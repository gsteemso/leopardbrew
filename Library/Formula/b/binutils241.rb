class Binutils241 < Formula
  # The only sub‐package applicable to Mac OS (Darwin) is the actual binutils.
  # gas, ld, gold, and all of the other user‐visible sub‐packages are unable to
  # handle Mach-O binaries.
  desc 'GNU Binary Utilities for native development (legacy version not using Thread‐Local Storage)'
  homepage 'https://www.gnu.org/software/binutils/binutils.html'
  url 'https://ftpmirror.gnu.org/binutils/binutils-2.41.tar.lz'
  mirror 'https://sourceware.org/pub/binutils/releases/binutils-2.41.tar.lz'
  sha256 'eab3444055882ed5eb04e2743d03f0c0e1bc950197a4ddd31898cd5a2843d065'

  # No --default-names option as it interferes with Homebrew builds.
  option :universal
  option 'with-tests', 'Enable running build-time unit tests (requires {deja-gnu})'
  option 'with-zstd', 'Allow debugging‐data compression in ZStandard format'
  option 'without-nls', 'Build without natural‐language support (internationalization)'

  depends_on 'texinfo'    => :build  # for the documentation; stock version is too old
  depends_on 'deja-gnu'   => :build if build.with? 'tests'
  depends_on 'pkg-config' => :build if build.with? 'zstd'
  depends_on 'isl'
  depends_on 'libiconv'
  depends_on 'zlib'
  depends_on :nls   => :recommended
  depends_on 'zstd' => :optional

  def install
    ENV.universal_binary if build.universal?
    ENV.append 'CFLAGS', '-std=gnu99'   # needed because older GCCs default to gnu89 instead
    ENV['MAKEINFO'] = Formula['texinfo'].opt_bin/makeinfo  # needed because of faulty `configure`
    cd 'libiberty' do
      system './configure', "--prefix=#{prefix}"
      system 'make'
    end
    cd 'libsframe' do
      system './configure', "--prefix=#{prefix}",
                            '--program-prefix=g',
                            '--disable-dependency-tracking',
                            '--disable-silent-rules',
                            '--enable-install-libbfd',
                            '--enable-shared'  # Don’t build LibSFrame static‐only.
      system 'make'
    end
    cd 'bfd' do
      args = [
          "--prefix=#{prefix}",
          '--program-prefix=g',
          '--disable-dependency-tracking',
          '--disable-silent-rules',
          '--enable-64-bit-bfd',    # Needed for 64‐bit targets on narrower archs.
          '--enable-build-warnings',
          '--enable-checking=all',  # Run‐time checking, not build‐time.
          '--enable-install-libbfd',
          '--enable-plugins',       # Not sure _what_ plugins, but sure, why not.
          '--enable-shared',        # Don’t build LibBFD static‐only.
          '--with-system-zlib',     # Vs. binutils’.  Ours is likely newer.
          '--enable-targets=all',   # All target ISAs, not all makefile targets.
          '--enable-werror',        # Make compiler warnings fatal.
        ]
      args << '--disable-nls' if build.without? 'nls'
      args << '--with-zstd' if build.with? 'zstd'
      system './configure', *args
      system 'make'
    end
    cd 'opcodes' do
      args = [
          "--prefix=#{prefix}",
          '--program-prefix=g',
          '--disable-dependency-tracking',
          '--disable-silent-rules',
          '--enable-64-bit-bfd',    # Needed for 64‐bit targets on narrower archs.
          '--enable-build-warnings',
          '--enable-checking=all',  # Run‐time checking, not build‐time.
          '--enable-install-libbfd',
          '--enable-shared',        # Don’t build LibOpcodes static‐only.
          '--enable-targets=all',   # All target ISAs, not all makefile targets.
          '--enable-werror',        # Make compiler warnings fatal.
        ]
      args << '--disable-nls' if build.without? 'nls'
      system './configure', *args
      system 'make'
    end
    cd 'intl' do
      system './configure', "--prefix=#{prefix}",
                            "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}",
                            "--with-libintl-prefix=#{Formula['gettext'].opt_prefix}"
    end if build.with? 'nls'
    cd 'libctf' do
      system './configure', "--prefix=#{prefix}",
                            '--program-prefix=g',
                            '--disable-dependency-tracking',
                            '--disable-silent-rules',
                            '--enable-install-libbfd',
                            '--enable-shared',
                            '--with-system-zlib'  # Vs. binutils’.  Ours is likely newer.
      system 'make'
    end
    cd 'binutils' do
      args = [
          "--prefix=#{prefix}",
          '--program-prefix=g',
          '--disable-dependency-tracking',
          '--disable-silent-rules',
          '--enable-build-warnings',
          '--enable-checking=all',         # Run‐time checking, not build‐time.
          '--enable-colored-disassembly',  # Sets a default behaviour for objdump.
          '--without-debuginfod',          # Whatever this is, we don’t have it.
          '--enable-deterministic-archives',  # Makes ar and ranlib default to -D behaviour.
          '--enable-f-for-ifunc-symbols',  # Makes nm use F / f for global / local ifunc symbols.
          '--enable-follow-debug-links',   # Makes readelf & objdump follow debug links by default.
          "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}",
          '--enable-plugins',              # Not sure _what_ plugins, but sure, why not.
          '--with-system-zlib',            # Vs. binutils’.  Ours is likely newer.
          '--enable-targets=all',          # All target ISAs, not all makefile targets.
          '--enable-werror',               # Make compiler warnings fatal.
        ]
      args << '--disable-nls' if build.without? 'nls'
      args << '--with-zstd' if build.with? 'zstd'
      system './configure', *args
      system 'make'
    end
    ['libiberty', 'libsframe', 'libctf', 'binutils'].each do |dir|  # bfd? opcodes?
      cd dir { system 'make', 'check' }
    end if build.with? 'tests'
    ['libsframe', 'bfd', 'opcodes', 'libctf', 'binutils'].each do |dir|
      cd dir { system 'make', 'install' }
    end
  end # install

  test do
    for_archs(bin/'gnm') { |_, cmd| assert_match(/main/, `#{cmd * ' '} #{bin}/gnm`) }
  end
