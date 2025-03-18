Leopardbrew
===========

Leopardbrew is a fork of [Tigerbrew][tigerbrew], itself a fork of [Homebrew][homebrew],
focussing on universal / 64‐bit builds.  (Originally, it was also going to give
proper support for pure Darwin – i.e., non‐Mac‐OS – installations; but since
Apple have not released one of those since the noughties and their proprietary
additions mean it is no longer possible to construct one, that’s no longer the
case.)  Despite the name (only meant to differentiate it from its ancestor),
Leopardbrew still aims for full compatibility with Tiger (Mac OS 10.4 / Darwin
8) systems.  In principle, compatibility with all Mac OSes from Tiger to the
current version is a design goal, but that is not close to being achieved at
this point.

Unlike its ancestors, Leopardbrew makes no pretense of supporting Linux.  The
whole point of Linux is that you have complete control over what’s installed on
your system, whereas Homebrew was made specifically to work around the gaps in
a nearly unmodifiable Mac OS install.  Plus, darn near every recipe refers to
Mac‐OS‐specific features.  What is even supposed to be the point of supporting
Linux here?

I get that the user interface of Homebrew is nice & simple compared to a lot of
Linux‐native package managers, but the design goals here are totally divergent.
If a Linux user really wants to run this anyway, any halfway modern Linux
system ought to be able to run actual Homebrew; use that instead.


Installation
============

You will first need to install the most up‐to‐date version of Xcode compatible
with your operating system.  For Tiger, that’s [Xcode 2.5][xc25]; for Leopard,
[Xcode 3.1.4][xc314].  Both downloads are from Apple and will require an Apple
Developer account.

On the computer you’re reading this on, control‐ or secondary‐click this link
and save it to disk (the option will be something like “Save Link As” or
“Download Linked File”, depending on your browser):

<https://raw.github.com/gsteemso/leopardbrew/go/install>

(It used to be possible to instead use TenFourFox directly from the target
machine, but that software is no longer maintained and is now unable to fully
handle most pages on Github.)

Transfer the saved file to your Tiger or Leopard machine, along with Xcode.

On the target machine, type `ruby` followed by a space into your Terminal
prompt, then drag and drop the `install` file onto the same Terminal window,
and press return.

You’ll also want to make sure that /usr/local/bin and /usr/local/sbin are in
your PATH.  (Unlike later Mac OS versions, neither is in the default PATH.)
If you use bash as your shell, add this line to your ~/.bash_profile:

```sh
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
```

What Packages Are Available?
----------------------------
1. You can [browse the Formula directory on GitHub][formula].
2. Or type `brew search` for a list.
3. Or use `brew desc` to browse packages from the command line.

More Documentation
------------------
`brew help` or `man brew`.  At some point a wiki may be resurrected, but do not
hold your breath.

FAQ
---

### How do I switch from Homebrew or Tigerbrew?

Run these commands from your terminal.  You must have git installed.

```
cd `brew --repository`
git remote set-url origin https://github.com/gsteemso/leopardbrew.git
git fetch origin
git reset --hard origin/master
```

### Something broke!

Some of the formulae in the repository have been tested, but there are still
vast numbers that haven’t.  If something doesn’t work (highly probable),
[report a bug][issues] – or submit a [pull request][prs] – and I’ll try to get
it working.

Credits
-------

Homebrew was originally by [mxcl][mxcl].  The Tigerbrew fork is by
[Misty De Méo][mistydemeo], incorporating some code originally written by
@sceaga.  This fork is by [Gordon Steemson][gsteemso].

License
-------
Code is under the [BSD 2 Clause (NetBSD) license][license].

[Tigerbrew]:https://github.com/mistydemeo/tigerbrew
[Homebrew]:http://brew.sh
[xc25]:https://developer.apple.com/download/more/?=xcode%202.5
[xc314]:https://developer.apple.com/download/more/?=xcode%203.1.4
[formula]:https://github.com/gsteemso/leopardbrew/tree/master/Library/Formula
[issues]:https://github.com/gsteemso/leopardbrew/issues
[prs]:https://github.com/gsteemso/leopardbrew/pulls
[mxcl]:http://twitter.com/mxcl
[mistydemeo]:https://github.com/mistydemeo
[gsteemso]:https://github.com/gsteemso
[license]:https://github.com/gsteemso/leopardbrew/blob/master/LICENSE.txt
