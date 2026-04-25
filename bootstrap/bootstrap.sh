#!/usr/bin/env bash

################################################################################
# bootstrap.sh - macOS Setup Script
#
# Declarative macOS configuration inspired by NixOS.
# Run anytime to converge your system to the desired state.
#
# Features:
# - Homebrew package installation (smart detection by default)
# - Dotfile deployment via GNU Stow
# - macOS system preferences
# - Development environment configuration
#
# Usage: ./bootstrap.sh [options]
#   --force            Force reinstall all packages (skip smart detection)
#   --skip-homebrew    Skip Homebrew installation and package installation
#   --skip-dotfiles    Skip dotfile deployment
#   --skip-macos       Skip macOS defaults configuration
#   --help             Display this help message
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
STOW_DIR="$DOTFILES_DIR/stow"

# Options
FORCE_REINSTALL=false
SKIP_HOMEBREW=false
SKIP_DOTFILES=false
SKIP_MACOS=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo ""
    echo -e "${CYAN}╭$(printf '%*s' $width '' | tr ' ' '─')╮${NC}"
    echo -e "${CYAN}│${NC}$(printf '%*s' $padding '')${BOLD}${title}${NC}$(printf '%*s' $((width - padding - ${#title})) '')${CYAN}│${NC}"
    echo -e "${CYAN}╰$(printf '%*s' $width '' | tr ' ' '─')╯${NC}"
    echo ""
}

print_section() {
    local title="$1"
    echo -e "  ${YELLOW}${BOLD}${title}${NC}"
    echo -e "  ${DIM}$(printf '%*s' ${#title} '' | tr ' ' '─')${NC}"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ask for confirmation
confirm() {
    read -p "$1 (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_REINSTALL=true
            shift
            ;;
        --skip-homebrew)
            SKIP_HOMEBREW=true
            shift
            ;;
        --skip-dotfiles)
            SKIP_DOTFILES=true
            shift
            ;;
        --skip-macos)
            SKIP_MACOS=true
            shift
            ;;
        --help)
            echo "Usage: ./bootstrap.sh [options]"
            echo ""
            echo "Declarative macOS configuration - run anytime to sync your system."
            echo ""
            echo "Options:"
            echo "  --force            Force reinstall all packages (skip smart detection)"
            echo "  --skip-homebrew    Skip Homebrew installation and package installation"
            echo "  --skip-dotfiles    Skip dotfile deployment"
            echo "  --skip-macos       Skip macOS defaults configuration"
            echo "  --help             Display this help message"
            echo ""
            echo "Examples:"
            echo "  ./bootstrap.sh                    # Smart install (default)"
            echo "  ./bootstrap.sh --force            # Reinstall everything"
            echo "  ./bootstrap.sh --skip-macos       # Skip macOS preferences"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Main Setup
################################################################################

print_header "macOS Bootstrap Script"
print_info "Dotfiles directory: $DOTFILES_DIR"
print_info "Stow directory: $STOW_DIR"

# Request sudo access upfront
print_info "This script requires sudo access for some operations"
sudo -v

# Keep sudo alive throughout the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

################################################################################
# 1. Homebrew Installation
################################################################################

if [ "$SKIP_HOMEBREW" = false ]; then
    print_header "Homebrew Setup"

    if ! command_exists brew; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        print_success "Homebrew installed"
    else
        print_success "Homebrew already installed"
        print_info "Updating Homebrew..."
        brew update
    fi

    # Install packages from Brewfile
    if [ -f "$SCRIPT_DIR/brewfile" ]; then
        if [ "$FORCE_REINSTALL" = true ]; then
            print_info "Force mode: Reinstalling ALL packages from Brewfile..."
            print_warning "This will take 20-40 minutes and may reinstall existing apps"
            brew bundle --file="$SCRIPT_DIR/brewfile" --verbose
            print_success "All packages reinstalled"
        else
            print_info "Smart mode: Detecting and installing only missing packages..."
            print_info "(Use --force to reinstall everything)"

            if [ -f "$SCRIPT_DIR/brew-install-smart.sh" ]; then
                bash "$SCRIPT_DIR/brew-install-smart.sh"
                print_success "Package installation complete"
            else
                print_warning "brew-install-smart.sh not found, falling back to brew bundle"
                brew bundle --file="$SCRIPT_DIR/brewfile" --verbose
                print_success "Packages installed"
            fi
        fi
    else
        print_warning "Brewfile not found at $SCRIPT_DIR/brewfile"
    fi
