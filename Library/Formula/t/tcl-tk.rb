# stable release 2024-12-11; checked 2025-08-08
class TclTk < Formula
  desc 'Tool Command Language'
  homepage 'https://www.tcl.tk/'
  url 'https://downloads.sourceforge.net/project/tcl/Tcl/8.6.16/tcl8.6.16-src.tar.gz'
  version '8.6.16'
  sha256 '91cb8fa61771c63c262efb553059b7c7ad6757afa5857af6265e4b0bdc2a14a5'

  keg_only :provided_by_osx,
    'Tk installs some X11 headers and Mac OS provides an (older) Tcl/Tk.'

  deprecated_option 'without-tcllib' => 'without-libs'

  option :universal
  option 'without-libs', 'Don’t build tcllib or tklib (utility modules)'
  option 'without-tk', 'Don’t build Tk (the window toolkit)'

  if MacOS.version < :snow_leopard
    depends_on 'pkg-config' => :build
    depends_on :x11
  end
  depends_on 'sqlite'
  depends_on 'zlib'

  resource 'tk' do
    url 'https://downloads.sourceforge.net/project/tcl/Tcl/8.6.16/tk8.6.16-src.tar.gz'
    version '8.6.16'
    sha256 'be9f94d3575d4b3099d84bc3c10de8994df2d7aa405208173c709cc404a7e5fe'
  end

  resource 'tcllib' do
    url 'https://downloads.sourceforge.net/project/tcllib/tcllib/2.0/tcllib-2.0.tar.xz'
    sha256 '642c2c679c9017ab6fded03324e4ce9b5f4292473b62520e82aacebb63c0ce20'
  end

  resource 'tklib' do
    url 'https://core.tcl-lang.org/tklib/raw/tklib-0.9.tar.xz?name=52e66024eff631ff'
    sha256 'b0258d1a5039d44ac0cde0b3a7ee0aa0d687acc9eb4d9c5f683f2cbffd26c6ca'
  end

  def install
    # TCL has restrictions on doing :universal builds under Tiger, but they don’t factor in because
    # Leopardbrew quietly makes :universal the same as not-:universal under Tiger.
    ENV.universal_binary if build.universal?

    args = [
        "--prefix=#{prefix}",
        "--mandir=#{man}",
        '--disable-dtrace',
        '--with-encoding=utf-8',
        '--disable-framework',
        '--enable-man-suffix',
        '--enable-man-symlinks',
        '--enable-threads',
      ]
    args << '--enable-64bit' if Target.prefer_64b?

    cd 'unix' do
      system './configure', *args
      system 'make'
      system 'make', 'install'
      system 'make', 'install-private-headers'
      ln_s bin/'tclsh8.6', bin/'tclsh'
    end

    if build.with? 'tk'
      ENV.prepend_path 'PATH', bin # so that tk finds our new tclsh

      resource('tk').stage do
        args = [
            "--prefix=#{prefix}",
            "--mandir=#{man}",
            '--enable-man-suffix',
            '--enable-man-symlinks',
            "--with-tcl=#{lib}",
            '--enable-threads',
          ]
        args << '--enable-64bit' if Target.prefer_64b?

        # Aqua support now requires features introduced in Snow Leopard
        if MacOS.version < :snow_leopard
          args << '--with-x'
        else
          args << '--enable-aqua=yes'
          args << '--without-x'
        end

        cd 'unix' do
          system './configure', *args
          system 'make', "TK_LIBRARY=#{lib}"
          # `make test` is for maintainers
          system 'make', 'install'
          system 'make', 'install-private-headers'
          ln_s bin/'wish8.6', bin/'wish'
        end
      end
    end # build with tk?

    if build.with? 'libs'
      resource('tcllib').stage do
        system './configure', "--prefix=#{prefix}", "--mandir=#{man}"
        system 'make'
        system 'make', 'install'
      end
      resource('tklib').stage do
        system './configure', "--prefix=#{prefix}"
        system 'make'
        system 'make', 'install'
      end
    end # build with libs?
  end # install

  test do
    for_archs(bin/'tclsh') do |_, cmd_array|
      assert_equal 'honk', pipe_output(cmd_array * ' ', "puts honk\n").chomp
    end
  end # test
end # TclTk
