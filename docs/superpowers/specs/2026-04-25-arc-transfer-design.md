# `arc` — file transfer commands for arc-reactor

## Overview

`arc` is a shell command for transferring files between this machine and the arc-reactor media server. It combines named shortcuts for common paths, an interactive fzf-based directory browser, and rsync for reliable transfers.

Design principle: **minimize friction**. Common transfers should be one command. Exploration should be effortless.

## Interface

### Subcommands

| Command | Description |
|---------|-------------|
| `arc push <local> [dest]` | Upload file/directory to server |
| `arc pull [source] [local]` | Download file/directory from server |
| `arc ls [path]` | Browse remote filesystem interactively |
| `arc df` | Show server disk usage |

### Shortcut registry

```bash
declare -A ARC_SHORTCUTS=(
    [movies]="/media/myfiles/movies"
    [tv]="/media/myfiles/tv"
    [herald]="/home/herald"
    [configs]="/home/kyledenis/configs"
    [home]="/home/kyledenis"
)
ARC_DEFAULT="/media/myfiles"
ARC_HOST="arc-reactor"
```

Shortcuts are resolved before any operation. Raw paths starting with `/` bypass resolution. Shortcuts support sub-paths via slash syntax: `movies/James Bond Collection` resolves to `/media/myfiles/movies/James Bond Collection`.

### Path resolution

Effort scales with knowledge — the less you know, the more help you get:

1. **Raw path** (`/media/myfiles/movies/`) → use directly, no resolution
2. **Exact shortcut** (`movies`) → resolve from registry, instant
3. **Shortcut + sub-path** (`movies/James Bond Collection`) → resolve shortcut, append sub-path
4. **Fuzzy fragment** (`bond`, `gold`, `herald`) → search remote dirs for matches:
   - 1 match → auto-select, no interaction needed
   - Multiple matches → quick fzf picker showing just the matches (not the full browser)
   - 0 matches → "No match for 'bond'. Browse?" → falls back to interactive browser
5. **Nothing** (arg omitted) → full interactive browser

Fuzzy resolution uses: `ssh arc-reactor "find /media/myfiles -maxdepth 3 -type d -iname '*<fragment>*'"`. Shortcut names are checked first (exact match takes priority over fuzzy).

### Modes of operation

**Inline — you know (or roughly know) where it goes:**

```bash
arc push MyMovie/ movies           # exact shortcut → instant
arc push MyMovie/ bond             # fuzzy → finds /media/myfiles/movies/James Bond Collection/
arc push report.txt herald         # exact shortcut → /home/herald/
arc pull gold                      # fuzzy → finds Goldfinger dir, downloads to ./
arc pull /var/log/syslog .         # raw path → direct rsync
arc pull configs/reencode-queue.txt ~/bak/    # shortcut + sub-path → direct
```

**Interactive — you want to explore:**

```bash
arc push MyMovie/                  # no destination → browser opens for remote
arc pull                           # no source → browser opens for remote
arc push                           # no args → browser for local file, then remote destination
```

## Interactive browser

Built on fzf with `reload` bindings for smooth in-place directory traversal (no flickering/re-invocation).

### Layout

```
╭─ arc push MyMovie/ — select destination ──────────────────╮
│                                                            │
│  ★ movies      /media/myfiles/movies/                      │
│  ★ tv          /media/myfiles/tv/                          │
│  ★ herald      /home/herald/                               │
│  ★ configs     /home/kyledenis/configs/                    │
│  ★ home        /home/kyledenis/                            │
│  ───────────────────────────────────────                   │
│  📁 movies/                                                │
│  📁 tv/                                                    │
│  📁 music/                                                 │
│  📁 photos/                                                │
│                                                            │
│  ↑↓ navigate  → enter dir  ← go up  enter select  esc quit│
╰────────────────────────────────────────────────────────────╯
│ Preview: 3 items — James Bond Collection/  Marvel/  ...    │
```

### Navigation

| Key | Action |
|-----|--------|
| ↑↓ | Move selection |
| → or Tab | Descend into highlighted directory |
| ← or Backspace | Go up one level |
| Enter | Select current directory (push) or file (pull) |
| Type | Fuzzy filter current listing |
| Esc | Cancel |

### Pinned shortcuts

Always visible at the top of the browser regardless of current directory. Selecting a pin jumps to that directory instantly.

### Performance

Directory tree is pre-fetched in a single SSH call (`find` with depth limit). Navigation within the pre-fetched tree is instant (no SSH roundtrips). Deeper navigation triggers on-demand fetches. SSH ControlMaster is used for connection reuse.

## Transfer engine

All transfers use rsync:

```bash
rsync -ah --progress --partial "$source" "$dest"
```

- `-a` — archive mode (preserves permissions, recurses directories)
- `-h` — human-readable sizes
- `--progress` — per-file transfer progress with speed and ETA
- `--partial` — keep partial transfers for resume on interruption

For push: `rsync -ah --progress --partial "$local_path" "${ARC_HOST}:${remote_path}/"`
For pull: `rsync -ah --progress --partial "${ARC_HOST}:${remote_path}" "${local_dest}"`

## Components

### Files to create/modify

