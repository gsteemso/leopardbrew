# stable release 2010-10-14; discontinued.
class AppleGcc42 < Formula
  desc 'the last Apple version of the GNU Compiler Collection for Mac OS'
  homepage 'http://https://opensource.apple.com/releases/'
  url 'https://github.com/apple-oss-distributions/gcc/archive/refs/tags/gcc-5666.3.tar.gz'
  version '4.2.1-5666.3'
  revision 1  # For the crt0 & libssp fixes.
  sha256 '2e9889ce0136f5a33298cf7cce5247d31a5fb1856e6f301423bde4a81a5e7ea6'

  keg_only :provided_by_osx if MacOS.version > :tiger and MacOS.version < :lion

  option :universal
  option 'with-arm', 'Build with 32‐bit ARM support for iOS, etc' if MacOS.iPhone_SDK_present?

  # Make sure we have a suitable `as` for every target (& don’t put as “:cctools”, it won’t necessarily pull in the actual formula).
  depends_on 'cctools' if build.with? 'arm'

  enhanced_by :nls

  # Fiddle with the build script and associated files (to allow more possible system configurations, albeit much of it specifically
  # for building :arm32 compilers; to fix several bugs; and also to greatly simplify installation).
  patch :DATA

  patch <<END_OF_PATCH if MacOS.version < :leopard
--- old/gcc/libgcov.c
+++ new/gcc/libgcov.c
# <vproc.h> is not present on systems prior to Leopard; apply the fact in conditional compilation.
@@ -33,9 +33,10 @@
 #include "tsystem.h"
 #include "coretypes.h"
 #include "tm.h"
-
+#include <AvailabilityMacros.h>
+
 /* APPLE LOCAL begin instant off 6414141 */
-#if defined(__APPLE__) && !defined(__STATIC__) && !defined(__ppc__) && !defined(__ppc64__) && !defined(__arm__)
+#if defined(__APPLE__) && !defined(__STATIC__) && !defined(__ppc__) && !defined(__ppc64__) && !defined(__arm__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 #include <vproc.h>
 #if defined(VPROC_HAS_TRANSACTIONS)
 vproc_transaction_t vproc_transaction_begin(vproc_t virtual_proc) __attribute__((weak));
