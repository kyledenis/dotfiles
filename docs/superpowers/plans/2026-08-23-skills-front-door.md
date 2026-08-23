# Skills Front Door — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `skills-sync` with a `skills` command that reports across all three skill channels and dispatches to the right one, with behaviour identical to today's sync.

**Architecture:** A thin dispatcher (`scripts/skills.sh`) fronts the existing sync engine (`scripts/skills-sync.sh`), sharing helpers through `scripts/lib/skills-common.sh`. Bare `skills` prints a read-only dashboard; every mutation takes an explicit verb. Phase 1 adds no new behaviour to sync itself — it reorganises, adds test seams, and moves the user-facing surface.

**Tech Stack:** bash, `yq` v4, `bats-core` for tests, `claude` CLI (read-only), GNU-less macOS coreutils.

**Spec:** `docs/superpowers/specs/2026-08-22-skills-cli-design.md`

## Global Constraints

- Scripts are `#!/usr/bin/env bash`. macOS ships bash 3.2 — no associative-array-in-function tricks beyond what `skills-sync.sh` already uses, no `${var,,}`, no `mapfile`.
- `yq` is v4 (`v4.52.4`). Frontmatter is read through `yq eval`, never regex-parsed beyond locating the `---` delimiters.
- Do **not** use `set -u`. The existing scripts don't, and `"${arr[@]}"` on an empty array breaks under it on bash 3.2.
- The pre-commit hook enforces: `bash -n` syntax check on every staged `.sh`, no trailing whitespace, no `.DS_Store`, no large files. It *warns* if a `.sh` is not executable. Run `chmod +x` on new executables; leave `lib/*.sh` non-executable (they are sourced) and accept the warning.
- Commits use conventional format `type(scope): description`. No "Generated with Claude Code", no `Co-Authored-By`. The harness appends its own session trailer — don't hand-write one.
- Tests must never touch `$HOME/.skills`, `$HOME/.claude/skills` or `$HOME/.cursor/skills`. Every test runs against `mktemp -d` via the env overrides added in Task 1.
- **Never run a `.bats` file that can write, before the destination overrides exist.** The RED phase of Task 1 uses a `--dry-run` probe precisely because running the real suite against hardcoded destinations deletes the user's live skill directories. This happened once. The suite runs only after Step 5.
- Phase 1 is behaviour-identical for sync. If a test that passes against today's `skills-sync.sh` fails after a refactor, the refactor is wrong.
- Work happens on branch `feat/skills-front-door`, already created, with the spec committed at `f1f0169`.

### Deviations from the spec, deliberate

1. **`--import` stays inside `skills-sync.sh`.** The spec's file table moves it out but gives it no home file. `skills import` delegates to `skills-sync.sh --import` instead. The user-facing surface is exactly as specified; only the internal carve-up is deferred. Same for `--list` → `skills list`.
2. **The UPSTREAM row reads "27 unclassified", not "18".** The spec's Phase 1 description says 18, but Phase 1 has no provenance data — it can only count skills lacking a `source:` block, which is all 27. Distinguishing the ~9 you wrote is exactly what Phase 2 establishes.

---

### Task 1: Test harness and destination seams

Nothing in this repo is tested. Before refactoring a 26KB script that writes into `~/.claude/skills`, build the net — and the only reason it isn't testable today is that the two destination paths are hardcoded.

**Files:**
- Create: `scripts/tests/helpers.bash`
- Create: `scripts/tests/sync.bats`
- Modify: `scripts/skills-sync.sh:59-66` (destination env overrides)

**Interfaces:**
- Consumes: nothing
- Produces: `setup_skills_env()`, `teardown_skills_env()`, `make_skill <name> [body]` in `scripts/tests/helpers.bash`. Env contract: `SKILLS_DIR`, `SKILLS_DEST_CLAUDE`, `SKILLS_DEST_CURSOR` override the canonical store and both tool destinations.

- [ ] **Step 1: Install bats**

```bash
brew install bats-core
bats --version
```

Expected: `Bats 1.x.x`.

- [ ] **Step 2: Write the test helper**

Create `scripts/tests/helpers.bash`:

```bash
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
```

- [ ] **Step 3: Write the failing tests**

Create `scripts/tests/sync.bats`:

```bash
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
    run yq -p json -o json '.skills | keys | .[]' "$SKILLS_DEST_CLAUDE/.skills-sync.json"
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
```

