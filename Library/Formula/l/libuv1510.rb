class Libuv1510 < Formula
  desc 'Multi-platform support library with a focus on asynchronous I/O'
  homepage 'https://github.com/libuv/libuv'
  url 'https://github.com/libuv/libuv/archive/refs/tags/v1.51.0.tar.gz'
  sha256 '27e55cf7083913bfb6826ca78cde9de7647cded648d35f24163f2d31bb9f51cd'
  head 'https://github.com/libuv/libuv.git', :branch => 'v1.x'

  conflicts_with 'libuv', 'libuv1442', :because => 'these are all the same package, and not keg‐only'

  option :universal
  option 'with-docs',  'Build and install documentation (requires Python 3)'
  option 'with-tests', 'Run the build‐time unit tests (requires Internet connection)'

  # The build script passes --gnu to M4, which is only understood by GNU M4 1.4.12
  # or later.  Apple stock M4 on all releases is forked from GNU version 1.4.6.
  depends_on 'm4'         => :build
  depends_on 'pkg-config' => :build
  if MacOS.version <= :snow_leopard and build.with?('docs')
    depends_on :python3   => :build
    depends_on LanguageModuleRequirement.new(:python3, 'sphinx') => :build
  end

  needs :c11;

  def install
    ENV.universal_binary if build.universal?

    args = %W{
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
      }
    args << '--enable-year2038' if ENV.building_pure_64_bit?

    system './autogen.sh'
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'

    if build.with? 'docs'
      ENV.prepend_path 'PATH', HOMEBREW_PREFIX/'bin'
      # This isn't yet handled by the make install process sadly.
      cd 'docs' do
        system 'make', 'man'
        system 'make', 'singlehtml'
        man1.install 'build/man/libuv.1'
        doc.install Dir['build/singlehtml/*']
      end
      ENV.remove 'PATH', HOMEBREW_PREFIX/'bin', ':'
    end
  end

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <uv.h>
      #include <stdlib.h>

      int main()
      {
        uv_loop_t* loop = malloc(sizeof *loop);
        uv_loop_init(loop);
        uv_loop_close(loop);
        free(loop);
        return 0;
      }
    EOS

    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', '-luv', '-o', 'test'
    arch_system './test'
  end
end
