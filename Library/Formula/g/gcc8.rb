# Stable release 2021-05-14; branch discontinued.
class Gcc8 < Formula
  desc 'GNU compiler collection'
  homepage 'https://gcc.gnu.org'
  url 'https://ftpmirror.gnu.org/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz'
  sha256 'd308841a511bb830a6100397b0042db24ce11f642dab6ea6ee44842e5325ed50'
  revision 1  # For the driver‐driver.

  option :universal
  option 'with-jit', 'Build the just-in-time compiler (the completed GCC will run slower)'
  option 'with-tests', 'Run extra build‐time unit tests (depends on {autogen} & {deja-gnu}; very slow)'
  option 'without-cross-compilers', 'Don’t build counterpart compilers that target other architectures'
  option 'without-nls', 'Build without Natural Language Support (internationalization)'

  depends_on ArchRequirement => [:intel, :powerpc]

  # Tiger’s stock as can’t handle the PowerPC assembly found in libitm.  (Do not use “:cctools” – the {Requirement} it generates is
  # satisfiable by Xcode or by Apple’s CLT without ever pulling in the actual {cctools}.)
  depends_on 'cctools' => :build if MacOS.version < :leopard
  depends_on :ld64     => :build if MacOS.version < :lion
  depends_group ['tests', ['autogen', 'deja-gnu'] => [:build, :optional]]

  depends_on 'gmp'
  depends_on 'isl'
  depends_on 'libmpc'
  depends_on 'mpfr'

  enhanced_by 'texinfo'  # Making the docs with not‐obsolete tools seems like a good idea, especially since Leopard’s stock version
                         # of `makeinfo` is so old, it doesn’t recognize UTF-8 as an encoding name.  It still _runs_, but generates
                         # moderately flawed output.

  # Bug 21514 [DR 488] (templates and anonymous enum) – fixed in 4.0.2.  See (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=21514).
  fails_with [:gcc_4_0, :llvm]

  cxxstdlib_check :skip  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib.

  # The bottles are built on systems with the CLT installed, & cannot “just work” on Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?; MacOS::CLT.installed?; end

  resource 'driver-driver' do url "file://#{HOMEBREW_CONTRIB}/gcc-driverdriver.c"; end

  patch :DATA  # Annotated inline.

  def version_major; @v_m ||= version.to_s.slice(/\d+/); end

  def install
    def add_suffix(file, suffix)
      dir = File.dirname(file); ext = File.extname(file); base = File.basename(file, ext)
      File.rename file, "#{dir}/#{base}-#{suffix}#{ext}"
    end

    def arch_config_args(t)
      @x86_64_target ||= (Target.intel? and Target._64b?) ? CPU.model_data(Target.model)[:gcc][:flags][%r{-march=(\w+)}][1] \
                                                          : 'core2'
      @ppc_target ||= (not Target.powerpc?) ? '7400' : \
                      Target.model == :g5   ? '7450' : CPU.model_data(Target.model)[:gcc][:flags][%r{\d+$}]
      case CPU.type_of(arch_unword t)
        when :intel   then ['--with-arch-32=prescott', "--with-arch-64=#{@x86_64_target}"]
        when :powerpc then ["--with-cpu-32=#{@ppc_target}", '--with-cpu-64=970']
        else []  # No reasonable defaults for arm32, and no settings at all for arm64.
      end
    end # arch_config_args

    def arch_unword(this_word)
      case this_word
        when 'aarch64'   then :arm64
        when 'i686'      then :i386
        when 'powerpc'   then :ppc
        when 'powerpc64' then :ppc64
        else this_word.to_sym
      end
    end # arch_unword

    def arch_word(this_arch)
      case this_arch.to_s
        when 'arm64'       then 'aarch64'
        when /^arm(?!64$)/ then 'arm'
        when 'i386'        then 'i686'
        when 'ppc'         then 'powerpc'
        when 'ppc64'       then 'powerpc64'
        when 'x86_64'      then 'x86_64'
      end
    end # arch_word

    def core_drivers; %w[cpp g++ gcc gfortran]; end

    def target_SDK_path_for(this_arch)
      return MacOS.sdk_path unless this_arch.starts_with?('powerpc') and MacOS.version > :leopard
      MacOS.sdk_path.sub(%r{MacOSX.*\.sdk$}, 'MacOSX10.5.sdk')
    end

    ENV.single_arch_binary if build.universal?  # Even if we’re building fat, the build‐platform‐hosted compiler is single-arch.
    ENV.delete_at %w[CPP CXXCPP]          # These cease to be correct mid‐bootstrap.

    _build_ = arch_word(Target.preferred_arch)  # We always build on our native architecture.
    _hosts_ = Target.tool_host_archset.map{ |a| arch_word(a) }  # If building a bottle, its architecture is the only thing in here.
