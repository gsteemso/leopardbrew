# Stable release 2025-12-10; checked 2026-03-16.
class Bash < Formula
  desc 'Bourne-Again SHell, a UNIX command interpreter'
  homepage 'https://www.gnu.org/software/bash/'
  url 'http://ftpmirror.gnu.org/bash/bash-5.3.tar.gz'
  mirror 'https://mirrors.ocf.berkeley.edu/gnu/bash/bash-5.3.tar.gz'
  mirror 'https://mirrors.kernel.org/gnu/bash/bash-5.3.tar.gz'
  version '5.3.9'
  sha256 '0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba'

  head 'http://git.savannah.gnu.org/r/bash.git'

  stable do
    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-001'
      sha256 '1f608434364af86b9b45c8b0ea3fb3b165fb830d27697e6cdfc7ac17dee3287f'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-002'
      sha256 'e385548a00130765ec7938a56fbdca52447ab41fabc95a25f19ade527e282001'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-003'
      sha256 'f245d9c7dc3f5a20d84b53d249334747940936f09dc97e1dcb89fc3ab37d60ed'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-004'
      sha256 '9591d245045529f32f0812f94180b9d9ce9023f5a765c039b852e5dfc99747d0'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-005'
      sha256 'cca1ef52dbbf433bc98e33269b64b2c814028efe2538be1e2c9a377da90bc99d'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-006'
      sha256 '29119addefed8eff91ae37fd51822c31780ee30d4a28376e96002706c995ff10'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-007'
      sha256 'c0976bbfffa1453c7cfdd62058f206a318568ff2d690f5d4fa048793fa3eb299'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-008'
      sha256 '097cd723cbfb8907674ac32214063a3fd85282657ec5b4e544d2c0f719653fb4'
    end

    patch :p0 do
      url 'http://ftpmirror.gnu.org/bash/bash-5.3-patches/bash53-009'
      sha256 'eee30fe78a4b0cb2fe20e010e00308899cfc613e0774ebb3c8557a1552f24f8c'
    end
  end # stable

  STANDARD_BASH = (MacOS.version < :leopard ? '2.05b' : '3.2')  # true even on Mac OS 10.3 and Mac OS 15
  SYSTEM_BASH = Pathname.new '/bin/bash'
  MOVED_BASH = Pathname.new "/bin/bash-#{STANDARD_BASH}"
  TO = HOMEBREW_PREFIX/'bin/to-brewed-bash'
  FRO = HOMEBREW_PREFIX/'bin/to-stock-bash'

  option :universal

  depends_on SelfUnbrewedRequirement.new(SYSTEM_BASH, MOVED_BASH, 'to-stock-bash')
  depends_on 'bison' => :build
  depends_on 'readline'
  depends_on :nls => :recommended

  def ensure_to_fro
    TO.binwrite switch_to unless TO.exists?
    FRO.binwrite switch_from unless FRO.exists?
    chmod 0755, [TO, FRO]
  end

  def install
    ENV.universal_binary if build.universal?

    # When built with SSH_SOURCE_BASHRC, bash will source ~/.bashrc when it’s started non-interactively from sshd.  This allows the
    # user to set environment variables prior to running the command (e.g. $PATH).  The /bin/bash that ships with Mac OS defines it,
    # and without it, some things (e.g. git+ssh) will break if the user sets their default shell to Homebrew's bash rather than the
    # system’s stock version.
    ENV.append_to_cflags '-DSSH_SOURCE_BASHRC'

    args = %W[
      --prefix=#{prefix}
      --with-installed-readline=#{Formula['readline'].opt_prefix}
    ]
    args << '--disable-nls' if build.without? 'nls'

    system './configure', *args
    system 'make'
    # no `make tests`; it outputs blather that only means much if you pore over the test scripts.
    system 'make', 'install'
  end # install

  insinuate { ensure_to_fro; system 'sudo', TO.to_s }

  # This command also deletes `to-*-bash` if our rack is gone.
  uninsinuate do |silent|
    ensure_to_fro
    do_system((silent ? [:silent] : []), 'sudo', MOVED_BASH.to_s, FRO.to_s)
  end

  def caveats; <<-EOS.undent
      Some older software may rely on behaviour that has changed since your system’s
      Bash was current.  To minimize breakage, source
          #{HOMEBREW_PREFIX}/etc/bash_compat
      from your .bash_profile.  It sets a Bash system variable for compatibility mode.

      To minimize trouble caused by software that insists on using a specific version
      of Bash, two extra commands have been installed:
          to-brewed-bash
          to-stock-bash
      These respectively activate and deactivate a complex arrangement of symlinks
      that completely substitute the brewed version of Bash (including its alternate
      names and accompanying programs, and all relevant manual pages) for the stock
      versions.  When the brewed versions are active, the stock versions of all
      commands and manpages remain available with the suffix “-#{STANDARD_BASH}” (for
      example, the stock version of Bash remains available as “bash-#{STANDARD_BASH}”).

      The switchover commands are used automatically when the formula is installed or
      uninstalled; you should never need to worry about them yourself.  CAUTION:  If
      the new Bash is removed other than by the `brew` command, none of the symlinks
      will point to anything any more, crippling your system!  If this occurs, you
      must manually run
          /bin/bash-#{STANDARD_BASH} #{FRO}
      to put your system back in order.  IF YOUR TERMINAL PROGRAM EXPECTS TO START UP
      WITH BASH BUT NO ACTIVE TERMINAL WINDOWS FROM BEFORE THE DISASTER ARE STILL
      RUNNING, THIS REQUIRES SETTING THE TERMINAL PROGRAM TO USE A DIFFERENT SHELL –
      IN EXTREME CASES, EDITING /etc/shells FIRST.
    EOS
  end # caveats

  test do
    for_archs(bin/'bash') do |_, cmd_array| assert_equal 'hello', shell_output("#{cmd_array * ' '} -c 'echo hello'").strip; end
  end

  def switch_to; <<-_.undent
    #!/bin/sh
    #### This switches the active Bash from the stock version to the brewed version. ####
    #### For use with Leopardbrew on Mac OS 10.4 onwards (untested on earlier OSes). ####

    Links=([0]='/bin/bash' \\
           [1]='/bin/sh' \\
           [2]='/usr/bin/bashbug' \\
           [3]='/usr/share/info/bash' \\
           [4]='/usr/share/man/man1/bash' \\
           [5]='/usr/share/man/man1/bashbug' \\
           [6]='/usr/share/man/man1/sh')
    Brew_Paths=([0]='/bin/bash' \\
                [1]='/bin/bash' \\
                [2]='/bin/bashbug' \\
                [3]='/share/info/bash' \\
                [4]='/share/man/man1/bash' \\
                [5]='/share/man/man1/bashbug' \\
                [6]='/share/man/man1/bash')
    Extensions=([3]='.info' [4]='.1' [5]='.1' [6]='.1'); Link_Local=([6]='yes')
    Pfx="$(brew --prefix)"; V_Ext="-${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]%[a-z]*}"
    for i in 0 1 2 3 4 5 6; do
      Link="${Links[$i]}${Extensions[$i]}"; gzLink="${Link}.gz"
      if [ -e "$gzLink" ]; then if [ -L "$gzLink" ]; then sudo rm "$gzLink" else sudo gunzip "$gzLink"; fi; fi
      if [ -e "$Link" ] && ! [ -L "$Link" ]; then sudo mv -f "$Link" "${Links[$i]}${V_Ext}${Extensions[$i]}"; fi
      if [ "${Link_Local[$i]}" != 'yes' ]; then sudo ln -fs "${Pfx}/opt/bash${Brew_Paths[$i]}${Extensions[$i]}" "$Link"
      else sudo ln -fs "${Brew_Paths[$i]##*/}${Extensions[$i]}" "$Link"; fi
    done

    Compatibility_Name='bash_compat'
    if [ "${BASH_VERSINFO[0]}" -lt '3' ] ||
       [ "${BASH_VERSINFO[0]}" = '3' ] && [ "$((${BASH_VERSINFO[1]%[a-z]}))" -lt '1' ]
    then Compatibility_Version='3.1'
    else Compatibility_Version="${BASH_VERSINFO[0]}.$((${BASH_VERSINFO[1]%[a-z]}))"
    fi
    Compatibility_File="BASH_COMPAT='${Compatibility_Version}'"
    sudo echo "$Compatibility_File" >| "/tmp/${Compatibility_Name}"
    chmod 0644 "/tmp/${Compatibility_Name}"
    sudo mv -f "/tmp/${Compatibility_Name}" "${Pfx}/etc/${Compatibility_Name}"
    echo 'Future invocations of Bash will use the brewed version.'
    _
  end # switch_to

  def switch_from; <<-_.undent
    #!/bin/sh
    #### This switches the active Bash from the brewed version back to the stock version. ####
    #### For use with Leopardbrew on Mac OS 10.4 and later (is untested on earlier OSes). ####
    shopt -s nullglob  # allows ignoring nonexistent combinations from patterns

    V_Ext=(/bin/bash-*); V_Ext="${V_Ext[0]#/bin/bash}"
    if [ -z "$V_Ext" ]; then echo 'Your stock Bash is missing!' && exit 1; fi

    Links=([0]='/bin/bash' \\
           [1]='/bin/sh' \\
           [2]='/usr/bin/bashbug' \\
           [3]='/usr/share/info/bash.info' \\
           [4]='/usr/share/man/man1/bash.1' \\
           [5]='/usr/share/man/man1/bashbug.1' \\
           [6]='/usr/share/man/man1/sh.1')
    Targets=([0]="bash${V_Ext}" \\
             [1]="sh${V_Ext}" \\
             [2]="bashbug${V_Ext}" \\
             [3]="bash${V_Ext}.info" \\
             [4]="bash${V_Ext}.1" \\
             [5]="bashbug${V_Ext}.1" \\
             [6]='bash.1')
    for i in 0 1 2 3 4 5 6; do sudo ln -fs "${Targets[$i]}" "${Links[$i]}"; done

    Disembrew_Files=($(brew --prefix){/bin/to-*-bash,/etc/bash_compat})
    if ! [ -e "$(brew --cellar)/bash" ]; then
      for File in "${Disembrew_Files[@]}"; do sudo rm -f "$File"; done
    fi
    echo 'Future invocations of Bash will use your system’s stock version.'
    _
  end # switch_from
end # Bash
