class AppleGcc42 < Formula
  desc 'the last Apple version of the GNU Compiler Collection for OS X'
  homepage 'http://https://opensource.apple.com/releases/'
  url 'https://github.com/apple-oss-distributions/gcc/archive/refs/tags/gcc-5666.3.tar.gz'
  version '4.2.1-5666.3'
  sha256 '2e9889ce0136f5a33298cf7cce5247d31a5fb1856e6f301423bde4a81a5e7ea6'

  option 'with-arm', 'Build with 32‐bit ARM support for iOS et sim (requires Xcode iPhone SDK; the hacked v2.2.1 was the last to support PowerPC)'

  depends_on 'gmp'
  depends_on 'mpfr'

  enhanced_by ['gettext', 'libiconv']

  keg_only :provided_by_osx if MacOS.version > :tiger and MacOS.version < :lion

  # Fiddle the build script and associated files to allow for more possible
  # system configurations, almost (but not quite) all of it specifically for
  # building arm compilers, and also to greatly simplify installation.
  # build_gcc:
  # - Since we aren’t using the feature that puts two prefixes on everything,
  #   set the “inner” one to the null string.
  # - Don’t look in weird places for the C++ standard library.
  # - Since older xcodebuild does not understand “Path” or “PlatformPath” (and
  #   there is no clue as to what exactly $ARM_SDK ought to hold even if those
  #   would be understood), bypass them via an environment variable.
  # - Use a lipo version that can recognize an ARM slice.
  # - Use the split prefix that we DIDN’T set to the null string.
  # - Put shared libraries in the correct location.
  # - Use versioned libraries.
  # - Build the HTML documentation straight into share/doc.
  # - Don’t symlink to nonexistent files.
  # - Don’t forget to build libgcc_s.1.dylib.
  # - Don’t bother copying libgomp.a, it’s already in place because we didn’t
  #   use the split‐prefix feature.
  # - Remove several instances of doubled directory separators.
  # - Don’t generate extra debugging data.
  # - Don’t chgrp.  It is not useful, and when we are not in the destination
  #   group (“wheel”), it fails messily.
  # gcc/config/arm/lib1funcs.asm:
  # - Fix a critical typo in the armv7 #defines.
  # - Manually assemble two armv6 instructions that the assembler inexplicably
  #   refuses to process.  Since Apple’s as doesn’t know “.4byte”, express them
  #   each as four discrete .bytes in reverse order.
  # gcc/Makefile.in:
  # - Adjust for not using the split‐prefix feature.
  patch :DATA

  if MacOS.version > :tiger and MacOS.version < :lion
   def to; HOMEBREW_PREFIX/'bin/to-brewed-gcc42'; end
   def fro; HOMEBREW_PREFIX/'bin/to-stock-gcc42'; end
  end

  def install
    args = [
      "LOCAL_MAKEFLAGS=#{ENV['MAKEFLAGS']}",
      'RC_OS=macos',
      'RC_ARCHS=ppc i386',
      (build.with?('arm') ? 'TARGETS=ppc i386 arm' : 'TARGETS=ppc i386'),
      "SRCROOT=#{buildpath}",
      "OBJROOT=#{buildpath}/build",
      "SYMROOT=#{buildpath}/build/sym",
      "DSTROOT=#{prefix}"
    ]
    args << "PPC_SYSROOT=#{MacOS.sdk_path}" if MacOS.version < '10.5'
    if build.with? 'arm'
      this_dir = "#{MacOS.active_developer_dir}/Platforms/iPhoneOS.platform"
      if File.directory?(this_dir)
        args << "ARM_PLATFORM=#{this_dir}"
      else
        raise CannotInstallFormulaError.new('Can’t make compilers for ARM; the iPhoneOS SDK was not found.')
      end
      this_dir = "#{this_dir}/Developer/SDKs"
      if File.directory?(this_dir)
        candidate_version = (Dir.glob("#{this_dir}/iPhoneOS*.sdk").map{ |f|
            File.basename(f, '.sdk')[/\d+\.\d+(?:\.\d+)?/].split('.')
          }.each{ |a|
            a[2] ||= nil		# add nil entries to make every array 3 elements long
          }.sort{ |a, b|
               a[0] == b[0] \
            ? (a[1] == b[1] \
              ? a[2].to_i <=> b[2].to_i \
              : a[1].to_i <=> b[1].to_i \
            ) : a[0].to_i <=> b[0].to_i		# nil.to_i produces 0
          }[-1] || []).compact * '.'		# drop the nil entries after sorting
        inreplace 'build_gcc', '@@iPhoneOSSDK@@', "iPhoneOS#{candidate_version}.sdk"
      else
        raise CannotInstallFormulaError.new('Can’t make compilers for ARM; the iPhoneOS SDK was not found.')
      end
    end # build.with? 'arm'
    mkdir 'build'
    system 'gnumake', 'install', *args  # this installs the stuff straight into our prefix for us
    if MacOS.version > :tiger and MacOS.version < :lion
      to.binwrite switch_to
      fro.binwrite switch_from
      chmod 0755, [to, fro]
    end
  end # install

  if MacOS.version > :tiger and MacOS.version < :lion
    # If we put this in #install proper, postprocessing will smurf up the actual files’ permissions.
    def post_install; bin.install_symlink [to, fro]; end

    def insinuate; system to if to.exists?; end

    # This command also deletes `to-*-gcc42` if the `apple-gcc42` rack is gone.
    def uninsinuate; system fro if fro.exists?; end
  end

  def caveats
    caveat_text = <<-EOS.undent
      This formula brews compilers from Apple’s custom GCC 4.2.1 sources, build 5666.3
      (the last available from Apple’s open‐source distributions).  All compilers have
      a “-4.2” suffix.
    EOS
    caveat_text += <<-_.undent if build.with? 'arm'

      Building the ARM compilers on PowerPC is problematic at best.  The only releases
      of the SDK supporting PowerPC Macs were pulled from Apple’s servers years ago, &
      if you can track down a bootleg copy (the latest was v2.2.1, incorporating Xcode
      3.1.2 build 2621a), it needs some tweaks with a text editor to work correctly (a
      few places online detail just what must be edited).  Further,
          /Developer/Platforms/iPhoneOS.platform/Developer/usr/include/stdint.h
      must be symlinked into the latest SDK version present, as Apple forgot it unless
      you are using GCC 4.0 (and we’re not, we’re using the GCC 4.2 we just built).
    _
    caveat_text += <<-_.undent if MacOS.version > :tiger and MacOS.version < :lion

      Apple shipped an older version of this compiler (build 5577) with your OS, using
      the exact same name, so two extra commands are installed:
          to-brewed-gcc42
          to-stock-gcc42
      These respectively activate and deactivate a web of symlinks substituting brewed
      Apple GCC 4.2 for the stock version.  Under brewed GCC, stock commands are still
      available as “<command name>-4.2.1.5577”, as are their manpages and so forth.

      The switchover commands are run automatically when the formula gets installed or
      uninstalled; apart from entering your password at those times so they can `sudo`,
      you should never need to worry about them.

      CAUTION:  Should the software be removed without use of the `brew` command, none
      of the symlinks will point to anything any more, making your compiler unuseable!
      Should that occur, you will need to run the `to-stock-gcc42` command to put your
      system back in order.
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
    system bin/'gcc-4.2', *CPU.runnable_archs.as_arch_flags.split(' '), '-o', 'hello-c', 'hello-c.c'
    for_archs('./hello-c') do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      assert_equal "Hello, world!\n", Utils.popen_read(*(arch_cmd << './hello-c'))
    end

    (testpath/'hello-cc.cc').write <<-EOS.undent
      #include <iostream>
      int main()
      {
        std::cout << "Hello, world!" << std::endl;
        return 0;
      }
    EOS
    system bin/'g++-4.2', *CPU.runnable_archs.as_arch_flags.split(' '), '-o', 'hello-cc', 'hello-cc.cc'
    for_archs('./hello-cc') do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      assert_equal "Hello, world!\n", Utils.popen_read(*(arch_cmd << './hello-cc'))
    end
  end # test

  def switch_to; <<-_.undent
    #!/bin/bash
    #### This switches GCC 4.2.1 from the stock build 5577 to the brewed build 5666.3 ####
    #### For use with Leopardbrew on Mac OS 10.5–6 (no others shipped with GCC 4.2.1) ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    Bin_Pfx=/usr/bin/
    Man1_Pfx=/usr/share/man/man1/
    Opt_Pfx="$(brew --prefix)/opt/apple-gcc42/"

    Short_Names=(c++ cpp g++ gcc gcov)
    Targets=(${Opt_Pfx}{bin,share/man/man1}/{arm,i686,powerpc}-apple-darwin*-{cpp,g{++,cc}}-4.2.1{,.1})
    Dir_Targets=(${Opt_Pfx}{lib{,exec}/gcc/{i686,powerpc}-apple-darwin*/,share/doc/gcc-}4.2.1)

    for Name in "${Short_Names[@]}" ; do
      V_Nm="${Name}-4.2.1.5577"
      Sh_V_Nm="${Name}-4.2"

      Link="${Bin_Pfx}${Name}"  # sanity check – ensures, e.g., that `gcc` doesn’t get you `gcc-4.0`
      if [ -L "$Link" ] && [ $(readlink -n "$Link") != "$Sh_V_Nm" ] ; then sudo ln -fs "$Sh_V_Nm" "$Link" ; fi
      Link="${Bin_Pfx}${Sh_V_Nm}"  # actual work
      if [ -f "$Link" -a \\! -L "$Link" ] ; then sudo mv "$Link" "${Link}.1.5577" ; fi
      sudo ln -fs "${Opt_Pfx}${Link#/usr/}" "$Link"

      Link="${Man1_Pfx}${Name}.1"  # for sanity checks – ensure, e.g., that `man gcc` ↛ `man gcc-4.0`
      if [ -e "${Link}.gz" ] ; then gunzip "${Link}.gz" ; fi  # compressed manpages mess this up
      if [ -L "$Link" ] && [ $(readlink -n "$Link") != "${Sh_V_Nm}.1" ] ; then sudo ln -fs "${Sh_V_Nm}.1" "$Link" ; fi
      Link="${Man1_Pfx}${Sh_V_Nm}.1"  # actual work
      if [ -f "$Link" -a \\! -L "$Link" ] ; then sudo mv "$Link" "${Link}.5577.1" ; fi
      sudo ln -fs "${Opt_Pfx}${Link#/usr/}" "$Link"
    done

    for Target in "${Targets[@]}" ; do
      Link="/usr/${Target#${Opt_Pfx}}"
      Tail="${Link##*2.1}" ; Nose="${Link%${Tail}}"
      if [ -f "$Link" -a \\! -L "$Link" ] ; then sudo mv "$Link" "${Nose}.5577${Tail}" ; fi
      if [ -e "$Target" ]; then sudo ln -fs "$Target" "$Link"; fi
    done

    for Target in "${Dir_Targets[@]}" ; do
      Link="/usr/${Target#${Opt_Pfx}}"
      if [ -L "$Link" ] ; then sudo rm -f "$Link"
      elif [ -d "$Link" ] ; then sudo mv "$Link" "${Link}.5577"
      fi
      if [ -e "$Target" ]; then sudo ln -fs "$Target" "$Link"; fi
    done
    _
  end # switch_to

  def switch_from; <<-_.undent
    #!/bin/bash
    #### This switches GCC 4.2.1 from the brewed build 5666.3 back to the stock build 5577 ####
    #### For use with Leopardbrew on Mac OS 10.5 / 10.6 (no others shipped with GCC 4.2.1) ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    Short_Names=(c++ cpp g++ gcc gcov)
    Long_Targets=(/usr/{bin,share/man/man1}/{i686,powerpc}-apple-darwin*-g{++,cc}-4.2.1.5577{,.1})
    Delete_Links=(/usr/{bin,share/man/man1}/{{i686,powerpc}-apple-darwin*-cpp,arm-*}-4.2.1{,.1} /usr/share/doc/gcc-4.2.1)
    Dir_Links=(/usr/lib{,exec}/gcc/{i686,powerpc}-apple-darwin*/4.2.1)
    Disembrew_Scripts=($(brew --prefix)/bin/to-*-gcc42)

    Bin_Pfx=/usr/bin/
    Man1_Pfx=/usr/share/man/man1/

    for Name in "${Short_Names[@]}" ; do
      V_Nm="${Name}-4.2.1.5577"
      Sh_V_Nm="${Name}-4.2"

      Link="${Bin_Pfx}${Name}"  # sanity check – ensures, e.g., that `gcc` doesn’t get you `gcc-4.0`
      if [ -L "$Link" -a "$(readlink -n "$Link")" != "$Sh_V_Nm" ] || [ \\! -e "$Link" ]
      then sudo ln -fs "$Sh_V_Nm" "$Link" ; fi
      Link="${Bin_Pfx}${Sh_V_Nm}"  # actual work
      if [ -L "$Link" -o \\! -e "$Link" ] ; then sudo ln -fs "$V_Nm" "$Link" ; fi

      Link="${Man1_Pfx}${Name}.1"  # sanity check – ensures, e.g., that `man gcc` ↛ `man gcc-4.0`
      if [ -L "$Link" -a "$(readlink -n "$Link")" != "${Sh_V_Nm}.1" ] || [ \\! -e "$Link" ]
      then sudo ln -fs "${Sh_V_Nm}.1" "$Link" ; fi
      Link="${Man1_Pfx}${Sh_V_Nm}.1"  # actual work
      if [ -L "$Link" -o \\! -e "$Link" ] ; then sudo ln -fs "${V_Nm}.1" "$Link" ; fi
    done

    for Target in "${Long_Targets[@]}" ; do
      Tail="${Target##*5577}" ; Nose="${Target%${Tail}}" ; Link="${Nose%.5577}${Tail}"
      if [ -L "$Link" -o \\! -e "$Link" ] ; then sudo ln -fs "${Target##*/}" "$Link" ; fi
    done

    for Link in "${Delete_Links[@]}" ; do if [ -L "$Link" ] ; then sudo rm -f "$Link" ; fi ; done

    for Link in "${Dir_Links[@]}" ; do
      if [ -L "$Link" ] ; then sudo rm -f "$Link" ; fi
      # these have to remain separate or else the symlink gets put inside the symlinked directory!
      if [ \\! -e "$Link" ] ; then sudo ln -fs "${Link##*/}.5577" "$Link" ; fi
    done

    if [ \\! -e "$(brew --cellar)/apple-gcc42" ] ; then
      for Script in "${Disembrew_Scripts[@]}" ; do rm -f "$Script" ; done
    fi
    _
  end # switch_from
