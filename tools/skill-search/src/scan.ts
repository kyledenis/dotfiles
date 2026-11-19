import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { home, matches, type Config } from "./config.ts";
import { classifierInput, readSkill, sha, type Skill } from "./skill.ts";

export type Located = { id: string; source: string; path: string };
export type Found = Located & Skill & { real: string; input: string; inputHash: string };

const flat = (source: string, dir: string): Located[] =>
  subdirs(dir)
    .map((d) => ({ id: `${source}:${d}`, source, path: join(dir, d, "SKILL.md") }))
    .filter((l) => existsSync(l.path));

export function locate(config: Config): Located[] {
  const out: Located[] = [
    ...flat("npx", join(home, ".agents/skills")),
    ...flat("claude", join(home, ".claude/skills")),
    ...claudePlugins(),
    ...synced(),
    ...flat("cursor", join(home, ".cursor/skills")),
    ...flat("codex", join(home, ".codex/skills")),
    ...config.sources.flatMap((s) => flat(s.name, s.path)),
  ];
  return out.filter((l) => !matches(config.exclude, l.id));
}

function claudePlugins(): Located[] {
  const settings = readJson(join(home, ".claude/settings.json"));
  const installed = readJson(join(home, ".claude/plugins/installed_plugins.json"));
  const enabled = Object.entries(settings?.enabledPlugins ?? {}).filter(([, on]) => on).map(([k]) => k);
  return enabled.flatMap((key) => {
    const plugin = key.split("@")[0];
    return (installed?.plugins?.[key] ?? [])
      .filter((e: { scope?: string }) => e.scope === "user")
      .flatMap((e: { installPath: string }) => nested(`plugin:${plugin}`, join(e.installPath, "skills")));
  });
}

function synced(): Located[] {
  const root = join(home, ".claude/plugins/synced");
  return subdirs(root).flatMap((account) =>
    subdirs(join(root, account)).flatMap((plugin) =>
      nested(`synced:${plugin.split("~")[0]}`, join(root, account, plugin, "skills")),
    ),
  );
}

function nested(prefix: string, dir: string): Located[] {
  if (!existsSync(dir)) return [];
  const files = (readdirSync(dir, { recursive: true }) as string[]).filter((f) => basename(f) === "SKILL.md").sort();
  const roots = new Set(files.map((f) => dirname(f)));
  const insideAnother = (f: string) => {
    for (let d = dirname(dirname(f)); d !== "." && d !== "/"; d = dirname(d)) if (roots.has(d)) return true;
    return false;
  };
  return files
    .filter((f) => !insideAnother(f))
    .map((f) => ({ id: `${prefix}/${basename(dirname(join(dir, f)))}`, source: prefix, path: join(dir, f) }));
}

function subdirs(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => !d.name.startsWith(".") && (d.isDirectory() || d.isSymbolicLink()))
    .map((d) => d.name)
    .sort();
}

function readJson(path: string) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return undefined;
  }
}

export function scan(config: Config): Found[] {
  const byReal = new Set<string>();
  const byContent = new Set<string>();
  const ids = new Set<string>();
  const out: Found[] = [];
  for (const l of locate(config)) {
    let real: string;
    try {
      real = realpathSync(l.path);
    } catch {
      continue;
    }
    if (byReal.has(real) || ids.has(l.id)) continue;
    byReal.add(real);
    const skill = readSkill(real);
    const input = classifierInput(skill);
    const inputHash = sha(input);
    if (byContent.has(skill.name + "\0" + inputHash)) continue;
    byContent.add(skill.name + "\0" + inputHash);
    ids.add(l.id);
    out.push({ ...l, ...skill, real, input, inputHash });
  }
  return out;
}

export function fingerprint(config: Config, extra: string[]): string {
  const lines = locate(config).map((l) => {
    try {
      const s = statSync(l.path);
      return `${l.id}\t${s.mtimeMs}\t${s.size}`;
    } catch {
      return `${l.id}\t-`;
    }
  });
  for (const f of extra) lines.push(`${f}\t${existsSync(f) ? statSync(f).mtimeMs : "-"}`);
  return sha(lines.join("\n"), 32);
}
