#!/usr/bin/env bash

################################################################################
# sync-apps.sh - Sync Installed Apps with Brewfile
#
# This script compares your installed applications with the Brewfile and
# helps you keep your package list up-to-date.
#
# Usage: ./sync-apps.sh [--audit|--add|--remove|--update]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
BREWFILE="$DOTFILES_DIR/bootstrap/brewfile"

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

# Check if app is in Brewfile
is_in_brewfile() {
    local app="$1"
    grep -qi "cask \"$app\"" "$BREWFILE" || grep -qi "mas \".*\", id:.*# .*$app" "$BREWFILE"
}

# Get cask name from app name
get_cask_name() {
    local app="$1"
    echo "$app" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/\.app$//'
}

# Check if cask exists in Homebrew
cask_exists() {
    local cask="$1"
    brew search --cask "^${cask}$" 2>/dev/null | grep -q "^${cask}$"
}

################################################################################
# Audit Mode - Show differences
################################################################################

audit() {
    print_header "Brewfile Audit"

    # Get installed apps (excluding system apps)
    INSTALLED_APPS=$(ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | grep -v "^Safari$\|^Utilities$\|^Developer$\|^TestFlight$")

    # Arrays for categorization
    declare -a in_brewfile=()
    declare -a not_in_brewfile=()
    declare -a available_casks=()
    declare -a unavailable_casks=()

    local app_count
    app_count=$(echo "$INSTALLED_APPS" | wc -l | tr -d ' ')
    print_info "Scanning $app_count applications..."
    echo ""

    while IFS= read -r app; do
        cask_name=$(get_cask_name "$app")

        if is_in_brewfile "$cask_name"; then
            in_brewfile+=("$app")
        else
            not_in_brewfile+=("$app")

            # Check if available as cask
            if cask_exists "$cask_name"; then
                available_casks+=("$cask_name|$app")
            else
                unavailable_casks+=("$app")
            fi
        fi
    done <<< "$INSTALLED_APPS"

    # Summary
    print_section "Summary"
    echo ""
    echo -e "    ${GREEN}${#in_brewfile[@]}${NC} tracked in Brewfile"
    echo -e "    ${YELLOW}${#available_casks[@]}${NC} can be added ${DIM}(installed, available as cask)${NC}"
    echo -e "    ${DIM}${#unavailable_casks[@]}${NC} not available via Homebrew"
    echo ""

    # Casks in Brewfile but not installed
    brewfile_casks=$(grep "^cask " "$BREWFILE" | sed 's/cask "\([^"]*\)".*/\1/')

    not_installed=()
    while IFS= read -r cask; do
        app_name=$(echo "$cask" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' | sed 's/ //g')

        if ! echo "$INSTALLED_APPS" | grep -qi "^$app_name$"; then
            not_installed+=("$cask")
        fi
    done <<< "$brewfile_casks"

    if [ ${#not_installed[@]} -gt 0 ]; then
        echo -e "    ${RED}${#not_installed[@]}${NC} in Brewfile but not installed"
        echo ""
    fi

    # Available to add
    if [ ${#available_casks[@]} -gt 0 ]; then
        print_section "Can be added"
        echo ""
        for entry in "${available_casks[@]}"; do
            cask="${entry%%|*}"
            app="${entry##*|}"
            printf "    ${GREEN}+${NC} %-24s ${DIM}cask \"%s\"${NC}\n" "$app" "$cask"
        done
        echo ""
        print_info "Run 'dotfiles add-apps' to add these interactively"
        echo ""
    fi

    # Stale Brewfile entries
    if [ ${#not_installed[@]} -gt 0 ]; then
        print_section "Stale Brewfile entries"
        echo -e "  ${DIM}In Brewfile but not installed — remove or reinstall${NC}"
        echo ""
        for cask in "${not_installed[@]}"; do
            echo -e "    ${RED}✗${NC} $cask"
        done
        echo ""
        print_info "Run 'brew bundle --file=$BREWFILE' to install, or remove from Brewfile"
        echo ""
    fi

    # Not available via Homebrew (collapsed by default)
    if [ ${#unavailable_casks[@]} -gt 0 ]; then
        print_section "Not available via Homebrew"
        echo -e "  ${DIM}App Store, direct downloads, or bundled apps — no action needed${NC}"
        echo ""
        # Show in compact columns
        local col=0
        for app in "${unavailable_casks[@]}"; do
            printf "    ${DIM}%-28s${NC}" "$app"
            col=$(( col + 1 ))
            if [ $(( col % 2 )) -eq 0 ]; then
                echo ""
            fi
        done
        [ $(( col % 2 )) -ne 0 ] && echo ""
        echo ""
    fi
}

################################################################################
# Add Mode - Interactively add new apps
################################################################################

add_apps() {
    print_header "Add New Applications to Brewfile"

    # Get apps not in brewfile
    INSTALLED_APPS=$(ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | grep -v "^Safari$\|^Utilities$\|^Developer$\|^TestFlight$")

    available_to_add=()

    while IFS= read -r app; do
        cask_name=$(get_cask_name "$app")

        if ! is_in_brewfile "$cask_name" && cask_exists "$cask_name"; then
            available_to_add+=("$cask_name|$app")
        fi
    done <<< "$INSTALLED_APPS"

    if [ ${#available_to_add[@]} -eq 0 ]; then
        print_success "No new applications to add!"
        return
    fi

    echo "Found ${#available_to_add[@]} applications that can be added:"
    echo ""

    for entry in "${available_to_add[@]}"; do
        cask="${entry%%|*}"
        app="${entry##*|}"

        echo -e "${CYAN}Add '$app' (cask: $cask)?${NC}"
        read -p "  [y/n/q/i] (y=yes, n=no, q=quit, i=info) " -n 1 -r
        echo

        case $REPLY in
            y|Y)
                # Get category from user
                echo "  Category?"
                echo "    1) Browsers"
                echo "    2) Development"
                echo "    3) AI Tools"
                echo "    4) Communication"
                echo "    5) Productivity"
                echo "    6) Utilities"
                echo "    7) Media"
                echo "    8) Design"
                echo "    9) Other"
                read -p "  Enter number (1-9): " -n 1 category
                echo

                # Add to brewfile (this would need proper parsing and insertion)
                print_success "Would add: cask \"$cask\"  # $app"
                print_warning "Manual addition recommended - add to appropriate section in brewfile"
                echo "    cask \"$cask\"  # $app"
                echo ""
                ;;
            i|I)
                brew info --cask "$cask"
                echo ""
                ;;
            q|Q)
                print_info "Exiting..."
                return
                ;;
            *)
                print_info "Skipped"
                ;;
        esac
    done

    print_info "Commit your changes:"
    echo "  cd $DOTFILES_DIR"
    echo "  git add bootstrap/brewfile"
    echo "  git commit -m 'Add new applications to Brewfile'"
}

################################################################################
# Update Mode - Update all packages
################################################################################

update_all() {
    print_header "Updating All Packages"

    print_info "Updating Homebrew..."
    brew update

    print_info "Upgrading formula..."
    brew upgrade

    print_info "Upgrading casks..."
    brew upgrade --cask --greedy

    print_info "Upgrading Mac App Store apps..."
    if command -v mas &> /dev/null; then
        mas upgrade
    else
        print_warning "mas not installed, skipping App Store updates"
    fi

    print_info "Cleaning up..."
    brew cleanup -s

    print_success "All packages updated!"
}

################################################################################
# Export Mode - Generate current state
################################################################################

export_current() {
    print_header "Exporting Current Installation State"

    local export_file="$DOTFILES_DIR/bootstrap/brewfile.current"

    print_info "Generating brewfile from current installation..."

    brew bundle dump --file="$export_file" --force

    print_success "Current state exported to: $export_file"
    print_info "Compare with existing brewfile:"
    echo "  diff $BREWFILE $export_file"
}

################################################################################
# Main
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [command]

Commands:
    --audit     Show differences between installed apps and Brewfile
    --add       Interactively add new apps to Brewfile
    --update    Update all Homebrew packages and casks
    --export    Export current installation to brewfile.current
    --help      Show this help message

Examples:
    $0 --audit          # Check what's out of sync
    $0 --add            # Add newly installed apps
    $0 --update         # Update everything

Recommended workflow:
    1. Install a new app normally (App Store, download, etc.)
    2. Run './sync-apps.sh --audit' to see what's new
    3. Run './sync-apps.sh --add' to add to Brewfile
    4. Commit the changes to git

Automated scheduling:
    Add to crontab for weekly audits:
    0 9 * * 1 cd $DOTFILES_DIR && ./scripts/sync-apps.sh --audit
EOF
}

# Parse command
case "${1:-}" in
    --audit)
        audit
        ;;
    --add)
        add_apps
        ;;
    --update)
        update_all
        ;;
    --export)
        export_current
        ;;
    --help)
        show_usage
        ;;
    "")
        # Default to audit if no command given
        audit
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
