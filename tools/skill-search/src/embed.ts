import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";

/** An OpenAI-compatible /v1/embeddings endpoint. The default is LM Studio with the model engram settled on after its A/B. */
export type Embed = { url: string; model: string };
export const DEFAULT_EMBED: Embed = { url: "http://localhost:1234", model: "text-embedding-qwen3-embedding-0.6b" };

/** What gets embedded for a skill: its name and description, plus the "when" lines of the moments it is filed under. */
export type Doc = { id: string; name: string; description: string; when?: string[] };

/** Qwen3 embedding models take a task instruction on the query side only; nomic wants a prefix on both. */
export function prefixes(model: string): { doc: string; query: string } {
  if (model.includes("qwen3-embedding"))
    return { doc: "", query: "Instruct: Given a task someone is about to do, or the direction they want to take it, retrieve the agent skills that help with it\nQuery: " };
  if (model.includes("nomic-embed")) return { doc: "search_document: ", query: "search_query: " };
  return { doc: "", query: "" };
}

export const docText = (d: Doc) => `${d.name}: ${d.description}` + (d.when?.length ? `\nUse when ${d.when.join("; ")}` : "");
const hash = (s: string) => createHash("sha1").update(s).digest("hex").slice(0, 16);

/** True when the endpoint runs on this machine, so private skills may be sent to it. */
export function isLocal(url: string): boolean {
  try {
    const h = new URL(url).hostname;
    return h === "localhost" || h === "127.0.0.1" || h === "::1" || h === "[::1]";
  } catch {
    return false;
  }
}

function parseVectors(body: unknown, n: number): Float32Array[] {
  const data = (body as { data?: unknown })?.data;
  if (!Array.isArray(data) || data.length !== n) throw new Error(`expected ${n} embeddings, got ${Array.isArray(data) ? data.length : "none"}`);
  const rows = [...data].sort((a, b) => Number(a?.index) - Number(b?.index));
  return rows.map((r) => {
    const e = r?.embedding;
    if (!Array.isArray(e) || !e.length || e.some((x) => typeof x !== "number")) throw new Error("an embedding is not a list of numbers");
    return normalise(Float32Array.from(e));
  });
}

function normalise(v: Float32Array): Float32Array {
  let s = 0;
  for (const x of v) s += x * x;
  const n = Math.sqrt(s) || 1;
  for (let i = 0; i < v.length; i++) v[i] /= n;
  return v;
}

export async function embedTexts(e: Embed, texts: string[], timeoutMs: number): Promise<Float32Array[]> {
  const res = await fetch(`${e.url.replace(/\/$/, "")}/v1/embeddings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ model: e.model, input: texts }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error(`embedding server answered ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return parseVectors(await res.json(), texts.length);
}

export const embedQuery = async (e: Embed, q: string, timeoutMs: number) => (await embedTexts(e, [prefixes(e.model).query + q], timeoutMs))[0];

type IndexFile = { model: string; dims: number; ids: string[]; hashes: string[] };

/** Skill vectors, cached in the state folder as one Float32 file plus an index of ids and text hashes. */
export class Vectors {
  readonly byId = new Map<string, { hash: string; v: Float32Array }>();
  private readonly dir: string;
  readonly model: string;
  constructor(dir: string, model: string) {
    this.dir = dir;
    this.model = model;
    const idx = join(dir, "vectors.json");
    const bin = join(dir, "vectors.bin");
    if (!existsSync(idx) || !existsSync(bin)) return;
    try {
      const meta: unknown = JSON.parse(readFileSync(idx, "utf8"));
      const m = meta as Partial<IndexFile>;
      if (m.model !== model || !m.dims || !Array.isArray(m.ids) || !Array.isArray(m.hashes)) return;
      const buf = readFileSync(bin);
      const all = new Float32Array(buf.buffer, buf.byteOffset, buf.byteLength / 4);
      if (all.length !== m.ids.length * m.dims) return;
      m.ids.forEach((id, i) => this.byId.set(id, { hash: String(m.hashes?.[i]), v: all.slice(i * m.dims!, (i + 1) * m.dims!) }));
    } catch {
      this.byId.clear();
    }
  }

  /** Docs with no vector, or whose text changed since theirs was made. */
  stale(docs: Doc[]): Doc[] {
    return docs.filter((d) => this.byId.get(d.id)?.hash !== hash(docText(d)));
  }

  /** Embeds stale docs in batches until done or out of time, dropping vectors for skills no longer installed. Returns how many are still missing. */
  async update(docs: Doc[], e: Embed, budgetMs: number): Promise<number> {
    const live = new Set(docs.map((d) => d.id));
    let changed = false;
    for (const id of [...this.byId.keys()]) if (!live.has(id)) (this.byId.delete(id), (changed = true));
    const todo = this.stale(docs);
    const end = Date.now() + budgetMs;
    const p = prefixes(e.model).doc;
    try {
      for (let i = 0; i < todo.length && Date.now() < end; i += 32) {
        const batch = todo.slice(i, i + 32);
        const vs = await embedTexts(e, batch.map((d) => p + docText(d)), Math.max(1000, end - Date.now()));
        batch.forEach((d, j) => this.byId.set(d.id, { hash: hash(docText(d)), v: vs[j] }));
        changed = true;
      }
    } finally {
      // Keep finished batches even when a later one times out, so the next run picks up where this one stopped.
      if (changed) this.save();
    }
    return this.stale(docs).length;
  }

  private save() {
    const ids = [...this.byId.keys()];
    const dims = ids.length ? this.byId.get(ids[0])!.v.length : 0;
    const all = new Float32Array(ids.length * dims);
    ids.forEach((id, i) => all.set(this.byId.get(id)!.v, i * dims));
    mkdirSync(this.dir, { recursive: true });
    writeFileSync(join(this.dir, "vectors.bin.tmp"), Buffer.from(all.buffer));
    writeFileSync(join(this.dir, "vectors.json.tmp"), JSON.stringify({ model: this.model, dims, ids, hashes: ids.map((id) => this.byId.get(id)!.hash) } satisfies IndexFile));
    renameSync(join(this.dir, "vectors.bin.tmp"), join(this.dir, "vectors.bin"));
    renameSync(join(this.dir, "vectors.json.tmp"), join(this.dir, "vectors.json"));
  }

  /** Cosine similarity of the query to every skill that has a vector. */
  similarities(q: Float32Array): Map<string, number> {
    const out = new Map<string, number>();
    for (const [id, { v }] of this.byId) {
      if (v.length !== q.length) continue;
      let s = 0;
      for (let i = 0; i < v.length; i++) s += v[i] * q[i];
      out.set(id, s);
    }
    return out;
  }
}
