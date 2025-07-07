### Incompleteness Notice ###
This file was partially updated for the purposes of Tigerbrew, but needs extensive further work
for useability with Leopardbrew.  Among numerous other issues, at present the tap mechanism is no
longer working, and all of the taps listed below were specific to the original Homebrew in any case.
Caveat lector!

# Acceptable Formulae
Some formulae should not go in
[gsteemso/leopardbrew](https://github.com/gsteemso/leopardbrew).  But there are additional
[Interesting Taps & Branches](Interesting-Taps-&-Branches.md), and anyone can start their own!

### We try hard to avoid dupes in gsteemso/leopardbrew
Stuff that comes with Mac OS or libraries that are provided by
[RubyGems, CPAN or PyPi](Gems,-Eggs-and-Perl-Modules.md) should not be duplicated.  There are good
reasons for this:

* Duplicate libraries regularly break builds
* Subtle bugs emerge with duplicate libraries, and to a lesser extent, duplicate tools
* We want our formulae to work with what comes with Mac OS

There are exceptions:

* OpenSSL – Apple has formally deprecated OpenSSL on Mac OS in favour of their own Security
  Framework, & consequently the Mac OS OpenSSL is rarely updated and frequently falls behind
  important security updates.  Homebrew and its successors endeavour to use their respective
  packaged OpenSSL as much as possible.
* Programs that a user will regularly interact with directly, like editors and language runtimes.
* Libraries that provide functionality or contain security updates not found in the system version
  (for example, OpenSSH).
* Things that are **designed to be installed in parallel to earlier versions of themselves.**

#### Examples

  Formula         | Reason
  ---             | ---
  ruby, python, perl    | People want newer versions
  bash            | Mac OS’ Bash is stuck at 3.2 because newer versions are licensed under GPLv3
  zsh             | Homebrew determined that including this was a mistake too firmly entrenched to
                  | remove; but Leopardbrew includes it because the system version from 2009 is
                  | just that outdated.
  emacs, vim      | [Too popular to move to dupes](https://github.com/Homebrew/homebrew/pull/21594#issuecomment-21968819)
  subversion      | Originally added for 10.5, but people want the latest version
  libcurl         | Some formulae require a newer version than Mac OS provides
  openssl         | Mac OS’ OpenSSL is deprecated & outdated
  libxml2         | Historically, Mac OS’ LibXML2 has been buggy

Homebrew also maintains [a tap](https://github.com/Homebrew/homebrew-dupes) that contains many
duplicates not otherwise found in Homebrew.  These packages will be inaccessible until the tap
mechanism is repaired, and even then, most Homebrew packages assume environments far newer than
Tiger or Leopard.

### We don’t like tools that upgrade themselves
Software that can upgrade itself does not integrate well with our upgrade functionality.

### We don’t like install-scripts that download things
Because that circumvents our hash-checks, makes finding/fixing bugs harder, often breaks patches
and disables the caching.  Almost always you can add a resource to the formula file to handle the
separate download and then the installer script will not attempt to load that stuff on demand.  Or
there is a command line switch where you can point it to the downloaded archive in order to avoid
loading.

### We don’t like binary formulae
Our policy is that formulae in the core repository
([gsteemso/leopardbrew](https://github.com/gsteemso/leopardbrew)) must be built from source (or
produce cross-platform executables, like e.g. Java does).  Binary-only formulae should go to
[Homebrew/homebrew-binary](https://github.com/Homebrew/homebrew-binary).  Again, those formulæ will
be unavailable until the tap mechanism is repaired, but almost none of them support PowerPC any
more anyway.

### Stable versions
Formulae in the core repository must have a stable version tagged by the upstream project.
Tarballs are preferred to git checkouts, and tarballs should include the version in the filename
whenever possible.

Software that does not provide a stable, tagged version, or has guidance to always install the most
recent version, should be put in
[Homebrew/homebrew-head-only](https://github.com/Homebrew/homebrew-headonly) or
[homebrew/devel-only](https://github.com/Homebrew/homebrew-devel-only).  Again, those formulæ will
be unavailable until the tap mechanism is repaired.

### Bindings
First check that there is not already a binding available via [`gem`](https://rubygems.org/),
[`pip`](http://www.pip-installer.org/), etc..

If not, then put bindings in the formula they bind to.  This is more useful to end users.  Just
install the stuff!  Having to faff around with foo-ruby foo-perl etc. sucks.

### Niche (or self-submitted) Stuff<a name="Niche_Stuff"></a>
The software in question must be
* maintained (e.g. upstream is still making new releases)
* known
* stable (e.g. not declared "unstable" or "beta" by upstream)
* used
* have a homepage

We will reject formulae that seem too obscure, partly because they won’t get maintained and partly
because we have to draw the line somewhere.

We frown on authors submitting their own work unless it is very popular.

Don’t forget Homebrew is all git underneath!  Maintain your own fork or tap if you have to!

There may be exceptions to these rules in the main repository, we may include things that don’t
meet these criteria or reject things that do.  Please trust that we need to use our discretion
based on our experience running a package manager.

### Stuff that builds a .app
Don’t make your formula build an `.app` (native Mac OS Application); we don’t want those things in
Homebrew.  Make it build a command line tool or a library.  However, we have a few exceptions to
that, e.g. when the App is just additional to CLI or if the GUI-application is non-native for Mac OS
and/or hard to get in binary elsewhere (example: fontforge).  Check out the
[homebrew-cask](https://github.com/caskroom/homebrew-cask) project if you’d like to brew native Mac
OS Applications.

### Building under “superenv” is best
The “superenv” is code Homebrew uses to try to minimize finding undeclared dependencies
accidentally.  Some formulae will only work under the original “standard env” which is selected in
a formula by adding `env :std`, or on the command line by `--env=std`.  The preference for new
formulae is that they be made to work under superenv (which is the default) whenever possible.

### Sometimes there are exceptions
Even if all criteria are met we may not accept the formula.  Documentation tends to lag behind
current decision-making.  Although some rejections may seem arbitrary or strange, they are based
upon years of experience making Homebrew work acceptably for our users.
