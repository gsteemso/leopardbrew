class Perl < Formula
  desc "Highly capable, feature-rich programming language"
  homepage "https://www.perl.org/"
  url 'https://www.cpan.org/src/5.0/perl-5.40.0.tar.xz'
  sha256 'd5325300ad267624cb0b7d512cfdfcd74fa7fe00c455c5b51a6bd53e5e199ef9'

  head "https://perl5.git.perl.org/perl.git", :branch => "blead"

  keg_only :provided_by_osx,
    "OS X ships Perl and overriding that can cause unintended issues"

  bottle do
    sha256 "0743dbdaa87cc72cc5f206ade56c68d4f5e2ebacad8f047872b8c3827bfa724c" => :tiger_altivec
  end

  option :universal
  option "with-dtrace", "Build with DTrace probes" if MacOS.version >= :leopard
  option "with-tests", "Run the build-test suite"

  # Unbreak Perl build on legacy Darwin systems
  # see https://github.com/Perl/perl5/pull/21023
  # lib/ExtUtils/MM_Darwin.pm: Unbreak Perl build
  # see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/444/files
  # t/04-xs-rpath-darwin.t: Need Darwin 9 minimum
  # see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/446
  # (undocumented) Dummy library build needs to match Perl build, especially on 64-bit
  patch :DATA

  def install
    # Kernel.system but ignoring exceptions
    def oblivious_system(cmd, *args)
      Homebrew.system(cmd, *args)
    rescue
      # do nothing
    end

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

    archs.each do |arch|
      case arch
        when :ppc, :i386 then bitness = 32; ENV.m32
        when :ppc64, :x86_64 then bitness = 64; ENV.m64
      end

      conditional_args = %W[
        -Acppflags=-m#{bitness}
      ]
      conditional_args << '-Duse64bitall' if bitness == 64
      conditional_args << "-Dusedtrace" if build.with? "dtrace"
      conditional_args << "-Dusedevel" if build.head?

      system "./Configure", *args, *conditional_args
      system "make"
      if build.with?("tests") || build.bottle?
        # - Set CFLAGS for the tests, so that the patch I added to make a dummy library be built
        #   with the same bitness as perl will definitely work.
        # - The tests produce one known failure on ppc64, but when nothing else goes wrong, we
        #   don't want the whole build to fail; so ignore errors.  On any other architecture, we
        #   still want errors to be fatal.
        if arch == :ppc64
          oblivious_system 'make', 'test', 'CFLAGS=-m64'
        else
          system 'make', 'test', "CFLAGS=-m#{bitness}"
        end
      end
      system "make", "install"

      if build.universal?
        ENV.deparallelize { system 'make', 'distclean' }
        Merge.scour_keg(prefix, stashdir/"bin-#{arch}")
        # undo architecture-specific tweaks before next run
        case bitness
          when 32 then ENV.un_m32
          when 64 then ENV.un_m64
        end # case bitness
      end # universal?
    end # each |arch|

    Merge.mach_o(prefix, stashdir, archs) if build.universal?
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
    (testpath/"test.pl").write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    system "#{bin}/perl", "test.pl"
  end # test
end # Perl

class Merge
  module Pathname_extension
    def is_bare_mach_o?
      # header word 0, magic signature:
      #   MH_MAGIC    = 'feedface' – value with lowest‐order bit clear
      #   MH_MAGIC_64 = 'feedfacf' – same value with lowest‐order bit set
      # low‐order 24 bits of header word 1, CPU type:  7 is x86, 12 is ARM, 18 is PPC
      # header word 3, file type:  no types higher than 10 are defined
      # header word 5, net size of load commands, is far smaller than the filesize
      if (self.file? and self.size >= 28 and mach_header = self.binread(24).unpack('N6'))
        raise('Fat binary found where bare Mach-O file expected') if mach_header[0] == 0xcafebabe
        ((mach_header[0] & 0xfffffffe) == 0xfeedface and
          [7, 12, 18].detect { |item| (mach_header[1] & 0x00ffffff) == item } and
          mach_header[3] < 11 and
          mach_header[5] < self.size)
      else
        false
      end
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
    end # scour_keg

    def mach_o(install_prefix, arch_dirs, sub_path = '')
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
          mach_o(keg_prefix, stash_root, archs, spb)
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
    end # mach_o
  end # << self
end # Merge

__END__
--- old/cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm   2023-03-02 11:53:45.000000000 +0000
+++ new/cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm   2023-05-21 05:13:48.000000000 +0100
@@ -46,29 +46,4 @@
     $self->SUPER::init_dist(@_);
 }
 
-=head3 cflags
-
-Over-ride Apple's automatic setting of -Werror
-
-=cut
-
-sub cflags {
-    my($self,$libperl)=@_;
-    return $self->{CFLAGS} if $self->{CFLAGS};
-    return '' unless $self->needs_linking();
-
-    my $base = $self->SUPER::cflags($libperl);
-
-    foreach (split /\n/, $base) {
-        /^(\S*)\s*=\s*(\S*)$/ and $self->{$1} = $2;
-    };
-    $self->{CCFLAGS} .= " -Wno-error=implicit-function-declaration";
-
-    return $self->{CFLAGS} = qq{
-CCFLAGS = $self->{CCFLAGS}
-OPTIMIZE = $self->{OPTIMIZE}
-PERLTYPE = $self->{PERLTYPE}
-};
-}
-
 1;
--- old/dist/ExtUtils-CBuilder/lib/ExtUtils/CBuilder/Platform/darwin.pm   2023-03-02 11:53:46.000000000 +0000
+++ new/dist/ExtUtils-CBuilder/lib/ExtUtils/CBuilder/Platform/darwin.pm   2023-05-21 05:18:00.000000000 +0100
@@ -20,9 +20,6 @@
   local $cf->{ccflags} = $cf->{ccflags};
   $cf->{ccflags} =~ s/-flat_namespace//;
 
-  # XCode 12 makes this fatal, breaking tons of XS modules
-  $cf->{ccflags} .= ($cf->{ccflags} ? ' ' : '').'-Wno-error=implicit-function-declaration';
-
   $self->SUPER::compile(@_);
 }
 
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
