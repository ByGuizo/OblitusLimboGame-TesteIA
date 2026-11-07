// =====================================================================
//  Texturas procedurais — todas geradas em canvas, nenhuma imagem externa
// =====================================================================
import * as THREE from 'three';

// ---------- ruído ----------
function hash(x, y, s) {
  let h = x * 374761393 + y * 668265263 + s * 982451653;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
}
function vnoise(x, y, s = 0, period = 0) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const w = (a) => period ? ((a % period) + period) % period : a;
  const a = hash(w(xi), w(yi), s), b = hash(w(xi + 1), w(yi), s);
  const c = hash(w(xi), w(yi + 1), s), d = hash(w(xi + 1), w(yi + 1), s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export function fbm(x, y, oct = 4, s = 0, period = 0) {
  let sum = 0, amp = 0.5, f = 1, norm = 0;
  for (let i = 0; i < oct; i++) {
    sum += vnoise(x * f, y * f, s + i * 17, period ? period * f : 0) * amp;
    norm += amp; amp *= 0.5; f *= 2;
  }
  return sum / norm;
}
let seed = 1;
const rand = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };

function makeCanvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function toTex(c, { repeat = [1, 1], srgb = true, wrap = true } = {}) {
  const t = new THREE.CanvasTexture(c);
  if (wrap) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.repeat.set(repeat[0], repeat[1]);
  t.anisotropy = 8;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  t.needsUpdate = true;
  return t;
}
// percorre os pixels; fn(x,y) => [r,g,b] ou [r,g,b,a]
function pixels(w, h, fn) {
  const c = makeCanvas(w, h), g = c.getContext('2d');
  const img = g.createImageData(w, h), d = img.data;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = fn(x, y), i = (y * w + x) * 4;
    d[i] = p[0]; d[i + 1] = p[1]; d[i + 2] = p[2]; d[i + 3] = p.length > 3 ? p[3] : 255;
  }
  g.putImageData(img, 0, 0);
  return c;
}
const clamp = (v, a = 0, b = 255) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => a + (b - a) * t;

const cache = {};
export const T = {
  get(name) {
    if (cache[name]) return cache[name];
    const b = builders[name];
    if (!b) throw new Error('textura desconhecida ' + name);
    seed = 1 + name.length * 977;
    const out = b();
    if (out && out.color) { cache[name] = out.color; cache[name + 'Bump'] = out.bump; if (out.emit) cache[name + 'Emit'] = out.emit; return cache[name]; }
    cache[name] = out; return out;
  },
  pair(name) { this.get(name); return { map: cache[name], bump: cache[name + 'Bump'], emit: cache[name + 'Emit'] }; },
};

