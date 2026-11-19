import type { Config } from "./config.ts";
import { overrideFor, place, type Override } from "./render.ts";
import type { Store } from "./store.ts";
import type { Entry } from "./taxonomy.ts";

export type Card = { id: string; name: string; source: string; description: string; path: string; moments: string[]; invoke?: string };

/** One card per visible skill, its moments ordered by fit. `slashable` says whether Claude Code loads an npx skill under its own name. */
export function catalogue(store: Store, entries: Entry[], r: Config["render"], overrides: Record<string, Override>, slashable: (name: string) => boolean): Card[] {
  const cards: Card[] = [];
  for (const [id, v] of Object.entries(store.skills)) {
    const o = overrideFor(overrides, id, v);
    if (o?.hide) continue;
    const moments = place(id, v, entries, r, o)
      .sort((a, b) => b.p - a.p)
      .map((p) => p.id);
    cards.push({ id, name: v.name, source: v.source, description: v.description, path: v.path, moments, invoke: invocation(v.source, v.name, slashable) });
  }
  return cards.sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
}

function invocation(source: string, name: string, slashable: (name: string) => boolean): string | undefined {
  if (source === "claude") return `/${name}`;
  if (source.startsWith("plugin:")) return `/${source.slice("plugin:".length)}:${name}`;
  if (source === "npx" && slashable(name)) return `/${name}`;
  return undefined;
}

type Hits = { hits: number; score: number };

/**
 * Scores cards by how many query words they contain, then by where: a word in the name counts 3, in the
 * skill's own description 2, in a moment it is filed under 1 (moment lines are shared by many skills, so they
 * rank last). Words match at word starts, so "test" finds "tests" but not "latest".
 */
function keyword(cards: Card[], query: string, entries: Entry[]): { words: string[]; by: Map<string, Hits> } {
  const words = query.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 1);
  const by = new Map<string, Hits>();
  if (!words.length) return { words, by };
  const when = new Map(entries.map((e) => [e.id, `${e.id} ${e.when}`]));
  const starts = words.map((w) => new RegExp(`(^|[^a-z0-9])${w}`));
  for (const c of cards) {
    const name = c.name.toLowerCase();
    const moments = c.moments.map((m) => when.get(m) ?? m).join(" ").toLowerCase();
    const description = c.description.toLowerCase();
    let hits = 0;
    let score = 0;
    for (const re of starts) {
      const s = (re.test(name) ? 3 : 0) + (re.test(description) ? 2 : 0) + (re.test(moments) ? 1 : 0);
      if (s) hits++;
      score += s;
    }
    if (hits) by.set(c.id, { hits, score });
  }
  return { words, by };
}

/** Keyword matches only, most matched words first, then by where they matched. */
export function search(cards: Card[], query: string, entries: Entry[]): Card[] {
  const { words, by } = keyword(cards, query, entries);
  if (!words.length) return cards;
  return cards
    .filter((c) => by.has(c.id))
    .sort((a, b) => by.get(b.id)!.hits - by.get(a.id)!.hits || by.get(b.id)!.score - by.get(a.id)!.score || a.name.localeCompare(b.name));
}

/** Reciprocal-rank constant: higher flattens the gap between first and tenth place in each list. */
export const RRF_K = 60;

/**
 * Ranks by meaning and keywords together when similarities are given: each skill scores 1/(RRF_K + rank) in
 * the meaning order, plus the same for its rank among keyword matches. A skill near the top of both lists
 * wins, and either list alone can still lift a skill the other misses. Without similarities it is the keyword search.
 */
export function rank(cards: Card[], query: string, entries: Entry[], sims?: Map<string, number>): Card[] {
  if (!sims?.size) return search(cards, query, entries);
  if (!keyword(cards, query, entries).words.length) return cards;
  const score = new Map<string, number>();
  const add = (list: Card[]) => list.forEach((c, i) => score.set(c.id, (score.get(c.id) ?? 0) + 1 / (RRF_K + i + 1)));
  add([...cards].sort((a, b) => (sims.get(b.id) ?? -1) - (sims.get(a.id) ?? -1)));
  add(search(cards, query, entries));
  return [...cards].sort((a, b) => score.get(b.id)! - score.get(a.id)! || a.name.localeCompare(b.name));
}

export function plain(cards: Card[], limit: number): string {
  const blocks = cards.slice(0, limit).map((c) =>
    [
      `name: ${c.name}`,
      ...(c.invoke ? [`invoke: ${c.invoke}`] : []),
      `moments: ${c.moments.join(", ") || "none"}`,
      `description: ${c.description}`,
      `path: ${c.path}`,
    ].join("\n"),
  );
  const more = cards.length - limit;
  return blocks.join("\n\n") + (more > 0 ? `\n\n${more} more. Add words to narrow, or pass --limit ${cards.length}.` : "") + "\n";
}

/** The picker opens only for a person at a terminal: both ends are TTYs, fzf exists, and no output format was asked for. */
export function shouldPick(o: { json?: boolean; plain?: boolean; stdinTTY: boolean; stdoutTTY: boolean; fzf: boolean }): boolean {
  return !o.json && !o.plain && o.stdinTTY && o.stdoutTTY && o.fzf;
}
