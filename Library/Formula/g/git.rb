# Stable release 2025-08-18; checked 2025-10-11.
class Git < Formula
  desc 'Distributed revision control system'
  homepage 'https://git-scm.com'
  url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.51.0.tar.xz'
  mirror 'https://www.kernel.org/pub/software/scm/git/git-2.51.0.tar.xz'
  sha256 '60a7c2251cc2e588d5cd87bae567260617c6de0c22dca9cdbfc4c7d2b8990b62'
  head 'https://github.com/git/git.git', :shallow => false

  resource 'html' do
    url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-htmldocs-2.51.0.tar.xz'
    sha256 'dd33897c676ea140d57a652758e458756fa93582801cfd1d7e1f62acd5fa7580'
  end

  resource 'man' do
    url 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-2.51.0.tar.xz'
    sha256 'c10aea63316865ace762078a6e67fc3cf117b11a5c9d4a2a52cb3762ae22ed35'
  end

  option 'with-brewed-svn',       'Use brewed Subversion'
  option 'with-pcre2',            'Build with support for Perl‐compatible regular expressions'
  option 'with-persistent-https', 'Build contributed git-remote-persistent-https feature (requires Go)' unless CPU.powerpc?
  option 'with-tests',            'Perform build-time unit tests (might not succeed)'
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
    depends_on 'swig'                       # Trigger installation of {swig} before {subversion}; otherwise {swig} is not pulled in
    depends_on 'subversion' => 'with-perl'  # at all (see https://github.com/Homebrew/homebrew/issues/34554)
  end

  enhanced_by 'expat'   # Used for locking over DAV.
  enhanced_by 'python2'
  enhanced_by 'python3'
  enhanced_by 'zlib'    # The stock version works, but newer is better.

  patch :DATA if MacOS.version <= :mavericks  # The patches are annotated inline.

  def install
    if MacOS.version < :leopard
      f = Formula['gnu-tar']
      tab = Tab.for_keg f.prefix
      tar_name = tab.used_options.include?('--default-names') ? f.bin/'tar' : f.bin/'gtar'
      inreplace 'Makefile' do |s|
        s.change_make_var! 'TAR', tar_name.to_s
      end
    end # Older than Leopard?
    ENV['V'] = '1'                      # build verbosely
    ENV['NO_FINK'] = '1'                # If these are installed, tell the
    ENV['NO_DARWIN_PORTS'] = '1'        #   Git build system to not use them
    perl_pathname = Formula['perl'].opt_bin/'perl'
    ENV['PERL_PATH'] = perl_pathname    # path to the binary
    (ENV['PYTHON_PATH'] =               # path to the binary, if any
        ((f = Formula['python3']).any_version_installed? ? f.opt_bin/'python3' :
          (which('python3').choke or
            ((f = Formula['python']).installed? ? f.opt_bin/'python2.7' :
              which('python2.7').choke
      ) ) ) ) or ENV['NO_PYTHON'] = '1' # system Python < 2.7, e.g. on Tiger/Leopard, won’t work
    if build.with? 'tcl-tk'
      ENV['TCL_PATH'] = (fp = Formula['tcl-tk'].opt_bin)/'tclsh'
      ENV['TCLTK_PATH'] = fp/'wish'
    else
      ENV['NO_TCLTK'] = '1'
    end
    ENV['DEFAULT_EDITOR'] = ENV['EDITOR'].choke || 'vi'  # default to the original default value
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
    ENV['BLK_SHA1_UNSAFE'] = '1'  # By choosing no “safe” SHA1 backend, we make git default to its
                                  # internal sha1collisiondetection library implementation.
    ENV['OPENSSL_SHA256'] = '1'
    ENV['NEEDS_LIBICONV'] = '1'  # Otherwise we get the inadequate stock version instead of ours.
    ENV['CFLAGS_APPEND'] = '-std=gnu99'
    perl_version = /\d\.\d+/.match(`#{perl_pathname} --version`)
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

    dir_args = %W[
        prefix=#{prefix}
        sysconfdir=#{etc}
      ]  # “sysconfdir” is weirdly absent from the Makefile, even though it’s very obviously assumed to be present.

    make *dir_args
    make 'test', *dir_args if build.with? 'tests'
    make 'install', *dir_args

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
    The OS X keychain credential helper is installed to:
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
@@ -131,6 +131,11 @@
         ifeq ($(shell expr "$(uname_R)" : '[15]\.'),2)
 		NO_STRLCPY = YesPlease
         endif
