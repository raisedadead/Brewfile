# Brewfile

Apps, tools, and utilities for my macOS machines.

Run `just` to list commands. Homebrew and Just are required.

| Command | Action |
| --- | --- |
| `just install PACKAGE…` | Install named packages. Accepts Homebrew flags. |
| `just uninstall PACKAGE…` | Remove named packages. Accepts Homebrew flags. |
| `just install-brewfile` | Install and upgrade Brewfile entries. |
| `just dump` | Replace the Brewfile with the installed inventory. |
| `just dump --no-mas --no-vscode` | Dump without App Store apps or VS Code extensions. |
| `just check` | Check that Brewfile entries are installed. Return failure if entries are missing. |
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
It does not reconcile installed packages with the Brewfile.

Use Git directly to commit and push the Brewfile. The recipes do not sync Git,
make backups, or show interactive package pickers. The former `save`, `sync`,
`push`, `commit`, `drift`, skip-install variants, and audit options were removed.
Use Homebrew directly for selective bundle installs.

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
