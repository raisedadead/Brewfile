# Brewfile

Apps, tools, and utilities for my macOS machines.

Run `just` to list commands. Homebrew and Just are required. Pickers use Gum.

| Command | Action |
| --- | --- |
| `just install PACKAGE…` | Install named packages. Accepts Homebrew flags. |
| `just uninstall` | Pick entries to remove. Without a terminal, show how to pass package names. |
| `just uninstall PACKAGE…` | Remove named packages. Accepts Homebrew flags. |
| `just install-brewfile` | Install and upgrade Brewfile entries. |
| `just dump` | Pick a scope in a terminal; otherwise dump everything. Back up the Brewfile first. |
| `just dump --all` | Dump without a picker. |
| `just dump --no-mas --no-vscode` | Dump without App Store apps or VS Code extensions. |
| `just check` | List missing or outdated Brewfile entries. Return failure if work is needed. |
| `just drift` | Preview packages outside the Brewfile and removable cached files. Return failure if packages would be removed. |
| `just update` | Update Homebrew metadata, then upgrade packages. |
| `just clean` | Preview unused dependencies and old files that Homebrew can remove. |
| `just doctor` | Run Homebrew diagnostics. |
| `just list --formula` | List installed formulae. Accepts `brew list` flags. |
| `just outdated` | List outdated packages, including auto-updating casks. |
| `just audit` | Report outdated packages, unused dependencies, and service status. |
| `just diff` | Show Brewfile changes against HEAD. |
| `just commit` | Commit only the Brewfile. Preserve other staged files. |
| `just sync` | Push with Git's configured remote. No automatic rebase. |

The audit uses local Homebrew metadata. Run `brew update` to refresh it.
It does not measure package use or scan for vulnerabilities. It writes no reports.

`just clean` is a preview. Run `brew autoremove` or `brew cleanup` to apply it.
Use `just drift` to preview Brewfile cleanup. It cannot approve removals.
Run `brew bundle cleanup --file=Brewfile` to review and apply that cleanup.
Use `just install-brewfile` to install or update unmet entries.

Each dump replaces `Brewfile.bak` with the previous Brewfile. Review changes
with `just diff` before committing.

Cancel a picker to leave packages and the Brewfile unchanged. App Store removal
requires administrator privileges. Tap removal does not remove its packages.

Run `just dump && just commit && just sync` to save and push the inventory.
The former `save`, `push`, skip-install variants, and audit options were removed.
Use Homebrew directly for selective bundle installs.

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
