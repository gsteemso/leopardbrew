#!/usr/bin/ruby -W0
# -*- coding: utf-8 -*-

std_trap = trap('INT') { exit! 130 } # no backtrace thanks

# add HOMEBREW_RUBY_LIBRARY to front of Ruby‐library search path
$:.unshift(ENV['HOMEBREW_RUBY_LIBRARY'])

# Homebrew libraries:
require 'global'  # among other things, imports our environment variables as constants
require 'utils'   # defines or imports a lot of our infrastructure

case ARGV.first
when '-V', '--version'
  puts Homebrew.homebrew_version_string
  exit 0
end

def require?(path)
  require path
rescue LoadError
  # Raise on syntax errors, not if the file’s merely missing.
  raise if (HOMEBREW_RUBY_LIBRARY/"#{path}.rb").file?
end

begin
  if ENV['HOMEBREW_DEBUG_RUBY'].choke
    trap('INT') { puts caller * "\n"; exit! 130 }
  else
    trap('INT', std_trap) # restore default CTRL-C handler
  end

  empty_argv = ARGV.empty?
  help_regex = %r{-h$|--help$|--usage$|-\?$|^help$}
  help_flag = false
  internal_cmd = true
  cmd = nil

  ARGV.dup.each_with_index do |arg, i|
    if help_flag and cmd
      break
    elsif arg =~ help_regex
      help_flag = true
    elsif !cmd
      cmd = ARGV.delete_at(i)
    end
  end

  cmd = HOMEBREW_INTERNAL_COMMAND_ALIASES.fetch(cmd, cmd)

  # Add contributed commands to PATH before checking.
  Dir["#{HOMEBREW_LIBRARY}/Taps/*/*/cmd"].each do |tap_cmd_dir|
    ENV['PATH'] += "#{File::PATH_SEPARATOR}#{tap_cmd_dir}"
  end

  # Add SCM wrappers.
  ENV['PATH'] += "#{File::PATH_SEPARATOR}#{HOMEBREW_LIBRARY}/ENV/scm"

  if cmd
    internal_cmd = require? "cmd/#{cmd}"
    if DEVELOPER and not internal_cmd
      internal_cmd = require? "dev-cmd/#{cmd}"
    end
  end

  # Usage instructions should be displayed if and only if one of:
  # - a help flag is passed AND an internal command is matched
  # - a help flag is passed AND there is no command specified
  # - no arguments are passed
  #
  # It should never affect external commands so they can handle usage
  # arguments themselves.

  if empty_argv
    $stderr.puts ARGV.usage
    exit 1
  elsif help_flag
    if cmd.nil?
      puts ARGV.usage
      exit 0
    else
      # Handle both internal ruby and shell commands
      require 'cmd/help'
      help_text = Homebrew.help_for_command(cmd)
      if help_text.nil?
        # External command, let it handle help by itself
      elsif help_text.empty?
        puts "No help available for #{cmd}"
        exit 1
      else
        puts help_text
        exit 0
      end
    end
  end

  if internal_cmd
    Homebrew.send cmd.to_s.gsub('-', '_').downcase
  elsif which "brew-#{cmd}"
    exec "brew-#{cmd}", *ARGV
  elsif (path = which("brew-#{cmd}.rb")) and require?(path)
    exit Homebrew.failed? ? 1 : 0
  else
    onoe "Unknown command: #{cmd}"
    exit 1
  end

rescue FormulaUnspecifiedError
  abort 'This command requires a formula argument.'
rescue KegUnspecifiedError
  abort 'This command requires a keg argument.'
rescue UsageError
  onoe 'Invalid usage.'
  abort ARGV.usage
rescue SystemExit => e
  puts "Kernel.exit(#{e.status})" if e.status != 0 and ARGV.verbose?
  raise
rescue Interrupt => e
  puts # seemingly a newline is typical
  exit 130
rescue BuildError => e
  e.dump
  exit 1
rescue RuntimeError, SystemCallError => e
  raise if e.message.empty?
  onoe e
  puts e.backtrace if ARGV.debug?
  exit 1
rescue Exception => e
  onoe e
  if internal_cmd
    puts "#{Tty.white}Please report this bug:"
    puts "    #{Tty.em}#{ISSUES_URL}#{Tty.reset}"
  end
  puts e.backtrace
  exit 1
else
  exit 1 if Homebrew.failed?
end
