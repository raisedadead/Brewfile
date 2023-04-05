# Brewfile

> apps, tools and utilities that I use on my macOS machines

## Prerequisite

If you are the same person as I am, make sure that the initial system setup checklist has been completed and tools and packages have been installed.

## Installation

1. Install Homebrew:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install [Homebrew-file](https://github.com/rcmdnk/homebrew-file)

   ```bash
   brew install rcmdnk/file/brew-file
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
