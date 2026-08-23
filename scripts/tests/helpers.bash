#!/usr/bin/env bash
# Shared setup for skills bats tests.
#
# Every test runs against a throwaway tree — never the real ~/.skills
# or the real tool directories.

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$DOTFILES_ROOT/scripts"

# Fuse. This runs at `load helpers` time, before any test body, so a test that
# forgets to call setup_skills_env still cannot reach the real ~/.skills or the
# real tool directories. Without it, one forgotten setup silently deletes the
# user's installed skills — which is exactly how this file came to exist.
: "${BATS_FILE_TMPDIR:=$(mktemp -d)}"
export SKILLS_DIR="$BATS_FILE_TMPDIR/fallback-skills"
export SKILLS_DEST_CLAUDE="$BATS_FILE_TMPDIR/fallback-claude"
export SKILLS_DEST_CURSOR="$BATS_FILE_TMPDIR/fallback-cursor"

setup_skills_env() {
    TEST_ROOT="$(mktemp -d)"
    export SKILLS_DIR="$TEST_ROOT/skills"
    export SKILLS_DEST_CLAUDE="$TEST_ROOT/claude"
    export SKILLS_DEST_CURSOR="$TEST_ROOT/cursor"
    mkdir -p "$SKILLS_DIR" "$SKILLS_DEST_CLAUDE" "$SKILLS_DEST_CURSOR"
}

teardown_skills_env() {
    if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
}

# make_skill <name> [body]
# Writes a well-formed skill into the canonical store.
make_skill() {
    local name="$1"
    local body="${2:-Body text for $name.}"
    mkdir -p "$SKILLS_DIR/$name"
    cat > "$SKILLS_DIR/$name/SKILL.md" <<EOF
---
name: $name
description: Test skill $name
version: "1.0"
targets: [claude, cursor]
category: general
---

# $name

$body
EOF
}
