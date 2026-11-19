import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { basename, dirname } from "node:path";
import { parse } from "yaml";

export type Skill = {
  name: string;
  description: string;
  userOnly: boolean;
  headings: string[];
};

export function sha(s: string, len = 16): string {
  return createHash("sha256").update(s).digest("hex").slice(0, len);
}

export function readSkill(path: string): Skill {
  return parseSkill(readFileSync(path, "utf8"), basename(dirname(path)));
}

export function parseSkill(text: string, fallbackName: string): Skill {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  const fm = m ? frontmatter(m[1]) : {};
  return {
    name: str(fm.name) || fallbackName,
    description: str(fm.description).replace(/\s+/g, " ").trim(),
    userOnly: fm["disable-model-invocation"] === true || fm["disable-model-invocation"] === "true",
    headings: headings(m ? text.slice(m[0].length) : text),
  };
}

function frontmatter(block: string): Record<string, unknown> {
  try {
    const v = parse(block);
    if (v && typeof v === "object") return v as Record<string, unknown>;
  } catch {}
  const out: Record<string, unknown> = {};
  const lines = block.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const kv = lines[i].match(/^([\w-]+):\s*(.*)$/);
    if (!kv) continue;
    let value = kv[2].trim();
    if (/^[>|]-?$/.test(value) || value === "") {
      const body: string[] = [];
      while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1])) body.push(lines[++i].trim());
      value = body.join(" ");
    }
    out[kv[1]] = value.replace(/^["']|["']$/g, "");
  }
  return out;
}

function str(v: unknown): string {
  return typeof v === "string" ? v.trim() : v == null ? "" : String(v);
}

export function headings(body: string): string[] {
  const out: string[] = [];
  let fence = false;
  for (const line of body.split(/\r?\n/)) {
    if (line.trimStart().startsWith("```")) fence = !fence;
    if (!fence && /^#{2,3} /.test(line)) out.push(line.replace(/^#+\s*|\s*#*\s*$/g, ""));
    if (out.length === 40) break;
  }
  return out;
}

export function classifierInput(s: Skill): string {
  let out = `Agent skill: ${s.name}\nDescription: ${s.description}`;
  if (s.headings.length) out += `\nSection headings: ${s.headings.join("; ")}`;
  return out;
}
