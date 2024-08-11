class Lame < Formula
  desc 'Lame Ain’t an MP3 Encoder (LAME)'
  homepage 'http://lame.sourceforge.net/'
  url 'https://downloads.sourceforge.net/sourceforge/lame/lame-3.100.tar.gz'
  sha256 'ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e'

  head 'https://svn.code.sf.net/p/lame/svn/trunk/lame'

  option :universal

  patch :DATA

  unless build.head?
    patch <<EoP
--- old/include/libmp3lame.sym	2017-09-06 12:33:35.000000000 -0700
+++ new/include/libmp3lame.sym	2024-08-05 11:40:42.000000000 -0700
@@ -1,5 +1,4 @@
 lame_init
-lame_init_old
 lame_set_num_samples
 lame_get_num_samples
 lame_set_in_samplerate
EoP
  end

  def install
    ENV.universal_binary if build.universal?

    system './configure', "--prefix=#{prefix}",
                          '--disable-debug',
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-nasm'
    system 'make', 'install'
  end

  test do
    system "#{bin}/lame", '--genre-list', test_fixtures('test.mp3')
  end
end

__END__
--- old/frontend/parse.c	2017-10-10 12:08:39.000000000 -0700
+++ new/frontend/parse.c	2024-08-05 11:55:30.000000000 -0700
@@ -2001,7 +2001,7 @@
                     nogap_tags = 1;
 
                 T_ELIF("nogapout")
-                    int const arg_n = strnlen(nextArg, PATH_MAX);
+                    int const arg_n = strlen(nextArg);
                     if (arg_n >= PATH_MAX) {
                         error_printf("%s: %s argument length (%d) exceeds limit (%d)\n", ProgramName, token, arg_n, PATH_MAX);
                         return -1;
@@ -2011,7 +2011,7 @@
                     argUsed = 1;
 
                 T_ELIF("out-dir")
-                    int const arg_n = strnlen(nextArg, PATH_MAX);
+                    int const arg_n = strlen(nextArg);
                     if (arg_n >= PATH_MAX) {
                         error_printf("%s: %s argument length (%d) exceeds limit (%d)\n", ProgramName, token, arg_n, PATH_MAX);
                         return -1;
