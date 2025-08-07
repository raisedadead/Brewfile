.PHONY: help deps install dump commit update clean check doctor uninstall
.DEFAULT_GOAL := help

# Export to suppress Homebrew hints
export HOMEBREW_NO_ENV_HINTS=1

deps:
	@command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew is not installed"; exit 1; }
	@command -v gum >/dev/null 2>&1 || { echo "Error: gum is not installed. Run 'brew install gum'"; exit 1; }
	@command -v xargs >/dev/null 2>&1 || { echo "Error: xargs is not installed"; exit 1; }
	@echo "All dependencies are installed"

help:
	@echo "Available commands:"
	@echo "  make deps              - Check if required dependencies are installed"
	@echo "  make install [type=all|formulas|casks|vscode|mas] - Install from Brewfile"
	@echo "  make dump              - Update Brewfile with current packages"
	@echo "  make commit            - Commit Brewfile changes"
	@echo "  make update            - Update all packages, cleanup, and doctor"
	@echo "  make clean             - Remove unused dependencies"
	@echo "  make check             - Check system for issues"
	@echo "  make doctor            - Run brew doctor"
	@echo "  make uninstall [type=formulas|casks] - Interactive uninstall"

# Install command with type parameter (default: all)
type ?= all
install:
ifeq ($(type),formulas)
	brew bundle install --no-cask --no-mas --no-vscode --file=Brewfile
else ifeq ($(type),casks)
	brew bundle install --cask --no-mas --no-vscode --file=Brewfile
else ifeq ($(type),vscode)
	brew bundle install --vscode --file=Brewfile
else ifeq ($(type),mas)
	brew bundle install --mas --file=Brewfile
else
	brew bundle install --all --file=Brewfile
endif

dump:
	brew bundle dump --force --file=Brewfile

commit:
	git add Brewfile
	git commit -m "chore: update brewfile $$(date +%Y-%m-%d)"

update:
	brew update
	brew upgrade
	brew upgrade --cask
	brew cleanup
	brew doctor

clean:
	brew bundle cleanup --file=Brewfile
	brew autoremove

check:
	brew bundle check --file=Brewfile

doctor:
	brew doctor

# Uninstall command with type parameter (default: formulas)
type ?= formulas
uninstall: deps
ifeq ($(type),casks)
	brew list --cask | gum choose --no-limit | xargs brew uninstall --cask --force
else
	brew list --formula | gum choose --no-limit | xargs brew uninstall --force
endif