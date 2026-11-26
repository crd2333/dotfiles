#!/usr/bin/env node
/**
 * Sync the dedicated headless Pi profile (~/.pi/agent-headless) from the
 * primary ~/.pi/agent directory and tracked headless overlay.
 *
 * Symlinks shared credentials, models, packages, and non-interactive extension
 * configs into ~/.pi/agent-headless while keeping sessions isolated and
 * filtering out user-interactive extensions via config/pi/settings-headless.json
 * (plus optional untracked config/pi/settings-headless.local.json).
 *
 * Usage: node sync_pi_headless.mjs [--dry-run]
 */
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  rmSync,
  statSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { delimiter, dirname, join, resolve } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const DOTFILES = dirname(fileURLToPath(import.meta.url));
const HOME = homedir();
const DRY_RUN = process.argv.slice(2).includes("--dry-run") || process.argv.slice(2).includes("-n");

const SHARED_ENTRIES = [
  "auth.json",
  "models.json",
  "models-store.json",
  "mcp.json",
  "trust.json",
  "pi-vcc-config.json",
  "pi-crd233.json",
  "pi-crd233-content",
  "git",
  "npm",
  "bin",
  "cache",
  "fff",
  "skills",
];

const SHARED_EXTENSION_CONFIGS = [
  "pi-client-fingerprint",
  "pi-crd233",
];

const isPlainObject = (value) =>
  typeof value === "object" && value !== null && !Array.isArray(value);

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

function isExecutableFile(path) {
  try {
    if (!statSync(path).isFile()) return false;
    return process.platform === "win32" || (statSync(path).mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

function piDetected(srcDir) {
  if (existsSync(srcDir)) return true;
  const extensions =
    process.platform === "win32"
      ? (process.env.PATHEXT ?? ".COM;.EXE;.BAT;.CMD").split(";").filter(Boolean)
      : [""];
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    if (!dir) continue;
    for (const extension of extensions) {
      if (isExecutableFile(join(dir, "pi" + extension))) return true;
    }
  }
  return false;
}

function ensureSymlink(src, dst) {
  if (!existsSync(src)) return;
  let existing = null;
  try {
    existing = lstatSync(dst);
  } catch {
    existing = null;
  }

  if (existing && existing.isSymbolicLink()) {
    try {
      const currentTarget = readlinkSync(dst);
      if (resolve(dirname(dst), currentTarget) === resolve(src)) return;
    } catch {}
  }

  if (DRY_RUN) {
    console.log(`[pi-headless] would link: ${dst} -> ${src}`);
    return;
  }

  mkdirSync(dirname(dst), { recursive: true });
  if (existing) rmSync(dst, { recursive: true, force: true });
  const isDir = statSync(src).isDirectory();
  symlinkSync(src, dst, isDir ? "junction" : "file");
  console.log(`[pi-headless] linked: ${dst} -> ${src}`);
}

function main() {
  const srcDir = join(HOME, ".pi", "agent");
  const dstDir = join(HOME, ".pi", "agent-headless");
  const overlayPath = join(DOTFILES, "config", "pi", "settings-headless.json");
  const localOverlayPath = join(DOTFILES, "config", "pi", "settings-headless.local.json");

  if (!piDetected(srcDir)) {
    console.log(`[pi-headless] skipped (pi not installed): ${dstDir}`);
    return 0;
  }
  if (!existsSync(overlayPath)) {
    console.warn(`[pi-headless] warning: overlay does not exist: ${overlayPath}`);
    return 0;
  }

  if (!DRY_RUN) {
    mkdirSync(join(dstDir, "extensions"), { recursive: true });
  }

  for (const name of SHARED_ENTRIES) {
    ensureSymlink(join(srcDir, name), join(dstDir, name));
  }
  for (const extCfg of SHARED_EXTENSION_CONFIGS) {
    ensureSymlink(join(srcDir, "extensions", extCfg), join(dstDir, "extensions", extCfg));
  }

  let base;
  let overlay;
  let local;
  try {
    base = readJson(join(srcDir, "settings.json")) ?? {};
    overlay = readJson(overlayPath) ?? {};
    local = existsSync(localOverlayPath) ? readJson(localOverlayPath) ?? {} : {};
  } catch (error) {
    console.error(`[pi-headless] error: ${error.message}`);
    return 1;
  }

  const next = merge(merge(base, overlay), local);
  delete next.extensionChangelogVersions;

  const target = join(dstDir, "settings.json");
  const serialized = JSON.stringify(next, null, 2);
  let targetIsSymlink = false;
  try {
    targetIsSymlink = lstatSync(target).isSymbolicLink();
  } catch {}

  const current = existsSync(target) ? readFileSync(target, "utf8") : undefined;
  if (!targetIsSymlink && current !== undefined && current.trimEnd() === serialized) {
    console.log(`[pi-headless] unchanged: ${target}`);
    return 0;
  }

  const hasLocal = existsSync(localOverlayPath);
  if (DRY_RUN) {
    console.log(`[pi-headless] would apply: ${target} <- ${overlayPath}${hasLocal ? ` + ${localOverlayPath}` : ""}`);
    return 0;
  }

  mkdirSync(dirname(target), { recursive: true });
  if (targetIsSymlink) unlinkSync(target);
  writeFileSync(target, serialized + "\n", process.platform === "win32" ? { encoding: "utf8" } : { encoding: "utf8", mode: 0o600 });
  console.log(`[pi-headless] applied: ${target} <- ${overlayPath}${hasLocal ? ` + ${localOverlayPath}` : ""}`);
  return 0;
}

process.exit(main());
