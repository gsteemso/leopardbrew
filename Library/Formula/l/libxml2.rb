class Libxml2 < Formula
  desc 'C XML library developed for GNOME'
  homepage 'https://gitlab.gnome.org/GNOME/libxml2/-/wikis/home'
  url 'https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.4.tar.xz'
  sha256 '24175ec30a97cfa86bdf9befb7ccf4613f8f4b2713c5103e0dd0bc9c711a2773'

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
  depends_on 'xz'
  depends_on :python => :optional
  depends_on :python3 if build.with? 'python'

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
          --with-lzma=#{Formula['xz'].opt_prefix}
          --with-readline
          --enable-static
          --with-zlib
        ]
#      args << '--with-docs' if build.head?  # docs require Doxygen
      args << (build.with?('python') ? '--with-python' : '--without-python')
      system "#{buildpath}/configure", *args
      inreplace ['Makefile', 'python/Makefile'], '-lpython2.7', '-undefined dynamic_lookup' if build.with? 'python'
      system 'make'
      system 'make', 'check'
      system 'make', 'install'
      if build.with? 'python'
        ENV.delete 'PYTHONPATH'
        mktemp do
          old_path = ENV['PATH']
          begin
            # replace the unversioned `python` 2 in $PATH with the unversioned `python` 3 in Python3/libexec/bin
            ENV['PATH'] = ENV['PATH'].sub(Formula['python'].opt_bin.to_s, "#{Formula['python3'].opt_prefix}/libexec/bin")
            system "#{buildpath}/configure", *args
            Pathname.new(pwd).install_symlink_to "#{maintemp}/libxml2.la", "#{maintemp}/.libs"
            system 'make', '-C', 'python'
            system 'make', '-C', 'python', 'check'
            system 'make', '-C', 'python', 'install'
          ensure
            ENV['PATH'] = old_path
          end
        end # secondary temporary directory
      end # build with python?
    end # main temporary directory
  end # install

  def post_install
    if build.with? 'python'
      # There are no system Python bindings to LibXML2, so we can install our own even though the
      # library itself has to be keg‐only.
      # Our Python will be missing if system Python was deemed adequate, but even if site_packages is
      # not there, Pathname⸬binwrite will simply create it before writing to the file.
      (Formula['python'].site_packages/'libxml2.pth').binwrite "#{opt_lib}/python2.7/site-packages\n"
      py3 = Formula['python3']
      (py3.site_packages/'libxml2.pth').binwrite "#{opt_lib}/python#{py3.xy}/site-packages\n"
    end # build with python?
  end # post_install

  def caveats; <<-_.undent if build.with? 'python'
      Python bindings for LibXML2 were installed.  The library itself already exists
      in Mac OS, and needs to be kept aside; but Python bindings to it do not, and are
      therefore not a problem.  The `libxml2.pth` file described in the automated
      announcement below has already been written, and the one for Python 3 as well.
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
