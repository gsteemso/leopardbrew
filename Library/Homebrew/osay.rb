# Routines for addressing the user.

class TTY
  class << self
    def bold;    bold nil; end
    def default; bold  39; end
    def cyan;    bold  36; end
    def blue;    bold  34; end
    def gray;    bold  30; end  # bold black usually gets you an implementation-dependent shade of grey
    alias_method :grey, :gray
    def green;   bold  32; end
    def magenta; bold  35; end
    def red;     bold  31; end
    def white;   bold  37; end
    def yellow;  bold  33; end

    def em;        underline nil; end
    def ul_red;    underline  31; end
    def ul_yellow; underline  33; end

    def reset; escape 0; end

    def width; `/usr/bin/tput cols`.strip.to_i; end
    def truncate(str); str.to_s[0, width - 4]; end

    private

    def bold(n); escape(n ? "1;#{n}" : '1'); end
    def underline(n); escape(n ? "4;#{n}" : '4'); end

    def escape(n); "\033[#{n}m" if $stdout.tty?; end
  end # << self
end # TTY

def oh1(title)
  title = TTY.truncate(title) if $stdout.tty? && !VERBOSE
  puts "#{TTY.green}==>#{TTY.default} #{title}#{TTY.reset}"
end

def ohai(title, *sput)
  title = TTY.truncate(title) if $stdout.tty? && !VERBOSE
  puts "#{TTY.cyan}==>#{TTY.default} #{title}#{TTY.reset}"
  puts sput
end

# Print a warning (do this rarely)
def opoo(warning, *sput); $stderr.puts "#{TTY.ul_yellow}Warning#{TTY.reset}: #{warning}\n", sput; end

def onoe(error, *sput); $stderr.puts "#{TTY.ul_red}Error#{TTY.reset}: #{error}\n", sput; end

def ofail(error, *sput); onoe error, sput; Homebrew.failed = true; end

def odie(error, *sput); onoe error, sput; exit 1; end
