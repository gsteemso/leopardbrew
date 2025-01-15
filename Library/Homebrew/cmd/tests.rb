require 'extend/ENV'
ENV.activate_extensions!

module Homebrew
  def tests
    def bundler_version
      `#{CONFIG_RUBY_PATH} --version`.match %r{ruby (\d+\.\d+\.\d+)}
      if $1 < '1.8.7' then ['1.0.22', 'bundle']
      elsif $1 < '2.3.0' then ['1.17.3', 'bundle']
      elsif $1 < '2.6.0' then ['2.3.27']
      elsif $1 < '3.0.0' then ['2.4.22']
    # elsif $1 < '4.0.0' then ['2.5.x']  -- don’t specify it at all, to get current version
      else ['']
      end
    end
    ENV.prepend_path 'PATH', CONFIG_RUBY_BIN
    ENV.prepend_path 'PATH', "#{Gem.user_dir}/bin"
    HOMEBREW_LIBRARY_TEST.cd do
      ENV["TESTOPTS"] = "-v" if VERBOSE
      ENV["HOMEBREW_TESTS_COVERAGE"] = "1" if ARGV.include? "--coverage"
      ENV["HOMEBREW_NO_COMPAT"] = "1" if ARGV.include? "--no-compat"
      puts 'This may take a few minutes.'
      Homebrew.install_gem_setup_path! "bundler", *bundler_version
      quiet_system(CONFIG_RUBY_BIN/'bundle', "check") or \
        system(CONFIG_RUBY_BIN/'bundle', 'config', 'set', '--local', 'path', "vendor/bundle")
      system CONFIG_RUBY_BIN/'bundle', "exec", "rake", "test"
      Homebrew.failed = !$?.success?
      if (fs_leak_log = HOMEBREW_LIBRARY_TEST/'fs_leak_log').file?
        fs_leak_log_content = fs_leak_log.read
        unless fs_leak_log_content.empty?
          opoo "File leak is detected"
          puts fs_leak_log_content
          Homebrew.failed = true
        end
      end
    end
  end
end
