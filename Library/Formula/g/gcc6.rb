class Gcc6 < Formula
  desc 'GNU compiler collection'
  homepage 'https://gcc.gnu.org'
  url 'http://ftpmirror.gnu.org/gcc/gcc-6.5.0/gcc-6.5.0.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/gcc/gcc-6.5.0/gcc-6.5.0.tar.xz'
  sha256 '7ef1796ce497e89479183702635b14bb7a46b53249209a5e0f999bebf4740945'
  revision 1  # For the late‐added C++ compatibility patch.

  option 'with-arm32', 'Also build for 32‐bit ARM targets (requires iOS SDK or similar)'
  option 'with-java', 'Build the gcj compiler (depends on {ecj} and {python})'
  option 'with-jit', 'Build the just-in-time compiler (slows down the completed GCC)'
  option 'with-tests', 'Run extra build‐time unit tests (depends on {autogen} & {deja-gnu}; very slow)'
  option 'without-cross-compilers', 'Don’t build counterpart compilers for building fat binaries'
  # Enabling multilib on a host that can’t run 64‐bit causes build failures.
  option 'without-multilib', 'Build without multilib support' if CPU._64b?

  # Tiger’s stock as can’t handle the PowerPC assembly found in libitm.  (Don’t specify this as
  # :cctools, because it might incorrectly assume the stock version meets the requirement.)
  depends_on 'cctools' => :build if MacOS.version < :leopard or build.with? 'arm32'
  depends_group ['tests', ['autogen', 'deja-gnu'] => [:build, :optional]]

  depends_on :ld64 if MacOS.version < :snow_leopard
  depends_on 'gmp'
  depends_on 'libmpc'
  depends_on 'mpfr'
  depends_on 'isl016'
  depends_on :nls => :recommended
  depends_group ['java', ['ecj', :python, :x11] => :optional]

  # The bottles are built on systems with the CLT installed, and do not work out of the box on
  # Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?; MacOS::CLT.installed?; end

  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib.
  cxxstdlib_check :skip

  # Fix a C++ ABI incompatibility found after GCC6 development ended.
  # See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=87822
  patch do
    url 'https://gcc.gnu.org/bugzilla/attachment.cgi?id=44936'
    sha256 'cce0a9a87002b64cf88e595f1520ccfaff7a4c39ee1905d82d203a1ecdfbda29'
  end

  patch :DATA

  # Fix an Intel-only build failure on 10.4.  See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64184
  patch do
    url 'https://gist.githubusercontent.com/mistydemeo/9c5b8dadd892ba3197a9cb431295cc83/raw/582d1ba135511272f7262f51a3f83c9099cd891d/sysdep-unix-tiger-intel.patch'
    sha256 '17afaf7daec1dd207cb8d06a7e026332637b11e83c3ad552b4cd32827f16c1d8'
  end if MacOS.version < :leopard and Target.intel?

  def install
    def add_suffix(file, suffix)
      dir = File.dirname(file)
      ext = File.extname(file)
      base = File.basename(file, ext)
      File.rename file, "#{dir}/#{base}-#{suffix}#{ext}"
    end # add_suffix

    def arch_word(this_arch)
      case this_arch
        when :arm64,
             :arm64e  then 'aarch64'
        when :i386    then 'i686'
        when :ppc     then 'powerpc'
        when :ppc64   then 'powerpc64'
        when :x86_64,
             :x86_64h then 'x86_64'
      end
    end # arch_word

    def raise__no_iphoneos_sdk_found
      raise CannotInstallFormulaError, 'Can’t make compilers for 32‐bit ARM; the iPhoneOS SDK was not found.'
    end

    def osmajor; `uname -r`.match(/^(\d+)\./)[1]; end

    def version_suffix; version.to_s.slice(/\d\d?/); end

    build_platform = arch_word(Target.preferred_arch)
    host_platforms = Target.local_archs.map{ |a| arch_word(a) }
    target_platforms = Target.cross_archs.map{ |a| arch_word(a) }
    target_platforms << 'arm' if build.with? 'arm32'

    if ENV.compiler == :gcc_4_0
      # GCC Bug 25127 – see https://gcc.gnu.org/bugzilla//show_bug.cgi?id=25127
      # ../../../libgcc/unwind.inc: In function '_Unwind_RaiseException':
      # ../../../libgcc/unwind.inc:136:1: internal compiler error: in rs6000_emit_prologue, at
      #   config/rs6000/rs6000.c:26535
      ENV.no_optimization if Target.powerpc?
      # Make sure we don't generate STABS data.
      # /usr/libexec/gcc/powerpc-apple-darwin8/4.0.1/ld:
      #   .libs/libstdc++.lax/libc++98convenience.a/ios_failure.o has both STABS and DWARF debugging info
      # collect2: error: ld returned 1 exit status
      ENV.append_to_cflags '-gstabs0'
    end

    # Prevent libstdc++ being incorrectly tagged with CPU subtype 10 (G4e).
    # See:  https://github.com/mistydemeo/tigerbrew/issues/538
    ENV.append_to_cflags '-force_cpusubtype_ALL' \
      if Target.model == :g3 and [:gcc, :gcc_4_0, :llvm].include? ENV.compiler

    # See the note at the conditional cctools dependency above.
    ENV['AS'] = ENV['AS_FOR_TARGET'] = Formula['cctools'].bin/'as' if MacOS.version < :leopard or build.with? 'arm32'

    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete 'LD'

    # Ensure correct install names when linking against libgcc_s;
    # see discussion in https://github.com/Homebrew/homebrew/pull/34303
    inreplace 'libgcc/config/t-slibgcc-darwin', '@shlib_slibdir@', "#{HOMEBREW_PREFIX}/lib/gcc/#{version_suffix}"

    # When unspecified, GCC 6’s default compilers are C/C++/Fortran/Java/ObjC/ObjC++ – plus link‐
    #   time optimization (which for some reason is handled as a language), because --enable-lto is
    #   on by default.
    # There’s no way to bootstrap the Ada compiler, and while Go has nominally been available since
    #   GCC 4.6.0, it has never worked on Darwin.
    #   See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46986
    # Java and JIT are possible, but Java is of unclear utility because of its implementation as a
    #   compiler rather than an interpreter, while the JIT feature incurs a performance penalty; so
    #   both of them are optional.
    # Given these constraints, by default, only build the default compiler set (including LTO).
    languages = %w[c c++ fortran lto objc obj-c++]
    languages << 'java' if build.with? 'java'
    languages << 'jit' if build.with? 'jit'

    configargs = ["--with-gxx-include-dir=#{lib}/c++/6.0.0"]
    ppc_sysroot = "/Developer/SDKs/MacOSX10.#{MacOS.version < '10.5' ? '4u' : '5'}.sdk"
    ppc_configargs = configargs + ["--with-build-sysroot=#{ppc_sysroot}"]
    arm32_sysroot = ''; arm32_configargs = []; arm32_archs = []
    if build.with? 'arm32'
      arm32_platform = MacOS.active_developer_dir/'Platforms/iPhoneOS.platform'
      raise__no_iphoneos_sdk_found unless arm32_platform.directory?
      arm32_toolroot = arm32_platform/'Developer'
      arm32_SDKs = arm32_toolroot/'SDKs'
      raise__no_iphoneos_sdk_found unless arm32_SDKs.directory?
      candidate_version = ((Dir.glob("#{arm32_SDKs}/iPhoneOS*.sdk").map{ |f|
          File.basename(f, '.sdk')[/\d+\.\d+(?:\.\d+)?/].split('.')
        }.each{ |a|
          a[2] ||= nil   # add nil entries to make every array 3 elements long
        }.sort{ |a, b|
             a[0] == b[0] \
          ? (a[1] == b[1] \
            ? a[2].to_i <=> b[2].to_i \
            : a[1].to_i <=> b[1].to_i \
          ) : a[0].to_i <=> b[0].to_i   # nil.to_i produces 0
        }[-1] || []).compact * '.'      # drop the nil entries after sorting
        ).choke or raise__no_iphoneos_sdk_found
      arm32_sysroot = arm32_SDKs/"iPhoneOS#{candidate_version}.sdk"
      arm32_configargs = configargs + ["--with-build-sysroot=#{arm32_sysroot}"]
      atr = arm32_toolroot; asr = arm32_sysroot
      arm32_archs =
        `#{atr}/usr/bin/lipo -info #{asr}/usr/lib/libSystem.dylib | cut -d':' -f 3`.split(' ').select{ |e| e =~ %r{^arm} }
      raise CannotInstallFormulaError,
             'Can’t build compilers for 32‐bit ARM (no library slices found).' if arm32_archs == []
    end # build.with? 'arm32'
    src_dir = buildpath/'build/src'
    mkdir_p src_dir
    src_dir.install_symlink Dir.glob("#{buildpath}/*").reject{ |p| p == src_dir.to_s }

    args = case Target.type
        when :powerpc then ppc_configargs
        when :intel   then configargs
      end

    args += [
      "--build=#{build_platform}-apple-darwin#{osmajor}",
      "--prefix=#{prefix}",
      "--libdir=#{lib}/gcc/#{version_suffix}",
      "--datadir=#{pkgshare}",
      "--program-suffix=-#{version_suffix}",  # Make most executables versioned to avoid conflicts.
      "--enable-languages=#{languages * ','}",
      "--with-gmp=#{Formula['gmp'].opt_prefix}",
      "--with-mpfr=#{Formula['mpfr'].opt_prefix}",
      "--with-mpc=#{Formula['libmpc'].opt_prefix}",
      "--with-isl=#{Formula['isl016'].opt_prefix}",
      "--with-bugurl=#{ISSUES_URL}",
      '--enable-checking=yes,fold,extra',  # All but the 4 truly expensive ones.
      '--enable-default-pie',
      '--enable-default-ssp',
      '--enable-host-shared',  # Required for JIT, but a good idea regardless.
      '--disable-libada',
      "--with-pkgversion=Leopardbrew #{name} #{pkg_version} #{build.used_options * ' '}".strip,
      '--enable-target-optspace',
      '--enable-threads',
      '--disable-werror',  # While superenv removes “-Werror”, later bootstrap stages do see it.
    ]
    # Use “bootstrap-debug” build configuration to force stripping of object files prior to
    #   comparison during bootstrap (broken by Xcode 6.3 – Mac OS Mavericks and later).  Also is
    #   supposedly faster, and tests more.  “bootstrap-time” logs tool‐run durations to the build
    #   directory.  “bootstrap-debug-lib” is required by the build‐time unit tests.
    build_config = 'bootstrap-debug'
    build_config += ' bootstrap-time' if DEBUG
    build_config += ' bootstrap-debug-lib' if build.with? 'tests'
    args << "--with-build-config=\"#{build_config}\""
    # The pre-Mavericks toolchain requires the older DWARF-2 debug data format to avoid failure
    #   during the stage 3 comparison of object files.
    # See:  http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45248
    # While superenv removes “-gdwarf-2”, later bootstrap stages do see it.
    args << '--with-dwarf2' if MacOS.version < :mavericks
    args << ((CPU._64b? and build.with? 'multilib') ? '--enable-multilib' : '--disable-multilib')
    args << '--disable-nls' if build.without? :nls
    # “Building GCC with plugin support requires a host that supports -fPIC, -shared, -ldl and -rdynamic.”
    args << '--enable-plugin' if MacOS.version > :leopard
    if build.with?('java')
      args << "--with-ecj-jar=#{Formula['ecj'].opt_share}/java/ecj.jar"
      args << '--enable-libgcj-multifile'
      args << "--with-python-dir=#{HOMEBREW_PREFIX}/lib/python2.7/site-packages"
      args << '--with-x' << '--enable-java-awt=xlib'
      args << '--disable-gtktest' << '--disable-glibtest' << '--disable-libarttest'
    end
    # Xcode-only systems need a sysroot path.  “native-system-header-dir” will be appended.
    unless MacOS::CLT.installed?
      args << '--with-native-system-header-dir=/usr/include'
      args << "--with-sysroot=#{MacOS.sdk_path}"
    end

    arch_args = case Target.type
        when :intel then [ '--with-arch-32=prescott', '--with-arch-64=core2' ]
        when :powerpc
          ["--with-cpu-32=#{Target.model == :g3 ? '750' : '7400'}", '--with-cpu-64=970']
        else [] # no good defaults here for :arm
      end

    mktemp do
      system buildpath/'configure', *args, *arch_args
      system 'make', 'bootstrap'
      ENV.deparallelize { system 'make', 'check' } if build.with? 'tests'
      system 'make', 'install'

