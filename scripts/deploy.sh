#!/usr/bin/env bash

################################################################################
# deploy.sh - Automated Dotfiles Deployment Script
#
# This script simplifies the deployment of dotfiles using GNU Stow.
# It handles backing up existing files, deploying packages, and verification.
#
# Usage: ./deploy.sh [options] [packages...]
#   --restow       Restow all packages (delete and recreate symlinks)
#   --delete       Remove symlinks for specified packages
#   --dry-run      Show what would be done without making changes
#   --force        Skip backup and overwrite existing files
#   --help         Display this help message
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
STOW_DIR="$DOTFILES_DIR/stow"
TARGET_DIR="$HOME"

# Options
RESTOW=false
DELETE=false
DRY_RUN=false
FORCE=false
PACKAGES=()

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

show_help() {
    cat << EOF
Dotfiles Deployment Script

Usage: $0 [options] [packages...]

Options:
    --restow       Restow all packages (delete and recreate symlinks)
    --delete       Remove symlinks for specified packages
    --dry-run      Show what would be done without making changes
    --force        Skip backup and overwrite existing files
    --help         Display this help message

Packages:
    If no packages are specified, all packages in stow/ will be processed.
    Otherwise, only the specified packages will be processed.

Examples:
    $0                      # Deploy all packages
    $0 zsh git              # Deploy only zsh and git packages
    $0 --restow             # Restow all packages
    $0 --delete vim         # Remove vim package
    $0 --dry-run            # Preview deployment
    $0 --force zsh          # Force deploy zsh (no backup)

Available Packages:
$(ls -1 "$STOW_DIR" 2>/dev/null | sed 's/^/    /')

EOF
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --restow)
            RESTOW=true
            shift
            ;;
        --delete)
            DELETE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            PACKAGES+=("$1")
            shift
            ;;
    esac
done

################################################################################
# Validation
################################################################################

print_header "Dotfiles Deployment"

# Check if stow is installed
if ! command_exists stow; then
    print_error "GNU Stow is not installed. Install it with: brew install stow"
    exit 1
fi

# Check if stow directory exists
if [ ! -d "$STOW_DIR" ]; then
    print_error "Stow directory not found: $STOW_DIR"
    exit 1
fi

