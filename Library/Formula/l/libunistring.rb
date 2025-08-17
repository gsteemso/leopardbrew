# stable release 2024-10-16; checked 2025-08-06
class Libunistring < Formula
  desc 'C string library for manipulating Unicode strings'
  homepage 'https://www.gnu.org/software/libunistring/'
  url 'http://ftpmirror.gnu.org/libunistring/libunistring-1.3.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.xz'
  sha256 'f245786c831d25150f3dfb4317cda1acc5e3f79a5da4ad073ddca58886569527'

  option :universal

  def install
    ENV.universal_binary if build.universal?

    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    # `make check` hardcodes bit widths, causing failure with 32b/64b universal builds.
    # ...with Tiger on a G5, fails 3 gnulib tests but no actual libunistring tests.
    system 'make', 'install'
  end
end