+	ifeq ($(shell test "`expr "$(uname_R)" : '\([0-9][0-9]*\)\.'`" -lt 12 && echo 1),1)
+		NO_REGEX=YesPlease
+	else
+		USE_ENHANCED_BASIC_REGULAR_EXPRESSIONS = YesPlease
+	endif
         ifeq ($(shell test "`expr "$(uname_R)" : '\([0-9][0-9]*\)\.'`" -ge 11 && echo 1),1)
 		HAVE_GETDELIM = YesPlease
         endif
@@ -146,8 +151,7 @@
 	HAVE_BSD_SYSCTL = YesPlease
 	FREAD_READS_DIRECTORIES = UnfortunatelyYes
 	HAVE_NS_GET_EXECUTABLE_PATH = YesPlease
-	CSPRNG_METHOD = arc4random
-	USE_ENHANCED_BASIC_REGULAR_EXPRESSIONS = YesPlease
+	CSPRNG_METHOD = openssl
 
 	# Workaround for `gettext` being keg-only and not even being linked via
 	# `brew link --force gettext`, should be obsolete as of
@@ -173,6 +177,7 @@
                 endif
         endif
 
+	ifeq ($(shell test "`expr "$(uname_R)" : '\([0-9][0-9]*\)\.'`" -gt 13 && echo 1), 1)
 	# The builtin FSMonitor on MacOS builds upon Simple-IPC.  Both require
 	# Unix domain sockets and PThreads.
         ifndef NO_PTHREADS
@@ -181,6 +186,7 @@
 	FSMONITOR_OS_SETTINGS = darwin
         endif
         endif
+	endif
 
 	BASIC_LDFLAGS += -framework CoreServices
 endif
# Very old Mac OSes don’t understand “rpath”.
--- old/Makefile
+++ new/Makefile
@@ -1401,7 +1401,7 @@
 # Older versions of GCC may require adding "-std=gnu99" at the end.
 CFLAGS = -g -O2 -Wall
 LDFLAGS =
-CC_LD_DYNPATH = -Wl,-rpath,
+CC_LD_DYNPATH = -L
 BASIC_CFLAGS = -I.
 BASIC_LDFLAGS =
 
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
# We use the 2.40.1 version of git-credential-osxkeychain, not the 2.43.0 version, because we don’t
# have getline(3).  The totally rewritten 2.46.0 version is out of the question as it requires Snow
# Leopard or later.
--- old/contrib/credential/osxkeychain/git-credential-osxkeychain.c
+++ new/contrib/credential/osxkeychain/git-credential-osxkeychain.c
@@ -3,52 +3,14 @@
 #include <stdlib.h>
 #include <Security/Security.h>
 
-#define ENCODING kCFStringEncodingUTF8
-static CFStringRef protocol; /* Stores constant strings - not memory managed */
-static CFStringRef host;
-static CFNumberRef port;
-static CFStringRef path;
-static CFStringRef username;
-static CFDataRef password;
-static CFDataRef password_expiry_utc;
-static CFDataRef oauth_refresh_token;
-static int state_seen;
+static SecProtocolType protocol;
+static char *host;
+static char *path;
+static char *username;
+static char *password;
+static UInt16 port;
 