- [ ] **Step 4: Prove the override is not yet honoured — without writing anything**

Do **not** run `bats scripts/tests/sync.bats` yet. The destinations are still
hardcoded, so the suite's `--prune` test would run against the real
`~/.claude/skills` and delete every managed skill in it. Use `--dry-run`, which
writes nothing, as the RED probe instead:

```bash
T=$(mktemp -d)
mkdir -p "$T/skills/alpha"
printf -- '---\nname: alpha\ndescription: probe\nversion: "1.0"\ntargets: [claude, cursor]\ncategory: general\n---\n\nbody\n' \
    > "$T/skills/alpha/SKILL.md"

SKILLS_DIR="$T/skills" \
SKILLS_DEST_CLAUDE="$T/claude" \
SKILLS_DEST_CURSOR="$T/cursor" \
    ./scripts/skills-sync.sh --dry-run | grep "Would create"
```

Expected: the destination paths printed are under **`$HOME/.claude/skills`** and
`$HOME/.cursor/skills`, *not* under `$T`. That is the RED — the script ignores
`SKILLS_DEST_*`. Keep `$T` for Step 6; `--dry-run` created nothing inside it.

- [ ] **Step 5: Add the destination overrides**

In `scripts/skills-sync.sh`, replace the two hardcoded destination assignments (around L59-66):

```bash
TOOL_DEST[claude]="$HOME/.claude/skills"
```
```bash
TOOL_DEST[cursor]="$HOME/.cursor/skills"
```

with:

```bash
TOOL_DEST[claude]="${SKILLS_DEST_CLAUDE:-$HOME/.claude/skills}"
```
```bash
TOOL_DEST[cursor]="${SKILLS_DEST_CURSOR:-$HOME/.cursor/skills}"
```

Leave `TOOL_LAYOUT` and `TOOL_FIELDS` untouched.

- [ ] **Step 6: Re-run the probe, then run the suite**

First confirm the seam works, still without writing:

```bash
SKILLS_DIR="$T/skills" \
SKILLS_DEST_CLAUDE="$T/claude" \
SKILLS_DEST_CURSOR="$T/cursor" \
    ./scripts/skills-sync.sh --dry-run | grep "Would create"
```

Expected: destinations now under `$T`. That is the GREEN for the seam, and the
proof that it is safe to run the suite.

Now run it:

Run: `bats scripts/tests/sync.bats`
Expected: 7 tests, all PASS.

Then confirm nothing leaked into the real directories:

```bash
ls ~/.claude/skills | wc -l   # expect 37
ls ~/.cursor/skills | wc -l   # expect 35
```

- [ ] **Step 7: Confirm the real sync still works**

Run: `./scripts/skills-sync.sh --dry-run`
Expected: reports against your real 27 skills, writes nothing. This proves the `:-` defaults are correct.

- [ ] **Step 8: Commit**

```bash
chmod +x scripts/tests/sync.bats
git add scripts/tests/helpers.bash scripts/tests/sync.bats scripts/skills-sync.sh
git commit -m "test(skills): characterise sync behaviour with overridable destinations"
```

---

### Task 2: Extract the shared library

Four new files need this script's frontmatter and manifest helpers. Extracting them is a prerequisite, not tidying — and Task 1's tests prove the extraction changed nothing.

**Files:**
- Create: `scripts/lib/skills-common.sh`
- Modify: `scripts/skills-sync.sh` (delete the extracted blocks, source the library)
- Test: `scripts/tests/common.bats`

