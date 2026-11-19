import assert from "node:assert/strict";
import { test } from "node:test";
import type { Config } from "../src/config.ts";
import { matches } from "../src/config.ts";
import { batchKey, fileable, filerArgs, filerPrompt, parseReply, shouldRetry } from "../src/filer.ts";
import { catalogue, search, shouldPick } from "../src/find.ts";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { place, risks } from "../src/render.ts";
import type { Found } from "../src/scan.ts";
import { classifierInput, parseSkill, sha } from "../src/skill.ts";
import type { Store, Verdict } from "../src/store.ts";
import { plan, record } from "../src/sync.ts";
import { questions, type Entry } from "../src/taxonomy.ts";

const entries: Entry[] = [
  { id: "debug-failure", axis: "activity", group: "verify", when: "debugging a failure" },
  { id: "write-tests", axis: "activity", group: "build", when: "writing tests" },
  { id: "refactor", axis: "activity", group: "build", when: "refactoring" },
  { id: "typescript", axis: "domain", group: "domains", when: "working in TypeScript" },
];
const qs = questions(entries);
const render: Config["render"] = { activities: 2, minP: 0.5, domains: 1, domainMinP: 0.7, domainMargin: 0.3, fxMinP: 0.5 };

function found(name: string, description: string, body = "", id = `npx:${name}`): Found {
  const s = parseSkill(`---\nname: ${name}\ndescription: ${description}\n---\n${body}`, name);
  const input = classifierInput(s);
  return { id, source: id.split(":")[0], path: `/x/${name}/SKILL.md`, real: `/x/${name}/SKILL.md`, ...s, input, inputHash: sha(input) };
}

function verdict(f: Found, p: Record<string, number> = {}): Verdict {
  return {
    name: f.name, source: f.source, path: f.path, description: f.description, userOnly: false, input: f.inputHash, by: "jev",
    p: Object.fromEntries(qs.map((q) => [q.id, p[q.id] ?? 0.1])), q: Object.fromEntries(qs.map((q) => [q.id, q.hash])), updated: "",
  };
}

test("frontmatter: folded description, user-only flag, headings outside fences", () => {
  const s = parseSkill("---\nname: a\ndescription: >-\n  first line\n  second line\ndisable-model-invocation: true\n---\n## One\n```\n## not a heading\n```\n### Two\n", "dir");
  assert.equal(s.description, "first line second line");
  assert.equal(s.userOnly, true);
  assert.deepEqual(s.headings, ["One", "Two"]);
});

test("frontmatter: invalid yaml falls back to line parsing", () => {
  const s = parseSkill("---\nname: b\ndescription: Use when: things break: badly\n---\n", "dir");
  assert.equal(s.name, "b");
  assert.match(s.description, /things break/);
});

test("plan: only skills whose classifier input changed are re-asked", () => {
  const a = found("a", "debugs things", "## Steps");
  const b = found("b", "writes tests");
  const store: Store = { version: 1, skills: { [a.id]: verdict(a), [b.id]: verdict(b), "npx:gone": verdict(found("gone", "x")) } };
  const bodyOnly = found("a", "debugs things", "## Steps\nnew paragraph that the classifier never sees");
  const edited = found("b", "writes tests first");
  const added = found("c", "refactors");
  const p = plan([bodyOnly, edited, added], store, qs);
  assert.deepEqual(p.jobs.map((j) => j.skill.id).sort(), ["npx:b", "npx:c"]);
  assert.deepEqual(p.removed, ["npx:gone"]);
  assert.equal(p.unchanged, 1);
});

test("plan: a reworded question is re-asked for every skill, alone", () => {
  const a = found("a", "debugs things");
  const store: Store = { version: 1, skills: { [a.id]: verdict(a) } };
  const reworded = questions(entries.map((e) => (e.id === "refactor" ? { ...e, when: "simplifying code" } : e)));
  const p = plan([a], store, reworded);
  assert.equal(p.jobs.length, 1);
  assert.deepEqual(p.jobs[0].qids, ["refactor"]);
  assert.equal(p.jobs[0].fresh, false);
});

