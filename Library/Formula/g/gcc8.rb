# Stable release 2021-05-14; branch discontinued.
class Gcc8 < Formula
  desc 'GNU compiler collection'
  homepage 'https://gcc.gnu.org'
  url 'https://ftpmirror.gnu.org/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz'
  sha256 'd308841a511bb830a6100397b0042db24ce11f642dab6ea6ee44842e5325ed50'
  revision 1  # For the driver‐driver.

  option :universal
  option 'with-extra-checks', 'Run extra build‐time consistency checks (takes noticeably longer)'
  option 'with-jit', 'Build the just-in-time compiler (slows down the completed GCC)'
  option 'with-tests', 'Run extra build‐time unit tests (depends on {autogen} & {deja-gnu}; very slow)'
  option 'without-cross-compilers', 'Don’t build counterpart compilers that target other architectures'
  # Enabling multilib on a host that can’t run 64‐bit causes build failures.
  option 'without-multilib', 'Build without multilib support' if CPU._64b?
  option 'without-nls', 'Build without Natural Language Support (internationalization)'

  depends_on ArchRequirement.new([:intel, :powerpc])

  # Tiger’s stock as can’t handle the PowerPC assembly found in libitm.  (Don’t specify this as “:cctools”.  The {Requirement} that
  # generates is satisfiable by Xcode or Apple’s CLT without pulling in the actual {cctools}.)
  depends_on 'cctools' => :build if MacOS.version < :leopard
  depends_on :ld64     => :build
  depends_group ['tests', ['autogen', 'deja-gnu'] => [:build, :optional]]

  depends_on 'gmp'
  depends_on 'isl'
  depends_on 'libmpc'
  depends_on 'mpfr'
  # Cannot `depends_on` :nls, as an older Mac OS’ stock compilers cannot handle it.
