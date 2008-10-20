require 'file/tail'

############ Extending LOGFILE with FILE and TAIL capabilities
class LogFile < File
	include File::Tail
	
	attr_accessor :log_format_str
	
	attr_reader :log_format_obj
  
  def get_log_format_obj
    return nil if @log_format_str.nil?
    @log_format_obj = LogFormat.new(@log_format_str) if @log_format_obj.nil?
    @log_format_obj
  end
    
  def scan_str(line)
    log_format = get_log_format_obj
    raise ArgumentError if log_format.nil? or line !~ log_format.format_regex
    data = line.scan(log_format.format_regex).flatten
    parsed_data = {}
    log_format.format_symbols.size.times do |i|
      parsed_data[log_format.format_symbols[i]] = data[i]
    end
    #remove [] from time if present
    parsed_data[:datetime] = parsed_data[:datetime][1...-1] if parsed_data[:datetime]
    # Add ip as domain if we don't have a domain (virtual host)
    # Assumes we always have an ip
    parsed_data[:domain] = parsed_data[:ip] unless parsed_data[:domain]
    parsed_data
  end
  
  # Attaching to log-file (same as 'tail -f')
  # It is executing for ever
  def attach(&block)
    self.interval = 10
    self.reopen_suspicious = true
    self.suspicious_interval = 30
    self.reopen_deleted = true
    self.backward.tail nil, &block
  end
  
end