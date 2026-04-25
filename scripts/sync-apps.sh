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
STATE_DIR="$HOME/.local/state/dotfiles"
SNAPSHOT_FILE="$STATE_DIR/installed-apps.snapshot"

################################################################################
# Helper Functions
################################################################################

save_snapshot() {
    mkdir -p "$STATE_DIR"
    ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | sort > "$SNAPSHOT_FILE"
}

get_recently_removed() {
    # Apps in the snapshot that are no longer installed
    if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        return
    fi
    local current
    current=$(ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | sort)
    comm -23 "$SNAPSHOT_FILE" <(echo "$current")
}

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

    # Fetch cask index in background
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spin_i=0
    local tmp_casks
    tmp_casks=$(mktemp)
    brew search --cask '' > "$tmp_casks" 2>/dev/null &
    local brew_pid=$!

    trap 'kill "$brew_pid" 2>/dev/null; rm -f "$tmp_casks"; printf "\r\033[K" >&2; return 1' INT

    while kill -0 "$brew_pid" 2>/dev/null; do
        local sc="${spin_chars:spin_i:1}"
        printf "\r  ${CYAN}%s${NC} ${DIM}Scanning %d apps...${NC}" "$sc" "$app_count" >&2
        spin_i=$(( (spin_i + 1) % ${#spin_chars} ))
        sleep 0.08
    done
    wait "$brew_pid" || true
    printf "\r\033[K" >&2

    local all_casks
    all_casks=$(cat "$tmp_casks")
    rm -f "$tmp_casks"
    trap - INT

    while IFS= read -r app; do
        cask_name=$(get_cask_name "$app")

        if is_in_brewfile "$cask_name"; then
            in_brewfile+=("$app")
        else
            not_in_brewfile+=("$app")

            # Check if available as cask
            if echo "$all_casks" | grep -qx "$cask_name"; then
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
        print_info "Run 'dotfiles remove-apps' to clean up, or 'brew bundle' to install them"
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

    # Save snapshot for remove-apps tracking
    save_snapshot
}

################################################################################
# Add Mode - Interactively add new apps
################################################################################

# Category definitions — labels map to Brewfile section markers
CATEGORIES=(
    "Browsers"
    "Development & IDEs"
    "AI Tools"
    "Communication"
    "Productivity & Organization"
    "Window Management & UI"
    "Utilities - System & Power"
    "Utilities - Screenshots & Media"
    "Design & Creative"
    "Media - Video & Audio"
    "Reading & Reference"
    "Security & Privacy"
    "File Management"
    "Gaming"
)

# Auto-detect category based on cask name and brew info
guess_category() {
    local cask="$1"
    local desc
    desc=$(brew info --cask "$cask" 2>/dev/null | head -2 | tail -1 | tr '[:upper:]' '[:lower:]')

    case "$cask" in
        *browser*|firefox*|chrome*|arc|zen|brave*)    echo "Browsers"; return ;;
        *studio*|*code*|*ide*|cursor|ghostty|iterm*|codex|opencode) echo "Development & IDEs"; return ;;
        chatgpt*|claude*|ollama*|lm-studio*|*-ai*)    echo "AI Tools"; return ;;
        discord*|slack*|signal*|whatsapp*|telegram*|zoom*) echo "Communication"; return ;;
        *vpn*|mullvad*|proton*|wireshark*|burp*|cloudflare*) echo "Security & Privacy"; return ;;
        figma*|sketch*|canva*|gimp*|rive*|affinity*)  echo "Design & Creative"; return ;;
        spotify*|vlc*|iina*|audacity*|capcut*|jellyfin*) echo "Media - Video & Audio"; return ;;
        anki*|calibre*)                                echo "Reading & Reference"; return ;;
        steam*)                                        echo "Gaming"; return ;;
    esac

    # Fall back to brew description keywords
    case "$desc" in
        *browser*)    echo "Browsers" ;;
        *develop*|*ide*|*editor*|*terminal*|*debug*) echo "Development & IDEs" ;;
        *ai*|*language*model*|*llm*|*machine*learning*) echo "AI Tools" ;;
        *messag*|*chat*|*communicat*|*video*call*) echo "Communication" ;;
        *security*|*vpn*|*firewall*|*encrypt*) echo "Security & Privacy" ;;
        *design*|*creative*|*photo*edit*|*illustrat*) echo "Design & Creative" ;;
        *video*|*audio*|*media*|*music*|*stream*) echo "Media - Video & Audio" ;;
        *screenshot*|*screen*capture*|*ocr*) echo "Utilities - Screenshots & Media" ;;
        *window*|*menu*bar*|*dock*|*gesture*) echo "Window Management & UI" ;;
        *produc*|*note*|*calendar*|*organiz*|*task*) echo "Productivity & Organization" ;;
        *utilit*|*tool*|*monitor*|*battery*|*display*) echo "Utilities - System & Power" ;;
        *)            echo "Utilities - System & Power" ;;
    esac
}

