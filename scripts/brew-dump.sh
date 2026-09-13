#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 1 && "$1" == --all ]]; then
  set --
elif [[ $# -eq 0 ]]; then
  command -v gum >/dev/null || {
    printf 'Install gum: brew install gum\n' >&2
    exit 1
  }
  scope=$(gum choose --header 'Dump' Everything 'Skip App Store' 'Skip VS Code' 'Skip both')
  case "$scope" in
  Everything) ;;
  'Skip App Store') set -- --no-mas ;;
  'Skip VS Code') set -- --no-vscode ;;
  'Skip both') set -- --no-mas --no-vscode ;;
  *) exit 1 ;;
  esac
fi

if [[ -f Brewfile ]]; then
  cp Brewfile Brewfile.bak
fi
exec brew bundle dump --force --file=Brewfile "$@"
