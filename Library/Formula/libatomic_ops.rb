class LibatomicOps < Formula
  desc "Implementations for atomic memory update operations"
  homepage "https://github.com/ivmai/libatomic_ops/"
  url "https://github.com/ivmai/libatomic_ops/releases/download/v7.8.2/libatomic_ops-7.8.2.tar.gz"
  sha256 "d305207fe207f2b3fb5cb4c019da12b44ce3fcbc593dfd5080d867b1a2419b51"

  patch :p0, :DATA

  option :universal

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --enable-shared
    ]
<<<<<<< HEAD
    args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')
=======
    args << "--disable-silent-rules" if ARGV.verbose?
>>>>>>> 364b89a2ef (Ongoing efforts to unstupid superenv and to add more --universal builds)

    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"
  end
end

__END__
--- tests/Makefile.in.orig     2024-03-25 11:38:47.000000000 -0700
+++ tests/Makefile.in          2024-03-25 11:38:20.000000000 -0700
@@ -559,7 +559,7 @@
 
 # We distribute test_atomic_include.h and list_atomic.c, since it is hard
 # to regenerate them on Windows without sed.
-BUILT_SOURCES = test_atomic_include.h list_atomic.i list_atomic.o
+BUILT_SOURCES = test_atomic_include.h list_atomic.o
 CLEANFILES = list_atomic.i list_atomic.o
 AM_CPPFLAGS = \
         -I$(top_builddir)/src -I$(top_srcdir)/src \
