// Bakes the green texture plate (assets/textures/plate_green.webp and its
// 2.0x / 3.0x variants).
//
// The plate is the app's only texture: a radial deep-green field that lifts
// towards #165A4B in the middle, with fine grain at 5 %. It is pre-baked
// rather than rendered by a live shader because a fragment shader on web
// costs a first-frame stall on CanvasKit for a background that never moves.
//
// Run without global installs (from the repository root):
//   tmp="$(mktemp -d)" && cp app/tool/generate_texture_plates.mjs "$tmp"
//   (cd "$tmp" && npm init -y >/dev/null && npm i sharp@0.34.4 &&
//     FLUI_APP_DIR="$OLDPWD/app" node generate_texture_plates.mjs)
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const APP =
  process.env.FLUI_APP_DIR ?? path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');

// Keep in sync with FluiColors.plateCenter / plateEdge.
const CENTER = [0x16, 0x5a, 0x4b];
const EDGE = [0x0b, 0x3d, 0x34];
// Grain amplitude as a share of full scale (the brief asks for 4-6 %).
const GRAIN = 0.05;
// Grain is drawn in 2 x 2 blocks: it reads as film grain instead of noise and
// survives lossy compression at a fraction of the bytes.
const GRAIN_BLOCK = 2;
// The plate is always painted with BoxFit.cover, so a moderate base is
// enough for a field with no edges or text in it.
const BASE = { width: 640, height: 800 };
const DENSITIES = [
  { scale: 1, dir: '' },
  { scale: 2, dir: '2.0x' },
  { scale: 3, dir: '3.0x' },
];
// The highlight sits slightly above the middle, like light on a surface.
const FOCUS = { x: 0.5, y: 0.38 };
// Fixed so a regenerated plate is byte-identical.
const SEED = 0x0f1a1;

/// Deterministic PRNG (mulberry32), so regenerating produces the same bytes.
const rng = (seed) => () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = seed;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

const plate = (width, height) => {
  const data = Buffer.allocUnsafe(width * height * 3);
  const cx = width * FOCUS.x;
  const cy = height * FOCUS.y;
  const maxDistance = Math.hypot(Math.max(cx, width - cx), Math.max(cy, height - cy));
  const blocksX = Math.ceil(width / GRAIN_BLOCK);
  const random = rng(SEED);
  const grain = new Int8Array(blocksX * Math.ceil(height / GRAIN_BLOCK));
  for (let i = 0; i < grain.length; i++) {
    grain[i] = Math.round((random() * 2 - 1) * GRAIN * 255);
  }

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      // Smoothstep from the lifted centre to the deep edge.
      const t = Math.min(1, Math.hypot(x - cx, y - cy) / maxDistance);
      const eased = t * t * (3 - 2 * t);
      const noise = grain[Math.floor(y / GRAIN_BLOCK) * blocksX + Math.floor(x / GRAIN_BLOCK)];
      const offset = (y * width + x) * 3;
      for (let c = 0; c < 3; c++) {
        const value = CENTER[c] + (EDGE[c] - CENTER[c]) * eased + noise;
        data[offset + c] = Math.max(0, Math.min(255, Math.round(value)));
      }
    }
  }
  return sharp(data, { raw: { width, height, channels: 3 } });
};

for (const { scale, dir } of DENSITIES) {
  const out = path.join(APP, 'assets', 'textures', dir);
  fs.mkdirSync(out, { recursive: true });
  const file = path.join(out, 'plate_green.webp');
  await plate(BASE.width * scale, BASE.height * scale)
    .webp({ quality: 72, effort: 6 })
    .toFile(file);
  console.log(`${file}: ${(fs.statSync(file).size / 1024).toFixed(1)} kB`);
}
