class TclTk < Formula
  desc "Tool Command Language"
  homepage "https://www.tcl.tk/"
  url "https://downloads.sourceforge.net/projects/tcl/files/Tcl/8.6.14/tcl8.6.14-src.tar.gz"
  version "8.6.14"
  sha256 "5880225babf7954c58d4fb0f5cf6279104ce1cd6aa9b71e9a6322540e1c4de66"

  keg_only :provided_by_osx,
    "Tk installs some X11 headers and OS X provides an (older) Tcl/Tk."

  deprecated_option "enable-threads" => "with-threads"

  option :universal
  option "with-threads", "Build with multithreading support"
  option "without-tcllib", "Don't build tcllib (utility modules)"
  option "without-tk", "Don't build the Tk (window toolkit)"

  depends_on :x11 if MacOS.version < :snow_leopard
  depends_on "pkg-config" => :build if build.with? "x11"
  depends_on "sqlite"
  depends_on "zlib"

  resource "tk" do
    url "https://downloads.sourceforge.net/projects/tcl/files/Tcl/8.6.14/tk8.6.14-src.tar.gz"
    version "8.6.14"
    sha256 "8ffdb720f47a6ca6107eac2dd877e30b0ef7fac14f3a84ebbd0b3612cee41a94"
  end

  resource "tcllib" do
    url "https://downloads.sourceforge.net/projects/tcllib/files/tcllib/1.21/tcllib-1.21.tar.xz"
    sha256 "10c7749e30fdd6092251930e8a1aa289b193a3b7f1abf17fee1d4fa89814762f"
  end

  def install
    ENV.universal_binary if build.universal?
    # TCL has restrictions on doing :universal builds under Tiger, but they aren’t a factor
    # because Tigerbrew quietly makes :universal the same as not-:universal under Tiger

    # Build breaks passing -w
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    args = [
      "--prefix=#{prefix}",
      "--mandir=#{man}",
      '--enable-man-symlinks',
      '--enable-man-suffix',
      '--disable-framework',
      '--disable-dtrace',
      '--with-encoding=utf-8'
    ]
    args << "--enable-threads" if build.with? "threads"
    args << "--enable-64bit" if MacOS.prefer_64_bit?

    cd "unix" do
      system "./configure", *args
      system "make"
      system "make", "install"
      system "make", "install-private-headers"
      ln_s bin/"tclsh8.6", bin/"tclsh"
    end

    if build.with? "tk"
      ENV.prepend_path "PATH", bin # so that tk finds our new tclsh

      resource("tk").stage do
        args = ["--prefix=#{prefix}", "--mandir=#{man}", "--with-tcl=#{lib}"]
        args << "--enable-threads" if build.with? "threads"
        args << "--enable-64bit" if MacOS.prefer_64_bit?

        # Aqua support now requires features introduced in Snow Leopard at least
        if MacOS.version < :snow_leopard
          args << "--with-x"
        else
          args << "--enable-aqua=yes"
          args << "--without-x"
        end

        cd "unix" do
          system "./configure", *args
          system "make", "TK_LIBRARY=#{lib}"
          # system "make", "test"  # for maintainers
          system "make", "install"
          system "make", "install-private-headers"
          ln_s bin/"wish8.6", bin/"wish"
        end
      end
    end

    if build.with? "tcllib"
      resource("tcllib").stage do
        system "./configure", "--prefix=#{prefix}",
                              "--mandir=#{man}"
        system "make", "install"
      end
    end
  end

  test do
    assert_equal "honk", pipe_output("#{bin}/tclsh", "puts honk\n").chomp
  end
end
