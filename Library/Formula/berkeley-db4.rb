class BerkeleyDb4 < Formula
  desc "High performance key/value database"
  homepage "https://www.oracle.com/technology/products/berkeley-db/index.html"
  url "http://download.oracle.com/berkeley-db/db-4.8.30.tar.gz"
  sha256 "e0491a07cdb21fb9aa82773bbbedaeb7639cbd0e7f96147ab46141e0045db72a"

  bottle do
    cellar :any
    sha256 "50bf69bfe5d7e5085d8ed1f2ac60882a7ca5c408489143f092751441dfa11787" => :tiger_altivec
  end

  option :universal

  keg_only "BDB 4.8.30 is provided for software that doesn't compile against newer versions."

  # Fix build under Xcode 4.6
  patch :DATA

  def install
    # BerkeleyDB dislikes parallel builds
    ENV.deparallelize

    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      stashdir = 'arch-stashes'
      the_binaries = %w[
        bin/db_archive
        bin/db_checkpoint
        bin/db_deadlock
        bin/db_dump
        bin/db_hotbackup
        bin/db_load
        bin/db_printlog
        bin/db_recover
        bin/db_sql
        bin/db_stat
        bin/db_upgrade
        bin/db_verify
        lib/libdb.a
        lib/libdb-4.8.a
        lib/libdb-4.8.dylib
        lib/libdb_cxx.a
        lib/libdb_cxx-4.8.a
        lib/libdb_cxx-4.8.dylib
      ]
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :x86_64, :ppc64 then ENV.m64
        end
      end

      # “debug” is already disabled
      # per the package instructions, “docdir” is supposed to not have a leading “--”
      args = ["--prefix=#{prefix}",
              "docdir=#{doc}",
              "--enable-cxx"]

      # BerkeleyDB requires you to build everything from a build subdirectory
      cd 'build_unix' do
        system "../dist/configure", *args
        system "make"
        system "make", "install"
        if build.universal?
          system 'make', 'clean'
          Merge.prep(prefix, buildpath/"arch-stashes/bin-#{arch}", the_binaries)
          # undo architecture-specific tweaks before next run
          case arch
            when :i386, :ppc then ENV.un_m32
            when :ppc64, :x86_64 then ENV.un_m64
          end # case arch
        end # universal?
      end # cd build_unix
    end # archs.each

    Merge.mach_o(prefix, stashdir, archs) if build.universal?
  end # install

  test do
    system bin/'db_stat', '-V'
  end # test
end

class Merge
  class << self
    include FileUtils

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        mkpath dest.parent
        cp source, dest
      end # each binary
    end # prep

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def mach_o(keg_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "bin-#{a}"}
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
          mach_o(keg_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', keg_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, keg_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # mach_o
  end # << self
end # Merge

__END__
diff --git a/dbinc/atomic.h b/dbinc/atomic.h
index 0034dcc..50b8b74 100644
--- a/dbinc/atomic.h
+++ b/dbinc/atomic.h
@@ -144,7 +144,7 @@ typedef LONG volatile *interlocked_val;
 #define	atomic_inc(env, p)	__atomic_inc(p)
 #define	atomic_dec(env, p)	__atomic_dec(p)
 #define	atomic_compare_exchange(env, p, o, n)	\
-	__atomic_compare_exchange((p), (o), (n))
+	__atomic_compare_exchange_db((p), (o), (n))
 static inline int __atomic_inc(db_atomic_t *p)
 {
 	int	temp;
@@ -176,7 +176,7 @@ static inline int __atomic_dec(db_atomic_t *p)
  * http://gcc.gnu.org/onlinedocs/gcc-4.1.0/gcc/Atomic-Builtins.html
  * which configure could be changed to use.
  */
-static inline int __atomic_compare_exchange(
+static inline int __atomic_compare_exchange_db(
 	db_atomic_t *p, atomic_value_t oldval, atomic_value_t newval)
 {
 	atomic_value_t was;
