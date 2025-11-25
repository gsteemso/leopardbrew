# stable release 2020-04-20; discontinued
class Python2 < Formula
  desc 'Interpreted, interactive, object-oriented language (historical vers.)'
  homepage 'https://www.python.org'
  url 'https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz'
  sha256 'b62c0e7937551d0cc02b8fd5cb0f544f9405bafc9a54d3808ed4594812edef43'
  # As Python 2 reached EOL in 2020, the :HEAD version is no longer available.
  revision 2

  # Please don't add a wide/ucs4 option, as it won't be accepted.  See:  https://github.com/Homebrew/homebrew/pull/32368

  option :universal
  if Formula['python3'].installed?
    option 'with-html-docs', 'also build documentation in HTML format'
    deprecated_option 'with-sphinx-doc' => 'with-html-docs'
  end

  depends_on 'pkg-config' => :build
  if build.with?('html-docs')
    depends_on :python3   => :build
    depends_on LanguageModuleRequirement.new(:python3, 'sphinx') => :build
  end
  depends_on 'openssl3'
  depends_on 'tcl-tk'
  depends_on 'gdbm' => :recommended
  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'berkeley-db4' => :optional

  enhanced_by :nls    # Useful if available, but not worth actually depending on.
  enhanced_by 'zlib'  # Sometimes it will pick this up even when not made explicit, but we don’t _need_ it.

  skip_clean 'bin/pip', 'bin/pip-2.7'
  skip_clean 'bin/easy_install', 'bin/easy_install-2.7'

  patch :DATA  # What the patches do are noted in the comments.

  # On Snow Leopard or greater, don’t link to LibX11, because our Tk uses Aqua.
  patch <<END_OF_PATCH if MacOS.version >= :snow_leopard
--- old/setup.py
+++ new/setup.py
@@ -1973,21 +1973,6 @@ class PyBuildExt(build_ext):
             if dir not in include_dirs:
                 include_dirs.append(dir)

-        # Check for various platform-specific directories
-        if host_platform == 'sunos5':
-            include_dirs.append('/usr/openwin/include')
-            added_lib_dirs.append('/usr/openwin/lib')
-        elif os.path.exists('/usr/X11R6/include'):
-            include_dirs.append('/usr/X11R6/include')
-            added_lib_dirs.append('/usr/X11R6/lib64')
-            added_lib_dirs.append('/usr/X11R6/lib')
-        elif os.path.exists('/usr/X11R5/include'):
-            include_dirs.append('/usr/X11R5/include')
-            added_lib_dirs.append('/usr/X11R5/lib')
-        else:
-            # Assume default location for X11
-            include_dirs.append('/usr/X11/include')
-            added_lib_dirs.append('/usr/X11/lib')

         # If Cygwin, then verify that X is installed before proceeding
         if host_platform == 'cygwin':
@@ -2012,9 +1997,6 @@ class PyBuildExt(build_ext):
         if host_platform in ['aix3', 'aix4']:
             libs.append('ld')

