class GasPreprocessor < Formula
  desc 'Perl script implementing a subset of the GNU as preprocessor that Apple’s as doesn’t'
  homepage 'https://github.com/FFmpeg/gas-preprocessor'
  head 'https://github.com/FFmpeg/gas-preprocessor.git'

  def install
    bin.install 'gas-preprocessor.pl'
    prefix.install 'test.S'
  end

  def caveats; <<-_.undent
      gas-preprocessor is only applicable to assembly language code fed to Apple’s
      `as`.

      Testing this formula requires a specially-constructed assembly-language file,
      which currently only exists for ARM code.  ARM code is not understood by GCC
      unless you have the iOS SDK installed.  If you can translate the source file
      in this formula’s Cellar directory from ARM assembly to Intel or PowerPC, we
      urge you to do so and send us a copy.
    _
  end

  test do
    unless (objdump = which('ObjectDump', "#{ENV['PATH']}:#{OPTDIR}/ld64/bin"))
      opoo 'Cannot test this formula – missing tool',
           'To test this formula requires the ObjectDump tool from the {ld64} package,',
           'which is not installed.'
      return false
    end
    arm_SDKs = Dir.glob("#{MacOS.active_developer_dir}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk").sort
    armccbin = "#{arm_SDKs[-1]}/Developer/usr/bin" unless arm_SDKs.empty?
    unless (armccbin and (armcc = re_which(%r{^arm-apple-darwin\d+-gcc-}, "#{ENV['PATH']}:#{armccbin}")))
      opoo 'Cannot test this formula – missing data',
           'To test this formula requires a specially-constructed assembly-language',
           'source file, which currently only exists for ARM code – but GCC for ARM',
           'does not appear to be installed.'
      return false
    end
    without_archflags do
      system "#{bin}/gas-preprocessor.pl", '-as-type', 'gas', '--', armcc, '-arch', 'arm', '-c',
                                                                  "#{prefix}/test.S", '-o', 'test.o'
      system objdump, '-d', 'test.o', '>', 'disasm'
      system armcc, '-arch', 'arm', '-c', "#{prefix}/test.S", '-o', 'test.o'
      system objdump, '-d', 'test.o', '>', 'disasm-ref'
      system 'diff', '-q', 'disasm-ref', 'disasm'  # returns false if they differ
    end # without archflags
  end # test
end # GasPreprocessor
