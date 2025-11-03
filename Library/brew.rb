#!/usr/bin/ruby -W0
# -*- coding: utf-8 -*-

std_trap = trap('INT') { exit! 130 } # no backtrace thanks

$:.unshift(ENV['HOMEBREW_RUBY_LIBRARY'])  # Add $HOMEBREW_RUBY_LIBRARY to the front of the Ruby‐library search path.
# Import or define all our infrastructure, such as reading specific environment variables into global constants.
require 'global'

if ['-V', '--version'].include? ARGV.first
  puts Homebrew.homebrew_version_string  # see `utils.rb`
  exit 0
end

def require?(path)
  require path
rescue LoadError
  raise if (HOMEBREW_RUBY_LIBRARY/"#{path}.rb").file?  # Raise on syntax errors, not if the file’s merely missing.
end

begin
  if ENV['HOMEBREW_DEBUG_RUBY'].choke then trap('INT') { puts caller * "\n"; exit! 130 }
  else trap('INT', std_trap); end  # restore default CTRL-C handler

  if MacOS.version <= :leopard
    numprocs = `sysctl -n kern.maxproc`.to_i * 2 / 3
    if numprocs > `sysctl -n kern.maxprocperuid`.to_i
      opoo <<-_.undent
        Your ancient version of Mac OS sharply limits the number of concurrent
        processes you are allowed to run.  ’Brewing without raising this limit will not
        always work properly, and the resulting failures will seem nonsensical.  Please
        enter your sudo password at the prompt so Leopardbrew can raise the limit.  (It
        will stay raised, systemwide, until you reboot).

        To be more specific, sysctl(8) will raise “kern.maxprocperuid” to a saner value
        – two‐thirds of the system maximum, “kern.maxproc”.  Your system is so outdated,
        that maximum is itself a bit low, but there’s nothing we can do about that.
      _
      system 'sudo', 'sysctl', '-w', "kern.maxprocperuid=#{numprocs}"
    end # kern.maxprocperuid check
  end # Leopard or older?

  empty_argv = ARGV.empty?
  help_regex = %r{-h$|--help$|--usage$|-\?$|^help$}
  help_flag = false
  internal_cmd = true
  cmd = nil
  ARGV.dup.each_with_index do |arg, i|
    if help_flag and cmd then break
    elsif arg =~ help_regex then help_flag = true
    else cmd ||= ARGV.delete_at(i); end
  end
  cmd = HOMEBREW_INTERNAL_COMMAND_ALIASES.fetch(cmd, cmd)

  # Add contributed commands and SCM wrappers to PATH before checking.
  Dir["#{HOMEBREW_LIBRARY}/Taps/*/*/cmd"].each{ |tap_cmd_dir| ENV['PATH'] += "#{File::PATH_SEPARATOR}#{tap_cmd_dir}" }
  ENV['PATH'] += "#{File::PATH_SEPARATOR}#{HOMEBREW_LIBRARY}/ENV/scm"

  if cmd
    internal_cmd = require? "cmd/#{cmd}"
    if DEVELOPER and not internal_cmd then internal_cmd = require? "dev-cmd/#{cmd}"; end
  end

  # Usage instructions should be displayed if and only if one of:
  # - a help flag is passed AND an internal command is matched
  # - a help flag is passed AND there is no command specified
  # - no arguments are passed
  #
  # It should never affect external commands, so they can handle usage arguments themselves.
  if empty_argv then $stderr.puts ARGV.usage; exit 1
  elsif help_flag
    if cmd.nil? then puts ARGV.usage; exit 0
    else  # Handle both internal ruby and shell commands
      require 'cmd/help'
      help_text = Homebrew.help_for_command(cmd)
      if help_text.nil?  # External command, let it handle help by itself
      elsif help_text.empty? then puts "No help available for #{cmd}"; exit 1
      else puts help_text; exit 0
      end
    end
  end

  if internal_cmd then Homebrew.send cmd.to_s.gsub('-', '_').downcase
  elsif which "brew-#{cmd}" then exec "brew-#{cmd}", *ARGV
  elsif (path = which("brew-#{cmd}.rb")) and require?(path) then exit Homebrew.failed? ? 1 : 0
  else onoe "Unknown command: #{cmd}"; exit 1; end

rescue FormulaUnspecifiedError
  abort 'This command requires a formula argument.'
rescue KegUnspecifiedError
  abort 'This command requires a keg argument.'
rescue UsageError
  onoe 'Invalid usage.'
  abort ARGV.usage
rescue MissingParameterError => e
  abort e.message
rescue SystemExit => e
  $stderr.puts "Kernel.exit(#{e.status})" if e.status != 0 and VERBOSE; raise
rescue Interrupt => e
  puts # seemingly a newline is typical
  exit 130
rescue BuildError => e
  e.dump; exit 1
rescue RuntimeError, SystemCallError => e
  raise if e.message.empty?; onoe e; $stderr.puts e.backtrace if DEBUG; exit 1
rescue Exception => e
  onoe e
  if internal_cmd then $stderr.puts "#{TTY.white}Please report this bug:\n    #{TTY.em}#{ISSUES_URL}#{TTY.reset}"; end
  $stderr.puts e.backtrace if DEBUG; exit 1
else
  exit 1 if Homebrew.failed?
end
