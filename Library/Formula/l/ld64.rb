class Ld64 < Formula
  desc "Updated version of the ld shipped by Apple"
  homepage "https://github.com/apple-oss-distributions/ld64/tree/ld64-97.17"
  # The latest version available that nominally builds for PPC is 127.2, which won’t build on Tiger, at least not without extensive
  # patching.  Leopard users:  If you like, add a 127.2 option, or fix the build on Tiger.
  url "https://github.com/apple-oss-distributions/ld64/archive/refs/tags/ld64-97.17.tar.gz"
  sha256 "dc609d295365f8f5853b45e8dbcb44ca85e7dbc7a530e6fb5342f81d3c042db5"
  revision 2

  resource "makefile" do
    url "https://trac.macports.org/export/123511/trunk/dports/devel/ld64/files/Makefile-97", :using => :nounzip
    sha256 "48e3475bd73f9501d17b7d334d3bf319f5664f2d5ab9d13378e37c2519ae2a3a"
  end

  keg_only :provided_by_osx, "ld64 is an updated version of the ld shipped by Apple."

  option :universal

  depends_on MaximumMacOSRequirement => :snow_leopard

  # Tiger either includes old versions of these headers, or doesn't ship them at all.
  depends_on "cctools-headers" => :build
  depends_on "dyld-headers" => :build
  depends_on "libunwind-headers" => :build
  # No CommonCrypto
  depends_on "openssl3" if MacOS.version < :leopard

  fails_with :gcc_4_0 do
    build 5370
    cause 'It incorrectly gets hung up on “protected” status in the C++ code.'
  end

  # Fix the messed‐up PowerPC maximum‐displacement constants, incorporating MacPorts’ un‐botching of the logic that chooses whether
  # to do a branch island.  Also incorporates MacPorts’ version‐number patch, tuned to this revision of ld64.
  patch :DATA

  # Remove LTO support
  patch :p0 do
    url "https://trac.macports.org/export/103949/trunk/dports/devel/ld64/files/ld64-97-no-LTO.patch"
    sha256 "2596cc25118981cbc31e82ddcb70508057f1946c46c3d6d6845ab7bd01ff1433"
  end

  def install
    ENV.universal_binary if build.universal?

    buildpath.install resource("makefile")
    mv "Makefile-97", "Makefile"
    inreplace "src/ld/Options.cpp", "@@VERSION@@", version.to_s

    if MacOS.version < :leopard
      # No CommonCrypto
      inreplace "src/ld/MachOWriterExecutable.hpp" do |s|
        s.gsub! "<CommonCrypto/CommonDigest.h>", "<openssl/md5.h>"
        s.gsub! "CC_MD5", "MD5"
      end

      inreplace "Makefile", "-Wl,-exported_symbol,__mh_execute_header", ""
    end

    args = %W[
      CC=#{ENV.cc}
      CXX=#{ENV.cxx}
      OTHER_CPPFLAGS=#{ENV.cppflags}
      OTHER_LDFLAGS=#{ENV.ldflags}
    ]

    args << 'RC_SUPPORTED_ARCHS="armv6 armv7 i386 x86_64"' if MacOS.version >= :lion
    args << "OTHER_LDFLAGS_LD64=-lcrypto" if MacOS.version < :leopard

    # Macports makefile hardcodes optimization
    inreplace "Makefile" do |s|
      s.change_make_var! "CFLAGS", ENV.cflags
      s.change_make_var! "CXXFLAGS", ENV.cxxflags
    end

    system "make", *args
    system "make", "install", "PREFIX=#{prefix}"
  end
end

