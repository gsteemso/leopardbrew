module FormulaCellarChecks
# This module is `include`d by cmd/audit’s FormulaAuditor and by FormulaInstaller.
# It depends on its hosts having a Formula instance called “formula”.
  def check_PATH(bin)
    # Warn the user if stuff was installed outside of their PATH.
    return unless bin.directory?
    return unless bin.children.length > 0

    prefix_bin = (HOMEBREW_PREFIX/bin.basename)
    return unless prefix_bin.directory?

    prefix_bin = prefix_bin.realpath
    return if ORIGINAL_PATHS.include? prefix_bin

    <<-EOS.undent
      #{prefix_bin} is not in your PATH
      You can amend this by altering your #{shell_profile} file.
    EOS
  end # check_PATH

  def check_manpages
    # Check for man pages that aren’t in share/man.
    return unless (formula.prefix/'man').directory?

    <<-EOS.undent
      A top-level “man” directory was found
      Leopardbrew requires that man pages live under “share”.  This can often be
      fixed by passing “--mandir=\#{man}” to configure.
    EOS
  end # check_manpages

  def check_infopages
    # Check for info pages that aren’t in share/info.
    return unless (formula.prefix/'info').directory?

    <<-EOS.undent
      A top-level “info” directory was found
      Leopardbrew suggests that info pages live under “share”.  This can often be
      fixed by passing “--infodir=\#{info}” to configure.
    EOS
  end # check_infopages

  def check_jars
    return unless formula.lib.directory?
    jars = formula.lib.children.select { |g| g.extname == ".jar" }
    return if jars.empty?

    <<-EOS.undent
      JARs were installed to “#{formula.lib}”
      Installing JARs to “lib” can cause conflicts between packages.  For Java
      software, it is typically better for the formula to install to “libexec” and
      then symlink or wrap binaries into “bin”.  See {activemq}, {jruby}, etc. for
      examples.  The offending files are:
        #{jars * "\n  "}
    EOS
  end # check_jars

  def check_non_libraries
    return unless formula.lib.directory?

    valid_extensions = %w[.a .dylib .framework .jnilib .la .o .so .jar .prl .pl .pm .sh]
    non_libs = formula.lib.children.reject{ |g| g.directory? or valid_extensions.include? g.extname }
    return if non_libs.empty?

    <<-EOS.undent
      Non-libraries were installed to “#{formula.lib}”
      Installing non-libraries to “lib” is discouraged.  The offending files are:
        #{non_libraries * "\n  "}
    EOS
  end # check_non_libraries

  def check_non_executables(bin)
    return unless bin.directory?

    non_exes = bin.children.reject{ |g| g.executable? }
    return if non_exes.empty?

    <<-EOS.undent
      Non-executables were installed to “#{bin}”
      The offending files are:
        #{non_exes * "\n  "}
    EOS
  end # check_non_executables

  def check_generic_executables(bin)
    return unless bin.directory?
    generic_names = %w[run service start stop]
    generics = bin.children.select { |g| generic_names.include? g.basename.to_s }
    return if generics.empty?

    <<-EOS.undent
      Generic binaries were installed to “#{bin}”
      Binaries with generic names are likely to conflict with other software,
      suggesting that this software should be installed to “libexec” and then
      symlinked as needed.

      The offending files are:
        #{generics * "\n  "}
    EOS
  end # check_generic_executables

  def check_shadowed_headers
    ["libtool", "subversion", "berkeley-db"].each do |formula_name|
      return if formula.name.starts_with?(formula_name)
    end

    return if MacOS.version < :mavericks && formula.name.starts_with?("postgresql")
    return if MacOS.version < :yosemite  && formula.name.starts_with?("memcached")

    return if formula.keg_only? or not formula.include.directory?

    files  = relative_glob(formula.include, "**/*.h")
    files &= relative_glob("#{MacOS.sdk_path}/usr/include", "**/*.h")
    files.map! { |p| File.join(formula.include, p) }

    return if files.empty?

    <<-EOS.undent
      Header files that shadow system header files were installed to “#{formula.include}”
      The offending files are:
        #{files * "\n  "}
    EOS
  end # check_shadowed_headers

  def check_easy_install_pth(lib)
    pth_found = Dir["#{lib}/python{2.7,3}*/site-packages/easy-install.pth"].map { |f| File.dirname(f) }
    return if pth_found.empty?

    <<-EOS.undent
      “easy-install.pth” files were found
      These .pth files are likely to cause link conflicts.  Please invoke setup.py
      using Language::Python.setup_install_args.  The offending files are:
        #{pth_found * "\n  "}
    EOS
  end # check_easy_install_pth

  def check_openssl_links
    return unless formula.prefix.directory?
    keg = Keg.new(formula.prefix)
    system_openssl = keg.mach_o_files.select do |obj|
      dlls = obj.dynamically_linked_libraries
      dlls.any? { |dll| /\/usr\/lib\/lib(crypto|ssl).(\d\.)*dylib/.match dll }
    end
    return if system_openssl.empty?

    <<-EOS.undent
      Object files were linked against system OpenSSL
      Some object files were linked against the outdated stock OpenSSL.  Adding
      “depends_on 'openssl3'” to the formula may help.  The offending files are:
        #{system_openssl * "\n  "}
    EOS
  end # check_openssl_links

  def check_python_framework_links(lib)
    python_modules = Pathname.glob lib/"python*/site-packages/**/*.{dylib,so}"
    framework_links = python_modules.select do |obj|
      dlls = obj.dynamically_linked_libraries
      dlls.any? { |dll| /Python\.framework/.match dll }
    end
    return if framework_links.empty?

    <<-EOS.undent
      Python modules have explicit framework links
      Some Python extension modules were linked directly to a Python framework
      binary.  They should be linked with “-undefined dynamic_lookup” instead of
      “-lpython” or “-framework Python”.  The offending files are:
        #{framework_links * "\n  "}
    EOS
  end # check_python_framework_links

  def check_emacs_lisp(share, name)
    return unless (share/"emacs/site-lisp").directory?

    # Emacs itself can do what it wants
    return if name == "emacs"

    elisps = (share/"emacs/site-lisp").children.select { |file| %w[.el .elc].include? file.extname }
    return if elisps.empty?

    <<-EOS.undent
      Emacs Lisp files were linked directly to #{HOMEBREW_PREFIX}/share/emacs/site-lisp

      This may cause conflicts with other packages; install to a subdirectory instead, such as

          #{share}/emacs/site-lisp/#{name}

      The offending files are:
        #{elisps * "\n  "}
    EOS
  end # check_emacs_lisp

  def audit_installed
    audit_check_output(check_manpages)
    audit_check_output(check_infopages)
    audit_check_output(check_jars)
    audit_check_output(check_non_libraries)
    audit_check_output(check_non_executables(formula.bin))
    audit_check_output(check_generic_executables(formula.bin))
    audit_check_output(check_non_executables(formula.sbin))
    audit_check_output(check_generic_executables(formula.sbin))
    audit_check_output(check_shadowed_headers)
    audit_check_output(check_easy_install_pth(formula.lib))
    audit_check_output(check_openssl_links)
    audit_check_output(check_python_framework_links(formula.lib))
    audit_check_output(check_emacs_lisp(formula.share, formula.name))
  end # audit_installed

  private

  def relative_glob(dir, pattern)
    File.directory?(dir) ? Dir.chdir(dir) { Dir[pattern] } : []
  end
end # FormulaCellarChecks