const builders = {
  // ---------- piso de tábuas de madeira ----------
  wood() {
    const W = 512, H = 512, planks = 8, ph = H / planks;
    const offs = Array.from({ length: planks }, () => rand() * W);
    const tones = Array.from({ length: planks }, () => 0.75 + rand() * 0.4);
    const bumpC = makeCanvas(W, H), bg = bumpC.getContext('2d'), bimg = bg.createImageData(W, H);
    const color = pixels(W, H, (x, y) => {
      const p = Math.floor(y / ph), ly = y - p * ph;
      const xx = (x + offs[p]) % W;
      const seam = (xx % 256) < 2 || ly < 2 ? 1 : 0;
      const grain = fbm(xx * 0.01, y * 0.25, 4, p) * 0.6 + Math.sin(xx * 0.04 + fbm(xx * 0.02, y * 0.1, 3, p + 9) * 9) * 0.15;
      const knot = Math.max(0, 1 - Math.hypot(((xx + p * 97) % 180) - 90, (ly - ph / 2) * 2) / 26);
      let v = (0.45 + grain * 0.55) * tones[p] - knot * 0.35;
      const wear = fbm(x * 0.02, y * 0.02, 3, 77) * 0.25;
      v = v * (0.85 + wear);
      const i = (y * W + x) * 4, bv = seam ? 20 : clamp(140 + grain * 90 - knot * 60);
      bimg.data[i] = bimg.data[i + 1] = bimg.data[i + 2] = bv; bimg.data[i + 3] = 255;
      if (seam) return [18, 11, 6];
      return [clamp(118 * v), clamp(74 * v), clamp(42 * v)];
    });
    bg.putImageData(bimg, 0, 0);
    return { color: toTex(color), bump: toTex(bumpC, { srgb: false }) };
  },

  // ---------- calçamento de pedra (voronoi) ----------
  cobble() {
    const W = 512, G = 8, CS = W / G, pts = [];
    for (let j = 0; j < G; j++) for (let i = 0; i < G; i++)
      pts.push([(i + 0.15 + rand() * 0.7) * CS, (j + 0.15 + rand() * 0.7) * CS, 0.7 + rand() * 0.5, rand()]);
    const bumpC = makeCanvas(W, W), bg = bumpC.getContext('2d'), bimg = bg.createImageData(W, W);
    const color = pixels(W, W, (x, y) => {
      let d1 = 1e9, d2 = 1e9, id = 0;
      const cx = Math.floor(x / CS), cy = Math.floor(y / CS);
      for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) {
        const gx = cx + ox, gy = cy + oy;
        const wx = (gx + G) % G, wy = (gy + G) % G, i = wy * G + wx;
        const px = pts[i][0] + (gx - wx) * CS, py = pts[i][1] + (gy - wy) * CS;
        const dx = x - px, dy = y - py, d = dx * dx + dy * dy;
        if (d < d1) { d2 = d1; d1 = d; id = i; } else if (d < d2) d2 = d;
      }
      const edge = Math.sqrt(d2) - Math.sqrt(d1);
      const n = fbm(x * 0.03, y * 0.03, 4, 3);
      const t = pts[id][2], hue = pts[id][3];
      const gap = edge < 5 ? 1 - edge / 5 : 0;
      const i = (y * W + x) * 4, bv = clamp(200 * Math.min(1, edge / 14) + n * 50 - 20);
      bimg.data[i] = bimg.data[i + 1] = bimg.data[i + 2] = bv; bimg.data[i + 3] = 255;
      let r = (78 + n * 60) * t, g = (80 + n * 58) * t, b = (88 + n * 55) * t;
      if (hue > 0.7) { r *= 1.15; g *= 1.05; }
      r = mix(r, 22, gap); g = mix(g, 24, gap); b = mix(b, 22, gap);
      return [clamp(r), clamp(g), clamp(b)];
    });
    bg.putImageData(bimg, 0, 0);
    return { color: toTex(color), bump: toTex(bumpC, { srgb: false }) };
  },

  // ---------- tijolos de pedra ----------
  brick() {
    const W = 512, rows = 8, rh = W / rows, bw = 128;
    const bumpC = makeCanvas(W, W), bg = bumpC.getContext('2d'), bimg = bg.createImageData(W, W);
    const color = pixels(W, W, (x, y) => {
      const r = Math.floor(y / rh), off = (r % 2) * bw / 2;
      const bx = Math.floor((x + off) / bw), lx = (x + off) % bw, ly = y % rh;
      const mortar = lx < 4 || ly < 4;
      const tone = 0.7 + hash(bx, r, 5) * 0.45;
      const n = fbm(x * 0.05, y * 0.05, 4, 8);
      const i = (y * W + x) * 4, bv = mortar ? 30 : clamp(170 + n * 80);
      bimg.data[i] = bimg.data[i + 1] = bimg.data[i + 2] = bv; bimg.data[i + 3] = 255;
      if (mortar) return [40 + n * 20, 36 + n * 18, 32 + n * 16];
      return [clamp((70 + n * 70) * tone), clamp((64 + n * 62) * tone), clamp((60 + n * 56) * tone)];
    });
    bg.putImageData(bimg, 0, 0);
    return { color: toTex(color), bump: toTex(bumpC, { srgb: false }) };
  },

  // ---------- reboco com vigas (casas enxaimel de Vardun) ----------
  timber() {
    const W = 256, H = 256;
    return toTex(pixels(W, H, (x, y) => {
      const n = fbm(x * 0.04, y * 0.04, 4, 11);
      const beamV = x < 18 || x > W - 18, beamH = y < 16 || (y > H / 2 - 8 && y < H / 2 + 8) || y > H - 16;
      const diag = Math.abs((x - y)) < 9 && y < H / 2, diag2 = Math.abs((W - x) - (y - H / 2)) < 9 && y > H / 2;
      if (beamV || beamH || diag || diag2) {
        const g = fbm(x * 0.02, y * 0.3, 3, 4);
        return [clamp(52 + g * 40), clamp(34 + g * 26), clamp(22 + g * 16)];
      }
      const stain = fbm(x * 0.015, y * 0.015, 3, 5);
      return [clamp(168 + n * 50 - stain * 60), clamp(156 + n * 46 - stain * 60), clamp(132 + n * 40 - stain * 55)];
    }));
  },

  // ---------- telhas ----------
  roof() {
    const W = 256;
    return toTex(pixels(W, W, (x, y) => {
      const row = Math.floor(y / 21), off = (row % 2) * 16;
      const lx = (x + off) % 32, ly = y % 21;
      const n = fbm(x * 0.06, y * 0.06, 3, 21);
      const shade = 1 - ly / 30 - (lx < 2 ? 0.4 : 0);
      const t = 0.75 + hash(Math.floor((x + off) / 32), row, 3) * 0.35;
      return [clamp((70 + n * 40) * shade * t), clamp((48 + n * 30) * shade * t), clamp((46 + n * 26) * shade * t)];
    }));
  },

  // ---------- chão de terra e grama ----------
  ground() {
    const W = 512;
    return toTex(pixels(W, W, (x, y) => {
      const n = fbm(x * 0.012, y * 0.012, 5, 31, 6), m = fbm(x * 0.08, y * 0.08, 3, 32, 41);
      const grass = clamp((n - 0.42) * 4, 0, 1);
      const r = mix(58, 34, grass) + m * 25, g = mix(44, 52, grass) + m * 28, b = mix(32, 30, grass) + m * 12;
      return [clamp(r), clamp(g), clamp(b)];
    }));
  },

  // ---------- mármore negro polido (castelo de Hikari) ----------
  marble() {
    const W = 512;
    const color = pixels(W, W, (x, y) => {
      const tile = (x % 256 < 2 || y % 256 < 2);
      const n = fbm(x * 0.008, y * 0.008, 5, 51, 4);
      const vein = Math.pow(1 - Math.abs(Math.sin((x * 0.01 + y * 0.006 + n * 6) * 3.1)), 18);
      const v2 = Math.pow(1 - Math.abs(Math.sin((x * 0.004 - y * 0.011 + n * 4) * 5)), 30);
      const base = 18 + n * 18;
      if (tile) return [8, 8, 10];
      return [clamp(base + vein * 120 + v2 * 60), clamp(base + vein * 120 + v2 * 62), clamp(base + 4 + vein * 130 + v2 * 70)];
    });
    return toTex(color);
  },

  // ---------- rocha com rachaduras de lava ----------
  lava() {
    const W = 512;
    const emitC = makeCanvas(W, W), eg = emitC.getContext('2d'), eimg = eg.createImageData(W, W);
    const color = pixels(W, W, (x, y) => {
      const n = fbm(x * 0.02, y * 0.02, 5, 61, 10);
      const crack = Math.abs(fbm(x * 0.012, y * 0.012, 4, 62, 6) - 0.5);
      const glow = clamp(1 - crack * 22, 0, 1);
      const i = (y * W + x) * 4;
      eimg.data[i] = clamp(255 * glow); eimg.data[i + 1] = clamp(120 * glow * glow); eimg.data[i + 2] = clamp(20 * glow); eimg.data[i + 3] = 255;
      const r = 40 + n * 50, g = 30 + n * 32, b = 26 + n * 26;
      return [clamp(mix(r, 255, glow)), clamp(mix(g, 110, glow)), clamp(mix(b, 20, glow))];
    });
    eg.putImageData(eimg, 0, 0);
    return { color: toTex(color), bump: null, emit: toTex(emitC) };
  },

  // ---------- pele tatuada de Darius ----------
  tattoo() {
    const W = 256, c = pixels(W, W, (x, y) => {
      const n = fbm(x * 0.05, y * 0.05, 3, 71);
      return [clamp(86 + n * 30), clamp(104 + n * 30), clamp(62 + n * 20)];
    });
    const g = c.getContext('2d');
    g.lineCap = 'round';
    for (let i = 0; i < 40; i++) {
      const fresh = rand() < 0.3;
      g.strokeStyle = fresh ? 'rgba(150,20,20,0.85)' : 'rgba(20,24,18,0.8)';
      g.lineWidth = 1.5 + rand() * 3;
      g.beginPath();
      let px = rand() * W, py = rand() * W; g.moveTo(px, py);
      for (let k = 0; k < 5; k++) { px += (rand() - 0.5) * 60; py += (rand() - 0.3) * 40; g.quadraticCurveTo(px + 20, py - 20, px, py); }
      g.stroke();
    }
    return toTex(c);
  },

  // ---------- escamas draconato (Krauser) ----------
  scales() {
    const W = 256;
    return toTex(pixels(W, W, (x, y) => {
      const row = Math.floor(y / 14), off = (row % 2) * 9;
      const lx = ((x + off) % 18) - 9, ly = (y % 14);
      const d = Math.hypot(lx, (ly - 2) * 1.1) / 11;
      const rim = clamp((d - 0.75) * 6, 0, 1);
      const n = fbm(x * 0.05, y * 0.05, 3, 81);
      const sheen = (1 - d) * 40;
      return [clamp(20 + n * 18 + sheen * 0.6 - rim * 15), clamp(26 + n * 22 + sheen * 0.9 - rim * 15), clamp(30 + n * 26 + sheen - rim * 10)];
    }));
  },

  // ---------- tecido (capa) com barra rasgada ----------
  cloak() {
    const W = 128, H = 256;
    const cut = Array.from({ length: 17 }, () => 0.78 + rand() * 0.2);
    return toTex(pixels(W, H, (x, y) => {
      const n = fbm(x * 0.08, y * 0.05, 3, 91);
      const k = x / W * 16, i = Math.floor(k), f = k - i;
      const lim = mix(cut[i], cut[i + 1], f) * H;
      const a = y < lim - fbm(x * 0.3, 0, 2, 92) * 20 ? 255 : 0;
      const folds = Math.sin(x * 0.25 + n * 3) * 0.15 + 0.85;
      const v = (26 + n * 22) * folds;
      return [clamp(v), clamp(v * 0.95), clamp(v * 1.05), a];
    }), { wrap: false });
  },

  // ---------- círculo rúnico ----------
  runes() {
    const W = 512, c = makeCanvas(W, W), g = c.getContext('2d');
    g.translate(W / 2, W / 2);
    g.strokeStyle = '#fff'; g.shadowColor = '#fff'; g.shadowBlur = 8;
    const ring = (r, w) => { g.lineWidth = w; g.beginPath(); g.arc(0, 0, r, 0, Math.PI * 2); g.stroke(); };
    ring(240, 4); ring(222, 2); ring(150, 3); ring(140, 1.5); ring(60, 3);
    for (let i = 0; i < 28; i++) {
      g.save(); g.rotate(i / 28 * Math.PI * 2); g.translate(0, -186);
      g.lineWidth = 3; g.beginPath();
      for (let k = 0; k < 4; k++) {
        const x1 = (rand() - 0.5) * 22, y1 = (rand() - 0.5) * 28, x2 = (rand() - 0.5) * 22, y2 = (rand() - 0.5) * 28;
        g.moveTo(x1, y1); g.lineTo(x2, y2);
      }
      g.stroke(); g.restore();
    }
    for (let i = 0; i < 6; i++) {
      const a = i / 6 * Math.PI * 2, b = (i + 2) / 6 * Math.PI * 2;
      g.lineWidth = 2; g.beginPath(); g.moveTo(Math.cos(a) * 150, Math.sin(a) * 150); g.lineTo(Math.cos(b) * 150, Math.sin(b) * 150); g.stroke();
    }
    return toTex(c, { wrap: false });
  },

  // ---------- sprites de partículas ----------
  glow() {
    const W = 128, c = makeCanvas(W, W), g = c.getContext('2d');
    const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(255,255,255,0.6)');
    gr.addColorStop(0.6, 'rgba(255,255,255,0.12)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, W, W);
    return toTex(c, { wrap: false, srgb: false });
  },
  smoke() {
    const W = 128;
    return toTex(pixels(W, W, (x, y) => {
      const d = Math.hypot(x - 64, y - 64) / 64;
      const n = fbm(x * 0.06, y * 0.06, 4, 101);
      const a = clamp((1 - d) * 1.6 * (0.4 + n), 0, 1) * 255;
      return [255, 255, 255, a];
    }), { wrap: false, srgb: false });
  },
  spark() {
    const W = 64, c = makeCanvas(W, W), g = c.getContext('2d');
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.15, 'rgba(255,255,255,0.9)'); gr.addColorStop(0.4, 'rgba(255,255,255,0.15)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, W, W);
    g.globalCompositeOperation = 'lighter'; g.fillStyle = 'rgba(255,255,255,0.5)';
    g.fillRect(30, 0, 4, 64); g.fillRect(0, 30, 64, 4);
    return toTex(c, { wrap: false, srgb: false });
  },
  // arco de corte (gradiente ao longo do arco)
  slash() {
    const W = 512, H = 64;
    return toTex(pixels(W, H, (x, y) => {
      const u = x / W, v = y / H;
      const along = Math.pow(u, 1.6) * (u < 0.92 ? 1 : (1 - u) / 0.08);
      const across = Math.pow(Math.sin(v * Math.PI), 0.6) * (0.4 + 0.6 * v);
      const n = fbm(x * 0.04, y * 0.2, 3, 111);
      const a = clamp(along * across * (0.6 + n * 0.6) * 255);
      return [255, 255, 255, a];
    }), { wrap: false, srgb: false });
  },
  ring() {
    const W = 256, c = makeCanvas(W, W), g = c.getContext('2d');
    const gr = g.createRadialGradient(128, 128, 60, 128, 128, 128);
    gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.75, 'rgba(255,255,255,0.15)');
    gr.addColorStop(0.93, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, W, W);
    return toTex(c, { wrap: false, srgb: false });
  },
  // decalque de aviso (telegraph)
  telegraph() {
    const W = 256, c = makeCanvas(W, W), g = c.getContext('2d');
    const gr = g.createRadialGradient(128, 128, 0, 128, 128, 128);
    gr.addColorStop(0, 'rgba(255,255,255,0.10)'); gr.addColorStop(0.85, 'rgba(255,255,255,0.35)');
    gr.addColorStop(0.95, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, W, W);
    return toTex(c, { wrap: false, srgb: false });
  },
  // flores vermelhas carnudas (cartão alfa)
  flower() {
    const W = 128, c = makeCanvas(W, W), g = c.getContext('2d');
    g.translate(64, 64);
    for (let i = 0; i < 6; i++) {
      g.save(); g.rotate(i / 6 * Math.PI * 2);
      const gr = g.createLinearGradient(0, 0, 0, -56);
      gr.addColorStop(0, '#3a0006'); gr.addColorStop(0.5, '#9c0c18'); gr.addColorStop(1, '#d8323a');
      g.fillStyle = gr; g.beginPath(); g.ellipse(0, -30, 16, 30, 0, 0, Math.PI * 2); g.fill();
      g.strokeStyle = 'rgba(60,0,10,0.7)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(0, -4); g.lineTo(0, -54); g.stroke();
      g.restore();
    }
    g.fillStyle = '#1a0004'; g.beginPath(); g.arc(0, 0, 9, 0, Math.PI * 2); g.fill();
    return toTex(c, { wrap: false });
  },
  // capim alto de pontas roxas
  grassBlade() {
    const W = 128, H = 256, c = makeCanvas(W, H), g = c.getContext('2d');
    for (let i = 0; i < 9; i++) {
      const x = 10 + rand() * 108, h = 140 + rand() * 110, bend = (rand() - 0.5) * 50;
      const gr = g.createLinearGradient(0, H, 0, H - h);
      gr.addColorStop(0, '#16210f'); gr.addColorStop(0.6, '#3c4a22'); gr.addColorStop(0.85, '#5a2c6a'); gr.addColorStop(1, '#b45ad8');
      g.fillStyle = gr; g.beginPath();
      g.moveTo(x - 4, H); g.quadraticCurveTo(x + bend * 0.4, H - h * 0.5, x + bend, H - h); g.quadraticCurveTo(x + bend * 0.4 + 2, H - h * 0.5, x + 4, H); g.fill();
    }
    return toTex(c, { wrap: false });
  },
  bark() {
    const W = 256;
    return toTex(pixels(W, W, (x, y) => {
      const n = fbm(x * 0.03, y * 0.004, 4, 121, 8);
      const ridges = Math.abs(Math.sin(x * 0.12 + n * 10));
      const v = 20 + ridges * 30 + n * 30;
      return [clamp(v * 1.05), clamp(v * 0.9), clamp(v * 0.85)];
    }));
  },
  rock() {
    const W = 256;
    return toTex(pixels(W, W, (x, y) => {
      const n = fbm(x * 0.03, y * 0.03, 5, 131, 8);
      const crack = Math.abs(fbm(x * 0.02, y * 0.02, 3, 132, 5) - 0.5) < 0.02 ? 0.5 : 1;
      return [clamp((130 + n * 80) * crack), clamp((30 + n * 40) * crack), clamp((30 + n * 30) * crack)];
    }));
  },
  // céu noturno com estrelas (equiretangular simples)
  sky() {
    const W = 1024, H = 512, c = makeCanvas(W, H), g = c.getContext('2d');
    const gr = g.createLinearGradient(0, 0, 0, H);
    gr.addColorStop(0, '#02040c'); gr.addColorStop(0.45, '#0b1430'); gr.addColorStop(0.55, '#1a2448'); gr.addColorStop(1, '#05060c');
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
    for (let i = 0; i < 900; i++) {
      const y = rand() * H * 0.5, a = rand() * 0.8 * (1 - y / (H * 0.5));
      g.fillStyle = `rgba(220,230,255,${a})`; g.fillRect(rand() * W, y, rand() < 0.1 ? 2 : 1, rand() < 0.1 ? 2 : 1);
    }
    // nuvens tênues
    const img = g.getImageData(0, 0, W, H), d = img.data;
    for (let y = 0; y < H * 0.55; y++) for (let x = 0; x < W; x++) {
      const n = fbm(x * 0.006, y * 0.02, 4, 141, 6);
      const cl = clamp((n - 0.5) * 2.2, 0, 1) * 0.45;
      const i = (y * W + x) * 4;
      d[i] = mix(d[i], 60, cl); d[i + 1] = mix(d[i + 1], 70, cl); d[i + 2] = mix(d[i + 2], 105, cl);
    }
    g.putImageData(img, 0, 0);
    const t = toTex(c, { wrap: false }); t.mapping = THREE.EquirectangularReflectionMapping; return t;
  },
  // céu do limbo
  limboSky() {
    const W = 1024, H = 512;
    const c = pixels(W, H, (x, y) => {
      const n = fbm(x * 0.004, y * 0.01, 5, 151, 4);
      const vein = Math.pow(1 - Math.abs(fbm(x * 0.006, y * 0.012, 4, 152, 6) - 0.5) * 2, 14);
      const v = n * 30;
      return [clamp(v + vein * 120), clamp(v * 0.2 + vein * 10), clamp(v * 0.4 + vein * 20)];
    });
    const t = toTex(c, { wrap: false }); t.mapping = THREE.EquirectangularReflectionMapping; return t;
  },
  moon() {
    const W = 256, c = makeCanvas(W, W), g = c.getContext('2d');
    const gr = g.createRadialGradient(128, 128, 40, 128, 128, 128);
    gr.addColorStop(0, 'rgba(230,236,255,1)'); gr.addColorStop(0.42, 'rgba(210,220,255,1)'); gr.addColorStop(0.46, 'rgba(160,180,255,0.35)'); gr.addColorStop(1, 'rgba(120,140,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, W, W);
    g.globalCompositeOperation = 'multiply';
    for (let i = 0; i < 14; i++) { g.fillStyle = 'rgba(170,175,200,0.6)'; g.beginPath(); g.arc(90 + rand() * 76, 90 + rand() * 76, 4 + rand() * 12, 0, Math.PI * 2); g.fill(); }
    return toTex(c, { wrap: false });
  },
  banner() {
    const W = 64, H = 128;
    return toTex(pixels(W, H, (x, y) => {
      const n = fbm(x * 0.1, y * 0.05, 3, 161);
      const tip = y > H - (W / 2 - Math.abs(x - W / 2)) ? 0 : 255;
      const trim = x < 4 || x > W - 5 || y < 6 ? 1 : 0;
      if (trim) return [180, 150, 70, tip];
      return [clamp(30 + n * 30), clamp(50 + n * 30), clamp(110 + n * 50), tip];
    }), { wrap: false });
  },
  water() {
    const W = 256;
    return toTex(pixels(W, W, (x, y) => {
      const n = fbm(x * 0.03, y * 0.03, 4, 171, 8);
      const c = Math.pow(1 - Math.abs(n - 0.5) * 2, 8);
      return [clamp(40 + c * 200), clamp(110 + c * 140), clamp(200 + c * 55)];
    }));
  },
  // pergaminho para UI
  paper() {
    const W = 512, H = 256;
    return pixels(W, H, (x, y) => {
      const n = fbm(x * 0.01, y * 0.02, 5, 181);
      const e = Math.min(x, y, W - x, H - y) / 30;
      const burn = clamp(1 - e, 0, 1);
      return [clamp(196 + n * 40 - burn * 120), clamp(176 + n * 34 - burn * 120), clamp(136 + n * 28 - burn * 100)];
    });
  },
};