__END__
--- old/src/ld/MachOWriterExecutable.hpp
+++ new/src/ld/MachOWriterExecutable.hpp
@@ -7559,10 +7559,10 @@
 					displacement -= ref->getTarget().getAddress();
 				}
 				else {
-					const int64_t bl_eightMegLimit = 0x00FFFFFF;
-					if ( (displacement > bl_eightMegLimit) || (displacement < (-bl_eightMegLimit)) ) {
+					const int64_t bl_sixtyFourMegLimit = 0x01FFFFFF;
+					if ( (displacement > bl_sixtyFourMegLimit) || (displacement < (-bl_sixtyFourMegLimit)) ) {
 						//fprintf(stderr, "bl out of range (%lld max is +/-16M) from %s in %s to %s in %s\n", displacement, this->getDisplayName(), this->getFile()->getPath(), target.getDisplayName(), target.getFile()->getPath());
-						throwf("bl out of range (%lld max is +/-16M) from %s at 0x%08llX in %s of %s to %s at 0x%08llX in %s of  %s",
+						throwf("bl out of range (%lld max is +/-32M) from %s at 0x%08llX in %s of %s to %s at 0x%08llX in %s of  %s",
 							displacement, inAtom->getDisplayName(), inAtom->getAddress(), inAtom->getSectionName(), inAtom->getFile()->getPath(),
 							ref->getTarget().getDisplayName(), ref->getTarget().getAddress(), ref->getTarget().getSectionName(), ref->getTarget().getFile()->getPath());
 					}
@@ -7584,7 +7584,7 @@
 				const int64_t b_sixtyFourKiloLimit = 0x0000FFFF;
 				if ( (displacement > b_sixtyFourKiloLimit) || (displacement < (-b_sixtyFourKiloLimit)) ) {
 					//fprintf(stderr, "bl out of range (%lld max is +/-16M) from %s in %s to %s in %s\n", displacement, this->getDisplayName(), this->getFile()->getPath(), target.getDisplayName(), target.getFile()->getPath());
-					throwf("bcc out of range (%lld max is +/-64K) from %s in %s to %s in %s",
+					throwf("bcc out of range (%lld max is +/-32K) from %s in %s to %s in %s",
 						displacement, inAtom->getDisplayName(), inAtom->getFile()->getPath(),
 						ref->getTarget().getDisplayName(), ref->getTarget().getFile()->getPath());
 				}
@@ -10996,10 +10996,10 @@
 void BranchIslandAtom<ppc>::copyRawContent(uint8_t buffer[]) const
 {
 	int64_t displacement;
-	const int64_t bl_sixteenMegLimit = 0x00FFFFFF;
+	const int64_t bl_sixtyFourMegLimit = 0x01FFFFFF;
 	if ( fTarget.getContentType() == ObjectFile::Atom::kBranchIsland ) {
 		displacement = getFinalTargetAdress() - this->getAddress();
-		if ( (displacement > bl_sixteenMegLimit) && (displacement < (-bl_sixteenMegLimit)) ) {
+		if ( (displacement > bl_sixtyFourMegLimit) || (displacement < (-bl_sixtyFourMegLimit)) ) {
 			displacement = fTarget.getAddress() - this->getAddress();
 		}
 	}
@@ -11014,10 +11014,10 @@
 void BranchIslandAtom<ppc64>::copyRawContent(uint8_t buffer[]) const
 {
 	int64_t displacement;
-	const int64_t bl_sixteenMegLimit = 0x00FFFFFF;
+	const int64_t bl_sixtyFourMegLimit = 0x01FFFFFF;
 	if ( fTarget.getContentType() == ObjectFile::Atom::kBranchIsland ) {
 		displacement = getFinalTargetAdress() - this->getAddress();
-		if ( (displacement > bl_sixteenMegLimit) && (displacement < (-bl_sixteenMegLimit)) ) {
+		if ( (displacement > bl_sixtyFourMegLimit) || (displacement < (-bl_sixtyFourMegLimit)) ) {
 			displacement = fTarget.getAddress() - this->getAddress();
 		}
 	}
--- old/src/ld/Options.cpp
+++ new/src/ld/Options.cpp
@@ -37,6 +37,8 @@
 
 extern void printLTOVersion(Options &opts);
 
+const char *ldVersionString = "@(#)PROGRAM:ld  PROJECT:ld64-@@VERSION@@\n";
+
 // magic to place command line in crash reports
 extern "C" char* __crashreporter_info__;
 static char crashreporterBuffer[1000];
@@ -2596,7 +2598,6 @@
 			addStandardLibraryDirectories = false;
 		else if ( strcmp(argv[i], "-v") == 0 ) {
 			fVerbose = true;
-			extern const char ldVersionString[];
 			fprintf(stderr, "%s", ldVersionString);
 			 // if only -v specified, exit cleanly
 			 if ( argc == 2 ) {
