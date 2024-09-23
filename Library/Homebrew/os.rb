module OS
  def self.mac?
    /darwin/i === RUBY_PLATFORM  # TODO:  need to disambiguate Mac OS from bare Darwin
  end

  def self.linux?
    /linux/i === RUBY_PLATFORM
  end

  if OS.mac?
    ISSUES_URL           = 'https://github.com/gsteemso/leopardbrew'
    ::MACOS_FULL_VERSION = ENV['HOMEBREW_OSX_VERSION'].chomp
    ::MACOS_VERSION      = ::MACOS_FULL_VERSION[/\d\d\.\d+/]
      ::MACOS_VERSION    =   ::MACOS_VERSION.slice(0, 2) if ::MACOS_VERSION.to_f >= 11
    PATH_OPEN = '/usr/bin/open'
    require 'os/mac'
  elsif OS.linux?
    ISSUES_URL = 'https://github.com/Homebrew/linuxbrew/wiki/troubleshooting'
    ::MACOS_FULL_VERSION = ::MACOS_VERSION = '0'
    PATH_OPEN = 'xdg-open'
  else
    raise 'Unknown operating system'
  end
end
