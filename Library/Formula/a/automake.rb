# stable release 2025-06-26; checked 2025-08-02
class Automake < Formula
  desc 'Tool for generating GNU Standards-compliant Makefiles'
  homepage 'https://www.gnu.org/software/automake/'
  url 'http://ftpmirror.gnu.org/automake/automake-1.18.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/automake/automake-1.18.tar.xz'
  sha256 '5bdccca96b007a7e344c24204b9b9ac12ecd17f5971931a9063bdee4887f4aaf'

  keg_only :provided_until_xcode43

  depends_on 'autoconf' => [:build, :run]

  def install
    system './configure', "--prefix=#{prefix}", '--disable-silent-rules'
    system 'make'
    system 'make', 'install'

    # Our aclocal must go first.  See:  https://github.com/Homebrew/homebrew/issues/10618
    (share/'aclocal/dirlist').write <<-EOS.undent
        #{HOMEBREW_PREFIX}/share/aclocal
        /usr/share/aclocal
      EOS
  end

  test do
    system "#{bin}/automake", '--version'
  end
end
