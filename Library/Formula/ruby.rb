class Ruby < Formula
  desc "Powerful, clean, object-oriented scripting language"
  homepage "https://www.ruby-lang.org/"
  url "https://cache.ruby-lang.org/pub/ruby/3.3/ruby-3.3.3.tar.xz"
  sha256 "83c0995388399c9555bad87e70af069755b5a9d84bbaa74aa22d1e37ff70fc1e"

  head do
    url "https://github.com/ruby/ruby.git"
    depends_on "autoconf" => :build
  end

  option :universal
  option "with-suffix", "Suffix commands with “33”"
  option "with-doc", "Install documentation"
  option "with-tcltk", "Install with Tcl/Tk support"

  depends_on 'pkg-config' => :build
  depends_on 'libyaml'
  depends_on 'openssl3'
  depends_on 'readline' => :recommended
  depends_on 'gdbm' => :optional
  depends_on 'gmp' => :optional
  depends_on 'libffi' => :optional
  depends_on :x11 if build.with? 'tcltk'

  patch :DATA if MacOS.version < :snow_leopard

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      mkdir 'arch-stashes'
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end

    # mcontext types had a member named `ss` instead of `__ss`
    # prior to Leopard; see
    # https://github.com/mistydemeo/tigerbrew/issues/473
    if Hardware::CPU.intel? && MacOS.version < :leopard
      inreplace "signal.c" do |s|
        s.gsub! "->__ss.", "->ss."
        s.gsub! "__rsp", "rsp"
        s.gsub! "__rbp", "rbp"
        s.gsub! "__esp", "esp"
        s.gsub! "__ebp", "ebp"
      end

      inreplace "vm_dump.c" do |s|
        s.gsub! /uc_mcontext->__(ss)\.__(r\w\w)/,
                "uc_mcontext->\1.\2"
        s.gsub! "mctx->__ss.__##reg",
                "mctx->ss.reg"
        # missing include in vm_dump; this is an ugly solution
        s.gsub! '#include "iseq.h"',
                %{#include "iseq.h"\n#include <ucontext.h>}
      end
    end

    system "autoconf" if build.head?

    args = [
      "--prefix=#{prefix}",
      '--disable-silent-rules',
      '--enable-debug-env',  # this enables an environment variable, not a debug build
      '--enable-mkmf-verbose',
      '--enable-shared',
      '--with-mantype=man',
      "--with-sitedir=#{HOMEBREW_PREFIX}/lib/ruby/site_ruby",
      "--with-vendordir=#{HOMEBREW_PREFIX}/lib/ruby/vendor_ruby"
    ]

    args << "--program-suffix=33" if build.with? "suffix"
    args << "--with-out-ext=tk" if build.without? "tcltk"
    args << "--disable-install-doc" if build.without? "doc"
    args << "--disable-dtrace" unless MacOS::CLT.installed?
    args << "--without-gmp" if build.without? "gmp"

    # see https://bugs.ruby-lang.org/issues/10272
    args << "--with-setjmp-type=setjmp" if MacOS.version == :lion

    paths = [
      Formula["libyaml"].opt_prefix,
      Formula["openssl3"].opt_prefix
    ]

    %w[readline gdbm gmp libffi].each do |dep|
      paths << Formula[dep].opt_prefix if build.with? dep
    end

    args << "--with-opt-dir=#{paths.join(":")}"

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :x86_64, :ppc64 then ENV.m64
        end
        mkdir "arch-stashes/#{arch}-bin"
      end

      args << "--with-arch=#{arch}"  # in theory this supports building fat binaries directly; in
                                     # practice, it fails when it gets to the coroutines
      # specifically, for some reason `configure` thinks the endianness is “universal”!
      case arch
        when :ppc then args.concat %w[ac_cv_c_bigendian=yes --with-coroutine=ppc]
        when :ppc64 then args.concat %w[ac_cv_c_bigendian=yes --with-coroutine=ppc64]
        when :i386 then args.concat %w[ac_cv_c_bigendian=no --with-coroutine=x86]
        when :x86_64 then args.concat %w[ac_cv_c_bigendian=no --with-coroutine=amd64]
      end

      args << 'ac_cv_func_fcopyfile=no' if MacOS.version < :snow_leopard

      system "./configure", *args

      # Ruby has been configured to look in the HOMEBREW_PREFIX for the
      # sitedir and vendordir directories; however we don't actually want to create
      # them during the install.
      #
      # These directories are empty on install; sitedir is used for non-rubygems
      # third party libraries, and vendordir is used for packager-provided libraries.
      inreplace "tool/rbinstall.rb" do |s|
        s.gsub! 'prepare "extension scripts", sitelibdir', ""
        s.gsub! 'prepare "extension scripts", vendorlibdir', ""
        s.gsub! 'prepare "extension objects", sitearchlibdir', ""
        s.gsub! 'prepare "extension objects", vendorarchlibdir', ""
      end

      system "make"
      system "make", "install"
      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, "arch-stashes/#{arch}-bin")
        # these headers are architecture-dependent; when installing :universal, these copies will
        # be used in merging them all together
        #   .ext/include/ppc64-darwin9.0/ruby/config.h
        #   (...)
        mkdir "arch-stashes/#{arch}-h"
