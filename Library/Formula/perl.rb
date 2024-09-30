class Perl < Formula
  desc 'Highly capable, feature-rich programming language'
  homepage 'https://www.perl.org/'
  url 'https://www.cpan.org/src/5.0/perl-5.40.0.tar.xz'
  sha256 'd5325300ad267624cb0b7d512cfdfcd74fa7fe00c455c5b51a6bd53e5e199ef9'

  head 'https://github.com/Perl/perl5.git', :branch => 'blead'

  devel do
    url 'https://www.cpan.org/src/5.0/perl-5.41.3.tar.xz'
    sha256 'e4f23aa6160a3830bdbefa241c87018a33e21da9e0ad915332158832d0fd8230'
  end

  keg_only :provided_by_osx,
    'OS X ships Perl and overriding that can cause unintended issues'

  bottle do
    sha256 '0743dbdaa87cc72cc5f206ade56c68d4f5e2ebacad8f047872b8c3827bfa724c' => :tiger_altivec
  end

  option :universal
  option 'with-dtrace', 'Build with DTrace probes' if MacOS.version >= :leopard
  option 'with-tests', 'Run the build-test suite (fails on ppc64 when built with older GCCs)'

  # installperl:  .packlist files are sometimes created without write permissions (undocumented)
  # t/04-xs-rpath-darwin.t:  Need Darwin 9 minimum
  #   see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/446
  #   ″  :  Dummy library build needs to match Perl build, especially on 64-bit (undocumented)
  patch :DATA unless build.head?

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    args = %W[
      -des
      -Dprefix=#{prefix}
      -Uvendorprefix=
      -Dprivlib=#{lib}
      -Darchlib=#{lib}
      -Dman1dir=#{man1}
      -Dman3dir=#{man3}
      -Dman3ext=3pl
      -Dsitelib=#{lib}/site_perl
      -Dsitearch=#{lib}/site_perl
      -Dsiteman1dir=#{man1}
      -Dsiteman3dir=#{man3}
      -Dperladmin=none
      -Dstartperl='\#!#{opt_bin}/perl'
      -Duseshrplib
      -Duselargefiles
      -Dusenm
      -Dusethreads
    ]
    args << '-Dusedevel' unless build.stable?
    args << '-Dusedtrace' if build.with? 'dtrace'

    archs.each do |arch|
      case arch
        when :ppc, :i386 then bitness = 32; ENV.m32
        when :ppc64, :x86_64 then bitness = 64; ENV.m64
      end

      arch_args = %W[
        -Acppflags=-m#{bitness}
      ]
      if bitness == 64
        arch_args << '-Duse64bitall'
      elsif Hardware::CPU.family == :g5 or Hardware::CPU.family == :g5_64
        arch_args << '-Duse64bitint'
      end

      system './Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' if build.with?('tests') || build.bottle?
      system 'make', 'install'

      if build.universal?
        ENV.deparallelize { system 'make', 'veryclean' }
        Merge.scour_keg(prefix, stashdir/"bin-#{arch}")
        # undo architecture-specific tweaks before next run
        case bitness
          when 32 then ENV.un_m32
          when 64 then ENV.un_m64
        end # case bitness
      end # universal?
    end # each |arch|

    Merge.binaries(prefix, stashdir, archs) if build.universal?
  end # install

  def caveats
    the_text = <<-EOS.undent
      By default Perl installs modules in your HOME dir. If this is an issue run:
        `#{bin}/cpan o conf init`
      and tell it to put them in, for example, #{opt_lib}/site_perl instead.
    EOS
    the_text += <<-_.undent if (build.with?('tests') and Hardware::CPU.ppc? and (build.universal? or MacOS.prefer_64_bit?))
      Perl is known to fail one test (t/io/sem) when built for 64-bit PowerPC.  This
      failure, being expected, is ignored.  However, any other errors that may occur
      also get ignored.  You must check the test summary produced during compilation
      to verify that no other failures took place.
    _
    the_text
  end # caveats

  test do
    perl = (stable? ? bin/'perl' : Dir.glob("#{bin}/perl5.*").first)
    (testpath/'test.pl').write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    system perl, 'test.pl'
  end # test
end # Perl

