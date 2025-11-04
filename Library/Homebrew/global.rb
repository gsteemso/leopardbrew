require 'pathname'  #
require 'rbconfig'  # Ruby libraries.
require 'set'       #
# These others are Homebrew libraries:
require 'extend/leopard' if RUBY_VERSION <= '1.8.6'  # also pulls in extend/tiger if needed
require 'extend/string'
require 'extend/ARGV'; ARGV.extend(HomebrewArgvExtension)
require 'extend/misc'
require 'extend/pathname'  # also pulls in extend/fileutils, mach, metafiles, & resource
require 'osay'
require 'utils'

# Path to main executable ($HOMEBREW_PREFIX/bin/brew):
if ENV['HOMEBREW_BREW_FILE'].choke then HOMEBREW_BREW_FILE = Pathname.new(ENV['HOMEBREW_BREW_FILE'])
else odie '$HOMEBREW_BREW_FILE was not exported!  Please brew via bin/brew!'; end

RbConfig = Config if RUBY_VERSION < '1.8.6'  # different module name on Tiger

# Predefined pathnames:
CONFIG_RUBY_PATH        = RbConfig.responds_to?(:ruby) \
                          ? Pathname.new(RbConfig.ruby) \
                          : Pathname.new(RbConfig::CONFIG['bindir'])/(RbConfig::CONFIG['ruby_install_name'] \
                                                                      + RbConfig::CONFIG['EXEEXT'])
                                                                    # The current Ruby binary
  CONFIG_RUBY_BIN       =   CONFIG_RUBY_PATH.dirname                # Where it lives
CURL_PATH               = Pathname.new(ENV['HOMEBREW_CURL_PATH'])   # our internal Portable Curl
HOMEBREW_CACHE          = Pathname.new(ENV['HOMEBREW_CACHE'])
                          # Where downloads (bottles, source tarballs, etc.) are cached (/Library/Caches/Homebrew)
  HOMEBREW_FORMULA_CACHE =  HOMEBREW_CACHE/'Formula'                # Where URL‐spec’d formulæ, & all formula locks, are cached
HOMEBREW_CELLAR         = Pathname.new(ENV['HOMEBREW_CELLAR']).realpath
HOMEBREW_LIBRARY        = Pathname.new(ENV['HOMEBREW_LIBRARY'])     # In HOMEBREW_REPOSITORY
  HOMEBREW_CONTRIB      =   HOMEBREW_LIBRARY/'Contributions'
  LINKDIR               =   HOMEBREW_LIBRARY/'LinkedKegs'           # Records which kegs are linked
  PINDIR                =   HOMEBREW_LIBRARY/'PinnedKegs'           # see `formula/pin.rb`
HOMEBREW_RUBY_LIBRARY   = Pathname.new(ENV['HOMEBREW_RUBY_LIBRARY']) # Homebrew’s Ruby libraries
  HOMEBREW_CMDS         =   HOMEBREW_RUBY_LIBRARY/'cmd'
  HOMEBREW_DEV_CMDS     =   HOMEBREW_RUBY_LIBRARY/'dev-cmd'
  HOMEBREW_LOAD_PATH    =   HOMEBREW_RUBY_LIBRARY                   # The path to our libraries /when invoking Ruby/.  May be set
                                                                    # to a custom value during unit testing of Homebrew itself.
  TEST_FIXTURES         =   HOMEBREW_RUBY_LIBRARY/'test/fixtures'
HOMEBREW_PREFIX         = Pathname.new(ENV['HOMEBREW_PREFIX'])      # Where we link under
  OPTDIR                =   HOMEBREW_PREFIX/'opt'                   # Where we are always available
HOMEBREW_REPOSITORY     = Pathname.new(ENV['HOMEBREW_REPOSITORY'])  # Where .git is found
  GIT_REPO_HEAD         =   HOMEBREW_REPOSITORY/'.git/refs/heads/combined'
HOMEBREW_RUBY_PATH      = Pathname.new(ENV['HOMEBREW_RUBY_PATH'])   # Our internal Ruby binary
OPEN_PATH               = Pathname.new('/usr/bin/open')
SYSTEM_RUBY_PATH        = Pathname.new('/usr/bin/ruby')             # The system Ruby binary
TAR_PATH                = (gtar = OPTDIR/'gnu-tar/bin/gtar').executable? ? gtar : Pathname.new('/usr/bin/tar')

# Predefined regular expressions:
# CompilerConstants::GNU_GCC_REGEXP # For recognizing brewed, non-Apple GCCs.
HOMEBREW_CASK_TAP_FORMULA_REGEX   = %r{^(Caskroom)/(cask)/([\w+-.]+)$}
                                    # Match formulæ in the default brew‐cask tap, e.g. Caskroom/cask/someformula
HOMEBREW_CORE_FORMULA_REGEX       = %r{^homebrew/homebrew/([\w+-.]+)$}i
                                    # Match core formulæ, e.g. homebrew/homebrew/someformula
