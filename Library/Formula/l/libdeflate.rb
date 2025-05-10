class Libdeflate < Formula
  desc 'Improved DEFLATE/zlib/gzip implementation'
  homepage 'https://github.com/ebiggers/libdeflate'
  url 'https://github.com/ebiggers/libdeflate/archive/refs/tags/v1.19.tar.gz'
  sha256 '27bf62d71cd64728ff43a9feb92f2ac2f2bf748986d856133cc1e51992428c25'

  option :universal

  depends_on 'cmake' => :build

  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    mkdir('../build') do
      system 'cmake', buildpath, *std_cmake_args, '-DLIBDEFLATE_BUILD_TESTS=ON'
      system 'cmake', '-B', buildpath
      system 'cmake', '--build', '.'
      system 'ctest', '-VV'
      system 'cmake', '--build', '.', '--target', 'install'
    end
  end # install
end # Libdeflate

__END__
--- old/programs/gzip.c
+++ new/programs/gzip.c
@@ -346,15 +346,31 @@
 #endif
 }
 
+#if defined(__APPLE__) && !defined(HAVE_FUTIMENS)
+static struct timeval
+val_from_spec(struct timespec *input_spec)
+{
+	return (struct timeval) { .tv_sec = input_spec->tv_sec,
+	                          .tv_usec = (input_spec->tv_nsec / 1000) };
+}
+#endif
+
 static void
 restore_timestamps(struct file_stream *out, const tchar *newpath,
 		   const stat_t *stbuf)
 {
 	int ret;
 #ifdef __APPLE__
+# ifdef HAVE_FUTIMENS
 	struct timespec times[2] = { stbuf->st_atimespec, stbuf->st_mtimespec };
 
 	ret = futimens(out->fd, times);
+# else
+	struct timeval times[2] = { val_from_spec(&(stbuf->st_atimespec)),
+	                            val_from_spec(&(stbuf->st_mtimespec)) };
+
+	ret = futimes(out->fd, times);
+# endif
 #elif (defined(HAVE_FUTIMENS) && defined(HAVE_STAT_NANOSECOND_PRECISION)) || \
 	/* fallback detection method for direct compilation */ \
 	(!defined(HAVE_CONFIG_H) && defined(UTIME_NOW))