-static void clear_credential(void)
-{
-	if (host) {
-		CFRelease(host);
-		host = NULL;
-	}
-	if (port) {
-		CFRelease(port);
-		port = NULL;
-	}
-	if (path) {
-		CFRelease(path);
-		path = NULL;
-	}
-	if (username) {
-		CFRelease(username);
-		username = NULL;
-	}
-	if (password) {
-		CFRelease(password);
-		password = NULL;
-	}
-	if (password_expiry_utc) {
-		CFRelease(password_expiry_utc);
-		password_expiry_utc = NULL;
-	}
-	if (oauth_refresh_token) {
-		CFRelease(oauth_refresh_token);
-		oauth_refresh_token = NULL;
-	}
-}
-
-#define STRING_WITH_LENGTH(s) s, sizeof(s) - 1
-
-__attribute__((format (printf, 1, 2), __noreturn__))
+__attribute__((format (printf, 1, 2)))
 static void die(const char *err, ...)
 {
 	char msg[4096];
@@ -57,289 +19,108 @@
 	vsnprintf(msg, sizeof(msg), err, params);
 	fprintf(stderr, "%s\n", msg);
 	va_end(params);
-	clear_credential();
 	exit(1);
 }
 
-static void *xmalloc(size_t len)
+static void *xstrdup(const char *s1)
 {
-	void *ret = malloc(len);
+	void *ret = strdup(s1);
 	if (!ret)
 		die("Out of memory");
 	return ret;
 }
 
-static CFDictionaryRef create_dictionary(CFAllocatorRef allocator, ...)
-{
-	va_list args;
-	const void *key;
-	CFMutableDictionaryRef result;
-
-	result = CFDictionaryCreateMutable(allocator,
-					   0,
-					   &kCFTypeDictionaryKeyCallBacks,
-					   &kCFTypeDictionaryValueCallBacks);
-
-
-	va_start(args, allocator);
-	while ((key = va_arg(args, const void *)) != NULL) {
-		const void *value;
-		value = va_arg(args, const void *);
-		if (value)
-			CFDictionarySetValue(result, key, value);
-	}
-	va_end(args);
-
-	return result;
-}
-
-#define CREATE_SEC_ATTRIBUTES(...) \
-	create_dictionary(kCFAllocatorDefault, \
-			  kSecClass, kSecClassInternetPassword, \
-			  kSecAttrServer, host, \
-			  kSecAttrAccount, username, \
-			  kSecAttrPath, path, \
-			  kSecAttrPort, port, \
-			  kSecAttrProtocol, protocol, \
-			  kSecAttrAuthenticationType, \
-			  kSecAttrAuthenticationTypeDefault, \
-			  __VA_ARGS__);
+#define KEYCHAIN_ITEM(x) (x ? strlen(x) : 0), x
+#define KEYCHAIN_ARGS \
+	NULL, /* default keychain */ \
+	KEYCHAIN_ITEM(host), \
+	0, NULL, /* account domain */ \
+	KEYCHAIN_ITEM(username), \
+	KEYCHAIN_ITEM(path), \
+	port, \
+	protocol, \
+	kSecAuthenticationTypeDefault
 
-static void write_item(const char *what, const char *buf, size_t len)
+static void write_item(const char *what, const char *buf, int len)
 {
 	printf("%s=", what);
 	fwrite(buf, 1, len, stdout);
 	putchar('\n');
 }
 
-static void find_username_in_item(CFDictionaryRef item)
+static void find_username_in_item(SecKeychainItemRef item)
 {
-	CFStringRef account_ref;
-	char *username_buf;
-	CFIndex buffer_len;
-
-	account_ref = CFDictionaryGetValue(item, kSecAttrAccount);
-	if (!account_ref)
-	{
-		write_item("username", "", 0);
-		return;
-	}
+	SecKeychainAttributeList list;
+	SecKeychainAttribute attr;
 
-	username_buf = (char *)CFStringGetCStringPtr(account_ref, ENCODING);
-	if (username_buf)
-	{
-		write_item("username", username_buf, strlen(username_buf));
+	list.count = 1;
+	list.attr = &attr;
+	attr.tag = kSecAccountItemAttr;
+
+	if (SecKeychainItemCopyContent(item, NULL, &list, NULL, NULL))
 		return;
-	}
 
-	/* If we can't get a CString pointer then
-	 * we need to allocate our own buffer */
-	buffer_len = CFStringGetMaximumSizeForEncoding(
-			CFStringGetLength(account_ref), ENCODING) + 1;
-	username_buf = xmalloc(buffer_len);
-	if (CFStringGetCString(account_ref,
-				username_buf,
-				buffer_len,
-				ENCODING)) {
-		write_item("username", username_buf, strlen(username_buf));
-	}
-	free(username_buf);
+	write_item("username", attr.data, attr.length);
+	SecKeychainItemFreeContent(&list, NULL);
 }
 
