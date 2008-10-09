#!/usr/bin/ruby

require 'rubygems'
# I know it's too heavy, but it looks so sweat ^__^
# It allows to do tricks like 5.minutes.ago, and even make.yourself.a.coffee.
require 'activesupport'

# 'What do you see in the dark when the demons come for you' (c) Godsmack.
require 'daemons'
# I like pretty configuration files
require 'yaml'
require 'ostruct'

# Defines root dir
BANANOID_ROOT = "#{File.dirname(Pathname.new(__FILE__).realpath)}" unless defined?(BANANOID_ROOT)

# Let's check first - may be there is another copy of bananoid already running?
PID_FILE = File.join(BANANOID_ROOT, 'self.pid')
if File.exists?(PID_FILE) and Daemons::Pid.running?(IO.read(PID_FILE).to_i)
  puts "Another instance is running..."
  exit
end

# Let's read configuration
$config = OpenStruct.new(YAML.load_file(File.join(BANANOID_ROOT, 'config.yml')))
# And add my_ip to whitelisted
$config.whitelist |= $config.my_ip

# This is ugly, need to get rid of it.
# TODO: get rid of this
KEYS = [:domain, :ip, :time, :status, :request, :body_size, :referer, :user_agent]


#################################################
############ HERE ARE THE CLASSES ###############
#################################################
require File.join(BANANOID_ROOT, 'lib/logfile')
require File.join(BANANOID_ROOT, 'lib/database')
require File.join(BANANOID_ROOT, 'lib/blocker')
#################################################
############## HERE IS THE MAGIC ################
#################################################

daemon_options = {:app_name => 'bananoid', :dir_mode => :normal, :dir => BANANOID_ROOT, :backtrace  => true}
daemon_options[:ontop] = true if $config.debug
# Become a daemon
Daemons.daemonize daemon_options

# To see me in top / ps you need this string
$0 = 'bananoid'

if $config.debug
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG
else
  $logger = Logger.new(File.join(BANANOID_ROOT, $config.logs['my'])) # STDOUT
  $logger.level = Logger::INFO
end

$logger.info "Started at #{Time.now}"
$logger.info "Running under #{BANANOID_ROOT}"
$logger.debug "Opening #{$config.logs['httpd']}"

httpd_log = LogFile.new($config.logs['httpd'], "r")

$logger.debug "Opening database #{$config.database}"

# Working with such speed on hdd eats a lot of resources.
# So the good idea is to bring DB to tmpfs.
if $config.database['use_tmpfs']
  $logger.info "Trying to mount tmpfs to #{BANANOID_ROOT}/db"
  mounts = `mount`
  unless mounts.match BANANOID_ROOT
    $logger.info `/bin/mount -t tmpfs -o size=#{$config.database['tmpfs_size']},mode=0744 tmpfs #{BANANOID_ROOT}/db`
  end
end


db = DataBase.new # TODO
purge_timer = Time.now
unblock_timer = Time.now

$logger.debug "Attaching to log."
begin
  #let's start tailing app's log
  httpd_log.attach do |line|
    data = httpd_log.scan_str(line)
    unless data.nil?
      db.add data
      enemies = db.list_enemies
      unless enemies.empty?
        enemies.each do |row|
          Blocker.block row['ip']
          db.imprison row['ip']
        end 
      end
    end
  
    # should we clean up DB?
    if purge_timer < $config.periodic['purge'].minutes.ago
      $logger.info "Database PURGE started >>>>>>>>>>>>>>>>>>"
      db.purge_old 
      $logger.info "Database PURGE ended <<<<<<<<<<<<<<<<<<<<"
      purge_timer = Time.now
    end
  
    # who should be released from jail?
    if unblock_timer < $config.periodic['bann'].minutes.ago
      $logger.info "Prisoners RELEASE started >>>>>>>>>>>>>>>>>>"
      db.free_prisoners do |ip|
        Blocker.unblock ip
      end
      $logger.info "Prisoners RELEASE ended <<<<<<<<<<<<<<<<<<<<"
      unblock_timer = Time.now
    end
  
  end
rescue
  $logger.error 'An exception caught. Dying...'
end