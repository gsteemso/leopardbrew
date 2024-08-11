class Xa < Formula
  desc '6502 cross assembler'
  homepage 'http://www.floodgap.com/retrotech/xa/'
  url 'http://www.floodgap.com/retrotech/xa/dists/xa-2.4.1.tar.gz'
  sha256 '63c12a6a32a8e364f34f049d8b2477f4656021418f08b8d6b462be0ed3be3ac3'

  def install
    system 'make', 'test'
    ENV.deparallelize { system 'make', 'install', "DESTDIR=#{prefix}" }
  end

  test do
    (testpath/'foo.a').write "jsr $ffd2\n"

    system "#{bin}/xa", 'foo.a'
    code = File.open('a.o65', 'rb') { |f| f.read.unpack('C*') }
    assert_equal [0x20, 0xd2, 0xff], code
  end
end
