class Mpg123 < Formula
  desc 'MP3 player for Linux and UNIX'
  homepage 'http://www.mpg123.de/'
  url 'http://www.mpg123.de/download/mpg123-1.32.10.tar.bz2'
  sha256 '87b2c17fe0c979d3ef38eeceff6362b35b28ac8589fbf1854b5be75c9ab6557c'

  option :universal

  def install
    args = [
      "--prefix=#{prefix}",
      '--disable-debug',
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      '--enable-ipv6',
      '--enable-network',
      '--enable-static',
      '--with-audio=coreaudio',
    ]

    if build.universal?
      is_powerpc = false
      ENV.universal_binary
      if ENV.build_archs.map(&:to_s).sort == ['ppc', 'ppc64']
        args << '--with-cpu=altivec' if Hardware::CPU.altivec?
      else # is not pure PowerPC
        ENV.build_archs.each do |arch|
          _cpu = case arch
                   when :i386 then 'x86'  # include everything; could be Hackintosh or VM
                   when :ppc, :ppc64 then 'altivec' if Hardware::CPU.altivec?
                   when :x86_64 then 'x86-64'
                 end
          args << "-Xarch_#{arch.to_s}" << "--with-cpu=#{_cpu}" if _cpu
        end # each |arch|
      end # not pure PowerPC
    end # universal?

    system './configure', *args
    system 'make'
    system 'make', 'install'
  end # install

  test do
    arch_system bin/'mpg123', test_fixtures('test.mp3')
  end # test
end # Mpg123
