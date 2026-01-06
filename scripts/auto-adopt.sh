#!/usr/bin/env bash

################################################################################
# auto-adopt.sh - Intelligent Dotfiles Auto-Adoption
#
# Automatically discovers and adopts new dotfiles into stow management.
# Runs silently via launchd, classifies files intelligently, and only
# logs actions without user intervention.
#
# Usage:
#   ./auto-adopt.sh              # Run adoption (default)
#   ./auto-adopt.sh --dry-run    # Preview what would be adopted
#   ./auto-adopt.sh --status     # Show current state
#
################################################################################

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow DOTFILES_DIR to be overridden by environment variable
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$SCRIPT_DIR")}"
STOW_DIR="$DOTFILES_DIR/stow"
# Use runtime patterns dir if set (for launchd), otherwise use dotfiles location
PATTERNS_DIR="${DOTFILES_RUNTIME_DIR:-$DOTFILES_DIR/scripts}/patterns"

STATE_DIR="$HOME/.local/state/dotfiles"
LOG_FILE="$STATE_DIR/auto-adopt.log"
LAST_SCAN_FILE="$STATE_DIR/last-scan.txt"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# ============================================================================
# Logging
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log_info() {
    log "INFO: $*"
}

log_warn() {
    log "WARN: $*"
}

log_adopted() {
    log "ADOPTED: $*"
}

log_skipped() {
    log "SKIPPED: $*"
}

log_sensitive() {
    log "SENSITIVE: $*"
}

# ============================================================================
# Pattern Loading
# ============================================================================

IGNORE_PATTERNS=""
SENSITIVE_PATTERNS=""
ADOPT_PATTERNS=""

load_patterns_to_var() {
    local file="$1"
    local result=""

    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ -z "$line" || "$line" == \#* ]] && continue
            # Strip package mapping for pattern matching (keep just the pattern)
            local pattern="${line%%:*}"
            result="${result}${pattern}"$'\n'
        done < "$file"
    fi
    echo "$result"
}

init_patterns() {
    IGNORE_PATTERNS=$(load_patterns_to_var "$PATTERNS_DIR/ignore.txt")
    SENSITIVE_PATTERNS=$(load_patterns_to_var "$PATTERNS_DIR/sensitive.txt")
    ADOPT_PATTERNS=$(load_patterns_to_var "$PATTERNS_DIR/adopt.txt")
}

# ============================================================================
# Pattern Matching
# ============================================================================