test("plan: a moved plugin path costs no classifier call", () => {
  const a = found("a", "debugs things", "", "plugin:x/a");
  const store: Store = { version: 1, skills: { [a.id]: { ...verdict(a), path: "/old/1.0/a/SKILL.md" } } };
  const p = plan([a], store, qs);
  assert.equal(p.jobs.length, 0);
  assert.deepEqual(p.refreshed, ["plugin:x/a"]);
});

test("place: top activities above the floor, capped domains, overrides win", () => {
  const f = found("a", "x");
  const v = verdict(f, { "debug-failure": 0.9, "write-tests": 0.8, refactor: 0.6, typescript: 0.75 });
  assert.deepEqual(place(f.id, v, entries, render).map((p) => p.id), ["debug-failure", "write-tests", "typescript"]);
  const o = { add: ["refactor"], remove: ["write-tests"] };
  assert.deepEqual(place(f.id, v, entries, render, o).map((p) => p.id).sort(), ["debug-failure", "refactor", "typescript"]);
  assert.deepEqual(place(f.id, v, entries, render, { hide: true }), []);
});

test("place: a domain must stand out from the skill's own baseline", () => {
  const many: Entry[] = [...entries, { id: "video", axis: "domain", group: "domains", when: "video" }, { id: "figma", axis: "domain", group: "domains", when: "figma" }];
  const f = found("a", "x");
  const specific = { ...verdict(f, { typescript: 0.75 }), p: { ...verdict(f).p, typescript: 0.75, video: 0.05, figma: 0.05 } };
  assert.ok(place(f.id, specific, many, render).some((p) => p.id === "typescript"));
  const generic = { ...specific, p: { ...specific.p, video: 0.74, figma: 0.73 } };
  assert.ok(!place(f.id, generic, many, render).some((p) => ["typescript", "video", "figma"].includes(p.id)));
});

test("risks: side-effect questions set the ask-first tier, overrides can clear it", () => {
  const f = found("a", "x");
  const v = verdict(f, { "fx-spawns": 0.8 });
  assert.deepEqual(risks(v, render), ["spawns agents"]);
  assert.deepEqual(risks(v, render, { tier: "normal" }), []);
});

test("record: agent answers apply only to the skill version they were made for", () => {
  const a = found("a", "debugs things");
  const store: Store = { version: 1, skills: { [a.id]: { ...verdict(a), pending: qs.map((q) => q.id) } } };
  const stale = record(store, qs, [{ id: a.id, input: "old", activities: ["debug-failure"] }]);
  assert.equal(stale.rejected.length, 1);
  const ok = record(store, qs, [{ id: a.id, input: a.inputHash, activities: ["debug-failure"], primary: "debug-failure", fx: ["spawns"] }]);
  assert.deepEqual(ok.applied, [a.id]);
  assert.equal(store.skills[a.id].p["debug-failure"], 0.9);
  assert.equal(store.skills[a.id].p["fx-spawns"], 0.75);
  assert.deepEqual(store.skills[a.id].pending, []);
});

test("patterns match skill ids", () => {
  assert.ok(matches(["synced:*"], "synced:sales/forecast"));
  assert.ok(!matches(["claude:*"], "npx:claude-api"));
});

function pendingStore(...fs: Found[]): Store {
  return { version: 1, skills: Object.fromEntries(fs.map((f) => [f.id, { ...verdict(f), pending: qs.map((q) => q.id) }])) };
}