**Interfaces:**
- Consumes: `SKILLS_DIR`, `SKILLS_DEST_CLAUDE`, `SKILLS_DEST_CURSOR` from Task 1.
- Produces, all sourced from `scripts/lib/skills-common.sh`:
  - Colour vars `RED GREEN YELLOW BLUE CYAN BOLD DIM NC`
  - `print_success/print_error/print_warning/print_info/print_step/print_verbose <msg>`
  - `extract_frontmatter <file>` → YAML on stdout
  - `extract_body <file>` → markdown on stdout
  - `read_field <file> <field>` → string
  - `read_targets <file>` → space-separated tools, or `all`
  - `read_category <file>` → string, default `general`
  - `transform_frontmatter <file> <allowed-fields>` → `---`-delimited YAML
  - `hash_skill_dir <dir>` → sha256 hex
  - `read_manifest <tool>` / `manifest_hash <json> <name>` / `manifest_tool_hash <json> <name>` / `write_manifest <tool> <json>`
  - Arrays `TOOL_DEST TOOL_LAYOUT TOOL_FIELDS` and `TOOLS`
  - `MANIFEST_NAME=".skills-sync.json"`

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/common.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats scripts/tests/common.bats`
Expected: FAIL — `scripts/lib/skills-common.sh` does not exist.

- [ ] **Step 3: Create the library**

Create `scripts/lib/skills-common.sh`. **Move** — do not retype — these blocks out of `scripts/skills-sync.sh`, preserving their bodies exactly:

- the colour definitions (`RED` … `NC`, currently ~L22-29)
- `SKILLS_DIR` and `MANIFEST_NAME` (~L34-35)
- the Tool Definitions block: `declare -A TOOL_DEST TOOL_LAYOUT TOOL_FIELDS`, all nine assignments, and `TOOLS=(claude cursor)` (~L57-69), with the Task 1 overrides intact
- `print_success` `print_error` `print_warning` `print_info` `print_step` `print_verbose` (~L75-99)
- `extract_frontmatter` `extract_body` `read_field` `read_targets` `read_category` `transform_frontmatter` `hash_skill_dir` (~L207-280)
- `read_manifest` `manifest_hash` `manifest_tool_hash` `write_manifest` (~L287-325)

Prepend this header, and make the two variables that the moved functions read from their caller safe to source standalone:

```bash
#!/usr/bin/env bash
################################################################################
# skills-common.sh - shared helpers for the skills commands
#
# Sourced, not executed. Provides frontmatter parsing, content hashing,
# per-tool destination config, manifest I/O and print helpers to
# skills.sh and skills-sync.sh.
#
# Environment:
#   SKILLS_DIR           canonical store        (default: ~/.skills)
#   SKILLS_DEST_CLAUDE   claude destination     (default: ~/.claude/skills)
#   SKILLS_DEST_CURSOR   cursor destination     (default: ~/.cursor/skills)
################################################################################

# print_verbose and write_manifest read these from their caller.
# Default them so this library can be sourced on its own.
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
```

- [ ] **Step 4: Source the library from the sync engine**

In `scripts/skills-sync.sh`, immediately after `set -e`, insert:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/skills-common.sh"
```

Delete the now-duplicated `SCRIPT_DIR` assignment further down. Leave the Options block (`DRY_RUN=false` … `TOOL_FILTER=""`) and the Counters block in place — they are assigned *after* the source, so they override the library defaults, which is correct.

- [ ] **Step 5: Run both test files to verify they pass**

Run: `bats scripts/tests/`
Expected: 17 tests, all PASS. `sync.bats` passing unchanged is the proof that the extraction was behaviour-preserving.

- [ ] **Step 6: Verify syntax and real-world behaviour**

```bash
bash -n scripts/skills-sync.sh scripts/lib/skills-common.sh
./scripts/skills-sync.sh --dry-run
./scripts/skills-sync.sh --list
```

