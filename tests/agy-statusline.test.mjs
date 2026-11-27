import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../config/agy/statusline.mjs', import.meta.url));
const id = '12345678-1234-1234-1234-123456789abc';
const usage = { input_tokens: 2135, output_tokens: 6, cache_read_input_tokens: 12270, cache_creation_input_tokens: 0 };

function render(current_usage, terminal_width = 80, { home, ...fields } = {}) {
  const input = JSON.stringify({
    terminal_width,
    conversation_id: id,
    context_window: { context_window_size: 1048576, used_percentage: 1.86, current_usage },
    cycle_mode: 'accept-edits',
    model: { display_name: 'Gemini 4 Neon (High)', effort: 'high' },
    ...fields,
  });
  const env = home ? { ...process.env, HOME: home, USERPROFILE: home } : process.env;
  return execFileSync(process.execPath, [script], { input, encoding: 'utf8', env })
    .replace(/\x1b\[[0-9;]*m/g, '').trimEnd();
}

test('shows the latest prompt cache hit rate and counts cache writes as input', () => {
  const line = render(usage);
  assert.match(line, /CH85\.2% · [\da-f-]{36}\s+Gemini 4 Neon · high$/);
  assert.equal(line.length, 80);
  assert.match(render({ input_tokens: 25, cache_read_input_tokens: 50, cache_creation_input_tokens: 25 }), /CH50\.0%/);
  assert.match(render({ input_tokens: 100, cache_read_input_tokens: 0 }), /CH0\.0%/);
  assert.doesNotMatch(render(null), /CH/);
});

test('keeps context and the full session ID ahead of cache stats', () => {
  const essentials = `1.9%/1M · ${id}`;
  assert.equal(render(usage, essentials.length), essentials);
});

test('weights cache usage from one native log and displays fields in the requested order', (t) => {
  const home = mkdtempSync(join(tmpdir(), 'agy-statusline-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const logs = join(home, '.gemini', 'antigravity-cli', 'brain', id, '.system_generated', 'logs');
  mkdirSync(logs, { recursive: true });
  const step = (input_tokens, cache_read_tokens, extra = {}) => JSON.stringify({ source: 'MODEL', input_tokens, cache_read_tokens, ...extra });
  const full = join(logs, 'transcript_full.jsonl');
  writeFileSync(full, step(100, 0));
  const fields = { home, cwd: join(home, 'project'), conversation_title: 'Cache audit' };
  assert.match(render(usage, 150, fields), /CH85\.2%\/Σ0\.0%/);

  writeFileSync(join(logs, 'transcript.jsonl'), [step(9000, 0), step(100, 1900, { cache_creation_input_tokens: 1000 }), '{"source":'].join('\n'));
  const rendered = render(usage, 150, { ...fields, transcript_path: full, cost: { total_usd: 0.031, estimated: true } });
  assert.ok(rendered.startsWith(`~${sep}project · Cache audit · 1.9%/1M · CH85.2%/Σ15.8% · ~$0.031 · ${id}`), rendered);
  assert.match(rendered, /Gemini 4 Neon · high$/);
  assert.doesNotMatch(render(usage, 150, fields), /\$/);
});
