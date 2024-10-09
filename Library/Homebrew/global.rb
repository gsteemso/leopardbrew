require 'pathname'  #
require 'rbconfig'  # Ruby libraries
require 'set'       #
# all these others are Homebrew libraries
require 'extend/leopard' if RUBY_VERSION <= '1.8.6'
require 'extend/tiger' if RUBY_VERSION == '1.8.2'
require 'extend/ARGV'
require 'extend/fileutils'
require 'extend/module'
require 'extend/pathname'
require 'extend/string'
require 'exceptions'
require 'os'
require 'utils'

ARGV.extend(HomebrewArgvExtension)

if ENV['HOMEBREW_BREW_FILE']
  # Path to main executable ($HOMEBREW_PREFIX/bin/brew):
  HOMEBREW_BREW_FILE = Pathname.new(ENV['HOMEBREW_BREW_FILE'])
else
  odie '$HOMEBREW_BREW_FILE was not exported! Please call bin/brew directly!'
end

RbConfig = Config if RUBY_VERSION < '1.8.6'  # different module name on Tiger

# Predefined pathnames:
CONFIG_RUBY_PATH        = if RbConfig.respond_to?(:ruby)            # The current Ruby binary
                          then Pathname.new(RbConfig.ruby)
                          else Pathname.new(RbConfig::CONFIG['bindir']).join \
                              (RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT'])
                          end
  CONFIG_RUBY_BIN       =   CONFIG_RUBY_PATH.dirname                # Where it lives
HOMEBREW_CACHE          = Pathname.new(ENV['HOMEBREW_CACHE'])
                          # Where downloads (bottles, source tarballs, etc.) are cached
  HOMEBREW_CACHE_FORMULA =  HOMEBREW_CACHE/'Formula'
                            # Where brews installed via URL are cached
HOMEBREW_CELLAR         = Pathname.new(ENV['HOMEBREW_CELLAR'])
HOMEBREW_CURL           = Pathname.new(ENV['HOMEBREW_CURL'])
HOMEBREW_LIBRARY        = Pathname.new(ENV['HOMEBREW_LIBRARY'])
  HOMEBREW_CONTRIB      =   HOMEBREW_LIBRARY/'Contributions'
  LINKDIR               =   HOMEBREW_LIBRARY/'LinkedKegs'           # Records which kegs are linked
  PINDIR                =   HOMEBREW_LIBRARY/'PinnedKegs'           # see `formula_pin.rb`
HOMEBREW_LIBRARY_PATH   = Pathname.new(ENV['HOMEBREW_LIBRARY_PATH']) # Homebrew’s Ruby libraries
  HOMEBREW_LOAD_PATH    =   HOMEBREW_LIBRARY_PATH
                            # The path to our libraries /when invoking Ruby/.  Is sometimes set to
                            # a custom value during unit testing of Homebrew itself.
HOMEBREW_PREFIX         = Pathname.new(ENV['HOMEBREW_PREFIX'])      # Where we link under
  OPTDIR                =   HOMEBREW_PREFIX/'opt'                   # Where we are always available
HOMEBREW_REPOSITORY     = Pathname.new(ENV['HOMEBREW_REPOSITORY'])  # Where .git is found
HOMEBREW_RUBY_PATH      = Pathname.new(ENV['HOMEBREW_RUBY_PATH'])   # Our internal Ruby binary
  HOMEBREW_RUBY_BIN     =   HOMEBREW_RUBY_PATH.parent               # Where it lives
SYSTEM_RUBY_PATH        = Pathname.new('/usr/bin/ruby')             # The system Ruby binary
  SYSTEM_RUBY_BIN       =   SYSTEM_RUBY_PATH.parent                 # Where it lives
gtar = HOMEBREW_PREFIX/'opt/gnu-tar/bin/gtar'
TAR_PATH                = Pathname.new(gtar.executable? ? gtar : which('tar'))

# Predefined regular expressions:
# CompilerConstants::GNU_CXX11_REGEXP #
# CompilerConstants::GNU_CXX14_REGEXP # see `compilers.rb`
# CompilerConstants::GNU_GCC_REGEXP   #
HOMEBREW_CASK_TAP_FORMULA_REGEX   = %r{^(Caskroom)/(cask)/([\w+-.]+)$}
                                    # Match formulæ in the default brew‐cask tap, e.g. Caskroom/cask/someformula
HOMEBREW_CORE_FORMULA_REGEX       = %r{^homebrew/homebrew/([\w+-.]+)$}i
                                    # Match core formulæ, e.g. homebrew/homebrew/someformula
HOMEBREW_PULL_OR_COMMIT_URL_REGEX = %r{https://github\.com/([\w-]+)/tigerbrew(-[\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})}
HOMEBREW_TAP_ARGS_REGEX           = %r{^([\w-]+)/(homebrew-)?([\w-]+)$}
                                    # Match taps given as arguments, e.g. someuser/sometap
HOMEBREW_TAP_DIR_REGEX            = %r{#{Regexp.escape(HOMEBREW_LIBRARY.to_s)}/Taps/([\w-]+)/([\w-]+)}
                                    # Match taps’ directory paths, e.g. HOMEBREW_LIBRARY/Taps/someuser/sometap
HOMEBREW_TAP_FORMULA_REGEX        = %r{^([\w-]+)/([\w-]+)/([\w+-.@]+)$}
                                    # Match taps’ formulæ, e.g. someuser/sometap/someformula
  HOMEBREW_TAP_PATH_REGEX         =   Regexp.new(HOMEBREW_TAP_DIR_REGEX.source + %r{/(.*)}.source)
                                      # Match taps’ formula paths, e.g. HOMEBREW_LIBRARY/Taps/someuser/sometap/someformula
# Pathname::BOTTLE_EXTNAME_RX       # see `extend/pathname.rb`

# Other predefined values:
# CompilerConstants::CLANG_CXX11_MIN #
# CompilerConstants::CLANG_CXX14_MIN # see `compilers.rb`
# CompilerConstants::COMPILERS       #
HOMEBREW_CURL_ARGS          = '-f#LA'
HOMEBREW_INTERNAL_COMMAND_ALIASES = \
                              { 'ls'          => 'list',
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
HOMEBREW_SYSTEM             = ENV['HOMEBREW_SYSTEM']
HOMEBREW_USER_AGENT         = ENV['HOMEBREW_USER_AGENT']
HOMEBREW_USER_AGENT_CURL    = ENV['HOMEBREW_USER_AGENT_CURL']
    ruby_version = "#{RUBY_VERSION}#{"-p#{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL}"
HOMEBREW_USER_AGENT_RUBY    = "#{HOMEBREW_USER_AGENT} ruby/#{ruby_version}"
HOMEBREW_VERSION            = ENV['HOMEBREW_VERSION']  # Permanently fixed at 0.9.5
HOMEBREW_WWW                = 'https://github.com/gsteemso/leopardbrew'
# MACOS_FULL_VERSION        # Imported from $HOMEBREW_OSX_VERSION in `os.rb`
# MACOS_VERSION             # Just the numeric part (see `os.rb`)
OS_VERSION                  = ENV['HOMEBREW_OS_VERSION']
# Tab::FILENAME             # see `tab.rb`

# Optionally user‐defined values:
BREW_NICE_LEVEL = ENV['HOMEBREW_NICE_LEVEL']  # Do we `nice` our build process?
DEBUG           = ARGV.debug?                 # Checks all of “-d”, “--debug”, & $HOMEBREW_DEBUG
DEVELOPER       = ARGV.homebrew_developer?    # Enable developer commands (checks both
                                              #   “--homebrew-developer” & $HOMEBREW_DEVELOPER)
HOMEBREW_GITHUB_API_TOKEN = ENV['HOMEBREW_GITHUB_API_TOKEN']    # For unthrottled Github access
HOMEBREW_LOGS   = Pathname.new(ENV.fetch 'HOMEBREW_LOGS', '~/Library/Logs/Homebrew/').expand_path
                  # Where build, postinstall, and test logs of formulæ are written to
HOMEBREW_TEMP   = Pathname.new(ENV.fetch 'HOMEBREW_TEMP', '/tmp')
                  # Where temporary folders for building and testing formulæ are created
NO_COMPAT       = ENV['HOMEBREW_NO_COMPAT']
ORIGINAL_PATHS  = ENV['PATH'].split(File::PATH_SEPARATOR).map { |p| Pathname.new(p).expand_path rescue nil }.compact.freeze
QUIETER         = ARGV.quieter?               # Give as little feedback as possible
VERBOSE         = ARGV.verbose?               # Give lots of feedback (checks all of “-v”,
                                              #   “--verbose”, $HOMEBREW_VERBOSE, & $VERBOSE)

# Further housekeeping:
require 'compat' unless ARGV.include?('--no-compat') || NO_COMPAT

# Environment variables that affect ARGV and/or builds (unless noted, see `extend/ARGV.rb`):
# HOMEBREW_BUILD_BOTTLE      # Always build a bottle instead of a normal installation
# HOMEBREW_BUILD_FROM_SOURCE # Force building from source even when there is a bottle
# HOMEBREW_BUILD_UNIVERSAL   # If there’s a :universal option, always use it
# HOMEBREW_PREFER_64_BIT     # Build 64‐bit by default (required to build --universal; see `os/mac.rb`)
# HOMEBREW_QUIET             # Show as little as possible
# HOMEBREW_SANDBOX           # hells if I know
# HOMEBREW_VERBOSE           # Show build messages
#   VERBOSE                  #   Same thing but system‐wide

# Environment variables that can be used to control Superenv:
# HOMEBREW_CC_LOG_PATH    # This is set by `formula.rb` whenever it executes a Superenv build tool
# HOMEBREW_FORCE_FLAGS    # When argument refurbishment is performed, these are always inserted
# HOMEBREW_INCLUDE_PATHS  # These are how -I flags reach ENV/*/cc
# HOMEBREW_ISYSTEM_PATHS  # These are how -isystem flags reach ENV/*/cc
# HOMEBREW_LIBRARY_PATHS  # These are how -L flags reach ENV/*/cc

# Other environment variables:
# HOMEBREW_MACH_O_FILE    # Briefly exists during `otool -L` parsing; see `mach.rb`

module Homebrew
  include FileUtils
  extend self

  attr_accessor :failed
  alias_method :failed?, :failed
end