# Find the line number of a Brewfile section header
find_section_line() {
    local section="$1"
    local line_num
    line_num=$(grep -n "^# $section" "$BREWFILE" 2>/dev/null | tail -1 | cut -d: -f1)
    echo "${line_num:-0}"
}

# Insert a cask line into the correct Brewfile section
insert_into_brewfile() {
    local cask="$1"
    local app="$2"
    local category="$3"

    local section_line
    section_line=$(find_section_line "$category")

    if [ "$section_line" -eq 0 ]; then
        # Section not found — append before Fonts section or at end
        local fonts_line
        fonts_line=$(grep -n "^# Fonts" "$BREWFILE" 2>/dev/null | head -1 | cut -d: -f1)
        if [ -n "$fonts_line" ] && [ "$fonts_line" -gt 0 ]; then
            # Insert new section before Fonts
            sed -i '' "${fonts_line}i\\
\\
# ${category}\\
cask \"${cask}\"  # ${app}
" "$BREWFILE"
        else
            # Append to end
            printf '\n# %s\ncask "%s"  # %s\n' "$category" "$cask" "$app" >> "$BREWFILE"
        fi
    else
        # Find the last cask line in this section (before next section or blank line gap)
        local insert_after=$section_line
        local total_lines
        total_lines=$(wc -l < "$BREWFILE" | tr -d ' ')

        for (( i = section_line + 1; i <= total_lines; i++ )); do
            local line
            line=$(sed -n "${i}p" "$BREWFILE")
            if [[ "$line" == cask\ * ]]; then
                insert_after=$i
            elif [[ "$line" == "# "* ]] && [[ "$line" != "#"*"$category"* ]]; then
                break
            fi
        done

        sed -i '' "${insert_after}a\\
cask \"${cask}\"  # ${app}
" "$BREWFILE"
    fi
}

# Arrow-key menu selector
# Usage: select_from_menu "result_var" "preselect_value" "${ARRAY[@]}"
select_from_menu() {
    local result_var="$1"
    local preselect="$2"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local selected=0
    local cancelled=false

    # Find preselected index
    for i in "${!options[@]}"; do
        [[ "${options[$i]}" == "$preselect" ]] && selected=$i
    done

    # Hide cursor
    tput civis 2>/dev/null

    # Draw initial list
    echo -e "      ${DIM}↑↓ navigate · enter confirm · q cancel${NC}"
    local i
    for i in "${!options[@]}"; do
        if [ "$i" -eq "$selected" ]; then
            echo -e "      ${CYAN}▸ ${options[$i]}${NC}"
        else
            echo -e "      ${DIM}  ${options[$i]}${NC}"
        fi
    done

    # Read keys and redraw
    while true; do
        local key
        read -rsn1 key < /dev/tty

        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 key < /dev/tty
            case "$key" in
                '[A') [ "$selected" -gt 0 ] && (( selected-- )) ;;
                '[B') [ "$selected" -lt $((count - 1)) ] && (( selected++ )) ;;
            esac
        elif [[ "$key" == "" ]]; then
            break
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            cancelled=true
            break
        fi

        # Move cursor up and redraw
        tput cuu "$count" 2>/dev/null
        for i in "${!options[@]}"; do
            tput el 2>/dev/null
            if [ "$i" -eq "$selected" ]; then
                echo -e "      ${CYAN}▸ ${options[$i]}${NC}"
            else
                echo -e "      ${DIM}  ${options[$i]}${NC}"
            fi
        done
    done

    tput cnorm 2>/dev/null

    if $cancelled; then
        printf -v "$result_var" ""
    else
        printf -v "$result_var" "%s" "${options[$selected]}"
    fi
}

