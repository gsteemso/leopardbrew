class Icu4c < Formula
  desc "C/C++ and Java libraries for Unicode and globalization"
  homepage "https://icu.unicode.org/"
  url "https://github.com/unicode-org/icu/releases/download/release-56-2/icu4c-56_2-src.tgz"
  version "56.2"
  sha256 "187faf495133f4cffa22d626896e7288f43d342e6af5eb8b214a1bf37bad51a6"

  keg_only :provided_by_osx, "OS X provides libicucore.dylib (but nothing else)."

  option :universal
  option :cxx11

  # build tries to pass -compatibility_version to ld, which Tiger's ld can't grok
  depends_on :ld64 if MacOS.version < :leopard

  # The first two of these are nearly identical patches as were submitted upstream regarding
  # ICU4C 55.1.  The third addresses a makefile misconfiguration preventing :universal builds,
  # and would not have been needed if there was a “--disable-dependency-tracking” option.
  patch :p0, :DATA

  def install
    ENV.universal_binary if build.universal?
    # Tiger's libtool chokes if it's passed -w
    ENV.enable_warnings if MacOS.version < :leopard
    ENV.cxx11 if build.cxx11?

    args = ["--prefix=#{prefix}", "--disable-samples", "--enable-static"]
    args << "--with-library-bits=64" if MacOS.prefer_64_bit?

    ENV['CPPFLAGS'] = '-DU_CHARSET_IS_UTF8=1'
    # Could also be done in *args, but that elicits irritating and unhelpful usage warnings.

    cd "source" do
      system "./runConfigureICU", "MacOSX", *args
      system "make"
      system "make", "check"
      system "make", "install"
    end
  end

  test do
    system "#{bin}/gendict", "--uchars", "/usr/share/dict/words", "dict"
  end
end

__END__
--- source/common/putil.cpp.old           2024-01-11 15:21:48.000000000 -0800
+++ source/common/putil.cpp               2024-01-11 15:24:06.000000000 -0800
@@ -117,6 +117,13 @@
 #endif
 
 /*
+ * Mac OS X 10.4 doesn't use its localtime_r() declaration in <time.h> if either _ANSI_SOURCE or _POSIX_C_SOURCE is #defined.
+ */
+#if defined(U_TZNAME) && U_PLATFORM_IS_DARWIN_BASED && (defined(_ANSI_SOURCE) || defined(_POSIX_C_SOURCE))
+U_CFUNC struct tm *localtime_r(const time_t *, struct tm *);
+#endif
+
+/*
  * Only include langinfo.h if we have a way to get the codeset. If we later
  * depend on more feature, we can test on U_HAVE_NL_LANGINFO.
  *
--- source/tools/toolutil/pkg_genc.c.old  2024-01-11 16:29:38.000000000 -0800
+++ source/tools/toolutil/pkg_genc.c      2024-01-11 16:31:15.000000000 -0800
@@ -113,13 +113,13 @@
     int8_t      hexType; /* HEX_0X or HEX_0h */
 } assemblyHeader[] = {
     /* For gcc assemblers, the meaning of .align changes depending on the */
-    /* hardware, so we use .balign 16 which always means 16 bytes. */
+    /* hardware, so we use .p2align 4 which always means 16 bytes. */
     /* https://sourceware.org/binutils/docs/as/Pseudo-Ops.html */
     {"gcc",
         ".globl %s\n"
         "\t.section .note.GNU-stack,\"\",%%progbits\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "#ifdef U_HIDE_DATA_SYMBOL\n"
         "\t.hidden %s\n"
         "#endif\n"
@@ -137,7 +137,7 @@
         "#endif\n"
         "\t.data\n"
         "\t.const\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "_%s:\n\n",
 
         ".long ","",HEX_0X
@@ -145,7 +145,7 @@
     {"gcc-cygwin",
         ".globl _%s\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "_%s:\n\n",
 
         ".long ","",HEX_0X
@@ -153,7 +153,7 @@
     {"gcc-mingw64",
         ".globl %s\n"
         "\t.section .rodata\n"
-        "\t.balign 16\n"
+        "\t.p2align 4\n"
         "%s:\n\n",
 
         ".long ","",HEX_0X
--- source/config/mh-darwin.old           2024-02-13 22:24:55.000000000 -0800
+++ source/config/mh-darwin               2024-02-13 22:31:30.000000000 -0800
@@ -54,14 +54,14 @@
 
 ## Compilation and dependency rules
 %.$(STATIC_O): $(srcdir)/%.c
-	$(call SILENT_COMPILE,$(strip $(COMPILE.c) $(STATICCPPFLAGS) $(STATICCFLAGS)) -MMD -MT "$*.d $*.o $*.$(STATIC_O)" -o $@ $<)
+	$(call SILENT_COMPILE,$(strip $(COMPILE.c) $(STATICCPPFLAGS) $(STATICCFLAGS)) -o $@ $<)
 %.o: $(srcdir)/%.c
-	$(call SILENT_COMPILE,$(strip $(COMPILE.c) $(DYNAMICCPPFLAGS) $(DYNAMICCFLAGS)) -MMD -MT "$*.d $*.o $*.$(STATIC_O)" -o $@ $<)
+	$(call SILENT_COMPILE,$(strip $(COMPILE.c) $(DYNAMICCPPFLAGS) $(DYNAMICCFLAGS)) -o $@ $<)
 
 %.$(STATIC_O): $(srcdir)/%.cpp
-	$(call SILENT_COMPILE,$(strip $(COMPILE.cc) $(STATICCPPFLAGS) $(STATICCXXFLAGS)) -MMD -MT "$*.d $*.o $*.$(STATIC_O)" -o $@ $<)
+	$(call SILENT_COMPILE,$(strip $(COMPILE.cc) $(STATICCPPFLAGS) $(STATICCXXFLAGS)) -o $@ $<)
 %.o: $(srcdir)/%.cpp
-	$(call SILENT_COMPILE,$(strip $(COMPILE.cc) $(DYNAMICCPPFLAGS) $(DYNAMICCXXFLAGS)) -MMD -MT "$*.d $*.o $*.$(STATIC_O)" -o $@ $<)
+	$(call SILENT_COMPILE,$(strip $(COMPILE.cc) $(DYNAMICCPPFLAGS) $(DYNAMICCXXFLAGS)) -o $@ $<)
 
 ## Versioned libraries rules
 
