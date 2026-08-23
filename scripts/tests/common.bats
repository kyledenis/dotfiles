#!/usr/bin/env bats

load helpers

setup() {
    setup_skills_env
    source "$SCRIPTS_DIR/lib/skills-common.sh"
}
teardown() { teardown_skills_env; }

@test "read_field reads a frontmatter value" {
    make_skill alpha
    run read_field "$SKILLS_DIR/alpha/SKILL.md" "name"
    [ "$output" = "alpha" ]
}

@test "read_field returns empty for a missing field" {
    make_skill alpha
    run read_field "$SKILLS_DIR/alpha/SKILL.md" "nonexistent"
    [ "$output" = "" ]
}

@test "read_targets returns the declared tools" {
    make_skill alpha
    run read_targets "$SKILLS_DIR/alpha/SKILL.md"
    [ "$output" = "claude cursor" ]
}

@test "read_targets defaults to all when the field is absent" {
    mkdir -p "$SKILLS_DIR/bare"
    printf -- '---\nname: bare\ndescription: no targets\n---\n\nbody\n' \
        > "$SKILLS_DIR/bare/SKILL.md"
    run read_targets "$SKILLS_DIR/bare/SKILL.md"
    [ "$output" = "all" ]
}

@test "read_category defaults to general" {
    mkdir -p "$SKILLS_DIR/bare"
    printf -- '---\nname: bare\ndescription: no category\n---\n\nbody\n' \
        > "$SKILLS_DIR/bare/SKILL.md"
    run read_category "$SKILLS_DIR/bare/SKILL.md"
    [ "$output" = "general" ]
}

@test "extract_body returns markdown without the frontmatter" {
    make_skill alpha "Distinctive body sentence."
    run extract_body "$SKILLS_DIR/alpha/SKILL.md"
    [[ "$output" == *"Distinctive body sentence."* ]]
    [[ "$output" != *"description:"* ]]
}

@test "transform_frontmatter keeps only the allowed fields" {
    make_skill alpha
    run transform_frontmatter "$SKILLS_DIR/alpha/SKILL.md" "name description"
    [[ "$output" == *"name: alpha"* ]]
    [[ "$output" != *"targets:"* ]]
    [[ "$output" != *"version:"* ]]
}

@test "hash_skill_dir changes when content changes" {
    make_skill alpha
    local first
    first=$(hash_skill_dir "$SKILLS_DIR/alpha")
    echo "extra line" >> "$SKILLS_DIR/alpha/SKILL.md"
    local second
    second=$(hash_skill_dir "$SKILLS_DIR/alpha")
    [ "$first" != "$second" ]
}

@test "hash_skill_dir is stable across repeated calls" {
    make_skill alpha
    [ "$(hash_skill_dir "$SKILLS_DIR/alpha")" = "$(hash_skill_dir "$SKILLS_DIR/alpha")" ]
}

@test "TOOL_DEST honours the environment overrides" {
    [ "${TOOL_DEST[claude]}" = "$SKILLS_DEST_CLAUDE" ]
    [ "${TOOL_DEST[cursor]}" = "$SKILLS_DEST_CURSOR" ]
}
