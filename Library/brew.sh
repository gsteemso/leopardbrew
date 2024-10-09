HOMEBREW_VERSION="0.9.5"

brew() {
  "$HOMEBREW_BREW_FILE" "$@"
}

odie() {
  if [[ -t 2 ]] # check whether stderr is a tty.
  then
    echo -ne "\033[4;31mError\033[0m: " >&2
    # highlight “Error” with underline and red color
  else
    echo -n "Error: " >&2
  fi
  if [[ $# -eq 0 ]]
  then
    /bin/cat >&2
  else
    echo "$*" >&2
  fi
  exit 1
}

safe_cd() {
  cd "$@" >/dev/null || odie "Error: failed to cd to $*!"
}

# Force UTF-8 to avoid encoding issues for users with broken locale settings.
if [[ "$(locale charmap 2> /dev/null)" != "UTF-8" ]]
then
  export LC_ALL="en_US.UTF-8"
fi

# Where we store built products.  [prefix]/Cellar if it exists ([prefix] is
# “/usr/local” by default) -- normally defaults to [repository]/Cellar.
if [[ -d "$HOMEBREW_PREFIX/Cellar" ]]
then
  HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
else
  HOMEBREW_CELLAR="$HOMEBREW_REPOSITORY/Cellar"
fi

case "$*" in
  --prefix) echo "$HOMEBREW_PREFIX"; exit 0 ;;
  --cellar) echo "$HOMEBREW_CELLAR"; exit 0 ;;
  --repository|--repo) echo "$HOMEBREW_REPOSITORY"; exit 0 ;;
esac
# note – if ARGV also contains anything else, the relevant `brew` subcommand is
# executed instead of one of these shortcuts

if [[ "$HOMEBREW_PREFIX" = "/" || "$HOMEBREW_PREFIX" = "/usr" ]]
then
  # it may work, but I only see pain this route and don't want to support it
  odie "Cowardly refusing to continue at this prefix: $HOMEBREW_PREFIX"
fi

# Users may have these set, pointing the system Ruby
# at non-system gem paths
unset GEM_HOME
unset GEM_PATH

HOMEBREW_SYSTEM="$(uname -s)"   # TODO:  Differentiate between bare Darwin and actual Mac OS
case "$HOMEBREW_SYSTEM" in
  Darwin) HOMEBREW_OSX="1";;
  Linux) HOMEBREW_LINUX="1";;
esac

HOMEBREW_CURL="/usr/bin/curl"
if [[ -n "$HOMEBREW_OSX" ]]
then
  HOMEBREW_PROCESSOR="$(uname -p)"
  HOMEBREW_PRODUCT="Leopardbrew"
  HOMEBREW_SYSTEM="Macintosh"
  # This is i386 even on x86_64 machines
  [[ "$HOMEBREW_PROCESSOR" = "i386" ]] && HOMEBREW_PROCESSOR="Intel"
  HOMEBREW_OSX_VERSION="$(/usr/bin/sw_vers -productVersion)"
  HOMEBREW_OS_VERSION="Mac OS $HOMEBREW_OSX_VERSION"
else
  HOMEBREW_PROCESSOR="$(uname -m)"
  HOMEBREW_PRODUCT="${HOMEBREW_SYSTEM}brew"
  [[ -n "$HOMEBREW_LINUX" ]] && HOMEBREW_OS_VERSION="$(lsb_release -sd 2>/dev/null)"
  : "${HOMEBREW_OS_VERSION:=$(uname -r)}"
fi
HOMEBREW_USER_AGENT="$HOMEBREW_PRODUCT/$HOMEBREW_VERSION ($HOMEBREW_SYSTEM; $HOMEBREW_PROCESSOR $HOMEBREW_OS_VERSION)"
HOMEBREW_CURL_VERSION="$("$HOMEBREW_CURL" --version 2>/dev/null | head -n1 | /usr/bin/awk '{print $1"/"$2}')"
HOMEBREW_USER_AGENT_CURL="$HOMEBREW_USER_AGENT $HOMEBREW_CURL_VERSION"

if [[ -z "$HOMEBREW_CACHE" ]]
then
  HOMEBREW_CACHE="$HOME/Library/Caches/Homebrew"
fi

# We want to ensure that newer Intel Macs use our Ruby/curl, too
HOMEBREW_FORCE_VENDOR_RUBY="1"

# Declared in bin/brew
export HOMEBREW_BREW_FILE
export HOMEBREW_LIBRARY
export HOMEBREW_PREFIX
export HOMEBREW_REPOSITORY

# Declared here in brew.sh
export HOMEBREW_CACHE
export HOMEBREW_CELLAR
export HOMEBREW_CURL  # ← may be updated by `vendor-curl.sh` (sourced below)
export HOMEBREW_LIBRARY_PATH="${HOMEBREW_LIBRARY}/Homebrew"
export HOMEBREW_OS_VERSION
export HOMEBREW_OSX_VERSION
# HOMEBREW_RUBY_PATH is also exported from `ruby.sh` (sourced below)
export HOMEBREW_SYSTEM
export HOMEBREW_USER_AGENT
export HOMEBREW_USER_AGENT_CURL  # ← may be updated below
export HOMEBREW_VERSION

