module Homebrew
  module Assertions
    if defined?(Gem)
      begin
        gem "minitest", "< 5.0.0"
      rescue Gem::LoadError
      else
        require "minitest/unit"
      end
    end
    require "test/unit/assertions"

    if defined?(MiniTest::Assertion)
      FailedAssertion = MiniTest::Assertion
    else
      FailedAssertion = Test::Unit::AssertionFailedError
    end

    include Test::Unit::Assertions

    # Returns the output of running cmd, and asserts the exit status
    def shell_output(cmd, result = 0)
      ohai cmd
      output = `#{cmd}`
      puts output if VERBOSE
      assert_equal result, $?.exitstatus
      output
    end

    # Returns the outputs of running each arch of cmd, and asserts the exit statuses
    def arch_outputs(cmd, argstr, result = 0)
      outputs = []
      cmd = which(cmd) unless cmd.to_s =~ %r{/}
      cmd = Pathname.new(cmd) unless cmd.class == Pathname
      if cmd.universal?
        if (arch_cmd = which 'arch')
          cmd.archs.select { |a| Hardware::CPU.can_run?(a) }.each do |a|
            cmdstr = "#{arch_cmd} -arch #{a.to_s} #{cmd} #{argstr}"
            ohai cmdstr
            outputs << `#{cmdstr}` 
            puts outputs[-1] if VERBOSE
            assert_equal result, $?.exitstatus
          end
        else
          opoo "Can’t find the “arch” command.  Running #{cmd} with the default architecture only:"
          outputs << shell_output("#{cmd} #{argstr}", result)
        end
      else
        outputs << shell_output("#{cmd} #{argstr}", result)
      end
      outputs
    end

    # Returns the output of running the cmd with the optional input, and
    # optionally asserts the exit status
    def pipe_output(cmd, input = nil, result = nil)
      ohai cmd
      output = IO.popen(cmd, "w+") do |pipe|
        pipe.write(input) unless input.nil?
        pipe.close_write
        pipe.read
      end
      puts output if VERBOSE
      assert_equal result, $?.exitstatus unless result.nil?
      output
    end
  end
end
