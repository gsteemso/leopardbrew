# FAQ
### How do I update my local packages?
First update the formulæ and Leopardbrew itself:

    brew update

You can now find out what is outdated with:

    brew outdated

Upgrade everything with:

    brew upgrade

Or upgrade a specific formula with:

    brew upgrade $FORMULA

### How do I stop certain formulæ from being updated?
To stop something from being updated/upgraded:

    brew pin $FORMULA

To allow that formulæ to update again:

    brew unpin $FORMULA

<a name="cleanup"></a>
### How do I uninstall old versions of a formula?
By default, Leopardbrew does not uninstall old versions of a formula, so
over time you will accumulate old versions. To remove them, simply use:

    brew cleanup $FORMULA

or clean up everything at once:

    brew cleanup

to see what would be cleaned up:

    brew cleanup -n

<a name="uninstall"></a>
### How do I uninstall Leopardbrew?
To uninstall its ancestor Homebrew, you could at one time paste the command below into a terminal
prompt.  Unfortunately, nothing similar has yet been written for Leopardbrew.

```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
```
In those days, you could download that uninstall script by hand and run `./uninstall --help` to
view more uninstall options.

<a name="uninstall-package"></a>
### How do I uninstall a formula?
If you do not uninstall all of the versions that Leopardbrew has installed, Leopardbrew will
continue to attempt to install the newest version it knows about when you do (`brew upgrade
--all`).  This can be surprising.

To remove a formula entirely, you may do (`brew uninstall formula_name --force`).

Be careful as this is a destructive operation.

### Where does stuff get downloaded?

    brew --cache

Which is usually: `/Library/Caches/Homebrew`

