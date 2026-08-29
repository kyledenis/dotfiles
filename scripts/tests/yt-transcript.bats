#!/usr/bin/env bats

# The CLI half needs the network, so these cover the parts that do not:
# argument handling, and the parser that turns json3 into text.

DOTFILES_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPTS_DIR="$DOTFILES_ROOT/scripts"
CLI="$SCRIPTS_DIR/yt-transcript.sh"
PARSER="$SCRIPTS_DIR/lib/yt-transcript-parse.py"
FIXTURE="$SCRIPTS_DIR/tests/fixtures/captions.json3"

setup() {
    TEST_ROOT="$(mktemp -d)"
    export NOTE_FILE="$TEST_ROOT/note"
    export SUB="$FIXTURE"
    export LANG_CODE="en"
    export FORCE_AUTO="false"
    export MODE="text"
    export META='{"en": [{"ext": "json3"}]}
{"title": "Test Talk", "channel": "Test Channel", "duration": 125, "webpage_url": "https://example.com/v"}'
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
    unset NOTE_FILE SUB LANG_CODE FORCE_AUTO MODE META
}

@test "help lists the output modes" {
    run "$CLI" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--timestamps"* ]]
    [[ "$output" == *"--json"* ]]
    [[ "$output" == *"--copy"* ]]
    [[ "$output" == *"--langs"* ]]
}

@test "no argument shows help and fails" {
    run "$CLI"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: yt-transcript"* ]]
}

@test "unknown option is rejected rather than treated as a url" {
    run "$CLI" --nope
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown option"* ]]
}

@test "--out with no filename is rejected" {
    run "$CLI" https://example.com --out
    [ "$status" -eq 1 ]
    [[ "$output" == *"--out needs a filename"* ]]
}

@test "two urls are rejected" {
    run "$CLI" https://a.example https://b.example
    [ "$status" -eq 1 ]
    [[ "$output" == *"one video at a time"* ]]
}

@test "parser drops cues with no segs and whitespace-only cues" {
    MODE=timestamps run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
}

@test "parser joins multi-segment cues into one line" {
    MODE=timestamps run python3 "$PARSER"
    [[ "${lines[0]}" == "[0:01] Hello world." ]]
}

@test "parser collapses newlines inside a cue" {
    MODE=timestamps run python3 "$PARSER"
    [[ "${lines[1]}" == "[0:04] Second cue here." ]]
}

@test "parser starts a new paragraph after a long silence" {
    # Asserted against $output, not $lines: bats collapses the blank separator.
    run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello world. Second cue here.

After a long gap." ]
}

@test "json mode reports the human track when the language is in subtitles" {
    MODE=json run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"source": "human"'* ]]
    [[ "$output" == *'"title": "Test Talk"'* ]]
}

@test "json mode reports auto when the language has no human track" {
    META='NA
{"title": "Test Talk", "channel": "Test Channel", "duration": 125}' MODE=json run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"source": "auto"'* ]]
}

@test "--auto overrides a present human track" {
    FORCE_AUTO=true MODE=json run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"source": "auto"'* ]]
}

@test "note file carries title, duration, source and word count" {
    run python3 "$PARSER"
    [ "$status" -eq 0 ]
    [ -f "$NOTE_FILE" ]
    [ "$(sed -n 1p "$NOTE_FILE")" = "Test Talk" ]
    note="$(sed -n 2p "$NOTE_FILE")"
    [[ "$note" == *"Test Channel"* ]]
    [[ "$note" == *"2:05"* ]]
    [[ "$note" == *"human-written captions"* ]]
    [[ "$note" == *"9 words"* ]]
}

@test "an empty caption file is an error, not empty output" {
    echo '{"events": []}' > "$TEST_ROOT/empty.json3"
    SUB="$TEST_ROOT/empty.json3" run python3 "$PARSER"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no text"* ]]
}

@test "rogue registers the media category" {
    run "$SCRIPTS_DIR/rogue.sh" media
    [ "$status" -eq 0 ]
    [[ "$output" == *"yt-transcript"* ]]
}

@test "rogue lists media in its help" {
    run "$SCRIPTS_DIR/rogue.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"media"* ]]
}
