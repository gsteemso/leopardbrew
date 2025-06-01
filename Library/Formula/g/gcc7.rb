class Gcc7 < Formula
  desc 'GNU compiler collection'
  homepage 'https://gcc.gnu.org'
  url 'http://ftpmirror.gnu.org/gcc/gcc-7.5.0/gcc-7.5.0.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/gcc/gcc-7.5.0/gcc-7.5.0.tar.xz'
  sha256 'b81946e7f01f90528a1f7352ab08cc602b9ccc05d4e44da4bd501c5a189ee661'

  option 'with-jit', 'Build the just-in-time compiler (slows down the completed GCC)'
  option 'with-profiling', 'Build the compiler for optimized performance (takes longer)'
  option 'with-tests', 'Run build‐time self‐tests (depends on autogen & deja-gnu; very slow)'
  option 'without-cross-compiler', 'Don’t build the complementary compiler for building fat binaries'
  # Enabling multilib on a host that can’t run 64‐bit causes build failures.
  option 'without-multilib', 'Build without multilib support' if MacOS.prefer_64_bit?
  option 'without-nls', 'Build without native‐language support (localization)'

  # Tiger’s stock as can’t handle the PowerPC assembly found in libitm.
  depends_on :cctools => :build if MacOS.version < '10.5'
  depends_group ['tests', ['autogen', 'deja-gnu']] => [:build, :optional]

  depends_on :ld64 if MacOS.version < '10.6'
  depends_on 'gmp'
  depends_on 'libmpc'
  depends_on 'mpfr'
  depends_on 'isl016'
  depends_on :nls => :recommended

  # The bottles are built on systems with the CLT installed, and do not work
  # out of the box on Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?; MacOS::CLT.installed?; end

  # Bug 21514 [DR 488] (templates and anonymous enum) – fixed in 4.0.2.
  # See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=21514
  fails_with :gcc_4_0
  fails_with :llvm

  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib.
  cxxstdlib_check :skip

  # gcc/jit/Make-lang.in:
  # - Fix for libgccjit.so linkage on Darwin.
  #   See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64089
  patch :DATA

  # Fix an Intel-only build failure on 10.4.
  # See:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64184
  patch do
    url 'https://gist.githubusercontent.com/mistydemeo/9c5b8dadd892ba3197a9cb431295cc83/raw/582d1ba135511272f7262f51a3f83c9099cd891d/sysdep-unix-tiger-intel.patch'
    sha256 '17afaf7daec1dd207cb8d06a7e026332637b11e83c3ad552b4cd32827f16c1d8'
  end if MacOS.version < '10.5' && Hardware::CPU.intel?

  def install
    def add_suffix(file, suffix)
      dir = File.dirname(file)
      ext = File.extname(file)
      base = File.basename(file, ext)
      File.rename file, "#{dir}/#{base}-#{suffix}#{ext}"
    end # add_suffix

    def arch_word(this_arch)
      case this_arch
        when :i386   then 'i686'
        when :ppc    then 'powerpc'
        when :ppc64  then 'powerpc64'
        when :x86_64 then 'x86_64'
      end
    end # arch_word

    def osmajor; `uname -r`[/^\d+(?=\.)/]; end

    def version_suffix; version.to_s[/\d\d?/]; end

    # Ensure correct install names when linking against libgcc_s;
    # see discussion in https://github.com/Homebrew/homebrew/pull/34303
    inreplace 'libgcc/config/t-slibgcc-darwin', '@shlib_slibdir@',
                                                "#{opt_lib}/gcc/#{version_suffix}"

    # See the note at the conditional cctools dependency above.
    ENV['AS'] = ENV['AS_FOR_TARGET'] = Formula['cctools'].bin/'as' if MacOS.version < '10.5'

    # Prevent libstdc++ being incorrectly tagged with CPU subtype 10 (G4e).
    # See:  https://github.com/mistydemeo/tigerbrew/issues/538
    # Note that we won’t have :gcc_4_0 or :llvm, as they are fails_with.
    # Getting a :g3 build target is still possible in multiple ways though.
    ENV.append_to_cflags '-force_cpusubtype_ALL' \
      if ENV.compiler == :gcc and CPU.model == :g3 or CPU.bottle_target_model == :g3

    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete 'LD'

    # Build the C/C++, FORTRAN, & Objective‐C/C++ compilers.  There’s no way to
    # bootstrap Ada, HSAIL BRIG is so niche as to be a waste of time to build,
    # and while Go has nominally been available since GCC 4.6.0, it has never
    # worked on Darwin:  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46986
    languages = %w[c c++ fortran objc obj-c++]
    # The JIT compiler is not built by default because it incurs a performance
    # penalty in the compiler.
    languages << 'jit' if build.with? 'jit'

    args = [
      "--build=#{arch_word(MacOS.preferred_arch)}-apple-darwin#{osmajor}",
      "--prefix=#{prefix}",
      "--libdir=#{lib}/gcc/#{version_suffix}",
      # Version the executables to avoid conflicts.
      "--program-suffix=-#{version_suffix}",
      "--enable-languages=#{languages * ','}",
      "--with-gmp=#{Formula['gmp'].opt_prefix}",
      "--with-isl=#{Formula['isl016'].opt_prefix}",
      "--with-mpc=#{Formula['libmpc'].opt_prefix}",
      "--with-mpfr=#{Formula['mpfr'].opt_prefix}",
      '--with-boot-ldflags=-dynamic -dynamic-libstdc++ -dynamic-libgcc',
      '--enable-checking=yes,fold,extra',  # All but the 4 truly expensive ones.
      '--enable-decimal-float',
      '--enable-default-pie',
      '--enable-default-ssp',
      '--with-diagnostics-color=always',
      '--disable-libada',
      "--with-pkgversion=Leopardbrew #{name} #{pkg_version} #{build.used_options * ' '}".strip,
      '--enable-shared',  # Is supposedly the default anyway.
      '--with-stage1-ldflags=-dynamic -dynamic-libstdc++ -dynamic-libgcc',
	  '--with-system-zlib',
      '--enable-tls',
      # Allow different GCC versions to coëxist.
      '--enable-version-specific-runtime-libs',
    ]

    # The pre-Mavericks toolchain requires the older DWARF-2 debug data format
    # to avoid failure during the stage 3 comparison of object files.
    # See: http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45248
    # Note that “-gdwarf-2” is removed by superenv anyway.
    args << '--with-dwarf2' if MacOS.version < '10.9'

    # “This option is required when building the libgccjit.so library.”
    args << '--enable-host-shared' if build.with? 'jit'

    args << '--disable-multilib' if build.without? 'multilib'

    args << '--disable-nls' if build.without? 'nls'

    # “Building GCC with plugin support requires a host that supports -fPIC,
    # -shared, -ldl and -rdynamic.”