-static OSStatus find_internet_password(void)
+static void find_internet_password(void)
 {
-	CFDictionaryRef attrs;
-	CFDictionaryRef item;
-	CFDataRef data;
-	OSStatus result;
-
-	attrs = CREATE_SEC_ATTRIBUTES(kSecMatchLimit, kSecMatchLimitOne,
-				      kSecReturnAttributes, kCFBooleanTrue,
-				      kSecReturnData, kCFBooleanTrue,
-				      NULL);
-	result = SecItemCopyMatching(attrs, (CFTypeRef *)&item);
-	if (result) {
-		goto out;
-	}
+	void *buf;
+	UInt32 len;
+	SecKeychainItemRef item;
 
-	data = CFDictionaryGetValue(item, kSecValueData);
+	if (SecKeychainFindInternetPassword(KEYCHAIN_ARGS, &len, &buf, &item))
+		return;
 
-	write_item("password",
-		   (const char *)CFDataGetBytePtr(data),
-		   CFDataGetLength(data));
+	write_item("password", buf, len);
 	if (!username)
 		find_username_in_item(item);
 
-	CFRelease(item);
-
-	write_item("capability[]", "state", strlen("state"));
-	write_item("state[]", "osxkeychain:seen=1", strlen("osxkeychain:seen=1"));
-
-out:
-	CFRelease(attrs);
-
-	/* We consider not found to not be an error */
-	if (result == errSecItemNotFound)
-		result = errSecSuccess;
-
-	return result;
-}
-
-static OSStatus delete_ref(const void *itemRef)
-{
-	CFArrayRef item_ref_list;
-	CFDictionaryRef delete_query;
-	OSStatus result;
-
-	item_ref_list = CFArrayCreate(kCFAllocatorDefault,
-				      &itemRef,
-				      1,
-				      &kCFTypeArrayCallBacks);
-	delete_query = create_dictionary(kCFAllocatorDefault,
-					 kSecClass, kSecClassInternetPassword,
-					 kSecMatchItemList, item_ref_list,
-					 NULL);
-
-	if (password) {
-		/* We only want to delete items with a matching password */
-		CFIndex capacity;
-		CFMutableDictionaryRef query;
-		CFDataRef data;
-
-		capacity = CFDictionaryGetCount(delete_query) + 1;
-		query = CFDictionaryCreateMutableCopy(kCFAllocatorDefault,
-						      capacity,
-						      delete_query);
-		CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
-		result = SecItemCopyMatching(query, (CFTypeRef *)&data);
-		if (!result) {
-			CFDataRef kc_password;
-			const UInt8 *raw_data;
-			const UInt8 *line;
-
-			/* Don't match appended metadata */
-			raw_data = CFDataGetBytePtr(data);
-			line = memchr(raw_data, '\n', CFDataGetLength(data));
-			if (line)
-				kc_password = CFDataCreateWithBytesNoCopy(
-						kCFAllocatorDefault,
-						raw_data,
-						line - raw_data,
-						kCFAllocatorNull);
-			else
-				kc_password = data;
-
-			if (CFEqual(kc_password, password))
-				result = SecItemDelete(delete_query);
-
-			if (line)
-				CFRelease(kc_password);
-			CFRelease(data);
-		}
-
-		CFRelease(query);
-	} else {
-		result = SecItemDelete(delete_query);
-	}
-
-	CFRelease(delete_query);
-	CFRelease(item_ref_list);
-
-	return result;
+	SecKeychainItemFreeContent(NULL, buf);
 }
 
