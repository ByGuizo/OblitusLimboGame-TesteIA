// =====================================================================
//  Cenários procedurais
// =====================================================================
import * as THREE from 'three';
import { T, fbm } from './textures.js';
import { toon, part, glowMat, weapon, U } from './models.js';
import { G, rnd } from './world.js';

const V3 = THREE.Vector3;
function rep(tex, rx, ry) { const t = tex.clone(); t.repeat.set(rx, ry); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.needsUpdate = true; return t; }
function std(name, rx = 1, ry = 1, o = {}) {
  const p = T.pair(name);
  return new THREE.MeshStandardMaterial({ map: rep(p.map, rx, ry), bumpMap: p.bump ? rep(p.bump, rx, ry) : null, bumpScale: o.bump ?? 2, roughness: o.rough ?? 0.85, metalness: o.metal ?? 0, color: o.color ?? 0xffffff, ...(o.extra || {}) });
}
function mesh(geo, mat, x = 0, y = 0, z = 0, parent, { cast = true, recv = true } = {}) {
  const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = cast; m.receiveShadow = recv; (parent || G.scene).add(m); return m;
}
function glowSprite(color, size, pos, parent) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.get('glow'), color: new THREE.Color(color).multiplyScalar(2), blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, toneMapped: false }));
  s.scale.setScalar(size); s.position.copy(pos); (parent || G.scene).add(s); return s;
}
function setupLights(o) {
  const S = G.scene;
  const hemi = new THREE.HemisphereLight(o.sky || '#3a4a7a', o.ground || '#1a1410', o.hemi ?? 0.6); S.add(hemi);
  const dir = new THREE.DirectionalLight(o.dirColor || '#9ab0ff', o.dir ?? 1.2);
  dir.position.set(...(o.dirPos || [-10, 20, -8]));
  dir.castShadow = true;
  const q = G.quality === 'low' ? 1024 : 2048;
  dir.shadow.mapSize.set(q, q);
  const sc = dir.shadow.camera; sc.left = -18; sc.right = 18; sc.top = 18; sc.bottom = -18; sc.near = 1; sc.far = 70;
  dir.shadow.bias = -0.0005; dir.shadow.normalBias = 0.03;
  S.add(dir); S.add(dir.target);
  const off = new V3(...(o.dirPos || [-10, 20, -8]));
  return { hemi, dir, follow: () => { const p = G.player ? G.player.pos : new V3(); dir.position.copy(p).add(off); dir.target.position.copy(p); } };
}
function candle(pos, parent, lights) {
  const g = new THREE.Group(); g.position.copy(pos); (parent || G.scene).add(g);
  mesh(new THREE.CylinderGeometry(0.025, 0.03, 0.16, 8), toon('#e8dcc0'), 0, 0.08, 0, g, { cast: false });
  const f = mesh(new THREE.ConeGeometry(0.018, 0.06, 6), glowMat('#ffb040', 3), 0, 0.2, 0, g, { cast: false });
  const s = glowSprite('#ff9a30', 0.35, new V3(0, 0.2, 0), g);
  lights && lights.push({ f, s, ph: Math.random() * 10 });
  return g;
}
function flicker(list, t) { for (const c of list) { const k = 0.85 + Math.sin(t * 13 + c.ph) * 0.08 + Math.sin(t * 29 + c.ph * 2) * 0.06; c.f.scale.set(1, k, 1); c.s.material.opacity = k; if (c.l) c.l.intensity = c.base * k; } }

