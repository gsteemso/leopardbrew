class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage 'http://curl.haxx.se/docs/caextract.html'
  url 'https://curl.se/ca/cacert-2024-12-31.pem',
    :using => :nounzip
  version '2024-12-31'
  sha256 'a3f328c21e39ddd1f2be1cea43ac0dec819eaa20a90425d7da901a11531b3aa5'

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => 'ca-bundle.crt'
  end

  test do
    true
  end
end
