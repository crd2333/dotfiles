import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

const { onWillParseMarkdown: render } = runInNewContext(
  readFileSync(new URL('../config/crossnote/parser.js', import.meta.url), 'utf8'),
);

const carousel = body => `\`\`\`\`carousel\n${body}\n\`\`\`\``;
const prefix = '/' + '../'.repeat(20);
const artifact = '/home/demo/.gemini/antigravity-cli/brain/01234567-89ab-cdef-0123-456789abcdef';
const separator = '<!-- slide -->';

test('rewrites allowlisted POSIX absolute paths in body and carousels while preserving workspace paths', async () => {
  const bodyImage = `![References](${artifact}/benchmark-99-media/charades-refs.png)`;
  const absolute = `![First](${artifact}/scratch/stills/first.png)`;
  const ordinary = '![External](/assets/second.png)';
  const html = await render(`${bodyImage}\n\n${carousel(`${absolute}\n${separator}\n${ordinary}`)}\n\n${carousel('Last')}`);
  assert.ok(html.startsWith(`![References](${prefix}${artifact.slice(1)}/benchmark-99-media/charades-refs.png)`));
  assert.ok(html.includes(`![First](${prefix}${artifact.slice(1)}/scratch/stills/first.png)`));
  assert.ok(html.includes(ordinary));
  assert.equal((html.match(/class="agy-carousel"/g) || []).length, 2);
  for (const page of ['1 / 2', '2 / 2', '1 / 1']) assert.ok(html.includes(`>${page}</div>`));
});

test('rewrites file:// URLs, reference definitions, and MPE-resolved HTML tags while preserving suffixes', async () => {
  const source = [
    '[Report](file:///home/demo/report.md#L10-L20 "Title")',
    '[Mac](file://localhost/Users/demo/pic.png?v=1)',
    '[Data](/data/exp/run%201/out.json#summary)',
    '![Spaced](</tmp/my folder/shot (1).png>)',
    '[ref]: /var/log/app.log "App log"',
    '<img src="/home/demo/a.png" srcset="/tmp/a.png 1x, /assets/b.png 2x">',
    '<a href="file:///etc/hosts">hosts</a>',
    '<source srcset="/opt/a.webp 1x, /home/demo/b.webp 2x">',
    '<video src="/home/demo/clip.mp4"></video>',
  ].join('\n');
  const expected = [
    `[Report](${prefix}home/demo/report.md#L10-L20 "Title")`,
    `[Mac](${prefix}Users/demo/pic.png?v=1)`,
    `[Data](${prefix}data/exp/run%201/out.json#summary)`,
    `![Spaced](<${prefix}tmp/my folder/shot (1).png>)`,
    `[ref]: ${prefix}var/log/app.log "App log"`,
    `<img src="${prefix}home/demo/a.png" srcset="${prefix}tmp/a.png 1x, /assets/b.png 2x">`,
    `<a href="${prefix}etc/hosts">hosts</a>`,
    `<source srcset="${prefix}opt/a.webp 1x, ${prefix}home/demo/b.webp 2x">`,
    '<video src="/home/demo/clip.mp4"></video>',
  ].join('\n');
  assert.equal(await render(source), expected);
});

test('keeps slide comments and image examples literal inside nested code fences', async () => {
  const nested = `\`\`\`md\n${separator}\n![Example](${artifact}/scratch/example.png)\n\`\`\``;
  const html = await render(carousel(`${nested}\n${separator}\nNext`));
  assert.ok(html.includes(nested));
  assert.equal((html.match(/class="agy-carousel-slide"/g) || []).length, 2);
});

test('preserves workspace paths, non-POSIX URLs, single-segment roots, and inline code', async () => {
  const source = [
    '![Local](/assets/first.png)',
    '![Media](/media/shot.png)',
    '[Lib](/lib/utils.ts)',
    '[Route](/home)',
    `![Remote](https://example.test${artifact}/image.png)`,
    `![Network](//example.test${artifact}/image.png)`,
    `![Relative](..${artifact}/image.png)`,
    '[Windows](file:///C:/Users/demo/file.md)',
    'Inline `![Code](/home/demo/a.png)` and `/data/lumere-run/cases/`',
  ].join('\n');
  assert.equal(await render(source), source);
});

test('rewrites links inside 4-space nested list items while skipping indented code blocks', async () => {
  const source = [
    '- Parent',
    '    - [Nested](/home/demo/a.md)',
    '',
    '    ![Code](/home/demo/b.png)',
  ].join('\n');
  const expected = [
    '- Parent',
    `    - [Nested](${prefix}home/demo/a.md)`,
    '',
    '    ![Code](/home/demo/b.png)',
  ].join('\n');
  assert.equal(await render(source), expected);
});

test('ignores code samples, malformed carousels, and normal content', async () => {
  const imageSample = `![Example](${artifact}/scratch/example.png)`;
  const ordinary = `# Example\n\n\`\`\`\`\`md\n${carousel('Example')}\n\`\`\`\`\`\n\n~~~md\n${imageSample}\n${carousel('Another example')}\n~~~\n\n    ${imageSample}`;
  const malformed = '\`\`\`\`carousel\nMissing close';
  for (const source of [ordinary, malformed, carousel(separator), 'Normal\r\nMarkdown\r\n']) {
    assert.equal(await render(source), source);
  }
});