// =====================================================================
//  VARDUN — ruas noturnas
// =====================================================================
function house(x, z, w, d, h, facing, opts = {}) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = facing; G.scene.add(g);
  const stone = opts.stone || std('brick', w / 3, 0.5, { color: '#8a8a90' });
  const timber = opts.timber || new THREE.MeshStandardMaterial({ map: rep(T.get('timber'), Math.max(1, Math.round(w / 3)), 1), roughness: 0.9 });
  mesh(new THREE.BoxGeometry(w, 1.4, d), stone, 0, 0.7, 0, g);
  mesh(new THREE.BoxGeometry(w, h - 1.4, d), timber, 0, 1.4 + (h - 1.4) / 2, 0, g);
  // andar superior em balanço
  if (opts.jetty !== false) mesh(new THREE.BoxGeometry(w + 0.3, 2.2, d + 0.5), timber, 0, h + 1.1, 0.0, g);
  const top = opts.jetty !== false ? h + 2.2 : h;
  // telhado
  const sh = new THREE.Shape(); const rw = (w + 0.9) / 2; sh.moveTo(-rw, 0); sh.lineTo(rw, 0); sh.lineTo(0, opts.roofH || 2.6); sh.closePath();
  const rg = new THREE.ExtrudeGeometry(sh, { depth: d + 1.0, bevelEnabled: false }); rg.translate(0, 0, -(d + 1.0) / 2);
  const roofMat = new THREE.MeshStandardMaterial({ map: rep(T.get('roof'), 2, 2), roughness: 0.95, color: opts.roofColor || '#ffffff' });
  const roof = mesh(rg, roofMat, 0, top, 0, g); roof.rotation.y = Math.PI / 2;
  // chaminé
  if (opts.chimney !== false) { mesh(new THREE.BoxGeometry(0.6, 1.8, 0.6), stone, w * 0.25, top + 1.6, d * 0.2, g); }
  // janelas e porta (face +z local = rua)
  const fz = d / 2 + 0.02;
  const winLit = new THREE.MeshStandardMaterial({ color: '#ffb860', emissive: '#ff9a40', emissiveIntensity: 1.6 });
  const winDark = new THREE.MeshStandardMaterial({ color: '#141822', emissive: '#0a0c14', roughness: 0.3 });
  const frame = toon('#2a1a10');
  const nW = Math.max(1, Math.floor(w / 2.2));
  for (let i = 0; i < nW; i++) {
    const wx = -w / 2 + (i + 0.5) * (w / nW);
    for (const wy of [2.4, h + 1.0]) {
      if (wy < 2 && i === Math.floor(nW / 2)) continue;
      const lit = Math.random() < (opts.lit ?? 0.45);
      mesh(new THREE.PlaneGeometry(0.7, 0.9), lit ? winLit : winDark, wx, wy, wy > h ? fz + 0.25 : fz, g, { cast: false });
      mesh(new THREE.BoxGeometry(0.85, 0.08, 0.08), frame, wx, wy - 0.48, (wy > h ? fz + 0.25 : fz) + 0.03, g, { cast: false });
      mesh(new THREE.BoxGeometry(0.06, 1.0, 0.06), frame, wx, wy, (wy > h ? fz + 0.25 : fz) + 0.03, g, { cast: false });
      if (lit && Math.random() < 0.5) glowSprite('#ff9a40', 1.6, new V3(wx, wy, (wy > h ? fz + 0.25 : fz) + 0.3), g);
    }
  }
  if (opts.door !== false) {
    const dm = mesh(new THREE.BoxGeometry(1.1, 2.0, 0.1), toon('#3a2414'), opts.doorX ?? 0, 1.0, fz, g);
    mesh(new THREE.BoxGeometry(1.3, 0.12, 0.2), frame, opts.doorX ?? 0, 2.05, fz, g);
  }
  return g;
}
function lanternPost(x, z, real, lights) {
  const g = new THREE.Group(); g.position.set(x, 0, z); G.scene.add(g);
  mesh(new THREE.CylinderGeometry(0.06, 0.09, 3.2, 8), toon('#1a1a1e'), 0, 1.6, 0, g);
  mesh(new THREE.BoxGeometry(0.6, 0.06, 0.06), toon('#1a1a1e'), 0.25, 3.15, 0, g);
  const cage = mesh(new THREE.BoxGeometry(0.22, 0.32, 0.22), new THREE.MeshStandardMaterial({ color: '#ffcf80', emissive: '#ffa040', emissiveIntensity: 2.2, transparent: true, opacity: 0.9 }), 0.5, 2.9, 0, g);
  const s = glowSprite('#ffa040', 2.4, new V3(0.5, 2.9, 0), g);
  const L = { f: cage, s, ph: Math.random() * 9 };
  if (real) { const l = new THREE.PointLight('#ffa860', 9, 16, 1.6); l.position.set(0.5, 2.8, 0); g.add(l); L.l = l; L.base = 9; }
  lights.push(L);
}
function stall(x, z, rot, color) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = rot; G.scene.add(g);
  const wood = toon('#5a3a22');
  mesh(new THREE.BoxGeometry(2.4, 0.9, 1.0), wood, 0, 0.45, 0, g);
  for (const sx of [-1.1, 1.1]) for (const sz of [-0.45, 0.45]) mesh(new THREE.CylinderGeometry(0.04, 0.04, 2.3, 6), wood, sx, 1.15, sz, g);
  const aw = mesh(new THREE.BoxGeometry(2.7, 0.05, 1.5), toon(color), 0, 2.3, 0.15, g); aw.rotation.x = 0.25;
  const prod = ['#c03020', '#e08020', '#5a8a2a', '#d0b040', '#7a3a8a'];
  for (let i = 0; i < 14; i++) mesh(new THREE.SphereGeometry(0.08 + Math.random() * 0.05, 8, 6), toon(prod[i % 5]), -1 + Math.random() * 2, 0.97, -0.3 + Math.random() * 0.6, g, { cast: false });
  for (let i = 0; i < 2; i++) mesh(new THREE.BoxGeometry(0.5, 0.4, 0.5), toon('#6a4a2a'), -0.8 + i * 1.6, 0.2, 0.9, g);
  return g;
}
function bunting(a, b, cols) {
  const pts = [], n = 18, sag = 0.9;
  for (let i = 0; i <= n; i++) { const t = i / n; pts.push(new V3().lerpVectors(a, b, t).add(new V3(0, -Math.sin(t * Math.PI) * sag, 0))); }
  const curve = new THREE.CatmullRomCurve3(pts);
  mesh(new THREE.TubeGeometry(curve, 30, 0.012, 4), toon('#2a2018'), 0, 0, 0, null, { cast: false });
  const fl = new THREE.BufferGeometry().setFromPoints([new V3(-0.18, 0, 0), new V3(0.18, 0, 0), new V3(0, -0.42, 0)]); fl.computeVertexNormals();
  for (let i = 1; i < 26; i++) {
    const p = curve.getPoint(i / 26);
    const m = mesh(fl, toon(cols[i % cols.length], { side: THREE.DoubleSide }), p.x, p.y, p.z, null, { cast: false });
    m.lookAt(p.x + (b.z - a.z), p.y, p.z - (b.x - a.x));
  }
}
function barrel(x, z, parent, s = 1) {
  const m = mesh(new THREE.CylinderGeometry(0.38 * s, 0.38 * s, 0.95 * s, 14), toon('#6a4426'), x, 0.475 * s, z, parent);
  for (const y of [0.18, 0.77]) mesh(new THREE.TorusGeometry(0.39 * s, 0.025, 4, 16), toon('#2a2a2a'), x, y * s, z, parent, { cast: false }).rotation.x = Math.PI / 2;
  return m;
}
function crate(x, z, parent, s = 1, y = 0) { const m = mesh(new THREE.BoxGeometry(0.7 * s, 0.7 * s, 0.7 * s), new THREE.MeshStandardMaterial({ map: rep(T.get('wood'), 0.5, 0.5), roughness: 0.9 }), x, y + 0.35 * s, z, parent); m.rotation.y = Math.random(); return m; }

