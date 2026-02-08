# Brewfile Management with Just
# Run `just` or `just help` for available recipes

set shell := ["bash", "-cu"]
set dotenv-load := false

# Configuration
export HOMEBREW_NO_ENV_HINTS := "1"
brewfile := "Brewfile"

# Default recipe - show help
default: help

# Check if brew is installed (internal)
[private]
check-brew:
    @command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew is not installed"; exit 1; }

# Check required dependencies
deps: check-brew
    @command -v gum >/dev/null 2>&1 || { echo "Error: gum is not installed. Run 'brew install gum'"; exit 1; }
    @command -v xargs >/dev/null 2>&1 || { echo "Error: xargs is not installed"; exit 1; }
    @echo "All dependencies are installed"

# Show available recipes
help:
    @echo "Brewfile Management:"
    @echo "  just install              - Install everything"
    @echo "  just install-no-mas       - Install everything except Mac App Store"
    @echo "  just install-no-vscode    - Install everything except VS Code extensions"
    @echo "  just install-no-mas-vscode - Install everything except MAS & VS Code"
    @echo "  just uninstall            - Interactive package removal"
    @echo "  just update               - Update all packages, cleanup, doctor"
    @echo "  just clean                - Remove unused dependencies (with confirmation)"
    @echo ""
    @echo "Status & Info:"
    @echo "  just check                - Check if system matches Brewfile"
    @echo "  just doctor               - Run brew doctor"
    @echo "  just list [TYPE]          - List packages (formulas|casks|all)"
    @echo "  just outdated             - Show outdated packages"
    @echo "  just deps                 - Check required dependencies"
    @echo "  just diff                 - Show uncommitted Brewfile changes"
    @echo ""
    @echo "File Management:"
    @echo "  just dump                 - Dump everything to Brewfile"
    @echo "  just dump-no-mas          - Dump everything except Mac App Store"
    @echo "  just dump-no-vscode       - Dump everything except VS Code extensions"
    @echo "  just dump-no-mas-vscode   - Dump everything except MAS & VS Code"
    @echo "  just clean-backup         - Remove Brewfile.bak"
    @echo "  just commit               - Git commit Brewfile"
    @echo "  just push                 - Push changes (with remote update check)"
    @echo "  just sync                 - Alias for push"

# ─────────────────────────────────────────────────────────────────────────────
# Installation Recipes
# ─────────────────────────────────────────────────────────────────────────────

# Install everything from Brewfile
install: check-brew
    brew bundle install --file={{ brewfile }}

# Install everything except Mac App Store apps
install-no-mas: check-brew
    HOMEBREW_BUNDLE_MAS_SKIP="*" brew bundle install --file={{ brewfile }}

# Install everything except VS Code extensions
install-no-vscode: check-brew
    HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file={{ brewfile }}

# Install everything except MAS & VS Code
install-no-mas-vscode: check-brew
    HOMEBREW_BUNDLE_MAS_SKIP="*" HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file={{ brewfile }}

# ─────────────────────────────────────────────────────────────────────────────
# Dump Recipes
# ─────────────────────────────────────────────────────────────────────────────

# Backup existing Brewfile (internal)
[private]
backup-brewfile:
    @[ -f {{ brewfile }} ] && cp {{ brewfile }} {{ brewfile }}.bak || true

# Dump everything to Brewfile
dump: check-brew backup-brewfile
    brew bundle dump --force --describe --file={{ brewfile }}

# Dump everything except Mac App Store apps
dump-no-mas: check-brew backup-brewfile
    brew bundle dump --force --describe --no-mas --file={{ brewfile }}

# Dump everything except VS Code extensions
dump-no-vscode: check-brew backup-brewfile
    brew bundle dump --force --describe --no-vscode --file={{ brewfile }}

# Dump everything except MAS & VS Code
dump-no-mas-vscode: check-brew backup-brewfile
    brew bundle dump --force --describe --no-mas --no-vscode --file={{ brewfile }}

# ─────────────────────────────────────────────────────────────────────────────
# Git Recipes
# ─────────────────────────────────────────────────────────────────────────────

# Show uncommitted Brewfile changes
diff:
    #!/usr/bin/env bash
    output=$(git diff {{ brewfile }} 2>/dev/null) || { echo "No git repository or Brewfile not tracked"; exit 0; }
    [ -z "$output" ] && echo "No uncommitted changes." || echo "$output"

# Git commit Brewfile with date
commit:
    git add {{ brewfile }}
    @if git diff --cached --quiet; then \
        echo "No changes to commit"; \
    else \
        git commit -m "chore: update brewfile $(date +%Y-%m-%d)"; \
    fi

