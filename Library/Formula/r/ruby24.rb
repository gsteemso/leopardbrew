class Ruby24 < Formula
  desc 'This version of the scripting language is required to build more modern versions'
  homepage 'https://www.ruby-lang.org/'
  url 'https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.10.tar.xz'
  sha256 'd5668ed11544db034f70aec37d11e157538d639ed0d0a968e2f587191fc530df'

  RV = '2.4'

  option :universal

  depends_on 'pkg-config' => :build

  depends_on 'gdbm'
  depends_on 'gmp'
  depends_on 'libffi'
  depends_on 'libyaml'
  depends_on 'openssl'
  depends_on 'readline'
  depends_on :x11

  # fix for ext/fiddle/libffi-3.2.1/src/x86/win32.S
  # based on https://github.com/macports/macports-ports/blob/8964c98f0e33e4aaabc851d8b684f4c709edceef/devel/libffi/files/PR-44170.patch
  patch :DATA

  def install
    args = [
      "--prefix=#{prefix}",
      "--program-suffix=-#{RV}",
      '--disable-dependency-tracking',
      '--enable-debug-env',  # this enables an environment variable, not a debug build
      '--enable-load-relative',
      '--with-mantype=man',
      '--enable-shared',
      '--disable-silent-rules',
      "--with-sitedir=#{HOMEBREW_PREFIX}/lib/ruby/site_ruby",
      "--with-vendordir=#{HOMEBREW_PREFIX}/lib/ruby/vendor_ruby"
    ]

    if build.universal?
      ENV.universal_binary
      args << "--with-arch=#{Target.local_archs.join(',')}"
    end

    args << '--disable-dtrace' unless MacOS::CLT.installed?

    # Older Darwins do not implement this function as Ruby expects, and are missing at least one
    # definition in the header as well.
    args << 'ac_cv_func_fcopyfile=no' if MacOS.version < :snow_leopard  # is this the right cutoff?

    system './configure', *args

    # Ruby has been configured to look in the HOMEBREW_PREFIX for the sitedir and vendordir
    # directories; however we don't actually want to create them during the install, after which
    # they are empty anyway.  sitedir is used for non-rubygems third‐party libraries, and
    # vendordir is used for packager-provided libraries.
    inreplace 'tool/rbinstall.rb' do |s|
      s.gsub! 'prepare "extension scripts", sitelibdir', ''
      s.gsub! 'prepare "extension scripts", vendorlibdir', ''
      s.gsub! 'prepare "extension objects", sitearchlibdir', ''
      s.gsub! 'prepare "extension objects", vendorarchlibdir', ''
    end

    system 'make'
    system 'make', 'update-gems'
    system 'make', 'extract-gems'
    system 'make', 'install'
  end # install

  def post_install
    # Customize rubygems to look/install in the global gem directory instead of in the Cellar,
    # making gems last across reinstalls:
    config_file = lib/"ruby/#{abi_version}/rubygems/defaults/operating_system.rb"
    config_file.unlink if config_file.exist?
    config_file.write rubygems_config
    # Create the sitedir and vendordir that were skipped during install:
    mkdir_p `#{bin}/ruby-#{RV} -e 'require "rbconfig"; print RbConfig::CONFIG["sitearchdir"]'`
    mkdir_p `#{bin}/ruby-#{RV} -e 'require "rbconfig"; print RbConfig::CONFIG["vendorarchdir"]'`
  end # post_install

  def abi_version; "#{RV}.0"; end

  def rubygems_config; <<-EOS.undent
    module Gem
      class << self
        alias :old_default_dir :default_dir
        alias :old_default_path :default_path
        alias :old_default_bindir :default_bindir
        alias :old_ruby :ruby

        def default_dir; @default_dir ||= "#{HOMEBREW_PREFIX}/lib/ruby/gems/#{abi_version}"; end

        def private_dir; @private_dir ||= \
          if defined? RUBY_FRAMEWORK_VERSION
            [ File.dirname(RbConfig::CONFIG['sitedir']), 'Gems', RbConfig::CONFIG['ruby_version'] ]
          elsif RbConfig::CONFIG['rubylibprefix']
            [ RbConfig::CONFIG['rubylibprefix'],         'gems', RbConfig::CONFIG['ruby_version'] ]
          else
            [ RbConfig::CONFIG['libdir'],   ruby_engine, 'gems', RbConfig::CONFIG['ruby_version'] ]
          end
        end

        def default_path
          if Gem.user_home and File.exist?(Gem.user_home)
            [user_dir, default_dir, private_dir]
          else
            [default_dir, private_dir]
          end
        end

        def default_bindir; "#{HOMEBREW_PREFIX}/bin"; end

        def ruby; "#{opt_bin}/ruby-#{RV}"; end
      end
    end
    EOS
  end # rubygems_config

  test do
    for_archs(bin/"ruby-#{RV}") { |_, cmd|
      assert_equal "hello\n", shell_output("#{cmd * ' '} -e 'puts \"hello\"'")
    }
  end # test
