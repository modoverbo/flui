// Generates the flui brand SVGs, web icons and launcher icon sources from one
// wave geometry (keep WAVES and STROKE in sync with FluiSymbolGeometry in
// lib/shared/widgets/flui_symbol.dart; a test checks the SVG assets).
//
// Run without global installs (from the repository root):
//   tmp="$(mktemp -d)" && cp app/tool/generate_brand_assets.mjs "$tmp"
//   (cd "$tmp" && npm init -y >/dev/null && npm i @resvg/resvg-js@2.6.2 &&
//     FLUI_APP_DIR="$OLDPWD/app" node generate_brand_assets.mjs)
// Then, in app/: dart run flutter_launcher_icons
import { Resvg } from '@resvg/resvg-js';
import fs from 'node:fs';
import path from 'node:path';

const APP =
  process.env.FLUI_APP_DIR ?? path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const GREEN = '#0B3D34';
const YELLOW = '#FFD60A';
const STROKE = 5;
const WAVES = [
  { y: 14, x0: 6, h: 16, amp: 4.4 },
  { y: 24.5, x0: 8, h: 16, amp: 3.6 },
  { y: 35, x0: 10, h: 16, amp: 2.8 },
];
const fmt = (n) => Number(n.toFixed(2)).toString();
const d = ({ y, x0, h, amp }) =>
  `M${fmt(x0)} ${fmt(y)}c${fmt(h / 3)} ${fmt(-amp)} ${fmt((2 * h) / 3)} ${fmt(-amp)} ${fmt(h)} 0s${fmt((2 * h) / 3)} ${fmt(amp)} ${fmt(h)} 0`;
const group = (color) =>
  `<g fill="none" stroke="${color}" stroke-width="${STROKE}" stroke-linecap="round" stroke-linejoin="round">\n` +
  WAVES.map((w) => `    <path d="${d(w)}"/>`).join('\n') + '\n  </g>';

const header = `<!-- flui symbol. Derived from Tabler Icons "ripple" (MIT, Copyright (c) 2020-2026 Pawel Kuna): see LICENSE-tabler-icons.txt -->`;
const symbolSvg = (color) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">\n  ${header}\n  ${group(color)}\n</svg>\n`;

// Icon on a deep green tile. scale = symbol size relative to the tile, radius in tile units (48).
const iconSvg = ({ scale, radius }) => {
  const offset = (48 - 48 * scale) / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">\n  ${header}\n  <rect width="48" height="48" rx="${radius}" fill="${GREEN}"/>\n  <g transform="translate(${fmt(offset)} ${fmt(offset)}) scale(${scale})">\n  ${group(YELLOW)}\n  </g>\n</svg>\n`;
};
const transparentSvg = ({ scale }) => {
  const offset = (48 - 48 * scale) / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g transform="translate(${fmt(offset)} ${fmt(offset)}) scale(${scale})">${group(YELLOW)}</g></svg>`;
};
const png = (svg, size, out) => {
  const data = new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render().asPng();
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, data);
};

fs.mkdirSync(`${APP}/assets/brand`, { recursive: true });
fs.writeFileSync(`${APP}/assets/brand/flui_symbol.svg`, symbolSvg(YELLOW));
fs.writeFileSync(`${APP}/assets/brand/flui_symbol_green.svg`, symbolSvg(GREEN));

const rounded = iconSvg({ scale: 0.7, radius: 11 });
const fullBleed = iconSvg({ scale: 0.72, radius: 0 });
const maskable = iconSvg({ scale: 0.56, radius: 0 });
fs.writeFileSync(`${APP}/web/favicon.svg`, rounded);
png(rounded, 32, `${APP}/web/favicon.png`);
png(rounded, 192, `${APP}/web/icons/Icon-192.png`);
png(rounded, 512, `${APP}/web/icons/Icon-512.png`);
png(maskable, 192, `${APP}/web/icons/Icon-maskable-192.png`);
png(maskable, 512, `${APP}/web/icons/Icon-maskable-512.png`);
png(fullBleed, 180, `${APP}/web/icons/apple-touch-icon.png`);
// Launcher icon sources (not bundled): iOS needs an opaque full-bleed square.
png(fullBleed, 1024, `${APP}/assets/brand/launcher/flui_launcher_icon.png`);
png(transparentSvg({ scale: 0.72 }), 1024, `${APP}/assets/brand/launcher/flui_launcher_foreground.png`);
console.log(WAVES.map(d).join('\n'));
