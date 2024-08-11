class Scons < Formula
  desc 'Substitute for classic “make” with autotools-like functionality'
  homepage 'https://www.scons.org/'
  url 'https://files.pythonhosted.org/packages/ec/5c/cc835a17633de8b260ec1a6e527b5c57f4975cee5949f49e57ad4d5fab4b/scons-4.8.0.tar.gz'
  sha256 '2c7377ff6a22ca136c795ae3dc3d0824696e5478d1e4940f2af75659b0d45454'

  head do
    url "file://#{HOMEBREW_LIBRARY_PATH}/test/tarballs/testball-0.1.tbz"  # dummy download, we don’t use it
    sha256 '91e3f7930c98d7ccfb288e115ed52d06b0e5bc16fec7dce8bdda86530027067b'
  end

  depends_on :python3

  def install
    if build.head?
      system 'pip3', 'install', 'scons'
    else
      system 'pip3', 'install', '.'
    end
    # pip3 installs the executable scripts inside the Python framework.  This does not facilitate
    # using them directly.  If we symlink them into `bin`, it keeps our installation from looking
    # empty and lets them be correctly `brew link`ed.
    # The previous, non‐pip3’d version of this formula also put them in `libexec` for proper
    # importation, but that’s redundant after pip3 did its work.
    p3f = Formula['python3']
    scons_bins = Dir.glob("#{p3f.opt_prefix}/Frameworks/Python.framework/Versions/#{p3f.version.to_s.slice(/^[^.]+\.[^.]+/)}/bin/scons*")
    mkdir_p bin
    ln_s scons_bins, bin
  end # install

  def uninsinuate
    # this is needed for the installed Python package to actually go away upon removal
    system 'pip3', 'uninstall', '--yes', 'scons'
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      int main()
      {
        printf("Homebrew");
        return(0);
      }
    EOS
    (testpath/'SConstruct').write "Program('test.c')"
    system bin/'scons'
    assert_equal 'Homebrew', shell_output(testpath/'test')
  end # test
end # Scons
