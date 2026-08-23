#!/usr/bin/env bash

################################################################################
# skills.sh - one front door for AI agent skills
#
# Three channels, each with its own update mechanism:
#   mine      ~/.skills entries you wrote        — git
#   upstream  ~/.skills entries with a `source:` — skills update  (phase 3)
#   plugins   Claude Code plugins               — claude plugin update
#
# Bare `skills` is read-only. Every mutation takes an explicit verb.
#
# Usage: skills [command] [options]
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/skills-common.sh"
source "$SCRIPT_DIR/lib/skills-plugins.sh"

SPEC_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/docs/superpowers/specs/2026-08-22-skills-cli-design.md"

show_help() {
    cat << 'EOF'
Usage: skills [command] [options]

One front door for AI agent skills across three channels: the skills you
wrote, the ones vendored from someone else's repo, and Claude Code plugins.

Commands:
    (none)          Status across all three channels — read-only
    list, ls        Full registry: name, version, targets
    sync            Distribute ~/.skills to Claude Code and Cursor
    import [name]   Adopt unmanaged skills out of tool directories
    new, create <name>
                    Scaffold a new skill
    help            This message

Sync options:
    --dry-run       Preview without writing any files
    --prune         Remove skills no longer in the canonical store
    --tool NAME     Sync to one tool only (claude, cursor)
    --verbose       Detailed output

Coming in later phases:
    update          Pull every channel forward, with changelogs
    add <repo>      Vendor a skill from a git repo, pinned to a commit
    diff <name>     Show how your fork differs from its upstream
    merge <name>    Three-way merge upstream changes into a fork
    adopt <name>    Record where an already-vendored skill came from
    doctor          Report drift, duplicates and stale forks
    find [query]    Search the ecosystem via `npx skills find`

Environment:
    SKILLS_DIR              canonical store      (default: ~/.skills)
    SKILLS_DEST_CLAUDE      claude destination   (default: ~/.claude/skills)
    SKILLS_DEST_CURSOR      cursor destination   (default: ~/.cursor/skills)

Examples:
    skills                  What do I have, and what has drifted?
    skills sync --dry-run   Preview a sync
    skills new my-skill     Scaffold a skill
EOF
}

# Count skill directories in the canonical store.
count_canonical_skills() {
    local count=0
    local d
    for d in "$SKILLS_DIR"/*/; do
        [ -f "$d/SKILL.md" ] || continue
        count=$((count + 1))
    done
    echo "$count"
}

# MINE row: how many, and what git thinks of the working tree.
status_mine() {
    local count
    count=$(count_canonical_skills)
    printf "  ${BOLD}MINE${NC}       ${DIM}%-32s${NC} %s skills\n" "$SKILLS_DIR" "$count"

    if [ ! -d "$SKILLS_DIR/.git" ]; then
        printf "             ${DIM}not a git repository${NC}\n"
        return
    fi

    local dirty ahead state
    dirty=$(git -C "$SKILLS_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git -C "$SKILLS_DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)

    if [ "$dirty" -eq 0 ]; then
        state="${GREEN}clean${NC}"
    else
        state="${YELLOW}$dirty uncommitted${NC}"
    fi
    if [ "$ahead" -gt 0 ]; then
        state="$state ${DIM}·${NC} ${YELLOW}↑$ahead unpushed${NC}"
    fi
    printf "             %b\n" "$state"
}

# Names listed in ~/.skills/.skills-ignore, one per line, # comments allowed.
# Skills another tool installed belong here so they stop reading as drift.
ignored_skills() {
    local f="$SKILLS_DIR/.skills-ignore"
    [ -f "$f" ] || return 0
    grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' || true
}

# UPSTREAM row. Phase 1 has no provenance yet, so every skill without a
# `source:` block reads as unclassified. Phase 2 fills these in.
status_upstream() {
    local pinned=0 unclassified=0 d src
    for d in "$SKILLS_DIR"/*/; do
        [ -f "$d/SKILL.md" ] || continue
        src=$(read_field "$d/SKILL.md" "source.url")
        if [ -n "$src" ]; then
            pinned=$((pinned + 1))
        else
            unclassified=$((unclassified + 1))
        fi
    done

    printf "  ${BOLD}UPSTREAM${NC}   ${DIM}%-32s${NC} %s pinned\n" "vendored from git" "$pinned"
    if [ "$unclassified" -gt 0 ]; then
        printf "             ${YELLOW}%s unclassified${NC} ${DIM}— run \`skills adopt <name> <repo>\`${NC}\n" "$unclassified"
    fi
}

status_plugins() {
    plugins_supported || return 0
    local snap
    snap=$(plugins_snapshot) || return 0
    [ -n "$snap" ] || return 0

    local total enabled
    total=$(plugins_count "$snap")
    enabled=$(plugins_enabled_count "$snap")
    printf "  ${BOLD}PLUGINS${NC}    ${DIM}%-32s${NC} %s installed\n" "claude" "$total"
    printf "             ${DIM}%s enabled · %s disabled${NC}\n" "$enabled" "$((total - enabled))"
}

# Skills sitting in a tool directory that the canonical store knows nothing
# about — either something else installed them, or you wrote them in place.
status_drift() {
    local ignored names count tool dest d name
    ignored=$(ignored_skills)
    names=""

    for tool in "${TOOLS[@]}"; do
        dest="${TOOL_DEST[$tool]}"
        [ -d "$dest" ] || continue
        for d in "$dest"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            [ -d "$SKILLS_DIR/$name" ] && continue
            echo "$ignored" | grep -qx "$name" && continue
            names="$names$name"$'\n'
        done
    done

    count=$(printf '%s' "$names" | sort -u | grep -c . || true)
    [ -z "$count" ] && count=0
    [ "$count" -eq 0 ] && return 0

    printf "  ${BOLD}DRIFT${NC}      ${YELLOW}%s unmanaged${NC} ${DIM}in tool directories — \`skills import\`${NC}\n" "$count"
}

cmd_status() {
    echo ""
    status_mine
    echo ""
    status_upstream
    echo ""
    status_plugins
    echo ""
    local drift
    drift=$(status_drift)
    if [ -n "$drift" ]; then
        printf '%s\n' "$drift"
        echo ""
    fi
    printf "  ${DIM}skills sync · list · help${NC}\n"
    echo ""
}

cmd_list()   { exec "$SCRIPT_DIR/skills-sync.sh" --list; }
cmd_sync()   { exec "$SCRIPT_DIR/skills-sync.sh" "$@"; }
cmd_import() { exec "$SCRIPT_DIR/skills-sync.sh" --import "$@"; }
cmd_new()    { exec "$SCRIPT_DIR/skills-create.sh" "$@"; }

not_yet() {
    print_error "\`skills $1\` arrives in a later phase."
    echo "  Design: $SPEC_PATH"
    exit 2
}

COMMAND="${1:-status}"
[ $# -gt 0 ] && shift

case "$COMMAND" in
    status)                       cmd_status "$@" ;;
    list|ls)                      cmd_list ;;
    sync)                         cmd_sync "$@" ;;
    import)                       cmd_import "$@" ;;
    new|create)                   cmd_new "$@" ;;
    update|add|diff|merge|adopt|doctor|find)
                                  not_yet "$COMMAND" ;;
    help|--help|-h)               show_help ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo "Run 'skills help' for usage"
        exit 1
        ;;
esac