# Push changes (with remote update check)
[no-exit-message]
push:
    #!/usr/bin/env bash
    set -euo pipefail
    git remote get-url origin >/dev/null 2>&1 || { echo "Error: no 'origin' remote configured"; exit 1; }
    BRANCH=$(git branch --show-current)
    [ -z "$BRANCH" ] && { echo "Error: not on a branch (detached HEAD)"; exit 1; }
    echo "Fetching remote changes..."
    git fetch origin
    REMOTE_AHEAD=$(git rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo 0)
    if [ "$REMOTE_AHEAD" -gt 0 ]; then
        echo "Remote has $REMOTE_AHEAD new commit(s), rebasing..."
        git rebase "origin/$BRANCH" || {
            echo "Rebase failed. Resolve conflicts and run 'git rebase --continue'"
            exit 1
        }
    fi
    LOCAL_AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)
    if [ "$LOCAL_AHEAD" -gt 0 ]; then
        echo "Pushing $LOCAL_AHEAD commit(s)..."
        git push origin "$BRANCH"
    else
        echo "Already in sync."
    fi

# Alias for push
sync: push

# ─────────────────────────────────────────────────────────────────────────────
# Update & Maintenance Recipes
# ─────────────────────────────────────────────────────────────────────────────

# Update all packages, cleanup, and run doctor
[no-exit-message]
update: check-brew
    brew update
    brew upgrade
    brew cleanup
    @-brew doctor

# Remove unused dependencies (with confirmation)
[no-exit-message]
clean: check-brew
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Packages not in Brewfile:"
    brew bundle cleanup --file={{ brewfile }} || true
    echo ""
    printf "Remove these packages? [y/N] "
    read -r confirm || confirm=""
    if [ "$confirm" = "y" ]; then
        brew bundle cleanup --force --file={{ brewfile }}
        brew autoremove
    else
        echo "Aborted."
    fi

# Remove Brewfile.bak
clean-backup:
    @rm -f {{ brewfile }}.bak && echo "Removed {{ brewfile }}.bak" || echo "No backup file found"

# ─────────────────────────────────────────────────────────────────────────────
# Status & Info Recipes
# ─────────────────────────────────────────────────────────────────────────────

# Check if system matches Brewfile
[no-exit-message]
check: check-brew
    #!/usr/bin/env bash
    output=$(brew bundle check --file={{ brewfile }} 2>&1)
    status=$?
    echo "$output"
    if [ $status -ne 0 ]; then
        echo ""
        echo "→ Run 'just install' to satisfy missing dependencies."
    fi

# Run brew doctor
[no-exit-message]
doctor: check-brew
    @-brew doctor

# Interactive package removal
[no-exit-message]
uninstall: deps
    #!/usr/bin/env bash
    set -euo pipefail
    TYPE=$(gum choose "brew formulas" "brew casks" "mas apps") || { echo "Cancelled."; exit 0; }
    declare -a FAILED=()
    case "$TYPE" in
        "brew formulas")
            SELECTED=$(brew list --formula | gum filter --no-limit) || true
            if [ -n "$SELECTED" ]; then
                while IFS= read -r pkg; do
                    brew uninstall "$pkg" || FAILED+=("$pkg")
                done <<< "$SELECTED"
            else
                echo "No formulas selected"
            fi
            ;;
        "brew casks")
            SELECTED=$(brew list --cask | gum filter --no-limit) || true
            if [ -n "$SELECTED" ]; then
                while IFS= read -r pkg; do
                    brew uninstall --cask "$pkg" || FAILED+=("$pkg")
                done <<< "$SELECTED"
            else
                echo "No casks selected"
            fi
            ;;
        "mas apps")
            command -v mas >/dev/null 2>&1 || { echo "Error: mas is not installed. Run 'brew install mas'"; exit 1; }
            SELECTED=$(mas list | gum filter --no-limit | awk '{print $1}') || true
            if [ -n "$SELECTED" ]; then
                while IFS= read -r pkg; do
                    sudo mas uninstall "$pkg" || FAILED+=("$pkg")
                done <<< "$SELECTED"
            else
                echo "No apps selected"
            fi
            ;;
    esac
    if [ "${#FAILED[@]}" -gt 0 ]; then
        echo ""
        echo "Failed to uninstall: ${FAILED[*]}"
        exit 1
    fi

# List installed packages (formulas, casks, or all)
list type="all": check-brew
    #!/usr/bin/env bash
    case "{{ type }}" in
        casks)
            brew list --cask
            ;;
        formulas)
            brew list --formula
            ;;
        all)
            brew list
            ;;
        *)
            echo "Unknown type '{{ type }}'. Use: formulas, casks, or all"
            exit 1
            ;;
    esac

# Show outdated packages
outdated: check-brew
    brew outdated --greedy
