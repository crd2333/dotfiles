import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";

// Isolated POSIX HOME/PATH fixtures: never merge into the operator's real Pi files.
const relative = "config/pi/extensions/pi-crd233/pi-crd233.json";
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "dotfiles-merge-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const home = join(root, "home");
  const dotfiles = join(home, "dotfiles");
  const bin = join(root, "bin");
  mkdirSync(dotfiles, { recursive: true });
  mkdirSync(bin);
  writeFileSync(join(bin, "pi"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  const script = join(dotfiles, "merge_json.mjs");
  copyFileSync(new URL("../merge_json.mjs", import.meta.url), script);
  const source = join(dotfiles, relative);
  const local = source.replace(/\.json$/, ".local.json");
  const target = join(home, ".pi/agent/extensions/pi-crd233/pi-crd233.json");
  const put = (path, value) => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
  };
  put(join(dotfiles, "config/pi/settings.json"), {});
  put(join(dotfiles, "config/pi/models.json"), {});
  return {
    source, local, target, put,
    settingsSource: join(dotfiles, "config/pi/settings.json"),
    settingsTarget: join(home, ".pi/agent/settings.json"),
    modelsSource: join(dotfiles, "config/pi/models.json"),
    modelsLocal: join(dotfiles, "config/pi/models.local.json"),
    modelsTarget: join(home, ".pi/agent/models.json"),
    read: path => JSON.parse(readFileSync(path, "utf8")),
    run: (args = [], installed = true) => {
      const result = spawnSync(process.execPath, [script, ...args], {
        env: { ...process.env, HOME: home, PATH: installed ? bin : join(root, "missing-bin") },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      return result.stdout;
    },
  };
}

const options = { skip: process.platform === "win32" };
test("rebuilds pi-crd233 from public/local layers and is idempotent", options, t => {
  const f = fixture(t);
  f.put(f.source, { network: { providers: ["exa"], proxy: { access: { dns: "allow" } } } });
  f.put(f.local, { network: { providers: ["tavily"], credentials: { tavily: "fixture-key" }, proxy: { url: "http://127.0.0.1:19198" } } });
  f.put(f.target, { retained: true, network: { providers: ["old"], proxy: { access: { github: "deny" } } } });
  const original = readFileSync(f.source, "utf8");
  f.run();
  assert.deepEqual(f.read(f.target), {
    network: { providers: ["tavily"], credentials: { tavily: "fixture-key" }, proxy: { access: { dns: "allow" }, url: "http://127.0.0.1:19198" } },
  });
  assert.equal(readFileSync(f.source, "utf8"), original);
  assert.match(f.run(), /unchanged/);
});

test("dry-run preserves symlink and source; actual merge creates a real file", options, t => {
  const f = fixture(t);
  f.put(f.source, { public: true });
  f.put(f.local, { local: true });
  mkdirSync(dirname(f.target), { recursive: true });
  symlinkSync(f.source, f.target);
  const original = readFileSync(f.source, "utf8");
  assert.match(f.run(["--dry-run"]), /would replace symlink/);
  assert.equal(lstatSync(f.target).isSymbolicLink(), true);
  assert.equal(readFileSync(f.source, "utf8"), original);
  f.run();
  assert.equal(lstatSync(f.target).isSymbolicLink(), false);
  assert.deepEqual(f.read(f.target), { public: true, local: true });
  assert.equal(readFileSync(f.source, "utf8"), original);
});

test("creates missing target without local and ignores legacy private JSON", options, t => {
  const f = fixture(t);
  f.put(f.source, { public: true });
  f.put(f.source.replace(/\.json$/, ".private.json"), { legacy: true });
  f.run();
  assert.deepEqual(f.read(f.target), { public: true });
});

test("removes obsolete proxy keys after a breaking config change", options, t => {
  const f = fixture(t);
  f.put(f.source, { network: { proxy: {
    access: { github: "allow" }, categories: { github: ["github.com"] },
  } } });
  f.put(f.local, { network: { credentials: { tavily: "fixture-key" } } });
  f.run();

  f.put(f.source, { network: { proxy: {
    url: "http://127.0.0.1:19198", hosts: ["github.com"],
  } } });
  const before = readFileSync(f.target, "utf8");
  assert.match(f.run(["--dry-run"]), /would apply/);
  assert.equal(readFileSync(f.target, "utf8"), before);
  f.run();
  assert.deepEqual(f.read(f.target), { network: {
    proxy: { url: "http://127.0.0.1:19198", hosts: ["github.com"] },
    credentials: { tavily: "fixture-key" },
  } });
});

test("removes keys deleted from local and handles removal of the local file", options, t => {
  const f = fixture(t);
  f.put(f.source, { network: { proxy: { url: "public-url" } } });
  f.put(f.local, { network: { proxy: { url: "local-url" }, credentials: { exa: "fixture-key" } } });
  f.run();
  f.put(f.local, { network: { proxy: { url: "local-url" } } });
  f.run();
  assert.deepEqual(f.read(f.target), { network: { proxy: { url: "local-url" } } });
  rmSync(f.local);
  f.run();
  assert.deepEqual(f.read(f.target), f.read(f.source));
});

test("rebuilds models without retaining removed providers", options, t => {
  const f = fixture(t);
  f.put(f.source, {});
  f.put(f.modelsSource, { providers: { current: { baseUrl: "public-url", models: ["new"] } } });
  f.put(f.modelsLocal, { providers: { current: { apiKey: "fixture-key" }, local: { models: ["local"] } } });
  f.put(f.modelsTarget, { providers: { obsolete: { models: ["old"] }, current: { legacy: true } } });
  f.run();
  assert.deepEqual(f.read(f.modelsTarget), { providers: {
    current: { baseUrl: "public-url", models: ["new"], apiKey: "fixture-key" },
    local: { models: ["local"] },
  } });
});

test("settings still preserves Pi state and recursively merges public/local overrides", options, t => {
  const f = fixture(t);
  f.put(f.source, {});
  f.put(f.settingsSource, { defaultModel: "public", compaction: { enabled: true } });
  f.put(f.settingsSource.replace(/\.json$/, ".local.json"), { defaultModel: "local" });
  f.put(f.settingsTarget, {
    deviceId: "fixture-device", packages: ["fixture-package"], lastChangelogVersion: "1.0.0",
    defaultModel: "old", compaction: { enabled: false, reserveTokens: 1000 },
  });
  f.run();
  assert.deepEqual(f.read(f.settingsTarget), {
    deviceId: "fixture-device", packages: ["fixture-package"], lastChangelogVersion: "1.0.0",
    defaultModel: "local", compaction: { enabled: true, reserveTokens: 1000 },
  });
});

test("replace mode can rebuild an invalid live JSON file", options, t => {
  const f = fixture(t);
  f.put(f.source, { public: true });
  f.put(f.target, {});
  writeFileSync(f.target, "{invalid json");
  f.run();
  assert.deepEqual(f.read(f.target), { public: true });
});

test("does not create target on dry-run or when Pi is absent", options, t => {
  const f = fixture(t);
  f.put(f.source, { public: true });
  f.run(["--dry-run"]);
  assert.equal(existsSync(f.target), false);
  assert.match(f.run([], false), /pi not installed/);
  assert.equal(existsSync(f.target), false);
});
