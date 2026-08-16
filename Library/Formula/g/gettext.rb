# stable release 2026-01-29; checked 2026-07-22
require 'merge'

class Gettext < Formula
  include Merge

  desc 'GNU internationalization (i18n) and localization (l10n) library'
  homepage 'https://www.gnu.org/software/gettext/'
  # Fetching the LZIPped version of this package, rather than the XZ-compressed one, lets {xz} use NLS without forming a dependency
  # loop.  It’s also a smaller download.
  url 'http://ftpmirror.gnu.org/gettext/gettext-1.0.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.lz'
  sha256 'd6342cbe1411a2fe7d139bfed80c2d63b1babc92acfedc72501cc105184f61ee'

  # Neither gettext nor libintl have ever been present on any version of Mac OS.  The Homebrew (& Tigerbrew) maintainers presumably
  # made this package keg‐only because Mac OS DOES include its counterpart, libiconv, which is thus rightly keg‐only; but the range
  # & extent of problems caused by {gettext}’s invisibility to other packages justify reversing that here.  The mechanisms that let
  # keg‐only packages work are meant for library linkage and can’t easily make up for executables being hidden.  In other words, to
  # use gettext without jumping through hoops requires that its bin/ be visible, which in turn requires that its keg be linked.

  option :tests, 'Run the build-time unit tests (fails on older systems)'
  option :universal

  enhanced_by 'libiconv'

  def install
    if build.universal?
      Target.allow_universal_binary
      the_binaries = %w[envsubst gettext msgattrib msgcat msgcmp msgcomm msgconv msgen msgexec msgfilter msgfmt msggrep msginit
                        msgmerge msgpre msgunfmt msguniq ngettext printf_gettext printf_ngettext recode-sr-latin xgettext
                     ].map{ |f| "bin/#{f}" } \
                   + %w[asprintf.0.dylib asprintf.a gettextlib.a gettextlib-1.0.dylib gettextpo.0.dylib gettextpo.a gettextsrc.a
                        gettextsrc-1.0.dylib intl.8.dylib intl.a textstyle.0.dylib textstyle.a].map{ |f| "lib/lib#{f}" } \
                   + %w[cldr-plurals hostname urlget].map{ |f| "libexec/gettext/#{f}" }
    end # build universal?
    archs = Target.partitioned_archset(:word_size)
    args = [
        "--prefix=#{prefix}",
        '--disable-debug',
        '--disable-dependency-tracking',
        '--disable-silent-rules',
        '--with-included-gettext',
        '--with-included-libunistring',
        '--with-included-libxml',
        "--with-lispdir=#{share}/emacs/site-lisp/gettext",
        '--without-git', # Don't use a VCS to create the infrastructure archive.
        '--without-xz'   # Avoid a dependency loop.
      ]
    args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" if active_enhancement_names.include? 'libiconv'
    mkdir 'build'
    archs.each do |partition|
      ENV.set_build_archs(partition) if build.universal?
      arch_args = []
      arch_args << '--enable-year2038' if Target._64b?(partition)

      cd 'build' do
        checkpoint (partition.is_a?(Hash) ? partition.keys.first : partition) do
          system '../configure', *args, *arch_args
          system 'make'
          system 'make', 'check' if build.with? 'tests' and Target.build_will_run?(partition)
        end
        system 'make', 'install'

        if build.universal?
          ENV.deparallelize { system 'make', 'distclean' }
          merge_prep(:binary, partition, the_binaries)
        end # build universal?
      end # cd build/
    end # each |partition|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
      # Besides the binaries, the Emacs .elc files (bytecoded Lisp) also differ… in the compilation timestamps.  Ignore.
    end # build universal?
  end # install

  def caveats; <<-_.undent
      GNU Gettext and GNU Libiconv are circularly interdependent.  {libiconv} depends
      explicitly on {gettext} – which means that {gettext} will be brewed for you, if
      it wasn’t already, when you brew {libiconv}.  The reverse can’t be done because
      of the circular dependency.

      TL,DR:  To ensure both packages work correctly, once {libiconv} has been brewed,
      you should `brew reinstall gettext`.

      (They should be brewed in this order because Mac OS does include a very basic –
      if outdated – libiconv, but has never included gettext.)
    _
  end # caveats

  test do
    arch_system "#{bin}/gettext", '--version'
    arch_system "#{bin}/gettext", '--help'
  end # test
end # Gettext