end # Binutils241

__END__
--- old/binutils/configure
+++ new/binutils/configure
@@ -5122,23 +5122,33 @@
        # Check to see if the nm accepts a BSD-compat flag.
        # Adding the `sed 1q' prevents false positives on HP-UX, which says:
        #   nm: unknown option "B" ignored
+       # However, it is no help on Darwin 9, which says:
+       #   nm: invalid argument -B
+      if "$tmp_nm" -B "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
        case `"$tmp_nm" -B "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
        *$tmp_nm*) lt_cv_path_NM="$tmp_nm -B"
 	 break
 	 ;;
        *)
 	 case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
 	 *$tmp_nm*)
 	   lt_cv_path_NM="$tmp_nm -p"
 	   break
 	   ;;
 	 *)
 	   lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"} # keep the first match, but
 	   continue # so that we can try to find one that supports BSD flags
 	   ;;
 	 esac
 	 ;;
        esac
+      elif "$tmp_nm" -p "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
+       case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
+       *$tmp_nm*) lt_cv_path_NM="$tmp_nm -p"; break;;
+       *) lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"}; continue;; # as above
+       esac
+      else lt_cv_path_NM="$tmp_nm"
+      fi
      fi
    done
    IFS="$lt_save_ifs"
--- old/libbfd/configure
+++ new/libbfd/configure
@@ -5442,23 +5442,33 @@
        # Check to see if the nm accepts a BSD-compat flag.
        # Adding the `sed 1q' prevents false positives on HP-UX, which says:
        #   nm: unknown option "B" ignored
+      # However, it is no help on Darwin 9, which says:
+      #   nm: invalid argument -B
+     if "$tmp_nm" -B "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
        case `"$tmp_nm" -B "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
        *$tmp_nm*) lt_cv_path_NM="$tmp_nm -B"
 	 break
 	 ;;
        *)
 	 case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
 	 *$tmp_nm*)
 	   lt_cv_path_NM="$tmp_nm -p"
 	   break
 	   ;;
 	 *)
 	   lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"} # keep the first match, but
 	   continue # so that we can try to find one that supports BSD flags
 	   ;;
 	 esac
 	 ;;
        esac
+      elif "$tmp_nm" -p "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
+       case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
+       *$tmp_nm*) lt_cv_path_NM="$tmp_nm -p"; break;;
+       *) lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"}; continue;; # as above
+       esac
+      else lt_cv_path_NM="$tmp_nm"
+      fi
      fi
    done
    IFS="$lt_save_ifs"
--- old/libctf/configure
+++ new/libctf/configure
@@ -5966,23 +5966,33 @@
        # Check to see if the nm accepts a BSD-compat flag.
        # Adding the `sed 1q' prevents false positives on HP-UX, which says:
        #   nm: unknown option "B" ignored