end # AppleGcc42

__END__
--- old/build_gcc
+++ new/build_gcc
@@ -51,7 +51,7 @@
 # The fourth parameter is the location where the compiler will be installed,
 # normally "/usr".  You can move it once it's built, so this mostly controls
 # the layout of $DEST_DIR.
-DEST_ROOT="$4"
+DEST_ROOT=''
 
 # The fifth parameter is the place where the compiler will be copied once
 # it's built.
@@ -81,10 +81,10 @@
 
 # This is the libstdc++ version to use.
 LIBSTDCXX_VERSION=4.2.1
-if [ ! -d "$DEST_ROOT/include/c++/$LIBSTDCXX_VERSION" ]; then
+if [ ! -d "/usr/include/c++/$LIBSTDCXX_VERSION" ]; then
   LIBSTDCXX_VERSION=4.0.0
 fi
-NON_ARM_CONFIGFLAGS="--with-gxx-include-dir=\${prefix}/include/c++/$LIBSTDCXX_VERSION"
+NON_ARM_CONFIGFLAGS="--with-gxx-include-dir=/usr/include/c++/$LIBSTDCXX_VERSION"
 
 # Build against the MacOSX10.5 SDK for PowerPC.
 PPC_SYSROOT=/Developer/SDKs/MacOSX10.5.sdk
