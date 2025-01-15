setup-ruby-path() {
  local vendor_dir
  local vendor_ruby_current_version
  local vendor_ruby_path

  vendor_dir="$HOMEBREW_RUBY_LIBRARY/vendor"
  vendor_ruby_current_version="$vendor_dir/portable-ruby/current"
  vendor_ruby_path="$vendor_ruby_current_version/bin/ruby"

  [ -z "$HOMEBREW_DEVELOPER" ] && unset HOMEBREW_RUBY_PATH

  if [ -z "$HOMEBREW_RUBY_PATH" ] && [ "$HOMEBREW_COMMAND" != "vendor-install" ]; then
    if [ -x "$vendor_ruby_path" ]; then
      HOMEBREW_RUBY_PATH="$vendor_ruby_path"
      if [ "$(readlink "$vendor_ruby_current_version")" != "$(<"$vendor_dir/portable-ruby-version")" ]; then
        brew vendor-install ruby || onoe "Failed to upgrade vendor Ruby."
      fi
    else
      HOMEBREW_RUBY_PATH="/usr/bin/ruby"
      brew vendor-install ruby
      [ -x "$vendor_ruby_path" ] || odie "Failed to install vendor Ruby."
      HOMEBREW_RUBY_PATH="$vendor_ruby_path"
    fi
  fi

  export HOMEBREW_RUBY_PATH  # will be null if not a developer and command is vendor-install
}
