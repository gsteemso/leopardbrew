class Libksba < Formula
  desc 'X.509 and certificate‐management library'
  homepage 'https://www.gnupg.org/software/libksba/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/libksba/libksba-1.6.7.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/libksba/libksba-1.6.7.tar.bz2'
  sha256 'cf72510b8ebb4eb6693eef765749d83677a03c79291a311040a5bfd79baab763'

  option :universal

  depends_on 'libgpg-error'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-static'
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  # The program formerly used in the test block no longer exists.
end
