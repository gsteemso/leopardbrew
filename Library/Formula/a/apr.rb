# stable release 2025-05-16; checked 2025-08-17
class Apr < Formula
  desc 'Apache Portable Runtime library'
  homepage 'https://apr.apache.org/'
  url 'https://dlcdn.apache.org/apr/apr-1.7.6.tar.bz2'
  sha256 '49030d92d2575da735791b496dc322f3ce5cff9494779ba8cc28c7f46c5deb32'

  keg_only :provided_by_osx, 'Apple’s CLT package contains apr.'

  option :universal

  # On older Darwins, POSIX.1 shared memory and SysV semaphores are broken in various ways both
  # subtle and overt.  Prevent the former from being selected as the basis of named shared memory
  # implementation, and the latter from being selected as the preferred lock implementation.
  patch :DATA if MacOS.version <= :snow_leopard

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize
    ENV.append 'CPPFLAGS', '-D_DARWIN_USE_64_BIT_INODE' if MacOS.version >= :leopard
    ENV.append 'CPPFLAGS', '-DDARWIN_10' if build.universal? and MacOS.version >= :tiger and MacOS.version <= :lion

    system './configure', "--prefix=#{prefix}"
    system 'make'
    # “make check” fails, inexplicably.  It doesn’t (the same way) when using the broken system
    # primitives we patched it to not use!  Graah.
    system 'make', 'install'
    (lib/'apr.exp').unlink  # Delete this stray .exp file.
  end

  test do
    system "#{bin}/apr-1-config", '--link-libtool', '--libs'
  end
end

__END__
--- old/configure
+++ new/configure
@@ -25864,7 +25864,7 @@
 
 fi
 
-ac_rc=yes
+ac_rc=no
 for ac_spec in header:sys/mman.h func:mmap func:munmap func:shm_open              func:shm_unlink; do
     ac_type=`echo "$ac_spec" | sed -e 's/:.*$//'`
     ac_item=`echo "$ac_spec" | sed -e 's/^.*://'`
@@ -31499,7 +31499,7 @@
     hasposixser="0"
 fi
 
-ac_rc=yes
+ac_rc=no
 for ac_spec in func:semget func:semctl func:semop define:SEM_UNDO; do
     ac_type=`echo "$ac_spec" | sed -e 's/:.*$//'`
     ac_item=`echo "$ac_spec" | sed -e 's/^.*://'`
@@ -31790,7 +31790,7 @@
 
 fi
 
-ac_rc=yes
+ac_rc=no
 for ac_spec in func:semget func:semctl func:semop define:SEM_UNDO; do
     ac_type=`echo "$ac_spec" | sed -e 's/:.*$//'`
     ac_item=`echo "$ac_spec" | sed -e 's/^.*://'`
