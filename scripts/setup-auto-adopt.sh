#!/usr/bin/env bash

################################################################################
# setup-auto-adopt.sh - Install/Uninstall Auto-Adopt Daemon
#
# Manages the launchd daemon that automatically adopts new dotfiles.
#
# Usage:
#   ./setup-auto-adopt.sh install     Install and start the daemon
#   ./setup-auto-adopt.sh uninstall   Stop and remove the daemon
#   ./setup-auto-adopt.sh status      Check if daemon is running
#   ./setup-auto-adopt.sh reinstall   Uninstall then install
#
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
PLIST_NAME="com.kyledenis.dotfiles.auto-adopt.plist"
PLIST_SRC="$DOTFILES_DIR/bootstrap/launchd/$PLIST_NAME"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME"
STATE_DIR="$HOME/.local/state/dotfiles"
LOG_FILE="$STATE_DIR/auto-adopt.log"

# Runtime script location (outside protected Documents folder)
RUNTIME_DIR="$HOME/.local/bin"
RUNTIME_SCRIPT="$RUNTIME_DIR/dotfiles-auto-adopt"

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

install_daemon() {
    echo "Installing auto-adopt daemon..."

    # Check if source plist exists
    if [[ ! -f "$PLIST_SRC" ]]; then
        print_error "Source plist not found: $PLIST_SRC"
        exit 1
    fi

    # Create directories
    mkdir -p "$HOME/Library/LaunchAgents"
    mkdir -p "$STATE_DIR"
    mkdir -p "$RUNTIME_DIR"

    # Copy the auto-adopt script to a non-protected location
    # (macOS restricts launchd access to ~/Documents)
    cp "$SCRIPT_DIR/auto-adopt.sh" "$RUNTIME_SCRIPT"
    chmod +x "$RUNTIME_SCRIPT"

    # Unload existing if present (ignore errors)
    launchctl unload "$PLIST_DST" 2>/dev/null || true

    # Generate plist with correct runtime path
    cat > "$PLIST_DST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kyledenis.dotfiles.auto-adopt</string>

    <key>ProgramArguments</key>
    <array>
        <string>$RUNTIME_SCRIPT</string>
    </array>

    <key>StartInterval</key>
    <integer>14400</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>$HOME</string>
        <key>DOTFILES_DIR</key>
        <string>$DOTFILES_DIR</string>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/dotfiles-auto-adopt-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dotfiles-auto-adopt-stderr.log</string>

    <key>LowPriorityIO</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>Nice</key>
    <integer>10</integer>
</dict>
</plist>
EOF

    # Load the daemon
    if launchctl load "$PLIST_DST"; then
        print_success "Auto-adopt daemon installed and started"
        echo ""
        echo "The daemon will run:"
        echo "  - Immediately (on load)"
        echo "  - Every 4 hours"
        echo "  - On login"
        echo ""
        echo "Runtime script: $RUNTIME_SCRIPT"
        echo ""
        echo "Check status with: dotfiles status"
        echo "View logs with:    dotfiles log"
    else
        print_error "Failed to load daemon"
        exit 1
    fi
}

uninstall_daemon() {
    echo "Uninstalling auto-adopt daemon..."

    # Unload if running
    if launchctl list 2>/dev/null | grep -q "dotfiles.auto-adopt"; then
        launchctl unload "$PLIST_DST" 2>/dev/null || true
    fi

    # Remove plist
    if [[ -f "$PLIST_DST" ]]; then
        rm -f "$PLIST_DST"
        print_success "Plist removed"
    fi

    # Remove runtime script
    if [[ -f "$RUNTIME_SCRIPT" ]]; then
        rm -f "$RUNTIME_SCRIPT"
        print_success "Runtime script removed"
    fi

    print_success "Auto-adopt daemon uninstalled"
}

show_status() {
    echo "Auto-Adopt Daemon Status"
    echo "========================"
    echo ""

    # Check if plist is installed
    if [[ -f "$PLIST_DST" ]]; then
        print_success "Plist installed: $PLIST_DST"
    else
        print_error "Plist not installed"
        echo ""
        echo "Run './setup-auto-adopt.sh install' to install"
        return 1
    fi

    # Check if loaded in launchctl
    if launchctl list 2>/dev/null | grep -q "dotfiles.auto-adopt"; then
        print_success "Daemon is loaded and scheduled"
    else
        print_warning "Daemon is installed but not loaded"
        echo "  Try: launchctl load $PLIST_DST"
    fi

    echo ""

    # Show last run time from log
    if [[ -f "$LOG_FILE" ]]; then
        local last_run
        last_run=$(grep "Scan started" "$LOG_FILE" 2>/dev/null | tail -1 | cut -d']' -f1 | tr -d '[')
        if [[ -n "$last_run" ]]; then
            echo "Last run: $last_run"
        fi

        # Show recent activity
        local recent_adopts
        recent_adopts=$(grep "ADOPTED:" "$LOG_FILE" 2>/dev/null | tail -5)
        if [[ -n "$recent_adopts" ]]; then
            echo ""
            echo "Recent adoptions:"
            echo "$recent_adopts" | sed 's/^/  /'
        fi
    else
        echo "No log file yet (daemon hasn't run)"
    fi

    echo ""

    # Show temp log if exists
    if [[ -f "/tmp/dotfiles-auto-adopt-stderr.log" ]]; then
        local errors
        errors=$(cat /tmp/dotfiles-auto-adopt-stderr.log 2>/dev/null)
        if [[ -n "$errors" ]]; then
            print_warning "Errors in /tmp/dotfiles-auto-adopt-stderr.log:"
            echo "$errors" | tail -5 | sed 's/^/  /'
        fi
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

case "${1:-}" in
    install)
        install_daemon
        ;;
    uninstall|remove)
        uninstall_daemon
        ;;
    reinstall)
        uninstall_daemon
        echo ""
        install_daemon
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 [install|uninstall|reinstall|status]"
        echo ""
        echo "Commands:"
        echo "  install     Install and start the auto-adopt daemon"
        echo "  uninstall   Stop and remove the daemon"
        echo "  reinstall   Uninstall then install (useful after updates)"
        echo "  status      Check if daemon is running"
        exit 1
        ;;
esac
