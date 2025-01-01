class Openssl3 < Formula
  desc 'Cryptography and SSL/TLS Toolkit'
  homepage 'https://openssl.org/'
  url 'https://openssl.org/source/openssl-3.3.1.tar.gz'
  sha256 '777cd596284c883375a2a7a11bf5d2786fc5413255efab20c50d6ffe6d020b7e'
  license 'Apache-2.0'

  option :universal
  option 'without-tests', 'Skip the self-test procedure (not recommended for a first install)'

  keg_only :provided_by_osx

  depends_on 'curl-ca-bundle'
  depends_on 'perl'

  def arg_format(arch)
    case arch
      when :x86_64 then 'darwin64-x86_64-cc'
      when :i386   then 'darwin-i386-cc'
      when :ppc    then 'darwin-ppc-cc'
      when :ppc64  then 'darwin64-ppc-cc'
    end
  end

  def install
    # Build breaks passing -w
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    # Leopard and newer have the crypto framework
    ENV.append_to_cflags '-DOPENSSL_NO_APPLE_CRYPTO_RANDOM' if MacOS.version == :tiger
    # This could interfere with how we expect OpenSSL to build.
    ENV.delete('OPENSSL_LOCAL_CONFIG_DIR')
    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, causing them to break every Perl update.
    # Whilst our env points to opt_bin, by default OpenSSL resolves the symlink.
    ENV['PERL'] = Formula['perl'].opt_bin/'perl' if which('perl') == Formula['perl'].opt_bin/'perl'

    if build.universal?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/openssl
        lib/engines-3/capi.dylib
        lib/engines-3/loader_attic.dylib
        lib/engines-3/padlock.dylib
        lib/libcrypto.3.dylib
        lib/libcrypto.a
        lib/libssl.3.dylib
        lib/libssl.a
      ]
      the_headers = %w[
        openssl/configuration.h
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    openssldir.mkpath

    args = [
      "--prefix=#{prefix}",
      "--openssldir=#{openssldir}",
      'no-atexit',  # maybe this will stop the segfaults?
      'no-legacy',  # for no apparent reason, the legacy provider fails `make test`
      'enable-trace',
      'zlib-dynamic'
    ]
    args << 'sctp' if MacOS.version > :leopard  # pre‐Snow Leopard lacks these system headers
    args << 'enable-brotli-dynamic' if Formula['brotli'].installed?
    args << 'enable-zstd-dynamic' if Formula['zstd'].installed?
    # No {get,make,set}context support before Leopard
    args << 'no-async' if MacOS.version < :leopard

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}" if build.universal?

      arch_args = [
        arg_format(arch),
      ]
      # the assembly routines don’t work right on Tiger or on 32‐bit PowerPC G5
      arch_args << 'no-asm' if MacOS.version < :leopard or (arch == :ppc and Hardware::CPU.model == :g5)

      system 'perl', './Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' if build.with? 'tests'
      system 'make', 'install', 'MANSUFFIX=ssl'

      if build.universal?
        system 'make', 'distclean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        Merge.prep(include, stashdir/"h-#{arch}", the_headers)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|
    if build.universal?
      Merge.binaries(prefix, stashdir, archs)
      Merge.c_headers(include, stashdir, archs)
    end # universal?
  end # install

  def openssldir
    etc/'openssl@3'
  end

  def post_install
    rm_f openssldir/'cert.pem'
    openssldir.install_symlink Formula['curl-ca-bundle'].opt_share/'ca-bundle.crt' => 'cert.pem'
  end

  def caveats
    <<-EOS.undent
      OpenSSL3 configures itself to allow any or all of Zlib, Brotli, & ZStandard
      (“zstd”) compression, if their formulæ are already brewed at the time.  If you
      install them afterwards, OpenSSL3 will not know about them.

      A CA file is provided by the `curl-ca-bundle` formula.  To add certificates to
      it, place .pem files in
        #{openssldir}/certs
      and run
        #{opt_bin}/c_rehash
    EOS
  end

  test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    assert_predicate openssldir/'openssl.cnf', :exist?,
            'OpenSSL requires the .cnf file for some functionality'

    # Check OpenSSL itself functions as expected.
    (testpath/'testfile.txt').write('This is a test file')
    expected_checksum = 'e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249'
    for_archs bin/'openssl' do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      system *arch_cmd, bin/'openssl', 'dgst', '-sha256', '-out', 'checksum.txt', 'testfile.txt'
      open('checksum.txt') do |f|
        checksum = f.read(100).split('=').last.strip
        assert_equal checksum, expected_checksum
      end
    end
  end # test
