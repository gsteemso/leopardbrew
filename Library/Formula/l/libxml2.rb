# stable version 2025-07-15; checked 2025-08-06
class Libxml2 < Formula
  desc 'C XML library developed for GNOME'
  homepage 'https://gitlab.gnome.org/GNOME/libxml2/-/wikis/home'
  url 'https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz'
  sha256 '03d006f3537616833c16c53addcdc32a0eb20e55443cba4038307e3fa7d8d44b'

  keg_only :provided_by_osx

  head do
    url 'https://gitlab.gnome.org/GNOME/libxml2.git'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal
  option 'with-python', 'Build with Python 2.7 and Python 3 language bindings'

  depends_on 'pkg-config' => :build
  depends_on 'readline'
  if build.with? 'python'
    depends_on :python2
    depends_on :python3
  end

  enhanced_by 'libiconv'
  enhanced_by 'xz'

  resource 'conformance_test_suite' do
    url 'http://www.w3.org/XML/Test/xmlts20130923.tar.gz'
    sha256 '9b61db9f5dbffa545f4b8d78422167083a8568c59bd1129f94138f936cf6fc1f'
  end

  def install
    ENV.universal_binary if build.universal?
    ENV.delete 'PYTHONPATH'
    mktemp do
      maintemp = pwd
      if build.head?
        ENV['NOCONFIGURE'] = 'yes'
        system "#{buildpath}/autogen.sh"
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
#      args << '--with-docs' if build.head?  # docs require Doxygen
      args << "--with-iconv=#{Formula['libiconv'].opt_prefix}" if active_enhancements.include? 'libiconv'
      args << "--with-lzma=#{Formula['xz'].opt_prefix}" if active_enhancements.include? 'xz'
      args << (build.with?('python') ? '--with-python' : '--without-python')
      system "#{buildpath}/configure", *args
      inreplace ['Makefile', 'python/Makefile'], '-lpython2.7', '-undefined dynamic_lookup' if build.with? 'python'
      system 'make'
      resource('conformance_test_suite').stage(buildpath/'xmlconf')
      system 'make', 'check'
      system 'make', 'install'
      if build.with? 'python'
        ENV.delete 'PYTHONPATH'
        mktemp do
          system "#{buildpath}/configure", *args
          Pathname.new(pwd).install_symlink_to "#{maintemp}/libxml2.la", "#{maintemp}/.libs"
          system 'make', '-C', 'python'
          system 'make', '-C', 'python', 'check'
          system 'make', '-C', 'python', 'install'
        end # secondary temporary directory
      end # build with python?
    end # main temporary directory
  end # install

  def post_install
    if build.with? 'python'
      # There are no system Python bindings to LibXML2, so we can install our own even though the
      # library itself has to be keg‐only.
      # Our Python will be missing if system Python was deemed adequate, but even if site_packages
      # is not there, Pathname⸬binwrite will simply create it before writing to the file.
      (Formula['python2'].site_packages/'libxml2.pth').binwrite "#{opt_lib}/python2.7/site-packages\n"
      py3 = Formula['python3']
      (py3.site_packages/'libxml2.pth').binwrite "#{opt_lib}/python#{py3.xy}/site-packages\n"
    end # build with python?
  end # post_install

  def caveats; <<-_.undent
      If LibXML2 is built --with-python, Python 2 and 3 bindings for it are installed.
      An obsolete version of the library itself is included with Mac OS, so the built
      library must be keg‐only; but Python bindings to it are not, so they may safely
      be made visible via the appropriate search paths.
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