END_OF_PATCH

  if MacOS.version > :tiger and MacOS.version < :lion
    TO = HOMEBREW_PREFIX/'bin/to-brewed-gcc42'
    FRO = HOMEBREW_PREFIX/'bin/to-stock-gcc42'

    def ensure_to_fro
      TO.binwrite switch_to unless TO.exists?
      FRO.binwrite switch_from unless FRO.exists?
      chmod 0755, [TO, FRO]
    end

    def stock_apple_gcc42_build
      if installed? and not (candidates = Dir['/usr/bin/*-apple-darwin*-gcc-4.2.1.5[0-9][0-9][0-9]*']).empty?
        return candidates.sort.first[-4,4]
      end
      if (gcc42 = Pathname.new(Dir['/usr/bin/*-apple-darwin*-gcc-4.2.1'].first)).choke and not gcc42.symlink?
        return `#{gcc42} --version`[/build (5\d{3})/][1]
      end
    end

    insinuate { ensure_to_fro; system 'sudo', TO.to_s }

    # This command also deletes `to-*-gcc42` if our rack is gone.
    uninsinuate do |silent|
      ensure_to_fro
      do_system((silent ? [:silent] : []), 'sudo', FRO.to_s)
    end
  end # :leopard or :snow_leopard?

  def croak_no_ios_sdk
    raise CannotInstallFormulaError, 'Can’t make compilers for ARM; a working iPhoneOS SDK was not found.'
  end

  def install
    ENV.single_arch_binary if build.universal?
    ENV.without_archflags  # The build script takes care of them.

    inreplace 'build_gcc', '@@OPTDIR@@', OPTDIR.to_s
    inreplace 'build_gcc', '@@BREW_CCTOOLBIN@@', (build.with?('arm') ? "#{OPTDIR}/cctools/bin" : '/usr/bin')
    inreplace 'gcc/config.host', '@@RUNNING_32_ON_64@@', ((CPU._64b? and not Target.prefer_64b?) ? 'yes' : 'no')
    if MacOS.version <= :leopard
      inreplace 'gcc/config/rs6000/t-darwin', 'isysroot/Developer/SDKs/MacOSX10.5.sdk', ''
      inreplace 'gcc/config/rs6000/t-darwin', /mmacosx-version-min=10.\d/, "mmacosx-version-min=#{MacOS.version}"
    end

    arm_archs = nil
    if build.with? 'arm'
      arm_toolroot = MacOS.active_developer_dir/'Platforms/iPhoneOS.platform/Developer'
      croak_no_ios_sdk unless arm_toolroot.directory? and (arm_toolroot/'SDKs').directory?
      arm_SDKs = Dir.glob("#{arm_toolroot}/SDKs/iPhoneOS*.sdk")
      croak_no_ios_sdk if arm_SDKs.empty?
      highest_SDK_version = (arm_SDKs.map{ |f| File.basename(f, '.sdk').sub(/^iPhoneOS/, '') }.sort)[-1]
      ENV['ARM_TOOLROOT'] = arm_toolroot.to_s
      ENV['ARM_SYSROOT'] = "#{arm_toolroot}/SDKs/iPhoneOS#{highest_SDK_version}.sdk"
      # This does pick up the correct `lipo` (in {cctools}), thanks to it being in the $PATH.
      lipo_command_line = "lipo -info \"$ARM_SYSROOT/usr/lib/libSystem.dylib\" | cut -d ':' -f 3 -s"
      arm_archs = Utils.popen_read(lipo_command_line).split(' ').select{ |a| a =~ %r{^arm} }.join(' ')
      croak_no_ios_sdk if arm_archs.empty?
    end # build.with? 'arm'

    ENV['LOCAL_MAKEFLAGS'] = ENV['MAKEFLAGS']
    ENV['Build_Root']      = "#{buildpath}/build"

    # Apple’s modifications to GCC presuppose always building with multilib, to an extent that is needlessly awkward to disentangle.
    # Further, building 64‐bit produces unstable results, at best.  As a result, we must always build in 32‐bit mode with multilibs.
    arg1_host_archs      = Target.tool_host_archset._32b_subset.as_build_archs
    arg2_target_archs    = Target.tool_target_archset._32b_subset.as_build_archs
    arg2_target_archs    += " #{arm_archs}" if build.with? 'arm'
    arg3_source_root     = buildpath
    arg4_prefix_2_unused = ''
    arg5_install_prefix  = prefix
    arg6_debugsym_unused = buildpath/'build/sym'

    # With relatively minor patching, Apple’s build_gcc builds & installs right into #prefix for us.
    system buildpath/'build_gcc', arg1_host_archs, arg2_target_archs, arg3_source_root, arg4_prefix_2_unused, arg5_install_prefix,
                                  arg6_debugsym_unused
  end # install

  def caveats
    caveat_text = <<-EOS.undent
      This formula brews compilers from Apple’s custom GCC 4.2.1 sources, build 5666.3
      (the last available from Apple’s open‐source distributions).  All compilers have
      a “-4.2” suffix.
    EOS
    caveat_text += <<-_.undent if CPU.powerpc? and (build.with? 'arm' or not installed?)

      Building the ARM compilers on PowerPC can be problematic.  The only releases of
      the SDK that ran on Power Macs were removed from Apple’s servers years ago, and
      if you can find a copy – the last was v2.2.1, based on Xcode 3.1.2 build 2621a –
      it needs some tweaks with a text editor to work right (a few places online talk
      about just what must be changed).  Further,
          /Developer/Platforms/iPhoneOS.platform/Developer/usr/include/stdint.h
      must be symlinked into the /usr/include directories of any SDK versions you may
      want to use, as Apple forgot to unless you are using GCC 4.0 (and we aren’t, we
      will be using the GCC 4.2 we just built).
    _
    caveat_text += <<-_.undent if MacOS.version > :tiger and MacOS.version < :lion

      Apple shipped an older version of this compiler (build #{stock_apple_gcc42_build}) with the OS, using
      the exact same name, so two extra commands are installed:
          to-brewed-gcc42
          to-stock-gcc42
      These respectively activate & deactivate a network of symlinks which substitute
      brewed Apple GCC 4.2 for the stock copy.  Under brewed GCC, every stock command
      is still available as “<command name>-4.2.1.#{stock_apple_gcc42_build}”, as are their manpages and so
      forth.

      The switchover commands are run automatically whenever the formula is installed
      or uninstalled; apart from entering your password at those times so they can be
      `sudo`ed, you should never need to worry about them.

      CAUTION:  Should the software be removed without using the `brew` command, none
      of the symlinks will point to anything anymore, making your compiler unuseable!
      Should that occur, you must run the `to-stock-gcc42` command to put your system
      back in order.
    _
    caveat_text
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
    arch_words = Target.local_archs.as_arch_flags.split(' ')
    system "#{bin}/gcc-4.2", *arch_words, '-o', 'hello-c', 'hello-c.c'
    for_archs('./hello-c') { |_, cmd| assert_equal "Hello, world!\n", `#{cmd * ' '}` }

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system "#{bin}/g++-4.2", *arch_words, '-o', 'hello-cc', 'hello-cc.cc'
    for_archs('./hello-cc') { |_, cmd| assert_equal("Hello, world!\n", `#{cmd * ' '}`) }
  end # test

  def switch_to; <<-_.undent
    #!/bin/bash
    #### This switches GCC 4.2.1 from the stock build #{stock_apple_gcc42_build} over to the brewed build 5666.3 ####
    #### For use with Leopardbrew on Mac OS 10.5 / 10.6 (no others shipped with GCC 4.2.1) ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    Bin_Pfx=/usr/bin/
    Man1_Pfx=/usr/share/man/man1/
    Opt_Pfx="#{OPTDIR}/apple-gcc42/"

    Short_Names=(c++ cpp g++ gcc gcov)
    Targets=(${Opt_Pfx}{bin,share/man/man1}/{arm,i686,powerpc}-apple-darwin*-{cpp,g{++,cc}}-4.2.1{,.1})
    Dir_Targets=(${Opt_Pfx}lib{,exec}/gcc/{{{i686,powerpc}-apple-darwin*/,share/doc/gcc-}4.2.1,arm-apple-darwin*})

    for Name in "${Short_Names[@]}"; do
      V_Nm="${Name}-4.2.1.#{stock_apple_gcc42_build}"
      Sh_V_Nm="${Name}-4.2"

      Link="${Bin_Pfx}${Name}"  # sanity check – ensures, e.g., that `gcc` doesn’t get you `gcc-4.0`
      if [ -L "$Link" ] && [ $(readlink -n "$Link") != "$Sh_V_Nm" ]; then sudo ln -fs "$Sh_V_Nm" "$Link"; fi
      Link="${Bin_Pfx}${Sh_V_Nm}"  # actual work
      if [ -f "$Link" ] && ! [ -L "$Link" ]; then sudo mv "$Link" "${Link}.1.#{stock_apple_gcc42_build}"; fi
      sudo ln -fs "${Opt_Pfx}${Link#/usr/}" "$Link"

      Link="${Man1_Pfx}${Name}.1"  # for sanity checks – ensure, e.g., that `man gcc` ↛ `man gcc-4.0`
      if [ -e "${Link}.gz" ]; then gunzip "${Link}.gz"; fi  # compressed manpages mess this up
      if [ -L "$Link" ] && [ $(readlink -n "$Link") != "${Sh_V_Nm}.1" ]; then sudo ln -fs "${Sh_V_Nm}.1" "$Link"; fi
      Link="${Man1_Pfx}${Sh_V_Nm}.1"  # actual work
      if [ -f "$Link" ] && ! [ -L "$Link" ]; then sudo mv "$Link" "${Link}.#{stock_apple_gcc42_build}.1"; fi
      sudo ln -fs "${Opt_Pfx}${Link#/usr/}" "$Link"
    done

    for Target in "${Targets[@]}"; do
      Link="/usr/${Target#${Opt_Pfx}}"
      Tail="${Link##*2.1}"; Nose="${Link%${Tail}}"
      if [ -f "$Link" ] && ! [ -L "$Link" ]; then sudo mv "$Link" "${Nose}.#{stock_apple_gcc42_build}${Tail}"; fi
      if [ -e "$Target" ]; then sudo ln -fs "$Target" "$Link"; fi
    done

    for Target in "${Dir_Targets[@]}"; do
      Link="/usr/${Target#${Opt_Pfx}}"
      if [ -L "$Link" ]; then sudo rm -f "$Link"
      elif [ -d "$Link" ]; then sudo mv "$Link" "${Link}.#{stock_apple_gcc42_build}"
      fi
      if [ -e "$Target" ]; then sudo ln -fs "$Target" "$Link"; fi
    done

    echo 'Invocations of Apple GCC 4.2 and its ancillary parts shall henceforth use the brewed versions.'
    _
  end # switch_to

  def switch_from; <<-_.undent
    #!/bin/bash
    #### This switches GCC 4.2.1 from the brewed build 5666.3 back to the stock build #{stock_apple_gcc42_build} ####
    #### For use with Leopardbrew on Mac OS 10.5 / 10.6 (no others shipped with GCC 4.2.1) ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    Opt_Pfx="#{OPTDIR}/apple-gcc42"
    Bin_Pfx=/usr/bin/
    Man1_Pfx=/usr/share/man/man1/

    Short_Names=(c++ cpp g++ gcc gcov)
    Long_Targets=({${Bin_Pfx},${Man1_Pfx}}{i686,powerpc}-apple-darwin*-g{++,cc}-4.2.1.#{stock_apple_gcc42_build}{,.1})
    Delete_Links=({${Bin_Pfx},${Man1_Pfx}}{arm-*,{i686,powerpc}-apple-darwin*-cpp}-4.2.1{,.1} /usr/share/doc/gcc-4.2.1)
    Old_Dir_Targets=(/usr/lib{,exec}/gcc/{arm-*,{i686,powerpc}-apple-darwin*/4.2.1})
    Disembrew_Scripts=(#{HOMEBREW_PREFIX}/bin/to-*-gcc42)

    for Name in "${Short_Names[@]}"; do
      V_Nm="${Name}-4.2.1.#{stock_apple_gcc42_build}"
      Sh_V_Nm="${Name}-4.2"

      Link="${Bin_Pfx}${Name}"  # sanity check – ensures, e.g., that `gcc` ↛ `gcc-4.0`
      if [ -L "$Link" ] && [ "$(readlink -n "$Link")" != "$Sh_V_Nm" ] || ! [ -e "$Link" ]
      then sudo ln -fs$v "$Sh_V_Nm" "$Link"; fi
      Link="${Bin_Pfx}${Sh_V_Nm}"  # actual work
      if [ -L "$Link" ] || ! [ -e "$Link" ]; then sudo ln -fs$v "$V_Nm" "$Link"; fi

      Link="${Man1_Pfx}${Name}.1"  # sanity check – ensures, e.g., that `man gcc` ↛ `man gcc-4.0`
      if [ -L "$Link" ] && [ "$(readlink -n "$Link")" != "${Sh_V_Nm}.1" ] || ! [ -e "$Link" ]
      then sudo ln -fs$v "${Sh_V_Nm}.1" "$Link"; fi
      Link="${Man1_Pfx}${Sh_V_Nm}.1"  # actual work
      if [ -L "$Link" ] || ! [ -e "$Link" ]; then sudo ln -fs$v "${V_Nm}.1" "$Link"; fi
    done

    for Target in "${Long_Targets[@]}"; do
      Tail="${Target##*#{stock_apple_gcc42_build}}"; Nose="${Target%${Tail}}"; Link="${Nose%.#{stock_apple_gcc42_build}}${Tail}"
      if [ -L "$Link" ] || ! [ -e "$Link" ]; then sudo ln -fs$v "${Target##*/}" "$Link"; fi
    done

    for Link in "${Delete_Links[@]}"; do if [ -L "$Link" ]; then sudo rm -f$v "$Link"; fi; done

    for Link in "${Old_Dir_Targets[@]}"; do
      if [ -L "$Link" ]; then sudo rm -f$v "$Link"; fi
      # these have to remain separate or else the symlink gets put inside the symlinked directory!
      if [ -e "${Link}.#{stock_apple_gcc42_build}" ] && ! [ -e "$Link" ]; then
        sudo ln -fs$v "${Link##*/}.#{stock_apple_gcc42_build}" "$Link"
      fi
    done

    echo 'Invocations of Apple GCC 4.2 and its ancillary parts shall henceforth use the stock versions.'

    if ! [ -e "#{HOMEBREW_CELLAR}/apple-gcc42" ]; then
      for Script in "${Disembrew_Scripts[@]}"; do rm -f$v "$Script"; done
    fi
  _
  end # switch_from
end # AppleGcc42

__END__
--- old/build_gcc
+++ new/build_gcc
# - Make a way to detranslate GCC architecture names back to Apple ones.
# - Improve the filtering of architecture names.
# - Since we aren’t using the feature that puts two prefixes on everything, set the “inner” one to the null string.
# - Allow setting the working build directory by environment variable, rather than by having to cd to it before running this script.
# - Use the `lipo` from cctools when building for ARM – it’s newer and can handle ARM slices.
# - Don’t look in weird places for the C++ standard library.
# - Do not set an include directory for outputting the C++ standard library headers.
# - Since older xcodebuild knows nothing of “Path” or “PlatformPath” (and there’s no clue as to what exactly $ARM_SDK ought to hold
#   even if those would be understood), bypass them via an environment variable.
# - Reörder the arm configuration so it is consistent across all methods of setting its initial values.
# - Use the correct $*_CONFIGFLAGS for the build architecture, and reference the 10.5 SDK if building for PPC on a later Darwin.
# - Use the part of the split prefix that we DIDN’T set to the null string.
# - Put shared libraries in the correct location.
# - Use the architecture‐specific tools from cctools, if we are building for ARM and so know they are available.
# - Let our `as` interposer scripts rewrite mistaken -arch flags, and symlink the relevant one as just “as” for each added compiler
#   we build.
# - When building the cross‐hosted compilers and we know cctools are available, make sure they are in $COMPILER_PATH, & set $prefix
#   instead of $DESTDIR.
# - Build the HTML documentation straight into share/doc, not to the hilariously long prefix Apple uses.
# - Don’t symlink to nonexistent files.  Symlink to cctools’ `as` (if available, or else the system one) instead.
# - Don’t forget to build libgcc_s.*.dylib, adjusting * for whether we’re on Tiger or later.
# - Don’t bother copying libgomp.a et al, they’re already in place because we didn’t use the split‐prefix feature.
# - Remove several instances of doubled directory separators.
# - Don’t bother generating debugging data.  It gets discarded.
# - Don’t try to strip libgcc.*.dylib, nor anything in cctools, nor anything under /usr.
# - Don’t chgrp.  It does nothing useful, and as we aren’t in the destination group (“wheel”), it fails messily.
@@ -5,9 +5,10 @@
 
 # -arch arguments are different than configure arguments. We need to
 # translate them.
-
-TRANSLATE_ARCH="sed -e s/ppc/powerpc/ -e s/i386/i686/ -e s/armv6/arm/"
-OMIT_X86_64="sed -e s/x86_64//"
+TRANSLATE_ARCH='sed -e s/ppc64/powerpc64/ -e s/ppc[0-9]*/powerpc/g -e s/i386/i686/ -e s/arm[a-z0-9]*/arm/g'
+DETRANSLATE_ARCH='sed -e s/powerpc/ppc/g -e s/i686/i386/'  # arm & x86_64 don’t need detranslation
+UN_64='sed -e s/powerpc64/powerpc/ -e s/x86_64/i686/'      # we’re going to be `uniq`ing anyway; make sure nothing gets missed
+Uniq_Word_Sort () { local Argv="$*"; echo "$(echo $Argv | tr -s ' ' $'\n' | sort -u | tr -s $'\n' ' ')"; }
 
 # Build GCC the "Apple way".
 # Parameters:
@@ -15,13 +16,13 @@
 # The first parameter is a space-separated list of the architectures
 # the compilers will run on.  For instance, "ppc i386".  If the
 # current machine isn't in the list, it will (effectively) be added.
-HOSTS=`echo $1 | $TRANSLATE_ARCH `
#`
+HOSTS="$(Uniq_Word_Sort "$(echo "$1" | $TRANSLATE_ARCH | $UN_64)")"
 
 # The second parameter is a space-separated list of the architectures the
 # compilers will generate code for.  If the current machine isn't in
 # the list, a compiler for it will get built anyway, but won't be
 # installed.
-TARGETS=`echo $2 | $TRANSLATE_ARCH | $OMIT_X86_64`
#`
+TARGETS="$(Uniq_Word_Sort "$(echo "$2" | $TRANSLATE_ARCH | $UN_64)")"
 
 # The GNU makefile target ('bootstrap' by default).
 BOOTSTRAP=${BOOTSTRAP-bootstrap}
@@ -38,10 +39,10 @@
 # $RC_NONARCH_CFLAGS (and mysteriously prepends '-pipe' thereto).
 # We will allow this to override the default $CFLAGS and $CXXFLAGS.
 
-CFLAGS="-g -O2 ${RC_NONARCH_CFLAGS/-pipe/}"
+cF='-g -Os'; export CFLAGS="$cF" CXXFLAGS="$cF"  # no `as`-bug '-pipe' needed (interposed script does it)
 
 # This isn't a parameter; it is the architecture of the current machine.
-BUILD=`arch | $TRANSLATE_ARCH`
#`
+BUILD="$(arch | $TRANSLATE_ARCH | $UN_64)  # With everything multilib’d, building both i686 & x86_64 compilers’d be inefficient.
 
 # The third parameter is the path to the compiler sources.  There should
 # be a shell script named 'configure' in this directory.  This script
@@ -51,7 +52,7 @@
 # The fourth parameter is the location where the compiler will be installed,
 # normally "/usr".  You can move it once it's built, so this mostly controls
 # the layout of $DEST_DIR.
-DEST_ROOT="$4"
+DEST_ROOT=''
 
 # The fifth parameter is the place where the compiler will be copied once
 # it's built.
@@ -65,7 +66,7 @@
 # The current working directory is where the build will happen.
 # It may already contain a partial result of an interrupted build,
 # in which case this script will continue where it left off.
-DIR=`pwd`
#`
+DIR="${Build_Root:-$(pwd)}"; if ! [ -d "$DIR" ]; then mkdir -p "$DIR"; fi
 
 # This isn't a parameter; it's the version of the compiler that we're
 # about to build.  It's included in the names of various files and
@@ -79,25 +80,24 @@
 # to be built.  It's VERS but only up to the second '.' (if there is one).
 MAJ_VERS=`echo $VERS | sed 's/\([0-9]*\.[0-9]*\)[.-].*/\1/'`
#`
 
+LIPO=@@BREW_CCTOOLBIN@@/lipo  # Varies according to whether we’re accommodating ARM.
+
 # This is the libstdc++ version to use.
 LIBSTDCXX_VERSION=4.2.1
-if [ ! -d "$DEST_ROOT/include/c++/$LIBSTDCXX_VERSION" ]; then
+if ! [ -d "/usr/include/c++/$LIBSTDCXX_VERSION" ]; then
   LIBSTDCXX_VERSION=4.0.0
 fi
-NON_ARM_CONFIGFLAGS="--with-gxx-include-dir=\${prefix}/include/c++/$LIBSTDCXX_VERSION"
+NON_ARM_CONFIGFLAGS="--with-build-sysroot=\"${NON_ARM_SYSROOT:-/}\""
 
-# Build against the MacOSX10.5 SDK for PowerPC.
-PPC_SYSROOT=/Developer/SDKs/MacOSX10.5.sdk
-PPC_CONFIGFLAGS="$NON_ARM_CONFIGFLAGS --with-build-sysroot=\"$PPC_SYSROOT\""
 
 DARWIN_VERS=`uname -r | sed 's/\..*//'`
#`
 echo DARWIN_VERS = $DARWIN_VERS
 
+if [ "$DARWIN_VERS" -gt '9' ]; then PPC_root=/Developer/SDKs/MacOSX10.5.sdk; else PPC_root=/; fi
+PPC_CONFIGFLAGS="--with-build-sysroot=${PPC_SYSROOT:-$PPC_root}"
+
 # APPLE LOCAL begin ARM
-ARM_LIBSTDCXX_VERSION=4.2.1
-ARM_CONFIGFLAGS="--with-gxx-include-dir=/usr/include/c++/$ARM_LIBSTDCXX_VERSION"
-
-if [ -n "$ARM_SDK" ]; then
+if [ -z "$ARM_TOOLROOT" -o -z "$ARM_SYSROOT" ]; then if [ -n "$ARM_SDK" ]; then
 
   ARM_PLATFORM=`xcodebuild -version -sdk $ARM_SDK PlatformPath`
   ARM_SYSROOT=`xcodebuild -version -sdk $ARM_SDK Path`
#`
@@ -127,22 +127,33 @@
   ARM_TOOLROOT=/
 
 fi
-ARM_CONFIGFLAGS="$ARM_CONFIGFLAGS --with-build-sysroot=\"$ARM_SYSROOT\""
+fi
+ARM_LIBSTDCXX_VERSION='4.2.1'
+if ! [ -d "$ARM_SYSROOT/usr/include/c++/$ARM_LIBSTDCXX_VERSION" ]; then
+  ARM_LIBSTDCXX_VERSION='4.0.0'
+fi
+ARM_CONFIGFLAGS="--with-build-sysroot=\"$ARM_SYSROOT\""
+
+case $BUILD in
+  powerpc) BUILD_CONFIGFLAGS="$PPC_CONFIGFLAGS";;
+  i686) BUILD_CONFIGFLAGS="$NON_ARM_CONFIGFLAGS";;
+  arm) BUILD_CONFIGFLAGS="$ARM_CONFIGFLAGS";;
+esac
 
 # If building an ARM target, check that the required directories exist
 # and query the libSystem arm slices to determine which multilibs we should
 # build.
 if echo $TARGETS | grep arm; then
