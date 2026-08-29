#!/usr/bin/env bash

################################################################################
# yt-transcript - Pull a YouTube video's transcript as clean text
#
# Reads the caption track YouTube already holds rather than transcribing
# audio, so it costs one request and about a second. Prefers the
# human-written track and falls back to the auto-generated one.
#
# Usage: yt-transcript <url|id> [options]
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$SCRIPT_DIR/lib/yt-transcript-parse.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

# Status goes to stderr, which is often redirected. Stay plain unless it is a terminal.
if [ ! -t 2 ]; then
    RED='' GREEN='' DIM='' NC=''
fi

LANG_CODE="${YT_TRANSCRIPT_LANG:-en}"
MODE="text"
OUT=""
COPY=false
FORCE_AUTO=false
URL=""

die() {
    echo -e "${RED}error:${NC} $1" >&2
    exit 1
}

show_help() {
    cat << 'EOF'
Usage: yt-transcript <url|id> [options]

Pull a YouTube video's transcript as clean text. Reads the caption track
YouTube already has, so there is no audio download and no transcription
step. Prefers human-written captions, falls back to auto-generated.

Options:
    -t, --timestamps    One line per cue, prefixed [m:ss]
    -j, --json          Structured JSON with metadata and cue timings
    -o, --out FILE      Write to FILE instead of stdout
    -c, --copy          Copy the transcript to the clipboard
        --auto          Force the auto-generated track
        --langs         List the caption languages this video has
    -h, --help          This message

Environment:
    YT_TRANSCRIPT_LANG  Caption language (default: en)

Examples:
    yt-transcript 'https://youtu.be/WkBPX-oDMnA'
    yt-transcript WkBPX-oDMnA -t
    yt-transcript <url> -c                    copy, ready to paste
    yt-transcript <url> -o talk.txt
    yt-transcript <url> -j | jq -r '.cues[0].text'

Notes:
    The transcript goes to stdout so it pipes cleanly. Title, channel and
    caption source are reported on stderr.

    No captions at all? Transcribe the audio instead:
      yt-dlp -x --audio-format wav -o a.wav <url> && whisper a.wav
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--timestamps) MODE="timestamps" ;;
        -j|--json)       MODE="json" ;;
        -o|--out)        shift; [ $# -gt 0 ] || die "--out needs a filename"; OUT="$1" ;;
        -c|--copy)       COPY=true ;;
        --auto)          FORCE_AUTO=true ;;
        --langs)         MODE="langs" ;;
        -h|--help)       show_help; exit 0 ;;
        -*)              die "unknown option: $1 (try --help)" ;;
        *)               [ -z "$URL" ] || die "only one video at a time"; URL="$1" ;;
    esac
    shift
done

[ -n "$URL" ] || { show_help; exit 1; }
command -v yt-dlp >/dev/null 2>&1 || die "yt-dlp is not installed (brew install yt-dlp)"

if [ "$MODE" = "langs" ]; then
    INFO=$(yt-dlp --no-update --skip-download --no-warnings -J "$URL" 2>/dev/null) \
        || die "could not read that video"
    INFO="$INFO" python3 -c '
import json, os
d = json.loads(os.environ["INFO"])
manual = sorted(d.get("subtitles") or {})
auto = sorted(d.get("automatic_captions") or {})
print(d.get("title", "?"), end="\n\n")
print("human-written : " + (", ".join(manual) if manual else "(none)"))
print("auto-generated: " + (str(len(auto)) + " languages, incl. " + ", ".join(auto[:8]) if auto else "(none)"))
'
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ "$FORCE_AUTO" = true ]; then
    WRITE=(--write-auto-subs)
else
    WRITE=(--write-subs --write-auto-subs)
fi

if ! META=$(yt-dlp --no-update --skip-download --no-simulate --no-warnings \
        "${WRITE[@]}" --sub-langs "$LANG_CODE" --sub-format json3 \
        --print '%(subtitles)j' --print '%(.{title,channel,duration,webpage_url})j' \
        -o "$TMP/sub.%(ext)s" "$URL" 2>"$TMP/err"); then
    die "$(tail -1 "$TMP/err" 2>/dev/null || echo 'yt-dlp failed')"
fi

SUB=$(find "$TMP" -name 'sub.*.json3' | head -1)
[ -n "$SUB" ] || die "no '$LANG_CODE' captions for this video.
  Run with --langs to see what exists, or transcribe the audio:
  yt-dlp -x --audio-format wav -o a.wav '$URL' && whisper a.wav"

[ -f "$PARSER" ] || die "parser library is missing: $PARSER"

if ! RESULT=$(SUB="$SUB" META="$META" MODE="$MODE" LANG_CODE="$LANG_CODE" \
        FORCE_AUTO="$FORCE_AUTO" NOTE_FILE="$TMP/note" python3 "$PARSER" 2>"$TMP/perr"); then
    die "$(tail -1 "$TMP/perr" 2>/dev/null || echo 'could not parse the caption file')"
fi

while IFS= read -r line; do
    echo -e "${DIM}${line}${NC}" >&2
done < "$TMP/note"

if [ "$COPY" = true ]; then
    printf '%s\n' "$RESULT" | pbcopy
    echo -e "${GREEN}✓${NC} copied to clipboard" >&2
fi

if [ -n "$OUT" ]; then
    printf '%s\n' "$RESULT" > "$OUT"
    echo -e "${GREEN}✓${NC} wrote $OUT" >&2
elif [ "$COPY" = false ]; then
    printf '%s\n' "$RESULT"
fi
