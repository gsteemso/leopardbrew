# stable release 2025-07-15, checked 2025-08-02
class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage 'http://curl.haxx.se/docs/caextract.html'
  url 'https://curl.se/ca/cacert-2025-07-15.pem', :using => :nounzip
  version '2025-07-15'
  sha256 '7430e90ee0cdca2d0f02b1ece46fbf255d5d0408111f009638e3b892d6ca089c'

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => 'ca-bundle.crt'
    vendor_cert_bundle = HOMEBREW_RUBY_LIBRARY/'vendor/portable-curl/current/share/cacert.pem'
    rm_f vendor_cert_bundle if vendor_cert_bundle.exists?
    cp share/'ca-bundle.crt', vendor_cert_bundle, :preserve => true
  end

  test { :does_not_apply }
end
