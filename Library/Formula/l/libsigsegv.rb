class Libsigsegv < Formula
  desc 'Library for handling page faults in user mode'
  homepage 'https://www.gnu.org/software/libsigsegv/'
  url 'http://ftpmirror.gnu.org/libsigsegv/libsigsegv-2.15.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libsigsegv/libsigsegv-2.15.tar.gz'
  sha256 '036855660225cb3817a190fc00e6764ce7836051bacb48d35e26444b8c1729d9'

  option :universal

  def install
    ENV.universal_binary if build.universal?

    system './configure', '--disable-dependency-tracking',
                          "--prefix=#{prefix}",
                          '--enable-shared'
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    # Sourced from tests/efault1.c in tarball.
    (testpath/'test.c').write <<-EOS.undent
      #include "sigsegv.h"

      #include <errno.h>
      #include <fcntl.h>
      #include <stdio.h>
      #include <stdlib.h>
      #include <unistd.h>

      const char *null_pointer = NULL;
      static int
      handler (void *fault_address, int serious)
      {
        abort ();
      }

      int
      main ()
      {
        if (open (null_pointer, O_RDONLY) != -1 || errno != EFAULT)
          {
            fprintf (stderr, "EFAULT not detected alone.\\n");
            exit (1);
          }

        if (sigsegv_install_handler (&handler) < 0)
          exit (2);

        if (open (null_pointer, O_RDONLY) != -1 || errno != EFAULT)
          {
            fprintf (stderr, "EFAULT not detected with handler.\\n");
            exit (1);
          }

        printf ("Test passed.\\n");
        return 0;
      }
    EOS

    ENV.universal_binary if build.universal?

    system ENV.cc, 'test.c', "-L#{lib}", '-lsigsegv', '-o', 'test'
    result = TRUE
    for_archs('./test') { |_, cmd| result &&= assert_match /Test passed/, shell_output(cmd * ' ') }
    result
  end
end
