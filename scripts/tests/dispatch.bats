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

@test "status reports the plugin channel from the fixture" {
    make_skill alpha
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"PLUGINS"* ]]
    [[ "$output" == *"5 installed"* ]]
    [[ "$output" == *"3 enabled"* ]]
}

@test "status reports skills with no source pin as unclassified" {
    make_skill alpha
    make_skill beta
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"UPSTREAM"* ]]
    [[ "$output" == *"2 unclassified"* ]]
}

@test "status counts unmanaged skills in tool directories as drift" {
    make_skill alpha
    mkdir -p "$SKILLS_DEST_CLAUDE/foreign"
    echo "x" > "$SKILLS_DEST_CLAUDE/foreign/SKILL.md"
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRIFT"* ]]
    [[ "$output" == *"1 unmanaged"* ]]
}

@test "skills listed in .skills-ignore are not counted as drift" {
    make_skill alpha
    mkdir -p "$SKILLS_DEST_CLAUDE/foreign"
    echo "x" > "$SKILLS_DEST_CLAUDE/foreign/SKILL.md"
    printf '# installed by another tool\nforeign\n' > "$SKILLS_DIR/.skills-ignore"
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" != *"unmanaged"* ]]
}

@test "status omits the plugin row when the channel is unavailable" {
    make_skill alpha
    export SKILLS_PLUGINS_JSON="/nonexistent/plugins.json"
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"MINE"* ]]
    [[ "$output" != *"installed"* ]]
}

@test "status counts a skill unmanaged in two tools only once" {
    make_skill alpha
    mkdir -p "$SKILLS_DEST_CLAUDE/foreign" "$SKILLS_DEST_CURSOR/foreign"
    echo "x" > "$SKILLS_DEST_CLAUDE/foreign/SKILL.md"
    echo "x" > "$SKILLS_DEST_CURSOR/foreign/SKILL.md"
    run "$SCRIPTS_DIR/skills.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 unmanaged"* ]]
}