#      bin.install_symlink bin/"gfortran-#{version_suffix}" => 'gfortran'
    end # regular compiler

    if build.with? 'cross-compilers'
      # Might as well take advantage of what we just built.
      ENV.cc = bin/"gcc-#{version_suffix}"
      arch_args = [
        "--target=#{arch_word(MacOS.counterpart_arch)}-apple-darwin#{osmajor}",
        '--enable-shared',
      ]
      arch_args += case MacOS.counterpart_type
          when :intel then ['--with-arch-32=prescott', '--with-arch-64=core2']
          when :powerpc then ['--with-cpu-32=7400', '--with-cpu-64=970', '--enable-bootstrap']
          else [] # no good defaults here for :arm
        end
  
      mktemp do
        system buildpath/'configure', *args, *arch_args
        system 'make'
        system 'make', 'install'
      end if build.with? 'cross-compilers'
    end

    # Handle conflicts between GCC formulae.
    # - (Since GCC 4.8 libffi stuff are no longer shipped.)
    # - (Since GCC 4.9 java properties are properly sandboxed.)
    # - Rename man7.
    Dir.glob(man7/'*.7') { |file| add_suffix(file, version_suffix) }
    # - Info:  edit internal menu entries and rename.
    Dir.glob(info/'*.info') do |file|
      inreplace file, nil, nil do |s|
        in_the_zone = false
        s.each_line do |line|
          case in_the_zone
            when false
              in_the_zone = true if line =~ /START-INFO-DIR-ENTRY/
              next
            when true
              break if line =~ /END-INFO-DIR-ENTRY/
              line.sub!(/(\*[^(]+\()(.+)(\))/, "#{$1}#{$2}-#{version_suffix})")
          end # in the zone
        end # |line|
      end # |s|
      add_suffix(file, version_suffix)
    end # |file|
  end # install

  test do
    (testpath/'hello-c.c').write <<-EOS.undent
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    system bin/"gcc-#{version_suffix}", '-o', 'hello-c', 'hello-c.c'
    for_archs('./hello-c') { |_, cmd| assert_equal("Hello, world!\n", `#{cmd * ' '}`) }

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system bin/"g++-#{version_suffix}", '-o', 'hello-cc', 'hello-cc.cc'
    for_archs('./hello-cc') { |_, cmd| assert_equal("Hello, world!\n", `#{cmd * ' '}`) }

    (testpath/'test.f90').write <<-EOS.undent
      integer,parameter::m=10000
      real::a(m), b(m)
      real::fact=0.5

      do concurrent (i=1:m)
        a(i) = a(i) + fact*b(i)
      end do
      write(*,"(A)") "Done"
      end
    EOS
    system bin/"gfortran-#{version_suffix}", '-o', 'test', 'test.f90'
    for_archs('./test') { |_, cmd| assert_equal("Done\n", `#{cmd * ' '}`) }
  end # test
end # Gcc6

__END__
--- old/configure	2024-06-18 20:51:40.000000000 -0700
+++ new/configure	2024-06-18 21:16:30.000000000 -0700
# Fix `configure` oversights that block building Java under ppc64 Darwin.  No specific reference.
@@ -3432,7 +3432,7 @@
     ;;
   powerpc*-*-linux*)
     ;;
