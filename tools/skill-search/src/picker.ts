import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createServer, request } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { tilde } from "./config.ts";
import type { Card } from "./find.ts";
import type { Mode, Searcher } from "./searcher.ts";

/** What the person chose in the picker. */
export type Picked = { kind: "print"; card: Card } | { kind: "copy"; card: Card } | { kind: "quit" };

const NAME_WIDTH = 28;
const QUERY_TIMEOUT_MS = 1500;
const WARM_TIMEOUT_MS = 60_000;

// Each style closes only itself, so a highlighted word inside a bold name leaves the rest of the name bold.
const esc = (on: string, off: string) => (s: string) => `\x1b[${on}m${s}\x1b[${off}m`;
export const bold = esc("1", "22");
export const dim = esc("2", "22");
const green = esc("32", "39");
const cyan = esc("36", "39");
const yellow = esc("33", "39");

/** Highlights the starts of query words, the same places the keyword search matches. */
export function highlight(text: string, words: string[]): string {
  if (!words.length) return text;
  const re = new RegExp(`(^|[^a-z0-9])(${words.map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})`, "gi");
  return text.replace(re, (_, pre: string, w: string) => pre + yellow(w));
}

/** One fzf line: hidden id, path and slash command, then the name in a fixed column and the description. */
export function line(c: Card, words: string[]): string {
  const name = c.name.length > NAME_WIDTH ? c.name.slice(0, NAME_WIDTH - 1) + "…" : c.name.padEnd(NAME_WIDTH);
  const description = c.description.replace(/\s+/g, " ");
  return `${c.id}\t${c.path}\t${c.invoke ?? ""}\t${bold(highlight(name, words))}  ${highlight(description, words)}`;
}

export const queryWords = (q: string) => q.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 1);

/** The preview: what to type, where it is filed and where it lives, then the skill's own text without its frontmatter. */
export function preview(c: Card, width: number, body: string): string {
  const head = [
    `${bold(c.name)}  ${dim(c.source)}`,
    ...(c.invoke ? [green(c.invoke)] : []),
    ...(c.moments.length ? [cyan(c.moments.join(" · "))] : []),
    dim(tilde(c.path)),
    "",
    c.description,
    "",
    dim("─".repeat(Math.max(10, Math.min(width, 120) - 1))),
    "",
  ];
  return head.join("\n") + "\n" + body;
}

export function stripFrontmatter(text: string): string {
  return text.replace(/^---\n[\s\S]*?\n---\n*/, "");
}

export function footer(mode: Mode | undefined): string {
  const keys = `${bold("enter")} print  ${bold("ctrl-y")} copy  ${bold("esc")} quit`;
  return mode?.by === "words" && mode.why && mode.why !== "off" ? `${keys}   ${dim(`words only: ${mode.why}`)}` : keys;
}

/** Reads fzf's output (the --expect key, then the chosen line) into what the person picked. */
export function parsePick(out: string, status: number | null, cards: Map<string, Card>): Picked {
  const [key = "", chosen = ""] = out.split("\n");
  const card = cards.get(chosen.split("\t")[0]);
  if (status !== 0 || !card) return { kind: "quit" };
  return key === "ctrl-y" ? { kind: "copy", card } : { kind: "print", card };
}