-        # Finally, link with the X11 libraries (not appropriate on cygwin)
-        if host_platform != "cygwin":
-            libs.append('X11')

         ext = Extension('_tkinter', ['_tkinter.c', 'tkappinit.c'],
                         define_macros=[('WITH_APPINIT', 1)] + defs,
END_OF_PATCH

  # setuptools remembers the build flags, and uses them later to build packages.  Xcode-only systems need different flags.
  def pour_bottle
    reason <<-EOS.undent
      The bottle needs the Apple Command Line Tools to be installed.
      You can install them, if desired, with:
          xcode-select --install
    EOS
    satisfy { MacOS::CLT.installed? }
  end # pour_bottle

  def install
    ENV.universal_binary if build.universal?
    ENV.without_archflags  # The makefile takes care of them for us.

    ENV['PYTHONHOME'] = nil  # Unset these so that installing pip and setuptools puts them where we
    ENV['PYTHONPATH'] = nil  # want and not into some other Python the user has installed.

    # There’s no simple way to extract a “ppc” slice from a universal file.  We must specify the exact sub‐architecture we actually
    # put in there in the first place.  Of course, if it already was :g4, we don’t need to do anything.
    if Target.powerpc? and (m_for_ppc = Target.model_for_arch(:ppc)) != :g4
      our_ppc_flavour = Target.model_optflags(m_for_ppc)[/^-mcpu=(\d+)/, 1]
      inreplace 'configure' do |s| s.gsub! '-extract ppc7400', "-extract ppc#{our_ppc_flavour}" end
    end

    # Outsmart the detection code; superenv makes cc always find includes/libs.
    inreplace 'setup.py' do |s|
      s.gsub! '/usr/local/ssl', Formula['openssl3'].opt_prefix
      s.gsub! '/usr/include/db4', Formula['berkeley-db4'].opt_include if build.with? 'berkeley-db4'
      if build.with? 'gdbm'
        f = Formula['gdbm']
        s.gsub! 'if find_file("ndbm.h", inc_dirs,',
                "if find_file('ndbm.h', ['#{f.opt_include}'],"
        s.gsub! %r{if self\.compiler\.find_library_file\(lib_dirs,[ \t\n]+'gdbm_compat'},
                  "if self.compiler.find_library_file(['#{f.opt_lib}'], 'gdbm_compat'"
        s.gsub! "self.compiler.find_library_file(lib_dirs, 'gdbm')",
                "self.compiler.find_library_file(['#{f.opt_lib}'], 'gdbm')"
      end
      if build.with? 'readline'
        f = Formula['readline']
        s.gsub! 'do_readline = self.compiler.find_library_file(lib_dirs,',
                "do_readline = self.compiler.find_library_file(['#{f.opt_lib}'],"
        s.gsub! "find_file('readline/rlconf.h', inc_dirs,",
                "find_file('readline/rlconf.h', ['#{f.opt_include}'],"
      end
      if build.with? 'sqlite'
        s.gsub! 'sqlite_setup_debug = False', 'sqlite_setup_debug = True'
        s.gsub! 'for d_ in inc_dirs + sqlite_inc_paths:',
                "for d_ in ['#{Formula['sqlite'].opt_include}']:"
        # Allow sqlite3 module to load extensions:
        # https://docs.python.org/library/sqlite3.html#f1
        s.gsub! 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', ''
      end
    end

    # Allow python modules to use ctypes.find_library to find Leopardbrew’s stuff even if the brewed package isn’t a /usr/local/lib.
    # Try this with:  `brew install enchant && pip install pyenchant`
    inreplace './Lib/ctypes/macholib/dyld.py' do |s|
      s.gsub! 'DEFAULT_LIBRARY_FALLBACK = [', "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      s.gsub! 'DEFAULT_FRAMEWORK_FALLBACK = [', "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    # :arm builds are not supported; just build for Intel and hope it keeps working
    args = %W[
      --prefix=#{prefix}
      --datarootdir=#{share}
      --datadir=#{share}
      --without-ensurepip
      --enable-framework=#{frameworks}
      --enable-ipv6
      MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}
      --with-universal-archs=#{Target.type}#{build.universal? ? '' : "-#{Target.bits(Target.arch)}"}
      --enable-universalsdk=/
    ]
    # Infuriatingly, Coreutils ginstall now treats a destination file which already exists as a bad directory name, instead of just
    # overwriting the file – even when passed “-f”.  This causes a failure during installation of `pythonw`.
    args << 'INSTALL=/usr/bin/install' if Formula['coreutils'].any_version_installed?
    # Avoid linking to libgcc (see https://code.activestate.com/lists/python-dev/112195/).  Enable LLVM optimizations.
    args << '--without-gcc' << '--enable-optimizations' if ENV.compiler == :clang

    cflags   = []
    ldflags  = []
    cppflags = []

    unless MacOS::CLT.installed?
      # Help Python's build system (setuptools/pip) to build things on Xcode-only systems
      # The setup.py looks at “-isysroot” to get the sysroot (and not at --sysroot)
      cflags   << "-isysroot #{MacOS.sdk_path}"
      ldflags  << "-isysroot #{MacOS.sdk_path}"
      cppflags << "-I#{MacOS.sdk_path}/usr/include" # find zlib
    end

    # G5 build under Tiger failed to recognize “vector” keyword in system header
    cflags << '-mpim-altivec' if MacOS.version == :tiger and CPU.altivec? \
                                 and [:gcc, :gcc_4_0, :llvm].include? ENV.compiler

    f = Formula['tcl-tk']
    cppflags << "-I#{f.opt_include}"
    ldflags  << "-L#{f.opt_lib}"

    args << "CPPFLAGS=#{cppflags.join(' ')}"
    args << "CFLAGS=#{cflags.join(' ')}" unless cflags.empty?
    args << "LDFLAGS=#{ldflags.join(' ')}"

    system './configure', *args
    system 'make'
    ENV.deparallelize do
      # Tell Python not to install into /Applications
      system 'make', 'install', "PYTHONAPPSDIR=#{prefix}"
      system 'make', 'frameworkinstallextras', "PYTHONAPPSDIR=#{pkgshare}"
    end
    # Remove 2to3 because Python 3 also installs it, as well as unversioned symlinks
    %w[2to3 idle pydoc python python-config pythonw smtpd.py].each do |link|
      rm "#{cellar_framework}/bin/#{link}"
    end

    # Fixes setting Python build flags for certain software
    # See: https://github.com/Homebrew/homebrew/pull/20182
    # https://bugs.python.org/issue3588
    inreplace cellar_framework/'lib/python2.7/config/Makefile' do |s|
      s.change_make_var! 'LINKFORSHARED',
        "-u _PyMac_Error $(PYTHONFRAMEWORKINSTALLDIR)/Versions/$(VERSION)/$(PYTHONFRAMEWORK)"
    end

    # Prevent third-party packages from building against fragile Cellar paths
    inreplace [cellar_framework/'lib/python2.7/_sysconfigdata.py',
               cellar_framework/'lib/python2.7/config/Makefile',
               cellar_framework/'lib/pkgconfig/python-2.7.pc'],
              prefix, opt_prefix

    # A fix, because python2 and python3 both want to install Python.framework which would conflict in HOMEBREW_PREFIX/Frameworks.
    # https://github.com/Homebrew/homebrew/issues/15943
    # After 2020, Python 3 is the norm; thus, remove these from Python2 rather than from Python3.
    ['Headers', 'Python', 'Resources', 'Versions/Current'].each{ |ln| rm frameworks/"Python.framework/#{ln}" }

    # Any .apps get a “ 2” inserted, to not conflict with python 3.x.
    Dir.glob(prefix/'*.app') { |app| mv app, app.sub('.app', ' 2.app') }

    cd 'Doc' do
      system 'make', 'html'
      doc.install Dir['build/html/*']
    end if build.with?('html-docs')

    # Ensure the pkgconfig files get linked into HOMEBREW_PREFIX so they’re accessible.
    (lib/'pkgconfig').install_symlink Dir[cellar_framework/'lib/pkgconfig/*']

    # Remove the site-packages which Python created in its Cellar.  Replace it using HOMEBREW_PREFIX/lib/python27/site-packages, so
    # that user‐installed Python software survives minor updates, such as going from 2.7.2 to 2.7.3.
    site_packages.mkpath
    cellar_site_packages.rmtree
    cellar_site_packages.parent.install_symlink_to site_packages

    # Write our sitecustomize.py
    rm_rf Dir["#{site_packages}/sitecustomize.py[co]"]
    (site_packages/'sitecustomize.py').atomic_write(sitecustomize)
  end # install

  def post_install
    # Remove old setuptools installations that may still fly around and be listed in the easy_install.pth.  It can break setuptools
    # builds with, e.g., “zipimport.ZipImportError: bad local file header setuptools-0.9.5-py3.3.egg”.
    rm_rf Dir["#{site_packages}/setuptools*"]
    rm_rf Dir["#{site_packages}/distribute*"]
    rm_rf Dir["#{site_packages}/pip{,[-_.][0-9]*}"]

    # Help distutils find brewed stuff when building extensions.
    f_ossl = Formula['openssl3'];  f_tcltk = Formula['tcl-tk']
    include_dirs = [HOMEBREW_PREFIX/'include', f_ossl.opt_include, f_tcltk.opt_include]
    library_dirs = [HOMEBREW_PREFIX/'lib',     f_ossl.opt_lib,     f_tcltk.opt_lib]
    if build.with? 'sqlite'
      f = Formula['sqlite']
      include_dirs << f.opt_include
      library_dirs << f.opt_lib
    end

    (cellar_framework/'lib/python2.7/distutils/distutils.cfg').atomic_write <<-EOS.undent
        [install]
        prefix=#{cellar_framework}

        [build_ext]
        include_dirs=#{include_dirs.join ':'}
        library_dirs=#{library_dirs.join ':'}
      EOS

    (cellar_framework/'pip.conf').atomic_write <<-_.undent
        [install]
        prefix=#{cellar_framework}
        no-warn-script-location=true
      _

    # (Re‐)install pip, setuptools, & wheel, which will have been smurfed up by the site‐packages shenanigans above (not to mention
    # being out of date) if they were already present.
    system bin/'python2', '-m', 'ensurepip', '--upgrade'
    cfb = cellar_framework/'bin'
    system "#{cfb}/pip2", 'install', '--force-reinstall', '--upgrade', 'pip'
    # Replace duplicate files with symlinks.
    rm Dir["#{cfb}/pip{,2}"]
    cfb.install_symlink_to 'pip2.7' => 'pip2'
    bin.install_symlink_to "#{cfb}/pip2.7" => 'pip2'

    inreplace [cellar_framework/"lib/python2.7/distutils/distutils.cfg", cellar_framework/'pip.conf'],
      %r{prefix=#{cellar_framework}},
      "prefix=#{HOMEBREW_PREFIX}"

    system "#{cfb}/pip2", 'install', '--force-reinstall', '--upgrade', 'setuptools'
  end # install

  def cellar_framework; frameworks/'Python.framework/Versions/2.7'; end

  def cellar_site_packages; cellar_framework/relative_site_packages; end

  def relative_site_packages; 'lib/python2.7/site-packages'; end

  def site_packages; HOMEBREW_PREFIX/relative_site_packages; end

  def sitecustomize; <<-EOS.undent
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import sys

      if sys.version_info[0] != 2:
          # This can only happen if the user has set the PYTHONPATH for 3.x and run Python 2.x or vice versa.  Every Python looks
          # at the PYTHONPATH variable and we can't fix it here in sitecustomize.py, because the PYTHONPATH is evaluated after the
          # sitecustomize.py.  Many modules (e.g. PyQt4) are built only for a specific version of Python and will fail with cryptic
          # error messages.  In the end this means:  Don't set the PYTHONPATH permanently if you use different Python versions.
          exit('Your PYTHONPATH points to a site-packages dir for Python 2.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' +
               str(os.environ['PYTHONPATH']) + '"\\n' + '     You should `unset PYTHONPATH` to fix this.')

      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path and reject paths in /System pre-emptively (#14712)
          library_site = '/Library/Python/2.7/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site) and
                                             not p.startswith('/System')]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)

          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/2\.7/lib/python2\.7/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]

          # LINKFORSHARED (and python-config --ldflags) return the full path to the lib (yes, "Python" is actually the lib, not a
          # dir) so that third-party software does not need to add the -F/#{HOMEBREW_PREFIX}/Frameworks switch.
          try:
              from _sysconfigdata import build_time_vars
              build_time_vars['LINKFORSHARED'] = '-u _PyMac_Error #{opt_frameworks}/Python.framework/Versions/2.7/Python'
          except:
              pass  # remember: don't print here. Better to fail silently.

          # Set the sys.executable to use the opt_prefix
          sys.executable = '#{opt_bin}/python2.7'
    EOS
  end # sitecustomize

  def caveats; <<-EOS.undent
      The interpreter binary is named “python2”, not just plain “python” (Python 2 is
      now so obsolete that “python” generally means “python3”, assuming you have it
      installed).

      Pip and setuptools are installed. To update them
          pip2 install --upgrade pip setuptools

      You can install Python2 packages with
          pip2 install <package>

      They will install into the site-package directory
          #{site_packages}

      See:  #{HOMEBREW_REPOSITORY}/share/doc/homebrew/Homebrew-and-Python.md
    EOS
  end # caveats

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    arch_system cellar_framework/'bin/python2.7', '-c', "'import sqlite3'"
    # Check if some other modules import. Then the linked libs are working.
    arch_system cellar_framework/'bin/python2.7', '-c', "'import Tkinter; root = Tkinter.Tk()'"
    system cellar_framework/'bin/pip2', 'list', '--format=columns'  # pip is not a binary
  end # test
