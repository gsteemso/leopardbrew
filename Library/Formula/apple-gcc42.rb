class AppleGcc42 < Formula
  desc 'the last Apple version of the GNU Compiler Collection for OS X'
  homepage 'http://https://opensource.apple.com/releases/'
  url 'https://github.com/apple-oss-distributions/gcc/archive/refs/tags/gcc-5666.3.tar.gz'
  version '4.2.1-5666.3'
  sha256 '2e9889ce0136f5a33298cf7cce5247d31a5fb1856e6f301423bde4a81a5e7ea6'

  depends_on 'gmp'
  depends_on 'mpfr'

  keg_only :provided_by_osx if MacOS.version > :tiger and MacOS.version < :lion

  @switch_to <<-End_of_To
#!/bin/bash
shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

Man1_Pfx=/usr/share/man/man1/
Opt_Pfx="$(brew --prefix)/opt/apple-gcc42/"

Short_Names=(c++ cpp g++ gcc gcov)
Targets=(${Opt_Pfx}{bin,share/man/man1}/{i686,powerpc}-apple-darwin*-{cpp,g{++,cc}}-4.2.1{,.1})
Dir_Targets=(${Opt_Pfx}lib{,exec}/gcc/{i686,powerpc}-apple-darwin*/4.2.1)

for Name in "${Short_Names[@]}" ; do
  # these were always symlinks; no need to rename anything
  sudo ln -fs "${Opt_Pfx}bin/${Name}-4.2" "/usr/bin/$Name"

  V_Nm="${Name}-4.2.1"  # the .1 is not part of the version, it is the man section
  Link="${Man1_Pfx}${Name}.1"
  # sanity check
  if [ -L "$Link" -a $(readlink -n "$Link") != "$V_Nm" ] ; then sudo ln -fs "$V_Nm" "$Link" ; fi
  # actual work
  Link="${Man1_Pfx}${V_Nm}"
  if [ -f "$Link" -a ! -L "$Link" ] ; then sudo mv "$Link" "${Link%.1}.5577.1" ; fi
  sudo ln -fs "${Opt_Pfx}${Link#/usr/}" "$Link"
done

for Target in "${Targets[@]}" ; do
  Link="/usr/${Target#${Opt_Pfx}}"
  Tail="${Link##*2.1}" ; Nose="${Link%${Tail}}"
  if [ -f "$Link" -a ! -L "$Link" ] ; then sudo mv "$Link" "${Nose}.5577${Tail}" ; fi
  sudo ln -fs "$Target" "$Link"
done

for Target in "${Dir_Targets[@]}" ; do
  Link="/usr/${Target#${Opt_Pfx}}"
  if [ -L "$Link" ] ; then sudo rm -f "$Link"
  elif [ -d "$Link" ] ; then sudo mv "$Link" "${Link}.5577"
  fi
  sudo ln -fs "$Target" "$Link"
done
End_of_To

  @switch_from <<-End_of_From
#!/bin/bash
shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

Short_Names=(c++ cpp g++ gcc gcov)
Long_Targets=(/usr/{bin,share/man/man1}/{i686,powerpc}-apple-darwin*-g{++,cc}-4.2.1.5577{,.1})
Delete_Links=(/usr/{bin,share/man/man1}/{i686,powerpc}-apple-darwin*-cpp-4.2.1{,.1})
Dir_Links=(/usr/lib{,exec}/gcc/{i686,powerpc}-apple-darwin*/4.2.1)
Disembrew_Script=/usr/local/bin/to-brewed-gcc42

Bin_Pfx=/usr/bin/
Man1_Pfx=/usr/share/man/man1/

for Name in "${Short_Names[@]}" ; do
  Link="${Bin_Pfx}$Name"
  if [ -L "$Link" -o ! -e "$Link" ] ; then sudo ln -fs "${Name}-4.2" "$Link" ; fi

  V_Nm="${Name}-4.2.1"  # the .1 is not part of the version, it is the man section
  Link="${Man1_Pfx}${Name}.1"
  # sanity check
  if [ -L "$Link" ] && [ "$(readlink -n "$Link")" != "$V_Nm" ] ; then sudo ln -fs "$V_Nm" "$Link" ; fi
  # actual work
  Link="${Man1_Pfx}$V_Nm"
  if [ -L "$Link" -o ! -e "$Link" ] ; then sudo ln -fs "${V_Nm%.1}.5577.1" "$Link" ; fi
done

for Target in "${Long_Targets[@]}" ; do
  Tail="${Target##*5577}" ; Nose="${Target%${Tail}}" ; Link="${Nose%.5577}${Tail}"
  if [ -L "$Link" -o ! -e "$Link" ] ; then sudo ln -fs "$Target" "$Link" ; fi
done

