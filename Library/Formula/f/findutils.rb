class Findutils < Formula
  desc "Collection of GNU find, xargs, and locate"
  homepage "https://www.gnu.org/software/findutils/"
  url "http://ftpmirror.gnu.org/findutils/findutils-4.10.0.tar.xz"
  mirror "https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz"
  sha256 '1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5'

  deprecated_option "default-names" => "with-default-names"

  option "with-default-names", "Do not prepend 'g' to the binary"

  def install
    args = ["--prefix=#{prefix}",
            "--localstatedir=#{var}/locate",
            "--disable-dependency-tracking",
            '--disable-silent-rules']
    args << "--program-prefix=g" if build.without? "default-names"

    system "./configure", *args
    system "make", "install"
  end

  test do
    _find = (build.with?('default-names') ? 'find' : 'gfind')
    system bin/_find, "--version"
  end
end
