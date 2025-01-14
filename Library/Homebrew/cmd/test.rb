require 'extend/ENV'
require 'cmd/switch'
require 'formula/assertions'
require 'sandbox'
require 'timeout'

module Homebrew
  def test
    raise FormulaUnspecifiedError if ARGV.named.empty?

    ARGV.resolved_formulae.each do |f|
      # Cannot test formulae without a test method
      unless f.test_defined?
        ofail "#{f.full_name} defines no test"
        next
      end

      named_spec = ((ARGV.build_head? or f.head_only?) ? :head : ((ARGV.build_devel? or f.devel_only?) ? :devel : :stable))
      named_version = f.send(named_spec).version.to_s

      # Cannot test uninstalled formulae
      unless f.installed?(named_spec)
        ofail "The specified test requires version #{named_version} of #{f.full_name} to be installed"
        next
      end

      if f.rack.subdirs.length > 1 and f.spec_prefix(named_spec) != f.opt_prefix.resolved_path
        if f.keg_only?
          Keg.new(f.spec_prefix(named_spec)).optlink
        else
          stashed_argv = ARGV
          ARGV.clear
          ARGV.unshift(f.full_name, named_version)
          switch
          ARGV.clear
          ARGV.unshift *stashed_argv
        end
      end

      if f.head_only? and not ARGV.build_head?
        ARGV.unshift('--HEAD')
      elsif f.devel_only? and not ARGV.build_devel?
        ARGV.unshift('--devel')
      end

      oh1 "Testing #{f.full_name} version #{named_version}"

      env = ENV.to_hash

      begin
        args = %W[
          #{CONFIG_RUBY_PATH}
          -W0
          -I #{HOMEBREW_LOAD_PATH}
          --
          #{HOMEBREW_LIBRARY_PATH}/test.rb
          #{f.path}
        ].concat(ARGV.options_only)

        if Sandbox.available? && ARGV.sandbox?
          if Sandbox.auto_disable?
            Sandbox.print_autodisable_warning
          else
            Sandbox.print_sandbox_message
          end
        end # Sandbox?

        Utils.safe_fork do
          if Sandbox.available? && ARGV.sandbox? && !Sandbox.auto_disable?
            sandbox = Sandbox.new
            f.logs.mkpath
            sandbox.record_log(f.logs/'sandbox.test.log')
            sandbox.allow_write_temp_and_cache
            sandbox.allow_write_log(f)
            sandbox.allow_write_xcode
            sandbox.exec(*args)
          else
            exec(*args)
          end
        end # Utils.safe_fork
      rescue Assertions::FailedAssertion => e
        ofail "#{f.full_name}: failed"
        puts e.message
      rescue Exception => e
        ofail "#{f.full_name}: failed"
        puts e, e.backtrace
      ensure
        ENV.replace(env)
      end
    end # do each resolved formula |f|
  end # test
end # Homebrew
