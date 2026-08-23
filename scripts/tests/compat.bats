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

@test "bare skills-sync still syncs, with a deprecation notice" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-compat.sh"
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/SKILL.md" ]
    [[ "$output" == *"now \`skills\`"* ]]
}

@test "--list maps onto the list verb" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-compat.sh" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
}

@test "sync flags survive the mapping" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-compat.sh" --dry-run
    [ "$status" -eq 0 ]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
}

@test "--tool and its value both survive the mapping" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills-compat.sh" --tool claude
    [ "$status" -eq 0 ]
    [ -f "$SKILLS_DEST_CLAUDE/alpha/SKILL.md" ]
    [ ! -d "$SKILLS_DEST_CURSOR/alpha" ]
}

@test "--import maps onto the import verb" {
    run "$SCRIPTS_DIR/skills-compat.sh" --import --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"now \`skills\`"* ]]
    [[ "$output" == *"Running \`skills import --dry-run\`"* ]]
}

@test "--prune is passed through to sync" {
    make_skill alpha
    "$SCRIPTS_DIR/skills-compat.sh" >/dev/null
    rm -rf "$SKILLS_DIR/alpha"
    run "$SCRIPTS_DIR/skills-compat.sh" --prune
    [ "$status" -eq 0 ]
    [ ! -d "$SKILLS_DEST_CLAUDE/alpha" ]
}
