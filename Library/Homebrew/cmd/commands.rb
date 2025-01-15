module Homebrew
  def commands
    if ARGV.include? "--quiet"
      cmds = internal_commands + external_commands
      cmds += internal_development_commands if DEVELOPER
      cmds += HOMEBREW_INTERNAL_COMMAND_ALIASES.keys if ARGV.include? "--include-aliases"
      puts_columns cmds.sort
    else
      # Find commands in Homebrew/cmd
      puts "Built-in commands"
      puts_columns internal_commands

      # Find commands in Homebrew/dev-cmd
      if DEVELOPER
        puts
        puts "Built-in development commands"
        puts_columns internal_development_commands
      end

      # Find commands in the path
      unless (exts = external_commands).empty?
        puts
        puts "External commands"
        puts_columns exts
      end
    end
  end

  def internal_commands
    with_directory = false
    HOMEBREW_CMDS.children(with_directory).map { |f| File.basename(f, ".rb") }
  end

  def internal_development_commands
    with_directory = false
    HOMEBREW_DEV_CMDS.children(with_directory).map { |f| File.basename(f, ".rb") }
  end

  def external_commands
    paths.flat_map { |p| Dir["#{p}/brew-*"] }.
      map { |f| File.basename(f, ".rb")[5..-1] }.
      reject { |f| f =~ /\./ }.
      sort
  end
end
