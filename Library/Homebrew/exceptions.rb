class CannotInstallFormulaError < RuntimeError; end
# Raised by Pathname#verify_checksum when “expected” is nil or empty:
class ChecksumMissingError < ArgumentError; end
class DebugError < RuntimeError; end
class FormulaSpecificationError < StandardError; end
# Raised when a single patch file is not found and apply hasn’t been specified:
class MissingApplyError < RuntimeError ; end
class MissingParameterError < RuntimeError ; end
class UsageError < RuntimeError; end
  class FormulaUnspecifiedError < UsageError; end
  class KegUnspecifiedError < UsageError; end

# See also:
# GitHub⸬AuthenticationFailedError  (in “utils.rb”)
# GitHub⸬RateLimitExceededError
# Keg⸬AlreadyLinkedError
# Keg⸬LinkError
#   Keg⸬ConflictError
#   Keg⸬DirectoryNotWritableError
# Migrator⸬MigrationNeededError
# Migrator⸬MigratorDifferentTapsError
# Migrator⸬MigratorNoOldnameError
# Migrator⸬MigratorNoOldpathError

class AlienCompilerError < ArgumentError
  def initialize(name)
    super "Compiler “#{name}”?  Sorry, Leopardbrew only knows about GCC variants and Clang."
  end
end

class BottleVersionMismatchError < RuntimeError
  def initialize(bottle_file, bottle_version, formula, formula_version)
    super <<-EOS.undent
        Bottle version mismatch
        Bottle: #{bottle_file} (#{bottle_version})
        Formula: #{formula.full_name} (#{formula_version})
      EOS
  end # initialize
end # BottleVersionMismatchError

class BuildError < RuntimeError
  attr_reader :formula, :env

  def initialize(formula, cmd, args, env)
    @formula = formula
    @env = env
    args = args.map { |arg| arg.to_s.gsub " ", "\\ " }.join(" ")
    super "Failed executing: #{cmd} #{args}"
  end # initialize

  def issues; @issues ||= fetch_issues; end

  def fetch_issues
    GitHub.issues_for_formula(formula.name)
  rescue GitHub::RateLimitExceededError => e
    opoo e.message
    []
  end # fetch_issues

  def dump
    if VERBOSE
      require "cmd/config"
      require "cmd/--env"
      ohai "Formula"
      puts "Tap: #{formula.tap}" if formula.tap?
      puts "Path: #{formula.path}"
      ohai "Configuration"
      Homebrew.dump_verbose_config
      ohai "ENV"
      Homebrew.dump_build_env(env)
      puts
      onoe "#{formula.full_name} #{formula.version} did not build"
      unless (logs = Dir["#{formula.logs}/*"]).empty?
        puts "Logs:"
        puts logs.map { |fn| "     #{fn}" }.join("\n")
      end
    else # not VERBOSE
      puts "\n#{TTY.ul_red}READ THIS#{TTY.reset}: #{TTY.em}#{ISSUES_URL}#{TTY.reset}"
      if formula.tap?
        case formula.tap
          when "homebrew/homebrew-boneyard"
            puts "#{formula} was moved to homebrew-boneyard because it has unfixable issues."
            puts "Please do not file any issues about this. Sorry!"
          else
            puts "If reporting this issue please do so not at the address above, but rather at"
            puts "  https://github.com/#{formula.tap}/issues"
        end
      end
    end # VERBOSE?
    puts
    if RUBY_VERSION >= '1.8.7' and issues and issues.any?
      puts "These open issues may also help:"
      puts issues.map { |i| "#{i["title"]} #{i["html_url"]}" }.join("\n")
    end
    if MacOS.version > MacOS::MAX_SUPPORTED_VERSION
      require 'cmd/doctor'
      opoo Checks.new.check_for_unsupported_osx
    end
  end # dump
end # BuildError

# Raised by cmd/install, cmd/reinstall, and cmd/upgrade if the user passes any
# flags/environment that would cause a bottle-only installation on a system
# without build tools to fail.
class BuildFlagsError < RuntimeError
  def initialize(flags)
    xcode_text = case MacOS.version
      when /10.1\d/, /1[1-9]/ then <<-EOS.undent
          or install Xcode from the App Store, or the CLT by running:
              xcode-select --install
        EOS
      when '10.9' then <<-EOS.undent
          or install Xcode from:
              https://developer.apple.com/downloads/
          or the CLT by running:
              xcode-select --install
        EOS
      when '10.7', '10.8' then <<-EOS.undent
          or install Xcode or the CLT from:
              https://developer.apple.com/downloads/
        EOS
      else <<-EOS.undent
          or install Xcode from:
              https://developer.apple.com/xcode/downloads/
        EOS
    end
    fp = plural flags.length
    super <<-EOS.undent
        The following flag#{fp}:
            #{flags.join(", ")}
        require#{fp == 's' ? '' : 's'} building tools, but none are installed.
        Either remove the flag#{fp} to attempt bottle installation,
        #{xcode_text}
      EOS
  end # initialize