-  if [ ! -d $ARM_SYSROOT ]; then
+  if ! [ -d $ARM_SYSROOT ]; then
     echo "Error: cannot find ARM SDK to build ARM target"
     exit 1
   fi
-  if [ ! -d $ARM_TOOLROOT ]; then
+  if ! [ -d $ARM_TOOLROOT ]; then
     echo "Error: $ARM_TOOLROOT directory is not installed"
     exit 1
   fi
   if [ "x$ARM_MULTILIB_ARCHS" = "x" ] ; then
-    ARM_MULTILIB_ARCHS=`/usr/bin/lipo -info $ARM_SYSROOT/usr/lib/libSystem.dylib | cut -d':' -f 3 | sed -e 's/x86_64//' -e 's/i386//' -e 's/ppc7400//' -e 's/ppc64//' -e 's/^ *//' -e 's/ $//'`
#`
+    ARM_MULTILIB_ARCHS="$($LIPO -info $ARM_SYSROOT/usr/lib/libSystem.dylib | cut -d':' -f 3 | sed -E -e 's/x86_64//' -e 's/i386//' -e 's/ppc[0-9]*//g' -e 's/^ *//' -e 's/ *$//')"
   fi;
   if [ "x$ARM_MULTILIB_ARCHS" == "x" ] ; then
     echo "Error: missing ARM slices in $ARM_SYSROOT"
