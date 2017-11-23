# Brewfile

> apps, tools and utilities that I use on my macOS machines

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [Contribute](#contribute)
- [License](#license)

## Install

- These instructions are strictly for me and only me. Please use at your discreation.

- Install Homebrew-file

 ```bash
 $ curl -fsSL https://raw.github.com/rcmdnk/homebrew-file/install/install.sh |sh

 ```

- Add following lines to `~/.zshrc`
 ```bash
 if [ -f $(brew --prefix)/etc/brew-wrap ];then
   source $(brew --prefix)/etc/brew-wrap
 fi
 ```

- Setup GitHub repo
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

The Unlicense © 2017 Mrugesh Mohapatra
