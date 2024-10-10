class Libassuan < Formula
  desc 'Assuan IPC Library'
  homepage 'https://www.gnupg.org/software/libassuan/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.1.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.1.tar.bz2'
  sha256 'c8f0f42e6103dea4b1a6a483cb556654e97302c7465308f58363778f95f194b1'

  depends_on 'libgpg-error'

  option :universal

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-static'
    system 'make', 'install'
  end

  # The former test method relied on a program that is no longer built.
end
