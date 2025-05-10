class Xmlto < Formula
  desc 'Convert XML to another format (based on XSL or other tools)'
  homepage 'https://pagure.io/xmlto'
  url 'https://pagure.io/xmlto/archive/0.0.29/xmlto-0.0.29.tar.gz'
  sha256 '40504db68718385a4eaa9154a28f59e51e59d006d1aa14f5bc9d6fded1d6017a'

  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'docbook-xsl'
  # Doesn't strictly depend on GNU getopt, but OS X system getopt(1)
  # does not support longopts in the optstring, so use GNU getopt.
  depends_on 'gnu-getopt'

  # xmlto forces --nonet on xsltproc, which causes it to fail when
  # DTDs/entities aren't available locally.
  # it also uses an http:// URL for an https‐only server.
  patch :DATA

  def install
    # GNU getopt is keg-only, so point configure to it
    ENV['GETOPT'] = Formula['gnu-getopt'].opt_bin/'getopt'
    # Find our docbook catalog
    ENV['XML_CATALOG_FILES'] ||= etc/'xml/catalog'

    system 'autoreconf', '--force', '--install'
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--with-webbrowser=any'
    ENV.deparallelize { system 'make', 'install' }
  end
end


__END__
--- old/xmlto.in
+++ new/xmlto.in
@@ -225,7 +225,7 @@
 export VERBOSE
 
 # Disable network entities
-XSLTOPTS="$XSLTOPTS --nonet"
+#XSLTOPTS="$XSLTOPTS --nonet"
 
 # The names parameter for the XSLT stylesheet
 XSLTPARAMS=""
@@ -582,7 +582,7 @@
 if [ "$PROFILE" -eq 1 ]
 then
   PROF_PROCESSED="$XSLT_PROCESSED_DIR/$(basename "${INPUT_FILE%.*}").prof"
-  PROFILE_STYLESHEET="http://docbook.sourceforge.net/release/xsl/current/profiling/profile.xsl"
+  PROFILE_STYLESHEET="https://docbook.sourceforge.net/release/xsl/current/profiling/profile.xsl"
   [ "$VERBOSE" -ge 1 ] && echo >&2 "Profiling stylesheet: ${PROFILE_STYLESHEET}"
 
   [ "${VERBOSE}" -ge 1 ] && \