Expected: no syntax errors; dry-run reports on the real 27 skills; `--list` prints the registry.

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/skills-common.sh scripts/skills-sync.sh scripts/tests/common.bats
git commit -m "refactor(skills): extract shared helpers into lib/skills-common.sh"
```

---

### Task 3: Read the plugins channel

The dashboard needs plugin counts. `claude plugin list --json` is the only source, and it must be behind a seam so tests never shell out to it.

**Files:**
- Create: `scripts/lib/skills-plugins.sh`
- Create: `scripts/tests/fixtures/plugins.json`
- Test: `scripts/tests/plugins.bats`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, sourced from `scripts/lib/skills-plugins.sh`:
  - `plugins_supported()` → exit 0 if the `claude` CLI is available or a fixture is set
  - `plugins_snapshot()` → the plugin list JSON on stdout; exit 1 if unavailable
  - `plugins_count <json>` → total installed
  - `plugins_enabled_count <json>` → enabled count
  - `plugins_user_ids <json>` → newline-separated ids with `scope == "user"`
  - Env seam: `SKILLS_PLUGINS_JSON` — path to a fixture file, used instead of invoking `claude`

- [ ] **Step 1: Create the fixture**

Create `scripts/tests/fixtures/plugins.json`. Five entries, shaped exactly like real `claude plugin list --json` output:

```json
[
  {
    "id": "superpowers@claude-plugins-official",
    "version": "6.3.0",
    "scope": "user",
    "enabled": true,
    "installPath": "/tmp/fixture/superpowers/6.3.0",
    "installedAt": "2026-03-31T19:09:48.628Z",
    "lastUpdated": "2026-08-13T13:57:41.479Z"
  },
  {
    "id": "figma@claude-plugins-official",
    "version": "2.2.96",
    "scope": "user",
    "enabled": true,
    "installPath": "/tmp/fixture/figma/2.2.96",
    "installedAt": "2025-12-30T00:13:07.813Z",
    "lastUpdated": "2026-08-21T10:57:30.396Z"
  },
  {
    "id": "atlassian@claude-plugins-official",
    "version": "94a30436435f",
    "scope": "user",
    "enabled": false,
    "installPath": "/tmp/fixture/atlassian/94a30436435f",
    "installedAt": "2026-05-29T12:42:56.405Z",
    "lastUpdated": "2026-08-01T07:10:10.466Z",
    "mcpServers": {
      "atlassian": { "type": "http", "url": "https://example.invalid/mcp" }
    }
  },
  {
    "id": "hookify@claude-plugins-official",
    "version": "unknown",
    "scope": "user",
    "enabled": false,
    "installPath": "/tmp/fixture/hookify/unknown",
    "installedAt": "2025-12-30T00:16:09.130Z",
    "lastUpdated": "2026-08-22T05:00:21.461Z"
  },
  {
    "id": "ralph-wiggum@claude-plugins-official",
    "version": "dbc4a7733cd4",
    "scope": "project",
    "projectPath": "/tmp/fixture-project",
    "installPath": "/tmp/fixture/ralph-wiggum/dbc4a7733cd4",
    "enabled": true,
    "installedAt": "2025-12-30T06:29:14.737Z",
    "lastUpdated": "2026-03-24T22:15:00.486Z"
  }
]
```

- [ ] **Step 2: Write the failing test**

Create `scripts/tests/plugins.bats`:

```bash
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bats scripts/tests/plugins.bats`
Expected: FAIL — `scripts/lib/skills-plugins.sh` does not exist.

- [ ] **Step 4: Write the library**

Create `scripts/lib/skills-plugins.sh`:

```bash
#!/usr/bin/env bash
################################################################################
# skills-plugins.sh - read the Claude Code plugin channel
#
# Sourced, not executed. Plugins are read-only to `skills` in phase 1;
# `claude plugin update` is driven from `skills update` in a later phase.
#
# Environment:
#   SKILLS_PLUGINS_JSON  path to a JSON fixture, used instead of invoking
#                        the claude CLI. Test seam only.
################################################################################

# True when we have some way to read the plugin list.
plugins_supported() {
    if [ -n "$SKILLS_PLUGINS_JSON" ]; then
        [ -f "$SKILLS_PLUGINS_JSON" ]
        return $?
    fi
    command -v claude >/dev/null 2>&1
}

# Emit the plugin list as JSON. Non-zero when unavailable.
plugins_snapshot() {
    if [ -n "$SKILLS_PLUGINS_JSON" ]; then
        if [ -f "$SKILLS_PLUGINS_JSON" ]; then
            cat "$SKILLS_PLUGINS_JSON"
            return 0
        fi
        return 1
    fi
    command -v claude >/dev/null 2>&1 || return 1
    claude plugin list --json 2>/dev/null
}

plugins_count() {
    echo "$1" | yq -p json '. | length' - 2>/dev/null || echo 0
}

plugins_enabled_count() {
    echo "$1" | yq -p json '[.[] | select(.enabled == true)] | length' - 2>/dev/null || echo 0
}

