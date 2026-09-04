#!/usr/bin/env bash
# Claude Code status line.
#   line 1: selected model
#   line 2: 5h usage · 7d usage · context window used
# Reads the session JSON on stdin. Prints an explicit marker when quota data
# is absent rather than rendering blank, so a schema change stays visible.
input=$(cat)

command -v jq >/dev/null 2>&1 || { printf 'usage: jq not installed'; exit 0; }

# Tab-separated, with IFS pinned to tab: the model display name contains
# spaces, and default word-splitting would shift every field after it.
IFS=$'\t' read -r model h5p h5r d7p d7r ctx <<<"$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // .model.id // "-"),
    (.rate_limits.five_hour.used_percentage      // "-"),
    (.rate_limits.five_hour.resets_at            // "-"),
    (.rate_limits.seven_day.used_percentage      // "-"),
    (.rate_limits.seven_day.resets_at            // "-"),
    (.context_window.used_percentage
       // (if (.context_window.remaining_percentage | type) == "number"
           then (100 - .context_window.remaining_percentage) else null end)
       // "-") ] | @tsv' 2>/dev/null)"

seg() { # $1=label $2=pct $3=resets_at $4=date-format $5=invert (lower is worse)
  local pct=${2%%.*} when=''
  { [ -z "$pct" ] || [ "$pct" = "-" ]; } && return 1
  local c=$'\033[32m'
  if [ -n "$5" ]; then
    [ "$pct" -lt 50 ] 2>/dev/null && c=$'\033[33m'
    [ "$pct" -lt 20 ] 2>/dev/null && c=$'\033[31m'
  else
    [ "$pct" -ge 50 ] 2>/dev/null && c=$'\033[33m'
    [ "$pct" -ge 80 ] 2>/dev/null && c=$'\033[31m'
  fi
  [ "$3" != "-" ] && when=$(date -r "$3" "+$4" 2>/dev/null) && when=" \033[2m→\033[0m \033[2m$when\033[0m"
  printf '\033[2m%s:\033[0m %s%s%%\033[0m%b' "$1" "$c" "$pct" "$when"
}

usage=''
s=$(seg '5h'  "$h5p" "$h5r" '%H:%M')       && usage="${usage:+$usage \033[2m·\033[0m }$s"
s=$(seg '7d'  "$d7p" "$d7r" '%a %H:%M')    && usage="${usage:+$usage \033[2m·\033[0m }$s"
s=$(seg 'ctx' "$ctx" '-'    '')           && usage="${usage:+$usage \033[2m·\033[0m }$s"
[ -z "$usage" ] && usage=$'\033[2musage: n/a (no rate-limit data in payload yet)\033[0m'

{ [ -n "$model" ] && [ "$model" != "-" ]; } && printf '\033[1;36m%s\033[0m\n' "$model"
printf '%b' "$usage"
