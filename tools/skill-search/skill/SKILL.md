---
name: skill-search
description: Use when setting up or maintaining skill-search, which files every installed skill by the moment it helps with into a skill map and searches it. Also use when the map's INDEX.md says skills are waiting to be filed, when a skill is filed in the wrong place, or to search installed skills by words (`skill-search <words>`).
---

# Skill search

skill-search lets an agent, or the user, find the right skill without knowing its name. A CLI scans every installed skill, asks a classifier which moments each one helps with, and writes a skill map:

- `INDEX.md`: one line per moment ("debugging a failure", "about to say work is done"), loaded into every session
- `activities/<id>.md` and `domains/<id>.md`: the skills for that moment, ranked, with paths

Change detection is by hash of what the classifier reads (name, description, section headings). Edits to a skill's body, version bumps and moved plugin paths cost nothing. Only new or changed descriptions are classified again.

Run the CLI as `skill-search` when it is on PATH, otherwise as `node <this skill's folder>/scripts/skill-search.mjs`.

## Searching

`skill-search <words>` takes a skill name, a topic or a plain description of what you are about to do ("the context window keeps filling up"), ranks installed skills by meaning and by matching words, and prints one block per skill: name, slash command, moments, full description and path. Add `--json` for JSON and `--limit <n>` for more results. Meaning needs the local embedding server (LM Studio at `localhost:1234` by default, `embed:` in `config.yaml`); without it a line on stderr says the search used words only. In a terminal with fzf it opens a picker with a preview instead. Use `skill-search find <words>` when a word is also a command name, such as `status`.

## First-time setup

Work through these with the user. Each step that edits their configuration needs a yes first.

1. **Create the data folder.** `skill-search init` makes `~/.agents/skill-search/` (or `$SKILL_SEARCH_DIR`) with `config.yaml` and a copy of the default `taxonomy.yaml`, and prints the hook command.
2. **Choose what to scan.** Run `skill-search sync --dry-run` and show the user the count per source (`npx:`, `claude:`, `plugin:<name>/`, `synced:`, `cursor:`, `codex:`). Large groups they never use, such as claude.ai-synced plugins, go in `exclude` in `config.yaml`. Skill folders outside the defaults go in `sources` as `{name, path}`.
3. **Choose the classifier.**
   - With a TypeSafe key (`TYPESAFE_API_KEY`, or `jev.keyFile` in config), public skills are classified by Jev. Each call costs a fraction of a cent.
   - Skills the user wrote, or does not want sent to a third party, go in `private` (patterns such as `claude:*`). Those are filed by you, below.
   - With no key, set `classifier: none` and file every skill yourself.
4. **Build.** `skill-search sync`. Then file whatever is pending (next section).
5. **Load the index.** Ask before each one.
   - Claude Code: add `@~/.agents/skill-search/INDEX.md` to `~/.claude/CLAUDE.md`. Subagents read CLAUDE.md too, so they get the map as well.
   - Claude Code, the scout: symlink `agents/skill-scout.md` from this skill's folder into `~/.claude/agents/`. It is a read-only Haiku agent that reads the map and the matching skills in full, and briefs the agent that dispatched it. Then list, in `CLAUDE.md`, the moves that should dispatch it (starting a task or goal, planning, choosing, building, testing, debugging, reviewing, committing, shipping, saying done, reporting), and say to wait for its brief before making the move it is scouting.
   - Cursor and other agents: add a line to their user rules or `AGENTS.md`: "Whenever you start a task or a new goal, and before you plan, choose, build, test, debug, review, commit, ship or report, read ~/.agents/skill-search/INDEX.md, open the files for the matching lines, and read the skills that fit."
6. **Keep it current.** Offer the hook command that `init` printed, with `--wait` added, on two events in `~/.claude/settings.json`: `SessionStart`, and `PreToolUse` with matcher `^Agent$` so every subagent reads a current map. Give each a 120-second timeout. The hook checks file stats in about 0.2 seconds. When something changed, it starts `skill-search refresh` and waits up to 15 seconds for it, which covers classifying a few dozen skills (about 2 seconds) and a small filing run. Anything slower finishes in the background. A refresh that hit a classifier failure is not retried by the hook for 15 minutes unless a skill changes. Without `--wait` the hook never waits. `sh test/hook-outage.sh` in the repo checks these limits. Show the user the exact JSON before adding it.
7. **File private skills automatically (optional).** With Claude Code installed, add `filer: claude` to `config.yaml` (or `filer: {command: claude, model: sonnet, max: 10}`). `refresh` then files pending private skills through a headless `claude -p` run with no tools, MCP servers or hooks. A batch that fails waits a day before it is tried again. Without a filer, pending skills wait for you (next section).

## Filing pending skills

`skill-search pending` prints JSON with three parts:
- `skills`: id, name, path and input hash for each skill waiting to be filed
- `answer`: the shape to reply in
- `taxonomy`: every entry with its `when` line and any `yes`/`no` boundary

For each pending skill:

1. Read its SKILL.md in full, not only the description. The classifier sees only the description; you can do better.
2. For every entry, ask: "Would an agent that is <when> be better off opening this skill?" Say yes only when the skill has real guidance for that moment, not a passing mention. Several yeses are normal. No domain is fine.
3. Pick one `primary` activity.
4. Mark `fx` for what following the skill does: `spawns` (launches subagents or model runs), `pushes` (commits pushed, PRs opened or merged, deploys), `external` (posts or writes to an outside service).

Write one JSON line per skill to a file, copying `id` and `input` exactly, then run `skill-search record <file>`. A rejected line means the skill changed after you listed it, so list it again.

## Fixing a placement

Put corrections in `~/.agents/skill-search/overrides.yaml`, keyed by skill name, or by full id when two sources share a name:

```yaml
systematic-debugging:
  add: [write-tests]        # pin into an entry
  remove: [review-diff]     # take out of an entry
hyperframes-cli:
  tier: normal              # clear "ask first" when the side-effect guess is wrong
some-noisy-skill:
  hide: true                # keep it out of the map
```

Then run `skill-search render`. Overrides never cost a classifier call. `skill-search status` lists overrides whose skill has gone.

## Changing the taxonomy

Edit `~/.agents/skill-search/taxonomy.yaml`. The `when` line is both the index text and the classifier's question, so reword with care. Only the entries you change are re-asked, for every skill, on the next sync. Use `yes`/`no` lines to sharpen a vague boundary. `skill-search status` lists entries with no skills, which are candidates to merge or drop.

## Checking health

`skill-search status` shows:
- the saved and installed counts
- how each skill was classified
- what is out of date or pending
- skills with no placement
- empty entries and stale overrides
- the last sync time

The hook's log is `~/.local/state/skill-search/sync.log`.
