# stable release 2023-12-22; checked 2025-08-02
class Autoconf < Formula
  desc "Automatic configure script builder"
  homepage "https://www.gnu.org/software/autoconf"
  url "http://ftpmirror.gnu.org/autoconf/autoconf-2.72.tar.xz"
  mirror "https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz"
  sha256 "ba885c1319578d6c94d46e9b0dceb4014caafe2490e437a0dbca3f270a223f5a"

  keg_only :provided_until_xcode43

  bottle do
    cellar :any_skip_relocation
    sha256 "ef803264de782df052807bc4fdd57454d45fdad5502c029c55e91f34e3756bdc" => :tiger_altivec
  end

  # Stock M4 is too old.  (Also, stock Automake is too old to run the test suite, but {automake} is
  # not possible to depends_on because said dependency would be circular.  TODO:  Revisit this once
  # enhanced_by formulæ can accept :build tags.)
  depends_on "m4"

  def install
    ENV["PERL"] = "/usr/bin/perl"

    # Force autoreconf to look for and use our glibtoolize, if only because Tiger has no libtoolize.
    # (“Our” glibtoolize is rather a shaky concept… {libtool} depends on this formula.  Fortunately,
    # this seems to somehow work anyway.)
    inreplace "bin/autoreconf.in", "libtoolize", "glibtoolize"
    # Also touch the man page so that it isn’t rebuilt.
    inreplace "man/autoreconf.1", "libtoolize", "glibtoolize"

    system "./configure", "--prefix=#{prefix}",
           "--with-lispdir=#{share}/emacs/site-lisp/autoconf"
    system "make", "install"

    rm_f info/"standards.info"
  end

  test do
    cp "#{share}/autoconf/autotest/autotest.m4", "autotest.m4"
    system "#{bin}/autoconf", "autotest.m4"
  end
end
