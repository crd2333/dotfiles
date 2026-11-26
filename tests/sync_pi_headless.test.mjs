import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "dotfiles-pi-headless-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const home = join(root, "home");
  const dotfiles = join(home, "dotfiles");
  mkdirSync(dotfiles, { recursive: true });
  const script = join(dotfiles, "sync_pi_headless.mjs");
  copyFileSync(new URL("../sync_pi_headless.mjs", import.meta.url), script);
  const put = (path, value) => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, typeof value === "string" ? value : JSON.stringify(value, null, 2) + "\n");
  };
  return {
    home,
    dotfiles,
    srcDir: join(home, ".pi/agent"),
    dstDir: join(home, ".pi/agent-headless"),
    overlay: join(dotfiles, "config/pi/settings-headless.json"),
    localOverlay: join(dotfiles, "config/pi/settings-headless.local.json"),
    put,
    read: path => JSON.parse(readFileSync(path, "utf8")),
    run: (args = []) => {
      const result = spawnSync(process.execPath, [script, ...args], {
        env: { ...process.env, HOME: home, PATH: join(root, "missing-bin") },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      return result.stdout;
    },
  };
}

const options = { skip: process.platform === "win32" };

test("syncs headless symlinks, filters packages, preserves host settings, and excludes interactive extensions", options, t => {
  const f = fixture(t);
  f.put(join(f.srcDir, "auth.json"), { token: "fixture" });
  f.put(join(f.srcDir, "models.json"), { providers: {} });
  f.put(join(f.srcDir, "extensions/herdr-agent-state.ts"), "export default () => {};\n");
  f.put(join(f.srcDir, "extensions/pi-permission-system/config.json"), { mode: "ask" });
  f.put(join(f.srcDir, "extensions/pi-client-fingerprint/config.json"), { enabled: true });
  f.put(join(f.srcDir, "extensions/pi-crd233/pi-crd233.json"), { network: {} });
  f.put(join(f.srcDir, "settings.json"), {
    defaultProvider: "aio",
    defaultModel: "gpt-6.2-sol",
    httpProxy: "http://127.0.0.1:19198",
    packages: ["git:github.com/crd2333/pi-agy-acp", "npm:@gotgenes/pi-permission-system"],
    extensionChangelogVersions: { foo: "1.0.0" },
  });
  f.put(f.overlay, {
    packages: ["git:github.com/crd2333/pi-client-fingerprint"],
    cacheWarming: "off",
  });
  f.put(f.localOverlay, { defaultThinkingLevel: "medium" });

  assert.match(f.run(["--dry-run"]), /would apply/);
  assert.equal(existsSync(f.dstDir), false);

  f.run();

  assert.equal(lstatSync(join(f.dstDir, "auth.json")).isSymbolicLink(), true);
  assert.equal(resolve(readlinkSync(join(f.dstDir, "auth.json"))), resolve(join(f.srcDir, "auth.json")));
  assert.equal(lstatSync(join(f.dstDir, "extensions")).isSymbolicLink(), false);
  assert.equal(lstatSync(join(f.dstDir, "extensions/pi-client-fingerprint")).isSymbolicLink(), true);
  assert.equal(lstatSync(join(f.dstDir, "extensions/pi-crd233")).isSymbolicLink(), true);
  assert.equal(existsSync(join(f.dstDir, "extensions/herdr-agent-state.ts")), false);
  assert.equal(existsSync(join(f.dstDir, "extensions/pi-permission-system")), false);

  assert.deepEqual(f.read(join(f.dstDir, "settings.json")), {
    defaultProvider: "aio",
    defaultModel: "gpt-6.2-sol",
    httpProxy: "http://127.0.0.1:19198",
    packages: ["git:github.com/crd2333/pi-client-fingerprint"],
    cacheWarming: "off",
    defaultThinkingLevel: "medium",
  });

  assert.match(f.run(), /unchanged/);
});

test("skips cleanly when Pi is absent", options, t => {
  const f = fixture(t);
  f.put(f.overlay, { packages: [] });
  assert.match(f.run(), /skipped/);
  assert.equal(existsSync(f.dstDir), false);
});