@@ -97,7 +97,16 @@
 ARM_LIBSTDCXX_VERSION=4.2.1
 ARM_CONFIGFLAGS="--with-gxx-include-dir=/usr/include/c++/$ARM_LIBSTDCXX_VERSION"
 
-if [ -n "$ARM_SDK" ]; then
+if [ -n "$ARM_PLATFORM" ]; then
+
+  ARM_TOOLROOT="$ARM_PLATFORM/Developer"
+  ARM_SYSROOT="$ARM_TOOLROOT/SDKs/@@iPhoneOSSDK@@"
+  if [ \! -d "$ARM_SYSROOT/usr/include/c++/$ARM_LIBSTDCXX_VERSION" ]; then
+    ARM_LIBSTDCXX_VERSION=4.0.0
+    ARM_CONFIGFLAGS="--with-gxx-include-dir=$ARM_SYSROOT/usr/include/c++/$ARM_LIBSTDCXX_VERSION"
+  fi
+
+elif [ -n "$ARM_SDK" ]; then
 
   ARM_PLATFORM=`xcodebuild -version -sdk $ARM_SDK PlatformPath`
   ARM_SYSROOT=`xcodebuild -version -sdk $ARM_SDK Path`
@@ -142,7 +151,7 @@
     exit 1
   fi
   if [ "x$ARM_MULTILIB_ARCHS" = "x" ] ; then
