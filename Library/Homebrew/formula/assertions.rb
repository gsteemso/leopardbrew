module Homebrew
  module Assertions
    if defined?(Gem)
      begin
        gem 'minitest', '< 5.0.0'
      rescue Gem::LoadError  # do nothing
      else require 'minitest/unit'
      end
    end # Gem defined?
    require 'test/unit/assertions'

    if defined?(MiniTest::Assertion)
      FailedAssertion = MiniTest::Assertion
    else
      FailedAssertion = Test::Unit::AssertionFailedError
    end

    include Test::Unit::Assertions

    def with_assertion(&block)
      raise ArgumentError, 'with_assertion() requires a block containing at least one assertion' unless block_given?
      if defined? Debrew
        Debrew.inhibit { yield }
      else
        yield
      end
      return true
    rescue FailedAssertion
      return false
    rescue Exception => e
      $stderr.puts "Unexpected exception caught in Homebrew::Assertions#with_assertion():  #{e.class}"
      return false
    end # Homebrew::Assertions#with_assertion()

    # Returns the output of running cmd, and asserts the exit status
    def shell_output(cmd, result = 0)
      ohai cmd
      output = `#{cmd}`
      puts output if VERBOSE
      assert_equal result, $?.exitstatus
      output
    end # Homebrew::Assertions#shell_output()

    # Returns the output of running the cmd with the optional input, and
    # optionally asserts the exit status
    def pipe_output(cmd, input = nil, result = nil)
      ohai cmd
      output = IO.popen(cmd, 'w+') do |pipe|
        unless input.nil?
          puts input if VERBOSE
          pipe.write(input)
        end
        pipe.close_write
        pipe.read
      end
      puts output if VERBOSE
      assert_equal result, $?.exitstatus unless result.nil?
      output
    end # Homebrew::Assertions#pipe_output()
  end # Assertions
end # Homebrew