#        cp include/'<header>', "arch-stashes/#{arch}-h/<header>"
        # undo architecture-specific tweaks before next run
        case arch
          when :i386, :ppc then ENV.un_m32
          when :x86_64, :ppc64 then ENV.un_m64
        end # case arch
      end # universal?
    end # archs.each

    if build.universal?
      Merge.mach_o(prefix, 'arch-stashes', archs)
      Merge.c_headers(include, 'arch-stashes', archs)
    end # universal?
  end # install

  def post_install
    # Customize rubygems to look/install in the global gem directory
    # instead of in the Cellar, making gems last across reinstalls
    config_file = lib/"ruby/#{abi_version}/rubygems/defaults/operating_system.rb"
    config_file.unlink if config_file.exist?
    config_file.write rubygems_config

    # Create the sitedir and vendordir that were skipped during install
    mkdir_p `#{bin}/ruby -e 'require "rbconfig"; print RbConfig::CONFIG["sitearchdir"]'`
    mkdir_p `#{bin}/ruby -e 'require "rbconfig"; print RbConfig::CONFIG["vendorarchdir"]'`
  end # post_install

  def abi_version
    "3.3.0"
  end

  def rubygems_config; <<-EOS.undent
    module Gem
      class << self
        alias :old_default_dir :default_dir
        alias :old_default_path :default_path
        alias :old_default_bindir :default_bindir
        alias :old_ruby :ruby
      end

      def self.default_dir
        path = [
          "#{HOMEBREW_PREFIX}",
          "lib",
          "ruby",
          "gems",
          "#{abi_version}"
        ]

        @default_dir ||= File.join(*path)
      end

      def self.private_dir
        path = if defined? RUBY_FRAMEWORK_VERSION then
                 [
                   File.dirname(RbConfig::CONFIG['sitedir']),
                   'Gems',
                   RbConfig::CONFIG['ruby_version']
                 ]
               elsif RbConfig::CONFIG['rubylibprefix'] then
                 [
                  RbConfig::CONFIG['rubylibprefix'],
                  'gems',
                  RbConfig::CONFIG['ruby_version']
                 ]
               else
                 [
                   RbConfig::CONFIG['libdir'],
                   ruby_engine,
                   'gems',
                   RbConfig::CONFIG['ruby_version']
                 ]
               end

        @private_dir ||= File.join(*path)
      end

      def self.default_path
        if Gem.user_home && File.exist?(Gem.user_home)
          [user_dir, default_dir, private_dir]
        else
          [default_dir, private_dir]
        end
      end

      def self.default_bindir
        "#{HOMEBREW_PREFIX}/bin"
      end

      def self.ruby
        "#{opt_bin}/ruby#{"33" if build.with? "suffix"}"
      end
    end
    EOS
  end # rubygems_config

  test do
    output = `#{bin}/ruby -e "puts 'hello'"`
    assert_equal "hello\n", output
    assert_equal 0, $?.exitstatus
  end # test
end # Ruby