#    args << '--enable-plugin' if MacOS.version > '10.5'

    # Xcode-only systems need a sysroot path.  “native-system-header-dir” will
    # be appended.
    unless MacOS::CLT.installed?
      args << '--with-native-system-header-dir=/usr/include'
      args << "--with-sysroot=#{MacOS.sdk_path}"
    end

    arch_args = case CPU.type
        when :intel then ['--with-arch-32=prescott', '--with-arch-64=core2']
        when :powerpc then ["--with-cpu-32=7#{CPU.model == :g3 ? '5' : '40'}0", '--with-cpu-64=970']
        else [] # no good defaults here for :arm
      end

	ENV['BOOT_CFLAGS'] = '-g -Os'

#    ENV.append ['BOOT_CFLAGS', 'HOMEBREW_FORCE_FLAGS'], '-mlongcall' if CPU.type == :powerpc

	ENV['BUILD_CONFIG'] = 'bootstrap-debug bootstrap-lto-noplugin'

	ENV['POSTSTAGE1_LDFLAGS'] = '-undefined dynamic_lookup'

    ENV.deparallelize
    mktemp do
      system buildpath/'configure', *args, *arch_args
      system 'make', (build.with?('profiling') ? 'profiledbootstrap' : 'bootstrap')
      ENV.deparallelize { system 'make', 'check' } if build.with? 'tests'
      system 'make', 'install'

      bin.install_symlink bin/"gfortran-#{version_suffix}" => 'gfortran'
    end # regular compiler

    if build.with? 'cross-compiler'
      # Might as well take advantage of what we just built.
      ENV.cc = bin/"gcc-#{version_suffix}"
      arch_args = ["--target=#{arch_word(MacOS.counterpart_arch)}-apple-darwin#{osmajor}"]
      arch_args += case MacOS.counterpart_type
          when :intel then ['--with-arch-32=prescott', '--with-arch-64=core2']
          when :powerpc then ['--with-cpu-32=7400', '--with-cpu-64=970', '--enable-bootstrap']
          else [] # no good defaults here for :arm
        end

      mktemp do
        system buildpath/'configure', *args, *arch_args
        system 'make'
        system 'make', 'install'
      end
    end # cross‐compiler

    # Handle conflicts between GCC formulae.
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

  def caveats
    if build.with?('multilib') then <<-EOS.undent
        GCC has been built with multilib support. Notably, OpenMP may not work:
        See ⟨https://gcc.gnu.org/bugzilla/show_bug.cgi?id=60670⟩.
        If you need OpenMP support you may want to
            brew reinstall gcc --without-multilib
      EOS
    end
  end

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
    for_archs './hello-c' { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system bin/"g++-#{version_suffix}", '-o', 'hello-cc', 'hello-cc.cc'
    for_archs './hello-cc' { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }

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
    for_archs './test' { |_, cmd| assert_equal("Done\n", Utils.popen_read(*cmd)) }
  end # test
end # Gcc7

__END__
--- old/gcc/jit/Make-lang.in
+++ new/gcc/jit/Make-lang.in
@@ -85,8 +85,7 @@
 	     $(jit_OBJS) libbackend.a libcommon-target.a libcommon.a \
 	     $(CPPLIB) $(LIBDECNUMBER) $(LIBS) $(BACKENDLIBS) \
 	     $(EXTRA_GCC_OBJS) \
-	     -Wl,--version-script=$(srcdir)/jit/libgccjit.map \
-	     -Wl,-soname,$(LIBGCCJIT_SONAME)
+	     -Wl,-install_name,$(LIBGCCJIT_SONAME)
 
 $(LIBGCCJIT_SONAME_SYMLINK): $(LIBGCCJIT_FILENAME)
 	ln -sf $(LIBGCCJIT_FILENAME) $(LIBGCCJIT_SONAME_SYMLINK)
