class Python3 < Formula
  desc 'Interpreted, interactive, object-oriented programming language'
  homepage 'https://www.python.org/'
  url 'https://www.python.org/ftp/python/3.10.15/Python-3.10.15.tar.xz'
  sha256 'aab0950817735172601879872d937c1e4928a57c409ae02369ec3d91dccebe79'

  XY = '3.10'.freeze

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'gdbm' => :recommended
  depends_on 'readline' => :recommended
  depends_on 'xz' => :recommended # for the lzma module added in 3.3
  depends_on 'bzip2'
  depends_on 'openssl3'
  depends_on 'sqlite'
  depends_on 'tcl-tk'
  depends_on :x11 if Tab.for_name('tcl-tk').with?('x11')

  skip_clean 'bin/pip3', 'bin/pip-3.4', 'bin/pip-3.5', 'bin/pip-3.6', 'bin/pip-3.7', 'bin/pip-3.10'

  # - Enable PPC‐only universal builds.
  # - Homebrew's tcl-tk is built in standard unix fashion (due to link errors)
  #   so we have to stop python from searching for frameworks and linking
  #   against X11.
  # - Add Support for OS X before 10.6
  #   from macports/lang/python310/files/patch-threadid-older-systems.diff
  #   and macports/lang/python310/files/patch-no-copyfile-on-Tiger.diff
  patch :p0, :DATA

  # setuptools remembers the build flags python is built with and uses them to
  # build packages later. Xcode-only systems need different flags.
  def pour_bottle?
    MacOS::CLT.installed?
  end

  def install
    # Unset these so that installing pip puts it where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONHOME'] = nil
    ENV['PYTHONPATH'] = nil

    # Avoid linking to libgcc http://code.activestate.com/lists/python-dev/112195/
    args = %W[
      --prefix=#{prefix}
      --enable-ipv6
      --datarootdir=#{share}
      --datadir=#{share}
      --enable-framework=#{frameworks}
      --enable-loadable-sqlite-extensions
      --with-openssl=#{Formula['openssl3'].opt_prefix}
      MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}
    ]
    args << '--without-gcc' if ENV.compiler == :clang

    args << '--enable-universalsdk=/'
    if build.universal? then
      ENV.permit_arch_flags if superenv?
      bitness = ''
    elsif Hardware::CPU.is_32_bit? then bitness = '-32'
    else bitness = '-64'; end
    args << "--with-universal-archs=#{Hardware::CPU.ppc? ? 'ppc' : 'intel'}#{bitness}"

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

    # There is no simple way to extract a “ppc” slice from a universal file.  We have to
    # specify the exact sub‐architecture we actually put in there in the first place.
    if Hardware::CPU.ppc?
      our_ppc_flavour = Hardware::CPU.optimization_flags[Hardware::CPU.family][/^-mcpu=(\d+)/, 1]
      inreplace 'configure' do |s| s.gsub! '-extract ppc7400', "-extract ppc#{our_ppc_flavour}" end
    end

    # We want our readline! This is just to outsmart the detection code,
    # superenv makes cc always find includes/libs!
    inreplace 'setup.py',
      'do_readline = self.compiler.find_library_file(self.lib_dirs,
                readline_lib)',
      "do_readline = '#{Formula['readline'].opt_lib}/libhistory.dylib'"

    inreplace 'setup.py' do |s|
      s.gsub! 'sqlite_setup_debug = False', 'sqlite_setup_debug = True'
      s.gsub! 'for d_ in self.inc_dirs + sqlite_inc_paths:',
              "for d_ in ['#{Formula['sqlite'].opt_include}']:"
    end

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace './Lib/ctypes/macholib/dyld.py' do |f|
      f.gsub! 'DEFAULT_LIBRARY_FALLBACK = [', "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      f.gsub! 'DEFAULT_FRAMEWORK_FALLBACK = [', "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    tcl_tk = Formula['tcl-tk'].opt_prefix
    ENV.append 'CPPFLAGS', "-I#{tcl_tk}/include"
    ENV.append 'LDFLAGS', "-L#{tcl_tk}/lib"

    args << "CFLAGS=#{cflags.join(' ')}" unless cflags.empty?
    args << "LDFLAGS=#{ldflags.join(' ')}" unless ldflags.empty?
    args << "CPPFLAGS=#{cppflags.join(' ')}" unless cppflags.empty?

    system './configure', *args
    system 'make'

    ENV.deparallelize # Installs must be serialized
    # Tell Python not to install into /Applications (default for framework builds)
    system 'make', 'install', "PYTHONAPPSDIR=#{prefix}"
    # Demos and Tools
    system 'make', 'frameworkinstallextras', "PYTHONAPPSDIR=#{share}/python3"

    # Any .app get a “ 3” attached, so it does not conflict with python 2.x.
    Dir.glob(prefix/'*.app') { |app| mv app, app.sub('.app', ' 3.app') }

    # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
    (lib/'pkgconfig').install_symlink Dir[cellar_framework/'lib/pkgconfig/*']

    # No need to remove 2to3 – while python2 includes it, the python 2 formula already deletes it
    # rm bin/'2to3'

    # Remove the site-packages that Python created in its Cellar.  See below in post_install.
    cellar_site_packages.rmtree

    # Install unversioned symlinks in libexec/bin.
    { 'idle' => 'idle3',
      'pydoc' => 'pydoc3',
      'python' => 'python3',
      'python-config' => 'python3-config',
    }.each do |unversioned_name, versioned_name|
      (libexec/'bin').install_symlink (bin/versioned_name).realpath => unversioned_name
    end
  end # install

  def post_install
    ENV.delete 'PYTHONPATH'

    # Create a site-packages in HOMEBREW_PREFIX/lib/python#{xy}/site-packages so that user‐
    # installed Python software survives minor updates, such as going from 3.3.2 to 3.3.3:
    site_packages.mkpath
    # Symlink it into the cellar
    cellar_site_packages.rmtree if cellar_site_packages.exists?
    cellar_site_packages.parent.install_symlink site_packages

    # redo the Pip3 install, which gets smurfed up by the site-packages shenanigans above
    system bin/'python3', '-m', 'ensurepip', '--upgrade'

    # upgrade the stuff pip dragged in
    ['setuptools', 'wheel'].each do |pkg|
      system bin/'pip3', 'install', '--force-reinstall', '--upgrade', '--no-warn-script-location', pkg
    end
    rm_rf cellar_framework/'bin/pip'
    mv cellar_framework/'bin/wheel', cellar_framework/'bin/wheel3'
    bin.install_symlink cellar_framework/'bin/wheel3'

    # Write our sitecustomize.py
    rm_rf Dir[site_packages/'sitecustomize.py[co]']
    (site_packages/'sitecustomize.py').atomic_write(sitecustomize)

    # Fix up the LINKFORSHARED configuration variable
    inreplace Dir[cellar_framework/"lib/python#{xy}/_sysconfigdata_*.py"],
              %r{('LINKFORSHARED':\s+'.+?(?:'\n\s+')?)(Python.framework/Versions/#{xy}/Python',)},
              "\\1#{opt_frameworks}/\\2"

    # Install unversioned symlinks in libexec/bin.
    { 'pip' => 'pip3',
      'wheel' => 'wheel3',
    }.each do |unversioned_name, versioned_name|
      (libexec/'bin').install_symlink (bin/versioned_name).realpath => unversioned_name
    end

    # post_install happens after link
    %W[pip3 pip#{xy} wheel3].each do |e|
      (HOMEBREW_PREFIX/'bin').install_symlink bin/e
    end

    # Help distutils find brewed stuff when building extensions
    include_dirs = [HOMEBREW_PREFIX/'include', Formula['openssl3'].opt_include,
                    Formula['sqlite'].opt_include, Formula['tcl-tk'].opt_include]
    library_dirs = [HOMEBREW_PREFIX/'lib', Formula['openssl3'].opt_lib,
                    Formula['sqlite'].opt_lib, Formula['tcl-tk'].opt_lib]

    cfg = cellar_framework/"lib/python#{xy}/distutils/distutils.cfg"

    cfg.atomic_write <<-EOS.undent
      [install]
      prefix=#{HOMEBREW_PREFIX}

      [build_ext]
      include_dirs=#{include_dirs.join ':'}
      library_dirs=#{library_dirs.join ':'}
    EOS
  end # post_install

  def cellar_framework; frameworks/"Python.framework/Versions/#{xy}"; end

  def cellar_site_packages; cellar_framework/"lib/python#{xy}/site-packages"; end

  def site_packages; HOMEBREW_PREFIX/"lib/python#{xy}/site-packages"; end

  def xy; XY; end

  def sitecustomize
    <<-EOS.undent
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import sys

      if sys.version_info[0] != 3:
          # This can only happen if the user has set the PYTHONPATH for 3.x and run
          # Python 2.x or vice versa.  Every Python looks at the PYTHONPATH variable
          # and we can't fix it here in sitecustomize.py, because the PYTHONPATH is
          # evaluated after the sitecustomize.py.  Many modules (e.g. PyQt4) are
          # built only for a specific version of Python and will fail with cryptic
          # error messages.  In the end this means:  Don't set the PYTHONPATH
          # permanently if you use different Python versions.
          exit('Your PYTHONPATH points to a site-packages dir for Python 3.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
               '     You should `unset PYTHONPATH` to fix this.')

      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path
          library_site = '/Library/Python/#{xy}/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site)]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)

          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX
          # site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/#{xy}/lib/python#{xy}/site-packages')
          sys.path = [long_prefix.sub('#{HOMEBREW_PREFIX/"lib/python#{xy}/site-packages"}', p) for p in sys.path]

          # Set the sys.executable to use the opt_prefix
          sys.executable = '#{opt_bin}/python#{xy}'
    EOS
  end # sitecustomize

  def caveats
    text = <<-EOS.undent
      Python is installed as
          #{HOMEBREW_PREFIX}/bin/python3

      Unversioned symlinks `python`, `python-config`, `pip` etc. pointing to
      `python3`, `python3-config`, `pip3` etc., respectively, are installed into
          #{opt_libexec}/bin

      If you need Leopardbrew’s Python 2.7 run
          brew install python

      Pip and wheel are installed. To update them run
          pip3 install --upgrade pip wheel

      You can install Python packages with
          pip3 install <package>
      They will install into the site-package directory
          #{HOMEBREW_PREFIX/"lib/python#{xy}/site-packages"}

      See: https://docs.brew.sh/Homebrew-and-Python
    EOS

    text += <<-EOS.undent if MacOS.version <= :snow_leopard

      Apple’s Tcl/Tk is not recommended for Python on Mac OS X 10.6 or earlier.
      For more information see:  https://www.python.org/download/mac/tcltk/
    EOS

    text
  end # caveats

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    system bin/"python#{xy}", '-c', 'import sqlite3'
    # Check if some other modules import. Then the linked libs are working.
    system bin/"python#{xy}", '-c', 'import tkinter; root = tkinter.Tk()'
    system bin/'pip3', 'list'
  end # test
end # Python3

__END__
--- configure	2024-09-06 17:20:06 -0700
+++ configure	2024-09-28 18:29:02 -0700
@@ -7578,6 +7578,21 @@
                LIPO_INTEL64_FLAGS="-extract x86_64"
                ARCH_RUN_32BIT="true"
                ;;
+            ppc)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc -arch ppc64"
+               LIPO_32BIT_FLAGS="-extract ppc7400"
+               ARCH_RUN_32BIT="/usr/bin/arch -ppc"
+               ;;
+            ppc-32)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc"
+               LIPO_32BIT_FLAGS=""
+               ARCH_RUN_32BIT=""
+               ;;
+            ppc-64)
+               UNIVERSAL_ARCH_FLAGS="-arch ppc64"
+               LIPO_32BIT_FLAGS=""
+               ARCH_RUN_32BIT="true"
+               ;;
             intel)
                UNIVERSAL_ARCH_FLAGS="-arch i386 -arch x86_64"
                LIPO_32BIT_FLAGS="-extract i386"
