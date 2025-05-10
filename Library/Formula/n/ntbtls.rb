class Ntbtls < Formula
  desc 'ntbTLS – the Not Too Bad TLS‐1.2‐only library'
  homepage 'https://www.gnupg.org/software/ntbtls/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/ntbtls/ntbtls-0.3.2.tar.bz2'
  sha256 'bdfcb99024acec9c6c4b998ad63bb3921df4cfee4a772ad6c0ca324dbbf2b07c'

  option :universal

  depends_on 'libgcrypt'
  depends_on 'libgpg-error'
  depends_on 'libksba'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-static'
    system 'make'
#    system 'make', 'check'  # this doesn’t actually do anything
    system 'make', 'install'
  end
end
