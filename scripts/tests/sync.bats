#!/usr/bin/env bats

load helpers

setup() { setup_skills_env; }
teardown() { teardown_skills_env; }

@test "sync writes a skill to both tool destinations" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-sync.sh"
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/SKILL.md" ]
    [ -f "$SKILLS_DEST_CURSOR/alpha/SKILL.md" ]
}

@test "sync filters frontmatter to each tool's allowed fields" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-sync.sh"
    [ "$status" -eq 0 ]

    # claude keeps name/description/version, drops targets/category
    run grep -c '^version:' "$SKILLS_DEST_CLAUDE/alpha/SKILL.md"
    [ "$output" = "1" ]
    run grep -c '^targets:' "$SKILLS_DEST_CLAUDE/alpha/SKILL.md"
    [ "$output" = "0" ]

    # cursor keeps only name/description
    run grep -c '^version:' "$SKILLS_DEST_CURSOR/alpha/SKILL.md"
    [ "$output" = "0" ]
}

@test "sync preserves supporting files alongside SKILL.md" {
    make_skill alpha
    mkdir -p "$SKILLS_DIR/alpha/references"
    echo "reference material" > "$SKILLS_DIR/alpha/references/notes.md"
    run "$SCRIPTS_DIR/skills-sync.sh"
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/references/notes.md" ]
}

@test "sync writes a manifest naming what it manages" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-sync.sh"
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/.skills-sync.json" ]
    run yq -p json '.skills | keys | .[]' "$SKILLS_DEST_CLAUDE/.skills-sync.json"
    [[ "$output" == *"alpha"* ]]
}

@test "prune removes managed skills but never foreign ones" {
    # This invariant is what lets `npx skills` and `skills sync` share
    # ~/.claude/skills without eating each other's files. Do not break it.
    make_skill alpha
    "$SCRIPTS_DIR/skills-sync.sh" >/dev/null

    mkdir -p "$SKILLS_DEST_CLAUDE/foreign"
    echo "installed by another tool" > "$SKILLS_DEST_CLAUDE/foreign/SKILL.md"

    rm -rf "$SKILLS_DIR/alpha"
    run "$SCRIPTS_DIR/skills-sync.sh" --prune
    [ "$status" -eq 0 ]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
    [ -f "$SKILLS_DEST_CLAUDE/foreign/SKILL.md" ]
}

@test "targets frontmatter restricts which tools receive a skill" {
    make_skill beta
    # rewrite targets to claude only
    yq -i '.targets = ["claude"]' --front-matter=process "$SKILLS_DIR/beta/SKILL.md"
    run "$SCRIPTS_DIR/skills-sync.sh"
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/beta/SKILL.md" ]
    [ ! -d "$SKILLS_DEST_CURSOR/beta" ]
}

@test "dry-run writes nothing" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-sync.sh" --dry-run
    [ "$status" -eq 0 ]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
}
