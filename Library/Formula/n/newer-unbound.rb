class NewerUnbound < Formula
  desc 'Validating, recursive, caching DNS resolver'
  homepage 'https://nlnetlabs.nl/projects/unbound/about/'
  url 'https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz'
  version '1.19.3'
  sha256 '3ae322be7dc2f831603e4b0391435533ad5861c2322e34a76006a9fb65eb56b9'

  def install
    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test newer-unbound`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
