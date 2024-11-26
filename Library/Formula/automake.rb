class Automake < Formula
  desc 'Tool for generating GNU Standards-compliant Makefiles'
  homepage 'https://www.gnu.org/software/automake/'
  url 'http://ftpmirror.gnu.org/automake/automake-1.17.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/automake/automake-1.17.tar.xz'
  sha256 '8920c1fc411e13b90bf704ef9db6f29d540e76d232cb3b2c9f4dc4cc599bd990'

  option 'with-tests', 'Run the build‐time unit tests'

  depends_on 'autoconf' => [:build, :run]

  if build.with? 'tests'
    depends_on :python
    enhanced_by 'libtool'
  end

  keg_only :provided_until_xcode43

  # Superenv argument refurbishment messes up the compiler‐flag jiggery‐pokery
  # used by one of the `make check` tests.  This makes that test skip itself
  # when argument refurbishment is active.
  patch :DATA

  def install
    ENV['PERL'] = '/usr/bin/perl'

    system './configure', "--prefix=#{prefix}"
    system 'make'
    bombproof_system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'

    # Our aclocal must go first. See:
    # https://github.com/Homebrew/homebrew/issues/10618
    (share/'aclocal/dirlist').write <<-EOS.undent
      #{HOMEBREW_PREFIX}/share/aclocal
      /usr/share/aclocal
    EOS
  end

  test do
    system bin/'automake', '--version'
  end
end

__END__
--- old/t/amhello-cflags.sh
+++ new/t/amhello-cflags.sh
@@ -22,6 +22,11 @@
 required=gcc
 . test-init.sh
 
+case "$HOMEBREW_CCCFG" in
+  *O*) skip_ 'Homebrew argument refurbishment precludes meaningful results' ;;
+  *) ;;
+esac
+
 cp "$am_docdir"/amhello-1.0.tar.gz . \
   || fatal_ "cannot get amhello tarball"
 