| File | Change |
|------|--------|
| `stow/zsh/.config/zsh/functions.zsh` | Add `arc()` function and helpers (`_arc_browse`, `_arc_resolve_shortcut`) |
| `scripts/rogue.sh` | Add `show_transfer()` section documenting arc commands |

### Function structure

```
arc()                          — main dispatcher (push/pull/ls/df)
├── _arc_resolve_path()        — resolve shortcut, fuzzy fragment, or raw path
├── _arc_browse_remote()       — fzf-based remote directory browser
├── _arc_browse_local()        — fzf-based local file picker
├── _arc_push()                — rsync upload with progress
└── _arc_pull()                — rsync download with progress
```

### `_arc_resolve_path()` — the smart resolver

Central to both push and pull. Takes a user-provided string and returns a full remote path:

```
_arc_resolve_path(input)
│
├── starts with / → return as-is (raw path)
├── contains / and prefix matches shortcut → resolve shortcut + append sub-path
├── exact shortcut match → return shortcut path
├── else → fuzzy search: ssh find -iname '*input*'
│   ├── 0 matches → return empty (caller decides: browse or error)
│   ├── 1 match  → return it directly (no interaction)
│   └── N matches → quick fzf picker with just the matches → return selection
```

### `arc push` flow

```
arc push [local_path] [remote_dest]
│
├── local_path provided?
│   ├── yes → validate it exists
│   └── no  → _arc_browse_local() → pick file/dir
│
├── remote_dest provided?
│   ├── yes → _arc_resolve_path(remote_dest)
│   │   ├── resolved → use it
│   │   └── empty (no matches) → _arc_browse_remote(ARC_DEFAULT)
│   └── no  → _arc_browse_remote(ARC_DEFAULT) → pick directory
│
└── rsync -ah --progress --partial "$local" "${ARC_HOST}:${remote}/"
```

### `arc pull` flow

```
arc pull [remote_source] [local_dest]
│
├── remote_source provided?
│   ├── yes → _arc_resolve_path(remote_source)
│   │   ├── resolved to directory → _arc_browse_remote(resolved_path) → pick file/dir
│   │   ├── resolved to file → use directly (no browse)
│   │   └── empty (no matches) → _arc_browse_remote(ARC_DEFAULT)
│   └── no  → _arc_browse_remote(ARC_DEFAULT) → pick file/dir
│
├── local_dest provided?
│   ├── yes → use as-is
│   └── no  → current directory
│
└── rsync -ah --progress --partial "${ARC_HOST}:${remote}" "$local/"
```

### `arc ls` flow

Opens the interactive browser without initiating a transfer. Useful for exploring what's on the server.

```
arc ls [shortcut_or_path]
│
├── argument provided?
│   ├── starts with / → _arc_browse_remote(path) → display only
│   ├── matches shortcut → _arc_browse_remote(shortcut_path) → display only
│   └── no  → _arc_browse_remote(ARC_DEFAULT) → display only
│
└── prints selected path (useful for piping)
```

### `arc df`

Simple remote disk usage check:

```bash
ssh arc-reactor "df -h / | tail -1"
```

### `_arc_browse_remote()` implementation approach

Uses fzf `reload` action to navigate directories without restarting fzf:

```bash
_arc_browse_remote() {
    local start_dir="${1:-$ARC_DEFAULT}"
    local mode="${2:-dir}"  # "dir" for push destinations, "file" for pull sources
    local current="$start_dir"

    # Pre-fetch directory tree for fast initial navigation
    local tree_cache
    tree_cache=$(ssh "$ARC_HOST" "find '$start_dir' -maxdepth 3 -type d 2>/dev/null" | sort)

    # Build pinned entries
    local pins=""
    for key in "${(@k)ARC_SHORTCUTS}"; do
        pins+="★ ${key}|${ARC_SHORTCUTS[$key]}"$'\n'
    done

    # fzf with reload bindings for directory traversal
    # → (right arrow): descend into directory
    # ← (left arrow): go up one level
    # Enter: select current item
    # Preview: show contents of highlighted directory
    ...
}
```

The full implementation uses `--bind 'right:reload(...)'` to re-populate fzf's list when navigating directories, and `--header` to show the current path. Pins are always prepended to the list.

## rogue documentation

New section added to `rogue.sh` under `show_transfer()`:

```
  File Transfer (arc-reactor)
  ──────────────────────────────
  arc push <file> [dest]    Upload to server (dest: shortcut or path)
  arc pull [source] [local] Download from server
  arc ls [path]             Browse server filesystem
  arc df                    Server disk usage

  Shortcuts: movies, tv, herald, configs, home
  Omit destination to browse interactively with fzf.
```

## Dependencies

- fzf (already installed)
- rsync (already installed on both machines)
- ssh with `arc-reactor` host configured (already set up)

No new dependencies required.

## Edge cases

- **Spaces in filenames**: All paths are quoted. rsync handles this natively.
- **Large directories**: Pre-fetch is depth-limited. Deeper browsing fetches on demand.
- **Connection failure**: SSH failure is caught and reported before entering the browser.
- **Cancelled transfer**: rsync `--partial` preserves progress. Re-running the same command resumes.
- **fzf not installed**: Falls back to raw path mode with a warning.
