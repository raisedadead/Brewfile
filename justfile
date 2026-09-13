set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments
set dotenv-load := false

export HOMEBREW_NO_ENV_HINTS := "1"

default: help

help:
    @just --list

install +packages:
    brew install "$@"

uninstall +packages:
    brew uninstall "$@"

install-brewfile:
    brew bundle install --file=Brewfile

dump *args:
    brew bundle dump --force --file=Brewfile "$@"

check:
    brew bundle check --file=Brewfile

update:
    brew update
    brew upgrade

clean:
    brew autoremove --dry-run
    brew cleanup --dry-run

doctor:
    brew doctor

list *args:
    brew list "$@"

outdated:
    brew outdated --greedy

audit:
    @printf '\nOutdated packages\n'
    brew outdated --greedy
    @printf '\nUnused dependencies\n'
    brew autoremove --dry-run
    @printf '\nServices\n'
    brew services list

diff:
    git diff HEAD -- Brewfile
