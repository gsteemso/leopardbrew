class Libxslt < Formula
  desc 'C XSLT library developed for GNOME'
  homepage 'https://gitlab.gnome.org/GNOME/libxslt/-/wikis/home'
  url 'https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz'
  sha256 '5a3d6b383ca5afc235b171118e90f5ff6aa27e9fea3303065231a6d403f0183a'

  keg_only :provided_by_osx

  head do
    url 'https://gitlab.gnome.org/GNOME/libxslt.git'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end # head

  option :universal
  option 'with-python', 'Build with Python 2.7 and Python 3 language bindings'

  depends_on 'pkg-config' => :build
  depends_on 'libxml2'
  depends_on :python => :optional
  depends_on :python3 if build.with? 'python'

  def install
    ENV.universal_binary if build.universal?
    ENV.delete 'PYTHONPATH'
    mktemp do
      maintemp = pwd
      if build.head?
        ENV['NOCONFIGURE'] = 'yes'
        system './autogen.sh'
      end
      args = %W[
          --prefix=#{prefix}
          --disable-dependency-tracking
          --disable-silent-rules
          --without-debug
          --without-debugger
          --with-libxml-prefix=#{Formula['libxml2'].opt_prefix}
          --enable-static
        ]
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
            _here = Pathname.new(pwd)
            (_here/'libxslt').install_symlink_to "#{maintemp}/libxslt/libxslt.la", "#{maintemp}/libxslt/.libs"
            (_here/'libexslt').install_symlink_to "#{maintemp}/libexslt/libexslt.la", "#{maintemp}/libexslt/.libs"
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
      (Formula['python'].site_packages/'libxslt.pth').binwrite "#{opt_lib}/python2.7/site-packages\n"
      py3 = Formula['python3']
      (py3.site_packages/'libxslt.pth').binwrite "#{opt_lib}/python#{py3.xy}/site-packages\n"
    end # build with python?
  end # post_install

  def caveats
    cavs = <<-_.undent if build.with? 'python'
      Python bindings for LibXSLT were installed.  The library itself already exists
      in Mac OS, and needs to be kept aside; but Python bindings to it do not, and are
      therefore not a problem.  The `libxslt.pth` file described in the automated
      announcement below has already been written, and the one for Python 3 as well.

    _
    cavs += <<-EOS.undent
      To allow the nokogiri gem to link against this libxslt run:
        gem install nokogiri -- --with-xslt-dir=#{opt_prefix}
    EOS
    cavs
  end
end # Libxslt
