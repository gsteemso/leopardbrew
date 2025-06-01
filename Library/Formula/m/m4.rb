class M4 < Formula
  desc 'Macro processing language'
  homepage 'https://www.gnu.org/software/m4'
  url 'http://ftpmirror.gnu.org/m4/m4-1.4.19.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz'
  sha256 '63aede5c6d33b6d9b13511cd0be2cac046f2e70fd0a07aa9573a04a82783af96'

  enhanced_by :nls

  keg_only :provided_by_osx

  def install
    system './configure', "--prefix=#{prefix}", '--disable-dependency-tracking'
    system 'make'
    system 'make', 'install'
  end

  test do
    assert_match 'Homebrew',
      pipe_output("#{bin}/m4", "define(TEST, Homebrew)\nTEST\n")
  end
end
