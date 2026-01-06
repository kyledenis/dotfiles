#!/usr/bin/env bash

################################################################################
# rogue - Quick reference for dotfiles commands and helpers
#
# A beautifully formatted summary of all available commands, functions,
# and utilities provided by your dotfiles.
#
# Usage: rogue [category]
#
################################################################################

# Colors
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Box drawing characters
H_LINE="─"
V_LINE="│"
TL_CORNER="╭"
TR_CORNER="╮"
BL_CORNER="╰"
BR_CORNER="╯"

print_header() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    echo -e "${CYAN}${TL_CORNER}$(printf '%*s' $width '' | tr ' ' "$H_LINE")${TR_CORNER}${NC}"
    echo -e "${CYAN}${V_LINE}${NC}$(printf '%*s' $padding '')${BOLD}${title}${NC}$(printf '%*s' $((width - padding - ${#title})) '')${CYAN}${V_LINE}${NC}"
    echo -e "${CYAN}${BL_CORNER}$(printf '%*s' $width '' | tr ' ' "$H_LINE")${BR_CORNER}${NC}"
    echo ""
}

print_section() {
    local title="$1"
    echo -e "  ${YELLOW}${BOLD}${title}${NC}"
    echo -e "  ${DIM}$(printf '%*s' ${#title} '' | tr ' ' '─')${NC}"
}

print_cmd() {
    local cmd="$1"
    local desc="$2"
    printf "    ${GREEN}%-20s${NC} %s\n" "$cmd" "$desc"
}

show_dotfiles() {
    print_section "Dotfiles Management"
    print_cmd "dotfiles status" "Check auto-adopt daemon status"
    print_cmd "dotfiles log [n]" "Show last n auto-adopt log entries"
    print_cmd "dotfiles run-now" "Manually trigger auto-adopt"
    print_cmd "dotfiles dry-run" "Preview what would be adopted"
    print_cmd "dotfiles install" "Install the auto-adopt daemon"
    print_cmd "dotfiles uninstall" "Remove the auto-adopt daemon"
    print_cmd "dotfiles add <file>" "Add file to stow management"
    print_cmd "dotfiles update" "Pull latest and re-stow"
    print_cmd "dotfiles st" "Show git status of dotfiles"
    print_cmd "dotfiles commit <msg>" "Commit dotfiles changes"
    print_cmd "dotfiles audit" "Compare installed apps vs Brewfile"
    print_cmd "dotfiles sync" "Full sync workflow"
    echo ""
}

show_navigation() {
    print_section "PARAS Navigation"
    print_cmd "p [dir]" "Navigate to Projects"
    print_cmd "a [dir]" "Navigate to Areas"
    print_cmd "r [dir]" "Navigate to Resources"
    print_cmd "ar [dir]" "Navigate to Archive"
    print_cmd "s [dir]" "Navigate to System"
    print_cmd "paras-list" "List all PARAS directories"
    print_cmd "paras-archive <name>" "Archive a project"
    echo ""
}

show_git() {
    print_section "Git Shortcuts"
    print_cmd "gst" "Git status (short format)"
    print_cmd "gcm <msg>" "Git commit with message"
    print_cmd "gac <msg>" "Git add all + commit"
    print_cmd "gacp <msg>" "Git add all + commit + push"
    print_cmd "gnb <branch>" "Create and checkout new branch"
    print_cmd "gdb <branch>" "Delete local and remote branch"
    print_cmd "glog" "Pretty git log graph"
    echo ""
}

show_python() {
    print_section "Python"
    print_cmd "venv-create" "Create and activate venv"
    print_cmd "venv-activate" "Activate existing venv"
    print_cmd "venv-deactivate" "Deactivate current venv"
    print_cmd "pip-save <pkg>" "Install and freeze to requirements"
    echo ""
}

