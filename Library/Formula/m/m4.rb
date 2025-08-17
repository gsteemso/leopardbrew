# stable release 2025-05-10; checked 2025-08-08
class M4 < Formula
  desc 'Macro processing language'
  homepage 'https://www.gnu.org/software/m4'
  url 'https://ftpmirror.gnu.org/m4/m4-1.4.20.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.xz'
  sha256 'e236ea3a1ccf5f6c270b1c4bb60726f371fa49459a8eaaebc90b216b328daf2b'

  keg_only :provided_by_osx

  enhanced_by :nls

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    # `make check` gets hung up on Gnulib issues
    system 'make', 'install'
  end

  test do
    assert_match 'Homebrew',
      pipe_output("#{bin}/m4", "define(TEST, Homebrew)\nTEST\n")
  end
end
