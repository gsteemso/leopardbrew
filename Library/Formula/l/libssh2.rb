# Stable release 2024-10-16; checked 2026-03-15.
class Libssh2 < Formula
  desc 'C library implementing the SSH2 protocol'
  homepage 'http://www.libssh2.org/'
  url 'https://libssh2.org/download/libssh2-1.11.1.tar.xz'
  sha256 '9954cb54c4f548198a7cbebad248bdc87dd64bd26185708a294b2b50771e3769'

  head do
    url "https://github.com/libssh2/libssh2.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option :universal

  depends_on 'openssl3'
  depends_on 'zlib'

  patch :DATA

  def install
    ENV.universal_binary if build.universal?

    # Older GCCs can’t handle “#pragma GCC diagnostic” within functions
    if [:gcc_4_0, :gcc_4_2, :llvm].include? ENV.compiler then
      inreplace 'src/session.c', %r{^#pragma GCC diagnostic[^\n]*$}, ''
    end

    args = %W[
        --prefix=#{prefix}
        --disable-debug
        --disable-dependency-tracking
        --disable-silent-rules
        --disable-docker-tests
        --disable-sshd-tests
        --disable-examples-build
        --with-libssl-prefix=#{Formula['openssl3'].opt_prefix}
        --with-libz
        --with-libz-prefix=#{Formula['zlib'].opt_prefix}
      ]
    args << '--enable-year2038' if Target._64b?

    system './buildconf' if build.head?
    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <libssh2.h>

      int main(void)
      {
      libssh2_exit();
      return 0;
      }
    EOS

    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', "-L#{lib}", '-lssh2', '-o', 'test'
    arch_system './test'
  end # test
end # Libssh2

__END__
--- old/tests/openssh_fixture.c
+++ new/tests/openssh_fixture.c
@@ -234,7 +234,7 @@
 
 static int is_running_inside_a_container(void)
 {
-#ifdef _WIN32
+#if defined(_WIN32) || !defined(getline)
     return 0;
 #else
     const char *cgroup_filename = "/proc/self/cgroup";