add_apps() {
    print_header "Add Apps to Brewfile"

    # Get apps not in brewfile
    INSTALLED_APPS=$(ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | grep -v "^Safari$\|^Utilities$\|^Developer$\|^TestFlight$")

    available_to_add=()
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spin_i=0

    # Fetch cask index in background
    local tmp_casks
    tmp_casks=$(mktemp)
    brew search --cask '' > "$tmp_casks" 2>/dev/null &
    local brew_pid=$!

    trap 'kill "$brew_pid" 2>/dev/null; rm -f "$tmp_casks"; printf "\r\033[K" >&2; tput cnorm 2>/dev/null; return 1' INT

    # Spin while waiting for brew index
    while kill -0 "$brew_pid" 2>/dev/null; do
        local sc="${spin_chars:spin_i:1}"
        printf "\r  ${CYAN}%s${NC} ${DIM}Fetching Homebrew cask index...${NC}" "$sc" >&2
        spin_i=$(( (spin_i + 1) % ${#spin_chars} ))
        sleep 0.08
    done
    wait "$brew_pid" || true

    # Fast in-memory scan against cached index
    local all_casks
    all_casks=$(cat "$tmp_casks")
    rm -f "$tmp_casks"

    local app_total
    app_total=$(echo "$INSTALLED_APPS" | wc -l | tr -d ' ')
    local scanned=0

    while IFS= read -r app; do
        (( ++scanned ))
        printf "\r  ${CYAN}✓${NC} ${DIM}Checking %d/%d apps...${NC}" "$scanned" "$app_total" >&2
        cask_name=$(get_cask_name "$app")
        if ! is_in_brewfile "$cask_name" && echo "$all_casks" | grep -qx "$cask_name"; then
            available_to_add+=("$cask_name|$app")
        fi
    done <<< "$INSTALLED_APPS"

    printf "\r\033[K" >&2
    trap - INT

    if [ ${#available_to_add[@]} -eq 0 ]; then
        print_success "All installed apps are already in Brewfile"
        return
    fi

    local added=0
    local skipped=0
    local total=${#available_to_add[@]}
    local current=0

    echo -e "  ${GREEN}✓${NC} Found ${BOLD}${total}${NC} app(s) to review"
    echo ""

    for entry in "${available_to_add[@]}"; do
        cask="${entry%%|*}"
        app="${entry##*|}"
        (( ++current ))

        # Auto-detect category
        local suggested
        suggested=$(guess_category "$cask")

        echo -e "  ${GREEN}+${NC} ${BOLD}${app}${NC} ${DIM}→ ${suggested}${NC} ${DIM}(${current}/${total})${NC}"
        echo -ne "    [${BOLD}Y${NC}]es  [${BOLD}n${NC}]o  [${BOLD}c${NC}]hange  [${BOLD}i${NC}]nfo  [${BOLD}q${NC}]uit: "
        read -n 1 -r REPLY < /dev/tty
        echo ""

        case $REPLY in
            y|Y|"")
                insert_into_brewfile "$cask" "$app" "$suggested"
                echo -e "    ${GREEN}✓${NC} Added to ${suggested}"
                (( ++added ))
                ;;
            c|C)
                echo ""
                local chosen
                select_from_menu chosen "$suggested" "${CATEGORIES[@]}"
                if [[ -n "$chosen" ]]; then
                    insert_into_brewfile "$cask" "$app" "$chosen"
                    echo -e "    ${GREEN}✓${NC} Added to ${chosen}"
                    (( ++added ))
                else
                    echo -e "    ${DIM}Cancelled — skipped${NC}"
                    (( ++skipped ))
                fi
                ;;
            i|I)
                brew info --cask "$cask" 2>/dev/null | head -5 | sed 's/^/    /'
                echo -ne "    ${DIM}Add? [Y/n]:${NC} "
                read -n 1 -r REPLY2 < /dev/tty
                echo ""
                if [[ "$REPLY2" =~ ^[Nn]$ ]]; then
                    (( ++skipped ))
                else
                    insert_into_brewfile "$cask" "$app" "$suggested"
                    echo -e "    ${GREEN}✓${NC} Added to ${suggested}"
                    (( ++added ))
                fi
                ;;
            q|Q)
                break
                ;;
            *)
                (( ++skipped ))
                ;;
        esac
        echo ""
    done

    echo ""
    if [ $added -gt 0 ]; then
        print_success "Added $added app(s) to Brewfile"
        print_info "Run 'dotfiles review' to commit"
    else
        print_info "No apps added"
    fi
}

################################################################################
# Remove Mode - Interactively remove stale Brewfile entries
################################################################################

remove_apps() {
    local show_all=false
    [[ "${1:-}" == "--all" ]] && show_all=true

    print_header "Clean Up Brewfile"

    INSTALLED_APPS=$(ls -1 /Applications/ | grep ".app$" | sed 's/.app$//' | grep -v "^Safari$\|^Utilities$\|^Developer$\|^TestFlight$")
    brewfile_casks=$(grep "^cask " "$BREWFILE" | sed 's/cask "\([^"]*\)".*/\1/')

    # Determine which apps were recently removed (if snapshot exists)
    local recently_removed=""
    local has_snapshot=false
    if ! $show_all && [[ -f "$SNAPSHOT_FILE" ]]; then
        has_snapshot=true
        recently_removed=$(get_recently_removed)
    fi

    # Fetch cask index to check validity
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spin_i=0
    local tmp_casks
    tmp_casks=$(mktemp)
    brew search --cask '' > "$tmp_casks" 2>/dev/null &
    local brew_pid=$!

    trap 'kill "$brew_pid" 2>/dev/null; rm -f "$tmp_casks"; printf "\r\033[K" >&2; return 1' INT

    while kill -0 "$brew_pid" 2>/dev/null; do
        local sc="${spin_chars:spin_i:1}"
        printf "\r  ${CYAN}%s${NC} ${DIM}Checking Brewfile entries...${NC}" "$sc" >&2
        spin_i=$(( (spin_i + 1) % ${#spin_chars} ))
        sleep 0.08
    done
    wait "$brew_pid" || true
    printf "\r\033[K" >&2

    local all_casks
    all_casks=$(cat "$tmp_casks")
    rm -f "$tmp_casks"
    trap - INT

    # Categorise not-installed Brewfile entries
    local not_installed_invalid=()
    local recently_removed_casks=()
    local not_installed_known=()

    while IFS= read -r cask; do
        app_name=$(echo "$cask" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' | sed 's/ //g')
        if ! echo "$INSTALLED_APPS" | grep -qi "^$app_name$"; then
            if ! echo "$all_casks" | grep -qx "$cask"; then
                # Not even a valid cask anymore — always show
                not_installed_invalid+=("$cask")
            elif $show_all || ! $has_snapshot; then
                # --all mode or no snapshot — show everything
                not_installed_known+=("$cask")
            elif echo "$recently_removed" | grep -qi "$app_name"; then
                # Was installed last time, now gone — recently uninstalled
                recently_removed_casks+=("$cask")
            fi
            # Otherwise: not installed but was already missing last time — skip
        fi
    done <<< "$brewfile_casks"

    local total=$(( ${#not_installed_invalid[@]} + ${#recently_removed_casks[@]} + ${#not_installed_known[@]} ))

    if [ "$total" -eq 0 ]; then
        if $show_all || ! $has_snapshot; then
            print_success "Brewfile is clean — nothing to review"
        else
            print_success "No recently removed apps to clean up"
            print_info "Run 'dotfiles remove-apps --all' to review all not-installed entries"
        fi
        save_snapshot
        return
    fi

    local removed=0
    local current=0

    # Invalid casks first — genuinely stale
    if [ ${#not_installed_invalid[@]} -gt 0 ]; then
        print_section "Invalid casks"
        echo -e "  ${DIM}No longer available in Homebrew — safe to remove${NC}"
        echo ""

        for cask in "${not_installed_invalid[@]}"; do
            (( ++current ))
            echo -e "  ${RED}✗${NC} ${BOLD}${cask}${NC} ${DIM}(${current}/${total})${NC}"
            echo -ne "    [${BOLD}Y${NC}]es remove  [${BOLD}n${NC}]o keep  [${BOLD}q${NC}]uit: "
            read -n 1 -r REPLY < /dev/tty
            echo ""

            case $REPLY in
                y|Y|"")
                    sed -i '' "/^cask \"${cask}\"/d" "$BREWFILE"
                    echo -e "    ${GREEN}✓${NC} Removed"
                    (( ++removed ))
                    ;;
                q|Q)
                    echo ""
                    if [ $removed -gt 0 ]; then
                        print_success "Removed $removed entry/entries from Brewfile"
                        print_info "Run 'dotfiles review' to commit"
                    fi
                    save_snapshot
                    return
                    ;;
                *)
                    echo -e "    ${DIM}Kept${NC}"
                    ;;
            esac
            echo ""
        done
    fi

    # Recently removed apps — the main actionable section
    if [ ${#recently_removed_casks[@]} -gt 0 ]; then
        print_section "Recently uninstalled"
        echo -e "  ${DIM}These apps were removed since your last audit${NC}"
        echo ""

        for cask in "${recently_removed_casks[@]}"; do
            (( ++current ))
            echo -e "  ${YELLOW}?${NC} ${BOLD}${cask}${NC} ${DIM}(${current}/${total})${NC}"
            echo -ne "    [${BOLD}K${NC}]eep  [${BOLD}r${NC}]emove  [${BOLD}q${NC}]uit: "
            read -n 1 -r REPLY < /dev/tty
            echo ""

            case $REPLY in
                r|R)
                    sed -i '' "/^cask \"${cask}\"/d" "$BREWFILE"
                    echo -e "    ${GREEN}✓${NC} Removed"
                    (( ++removed ))
                    ;;
                q|Q)
                    break
                    ;;
                *)
                    echo -e "    ${DIM}Kept${NC}"
                    ;;
            esac
            echo ""
        done
    fi

    # All not-installed valid casks (--all mode or first run)
    if [ ${#not_installed_known[@]} -gt 0 ]; then
        print_section "In Brewfile but not installed"
        echo -e "  ${DIM}Will be installed on a new machine — remove any you no longer want${NC}"
        echo ""

        for cask in "${not_installed_known[@]}"; do
            (( ++current ))
            echo -e "  ${YELLOW}?${NC} ${BOLD}${cask}${NC} ${DIM}(${current}/${total})${NC}"
            echo -ne "    [${BOLD}K${NC}]eep  [${BOLD}r${NC}]emove  [${BOLD}q${NC}]uit: "
            read -n 1 -r REPLY < /dev/tty
            echo ""

            case $REPLY in
                r|R)
                    sed -i '' "/^cask \"${cask}\"/d" "$BREWFILE"
                    echo -e "    ${GREEN}✓${NC} Removed"
                    (( ++removed ))
                    ;;
                q|Q)
                    break
                    ;;
                *)
                    echo -e "    ${DIM}Kept${NC}"
                    ;;
            esac
            echo ""
        done
    fi

    echo ""
    if [ $removed -gt 0 ]; then
        print_success "Removed $removed entry/entries from Brewfile"
        print_info "Run 'dotfiles review' to commit"
    else
        print_info "No entries removed"
    fi

    save_snapshot
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
    --remove)
        shift
        remove_apps "$@"
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
