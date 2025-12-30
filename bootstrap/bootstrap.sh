#!/usr/bin/env bash

################################################################################
# bootstrap.sh - macOS Setup Script
#
# This script automates the setup of a new macOS machine with:
# - Homebrew package installation
# - Dotfile deployment via GNU Stow
# - macOS system preferences
# - Development environment configuration
#
# Usage: ./bootstrap.sh [options]
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
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
STOW_DIR="$DOTFILES_DIR/stow"

# Options
SKIP_HOMEBREW=false
SKIP_DOTFILES=false
SKIP_MACOS=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
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
            echo "  --skip-homebrew    Skip Homebrew installation and package installation"
            echo "  --skip-dotfiles    Skip dotfile deployment"
            echo "  --skip-macos       Skip macOS defaults configuration"
            echo "  --help             Display this help message"
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
        print_info "Installing packages from Brewfile..."
        brew bundle --file="$SCRIPT_DIR/brewfile" --no-lock
        print_success "Packages installed"
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
            stow -v -t "$HOME" "$package" 2>&1 | grep -v "^LINK:" || true
            print_success "$package deployed"
        done

        if [ -d "$BACKUP_DIR" ]; then
            print_success "Dotfiles deployed. Backups saved to: $BACKUP_DIR"
        else
            print_success "Dotfiles deployed. No backups needed."
        fi
    fi

    cd - > /dev/null || exit 1
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

# Install Oh My Zsh if not present (optional)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    if confirm "Install Oh My Zsh? (optional)"; then
        print_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed"
    fi
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
# 6. SSH Key Setup
################################################################################

print_header "SSH Configuration"

if [ -f "$HOME/.ssh/config" ]; then
    print_success "SSH config found at ~/.ssh/config"
else
    print_warning "No SSH config found"
fi

# Check for SSH keys
if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
    if confirm "No SSH keys found. Generate a new SSH key?"; then
        read -p "Enter your email for SSH key: " ssh_email
        ssh-keygen -t ed25519 -C "$ssh_email"

        print_success "SSH key generated"
        print_info "Add this key to GitHub/GitLab:"
        cat "$HOME/.ssh/id_ed25519.pub"

        # Start SSH agent and add key
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
    fi
else
    print_success "SSH keys already exist"
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
