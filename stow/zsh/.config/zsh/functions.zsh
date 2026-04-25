# ============================================================================
# ZSH Functions - Helpful shell functions
# ============================================================================

# PARAS Navigation Functions
# ============================================================================

# Quick navigate to PARAS directories
p() {
    cd "$PROJECTS_DIR/$1" || return
}

a() {
    cd "$AREAS_DIR/$1" || return
}

r() {
    cd "$RESOURCES_DIR/$1" || return
}

ar() {
    cd "$ARCHIVE_DIR/$1" || return
}

s() {
    cd "$SYSTEM_DIR/$1" || return
}

# List PARAS directories
paras-list() {
    echo "Projects:"
    ls -1 "$PROJECTS_DIR"
    echo "\nAreas:"
    ls -1 "$AREAS_DIR"
    echo "\nResources:"
    ls -1 "$RESOURCES_DIR"
    echo "\nArchive:"
    ls -1 "$ARCHIVE_DIR"
}

# Archive a project
paras-archive() {
    if [ -z "$1" ]; then
        echo "Usage: paras-archive <project-name>"
        return 1
    fi

    local project_path="$PROJECTS_DIR/$1"
    local archive_path="$ARCHIVE_DIR/$1-$(date +%Y%m%d)"

    if [ ! -d "$project_path" ]; then
        echo "Project '$1' not found in $PROJECTS_DIR"
        return 1
    fi

    echo "Archiving $project_path to $archive_path"
    mv "$project_path" "$archive_path"
    echo "Project archived successfully!"
}

# Development Functions
# ============================================================================

# Create and navigate to a new directory
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# Extract any archive
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar x "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *)           echo "Error: '$1' cannot be extracted via extract()" ;;
    esac
}

# Git Functions
# ============================================================================

# Quick git commit with message
gcm() {
    git commit -m "$*"
}

# Git add all and commit
gac() {
    git add . && git commit -m "$*"
}

# Git add all, commit, and push
gacp() {
    git add . && git commit -m "$*" && git push
}

# Git status with short format
gst() {
    git status -sb
}

# Create a new git branch and check it out
gnb() {
    if [ -z "$1" ]; then
        echo "Usage: gnb <branch-name>"
        return 1
    fi
    git checkout -b "$1"
}

# Delete local and remote branch
gdb() {
    if [ -z "$1" ]; then
        echo "Usage: gdb <branch-name>"
        return 1
    fi
    git branch -d "$1"
    git push origin --delete "$1"
}

# Show git log in a pretty format
glog() {
    git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
}

# Python Functions
# ============================================================================

# Create and activate Python virtual environment
venv-create() {
    python3 -m venv venv
    source venv/bin/activate
}

