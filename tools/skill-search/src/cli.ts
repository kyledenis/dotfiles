import { spawn, spawnSync } from "node:child_process";
import { closeSync, copyFileSync, existsSync, mkdirSync, openSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { home, loadConfig, tilde, type Config } from "./config.ts";
import { batchKey, fileable, filerPrompt, FILING_ENV, parseReply, runFiler, shouldRetry } from "./filer.ts";
import { catalogue, plain, shouldPick } from "./find.ts";
import { jevKey } from "./jev.ts";
import { pick } from "./picker.ts";
import { loadOverrides, render, staleOverrides } from "./render.ts";
import { fingerprint, scan } from "./scan.ts";
import { Searcher } from "./searcher.ts";
import { loadStore, saveStore, storePath } from "./store.ts";
import { execute, plan, record, type AgentAnswer } from "./sync.ts";
import { loadTaxonomy, questions, taxonomyPath } from "./taxonomy.ts";

const USAGE = `skill-search: find the installed agent skill for the moment you are in

  skill-search [words]         search installed skills: a picker in a terminal, a ranked list otherwise (find --help)
  skill-search find [words]    the same, for words that are also command names (skill-search find status)
  skill-search init            create the data folder and print the hook to install
  skill-search sync            classify new or changed skills, then render
  skill-search render          rebuild INDEX.md and the entry files from saved verdicts
  skill-search status          what is filed, pending, unplaced or stale
  skill-search pending         skills waiting for an agent to file them (JSON)
  skill-search record <file>   save an agent's answers for pending skills (JSONL)
  skill-search refresh         sync, then file pending private skills with the configured filer
  skill-search hook            fast change check for a hook; refreshes in the background

options: --dry-run (sync, refresh), --reclassify (sync, refresh: ask again for every skill), --quiet,
         --wait (hook: wait up to 15 s for the refresh to finish), --emit (hook: print INDEX.md as context)
data: $SKILL_SEARCH_DIR or ~/.agents/skill-search`;

const FIND_HELP = `skill-search [words]: find installed skills by what you want to do, or by name

Words can be a skill's name ("clean-copy"), a topic ("flaky test") or a direction ("make the
interface feel calmer"). Skills are ranked by meaning and by matching words together. Meaning
needs a local embedding server (LM Studio at localhost:1234 by default, set with \`embed:\` in
config.yaml); without one, words alone decide and a note on stderr says why.

\`skill-search find [words]\` is the same command, for when a search word is also a command name.
In a terminal with fzf it opens a picker with each skill in a preview pane: type to search,
enter prints the skill's slash command and path, ctrl-y copies the slash command (or the path
when it has none), esc quits.
Otherwise (piped, or run by an agent) it prints the best matches, one block per skill.

Options:
  --plain       print the ranked list even in a terminal
  --json        print the matches as JSON
  --limit <n>   how many matches to print (default 15)

Examples:
  skill-search
  skill-search flaky test
  skill-search make the onboarding feel less like a form
  skill-search "tool calling" --plain
  skill-search swiftui animation --json --limit 5
  skill-search find status

Exits 1 when nothing matches.`;

const { values: flags, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    "dry-run": { type: "boolean" },
    reclassify: { type: "boolean" },
    quiet: { type: "boolean" },
    emit: { type: "boolean" },
    wait: { type: "boolean" },
    locked: { type: "boolean" },
    plain: { type: "boolean" },
    json: { type: "boolean" },
    limit: { type: "string" },
    help: { type: "boolean", short: "h" },
  },
});

const config = loadConfig();
const WAIT_MS = 15_000;
/** One-shot search waits this long for the embedding model, which takes ~15 s to load when LM Studio has unloaded it. */
const QUERY_MS = 20_000;
/** One-shot search embeds stale skills for at most this long; refresh embeds them when the model is loaded, and stale ones still rank. */
const PREPARE_MS = 3_000;
/** How long refresh waits to learn whether the embedding model is loaded. */
const READY_MS = 1_500;
const VECTORS_MS = 120_000;
const SYNC_RETRY_MS = 15 * 60_000;
const log = (...a: unknown[]) => flags.quiet || console.log(...a);
const watched = (c: Config) => [join(c.dataDir, "config.yaml"), join(c.dataDir, "overrides.yaml"), taxonomyPath(c.dataDir)];

function taxonomy() {
  const entries = loadTaxonomy(taxonomyPath(config.dataDir));
  return { entries, qs: questions(entries) };
}

type Synced = { print: string; failed: number; dry: boolean };

