#!/usr/bin/env bats

load helpers

setup() {
    setup_skills_env
    export SKILLS_PLUGINS_JSON="$SCRIPTS_DIR/tests/fixtures/plugins.json"
}
teardown() {
    unset SKILLS_PLUGINS_JSON
    teardown_skills_env
}

@test "help lists the phase-1 verbs" {
    run "$SCRIPTS_DIR/skills.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"sync"* ]]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"new"* ]]
    [[ "$output" == *"doctor"* ]]
}

@test "sync delegates to the sync engine" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh" sync
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/SKILL.md" ]
}

@test "sync passes flags through to the engine" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh" sync --dry-run
    [ "$status" -eq 0 ]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
}

@test "sync passes --tool through to the engine" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh" sync --tool claude
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/SKILL.md" ]
    [ ! -d "$SKILLS_DEST_CURSOR/alpha" ]
}

@test "list shows the registry" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
}

@test "bare invocation reports status and writes nothing" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MINE"* ]]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
}

@test "status counts the skills in the canonical store" {
    make_skill alpha
    make_skill beta
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 skills"* ]]
}

@test "later-phase verbs exit 2 and point at the spec" {
    run "$SCRIPTS_DIR/skills.sh" update
    [ "$status" -eq 2 ]
    [[ "$output" == *"later phase"* ]]
}

@test "an unknown verb exits 1" {
    run "$SCRIPTS_DIR/skills.sh" nonsense
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}
