import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

const { onWillParseMarkdown: render } = runInNewContext(
  readFileSync(new URL('../config/crossnote/parser.js', import.meta.url), 'utf8'),
);

const carousel = body => `\`\`\`\`carousel\n${body}\n\`\`\`\``;
const artifact = '/home/demo/.gemini/antigravity-cli/brain/01234567-89ab-cdef-0123-456789abcdef';
const separator = '<!-- slide -->';

test('splits independent carousels and rewrites only their agy scratch images', async () => {
  const absolute = `![First](${artifact}/scratch/stills/first.png)`;
  const ordinary = '![External](/assets/second.png)';
  const html = await render(`${absolute}\n\n${carousel(`${absolute}\n${separator}\n${ordinary}`)}\n\n${carousel('Last')}`);
  assert.ok(html.startsWith(absolute));
  assert.ok(html.includes('![First](./scratch/stills/first.png)'));
  assert.ok(html.includes(ordinary));
  assert.equal((html.match(/class="agy-carousel"/g) || []).length, 2);
  for (const page of ['1 / 2', '2 / 2', '1 / 1']) assert.ok(html.includes(`>${page}</div>`));
});

test('keeps slide comments and image examples literal inside nested code fences', async () => {
  const nested = `\`\`\`md\n${separator}\n![Example](${artifact}/scratch/example.png)\n\`\`\``;
  const html = await render(carousel(`${nested}\n${separator}\nNext`));
  assert.ok(html.includes(nested));
  assert.equal((html.match(/class="agy-carousel-slide"/g) || []).length, 2);
});

test('ignores code samples, malformed carousels, and normal content', async () => {
  const ordinary = `# Example\n\n\`\`\`\`\`md\n${carousel('Example')}\n\`\`\`\`\`\n\n~~~md\n${carousel('Another example')}\n~~~`;
  const malformed = '\`\`\`\`carousel\nMissing close';
  for (const source of [ordinary, malformed, carousel(separator), 'Normal\r\nMarkdown\r\n']) {
    assert.equal(await render(source), source);
  }
});
