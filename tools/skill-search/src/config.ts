import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { parse } from "yaml";
import { DEFAULT_EMBED, type Embed } from "./embed.ts";

export type ExtraSource = { name: string; path: string };

export type Config = {
  dataDir: string;
  stateDir: string;
  sources: ExtraSource[];
  exclude: string[];
  private: string[];
  classifier: "jev" | "none";
  jev: { url: string; model: string; keyEnv: string; keyFile?: string; concurrency: number };
  render: { activities: number; minP: number; domains: number; domainMinP: number; domainMargin: number; fxMinP: number };
  filer?: { command: string; model: string; max: number };
  embed?: Embed;
};

export const home = homedir();

export function expand(p: string): string {
  return p === "~" ? home : p.startsWith("~/") ? join(home, p.slice(2)) : p;
}

export function tilde(p: string): string {
  return p.startsWith(home + "/") ? "~" + p.slice(home.length) : p;
}

export function dataDir(): string {
  return expand(process.env.SKILL_SEARCH_DIR ?? process.env.SKILL_MAP_DIR ?? "~/.agents/skill-search");
}

export function loadConfig(dir = dataDir()): Config {
  const file = join(dir, "config.yaml");
  const raw = existsSync(file) ? (parse(readFileSync(file, "utf8")) ?? {}) : {};
  const state = process.env.XDG_STATE_HOME ? join(process.env.XDG_STATE_HOME, "skill-search") : join(home, ".local/state/skill-search");
  return {
    dataDir: dir,
    stateDir: state,
    sources: (raw.sources ?? []).map((s: ExtraSource) => ({ name: s.name, path: expand(s.path) })),
    exclude: raw.exclude ?? [],
    private: raw.private ?? [],
    classifier: raw.classifier ?? "jev",
    jev: {
      url: raw.jev?.url ?? "https://api.typesafe.ai/v1/systemone",
      model: raw.jev?.model ?? "jev-1.13.0",
      keyEnv: raw.jev?.keyEnv ?? "TYPESAFE_API_KEY",
      keyFile: raw.jev?.keyFile ? expand(raw.jev.keyFile) : undefined,
      concurrency: raw.jev?.concurrency ?? 8,
    },
    render: {
      activities: raw.render?.activities ?? 4,
      minP: raw.render?.minP ?? 0.5,
      domains: raw.render?.domains ?? 2,
      domainMinP: raw.render?.domainMinP ?? 0.6,
      domainMargin: raw.render?.domainMargin ?? 0.3,
      fxMinP: raw.render?.fxMinP ?? 0.5,
    },
    filer: filer(raw.filer),
    embed: embed(raw.embed),
  };
}

/** `filer: claude` or `filer: {command, model, max}` turns on automatic filing; absent or `none` leaves pending skills for an agent. */
function filer(raw: unknown): Config["filer"] {
  if (!raw || raw === "none") return undefined;
  const o = (typeof raw === "string" ? { command: raw } : raw) as { command?: string; model?: string; max?: number };
  return { command: o.command ?? "claude", model: o.model ?? "sonnet", max: o.max ?? 10 };
}

/** Search by meaning is on unless `embed: none`; `embed: {url, model}` points it at another OpenAI-compatible embeddings endpoint. */
function embed(raw: unknown): Config["embed"] {
  if (raw === "none" || raw === false) return undefined;
  const o = raw && typeof raw === "object" ? (raw as { url?: unknown; model?: unknown }) : {};
  return { url: typeof o.url === "string" ? o.url : DEFAULT_EMBED.url, model: typeof o.model === "string" ? o.model : DEFAULT_EMBED.model };
}

export function matches(patterns: string[], id: string): boolean {
  return patterns.some((p) => new RegExp("^" + p.split("*").map(escape).join(".*") + "$").test(id));
}

function escape(s: string): string {
  return s.replace(/[.+?^${}()|[\]\\]/g, "\\$&");
}
