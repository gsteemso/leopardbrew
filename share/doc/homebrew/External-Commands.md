# External Commands
Leopardbrew, like Git, supports *external commands*.  This lets you create new commands that can be
run like:

```
$ brew mycommand --option1 --option3 formula
```

without modifying Leopardbrew’s internals.

## COMMAND TYPES
External commands come in two flavors:  Ruby commands and shell scripts.

In both cases, the command file should be executable (`chmod +x`) and live somewhere in `$PATH`.

### RUBY COMMANDS
An external command `extcmd` implemented as a Ruby command should be named `brew-extcmd.rb`.  The
command is executed by doing a `require` on the full pathname.  As the command is `require`d, it
has full access to the Leopardbrew “environment”, i.e. all global variables and modules that any
internal command has access to.

The command may `Kernel.exit` with a status code if it needs to; if it doesn’t explicitly exit then
Leopardbrew will return 0.

### SHELL SCRIPTS
A shell script for an command named `extcmd` should be named `brew-extcmd`.  This file will be run
via `exec` with some Leopardbrew variables set as environmental variables, and passed any
additional command-line arguments.

<table>
  <tr>
    <td><strong>Variable</strong></td>
    <td><strong>Description</strong></td>
	</tr>
  <tr>
    <td>HOMEBREW_CACHE</td>
		<td>Where Leopardbrew caches downloaded tarballs to, typically
		    <code>/Library/Caches/Homebrew</code>.</td>
	</tr>
  <tr>
    <td>HOMEBREW_CELLAR</td>
		<td>The location of the Leopardbrew Cellar, where software is staged.  This will be
		    <code>$HOMEBREW_PREFIX/Cellar</code> if that directory exists, or
		    <code>$HOMEBREW_REPOSITORY/Cellar</code> otherwise (the latter case is the norm in
		    Leopardbrew).</td>
  </tr>
  <tr>
    <td>HOMEBREW_LIBRARY_PATH</td>
		<td>The directory containing Leopardbrew’s own application code.</td>
	</tr>
  <tr>
    <td>HOMEBREW_PREFIX</td>
		<td>Where Leopardbrew installs software.  This is <code>/usr/local</code> by default.</td>
	</tr>
  <tr>
    <td>HOMEBREW_REPOSITORY</td>
		<td>If installed from a Git clone (the usual case), the repo directory (i.e., where
		    Leopardbrew’s <code>.git</code> directory lives).</td>
  </tr>
</table>

Note that the script itself can use any suitable shebang (`#!`) line, so an external “shell script”
can be written for sh, bash, Ruby, or anything else.

## USER-SUBMITTED COMMANDS
These commands have been contributed by Leopardbrew users but are not included in the main
Leopardbrew repository, nor are they installed by the installer script.  You can install them
manually, as outlined above.

>*NOTE:* They are largely untested, and as always, be careful about running untested code on your
machine.

### brew-livecheck
> Check if there is a new upstream version of a formula.
>
> See the [`README`](https://github.com/youtux/homebrew-livecheck/blob/master/README.md) for more
> info and usage.
>
> Install using:
> ```
> $ brew tap youtux/livecheck
> ```

### brew-any-tap

> Like `brew tap` but works on *any* git repository, whether public or private, on GitHub or not.
>
> Install using (ironically enough) `brew tap`:
>
> ```
> brew tap telemachus/anytap
> brew install brew-any-tap
> ```
>
> See the  [`README`](https://github.com/telemachus/homebrew-anytap/blob/master/README.md) for
> further explanation and examples of use.

### brew-cask

>Install .app and other "Drag to install" packages from Leopardbrew.
>
> https://github.com/caskroom/homebrew-cask
>
> Install using:
> ```
> $ brew tap caskroom/cask
> $ brew install brew-cask
> ```

### brew-desc
>Get short descriptions for Leopardbrew formulae or search formulae by description:
>[https://github.com/telemachus/brew-desc](https://github.com/telemachus/homebrew-desc)
>
>You can install manually or using `brew tap`:
> ```
> $ brew tap telemachus/desc
> ```

### brew-gem
>Install any gem package into a self-contained Leopardbrew cellar location:
><https://github.com/sportngin/brew-gem>
>
>*Note:* This can also be installed with `brew install brew-gem`.

### brew-growl
>Get Growl notifications for Leopardbrew https://github.com/secondplanet/brew-growl

### brew-more
>Scrapes a formula’s homepage to get more information:
>[https://gist.github.com/475200](https://gist.github.com/475200)

### brew-services
>Simple support to start formulae using launchctl, has out of the box support for any formula which
>defines `startup_plist` (e.g. mysql, postgres, redis u.v.m.):
>[https://github.com/gapple/homebrew-services](https://github.com/gapple/homebrew-services)
>
> Install using:
> ```
> $ brew tap gapple/services
> ```

## SEE ALSO
Leopardbrew Docs: <https://github.com/gsteemso/leopardbrew/tree/master/share/doc/homebrew>
