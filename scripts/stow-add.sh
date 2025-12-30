#!/usr/bin/env bash

################################################################################
# stow-add.sh - Easily Add Files to Dotfiles Management
#
# This script helps you add new config files to your stow-managed dotfiles.
# It handles the directory structure and symlinking automatically.
#
# Usage:
#   ./stow-add.sh ~/.claude/CLAUDE.md
#   ./stow-add.sh ~/.config/app/config.json app-config
#   ./stow-add.sh --create ~/.newrc newrc
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
STOW_DIR="$DOTFILES_DIR/stow"

################################################################################
# Helper Functions
################################################################################

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
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "${BLUE}→${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [options] <file-path> [package-name]

Add a file or directory to your stow-managed dotfiles.

Arguments:
    file-path       Path to the file/directory (e.g., ~/.claude/CLAUDE.md)
    package-name    Optional: Name for the stow package (auto-detected if not provided)

Options:
    --create        Create the file if it doesn't exist (with template)
    --force         Force overwrite if already managed
    --help          Show this help message

Examples:
    # Add an existing file
    $0 ~/.claude/CLAUDE.md

    # Add with specific package name
    $0 ~/.config/myapp/config.json myapp

    # Create and add a new file
    $0 --create ~/.newrc

    # Add an entire directory
    $0 ~/.config/starship

The script will:
    1. Detect or ask for a package name
    2. Create the proper stow directory structure
    3. Move/copy the file to stow/package/
    4. Create symlink back to original location
    5. Add to git and show you what to commit

EOF
}

################################################################################
# Main Logic
################################################################################

# Parse options
CREATE_MODE=false
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --create)
            CREATE_MODE=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Get file path
if [ -z "$1" ]; then
    print_error "No file path provided"
    show_usage
    exit 1
fi

FILE_PATH="$1"
CUSTOM_PACKAGE="$2"

# Expand ~ to $HOME
FILE_PATH="${FILE_PATH/#\~/$HOME}"

# Check if file exists (unless creating)
if [ "$CREATE_MODE" = false ] && [ ! -e "$FILE_PATH" ]; then
    print_error "File does not exist: $FILE_PATH"
    echo ""
    echo "Use --create to create a new file, or check the path."
    exit 1
fi

# Get relative path from HOME
if [[ "$FILE_PATH" == "$HOME"* ]]; then
    REL_PATH="${FILE_PATH#$HOME/}"
else
    print_error "File must be in your home directory (~)"
    exit 1
fi

# Extract package name and structure
if [ -n "$CUSTOM_PACKAGE" ]; then
    PACKAGE_NAME="$CUSTOM_PACKAGE"
else
    # Auto-detect package name from path
    if [[ "$REL_PATH" == .config/* ]]; then
        # For .config/app/file -> package is "app"
        PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f2)
    elif [[ "$REL_PATH" == .* ]]; then
        # For .dotfile or .dir/file -> extract base name
        PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f1 | sed 's/^\.//')
    else
        # For other files, use first directory component
        PACKAGE_NAME=$(echo "$REL_PATH" | cut -d'/' -f1)
    fi
fi

PACKAGE_DIR="$STOW_DIR/$PACKAGE_NAME"
TARGET_PATH="$PACKAGE_DIR/$REL_PATH"

echo ""
print_info "Configuration:"
echo "  Source file:    $FILE_PATH"
echo "  Relative path:  ~/$REL_PATH"
echo "  Package name:   $PACKAGE_NAME"
echo "  Stow location:  $TARGET_PATH"
echo ""

# Ask for confirmation
read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Aborted"
    exit 0
fi

################################################################################
# Execute
################################################################################

echo ""
print_step "Creating stow package structure..."

# Create package directory if it doesn't exist
mkdir -p "$(dirname "$TARGET_PATH")"
print_success "Created directory structure"

# Handle file creation or moving
if [ "$CREATE_MODE" = true ]; then
    print_step "Creating new file..."

    # Determine file type and create template
    BASENAME=$(basename "$FILE_PATH")

    if [[ "$BASENAME" == *.md ]]; then
        # Markdown template
        cat > "$TARGET_PATH" << EOF
# ${BASENAME%.md}

Created: $(date +%Y-%m-%d)

## Description

[Describe what this file is for]

## Usage

\`\`\`bash
# Example usage
\`\`\`

---

**Last Updated**: $(date +%Y-%m-%d)
EOF
    elif [[ "$BASENAME" == *.json ]]; then
        # JSON template
        cat > "$TARGET_PATH" << EOF
{
  "created": "$(date +%Y-%m-%d)",
  "description": "Configuration file"
}
EOF
    elif [[ "$BASENAME" == *.toml ]]; then
        # TOML template
        cat > "$TARGET_PATH" << EOF
# ${BASENAME%.toml} configuration
# Created: $(date +%Y-%m-%d)

[main]
# Your configuration here
EOF
    elif [[ "$BASENAME" == *.yaml || "$BASENAME" == *.yml ]]; then
        # YAML template
        cat > "$TARGET_PATH" << EOF
# ${BASENAME%.*} configuration
# Created: $(date +%Y-%m-%d)

config:
  # Your configuration here
EOF
    else
        # Plain text template
        cat > "$TARGET_PATH" << EOF
# ${BASENAME}
# Created: $(date +%Y-%m-%d)

# Configuration goes here
EOF
    fi

    print_success "Created template file: $TARGET_PATH"

elif [ -e "$FILE_PATH" ]; then
    # File exists, move it
    if [ -e "$TARGET_PATH" ] && [ "$FORCE_MODE" = false ]; then
        print_error "File already exists in stow: $TARGET_PATH"
        print_info "Use --force to overwrite"
        exit 1
    fi

    print_step "Moving file to stow..."
    mv "$FILE_PATH" "$TARGET_PATH"
    print_success "Moved file to: $TARGET_PATH"
else
    print_error "File doesn't exist and --create not specified"
    exit 1
fi

# Run stow to create symlink
print_step "Creating symlink with stow..."
cd "$STOW_DIR"

# Unstow first if forcing
if [ "$FORCE_MODE" = true ]; then
    stow -D "$PACKAGE_NAME" 2>/dev/null || true
fi

# Stow the package
stow -v "$PACKAGE_NAME" 2>&1 | grep -v "^LINK:" || true

print_success "Symlinked: $FILE_PATH -> $TARGET_PATH"

# Verify symlink
if [ -L "$FILE_PATH" ]; then
    print_success "Verification: Symlink created successfully"
else
    print_warning "Verification: Expected symlink not found at $FILE_PATH"
fi

# Git status
print_step "Git status..."
cd "$DOTFILES_DIR"

git add "stow/$PACKAGE_NAME"
print_success "Staged changes for commit"

echo ""
print_info "Next steps:"
echo "  1. Review the file: vim $TARGET_PATH"
echo "  2. Test that symlink works: ls -la $FILE_PATH"
echo "  3. Commit changes:"
echo ""
echo "     cd $DOTFILES_DIR"
echo "     git commit -m 'Add $PACKAGE_NAME dotfile'"
echo "     git push"
echo ""

# Show what was added
echo "Added to git:"
git status --short "stow/$PACKAGE_NAME"
echo ""

print_success "Done! Your dotfile is now managed by stow."
