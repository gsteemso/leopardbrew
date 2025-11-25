# Stable release 2013-12-10; discontinued? (checked 2025-11-13).
# This formula is intended to be used by gcc formulæ with java support.
class Ecj < Formula
  desc 'Standalone version of the Eclipse Java compiler'
  homepage 'https://gcc.gnu.org/'
  url 'ftp://sourceware.org/pub/java/ecj-4.9.jar'
  mirror 'https://mirrors.kernel.org/sources.redhat.com/java/ecj-4.9.jar'
  sha256 '9506e75b862f782213df61af67338eb7a23c35ff425d328affc65585477d34cd'

  def install
    (share/'java').install "ecj-#{version}.jar" => 'ecj.jar'
  end

  test { :does_not_apply }
end # Ecj