#    # If _hosts_ doesn’t contain all possible architectures, the logic we use for gathering the target‐library code goes wrong.
#    _unhosts_ = Target.cross_archs.map{ |a| arch_word(a) } - _hosts_
    # We only don’t build for all possible targets if explicitly commanded not to.
    _targets_ = (build.with?('cross-compilers') ? Target.tool_target_archset : Target.native_archs).map{ |a| arch_word(a) }
    _unique_ = (_hosts_ + _targets_).uniq

    # - GCC Bug 25127 for PowerPC (https://gcc.gnu.org/bugzilla//show_bug.cgi?id=25127)
    #   ../../../libgcc/unwind.inc: In function '_Unwind_RaiseException':
    #   ../../../libgcc/unwind.inc:136:1: internal compiler error: in rs6000_emit_prologue, at config/rs6000/rs6000.c:26535
    # - GCC 7 fails to install on 10.6 x86_64 at stage3 (https://github.com/mistydemeo/tigerbrew/issues/554)
    ENV.no_optimization

    cctools_bin = MacOS.version < :leopard ? Formula['cctools'].opt_bin : '/usr/bin'
    ld_binary = "#{MacOS.version < :lion ? Formula['ld64'].opt_bin : '/usr/bin'}/ld"
    gnuple = "-apple-darwin#{MacOS.darwin}"
    lib_gcc = lib/'gcc'
    target_SDK_path = 

    # Prevent libstdc++ being mis‐tagged with CPU subtype 10 (G4e).  See (https://github.com/mistydemeo/tigerbrew/issues/538).
    # Note that we won’t have :gcc_4_0 or :llvm, as they are fails_with.
    ENV.append_to_cflags '-force_cpusubtype_ALL' if Target.model == :g3 and ENV.compiler == :gcc_4_2

    ENV['AS'] = ENV['AS_FOR_TARGET'] = "#{cctools_bin}/as"  # See the note at the conditional cctools dependency above.
    ENV['POSTSTAGE1_LDFLAGS'] = '-undefined dynamic_lookup'

    # For some reason, there is a pervasive assumption that plugins (that is, Mach bundle files) should have the filename extension
    # “.so”.  However, the latest word I could find from Apple instead stated that every dynamically‐linked file (other, presumably,
    # than the central file in a framework) should have the extension “.dylib”.  Of course, this is only relevant if one intends to
    # link it via “-l𝘯𝘢𝘮𝘦” – the actual OS doesn’t care.  Fix it anyway:
    begin
      files = %w[gcc libatomic libbacktrace libcc1 libffi libgfortran libgo libgomp libhsail-rt libitm libmpx libobjc liboffloadmic
          liboffloadmic/plugin libquadmath libsanitizer libssp libstdc++-v3 libvtv lto-plugin zlib].map{ |d| "#{d}/configure" } +
        %w[libgo/config/libtool.m4 libtool.m4]
      inreplace files, "shrext_cmds='\`test .\$module = .yes && echo .so || echo .dylib\`'", "shrext_cmds='.dylib'"
    end

    build_dir = buildpath/'build'; src_dir = build_dir/'src'; mkdir_p src_dir
    src_dir.install_symlink_to Dir.glob("#{buildpath}/*").reject{ |p| p == build_dir.to_s }

    # Build the C/C++, ꜰᴏʀᴛʀᴀɴ, & Objective‐C/C++ compilers.
    # The only way to bootstrap Ada would be to iterate from GCC 3.4; while Go has nominally been available since GCC 4.6.0, it has
    # never worked on Darwin – see (https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46986); HSAIL BRIG, even if it were of any use, is
    # unavailable on PowerPC; and GCC’s native Link‐Time Optimization (not a language but, oddly, controlled alongside them) simply
    # can’t be done – it requires the ELF binary format, where Darwin et seq use Mach‐O.  Just‐In‐Time code generation IS available,
    # but reduces the performance of the finished compiler, so we disable it by default; the user may opt in.
    languages = %w[c c++ fortran objc obj-c++]
    languages << 'jit' if build.with? 'jit'

    # Create a bootstrap configuration that sets the preferred optimization level to “-Os”, which, Apple claims, generally produces
    # the most performant code.
    cp buildpath/'config/bootstrap-O1.mk', buildpath/'config/bootstrap-Os.mk'
    inreplace buildpath/'config/bootstrap-Os.mk', '-O1', '-Os'

    # Each “bootstrap-xxx” build “configuration” just names one of 1̶4̶ 15 Makefile fragments for inclusion when bootstrapping.  Bare,
    # unmodified bootstrap does relatively heavy checking (which causes issues with Xcode 6.3 breakage on Mac OS Mavericks et seq.),
    # so we use “-debug-big” instead; it does lighter checks, with greater speed at the cost of disk space – even compared to plain
    # “-debug”.  Under “-debug-lib”, target libraries are built with “-fcompare-debug” to ensure the code remains constant with and
    # without additions for debugging; alas, this inexplicably fails for libgomp, forcing a Makefile patch.  We just created “-Os”,
    # for performance.  “-time” logs tool‐run durations to the build directory.
    # We can’t use “-asan” or “-ubsan” (which respectively pull in the Address and Undefined‐Behaviour Sanitizers) because Google’s
    # libsanitize won’t necessarily support our configuration.  (Exactly what it chokes on is not clear.)  Also, as discussed above,
    # GCC’s native LTO is inapplicable, which bars “-lto” and “-lto-noplugin”.  We don’t need “-debug-ckovw”, which merely triggers
    # warnings if the debug comparisons are not done, or “-debug-lean”, which is like “-debug-big” but slower (though, it does save
    # on disk space).  “-cet” and “-mpx” would enable x86‐Linux‐only safeguards, which obviously don’t apply.  “-O1” & “-O3”, which
    # are mutually exclusive with our own “-Os”, would set the optimization level to those values.
    build_config = %w[bootstrap-debug-big bootstrap-debug-lib bootstrap-Os]
    build_config << 'bootstrap-time' if DEBUG

    build_config_args = [
        "--host=#{_build_}#{gnuple}",
        "--target=#{_build_}#{gnuple}",
        "--program-prefix=#{_build_}#{gnuple}-",
        "--with-build-config=#{build_config * ' '}",
        '--enable-stage1-checking=yes',  # This is the default if we hadn’t specified a value for “checking” below.
      ]
    build_config_args << "--with-sysroot=#{MacOS.sdk_path}" unless MacOS::CLT.installed?  # For Xcode‐only systems.

    config_args = [
        "--build=#{_build_}#{gnuple}",
        "--prefix=#{prefix}",
        "--program-suffix=-#{version_major}",       # Make most executables versioned to avoid conflicts.
        "--with-gmp=#{Formula['gmp'].opt_prefix}",
        "--with-isl=#{Formula['isl'].opt_prefix}",
        "--with-mpc=#{Formula['libmpc'].opt_prefix}",
        "--with-mpfr=#{Formula['mpfr'].opt_prefix}",
        "--with-bugurl=#{ISSUES_URL}",
        '--enable-checking=release',                # Pretty much the least level of testing that actually tests anything.
        '--disable-compressed-debug-sections',
        '--enable-decimal-float',
        '--enable-default-ssp',
        '--with-diagnostics-color=always',
        '--enable-host-shared',                     # Required for JIT, but a good idea regardless.
        "--enable-languages=#{languages * ','}",
        '--enable-libatomic',
        '--enable-libssp',
        '--disable-lto',
        '--disable-multilib',
        "--with-pkgversion=Leopardbrew #{name} #{pkg_version}#{" (with #{build.used_options__modeless.list_flags})" \
                                                                                       unless build.used_options__modeless.empty?}",
        '--with-system-zlib',
        '--enable-target-optspace',
        '--enable-threads',
        '--enable-version-specific-runtime-libs',   # Without this, we’d have to go keg‐only for versions to coëxist.
        '--disable-werror',                         # While superenv removes “-Werror”, later bootstrap stages (and all subordinate
      ]                                             # compiler builds) do see it.
    # Otherwise make fails during comparison at stage 3.  See (http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45248).  (While superenv
    # removes “-gdwarf-2”, later bootstrap stages [and all subordinate compiler builds] do see it.)
    config_args << '--with-dwarf2' if MacOS.version < :mavericks
    # NLS is only enabled by default for non‐Canadian‐cross builds.
    config_args += (build.with?('nls') ? %w[--enable-nls --with-included-gettext] : %w[--disable-nls])
    # “Building GCC with plugin support requires a host that supports -fPIC, -shared, -ldl and -rdynamic.”
    config_args << '--enable-plugin' if MacOS.version > :leopard

    current_obj = build_dir/"obj-#{_build_}-#{_build_}"
    current_dst = build_dir/"dst-#{_build_}-#{_build_}"
    current_bin = current_dst/'bin'

    cd build_dir do  # Start from here so #checkpoint() can see the stuff we want it to save.
      checkpoint("1-#{arch_unword(_build_)}-native-compiler") do
        mkdir_p [current_obj, current_dst]
        cd current_obj do
          system src_dir/'configure', *build_config_args, *config_args, *arch_config_args(_build_)
          system 'make', 'bootstrap'
          ENV.deparallelize { system 'make', 'check' } if build.with? 'tests'
          ENV.deparallelize { system 'make', 'html', 'info' }
          system 'make', "prefix=#{current_dst}", 'install-gcc', 'install-target'
        end
        cd current_bin do  # This is created for us by the “make install” step above.
          rm Dir["#{_build_}#{gnuple}-#{_build_}#{gnuple}*"]
          core_drivers.each do |prg|
            ln_s "#{_build_}#{gnuple}-#{prg}-#{version_major}", "#{prg}-#{version_major}"
            ln_s "#{_build_}#{gnuple}-#{prg}-#{version_major}", prg
            ln_s "#{_build_}#{gnuple}-#{prg}-#{version_major}", "#{_build_}#{gnuple}-#{prg}"
          end
          ln_s "#{_build_}#{gnuple}-gcc-#{version_major}", 'cc'
          ln_s "#{_build_}#{gnuple}-g++-#{version_major}", 'c++'
        end
      end # native-compiler checkpoint
    end # cd to build dir for checkpoint

    ENV.prepend_path 'PATH', current_bin  # Add the native compiler to $PATH…
    ENV.delete_at %w[CC CXX OBJC OBJCXX]  # …replacing all of these.
    # Make all those libraries we just built visible in the location they believe themselves to be installed.
    lib_gcc.install_symlink_to current_dst/"lib/gcc/#{_build_}#{gnuple}"

    ENV.remove_from_cflags '-force_cpusubtype_ALL'  # Undo build‐specific $CFLAGS.
    ENV.without_archflags  # The post‐bootstrap build process doesn’t use archflags.

    unless _unique_ == [_build_]
      ENV.delete_at %w[AS AS_FOR_TARGET]  # We no longer need these, as we are preparing substitutes.

      # Set up specially-named utility programs (actually wrapper shims).  “The cross‐tools’ build process expects to find specific
      # programs under names like ‘i686-apple-darwin#{darwin_major}-ar’ – so make them.  Annoyingly, `ranlib` changes its behaviour
      # depending on what you call it, so we have to use shell scripts for indirection,” says the build_gcc script from Apple’s old
      # GCC fork.
      build_bin = build_dir/'bin'
      mkdir build_bin do
        %w[ar nm ranlib strip lipo].each do |prg|
          _unique_.each do |t|
            Pathname(fname = "#{t}#{gnuple}-#{prg}").atomic_write <<-_.undent
                #!/bin/sh
                exec #{cctools_bin}/#{prg} "$@"
              _
            chmod 'a+x', fname
          end # each unique arch |t|
        end # each cctool |prg|
        _unique_.each do |t|
          Pathname(fname = "#{t}#{gnuple}-ld").atomic_write <<-_.undent
              #!/bin/sh
              exec #{ld_binary} "$@"
            _
          chmod 'a+x', fname
          Pathname(fname = "#{t}#{gnuple}-as").atomic_write <<-_.undent
              #!/bin/sh
              dt=#{arch_unword(t)}
              temp_file=''
              prev_was_I=false; prev_was_arch=false; prev_was_o=false
              args=()
              for a; do
                if [ $prev_was_I != false ]; then prev_was_I=false; args[${#args[@]}]="-I$a"
                elif [ $prev_was_arch != false ]; then case $a in
                    -*) echo "as:  Unrecognized architecture “$a”"; exit 1;;
                    *) prev_was_arch=false; dt="$(echo $a | sed -e s/powerpc/ppc/g -e s/i686/i386/ -e s/aarch64/arm64/)";;
                  esac
                elif [ $prev_was_o != false ]; then prev_was_o=false; args[${#args[@]}]="$a"
                else case $a in
                    -I) prev_was_I=true;;
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
        end # each unique architecture |t|
        ENV.prepend_path 'PATH', pwd  # Add the directory containing all of these to $PATH.
      end # build cctools shim wrappers

      _unique_.each do |t|
        next if t == _build_
        ENV['AS'] = build_dir/"bin/#{t}#{gnuple}-as"
        other_config_args = [
            "--host=#{_build_}#{gnuple}",
            "--target=#{t}#{gnuple}",
            "--program-prefix=#{t}#{gnuple}-",
            "--with-sysroot=#{target_SDK_path_for t}",
          ]
        current_obj = build_dir/"obj-#{_build_}-#{t}"
        current_dst = build_dir/"dst-#{_build_}-#{t}"
        current_bin = current_dst/'bin'
        cd build_dir do  # Start from here so #checkpoint() can see the stuff we want it to save.
          checkpoint("2-#{arch_unword(_build_)}-hosted-#{arch_unword(t)}-cross-compiler") do
            mkdir_p [current_obj, current_dst]
            cd current_obj do
              system src_dir/'configure', *config_args, *arch_config_args(t), *other_config_args
              system 'make', 'all'
              system 'make', "prefix=#{current_dst}", 'install-gcc', 'install-target'
            end # build cross compiler
          end # “cross‐compiler for |t|” checkpoint
        end # cd to build dir for checkpoint
        ENV.prepend_path 'PATH', current_bin  # Add the tools we just built to $PATH.
        core_drivers.each do |prg|  # Also make the most important ones available in-tree.
          build_bin.install_symlink "#{current_bin}/#{t}#{gnuple}-#{prg}-#{version_major}" => "#{t}#{gnuple}-#{prg}"
        end
        # Make all those libraries we just built visible in the location they believe themselves to be installed.
        lib.install_symlink_to current_dst/'lib/gcc'
      end # each unique architecture |t|
    end # build anything besides _build_?

    unless _hosts_ == [_build_]
      _hosts_.each do |h|
        next if h == _build_
        ENV['AS'] = build_bin/"#{h}#{gnuple}-as"
        _unique_.each do |t|
          other_config_args = [
              "--host=#{h}#{gnuple}",
              "--target=#{t}#{gnuple}",
              "--program-prefix=#{t}#{gnuple}-",
              "--with-sysroot=#{target_SDK_path_for t}",
            ]
          current_obj = build_dir/"obj-#{h}-#{t}"
          current_dst = build_dir/"dst-#{h}-#{t}"
          current_bin = current_dst/'bin'
          make_install_command = %W[make prefix=#{current_dst} install-gcc]
          make_install_command << 'install-target' if h == t
          cd build_dir do  # Start from here so #checkpoint() can see the stuff we want it to save.
            checkpoint("3-#{arch_unword(h)}-#{h == t ? 'native' : "hosted-#{arch_unword(t)}-cross"}-compiler") do
              mkdir_p [current_obj, current_dst]
              cd current_obj do
                system src_dir/'configure', *config_args, *arch_config_args(t), *other_config_args
                system 'make'
                system *make_install_command
              end # build cross‐hosted compiler
              cd current_bin do rm Dir["#{t}#{gnuple}-#{t}#{gnuple}*"] if h == t; end
            end # “|h|‐hosted cross‐compiler for |t|” checkpoint
          end # cd to build dir for checkpoint
        end # each unique architecture |t|
      end # each host platform |h|
    end # build with cross‐hosting?
#    # Even if we aren’t installing native compilers for some architectures, we still need to generate their native libraries so the
#    # fat‐binary installation logic works correctly.  Otherwise we would have to gin up an unholy scavenger‐hunt checklist to guess
#    # when we MIGHT, coïncidentally, have generated a slice with the right architecture while building native cross‐compilers – for
#    # EVERY binary in the whole compiler collection.  No thanks!
#    if build.with? 'cross-compilers' and not _unhosts_.empty?
#      _unhosts_.each do |h|
#        ENV['AS'] = build_bin/"#{h}#{gnuple}-as"
#        other_config_args = [
#            "--host=#{h}#{gnuple}",
#            "--target=#{h}#{gnuple}",
#            "--program-prefix=#{h}#{gnuple}-",
#            "--with-sysroot=#{target_SDK_path_for h}",
#          ]
#        current_obj = build_dir/"obj-#{h}-#{h}"
#        current_dst = build_dir/"dst-#{h}-#{h}"
#        current_bin = current_dst/'bin'
#        cd build_dir do  # Start from here so #checkpoint() can see the stuff we want it to save.
#          checkpoint("4-#{arch_unword(h)}-native-compiler") do
#            mkdir_p [current_obj, current_dst]
#            cd current_obj do
#              system src_dir/'configure', *config_args, *arch_config_args(h), *other_config_args
#              system 'make'
#              system 'make', "prefix=#{current_dst}", 'install-target'
#            end # build cross‐unhosted compiler
##            cd current_bin do rm Dir["#{h}#{gnuple}-#{h}#{gnuple}*"]; end
#          end # “|h|‐unhosted native compiler” checkpoint
#        end # cd to build dir for checkpoint
#      end # each unhost platform |h|
#    end # fill in _unhosts_ target libraries

raise

    # Actually install all the stuff we just built.
    doc.install (build_dir/"obj-#{_build_}-#{_build_}/gcc/HTML/gcc-#{version}").children
  # manpages
    share.install build_dir/"dst-#{_build_}-#{_build_}/share/man"
    man1.install_symlink_to "g++-#{version_major}.1" => "c++-#{version_major}.1"
    _unique_.each{ |t| core_drivers.each{ |prg|
      man1.install_symlink_to "#{prg}-#{version_major}.1" => "#{t}#{gnuple}-#{prg}-#{version_major}.1"
    } }
  # libexec
    begin
      built_root = build_dir/"dst-#{_build_}-#{_build_}/libexec/gcc/#{_build_}#{gnuple}/#{version}"
      built_root_re = %r{^#{Regexp.escape built_root}/}
      _targets_.each do |t|
        libexec_offset = "libexec/gcc/#{t}#{gnuple}/#{version}"
        built_root.find do |pn|
          pn_offset = pn.to_s.sub(built_root_re, '')
          if pn.directory? then pn.mkpath
          else
            parent_dir = (target_file = prefix/libexec_offset/pn_offset).parent
            if pn.tracked_mach_o?
              if (slices = Dir["#{build_dir}/dst-*-#{t}/#{libexec_offset}/#{pn_offset}"]).length > 1
                system MacOS.lipo, '-create', *slices, '-output', target_file
              else cp slices[0], target_file; end
            else parent_dir.install build_dir/"dst-#{_build_}-#{t}/#{libexec_offset}/#{pn_offset}"; end
          end # not a directory
        end # find |pn| within built_root
        (prefix/libexec_offset).install_symlink_to "#{cctools_bin}/as"
      end # each libexec target architecture |t|
    end
  # bin
    bin.mkpath
    # The native drivers, which vary per host architecture.  (Ignore compiler drivers; they get overwritten by the driver-driver.)
    Dir["#{build_dir}/dst-#{_build_}-#{_build_}/bin/*"].reject{ |f| File.symlink? f }.map{ |f| File.basename f
      }.reject{ |f| core_drivers.any?{ |prg| f.starts_with? "#{_build_}#{gnuple}-prg" } or f =~ %r{c\+\+}
      }.each{ |f|
        finished_name = f.sub %r{^#{_build_}#{gnuple}-}, ''
        if (slices = Dir["#{build_dir}/dst-{#{_hosts_.map{ |h| "#{h}-#{h}" } * ','}}/bin/*#{gnuple}-#{finished_name}"]).length > 1
          system MacOS.lipo, '-output', bin/finished_name, '-create', *slices
        else cp slices[0], bin/finished_name; end
      }
    # The fully‐named drivers, which have the same target on every host.
    _unique_.each do |t|
      Dir["#{build_dir}/dst-#{_build_}-#{t}/bin/*"].reject{ |f| File.symlink?(f) or f =~ %r{c\+\+} or f.ends_with(version.to_s)
        }.map{ |f| File.basename f }.each{ |f|
          finished_name = f.sub(%r{#{Regexp.escape version_major}$}, version.to_s)
          if (slices = Dir["#{build_dir}/dst-*-#{t}/bin/#{f}"]).length > 1
            system MacOS.lipo, '-output', bin/finished_name, '-create', *slices
          else cp slices[0], bin/finished_name; end
        }
    end # each target architecture |t|
  # lib
    lib.rmtree  # Get rid of all the temporary symlinks we stuck in there.
    lib_gcc.mkpath
# TODO:  Scan for library files & lipo(1) them together, then use install_name_tool(1) to adjust the install paths.  We built stuff
#        in per‐architecture directories, but we install them as fat binaries in a single directory:   {lib}/gcc/<version>.
#    if (slices = Dir["#{build_dir}/dst-#{_build_}-*/lib/gcc/*#{gnuple}/#{version}/libgcc_s.1.dylib"]).length > 1
#      system MacOS.lipo, '-output', lib_gcc/'libgcc_s.1.dylib', '-create', *slices
#    else cp slices[0], lib_gcc/'libgcc_s.1.dylib'; end
#    lib_gcc.install_symlink_to 'libgcc_s.1.dylib' => 'libgcc_s.1.0.dylib'
#    lib_gcc.install_symlink_to 'libgcc_s.1.dylib' => 'libgcc_s_ppc64.1.dylib' if _unique_.includes? 'powerpc64'
#    lib_gcc.install_symlink_to 'libgcc_s.1.dylib' => 'libgcc_s_x86_64.1.dylib' if _unique_.includes? 'x86_64'
  # include
#TODO:  Verify that all of the include/ hierarchies contain identical material.
    include.install Dir["#{build_dir}/dst-#{_build_}-#{_build_}/include/*"]

    # Build the driver‐driver, using the named drivers.
    resource('driver-driver').unpack buildpath
    core_drivers.each do |prg|
      _hosts_.each do |h|
        mkpath "#{build_dir}/obj-#{h}-#{h}/driver-driver"
        system build_dir/"dst-#{_build_}-#{h}/bin/#{h}#{gnuple}-gcc-#{version}", buildpath/'gcc-driverdriver.c',
               "-DPDN=\"#{gnuple}-#{prg}-#{version}\"", "-I#{build_dir}/src/include", "-I#{build_dir}/src/gcc",
               "-I#{build_dir}/src/gcc/config", "-I#{lib}/gcc/#{h}#{gnuple}/#{version}/include",
               "-L#{build_dir}/obj-#{h}-#{h}/gcc", "-L#{build_dir}/obj-#{h}-#{h}/libiberty", '-liberty',
               '-o', build_dir/"obj-#{h}-#{h}/driver-driver/#{prg}-#{version_major}"
      end # each host architecture |h|
      if (slices = Dir["#{build_dir}/obj-*/driver-driver/#{prg}-#{version_major}"]).length > 1
        system MacOS.lipo, '-output', bin/"#{prg}-#{version_major}", '-create', *slices
      else cp slices[0], bin/"#{prg}-#{version_major}"; end
    end # each |prg|
    bin.install_symlink_to bin/"g++-#{version_major}" => "c++-#{version_major}"
    bin.install_symlink_to bin/"gcc-#{version_major}" => "cc-#{version_major}"

    # Unwrap all the things that got shoved into fat containers with only one slice.
    prefix.find do |pn|
      if pn.fat_container? and not pn.fat?
        mv pn, (pnt = "#{pn}_temp")
        system MacOS.lipo, pnt, '-thin', pnt.arch, '-output', pn
        pnt.unlink
      end
    end # find |pn|

    # Handle conflicts between GCC formulæ & avoid interfering with system compilers.
    # man7:  Add “-gcc8” suffixes.
    Dir.glob(man7/'*.7') { |file| add_suffix(file, name) }
    # Info:  Edit internal menu entries and rename with “-8” suffixes.
    Dir.glob(info/'*.info') do |file|
      inreplace file do |s|
        in_the_zone = false
        s.each_line do |line|
          case in_the_zone
            when false then in_the_zone = true if line =~ /START-INFO-DIR-ENTRY/
            when true
              break if line =~ /END-INFO-DIR-ENTRY/
              line.sub!(/(\*[^(]+\()(.+)(\))/, "#{$1}#{$2}-#{version_major})")
          end # in the zone
        end # each |line|
      end # file contents |s|
      add_suffix(file, version_major)
    end # each *.info |file|
  end # install

  test do
    ENV.universal_binary if build.universal?

    (testpath/'hello-c.c').write <<-EOS.undent
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    for_archs(bin/"gcc-#{version_major}") do |_, compiler_cmd|
      system *compiler_cmd, *ENV.build_archs.as_arch_flag_array, '-o', 'hello-c', 'hello-c.c'
      for_archs('./hello-c') { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }
    end

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    for_archs(bin/"g++-#{version_major}") do |_, compiler_cmd|
      system *compiler_cmd, *ENV.build_archs.as_arch_flag_array, '-o', 'hello-cc', 'hello-cc.cc'
      for_archs('./hello-cc') { |_, cmd| assert_equal("Hello, world!\n", Utils.popen_read(*cmd)) }
    end

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
    for_archs(bin/"gfortran-#{version_major}") do |_, compiler_cmd|
      system *compiler_cmd, *ENV.build_archs.as_arch_flag_array, '-o', 'test', 'test.f90'
      for_archs('./test') { |_, cmd| assert_equal("Done\n", Utils.popen_read(*cmd)) }
    end
  end # test
end # Gcc8

__END__
--- old/config/mh-darwin
+++ new/config/mh-darwin
# This test against Darwin’s version number stops at Darwin 19 (Mac OS 10.15).  Considering we have already skipped Darwin 25, that
# doesn’t seem very future‐resilient.
@@ -13,7 +13,7 @@
 
 # ld on Darwin versions >= 10.7 defaults to PIE executables. Disable this for
 # gcc components, since it is incompatible with our pch implementation.
-DARWIN_NO_PIE := `case ${host} in *-*-darwin[1][1-9]*) echo -Wl,-no_pie ;; esac;`
+DARWIN_NO_PIE := `case ${host} in *-*-darwin1[1-9]*|*-*-darwin[2-9][0-9]*) echo -Wl,-no_pie ;; esac;`
 
 BOOT_CFLAGS += $(DARWIN_MDYNAMIC_NO_PIC)
 BOOT_LDFLAGS += $(DARWIN_NO_PIE)
--- old/config/mt-ospace
+++ new/config/mt-ospace
# The original comment here is misleading.  On some platforms, optimizing for space IS optimizing for speed.
@@ -1,3 +1,3 @@
-# Build libraries optimizing for space, not speed.
+# Build libraries optimizing for space first.
  CFLAGS_FOR_TARGET += -g -Os
  CXXFLAGS_FOR_TARGET += -g -Os
--- old/gcc/config/darwin.h
+++ new/gcc/config/darwin.h
# The comment states that these should only be suppressed when operation is sysrooted; but no reason is given for doing that in the
# first place, and they are ALWAYS suppressed regardless!  Under what bizarre circumstances would you not want your compiler to see
# <sysroot>/usr/lib without that being explicitly suppressed?
@@ -262,10 +262,6 @@
    isysroot is specified.  */
 #define LINK_SYSROOT_SPEC "%{isysroot*:-syslibroot %*}"
 
-/* Suppress the addition of extra prefix paths when a sysroot is in use.  */
-#define STANDARD_STARTFILE_PREFIX_1 ""
-#define STANDARD_STARTFILE_PREFIX_2 ""
-
 /* Please keep the random linker options in alphabetical order (modulo
    'Z' and 'no' prefixes). Note that options taking arguments may appear
    multiple times on a command line with different arguments each time,
--- old/gcc/gcc.c
+++ new/gcc/gcc.c
# Prevent an extraneous equals sign from being emitted when the search paths are listed.  It is only used when the PREFIX parameter
# has been filled in with an environment‐variable name and should not be inserted otherwise.
@@ -2688,7 +2689,7 @@
   info.first_time = true;
 
   obstack_grow (&collect_obstack, prefix, strlen (prefix));
-  obstack_1grow (&collect_obstack, '=');
+  if (prefix[0]) obstack_1grow (&collect_obstack, '=');
 
   for_each_path (paths, do_multi, 0, add_to_obstack, &info);
 
# Do not repeat a prefix for “BINUTILS”, because binutils doesn’t do Mach‐O binaries & won’t (usefully) be installed; it just gives
# a duplicate of that standard prefix.
@@ -4561,8 +4562,6 @@
 #ifndef OS2
       add_prefix (&exec_prefixes, standard_libexec_prefix, "GCC",
 		  PREFIX_PRIORITY_LAST, 1, 0);
-      add_prefix (&exec_prefixes, standard_libexec_prefix, "BINUTILS",
-		  PREFIX_PRIORITY_LAST, 2, 0);
       add_prefix (&exec_prefixes, standard_exec_prefix, "BINUTILS",
 		  PREFIX_PRIORITY_LAST, 2, 0);
 #endif
--- old/gcc/jit/jit-playback.c
+++ new/gcc/jit/jit-playback.c
# Dynamic‐library names do not necessarily end with “.so”.
@@ -1814,7 +1814,7 @@
   ctxt_progname = get_str_option (GCC_JIT_STR_OPTION_PROGNAME);
 
   if (!ctxt_progname)
-    ctxt_progname = "libgccjit.so";
+    ctxt_progname = "libgccjit";
 
   auto_vec <recording::requested_dump> requested_dumps;
   m_recording_ctxt->get_all_requested_dumps (&requested_dumps);
--- old/gcc/jit/jit-recording.c
+++ new/gcc/jit/jit-recording.c
# Dynamic‐library names do not necessarily end with “.so”.
@@ -1426,7 +1426,7 @@
   const char *ctxt_progname =
     get_str_option (GCC_JIT_STR_OPTION_PROGNAME);
   if (!ctxt_progname)
-    ctxt_progname = "libgccjit.so";
+    ctxt_progname = "libgccjit";
 
   if (loc)
     fprintf (stderr, "%s: %s: error: %s\n",
--- old/gcc/jit/Make-lang.in
+++ new/gcc/jit/Make-lang.in
# Keep libgccjit with all the other libraries, distinguished by GCC version, _as required by configuration option_!  How, and _why_,
# is this not already the case?  Also, dynamic‐library names do not necessarily end with “.so”.
@@ -40,16 +40,16 @@
 # into the jit rule, but that needs a little bit of work
 # to do the right thing within all.cross.
 
-LIBGCCJIT_LINKER_NAME = libgccjit.so
+LIBGCCJIT_LINKER_NAME = libgccjit
 LIBGCCJIT_VERSION_NUM = 0
 LIBGCCJIT_MINOR_NUM = 0
 LIBGCCJIT_RELEASE_NUM = 1
+LIBGCCJIT_FULL_VERSION = $(LIBGCCJIT_VERSION_NUM).$(LIBGCCJIT_MINOR_NUM).$(LIBGCCJIT_RELEASE_NUM)
 LIBGCCJIT_SONAME = $(LIBGCCJIT_LINKER_NAME).$(LIBGCCJIT_VERSION_NUM)
-LIBGCCJIT_FILENAME = \
-  $(LIBGCCJIT_SONAME).$(LIBGCCJIT_MINOR_NUM).$(LIBGCCJIT_RELEASE_NUM)
+LIBGCCJIT_FILENAME = $(LIBGCCJIT_LINKER_NAME).$(LIBGCCJIT_FULL_VERSION).dylib
 
-LIBGCCJIT_LINKER_NAME_SYMLINK = $(LIBGCCJIT_LINKER_NAME)
-LIBGCCJIT_SONAME_SYMLINK = $(LIBGCCJIT_SONAME)
+LIBGCCJIT_LINKER_NAME_SYMLINK = $(LIBGCCJIT_LINKER_NAME).dylib
+LIBGCCJIT_SONAME_SYMLINK = $(LIBGCCJIT_SONAME).dylib
 
 # Conditionalize the use of the LD_VERSION_SCRIPT_OPTION and
 # LD_SONAME_OPTION depending if configure found them, using $(if)
# Correctly set the library load name, and the current and compatibility versions.
@@ -62,7 +62,9 @@
 
 LIBGCCJIT_SONAME_OPTION = \
 	$(if $(LD_SONAME_OPTION), \
-	     -Wl$(COMMA)$(LD_SONAME_OPTION)$(COMMA)$(LIBGCCJIT_SONAME))
+	     -Wl$(COMMA)$(LD_SONAME_OPTION)$(COMMA)$(DESTDIR)$(libsubdir)/$(LIBGCCJIT_FILENAME) \
+	     -Wl$(COMMA)-compatibility_version$(COMMA)$(LIBGCCJIT_FULL_VERSION) \
+	     -Wl$(COMMA)-current_version$(COMMA)$(LIBGCCJIT_FULL_VERSION))
 
 jit: $(LIBGCCJIT_FILENAME) \
 	$(LIBGCCJIT_SYMLINK) \
@@ -274,13 +276,13 @@
 # Install hooks:
 jit.install-common: installdirs
 	$(INSTALL_PROGRAM) $(LIBGCCJIT_FILENAME) \
-	  $(DESTDIR)/$(libdir)/$(LIBGCCJIT_FILENAME)
+	  $(DESTDIR)$(libsubdir)/$(LIBGCCJIT_FILENAME)
 	ln -sf \
 	  $(LIBGCCJIT_FILENAME) \
-	  $(DESTDIR)/$(libdir)/$(LIBGCCJIT_SONAME_SYMLINK)
+	  $(DESTDIR)$(libsubdir)/$(LIBGCCJIT_SONAME_SYMLINK)
 	ln -sf \
-	  $(LIBGCCJIT_SONAME_SYMLINK)\
-	  $(DESTDIR)/$(libdir)/$(LIBGCCJIT_LINKER_NAME_SYMLINK)
+	  $(LIBGCCJIT_FILENAME) \
+	  $(DESTDIR)$(libsubdir)/$(LIBGCCJIT_LINKER_NAME_SYMLINK)
 	$(INSTALL_DATA) $(srcdir)/jit/libgccjit.h \
 	  $(DESTDIR)/$(includedir)/libgccjit.h
 	$(INSTALL_DATA) $(srcdir)/jit/libgccjit++.h \
--- old/gcc/Makefile.in
+++ new/gcc/Makefile.in
# The GCC-generated ar, nm, ranlib, & LTO wrappers exist to insert the LTO plugin, which can’t apply on Darwin (doubly so, on older
# Darwins that can’t even do plugins).  Stop all four of them from being made.  This has the side benefit of restoring the “install
# the driver last to minimize the risk of breakage” behaviour described in the comment at lines 3435–3437.
@@ -1907,8 +1907,7 @@
 # This is what is made with the host's compiler
 # whether making a cross compiler or not.
 native: config.status auto-host.h build-@POSUB@ $(LANGUAGES) \
-	$(EXTRA_PROGRAMS) $(COLLECT2) lto-wrapper$(exeext) \
-	gcc-ar$(exeext) gcc-nm$(exeext) gcc-ranlib$(exeext)
+	$(EXTRA_PROGRAMS) $(COLLECT2)
 
 ifeq ($(enable_plugin),yes)
 native: gengtype$(exeext)
@@ -3437,7 +3436,7 @@
 # broken is small.
 install: install-common $(INSTALL_HEADERS) \
     install-cpp install-man install-info install-@POSUB@ \
-    install-driver install-lto-wrapper install-gcc-ar
+    install-driver
 
 ifeq ($(enable_plugin),yes)
 install: install-plugin
--- old/gcc/system.h
+++ new/gcc/system.h
# Not only plugins, but also JIT (& who knows what else) require system functions like dlopen() (found in <dlfcn.h>).  We need that
# header, regardless of whether actual plugins are to be supported.
@@ -677,8 +677,8 @@
 # endif
 #endif
 
-#if defined (ENABLE_PLUGIN) && defined (HAVE_DLFCN_H)
-/* If plugin support is enabled, we could use libdl.  */
+#if defined (HAVE_DLFCN_H)
+/* If plugin support, JIT, or who knows what else are enabled, we will need libdl. */
 #include <dlfcn.h>
 #endif
 
--- old/libgcc/config/t-slibgcc-darwin
+++ new/libgcc/config/t-slibgcc-darwin
# Many GCC target libraries inexplicably link to the system-specific stub libraries, so no, they aren’t “useless unless building to
# /usr/lib”.  That would only be true if the new stub libraries were the same as the old ones, which they aren’t.  This quirk seems
# to also be the source of the inexplicable, unblockable linkage of the old libgcc_s in parallel with the freshly‐built version, so
# making sure not to do that is doubly important.
@@ -27,14 +27,7 @@
 SHLIB_MAPFILES = libgcc-std.ver $(srcdir)/config/libgcc-libsystem.ver
 SHLIB_VERPFX = $(srcdir)/config/$(cpu_type)/libgcc-darwin
 
-# we're only going to build the stubs if the target slib is /usr/lib
-# there is no other case in which they're useful in a live system.
-ifeq (/usr/lib,$(shlib_slibdir))
 LGCC_STUBS = libgcc_s.10.4.dylib libgcc_s.10.5.dylib
-else
-LGCC_STUBS =
-endif
-
 LGCC_FILES = libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)
 LGCC_FILES += $(LGCC_STUBS)
 LEXT_STUBS = libgcc_ext.10.4$(SHLIB_EXT) libgcc_ext.10.5$(SHLIB_EXT)
# Building with multilibs disabled causes single-slice fat-binary containers to be generated.  This is obviously silly; fix it.
@@ -60,34 +53,33 @@
 #
 # This assumes each multilib corresponds to a different architecture.
 libgcc_s.%.dylib : all-multi $(SHLIB_VERPFX).%.ver libgcc_s$(SHLIB_EXT)
-	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; \
+	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; i=0 ; \
#'
 	for mlib in $$MLIBS ; do \
 	  $(STRIP) -o $(@)_T$${mlib} \
 	    -s $(SHLIB_VERPFX).$(*).ver -c -u \
-	    ../$${mlib}/libgcc/$${mlib}/libgcc_s$(SHLIB_EXT)  || exit 1 ; \
+	    ../$${mlib}/libgcc/$${mlib}/libgcc_s$(SHLIB_EXT) || exit 1 ; i=$$(($$i + 1)) ; \
 	done
-	$(LIPO) -output $@ -create $(@)_T*
-	rm $(@)_T*
+	if [ $$i -gt 1 ]; then $(LIPO) -output $@ -create $(@)_T* ; rm $(@)_T* ; else mv $(@)_T* $@ ; fi
 
 libgcc_ext.%.dylib : all-multi $(SHLIB_VERPFX).%.ver libgcc_s$(SHLIB_EXT) 
-	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; \
+	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; i=0 ; \
#'
 	for mlib in $$MLIBS ; do \
 	  $(STRIP) -o $(@)_T$${mlib} \
 	    -R $(SHLIB_VERPFX).$(*).ver -c -urx \
-	    ../$${mlib}/libgcc/$${mlib}/libgcc_s$(SHLIB_EXT) || exit 1 ; \
+	    ../$${mlib}/libgcc/$${mlib}/libgcc_s$(SHLIB_EXT) || exit 1 ; i=$$(($$i + 1)) ; \
 	done
-	$(LIPO) -output $@ -create $(@)_T*
-	rm $(@)_T*
+	if [ $$i -gt 1 ]; then $(LIPO) -output $@ -create $(@)_T* ; rm $(@)_T* ; else mv $(@)_T* $@ ; fi
 
 libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT): all-multi libgcc_s$(SHLIB_EXT)
-	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; \
+	MLIBS=`$(CC) --print-multi-lib | sed -e 's/;.*$$//'` ; i=0 ; \
#`
 	for mlib in $$MLIBS ; do \
 	  cp ../$${mlib}/libgcc/$${mlib}/libgcc_s$(SHLIB_EXT)  \
-	    ./libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T_$${mlib} || exit 1 ; \
+	    ./libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T_$${mlib} || exit 1 ; i=$$(($$i + 1)) ; \
 	done
-	$(LIPO) -output libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT) \
-	  -create libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T*
-	rm libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T*
+	if [ $$i -gt 1 ]; then
+	  $(LIPO) -output libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT) -create libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T*
+	  rm libgcc_s.$(SHLIB_SOVERSION)$(SHLIB_EXT)_T*
+	else mv $(@)_T* $@ ; fi
 
 install-darwin-libgcc-stubs :
 	$(mkinstalldirs) $(DESTDIR)$(slibdir)
--- old/libstdc++-v3/configure
+++ new/libstdc++-v3/configure
# Use of -Wabi without any qualifier regarding what ABI to compare to is utterly pointless, & elicits an identical compiler warning
# on EACH AND EVERY SOURCE FILE in libstdc++-v3/.  This is so immensely irritating that it was worth patching.
@@ -81940,7 +81940,7 @@
   # OPTIMIZE_CXXFLAGS = -O3 -fstrict-aliasing -fvtable-gc
 
 
-  WARN_FLAGS='-Wall -Wextra -Wwrite-strings -Wcast-qual -Wabi'
+  WARN_FLAGS='-Wall -Wextra -Wwrite-strings -Wcast-qual'
 
 
 
--- old/Makefile.in
+++ new/Makefile.in
# Doing bootstrap-debug-lib causes the stage3 value of $(TFLAGS) to differ from the plain one used when not bootstrapping.  This in
# turn causes Make invocations for things like unit testing or documentation to fail, because the $CC value in config.cache doesn’t
# match the one in use at the time.  Thus, we must insert a conditional expression to remove config.cache (if it exists) – but only
# when $(BUILD_CONFIG) contains “bootstrap-debug-lib” and $(TFLAGS) does not contain “-fcompare-debug=”.
# Fixing this properly (and a lot of other maintenance besides) would be a lot more straightforward if they’d implemented all these
# nearly‐identical “configure-target-xxx” blocks as a parameterized shell subroutine, instead of as an autogen macro.  We seriously
# do not need to {depends_on} {automake} just to tweak the build of our bootstrap compiler.
@@ -37903,6 +37903,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libstdc++-v3; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -39146,6 +39148,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libsanitizer; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -40389,6 +40393,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libmpx; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -41632,6 +41638,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libvtv; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -42876,6 +42884,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=liboffloadmic; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -43334,6 +43344,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libssp; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -43792,6 +43804,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=newlib; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -44249,6 +44263,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libgcc; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -45488,6 +45504,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libbacktrace; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -45946,6 +45964,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libquadmath; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -46404,6 +46424,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libgfortran; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -46862,6 +46884,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libobjc; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -47320,6 +47344,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libgo; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -47778,6 +47804,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libhsail-rt; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -48236,6 +48264,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libtermcap; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -48629,6 +48659,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=winsup; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -49087,6 +49119,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libgloss; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -49540,6 +49574,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libffi; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -49988,6 +50024,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=zlib; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -50446,6 +50484,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=rda; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -50904,6 +50944,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libada; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -51361,6 +51403,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libgomp; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
# Doing -fcompare-debug on libgomp fails for some reason.  Ideally we’d figure out why and fix it, but in the meantime, just bypass
# it for that one library.
@@ -51896,7 +51940,7 @@
 	@[ $(current_stage) = stage3 ] || $(MAKE) stage3-start
 	@r=`${PWD_COMMAND}`; export r; \
 	s=`cd $(srcdir); ${PWD_COMMAND}`; export s; \
#`
-	TFLAGS="$(STAGE3_TFLAGS)"; \
+	TFLAGS="$(filter-out -fcompare-debug=%,$(STAGE3_TFLAGS))"; \
 	$(NORMAL_TARGET_EXPORTS) \
 	  \
 	cd $(TARGET_SUBDIR)/libgomp && \
@@ -51909,7 +51953,7 @@
 		CXXFLAGS_FOR_TARGET="$(CXXFLAGS_FOR_TARGET)" \
 		LIBCFLAGS_FOR_TARGET="$(LIBCFLAGS_FOR_TARGET)" \
 		$(EXTRA_TARGET_FLAGS)   \
-		TFLAGS="$(STAGE3_TFLAGS)"  \
+		TFLAGS="$(filter-out -fcompare-debug=%,$(STAGE3_TFLAGS))" \
 		$(TARGET-stage3-target-libgomp)
 
 maybe-clean-stage3-target-libgomp: clean-stage3-target-libgomp
# Continue the bootstrap-debug-lib corrections.
@@ -52605,6 +52649,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libitm; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
@@ -53063,6 +53109,8 @@
 		sed -e 's,\./,,g' -e 's,[^/]*/,../,g' `$(srcdir) ;; \
#`
 	esac; \
 	module_srcdir=libatomic; \
+	$(if $(and $(findstring bootstrap-debug-lib,$(BUILD_CONFIG)),$(if $(findstring -fcompare-debug=,$(TFLAGS)),,true)),test -f \
+	  $(TARGET_SUBDIR)/$$module_srcdir/config.cache && rm $(TARGET_SUBDIR)/$$module_srcdir/config.cache;) \
 	rm -f no-such-file || : ; \
 	CONFIG_SITE=no-such-file $(SHELL) \
 	  $$s/$$module_srcdir/configure \