export function buildVardun() {
  const S = G.scene;
  S.background = T.get('sky'); S.environment = null;
  S.fog = new THREE.FogExp2('#0b1226', 0.032);
  const L = setupLights({ sky: '#4a5a9a', ground: '#14100c', hemi: 0.75, dirColor: '#a8b8ff', dir: 1.1, dirPos: [-12, 22, 6] });
  // chão
  const ground = mesh(new THREE.PlaneGeometry(14, 80), std('cobble', 3, 18, { rough: 0.65, bump: 3 }), 0, 0, 6, null, { cast: false });
  ground.rotation.x = -Math.PI / 2;
  // poças
  const puddleMat = new THREE.MeshStandardMaterial({ color: '#0a1020', roughness: 0.05, metalness: 0.8, transparent: true, opacity: 0.7 });
  for (let i = 0; i < 9; i++) { const p = mesh(new THREE.CircleGeometry(rnd(0.5, 1.2), 16), puddleMat, rnd(-3, 3), 0.012, rnd(-24, 36), null, { cast: false }); p.rotation.x = -Math.PI / 2; p.scale.x = rnd(1, 2); }
  // casas (lado esquerdo +x olha para -x; lado direito)
  const obstacles = [];
  let z = -30;
  const sideZ = [];
  while (z < 40) {
    const w = rnd(5, 7.5);
    sideZ.push([z + w / 2, w]); z += w + rnd(0.1, 0.6);
  }
  for (const [cz, w] of sideZ) {
    const h = rnd(3.4, 4.6), d = 6;
    const isRurik = cz > 6 && cz < 14;
    house(-7.5, cz, w, d, h, Math.PI / 2, { lit: isRurik ? 1 : 0.4 });
    if (!(cz > 34)) house(7.5, cz + 1.3, w, d, h * rnd(0.9, 1.1), -Math.PI / 2, { lit: 0.4, roofColor: Math.random() < 0.5 ? '#c8b0b0' : '#ffffff' });
  }
  // fundo: muralha e torres distantes
  for (let i = 0; i < 7; i++) {
    const tx = rnd(-30, 30), tz = rnd(55, 75), th = rnd(10, 22);
    mesh(new THREE.CylinderGeometry(rnd(1.5, 2.5), rnd(2, 3), th, 10), new THREE.MeshStandardMaterial({ color: '#1a2038', roughness: 1 }), tx, th / 2, tz, null, { cast: false });
    mesh(new THREE.ConeGeometry(rnd(2.2, 3.2), rnd(4, 7), 10), new THREE.MeshStandardMaterial({ color: '#141a30', roughness: 1 }), tx, th + 2.5, tz, null, { cast: false });
  }
  // lua
  const moon = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.get('moon'), color: new THREE.Color('#dfe6ff').multiplyScalar(1.6), fog: false, transparent: true, toneMapped: false }));
  moon.scale.setScalar(16); moon.position.set(-30, 45, 70); S.add(moon);
  // barracas, barris, caixas
  stall(3.0, -14, -Math.PI / 2, '#8a2a2a'); stall(-3.0, -2, Math.PI / 2, '#2a5a8a'); stall(3.0, 22, -Math.PI / 2, '#7a6a2a');
  obstacles.push({ minX: 2.4, maxX: 3.6, minZ: -15.3, maxZ: -12.7 }, { minX: -3.6, maxX: -2.4, minZ: -3.3, maxZ: -0.7 }, { minX: 2.4, maxX: 3.6, minZ: 20.7, maxZ: 23.3 });
  for (const [bx, bz] of [[-3.8, -20], [-3.7, -19.2], [3.8, 4], [3.9, 30], [-3.8, 26], [-3.9, 26.8]]) { barrel(bx, bz); obstacles.push({ x: bx, z: bz, r: 0.4 }); }
  for (const [cx, cz] of [[3.8, 5.2], [-3.8, 18], [-3.6, 18.8], [3.7, 31.2]]) { crate(cx, cz); obstacles.push({ x: cx, z: cz, r: 0.45 }); }
  // lanternas
  const lights = [];
  [[-3.9, -22, true], [3.9, -12, false], [-3.9, -4, true], [3.9, 6, true], [-3.9, 15, false], [3.9, 25, true], [-3.9, 33, false]].forEach(([x, z, r]) => { lanternPost(x, z, r, lights); obstacles.push({ x, z, r: 0.15 }); });
  // bandeirolas
  bunting(new V3(-4.5, 5.5, -16), new V3(4.5, 5.2, -15), ['#a02020', '#d06020', '#2a4a8a']);
  bunting(new V3(-4.5, 5.6, 0), new V3(4.5, 5.4, 1), ['#a02020', '#e0c040', '#2a6a4a']);
  bunting(new V3(-4.5, 5.4, 16), new V3(4.5, 5.5, 17), ['#8a2a6a', '#d06020', '#2a4a8a']);
  // memorial de Lili
  const mem = new THREE.Group(); mem.position.set(3.6, 0, -7); S.add(mem);
  const candles = [];
  for (let i = 0; i < 9; i++) candle(new V3(rnd(-0.4, 0.3), 0, rnd(-0.8, 0.8)), mem, candles);
  for (let i = 0; i < 6; i++) { const f = mesh(new THREE.CircleGeometry(0.12, 6), toon(['#e8e0f0', '#d03040', '#f0d060'][i % 3], { side: THREE.DoubleSide }), rnd(-0.3, 0.2), 0.02, rnd(-0.7, 0.7), mem, { cast: false }); f.rotation.x = -Math.PI / 2; }
  const ml = new THREE.PointLight('#ffa050', 3, 5, 2); ml.position.set(0, 0.6, 0); mem.add(ml); candles.push({ f: new THREE.Object3D(), s: { material: {} }, ph: 0, l: ml, base: 3 });
  // placa da Taverna de Rurik
  const sign = mesh(new THREE.BoxGeometry(1.6, 0.8, 0.06), new THREE.MeshStandardMaterial({ map: (() => { const c = document.createElement('canvas'); c.width = 256; c.height = 128; const g = c.getContext('2d'); g.fillStyle = '#4a2e18'; g.fillRect(0, 0, 256, 128); g.strokeStyle = '#2a1608'; g.lineWidth = 8; g.strokeRect(4, 4, 248, 120); g.fillStyle = '#d8b878'; g.font = 'bold 34px serif'; g.textAlign = 'center'; g.fillText('TAVERNA', 128, 55); g.font = 'bold 30px serif'; g.fillText('de RURIK', 128, 95); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; })(), roughness: 0.9 }), -4.4, 3.4, 10.5);
  sign.rotation.y = Math.PI / 2; sign.rotation.z = 0.08;
  // porta da taverna de Darius (fim da rua)
  const dar = house(0, 44, 9, 6, 4, Math.PI, { lit: 0.05, roofColor: '#806060', jetty: false });
  const soot = mesh(new THREE.PlaneGeometry(9, 4), new THREE.MeshBasicMaterial({ color: '#000', transparent: true, opacity: 0.35 }), 0, 2, 40.95, null, { cast: false }); soot.rotation.y = Math.PI;
  const darLight = new THREE.PointLight('#ff5030', 4, 7, 2); darLight.position.set(0, 2.2, 40); S.add(darLight);
  const update = (dt, t) => {
    L.follow(); flicker(lights, t); flicker(candles, t);
    if (Math.random() < dt * 4) G.fx.burst('mote', G.player ? G.player.pos : new V3(), { n: 1, r: 10, color: '#9ab0ff', color2: '#405080' });
    darLight.intensity = 3 + Math.sin(t * 7) * 0.8 + Math.sin(t * 17) * 0.4;
  };
  return {
    name: 'vardun', bounds: { type: 'box', minX: -4.4, maxX: 4.4, minZ: -28, maxZ: 40.3 }, obstacles, surface: 'stone',
    spawn: { pos: new V3(0, 0, -25), yaw: 0 },
    points: { mira: new V3(2.6, 0, -6.6), rurik: new V3(-3.4, 0, 10.2), near: new V3(-3.6, 0, 12.6), darius: new V3(0, 0, 39.5), memorial: new V3(3.6, 0, -7) },
    update, map: { w: 10, h: 72, cx: 0, cz: 6 },
  };
}