matches_pattern() {
    local path="$1"
    local patterns="$2"

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue

        # Handle glob patterns
        if [[ "$path" == $pattern ]]; then
            return 0
        fi
        # Handle directory patterns (e.g., .cache/*)
        if [[ "$pattern" == *'/*' ]]; then
            local dir_pattern="${pattern%/*}"
            if [[ "$path" == $dir_pattern || "$path" == $dir_pattern/* ]]; then
                return 0
            fi
        fi
        # Handle wildcard prefix patterns (e.g., *token*)
        if [[ "$pattern" == \** && "$pattern" == *\* ]]; then
            local inner="${pattern#\*}"
            inner="${inner%\*}"
            if [[ "$path" == *"$inner"* ]]; then
                return 0
            fi
        fi
    done <<< "$patterns"
    return 1
}

# ============================================================================
# Classification
# ============================================================================

classify() {
    local path="$1"

    # Check sensitive patterns first (highest priority)
    if matches_pattern "$path" "$SENSITIVE_PATTERNS"; then
        echo "sensitive"
        return
    fi

    # Check ignore patterns
    if matches_pattern "$path" "$IGNORE_PATTERNS"; then
        echo "ignore"
        return
    fi

    # Check adopt patterns
    if matches_pattern "$path" "$ADOPT_PATTERNS"; then
        echo "adopt"
        return
    fi

    # Default: ignore unknown files
    echo "unknown"
}

# ============================================================================
# Package Name Inference
# ============================================================================

get_package_name() {
    local rel_path="$1"

    # Check adopt.txt for explicit package mapping
    if [[ -f "$PATTERNS_DIR/adopt.txt" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            if [[ "$line" == *:* ]]; then
                local pattern="${line%%:*}"
                local package="${line#*:}"
                if [[ "$rel_path" == $pattern ]]; then
                    echo "$package"
                    return
                fi
            fi
        done < "$PATTERNS_DIR/adopt.txt"
    fi

    # Infer from path
    if [[ "$rel_path" == .config/* ]]; then
        # .config/appname/... → package "appname"
        echo "$rel_path" | cut -d'/' -f2
    elif [[ "$rel_path" =~ ^\.[a-z]+rc$ ]]; then
        # .apprc → package "app"
        local name="${rel_path#.}"
        echo "${name%rc}"
    elif [[ "$rel_path" =~ ^\.[a-z]+\.conf$ ]]; then
        # .app.conf → package "app"
        local name="${rel_path#.}"
        echo "${name%%.*}"
    else
        # .appname or .app.config → package from first part
        local name="${rel_path#.}"
        echo "${name%%[._]*}"
    fi
}

# ============================================================================
# Stow Management Check
# ============================================================================

is_managed_by_stow() {
    local path="$1"
    local rel_path="${path#$HOME/}"

    # Check if it's a symlink pointing into our stow directory
    if [[ -L "$path" ]]; then
        local target
        target=$(readlink "$path" 2>/dev/null || true)
        if [[ "$target" == "$STOW_DIR"/* || "$target" == *"/dotfiles/stow/"* ]]; then
            return 0
        fi
    fi

    # Check if a stow package exists for this path
    # e.g., ~/.config/atuin would check for stow/atuin/.config/atuin
    local package_name
    if [[ "$rel_path" == .config/* ]]; then
        package_name=$(echo "$rel_path" | cut -d'/' -f2)
    else
        package_name="${rel_path#.}"
        package_name="${package_name%%[._]*}"
    fi

    if [[ -n "$package_name" && -d "$STOW_DIR/$package_name" ]]; then
        # Check if this specific path exists in the stow package
        if [[ -e "$STOW_DIR/$package_name/$rel_path" ]]; then
            return 0
        fi
    fi

    # For directories, check if ANY child is a symlink to stow
    if [[ -d "$path" ]]; then
        local child
        while IFS= read -r -d '' child; do
            if [[ -L "$child" ]]; then
                local target
                target=$(readlink "$child" 2>/dev/null || true)
                if [[ "$target" == *"/dotfiles/stow/"* ]]; then
                    return 0
                fi
            fi
        done < <(find "$path" -maxdepth 1 -print0 2>/dev/null)
    fi

    return 1
}

# ============================================================================
# File Adoption
# ============================================================================

adopt_file() {
    local file="$1"
    local dry_run="${2:-false}"
    local rel_path="${file#$HOME/}"

    # Get package name
    local package
    package=$(get_package_name "$rel_path")

    # Validate package name
    if [[ -z "$package" || "$package" == "." ]]; then
        log_warn "Could not determine package name for: $rel_path"
        return 1
    fi

    # Build stow path
    local stow_path="$STOW_DIR/$package/$rel_path"
    local stow_dir
    stow_dir=$(dirname "$stow_path")

    if [[ "$dry_run" == "true" ]]; then
        echo "Would adopt: $rel_path → stow/$package/"
        return 0
    fi

    # Create directory structure
    mkdir -p "$stow_dir"

    # Move file to stow
    if [[ -d "$file" ]]; then
        # For directories, copy contents then remove original
        cp -R "$file" "$stow_path"
        rm -rf "$file"
    else
        mv "$file" "$stow_path"
    fi

    # Create symlink back
    ln -s "$stow_path" "$file"

    log_adopted "$rel_path → stow/$package/"
    echo "Adopted: $rel_path → stow/$package/"
}

# ============================================================================
# Home Directory Scanning
# ============================================================================

scan_home() {
    local -a candidates=()

    # Scan ~ for dotfiles (depth 1)
    while IFS= read -r -d '' item; do
        local rel_path="${item#$HOME/}"
        [[ "$rel_path" == "." || "$rel_path" == ".." ]] && continue
        candidates+=("$rel_path")
    done < <(find "$HOME" -maxdepth 1 -name ".*" -print0 2>/dev/null)

    # Scan ~/.config (depth 2)
    if [[ -d "$HOME/.config" ]]; then
        while IFS= read -r -d '' item; do
            local rel_path="${item#$HOME/}"
            # Only include top-level directories in .config
            if [[ "$rel_path" == .config/* ]]; then
                local depth
                depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
                [[ $depth -gt 1 ]] && continue
            fi
            candidates+=("$rel_path")
        done < <(find "$HOME/.config" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
    fi

    printf '%s\n' "${candidates[@]}"
}

# ============================================================================
# Main Logic
# ============================================================================

run_adoption() {
    local dry_run="${1:-false}"

    log_info "Scan started (dry_run=$dry_run)"

    init_patterns

    local adopted_count=0
    local skipped_count=0
    local sensitive_count=0
    local ignored_count=0

    while IFS= read -r rel_path; do
        [[ -z "$rel_path" ]] && continue

        local full_path="$HOME/$rel_path"

        # Skip if already managed by stow
        if is_managed_by_stow "$full_path"; then
            continue
        fi

        # Skip if it's a symlink pointing elsewhere (intentional)
        if [[ -L "$full_path" ]]; then
            continue
        fi

        # Skip if file doesn't exist
        [[ ! -e "$full_path" ]] && continue

        # Classify
        local classification
        classification=$(classify "$rel_path")

        case "$classification" in
            sensitive)
                log_sensitive "$rel_path (not adopted for security)"
                sensitive_count=$((sensitive_count + 1))
                ;;
            ignore)
                ignored_count=$((ignored_count + 1))
                ;;
            adopt)
                if adopt_file "$full_path" "$dry_run"; then
                    adopted_count=$((adopted_count + 1))
                else
                    skipped_count=$((skipped_count + 1))
                fi
                ;;
            unknown)
                log_skipped "$rel_path (unknown pattern)"
                skipped_count=$((skipped_count + 1))
                ;;
        esac
    done < <(scan_home)

    log_info "Scan complete: adopted=$adopted_count, sensitive=$sensitive_count, skipped=$skipped_count, ignored=$ignored_count"

    if [[ "$dry_run" == "false" && $adopted_count -gt 0 ]]; then
        echo ""
        echo "Summary: $adopted_count file(s) adopted"
        echo "Run 'dotfiles log' to see details"
    elif [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "Dry run complete: $adopted_count would be adopted"
    fi
}

show_status() {
    echo "Auto-adopt Status"
    echo "================="
    echo ""
    echo "Directories:"
    echo "  Dotfiles: $DOTFILES_DIR"
    echo "  Stow:     $STOW_DIR"
    echo "  State:    $STATE_DIR"
    echo ""
    echo "Pattern files:"
    echo "  Ignore:    $(wc -l < "$PATTERNS_DIR/ignore.txt" 2>/dev/null || echo 0) patterns"
    echo "  Sensitive: $(wc -l < "$PATTERNS_DIR/sensitive.txt" 2>/dev/null || echo 0) patterns"
    echo "  Adopt:     $(wc -l < "$PATTERNS_DIR/adopt.txt" 2>/dev/null || echo 0) patterns"
    echo ""
    if [[ -f "$LOG_FILE" ]]; then
        echo "Last 5 log entries:"
        tail -5 "$LOG_FILE" | sed 's/^/  /'
    else
        echo "No log file yet"
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main() {
    case "${1:-}" in
        --dry-run|-n)
            run_adoption true
            ;;
        --status|-s)
            show_status
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run|--status|--help]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n   Preview what would be adopted"
            echo "  --status, -s    Show current state"
            echo "  --help, -h      Show this help"
            echo ""
            echo "With no arguments, runs adoption silently"
            ;;
        "")
            run_adoption false
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