-    ARM_MULTILIB_ARCHS=`/usr/bin/lipo -info $ARM_SYSROOT/usr/lib/libSystem.dylib | cut -d':' -f 3 | sed -e 's/x86_64//' -e 's/i386//' -e 's/ppc7400//' -e 's/ppc64//' -e 's/^ *//' -e 's/ $//'`
+    ARM_MULTILIB_ARCHS=`$ARM_TOOLROOT/usr/bin/lipo -info $ARM_SYSROOT/usr/lib/libSystem.dylib | cut -d':' -f 3 | sed -e 's/x86_64//' -e 's/i386//' -e 's/ppc7400//' -e 's/ppc64//' -e 's/^ *//' -e 's/ $//'`
   fi;
   if [ "x$ARM_MULTILIB_ARCHS" == "x" ] ; then
     echo "Error: missing ARM slices in $ARM_SYSROOT"
@@ -174,11 +183,13 @@
 
 # These are the configure and build flags that are used.
 CONFIGFLAGS="--disable-checking --enable-werror \
-  --prefix=$DEST_ROOT \
+  --prefix=$DEST_DIR \
   --mandir=\${prefix}/share/man \
   --enable-languages=$LANGUAGES \
   --program-transform-name=/^[cg][^.-]*$/s/$/-$MAJ_VERS/ \
-  --with-slibdir=/usr/lib \
+  --with-slibdir=\${prefix}/lib \
+  --enable-serial-configure \
+  --enable-version-specific-runtime-libs \
   --build=$BUILD-apple-darwin$DARWIN_VERS"
 
 # Figure out how many make processes to run.