#  depends_on :nls => :recommended

  # Bug 21514 [DR 488] (templates and anonymous enum) – fixed in 4.0.2.  See (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=21514).
  fails_with [:gcc_4_0, :llvm]

  cxxstdlib_check :skip  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib.

  # The bottles are built on systems with the CLT installed, & cannot “just work” on Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?; MacOS::CLT.installed?; end

  resource 'driver-driver' do
    url 'https://raw.githubusercontent.com/apple-oss-distributions/gcc/refs/tags/gcc-5666.3/driverdriver.c', :using => :nounzip
    sha256 '9c41f0c5e6f30851307671a2223e81a661c0b7113225ad8d0c6e2c6b0036169a'
  end

  def install
    def add_suffix(file, suffix)
      dir = File.dirname(file)
      ext = File.extname(file)
      base = File.basename(file, ext)
      File.rename file, "#{dir}/#{base}-#{suffix}#{ext}"
    end # add_suffix

    def arch_word(this_arch)
      case this_arch
        when :arm64, :arm64e   then :aarch64
        when %r{^arm(?!64$)}   then :arm
        when :i386             then :i686
        when :ppc              then :powerpc
        when :ppc64            then :powerpc64
        when :x86_64, :x86_64h then :x86_64
      end
    end # arch_word

    def arch_unword(this_word)
      case this_word
        when :aarch64   then :arm64
        when :arm       then :arm
        when :i686      then :i386
        when :powerpc   then :ppc
        when :powerpc64 then :ppc64
        when :x86_64    then :x86_64
      end
    end # arch_unword

    def arch_config_args(t)
      case CPU.type_of(arch_unword(t))
        when :intel   then ['--with-arch-32=prescott', '--with-arch-64=core2']
        when :powerpc then ["--with-cpu-32=#{Target.model == :g3 ? '750' : '7400'}", '--with-cpu-64=970']
        else []  # No good defaults for arm, and no defaults at all for aarch64.
      end
    end # arch_config_args

    ENV.single_arch_binary if build.universal?  # Even if we’re building fat, the build‐platform‐hosted compiler is single-arch.
    ENV.deparallelize if DEBUG

    _build_ = arch_word(Target.preferred_arch)  # We always build on our native architecture.
    # If we’re building a bottle, its architecture will be the only thing in _hosts_.
    _hosts_ = (build.cross?        ? Target.cross_archs \
                : build.universal? ? Target.local_archs \
                                   : [Target.arch]
              ).map{ |a| arch_word(a) }
    # We only don’t build for all possible targets if explicitly commanded not to.
    _targets_ = (build.with?('cross-compilers') ? Target.cross_archs \
                  : build.fat?                  ? CPU.native_archs \
                                                : Target.preferred_arch_as_list).map{ |a| arch_word(a) }
    _unique_ = (_hosts_ + _targets_).uniq
    if CPU._64b? and build.with? 'multilib'
      _targets_ = _targets_.reject{ |a| (a == :powerpc and _targets_.include? :powerpc64) \
                                     or (a == :i686    and _targets_.include? :x86_64)      }
      _unique_  = _unique_.reject { |a| (a == :powerpc and _unique_.includes? :powerpc64) \
                                     or (a == :i686    and _unique_.includes? :x86_64)      }
    end

    # GCC Bug 25127 for PowerPC (https://gcc.gnu.org/bugzilla//show_bug.cgi?id=25127)
    # ../../../libgcc/unwind.inc: In function '_Unwind_RaiseException':
    # ../../../libgcc/unwind.inc:136:1: internal compiler error: in rs6000_emit_prologue, at config/rs6000/rs6000.c:26535
    # GCC 7 fails to install on 10.6 x86_64 at stage3 (https://github.com/mistydemeo/tigerbrew/issues/554)
    ENV.no_optimization

    cctools_bin = MacOS.version < :leopard ? Formula['cctools'].bin : '/usr/bin'
    ld_binary = "#{MacOS.version < :snow_leopard ? Formula['ld64'].bin : '/usr/bin'}/ld"
    gnuple = "-apple-darwin#{`uname -r`.match(/^(\d+)\./)[1]}"
    version_suffix = version.to_s.slice(/\d\d?/)

    # Prevent libstdc++ being mis‐tagged with CPU subtype 10 (G4e).  See (https://github.com/mistydemeo/tigerbrew/issues/538).
    # Note that we won’t have :gcc_4_0 or :llvm, as they are fails_with.
    ENV.append_to_cflags '-force_cpusubtype_ALL' if Target.model == :g3 and ENV.compiler == :gcc

    ENV['AS'] = ENV['AS_FOR_TARGET'] = "#{cctools_bin}/as"  # See the note at the conditional cctools dependency above.
    ENV['POSTSTAGE1_LDFLAGS'] = '-undefined dynamic_lookup'

    # Ensure correct install names in linking against libgcc_s; see discussion in (https://github.com/Homebrew/homebrew/pull/34303).
    inreplace 'libgcc/config/t-slibgcc-darwin', '@shlib_slibdir@', "#{HOMEBREW_PREFIX}/lib/gcc/#{version_suffix}"

    build_dir = buildpath/'build'; src_dir = build_dir/'src'; mkdir_p src_dir
    src_dir.install_symlink_to Dir.glob("#{buildpath}/*").reject{ |p| p == build_dir.to_s }

    # Build the C/C++, ꜰᴏʀᴛʀᴀɴ, & Objective‐C/C++ compilers.  There’s no way to bootstrap Ada; HSAIL BRIG isn’t used anywhere we’ve
    # ever heard of; and while Go has nominally been available since GCC 4.6.0, it has never worked on any Darwin – see
    # (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46986).  Just‐In‐Time compilation is possible, but incurs a performance cost at
    # compiler run time, so we make it optional.
    languages = %w[c c++ fortran objc obj-c++]
    languages << 'jit' if build.with? 'jit'

    # Each “bootstrap-xxx” build “configuration” merely names a Makefile fragment for inclusion when bootstrapping.  “-debug” tests
    # more lightly (working around breakage with Xcode 6.3, on Mac OS Mavericks and later).  “-debug-big” & “-debug-lib” add points
    # of comparison.  “-time” simply logs tool‐run durations to the build directory.
    # We can’t use “-asan” or “-ubsan” (which pull in the Address and Undefined‐Behaviour Sanitizers), because Google’s libsanitize
    # won’t necessarily support our configuration.  (Whether it chokes on all ancient versions of Mac OS, or merely PowerPC systems,
    # is unclear.)  Also, as discussed above, there is no way to use GCC’s native LTO.
    build_config = ['bootstrap-debug']
    build_config += %w[ bootstrap-debug-big bootstrap-debug-lib ] if build.with? 'extra-checks'
    build_config << 'bootstrap-time' if DEBUG

    build_config_args = [
        "--host=#{_build_}#{gnuple}",
        "--target=#{_build_}#{gnuple}",
        "--prefix=#{prefix}",
        "--with-build-config=#{build_config * ' '}",
        "--with-gxx-include-dir=#{lib}/c++/#{version_suffix}.0.0",
        '--enable-stage1-checking=yes',  # This is the default if we hadn’t specified a value for “checking” below.
      ]
    build_config_args << '--enable-serial-configure' if DEBUG

    config_args = [
        "--build=#{_build_}#{gnuple}",
        "--libdir=${prefix}/lib/gcc/#{version_suffix}",
        "--datadir=${datarootdir}/gcc#{version_suffix}",
        "--program-suffix=-#{version_suffix}",  # Make most executables versioned to avoid conflicts.
        "--with-gmp=#{Formula['gmp'].opt_prefix}",
        "--with-isl=#{Formula['isl'].opt_prefix}",
        "--with-mpc=#{Formula['libmpc'].opt_prefix}",
        "--with-mpfr=#{Formula['mpfr'].opt_prefix}",
        "--with-bugurl=#{ISSUES_URL}",
        "--enable-checking=#{build.with?('extra-checks') ? 'all' : 'release'}",  # Everything but Valgrind, or else just normal.
        '--disable-compressed-debug-sections',
        '--enable-decimal-float',
        '--enable-default-pie',
        '--enable-default-ssp',
        '--with-diagnostics-color=always',
        '--enable-host-shared',  # Required for JIT, but a good idea regardless.
        "--enable-languages=#{languages * ','}",
        '--enable-libatomic',
        '--enable-libssp',
        '--disable-lto',
        "--with-pkgversion=Leopardbrew #{name} #{pkg_version}#{" (with #{build.used_options.list})" unless build.used_options.empty?}",
        '--with-system-zlib',
        '--enable-target-optspace',
        '--enable-threads',
        '--enable-version-specific-runtime-libs',  # Allow different GCC versions to coëxist.
      ]
    # Otherwise make fails during comparison at stage 3.  See (http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45248).
    # (While superenv removes “-gdwarf-2”, later bootstrap stages do see it.)
    config_args << '--with-dwarf2' if MacOS.version < :mavericks
    config_args << ((CPU._64b? and build.with? 'multilib') ? '--enable-multilib' : '--disable-multilib')
    config_args << (build.with?('nls') ? '--with-included-gettext' : '--disable-nls')
    # “Building GCC with plugin support requires a host that supports -fPIC, -shared, -ldl and -rdynamic.”
    config_args << '--enable-plugin' if MacOS.version > :leopard
    unless MacOS::CLT.installed?
      # Xcode-only systems need a sysroot path.  Also, “native-system-header-dir” will be appended.
      config_args << "--with-sysroot=#{MacOS.sdk_path}"
      config_args << '--with-native-system-header-dir=/usr/include'
    end

    current_obj = build_dir/"obj-#{_build_}-#{_build_}"
    current_dst = build_dir/"dst-#{_build_}-#{_build_}"
    mkdir_p [current_obj, current_dst]
    cd current_obj do
      system src_dir/'configure', *build_config_args, *config_args, *arch_config_args(_build_),
        '--disable-werror'  # While superenv removes “-Werror”, later bootstrap stages do see it.
      system 'make', (build.with?('profiling') ? 'profiledbootstrap' : 'bootstrap')
      ENV.deparallelize { system 'make', 'check' } if build.with? 'tests'
      system 'make', 'html', 'info'
      system 'make', "prefix=#{current_dst}", 'install-gcc', 'install-target'  # This is… possibly still correct?
    end # native compiler
    ENV.remove_from_cflags '-force_cpusubtype_ALL'  # Undo build‐specific $CFLAGS.

    ENV.without_archflags  # The post‐bootstrap build process doesn’t use archflags.

    unless _unique_ == [_build_]
      # Take advantage of what we just built.
      cd current_dst/'bin' do
        ln "gcc-#{version_suffix}", 'gcc'
        ln 'gcc', "#{_build_}#{gnuple}-gcc"
        ENV.prepend_path 'PATH', pwd
      end # Add the native compiler to $PATH.
      ENV.delete_multiple(%w[CC CXX OBJC OBJCXX])

      # We don’t need these any more, as we are preparing substitutes.
      ENV.delete_multiple %w[AS AS_FOR_TARGET] if MacOS.version < :leopard

      # Set up specially-named utility programs (actually wrapper shims).  “The cross‐tools’ build process expects to find specific
      # programs under names like ‘i686-apple-darwin#{darwin_major}-ar’ – so make them.  Annoyingly, `ranlib` changes its behaviour
      # depending on what you call it, so we have to use shell scripts for indirection.”
      mkdir build_dir/'bin' do
        %w[ar nm ranlib strip lipo].each do |prg|
          _unique_.each do |t|
            (fname = "#{t}#{gnuple}-#{prg}").atomic_write <<-_.undent
                #!/bin/sh
                exec #{cctools_bin}/#{prg} "$@"
              _
            chmod 'a+x', fname
          end # each unique arch |t|
        end # each cctool |prg|
        _unique_.each do |t|
          (fname = "#{t}#{gnuple}-ld").atomic_write <<-_.undent
              #!/bin/sh
              exec #{ld_binary} "$@"
            _
          chmod 'a+x', fname
          (fname = "#{t}#{gnuple}-as").atomic_write <<-_.undent
              #!/bin/sh
              dt=#{arch_unword(t)}
              temp_file=''
              prev_was_arch=false; prev_was_o=false
              args=()
              for a; do
                if [ $prev_was_arch != false ]; then case $a in
                    -*) echo "as:  Unrecognized architecture “$a”"; exit 1;;
                    *) prev_was_arch=false; dt="$(echo $a | sed -e s/powerpc/ppc/g -e s/i686/i386/ -e s/aarch64/arm64/)";;
                  esac
                elif [ $prev_was_o != false ]; then prev_was_o=false; args[${#args[@]}]="$a"
                else case $a in
                    -arch) prev_was_arch=true;;
                    -o) prev_was_o=true; args[${#args[@]}]="$a";;
                    -*) args[${#args[@]}]="$a";;
                    *) temp_file=$a
                      dot_machine="$(cat "$temp_file" | egrep -o '[^0-9A-Z_a-z]\\.machine[[:blank:]]+[a-z][0-9_a-z]*')"
                      if [ "x$dot_machine" != "x" ]; then
                        case $dot_machine in
                          *ppc64)    dt=ppc64 ;;
                          *ppc*)     dt=ppc   ;;
                          *i[3-9]86) dt=i386  ;;
                          *x86_64*)  dt=x86_64;;
                          *arm64*)   dt=arm64 ;;
                          *arm*)     dt=arm   ;;
                          *) echo 'as:  Unrecognized machine type'; exit 1;;
                        esac
                      fi;;
                  esac
                fi
              done
              exec cat $temp_file | #{cctools_bin}/as -arch $dt "${args[@]}"
            _
          chmod 'a+x', fname
        end # each unique arch |t|
        ENV.prepend_path 'PATH', pwd  # Add the directory containing all of these to $PATH.
      end # build cctools shim wrappers

      _unique_.each do |t|
        next if t == _build_
        current_obj = build_dir/"obj-#{_build_}-#{t}"
        current_dst = build_dir/"dst-#{_build_}-#{t}"
        mkdir_p [current_obj, current_dst]
        ENV['AS'] = build_dir/"bin/#{t}#{gnuple}-as"
        target_config_args = [
            "--host=#{_build_}#{gnuple}",
            "--target=#{t}#{gnuple}",
            "--program-prefix=#{t}#{gnuple}-",
            '--enable-werror-always',
          ]
        cd current_obj do
          system src_dir/'configure', *config_args, *arch_config_args(t), *target_config_args
          system 'make', 'all'
          system 'make', "prefix=#{current_dst}", 'install-gcc', 'install-target'

          ENV.prepend_path 'PATH', current_dst/'bin'  # Add the compiler we just built to $PATH.
        end # build cross compilers
      end # each unique arch |t|
    end # build anything besides _build_?

    # In Apple’s words, “Rearrange various libraries, for no really good reason.”
    _unique_.each do |t|
      t_libs = build_dir/"dst-#{_build_}-#{t}/lib/gcc/#{t}#{gnuple}/#{version}"
      mv t_libs/'static/libgcc.a', t_libs/'libgcc_static.a'
      mv t_libs/'kext/libgcc.a', t_libs/'libcc_kext.a'
      (t_libs/'static').rmtree; (t_libs/'kext').rmtree
      # glue together kext64 stuff
      if (t_libs/'kext64/libgcc.a').exists?
        raise RuntimeError, "the #{_build_}-#{t} kext library contains no symbols" \
          unless Utils.popen_read(MacOS.libtool, '-static', *Dir["#{t_libs}/{kext64/libgcc,libcc_kext}.a"],
                                                            '-o', "#{t_libs}/libcc_kext1.a", '2>&1'
                                 ).split("\n").any?{ |line| line !~ %r{has no symbols} }
        mv t_libs/'libcc_kext1.a', t_libs/'libcc_kext.a', :force => true
        (t_libs/'kext64').rmtree
      end
    end # rearrange libraries

    unless _hosts_ == [_build_]
      _hosts_.each do |h|
        next if h == _build_
        _unique_.each do |t|
          current_obj = build_dir/"obj-#{h}-#{t}"
          current_dst = build_dir/"dst-#{h}-#{t}"
          mkdir_p [current_obj, current_dst]
          ENV['AS'] = build_dir/"bin/#{t}#{gnuple}-as"
          target_config_args = [
              "--host=#{h}#{gnuple}",
              "--target=#{t}#{gnuple}",
              "--program-prefix=#{h == t ? '' : "#{t}#{gnuple}-"}",
            ]
          cd current_obj do
            system src_dir/'configure', *config_args, *arch_config_args(t), *target_config_args
            if h == t
              system 'make', 'all'
              system 'make', "prefix='#{current_dst}'", 'install-gcc', 'install-target'
            else
              system 'make', 'all-gcc'
              system 'make', "prefix='#{current_dst}'", 'install-gcc'
            end
          end
        end # each unique architecture |t|
      end # each host platform |h|
    end # build with cross‐hosting?

    # Actually install all the stuff we just built.
    doc.install Dir["#{build_dir}/obj-#{_build_}-#{_build_}/gcc/HTML/*"]
    info.install Dir["#{build_dir}/obj-#{_build_}-#{_build_}/share/info/*"]
  # manpages
    share.install build_dir/"obj-#{_build_}-#{_build_}/share/man"
    man1.install_symlink_to "g++-#{version_suffix}.1" => "c++-#{version_suffix}.1"
    _targets_.each{ |t| ['cpp', 'gcc', 'g++'].each{ |prg|
      man1.install_symlink_to "#{prg}-#{version_suffix}.1" => "#{t}#{gnuple}-#{prg}-#{version}.1"
    } }
  # libexec
    _targets_.each do |t|
      libexec_offset = "libexec/gcc/#{t}#{gnuple}/#{version}"
      (built_root = build_dir/"dst-#{_build_}-#{_build_}/libexec/gcc/#{_build_}#{gnuple}/#{version}").find do |pn|
        pn_offset = pn.to_s.sub(%r{^#{Regexp.escape built_root}/}, '')
        if pn.directory? then (prefix/libexec_offset/pn_offset).mkpath
        elsif pn.file?
          if Utils.popen_read('file', pn.to_s) =~ %r{Mach-O executable}
            if (slices = Dir["#{build_dir}/dst-*-#{t}#{libexec_offset}/#{pn_offset}"]).length > 1
              system MacOS.lipo, '-create', *slices, '-output', prefix/libexec_offset/pn_offset
            else cp slices[0], prefix/libexec_offset/pn_offset; end
          else
            parent_dir = (prefix/libexec_offset/pn_offset).parent
            parent_dir.install build_dir/"dst-#{_build_}-#{t}/#{libexec_offset}/#{pn_offset}"
          end
        end
      end # find |pn| within built_root
      (prefix/libexec_offset).install_symlink_to "#{cctools_bin}/as"
    end # each libexec target |t|
  # bin
    # The native drivers, which vary between host architectures.
    Dir["#{build_dir}/dst-#{_build_}-#{_build_}/bin/*"].map(&:File.basename).select{ |f|
      f =~ %r{^[^-]+-[0-9.]+$} }.reject{ |f| f =~ %r{gccbug} or f =~ %r{gcov} }.each{ |f|
        if (slices = Dir["#{build_dir}/dst-*/bin/#{f}"]).length > 1
          system MacOS.lipo, '-output', bin/f, '-create', *slices
        else cp slices[0], bin/f; end
      } if _targets_.include? _build_
    # gcov, which needs special treatment because it gets built more times.
    if (slices = Dir["#{build_dir}/dst-*-#{_targets_.first}/bin/*gcov*"]).length > 1
      system MacOS.lipo, '-output', bin/"gcov-#{version_suffix}", '-create', *slices
    else cp slices[0], bin/"gcov-#{version_suffix}"; end
    # The fully‐named drivers, which have the same target on every host.
    _targets_.each{ |t| ['cpp', 'gcc', 'g++'].each{ |prg|
        if (slices = Dir["#{build_dir}/dst-*-#{t}/bin/#{t}#{gnuple}-#{prg}-#{version}"]).length > 1
          system MacOS.lipo, '-output', bin/"#{t}#{gnuple}-#{prg}-#{version}", '-create', *slices
        else cp slices[0], bin/"#{t}#{gnuple}-#{prg}-#{version}"; end
    } }
  # lib
    _targets_.each{ |t| (lib/'gcc').install build_dir/"dst-#{_build_}-#{t}/lib/gcc/#{t}#{gnuple}" }
    Dir["#{build_dir}/obj-#{_build_}-#{_build_}/gcc/libgcc_s.*.dylib"].reject{ |f| File.symlink? f }.map(&:File.basename).each do |dylib|
      if (slices = Dir["#{build_dir}/obj-#{_build_}-*/gcc/#{dylib}"]).length > 1
        system MacOS.lipo, '-output', lib/dylib, '-create', *slices
      else cp slices[0], lib/dylib; end
    end
    %w[libgcc_s.1.0.dylib libgcc_s_ppc64.1.dylib libgcc_s_x86_64.1.dylib].each{ |link|
      lib.install_symlink_to 'libgcc_s.1.dylib' => link
    }
    _targets_.each do |t|
      cp '/usr/lib/libstdc++.6.dylib', (fn = lib/"gcc/#{t}#{gnuple}/#{version}/libstdc++.dylib"), :preserve => true
      system MacOS.locate('strip'), '-x', '-c', fn
    end
  # include
    hdr_dir = include/"gcc/darwin/#{version_suffix}"
    # “Some headers are installed from more-hdrs/.  They all share one common feature: they shouldn't be installed here.  Sometimes,
    # they [...] should be installed by some completely different package; sometimes, they only exist for CodeWarrior compatibility,
    # and CodeWarrior should provide its own.  We take care not to install the headers if Libc is already providing them.”  So says
    # Apple’s build_gcc script from their version of GCC 4.2.
    Dir["#{src_dir}/more-hdrs/*.h"].each do |hdr|
      h = hdr.basename
      sys_hdr = Pathname.new "/usr/include/#{h}"
      if not sys_hdr.exists? or sys_hdr.symlink?
        cp_r hdr, hdr_dir/h
        _unique_.each do |t|
          t_hdr_dir = lib/"gcc/#{t}#{gnuple}/#{version}/include"
          t_hdr_dir.install_symlink_to include/"gcc/darwin/#{version_suffix}/#{h}" unless (t_hdr_dir/h).exists?
        end
      end # sys_hdr not a regular file?
    end # each more-headers |hdr|

    # Build the driver‐driver, using the named drivers.
    resource('driver-driver').unpack buildpath
    %w[cpp gcc g++ gfortran].each do |prg|
      _hosts_.each do |h|
        mkpath "#{build_dir}/obj-#{h}-#{h}/driver-driver"
        # Why is libiberty for $HOST targeting $BUILD used here, with each other library the other way around?  Shouldn’t _all_ the
        # used libraries be both for and targeting $HOST?  Surely, anything else should only work because each variant has the same
        # symbols?  I have changed it to use the double‐$HOST pathnames; we shall see what results.
        system build_dir/"dst-#{_build_}-#{h}/bin/#{h}#{gnuple}-gcc-#{version}", buildpath/'driverdriver.c',
               "-DPDN=\"#{gnuple}-#{prg}-#{version}\"", "-DIL=\"/bin/\"",
               "-I#{buildpath}/include", "-I#{buildpath}/gcc", "-I#{buildpath}/gcc/config",
               "-L#{build_dir}/dst-#{h}-#{h}/lib/", "-L#{build_dir}/dst-#{h}-#{h}/#{h}#{gnuple}/lib/",
               "-L#{build_dir}/obj-#{h}-#{h}/libiberty/", '-liberty',
               '-o', build_dir/"obj-#{h}-#{h}/driver-driver/#{prg}-#{version_suffix}"
      end # each host architecture |h|
      if (slices = Dir["#{build_dir}/obj-*/driver-driver/#{prg}-#{version_suffix}"]).length > 1
        system MacOS.lipo, '-output', bin/"#{prg}-#{version_suffix}", '-create', *slices
      else cp slices[0], bin/"#{prg}-#{version_suffix}"; end
    end # each |prg|
    bin.install_symlink_to bin/"g++-#{version_suffix}" => "c++-#{version_suffix}"
    rm_f Dir["#{lib}/gcc/*/*/include/c++"]

    # Strip specific generated binaries.
    prefix.find do |pn|
      next unless pn.file? and (pn.stat & 0777 == 0111)
      next if %w[fixinc.sh libstdc++.dylib mkheaders].include?(pn.basename.to_s)
      if pn.symlink? or not pn.to_s.starts_with?(prefix.to_s) then Find.prune; next; end
      system MacOS.locate('strip'), pn
    end
    prefix.find do |pn|
      if pn.to_s.ends_with?('.a')
        system MacOS.locate('strip'), pn, '-SX'
        system MacOS.libtool, '-static', pn
      elsif pn.to_s.ends_with?('.dSYM') then pn.unlink
      else next; end
    end

    # Handle conflicts between GCC formulæ & avoid interfering with system compilers.
    # - Rename man7.
    Dir.glob(man7/'*.7') { |file| add_suffix(file, version_suffix) }
    # - Info:  edit internal menu entries and rename.
    Dir.glob(info/'*.info') do |file|
      inreplace file, nil, nil do |s|
        in_the_zone = false
        s.each_line do |line|
          case in_the_zone
            when false then in_the_zone = true if line =~ /START-INFO-DIR-ENTRY/
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
        GCC has been built with multilib support.  Notably, OpenMP may not work:
        See ⟨https://gcc.gnu.org/bugzilla/show_bug.cgi?id=60670⟩.
        If you need OpenMP support you may want to
            brew reinstall gcc --without-multilib
      EOS
    end
  end # caveats

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
    for_archs('./hello-c') { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system bin/"g++-#{version_suffix}", '-o', 'hello-cc', 'hello-cc.cc'
    for_archs('./hello-cc') { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }

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
    for_archs('./test') { |_, cmd| assert_equal("Done\n", Utils.popen_read(*cmd)) }
  end # test
end # Gcc8
