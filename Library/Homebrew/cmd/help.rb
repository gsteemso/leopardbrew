HOMEBREW_HELP = <<EOS
Example usage:
  brew ( info | home | options ) [FORMULA ...]
  brew ( install | upgrade | uninstall ) FORMULA ...
  brew search [foo]
  brew list [FORMULA ...]
  brew update
  brew ( pin | unpin ) [FORMULA ...]

Troubleshooting:
  brew doctor
  brew install -vd FORMULA
  brew ( env | config )

Brewing:
  brew create [URL [--no-fetch]]
  brew edit [FORMULA ...]
  #{HOMEBREW_REPOSITORY}/share/doc/homebrew/Formula-Cookbook.md

Further help:
  man brew
  brew home
EOS

# NOTE:  Keep basic --help text under 25 lines (the default Terminal height).  The string is at the top to make it easy to measure!
#        Scrolling sucks and concision is important.  If more is needed, we should specialize it like the gem command does.
# NOTE:  Keep user‐visible lines under 80 characters!  Wrapping can become unreadably messy.

module Homebrew
  def help; puts HOMEBREW_HELP; end

  def help_s; HOMEBREW_HELP; end

  def help_for_command(cmd)
    cmd_path = [
      HOMEBREW_CMDS/"#{cmd}.sh",
      HOMEBREW_DEV_CMDS/"#{cmd}.sh",
      HOMEBREW_CMDS/"#{cmd}.rb",
      HOMEBREW_DEV_CMDS/"#{cmd}.rb",
    ].find { |cp| File.exists?(cp) } or return
#    return if cmd_path.nil?

    cmd_path.read.split("\n").grep(/^#:/).map{ |line| line.slice(2..-1).delete("`").sub(/^  \* /, "brew ") }.join("\n")
  end
end
