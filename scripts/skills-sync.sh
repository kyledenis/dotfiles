#!/usr/bin/env bash

################################################################################
# skills-sync.sh - Sync canonical skills to AI tool directories
#
# Reads skills from a canonical store (~/.skills) and distributes them to
# each tool's expected location with appropriate frontmatter transformation.
#
# Usage:
#   skills-sync.sh                  # Sync all skills to all targets
#   skills-sync.sh --dry-run        # Preview without writing
#   skills-sync.sh --list           # Show skill registry
#   skills-sync.sh --tool claude    # Sync to specific tool only
#   skills-sync.sh --prune          # Remove orphaned skills from targets
#   skills-sync.sh --import          # Import unmanaged skills from tools
#   skills-sync.sh --verbose        # Detailed output
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.skills}"
MANIFEST_NAME=".skills-sync.json"

# Options
DRY_RUN=false
PRUNE=false
VERBOSE=false
LIST_ONLY=false
IMPORT_MODE=false
TOOL_FILTER=""

# Counters
SYNCED=0
SKIPPED=0
PRUNED=0
ERRORS=0

################################################################################
# Tool Definitions
#
# Each tool has:
#   dest       - target directory for skills
#   layout     - "flat" (<name>/SKILL.md) or "categorized" (<category>/<name>/SKILL.md)
#   fields     - YAML frontmatter fields to keep (space-separated)
################################################################################

declare -A TOOL_DEST TOOL_LAYOUT TOOL_FIELDS

TOOL_DEST[claude]="$HOME/.claude/skills"
TOOL_LAYOUT[claude]="flat"
TOOL_FIELDS[claude]="name description version"

TOOL_DEST[cursor]="$HOME/.cursor/skills"
TOOL_LAYOUT[cursor]="flat"
TOOL_FIELDS[cursor]="name description"

# Hermes uses categorized layout — uncomment when ready
# TOOL_DEST[hermes]="$HOME/.hermes/skills"
# TOOL_LAYOUT[hermes]="categorized"
# TOOL_FIELDS[hermes]="name description version"

TOOLS=(claude cursor)

################################################################################
# Helper Functions
################################################################################

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

show_help() {
    cat << 'EOF'
Usage: skills-sync.sh [options]

Sync canonical skills from ~/.skills to AI tool directories.

Options:
    --dry-run       Preview without writing any files
    --prune         Remove skills from targets that are no longer in canonical store
    --import        Import unmanaged skills from tool directories into ~/.skills
    --tool NAME     Sync to a specific tool only (claude, cursor)
    --list          Show skill registry and exit
    --verbose       Show detailed sync operations
    --help          Show this help message

Environment:
    SKILLS_DIR      Override canonical skills directory (default: ~/.skills)

Examples:
    skills-sync.sh                  # Sync all skills
    skills-sync.sh --dry-run        # Preview changes
    skills-sync.sh --list           # Show registry
    skills-sync.sh --tool claude    # Sync to Claude Code only
    skills-sync.sh --prune          # Clean up orphaned skills
    skills-sync.sh --import         # Import unmanaged skills from tools
    skills-sync.sh --import --dry-run  # Preview import without prompting

EOF
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --prune)
            PRUNE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --import)
            IMPORT_MODE=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --tool)
            TOOL_FILTER="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            print_error "Unexpected argument: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Validation
################################################################################

if [ ! -d "$SKILLS_DIR" ]; then
    print_warning "Skills directory not found: $SKILLS_DIR"
    print_info "Clone your skills repo: git clone <repo> ~/.skills"
    exit 0
fi

if ! command -v yq >/dev/null 2>&1; then
    print_error "yq is required but not installed. Install with: brew install yq"
    exit 1
fi

# Validate tool filter
if [ -n "$TOOL_FILTER" ]; then
    if [ -z "${TOOL_DEST[$TOOL_FILTER]+x}" ]; then
        print_error "Unknown tool: $TOOL_FILTER"
        echo "Available tools: ${TOOLS[*]}"
        exit 1
    fi
    TOOLS=("$TOOL_FILTER")
fi

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

