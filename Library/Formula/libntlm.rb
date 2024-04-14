class Libntlm < Formula
  desc "Implements Microsoft's NTLM authentication"
  version "1.7"
  homepage "https://gitlab.com/gsasl/libntlm/"
  url "https://gitlab.com/gsasl/libntlm/-/archive/v1.7/libntlm-v1.7.tar.bz2"
  sha256 "fa1c12c699f71d906b6880981cadba358e5b2e62e3d18424eaa47fa1bd9e918f"

  depends_on "autoconf" => :build
  depends_on "git" => :build
  depends_on "m4" => :build

  def caveats
    <<-EOS.undent
      The NTLM protocol is quite weakly encrypted.  LibNTLM should only be used for
      interoperability, never for security.
    EOS
  end

  def install
    system "./bootstrap"
  end
end
