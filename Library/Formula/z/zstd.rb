# Zstandard 1.5.6 requires C++14.  1.5.5 is the last version that can be built with Tiger‐/Leopard‐
#   era compilers.
class Zstd < Formula
  desc 'Zstandard - fast real-time compression algorithm (see RFC 8878)'
  homepage 'https://github.com/facebook/zstd/'
  url 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz'
  sha256 '9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4'

  option :universal

  depends_on 'lz4' => :recommended

  if MacOS.version < :leopard
    depends_on 'apple-gcc42' => :build  # may not actually be true
    depends_on 'cctools'     => :build  # Needs a more recent "as".
    depends_on 'ld64'        => :build  # Tiger's system `ld` can't build the library.
    depends_on 'make'        => :build  # Tiger's system `make` can't handle the makefile.
  end

  # eliminate dependency extraction, freeing :universal build
  patch :DATA

  def install
    ENV.deparallelize
    # For some reason, type `long long` is not understood unless this is made explicit:
    ENV.append_to_cflags '-std=c99'
    ENV.universal_binary if build.universal?

    # The “install” Make target covers static & dynamic libraries, CLI binaries, and manpages.
    # The “manual” Make target (not used here) would cover API documentation in HTML.
    args = %W[
      prefix=#{prefix}
      install
    ]
    args << 'V=1' if VERBOSE
    # `make check` et sim. are not used because they are specific to the zstd developers.
    make *args
  end # install

  test do
    for_archs bin/'zstd' do |_, cmd|
      system *cmd, '-z', '-o', './test.zst', test_fixtures('test.pdf')
      system *cmd, '-t', 'test.zst'
      system *cmd, '-d', '--rm', 'test.zst'
      result = system 'diff', '-s', 'test', test_fixtures('test.pdf')
      rm 'test'
      result
    end # for_archs |zstd|
  end # test
end # Zstd

__END__
--- old/lib/Makefile
+++ new/lib/Makefile
@@ -200,15 +200,15 @@
 
 # Generate .h dependencies automatically
 
-DEPFLAGS = -MT $@ -MMD -MP -MF
+DEPFLAGS =
 
-$(ZSTD_DYNLIB_DIR)/%.o : %.c $(ZSTD_DYNLIB_DIR)/%.d | $(ZSTD_DYNLIB_DIR)
+$(ZSTD_DYNLIB_DIR)/%.o : %.c $(ZSTD_DYNLIB_DIR)
 	@echo CC $@
-	$(COMPILE.c) $(DEPFLAGS) $(ZSTD_DYNLIB_DIR)/$*.d $(OUTPUT_OPTION) $<
+	$(COMPILE.c) $(DEPFLAGS) $(OUTPUT_OPTION) $<
 
-$(ZSTD_STATLIB_DIR)/%.o : %.c $(ZSTD_STATLIB_DIR)/%.d | $(ZSTD_STATLIB_DIR)
+$(ZSTD_STATLIB_DIR)/%.o : %.c $(ZSTD_STATLIB_DIR)
 	@echo CC $@
-	$(COMPILE.c) $(DEPFLAGS) $(ZSTD_STATLIB_DIR)/$*.d $(OUTPUT_OPTION) $<
+	$(COMPILE.c) $(DEPFLAGS) $(OUTPUT_OPTION) $<
 
 $(ZSTD_DYNLIB_DIR)/%.o : %.S | $(ZSTD_DYNLIB_DIR)
 	@echo AS $@
@@ -222,10 +222,6 @@
 $(BUILD_DIR) $(ZSTD_DYNLIB_DIR) $(ZSTD_STATLIB_DIR):
 	$(MKDIR) -p $@
 
-DEPFILES := $(ZSTD_DYNLIB_OBJ:.o=.d) $(ZSTD_STATLIB_OBJ:.o=.d)
-$(DEPFILES):
-
-include $(wildcard $(DEPFILES))
 
 
 # Special case : building library in single-thread mode _and_ without zstdmt_compress.c
--- old/programs/Makefile
+++ new/programs/Makefile
@@ -323,11 +323,11 @@
 
 # Generate .h dependencies automatically
 
-DEPFLAGS = -MT $@ -MMD -MP -MF
+DEPFLAGS =
 
-$(BUILD_DIR)/%.o : %.c $(BUILD_DIR)/%.d | $(BUILD_DIR)
+$(BUILD_DIR)/%.o : %.c $(BUILD_DIR)
 	@echo CC $@
-	$(COMPILE.c) $(DEPFLAGS) $(BUILD_DIR)/$*.d $(OUTPUT_OPTION) $<
+	$(COMPILE.c) $(DEPFLAGS) $(OUTPUT_OPTION) $<
 
 $(BUILD_DIR)/%.o : %.S | $(BUILD_DIR)
 	@echo AS $@
@@ -336,10 +336,6 @@
 MKDIR ?= mkdir
 $(BUILD_DIR): ; $(MKDIR) -p $@
 
-DEPFILES := $(ZSTD_OBJ:.o=.d)
-$(DEPFILES):
-
-include $(wildcard $(DEPFILES))
 
 
 
