class Libtool < Formula
  desc 'Generic library support script'
  homepage 'https://www.gnu.org/software/libtool/'
  url 'http://ftpmirror.gnu.org/libtool/libtool-2.5.4.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.xz'
  sha256 'f81f5860666b0bc7d84baddefa60d1cb9fa6fceb2398cc3baca6afaa60266675'

  keg_only :provided_until_xcode43

  option :universal
  option 'with-tests', 'Run the build‐time unit tests (very slow, & requires gettext)'

  depends_on 'autoconf' => :run
  depends_on 'automake' => :run
  depends_on 'gettext' if build.with? 'tests'

  # For some reason, the Libtool maintainers think that Darwin’s loadable‐
  # module extension is “.so” rather than “.bundle”.
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--program-prefix=g',
                          '--disable-dependency-tracking',
                          '--enable-ltdl-install'
    system 'make'
    safe_system('make', 'check') if build.with? 'tests'
    system 'make', 'install'
  end

  def caveats; <<-EOS.undent
      In order to prevent conflicts with Apple’s stock libtool, we prepend a “g” to
      get “glibtool” and “glibtoolize”.
    EOS
  end

  test do
    # glibtool is a script – there are no architectures to separate out.
    # TODO:  Devise a better test, that exercises LibLTDL.
    system bin/'glibtool', 'execute', '/usr/bin/true'
  end
end

__END__
--- old/configure
+++ new/configure
@@ -13657,7 +13657,7 @@
   soname_spec='$libname$release$major$shared_ext'
   shlibpath_overrides_runpath=yes
   shlibpath_var=DYLD_LIBRARY_PATH
-  shrext_cmds='`test .$module = .yes && echo .so || echo .dylib`'
+  shrext_cmds='`test .$module = .yes && echo .bundle || echo .dylib`'
 
   sys_lib_search_path_spec="$sys_lib_search_path_spec /usr/local/lib"
   sys_lib_dlsearch_path_spec='/usr/local/lib /lib /usr/lib'