@@ -225,14 +236,14 @@
 unset RC_DEBUG_OPTIONS
 make $MAKEFLAGS CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
 make $MAKEFLAGS html CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-make $MAKEFLAGS DESTDIR=$DIR/dst-$BUILD-$BUILD install-gcc install-target \
+make $MAKEFLAGS prefix=$DIR/dst-$BUILD-$BUILD install-gcc install-target \
   CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
 
 # Add the compiler we just built to the path, giving it appropriate names.
-D=$DIR/dst-$BUILD-$BUILD/usr/bin
+D=$DIR/dst-$BUILD-$BUILD$DEST_ROOT/bin
 ln -f $D/gcc-$MAJ_VERS $D/gcc || exit 1
 ln -f $D/gcc $D/$BUILD-apple-darwin$DARWIN_VERS-gcc || exit 1
-PATH=$DIR/dst-$BUILD-$BUILD/usr/bin:$PATH
+PATH=$D:$PATH
 
 # The cross-tools' build process expects to find certain programs
 # under names like 'i386-apple-darwin$DARWIN_VERS-ar'; so make them.
@@ -309,18 +320,18 @@
     # APPLE LOCAL end ARM ARM_CONFIGFLAGS
    fi
    make $MAKEFLAGS all CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-   make $MAKEFLAGS DESTDIR=$DIR/dst-$BUILD-$t install-gcc install-target \
+   make $MAKEFLAGS prefix=$DIR/dst-$BUILD-$t install-gcc install-target \
      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
 
    # Add the compiler we just built to the path.
