// ForeverBis : dessine le logo (bouclier + étoile B.I.S), style plat à contour noir.
// Usage (depuis le dossier AddOns) :  node ForeverBis/Tools/build-logo.js
// Produit Media/Logo.tga (128x128, utilisé par le jeu) et Media/Logo_source.png (512x512).
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.resolve(__dirname, "..", "Media");
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- formes (coordonnées -1..1, y vers le bas)
const TOP = -0.78, MID = 0.05, TIP = 0.86, HALF = 0.68, CORNER = 0.12;
function shieldHalf(y) {
  if (y < TOP || y > TIP) return -1;
  if (y <= MID) return HALF;
  const t = (y - MID) / (TIP - MID); // 0..1
  return HALF * Math.sqrt(1 - t * t * t); // flancs arrondis, pointe en bas
}
// distance signée approx. au bouclier (négatif = dedans)
function shieldDist(x, y) {
  const h = shieldHalf(y);
  let d = h < 0 ? 1 : Math.abs(x) - h;
  d = Math.max(d, TOP - y);
  // coins du haut arrondis
  const cx = HALF - CORNER, cy = TOP + CORNER;
  if (Math.abs(x) > cx && y < cy) d = Math.max(d, Math.hypot(Math.abs(x) - cx, y - cy) - CORNER);
  // pente de la pointe : corrige l'épaisseur du contour
  if (y > MID) {
    const e = 0.002, dh = (shieldHalf(y + e) - shieldHalf(y - e)) / (2 * e);
    if (isFinite(dh)) d = (Math.abs(x) - h) / Math.sqrt(1 + dh * dh);
    if (h < 0) d = 1;
  }
  return d;
}
function star(cx, cy, R, r) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rad = i % 2 === 0 ? R : r;
    pts.push([cx + rad * Math.cos(a), cy + rad * Math.sin(a)]);
  }
  return pts;
}
function inPoly(x, y, p) {
  let c = false;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    const [xi, yi] = p[i], [xj, yj] = p[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
  }
  return c;
}
function polyDist(x, y, p) {
  let m = Infinity;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    const [ax, ay] = p[j], [bx, by] = p[i];
    const dx = bx - ax, dy = by - ay;
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
    m = Math.min(m, Math.hypot(x - ax - t * dx, y - ay - t * dy));
  }
  return inPoly(x, y, p) ? -m : m;
}

const STAR = star(0, -0.02, 0.5, 0.21);
const STAR_HI = star(-0.03, -0.06, 0.32, 0.13);
const OUTLINE = 0.075;

// -> [r,g,b,a] 0..255 pour un point
function shade(x, y) {
  // ombre portée au sol
  const sh = Math.hypot(x / 0.62, (y - 0.93) / 0.07);
  const shadow = sh < 1 ? [0, 0, 0, 70] : null;

  const ds = shieldDist(x, y);
  const dst = polyDist(x, y, STAR);
  let col = null;
  if (ds < 0) {
    // fond du bouclier : moitié gauche plus claire (couleur ForeverBis #33ccff)
    col = x < 0 ? [70, 190, 245] : [35, 140, 215];
    // bande dorée intérieure
    if (ds > -OUTLINE - 0.07 && ds < -OUTLINE) col = [255, 205, 40];
    if (ds > -OUTLINE) col = [15, 15, 20];
  }
  if (dst < OUTLINE * 0.85 && ds < 0.0) {
    col = [15, 15, 20];
    if (dst < 0) col = inPoly(x, y, STAR_HI) ? [255, 228, 90] : [250, 190, 30];
  }
  if (col) return [...col, 255];
  return shadow || [0, 0, 0, 0];
}

function render(size, ss) {
  const px = Buffer.alloc(size * size * 4);
  for (let j = 0; j < size; j++) {
    for (let i = 0; i < size; i++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sj = 0; sj < ss; sj++) {
        for (let si = 0; si < ss; si++) {
          const x = ((i + (si + 0.5) / ss) / size) * 2 - 1;
          const y = ((j + (sj + 0.5) / ss) / size) * 2 - 1;
          const c = shade(x * 1.08, y * 1.08);
          r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
        }
      }
      const o = (j * size + i) * 4;
      if (a > 0) { px[o] = r / a; px[o + 1] = g / a; px[o + 2] = b / a; }
      px[o + 3] = a / (ss * ss);
    }
  }
  return px;
}

// ---------------------------------------------------------------- TGA 32 bits, origine en bas à gauche
function writeTga(file, size, px) {
  const h = Buffer.alloc(18);
  h[2] = 2; h.writeUInt16LE(size, 12); h.writeUInt16LE(size, 14); h[16] = 32; h[17] = 8;
  const d = Buffer.alloc(size * size * 4);
  for (let j = 0; j < size; j++) {
    for (let i = 0; i < size; i++) {
      const s = (j * size + i) * 4, t = ((size - 1 - j) * size + i) * 4;
      d[t] = px[s + 2]; d[t + 1] = px[s + 1]; d[t + 2] = px[s]; d[t + 3] = px[s + 3];
    }
  }
  fs.writeFileSync(file, Buffer.concat([h, d]));
}

// ---------------------------------------------------------------- PNG
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
function crc32(buf) { let c = -1; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePng(file, size, px) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let j = 0; j < size; j++) px.copy(raw, j * (size * 4 + 1) + 1, j * size * 4, (j + 1) * size * 4);
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0)),
  ]));
}

writeTga(path.join(OUT, "Logo.tga"), 128, render(128, 4));
writePng(path.join(OUT, "Logo_source.png"), 512, render(512, 3));
console.log("Media/Logo.tga et Media/Logo_source.png écrits");