@@ -7599,7 +7614,7 @@
                ARCH_RUN_32BIT="/usr/bin/arch -i386 -ppc"
                ;;
             *)
-               as_fn_error $? "proper usage is --with-universal-arch=universal2|32-bit|64-bit|all|intel|3-way" "$LINENO" 5
+               as_fn_error $? "proper usage is --with-universal-arch=universal2|32-bit|64-bit|all|ppc|intel|3-way" "$LINENO" 5
                ;;
             esac
 
--- Lib/_osx_support.py	2024-09-06 17:20:06 -0700
+++ Lib/_osx_support.py	2024-09-27 21:27:57 -0700
@@ -544,6 +544,8 @@
                 machine = 'universal2'
             elif archs == ('i386', 'ppc'):
                 machine = 'fat'
+            elif archs == ('ppc', 'ppc64'):
+                machine = 'fatppc'
             elif archs == ('i386', 'x86_64'):
                 machine = 'intel'
             elif archs == ('i386', 'ppc', 'x86_64'):
--- setup.py
+++ setup.py
@@ -2111,12 +2111,6 @@
         if self.detect_tkinter_fromenv():
             return True
 
-        # Rather than complicate the code below, detecting and building
-        # AquaTk is a separate method. Only one Tkinter will be built on
-        # Darwin - either AquaTk, if it is found, or X11 based Tk.
-        if (MACOS and self.detect_tkinter_darwin()):
-            return True
-
         # Assume we haven't found any of the libraries or include files
         # The versions with dots are used on Unix, and the versions without
         # dots on Windows, for detection by cygwin.