# Activate virtual environment
venv-activate() {
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    elif [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        echo "No virtual environment found in current directory"
        return 1
    fi
}

# Deactivate virtual environment
venv-deactivate() {
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate
    else
        echo "No active virtual environment"
    fi
}

# Install requirements and freeze
pip-save() {
    pip install "$@" && pip freeze > requirements.txt
}

# Network Functions
# ============================================================================

# Get external IP address
myip() {
    local v4 v6
    v4=$(curl -4 -s --max-time 3 https://ifconfig.me 2>/dev/null)
    v6=$(curl -6 -s --max-time 3 https://ifconfig.me 2>/dev/null)
    [ -n "$v4" ] && echo "IPv4: $v4"
    [ -n "$v6" ] && echo "IPv6: $v6"
}

# Get local IP address
localip() {
    ipconfig getifaddr en0 || ipconfig getifaddr en1
}

# Port scanning
port() {
    if [ -z "$1" ]; then
        echo "Usage: port <port-number>"
        return 1
    fi
    lsof -i :"$1"
}

# Kill process on port
killport() {
    if [ -z "$1" ]; then
        echo "Usage: killport <port-number>"
        return 1
    fi
    local pids
    pids=$(lsof -ti :"$1" 2>/dev/null)
    if [[ -z "$pids" ]]; then
        echo "No process found on port $1"
        return 1
    fi
    echo "$pids" | xargs kill -9
    echo "Killed process(es) on port $1"
}

# System Functions
# ============================================================================

# Show disk usage of current directory
duf() {
    du -sh * | sort -hr
}

# Find large files
findlarge() {
    local size="${1:-100M}"
    find . -type f -size "+$size" -exec ls -lh {} \; | awk '{ print $9 ": " $5 }'
}

# Clean up system safely
# Usage: cleanup [--dry-run] [--all] [--force]
#   --dry-run  Show what would be deleted without deleting
#   --all      Include aggressive cleanup (Docker images, all caches)
#   --force    Skip confirmation prompts
cleanup() {
    local dry_run=false
    local aggressive=false
    local force=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=true ;;
            --all) aggressive=true ;;
            --force) force=true ;;
            --help|-h)
                echo "Usage: cleanup [--dry-run] [--all] [--force]"
                echo "  --dry-run  Show what would be deleted without deleting"
                echo "  --all      Include aggressive cleanup (all Docker images, all caches)"
                echo "  --force    Skip confirmation prompts"
                return 0
                ;;
            *)
                echo "Unknown option: $arg"
                echo "Run 'cleanup --help' for usage"
                return 1
                ;;
        esac
    done

    local BOLD='\033[1m' DIM='\033[2m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'

    if $dry_run; then
        echo -e "${YELLOW}⚠${NC} Dry run — no files will be deleted"
        echo ""
    fi

    # Homebrew cleanup (always safe)
    if command -v brew >/dev/null; then
        echo -e "${BOLD}Homebrew${NC} cleanup..."
        if $dry_run; then
            brew cleanup --dry-run 2>/dev/null | head -20
            echo "  (showing first 20 items)"
        else
            brew cleanup
            brew autoremove
        fi
        echo ""
    fi

    # Python cache - only in current directory, with safety checks
    local cwd="$PWD"
    local dangerous_paths=("$HOME" "/" "/Users" "/System" "/Library" "/Applications" "/var" "/etc" "/usr" "/bin" "/sbin" "/tmp")

    local is_dangerous=false
    for dangerous in "${dangerous_paths[@]}"; do
        if [[ "$cwd" == "$dangerous" ]]; then
            is_dangerous=true
            break
        fi
    done

    if $is_dangerous; then
        echo -e "${YELLOW}⚠${NC} Skipping Python cache cleanup (system directory: $cwd)"
        echo -e "  ${DIM}Run from a project directory to clean Python caches${NC}"
    else
        # Check if this looks like a Python project
        if [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -d "venv" ]] || [[ -d ".venv" ]]; then
            echo -e "${BOLD}Python${NC} cache cleanup (current directory)..."
            local pycache_count=$(find . -maxdepth 5 -type d -name "__pycache__" 2>/dev/null | wc -l | tr -d ' ')
            local pyc_count=$(find . -maxdepth 5 -type f -name "*.pyc" 2>/dev/null | wc -l | tr -d ' ')

            if [[ "$pycache_count" -gt 0 ]] || [[ "$pyc_count" -gt 0 ]]; then
                echo "   Found: $pycache_count __pycache__ dirs, $pyc_count .pyc files"
                if $dry_run; then
                    find . -maxdepth 5 -type d -name "__pycache__" 2>/dev/null | head -10
                    [[ "$pycache_count" -gt 10 ]] && echo "   ... and $((pycache_count - 10)) more"
                else
                    find . -maxdepth 5 -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
                    find . -maxdepth 5 -type f -name "*.pyc" -delete 2>/dev/null
                    echo "   ✓ Cleaned"
                fi
            else
                echo "   Nothing to clean"
            fi
        else
            echo -e "${DIM}Python — not a project directory, skipping${NC}"
        fi
    fi
    echo ""

    # macOS caches - only with --all flag due to side effects
    if $aggressive; then
        echo -e "${BOLD}macOS${NC} cache cleanup..."
        local cache_size=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1)
        echo "   Cache size: $cache_size"

        if $dry_run; then
            echo "   Would delete: ~/Library/Caches/*"
            ls ~/Library/Caches 2>/dev/null | head -10
            echo "   ..."
        else
            if $force; then
                rm -rf ~/Library/Caches/* 2>/dev/null
                echo "   ✓ Cleaned"
            else
                echo -n "   Delete all application caches? This may log you out of some apps. (y/N) "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    rm -rf ~/Library/Caches/* 2>/dev/null
                    echo "   ✓ Cleaned"
                else
                    echo "   Skipped"
                fi
            fi
        fi
        echo ""
    fi

    # Docker cleanup - conservative by default
    if command -v docker >/dev/null; then
        # Check if Docker daemon is running
        if docker info >/dev/null 2>&1; then
            echo -e "${BOLD}Docker${NC} cleanup..."

            if $aggressive; then
                # Aggressive: remove ALL unused images
                if $dry_run; then
                    echo "   Would remove all unused containers, networks, and images"
                    docker system df
                else
                    if $force; then
                        docker system prune -af
                        echo "   ✓ Cleaned (all unused images removed)"
                    else
                        echo -n "   Remove ALL unused images (not just dangling)? (y/N) "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            docker system prune -af
                            echo "   ✓ Cleaned"
                        else
                            # Fall back to conservative cleanup
                            docker system prune -f
                            echo "   ✓ Cleaned (dangling images only)"
                        fi
                    fi
                fi
            else
                # Conservative: only dangling images and stopped containers
                if $dry_run; then
                    echo "   Would remove stopped containers and dangling images"
                    docker system df
                else
                    docker system prune -f
                    echo "   ✓ Cleaned (dangling images only)"
                fi
            fi
        else
            echo -e "${DIM}Docker — daemon not running, skipping${NC}"
        fi
        echo ""
    fi

    if $dry_run; then
        echo -e "${DIM}Dry run complete — run without --dry-run to execute${NC}"
    else
        echo -e "${GREEN}✓${NC} Cleanup complete"
    fi
}

# File Operations
# ============================================================================

# Backup a file
backup() {
    if [ -z "$1" ]; then
        echo "Usage: backup <file>"
        return 1
    fi
    cp "$1" "$1.backup-$(date +%Y%m%d-%H%M%S)"
}

# Find and replace in files
findreplace() {
    if [ $# -ne 2 ]; then
        echo "Usage: findreplace <search> <replace>"
        return 1
    fi
    find . -type f -exec sed -i '' "s/$1/$2/g" {} +
}

# Productivity Functions
# ============================================================================

# Quick timer
timer() {
    local duration="${1:-5m}"
    echo "Timer set for $duration"
    sleep "$duration" && afplay /System/Library/Sounds/Glass.aiff
}

# Countdown
countdown() {
    local seconds="${1:-60}"
    local end=$((SECONDS + seconds))
    while [ $SECONDS -lt $end ]; do
        printf "\r%02d:%02d" $(((end-SECONDS)/60)) $(((end-SECONDS)%60))
        sleep 0.5
    done
    echo -e "\nTime's up!"
    afplay /System/Library/Sounds/Glass.aiff
}

# Show a notification (macOS)
notify() {
    if [ -z "$1" ]; then
        echo "Usage: notify <message> [title]"
        return 1
    fi
    local message="$1"
    local title="${2:-Notification}"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Dotfiles Functions
# ============================================================================

# Unified dotfiles command
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        # Auto-adopt commands
        status)
            "$SYSTEM_DIR/dotfiles/scripts/setup-auto-adopt.sh" status
            ;;
        log)
            local lines="${1:-20}"
            local log_file="$HOME/.local/state/dotfiles/auto-adopt.log"
            if [[ -f "$log_file" ]]; then
                tail -n "$lines" "$log_file"
            else
                echo "No log file yet. Run 'dotfiles run-now' to create one."
            fi
            ;;
        run-now)
            echo "Running auto-adopt manually..."
            "$SYSTEM_DIR/dotfiles/scripts/auto-adopt.sh"
            echo ""
            echo "Done. Check 'dotfiles log' for results."
            ;;
        dry-run)
            echo "Preview of what would be adopted:"
            "$SYSTEM_DIR/dotfiles/scripts/auto-adopt.sh" --dry-run
            ;;
        # Daemon management
        install)
            "$SYSTEM_DIR/dotfiles/scripts/setup-auto-adopt.sh" install
            ;;
        uninstall)
            "$SYSTEM_DIR/dotfiles/scripts/setup-auto-adopt.sh" uninstall
            ;;
        # Existing commands
        packages|pkg)
            dotfiles-packages "$@"
            ;;
        add)
            dotfiles-add "$@"
            ;;
        update)
            dotfiles-update "$@"
            ;;
        push)
            dotfiles-push "$@"
            ;;
        st)
            dotfiles-status "$@"
            ;;
        commit)
            dotfiles-commit "$@"
            ;;
        audit)
            dotfiles-audit "$@"
            ;;
        add-apps)
            dotfiles-add-apps "$@"
            ;;
        brew-update)
            dotfiles-brew-update "$@"
            ;;
        export)
            dotfiles-export "$@"
            ;;
        sync)
            dotfiles-sync "$@"
            ;;
        # SSH key management
        ssh-create)
            ssh-create "$@"
            ;;
        ssh-list)
            ssh-list "$@"
            ;;
        # Review and commit adopted configs
        review)
            dotfiles-review "$@"
            ;;
        # AI skills management
        skills-create)
            skills-create "$@"
            ;;
        skills-sync)
            skills-sync "$@"
            ;;
        help|--help|-h|*)
            rogue dotfiles
            ;;
    esac
}

# Add a new file to stow-managed dotfiles
dotfiles-add() {
    if [ -z "$1" ]; then
        echo "Usage: dotfiles-add <file-path> [package-name]"
        echo ""
        echo "Examples:"
        echo "  dotfiles-add ~/.claude/CLAUDE.md"
        echo "  dotfiles-add ~/.config/myapp/config.json myapp"
        echo "  dotfiles-add --create ~/.newrc"
        return 1
    fi

    "$SYSTEM_DIR/dotfiles/scripts/stow-add.sh" "$@"
}

# Review and commit pending dotfiles changes
dotfiles-review() {
    local dotfiles_dir="$SYSTEM_DIR/dotfiles"
    cd "$dotfiles_dir" || return

    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local CYAN='\033[0;36m'
    local BOLD='\033[1m'
    local DIM='\033[2m'
    local NC='\033[0m'

    # ── Collect changes by package ──────────────────────────
    local -A pkg_added=()      # pkg → list of added files
    local -A pkg_deleted=()    # pkg → list of deleted files
    local -A pkg_modified=()   # pkg → list of modified files
    local -a new_packages=()   # untracked stow packages
    local -a changed_packages=()  # all packages with changes
    local -a blocked_files=()  # dangerous files that block commit

    # New untracked packages
    local dir pkg
    while IFS= read -r line; do
        dir="${line#\?\? }"
        if [[ "$dir" == stow/*/ ]]; then
            pkg="${dir#stow/}"
            pkg="${pkg%/}"
            new_packages+=("$pkg")
        fi
    done < <(git status --porcelain 2>/dev/null | grep '^?? stow/')

    # Tracked file changes (modified, added, deleted)
    local st file
    while IFS= read -r line; do
        st="${line:0:2}"
        file="${line:3}"
        [[ "$file" != stow/* ]] && continue
        pkg="${file#stow/}"
        pkg="${pkg%%/*}"

        case "$st" in
            " M"|"M "|"MM") pkg_modified[$pkg]+="${file#stow/$pkg/}"$'\n' ;;
            " D"|"D ")       pkg_deleted[$pkg]+="${file#stow/$pkg/}"$'\n' ;;
            "A "|"AM")       pkg_added[$pkg]+="${file#stow/$pkg/}"$'\n' ;;
        esac
    done < <(git status --porcelain 2>/dev/null)

    # Build unique list of changed packages
    local k
    for k in ${(k)pkg_modified} ${(k)pkg_deleted} ${(k)pkg_added}; do
        if (( ! ${changed_packages[(Ie)$k]} )); then
            changed_packages+=("$k")
        fi
    done

    # Nothing pending?
    if [[ ${#new_packages[@]} -eq 0 && ${#changed_packages[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Nothing to review — dotfiles are clean"
        cd - > /dev/null || return
        return 0
    fi

    # ── Safety checks ───────────────────────────────────────

    # Check for private keys (files in ssh keys dir without .pub extension)
    local f
    for f in stow/ssh/.ssh/keys/*; do
        [[ ! -f "$f" ]] && continue
        [[ "$f" == *.pub ]] && continue
        blocked_files+=("$f")
    done

    # Check all changed/new files for private key content
    local check_file
    {
        for k in "${new_packages[@]}"; do
            find "stow/$k" -type f 2>/dev/null
        done
        for k in "${changed_packages[@]}"; do
            while IFS= read -r f; do
                [[ -n "$f" ]] && echo "stow/$k/$f"
            done <<< "${pkg_added[$k]}${pkg_modified[$k]}"
        done
    } | while read -r check_file; do
        [[ ! -f "$check_file" ]] && continue
        if grep -q '-----BEGIN.*PRIVATE KEY-----' "$check_file" 2>/dev/null; then
            blocked_files+=("$check_file")
        fi
    done

    if [[ ${#blocked_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}BLOCKED${NC} — dangerous files detected:"
        echo ""
        for f in "${blocked_files[@]}"; do
            echo -e "    ${RED}✗${NC} $f"
        done
        echo ""
        echo -e "  ${DIM}Remove these files before committing. Private keys belong in 1Password, not git.${NC}"
        echo ""
        cd - > /dev/null || return
        return 1
    fi

    # ── Generate commit messages per package ────────────────

    local -A pkg_messages=()
    local additions deletions diff_content parts_str
    local -a parts=()
    local commit_type added_keys deleted_keys key_names verb new_hosts removed_hosts
    local basename filepath changed_funcs new_plugin new_aliases
    local mod_count del_count add_count total_changes only_file
    local file_list fcount total new_ahead
    local -a pkg_files=()

    # Helper: describe change character based on diff stats
    # High add+delete = restructure, mostly adds = extend, mostly deletes = trim
    _describe_config_change() {
        local file="$1" add del
        add=$(git diff -- "$file" 2>/dev/null | grep -c '^+[^+]' || echo 0)
        del=$(git diff -- "$file" 2>/dev/null | grep -c '^-[^-]' || echo 0)
        if [[ $add -gt 10 && $del -gt 10 ]]; then
            echo "reorganise"
        elif [[ $add -gt $del && $del -gt 0 ]]; then
            echo "update"
        elif [[ $del -gt $add ]]; then
            echo "simplify"
        elif [[ $add -gt 0 ]]; then
            echo "extend"
        else
            echo "update"
        fi
    }

    for pkg in "${changed_packages[@]}"; do
        parts=()
        commit_type="chore"

        # ── SSH package ─────────────────────────────
        if [[ "$pkg" == "ssh" ]]; then
            # Key changes
            added_keys=0 deleted_keys=0 key_names=""
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                if [[ "$f" == .ssh/keys/*.pub ]]; then
                    (( added_keys++ ))
                    key_names+="${${f%.pub}##*/} "
                fi
            done <<< "${pkg_added[$pkg]}"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                [[ "$f" == .ssh/keys/*.pub ]] && (( deleted_keys++ ))
            done <<< "${pkg_deleted[$pkg]}"

            [[ $added_keys -gt 0 ]] && parts+=("add ${key_names% } key")
            if [[ $deleted_keys -gt 1 ]]; then
                parts+=("clean up $deleted_keys orphan keys")
            elif [[ $deleted_keys -eq 1 ]]; then
                parts+=("remove orphan key")
            fi

            # Config changes — diff-aware verb selection
            if [[ "${pkg_modified[$pkg]}" == *config* ]]; then
                verb=$(_describe_config_change "stow/ssh/.ssh/config")
                diff_content=$(git diff -- "stow/ssh/.ssh/config" 2>/dev/null)

                # Detect specific changes from diff content
                new_hosts=$(echo "$diff_content" | grep '^+Host ' | grep -v '^+++' | sed 's/^+Host //' | tr '\n' ', ' | sed 's/, $//')
                removed_hosts=$(echo "$diff_content" | grep '^-Host ' | grep -v '^---' | sed 's/^-Host //' | tr '\n' ', ' | sed 's/, $//')

                if [[ -n "$new_hosts" && -n "$removed_hosts" ]]; then
                    parts+=("${verb} config")
                elif [[ -n "$new_hosts" ]]; then
                    parts+=("add ${new_hosts} host")
                elif [[ -n "$removed_hosts" ]]; then
                    parts+=("remove ${removed_hosts} host")
                elif [[ "$verb" != "update" ]]; then
                    parts+=("${verb} config")
                else
                    # Check for specific option changes
                    if echo "$diff_content" | grep -q '+.*RequestTTY'; then
                        parts+=("suppress TTY for git hosts")
                    else
                        parts+=("update config")
                    fi
                fi
            fi
            commit_type="feat"

        # ── ZSH package ─────────────────────────────
        elif [[ "$pkg" == "zsh" ]]; then
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                basename="${f##*/}"
                filepath="stow/$pkg/$f"
                diff_content=$(git diff -- "$filepath" 2>/dev/null)

                case "$basename" in
                    functions.zsh)
                        # Try to detect what changed in functions
                        changed_funcs=$(echo "$diff_content" | grep -E '^[+-](function |[a-z_-]+\(\))' | grep -v '^[+-]{3}' | sed 's/^[+-]//' | sed 's/().*//' | sed 's/^function //' | sort -u | head -3 | tr '\n' ', ' | sed 's/, $//')
                        if [[ -n "$changed_funcs" ]]; then
                            # Determine if fix or update based on change ratio
                            verb=$(_describe_config_change "$filepath")
                            if [[ "$verb" == "update" ]]; then
                                parts+=("update ${changed_funcs}")
                            else
                                parts+=("${verb} ${changed_funcs}")
                            fi
                        else
                            parts+=("update shell functions")
                        fi
                        ;;
                    .zshrc)
                        # Detect what changed
                        if echo "$diff_content" | grep -q '^+source\|^+zinit\|^+plug'; then
                            new_plugin=$(echo "$diff_content" | grep '^+' | grep -oE '[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+' | head -1)
                            if [[ -n "$new_plugin" ]]; then
                                parts+=("add ${new_plugin} plugin")
                            else
                                parts+=("add new plugin")
                            fi
                        elif echo "$diff_content" | grep -q '^+export '; then
                            parts+=("update environment variables")
                        elif echo "$diff_content" | grep -q '^+alias '; then
                            parts+=("add aliases")
                        else
                            parts+=("update zshrc")
                        fi
                        ;;
                    aliases.zsh)
                        new_aliases=$(echo "$diff_content" | grep '^+alias ' | sed "s/^+alias //" | cut -d= -f1 | tr '\n' ', ' | sed 's/, $//')
                        if [[ -n "$new_aliases" ]]; then
                            parts+=("add ${new_aliases} aliases")
                        else
                            parts+=("update aliases")
                        fi
                        ;;
                    *)
                        parts+=("update ${basename%.zsh}")
                        ;;
                esac
            done <<< "${pkg_modified[$pkg]}"

        # ── Git package ─────────────────────────────
        elif [[ "$pkg" == "git" ]]; then
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                basename="${f##*/}"
                case "$basename" in
                    .gitconfig|config) parts+=("update git config") ;;
                    .gitignore|ignore) parts+=("update global gitignore") ;;
                    *)                 parts+=("update ${basename}") ;;
                esac
            done <<< "${pkg_modified[$pkg]}"

        # ── Generic package ─────────────────────────
        else
            mod_count=0 del_count=0 add_count=0
            while IFS= read -r f; do [[ -n "$f" ]] && (( mod_count++ )); done <<< "${pkg_modified[$pkg]}"
            while IFS= read -r f; do [[ -n "$f" ]] && (( del_count++ )); done <<< "${pkg_deleted[$pkg]}"
            while IFS= read -r f; do [[ -n "$f" ]] && (( add_count++ )); done <<< "${pkg_added[$pkg]}"

            total_changes=$(( mod_count + del_count + add_count ))

            if [[ $total_changes -eq 1 ]]; then
                only_file=$(echo "${pkg_modified[$pkg]}${pkg_added[$pkg]}${pkg_deleted[$pkg]}" | head -1)
                if [[ $del_count -eq 1 ]]; then
                    parts+=("remove ${only_file##*/}")
                elif [[ $add_count -eq 1 ]]; then
                    parts+=("add ${only_file##*/}")
                else
                    parts+=("update ${only_file##*/}")
                fi
            elif [[ $del_count -gt 0 && $mod_count -eq 0 && $add_count -eq 0 ]]; then
                parts+=("clean up $del_count files")
            elif [[ $add_count -gt 0 && $mod_count -eq 0 && $del_count -eq 0 ]]; then
                parts+=("add $add_count files")
            else
                parts+=("update $total_changes files")
            fi
        fi

        # Build the message
        if [[ ${#parts[@]} -gt 0 ]]; then
            parts_str="${(j:, :)parts}"
            pkg_messages[$pkg]="${commit_type}($pkg): $parts_str"
        else
            pkg_messages[$pkg]="chore($pkg): update config"
        fi
    done

    # Messages for new packages
    for pkg in "${new_packages[@]}"; do
        file_list=$(find "stow/$pkg" -type f 2>/dev/null | sed "s|stow/$pkg/||" | sort)
        fcount=$(echo "$file_list" | wc -l | tr -d ' ')
        if [[ $fcount -eq 1 ]]; then
            pkg_messages[$pkg]="chore(dotfiles): adopt ${pkg} config (${file_list})"
        else
            pkg_messages[$pkg]="chore(dotfiles): adopt ${pkg} config ($fcount files)"
        fi
    done

    unfunction _describe_config_change 2>/dev/null

    # ── Display ─────────────────────────────────────────────
    echo ""
    echo -e "  ${BOLD}Dotfiles Review${NC}"
    echo ""

    for pkg in "${changed_packages[@]}"; do
        echo -e "    ${YELLOW}~${NC}  ${pkg_messages[$pkg]}"
    done
    for pkg in "${new_packages[@]}"; do
        echo -e "    ${GREEN}+${NC}  ${pkg_messages[$pkg]}"
    done

    local total_commits=$(( ${#changed_packages[@]} + ${#new_packages[@]} ))
    echo ""

    # Check remote status
    local ahead
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    # ── Prompt ──────────────────────────────────────────────
    if [[ $total_commits -eq 1 ]]; then
        echo -ne "  Commit? ${DIM}[Y/n/d(iff)]${NC} "
    else
        echo -ne "  Commit ${total_commits} changes? ${DIM}[Y/n/d(iff)]${NC} "
    fi

    read -k 1 REPLY
    echo ""

    case $REPLY in
        [Yy]|$'\n')
            echo ""
            # Commit each package separately
            for pkg in "${changed_packages[@]}"; do
                # Stage files for this package
                while IFS= read -r f; do
                    [[ -n "$f" ]] && git add "stow/$pkg/$f"
                done <<< "${pkg_modified[$pkg]}${pkg_added[$pkg]}"
                while IFS= read -r f; do
                    [[ -n "$f" ]] && git rm --cached "stow/$pkg/$f" 2>/dev/null
                done <<< "${pkg_deleted[$pkg]}"
                git commit -m "${pkg_messages[$pkg]}" --quiet
                echo -e "    ${GREEN}✓${NC}  ${pkg_messages[$pkg]}"
            done
            for pkg in "${new_packages[@]}"; do
                git add "stow/$pkg"
                git commit -m "${pkg_messages[$pkg]}" --quiet
                echo -e "    ${GREEN}✓${NC}  ${pkg_messages[$pkg]}"
            done

            echo ""
            new_ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
            if [[ $new_ahead -gt 0 ]]; then
                echo -ne "  ${DIM}⇡ ${new_ahead} ahead of origin${NC} — push? ${DIM}[Y/n]${NC} "
                read -k 1 PUSH_REPLY
                echo ""
                case $PUSH_REPLY in
                    [Nn])
                        echo -e "  ${DIM}Skipped. Run 'dotfiles push' when ready.${NC}"
                        ;;
                    *)
                        echo ""
                        if git push --quiet; then
                            echo -e "  ${GREEN}✓${NC}  Pushed to origin"
                        else
                            echo -e "  ${RED}✗${NC}  Push failed"
                        fi
                        ;;
                esac
            fi
            ;;
        d)
            echo ""
            for pkg in "${new_packages[@]}"; do
                echo -e "  ${BOLD}── $pkg (new) ──${NC}"
                find "stow/$pkg" -type f 2>/dev/null | while read -r f; do
                    echo -e "  ${CYAN}${f}${NC}"
                    head -30 "$f"
                    total=$(wc -l < "$f" | tr -d ' ')
                    [[ "$total" -gt 30 ]] && echo -e "  ${DIM}... ($total lines total)${NC}"
                done
                echo ""
            done
            for pkg in "${changed_packages[@]}"; do
                echo -e "  ${BOLD}── $pkg ──${NC}"
                pkg_files=()
                while IFS= read -r f; do
                    [[ -n "$f" ]] && pkg_files+=("stow/$pkg/$f")
                done <<< "${pkg_modified[$pkg]}${pkg_added[$pkg]}${pkg_deleted[$pkg]}"
                git diff -- "${pkg_files[@]}" 2>/dev/null
                echo ""
            done
            echo -e "  ${DIM}Run 'dotfiles review' again to commit.${NC}"
            ;;
        *)
            echo "  No changes made."
            ;;
    esac

    cd - > /dev/null || return
}

