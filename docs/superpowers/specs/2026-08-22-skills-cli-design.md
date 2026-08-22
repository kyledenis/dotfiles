# `skills` — one front door for AI agent skills

## Overview

Today, `skills-sync` distributes a canonical store (`~/.skills`) to `~/.claude/skills` and
`~/.cursor/skills`, transforming frontmatter per tool. It does that job well. What it cannot do
is tell you where any skill came from, or update one.

That gap is the whole problem. Of the 27 skills in `~/.skills`, roughly 18 were copied out of
somebody else's repo — `emilkowalski/skill`, `kylezantos/design-motion-principles`, and batches
from Vercel, Trail of Bits, Sentry, OpenAI and GSAP. Their provenance survives only in git commit
subjects. They are frozen at whatever they were the day they were copied, and there is no
mechanism, and no record, that would let them move.

Meanwhile two other channels have appeared that already solve updating, each with its own
incantation:

- **Claude Code plugins** — `claude plugin update <id>`, auto-resolving from marketplaces.
  35 installed.
- **The `skills` npm CLI** (`npx skills`, v1.5.23) — the agentskills.io open standard's reference
  tool: `add`, `update`, `find`, `skills-lock.json`.

So the friction is not a missing updater. It is that three updaters exist and nothing knows which
one owns which skill, so the knowledge lives in your head.

**Design principle: be the front door, not a fourth package manager.** `skills` learns which
channel each skill belongs to and drives the right mechanism for each. It reimplements nothing
that already works, and it owns exactly one thing nobody else can do — tracking a *vendored fork*
against its upstream.

### Non-goals

- Replacing `npx skills` as a registry or discovery mechanism. `skills find` shells out to it.
- Replacing the plugin system. Plugins that are plugins stay plugins.
- Managing project-scoped (`.claude/skills/`) skills. User scope only.
- Publishing skills anywhere. `~/.skills` pushes to GitHub via plain git.

## The three channels

| Channel | Lives in | Updated by | Count today |
|---------|----------|-----------|-------------|
| **mine** | `~/.skills/<name>/` | you, via git | ~9 |
| **upstream** | `~/.skills/<name>/` with a `source:` pin | `skills update` | ~18 |
| **plugins** | `~/.claude/plugins/cache/` | `claude plugin update` | 35 |

The 9/18 split of the 27 is an estimate read off commit subjects, not a measurement — nothing
records it today, which is the point. Phase 2 establishes the real number.

`mine` and `upstream` share a directory and a git history deliberately. A vendored skill you have
edited is a fork, and a fork belongs in your repo, synced by your transform, not in a second tree
owned by another tool. The only difference between the two channels is whether a `source:` block
is present.

## Interface

### Subcommands

