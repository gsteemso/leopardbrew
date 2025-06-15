# Routines for addressing the user.

class Tty
  class << self
    def blue; bold 34; end
    def white; bold 39; end
    def red; underline 31; end
    def yellow; underline 33; end
    def em; underline 39; end
    def green; bold 32; end
    def gray; bold 30; end

    def reset; escape 0; end

    def width; `/usr/bin/tput cols`.strip.to_i; end
    def truncate(str); str.to_s[0, width - 4]; end

    private

    def bold(n); escape "1;#{n}"; end
    def underline(n); escape "4;#{n}"; end

    def escape(n); "\033[#{n}m" if $stdout.tty?; end
  end
end

def oh1(title)
  title = Tty.truncate(title) if $stdout.tty? && !VERBOSE
  puts "#{Tty.green}==>#{Tty.white} #{title}#{Tty.reset}"
end

def ohai(title, *sput)
  title = Tty.truncate(title) if $stdout.tty? && !VERBOSE
  puts "#{Tty.blue}==>#{Tty.white} #{title}#{Tty.reset}"
  puts sput
end

# Print a warning (do this rarely)
def opoo(warning, *sput)
  $stderr.puts "#{Tty.yellow}Warning#{Tty.reset}: #{warning}"
  $stderr.puts sput
end

def onoe(error, *sput)
  $stderr.puts "#{Tty.red}Error#{Tty.reset}: #{error}"
  $stderr.puts sput
end

def ofail(error, *sput)
  onoe error, sput
  Homebrew.failed = true
end

def odie(error, *sput)
  onoe error, sput
  exit 1
end
