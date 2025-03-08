class Ld64128ppc < Formula
  desc 'Updated version of the ld shipped by Apple'
  homepage 'https://github.com/apple-oss-distributions/ld64/tree/ld64-128.2'
  url 'https://github.com/apple-oss-distributions/ld64/archive/refs/tags/ld64-127.2.tar.gz'
  sha256 'acfc5c3340a24ad8696ff22027b121cb3807c75fade7dec48b2b52494698e05f'
  version '128.2_ppc'

  resource 'makefile' do
    url 'file:///Users/gsteemso/devel/_ld64/new-Makefile'
    sha256 '02857a391fc7e911d9ceea9aec793d429414eb31cc071088ad6a4509c6f08461'
  end

  option :universal
  option 'with-tests', 'Perform build‐time unit tests'

  depends_on MaximumMacOSRequirement => :mountain_lion

  # Tiger either includes old versions of these headers, or doesn't ship them at all.
  depends_on 'cctools-headers' => :build
  depends_on 'dyld-headers' => :build
  depends_on 'libunwind-headers' => :build
  # No CommonCrypto
  depends_on 'openssl' if MacOS.version < :leopard

  keg_only :provided_by_osx, 'An older version is already installed as part of the OS.'

  fails_with :gcc_4_0 do build 5370; end  # does it really?  hells if I know

  # Apply 127.2 → 128.2 diff, except file renaming, without PowerPC stripping:
  patch :p1 do
    url 'file:///Users/gsteemso/devel/_ld64/ld64-127.2-to-128.2_ppc-shorter.patch'
    sha256 '06eea28c5422966a8e3bdfc93af51f484454af06abad7fa8cde8cb86aaa03cfd'
  end

  # Omnibus collection of MacPorts, Tigerbrew, and Leopardbrew patches.
  # src/abstraction/MachOFileAbstraction.hpp:
  # - Correct error‐message and preprocessor‐constant typos.
  # - Implement an ugly hack to get machochecker working correctly (the file
  #   abstraction fails to account for there being more than 1 variable-length
  #   member of a specific variable-length array, which is a concept so painful
  #   to define in C++ terms that I just didn’t).
  # src/ld/HeaderAndLoadCommands.hpp:
  # - Add a missing header‐file inclusion.
  # - Correct an error‐message typo.
  # src/ld/InputFiles.cpp:
  # - Remove dependencies on Clang/LLVM.
  # src/ld/ld.cpp:
  # - Remove a duplicate header‐file inclusion.
  # - Remove dependencies on Clang/LLVM.
  # src/ld/ld.hpp:
  # - Correct function‐name typos & remove some trailing whitespace.
  # src/ld/LinkEdit.hpp:
  # - Skip zero-length atoms to prevent metadata spillover.  <rdar://problem/10422823>
  # src/ld/LinkEditClassic.hpp:
  # - Ensure that __mh_execute_header cannot apply to position‐independent
  #   executables (support slideable static images).  <rdar://problem/10280094>
  # - Refine when to use scattered relocation on x86.
  # - Error message:  “Invalid”, not “illegal”.  No one is going to jail.
  # src/ld/Options.cpp:
  # - Improve version reporting.
  # - Function name:  “Invalid”, not “illegal”.  No one is going to jail.
  # - Correct error‐message typos.
  # - Tweak version‐minimum adjustment to allow for iOS simulation on x86_64.
  # - Ensure ppc64 kexts have the correct Mach filetype.
  # - Adjust determination of when to not use compressed LINKEDIT.
  # - Don’t emit minimum‐version or function‐start load commands prior to Mac
  #   OS 10.7 or iOS 4.2.  (These versions are totally guesstimated, and should
  #   be corrected; we only know for sure that Mac OS 10.5 doesn’t know about
  #   them, which might not be a problem except none of its tools do either.)
  # - Don’t use the classic linker unless explicitly requested.
  # src/ld/Options.h:
  # - Function name:  “Invalid”, not “illegal”.  No one is going to jail.
  # src/ld/OutputFile.cpp:
  # - Improve error logging.
  # - Correctly alignment‐pad zero‐fill sections.  <rdar://problem/10445047>
  # - Include PPC32 in 4GiB out‐of‐range warning.  AKA <rdar://problem/9610466>
  #   for ppc (https://trac.macports.org/ticket/46801)
  # - Do not warn when -static either.
  # - Fix bungled limit calculations on PPC branch logic.
  # - Correct function‐name typos.
  # - Fix incorrect NOP generation for ppc64.
  # - Error messages:  “Invalid”, not “illegal”.  No one is going to jail.
  # - Correctly handle global weak references.
  # src/ld/parsers/archive_file.cpp:
  # - Remove dependencies on Clang/LLVM.
  # src/ld/parsers/libunwind/AddressSpace.hpp:
  # - Remove an unused header‐file inclusion.  (http://trac.macports.org/ticket/46535)
  # src/ld/parsers/macho_dylib_file.cpp:
  # - Add PowerPC platforms to those which special-case older libSystem dylibs,
  #   leaving Arm platforms as the only ones that don’t.
  # src/ld/parsers/macho_relocatable_file.cpp:
  # - Correct function‐name typos.
  # - Avert crashes/freezes by checking for mach-O files with specific
  #   malformations.  <rdar://problem/12501376>
  # - Ensure self‐references are direct.
  # - Correct error‐message typos.
  # - Tune up -mlongbranch handling.  (https://trac.macports.org/ticket/44607)
  # src/ld/passes/objc.cpp:
  # - Loosen restrictions on size test to allow for padding.  <rdar://problem/10272666>
  # src/ld/passes/order.cpp:
  # - Add initializers to the list of things that may have ordering applied.
  # src/ld/passes/stubs/stubs.cpp:
  # - Remove an unused (and misspelt) variable.
  # - Throw an error if resolver functions are attempted for targets prior to
  #   Mac OS 10.6.
  # - Add ppc64 to list of architectures not supporting dylib resolver stubs.
  # src/ld/passes/tlvp.cpp:
  # - Error message:  “Invalid”, not “illegal”.  No one is going to jail.
  # src/ld/Resolver.cpp:
  # - Remove dependencies on Clang/LLVM.
  # - Resolve dylib stub helper regardless of whether dylib info is compressed.
  # src/other/dyldinfo.cpp:
  # - Add omitted ppc64 architecture reporting.
  # src/other/machochecker.cpp:
  # - Fix the mess where it assumes the first member of a variable‐length array
  #   of variable‐length arrays is the one it’s searching for (spoiler alert:
  #   a non‐trivial proportion of the time, it isn’t).
  # - Correct error‐message and function‐name typos.
  # src/other/ObjectDump.cpp:
  # - Remove dependencies on Clang/LLVM.
  # - Remove over‐processing of thin binaries.
  # src/other/rebase.cpp:
  # - Add a missing header‐file inclusion.
  # unit-tests/bin/result-filter.pl:
  # - Correct error‐message typo.
  # unit-tests/include/common.makefile:
  # - Do not set variables to excessively‐specific SDK versions.
  # unit-tests/test-cases/allow_heap_execute/Makefile:
  # - Add the ppc64 case.
  # unit-tests/test-cases/archive-basic/Makefile:
  # - Only report success AFTER the last test has run.
  patch :DATA

  # Tweak the unit tests during formula tuning – see patches at end of above
  # unit-tests/bin/result-filter.pl:
  # - Insert a blank line between tests.
  # - Uncomment the bits that print the stdout and stderr captured during each
  #   unsuccessful test.
  # - Add code to print the stdout and stderr captures of tests that `make` did
  #   not choke on, but were deemed to have failed anyway because they produced
  #   output to stderr.
  # - Print the names and outcomes of all tests, not just the failed ones.
  # unit-tests/include/common.makefile:
  # - Add “-v” to CFLAGS and CXXFLAGS so that the exact commands emitted by the
  #   compiler driver will be shown.
  # - Add code to dump the environment variables during each test, into a
  #   different file according to whether the test is being run individually or
  #   as part of the whole set.
  # unit-tests/run-all-unit-tests:
  # - Add an environment‐variable export to indicate that all tests are being
  #   run at once, for consumption by the modified “common.makefile”.

  def install
    # Complete the 127.2 → 128.2 update patch by renaming the two files that
    # were renamed by Apple.  (The “patch” program, designed to do as little
    # damage as possible when misapplied, never renames files.)
    mv 'src/ld/passes/order_file.h',   'src/ld/passes/order.h'
    mv 'src/ld/passes/order_file.cpp', 'src/ld/passes/order.cpp'

    ENV.universal_binary if build.universal?

    buildpath.install resource('makefile')
    mv 'new-Makefile', 'Makefile'
    inreplace 'src/ld/Options.cpp', '@@VERSION@@', version.to_s

    if MacOS.version < :leopard
      # No CommonCrypto
      inreplace 'src/ld/OutputFile.cpp' do |s|
        s.gsub! '<CommonCrypto/CommonDigest.h>', '<openssl/md5.h>'
        s.gsub! 'CC_MD5', 'MD5'
      end
      ENV.append 'LDFLAGS', '-lcrypto'

      inreplace 'Makefile', '-Wl,-exported_symbol,__mh_execute_header', ''
    end

    if build.with? 'tests'
      # The stuff that can’t be fixed with this substitution was already `patch`ed out.
      inreplace 'unit-tests/include/common.makefile', '10.6', '10.4' if MacOS.version < '10.6'

      runnable_archs = CPU.all_archs.select{ |a| CPU.can_run?(a) }.map(&:to_s)
      inreplace 'unit-tests/run-all-unit-tests', /x86_64 +i386/, runnable_archs * ' '
    end

    system 'make'
    if build.with? 'tests'
      ENV['as_nl'] = 'fake' if superenv?  # disable argument refurbishment even for Make
      without_archflags { system 'make', '-j1', 'check' }
      ENV.delete('as_nl')
    end
    raise;
    system 'make', 'install', "PREFIX=#{prefix}"
  end # install
end # Ld64128ppc

__END__
--- old/src/abstraction/MachOFileAbstraction.hpp
+++ new/src/abstraction/MachOFileAbstraction.hpp
@@ -166,7 +166,7 @@
 	#define X86_64_RELOC_TLV    9
 #endif
 
-#define GENERIC_RLEOC_TLV  5
+#define GENERIC_RELOC_TLV  5
 
 #ifndef EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER
 	#define EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER 0x10
@@ -883,6 +883,8 @@
 	uint64_t		thread_register(uint32_t index) const				INLINE { return P::getP(thread_registers[index]); }
 	void			set_thread_register(uint32_t index, uint64_t value)	INLINE { P::setP(thread_registers[index], value); }
 	
+	uint32_t*		raw_array() const									INLINE { return (uint32_t*) &fields_flavor; }
+
 	typedef typename P::E		E;
 	typedef typename P::uint_t	pint_t;
 private:
--- old/src/ld/HeaderAndLoadCommands.hpp
+++ new/src/ld/HeaderAndLoadCommands.hpp
@@ -29,6 +29,7 @@
 #include <limits.h>
 #include <unistd.h>
 #include <mach-o/loader.h>
