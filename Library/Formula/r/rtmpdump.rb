# This is a monkey-patched bit of idiocy to make up for there not being any kind of formal release,
# just an undifferentiated Git repository.
class Rtmpdump < Formula
  desc "Tool and library for downloading RTMP streaming media"
  homepage "https://rtmpdump.mplayerhq.hu"
  head "git://git.ffmpeg.org/rtmpdump"

  option :universal

  # Tiger's ld fails with:
  # "common symbols not allowed with MH_DYLIB output format with the -multi_module option"
  depends_on :ld64 if MacOS.version < :leopard
  depends_on "openssl3"

  # Is this still true?  Hells if I know!
  fails_with :llvm do
    build 2336
    cause "Crashes at runtime"
  end

  def install
    ENV.universal_binary if build.universal?
    # Fix version error in Makefiles, while it’s still there...  Do not expect it to be fixed any
    # time soon; the last update took most of a decade.
    inreplace ['Makefile', 'librtmp/Makefile'], 'VERSION=v2.4', 'VERSION=v2.6'
    ENV.deparallelize
    system "make", "SYS=darwin", "prefix=#{prefix}", "mandir=#{man}", "sbindir=#{bin}", "install"
  end
end
