# This program parses weblogs in the NCSA Common (access log) format or
# NCSA Combined log format
#
# One line consists of
#  host rfc931 username date:time request statuscode bytes
# For example
#  1.2.3.4 - dsmith [10/Oct/1999:21:15:05 +0500] "GET /index.html HTTP/1.0" 200 12
#                   [dd/MMM/yyyy:hh:mm:ss +-hhmm]
# Where
#  dd is the day of the month
#  MMM is the month
#  yyy is the year
#  :hh is the hour
#  :mm is the minute
#  :ss is the seconds
#  +-hhmm is the time zone
#
# In practice, the day is typically logged in two-digit format even for 
# single-digit days. 
# For example, the second day of the month would be represented as 02. 
# However, some HTTP servers do log a single digit day as a single digit. 
# When parsing log records, you should be aware of both possible day 
# representations.
#
# Author:: Jan Wikholm [jw@jw.fi]
# License:: MIT


class LogFormat
  attr_reader :format, :format_symbols, :format_regex
  
  # add more format directives here..
  DIRECTIVES = {
    # format string char => [:symbol to use, /regex to use when matching against log/]
    'h' => [:ip, /\d+\.\d+\.\d+\.\d+/],
    'l' => [:auth, /.*?/],
    'u' => [:username, /.*?/],
    't' => [:datetime, /\[.*?\]/],
    'r' => [:request, /.*?/],
    's' => [:status, /\d+/],
    'b' => [:bytecount, /-|\d+/],
    'v' => [:domain, /.*?/],
    'i' => [:header_lines, /.*?/], 
  }

  def initialize(format)
    @format = format
    parse_format(format)
  end
  
  # The symbols are used to map the log to the env variables
  # The regex is used when checking what format the log is and to extract data
  def parse_format(format)
    format_directive = /%(.*?)(\{.*?\})?([#{[DIRECTIVES.keys.join('|')]}])([\s\\"]*)/
    log_format_symbols = []
    format_regex = ""
    format.scan(format_directive) do |condition, subdirective, directive_char, ignored|
      log_format, match_regex = process_directive(directive_char, subdirective, condition)
      ignored.gsub!(/\s/, '\\s') unless ignored.nil?
      log_format_symbols << log_format
      format_regex << "(#{match_regex})#{ignored}"
    end
    @format_symbols = log_format_symbols
    @format_regex =  /^#{format_regex}/
  end

  def process_directive(directive_char, subdirective, condition)
    directive = DIRECTIVES[directive_char]
    case directive_char 
    when 'i'
      log_format = subdirective[1...-1].downcase.tr('-', '_').to_sym
      [log_format, directive[1].source]
    else
      [directive[0], directive[1].source]
    end
  end
end