test("fileable: private skills are filed, classifier failures wait for the classifier", () => {
  const mine = found("mine", "x", "", "claude:mine");
  const failed = found("failed", "y");
  const done = found("done", "z", "", "claude:done");
  const store = pendingStore(mine, failed);
  store.skills[done.id] = verdict(done);
  const cfg = { private: ["claude:*"] } as Config;
  assert.deepEqual(fileable(store, cfg, true), ["claude:mine"]);
  assert.deepEqual(fileable(store, cfg, false), ["claude:mine", "npx:failed"]);
  assert.deepEqual(fileable(store, cfg, false, 1), ["claude:mine"]);
});

test("parseReply: one answer per requested skill, stamped with the stored input, which record accepts", () => {
  const a = found("a", "debugs things");
  const b = found("b", "writes tests");
  const store = pendingStore(a, b);
  const reply = [
    "Here are the filings:",
    "```json",
    `{"id": "npx:a", "activities": ["debug-failure"], "domains": [], "primary": "debug-failure", "fx": []}`,
    `{"id": "npx:a", "activities": ["refactor"], "primary": "refactor"}`,
    `{"id": "npx:not-asked", "activities": ["refactor"]}`,
    `{"id": "npx:b", "activities": "write-tests" `,
    "```",
  ].join("\n");
  const answers = parseReply(reply, store, ["npx:a", "npx:b"]);
  assert.deepEqual(answers.map((x) => [x.id, x.primary]), [["npx:a", "debug-failure"]]);
  assert.deepEqual(record(store, qs, answers).applied, ["npx:a"]);
  assert.equal(store.skills["npx:a"].p["debug-failure"], 0.9);
  assert.ok(store.skills["npx:b"].pending?.length);
});

test("shouldRetry: a failed batch waits a day unless it changes", () => {
  const now = Date.parse("2026-11-18T12:00:00Z");
  assert.ok(shouldRetry(undefined, "k1", now));
  assert.ok(!shouldRetry("k1 2026-11-18T06:00:00.000Z", "k1", now));
  assert.ok(shouldRetry("k1 2026-11-18T06:00:00.000Z", "k2", now));
  assert.ok(shouldRetry("k1 2026-11-17T11:00:00.000Z", "k1", now));
  assert.ok(shouldRetry("k1 garbage", "k1", now));
  const fifteenMinutes = 15 * 60_000;
  assert.ok(!shouldRetry("k1 2026-11-18T11:50:00.000Z", "k1", now, fifteenMinutes));
  assert.ok(shouldRetry("k1 2026-11-18T11:40:00.000Z", "k1", now, fifteenMinutes));
});

test("batchKey changes when a skill in the batch changes", () => {
  const a = found("a", "x");
  const store = pendingStore(a);
  const before = batchKey([a.id], store);
  store.skills[a.id].input = "edited";
  assert.notEqual(batchKey([a.id], store), before);
});

test("filerArgs: the filing run has no tools, MCP servers, hooks or saved session", () => {
  const args = filerArgs("sonnet");
  assert.equal(args[args.indexOf("--tools") + 1], "");
  assert.ok(args.includes("--strict-mcp-config"));
  assert.ok(args.includes("--no-session-persistence"));
  assert.equal(args[args.indexOf("--setting-sources") + 1], "");
  assert.deepEqual(JSON.parse(args[args.indexOf("--settings") + 1]), { disableAllHooks: true });
});

