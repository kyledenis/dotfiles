import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { matches, type Config } from "./config.ts";
import { sha } from "./skill.ts";
import type { Store } from "./store.ts";
import type { AgentAnswer } from "./sync.ts";
import type { Entry } from "./taxonomy.ts";

export type Filer = { command: string; model: string; max: number };

export const FILING_ENV = "SKILL_SEARCH_FILING";
const RETRY_AFTER_MS = 24 * 60 * 60 * 1000;
const TIMEOUT_MS = 10 * 60 * 1000;
const MAX_SKILL_CHARS = 30_000;

/** Pending skills that are kept from the classifier on purpose (private, or no key). Classifier failures retry on the next sync instead. */
export function fileable(store: Store, config: Config, hasKey: boolean, max = Infinity): string[] {
  return Object.entries(store.skills)
    .filter(([id, v]) => v.pending?.length && (!hasKey || matches(config.private, id)))
    .map(([id]) => id)
    .sort()
    .slice(0, max);
}

export function batchKey(ids: string[], store: Store): string {
  return sha(ids.map((id) => `${id}\0${store.skills[id].input}`).join("\n"));
}

/** Work that failed is not retried within `after` ms unless it changes. `last` is the saved "<key> <iso time>" line. */
export function shouldRetry(last: string | undefined, key: string, now: number, after = RETRY_AFTER_MS): boolean {
  const [k, at] = (last ?? "").split(" ");
  return k !== key || !(now - Date.parse(at) < after);
}

export function filerPrompt(skills: { id: string; text: string }[], entries: Entry[]): string {
  const vocabulary = entries.map(({ id, axis, when, yes, no }) => ({ id, axis, when, ...(yes && { yes }), ...(no && { no }) }));
  return [
    "You are filing agent skills into a map that tells coding agents which skills to open at each moment of their work.",
    "",
    'For each skill below, read its whole SKILL.md. For every taxonomy entry, ask: "Would an AI coding agent that is <when> be better off opening this skill?" Say yes only when the skill has real guidance for that moment, not a passing mention. Respect each entry\'s yes/no boundary. Most skills fit one to three activities. No domain is fine.',
    "Pick one primary activity. In fx, list what following the skill does: spawns (launches subagents or model runs), pushes (pushes commits, opens or merges pull requests, deploys), external (posts or writes to an outside service).",
    "",
    "Reply with one JSON object per skill, one per line, and nothing else:",
    '{"id": "<skill id>", "activities": ["<activity ids>"], "domains": ["<domain ids>"], "primary": "<activity id>", "fx": ["spawns" | "pushes" | "external"]}',
    "",
    "Taxonomy:",
    JSON.stringify(vocabulary),
    ...skills.flatMap((s) => ["", `=== skill ${s.id} ===`, s.text.slice(0, MAX_SKILL_CHARS)]),
  ].join("\n");
}

/** Keeps one answer per requested skill and stamps it with the input it was filed against. Prose and code fences are skipped. */
export function parseReply(text: string, store: Store, ids: string[]): AgentAnswer[] {
  const wanted = new Set(ids);
  const out = new Map<string, AgentAnswer>();
  for (const line of text.split("\n")) {
    const t = line.trim();
    if (!t.startsWith("{")) continue;
    let a: Record<string, unknown>;
    try {
      a = JSON.parse(t);
    } catch {
      continue;
    }
    if (typeof a.id !== "string" || !wanted.has(a.id) || out.has(a.id)) continue;
    out.set(a.id, {
      id: a.id,
      input: store.skills[a.id].input,
      activities: strings(a.activities),
      domains: strings(a.domains),
      primary: typeof a.primary === "string" ? a.primary : undefined,
      fx: strings(a.fx),
    });
  }
  return [...out.values()];
}

function strings(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
}

/** Headless Claude Code with no tools, MCP servers, hooks or saved session, so filing cannot act or set off another sync. */
export function filerArgs(model: string): string[] {
  return [
    "-p",
    "--model", model,
    "--tools", "",
    "--strict-mcp-config",
    "--setting-sources", "",
    "--settings", JSON.stringify({ disableAllHooks: true }),
    "--no-session-persistence",
    "--output-format", "text",
  ];
}

export function runFiler(filer: Filer, prompt: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(filer.command, filerArgs(filer.model), {
      cwd: tmpdir(),
      env: { ...process.env, [FILING_ENV]: "1" },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let out = "";
    let err = "";
    const timer = setTimeout(() => child.kill("SIGTERM"), TIMEOUT_MS);
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) => (clearTimeout(timer), reject(e)));
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      if (code === 0) resolve(out);
      else reject(new Error(`${filer.command} exited ${signal ?? code}: ${err.trim().slice(0, 300)}`));
    });
    child.stdin.end(prompt);
  });
}
