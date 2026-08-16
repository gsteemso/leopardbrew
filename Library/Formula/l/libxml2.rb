# stable version 2026-04-16; checked 2026-07-23
class Libxml2 < Formula
  desc 'XML library originally developed for GNOME'
  homepage 'https://gitlab.gnome.org/GNOME/libxml2/-/wikis/home'
  url 'https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz'
  sha256 '78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07'

  keg_only :provided_by_osx

  head do
    url 'https://gitlab.gnome.org/GNOME/libxml2.git'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal
  option 'with-docs', 'Build the documentation (requires Doxygen)'

  depends_on 'pkg-config' => :build
  depends_on 'readline'
  depends_on 'doxygen' if build.with?('docs')

  enhanced_by 'libiconv'

  resource 'conformance_test_suite' do
    url 'http://www.w3.org/XML/Test/xmlts20130923.tar.gz'
    sha256 '9b61db9f5dbffa545f4b8d78422167083a8568c59bd1129f94138f936cf6fc1f'
  end

  def install
    ENV.universal_binary if build.universal?
    if build.head?
      ENV['NOCONFIGURE'] = 'yes'
      system './autogen.sh'
    end
    args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
        --without-debug
        --with-history
        --with-readline
        --enable-static
      ]
    args << '--with-docs' if build.with? 'docs'
    args << "--with-iconv=#{Formula['libiconv'].opt_prefix}" if active_enhancement_names.include? 'libiconv'
    system './configure', *args
    system 'make'
    resource('conformance_test_suite').stage('xmlconf')
    system 'make', 'check'
    system 'make', 'install'
  end # install

  def caveats; <<-_.undent
      The Python bindings for LibXML2 will be removed in LibXML2 release 2.16, and it
      now requires Doxygen (which can’t be built with the long‐obsolete Apple GCC) to
      build them anyway.  As such, this formula’s `--with-python` option has likewise
      been removed.
    _
  end # caveats

  test do
    (testpath/'test.c').write <<-EOS.undent
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
    args = `#{bin}/xml2-config --cflags --libs`.split
    args += %w[test.c -o test]
    system ENV.cc, *args
    arch_system './test'
  end
end
