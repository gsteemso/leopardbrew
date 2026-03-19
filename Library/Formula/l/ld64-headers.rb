# The Tiger and Leopard stock headers are too old to build {ld64}… which is required to build the {cctools} we get these from.
class Ld64Headers < Formula
  desc 'assorted headers from Apple open source, for building ld64'
  homepage 'https://github.com/apple-oss-distributions/cctools/tree/cctools-855'
  url 'https://github.com/apple-oss-distributions/cctools/archive/refs/tags/cctools-855.tar.gz'
  sha256 '7c31652cefde324fd6dc6f4dabbcd936986430039410a65c98d4a7183695f6d7'

  keg_only :provided_by_osx

  depends_on MaximumMacOSRequirement => :snow_leopard

  resource 'mach-machine-h' do
    url 'https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-2422.90.20.tar.gz'
    sha256 '58c42f91e690dea501ba8f3e2ec47db68d975d9e72cae2bbf508df1e3ab5504b'
  end

  def install
    # only supports DSTROOT, not PREFIX
    inreplace 'include/Makefile', '/usr/include', '/include'
    system 'make', 'installhdrs', "DSTROOT=#{prefix}", "RC_ProjectSourceVersion=#{version}"
    # installs a bunch of headers we don't need to DSTROOT/usr/local/include
    (prefix/'usr').rmtree

    # ld64 requires an updated mach/machine.h to build
    resource('mach-machine-h').stage { (include/'mach').install 'osfmk/mach/machine.h' }

    # We just grabbed the exact same download used by {cctools}.  Avoid duplication:
    HOMEBREW_CACHE.install_symlink_to HOMEBREW_CACHE/'ld64-headers-855.tar.gz' => 'cctools-855.tar.gz'
  end

  test { :does_not_apply }
end