end # Ruby24

__END__
--- a/ext/fiddle/libffi-3.2.1/src/x86/win32.S	2017-04-04 11:14:27 +0200
+++ b/ext/fiddle/libffi-3.2.1/src/x86/win32.S	2017-04-04 11:16:20 +0200
@@ -528,7 +528,7 @@
         .text
  
         # This assumes we are using gas.
-        .balign 16
+        .p2align 4
 FFI_HIDDEN(ffi_call_win32)
         .globl	USCORE_SYMBOL(ffi_call_win32)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -711,7 +711,7 @@
         popl %ebp
         ret
 .ffi_call_win32_end:
-        .balign 16
+        .p2align 4
 FFI_HIDDEN(ffi_closure_THISCALL)
         .globl	USCORE_SYMBOL(ffi_closure_THISCALL)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -724,7 +724,7 @@
         push	%ecx
         jmp	.ffi_closure_STDCALL_internal
 
-        .balign 16
+        .p2align 4
 FFI_HIDDEN(ffi_closure_FASTCALL)
         .globl	USCORE_SYMBOL(ffi_closure_FASTCALL)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -753,7 +753,7 @@
 
 .LFE1:
         # This assumes we are using gas.
-        .balign 16
+        .p2align 4
 FFI_HIDDEN(ffi_closure_SYSV)
 #if defined(X86_WIN32)
         .globl	USCORE_SYMBOL(ffi_closure_SYSV)
@@ -897,7 +897,7 @@
 #define RAW_CLOSURE_USER_DATA_OFFSET (RAW_CLOSURE_FUN_OFFSET + 4)
 
 #ifdef X86_WIN32
-        .balign 16
+        .p2align 4
 FFI_HIDDEN(ffi_closure_raw_THISCALL)
         .globl	USCORE_SYMBOL(ffi_closure_raw_THISCALL)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -916,7 +916,7 @@
 #endif /* X86_WIN32 */
 
         # This assumes we are using gas.
-        .balign 16
+        .p2align 4
 #if defined(X86_WIN32)
         .globl	USCORE_SYMBOL(ffi_closure_raw_SYSV)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -1039,7 +1039,7 @@
 #endif /* !FFI_NO_RAW_API */
 
         # This assumes we are using gas.
-        .balign	16
+        .p2align 4
 FFI_HIDDEN(ffi_closure_STDCALL)
         .globl	USCORE_SYMBOL(ffi_closure_STDCALL)
 #if defined(X86_WIN32) && !defined(__OS2__)
@@ -1184,7 +1184,6 @@
 
 #if defined(X86_WIN32) && !defined(__OS2__)
         .section	.eh_frame,"w"
-#endif
 .Lframe1:
 .LSCIE1:
         .long	.LECIE1-.LASCIE1  /* Length of Common Information Entry */
@@ -1343,6 +1342,7 @@
         /* End of DW_CFA_xxx CFI instructions.  */
         .align 4
 .LEFDE5:
+#endif
 
 #endif /* !_MSC_VER */
 
