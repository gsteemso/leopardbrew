# Stable release 2026-02-02; checked 2026-03-08.
class Git < Formula
  desc 'Distributed revision control system'
  homepage 'https://git-scm.com'
  url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.53.0.tar.xz'
  mirror 'https://www.kernel.org/pub/software/scm/git/git-2.53.0.tar.xz'
  sha256 '5818bd7d80b061bbbdfec8a433d609dc8818a05991f731ffc4a561e2ca18c653'
  head 'https://github.com/git/git.git', :shallow => false

  if MacOS.version < :snow_leopard
    # We use the 2.40.1 version of git-credential-osxkeychain, not anything more recent, for we don’t have getline(3).  The totally
    # rewritten 2.46.0 version is out of the question as it requires Snow Leopard or later.
    resource 'pre-SnowLeopard-credentials' do
      url 'https://raw.githubusercontent.com/git/git/refs/tags/v2.40.1/contrib/credential/osxkeychain/git-credential-osxkeychain.c'
      sha256 '54dcb2e750aa1a135af1c1c2d948e557b20d8218cf3c2c9e153569acd9c0dfdb'
    end
  end

  resource 'html' do
    url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-htmldocs-2.53.0.tar.xz'
    sha256 '994b93cbf25a9c13f1206dcc1751f0559633d5152155e16fc025ab776af08e0d'
  end

  resource 'man' do
    url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-2.53.0.tar.xz'
    sha256 '957ffe4409eeb90c7332bff4abee8d5169d28ef5c7c3bf08419f4239be13f77f'
  end

  option 'with-brewed-svn',       'Use brewed Subversion'
  option 'with-pcre2',            'Build with support for Perl‐compatible regular expressions'
  option 'with-persistent-https', 'Build contributed git-remote-persistent-https feature (requires Go)' unless CPU.powerpc?
  option :tests,                  'Perform build-time unit tests (might not succeed)'
  option 'without-tcl-tk',        'Disable graphical user interface'

  depends_on 'gnu-tar' => :build if MacOS.version < :leopard  # stock tar has odd permissions errors
  depends_on 'go'      => :build if build.with? 'persistent-https'
  depends_on 'make'    => :build
  depends_on 'tcl-tk'  => :recommended  # “wish” is used for the GUI.
  depends_on 'pcre2'   => :optional
  # depends on libcurl 7.61.0 or later
  depends_on 'curl'
  depends_on 'gettext'
  depends_on 'libiconv'
  depends_on 'openssh'  # Without this, you can’t log into Github on older Macs because the encryption schemes are so outdated.
  depends_on 'openssl3'
  # depends on Perl >= v5.26.0; Tiger includes v5.8.6, Leopard v5.8.8
  depends_on 'perl'
  if build.with? 'brewed-svn'
    depends_on 'swig'                       # Trigger installation of {swig} before {subversion}; otherwise {swig} won’t get pulled
    depends_on 'subversion' => 'with-perl'  # in at all (see https://github.com/Homebrew/homebrew/issues/34554)
  end

  enhanced_by 'expat'   # Used for locking over DAV.
  enhanced_by 'python2'
  enhanced_by 'python3'
  enhanced_by 'zlib'    # The stock version works, but newer is better.

  patch <<_ if MacOS.version < :leopard  # Very old Mac OSes don’t understand “rpath”.
--- old/Makefile
+++ new/Makefile
@@ -965,6 +965,6 @@
 # Older versions of GCC may require adding "-std=gnu99" at the end.
 CFLAGS = -g -O2 -Wall
 LDFLAGS =
-CC_LD_DYNPATH = -Wl,-rpath,
+CC_LD_DYNPATH = -L
 BASIC_CFLAGS = -I.
 BASIC_LDFLAGS =