@@ -166,19 +177,21 @@
 rm -rf $SRC_DIR || exit 1
 mkdir $SRC_DIR || exit 1
 ln -s $ORIG_SRC_DIR/* $SRC_DIR/ || exit 1
+offset="${DIR#${ORIG_SRC_DIR}/}"; if "$offset" != "$DIR"; then rm "$SRC_DIR/${offset%%/*}" || exit 1; fi  # avoid symlink loop
 rm -rf $SRC_DIR/tcl $SRC_DIR/expect $SRC_DIR/dejagnu || exit 1
 # Also remove libstdc++ since it is built from a separate project.
 # rm -rf $SRC_DIR/libstdc++-v3 || exit 1
 # Clean out old specs files
 rm -f /usr/lib/gcc/*/4.0.0/specs
 
 # These are the configure and build flags that are used.
 CONFIGFLAGS="--disable-checking --enable-werror \
-  --prefix=$DEST_ROOT \
+  --prefix=$DEST_DIR \
   --mandir=\${prefix}/share/man \
   --enable-languages=$LANGUAGES \
   --program-transform-name=/^[cg][^.-]*$/s/$/-$MAJ_VERS/ \
-  --with-slibdir=/usr/lib \
+  --enable-shared \
+  --with-slibdir=\${prefix}/lib \
   --build=$BUILD-apple-darwin$DARWIN_VERS"
 
 # Figure out how many make processes to run.
@@ -215,62 +228,62 @@
 mkdir -p $DIR/obj-$BUILD-$BUILD $DIR/dst-$BUILD-$BUILD || exit 1
 cd $DIR/obj-$BUILD-$BUILD || exit 1
 if [ \! -f Makefile ]; then
- $SRC_DIR/configure $bootstrap $CONFIGFLAGS $NON_ARM_CONFIGFLAGS \
+  $SRC_DIR/configure $bootstrap $CONFIGFLAGS $BUILD_CONFIGFLAGS \
    --host=$BUILD-apple-darwin$DARWIN_VERS \
    --target=$BUILD-apple-darwin$DARWIN_VERS || exit 1
 fi
 # Unset RC_DEBUG_OPTIONS because it causes the bootstrap to fail.
 # Also keep unset for cross compilers so that the cross built libraries are
 # comparable to the native built libraries.
 unset RC_DEBUG_OPTIONS
-make $MAKEFLAGS CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-make $MAKEFLAGS html CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-make $MAKEFLAGS DESTDIR=$DIR/dst-$BUILD-$BUILD install-gcc install-target \
-  CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
+make $MAKEFLAGS || exit 1; make $MAKEFLAGS html || exit 1  # don’t need CFLAGS et al when exported
+make $MAKEFLAGS prefix=$DIR/dst-$BUILD-$BUILD install-gcc install-target || exit 1
 
 # Add the compiler we just built to the path, giving it appropriate names.
-D=$DIR/dst-$BUILD-$BUILD/usr/bin
+D=$DIR/dst-$BUILD-$BUILD$DEST_ROOT/bin
 ln -f $D/gcc-$MAJ_VERS $D/gcc || exit 1
 ln -f $D/gcc $D/$BUILD-apple-darwin$DARWIN_VERS-gcc || exit 1
-PATH=$DIR/dst-$BUILD-$BUILD/usr/bin:$PATH
+PATH=$D:$PATH
 
 # The cross-tools' build process expects to find certain programs
 # under names like 'i386-apple-darwin$DARWIN_VERS-ar'; so make them.
 # Annoyingly, ranlib changes behaviour depending on what you call it,
 # so we have to use a shell script for indirection, grrr.
+UNIQUE_ARCHS="$(Uniq_Word_Sort "$TARGETS $HOSTS")"
 rm -rf $DIR/bin || exit 1
 mkdir $DIR/bin || exit 1
-for prog in ar nm ranlib strip lipo ld ; do
-  for t in `echo $TARGETS $HOSTS | sort -u`; do
+for prog in ar nm ranlib strip lipo; do
+  for t in $UNIQUE_ARCHS; do
     P=$DIR/bin/${t}-apple-darwin$DARWIN_VERS-${prog}
-    # APPLE LOCAL begin toolroot
-    if [ $t = "arm" ]; then
-      toolroot=$ARM_TOOLROOT
-    else
-      toolroot=
-    fi
-    # APPLE LOCAL end toolroot
     echo '#!/bin/sh' > $P || exit 1
-    # APPLE LOCAL insert toolroot below
-    echo 'exec '${toolroot}'/usr/bin/'${prog}' "$@"' >> $P || exit 1
+    echo 'exec @@BREW_CCTOOLBIN@@/'${prog}' "$@"' >> $P || exit 1
     chmod a+x $P || exit 1
   done
 done
-for t in `echo $1 $2 | sort -u`; do
-  gt=`echo $t | $TRANSLATE_ARCH`
#`
-  P=$DIR/bin/${gt}-apple-darwin$DARWIN_VERS-as
-  # APPLE LOCAL begin toolroot
-  if [ $gt = "arm" ]; then
-    toolroot=$ARM_TOOLROOT
-  else
-    toolroot=
-  fi
-  # APPLE LOCAL end toolroot
-  echo '#!/bin/sh' > $P || exit 1
-
-  # APPLE LOCAL insert toolroot below
-  echo 'for a; do case $a in -arch) exec '${toolroot}'/usr/bin/as "$@";;  esac; done' >> $P || exit 1
-  echo 'exec '${toolroot}'/usr/bin/as -arch '${t}' "$@"' >> $P || exit 1
+for t in $UNIQUE_ARCHS; do
+  P=$DIR/bin/${t}-apple-darwin$DARWIN_VERS-ld
+  if [ $t = "arm" ]; then toolroot="$ARM_TOOLROOT"; else toolroot= ; fi
+  echo '#!/bin/sh' >$P || exit 1; echo 'exec '${toolroot}'/usr/bin/ld "$@"' >>$P || exit 1
+  chmod a+x $P || exit 1
+  dt="$(echo "$t" | $DETRANSLATE_ARCH)"; P=$DIR/bin/${t}-apple-darwin$DARWIN_VERS-as; cat >$P <<EOT
+#!/bin/sh
+dt=$dt; temp_file=''; prev_was_arch=false; prev_was_o=false; args=()
+for a; do case \$a in
+  -arch) prev_was_arch=true;; -o) prev_was_o=true; args[\${#args[@]}]="\$a";; -*) args[\${#args[@]}]="\$a";;
+  *) if [ \$prev_was_arch != false ]; then dt="\$(echo \$a | ${DETRANSLATE_ARCH})"; prev_was_arch=false
+    elif [ \$prev_was_o != false ]; then prev_was_o=false; args[\${#args[@]}]="\$a"
+    else temp_file=\$a
+      dot_machine="\$(cat "\$temp_file" | egrep -o '[^0-9A-Z_a-z]\\.machine[[:blank:]]+[a-z][0-9_a-z]*')"
+      if [ "x\$dot_machine" != "x" ]; then
+        case \$dot_machine in
+          *ppc64) dt=ppc64;; *ppc*) dt=ppc;; *i[3-9]86) dt=i386;; *x86_64) dt=x86_64;; *arm*) dt=arm;;
+          *) echo 'as:  Unrecognized machine type'; exit 1;;
+        esac
+    fi; fi;;
+esac; done
+exec cat \$temp_file | @@BREW_CCTOOLBIN@@/as -arch \$dt "\${args[@]}"
+EOT
+  [ $? ] || exit 1
   chmod a+x $P || exit 1
 done
 PATH=$DIR/bin:$PATH
@@ -279,15 +292,16 @@
 # one of our hosts, add all of the targets to the list.
 if echo $HOSTS | grep $BUILD
 then
-  CROSS_TARGETS=`echo $TARGETS $HOSTS | tr ' ' '\n' | sort -u`
#`
+  CROSS_TARGETS="$UNIQUE_ARCHS"
 else
-  CROSS_TARGETS="$HOSTS"
+  CROSS_TARGETS="$TARGETS"
 fi
 
 # Build the cross-compilers, using the compiler we just built.
 for t in $CROSS_TARGETS ; do
  if [ $t != $BUILD ] ; then
   mkdir -p $DIR/obj-$BUILD-$t $DIR/dst-$BUILD-$t || exit 1
+   ln -fs $t-apple-darwin$DARWIN_VERS-as $DIR/bin/as
    cd $DIR/obj-$BUILD-$t || exit 1
    if [ \! -f Makefile ]; then
     # APPLE LOCAL begin ARM ARM_CONFIGFLAGS
@@ -302,25 +316,25 @@
       LD_FOR_TARGET=$DIR/bin/${t}-apple-darwin$DARWIN_VERS-ld \
       $SRC_DIR/configure $T_CONFIGFLAGS $ARM_CONFIGFLAGS || exit 1
     elif [ $t = 'powerpc' ] ; then
-      $SRC_DIR/configure $T_CONFIGFLAGS $PPC_CONFIGFLAGS || exit 1
-    else
-      $SRC_DIR/configure $T_CONFIGFLAGS $NON_ARM_CONFIGFLAGS || exit 1
+      TCFLAGS="$cF -m32"; $SRC_DIR/configure $T_CONFIGFLAGS $PPC_CONFIGFLAGS || exit 1
+    elif [ $t = 'i686' ]; then
+      TCFLAGS="$cF -m32"; $SRC_DIR/configure $T_CONFIGFLAGS $NON_ARM_CONFIGFLAGS || exit 1
+    else echo 'unrecognized target architecture!' >2; exit 1
     fi
     # APPLE LOCAL end ARM ARM_CONFIGFLAGS
    fi
-   make $MAKEFLAGS all CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-   make $MAKEFLAGS DESTDIR=$DIR/dst-$BUILD-$t install-gcc install-target \
-     CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
+   make $MAKEFLAGS all || exit 1
+   make $MAKEFLAGS prefix=$DIR/dst-$BUILD-$t install-gcc install-target || exit 1
 
    # Add the compiler we just built to the path.