for Link in "${Delete_Links[@]}" ; do if [ -L "$Link" ] ; then sudo rm -f "$Link" ; fi ; done

for Link in "${Dir_Links[@]}" ; do
  if [ -L "$Link" ] ; then sudo rm -f "$Link" ; fi
  # these have to remain separate or else the symlink gets put inside the symlinked directory!
  if [ ! -e "$Link" ] ; then sudo ln -fs "${Link##*/}.5577" "$Link" ; fi
done

if [ ! -e /Users/Shared/Brewery/Cellar/apple-gcc42 ] ; then rm -f "$Disembrew_Script" ; fi
End_of_From

  def install
    args = [
      'RC_OS=macos',
      'RC_ARCHS=ppc i386',
      'TARGETS=ppc i386',
      "SRCROOT=#{buildpath}",
      "OBJROOT=#{buildpath}/build/obj",
      "DSTROOT=#{buildpath}/build/dst",
      "SYMROOT=#{buildpath}/build/sym"
    ]
    mkdir_p ['build/obj', 'build/dst', 'build/sym']
    system 'gnumake', 'install', *args
    doc.install *Dir['build/dst/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.DeveloperTools.docset/Contents/Resources/Documents/documentation/DeveloperTools/gcc-4.2.1/*']
    bin.install *Dir['build/dst/usr/bin/*']
    if MacOS.version > :tiger and MacOS.version < :lion
      (bin/'to-brewed-gcc42').binwrite @switch_to
      (bin/'to-stock-gcc42').binwrite @switch_from
    end
    include.install 'build/dst/usr/include/gcc' if MacOS.version < :leopard
    lib.install 'build/dst/usr/lib/gcc'
    if MacOS.version > :tiger
      # delete broken symlinks
      rm lib/'gcc/i686-apple-darwin9/4.2.1/include/ppc_intrinsics.h'
      rm lib/'gcc/i686-apple-darwin9/4.2.1/include/stdint.h'
      rm lib/'gcc/powerpc-apple-darwin9/4.2.1/include/ppc_intrinsics.h'
      rm lib/'gcc/powerpc-apple-darwin9/4.2.1/include/stdint.h'
    end
    libexec.install 'build/dst/usr/libexec/gcc'
    # delete broken symlinks
    rm libexec/'libexec/gcc/i686-apple-darwin9/4.2.1/as'
    rm libexec/'libexec/gcc/i686-apple-darwin9/4.2.1/ld'
    rm libexec/'libexec/gcc/powerpc-apple-darwin9/4.2.1/as'
    rm libexec/'libexec/gcc/powerpc-apple-darwin9/4.2.1/ld'
    man.install 'build/dst/usr/share/man/man1'
  end

  def post_install
    system bin/'to-brewed-gcc42'
  end if MacOS.version > :tiger and MacOS.version < :lion

  def uninstall
    system bin/'to-stock-gcc42'
    # This command deletes `to-brewed-gcc42` if the `apple-gcc42` rack is gone.  Note that it
    # doesn’t touch `to-stock-gcc42`, just in case.
  rescue
    onoe <<-_.undent
      Something went wrong when un‐symlinking the brewed GCC from your system.  Your
      stock GCC may have become unreachable without using the “-4.2.1.5577” suffixes.
      To repair it manually, you will have to use the “find” command to search for
      broken symlinks under the /usr heirarchy.  The only way to automate that is to
      write a small shell command to your hard drive and then use that shell command
      as a parameter to the `find` command’s `-exec` primary.
    _
  end if MacOS.version > :tiger and MacOS.version < :lion

  def caveats
    <<-EOS.undent
      This formula brews compilers built from Apple’s GCC sources, build 5666.3 (the
      last available from Apple’s open‐source distributions).  All compilers have a
      “-4.2” suffix.
    EOS
    <<-_.undent if MacOS.version > :tiger and MacOS.version < :lion

      Because Apple shipped an older build of this compiler (build 5577) with your OS,
      using the exact same name, two extra commands have been installed:
        to-brewed-gcc42
        to-stock-gcc42
      These respectively activate and deactivate a complex arrangement of symlinks
      that completely substitute the brewed version of GCC 4.2 for the stock version.
      When the brewed version is active, the stock versions of all commands remain
      available as “[program name]-[version number].5577”, as do their manpages etc.

      The switchover commands are used automatically when the formula is installed or
      uninstalled; you should never need to worry about them.  CAUTION:  If the
      software is removed without using the `brew` command, none of the symlinks will
      point to anything any more, making your compiler unuseable!  If this occurs,
      you must run the `to-stock-gcc42` command to put your system back in order.
    _
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
    system bin/'gcc-4.2', '-o', 'hello-c', 'hello-c.c'
    assert_equal "Hello, world!\n", `./hello-c`
  end
end