################################################################################
# List Mode
################################################################################

list_skills() {
    echo -e "\n${BOLD}Skill Registry${NC} ${DIM}($SKILLS_DIR)${NC}\n"

    local count=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue

        local name version targets category
        name=$(read_field "$skill_dir/SKILL.md" "name")
        version=$(read_field "$skill_dir/SKILL.md" "version")
        targets=$(read_targets "$skill_dir/SKILL.md")
        category=$(read_category "$skill_dir/SKILL.md")

        # Count supporting files
        local file_count
        file_count=$(find "$skill_dir" -type f ! -name SKILL.md | wc -l | tr -d ' ')

        printf "  ${GREEN}%-30s${NC} ${DIM}v%-6s${NC} ${CYAN}%-20s${NC}" "$name" "$version" "[$category]"

        if [ "$file_count" -gt 0 ]; then
            printf " ${DIM}+%s files${NC}" "$file_count"
        fi
        echo ""

        # Show targets
        if [ "$targets" = "all" ]; then
            printf "  ${DIM}%-30s targets: all${NC}\n" ""
        else
            printf "  ${DIM}%-30s targets: %s${NC}\n" "" "$targets"
        fi

        count=$((count + 1))
    done

    echo ""
    print_info "$count skill(s) in registry"
    echo ""
}

if [ "$LIST_ONLY" = true ]; then
    list_skills
    exit 0
fi

################################################################################
# Import Mode — Reverse sync from tool directories to canonical store
################################################################################