class Merge
  module Pathname_extension
    def is_bare_mach_o?
      def got_valid_mach_o_header?(words)
        # header word 0, magic signature:
        #   MH_MAGIC    = 'feedface' – value with lowest‐order bit clear
        #   MH_MAGIC_64 = 'feedfacf' – same value with lowest‐order bit set
        # low‐order 24 bits of header word 1, CPU type:  7 is x86, 12 is ARM, 18 is PPC
        # header word 3, file type:  no types higher than 10 are defined
        # header word 5, net size of load commands, is far smaller than the filesize
        raise('Fat binary found where bare Mach-O file expected') if words[0] == 0xcafebabe
        ((words[0] & 0xfffffffe == 0xfeedface) and
          [7, 12, 18].detect { |item| words[1] & 0x00ffffff == item } and
          words[3] < 11 and
          words[5] < self.size)
      end # got_valid_mach_o_header?
      self.file? and (not self.symlink?) and
        (self.size >= 28 and
          got_valid_mach_o_header?(self.binread(24).unpack('N6'))) or
        (self.binread(8) == "!<arch>\x0a" and self.size >= 72 and
          (self.binread(16, 8) !~ %r|^#1/\d+|   and
            got_valid_mach_o_header?(self.binread(24, 68).unpack('N6'))) or
          (self.binread(16, 8) =~ %r|^#1/(\d+)| and
            got_valid_mach_o_header?(self.binread(24, 68+($1.to_i)).unpack('N6'))))
    end unless method_defined?(:is_bare_mach_o?)
  end # Pathname_extension

  class << self
    include FileUtils

    # The stash_root is expected to be a Pathname object.
    # The keg_prefix and the sub_path are just strings.
    def scour_keg(keg_prefix, stash_root, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      stash_p = stash_root/s_p
      mkdir_p stash_p unless stash_p.directory?
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f).extend(Pathname_extension)
        spb = s_p + pn.basename
        if pn.directory?
          scour_keg(keg_prefix, stash_root, spb)
        # the number of things that look like Mach-O files but aren’t is horrifying, so test
        elsif ((not pn.symlink?) and pn.is_bare_mach_o?)
          cp pn, stash_root/spb
        end # what is pn?
      end # each pathname
    end # Merge.scour_keg

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

  end # << self
end # Merge

__END__
--- old/installperl
+++ new/installperl
@@ -238,7 +238,29 @@
 				" some tests failed! (Installing anyway.)\n";
 
 # This will be used to store the packlist
-$packlist = ExtUtils::Packlist->new("$installarchlib/.packlist");
+{ # it keeps getting created without write permissions so just do the nuclear option & remake it
+    umask 0000;
+    my(@subdirs, $string, $fh, $packlistname);
+    $installarchlib =~ s|//+|/|g;
+    @subdirs = split '/', $installarchlib;
+    foreach my $i (0..$#subdirs) {
+        $string = '/' . join '/', @subdirs[0..$i];
+        mkdir $string unless -d $string;
+    }
+    $packlistname = "$installarchlib/.packlist";
+    $packlist = ExtUtils::Packlist->new($packlistname);
+    unless (-w $packlistname) {
+        unless (chmod(0755, $installarchlib) and chmod(0644, $packlistname)) {
+            local $/ = local $\ = undef;
+            if (open($fh, '<', $packlistname)) { $string = <$fh>; close($fh); }
+            else { $string = ''; }
+            unlink($packlistname) or die "Couldn't delete file $packlistname.\n" if (-f $packlistname);
+            open($fh, '+>', $packlistname) or die "Couldn't open file $packlistname for I/O.\n";
+            print $fh $string;
+            close($fh);
+        }
+    }
+}
 
 if ($Is_W32 or $Is_Cygwin) {
     my $perldll;
--- old/cpan/ExtUtils-MakeMaker/t/04-xs-rpath-darwin.t
+++ new/cpan/ExtUtils-MakeMaker/t/04-xs-rpath-darwin.t
@@ -14,9 +14,13 @@ BEGIN {
     chdir 't' or die "chdir(t): $!\n";
     unshift @INC, 'lib/';
     use Test::More;
+    my ($osmajmin) = $Config{osvers} =~ /^(\d+\.\d+)/;
     if( $^O ne "darwin" ) {
         plan skip_all => 'Not darwin platform';
     }
+    elsif ($^O eq 'darwin' && $osmajmin < 9) {
+	plan skip_all => 'For OS X Leopard and newer'
+    }
     else {
         plan skip_all => 'Dynaloading not enabled'
             if !$Config{usedl} or $Config{usedl} ne 'define';
@@ -195,7 +199,7 @@
     my $libext = $Config{so};
 
     my $libname = 'lib' . $self->{mylib_lib_name} . '.' . $libext;
-    my @cmd = ($cc, '-I.', '-dynamiclib', '-install_name',
+    my @cmd = ($cc, split(' ', $ENV{'CFLAGS'}), '-I.', '-dynamiclib', '-install_name',
              '@rpath/' . $libname,
              'mylib.c', '-o', $libname);
     _run_system_cmd(\@cmd);
