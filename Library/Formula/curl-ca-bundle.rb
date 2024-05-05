class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage "http://curl.haxx.se/docs/caextract.html"
  url "https://curl.se/ca/cacert-2023-08-22.pem",
    :using => :nounzip
  version "2023-08-22"
  sha256 "23c2469e2a568362a62eecf1b49ed90a15621e6fa30e29947ded3436422de9b9"

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => "ca-bundle.crt"
  end

  test do
    true
  end
end