-  powerpc-*-darwin*)
+  powerpc*-*-darwin*)
     ;;
   powerpc-*-aix* | rs6000-*-aix*)
     ;;
@@ -3459,7 +3459,7 @@
 
 # Disable Java, libgcj or related libraries for some systems.
 case "${target}" in
-  powerpc-*-darwin*)
+  powerpc*-*-darwin*)
     ;;
   i[3456789]86-*-darwin*)
     ;;
--- old/gcc/jit/Make-lang.in
+++ new/gcc/jit/Make-lang.in
# Fix for libgccjit.so linkage on Darwin.  See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64089
@@ -85,8 +85,7 @@
 	     $(jit_OBJS) libbackend.a libcommon-target.a libcommon.a \
 	     $(CPPLIB) $(LIBDECNUMBER) $(LIBS) $(BACKENDLIBS) \
 	     $(EXTRA_GCC_OBJS) \
-	     -Wl,--version-script=$(srcdir)/jit/libgccjit.map \
-	     -Wl,-soname,$(LIBGCCJIT_SONAME)
+	     -Wl,-install_name,$(LIBGCCJIT_SONAME)
 
 $(LIBGCCJIT_SONAME_SYMLINK): $(LIBGCCJIT_FILENAME)
 	ln -sf $(LIBGCCJIT_FILENAME) $(LIBGCCJIT_SONAME_SYMLINK)
