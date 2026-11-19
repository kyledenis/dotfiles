import { existsSync, readFileSync } from "node:fs";
import type { Config } from "./config.ts";
import type { Question } from "./taxonomy.ts";

export function jevKey(config: Config): string | undefined {
  const env = process.env[config.jev.keyEnv];
  if (env) return env;
  const file = config.jev.keyFile;
  if (!file || !existsSync(file)) return undefined;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const [k, ...rest] = line.split("=");
    if (k.trim() === config.jev.keyEnv) return rest.join("=").trim().replace(/^["']|["']$/g, "");
  }
  return undefined;
}

const RETRY = new Set([429, 500, 502, 503, 504, 529]);

export async function askJev(config: Config, key: string, state: string, qs: Question[]): Promise<Record<string, number>> {
  const body = JSON.stringify({
    state,
    model: config.jev.model,
    questions: Object.fromEntries(qs.map((q) => [q.id, { type: "noul", instructions: q.text }])),
  });
  let last = "";
  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      const res = await fetch(config.jev.url, {
        method: "POST",
        headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
        body,
        signal: AbortSignal.timeout(90_000),
      });
      if (res.ok) {
        const json = (await res.json()) as { answers: Record<string, { noul: string | number }> };
        const out: Record<string, number> = {};
        for (const q of qs) {
          const a = json.answers?.[q.id];
          if (a == null) throw new Error(`jev: no answer for ${q.id}`);
          out[q.id] = Math.round(Number(a.noul) * 1000) / 1000;
        }
        return out;
      }
      last = `http ${res.status}: ${(await res.text()).slice(0, 200)}`;
      if (!RETRY.has(res.status)) break;
    } catch (e) {
      last = String(e);
    }
    await new Promise((r) => setTimeout(r, Math.min(30, 2 ** attempt) * 1000 + Math.random() * 1000));
  }
  throw new Error(last || "jev: retries exhausted");
}

export async function pool<T, R>(items: T[], size: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(size, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        out[i] = await fn(items[i]);
      }
    }),
  );
  return out;
}