# Ids of user-scoped plugins, one per line. These are the ones
# `skills update` will drive in a later phase — project-scoped plugins
# belong to their project, not to this machine's configuration.
plugins_user_ids() {
    echo "$1" | yq -p json '.[] | select(.scope == "user") | .id' - 2>/dev/null
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bats scripts/tests/plugins.bats`
Expected: 7 tests, all PASS.

- [ ] **Step 6: Verify against the real CLI**

```bash
source scripts/lib/skills-plugins.sh
snap=$(plugins_snapshot) && echo "installed: $(plugins_count "$snap"), enabled: $(plugins_enabled_count "$snap")"
```

Expected: `installed: 35, enabled: 22` on this machine today. A different number is fine — a *zero* means `plugins_snapshot` is broken.

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/skills-plugins.sh scripts/tests/plugins.bats scripts/tests/fixtures/plugins.json
git commit -m "feat(skills): read the claude plugin channel behind a test seam"
```

---

### Task 4: The dispatcher

**Files:**
- Create: `scripts/skills.sh`
- Test: `scripts/tests/dispatch.bats`

**Interfaces:**
- Consumes: `lib/skills-common.sh` (Task 2), `lib/skills-plugins.sh` (Task 3).
- Produces: `scripts/skills.sh` accepting `status list sync import new update add diff merge adopt doctor find help`. Later-phase verbs exit 2 with a pointer to the spec. `cmd_status()` is defined here as the MINE row only; Task 5 extends it.

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/dispatch.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats scripts/tests/dispatch.bats`
Expected: FAIL — `scripts/skills.sh` does not exist.

- [ ] **Step 3: Write the dispatcher**

Create `scripts/skills.sh`:

```bash
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

SPEC_PATH="docs/superpowers/specs/2026-08-22-skills-cli-design.md"

show_help() {
    cat << 'EOF'
Usage: skills [command] [options]

One front door for AI agent skills across three channels: the skills you
wrote, the ones vendored from someone else's repo, and Claude Code plugins.

Commands:
    (none)          Status across all three channels — read-only
    list            Full registry: name, version, targets
    sync            Distribute ~/.skills to Claude Code and Cursor
    import [name]   Adopt unmanaged skills out of tool directories
    new <name>      Scaffold a new skill
    doctor          Report drift, duplicates and stale forks
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

cmd_status() {
    echo ""
    status_mine
    echo ""
    printf "  ${DIM}skills sync · list · doctor${NC}\n"
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
```

Note `doctor` is listed in `show_help` but routed to `not_yet` — it is a Phase 4 verb. The test asserts help *mentions* it, and that `update` exits 2; both hold.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats scripts/tests/dispatch.bats`
Expected: 9 tests, all PASS.

- [ ] **Step 5: Run the whole suite**

Run: `bats scripts/tests/`
Expected: 33 tests, all PASS.

- [ ] **Step 6: Try it against the real store**

```bash
chmod +x scripts/skills.sh
./scripts/skills.sh
./scripts/skills.sh help
./scripts/skills.sh sync --dry-run
```

Expected: status shows 27 skills and the real git state of `~/.skills` (6 uncommitted today); help renders; dry-run writes nothing.

- [ ] **Step 7: Commit**

```bash
git add scripts/skills.sh scripts/tests/dispatch.bats
git commit -m "feat(skills): add the skills front-door dispatcher"
```

---

### Task 5: The dashboard

**Files:**
- Modify: `scripts/skills.sh` (add `status_upstream`, `status_plugins`, `status_drift`; extend `cmd_status`)
- Modify: `scripts/tests/dispatch.bats` (add dashboard tests)

**Interfaces:**
- Consumes: `plugins_supported/plugins_snapshot/plugins_count/plugins_enabled_count` (Task 3), `TOOL_DEST`/`TOOLS`/`read_field` (Task 2), `count_canonical_skills` (Task 4).
- Produces: `~/.skills/.skills-ignore` as a supported file — newline-delimited skill names, `#` comments, excluded from the drift count.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/dispatch.bats`:

```bash
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
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats scripts/tests/dispatch.bats`
Expected: the 5 new tests FAIL; the original 9 still PASS.

- [ ] **Step 3: Implement the remaining rows**

In `scripts/skills.sh`, insert these functions after `status_mine`:

```bash
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
    local ignored unmanaged=0 tool dest d name
    ignored=$(ignored_skills)

    for tool in "${TOOLS[@]}"; do
        dest="${TOOL_DEST[$tool]}"
        [ -d "$dest" ] || continue
        for d in "$dest"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            [ -d "$SKILLS_DIR/$name" ] && continue
            echo "$ignored" | grep -qx "$name" && continue
            unmanaged=$((unmanaged + 1))
        done
    done

    [ "$unmanaged" -eq 0 ] && return 0
    printf "  ${BOLD}DRIFT${NC}      ${YELLOW}%s unmanaged${NC} ${DIM}in tool directories — \`skills import\`${NC}\n" "$unmanaged"
}
```

Then replace `cmd_status` with:

```bash
cmd_status() {
    echo ""
    status_mine
    echo ""
    status_upstream
    echo ""
    status_plugins
    echo ""
    status_drift
    printf "  ${DIM}skills sync · list · doctor${NC}\n"
    echo ""
}
```

Note `read_field "$d/SKILL.md" "source.url"` works because `read_field` interpolates the field into a `yq` path expression — a dotted field reads a nested key with no change to the helper.

- [ ] **Step 4: Run to verify they pass**

Run: `bats scripts/tests/dispatch.bats`
Expected: 14 tests, all PASS.

- [ ] **Step 5: Run the whole suite and eyeball the real thing**

```bash
bats scripts/tests/
./scripts/skills.sh
```

Expected: 38 tests PASS. Against the real store: 27 skills, 0 pinned / 27 unclassified, 35 plugins (22 enabled / 13 disabled), and 11 unmanaged in the drift row.

- [ ] **Step 6: Commit**

```bash
git add scripts/skills.sh scripts/tests/dispatch.bats
git commit -m "feat(skills): report all three channels in the status dashboard"
```

---

### Task 6: Shell wiring and deprecation shims

**Files:**
- Create: `scripts/skills-compat.sh`
- Modify: `stow/zsh/.config/zsh/functions.zsh:1373-1382` (function definitions)
- Modify: `stow/zsh/.config/zsh/functions.zsh:525-531` (the `dotfiles` dispatcher)
- Test: `scripts/tests/compat.bats`

**Interfaces:**
- Consumes: `scripts/skills.sh` (Task 4).
- Produces: shell functions `skills`, `skills-sync` (deprecated), `skills-create` (deprecated); `dotfiles skills <args>` routing.

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/compat.bats`:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats scripts/tests/compat.bats`
Expected: FAIL — `scripts/skills-compat.sh` does not exist.

- [ ] **Step 3: Write the shim**

Create `scripts/skills-compat.sh`:

```bash
#!/usr/bin/env bash

################################################################################
# skills-compat.sh - deprecation shim for `skills-sync`
#
# Maps the old flag-driven surface onto `skills` verbs so muscle memory
# and any old scripts keep working. This shim is permanent and harmless;
# `skills` is the command.
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERB="sync"
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --list)   VERB="list" ;;
        --import) VERB="import" ;;
        *)        ARGS+=("$arg") ;;
    esac