_

  patch :DATA if MacOS.version <= :mavericks  # The patches are annotated inline.

  def install
    if MacOS.version < :snow_leopard
      if MacOS.version < :leopard
        f = Formula['gnu-tar']
        tab = Tab.for_keg f.prefix
        tar_name = tab.used_options.include?('--default-names') ? f.bin/'tar' : f.bin/'gtar'
        inreplace 'Makefile' do |s| s.change_make_var! 'TAR', tar_name.to_s; end
      end # Older than Leopard?
      rm 'contrib/credential/osxkeychain/git-credential-osxkeychain.c'
      (buildpath/'contrib/credential/osxkeychain').install resource('pre-SnowLeopard-credentials')
    end # Older than Snow Leopard?
    ENV['V'] = '1'                       # Build verbosely.
    ENV['NO_FINK'] = '1'                 # ← If these are installed, tell the Git build system to not use them.
    ENV['NO_DARWIN_PORTS'] = '1'         # ←
    (ENV['PYTHON_PATH'] =                # Path to the binary, if any.
        ((f = Formula['python3']).any_version_installed? ? f.opt_bin/'python3' :
          (which('python3').choke or
            ((f = Formula['python2']).installed? ? f.opt_bin/'python2.7' :
              which('python2.7').choke
      ) ) ) ) or ENV['NO_PYTHON'] = '1'  # System Python < 2.7, e.g. on Tiger or Leopard, won’t work.
    if build.with? 'tcl-tk'
      ENV['TCL_PATH'] = (fp = Formula['tcl-tk'].opt_bin)/'tclsh'
      ENV['TCLTK_PATH'] = fp/'wish'
    else
      ENV['NO_TCLTK'] = '1'
    end
    ENV['DEFAULT_EDITOR'] = which_editor  # See “utils.rb”.
    ENV['DEFAULT_HELP_FORMAT'] = 'man'
    ENV['CHARSET_LIB'] = '-lcharset'
    ENV['EXPATDIR'] = (f = Formula['expat']).installed? ? f.opt_prefix \
                                                        : (MacOS.version > :tiger ? '/usr' : nil) \
                                                        or ENV['NO_EXPAT'] = '1'
    ENV['CURLDIR'] = (f = Formula['curl']).opt_prefix
    ENV['CURL_CONFIG'] = f.opt_bin/'curl-config'
    if build.with? 'pcre2'
      ENV['USE_LIBPCRE2'] = '1'
      ENV['LIBPCREDIR'] = Formula['pcre2'].opt_prefix
    end
    ENV['NO_APPLE_COMMON_CRYPTO'] = '1'
    ENV['NEEDS_CRYPTO_WITH_SSL'] = '1'
    ENV['NEEDS_SSL_WITH_CRYPTO'] = '1'
    ENV['BLK_SHA1_UNSAFE'] = '1'  # By our choosing no “safe” SHA1 backend, git must default to its internal sha1collisiondetection
                                  # library implementation.
    ENV['OPENSSL_SHA256'] = '1'
    ENV['NEEDS_LIBICONV'] = '1'          # Otherwise we get the inadequate stock version instead of ours.
    ENV['USE_HOMEBREW_LIBICONV'] = '1'   #
    ENV['CFLAGS_APPEND'] = '-std=gnu99'
    perl_pathname = Formula['perl'].opt_bin/'perl'
    perl_version = /\d\.\d+/.match(`#{perl_pathname} --version`)
    ENV['PERL_PATH'] = perl_pathname     # Path to the binary.
    ENV['NO_PERL_CPAN_FALLBACKS'] = '1'  # Avoid potential issues (recommended for Git distributors, which is not us, but close?)
    if build.with? 'brewed-svn'
      f = Formula['subversion']
      ENV['PERLLIB_EXTRA'] = %W[
        #{f.opt_lib}/perl5/site_perl
        #{f.opt_prefix}/Library/Perl/#{perl_version}/darwin-thread-multi-2level
      ].join(':')
    elsif MacOS.version >= :mavericks
      ENV['PERLLIB_EXTRA'] = %W[
        #{MacOS.active_developer_dir}
        /Library/Developer/CommandLineTools
        /Applications/Xcode.app/Contents/Developer
      ].uniq.map do |p|
        "#{p}/Library/Perl/#{perl_version}/darwin-thread-multi-2level"
      end.join(':')
    else
      ENV['NO_SVN_TESTS'] = '1'  # Save a LOT of time if we’re not using Subversion at all.
    end

    args = %W[
        prefix=#{prefix}
        sysconfdir=#{etc}
      ]  # sysconfdir is not set properly when using the bare Makefile, so we have to do it explicitly.
    make *args
    make 'test', *args if build.with? 'tests'
    make 'install', *args

    # Install the OS X keychain credential helper
    cd 'contrib/credential/osxkeychain' do
      make
      bin.install 'git-credential-osxkeychain'
    end

    # Install git-subtree
    cd 'contrib/subtree' do
      make
      bin.install 'git-subtree'
    end

    cd 'contrib/persistent-https' do
      make
      bin.install 'git-remote-persistent-http',
                  'git-remote-persistent-https',
                  'git-remote-persistent-https--proxy'
    end if build.with? 'persistent-https'

    bash_completion.install 'contrib/completion/git-completion.bash'
    bash_completion.install 'contrib/completion/git-prompt.sh'
    zsh_completion.install 'contrib/completion/git-completion.zsh' => '_git'
    ln_s Dir["#{bash_completion}/git-{completion.ba,prompt.}sh"], zsh_completion

    (share/'git-core').install 'contrib'

    # We could build the manpages ourselves, but the build process depends
    # on many other packages, and is somewhat crazy, this way is easier.
    man.install resource('man')
    (share/'doc/git-doc').install resource('html')

    # Make html docs world-readable
    chmod 0644, Dir["#{share}/doc/git-doc/**/*.{html,txt}"]
    chmod 0755, Dir["#{share}/doc/git-doc/{RelNotes,howto,technical}"]

    # Set the macOS keychain credential helper by default (as Apple’s CLT’s git also does this).
    (buildpath/'gitconfig').write <<-EOS.undent
      [credential]
      \thelper = osxkeychain
    EOS
    etc.install 'gitconfig'
  end # install

  def caveats; <<-EOS.undent
    The Mac OS keychain credential helper is installed to:
        #{HOMEBREW_PREFIX}/bin/git-credential-osxkeychain

    The “contrib” directory is installed to:
        #{HOMEBREW_PREFIX}/share/git-core/contrib
    EOS
  end # caveats

  test do
    system "#{bin}/git", 'init'
    %w[haunted house].each { |f| touch testpath/f }
    system "#{bin}/git", 'add', 'haunted', 'house'
    system "#{bin}/git", 'commit', '-a', '-m', 'Initial_Commit'
    assert_equal "haunted\nhouse", shell_output("#{bin}/git ls-files").strip
  end # test
