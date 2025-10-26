require 'language/python'

class Python2Requirement < Requirement
  fatal true
  default_formula 'python2'

  satisfy :build_env => false do
    # Always use Python 2.7 for consistency on older versions of OSX.
    which_python and (v = python_short_version) and (v.to_s == '2.7')
  end

  env do
    if (psv = python_short_version)
      unless which_python and (py_dir = which_python.dirname) and (py_dir == '/usr/bin')  # system Python
        # Homebrew Python should take precedence over older Pythons in $PATH.
        py_f = Formula["python#{psv.to_s[0]}"]
        ENV.prepend_path 'PATH', (py_dir == py_f.bin ? py_f.opt_bin : py_dir)
      end
      ENV['PYTHONPATH'] = "#{HOMEBREW_PREFIX}/lib/python#{psv}/site-packages"
    end
  end # env

  def python_short_version; Language::Python.major_minor_version which_python; end

  def which_python
    if (py = which py_exec) then Pathname.new Utils.popen_read(py, '-c', 'import sys; print(sys.executable)').strip; end
  end

  def py_exec; 'python2'; end

  # Deprecated
  alias_method :to_s, :py_exec
end # PythonRequirement

class Python3Requirement < Python2Requirement
  fatal true
  default_formula 'python3'

  satisfy(:build_env => false) { psv = python_short_version and psv.to_s.starts_with?('3') }

  def py_exec; 'python3'; end
end # Python3Requirement
