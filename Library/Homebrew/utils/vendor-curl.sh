setup-curl-path() {
  local vendor_dir
  local vendor_curl_current_version
  local vendor_curl_path

  vendor_dir="$HOMEBREW_RUBY_LIBRARY/vendor"
  vendor_curl_current_version="$vendor_dir/portable-curl/current"
  vendor_curl_path="$vendor_curl_current_version/bin/curl"

  if [ "$HOMEBREW_COMMAND" != 'vendor-install' ]; then
    if [ -x "$vendor_curl_path" ]; then
      HOMEBREW_CURL_PATH="$vendor_curl_path"
      [ $(readlink "$vendor_curl_current_version") != "$(<"$vendor_dir/portable-curl-version")" ] \
        && brew vendor-install curl || onoe "Failed to upgrade vendor Curl."
    else
      HOMEBREW_CURL_PATH="/usr/bin/curl"
      if [ "$HOMEBREW_OS_VERSION_DIGITS" -lt "101500" -o ! -x "$HOMEBREW_CURL_PATH" ]; then
        brew vendor-install curl
        [ -x "$vendor_curl_path" ] || odie 'Failed to install vendor Curl.'
        HOMEBREW_CURL_PATH="$vendor_curl_path"
      fi
    fi
  fi
  export HOMEBREW_CURL_PATH
}
