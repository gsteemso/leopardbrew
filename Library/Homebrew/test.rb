old_trap = trap('INT') { exit! 130 }

require 'fcntl'
require 'socket'
require 'timeout'

require 'global'
require 'debrew'
require 'formula/assertions'

TEST_TIMEOUT_SECONDS = 5*60

begin
  error_pipe = UNIXSocket.open(ENV['HOMEBREW_ERROR_PIPE'], &:recv_io)
  error_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

  trap('INT', old_trap)

  normal_path = ENV['PATH']

  # Set up all the machinery for universal builds.  Also change to our $PATH that ensures all our tools are where they ought to be.
  f = ARGV.formulae.first
  f.set_active_spec(ARGV.build_spec)
  t = Tab.from_file(f.prefix/Tab::FILENAME)
  Target.allow_universal_binary if t.built_archs.length > 1 or ARGV.valid_universal_mode?(t.build_mode)
  f.build = BuildOptions.new(t.used_options + Options.create(ARGV.effective_formula_flags), f.options)
  f.extend(Homebrew::Assertions)
  ENV.set_active_formula(f)
  ENV.setup_build_environment(t.built_archs)

  path_parts = ENV['PATH'].split(':') + normal_path.split(':')
  ENV['PATH'] = path_parts.uniq.join(':')

  # Enable argument refurbishment under Superenv.  This enforces architecture
  # and optimization flags; otherwise, 64‐bit, universal, & cross builds fail.
  ENV.refurbish_args if superenv?

  f.extend(Debrew::Formula) if DEBUG

  # Tests can return :does_not_apply; or any true value on success; or buggily time out / explicitly return false on failure.  (Use
  # of a timeout precludes use of a debugging shell.)
  case (DEBUG ? f.run_test : Timeout.timeout(TEST_TIMEOUT_SECONDS) { f.run_test })
    when false           then opoo 'Test failed'
    when nil             then onoe 'The test returned `nil` instead of `true` or `false`.  This is a bug.'
    when :does_not_apply then ohai 'This formula cannot meaningfully be tested.'
                         else ohai 'Test passed'
  end
rescue Exception => e
  Marshal.dump(e, error_pipe)
  error_pipe.close
  exit! 1
end
