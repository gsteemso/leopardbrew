class Libidn < Formula
  desc 'International domain name library'
  homepage 'https://www.gnu.org/software/libidn/'
  url 'http://ftpmirror.gnu.org/libidn/libidn-1.42.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libidn/libidn-1.42.tar.gz'
  sha256 'd6c199dcd806e4fe279360cb4b08349a0d39560ed548ffd1ccadda8cdecb4723'

  option :universal
  option 'without-nls', 'Build without internationalization'

  depends_on 'pkg-config' => :build
  if build.with? 'nls'
    depends_on 'libiconv'
    depends_on 'gettext'
  end

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-csharp
      --with-lispdir=#{share}/emacs/site-lisp/#{name}
    ]
    args << '--disable-nls' if build.without? 'nls'
    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    ENV['CHARSET'] = 'UTF-8'
    arch_system "#{bin}/idn", 'räksmörgås.se', 'blåbærgrød.no'
  end
end