// =====================================================================
//  TAVERNA DE DARIUS — arena interna
// =====================================================================
export function buildTavern() {
  const S = G.scene;
  S.background = new THREE.Color('#050302'); S.environment = null;
  S.fog = new THREE.FogExp2('#1a0f08', 0.024);
  const L = setupLights({ sky: '#8a6040', ground: '#2a1608', hemi: 0.95, dirColor: '#ffb070', dir: 0.5, dirPos: [4, 18, 3] });
  const W = 11.5, D = 9.5, H = 7.6;
  const floor = mesh(new THREE.PlaneGeometry(W * 2, D * 2), std('wood', 5, 5, { rough: 0.75, bump: 2.5 }), 0, 0, 0, null, { cast: false }); floor.rotation.x = -Math.PI / 2;
  const wallMat = std('brick', 6, 2, { color: '#7a5a48' }), panel = std('wood', 4, 1, { color: '#a07050' });
  const walls = [[0, D, 0], [0, -D, Math.PI], [W, 0, -Math.PI / 2], [-W, 0, Math.PI / 2]];
  for (const [x, z, r] of walls) {
    const len = Math.abs(x) > 0 ? D * 2 : W * 2;
    const w = mesh(new THREE.PlaneGeometry(len, H), wallMat, x, H / 2, z, null, { cast: false }); w.rotation.y = r + Math.PI;
    const p = mesh(new THREE.PlaneGeometry(len, 1.4), panel, x * 0.995, 0.7, z * 0.995, null, { cast: false }); p.rotation.y = r + Math.PI;
  }
  const ceil = mesh(new THREE.PlaneGeometry(W * 2, D * 2), std('wood', 4, 4, { color: '#4a3020' }), 0, H, 0, null, { cast: false }); ceil.rotation.x = Math.PI / 2;
  // vigas
  const beamMat = toon('#2e1c10');
  for (let i = -3; i <= 3; i++) mesh(new THREE.BoxGeometry(0.35, 0.4, D * 2), beamMat, i * 3.2, H - 0.25, 0, null, { cast: false });
  // balcão (mezanino) nos fundos e lados
  const balY = 3.6, balMat = std('wood', 3, 1, { color: '#8a6040' });
  mesh(new THREE.BoxGeometry(W * 2, 0.25, 3), balMat, 0, balY, D - 1.5);
  mesh(new THREE.BoxGeometry(3, 0.25, D * 2 - 3), balMat, W - 1.5, balY, -1.5);
  const postMat = toon('#3a2414');
  for (let x = -W + 1; x <= W - 1; x += 2.6) { mesh(new THREE.BoxGeometry(0.22, balY, 0.22), postMat, x, balY / 2, D - 3); mesh(new THREE.BoxGeometry(0.08, 0.9, 0.08), postMat, x, balY + 0.55, D - 3); }
  mesh(new THREE.BoxGeometry(W * 2, 0.08, 0.1), postMat, 0, balY + 1.0, D - 3);
  for (let z = -D + 1; z <= D - 3; z += 2.6) { mesh(new THREE.BoxGeometry(0.22, balY, 0.22), postMat, W - 3, balY / 2, z); mesh(new THREE.BoxGeometry(0.08, 0.9, 0.08), postMat, W - 3, balY + 0.55, z); }
  mesh(new THREE.BoxGeometry(0.1, 0.08, D * 2 - 3), postMat, W - 3, balY + 1.0, -1.5);
  // escada
  for (let i = 0; i < 12; i++) mesh(new THREE.BoxGeometry(1.4, 0.15, 0.4), balMat, -W + 1.2, (i + 1) * 0.3, -2 + i * 0.4);
  // bar (balcão de bebidas)
  const bar = mesh(new THREE.BoxGeometry(6, 1.1, 0.9), std('wood', 3, 0.5, { color: '#6a4028' }), -4, 0.55, -D + 1.6);
  mesh(new THREE.BoxGeometry(6.2, 0.1, 1.1), toon('#3a2010'), -4, 1.12, -D + 1.6);
  for (let s = 0; s < 3; s++) {
    mesh(new THREE.BoxGeometry(6, 0.08, 0.4), toon('#3a2010'), -4, 1.8 + s * 0.7, -D + 0.25, null, { cast: false });
    for (let k = 0; k < 14; k++) mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.32, 8), new THREE.MeshStandardMaterial({ color: ['#2a5a2a', '#5a2a1a', '#2a2a5a', '#7a6a2a'][k % 4], roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85 }), -6.7 + k * 0.4, 2.0 + s * 0.7, -D + 0.25, null, { cast: false });
  }
  const obstacles = [{ minX: -7, maxX: -1, minZ: -D, maxZ: -D + 2.1 }];
  // mesas nas bordas (centro livre para a luta)
  const candles = [];
  const tableAt = (x, z, toppled) => {
    const g = new THREE.Group(); g.position.set(x, 0, z); S.add(g);
    if (toppled) { g.rotation.z = Math.PI / 2; g.position.y = 0.55; g.rotation.y = Math.random() * 3; }
    mesh(new THREE.CylinderGeometry(0.95, 0.95, 0.1, 18), std('wood', 1, 1, { color: '#8a5a38' }), 0, 0.82, 0, g);
    mesh(new THREE.CylinderGeometry(0.12, 0.2, 0.8, 8), toon('#3a2414'), 0, 0.4, 0, g);
    if (!toppled) {
      candle(new V3(0.2, 0.87, 0.1), g, candles);
      mesh(new THREE.CylinderGeometry(0.06, 0.07, 0.3, 8), new THREE.MeshStandardMaterial({ color: '#2a4a2a', roughness: 0.1, transparent: true, opacity: 0.8 }), -0.3, 1.02, -0.2, g);
      mesh(new THREE.CylinderGeometry(0.07, 0.06, 0.14, 8), toon('#8a6a3a'), 0.4, 0.94, -0.3, g);
      for (let k = 0; k < 3; k++) { const a = k * 2.1 + Math.random(); mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.06, 10), std('wood', 0.5, 0.5), Math.cos(a) * 1.3, 0.5, Math.sin(a) * 1.3, g); mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.5, 5), toon('#3a2414'), Math.cos(a) * 1.3, 0.25, Math.sin(a) * 1.3, g); }
    }
    obstacles.push({ x, z, r: toppled ? 0.6 : 1.0 });
  };
  tableAt(-8.5, 4.5); tableAt(8.4, -5.5); tableAt(-8.6, -2.5); tableAt(5.5, 6.8, true); tableAt(-4.8, 6.6); tableAt(1.5, 7.2);
  // banquinhos tombados e destroços
  for (let i = 0; i < 6; i++) { const s = mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.06, 10), std('wood', 0.5, 0.5), rnd(-6, 6), 0.03, rnd(-5, 5)); s.rotation.set(rnd(0, 1.5), 0, rnd(0, 1.5)); s.position.y = 0.15; }
  for (const [bx, bz] of [[10.5, 8.4], [9.6, 8.6], [10.6, 7.5], [-10.5, -8.4], [10.5, -8.5]]) { barrel(bx, bz); obstacles.push({ x: bx, z: bz, r: 0.42 }); }
  // lustre central
  const chand = new THREE.Group(); chand.position.set(0, H - 2.2, 0); S.add(chand);
  mesh(new THREE.TorusGeometry(1.4, 0.06, 6, 28), toon('#1a1a1a'), 0, 0, 0, chand).rotation.x = Math.PI / 2;
  mesh(new THREE.TorusGeometry(0.7, 0.05, 6, 20), toon('#1a1a1a'), 0, 0.3, 0, chand).rotation.x = Math.PI / 2;
  for (let i = 0; i < 4; i++) { const ch = mesh(new THREE.CylinderGeometry(0.015, 0.015, 2.2, 4), toon('#1a1a1a'), Math.cos(i * 1.57) * 0.7, 1.1, Math.sin(i * 1.57) * 0.7, chand); ch.rotation.z = Math.cos(i * 1.57) * 0.3; ch.rotation.x = -Math.sin(i * 1.57) * 0.3; }
  for (let i = 0; i < 10; i++) candle(new V3(Math.cos(i / 10 * Math.PI * 2) * 1.4, 0.05, Math.sin(i / 10 * Math.PI * 2) * 1.4), chand, candles);
  for (let i = 0; i < 5; i++) candle(new V3(Math.cos(i / 5 * Math.PI * 2) * 0.7, 0.35, Math.sin(i / 5 * Math.PI * 2) * 0.7), chand, candles);
  const cl = new THREE.PointLight('#ffa860', 40, 24, 1.3); cl.position.set(0, H - 2.6, 0); cl.castShadow = G.quality !== 'low'; cl.shadow.mapSize.set(512, 512); S.add(cl);
  candles.push({ f: new THREE.Object3D(), s: { material: {} }, ph: 1, l: cl, base: 40 });
  // arandelas
  for (const [x, z] of [[-W + 0.2, -4], [W - 0.2, 3], [-W + 0.2, 5.5], [3, -D + 0.2]]) {
    const g = new THREE.Group(); g.position.set(x, 2.4, z); S.add(g);
    candle(new V3(0, 0, 0), g, candles); glowSprite('#ff8a30', 2.2, new V3(0, 0.2, 0), g);
  }
  const wl1 = new THREE.PointLight('#ff9040', 12, 12, 1.6); wl1.position.set(-W + 1, 2.6, -4); S.add(wl1);
  const wl2 = new THREE.PointLight('#ff9040', 12, 12, 1.6); wl2.position.set(W - 1, 2.6, 3); S.add(wl2);
  candles.push({ f: new THREE.Object3D(), s: { material: {} }, ph: 2, l: wl1, base: 12 }, { f: new THREE.Object3D(), s: { material: {} }, ph: 3, l: wl2, base: 12 });
  // portas
  for (const [x, z, r] of [[0, -D + 0.05, 0], [W - 0.05, -4.5, -Math.PI / 2], [-W + 0.05, 2, Math.PI / 2]]) {
    const d = mesh(new THREE.BoxGeometry(1.6, 2.6, 0.12), toon('#2a1608'), x, 1.3, z); d.rotation.y = r;
  }
  const update = (dt, t) => {
    L.follow(); flicker(candles, t);
    chand.rotation.y = Math.sin(t * 0.3) * 0.05;
    if (Math.random() < dt * 6) G.fx.burst('mote', new V3(0, 0.5, 0), { n: 1, r: 9, color: '#ffc080', color2: '#804020' });
  };
  return {
    name: 'tavern', bounds: { type: 'box', minX: -W + 0.6, maxX: W - 0.6, minZ: -D + 0.6, maxZ: D - 0.6 }, obstacles, surface: 'wood', ceiling: H,
    spawn: { pos: new V3(0, 0, -6.5), yaw: 0 },
    points: { darius: new V3(0, 0, 4.5), doorBack: new V3(0, 0, -D + 1.2), doorRight: new V3(W - 1.2, 0, -4.5), doorLeft: new V3(-W + 1.2, 0, 2), stairs: new V3(-W + 1.4, 0, 2.5), balcony: new V3(4, 0, D - 2) },
    update, map: { w: W * 2, h: D * 2, cx: 0, cz: 0 },
  };
}

