({
  async onWillParseMarkdown(markdown) {
    // Other leading-slash destinations retain MPE's workspace-relative meaning.
    const posixRoots = new Set([
      'home', 'tmp', 'var', 'opt', 'mnt', 'data', 'root', 'etc', 'usr', 'srv',
      'Users', 'Volumes', 'Applications', 'Library', 'System', 'private',
    ]);
    // MPE resolves leading slashes from the project root via path.resolve.
    const absolutePrefix = '/' + '../'.repeat(20);
    const lines = markdown.split('\n');

    function rewritePath(value) {
      const fileUrl = /^file:\/\/(?:localhost)?(?=\/)/i.exec(value);
      if (fileUrl) {
        const path = value.slice(fileUrl[0].length);
        if (/^\/(?:\/|[a-z]:)/i.test(path)) return value; // Network paths and Windows drives.
        return absolutePrefix + path.slice(1);
      }
      const root = /^\/([^/?#]+)\//.exec(value)?.[1];
      return posixRoots.has(root) ? absolutePrefix + value.slice(1) : value;
    }

    function rewriteDestination(value) {
      return value.startsWith('<') ? '<' + rewritePath(value.slice(1, -1)) + '>' : rewritePath(value);
    }

    function rewriteSrcset(value) {
      return value.replace(/(^|,\s*)(\S+)/g, (_, sep, url) => sep + rewritePath(url));
    }

    function rewriteTag(tag, name) {
      const tagName = name.toLowerCase();
      if (tagName !== 'img' && tagName !== 'a' && tagName !== 'source') return tag;
      const attributes = /(\s+)([^\s"'<>/=]+)(?:(\s*=\s*)(?:"([^"]*)"|'([^']*)'|[^\s"'=<>`]+))?/g;
      return tag.replace(attributes, (attr, space, key, equals, doubleQuoted, singleQuoted) => {
        const value = doubleQuoted ?? singleQuoted;
        if (value === undefined) return attr;
        const attrName = key.toLowerCase();
        let rewritten;
        if (tagName === 'img' && attrName === 'src') rewritten = rewritePath(value);
        else if (tagName === 'a' && attrName === 'href') rewritten = rewritePath(value);
        else if ((tagName === 'img' || tagName === 'source') && attrName === 'srcset') rewritten = rewriteSrcset(value);
        else return attr;
        const quote = doubleQuoted === undefined ? "'" : '"';
        return space + key + equals + quote + rewritten + quote;
      });
    }

    // Match the destination separately so the original spacing and title survive.
    const destination = String.raw`(<(?:\\[^\r\n]|[^\\<>\r\n])*>|(?:\\[^\s]|[^\\\s()<>]|\((?:\\[^\s]|[^\\\s()<>])*\))+)`;
    const title = String.raw`(?:"(?:\\[^\r\n]|[^"\\\r\n])*"|'(?:\\[^\r\n]|[^'\\\r\n])*'|\((?:\\[^\r\n]|[^()\\\r\n])*\))`;
    const inlineLink = new RegExp(String.raw`(\([ \t]*)${destination}(?:[ \t]+${title})?[ \t]*\)`, 'y');
    const reference = new RegExp(String.raw`(\[(?:\\[^\r\n]|[^\\\]\r\n])+\]:[ \t]*)${destination}(?:[ \t]+${title})?[ \t]*\r?$`, 'my');
    const htmlTag = /<\/?([a-z][\w:-]*)(?=[\s/>])(?:[^"'<>]|"[^"]*"|'[^']*')*>/iy;

    function rewriteProse(source) {
      // Consume whole code spans and HTML tags before looking for links inside them.
      const tokens = /^ {4}(?![ \t]*(?:[-+*]|\d{1,9}[.)])[ \t])[^\n]*|\n[ \t\r]*\n|\\[\x21-\x2f\x3a-\x40\x5b-\x60\x7b-\x7e]|`+|<!--|<|\[|\]/gm;
      const codeEnd = /`+|\n[ \t\r]*\n/g;
      let openLabels = 0;
      let output = '';
      let cursor = 0;
      for (let token; (token = tokens.exec(source));) {
        const [marker] = token;
        const { index } = token;
        let match;
        let start = index;
        if (marker === '[') {
          const indent = source.slice(source.lastIndexOf('\n', index - 1) + 1, index);
          reference.lastIndex = index;
          if (/^[ \t]{0,3}$/.test(indent)) match = reference.exec(source);
          if (!match) openLabels++;
        } else if (marker === ']') {
          if (!openLabels) continue;
          openLabels--;
          start = index + 1;
          inlineLink.lastIndex = start;
          match = inlineLink.exec(source);
        } else if (marker[0] === '`') {
          codeEnd.lastIndex = tokens.lastIndex;
          for (let end; (end = codeEnd.exec(source)) && end[0][0] === '`';) {
            if (end[0].length === marker.length) {
              tokens.lastIndex = codeEnd.lastIndex;
              break;
            }
          }
        } else if (marker === '<!--') {
          const end = source.indexOf('-->', tokens.lastIndex);
          tokens.lastIndex = end < 0 ? source.length : end + 3;
        } else if (marker === '<') {
          htmlTag.lastIndex = index;
          const tag = htmlTag.exec(source);
          if (!tag) continue;
          output += source.slice(cursor, index) + rewriteTag(tag[0], tag[1]);
          cursor = tokens.lastIndex = htmlTag.lastIndex;
        } else if (marker[0] !== '\\') {
          openLabels = 0;
        }
        if (match) {
          const [whole, prefix, path] = match;
          output += source.slice(cursor, start) + prefix + rewriteDestination(path) + whole.slice(prefix.length + path.length);
          cursor = tokens.lastIndex = start + whole.length;
        }
      }
      return output + source.slice(cursor);
    }

    const quotePrefix = /^ {0,3}>[ \t]?/;
    const listPrefix = /^ {0,3}(?:[-+*]|\d{1,9}[.)]) {1,4}(?! )/;
    const fencePattern = /^ {0,3}(`{3,}|~{3,})([^\r]*)\r?$/;

    function fenceAt(line) {
      const containers = [];
      for (;;) {
        const quote = quotePrefix.exec(line);
        const prefix = quote ?? listPrefix.exec(line);
        if (!prefix) break;
        // A block quote repeats its marker; a list item uses indentation.
        containers.push(quote ? null : ' '.repeat(prefix[0].length));
        line = line.slice(prefix[0].length);
      }
      const match = fencePattern.exec(line);
      if (!match || (match[1][0] === '`' && match[2].includes('`'))) return;
      return { marker: match[1], info: match[2].trim(), containers };
    }

    function fenceEnd(start, limit, { marker, containers }) {
      for (let i = start + 1; i < limit; i++) {
        let line = lines[i];
        for (const indent of containers) {
          if (indent === null) {
            const quote = quotePrefix.exec(line);
            if (!quote) return { next: i };
            line = line.slice(quote[0].length);
          } else {
            if (!line.startsWith(indent) && line.trim()) return { next: i };
            line = line.slice(indent.length);
          }
        }
        const close = fencePattern.exec(line);
        if (close && !close[2].trim() && close[1].startsWith(marker)) return { next: i + 1, end: i };
      }
      return { next: limit };
    }

    function appendProse(output, start, end) {
      if (start < end) output.push(rewriteProse(lines.slice(start, end).join('\n')));
    }

    function renderCarousel(start, end) {
      const slides = [[]];
      let slide = slides[0];
      let cursor = start + 1;
      for (let i = cursor; i < end; i++) {
        const nested = fenceAt(lines[i]);
        if (nested) {
          appendProse(slide, cursor, i);
          const { next } = fenceEnd(i, end, nested);
          slide.push(lines.slice(i, next).join('\n'));
          cursor = next;
          i = next - 1;
        } else if (/^[ \t]*<!--\s*slide\s*-->[ \t]*\r?$/.test(lines[i])) {
          appendProse(slide, cursor, i);
          slide = [];
          slides.push(slide);
          cursor = i + 1;
        }
      }
      appendProse(slide, cursor, end);
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
      if (!fence) continue;
      appendProse(output, cursor, i);
      const { next, end } = fenceEnd(i, lines.length, fence);
      const carousel = end !== undefined && !fence.containers.length &&
        fence.marker.startsWith('````') && fence.info === 'carousel' && renderCarousel(i, end);
      if (carousel) output.push('', carousel, '');
      else output.push(lines.slice(i, next).join('\n'));
      cursor = next;
      i = next - 1;
    }
    appendProse(output, cursor, lines.length);
    return output.join('\n');
  },
})
