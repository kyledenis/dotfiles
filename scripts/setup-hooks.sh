#!/usr/bin/env bash

################################################################################
# setup-hooks.sh - Install Git Hooks for Dotfiles Repository
#
# This script installs pre-commit hooks to ensure quality and consistency.
#
# Usage: ./setup-hooks.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
GIT_HOOKS_DIR="$DOTFILES_DIR/.git/hooks"

echo -e "${BLUE}Setting up Git hooks for dotfiles repository...${NC}\n"

# Check if we're in a git repository
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    echo "Error: Not in a Git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Install pre-commit hook
echo "Installing pre-commit hook..."
cp "$SCRIPT_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo -e "${GREEN}✓ Pre-commit hook installed${NC}\n"

# Test the hook
echo "Testing pre-commit hook..."
if "$GIT_HOOKS_DIR/pre-commit"; then
    echo -e "${GREEN}✓ Pre-commit hook is working${NC}\n"
else
    echo "Note: Pre-commit hook tests failed, but this might be expected."
    echo "The hook will still run on commits.\n"
fi

echo -e "${GREEN}Git hooks setup complete!${NC}"
echo ""
echo "The following hooks are now active:"
echo "  - pre-commit: Checks for sensitive data, syntax errors, and more"
echo ""
echo "To bypass hooks temporarily: git commit --no-verify"
echo ""
