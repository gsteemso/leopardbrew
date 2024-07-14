class Bash < Formula
  desc "Bourne-Again SHell, a UNIX command interpreter"
  homepage "https://www.gnu.org/software/bash/"
  url "http://ftpmirror.gnu.org/bash/bash-5.2.21.tar.gz"
  mirror "https://mirrors.ocf.berkeley.edu/gnu/bash/bash-5.2.21.tar.gz"
  mirror "https://mirrors.kernel.org/gnu/bash/bash-5.2.21.tar.gz"
  sha256 "c8e31bdc59b69aaffc5b36509905ba3e5cbb12747091d27b4b977f078560d5b8"

  head "http://git.savannah.gnu.org/r/bash.git"

  bottle do
    sha256 "7864d94ed3a5513db0b84452cc9f3c7cacb5c35ed597502a93d2fb844a8cf1c7" => :tiger_altivec
  end

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
  end

  def caveats; <<-EOS.undent
    In order to use this build of bash as your login shell,
    it must be added to /etc/shells.
    EOS
  end

  test do
    assert_equal "hello", shell_output("#{bin}/bash -c \"echo hello\"").strip
  end
end

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
