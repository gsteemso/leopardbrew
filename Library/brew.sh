#!/bin/sh

LEOPARDBREW_VERSION='0.5.2'

###### Convenience functions ######

brew() { "$HOMEBREW_BREW_FILE" "$@" ; }

onoe() {
  # If stderr is a terminal, underline “Error” & print it in red
  if [ -t 2 ]; then echo -ne "\033[4;31mError\033[0m:  " >&2; else echo -n 'Error:  ' >&2 ; fi
  if [ $# -eq 0 ]; then /bin/cat >&2 ; else echo "$*" >&2 ; fi
}

odie() { onoe "$@"; exit 1; }

safe_cd() { cd "$@" >/dev/null || odie "Error: failed to cd to $*!"; }

version_string() {
  maj="$(echo "$1" | cut -d . -f 1)"
  min="$(echo "$1" | cut -d . -f 2)"; if [ -z "$min" ]; then min='00'; fi
  bug="$(echo "$1" | cut -d . -f 3)"; if [ -z "$bug" ]; then bug='00'; fi
  printf '%02.2s%02.2s%02.2s' "$maj" "$min" "$bug"
}

###### Preliminaries ######

# Force UTF-8 to avoid encoding issues for users with broken locale settings.
if [ "$(locale charmap 2> /dev/null)" != 'UTF-8' ]; then export LC_ALL='en_US.UTF-8'; fi

# Where we store built products.  [prefix]/Cellar if it exists (default [prefix] is “/usr/local”) – but usually [repository]/Cellar.
if [ -d "$HOMEBREW_PREFIX/Cellar" ]; then HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
else HOMEBREW_CELLAR="$HOMEBREW_REPOSITORY/Cellar"; fi

if ! [ -d "$HOMEBREW_CELLAR" ]; then mkdir "$HOMEBREW_CELLAR"; fi

case "$*" in
  --prefix) echo "$HOMEBREW_PREFIX"; exit 0 ;;
  --cellar) echo "$HOMEBREW_CELLAR"; exit 0 ;;
  --repository|--repo) echo "$HOMEBREW_REPOSITORY"; exit 0 ;;
esac
# Note – if ARGV also contains anything else, the relevant `brew` subcommand is executed instead of one of these shortcuts.

# Where we keep the Homebrew Ruby libraries.
HOMEBREW_RUBY_LIBRARY="${HOMEBREW_LIBRARY}/Homebrew"

# This should be set to the system “/Library/Caches/Homebrew” for a multi‐user machine.
[ -d '/Library/Caches/Homebrew' -a -z "$HOMEBREW_CACHE" ] && HOMEBREW_CACHE='/Library/Caches/Homebrew'
[ -z "$HOMEBREW_CACHE" ] && HOMEBREW_CACHE="$HOME/Library/Caches/Homebrew"

###### Sanity checks ######

[ "$HOMEBREW_PREFIX" = '/' -o "$HOMEBREW_PREFIX" = '/usr' ] && odie "Refusing to continue at this prefix:  $HOMEBREW_PREFIX"

# Many Pathname operations use getwd() when they shouldn’t, and then fail in strange ways.  Reduce our support burden by showing a
# user-friendly error.
[ -d "$(pwd)" ] || odie 'The current working directory doesn’t exist; cannot proceed.'

###### The command line ######

if [ "$1" = -v ]; then shift; set -- "$@" -v; fi  # Shift the -v to the end of the parameter list

HOMEBREW_ARG_COUNT="$#"
HOMEBREW_COMMAND="$1"
shift
case "$HOMEBREW_COMMAND" in
  ls)          HOMEBREW_COMMAND='list';;
  homepage)    HOMEBREW_COMMAND='home';;
  -S)          HOMEBREW_COMMAND='search';;
  up)          HOMEBREW_COMMAND='update';;
  ln)          HOMEBREW_COMMAND='link';;
  instal)      HOMEBREW_COMMAND='install';; # gem does the same
  rm)          HOMEBREW_COMMAND='uninstall';;
  remove)      HOMEBREW_COMMAND='uninstall';;
  configure)   HOMEBREW_COMMAND='diy';;
  abv)         HOMEBREW_COMMAND='info';;
  dr)          HOMEBREW_COMMAND='doctor';;
  --repo)      HOMEBREW_COMMAND='--repository';;
  environment) HOMEBREW_COMMAND='--env';;
  --config)    HOMEBREW_COMMAND='config';;
esac

if [ -f "$HOMEBREW_RUBY_LIBRARY/cmd/$HOMEBREW_COMMAND.sh" ]; then
  HOMEBREW_BASH_COMMAND="$HOMEBREW_RUBY_LIBRARY/cmd/$HOMEBREW_COMMAND.sh"
elif [ -n "$HOMEBREW_DEVELOPER" -a -f "$HOMEBREW_RUBY_LIBRARY/dev-cmd/$HOMEBREW_COMMAND.sh" ]; then
  HOMEBREW_BASH_COMMAND="$HOMEBREW_RUBY_LIBRARY/dev-cmd/$HOMEBREW_COMMAND.sh"
fi

