brew(1) -- The missing package manager for OS X
===============================================

## SYNOPSIS

`brew` --version<br>
`brew` command [--verbose|-v] [options] [formula] ...

## DESCRIPTION

Leopardbrew is the easiest and most flexible way to install the UNIX tools Apple
didn't include with OS X.

## ESSENTIAL COMMANDS

For the full command list, see the COMMANDS section.

With `--verbose` or `-v`, many commands print extra debugging information.
Note that these flags should only appear after a command.

  * `install` <formula>:
    Install <formula>.

  * `remove` <formula>:
    Uninstall <formula>.

  * `update`:
    Fetch the newest version of Leopardbrew from GitHub using `git`(1).

  * `list`:
    List all installed formulæ.

  * `search` <text>|/<text>/:
    Perform a substring search of formula names for <text>.  If <text> is
    surrounded with slashes, then it is interpreted as a regular expression.
    Back when Leopardbrew was still Homebrew, the search for <text> was extended
    online to some popular taps, but Homebrew continued to evolve in a different
    direction and none of its taps still work with Leopardbrew.

    If no search term is given, all locally available formulæ are listed.

## COMMANDS

  * `audit` [--strict] [--online] [<formulæ>]:
    Check <formulæ> for Leopardbrew coding style violations.  This should be
    run before submitting a new formula.

    If no <formulæ> are provided, all of them are checked.

    If `--strict` is passed, additional checks are run.  This should be used
    when creating for new formulæ.

    If `--online` is passed, additional slower checks that require a network
    connection are run.  This should be used when creating new formulæ.

    `audit` exits with a non-zero status if any errors are found.  This is useful,
    for instance, for implementing pre-commit hooks.

  * `cat` <formula>:
    Display the source to <formula>.

  * `cleanup [--force] [--prune=<days>] [-ns]` [<formulæ>]:
    For specific or all installed formulæ, remove any older versions from the
    cellar.  By default, does not remove out-of-date keg-only brews, as other
    software may link directly to specific versions.  In addition old downloads from
    the Leopardbrew download-cache are deleted.

    If `--force` is passed, remove out-of-date keg-only brews as well.

    If `--prune=<number>` is specified, remove all cache files older than <number> days.

    If `-n` is passed, show what would be removed, but do not actually remove anything.

    If `-s` is passed, scrubs the cache, removing downloads for even the latest
    versions of formula.  Note downloads for any installed formula will still not be
    deleted.  If you want to delete those too: `rm -rf $(brew --cache)/*`

  * `command` <cmd>:
    Display the path to the file which is used when invoking `brew <cmd>`.

  * `commands [--quiet [--include-aliases]]`:
    Show a list of built-in and external commands.

    If `--quiet` is passed, list only the names of commands without the header.
    With `--include-aliases`, the aliases of internal commands will be included.

  * `config`:
    Show Leopardbrew and system configuration useful for debugging.  If you file
    a bug report, you will likely be asked for this information if you do not
    provide it.

  * `create <URL> [--autotools|--cmake] [--no-fetch] [--set-name <name>] [--set-version <version>]`:
    Generate a formula for the downloadable file at <URL> and open it in the editor.
    Leopardbrew will attempt to automatically derive the formula name
    and version, but if it fails, you'll have to make your own template.  The wget
    formula serves as a simple example.  For a complete cheat-sheet, have a look at

    <https://github.com/gsteemso/leopardbrew/blob/combined/share/doc/homebrew/Formula-Cookbook.md>

    If `--autotools` is passed, create a basic template for an Autotools-style build.
    If `--cmake` is passed, create a basic template for a CMake-style build.

    If `--no-fetch` is passed, Leopardbrew will not download <URL> to the cache and
    will thus not add the SHA256 to the formula for you.

    The options `--set-name` and `--set-version` each take an argument and allow
    you to explicitly set the name and version of the package you are creating.

  * `deps [--1] [-n] [--union] [--tree] [--all] [--installed] [--skip-build] [--skip-optional]` <formulæ>:
    Show dependencies for <formulæ>.  When given multiple formula arguments,
    show the intersection of dependencies for <formulæ>, except when passed
    `--tree`, `--all`, or `--installed`.

    If `--1` is passed, only show dependencies one level down, instead of
    recursing.

    If `-n` is passed, show dependencies in topological order.

    If `--union` is passed, show the union of dependencies for <formulæ>,
    instead of the intersection.

    If `--tree` is passed, show dependencies as a tree.

    If `--all` is passed, show dependencies for all formulæ.

    If `--installed` is passed, show dependencies for all installed formulæ.

    By default, `deps` shows dependencies for <formulæ>.  To skip the `:build`
    type dependencies, pass `--skip-build`.  Similarly, pass `--skip-optional`
    to skip `:optional` dependencies.

  * `desc` <formula>:
    Display <formula>’s name and one‐line description.

  * `desc [-s|-n|-d] <pattern>`:
    Search both name and description (`-s`), just the names (`-n`), or just the
    descriptions (`-d`) for `<pattern>`.  `<pattern>` is by default interpreted
    as a literal string; if flanked by slashes, it is instead interpreted as a
    regular expression.  Formula descriptions are cached; the cache is created on
    the first search, making that search slower than subsequent ones.

  * `diy [--name=<name>] [--version=<version>]`:
    Automatically determine the installation prefix for non-Leopardbrew software.

    Using the output from this command, you can install your own software into
    the Cellar and then link it into Leopardbrew's prefix with `brew link`.

    The options `--name=<name>` and `--version=<version>` each take an argument
    and allow you to explicitly set the name and version of the package you are
    installing.

  * `doctor`:
    Check your system for potential problems.  Doctor exits with a non-zero status
    if any problems are found.

  * `edit`:
    Open all of Leopardbrew for editing.

  * `edit` <formula>:
    Open <formula> in the editor.

  * `fetch [--force] [-v] [--devel|--HEAD] [--deps] [--build-from-source|--force-bottle]` <formulæ>:
    Download the source packages for the given <formulæ>.
    For tarballs, also print SHA1 and SHA-256 checksums.

    If `--HEAD` or `--devel` is passed, fetch that version instead of the
    stable version.

    If `-v` is passed, do a verbose VCS checkout, if the URL represents a VCS.
    This is useful for seeing if an existing VCS cache has been updated.

    If `--force` is passed, remove a previously cached version and re-fetch.

    If `--deps` is passed, also download dependencies for any listed <formulæ>.

    If `--build-from-source` is passed, download the source rather than a
    bottle.

    If `--force-bottle` is passed, download a bottle if it exists for the current
    version of OS X, even if it would not be used during installation.

  * `home`:
    Open Leopardbrew's own homepage in a browser.

  * `home` <formula>:
    Open <formula>'s homepage in a browser.

  * `info` <formula>:
    Display information about <formula>.

  * `info --github` <formula>:
    Open a browser to the GitHub History page for formula <formula>.

    To view formula history locally: `brew log -p <formula>`.

  * `info --json=<version>` (--all|--installed|<formulæ>):
    Print a JSON representation of <formulæ>.  Currently the only accepted value
    for <version> is `v1`.

    Pass `--all` to get information on all formulæ, or `--installed` to get
    information on all installed formulæ.

    See the docs for examples of using the JSON:
    <https://github.com/gsteemso/leopardbrew/blob/combined/share/doc/homebrew/Querying-Brew.md>

  * `install [--debug] [--env=<std|super>] [--ignore-dependencies] [--only-dependencies] [--cc=<compiler>] [--build-from-source|--force-bottle] [--devel|--HEAD]` <formula>:
    Install <formula>.

    <formula> is usually the name of the formula to install, but it can be specified
    several different ways.  See [SPECIFYING FORMULAE][].

    If `--debug` is passed and brewing fails, open an interactive debugging
    session with access to IRB or a shell inside the temporary build directory.

    If `--env=std` is passed, use the standard build environment instead of superenv.

    If `--env=super` is passed, use superenv even if the formula specifies the
    standard build environment.

    If `--ignore-dependencies` is passed, skip installing any dependencies of
    any kind.  If they are not already present, the formula will probably fail
    to install.

    If `--only-dependencies` is passed, install the dependencies with specified
    options but do not install the specified formula.

    If `--cc=<compiler>` is passed, attempt to compile using <compiler>.
    <compiler> should be the name of the compiler's executable, for instance
    `gcc-4.2` for Apple's GCC 4.2, or `gcc-4.9` for a Leopardbrew-provided GCC
    4.9.

    If `--build-from-source` is passed, compile from source even if a bottle
    is provided for <formula>.

    If `--force-bottle` is passed, install from a bottle if it exists
    for the current version of OS X, even if custom options are given.

    If `--devel` is passed, and <formula> defines it, install the development version.

    If `--HEAD` is passed, and <formula> defines it, install the HEAD version,
    aka master, trunk, unstable.

    To install a newer version of HEAD use
    `brew rm <foo> && brew install --HEAD <foo>`.

  * `install --interactive [--git]` <formula>:
    Download and patch <formula>, then open a shell.  This allows the user to
    run `./configure --help` and otherwise determine how to turn the software
    package into a Leopardbrew formula.

    If `--git` is passed, Leopardbrew will create a Git repository, useful for
    creating patches to the software.

  * `irb [--examples]`:
    Enter the interactive Leopardbrew Ruby shell.

    If `--examples` is passed, several examples will be shown.

  * `leaves`:
    Show installed formulæ that are not dependencies of another installed formula.

  * `ln`, `link [--overwrite] [--dry-run] [--force]` <formula>:
    Symlink all of <formula>'s installed files into the Leopardbrew prefix.  This
    is done automatically when you install formulæ but can be useful for DIY
    installations.

    If `--overwrite` is passed, Leopardbrew will delete files which already exist in
    the prefix while linking.

    If `--dry-run` or `-n` is passed, Leopardbrew will list all files which would
    be linked or which would be deleted by `brew link --overwrite`, but will not
    actually link or delete any files.

    If `--force` is passed, Leopardbrew will allow keg-only formulæ to be linked.

  * `linkapps [--local]` [<formulæ>]:
    Find installed formulæ that have compiled `.app`-style "application"
    packages for OS X, and symlink those apps into `/Applications`, allowing
    for easier access.

    If no <formulæ> are provided, all of them will have their .apps symlinked.

    If provided, `--local` will move them into the user's `~/Applications`
    directory instead of the system directory.  It may need to be created, first.

  * `ls`, `list [--full-name]`
    List all installed formulæ.  If `--full-name` is passed, print formulæ with
    full-qualified names.

  * `ls`, `list --unbrewed`
    List all files in the Leopardbrew prefix not installed by Leopardbrew.

  * `ls`, `list [--versions [--multiple]] [--pinned]` [<formulæ>]:
    List the installed files for <formulæ>.  Combined with `--verbose`, recursively
    list the contents of all subdirectories in each <formula>'s keg.

    If `--versions` is passed, show the version number for installed formulæ,
    or only the specified formulæ if <formulæ> are given.  With `--multiple`,
    only show formulæ with multiple versions installed.

    If `--pinned` is passed, show the versions of pinned formulæ, or only the
    specified (pinned) formulæ if <formulæ> are given.
    See also `pin`, `unpin`.

  * `log [git-log-options]` <formula> ...:
    Show the git log for the given formulæ.  Options that `git-log`(1)
    recognizes can be passed before the formula list.

  * `missing` [<formulæ>]:
    Check the given <formulæ> for missing dependencies.

    If no <formulæ> are given, check all installed brews.

  * `migrate [--force]` <formulæ>:
    Migrate renamed packages to new name, where <formulæ> are old names of
    packages.

    If `--force` is passed, then treat installed <formulæ> and passed <formulæ>
    like if they are from same taps and migrate them anyway.

  * `options [--compact] [--all] [--installed]` <formula>:
    Display install options specific to <formula>.

    If `--compact` is passed, show all options on a single line separated by
    spaces.

    If `--all` is passed, show options for all formulæ.

    If `--installed` is passed, show options for all installed formulæ.

  * `outdated [--quiet | --verbose | --json=v1 ]`:
    Show formulæ that have an updated version available.

    By default, version information is displayed in interactive shells, and
    suppressed otherwise.

    If `--quiet` is passed, list only the names of outdated brews (takes
    precedence over `--verbose`).

    If `--verbose` is passed, display detailed version information.

    If `--json=<version>` is passed, the output will be in JSON format.  The only
    valid version is `v1`.

  * `pin` <formulæ>:
    Pin the specified <formulæ>, preventing them from being upgraded when
    issuing the `brew upgrade` command.  See also `unpin`.

  * `prune`:
    Remove dead symlinks from the Leopardbrew prefix.  This is generally not
    needed, but can be useful when doing DIY installations.

  * `reinstall` <formula>:
    Uninstall then install <formula>

  * `rm`, `remove`, `uninstall [--force]` <formula>:
    Uninstall <formula>.

    If `--force` is passed, and there are multiple versions of <formula>
    installed, delete all installed versions.

  * `search`, `-S`:
    Display all locally available formulæ for brewing (including tapped ones).
    No online search is performed if called without arguments.

  * `search`, `-S` <text>|/<text>/:
    Perform a substring search of formula names for <text>.  If <text> is
    surrounded with slashes, then it is interpreted as a regular expression.
    The search for <text> is extended online to some popular taps.

  * `search --debian`|`--fedora`|`--fink`|`--macports`|`--opensuse`|`--ubuntu` <text>:
    Search for <text> in the given package manager's list.

  * `sh [--env=std]`:
    Instantiate a Leopardbrew build environment.  Uses our years-battle-hardened
    Leopardbrew build logic to help your `./configure && make && make install`
    or even your `gem install` succeed.  Especially handy if you run Leopardbrew
    in a Xcode-only configuration since it adds tools like make to your PATH
    which otherwise build-systems would not find.

  * `switch` <name> <version>:
    Symlink all of the specific <version> of <name>'s install to Leopardbrew prefix.

  * `tap` [--full] [<user/repo>] [<URL>]:
    Tap a formula repository or list existing taps.  This command can be invoked
    in three ways.

    + `tap` without arguments displays existing taps.

    + `tap <user/repo>` taps a formula repository from GitHub using HTTPS.
      Since so many taps are hosted on GitHub, this command is a shortcut for
      `tap user/repo https://github.com/#{user}/homebrew-#{repo}`.

    + `tap <user/repo> <URL>` taps a formula repository from anywhere, using
      any transport protocol that `git` handles.  The one-argument form of `tap`
      simplifies but also limits.   This two-argument command makes no
      assumptions, so taps can be cloned from places other than GitHub and
      using protocols other than HTTPS, e.g., SSH, GIT, HTTP, FTP(S), RSYNC.

    By default, the repository is cloned as a shallow copy (`--depth=1`), but
    if `--full` is passed, a full clone will be used.

  * `tap --repair`:
    Migrate tapped formulæ from symlink-based to directory-based structure.

  * `tap --list-official`:
    List all official taps.

  * `tap --list-pinned`:
    List all pinned taps.

  * `tap-info` <tap>:
    Display information about <tap>.

  * `tap-info --json=<version>` (--installed|<taps>):
    Print a JSON representation of <taps>.  Currently the only accepted value
    for <version> is `v1`.

    Pass `--installed` to get information on installed taps.

    See the docs for examples of using the JSON:
    <https://github.com/gsteemso/leopardbrew/blob/combined/share/doc/homebrew/Querying-Brew.md>

  * `tap-pin` <tap>:
    Pin <tap>, prioritizing its formulæ over core when formula names are supplied
    by the user.  See also `tap-unpin`.

  * `tap-unpin` <tap>:
    Unpin <tap> so its formulæ are no longer prioritized.  See also `tap-pin`.

  * `test` [--devel|--HEAD] [--debug] <formula>:
    A few formulæ provide a test method.  `brew test <formula>` runs this
    test method.  There is no standard output or return code, but it should
    generally indicate to the user if something is wrong with the installed
    formula.

    To test the development or head version of a formula, use `--devel` or
    `--HEAD`.

    If `--debug` is passed and the test fails, an interactive debugger will be
    launched with access to IRB or a shell inside the temporary test directory.

    Example: `brew install jruby && brew test jruby`

  * `unlink [--dry-run]` <formula>:
    Remove symlinks for <formula> from the Leopardbrew prefix.  This can be useful
    for temporarily disabling a formula:
    `brew unlink foo && commands && brew link foo`.

    If `--dry-run` or `-n` is passed, Homebrew will list all files which would
    be unlinked, but will not actually unlink or delete any files.

  * `unlinkapps [--local]` [<formulæ>]:
    Removes links created by `brew linkapps`.

    If no <formulæ> are provided, all linked app will be removed.

  * `unpack [--git|--patch] [--destdir=<path>]` <formulæ>:
    Unpack the source files for <formulæ> into subdirectories of the current
    working directory.  If `--destdir=<path>` is given, the subdirectories will
    be created in the directory named by `<path>` instead.

    If `--patch` is passed, patches for <formulæ> will be applied to the
    unpacked source.

    If `--git` is passed, a Git repository will be initalized in the unpacked
    source.  This is useful for creating patches for the software.

  * `unpin` <formulæ>:
    Unpin <formulæ>, allowing them to be upgraded by `brew upgrade`.  See also
    `pin`.

  * `untap` <tap>:
    Remove a tapped repository.

  * `update [--rebase]`:
    Fetch the newest version of Leopardbrew and all formulæ from GitHub using
     `git`(1).

    If `--rebase` is specified then `git pull --rebase` is used.

  * `upgrade [install-options]` [<formulæ>]:
    Upgrade outdated, unpinned brews.

    Options for the `install` command are also valid here.

    If <formulæ> are given, upgrade only the specified brews (but do so even
    if they are pinned; see `pin`, `unpin`).

  * `uses [--installed] [--recursive] [--skip-build] [--skip-optional] [--devel|--HEAD]` <formulæ>:
    Show the formulæ that specify <formulæ> as a dependency.  When given
    multiple formula arguments, show the intersection of formulæ that use
    <formulæ>.

    Use `--recursive` to resolve more than one level of dependencies.

    If `--installed` is passed, only list installed formulæ.

    By default, `uses` shows all formulæ that specify <formulæ> as a dependency.
    To skip the `:build` type dependencies, pass `--skip-build`.  Similarly, pass
    `--skip-optional` to skip `:optional` dependencies.

    By default, `uses` shows usages of `formula` by stable builds.  To find
    cases where `formula` is used by development or HEAD build, pass
    `--devel` or `--HEAD`.

  * `--cache`:
    Display Leopardbrew's download cache.  See also `HOMEBREW_CACHE`.

  * `--cache` <formula>:
    Display the file or directory used to cache <formula>.

  * `--cellar`:
    Display Leopardbrew’s Cellar path.  *Default:* `$(brew --prefix)/Cellar`, or if
    that directory doesn't exist, `$(brew --repository)/Cellar`.

  * `--cellar` <formula>:
    Display the location in the cellar where <formula> would be installed,
    without any sort of versioned directory as the last path.

  * `--env`:
    Show a summary of the Leopardbrew build environment.

  * `--prefix`:
    Display Leopardbrew’s install path.  *Default:* `/usr/local`

  * `--prefix` <formula>:
    Display the location in the cellar where <formula> is or would be installed.

  * `--repository`:
    Display where Leopardbrew’s `.git` directory is located.  For standard installs,
    the `prefix` and `repository` are the same directory.

  * `--version`:
    Print the version number of brew to standard error and exit.

