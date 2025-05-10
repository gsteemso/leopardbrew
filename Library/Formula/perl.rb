require 'merge'

class Perl < Formula
  extend Merge;

  desc 'Highly capable, feature-rich programming language'
  homepage 'https://www.perl.org/'
  url 'https://www.cpan.org/src/5.0/perl-5.40.2.tar.xz'
  sha256 '10d4647cfbb543a7f9ae3e5f6851ec49305232ea7621aed24c7cfbb0bef4b70d'

  head 'https://github.com/Perl/perl5.git', :branch => 'blead'

  bottle do
    sha256 '0743dbdaa87cc72cc5f206ade56c68d4f5e2ebacad8f047872b8c3827bfa724c' => :tiger_altivec
  end

  devel do
    url 'https://www.cpan.org/src/5.0/perl-5.41.12.tar.xz'
    sha256 '136225190411feefd0cb7b6a5f732528763d414d5945859fb7e59a6b6469f0f8'
  end

  keg_only :provided_by_osx,
    'OS X ships Perl and overriding that can cause unintended issues'

  option :universal
  option 'with-dtrace', 'Build with DTrace probes' if (MacOS.version >= :leopard and not MacOS.prefer_64_bit?) \
                                                      or MacOS.version >= :lion
  option 'with-tests', 'Run the build-time unit tests (fails on ppc64 when built with older GCCs)'

  enhanced_by 'curl'  # The obsolete stock curl on older Mac OSes causes
                      # extension modules reliant on it to fail messily.

  if (build.with?('tests') or build.bottle?) and (build.universal? or
                                                     (MacOS.prefer_64_bit? and Hardware::CPU.ppc?))
    fails_with :gcc
    fails_with :gcc_4_0
  end

  # installperl:  .packlist files are sometimes created without write permissions (undocumented)
  # t/04-xs-rpath-darwin.t:  Need Darwin 9 minimum
  #   see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/446
  # (same file):  Dummy library build needs to match bit width(s) of Perl build (undocumented)
  patch :DATA unless build.head?

  def install
    if build.universal?
      archs = CPU.local_archs
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    # set installation directories for pure‐Perl extensions to the shared
    # location $HOMEBREW_PREFIX/site_perl
    args = %W[
      -des
      -Dprefix=#{prefix}
      -Uvendorprefix=
      -Dprivlib=#{lib}
      -Darchlib=#{lib}
      -Dman1dir=#{man1}
      -Dman3dir=#{man3}
      -Dman3ext=3pl
      -Dsitebin=#{HOMEBREW_PREFIX}/site_perl/bin
      -Dsitescript=#{HOMEBREW_PREFIX}/site_perl/bin
      -Dsitelib=#{HOMEBREW_PREFIX}/site_perl/lib
      -Dsitearch=#{lib}
      -Dsiteman1dir=#{HOMEBREW_PREFIX}/site_perl/man1
      -Dsiteman3dir=#{HOMEBREW_PREFIX}/site_perl/man3
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
      ENV.set_build_archs(arch) if build.universal?

      arch_args = []
      if arch.to_s =~ %r{64} then arch_args << '-Duse64bitall'
      elsif CPU._64b? then arch_args << '-Duse64bitint'; end

      system './Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' if build.with?('tests') or build.bottle?
      system 'make', 'install'

      if build.universal?
        ENV.deparallelize { system 'make', 'veryclean' }
        Merge.scour_keg(prefix, stashdir/"bin-#{arch}")
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      Merge.binaries(prefix, stashdir, archs)
    end # universal?
  end # install

  def caveats; <<-EOS.undent
      By default Perl installs modules in your HOME dir. If this is an issue run:
        `#{bin}/cpan o conf init`
      and tell it to put them in, for example, #{HOMEBREW_PREFIX}/site_perl instead.

      Perl will take advantage of brewed cURL, if it is present.  If it is _not_
      present, the system `curl` will be used by those extension modules that require
      it; on older Mac OSes, this will fail messily in use, due to its obsolescence.
      (Due to a circular dependency, a newer cURL cannot be automatically brewed for
      you.  If you have extension modules which require a newer cURL, it must be
      brewed separately, and then Perl reïnstalled.)
    EOS
  end # caveats

  test do
    perl = (stable? ? bin/'perl' : Dir.glob("#{bin}/perl5.*").first)
    (testpath/'test.pl').write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    arch_system perl, 'test.pl'
  end # test
end # Perl

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
