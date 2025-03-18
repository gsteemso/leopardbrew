class Binutils241 < Formula
  # The only sub‐package applicable to Mac OS (Darwin) is the actual binutils.
  # gas, ld, gold, and all of the other user‐visible sub‐packages are unable to
  # handle Mach-O binaries.
  desc 'GNU Binary Utilities for native development (legacy version not using Thread‐Local Storage)'
  homepage 'https://www.gnu.org/software/binutils/binutils.html'
  url 'https://ftpmirror.gnu.org/binutils/binutils-2.41.tar.lz'
  mirror 'https://sourceware.org/pub/binutils/releases/binutils-2.41.tar.lz'
  sha256 'eab3444055882ed5eb04e2743d03f0c0e1bc950197a4ddd31898cd5a2843d065'

  # No --default-names option as it interferes with Homebrew builds.
  option :universal
  option 'with-zstd', 'Allow debugging‐data compression in ZStandard format'
  option 'without-nls', 'Build without natural‐language support (internationalization)'

  depends_on 'pkg-config' => :build if build.with? 'zstd'
  depends_on 'isl'
  depends_on 'zlib'
  depends_group ['nls', ['gettext', 'libiconv']] => :recommended
  depends_on 'zstd' => :optional

  def install
    ENV.universal_binary if build.universal?
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
      '--enable-shared',  # Makes the BFD and Opcodes libraries dynamically shared.
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
  end # install

  test do
    gnu_nm = (bin/'gnm').to_s
    for_archs bin/'gnm' do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s]) << gnu_nm << gnu_nm
      assert_match /main/, Utils.popen_read(*arch_cmd)
    end
  end # test
end # Binutils241

__END__
