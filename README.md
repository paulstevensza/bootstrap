# Bootstrap

Bootstraps a fresh macOS install to turn my laptop into something useful. I like to refresh my macOS install frequently,
and get tired of repeating the process of installing it and then adding in the applications that I find most useful.
It's also a nice staging point for a new Mac.

I think I'll likely be shifting to harder hitting hardware than Apple offer, so a `bootstrap-linux` will soon be in the
works.

### Attribution

Heavily inspired by the awesome work done by [Automantic](https://github.com/atomantic/dotfiles/) on his own dotfiles
repo.

### Usage

Open `Terminal`, and type the following:

```
$ git clone https://github.com/paulstevensza/bootstrap.git ~/.bootstrap
$ cd $_
$ ./bootstrap.sh
```

## What this does

1. Installs Homebrew by fetching the shell script via curl and executes it. We all love running random stuff from the
Internet...so WIN!
2. Runs a `brew update` and runs `brew bundle` to install taps, casks and formulae from `Brewfile`.
3. Sets the current shell to Brew's version of ZSH instead of the baked in version of ZSH that ships with macOS.
4. Shoves dotfiles into `$HOME`.
5. Tells any open System Preferences panes to jog on.
6. Locks down various bits of macOS, as well as tweaks some built-in settings.
7. Imports SSH keys and sets `~/.ssh` to `0700` and all files within it to `0600`. These are sourced from a folder in
Documents that sync to iCloud.
8. Installs some of the fonts I use in iTerm2.
9. Configures iTerm2, which was installed from the `Brewfile`.
10. Installs a hosts file from https://someonewhocares.org/hosts to block junk sites.
11. Configures Atom and installs my most frequently used packages using `apm`.
12. Creates a virtualenv and installs frequently used packages. `pyenv` is installed from `Brewfile` as well.
13. Sets up a very basic workspace for Go.
14. Installs Ruby 2.5.1 using `rbenv`, which was also installed from `Brewfile`.
15. Uses `mas` (yup...`Brewfile`) to install some apps from the App Store.
16. Downloads SteelSeriesEngine for my mouse and Skype, and drops them into `~/Downloads`.

## Todo

* ~Fix anything tagged as a BUG.~
* ~Create a default Python virtualenv.~
* ~Install common Python tools and libraries.~
* ~Install software from the App Store.~
* ~Download additional software.~
* ~Configurations to support Golang.~
* ~Create a default Ruby rbenv.~

## Copyright

Copyright &copy; 2018 Paul Stevens

## Licensed

Licensed under the MIT License. See LICENSE for details.