test("filerPrompt carries every skill and the taxonomy boundaries", () => {
  const prompt = filerPrompt([{ id: "npx:a", text: "# A\nbody" }], [{ ...entries[0], no: "reading docs" }]);
  assert.match(prompt, /=== skill npx:a ===\n# A\nbody/);
  assert.match(prompt, /"no":"reading docs"/);
});

// A small filed catalogue: two skills about debugging and tests, one about refactoring.
function findFixture(): Store {
  const debugging = found("systematic-debugging", "Use when a test fails or a bug appears.");
  const flaky = { ...found("flaky-hunter", "Finds flaky tests and pins their cause.", "", "claude:flaky-hunter") };
  const kit = { ...found("refactor-kit", "Simplify code without changing behaviour.", "", "plugin:x/refactor-kit"), source: "plugin:x" };
  return {
    version: 1,
    skills: {
      [debugging.id]: verdict(debugging, { "debug-failure": 0.9 }),
      [flaky.id]: verdict(flaky, { "write-tests": 0.8, "debug-failure": 0.6 }),
      [kit.id]: verdict(kit, { refactor: 0.9 }),
    },
  };
}

test("catalogue: moments by fit, slash commands per source, hidden skills left out", () => {
  const cards = catalogue(findFixture(), entries, render, { "refactor-kit": { hide: false } }, () => false);
  const byName = Object.fromEntries(cards.map((c) => [c.name, c]));
  assert.deepEqual(byName["flaky-hunter"].moments, ["write-tests", "debug-failure"]);
  assert.equal(byName["flaky-hunter"].invoke, "/flaky-hunter");
  assert.equal(byName["refactor-kit"].invoke, "/x:refactor-kit");
  assert.equal(byName["systematic-debugging"].invoke, undefined);
  assert.equal(catalogue(findFixture(), entries, render, {}, (n) => n === "systematic-debugging").find((c) => c.name === "systematic-debugging")?.invoke, "/systematic-debugging");
  assert.deepEqual(catalogue(findFixture(), entries, render, { "refactor-kit": { hide: true } }, () => false).map((c) => c.name), ["flaky-hunter", "systematic-debugging"]);
});

test("search: more matched words first, then name over description over moment, at word starts", () => {
  const cards = catalogue(findFixture(), entries, render, {}, () => false);
  // "debug": name (3) + moment debug-failure (1) beats moment only (1); refactor-kit has no match.
  assert.deepEqual(search(cards, "debug", entries).map((c) => c.name), ["systematic-debugging", "flaky-hunter"]);
  // "flaky test": flaky-hunter matches both words, systematic-debugging only "test" (in its description).
  assert.deepEqual(search(cards, "flaky test", entries).map((c) => c.name), ["flaky-hunter", "systematic-debugging"]);
  // "ode" is inside "code" but starts no word, so nothing matches.
  assert.deepEqual(search(cards, "ode", entries), []);
});

test("shouldPick: the picker needs a person at a terminal, fzf, and no output flag", () => {
  const tty = { stdinTTY: true, stdoutTTY: true, fzf: true };
  assert.ok(shouldPick(tty));
  assert.ok(!shouldPick({ ...tty, stdoutTTY: false }));
  assert.ok(!shouldPick({ ...tty, stdinTTY: false }));
  assert.ok(!shouldPick({ ...tty, fzf: false }));
  assert.ok(!shouldPick({ ...tty, plain: true }));
  assert.ok(!shouldPick({ ...tty, json: true }));
});

test("find CLI: ranked blocks when piped, JSON on request, exit 1 on no match, exit 2 on a bad limit", () => {
  const dir = mkdtempSync(join(tmpdir(), "skill-search-find-"));
  writeFileSync(join(dir, "verdicts.json"), JSON.stringify(findFixture()));
  writeFileSync(
    join(dir, "taxonomy.yaml"),
    "activities:\n  verify:\n    - {id: debug-failure, when: debugging a failure}\n  build:\n    - {id: write-tests, when: writing tests}\n    - {id: refactor, when: refactoring}\ndomains:\n  - {id: typescript, when: working in TypeScript}\n",
  );
  writeFileSync(join(dir, "config.yaml"), "render: {activities: 2, domains: 1}\nembed: none\n");
  const cli = (...args: string[]) =>
    spawnSync(process.execPath, [join(import.meta.dirname, "../src/cli.ts"), ...args], { env: { ...process.env, SKILL_SEARCH_DIR: dir }, encoding: "utf8" });
  const run = (...args: string[]) => cli("find", ...args);

  // Search is the default verb: words that are not a command search, and match `find` exactly.
  assert.equal(cli("debug").stdout, run("debug").stdout);
  // Piped with no words, an agent gets the usage, not an arbitrary list.
  assert.match(cli().stdout, /^skill-search: find the installed agent skill/);
  // A word that is also a command runs the command; `find` searches for it instead.
  assert.match(cli("status").stdout, /^data /m);

  const listed = run("debug");
  assert.equal(listed.status, 0);
  const names = [...listed.stdout.matchAll(/^name: (.+)$/gm)].map((m) => m[1]);
  assert.deepEqual(names, ["systematic-debugging", "flaky-hunter"]);
  assert.match(listed.stdout, /name: flaky-hunter\ninvoke: \/flaky-hunter\nmoments: write-tests, debug-failure\ndescription: Finds flaky tests and pins their cause\.\npath: \/x\/flaky-hunter\/SKILL\.md/);

  const json = run("flaky", "--json");
  assert.equal(json.status, 0);
  assert.deepEqual(JSON.parse(json.stdout).map((c: { name: string }) => c.name), ["flaky-hunter"]);

  const limited = run("debug", "--limit", "1");
  assert.match(limited.stdout, /1 more\. Add words to narrow, or pass --limit 2\./);

  const none = run("kubernetes");
  assert.equal(none.status, 1);
  assert.match(none.stderr, /No skill matches "kubernetes"/);

  assert.equal(run("debug", "--limit", "zero").status, 2);
});

test("search: a skill's own description outranks a moment line it shares with many skills", () => {
  const owner = found("noise-filter", "Catches flaky tests.");
  const bystander = found("aaa-generic", "General helper.");
  const store: Store = {
    version: 1,
    skills: {
      [owner.id]: verdict(owner, { "write-tests": 0.8 }),
      [bystander.id]: verdict(bystander, { "write-tests": 0.8 }),
    },
  };
  const flakyMoment: Entry[] = entries.map((e) => (e.id === "write-tests" ? { ...e, when: "writing tests, or chasing a flaky test" } : e));
  const cards = catalogue(store, flakyMoment, render, {}, () => false);
  // Both match "flaky test" twice; the owner says "flaky" itself (2), the bystander only inherits it from the moment (1).
  assert.deepEqual(search(cards, "flaky test", flakyMoment).map((c) => c.name), ["noise-filter", "aaa-generic"]);
});

// --- search by meaning and the picker ---

import { createServer } from "node:http";
import { isLocal, Vectors } from "../src/embed.ts";
import { rank, type Card } from "../src/find.ts";
import { footer, line, parsePick, stripFrontmatter } from "../src/picker.ts";
import { matchesOf, MEANING_MAX, reason } from "../src/searcher.ts";

const card = (name: string, description: string, moments: string[] = []): Card => ({ id: `npx:${name}`, name, source: "npx", description, path: `/x/${name}/SKILL.md`, moments, invoke: `/${name}` });
const sim = (pairs: [string, number][]) => new Map(pairs.map(([n, s]) => [`npx:${n}`, s]));

test("rank: meaning and keyword ranks add up, so a skill near the top of both wins and either list alone can lift one", () => {
  const cards = [card("alpha", "unrelated words"), card("beta", "fixes flaky tests"), card("gamma", "about calm interfaces")];
  // gamma is closest by meaning, beta is the only keyword match and second by meaning: beta is top of both lists combined.
  const sims = sim([["alpha", 0.2], ["beta", 0.5], ["gamma", 0.6]]);
  assert.deepEqual(rank(cards, "flaky", [], sims).map((c) => c.name), ["beta", "gamma", "alpha"]);
  // With no keyword match, meaning alone orders them.
  assert.deepEqual(rank(cards, "serene", [], sims).map((c) => c.name), ["gamma", "beta", "alpha"]);
  // Without similarities it is the keyword search.
  assert.deepEqual(rank(cards, "flaky", []).map((c) => c.name), ["beta"]);
});

test("matchesOf: keyword hits always show; by meaning only skills close to the best, above the floor, at most MEANING_MAX", () => {
  const many = Array.from({ length: 30 }, (_, i) => card(`s${i}`, "x"));
  const sims = new Map(many.map((c, i) => [c.id, 0.7 - i * 0.001]));
  assert.equal(matchesOf(many, [], sims).length, MEANING_MAX);
  const cards = [card("near", "x"), card("far", "x"), card("word", "x")];
  const s = sim([["near", 0.62], ["far", 0.4], ["word", 0.3]]);
  assert.deepEqual(matchesOf(cards, [cards[2]], s).map((c) => c.name), ["near", "word"]);
  // Below the floor nothing matches by meaning, however close to the best.
  assert.deepEqual(matchesOf(cards, [], sim([["near", 0.4], ["far", 0.39], ["word", 0.3]])), []);
});

test("Vectors.update keeps finished batches when a later batch fails, and only embeds what changed", async () => {
  let calls = 0;
  const server = createServer((req, res) => {
    let body = "";
    req.on("data", (d) => (body += d)).on("end", () => {
      calls++;
      const input: string[] = JSON.parse(body).input;
      if (calls === 2) return res.writeHead(500).end("model crashed");
      res.end(JSON.stringify({ data: input.map((_, index) => ({ index, embedding: [1, index + 1, 0] })) }));
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const port = (server.address() as { port: number }).port;
  const embed = { url: `http://127.0.0.1:${port}`, model: "test-model" };
  const dir = mkdtempSync(join(tmpdir(), "skill-search-vec-"));
  const docs = Array.from({ length: 40 }, (_, i) => ({ id: `npx:s${i}`, name: `s${i}`, description: "d" }));
  try {
    await assert.rejects(new Vectors(dir, "test-model").update(docs, embed, 10_000), /500/);
    const saved = new Vectors(dir, "test-model");
    assert.equal(saved.byId.size, 32, "the first batch of 32 was saved before the second failed");
    assert.equal(await saved.update(docs, embed, 10_000), 0);
    assert.equal(calls, 3, "the retry embedded only the 8 that were missing");
    assert.equal(new Vectors(dir, "other-model").byId.size, 0, "vectors from another model are not used");
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test("picker: names sit in a fixed column, long ones are cut, and fzf's output maps to print, copy or quit", () => {
  const long = card("principle-make-operations-idempotent", "Apply when designing");
  const [id, path, invoke, shown] = line(long, []).split("\t");
  assert.deepEqual([id, path, invoke], ["npx:principle-make-operations-idempotent", "/x/principle-make-operations-idempotent/SKILL.md", "/principle-make-operations-idempotent"]);
  assert.match(shown, /principle-make-operations-i…/);
  const byId = new Map([[long.id, long]]);
  const chosen = line(long, []);
  assert.deepEqual(parsePick(`\n${chosen}\n`, 0, byId), { kind: "print", card: long });
  assert.deepEqual(parsePick(`ctrl-y\n${chosen}\n`, 0, byId), { kind: "copy", card: long });
  assert.deepEqual(parsePick("", 130, byId), { kind: "quit" });
  assert.equal(stripFrontmatter("---\nname: a\n---\n\n# Body\n"), "# Body\n");
});

test("picker footer: the keys, plus why search is by words only when meaning is unavailable", () => {
  const plainText = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "");
  assert.equal(plainText(footer({ by: "meaning" })), "enter print  ctrl-y copy  esc quit");
  assert.equal(plainText(footer({ by: "words", why: "off" })), "enter print  ctrl-y copy  esc quit");
  const embed = { url: "http://localhost:1234", model: "m" };
  assert.match(plainText(footer({ by: "words", why: reason(new TypeError("fetch failed"), embed) })), /words only: no embedding server at http:\/\/localhost:1234$/);
  assert.ok(isLocal("http://localhost:1234") && isLocal("http://127.0.0.1:9") && !isLocal("https://api.example.com"));
});
