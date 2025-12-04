#:Install the vendor version of Homebrew dependencies.
#:
#:  Usage:  brew vendor-install /target/
#:
#:Currently, /target/ must be exactly one of “curl” or “ruby”.  Note:  This will
#:fail if your system curl is too old and the Leopardbrew vendor curl is not yet
#:installed.

# Hide shellcheck complaint:
# shellcheck source=/dev/null
source "$HOMEBREW_RUBY_LIBRARY/utils/lock.sh"

VENDOR_DIR="$HOMEBREW_RUBY_LIBRARY/vendor"

# Built from https://github.com/Homebrew/homebrew-portable.
if [ "$HOMEBREW_PROCESSOR_TYPE" = "powerpc" ]; then
  # PPC-only 10.4 build
  curl_URL="http://archive.org/download/tigerbrew/portable-curl-7.58.0-1.tiger_g3.bottle.tar.gz"
  curl_SHA="93f18319a239905f5e8b5443825548bc870a639d8019b9e2d0c84c33d84794fe"
  ruby_URL="http://archive.org/download/tigerbrew/portable-ruby-2.3.3.tiger_g3.bottle.tar.gz"
  ruby_SHA="162bed8c95fb30d4580ebc7dfadbb9d699171edbd7b60d8259de7f4cfc55cc32"
else
  # Intel-only 10.4 build
  curl_URL="http://archive.org/download/tigerbrew/portable-curl-7.58.0-1.tiger_i386.bottle.tar.gz"
  curl_SHA="0dbcffe698aa47189bb1d5d3b0ef284e2255b75f10284d57927091c9846e7d43"
  ruby_URL="http://archive.org/download/tigerbrew/portable-ruby-2.3.3.tiger_i386.bottle.tar.gz"
  ruby_SHA="7f4f13348d583bc9e8594d2b094c6b0140ce0a32a226a145b8b7f9993fca8c28"
fi

_fetch() {
  local -a curl_args
  local sha
  local temporary_path

  echo '==> Please wait... leopards are now brewing'
  echo "Downloading Leopardbrew’s ${VENDOR_NAME}; this may take some time"

  curl_args=( --fail --remote-time --location --user-agent "$HOMEBREW_USER_AGENT_CURL" )

  if [ -n "$HOMEBREW_QUIET" ]; then curl_args["${#curl_args[*]}"]='--silent'
  elif [ -z "$HOMEBREW_VERBOSE" ]; then curl_args["${#curl_args[*]}"]='--progress-bar'
  fi

  temporary_path="${CACHED_LOCATION}.incomplete"

  mkdir -p "$HOMEBREW_CACHE"
  [ -n "$HOMEBREW_QUIET" ] || echo "==> Downloading $VENDOR_URL"
  if [ -f "$CACHED_LOCATION" ]; then
    [ -n "$HOMEBREW_QUIET" ] || echo "Already downloaded: $CACHED_LOCATION"
  else
    if [ -f "$temporary_path" ]; then
      "$HOMEBREW_CURL_PATH" "${curl_args[@]}" -C - "$VENDOR_URL" -o "$temporary_path"
      if [ $? -eq 33 ] ; then
        [ -n "$HOMEBREW_QUIET" ] || echo 'Trying a full download'
        rm -f "$temporary_path"
        "$HOMEBREW_CURL_PATH" "${curl_args[@]}" "$VENDOR_URL" -o "$temporary_path"
      fi
    else
      "$HOMEBREW_CURL_PATH" "${curl_args[@]}" "$VENDOR_URL" -o "$temporary_path"
    fi

    [ -f "$temporary_path" ] || odie "Download failed: ${VENDOR_URL}"

    trap '' SIGINT
    mv "$temporary_path" "$CACHED_LOCATION"
    trap - SIGINT
  fi

  if [ "$(sysctl -n hw.cputype)" != "18" ]  # not powerpc:  arm or intel
  then cpu_model="$(sysctl -n hw.cpufamily)"
  else cpu_model="$(sysctl -n hw.cpusubtype)"; fi

  if [ -x "$(which shasum)" ]; then
    sha="$(shasum -a 256 "$CACHED_LOCATION" | cut -d' ' -f1)"
  elif [ -x "$(which sha256sum)" ]; then
    sha="$(sha256sum "$CACHED_LOCATION" | cut -d' ' -f1)"
  # Ruby 1.8.2's vendored Ruby has broken SHA256 calculation on several PowerPC CPUs
  elif [ -x "$(which ruby)" -a "$cpu_model" != 9 -a "$cpu_model" != 10 -a "$cpu_model" != 11 ]; then
    sha="$(ruby -e "require 'digest/sha2'; digest = Digest::SHA256.new; File.open('$CACHED_LOCATION', 'rb') { |f| digest.update(f.read) }; puts digest.hexdigest")"
  else
    # Pure Perl SHA256 implementation
    sha="$($VENDOR_DIR/sha256 "$CACHED_LOCATION")"
  fi

  [ "$sha" != "$VENDOR_SHA" ] && odie <<EOS
Checksum mismatch.
Expected: $VENDOR_SHA
Actual: $sha
Archive: $CACHED_LOCATION
To retry an incomplete download, remove the file above.
EOS
}

