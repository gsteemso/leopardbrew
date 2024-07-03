require 'pathname'  #
require 'rbconfig'  # Ruby libraries
require 'set'       #
# all these others are Homebrew libraries
require 'extend/tiger' if RUBY_VERSION == '1.8.2'
require 'extend/leopard' if RUBY_VERSION <= '1.8.6'
require 'extend/ARGV'
require 'extend/fileutils'
require 'extend/module'
require 'extend/pathname'
require 'extend/string'
require 'exceptions'
require 'os'
require 'utils'

if ENV['HOMEBREW_BREW_FILE']
  # Path to `bin/brew` main executable in {HOMEBREW_PREFIX}
  HOMEBREW_BREW_FILE = Pathname.new(ENV['HOMEBREW_BREW_FILE'])
else
  odie '$HOMEBREW_BREW_FILE was not exported! Please call bin/brew directly!'
end

# Predefined pathnames:
HOMEBREW_CACHE           = Pathname.new(ENV['HOMEBREW_CACHE'])
                           # Where downloads (bottles, source tarballs, etc.) are cached
  HOMEBREW_CACHE_FORMULA =   HOMEBREW_CACHE/'Formula'
                             # Where brews installed via URL are cached
HOMEBREW_CELLAR          = Pathname.new(ENV['HOMEBREW_CELLAR'])
HOMEBREW_LIBRARY         = Pathname.new(ENV['HOMEBREW_LIBRARY'])
  HOMEBREW_CONTRIB       =   HOMEBREW_LIBRARY/'Contributions'
  HOMEBREW_LIBRARY_PATH  =   HOMEBREW_LIBRARY/'Homebrew'            # Homebrew’s Ruby libraries
  HOMEBREW_LOAD_PATH     =   HOMEBREW_LIBRARY_PATH
                             # The path to our libraries /when invoking Ruby/.  Is sometimes set to
                             # a custom value during unit testing of Homebrew itself.
HOMEBREW_PREFIX          = Pathname.new(ENV['HOMEBREW_PREFIX'])     # Where we link under
HOMEBREW_REPOSITORY      = Pathname.new(ENV['HOMEBREW_REPOSITORY']) # Where .git is found
HOMEBREW_VERSION         = Pathname.new(ENV['HOMEBREW_VERSION'])    # Permanently fixed at 0.9.5

# Predefined miscellaneous values:
HOMEBREW_USER_AGENT_CURL = ENV['HOMEBREW_USER_AGENT_CURL']

# Optional user‐defined values:
HOMEBREW_GITHUB_API_TOKEN = ENV['HOMEBREW_GITHUB_API_TOKEN']
                            # For unthrottled access to Github repositories
HOMEBREW_LOGS = Pathname.new(ENV.fetch 'HOMEBREW_LOGS', '~/Library/Logs/Homebrew/').expand_path
                # Where build, postinstall, and test logs of formulæ are written to
HOMEBREW_TEMP = Pathname.new(ENV.fetch 'HOMEBREW_TEMP', '/tmp')
                # Where temporary folders for building and testing formulæ are created

ARGV.extend(HomebrewArgvExtension)

HOMEBREW_WWW = 'https://github.com/gsteemso/leopardbrew'

RbConfig = Config if RUBY_VERSION < '1.8.6'  # different module name on Tiger

if RbConfig.respond_to?(:ruby)
  RUBY_PATH = Pathname.new(RbConfig.ruby)
else
  RUBY_PATH = Pathname.new(RbConfig::CONFIG['bindir']).join(
    RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']
  )
end
RUBY_BIN = RUBY_PATH.dirname  # the directory our Ruby interpreter lives in

if RUBY_PLATFORM =~ /darwin/  # TODO:  need to disambiguate Mac OS from bare Darwin
  MACOS_FULL_VERSION = `/usr/bin/sw_vers -productVersion`.chomp
  MACOS_VERSION = MACOS_FULL_VERSION[/\d\d\.\d+/]
  OS_VERSION = "Mac OS #{MACOS_FULL_VERSION}"
else
  MACOS_FULL_VERSION = MACOS_VERSION = '0'
  OS_VERSION = RUBY_PLATFORM
end

ruby_version = "#{RUBY_VERSION}#{"-p#{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL}"
HOMEBREW_USER_AGENT_RUBY = "#{ENV['HOMEBREW_USER_AGENT']} ruby/#{ruby_version}"

HOMEBREW_CURL_ARGS = '-f#LA'

require 'tap_constants'

module Homebrew
  include FileUtils
  extend self

  attr_accessor :failed
  alias_method :failed?, :failed
end

HOMEBREW_PULL_OR_COMMIT_URL_REGEX = %r[https://github\.com/([\w-]+)/tigerbrew(-[\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})]

require 'compat' unless ARGV.include?('--no-compat') || ENV['HOMEBREW_NO_COMPAT']

ORIGINAL_PATHS = ENV['PATH'].split(File::PATH_SEPARATOR).map { |p| Pathname.new(p).expand_path rescue nil }.compact.freeze

HOMEBREW_INTERNAL_COMMAND_ALIASES = {
  'ls'          => 'list',
  'homepage'    => 'home',
  '-S'          => 'search',
  'up'          => 'update',
  'ln'          => 'link',
  'instal'      => 'install', # gem does the same
  'rm'          => 'uninstall',
  'remove'      => 'uninstall',
  'configure'   => 'diy',
  'abv'         => 'info',
  'dr'          => 'doctor',
  '--repo'      => '--repository',
  'environment' => '--env',
  '--config'    => 'config'
}