const q1 = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`;

export async function pick(searcher: Searcher, initial: string): Promise<Picked> {
  const dir = mkdtempSync(join(tmpdir(), "skill-search-"));
  const sock = join(dir, "s.sock");
  const fzfSock = join(dir, "fzf.sock");
  const byId = new Map(searcher.cards.map((c) => [c.id, c]));
  const bodies = new Map<string, string>();
  let mode: Mode | undefined;
  let current = initial;
  let warm = false;

  const lines = async (q: string) => {
    current = q;
    const r = await searcher.query(q, warm ? QUERY_TIMEOUT_MS : 300);
    mode = r.mode;
    return r.cards.map((c) => line(c, queryWords(q))).join("\n") + "\n";
  };
  const body = (c: Card) => {
    let b = bodies.get(c.id);
    if (b === undefined) {
      let text = "";
      try {
        text = stripFrontmatter(readFileSync(c.path, "utf8"));
      } catch (e) {
        text = `could not read ${c.path}: ${e instanceof Error ? e.message : e}`;
      }
      const bat = spawnSync("bat", ["--language=md", "--color=always", "--style=plain", "--paging=never"], { input: text, encoding: "utf8" });
      b = bat.status === 0 && bat.stdout ? bat.stdout : text;
      bodies.set(c.id, b);
    }
    return b;
  };

  const server = createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", "http://picker");
    try {
      if (url.pathname === "/lines") return res.end(await lines(url.searchParams.get("q") ?? ""));
      if (url.pathname === "/footer") return res.end(footer(mode));
      if (url.pathname === "/preview") {
        const c = byId.get(url.searchParams.get("id") ?? "");
        return res.end(c ? preview(c, Number(url.searchParams.get("w")) || 80, body(c)) : "");
      }
      res.statusCode = 404;
      res.end();
    } catch (e) {
      res.end(`skill-search: ${e instanceof Error ? e.message : e}\n`);
    }
  });
  await new Promise<void>((done) => server.listen(sock, done));

  const curl = `curl -s --unix-socket ${q1(sock)} -G http://picker`;
  const tell = (action: string) => {
    const r = request({ socketPath: fzfSock, method: "POST", path: "/" }, (res) => res.resume());
    r.on("error", () => {});
    r.end(action);
  };
  // Load the embedding model while the person types, then re-run their query by meaning.
  void searcher.prepare(WARM_TIMEOUT_MS).then(async (down) => {
    if (down) return;
    const r = await searcher.query("warm", WARM_TIMEOUT_MS);
    warm = r.mode.by === "meaning";
    if (warm && current.trim()) tell(`reload(${curl}/lines --data-urlencode q={q})+transform-footer(${curl}/footer)`);
  });

  const first = await lines(initial);
  const fzf = spawn(
    "fzf",
    [
      "--ansi", "--disabled", "--no-sort", "--layout=reverse", "--no-hscroll", "--highlight-line", "--height=80%", "--min-height=20",
      "--delimiter=\t", "--with-nth=4",
      "--border=rounded", "--border-label= skill-search ", "--border-label-pos=3",
      "--prompt=› ", "--ghost=a task, a direction or a skill name", "--info=inline-right", "--info-command=echo \"${FZF_INFO%%/*}\"",
      "--query", initial,
      "--preview", `${curl}/preview --data-urlencode id={1} --data-urlencode w=$FZF_PREVIEW_COLUMNS`,
      "--preview-window=right,50%,wrap,border-left,<60(down,50%,wrap,border-top)",
      "--footer", footer(mode),
      "--bind", `change:reload(${curl}/lines --data-urlencode q={q})`,
      // A reload can land after fzf has previewed the old first row, so redraw the preview with each new result list.
      "--bind", `result:transform-footer(${curl}/footer)+refresh-preview`,
      "--listen", fzfSock,
      "--expect=ctrl-y",
    ],
    { stdio: ["pipe", "pipe", "inherit"] },
  );
  fzf.stdin.end(first);
  let out = "";
  fzf.stdout.setEncoding("utf8").on("data", (d: string) => (out += d));
  // A closed terminal or a kill ends fzf and this process together; remove the sockets on the way out.
  const cleanup = () => rmSync(dir, { recursive: true, force: true });
  const signals = ["SIGHUP", "SIGTERM", "SIGINT"] as const;
  const onSignal = () => (cleanup(), process.exit(130));
  for (const s of signals) process.once(s, onSignal);
  const status = await new Promise<number | null>((done) => fzf.on("close", done));
  for (const s of signals) process.off(s, onSignal);
  server.close();
  cleanup();
  return parsePick(out, status, byId);
}