end # Openssl3

class Merge
  class << self
    include FileUtils

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        cp_mkp source, dest
      end # each binary
    end # Merge.prep

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def binaries(keg_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "bin-#{a}"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          binaries(keg_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', keg_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, keg_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # Merge.binaries

    def c_headers(include_dir, stash_root, archs, sub_path = '')
      # Architecture-specific <header>.<extension> files need to be surgically combined and were
      # stashed for this purpose.  The differences are relatively minor and can be “#if defined ()”
      # together.  We make the simplifying assumption that the architecture-dependent headers in
      # question are present on all architectures.
      #
      # Don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{stash_root}/h-#{archs[0]}/#{s_p}*"].each do |basis_file|
        spb = s_p + File.basename(basis_file)
        if File.directory?(basis_file)
          c_headers(include_dir, stash_root, archs, spb)
        else
          diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of
                           # three‐element hashes; containing the arch, the hunk’s displacement
                           # (number of basis‐file lines it replaces), and an array of its lines.
          archs[1..-1].each do |a|
            raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stash_root}/h-#{a}/#{spb}`
            next unless raw_diffs
            # The unified diff output begins with two lines identifying the source files, which are
            # followed by a series of hunk records, each describing one difference that was found.
            # Each hunk record begins with a line that looks like:
            # @@ -line_number,length_in_lines +line_number,length_in_lines @@
            diff_hunks = raw_diffs.lines[2..-1].join('').split(/(?=^@@)/)
            diff_hunks.each do |d|
              # lexical sorting of numbers requires that they all be the same length
              base_linenumber_string = ('00000' + d.match(/\A@@ -(\d+)/)[1])[-6..-1]
              unless diffpoints.has_key?(base_linenumber_string)
                diffpoints[base_linenumber_string] = []
              end
              length_match = d.match(/\A@@ -\d+,(\d+)/)
              # if the hunk length is 1, the comma and second number are not present
              length_match = (length_match == nil ? 1 : length_match[1].to_i)
              line_group = []
              # we want the lines that are either unchanged between files or only found in the non‐
              # basis file; and to shave off the leading ‘+’ or ‘ ’
              d.lines { |line| line_group << line[1..-1] if line =~ /^[+ ]/ }
              diffpoints[base_linenumber_string] << {
                :arch => a,
                :displacement => length_match,
                :hunk_lines => line_group
              }
            end # each diff hunk |d|
          end # each arch |a|
          # Ideally, the logic would account for overlapping and/or different-displacement hunks at
          # this point; but since most packages do not seem to generate such in the first place, it
          # can wait.  That said, packages exist (e.g. the originals of both Python 2 and Python 3)
          # which can and do generate quad fat binaries (and we want to some day support generating
          # them by default), so it can’t be ignored forever.
          basis_lines = []
          File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
          # Don’t forget, the line-array indices are one less than the line numbers.
          # Start with the last diff point so the insertions don’t screw up our line numbering:
          diffpoints.keys.sort.reverse.each do |index_string|
            diff_start = index_string.to_i - 1
            diff_end = index_string.to_i + diffpoints[index_string][0][:displacement] - 2
            adjusted_lines = [
              "\#if defined (__#{archs[0]}__)\n",
              basis_lines[diff_start..diff_end],
              *(diffpoints[index_string].map { |dp|
                  [ "\#elif defined (__#{dp[:arch]}__)\n", *(dp[:hunk_lines]) ]
                }),
              "\#endif\n"
            ]
            basis_lines[diff_start..diff_end] = adjusted_lines
          end # each key |index_string|
          File.new("#{include_dir}/#{spb}", 'w').syswrite(basis_lines.join(''))
        end # if not a directory
      end # each |basis_file|
    end # Merge.c_headers

  end # << self
end # Merge