-   PATH=$DIR/dst-$BUILD-$t/usr/bin:$PATH
+   PATH=$DIR/dst-$BUILD-$t$DEST_ROOT/bin:$PATH
  fi
 done
 
 # Rearrange various libraries, for no really good reason.
 for t in $CROSS_TARGETS ; do
   DT=$DIR/dst-$BUILD-$t
-  D=`echo $DT/usr/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS`
#`
+  D=$(echo $DT$DEST_ROOT/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS)
   mv $D/static/libgcc.a $D/libgcc_static.a || exit 1
   mv $D/kext/libgcc.a $D/libcc_kext.a || exit 1
   rm -r $D/static $D/kext || exit 1
@@ -337,6 +351,7 @@
   if [ $h != $BUILD ] ; then
     for t in $TARGETS ; do
       mkdir -p $DIR/obj-$h-$t $DIR/dst-$h-$t || exit 1
+      ln -fs $t-apple-darwin$DARWIN_VERS-as $DIR/bin/as
       cd $DIR/obj-$h-$t || exit 1
       if [ $h = $t ] ; then
 	pp=
@@ -360,27 +375,24 @@
 	# APPLE LOCAL end ARM ARM_CONFIGFLAGS
       fi
 
+      ORIG_COMPILER_PATH=$COMPILER_PATH
       # For ARM, we need to make sure it picks up the ARM_TOOLROOT versions
       # of the linker and cctools.
       if [ $t = 'arm' ] ; then
-        ORIG_COMPILER_PATH=$COMPILER_PATH
         export COMPILER_PATH=$ARM_TOOLROOT/usr/bin:$COMPILER_PATH
+      else export COMPILER_PATH=@@BREW_CCTOOLBIN@@:$COMPILER_PATH
       fi
 
       if [ $h = $t ] ; then
-	  make $MAKEFLAGS all CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-	  make $MAKEFLAGS DESTDIR=$DIR/dst-$h-$t install-gcc install-target \
-	      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
+          make $MAKEFLAGS all || exit 1
+          make "$MAKEFLAGS" prefix="$DIR/dst-$h-$t" install-gcc install-target || exit 1
       else
-	  make $MAKEFLAGS all-gcc CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-	  make $MAKEFLAGS DESTDIR=$DIR/dst-$h-$t install-gcc \
-	      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
+          make $MAKEFLAGS all-gcc || exit 1
+          make "$MAKEFLAGS" prefix="$DIR/dst-$h-$t" install-gcc || exit 1
       fi
 
-      if [ $t = 'arm' ] ; then
         export COMPILER_PATH=$ORIG_COMPILER_PATH
         unset ORIG_COMPILER_PATH
-      fi
     done
   fi
 done
@@ -395,7 +407,7 @@
 rm -rf * || exit 1
 
 # HTML documentation
-HTMLDIR="/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.DeveloperTools.docset/Contents/Resources/Documents/documentation/DeveloperTools"
+HTMLDIR="/share/doc"
 mkdir -p ".$HTMLDIR" || exit 1
 cp -Rp $DIR/obj-$BUILD-$BUILD/gcc/HTML/* ".$HTMLDIR/" || exit 1
 
@@ -420,36 +432,35 @@
   done
   for f in $LIBEXEC_FILES ; do
     if file $DIR/dst-*-$t$DL/$f | grep -q 'Mach-O executable' ; then
-      lipo -output .$DL/$f -create $DIR/dst-*-$t$DL/$f || exit 1
+      $LIPO -output .$DL/$f -create $DIR/dst-*-$t$DL/$f || exit 1
     else
       cp -p $DIR/dst-$BUILD-$t$DL/$f .$DL/$f || exit 1
     fi
   done
-  ln -s ../../../../bin/as .$DL/as
-  ln -s ../../../../bin/ld .$DL/ld
+  ln -s @@BREW_CCTOOLBIN@@/as .$DL/as
 done
 
 # bin
 # The native drivers ('native' is different in different architectures).
 BIN_FILES=`ls $DIR/dst-$BUILD-$BUILD$DEST_ROOT/bin | grep '^[^-]*-[0-9.]*$' \
   | grep -v gccbug | grep -v gcov || exit 1`
#`
 mkdir .$DEST_ROOT/bin
 for f in $BIN_FILES ; do
-  lipo -output .$DEST_ROOT/bin/$f -create $DIR/dst-*$DEST_ROOT/bin/$f || exit 1
+  $LIPO -output .$DEST_ROOT/bin/$f -create $DIR/dst-*$DEST_ROOT/bin/$f || exit 1
 done
 # gcov, which is special only because it gets built multiple times and lipo
 # will complain if we try to add two architectures into the same output.
 TARG0=`echo $TARGETS | cut -d ' ' -f 1`
#`
-lipo -output .$DEST_ROOT/bin/gcov-$MAJ_VERS -create \
+$LIPO -output .$DEST_ROOT/bin/gcov-$MAJ_VERS -create \
   $DIR/dst-*-$TARG0$DEST_ROOT/bin/*gcov* || exit 1
 # The fully-named drivers, which have the same target on every host.
 for t in $TARGETS ; do
-  lipo -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-gcc-$VERS -create \
+  $LIPO -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-gcc-$VERS -create \
     $DIR/dst-*-$t$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-gcc-$VERS || exit 1
-  lipo -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-cpp-$VERS -create \
+  $LIPO -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-cpp-$VERS -create \
     $DIR/dst-*-$t$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-cpp-$VERS || exit 1
   if [ $BUILD_CXX -eq 1 ]; then
-    lipo -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-g++-$VERS -create \
+    $LIPO -output .$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-g++-$VERS -create \
     $DIR/dst-*-$t$DEST_ROOT/bin/$t-apple-darwin$DARWIN_VERS-g++* || exit 1
   fi
 done
@@ -460,7 +471,16 @@
   cp -Rp $DIR/dst-$BUILD-$t$DEST_ROOT/lib/gcc/$t-apple-darwin$DARWIN_VERS \
     .$DEST_ROOT/lib/gcc || exit 1
 done
+for libname in libgcc_s.1.dylib libgcc_s.10.4.dylib libgcc_s.10.5.dylib; do   # don`t forget libgcc!
+  if [ -e $DIR/obj-$BUILD-$BUILD/gcc/$libname ]; then
+    $LIPO -output .$DEST_ROOT/lib/$libname -create $DIR/obj-$BUILD-*/gcc/$libname || exit 1
+  fi
+done
+for link in libgcc_s.1.0.dylib libgcc_s_ppc64.1.dylib libgcc_s_x86_64.1.dylib; do
+  ln -s libgcc_s.1.dylib .$DEST_ROOT/lib/$link
+done
 
+if [ 0 != 0 ]; then  # Don’t bother, it’s already in place.
 # APPLE LOCAL begin native compiler support
 # libgomp is not built for ARM
 LIBGOMP_TARGETS=`echo $TARGETS | sed -E -e 's/(^|[[:space:]])arm($|[[:space:]])/ /'`
#`
@@ -489,6 +509,7 @@
     done
 done
 # APPLE LOCAL end native compiler support
+fi
 
 if [ $BUILD_CXX -eq 1 ]; then
 for t in $TARGETS ; do
@@ -518,7 +539,7 @@
 # providing them.
 cd $SRC_DIR/more-hdrs
 for h in `echo *.h` ; do
-  if [ ! -f /usr/include/$h -o -L /usr/include/$h ] ; then
+  if [ \! -f /usr/include/$h -o -L /usr/include/$h ] ; then
     cp -R $h $DEST_DIR$HEADERPATH/$h || exit 1
     for t in $TARGETS ; do
       THEADERPATH=$DEST_DIR$DEST_ROOT/lib/gcc/${t}-apple-darwin$DARWIN_VERS/$VERS/include
@@ -555,16 +576,16 @@
 	-liberty -L$DIR/dst-$BUILD-$h$DEST_ROOT/lib/                           \
 	-L$DIR/dst-$BUILD-$h$DEST_ROOT/$h-apple-darwin$DARWIN_VERS/lib/                    \
         -L$DIR/obj-$h-$BUILD/libiberty/                                        \
-	-o $DEST_DIR/$DEST_ROOT/bin/tmp-$h-gcc-$MAJ_VERS || exit 1
+	-o $DEST_DIR$DEST_ROOT/bin/tmp-$h-gcc-$MAJ_VERS || exit 1
     $DIR/dst-$BUILD-$h$DEST_ROOT/bin/$h-apple-darwin$DARWIN_VERS-gcc-$VERS     \
 	$ORIG_SRC_DIR/driverdriver.c                               \
 	-DPDN="\"-apple-darwin$DARWIN_VERS-cpp-$VERS\""                                    \
 	-DIL="\"$DEST_ROOT/bin/\"" -I  $ORIG_SRC_DIR/include                   \
 	-I  $ORIG_SRC_DIR/gcc -I  $ORIG_SRC_DIR/gcc/config                     \
 	-liberty -L$DIR/dst-$BUILD-$h$DEST_ROOT/lib/                           \
 	-L$DIR/dst-$BUILD-$h$DEST_ROOT/$h-apple-darwin$DARWIN_VERS/lib/                    \
         -L$DIR/obj-$h-$BUILD/libiberty/                                        \
-	-o $DEST_DIR/$DEST_ROOT/bin/tmp-$h-cpp-$MAJ_VERS || exit 1
+	-o $DEST_DIR$DEST_ROOT/bin/tmp-$h-cpp-$MAJ_VERS || exit 1
     if [ $BUILD_CXX -eq 1 ]; then
 	$DIR/dst-$BUILD-$h$DEST_ROOT/bin/$h-apple-darwin$DARWIN_VERS-gcc-$VERS     \
 	    $ORIG_SRC_DIR/driverdriver.c                               \
