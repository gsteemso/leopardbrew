# stable release 2023-07-30; checked 2025-08-04
require 'merge'

class Gmp < Formula
  include Merge

  desc 'GNU multiple precision arithmetic library'
  homepage 'https://gmplib.org/'
  url 'https://gmplib.org/download/gmp/gmp-6.3.0.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.lz'
  sha256 'be5c908a7a836c3a9bd9d62aa58563c5e9e7fef94c43a7f42dbc35bb6d02733c'

  bottle do
    sha256 'fe8558bf7580c9c8a3775016eccf61249b8d637b1b2970942dba22444c48da7d' => :tiger_altivec
  end

  option :universal

  def install
    # Map Leopardbrew’s CPU‐model symbols to those for configuring a GMP build.
    def lookup(cpu_sym)
      case cpu_sym
        when :g3  then 'powerpc750'
        when :g4  then 'powerpc7400'
        when :g4e then 'powerpc7450'
        when :g5  then 'powerpc970'
        when :core        then 'pentiumm'
        when :penryn      then 'core2'
        when :arrandale   then 'westmere'
        else cpu_sym.to_s  # sandybridge, ivybridge, haswell, broadwell
      end
    end # cpu_lookup

    if build.universal?
      archs = CPU.local_archs
      the_binaries = %w[
        lib/libgmp.10.dylib
        lib/libgmp.a
        lib/libgmpxx.4.dylib
        lib/libgmpxx.a
      ]
      the_headers = %w[
        include/gmp.h
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    build_sym = CPU.model
    tuple_tail = "apple-darwin#{`uname -r`[/^\d+/]}"

    args = [
      "--prefix=#{prefix}",
      '--disable-silent-rules',
      '--enable-cxx',
      "--build=#{found_build = lookup(build_sym)}-#{tuple_tail}",
    ]

    found_host = lookup(host_sym = (build.bottle? \
                                    ? (ARGV.bottle_arch or CPU.oldest) \
                                    : build_sym ) )

    args << "--host=#{found_host}-#{tuple_tail}" if found_host != found_build

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      arch_args = case arch
          when :arm64, :x86_64 then ['ABI=64']
          when :i386 then ['ABI=32']
          when :ppc then host_sym == :g5 ? ['ABI=mode32'] : ['ABI=32']
          when :ppc64 then ['ABI=mode64']
        end
      arch_args << '--disable-assembly' if CPU.bit_width(arch) == 32

      system './configure', *args, *arch_args
      system 'make'
      system 'make', 'check'
      ENV.deparallelize { system 'make', 'install' }

      if build.universal?
        system 'make', 'distclean'
        merge_prep(:binary, arch, the_binaries)
        merge_prep(:header, arch, the_headers)
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
      merge_c_headers(archs)
    end # universal?
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <gmp.h>
      #include <stdlib.h>

      int main() {
        mpz_t i, j, k;
        mpz_init_set_str (i, "1a", 16);
        mpz_init (j);
        mpz_init (k);
        mpz_sqrtrem (j, k, i);
        if (mpz_get_si (j) != 5 || mpz_get_si (k) != 1) abort();
        return 0;
      }
    EOS
    system ENV.cc, 'test.c', "-L#{lib}", '-lgmp', '-o', 'test'
    arch_system './test'
  end # test
end #Gmp
