#!/usr/bin/env bash

################################################################################
# scan-configs.sh - Detect new config candidates (read-only)
#
# Scans ~ and ~/.config for unmanaged configs matching adopt patterns and
# writes candidates to state. Never moves, copies, or symlinks anything —
# adoption happens with explicit consent in 'dotfiles review'.
#
# Usage:
#   ./scan-configs.sh            # Scan and print results
#   ./scan-configs.sh --quiet    # Scan silently (for background use)
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$SCRIPT_DIR")}"
STOW_DIR="$DOTFILES_DIR/stow"
PATTERNS_DIR="$DOTFILES_DIR/scripts/patterns"

STATE_DIR="$HOME/.local/state/dotfiles"
CANDIDATES_FILE="$STATE_DIR/candidates.txt"
STAMP_FILE="$STATE_DIR/last-scan"

mkdir -p "$STATE_DIR"

IGNORE_PATTERNS=""
SENSITIVE_PATTERNS=""
ADOPT_PATTERNS=""

load_patterns_to_var() {
    local file="$1"
    local result=""
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
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

matches_pattern() {
    local path="$1"
    local patterns="$2"
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if [[ "$path" == $pattern ]]; then
            return 0
        fi
        if [[ "$pattern" == *'/*' ]]; then
            local dir_pattern="${pattern%/*}"
            if [[ "$path" == $dir_pattern || "$path" == $dir_pattern/* ]]; then
                return 0
            fi
        fi
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

classify() {
    local path="$1"
    if matches_pattern "$path" "$SENSITIVE_PATTERNS"; then
        echo "sensitive"
        return
    fi
    if matches_pattern "$path" "$IGNORE_PATTERNS"; then
        echo "ignore"
        return
    fi
    if matches_pattern "$path" "$ADOPT_PATTERNS"; then
        echo "adopt"
        return
    fi
    echo "unknown"
}

is_managed_by_stow() {
    local path="$1"
    local rel_path="${path#$HOME/}"

    if [[ -L "$path" ]]; then
        local target
        target=$(readlink "$path" 2>/dev/null || true)
        if [[ "$target" == "$STOW_DIR"/* || "$target" == *"/dotfiles/stow/"* ]]; then
            return 0
        fi
    fi

    local package_name
    if [[ "$rel_path" == .config/* ]]; then
        package_name=$(echo "$rel_path" | cut -d'/' -f2)
    else
        package_name="${rel_path#.}"
        package_name="${package_name%%[._]*}"
    fi

    if [[ -n "$package_name" && -d "$STOW_DIR/$package_name" ]]; then
        if [[ -e "$STOW_DIR/$package_name/$rel_path" ]]; then
            return 0
        fi
    fi

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

scan_home() {
    local -a candidates=()

    while IFS= read -r -d '' item; do
        local rel_path="${item#$HOME/}"
        [[ "$rel_path" == "." || "$rel_path" == ".." ]] && continue
        candidates+=("$rel_path")
    done < <(find "$HOME" -maxdepth 1 -name ".*" -print0 2>/dev/null)

    if [[ -d "$HOME/.config" ]]; then
        while IFS= read -r -d '' item; do
            local rel_path="${item#$HOME/}"
            candidates+=("$rel_path")
        done < <(find "$HOME/.config" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
    fi

    if [[ ${#candidates[@]} -gt 0 ]]; then
        printf '%s\n' "${candidates[@]}"
    fi
}

main() {
    local quiet=false
    [[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]] && quiet=true

    init_patterns

    local tmp
    tmp=$(mktemp)
    local count=0
    local rel_path full_path size_kb file_count

    while IFS= read -r rel_path; do
        [[ -z "$rel_path" ]] && continue
        full_path="$HOME/$rel_path"

        [[ ! -e "$full_path" ]] && continue
        [[ -L "$full_path" ]] && continue
        is_managed_by_stow "$full_path" && continue
        [[ "$(classify "$rel_path")" == "adopt" ]] || continue

        if [[ -d "$full_path" ]]; then
            size_kb=$(du -sk "$full_path" 2>/dev/null | cut -f1)
            file_count=$(find "$full_path" -type f 2>/dev/null | wc -l | tr -d ' ')
        else
            size_kb=$(( ($(stat -f "%z" "$full_path" 2>/dev/null || echo 0) + 1023) / 1024 ))
            file_count=1
        fi

        echo "${rel_path}|${size_kb}|${file_count}" >> "$tmp"
        count=$((count + 1))
    done < <(scan_home)

    mv "$tmp" "$CANDIDATES_FILE"
    date +%s > "$STAMP_FILE"

    if ! $quiet; then
        if [[ $count -eq 0 ]]; then
            echo "No new config candidates."
        else
            echo "$count candidate(s) detected:"
            while IFS='|' read -r rel_path size_kb file_count; do
                [[ -z "$rel_path" ]] && continue
                if [[ $size_kb -ge 1024 ]]; then
                    echo "  $rel_path ($file_count files, $((size_kb / 1024))MB)"
                else
                    echo "  $rel_path ($file_count files, ${size_kb}KB)"
                fi
            done < "$CANDIDATES_FILE"
            echo ""
            echo "Run 'dotfiles review' to adopt."
        fi
    fi
}

main "$@"
