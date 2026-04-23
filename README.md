# Brewfile

> apps, tools and utilities that I use on my macOS machines

## Audit

Run an inventory audit with terminal charts for formulas, casks, and taps:

```bash
just audit
```

Useful options:

```bash
just audit -- --refresh
just audit -- --days 120 --max-rows 20
just audit -- --with-cve
```

Each run writes a timestamped snapshot under `~/.local/share/brew-audit/` with:

- `report.txt` (terminal report)
- `summary.json` (machine-readable summary)
- `formula-usage.tsv`, `cask-usage.tsv`, `tap-freshness.tsv`
- `cve-findings.tsv` (only when CVE findings exist)

## License

[The Unlicense](/LICENSE.md) © 2017 Mrugesh Mohapatra
