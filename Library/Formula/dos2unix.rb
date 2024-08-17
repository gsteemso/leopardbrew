class Dos2unix < Formula
  desc 'Convert text between DOS, UNIX, and Mac formats'
  homepage 'http://waterlan.home.xs4all.nl/dos2unix.html'
  url 'https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.5.2.tar.gz'
  mirror 'https://downloads.sourceforge.net/project/dos2unix/dos2unix/7.5.2/dos2unix-7.5.2.tar.gz'
  sha256 '264742446608442eb48f96c20af6da303cb3a92b364e72cb7e24f88239c4bf3a'
  head 'https://git.code.sf.net/p/dos2unix/dos2unix.git'

  devel do
    url 'https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.5.3-beta1.tar.gz'
    sha256 'e3dddcf7d02dbd070a2581ec685dd85792b54ebdb109d23c9c147f4300d766fe'
  end

  def install
    system 'make', 'install', "prefix=#{prefix}"
  end

  test do
    # write a file with lf
    path = testpath/'test.txt'
    path.write "foo\nbar\n"

    # unix2mac: convert lf to cr
    system bin/'unix2mac', path
    assert_equal "foo\rbar\r", path.read

    # mac2unix: convert cr to lf
    system bin/'mac2unix', path
    assert_equal "foo\nbar\n", path.read

    # unix2dos: convert lf to cr+lf
    system bin/'unix2dos', path
    assert_equal "foo\r\nbar\r\n", path.read

    # dos2unix: convert cr+lf to lf
    system bin/'dos2unix', path
    assert_equal "foo\nbar\n", path.read
  end
end
