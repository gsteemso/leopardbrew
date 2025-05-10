class Binutils < Formula
  # The only sub‐package applicable to Mac OS (Darwin) is the actual binutils.
  # gas, ld, gold, and all of the other user‐visible sub‐packages are unable to
  # handle Mach-O binaries.
  desc 'GNU Binary Utilities for native development'
  homepage 'https://www.gnu.org/software/binutils/binutils.html'
  url 'https://ftpmirror.gnu.org/binutils/binutils-2.43.1.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/binutils/binutils-2.43.1.tar.lz'
  sha256 '1bd0b4604a7b1f65737c8ad0ce5191daf233843c73c6bf5429eb4e95895bd136'

  # Unfortunately, the binutils sub‐package requires the bfd one, which is
  # designed around thread-local storage and thus cannot be built by GCC 4.x.
  needs :tls

  # No --default-names option as it interferes with Homebrew builds.
  option :universal
  option 'with-zstd', 'Allow debugging‐data compression in ZStandard format'
  option 'without-nls', 'Build without natural‐language support (internationalization)'

  depends_on 'pkg-config' => :build if build.with? 'zstd'
  depends_on 'isl'
  depends_on 'zlib'
  depends_on 'gettext' if build.with? 'nls'
  depends_on 'zstd' => :optional

  def install
    ENV.universal_binary if build.universal?
    ENV.prepend_path ENV['PKG_CONFIG_PATH'], Formula['zstd'].opt_prefix if build.with? 'zstd'
    args = [
      "--prefix=#{prefix}",
      '--disable-debug',
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      '--program-prefix=g',
      '--enable-64-bit-bfd',  # Without this, even “all targets” can’t do 64‐bit ones.
      '--enable-build-warnings',
      '--enable-checking=all',
      '--enable-colored-disassembly',  # Sets a default behaviour for objdump.
      '--enable-compressed-debug-sections=all',
      '--enable-deterministic-archives',  # Makes ar and ranlib default to -D behaviour.
      '--enable-f-for-ifunc-symbols',  # Makes nm use F and f for global and local ifunc symbols.
      '--enable-follow-debug-links',  # Makes readelf & objdump follow debug links by default.
      '--enable-install-libbfd',
      '--enable-plugins',
      '--with-system-zlib',
      '--enable-targets=all',  # Means “all target ISAs”, not “all makefile targets”.
      '--enable-werror',
    ]
    args << '--disable-nls' if build.without? 'nls'
    args << '--with-zstd' if build.with? 'zstd'
    system './configure', *args
    system 'make', 'all-binutils'
    system 'make', 'check-binutils'
    system 'make', 'install-binutils'
  end

  test do
    assert_match /main/, shell_output("#{bin}/gnm #{bin}/gnm")
  end
end
