# Brewfile

Apps, tools, and utilities for my macOS machines.

Run `just` to list commands. Homebrew and Just are required.

| Command | Action |
| --- | --- |
| `just install PACKAGE…` | Install named packages. Accepts Homebrew flags. |
| `just uninstall PACKAGE…` | Remove named packages. Accepts Homebrew flags. |
| `just install-brewfile` | Install and upgrade Brewfile entries. |
| `just dump` | Copy the Brewfile to `Brewfile.bak`, then replace it with the installed inventory. |
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

The audit uses local Homebrew metadata. Run `brew update` to refresh it.
It does not measure package use or scan for vulnerabilities. It writes no reports.

`just clean` is a preview. Run `brew autoremove` or `brew cleanup` to apply it.
Use `just drift` to preview Brewfile cleanup. It cannot approve removals.
Run `brew bundle cleanup --file=Brewfile` to review and apply that cleanup.
Use `just install-brewfile` to install or update unmet entries.

Each dump replaces `Brewfile.bak` with the previous Brewfile. Review changes
with `just diff` before committing.

Use Git directly to commit and push the Brewfile. The recipes do not sync Git
or show interactive package pickers. The former `save`, `sync`, `push`, `commit`,
skip-install variants, and audit options were removed.
Use Homebrew directly for selective bundle installs.

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