-   PATH=$DIR/dst-$BUILD-$t/usr/bin:$PATH
+   PATH=$DIR/dst-$BUILD-$t$DEST_ROOT/bin:$PATH
  fi
 done
 
 # Rearrange various libraries, for no really good reason.
 for t in $CROSS_TARGETS ; do
   DT=$DIR/dst-$BUILD-$t
-  D=`echo $DT/usr/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS`
+  D=`echo $DT$DEST_ROOT/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS`
   mv $D/static/libgcc.a $D/libgcc_static.a || exit 1
   mv $D/kext/libgcc.a $D/libcc_kext.a || exit 1
   rm -r $D/static $D/kext || exit 1
@@ -367,13 +378,13 @@
         export COMPILER_PATH=$ARM_TOOLROOT/usr/bin:$COMPILER_PATH
       fi
 
-      if [ $h = $t ] ; then
+      if [ $t != 'arm' ] ; then
 	  make $MAKEFLAGS all CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-	  make $MAKEFLAGS DESTDIR=$DIR/dst-$h-$t install-gcc install-target \
+	  make $MAKEFLAGS prefix=$DIR/dst-$h-$t install-gcc install-target \
 	      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
       else
 	  make $MAKEFLAGS all-gcc CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
-	  make $MAKEFLAGS DESTDIR=$DIR/dst-$h-$t install-gcc \
+	  make $MAKEFLAGS prefix=$DIR/dst-$h-$t install-gcc \
 	      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
       fi
 
@@ -395,7 +406,7 @@
 rm -rf * || exit 1
 
 # HTML documentation
-HTMLDIR="/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.DeveloperTools.docset/Contents/Resources/Documents/documentation/DeveloperTools"
+HTMLDIR="/share/doc"
 mkdir -p ".$HTMLDIR" || exit 1
 cp -Rp $DIR/obj-$BUILD-$BUILD/gcc/HTML/* ".$HTMLDIR/" || exit 1
 
@@ -425,8 +436,6 @@
       cp -p $DIR/dst-$BUILD-$t$DL/$f .$DL/$f || exit 1
     fi
   done
-  ln -s ../../../../bin/as .$DL/as
-  ln -s ../../../../bin/ld .$DL/ld
 done
 
 # bin
@@ -455,11 +464,19 @@
 done
 
 # lib
+if echo $TARGETS | grep arm; then best_lipo=$ARM_TOOLROOT/usr/bin/lipo
+else best_lipo="$(which lipo)"
+fi
 mkdir -p .$DEST_ROOT/lib/gcc || exit 1
 for t in $TARGETS ; do
   cp -Rp $DIR/dst-$BUILD-$t$DEST_ROOT/lib/gcc/$t-apple-darwin$DARWIN_VERS \
     .$DEST_ROOT/lib/gcc || exit 1
 done
+$best_lipo -output .$DEST_ROOT/lib/libgcc_s.1.dylib -create \
+  $DIR/obj-$BUILD-*/gcc/libgcc_s.1.dylib || exit 1
+for link in libgcc_s.1.0.dylib libgcc_s_ppc64.1.dylib libgcc_s_x86_64.1.dylib; do
+  ln -s libgcc_s.1.dylib .$DEST_ROOT/lib/$link
+done
 
 # APPLE LOCAL begin native compiler support
 # libgomp is not built for ARM
@@ -469,7 +486,7 @@
 # And copy libgomp stuff by hand...
 for t in $LIBGOMP_TARGETS ; do
     for h in $LIBGOMP_HOSTS ; do
-	if [ $h = $t ] ; then
+	if [ $h != $h ] ; then
 	    cp -p $DIR/dst-$h-$t$DEST_ROOT/lib/libgomp.a \
 		.$DEST_ROOT/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/ || exit 1
 	    cp -p $DIR/dst-$h-$t$DEST_ROOT/lib/libgomp.spec \
