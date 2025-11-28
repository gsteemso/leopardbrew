Leopardbrew
===========

Leopardbrew is a fork of [Tigerbrew][tigerbrew], itself a fork of [Homebrew][homebrew], focussing
on 64‐bit and universal builds.  (Originally, it was also going to properly support pure Darwin –
i.e., non‐Mac‐OS – installations; but Apple have not released one of those since the noughties, and
their proprietary additions mean it is no longer possible to construct one, so that’s no longer the
case.)

Despite the name – which was only chosen to differentiate it from its ancestor – Leopardbrew still
aims for full compatibility with Tiger (Mac OS 10.4 / Darwin 8) systems.  Actually, compatibility
with all Mac OSes from Tiger to the current version is a long‐term design goal (just to stubbornly
prove that it can be done), though it is nowhere near being achieved yet.

Unlike its ancestors, Leopardbrew makes no attempt to support Linux.  The whole point of Linux is
that you have complete control over what’s installed on your system, whereas Homebrew was made
specifically to work around the gaps in a nearly unmodifiable Mac OS install.  Plus, almost every
recipe refers to Mac‐OS‐specific features.  What is even supposed to be the point of supporting
Linux here?  All right, the user interface of Homebrew is pleasantly simple compared to many
Linux‐native package managers, but the design goals are totally divergent.  If a Linux user
absolutely insists on running this anyway, any reasonable Linux system ought to support the actual
Homebrew; use that instead.


Installation
============

You will first need to install the most up‐to‐date version of Xcode compatible with your operating
system.  For Tiger, that’s [Xcode 2.5][xc25]; for Leopard, [Xcode 3.1.4][xc314].  Both downloads
are from Apple and will require an Apple Developer account.  When you have downloaded it, transfer
it to the target machine and install it.

(On Leopard, you also have the option of using the iPhone SDK, which contains an acceptable version
of Xcode.  The last version runnable on PowerPCs, release 9m2621a final 0, was quietly purged from
Apple’s servers many years ago; but if you can find a bootleg copy and apply the handful of minor
text edits required to make it function, it will also install the resources to build for 32-bit ARM
systems as part of Xcode 3.1.2.)

On the computer you’re reading this on, control‐ or secondary‐click this link and save it to disk.
The option will be something like “Save Link As” or “Download Linked File”, depending on your
browser:

<https://raw.githubusercontent.com/gsteemso/leopardbrew/master/go_to/install>

(It used to be, and at times still is, possible to use TenFourFox directly from the target machine;
but that software is no longer maintained, and cannot handle most pages on Github.)

Transfer the saved file to your Tiger or Leopard machine.  On that machine, type `ruby` followed by
a space into your Terminal prompt, then drag and drop the `install` file onto the same Terminal
window, and press return.

You’ll also want to make sure that /usr/local/bin and /usr/local/sbin are in your $PATH.  (In
earlier Mac OS versions, neither is in the default PATH.)  If you use bash as your shell, add this
line to your ~/.bash_profile:

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

`brew help` or `man brew`.  At some point a wiki may be resurrected, but do not hold your breath.

FAQ
---

### How do I switch from Homebrew or Tigerbrew?

Run these commands from your terminal.  You must have git installed.  That’s a non-trivial ask, but
unavoidable.

```sh
cd "$(brew --repository)"
git remote set-url origin https://github.com/gsteemso/leopardbrew.git
git fetch origin
git reset --hard origin/master
```

### Something broke!

Some of the formulæ in the repository have been tested, but there are still vast numbers that have
not; and several that were initially updated to work in Leopardbrew have since been rendered
inoperative again by changes in the offered functionality.  If something doesn’t work (highly
probable), [report a bug][issues] – or submit a [pull request][prs] – and I’ll try to get it
working.

Credits
-------

Homebrew was originally by [mxcl][mxcl].  The Tigerbrew fork is by [Misty De Méo][mistydemeo],
incorporating some code originally written by @sceaga.  This fork is by [Gordon Steemson][gsteemso].

License
-------

Code is under the [BSD 2 Clause (NetBSD) license][license].

[Tigerbrew]:https://github.com/mistydemeo/tigerbrew
[Homebrew]:https://brew.sh
[xc25]:https://developer.apple.com/download/more/?=xcode%202.5
[xc314]:https://developer.apple.com/download/more/?=xcode%203.1.4
[formula]:https://github.com/gsteemso/leopardbrew/tree/master/Library/Formula
[issues]:https://github.com/gsteemso/leopardbrew/issues
[prs]:https://github.com/gsteemso/leopardbrew/pulls
[mxcl]:https://twitter.com/mxcl
[mistydemeo]:https://github.com/mistydemeo
[gsteemso]:https://github.com/gsteemso
[license]:https://github.com/gsteemso/leopardbrew/blob/master/LICENSE.txt