done

printf '\033[1;33m⚠\033[0m skills-sync is now `skills`. Running `skills %s %s`.\n' \
    "$VERB" "${ARGS[*]}" >&2

if [ ${#ARGS[@]} -eq 0 ]; then
    exec "$SCRIPT_DIR/skills.sh" "$VERB"
fi
exec "$SCRIPT_DIR/skills.sh" "$VERB" "${ARGS[@]}"
```

The empty-array branch matters: `"${ARGS[@]}"` on an empty array under bash 3.2 expands to a single empty string in some contexts, which `skills.sh` would reject as an unknown command.

- [ ] **Step 4: Run to verify it passes**

Run: `bats scripts/tests/compat.bats`
Expected: 4 tests, all PASS.

- [ ] **Step 5: Wire up the shell functions**

In `stow/zsh/.config/zsh/functions.zsh`, replace the block at ~L1373-1382:

```bash
# Create a new AI agent skill
skills-create() {
    "$SYSTEM_DIR/dotfiles/scripts/skills-create.sh" "$@"
}

# Sync skills to all AI tools
skills-sync() {
    "$SYSTEM_DIR/dotfiles/scripts/skills-sync.sh" "$@"
}
```

with:

```bash
# One front door for AI agent skills — yours, vendored, and plugins
skills() {
    "$SYSTEM_DIR/dotfiles/scripts/skills.sh" "$@"
}

# Deprecated — use `skills new`
skills-create() {
    print -u2 -P "%F{yellow}⚠%f skills-create is now \`skills new\`."
    "$SYSTEM_DIR/dotfiles/scripts/skills-create.sh" "$@"
}

# Deprecated — use `skills`
skills-sync() {
    "$SYSTEM_DIR/dotfiles/scripts/skills-compat.sh" "$@"
}
```

- [ ] **Step 6: Add `skills` to the dotfiles dispatcher**

In the same file at ~L525-531, replace:

```bash
        # AI skills management
        skills-create)
            skills-create "$@"
            ;;
        skills-sync)
            skills-sync "$@"
            ;;
