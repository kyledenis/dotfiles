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
    curl -s https://ifconfig.me
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
    lsof -ti :"$1" | xargs kill -9
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

    if $dry_run; then
        echo "=== DRY RUN MODE - No files will be deleted ==="
        echo ""
    fi

    # Homebrew cleanup (always safe)
    if command -v brew >/dev/null; then
        echo "📦 Homebrew cleanup..."
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
        echo "⚠️  Skipping Python cache cleanup (running from system directory: $cwd)"
        echo "   Run from a project directory to clean Python caches"
    else
        # Check if this looks like a Python project
        if [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -d "venv" ]] || [[ -d ".venv" ]]; then
            echo "🐍 Python cache cleanup (current directory only)..."
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
            echo "🐍 Skipping Python cleanup (not a Python project directory)"
        fi
    fi
    echo ""

    # macOS caches - only with --all flag due to side effects
    if $aggressive; then
        echo "🍎 macOS cache cleanup..."
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
            echo "🐳 Docker cleanup..."

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
            echo "🐳 Docker: daemon not running, skipping"
        fi
        echo ""
    fi

    if $dry_run; then
        echo "=== DRY RUN COMPLETE - Run without --dry-run to execute ==="
    else
        echo "✅ Cleanup complete!"
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
        add)
            dotfiles-add "$@"
            ;;
        update)
            dotfiles-update "$@"
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
        help|--help|-h|*)
            echo "dotfiles - Unified dotfiles management"
            echo ""
            echo "Auto-adopt (background daemon):"
            echo "  status      Check if daemon is running"
            echo "  log [n]     Show last n log entries (default 20)"
            echo "  run-now     Manually trigger auto-adopt"
            echo "  dry-run     Preview what would be adopted"
            echo "  install     Install the auto-adopt daemon"
            echo "  uninstall   Remove the auto-adopt daemon"
            echo ""
            echo "Manual management:"
            echo "  add         Add a file to stow management"
            echo "  update      Pull latest and re-stow"
            echo "  st          Show git status"
            echo "  commit      Commit dotfiles changes"
            echo ""
            echo "App sync:"
            echo "  audit       Compare installed apps vs Brewfile"
            echo "  add-apps    Add new apps to Brewfile"
            echo "  sync        Full sync workflow"
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
    git status
    cd - > /dev/null || return
}

# Commit dotfiles changes
dotfiles-commit() {
    if [ -z "$1" ]; then
        echo "Usage: dotfiles-commit <message>"
        return 1
    fi
    cd "$SYSTEM_DIR/dotfiles" || return
    git add .
    git commit -m "$1"
    cd - > /dev/null || return
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