show_network() {
    print_section "Network"
    print_cmd "myip" "Get external IP address"
    print_cmd "localip" "Get local IP address"
    print_cmd "port <num>" "Show processes on port"
    print_cmd "killport <num>" "Kill process on port"
    print_cmd "flushdns" "Flush DNS cache"
    echo ""
}

show_system() {
    print_section "System Utilities"
    print_cmd "mkcd <dir>" "Create directory and cd into it"
    print_cmd "extract <file>" "Extract any archive format"
    print_cmd "backup <file>" "Create timestamped backup"
    print_cmd "duf" "Disk usage of current directory"
    print_cmd "findlarge [size]" "Find files larger than size"
    print_cmd "cleanup [opts]" "Clean system (--dry-run, --all)"
    print_cmd "showhidden" "Show hidden files in Finder"
    print_cmd "hidehidden" "Hide hidden files in Finder"
    print_cmd "lock" "Lock screen"
    print_cmd "emptytrash" "Empty trash"
    echo ""
}

show_productivity() {
    print_section "Productivity"
    print_cmd "timer [duration]" "Set a timer (default: 5m)"
    print_cmd "countdown [secs]" "Countdown timer (default: 60)"
    print_cmd "notify <msg> [title]" "Show macOS notification"
    echo ""
}

show_scripts() {
    print_section "Dotfiles Scripts"
    print_cmd "bootstrap.sh" "Full machine setup"
    print_cmd "deploy.sh" "Deploy/update stow packages"
    print_cmd "sync-apps.sh" "Sync Brewfile with installed apps"
    print_cmd "stow-add.sh" "Interactive stow file addition"
    print_cmd "auto-adopt.sh" "Auto-adopt daemon script"
    print_cmd "macos-defaults.sh" "Apply macOS preferences"
    echo ""
}

show_all() {
    print_header "ROGUE - Dotfiles Quick Reference"

    echo -e "  ${DIM}Your dotfiles provide these commands and shortcuts.${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}rogue <category>${NC} ${DIM}for specific sections.${NC}"
    echo ""

    show_dotfiles
    show_navigation
    show_git
    show_python
    show_network
    show_system
    show_productivity
    show_scripts

    echo -e "  ${DIM}${H_LINE}${H_LINE}${H_LINE}${NC}"
    echo -e "  ${DIM}Dotfiles: ~/Documents/paras/04-system/dotfiles${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}rogue --help${NC} ${DIM}for more options${NC}"
    echo ""
}

show_help() {
    echo "Usage: rogue [category]"
    echo ""
    echo "Categories:"
    echo "  dotfiles    Dotfiles management commands"
    echo "  nav         PARAS navigation shortcuts"
    echo "  git         Git shortcuts"
    echo "  python      Python virtual environment helpers"
    echo "  network     Network utilities"
    echo "  system      System utilities"
    echo "  prod        Productivity tools"
    echo "  scripts     Available dotfiles scripts"
    echo ""
    echo "Examples:"
    echo "  rogue           Show all commands"
    echo "  rogue git       Show git shortcuts only"
    echo "  rogue dotfiles  Show dotfiles management commands"
}

# Main
case "${1:-all}" in
    dotfiles|df)
        print_header "Dotfiles Management"
        show_dotfiles
        ;;
    nav|navigation|paras)
        print_header "PARAS Navigation"
        show_navigation
        ;;
    git|g)
        print_header "Git Shortcuts"
        show_git
        ;;
    python|py)
        print_header "Python"
        show_python
        ;;
    network|net)
        print_header "Network"
        show_network
        ;;
    system|sys)
        print_header "System Utilities"
        show_system
        ;;
    prod|productivity)
        print_header "Productivity"
        show_productivity
        ;;
    scripts|sc)
        print_header "Dotfiles Scripts"
        show_scripts
        ;;
    all)
        show_all
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        echo "Unknown category: $1"
        echo "Run 'rogue --help' for usage"
        exit 1
        ;;
esac