async function sync(): Promise<Synced> {
  const print = fingerprint(config, watched(config));
  const { entries, qs } = taxonomy();
  const store = loadStore(config.dataDir);
  const found = scan(config);
  const p = plan(found, store, qs, flags.reclassify);
  const calls = p.jobs.filter((j) => !j.fresh).length;
  log(`${found.length} skills: ${p.unchanged} unchanged, ${p.jobs.length - calls} new or changed, ${calls} with changed questions, ${p.removed.length} removed, ${p.refreshed.length} moved`);
  if (flags["dry-run"]) {
    for (const j of p.jobs) log(`  classify ${j.skill.id}${j.fresh ? "" : ` (${j.qids.length} questions)`}`);
    for (const id of p.removed) log(`  remove   ${id}`);
    return { print, failed: 0, dry: true };
  }
  const out = await execute(p, found, store, qs, config);
  saveStore(config.dataDir, store);
  for (const f of out.failed) log(`  failed ${f.id}: ${f.error}`);
  log(`classified ${out.classified}, left for an agent ${out.pending}, failed ${out.failed.length}`);
  const r = render(store, entries, config);
  log(`rendered ${r.files} entry files; ${r.placed} skills placed, ${r.pending.length} pending, ${r.unplaced.length} with no placement`);
  writeState("last-sync", new Date().toISOString());
  return { print, failed: out.failed.length, dry: false };
}

function cards() {
  const { entries } = taxonomy();
  const list = catalogue(loadStore(config.dataDir), entries, config.render, loadOverrides(config.dataDir), (name) =>
    existsSync(join(home, ".claude/skills", name)),
  );
  return { entries, list };
}

/**
 * Embeds new or changed skills for search by meaning, only when the model is already loaded: the hook waits on
 * this process, and a cold load takes ~15 s. Otherwise search embeds them when it next runs. Best effort: it never
 * fails a sync or holds the change check open.
 */
async function vectors() {
  if (!config.embed || flags["dry-run"]) return;
  const { entries, list } = cards();
  const s = new Searcher(list, entries, config);
  const stale = s.stale();
  if (!stale) return;
  if (!(await s.ready(READY_MS))) return log(`vectors: ${stale} left for search to embed`);
  const down = await s.prepare(VECTORS_MS);
  log(down ? `vectors not updated: ${down}` : `vectors: embedded ${stale}`);
}

/** Files the skills an agent has to file. `left` counts those still waiting, so the caller keeps the change check open for them. */
async function file(): Promise<{ left: number; failed: boolean }> {
  const filer = config.filer;
  if (!filer) return { left: 0, failed: false };
  const { entries, qs } = taxonomy();
  const store = loadStore(config.dataDir);
  const hasKey = config.classifier === "jev" && !!jevKey(config);
  const ids = fileable(store, config, hasKey, filer.max);
  if (!ids.length) return { left: 0, failed: false };
  const key = batchKey(ids, store);
  if (!shouldRetry(readState("filer-failed"), key, Date.now())) {
    log(`filing: ${ids.length} skills wait a day after a failed attempt (${ids.join(", ")})`);
    return { left: ids.length, failed: false };
  }
  log(`filing ${ids.length} skills with ${filer.command} (${filer.model}): ${ids.join(", ")}`);
  let failed = false;
  try {
    const skills = ids.map((id) => ({ id, text: readFileSync(store.skills[id].path, "utf8") }));
    const reply = await runFiler(filer, filerPrompt(skills, entries));
    const res = record(store, qs, parseReply(reply, store, ids));
    saveStore(config.dataDir, store);
    for (const r of res.rejected) log(`  rejected ${r.id}: ${r.why}`);
    const unanswered = ids.filter((id) => !res.applied.includes(id) && !res.rejected.some((r) => r.id === id));
    if (unanswered.length) log(`  unanswered: ${unanswered.join(", ")}`);
    const r = render(store, entries, config);
    log(`filed ${res.applied.length} of ${ids.length}; ${r.pending.length} pending`);
    failed = res.applied.length < ids.length;
  } catch (e) {
    log(`  filing failed: ${e instanceof Error ? e.message : e}`);
    failed = true;
  }
  if (failed) writeState("filer-failed", `${key} ${new Date().toISOString()}`);
  return { left: fileable(loadStore(config.dataDir), config, hasKey).length, failed };
}

/** Saves the change check once nothing is left to do. A classifier failure keeps it open but is not retried by the hook for a while. */
function settle(s: Synced, left: number) {
  if (s.failed) writeState("sync-failed", `${s.print} ${new Date().toISOString()}`);
  else if (!left) writeState("fingerprint", s.print);
}

