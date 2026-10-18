// Vector stroke font in the spirit of the Vectrex / Asteroids character generator.
// Every glyph lives on a 4 x 6 grid (x 0..4, y 0..6, y down). A glyph is a list of
// strokes separated by '|', each stroke a list of "xy" points joined by lines.
const VecFont = (() => {
  const SRC = {
    'A': '06 02 20 42 46|03 43',
    'B': '00 06|00 30 41 42 33 03|33 44 45 36 06',
    'C': '41 30 10 01 05 16 36 45',
    'D': '00 06|00 30 42 44 36 06',
    'E': '40 00 06 46|03 23',
    'F': '40 00 06|03 23',
    'G': '41 30 10 01 05 16 36 45 43 23',
    'H': '00 06|40 46|03 43',
    'I': '10 30|20 26|16 36',
    'J': '40 44 36 16 05',
    'K': '00 06|40 03 46',
    'L': '00 06 46',
    'M': '06 00 23 40 46',
    'N': '06 00 46 40',
    'O': '10 30 41 45 36 16 05 01 10',
    'P': '06 00 30 41 42 33 03',
    'Q': '10 30 41 45 36 16 05 01 10|24 46',
    'R': '06 00 30 41 42 33 03|23 46',
    'S': '41 30 10 01 02 13 33 44 45 36 16 05',
    'T': '00 40|20 26',
    'U': '00 05 16 36 45 40',
    'V': '00 26 40',
    'W': '00 06 23 46 40',
    'X': '00 46|40 06',
    'Y': '00 23 40|23 26',
    'Z': '00 40 06 46',
    '0': '10 30 41 45 36 16 05 01 10|05 41',
    '1': '02 20 26|16 36',
    '2': '01 10 30 41 42 06 46',
    '3': '00 40 23|23 33 44 45 36 16 05',
    '4': '30 04 44|30 36',
    '5': '40 00 03 33 44 45 36 16 05',
    '6': '41 30 10 01 05 16 36 45 44 33 13 04',
    '7': '00 40 16',
    '8': '10 30 41 42 33 13 02 01 10|13 04 05 16 36 45 44 33',
    '9': '05 16 36 45 41 30 10 01 02 13 33 42',
    '!': '20 24|25 26',
    '?': '01 10 30 41 42 23 24|25 26',
    '.': '25 26',
    ',': '25 16',
    ':': '21 22|24 25',
    ';': '21 22|25 16',
    '-': '13 33',
    '+': '13 33|21 25',
    '\'': '20 21',
    '"': '10 11|30 31',
    '/': '40 06',
    '(': '30 11 15 36',
    ')': '10 31 35 16',
    '<': '40 03 46',
    '>': '00 43 06',
    '=': '02 42|04 44',
    '*': '21 25|02 44|04 42',
    '%': '00 11 02|40 06|34 45 36',
    '&': '46 02 11 20 31 22 05 16 36 44',
    '_': '06 46',
    '#': '10 16|30 36|02 42|04 44',
    ' ': ''
  };
  const glyphs = {};
  for (const k in SRC) {
    glyphs[k] = SRC[k] ? SRC[k].split('|').map(s => s.trim().split(/\s+/).map(p => [+p[0], +p[1]])) : [];
  }
  // Characters that have no glyph render as a small box.
  const BOX = [[[0, 1], [4, 1], [4, 6], [0, 6], [0, 1]]];

  function width(str, size) {
    const u = size / 6;
    return str.length * 6 * u - 2 * u;
  }

  // Draws `str` with its top-left (or top-centre / top-right) at (x, y). `size` is the glyph height.
  function draw(ctx, str, x, y, size, align = 'left', color = '#3cff5a', lw = 0) {
    const u = size / 6;
    str = String(str).toUpperCase();
    const w = width(str, size);
    if (align === 'center') x -= w / 2; else if (align === 'right') x -= w;
    ctx.save();
    ctx.strokeStyle = color;
    ctx.lineWidth = lw || Math.max(1.3, size / 9);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    for (const ch of str) {
      const g = glyphs[ch] || BOX;
      for (const stroke of g) {
        for (let i = 0; i < stroke.length; i++) {
          const px = x + stroke[i][0] * u, py = y + stroke[i][1] * u;
          if (i) ctx.lineTo(px, py); else ctx.moveTo(px, py);
        }
      }
      x += 6 * u;
    }
    ctx.stroke();
    ctx.restore();
  }

  // Word-wraps `str` to at most `maxWidth` pixels at `size`, returning lines.
  function wrap(str, size, maxWidth) {
    const words = String(str).split(/\s+/);
    const lines = [];
    let cur = '';
    for (const w of words) {
      const test = cur ? cur + ' ' + w : w;
      if (width(test, size) > maxWidth && cur) { lines.push(cur); cur = w; } else cur = test;
    }
    if (cur) lines.push(cur);
    return lines;
  }

  return { draw, width, wrap };
})();