end # Git

__END__
# Fix PowerPC build, and support for Mac OS up through roughly Mavericks:
# - Stock regex(3) is too old and lacks some file system monitoring functionality.
# - Needs arc4random_buf(3) which is missing on Leopard and prior, so just use OpenSSL since
#   newer implementations were based on AES cipher.
--- old/config.mak.uname
+++ new/config.mak.uname
@@ -147,8 +147,12 @@
 	HAVE_BSD_SYSCTL = YesPlease
 	FREAD_READS_DIRECTORIES = UnfortunatelyYes
 	HAVE_NS_GET_EXECUTABLE_PATH = YesPlease
-	CSPRNG_METHOD = arc4random
-	USE_ENHANCED_BASIC_REGULAR_EXPRESSIONS = YesPlease
+	CSPRNG_METHOD = openssl
+	ifeq ($(shell test "`expr "$(uname_R)" : '\([0-9][0-9]*\)\.'`" -lt 12 && echo 1),1)
+		NO_REGEX=YesPlease
+	else
+		USE_ENHANCED_BASIC_REGULAR_EXPRESSIONS = YesPlease
+	endif
 
         ifeq ($(uname_M),arm64)
 		HOMEBREW_PREFIX = /opt/homebrew
@@ -160,6 +164,7 @@
 		NEEDS_GOOD_LIBICONV = UnfortunatelyYes
         endif
 
+	ifeq ($(shell test "`expr "$(uname_R)" : '\([0-9][0-9]*\)\.'`" -gt 13 && echo 1), 1)
 	# The builtin FSMonitor on MacOS builds upon Simple-IPC.  Both require
 	# Unix domain sockets and PThreads.
         ifndef NO_PTHREADS
@@ -168,6 +173,7 @@
 	FSMONITOR_OS_SETTINGS = darwin
         endif
         endif
+	endif
 
 	BASIC_LDFLAGS += -framework CoreServices
 endif
# Older GCCs, which are the default on Apple PowerPC, do not define __BYTE_ORDER__.
--- old/sha1dc/sha1.c
+++ new/sha1dc/sha1.c
@@ -102,6 +102,9 @@
  */
 #define SHA1DC_BIGENDIAN
 
+#elif (defined(__APPLE__) && defined(__BIG_ENDIAN__) && !defined(SHA1DC_BIGENDIAN))
+# define SHA1DC_BIGENDIAN
+
 /* Not under GCC-alike or glibc or *BSD or newlib or <processor whitelist> or <os whitelist> */
 #elif defined(SHA1DC_ON_INTEL_LIKE_PROCESSOR)
 /*
# We can’t include <copyfile.h> prior to Leopard, because it didn’t exist.
--- old/t/unit-tests/clar/clar/fs.h
+++ new/t/unit-tests/clar/clar/fs.h
@@ -311,7 +311,7 @@
 # include <sys/sendfile.h>
 #endif
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 # include <copyfile.h>
 #endif
 
