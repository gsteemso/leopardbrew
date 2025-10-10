require "requirement"
require "requirements/apr_requirement"
require "requirements/cctools_requirement"
require "requirements/emacs_requirement"
require "requirements/fortran_requirement"
require "requirements/java_requirement"
require "requirements/language_module_requirement"
require "requirements/maximum_macos_requirement"
require "requirements/minimum_macos_requirement"
require "requirements/mpi_requirement"
require "requirements/osxfuse_requirement"
require "requirements/python_requirement"
require "requirements/ruby_requirement"
require "requirements/tuntap_requirement"
require "requirements/unsigned_kext_requirement"
require "requirements/x11_requirement"

class ArchRequirement < Requirement
  fatal true

  def initialize(arch)
    @arch = Array(arch).pop
    super
  end

  satisfy(:build_env => false) do
    case @arch.to_s.downcase
      when %r{^arm} then Target.arm?
      when 'i386', 'ppc' then Target.arch == @arch
      when 'intel' then Target.intel?
      when 'powerpc' then Target.powerpc?
      when 'ppc64' then Target.prefer_64b? and Target.powerpc?
      when 'x86_64' then Target.prefer_64b? and Target.intel?
    end
  end

  def message; "This formula requires a#{@arch.to_s[0] == 'p' ? '' : 'n'} #{@arch} architecture."; end
end # ArchRequirement

class GitRequirement < Requirement
  fatal true
  default_formula "git"
  satisfy { !!which("git") }
end

class GPGRequirement < Requirement
  fatal true
  default_formula "gpg"
  satisfy { which("gpg") }
end

class MercurialRequirement < Requirement
  fatal true
  default_formula "mercurial"
  satisfy { which("hg") }
end

class MysqlRequirement < Requirement
  fatal true
  default_formula "mysql"
  satisfy { which "mysql_config" }
end

class PostgresqlRequirement < Requirement
  fatal true
  default_formula "postgresql"
  satisfy { which "pg_config" }
end

class SelfUnbrewedRequirement < Requirement
  fatal true
  def initialize(stock_pathname, moved_pathname, unlink_script_name)
    @stock = Pathname.new(stock_pathname)
    @moved = Pathname.new(moved_pathname)
    @unscript = unlink_script_name
    super()
  end
  satisfy { (not @stock.symlink?) or (@moved.exists? and @stock.readlink == @moved.basename) }
  def message; <<-_.undent
      You can’t reïnstall this software while using it!  You need to run
          #{@unscript}
      before proceeding.
    _
  end
end

class TeXRequirement < Requirement
  fatal true
  cask "mactex"
  download "https://www.tug.org/mactex/"
  satisfy { which("tex") || which("latex") }
  def message
    s = <<-EOS.undent
      A LaTeX distribution is required for Homebrew to install this formula.

      Make sure that "/usr/texbin", or the location you installed it to, is in
      your PATH before proceeding.
    EOS
    s += super
    s
  end
end

class XcodeRequirement < Requirement
  fatal true
  satisfy(:build_env => false) { xcode_installed_version }
  def initialize(tags)
    @version = tags.find { |t| tags.delete(t) if /(\d\.)+\d/ === t }
    super
  end
  def xcode_installed_version
    return false unless MacOS::Xcode.installed?
    return true unless @version
    MacOS::Xcode.version >= @version
  end
  def message
    version = " #{@version}" if @version
    message = <<-EOS.undent
      A full installation of Xcode.app#{version} is required to compile this software.
      Installing just the Command Line Tools is not sufficient.
    EOS
    if MacOS.version >= :lion
      message += <<-EOS.undent
        Xcode can be installed from the App Store.
      EOS
    else
      message += <<-EOS.undent
        Xcode can be installed from https://developer.apple.com/xcode/downloads/
      EOS
    end
  end
  def inspect
    "#<#{self.class.name}: #{name.inspect} #{tags.inspect} version=#{@version.inspect}>"
  end
end

