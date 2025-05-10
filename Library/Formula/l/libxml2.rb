class Libxml2 < Formula
  desc "GNOME XML library"
  homepage "http://xmlsoft.org"
  url "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz"
  sha256 "24ae78ff1363a973e6d8beba941a7945da2ac056e19b53956aeb6927fd6cfb56"

  head do
    url "https://git.gnome.org/browse/libxml2", :using => :git

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option :universal
  option 'with-python', 'Build with Python 2.7 language bindings'

  depends_on 'python' => :optional
  depends_on 'python3' if build.with? 'python'
  depends_on 'libiconv'
  depends_on "xz"
  depends_on "zlib"
  depends_on 'pkg-config' => :build

  keg_only :provided_by_osx

  def install
    ENV.deparallelize
    ENV.universal_binary if build.universal?
    if build.head?
      inreplace "autogen.sh", "libtoolize", "glibtoolize"
      system "./autogen.sh"
    end

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --without-debug
      --with-iconv=#{Formula['libiconv'].opt_prefix}
      --with-lzma=#{Formula["xz"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]
    # the package builds the python bindings by default
    args << "--without-python" if build.without? "python"

    system "./configure", *args
    inreplace ['Makefile', 'python/Makefile'], '-lpython2.7', '-undefined dynamic_lookup'
    system "make"
    system "make", "check" if (build.without?('python') or
                               (build.universal? == Tab.for_name('python').universal?) )
    system "make", "install"

    if build.with? "python"
      cd "python" do
        # We need to insert our include dir first
        inreplace "setup.py", "includes_dir = [", "includes_dir = ['#{include}', '#{MacOS.sdk_path}/usr/include',"
        system "python3", "setup.py", "install", "--prefix=#{prefix}"
      end
    end
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <libxml/tree.h>

      int main()
      {
        xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr root_node = xmlNewNode(NULL, BAD_CAST "root");
        xmlDocSetRootElement(doc, root_node);
        xmlFreeDoc(doc);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    args = `#{bin}/xml2-config --cflags --libs`.split
    args += %w[test.c -o test]
    system ENV.cc, *args
    system "./test"
  end
end
