# stable release contemporaneous with Mac OS 10.14–10.15; frozen
class Cctools < Formula
  desc 'Apple’s binary and cross-compilation tools'
  homepage 'https://github.com/apple-oss-distributions/cctools/tree/cctools-855'
  url 'https://github.com/apple-oss-distributions/cctools/archive/refs/tags/cctools-855.tar.gz'
  sha256 '7c31652cefde324fd6dc6f4dabbcd936986430039410a65c98d4a7183695f6d7'

  keg_only :provided_by_osx, 'This package duplicates tools shipped by Xcode.'

  depends_on :ld64

  cxxstdlib_check :skip

  if MacOS.version >= :snow_leopard
    option 'with-llvm', 'Build with Link-Time Optimization support'
    depends_on 'llvm' => :optional
  end

  patch :p0 do
    url 'https://trac.macports.org/export/129741/trunk/dports/devel/cctools/files/cctools-829-lto.patch'
    sha256 '8ed90e0eef2a3afc810b375f9d3873d1376e16b17f603466508793647939a868'
  end

  patch :p0 do
    url 'https://trac.macports.org/export/129741/trunk/dports/devel/cctools/files/PR-37520.patch'
    sha256 '921cba3546389809500449b08f4275cfd639295ace28661c4f06174b455bf3d4'
  end

  patch :p0 do
    url 'https://trac.macports.org/export/129741/trunk/dports/devel/cctools/files/cctools-839-static-dis_info.patch'
    sha256 'f49162b5c5d2753cf19923ff09e90949f01379f8de5604e86c59f67441a1214c'
  end

  # Fix building libtool with LTO disabled.
  patch do
    url 'https://gist.githubusercontent.com/mistydemeo/9fc5589d568d2fc45fb5/raw/c752d5c4567809c10b14d623b6c2d7416211b33a/libtool-no-lto.diff'
    sha256 '3b687f2b9388ac6c4acac2b7ba28d9fd07f2a16e7d2dad09aa2255d98ec1632b'
  end

  # strnlen() was not available until Lion.
  patch :DATA if MacOS.version < :lion

  def install
    ENV.deparallelize      # See ⟨https://github.com/mistydemeo/tigerbrew/issues/102⟩.

    inreplace('libstuff/lto.c', '@@LLVM_LIBDIR@@', Formula['llvm'].opt_lib) if build.with? 'llvm'

    # Fixes build with gcc-4.2: https://trac.macports.org/ticket/43745
    ENV.append_to_cflags '-std=gnu99'

    # Astoundingly, RC_ARCHS is not actually used anywhere, despite being passed to every $(MAKE) invocation.
    # We can ignore RC_OS because “macos” is the default.
    # We set SUBDIRS_32 empty to prevent wasting time building the (very obsolete) classic version of ld.
    args = %W[
      DSTROOT=#{prefix}
      CC=#{ENV.cc}
      CXX=#{ENV.cxx}
      LTO=#{'-DLTO_SUPPORT' if build.with? 'llvm'}
      RC_CFLAGS=#{ENV.cflags}
      RC_ProjectSourceVersion=#{version}
      SUBDIRS_32=
      TRIE=
      USE_DEPENDENCY_FILE=NO
    ]

    system 'make', 'install_tools', *args

    # {cctools} installs relative to the supplied DSTROOT as though it were /, so we need to move things to the standard paths.  We
    # also merge the /usr and /usr/local trees.
    prefix.install Dir["#{prefix}/usr/local/Open*"]  # The open-source license and the version plist.
    # bin/
    bin.install Dir["#{prefix}/usr{,/local}/bin/*"]  # usr/local/efi/bin/mtoc is just a copy of usr/local/bin/mtoc.
    # `strip` expects the presence of `ld`, and under certain conditions will crash if it isn’t there.
    bin.install_symlink_to MacOS.ld => 'ld'
    # include/
    include.install Dir["#{prefix}/usr/local/include/*"]              # There are lots of things in usr/local/include/, one of them
    (include/'mach-o').install Dir["#{prefix}/usr/include/mach-o/*"]  # being mach-o/, but usr/include/ _only_ contains mach-o/.
    # libexec/
    (libexec/'as').install Dir["#{prefix}/usr{,/local}/libexec/as/*"]  # Both have libexec/as/, but with no namespace collisions.
    # share/man/
    man.install Dir["#{prefix}/usr/share/man/*"]                     # We have man1 in three places, man3 in two, and man5 here.
    man1.install Dir["#{prefix}/usr/local{,/efi/share}/man/man1/*"]  # The other two man1.
    man3.install Dir["#{prefix}/usr/local/man/man3/*"]               # The other man3.
  end # install

  test do
    assert_match '/usr/lib/libSystem.B.dylib', shell_output("#{bin}/otool -L #{bin}/install_name_tool")
  end
end # Cctools

__END__
--- old/otool/ofile_print.c
+++ new/otool/ofile_print.c
# strnlen() was not available pre-Snow Leopard.
@@ -231,6 +231,10 @@
 /* The maximum section alignment allowed to be specified, as a power of two */
 #define MAXSECTALIGN		15 /* 2**15 or 0x8000 */
 
+#ifndef strnlen
+static size_t strnlen(const char *s, size_t maxlen) { size_t len = 0; while ((len <= maxlen) && s[len]) len++; return len; }
+#endif
+
 static void print_arch(
     struct fat_arch *fat_arch);
 static void print_cputype(