async function withLock(fn: () => Promise<number>): Promise<number> {
  if (!flags.locked) {
    if (locked()) return console.log("a sync is already running"), 1;
    writeState("sync.lock", String(process.pid));
  }
  try {
    return await fn();
  } finally {
    try {
      unlinkSync(join(config.stateDir, "sync.lock"));
    } catch {}
  }
}

function writeState(name: string, value: string) {
  mkdirSync(config.stateDir, { recursive: true });
  writeFileSync(join(config.stateDir, name), value + "\n");
}

function readState(name: string): string | undefined {
  const f = join(config.stateDir, name);
  return existsSync(f) ? readFileSync(f, "utf8").trim() : undefined;
}

function locked(): boolean {
  const pid = Number(readState("sync.lock"));
  if (!pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

/** Refreshes when anything the map depends on changed. --wait finishes the refresh before returning, so the caller reads a current map. */
async function hook(): Promise<number> {
  if (process.env[FILING_ENV]) return 0;
  const print = existsSync(storePath(config.dataDir)) && !locked() ? fingerprint(config, watched(config)) : undefined;
  if (print && print !== readState("fingerprint") && shouldRetry(readState("sync-failed"), print, Date.now(), SYNC_RETRY_MS)) {
    mkdirSync(config.stateDir, { recursive: true });
    const out = openSync(join(config.stateDir, "sync.log"), "a");
    const child = spawn(process.execPath, [process.argv[1], "refresh", "--locked"], { detached: true, stdio: ["ignore", out, out] });
    writeState("sync.lock", String(child.pid));
    closeSync(out);
    if (flags.wait) await Promise.race([new Promise((done) => child.on("close", done)), new Promise((done) => setTimeout(done, WAIT_MS).unref())]);
    child.unref();
  }
  if (flags.emit) {
    const index = join(config.dataDir, "INDEX.md");
    if (existsSync(index))
      process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: readFileSync(index, "utf8") } }));
  }
  return 0;
}

const COMMANDS = new Set(["find", "init", "sync", "render", "status", "pending", "record", "refresh", "hook"]);

function picking(): boolean {
  const fzf = spawnSync("sh", ["-c", "command -v fzf"]).status === 0;
  return shouldPick({ json: flags.json, plain: flags.plain, stdinTTY: !!process.stdin.isTTY, stdoutTTY: !!process.stdout.isTTY, fzf });
}

async function find(words: string[]): Promise<number> {
  if (flags.help) return console.log(FIND_HELP), 0;
  const limit = flags.limit === undefined ? 15 : Number(flags.limit);
  if (!Number.isInteger(limit) || limit < 1) {
    console.error(`--limit takes a whole number above 0, not "${flags.limit}".\n  skill-search ${words.join(" ") || "<words>"} --limit 5`);
    return 2;
  }
  const query = words.join(" ");
  const { entries, list } = cards();
  const searcher = new Searcher(list, entries, config);
  if (picking()) {
    const p = await pick(searcher, query);
    switch (p.kind) {
      case "quit":
        return 0;
      case "copy": {
        const copied = p.card.invoke ?? p.card.path;
        spawnSync("pbcopy", { input: copied });
        console.log(`copied: ${copied}`);
        return 0;
      }
      case "print":
        console.log([...(p.card.invoke ? [`invoke: ${p.card.invoke}`] : []), `path: ${p.card.path}`].join("\n"));
        return 0;
    }
  }
  await searcher.prepare(PREPARE_MS);
  const r = await searcher.query(query, QUERY_MS);
  if (r.mode.by === "words" && r.mode.why && r.mode.why !== "off" && !flags.quiet) console.error(`searched by words only: ${r.mode.why}`);
  if (!r.cards.length) {
    console.error(`No skill matches "${query}".\n  skill-search <fewer or broader words>\n  skill-search --plain --limit ${list.length}   lists every skill`);
    return 1;
  }
  process.stdout.write(flags.json ? JSON.stringify(r.cards.slice(0, limit), null, 1) + "\n" : plain(r.cards, limit));
  return 0;
}