end # Python2

__END__
# Enable PowerPC-only universal builds.
--- old/configure	2020-04-19 14:13:39 -0700
+++ new/configure	2024-09-24 20:31:23 -0700
@@ -6152,6 +6152,21 @@
                LIPO_32BIT_FLAGS=""
                ARCH_RUN_32BIT=""
                ;;
+            powerpc)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc -arch ppc64"
+               LIPO_32BIT_FLAGS="-extract ppc7400"
+               ARCH_RUN_32BIT="/usr/bin/arch -ppc"
+               ;;
+            powerpc-32)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc"
+               LIPO_32BIT_FLAGS=""
+               ARCH_RUN_32BIT=""
+               ;;
+            powerpc-64)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc64"
+               LIPO_32BIT_FLAGS=""
+               ARCH_RUN_32BIT=""
+               ;;
             3-way)
                UNIVERSAL_ARCH_FLAGS="-arch i386 -arch ppc -arch x86_64"
                LIPO_32BIT_FLAGS="-extract ppc7400 -extract i386"
# For some reason, they have never bothered to use the correct shared‐library filename extension.
@@ -8544,6 +8559,7 @@
 		esac
 		;;
 	CYGWIN*)   SO=.dll;;
+	Darwin*)   SO=.dylib;;
 	*)	   SO=.so;;
 	esac
 else
