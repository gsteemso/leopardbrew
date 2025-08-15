#:Check the library links of an installed formula.
#:
#:  Usage:    linkage [--test | --reverse] <formula>
#:
#:<formula> must be installed or an error is raised.
#:
#:If `--test` is passed, only display missing libraries.  Exits with a non-zero
#:exit code if any missing libraries were found.
#:
#:If `--reverse` is passed, for each dynamic library the keg references, print
#:its name and which of the keg’s binaries link to it.

require "macos/linkage_checker"

module Homebrew
  module_function

  def linkage
    ARGV.kegs.each do |keg|
      ohai "Checking #{keg.name} linkage" if ARGV.kegs.size > 1
      result = LinkageChecker.new(keg)
      if ARGV.include?("--test")
        result.display_test_output
        Homebrew.failed = true if result.broken_dylibs?
      elsif ARGV.include?("--reverse")
        result.display_reverse_output
      else
        result.display_normal_output
      end
    end
  end
end