function status(): number {
  const { entries, qs } = taxonomy();
  const store = loadStore(config.dataDir);
  const found = scan(config);
  const p = plan(found, store, qs);
  const r = render(store, entries, config);
  const stale = staleOverrides(loadOverrides(config.dataDir), store);
  const by: Record<string, number> = {};
  for (const v of Object.values(store.skills)) by[v.by || "none"] = (by[v.by || "none"] ?? 0) + 1;
  const empty = entries.filter((e) => !Object.values(store.skills).some((v) => (v.p[e.id] ?? 0) >= (e.axis === "activity" ? config.render.minP : config.render.domainMinP)));
  console.log(`data        ${tilde(config.dataDir)}`);
  console.log(`taxonomy    ${tilde(taxonomyPath(config.dataDir))} (${entries.length} entries)`);
  console.log(`skills      ${Object.keys(store.skills).length} saved, ${found.length} installed`);
  console.log(`classified  ${Object.entries(by).map(([k, n]) => `${k} ${n}`).join(", ")}`);
  console.log(`out of date ${p.jobs.length} to classify, ${p.removed.length} to remove, ${p.refreshed.length} moved`);
  console.log(`pending     ${r.pending.length}${r.pending.length ? ": " + r.pending.join(", ") : ""}`);
  console.log(`unplaced    ${r.unplaced.length}${r.unplaced.length ? ": " + r.unplaced.join(", ") : ""}`);
  console.log(`empty       ${empty.map((e) => e.id).join(", ") || "none"}`);
  console.log(`overrides   ${stale.length ? "stale: " + stale.join(", ") : "ok"}`);
  console.log(`last sync   ${readState("last-sync") ?? "never"}`);
  return 0;
}

function pending(): number {
  const { entries } = taxonomy();
  const store = loadStore(config.dataDir);
  const skills = Object.entries(store.skills)
    .filter(([, v]) => v.pending?.length)
    .map(([id, v]) => ({ id, name: v.name, path: v.path, input: v.input }));
  const answer = { id: "<skill id>", input: "<input from above>", activities: ["<ids>"], domains: ["<ids>"], primary: "<one activity id>", fx: ["spawns|pushes|external"] };
  const vocabulary = entries.map(({ id, axis, when, yes, no }) => ({ id, axis, when, ...(yes && { yes }), ...(no && { no }) }));
  console.log(JSON.stringify({ skills, answer, taxonomy: vocabulary }, null, 1));
  return 0;
}

function recordFile(file: string): number {
  const { entries, qs } = taxonomy();
  const store = loadStore(config.dataDir);
  const answers = readFileSync(file, "utf8").split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l) as AgentAnswer);
  const res = record(store, qs, answers);
  saveStore(config.dataDir, store);
  for (const r of res.rejected) console.log(`rejected ${r.id}: ${r.why}`);
  const r = render(store, entries, config);
  console.log(`recorded ${res.applied.length}, rejected ${res.rejected.length}; ${r.pending.length} still pending`);
  return res.rejected.length ? 1 : 0;
}

function init(): number {
  mkdirSync(config.dataDir, { recursive: true });
  const tax = join(config.dataDir, "taxonomy.yaml");
  if (!existsSync(tax)) copyFileSync(taxonomyPath("/nonexistent"), tax);
  const cfg = join(config.dataDir, "config.yaml");
  if (!existsSync(cfg))
    writeFileSync(cfg, ["# skill-search settings. Patterns match skill ids such as npx:how or plugin:vercel/ai-sdk.", "exclude: []", "private: []", "classifier: jev", ""].join("\n"));
  console.log(`data folder ready: ${tilde(config.dataDir)}`);
  console.log(`Claude Code SessionStart hook command:\n  ${process.execPath} ${process.argv[1]} hook`);
  return 0;
}

async function main(): Promise<number> {
  const [cmd, arg] = positionals;
  if (cmd === "find") return find(positionals.slice(1));
  if (cmd && !COMMANDS.has(cmd)) return find(positionals);
  if (!cmd && !flags.help && (flags.plain || flags.json || picking())) return find([]);
  if (flags.help || !cmd) return console.log(USAGE), 0;
  if (cmd === "sync")
    return withLock(async () => {
      const s = await sync();
      if (!s.dry) settle(s, 0);
      await vectors();
      return s.failed ? 1 : 0;
    });
  if (cmd === "refresh")
    return withLock(async () => {
      const s = await sync();
      if (s.dry) return 0;
      const f = await file();
      settle(s, f.left);
      await vectors();
      return s.failed || f.failed ? 1 : 0;
    });
  if (cmd === "render") {
    const r = render(loadStore(config.dataDir), taxonomy().entries, config);
    return console.log(`rendered ${r.files} entry files; ${r.placed} placed, ${r.pending.length} pending, ${r.unplaced.length} unplaced`), 0;
  }
  if (cmd === "status") return status();
  if (cmd === "pending") return pending();
  if (cmd === "record" && arg) return recordFile(arg);
  if (cmd === "hook") return hook();
  if (cmd === "init") return init();
  console.log(USAGE);
  return 1;
}

// A piped stdout is written asynchronously, so exit only once it has flushed, or long output is cut off.
const exit = (code: number) => process.stdout.write("", () => process.exit(code));

main().then(
  (code) => exit(code),
  (e) => {
    console.error(`skill-search: ${e instanceof Error ? e.message : e}`);
    process.exit(1);
  },
);
