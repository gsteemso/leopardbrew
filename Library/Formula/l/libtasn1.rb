require 'merge'

class Libtasn1 < Formula
  include Merge

  desc "ASN.1 structure parser library"
  homepage "https://www.gnu.org/software/libtasn1/"
  url "http://ftpmirror.gnu.org/libtasn1/libtasn1-4.19.0.tar.gz"
  mirror "https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz"
  sha256 "1613f0ac1cf484d6ec0ce3b8c06d56263cc7242f1c23b30d82d23de345a63f7a"

  bottle do
    sha256 "ab864e12a279d8f7f2f7a3a8e3d30f495a54ae7e9e448b9f45746e2362f81f72" => :tiger_altivec
  end

  option :universal

  def install
    if build.universal?
      ENV.allow_universal_binary
      the_binaries = %w[
        bin/asn1Coding
        bin/asn1Decoding
        bin/asn1Parser
        lib/libtasn1.6.dylib
        lib/libtasn1.a
      ]
    end # universal build?
    archs = Target.archset

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      system "./configure", "--prefix=#{prefix}",
                            "--disable-dependency-tracking",
                            "--disable-silent-rules"
      system "make"
      system "make", "check"
      system "make", "install"
      if build.universal?
        system 'make', 'distclean'
        merge_prep(:binary, arch, the_binaries)
      end # universal build?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
    end # universal build?
  end # install

  test do
    (testpath/"pkix.asn").write <<-EOS.undent
      PKIX1 { }
      DEFINITIONS IMPLICIT TAGS ::=
      BEGIN
      Dss-Sig-Value ::= SEQUENCE {
           r       INTEGER,
           s       INTEGER
      }
      END
    EOS
    (testpath/"assign.asn1").write <<-EOS.undent
      dp PKIX1.Dss-Sig-Value
      r 42
      s 47
    EOS
    for_archs bin/'asn1Coding' do |_, cmd|
      system *cmd, 'pkix.asn', 'assign.asn1'
      result = assert_match /Decoding: SUCCESS/,
        shell_output("#{cmd[0..-2] * ' '} asn1Decoding pkix.asn assign.out PKIX1.Dss-Sig-Value 2>&1")
      rm 'assign.out'
      result
    end # for_archs |cmd|
  end # test
end # Libtasn1
