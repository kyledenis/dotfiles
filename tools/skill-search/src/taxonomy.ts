import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";
import { sha } from "./skill.ts";

export type Entry = {
  id: string;
  axis: "activity" | "domain";
  group: string;
  when: string;
  yes?: string;
  no?: string;
};

export type Question = { id: string; text: string; hash: string };

export const FX = {
  "fx-spawns": "Does this skill direct the agent to launch subagents, parallel workers or other model runs?",
  "fx-pushes": "Does this skill direct the agent to deploy or release software, or to push commits, open, merge or land pull requests?",
  "fx-external":
    "Following this skill, will the agent send content to an outside service, such as posting, messaging or writing through a third-party API?",
} as const;

export const FX_LABEL: Record<keyof typeof FX, string> = {
  "fx-spawns": "spawns agents",
  "fx-pushes": "pushes or deploys",
  "fx-external": "sends to outside services",
};

export function taxonomyPath(dataDir: string): string {
  const own = join(dataDir, "taxonomy.yaml");
  if (existsSync(own)) return own;
  const here = dirname(fileURLToPath(import.meta.url));
  return [join(here, "../taxonomy.yaml"), join(here, "taxonomy.yaml")].find(existsSync) ?? own;
}

export function loadTaxonomy(path: string): Entry[] {
  const raw = parse(readFileSync(path, "utf8"));
  const out: Entry[] = [];
  for (const [group, items] of Object.entries(raw.activities ?? {}))
    for (const e of items as Entry[]) out.push({ ...e, axis: "activity", group });
  for (const e of (raw.domains ?? []) as Entry[]) out.push({ ...e, axis: "domain", group: "domains" });
  const seen = new Set<string>();
  for (const e of out) {
    if (!/^[a-z0-9-]+$/.test(e.id) || e.id.startsWith("fx-")) throw new Error(`taxonomy: bad id "${e.id}"`);
    if (seen.has(e.id)) throw new Error(`taxonomy: duplicate id "${e.id}"`);
    if (!e.when) throw new Error(`taxonomy: "${e.id}" has no when`);
    seen.add(e.id);
  }
  return out;
}

export function questions(entries: Entry[]): Question[] {
  const qs = entries.map((e) => {
    let text = `Would an AI coding agent that is ${e.when} be better off opening this skill?`;
    if (e.yes) text += ` Yes when: ${e.yes}.`;
    if (e.no) text += ` No when: ${e.no}.`;
    return { id: e.id, text };
  });
  for (const [id, text] of Object.entries(FX)) qs.push({ id, text });
  return qs.map((q) => ({ ...q, hash: sha(q.text, 12) }));
}