@@ -574,28 +595,26 @@
 	    -liberty -L$DIR/dst-$BUILD-$h$DEST_ROOT/lib/                           \
 	    -L$DIR/dst-$BUILD-$h$DEST_ROOT/$h-apple-darwin$DARWIN_VERS/lib/                    \
             -L$DIR/obj-$h-$BUILD/libiberty/                                        \
-	    -o $DEST_DIR/$DEST_ROOT/bin/tmp-$h-g++-$MAJ_VERS || exit 1
+	    -o $DEST_DIR$DEST_ROOT/bin/tmp-$h-g++-$MAJ_VERS || exit 1
     fi
 done
 
-lipo -output $DEST_DIR/$DEST_ROOT/bin/gcc-$MAJ_VERS -create \
-  $DEST_DIR/$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
-rm $DEST_DIR/$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
-lipo -output $DEST_DIR/$DEST_ROOT/bin/cpp-$MAJ_VERS -create \
-  $DEST_DIR/$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
-rm $DEST_DIR/$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
+$LIPO -output $DEST_DIR$DEST_ROOT/bin/gcc-$MAJ_VERS -create $DEST_DIR$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
+rm $DEST_DIR$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
+$LIPO -output $DEST_DIR$DEST_ROOT/bin/cpp-$MAJ_VERS -create $DEST_DIR$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
+rm $DEST_DIR$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
 
 if [ $BUILD_CXX -eq 1 ]; then
-  lipo -output $DEST_DIR/$DEST_ROOT/bin/g++-$MAJ_VERS -create \
-       $DEST_DIR/$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
-  ln -f $DEST_DIR/$DEST_ROOT/bin/g++-$MAJ_VERS $DEST_DIR/$DEST_ROOT/bin/c++-$MAJ_VERS || exit 1
-  rm $DEST_DIR/$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
+  $LIPO -output $DEST_DIR$DEST_ROOT/bin/g++-$MAJ_VERS -create $DEST_DIR$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
+  ln -f $DEST_DIR$DEST_ROOT/bin/g++-$MAJ_VERS $DEST_DIR/bin/c++-$MAJ_VERS || exit 1
+  rm $DEST_DIR$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
 
   # Remove extraneous stuff
-  rm -rf $DEST_DIR/$DEST_ROOT/lib/gcc/*/*/include/c++
+  rm -rf $DEST_DIR$DEST_ROOT/lib/gcc/*/*/include/c++
 fi
 
 
+if [ 0 != 0 ]; then  # Don’t bother; we just discard it anyway.
 ########################################
 # Create SYM_DIR with information required for debugging.
 
@@ -614,20 +633,17 @@
   | cpio -pdml $SYM_DIR || exit 1
 # Save source files.
 mkdir $SYM_DIR/src || exit 1
+fi
 cd $DIR || exit 1
-find obj-* -name \*.\[chy\] -print | cpio -pdml $SYM_DIR/src || exit 1
 
 ########################################
 # Remove debugging information from DEST_DIR.
 
-find $DEST_DIR -perm -0111 \! -name fixinc.sh \
-    \! -name mkheaders \! -name libstdc++.dylib -type f -print \
-  | xargs strip || exit 1
+find $DEST_DIR -perm -0111 \! -name fixinc.sh \! -name 'libgcc_s.*.dylib' \! -name libstdc++.dylib \
+  \! -name mkheaders \! -path '@@OPTDIR@@/cctools/*' \! -path '/usr/*' -type f -print | xargs strip || exit 1
 find $DEST_DIR -name \*.a -print | xargs strip -SX || exit 1
 find $DEST_DIR -name \*.a -print | xargs ranlib || exit 1
 find $DEST_DIR -name \*.dSYM -print | xargs rm -r || exit 1
-chgrp -h -R wheel $DEST_DIR
-chgrp -R wheel $DEST_DIR
 
 # Done!
 exit 0
--- old/config/mh-ppc-darwin
+++ new/config/mh-ppc-darwin
# Make the optimization level “-Os”, to match everywhere else we changed it.
@@ -2,4 +2,4 @@
 # position-independent-code -- the usual default on Darwin. This fix speeds
 # compiles by 3-5%.
 
-BOOT_CFLAGS=-g -O2 -mdynamic-no-pic
+BOOT_CFLAGS = -g -Os -mdynamic-no-pic
--- old/config/mh-x86-darwin
+++ new/config/mh-x86-darwin
# - Make the optimization level “-Os”, to match everywhere else we changed it.
# - Fix a Make‐variable assignment to use $(shell ...) instead of `...`.
@@ -2,8 +2,8 @@
 # The -mdynamic-no-pic ensures that the compiler executable is built without
 # position-independent-code -- the usual default on Darwin.
 
-BOOT_CFLAGS=-g -O2 -mdynamic-no-pic
+BOOT_CFLAGS = -g -Os -mdynamic-no-pic
 
 # For hosts after darwin10 we want to pass in -no-pie
-BOOT_LDFLAGS=`case ${host} in *-*-darwin[1][1-9]*) echo -Wl,-no_pie ;; esac;`
#`
+BOOT_LDFLAGS := $(shell case ${host} in *-*-darwin1[1-9]*|*-*-darwin[2-9][0-9]*) echo -Wl,-no_pie;; esac)
 LDFLAGS=$(BOOT_LDFLAGS)
