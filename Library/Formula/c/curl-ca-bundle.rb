class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage 'http://curl.haxx.se/docs/caextract.html'
  url 'https://curl.se/ca/cacert-2025-02-25.pem', :using => :nounzip
  version '2025-02-25'
  sha256 '50a6277ec69113f00c5fd45f09e8b97a4b3e32daa35d3a95ab30137a55386cef'

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => 'ca-bundle.crt'
  end

  test { :does_not_apply }
end