# Update dotfiles
dotfiles-update() {
    echo "Updating dotfiles..."
    cd "$SYSTEM_DIR/dotfiles" || return
    git pull
    echo "Re-stowing packages..."
    cd stow || return
    for package in */; do
        stow -R -v -t "$HOME" "${package%/}"
    done
    cd - > /dev/null || return
    echo "Dotfiles updated!"
}

# Show dotfiles status
dotfiles-status() {
    cd "$SYSTEM_DIR/dotfiles" || return

    local BOLD='\033[1m'
    local DIM='\033[2m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m'

    local dirty ahead behind
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

    if [[ $dirty -eq 0 && $ahead -eq 0 && $behind -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Dotfiles are clean and up to date"
    else
        if [[ $dirty -gt 0 ]]; then
            echo -e "${YELLOW}~${NC} ${dirty} uncommitted change(s) — run 'dotfiles review'"
        fi
        if [[ $ahead -gt 0 ]]; then
            echo -e "${YELLOW}⇡${NC} ${ahead} commit(s) ahead — run 'dotfiles push'"
        fi
        if [[ $behind -gt 0 ]]; then
            echo -e "${RED}⇣${NC} ${behind} commit(s) behind — run 'dotfiles update'"
        fi
    fi

    cd - > /dev/null || return
}

# Commit dotfiles changes (with preview)
dotfiles-commit() {
    if [ -z "$1" ]; then
        echo "Usage: dotfiles commit <message>"
        return 1
    fi
    cd "$SYSTEM_DIR/dotfiles" || return

    local DIM='\033[2m' GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' NC='\033[0m'

    local changes
    changes=$(git status --porcelain 2>/dev/null)
    if [[ -z "$changes" ]]; then
        echo -e "${GREEN}✓${NC} Nothing to commit"
        cd - > /dev/null || return
        return 0
    fi

    echo -e "${DIM}Changes to commit:${NC}"
    echo "$changes" | while IFS= read -r line; do
        local st="${line:0:2}" file="${line:3}"
        case "$st" in
            " M"|"M "|"MM") echo -e "  ${YELLOW}~${NC} $file" ;;
            " D"|"D ")      echo -e "  ${RED}-${NC} $file" ;;
            "??")           echo -e "  ${GREEN}+${NC} $file" ;;
            *)              echo -e "  ${DIM}?${NC} $file" ;;
        esac
    done
    echo ""
    echo -ne "Commit all with message '${1}'? ${DIM}[Y/n]${NC} "
    read -k 1 REPLY
    echo ""

    case $REPLY in
        [Nn])
            echo -e "${DIM}Cancelled. Use 'dotfiles review' for per-package commits.${NC}"
            ;;
        *)
            git add .
            git commit -m "$1"
            ;;
    esac

    cd - > /dev/null || return
}