HOMEBREW_PULL_OR_COMMIT_URL_REGEX = %r{https://github\.com/([\w-]+)/(?:tiger|leopard)brew(-[\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})}
HOMEBREW_TAP_ARGS_REGEX           = %r{^([\w-]+)/(homebrew-)?([\w-]+)$}
                                    # Match taps given as arguments, e.g. someuser/sometap
HOMEBREW_TAP_DIR_REGEX            = %r{#{Regexp.escape(HOMEBREW_LIBRARY.to_s)}/Taps/([\w-]+)/([\w-]+)}
                                    # Match taps’ directory paths, e.g. HOMEBREW_LIBRARY/Taps/someuser/sometap
  HOMEBREW_TAP_PATH_REGEX         =   Regexp.new(HOMEBREW_TAP_DIR_REGEX.source + %r{/(.*)}.source)
                                      # Match taps’ formula paths, e.g. HOMEBREW_LIBRARY/Taps/someuser/sometap/someformula
HOMEBREW_TAP_FORMULA_REGEX        = %r{^([\w-]+)/([\w-]+)/([\w+-.@]+)$}
                                    # Match taps’ formulæ, e.g. someuser/sometap/someformula
# OPTION_RX                         # see `options.rb`
# Pathname::BOTTLE_EXTNAME_RX       # see `extend/pathname.rb`
VERSIONED_NAME_REGEX              = %r{^([^-=][^=]*)=([^=]+)$}      # Matches a formula‐name‐including‐version specification.

# Other predefined values:
# CompilerConstants::ARCH_COMPILER_MINIMUM
                                    # Lists the minimum compiler to target a given architecture.
# CompilerConstants::COMPILER_DEFAULT # Lists the default language versions for a given compiler version.
# CompilerConstants::COMPILER_SUPPORT # Lists the greatest supported language versions for a given compiler version.
# CompilerConstants::COMPILERS      # Lists the known compilers.
HOMEBREW_CURL_ARGS       = '-f#LA'
HOMEBREW_INTERNAL_COMMAND_ALIASES = { 'ls'          => 'list',
                                      'homepage'    => 'home',
                                      '-S'          => 'search',
                                      'up'          => 'update',
                                      'ln'          => 'link',
                                      'instal'      => 'install',  # gem does the same
                                      'rm'          => 'uninstall',
                                      'remove'      => 'uninstall',
                                      'configure'   => 'diy',
                                      'abv'         => 'info',
                                      'dr'          => 'doctor',
                                      '--repo'      => '--repository',
                                      'environment' => '--env',
                                      '--config'    => 'config'
                                    }
HOMEBREW_OUTDATED_LIMIT  = 1209600 # 60 s * 60 min * 24 h * 14 days:  two weeks
HOMEBREW_USER_AGENT      = ENV['HOMEBREW_USER_AGENT']
HOMEBREW_USER_AGENT_CURL = ENV['HOMEBREW_USER_AGENT_CURL']
HOMEBREW_USER_AGENT_RUBY = "#{HOMEBREW_USER_AGENT} ruby/#{RUBY_VERSION}#{defined?(RUBY_PATCHLEVEL) ? "-p#{RUBY_PATCHLEVEL}" : ''}"
HOMEBREW_WWW             = 'https://github.com/gsteemso/leopardbrew'
    ISSUES_URL           =   HOMEBREW_WWW
LEOPARDBREW_VERSION      = ENV['LEOPARDBREW_VERSION']
MACOS_FULL_VERSION       = ENV['HOMEBREW_OS_VERSION'].chomp
  MACOS_VERSION          =   MACOS_FULL_VERSION[/\d\d\.\d+/]
    MACOS_VERSION        =     MACOS_VERSION.slice(0, 2) if MACOS_VERSION.to_f >= 11
# MacOS::MAX_SUPPORTED_VERSION # see `macos/version.rb`
# Tab::FILENAME                # see `tab.rb`

# Optionally user‐defined values:
BREW_NICE_LEVEL = ENV['HOMEBREW_NICE_LEVEL']  # Do we `nice` our build process?
DEBUG           = ARGV.debug?                 # Checks all of “-d”, “--debug”, & $HOMEBREW_DEBUG
DEVELOPER       = ARGV.homebrew_developer?    # Enable developer commands (checks both
                                              #   “--homebrew-developer” & $HOMEBREW_DEVELOPER)
HOMEBREW_GITHUB_API_TOKEN = ENV['HOMEBREW_GITHUB_API_TOKEN'] # For unthrottled Github access
HOMEBREW_INSTALL_BADGE = ENV['HOMEBREW_INSTALL_BADGE'] || "\xf0\x9f\x8d\xba"
                                              # Default is the beer emoji (see `formula/installer.rb`)
HOMEBREW_LOGS   = Pathname.new(ENV.fetch 'HOMEBREW_LOGS', '~/Library/Logs/Homebrew/').expand_path
                  # Where build, postinstall, and test logs of formulæ are written to
HOMEBREW_TEMP   = Pathname.new(ENV.fetch 'HOMEBREW_TEMP', '/tmp').realpath
                  # Where temporary folders for building and testing formulæ are created
NO_EMOJI        = ENV['HOMEBREW_NO_EMOJI']    # Don’t show badges at all (see `formula/installer.rb` and `cmd/info.rb`)
ORIGINAL_PATHS  = ENV['PATH'].split(File::PATH_SEPARATOR).map{ |p| Pathname.new(p).expand_path rescue nil }.compact.freeze
QUIETER         = ARGV.quieter?               # Give less feedback when VERBOSE (checks:  “-q”, “--quieter”, & $HOMEBREW_QUIET)
VERBOSE         = ARGV.verbose? or QUIETER    # Give lots of feedback (checks:  “-v”, “--verbose”, $HOMEBREW_VERBOSE, & $VERBOSE)

require 'extend/ENV'; ENV.activate_extensions!  # pulls in target (thence macos, & cpu) and formula (thence almost two dozen more)

# include backwards‐compatibility cruft?
require 'compat' unless ENV['HOMEBREW_NO_COMPAT'] or ARGV.include?('--no-compat')

# Customizeable environment variables:
# $HOMEBREW_BUILD_BOTTLE         # Always build a bottle instead of a normal installation (see `extend/ARGV.rb`)
# $HOMEBREW_BUILD_FROM_SOURCE    # Force building from source even when there is a bottle (see `extend/ARGV.rb`)
# $HOMEBREW_CURL_VERBOSE         # Checked by ::curl() in `utils.rb`; deleted by CurlApacheMirrorDownloadStrategy
# $HOMEBREW_DEBUG_RUBY           # Set if we’re debugging our interaction with the Ruby that we’re running on
# $HOMEBREW_FAIL_LOG_LINES       # How many lines of system output to log on failure (see `formula.rb`)
# $HOMEBREW_MAKE_JOBS            # Used in $MAKEFLAGS, prefixed by “-j”
# $HOMEBREW_NO_GITHUB_API        # Used by GitHub.open & GitHub.print_pull_requests_matching in `utils.rb`
# $HOMEBREW_NO_INSECURE_REDIRECT # Tested in CurlDownloadStrategy#fetch if an https → http redirect is encountered.
# $HOMEBREW_PREFER_64_BIT        # Build 64‐bit by default (req’d for Leopard :universal; see `macos.rb`)
# $HOMEBREW_SANDBOX              # hells if I know (see `extend/ARGV.rb`)
# $HOMEBREW_UNIVERSAL_MODE       # “local” | “cross”; if there’s a :universal option, use it this way (see `extend/ARGV.rb`)
# $HOMEBREW_VERBOSE_USING_DOTS   # Print heartbeat dots during long system calls (see `formula.rb`)

# Superenv environment variables:
# (also see HOMEBREW_CC below)
# $HOMEBREW_ARCHFLAGS          # Like $HOMEBREW_BUILD_ARCHS but as archflags
# $HOMEBREW_CCCFG              # A set of flags governing things like argument refurbishment
# $HOMEBREW_DISABLE__W         # Enable warnings by not inserting “-w”
# $HOMEBREW_FORCE_FLAGS        # Always inserted during argument refurbishment
ENV['HOMEBREW_GIT'] = "#{OPTDIR}/git/bin/git" if (OPTDIR/'git/bin/git').executable?  # see `ENV/scm/git`
# $HOMEBREW_INCLUDE_PATHS      # These are how -I flags reach ENV/super/cc
# $HOMEBREW_ISYSTEM_PATHS      # These are how -isystem flags reach ENV/super/cc
# $HOMEBREW_LIBRARY_PATHS      # These are how -L flags reach ENV/super/cc
# $HOMEBREW_OPTFLAGS           # Set to the compiler optimization flags suiting HOMEBREW_BUILD_ARCHS
# $HOMEBREW_OPTIMIZATION_LEVEL # This is how an -O flag reaches ENV/super/cc
# $HOMEBREW_SDKROOT            # Set to MacOS.sdk_path iff we have Xcode without command‐line tools
ENV['HOMEBREW_SVN'] = "#{OPTDIR}/subversion/bin/svn" if (OPTDIR/'subversion/bin/svn').executable?  # see `ENV/scm/git`

# Other environment variables used in brewing:
# $CC/$CXX/$FC/$OBJC/$OBJCXX # These combine $HOMEBREW_CC et al with ENV.build_archs.as_archflags
# $HOMEBREW_BUILD_ARCHS      # Tracks the architectures being built for
# $HOMEBREW_CC               # Tracks the selected compiler (see `extend/ENV/*.rb`)
# $HOMEBREW_CC_LOG_PATH      # This is set by `formula.rb` whenever it executes a Superenv build tool
# $HOMEBREW_MACH_O_FILE      # Briefly exists during `otool -L` parsing; see `mach.rb`
# $HOMEBREW_PROCESSOR_TYPE   # Set by `brew.sh` and used by `cmd/vendor-install.sh`

module Homebrew
  include FileUtils
  extend self

  attr_accessor :failed
  alias_method :failed?, :failed
end