end # BuildFlagsError

# raised by FormulaInstaller.check_dependencies_bottled and
# FormulaInstaller.install if the formula or its dependencies are not bottled
# and are being installed on a system without necessary build tools
class BuildToolsError < RuntimeError
  def initialize(formulae)
    if formulae.length > 1
      formula_text = "formulae"
      package_text = "binary packages"
    else
      formula_text = "formula"
      package_text = "a binary package"
    end
    if MacOS.version >= "10.10"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from the App Store,
        or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version == "10.9"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from:
          https://developer.apple.com/downloads/
        or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version >= "10.7"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode or the CLT from:
          https://developer.apple.com/downloads/
      EOS
    else
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from:
          https://developer.apple.com/xcode/downloads/
      EOS
    end
    super <<-EOS.undent
      The following #{formula_text}:
        #{formulae.join(", ")}
      cannot be installed as #{package_text} and must be built from source.
      #{xcode_text}
    EOS
  end # initialize
end # BuildToolsError

# raised by Pathname#verify_checksum when verification fails
class ChecksumMismatchError < RuntimeError
  attr_reader :expected, :hash_type
  def initialize(fn, expected, actual)
    @expected = expected
    @hash_type = expected.hash_type.to_s.upcase
    super <<-EOS.undent
        #{@hash_type} mismatch
        Expected: #{expected}
        Actual: #{actual}
        Archive: #{fn}
        To retry an incomplete download, remove the file above.
      EOS
  end # initialize
end # ChecksumMismatchError

# Raised by CompilerSelector if the formula fails with the user‐specified compiler.
class ChosenCompilerError < RuntimeError
  def initialize(formula, compiler_name)
    super <<-_.undent
        #{formula.full_name} cannot be built with the specified compiler, #{compiler_name}.
        To install this formula, you may need to
            brew install gcc
      _
  end # initialize
end # ChosenCompilerError

# raised by CompilerSelector if the formula fails with all of
# the compilers available on the user's system
class CompilerSelectionError < RuntimeError
  def initialize(formula)
    super <<-EOS.undent
        #{formula.full_name} cannot be built with any available compilers.
        To install this formula, you may need to either:
            brew install apple-gcc42
        or:
            brew install gcc
      EOS
  end # initialize
end # CompilerSelectionError