+       # However, it is no help on Darwin 9, which says:
+       #   nm: invalid argument -B
+      if "$tmp_nm" -B "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
        case `"$tmp_nm" -B "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
        *$tmp_nm*) lt_cv_path_NM="$tmp_nm -B"
 	 break
 	 ;;
        *)
 	 case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
 	 *$tmp_nm*)
 	   lt_cv_path_NM="$tmp_nm -p"
 	   break
 	   ;;
 	 *)
 	   lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"} # keep the first match, but
 	   continue # so that we can try to find one that supports BSD flags
 	   ;;
 	 esac
 	 ;;
        esac
+      elif "$tmp_nm" -p "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
+       case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
+       *$tmp_nm*) lt_cv_path_NM="$tmp_nm -p"; break;;
+       *) lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"}; continue;; # as above
+       esac
+      else lt_cv_path_NM="$tmp_nm"
+      fi
      fi
    done
    IFS="$lt_save_ifs"
--- old/libsframe/configure
+++ new/libsframe/configure
@@ -5821,23 +5821,33 @@
        # Check to see if the nm accepts a BSD-compat flag.
        # Adding the `sed 1q' prevents false positives on HP-UX, which says:
        #   nm: unknown option "B" ignored
+       # However, it is no help on Darwin 9, which says:
+       #   nm: invalid argument -B
+      if "$tmp_nm" -B "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
        case `"$tmp_nm" -B "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
        *$tmp_nm*) lt_cv_path_NM="$tmp_nm -B"
 	 break
 	 ;;
        *)
 	 case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
 	 *$tmp_nm*)
 	   lt_cv_path_NM="$tmp_nm -p"
 	   break
 	   ;;
 	 *)
 	   lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"} # keep the first match, but
 	   continue # so that we can try to find one that supports BSD flags
 	   ;;
 	 esac
 	 ;;
        esac
+      elif "$tmp_nm" -p "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
+       case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
+       *$tmp_nm*) lt_cv_path_NM="$tmp_nm -p"; break;;
+       *) lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"}; continue;; # as above
+       esac
+      else lt_cv_path_NM="$tmp_nm"
+      fi
      fi
    done
    IFS="$lt_save_ifs"
--- old/opcodes/configure
+++ new/opcodes/configure
@@ -5376,23 +5376,33 @@
        # Check to see if the nm accepts a BSD-compat flag.
        # Adding the `sed 1q' prevents false positives on HP-UX, which says:
        #   nm: unknown option "B" ignored
+       # However, it is no help on Darwin 9, which says:
+       #   nm: invalid argument -B
+      if "$tmp_nm" -B "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
        case `"$tmp_nm" -B "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
        *$tmp_nm*) lt_cv_path_NM="$tmp_nm -B"
 	 break
 	 ;;
        *)
 	 case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
 	 *$tmp_nm*)
 	   lt_cv_path_NM="$tmp_nm -p"
 	   break
 	   ;;
 	 *)
 	   lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"} # keep the first match, but
 	   continue # so that we can try to find one that supports BSD flags
 	   ;;
 	 esac
 	 ;;
        esac
+      elif "$tmp_nm" -p "$tmp_nm_to_nm" >/dev/null 2>&1 ; then
+       case `"$tmp_nm" -p "$tmp_nm_to_nm" 2>&1 | grep -v '^ *$' | sed '1q'` in
+       *$tmp_nm*) lt_cv_path_NM="$tmp_nm -p"; break;;
+       *) lt_cv_path_NM=${lt_cv_path_NM="$tmp_nm"}; continue;; # as above
+       esac
+      else lt_cv_path_NM="$tmp_nm"
+      fi
      fi
    done
    IFS="$lt_save_ifs"
--- old/opcodes/riscv-opc.c
+++ new/opcodes/riscv-opc.c
@@ -155,11 +155,11 @@
 #define MASK_RL (OP_MASK_RL << OP_SH_RL)
 #define MASK_AQRL (MASK_AQ | MASK_RL)
 #define MASK_SHAMT (OP_MASK_SHAMT << OP_SH_SHAMT)
-#define MATCH_SHAMT_REV8_32 (0b11000 << OP_SH_SHAMT)
-#define MATCH_SHAMT_REV8_64 (0b111000 << OP_SH_SHAMT)
-#define MATCH_SHAMT_BREV8 (0b00111 << OP_SH_SHAMT)
-#define MATCH_SHAMT_ZIP_32 (0b1111 << OP_SH_SHAMT)
-#define MATCH_SHAMT_ORC_B (0b00111 << OP_SH_SHAMT)
+#define MATCH_SHAMT_REV8_32 (0x18 << OP_SH_SHAMT)
+#define MATCH_SHAMT_REV8_64 (0x38 << OP_SH_SHAMT)
+#define MATCH_SHAMT_BREV8 (0x7 << OP_SH_SHAMT)
+#define MATCH_SHAMT_ZIP_32 (0xf << OP_SH_SHAMT)
+#define MATCH_SHAMT_ORC_B (0x7 << OP_SH_SHAMT)
 #define MASK_VD (OP_MASK_VD << OP_SH_VD)
 #define MASK_VS1 (OP_MASK_VS1 << OP_SH_VS1)
 #define MASK_VS2 (OP_MASK_VS2 << OP_SH_VS2)