// =====================================================================
//  VALE DAS FLORES SANGRENTAS
// =====================================================================
function twistedTree(x, z, s = 1, parent) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = Math.random() * 6; (parent || G.scene).add(g);
  const bark = new THREE.MeshStandardMaterial({ map: rep(T.get('bark'), 1, 3), color: '#5a4a50', roughness: 1 });
  const pts = []; let px = 0, pz = 0;
  for (let i = 0; i <= 6; i++) { pts.push(new V3(px, i * 1.3 * s, pz)); px += rnd(-0.35, 0.35) * s; pz += rnd(-0.35, 0.35) * s; }
  const curve = new THREE.CatmullRomCurve3(pts);
  const trunk = new THREE.TubeGeometry(curve, 24, 0.32 * s, 8);
  // afinar o tronco
  const pos = trunk.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i) / (7.8 * s), tt = Math.max(0.2, 1 - y * 0.75);
    const c = curve.getPoint(Math.min(1, Math.max(0, pos.getY(i) / (7.8 * s))));
    pos.setX(i, c.x + (pos.getX(i) - c.x) * tt); pos.setZ(i, c.z + (pos.getZ(i) - c.z) * tt);
  }
  trunk.computeVertexNormals();
  mesh(trunk, bark, 0, 0, 0, g);
  for (let b = 0; b < 6; b++) {
    const st = curve.getPoint(rnd(0.45, 0.95));
    const dir = new V3(rnd(-1, 1), rnd(0.2, 0.9), rnd(-1, 1)).normalize();
    const bp = [st, st.clone().addScaledVector(dir, 1.2 * s).add(new V3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3))), st.clone().addScaledVector(dir, 2.4 * s).add(new V3(rnd(-0.5, 0.5), rnd(-0.6, 0.3), rnd(-0.5, 0.5)))];
    mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(bp), 8, 0.08 * s, 5), bark, 0, 0, 0, g);
  }
  // copa escura esparsa
  for (let k = 0; k < 4; k++) {
    const c = curve.getPoint(1).add(new V3(rnd(-1.5, 1.5) * s, rnd(-0.5, 1), rnd(-1.5, 1.5) * s));
    mesh(new THREE.IcosahedronGeometry(rnd(0.9, 1.5) * s, 0), new THREE.MeshStandardMaterial({ color: '#1a1416', roughness: 1, flatShading: true }), c.x, c.y, c.z, g);
  }
  return g;
}
function grassField(r0, r1, count, center = new V3(), hs = 1) {
  const tex = T.get('grassBlade');
  const mat = new THREE.MeshStandardMaterial({ map: tex, alphaTest: 0.4, side: THREE.DoubleSide, roughness: 1, color: '#c0c0c0' });
  mat.onBeforeCompile = (s) => {
    s.uniforms.uTime = U.time;
    s.vertexShader = 'uniform float uTime;\n' + s.vertexShader.replace('#include <begin_vertex>', `vec3 transformed = position; float sw = uv.y * uv.y; vec4 wp = instanceMatrix * vec4(position,1.0); transformed.x += sin(uTime*1.6 + wp.x*0.4 + wp.z*0.3) * 0.18 * sw;`);
  };
  const geo = new THREE.PlaneGeometry(1.0, 1.6); geo.translate(0, 0.8, 0);
  const g2 = geo.clone(); g2.rotateY(Math.PI / 2);
  const merged = mergeGeos([geo, g2]);
  const im = new THREE.InstancedMesh(merged, mat, count);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new V3();
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(rnd(r0 * r0, r1 * r1));
    q.setFromAxisAngle(new V3(0, 1, 0), Math.random() * 6); const s = rnd(0.6, 1.4) * hs; sc.set(s, s * rnd(0.7, 1.3), s);
    m4.compose(new V3(center.x + Math.cos(a) * r, 0, center.z + Math.sin(a) * r), q, sc); im.setMatrixAt(i, m4);
  }
  im.receiveShadow = true; G.scene.add(im); return im;
}
function mergeGeos(geos) {
  const pos = [], uv = [], nor = [], idx = []; let off = 0;
  for (const g of geos) {
    const p = g.attributes.position, u = g.attributes.uv, n = g.attributes.normal;
    for (let i = 0; i < p.count; i++) { pos.push(p.getX(i), p.getY(i), p.getZ(i)); uv.push(u.getX(i), u.getY(i)); nor.push(n.getX(i), n.getY(i), n.getZ(i)); }
    const ix = g.index.array; for (let i = 0; i < ix.length; i++) idx.push(ix[i] + off);
    off += p.count;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); out.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); out.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); out.setIndex(idx);
  return out;
}
function flowerField(r0, r1, count, center = new V3()) {
  const mat = new THREE.MeshStandardMaterial({ map: T.get('flower'), alphaTest: 0.3, side: THREE.DoubleSide, roughness: 0.6, emissive: '#300004' });
  const geo = new THREE.PlaneGeometry(0.5, 0.5); geo.rotateX(-Math.PI / 2);
  const im = new THREE.InstancedMesh(geo, mat, count);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(rnd(r0 * r0, r1 * r1)), s = rnd(0.6, 1.6);
    e.set(rnd(-0.4, 0.4), Math.random() * 6, rnd(-0.4, 0.4)); q.setFromEuler(e);
    m4.compose(new V3(center.x + Math.cos(a) * r, rnd(0.05, 0.35), center.z + Math.sin(a) * r), q, new V3(s, s, s)); im.setMatrixAt(i, m4);
  }
  G.scene.add(im); return im;
}
export function buildValley() {
  const S = G.scene;
  S.background = new THREE.Color('#0c0608'); S.environment = null;
  S.fog = new THREE.FogExp2('#3a1622', 0.036);
  const L = setupLights({ sky: '#9a6a90', ground: '#2a1014', hemi: 1.25, dirColor: '#d0a8c8', dir: 1.3, dirPos: [8, 20, -6] });
  const ground = mesh(new THREE.CircleGeometry(60, 48), new THREE.MeshStandardMaterial({ map: rep(T.get('ground'), 14, 14), roughness: 1, color: '#9a8080' }), 0, 0, 0, null, { cast: false }); ground.rotation.x = -Math.PI / 2;
  const obstacles = [];
  for (let i = 0; i < 46; i++) {
    const a = rnd(0, Math.PI * 2), r = i < 18 ? rnd(9, 20) : rnd(20, 40);
    const x = Math.cos(a) * r, z = Math.sin(a) * r;
    if (Math.hypot(x - 0, z - 6) < 4) continue;
    twistedTree(x, z, rnd(0.8, 1.3)); if (r < 21) obstacles.push({ x, z, r: 0.5 });
  }
  // árvore das runas
  const rt = twistedTree(5, 9, 1.6); obstacles.push({ x: 5, z: 9, r: 0.8 });
  const runeBand = mesh(new THREE.CylinderGeometry(0.62, 0.66, 1.2, 16, 1, true), new THREE.MeshBasicMaterial({ map: rep(T.get('runes'), 3, 1), color: new THREE.Color('#40a0ff').multiplyScalar(2.5), transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }), 5, 1.6, 9, null, { cast: false });
  grassField(3.5, 30, G.quality === 'low' ? 2500 : 6000, undefined, 0.75);
  flowerField(0.5, 30, G.quality === 'low' ? 1500 : 3500);
  // acampamento
  const camp = new V3(0, 0, 0);
  for (let i = 0; i < 9; i++) { const a = i / 9 * Math.PI * 2; mesh(new THREE.DodecahedronGeometry(0.2, 0), new THREE.MeshStandardMaterial({ color: '#4a4448', flatShading: true }), Math.cos(a) * 0.6, 0.12, Math.sin(a) * 0.6); }
  for (let i = 0; i < 4; i++) { const l = mesh(new THREE.CylinderGeometry(0.07, 0.07, 1.0, 6), toon('#3a2414'), 0, 0.15, 0); l.rotation.set(Math.PI / 2, i * 0.8, 0.3); }
  for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI * 2 + 0.4; const b = mesh(new THREE.BoxGeometry(0.8, 0.12, 1.8), toon(['#5a3a2a', '#3a4a5a', '#5a2a3a', '#3a5a3a'][i]), Math.cos(a) * 2.6, 0.06, Math.sin(a) * 2.6); b.rotation.y = -a; }
  const fire = new THREE.PointLight('#ff7a30', 10, 14, 1.6); fire.position.set(0, 0.8, 0); S.add(fire);
  obstacles.push({ x: 0, z: 0, r: 0.8 });
  const update = (dt, t) => {
    L.follow();
    fire.intensity = 9 + Math.sin(t * 11) * 1.5 + Math.sin(t * 23) * 1;
    if (Math.random() < dt * 25) G.fx.burst('fire', camp, { n: 1, r: 0.25 });
    if (Math.random() < dt * 6) G.fx.burst('smoke', camp.clone().setY(1), { n: 1, r: 0.2, alpha: 0.25 });
    if (Math.random() < dt * 8) G.fx.burst('petal', G.player ? G.player.pos : camp, { n: 1, r: 10 });
    if (Math.random() < dt * 3) G.fx.burst('ember', camp, { n: 1, r: 0.3 });
  };
  return {
    name: 'valley', bounds: { type: 'circle', r: 24, cx: 0, cz: 0 }, obstacles, surface: 'grass',
    spawn: { pos: new V3(-2.5, 0, -3), yaw: 0.6 }, points: { tree: new V3(4.2, 0, 7.6), camp }, runeBand, update, camExtra: 6,
    map: { w: 50, h: 50, cx: 0, cz: 0 },
  };
}

