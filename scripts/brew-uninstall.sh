#!/usr/bin/env bash
set -euo pipefail

if (($#)); then
  exec brew uninstall "$@"
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  printf 'Use: just uninstall PACKAGE…\n' >&2
  exit 1
fi

command -v gum >/dev/null || {
  printf 'Install gum: brew install gum\n' >&2
  exit 1
}

category=$(gum choose --header 'Remove from' Formulae Casks Taps 'App Store')
case "$category" in
Formulae)
  list=(brew list --formula --full-name)
  remove=(brew uninstall --formula)
  ;;
Casks)
  list=(brew list --cask)
  remove=(brew uninstall --cask)
  ;;
Taps)
  list=(brew tap)
  remove=(brew untap)
  ;;
'App Store')
  list=(mas list)
  remove=(sudo mas uninstall)
  ;;
*) exit 1 ;;
esac

packages=$("${list[@]}")
if [[ -z "$packages" ]]; then
  printf 'Nothing installed.\n'
  exit 0
fi

selected=$(printf '%s\n' "$packages" | gum filter --no-limit --header "Remove $category")
[[ -n "$selected" ]] || exit 0

names=()
while IFS= read -r name; do
  if [[ "$category" == 'App Store' ]]; then
    read -r name _ <<<"$name"
    [[ "$name" =~ ^[0-9]+$ ]] || exit 1
  fi
  names+=("$name")
done <<<"$selected"

exec "${remove[@]}" "${names[@]}"
