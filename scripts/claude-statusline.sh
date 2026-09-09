#!/usr/bin/env bash

################################################################################
# claude-statusline.sh - Point Claude Code at the stow-managed status line
#
# ~/.claude/settings.json is not tracked: Claude Code rewrites it whenever a
# preference changes, it holds machine-local permission grants, and this
# repository is public. So rather than stowing the file, this merges in the one
# key that references the status line and leaves everything else alone.
#
# Usage: ./claude-statusline.sh [--dry-run]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info()    { echo -e "${CYAN}ℹ${NC} $1"; }

SETTINGS="$HOME/.claude/settings.json"
SCRIPT_TARGET="$HOME/.claude/statusline-command.sh"
STATUSLINE_COMMAND="~/.claude/statusline-command.sh"

DRY_RUN=false
case "${1:-}" in
    --dry-run) DRY_RUN=true ;;
    "")        ;;
    *)         print_error "Unknown option: $1"; exit 1 ;;
esac

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required to merge the status line setting"
    exit 1
fi

if [ ! -e "$SCRIPT_TARGET" ]; then
    print_warning "Status line script not deployed yet — stow the claude package first"
    exit 0
fi

current=$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null || echo "")
if [ "$current" = "$STATUSLINE_COMMAND" ]; then
    print_success "claude: status line already configured"
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    if [ -n "$current" ]; then
        print_info "Would repoint status line: $current -> $STATUSLINE_COMMAND"
    else
        print_info "Would set status line to: $STATUSLINE_COMMAND"
    fi
    exit 0
fi

mkdir -p "$(dirname "$SETTINGS")"
existed=true
if [ ! -f "$SETTINGS" ]; then
    existed=false
    umask 077
    echo '{}' > "$SETTINGS"
fi

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    print_error "$SETTINGS is not valid JSON — refusing to modify it"
    exit 1
fi

backup=""
if [ "$existed" = true ]; then
    backup="$SETTINGS.bak-statusline-$(date +%Y%m%d-%H%M%S)"
    cp -p "$SETTINGS" "$backup"
fi

merged=$(mktemp)
jq --arg cmd "$STATUSLINE_COMMAND" \
   '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "$merged"

if ! jq -e . "$merged" >/dev/null 2>&1; then
    print_error "Merge produced invalid JSON — settings left untouched"
    rm -f "$merged"
    exit 1
fi

# Write through rather than replacing, so a symlinked settings.json survives.
cat "$merged" > "$SETTINGS"
rm -f "$merged"

print_success "claude: status line configured ($STATUSLINE_COMMAND)"
if [ -n "$backup" ]; then
    print_info "Previous settings backed up to: $(basename "$backup")"
fi
