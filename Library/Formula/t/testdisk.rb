# stable version 2024-02-22; checked 2025-12-06.
class Testdisk < Formula
  desc 'powerful free data-recovery utility'
  homepage 'http://www.cgsecurity.org/wiki/TestDisk'
  url 'http://www.cgsecurity.org/testdisk-7.2.tar.bz2'
  sha256 'f8343be20cb4001c5d91a2e3bcd918398f00ae6d8310894a5a9f2feb813c283f'

  # Correct a typo in the partition‐GUID data.
  patch :DATA

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make', 'install'
  end # install

  test do
    path = 'test.dmg'
    system 'hdiutil', 'create', '-megabytes', '10', path
    system bin/'testdisk', '/list', path
  end
end # Testdisk

__END__
--- old/src/common.h
+++ new/src/common.h
@@ -141,7 +141,7 @@
 #define GPT_ENT_TYPE_FREEBSD_UFS	\
 	(const efi_guid_t){le32(0x516e7cb6),le16(0x6ecf),le16(0x11d6),0x8f,0xf8,{0x00,0x02,0x2d,0x09,0x71,0x2b}}
 #define GPT_ENT_TYPE_FREEBSD_ZFS	\
-	(const efi_guid_t){le32(0x516e7cb),le16(0x6ecf),le16(0x11d6),0x8f,0xf8,{0x00,0x02,0x2d,0x09,0x71,0x2b}}
+	(const efi_guid_t){le32(0x516e7cba),le16(0x6ecf),le16(0x11d6),0x8f,0xf8,{0x00,0x02,0x2d,0x09,0x71,0x2b}}
 /*
  * The following is unused but documented here to avoid reuse.
  *