[ "$(id -u)" = '0' ] && [ "$(/usr/bin/stat -f%u "$HOMEBREW_BREW_FILE")" != '0' ] &&
  case "$HOMEBREW_COMMAND" in
    install|reinstall|postinstall|link|pin|unpin|update|upgrade|vendor-install|create|migrate|tap|tap-pin|switch)
      odie <<EOS
Refusing to “sudo brew $HOMEBREW_COMMAND”.
You can use brew with sudo, but only if the brew executable is owned by root.
However, this is neither supported in any way nor recommended; do so at your
own risk.
EOS
      ;;
  esac

###### Identity stuff ######

HOMEBREW_PROCESSOR_TYPE="$(uname -p)"
# This is i386 even on x86_64 machines
[ "$HOMEBREW_PROCESSOR_TYPE" = 'i386' ] && HOMEBREW_PROCESSOR_TYPE='Intel'
HOMEBREW_OS_VERSION="$(/usr/bin/sw_vers -productVersion)"
HOMEBREW_OS_VERSION_DIGITS="$(version_string "$HOMEBREW_OS_VERSION")"
HOMEBREW_USER_AGENT="Leopardbrew/$LEOPARDBREW_VERSION (Macintosh; $HOMEBREW_PROCESSOR_TYPE Mac OS $HOMEBREW_OS_VERSION)"

###### More sanity checks ######

# Check early for bad xcode-select, because `doctor` and many other things will hang.  Note that this bug was fixed in 10.9.
[ $HOMEBREW_OS_VERSION_DIGITS -lt 100900 ] && [ -f '/usr/bin/xcode-select' ] \
  && [ "$('/usr/bin/xcode-select' --print-path)" = '/' ] && odie <<EOS
Your xcode-select path is currently set to “/”.
This causes the ‘xcrun’ tool to hang, and can render Homebrew unusable.
If you are using Xcode, you should:
    sudo xcode-select -switch /Applications/Xcode.app
Otherwise, you should:
    sudo rm -rf /usr/share/xcode-select
EOS

XCRUN_OUTPUT="$(/usr/bin/xcrun clang 2>&1)"
[ "$?" -ne 0 ] &&
  case "$XCRUN_OUTPUT" in
    *license*)
      odie <<EOS
You have not agreed to the Xcode license.  Please resolve this by running:
    sudo xcodebuild -license
EOS
      ;;
  esac

###### Ruby and Curl ######

# Users may have these set, pointing the system Ruby at non-system gem paths
unset GEM_HOME
unset GEM_PATH

# Hide shellcheck complaint:
# shellcheck source=/dev/null
source "$HOMEBREW_RUBY_LIBRARY/utils/vendor-ruby.sh"
setup-ruby-path

source "$HOMEBREW_RUBY_LIBRARY/utils/vendor-curl.sh"
setup-curl-path

HOMEBREW_CURL_VERSION="$("$HOMEBREW_CURL_PATH" --version 2>/dev/null | head -n1 | /usr/bin/awk '{print $1"/"$2}')"
HOMEBREW_USER_AGENT_CURL="$HOMEBREW_USER_AGENT $HOMEBREW_CURL_VERSION"

###### Exports to the Ruby side ######

# Declared in bin/brew
export HOMEBREW_BREW_FILE
export HOMEBREW_LIBRARY
export HOMEBREW_PREFIX
export HOMEBREW_REPOSITORY

# Declared in setup-____-path
export HOMEBREW_CURL_PATH
export HOMEBREW_RUBY_PATH

# Declared here in brew.sh
export HOMEBREW_CACHE
export HOMEBREW_CELLAR
export HOMEBREW_PROCESSOR_TYPE
export HOMEBREW_RUBY_LIBRARY
export HOMEBREW_OS_VERSION
export HOMEBREW_USER_AGENT
export HOMEBREW_USER_AGENT_CURL
export LEOPARDBREW_VERSION

###### Command execution ######

if [ -n "$HOMEBREW_BASH_COMMAND" ]; then
  # Source rather than executing directly, to ensure the whole file is loaded before it is run.  This makes running a Bash script
  # behave more like a Ruby script and avoids hard-to-debug issues if the Bash script is updated at the same time as being run.
  # Hide shellcheck complaint:
  # shellcheck source=/dev/null
  source "$HOMEBREW_BASH_COMMAND"
  { "homebrew-$HOMEBREW_COMMAND" "$@"; exit $?; }
else # There is no shell‐script version of the command.
  # Unshift command back into argument list (unless it was empty, i.e. there was no command).
  [ "$HOMEBREW_ARG_COUNT" -gt 0 ] && set -- "$HOMEBREW_COMMAND" "$@"
  if [ -n "$HOMEBREW_DEBUG_RUBY" ]; then
    export HOMEBREW_DEBUG_RUBY
    exec "$HOMEBREW_RUBY_PATH" -d -W0 "$HOMEBREW_LIBRARY/brew.rb" "$@"
  else
    exec "$HOMEBREW_RUBY_PATH" -W0 "$HOMEBREW_LIBRARY/brew.rb" "$@"
  fi
fi
