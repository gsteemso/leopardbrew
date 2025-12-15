old_trap = trap('INT') { exit! 130 }

require 'global'
require 'extend/ENV'
require 'timeout'
require 'debrew'
require 'formula/assertions'
require 'fcntl'
require 'socket'

TEST_TIMEOUT_SECONDS = 5*60

begin
  error_pipe = UNIXSocket.open(ENV['HOMEBREW_ERROR_PIPE'], &:recv_io)
  error_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

  trap('INT', old_trap)

  normal_path = ENV['PATH']

  # Set up all the stuff for 64‐bit, universal and cross builds.  Also change
  # to our $PATH that ensures all our tools are where they ought to be.
  f = ARGV.formulae.first
  f.set_active_spec(ARGV.build_head? ? :head : (ARGV.build_devel? ? :devel : :stable))
  t = Tab.from_file(f.prefix/Tab::FILENAME)
  f.build = BuildOptions.new(t.used_options + Options.create(ARGV.effective_formula_flags), f.options)
  f.extend(Homebrew::Assertions)
  ENV.activate_extensions!
  ENV.set_active_formula(f)
  ENV.setup_build_environment(t.built_archs)

  path_parts = ENV['PATH'].split(':') + normal_path.split(':')
  ENV['PATH'] = path_parts.uniq.join(':')

  # Enable argument refurbishment under Superenv.  This enforces architecture
  # and optimization flags; otherwise, 64‐bit, universal, & cross builds fail.
  ENV.refurbish_args if superenv?

  if DEBUG  # can’t use a timeout and run a debugging shell at the same time
    f.extend(Debrew::Formula)
    raise 'test returned false' if f.run_test == false
  else
    # tests can either buggily time out, or explicitly return false to indicate failure
    Timeout.timeout TEST_TIMEOUT_SECONDS do
      raise 'test returned false' if f.run_test == false
    end # timeout?
  end # debug?
  oh1 'Test passed'
rescue Exception => e
  Marshal.dump(e, error_pipe)
  error_pipe.close
  exit! 1
end
