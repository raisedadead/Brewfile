# Brewfile

> apps, tools and utilities that I use on my macOS machines

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [License](#license)

## Install

> These instructions work for my config. Please use at your discreation. 

Install Homebrew-file (which will also install Homebrew if not installed already)

 ```bash
 $ curl -fsSL https://raw.github.com/rcmdnk/homebrew-file/install/install.sh |sh

 ```

Add following lines to `~/.zshrc`
 ```bash
 if [ -f $(brew --prefix)/etc/brew-wrap ];then
   source $(brew --prefix)/etc/brew-wrap
 fi
 ```

Setup GitHub repo
 ```bash
 brew file set_repo
 # raisedadead/Brewfile
 ```

## Usage

```bash
brew file install
```

## Maintainers

[@raisedadead](https://github.com/raisedadead)

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
