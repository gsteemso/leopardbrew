require "formula_support"
require "formula_lock"
require "formula_pin"
require "hardware"
require "bottles"
require "build_environment"
require "build_options"
require "formulary"
require "software_spec"
require "install_renamed"
require "pkg_version"
require 'tab'
require "tap"
require "formula_renames"
require "keg"

# A formula provides instructions and metadata for Homebrew to install a piece
# of software. Every Homebrew formula is a {Formula}.
# All subclasses of {Formula} (and all Ruby classes) have to be named
# `UpperCase` and `not-use-dashes`.
# A formula specified in `this-formula.rb` should have a class named
# `ThisFormula`. Homebrew does enforce that the name of the file and the class
# correspond.
# Make sure you check with `brew search` that the name is free!
# @abstract
# @see SharedEnvExtension
# @see FileUtils
# @see Pathname
# @see http://www.rubydoc.info/github/Homebrew/homebrew/file/share/doc/homebrew/Formula-Cookbook.md Formula Cookbook
# @see https://github.com/styleguide/ruby Ruby Style Guide
#
# <pre>class Wget < Formula
#   homepage "https://www.gnu.org/software/wget/"
#   url "https://ftp.gnu.org/gnu/wget/wget-1.15.tar.gz"
#   sha256 "52126be8cf1bddd7536886e74c053ad7d0ed2aa89b4b630f76785bac21695fcd"
#
#   def install
#     system "./configure", "--prefix=#{prefix}"
#     system "make", "install"
#   end
# end</pre>
class Formula
  include FileUtils
  include Utils::Inreplace
  extend Enumerable

  # @!method inreplace(paths, before = nil, after = nil)
  # Actually implemented in {Utils::Inreplace.inreplace}.  Sometimes we have to change a bit before
  # we install.  Mostly we prefer a patch; but if you need the prefix() of this formula in the
  # patch you have to resort to `inreplace`, because in the patch you don't have access to any var
  # defined by the formula.  Only HOMEBREW_PREFIX is available in the embedded patch.  inreplace
  # supports regular expressions.
  # <pre>inreplace "somefile.cfg", /look[for]what?/, "replace by #{bin}/tool"</pre>
  # @see Utils::Inreplace.inreplace

  # The name of this {Formula}.
  # e.g. `this-formula`
  attr_reader :name

  # The fully-qualified name of this {Formula}.
  # For core formula it's the same as {#name}.
  # e.g. `homebrew/tap-name/this-formula`
  attr_reader :full_name

  # The full path to this {Formula}.
  # e.g. `/usr/local/Library/Formula/this-formula.rb`
  attr_reader :path

  # The stable (and default) {SoftwareSpec} for this {Formula}
  # This contains all the attributes (e.g. URL, checksum) that apply to the
  # stable version of this formula.
  # @private
  attr_reader :stable

  # The development {SoftwareSpec} for this {Formula}.
  # Installed when using `brew install --devel`
  # `nil` if there is no development version.
  # @see #stable
  # @private
  attr_reader :devel

  # The HEAD {SoftwareSpec} for this {Formula}.
  # Installed when using `brew install --HEAD`
  # This is always installed with the version `HEAD` and taken from the latest
  # commit in the version control system.
  # `nil` if there is no HEAD version.
  # @see #stable
  # @private
  attr_reader :head

  # The currently active {SoftwareSpec}.
  # @see #determine_active_spec
  attr_reader :active_spec
  protected :active_spec

  # A symbol to indicate currently active {SoftwareSpec}.
  # It's either :stable, :devel or :head
  # @see #active_spec
  # @private
  attr_reader :active_spec_sym

  # Used for creating new Homebrew versions of software without new upstream
  # versions.
  # @see .revision
  attr_reader :revision

  # The current working directory during builds.
  # Will only be non-`nil` inside {#install}.
  attr_reader :buildpath

  # The current working directory during tests.
  # Will only be non-`nil` inside {#test}.
  attr_reader :testpath

  # When installing a bottle (binary package) from a local path this will be
  # set to the full path to the bottle tarball. If not, it will be `nil`.
  # @private
  attr_accessor :local_bottle_path

  # The {BuildOptions} for this {Formula}. Lists the arguments passed and any
  # {#options} in the {Formula}. Note that these may differ at different times
  # during the installation of a {Formula}. This is annoying but the result of
  # state that we're trying to eliminate.
  # @return [BuildOptions]
  attr_accessor :build

  # @private
  def initialize(name, path, spec)
    @name = name
    @path = path
    @revision = self.class.revision || 0

    @full_name = if path.to_s =~ HOMEBREW_TAP_PATH_REGEX
        "#{$1}/#{$2.gsub(/^homebrew-/, '')}/#{name}"
      else
        name
      end

    set_spec :stable
    set_spec :devel
    set_spec :head

    @active_spec = determine_active_spec(spec)
    @active_spec_sym = if head?
        :head
      elsif devel?
        :devel
      else
        :stable
      end
    validate_attributes!
    @build = active_spec.build
    @pin = FormulaPin.new(self)
  end # initialize

  # @private
  def set_active_spec(spec_sym)
    spec = send(spec_sym)
    raise FormulaSpecificationError, "#{spec_sym} spec is not available for #{full_name}" unless spec
    @active_spec = spec
    @active_spec_sym = spec_sym
    validate_attributes!
    @build = active_spec.build
  end # set_active_spec

  private

  def set_spec(name)
    spec = self.class.send(name)
    if spec.url
      spec.owner = self
      instance_variable_set("@#{name}", spec)
    end
  end # set_spec

  def determine_active_spec(requested)
    spec = send(requested) || stable || devel || head
    spec || raise(FormulaSpecificationError, "formulae require at least a URL")
  end

  def validate_attributes!
    if name.nil? || name.empty? || name =~ /\s/
      raise FormulaValidationError.new(:name, name)
    end

    url = active_spec.url
    if url.nil? || url.empty? || url =~ /\s/
      raise FormulaValidationError.new(:url, url)
    end

    val = version.respond_to?(:to_s) ? version.to_s : version
    if val.nil? || val.empty? || val =~ /\s/
      raise FormulaValidationError.new(:version, val)
    end
  end # validate_attributes!

  public

  # Is the currently active {SoftwareSpec} a {#stable} build?
  # @private
  def stable?; active_spec == stable; end

  # Is the currently active {SoftwareSpec} a {#devel} build?
  # @private
  def devel?; active_spec == devel; end

  # Is the currently active {SoftwareSpec} a {#head} build?
  # @private
  def head?; active_spec == head; end

  # Is the only defined {SoftwareSpec} for a {#stable} build?
  def stable_only?; head.nil? and devel.nil?; end

  # Is the only defined {SoftwareSpec} for a {#devel} build?
  def devel_only?; head.nil? and stable.nil?; end

  # Is the only defined {SoftwareSpec} for a {#head} build?
  def head_only?; devel.nil? and stable.nil?; end

  # @private
  def bottle_unneeded?; active_spec.bottle_unneeded?; end

  # @private
  def bottle_disabled?; active_spec.bottle_disabled?; end

  # @private
  def bottle_disable_reason; active_spec.bottle_disable_reason; end

  # @private
  def bottled?; active_spec.bottled?; end

  # @private
  def bottle_specification; active_spec.bottle_specification; end

  # The Bottle object for the currently active {SoftwareSpec}.
  # @private
  def bottle; Bottle.new(self, bottle_specification) if bottled?; end

  # The description of the software.
  # @see .desc
  def desc; self.class.desc; end

  # The homepage for the software.
  # @see .homepage
  def homepage; self.class.homepage; end

  # The version for the currently active {SoftwareSpec}.
  # The version is autodetected from the URL and/or tag so only needs to be
  # declared if it cannot be autodetected correctly.
  # @see .version
  def version; active_spec.version; end

  # The {PkgVersion} for this formula with {version} and {#revision} information.
  def pkg_version; PkgVersion.new(version, revision); end

  # A named Resource for the currently active {SoftwareSpec}.
  # Additional downloads can be defined as {#resource}s.
  # {Resource#stage} will create a temporary directory and yield to a block.
  # <pre>resource("additional_files").stage { bin.install "my/extra/tool" }</pre>
  def resource(name); active_spec.resource(name); end

  # An old name for the formula
  def oldname
    @oldname ||= if core_formula?
        if FORMULA_RENAMES && FORMULA_RENAMES.value?(name)
          FORMULA_RENAMES.to_a.rassoc(name).first
        end
      elsif tap?
        user, repo = tap.split("/")
        formula_renames = Tap.fetch(user, repo.sub("homebrew-", "")).formula_renames
        if formula_renames.value?(name)
          formula_renames.to_a.rassoc(name).first
        end
      end
      puts "Formula #{name}’s old name was #{@oldname}" if DEBUG and @oldname

    @oldname
  end # oldname

  # The {Resource}s for the currently active {SoftwareSpec}.
  def resources; active_spec.resources.values; end

  # The {Dependency}s for the currently active {SoftwareSpec}.
  # @private
  def deps; active_spec.deps; end

  # The {Requirement}s for the currently active {SoftwareSpec}.
  # @private
  def requirements; active_spec.requirements; end

  # Any one member of a soft‐dependency group can be used to check for that
  # group’s presence, as the individual formulæ are only recorded when every
  # member of the group is present.
  def enhanced_by?(aid); active_spec.enhanced_by?(aid); end

  # The list of formulæ that, being known to be installed, will enhance the
  # currently active {SoftwareSpec}.
  # @private
  def active_enhancements; active_spec.active_enhancements; end

  # The complete list of formula‐groups that would enhance the currently
  # active {SoftwareSpec} if already installed.
  # @private
  def named_enhancements; active_spec.named_enhancements; end

  # The cached download for the currently active {SoftwareSpec}.
  # @private
  def cached_download; active_spec.cached_download; end

  # Deletes the download for the currently active {SoftwareSpec}.
  # @private
  def clear_cache; active_spec.clear_cache; end

  # The list of patches for the currently active {SoftwareSpec}.
  # @private
  def patchlist; active_spec.patches; end

  # The options for the currently active {SoftwareSpec}.
  # @private
  def options; active_spec.options; end

  # The deprecated options for the currently active {SoftwareSpec}.
  # @private
  def deprecated_options; active_spec.deprecated_options; end

  # The deprecated options _used_ for the currently active {SoftwareSpec}.
  # @private
  def deprecated_args; active_spec.deprecated_actuals; end

  # If a named option is defined for the currently active {SoftwareSpec}.
  def option_defined?(name); active_spec.option_defined?(name); end

  # All the {.fails_with} for the currently active {SoftwareSpec}.
  # @private
  def compiler_failures; active_spec.compiler_failures; end

  # If this {Formula} is installed.  Specifically, checks that the requested
  # (or else the active) current prefix is installed.
  # @private
  def installed?(spec = nil); is_installed_prefix?(spec ? spec_prefix(spec) : prefix); end

  # If at least one version of {Formula} is installed, no matter how outdated.
  # @private
  def any_version_installed?
    rack.directory? and rack.subdirs.any? { |keg| is_installed_prefix?(keg) }
  end

  # If some version of {Formula} is installed under its old name.
  # @private
  def oldname_installed?
    oldname and (oldrack = HOMEBREW_CELLAR/oldname) and oldrack.directory? \
      and oldrack.subdirs.any? { |keg| is_installed_prefix?(keg) }
  end

  # Returns HEAD (if present), or else the greatest version number among kegs in this rack.
  def greatest_installed_keg
    highest_seen = ''
    rack.subdirs.each do |keg|
      if is_installed_prefix?(keg)
        candidate = keg.basename
        if candidate == 'HEAD' then highest_seen = 'HEAD'; break; end
        highest_seen = candidate if candidate.to_s > highest_seen.to_s
      else
        raise RuntimeError, "#{keg} is located in a rack of kegs, but is not an installed keg"
      end
    end if rack.directory?
    raise RuntimeError, "#{name} is not installed." if highest_seen == ''
    Keg.new(rack/highest_seen)
  end # greatest_installed_keg

  # This {Formula}’s `LinkedKegs` directory.  You probably want {#opt_prefix} instead.
  # @private
  def linked_keg; LINKDIR/name; end

  # What would be the .prefix for the given SoftwareSpec?
  # @private
  def spec_prefix(ss)
    if spec = send(ss) then prefix(PkgVersion.new(spec.version, revision)); end
  end

  # The list of installed current spec versions
  def installed_current_prefixes
    icp = {}
    [:head, :devel, :stable].each do |ss|
      pfx = spec_prefix(ss)
      icp[ss] = pfx if is_installed_prefix?(pfx)
    end

    icp
  end # installed_current_prefixes

  private

  def is_installed_prefix?(pn); self.class.is_installed_prefix?(pn); end

  def self.is_installed_prefix?(pn); pn and pn.directory? and (pn/Tab::FILENAME).file?; end

  public

  def self.from_installed_prefix(pn)
    if is_installed_prefix?(pn)
      ts = Tab.from_file(pn/Tab::FILENAME)[:source]
      Formulary.factory(ts['path'], ts['spec'])
    end
  end # Formula::from_installed_prefix

  # The directory in the cellar that the formula is installed to.
  # This directory’s pathname includes the formula’s name and version.
  def prefix(v = pkg_version); HOMEBREW_CELLAR/name/v.to_s; end

  # The parent of the prefix; the named directory in the cellar containing all
  # installed versions of this software.
  # @private
  def rack; prefix.parent; end

  # The directory where the formula's binaries should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # Need to install into the {.bin} but the makefile doesn't mkdir -p prefix/bin?
  # <pre>bin.mkpath</pre>
  #
  # No `make install` available?
  # <pre>bin.install "binary1"</pre>
  def bin; prefix/'bin'; end

  # The directory where the formula's documentation should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  def doc; share/'doc'/name; end

  # The directory where the formula's headers should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # No `make install` available?
  # <pre>include.install "example.h"</pre>
  def include; prefix/'include'; end

  # The directory where the formula's info files should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  def info; share/'info'; end

  # The directory where the formula's libraries should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # No `make install` available?
  # <pre>lib.install "example.dylib"</pre>
  def lib; prefix/'lib'; end

  # The directory where the formula's binaries should be installed.
  # This is not symlinked into `HOMEBREW_PREFIX`.
  # It is also commonly used to install files that we do not wish to be
  # symlinked into HOMEBREW_PREFIX from one of the other directories and
  # instead manually create symlinks or wrapper scripts into e.g. {#bin}.
  def libexec; prefix/'libexec'; end

  # The root directory where the formula's manual pages should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  # Often one of the more specific `man` functions should be used instead
  # e.g. {#man1}
  def man; share/'man'; end

  # The directories where the formula's man/n/ pages should be installed,
  # where /n/ is a manual‐section number in the range 1 through 8.
  # These are symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # No `make install` available?
  # <pre>man1.install "example.1"</pre>
  1.upto(8).each do |n|
    define_method("man#{n}".to_sym) { man/"man#{n}" }
  end

  # The directory where the formula's `sbin` binaries should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  # Generally we try to migrate these to {#bin} instead.
  def sbin; prefix/'sbin'; end

  # The directory where the formula's shared files should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # Need a custom directory?
  # <pre>(share/"concept").mkpath</pre>
  #
  # Installing something into another custom directory?
  # <pre>(share/"concept2").install "ducks.txt"</pre>
  #
  # Install `./example_code/simple/ones` to share/demos
  # <pre>(share/"demos").install "example_code/simple/ones"</pre>
  #
  # Install `./example_code/simple/ones` to share/demos/examples
  # <pre>(share/"demos").install "example_code/simple/ones" => "examples"</pre>
  def share; prefix/'share'; end

  # The directory where the formula's shared files should be installed,
  # with the name of the formula appended to avoid linking conflicts.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  #
  # No `make install` available?
  # <pre>pkgshare.install "examples"</pre>
  def pkgshare; share/name; end

  # The directory where the formula's Frameworks should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  # This is not symlinked into `HOMEBREW_PREFIX`.
  def frameworks; prefix/'Frameworks'; end

  # The directory where the formula's kernel extensions should be installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  # This is not symlinked into `HOMEBREW_PREFIX`.
  def kext_prefix; prefix/'Library/Extensions'; end

  # The directory where the formula's configuration files should be installed.
  # Anything using `etc.install` will not overwrite other files on e.g. upgrades
  # but will write a new file named `*.default`.
  # This directory is not inside the `HOMEBREW_CELLAR` so it is persisted
  # across upgrades.
  def etc; (HOMEBREW_PREFIX/'etc').extend(InstallRenamed); end

  # The directory where the formula's variable files should be installed.
  # This directory is not inside the `HOMEBREW_CELLAR` so it is persisted
  # across upgrades.
  def var; HOMEBREW_PREFIX/'var'; end

  # The directory where the formula's Bash completion files should be
  # installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  def bash_completion; prefix/'etc/bash_completion.d'; end

  # The directory where the formula's fish completion files should be
  # installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  def fish_completion; share/'fish/vendor_completions.d'; end

  # The directory where the formula's ZSH completion files should be
  # installed.
  # This is symlinked into `HOMEBREW_PREFIX` after installation or with
  # `brew link` for formulae that are not keg-only.
  def zsh_completion; share/'zsh/site-functions'; end

  # The directory used for as the prefix for {#etc} and {#var} files on
  # installation so, despite not being in `HOMEBREW_CELLAR`, they are installed
  # there after pouring a bottle.
  # @private
  def bottle_prefix; prefix/'.bottle'; end

  # The directory where the formula's installation logs will be written.
  # @private
  def logs; HOMEBREW_LOGS/name; end

  # This method can be overridden to provide a plist.
  # For more examples read Apple's handy manpage:
  # https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man5/plist.5.html
  # <pre>def plist; <<-EOS.undent
  #  <?xml version="1.0" encoding="UTF-8"?>
  #  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  #  <plist version="1.0">
  #  <dict>
  #    <key>Label</key>
  #      <string>#{plist_name}</string>
  #    <key>ProgramArguments</key>
  #    <array>
  #      <string>#{opt_bin}/example</string>
  #      <string>--do-this</string>
  #    </array>
  #    <key>RunAtLoad</key>
  #    <true/>
  #    <key>KeepAlive</key>
  #    <true/>
  #    <key>StandardErrorPath</key>
  #    <string>/dev/null</string>
  #    <key>StandardOutPath</key>
  #    <string>/dev/null</string>
  #  </plist>
  #  EOS
  #end</pre>
  def plist; nil; end
  alias_method :startup_plist, :plist

  # The {.plist} name (the name of the launchd service).
  def plist_name; 'leopardbrew.gsteemso.'+name; end

  def plist_path; prefix/(plist_name+'.plist'); end

  # @private
  def plist_manual; self.class.plist_manual; end

  # @private
  def plist_startup; self.class.plist_startup; end

  # A stable path for this formula, when installed. Contains the formula name
  # but no version number. Only the active version will be linked here if
  # multiple versions are installed.
  #
  # This is the prefered way to refer a formula in plists or from another
  # formula, as the path is stable even when the software is updated.
  # <pre>args << "--with-readline=#{Formula["readline"].opt_prefix}" if build.with? "readline"</pre>
  def opt_prefix; OPTDIR/name; end

  %w[bin include lib libexec sbin share Frameworks].each do |dir|
    define_method("opt_#{dir}".downcase) { opt_prefix/dir }
  end

  def opt_pkgshare; opt_share/name; end

  # Can be overridden to selectively disable bottles from formulae.
  # Defaults to true so overridden version does not have to check if bottles
  # are supported.
  def pour_bottle?; true; end

  # Can be overridden to run commands on both source and bottle installation.
  def post_install; end

  # @private
  def post_install_defined?
    self.class.public_instance_methods(false).map(&:to_s).include?("post_install")
  end

  # @private
  def run_post_install
    build, self.build = self.build, Tab.for_formula(self)
    post_install
  ensure
    self.build = build
  end # run_post_install

  # Tell the user about any caveats regarding this package.
  # @return [String]
  # <pre>def caveats
  #   <<-EOS.undent
  #     Are optional. Something the user should know?
  #   EOS
  # end</pre>
  #
  # <pre>def caveats
  #   s = <<-EOS.undent
  #     Print some important notice to the user when `brew info <formula>` is
  #     called or when brewing a formula.
  #     This is optional. You can use all the vars like #{version} here.
  #   EOS
  #   s += "Some issue only on older systems" if MacOS.version < :mountain_lion
  #   s
  # end</pre>
  def caveats; nil; end

  # rarely, you don't want your library symlinked into HOMEBREW_PREFIX
  # see curl.rb for an example
  def keg_only?; keg_only_reason and keg_only_reason.valid?; end

  # @private
  def keg_only_reason; self.class.keg_only_reason; end

  # sometimes the formula cleaner breaks things
  # skip cleaning paths in a formula with a class method like this:
  #   skip_clean "bin/foo", "lib/bar"
  # keep .la files with:
  #   skip_clean :la
  # @private
  def skip_clean?(path)
    return true if path.extname == ".la" && self.class.skip_clean_paths.include?(:la)
    to_check = path.relative_path_from(prefix).to_s
    self.class.skip_clean_paths.include? to_check
  end

  # Sometimes we accidentally install files outside prefix. After we fix that,
  # users will get nasty link conflict error. So we create a whitelist here to
  # allow overwriting certain files. e.g.
  #   link_overwrite "bin/foo", "lib/bar"
  #   link_overwrite "share/man/man1/baz-*"
  # @private
  def link_overwrite?(path)
    # Don't overwrite files not created by Homebrew.
    return false unless path.stat.uid == File.stat(HOMEBREW_BREW_FILE).uid
    # Don't overwrite files belong to other keg.
    begin
      Keg.for(path)
    rescue NotAKegError, Errno::ENOENT
      # file doesn't belong to any keg.
    else
      return false
    end
    to_check = path.relative_path_from(HOMEBREW_PREFIX).to_s
    self.class.link_overwrite_paths.any? do |p|
      p == to_check ||
        to_check.starts_with?(p.chomp("/") + "/") ||
        /^#{Regexp.escape(p).gsub('\*', ".*?")}$/ === to_check
    end
  end # link_overwrite?

  def skip_cxxstdlib_check?; false; end

  # @private
  def require_universal_deps?; false; end

  # @private
  def patch
    unless patchlist.empty?
      ohai "Patching"
      patchlist.each(&:apply)
    end
  end

  # yields self with current working directory set to the uncompressed tarball
  # @private
  def brew
    stage do
      prepare_patches

      begin
        yield self
      ensure
        # the `open` inside `cp` should not be able to fail; when it does, it
        # torpedoes the entire install.  Thus a `rescue` clause, to loop until
        # it either succeeds or has failed so often it should be given up on.
        count = 0
        begin
          count += 1; cp Dir["{config.log,CMakeCache.txt}"], logs
        rescue
          retry unless count >= 5
          puts 'unable to copy configuration logs'
        end
      end
    end
  end # brew

  # @private
  def lock
    @lock = FormulaLock.new(name)
    @lock.lock
    if (on = oldname) and (on_rack = HOMEBREW_CELLAR/on).exists? and on_rack.resolved_path == rack
      @oldname_lock = FormulaLock.new(on)
      @oldname_lock.lock
    end
  end # lock

  # @private
  def unlock
    @lock.unlock unless @lock.nil?
    @oldname_lock.unlock unless @oldname_lock.nil?
  end

  # @private
  def pinnable?; @pin.pinnable?; end

  # @private
  def pinned?; @pin.pinned?; end

  # @private
  def pin; @pin.pin; end

  # @private
  def unpin; @pin.unpin; end

  # @private
  def ==(other)
    instance_of?(other.class) and
      name == other.name and
      active_spec == other.active_spec
  end
  alias_method :eql?, :==

  # @private
  def hash; name.hash; end

  # @private
  def <=>(other)
    return unless Formula === other
    name <=> other.name
  end

  def to_s; name; end

  # @private
  def inspect; "#<Formula #{name} (#{active_spec_sym}) #{path}>"; end

  # Standard parameters for CMake builds.
  # Setting CMAKE_FIND_FRAMEWORK to "LAST" tells CMake to search for our
  # libraries before trying to utilize Frameworks, many of which will be from
  # 3rd party installs.
  # Note: there isn't a std_autotools variant because autotools is a lot
  # less consistent and the standard parameters are more memorable.
  def std_cmake_args
    %W[
      -DCMAKE_C_FLAGS_RELEASE=
      -DCMAKE_CXX_FLAGS_RELEASE=
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -Wno-dev
    ]
  end # std_cmake_args

  # an array of all core {Formula} names
  # @private
  def self.core_names
    @core_names ||= core_files.map { |f| f.basename(".rb").to_s }.sort
  end

  # an array of all core {Formula} files
  # @private
  def self.core_files
    @core_files ||= Pathname.glob("#{HOMEBREW_LIBRARY}/Formula/*.rb")
  end

  # an array of all tap {Formula} names
  # @private
  def self.tap_names; @tap_names ||= Tap.flat_map(&:formula_names).sort; end

  # an array of all tap {Formula} files
  # @private
  def self.tap_files; @tap_files ||= Tap.flat_map(&:formula_files); end

  # an array of all {Formula} names
  # @private
  def self.names
    @names ||= (core_names + tap_names.map { |name| name.split("/")[-1] }).uniq.sort
  end

  # an array of all {Formula} files
  # @private
  def self.files; @files ||= core_files + tap_files; end

  # an array of all {Formula} names, which the tap formulae have the fully-qualified name
  # @private
  def self.full_names; @full_names ||= core_names + tap_names; end

  # @private
  def self.each
    files.each do |file|
      begin
        yield Formulary.factory(file)
      rescue StandardError => e
        # Don't let one broken formula break commands. But do complain.
        onoe "Failed to import: #{file}"
        puts e
        next
      end
    end
  end # Formula::each

  # An array of all racks currently installed.
  # @private
  def self.racks
    @racks ||= (HOMEBREW_CELLAR.directory? ? HOMEBREW_CELLAR.subdirs.reject(&:symlink?) : [])
  end

  # An array of all installed {Formula}
  # @private
  def self.installed
    @installed ||= racks.map do |rack|
      begin
        Formulary.from_rack(rack)
      rescue FormulaUnavailableError, TapFormulaAmbiguityError
      end
    end.compact
  end # Formula::installed

  # an array of all core aliases
  # @private
  def self.core_aliases
    @core_aliases ||= Dir["#{HOMEBREW_LIBRARY}/Aliases/*"].map { |f| File.basename f }.sort
  end

  # an array of all tap aliases
  # @private
  def self.tap_aliases; @tap_aliases ||= Tap.flat_map(&:aliases).sort; end

  # an array of all aliases
  # @private
  def self.aliases
    @aliases ||= (core_aliases + tap_aliases.map { |name| name.split("/")[-1] }).uniq.sort
  end

  # an array of all aliases, , which the tap formulae have the fully-qualified name
  # @private
  def self.alias_full_names; @alias_full_names ||= core_aliases + tap_aliases; end

  def self.[](name); Formulary.factory(name); end

  # @private
  def tap?; HOMEBREW_TAP_DIR_REGEX === path; end

  # @private
  def tap
    if path.to_s =~ HOMEBREW_TAP_DIR_REGEX
      "#{$1}/#{$2}"
    elsif core_formula?
      "mistydemeo/tigerbrew"
    end
  end # tap

  # @private
  def print_tap_action(options = {})
    if tap?
      verb = options[:verb] || "Installing"
      ohai "#{verb} #{name} from #{tap}"
    end
  end # print_tap_action

  # True if this formula is provided by Homebrew itself
  # @private
  def core_formula?; path == Formulary.core_path(name); end

  # @private
  def env; self.class.env; end

  # @private
  def conflicts; self.class.conflicts; end

  # Returns a list of Dependency objects in an installable order, which
  # means if a depends on b then b will be ordered before a in this list
  # @private
  def recursive_dependencies(&block); Dependency.expand(self, &block); end

  # The full set of Requirements for this formula's dependency tree.
  # @private
  def recursive_requirements(&block); Requirement.expand(self, &block); end

  # @private
  def to_hash
    hsh = {
      "name" => name,
      "full_name" => full_name,
      "desc" => desc,
      "homepage" => homepage,
      "oldname" => oldname,
      "versions" => {
        "stable" => (stable.version.to_s if stable),
        "bottle" => bottle ? true : false,
        "devel" => (devel.version.to_s if devel),
        "head" => (head.version.to_s if head)
      },
      "revision" => revision,
      "installed" => [],
      "linked_keg" => (linked_keg.resolved_path.basename.to_s if linked_keg.exist?),
      "keg_only" => keg_only?,
      "dependencies" => deps.map(&:name).uniq,
      "conflicts_with" => conflicts.map(&:name),
      "caveats" => caveats
    }
    hsh["requirements"] = requirements.map do |req|
        {
          "name" => req.name,
          "default_formula" => req.default_formula,
          "cask" => req.cask,
          "download" => req.download
        }
      end
    hsh["options"] = options.map do |opt|
        { "option" => opt.flag, "description" => opt.description }
      end
    hsh["bottle"] = {}
    %w[stable devel].each do |spec_sym|
        next unless spec = send(spec_sym)
        next unless (bottle_spec = spec.bottle_specification).checksums.any?
        bottle_info = {
          "revision" => bottle_spec.revision,
          "cellar" => (cellar = bottle_spec.cellar).is_a?(Symbol) ? \
                      cellar.inspect : cellar,
          "prefix" => bottle_spec.prefix,
          "root_url" => bottle_spec.root_url,
        }
        bottle_info["files"] = {}
        bottle_spec.collector.keys.each do |os|
            checksum = bottle_spec.collector[os]
            bottle_info["files"][os] = {
              "url" => "#{bottle_spec.root_url}/#{Bottle::Filename.create(self, os, bottle_spec.revision)}",
              checksum.hash_type.to_s => checksum.hexdigest,
            }
          end
        hsh["bottle"][spec_sym] = bottle_info
      end
    if rack.directory?
      rack.subdirs.each do |keg_path|
          keg = Keg.new keg_path
          tab = Tab.for_keg keg_path

          hsh["installed"] << {
            "version" => keg.version.to_s,
            "used_options" => tab.used_options.as_flags,
            "built_as_bottle" => tab.built_bottle,
            "poured_from_bottle" => tab.poured_from_bottle
          }
        end
      hsh["installed"] = hsh["installed"].sort_by { |i| Version.new(i["version"]) }
    end

    hsh
  end # to_hash

  # @private
  def fetch; active_spec.fetch; end

  # @private
  def verify_download_integrity(fn); active_spec.verify_download_integrity(fn); end

  # The `test` command must set up the ’brew build environment, arrange to use
  # the exact same ARGV and build options as during the original brewing, &c.
  # @private
  def run_test
    old_home = ENV["HOME"]
    mktemp do
      @testpath = Pathname.pwd
      ENV["HOME"] = @testpath
      setup_test_home @testpath
      result = test
      if result == :does_not_apply
        puts 'This formula produces no executable code, so it cannot meaningfully be tested.'
        true
      else
        result
      end
    end
  ensure
    @testpath = nil
    ENV["HOME"] = old_home
  end # run_test

  # @private
  def test_defined?; false; end

  def test_fixtures(file); (HOMEBREW_LIBRARY_PATH/'test/fixtures')/file; end

  # This method is overriden in {Formula} subclasses to provide the installation instructions.
  # The sources (from {.url}) are downloaded, hash-checked and
  # Homebrew changes into a temporary directory where the
  # archive was unpacked or repository cloned.
  # <pre>def install
  #   system "./configure", "--prefix=#{prefix}"
  #   system "make", "install"
  # end</pre>
  def install; end

  # These methods must be likewise overridden, in such formulæ as need to carry out some action
  # to very deeply integrate with the system upon installation, and then to remove that integration
  # before formula uninstallation is safe.  THESE METHODS MUST BE IDEMPOTENT!  It is not only
  # possible, but actively expected, for them to be called more than once without their counterpart
  # being called in between, in which case they must not make a mess!
  def insinuate; end

  def uninsinuate; end

  protected

  def setup_test_home(home)
    # keep Homebrew's site-packages in sys.path when testing with system Python
    user_site_packages = home/"Library/Python/2.7/lib/python/site-packages"
    user_site_packages.mkpath
    (user_site_packages/"homebrew.pth").write <<-EOS.undent
      import site; site.addsitedir("#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
      import sys; sys.path.insert(0, "#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
    EOS
  end # setup_test_home

  public

  # To call out to the system, we use the `system` method and we prefer
  # you give the args separately as in the line below, otherwise a subshell
  # has to be opened first.
  # <pre>system "./bootstrap.sh", "--arg1", "--prefix=#{prefix}"</pre>
  #
  # For CMake we have some necessary defaults in {#std_cmake_args}:
  # <pre>system "cmake", ".", *std_cmake_args</pre>
  #
  # If the arguments given to configure (or make or cmake) are depending
  # on options defined above, we usually make a list first and then
  # use the `args << if <condition>` to append to:
  # <pre>args = ["--with-option1", "--with-option2"]
  #
  # # Most software still uses `configure` and `make`.
  # # Check with `./configure --help` what our options are.
  # system "./configure", "--prefix=#{prefix}", "--disable-debug",
  #                       "--disable-dependency-tracking", "--disable-silent-rules",
  #                       *args  # our custom arg list (needs `*` to unpack)
  #
  # # If there is a "make", "install" available, please use it!
  # system "make", "install"</pre>
  def system(cmd, *args)
    verbose_using_dots = !ENV["HOMEBREW_VERBOSE_USING_DOTS"].nil?

    # remove "boring" arguments so that the important ones are more likely to
    # be shown considering that we trim long ohai lines to the terminal width
    pretty_args = args.dup
    if cmd == "./configure" && !VERBOSE
      pretty_args.delete "--disable-dependency-tracking"
      pretty_args.delete "--disable-debug"
    end
    pretty_args.each_index do |i|
      if pretty_args[i].to_s.start_with? "import setuptools"
        pretty_args[i] = "import setuptools..."
      end
    end
    ohai "#{cmd} #{pretty_args*" "}".strip

    @exec_count ||= 0
    @exec_count += 1
    logfn = "#{logs}/%02d.%s" % [@exec_count, File.basename(cmd).split(" ").first]
    logs.mkpath

    File.open(logfn, "w") do |log|
      log.puts Time.now, "", cmd, args, ""
      log.flush

      if VERBOSE
        rd, wr = IO.pipe
        begin
          pid = fork do
            rd.close
            log.close
            exec_cmd(cmd, args, wr, logfn)
          end
          wr.close

          if verbose_using_dots
            last_dot = Time.at(0)
            while buf = rd.gets
              log.puts buf
              # make sure dots printed with interval of at least 1 min.
              if (Time.now - last_dot) > 60
                print "."
                $stdout.flush
                last_dot = Time.now
              end
            end
            puts
          else
            while buf = rd.gets
              log.puts buf
              puts buf
            end
          end
        ensure
          rd.close
        end
      else
        pid = fork { exec_cmd(cmd, args, log, logfn) }
      end

      Process.wait(pid)

      $stdout.flush

      unless $?.success?
        log_lines = ENV["HOMEBREW_FAIL_LOG_LINES"]
        log_lines ||= "15"

        log.flush
        if !VERBOSE || verbose_using_dots
          puts "Last #{log_lines} lines from #{logfn}:"
          Kernel.system "/usr/bin/tail", "-n", log_lines, logfn
        end
        log.puts

        require "cmd/config"
        require "cmd/--env"

        env = ENV.to_hash

        Homebrew.dump_verbose_config(log)
        log.puts
        Homebrew.dump_build_env(env, log)

        raise BuildError.new(self, cmd, args, env)
      end
    end
  end # system

  # use these for running `make check`:
  def bombed_system?(cmd, *args)
    ohai "#{cmd} #{args * ' '}".strip
    Homebrew._system(cmd, *args) ? false : $?.exitstatus
  end

  def bombproof_system(cmd, *args); not bombed_system?(cmd, *args); end

  private

  def exec_cmd(cmd, args, out, logfn)
    ENV["HOMEBREW_CC_LOG_PATH"] = logfn

    # TODO: system "xcodebuild" is deprecated, this should be removed soon.
    if cmd.to_s.start_with? "xcodebuild"
      ENV.remove_cc_etc
    end

    # Turn on argument filtering in the superenv compiler wrapper.
    # We should probably have a better mechanism for this than adding
    # special cases to this method.
    if cmd == "python"
      setup_py_in_args = %w[setup.py build.py].include?(args.first)
      setuptools_shim_in_args = args.any? { |a| a.to_s.start_with? "import setuptools" }
      if setup_py_in_args || setuptools_shim_in_args
        ENV.refurbish_args
      end
    end

    $stdout.reopen(out)
    $stderr.reopen(out)
    out.close
    args.collect!(&:to_s)
    exec(cmd, *args) rescue nil
    puts "Failed to execute: #{cmd}"
    exit! 1 # never gets here unless exec threw or failed
  end # exec_cmd

  def stage
    active_spec.stage do
      @buildpath = Pathname.pwd
      env_home = buildpath/".brew_home"
      mkdir_p env_home
      old_home, ENV["HOME"] = ENV["HOME"], env_home
      begin
        yield
      ensure
        @buildpath = nil
        ENV["HOME"] = old_home
      end
    end
  end # stage

  def prepare_patches
    active_spec.add_legacy_patches(patches) if respond_to?(:patches)
    patchlist.grep(DATAPatch) { |p| p.path = path }
    patchlist.each { |p| p.verify_download_integrity(p.fetch) if p.external? }
  end

  def self.method_added(method)
    case method
      when :brew
        raise "You cannot override Formula#brew in class #{name}"
      when :test
        define_method(:test_defined?) { true }
      when :options
        instance = allocate

        specs.each do |spec|
          instance.options.each do |opt, desc|
            spec.option(opt[/^--(.+)$/, 1], desc)
          end
        end

        remove_method(:options)
    end
  end # Formula::method_added

  # The methods below define the formula DSL.
  class << self
    include BuildEnvironmentDSL

    # The reason for why this software is not linked (by default) to
    # {::HOMEBREW_PREFIX}.
    # @private
    attr_reader :keg_only_reason

    # @!attribute [w] license
    # The SPDX ID of the open-source license that the formula uses.
    # Shows when running `brew info`.
    # Use `:any_of`, `:all_of` or `:with` to describe complex license expressions.
    # `:any_of` should be used when the user can choose which license to use.
    # `:all_of` should be used when the user must use all licenses.
    # `:with` should be used to specify a valid SPDX exception.
    # Add `+` to an identifier to indicate that the formulae can be
    # licensed under later versions of the same license.
    # @see https://docs.brew.sh/License-Guidelines Homebrew License Guidelines
    # @see https://spdx.github.io/spdx-spec/appendix-IV-SPDX-license-expressions/ SPDX license expression guide
    # <pre>license "BSD-2-Clause"</pre>
    # <pre>license "EPL-1.0+"</pre>
    # <pre>license any_of: ["MIT", "GPL-2.0-only"]</pre>
    # <pre>license all_of: ["MIT", "GPL-2.0-only"]</pre>
    # <pre>license "GPL-2.0-only" => { with: "LLVM-exception" }</pre>
    # <pre>license :public_domain</pre>
    # <pre>license any_of: [
    #   "MIT",
    #   :public_domain,
    #   all_of: ["0BSD", "Zlib", "Artistic-1.0+"],
    #   "Apache-2.0" => { with: "LLVM-exception" },
    # ]</pre>
    def license(args = nil); args.nil? ? @licenses : @licenses = args; end

    # @!attribute [w]
    # A one-line description of the software. Used by users to get an overview
    # of the software and Homebrew maintainers.
    # Shows when running `brew info`.
    #
    # <pre>desc "Example formula"</pre>
    attr_rw :desc

    # @!attribute [w] homepage
    # The homepage for the software. Used by users to get more information
    # about the software and Homebrew maintainers as a point of contact for
    # e.g. submitting patches.
    # Can be opened with running `brew home`.
    #
    # <pre>homepage "https://www.example.com"</pre>
    attr_rw :homepage

    # The `:startup` attribute set by {.plist_options}.
    # @private
    attr_reader :plist_startup

    # The `:manual` attribute set by {.plist_options}.
    # @private
    attr_reader :plist_manual

    # @!attribute [w] revision
    # Used for creating new Homebrew versions of software without new upstream
    # versions. For example, if we bump the major version of a library this
    # {Formula} {.depends_on} then we may need to update the `revision` of this
    # {Formula} to install a new version linked against the new library version.
    # `0` if unset.
    #
    # <pre>revision 1</pre>
    attr_rw :revision

    # A list of the {.stable}, {.devel} and {.head} {SoftwareSpec}s.
    # @private
    def specs; @specs ||= [stable, devel, head].freeze; end

    # @!attribute [w] url
    # The URL used to download the source for the {#stable} version of the formula.
    # We prefer `https` for security and proxy reasons.
    # Optionally specify the download strategy with `:using => ...`
    #     `:git`, `:hg`, `:svn`, `:bzr`, `:cvs`,
    #     `:curl` (normal file download. Will also extract.)
    #     `:nounzip` (without extracting)
    #     `:post` (download via an HTTP POST)
    #     `S3DownloadStrategy` (download from S3 using signed request)
    #
    # <pre>url "https://packed.sources.and.we.prefer.https.example.com/archive-1.2.3.tar.bz2"</pre>
    # <pre>url "https://some.dont.provide.archives.example.com", :using => :git, :tag => "1.2.3"</pre>
    def url(val, specs = {}); stable.url(val, specs); end

    # @!attribute [w] version
    # The version string for the {#stable} version of the formula.
    # The version is autodetected from the URL and/or tag so only needs to be
    # declared if it cannot be autodetected correctly.
    #
    # <pre>version "1.2-final"</pre>
    def version(val = nil); stable.version(val); end

    # @!attribute [w] mirror
    # Additional URLs for the {#stable} version of the formula.
    # These are only used if the {.url} fails to download. It's optional and
    # there can be more than one. Generally we add them when the main {.url}
    # is unreliable. If {.url} is really unreliable then we may swap the
    # {.mirror} and {.url}.
    #
    # <pre>mirror "https://in.case.the.host.is.down.example.com"
    # mirror "https://in.case.the.mirror.is.down.example.com</pre>
    def mirror(val); stable.mirror(val); end

    # @!attribute [w] sha256
    # @scope class
    # To verify the {#cached_download}'s integrity and security we verify the
    # SHA-256 hash matches what we've declared in the {Formula}. To quickly fill
    # this value you can leave it blank and run `brew fetch --force` and it'll
    # tell you the currently valid value.
    #
    # <pre>sha256 "2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7"</pre>
    Checksum::TYPES.each do |type|
      define_method(type) { |val| stable.send(type, val) }
    end

    # @!attribute [w] bottle
    # Adds a {.bottle} {SoftwareSpec}.
    # This provides a pre-built binary package built by the Homebrew maintainers for you.
    # It will be installed automatically if there is a binary package for your platform and you
    # haven't passed or previously used any options on this formula.  If you maintain your own
    # repository, you can add your own bottle links.
    # https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Bottles.md
    # You can ignore this block entirely if submitting to Homebrew/Homebrew, It'll be
    # handled for you by the Brew Test Bot.
    #
    # <pre>bottle do
    #   root_url "http://example.com" # Optional root to calculate bottle URLs
    #   prefix "/opt/homebrew" # Optional HOMEBREW_PREFIX in which the bottles were built.
    #   cellar "/opt/homebrew/Cellar" # Optional HOMEBREW_CELLAR in which the bottles were built.
    #   revision 1 # Making the old bottle outdated without bumping the version/revision of the formula.
    #   sha256 "4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865" => :yosemite
    #   sha256 "53c234e5e8472b6ac51c1ae1cab3fe06fad053beb8ebfd8977b010655bfdd3c3" => :mavericks
    #   sha256 "1121cfccd5913f0a63fec40a6ffd44ea64f9dc135c66634ba001d10bcf4302a2" => :mountain_lion
    # end</pre>
    #
    # For formulae which don't require compiling, you can tag them with:
    # <pre>bottle :unneeded</pre>
    #
    # To disable bottle for other reasons.
    # <pre>bottle :disable, "reasons"</pre>
    def bottle(*args, &block); stable.bottle(*args, &block); end

    # @private
    def build; stable.build; end

    # @!attribute [w] stable
    # Allows adding {.depends_on} and {#patch}es just to the {.stable} {SoftwareSpec}.
    # This is required instead of using a conditional.
    # It is preferrable to also pull the {url} and {.sha256} into the block if one is added.
    #
    # <pre>stable do
    #   url "https://example.com/foo-1.0.tar.gz"
    #   sha256 "2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7"
    #
    #   depends_on "libxml2"
    #   depends_on "libffi"
    # end</pre>
    def stable(&block)
      @stable ||= SoftwareSpec.new
      return @stable unless block_given?
      @stable.instance_eval(&block)
    end

    # @!attribute [w] devel
    # Adds a {.devel} {SoftwareSpec}.
    # This can be installed by passing the `--devel` option to allow
    # installing non-stable (e.g. beta) versions of software.
    #
    # <pre>devel do
    #   url "https://example.com/archive-2.0-beta.tar.gz"
    #   sha256 "2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7"
    #
    #   depends_on "cairo"
    #   depends_on "pixman"
    # end</pre>
    def devel(&block)
      @devel ||= SoftwareSpec.new
      return @devel unless block_given?
      @devel.instance_eval(&block)
    end

    # @!attribute [w] head
    # Adds a {.head} {SoftwareSpec}.
    # This can be installed by passing the `--HEAD` option to allow
    # installing software directly from a branch of a version-control repository.
    # If called as a method this provides just the {url} for the {SoftwareSpec}.
    # If a block is provided you can also add {.depends_on} and {#patch}es just to the {.head} {SoftwareSpec}.
    # The download strategies (e.g. `:using =>`) are the same as for {url}.
    # `master` is the default branch and doesn't need stating with a `:branch` parameter.
    # <pre>head "https://we.prefer.https.over.git.example.com/.git"</pre>
    # <pre>head "https://example.com/.git", :branch => "name_of_branch", :revision => "abc123"</pre>
    # or (if autodetect fails):
    # <pre>head "https://hg.is.awesome.but.git.has.won.example.com/", :using => :hg</pre>
    def head(val = nil, specs = {}, &block)
      @head ||= HeadSoftwareSpec.new
      if block_given?
        @head.instance_eval(&block)
      elsif val
        @head.url(val, specs)
      else
        @head
      end
    end # head

    # Additional downloads can be defined as resources and accessed in the
    # install method. Resources can also be defined inside a stable, devel, or
    # head block. This mechanism replaces ad-hoc "subformula" classes.
    # <pre>resource "additional_files" do
    #   url "https://example.com/additional-stuff.tar.gz"
    #   sha256 "c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2"
    # end</pre>
    def resource(name, klass = Resource, &block)
      specs.each do |spec|
        spec.resource(name, klass, &block) unless spec.resource_defined?(name)
      end
    end

    def go_resource(name, &block)
      specs.each { |spec| spec.go_resource(name, &block) }
    end

    # The dependencies for this formula. Use strings for the names of other
    # formulae. Homebrew provides some :special dependencies for stuff that
    # requires certain extra handling (often changing some ENV vars or
    # deciding if to use the system provided version or not.)
    # <pre># `:build` means this dep is only needed during build.
    # depends_on "cmake" => :build</pre>
    # <pre>depends_on "homebrew/dupes/tcl-tk" => :optional</pre>
    # <pre># `:recommended` dependencies are built by default.
    # # But a `--without-...` option is generated to opt-out.
    # depends_on "readline" => :recommended</pre>
    # <pre># `:optional` dependencies are NOT built by default.
    # # But a `--with-...` options is generated.
    # depends_on "glib" => :optional</pre>
    # <pre># If you need to specify that another formula has to be built with/out
    # # certain options (note, no `--` needed before the option):
    # depends_on "zeromq" => "with-pgm"
    # depends_on "qt" => ["with-qtdbus", "developer"] # Multiple options.</pre>
    # <pre># Optional and enforce that boost is built with `--with-c++11`.
    # depends_on "boost" => [:optional, "with-c++11"]</pre>
    # <pre># If a dependency is only needed in certain cases:
    # depends_on "sqlite" if MacOS.version == :leopard
    # depends_on :xcode # If the formula really needs full Xcode.
    # depends_on :tex # Homebrew does not provide a Tex Distribution.
    # depends_on :fortran # Checks that `gfortran` is available or `FC` is set.
    # depends_on :mpi => :cc # Needs MPI with `cc`
    # depends_on :mpi => [:cc, :cxx, :optional] # Is optional. MPI with `cc` and `cxx`.
    # depends_on :macos => :lion # Needs at least Mac OS X "Lion" aka. 10.7.
    # depends_on :apr # If a formula requires the CLT-provided apr library to exist.
    # depends_on :arch => :intel # If this formula only builds on Intel architecture.
    # depends_on :arch => :x86_64 # If this formula only builds on Intel x86 64-bit.
    # depends_on :arch => :ppc # Only builds on PowerPC?
    # depends_on :ld64 # Sometimes ld fails on `MacOS.version < :leopard`. Then use this.
    # depends_on :x11 # X11/XQuartz components.  Non-optional X11 deps should go in Homebrew/Homebrew-x11
    # depends_on :osxfuse # Permits the use of the upstream signed binary or our source package.
    # depends_on :tuntap # Does the same thing as above. This is vital for Yosemite and above.
    # depends_on :mysql => :recommended</pre>
    # <pre># It is possible to only depend on something if
    # # `build.with?` or `build.without? "another_formula"`:
    # depends_on :mysql # allows brewed or external mysql to be used
    # depends_on :postgresql if build.without? "sqlite"
    # depends_on :hg # Mercurial (external or brewed) is needed</pre>
    # <pre># If any Python >= 2.7 < 3.x is okay (either from OS X or brewed):
    # depends_on :python</pre>
    # <pre># to depend on Python >= 2.7 but use system Python where possible
    # depends_on :python if MacOS.version <= :snow_leopard</pre>
    # <pre># Python 3.x if the `--with-python3` is given to `brew install example`
    # depends_on :python3 => :optional</pre>
    # # depends_on also accepts an array of strings and/or symbols.  Internally, it
    # # converts such an array to a succession of individual depends_on statements.
    def depends_on(dep); specs.each { |spec| spec.depends_on(dep) }; end

    # # Define a set of alternate dependencies, only one of which is to be selectable.
    # # If the set is required, pass the array of alternates.  Otherwise, pass a one‐
    # # element hash; the key MUST be the two‐element array ['set-name', priority],
    # # where “priority” must be either “:optional” or “:recommended”.
    # depends_on_one ['ssl', ':optional'] => ['openssl3', 'libressl']
    # # The above generates the mutually exclusive options
    # --with-openssl3
    # --with-libressl
    # # The conditional “build.with?('ssl')” is generated as shorthand for
    # # “build.with?('openssl3') or build.with?('libressl')”, and “build.without?('ssl')”
    # # for “build.without?('openssl3') and build.without?('libressl')”.
    # depends_on_one ['ssl', :recommended] => ['openssl3', 'libressl']
    # # The above generates the mutually exclusive options
    # --with-openssl3
    # --with-libressl
    # --without-ssl
    # # The normal, autogenerated “build.with? 'ssl'” is shorthand for
    # # “build.with? 'openssl3' or build.with? 'libressl'”.
    # # If none of them is used, the first of the alternates listed is chosen by
    # # default.
    # depends_on_one ['transport_security', :required] => ['ssl', 'gnutls']
    # # or
    # depends_on_one ['ssl', 'gnutls']
    # # each generate the option
    # --with-gnutls
    # # in addition to whatever was generated for the 'ssl' set.
    # # If none of the options is used, the first of the alternates listed is chosen
    # # by default.  In this case, since it was another set, the default for that set
    # # is chosen.  Note that the set name goes unused in this case.
#    def depends_on_one(set); specs.each { |spec| spec.depends_on_one(set) }; end

    # # Define a group of dependencies selectable by a single option.  Pass it a one‐
    # # element hash.  The key MUST be the element-pair ['group-name', priority],
    # # where “priority” must be either “:optional” or “:recommended”.
    # depends_group ['more-dns', :recommended] => ['c-ares', 'ibidn2, 'libpsl']
    def depends_group(group); specs.each { |spec| spec.depends_group(group) }; end

    # Soft dependencies (those which can be omitted if need be, in order to
    # avoid dependency loops) are to be indicated with “enhanced_by” commands.
    # Each one specifies a dependency (or mutually necessary group thereof –
    # for example, {make} has a soft dependency on {guile}, but can’t use it
    # unless {pkg-config} is also present).  Formally, “enhanced_by” takes an
    # array argument, but single strings also work thanks to silent type‐
    # coërcion to the correct thing.
    def enhanced_by(aid); specs.each { |spec| spec.enhanced_by(aid) } unless ARGV.ignore_aids?; end

    # @!attribute [w] option
    # Options can be used as arguments to `brew install`.
    # To use, or refrain from using, features or other software:
    #   `"with-foo"` or `"without-bar"`.
    # Note, that for {.depends_on} that are `:optional` or `:recommended`, options
    # are generated automatically.
    #
    # There are also some special options:
    # - `:universal`: build a universal binary/library (e.g. on newer Intel Macs
    #   this means a combined x86_64/x86 binary/library).
    # <pre>option "with-spam", "The description goes here without a dot at the end"</pre>
    # <pre>option "with-qt", "Text here overwrites the autogenerated one from 'depends_on "qt" => :optional'"</pre>
    # <pre>option :universal</pre>
    def option(name, description = "")
      specs.each { |spec| spec.option(name, description) }
    end

    def deprecated_option(hash)
      specs.each { |spec| spec.deprecated_option(hash) }
    end

    # External patches can be declared using resource-style blocks.
    # <pre>patch do
    #   url "https://example.com/example_patch.diff"
    #   sha256 "c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2"
    # end</pre>
    #
    # A strip level of `-p1` is assumed. It can be overridden using a symbol
    # argument:
    # <pre>patch :p0 do
    #   url "https://example.com/example_patch.diff"
    #   sha256 "c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2"
    # end</pre>
    #
    # Patches can be declared in stable, devel, and head blocks. This form is
    # preferred over using conditionals.
    # <pre>stable do
    #   patch do
    #     url "https://example.com/example_patch.diff"
    #     sha256 "c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2"
    #   end
    # end</pre>
    #
    # Embedded (`__END__`) patches are declared like so:
    # <pre>patch :DATA
    # patch :p0, :DATA</pre>
    #
    # Patches can also be embedded by passing a string. This makes it possible
    # to provide multiple embedded patches while making only some of them
    # conditional.
    # <pre>patch :p0, "..."</pre>
    def patch(strip = :p1, src = nil, &block)
      specs.each { |spec| spec.patch(strip, src, &block) }
    end

    # Defines launchd plist handling.
    #
    # Does your plist need to be loaded at startup?
    # <pre>plist_options :startup => true</pre>
    #
    # Or only when necessary or desired by the user?
    # <pre>plist_options :manual => "foo"</pre>
    #
    # Or perhaps you'd like to give the user a choice? Ooh fancy.
    # <pre>plist_options :startup => "true", :manual => "foo start"</pre>
    def plist_options(options)
      @plist_startup = options[:startup]
      @plist_manual = options[:manual]
    end

    # @private
    def conflicts; @conflicts ||= []; end

    # If this formula conflicts with another one.
    # <pre>conflicts_with "imagemagick", :because => "because this is just a stupid example"</pre>
    def conflicts_with(*names)
      opts = Hash === names.last ? names.pop : {}
      names.each { |name| conflicts << FormulaConflict.new(name, opts[:because]) }
    end

    def skip_clean(*paths)
      paths.flatten!
      # Specifying :all is deprecated and will become an error
      skip_clean_paths.merge(paths)
    end

    # @private
    def skip_clean_paths; @skip_clean_paths ||= Set.new; end

    # Software that will not be sym-linked into the `brew --prefix` will only
    # live in its Cellar. Other formulae can depend on it and then brew will
    # add the necessary includes and libs (etc.) during the brewing of that
    # other formula. But generally, keg_only formulae are not in your PATH
    # and not seen by compilers if you build your own software outside of
    # Homebrew. This way, we don't shadow software provided by OS X.
    # <pre>keg_only :provided_by_osx</pre>
    # <pre>keg_only "because I want it so"</pre>
    def keg_only(reason, explanation = "")
      @keg_only_reason = KegOnlyReason.new(reason, explanation)
    end

    # Pass :skip to this method to disable post-install stdlib checking
    def cxxstdlib_check(check_type)
      define_method(:skip_cxxstdlib_check?) { true } if check_type == :skip
    end

    # Marks the {Formula} as failing with a particular compiler so it will fall back to others.
    # For Apple compilers, this should be in the format:
    # <pre>fails_with :llvm do # :llvm is really llvm-gcc
    #   build 2334
    #   cause "Segmentation fault during linking."
    # end
    #
    # fails_with :clang do
    #   build 600
    #   cause "multiple configure and compile errors"
    # end</pre>
    #
    # The block may be omitted, and if present the build may be omitted;
    # if so, then the compiler will be blacklisted for *all* versions.
    #
    # `major_version` should be the major release number only, for instance
    # '4.8' for the GCC 4.8 series (4.8.0, 4.8.1, etc.).
    # If `version` or the block is omitted, then the compiler will be
    # blacklisted for all compilers in that series.
    #
    # For example, if a bug is only triggered on GCC 4.8.1 but is not
    # encountered on 4.8.2:
    #
    # <pre>fails_with :gcc => '4.8' do
    #   version '4.8.1'
    # end</pre>
    def fails_with(compiler, &block)
      specs.each { |spec| spec.fails_with(compiler, &block) }
    end

    def needs(*standards); specs.each { |spec| spec.needs(*standards) }; end

    # Test (is required for new formula and makes us happy).
    # @return [Boolean]
    #
    # The block will create, run in and delete a temporary directory.
    #
    # We are fine if the executable does not error out, so we know linking
    # and building the software was ok.
    # <pre>system bin/"foobar", "--version"</pre>
    #
    # <pre>(testpath/"test.file").write <<-EOS.undent
    #   writing some test file, if you need to
    # EOS
    # assert_equal "OK", shell_output("test_command test.file").strip</pre>
    #
    # Need complete control over stdin, stdout?
    # <pre>require "open3"
    # Open3.popen3("#{bin}/example", "argument") do |stdin, stdout, _|
    #   stdin.write("some text")
    #   stdin.close
    #   assert_equal "result", stdout.read
    # end</pre>
    #
    # The test will fail if it returns false, or if an exception is raised.
    # Failed assertions and failed `system` commands will raise exceptions.
    #
    # For formulæ that install headers, or documentation, or otherwise install
    # nothing executable and cannot meaningfully be tested, do
    #    test { :does_not_apply }
    # A message will be printed and the test will “succeed”.

    def test(&block); define_method(:test, &block); end

    # @private
    def link_overwrite(*paths)
      paths.flatten!
      link_overwrite_paths.merge(paths)
    end

    # @private
    def link_overwrite_paths; @link_overwrite_paths ||= Set.new; end
  end # Formula domain‐specific language
end # Formula
