import { existsSync, mkdirSync, readdirSync, readFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { parse } from "yaml";
import { tilde, type Config } from "./config.ts";
import { writeAtomic, type Store, type Verdict } from "./store.ts";
import { FX, FX_LABEL, type Entry } from "./taxonomy.ts";

export type Override = { add?: string[]; remove?: string[]; tier?: "ask" | "normal"; hide?: boolean };
export type Placement = { id: string; skill: string; p: number; pinned: boolean };

export function loadOverrides(dataDir: string): Record<string, Override> {
  const f = join(dataDir, "overrides.yaml");
  return existsSync(f) ? (parse(readFileSync(f, "utf8")) ?? {}) : {};
}

export function overrideFor(o: Record<string, Override>, id: string, v: Verdict): Override | undefined {
  return o[id] ?? o[v.name];
}

export function staleOverrides(o: Record<string, Override>, store: Store): string[] {
  const keys = new Set(Object.entries(store.skills).flatMap(([id, v]) => [id, v.name]));
  return Object.keys(o).filter((k) => !keys.has(k));
}

export function place(id: string, v: Verdict, entries: Entry[], r: Config["render"], o?: Override): Placement[] {
  if (o?.hide) return [];
  const score = (e: Entry) => v.p[e.id] ?? 0;
  const acts = entries
    .filter((e) => e.axis === "activity" && score(e) >= r.minP)
    .sort((a, b) => score(b) - score(a))
    .slice(0, r.activities);
  const domains = entries.filter((e) => e.axis === "domain");
  const total = domains.reduce((sum, e) => sum + score(e), 0);
  const others = (e: Entry) => (domains.length > 1 ? (total - score(e)) / (domains.length - 1) : 0);
  const doms = domains
    .filter((e) => score(e) >= r.domainMinP && score(e) >= others(e) + r.domainMargin)
    .sort((a, b) => score(b) - score(a))
    .slice(0, r.domains);
  const out = new Map<string, Placement>();
  for (const e of [...acts, ...doms]) out.set(e.id, { id: e.id, skill: id, p: score(e), pinned: false });
  for (const e of o?.remove ?? []) out.delete(e);
  for (const e of o?.add ?? []) out.set(e, { id: e, skill: id, p: 1, pinned: true });
  return [...out.values()];
}

export function risks(v: Verdict, r: Config["render"], o?: Override): string[] {
  if (o?.tier === "normal") return [];
  const found = (Object.keys(FX) as (keyof typeof FX)[]).filter((k) => (v.p[k] ?? 0) >= r.fxMinP).map((k) => FX_LABEL[k]);
  return o?.tier === "ask" && !found.length ? ["marked ask first"] : found;
}

export function render(store: Store, entries: Entry[], config: Config): { files: number; placed: number; unplaced: string[]; pending: string[] } {
  const overrides = loadOverrides(config.dataDir);
  const byEntry = new Map<string, Placement[]>(entries.map((e) => [e.id, []]));
  const unplaced: string[] = [];
  const pending: string[] = [];
  let placed = 0;
  for (const [id, v] of Object.entries(store.skills)) {
    if (v.pending?.length) pending.push(id);
    const ps = place(id, v, entries, config.render, overrideFor(overrides, id, v));
    if (!ps.length && !v.pending?.length && !overrideFor(overrides, id, v)?.hide) unplaced.push(id);
    if (ps.length) placed++;
    for (const p of ps) byEntry.get(p.id)?.push(p);
  }

  const written = new Set<string>();
  for (const e of entries) {
    const list = byEntry.get(e.id)!.sort((a, b) => b.p - a.p || store.skills[a.skill].name.localeCompare(store.skills[b.skill].name));
    if (!list.length) continue;
    const rel = `${e.axis === "activity" ? "activities" : "domains"}/${e.id}.md`;
    written.add(rel);
    writeIfChanged(join(config.dataDir, rel), entryFile(e, list, store, config, overrides));
  }
  for (const dir of ["activities", "domains"]) {
    const full = join(config.dataDir, dir);
    mkdirSync(full, { recursive: true });
    for (const f of readdirSync(full)) if (f.endsWith(".md") && !written.has(`${dir}/${f}`)) unlinkSync(join(full, f));
  }
  writeIfChanged(join(config.dataDir, "INDEX.md"), index(entries, byEntry, Object.keys(store.skills).length, pending.length, config));
  return { files: written.size, placed, unplaced, pending };
}

function entryFile(e: Entry, list: Placement[], store: Store, config: Config, overrides: Record<string, Override>): string {
  const lines = [`# ${e.id}`, "", `When ${e.when}.`, "", "Ranked by fit. Read the top ones that match the task; open a SKILL.md by its path.", ""];
  list.forEach((p, i) => {
    const v = store.skills[p.skill];
    const notes = [
      ...risks(v, config.render, overrideFor(overrides, p.skill, v)).map((r) => `ask first: ${r}`),
      ...(v.userOnly ? ["not invocable: read the file instead"] : []),
    ];
    lines.push(`${i + 1}. **${v.name}** (${v.source}) ${p.pinned ? "pinned" : p.p.toFixed(2)}`);
    if (v.description) lines.push(`   ${clip(v.description, 260)}`);
    lines.push(`   \`${tilde(v.path)}\`${notes.length ? " · " + notes.join(" · ") : ""}`);
  });
  return lines.join("\n") + "\n";
}

function index(entries: Entry[], byEntry: Map<string, Placement[]>, total: number, pending: number, config: Config): string {
  const lines = [
    "# Skill map",
    "",
    `${total} installed skills, filed by the moment they help with. Use this whenever you start a task or a new goal, including when you are only asked for a plan, a recommendation or an answer, and again whenever you are about to plan, choose, build, test, debug, review, commit, ship, say work is done or write the final report. If a \`skill-scout\` agent is available, dispatch it with the overall goal and your next move: it reads this map and the skills in full, and briefs you. Otherwise, find the lines that match your next move and read the files they name, under \`${tilde(config.dataDir)}/\`. Each file ranks its skills and gives their paths; read every one whose description fits your task, and follow them. You can read any SKILL.md by path, including skills you cannot invoke. Skills marked "ask first" spawn agents, push, deploy or send to outside services: check with the user before following one unless they asked for that. To search by words instead, run \`skill-search find <words>\`.`,
  ];
  let group = "";
  for (const e of entries) {
    const n = byEntry.get(e.id)!.length;
    if (!n) continue;
    if (e.group !== group) {
      group = e.group;
      lines.push("", `## ${group}`);
    }
    lines.push(`- ${e.axis === "activity" ? "activities" : "domains"}/${e.id}.md (${n}): ${e.when}`);
  }
  if (pending) lines.push("", `${pending} skills are new or changed and not filed yet. To file them, run \`skill-search pending\` and follow the skill-search skill.`);
  return lines.join("\n") + "\n";
}

function clip(s: string, n: number): string {
  return s.length <= n ? s : s.slice(0, n - 1).replace(/\s+\S*$/, "") + "…";
}

function writeIfChanged(path: string, content: string): void {
  if (existsSync(path) && readFileSync(path, "utf8") === content) return;
  writeAtomic(path, content);
}