# Push dotfiles to origin
dotfiles-push() {
    cd "$SYSTEM_DIR/dotfiles" || return

    local GREEN='\033[0;32m'
    local RED='\033[0;31m'
    local DIM='\033[2m'
    local NC='\033[0m'

    local ahead
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    if [[ $ahead -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Already up to date with origin"
    elif git push --quiet; then
        echo -e "${GREEN}✓${NC} Pushed ${ahead} commit(s) to origin"
    else
        echo -e "${RED}✗${NC} Push failed"
    fi

    cd - > /dev/null || return
}

# List available stow packages
dotfiles-packages() {
    local BOLD='\033[1m' DIM='\033[2m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
    local stow_dir="$SYSTEM_DIR/dotfiles/stow"

    local pkg linked
    for pkg in "$stow_dir"/*/; do
        pkg="${pkg%/}"
        pkg="${pkg##*/}"
        # Check if at least one file from this package is symlinked
        linked=false
        while IFS= read -r f; do
            local rel="${f#$stow_dir/$pkg/}"
            [[ -L "$HOME/$rel" ]] && linked=true && break
        done < <(find "$stow_dir/$pkg" -type f 2>/dev/null)

        if $linked; then
            echo -e "  ${GREEN}✓${NC} $pkg"
        else
            echo -e "  ${DIM}·${NC} ${DIM}$pkg${NC} ${DIM}(not deployed)${NC}"
        fi
    done
}

# Audit installed applications vs Brewfile
dotfiles-audit() {
    echo "Checking dotfiles sync status..."
    cd "$SYSTEM_DIR/dotfiles" || return
    ./scripts/sync-apps.sh --audit
    cd - > /dev/null || return
}

# Add new applications to Brewfile
dotfiles-add-apps() {
    echo "Adding new applications..."
    cd "$SYSTEM_DIR/dotfiles" || return
    ./scripts/sync-apps.sh --add
    cd - > /dev/null || return
}

# Update all Homebrew packages
dotfiles-brew-update() {
    echo "Updating all Homebrew packages..."
    cd "$SYSTEM_DIR/dotfiles" || return
    ./scripts/sync-apps.sh --update
    cd - > /dev/null || return
}

# Export current installation state
dotfiles-export() {
    echo "Exporting current installation state..."
    cd "$SYSTEM_DIR/dotfiles" || return
    ./scripts/sync-apps.sh --export
    cd - > /dev/null || return
}

# Quick sync workflow: audit -> add -> commit
dotfiles-sync() {
    echo "Running full dotfiles sync workflow..."
    cd "$SYSTEM_DIR/dotfiles" || return

    # Audit
    echo "\n=== AUDIT ==="
    ./scripts/sync-apps.sh --audit

    # Ask if user wants to continue
    echo ""
    read -p "Add new apps to Brewfile? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/sync-apps.sh --add

        # Commit if changes were made
        if [[ $(git status --porcelain) ]]; then
            echo ""
            read -p "Commit changes? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git add bootstrap/brewfile bootstrap/MANUAL_APPS.md
                git commit -m "Update: Sync installed applications"
                echo "Changes committed!"
            fi
        fi
    fi

    cd - > /dev/null || return
}

# Quick Reference
# ============================================================================

# Show dotfiles quick reference
rogue() {
    "$SYSTEM_DIR/dotfiles/scripts/rogue.sh" "$@"
}

# SSH Key Management
# ============================================================================

# Create a new SSH key and register it in the dotfiles system
ssh-create() {
    "$SYSTEM_DIR/dotfiles/scripts/ssh-create.sh" "$@"
}

# List all managed SSH keys with their host mappings
ssh-list() {
    local keys_dir="$HOME/.ssh/keys"
    local config_file="$HOME/.ssh/config"

    if [[ ! -d "$keys_dir" ]]; then
        echo "No keys directory found at $keys_dir"
        return 1
    fi

    echo "Managed SSH keys:"
    echo ""
    for pub in "$keys_dir"/*.pub; do
        [[ -f "$pub" ]] || continue
        local name=$(basename "$pub" .pub)
        local hostname=""
        if [[ -f "$config_file" ]]; then
            hostname=$(awk "/^Host ${name}\$/{found=1} found && /HostName/{print \$2; exit}" "$config_file")
        fi
        printf "  %-25s → %s\n" "$name" "${hostname:-<no config entry>}"
    done
    echo ""
}

# AI Skills Management
# ============================================================================

# Create a new AI agent skill
skills-create() {
    "$SYSTEM_DIR/dotfiles/scripts/skills-create.sh" "$@"
}

# Sync skills to all AI tools
skills-sync() {
    "$SYSTEM_DIR/dotfiles/scripts/skills-sync.sh" "$@"
}

# macOS Specific Functions
# ============================================================================

# Flush DNS cache
flushdns() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "DNS cache flushed"
}

# Show/hide hidden files in Finder
showhidden() {
    defaults write com.apple.finder AppleShowAllFiles -bool true
    killall Finder
}

hidehidden() {
    defaults write com.apple.finder AppleShowAllFiles -bool false
    killall Finder
}

# Lock screen
lock() {
    /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
}

# Empty trash
emptytrash() {
    echo "Emptying trash..."
    rm -rf ~/.Trash/*
    echo "Trash emptied!"
}

# Startup Checks
# ============================================================================

# Nudge for uncommitted dotfiles adoptions (once per session, >24h old only)
_dotfiles_pending_check() {
    # Skip if already checked this session
    [[ -n "$_DOTFILES_CHECKED" ]] && return
    export _DOTFILES_CHECKED=1

    local dotfiles_dir="${SYSTEM_DIR:-$HOME/Documents/paras/04-system}/dotfiles"
    [[ -d "$dotfiles_dir/.git" ]] || return

    # Fast check: any untracked stow/ dirs?
    local pending
    pending=$(git -C "$dotfiles_dir" status --porcelain 2>/dev/null | grep -c '^?? stow/' || true)
    [[ "$pending" -eq 0 ]] && return

    # Check if oldest untracked package is >24h old
    local oldest_ts now_ts age_hours
    oldest_ts=$(find "$dotfiles_dir"/stow -maxdepth 2 -name ".git" -prune -o -type d -print 2>/dev/null \
        | head -5 | while read -r d; do stat -f "%m" "$d" 2>/dev/null; done | sort -n | head -1)
    [[ -z "$oldest_ts" ]] && return
    now_ts=$(date +%s)
    age_hours=$(( (now_ts - oldest_ts) / 3600 ))
    [[ "$age_hours" -lt 24 ]] && return

    # Defer output to a precmd after P10k instant prompt has released stdout.
    # P10k forces _p9k_precmd to run LAST in precmd_functions, and it's there
    # that _p9k_clear_instant_prompt restores fd 1/2 and unsets the flag.
    # So: first precmd → flag still set → skip; second precmd → flag gone → echo.
    _dotfiles_pending_msg="\033[2mdotfiles: ${pending} adopted config(s) pending commit. Run \033[0mdotfiles review\033[2m to commit.\033[0m"
    autoload -Uz add-zsh-hook
    _dotfiles_show_pending() {
        (( ${+__p9k_instant_prompt_active} )) && return
        echo -e "$_dotfiles_pending_msg"
        unset _dotfiles_pending_msg
        add-zsh-hook -d precmd _dotfiles_show_pending
    }
    add-zsh-hook precmd _dotfiles_show_pending
}
_dotfiles_pending_check
