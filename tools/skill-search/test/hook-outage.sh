#!/bin/sh
# Checks that `hook --wait` stays bounded while the classifier is unreachable:
# the first call returns after the wait cap, a call during the refresh returns at once,
# a call after the failure is held by the cooldown, and an edited skill gets past it.
# Usage: sh test/hook-outage.sh [path to skill-search.mjs]   (takes about 80 seconds)
set -eu
CLI=${1:-$(dirname "$0")/../skill/scripts/skill-search.mjs}
S=$(mktemp -d /tmp/skill-search-outage.XXXX)
mkdir -p "$S/data" "$S/state" "$S/skills/demo"
cp "$(dirname "$0")/../taxonomy.yaml" "$S/data/"
printf -- '---\nname: demo\ndescription: Use when debugging a demo.\n---\n' > "$S/skills/demo/SKILL.md"
cat > "$S/data/config.yaml" <<EOF
exclude: ["npx:*", "claude:*", "plugin:*", "synced:*", "codex:*", "cursor:*"]
classifier: jev
embed: none
jev: {url: "http://127.0.0.1:9/unreachable"}
sources: [{name: scratch, path: $S/skills}]
EOF
echo '{"version":1,"skills":{}}' > "$S/data/verdicts.json"
export SKILL_SEARCH_DIR="$S/data" XDG_STATE_HOME="$S/state" TYPESAFE_API_KEY=dummy
LOG="$S/state/skill-search/sync.log"
elapsed() { start=$(date +%s); node "$CLI" hook --wait; echo $(( $(date +%s) - start )); }
lines() { wc -l < "$LOG" | tr -d ' '; }
fail() { echo "FAIL: $1"; exit 1; }

# A call that starts no refresh returns in node's startup time; QUICK leaves room for a loaded machine
# while staying well under the 15 s cap a waited-on refresh would cost.
QUICK=5
t=$(elapsed); [ "$t" -le 20 ] || fail "first call took ${t}s, expected the 15 s cap"
t=$(elapsed); [ "$t" -le $QUICK ] || fail "call during the refresh took ${t}s"
i=0; while [ -f "$S/state/skill-search/sync.lock" ] && [ $i -lt 40 ]; do sleep 3; i=$((i + 1)); done
[ -f "$S/state/skill-search/sync-failed" ] || fail "the failed sync was not recorded"
n=$(lines); t=$(elapsed)
[ "$(lines)" = "$n" ] && [ ! -f "$S/state/skill-search/sync.lock" ] || fail "cooldown did not hold: a refresh started ($n -> $(lines) log lines)"
[ "$t" -le $QUICK ] || fail "cooldown call took ${t}s"
echo more >> "$S/skills/demo/SKILL.md"; n=$(lines); node "$CLI" hook; sleep 2
[ "$(lines)" -gt "$n" ] || fail "an edited skill did not get past the cooldown"
echo "ok: bounded wait, lock, cooldown and change bypass ($S)"
