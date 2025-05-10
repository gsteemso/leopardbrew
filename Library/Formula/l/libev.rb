class Libev < Formula
  desc 'Asynchronous event library'
  homepage 'http://software.schmorp.de/pkg/libev.html'
  url 'http://dist.schmorp.de/libev/Attic/libev-4.33.tar.gz'
  sha256 '507eb7b8d1015fbec5b935f34ebed15bf346bed04a11ab82b8eee848c4205aea'

  def install
    ENV.universal_binary
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make', 'install'

    # Remove compatibility header to prevent conflict with libevent
    (include/'event.h').unlink
  end
end