# If no packages specified, get all packages
if [ ${#PACKAGES[@]} -eq 0 ]; then
    cd "$STOW_DIR"
    mapfile -t PACKAGES < <(ls -d */ 2>/dev/null | sed 's#/##')
    cd - > /dev/null
fi

# Validate packages exist
for package in "${PACKAGES[@]}"; do
    if [ ! -d "$STOW_DIR/$package" ]; then
        print_error "Package not found: $package"
        exit 1
    fi
done

print_info "Dotfiles directory: $DOTFILES_DIR"
print_info "Stow directory: $STOW_DIR"
print_info "Target directory: $TARGET_DIR"
print_info "Packages to process: ${PACKAGES[*]}"

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No changes will be made"
fi

################################################################################
# Backup Existing Files
################################################################################

if [ "$FORCE" = false ] && [ "$DELETE" = false ] && [ "$DRY_RUN" = false ]; then
    print_header "Checking for Conflicts"

    BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
    NEEDS_BACKUP=false

    for package in "${PACKAGES[@]}"; do
        # Check if stow would conflict
        cd "$STOW_DIR"

        if stow -n -v -t "$TARGET_DIR" "$package" 2>&1 | grep -q "existing target"; then
            print_warning "Conflicts detected for package: $package"
            NEEDS_BACKUP=true
        fi

        cd - > /dev/null
    done

    if [ "$NEEDS_BACKUP" = true ]; then
        print_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"

        for package in "${PACKAGES[@]}"; do
            cd "$STOW_DIR"

            # Get list of files that would be linked
            stow -n -v -t "$TARGET_DIR" "$package" 2>&1 | grep "existing target" | while read -r line; do
                # Extract file path from stow output
                if [[ $line =~ existing\ target\ is\ (.+)\ not ]]; then
                    conflicting_file="${BASH_REMATCH[1]}"
                    conflicting_path="$TARGET_DIR/$conflicting_file"

                    if [ -e "$conflicting_path" ] && [ ! -L "$conflicting_path" ]; then
                        backup_path="$BACKUP_DIR/$conflicting_file"
                        mkdir -p "$(dirname "$backup_path")"

                        cp -a "$conflicting_path" "$backup_path"
                        print_info "Backed up: $conflicting_file"

                        rm -f "$conflicting_path"
                    fi
                fi
            done

            cd - > /dev/null
        done

        if [ -d "$BACKUP_DIR" ]; then
            print_success "Backup created: $BACKUP_DIR"
        fi
    else
        print_success "No conflicts detected"
    fi
fi

################################################################################
# Deploy/Remove Packages
################################################################################

cd "$STOW_DIR"

if [ "$DELETE" = true ]; then
    print_header "Removing Packages"

    for package in "${PACKAGES[@]}"; do
        print_info "Removing $package..."

        if [ "$DRY_RUN" = true ]; then
            stow -n -D -v -t "$TARGET_DIR" "$package"
        else
            stow -D -v -t "$TARGET_DIR" "$package" 2>&1 | grep -v "^UNLINK:" || true
            print_success "$package removed"
        fi
    done

elif [ "$RESTOW" = true ]; then
    print_header "Restowing Packages"

    for package in "${PACKAGES[@]}"; do
        print_info "Restowing $package..."

        if [ "$DRY_RUN" = true ]; then
            stow -n -R -v -t "$TARGET_DIR" "$package"
        else
            stow -R -v -t "$TARGET_DIR" "$package" 2>&1 | grep -v "^LINK:\|^UNLINK:" || true
            print_success "$package restowed"
        fi
    done

else
    print_header "Deploying Packages"

    for package in "${PACKAGES[@]}"; do
        print_info "Deploying $package..."

        if [ "$DRY_RUN" = true ]; then
            stow -n -v -t "$TARGET_DIR" "$package"
        else
            stow -v -t "$TARGET_DIR" "$package" 2>&1 | grep -v "^LINK:" || true
            print_success "$package deployed"
        fi
    done
fi

cd - > /dev/null

################################################################################
# Verification
################################################################################

if [ "$DRY_RUN" = false ] && [ "$DELETE" = false ]; then
    print_header "Verification"

    VERIFIED=true

    for package in "${PACKAGES[@]}"; do
        # Check if key files are symlinked
        case $package in
            zsh)
                if [ -L "$HOME/.zshrc" ]; then
                    print_success "zsh: .zshrc is symlinked"
                else
                    print_error "zsh: .zshrc is not symlinked"
                    VERIFIED=false
                fi
                ;;
            git)
                if [ -L "$HOME/.gitconfig" ]; then
                    print_success "git: .gitconfig is symlinked"
                else
                    print_error "git: .gitconfig is not symlinked"
                    VERIFIED=false
                fi
                ;;
            vim)
                if [ -L "$HOME/.vimrc" ]; then
                    print_success "vim: .vimrc is symlinked"
                else
                    print_error "vim: .vimrc is not symlinked"
                    VERIFIED=false
                fi
                ;;
            nvim)
                if [ -L "$HOME/.config/nvim/init.lua" ]; then
                    print_success "nvim: init.lua is symlinked"
                else
                    print_error "nvim: init.lua is not symlinked"
                    VERIFIED=false
                fi
                ;;
            *)
                print_info "$package: Skipping verification (no checks defined)"
                ;;
        esac
    done

    if [ "$VERIFIED" = true ]; then
        print_success "All verifications passed!"
    else
        print_warning "Some verifications failed. Check output above."
    fi
fi

################################################################################
# Post-Deployment
################################################################################

if [ "$DRY_RUN" = false ] && [ "$DELETE" = false ]; then
    print_header "Post-Deployment Steps"

    echo "Recommended next steps:"
    echo "  1. Restart your terminal or run: exec zsh"
    echo "  2. Verify configurations are working"
    echo "  3. Review any backup files in: ${BACKUP_DIR:-none created}"

    # Source new shell config if in zsh
    if [ -n "$ZSH_VERSION" ]; then
        print_info "To apply changes immediately, run: exec zsh"
    fi
fi

################################################################################
# Completion
################################################################################

print_header "Deployment Complete!"

if [ "$DRY_RUN" = true ]; then
    print_info "This was a dry run. No changes were made."
    print_info "Run without --dry-run to apply changes."
else
    print_success "Dotfiles deployment successful!"
fi

exit 0
