# Here I will store all requests and prisoners (to make sure I'll not forget to free them).
require 'sqlite3'

############ Layer to storage.
class DataBase

  # Connect to DB
  def initialize
    @db = SQLite3::Database.new( File.join(BANANOID_ROOT, $config.database['file']) )
    @db.type_translation = true
    @db.results_as_hash = true
    @db.execute <<-SQLite
      CREATE TABLE IF NOT EXISTS requests (
      id INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
      domain TEXT  NOT NULL,
      request TEXT NOT NULL,
      referer TEXT NOT NULL,
      status INTEGER NOT NULL,
      ip  TEXT NOT NULL,
      first_seen INTEGER NOT NULL,
      last_seen INTEGER NOT NULL,
      counter  INTEGER NOT NULL,
      UNIQUE (domain, request, referer, status, ip)
      )
    SQLite
    
    @db.execute <<-SQLite
      CREATE TABLE IF NOT EXISTS prisoners (
      id INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
      ip  TEXT NOT NULL,
      added INTEGER NOT NULL,
      UNIQUE (ip)
      )
    SQLite
  end
  
  # add and recalculate counter
  def add(data)
    
    # selecting all records, skipping old ones.
    result = @db.get_first_row "SELECT id, counter FROM requests WHERE domain=:domain AND request=:request AND status=:status AND referer=:referer AND ip=:ip AND first_seen<=:first_seen",
      'domain' => data[:domain],
      'request' => data[:request],
      'referer' => data[:referer],
      'status' => data[:status],
      'ip' => data[:ip],
      'first_seen' => $config.detection['max_period'].seconds.ago.to_i
    # adding new request, overwriting too old ones.
    if result.nil?
      @db.execute "INSERT OR REPLACE INTO requests (domain, request, referer, status, ip, first_seen, last_seen, counter) 
                                VALUES (:domain, :request, :referer, :status, :ip, strftime('%s','now'), strftime('%s','now'), 1)",
        'domain' => data[:domain],
        'request' => data[:request],
        'referer' => data[:referer],
        'status' => data[:status],
        'ip' => data[:ip]
    else
      # Look, Ma! We got fresh requests
      @db.execute "UPDATE requests SET last_seen = strftime('%s','now'), counter = counter+1 WHERE id = ?", result['id']
    end
  end

  def list_enemies
    @db.execute "SELECT ip FROM requests WHERE counter > ? AND (last_seen - first_seen) > ?", $config.detection['max_rate'], $config.detection['max_period']
  end
  
  def imprison(ip)
    @db.execute "INSERT OR REPLACE INTO prisoners (ip, added) VALUES(?, strftime('%s','now'))", ip
    @db.execute "DELETE FROM requests WHERE ip = ?", ip
  end

  def free_prisoners(&block)
    list = @db.execute "SELECT id, ip, added FROM prisoners WHERE added < ?", $config.periodic['bann'].minutes.ago
    list.each do |row|
      @db.execute "DELETE FROM prisoners WHERE id=?", row['id']
      yield row['ip']
    end unless list.empty?
  end
  
  # Purge all non-essential data.
  def purge_old
    @db.execute "DELETE FROM requests WHERE first_seen < ?", $config.periodic['purge'].minutes.ago.to_i
  end

 
end