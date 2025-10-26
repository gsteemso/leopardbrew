# Leopardbrew and Python

## Overview

This page describes how Python is handled in Leopardbrew for users.  See [Python for Formula Authors](Python-for-Formula-Authors.md)
for advice on writing formulæ to install packages written in Python.

Leopardbrew should work with any [CPython](https://stackoverflow.com/questions/2324208/is-there-any-difference-between-cpython-and-python)
and defaults to the Mac OS system Python, though this will not work very well on older systems and you will probably have to
install Leopardbrew’s `python3` formula to get anything useful done.  You may need to install the `python2` formula as well, as many
less‐frequently‐updated formulæ still depend on it.

**Important:**  If you choose to install a Python which isn’t either of these (system Python or brewed Python), the Leopardbrew
maintainer can only provide very limited support.

## Python 2.x or Python 3.x

Leopardbrew provides a formula for Python 2.7.18 and one for Python 3.x.  They don’t conflict, so they can both be installed.  The
executable `python2` will always point to the 2.7 version and `python3` to the 3.x version.  Plain “python” usually now refers to
`python3`, rather than `python2` as was traditionally the case; the world marches on and Python 2 is now distinctly obsolete.

## Setuptools, Pip, etc.

The Python formulæ install [`pip`](http://www.pip-installer.org) and [Setuptools](https://pypi.python.org/pypi/setuptools).

Setuptools can be updated via Pip, without having to re-brew Python:

    pip install --upgrade setuptools

Similarly, Pip can be used to upgrade itself via:

    pip install --upgrade pip

### Note on `pip install --user`

The normal `pip install --user` is disabled for brewed Python.  This is because of a bug in distutils, because Leopardbrew writes a
`distutils.cfg` which sets the package `prefix`.

A possible workaround (which puts executable scripts in `~/Library/Python/<X>.<Y>/bin`) is:

    pip install --user --install-option="--prefix=" <package-name>

You can make this “empty prefix” the default by adding a `~/.pydistutils.cfg` file with the following contents:

    [install]
    prefix=

## `site-packages` and the `PYTHONPATH`

The `site-packages` is a directory that contains Python modules (especially bindings installed by other formulæ).  Leopardbrew
creates it here:

    $(brew --prefix)/lib/pythonX.Y/site-packages

So, for Python 2.7.18, you’ll find it at `/usr/local/lib/python2.7/site-packages`.

Python 2.7 also searches for modules in:

  - `/Library/Python/2.7/site-packages`
  - `~/Library/Python/2.7/lib/python/site-packages`

Leopardbrew’s `site-packages` directory is first created if (1) any Leopardbrew formula with Python bindings are installed, or (2)
upon `brew install python2` or `brew install python3`.

### Why here?

The reasoning for this location is to preserve your modules between (minor) upgrades or reïnstallations of Python.  Additionally,
Leopardbrew has a strict policy never to write stuff outside of the `brew --prefix`, so we don’t spam your system.

## Leopardbrew-provided Python bindings

Some formulæ provide python bindings.  Sometimes a `--with-python2` or `--with-python3` option has to be passed to `brew install`
in order to build the python bindings.  (Check with `brew options <formula>`.)

Note:  Any formula that still refers to “--with-python” instead of “--with-python2” will fail to brew; updates fixing this issue
continue to be rolled out.  This is a vital evolutionary step; at some point in the very near future, “--with-python” will *always*
mean Python 3, as is already the case for the rest of the world.

Leopardbrew builds bindings against the first `python` (and `python-config`) in your `PATH`.  (Check with `which python`).

**Warning!**  Python may crash (see [Common Issues](Common-Issues.md)) if you `import <module>` from a brewed Python if you ran
`brew install <formula_with_python_bindings>` against the system Python.  If you decide to switch to the brewed Python, you should
reinstall all formulæ that include python bindings (e.g. `pyside`, `wxwidgets`, `pygtk`, `pygobject`, `opencv`, `vtk`, and
`boost-python`).

## Policy for non-brewed Python bindings

These should be installed via `pip install <x>`.  To discover, you can use `pip search` or <https://pypi.python.org/pypi>.
(**Note:**  Older system Pythons do not provide `pip`.  Simply `easy_install pip` to fix that.)

## Brewed Python modules

For brewed Python, modules installed with `pip` or `python setup.py install` will be installed to
`$(brew --prefix)/lib/pythonX.Y/site-packages` directory (explained above).  Executable python scripts will be in
`$(brew --prefix)/bin`.

The system Python may not know which compiler flags to set in order to build bindings for software installed in Leopardbrew so you
may need to:

    CFLAGS=-I$(brew --prefix)/include LDFLAGS=-L$(brew --prefix)/lib pip install <package>

## Virtualenv

**WARNING:**  When you `brew install` formulæ that provide Python bindings, you should **not be in an active virtual environment**.

Activate the virtualenv *after* you’ve brewed, or brew in a fresh Terminal window.  Leopardbrew will still install Python modules
into Leopardbrew’s `site-packages` and *not* into the virtual environment’s site-package.

Virtualenv has a switch to allow “global” (i.e. Leopardbrew’s) `site-packages` to be accessible from within the virtualenv.

## Why is Leopardbrew’s Python being installed as a dependency?

Formulæ that depend on the special :python2 or :python3 targets are bottled against the Leopardbrew Pythons, and require the
indicated ones to be installed.  You can avoid installing Leopardbrew’s Pythons by brewing these formulæ with `--build-from-source`.
