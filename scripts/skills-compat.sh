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

exec "$SCRIPT_DIR/skills.sh" "$VERB" "${ARGS[@]}"
