#!/usr/bin/env bats

load helpers

setup() {
    setup_skills_env
    export SKILLS_PLUGINS_JSON="$SCRIPTS_DIR/tests/fixtures/plugins.json"
    source "$SCRIPTS_DIR/lib/skills-plugins.sh"
}
teardown() {
    unset SKILLS_PLUGINS_JSON
    teardown_skills_env
}

@test "plugins_snapshot reads the fixture instead of shelling out" {
    run plugins_snapshot
    [ "$status" -eq 0 ]
    [[ "$output" == *"superpowers@claude-plugins-official"* ]]
}

@test "plugins_count totals every installed plugin" {
    run plugins_count "$(plugins_snapshot)"
    [ "$output" = "5" ]
}

@test "plugins_enabled_count counts only enabled plugins" {
    run plugins_enabled_count "$(plugins_snapshot)"
    [ "$output" = "3" ]
}

@test "plugins_user_ids excludes project-scoped plugins" {
    run plugins_user_ids "$(plugins_snapshot)"
    [[ "$output" == *"superpowers@claude-plugins-official"* ]]
    [[ "$output" != *"ralph-wiggum"* ]]
}

@test "plugins_supported succeeds when a fixture is set" {
    run plugins_supported
    [ "$status" -eq 0 ]
}

@test "plugins_snapshot fails cleanly when the fixture is missing" {
    export SKILLS_PLUGINS_JSON="$TEST_ROOT/does-not-exist.json"
    run plugins_snapshot
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}

@test "plugins_supported fails when the fixture is missing" {
    export SKILLS_PLUGINS_JSON="$TEST_ROOT/does-not-exist.json"
    run plugins_supported
    [ "$status" -ne 0 ]
}
