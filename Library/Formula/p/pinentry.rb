class Pinentry < Formula
  desc 'Passphrase entry dialog utilizing the Assuan protocol'
  homepage 'https://www.gnupg.org/related_software/pinentry/index.en.html'
  url 'https://www.gnupg.org/ftp/gcrypt/pinentry/pinentry-1.3.1.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/pinentry/pinentry-1.3.1.tar.bz2'
  sha256 'bc72ee27c7239007ab1896c3c2fae53b076e2c9bd2483dc2769a16902bce8c04'

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'libgpg-error'
  depends_on 'libassuan'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-pinentry-curses',
                          '--enable-fallback-curses',
                          '--enable-pinentry-tty',
                          '--disable-pinentry-gnome3',
                          '--disable-pinentry-gtk2',
                          '--disable-pinentry-qt4'
    system 'make'
#    system 'make', 'check'  # This doesn’t actually do anything.
    system 'make', 'install'
  end

  test do
    system bin/'pinentry', '--version'
  end
end
