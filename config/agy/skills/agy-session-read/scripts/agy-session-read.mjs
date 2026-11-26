import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

const UUID = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
const USAGE = "Usage: node agy-session-read.mjs <uuid-or-path> [--last <turns>] [--before <turn>] [--tools]";
const MAX_EXCERPT = 14_000;
const MAX_ENTRY = 4_000;
const TOOL_DETAIL = new Map([
  ["run_command", ["CommandLine"]],
  ["read_file", ["Path", "AbsolutePath"]],
  ["view_file", ["AbsolutePath", "Path"]],
  ["write_to_file", ["TargetFile", "Path"]],
  ["replace_file_content", ["TargetFile", "Path"]],
  ["multi_replace_file_content", ["TargetFile", "Path"]],
]);

function clip(text, limit) {
  return text.length > limit ? `${text.slice(0, limit - 1)}…` : text;
}

function resolveTranscriptPath(target) {
  if (UUID.test(target)) {
    const id = target.toLowerCase();
    const logs = join(homedir(), ".gemini", "antigravity-cli", "brain", id, ".system_generated", "logs");
    for (const file of ["transcript_full.jsonl", "transcript.jsonl"]) {
      const path = join(logs, file);
      if (existsSync(path)) return { label: id, path };
    }
    throw new Error(`No native transcript found for ${id}.`);
  }
  const path = target.startsWith("~/") ? resolve(homedir(), target.slice(2)) : resolve(target);
  if (!existsSync(path)) throw new Error(`Transcript file not found: ${path}`);
  return { label: path, path };
}

function parseTurns(text, tools) {
  const lines = text.split("\n");
  const turns = [];
  let current = [];
  for (const [i, line] of lines.entries()) {
    if (!line.trim()) continue;
    let row;
    try {
      row = JSON.parse(line);
    } catch {
      if (i === lines.length - 1) break;
      throw new Error(`Invalid JSON in transcript at line ${i + 1}.`);
    }
    if (row?.type === "USER_INPUT") {
      if (current.length) turns.push(current);
      current = typeof row.content === "string" && row.content.trim()
        ? [{ label: "User", body: row.content.trim() }]
        : [];
    } else if (row?.type === "PLANNER_RESPONSE") {
      if (typeof row.content === "string" && row.content.trim()) {
        const truncated = Array.isArray(row.truncated_fields) && row.truncated_fields.includes("content");
        const body = truncated ? `${row.content.trim()}\n[Antigravity truncated this message in its saved log.]` : row.content.trim();
        current.push({ label: "Assistant", body });
      }
      if (tools && Array.isArray(row.tool_calls)) {
        for (const call of row.tool_calls) {
          if (typeof call?.name !== "string") continue;
          const detail = TOOL_DETAIL.get(call.name)?.map((k) => call.args?.[k]).find((v) => typeof v === "string" && v.trim());
          current.push({ label: "Tool", body: `${call.name}${detail ? `: ${detail}` : ""}` });
        }
      }
    }
  }
  if (current.length) turns.push(current);
  return turns;
}

function render(label, turns, last, before) {
  const end = before === undefined ? turns.length : Math.min(turns.length, before - 1);
  const start = Math.max(0, end - last);
  const blocks = [];
  let used = 0;
  let firstShown = end + 1;
  for (let i = end - 1; i >= start; i--) {
    const text = turns[i].map(({ label: role, body }) => clip(`### ${role}\n${body}`, MAX_ENTRY)).join("\n\n");
    if (blocks.length && used + text.length + 2 > MAX_EXCERPT) break;
    blocks.push(text);
    used += text.length + 2;
    firstShown = i + 1;
  }
  const header = [`Antigravity conversation ${label} (${turns.length} turns).`];
  if (blocks.length) header[0] = `Antigravity conversation ${label} (turns ${firstShown}-${end} of ${turns.length}).`;
  if (firstShown > 1 && blocks.length) header.push(`Older turns: repeat with --before ${firstShown}.`);
  return `${header.join("\n")}\n\n${blocks.reverse().join("\n\n") || "No dialogue found in the requested turns."}`;
}

try {
  const { values, positionals } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      help: { type: "boolean", short: "h" },
      last: { type: "string", default: "5" },
      before: { type: "string" },
      tools: { type: "boolean", default: false },
    },
  });
  if (values.help) {
    console.log(USAGE);
    process.exit(0);
  }
  const [target] = positionals;
  if (positionals.length !== 1) throw new Error(`Pass one conversation UUID or transcript path. ${USAGE}`);
  const last = Number(values.last);
  if (!Number.isSafeInteger(last) || last < 1) throw new Error("--last must be a positive integer.");
  const before = values.before === undefined ? undefined : Number(values.before);
  if (before !== undefined && (!Number.isSafeInteger(before) || before < 1)) throw new Error("--before must be a positive integer.");

  const { label, path } = resolveTranscriptPath(target);
  const turns = parseTurns(readFileSync(path, "utf8"), values.tools);
  console.log(render(label, turns, last, before));
} catch (error) {
  console.error(`agy-session-read: ${error.message}`);
  process.exitCode = 1;
}
