require "bottles"            # pulls in tab (thence ostruct, cxxstdlib, options, utils/json); repeats macos + extend/ARGV
require "build_environment"  # pulls in set
require "build_options"
require "formula/support"
require "formula/lock"       # pulls in fcntl
require "formula/pin"        # pulls in keg
require "formulary"          # pulls in vendor/backports/enumerable, digest, formula/renames
require "install_renamed"
require "pkg_version"        # pulls in version
require "software_spec"      # pulls in forwardable, build_options, checksum, compilers, dependency_collector, patch;
                             # repeats bottles + options + resource + version
require "tap"                # repeats utils/json

# A formula provides instructions and metadata for Leopardbrew to install a piece of software.  Each Leopardbrew formula subclasses
#   {Formula} to implement those instructions and metadata.  Such subclasses of {Formula}, like any other Ruby class, must be named
#   in “UpperCamelCase” and “cannot-use-dashes”.  Also, a Leopardbrew formula specified in the file “this-formula.rb” must have the
#   class name “ThisFormula”.  Leopardbrew does enforce that the names of the file and of the class correspond.  Make sure to check
#   with `brew search` that the name is free!
# @abstract
# @see SharedEnvExtension
# @see FileUtils
# @see Pathname
# @see http://localhost`brew --repo`/share/doc/homebrew/Formula-Cookbook.md Formula Cookbook
# @see https://rubystyle.guide/ RuboCop’s Ruby Style Guide
#     class Wget < Formula
#       homepage 'https://www.gnu.org/software/wget/'
#       url 'https://ftp.gnu.org/gnu/wget/wget-1.15.tar.gz'
#       sha256 '52126be8cf1bddd7536886e74c053ad7d0ed2aa89b4b630f76785bac21695fcd'
#
#       def install
#         system './configure', "--prefix=#{prefix}"
#         system 'make', 'install'
#       end
#     end # Wget
class Formula
  include FileUtils
  include Utils::Inreplace
  extend Enumerable

  # @!method inreplace(paths, before = nil, after = nil)
  # Implemented in {Utils⸬Inreplace.inreplace}.  Sometimes we have to change a bit before we install.  Generally we prefer a patch;
  #   but if you need the {prefix} of this formula in the patch, you have to resort to `inreplace`, because in the patch there’s no
  #   access to anything defined by the formula.  Only HOMEBREW_PREFIX is available in the embedded patch, and even that only works
  #   thanks to a moderately fragile hack.
  #`inreplace` supports regular expressions.
  #     inreplace 'somefile.cfg', /look[for]what?/, "replace by #{bin}/tool"
  # @see Utils::Inreplace.inreplace

  # The name of this {Formula}.
  #     this-formula
  attr_reader :name

  # The fully-qualified name of this {Formula}.  For core formulæ it’s the same as {#name}.
  #     homebrew/tap-name/this-formula
  attr_reader :full_name

  # The full path to this {Formula}.
  #     "$(brew --repository)"/Library/Formula/t/this-formula.rb
  attr_reader :path

  # The stable, default {SoftwareSpec} for this {Formula}.  This contains all the attributes (such as URL and checksum) which apply
  #   to the stable version of this formula.
  # @private
  attr_reader :stable

  # The development {SoftwareSpec} for this {Formula}.  Installed via `brew install --devel`.  `nil` if there is no such version.
  # @see #stable
  # @private
  attr_reader :devel

  # The HEAD {SoftwareSpec} for this {Formula}.  Installed via `brew install --HEAD`.  Always given the pseudo‐version “HEAD”, this
  #   is taken from the latest commit in the version control system.  `nil` if there is no such version.
  # @see #stable
  # @private
  attr_reader :head

  # The currently active {SoftwareSpec}.
  # @see #determine_active_spec
  attr_reader :active_spec
  protected :active_spec

  # A symbol to indicate the currently active {SoftwareSpec}.  It’s one of {:stable :devel :head}.
  # @see #active_spec
  # @private
  attr_reader :active_spec_sym

  # Used for creating new Homebrew versions of software without new upstream versions.
  # @see ⸬revision.
  attr_reader :revision

  # The current working directory during builds.  Will only be non-`nil` inside {#install}.
  attr_reader :buildpath

  # The current working directory during tests.  Will only be non-`nil` inside {#test}.
  attr_reader :testpath

  # When installing a bottle – a precompiled package – from a local source, this will be set to the full path to the bottle tarball.
  #   Otherwise, it will be `nil`.
  # @private
  attr_accessor :local_bottle_path

  # The {BuildOptions} for this {Formula}.  Contains the arguments passed and any {#option}s made available by the {Formula}.  Note
  #   that these may vary during the installation of a {Formula}.  This is annoying but is the result of state that we’re trying to
  #   eliminate.
  # @return [BuildOptions]
  attr_accessor :build

  # Compare formulæ by their names.  If their names are equal, use their full names instead.
  def <=>(other); r = (name <=> other.name).to_s.nope || full_name <=> other.full_name; r.to_i; end

  # By the time this gets called, the formula has already been {instance_eval}’d by the Formulary.  The {SoftwareSpec}s are already
  # instantiated, for example.
  # @private
  def initialize(name, path, spec)
    @name = name
    @path = path
    @revision = self.class.revision || 0

    @full_name = if path.to_s =~ HOMEBREW_TAP_PATH_REGEX
        "#{$1}/#{$2.gsub(/^homebrew-/, '')}/#{name}"
      else name; end

    set_spec :stable
    set_spec :devel
    set_spec :head

    @active_spec = determine_active_spec(spec)
    @active_spec_sym = head? ? :head : (devel? ? :devel : :stable)
    validate_attributes!
    Resource::Patch.reset_count
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
    spec = send(requested) || stable || devel || head \
      or raise(FormulaSpecificationError, 'Formulæ require at least a URL.')
  end

  def validate_attributes!
    if name.nil? or name.empty? or name =~ /\s/ then raise FormulaValidationError.new(:name, name); end
    url = active_spec.url
    if url.nil? or url.empty? or url =~ /\s/ then raise FormulaValidationError.new(:url, url); end
    val = version.responds_to?(:to_s) ? version.to_s : version
    if val.nil? or val.empty? or val =~ /\s/ then raise FormulaValidationError.new(:version, val); end
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

  # The version for the currently active {SoftwareSpec}.  The version is autodetected from the URL and/or the tag, so only needs to
  #   be declared if autodetection guesses wrongly.
  # @see .version
  def version; active_spec.version; end

  # The {PkgVersion} for this formula with {version} and {#revision} information.
  def pkg_version; PkgVersion.new(version, revision); end

  # A named Resource for the current {SoftwareSpec}.  Additional downloads can be specified as {#resource}s.  {Resource#stage} will
  # create a temporary directory and yield to a block.
  #     resource("additional_files").stage { bin.install 'my/extra/tool' }
  def resource(name); active_spec.resource(name); end

  # An old name for the formula.
  def oldname
    @oldname ||= if core_formula?
        if FORMULA_RENAMES and FORMULA_RENAMES.value?(name)
          FORMULA_RENAMES.to_a.rassoc(name).first
        end
      elsif tap?
        user, repo = tap.split('/')
        formula_renames = Tap.fetch(user, repo.sub('homebrew-', '')).formula_renames
        if formula_renames.value?(name) then formula_renames.to_a.rassoc(name).first; end
      end
  end # oldname

  # The {Resource}s for the currently active {SoftwareSpec}.
  def resources; active_spec.resources.values; end

  # The {Dependency}s for the currently active {SoftwareSpec}.
  # @private
  def deps; active_spec.deps; end

  # The {Requirement}s for the currently active {SoftwareSpec}.
  # @private
  def requirements; active_spec.requirements; end

  # This tests the enhancement state of an already‐installed {Keg}.  For current affairs, examine #active_enhancements().
  def enhanced_by?(aid)
    installed?(active_spec_sym) && Tab.for_keg(Keg.new(spec_prefix(active_spec_sym)).path).active_aids.include?(aid)
  end

  # The list of formulæ that are known to be installed and could therefore enhance the active {SoftwareSpec}.
  # @private
  def active_enhancements; active_spec.active_enhancements; end

  # The complete list of formula‐groups that would enhance the active {SoftwareSpec} if already present when it was installed.
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
  def options; active_spec.build.options; end

  # The deprecated options for the currently active {SoftwareSpec}.
  # @private
  def deprecated_options; active_spec.deprecated_options; end

  # The deprecated options _used_ for the currently active {SoftwareSpec}.
  # @private
  def deprecated_args; active_spec.deprecated_actuals; end

  # Whether a named option is defined for the currently active {SoftwareSpec}.  Can be supplied as a bare name, a command‐line flag,
  #   or a full‐blown Option object.
  def option_defined?(o); active_spec.option_defined?(o); end

  # All the {⸬fails_with} for the currently active {SoftwareSpec}.
  # @private
  def compiler_failures; active_spec.compiler_failures; end

  # If this {Formula} is installed.  Specifically, checks that the requested current prefix is installed, or the active one if none
  #   is specified.
  # @private
  def installed?(ssym = nil); is_installed_prefix?(ssym ? spec_prefix(ssym) : prefix); end

  # If at least one version of {Formula} is installed, no matter how outdated.
  # @private
  def any_version_installed?
    rack.directory? and rack.subdirs.any?{ |keg| is_installed_prefix?(keg) }
  end

  # If only versions of {Formula} other than the current ones are installed.
  # @private
  def only_old_versions_installed?
    rack.directory? and rack.subdirs.select{ |keg_dir|
                          [:head, :devel, :stable].any?{ |ssym| keg_dir == spec_prefix(ssym) }
                        }.empty? and rack.subdirs.any?{ |keg_dir| is_installed_prefix?(keg_dir) }
  end

  # If some version of {Formula} is installed under its old name.
  # @private
  def oldname_installed?
    oldname and (oldrack = HOMEBREW_CELLAR/oldname) and oldrack.directory? \
      and oldrack.subdirs.any?{ |keg_dir| is_installed_prefix?(keg_dir) }
  end

  # Returns a new Keg:  The greatest amongst versioned kegs in this rack, or HEAD if no others are present.
  def greatest_installed_keg
    highest_seen = ''; head_seen = false
    rack.subdirs.each{ |keg_dir|
      if is_installed_prefix?(keg_dir)
        candidate = keg_dir.basename
        if candidate == 'HEAD' then head_seen = true; next; end
        highest_seen = candidate if candidate.to_s > highest_seen.to_s
      else
        raise NotAnInstalledKegError, keg_dir
      end
    } if rack.directory?
    if highest_seen == ''
      if head_seen then highest_seen = 'HEAD'
      else raise FormulaNotInstalledError, full_name
      end
    end
    Keg.new(rack/highest_seen)
  end # greatest_installed_keg

  # This formula’s directory in `LinkedKegs`.  You probably want {#opt_prefix} instead.
  # @private
  def linked_keg; LINKDIR/name; end

  # What would be the .prefix for the SoftwareSpec corresponding to the given symbol?
  # @private
  def spec_prefix(ssym); if ss = send(ssym) then prefix(PkgVersion.new(ss.version, revision)); end; end

  # The list of installed current spec versions.
  def installed_current_prefixes
    icp = {}
    [:head, :devel, :stable].each{ |ss|
      pfx = spec_prefix(ss)
      icp[ss] = pfx if is_installed_prefix?(pfx)
    }
    icp
  end # installed_current_prefixes

  private

  def is_installed_prefix?(pn); self.class.is_installed_prefix?(pn); end

  public

  def self.is_installed_prefix?(pn); pn and pn.directory? and (pn/Tab::FILENAME).file?; end

  # The directory in the cellar that the formula is installed to.  This directory’s pathname includes the formula’s name & version.
  def prefix(v = pkg_version); HOMEBREW_CELLAR/name/v.to_s; end

  # The parent of the prefix; the named directory in the cellar containing all installed versions of this software.
  # @private
  def rack; prefix.parent; end

  # The directory in which to install the formula’s binaries.  This is symlinked into `HOMEBREW_PREFIX` after installation – unless
  #   the formula is keg-only – or with `brew link`.
  # Need to install into the {.bin} but the makefile doesn’t mkdir -p prefix/bin?
  #     bin.mkpath
  # No `make install` available?
  #     bin.install 'binary1'
  def bin; prefix/'bin'; end

  # The directory in which to install the formula’s documentation.  This is symlinked into `HOMEBREW_PREFIX` after installation (if
  # the formula is not keg-only), or with `brew link`.
  def doc; share/'doc'/name; end

  # The directory in which to install the formula’s header files.  This is symlinked into `HOMEBREW_PREFIX` after installation – if
  #   the formula is not keg‐only – or with `brew link`.
  # No `make install` available?
  #     include.install "example.h"
  def include; prefix/'include'; end

  # The directory in which to install the formula’s texinfo files.  This is symlinked into `HOMEBREW_PREFIX` after installation (if
  # the formula is not keg-only), or with `brew link`.
  def info; share/'info'; end

  # The directory in which to install the formula’s libraries.  This is symlinked into `HOMEBREW_PREFIX` after installation (unless
  #   the formula is keg-only), or with `brew link`.
  # No `make install` available?
  #     lib.install "example.dylib"
  def lib; prefix/'lib'; end

  # The directory in which to install the formula’s private binaries.  Not symlinked into `HOMEBREW_PREFIX`, this is often used for
  # files from one of the other directories that we wish to keep apart – instead manually creating symlinks or wrapper scripts into,
  # for example, {#bin}.
  def libexec; prefix/'libexec'; end

  # The root of the directories in which to install the formula’s manpages.  Unless the formula is keg‐only, this is symlinked into
  #`HOMEBREW_PREFIX` after installation, or with `brew link`.  Often, one of the more specific `man` methods should be used instead,
  # for example {#man1}.
  def man; share/'man'; end

  # The directories in which to install the formula’s man/n/ pages, where /n/ is a manual‐section number, in the range 1–8.  Unless
  #   the formula is keg‐only, these are symlinked into `HOMEBREW_PREFIX` after installation, or with `brew link`.
  # No `make install` available?
  #     man1.install "example.1"
  1.upto(8).each{ |n| define_method("man#{n}".to_sym) { man/"man#{n}" } }

  # The directory in which to install the formula’s “secure” binaries.  This is symlinked into `HOMEBREW_PREFIX` after installation
  # (unless the formula is keg‐only), or with `brew link`.  Generally, we try to migrate these to {#bin} instead.
  def sbin; prefix/'sbin'; end

  # The directory in which to install shared files for the formula.  This is symlinked into `HOMEBREW_PREFIX` after installation if
  #   the formula is not keg‐only, or with `brew link`.
  # Need a custom directory?
  #     (share/"concept").mkpath
  # Installing something into another custom directory?
  #     (share/"concept2").install "ducks.txt"
  # Install `./example_code/simple/ones` to share/demos
  #     (share/"demos").install "example_code/simple/ones"
  # Install `./example_code/simple/ones` to share/demos/examples
  #     (share/"demos").install "example_code/simple/ones" => "examples"
  def share; prefix/'share'; end

  # Another directory in which to install shared files for the formula, this one using its name to avoid linking conflicts.  This’s
  #   symlinked into `HOMEBREW_PREFIX` after installation (unless the formula is keg‐only), or with `brew link`.
  # No `make install` available?
  #     pkgshare.install "examples"
  def pkgshare; share/name; end

  # The directory in which to install the formula’s Frameworks.  This is symlinked into `HOMEBREW_PREFIX` after installation unless
  # the formula is keg‐only, or with `brew link`.
  def frameworks; prefix/'Frameworks'; end

  # The directory in which to install the formula’s kernel extensions.  This is not symlinked into `HOMEBREW_PREFIX`.
  def kext_prefix; prefix/'Library/Extensions'; end

  # The directory in which to install the formula’s config files.  Anything using `etc.install` won’t overwrite other files on (for
  # example) upgrades, but will write a new file named `*.default`.  This directory is outside `HOMEBREW_CELLAR` so it will persist
  # across upgrades.
  def etc; (HOMEBREW_PREFIX/'etc').extend(InstallRenamed); end

  # The directory in which to install the formula’s variable files.  This directory is outside `HOMEBREW_CELLAR` so it will persist
  # across upgrades.
  def var; HOMEBREW_PREFIX/'var'; end

  # The directory in which to install the formula’s Bash completion files.  Unless the formula is keg‐only this gets symlinked into
  #`HOMEBREW_PREFIX` after installation, or with `brew link`.
  def bash_completion; prefix/'etc/bash_completion.d'; end

  # The directory in which to install the formula’s fish completion files.  Unless the formula is keg‐only this gets symlinked into
  #`HOMEBREW_PREFIX` after installation, or with `brew link`.
  def fish_completion; share/'fish/vendor_completions.d'; end

  # The directory in which to install the formula’s ZSH completion files.  Unless the formula is keg‐only, this gets symlinked into
  #`HOMEBREW_PREFIX` after installation, or with `brew link`.
  def zsh_completion; share/'zsh/site-functions'; end

  # The directory used to hold {#etc} and {#var} files on installation so, although not in `HOMEBREW_CELLAR`, they’ll get installed
  #   there upon pouring a bottle.
  # @private
  def bottle_prefix; prefix/'.bottle'; end

  # The directory where the formula's installation logs will be written.
  # @private
  def logs; HOMEBREW_LOGS/name; end

  # This method can be overridden to provide a plist.  For more examples read Apple's handy manpage:
  # https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man5/plist.5.html
  #     def plist; <<-EOS.undent
  #       <?xml version="1.0" encoding="UTF-8"?>
  #       <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  #       <plist version="1.0">
  #       <dict>
  #         <key>Label</key>
  #           <string>#{plist_name}</string>
  #         <key>ProgramArguments</key>
  #         <array>
  #           <string>#{opt_bin}/example</string>
  #           <string>--do-this</string>
  #         </array>
  #         <key>RunAtLoad</key>
  #         <true/>
  #         <key>KeepAlive</key>
  #         <true/>
  #         <key>StandardErrorPath</key>
  #         <string>/dev/null</string>
  #         <key>StandardOutPath</key>
  #         <string>/dev/null</string>
  #       </plist>
  #       EOS
  #     end
  def plist; nil; end
  alias_method :startup_plist, :plist

  # The {.plist} name (the name of the launchd service).
  def plist_name; 'leopardbrew.gsteemso.'+name; end

  def plist_path; prefix/(plist_name+'.plist'); end

  # @private
  def plist_manual; self.class.plist_manual; end

  # @private
  def plist_startup; self.class.plist_startup; end

  # A stable path for this formula, when installed.  Contains the formula name but no version number.  Only the active version will
  #   be linked here if multiple versions are installed.
  # This is the preferred way to refer to a formula in plists or from another formula, as the path is stable even when the software
  # gets updated.
  #     args << "--with-readline=#{Formula["readline"].opt_prefix}" if build.with? "readline"
  def opt_prefix; OPTDIR/name; end

  %w[bin include lib libexec sbin share Frameworks].each{ |dir|
    define_method("opt_#{dir}".downcase) { opt_prefix/dir }
  }

  def opt_pkgshare; opt_share/name; end

  # Can be overridden to selectively disable bottles from within formulæ.  Defaults to true so overridden version need not check if
  # bottles are supported.
  def pour_bottle?; true; end

  # Can be overridden to run commands on both source and bottle installation.
  def post_install; end

  # @private
  def post_install_defined?; self.class.public_instance_methods(false).map(&:to_s).include?('post_install'); end

  # @private
  def run_post_install
    build, self.build = self.build, Tab.for_keg(spec_prefix(active_spec_sym))
    post_install
  ensure
    self.build = build
  end # run_post_install

  # Tell the user about any caveats regarding this package.
  # @return [String]
  #     def caveats
  #       <<-EOS.undent
  #         Are optional. Something the user should know?
  #       EOS
  #     end
  #
  #     def caveats
  #       s = <<-EOS.undent
  #         Print some important notice to the user when `brew info <formula>` is
  #         called or when brewing a formula.
  #         This is optional. You can use all the vars like #{version} here.
  #       EOS
  #       s += "Some issue only on older systems" if MacOS.version < :mountain_lion
  #       s
  #     end
  def caveats; nil; end

  # You don’t always want your library symlinked into HOMEBREW_PREFIX.  See curl.rb for an example.
  def keg_only?; keg_only_reason and keg_only_reason.valid?; end

  # @private
  def keg_only_reason; self.class.keg_only_reason; end

  # Sometimes the formula cleaner breaks things.  Skip cleaning paths in a formula with a class method like this:
  #     skip_clean 'bin/foo', 'lib/bar'
  # keep .la files with:
  #     skip_clean :la
  # @private
  def skip_clean?(path)
    return true if path.extname == '.la' && self.class.skip_clean_paths.include?(:la)
    to_check = path.relative_path_from(prefix).to_s
    self.class.skip_clean_paths.include? to_check
  end

  # Sometimes we accidentally install files outside {#prefix}.  After we fix that users will get a nasty link conflict error, so we
  # create a whitelist here to allow overwriting certain files:
  #     link_overwrite 'bin/foo', 'lib/bar'
  #     link_overwrite 'share/man/man1/baz-*'
  # @private
  def link_overwrite?(path)
    # Don’t overwrite files not created by Homebrew.
    return false unless path.stat.uid == File.stat(HOMEBREW_BREW_FILE).uid
    # Don’t overwrite files belonging to other kegs.
    begin
      Keg.for(path)
    rescue NotAKegError, Errno::ENOENT
      # File doesn’t belong to any keg, which is what we want; do nothing.
    else
      return false
    end
    to_check = path.relative_path_from(HOMEBREW_PREFIX).to_s
    self.class.link_overwrite_paths.any?{ |p|
      p == to_check or
        to_check.starts_with?(p.chomp('/') + '/') or
        %r{^#{Regexp.escape(p).gsub('\*', '.*?')}$} === to_check
    }
  end # link_overwrite?

  def skip_cxxstdlib_check?; false; end

  # @private
  def require_universal_deps?; false; end

  # @private
  def patch; unless patchlist.empty?; ohai "Patching"; patchlist.each(&:apply); end; end

  # Yields self with the current working directory set to the decompressed tarball.
  # @private
  def brew
    stage do
      logs.mkpath unless logs.directory?
      prepare_patches
      begin
        yield self
      ensure
        cp Dir['{config.log,CMakeCache.txt}'], logs
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
  def unlock; @lock.unlock if @lock; @oldname_lock.unlock if @oldname_lock; end

  # @private
  def clean_up_lock
    @lock.delete if @lock; @oldname_lock.delete if @oldname_lock
  rescue
    # Do nothing.  Stray lockfiles are a minor nuisance at worst.
  end # clean_up_lock

  # @private
  def pinnable?; @pin.pinnable?; end

  # @private
  def pinned?; @pin.pinned?; end

  # @private
  def pin; @pin.pin; end

  # @private
  def unpin; @pin.unpin; end

  # @private
  def ==(other); instance_of?(other.class) and name == other.name and active_spec == other.active_spec; end
  alias_method :eql?, :==

  # @private
  def hash; name.hash; end

  # @private
  def <=>(other); return unless Formula === other; name <=> other.name; end

  def to_s; name; end

  # @private
  def inspect; "#<Formula #{name} (:#{active_spec_sym}) #{path}>"; end

  # Standard parameters for CMake builds.
  # Setting CMAKE_FIND_FRAMEWORK to “LAST” tells CMake to search for libraries before trying to use Frameworks, many of which might
  #   be from third‐party installs.
  # Note:  There’s no std_autotools_args because autotools is a lot less consistent, and the standard parameters are more memorable.
  def std_cmake_args
    %W[
      -DCMAKE_C_FLAGS_RELEASE=
      -DCMAKE_CXX_FLAGS_RELEASE=
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_OSX_ARCHITECTURES=#{ENV.build_archs.as_cmake_arch_flags}
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -Wno-dev
    ]
  end # std_cmake_args

  # An array of all core {Formula} names, as {String}s.
  # @private
  def self.core_names; @core_names ||= core_files.map{ |f| f.basename('.rb').to_s }.sort; end

  # An array of all core {Formula} files, as {Pathname}s.
  # @private
  def self.core_files; @core_files ||= Pathname.glob("#{HOMEBREW_LIBRARY}/Formula/*/*.rb"); end

  # An array of all tap {Formula} names, as {String}s.
  # @private
  def self.tap_names; @tap_names ||= Tap.flat_map(&:formula_names).sort; end

  # An array of all tap {Formula} files (as {Pathname}s?).
  # @private
  def self.tap_files; @tap_files ||= Tap.flat_map(&:formula_files); end

  # An array of all {Formula} names, as {String}s.
  # @private
  def self.names; @names ||= (core_names + tap_names.map{ |nm| nm.split('/')[-1] }).uniq.sort; end

  # An array of all {Formula} files (as {Pathname}s?).
  # @private
  def self.files; @files ||= core_files + tap_files; end

  # An array of all {Formula} names, wherein the tap formulæ have fully-qualified names, as {String}s.
  # @private
  def self.full_names; @full_names ||= core_names + tap_names; end

  # @private
  def self.each
    files.each{ |file|
      begin
        yield Formulary.factory(file)
      rescue StandardError => e
        # Don’t let one broken formula break commands, but do complain.
        onoe "Failed to import:  #{file}"; puts e; next
      end
    }
  end # Formula::each

  # An array of all installed racks, as {Pathname}s.
  # @private
  def self.racks
    @racks ||= (HOMEBREW_CELLAR.directory? ? HOMEBREW_CELLAR.subdirs.reject(&:symlink?) : [])
  end

  # An array of all installed {Formula}e, as {Formula}‐subclass instances.
  # @private
  def self.installed
    @installed ||= racks.map{ |rack|
        begin Formulary.from_rack(rack)
        rescue FormulaUnavailableError, TapFormulaAmbiguityError
          # do nothing
        end
      }.compact
  end # Formula::installed

  # An array of all core aliases, as {String}s.
  # @private
  def self.core_aliases
    @core_aliases ||= Dir["#{HOMEBREW_LIBRARY}/Aliases/*"].map{ |f| File.basename f }.sort
  end

  # An array of all tap aliases (as {String}s?).
  # @private
  def self.tap_aliases; @tap_aliases ||= Tap.flat_map(&:aliases).sort; end

  # An array of all aliases (as {String}s?).
  # @private
  def self.aliases
    @aliases ||= (core_aliases + tap_aliases.map{ |name| name.split("/")[-1] }).uniq.sort
  end

  # An array of all aliases, in which the tap formulæ have fully-qualified names (as {String}s?).
  # @private
  def self.alias_full_names; @alias_full_names ||= core_aliases + tap_aliases; end

  def self.[](name); Formulary.factory(name) rescue nil; end

  # @private
  def tap?; HOMEBREW_TAP_DIR_REGEX === path; end

  # @private
  def tap
    if path.to_s =~ HOMEBREW_TAP_DIR_REGEX then "#{$1}/#{$2}"
    elsif core_formula? then 'gsteemso/leopardbrew'; end
  end

  # @private
  def print_tap_action(options = {})
    if tap?; verb = options[:verb] || 'Installing'; ohai "#{verb} #{name} from #{tap}"; end
  end

  # True if this formula is provided by Leopardbrew itself.
  # @private
  def core_formula?; path == Formulary.core_path(name); end

  # @private
  def env; self.class.env; end

  # @private
  def conflicts; self.class.conflicts; end

  # Returns a list of {Dependency} objects in an installable order, meaning that if `a` depends on `b`, then `b` will appear before
  #  `a` in this list.
  # @private
  def recursive_dependencies(&block); Dependency.expand(self, &block); end

  # The full set of {Requirement}s for this formula’s dependency tree.
  # @private
  def recursive_requirements(&block); Requirement.expand(self, &block); end

  # @private
  def to_hash
    hsh = {     'name' => name,
           'full_name' => full_name,
                'desc' => desc,
            'homepage' => homepage,
             'oldname' => oldname,
            'versions' => {
                  'stable' => (stable.version.to_s if stable),
                  'bottle' => bottle ? true : false,
                   'devel' => (devel.version.to_s if devel),
                    'head' => (head.version.to_s if head)
                },
            'revision' => revision,
           'installed' => [],
          'linked_keg' => (linked_keg.resolved_path.basename.to_s if linked_keg.exist?),
            'keg_only' => keg_only?,
        'dependencies' => deps.map(&:name).uniq,
      'conflicts_with' => conflicts.map(&:name),
             'caveats' => caveats
    }
    hsh['requirements'] = requirements.map do |req|
        {            'name' => req.name,
          'default_formula' => req.default_formula,
                     'cask' => req.cask,
                 'download' => req.download
        }
      end
    hsh['options'] = options.map do |opt|
        { 'option' => opt.flag, 'description' => opt.description }
      end
    hsh['bottle'] = {}
    %w[stable devel].each do |spec_sym|
        next unless spec = send(spec_sym)
        next unless (bottle_spec = spec.bottle_specification).checksums.any?
        bottle_info = {
          'revision' => bottle_spec.revision,
            'cellar' => (cellar = bottle_spec.cellar).is_a?(Symbol) ? cellar.inspect : cellar,
            'prefix' => bottle_spec.prefix,
          'root_url' => bottle_spec.root_url,
        }
        bottle_info['files'] = {}
        bottle_spec.collector.keys.each do |os|
            checksum = bottle_spec.collector[os]
            bottle_info['files'][os] = {
                'url' => "#{bottle_spec.root_url}/#{Bottle::Filename.create(self, os, bottle_spec.revision)}",
                checksum.hash_type.to_s => checksum.hexdigest,
              }
          end
        hsh['bottle'][spec_sym] = bottle_info
      end
    if rack.directory?
      rack.subdirs.each do |keg_path|
          keg = Keg.new keg_path
          tab = Tab.for_keg keg_path
          hsh['installed'] << { 'version' => keg.version.to_s,
                           'used_options' => tab.used_options.as_flags,
                        'built_as_bottle' => tab.built_bottle,
                     'poured_from_bottle' => tab.poured_from_bottle
                   }
        end
      hsh['installed'] = hsh['installed'].sort_by{ |i| Version.new(i['version']) }
    end
    hsh
  end # to_hash

  # @private
  def fetch; active_spec.fetch; end

  # @private
  def verify_download_integrity(fn); active_spec.verify_download_integrity(fn); end

  # The `test` command must set up the ’brew build environment, arrange to use exactly the same ARGV and build options as were used
  #   during the original brewing, &c.
  # @private
  def run_test
    old_home = ENV['HOME']
    mktemp do
      @testpath = Pathname.pwd
      setup_test_home(ENV['HOME'] = @testpath)
      if (result = test) == :does_not_apply
        puts 'This formula cannot meaningfully be tested.'; true
      else result; end
    end
  ensure
    @testpath = nil
    ENV['HOME'] = old_home
  end # run_test

  # @private
  def test_defined?; false; end
  def insinuation_defined?; false; end

  def test_fixtures(file); TEST_FIXTURES/file; end

  # This method is overriden in {Formula} subclasses to provide the installation program.  The sources (from {.url}) are downloaded
  # and hash-checked, then Homebrew changes to a temporary directory where the archive was unpacked or repository cloned.
  #     def install
  #       system './configure', "--prefix=#{prefix}"
  #       system 'make', 'install'
  #     end
  def install; end

  protected

  def setup_test_home(home)
    # Keep Homebrew’s site-packages in sys.path when testing with system Python.
    # TODO:  Make this also work with Python 3.
    user_site_packages = home/'Library/Python/2.7/lib/python/site-packages'
    user_site_packages.mkpath
    (user_site_packages/'homebrew.pth').write <<-EOS.undent
      import site; site.addsitedir("#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
      import sys; sys.path.insert(0, "#{HOMEBREW_PREFIX}/lib/python2.7/site-packages")
    EOS
  end # setup_test_home

  public

  # To call out to the system, use the `system` method.  We prefer to give the args separately, as shown below, to avoid needing to
  # open a subshell first.
  #     system './bootstrap.sh', '--arg1', "--prefix=#{prefix}"
  # For CMake we have some necessary defaults in {#std_cmake_args}:
  #     system 'cmake', '.', *std_cmake_args
  # If the arguments given to configure (or make or cmake) depend on options defined above, we usually make a list first & then use
  #`args << if ⟨condition⟩` to append to it:
  #     args = ['--with-option1', '--with-option2']
  # Most software still uses `configure` and `make`.  Check with `./configure --help` what our options are.
  #     system './configure', "--prefix=#{prefix}", '--disable-debug',
  #                           '--disable-dependency-tracking', '--disable-silent-rules',
  #                           *args  # our custom arg list (“*” unpacks the array)
  # If there is a `make install` available, please use it!
  #     system 'make', 'install'
  def system(cmd, *args)
    cmd = cmd.to_s; args.map!(&:to_s)
    verbose_using_dots = !ENV['HOMEBREW_VERBOSE_USING_DOTS'].nil?
    # Remove “boring” arguments so that the important ones are more likely to be shown, considering that we trim long ohai lines to
    # the terminal width.
    pretty_args = args.dup
    if cmd == './configure' and not VERBOSE
      pretty_args.delete '--disable-debug'
      pretty_args.delete '--disable-dependency-tracking'
      pretty_args.delete '--disable-silent-rules'
    end
    pretty_args.each_index do |i|
      if pretty_args[i].to_s.starts_with? 'import setuptools'
        pretty_args[i] = 'import setuptools...'
      end
    end
    ohai "#{cmd} #{pretty_args * ' '}".strip
    @exec_count ||= 0
    @exec_count += 1
    logfn = "#{logs}/%02d.%s" % [@exec_count, File.basename(cmd).split(' ').first]
    logs.mkpath unless logs.directory?
    File.open(logfn, 'w') do |log|
      log.puts Time.now, '', cmd, args, ''
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
                print '.'
                $stdout.flush
                last_dot = Time.now
              end
            end
            puts
          else # not verbose_using_dots
            while buf = rd.gets
              log.puts buf
              puts buf
            end
          end # verbose using dots?
        ensure
          rd.close
        end
      else # not VERBOSE
        pid = fork { exec_cmd(cmd, args, log, logfn) }
      end # VERBOSE?
      Process.wait(pid)
      $stdout.flush
      unless $?.success?
        log_lines = ENV['HOMEBREW_FAIL_LOG_LINES'].choke || '15'
        log.flush
        if not VERBOSE or verbose_using_dots
          puts "Last #{log_lines} lines from #{logfn}:"
          Kernel.system '/usr/bin/tail', '-n', log_lines, logfn
        end
        log.puts
        require 'cmd/config'
        require 'cmd/--env'
        env = ENV.to_hash
        Homebrew.dump_verbose_config(log)
        log.puts
        Homebrew.dump_build_env(env, log)
        raise BuildError.new(self, cmd, args, env)
      end # $?.success?
    end # open |log|
  end # system

  private

  def exec_cmd(cmd, args, out, logfn)
    ENV['HOMEBREW_CC_LOG_PATH'] = logfn
    cmd = cmd.to_s
    # TODO: system 'xcodebuild' is deprecated, this should be removed soon.
    ENV.remove_cc_etc if cmd.starts_with? 'xcodebuild'
    # Turn on argument filtering in the superenv compiler wrapper.  (There should probably be a better mechanism for this than just
    # adding special cases to this method.)
    # ??? Argument filtering is ALREADY on most of the time, and there are no Python shims to intercept this anyway!  Just what was
    # this trying to achieve?
    if cmd == 'python2'
      setup_py_in_args = %w[setup.py build.py].include?(args.first)
      setuptools_shim_in_args = args.any?{ |a| a.to_s.starts_with? 'import setuptools' }
      if setup_py_in_args or setuptools_shim_in_args then ENV.refurbish_args; end
    end
    $stdout.reopen(out); $stderr.reopen(out); out.close
    cmd = cmd.split(' '); args.collect!(&:to_s)
    exec(*cmd, *args) rescue nil
    puts "Failed to execute:  #{cmd}"; exit! 1  # never gets here unless exec threw or failed
  end # exec_cmd

  def stage
    active_spec.stage do
      @buildpath = Pathname.pwd
      env_home = buildpath/'.brew_home'
      mkdir_p env_home
      old_home, ENV['HOME'] = ENV['HOME'], env_home
      begin
        yield
      ensure
        @buildpath = nil
        ENV["HOME"] = old_home
      end
    end # active spec do stage
  end # stage

  def prepare_patches
    active_spec.add_legacy_patches(patches) if respond_to?(:patches)
    patchlist.grep(DATAPatch) { |p| p.path = path }
    patchlist.each{ |p| p.verify_download_integrity(p.fetch) if p.external? }
  end

  def self.method_added(method)
    case method
      when :brew        then raise RuntimeError, "You may not override Formula#brew in class #{name}."
      when :insinuate,
           :uninsinuate then define_method(:insinuation_defined?){ true }
      when :options
        instance = allocate
        specs.each{ |ss| instance.options.each{ |opt, desc| ss.option(opt[/^--(.+)$/, 1], desc) } }
        remove_method(:options)
      when :test        then define_method(:test_defined?){ true }
    end
  end # Formula::method_added

  # The methods below define the formula DSL.
  class << self
    include BuildEnvironmentDSL

    # The reason why this software is not linked (by default) to {::HOMEBREW_PREFIX}.
    # @private
    attr_reader :keg_only_reason

    # @!attribute [w] license
    # The SPDX ID of the open-source license that the formula uses.  This is shown by `brew info`.  Use `:any_of`, `:all_of`, or
    #  `:with` to describe complex license expressions.  Use `:any_of` when the user can choose which license to use.  Use `:all_of`
    #   when the user must use all licenses.  Use `:with` to specify a valid SPDX exception.  Add `+` to an identifier to show that
    #   the formula can be licensed under later versions of the same license.
    # @see https://docs.brew.sh/License-Guidelines Homebrew License Guidelines
    # @see https://spdx.github.io/spdx-spec/appendix-IV-SPDX-license-expressions/ SPDX license expression guide
    #     license 'BSD-2-Clause'
    #     license 'EPL-1.0+'
    #     license any_of: ['MIT', 'GPL-2.0-only']
    #     license all_of: ['MIT', 'GPL-2.0-only']
    #     license 'GPL-2.0-only' => { with: 'LLVM-exception' }
    #     license :public_domain
    #     license any_of: [
    #       'MIT',
    #       :public_domain,
    #       all_of: ['0BSD', 'Zlib', 'Artistic-1.0+'],
    #       'Apache-2.0' => { with: 'LLVM-exception' },
    #     ]
    def license(args = nil); args.nil? ? @licenses : @licenses = args; end

    # @!attribute [w]
    # A one-line description of the software.  Used by users to get an overview of the software and by ’brew maintainers.  Shown by
    #`brew info`.
    #     desc 'Example formula'
    attr_rw :desc

    # @!attribute [w] homepage
    # The homepage for the software.  Used by users to get more information about the software, and by ’brew maintainers as a point
    # of contact for, e.g., submitting patches.  Can be opened by running `brew home`.
    #     homepage 'https://www.example.com'
    attr_rw :homepage

    # The `:startup` attribute set by {.plist_options}.
    # @private
    attr_reader :plist_startup

    # The `:manual` attribute set by {.plist_options}.
    # @private
    attr_reader :plist_manual

    # @!attribute [w] revision
    # Used for creating new Homebrew versions of software without new upstream versions.  For example, if we bump the major version
    # of a library this {Formula} {.depends_on}, we might need to update the {.revision} of this {Formula} to install a new version
    # linked against the new library version.  `0` if unset.
    #     revision 1
    attr_rw :revision

    # A list of the {.stable}, {.devel} and {.head} {SoftwareSpec}s.
    # @private
    def specs; @specs ||= [stable, devel, head].compact.freeze; end

    # @!attribute [w] url
    # The URL used to download the source for the {#stable} version of the formula.  We prefer `https` for security & proxy reasons.
    # Optionally specify the download strategy with `:using => ...`
    #     `:git`, `:hg`, `:svn`, `:bzr`, `:cvs` (Via version‐control software.)
    #     `:curl` (Normal file download.  Will also extract.)
    #     `:nounzip` (Without extracting.)
    #     `:post` (Download via an HTTP POST.)
    #     `S3DownloadStrategy` (Download from S3 using signed request.)
    #     url 'https://packed.sources.and.we.prefer.https.example.com/archive-1.2.3.tar.bz2'
    #     url 'https://some.dont.provide.archives.example.com', :using => :git, :tag => '1.2.3'
    def url(val, txfer_specs = {}); stable.url(val, txfer_specs); end

    # @!attribute [w] version
    # The version string for the {#stable} version of the formula.  The version is autodetected from the URL and/or tag, so we only
    # need to be declare it if it is not autodetected correctly.
    #     version '1.2-final'
    def version(val = nil); stable.version(val); end

    # @!attribute [w] mirror
    # Additional URLs for the {#stable} version of the formula.  Only used if the {.url} fails to download.  It is optional & there
    # can be more than one.  Generally we add them when the main {.url} is unreliable.  If {.url} is really unreliable, we may swap
    # the {.mirror} and {.url}.
    #     mirror 'https://in.case.the.host.is.down.example.com'
    #     mirror 'https://in.case.the.mirror.is.down.example.com'
    def mirror(val); stable.mirror(val); end

    # @!attribute [w] sha256
    # @scope class
    # To verify the {#cached_download}’s integrity & security we verify the SHA-256 hash matches what was declared in the {Formula}.
    # To quickly fill this value you can leave it blank and run `brew fetch --force`; it’ll tell you the currently valid value.
    #     sha256 '2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7'
    Checksum::TYPES.each do |type| define_method(type){ |val| stable.send(type, val) }; end

    # @!attribute [w] bottle
    # Adds a {.bottle} {SoftwareSpec}.  This provides a binary package pre‐built by the ’brew maintainers for you.  It is installed
    # automatically if there is a binary package for your platform and you haven’t specified or previously used any options on this
    # formula.  If you maintain your own repository, you can add your own bottle links.
    # @see https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Bottles.md
    #     bottle do
    #       root_url 'http://example.com' # Optional root to calculate bottle URLs
    #       prefix '/opt/homebrew' # Optional HOMEBREW_PREFIX in which the bottles were built.
    #       cellar '/opt/homebrew/Cellar' # Optional HOMEBREW_CELLAR in which the bottles were built.
    #       revision 1 # Making the old bottle outdated without bumping the version/revision of the formula.
    #       sha256 '4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865' => :yosemite
    #       sha256 '53c234e5e8472b6ac51c1ae1cab3fe06fad053beb8ebfd8977b010655bfdd3c3' => :mavericks
    #       sha256 '1121cfccd5913f0a63fec40a6ffd44ea64f9dc135c66634ba001d10bcf4302a2' => :mountain_lion
    #     end
    # For formulae which don't require compiling, you can tag them with:
    #     bottle :unneeded
    # To disable bottling for other reasons.
    #     bottle :disable, 'reasons'
    def bottle(*args, &block); stable.bottle(*args, &block); end

    # @private
    def build; stable.build; end

    # @!attribute [w] stable
    # Allows {.depends_on} and {#patch}es for just the {.stable} {SoftwareSpec}.  This is required any place a conditional might be
    # used for the same purpose.  It is preferable to also pull the {url} and {.sha256} into the block if one is added.
    #     stable do
    #       url 'https://example.com/foo-1.0.tar.gz'
    #       sha256 '2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7'
    #
    #       depends_on 'libxml2'
    #       depends_on 'libffi'
    #     end
    def stable(&block)
      @stable ||= SoftwareSpec.new
      block_given? ? @stable.instance_eval(&block) : @stable
    end

    # @!attribute [w] devel
    # Adds a {.devel} {SoftwareSpec}, installable by passing `--devel` to `brew install`.  This accommodates non-stable (e.g. beta)
    # versions of software.
    #     devel do
    #       url 'https://example.com/archive-2.0-beta.tar.gz'
    #       sha256 '2a2ba417eebaadcb4418ee7b12fe2998f26d6e6f7fda7983412ff66a741ab6f7'
    #
    #       depends_on 'cairo'
    #       depends_on 'pixman'
    #     end
    def devel(&block)
      @devel ||= SoftwareSpec.new
      @devel.option :devel
      block_given? ? @devel.instance_eval(&block) : @devel
    end

    # @!attribute [w] head
    # Adds a {.head} {SoftwareSpec}, installable by passing `--HEAD` to `brew install`.  This accommodates software directly from a
    # branch of a version-control repository.  If called as a method this provides just the {url} for the {SoftwareSpec}.  If given
    # a block, you can also add {.depends_on} and {#patch}es just to the {.head} {SoftwareSpec}.  The download strategies – such as
    # `:using =>` – are the same as for {url}.  `master` is the default branch and doesn’t need stating with a `:branch` parameter.
    #     head 'https://we.prefer.https.over.git.example.com/.git'
    #     head 'https://example.com/.git', :branch => 'name_of_branch', :revision => 'abc123'
    # or (if autodetect fails):
    #     head 'https://hg.is.awesome.but.git.has.won.example.com/', :using => :hg
    def head(val = nil, txfer_specs = {}, &block)
      @head ||= HeadSoftwareSpec.new
      @head.option :head
      block_given? ? @head.instance_eval(&block) \
                   : val ? @head.url(val, txfer_specs) \
                   : @head
    end # head

    # Additional downloads can be defined as {Resource}s and accessed in the install method.  {Resource}s can also be defined in a
    # {.stable}, {.devel}, or {.head} block.  This mechanism replaces ad-hoc “subformula” classes.
    #     resource 'additional_files' do
    #       url 'https://example.com/additional-stuff.tar.gz'
    #       sha256 'c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2'
    #     end
    def resource(name, klass = Resource, &block)
      specs.each{ |ss| ss.resource(name, klass, &block) unless ss.resource_defined?(name) }
    end

    def go_resource(name, &block); specs.each{ |ss| ss.go_resource(name, &block) }; end

    # The dependencies for this formula.  Use strings to name other formulæ.  Homebrew provides some :special dependencies where an
    # item requires certain extra handling (often changing some ENV vars, or deciding whether to use the system‐provided version).
    # `:build` means this dep is only needed during build.
    #     depends_on 'cmake' => :build
    #     depends_on 'homebrew/dupes/tcl-tk' => :optional
    # `:recommended` dependencies are built by default.  A `--without-…` option is generated to opt out.
    #     depends_on 'readline' => :recommended
    # `:optional` dependencies are NOT built by default.  A `--with-…` option is generated.
    #     depends_on 'glib' => :optional
    # If you need to specify that another formula has to be built with/out certain options (note, no `--` needed before the option):
    #     depends_on 'zeromq' => 'with-pgm'
    #     depends_on 'qt' => ['with-qtdbus', 'developer'] # Multiple options.
    # Optional and enforce that boost is built with `--with-c++11`:
    #     depends_on 'boost' => [:optional, 'with-c++11']
    # If a dependency is only needed in certain cases:
    #     depends_on 'sqlite' if MacOS.version == :leopard
    #     depends_on :xcode   # If the formula really needs full Xcode.
    #     depends_on :tex     # Homebrew does not provide a Tex Distribution.
    #     depends_on :fortran # Checks that `gfortran` is available or `FC` is set.
    #     depends_on :mpi => :cc       # Needs MPI with `cc`
    #     depends_on :mpi => [:cc, :cxx, :optional]  # Is optional.  MPI with `cc` and `cxx`.
    #     depends_on :macos => :lion   # Needs at least Mac OS X 'Lion' (10.7).
    #     depends_on :apr     # If a formula requires the CLT-provided apr library to exist.
    #     depends_on :arch => :intel   # If this formula only builds on Intel architecture.
    #     depends_on :arch => :x86_64  # If this formula only builds on Intel x86 64-bit.
    #     depends_on :arch => :ppc     # Only builds on PowerPC?
    #     depends_on :ld64    # Sometimes ld fails on `MacOS.version <= :leopard`.  Then use this.
    #     depends_on :x11     # X11/XQuartz components.  Non-optional X11 deps should go in Homebrew/Homebrew-x11
    #     depends_on :osxfuse  # Permits the use of the upstream signed binary or our source package.
    #     depends_on :tuntap  # Does the same thing as above. This is vital for Yosemite and above.
    #     depends_on :mysql => :recommended
    # It is possible to only depend on `formula` if `build.with? / build.without? 'other_formula'`:
    #     depends_on :mysql   # Allows brewed or external mysql to be used.
    #     depends_on :postgresql if build.without? 'sqlite'
    #     depends_on :hg      # Mercurial (external or brewed) is needed.
    # If any Python >= 2.7 < 3.x is okay (either from OS X or brewed):
    #     depends_on :python2
    # to depend on Python >= 2.7 but use system Python where possible
    #     depends_on :python2 if MacOS.version <= :snow_leopard
    # Python 3.x if the `--with-python3` is given to `brew install example`
    #     depends_on :python3 => :optional
    # `depends_on` also accepts an array of operands.  Internally, it converts it to a series of individual `depends_on` statements.
    def depends_on(dep); specs.each{ |ss| ss.depends_on(dep) }; end

    # Define a set of alternate dependencies, only one of which is to be selectable.  For example,
    #     depends_1_of ['⟨label⟩', ['⟨first⟩', {'⟨second⟩' => 'with-extra'}, '⟨third⟩']] => :optional
    #     depends_1_of ['⟨label⟩', ['⟨first⟩', {'⟨second⟩' => 'with-extra'}, '⟨third⟩']] => :recommended
    #     depends_1_of ['⟨label⟩', ['⟨first⟩', {'⟨second⟩' => 'with-extra'}, '⟨third⟩']]
    #     depends_1_of ['⟨label⟩', ['⟨first⟩', {'⟨second⟩' => 'with-extra'}, '⟨third⟩']] => [:build, :recommended]
    # These generate a “--with-⟨label⟩=” option.  For :recommended priority, a “--without-⟨label⟩” option is also created.  For any
    # priority other than :optional, exactly one generated option must be supplied (and, where it includes a value, that value must
    # be one of the formula names listed), or the steps below are taken.  {.with?} and {.without?} will always be able to check for
    # “⟨label⟩=”.  If the priority is :optional or :recommended, they will also be able to check for plain “⟨label⟩”.
    # For priorities other than :optional, if no alternative is specified by the user, the first installed alternative is chosen by
    # default.  If none are installed, the first in the list is taken as a dependency for automatic installation.
#    def depends_1_of(group); specs.each { |spec| spec.depends_1_of(group) }; end

    # Define a group of dependencies selectable by a single option.  All such groups must be either :optional or :recommended; only
    # those autogenerate the build options that this makes more convenient.  This autogenerates a “--without-dns-extras” option:
    #     depends_group ['dns-extras', ['c-ares', 'ibidn2, 'libpsl'] => :recommended]
    def depends_group(group); specs.each { |spec| spec.depends_group(group) }; end

    # Indicate a soft dependency (one which can be omitted, either to avoid dependency loops or simply to reduce installation time).
    #     enhanced_by 'package'
    #     enhanced_by ['package', 'other-package']
    # Each specifies a dependency (or a mutually necessary group thereof; for example, {make} has a soft dependency on {guile}, but
    # can’t use it unless {pkg-config} is also present).  Technically, {.enhanced_by} takes an {Array}; but {String}s also work and
    # are the most common use case.
    def enhanced_by(aid); specs.each { |spec| spec.enhanced_by(aid) } unless ARGV.ignore_aids?; end

    # @!attribute [w] option
    # Options can be used as arguments to `brew install`.  To use, or refrain from using, features or other software:
    #     brew install foo --with-bar --without-glarch
    # Note that for {.depends_on} and {.depends_group} which are `:optional` or `:recommended`, options are generated automatically.
    # For any others,
    #     option 'with-spam', 'The description goes here without a dot at the end'
    #     option 'with-qt', "This supersedes the text inferred from “depends_on 'qt' => :optional”"
    #     option :universal
    # As that last demonstrates, there are also some special options.
    # To allow building a universal binary (e.g. on older Intel Macs, x86 and x86_64 combined):
    #     :universal
    # To allow building a cross-compiled universal binary (e.g. on newer Intel Macs, x86_64 and arm64 combined; or under Leopard, a
    # Quad Fat Binary with both 32‐ and 64‐bit code for each of PowerPC and Intel CPUs):
    #     :cross
    def option(name, description = ''); specs.each { |spec| spec.option(name, description) }; end

    def deprecated_option(hash); specs.each { |spec| spec.deprecated_option(hash) }; end

    # External patches can be declared using resource-style blocks.
    #     patch do
    #       url 'https://example.com/example_patch.diff'
    #       sha256 'c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2'
    #     end
    # A strip level of `-p1` is assumed.  It can be overridden using a symbol argument:
    #     patch :p0 do
    #       url 'https://example.com/example_patch.diff'
    #       sha256 'c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2'
    #     end
    # Patches can be declared in {.stable}, {.devel}, and {.head} blocks.  This form is preferred over using conditionals.
    #     stable do
    #       patch do
    #         url 'https://example.com/example_patch.diff'
    #         sha256 'c6bc3f48ce8e797854c4b865f6a8ff969867bbcaebd648ae6fd825683e59fef2'
    #       end
    #     end
    # Embedded (`__END__`) patches are declared like so:
    #     patch :DATA
    #     patch :p0, :DATA
    # Patches can also be embedded by passing a string.  This allows a formula to have multiple embedded patches yet make only some
    # of them conditional.
    #     patch :p0, '...'
    #     patch <<END_OF_PATCH if ⟨condition⟩
    def patch(strip = :p1, src = nil, &block); specs.each { |s| s.patch(strip, src, &block) }; end

    # Defines launchd plist handling.
    # Does your plist need to be loaded at startup?
    #     plist_options :startup => true
    # Or only when necessary or desired by the user?
    #     plist_options :manual => 'foo'
    # Or perhaps you'd like to give the user a choice? Ooh fancy.
    #     plist_options :startup => 'true', :manual => 'foo start'
    def plist_options(options); @plist_startup = options[:startup]; @plist_manual = options[:manual]; end

    # @private
    def conflicts; @conflicts ||= []; end

    # Use this if this formula conflicts with another one.
    #     conflicts_with 'imagemagick', :because => 'because this is just a stupid example'
    def conflicts_with(*names)
      opts = Hash === names.last ? names.pop : {}
      names.each { |name| conflicts << FormulaConflict.new(name, opts[:because]) }
    end

    # Specifying :all is deprecated and will become an error
    def skip_clean(*paths); paths.flatten!; skip_clean_paths.merge(paths); end

    # @private
    def skip_clean_paths; @skip_clean_paths ||= Set.new; end

    # Software that will not be symlinked into `brew --prefix` will only live in the Cellar.  Other formulæ can depend on it & then
    # Leopardbrew will add the necessary includes, libs, &c. during the brewing of those other formulæ; but keg_only formulæ do not
    # generally appear in your PATH, and are not seen by compilers if you build your own software outside of Homebrew.  This way we
    # don’t shadow software provided by the OS.
    #     keg_only :provided_by_osx
    #     keg_only 'because I want it so'
    def keg_only(reason, blurb = ''); @keg_only_reason = KegOnlyReason.new(reason, blurb); end

    # Pass :skip to this method to disable post-install stdlib checking.
    def cxxstdlib_check(check_type)
      define_method(:skip_cxxstdlib_check?){ true } if check_type == :skip
    end

    # Marks the {Formula} as failing with a particular compiler so it will fall back to others.  For Apple compilers this should be
    # in the format
    #     fails_with :llvm do  # :llvm is really llvm-gcc
    #       build 2334
    #       cause 'Segmentation fault during linking.'
    #     end
    #     fails_with :clang do
    #       build 600
    #       cause 'multiple configure and compile errors'
    #     end
    # For GCC releases, the format is
    #     fails_with :gcc => ⟨major version⟩ do
    #       version 'full version'
    #       cause 'The needed C feature is not yet implemented in this version.'
    #     end
    # The block may be omitted, and if present the {build} ({version}) may be omitted; if so, then the compiler will be blacklisted
    # for *all* versions.  ⟨Major version⟩ should be the major release number only – for instance '4.8' for GCC 4.8.x (4.8.0, 4.8.1,
    # &c.).  If {version} or the block is omitted, the compiler will be blacklisted for all compilers in that series.  For example,
    # if a bug is only triggered on GCC 4.8.1 but is not encountered on 4.8.2:
    #     fails_with :gcc => '4.8' do
    #       version '4.8.1'
    #     end
    # Note that the cause is now neither used nor saved, but can still be specified for the formula author’s benefit.
    def fails_with(compiler, &block) specs.each { |spec| spec.fails_with(compiler, &block) } end

    # The formula may need compiler support for a specific set of features.  These can be specified using {.needs}:
    #     needs :c11    # C11
    #     needs :cxx11  # C++11
    #     needs :tls    # Thread-Local Storage.  GCCs a bit newer than Apple’s implemented a trick that makes this work on PowerPCs,
    #                   # even though Leopard itself doesn’t have that concept.
    def needs(*standards); specs.each{ |spec| spec.needs(*standards) }; end

    # Test (is required for new formula and makes us happy).
    # @return [Boolean]
    # The block will create, run in and delete a temporary directory.  We are fine if the executable does not error out, so we know
    # linking and building the software was ok.
    #     test do
    #       system bin/'foobar', '--version'
    #       (testpath/'test.file').write <<-EOS.undent
    #         writing some test file, if you need to
    #       EOS
    #       assert_equal 'OK', shell_output('test_command test.file').strip
    #     end
    # Need complete control over stdin, stdout?
    #     test do
    #       require 'open3'
    #       Open3.popen3("#{bin}/example", 'argument') do |stdin, stdout, _|
    #         stdin.write('some text')
    #         stdin.close
    #         assert_equal 'result', stdout.read
    #       end
    #     end
    # The test will fail if it returns false, or if an exception is raised.  Failed assertions or failed `system` commands do raise
    # exceptions.
    # For formulæ that install nothing executable and thus cannot meaningfully be tested, do
    #    test { :does_not_apply }
    # A message will be printed and the test will “succeed”.
    def test(&block); define_method(:test, &block); end

    # Insinuation is for formulæ which must carry out some action to very deeply integrate with the
    # system upon installation, and then to remove that integration prior to formula uninstallation.
    #     insinuate do
    #       # ensure the helper script is present before doing this:
    #       system('sudo', "#{bin}/to-brewed-package")
    #     end
    # THESE CODE BLOCKS MUST BE IDEMPOTENT!  It is not only possible, but actively expected, that they may be called more than once
    # without their counterpart being called in between; in which case, they must not make a mess!
    # An {.insinuate} block can also be called when not all of its formula’s dependencies are functional, or even present.  If this
    # may be a problem, it should test its environment and act accordingly.  Further, an {.uninsinuate} block must not presume that
    # its rack still exists.  It shall be called after the rack’s removal in order for helper scripts to delete themselves.
    def insinuate(&block); define_method(:insinuate, &block); end
    def uninsinuate(&block); define_method(:uninsinuate, &block); end

    # @private
    def link_overwrite(*paths); paths.flatten!; link_overwrite_paths.merge(paths); end

    # @private
    def link_overwrite_paths; @link_overwrite_paths ||= Set.new; end
  end # Formula domain‐specific language
end # Formula