--- old/gcc/c-incpath.c
+++ new/gcc/c-incpath.c
# Fix a signedness mismatch that only becomes apparent with uniformly 64‐bit values.
@@ -236,7 +236,7 @@
 	  /* If it is a regular file and if it is large enough to be a header-
 	     map, see if it really is one. */
 	  if (fstat (fileno (f), &f_info) == 0 && S_ISREG(f_info.st_mode)
-	    && f_info.st_size >= sizeof(struct hmap_header_map))
+	    && f_info.st_size >= (off_t) sizeof(struct hmap_header_map))
 	    {
 	      unsigned   headermap_size = f_info.st_size;
 
--- old/gcc/config/arm/arm.c
+++ new/gcc/config/arm/arm.c
# Initialize a variable declaration (that otherwise causes a spurious compiler warning in “warnings are fatal” mode).
@@ -7191,7 +7191,7 @@
 neon_output_logic_immediate (const char *mnem, rtx *op2, enum machine_mode mode,
 			     int inverse, int quad)
 {
-  int width, is_valid;
+  int width = 0, is_valid;
   static char templ[40];
   
   is_valid = neon_immediate_valid_for_logic (*op2, mode, inverse, op2, &width);
--- old/gcc/config/arm/lib1funcs.asm
+++ new/gcc/config/arm/lib1funcs.asm
# - Fix a critical typo in the armv7 #defines.
# - Manually assemble two armv6 instructions the assembler inexplicably refuses to generate.  Since Apple’s as doesn’t do “.4byte”,
#   express each as four discrete .bytes in reverse order.
@@ -187,7 +187,7 @@
 	ldr     lr, [sp], #8 ; \
 	bx      lr
 /* APPLE LOCAL begin v7 support. Merge from mainline */
-#if definded (__thumb2__)
+#if defined (__thumb2__)
 #define RETLDM1(...) \
 	pop     {__VA_ARGS__, lr} ; \
 	bx      lr
@@ -1483,14 +1483,14 @@
 #if (__ARM_ARCH__ == 6)
 #ifdef L_save_vfp_d8_d15_regs 
         ARM_FUNC_START save_vfp_d8_d15_regs
-        vpush {d8-d15}
+        .byte 0x10, 0x8b, 0x2d, 0xed
         RET
         FUNC_END save_vfp_d8_d15_regs
 #endif
 
 #ifdef L_restore_vfp_d8_d15__regs
         ARM_FUNC_START restore_vfp_d8_d15_regs
-        vpop {d8-d15}
+        .byte 0x10, 0x8b, 0xbd, 0xec
         RET
         FUNC_END restore_vfp_d8_d15_regs
 #endif
--- old/gcc/config/darwin.h
+++ new/gcc/config/darwin.h
# Remove all mentions of “crt0” from option specifications.  No such file exists on the Darwin systems we target, & GCC not finding
# it will cause compilation failures at _best_.
@@ -481,9 +481,7 @@
        %:version-compare(>< 10.5 10.6 mmacosx-version-min= -lgcc_s.10.5)   \
#:"
        -lgcc}"
 
-/* We specify crt0.o as -lcrt0.o so that ld will search the library path.
-
-   crt3.o provides __cxa_atexit on systems that don't have it.  Since
+/* crt3.o provides __cxa_atexit on systems that don’t have it.  Since
    it's only used with C++, which requires passing -shared-libgcc, key
    off that to avoid unnecessarily adding a destructor to every
    powerpc program built.  */
@@ -494,15 +492,8 @@
   "%{Zdynamiclib: %(darwin_dylib1) }					    \
    "/* APPLE LOCAL link optimizations 6499452 */"			    \
    %{!Zdynamiclib:%{Zbundle:%{!static: %(darwin_bundle1)}}		    \
-     %{!Zbundle:%{pg:%{static:-lgcrt0.o}				    \
-                     %{!static:%{object:-lgcrt0.o}			    \
-                               %{!object:%{preload:-lgcrt0.o}		    \
-                                 %{!preload:-lgcrt1.o %(darwin_crt2)}}}}    \
-                %{!pg:%{static:-lcrt0.o}				    \
-                      %{!static:%{object:-lcrt0.o}			    \
-                                %{!object:%{preload:-lcrt0.o}		    \
-                                  %{!preload: %(darwin_crt1)		    \
-					      %(darwin_crt2)}}}}}}	    \
+                  %{!Zbundle:%{pg:%{!static:%{!object:%{!preload:-lgcrt1.o %(darwin_crt2)}}}} \
+                             %{!pg:%{!static:%{!object:%{!preload: %(darwin_crt1) %(darwin_crt2)}}}}}} \
   %{shared-libgcc:							    \
     %{!miphoneos-version-min=*:						    \
       %:version-compare(< 10.5 mmacosx-version-min= crt3.o%s)}}"
--- old/gcc/config/i386/t-darwin
+++ new/gcc/config/i386/t-darwin
# Remove bug‐workaround “-pipe” flag to let our `as` interposer script work properly.
@@ -17,6 +19,6 @@
 # it to not properly process the first # directive, causing temporary
 # file names to appear in stabs, causing the bootstrap to fail.  Using -pipe
 # works around this by not having any temporary file names.
-TARGET_LIBGCC2_CFLAGS = -fPIC -pipe
+TARGET_LIBGCC2_CFLAGS = -fPIC  # “-pipe” moved to interposer script
 TARGET_LIBGCC2_STATIC_CFLAGS = -mmacosx-version-min=10.4
 # APPLE LOCAL end gcov 5573505
--- old/gcc/config/i386/t-darwin64
+++ new/gcc/config/i386/t-darwin64
# Remove bug‐workaround “-pipe” flag to let our `as` interposer script work properly.
@@ -7,6 +11,6 @@
 # it to not properly process the first # directive, causing temporary
 # file names to appear in stabs, causing the bootstrap to fail.  Using -pipe
 # works around this by not having any temporary file names.
-TARGET_LIBGCC2_CFLAGS = -fPIC -pipe
+TARGET_LIBGCC2_CFLAGS = -fPIC  # “-pipe” moved to interposer script
 TARGET_LIBGCC2_STATIC_CFLAGS = -mmacosx-version-min=10.4
 # APPLE LOCAL end gcov 5573505
--- old/gcc/config/rs6000/t-darwin
+++ new/gcc/config/rs6000/t-darwin
# Remove bug‐workaround “-pipe” flag to let our `as` interposer script work properly.
@@ -21,7 +21,7 @@
 # file names to appear in stabs, causing the bootstrap to fail.  Using -pipe
 # works around this by not having any temporary file names.
 # APPLE LOCAL begin gcov 5573505
-TARGET_LIBGCC2_CFLAGS = -Wa,-force_cpusubtype_ALL -pipe
+TARGET_LIBGCC2_CFLAGS = -Wa,-force_cpusubtype_ALL  # “-pipe” moved to interposer script
 TARGET_LIBGCC2_STATIC_CFLAGS = -mmacosx-version-min=10.4
 # APPLE LOCAL end gcov 5573505
 
--- old/gcc/config/t-darwin
+++ new/gcc/config/t-darwin
# Remove bug‐workaround “-pipe” flag to let our `as` interposer script work properly.
@@ -50,4 +52,4 @@
 # it to not properly process the first # directive, causing temporary
 # file names to appear in stabs, causing the bootstrap to fail.  Using -pipe
 # works around this by not having any temporary file names.
-TARGET_LIBGCC2_CFLAGS = -fPIC -pipe
+TARGET_LIBGCC2_CFLAGS = -fPIC  # “-pipe” moved to interposer script
--- old/gcc/config/t-slibgcc-darwin
+++ new/gcc/config/t-slibgcc-darwin
# Remove a redundant operation.
@@ -55,8 +55,6 @@
 	  rm -f $${mlib}/$@ || exit 1 ; \
 	  $(LN_S) ../$@ $${mlib}/$@ || exit 1 ; \
 	done
-	MLIBS=`$(GCC_FOR_TARGET) --print-multi-lib \
-		| sed -e 's/;.*$$//' -e '/^\.$$/d'` ; \
#`
 	for mlib in '' $$MLIBS ; do \
 	  $(STRIP_FOR_TARGET) -o $(@)_T$${mlib} \
 	    -s $(SHLIB_VERPFX).$(*).ver -c -u \
--- old/gcc/config.gcc
+++ new/gcc/config.gcc
# Consolidate needless redundancy.
@@ -391,7 +391,7 @@
   # APPLE LOCAL 5681645
   tmake_file="t-darwin ${cpu_type}/t-darwin"
   target_gtfiles="\$(srcdir)/config/darwin.c"
-  extra_options="${extra_options} darwin.opt"
+  extra_options="${extra_options} darwin.opt ${cpu_type}/darwin.opt"
   c_target_objs="darwin-c.o"
   cxx_target_objs="darwin-c.o"
   extra_objs="darwin.o"
@@ -779,7 +779,6 @@
 	;;
 # APPLE LOCAL begin ARM darwin target
 arm*-*-darwin*)
-	extra_options="${extra_options} arm/darwin.opt"
         tm_file="${tm_file} arm/darwin.h"
         tmake_file="${tmake_file} arm/t-slibgcc-iphoneos"
 	extra_headers="arm_neon.h"
@@ -1047,17 +1046,15 @@
 	# APPLE LOCAL mainline
 	with_cpu=${with_cpu:-core2}
 	# APPLE LOCAL Macintosh alignment 2002-2-19 --ff
-	extra_options="${extra_options} i386/darwin.opt"
 	# APPLE LOCAL 4099000 5681645
-	tmake_file="${tmake_file} t-slibgcc-darwin i386/t-darwin"
+	tmake_file="${tmake_file} t-slibgcc-darwin"
 	;;
 x86_64-*-darwin*)
 	# APPLE LOCAL mainline
 	# Deleted with_arch
 	# APPLE LOCAL mainline
 	with_cpu=${with_cpu:-core2}
 	# APPLE LOCAL Macintosh alignment 2002-2-19 --ff
-	extra_options="${extra_options} i386/darwin.opt"
 	tmake_file="t-darwin ${cpu_type}/t-darwin64 t-slibgcc-darwin"
 	tm_file="${tm_file} ${cpu_type}/darwin64.h"
 	;;
@@ -1746,7 +1743,6 @@
 powerpc-*-darwin*)
 	# APPLE LOCAL ARM 5681645
 	tmake_file="${tmake_file} t-slibgcc-darwin"
-	extra_options="${extra_options} rs6000/darwin.opt"
 	# APPLE LOCAL mainline candidate 2006-06-22 4512244
 	extra_parts="${extra_parts} crt2.o"
 	case ${target} in
# Consolidate needless redundancy.
@@ -1766,7 +1762,6 @@
 	tm_file="${tm_file} ${cpu_type}/darwin8.h ${cpu_type}/darwin64.h"
 	# APPLE LOCAL ARM 5681645
 	tmake_file="${tmake_file} t-slibgcc-darwin"
-	extra_options="${extra_options} ${cpu_type}/darwin.opt"
 	# We're omitting t-darwin8 to avoid building any multilibs
 	extra_headers=altivec.h
 	;;
--- old/gcc/config.host
+++ new/gcc/config.host
# Set use_long_long_for_widest_fast_int to [a value which shall be determined at brewing time].  It must equal “yes” instead of “no”
# if, and only if, we are building 32‐bit on 64‐bit hardware.
@@ -95,6 +95,7 @@
     # Default size of memory to set aside for precompiled headers
     host_xm_defines='DARWIN_PCH_ADDR_SPACE_SIZE=1024*1024*1024'
     # APPLE LOCAL end ARM native compiler support
+    use_long_long_for_widest_fast_int=@@RUNNING_32_ON_64@@
     ;;
 esac
 
--- old/gcc/configure
+++ new/gcc/configure
# - Convert `as --version` to `as -v`, because Apple’s as doesn’t do long options.  Give it null input, using `echo`, so it doesn’t
#   hang waiting for program text.
# - Chop out some other option‐flag arguments that Apple’s as can’t grok, leading to false‐negative test results.
@@ -14220,7 +14220,7 @@
   # ??? There exists an elf-specific test that will crash
   # the assembler.  Perhaps it's better to figure out whether
   # arbitrary sections are supported and try the test.
-  as_ver=`$gcc_cv_as --version 2>/dev/null | sed 1q`
#`
+  as_ver=`echo '' | $gcc_cv_as -v 2>/dev/null | sed 1q` # Apple`s as hangs waiting for input, even with -v
   if echo "$as_ver" | grep GNU > /dev/null; then
     as_ver=`echo $as_ver | sed -e 's/GNU assembler \([0-9.][0-9.]*\).*/\1/'`
#`
     as_major=`echo $as_ver | sed 's/\..*//'`
#`
@@ -14365,7 +14365,7 @@
 fi
   elif test x$gcc_cv_as != x; then
     echo '.section .rodata.str, "aMS", @progbits, 1' > conftest.s
