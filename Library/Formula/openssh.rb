class Openssh < Formula
  desc 'OpenBSD freely-licensed SSH connectivity tools'
  homepage 'https://www.openssh.com/'
  url 'https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.9p2.tar.gz'
  mirror 'https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.9p2.tar.gz'
  version '9.9p2'
  sha256 '91aadb603e08cc285eddf965e1199d02585fa94d994d6cae5b41e1721e215673'
  license 'SSH-OpenSSH'

  # Please don't resubmit the keychain patch option.  It will never be accepted.
  # https://archive.is/hSB6d#10%25

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'ldns'
  depends_on 'openssl3'
  depends_on 'zlib'

  keg_only :provided_by_osx

  # This patch is applied by Apple.
  # https://github.com/apple-oss-distributions/OpenSSH/blob/main/openssh/sandbox-darwin.c#L66
  patch do
    url 'https://raw.githubusercontent.com/Homebrew/patches/1860b0a745f1fe726900974845d1b0dd3c3398d6/openssh/patch-sandbox-darwin.c-apple-sandbox-named-external.diff'
    sha256 'd886b98f99fd27e3157b02b5b57f3fb49f43fd33806195970d4567f12be66e71'
  end

  # defines.h:
  # - Testing for endian.h is insufficient – the older‐Mac‐OS one defined different macros than the
  #   Linux one does.  Test for one of the affected #define names directly.
  patch :DATA

  resource 'com.openssh.sshd.sb' do
    url 'https://raw.githubusercontent.com/apple-oss-distributions/OpenSSH/OpenSSH-268.100.4/com.openssh.sshd.sb'
    sha256 'a273f86360ea5da3910cfa4c118be931d10904267605cdd4b2055ced3a829774'
  end

  TO = HOMEBREW_PREFIX/'bin/to-brewed-openssh'
  FRO = HOMEBREW_PREFIX/'bin/to-stock-openssh'

  def ensure_to_fro
    TO.binwrite switch_to unless TO.exists?
    FRO.binwrite switch_from unless FRO.exists?
    chmod 0755, [TO, FRO]
  end

  def install
    inreplace 'sftp-server.c', /\bHandle\b/, 'SFTP_Handle'

    ENV.universal_binary if build.universal?

    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
      --with-ldns
      --with-libedit
      --with-kerberos5
      --with-pam
      --with-ssl-dir=#{Formula['openssl3'].opt_prefix}
      --with-zlib=#{Formula['zlib'].opt_prefix}
    ]

    ENV.append 'CPPFLAGS', '-D__APPLE_SANDBOX_NAMED_EXTERNAL__'

    # Ensure sandbox profile prefix is correct.
    # We introduce this issue with patching, it's not an upstream bug.
    inreplace 'sandbox-darwin.c', '@PREFIX@/share/openssh', etc/'ssh'

    system './configure', *args
    system 'make'
    ENV.deparallelize { system 'make', 'install' }

    # This was removed by upstream with very little announcement and has potential to break
    # scripts, so recreate it for now.  Debian have done the same thing.
    bin.install_symlink 'ssh' => 'slogin'
    man1.install_symlink 'ssh.1' => 'slogin.1'

    buildpath.install resource('com.openssh.sshd.sb')
    (etc/'ssh').install 'com.openssh.sshd.sb' => 'org.openssh.sshd.sb'
  end # install

  def insinuate; ensure_to_fro; system 'sudo', TO; end

  # This command also deletes `to-*-openssh` if the `openssh` rack is gone.
  def uninsinuate; ensure_to_fro; system 'sudo', FRO; end

  test do
    require 'socket'
    def free_port
      server = TCPServer.new 0
      _, port, = server.addr
      server.close
      port
    end # free_port

    for_archs(bin/'ssh') do |a|
      arch_cmd = (a.nil? ? '' : "arch -arch #{a.to_s} ")
      assert_match "OpenSSH_#{version}", shell_output("#{arch_cmd}#{bin}/ssh -V 2>&1")
    end

    for_archs(sbin/'sshd') do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      port = free_port
      unless sshd_pid = fork
        exec *(arch_cmd << "#{sbin}/sshd"), '-D', '-p', port.to_s
      else
        sleep 2
        assert_match 'sshd', shell_output("lsof -i :#{port}   # arch #{a}")
        Process.kill 9, sshd_pid
        Process.waitpid sshd_pid
      end
    end
  end # test

  def switch_to; <<-_.undent
    #/bin/sh
    # to-brewed-openssh:  Switches system SSH from stock to brewed OpenSSH.
    # There are two families of files.  Host keys and the like live in /etc/ssh*, while executables and
    # manpages live in /usr/*.  More than the directory trees differ – in newer OpenSSHes, the previous
    # miscellany mixed into /etc is corralled into /etc/ssh/.  Both possibilities must be accommodated.

    brewed_etc_prefix="$(brew --prefix)/etc/"

    brewed_prefix="$(brew --prefix)/opt/openssh/"

    prefix_2=([0]='bin/' \\
              [1]='libexec/' \\
              [2]='sbin/' \\
              [3]='share/man/man1/' \\
              [4]='share/man/man5/' \\
              [5]='share/man/man8/')
    stock_file_infix=([0]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
                      [1]='sftp-server ssh-keysign sshd-keygen-wrapper' \\
                      [2]='sshd' \\
                      [3]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
                      [4]='ssh_config sshd_config' \\
                      [5]='sftp-server ssh-keysign sshd sshd-keygen-wrapper')
    suffix=([3]='.1' \\
            [4]='.5' \\
            [5]='.8')

    # We need to ask SSH its version, but if we already replaced it, we’d get the wrong answer; in that
    # case, look for where we moved it to.  (If multiple, assume the earliest version is stock.)
    if [ -L '/usr/bin/ssh' ]; then   # SOMETHING’s been done, it’s been moved.  Assume we did it, & get
                                     # the earliest version of any present renamed as we rename them.
      stock_version="$(ls /usr/bin/ssh-* | egrep -o '[0-9.]+p[0-9]+' | sed -E -e \
                                                's/^([0-9][.p])/0\\1/g' | sort -u | cut -d$'\\n' -f 1)"
      if [ "x$stock_version" = 'x' ]; then   # We didn’t get any hits.
        echo 'Leopardbrew cannot find your stock OpenSSH, and dares not do any reconfiguration of your'
        echo 'system because doing so will likely break prior reconfiguration by other software.'
        exit 1
      fi
    else   # it’s still in place; assume it’s the stock version.
      stock_version="$(/usr/bin/ssh -V 2>&1 | cut -d, -f1 | cut -c9-)"
    fi

    # Step 1:  Rename a set of stock files to get them out of the way.
    # Step 2:  Symlink the corresponding set of brewed files into its place.

    # Clean out any old symlinks (they are presumably left over from previous switches).
    for stock_file in /etc/ssh*; do if [ -L "$stock_file" ]; then sudo rm -f "$stock_file"; fi; done
    # Move any unmoved files.
    for stock_file in /etc/ssh*; do   # A bunch of loose files, or a directory.
      if [ "${stock_file##*-}" = "$stock_file" ]; then   # Unversioned, so assume it’s not been moved.
        sudo mv -f "$stock_file" "${stock_file}-$stock_version"
      fi
    done
    sudo ln -fs "${brewed_etc_prefix}ssh" '/etc/ssh'   # A directory.

    declare -i i=0
    while [ $i -le $((5)) ]; do
      for infix in ${stock_file_infix[$i]}; do
        stock_file="/usr/${prefix_2[$i]}$infix${suffix[$i]}"
        moved_file="/usr/${prefix_2[$i]}${infix}-$stock_version${suffix[$i]}"
        if [ "x${suffix[$i]}" != 'x' ] && [ -e "${stock_file}.gz" ]; then   # Compressed manpages?
          stock_file="${stock_file}.gz"
          moved_file="${moved_file}.gz"
        fi
        if [ -L "$stock_file" ]; then   # Assume the file was already moved and replaced.
          # If the symlink points to moved stock version, delete it.
          if [ "$(readlink "$stock_file")" = "${moved_file##*/}" ]; then sudo rm -f "$stock_file"; fi
        elif [ -e "$stock_file" ]; then sudo mv -f "$stock_file" "$moved_file"; fi   # Unmoved; do so.
      done
      for brewed_file in $brewed_prefix${prefix_2[$i]}*; do
        link_file="/usr/${prefix_2[$i]}${brewed_file##*/}"
        if [ \\! -L "$brewed_file" ] &&   # The brewed “slogin” is a symlink, and handled later.
           [ \\! -L "$link_file" ] || [ "$(readlink $link_file)" != "$brewed_file" ]; then
          sudo ln -fs "$brewed_file" "$link_file"   # Not yet linked, so do it.
        fi
      done
      let i=$(($i + 1))
    done
    sudo ln -fs "${brewed_prefix}bin/ssh" '/usr/bin/slogin'
    sudo ln -fs "${brewed_prefix}share/man/man1/ssh.1" '/usr/share/man/man1/slogin.1'
    if [ -e '/usr/share/man/man1/ssh.1' ] && [ -L '/usr/share/man/man1/slogin.1.gz' ]; then
      sudo rm -f '/usr/share/man/man1/slogin.1.gz'
    fi

    echo 'Invocations of SSH, and/or its various ancillary tools, shall henceforth use the'
    echo 'brewed versions.'
  _
  end # switch_to

  def switch_from; <<-_.undent
    #/bin/bash
    # to-stock-openssh:  Switches system SSH from brewed to stock OpenSSH.
    set +f   # enable pathname expansion
    shopt -s nullglob   # allow null pattern matches
    shopt -u failglob   # don’t act out if a pattern fails to match

    # We need to ask stock SSH its version, but if we didn’t already replace it, we’ll get ENOENT; in
    # that case, check for the stock configuration and abort.  Otherwise, look for our moved version.
    # (If multiple are present, assume we want the earliest.)
    if [ -L '/usr/bin/ssh' ]; then   # SOMETHING’s been done, it’s been moved.  Assume we did it, & get
                                     # the earliest version of any present renamed as we rename them.
      stock_version="$(ls /usr/bin/ssh-* | egrep -o '[0-9.]+p[0-9]+' | sed -E -e \
                                                's/^([0-9][.p])/0\\1/g' | sort -u | cut -d$'\\n' -f 1)"
      if [ "x$stock_version" = 'x' ]; then   # We didn’t get any hits.
        echo 'Leopardbrew cannot find your stock OpenSSH, and thus cannot restore your system'
        echo 'to a stock configuration.'
        exit 1
      fi
    else   # it’s still in place; assume it’s the stock version.
      echo 'It looks like your configuration is already stock.  Aborting reconfiguration.'
      exit 0
    fi
    # At this point we know the stock version.

	brewed_etc_prefix="$(brew --prefix)/etc/"

	brewed_prefix="$(brew --prefix)/opt/openssh/"

	prefix_2=([0]='bin/' \\
			  [1]='libexec/' \\
			  [2]='sbin/' \\
			  [3]='share/man/man1/' \\
			  [4]='share/man/man5/' \\
			  [5]='share/man/man8/')
	stock_file_infix=([0]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
					  [1]='sftp-server ssh-keysign sshd-keygen-wrapper' \\
					  [2]='sshd' \\
					  [3]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
					  [4]='ssh_config sshd_config' \\
					  [5]='sftp-server ssh-keysign sshd sshd-keygen-wrapper')
	brewed_file_infix=([0]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
					   [1]='sftp-server ssh-keysign ssh-pkcs11-helper ssh-sk-helper sshd-session' \\
					   [2]='sshd' \\
					   [3]='scp sftp ssh ssh-add ssh-agent ssh-keygen ssh-keyscan' \\
					   [4]='moduli ssh_config sshd_config' \\
					   [5]='sftp-server ssh-keysign ssh-pkcs11-helper ssh-sk-helper sshd')
	suffix=([3]='.1' \\
			[4]='.5' \\
			[5]='.8')

    # There are two families of files.  Host keys and the like live in /etc/ssh*, while executables and
    # manpages live in /usr/*.  More than the directory trees differ – in newer OpenSSHes, the previous
    # miscellany mixed into /etc is corralled into /etc/ssh/.  Both possibilities must be accommodated.

	# Step 1:  Delete symlinks to the brewed versions.
	# Step 2:  Make new symlinks to the previously‐renamed stock versions.

	for ssh_file in /etc/ssh*; do if [ -L "$ssh_file" ]; then sudo rm -f "$ssh_file"; fi; done
	for ssh_file in /etc/ssh*; do
	  # The previous step deleted all the symlinks we added when switching to the brewed version.
	  # Now we need to find everything we renamed and symlink it to the original names.
	  deversioned_file="${ssh_file%-${stock_version}}"
	  # If they differ, $ssh_file is something we renamed from $deversioned_file.
	  if [ "$deversioned_file" != "$ssh_file" ]; then
		sudo ln -fs "${ssh_file##*/}" "$deversioned_file"
	  fi
	done

	declare -i i=0
	while [ $i -le $((5)) ]; do
	  for infix in ${brewed_file_infix[$i]}; do
		brewed_file="$brewed_prefix${prefix_2[$i]}$infix${suffix[$i]}"
		link_file="/usr/${prefix_2[$i]}$infix${suffix[$i]}"
		if [ -L "$link_file" ] && [ "$(readlink "$link_file")" = "$brewed_file" ]; then
		  sudo rm -f "$link_file"
		fi
	  done
	  for infix in ${stock_file_infix[$i]}; do
		link_file="/usr/${prefix_2[$i]}$infix${suffix[$i]}"
		moved_file="/usr/${prefix_2[$i]}${infix}-${stock_version}${suffix[$i]}"
		if [ "x${suffix[$i]}" != 'x' ] && [ -e "${moved_file}.gz" ]; then   # Compressed manpages?
		  link_file="${link_file}.gz"
		  moved_file="${moved_file}.gz"
		fi
		if [ -e "$moved_file" ] && ! [ -L "$link_file" ]; then   # Verify not already replaced.
		  sudo ln -fs "${moved_file##*/}" "$link_file"
		fi
	  done
	  let i=$(($i + 1))
	done
	sudo ln -fs "ssh-${stock_version}" '/usr/bin/slogin'
	if [ -e '/usr/share/man/man1/ssh.1.gz' ]; then
	  if [ -L '/usr/share/man/man1/slogin.1' ]; then sudo rm -f '/usr/share/man/man1/slogin.1'; fi
	  sudo ln -fs "ssh-${stock_version}.1.gz" '/usr/share/man/man1/slogin.1.gz'
	else
	  sudo ln -fs "ssh-${stock_version}.1" '/usr/share/man/man1/slogin.1'
	fi

	echo 'Invocations of SSH, and/or its various ancillary tools, shall henceforth use the'
	echo 'stock versions.'

    if ! [ -d "$(brew --cellar)/openssh" ]; then sudo rm -f $(brew --prefix)/bin/to-*-openssh; fi
  _
  end # switch_from
end # Openssh

__END__
--- old/defines.h
+++ new/defines.h
@@ -646,7 +646,7 @@
 # endif /* WORDS_BIGENDIAN */
 #endif /* BYTE_ORDER */
 
-#ifndef HAVE_ENDIAN_H
+#ifndef le32toh
 # define openssh_swap32(v)					\
 	(uint32_t)(((uint32_t)(v) & 0xff) << 24 |		\
 	((uint32_t)(v) & 0xff00) << 8 |				\