-static OSStatus delete_internet_password(void)
+static void delete_internet_password(void)
 {
-	CFDictionaryRef attrs;
-	CFArrayRef refs;
-	OSStatus result;
+	SecKeychainItemRef item;
 
 	/*
 	 * Require at least a protocol and host for removal, which is what git
 	 * will give us; if you want to do something more fancy, use the
 	 * Keychain manager.
 	 */
 	if (!protocol || !host)
-		return -1;
-
-	attrs = CREATE_SEC_ATTRIBUTES(kSecMatchLimit, kSecMatchLimitAll,
-				      kSecReturnRef, kCFBooleanTrue,
-				      NULL);
-	result = SecItemCopyMatching(attrs, (CFTypeRef *)&refs);
-	CFRelease(attrs);
-
-	if (!result) {
-		for (CFIndex i = 0; !result && i < CFArrayGetCount(refs); i++)
-			result = delete_ref(CFArrayGetValueAtIndex(refs, i));
-
-		CFRelease(refs);
-	}
+		return;
 
-	/* We consider not found to not be an error */
-	if (result == errSecItemNotFound)
-		result = errSecSuccess;
+	if (SecKeychainFindInternetPassword(KEYCHAIN_ARGS, 0, NULL, &item))
+		return;
 
-	return result;
+	SecKeychainItemDelete(item);
 }
 
