#:  Usage:  brew diy [--name=<name>] [--version=<version>] [--bare]
#:
#:Invoke this command from the root of an unpacked source tarball.  It’ll attempt
#:to guess the package’s name and version based on the pathname of that directory,
#:then print out a CMake (or else Autotools) command option describing the Cellar
#:prefix corresponding to that information.  If it guesses incorrectly, either or
#:both of the name and version may be given explicitly on the command line.
#:
#:To get the Cellar-ready prefix in its bare form (i.e., not preprocessed to suit
#:a specific build system), include “--bare” in the command.

require 'formula'

module Homebrew
  def diy
    path = Pathname.getwd

    version = ARGV.value('version') || detect_version(path)
    name = ARGV.value('name') || detect_name(path, version)

    prefix = HOMEBREW_CELLAR/name/version

    if ARGV.longopt? 'bare'
      puts prefix
    elsif File.file? 'CMakeLists.txt'
      puts "-DCMAKE_INSTALL_PREFIX=#{prefix}"
    elsif File.file? 'configure'
      puts "--prefix=#{prefix}"
    else
      raise 'Couldn’t determine build system'
    end
  end

  def detect_version(path)
    version = path.version.to_s

    if version.empty?
      raise 'Couldn’t determine version.  Set it with --version=<version>.'
    else
      version
    end
  end

  def detect_name(path, version)
    basename = path.basename.to_s
    detected_name = basename[/(.*?)-?#{Regexp.escape(version)}/, 1] || basename
    canonical_name = Formulary.canonical_name(detected_name)

    odie <<-EOS.undent if detected_name != canonical_name
        The detected name #{detected_name.inspect} exists in Leopardbrew as an alias of
        #{canonical_name.inspect}.  Consider using the canonical name instead:
            brew diy --name=#{canonical_name}

        To continue using the detected name, pass it explicitly:
            brew diy --name=#{detected_name}
      EOS

    detected_name
  end
end
