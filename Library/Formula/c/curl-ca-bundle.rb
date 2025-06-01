class CurlCaBundle < Formula
  desc 'Modern certificate-authority bundle from the Curl project'
  homepage 'http://curl.haxx.se/docs/caextract.html'
  url 'https://curl.se/ca/cacert-2025-05-20.pem', :using => :nounzip
  version '2025-05-20'
  sha256 'ab3ee3651977a4178a702b0b828a4ee7b2bbb9127235b0ab740e2e15974bf5db'

  bottle do
    cellar :any
  end

  def install
    share.install "cacert-#{version}.pem" => 'ca-bundle.crt'
  end

  test { :does_not_apply }
end
