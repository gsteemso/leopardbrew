class Expect < Formula
  desc "Program that can automate interactive applications"
  homepage "https://core.tcl-lang.org/expect/index"
  url "https://downloads.sourceforge.net/project/expect/Expect/5.45.4/expect5.45.4.tar.gz"
  sha256 "49a7da83b0bdd9f46d04a04deec19c7767bb9a323e40c4781f89caf760b92c34"
  license :public_domain

  bottle do
    sha256 "57f38ef443814e8bb793a58c351126852a5ddbe2f8ff3d873635c1e8775524c8" => :tiger_altivec
  end

  option :universal

  depends_on "tcl-tk"

  conflicts_with "ircd-hybrid", because: "both install an `mkpasswd` binary"

  # Fix a segfault in exp_getptymaster()
  # Commit taken from Iain Sandoe's branch at https://github.com/iains/darwin-expect
  patch do
    url "https://github.com/iains/darwin-expect/commit/2a98bd855e9bf2732ba6ddbd490b748d5668eeb0.patch?full_index=1"
    sha256 "deb83cfa2475b532c4e63b0d67e640a4deac473300dd986daf650eba63c4b4c0"
  end

  # attempt to fix a bug encountered when blocking input is read
  # see https://debbugs.gnu.org/cgi/bugreport.cgi?bug=49078
  patch :DATA

  def install
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    ENV.universal_binary if build.universal?

    tcltk = Formula["tcl-tk"]
    args = %W[
      --prefix=#{prefix}
      --exec-prefix=#{prefix}
      --mandir=#{man}
      --enable-shared
      --with-tcl=#{tcltk.opt_lib}
    ]

    args << "--enable-64bit" if MacOS.prefer_64_bit?

    system "./configure", *args
    system "make"
    system "make", "install"
    lib.install_symlink Dir[lib/"expect*/libexpect*"]
    bin.env_script_all_files libexec/"bin",
                             PATH:       "#{tcltk.opt_bin}:$PATH",
                             TCLLIBPATH: lib.to_s
    # "expect" is already linked to "tcl-tk", no shim required
    bin.install libexec/"bin/expect"
  end

  test do
    assert_match "works", shell_output("echo works | #{bin}/timed-read 1")
    assert_equal "", shell_output("{ sleep 3; echo fails; } | #{bin}/timed-read 1 2>&1")
    assert_match "Done", pipe_output("#{bin}/expect", "exec true; puts Done")
  end
end

__END__
--- expect5.45.4/exp_main_sub.c	2018-02-04 10:43:58.000000000 +0000
+++ expect5.45.4/exp_main_sub.c	2021-10-23 00:39:09.375404444 +0100
@@ -326,7 +326,9 @@
 
 	if (code != EXP_EOF) {
 	    inChannel = expStdinoutGet()->channel;
-	    code = Tcl_GetsObj(inChannel, commandPtr);
+	    do {
+		code = Tcl_GetsObj(inChannel, commandPtr);
+	    } while (code < 0 && Tcl_InputBlocked(inChannel));
 #ifdef SIMPLE_EVENT
 	    if (code == -1 && errno == EINTR) {
 		if (Tcl_AsyncReady()) {
