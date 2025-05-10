class Libmetalink < Formula
  desc 'C library to parse Metalink XML files'
  homepage 'https://launchpad.net/libmetalink/'
  url 'https://launchpad.net/libmetalink/trunk/libmetalink-0.1.3/+download/libmetalink-0.1.3.tar.xz'
  sha256 '86312620c5b64c694b91f9cc355eabbd358fa92195b3e99517504076bf9fe33a'

  option :universal
  option 'with-tests', 'Build and run unit tests during brewing (requires CUNIT)'

  depends_on 'pkg-config' => :build
  depends_on 'cunit' if build.with? 'tests'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end
end