_install() {
  local tar_args
  local verb

  if [ -n "$HOMEBREW_VERBOSE" ]; then tar_args="xvzf"; else tar_args="xzf"; fi

  mkdir -p "$VENDOR_DIR/portable-$VENDOR_NAME"
  safe_cd "$VENDOR_DIR/portable-$VENDOR_NAME"

  trap '' SIGINT

  if [ -d "$VENDOR_VERSION" ]; then
    verb="reinstall"
    mv "$VENDOR_VERSION" "$VENDOR_VERSION.reinstall"
  elif [ -n "$(ls -A .)" ]; then
    verb="upgrade"
  else
    verb="install"
  fi

  safe_cd "$VENDOR_DIR"
  [ -n "$HOMEBREW_QUIET" ] || echo "==> Unpacking $(basename "$VENDOR_URL")"
  tar "$tar_args" "$CACHED_LOCATION"
  safe_cd "$VENDOR_DIR/portable-$VENDOR_NAME"

  if "./$VENDOR_VERSION/bin/$VENDOR_NAME" --version >/dev/null 2>&1 ; then
    ln -sfn "$VENDOR_VERSION" current
    # remove old vendor installations by sorting files with modified time.
    ls -t | grep -Ev "^(current|$VENDOR_VERSION)" | tail -n +4 | xargs rm -rf
    [ -d "$VENDOR_VERSION.reinstall" ] && rm -rf "$VENDOR_VERSION.reinstall"
  else
    rm -rf "$VENDOR_VERSION"
    [ -d "$VENDOR_VERSION.reinstall" ] && mv "$VENDOR_VERSION.reinstall" "$VENDOR_VERSION"
    odie "Failed to $verb vendor $VENDOR_NAME."
  fi

  trap - SIGINT
}

homebrew-vendor-install() {
  local option
  local url_var
  local sha_var

  for option in "$@"; do
    case "$option" in
      -\?|-h|--help|--usage) brew help vendor-install; exit $?;;
      --verbose) HOMEBREW_VERBOSE=1;;
      --quiet) HOMEBREW_QUIET=1;;
      --debug) HOMEBREW_DEBUG=1;;
      --*) ;;
      -*) case "$option" in (-*v*) HOMEBREW_VERBOSE=1;; esac
          case "$option" in (-*q*) HOMEBREW_QUIET=1  ;; esac
          case "$option" in (-*d*) HOMEBREW_DEBUG=1  ;; esac;;
      *) [ -n "$VENDOR_NAME" ] && odie 'This command does not take multiple vendor targets.'
         VENDOR_NAME="$option";;
    esac
  done

  [ -z "$VENDOR_NAME" ] && odie 'This command requires one vendor target.'
  [ -n "$HOMEBREW_DEBUG" ] && set -x

  url_var="${VENDOR_NAME}_URL"
  sha_var="${VENDOR_NAME}_SHA"
  if [ "$url_var" != 'ruby_URL' ]; then
    [ "$url_var" != 'curl_URL' ] && odie 'This command can only install “curl” or “ruby”.'
    VENDOR_URL="$curl_URL"
  else
    VENDOR_URL="$ruby_URL"
  fi
  if [ "$sha_var" != 'ruby_SHA' ]; then
    [ "$sha_var" != 'curl_SHA' ] && odie 'This command can only install “curl” or “ruby”.'
    VENDOR_SHA="$curl_SHA"
  else
    VENDOR_SHA="$ruby_SHA"
  fi

  if [ -z "$VENDOR_URL" ] || [ -z "$VENDOR_SHA" ] ; then
    odie <<-EOS
Cannot find a vendored version of $VENDOR_NAME for your $HOMEBREW_PROCESSOR
processor on Leopardbrew!
EOS
  fi

  VENDOR_VERSION="$(<"$VENDOR_DIR/portable-${VENDOR_NAME}-version")"
  CACHED_LOCATION="$HOMEBREW_CACHE/$(basename "$VENDOR_URL")"

  lock "vendor-install-$VENDOR_NAME"
  _fetch
  _install
}