+#include <mach/i386/thread_status.h>
 
 #include <vector>
 
@@ -459,7 +460,7 @@
 		case Options::kKextBundle:
 			return MH_KEXT_BUNDLE;
 	}
-	throw "unknonwn mach-o file type";
+	throw "unknown mach-o file type";
 }
 
 template <typename A>
--- old/src/ld/InputFiles.cpp
+++ new/src/ld/InputFiles.cpp
@@ -58,7 +58,6 @@
 #include "macho_relocatable_file.h"
 #include "macho_dylib_file.h"
 #include "archive_file.h"
-#include "lto_file.h"
 #include "opaque_section_file.h"
 
 
@@ -175,10 +174,6 @@
 	if ( result != NULL  )
 		 return result;
 		 
-	result = lto::archName(p, len);
-	if ( result != NULL  )
-		 return result;
-	
 	if ( strncmp((const char*)p, "!<arch>\n", 8) == 0 )
 		return "archive";
 	
@@ -264,11 +259,6 @@
 	if ( objResult != NULL ) 
 		return this->addObject(objResult, info, len);
 
-	// see if it is an llvm object file
-	objResult = lto::parse(p, len, info.path, info.modTime, _nextInputOrdinal, _options.architecture(), _options.subArchitecture(), _options.logAllFiles());
-	if ( objResult != NULL ) 
-		return this->addObject(objResult, info, len);
-
 	// see if it is a dynamic library
 	ld::dylib::File* dylibResult = mach_o::dylib::parse(p, len, info.path, info.modTime, _options, _nextInputOrdinal, info.options.fBundleLoader, indirectDylib);
 	if ( dylibResult != NULL ) 
@@ -290,31 +280,6 @@
 			logArchive(archiveResult);
 		return this->addArchive(archiveResult, info, len);
 	}
-	
-	// does not seem to be any valid linker input file, check LTO misconfiguration problems
-	if ( lto::archName((uint8_t*)p, len) != NULL ) {
-		if ( lto::libLTOisLoaded() ) {
-			throwf("file was built for %s which is not the architecture being linked (%s)", fileArch(p, len), _options.architectureName());
-		}
-		else {
-			const char* libLTO = "libLTO.dylib";
-			char ldPath[PATH_MAX];
-			char tmpPath[PATH_MAX];
-			char libLTOPath[PATH_MAX];
-			uint32_t bufSize = PATH_MAX;
-			if ( _NSGetExecutablePath(ldPath, &bufSize) != -1 ) {
-				if ( realpath(ldPath, tmpPath) != NULL ) {
-					char* lastSlash = strrchr(tmpPath, '/');
-					if ( lastSlash != NULL )
-						strcpy(lastSlash, "/../lib/libLTO.dylib");
-					libLTO = tmpPath;
-					if ( realpath(tmpPath, libLTOPath) != NULL ) 
-						libLTO = libLTOPath;
-				}
-			}
-			throwf("could not process llvm bitcode object file, because %s could not be loaded", libLTO);
-		}
-	}
 
 	// error handling
 	if ( ((fat_header*)p)->magic == OSSwapBigToHostInt32(FAT_MAGIC) ) {
--- old/src/ld/ld.cpp
+++ new/src/ld/ld.cpp
@@ -44,7 +44,6 @@
 #include <mach/mach_host.h>
 #include <dlfcn.h>
 #include <mach-o/dyld.h>
-#include <dlfcn.h>
 #include <AvailabilityMacros.h>
 
 #include <string>
@@ -83,7 +82,6 @@
 #include "parsers/archive_file.h"
 #include "parsers/macho_relocatable_file.h"
 #include "parsers/macho_dylib_file.h"
-#include "parsers/lto_file.h"
 #include "parsers/opaque_section_file.h"
 
 
--- old/src/ld/ld.hpp
+++ new/src/ld/ld.hpp
@@ -366,53 +366,53 @@
 	bool			weakImport : 1;
 	TargetBinding	binding : 3;
 	bool			contentAddendOnly : 1;
-	bool			contentDetlaToAddendOnly : 1;
+	bool			contentDeltaToAddendOnly : 1;
 	
 	typedef Fixup*		iterator;
 
 	Fixup() :
 		offsetInAtom(0), kind(kindNone), clusterSize(k1of1), weakImport(false), 
 		binding(bindingNone),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) { u.target = NULL; }
+		contentAddendOnly(false), contentDeltaToAddendOnly(false) { u.target = NULL; }
 
 	Fixup(Kind k, Atom* targetAtom) :
 		offsetInAtom(0), kind(k), clusterSize(k1of1), weakImport(false), 
 		binding(Fixup::bindingDirectlyBound),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false)  
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ assert(targetAtom != NULL); u.target = targetAtom; }
 
 	Fixup(uint32_t off, Cluster c, Kind k) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(false), 
 		binding(Fixup::bindingNone),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false)  
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ u.addend = 0; }
 
 	Fixup(uint32_t off, Cluster c, Kind k, bool weakIm, const char* name) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(weakIm), 
 		binding(Fixup::bindingByNameUnbound),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) 
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ assert(name != NULL); u.name = name; }
 		
 	Fixup(uint32_t off, Cluster c, Kind k, TargetBinding b, const char* name) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(false), binding(b),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) 
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ assert(name != NULL); u.name = name; }
 		
 	Fixup(uint32_t off, Cluster c, Kind k, const Atom* targetAtom) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(false), 
 		binding(Fixup::bindingDirectlyBound),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) 
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ assert(targetAtom != NULL); u.target = targetAtom; }
 		
 	Fixup(uint32_t off, Cluster c, Kind k, TargetBinding b, const Atom* targetAtom) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(false), binding(b),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) 
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ assert(targetAtom != NULL); u.target = targetAtom; }
 		
 	Fixup(uint32_t off, Cluster c, Kind k, uint64_t addend) :
 		offsetInAtom(off), kind(k), clusterSize(c), weakImport(false), 
 		binding(Fixup::bindingNone),  
-		contentAddendOnly(false), contentDetlaToAddendOnly(false) 
+		contentAddendOnly(false), contentDeltaToAddendOnly(false)
 			{ u.addend = addend; }
 			
 	bool firstInCluster() const { 
--- old/src/ld/LinkEdit.hpp
+++ new/src/ld/LinkEdit.hpp
@@ -1332,6 +1332,10 @@
 			std::vector<const ld::Atom*>& atoms = sect->atoms;
 			for (std::vector<const ld::Atom*>::iterator ait = atoms.begin(); ait != atoms.end(); ++ait) {
 				const ld::Atom* atom = *ait;
+				// <rdar://problem/10422823> filter out zero-length atoms, so
+				// LC_FUNCTION_STARTS address cannot spill into next section
+				if ( atom->size() == 0 )
+					continue;
 				uint64_t nextAddr = atom->finalAddress();
 				if ( atom->isThumb() )
 					nextAddr |= 1; 
--- old/src/ld/LinkEditClassic.hpp
+++ new/src/ld/LinkEditClassic.hpp
@@ -356,8 +356,9 @@
 				entry.set_n_type(N_EXT | N_SECT | N_PEXT);
 		}
 		else if ( (atom->symbolTableInclusion() == ld::Atom::symbolTableInAndNeverStrip)
-					&& (atom->section().type() == ld::Section::typeMachHeader) ) {
-			// the __mh_execute_header is historical magic and must be an absolute symbol
+					&& (atom->section().type() == ld::Section::typeMachHeader) 
+					&& !_options.positionIndependentExecutable() ) {
+			// the __mh_execute_header is non-PIE historical magic and must be an absolute symbol
 			entry.set_n_type(N_EXT | N_ABS);
 		}
 	}
