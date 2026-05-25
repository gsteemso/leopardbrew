# Stable release 2010-09-07; frozen.
class Ld64 < Formula
  desc "Updated version of the ld shipped by Apple"
  homepage "https://github.com/apple-oss-distributions/ld64/tree/ld64-97.17"
  # The latest version available that nominally builds for PPC is 127.2, which won’t build on Tiger, at least not without extensive
  # patching.  Leopard users:  If you like, add a 127.2 option, or fix the build on Tiger.
  url "https://github.com/apple-oss-distributions/ld64/archive/refs/tags/ld64-97.17.tar.gz"
  sha256 "dc609d295365f8f5853b45e8dbcb44ca85e7dbc7a530e6fb5342f81d3c042db5"
  revision 5  # For fixes to reporting.

  resource "makefile" do
    url "https://trac.macports.org/export/123511/trunk/dports/devel/ld64/files/Makefile-97", :using => :nounzip
    sha256 "48e3475bd73f9501d17b7d334d3bf319f5664f2d5ab9d13378e37c2519ae2a3a"
  end

  keg_only :provided_by_osx, "ld64 is an updated version of the ld shipped by Apple."

  option :universal

  depends_on MaximumMacOSRequirement => :snow_leopard

  # Tiger, and in some cases Leopard, either include old versions of these headers or don’t ship them at all.
  depends_on "dyld-headers" => :build
  depends_on "ld64-headers" => :build
  depends_on "libunwind-headers" => :build
  # No CommonCrypto
  depends_on "openssl3" if MacOS.version < :leopard

  fails_with :gcc_4_0 do
    build 5370
    cause 'It incorrectly gets hung up on “protected” status in the C++ code.'
  end

  patch :DATA  # Annotated inline.

  # Remove LTO support
  patch :p0 do
    url "https://trac.macports.org/export/103949/trunk/dports/devel/ld64/files/ld64-97-no-LTO.patch"
    sha256 "2596cc25118981cbc31e82ddcb70508057f1946c46c3d6d6845ab7bd01ff1433"
  end

  def install
    ENV.universal_binary if build.universal?

    (buildpath/'src/ld/configure.h').write <<-_.undent
        /* version information */
        #define LD_VERSION_STRING "@(#)PROGRAM:ld  PROJECT:ld64-#{version}\\n"

        /* support for realpath(3) */
        #{MacOS.version < :leopard ? '#define REALPATH_NEED_SYS_PARAM_H' : '/* #undef REALPATH_NEED_SYS_PARAM_H */'}
      _

    buildpath.install resource("makefile")
    mv "Makefile-97", "Makefile"

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
--- old/src/ld/ArchiveReader.hpp
+++ new/src/ld/ArchiveReader.hpp
# Correct a comment documenting what file‐load‐tracing command‐line option is being implemented, & make it work in the real world.
@@ -274,9 +274,9 @@
 	if ( strncmp((const char*)fileContent, "!<arch>\n", 8) != 0 )
 		throw "not an archive";
 
-	// write out path for -whatsloaded option
+	// write out path for -t option
 	if ( options.fLogAllFiles )