@@ -2164,22 +2158,6 @@
             if dir not in include_dirs:
                 include_dirs.append(dir)
 
-        # Check for various platform-specific directories
-        if HOST_PLATFORM == 'sunos5':
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
-
         # If Cygwin, then verify that X is installed before proceeding
         if CYGWIN:
             x11_inc = find_file('X11/Xlib.h', [], include_dirs)
@@ -2200,10 +2178,6 @@
         libs.append('tk'+ version)
         libs.append('tcl'+ version)
 
-        # Finally, link with the X11 libraries (not appropriate on cygwin)
-        if not CYGWIN:
-            libs.append('X11')
-
         # XXX handle these, but how to detect?
         # *** Uncomment and edit for PIL (TkImaging) extension only:
         #       -DWITH_PIL -I../Extensions/Imaging/libImaging  tkImaging.c \
--- Modules/posixmodule.c
+++ Modules/posixmodule.c
@@ -72,6 +72,8 @@
  */
 #if defined(__APPLE__)
 
+#include <AvailabilityMacros.h>
+
 #if defined(__has_builtin)
 #if __has_builtin(__builtin_available)
 #define HAVE_BUILTIN_AVAILABLE 1
@@ -244,7 +246,7 @@ corresponding Unix manual entries for mo
 #  include <sys/sendfile.h>
 #endif
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
 #  include <copyfile.h>
 #endif
 
