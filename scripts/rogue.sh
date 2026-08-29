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
    echo ""
    echo -e "  ${DIM}Day-to-day${NC}"
    print_cmd "dotfiles review" "Review, adopt new configs, commit, and push"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Run when the terminal nudges you about new configs"
    print_cmd "dotfiles st" "Show sync status (uncommitted, unpushed, behind)"
    print_cmd "dotfiles push" "Push commits to origin"
    print_cmd "dotfiles packages" "List stow packages and deployment status"
    print_cmd "dotfiles add <file>" "Add file to stow management"
    print_cmd "dotfiles update" "Pull latest and re-stow"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Run after git pull to re-stow updated configs"
    echo ""
    echo -e "  ${DIM}Config detection${NC}"
    print_cmd "dotfiles scan" "Scan for new configs now (read-only)"
    print_cmd "dotfiles status" "Last scan time and pending candidates"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Scans also run daily in the background; adoption only via review"
    echo ""
    echo -e "  ${DIM}Brewfile sync${NC}"
    print_cmd "dotfiles audit" "Compare installed apps vs Brewfile"
    print_cmd "dotfiles add-apps" "Interactively add installed apps to Brewfile"
    print_cmd "dotfiles remove-apps" "Remove stale entries from Brewfile"
    print_cmd "dotfiles sync" "Full sync: audit, add, commit"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Run after installing or removing apps via brew"
    echo ""
    echo -e "  ${DIM}Setup (rarely used)${NC}"
    print_cmd "dotfiles commit <msg>" "Manual commit (prefer review)"
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

show_paras_ref() {
    print_section "PARAS Quick Reference"
    echo -e "  ${DIM}What goes where — decision guide${NC}"
    echo ""
    printf "    ${GREEN}%-20s${NC} %s\n" "00-projects/" "Active work with a goal + deadline"
    echo -e "    ${DIM}                     → Has a clear finish line${NC}"
    echo -e "    ${DIM}                     → Needs multiple sessions${NC}"
    echo -e "    ${DIM}                     → Archive when done or stale >3mo${NC}"
    echo -e "    ${DIM}                     Review: weekly${NC}"
    echo ""
    printf "    ${GREEN}%-20s${NC} %s\n" "01-areas/" "Ongoing responsibilities, no end date"
    echo -e "    ${DIM}                     → Standards to maintain (health, finances, career)${NC}"
    echo -e "    ${DIM}                     → Part of your life roles${NC}"
    echo -e "    ${DIM}                     → Never \"done\", only maintained${NC}"
    echo -e "    ${DIM}                     Review: monthly${NC}"
    echo ""
    printf "    ${GREEN}%-20s${NC} %s\n" "02-resources/" "Reference material, not actionable now"
    echo -e "    ${DIM}                     → Interesting info for future use${NC}"
    echo -e "    ${DIM}                     → Not tied to a project or area${NC}"
    echo -e "    ${DIM}                     → Organised by topic${NC}"
    echo -e "    ${DIM}                     Review: quarterly${NC}"
    echo ""
    printf "    ${GREEN}%-20s${NC} %s\n" "03-archive/" "Inactive items from any category"
    echo -e "    ${DIM}                     → Completed or abandoned projects${NC}"
    echo -e "    ${DIM}                     → Areas/resources no longer relevant${NC}"
    echo -e "    ${DIM}                     → Named: original-name-YYYYMMDD${NC}"
    echo -e "    ${DIM}                     Review: annually${NC}"
    echo ""
    printf "    ${GREEN}%-20s${NC} %s\n" "04-system/" "System config and dotfiles"
    echo -e "    ${DIM}                     → Dotfiles, scripts, bootstrap${NC}"
    echo -e "    ${DIM}                     → Not user content${NC}"
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
    echo -e "  ${DIM}Run from: ~/Documents/paras/04-system/dotfiles/scripts/${NC}"
    echo ""
    print_cmd "deploy.sh" "Deploy/update stow packages"
    print_cmd "bootstrap.sh" "Full machine setup"
    print_cmd "sync-apps.sh" "Sync Brewfile with installed apps"
    print_cmd "stow-add.sh" "Interactive stow file addition"
    print_cmd "macos-defaults.sh" "Apply macOS preferences"
    echo ""
}

