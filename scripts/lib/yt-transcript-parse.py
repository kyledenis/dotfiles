"""Turn a YouTube json3 caption file into text. Called by yt-transcript.sh.

Reads SUB, META, MODE, LANG_CODE, FORCE_AUTO and NOTE_FILE from the
environment; writes the transcript to stdout and a two-line summary
(title, then details) to NOTE_FILE.
"""

import json
import os
import re
import sys

PARA_GAP_MS = 2000
PARA_MAX_CHARS = 700


def load_meta():
    lines = [l for l in os.environ["META"].splitlines() if l.strip()]
    manual = json.loads(lines[0]) if lines and lines[0].strip() not in ("", "NA") else {}
    meta = json.loads(lines[1]) if len(lines) > 1 else {}
    return manual, meta


def load_cues(path):
    cues = []
    for ev in json.load(open(path)).get("events", []):
        segs = ev.get("segs")
        if not segs:
            continue
        text = "".join(s.get("utf8", "") for s in segs)
        if not text.strip():
            continue
        start = ev.get("tStartMs", 0)
        cues.append({
            "start": start,
            "end": start + ev.get("dDurationMs", 0),
            "text": re.sub(r"\s+", " ", text).strip(),
        })
    return cues


def paragraphs(cues):
    out, buf, last = [], [], None
    for cue in cues:
        too_long = sum(len(b) for b in buf) > PARA_MAX_CHARS
        gapped = last is not None and cue["start"] - last > PARA_GAP_MS
        if buf and (gapped or too_long):
            out.append(" ".join(buf))
            buf = []
        buf.append(cue["text"])
        last = cue["end"]
    if buf:
        out.append(" ".join(buf))
    return [re.sub(r"\s+", " ", p).strip() for p in out]


def stamp(ms):
    h, rem = divmod(ms // 1000, 3600)
    m, s = divmod(rem, 60)
    return f"{h:d}:{m:02d}:{s:02d}" if h else f"{m:d}:{s:02d}"


def main():
    manual, meta = load_meta()
    lang = os.environ.get("LANG_CODE", "en")
    forced = os.environ.get("FORCE_AUTO") == "true"
    source = "auto" if (forced or lang not in manual) else "human"

    cues = load_cues(os.environ["SUB"])
    if not cues:
        sys.exit("the caption file held no text")

    mode = os.environ.get("MODE", "text")
    if mode == "json":
        body = json.dumps({**meta, "lang": lang, "source": source, "cues": cues},
                          indent=2, ensure_ascii=False)
    elif mode == "timestamps":
        body = "\n".join(f"[{stamp(c['start'])}] {c['text']}" for c in cues)
    else:
        body = "\n\n".join(paragraphs(cues))

    note_file = os.environ.get("NOTE_FILE")
    if note_file:
        secs = int(meta.get("duration") or 0)
        details = [
            meta.get("channel"),
            f"{secs // 60}:{secs % 60:02d}" if secs else "",
            ("auto-generated" if source == "auto" else "human-written") + " captions",
            f"{sum(len(c['text'].split()) for c in cues)} words",
        ]
        with open(note_file, "w") as fh:
            fh.write((meta.get("title") or "untitled") + "\n")
            fh.write(" · ".join(x for x in details if x) + "\n")

    print(body)


if __name__ == "__main__":
    main()