// =====================================================================
//  A BARREIRA DO INFINITO — domínio da criatura
// =====================================================================
export function buildDomain() {
  const S = G.scene;
  S.background = T.get('limboSky'); S.backgroundIntensity = 0.5; S.environment = null;
  S.fog = new THREE.FogExp2('#1e1430', 0.026);
  const L = setupLights({ sky: '#8a7ac0', ground: '#2a1a20', hemi: 1.5, dirColor: '#b8c4ff', dir: 1.6, dirPos: [-6, 22, -10] });
  const R = 16;
  const ground = mesh(new THREE.CircleGeometry(40, 64), new THREE.MeshStandardMaterial({ map: rep(T.get('ground'), 10, 10), roughness: 1, color: '#c8e8b0' }), 0, 0, 0, null, { cast: false }); ground.rotation.x = -Math.PI / 2;
  const moonL = new THREE.PointLight('#8a9aff', 40, 45, 1.2); moonL.position.set(0, 14, 0); S.add(moonL);
  // anel de runas no chão
  const runeRing = mesh(new THREE.RingGeometry(R - 0.6, R + 0.6, 96), new THREE.MeshBasicMaterial({ map: rep(T.get('runes'), 12, 1), color: new THREE.Color('#40a8ff').multiplyScalar(2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), 0, 0.03, 0, null, { cast: false });
  runeRing.rotation.x = -Math.PI / 2;
  const runeCircle = mesh(new THREE.PlaneGeometry(9, 9), new THREE.MeshBasicMaterial({ map: T.get('runes'), color: new THREE.Color('#40a8ff').multiplyScalar(2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), 0, 0.04, R + 4, null, { cast: false });
  runeCircle.rotation.x = -Math.PI / 2;
  // rocha vermelha rachada
  const rock = mesh(new THREE.DodecahedronGeometry(3.2, 1), new THREE.MeshStandardMaterial({ map: rep(T.get('rock'), 2, 2), roughness: 0.9, flatShading: true }), 0, 2.2, R + 4);
  rock.scale.set(1, 1.3, 0.9);
  const rl = new THREE.PointLight('#40a0ff', 12, 20, 1.6); rl.position.set(0, 2, R + 1); S.add(rl);
  // muralha de árvores
  for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2 + rnd(0, 0.1), r = R + rnd(3, 9); twistedTree(Math.cos(a) * r, Math.sin(a) * r, rnd(1, 1.5)); }
  grassField(R + 1, R + 12, 3000);
  flowerField(R - 2, R + 12, 2500);
  flowerField(2, R - 3, 500);
  // pilares de runas
  const pillars = [];
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * Math.PI * 2;
    const p = mesh(new THREE.BoxGeometry(0.8, 4, 0.8), new THREE.MeshStandardMaterial({ color: '#2a2630', roughness: 0.8 }), Math.cos(a) * (R + 1.5), 2, Math.sin(a) * (R + 1.5));
    const g = mesh(new THREE.BoxGeometry(0.82, 2.6, 0.82), new THREE.MeshBasicMaterial({ map: rep(T.get('runes'), 1, 2), color: new THREE.Color('#40a8ff').multiplyScalar(2), transparent: true, blending: THREE.AdditiveBlending, toneMapped: false }), p.position.x, 2.2, p.position.z, null, { cast: false });
    pillars.push(g);
  }
  const update = (dt, t) => {
    L.follow();
    runeRing.material.opacity = 0.6 + Math.sin(t * 2) * 0.25;
    runeCircle.rotation.z = t * 0.2;
    rl.intensity = 10 + Math.sin(t * 3) * 3;
    if (Math.random() < dt * 10) G.fx.burst('mote', new V3(0, 0, 0), { n: 1, r: R, color: '#60a0ff', color2: '#4030a0' });
    if (Math.random() < dt * 6) G.fx.burst('petal', new V3(0, 2, 0), { n: 1, r: R });
  };
  return {
    name: 'domain', bounds: { type: 'circle', r: R - 0.5, cx: 0, cz: 0 }, obstacles: [], surface: 'grass',
    spawn: { pos: new V3(0, 0, -10), yaw: 0 }, points: { boss: new V3(0, 0, 7), rock: new V3(0, 0, R + 2) }, update, camExtra: 3,
    map: { w: R * 2.2, h: R * 2.2, cx: 0, cz: 0 },
  };
}

// =====================================================================
//  SALÃO DO TRONO — Castelo de Hikari
// =====================================================================
export function buildThrone() {
  const S = G.scene;
  S.background = new THREE.Color('#03040a');
  S.environment = T.get('sky'); S.environmentIntensity = 0.6;
  S.fog = new THREE.FogExp2('#0a0e1c', 0.028);
  const L = setupLights({ sky: '#3a4a7a', ground: '#0a0a12', hemi: 0.55, dirColor: '#8aa0ff', dir: 0.6, dirPos: [5, 24, -8] });
  const R = 13;
  const floor = mesh(new THREE.CircleGeometry(R + 6, 64), new THREE.MeshStandardMaterial({ map: rep(T.get('marble'), 6, 6), roughness: 0.18, metalness: 0.35 }), 0, 0, 0, null, { cast: false });
  floor.rotation.x = -Math.PI / 2;
  // mosaico central
  const mos = mesh(new THREE.PlaneGeometry(9, 9), new THREE.MeshBasicMaterial({ map: T.get('runes'), color: new THREE.Color('#8a7a40').multiplyScalar(0.6), transparent: true, depthWrite: false }), 0, 0.01, 0, null, { cast: false });
  mos.rotation.x = -Math.PI / 2;
  // paredes circulares
  const wall = mesh(new THREE.CylinderGeometry(R + 6, R + 6, 16, 48, 1, true), std('brick', 14, 3, { color: '#3a3a48' }), 0, 8, 0, null, { cast: false });
  wall.material.side = THREE.BackSide;
  const ceil = mesh(new THREE.CircleGeometry(R + 6, 48), new THREE.MeshStandardMaterial({ color: '#0a0a12', roughness: 1 }), 0, 16, 0, null, { cast: false }); ceil.rotation.x = Math.PI / 2;
  // pilares
  const pillarMat = std('brick', 1, 4, { color: '#24242e' });
  const obstacles = [], globes = [], camColliders = [];
  for (let i = 0; i < 12; i++) {
    const a = i / 12 * Math.PI * 2 + Math.PI / 12, x = Math.cos(a) * (R + 1.2), z = Math.sin(a) * (R + 1.2);
    camColliders.push(mesh(new THREE.CylinderGeometry(0.75, 0.9, 14, 12), pillarMat, x, 7, z));
    mesh(new THREE.BoxGeometry(2.1, 0.5, 2.1), toon('#1a1a22'), x, 0.25, z);
    mesh(new THREE.BoxGeometry(2.0, 0.5, 2.0), toon('#1a1a22'), x, 13.8, z);
    const gl = mesh(new THREE.SphereGeometry(0.32, 16, 12), new THREE.MeshBasicMaterial({ color: new THREE.Color('#bfe0ff').multiplyScalar(2.5), toneMapped: false }), x * 0.93, 4.2, z * 0.93, null, { cast: false });
    glowSprite('#9ac8ff', 3, gl.position);
    globes.push(gl);
  }
  for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI * 2 + Math.PI / 4; const l = new THREE.PointLight('#a8c8ff', 16, 22, 1.5); l.position.set(Math.cos(a) * R * 0.85, 4.5, Math.sin(a) * R * 0.85); S.add(l); }
  // trono
  const dais = new THREE.Group(); dais.position.set(0, 0, R + 1.5); S.add(dais);
  for (let s = 0; s < 3; s++) mesh(new THREE.BoxGeometry(8 - s * 1.6, 0.35, 4 - s * 0.8), std('marble', 1, 1, { rough: 0.2, metal: 0.3 }), 0, 0.17 + s * 0.35, -s * 0.3, dais);
  const throne = new THREE.Group(); throne.position.set(0, 1.05, 0.6); dais.add(throne);
  mesh(new THREE.BoxGeometry(1.6, 0.6, 1.2), toon('#14243e'), 0, 0.3, 0, throne);
  camColliders.push(mesh(new THREE.BoxGeometry(1.8, 3.4, 0.3), toon('#0e1220'), 0, 1.7, 0.55, throne));
  mesh(new THREE.ConeGeometry(0.25, 0.8, 4), toon('#9a8040'), -0.7, 3.6, 0.55, throne); mesh(new THREE.ConeGeometry(0.25, 0.8, 4), toon('#9a8040'), 0.7, 3.6, 0.55, throne);
  mesh(new THREE.ConeGeometry(0.35, 1.1, 4), toon('#9a8040'), 0, 3.8, 0.55, throne);
  // estandartes azuis
  for (let i = 0; i < 8; i++) {
    const a = i / 8 * Math.PI * 2, x = Math.cos(a) * (R + 5.8), z = Math.sin(a) * (R + 5.8);
    const b = mesh(new THREE.PlaneGeometry(2.2, 6), new THREE.MeshStandardMaterial({ map: T.get('banner'), side: THREE.DoubleSide, transparent: true, alphaTest: 0.5, roughness: 0.9 }), x, 8, z, null, { cast: false });
    b.lookAt(0, 8, 0);
  }
  // estátua da justiça desequilibrada (relevo) atrás do trono
  const stat = new THREE.Group(); stat.position.set(0, 0, R + 5); S.add(stat);
  mesh(new THREE.CylinderGeometry(0.2, 0.25, 6, 8), toon('#3a3a44'), 0, 3, 0, stat);
  const beam = mesh(new THREE.BoxGeometry(4, 0.15, 0.15), toon('#3a3a44'), 0, 6, 0, stat); beam.rotation.z = 0.35;
  mesh(new THREE.CylinderGeometry(0.8, 0.5, 0.2, 12), toon('#3a3a44'), 1.8, 6.6, 0, stat);
  // correntes (Viktor)
  const chainPts = (a, b) => { const c = new THREE.CatmullRomCurve3([a, a.clone().lerp(b, 0.5).add(new V3(0, -0.4, 0)), b]); return mesh(new THREE.TubeGeometry(c, 16, 0.03, 4), new THREE.MeshStandardMaterial({ color: '#4a4a52', metalness: 0.8, roughness: 0.4 }), 0, 0, 0); };
  const chains = [chainPts(new V3(-3.5, 4.5, R - 0.3), new V3(-4.4, 2.2, R - 1.6)), chainPts(new V3(-5.4, 4.5, R - 0.3), new V3(-4.6, 2.2, R - 1.6))];
  const update = (dt, t) => {
    L.follow();
    for (const [i, g] of globes.entries()) g.scale.setScalar(1 + Math.sin(t * 2 + i) * 0.06);
    if (Math.random() < dt * 8) G.fx.burst('mote', new V3(0, 0, 0), { n: 1, r: R, color: '#a0c0ff', color2: '#304080' });
    if (Math.random() < dt * 3) G.fx.burst('smoke', new V3(rnd(-R, R), 0, rnd(-R, R)), { n: 1, r: 2, color: '#1a2030', color2: '#0a0e18', alpha: 0.18, size: 2 });
  };
  return {
    name: 'throne', bounds: { type: 'circle', r: R - 0.5, cx: 0, cz: 0 }, obstacles, surface: 'stone', ceiling: 15.5,
    spawn: { pos: new V3(0, 0, -10), yaw: 0 }, points: { throne: new V3(0, 0, R - 1.5), viktor: new V3(-4.5, 0, R - 1.8), calista: new V3(2.5, 0, R - 3.5), center: new V3(0, 0, 0) },
    chains, update, camExtra: 2.2, camColliders, map: { w: R * 2.4, h: R * 2.4, cx: 0, cz: 0 },
  };
}

// =====================================================================
//  O LIMBO
// =====================================================================
export function buildLimbo() {
  const S = G.scene;
  S.background = T.get('limboSky'); S.backgroundIntensity = 1; S.environment = null;
  S.fog = new THREE.FogExp2('#12020a', 0.04);
  const hemi = new THREE.HemisphereLight('#5a1020', '#000000', 0.8); S.add(hemi);
  const red = new THREE.PointLight('#ff2040', 30, 40, 1.4); red.position.set(0, 6, 12); S.add(red);
  // plataforma (o chão "não existe")
  const plat = mesh(new THREE.CylinderGeometry(6, 3, 2.5, 9, 2), new THREE.MeshStandardMaterial({ color: '#1a1014', roughness: 1, flatShading: true }), 0, -1.25, 0);
  const isl = [];
  for (let i = 0; i < 40; i++) {
    const m = mesh(new THREE.DodecahedronGeometry(rnd(0.5, 3), 0), new THREE.MeshStandardMaterial({ color: '#1a0e12', roughness: 1, flatShading: true, emissive: '#2a0008', emissiveIntensity: 0.4 }), rnd(-40, 40), rnd(-15, 20), rnd(-10, 60));
    m.userData.sp = rnd(0.05, 0.3); m.userData.ph = rnd(0, 6); isl.push(m);
  }
  // o "estômago" — coração pulsante do Limbo
  const heartMat = new THREE.MeshStandardMaterial({ color: '#100006', emissive: '#6a0010', emissiveIntensity: 1, roughness: 0.4, metalness: 0.2 });
  heartMat.onBeforeCompile = (s) => {
    s.uniforms.uTime = U.time;
    s.vertexShader = 'uniform float uTime;\n' + s.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * (sin(position.y*1.5+uTime*2.0)*0.4 + sin(position.x*2.0-uTime*1.3)*0.3);');
  };
  const heart = mesh(new THREE.IcosahedronGeometry(9, 4), heartMat, 0, 4, 34);
  const eye = mesh(new THREE.SphereGeometry(1.2, 16, 12), new THREE.MeshBasicMaterial({ color: new THREE.Color('#ff3050').multiplyScalar(3), toneMapped: false }), 0, 5, 25.5, null, { cast: false });
  const slit = new THREE.Mesh(new THREE.SphereGeometry(1.0, 12, 10), new THREE.MeshBasicMaterial({ color: '#000000' }));
  slit.scale.set(0.16, 0.95, 0.4); slit.position.z = -0.85; eye.add(slit);
  const halo = glowSprite('#ff2040', 9, new V3(0, 0, 0.2), eye); halo.material.opacity = 0.6;
  eye.visible = false;
  const update = (dt, t) => {
    const p = 1 + Math.sin(t * 1.3) * 0.04 + Math.max(0, Math.sin(t * 2.6)) * 0.03;
    heart.scale.setScalar(p); heartMat.emissiveIntensity = 0.8 + Math.sin(t * 2.6) * 0.4;
    red.intensity = 25 + Math.sin(t * 2.6) * 8;
    for (const m of isl) { m.position.y += Math.sin(t * m.userData.sp + m.userData.ph) * 0.004; m.rotation.y += dt * m.userData.sp * 0.3; }
    if (eye.visible) { eye.scale.y = 1 + Math.sin(t * 0.7) * 0.05; slit.scale.x = 0.12 + Math.max(0, Math.sin(t * 0.5)) * 0.1; }
    if (Math.random() < dt * 20) G.fx.burst('ember', new V3(0, -2, 10), { n: 1, r: 25, color: '#ff2040', color2: '#400010' });
  };
  return {
    name: 'limbo', bounds: { type: 'circle', r: 5.5, cx: 0, cz: 0 }, obstacles: [], surface: 'stone',
    spawn: { pos: new V3(0, 0, 0), yaw: 0 }, points: { heart: new V3(0, 4, 34) }, eye, update, map: { w: 12, h: 12, cx: 0, cz: 0 },
  };
}

export const LEVELS = { vardun: buildVardun, tavern: buildTavern, valley: buildValley, domain: buildDomain, throne: buildThrone, limbo: buildLimbo };
