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