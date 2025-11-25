# Stable release 2024-09-01; checked 2025-11-23.
class Isl < Formula
  desc 'Integer Set Library for the polyhedral model'
  homepage 'https://libisl.sourceforge.io/'
  # Note:  Always use tarball instead of git tag for stable version.
  url 'https://libisl.sourceforge.io/isl-0.27.tar.xz'
  mirror 'https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.27.tar.xz'
  sha256 '6d8babb59e7b672e8cb7870e874f3f7b813b6e00e6af3f8b04f7579965643d5c'

  head do
    url 'https://repo.or.cz/isl.git'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
  end

  option :universal

  depends_on 'libtool' => :build
  depends_on 'python3' => :build
  depends_on 'gmp'

  def install
    ENV.universal_binary if build.universal?
    system './autogen.sh' if build.head?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          "--with-gmp-prefix=#{Formula['gmp'].opt_prefix}",
                          "PYTHON=#{Formula['python3'].opt_bin}/python3"
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
    (share/'gdb/auto-load').install Dir["#{lib}/*-gdb.py"]
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <isl/ctx.h>

      int main()
      {
        isl_ctx* ctx = isl_ctx_alloc();
        isl_ctx_free(ctx);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', "-L#{lib}", '-lisl', '-o', 'test'
    arch_system './test'
  end # test
end # Isl
