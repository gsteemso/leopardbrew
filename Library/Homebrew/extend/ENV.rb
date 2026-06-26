require 'target'             # Pulls in 'macos', and thence 'cpu'.
Target.no_universal_binary   # We don’t want to be acting like there’s a “universal” option unless the formula does so first.
require 'extend/ENV/shared'  # Pulls in 'formula', and thence almost two dozen other modules.
require 'extend/ENV/std'
require 'extend/ENV/super'

def superenv?
  Superenv.bin && ARGV.env != 'std'
end

module EnvActivation
  def activate_extensions!
    if superenv?
      extend(Superenv)
    else
      extend(Stdenv)
    end
    initialize_build_mode unless ENV['HOMEBREW_BUILD_MODE'].choke
  end

  def with_build_environment
    old_env = to_hash.dup
    tmp_env = to_hash.dup.extend(EnvActivation)
    tmp_env.activate_extensions!
    tmp_env.setup_build_environment
    replace(tmp_env)
    yield
  ensure
    replace(old_env)
  end
end

ENV.extend(EnvActivation)
