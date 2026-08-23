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
