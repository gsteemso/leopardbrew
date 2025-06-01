class Coreutils < Formula
  desc "GNU File, Shell, and Text utilities"
  homepage "https://www.gnu.org/software/coreutils"
  url "http://ftpmirror.gnu.org/coreutils/coreutils-9.5.tar.xz"
  mirror "https://ftp.gnu.org/gnu/coreutils/coreutils-9.5.tar.xz"
  sha256 'cd328edeac92f6a665de9f323c93b712af1858bc2e0d88f3f7100469470a1b8a'

  head do
    url "https://git.savannah.gnu.org/git/coreutils.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "bison" => :build
    depends_on "texinfo" => :build
    depends_on "xz" => :build
    depends_on "wget" => :build
  end

  option 'without-gmp',   'Build with default (inferior) math handling'
  option 'without-nls',   'Build without natural‐language support (internationalization)'
  option 'without-tests', 'Skip the build‐time unit tests'

  depends_on "gmp" => :recommended
  depends_on :nls  => :recommended

  conflicts_with "aardvark_shell_utils", :because => "both install `realpath` binaries"
  conflicts_with "idutils",              :because => "both install `gid` and `gid.1`"
  conflicts_with "ganglia",              :because => "both install `gstat` binaries"
  conflicts_with "gegl",                 :because => "both install `gcut` binaries"

  patch :DATA

  def install
    if MacOS.version == :el_capitan
      # Work around unremovable, nested dirs bug that affects lots of
      # GNU projects. See:
      # https://github.com/Homebrew/homebrew/issues/45273
      # https://github.com/Homebrew/homebrew/issues/44993
      # This is thought to be an el_capitan bug:
      # https://lists.gnu.org/archive/html/bug-tar/2015-10/msg00017.html
      ENV["gl_cv_func_getcwd_abort_bug"] = "no"

      # renameatx_np and RENAME_EXCL are available at compile time from Xcode 8
      # (10.12 SDK), but the former is not available at runtime.
      inreplace "lib/renameat2.c", "defined RENAME_EXCL", "defined UNDEFINED_GIBBERISH"
    end

    system "./bootstrap" if build.head?

    args = %W[
      --prefix=#{prefix}
      --program-prefix=g
      --disable-silent-rules
    ]
    args << '--disable-year2038' unless MacOS.prefer_64_bit?
    args << "--without-gmp" if build.without? "gmp"
    system "./configure", *args
    system "make"
    begin
      safe_system 'make', 'check'
    rescue ErrorDuringExecution
      opoo 'Some of the unit tests did not complete successfully.',
        'This is not unusual.  If you ran Leopardbrew in “verbose” mode, the fraction of',
        'tests which failed will be visible in the text above; only you can say whether',
        'the pass rate shown there counts as “good enough”.'
    end if build.with? 'tests'
    system "make", "install"

    # Symlink all commands into libexec/gnubin without the 'g' prefix
    coreutils_filenames(bin).each do |cmd|
      (libexec/"gnubin").install_symlink bin/"g#{cmd}" => cmd
    end
    # Symlink all man(1) pages into libexec/gnuman without the 'g' prefix
    coreutils_filenames(man1).each do |cmd|
      (libexec/"gnuman"/"man1").install_symlink man1/"g#{cmd}" => cmd
    end

    # Symlink non-conflicting binaries
    bin.install_symlink "grealpath" => "realpath"
    man1.install_symlink "grealpath.1" => "realpath.1"
  end

  def caveats; <<-EOS.undent
      All commands are installed with the prefix ‘g’.
      If you really need to use these commands with their normal names, you
      can add the “gnubin” directory to your PATH from your bashrc:
          PATH="#{opt_libexec}/gnubin:$PATH"
      You can likewise access their man pages with normal names if you also add
      the “gnuman” directory to your MANPATH from your bashrc:
          MANPATH="#{opt_libexec}/gnuman:$MANPATH"
    EOS
  end

  def coreutils_filenames(dir)
    filenames = []
    dir.find do |path|
      next if path.directory? || path.basename.to_s == ".DS_Store"
      filenames << path.basename.to_s.sub(/^g/, "")
    end
    filenames.sort
  end

  test do
    (testpath/"test").write("test")
    (testpath/"test.sha1").write("a94a8fe5ccb19ba61c4c0873d391e987982fbbd3 test")
    system bin/"gsha1sum", "-c", "test.sha1"
    system bin/"gln", "-f", "test", "test.sha1"
  end
end

__END__
--- old/tests/ls/dired.sh
+++ new/tests/ls/dired.sh
@@ -37,13 +37,13 @@
 
 # Check with varying positions (due to usernames etc.)
 # Also use multibyte characters to show --dired counts bytes not characters
-touch dir/1a dir/2á || framework_failure_
+touch dir/1a dir/2æ || framework_failure_
 mkdir -p dir/3dir || framework_failure_
 
 ls -l --dired dir > out || fail=1
 
 dired_values=$(grep "//DIRED//" out| cut -d' ' -f2-)
-expected_files="1a 2á 3dir"
+expected_files="1a 2æ 3dir"
 
 dired_count=$(printf '%s\n' $dired_values | wc -l)
 expected_count=$(printf '%s\n' $expected_files | wc -l)
--- old/src/iopoll.c
+++ new/src/iopoll.c
@@ -23,7 +23,7 @@
    a readable event).  Also use poll(2) on systems we know work
    and/or are already using poll (linux).  */
 
-#if defined _AIX || defined __sun || defined __APPLE__ || \
+#if defined _AIX || defined __sun || \
     defined __linux__ || defined __ANDROID__
 # define IOPOLL_USES_POLL 1
   /* Check we've not enabled gnulib's poll module