```

with:

```bash
        # AI skills management
        skills)
            skills "$@"
            ;;
        skills-create)
            skills-create "$@"
            ;;
        skills-sync)
            skills-sync "$@"
            ;;
```

- [ ] **Step 7: Verify the shell integration end to end**

```bash
zsh -n stow/zsh/.config/zsh/functions.zsh
zsh -ic 'skills; skills help | head -5; skills-sync --list | head -5'
```

Expected: no syntax errors; `skills` prints the dashboard; `skills-sync --list` prints the deprecation notice on stderr followed by the registry.

- [ ] **Step 8: Commit**

```bash
chmod +x scripts/skills-compat.sh scripts/tests/compat.bats
git add scripts/skills-compat.sh scripts/tests/compat.bats stow/zsh/.config/zsh/functions.zsh
git commit -m "feat(skills): expose \`skills\` and deprecate skills-sync"
```

---

### Task 7: Call sites and documentation

**Files:**
- Modify: `scripts/deploy.sh:320`
- Modify: `bootstrap/bootstrap.sh:284-295`
- Modify: `scripts/rogue.sh:178-190` (`show_skills`)
- Modify: `README.md:44-56` and `README.md:144-152`

**Interfaces:**
- Consumes: `scripts/skills.sh` (Task 4).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Update deploy.sh**

At L320, replace:

```bash
        "$SCRIPT_DIR/skills-sync.sh" "${SYNC_ARGS[@]}" || print_warning "Skills sync encountered issues"
```

with:

```bash
        "$SCRIPT_DIR/skills.sh" sync "${SYNC_ARGS[@]}" || print_warning "Skills sync encountered issues"
```

- [ ] **Step 2: Update bootstrap.sh**

At L284-295, replace the block:

```bash
    # Post-stow: sync AI skills (if private skills repo is cloned)
    if [ -d "$HOME/.skills" ]; then
        if [ -f "$SCRIPT_DIR/../scripts/skills-sync.sh" ]; then
            print_info "Syncing AI skills..."
            bash "$SCRIPT_DIR/../scripts/skills-sync.sh"
            print_success "Skills synced to Claude Code and Cursor"
        fi
    else
        print_info "Skills repo not found. Clone it to enable AI skills:"
        echo "  git clone git@github.com:kyledenis/skills ~/.skills"
        echo "  skills-sync"
    fi
```

with:

```bash
    # Post-stow: sync AI skills (if private skills repo is cloned)
    if [ -d "$HOME/.skills" ]; then
        if [ -f "$SCRIPT_DIR/../scripts/skills.sh" ]; then
            print_info "Syncing AI skills..."
            bash "$SCRIPT_DIR/../scripts/skills.sh" sync
            print_success "Skills synced to Claude Code and Cursor"
        fi
    else
        print_info "Skills repo not found. Clone it to enable AI skills:"
        echo "  git clone git@github.com:kyledenis/skills ~/.skills"
        echo "  skills sync"
    fi
```

- [ ] **Step 3: Rewrite the rogue panel**

In `scripts/rogue.sh`, replace `show_skills()` (L178-190) with:

```bash
show_skills() {
    print_section "AI Skills"
    echo ""
    print_cmd "skills" "Status across all three channels"
    printf "    %-20s ${DIM}%s${NC}\n" "" "Read-only — what you have and what has drifted"
    print_cmd "skills list" "Full registry with versions and targets"
    print_cmd "skills sync" "Distribute ~/.skills to Claude Code and Cursor"
    print_cmd "skills new <name>" "Scaffold a new skill"
    print_cmd "skills import" "Adopt unmanaged skills out of tool dirs"
    echo ""
    echo -e "  ${DIM}Channels: yours (~/.skills), vendored upstream, Claude plugins.${NC}"
    echo -e "  ${DIM}Run${NC} ${GREEN}skills help${NC} ${DIM}for the full surface.${NC}"
    echo ""
}
```

The old panel hand-duplicated every flag, which rots the moment the surface moves. The verbs live here; the detail lives in `skills help`.

- [ ] **Step 4: Update the README**

Replace L44-56:

```markdown
### AI Skills Sync

