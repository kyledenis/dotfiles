import { matches, type Config } from "./config.ts";
import { embedQuery, isLocal, Vectors, type Doc, type Embed } from "./embed.ts";
import { rank, search, type Card } from "./find.ts";
import type { Entry } from "./taxonomy.ts";

/** How many of a skill's moments, best fit first, go into the text that is embedded for it. */
export const MOMENTS_EMBEDDED = 2;
/**
 * By meaning, a skill matches when it is within BAND of the closest skill's similarity and above FLOOR, and at
 * most MEANING_MAX skills match on meaning alone: a query unlike any skill still has near neighbours, and its
 * similarities sit almost as high as a real query's but flat, so the band alone would let dozens through.
 */
export const BAND = 0.1;
export const FLOOR = 0.45;
export const MEANING_MAX = 20;

export type Mode = { by: "meaning" } | { by: "words"; why?: string };
export type Result = { cards: Card[]; mode: Mode };

/** Embedding text for each card: name, description and the "when" lines of its best-fitting moments. */
export function docs(cards: Card[], entries: Entry[]): Doc[] {
  const when = new Map(entries.map((e) => [e.id, e.when]));
  return cards.map((c) => ({ id: c.id, name: c.name, description: c.description, when: c.moments.slice(0, MOMENTS_EMBEDDED).map((m) => when.get(m) ?? m) }));
}

/** The skills worth showing for a query: every keyword match, plus those close to the best match by meaning. */
export function matchesOf(ranked: Card[], keywordHits: Card[], sims: Map<string, number>): Card[] {
  const hit = new Set(keywordHits.map((c) => c.id));
  const top = Math.max(...ranked.map((c) => sims.get(c.id) ?? -1));
  const close = (c: Card) => {
    const s = sims.get(c.id);
    return s !== undefined && s >= FLOOR && s >= top - BAND;
  };
  const near = new Set(
    ranked
      .filter(close)
      .sort((a, b) => sims.get(b.id)! - sims.get(a.id)!)
      .slice(0, MEANING_MAX)
      .map((c) => c.id),
  );
  return ranked.filter((c) => hit.has(c.id) || near.has(c.id));
}

/** Keyword and meaning search over one catalogue, keeping vectors and query embeddings between calls. */
export class Searcher {
  readonly cards: Card[];
  private readonly entries: Entry[];
  private readonly embed?: Embed;
  private readonly vectors?: Vectors;
  private readonly docs: Doc[];
  private readonly queries = new Map<string, Float32Array>();
  private down?: string;

  constructor(cards: Card[], entries: Entry[], config: Config) {
    this.cards = cards;
    this.entries = entries;
    this.embed = config.embed;
    const local = !!config.embed && isLocal(config.embed.url);
    this.docs = docs(cards, entries).filter((d) => local || !matches(config.private, d.id));
    if (config.embed) this.vectors = new Vectors(config.stateDir, config.embed.model);
  }

  /** How many skills have no vector, or one made from text that has since changed. */
  stale(): number {
    return this.vectors ? this.vectors.stale(this.docs).length : 0;
  }

  /** True when the embedding model answers within `ms`, so embedding now will not wait for it to load. */
  async ready(ms: number): Promise<boolean> {
    if (!this.embed) return false;
    try {
      await embedQuery(this.embed, "ready", ms);
      return true;
    } catch (e) {
      this.down = reason(e, this.embed);
      return false;
    }
  }

  /** Embeds skills that have no vector yet. Returns why meaning search is unavailable, if it is. */
  async prepare(budgetMs: number): Promise<string | undefined> {
    if (!this.embed || !this.vectors) return "off";
    try {
      await this.vectors.update(this.docs, this.embed, budgetMs);
      this.down = undefined;
    } catch (e) {
      this.down = reason(e, this.embed);
    }
    return this.down;
  }

  async query(q: string, timeoutMs: number): Promise<Result> {
    const words = search(this.cards, q, this.entries);
    if (!q.trim()) return { cards: this.cards, mode: { by: "words" } };
    if (!this.embed || !this.vectors) return { cards: words, mode: { by: "words" } };
    if (!this.vectors.byId.size) return { cards: words, mode: { by: "words", why: this.down ?? "no skill vectors yet" } };
    let v = this.queries.get(q);
    if (!v) {
      try {
        v = await embedQuery(this.embed, q, timeoutMs);
        this.queries.set(q, v);
        this.down = undefined;
      } catch (e) {
        this.down = reason(e, this.embed);
        return { cards: words, mode: { by: "words", why: this.down } };
      }
    }
    const sims = this.vectors.similarities(v);
    return { cards: matchesOf(rank(this.cards, q, this.entries, sims), words, sims), mode: { by: "meaning" } };
  }
}

/** Why meaning search is unavailable, in words a person can act on. fetch reports a refused connection as "fetch failed". */
export function reason(e: unknown, embed: Embed): string {
  const err = e instanceof Error ? e : new Error(String(e));
  if (err.name === "TimeoutError" || err.name === "AbortError") return `the embedding model at ${embed.url} is still loading`;
  if (err.message === "fetch failed") return `no embedding server at ${embed.url}`;
  return err.message;
}
