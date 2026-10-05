#!/usr/bin/env node
/**
 * Merge JSON config overlays into live files, key by key.
 *
 * Some tools own a JSON config file and keep rewriting it with their own
 * machine-local state (Pi writes `deviceId`, `packages`, and
 * `lastChangelogVersion` into `~/.pi/agent/settings.json`). Symlinking such a
 * file into dotfiles would drag that state around and dirty this repo on every
 * write. This script merges a tracked overlay into the live file instead and
 * leaves every key it does not define untouched.
 *
 * Entries are `source|target|tool`, one per line, like create_symlink.sh:
 *   source  tracked JSON file holding the keys to enforce
 *   target  live JSON file to merge into (created when missing)
 *   tool    optional command or absolute path; the entry is skipped when the
 *           tool is not installed (empty column = always)
 *
 * A sibling `<source stem>.local.json` (e.g. `settings.json` ->
 * `settings.local.json`) is merged after the source when it exists, so
 * machine-local overrides stay untracked via the repo's `*.local.json` rule.
 *
 * Merge rules: later layers win per key; objects merge recursively; arrays and
 * scalars are replaced. Keys that only exist in the target are preserved.
 *
 * A target that is still a symlink (left over from a previous symlink-managed
 * setup, e.g. `~/.pi/agent/models.json -> dotfiles/config/pi/models.json`) is
 * replaced by a real file: writing through the link would rewrite the tracked
 * dotfiles file and silently commit live machine state into the repo.
 *
 * Usage: node merge_json.mjs [--dry-run]
 */
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { delimiter, dirname, join } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const DOTFILES = dirname(fileURLToPath(import.meta.url));
const HOME = homedir();

// Merge list, each line is fully self-contained: source|target|tool
//   tool column empty -> always merge
const PAIRS = `
${DOTFILES}/config/pi/settings.json|${HOME}/.pi/agent/settings.json|pi
${DOTFILES}/config/pi/models.json|${HOME}/.pi/agent/models.json|pi
`;

const DRY_RUN = process.argv.slice(2).includes("--dry-run") || process.argv.slice(2).includes("-n");

const isPlainObject = (value) =>
  typeof value === "object" && value !== null && !Array.isArray(value);

// Objects merge recursively; arrays and scalars are replaced by the overlay.
function merge(base, overlay) {
  const out = { ...base };
  for (const [key, value] of Object.entries(overlay)) {
    out[key] =
      isPlainObject(value) && isPlainObject(out[key])
        ? merge(out[key], value)
        : value;
  }
  return out;
}

function readJson(path) {
  if (!existsSync(path)) return undefined;
  const raw = readFileSync(path, "utf8").trim();
  if (raw === "") return {};
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`${path}: ${error.message}`);
  }
}

// A sibling override for `foo.json` is `foo.local.json`; otherwise `foo.local`.
function localPathFor(source) {
  return source.endsWith(".json")
    ? `${source.slice(0, -".json".length)}.local.json`
    : `${source}.local`;
}

function isSymlink(path) {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

function readlinkSafe(path) {
  try {
    return readlinkSync(path);
  } catch {
    return "?";
  }
}

function isExecutableFile(path) {
  try {
    if (!statSync(path).isFile()) return false;
    return process.platform === "win32" || (statSync(path).mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

// Mirror create_symlink.sh's check_tool: absolute/relative paths are tested for
// existence, plain names are looked up on PATH (with PATHEXT on Windows).
function toolInstalled(candidate) {
  if (!candidate) return true;
  if (/^[A-Za-z]:[\\/]/.test(candidate) || candidate.includes("/") || candidate.includes("\\")) {
    const expanded = candidate.startsWith("~")
      ? join(HOME, candidate.slice(1))
      : candidate;
    return existsSync(expanded);
  }
  const extensions =
    process.platform === "win32"
      ? (process.env.PATHEXT ?? ".COM;.EXE;.BAT;.CMD").split(";").filter(Boolean)
      : [""];
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    if (!dir) continue;
    for (const extension of extensions) {
      if (isExecutableFile(join(dir, candidate + extension))) return true;
    }
  }
  return false;
}

function mergeEntry(source, target, tool) {
  if (!toolInstalled(tool)) {
    console.log(`[merge] skipped (${tool} not installed): ${target}`);
    return true;
  }
  if (!existsSync(source)) {
    console.warn(`[merge] warning: source does not exist: ${source}`);
    return true;
  }

  const localSource = localPathFor(source);
  const hasLocal = existsSync(localSource);
  // A leftover symlink target must never be written through: the merged file
  // would land in dotfiles and dirty (or later commit) the tracked file.
  const targetIsSymlink = isSymlink(target);

  let live;
  let overlay;
  let local;
  try {
    live = readJson(target) ?? {};
    overlay = readJson(source) ?? {};
    local = hasLocal ? readJson(localSource) ?? {} : {};
  } catch (error) {
    console.error(`[merge] error: ${error.message}`);
    return false;
  }

  const next = merge(merge(live, overlay), local);
  const serialized = JSON.stringify(next, null, 2);
  const current = existsSync(target) ? readFileSync(target, "utf8") : undefined;

  // Even when the content already matches, a symlink target is still
  // replaced so the next tool-driven write cannot escape into dotfiles.
  if (!targetIsSymlink && current !== undefined && current.trimEnd() === serialized) {
    console.log(`[merge] unchanged: ${target}`);
    return true;
  }

  const replaced = targetIsSymlink ? ` (replaced symlink -> ${readlinkSafe(target)})` : "";

  if (DRY_RUN) {
    console.log(
      `[merge] would apply: ${target} <- ${source}${hasLocal ? ` + ${localSource}` : ""}` +
        (targetIsSymlink ? ` (would replace symlink -> ${readlinkSafe(target)})` : ""),
    );
    return true;
  }

  mkdirSync(dirname(target), { recursive: true });
  // Unlink first so the new file is written in place instead of following the
  // link into the dotfiles checkout.
  if (targetIsSymlink) unlinkSync(target);
  writeFileSync(target, serialized + "\n", "utf8");
  console.log(`[merge] applied: ${target} <- ${source}${hasLocal ? ` + ${localSource}` : ""}${replaced}`);
  return true;
}

function main() {
  let ok = true;
  for (const rawLine of PAIRS.split("\n")) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;

    const [source, target, tool = ""] = line.split("|").map((part) => part.trim());
    if (!source || !target) {
      console.error(`[merge] error: malformed entry (expected source|target|tool): ${line}`);
      ok = false;
      continue;
    }
    if (!mergeEntry(source, target, tool)) ok = false;
  }
  return ok ? 0 : 1;
}

process.exit(main());
