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
    end # shell_output

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
    end # pipe_output
  end # Assertions
end # Homebrew