### My Mac `.app`s don’t find `/usr/local/bin` utilities!
GUI apps on OS X don’t have `/usr/local/bin` in their `PATH` by default.
If you’re on Mountain Lion, you can fix this by running
`launchctl setenv PATH "/usr/local/bin:$PATH"`. [More details
here](https://stackoverflow.com/questions/135688/setting-environment-variables-in-os-x/5444960#5444960),
including how to set this across reboots.  If you’re pre-Mountain Lion, [here’s an official
alternative](https://developer.apple.com/legacy/library/qa/qa1067/_index.html).

### How do I contribute to Leopardbrew?
Read everything in https://github.com/gsteemso/leopardbrew/blob/master/CONTRIBUTING.md.

### Why do you compile everything?
Leopardbrew is about **homebrewing**, it’s half the point that you can just `brew edit $FORMULA`
and change how the formula is compiled to your own specification.

Leopardbrew will provide pre-compiled versions for some formulæ.  These pre-compiled versions are
referred to as **bottles** and will at some point be available online.

If available, bottled binaries will be used by default except under the following conditions:

* Options were passed to the install command.  I.e. `brew install $FORMULA` will use a bottled
  version of $FORMULA, but `brew install $FORMULA —enable-bar` will trigger a source build.
* The `--build-from-source` option is invoked.
* The environment variable `HOMEBREW_BUILD_FROM_SOURCE` is set.
* Homebrew is installed to a prefix other than the standard `/usr/local` (although some bottles
  support this).

In order to completely disable bottled builds, simply add a value for the environment variable
`HOMEBREW_BUILD_FROM_SOURCE` to your profile.

We aim to eventually bottle everything.

### How do I get a formula from someone else’s branch?

    brew install hub
    brew update
    cd $(brew --repository)
    hub pull someone_else

(Note:  Whether this still works under Leopardbrew, as opposed to 2016-era Homebrew, has not been
tested.)

Or:

`brew install https://raw.github.com/user/repo/branch/formula.rb`

Or:

`brew pull https://github.com/Homebrew/homebrew/pulls/1234`

<a name="usrlocal"></a>
### Why do Homebrew, Tigerbrew and Leopardbrew so strongly insist that I install to `/usr/local`?

1.  **It’s easier**<br>
    `/usr/local/bin` is already in your `PATH`.
2.  **It’s easier**<br>
    Tons of build scripts break if their dependencies aren’t in either `/usr` or `/usr/local`. We
    fix this for Homebrew formulæ (although we don’t always test for it), but you’ll find that many
    RubyGems and Python setup scripts break which is something outside our control.
3.  **It’s safe**<br>
    Apple has left this directory for us.  Which means there is no `/usr/local` directory by
    default, so there is no need to worry about messing up existing tools.

**If you plan to install gems that depend on brews then save yourself a bunch of hassle and install
to `/usr/local`!**

It is not always straightforward to tell `gem` to look in non-standard directories for headers and
libraries.  If you choose `/usr/local`, many things will “just work”.

<a name="sudo"></a>
### Why does Homebrew say sudo is bad?
**tl;dr** Sudo is dangerous, and you installed TextMate.app without sudo anyway.

Homebrew is designed to work without using sudo.  You can decide to use it but we strongly
recommend not to do so.  If you have used sudo and run into a bug then it is likely to be the cause.
Please don’t file a bug report unless you can reproduce it after reinstalling Homebrew from scratch
without using sudo.

You should only ever sudo a tool you trust.  Of course, you can trust Leopardbrew ;) But do you
trust the multi-megabyte Makefile that Leopardbrew runs?  Developers often understand C++ far
better than they understand make syntax.  It’s too high a risk to sudo such stuff.  It could break
your base system, or alter it subtly.

And indeed, we’ve seen some build scripts try to modify `/usr` even when the prefix was specified
as something else entirely.

Did you `chown root /Applications/TextMate.app`?  Probably not.  So is it that important to
`chown root wget`?

If you need to run Homebrew in a multi-user environment, consider creating a separate user account
especially for use of Homebrew.

There is one near-exception to this:  Some of our software is packaged such that it is insinuated
into the system as a direct replacement of stock software.  This is done by renaming the original
files and making symbolic links to them, so nothing should ever get lost, but sudo permission is
briefly required for that linking step.  We still would never want to _build_ those packages as the
superuser.

### Why isn’t a particular command documented?

If it’s not in `man brew`, it’s probably an external command.  These are documented
[here](External-Commands.md).

### Why haven’t you pulled my pull request?
If it’s been a while, bump it with a “bump” comment.  Sometimes we miss requests and there are
plenty of them.  Maybe we were thinking on something.  It will encourage consideration.  In the
meantime if you could rebase the pull request so that it can be cherry-picked more easily we will
love you for a long time.

### Can I edit formulæ myself?
Yes!  It’s easy!  Just `brew edit $FORMULA`.  You don’t have to submit modifications back to
*gsteemso/leopardbrew*, just edit the formula as you personally need it and `brew install`.  As a
bonus `brew update` will merge your changes with upstream so you can still keep the formula
up-to-date **with** your personal modifications!

### Can I make new formulæ?
Yes!  It’s easy!  Just `brew create URL`.  Homebrew will then open the formula in `$EDITOR` so you
can edit it, but it probably already installs; try it:  `brew install $FORMULA`.  If you come up
with any issues, run the command with the `-d` switch like so:  `brew install -d $FORMULA`, which
drops you into a debugging shell.

If you want your new formula to be part of *gsteemso/leopardbrew* or want to learn more about
writing formulæ, then please read the [Formula Cookbook](Formula-Cookbook.md).

### Can I install my own stuff to `/usr/local`?
Yes, brew is designed to not get in your way so you can use it how you like.

Install your own stuff, but be aware that if you install common libraries like libexpat yourself,
it may cause trouble when trying to build certain Homebrew formulæ.  As a result `brew doctor` will
warn you about unbrewed things in your prefix.

Thus it’s probably better to install your own stuff to the Cellar and then `brew link` it.  Like
so:

```bash
$ cd foo-0.1
$ brew diy
./configure —prefix=/usr/local/Cellar/foo/0.1
$ ./configure —prefix=/usr/local/Cellar/foo/0.1
[snip]
$ make && make install
$ brew link foo
Linking /usr/local/Cellar/foo/0.1… 17 symlinks created
```

### Where was a formula deleted?
Use `brew log $FORMULA` to find out!

Sometimes Homebrew formulæ were moved to specialized repositories.  These were the likely
candidates:

* [https://github.com/Homebrew/homebrew-dupes](https://github.com/Homebrew/homebrew-dupes)
* [https://github.com/Homebrew/homebrew-versions](https://github.com/Homebrew/homebrew-versions)
* [https://github.com/Homebrew/homebrew-games](https://github.com/Homebrew/homebrew-games)

You can use `brew tap` to access these formulæ:

```bash
brew tap homebrew/games
brew install …
```

Note that brew search still finds formula in taps.

Note also that taps don’t currently work.

### What does *keg-only* mean?
It means the formula is installed only into the Cellar; it is not linked into `/usr/local`.  This
means most tools will not find it.  We don’t do this lightly or without reason, and you can still
link in the formula if you need to with `brew link`.

### How can I specify different configure arguments for a formula?
`brew edit $FORMULA` and edit the formula.  Currently there is no other way to do this.
