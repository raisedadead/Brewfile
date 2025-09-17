.PHONY: help deps install install-no-mas install-no-vscode install-no-mas-vscode dump dump-no-mas dump-no-vscode dump-no-mas-vscode commit push sync update clean check doctor uninstall list outdated
.DEFAULT_GOAL := help

# Configuration
export HOMEBREW_NO_ENV_HINTS=1
BREWFILE := Brewfile
TYPE ?= all

deps:
	@command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew is not installed"; exit 1; }
	@command -v gum >/dev/null 2>&1 || { echo "Error: gum is not installed. Run 'brew install gum'"; exit 1; }
	@command -v xargs >/dev/null 2>&1 || { echo "Error: xargs is not installed"; exit 1; }
	@echo "All dependencies are installed"

help:
	@echo "Brewfile Management:"
	@echo "  make install           - Install everything"
	@echo "  make install-no-mas    - Install everything except Mac App Store"
	@echo "  make install-no-vscode - Install everything except VS Code extensions"
	@echo "  make install-no-mas-vscode - Install everything except MAS & VS Code"
	@echo "  make uninstall [TYPE=formulas|casks]"
	@echo "  make update            - Update all packages, cleanup, doctor"
	@echo "  make clean             - Remove unused dependencies"
	@echo ""
	@echo "Status & Info:"
	@echo "  make check             - Check if system matches Brewfile"
	@echo "  make doctor            - Run brew doctor"
	@echo "  make list [TYPE=formulas|casks]"
	@echo "  make outdated          - Show outdated packages"
	@echo "  make deps              - Check required dependencies"
	@echo ""
	@echo "File Management:"
	@echo "  make dump              - Dump everything to Brewfile"
	@echo "  make dump-no-mas       - Dump everything except Mac App Store"
	@echo "  make dump-no-vscode    - Dump everything except VS Code extensions"
	@echo "  make dump-no-mas-vscode - Dump everything except MAS & VS Code"
	@echo "  make commit            - Git commit Brewfile"
	@echo "  make push              - Push changes (with remote update check)"
	@echo "  make sync              - Alias for push"

install:
	brew bundle install --file=$(BREWFILE)

install-no-mas:
	HOMEBREW_BUNDLE_MAS_SKIP="*" brew bundle install --file=$(BREWFILE)

install-no-vscode:
	HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file=$(BREWFILE)

install-no-mas-vscode:
	HOMEBREW_BUNDLE_MAS_SKIP="*" HOMEBREW_BUNDLE_VSCODE_SKIP="*" brew bundle install --file=$(BREWFILE)

dump:
	brew bundle dump --force --file=$(BREWFILE)

dump-no-mas:
	brew bundle dump --force --no-mas --file=$(BREWFILE)

dump-no-vscode:
	brew bundle dump --force --no-vscode --file=$(BREWFILE)

dump-no-mas-vscode:
	brew bundle dump --force --no-mas --no-vscode --file=$(BREWFILE)

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
	@REMOTE_AHEAD=$$(git rev-list --count HEAD..origin/$$(git branch --show-current)); \
	LOCAL_AHEAD=$$(git rev-list --count origin/$$(git branch --show-current)..HEAD); \
	if [ $$REMOTE_AHEAD -gt 0 ]; then \
		echo "Remote has changes, fetching and rebasing..."; \
		git rebase origin/$$(git branch --show-current) || { \
			echo "Rebase failed. Please resolve conflicts manually and run 'git rebase --continue'"; \
			exit 1; \
		}; \
	elif [ $$LOCAL_AHEAD -gt 0 ]; then \
		echo "Local has all changes from remote, pushing new changes..."; \
	else \
		echo "No changes on remote or local, already in sync."; \
	fi; \
	if [ $$LOCAL_AHEAD -gt 0 ] || [ $$REMOTE_AHEAD -gt 0 ]; then \
		echo "Pushing changes..."; \
		git push origin $$(git branch --show-current); \
	fi

sync: push

update:
	brew update
	brew upgrade
	brew upgrade --cask
	brew cleanup
	-brew doctor

clean:
	brew bundle cleanup --file=$(BREWFILE)
	brew autoremove

check:
	brew bundle check --file=$(BREWFILE)

doctor:
	-brew doctor

uninstall: deps
ifeq ($(TYPE),casks)
	brew list --cask | gum choose --no-limit | xargs brew uninstall --cask --force
else
	brew list --formula | gum choose --no-limit | xargs brew uninstall --force
endif

list:
ifeq ($(TYPE),casks)
	brew list --cask
else ifeq ($(TYPE),formulas)
	brew list --formula
else
	brew list
endif

outdated:
	brew outdated --greedy