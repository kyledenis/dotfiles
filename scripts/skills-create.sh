#!/usr/bin/env bash

################################################################################
# skills-create.sh - Interactively create a new AI agent skill
#
# Generates a correctly-formatted SKILL.md with superset frontmatter in the
# canonical skills directory (~/.skills). This script IS the template — format
# changes only need to happen here, keeping the actual format always in sync.
#
# Usage:
#   skills-create <name>
#   skills-create --edit my-skill
#   skills-create --sync my-skill
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

# Options
OPEN_EDITOR=false
RUN_SYNC=false

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

show_help() {
    cat << 'EOF'
Usage: skills-create [options] <name>

Create a new AI agent skill with correct frontmatter format.

Arguments:
    name            Skill name in kebab-case (e.g., code-review, api-docs)

Options:
    --edit          Open $EDITOR after creating the skill
    --sync          Distribute to Claude Code and Cursor immediately after creating
    --help          Show this help message

Environment:
    SKILLS_DIR      Override skills directory (default: ~/.skills)

Examples:
    skills-create code-review               # Interactive creation
    skills-create --edit api-docs           # Create and open in editor
    skills-create --sync --edit my-skill    # Create, edit, then sync

EOF
}

# Prompt with a default value
prompt_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        echo -ne "  ${prompt} ${DIM}(${default})${NC}: "
    else
        echo -ne "  ${prompt}: "
    fi
    read -r result
    echo "${result:-$default}"
}

# Multi-select from options (space-separated, returns selected items)
prompt_multiselect() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "  ${prompt}"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${DIM}${i})${NC} ${opt}"
        i=$((i + 1))
    done
    echo -e "    ${DIM}a)${NC} all"
    echo ""

    echo -ne "  Select (comma-separated numbers, or ${BOLD}a${NC} for all): "
    read -r selection

    if [ "$selection" = "a" ] || [ -z "$selection" ]; then
        echo "${options[*]}"
        return
    fi

    local selected=()
    IFS=',' read -ra indices <<< "$selection"
    for idx in "${indices[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')
        if [ "$idx" -ge 1 ] && [ "$idx" -le "${#options[@]}" ] 2>/dev/null; then
            selected+=("${options[$((idx - 1))]}")
        fi
    done

    echo "${selected[*]}"
}