@@ -1411,8 +1412,8 @@
 			}
 			else {
 				// regular pointer
-				if ( !external && (entry.toAddend != 0) ) {
-					// use scattered reloc is target offset is non-zero
+				if ( !external && (entry.toAddend != 0) && (entry.toTarget->symbolTableInclusion() != ld::Atom::symbolTableNotIn) ) {
+					// use scattered reloc if target offset is non-zero into named atom (5658046)
 					sreloc1->set_r_scattered(true);
 					sreloc1->set_r_pcrel(false);
 					sreloc1->set_r_length(2);
@@ -2436,7 +2437,7 @@
 				{
 					const ld::dylib::File* dylib = dynamic_cast<const ld::dylib::File*>(target->file());
 					if ( (dylib != NULL) && dylib->willBeLazyLoadedDylib() )
-						throwf("illegal data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
+						throwf("invalid data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
 				}
 				return symbolIndex(target);
 		}
--- old/src/ld/Options.cpp
+++ new/src/ld/Options.cpp
@@ -36,10 +40,7 @@
 #include "Architectures.hpp"
 #include "MachOFileAbstraction.hpp"
 
-// upward dependency on lto::version()
-namespace lto {
-	extern const char* version();
-}
+const char *ldVersionString = "@(#)PROGRAM:ld  PROJECT:ld64-@@VERSION@@\n";
 
 // magic to place command line in crash reports
 const int crashreporterBufferSize = 2000;
@@ -141,7 +138,7 @@
 	this->parse(argc, argv);
 	this->parsePostCommandLineEnvironmentSettings();
 	this->reconfigureDefaults();
-	this->checkIllegalOptionCombinations();
+	this->checkInvalidOptionCombinations();
 }
 
 Options::~Options()
@@ -511,29 +508,29 @@
 		}
 		if ( (fMacVersionMin == ld::macVersionUnset) && (fOutputKind != Options::kObjectFile) ) {
 	#ifdef DEFAULT_MACOSX_MIN_VERSION
-			warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+			warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 			setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 	#else
-			warning("-macosx_version_min not specificed, assuming 10.6");
+			warning("-macosx_version_min not specified, assuming 10.6");
 			fMacVersionMin = ld::mac10_6;
 	#endif		
 		}
 		break;
 	case CPU_TYPE_POWERPC64:
 		fArchitectureName = "ppc64";
 		if ( (fMacVersionMin == ld::macVersionUnset) && (fOutputKind != Options::kObjectFile) ) {
-			warning("-macosx_version_min not specificed, assuming 10.5");
+			warning("-macosx_version_min not specified, assuming 10.5");
 			fMacVersionMin = ld::mac10_5;
 		}
 		break;
 	case CPU_TYPE_I386:
 		fArchitectureName = "i386";
 		if ( (fMacVersionMin == ld::macVersionUnset) && (fOutputKind != Options::kObjectFile) ) {
 	#ifdef DEFAULT_MACOSX_MIN_VERSION
-			warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+			warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 			setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 	#else
-			warning("-macosx_version_min not specificed, assuming 10.6");
+			warning("-macosx_version_min not specified, assuming 10.6");
 			fMacVersionMin = ld::mac10_6;
 	#endif		
 		}
@@ -544,10 +541,10 @@
 		fArchitectureName = "x86_64";
 		if ( (fMacVersionMin == ld::macVersionUnset) && (fOutputKind != Options::kObjectFile) ) {
 	#ifdef DEFAULT_MACOSX_MIN_VERSION
-			warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+			warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 			setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 	#else
-			warning("-macosx_version_min not specificed, assuming 10.6");
+			warning("-macosx_version_min not specified, assuming 10.6");
 			fMacVersionMin = ld::mac10_6;
 	#endif		
 		}
@@ -566,13 +563,13 @@
 		assert(fArchitectureName != NULL);
 		if ( (fMacVersionMin == ld::macVersionUnset) && (fIOSVersionMin == ld::iOSVersionUnset) && (fOutputKind != Options::kObjectFile) ) {
 #if defined(DEFAULT_IPHONEOS_MIN_VERSION)
-			warning("-ios_version_min not specificed, assuming " DEFAULT_IPHONEOS_MIN_VERSION);
+			warning("-ios_version_min not specified, assuming " DEFAULT_IPHONEOS_MIN_VERSION);
 			setIOSVersionMin(DEFAULT_IPHONEOS_MIN_VERSION);
 #elif defined(DEFAULT_MACOSX_MIN_VERSION)
-			warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+			warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 			setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 #else
-			warning("-macosx_version_min not specificed, assuming 10.6");
+			warning("-macosx_version_min not specified, assuming 10.6");
 			fMacVersionMin = ld::mac10_6;
 #endif
 		}
@@ -1794,7 +1791,7 @@
 // The general rule is "last option wins", i.e. if both -bundle and -dylib are specified,
 // whichever was last on the command line is used.
 //
-// Error check for invalid combinations of options is done in checkIllegalOptionCombinations()
+// Error check for invalid combinations of options is done in checkInvalidOptionCombinations()
 //
 void Options::parse(int argc, const char* argv[])
 {
@@ -2823,13 +2820,10 @@
 			addStandardLibraryDirectories = false;
 		else if ( strcmp(argv[i], "-v") == 0 ) {
 			fVerbose = true;
-			extern const char ldVersionString[];
 			fprintf(stderr, "%s", ldVersionString);
+			fprintf(stderr, "configured to support archs:  %s\n", ALL_SUPPORTED_ARCHS);
 			 // if only -v specified, exit cleanly
 			 if ( argc == 2 ) {
-				const char* ltoVers = lto::version();
-				if ( ltoVers != NULL )
-					fprintf(stderr, "%s\n", ltoVers);
 				exit(0);
 			}
 		}
@@ -3099,24 +3093,24 @@
 				case CPU_TYPE_POWERPC:			
 					if ( (fOutputKind != Options::kObjectFile) && (fOutputKind != Options::kPreload) ) {
 			#ifdef DEFAULT_MACOSX_MIN_VERSION
-						warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+						warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 						setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 			#else
-						warning("-macosx_version_min not specificed, assuming 10.6");
+						warning("-macosx_version_min not specified, assuming 10.6");
 						fMacVersionMin = ld::mac10_6;
 			#endif		
 					}
 					break;
 				case CPU_TYPE_ARM:
 					if ( (fOutputKind != Options::kObjectFile) && (fOutputKind != Options::kPreload) ) {
 			#if defined(DEFAULT_IPHONEOS_MIN_VERSION)
-						warning("-ios_version_min not specificed, assuming " DEFAULT_IPHONEOS_MIN_VERSION);
+						warning("-ios_version_min not specified, assuming " DEFAULT_IPHONEOS_MIN_VERSION);
 						setIOSVersionMin(DEFAULT_IPHONEOS_MIN_VERSION);
 			#elif defined(DEFAULT_MACOSX_MIN_VERSION)
-						warning("-macosx_version_min not specificed, assuming " DEFAULT_MACOSX_MIN_VERSION);
+						warning("-macosx_version_min not specified, assuming " DEFAULT_MACOSX_MIN_VERSION);
 						setMacOSXVersionMin(DEFAULT_MACOSX_MIN_VERSION);
 			#else
-						warning("-macosx_version_min not specificed, assuming 10.6");
+						warning("-macosx_version_min not specified, assuming 10.6");
 						fMacVersionMin = ld::mac10_6;
 			#endif
 					}
@@ -3144,7 +3138,7 @@
 			}
 			break;
 		case CPU_TYPE_X86_64:
-			if ( fMacVersionMin < ld::mac10_4 ) {
+			if ( (fMacVersionMin < ld::mac10_4) && (fIOSVersionMin == ld::iOSVersionUnset) ) {
 				//warning("-macosx_version_min should be 10.4 or later for x86_64");
 				fMacVersionMin = ld::mac10_4;
 			}
@@ -3173,6 +3167,7 @@
 				// else use object file
 			case CPU_TYPE_POWERPC:
 			case CPU_TYPE_I386:
+			case CPU_TYPE_POWERPC64:
 				// use .o files
 				fOutputKind = kObjectFile;
 				break;
@@ -3455,26 +3450,11 @@
 
 	
 	// only use compressed LINKEDIT for:
-	//			x86_64 and i386 on Mac OS X 10.6 or later
-	//			arm on iPhoneOS 3.1 or later
+	//			Mac OS 10.6 or later
+	//			iOS 3.1 or later
 	if ( fMakeCompressedDyldInfo ) {
-		switch (fArchitecture) {
-			case CPU_TYPE_I386:
-				if ( fIOSVersionMin != ld::iOSVersionUnset ) // simulator always uses compressed LINKEDIT
-					break;
-			case CPU_TYPE_X86_64:
-				if ( fMacVersionMin < ld::mac10_6 ) 
-					fMakeCompressedDyldInfo = false;
-				break;
-            case CPU_TYPE_ARM:
-				if ( !minOS(ld::mac10_6, ld::iOS_3_1) )
-					fMakeCompressedDyldInfo = false;
-				break;
-			case CPU_TYPE_POWERPC:
-			case CPU_TYPE_POWERPC64:
-			default:
-				fMakeCompressedDyldInfo = false;
-		}
+		if ( !minOS(ld::mac10_6, ld::iOS_3_1) )
+			fMakeCompressedDyldInfo = false;
 	}
 
 		
@@ -3567,14 +3547,14 @@
 		case Options::kStaticExecutable:
 		case Options::kPreload:
 		case Options::kKextBundle:
-			if ( fVersionLoadCommandForcedOn )
+			if ( fVersionLoadCommandForcedOn && minOS(ld::mac10_7, ld::iOS_4_2) )  // correct versions are unknown
 				fVersionLoadCommand = true;
 			break;
 		case Options::kDynamicExecutable:
 		case Options::kDyld:
 		case Options::kDynamicLibrary:
 		case Options::kDynamicBundle:
-			if ( !fVersionLoadCommandForcedOff )
+			if ( !fVersionLoadCommandForcedOff && minOS(ld::mac10_7, ld::iOS_4_2) )  // don't know correct versions
 				fVersionLoadCommand = true;
 			// <rdar://problem/9945513> for now, don't create version load commands for iOS simulator builds
 			if ( fVersionLoadCommand && (fArchitecture == CPU_TYPE_I386) ) {
@@ -3594,14 +3574,14 @@
 		case Options::kPreload:
 		case Options::kStaticExecutable:
 		case Options::kKextBundle:
-			if ( fFunctionStartsForcedOn )
+			if ( fFunctionStartsForcedOn && minOS(ld::mac10_7, ld::iOS_4_2) )  // guessing at versions
 				fFunctionStartsLoadCommand = true;
 			break;
 		case Options::kDynamicExecutable:
 		case Options::kDyld:
 		case Options::kDynamicLibrary:
 		case Options::kDynamicBundle:
-			if ( !fFunctionStartsForcedOff )
+			if ( !fFunctionStartsForcedOff && minOS(ld::mac10_7, ld::iOS_4_2) )  // guessing at versions
 				fFunctionStartsLoadCommand = true;
 			break;
 	}
@@ -3632,7 +3612,7 @@
 		fNonExecutableHeap = true;
 }
 
-void Options::checkIllegalOptionCombinations()
+void Options::checkInvalidOptionCombinations()
 {
 	// check -undefined setting
 	switch ( fUndefinedTreatment ) {
@@ -4069,15 +4049,6 @@
 
 void Options::checkForClassic(int argc, const char* argv[])
 {
-	// scan options
-	bool archFound = false;
-	bool staticFound = false;
-	bool dtraceFound = false;
-	bool kextFound = false;
-	bool rFound = false;
-	bool creatingMachKernel = false;
-	bool newLinker = false;
-	
 	// build command line buffer in case ld crashes
 	const char* srcRoot = getenv("SRCROOT");
 	if ( srcRoot != NULL ) {
@@ -4096,67 +4067,14 @@
 	}
 
 	for(int i=0; i < argc; ++i) {
-		const char* arg = argv[i];
-		if ( arg[0] == '-' ) {
-			if ( strcmp(arg, "-arch") == 0 ) {
-				parseArch(argv[++i]);
-				archFound = true;
-			}
-			else if ( strcmp(arg, "-static") == 0 ) {
-				staticFound = true;
-			}
-			else if ( strcmp(arg, "-kext") == 0 ) {
-				kextFound = true;
-			}
-			else if ( strcmp(arg, "-dtrace") == 0 ) {
-				dtraceFound = true;
-			}
-			else if ( strcmp(arg, "-r") == 0 ) {
-				rFound = true;
-			}
-			else if ( strcmp(arg, "-new_linker") == 0 ) {
-				newLinker = true;
-			}
-			else if ( strcmp(arg, "-classic_linker") == 0 ) {
+		if ( strcmp(argv[i], "-classic_linker") == 0 ) {
 				// ld_classic does not understand this option, so remove it
 				for(int j=i; j < argc; ++j)
 					argv[j] = argv[j+1];
 				warning("using ld_classic");
 				this->gotoClassicLinker(argc-1, argv);
-			}
-			else if ( strcmp(arg, "-o") == 0 ) {
-				const char* outfile = argv[++i];
-				if ( (outfile != NULL) && (strstr(outfile, "/mach_kernel") != NULL) )
-					creatingMachKernel = true;
-			}
 		}
 	}
-
-	// -dtrace only supported by new linker
-	if( dtraceFound )
-		return;
-
-	if( archFound ) {
-		switch ( fArchitecture ) {
-		case CPU_TYPE_I386:
-		case CPU_TYPE_POWERPC:
-			if ( (staticFound || kextFound) && !newLinker ) {
-				// this environment variable will disable use of ld_classic for -static links
-				if ( getenv("LD_NO_CLASSIC_LINKER_STATIC") == NULL ) {
-					this->gotoClassicLinker(argc, argv);
-				}
-			}
-			break;
-		}
-	}
-	else {
-		// work around for VSPTool
-		if ( staticFound ) {
-			warning("using ld_classic");
-			this->gotoClassicLinker(argc, argv);
-		}
-	}
-
 }
 
 void Options::gotoClassicLinker(int argc, const char* argv[])
--- old/src/ld/Options.h
+++ new/src/ld/Options.h
@@ -329,7 +329,7 @@
 
 
 	void						parse(int argc, const char* argv[]);
-	void						checkIllegalOptionCombinations();
+	void						checkInvalidOptionCombinations();
 	void						buildSearchPaths(int argc, const char* argv[]);
 	void						parseArch(const char* architecture);
 	FileInfo					findLibrary(const char* rootName, bool dylibsOnly=false);
--- old/src/ld/OutputFile.cpp
+++ new/src/ld/OutputFile.cpp
@@ -572,8 +572,8 @@
 			}
 		}
 		
-		if ( log ) fprintf(stderr, "  address=0x%08llX, hidden=%d, alignment=%02d, padBytes=%d, section=%s,%s\n",
-							sect->address, sect->isSectionHidden(), sect->alignment, sect->alignmentPaddingBytes, 
+		if ( log ) fprintf(stderr, "  address=0x%08llX, size=0x%08llX, hidden=%d, alignment=%02d, padBytes=%d, section=%s,%s\n",
+							sect->address, sect->size, sect->isSectionHidden(), sect->alignment, sect->alignmentPaddingBytes, 
 							sect->segmentName(), sect->sectionName());
 		// update running totals
 		if ( !sect->isSectionHidden() || hiddenSectionsOccupyAddressSpace )
@@ -605,6 +605,9 @@
 		if ( hasZeroForFileOffset(sect) ) {
 			// fileoff of zerofill sections is moot, but historically it is set to zero
 			sect->fileOffset = 0;
+
+			// <rdar://problem/10445047> align file offset with address layout
+			fileOffset += sect->alignmentPaddingBytes;
 		}
 		else {
 			// page align file offset at start of each segment
@@ -843,9 +846,9 @@
 		// is encoded in mach-o the same as:
 		//  .long _foo + 0x40000000
 		// so if _foo lays out to 0xC0000100, the first is ok, but the second is not.  
-		if ( (_options.architecture() == CPU_TYPE_ARM) || (_options.architecture() == CPU_TYPE_I386) ) {
-			// Unlikely userland code does funky stuff like this, so warn for them, but not warn for -preload
-			if ( _options.outputKind() != Options::kPreload ) {
+		if ( (_options.architecture() == CPU_TYPE_ARM) || (_options.architecture() == CPU_TYPE_I386)  || (_options.architecture() == CPU_TYPE_POWERPC) ) {
+			// Unlikely userland code does funky stuff like this, so warn for them, but not warn for -preload or -static
+			if ( (_options.outputKind() != Options::kPreload) && (_options.outputKind() != Options::kStaticExecutable) ) {
 				warning("32-bit absolute address out of range (0x%08llX max is 4GB): from %s + 0x%08X (0x%08llX) to 0x%08llX", 
 						displacement, atom->name(), fixup->offsetInAtom, atom->finalAddress(), displacement);
 			}
@@ -936,27 +939,27 @@
 
 void OutputFile::rangeCheckPPCBranch24(int64_t displacement, ld::Internal& state, const ld::Atom* atom, const ld::Fixup* fixup)
 {
-	const int64_t bl_eightMegLimit = 0x00FFFFFF;
-	if ( (displacement > bl_eightMegLimit) || (displacement < (-bl_eightMegLimit)) ) {
+	const int64_t bl_thirtyTwoMegLimit = 0x01FFFFFF;
+	if ( (displacement > bl_thirtyTwoMegLimit) || (displacement < (-bl_thirtyTwoMegLimit-1)) ) {
 		// show layout of final image
 		printSectionLayout(state);
 		
 		const ld::Atom* target;	
-		throwf("bl PPC branch out of range (%lld max is +/-16MB): from %s (0x%08llX) to %s (0x%08llX)", 
+		throwf("bl PPC branch out of range (%lld; max is +/-32MB):  from %s (0x%08llX) to %s (0x%08llX)", 
 				displacement, atom->name(), atom->finalAddress(), referenceTargetAtomName(state, fixup), 
 				addressOf(state, fixup, &target));
 	}
 }
 
 void OutputFile::rangeCheckPPCBranch14(int64_t displacement, ld::Internal& state, const ld::Atom* atom, const ld::Fixup* fixup)
 {
-	const int64_t b_sixtyFourKiloLimit = 0x0000FFFF;
-	if ( (displacement > b_sixtyFourKiloLimit) || (displacement < (-b_sixtyFourKiloLimit)) ) {
+	const int64_t b_thirtyTwoKiloLimit = 0x00007FFF;
+	if ( (displacement > b_thirtyTwoKiloLimit) || (displacement < (-b_thirtyTwoKiloLimit-1)) ) {
 		// show layout of final image
 		printSectionLayout(state);
 		
 		const ld::Atom* target;	
-		throwf("bcc PPC branch out of range (%lld max is +/-64KB): from %s (0x%08llX) to %s (0x%08llX)", 
+		throwf("bcc PPC branch out of range (%lld; max is +/-32KB):  from %s (0x%08llX) to %s (0x%08llX)", 
 				displacement, atom->name(), atom->finalAddress(), referenceTargetAtomName(state, fixup), 
 				addressOf(state, fixup, &target));
 	}
@@ -1012,7 +1015,7 @@
 				thumbTarget = targetIsThumb(state, fit);
 				if ( thumbTarget ) 
 					accumulator |= 1;
-				if ( fit->contentAddendOnly || fit->contentDetlaToAddendOnly )
+				if ( fit->contentAddendOnly || fit->contentDeltaToAddendOnly )
 					accumulator = 0;
 				break;
 			case ld::Fixup::kindSubtractTargetAddress:
@@ -1321,7 +1324,7 @@
 			case ld::Fixup::kindStoreTargetAddressX86PCRel32GOTLoad:
 			case ld::Fixup::kindStoreTargetAddressX86PCRel32TLVLoad:
 				accumulator = addressOf(state, fit, &toTarget);	
-				if ( fit->contentDetlaToAddendOnly )
+				if ( fit->contentDeltaToAddendOnly )
 					accumulator = 0;
 				if ( fit->contentAddendOnly )
 					delta = 0;
@@ -1366,7 +1369,7 @@
 				thumbTarget = targetIsThumb(state, fit);
 				if ( thumbTarget ) 
 					accumulator |= 1;
-				if ( fit->contentDetlaToAddendOnly )
+				if ( fit->contentDeltaToAddendOnly )
 					accumulator = 0;
 				// fall into kindStoreARMBranch24 case
 			case ld::Fixup::kindStoreARMBranch24:
@@ -1390,7 +1393,7 @@
 					newInstruction = opcode | disp;
 				} 
 				else if ( is_b && thumbTarget ) {
-					if ( fit->contentDetlaToAddendOnly )
+					if ( fit->contentDeltaToAddendOnly )
 						newInstruction = (instruction & 0xFF000000) | ((uint32_t)(delta >> 2) & 0x00FFFFFF);
 					else
 						throwf("no pc-rel bx arm instruction. Can't fix up branch to %s in %s",
@@ -1410,7 +1413,7 @@
 				thumbTarget = targetIsThumb(state, fit);
 				if ( thumbTarget ) 
 					accumulator |= 1;
-				if ( fit->contentDetlaToAddendOnly )
+				if ( fit->contentDeltaToAddendOnly )
 					accumulator = 0;
 				// fall into kindStoreThumbBranch22 case
 			case ld::Fixup::kindStoreThumbBranch22:
@@ -1422,7 +1425,7 @@
 				// Since blx cannot have the low bit set, set bit[1] of the target to
 				// bit[1] of the base address, so that the difference is a multiple of
 				// 4 bytes.
-				if ( !thumbTarget && !fit->contentDetlaToAddendOnly ) {
+				if ( !thumbTarget && !fit->contentDeltaToAddendOnly ) {
 				  accumulator &= -3ULL;
 				  accumulator |= ((atom->finalAddress() + fit->offsetInAtom ) & 2LL);
 				}
@@ -1456,7 +1459,7 @@
 					}
 					else if ( is_b ) {
 						instruction = 0x9000F000; // keep b
-						if ( !thumbTarget && !fit->contentDetlaToAddendOnly ) {
+						if ( !thumbTarget && !fit->contentDeltaToAddendOnly ) {
 							throwf("armv7 has no pc-rel bx thumb instruction. Can't fix up branch to %s in %s",
 									referenceTargetAtomName(state, fit), atom->name());
 						}
@@ -1490,7 +1493,7 @@
 					} 
 					else if ( is_b ) {
 						instruction = 0x9000F000; // keep b
-						if ( !thumbTarget && !fit->contentDetlaToAddendOnly ) {
+						if ( !thumbTarget && !fit->contentDeltaToAddendOnly ) {
 							throwf("armv6 has no pc-rel bx thumb instruction. Can't fix up branch to %s in %s",
 									referenceTargetAtomName(state, fit), atom->name());
 						}
@@ -1544,7 +1547,7 @@
 				break;
 			case ld::Fixup::kindStoreTargetAddressPPCBranch24:
 				accumulator = addressOf(state, fit, &toTarget);
-				if ( fit->contentDetlaToAddendOnly )
+				if ( fit->contentDeltaToAddendOnly )
 					accumulator = 0;
 				// fall into kindStorePPCBranch24 case
 			case ld::Fixup::kindStorePPCBranch24:
@@ -1562,6 +1565,7 @@
 {
 	switch ( _options.architecture() ) {
 		case CPU_TYPE_POWERPC:
+		case CPU_TYPE_POWERPC64:
 			for (uint8_t* p=from; p < to; p += 4)
 				OSWriteBigInt32((uint32_t*)p, 0, 0x60000000);
 			break;
@@ -2716,7 +2720,7 @@
 						// check for class refs to lazy loaded dylibs
 						const ld::dylib::File* dylib = dynamic_cast<const ld::dylib::File*>(target->file());
 						if ( (dylib != NULL) && dylib->willBeLazyLoadedDylib() )
-							throwf("illegal class reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
+							throwf("invalid class reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
 					}
 				}
 			}
@@ -2744,10 +2748,10 @@
 		this->pieDisabled = true;
 	}
 	else if ( (target->scope() == ld::Atom::scopeGlobal) && (target->combine() == ld::Atom::combineByName) ) {
-		throwf("illegal text-relocoation (direct reference) to (global,weak) %s in %s from %s in %s", target->name(), target->file()->path(), atom->name(), atom->file()->path());
+		throwf("invalid text-relocoation (direct reference) to (global,weak) %s in %s from %s in %s", target->name(), target->file()->path(), atom->name(), atom->file()->path());
 	}
 	else {
-		throwf("illegal text-relocation to %s in %s from %s in %s", target->name(), target->file()->path(), atom->name(), atom->file()->path());
+		throwf("invalid text-relocation to %s in %s from %s in %s", target->name(), target->file()->path(), atom->name(), atom->file()->path());
 	}
 }
 
@@ -2864,10 +2871,10 @@
 		switch ( target->definition() ) {
 			case ld::Atom::definitionProxy:
 				if ( (dylib != NULL) && dylib->willBeLazyLoadedDylib() )
-					throwf("illegal data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
+					throwf("invalid data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
 				if ( target->contentType() == ld::Atom::typeTLV ) {
 					if ( sect->type() != ld::Section::typeTLVPointers )
-						throwf("illegal data reference in %s to thread local variable %s in dylib %s", 
+						throwf("invalid data reference in %s to thread local variable %s in dylib %s", 
 								atom->name(), target->name(), dylib->path());
 				}
 				if ( inReadOnlySeg ) 
@@ -2968,14 +2975,19 @@
 		assert(minusTarget->definition() != ld::Atom::definitionProxy);
 		assert(target != NULL);
 		assert(target->definition() != ld::Atom::definitionProxy);
-		// make sure target is not global and weak
-		if ( (target->scope() == ld::Atom::scopeGlobal) && (target->combine() == ld::Atom::combineByName)
-				&& (atom->section().type() != ld::Section::typeCFI)
-				&& (atom->section().type() != ld::Section::typeDtraceDOF)
-				&& (atom->section().type() != ld::Section::typeUnwindInfo) 
-				&& (minusTarget != target) ) {
-			// ok for __eh_frame and __uwind_info to use pointer diffs to global weak symbols
-			throwf("bad codegen, pointer diff in %s to global weak symbol %s", atom->name(), target->name());
+		// check whether target of pointer-diff is both global and weak
+		if ( (target->scope() == ld::Atom::scopeGlobal) && (target->combine() == ld::Atom::combineByName)
+														&& (target->definition() == ld::Atom::definitionRegular) ) {
+			if ( (atom->section().type() == ld::Section::typeCFI)
+				|| (atom->section().type() == ld::Section::typeDtraceDOF)
+				|| (atom->section().type() == ld::Section::typeUnwindInfo) ) {
+				// ok for __eh_frame and __uwind_info to use pointer diffs to global weak symbols
+				return;
+			}
+			// Have direct reference to weak-global.  This should be an indirect reference
+			warning("direct access in %s to global weak symbol %s means the weak symbol cannot be overridden at runtime. "
+					"This was likely caused by different translation units being compiled with different visiblity settings.",
+					 atom->name(), target->name());
 		}
 		return;
 	}
@@ -3049,7 +3061,7 @@
 					noteTextReloc(atom, target);
 				const ld::dylib::File* dylib = dynamic_cast<const ld::dylib::File*>(target->file());
 				if ( (dylib != NULL) && dylib->willBeLazyLoadedDylib() )
-					throwf("illegal data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
+					throwf("invalid data reference to %s in lazy loaded dylib %s", target->name(), dylib->path());
 				_externalRelocsAtom->addExternalPointerReloc(relocAddress, target);
 				sect->hasExternalRelocs = true;
 				fixupWithTarget->contentAddendOnly = true;
@@ -3187,11 +3199,11 @@
 	else {
 		// for other archs, content is addend only with (non pc-rel) pointers
 		// pc-rel instructions are funny. If the target is _foo+8 and _foo is 
-		// external, then the pc-rel instruction *evalutates* to the address 8.
+		// external, then the pc-rel instruction *evaluates* to the address 8.
 		if ( targetUsesExternalReloc ) {
 			if ( isPcRelStore(fixupWithStore->kind) ) {
-				fixupWithTarget->contentDetlaToAddendOnly = true;
-				fixupWithStore->contentDetlaToAddendOnly = true;
+				fixupWithTarget->contentDeltaToAddendOnly = true;
+				fixupWithStore->contentDeltaToAddendOnly = true;
 			}
 			else if ( minusTarget == NULL ){
 				fixupWithTarget->contentAddendOnly = true;
--- old/src/ld/parsers/archive_file.cpp
+++ new/src/ld/parsers/archive_file.cpp
@@ -39,7 +39,6 @@
 #include "Architectures.hpp"
 
 #include "macho_relocatable_file.h"
-#include "lto_file.h"
 #include "archive_file.h"
 
 
@@ -91,8 +90,6 @@
 private:
 	static bool										validMachOFile(const uint8_t* fileContent, uint64_t fileLength, 
 																	const mach_o::relocatable::ParserOptions& opts);
-	static bool										validLTOFile(const uint8_t* fileContent, uint64_t fileLength, 
-																	const mach_o::relocatable::ParserOptions& opts);
 	static cpu_type_t								architecture();
 
 	class Entry : ar_hdr
@@ -239,12 +236,6 @@
 	return mach_o::relocatable::isObjectFile(fileContent, fileLength, opts);
 }
 
-template <typename A>
-bool File<A>::validLTOFile(const uint8_t* fileContent, uint64_t fileLength, const mach_o::relocatable::ParserOptions& opts)
-{
-	return lto::isObjectFile(fileContent, fileLength, opts.architecture, opts.subType);
-}
-
 
 
 template <typename A>
@@ -263,7 +254,7 @@
 		if ( (p==start) && ((strcmp(memberName, SYMDEF_SORTED) == 0) || (strcmp(memberName, SYMDEF) == 0)) )
 			continue;
 		// archive is valid if first .o file is valid
-		return (validMachOFile(p->content(), p->contentSize(), opts) || validLTOFile(p->content(), p->contentSize(), opts));
+		return validMachOFile(p->content(), p->contentSize(), opts);
 	}	
 	// empty archive
 	return true;
@@ -363,17 +354,8 @@
 			_instantiatedEntries[member] = state;
 			return _instantiatedEntries[member];
 		}
-		// see if member is llvm bitcode file
-		result = lto::parse(member->content(), member->contentSize(), 
-								mPath, member->modificationTime(), this->ordinal() + memberIndex, 
-								_objOpts.architecture, _objOpts.subType, _logAllFiles);
-		if ( result != NULL ) {
-			MemberState state = {result, false, false};
-			_instantiatedEntries[member] = state;
-			return _instantiatedEntries[member];
-		}
 			
-		throwf("archive member '%s' with length %d is not mach-o or llvm bitcode", memberName, member->contentSize());
+		throwf("archive member '%s' with length %d is not mach-o", memberName, member->contentSize());
 	}
 	catch (const char* msg) {
 		throwf("in %s, %s", memberPath, msg);
--- old/src/ld/parsers/libunwind/AddressSpace.hpp
+++ new/src/ld/parsers/libunwind/AddressSpace.hpp
@@ -37,7 +37,6 @@
 #include <mach-o/getsect.h>
 #include <mach-o/dyld_priv.h>
 #include <mach/i386/thread_status.h>
-#include <Availability.h>
 
 #include "FileAbstraction.hpp"
 #include "libunwind.h"
--- old/src/ld/parsers/macho_dylib_file.cpp
+++ new/src/ld/parsers/macho_dylib_file.cpp
@@ -523,21 +523,15 @@
 
 
 template <>
-void File<x86_64>::addDyldFastStub()
-{
-	addSymbol("dyld_stub_binder", false, false, 0);
-}
-
-template <>
-void File<x86>::addDyldFastStub()
+void File<arm>::addDyldFastStub()
 {
-	addSymbol("dyld_stub_binder", false, false, 0);
+	// do nothing
 }
 
 template <typename A>
 void File<A>::addDyldFastStub()
 {
-	// do nothing
+	addSymbol("dyld_stub_binder", false, false, 0);
 }
 
 template <typename A>
--- old/src/ld/parsers/macho_relocatable_file.cpp
+++ new/src/ld/parsers/macho_relocatable_file.cpp
@@ -174,7 +174,7 @@
 	static const char*				makeSegmentName(const macho_section<typename A::P>* s);
 	static bool						readable(const macho_section<typename A::P>* s);
 	static bool						writable(const macho_section<typename A::P>* s);
-	static bool						exectuable(const macho_section<typename A::P>* s);
+	static bool						executable(const macho_section<typename A::P>* s);
 	static ld::Section::Type		sectionType(const macho_section<typename A::P>* s);
 	
 	File<A>&						_file;
@@ -822,6 +822,8 @@
 const uint8_t* Atom<A>::contentPointer() const
 {
 	const macho_section<P>* sct = this->sect().machoSection();
+	if ( this->_objAddress > sct->addr() + sct->size() )
+		throwf("malformed .o file, symbol has address 0x%0llX which is outside range of its section", (uint64_t)this->_objAddress);
 	uint32_t fileOffset = sct->offset() - sct->addr() + this->_objAddress;
 	return this->sect().file().fileContent()+fileOffset;
 }
@@ -2545,6 +2547,10 @@
 			// backing string in CFStrings should always be direct
 			addFixup(src, cl, firstKind, target.atom);
 		}
+		else if ( (src.atom == target.atom) && (target.atom->combine() == ld::Atom::combineByName) ) {
+			// reference to self should always be direct
+			addFixup(src, cl, firstKind, target.atom);
+		}
 		else {
 			// change direct fixup to by-name fixup
 			addFixup(src, cl, firstKind, false, target.atom->name());
@@ -3573,7 +3579,7 @@
 }
 
 template <typename A>
-bool Section<A>::exectuable(const macho_section<typename A::P>* sect)
+bool Section<A>::executable(const macho_section<typename A::P>* sect)
 {
 	// mach-o .o files do not contain segment permissions
 	// we just know TEXT is special
@@ -5494,12 +5500,12 @@
 			parser.addFixups(src, kind, target);
 			return false;
 			break;
-		case GENERIC_RLEOC_TLV:
+		case GENERIC_RELOC_TLV:
 			{
 				if ( !reloc->r_extern() )
-					throw "r_extern=0 and r_type=GENERIC_RLEOC_TLV not supported";
+					throw "r_extern=0 and r_type=GENERIC_RELOC_TLV not supported";
 				if ( reloc->r_length() != 2 )
-					throw "r_length!=2 and r_type=GENERIC_RLEOC_TLV not supported";
+					throw "r_length!=2 and r_type=GENERIC_RELOC_TLV not supported";
 				const macho_nlist<P>& sym = parser.symbolFromIndex(reloc->r_symbolnum());
 				// use direct reference for local symbols
 				if ( ((sym.n_type() & N_TYPE) == N_SECT) && ((sym.n_type() & N_EXT) == 0) ) {
@@ -5815,7 +5821,7 @@
 				// this is from -mlong-branch codegen.  We ignore the jump island and make reference to the real target
 				if ( nextReloc->r_type() != PPC_RELOC_PAIR ) 
 					throw "PPC_RELOC_JBSR missing following pair";
-				if ( !parser._hasLongBranchStubs )
+				if ( !parser._hasLongBranchStubs && !strstr(parser._path, "/usr/lib/crt1.o") )
 					warning("object file compiled with -mlong-branch which is no longer needed. "
 							"To remove this warning, recompile without -mlong-branch: %s", parser._path);
 				parser._hasLongBranchStubs = true;
--- old/src/ld/passes/objc.cpp
+++ new/src/ld/passes/objc.cpp
@@ -813,7 +813,7 @@
 					continue;
 				}
 				assert(categoryAtom != NULL);
-				assert(categoryAtom->size() == Category<A>::size());
+				assert(categoryAtom->size() >= Category<A>::size());
 				// ignore categories also in __objc_nlcatlist
 				if ( nlcatListAtoms.count(categoryAtom) != 0 )
 					continue;
--- old/src/ld/passes/order_file.cpp
+++ new/src/ld/passes/order_file.cpp
@@ -239,6 +239,7 @@
 {
 	// atoms in only some sections can have order_file applied
 	switch ( sect->type() ) {
+		case ld::Section::typeInitializerPointers:
 		case ld::Section::typeUnclassified:
 		case ld::Section::typeCode:
 		case ld::Section::typeZeroFill:
--- old/src/ld/passes/stubs/stubs.cpp
+++ new/src/ld/passes/stubs/stubs.cpp
@@ -72,7 +72,6 @@
 
 	const Options&				_options;
 	const cpu_type_t			_architecture;
-	const bool					_lazyDylibsInUuse;
 	const bool					_compressedLINKEDIT;
 	const bool					_prebind;
 	const bool					_mightBeInSharedRegion;
@@ -99,7 +98,6 @@
 		compressedFastBinderPointer(NULL),
 		_options(opts),
 		_architecture(opts.architecture()),
-		_lazyDylibsInUuse(opts.usingLazyDylibLinking()),
 		_compressedLINKEDIT(opts.makeCompressedDyldInfo()),
 		_prebind(opts.prebind()),
 		_mightBeInSharedRegion(opts.sharedRegionEligible()), 
@@ -226,7 +224,12 @@
 		for (std::vector<const ld::Atom*>::iterator ait=sect->atoms.begin();  ait != sect->atoms.end(); ++ait) {
 			const ld::Atom* atom = *ait;
 			if ( atom->contentType() == ld::Atom::typeResolver ) 
-				throwf("resolver function '%s' not supported in type of output", atom->name());
+			{
+				if ( _options.macosxVersionMin() < ld::mac10_6 )
+					throwf("resolver functions (%s) can only be used when targeting Mac OS X 10.6 or later", atom->name());
+				else
+					throwf("resolver function '%s' not supported in type of output", atom->name());
+			}
 		}
 	}
 }
@@ -236,6 +239,8 @@
 	switch ( _options.outputKind() ) {
 		case Options::kObjectFile:
 			// these kinds don't use stubs and can have resolver functions
+			if ( _options.macosxVersionMin() < ld::mac10_6 )   // ...unless OS predates 'em
+				verifyNoResolverFunctions(state);
 			return;
 		case Options::kKextBundle:
 		case Options::kStaticExecutable:
@@ -246,6 +251,8 @@
 			return;
 		case Options::kDynamicLibrary:
 			// uses stubs and can have resolver functions
+			if ( _options.macosxVersionMin() < ld::mac10_6 )
+				verifyNoResolverFunctions(state);
 			break;
 		case Options::kDynamicExecutable:
 		case Options::kDynamicBundle:
@@ -304,7 +311,7 @@
 				if ( _options.outputKind() != Options::kDynamicLibrary ) 
 					throwf("resolver functions (%s) can only be used in dylibs", atom->name());
 				if ( !_options.makeCompressedDyldInfo() ) {
-					if ( _options.architecture() == CPU_TYPE_POWERPC )
+					if ( (_options.architecture() == CPU_TYPE_POWERPC) || (_options.architecture() == CPU_TYPE_POWERPC64) )
 						throwf("resolver functions (%s) not supported for PowerPC", atom->name());
 					else if ( _options.architecture() == CPU_TYPE_ARM )
 						throwf("resolver functions (%s) can only be used when targeting iOS 4.2 or later", atom->name());
--- old/src/ld/passes/tlvp.cpp
+++ new/src/ld/passes/tlvp.cpp
@@ -199,7 +199,7 @@
 		if ( pos == variableToPointerMap.end() ) {
 			if (log) fprintf(stderr, "make TLV pointer for %s\n", it->first->name());
 			if ( it->first->contentType() != ld::Atom::typeTLV )
-				throwf("illegal thread local variable reference to regular symbol %s", it->first->name());
+				throwf("invalid thread local variable reference to regular symbol %s", it->first->name());
 			TLVEntryAtom* tlvp = new TLVEntryAtom(internal, it->first, it->second);
 			variableToPointerMap[it->first] = tlvp;
 		}
--- old/src/ld/Resolver.cpp
+++ new/src/ld/Resolver.cpp
@@ -58,7 +58,6 @@
 #include "InputFiles.h"
 #include "SymbolTable.h"
 #include "Resolver.h"
-#include "parsers/lto_file.h"
 
 
 namespace ld {
@@ -534,14 +533,6 @@
 	// convert references by-name or by-content to by-slot
 	this->convertReferencesToIndirect(atom);
 	
-	// remember if any atoms are proxies that require LTO
-	if ( atom.contentType() == ld::Atom::typeLTOtemporary )
-		_haveLLVMObjs = true;
-	
-	// if we've already partitioned into final sections, and lto needs a symbol very late, add it
-	if ( _addToFinalSection ) 
-		_internal.addAtom(atom);
-	
 	if ( _options.deadCodeStrip() ) {
 		// add to set of dead-strip-roots, all symbols that the compiler marks as don't strip
 		if ( atom.dontDeadStrip() )
@@ -911,13 +902,7 @@
 		}
 	}
 	
-	if ( _haveLLVMObjs ) {
-		// <rdar://problem/9777977> don't remove combinable atoms, they may come back in lto output
-		_atoms.erase(std::remove_if(_atoms.begin(), _atoms.end(), NotLiveLTO()), _atoms.end());
-	}
-	else {
-		_atoms.erase(std::remove_if(_atoms.begin(), _atoms.end(), NotLive()), _atoms.end());
-	}
+	_atoms.erase(std::remove_if(_atoms.begin(), _atoms.end(), NotLive()), _atoms.end());  // don't waste effort on LTO
 }
 
 
@@ -1056,10 +1041,6 @@
 
 void Resolver::checkUndefines(bool force)
 {
-	// when using LTO, undefines are checked after bitcode is optimized
-	if ( _haveLLVMObjs && !force )
-		return;
-
 	// error out on any remaining undefines
 	bool doPrint = true;
 	bool doError = true;
@@ -1078,8 +1059,7 @@
 			break;
 	}
 	std::vector<const char*> unresolvableUndefines;
-	// <rdar://problem/10052396> LTO many have eliminated need for some undefines
-	if ( _options.deadCodeStrip() || _haveLLVMObjs ) 
+	if ( _options.deadCodeStrip() ) 
 		this->liveUndefines(unresolvableUndefines);
 	else	
 		_symbolTable.undefines(unresolvableUndefines);
@@ -1272,7 +1252,7 @@
 	}
 	
 	_internal.compressedFastBinderProxy = NULL;
-	if ( needsStubHelper && _options.makeCompressedDyldInfo() ) { 
+	if ( needsStubHelper ) { 
 		// "dyld_stub_binder" comes from libSystem.dylib so will need to manually resolve
 		if ( !_symbolTable.hasName("dyld_stub_binder") ) {
 			_inputFiles.searchLibraries("dyld_stub_binder", true, false, false, *this);
@@ -1314,110 +1294,6 @@
 	_atoms.erase(std::remove_if(_atoms.begin(), _atoms.end(), AtomCoalescedAway()), _atoms.end());
 }
 
-void Resolver::linkTimeOptimize()
-{
-	// only do work here if some llvm obj files where loaded
-	if ( ! _haveLLVMObjs )
-		return;
-	
-	// run LLVM lto code-gen
-	lto::OptimizeOptions optOpt;
-	optOpt.outputFilePath				= _options.outputFilePath();
-	optOpt.tmpObjectFilePath			= _options.tempLtoObjectPath();
-	optOpt.allGlobalsAReDeadStripRoots	= _options.allGlobalsAreDeadStripRoots();
-	optOpt.verbose						= _options.verbose();
-	optOpt.saveTemps					= _options.saveTempFiles();
-	optOpt.pie							= _options.positionIndependentExecutable();
-	optOpt.mainExecutable				= _options.linkingMainExecutable();;
-	optOpt.staticExecutable 			= (_options.outputKind() == Options::kStaticExecutable);
-	optOpt.relocatable					= (_options.outputKind() == Options::kObjectFile);
-	optOpt.allowTextRelocs				= _options.allowTextRelocs();
-	optOpt.linkerDeadStripping			= _options.deadCodeStrip();
-	optOpt.arch							= _options.architecture();
-	optOpt.llvmOptions					= &_options.llvmOptions();
-	
-	std::vector<const ld::Atom*>		newAtoms;
-	std::vector<const char*>			additionalUndefines; 
-	if ( ! lto::optimize(_atoms, _internal, _inputFiles.nextInputOrdinal(), optOpt, *this, newAtoms, additionalUndefines) )
-		return; // if nothing done
-		
-	
-	// add all newly created atoms to _atoms and update symbol table
-	for(std::vector<const ld::Atom*>::iterator it = newAtoms.begin(); it != newAtoms.end(); ++it)
-		this->doAtom(**it);
-		
-	// some atoms might have been optimized way (marked coalesced), remove them
-	this->removeCoalescedAwayAtoms();
-	
-	// add new atoms into their final section
-	for (std::vector<const ld::Atom*>::iterator it = newAtoms.begin(); it != newAtoms.end(); ++it) {
-		_internal.addAtom(**it);
-	}
-
-	// remove temp lto section and move all of its atoms to their final section
-	ld::Internal::FinalSection* tempLTOsection = NULL;
-	for (std::vector<ld::Internal::FinalSection*>::iterator sit=_internal.sections.begin(); sit != _internal.sections.end(); ++sit) {
-		ld::Internal::FinalSection* sect = *sit;
-		if ( sect->type() == ld::Section::typeTempLTO ) {
-			tempLTOsection = sect;
-			// remove temp lto section from final image
-			_internal.sections.erase(sit);
-			break;
-		}
-	}
-	// lto atoms now have proper section info, so add to final section
-	if ( tempLTOsection != NULL ) {
-		for (std::vector<const ld::Atom*>::iterator ait=tempLTOsection->atoms.begin(); ait != tempLTOsection->atoms.end(); ++ait) {
-			const ld::Atom* atom = *ait;
-			if ( ! atom->coalescedAway() ) {
-				this->convertReferencesToIndirect(*atom);
-				_internal.addAtom(*atom);
-			}
-		}
-	}
-	
-	// resolve new undefines (e.g calls to _malloc and _memcpy that llvm compiler conjures up)
-	_addToFinalSection = true;
-	for(std::vector<const char*>::iterator uit = additionalUndefines.begin(); uit != additionalUndefines.end(); ++uit) {
-		const char *targetName = *uit;
-		// these symbols may or may not already be in linker's symbol table
-		if ( ! _symbolTable.hasName(targetName) ) {
-			_inputFiles.searchLibraries(targetName, true, true, false, *this);
-		}
-	}
-	_addToFinalSection = false;
-
-	// if -dead_strip on command line
-	if ( _options.deadCodeStrip() ) {
-		// clear liveness bit
-		for (std::vector<const ld::Atom*>::const_iterator it=_atoms.begin(); it != _atoms.end(); ++it) {
-			(const_cast<ld::Atom*>(*it))->setLive((*it)->dontDeadStrip());
-		}
-		// and re-compute dead code
-		this->deadStripOptimize();
-
-		// remove newly dead atoms from each section
-		for (std::vector<ld::Internal::FinalSection*>::iterator sit=_internal.sections.begin(); sit != _internal.sections.end(); ++sit) {
-			ld::Internal::FinalSection* sect = *sit;
-			sect->atoms.erase(std::remove_if(sect->atoms.begin(), sect->atoms.end(), NotLive()), sect->atoms.end());
-		}
-	}
-	
-	if ( _options.outputKind() == Options::kObjectFile ) {
-		// if -r mode, add proxies for new undefines (e.g. ___stack_chk_fail)
-		_addToFinalSection = true;
-		this->resolveUndefines();
-		_addToFinalSection = false;
-	}
-	else {
-		// last chance to check for undefines
-		this->checkUndefines(true);
-
-		// check new code does not override some dylib
-		this->checkDylibSymbolCollisions();
-	}
-}
-
 
 void Resolver::resolve()
 {
@@ -1431,7 +1307,6 @@
 	this->checkDylibSymbolCollisions();
 	this->removeCoalescedAwayAtoms();
 	this->fillInInternalState();
-	this->linkTimeOptimize();
 }
 
 
--- old/src/other/dyldinfo.cpp
+++ new/src/other/dyldinfo.cpp
@@ -347,6 +347,9 @@
 			case CPU_TYPE_POWERPC:			
 				printf("for arch ppc:\n");
 				break;
+			case CPU_TYPE_POWERPC64:	// don't omit this
+				printf("for arch ppc64:\n");
+				break;
 			case CPU_TYPE_ARM:
 				for (const ARMSubType* t=ARMSubTypes; t->subTypeName != NULL; ++t) {
 					if ( (cpu_subtype_t)fHeader->cpusubtype() == t->subType) {
--- old/src/other/machochecker.cpp
+++ new/src/other/machochecker.cpp
@@ -121,12 +121,16 @@
 	void										checkLoadCommands();
 	void										checkSection(const macho_segment_command<P>* segCmd, const macho_section<P>* sect);
 	uint8_t										loadCommandSizeMask();
+	uint32_t									threadStateFlavour();
+	uint32_t									stackPointerReg();
+	uint32_t									programCounterReg();
+	pint_t										threadCommand_threadStateRegister(const macho_thread_command<P>* threadInfo, const uint32_t register_index);
 	void										checkSymbolTable();
 	void										checkInitTerms();
 	void										checkIndirectSymbolTable();
 	void										checkRelocations();
-	void										checkExternalReloation(const macho_relocation_info<P>* reloc);
-	void										checkLocalReloation(const macho_relocation_info<P>* reloc);
+	void										checkExternalRelocation(const macho_relocation_info<P>* reloc);
+	void										checkLocalRelocation(const macho_relocation_info<P>* reloc);
 	pint_t										relocBase();
 	bool										addressInWritableSegment(pint_t address);
 	bool										hasTextRelocInRange(pint_t start, pint_t end);
@@ -261,68 +265,63 @@
 template <> uint8_t MachOChecker<arm>::loadCommandSizeMask()	{ return 0x03; }
 
 
-template <>
-ppc::P::uint_t MachOChecker<ppc>::getInitialStackPointer(const macho_thread_command<ppc::P>* threadInfo)
-{
-	return threadInfo->thread_register(3);
-}
-
-template <>
-ppc64::P::uint_t MachOChecker<ppc64>::getInitialStackPointer(const macho_thread_command<ppc64::P>* threadInfo)
-{
-	return threadInfo->thread_register(3);
-}
-
-template <>
-x86::P::uint_t MachOChecker<x86>::getInitialStackPointer(const macho_thread_command<x86::P>* threadInfo)
-{
-	return threadInfo->thread_register(7);
-}
-
-template <>
-x86_64::P::uint_t MachOChecker<x86_64>::getInitialStackPointer(const macho_thread_command<x86_64::P>* threadInfo)
-{
-	return threadInfo->thread_register(7);
-}
-
-template <>
-arm::P::uint_t MachOChecker<arm>::getInitialStackPointer(const macho_thread_command<arm::P>* threadInfo)
-{
-	return threadInfo->thread_register(13);
-}
-
-
-
-
-
-template <>
-ppc::P::uint_t MachOChecker<ppc>::getEntryPoint(const macho_thread_command<ppc::P>* threadInfo)
-{
-	return threadInfo->thread_register(0);
-}
-
-template <>
-ppc64::P::uint_t MachOChecker<ppc64>::getEntryPoint(const macho_thread_command<ppc64::P>* threadInfo)
-{
-	return threadInfo->thread_register(0);
-}
-
-template <>
-x86::P::uint_t MachOChecker<x86>::getEntryPoint(const macho_thread_command<x86::P>* threadInfo)
-{
-	return threadInfo->thread_register(10);
-}
-
-template <>
-x86_64::P::uint_t MachOChecker<x86_64>::getEntryPoint(const macho_thread_command<x86_64::P>* threadInfo)
-{
-	return threadInfo->thread_register(16);
-}
-
-template <>
-arm::P::uint_t MachOChecker<arm>::getEntryPoint(const macho_thread_command<arm::P>* threadInfo)
-{
-	return threadInfo->thread_register(15);
+template <> uint32_t MachOChecker<ppc>::threadStateFlavour()	{ return 1; }  // PPC_THREAD_STATE
+template <> uint32_t MachOChecker<ppc64>::threadStateFlavour()	{ return 5; }  // PPC_THREAD_STATE64
+template <> uint32_t MachOChecker<x86>::threadStateFlavour()	{ return 1; }  // x86_THREAD_STATE32
+template <> uint32_t MachOChecker<x86_64>::threadStateFlavour()	{ return 4; }  // x86_THREAD_STATE64
+template <> uint32_t MachOChecker<arm>::threadStateFlavour()	{ return 1; }  // ARM_THREAD_STATE
+
+
+template <typename A>
+typename A::P::uint_t MachOChecker<A>::threadCommand_threadStateRegister(const macho_thread_command<P>* threadInfo, const uint32_t register_index) {
+		uint32_t*	word32_array;
+		uint32_t	word32_index;
+		uint32_t	max_word32_index;
+	const uint32_t	target_flavour = MachOChecker<A>::threadStateFlavour();
+		uint32_t	current_flavour = threadInfo->flavor();
+		pint_t*		register_block = NULL;
+	if (current_flavour == target_flavour) {
+		return threadInfo->thread_register(register_index);
+	}
+	// At this point we need to start scanning through a variable-length array of variable-length arrays
+	word32_array = threadInfo->raw_array();
+	word32_index = threadInfo->count() + 2;  // this puts the offset at the start of the next data structure
+	max_word32_index = (threadInfo->cmdsize() - 8) >> 2;  // “index” of the next load command -- stay out!
+	current_flavour = E::get32(word32_array[word32_index++]);
+	while (word32_index < max_word32_index && current_flavour != target_flavour) {
+		if (word32_index >= max_word32_index)
+			return NULL;
+		word32_index += (E::get32(word32_array[word32_index]) + 1);
+		current_flavour = E::get32(word32_array[word32_index++]);
+	}
+	register_block = (pint_t*) &(word32_array[++word32_index]);
+	return P::getP(register_block[register_index]);
+}
+
+
+template <> uint32_t MachOChecker<ppc>::stackPointerReg()		{ return  3; }
+template <> uint32_t MachOChecker<ppc64>::stackPointerReg()		{ return  3; }
+template <> uint32_t MachOChecker<x86>::stackPointerReg()		{ return  7; }
+template <> uint32_t MachOChecker<x86_64>::stackPointerReg()	{ return  7; }
+template <> uint32_t MachOChecker<arm>::stackPointerReg()		{ return 13; }
+
+
+template <typename A>
+typename A::P::uint_t MachOChecker<A>::getInitialStackPointer(const macho_thread_command<P>* threadInfo) {
+	return MachOChecker<A>::threadCommand_threadStateRegister(threadInfo, MachOChecker<A>::stackPointerReg());
+}
+
+
+template <> uint32_t MachOChecker<ppc>::programCounterReg()		{ return  0; }
+template <> uint32_t MachOChecker<ppc64>::programCounterReg()	{ return  0; }
+template <> uint32_t MachOChecker<x86>::programCounterReg()		{ return 10; }
+template <> uint32_t MachOChecker<x86_64>::programCounterReg()	{ return 16; }
+template <> uint32_t MachOChecker<arm>::programCounterReg()		{ return 15; }
+
+
+template <typename A>
+typename A::P::uint_t MachOChecker<A>::getEntryPoint(const macho_thread_command<P>* threadInfo) {
+	return MachOChecker<A>::threadCommand_threadStateRegister(threadInfo, MachOChecker<A>::programCounterReg());
 }
 
 
@@ -570,9 +569,9 @@
 		pint_t initialSP = getInitialStackPointer(threadInfo);
 		if ( initialSP != 0 ) {
 			if ( stackSegment == NULL )
-				throw "LC_UNIXTHREAD specifics custom initial stack pointer, but no __UNIXSTACK segment";
+				throw "LC_UNIXTHREAD specifies a custom initial stack pointer, but there is no __UNIXSTACK segment";
 			if ( (initialSP < stackSegment->vmaddr()) || (initialSP > (stackSegment->vmaddr()+stackSegment->vmsize())) )
-				throw "LC_UNIXTHREAD specifics custom initial stack pointer which does not point into __UNIXSTACK segment";
+				throw "LC_UNIXTHREAD specifies a custom initial stack pointer which does not point into the __UNIXSTACK segment";
 		}
 	}
 	
@@ -975,7 +974,7 @@
 
 
 template <>
-void MachOChecker<ppc>::checkExternalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<ppc>::checkExternalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 2 ) 
 		throw "bad external relocation length";
@@ -991,7 +990,7 @@
 }
 
 template <>
-void MachOChecker<ppc64>::checkExternalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<ppc64>::checkExternalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 3 ) 
 		throw "bad external relocation length";
@@ -1007,7 +1006,7 @@
 }
 
 template <>
-void MachOChecker<x86>::checkExternalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<x86>::checkExternalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 2 ) 
 		throw "bad external relocation length";
@@ -1024,7 +1023,7 @@
 
 
 template <>
-void MachOChecker<x86_64>::checkExternalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<x86_64>::checkExternalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 3 ) 
 		throw "bad external relocation length";
@@ -1040,7 +1039,7 @@
 }
 
 template <>
-void MachOChecker<arm>::checkExternalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<arm>::checkExternalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 2 ) 
 		throw "bad external relocation length";
@@ -1057,7 +1056,7 @@
 
 
 template <>
-void MachOChecker<ppc>::checkLocalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<ppc>::checkLocalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_address() & R_SCATTERED ) {
 		// scattered
@@ -1077,7 +1076,7 @@
 
 
 template <>
-void MachOChecker<ppc64>::checkLocalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<ppc64>::checkLocalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 3 ) 
 		throw "bad local relocation length";
@@ -1092,13 +1091,13 @@
 }
 
 template <>
-void MachOChecker<x86>::checkLocalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<x86>::checkLocalRelocation(const macho_relocation_info<P>* reloc)
 {
 	// FIX
 }
 
 template <>
-void MachOChecker<x86_64>::checkLocalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<x86_64>::checkLocalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_length() != 3 ) 
 		throw "bad local relocation length";
@@ -1113,7 +1112,7 @@
 }
 
 template <>
-void MachOChecker<arm>::checkLocalReloation(const macho_relocation_info<P>* reloc)
+void MachOChecker<arm>::checkLocalRelocation(const macho_relocation_info<P>* reloc)
 {
 	if ( reloc->r_address() & R_SCATTERED ) {
 		// scattered
@@ -1142,7 +1141,7 @@
 	uint32_t lastSymbolIndex = 0xFFFFFFFF;
 	const macho_relocation_info<P>* const externRelocsEnd = &fExternalRelocations[fExternalRelocationsCount];
 	for (const macho_relocation_info<P>* reloc = fExternalRelocations; reloc < externRelocsEnd; ++reloc) {
-		this->checkExternalReloation(reloc);
+		this->checkExternalRelocation(reloc);
 		if ( reloc->r_symbolnum() != lastSymbolIndex ) {
 			if ( previouslySeenSymbolIndexes.count(reloc->r_symbolnum()) != 0 )
 				throw "external relocations not sorted";
@@ -1153,7 +1152,7 @@
 	
 	const macho_relocation_info<P>* const localRelocsEnd = &fLocalRelocations[fLocalRelocationsCount];
 	for (const macho_relocation_info<P>* reloc = fLocalRelocations; reloc < localRelocsEnd; ++reloc) {
-		this->checkLocalReloation(reloc);
+		this->checkLocalRelocation(reloc);
 	}
 	
 	// verify any section with S_ATTR_LOC_RELOC bits set actually has text relocs
--- old/src/other/ObjectDump.cpp
+++ new/src/other/ObjectDump.cpp
@@ -33,7 +33,6 @@
 
 #include "MachOFileAbstraction.hpp"
 #include "parsers/macho_relocatable_file.h"
-#include "parsers/lto_file.h"
 
 static bool			sDumpContent= true;
 static bool			sDumpStabs	= false;
@@ -1138,23 +1137,14 @@
 	objOpts.subType				= sPreferredSubArch;
 #if 1
 	if ( ! foundFatSlice ) {
-		cpu_type_t archOfObj;
-		cpu_subtype_t subArchOfObj;
-		if ( mach_o::relocatable::isObjectFile(p, &archOfObj, &subArchOfObj) ) {
-			objOpts.architecture = archOfObj;
-			objOpts.subType = subArchOfObj;
-		}
+		objOpts.architecture = OSSwapBigToHostInt32((uint32_t)mh->cputype);
+		objOpts.subType = OSSwapBigToHostInt32((uint32_t)mh->cpusubtype);
 	}
 
 	ld::relocatable::File* objResult = mach_o::relocatable::parse(p, fileLen, path, stat_buf.st_mtime, 0, objOpts);
 	if ( objResult != NULL )
 		return objResult;
 
-	// see if it is an llvm object file
-	objResult = lto::parse(p, fileLen, path, stat_buf.st_mtime, 0, sPreferredArch, sPreferredSubArch, false);
-	if ( objResult != NULL ) 
-		return objResult;
-
 	throwf("not a mach-o object file: %s", path);
 #else
 	// for peformance testing
--- old/src/other/rebase.cpp
+++ new/src/other/rebase.cpp
@@ -29,6 +29,7 @@
 #include <limits.h>
 #include <stdarg.h>
 #include <stdio.h>
+#include <stdlib.h>
 #include <fcntl.h>
 #include <errno.h>
 #include <unistd.h>
--- old/unit-tests/bin/result-filter.pl
+++ new/unit-tests/bin/result-filter.pl
@@ -134,7 +134,7 @@
     }
     if(!$seen_result)
     {
-	printf "%-40s AMBIGIOUS missing [X]PASS/[X]FAIL\n", $test_name;
+	printf "%-40s AMBIGUOUS missing [X]PASS/[X]FAIL\n", $test_name;
 	$total_count++;
 	#my $line1;
 	#foreach $line1 (@{$$tbl{stdout}})
--- old/unit-tests/include/common.makefile
+++ new/unit-tests/include/common.makefile
@@ -8,8 +8,6 @@
 # set default to be all
 VALID_ARCHS ?= "i386 x86_64 armv6"
 
-IOS_SDK = /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.Internal.sdk
-
 MYDIR=$(shell cd ../../bin;pwd)
 LD			= ld
 OBJECTDUMP	= ObjectDump
@@ -52,10 +50,6 @@
 export COMPILER_PATH
 export GCC_EXEC_PREFIX=garbage
 
-ifeq ($(ARCH),ppc)
-	SDKExtra = -isysroot /Developer/SDKs/MacOSX10.6.sdk
-endif
-
 CC		 = cc -arch ${ARCH} ${SDKExtra}
 CCFLAGS = -Wall 
 ASMFLAGS =
--- old/unit-tests/test-cases/allow_heap_execute/Makefile
+++ new/unit-tests/test-cases/allow_heap_execute/Makefile
@@ -20,6 +20,8 @@
 run-ppc:
 	${PASS_IFF} true
 
+run-ppc64:
+	${PASS_IFF} true
 
 run-i386:
 	# Test with the flag
--- old/unit-tests/test-cases/archive-basic/Makefile
+++ new/unit-tests/test-cases/archive-basic/Makefile
@@ -38,9 +38,9 @@
 	libtool -static foo-${ARCH}.o  bar-${ARCH}.o -o libfoobar-${ARCH}.a
 	${CC} ${CCFLAGS} main.c -lfoobar-${ARCH} -L. -o main-${ARCH} 
 	${FAIL_IF_BAD_MACHO} main-${ARCH}
-	nm main-${ARCH} | grep "_bar" | ${PASS_IFF_EMPTY}
+	nm main-${ARCH} | grep "_bar" | ${FAIL_IF_STDIN}
 	${CC} ${CCFLAGS} main.c -Wl,-force_load,libfoobar-${ARCH}.a -o main-${ARCH} 
-	${FAIL_IF_BAD_MACHO} main-${ARCH}
+	${PASS_IFF_GOOD_MACHO} main-${ARCH}
 
 clean:
 	rm -rf main-* *.o *.a
--- old/unit-tests/bin/result-filter.pl
+++ new/unit-tests/bin/result-filter.pl
@@ -27,6 +27,7 @@
 	if(length($entry))
 	{
 	    &process_entry($root, $entry);
+		print "\n";
 	    $entry = '';
 	}
 	$entry .= $_;
@@ -40,6 +41,7 @@
 if(length($entry))
 {
     &process_entry($root, $entry);
+    print "\n";
 }
 
 # show totals
@@ -93,15 +95,15 @@
     {
 	printf "%-40s FAIL Makefile failure\n", $test_name;
 	$total_count++;
-	#my $line1;
-	#foreach $line1 (@{$$tbl{stdout}})
-	#{
-	#    printf "stdout: %s\n", $line1;
-	#}
-	#foreach $line1 (@{$$tbl{stderr}})
-	#{
-	#    printf "stderr: %s\n", $line1;
-	#}
+	my $line1;
+	foreach $line1 (@{$$tbl{stdout}})
+	{
+		printf "stdout: %s\n", $line1;
+	}
+	foreach $line1 (@{$$tbl{stderr}})
+	{
+		printf "stderr: %s\n", $line1;
+	}
 	return;
     }
 
@@ -106,10 +108,18 @@
     }
 
     #if there was any output to stderr, mark this as a failure
-    foreach $line (@{$$tbl{stderr}})
+    if (scalar @{$$tbl{stderr}} > 0)
     {
-	printf "%-40s FAIL spurious stderr failure: %s\n", $test_name, $line;
+	printf "%-40s FAIL output to stderr detected\n", $test_name;
 	$total_count++;
+	foreach $line (@{$$tbl{stdout}})
+	{
+		printf "stdout: %s\n", $line;
+	}
+	foreach $line (@{$$tbl{stderr}})
+	{
+		printf "stderr: %s\n", $line;
+	}
 	return;
     }
 
@@ -124,26 +134,22 @@
 	    {
 		$pass_count++;
 	    }
-	    else
-	    {
-		# only print failure lines
 		printf "%-40s %s\n", $test_name, $line;
-	    }
 	    $seen_result = 1;
 	}
     }
     if(!$seen_result)
     {
 	printf "%-40s AMBIGUOUS missing [X]PASS/[X]FAIL\n", $test_name;
 	$total_count++;
-	#my $line1;
-	#foreach $line1 (@{$$tbl{stdout}})
-	#{
-	#    printf "stdout: %s\n", $line1;
-	#}
-	#foreach $line1 (@{$$tbl{stderr}})
-	#{
-	#    printf "stderr: %s\n", $line1;
-	#}
+	my $line1;
+	foreach $line1 (@{$$tbl{stdout}})
+	{
+		printf "stdout: %s\n", $line1;
+	}
+	foreach $line1 (@{$$tbl{stderr}})
+	{
+		printf "stderr: %s\n", $line1;
+	}
     }
 }
--- old/unit-tests/include/common.makefile
+++ new/unit-tests/include/common.makefile
@@ -51,14 +51,14 @@
 export GCC_EXEC_PREFIX=garbage
 
 CC		 = cc -arch ${ARCH} ${SDKExtra}
-CCFLAGS = -Wall 
+CCFLAGS = -v -Wall
 ASMFLAGS =
 VERSION_NEW_LINKEDIT = -mmacosx-version-min=10.6
 VERSION_OLD_LINKEDIT = -mmacosx-version-min=10.4
 LD_NEW_LINKEDIT = -macosx_version_min 10.6
 
 CXX		  = c++ -arch ${ARCH} ${SDKExtra}
-CXXFLAGS = -Wall
+CXXFLAGS = -v -Wall
 
 ifeq ($(ARCH),armv6)
   LDFLAGS := -syslibroot $(IOS_SDK)
@@ -137,3 +137,14 @@
 PASS_IFF_GOOD_MACHO	= ${PASS_IFF} ${MACHOCHECK}
 FAIL_IF_BAD_MACHO	= ${FAIL_IF_ERROR} ${MACHOCHECK}
 FAIL_IF_BAD_OBJ		= ${FAIL_IF_ERROR} ${OBJECTDUMP} >/dev/null
+
+ifdef RUNNING_ALL_TESTS
+  LISTFILE = all-tests-env-$(ARCH).list
+else
+  LISTFILE = test-env-$(ARCH).list
+endif
+
+all : envlist
+
+envlist :
+	@declare -p > $(LISTFILE)
--- old/unit-tests/run-all-unit-tests
+++ new/unit-tests/run-all-unit-tests
@@ -7,6 +7,7 @@
 
 export DYLD_FALLBACK_LIBRARY_PATH=${DYLD_FALLBACK_LIBRARY_PATH}:/Developer/usr/lib
 export MACOSX_DEPLOYMENT_TARGET=10.7
+export RUNNING_ALL_TESTS='true'
 # cd into test-cases directory
 cd `echo "$0" | sed 's/run-all-unit-tests/test-cases/'`
 
