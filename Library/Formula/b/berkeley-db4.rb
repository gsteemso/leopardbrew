require 'merge'

class BerkeleyDb4 < Formula
  include Merge

  desc "High performance key/value database"
  homepage "https://www.oracle.com/technology/products/berkeley-db/index.html"
  url "http://download.oracle.com/berkeley-db/db-4.8.30.tar.gz"
  sha256 "e0491a07cdb21fb9aa82773bbbedaeb7639cbd0e7f96147ab46141e0045db72a"

  keg_only "BDB 4.8.30 is provided for software that doesn't compile against newer versions."

  bottle do
    cellar :any
    sha256 "50bf69bfe5d7e5085d8ed1f2ac60882a7ca5c408489143f092751441dfa11787" => :tiger_altivec
  end

  option :universal

  # Fix build under Xcode 4.6
  patch :DATA

  def install
    if build.universal?
      ENV.allow_universal_binary
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
    end # universal build?
    archs = Target.archset

    # BerkeleyDB dislikes parallel builds
    ENV.deparallelize

    # “debug” is already disabled.
    # Per the package instructions, “docdir” is supposed to not have a leading “--”.
    args = [
      "--prefix=#{prefix}",
      "docdir=#{doc}",
      '--enable-cxx'
    ]

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      # BerkeleyDB requires you to build everything from a build subdirectory
      cd 'build_unix' do
        system "../dist/configure", *args
        system "make"
        system "make", "install"

        if build.universal?
          system 'make', 'clean'
          merge_prep(:binary, arch, the_binaries)
        end # universal build?
      end # cd build_unix
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
    end # universal build?
  end # install

  test do
    arch_system bin/'db_stat', '-V'
  end # test
end # BerkeleyDb4

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
