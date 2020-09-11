# Brewfile

> apps, tools and utilities that I use on my macOS machines

## Prerequisite

If you are the same person as I am, make sure that the initial system setup checklist has been completed.

> System setup checklist: <https://get.ms/setup>

## Installation

> **Warning:** Tools and utlites in the Brewfile work for my config. You should fork, and customize if you would not want your workstation to behave like mine. 

1. Install [Homebrew-file](https://github.com/rcmdnk/homebrew-file) (which will also install Homebrew if not installed already)

   ```bash
   curl -fsSL https://raw.github.com/rcmdnk/homebrew-file/install/install.sh |sh
   ```

2. Add following lines to `~/.zshrc`

   ```bash
   if [ -f $(brew --prefix)/etc/brew-wrap ];then
     source $(brew --prefix)/etc/brew-wrap
   fi
   ```

   or use one-off if you would use [my dotfiles](https://github.com/raisedadead/dotfiles) as well later.
 
   ```bash
   source $(brew --prefix)/etc/brew-wrap
   ```
 
3. Setup GitHub repo

   ```bash
   brew file set_repo
   # raisedadead/Brewfile
   ```

## Usage

- Setup the tools, utilites for the first time on a fresh computer

  ```bash
  brew file install
  ```

- Or add/update the existing setup

  ```
  brew file update
  ```
  
- Or edit the current setup

  ```
  brew file edit
  ```

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