| Command | Description |
|---------|-------------|
| `skills` | Three-channel status dashboard. Read-only. |
| `skills list` | Full registry table — name, version, source, targets |
| `skills sync` | Distribute `~/.skills` → tool directories |
| `skills update [name...]` | Pull every channel forward; report what changed and why |
| `skills add <repo>` | Vendor a skill from a git repo, pinned |
| `skills diff <name>` | Show how your fork differs from its pinned upstream |
| `skills merge <name>` | Three-way merge upstream changes into a fork |
| `skills new <name>` | Scaffold a new skill (today's `skills-create`) |
| `skills import [name...]` | Adopt unmanaged skills out of tool dirs into `~/.skills`. Bare form walks every unmanaged skill interactively, as today's `--import` does; named form takes just those. |
| `skills adopt <name> <repo>` | Backfill a `source:` pin onto an already-vendored skill |
| `skills find [query]` | Search the ecosystem — delegates to `npx skills find` |
| `skills doctor` | Report drift, duplicates, and un-vendoring opportunities |
| `skills help` | Usage |

Flags that exist today move under `sync`, unchanged in meaning:
`skills sync --dry-run --tool claude --prune --verbose`.

### Bare `skills` — the dashboard

Read-only, always. A bare noun must never rewrite `~/.claude/skills`.

```
$ skills

  MINE       ~/.skills                          9 skills
             clean · ↑2 unpushed

  UPSTREAM   18 vendored · 4 have moved
             gsap-react            a3f21c → 9d40b1
             react-best-practices  71c0ea → e02f18
             emil-design-eng       a3f21c → 9d40b1   forked
             sentry-code-review    3b1f0a → 88ce41

  PLUGINS    claude · 2 marketplaces            35 installed
             22 enabled · 13 disabled

  DRIFT      11 unmanaged in ~/.claude/skills
             1 duplicate across channels

  skills update · sync · doctor
```

Network calls are the cost here. `git fetch` per distinct upstream repo (18 skills across ~6 repos)
plus one `claude plugin list --json` (local, no network). To keep the bare command instant, the
upstream row is served from a cache written by the last `skills update`, annotated with its age;
`skills --refresh` forces a fetch. Cache staleness over 24h is shown as `(checked 3d ago)`.

### `skills update`

The centrepiece. Runs all three channels and explains itself.

```
$ skills update

  MINE
  ✓ ~/.skills            git pull → already up to date
                         2 local commits unpushed

  UPSTREAM               6 repos fetched
  ✓ gsap-react           a3f21c → 9d40b1   clean, updated
      · feat: useGSAP() replaces manual context cleanup
      · docs: drop React 17 guidance
  ✓ react-best-practices 71c0ea → e02f18   clean, updated
      · fix: correct useMemo advice under the React 19 compiler
  ✓ sentry-code-review   3b1f0a → 88ce41   clean, updated
      · chore: split rules into reference files
  ⚠ emil-design-eng      a3f21c → 9d40b1   FORKED — not touched
      · feat: add section on optimistic UI
      · chore: reword intro
      your copy: SKILL.md +12 −3
      → skills diff emil-design-eng   ·   skills merge emil-design-eng
    14 already current

  PLUGINS
  ✓ superpowers          6.3.0 → 6.4.1
  ✓ figma                2.2.96 → 2.3.0
    33 already current
    restart Claude Code to apply

  3 updated · 1 needs review · 2 plugins updated
```

The commit subjects are load-bearing, not decoration. "It updated" tells you nothing; "the author
replaced `gsap.context()` with `useGSAP()`" tells you whether to re-read the skill before you next
lean on it.

## Provenance

A vendored skill declares its origin in its own frontmatter. Self-describing beats a central
lockfile: copy the directory to another machine and it still knows where it came from.

```yaml
---
name: emil-design-eng
description: >-
  This skill encodes Emil Kowalski's philosophy on UI polish...
version: "1.0"
targets: [claude, cursor]
category: creative
source:
  url: https://github.com/emilkowalski/skill.git
  path: .
  ref: main
  sha: a3f21c8e4b19d0c7f2a5e83b6d41907c2ff8e1ab
  hash: 9d40b1c7e2f8a3562b09dd41f7e8c05a3b12de49
  fetched_at: 2026-01-14
---
```

No `source:` block means you wrote it. That is the entire channel test.

One companion file: `~/.skills/.skills-ignore`, newline-delimited skill names that `doctor` should
stop reporting as unmanaged. Skills installed into a tool directory by something else — the
`*-environments` set, anything from `npx skills` — belong there. Comments with `#`, committed with
the repo.

`source:` never reaches a tool directory. `transform_frontmatter()` already filters frontmatter to
an allow-list per tool (`name description version` for claude), so provenance is stripped on sync
for free. No extra work, and no leaking internal bookkeeping into what the agent reads.

### The pristine hash

`hash` is what makes silent auto-update safe. It records what the skill hashed to at fetch time,
so a later comparison answers one question exactly: *have I edited this since?*

```
normalised_hash(dir) =
    for SKILL.md:  strip frontmatter keys {source, targets, category} via yq,
                   re-serialise, concatenate body
    for others:    file contents verbatim
    sha256 over the sorted file list
```

The three stripped keys are ours, added on adoption — upstream never sets them. Normalising through
`yq` on both sides means formatting differences between upstream's YAML and ours cannot produce a
false "forked" reading.

- `normalised_hash(local) == source.hash` → pristine. Overwriting loses nothing. Update silently.
- `normalised_hash(local) != source.hash` → a fork. Never write. Report and offer the diff.

## The upstream channel

### Clone cache

```
${XDG_CACHE_HOME:-$HOME/.cache}/rogue-skills/repos/<host>/<owner>/<repo>/
```

Cloned with `git clone --filter=blob:none` — a blobless partial clone. **Not** `--depth`, which
would break `git log <pinned-sha>..HEAD` and cost us the changelog that is the point of the feature.
Blobs are fetched on demand, so a skills repo costs kilobytes until something is actually read.

One clone serves all three needs: the pristine copy (`git show <sha>:<path>`), the new copy
(`git show <remote_sha>:<path>`), and the subjects between them.

### Update algorithm, per skill

1. Ensure clone exists; `git fetch origin <ref>`.
2. `remote_sha = git rev-parse origin/<ref>`. If equal to `source.sha`, up to date — stop.
3. `subjects = git log --oneline --no-merges <source.sha>..<remote_sha> -- <path>`.
   If empty, the repo moved but this skill did not — bump `source.sha` silently, no output.
4. If `normalised_hash(local) == source.hash`:
   copy `<path>@remote_sha` over the local directory, re-apply our `source`/`targets`/`category`
   keys, set `source.sha = remote_sha`, `source.hash = normalised_hash(new)`, `fetched_at = today`.
   Print `✓` with subjects.
5. Otherwise: print `⚠ FORKED`, subjects, and a diffstat of `local` against `<path>@source.sha`.
   Write nothing.

Every write lands in `~/.skills`, so `git diff` in that repo is the real audit trail and
`git checkout` is the undo. `skills update` does not commit — it leaves the working tree dirty on
purpose, so you review before the change reaches your agents.

### `skills merge`

Three-way, using material already in the cache:

```
git merge-file  local/SKILL.md  cache@source.sha:SKILL.md  cache@remote_sha:SKILL.md
```

Base, ours and theirs are all to hand, so `git merge-file` does the work; conflicts land as
standard markers for you to resolve. On a clean merge the pin advances and `hash` is recomputed
from the merged file — which correctly marks it as still forked, because it is.

### `skills add`

```
skills add emilkowalski/skill                          # owner/repo → GitHub
skills add vercel-labs/agent-skills -s react-best-practices
skills add https://github.com/foo/bar --path skills/baz
```

Clone into the cache, locate `SKILL.md` (repo root, or `--path`, or interactive pick when several
exist), copy into `~/.skills/<name>/`, add `targets`/`category` interactively, write the `source:`
pin at current HEAD. Then sync.

## The plugins channel

`claude plugin list --json` returns installed plugins with `id`, `version`, `scope` and `enabled`,
but no notion of "outdated" — and 13 of the 35 report `"version": "unknown"`, so a version
comparison would be fiction. Do not compute outdatedness. Just run the update for each installed
user-scope plugin (34 of the 35; `ralph-wiggum` is project-scoped) and report what the CLI says:

```
for id in $(claude plugin list --json | yq -p json '.[] | select(.scope=="user") | .id'); do
    claude plugin update "$id" --scope user
done
```

Running 34 commands instead of making you remember one is precisely the toil this command exists to
absorb. Plugins are read-only to `skills` in every other respect.

## `skills doctor`

Everything the dashboard summarises as `DRIFT`, itemised with a fix for each. Checks, with what
each finds today:

1. **Unmanaged** — in a tool directory, absent from `~/.skills`. *11:* `brainstorm`, `engram`,
   `improve`, `make-interfaces-feel-better`, and the seven `*-environments` skills.
   → `skills import <name>`, or add to `~/.skills/.skills-ignore`.
2. **Uncommitted** — untracked directories in `~/.skills`. *6:* `animation-vocabulary`,
   `apple-design`, `find-animation-opportunities`, `improve-animations`, `mathlens`,
   `swiftui-expert-skill`. → commit them.
3. **Unclassified** — no `source:`, but not written by you either. → `skills adopt <name> <repo>`.
4. **Duplicated across channels** — *1:* `swiftui-expert-skill` is vendored in `~/.skills` **and**
   installed as the plugin `swiftui-expert@swiftui-expert-skill` v2.5.0. The plugin is the
   maintained one. → drop the vendored copy.
5. **Now available as a plugin** — cross-references `claude plugin list --available --json`
   (254 entries) against vendored skill names and descriptions. Finds `sentry` against
   `sentry-code-review`. Also surfaces `mattpocock-skills` (26,177 installs, not installed) —
   distributed as a plugin *specifically* so it never needs manual syncing.
   → un-vendor and `claude plugin install`.
6. **Destination drift** — `tool_hash` in `.skills-sync.json` no longer matches the tool directory,
   meaning you edited `~/.claude/skills/<x>` in place and the next sync will overwrite it.
   → `skills import <name>` to pull the edit back into canon.
7. **Stale fork** — upstream has moved on a skill you have edited. → `skills merge <name>`.

Exit code 0 when clean, 1 when anything is found, so it can run from a hook.

## Components

### Files to create

| File | Responsibility |
|------|----------------|
| `scripts/skills.sh` | Front door: arg dispatch, dashboard, `doctor`, `update` orchestration |
| `scripts/lib/skills-common.sh` | Frontmatter read/transform, hashing, manifest I/O, colours |
| `scripts/lib/skills-upstream.sh` | Clone cache, pin read/write, fetch, changelog, diff, merge |
| `scripts/lib/skills-plugins.sh` | `claude plugin` wrappers, marketplace cross-reference |

### Files to modify

| File | Change |
|------|--------|
| `scripts/skills-sync.sh` | Becomes the sync **engine** only. Extract shared helpers to `lib/skills-common.sh`; drop `--list` and `--import` (they move to `skills list` / `skills import`). ~26KB → ~12KB. |
| `scripts/skills-create.sh` | Unchanged internals; invoked by `skills new` |
| `stow/zsh/.config/zsh/functions.zsh` | Add `skills()` at ~L1379; keep `skills-sync()`/`skills-create()` as deprecating shims; add `skills)` to the `dotfiles` dispatcher at ~L525 |
| `scripts/rogue.sh` | Rewrite `show_skills()` (L180) |
| `scripts/deploy.sh` | L320 → `skills.sh sync` |
| `bootstrap/bootstrap.sh` | L286–294 → `skills sync` |
| `README.md` | L49–56, L148–149 |

Splitting `skills-sync.sh` is not incidental tidying. Three new commands need its frontmatter and
hashing helpers, and a 26KB script that also has to grow an upstream channel is the wrong shape.
The extraction is scoped to moving existing functions unchanged.

### Backward compatibility

`skills-sync` keeps working, with a notice:

```
$ skills-sync --list
⚠ skills-sync is now `skills`. Running `skills list`.
  (this shim will stay, but `skills` is the command)
```

Flag mapping: bare → `sync`, `--list` → `list`, `--import` → `import`, `--dry-run`/`--tool`/
`--prune`/`--verbose` → passed through to `sync`. `skills-create` → `skills new`.

### The name

`skills` is also the binary name of the npm package. The shell function shadows it on `PATH`. This
is deliberate and harmless — the design only ever invokes the npm tool as `npx skills`, never bare.
Worth recording so a future you does not spend an afternoon on it.

## Migration

Ordered so nothing breaks midway and each phase is independently useful.

**Phase 0 — clean the slate.** Commit the 6 untracked skills. Decide `swiftui-expert-skill`:
the plugin supersedes it, so remove the vendored copy.

**Phase 1 — the front door.** `scripts/skills.sh` with `list`, `sync`, `new`, `import`, `help`,
plus a dashboard covering `mine` and `plugins`. Shims and call sites updated. Behaviour-identical
to today, better organised. The `upstream` row reads "18 unclassified".

**Phase 2 — provenance.** `skills adopt`, and backfill the 18. Known from commit subjects:
`emil-design-eng` ← `emilkowalski/skill`; `design-motion-principles` ←
`kylezantos/design-motion-principles`. The `f3f3256` batch of 9 (Vercel, Trail of Bits, Sentry,
OpenAI, GSAP, gstack) and the `5b3917c` batch of 9 need their repos identified by hand — one
session's work, done once.

`adopt` recovers the true original SHA where it can: walk `git log --format=%H -- <path>` on the
upstream and compare each commit's `normalised_hash` against the local copy. An untouched vendored
skill will match exactly, which recovers the real pin. On no match, pin to current HEAD and record
`hash` as today's local value — declaring the present state the baseline. That is honest but lossy,
and `adopt` should say which of the two happened.

**Phase 3 — updating.** `skills update` for the upstream and plugin channels, `skills diff`,
`skills merge`. This is the phase that pays for the whole thing.

**Phase 4 — the rest.** `skills add`, `skills find`, `skills doctor`.

## Testing

`skills-sync.sh` already honours a `SKILLS_DIR` override — the seam is half built. Add matching
overrides for the tool destinations (`SKILLS_TOOL_DEST_CLAUDE`, `SKILLS_TOOL_DEST_CURSOR`) and a
`SKILLS_CACHE_DIR`, so a test can run the whole pipeline against temp directories and never touch
real config.

With that, `bats-core` (`brew install bats-core`, tests in `scripts/tests/`) covers the parts worth
covering, since these are the branches where a mistake destroys work:

- `normalised_hash` is stable across YAML formatting differences and across adding/removing
  `source`/`targets`/`category`
- pristine detection: untouched copy → auto-update; one byte changed in the body → `FORKED`, and
  the local file is byte-identical afterwards
- changelog: empty commit range on a repo that moved elsewhere → silent pin bump, no output
- `sync --prune` leaves skills absent from `.skills-sync.json` untouched (the invariant that lets
  `npx skills` and `skills sync` share `~/.claude/skills`)
- `doctor` exits 1 on a seeded duplicate and 0 on a clean fixture

Everything mutating keeps `--dry-run`.

## `rogue` documentation

`show_skills()` currently hand-duplicates the flag list, which will rot the moment the surface
changes. Reduce it to the verbs and let `skills help` carry the detail:

```
  AI Skills
  ─────────
    skills                Status across all three channels
    skills update         Pull everything forward, with changelogs
    skills sync           Distribute ~/.skills to Claude and Cursor
    skills add <repo>     Vendor a skill from a git repo, pinned
    skills new <name>     Scaffold a new skill
    skills doctor         Find drift, duplicates, and stale forks

    Three channels: yours (~/.skills), vendored upstream (pinned),
    and Claude plugins. `skills help` for the full surface.
```

## Dependencies

- `yq` — already required by `skills-sync.sh`
- `git` — already present; needs `--filter=blob:none` support (git ≥ 2.19, 2026 macOS is fine)
- `claude` CLI — already present; degrade to skipping the plugins channel if absent
- `npx` — only for `skills find`; degrade with a message if absent
- `bats-core` — test-only, optional

No new runtime dependency.

## Edge cases

- **Offline.** `git fetch` and `claude plugin update` fail loudly per channel; the other channels
  still run. The dashboard falls back to cache with its age shown. Never present stale data as fresh.
- **Upstream repo deleted or renamed.** `fetch` fails for that skill only. `doctor` reports it as
  orphaned. The vendored copy is untouched and keeps working — that is the upside of vendoring.
- **Upstream restructures and the skill moves path.** `git log -- <path>` returns empty while the
  repo has clearly moved. Treat an empty range on a repo whose HEAD advanced past ~50 commits as
  suspicious and flag it in `doctor` rather than silently bumping the pin forever.
- **Two skills from one repo.** Keyed by URL, so they share one clone and one fetch.
- **A vendored skill you renamed locally.** `source.path` records the upstream directory, so the
  local name is free to differ.
- **`npx skills` writing into `~/.claude/skills`.** Safe: `--prune` iterates only names present in
  `.skills-sync.json`, so anything another tool installed is invisible to it. Verified against the
  current implementation. Preserve this invariant — a test guards it.
- **Frontmatter without a closing `---`.** Current helpers return empty and the skill silently
  syncs wrong. `doctor` should catch malformed frontmatter explicitly.
- **`yq` reformatting upstream YAML.** Only the *normalised* form is hashed, and the file written
  to `~/.skills` is upstream's bytes with our keys merged in — not a full yq round-trip — so
  upstream formatting survives.