-static OSStatus add_internet_password(void)
+static void add_internet_password(void)
 {
-	CFMutableDataRef data;
-	CFDictionaryRef attrs;
-	OSStatus result;
-
-	if (state_seen)
-		return errSecSuccess;
-
 	/* Only store complete credentials */
 	if (!protocol || !host || !username || !password)
-		return -1;
-
-	data = CFDataCreateMutableCopy(kCFAllocatorDefault, 0, password);
-	if (password_expiry_utc) {
-		CFDataAppendBytes(data,
-		    (const UInt8 *)STRING_WITH_LENGTH("\npassword_expiry_utc="));
-		CFDataAppendBytes(data,
-				  CFDataGetBytePtr(password_expiry_utc),
-				  CFDataGetLength(password_expiry_utc));
-	}
-	if (oauth_refresh_token) {
-		CFDataAppendBytes(data,
-		    (const UInt8 *)STRING_WITH_LENGTH("\noauth_refresh_token="));
-		CFDataAppendBytes(data,
-				  CFDataGetBytePtr(oauth_refresh_token),
-				  CFDataGetLength(oauth_refresh_token));
-	}
-
-	attrs = CREATE_SEC_ATTRIBUTES(kSecValueData, data,
-				      NULL);
-
-	result = SecItemAdd(attrs, NULL);
-	if (result == errSecDuplicateItem) {
-		CFDictionaryRef query;
-		query = CREATE_SEC_ATTRIBUTES(NULL);
-		result = SecItemUpdate(query, attrs);
-		CFRelease(query);
-	}
-
-	CFRelease(data);
-	CFRelease(attrs);
+		return;
 
-	return result;
+	if (SecKeychainAddInternetPassword(
+	      KEYCHAIN_ARGS,
+	      KEYCHAIN_ITEM(password),
+	      NULL))
+		return;
 }
 
 static void read_credential(void)
 {
-	char *buf = NULL;
-	size_t alloc;
-	ssize_t line_len;
+	char buf[1024];
 
-	while ((line_len = getline(&buf, &alloc, stdin)) > 0) {
+	while (fgets(buf, sizeof(buf), stdin)) {
 		char *v;
 
 		if (!strcmp(buf, "\n"))
 			break;
-		buf[line_len-1] = '\0';
+		buf[strlen(buf)-1] = '\0';
 
 		v = strchr(buf, '=');
 		if (!v)
@@ -348,100 +131,61 @@
 
 		if (!strcmp(buf, "protocol")) {
 			if (!strcmp(v, "imap"))
-				protocol = kSecAttrProtocolIMAP;
+				protocol = kSecProtocolTypeIMAP;
 			else if (!strcmp(v, "imaps"))
-				protocol = kSecAttrProtocolIMAPS;
+				protocol = kSecProtocolTypeIMAPS;
 			else if (!strcmp(v, "ftp"))
-				protocol = kSecAttrProtocolFTP;
+				protocol = kSecProtocolTypeFTP;
 			else if (!strcmp(v, "ftps"))
-				protocol = kSecAttrProtocolFTPS;
+				protocol = kSecProtocolTypeFTPS;
 			else if (!strcmp(v, "https"))
-				protocol = kSecAttrProtocolHTTPS;
+				protocol = kSecProtocolTypeHTTPS;
 			else if (!strcmp(v, "http"))
-				protocol = kSecAttrProtocolHTTP;
+				protocol = kSecProtocolTypeHTTP;
 			else if (!strcmp(v, "smtp"))
-				protocol = kSecAttrProtocolSMTP;
-			else {
-				/* we don't yet handle other protocols */
-				clear_credential();
+				protocol = kSecProtocolTypeSMTP;
+			else /* we don't yet handle other protocols */
 				exit(0);
-			}
 		}
 		else if (!strcmp(buf, "host")) {
 			char *colon = strchr(v, ':');
 			if (colon) {
-				UInt16 port_i;
 				*colon++ = '\0';
-				port_i = atoi(colon);
-				port = CFNumberCreate(kCFAllocatorDefault,
-						      kCFNumberShortType,
-						      &port_i);
+				port = atoi(colon);
 			}
-			host = CFStringCreateWithCString(kCFAllocatorDefault,
-							 v,
-							 ENCODING);
+			host = xstrdup(v);
 		}
 		else if (!strcmp(buf, "path"))
-			path = CFStringCreateWithCString(kCFAllocatorDefault,
-							 v,
-							 ENCODING);
+			path = xstrdup(v);
 		else if (!strcmp(buf, "username"))
-			username = CFStringCreateWithCString(
-					kCFAllocatorDefault,
-					v,
-					ENCODING);
+			username = xstrdup(v);
 		else if (!strcmp(buf, "password"))
-			password = CFDataCreate(kCFAllocatorDefault,
-						(UInt8 *)v,
-						strlen(v));
-		else if (!strcmp(buf, "password_expiry_utc"))
-			password_expiry_utc = CFDataCreate(kCFAllocatorDefault,
-							   (UInt8 *)v,
-							   strlen(v));
-		else if (!strcmp(buf, "oauth_refresh_token"))
-			oauth_refresh_token = CFDataCreate(kCFAllocatorDefault,
-							   (UInt8 *)v,
-							   strlen(v));
-		else if (!strcmp(buf, "state[]")) {
-			if (!strcmp(v, "osxkeychain:seen=1"))
-				state_seen = 1;
-		}
+			password = xstrdup(v);
 		/*
 		 * Ignore other lines; we don't know what they mean, but
 		 * this future-proofs us when later versions of git do
 		 * learn new lines, and the helpers are updated to match.
 		 */
 	}
-
-	free(buf);
 }
 
 int main(int argc, const char **argv)
 {
-	OSStatus result = 0;
 	const char *usage =
 		"usage: git credential-osxkeychain <get|store|erase>";
 
 	if (argc < 2 || !*argv[1])
 		die("%s", usage);
 
-	if (open(argv[0], O_RDONLY | O_EXLOCK) == -1)
-		die("failed to lock %s", argv[0]);
-
 	read_credential();
 
 	if (!strcmp(argv[1], "get"))
-		result = find_internet_password();
+		find_internet_password();
 	else if (!strcmp(argv[1], "store"))
-		result = add_internet_password();
+		add_internet_password();
 	else if (!strcmp(argv[1], "erase"))
-		result = delete_internet_password();
+		delete_internet_password();
 	/* otherwise, ignore unknown action */
 
-	if (result)
-		die("failed to %s: %d", argv[1], (int)result);
-
-	clear_credential();
-
 	return 0;
 }
# We can’t include <copyfile.h> prior to Leopard, because it didn’t exist.
--- old/t/unit-tests/clar/clar/fs.h
+++ new/t/unit-tests/clar/clar/fs.h
@@ -317,7 +317,7 @@
 # include <sys/sendfile.h>
 #endif
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 # include <copyfile.h>
 #endif
 