@@ -555,79 +572,69 @@
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
 	    -DPDN="\"-apple-darwin$DARWIN_VERS-g++-$VERS\""                                    \
 	    -DIL="\"$DEST_ROOT/bin/\"" -I  $ORIG_SRC_DIR/include                   \
 	    -I  $ORIG_SRC_DIR/gcc -I  $ORIG_SRC_DIR/gcc/config                     \
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
+lipo -output $DEST_DIR$DEST_ROOT/bin/gcc-$MAJ_VERS -create \
+  $DEST_DIR$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
+rm $DEST_DIR$DEST_ROOT/bin/tmp-*-gcc-$MAJ_VERS || exit 1
+lipo -output $DEST_DIR$DEST_ROOT/bin/cpp-$MAJ_VERS -create \
+  $DEST_DIR$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
+rm $DEST_DIR$DEST_ROOT/bin/tmp-*-cpp-$MAJ_VERS || exit 1
 
 if [ $BUILD_CXX -eq 1 ]; then
-  lipo -output $DEST_DIR/$DEST_ROOT/bin/g++-$MAJ_VERS -create \
-       $DEST_DIR/$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
-  ln -f $DEST_DIR/$DEST_ROOT/bin/g++-$MAJ_VERS $DEST_DIR/$DEST_ROOT/bin/c++-$MAJ_VERS || exit 1
-  rm $DEST_DIR/$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
+  lipo -output $DEST_DIR$DEST_ROOT/bin/g++-$MAJ_VERS -create \
+       $DEST_DIR$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
+  ln -f $DEST_DIR$DEST_ROOT/bin/g++-$MAJ_VERS $DEST_DIR/bin/c++-$MAJ_VERS || exit 1
+  rm $DEST_DIR$DEST_ROOT/bin/tmp-*-g++-$MAJ_VERS || exit 1
 
   # Remove extraneous stuff
-  rm -rf $DEST_DIR/$DEST_ROOT/lib/gcc/*/*/include/c++
+  rm -rf $DEST_DIR$DEST_ROOT/lib/gcc/*/*/include/c++
 fi
 
 
 ########################################
 # Create SYM_DIR with information required for debugging.
 
-cd $SYM_DIR || exit 1
 
 # Clean out SYM_DIR in case -noclean was passed to buildit.
-rm -rf * || exit 1
 
 # Generate .dSYM files
-find $DEST_DIR -perm -0111 \! -name fixinc.sh \
-    \! -name mkheaders -type f -print | xargs -n 1 -P ${SYSCTL} dsymutil
 
 # Save .dSYM files and .a archives
-cd $DEST_DIR || exit 1
-find . \( -path \*.dSYM/\* -or -name \*.a \) -print \
-  | cpio -pdml $SYM_DIR || exit 1
 # Save source files.
-mkdir $SYM_DIR/src || exit 1
 cd $DIR || exit 1
-find obj-* -name \*.\[chy\] -print | cpio -pdml $SYM_DIR/src || exit 1
 
 ########################################
 # Remove debugging information from DEST_DIR.
 
+find $DEST_DIR -name \*.la\* -print | xargs rm -r || exit 1
 find $DEST_DIR -perm -0111 \! -name fixinc.sh \
     \! -name mkheaders \! -name libstdc++.dylib -type f -print \
-  | xargs strip || exit 1
+  | xargs strip -u -x || exit 1
 find $DEST_DIR -name \*.a -print | xargs strip -SX || exit 1
 find $DEST_DIR -name \*.a -print | xargs ranlib || exit 1
 find $DEST_DIR -name \*.dSYM -print | xargs rm -r || exit 1
-chgrp -h -R wheel $DEST_DIR
-chgrp -R wheel $DEST_DIR
 
 # Done!
 exit 0
--- old/gcc/config/arm/lib1funcs.asm
+++ new/gcc/config/arm/lib1funcs.asm
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
--- old/gcc/Makefile.in
+++ new/gcc/Makefile.in
@@ -3302,8 +3302,7 @@
 	-chmod a+rx include
 	if [ -d ../prev-gcc ]; then \
 	  cd ../prev-gcc && \
-	  $(MAKE) real-$(INSTALL_HEADERS_DIR) DESTDIR=`pwd`/../gcc/ \
-	    libsubdir=. ; \
+	  $(MAKE) real-$(INSTALL_HEADERS_DIR) libsubdir=`pwd`/../gcc/ ; \
 	else \
 	  (TARGET_MACHINE='$(target)'; srcdir=`cd $(srcdir); ${PWD_COMMAND}`; \
 	    SHELL='$(SHELL)'; MACRO_LIST=`${PWD_COMMAND}`/macro_list ; \
