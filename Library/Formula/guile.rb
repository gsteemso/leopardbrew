class Guile < Formula
  desc 'GUILE:  GNU Ubiquitous Intelligent Language for Extensions'
  homepage 'https://www.gnu.org/software/guile/'
  url 'http://ftpmirror.gnu.org/guile/guile-3.0.10.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/guile/guile-3.0.10.tar.lz'
  sha256 'f0d97cccf506e4b6104c51639bd1b7bf67400e0b3401f0b2f6b7136532040327'

  head do
    url 'http://git.sv.gnu.org/r/guile.git'

    depends_on 'autoconf'   => :build
    depends_on 'automake'   => :build
    depends_on 'flex'       => :build
    depends_on 'gperftools' => :build
    depends_on 'texinfo'    => :build
  end

  option :universal

  depends_on 'gettext'    => [:build, :run]
  depends_on 'pkg-config' => :build
  depends_on 'bdw-gc'
  depends_on 'gmp'
  depends_on 'libffi'
  depends_on 'libtool'    => :run
  depends_on 'libunistring'
  depends_on 'readline'

  # does it still?  hells if I know
  fails_with :llvm do
    build 2336
    cause 'Segfaults during compilation'
  end

  # does it still?  hells if I know
  fails_with :clang do
    build 211
    cause 'Segfaults during compilation'
  end

  # - GCC 4.x can’t handle a repeated typedef if one of the iterations uses a structure declaration
  #   and the other uses its definition.
  # - Older Macs don’t have dprintf().
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system './autogen.sh' if build.head?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    ENV.deparallelize do
      system 'make'
      system 'make', '-i', '-k', 'check'
    end
    system 'make', 'install'

    # A really messed up workaround required on OS X --mkhl
    Pathname.glob(lib/'*.dylib') do |dylib|
      lib.install_symlink dylib.basename => "#{dylib.basename(".dylib")}.so"
    end

    (share/"gdb/auto-load").install Dir["#{lib}/*-gdb.scm"]
  end # install

  test do
    hello = testpath/"hello.scm"
    hello.write <<-EOS.undent
      (display "Hello World")
      (newline)
    EOS

    ENV["GUILE_AUTO_COMPILE"] = "0"

    system bin/"guile", hello
  end # test
end # Guile

__END__
--- old/libguile/dynstack.h	2019-08-02 05:41:06 -0700
+++ new/libguile/dynstack.h	2024-08-21 11:02:08 -0700
@@ -29,12 +29,12 @@
 
 
 
-typedef struct scm_dynstack
+struct scm_dynstack
 {
   scm_t_bits *base;
   scm_t_bits *top;
   scm_t_bits *limit;
-} scm_t_dynstack;
+};
 
 
 
--- old/libguile/posix.c	2024-06-19 11:54:50 -0700
+++ new/libguile/posix.c	2024-08-21 11:48:18 -0700
@@ -1609,7 +1609,7 @@
       default:    /* ENOENT, etc. */
         /* Report the error on the console (before switching to
            'posix_spawn', the child process would do exactly that.)  */
-        dprintf (err, "In execvp of %s: %s\n", exec_file,
+        fprintf (stderr, "In execvp of %s: %s\n", exec_file,
                  strerror (errno_save));
       }
 
--- old/libguile/print.h	2021-09-30 05:30:38 -0700
+++ new/libguile/print.h	2024-08-21 11:00:45 -0700
@@ -61,7 +61,7 @@
   SCM_MAKE_VALIDATE_MSG(pos, a, PRINT_STATE_P, "print-state")
 
 #define SCM_PRINT_STATE_LAYOUT "pwuwuwuwuwuwpwuwuwuwpwpw"
-typedef struct scm_print_state {
+struct scm_print_state {
   SCM handle;			/* Struct handle */
   int revealed;                 /* Has the state escaped to Scheme? */
   unsigned long writingp;	/* Writing? */
@@ -76,7 +76,7 @@
 				   circular reference detection;
 				   a vector. */
   SCM highlight_objects;        /* List of objects to be highlighted */
-} scm_print_state;
+};
 
 SCM_API SCM scm_print_state_vtable;
 
