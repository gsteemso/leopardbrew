class Gnupg < Formula
  desc 'GNU Privacy Guard:  A free PGP replacement'
  homepage 'https://www.gnupg.org/'
  url 'https://www.gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.5.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.5.tar.bz2'
  sha256 'f68f7d75d06cb1635c336d34d844af97436c3f64ea14bcb7c869782f96f44277'

  # /usr/bin/ld: multiple definitions of symbol _memrchr
  # https://github.com/mistydemeo/tigerbrew/issues/107
  depends_on :ld64
  depends_on "libgpg-error"
  depends_on "libgcrypt"
  depends_on "libksba"
  depends_on "libassuan"
  depends_on "pinentry"
  depends_on "npth"
  depends_on "curl" if MacOS.version <= :mavericks
  depends_on "dirmngr" => :recommended
  depends_on "libusb-compat" => :recommended
  depends_on "readline" => :optional

  def install
    # It is no longer necessary or useful to package GnuPG 1, so GnuPG 2 and gpg-agent no longer
    # need to be separated.
    (var/"run").mkpath

    ENV.append "LDFLAGS", "-lresolv"

    ENV["gl_cv_absolute_stdint_h"] = "#{MacOS.sdk_path}/usr/include/stdint.h"

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --sbindir=#{bin}
      --enable-symcryptrun
    ]

    if build.with? "readline"
      args << "--with-readline=#{Formula["readline"].opt_prefix}"
    end

    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"
  end

  def caveats; <<-EOS.undent
      Remember to add "use-standard-socket" to your ~/.gnupg/gpg-agent.conf
      file.
    EOS
  end

  test do
    system "#{bin}/gpgconf"
  end
end
