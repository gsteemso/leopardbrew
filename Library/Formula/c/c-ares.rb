class CAres < Formula
  desc 'Asynchronous DNS library'
  homepage 'https://c-ares.org/'
  url 'https://github.com/c-ares/c-ares/releases/download/cares-1_28_1/c-ares-1.28.1.tar.gz'
  sha256 '675a69fc54ddbf42e6830bc671eeb6cd89eeca43828eb413243fd2c0a760809d'

  head do
    url 'https://github.com/c-ares/c-ares.git', :branch => 'main'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
    depends_on 'm4'       => :build
  end

  option :universal

  def install
    ENV.universal_binary if build.universal?
    system 'autoreconf', '-fi' if build.head?
    system "./configure", "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-libgcc'
    system "make"
    # running the unit tests requires both C++11 and `googletest`, which seems a lot more trouble
    # than it’s probably worth
    ENV.deparallelize { system "make", "install" }
  end # install

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <ares.h>

      int main()
      {
        ares_library_init(ARES_LIB_INIT_ALL);
        ares_library_cleanup();
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lcares", "-o", "test"
    arch_system testpath/'test'
  end # test
end # CAres
