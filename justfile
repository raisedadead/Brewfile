set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments
set dotenv-load := false

export HOMEBREW_NO_ENV_HINTS := "1"

default: help

help:
    @just --list

install +packages:
    brew install "$@"

[no-exit-message]
uninstall *packages:
    @bash scripts/brew-uninstall.sh "$@"

install-brewfile:
    brew bundle install --file=Brewfile

[no-exit-message]
dump *args:
    @bash scripts/brew-dump.sh "$@"

[no-exit-message]
check:
    @brew bundle check --file=Brewfile --verbose 2>&1 | awk -f scripts/brew-check.awk

[no-exit-message]
drift:
    @HOMEBREW_NO_AUTO_UPDATE=1 brew bundle cleanup --file=Brewfile </dev/null

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
    HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --greedy
    @printf '\nUnused dependencies\n'
    brew autoremove --dry-run
    @printf '\nServices\n'
    brew services list

diff:
    git diff HEAD -- Brewfile
