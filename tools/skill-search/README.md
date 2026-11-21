# skill-search

Coding agents see installed skills as a flat list of names. Past a few dozen, most are names with no description, and the agent stops finding the one that fits. skill-search files every installed skill by the moment it helps with ("debugging a failure", "about to say work is done", "working with Cloudflare"), gives the agent a short index to read at each step, and lets agents and people search the whole set.

- **Scan.** It finds the skills in `~/.agents/skills` (npx skills), `~/.claude/skills`, enabled Claude Code plugins, `~/.cursor/skills`, `~/.codex/skills` and any extra folders listed in config.
- **Classify.** A judgment model ([Jev](https://typesafe.ai)) answers one question per taxonomy entry for each skill: "Would an AI coding agent that is <when> be better off opening this skill?" Skills marked private are never sent to Jev. An agent files them instead: by hand through the `skill-search` skill, or, with `filer: claude` in config, through a headless Claude Code run with no tools, which sends their text to Anthropic like any other session.
- **Track changes.** Each verdict is keyed by source and name. It stores a hash of exactly what the classifier reads: name, description and section headings. Body edits, version bumps and moved plugin paths cost no calls. A reworded taxonomy entry re-asks that one question for every skill.
- **Render.** It writes `INDEX.md` (one line per moment, about 2k tokens) plus a ranked file per moment with paths and an "ask first" tier for skills that spawn agents, push, deploy or post outside.
- **Search.** `skill-search find <words>` takes a name, a topic or a direction ("make the onboarding feel less like a form"). Typed by hand, `find` can be left out unless the first word is a command name; agents are told to always write it. It ranks skills by meaning and by matching words together, using reciprocal-rank fusion of the two orders. Meaning comes from a local embedding model: by default `text-embedding-qwen3-embedding-0.6b` in LM Studio at `localhost:1234`, set with `embed: {url, model}` or turned off with `embed: none`. Each skill is embedded as its name, description and its two best-fitting moments, and the vectors are cached in `~/.local/state/skill-search/`. Without the server, words alone rank, and a note says why. Private skills are only embedded when the server is on this machine. In a terminal with fzf it opens a picker with a preview; piped or run by an agent, it prints one block per skill, or JSON with `--json`. `node test/eval-search.ts` scores the ranking on 16 queries against the live map.
- **Stay current.** `skill-search hook --wait`, run on SessionStart and before each subagent starts, checks file stats in about 0.2 seconds and refreshes when anything changed. It waits up to 15 seconds, and a classifier outage is not retried for 15 minutes unless a skill changes.

```
npm install && npm run build
node skill/scripts/skill-search.mjs init
node skill/scripts/skill-search.mjs sync
```

The `skill/` folder is an agent skill that walks through setup and upkeep, with the CLI bundled in `skill/scripts/`.

`research/` holds the evaluation: full reads of 312 skills, an answer key, and scoring scripts. It stays on the machine that made it and out of git, because it quotes private skills in full. On that key, v1.2 has a pooled AUC of 0.897, and the primary activity is in a skill's top three for 81% of skills. `research/ab.ts` A/B tests a reworded question against the key before it ships.
