require 'language/python'

class PythonRequirement < Requirement
  fatal true
  default_formula 'python'
  cask 'python'

  satisfy :build_env => false do
    python = which_python
    next unless python
    version = python_short_version
    next unless version
    # Always use Python 2.7 for consistency on older versions of OSX.
    version == Version.new('2.7')
  end

  env do
    short_version = python_short_version

    if short_version == Version.new('2.7')
      ENV.prepend_path 'PATH', which_python.dirname unless system_python?
    # Homebrew Python should take precedence over older Pythons in the PATH
    else ENV.prepend_path 'PATH', Formula['python'].opt_bin; end

    ENV['PYTHONPATH'] = "#{HOMEBREW_PREFIX}/lib/python#{short_version}/site-packages"
  end # env

  def python_short_version
    @short_version ||= Language::Python.major_minor_version which_python
  end

  def which_python
    @which_python ||= if (python = which python_binary)
        Pathname.new Utils.popen_read(python, '-c', 'import sys; print(sys.executable)').strip
      end
  end

  def system_python; "/usr/bin/#{python_binary}"; end

  def system_python?; system_python == which_python.to_s; end

  def python_binary; 'python'; end

  # Deprecated
  alias_method :to_s, :python_binary
end # PythonRequirement

class Python3Requirement < PythonRequirement
  fatal true
  default_formula 'python3'
  cask 'python3'

  satisfy(:build_env => false) { which_python3 }

  def which_python3
    @which_python3 ||= if (python = which python_binary)
        Pathname.new Utils.popen_read(python, '-c', 'import sys; print(sys.executable)').strip
      end
  end

  def python_binary; 'python3'; end
end # Python3Requirement
