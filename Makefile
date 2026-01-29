.PHONY: help deps install install-no-mas install-no-vscode install-no-mas-vscode dump dump-no-mas dump-no-vscode dump-no-mas-vscode commit push sync update clean check doctor uninstall list outdated diff _check-brew
.DEFAULT_GOAL := help

# Configuration
export HOMEBREW_NO_ENV_HINTS=1
BREWFILE := Brewfile
TYPE ?= all

# Internal dependency check (lightweight)
_check-brew:
	@command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew is not installed"; exit 1; }

deps: _check-brew
	@command -v gum >/dev/null 2>&1 || { echo "Error: gum is not installed. Run 'brew install gum'"; exit 1; }
	@command -v xargs >/dev/null 2>&1 || { echo "Error: xargs is not installed"; exit 1; }
	@echo "All dependencies are installed"

help:
	@echo "Brewfile Management:"
	@echo "  make install           - Install everything"
	@echo "  make install-no-mas    - Install everything except Mac App Store"
	@echo "  make install-no-vscode - Install everything except VS Code extensions"
	@echo "  make install-no-mas-vscode - Install everything except MAS & VS Code"
	@echo "  make uninstall TYPE=formulas|casks"
	@echo "  make update            - Update all packages, cleanup, doctor"
	@echo "  make clean             - Remove unused dependencies (with confirmation)"
	@echo ""
	@echo "Status & Info:"
	@echo "  make check             - Check if system matches Brewfile"
	@echo "  make doctor            - Run brew doctor"
	@echo "  make list [TYPE=formulas|casks|all]"
	@echo "  make outdated          - Show outdated packages"
	@echo "  make deps              - Check required dependencies"
	@echo "  make diff              - Show uncommitted Brewfile changes"
	@echo ""
	@echo "File Management:"
	@echo "  make dump              - Dump everything to Brewfile"
	@echo "  make dump-no-mas       - Dump everything except Mac App Store"
	@echo "  make dump-no-vscode    - Dump everything except VS Code extensions"
	@echo "  make dump-no-mas-vscode - Dump everything except MAS & VS Code"
	@echo "  make commit            - Git commit Brewfile"
	@echo "  make push              - Push changes (with remote update check)"
	@echo "  make sync              - Alias for push"

install: _check-brew
	brew bundle install --file=$(BREWFILE)

install-no-mas: _check-brew
	HOMEBREW_BUNDLE_MAS_SKIP="*" brew bundle install --file=$(BREWFILE)

install-no-vscode: _check-brew
	HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file=$(BREWFILE)

install-no-mas-vscode: _check-brew
	HOMEBREW_BUNDLE_MAS_SKIP="*" HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file=$(BREWFILE)

dump: _check-brew
	@[ -f $(BREWFILE) ] && cp $(BREWFILE) $(BREWFILE).bak || true
	brew bundle dump --force --describe --file=$(BREWFILE)

dump-no-mas: _check-brew
	@[ -f $(BREWFILE) ] && cp $(BREWFILE) $(BREWFILE).bak || true
	brew bundle dump --force --describe --no-mas --file=$(BREWFILE)

dump-no-vscode: _check-brew
	@[ -f $(BREWFILE) ] && cp $(BREWFILE) $(BREWFILE).bak || true
	brew bundle dump --force --describe --no-vscode --file=$(BREWFILE)

dump-no-mas-vscode: _check-brew
	@[ -f $(BREWFILE) ] && cp $(BREWFILE) $(BREWFILE).bak || true
	brew bundle dump --force --describe --no-mas --no-vscode --file=$(BREWFILE)

diff:
	@git diff $(BREWFILE) 2>/dev/null || echo "No git repository or Brewfile not tracked"

commit:
	git add $(BREWFILE)
	@if git diff --cached --quiet; then \
		echo "No changes to commit"; \
	else \
		git commit -m "chore: update brewfile $$(date +%Y-%m-%d)"; \
	fi

push:
	@echo "Fetching remote changes..."
	@git fetch origin
	@BRANCH=$$(git branch --show-current); \
	REMOTE_AHEAD=$$(git rev-list --count HEAD..origin/$$BRANCH 2>/dev/null || echo 0); \
	if [ $$REMOTE_AHEAD -gt 0 ]; then \
		echo "Remote has $$REMOTE_AHEAD new commit(s), rebasing..."; \
		git rebase origin/$$BRANCH || { \
			echo "Rebase failed. Resolve conflicts and run 'git rebase --continue'"; \
			exit 1; \
		}; \
	fi; \
	LOCAL_AHEAD=$$(git rev-list --count origin/$$BRANCH..HEAD 2>/dev/null || echo 0); \
	if [ $$LOCAL_AHEAD -gt 0 ]; then \
		echo "Pushing $$LOCAL_AHEAD commit(s)..."; \
		git push origin $$BRANCH; \
	else \
		echo "Already in sync."; \
	fi

sync: push

update: _check-brew
	brew update
	brew upgrade
	brew upgrade --cask --greedy
	brew cleanup
	-brew doctor

clean: _check-brew
	@echo "Packages not in Brewfile:"
	@brew bundle cleanup --file=$(BREWFILE) || true
	@echo ""
	@printf "Remove these packages? [y/N] " && read confirm && [ "$$confirm" = "y" ] && \
		brew bundle cleanup --force --file=$(BREWFILE) && brew autoremove || \
		echo "Aborted."

check: _check-brew
	brew bundle check --file=$(BREWFILE)

doctor: _check-brew
	-brew doctor

uninstall: deps
ifeq ($(TYPE),casks)
	@selected=$$(brew list --cask | gum choose --no-limit); \
	if [ -n "$$selected" ]; then \
		echo "$$selected" | xargs brew uninstall --cask --force; \
	else \
		echo "Nothing selected"; \
	fi
else ifeq ($(TYPE),formulas)
	@selected=$$(brew list --formula | gum choose --no-limit); \
	if [ -n "$$selected" ]; then \
		echo "$$selected" | xargs brew uninstall --force; \
	else \
		echo "Nothing selected"; \
	fi
else
	@echo "Error: Specify TYPE=formulas or TYPE=casks"
	@exit 1
endif

list: _check-brew
ifeq ($(TYPE),casks)
	brew list --cask
else ifeq ($(TYPE),formulas)
	brew list --formula
else
	brew list
endif

outdated: _check-brew
	brew outdated --greedy