-    if { ac_try='$gcc_cv_as --fatal-warnings -o conftest.o conftest.s >&5'
+    if { ac_try='$gcc_cv_as -o conftest.o conftest.s >&5'  # Apple’s as does not grok long options
   { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
   (eval $ac_try) 2>&5
   ac_status=$?
@@ -14397,7 +14397,7 @@
 fi
   elif test x$gcc_cv_as != x; then
     echo '.section .rodata.str, "aMS", %progbits, 1' > conftest.s
-    if { ac_try='$gcc_cv_as --fatal-warnings -o conftest.o conftest.s >&5'
+    if { ac_try='$gcc_cv_as -o conftest.o conftest.s >&5'  # Apple’s as does not grok long options
   { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
   (eval $ac_try) 2>&5
   ac_status=$?
@@ -14435,7 +14435,7 @@
 fi
   elif test x$gcc_cv_as != x; then
     echo '.section .text,"axG",@progbits,.foo,comdat' > conftest.s
-    if { ac_try='$gcc_cv_as --fatal-warnings -o conftest.o conftest.s >&5'
+    if { ac_try='$gcc_cv_as -o conftest.o conftest.s >&5'  # Apple’s as does not grok long options
   { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
   (eval $ac_try) 2>&5
   ac_status=$?
@@ -14469,7 +14469,7 @@
 fi
   elif test x$gcc_cv_as != x; then
     echo '.section .text,"axG",%progbits,.foo,comdat' > conftest.s
-    if { ac_try='$gcc_cv_as --fatal-warnings -o conftest.o conftest.s >&5'
+    if { ac_try='$gcc_cv_as -o conftest.o conftest.s >&5'  # Apple’s as does not grok long options
   { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
   (eval $ac_try) 2>&5
   ac_status=$?
@@ -14612,7 +14612,7 @@
 	leal	foo@NTPOFF(%ecx), %eax'
#'
 	tls_first_major=2
 	tls_first_minor=14
-	tls_as_opt=--fatal-warnings
+	tls_as_opt=  # Apple’s as does not grok long options
 	;;
   x86_64-*-*)
     conftest_s='
#'
@@ -14627,7 +14627,7 @@
 	movq	$foo@TPOFF, %rax'
#'
 	tls_first_major=2
 	tls_first_minor=14
-	tls_as_opt=--fatal-warnings
+	tls_as_opt=  # Apple’s as does not grok long options
 	;;
   ia64-*-*)
     conftest_s='
#'
@@ -14688,7 +14688,7 @@
 	addi 9,9,x2@tprel@l'
#'
 	tls_first_major=2
 	tls_first_minor=14
-	tls_as_opt="-a32 --fatal-warnings"
+	tls_as_opt=  # Apple’s as does not grok “-a32”, nor long options
 	;;
   powerpc64-*-*)
     conftest_s='
#'
@@ -14722,7 +14722,7 @@
 	nop'
#'
 	tls_first_major=2
 	tls_first_minor=14
-	tls_as_opt="-a64 --fatal-warnings"
+	tls_as_opt=  # Apple’s as does not grok “-a64”, nor long options
 	;;
   s390-*-*)
     conftest_s='
#'
@@ -15718,7 +15718,7 @@
 fi
   elif test x$gcc_cv_as != x; then
     echo "$conftest_s" > conftest.s
-    if { ac_try='$gcc_cv_as -a32 -o conftest.o conftest.s >&5'
+    if { ac_try='$gcc_cv_as -o conftest.o conftest.s >&5'  # Apple’s as does not grok “-a32”
   { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
   (eval $ac_try) 2>&5
   ac_status=$?
--- old/gcc/gcc.c
+++ new/gcc/gcc.c
# Erase all attempts to load libssp, which Apple had removed but not cleaned up after.  Leopard et seq. provide SSP internally.
@@ -694,7 +694,7 @@
 #ifdef TARGET_LIBC_PROVIDES_SSP
 #define LINK_SSP_SPEC "%{fstack-protector:}"
 #else
-#define LINK_SSP_SPEC "%{fstack-protector|fstack-protector-all:-lssp_nonshared -lssp}"
+#define LINK_SSP_SPEC "%{fstack-protector|fstack-protector-all:%eApple GCC only supports -fstack-protector et al on newer OS versions.}"
 #endif
 #endif
 
# Prevent a spurious equals sign from being prefixed to printed lists of default search directories.
@@ -2634,7 +2634,7 @@
   info.first_time = true;
 
   obstack_grow (&collect_obstack, prefix, strlen (prefix));
-  obstack_1grow (&collect_obstack, '=');
+  if (prefix[0]) obstack_1grow (&collect_obstack, '=');
 
   for_each_path (paths, do_multi, 0, add_to_obstack, &info);
 
--- old/gcc/local-alloc.c
+++ new/gcc/local-alloc.c
# Fix some variable‐size mismatches that only become apparent with 64‐bit pointers.
@@ -901,7 +901,7 @@
 	  /* APPLE LOCAL begin 5695218 */
 	  if (reg_inheritance_matrix)
 	    {
-	      int dstregno;
+	      long dstregno;
 		if (REG_P (dest))
 		{
 		  dstregno = REGNO (dest);
@@ -2693,9 +2693,9 @@
 reg_inheritance_1 (rtx *px, void *data)
 {
   rtx x = *px;
-  unsigned int srcregno, dstregno;
+  unsigned long srcregno, dstregno;
 
-  dstregno = (int)data;
+  dstregno = (long)data;
 #ifdef TARGET_386
   /*
     Ugly special case: When moving a DI/SI/mode constant into an FP
--- old/gcc/Makefile.in
+++ new/gcc/Makefile.in
# Improve the consistency of CFLAGS across stages.
@@ -157,7 +157,7 @@
 LDFLAGS = @LDFLAGS@
 STAGE1_CFLAGS = -g @stage1_cflags@
 STAGE1_CHECKING_CFLAGS = -DENABLE_CHECKING -DENABLE_ASSERT_CHECKING
-BOOT_CFLAGS = -g -O2
+BOOT_CFLAGS = -g -Os
 
 # Flags to determine code coverage. When coverage is disabled, this will
 # contain the optimization flags, as you normally want code coverage
# Adjust for not using the split‐prefix feature (and correct an overlooked bare `pwd`).
@@ -3302,8 +3302,7 @@
 	-chmod a+rx include
 	if [ -d ../prev-gcc ]; then \
 	  cd ../prev-gcc && \
-	  $(MAKE) real-$(INSTALL_HEADERS_DIR) DESTDIR=`pwd`/../gcc/ \
#`
-	    libsubdir=. ; \
+	  $(MAKE) real-$(INSTALL_HEADERS_DIR) libsubdir=`${PWD_COMMAND}`/../gcc/ ; \
#`
 	else \
 	  (TARGET_MACHINE='$(target)'; srcdir=`cd $(srcdir); ${PWD_COMMAND}`; \
#`
 	    SHELL='$(SHELL)'; MACRO_LIST=`${PWD_COMMAND}`/macro_list ; \
#`
--- old/gcc/tree-if-conv.c
+++ new/gcc/tree-if-conv.c
# Initialize variable declarations that otherwise cause spurious compiler warnings under “warnings are fatal” mode.
@@ -857,7 +857,7 @@
   /* Replace phi nodes with cond. modify expr.  */
   for (i = 1; i < orig_loop_num_nodes; i++)
     {
-      tree phi, cond;
+      tree phi, cond = NULL;   /* aborts the build if it`s uninitialized */
       block_stmt_iterator bsi;
       basic_block true_bb = NULL;
       bb = ifc_bbs[i];
--- old/libcpp/traditional.c
+++ new/libcpp/traditional.c
# Initialize variable declarations that otherwise cause spurious compiler warnings under “warnings are fatal” mode.
@@ -346,7 +346,7 @@
   cpp_context *context;
   const uchar *cur;
   uchar *out;
-  struct fun_macro fmacro;
+  struct fun_macro fmacro = {NULL, NULL, NULL, 0, 0, 0};
   unsigned int c, paren_depth = 0, quote;
   enum ls lex_state = ls_none;
   bool header_ok;
--- old/libgomp/Makefile.in
+++ new/libgomp/Makefile.in
# Include GCC’s `fixinclude`d target‐header directory (which is located relative to a point two to three levels up in the directory
# hierarchy) when compiling; otherwise, `#include-next` can’t find any “next” header during multilib sub-builds.
@@ -263,7 +263,7 @@
 ACLOCAL_AMFLAGS = -I ../config
 SUBDIRS = testsuite
 gcc_version := $(shell cat $(top_srcdir)/../gcc/BASE-VER)
-search_path = $(addprefix $(top_srcdir)/config/, $(config_path)) $(top_srcdir)
+search_path = $(addprefix $(top_srcdir)/config/, $(config_path)) $(top_srcdir) $(MULTISRCTOP)../../gcc/include
 fincludedir = $(libdir)/gcc/$(target_alias)/$(gcc_version)/finclude
 libsubincludedir = $(libdir)/gcc/$(target_alias)/$(gcc_version)/include
 empty = 
--- old/libiberty/Makefile.in
+++ new/libiberty/Makefile.in
# Include GCC’s `fixinclude`d target‐header directory (which is located relative to a point two to three levels up in the directory
# hierarchy) when compiling; otherwise, `#include-next` can’t find any “next” header during multilib sub-builds.
@@ -116,7 +116,7 @@
 
 INCDIR=$(srcdir)/$(MULTISRCTOP)../include
 
-COMPILE.c = $(CC) -c @DEFS@ $(LIBCFLAGS) -I. -I$(INCDIR) $(HDEFINES) @ac_libiberty_warn_cflags@
+COMPILE.c = $(CC) -c @DEFS@ $(LIBCFLAGS) -I. -I$(INCDIR) -I$(MULTISRCTOP)../../gcc/include $(HDEFINES) @ac_libiberty_warn_cflags@
 
 # Just to make sure we don't use a built-in rule with VPATH
 .c.o:
