// Retrieval check against the live map: where each query's expected skills land under keyword, meaning and the combined ranking.
// Usage: node test/eval-search.ts [--raw]   (needs the embedding server; --raw prints each query's top similarities)
import { existsSync } from "node:fs";
import { join } from "node:path";
import { home, loadConfig } from "../src/config.ts";
import { embedQuery, Vectors } from "../src/embed.ts";
import { catalogue, rank, search } from "../src/find.ts";
import { loadOverrides } from "../src/render.ts";
import { loadStore } from "../src/store.ts";
import { loadTaxonomy, taxonomyPath } from "../src/taxonomy.ts";

// query -> skills that should be near the top (any one of them counts as a hit)
const CASES: [string, string[]][] = [
  ["clean-copy", ["clean-copy"]],
  ["remotion captions", ["remotion-captions"]],
  ["flaky test", ["systematic-debugging", "test-anti-patterns", "diagnosing-bugs"]],
  ["make the interface feel calmer and more alive", ["make-interfaces-feel-better", "design-motion-principles", "animate", "emil-design-eng", "be-weird-again"]],
  ["something is slow and I want to know why", ["performance", "measure-performance", "analyzing-dotnet-performance", "web-perf", "debug-optimize-lcp"]],
  ["the app should feel more fun and playful", ["be-weird-again", "creative", "make-interfaces-feel-better"]],
  ["turn my rambling thoughts into a tweet", ["post"]],
  ["what have I saved about this", ["engram"]],
  ["review my diff for bugs", ["code-review", "differential-review", "review-pr"]],
  ["stress test my plan by asking me questions", ["grilling", "brainstorming"]],
  ["make a video from this pull request", ["pr-to-video"]],
  ["copy that sounds like a robot wrote it", ["clean-copy", "install-anti-slop", "copywriting"]],
  ["check the page works for screen reader users", ["accessibility", "a11y-debugging", "accessibility-voiceover-specialist"]],
  ["post", ["post"]],
  ["swiftui animation", ["swiftui-expert-skill", "animate"]],
  ["be more creative, less generic", ["be-weird-again", "creative", "design-taste-frontend"]],
];

const config = loadConfig();
const entries = loadTaxonomy(taxonomyPath(config.dataDir));
const cards = catalogue(loadStore(config.dataDir), entries, config.render, loadOverrides(config.dataDir), (n) => existsSync(join(home, ".claude/skills", n)));
const known = new Set(cards.map((c) => c.name));
for (const c of CASES) {
  c[1] = c[1].filter((w) => known.has(w));
  if (!c[1].length) throw new Error(`none of the skills "${c[0]}" expects is installed`);
}
const when = new Map(entries.map((e) => [e.id, e.when]));
const moments = Number(process.env.EVAL_MOMENTS ?? 2);
const docs = cards.map((c) => ({ ...c, when: c.moments.slice(0, moments).map((m) => when.get(m) ?? m) }));
const embed = config.embed && process.env.EVAL_MODEL ? { ...config.embed, model: process.env.EVAL_MODEL } : config.embed;
if (!embed) throw new Error("embedding is off in config.yaml");
const vectors = new Vectors(config.stateDir, embed.model);
const missing = await vectors.update(docs, embed, 300_000);
if (missing) throw new Error(`${missing} skills still have no vector`);

const pos = (list: { name: string }[], want: string[]) => {
  const i = list.findIndex((c) => want.includes(c.name));
  return i < 0 ? "-" : String(i + 1);
};
let kwHits = 0, semHits = 0, hyHits = 0;
console.log("rank of the first expected skill (top 5 counts as a hit)\n");
console.log("keyword  meaning  combined  query");
for (const [q, want] of CASES) {
  const sims = vectors.similarities(await embedQuery(embed, q, 30_000));
  const kw = search(cards, q, entries);
  const sem = [...cards].sort((a, b) => (sims.get(b.id) ?? 0) - (sims.get(a.id) ?? 0));
  const hy = rank(cards, q, entries, sims);
  const [k, s, h] = [pos(kw, want), pos(sem, want), pos(hy, want)];
  const hit = (r: string) => r !== "-" && Number(r) <= 5;
  kwHits += +hit(k); semHits += +hit(s); hyHits += +hit(h);
  console.log(`${k.padStart(7)}  ${s.padStart(7)}  ${h.padStart(8)}  ${q}`);
  if (process.argv.includes("--raw")) {
    const top = sem.slice(0, 6).map((c) => `${c.name} ${(sims.get(c.id) ?? 0).toFixed(3)}`);
    console.log(`         meaning: ${top.join(", ")}\n         combined: ${hy.slice(0, 6).map((c) => c.name).join(", ")}`);
  }
}
console.log(`\ntop-5 hits: keyword ${kwHits}/${CASES.length}, meaning ${semHits}/${CASES.length}, combined ${hyHits}/${CASES.length}`);
