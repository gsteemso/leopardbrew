# stable release 2019-11-09; frozen.
class Isl016 < Formula
  desc "Integer Set Library for the polyhedral model"
  homepage "https://libisl.sourceforge.io"
  url "https://libisl.sourceforge.io/isl-0.16.1.tar.xz"
  sha256 '45292f30b3cb8b9c03009804024df72a79e9b5ab89e41c94752d6ea58a1e4b02'

  keg_only "Conflicts with isl in main repository."

  option :universal

  depends_on "gmp"

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--with-gmp=system",
                          "--with-gmp-prefix=#{Formula["gmp"].opt_prefix}"
    system "make"
    system "make", "install"
    mv lib/'pkgconfig/isl.pc', lib/'pkgconfig/isl-0.16.pc'
    (share/"gdb/auto-load").install Dir["#{lib}/*-gdb.py"]
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <isl/ctx.h>

      int main()
      {
        isl_ctx* ctx = isl_ctx_alloc();
        isl_ctx_free(ctx);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lisl", "-o", "test"
    arch_system "./test"
  end
end