else
    print_warning "Skipping Homebrew setup"
fi

################################################################################
# 2. GNU Stow - Dotfile Deployment
################################################################################

if [ "$SKIP_DOTFILES" = false ]; then
    print_header "Dotfile Deployment with GNU Stow"

    # Ensure GNU Stow is installed
    if ! command_exists stow; then
        print_error "GNU Stow not found. Please install it first: brew install stow"
        exit 1
    fi

    # Navigate to stow directory
    cd "$STOW_DIR" || exit 1

    # Get list of stow packages (directories in stow/)
    STOW_PACKAGES=($(ls -d */ 2>/dev/null | sed 's#/##'))

    if [ ${#STOW_PACKAGES[@]} -eq 0 ]; then
        print_warning "No stow packages found in $STOW_DIR"
    else
        print_info "Found ${#STOW_PACKAGES[@]} stow packages: ${STOW_PACKAGES[*]}"

        # Backup existing dotfiles
        print_info "Backing up existing dotfiles..."
        BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

        for package in "${STOW_PACKAGES[@]}"; do
            # Check if package would conflict
            if stow -n -v -t "$HOME" "$package" 2>&1 | grep -q "existing"; then
                print_warning "Conflicts detected for $package, backing up..."
                mkdir -p "$BACKUP_DIR"

                # Find conflicting files and back them up
                stow -n -v -t "$HOME" "$package" 2>&1 | grep "existing" | while read -r line; do
                    if [[ $line =~ existing\ target\ is\ (.+)\ not ]]; then
                        conflicting_file="${BASH_REMATCH[1]}"
                        if [ -e "$HOME/$conflicting_file" ]; then
                            mkdir -p "$BACKUP_DIR/$(dirname "$conflicting_file")"
                            mv "$HOME/$conflicting_file" "$BACKUP_DIR/$conflicting_file"
                            print_info "Backed up: $conflicting_file"
                        fi
                    fi
                done
            fi
        done

        # Deploy dotfiles with stow
        print_info "Deploying dotfiles..."
        for package in "${STOW_PACKAGES[@]}"; do
            print_info "Stowing $package..."
            if stow -t "$HOME" "$package" 2>&1; then
                print_success "$package deployed"
            else
                print_error "$package deployment failed"
            fi
        done

        if [ -d "$BACKUP_DIR" ]; then
            print_success "Dotfiles deployed. Backups saved to: $BACKUP_DIR"
        else
            print_success "Dotfiles deployed. No backups needed."
        fi
    fi

    cd - > /dev/null || exit 1

    # Post-stow: install auto-adopt daemon
    if [ -f "$SCRIPT_DIR/../scripts/setup-auto-adopt.sh" ]; then
        print_info "Installing auto-adopt daemon..."
        bash "$SCRIPT_DIR/../scripts/setup-auto-adopt.sh" install
        print_success "Auto-adopt daemon installed"
    fi

    # Post-stow: install git hooks
    if [ -f "$SCRIPT_DIR/../scripts/setup-hooks.sh" ]; then
        print_info "Installing git hooks..."
        bash "$SCRIPT_DIR/../scripts/setup-hooks.sh"
        print_success "Git hooks installed"
    fi

    # Post-stow: sync AI skills (if private skills repo is cloned)
    if [ -d "$HOME/.skills" ]; then
        if [ -f "$SCRIPT_DIR/../scripts/skills-sync.sh" ]; then
            print_info "Syncing AI skills..."
            bash "$SCRIPT_DIR/../scripts/skills-sync.sh"
            print_success "Skills synced to Claude Code and Cursor"
        fi
    else
        print_info "Skills repo not found. Clone it to enable AI skills:"
        echo "  git clone git@github.com:kyledenis/skills ~/.skills"
        echo "  skills-sync"
    fi
else
    print_warning "Skipping dotfile deployment"
fi

################################################################################
# 3. macOS System Preferences
################################################################################

if [ "$SKIP_MACOS" = false ]; then
    print_header "macOS System Preferences"

    if [ -f "$SCRIPT_DIR/macos-defaults.sh" ]; then
        if confirm "Apply macOS system preferences?"; then
            print_info "Applying macOS defaults..."
            bash "$SCRIPT_DIR/macos-defaults.sh"
            print_success "macOS preferences applied"
        else
            print_warning "Skipped macOS preferences"
        fi
    else
        print_warning "macOS defaults script not found at $SCRIPT_DIR/macos-defaults.sh"
    fi
else
    print_warning "Skipping macOS preferences"
fi

################################################################################
# 4. Shell Configuration
################################################################################

print_header "Shell Configuration"

# Set zsh as default shell if not already
if [ "$SHELL" != "$(which zsh)" ]; then
    print_info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    print_success "Default shell changed to zsh (restart terminal to apply)"
else
    print_success "zsh is already the default shell"
fi

################################################################################
# 5. Git Configuration
################################################################################

print_header "Git Configuration"

if [ -f "$HOME/.gitconfig" ]; then
    print_success "Git config found at ~/.gitconfig"

    # Verify git user is set
    if ! git config --global user.name > /dev/null 2>&1; then
        print_warning "Git user.name not set"
        read -p "Enter your Git name: " git_name
        git config --global user.name "$git_name"
    fi

    if ! git config --global user.email > /dev/null 2>&1; then
        print_warning "Git user.email not set"
        read -p "Enter your Git email: " git_email
        git config --global user.email "$git_email"
    fi

    print_success "Git configuration complete"
else
    print_warning "No .gitconfig found. Please configure Git manually or ensure stow deployed it."
fi

################################################################################
# 6. SSH Key Setup (1Password SSH Agent)
################################################################################

print_header "SSH Configuration"

# Check 1Password SSH agent
if [ -f "$HOME/.config/1Password/ssh/agent.toml" ]; then
    print_success "1Password SSH agent config found"
else
    print_warning "1Password SSH agent not configured"
    print_info "Install 1Password, enable the SSH agent, and configure ~/.config/1Password/ssh/agent.toml"
fi

# Check SSH config (deployed by stow)
if [ -f "$HOME/.ssh/config" ]; then
    print_success "SSH config found at ~/.ssh/config"
else
    print_warning "No SSH config found — ensure the ssh stow package was deployed"
fi

# Show existing keys
if [ -d "$HOME/.ssh/keys" ]; then
    local key_count
    key_count=$(ls "$HOME/.ssh/keys"/*.pub 2>/dev/null | wc -l | tr -d ' ')
    if [ "$key_count" -gt 0 ]; then
        print_success "$key_count SSH key(s) found in ~/.ssh/keys/"
    else
        print_info "No SSH keys yet. Create one with: ssh-create <name>"
    fi
else
    print_info "No SSH keys directory. Create a key with: ssh-create <name>"
fi

################################################################################
# 7. Create PARAS Directory Structure (if not exists)
################################################################################

print_header "PARAS Directory Structure"

PARAS_ROOT="$HOME/Documents/paras"

if [ -d "$PARAS_ROOT" ]; then
    print_success "PARAS directory exists at $PARAS_ROOT"
else
    if confirm "Create PARAS directory structure?"; then
        mkdir -p "$PARAS_ROOT/00-projects/personal"
        mkdir -p "$PARAS_ROOT/00-projects/work"
        mkdir -p "$PARAS_ROOT/01-areas"
        mkdir -p "$PARAS_ROOT/02-resources"
        mkdir -p "$PARAS_ROOT/03-archive"
        mkdir -p "$PARAS_ROOT/04-system/dotfiles"

        print_success "PARAS structure created"
    fi
fi

################################################################################
# 8. Post-Installation Steps
################################################################################

print_header "Post-Installation"

print_info "Recommended next steps:"
echo "  1. Review and customize ~/.zshrc"
echo "  2. Configure 1Password and enable SSH agent"
echo "  3. Sign in to applications (Slack, Chrome, etc.)"
echo "  4. Configure macOS System Preferences manually"
echo "  5. Install App Store applications with: mas install <id>"
echo "  6. Set up Time Machine backups"
echo "  7. Review PARAS documentation at $PARAS_ROOT/README.md"

################################################################################
# Completion
################################################################################

print_header "Bootstrap Complete!"

print_success "Setup complete! Some changes require a restart to take effect."

if confirm "Restart now?"; then
    print_info "Restarting..."
    sudo shutdown -r now
else
    print_warning "Please restart your Mac when convenient"
fi
