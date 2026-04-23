#!/usr/bin/env bash
set -euo pipefail

window_days="${BREW_AUDIT_DAYS:-90}"
output_root="${BREW_AUDIT_DIR:-$HOME/.local/share/brew-audit}"
max_rows="${BREW_AUDIT_MAX_ROWS:-12}"
refresh=0
with_cve=0

usage() {
  cat <<'EOF'
Usage: brew-audit.sh [options]

Periodic Homebrew audit for formulas, casks, and taps.

Options:
  --days N         Usage/tap staleness window in days (default: 90)
  --max-rows N     Max rows in top candidate tables (default: 12)
  --output-dir DIR Snapshot root directory (default: ~/.local/share/brew-audit)
  --refresh        Run brew update before collecting data
  --with-cve       Run CVE scan (uses cve-bin-tool or trivy if installed)
  --help           Show this help

Environment:
  BREW_AUDIT_DAYS
  BREW_AUDIT_MAX_ROWS
  BREW_AUDIT_DIR
EOF
}

while (($#)); do
  case "$1" in
    --)
      ;;
    --days)
      shift
      [ $# -gt 0 ] || { echo "Missing value for --days" >&2; exit 1; }
      window_days="$1"
      ;;
    --max-rows)
      shift
      [ $# -gt 0 ] || { echo "Missing value for --max-rows" >&2; exit 1; }
      max_rows="$1"
      ;;
    --output-dir)
      shift
      [ $# -gt 0 ] || { echo "Missing value for --output-dir" >&2; exit 1; }
      output_root="$1"
      ;;
    --refresh)
      refresh=1
      ;;
    --with-cve)
      with_cve=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

for command_name in brew python3; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

[[ "$window_days" =~ ^[0-9]+$ ]] || { echo "--days must be a positive integer" >&2; exit 1; }
[[ "$max_rows" =~ ^[0-9]+$ ]] || { echo "--max-rows must be a positive integer" >&2; exit 1; }
[ "$window_days" -gt 0 ] || { echo "--days must be > 0" >&2; exit 1; }
[ "$max_rows" -gt 0 ] || { echo "--max-rows must be > 0" >&2; exit 1; }

timestamp="$(date +%Y-%m-%dT%H-%M-%S)"
run_dir="$output_root/$timestamp"
mkdir -p "$run_dir"

if [ "$refresh" -eq 1 ]; then
  echo "Refreshing Homebrew metadata..."
  brew update >/dev/null
fi

echo "Collecting Homebrew inventory..."
brew info --json=v2 --installed > "$run_dir/installed.json"
brew outdated --json=v2 --greedy > "$run_dir/outdated.json"
brew tap-info --json --installed > "$run_dir/taps.json"

if ! brew services list --json > "$run_dir/services.json" 2>/dev/null; then
  printf '[]\n' > "$run_dir/services.json"
fi

brew leaves > "$run_dir/leaves.txt" || true
brew autoremove --dry-run > "$run_dir/autoremove.txt" 2>/dev/null || true

cve_json=""
cve_tool=""
if [ "$with_cve" -eq 1 ]; then
  cellar_path="$(brew --cellar)"
  if command -v cve-bin-tool >/dev/null 2>&1; then
    cve_tool="cve-bin-tool"
    cve_json="$run_dir/cve-findings.json"
    echo "Running CVE scan with cve-bin-tool..."
    cve-bin-tool -q -f json -o "$cve_json" "$cellar_path" >/dev/null 2>&1 || true
  elif command -v trivy >/dev/null 2>&1; then
    cve_tool="trivy"
    cve_json="$run_dir/cve-findings.json"
    echo "Running CVE scan with trivy..."
    trivy fs --quiet --scanners vuln --format json -o "$cve_json" "$cellar_path" >/dev/null 2>&1 || true
  else
    echo "CVE scan requested, but no scanner found (install cve-bin-tool or trivy)."
  fi
fi

python3 - "$run_dir" "$window_days" "$max_rows" "$with_cve" "$cve_json" "$cve_tool" <<'PY'
import collections
import csv
import datetime as dt
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys

