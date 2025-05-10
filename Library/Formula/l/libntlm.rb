class Libntlm < Formula
  desc "Implements Microsoft's NTLM authentication"
  homepage "https://gitlab.com/gsasl/libntlm/"
  url "https://download.savannah.nongnu.org/releases/libntlm/libntlm-1.8.tar.gz"
  sha256 "ce6569a47a21173ba69c990965f73eb82d9a093eb871f935ab64ee13df47fda1"

  option :universal

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'check'
    system "make", "install"
  end

  def caveats
    <<-EOS.undent
      The NTLM protocol is quite weakly encrypted.  LibNTLM should only be used for
      interoperability, never for security.
    EOS
  end
end