# Select from existing categories or enter new
prompt_category() {
    local existing=()

    # Gather existing categories from skills
    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        local first second fm cat
        first=$(grep -n '^---$' "$skill_dir/SKILL.md" | head -1 | cut -d: -f1)
        second=$(grep -n '^---$' "$skill_dir/SKILL.md" | sed -n '2p' | cut -d: -f1)
        if [ -n "$first" ] && [ -n "$second" ]; then
            fm=$(sed -n "$((first + 1)),$((second - 1))p" "$skill_dir/SKILL.md")
            cat=$(echo "$fm" | yq eval '.category // ""' - 2>/dev/null)
            if [ -n "$cat" ]; then
                # Add if not already in array
                local found=false
                for e in "${existing[@]}"; do
                    [ "$e" = "$cat" ] && found=true
                done
                if [ "$found" = false ]; then
                    existing+=("$cat")
                fi
            fi
        fi
    done

    if [ ${#existing[@]} -gt 0 ]; then
        echo -e "  Category ${DIM}(for Hermes directory nesting)${NC}"
        echo ""

        local i=1
        for cat in "${existing[@]}"; do
            echo -e "    ${DIM}${i})${NC} ${cat}"
            i=$((i + 1))
        done
        echo -e "    ${DIM}n)${NC} ${BOLD}new category${NC}"
        echo ""

        echo -ne "  Select or enter new: "
        read -r selection

        if [ "$selection" = "n" ] || [ -z "$selection" ]; then
            echo -ne "  New category name (kebab-case): "
            read -r new_cat
            echo "$new_cat"
        elif [ "$selection" -ge 1 ] && [ "$selection" -le "${#existing[@]}" ] 2>/dev/null; then
            echo "${existing[$((selection - 1))]}"
        else
            # Treat as direct input
            echo "$selection"
        fi
    else
        prompt_default "Category (kebab-case, e.g. software-development)" "general"
    fi
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --edit)
            OPEN_EDITOR=true
            shift
            ;;
        --sync)
            RUN_SYNC=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

SKILL_NAME="$1"

if [ -z "$SKILL_NAME" ]; then
    print_error "No skill name provided"
    show_help
    exit 1
fi

# Validate kebab-case
if [[ ! "$SKILL_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    print_error "Invalid skill name: $SKILL_NAME"
    echo "  Expected kebab-case (e.g., code-review, api-docs, my-skill)"
    exit 1
fi

# Check for duplicates
if [ -d "$SKILLS_DIR/$SKILL_NAME" ]; then
    print_error "Skill '$SKILL_NAME' already exists at $SKILLS_DIR/$SKILL_NAME"
    exit 1
fi

# Ensure skills directory exists
if [ ! -d "$SKILLS_DIR" ]; then
    print_warning "Skills directory not found: $SKILLS_DIR"
    echo -ne "  Create it? (y/n) "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$SKILLS_DIR"
        print_success "Created $SKILLS_DIR"
    else
        exit 1
    fi
fi

################################################################################
# Interactive Prompts
################################################################################

echo ""
echo -e "${BOLD}Create Skill: ${CYAN}$SKILL_NAME${NC}"
echo ""

# Description
echo -e "  ${BOLD}Description${NC} ${DIM}(what this skill does and when to trigger it)${NC}"
echo -e "  ${DIM}Paste or type. End with an empty line.${NC}"
echo ""
desc_lines=()
while true; do
    echo -ne "  > "
    read -r line
    if [ -z "$line" ]; then
        break
    fi
    desc_lines+=("$line")
done

if [ ${#desc_lines[@]} -eq 0 ]; then
    print_error "Description is required"
    exit 1
fi

# Join description lines with spaces for YAML >- block
DESCRIPTION=$(printf '%s ' "${desc_lines[@]}" | sed 's/ $//')

# Version
echo ""
VERSION=$(prompt_default "Version" "1.0")

# Targets
echo ""
AVAILABLE_TOOLS=(claude cursor hermes)
TARGETS=$(prompt_multiselect "Which tools should receive this skill?" "${AVAILABLE_TOOLS[@]}")

# Category
echo ""
CATEGORY=$(prompt_category)

################################################################################
# Confirmation
################################################################################

echo ""
echo -e "${DIM}──────────────────────────────────${NC}"
echo ""
print_info "Skill configuration:"
echo ""
echo -e "  Name:        ${BOLD}$SKILL_NAME${NC}"
echo -e "  Description: ${DESCRIPTION:0:70}${DIM}$([ ${#DESCRIPTION} -gt 70 ] && echo '...')${NC}"
echo -e "  Version:     $VERSION"
echo -e "  Targets:     $TARGETS"
echo -e "  Category:    $CATEGORY"
echo -e "  Location:    ${DIM}$SKILLS_DIR/$SKILL_NAME/SKILL.md${NC}"
echo ""

read -p "  Create this skill? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Aborted"
    exit 0
fi

################################################################################
# Generate SKILL.md
################################################################################

print_step "Creating skill"

mkdir -p "$SKILLS_DIR/$SKILL_NAME"

# Build targets YAML array
TARGETS_YAML="["
first=true
for t in $TARGETS; do
    if [ "$first" = true ]; then
        first=false
    else
        TARGETS_YAML+=", "
    fi
    TARGETS_YAML+="$t"
done
TARGETS_YAML+="]"

cat > "$SKILLS_DIR/$SKILL_NAME/SKILL.md" << EOF
---
name: $SKILL_NAME
description: >-
  $DESCRIPTION
version: "$VERSION"
targets: $TARGETS_YAML
category: $CATEGORY
---

# ${SKILL_NAME//-/ }

<!-- Replace this with your skill instructions -->

## When to Use

<!-- Describe when this skill should be activated -->

## Instructions

<!-- The actual instructions the AI agent should follow -->
EOF

print_success "Created $SKILLS_DIR/$SKILL_NAME/SKILL.md"

################################################################################
# Post-Creation
################################################################################

# Open in editor
if [ "$OPEN_EDITOR" = true ]; then
    EDITOR="${EDITOR:-vim}"
    print_step "Opening in $EDITOR"
    "$EDITOR" "$SKILLS_DIR/$SKILL_NAME/SKILL.md"
fi

# Run sync
if [ "$RUN_SYNC" = true ]; then
    print_step "Syncing skills"
    "$SCRIPT_DIR/skills.sh" sync
fi

# Git status
if [ -d "$SKILLS_DIR/.git" ]; then
    print_step "Git status"
    cd "$SKILLS_DIR"
    git add "$SKILL_NAME"
    print_success "Staged $SKILL_NAME/ for commit"
fi

echo ""
print_success "Skill '$SKILL_NAME' created."
echo ""
echo "  Next steps:"
echo -e "    1. Edit the skill: ${DIM}\$EDITOR $SKILLS_DIR/$SKILL_NAME/SKILL.md${NC}"
if [ "$RUN_SYNC" = false ]; then
    echo -e "    2. Distribute:     ${DIM}skills sync${NC}"
fi
echo -e "    3. Commit:         ${DIM}cd ~/.skills && git commit -m 'feat: add $SKILL_NAME skill'${NC}"
echo ""
