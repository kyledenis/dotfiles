import { matches, type Config } from "./config.ts";
import { askJev, jevKey, pool } from "./jev.ts";
import type { Found } from "./scan.ts";
import type { Store, Verdict } from "./store.ts";
import type { Question } from "./taxonomy.ts";

export type Job = { skill: Found; qids: string[]; fresh: boolean };
export type Plan = { jobs: Job[]; removed: string[]; refreshed: string[]; unchanged: number };
export type Outcome = { classified: number; pending: number; failed: { id: string; error: string }[] };

export function plan(found: Found[], store: Store, qs: Question[], reclassify = false): Plan {
  const jobs: Job[] = [];
  const refreshed: string[] = [];
  let unchanged = 0;
  const live = new Set(found.map((f) => f.id));
  for (const f of found) {
    const v = store.skills[f.id];
    if (!v || v.input !== f.inputHash || reclassify) {
      jobs.push({ skill: f, qids: qs.map((q) => q.id), fresh: true });
      continue;
    }
    const qids = qs.filter((q) => v.q[q.id] !== q.hash || v.pending?.includes(q.id)).map((q) => q.id);
    if (qids.length) jobs.push({ skill: f, qids, fresh: false });
    else if (v.path !== f.path || v.name !== f.name || v.userOnly !== f.userOnly || hasOrphans(v, qs)) refreshed.push(f.id);
    else unchanged++;
  }
  const removed = Object.keys(store.skills).filter((id) => !live.has(id));
  return { jobs, removed, refreshed, unchanged };
}

function hasOrphans(v: Verdict, qs: Question[]): boolean {
  const ids = new Set(qs.map((q) => q.id));
  return Object.keys(v.p).some((k) => !ids.has(k));
}

export async function execute(p: Plan, found: Found[], store: Store, qs: Question[], config: Config): Promise<Outcome> {
  const byId = new Map(found.map((f) => [f.id, f]));
  const valid = new Set(qs.map((q) => q.id));
  const today = new Date().toISOString().slice(0, 10);
  for (const id of p.removed) delete store.skills[id];
  for (const id of p.refreshed) store.skills[id] = base(byId.get(id)!, store.skills[id], valid, today);

  const key = config.classifier === "jev" ? jevKey(config) : undefined;
  const out: Outcome = { classified: 0, pending: 0, failed: [] };
  await pool(p.jobs, config.jev.concurrency, async (job) => {
    const prev = job.fresh ? undefined : store.skills[job.skill.id];
    const v = base(job.skill, prev, valid, today);
    if (key && !matches(config.private, job.skill.id)) {
      try {
        const answers = await askJev(config, key, job.skill.input, qs.filter((q) => job.qids.includes(q.id)));
        for (const q of qs) if (job.qids.includes(q.id)) {
          v.p[q.id] = answers[q.id];
          v.q[q.id] = q.hash;
        }
        v.pending = (v.pending ?? []).filter((id) => !job.qids.includes(id));
        v.by = config.jev.model;
        store.skills[job.skill.id] = v;
        out.classified++;
        return;
      } catch (e) {
        out.failed.push({ id: job.skill.id, error: String(e) });
        if (prev) return;
      }
    }
    v.pending = [...new Set([...(v.pending ?? []), ...job.qids])];
    store.skills[job.skill.id] = v;
    out.pending++;
  });
  return out;
}

function base(f: Found, prev: Verdict | undefined, valid: Set<string>, today: string): Verdict {
  const keep = <T>(o: Record<string, T> | undefined) => Object.fromEntries(Object.entries(o ?? {}).filter(([k]) => valid.has(k)));
  return {
    name: f.name,
    source: f.source,
    path: f.path,
    description: f.description,
    userOnly: f.userOnly,
    input: f.inputHash,
    by: prev?.by ?? "",
    p: keep(prev?.p),
    q: keep(prev?.q),
    pending: prev?.pending?.filter((id) => valid.has(id)),
    updated: today,
  };
}

export type AgentAnswer = { id: string; input: string; activities?: string[]; domains?: string[]; primary?: string; fx?: string[] };

export function record(store: Store, qs: Question[], answers: AgentAnswer[]): { applied: string[]; rejected: { id: string; why: string }[] } {
  const valid = new Set(qs.map((q) => q.id));
  const applied: string[] = [];
  const rejected: { id: string; why: string }[] = [];
  for (const a of answers) {
    const v = store.skills[a.id];
    if (!v) { rejected.push({ id: a.id, why: "unknown skill id" }); continue; }
    if (v.input !== a.input) { rejected.push({ id: a.id, why: "skill changed since pending was listed; list again" }); continue; }
    const yes = new Set([...(a.activities ?? []), ...(a.domains ?? []), ...(a.fx ?? []).map((x) => (x.startsWith("fx-") ? x : `fx-${x}`))]);
    const bad = [...yes].filter((id) => !valid.has(id));
    if (bad.length) { rejected.push({ id: a.id, why: `unknown ids: ${bad.join(", ")}` }); continue; }
    for (const q of qs) {
      v.p[q.id] = q.id === a.primary ? 0.9 : yes.has(q.id) ? 0.75 : 0.05;
      v.q[q.id] = q.hash;
    }
    v.pending = [];
    v.by = "agent";
    v.updated = new Date().toISOString().slice(0, 10);
    applied.push(a.id);
  }
  return { applied, rejected };
}
