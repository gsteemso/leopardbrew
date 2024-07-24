class Readline < Formula
  desc "Library for command-line editing"
  homepage "https://tiswww.case.edu/php/chet/readline/rltop.html"
  url "http://ftpmirror.gnu.org/readline/readline-8.2.tar.gz"
  mirror "https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz"
  sha256 "3feb7171f16a84ee82ca18a36d7b9be109a52c04f492a053331d7d1095007c35"
  version '8.2_p10'

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-001'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-001'
    sha256 'bbf97f1ec40a929edab5aa81998c1e2ef435436c597754916e6a5868f273aff7'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-002'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-002'
    sha256 'e06503822c62f7bc0d9f387d4c78c09e0ce56e53872011363c74786c7cd4c053'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-003'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-003'
    sha256 '24f587ba46b46ed2b1868ccaf9947504feba154bb8faabd4adaea63ef7e6acb0'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-004'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-004'
    sha256 '79572eeaeb82afdc6869d7ad4cba9d4f519b1218070e17fa90bbecd49bd525ac'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-005'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-005'
    sha256 '622ba387dae5c185afb4b9b20634804e5f6c1c6e5e87ebee7c35a8f065114c99'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-006'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-006'
    sha256 'c7b45ff8c0d24d81482e6e0677e81563d13c74241f7b86c4de00d239bc81f5a1'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-007'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-007'
    sha256 '5911a5b980d7900aabdbee483f86dab7056851e6400efb002776a0a4a1bab6f6'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-008'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-008'
    sha256 'a177edc9d8c9f82e8c19d0630ab351f3fd1b201d655a1ddb5d51c4cee197b26a'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-009'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-009'
    sha256 '3d9885e692e1998523fd5c61f558cecd2aafd67a07bd3bfe1d7ad5a31777a116'
  end

  patch :p0 do
    url 'http://ftpmirror.gnu.org/readline/readline-8.2-patches/readline82-010'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.2-patches/readline82-010'
    sha256 '758e2ec65a0c214cfe6161f5cde3c5af4377c67d820ea01d13de3ca165f67b4c'
  end

  keg_only :shadowed_by_osx, <<-EOS.undent
    OS X provides the BSD libedit library, which shadows libreadline.
    In order to prevent conflicts when programs look for libreadline we are
    defaulting this GNU Readline installation to keg-only.
  EOS

  def install
    ENV.universal_binary
    # Since we don't set any CFLAGS, readline adds some
    # which break the build as they're not supported by GCC 4.2
    ENV.append_to_cflags "-g -Os" if ENV.compiler == :gcc
    system "./configure", "--prefix=#{prefix}", "--enable-multibyte"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <stdlib.h>
      #include <readline/readline.h>

      int main()
      {
        printf("%s\\n", readline("test> "));
        return 0;
      }
    EOS
    ENV.universal_binary
    system ENV.cc, "test.c", "-lreadline", "-o", "test"
    assert_equal "Hello, World!", pipe_output("./test", "Hello, World!\n").strip
  end
end
