# stable release 2025-07-09; checked 2025-09-13
class Tcsh < Formula
  desc 'Enhanced, fully compatible version of the Berkeley C shell'
  homepage 'http://www.tcsh.org/'
  url 'ftp://ftp.astron.com/pub/tcsh/tcsh-6.24.16.tar.gz'
  sha256 '4208cf4630fb64d91d81987f854f9570a5a0e8a001a92827def37d0ed8f37364'

  def install
    system './configure', "--prefix=#{prefix}", "--sysconfdir=#{etc}"
    system 'make', 'install'
  end

  test do
    (testpath/'test.csh').write <<~EOS
      #!#{bin}/tcsh -f
      set ARRAY=( "t" "e" "s" "t" )
      foreach i ( 1 2 3 4 )
        echo -n $ARRAY[$i]
      end
    EOS
    assert_equal 'test', shell_output("#{bin}/tcsh ./test.csh")
  end
end