show_skills() {
    print_section "AI Skills"
    echo ""
    print_cmd "skills" "Status across all three channels"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Read-only — what you have and what has drifted"
    print_cmd "skills list" "Full registry with versions and targets"
    print_cmd "skills sync" "Distribute ~/.skills to Claude Code and Cursor"
    print_cmd "skills new <name>" "Scaffold a new skill"
    print_cmd "skills import" "Adopt unmanaged skills out of tool dirs"
    echo ""
    echo -e "  ${DIM}Channels: yours (~/.skills), vendored upstream, Claude plugins.${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}skills help${NC} ${DIM}for the full surface.${NC}"
    echo ""
}

show_ssh() {
    print_section "SSH Keys"
    print_cmd "ssh-create <name>" "Create and register a new SSH key"
    print_cmd "ssh-list" "List managed keys with host mappings"
    print_cmd "dotfiles ssh-create" "Same, via dotfiles command"
    print_cmd "dotfiles ssh-list" "Same, via dotfiles command"
    echo ""
}

show_transfer() {
    print_section "File Transfer (arc-reactor)"
    echo ""
    echo -e "  ${DIM}Transfer${NC}"
    print_cmd "arc push <file> [dest]" "Upload to server (shortcut, fuzzy, or path)"
    print_cmd "arc pull [source] [local]" "Download from server"
    echo ""
    echo -e "  ${DIM}Browse${NC}"
    print_cmd "arc ls [path]" "Browse server filesystem interactively"
    print_cmd "arc df" "Server disk usage"
    echo ""
    echo -e "  ${DIM}Shortcuts: movies, tv, herald, configs, home${NC}"
    echo -e "  ${DIM}Omit path to browse with fzf. Use fragments for fuzzy match.${NC}"
    echo ""
}

show_media() {
    print_section "Media"
    echo ""
    print_cmd "yt-transcript <url>" "Fetch a YouTube video's transcript as text"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Reads YouTube's own captions - no download, about a second"
    echo ""
    echo -e "  ${DIM}Options${NC}"
    print_cmd "-c, --copy" "Copy the transcript to the clipboard"
    print_cmd "-t, --timestamps" "One line per cue, prefixed [m:ss]"
    print_cmd "-j, --json" "Metadata and cue timings as JSON"
    print_cmd "-o, --out FILE" "Write to a file instead of stdout"
    print_cmd "--langs" "List the caption languages a video has"
    echo ""
    echo -e "  ${DIM}Prefers human-written captions, falls back to auto-generated.${NC}"
    echo -e "  ${DIM}No captions at all? Fall back to${NC} ${GREEN}whisper${NC} ${DIM}on the audio.${NC}"
    echo ""
}

show_all() {
    print_header "ROGUE - Dotfiles Quick Reference"

    echo -e "  ${DIM}Your dotfiles provide these commands and shortcuts.${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}rogue <category>${NC} ${DIM}for specific sections.${NC}"
    echo ""

    show_git
    show_skills
    show_ssh
    show_transfer
    show_media
    show_network
    show_system
    show_dotfiles
    show_navigation
    show_python
    show_productivity

    echo -e "  ${DIM}${H_LINE}${H_LINE}${H_LINE}${NC}"
    echo -e "  ${DIM}Dotfiles: ~/Documents/paras/04-system/dotfiles${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}rogue --help${NC} ${DIM}for more options${NC}"
    echo ""
}

show_help() {
    echo "Usage: rogue [category]"
    echo ""
    echo "Categories:"
    echo "  git         Git shortcuts"
    echo "  skills      AI skill management"
    echo "  ssh         SSH key management"
    echo "  transfer    File transfer (arc-reactor)"
    echo "  media       YouTube transcripts and media tools"
    echo "  network     Network utilities"
    echo "  system      System utilities"
    echo "  dotfiles    Dotfiles management commands"
    echo "  nav         PARAS navigation shortcuts"
    echo "  paras       PARAS methodology reference (what goes where)"
    echo "  python      Python virtual environment helpers"
    echo "  prod        Productivity tools"
    echo "  scripts     Dotfiles scripts (not shell commands)"
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
    nav|navigation)
        print_header "PARAS Navigation"
        show_navigation
        ;;
    paras|paras-ref|para|ref)
        print_header "PARAS Quick Reference"
        show_paras_ref
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
    ssh)
        print_header "SSH Keys"
        show_ssh
        ;;
    transfer|arc|tr)
        print_header "File Transfer"
        show_transfer
        ;;
    skills|sk)
        print_header "AI Skills"
        show_skills
        ;;
    media|yt)
        print_header "Media"
        show_media
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
