import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, isAbsolute, join, sep } from 'node:path';

const s = JSON.parse(readFileSync(0, 'utf8'));
const home = homedir();
const stateDir = join(home, '.gemini', 'antigravity-cli');
const cols = Number.isInteger(s.terminal_width) && s.terminal_width > 0 ? s.terminal_width : 80;
const segmenter = new Intl.Segmenter();
const segments = (text) => Array.from(segmenter.segment(text), ({ segment }) => segment);
const wide = /[\p{Script=Han}\p{Script=Hangul}\p{Script=Hiragana}\p{Script=Katakana}\p{Extended_Pictographic}\p{Regional_Indicator}\u3000-\u303f\uff01-\uff60\uffe0-\uffe6]/u;
const cell = (segment) => wide.test(segment) ? 2 : 1;
const width = (text) => segments(text).reduce((sum, segment) => sum + cell(segment), 0);
const clean = (text) => typeof text === 'string' ? text.replace(/[\p{Cc}\u2028\u2029]/gu, ' ').trim() : '';
const paint = (code, text) => `\x1b[${code}m${text}\x1b[0m`;
const dot = ' · ';

function clip(text, limit) {
  if (width(text) <= limit) return text;
  if (limit <= 0) return '';
  let clipped = '';
  let room = limit - 1;
  for (const segment of segments(text)) {
    const size = cell(segment);
    if (size > room) break;
    clipped += segment;
    room -= size;
  }
  return `${clipped}…`;
}

async function conversationTitle(id) {
  const fallback = clean(s.conversation_title);
  if (!id) return fallback;
  // agy can save the generated title without updating the statusline payload.
  try {
    const { DatabaseSync } = await import('node:sqlite');
    const db = new DatabaseSync(join(stateDir, 'conversation_summaries.db'), { readOnly: true, timeout: 0 });
    try {
      const row = db.prepare('SELECT title FROM conversation_summaries WHERE conversation_id = ?').get(id);
      return clean(row?.title) || fallback;
    } finally {
      db.close();
    }
  } catch {
    return fallback;
  }
}

const rate = (cached, prompt) => prompt > 0 ? `${(100 * cached / prompt).toFixed(1)}%` : '';
const tokenCount = (value) => Number.isSafeInteger(value) && value >= 0;

function conversationUsage(id) {
  const names = ['transcript.jsonl', 'transcript_full.jsonl'];
  const dirs = new Set();
  if (typeof s.transcript_path === 'string' && isAbsolute(s.transcript_path) && names.includes(basename(s.transcript_path))) {
    dirs.add(dirname(s.transcript_path));
  }
  if (/^[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}$/i.test(id)) {
    dirs.add(join(stateDir, 'brain', id, '.system_generated', 'logs'));
  }
  for (const dir of dirs) {
    for (const name of names) {
      let transcript;
      try {
        transcript = readFileSync(join(dir, name), 'utf8');
      } catch {
        continue;
      }
      let prompt = 0;
      let cached = 0;
      let awaitingUsage = false;
      // Both transcript variants describe the same requests; only use one.
      for (const line of transcript.trimEnd().split('\n')) {
        let step;
        try {
          step = JSON.parse(line);
        } catch {
          continue; // The last record may be incomplete while agy writes it.
        }
        // The checkpoint has no compacted context size, and agy can still report the old percentage.
        if (step?.type === 'CHECKPOINT' && step.status === 'DONE') awaitingUsage = true;
        if (step?.source !== 'MODEL' || !tokenCount(step.input_tokens) || !tokenCount(step.cache_read_tokens)) continue;
        const write = step.cache_creation_input_tokens ?? 0;
        if (!tokenCount(write)) continue;
        const tokens = step.input_tokens + step.cache_read_tokens + write;
        if (step.status === 'DONE' && tokens > 0) awaitingUsage = false;
        prompt += tokens;
        cached += step.cache_read_tokens;
      }
      if (prompt > 0 || awaitingUsage) return { lifetime: rate(cached, prompt), awaitingUsage };
    }
  }
  return { lifetime: '', awaitingUsage: false };
}

const id = clean(s.conversation_id);
const { lifetime, awaitingUsage } = conversationUsage(id);
const window = s.context_window;
const pct = awaitingUsage ? undefined : window?.used_percentage;
const used = awaitingUsage ? '~' : Number.isFinite(pct) ? `${pct.toFixed(1)}%` : '';
const context = window?.context_window_size > 0 && used
  ? `${used}/${new Intl.NumberFormat('en', { notation: 'compact' }).format(window.context_window_size)}`
  : '';
const { input_tokens: input, cache_read_input_tokens: cacheRead, cache_creation_input_tokens: cacheWrite = 0 } = window?.current_usage ?? {};
const latest = [input, cacheRead, cacheWrite].every(tokenCount) ? rate(cacheRead, input + cacheRead + cacheWrite) : '';
const cache = [latest, lifetime && `Σ${lifetime}`].filter(Boolean).join('/');
const totalUsd = s.cost?.total_usd;
const cost = Number.isFinite(totalUsd) && totalUsd > 0
  ? `${s.cost.estimated ? '~' : ''}$${totalUsd.toFixed(3)}`
  : '';
const cwd = clean(s.workspace?.current_dir || s.cwd);
const dir = cwd === home || cwd.startsWith(home + sep) ? `~${cwd.slice(home.length)}` : cwd;
const title = await conversationTitle(id);

const plain = (items) => items.map(([text]) => text).join(dot);
const colored = (items) => items.map(([text, color]) => paint(color, text)).join(paint('90', dot));
const left = [];
const right = [];
const remaining = (l = left, r = right) => cols - width(plain(l)) - width(plain(r)) - (l.length && r.length ? 2 : 0);

// Reserve the ID first, then insert usage and cost ahead of it.
const contextItem = [context, pct >= 90 ? '91' : pct >= 70 ? '33' : '90'];
if (context && remaining([contextItem]) >= 0) left.push(contextItem);
const idItem = [id, '90'];
if (id && remaining([...left, idItem]) >= 0) left.push(idItem);
function appendStat(value) {
  if (!value) return false;
  const index = left.indexOf(idItem);
  const item = [value, '90'];
  if (remaining([...left, item]) < 0) return false;
  left.splice(index < 0 ? left.length : index, 0, item);
  return true;
}
if (cache && !appendStat(`CH${cache}`) && latest) appendStat(`CH${latest}`);

const effort = clean(s.model?.effort);
let model = clean(s.model?.display_name);
const suffix = ` (${effort})`;
if (effort && model.toLowerCase().endsWith(suffix.toLowerCase())) model = model.slice(0, -suffix.length);
const modelText = clip(model, remaining() - (left.length ? 2 : 0));
if (modelText && modelText !== '…') right.push([modelText, '96']);
if (effort && remaining(left, [...right, [effort, '90']]) >= 0) right.push([effort, '90']);
appendStat(cost);

for (const text of [title, dir]) {
  const separator = left.length ? width(dot) : right.length ? 2 : 0;
  const value = clip(text, remaining() - separator);
  if (value && value !== '…') left.unshift([value, '36']);
}

const pad = right.length ? ' '.repeat(cols - width(plain(left)) - width(plain(right))) : '';
console.log(colored(left) + pad + colored(right));