@@ -10035,7 +10037,7 @@ done:
 #endif /* HAVE_SENDFILE */
 
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 /*[clinic input]
 os._fcopyfile
 
@@ -15478,7 +15480,7 @@ all_ins(PyObject *m)
 #endif
 #endif  /* HAVE_EVENTFD && EFD_CLOEXEC */
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
     if (PyModule_AddIntConstant(m, "_COPYFILE_DATA", COPYFILE_DATA)) return -1;
 #endif
 
--- Modules/clinic/posixmodule.c.h
+++ Modules/clinic/posixmodule.c.h
@@ -5270,7 +5270,7 @@ exit:
 
 #endif /* defined(HAVE_SENDFILE) && !defined(__APPLE__) && !(defined(__FreeBSD__) || defined(__DragonFly__)) */
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 
 PyDoc_STRVAR(os__fcopyfile__doc__,
 "_fcopyfile($module, in_fd, out_fd, flags, /)\n"
--- Modules/pyexpat.c
+++ Modules/pyexpat.c
@@ -1233,7 +1233,8 @@ newxmlparseobject(pyexpat_state *state, 
 static int
 xmlparse_traverse(xmlparseobject *op, visitproc visit, void *arg)
 {
-    for (int i = 0; handler_info[i].name != NULL; i++) {
+    int i;
+    for (i = 0; handler_info[i].name != NULL; i++) {
         Py_VISIT(op->handlers[i]);
     }
     Py_VISIT(Py_TYPE(op));
@@ -1862,13 +1863,14 @@ add_model_module(PyObject *mod)
 static int
 add_features(PyObject *mod)
 {
+    size_t i;
     PyObject *list = PyList_New(0);
     if (list == NULL) {
         return -1;
     }
 
     const XML_Feature *features = XML_GetFeatureList();
-    for (size_t i = 0; features[i].feature != XML_FEATURE_END; ++i) {
+    for (i = 0; features[i].feature != XML_FEATURE_END; ++i) {
         PyObject *item = Py_BuildValue("si", features[i].name,
                                        features[i].value);
         if (item == NULL) {
--- Python/thread_pthread.h
+++ Python/thread_pthread.h
@@ -343,7 +346,17 @@ PyThread_get_thread_native_id(void)
         PyThread_init_thread();
 #ifdef __APPLE__
     uint64_t native_id;
+#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
+    native_id = pthread_mach_thread_np(pthread_self());
+#elif MAC_OS_X_VERSION_MIN_REQUIRED < 1060
+    if (&pthread_threadid_np != NULL) {
+	(void) pthread_threaded_np(NULL, &native_id);
+    } else {
+	native_id = pthread_mach_threaded_np(pthread_self());
+    }
+#else
     (void) pthread_threadid_np(NULL, &native_id);
+#endif
 #elif defined(__linux__)
     pid_t native_id;
     native_id = syscall(SYS_gettid);
--- Lib/test/test_shutil.py
+++ Lib/test/test_shutil.py
@@ -2601,7 +2601,7 @@ class TestZeroCopySendfile(_ZeroCopyFileTest, unittest.TestCase):
             shutil._USE_CP_SENDFILE = True
 
 
-@unittest.skipIf(not MACOS, 'macOS only')
+@unittest.skipIf(not MACOS or not hasattr(posix, "_fcopyfile"), 'macOS with posix._fcopyfile only')
 class TestZeroCopyMACOS(_ZeroCopyFileTest, unittest.TestCase):
     PATCHPOINT = "posix._fcopyfile"
 
