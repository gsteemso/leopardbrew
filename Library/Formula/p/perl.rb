# stable release 2025-07-03; devel release 2025-07-20; checked 2025-08-01
require 'merge'

class Perl < Formula
  include Merge

  desc 'Highly capable, feature-rich programming language'
  homepage 'https://www.perl.org/'
  url 'https://www.cpan.org/src/5.0/perl-5.42.0.tar.xz'
  sha256 '73cf6cc1ea2b2b1c110a18c14bbbc73a362073003893ffcedc26d22ebdbdd0c3'

  head 'https://github.com/Perl/perl5.git', :branch => 'blead'

  keg_only :provided_by_osx,
    'Mac OS ships Perl and overriding that can cause unintended issues.'

  devel do
    url 'https://www.cpan.org/src/5.0/perl-5.43.1.tar.xz'
    sha256 '260fa2f8cae4a700083f48db70c2eb56abc3e45a166a6eb22df3319aef7eb141'
  end

  option :universal
  option 'with-dtrace', 'Build with DTrace probes' if (MacOS.version >= :leopard and not MacOS.prefer_64_bit?) \
                                                      or MacOS.version >= :lion
  option 'with-tests', 'Run the build-time unit tests (fails on 64‐bit when built with older compilers)'

  enhanced_by 'curl'  # The obsolete stock curl on older Mac OSes causes
                      # extension modules reliant on it to fail messily.

  if (build.with?('tests') or build.bottle?) and MacOS.prefer_64_bit? and not ARGV.force?
    fails_with [:gcc, :gcc_4_0, :llvm]
  end

  # installperl:  Rarely, .packlist files are created without write permissions.  (undocumented)
  # t/04-xs-rpath-darwin.t:  Library build needs to match bit width of Perl build.  (undocumented)
  patch :DATA unless build.head?

  # shared location for pure‐Perl extensions
  def site_perl; HOMEBREW_PREFIX/'site_perl'; end

  def install
    archs = build.universal? ? CPU.local_archs : [MacOS.preferred_arch]

    args = %W[
      -des
      -Dprefix=#{prefix}
      -Uvendorprefix=
      -Dprivlib=#{lib}
      -Darchlib=#{lib}
      -Dman1dir=#{man1}
      -Dman3dir=#{man3}
      -Dman3ext=3pl
      -Dsitebin=#{site_perl}/bin
      -Dsitescript=#{site_perl}/bin
      -Dsitelib=#{site_perl}/lib
      -Dsitearch=#{site_perl}/lib
      -Dsiteman1dir=#{site_perl}/man1
      -Dsiteman3dir=#{site_perl}/man3
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

      arch_args = ["-Dcc=#{ENV.cc}"]
      if arch.to_s =~ %r{64} then arch_args << '-Duse64bitall'
      elsif CPU._64b? then arch_args << '-Duse64bitint'; end

      system './Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' rescue nil if build.with?('tests') or build.bottle?
      system 'make', 'install'

      if build.universal?
        ENV.deparallelize{ system 'make', 'veryclean' }
        scour_keg(arch)
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
    end # universal?
  end # install

  def caveats; <<-EOS.undent
      By default Perl installs modules in your HOME dir.  If this is an issue, run:
          `#{bin}/cpan o conf init`
      and tell it to put them in, for example, #{site_perl} instead.

      If brewed cURL is not present, the system `curl` will be used by those extension
      modules that require it; on older Mac OSes, this will fail messily in use due to
      its extreme obsolescence.  (Due to a circular dependency, a newer cURL cannot be
      automatically brewed.)
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
@@ -199,7 +199,8 @@
     my $libext = $Config{so};
 
     my $libname = 'lib' . $self->{mylib_lib_name} . '.' . $libext;
-    my @cmd = ($cc, '-I.', '-dynamiclib', '-install_name',
+    my $m64 = defined $Config::Config{use64bitall};
+    my @cmd = ($cc, $m64 ? '-m64' : '-m32', '-I.', '-dynamiclib', '-install_name',
              '@rpath/' . $libname,
              'mylib.c', '-o', $libname);
     _run_system_cmd(\@cmd);