if [[ -n "$HOMEBREW_OSX" ]]
then
  if [[ -f "/usr/bin/xcode-select" ]] && [[ "$('/usr/bin/xcode-select' --print-path)" = "/" ]]
  then
    odie <<EOS
Your xcode-select path is currently set to '/'.
This causes the 'xcrun' tool to hang, and can render Homebrew unusable.
If you are using Xcode, you should:
  sudo xcode-select -switch /Applications/Xcode.app
Otherwise, you should:
  sudo rm -rf /usr/share/xcode-select
EOS
  fi

  XCRUN_OUTPUT="$(/usr/bin/xcrun clang 2>&1)"
  XCRUN_STATUS="$?"

  if [[ "$XCRUN_STATUS" -ne 0 && "$XCRUN_OUTPUT" = *license* ]]
  then
    odie <<EOS
You have not agreed to the Xcode license. Please resolve this by running:
  sudo xcodebuild -license
EOS
  fi
fi

# Many Pathname operations use getwd when they shouldn't, and then throw
# odd exceptions. Reduce our support burden by showing a user-friendly error.
if [[ ! -d "$(pwd)" ]]
then
  odie "The current working directory doesn't exist, cannot proceed."
fi

if [[ "$1" = -v ]]
then
  # Shift the -v to the end of the parameter list
  shift
  set -- "$@" -v
fi

HOMEBREW_ARG_COUNT="$#"
HOMEBREW_COMMAND="$1"
shift
case "$HOMEBREW_COMMAND" in
  ls)          HOMEBREW_COMMAND="list";;
  homepage)    HOMEBREW_COMMAND="home";;
  -S)          HOMEBREW_COMMAND="search";;
  up)          HOMEBREW_COMMAND="update";;
  ln)          HOMEBREW_COMMAND="link";;
  instal)      HOMEBREW_COMMAND="install";; # gem does the same
  rm)          HOMEBREW_COMMAND="uninstall";;
  remove)      HOMEBREW_COMMAND="uninstall";;
  configure)   HOMEBREW_COMMAND="diy";;
  abv)         HOMEBREW_COMMAND="info";;
  dr)          HOMEBREW_COMMAND="doctor";;
  --repo)      HOMEBREW_COMMAND="--repository";;
  environment) HOMEBREW_COMMAND="--env";;
  --config)    HOMEBREW_COMMAND="config";;
esac

if [[ -f "$HOMEBREW_LIBRARY_PATH/cmd/$HOMEBREW_COMMAND.sh" ]]; then
  HOMEBREW_BASH_COMMAND="$HOMEBREW_LIBRARY_PATH/cmd/$HOMEBREW_COMMAND.sh"
elif [[ -n "$HOMEBREW_DEVELOPER" && -f "$HOMEBREW_LIBRARY_PATH/dev-cmd/$HOMEBREW_COMMAND.sh" ]]; then
  HOMEBREW_BASH_COMMAND="$HOMEBREW_LIBRARY_PATH/dev-cmd/$HOMEBREW_COMMAND.sh"
fi

if [[ "$(id -u)" = "0" && "$(/usr/bin/stat -f%u "$HOMEBREW_BREW_FILE")" != "0" ]]
then
  case "$HOMEBREW_COMMAND" in
    install|reinstall|postinstall|link|pin|unpin|update|upgrade|vendor-install|create|migrate|tap|tap-pin|switch)
      odie <<EOS
Cowardly refusing to 'sudo brew $HOMEBREW_COMMAND'
You can use brew with sudo, but only if the brew executable is owned by root.
However, this is both not recommended and completely unsupported so do so at
your own risk.
EOS
      ;;
  esac
fi

# Hide shellcheck complaint:
# shellcheck source=/dev/null
source "$HOMEBREW_LIBRARY_PATH/utils/ruby.sh"
setup-ruby-path
if [[ -x "$HOMEBREW_LIBRARY_PATH/cmd/vendor-curl.sh" ]]
then
  source "$HOMEBREW_LIBRARY_PATH/cmd/vendor-curl.sh"
  setup-curl-path
  # This may have changed after we vendored curl; regenerate it
  HOMEBREW_CURL_VERSION="$("$HOMEBREW_CURL" --version 2>/dev/null | head -n1 | /usr/bin/awk '{print $1"/"$2}')"
  HOMEBREW_USER_AGENT_CURL="$HOMEBREW_USER_AGENT $HOMEBREW_CURL_VERSION"
  export HOMEBREW_USER_AGENT_CURL
fi

if [[ -n "$HOMEBREW_BASH_COMMAND" ]]
then
  # source rather than executing directly to ensure the whole file is read into
  # memory before it is run. This makes running a Bash script behave more like
  # a Ruby script and avoids hard-to-debug issues if the Bash script is updated
  # at the same time as being run.
  #
  # Hide shellcheck complaint:
  # shellcheck source=/dev/null
  source "$HOMEBREW_BASH_COMMAND"
  { "homebrew-$HOMEBREW_COMMAND" "$@"; exit $?; }
else
  # Unshift command back into argument list (unless argument list was empty).
  [[ "$HOMEBREW_ARG_COUNT" -gt 0 ]] && set -- "$HOMEBREW_COMMAND" "$@"
  exec "$HOMEBREW_RUBY_PATH" -W0 "$HOMEBREW_LIBRARY/brew.rb" "$@"
fi