Distributes AI agent skills from a private canonical store (`~/.skills`) to each tool's expected directory with per-tool frontmatter transformation.

```bash
skills-create <name>       # Interactive skill scaffolding
skills-sync                # Sync skills to all AI tools
skills-sync --list         # List all skills and their targets
skills-sync --dry-run      # Preview without writing
skills-sync --prune        # Remove orphaned skills from tools
```

Skills are stored in a separate private repo (`~/.skills/`) and synced to `~/.claude/skills/` and `~/.cursor/skills/`. See [skills-sync.sh](scripts/skills-sync.sh) for details.
```

with:

```markdown
### AI Skills

One front door across three channels: skills you wrote, skills vendored from
someone else's repo, and Claude Code plugins. Each channel has its own update
mechanism; `skills` knows which is which so you don't have to.

```bash
skills                     # Status across all three channels (read-only)
skills list                # Full registry with versions and targets
skills sync                # Distribute ~/.skills to Claude Code and Cursor
skills sync --dry-run      # Preview without writing
skills sync --prune        # Remove orphaned skills from tools
skills new <name>          # Interactive skill scaffolding
skills import              # Adopt unmanaged skills out of tool dirs
```

Skills live in a separate private repo (`~/.skills/`) and sync to
`~/.claude/skills/` and `~/.cursor/skills/` with per-tool frontmatter
transformation. `skills-sync` still works and forwards to `skills`.

Design: [2026-08-22-skills-cli-design.md](docs/superpowers/specs/2026-08-22-skills-cli-design.md).
```

Then replace the two script-tree lines at L148-149:

```
│   ├── skills-sync.sh         # AI skills distribution
│   ├── skills-create.sh       # Interactive skill scaffolding
```

with:

```
│   ├── skills.sh              # AI skills front door
│   ├── skills-sync.sh         # Sync engine (driven by `skills sync`)
│   ├── skills-compat.sh       # skills-sync deprecation shim
│   ├── skills-create.sh       # Interactive skill scaffolding
│   ├── lib/                   # Shared skills helpers
│   ├── tests/                 # bats tests
```

- [ ] **Step 5: Verify every call site**

```bash
bash -n scripts/deploy.sh bootstrap/bootstrap.sh scripts/rogue.sh
./scripts/rogue.sh skills
./scripts/deploy.sh --dry-run 2>&1 | grep -A3 "Syncing Skills"
grep -rn "skills-sync" scripts/ bootstrap/ README.md | grep -v "skills-sync.sh:" | grep -v skills-compat
```

Expected: no syntax errors; the rogue panel shows the new verbs; deploy's dry-run reaches the sync step; the final grep returns only intentional references (the compat shim, the README's "still works" line, and the script-tree entries).

- [ ] **Step 6: Full suite, one last time**

Run: `bats scripts/tests/`
Expected: 42 tests, all PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/deploy.sh bootstrap/bootstrap.sh scripts/rogue.sh README.md
git commit -m "docs(skills): point every call site and doc at \`skills\`"
```

---

## Done when

- `skills` prints the three-channel dashboard and writes nothing
- `skills sync|list|new|import` behave exactly as their `skills-sync` equivalents did
- `skills-sync` and `skills-create` still work, with a notice
- `rogue skills`, the README, `deploy.sh` and `bootstrap.sh` all describe the new surface
- `bats scripts/tests/` is green — 42 tests
- `~/.skills` is untouched by the whole exercise

## Not in this plan

**Phase 0 from the spec** — committing the 6 untracked skills in `~/.skills` and
removing the vendored `swiftui-expert-skill` now that the plugin supersedes it. That is
housekeeping in a *different* repo, and this plan's completion criterion is that `~/.skills`
comes out untouched. Do it separately, before or after; it does not gate anything here.

Phases 2-4 from the spec, each needing its own plan:

- **Phase 2** — `skills adopt` and backfilling `source:` onto the ~18 vendored skills. Largely research: identifying which repos the `f3f3256` and `5b3917c` batches came from.
- **Phase 3** — `skills update`, `diff`, `merge`. The clone cache, pin advance, pristine-hash check and changelog rendering.
- **Phase 4** — `skills add`, `find`, `doctor`.

Independent of all of it: `claude plugin install mattpocock-skills` gets you Matt Pocock's skills auto-updating today, no code required.
