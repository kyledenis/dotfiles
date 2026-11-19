import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export type Verdict = {
  name: string;
  source: string;
  path: string;
  description: string;
  userOnly: boolean;
  input: string;
  by: string;
  p: Record<string, number>;
  q: Record<string, string>;
  pending?: string[];
  updated: string;
};

export type Store = { version: 1; skills: Record<string, Verdict> };

export const storePath = (dataDir: string) => join(dataDir, "verdicts.json");

export function loadStore(dataDir: string): Store {
  const f = storePath(dataDir);
  return existsSync(f) ? JSON.parse(readFileSync(f, "utf8")) : { version: 1, skills: {} };
}

export function saveStore(dataDir: string, store: Store): void {
  const sorted: Store = { version: 1, skills: {} };
  for (const id of Object.keys(store.skills).sort()) {
    const v = store.skills[id];
    sorted.skills[id] = { ...v, p: sortKeys(v.p), q: sortKeys(v.q), ...(v.pending?.length ? { pending: [...v.pending].sort() } : { pending: undefined }) };
  }
  writeAtomic(storePath(dataDir), JSON.stringify(sorted, null, 1) + "\n");
}

function sortKeys<T>(o: Record<string, T>): Record<string, T> {
  return Object.fromEntries(Object.entries(o).sort(([a], [b]) => a.localeCompare(b)));
}

export function writeAtomic(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, content);
  renameSync(tmp, path);
}