if [ "$IMPORT_MODE" = true ]; then
    echo -e "\n${BOLD}Import Preview${NC}\n"

    # Collect import candidates: (tool, skill_name, skill_dir, description)
    declare -a IMPORT_TOOLS=()
    declare -a IMPORT_NAMES=()
    declare -a IMPORT_DIRS=()
    declare -a IMPORT_DESCS=()
    declare -a DIVERGED_TOOLS=()
    declare -a DIVERGED_NAMES=()
    declare -a DIVERGED_DIRS=()
    IMPORT_COUNT=0
    IMPORT_SKIP=0
    DIVERGED_COUNT=0

    for tool in "${TOOLS[@]}"; do
        tool_dir="${TOOL_DEST[$tool]}"
        [ -d "$tool_dir" ] || continue

        # Read this tool's manifest
        tool_manifest=$(read_manifest "$tool")

        for candidate_dir in "$tool_dir"/*/; do
            [ -d "$candidate_dir" ] || continue
            candidate_name=$(basename "$candidate_dir")

            # Skip manifest file directory (shouldn't happen, but be safe)
            [ "$candidate_name" = ".skills-sync.json" ] && continue

            # Skip if no SKILL.md
            [ -f "$candidate_dir/SKILL.md" ] || continue

            # Skip tool-bundled/reserved directories
            case "$tool" in
                cursor)
                    # Cursor's built-in skills are in skills-cursor/, not skills/
                    # But skip if somehow we're scanning the wrong dir
                    ;;
                codex)
                    # Skip .system/ directory
                    [ "$candidate_name" = ".system" ] && continue
                    ;;
            esac

            # Check if managed by skills-sync (in manifest)
            managed_hash=$(manifest_hash "$tool_manifest" "$candidate_name")
            if [ -n "$managed_hash" ]; then
                # Managed — but has it been modified in-place?
                # Compare against tool_hash (hash of the transformed output), not canonical hash
                expected_tool_hash=$(manifest_tool_hash "$tool_manifest" "$candidate_name")
                current_tool_hash=$(hash_skill_dir "$candidate_dir")
                if [ -n "$expected_tool_hash" ] && [ "$current_tool_hash" != "$expected_tool_hash" ]; then
                    # Diverged from canonical — flag it
                    DIVERGED_TOOLS+=("$tool")
                    DIVERGED_NAMES+=("$candidate_name")
                    DIVERGED_DIRS+=("$candidate_dir")
                    DIVERGED_COUNT=$((DIVERGED_COUNT + 1))
                else
                    print_verbose "Skipping $candidate_name from $tool (managed, unchanged)"
                fi
                continue
            fi

            # Skip if already exists in canonical store (duplicate)
            if [ -d "$SKILLS_DIR/$candidate_name" ]; then
                printf "  ${DIM}From ${tool}:${NC}\n"
                printf "    ${YELLOW}~${NC} %-24s ${DIM}SKIP (already in ~/.skills)${NC}\n" "$candidate_name"
                IMPORT_SKIP=$((IMPORT_SKIP + 1))
                continue
            fi

            # This is a genuine import candidate
            desc=$(read_field "$candidate_dir/SKILL.md" "description" 2>/dev/null)
            desc="${desc:0:60}"

            IMPORT_TOOLS+=("$tool")
            IMPORT_NAMES+=("$candidate_name")
            IMPORT_DIRS+=("$candidate_dir")
            IMPORT_DESCS+=("$desc")
            IMPORT_COUNT=$((IMPORT_COUNT + 1))
        done
    done

    # Display candidates grouped by tool
    if [ "$IMPORT_COUNT" -gt 0 ]; then
        current_tool=""
        for i in $(seq 0 $((IMPORT_COUNT - 1))); do
            if [ "${IMPORT_TOOLS[$i]}" != "$current_tool" ]; then
                current_tool="${IMPORT_TOOLS[$i]}"
                echo -e "  ${BOLD}From ${current_tool}:${NC}"
            fi
            printf "    ${GREEN}+${NC} %-24s ${DIM}\"%s\"${NC}\n" "${IMPORT_NAMES[$i]}" "${IMPORT_DESCS[$i]}"
        done
    fi

    # Display diverged skills
    if [ "$DIVERGED_COUNT" -gt 0 ]; then
        echo ""
        echo -e "  ${BOLD}${YELLOW}Modified in-place (diverged from canonical):${NC}"
        for i in $(seq 0 $((DIVERGED_COUNT - 1))); do
            printf "    ${YELLOW}!${NC} %-24s ${DIM}modified in ${DIVERGED_TOOLS[$i]}${NC}\n" "${DIVERGED_NAMES[$i]}"
        done
        echo ""
        echo -e "  ${DIM}These were synced from ~/.skills but edited locally.${NC}"
        echo -e "  ${DIM}To keep local changes: copy from tool dir to ~/.skills manually${NC}"
        echo -e "  ${DIM}To discard local changes: run skills-sync (overwrites with canonical)${NC}"
    fi

    # Summary
    echo ""
    echo -e "${DIM}──────────────────────────────────${NC}"

    if [ "$IMPORT_COUNT" -eq 0 ] && [ "$IMPORT_SKIP" -eq 0 ] && [ "$DIVERGED_COUNT" -eq 0 ]; then
        print_info "No unmanaged or modified skills found in any tool directory"
        exit 0
    fi

    parts=()
    [ "$IMPORT_COUNT" -gt 0 ] && parts+=("${GREEN}$IMPORT_COUNT to import${NC}")
    [ "$IMPORT_SKIP" -gt 0 ] && parts+=("${YELLOW}$IMPORT_SKIP skipped (duplicate)${NC}")
    [ "$DIVERGED_COUNT" -gt 0 ] && parts+=("${YELLOW}$DIVERGED_COUNT modified${NC}")
    echo -e "  $(IFS='  |  '; echo "${parts[*]}")"
    echo ""

    if [ "$IMPORT_COUNT" -eq 0 ]; then
        exit 0
    fi

    # Dry run stops here
    if [ "$DRY_RUN" = true ]; then
        print_info "Dry run — no changes made"
        exit 0
    fi

    # Prompt for confirmation
    read -p "  Import these to $SKILLS_DIR? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Aborted"
        exit 0
    fi

    # Execute import
    echo ""
    for i in $(seq 0 $((IMPORT_COUNT - 1))); do
        src_dir="${IMPORT_DIRS[$i]}"
        skill_name="${IMPORT_NAMES[$i]}"
        dest_dir="$SKILLS_DIR/$skill_name"

        # Copy entire skill directory
        mkdir -p "$dest_dir"
        cp -R "$src_dir"/* "$dest_dir/"

        # Augment frontmatter with missing superset fields
        skill_file="$dest_dir/SKILL.md"
        fm=$(extract_frontmatter "$skill_file")

        # Check which fields need adding
        has_version=$(echo "$fm" | yq eval '.version // ""' - 2>/dev/null)
        has_targets=$(echo "$fm" | yq eval '.targets // "" | length' - 2>/dev/null)
        has_category=$(echo "$fm" | yq eval '.category // ""' - 2>/dev/null)

        # Build augmented frontmatter
        augmented="$fm"
        if [ -z "$has_version" ]; then
            augmented=$(echo "$augmented" | yq eval '. + {"version": "1.0"}' -)
        fi
        if [ "$has_targets" = "0" ] || [ -z "$has_targets" ]; then
            # Default to all configured tools — build as proper YAML list
            targets_yaml="["
            first_t=true
            for t in "${TOOLS[@]}"; do
                if [ "$first_t" = true ]; then first_t=false; else targets_yaml+=", "; fi
                targets_yaml+="\"$t\""
            done
            targets_yaml+="]"
            augmented=$(echo "$augmented" | yq eval ".targets = $targets_yaml" -)
        fi
        if [ -z "$has_category" ]; then
            augmented=$(echo "$augmented" | yq eval '. + {"category": "general"}' -)
        fi

        # Rewrite SKILL.md with augmented frontmatter + original body
        {
            echo "---"
            echo "$augmented"
            echo "---"
            extract_body "$src_dir/SKILL.md"
        } > "$skill_file"

        print_success "$skill_name ${DIM}(from ${IMPORT_TOOLS[$i]})${NC}"
    done

    # Git stage if in a repo
    if [ -d "$SKILLS_DIR/.git" ]; then
        echo ""
        print_info "Imported skills are unstaged. To commit:"
        echo -e "  ${DIM}cd ~/.skills && git add -A && git commit -m 'feat: import skills from tools'${NC}"
    fi

    echo ""
    print_info "Run ${BOLD}skills-sync${NC} to distribute imported skills to all tools"
    echo ""
    exit 0
fi

################################################################################
# Forward Sync Logic
################################################################################

echo -e "\n${BOLD}Skills Sync${NC} ${DIM}(forward)${NC}"

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN — no changes will be made"
fi

echo ""

for tool in "${TOOLS[@]}"; do
    print_step "Syncing to ${BOLD}$tool${NC} → ${DIM}${TOOL_DEST[$tool]}${NC}"

    local_manifest=$(read_manifest "$tool")
    new_manifest="$local_manifest"
    tool_synced=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue

        skill_name=$(basename "$skill_dir")
        skill_file="$skill_dir/SKILL.md"

        # Check if this skill targets this tool
        targets=$(read_targets "$skill_file")
        if [ "$targets" != "all" ]; then
            if ! echo "$targets" | grep -qw "$tool"; then
                print_verbose "Skipping $skill_name (not targeted for $tool)"
                continue
            fi
        fi

        # Check content hash — skip if unchanged
        current_hash=$(hash_skill_dir "$skill_dir")
        cached_hash=$(manifest_hash "$local_manifest" "$skill_name")

        if [ "$current_hash" = "$cached_hash" ]; then
            print_verbose "Unchanged: $skill_name"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Determine destination path
        dest_dir="${TOOL_DEST[$tool]}/$skill_name"
        if [ "${TOOL_LAYOUT[$tool]}" = "categorized" ]; then
            category=$(read_category "$skill_file")
            dest_dir="${TOOL_DEST[$tool]}/$category/$skill_name"
        fi

        if [ "$DRY_RUN" = true ]; then
            if [ "$cached_hash" = "" ]; then
                print_info "Would create: $skill_name → $dest_dir"
            else
                print_info "Would update: $skill_name → $dest_dir"
            fi
        else
            # Create destination and copy supporting files first
            mkdir -p "$dest_dir"

            # Copy all supporting files (everything except SKILL.md)
            # Use rsync-like approach: copy dir contents, preserving structure
            find "$skill_dir" -type f ! -name SKILL.md -print0 | while IFS= read -r -d '' src_file; do
                rel_path="${src_file#$skill_dir}"
                dest_file="$dest_dir/$rel_path"
                mkdir -p "$(dirname "$dest_file")"
                cp "$src_file" "$dest_file"
            done

            # Remove supporting files in dest that no longer exist in source
            if [ -d "$dest_dir" ]; then
                find "$dest_dir" -type f ! -name SKILL.md ! -name "$MANIFEST_NAME" -print0 | while IFS= read -r -d '' dest_file; do
                    rel_path="${dest_file#$dest_dir/}"
                    if [ ! -f "$skill_dir/$rel_path" ]; then
                        rm "$dest_file"
                        print_verbose "Removed stale file: $rel_path"
                    fi
                done
            fi

            # Transform and write SKILL.md
            {
                transform_frontmatter "$skill_file" "${TOOL_FIELDS[$tool]}"
                echo ""
                extract_body "$skill_file"
            } > "$dest_dir/SKILL.md"

            if [ "$cached_hash" = "" ]; then
                print_success "$skill_name ${DIM}(new)${NC}"
            else
                print_success "$skill_name ${DIM}(updated)${NC}"
            fi
        fi

        # Update manifest entry (store both canonical hash and tool output hash)
        tool_output_hash=""
        if [ "$DRY_RUN" = false ] && [ -d "$dest_dir" ]; then
            tool_output_hash=$(hash_skill_dir "$dest_dir")
        fi
        new_manifest=$(echo "$new_manifest" | yq eval -p json -o json \
            ".skills.\"$skill_name\".hash = \"$current_hash\" | .skills.\"$skill_name\".version = \"$(read_field "$skill_file" "version")\" | .skills.\"$skill_name\".tool_hash = \"$tool_output_hash\"" -)

        SYNCED=$((SYNCED + 1))
        tool_synced=$((tool_synced + 1))
    done

    # Prune orphaned skills
    if [ "$PRUNE" = true ]; then
        # Get list of managed skills from manifest
        managed_skills=$(echo "$local_manifest" | yq eval -p json '.skills | keys | .[]' - 2>/dev/null)

        for managed_name in $managed_skills; do
            # Check if skill still exists in canonical store
            if [ ! -d "$SKILLS_DIR/$managed_name" ]; then
                dest_dir="${TOOL_DEST[$tool]}/$managed_name"

                if [ "$DRY_RUN" = true ]; then
                    print_info "Would prune: $managed_name from $tool"
                else
                    if [ -d "$dest_dir" ]; then
                        rm -rf "$dest_dir"
                        print_warning "Pruned: $managed_name"
                    fi
                    # Remove from manifest
                    new_manifest=$(echo "$new_manifest" | yq eval -p json -o json "del(.skills.\"$managed_name\")" -)
                fi

                PRUNED=$((PRUNED + 1))
            fi
        done
    fi

    # Write updated manifest
    write_manifest "$tool" "$new_manifest"

    if [ "$tool_synced" -eq 0 ] && [ "$PRUNED" -eq 0 ]; then
        print_info "Nothing to sync"
    fi
done

################################################################################
# Summary
################################################################################

echo ""
echo -e "${DIM}──────────────────────────────────${NC}"

if [ "$DRY_RUN" = true ]; then
    print_info "Dry run complete"
fi

parts=()
[ "$SYNCED" -gt 0 ] && parts+=("${GREEN}$SYNCED synced${NC}")
[ "$SKIPPED" -gt 0 ] && parts+=("${DIM}$SKIPPED unchanged${NC}")
[ "$PRUNED" -gt 0 ] && parts+=("${YELLOW}$PRUNED pruned${NC}")
[ "$ERRORS" -gt 0 ] && parts+=("${RED}$ERRORS errors${NC}")

if [ ${#parts[@]} -eq 0 ]; then
    echo -e "  No skills found in $SKILLS_DIR"
else
    echo -e "  $(IFS='  |  '; echo "${parts[*]}")"
fi

echo ""
