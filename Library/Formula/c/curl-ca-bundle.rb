# stable release 2026-07-16, checked 2026-08-07
class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage 'http://curl.haxx.se/docs/caextract.html'
  url 'https://curl.se/ca/cacert-2026-07-16.pem', :using => :nounzip
  version '2026-07-16'
  sha256 '3ff344e30b9b1ed2971044eabb438a08f2e2245ddb5f8ab1a3ad8b63ab4eaf91'

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => 'ca-bundle.crt'
    vendor_cert_bundle = HOMEBREW_RUBY_LIBRARY/'vendor/portable-curl/current/share/cacert.pem'
    rm_f vendor_cert_bundle if vendor_cert_bundle.exists?
    cp_p share/'ca-bundle.crt', vendor_cert_bundle
  end

  test { :does_not_apply }
end
