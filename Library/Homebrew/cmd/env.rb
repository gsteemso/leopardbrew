module Homebrew
  def env
    ENV.deps = ARGV.formulae if superenv?
    ENV.setup_build_environment
    ENV.universal_binary if ARGV.build_universal?
    if $stdout.tty? then dump_build_env; else build_env_keys.each{ |key| puts "export #{key}=\"#{ENV[key]}\"" }; end
  end # Homebrew.env

  def build_env_keys(env_ = ENV)
    %w[ CC CXX LD OBJC OBJCXX
        CFLAGS CXXFLAGS CPPFLAGS LDFLAGS SDKROOT MAKEFLAGS
        CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH CMAKE_FRAMEWORK_PATH CMAKE_OSX_ARCHITECTURES
        MACOSX_DEPLOYMENT_TARGET PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
        MAKE GIT CPP
        ACLOCAL_PATH PATH CPATH
    ].select{ |key| env_.key?(key) }.sort + env_.keys.select{ |key| key.starts_with?('HOMEBREW') }.sort
  end # Homebrew.build_env_keys

  def dump_build_env(env_ = ENV, f = $stdout)
    keys = build_env_keys(env_)
    keys -= %w[CC CXX OBJC OBJCXX] if env_["CC"] == env_["HOMEBREW_CC"]
    keys.each do |key|
      value = env_[key] || '[unset]'
      s = "#{key}: #{value}"
      if env_[key] and (value = value.split(' ', 2)[0]) and (value = which(value, ENV['PATH'], :restrict)) and value.symlink?
        s << " => #{value.realpath}"
      end
      f.puts s
    end
  end # Homebrew.dump_build_env
end # module Homebrew
