class Make < Formula
  desc 'Utility for directing compilation'
  homepage 'https://www.gnu.org/software/make/'
  url 'http://ftpmirror.gnu.org/make/make-4.4.1.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/make/make-4.4.1.tar.lz'
  sha256 '8814ba072182b605d156d7589c19a43b89fc58ea479b9355146160946f8cf6e9'

  option :universal
  option 'with-default-names', 'Do not prepend ‘g’ to the binary'
  option 'with-tests',         'Run the unit tests while building (requires Perl)'
  option 'without-nls',        'Build without natural‐language support (internationalization)'

  depends_on 'gettext' if build.with? 'nls'
  depends_on 'perl' if build.with? 'tests'

  enhanced_by ['guile', 'pkg-config']

  # For some reason the test suite deletes all but a few environment variables
  # to run the first four tests, which nukes Superenv’s internal state.  This
  # patch adds the $HOMEBREW_* variables to the list of those that get kept.
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << '--program-prefix=g' if build.without? 'default-names'
    args << '--disable-nls' if build.without? 'nls'
    args << '--with-guile' if enhanced_by? 'guile'
    system './configure', *args
    system 'make'
    bombproof_system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end # install

  test do
    (testpath/'Makefile').write <<-EOS.undent
      default:
      \t@echo Homebrew
    EOS

    cmd = build.with?('default-names') ? 'make' : 'gmake'

    for_archs bin/cmd do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s, ''])
      assert_equal "Homebrew\n", shell_output("#{arch_cmd * ' '}#{bin}/#{cmd}")
    end
  end # test
end # Make

__END__
--- old/tests/test_driver.pl	2023-02-20 08:10:56 -0800
+++ new/tests/test_driver.pl	2024-11-22 22:45:43 -0800
@@ -196,6 +196,9 @@
 
   # Pull in benign variables from the user's environment
 
+  # Identify Homebrew-specific envvars
+  foreach (keys(%ENV)) { push @Homebrew_keys, $_ if $_ =~ /^HOMEBREW_/; }
+
   foreach (# POSIX-specific things
            'TZ', 'TMPDIR', 'HOME', 'USER', 'LOGNAME', 'PATH',
            'LD_LIBRARY_PATH',
@@ -210,7 +213,8 @@
            '_TAG_REDIR_IN',  '_TAG_REDIR_OUT',
            # DJGPP-specific things
            'DJDIR', 'DJGPP', 'SHELL', 'COMSPEC', 'HOSTNAME', 'LFN',
-           'FNCASE', '387', 'EMU387', 'GROUP'
+           'FNCASE', '387', 'EMU387', 'GROUP',
+           @Homebrew_keys
           ) {
     $makeENV{$_} = $ENV{$_} if $ENV{$_};
   }
