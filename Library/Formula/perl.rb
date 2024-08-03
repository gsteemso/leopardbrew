class Perl < Formula
  desc 'Highly capable, feature-rich programming language'
  homepage 'https://www.perl.org/'
  url 'https://www.cpan.org/src/5.0/perl-5.40.0.tar.xz'
  sha256 'd5325300ad267624cb0b7d512cfdfcd74fa7fe00c455c5b51a6bd53e5e199ef9'

  head 'https://perl5.git.perl.org/perl.git', :branch => 'blead'

  devel do
    url 'https://www.cpan.org/src/5.0/perl-5.41.2.tar.xz'
    sha256 '34673976db2c4432f498dca2c3df82587ca37d7a2c2ba9407d4e4f3854a51ea6'
  end

  keg_only :provided_by_osx,
    'OS X ships Perl and overriding that can cause unintended issues'

  bottle do
    sha256 '0743dbdaa87cc72cc5f206ade56c68d4f5e2ebacad8f047872b8c3827bfa724c' => :tiger_altivec
  end

  option :universal
  option 'with-dtrace', 'Build with DTrace probes' if MacOS.version >= :leopard
  option 'with-tests', 'Run the build-test suite'

  # lib/ExtUtils/MM_Darwin.pm:  Unbreak Perl build on legacy Darwin systems
  # see https://github.com/Perl/perl5/pull/21023
  # see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/444/files
  #
  # t/04-xs-rpath-darwin.t:  Need Darwin 9 minimum
  # see https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/446
  #
  # (same, undocumented) Dummy library build needs to match Perl build, especially on 64-bit
  patch :DATA

  def install
    if build.universal?
      ENV.universal_binary
      archs = Hardware::CPU.universal_archs
    else
      archs = [MacOS.preferred_arch]
    end # universal?
    archs.extend ArchitectureListExtension

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
      -Dstartperl=\#!#{opt_bin}/perl
      -Duseshrplib
      -Duselargefiles
      -Dusenm
      -Dusethreads
    ]
    args << '-Dusedevel' if build.devel?
    args << '-Dusedtrace' if build.with? 'dtrace'

    current_SDK = MacOS.sdk_path.to_s

    accflags = [
      '-DNO_MATHOMS',
      *(archs.as_arch_flags),
      '-nostdinc',
      "-B#{current_SDK}/usr/include/gcc",
      "-B#{current_SDK}/usr/lib/gcc",
      "-isystem#{current_SDK}/usr/include",
      "-F#{current_SDK}/System/Library/Frameworks"
    ]
    aldflags = [
      *(archs.as_arch_flags),
      "-Wl,-syslibroot,#{current_SDK}"
    ]
    args << "-Accflags='#{ accflags.join(' ') }'" << "-Aldflags='#{ aldflags.join(' ') }'"

    system "./Configure #{ args.join(' ') }"
    system 'make'
    ENV.deparallelize do
      system 'make', 'test' if build.with?('tests') || build.bottle?
      system 'make', 'install'
    end
  end # install

  def caveats; <<-EOS.undent
      By default Perl installs modules in your HOME dir. If this is an issue run:
        `#{bin}/cpan o conf init`
      and tell it to put them in, for example, #{opt_lib}/site_perl instead.
    EOS
  end # caveats

  test do
    (testpath/'test.pl').write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    system "#{bin}/perl", 'test.pl'
  end # test
end # Perl

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
