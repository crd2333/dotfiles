({
  async onWillParseMarkdown(markdown) {
    const lines = markdown.split('\n');

    function fenceAt(line) {
      const match = /^ {0,3}(`{3,}|~{3,})([^\r]*)\r?$/.exec(line);
      if (!match || (match[1][0] === '`' && match[2].includes('`'))) return;
      return { marker: match[1], info: match[2].trim() };
    }

    function fenceEnd(start, limit, { marker }) {
      for (let i = start + 1; i < limit; i++) {
        const fence = fenceAt(lines[i]);
        if (fence && !fence.info && fence.marker.startsWith(marker)) return i;
      }
      return limit;
    }

    // MPE treats a leading slash as workspace-relative. Artifact reports
    // live in their run directory alongside the media referenced here.
    function resolveArtifactImage(line) {
      return line.replace(
        /^( {0,3}!\[[^\]\r\n]*\]\([ \t]*<?)(?:[a-z]:)?\/(?:[^/<>\r\n()]+\/)*\.gemini\/antigravity-cli\/brain\/[\da-f]{8}(?:-[\da-f]{4}){3}-[\da-f]{12}\//i,
        '$1./',
      );
    }

    function renderCarousel(start, end) {
      const slides = [[]];
      for (let i = start + 1; i < end; i++) {
        const slide = slides[slides.length - 1];
        const nested = fenceAt(lines[i]);
        if (nested) {
          const next = Math.min(fenceEnd(i, end, nested) + 1, end);
          slide.push(...lines.slice(i, next));
          i = next - 1;
        } else if (/^[ \t]*<!--\s*slide\s*-->[ \t]*\r?$/.test(lines[i])) {
          slides.push([]);
        } else {
          slide.push(resolveArtifactImage(lines[i]));
        }
      }
      const pages = slides.filter(slide => slide.some(line => line.trim()));
      if (!pages.length) return null;
      const eol = lines[start].endsWith('\r') ? '\r\n' : '\n';
      const html = pages.map((page, i) =>
        `<div class="agy-carousel-slide"><div class="agy-carousel-page">${i + 1} / ${pages.length}</div>${eol}${eol}` +
        page.join('\n') + `${eol}${eol}</div>`,
      ).join(eol + eol);
      return `<div class="agy-carousel" role="region" aria-label="Carousel" tabindex="0">${eol}${eol}` +
        html + `${eol}${eol}</div>`;
    }

    const output = [];
    let cursor = 0;
    for (let i = 0; i < lines.length; i++) {
      const fence = fenceAt(lines[i]);
      if (!fence) {
        lines[i] = resolveArtifactImage(lines[i]);
        continue;
      }
      const end = fenceEnd(i, lines.length, fence);
      if (end < lines.length && fence.marker.startsWith('````') && fence.info === 'carousel') {
        const carousel = renderCarousel(i, end);
        if (carousel) {
          output.push(...lines.slice(cursor, i), '', carousel, '');
          cursor = end + 1;
        }
      }
      i = end;
    }
    return output.concat(lines.slice(cursor)).join('\n');
  },
})
