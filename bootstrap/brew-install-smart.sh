#!/usr/bin/env bash

################################################################################
# brew-install-smart.sh - Smart Homebrew Installer
#
# This script intelligently installs packages from the Brewfile by:
# - Skipping apps already installed in /Applications
# - Installing only missing CLI tools
# - Showing what it's skipping vs installing
#
# Usage: ./brew-install-smart.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/brewfile"

echo -e "${BLUE}=== Smart Homebrew Installer ===${NC}\n"

# Check if Brewfile exists
if [ ! -f "$BREWFILE" ]; then
    echo -e "${RED}✗ Brewfile not found at $BREWFILE${NC}"
    exit 1
fi

# First, install taps and formulas (CLI tools) - these are lightweight
echo -e "${BLUE}Step 1: Installing taps...${NC}"
grep '^tap ' "$BREWFILE" | while read -r line; do
    tap_name=$(echo "$line" | sed 's/tap "\([^"]*\)".*/\1/')
    if brew tap | grep -q "^$tap_name$"; then
        echo -e "${GREEN}✓${NC} $tap_name (already tapped)"
    else
        echo -e "${YELLOW}→${NC} Tapping $tap_name..."
        brew tap "$tap_name"
    fi
done

echo -e "\n${BLUE}Step 2: Installing CLI tools (formulas)...${NC}"
grep '^brew "' "$BREWFILE" | sed 's/brew "\([^"]*\)".*/\1/' | while read -r formula; do
    if brew list "$formula" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $formula (already installed)"
    else
        echo -e "${YELLOW}→${NC} Installing $formula..."
        brew install "$formula" || echo -e "${RED}✗${NC} Failed to install $formula"
    fi
done

# For casks, check if app already exists in /Applications
echo -e "\n${BLUE}Step 3: Checking applications (casks)...${NC}"
echo -e "${YELLOW}This step will skip apps already in /Applications${NC}\n"

SKIPPED=0
TO_INSTALL=0
FAILED=()

grep '^cask "' "$BREWFILE" | sed 's/cask "\([^"]*\)".*/\1/' | while read -r cask; do
    # Check if already managed by Homebrew first (most reliable)
    if brew list --cask "$cask" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $cask (managed by Homebrew)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Get the app name that this cask would install
    app_info=$(brew info --cask "$cask" 2>/dev/null || echo "")

    # Extract app name from "Artifacts" section (format: "AppName.app (App)")
    # Handle symlinks like "qbittorrent.app -> qBittorrent.app (App)"
    app_name=$(echo "$app_info" | grep "\.app (App)" | sed 's/^[[:space:]]*//' | sed 's/ (App)$//' | sed 's/.*-> //' | head -1)

    # If no .app found, check for .pkg installers (these don't go to /Applications)
    if [ -z "$app_name" ]; then
        if echo "$app_info" | grep -q "(Pkg)\|(Installer)"; then
            echo -e "${YELLOW}⊙${NC} $cask → package installer ${BLUE}(skipping, can't verify)${NC}"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
    fi

    # Check if app exists in /Applications (case-insensitive)
    if [ -n "$app_name" ]; then
        # Try exact match first
        if [ -d "/Applications/$app_name" ]; then
            echo -e "${GREEN}⊙${NC} $cask → $app_name ${BLUE}(skipping, already in /Applications)${NC}"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Try case-insensitive match
        found_app=$(find /Applications -maxdepth 1 -iname "$app_name" -type d 2>/dev/null | head -1)
        if [ -n "$found_app" ]; then
            echo -e "${GREEN}⊙${NC} $cask → $(basename "$found_app") ${BLUE}(skipping, already in /Applications)${NC}"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
    fi

    # Not found, install it
    echo -e "${YELLOW}→${NC} Installing $cask..."
    if brew install --cask "$cask" 2>/dev/null; then
        TO_INSTALL=$((TO_INSTALL + 1))
    else
        echo -e "${RED}✗${NC} Failed to install $cask (may require manual install or license)"
        FAILED+=("$cask")
    fi
done

echo -e "\n${BLUE}Step 4: Mac App Store apps...${NC}"
if command -v mas &>/dev/null; then
    grep '^mas ' "$BREWFILE" | while read -r line; do
        app_name=$(echo "$line" | sed 's/mas "\([^"]*\)".*/\1/')
        app_id=$(echo "$line" | sed 's/.*id: \([0-9]*\).*/\1/')

        if mas list | grep -q "$app_id"; then
            echo -e "${GREEN}✓${NC} $app_name (already installed)"
        else
            echo -e "${YELLOW}→${NC} Installing $app_name (ID: $app_id)..."
            mas install "$app_id" || echo -e "${RED}✗${NC} Failed to install $app_name"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} mas (Mac App Store CLI) not installed. Skipping App Store apps."
    echo -e "   Install with: brew install mas"
fi

echo -e "\n${GREEN}=== Summary ===${NC}"
echo -e "Skipped $SKIPPED apps (already installed)"
echo -e "Installed $TO_INSTALL new apps"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Failed to install:${NC}"
    printf '%s\n' "${FAILED[@]}"
    echo -e "\nThese may require:"
    echo -e "  - Manual installation from their websites"
    echo -e "  - Active licenses (e.g., Bartender, Little Snitch)"
    echo -e "  - Mac App Store sign-in"
fi

echo -e "\n${GREEN}✓ Smart installation complete!${NC}"