-		printf("%s\n", path);
+		fprintf(stderr, "[ld64:  archive loaded] %s\n", path);
 
 	if ( !options.fFullyLoadArchives && !fForceLoad ) {
 		const Entry* const firstMember = (Entry*)&fFileContent[8];
# Make why‐loaded reporting work in the real world.
@@ -339,9 +339,9 @@
 				continue;
 			if ( fOptions.fWhyLoad ) {
 				if ( fForceLoad )
-					printf("-force_load forced load of %s(%s)\n", this->getPath(), memberName);
+					fprintf(stderr, "[ld64] -force_load forced load of %s(%s)\n", this->getPath(), memberName);
 				else
-					printf("-all_load forced load of %s(%s)\n", this->getPath(), memberName);
+					fprintf(stderr, "[ld64] -all_load forced load of %s(%s)\n", this->getPath(), memberName);
 			}
 			ObjectFile::Reader* r = this->makeObjectReaderForMember(p);
 			std::vector<class ObjectFile::Atom*>&	atoms = r->getAtoms();
@@ -357,7 +357,7 @@
 				const Entry* member = (Entry*)&fFileContent[E::get32(it->second->ran_off)];
 				if ( fInstantiatedEntries.count(member) == 0 ) {
 					if ( fOptions.fWhyLoad )
-						printf("-ObjC forced load of %s(%s)\n", this->getPath(), member->getName());
+						fprintf(stderr, "[ld64] -ObjC forced load of %s(%s)\n", this->getPath(), member->getName());
 					// only return these atoms once
 					fInstantiatedEntries.insert(member);
 					ObjectFile::Reader* r = makeObjectReaderForMember(member);
# Make ToC dumping work in the real world.
@@ -426,7 +426,7 @@
 {
 	for (unsigned int i=0; i < fTableOfContentCount; ++i) {
 		const struct ranlib* e = &fTableOfContents[i];
-		printf("%s in %s\n", &fStringPool[E::get32(e->ran_un.ran_strx)], ((Entry*)&fFileContent[E::get32(e->ran_off)])->getName());
+		fprintf(stderr, "[ld64] %s in %s\n", &fStringPool[E::get32(e->ran_un.ran_strx)], ((Entry*)&fFileContent[E::get32(e->ran_off)])->getName());
 	}
 }
 
# Make why‐loaded reporting work in the real world.
@@ -444,7 +444,7 @@
 			const Entry* member = (Entry*)&fFileContent[E::get32(result->ran_off)];
 			if ( fInstantiatedEntries.count(member) == 0 ) {
 				if ( fOptions.fWhyLoad ) 
-					printf("%s forced load of %s(%s)\n", name, this->getPath(), member->getName());
+					fprintf(stderr, "[ld64] %s forced load of %s(%s)\n", name, this->getPath(), member->getName());
 				// only return these atoms once
 				fInstantiatedEntries.insert(member);
 				ObjectFile::Reader* r = makeObjectReaderForMember(member);
--- old/src/ld/MachOReaderDylib.hpp
+++ new/src/ld/MachOReaderDylib.hpp
# Correct a comment documenting what file‐load‐tracing command‐line option is being implemented, & make it work in the real world.
@@ -345,9 +345,9 @@
 	const macho_load_command<P>* const cmds = (macho_load_command<P>*)((char*)header + sizeof(macho_header<P>));
 	const macho_load_command<P>* const cmdsEnd = (macho_load_command<P>*)((char*)header + sizeof(macho_header<P>) + header->sizeofcmds());
 
-	// write out path for -whatsloaded option
+	// write out path for -t option
 	if ( options.fLogAllFiles )
-		printf("%s\n", path);
+		fprintf(stderr, "[ld64:  dylib loaded] %s\n", path);
 
 	if ( options.fRootSafe && ((header->flags() & MH_ROOT_SAFE) == 0) )
 		warning("using -root_safe but linking against %s which is not root safe", path);
--- old/src/ld/MachOReaderRelocatable.hpp
+++ new/src/ld/MachOReaderRelocatable.hpp
# Make file-load tracing work in the real world.
@@ -1950,7 +1950,7 @@
 
 	// write out path for -t or -whatsloaded option
 	if ( options.fLogObjectFiles || options.fLogAllFiles )
-		printf("%s\n", path);
+		fprintf(stderr, "[ld64:  Mach-O file loaded] %s\n", path);
 
 	// cache intersting pointers
 	const macho_header<P>* header = (const macho_header<P>*)fileContent;
# Make error reporting work in the real world.
@@ -4335,7 +4335,7 @@
 							displacement |= 0xFC000000;
 					}
 					else {
-						printf("bad instruction for BR24 reloc");
+						fprintf(stderr, "[ld64] bad instruction for BR24 reloc");
 					}
 					if ( reloc->r_extern() ) {
 						offsetInTarget = srcAddr + displacement;
--- old/src/ld/MachOWriterExecutable.hpp
+++ new/src/ld/MachOWriterExecutable.hpp
# Fix the messed‐up PowerPC maximum‐displacement constants, incorporating MacPorts’ un‐botching of the logic choosing whether to do
# a branch island.
@@ -7559,10 +7559,10 @@
 					displacement -= ref->getTarget().getAddress();
 				}
 				else {
-					const int64_t bl_eightMegLimit = 0x00FFFFFF;
-					if ( (displacement > bl_eightMegLimit) || (displacement < (-bl_eightMegLimit)) ) {
+					const int64_t bl_thirtyTwoMegLimit = 0x01FFFFFC;
+					if ( (displacement > bl_thirtyTwoMegLimit) || (displacement < -(bl_thirtyTwoMegLimit + 4)) ) {
 						//fprintf(stderr, "bl out of range (%lld max is +/-16M) from %s in %s to %s in %s\n", displacement, this->getDisplayName(), this->getFile()->getPath(), target.getDisplayName(), target.getFile()->getPath());
-						throwf("bl out of range (%lld max is +/-16M) from %s at 0x%08llX in %s of %s to %s at 0x%08llX in %s of  %s",
+						throwf("bl out of range (%lld max is +/-32M) from %s at 0x%08llX in %s of %s to %s at 0x%08llX in %s of  %s",
 							displacement, inAtom->getDisplayName(), inAtom->getAddress(), inAtom->getSectionName(), inAtom->getFile()->getPath(),
 							ref->getTarget().getDisplayName(), ref->getTarget().getAddress(), ref->getTarget().getSectionName(), ref->getTarget().getFile()->getPath());
 					}
@@ -7581,10 +7581,10 @@
 					// the mach-o way of encoding this is that the bl instruction's target addr is the offset into the target
#'
 					displacement -= ref->getTarget().getAddress();
 				}
-				const int64_t b_sixtyFourKiloLimit = 0x0000FFFF;
-				if ( (displacement > b_sixtyFourKiloLimit) || (displacement < (-b_sixtyFourKiloLimit)) ) {
+				const int64_t b_thirtyTwoKiloLimit = 0x00007FFC;
+				if ( (displacement > b_thirtyTwoKiloLimit) || (displacement < -(b_thirtyTwoKiloLimit + 4)) ) {
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
+	const int64_t bl_thirtyTwoMegLimit = 0x01FFFFFC;
 	if ( fTarget.getContentType() == ObjectFile::Atom::kBranchIsland ) {
 		displacement = getFinalTargetAdress() - this->getAddress();
-		if ( (displacement > bl_sixteenMegLimit) && (displacement < (-bl_sixteenMegLimit)) ) {
+		if ( (displacement > bl_thirtyTwoMegLimit) || (displacement < -(bl_thirtyTwoMegLimit + 4)) ) {
 			displacement = fTarget.getAddress() - this->getAddress();
 		}
 	}
@@ -11014,10 +11014,10 @@
 void BranchIslandAtom<ppc64>::copyRawContent(uint8_t buffer[]) const
 {
 	int64_t displacement;
-	const int64_t bl_sixteenMegLimit = 0x00FFFFFF;
+	const int64_t bl_thirtyTwoMegLimit = 0x01FFFFFC;
 	if ( fTarget.getContentType() == ObjectFile::Atom::kBranchIsland ) {
 		displacement = getFinalTargetAdress() - this->getAddress();
-		if ( (displacement > bl_sixteenMegLimit) && (displacement < (-bl_sixteenMegLimit)) ) {
+		if ( (displacement > bl_thirtyTwoMegLimit) || (displacement < -(bl_thirtyTwoMegLimit + 4)) ) {
 			displacement = fTarget.getAddress() - this->getAddress();
 		}
 	}
--- old/src/ld/Options.cpp
+++ new/src/ld/Options.cpp
# Incorporate a variation on MacPorts’ version‐number patch via configure.h, tuned to this revision of ld64.
@@ -31,12 +31,19 @@
 #include <vector>
 
 #include "configure.h"
+#if defined(REALPATH_NEEDS_SYS_PARAM_H)
+# include <sys/param.h>
+#endif
+#include <stdlib.h>
+
 #include "Options.h"
 #include "Architectures.hpp"
 #include "MachOFileAbstraction.hpp"
 
 extern void printLTOVersion(Options &opts);
 
+const char *ldVersionString = LD_VERSION_STRING;
+
 // magic to place command line in crash reports
 extern "C" char* __crashreporter_info__;
 static char crashreporterBuffer[1000];
# Make file‐search reporting work in the real world.
@@ -588,7 +595,7 @@
 	sprintf(possiblePath, format,  dir, rootName);
 	bool found = (stat(possiblePath, &statBuffer) == 0);
 	if ( fTraceDylibSearching )
-		printf("[Logging for XBS]%sfound library: '%s'\n", (found ? " " : " not "), possiblePath);
+		fprintf(stderr, "[Logging for XBS]%sfound library: '%s'\n", (found ? " " : " not "), possiblePath);
 	if ( found ) {
 		result.path = strdup(possiblePath);
 		result.fileLen = statBuffer.st_size;
@@ -706,7 +713,7 @@
 		}
 		bool found = (stat(possiblePath, &statBuffer) == 0);
 		if ( fTraceDylibSearching )
-			printf("[Logging for XBS]%sfound framework: '%s'\n",
+			fprintf(stderr, "[Logging for XBS]%sfound framework: '%s'\n",
 				   (found ? " " : " not "), possiblePath);
 		if ( found ) {
 			FileInfo result;
# Continue the version‐number patch.
@@ -2596,7 +2603,6 @@
 			addStandardLibraryDirectories = false;
 		else if ( strcmp(argv[i], "-v") == 0 ) {
 			fVerbose = true;
-			extern const char ldVersionString[];
 			fprintf(stderr, "%s", ldVersionString);
 			 // if only -v specified, exit cleanly
 			 if ( argc == 2 ) {
# This logic was missing the ppc64 case.  It was also incorrect if run on a pre‐Snow Leopard system.  It still is, but less so.
@@ -2865,9 +2871,12 @@
 			switch ( fArchitecture ) {
 				case CPU_TYPE_I386:
 				case CPU_TYPE_X86_64:
-				case CPU_TYPE_POWERPC:			
-					fReaderOptions.fMacVersionMin = ObjectFile::ReaderOptions::k10_6; // FIX FIX, this really should be a check of the OS version the linker is running o
+				case CPU_TYPE_POWERPC64:
+					fReaderOptions.fMacVersionMin = ObjectFile::ReaderOptions::k10_4;  // FIXME:  Should use running OS’ version.
 					break;
+				case CPU_TYPE_POWERPC:
+					fReaderOptions.fMacVersionMin = ObjectFile::ReaderOptions::k10_3;  // FIXME:  Should use running OS’ version.
+					break;
 				case CPU_TYPE_ARM:
 					fReaderOptions.fIPhoneVersionMin = ObjectFile::ReaderOptions::k2_0; 
 					break;
# This logic was missing the ppc64 case.  This is _probably_ correct?
@@ -2908,9 +2917,7 @@
 				fAllowTextRelocs = true;
 				fUndefinedTreatment = kUndefinedDynamicLookup;
 				break;
-			case CPU_TYPE_POWERPC:
-			case CPU_TYPE_I386:
-			case CPU_TYPE_ARM:
+			default:
 				// use .o files
 				fOutputKind = kObjectFile;
 				break;
# Fix the logic for what to do when internally handed a file pathname instead of a proper install path.
@@ -2936,17 +2943,10 @@
 		parseSegAddrTable(fSegAddrTablePath, this->installPath());
 		// HACK to support seg_addr_table entries that are physical paths instead of install paths
 		if ( fBaseAddress == 0 ) {
-			if ( strcmp(this->installPath(), "/usr/lib/libstdc++.6.dylib") == 0 ) {
-				parseSegAddrTable(fSegAddrTablePath, "/usr/lib/libstdc++.6.0.4.dylib");
-				if ( fBaseAddress == 0 )
-					parseSegAddrTable(fSegAddrTablePath, "/usr/lib/libstdc++.6.0.9.dylib");
-			}
-				
-			else if ( strcmp(this->installPath(), "/usr/lib/libz.1.dylib") == 0 ) 
-				parseSegAddrTable(fSegAddrTablePath, "/usr/lib/libz.1.2.3.dylib");
-				
-			else if ( strcmp(this->installPath(), "/usr/lib/libutil.dylib") == 0 ) 
-				parseSegAddrTable(fSegAddrTablePath, "/usr/lib/libutil1.0.dylib");
+			char  path_buffer[PATH_MAX + 1];  /* realpath(3) results buffer (allow for null terminator) */
+			char *path_buf_ptr = path_buffer;
+			if (path_buf_ptr = realpath(this->installPath(), path_buffer))
+				parseSegAddrTable(fSegAddrTablePath, path_buf_ptr);
 		}		
 	}
 	
