// Generates the ten flui glyphs (assets/icons/*.svg) from one wave geometry.
//
// They are drawn on the same motif as the logo — the soft "fluir" wave — on a
// 24 grid with a 2 px stroke and round terminals, so they read as one family
// and never as a generic icon set. Keep GRID, STROKE and `wave()` in sync with
// FluiGlyphGeometry in lib/shared/widgets/flui_glyph.dart; a test checks every
// generated asset against those numbers.
//
// Run without global installs (from the repository root):
//   node app/tool/generate_glyphs.mjs
import fs from 'node:fs';
import path from 'node:path';

const APP =
  process.env.FLUI_APP_DIR ?? path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const GRID = 24;
const STROKE = 2;

const fmt = (n) => Number(n.toFixed(2)).toString();

/// One soft wave: a crest then a trough, the same curve as the logo.
/// Spans `2 * h` horizontally from `x`.
const wave = (x, y, h, amp) =>
  `M${fmt(x)} ${fmt(y)}` +
  `c${fmt(h / 3)} ${fmt(-amp)} ${fmt((2 * h) / 3)} ${fmt(-amp)} ${fmt(h)} 0` +
  `s${fmt((2 * h) / 3)} ${fmt(amp)} ${fmt(h)} 0`;

/// Arrow terminal, `s` wide, pointing right (`dir: 1`) or left (`dir: -1`).
const arrow = (x, y, dir, s = 2.2) =>
  `M${fmt(x - dir * s)} ${fmt(y - s)}L${fmt(x)} ${fmt(y)}L${fmt(x - dir * s)} ${fmt(y + s)}`;

/// Arrow terminal pointing down, `s` wide.
const arrowDown = (x, y, s = 2.2) =>
  `M${fmt(x - s)} ${fmt(y - s)}L${fmt(x)} ${fmt(y)}L${fmt(x + s)} ${fmt(y - s)}`;

const line = (x1, y1, x2, y2) => `M${fmt(x1)} ${fmt(y1)}L${fmt(x2)} ${fmt(y2)}`;

/// Each glyph is a list of stroked paths plus optional filled dots.
const GLYPHS = {
  // The motif itself: three stacked waves with a left-to-right phase offset.
  onda: {
    title: 'Onda',
    paths: [wave(2.5, 7, 7, 2.2), wave(3.5, 12, 7, 1.8), wave(4.5, 17, 7, 1.4)],
  },
  // A word over the stream, with a bead on the wave marking today's.
  'palabra-del-dia': {
    title: 'Palabra del día',
    paths: [line(4, 7.5, 20, 7.5), line(4, 12.5, 14, 12.5), wave(4, 18, 8, 1.8)],
  },
  // Two waves swapping direction: the word you had for the word that fits.
  reemplaza: {
    title: 'Reemplaza',
    paths: [
      wave(3, 8, 6.5, 1.8) + arrow(16, 8, 1),
      wave(8, 16, 6.5, 1.8),
      arrow(8, 16, -1),
    ],
  },
  // Momentum: the same wave, one step higher each day.
  racha: {
    title: 'Racha',
    paths: [wave(3, 18.5, 4, 1.5), wave(7, 13, 4, 1.5), wave(11, 7.5, 4, 1.5)],
    dots: [{ cx: 20.5, cy: 4.5, r: 1.8 }],
  },
  // The wave inside a conversation.
  'en-contexto': {
    title: 'En contexto',
    paths: [
      'M6 3.5h12a3.5 3.5 0 0 1 3.5 3.5v6a3.5 3.5 0 0 1-3.5 3.5h-6l-5 4v-4H6A3.5 3.5 0 0 1 2.5 13V7A3.5 3.5 0 0 1 6 3.5Z',
      wave(6.5, 10, 5.5, 1.5),
    ],
  },
  // Register: the same sentence, three amplitudes, one dial.
  'matiz-registro': {
    title: 'Matiz y registro',
    paths: [
      wave(2.5, 6.5, 6, 2.6),
      wave(2.5, 12, 6, 1.7),
      wave(2.5, 17.5, 6, 0.9),
      line(19.5, 4, 19.5, 20),
    ],
    dots: [{ cx: 19.5, cy: 12, r: 1.7 }],
  },
  // Your own voice: the capsule sits on the wave.
  microfono: {
    title: 'Micrófono',
    paths: [
      'M12 2.5a3 3 0 0 1 3 3v4.5a3 3 0 0 1-6 0V5.5a3 3 0 0 1 3-3Z',
      line(12, 13, 12, 17),
      wave(3.5, 20, 8.5, 1.7),
    ],
  },
  // Where you are heading: a pennant with a wave edge.
  meta: {
    title: 'Meta',
    paths: [
      line(5.5, 21.5, 5.5, 3.5),
      // The pennant: a wave out and the mirrored wave back.
      `${wave(5.5, 4, 6, 1.8)}V10.5c-2 1.8-4 1.8-6 0s-4-1.8-6 0Z`,
    ],
  },
  // A word that became yours.
  logro: {
    title: 'Logro',
    paths: [
      'M12 3a6.5 6.5 0 1 1 0 13 6.5 6.5 0 0 1 0-13Z',
      wave(7.5, 9.5, 4.5, 1.4),
      'M8.4 15.4 6.8 21.8 12 19.2l5.2 2.6-1.6-6.4',
    ],
  },
  // Going over the same wave again.
  repaso: {
    title: 'Repaso',
    paths: [
      wave(3.5, 19, 8, 1.8),
      // Over the same wave again: a shallow turn back to where it started.
      'M18 13A11 11 0 0 0 5 13',
      arrowDown(5, 13),
    ],
  },
};

const svg = ({ title, paths, dots = [] }) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${GRID}" height="${GRID}" viewBox="0 0 ${GRID} ${GRID}" role="img">\n` +
  `  <title>${title}</title>\n` +
  `  <g fill="none" stroke="currentColor" stroke-width="${STROKE}" stroke-linecap="round" stroke-linejoin="round">\n` +
  paths.map((d) => `    <path d="${d}"/>`).join('\n') +
  '\n' +
  dots.map((c) => `    <circle cx="${c.cx}" cy="${c.cy}" r="${c.r}" fill="currentColor" stroke="none"/>`).join('\n') +
  (dots.length ? '\n' : '') +
  '  </g>\n</svg>\n';

const out = `${APP}/assets/icons`;
fs.mkdirSync(out, { recursive: true });
for (const [name, glyph] of Object.entries(GLYPHS)) {
  fs.writeFileSync(`${out}/${name}.svg`, svg(glyph));
}
console.log(`wrote ${Object.keys(GLYPHS).length} glyphs to ${out}`);