class Merge
  module Pathname_extension
    def is_bare_mach_o?
      # header word 0, magic signature:
      #   MH_MAGIC    = 'feedface' – value with lowest‐order bit clear
      #   MH_MAGIC_64 = 'feedfacf' – same value with lowest‐order bit set
      # low‐order 24 bits of header word 1, CPU type:  7 is x86, 12 is ARM, 18 is PPC
      # header word 3, file type:  no types higher than 10 are defined
      # header word 5, net size of load commands, is far smaller than the filesize
      if (self.file? and self.size >= 28 and mach_header = self.binread(24).unpack('N6'))
        raise('Fat binary found where bare Mach-O file expected') if mach_header[0] == 0xcafebabe
        ((mach_header[0] & 0xfffffffe) == 0xfeedface and
          [7, 12, 18].detect { |item| (mach_header[1] & 0x00ffffff) == item } and
          mach_header[3] < 11 and
          mach_header[5] < self.size)
      else
        false
      end
    end unless method_defined?(:is_bare_mach_o?)
  end # Pathname_extension

  class << self
    include FileUtils

    def scour_keg(keg_prefix, stash, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f).extend(Pathname_extension)
        spb = s_p + pn.basename
        if pn.directory?
          Dir.mkdir "#{stash}/#{spb}"
          scour_keg(keg_prefix, stash, spb)
        # the number of things that look like Mach-O files but aren’t is horrifying, so test
        elsif ((not pn.symlink?) and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end # scour_keg

    def c_headers(include_dir, stash_root, archs, sub_path = '')
      # Architecture-specific <header>.<extension> files need to be surgically combined and were
      # stashed for this purpose.  The differences are relatively minor and can be “#if defined ()”
      # together.  We make the simplifying assumption that the architecture-dependent headers in
      # question are present on all architectures.
      #
      # Don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{stash_root}/#{archs[0]}-h/#{s_p}*"].each do |basis_file|
        spb = s_p + File.basename(basis_file)
        if File.directory?(basis_file)
          c_headers(include_dir, stash_root, archs, spb)
        else
          diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of
                           # three‐element hashes; containing the arch, the hunk’s displacement
                           # (number of basis‐file lines it replaces), and an array of its lines.
          archs[1..-1].each do |a|
            raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stash_root}/#{a}-h/#{spb}`
            next unless raw_diffs
            # The unified diff output begins with two lines identifying the source files, which are
            # followed by a series of hunk records, each describing one difference that was found.
            # Each hunk record begins with a line that looks like:
            # @@ -line_number,length_in_lines +line_number,length_in_lines @@
            diff_hunks = raw_diffs.lines[2..-1].join('').split(/(?=^@@)/)
            diff_hunks.each do |d|
              # lexical sorting of numbers requires that they all be the same length
              base_linenumber_string = ('00000' + d.match(/\A@@ -(\d+)/)[1])[-6..-1]
              unless diffpoints.has_key?(base_linenumber_string)
                diffpoints[base_linenumber_string] = []
              end
              length_match = d.match(/\A@@ -\d+,(\d+)/)
              # if the hunk length is 1, the comma and second number are not present
              length_match = (length_match == nil ? 1 : length_match[1].to_i)
              line_group = []
              # we want the lines that are either unchanged between files or only found in the non‐
              # basis file; and to shave off the leading ‘+’ or ‘ ’
              d.lines { |line| line_group << line[1..-1] if line =~ /^[+ ]/ }
              diffpoints[base_linenumber_string] << {
                :arch => a,
                :displacement => length_match,
                :hunk_lines => line_group
              }
            end # each diff hunk |d|
          end # each arch |a|
          # Ideally, the logic would account for overlapping and/or different-displacement hunks at
          # this point; but since most packages do not seem to generate such in the first place, it
          # can wait.  That said, packages exist (e.g. both Python 2 and Python 3) which can and do
          # generate quad fat binaries, so it can’t be ignored forever.
          basis_lines = []
          File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
          # Bear in mind that the line-array indices are one less than the line numbers.
          #
          # Start with the last diff point so the insertions don’t screw up our line numbering:
          diffpoints.keys.sort.reverse.each do |index_string|
            diff_start = index_string.to_i - 1
            diff_end = index_string.to_i + diffpoints[index_string][0][:displacement] - 2
            adjusted_lines = [
              "\#if defined (__#{archs[0]}__)\n",
              basis_lines[diff_start..diff_end],
              *(diffpoints[index_string].map { |dp|
                  [ "\#elif defined (__#{dp[:arch]}__)\n", *(dp[:hunk_lines]) ]
                }),
              "\#endif\n"
            ]
            basis_lines[diff_start..diff_end] = adjusted_lines
          end # each key |index_string|
          File.new("#{include_dir}/#{spb}", 'w').syswrite(basis_lines.join(''))
        end # if not a directory
      end # each |basis_file|
    end # c_headers

    # install_prefix expects a Pathname object, not just a string
    def mach_o(install_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "#{a}-bin"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          mach_o(install_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', install_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, install_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # mach_o
  end # << self
end # Merge

__END__
--- old/io_buffer.c	2024-06-30 18:15:25.000000000 -0700
+++ new/io_buffer.c	2024-06-30 18:16:54.000000000 -0700
@@ -28,10 +28,12 @@
 size_t RUBY_IO_BUFFER_PAGE_SIZE;
 size_t RUBY_IO_BUFFER_DEFAULT_SIZE;
 
-#ifdef _WIN32
-#else
+#ifndef _WIN32
 #include <unistd.h>
 #include <sys/mman.h>
+#ifndef MAP_ANONYMOUS
+#define MAP_ANONYMOUS MAP_ANON
+#endif
 #endif
 
 enum {
--- old/shape.c	2024-06-30 19:16:02.000000000 -0700
+++ new/shape.c	2024-06-30 19:20:28.000000000 -0700
@@ -14,6 +14,9 @@
 
 #ifndef _WIN32
 #include <sys/mman.h>
+#ifndef MAP_ANONYMOUS
+#define MAP_ANONYMOUS MAP_ANON
+#endif
 #endif
 
 #ifndef SHAPE_DEBUG
--- old/thread_pthread_mn.c	2024-06-30 19:16:38.000000000 -0700
+++ new/thread_pthread_mn.c	2024-06-30 19:21:48.000000000 -0700
@@ -166,6 +166,9 @@
 static rb_nativethread_lock_t nt_machine_stack_lock = RB_NATIVETHREAD_LOCK_INIT;
 
 #include <sys/mman.h>
+#ifndef MAP_ANONYMOUS
+#define MAP_ANONYMOUS MAP_ANON
+#endif
 
 // vm_stack_size + machine_stack_size + 1 * (guard page size)
 static inline size_t
