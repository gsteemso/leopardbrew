class Gpgme < Formula
  desc 'Library access to GnuPG'
  homepage 'https://www.gnupg.org/software/gpgme/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2'
  sha256 '9499e8b1f33cccb6815527a1bc16049d35a6198a6c5fae0185f2bd561bce5224'

  depends_on "gnupg"
  depends_on "libgpg-error"
  depends_on "libassuan"
  depends_on "pth"

  conflicts_with "argp-standalone",
                 :because => "gpgme picks it up during compile & fails to build"

  fails_with :llvm do
    build 2334
  end

  def install
    # Check these inreplaces with each release.
    # At some point GnuPG will pull the trigger on moving to GPG2 by default.
    inreplace "src/gpgme-config.in", "@GPG@", "#{Formula["gnupg"].opt_prefix}/bin/gpg"
    inreplace "src/gpgme-config.in", "@GPGSM@", "#{Formula["gnupg"].opt_prefix}/bin/gpgsm"

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-static"
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    assert_equal "#{Formula["gnupg"].opt_prefix}/bin/gpg", shell_output("#{bin}/gpgme-config --get-gpg").strip
  end
end