# Enable PowerPC-only universal builds.
--- old/Lib/_osx_support.py	2020-04-19 14:13:39 -0700
+++ new/Lib/_osx_support.py	2024-09-24 22:33:49 -0700
@@ -472,6 +472,8 @@
                 machine = archs[0]
             elif archs == ('i386', 'ppc'):
                 machine = 'fat'
+            elif archs == ('ppc', 'ppc64'):
+                machine = 'powerpc'
             elif archs == ('i386', 'x86_64'):
                 machine = 'intel'
             elif archs == ('i386', 'ppc', 'x86_64'):
# For some reason, they have never bothered to use the correct shared‐library filename extension.
--- old/Python/dynload_shlib.c
+++ new/Python/dynload_shlib.c
@@ -46,8 +46,13 @@
     {"module.exe", "rb", C_EXTENSION},
     {"MODULE.EXE", "rb", C_EXTENSION},
 #else
+#if defined(__APPLE__)
+    {".dylib", "rb", C_EXTENSION},
+    {"module.dylib", "rb", C_EXTENSION},
+#else
     {".so", "rb", C_EXTENSION},
     {"module.so", "rb", C_EXTENSION},
+#endif
 #endif
 #endif
 #endif
# Don’t search for a Tk framework – our Tk is a pure Unix build.
# from https://raw.githubusercontent.com/Homebrew/patches/42fcf22/python/brewed-tk-patch.diff
--- old/setup.py
+++ new/setup.py
@@ -1928,9 +1928,6 @@
         # Rather than complicate the code below, detecting and building
         # AquaTk is a separate method. Only one Tkinter will be built on
         # Darwin - either AquaTk, if it is found, or X11 based Tk.
-        if (host_platform == 'darwin' and
-            self.detect_tkinter_darwin(inc_dirs, lib_dirs)):
-            return

         # Assume we haven't found any of the libraries or include files
         # The versions with dots are used on Unix, and the versions without