## EXTERNAL COMMANDS

Leopardbrew, like `git`(1), supports external commands.  These are executable
scripts that reside somewhere in the PATH, named `brew-<cmdname>` or
`brew-<cmdname>.rb`, which can be invoked like `brew cmdname`.  This allows you
to create your own commands without modifying Leopardbrew’s internals.

Instructions for creating your own commands can be found in the docs:
<https://github.com/gsteemso/leopardbrew/blob/combined/share/doc/homebrew/External-Commands.md>

## SPECIFYING FORMULAE

Many Leopardbrew commands accept one or more <formula> arguments.  These arguments
can take several different forms:

  * The name of a formula:
    e.g.  `git`, `node`, `wget`.

  * The fully-qualified name of a tapped formula:
    Sometimes a formula from a tapped repository may conflict with one in gsteemso/leopardbrew.
    You can still access these formulæ by using a special syntax, e.g.
    `homebrew/dupes/vim` or `homebrew/versions/node4`.

  * An arbitrary URL:
    Leopardbrew can install formulæ via URL, e.g.
    `https://raw.github.com/gsteemso/leopardbrew/combined/Library/Formula/git.rb`.
    The formula file will be cached for later use.

## ENVIRONMENT

  * AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY:
    When using the S3 download strategy, Leopardbrew will look in
    these variables for access credentials (see
    <https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-environment>
    to retrieve these access credentials from AWS).   If they are not set,
    the S3 download strategy will download with a public
    (unsigned) URL.

  * BROWSER:
    If set, and `HOMEBREW_BROWSER` is not, use `BROWSER` as the web browser
    when opening project homepages.

  * EDITOR:
    If set, and `HOMEBREW_EDITOR` and `VISUAL` are not, use `EDITOR` as the text editor.

  * GIT:
    When using Git, Leopardbrew will use `GIT` if set,
    a Leopardbrew-built Git if installed, or the system-provided binary.

    Set this to force Leopardbrew to use a particular git binary.

  * HOMEBREW\_BOTTLE\_DOMAIN:
    If set, instructs Leopardbrew to use the given URL as a download mirror for bottles.

  * HOMEBREW\_BROWSER:
    If set, uses this setting as the browser when opening project homepages,
    instead of the OS default browser.

  * HOMEBREW\_BUILD\_FROM\_SOURCE:
    If set, instructs Leopardbrew to compile from source even when a formula
    provides a bottle.

  * HOMEBREW\_CACHE:
    If set, instructs Leopardbrew to use the given directory as the download cache.

    *Default:* `~/Library/Caches/Homebrew` if it exists; otherwise,
    `/Library/Caches/Homebrew`.

  * HOMEBREW\_CURL\_VERBOSE:
    If set, Leopardbrew will pass `--verbose` when invoking `curl`(1).

  * HOMEBREW\_DEBUG:
    If set, any commands that can emit debugging information will do so.

  * HOMEBREW\_DEBUG\_INSTALL:
    When `brew install -d` or `brew install -i` drops into a shell,
    `HOMEBREW_DEBUG_INSTALL` will be set to the name of the formula being
    brewed.

  * HOMEBREW\_DEBUG\_PREFIX:
    When `brew install -d` or `brew install -i` drops into a shell,
    `HOMEBREW_DEBUG_PREFIX` will be set to the target prefix in the Cellar
    of the formula being brewed.

  * HOMEBREW\_DEVELOPER:
    If set, Leopardbrew will print warnings that are only relevant to Leopardbrew
    developers (active or budding).

  * HOMEBREW\_EDITOR:
    If set, Leopardbrew will use this editor when editing a single formula, or
    several formulæ in the same directory.

    *NOTE*: `brew edit` will open all of Leopardbrew as discontinuous files and
    directories.  TextMate can handle this correctly in project mode, but many
    editors will do strange things in this case.

  * HOMEBREW\_GITHUB\_API\_TOKEN:
    A personal access token for the GitHub API, which you can create at
    <https://github.com/settings/tokens>.  If set, GitHub will allow you a
    greater number of API requests.  See
    <https://developer.github.com/v3/#rate-limiting> for more information.
    Leopardbrew uses the GitHub API for features such as `brew search`.

  * HOMEBREW\_LOGS:
    If set, Leopardbrew will use the given directory to store log files.

  * HOMEBREW\_MAKE\_JOBS:
    If set, instructs Leopardbrew to use the value of `HOMEBREW_MAKE_JOBS` as
    the number of parallel jobs to run when building with `make`(1).

    *Default:*  Four times the number of available CPU cores.

  * HOMEBREW\_NO\_EMOJI:
    If set, Leopardbrew will not print the `HOMEBREW_INSTALL_BADGE` on a
    successful build.

    *Note:*  Leopardbrew will only try to print emoji on Lion or newer.

  * HOMEBREW\_NO\_INSECURE\_REDIRECT:
    If set, Leopardbrew will not permit redirects from secure HTTPS
    to insecure HTTP.

    While ensuring your downloads are fully secure, this is likely
    to cause from-source Sourceforge & GNOME based formulæ
    to fail to download.

    Apache formulæ are currently unaffected by this variable and
    can redirect to plaintext.

  * HOMEBREW\_NO\_GITHUB\_API:
    If set, Leopardbrew will not use the GitHub API for e.g searches or
    fetching relevant issues on a failed install.

  * HOMEBREW\_INSTALL\_BADGE:
    Text printed before the installation summary of each successful build.
    Defaults to the beer emoji.

  * HOMEBREW\_SVN:
    When exporting from Subversion, Leopardbrew will use `HOMEBREW_SVN` if set,
    a Leopardbrew-built Subversion if installed, or the system-provided binary.

    Set this to force Leopardbrew to use a particular svn binary.

  * HOMEBREW\_TEMP:
    If set, instructs Leopardbrew to use `HOMEBREW_TEMP` as the temporary directory
    for building packages.  This may be needed if your system temp directory and
    Leopardbrew Prefix are on different volumes, as OS X has trouble moving
    symlinks across volumes when the target does not yet exist.

    This issue typically occurs when using FileVault or custom SSD
    configurations.

  * HOMEBREW\_VERBOSE:
    If set, Leopardbrew always assumes `--verbose` when running commands.

  * VISUAL:
    If set, and `HOMEBREW_EDITOR` is not, use `VISUAL` as the text editor.

## USING LEOPARDBREW BEHIND A PROXY

Leopardbrew uses several commands for downloading files (e.g.  curl, git, svn).
Many of these tools can download via a proxy.  It's common for these tools
to read proxy parameters from environment variables.

For the majority of cases setting `http_proxy` is enough.  You can set this in
your shell profile, or you can use it before a brew command:

    http_proxy=http://<host>:<port> brew install foo

If your proxy requires authentication:

    http_proxy=http://<user>:<password>@<host>:<port> brew install foo

## SEE ALSO

Leopardbrew Documentation: <https://github.com/gsteemso/leopardbrew/blob/combined/share/doc/homebrew/>

`git`(1), `git-log`(1)

## AUTHORS

Leopardbrew's current maintainer is Gordon Steemson.

Its immediate ancestor, Tigerbrew, is maintained by Misty de Meo.

Homebrew was originally created by Max Howell.

## BUGS

See Issues on GitHub: <http://github.com/gsteemso/leopardbrew/issues>