RUN_DIR = pathlib.Path(sys.argv[1])
WINDOW_DAYS = int(sys.argv[2])
MAX_ROWS = int(sys.argv[3])
WITH_CVE = sys.argv[4] == "1"
CVE_JSON = sys.argv[5]
CVE_TOOL = sys.argv[6]
NOW = dt.datetime.now(dt.timezone.utc)


def load_json_file(path: pathlib.Path, default):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return default


def run_command(args):
    result = subprocess.run(
        args,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip()


def days_since_epoch(epoch_value):
    try:
        epoch = int(epoch_value)
    except (TypeError, ValueError):
        return None
    if epoch <= 0:
        return None
    then = dt.datetime.fromtimestamp(epoch, tz=dt.timezone.utc)
    delta = NOW - then
    return max(0, int(delta.total_seconds() // 86400))


def format_days(days, none_value="n/a"):
    if days is None:
        return none_value
    return f"{days}d"


def progress_bar(value, total, width=28):
    if total <= 0:
        filled = 0
        percent = 0.0
    else:
        ratio = max(0.0, min(1.0, value / total))
        filled = int(round(ratio * width))
        percent = ratio * 100
    return f"{'#' * filled}{'.' * (width - filled)}", percent


def histogram_bar(value, max_value, width=28):
    if max_value <= 0:
        return ""
    filled = int(round((value / max_value) * width))
    return "#" * filled


AGE_UNITS = {
    "second": 1 / 86400,
    "minute": 1 / 1440,
    "hour": 1 / 24,
    "day": 1,
    "week": 7,
    "month": 30,
    "year": 365,
}


def parse_relative_age_days(value):
    text = str(value or "").strip().lower()
    if not text:
        return None
    if text in {"today", "just now"}:
        return 0
    if text == "yesterday":
        return 1
    match = re.search(r"(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago", text)
    if not match:
        return None
    amount = int(match.group(1))
    unit = match.group(2)
    return int(round(amount * AGE_UNITS[unit]))


def latest_install(install_records):
    latest = {}
    latest_time = -1
    for item in install_records or []:
        timestamp = int(item.get("time") or 0)
        if timestamp >= latest_time:
            latest = item
            latest_time = timestamp
    return latest


def tap_age_days(tap):
    tap_path = tap.get("path")
    if tap_path and os.path.isdir(tap_path):
        ts_text = run_command(["git", "-C", tap_path, "log", "-1", "--format=%ct"])
        if ts_text.isdigit():
            days = days_since_epoch(int(ts_text))
            if days is not None:
                return days
    return parse_relative_age_days(tap.get("last_commit"))


def parse_mdls_timestamp(raw_value):
    value = str(raw_value or "").strip()
    if not value or value == "(null)":
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S %z", "%Y-%m-%d %H:%M:%S"):
        try:
            parsed = dt.datetime.strptime(value, fmt)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return int(parsed.timestamp())
        except ValueError:
            continue
    return None


def app_last_used_epoch(app_path):
    output = run_command(["mdls", "-raw", "-name", "kMDItemLastUsedDate", str(app_path)])
    return parse_mdls_timestamp(output)


def collect_app_names(node, names):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "app":
                collect_app_names(value, names)
            else:
                collect_app_names(value, names)
        return

    if isinstance(node, list):
        for item in node:
            collect_app_names(item, names)
        return

    if isinstance(node, str) and node.endswith(".app"):
        names.add(os.path.basename(node))


ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def extract_command_token(command_line):
    command_line = command_line.strip()
    if not command_line:
        return None
    try:
        parts = shlex.split(command_line, posix=True)
    except ValueError:
        parts = command_line.split()

    if not parts:
        return None

    index = 0
    while index < len(parts) and ENV_ASSIGN_RE.match(parts[index]):
        index += 1

    while index < len(parts) and parts[index] in {"sudo", "command", "nohup", "time"}:
        index += 1
        while index < len(parts) and parts[index].startswith("-"):
            index += 1

    if index >= len(parts):
        return None

    token = os.path.basename(parts[index])

    if token == "env":
        index += 1
        while index < len(parts) and (
            parts[index].startswith("-") or ENV_ASSIGN_RE.match(parts[index])
        ):
            index += 1
        if index >= len(parts):
            return None
        token = os.path.basename(parts[index])

    if token in {"builtin", "exec"} and index + 1 < len(parts):
        token = os.path.basename(parts[index + 1])

    return token or None


def iter_history_records(path):
    if path.name == ".zsh_history":
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            for raw_line in handle:
                line = raw_line.rstrip("\n")
                if not line:
                    continue
                match = re.match(r"^: (\d+):\d+;(.*)$", line)
                if match:
                    yield match.group(2), int(match.group(1))
                else:
                    yield line, None
        return

    if path.name == "fish_history":
        current_cmd = None
        current_when = None
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            for raw_line in handle:
                stripped = raw_line.strip()
                if stripped.startswith("- cmd: "):
                    if current_cmd:
                        yield current_cmd, current_when
                    current_cmd = stripped[7:]
                    current_when = None
                elif stripped.startswith("cmd: "):
                    if current_cmd:
                        yield current_cmd, current_when
                    current_cmd = stripped[5:]
                    current_when = None
                elif stripped.startswith("when: ") and current_cmd:
                    value = stripped[6:].strip()
                    if value.isdigit():
                        current_when = int(value)
                elif not stripped and current_cmd:
                    yield current_cmd, current_when
                    current_cmd = None
                    current_when = None
        if current_cmd:
            yield current_cmd, current_when
        return

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line:
                yield line, None


def normalize_severity(value):
    severity = str(value or "UNKNOWN").upper().strip()
    if severity in {"CRIT", "CRITICAL"}:
        return "CRITICAL"
    if severity == "HIGH":
        return "HIGH"
    if severity in {"MEDIUM", "MODERATE"}:
        return "MEDIUM"
    if severity == "LOW":
        return "LOW"
    return "UNKNOWN"


def package_from_target(target):
    marker = "/Cellar/"
    if marker in target:
        return target.split(marker, 1)[1].split("/", 1)[0]
    return target


def parse_cve_findings(path):
    if not path:
        return []
    cve_path = pathlib.Path(path)
    if not cve_path.exists():
        return []

    data = load_json_file(cve_path, {})
    findings = []

    if isinstance(data, dict) and isinstance(data.get("Results"), list):
        for result in data["Results"]:
            target = str(result.get("Target") or "")
            fallback_package = package_from_target(target)
            for vuln in result.get("Vulnerabilities") or []:
                vuln_id = vuln.get("VulnerabilityID") or vuln.get("ID")
                if not vuln_id:
                    continue
                findings.append(
                    {
                        "id": str(vuln_id),
                        "severity": normalize_severity(vuln.get("Severity")),
                        "package": str(vuln.get("PkgName") or fallback_package or "unknown"),
                    }
                )

    if isinstance(data, dict) and isinstance(data.get("results"), list):
        for result in data["results"]:
            package_name = result.get("product") or result.get("package") or result.get("vendor")
            package_name = str(package_name or "unknown")
            for cve in result.get("cves") or []:
                cve_id = cve.get("cve_number") or cve.get("id")
                if not cve_id:
                    continue
                findings.append(
                    {
                        "id": str(cve_id),
                        "severity": normalize_severity(cve.get("severity")),
                        "package": package_name,
                    }
                )

    unique = []
    seen = set()
    for finding in findings:
        dedupe_key = (finding["id"], finding["package"])
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        unique.append(finding)
    return unique


installed = load_json_file(RUN_DIR / "installed.json", {"formulae": [], "casks": []})
taps = load_json_file(RUN_DIR / "taps.json", [])
services = load_json_file(RUN_DIR / "services.json", [])

formulae = installed.get("formulae") or []
casks = installed.get("casks") or []

history_paths = [
    pathlib.Path.home() / ".zsh_history",
    pathlib.Path.home() / ".bash_history",
    pathlib.Path.home() / ".config" / "fish" / "fish_history",
]

command_hits = collections.Counter()
command_last_seen = {}

for history_path in history_paths:
    if not history_path.exists():
        continue
    try:
        for command_line, timestamp in iter_history_records(history_path):
            token = extract_command_token(command_line)
            if not token:
                continue
            command_hits[token] += 1
            if timestamp is not None:
                previous = command_last_seen.get(token)
                if previous is None or timestamp > previous:
                    command_last_seen[token] = timestamp
    except OSError:
        continue

formula_rows = []
for formula in formulae:
    latest = latest_install(formula.get("installed"))
    names = set()

    base_name = formula.get("name")
    if base_name:
        names.add(base_name)

    full_name = formula.get("full_name")
    if full_name and "/" in full_name:
        names.add(full_name.rsplit("/", 1)[-1])

    for alias in formula.get("aliases") or []:
        if alias:
            names.add(alias)

    hits = sum(command_hits.get(name, 0) for name in names)
    last_epoch = 0
    for name in names:
        candidate = command_last_seen.get(name, 0)
        if candidate > last_epoch:
            last_epoch = candidate

    last_used_days = days_since_epoch(last_epoch) if last_epoch else None
    if hits == 0:
        usage_state = "unseen"
    elif last_used_days is None or last_used_days <= WINDOW_DAYS:
        usage_state = "active"
    else:
        usage_state = "stale"

    formula_rows.append(
        {
            "name": full_name or base_name or "unknown",
            "short_name": base_name or full_name or "unknown",
            "hits": hits,
            "last_used_days": last_used_days,
            "installed_days": days_since_epoch(latest.get("time")),
            "installed_on_request": bool(latest.get("installed_on_request")),
            "outdated": bool(formula.get("outdated")),
            "deprecated": bool(formula.get("deprecated")),
            "disabled": bool(formula.get("disabled")),
            "pinned": bool(formula.get("pinned")),
            "usage_state": usage_state,
            "installed_version": latest.get("version") or "",
            "current_stable": (formula.get("versions") or {}).get("stable") or "",
        }
    )

APP_LOCATIONS = [pathlib.Path("/Applications"), pathlib.Path.home() / "Applications"]

cask_rows = []
for cask in casks:
    app_names = set()
    collect_app_names(cask.get("artifacts") or [], app_names)

    last_used_epoch = None
    found_paths = []
    for app_name in sorted(app_names):
        for base in APP_LOCATIONS:
            app_path = base / app_name
            if not app_path.exists():
                continue
            found_paths.append(str(app_path))
            last_used = app_last_used_epoch(app_path)
            if last_used is None:
                continue
            if last_used_epoch is None or last_used > last_used_epoch:
                last_used_epoch = last_used

    last_used_days = days_since_epoch(last_used_epoch) if last_used_epoch else None
    if last_used_days is None:
        usage_state = "unknown"
    elif last_used_days <= WINDOW_DAYS:
        usage_state = "active"
    else:
        usage_state = "stale"

    cask_rows.append(
        {
            "token": cask.get("full_token") or cask.get("token") or "unknown",
            "last_used_days": last_used_days,
            "installed_days": days_since_epoch(cask.get("installed_time")),
            "outdated": bool(cask.get("outdated")),
            "deprecated": bool(cask.get("deprecated")),
            "disabled": bool(cask.get("disabled")),
            "usage_state": usage_state,
            "app_paths": found_paths,
            "installed_version": str(cask.get("installed") or ""),
            "current_version": str(cask.get("version") or ""),
        }
    )

tap_rows = []
for tap in taps:
    age_days = tap_age_days(tap)
    if age_days is None:
        freshness = "unknown"
    elif age_days <= WINDOW_DAYS:
        freshness = "fresh"
    else:
        freshness = "stale"

    tap_rows.append(
        {
            "name": tap.get("name") or "unknown",
            "remote": tap.get("remote") or "",
            "official": bool(tap.get("official")),
            "age_days": age_days,
            "freshness": freshness,
            "last_commit": tap.get("last_commit") or "",
        }
    )

service_rows = services if isinstance(services, list) else []
running_services = sum(1 for service in service_rows if service.get("status") == "started")

formula_total = len(formula_rows)
cask_total = len(cask_rows)
tap_total = len(tap_rows)

formula_outdated = sum(1 for row in formula_rows if row["outdated"])
formula_deprecated = sum(1 for row in formula_rows if row["deprecated"])
formula_disabled = sum(1 for row in formula_rows if row["disabled"])
formula_pinned = sum(1 for row in formula_rows if row["pinned"])
formula_at_risk = sum(
    1 for row in formula_rows if row["outdated"] or row["deprecated"] or row["disabled"]
)
formula_healthy = formula_total - formula_at_risk

cask_outdated = sum(1 for row in cask_rows if row["outdated"])
cask_deprecated = sum(1 for row in cask_rows if row["deprecated"])
cask_disabled = sum(1 for row in cask_rows if row["disabled"])
cask_at_risk = sum(1 for row in cask_rows if row["outdated"] or row["deprecated"] or row["disabled"])
cask_healthy = cask_total - cask_at_risk

tap_fresh = sum(1 for row in tap_rows if row["freshness"] == "fresh")
tap_stale = sum(1 for row in tap_rows if row["freshness"] == "stale")
tap_unknown = sum(1 for row in tap_rows if row["freshness"] == "unknown")

formula_usage_counts = collections.OrderedDict(
    [
        ("active", sum(1 for row in formula_rows if row["usage_state"] == "active")),
        ("stale", sum(1 for row in formula_rows if row["usage_state"] == "stale")),
        ("unseen", sum(1 for row in formula_rows if row["usage_state"] == "unseen")),
    ]
)

cask_usage_counts = collections.OrderedDict(
    [
        ("active", sum(1 for row in cask_rows if row["usage_state"] == "active")),
        ("stale", sum(1 for row in cask_rows if row["usage_state"] == "stale")),
        ("unknown", sum(1 for row in cask_rows if row["usage_state"] == "unknown")),
    ]
)

age_buckets = collections.OrderedDict(
    [("0-30d", 0), ("31-90d", 0), ("91-180d", 0), ("181-365d", 0), ("366d+", 0), ("unknown", 0)]
)


def age_bucket(days):
    if days is None:
        return "unknown"
    if days <= 30:
        return "0-30d"
    if days <= 90:
        return "31-90d"
    if days <= 180:
        return "91-180d"
    if days <= 365:
        return "181-365d"
    return "366d+"


for row in formula_rows:
    age_buckets[age_bucket(row["installed_days"])] += 1
for row in cask_rows:
    age_buckets[age_bucket(row["installed_days"])] += 1

formula_cleanup_candidates = [
    row
    for row in formula_rows
    if row["installed_on_request"] and row["usage_state"] in {"unseen", "stale"}
]
formula_cleanup_candidates.sort(
    key=lambda row: (
        0 if row["usage_state"] == "unseen" else 1,
        -(row["installed_days"] or 0),
        -(row["last_used_days"] or 0),
        row["short_name"],
    )
)

cask_cleanup_candidates = [
    row
    for row in cask_rows
    if row["usage_state"] == "stale" or (row["usage_state"] == "unknown" and row["app_paths"])
]
cask_cleanup_candidates.sort(
    key=lambda row: (
        1 if row["usage_state"] == "unknown" else 0,
        -(row["last_used_days"] or 0),
        -(row["installed_days"] or 0),
        row["token"],
    )
)

top_formula_usage = [row for row in formula_rows if row["hits"] > 0]
top_formula_usage.sort(key=lambda row: (-row["hits"], row["short_name"]))
top_formula_usage = top_formula_usage[:MAX_ROWS]

tap_freshness_rows = sorted(
    tap_rows,
    key=lambda row: (row["age_days"] is None, -(row["age_days"] or 0), row["name"]),
)[:MAX_ROWS]

cve_findings = parse_cve_findings(CVE_JSON)
severity_order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]
severity_counts = collections.OrderedDict((key, 0) for key in severity_order)
for finding in cve_findings:
    severity_counts[normalize_severity(finding.get("severity"))] += 1

package_counts = collections.Counter(finding["package"] for finding in cve_findings)
top_cve_packages = package_counts.most_common(MAX_ROWS)

summary = {
    "generated_at": NOW.isoformat(),
    "snapshot_dir": str(RUN_DIR),
    "window_days": WINDOW_DAYS,
    "inventory": {
        "formulae": formula_total,
        "casks": cask_total,
        "taps": tap_total,
        "services": len(service_rows),
        "services_running": running_services,
    },
    "formulae": {
        "healthy": formula_healthy,
        "at_risk": formula_at_risk,
        "outdated": formula_outdated,
        "deprecated": formula_deprecated,
        "disabled": formula_disabled,
        "pinned": formula_pinned,
        "usage": formula_usage_counts,
    },
    "casks": {
        "healthy": cask_healthy,
        "at_risk": cask_at_risk,
        "outdated": cask_outdated,
        "deprecated": cask_deprecated,
        "disabled": cask_disabled,
        "usage": cask_usage_counts,
    },
    "taps": {
        "fresh": tap_fresh,
        "stale": tap_stale,
        "unknown": tap_unknown,
    },
    "cve": {
        "requested": WITH_CVE,
        "scanner": CVE_TOOL,
        "count": len(cve_findings),
        "severity": severity_counts,
    },
}

(RUN_DIR / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

with (RUN_DIR / "formula-usage.tsv").open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(
        [
            "formula",
            "usage_state",
            "hits",
            "last_used_days",
            "installed_days",
            "outdated",
            "deprecated",
            "disabled",
            "pinned",
            "installed_on_request",
            "installed_version",
            "current_stable",
        ]
    )
    for row in sorted(formula_rows, key=lambda item: item["short_name"]):
        writer.writerow(
            [
                row["name"],
                row["usage_state"],
                row["hits"],
                row["last_used_days"],
                row["installed_days"],
                row["outdated"],
                row["deprecated"],
                row["disabled"],
                row["pinned"],
                row["installed_on_request"],
                row["installed_version"],
                row["current_stable"],
            ]
        )

with (RUN_DIR / "cask-usage.tsv").open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(
        [
            "cask",
            "usage_state",
            "last_used_days",
            "installed_days",
            "outdated",
            "deprecated",
            "disabled",
            "installed_version",
            "current_version",
            "app_paths",
        ]
    )
    for row in sorted(cask_rows, key=lambda item: item["token"]):
        writer.writerow(
            [
                row["token"],
                row["usage_state"],
                row["last_used_days"],
                row["installed_days"],
                row["outdated"],
                row["deprecated"],
                row["disabled"],
                row["installed_version"],
                row["current_version"],
                ",".join(row["app_paths"]),
            ]
        )

with (RUN_DIR / "tap-freshness.tsv").open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(["tap", "freshness", "age_days", "official", "remote", "last_commit"])
    for row in sorted(tap_rows, key=lambda item: item["name"]):
        writer.writerow(
            [
                row["name"],
                row["freshness"],
                row["age_days"],
                row["official"],
                row["remote"],
                row["last_commit"],
            ]
        )

if cve_findings:
    with (RUN_DIR / "cve-findings.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["id", "severity", "package"])
        for finding in cve_findings:
            writer.writerow([finding["id"], finding["severity"], finding["package"]])

lines = []
lines.append("BREW AUDIT")
lines.append(f"snapshot: {RUN_DIR}")
lines.append(f"window: {WINDOW_DAYS}d")
lines.append("")

lines.append("INVENTORY")
lines.append(
    f"  formulae={formula_total} casks={cask_total} taps={tap_total} services={len(service_rows)} (running={running_services})"
)
lines.append(
    f"  formula_risk={formula_at_risk} cask_risk={cask_at_risk} tap_stale={tap_stale} tap_unknown={tap_unknown}"
)
lines.append("")

lines.append("HEALTH")
for label, healthy, total in (
    ("formulae", formula_healthy, formula_total),
    ("casks", cask_healthy, cask_total),
    ("taps", tap_fresh, tap_total),
):
    bar, pct = progress_bar(healthy, total)
    lines.append(f"  {label:<10} [{bar}] {healthy:>3}/{total:<3} {pct:5.1f}%")
lines.append("")

lines.append("INSTALL AGE")
max_age_bucket = max(age_buckets.values()) if age_buckets else 0
for label, count in age_buckets.items():
    bar = histogram_bar(count, max_age_bucket)
    lines.append(f"  {label:<8} | {bar:<28} {count}")
lines.append("")

lines.append("FORMULA USAGE")
max_formula_usage = max(formula_usage_counts.values()) if formula_usage_counts else 0
for label, count in formula_usage_counts.items():
    bar = histogram_bar(count, max_formula_usage)
    lines.append(f"  {label:<8} | {bar:<28} {count}")
lines.append("")

lines.append("CASK USAGE")
max_cask_usage = max(cask_usage_counts.values()) if cask_usage_counts else 0
for label, count in cask_usage_counts.items():
    bar = histogram_bar(count, max_cask_usage)
    lines.append(f"  {label:<8} | {bar:<28} {count}")
lines.append("")

lines.append("TOP FORMULA COMMANDS")
if top_formula_usage:
    max_hits = max(row["hits"] for row in top_formula_usage)
    for row in top_formula_usage:
        bar = histogram_bar(row["hits"], max_hits)
        lines.append(f"  {row['short_name']:<20} | {bar:<28} {row['hits']}")
else:
    lines.append("  no shell-history matches for installed formula commands")
lines.append("")

lines.append("FORMULA CLEANUP CANDIDATES")
if formula_cleanup_candidates:
    lines.append("  formula                  state    hits  last_used  installed")
    for row in formula_cleanup_candidates[:MAX_ROWS]:
        lines.append(
            "  "
            + f"{row['short_name']:<24} "
            + f"{row['usage_state']:<8} "
            + f"{row['hits']:>4} "
            + f"{format_days(row['last_used_days'], 'never'):>10} "
            + f"{format_days(row['installed_days']):>10}"
        )
else:
    lines.append("  no cleanup candidates found")
lines.append("")

lines.append("CASK CLEANUP CANDIDATES")
if cask_cleanup_candidates:
    lines.append("  cask                     state    last_used  installed")
    for row in cask_cleanup_candidates[:MAX_ROWS]:
        lines.append(
            "  "
            + f"{row['token']:<24} "
            + f"{row['usage_state']:<8} "
            + f"{format_days(row['last_used_days'], 'unknown'):>10} "
            + f"{format_days(row['installed_days']):>10}"
        )
else:
    lines.append("  no cleanup candidates found")
lines.append("")

lines.append("TAP FRESHNESS")
if tap_freshness_rows:
    known_ages = [row["age_days"] for row in tap_freshness_rows if row["age_days"] is not None]
    max_tap_age = max(known_ages) if known_ages else 0
    for row in tap_freshness_rows:
        age_days = row["age_days"]
        if age_days is None:
            bar = ""
            age_text = "unknown"
        else:
            bar = histogram_bar(age_days, max_tap_age)
            age_text = f"{age_days}d"
        lines.append(f"  {row['name']:<24} | {bar:<28} {age_text}")
else:
    lines.append("  no taps found")
lines.append("")

lines.append("CVE")
if WITH_CVE and not CVE_TOOL:
    lines.append("  scanner: unavailable (install cve-bin-tool or trivy)")
elif WITH_CVE and CVE_TOOL:
    lines.append(f"  scanner: {CVE_TOOL}")
    lines.append(f"  findings: {len(cve_findings)}")
    if cve_findings:
        max_severity = max(severity_counts.values()) if severity_counts else 0
        for severity, count in severity_counts.items():
            if count == 0:
                continue
            bar = histogram_bar(count, max_severity)
            lines.append(f"  {severity:<8} | {bar:<28} {count}")
        if top_cve_packages:
            lines.append("  top packages:")
            for package, count in top_cve_packages[:5]:
                lines.append(f"    {package}: {count}")
else:
    lines.append("  scanner: not run (use --with-cve)")
lines.append("")

lines.append("FILES")
lines.append(f"  report: {RUN_DIR / 'report.txt'}")
lines.append(f"  summary: {RUN_DIR / 'summary.json'}")
lines.append(f"  formula usage: {RUN_DIR / 'formula-usage.tsv'}")
lines.append(f"  cask usage: {RUN_DIR / 'cask-usage.tsv'}")
lines.append(f"  tap freshness: {RUN_DIR / 'tap-freshness.tsv'}")
if cve_findings:
    lines.append(f"  cve findings: {RUN_DIR / 'cve-findings.tsv'}")

report_text = "\n".join(lines) + "\n"
(RUN_DIR / "report.txt").write_text(report_text, encoding="utf-8")
print(report_text, end="")
PY
