class NotBrewedBash < Requirement
  fatal true

  def initialize(sysbash, linked_sysbash)
    @stock = sysbash
    @correct = linked_sysbash
    super()
  end

  satisfy do
    (not @stock.symlink?) or (@correct.exists? and @stock.readlink == @correct.basename)
  end

  def message; <<-_.undent
    You can’t (re)install Bash while using it!  You need to run the `to-stock-bash`
    command before proceeding.
    _
  end
end

class Bash < Formula
  desc "Bourne-Again SHell, a UNIX command interpreter"
  homepage "https://www.gnu.org/software/bash/"
  url "http://ftpmirror.gnu.org/bash/bash-5.2.21.tar.gz"
  mirror "https://mirrors.ocf.berkeley.edu/gnu/bash/bash-5.2.21.tar.gz"
  mirror "https://mirrors.kernel.org/gnu/bash/bash-5.2.21.tar.gz"
  sha256 "c8e31bdc59b69aaffc5b36509905ba3e5cbb12747091d27b4b977f078560d5b8"
  revision 1

  head "http://git.savannah.gnu.org/r/bash.git"

  STANDARD_BASH = (MacOS.version < :leopard ? '2.05' : '3.2')
  SYSTEM_BASH = Pathname.new '/bin/bash'
  MOVED_BASH = Pathname.new "/bin/bash-#{STANDARD_BASH}"
  TO = HOMEBREW_PREFIX/'bin/to-brewed-bash'
  FRO = HOMEBREW_PREFIX/'bin/to-stock-bash'

  depends_on NotBrewedBash.new(SYSTEM_BASH, MOVED_BASH)
  depends_on "readline"

  patch :DATA

  def install
    # When built with SSH_SOURCE_BASHRC, bash will source ~/.bashrc when
    # it's started non-interactively from sshd.  This allows the user to set
    # environment variables prior to running the command (e.g. PATH).  The
    # /bin/bash that ships with Mac OS X defines this, and without it, some
    # things (e.g. git+ssh) will break if the user sets their default shell to
    # Homebrew's bash instead of /bin/bash.
    ENV.append_to_cflags "-DSSH_SOURCE_BASHRC"

    system "./configure", "--prefix=#{prefix}", "--with-installed-readline=#{Formula['readline'].opt_prefix}"
    system "make", "install"

    TO.binwrite switch_to
    FRO.binwrite switch_from
    chmod 0755, [TO, FRO]
  end # install

  def insinuate; system('sudo', TO) if TO.exists?; end

  def uninsinuate; system('sudo', MOVED_BASH, FRO) if FRO.exists?; end

  def caveats; <<-EOS.undent
      To use this build of bash as your login shell, you must add it to /etc/shells.

      Some older software may rely on behaviour that has changed since your system’s
      Bash was current.  To minimize breakage, source `#{HOMEBREW_PREFIX}/etc/bash_compat`
      from your .bashrc.  It sets a Bash system variable for compatibility mode.
    EOS
  end # caveats

  test do
    assert_equal "hello", shell_output("#{bin}/bash -c \"echo hello\"").strip
  end

  def switch_to; <<-_.undent
    #!/bin/bash
    #### This switches the active Bash from the stock version to the brewed version. ####
    #### For use with Leopardbrew on Mac OS 10.4 onwards (untested on earlier OSes). ####

    Links=([0]='/bin/bash' \
           [1]='/bin/sh' \
           [2]='/usr/bin/bashbug' \
           [3]='/usr/share/info/bash' \
           [4]='/usr/share/man/man1/bash' \
           [5]='/usr/share/man/man1/bashbug' \
           [6]='/usr/share/man/man1/sh')
    Brew_Paths=([0]='/bin/bash' \
                [1]='/bin/bash' \
                [2]='/bin/bashbug' \
                [3]='/share/info/bash' \
                [4]='/share/man/man1/bash' \
                [5]='/share/man/man1/bashbug' \
                [6]='/share/man/man1/bash')
    Extensions=([3]='.info' [4]='.1' [5]='.1' [6]='.1') ; Link_Local=([6]='yes')
    Pfx="$(brew --prefix)" ; V_Ext="-${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]%[a-z]*}"
    for i in "${!Links[@]}" ; do
      Link="${Links[$i]}${Extensions[$i]}" ; gzLink="${Link}.gz"
      if [ -e "$gzLink" ] ; then if [ -L "$gzlink" ] ; then sudo rm "$gzlink"
                                 else sudo gunzip "$gzLink" ; fi ; fi
      if [ -e "$Link" -a ! -L "$Link" ] ; then sudo mv "$Link" "${Links[$i]}${V_Ext}${Extensions[$i]}" ; fi
      if [ "${Link_Local[$i]}" != 'yes' ] ; then sudo ln -fs "${Pfx}${Brew_Paths[$i]}${Extensions[$i]}" "$Link"
      else sudo ln -fs "${Brew_Paths[$i]##*/}${Extensions[$i]}" "$Link" ; fi
    done

    Compatibility_Name='bash_compat'
    if [ "${BASH_VERSINFO[0]}" -lt '3' ] ||
       [ ! "${BASH_VERSINFO[0]}" != '3' -a "$((${BASH_VERSINFO[1]%[a-z]}))" -lt '1' ]
    then Compatibility_Version='3.1'
    else Compatibility_Version="${BASH_VERSINFO[0]}.$((${BASH_VERSINFO[1]%[a-z]}))"
    fi
    Compatibility_File="BASH_COMPAT='${Compatibility_Version}'"
    sudo echo "$Compatibility_File" >| "/tmp/${Compatibility_Name}"
    sudo mv "/tmp/${Compatibility_Name}" "${Pfx}/etc/${Compatibility_Name}"
    echo 'Future invocations of Bash will use the brewed version.'
    _
  end # switch_to

  def switch_from; <<-_.undent
    #!/bin/bash
    #### This switches the active Bash from the brewed version back to the stock version. ####
    #### For use with Leopardbrew on Mac OS 10.4 and later (is untested on earlier OSes). ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    V_Ext=(/bin/bash-*) ; V_Ext="${V_Ext[0]#/bin/bash}"
    if [ ! "$V_Ext" != "" ] ; then echo 'Your stock Bash is missing!' && exit 1 ; fi

    Links=([0]='/bin/bash' \
           [1]='/bin/sh' \
           [2]='/usr/bin/bashbug' \
           [3]='/usr/share/info/bash.info' \
           [4]='/usr/share/man/man1/bash.1' \
           [5]='/usr/share/man/man1/bashbug.1' \
           [6]='/usr/share/man/man1/sh.1')
    Targets=([0]="bash${V_Ext}" \
             [1]="sh${V_Ext}" \
             [2]="bashbug${V_Ext}" \
             [3]="bash${V_Ext}.info" \
             [4]="bash${V_Ext}.1" \
             [5]="bashbug${V_Ext}.1" \
             [6]='bash.1')
    for i in "${!Links[@]}" ; do sudo ln -fs "${Targets[$i]}" "${Links[$i]}" ; done

    Disembrew_Files=($(brew --prefix){/bin/to-*-bash,/etc/bash_compat})
    if [ ! -e "$(brew --cellar)/bash" ] ; then
      for File in "${Disembrew_Files[@]}" ; do sudo rm -f "$File" ; done
    fi
    echo 'Future invocations of Bash will use your system’s stock version.'
    _
  end # switch_from
end # Bash

__END__
--- old/examples/loadables/getconf.c	2024-06-27 21:42:56.000000000 -0700
+++ new/examples/loadables/getconf.c	2024-06-27 21:42:34.000000000 -0700
@@ -271,7 +271,9 @@
 #endif
     { "_NPROCESSORS_CONF", _SC_NPROCESSORS_CONF, SYSCONF },
     { "_NPROCESSORS_ONLN", _SC_NPROCESSORS_ONLN, SYSCONF },
+#ifdef _SC_PHYS_PAGES
     { "_PHYS_PAGES", _SC_PHYS_PAGES, SYSCONF },
+#endif
 #ifdef _SC_ARG_MAX
     { "_POSIX_ARG_MAX", _SC_ARG_MAX, SYSCONF },
 #else
