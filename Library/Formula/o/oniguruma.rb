class Oniguruma < Formula
  desc 'Discontinued regular expressions library'
  homepage 'https://github.com/kkos/oniguruma/'
  url 'https://github.com/kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz'
  sha256 '2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05'

  option :universal

  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    assert_match %r{#{Regexp.escape(prefix.to_s)}}, shell_output("#{bin}/onig-config --prefix")
  end
end # Oniguruma

__END__
--- old/test/test_regset.c
+++ new/test/test_regset.c
@@ -292,23 +292,7 @@
 static int
 get_all_content_of_file(char* path, char** rs, char** rend)
 {
-  ssize_t len;
-  size_t n;
-  char* line;
-  FILE* fp;
-
-  fp = fopen(path, "r");
-  if (fp == 0) return -1;
-
-  n = 0;
-  line = NULL;
-  len = getdelim(&line, &n, EOF, fp);
-  fclose(fp);
-  if (len < 0) return -2;
-
-  *rs   = line;
-  *rend = line + len;
-  return 0;
+  return -1;
 }
 #endif
 
