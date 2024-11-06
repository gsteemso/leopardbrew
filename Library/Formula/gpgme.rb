class Gpgme < Formula
  desc 'Library access to GnuPG'
  homepage 'https://www.gnupg.org/software/gpgme/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2'
  sha256 '9499e8b1f33cccb6815527a1bc16049d35a6198a6c5fae0185f2bd561bce5224'

  option :universal

  depends_on 'make' => :build
  depends_on 'swig' => :build
  depends_on 'gnupg'
  depends_on 'libassuan'
  depends_on 'libgpg-error'
  depends_on 'python'
  depends_on 'python3'

  # no idea if this is still true
  conflicts_with "argp-standalone", :because => "gpgme picks it up during compile & fails to build"
  # nor this
  fails_with :llvm do build 2334; end

  # configure:
  # - The shared‐module extension on Darwin (Mac OS) is “.bundle”, not “.so”.
  # - Apple GCC doesn’t know the options “-Wno-format-truncation” or “-Wno-sizeof-pointer-div”,
  #   causing configuration failure due to false negatives.  This patch deletes their addition to
  #   CFLAGS.
  # lang/python/Makefile.in:
  # - The Python makefile doesn’t obey the instructions in {setup.py} when calling {setup.py}, so
  #   build runs after the first one fail due to missing files.  This patch inserts an omitted
  #   command, in two places it’s missing from.  (There may be one more, but we don’t use that
  #   build target so it’s hard to tell.)  This does not fully solve the problem; the {gpgme.py}
  #   script and the {_gpgme.bundle} compiled module must be copied over by hand, and who can even
  #   tell whether they will work properly after being compiled for a different version of Python?
  # src/gpgme-config.in:
  # - Two supposedly deprecated commands within {gpgme-config} are actually no longer supported by
  #   the {configure} script at all, causing them to emit useless output.  This patch deletes them
  #   the rest of the way.
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--enable-static"
    make
    begin
      ENV.deparallelize { safe_system "make", '-ik', "check" }
    rescue Exception
      # just keep going
    end
    make 'install'
  end # install

  test do
    assert_equal "#{Formula["gnupg"].opt_prefix}/bin/gpg",
                 shell_output("#{bin}/gpgme-config --get-gpg").strip
  end
end # Gpgme

__END__
--- old/configure
+++ new/configure
@@ -13968,7 +13968,7 @@
   soname_spec='${libname}${release}${major}$shared_ext'
   shlibpath_overrides_runpath=yes
   shlibpath_var=DYLD_LIBRARY_PATH
-  shrext_cmds='`test .$module = .yes && echo .so || echo .dylib`'
+  shrext_cmds='`test .$module = .yes && echo .bundle || echo .dylib`'
 
   sys_lib_search_path_spec="$sys_lib_search_path_spec /usr/local/lib"
   sys_lib_dlsearch_path_spec='/usr/local/lib /lib /usr/lib'
@@ -17850,7 +17850,7 @@
   soname_spec='${libname}${release}${major}$shared_ext'
   shlibpath_overrides_runpath=yes
   shlibpath_var=DYLD_LIBRARY_PATH
-  shrext_cmds='`test .$module = .yes && echo .so || echo .dylib`'
+  shrext_cmds='`test .$module = .yes && echo .bundle || echo .dylib`'
 
   sys_lib_dlsearch_path_spec='/usr/local/lib /lib /usr/lib'
   ;;
@@ -32029,8 +32029,6 @@
       CFLAGS="$CFLAGS -Wno-missing-field-initializers"
       CFLAGS="$CFLAGS -Wno-sign-compare"
       CFLAGS="$CFLAGS -Wno-format-zero-length"
-      CFLAGS="$CFLAGS -Wno-format-truncation"
-      CFLAGS="$CFLAGS -Wno-sizeof-pointer-div"
     fi
     if test "$USE_MAINTAINER_MODE" = "yes"; then
         if test x"$_gcc_wopt" = xyes ; then
--- old/lang/python/Makefile.in
+++ new/lang/python/Makefile.in
 all-local: copystamp
@@ -770,6 +770,9 @@
 	  srcdir="$(srcdir)" \
 	  top_builddir="$(top_builddir)" \
-	    $$PYTHON setup.py --verbose build --build-base="$$(basename "$${PYTHON}")-gpg" ; \
+	    $$PYTHON setup.py --verbose build --build-base="$$(basename "$${PYTHON}")-gpg" ; \
+	    $$PYTHON setup.py build --verbose --build-base="$$(basename "$${PYTHON}")-gpg" ; \
 	done
 
 python$(PYTHON_VERSION)-gpg/dist/gpg-$(VERSION).tar.gz.asc: copystamp
@@ -809,11 +812,15 @@
 	  srcdir="$(srcdir)" \
 	  top_builddir="$(top_builddir)" \
 	  $$PYTHON setup.py \
-	  build \
-	  --build-base="$$(basename "$${PYTHON}")-gpg" \
-	  install \
-	  --prefix "$(DESTDIR)$(prefix)" \
-	  --verbose ; \
+	    build --verbose --build-base="$$(basename "$${PYTHON}")-gpg" ; \
+	  echo "current interpreter is $(PYTHON) -- starting second build run" ; \
+	  CPP="$(CPP)" CFLAGS="$(CFLAGS)" srcdir="$(srcdir)" top_builddir="$(top_builddir)" \
+	    $$PYTHON setup.py build --verbose --build-base="$$(basename "$${PYTHON}")-gpg" ; \
+	  echo "current interpreter is $(PYTHON) -- starting install run" ; \
+	  CPP="$(CPP)" CFLAGS="$(CFLAGS)" PYTHONUSERBASE="$(DESTDIR)$(prefix)" \
+	    srcdir="$(srcdir)" top_builddir="$(top_builddir)" \
+	    $$PYTHON setup.py install --user --verbose ; \
+	  PYTHONUSERBASE= ; \
 	done
 
 uninstall-local:
--- old/src/gpgme-config.in
+++ new/src/gpgme-config.in
@@ -196,14 +196,6 @@
             done
             exit 1
 	    ;;
-        --get-gpg)
-            # Deprecated
-            output="$output @GPG@"
-            ;;
-        --get-gpgsm)
-            # Deprecated
-            output="$output @GPGSM@"
-            ;;
 	*)
             usage 1 1>&2
 	    ;;
