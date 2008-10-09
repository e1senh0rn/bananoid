# This lib will allow me to read tail of file instead of starting from the beginning.
require 'file/tail'

############ Extending LOGFILE with FILE and TAIL capabilities
class LogFile < File
	include File::Tail
  
  # Attaching to log-file (same as 'tail -f')
  # It is executing for ever
  def attach(&block)
    self.interval = 10
    self.reopen_suspicious = true
    self.suspicious_interval = 30
    self.reopen_deleted = true
    self.backward.tail nil, &block
  end
  
  # Scanning and parsing the string.
  def scan_str(str)
    begin
      matches = str.scan(/(.*) (.*) \[(.*)\] (\d+) "(.*)" (\d+) "(.*)" "(.*)"/)[0]
      parsed = {}
      # TODO get rid of this constant
      KEYS.each_with_index do |param, index|
        case param
        when :time
          # This pice of code takes time. Be careful.
          parsed[param] = Time.parse matches[index].sub(':', ' ')
        else
          parsed[param] = matches[index]
        end
      end
    rescue
      $logger.error "Could not parse string: #{str}"
      parsed = nil
    end
    parsed
  end
  
end