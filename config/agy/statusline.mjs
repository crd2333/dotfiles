import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, sep } from 'node:path';

const s = JSON.parse(readFileSync(0, 'utf8'));
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
    const path = join(homedir(), '.gemini', 'antigravity-cli', 'conversation_summaries.db');
    const db = new DatabaseSync(path, { readOnly: true, timeout: 0 });
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

const window = s.context_window;
const pct = window?.used_percentage;
const context = window?.context_window_size > 0 && Number.isFinite(pct)
  ? `${pct.toFixed(1)}%/${new Intl.NumberFormat('en', { notation: 'compact' }).format(window.context_window_size)}`
  : '';
const cwd = clean(s.workspace?.current_dir || s.cwd);
const home = homedir();
const dir = cwd === home || cwd.startsWith(home + sep) ? `~${cwd.slice(home.length)}` : cwd;
const id = clean(s.conversation_id);
const title = await conversationTitle(id);
const mode = clean(s.cycle_mode);
const modeColor = { 'accept-edits': '38;5;114', auto: '33', plan: '36' }[mode] ?? '90';

const plain = (items) => items.map(([text]) => text).join(dot);
const colored = (items) => items.map(([text, color]) => paint(color, text)).join(paint('90', dot));
const left = [];
const right = [];
const remaining = (l = left, r = right) => cols - width(plain(l)) - width(plain(r)) - (l.length && r.length ? 2 : 0);

// Reserve room for context and a complete, copyable session ID before optional fields.
for (const item of [[context, pct >= 90 ? '91' : pct >= 70 ? '33' : '90'], [id, '90']]) {
  if (item[0] && remaining([...left, item]) >= 0) left.push(item);
}

const effort = clean(s.model?.effort);
let model = clean(s.model?.display_name);
const suffix = ` (${effort})`;
if (effort && model.toLowerCase().endsWith(suffix.toLowerCase())) model = model.slice(0, -suffix.length);
const modelText = clip(model, remaining() - (left.length ? 2 : 0));
if (modelText && modelText !== '…') right.push([modelText, '96']);
if (effort && remaining(left, [...right, [effort, '90']]) >= 0) right.push([effort, '90']);

for (const text of [title, dir]) {
  const separator = left.length ? width(dot) : right.length ? 2 : 0;
  const value = clip(text, remaining() - separator);
  if (value && value !== '…') left.unshift([value, '36']);
}

if (mode && remaining(left, [[mode, modeColor], ...right]) >= 0) right.unshift([mode, modeColor]);
const pad = right.length ? ' '.repeat(cols - width(plain(left)) - width(plain(right))) : '';
console.log(colored(left) + pad + colored(right));
