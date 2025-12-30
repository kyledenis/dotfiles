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

# Clean up system
cleanup() {
    echo "Cleaning up..."

    # Homebrew
    if command -v brew >/dev/null; then
        echo "Cleaning Homebrew..."
        brew cleanup -s
        brew autoremove
    fi

    # Python cache
    echo "Cleaning Python cache..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    find . -type f -name "*.pyc" -delete 2>/dev/null

    # Node modules (careful with this one!)
    # find . -name "node_modules" -type d -prune -print -exec rm -rf {} \;

    # macOS
    echo "Cleaning macOS caches..."
    rm -rf ~/Library/Caches/*

    # Docker
    if command -v docker >/dev/null; then
        echo "Cleaning Docker..."
        docker system prune -af
    fi

    echo "Cleanup complete!"
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
