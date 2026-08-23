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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SKILLS_DIR="${SKILLS_DIR:-$HOME/.skills}"
MANIFEST_NAME=".skills-sync.json"

################################################################################
# Tool Definitions
#
# Each tool has:
#   dest       - target directory for skills
#   layout     - "flat" (<name>/SKILL.md) or "categorized" (<category>/<name>/SKILL.md)
#   fields     - YAML frontmatter fields to keep (space-separated)
################################################################################

declare -gA TOOL_DEST TOOL_LAYOUT TOOL_FIELDS

TOOL_DEST[claude]="${SKILLS_DEST_CLAUDE:-$HOME/.claude/skills}"
TOOL_LAYOUT[claude]="flat"
TOOL_FIELDS[claude]="name description version"

TOOL_DEST[cursor]="${SKILLS_DEST_CURSOR:-$HOME/.cursor/skills}"
TOOL_LAYOUT[cursor]="flat"
TOOL_FIELDS[cursor]="name description"

TOOLS=(claude cursor)

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}→${NC} ${BOLD}$1${NC}"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "  ${DIM}$1${NC}"
    fi
}

################################################################################
# Ignore List
################################################################################

# Names listed in ~/.skills/.skills-ignore, one per line, # comments allowed.
# Skills another tool installed belong here so they stop reading as drift,
# and skills-sync's import mode skips them too.
ignored_skills() {
    local f="$SKILLS_DIR/.skills-ignore"
    [ -f "$f" ] || return 0
    grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' || true
}

################################################################################
# Frontmatter Utilities
################################################################################

# Extract YAML frontmatter from a SKILL.md file (between first and second --- only)
extract_frontmatter() {
    local file="$1"
    local first second
    first=$(grep -n '^---$' "$file" | head -1 | cut -d: -f1)
    second=$(grep -n '^---$' "$file" | sed -n '2p' | cut -d: -f1)
    if [ -n "$first" ] && [ -n "$second" ]; then
        sed -n "$((first + 1)),$((second - 1))p" "$file"
    fi
}

# Extract markdown body (everything after the second ---)
extract_body() {
    local file="$1"
    local second_delim
    second_delim=$(grep -n '^---$' "$file" | sed -n '2p' | cut -d: -f1)
    if [ -n "$second_delim" ]; then
        tail -n +"$((second_delim + 1))" "$file"
    fi
}

# Read a frontmatter field value
read_field() {
    local file="$1"
    local field="$2"
    extract_frontmatter "$file" | yq eval ".$field // \"\"" -
}

# Read targets array as space-separated string
read_targets() {
    local file="$1"
    local targets
    targets=$(extract_frontmatter "$file" | yq eval '.targets // [] | .[]' - 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
    if [ -z "$targets" ]; then
        echo "all"
    else
        echo "$targets"
    fi
}

# Read category field
read_category() {
    local file="$1"
    extract_frontmatter "$file" | yq eval '.category // "general"' -
}

# Transform frontmatter to only include allowed fields for a tool
# Uses yq's pick() to cleanly filter fields while preserving YAML formatting
transform_frontmatter() {
    local file="$1"
    local allowed_fields="$2"  # space-separated

    # Build JSON array of field names for yq pick()
    local pick_array="["
    local first=true
    for field in $allowed_fields; do
        if [ "$first" = true ]; then
            first=false
        else
            pick_array+=","
        fi
        pick_array+="\"$field\""
    done
    pick_array+="]"

    echo "---"
    extract_frontmatter "$file" | yq eval "pick($pick_array)" -
    echo "---"
}

# Generate a content hash for an entire skill directory
hash_skill_dir() {
    local dir="$1"
    find "$dir" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1
}

################################################################################
# Manifest Management
################################################################################

# Read the current manifest for a tool, or return empty JSON
read_manifest() {
    local tool="$1"
    local manifest_path="${TOOL_DEST[$tool]}/$MANIFEST_NAME"
    if [ -f "$manifest_path" ]; then
        cat "$manifest_path"
    else
        echo '{"managed_by":"skills-sync","skills":{}}'
    fi
}

# Get a skill's canonical hash from the manifest
manifest_hash() {
    local manifest_json="$1"
    local skill_name="$2"
    echo "$manifest_json" | yq eval -p json ".skills.\"$skill_name\".hash // \"\"" -
}

# Get a skill's tool output hash from the manifest
manifest_tool_hash() {
    local manifest_json="$1"
    local skill_name="$2"
    echo "$manifest_json" | yq eval -p json ".skills.\"$skill_name\".tool_hash // \"\"" -
}

# Write an updated manifest
write_manifest() {
    local tool="$1"
    local manifest_json="$2"
    local manifest_path="${TOOL_DEST[$tool]}/$MANIFEST_NAME"

    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would write manifest to $manifest_path"
        return
    fi

    mkdir -p "${TOOL_DEST[$tool]}"
    # Update the last_sync timestamp
    echo "$manifest_json" | yq eval -p json -o json ".last_sync = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" | .managed_by = \"skills-sync\"" - > "$manifest_path"
}
