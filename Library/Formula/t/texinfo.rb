class Texinfo < Formula
  desc "Official documentation format of the GNU project"
  homepage "https://www.gnu.org/software/texinfo/"
  url "http://ftpmirror.gnu.org/texinfo/texinfo-7.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/texinfo/texinfo-7.1.tar.xz"
  sha256 'deeec9f19f159e046fdf8ad22231981806dac332cc372f1c763504ad82b30953'

  # while this software is provided by the OS, no known uses are harmed by having a newer version.

  depends_on "perl"

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--disable-install-warnings",
                          "--prefix=#{prefix}"
    system "make", "install"
    doc.install Dir["doc/refcard/txirefcard*"]
  end

  test do
    (testpath/"test.texinfo").write <<-EOS.undent
      @ifnottex
      @node Top
      @top Hello World!
      @end ifnottex
      @bye
    EOS
    system "#{bin}/makeinfo", "test.texinfo"
    assert_match /Hello World!/, File.read("test.info")
  end
end
