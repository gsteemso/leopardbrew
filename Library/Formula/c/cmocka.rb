class Cmocka < Formula
  desc 'Unit testing framework for C'
  homepage 'https://cmocka.org/'
  url 'https://cmocka.org/files/1.1/cmocka-1.1.7.tar.xz'
  sha256 '810570eb0b8d64804331f82b29ff47c790ce9cd6b163e98d47a4807047ecad82'

  option :universal

  depends_on 'cmake' => :build

  def install
    ENV.universal_binary if build.universal?
    mkdir 'build' do
      system 'cmake', '..', '-DUNIT_TESTING=On', *std_cmake_args
      system 'make'
      system 'make', 'test'
      system 'make', 'install'
    end
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <stdarg.h>
      #include <stddef.h>
      #include <setjmp.h>
      #include <cmocka.h>

      static void null_test_success(void **state) {
        (void) state; /* unused */
      }

      int main(void) {
        const struct CMUnitTest tests[] = {
            cmocka_unit_test(null_test_success),
        };
        return cmocka_run_group_tests(tests, NULL, NULL);
      }
    EOS
    system ENV.cc, 'test.c', "-I#{include}", "-L#{lib}", '-lcmocka', '-o', 'test'
    arch_system './test'
  end # test
end # Cmocka