# raised in CurlDownloadStrategy.fetch
class CurlDownloadStrategyError < RuntimeError
  def initialize(url)
    if url =~ %r{^file://(.+)} then super "File does not exist:  #{$1}"
    else super "Download failed:  #{url}"; end
  end
end # CurlDownloadStrategyError

# Raised in Resource.fetch
class DownloadError < RuntimeError
  def initialize(resource, cause)
    super <<-EOS.undent
        Failed to download resource #{resource.download_name.inspect}
        #{cause.message}
      EOS
    set_backtrace(cause.backtrace)
  end # initialize
end # DownloadError

class DuplicateResourceError < ArgumentError
  def initialize(name); super "The resource #{name} is defined more than once."; end
end # DuplicateResourceError

# raised by safe_system in utils.rb and ` in cmd/update
class ErrorDuringExecution < RuntimeError
  def initialize(cmd, args = [])
    args = args.map { |a| a.to_s.gsub " ", "\\ " }.join(" ")
    super "Failure while executing:  #{cmd} #{args}"
  end
end # ErrorDuringExecution

class FileExistsError < RuntimeError
  def initialize(pathname); super "The object “#{pathname}” already exists."; end
end

class FormulaConflictError < RuntimeError
  attr_reader :formula, :conflicts
  def initialize(formula, conflicts)
    @formula = formula
    @conflicts = conflicts
    super message
  end

  def conflict_message(conflict)
    cm = "    #{conflict.name}"; cm += ":  because #{conflict.reason}" if conflict.reason
    cm
  end

  def message
    message = ["Cannot install #{formula.full_name} because conflicting formulae are installed.\n"]
    message.concat conflicts.map { |c| conflict_message(c) } << ''
    message << <<-EOS.undent
        Please `brew unlink #{conflicts.map(&:name) * ' '}` before continuing.

        Unlinking removes a formula’s symlinks from #{HOMEBREW_PREFIX}.  You
        can link the formula again after the install finishes.  You can --force this
        install, but the build may fail or cause obscure side-effects in the
        resulting software.
      EOS
    message.join("\n")
  end # message
end # FormulaConflictError

class FormulaInstallationAlreadyAttemptedError < RuntimeError
  def initialize(formula); super "Installation already attempted:  #{formula.full_name}"; end
end

class FormulaNotInstalledError < RuntimeError
  attr_reader :name
  def initialize(name); @name = name; super "#{name} is not installed."; end
end

class FormulaUnavailableError < RuntimeError
  attr_reader :name
  attr_accessor :dependent
  def initialize(name); @name = name; end
  def dependent_s; " (dependency of #{dependent})" if dependent and dependent != name; end
  def to_s; "No available formula for #{name}#{dependent_s}"; end
end # FormulaUnavailableError

  class TapFormulaUnavailableError < FormulaUnavailableError
    attr_reader :tap, :user, :repo
    def initialize(tap, name)
      @tap = tap
      @user = tap.user
      @repo = tap.repo
      super "#{tap}/#{name}"
    end # initialize

    def to_s
      s = super
      s += "\nPlease tap it and then try again: brew tap #{tap}" unless tap.installed?
      s
    end
  end # TapFormulaUnavailableError

class FormulaValidationError < StandardError
  attr_reader :attr
  def initialize(attr, value)
    @attr = attr
    super "invalid attribute: #{attr} (#{value.inspect})"
  end
end # FormulaValidationError

class FormulaVersionUnavailableError < RuntimeError
  def initialize(name, version); @name = name; @version = version; end
  def to_s; "The formula for #{@name} version #{@version} is no longer available"; end
end # FormulaUnavailableError

class MultipleVersionsInstalledError < RuntimeError
  attr_reader :name
  def initialize(name)
    @name = name
    super "#{name} has multiple installed versions.  Which one to use is indeterminable."
  end
end # MultipleVersionsInstalledError

class NoSuchKegError < RuntimeError
  def initialize(vers_name)
    vers_name =~ VERSIONED_NAME_REGEX
    super "No such version is installed:  #{HOMEBREW_CELLAR/$1/$2}"
  end
end # NoSuchKegError

class NoSuchRackError < RuntimeError
  def initialize(rack)
    super "No such formula is installed:  #{rack}"
  end
end # NoSuchRackError

class NotAKegError < RuntimeError
  def initialize(path); super "#{path.to_s} is neither a keg nor inside of one."; end
end

class NotAnInstalledKegError < RuntimeError
  def initialize(path)
    super "#{path.to_s} is in a rack of kegs, but is not itself an installed keg."
  end
end

class OperationInProgressError < RuntimeError
  def initialize(name)
    message = <<-EOS.undent
        Operation already in progress for #{name}
        Another active Leopardbrew process is already using #{name}.
        Please wait for it to finish or terminate it to continue.
      EOS
    super message
  end # initialize
end # OperationInProgressError

class ResourceMissingError < ArgumentError
  def initialize(formula, resource)
    super "#{formula.full_name} does not define resource #{resource.inspect}"
  end
end # ResourceMissingError

class TapFormulaAmbiguityError < RuntimeError
  attr_reader :name, :paths, :formulae
  def initialize(name, paths)
    @name = name
    @paths = paths
    @formulae = paths.map do |path|
      path.to_s =~ HOMEBREW_TAP_PATH_REGEX
      "#{$1}/#{$2.sub("homebrew-", "")}/#{path.basename(".rb")}"
    end
    super <<-EOS.undent
        Formulae found in multiple taps: #{formulae.map { |f| "\n       * #{f}" }.join}

        Please use the fully-qualified name e.g. #{formulae.first} to refer the formula.
      EOS
  end # initialize
end # TapFormulaAmbiguityError

class TapFormulaWithOldnameAmbiguityError < RuntimeError
  attr_reader :name, :possible_tap_newname_formulae, :taps
  def initialize(name, possible_tap_newname_formulae)
    @name = name
    @possible_tap_newname_formulae = possible_tap_newname_formulae
    @taps = possible_tap_newname_formulae.map do |newname|
      newname =~ HOMEBREW_TAP_FORMULA_REGEX
      "#{$1}/#{$2}"
    end
    super <<-EOS.undent
        Formulae with '#{name}' old name found in multiple taps: #{taps.map { |t| "\n       * #{t}" }.join}

        Please use the fully-qualified name (e.g. #{taps.first}/#{name}) to
        refer to the formula, or use its new name.
      EOS
  end # initialize
end # TapFormulaWithOldnameAmbiguityError

class TapPinStatusError < RuntimeError
  attr_reader :name, :pinned
  def initialize(name, pinned)
    @name = name
    @pinned = pinned
    super "#{name} is already #{pinned ? '' : 'un'}pinned."
  end
end # TapPinStatusError

class TapUnavailableError < RuntimeError
  attr_reader :name
  def initialize(name)
    @name = name
    super "No available tap #{name}."
  end
end # TapUnavailableError

class UnsatisfiedRequirements < RuntimeError
  def initialize(reqs)
    lines = ["#{plural reqs.length, 'Unsatisfied requirements', 'An unsatisfied requirement'} failed this build:"]
    reqs.each_pair do |dependent, reqset|
      reqset.each { |req| lines << "#{dependent}:  #{req.message}" }
    end
    super lines.join("\n")
  end # initialize
end # UnsatisfiedRequirements
