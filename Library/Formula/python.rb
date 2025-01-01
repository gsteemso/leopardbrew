class Python < Formula
  desc 'Interpreted, interactive, object-oriented programming language'
  homepage 'https://www.python.org'
  url 'https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz'
  sha256 'b62c0e7937551d0cc02b8fd5cb0f544f9405bafc9a54d3808ed4594812edef43'
  # as Python 2.7 development halted years ago, the :HEAD version is no longer available
  revision 1

  bottle do
    sha256 '2e35834cc056418aef2471eddb7b75a83fd3336b8c832bb0bbf13f140bb68dcc' => :tiger_altivec
  end

  # Please don't add a wide/ucs4 option, as it won't be accepted.
  # More details in: https://github.com/Homebrew/homebrew/pull/32368
  option :universal

  # sphinx-doc depends on python, but on 10.6 or earlier python is fulfilled by
  # brew, which would lead to circular dependency.
  if MacOS.version > :snow_leopard
    option 'with-sphinx-doc', 'Build HTML documentation'
    depends_on 'sphinx-doc' => [:build, :optional]
  end

  depends_on 'pkg-config' => :build
  depends_on 'openssl'
  depends_on 'tcl-tk'
  depends_on :x11 if Tab.for_name('tcl-tk').with?('x11')
  depends_on 'gdbm' => :recommended
  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'berkeley-db4' => :optional

  skip_clean 'bin/pip', 'bin/pip-2.7'
  skip_clean 'bin/easy_install', 'bin/easy_install-2.7'

  # Patch to disable the search for Tk.framework, since Homebrew’s Tk is
  # a plain unix build. Remove `-lX11` too, because our Tk is “AquaTk”.
  patch do
    url 'https://raw.githubusercontent.com/Homebrew/patches/42fcf22/python/brewed-tk-patch.diff'
    sha256 '15c153bdfe51a98efe48f8e8379f5d9b5c6c4015e53d3f9364d23c8689857f09'
  end

  patch :DATA  # enable PPC‐only universal builds

  # setuptools remembers the build flags python is built with and uses them to
  # build packages later. Xcode-only systems need different flags.
  def pour_bottle
    reason <<-EOS.undent
      The bottle needs the Apple Command Line Tools to be installed.
      You can install them, if desired, with:
          xcode-select --install
    EOS
    satisfy { MacOS::CLT.installed? }
  end # pour_bottle

  def install
    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONHOME'] = nil
    ENV['PYTHONPATH'] = nil

    # Avoid linking to libgcc (see https://code.activestate.com/lists/python-dev/112195/)
    args = %W[
      --prefix=#{prefix}
      --enable-ipv6
      --datarootdir=#{share}
      --datadir=#{share}
      --enable-framework=#{frameworks}
      --without-ensurepip
      MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}
    ]
    args << '--without-gcc' if ENV.compiler == :clang

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

    # We want our readline and openssl! This is just to outsmart the detection code,
    # superenv handles that cc finds includes/libs!
    inreplace 'setup.py' do |s|
      s.gsub! "do_readline = self.compiler.find_library_file(lib_dirs, 'readline')",
              "do_readline = '#{Formula['readline'].opt_lib}/libhistory.dylib'"
      s.gsub! '/usr/local/ssl', Formula['openssl'].opt_prefix
      s.gsub! '/usr/include/db4', Formula['berkeley-db4'].opt_include
    end

    args << '--enable-universalsdk=/'
    if build.universal? then
      bitness = ''
      if superenv?
        # one of the modules adds “-arch i386” on PPC to work around a linker bug, so no PPC CPUs
        ENV['HOMEBREW_OPTFLAGS'] = '' if Hardware::CPU.ppc?
      end
    elsif Hardware::CPU.is_32_bit? then bitness = '-32'
    else bitness = '-64'; end
    # ARM builds are not supported; just build for Intel and hope it keeps working
    args << "--with-universal-archs=#{Hardware::CPU.ppc? ? 'ppc' : 'intel'}#{bitness}"

    if build.with? 'sqlite'
      inreplace 'setup.py' do |s|
        s.gsub! 'sqlite_setup_debug = False', 'sqlite_setup_debug = True'
        s.gsub! 'for d_ in inc_dirs + sqlite_inc_paths:',
                "for d_ in ['#{Formula['sqlite'].opt_include}']:"
        # Allow sqlite3 module to load extensions:
        # https://docs.python.org/library/sqlite3.html#f1
        s.gsub! 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', ''
      end
    end

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace './Lib/ctypes/macholib/dyld.py' do |f|
      f.gsub! 'DEFAULT_LIBRARY_FALLBACK = [', "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      f.gsub! 'DEFAULT_FRAMEWORK_FALLBACK = [', "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    tcl_tk = Formula['tcl-tk'].opt_prefix
    cppflags << "-I#{tcl_tk}/include"
    ldflags  << "-L#{tcl_tk}/lib"

    args << "CFLAGS=#{cflags.join(' ')}" unless cflags.empty?
    args << "LDFLAGS=#{ldflags.join(' ')}" unless ldflags.empty?
    args << "CPPFLAGS=#{cppflags.join(' ')}" unless cppflags.empty?

    system './configure', *args
    system 'make'
    ENV.deparallelize do
      # Tell Python not to install into /Applications
      system 'make', 'install', "PYTHONAPPSDIR=#{prefix}"
      system 'make', 'frameworkinstallextras', "PYTHONAPPSDIR=#{pkgshare}"
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

    # A fix, because python and python3 both want to install Python.framework
    # and therefore we can't link both into HOMEBREW_PREFIX/Frameworks
    # https://github.com/Homebrew/homebrew/issues/15943
    # In 2024, Python 3 is the norm; thus, remove these from Python rather than from Python3
    ['Headers', 'Python', 'Resources'].each { |f| rm frameworks/"Python.framework/#{f}" }
    rm frameworks/'Python.framework/Versions/Current'

    # Symlink the pkgconfig files into HOMEBREW_PREFIX so they're accessible.
    (lib/'pkgconfig').install_symlink Dir[cellar_framework/'lib/pkgconfig/*']

    # Remove 2to3 because Python 3 also installs it
    rm bin/'2to3'

    # Remove the site-packages that Python created in its Cellar.
    cellar_site_packages.rmtree

    if MacOS.version > :snow_leopard && build.with?('sphinx-doc')
      cd 'Doc' do
        system 'make', 'html'
        doc.install Dir['build/html/*']
      end
    end
  end # install

  def post_install
    # Avoid conflicts with lingering unversioned files from Python 3
    rm_f %W[
      #{HOMEBREW_PREFIX}/bin/easy_install
      #{HOMEBREW_PREFIX}/bin/pip
      #{HOMEBREW_PREFIX}/bin/wheel
    ]

    # Fix up the site-packages so that user-installed Python software survives
    # minor updates, such as going from 2.7.0 to 2.7.1:

    # Symlink the prefix site-packages into the cellar.
    cellar_site_packages.unlink if cellar_site_packages.exist?
    cellar_site_packages.parent.install_symlink site_packages

    # Create a site-packages in HOMEBREW_PREFIX/lib/python2.7/site-packages
    site_packages.mkpath

    # Write our sitecustomize.py
    rm_rf Dir["#{site_packages}/sitecustomize.py[co]"]
    (site_packages/'sitecustomize.py').atomic_write(sitecustomize)

    # Remove old setuptools installations that may still fly around and be
    # listed in the easy_install.pth. This can break setuptools build with
    # zipimport.ZipImportError: bad local file header
    # setuptools-0.9.5-py3.3.egg
    rm_rf Dir["#{site_packages}/setuptools*"]
    rm_rf Dir["#{site_packages}/distribute*"]
    rm_rf Dir["#{site_packages}/pip[-_.][0-9]*", "#{site_packages}/pip"]

    # (Re‐)install pip (and setuptools) and wheel, which will have gotten smurfed up by the site‐
    # packages shenanigans above
    system bin/'python', '-m', 'ensurepip', '--upgrade'
    ['pip', 'setuptools'].each do |pkg|
      system cellar_framework/'bin/pip', 'install', '--force-reinstall', '--upgrade', '--no-warn-script-location', pkg
    end

    # When building from source, these symlinks will not exist, since
    # post_install happens after linking.
    %w[pip pip2 pip2.7 easy_install easy_install-2.7 wheel].each do |e|
      (HOMEBREW_PREFIX/'bin').install_symlink bin/e
    end

    # Help distutils find brewed stuff when building extensions
    include_dirs = [HOMEBREW_PREFIX/'include', Formula['openssl'].opt_include, Formula['tcl-tk'].opt_include]
    library_dirs = [HOMEBREW_PREFIX/'lib', Formula['openssl'].opt_lib, Formula['tcl-tk'].opt_lib]

    if build.with? 'sqlite'
      include_dirs << Formula['sqlite'].opt_include
      library_dirs << Formula['sqlite'].opt_lib
    end

    (cellar_framework/'lib/python2.7/distutils/distutils.cfg').atomic_write <<-EOS.undent
      [install]
      prefix=#{HOMEBREW_PREFIX}

      [build_ext]
      include_dirs=#{include_dirs.join ':'}
      library_dirs=#{library_dirs.join ':'}
    EOS
  end # post_install

  def cellar_framework; frameworks/'Python.framework/Versions/2.7/'; end

  def cellar_site_packages; cellar_framework/'lib/python2.7/site-packages'; end

  def site_packages; HOMEBREW_PREFIX/'lib/python2.7/site-packages'; end

  def sitecustomize; <<-EOS.undent
      # This file is created by Homebrew and is executed on each python startup.
      # Don't print from here, or else python command line scripts may fail!
      # <https://docs.brew.sh/Homebrew-and-Python>
      import re
      import os
      import sys

      if sys.version_info[0] != 2:
          # This can only happen if the user has set the PYTHONPATH for 3.x and run Python 2.x or vice versa.
          # Every Python looks at the PYTHONPATH variable and we can't fix it here in sitecustomize.py,
          # because the PYTHONPATH is evaluated after the sitecustomize.py. Many modules (e.g. PyQt4) are
          # built only for a specific version of Python and will fail with cryptic error messages.
          # In the end this means: Don't set the PYTHONPATH permanently if you use different Python versions.
          exit('Your PYTHONPATH points to a site-packages dir for Python 2.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
               '     You should `unset PYTHONPATH` to fix this.')

      # Only do this for a brewed python:
      if os.path.realpath(sys.executable).startswith('#{rack}'):
          # Shuffle /Library site-packages to the end of sys.path and reject
          # paths in /System pre-emptively (#14712)
          library_site = '/Library/Python/2.7/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site) and
                                             not p.startswith('/System')]
          # .pth files have already been processed so don't use addsitedir
          sys.path.extend(library_packages)

          # the Cellar site-packages is a symlink to the HOMEBREW_PREFIX
          # site_packages; prefer the shorter paths
          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/2\.7/lib/python2\.7/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]

          # LINKFORSHARED (and python-config --ldflags) return the
          # full path to the lib (yes, "Python" is actually the lib, not a
          # dir) so that third-party software does not need to add the
          # -F/#{HOMEBREW_PREFIX}/Frameworks switch.
          try:
              from _sysconfigdata import build_time_vars
              build_time_vars['LINKFORSHARED'] = '-u _PyMac_Error #{opt_prefix}/Frameworks/Python.framework/Versions/2.7/Python'
          except:
              pass  # remember: don't print here. Better to fail silently.

          # Set the sys.executable to use the opt_prefix
          sys.executable = '#{opt_bin}/python2.7'
    EOS
  end # sitecustomize

  def caveats; <<-EOS.undent
      Pip and setuptools are installed. To update them
          pip install --upgrade pip setuptools

      You can install Python packages with
          pip install <package>

      They will install into the site-package directory
          #{site_packages}

      See: https://docs.brew.sh/Homebrew-and-Python
    EOS
  end # caveats

  test do
    # Check if sqlite is ok, because we build with --enable-loadable-sqlite-extensions
    # and it can occur that building sqlite silently fails if OSX's sqlite is used.
    arch_system cellar_framework/'bin/python2.7', '-c', 'import sqlite3'
    # Check if some other modules import. Then the linked libs are working.
    arch_system cellar_framework/'bin/python2.7', '-c', 'import Tkinter; root = Tkinter.Tk()'
    system cellar_framework/'bin/pip', 'list', '--format=columns'  # pip is not a binary
  end # test
end # Python

__END__
--- old/configure	2020-04-19 14:13:39 -0700
+++ new/configure	2024-09-24 20:31:23 -0700
@@ -6152,6 +6152,21 @@
                LIPO_32BIT_FLAGS=""
                ARCH_RUN_32BIT=""
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
+               ARCH_RUN_32BIT=""
+               ;;
             3-way)
                UNIVERSAL_ARCH_FLAGS="-arch i386 -arch ppc -arch x86_64"
                LIPO_32BIT_FLAGS="-extract ppc7400 -extract i386"
--- old/Lib/_osx_support.py	2020-04-19 14:13:39 -0700
+++ new/Lib/_osx_support.py	2024-09-24 22:33:49 -0700
@@ -472,6 +472,8 @@
                 machine = archs[0]
             elif archs == ('i386', 'ppc'):
                 machine = 'fat'
+            elif archs == ('ppc', 'ppc64'):
+                machine = 'fatppc'
             elif archs == ('i386', 'x86_64'):
                 machine = 'intel'
             elif archs == ('i386', 'ppc', 'x86_64'):
