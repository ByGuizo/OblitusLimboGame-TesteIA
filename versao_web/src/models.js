// =====================================================================
//  Modelos procedurais + esqueleto + animação por keyframes
// =====================================================================
import * as THREE from 'three';
import { T } from './textures.js';

export const U = { time: { value: 0 } };          // uniform de tempo compartilhado
const V2 = THREE.Vector2;

// ---------- materiais ----------
const grad = (() => {
  const d = new Uint8Array([55, 120, 190, 255]);
  const t = new THREE.DataTexture(d, 4, 1, THREE.RedFormat);
  t.minFilter = t.magFilter = THREE.NearestFilter; t.needsUpdate = true; return t;
})();
const matCache = new Map();
export function toon(color, o = {}) {
  const key = color + JSON.stringify(o, (k, v) => (v && v.isTexture ? v.uuid : v));
  if (!o.unique && matCache.has(key)) return matCache.get(key);
  const { unique, ...rest } = o;
  const m = new THREE.MeshToonMaterial({ color, gradientMap: grad, ...rest });
  if (!o.unique) matCache.set(key, m);
  return m;
}
export function glowMat(color, intensity = 2) {
  return new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), toneMapped: false });
}
const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x060509, side: THREE.BackSide });
OUTLINE.onBeforeCompile = (s) => {
  s.vertexShader = s.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * 0.012;');
};
const OUTLINE_THICK = new THREE.MeshBasicMaterial({ color: 0x060509, side: THREE.BackSide });
OUTLINE_THICK.onBeforeCompile = (s) => {
  s.vertexShader = s.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * 0.022;');
};

export function part(geo, mat, { outline = true, shadow = true, thick = false } = {}) {
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = shadow;
  if (outline) { const o = new THREE.Mesh(geo, thick ? OUTLINE_THICK : OUTLINE); o.raycast = () => {}; m.add(o); }
  return m;
}

// cápsula afunilada (lathe) — topo em y=0, base em y=-len
export function taper(len, r0, r1, seg = 12) {
  const pts = [], n = 5;
  for (let i = 0; i <= n; i++) { const a = -Math.PI / 2 + (i / n) * Math.PI / 2; pts.push(new V2(Math.max(0.0001, Math.cos(a) * r1), -len + Math.sin(a) * r1)); }
  for (let i = 0; i <= n; i++) { const a = (i / n) * Math.PI / 2; pts.push(new V2(Math.max(0.0001, Math.cos(a) * r0), Math.sin(a) * r0)); }
  return new THREE.LatheGeometry(pts, seg);
}
function lathe(profile, seg = 14) { return new THREE.LatheGeometry(profile.map(([r, y]) => new V2(Math.max(0.0001, r), y)), seg); }

// =====================================================================
//  ESQUELETO HUMANOIDE
// =====================================================================
export function makeRig(o = {}) {
  const s = o.scale ?? 1, b = o.bulk ?? 1, outline = o.outline ?? true;
  const M = (c, extra) => (typeof c === 'string' || typeof c === 'number') ? toon(c, extra) : c;
  const skin = M(o.skin ?? '#e0b896'), top = M(o.top ?? '#333'), pants = M(o.pants ?? '#2a2a2a');
  const boots = M(o.boots ?? '#3a2a1e'), gloves = M(o.gloves ?? o.skin ?? '#e0b896'), sleeve = M(o.sleeve ?? o.top ?? '#333');
  const P = (g, m, op) => part(g, m, { outline, ...op });

  const root = new THREE.Group(); root.name = 'rig';
  const inner = new THREE.Group(); inner.scale.setScalar(s); root.add(inner);
  const body = new THREE.Group(); body.position.y = 0.95; inner.add(body);
  const hips = new THREE.Group(); body.add(hips);
  const chest = new THREE.Group(); chest.position.y = 0.09; hips.add(chest);
  const neck = new THREE.Group(); neck.position.y = 0.47; chest.add(neck);
  const head = new THREE.Group(); head.position.y = 0.06; neck.add(head);

  // pelve
  const pelvis = P(new THREE.SphereGeometry(0.15 * b, 14, 10), pants); pelvis.scale.set(1, 0.8, 0.75); pelvis.position.y = 0.02; hips.add(pelvis);
  // tronco
  const torsoG = lathe([[0.0001, -0.02], [0.135 * b, 0.0], [0.125 * b, 0.12], [0.17 * b, 0.3], [0.165 * b, 0.4], [0.1 * b, 0.47], [0.0001, 0.48]]);
  const torso = P(torsoG, o.torsoMat ? M(o.torsoMat) : top); torso.scale.z = 0.68; chest.add(torso);
  const neckM = P(taper(0.08, 0.045, 0.05), skin); neckM.position.y = 0.06; neck.add(neckM);
  // cabeça
  const headM = P(new THREE.SphereGeometry(0.115, 20, 16), o.headMat ? M(o.headMat) : skin); headM.scale.set(0.92, 1.06, 0.98); headM.position.y = 0.11; head.add(headM);
  const jaw = P(new THREE.SphereGeometry(0.085, 14, 10), o.headMat ? M(o.headMat) : skin); jaw.scale.set(0.95, 0.75, 0.95); jaw.position.set(0, 0.04, 0.025); head.add(jaw);
  // olhos
  const eyeMat = o.eyeGlow ? glowMat(o.eyeGlow, 2.5) : toon(o.eyes ?? '#1a1410');
  const eyes = [];
  for (const sx of [-1, 1]) {
    const e = new THREE.Mesh(new THREE.SphereGeometry(0.019, 10, 8), eyeMat);
    e.scale.set(1.2, 0.8, 0.5); e.position.set(sx * 0.042, 0.115, 0.1); head.add(e); eyes.push(e);
    const brow = new THREE.Mesh(new THREE.BoxGeometry(0.045, 0.008, 0.01), toon('#151015'));
    brow.position.set(sx * 0.043, 0.145, 0.103); brow.rotation.z = sx * -0.18; head.add(brow);
  }
  // nariz e boca
  const nose = new THREE.Mesh(new THREE.ConeGeometry(0.012, 0.03, 4), o.headMat ? M(o.headMat) : skin);
  nose.position.set(0, 0.085, 0.118); nose.rotation.x = 1.9; head.add(nose);
  const mouth = new THREE.Mesh(new THREE.BoxGeometry(0.032, 0.005, 0.006), toon('#3a1a1a'));
  mouth.position.set(0, 0.045, 0.108); head.add(mouth);
  // orelhas
  if (o.ears === 'elf' || o.ears === 'orc') {
    const len = o.ears === 'elf' ? 0.11 : 0.06;
    for (const sx of [-1, 1]) {
      const ear = P(new THREE.ConeGeometry(0.025, len, 6), skin);
      ear.position.set(sx * 0.11, 0.12, -0.0); ear.rotation.z = sx * -1.25; ear.rotation.y = sx * 0.3; head.add(ear);
    }
  }

  // braços
  const arm = (sx) => {
    const sh = new THREE.Group(); sh.position.set(sx * 0.2 * b, 0.4, 0); chest.add(sh);
    const shoulderBall = P(new THREE.SphereGeometry(0.062 * b, 12, 10), sleeve); sh.add(shoulderBall);
    const up = P(taper(0.28, 0.058 * b, 0.046 * b), sleeve); sh.add(up);
    const el = new THREE.Group(); el.position.y = -0.28; sh.add(el);
    const lo = P(taper(0.25, 0.046 * b, 0.036 * b), o.forearm ? M(o.forearm) : (o.bareArms ? skin : sleeve)); el.add(lo);
    if (o.gloves) { const gl = P(taper(0.1, 0.044 * b, 0.04 * b), gloves); gl.position.y = -0.15; el.add(gl); }
    const hand = new THREE.Group(); hand.position.y = -0.27; el.add(hand);
    const hm = P(new THREE.SphereGeometry(0.042 * b, 10, 8), gloves); hm.scale.set(0.9, 1.15, 0.7); hand.add(hm);
    return { sh, el, hand };
  };
  const L = arm(1), R = arm(-1);
  // pernas
  const leg = (sx) => {
    const hp = new THREE.Group(); hp.position.set(sx * 0.095 * b, -0.02, 0); hips.add(hp);
    const th = P(taper(0.45, 0.085 * b, 0.06 * b), pants); hp.add(th);
    const kn = new THREE.Group(); kn.position.y = -0.45; hp.add(kn);
    const sh = P(taper(0.42, 0.06 * b, 0.045 * b), pants); kn.add(sh);
    const bt = P(taper(0.24, 0.062 * b, 0.055 * b), boots); bt.position.y = -0.2; kn.add(bt);
    const foot = P(new THREE.BoxGeometry(0.1 * b, 0.07, 0.2 * b), boots); foot.position.set(0, -0.455, 0.045); kn.add(foot);
    if (o.bootTrim) { const tr = P(new THREE.TorusGeometry(0.066 * b, 0.022, 6, 12), M(o.bootTrim)); tr.rotation.x = Math.PI / 2; tr.position.y = -0.2; kn.add(tr); }
    return { hp, kn };
  };
  const LL = leg(1), RL = leg(-1);

  const joints = {
    body, hips, chest, neck, head,
    shL: L.sh, elL: L.el, shR: R.sh, elR: R.el,
    hipL: LL.hp, knL: LL.kn, hipR: RL.hp, knR: RL.kn,
  };
  const rig = {
    root, inner, joints, scale: s, bulk: b, eyes,
    handR: R.hand, handL: L.hand, mats: { skin, top, pants, boots },
    height: 1.82 * s, cloth: [],
  };
  return rig;
}

// ---------- acessórios ----------
function spikyHair(head, color, { count = 22, len = 0.16, long = 0, fringe = true, spread = 1 } = {}) {
  const mat = toon(color);
  const g = new THREE.Group(); g.position.y = 0.12; head.add(g);
  const cap = part(new THREE.SphereGeometry(0.125, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.6), mat); cap.position.set(0, 0.005, -0.012); cap.rotation.x = -0.5; cap.scale.set(1, 1.05, 1.05); g.add(cap);
  let sd = 7;
  const r = () => { sd = (sd * 16807) % 2147483647; return sd / 2147483647; };
  for (let i = 0; i < count; i++) {
    const az = r() * Math.PI * 2, el = 0.15 + r() * 1.1;
    const front = Math.cos(az) > 0.55;                 // evita cobrir o rosto
    if (front && el < 0.9) continue;
    const L = len * (0.7 + r() * 0.7) * (front ? 0.7 : 1);
    const c = part(new THREE.ConeGeometry(0.035 + r() * 0.02, L, 5), mat);
    const dir = new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el) * 0.9 + 0.1, -Math.cos(az) * Math.cos(el) * spread);
    dir.z = -Math.abs(dir.z) * (front ? -1 : 1);
    dir.normalize();
    c.position.copy(dir).multiplyScalar(0.1);
    c.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().add(new THREE.Vector3(0, -0.35, 0)).normalize());
    c.position.addScaledVector(dir, L * 0.4);
    g.add(c);
  }
  if (fringe) for (let i = 0; i < 5; i++) {
    const c = part(new THREE.ConeGeometry(0.03, 0.085 + (i % 2) * 0.025, 5), mat);
    c.position.set((i - 2) * 0.035, 0.06, 0.105); c.rotation.x = Math.PI + 0.55; c.rotation.z = (i - 2) * 0.2; g.add(c);
  }
  for (let i = 0; i < long; i++) {
    const t = (i - (long - 1) / 2) / Math.max(1, (long - 1) / 2);
    const L = 0.22 + (i % 2) * 0.07;
    const c = part(new THREE.ConeGeometry(0.03, L, 5), mat);
    c.rotation.x = Math.PI + 0.32; c.rotation.z = t * 0.45;
    c.position.set(t * 0.085 + Math.sin(t * 0.45) * L * 0.4, -0.03 - L * 0.42, -0.085 - L * 0.12);
    g.add(c);
  }
  return g;
}
function longHair(head, color, { len = 0.5, ponytail = false, wavy = false } = {}) {
  const mat = toon(color);
  const g = new THREE.Group(); g.position.y = 0.12; head.add(g);
  const cap = part(new THREE.SphereGeometry(0.128, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.62), mat); cap.position.set(0, 0.005, -0.012); cap.rotation.x = -0.5; cap.scale.set(1, 1.05, 1.08); g.add(cap);
  if (ponytail) {
    const tie = part(new THREE.SphereGeometry(0.035, 8, 6), mat); tie.position.set(0, 0.06, -0.12); g.add(tie);
    const tail = part(taper(len, 0.05, 0.015, 8), mat); tail.position.set(0, 0.06, -0.13); tail.rotation.x = 0.35; g.add(tail);
    g.userData.tail = tail;
  } else {
    for (let i = 0; i < 9; i++) {
      const a = (i / 8 - 0.5) * 2.6;
      const strand = part(taper(len * (0.85 + (i % 3) * 0.1), 0.05, 0.02, 6), mat);
      strand.position.set(Math.sin(a) * 0.11, 0.02, -Math.cos(a) * 0.1 - 0.01);
      strand.rotation.x = 0.12 + (wavy ? Math.sin(i) * 0.08 : 0); strand.rotation.z = Math.sin(a) * 0.15; g.add(strand);
    }
  }
  for (let i = 0; i < 4; i++) { // franja
    const c = part(new THREE.ConeGeometry(0.035, 0.09, 5), mat);
    c.position.set((i - 1.5) * 0.045, 0.06, 0.105); c.rotation.x = Math.PI + 0.5; c.rotation.z = (i - 1.5) * 0.28; g.add(c);
  }
  return g;
}
function cloak(rig, color, { width = 0.46, length = 1.0, hood = 'down', hoodColor } = {}) {
  const tex = T.get('cloak');
  const mat = new THREE.MeshToonMaterial({ color, gradientMap: grad, map: tex, alphaTest: 0.5, side: THREE.DoubleSide });
  const segW = 6, segH = 12;
  const geo = new THREE.PlaneGeometry(width, length, segW, segH);
  geo.translate(0, -length / 2, 0);
  const base = geo.attributes.position.array.slice();
  const m = new THREE.Mesh(geo, mat); m.castShadow = true;
  m.position.set(0, 0.42, -0.12);
  rig.joints.chest.add(m);
  // colarinho / capuz
  const collar = part(new THREE.TorusGeometry(0.13, 0.05, 8, 16, Math.PI * 1.5), toon(hoodColor || color));
  collar.rotation.x = Math.PI / 2; collar.rotation.z = Math.PI * 0.75 + Math.PI; collar.position.set(0, 0.44, -0.01); collar.scale.set(1.15, 1, 1);
  rig.joints.chest.add(collar);
  if (hood === 'up') {
    const h = part(new THREE.SphereGeometry(0.15, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.62), toon(hoodColor || color, { side: THREE.DoubleSide }));
    h.scale.set(1.05, 1.15, 1.15); h.position.set(0, 0.12, -0.02); h.rotation.x = -0.25;
    rig.joints.head.add(h);
    const tip = part(new THREE.ConeGeometry(0.07, 0.16, 8), toon(hoodColor || color)); tip.position.set(0, 0.2, -0.14); tip.rotation.x = -1.0; rig.joints.head.add(tip);
  }
  rig.cloth.push({ mesh: m, base, length, width, flap: Math.random() * 10 });
  return m;
}
export function updateCloth(rig, dt, speed, t) {
  for (const c of rig.cloth) {
    const pos = c.mesh.geometry.attributes.position, a = pos.array, b = c.base;
    const sp = Math.min(speed, 9);
    for (let i = 0; i < a.length; i += 3) {
      const y = Math.max(0, -b[i + 1] / c.length);  // 0 topo, 1 barra
      const x = b[i] / c.width;
      const back = Math.pow(y, 1.4) * (0.1 + sp * 0.09) + Math.sin(t * (4 + sp) + y * 4 + x * 3 + c.flap) * 0.025 * y * (1 + sp * 0.3);
      a[i] = b[i] * (1 + y * 0.35) + Math.sin(t * 2.3 + y * 3 + c.flap) * 0.02 * y;
      a[i + 1] = b[i + 1] + back * 0.35 * Math.min(1, sp / 6);
      a[i + 2] = b[i + 2] - back - Math.abs(x) * 0.05 * y;
    }
    pos.needsUpdate = true;
    c.mesh.geometry.computeVertexNormals();
  }
}

// ---------- armas ----------
export function weapon(kind, opts = {}) {
  const g = new THREE.Group();
  const metal = toon('#b8c0cc'), dark = toon('#2b2420'), wood = toon('#5a3a22'), gold = toon('#b08a3a');
  if (kind === 'kaelDagger') {
    const blade = part(new THREE.CylinderGeometry(0.004, 0.026, 0.34, 4), toon('#cfe6ff', { emissive: new THREE.Color('#1b4a70'), emissiveIntensity: 0.6 }));
    blade.scale.z = 0.35; blade.position.y = 0.21; g.add(blade);
    const rune = new THREE.Mesh(new THREE.BoxGeometry(0.006, 0.26, 0.012), glowMat('#6fdcff', 2.2)); rune.position.y = 0.2; g.add(rune);
    g.userData.glow = rune;
    const guard = part(new THREE.BoxGeometry(0.11, 0.022, 0.03), toon('#8aa4c0')); guard.position.y = 0.04; g.add(guard);
    for (const sx of [-1, 1]) { const sp = part(new THREE.ConeGeometry(0.012, 0.05, 4), toon('#bfe8ff')); sp.position.set(sx * 0.065, 0.055, 0); sp.rotation.z = sx * -0.9; g.add(sp); }
    const grip = part(new THREE.CylinderGeometry(0.016, 0.016, 0.1, 6), dark); grip.position.y = -0.02; g.add(grip);
    const pom = part(new THREE.OctahedronGeometry(0.022), toon('#9fd8ff', { emissive: new THREE.Color('#2a6a9a') })); pom.position.y = -0.08; g.add(pom);
  } else if (kind === 'dagger') {
    const blade = part(new THREE.CylinderGeometry(0.003, 0.02, 0.26, 4), metal); blade.scale.z = 0.35; blade.position.y = 0.16; g.add(blade);
    const grip = part(new THREE.CylinderGeometry(0.014, 0.014, 0.09, 6), dark); g.add(grip);
    const guard = part(new THREE.BoxGeometry(0.07, 0.015, 0.02), gold); guard.position.y = 0.04; g.add(guard);
  } else if (kind === 'sword') {
    const blade = part(new THREE.BoxGeometry(0.05, 0.75, 0.012), metal); blade.position.y = 0.45; g.add(blade);
    const tip = part(new THREE.ConeGeometry(0.035, 0.1, 4), metal); tip.scale.z = 0.3; tip.position.y = 0.87; g.add(tip);
    const guard = part(new THREE.BoxGeometry(0.18, 0.03, 0.04), dark); guard.position.y = 0.07; g.add(guard);
    const grip = part(new THREE.CylinderGeometry(0.018, 0.018, 0.14, 6), wood); g.add(grip);
  } else if (kind === 'club') {
    const c = part(taper(0.7, 0.03, 0.07, 8), wood); c.rotation.x = Math.PI; c.position.y = -0.05; g.add(c);
    for (let i = 0; i < 5; i++) { const n = part(new THREE.ConeGeometry(0.015, 0.05, 4), metal); n.position.set(Math.cos(i * 1.3) * 0.06, 0.45 + i * 0.04, Math.sin(i * 1.3) * 0.06); n.rotation.z = Math.cos(i * 1.3) * -1.4; n.rotation.x = Math.sin(i * 1.3) * 1.4; g.add(n); }
  } else if (kind === 'axe') {
    const h = part(new THREE.CylinderGeometry(0.018, 0.02, 0.8, 6), wood); h.position.y = 0.3; g.add(h);
    const head = part(new THREE.CylinderGeometry(0.14, 0.14, 0.02, 3, 1, false, 0, Math.PI), metal); head.rotation.z = Math.PI / 2; head.position.set(0.03, 0.62, 0); g.add(head);
  } else if (kind === 'cleaver') {
    const h = part(new THREE.CylinderGeometry(0.03, 0.035, 0.32, 6), dark); g.add(h);
    const blade = part(new THREE.BoxGeometry(0.26, 0.95, 0.025), toon('#7a7f86')); blade.position.set(0.06, 0.62, 0); g.add(blade);
    const edge = part(new THREE.BoxGeometry(0.03, 0.95, 0.012), toon('#d0d5dc')); edge.position.set(0.19, 0.62, 0); g.add(edge);
    const rust = part(new THREE.BoxGeometry(0.1, 0.3, 0.027), toon('#5b1d14')); rust.position.set(0.0, 0.85, 0); g.add(rust);
  } else if (kind === 'bow') {
    const curve = new THREE.QuadraticBezierCurve3(new THREE.Vector3(0, -0.6, 0), new THREE.Vector3(0, 0, opts.recurve ? 0.25 : 0.32), new THREE.Vector3(0, 0.6, 0));
    const limb = part(new THREE.TubeGeometry(curve, 16, 0.017, 6), toon(opts.color || '#6b4a2e')); g.add(limb);
    const str = new THREE.Mesh(new THREE.CylinderGeometry(0.002, 0.002, 1.2, 3), opts.stringGlow ? glowMat(opts.stringGlow, 2) : toon('#ddd'));
    g.add(str); g.userData.string = str;
    const grip = part(new THREE.CylinderGeometry(0.022, 0.022, 0.14, 6), toon('#d8cfb0')); grip.position.z = 0.2; g.add(grip);
    g.rotation.x = 0;
  } else if (kind === 'crossbow') {
    const stock = part(new THREE.BoxGeometry(0.05, 0.05, 0.55), wood); stock.position.z = 0.2; g.add(stock);
    const bowc = part(new THREE.TorusGeometry(0.25, 0.012, 4, 12, Math.PI), dark); bowc.position.z = 0.42; bowc.rotation.x = Math.PI / 2; bowc.rotation.z = Math.PI; g.add(bowc);
    g.rotation.x = -Math.PI / 2;
  } else if (kind === 'katana') {
    const blade = part(new THREE.BoxGeometry(0.03, 0.8, 0.008), metal); blade.position.y = 0.5; blade.rotation.z = 0.03; g.add(blade);
    const tsuba = part(new THREE.CylinderGeometry(0.04, 0.04, 0.012, 10), gold); tsuba.position.y = 0.09; g.add(tsuba);
    const grip = part(new THREE.CylinderGeometry(0.016, 0.016, 0.2, 6), toon('#202020')); g.add(grip);
  } else if (kind === 'ukulele') {
    const w = toon('#8a5a32'), w2 = toon('#5e3a1e');
    const b1 = part(new THREE.SphereGeometry(0.1, 14, 10), w); b1.scale.set(1, 1, 0.35); g.add(b1);
    const b2 = part(new THREE.SphereGeometry(0.08, 14, 10), w); b2.scale.set(1, 1, 0.35); b2.position.y = 0.12; g.add(b2);
    const hole = new THREE.Mesh(new THREE.CircleGeometry(0.03, 12), toon('#1a0f08')); hole.position.set(0, 0.07, 0.036); g.add(hole);
    const neckU = part(new THREE.BoxGeometry(0.035, 0.28, 0.025), w2); neckU.position.y = 0.32; g.add(neckU);
    const headU = part(new THREE.BoxGeometry(0.05, 0.08, 0.025), w2); headU.position.y = 0.49; g.add(headU);
    const strings = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.42, 0.002), glowMat('#e8e0c0', 1)); strings.position.set(0, 0.24, 0.04); g.add(strings);
    g.userData.strings = strings;
  }
  return g;
}

// =====================================================================
//  PERSONAGENS
// =====================================================================
export function buildCharacter(id, opt = {}) {
  let rig;
  switch (id) {
    case 'kiana': {
      rig = makeRig({ scale: 0.93, bulk: 1.0, skin: '#6f8c3e', top: '#1c1a21', pants: '#23202a', boots: '#4a3020', gloves: '#2a2228', sleeve: '#1c1a21', eyeGlow: '#ff2a1a', ears: 'orc', bootTrim: '#e8e4dc' });
      spikyHair(rig.joints.head, '#eef0f5', { count: 30, len: 0.2, long: 5 });
      // gibão de couro + cinto
      const belt = part(new THREE.TorusGeometry(0.14, 0.022, 6, 16), toon('#4a2e1c')); belt.rotation.x = Math.PI / 2; belt.position.y = 0.04; belt.scale.z = 0.75; rig.joints.hips.add(belt);
      const tunic = part(lathe([[0.15, 0.02], [0.2, -0.22], [0.0001, -0.22]]), toon('#2c2a52')); tunic.scale.z = 0.8; rig.joints.hips.add(tunic);
      cloak(rig, '#16141a', { width: 0.5, length: 1.02, hood: 'down' });
      const dag = weapon('kaelDagger'); dag.rotation.x = Math.PI / 2; dag.position.set(0, -0.02, 0.02); rig.handR.add(dag); rig.weapon = dag;
      const uku = weapon('ukulele'); uku.position.set(0.05, 0.12, -0.2); uku.rotation.set(0.1, Math.PI, 0.5); rig.joints.chest.add(uku); rig.ukulele = uku;
      rig.ukuleleBack = { pos: uku.position.clone(), rot: uku.rotation.clone() };
      break;
    }
    case 'near': {
      rig = makeRig({ scale: 0.97, bulk: 0.95, skin: '#e9cfb2', top: '#1a1a1e', pants: '#1e1e22', boots: '#191515', gloves: '#141414', eyes: '#d89a2a', ears: 'elf' });
      spikyHair(rig.joints.head, '#d8dbe4', { count: 18, len: 0.14 });
      const mask = part(new THREE.SphereGeometry(0.1, 14, 10, 0, Math.PI * 2, Math.PI * 0.5, Math.PI * 0.32), toon('#141824')); mask.position.set(0, 0.11, 0.018); mask.scale.set(1.0, 1.1, 1.05); rig.joints.head.add(mask);
      const scarf = part(new THREE.TorusGeometry(0.1, 0.04, 8, 16), toon('#5d2a86')); scarf.rotation.x = Math.PI / 2; scarf.position.y = 0.48; rig.joints.chest.add(scarf);
      for (const sx of [-1, 1]) { const tail = part(new THREE.BoxGeometry(0.06, 0.35, 0.01), toon('#5d2a86')); tail.position.set(sx * 0.05, 0.32, -0.15); tail.rotation.x = 0.5; rig.joints.chest.add(tail); }
      const pad = part(new THREE.SphereGeometry(0.08, 10, 8, 0, Math.PI * 2, 0, Math.PI / 2), toon('#9a7a3a')); pad.position.y = 0.02; rig.joints.shL.add(pad);
      cloak(rig, '#121216', { width: 0.44, length: 0.8, hood: 'up' });
      const d1 = weapon('dagger'); d1.rotation.x = Math.PI / 2; rig.handR.add(d1); rig.weapon = d1;
      const d2 = weapon('dagger'); d2.rotation.x = -Math.PI / 2; rig.handL.add(d2);
      break;
    }
    case 'amnon': {
      rig = makeRig({ scale: 1.0, bulk: 1.05, skin: '#a8302a', top: '#e8e4dc', pants: '#2a3550', boots: '#3a2a1e', sleeve: '#e8e4dc', eyes: '#d8d8e0', ears: 'elf' });
      const hair = spikyHair(rig.joints.head, '#141016', { count: 26, len: 0.2, long: 4 });
      const lock = part(new THREE.ConeGeometry(0.04, 0.18, 5), toon('#f2f0ec')); lock.position.set(0.02, 0.04, 0.1); lock.rotation.x = Math.PI + 0.35; hair.add(lock);
      for (const sx of [-1, 1]) {
        const horn = part(new THREE.TorusGeometry(0.07, 0.022, 6, 10, Math.PI * 1.1), toon('#3a2848'));
        horn.position.set(sx * 0.085, 0.2, -0.02); horn.rotation.set(0, sx * 1.4, sx * 0.6); rig.joints.head.add(horn);
      }
      const vest = part(lathe([[0.0001, 0.0], [0.15, 0.02], [0.18, 0.3], [0.17, 0.4], [0.0001, 0.42]]), toon('#3a5a8a')); vest.scale.z = 0.72; rig.joints.chest.add(vest);
      const trim = part(new THREE.BoxGeometry(0.02, 0.38, 0.02), toon('#c8a050')); trim.position.set(0.04, 0.22, 0.125); rig.joints.chest.add(trim);
      const bow = weapon('bow'); bow.position.set(0, -0.02, 0); rig.handL.add(bow); rig.weapon = bow;
      break;
    }
    case 'darin': {
      rig = makeRig({ scale: 1.0, bulk: 1.15, skin: '#d9a77c', top: '#d9a77c', pants: '#3a4a2a', boots: '#3a2a1a', bareArms: true, sleeve: '#d9a77c', eyes: '#1f8a5a' });
      spikyHair(rig.joints.head, '#4a2c1a', { count: 30, len: 0.17 });
      for (const sx of [-1, 1]) {
        const a = new THREE.Group(); a.position.set(sx * 0.07, 0.24, -0.02); rig.joints.head.add(a);
        const main = part(taper(0.22, 0.016, 0.01, 5), toon('#4a3020')); main.rotation.z = sx * 2.6; a.add(main);
        const br = part(taper(0.1, 0.012, 0.006, 5), toon('#4a3020')); br.position.set(sx * 0.06, 0.08, 0); br.rotation.z = sx * 2.2; a.add(br);
        const br2 = part(taper(0.08, 0.01, 0.005, 5), toon('#4a3020')); br2.position.set(sx * 0.12, 0.15, 0); br2.rotation.z = sx * 3.0; a.add(br2);
      }
      const fl = new THREE.Mesh(new THREE.CircleGeometry(0.035, 6), toon('#f4f0ea', { side: THREE.DoubleSide })); fl.position.set(0.08, 0.22, 0.05); fl.rotation.y = 0.6; rig.joints.head.add(fl);
      const belt = part(new THREE.TorusGeometry(0.15, 0.025, 6, 16), toon('#5a3a1a')); belt.rotation.x = Math.PI / 2; belt.position.y = 0.03; belt.scale.z = 0.75; rig.joints.hips.add(belt);
      // garras espirituais de lobo
      rig.claws = [];
      for (const hand of [rig.handL, rig.handR]) {
        const cg = new THREE.Group(); hand.add(cg);
        const gm = new THREE.MeshBasicMaterial({ color: new THREE.Color('#38ffb0').multiplyScalar(1.6), transparent: true, opacity: 0.55, toneMapped: false, depthWrite: false });
        const gaunt = new THREE.Mesh(new THREE.SphereGeometry(0.075, 10, 8), gm); gaunt.scale.set(1, 1.5, 0.9); cg.add(gaunt);
        for (let k = 0; k < 4; k++) { const cl = new THREE.Mesh(new THREE.ConeGeometry(0.014, 0.2, 4), gm); cl.position.set((k - 1.5) * 0.026, -0.15, 0.03); cl.rotation.x = Math.PI - 0.3; cg.add(cl); }
        cg.visible = !!opt.claws; rig.claws.push(cg);
      }
      break;
    }
    case 'calista': {
      rig = makeRig({ scale: 0.97, bulk: 0.95, skin: '#f0d0b4', top: '#2a2420', pants: '#2c241e', boots: '#3a2a20', gloves: '#5a3a24', sleeve: '#3a302a', eyes: '#3b3a30' });
      longHair(rig.joints.head, '#e8641c', { len: 0.42, ponytail: opt.ponytail, wavy: true });
      const armor = part(lathe([[0.0001, 0.12], [0.16, 0.14], [0.18, 0.3], [0.165, 0.4], [0.0001, 0.41]]), toon('#8c949e', { emissive: new THREE.Color('#111') })); armor.scale.z = 0.72; rig.joints.chest.add(armor);
      cloak(rig, '#111014', { width: 0.5, length: 1.05, hood: opt.hood ? 'up' : 'down' });
      const bow = weapon('bow', { color: '#d8d0c8', stringGlow: '#ff2030', recurve: true }); rig.handL.add(bow); rig.weapon = bow;
      break;
    }
    case 'viktor': {
      rig = makeRig({ scale: 1.03, bulk: 1.05, skin: '#efd9c6', top: '#efd9c6', pants: '#23324e', boots: '#cfc2a8', gloves: '#1e2638', sleeve: '#e8e0d4', eyes: '#3a4a5a', ears: 'elf', forearm: '#e8e0d4' });
      spikyHair(rig.joints.head, '#e6e9f0', { count: 22, len: 0.15 });
      const wrap = part(lathe([[0.135, 0.14], [0.15, 0.3], [0.0001, 0.3]]), toon('#e8e2d6')); wrap.scale.z = 0.7; rig.joints.chest.add(wrap);
      const sash = part(lathe([[0.15, 0.06], [0.2, -0.32], [0.0001, -0.32]]), toon('#9a2a22')); sash.scale.z = 0.5; sash.position.z = 0.02; rig.joints.hips.add(sash);
      const belt = part(new THREE.TorusGeometry(0.145, 0.03, 6, 16), toon('#6a5a3a')); belt.rotation.x = Math.PI / 2; belt.position.y = 0.05; belt.scale.z = 0.75; rig.joints.hips.add(belt);
      cloak(rig, '#ece8e2', { width: 0.6, length: 1.1, hood: 'down', hoodColor: '#24365a' });
      const brooch = part(new THREE.SphereGeometry(0.03, 8, 8), toon('#9a2a22')); brooch.position.set(0, 0.42, 0.12); rig.joints.chest.add(brooch);
      break;
    }
    case 'krauser': {
      const faceTex = (() => {
        const c = document.createElement('canvas'); c.width = 256; c.height = 128; const g = c.getContext('2d');
        g.fillStyle = '#e8cfb8'; g.fillRect(0, 0, 256, 128);
        const sc = T.get('scales').image; g.drawImage(sc, 64, 0, 128, 128);
        const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
      })();
      rig = makeRig({ scale: 1.1, bulk: 1.1, skin: '#e8cfb8', headMat: toon('#ffffff', { map: faceTex }), top: '#4a3424', pants: '#1e1a1e', boots: '#1a1418', gloves: '#1c2230', sleeve: '#22305a', eyes: '#1a1210' });
      rig.eyes[1].material = glowMat('#ffcc22', 2.5);  // olho reptiliano
      longHair(rig.joints.head, '#0a0a0e', { len: 0.62 });
      const pad = part(new THREE.SphereGeometry(0.11, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), toon('#7a828e')); pad.position.y = 0.03; rig.joints.shR.add(pad);
      const scalesArm = part(taper(0.27, 0.06, 0.05), toon('#ffffff', { map: T.get('scales') })); rig.joints.shL.add(scalesArm);
      cloak(rig, '#14244e', { width: 0.6, length: 1.15, hood: 'down', hoodColor: '#14244e' });
      const crystal = new THREE.Mesh(new THREE.OctahedronGeometry(0.035), glowMat('#ff1030', 2)); crystal.position.set(0, 0.36, 0.13); rig.joints.chest.add(crystal); rig.crystal = crystal;
      break;
    }
    case 'darius': {
      rig = makeRig({ scale: 1.32, bulk: 1.5, skin: toon('#ffffff', { map: T.get('tattoo') }), top: toon('#ffffff', { map: T.get('tattoo') }), pants: '#3a2a20', boots: '#2a1e16', bareArms: true, sleeve: toon('#ffffff', { map: T.get('tattoo') }), eyes: '#d8c040', ears: 'orc' });
      for (const sx of [-1, 1]) { const tusk = part(new THREE.ConeGeometry(0.014, 0.06, 5), toon('#e8e0c8')); tusk.position.set(sx * 0.035, 0.03, 0.09); rig.joints.head.add(tusk); }
      const knot = part(new THREE.SphereGeometry(0.04, 8, 6), toon('#141414')); knot.position.set(0, 0.24, -0.06); rig.joints.head.add(knot);
      const tail = part(taper(0.25, 0.03, 0.01, 6), toon('#141414')); tail.position.set(0, 0.24, -0.08); tail.rotation.x = 0.6; rig.joints.head.add(tail);
      for (const sh of [rig.joints.shL, rig.joints.shR]) {
        const pd = part(new THREE.SphereGeometry(0.1, 10, 8, 0, Math.PI * 2, 0, Math.PI / 2), toon('#4a3626')); pd.position.y = 0.02; sh.add(pd);
        for (let k = 0; k < 3; k++) { const sp = part(new THREE.ConeGeometry(0.015, 0.07, 4), toon('#9a9a9a')); sp.position.set((k - 1) * 0.05, 0.1, 0); sh.add(sp); }
      }
      const harness = part(new THREE.TorusGeometry(0.2, 0.02, 4, 16), toon('#3a2618')); harness.position.set(0, 0.25, 0); harness.rotation.set(0.2, 0, 0.8); harness.scale.z = 0.6; rig.joints.chest.add(harness);
      const w = weapon('cleaver'); w.rotation.x = Math.PI / 2; rig.handR.add(w); rig.weapon = w;
      break;
    }
    case 'thug': {
      const skins = ['#e0b896', '#c99a74', '#a8784e', '#f0cdb0', '#8a6040'];
      const leathers = ['#4a3424', '#3a2c22', '#5a4030', '#2e2a26', '#4a2a22'];
      const r = opt.seed ?? Math.floor(Math.random() * 1000);
      rig = makeRig({ scale: 0.98 + (r % 5) * 0.03, bulk: 1.05 + (r % 3) * 0.1, skin: skins[r % 5], top: leathers[r % 5], pants: '#2a2622', boots: '#1e1814', sleeve: leathers[(r + 2) % 5], eyes: '#1a1410' });
      if (r % 3 === 0) { const hood = part(new THREE.SphereGeometry(0.14, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.6), toon('#2a2420')); hood.position.y = 0.12; hood.scale.set(1, 1.1, 1.1); rig.joints.head.add(hood); }
      else if (r % 3 === 1) { const band = part(new THREE.TorusGeometry(0.115, 0.02, 6, 14), toon('#7a1a1a')); band.position.y = 0.17; band.rotation.x = Math.PI / 2; rig.joints.head.add(band); spikyHair(rig.joints.head, '#2a1a10', { count: 10, len: 0.08, fringe: false }); }
      else { spikyHair(rig.joints.head, '#3a2a1a', { count: 12, len: 0.09 }); const beard = part(new THREE.SphereGeometry(0.07, 8, 6), toon('#3a2a1a')); beard.position.set(0, 0.02, 0.06); beard.scale.set(1, 1.1, 0.6); rig.joints.head.add(beard); }
      const pad = part(new THREE.SphereGeometry(0.075, 10, 8, 0, Math.PI * 2, 0, Math.PI / 2), toon('#5a5a5e')); pad.position.y = 0.02; rig.joints.shR.add(pad);
      const kind = opt.weapon || ['sword', 'club', 'axe'][r % 3];
      const w = weapon(kind); w.rotation.x = Math.PI / 2; if (kind === 'crossbow') { w.rotation.set(0, 0, 0); } rig.handR.add(w); rig.weapon = w;
      break;
    }
    case 'mira': {
      rig = makeRig({ scale: 0.8, bulk: 0.9, skin: '#d8b49a', top: '#4a3a52', pants: '#3a2e40', boots: '#2a2020', sleeve: '#4a3a52', eyes: '#2a2a2a' });
      const bun = part(new THREE.SphereGeometry(0.13, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.6), toon('#b8b8c0')); bun.position.y = 0.12; rig.joints.head.add(bun);
      const b2 = part(new THREE.SphereGeometry(0.06, 8, 8), toon('#b8b8c0')); b2.position.set(0, 0.2, -0.1); rig.joints.head.add(b2);
      const patch = part(new THREE.CircleGeometry(0.03, 10), toon('#1a1a1a')); patch.position.set(-0.042, 0.115, 0.108); rig.joints.head.add(patch);
      const shawl = part(new THREE.TorusGeometry(0.15, 0.05, 6, 16), toon('#6a2a3a')); shawl.rotation.x = Math.PI / 2; shawl.position.y = 0.42; rig.joints.chest.add(shawl);
      const skirt = part(lathe([[0.15, 0.03], [0.26, -0.8], [0.0001, -0.8]]), toon('#3a2e40')); rig.joints.hips.add(skirt);
      const cane = part(new THREE.CylinderGeometry(0.015, 0.015, 0.9, 6), toon('#4a3020')); cane.position.y = -0.38; rig.handR.add(cane);
      rig.joints.chest.rotation.x = 0.35;
      break;
    }
    case 'rurik': {
      rig = makeRig({ scale: 1.18, bulk: 1.45, skin: '#d8a888', top: '#5a4632', pants: '#2e2620', boots: '#2a1e16', sleeve: '#7a6650', eyes: '#2a2a2a' });
      const hair = part(new THREE.SphereGeometry(0.125, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.55), toon('#8a8478')); hair.position.y = 0.12; rig.joints.head.add(hair);
      const beard = part(lathe([[0.08, 0.06], [0.1, 0], [0.06, -0.12], [0.0001, -0.16]]), toon('#7a7468')); beard.position.set(0, 0.05, 0.055); beard.scale.z = 0.7; rig.joints.head.add(beard);
      const apron = part(new THREE.BoxGeometry(0.3, 0.6, 0.02), toon('#a89a80')); apron.position.set(0, -0.1, 0.15); rig.joints.hips.add(apron);
      break;
    }
    case 'townsfolk': {
      const r = opt.seed ?? Math.floor(Math.random() * 1000);
      const cols = ['#5a4a6a', '#6a4a3a', '#3a5a4a', '#7a6a4a', '#4a4a5a', '#6a3a3a'];
      rig = makeRig({ scale: 0.92 + (r % 4) * 0.04, bulk: 1 + (r % 3) * 0.08, skin: ['#e0b896', '#c99a74', '#f0cdb0', '#a8784e'][r % 4], top: cols[r % 6], pants: cols[(r + 3) % 6], boots: '#2a2018', sleeve: cols[r % 6] });
      if (r % 2) longHair(rig.joints.head, ['#3a2a1a', '#8a6a3a', '#1a1a1a'][r % 3], { len: 0.3 });
      else spikyHair(rig.joints.head, ['#3a2a1a', '#6a4a2a', '#1a1a1a'][r % 3], { count: 12, len: 0.08 });
      if (r % 3 === 0) cloak(rig, cols[(r + 1) % 6], { width: 0.42, length: 0.85 });
      break;
    }
    case 'shadow': {
      const sm = new THREE.MeshBasicMaterial({ color: '#030205' });
      rig = makeRig({ scale: opt.giant ? 2.1 : 1.05, bulk: opt.giant ? 1.3 : 0.95, skin: sm, top: sm, pants: sm, boots: sm, gloves: sm, sleeve: sm, eyes: '#030205', outline: true });
      for (const e of rig.eyes) e.visible = false;
      for (let i = 0; i < 6; i++) { const sp = part(new THREE.ConeGeometry(0.04, 0.25, 4), sm); sp.position.set((i - 2.5) * 0.06, 0.18, -0.05); sp.rotation.x = -0.6; rig.joints.head.add(sp); }
      break;
    }
    case 'elemental': {
      const m = new THREE.MeshStandardMaterial({ color: '#2a7fd6', roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85 });
      wobble(m);
      rig = makeRig({ scale: 2.3, bulk: 1.6, skin: m, top: m, pants: m, boots: m, gloves: m, sleeve: m, outline: false, eyeGlow: '#ffffff' });
      rig.elemMat = m;
      const core = new THREE.Mesh(new THREE.IcosahedronGeometry(0.11, 1), glowMat('#9ff0ff', 3)); core.position.set(0, 0.28, 0.08); rig.joints.chest.add(core); rig.core = core;
      // ombros rochosos (visíveis na fase de fogo)
      rig.rocks = [];
      for (const sh of [rig.joints.shL, rig.joints.shR, rig.joints.head]) {
        for (let k = 0; k < 3; k++) {
          const r = new THREE.Mesh(new THREE.DodecahedronGeometry(0.06 + k * 0.02), m);
          r.position.set((k - 1) * 0.06, 0.06 + k * 0.03, -0.03); sh.add(r); rig.rocks.push(r);
        }
      }
      break;
    }
    default:
      rig = makeRig({});
  }
  rig.root.traverse(o => { if (o.isMesh) o.receiveShadow = false; });
  rig.id = id;
  return rig;
}

// deformação ondulante (criatura de água / sombras)
export function wobble(mat, amount = 0.025) {
  mat.onBeforeCompile = (s) => {
    s.uniforms.uTime = U.time;
    s.vertexShader = 'uniform float uTime;\n' + s.vertexShader.replace('#include <begin_vertex>',
      `vec3 transformed = position + normal * (sin(position.y * 18.0 + uTime * 6.0) * cos(position.x * 14.0 + uTime * 4.0)) * ${amount.toFixed(3)};`);
  };
  mat.customProgramCacheKey = () => 'wobble' + amount;
  return mat;
}

// =====================================================================
//  TENTÁCULOS DO ABISMO (Krauser)
// =====================================================================
export class Tentacle {
  constructor(scene, side, up) {
    this.n = 16; this.side = side; this.up = up;
    this.segs = [];
    const mat = toon('#0c0a12', { emissive: new THREE.Color('#2a0a30'), emissiveIntensity: 0.6 });
    for (let i = 0; i < this.n; i++) {
      const r = 0.13 * (1 - i / this.n) + 0.03;
      const m = part(new THREE.SphereGeometry(r, 10, 8), mat);
      scene.add(m); this.segs.push(m);
    }
    this.tip = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), glowMat('#ff2a6a', 2)); scene.add(this.tip);
    this.base = new THREE.Vector3(); this.target = null; this.extend = 0; this.phase = Math.random() * 10;
    this.scene = scene;
  }
  update(dt, t, basePos, backDir, rightDir) {
    this.base.copy(basePos);
    const idleTip = basePos.clone()
      .addScaledVector(backDir, 1.4).addScaledVector(rightDir, this.side * 1.2)
      .add(new THREE.Vector3(0, this.up * 0.8 + Math.sin(t * 1.7 + this.phase) * 0.35, 0))
      .addScaledVector(rightDir, Math.sin(t * 1.3 + this.phase) * 0.3);
    const tipPos = this.target ? idleTip.clone().lerp(this.target, this.extend) : idleTip;
    const ctrl = basePos.clone().addScaledVector(backDir, 0.6).add(new THREE.Vector3(0, 1.4 + this.up * 0.4, 0)).addScaledVector(rightDir, this.side * 0.7);
    if (this.target) ctrl.lerp(new THREE.Vector3((basePos.x + this.target.x) / 2, Math.max(basePos.y, this.target.y) + 2.2, (basePos.z + this.target.z) / 2), this.extend);
    const curve = new THREE.QuadraticBezierCurve3(basePos, ctrl, tipPos);
    for (let i = 0; i < this.n; i++) {
      const p = curve.getPoint(i / (this.n - 1));
      p.x += Math.sin(t * 5 + i * 0.7 + this.phase) * 0.04 * (i / this.n);
      this.segs[i].position.copy(p);
    }
    this.tip.position.copy(this.segs[this.n - 1].position);
    this.tipPos = tipPos;
  }
  setVisible(v) { for (const s of this.segs) s.visible = v; this.tip.visible = v; }
  dispose() { for (const s of this.segs) this.scene.remove(s); this.scene.remove(this.tip); }
}

// =====================================================================
//  ANIMAÇÃO — clipes por keyframe + locomoção procedural
// =====================================================================
const CH = ['body', 'hips', 'chest', 'neck', 'head', 'shL', 'elL', 'shR', 'elR', 'hipL', 'knL', 'hipR', 'knR'];
const UPPER = new Set(['chest', 'neck', 'head', 'shL', 'elL', 'shR', 'elR']);
const REST = { shL: [0, 0, 0.12], shR: [0, 0, -0.12], elL: [-0.15, 0, 0], elR: [-0.15, 0, 0] };

const S = { // atalhos de pose
  stanceDagger: { shR: [-0.7, 0, -0.25], elR: [-1.1, 0, 0], shL: [-0.45, 0, 0.35], elL: [-1.2, 0, 0], chest: [0.12, -0.25, 0], hipL: [-0.35, 0, 0.08], knL: [0.55, 0, 0], hipR: [0.25, 0, -0.08], knR: [0.45, 0, 0], body: [0, 0.25, 0], pos: [0, -0.06, 0] },
};
export const CLIPS = {
  atk1: { dur: 0.4, ev: { 0.12: 'hit' }, keys: [
    [0, { chest: [0.1, 0.8, 0], shR: [-1.3, 0, 1.0], elR: [-1.4, 0, 0], shL: [-0.3, 0, 0.5], elL: [-1, 0, 0], hipL: [-0.4, 0, 0], knL: [0.5, 0, 0], hipR: [0.3, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.08, 0] }],
    [0.12, { chest: [0.2, -0.8, 0], shR: [-1.45, 0, -1.2], elR: [-0.15, 0, 0], shL: [-0.2, 0, 0.6], elL: [-0.8, 0, 0], hipL: [-0.6, 0, 0], knL: [0.6, 0, 0], hipR: [0.45, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.12, 0.12] }],
    [0.4, { chest: [0.15, -0.4, 0], shR: [-0.9, 0, -0.6], elR: [-0.8, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], hipL: [-0.4, 0, 0], knL: [0.5, 0, 0], hipR: [0.3, 0, 0], knR: [0.4, 0, 0], pos: [0, -0.08, 0.05] }]] },
  atk2: { dur: 0.42, ev: { 0.13: 'hit' }, keys: [
    [0, { chest: [0.0, -0.6, 0], shR: [-2.5, 0, -0.7], elR: [-0.9, 0, 0], shL: [-0.5, 0, 0.6], elL: [-1.2, 0, 0], hipL: [0.3, 0, 0], knL: [0.3, 0, 0], hipR: [-0.4, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.05, 0] }],
    [0.13, { chest: [0.35, 0.7, 0], shR: [-0.7, 0, 0.8], elR: [-0.3, 0, 0], shL: [-0.2, 0, 0.3], elL: [-0.6, 0, 0], hipL: [0.4, 0, 0], knL: [0.3, 0, 0], hipR: [-0.6, 0, 0], knR: [0.7, 0, 0], pos: [0, -0.14, 0.12] }],
    [0.42, { chest: [0.2, 0.3, 0], shR: [-0.8, 0, 0.2], elR: [-0.9, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], hipL: [0.2, 0, 0], knL: [0.4, 0, 0], hipR: [-0.4, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.08, 0.05] }]] },
  atk3: { dur: 0.62, ev: { 0.24: 'hit' }, keys: [
    [0, { chest: [-0.1, 0.5, 0], shR: [0.6, 0, -0.4], elR: [-1.8, 0, 0], shL: [-1.2, 0, 0.3], elL: [-0.4, 0, 0], hipL: [-0.2, 0, 0], knL: [1.0, 0, 0], hipR: [0.2, 0, 0], knR: [1.1, 0, 0], pos: [0, -0.25, -0.05] }],
    [0.24, { chest: [0.45, -0.35, 0], shR: [-1.65, 0, 0.05], elR: [0.0, 0, 0], shL: [0.4, 0, 0.7], elL: [-0.3, 0, 0], hipL: [-1.0, 0, 0], knL: [0.7, 0, 0], hipR: [0.8, 0, 0], knR: [0.2, 0, 0], pos: [0, -0.22, 0.25] }],
    [0.62, { chest: [0.15, -0.25, 0], shR: [-0.8, 0, -0.3], elR: [-1.0, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], hipL: [-0.4, 0, 0], knL: [0.5, 0, 0], hipR: [0.3, 0, 0], knR: [0.4, 0, 0], pos: [0, -0.08, 0.05] }]] },
  spin: { dur: 0.55, ev: { 0.2: 'hit' }, keys: [
    [0, { body: [0, 0, 0], chest: [0.2, 0.6, 0], shR: [-1.5, 0, -0.3], elR: [-0.2, 0, 0], shL: [-1.4, 0, 0.3], elL: [-0.2, 0, 0], pos: [0, -0.15, 0] }],
    [0.3, { body: [0, -Math.PI * 2, 0], chest: [0.2, 0.0, 0], shR: [-1.5, 0, -1.3], elR: [0, 0, 0], shL: [-1.4, 0, 1.3], elL: [0, 0, 0], pos: [0, -0.15, 0] }],
    [0.55, { body: [0, -Math.PI * 2, 0], chest: [0.1, -0.2, 0], shR: [-0.8, 0, -0.3], elR: [-1.0, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], pos: [0, -0.06, 0] }]] },
  dodge: { dur: 0.45, keys: [
    [0, { body: [0, 0, 0], pos: [0, -0.1, 0], hipL: [-0.5, 0, 0], knL: [0.8, 0, 0], hipR: [-0.3, 0, 0], knR: [0.9, 0, 0], shL: [-1.4, 0, 0.3], shR: [-1.4, 0, -0.3], elL: [-1.5, 0, 0], elR: [-1.5, 0, 0] }],
    [0.12, { body: [Math.PI * 0.6, 0, 0], pos: [0, -0.45, 0], hipL: [-1.9, 0, 0], knL: [2.2, 0, 0], hipR: [-1.9, 0, 0], knR: [2.2, 0, 0], shL: [-1.8, 0, 0.3], shR: [-1.8, 0, -0.3], elL: [-2, 0, 0], elR: [-2, 0, 0], chest: [0.6, 0, 0] }],
    [0.3, { body: [Math.PI * 1.6, 0, 0], pos: [0, -0.45, 0], hipL: [-1.9, 0, 0], knL: [2.2, 0, 0], hipR: [-1.9, 0, 0], knR: [2.2, 0, 0], shL: [-1.8, 0, 0.3], shR: [-1.8, 0, -0.3], elL: [-2, 0, 0], elR: [-2, 0, 0], chest: [0.6, 0, 0] }],
    [0.45, { body: [Math.PI * 2, 0, 0], pos: [0, -0.1, 0], hipL: [-0.4, 0, 0], knL: [0.6, 0, 0], hipR: [0.2, 0, 0], knR: [0.5, 0, 0], shL: [-0.4, 0, 0.4], shR: [-0.7, 0, -0.3], elL: [-1.1, 0, 0], elR: [-1.1, 0, 0], chest: [0.1, 0, 0] }]] },
  backstep: { dur: 0.35, keys: [
    [0, { body: [-0.3, 0, 0], pos: [0, -0.15, 0], hipL: [-0.8, 0, 0], knL: [0.6, 0, 0], hipR: [0.2, 0, 0], knR: [0.8, 0, 0] }],
    [0.35, { body: [0, 0, 0], pos: [0, -0.08, 0], hipL: [-0.4, 0, 0], knL: [0.5, 0, 0], hipR: [0.25, 0, 0], knR: [0.45, 0, 0] }]] },
  hit: { dur: 0.32, keys: [
    [0, { chest: [-0.45, 0.2, 0], head: [-0.35, 0, 0], shL: [-0.6, 0, 0.9], shR: [-0.6, 0, -0.9], elL: [-0.6, 0, 0], elR: [-0.6, 0, 0], pos: [0, -0.05, -0.08] }],
    [0.32, { chest: [0.05, 0, 0], head: [0, 0, 0], shL: [-0.3, 0, 0.3], shR: [-0.5, 0, -0.3], elL: [-0.8, 0, 0], elR: [-0.8, 0, 0], pos: [0, 0, 0] }]] },
  knock: { dur: 1.1, keys: [
    [0, { body: [-0.4, 0, 0], pos: [0, 0, 0], chest: [-0.3, 0, 0], shL: [-2, 0, 0.6], shR: [-2, 0, -0.6] }],
    [0.25, { body: [-1.45, 0, 0], pos: [0, -0.78, 0], chest: [-0.1, 0, 0], shL: [-2.6, 0, 0.8], shR: [-2.6, 0, -0.8], hipL: [-0.4, 0, 0], hipR: [-0.2, 0, 0] }],
    [0.7, { body: [-1.45, 0, 0], pos: [0, -0.78, 0], chest: [-0.1, 0, 0], shL: [-2.6, 0, 0.8], shR: [-2.6, 0, -0.8], hipL: [-0.4, 0, 0], hipR: [-0.2, 0, 0] }],
    [1.1, { body: [0, 0, 0], pos: [0, -0.1, 0], chest: [0.1, 0, 0], shL: [-0.4, 0, 0.3], shR: [-0.6, 0, -0.3], hipL: [-0.3, 0, 0], knL: [0.5, 0, 0], hipR: [0.2, 0, 0], knR: [0.5, 0, 0] }]] },
  guard: { dur: 0.12, hold: true, keys: [
    [0, { shR: [-0.7, 0, -0.25], elR: [-1.1, 0, 0], shL: [-0.45, 0, 0.35], elL: [-1.2, 0, 0] }],
    [0.12, { chest: [0.15, -0.4, 0], shR: [-1.3, 0, 0.7], elR: [-1.6, 0, 0], shL: [-1.1, 0, -0.5], elL: [-1.7, 0, 0], hipL: [-0.4, 0, 0], knL: [0.6, 0, 0], hipR: [0.35, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.12, 0] }]] },
  cast: { dur: 0.5, upper: true, ev: { 0.18: 'hit' }, keys: [
    [0, { chest: [0, 0.5, 0], shR: [-0.5, 0, -0.6], elR: [-1.8, 0, 0], shL: [-0.4, 0, 0.3], elL: [-1, 0, 0] }],
    [0.18, { chest: [0.15, -0.5, 0], shR: [-1.6, 0, 0.1], elR: [0, 0, 0], shL: [-0.2, 0, 0.6], elL: [-0.5, 0, 0] }],
    [0.5, { chest: [0.1, -0.2, 0], shR: [-0.8, 0, -0.2], elR: [-1, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0] }]] },
  strum: { dur: 0.7, ev: { 0.35: 'hit' }, keys: [
    [0, { chest: [0.1, 0.2, 0], shL: [-1.1, 0, 0.5], elL: [-1.5, 0, 0], shR: [-0.6, 0, -0.5], elR: [-1.5, 0, 0], pos: [0, -0.05, 0] }],
    [0.3, { chest: [-0.1, 0.0, 0], shL: [-1.1, 0, 0.5], elL: [-1.5, 0, 0], shR: [-0.3, 0, -0.2], elR: [-1.1, 0, 0], pos: [0, -0.1, 0] }],
    [0.4, { chest: [-0.35, 0, 0], head: [-0.3, 0, 0], shL: [-0.2, 0, 1.5], elL: [-0.1, 0, 0], shR: [-0.2, 0, -1.5], elR: [-0.1, 0, 0], pos: [0, -0.1, 0] }],
    [0.7, { chest: [0.05, 0, 0], head: [0, 0, 0], shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], shR: [-0.7, 0, -0.3], elR: [-1.1, 0, 0], pos: [0, -0.06, 0] }]] },
  play: { dur: 0.3, hold: true, keys: [
    [0, { shL: [-0.4, 0, 0.4], elL: [-1.1, 0, 0], shR: [-0.6, 0, -0.3], elR: [-1.1, 0, 0] }],
    [0.3, { chest: [0.05, 0.2, 0], head: [0.25, 0.3, 0], shL: [-1.15, 0, 0.55], elL: [-1.6, 0, 0], shR: [-0.55, 0, -0.45], elR: [-1.45, 0, 0], pos: [0, -0.03, 0] }]] },
  shoot: { dur: 0.6, upper: true, ev: { 0.42: 'hit' }, keys: [
    [0, { chest: [0, -1.2, 0], head: [0, 1.1, 0], shL: [-1.57, 0, 0.0], elL: [0, 0, 0], shR: [-1.5, 0, 0.3], elR: [-0.4, 0, 0] }],
    [0.4, { chest: [0, -1.25, 0], head: [0, 1.15, 0], shL: [-1.57, 0, 0.0], elL: [0, 0, 0], shR: [-1.5, 0, 0.6], elR: [-2.3, 0, 0] }],
    [0.6, { chest: [0, -1.2, 0], head: [0, 1.1, 0], shL: [-1.5, 0, 0.0], elL: [0, 0, 0], shR: [-1.0, 0, -0.5], elR: [-0.4, 0, 0] }]] },
  swing: { dur: 0.95, ev: { 0.52: 'hit' }, keys: [
    [0, { chest: [0, 0, 0], shR: [-0.5, 0, -0.2], elR: [-0.5, 0, 0] }],
    [0.4, { chest: [-0.25, -0.5, 0], shR: [-2.8, 0, -0.4], elR: [-0.7, 0, 0], shL: [-0.6, 0, 0.6], elL: [-0.8, 0, 0], hipL: [-0.3, 0, 0], knL: [0.3, 0, 0], hipR: [0.2, 0, 0], knR: [0.3, 0, 0] }],
    [0.52, { chest: [0.45, 0.4, 0], shR: [-0.5, 0, 0.4], elR: [-0.1, 0, 0], shL: [-0.2, 0, 0.4], elL: [-0.5, 0, 0], hipL: [-0.6, 0, 0], knL: [0.5, 0, 0], hipR: [0.4, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.12, 0.15] }],
    [0.95, { chest: [0.1, 0, 0], shR: [-0.5, 0, -0.2], elR: [-0.5, 0, 0], shL: [-0.3, 0, 0.3], elL: [-0.5, 0, 0], pos: [0, 0, 0] }]] },
  heavy: { dur: 1.3, ev: { 0.78: 'hit' }, keys: [
    [0, { chest: [0, 0, 0], shR: [-0.5, 0, -0.2], shL: [-0.5, 0, 0.2] }],
    [0.62, { chest: [-0.45, 0, 0], head: [-0.2, 0, 0], shR: [-3.0, 0, 0.2], elR: [-0.6, 0, 0], shL: [-3.0, 0, -0.2], elL: [-0.6, 0, 0], hipL: [-0.4, 0, 0], knL: [0.3, 0, 0], hipR: [0.3, 0, 0], knR: [0.2, 0, 0], pos: [0, 0.05, 0] }],
    [0.78, { chest: [0.7, 0, 0], head: [0.2, 0, 0], shR: [-0.9, 0, 0.1], elR: [-0.1, 0, 0], shL: [-0.9, 0, -0.1], elL: [-0.1, 0, 0], hipL: [-0.9, 0, 0], knL: [0.9, 0, 0], hipR: [0.5, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.3, 0.3] }],
    [1.3, { chest: [0.1, 0, 0], head: [0, 0, 0], shR: [-0.5, 0, -0.2], elR: [-0.4, 0, 0], shL: [-0.5, 0, 0.2], elL: [-0.4, 0, 0], pos: [0, 0, 0] }]] },
  sweep: { dur: 1.0, ev: { 0.55: 'hit' }, keys: [
    [0, { chest: [0, 0, 0], shR: [-0.5, 0, -0.2] }],
    [0.45, { chest: [0.1, 1.1, 0], shR: [-1.4, 0, 1.2], elR: [-0.6, 0, 0], shL: [-0.5, 0, 0.8], hipL: [-0.4, 0, 0], knL: [0.5, 0, 0], hipR: [0.3, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.15, 0] }],
    [0.58, { chest: [0.25, -1.2, 0], shR: [-1.5, 0, -1.4], elR: [0, 0, 0], shL: [-0.3, 0, 0.6], hipL: [-0.5, 0, 0], knL: [0.6, 0, 0], hipR: [0.4, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.18, 0.1] }],
    [1.0, { chest: [0.05, 0, 0], shR: [-0.5, 0, -0.2], elR: [-0.4, 0, 0], shL: [-0.3, 0, 0.3], pos: [0, 0, 0] }]] },
  slam: { dur: 1.4, ev: { 0.85: 'hit' }, keys: [
    [0, { chest: [0, 0, 0] }],
    [0.65, { chest: [-0.5, 0, 0], head: [-0.4, 0, 0], shR: [-2.9, 0, -0.5], elR: [-1.2, 0, 0], shL: [-2.9, 0, 0.5], elL: [-1.2, 0, 0], pos: [0, 0.15, 0] }],
    [0.85, { chest: [0.9, 0, 0], head: [0.3, 0, 0], shR: [-1.2, 0, -0.1], elR: [0, 0, 0], shL: [-1.2, 0, 0.1], elL: [0, 0, 0], hipL: [-1.2, 0, 0], knL: [1.4, 0, 0], hipR: [-1.2, 0, 0], knR: [1.4, 0, 0], pos: [0, -0.45, 0.2] }],
    [1.4, { chest: [0.1, 0, 0], head: [0, 0, 0], shR: [-0.4, 0, -0.2], elR: [-0.4, 0, 0], shL: [-0.4, 0, 0.2], elL: [-0.4, 0, 0], pos: [0, 0, 0] }]] },
  roar: { dur: 1.6, keys: [
    [0, { chest: [0, 0, 0] }],
    [0.35, { chest: [-0.55, 0, 0], head: [-0.5, 0, 0], shR: [-0.8, 0, -1.3], elR: [-0.9, 0, 0], shL: [-0.8, 0, 1.3], elL: [-0.9, 0, 0], pos: [0, -0.05, 0] }],
    [1.3, { chest: [-0.55, 0, 0], head: [-0.5, 0, 0], shR: [-0.8, 0, -1.3], elR: [-0.9, 0, 0], shL: [-0.8, 0, 1.3], elL: [-0.9, 0, 0], pos: [0, -0.05, 0] }],
    [1.6, { chest: [0.1, 0, 0], head: [0, 0, 0], shR: [-0.4, 0, -0.2], shL: [-0.4, 0, 0.2], pos: [0, 0, 0] }]] },
  charge: { dur: 0.3, hold: true, keys: [
    [0, { chest: [0.2, 0, 0] }],
    [0.3, { chest: [0.6, 0, 0], head: [-0.4, 0, 0], shR: [0.6, 0, -0.4], elR: [-0.6, 0, 0], shL: [0.6, 0, 0.4], elL: [-0.6, 0, 0], hipL: [-0.9, 0, 0], knL: [1.0, 0, 0], hipR: [0.6, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.15, 0] }]] },
  claw: { dur: 0.5, ev: { 0.2: 'hit' }, keys: [
    [0, { chest: [0, 0.6, 0], shR: [-2.3, 0, -0.9], elR: [-1.0, 0, 0], shL: [-0.6, 0, 0.5] }],
    [0.2, { chest: [0.4, -0.7, 0], shR: [-0.6, 0, 0.6], elR: [-0.2, 0, 0], shL: [-0.4, 0, 0.5], pos: [0, -0.1, 0.15] }],
    [0.5, { chest: [0.1, 0, 0], shR: [-0.6, 0, -0.3], elR: [-0.6, 0, 0], shL: [-0.5, 0, 0.3], pos: [0, 0, 0] }]] },
  claw2: { dur: 0.5, ev: { 0.2: 'hit' }, keys: [
    [0, { chest: [0, -0.6, 0], shL: [-2.3, 0, 0.9], elL: [-1.0, 0, 0], shR: [-0.6, 0, -0.5] }],
    [0.2, { chest: [0.4, 0.7, 0], shL: [-0.6, 0, -0.6], elL: [-0.2, 0, 0], shR: [-0.4, 0, -0.5], pos: [0, -0.1, 0.15] }],
    [0.5, { chest: [0.1, 0, 0], shL: [-0.6, 0, 0.3], elL: [-0.6, 0, 0], shR: [-0.5, 0, -0.3], pos: [0, 0, 0] }]] },
  punch: { dur: 0.4, ev: { 0.12: 'hit' }, keys: [
    [0, { chest: [0, 0.6, 0], shR: [0.4, 0, -0.4], elR: [-2.1, 0, 0], shL: [-1.0, 0, 0.3], elL: [-1.8, 0, 0], hipL: [-0.4, 0, 0], knL: [0.4, 0, 0], hipR: [0.3, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.1, 0] }],
    [0.12, { chest: [0.2, -0.6, 0], shR: [-1.6, 0, 0.15], elR: [0, 0, 0], shL: [-0.6, 0, 0.4], elL: [-1.8, 0, 0], hipL: [-0.6, 0, 0], knL: [0.5, 0, 0], hipR: [0.5, 0, 0], knR: [0.2, 0, 0], pos: [0, -0.12, 0.18] }],
    [0.4, { chest: [0.1, -0.2, 0], shR: [-0.7, 0, -0.3], elR: [-1.5, 0, 0], shL: [-0.7, 0, 0.3], elL: [-1.5, 0, 0], pos: [0, -0.06, 0.05] }]] },
  punchL: { dur: 0.4, ev: { 0.12: 'hit' }, keys: [
    [0, { chest: [0, -0.6, 0], shL: [0.4, 0, 0.4], elL: [-2.1, 0, 0], shR: [-1.0, 0, -0.3], elR: [-1.8, 0, 0], pos: [0, -0.1, 0] }],
    [0.12, { chest: [0.2, 0.6, 0], shL: [-1.6, 0, -0.15], elL: [0, 0, 0], shR: [-0.6, 0, -0.4], elR: [-1.8, 0, 0], pos: [0, -0.12, 0.18] }],
    [0.4, { chest: [0.1, 0.2, 0], shL: [-0.7, 0, 0.3], elL: [-1.5, 0, 0], shR: [-0.7, 0, -0.3], elR: [-1.5, 0, 0], pos: [0, -0.06, 0.05] }]] },
  uppercut: { dur: 0.75, ev: { 0.3: 'hit' }, keys: [
    [0, { chest: [0.4, 0.3, 0], shR: [0.6, 0, -0.3], elR: [-1.8, 0, 0], pos: [0, -0.3, 0], hipL: [-0.8, 0, 0], knL: [1.2, 0, 0], hipR: [0, 0, 0], knR: [1.1, 0, 0] }],
    [0.3, { chest: [-0.3, -0.4, 0], head: [-0.3, 0, 0], shR: [-2.9, 0, 0.1], elR: [-0.3, 0, 0], shL: [-0.3, 0, 0.6], pos: [0, 0.15, 0.15], hipL: [-0.2, 0, 0], knL: [0.2, 0, 0], hipR: [0.4, 0, 0], knR: [0.6, 0, 0] }],
    [0.75, { chest: [0.1, 0, 0], head: [0, 0, 0], shR: [-0.7, 0, -0.3], elR: [-1.4, 0, 0], shL: [-0.6, 0, 0.3], pos: [0, -0.05, 0] }]] },
  kneel: { dur: 0.5, hold: true, keys: [
    [0, {}],
    [0.5, { pos: [0, -0.42, 0], hipL: [-1.5, 0, 0.1], knL: [1.55, 0, 0], hipR: [0.15, 0, -0.1], knR: [1.95, 0, 0], chest: [0.35, 0, 0], head: [0.3, 0, 0], shL: [-0.2, 0, 0.2], shR: [-0.2, 0, -0.2] }]] },
  lie: { dur: 0.8, hold: true, keys: [
    [0, {}],
    [0.8, { body: [-1.5, 0, 0], pos: [0, -0.82, 0], chest: [-0.05, 0, 0], head: [-0.2, 0.4, 0], shL: [-0.3, 0, 0.7], shR: [-0.2, 0, -0.4], hipL: [-0.1, 0, 0], knL: [0.3, 0, 0] }]] },
  death: { dur: 1.0, hold: true, keys: [
    [0, { body: [0, 0, 0], pos: [0, 0, 0] }],
    [0.25, { body: [-0.5, 0, 0], pos: [0, -0.2, 0], chest: [-0.3, 0, 0], shL: [-1.5, 0, 0.8], shR: [-1.5, 0, -0.8] }],
    [0.7, { body: [-1.52, 0, 0.1], pos: [0, -0.82, 0], chest: [-0.1, 0, 0], head: [-0.3, 0.5, 0], shL: [-2.6, 0, 0.6], shR: [-2.4, 0, -0.9], hipL: [-0.3, 0, 0], knL: [0.4, 0, 0] }],
    [1.0, { body: [-1.52, 0, 0.1], pos: [0, -0.84, 0], chest: [-0.1, 0, 0], head: [-0.3, 0.5, 0], shL: [-2.7, 0, 0.6], shR: [-2.4, 0, -0.9], hipL: [-0.3, 0, 0], knL: [0.4, 0, 0] }]] },
  talk: { dur: 1.6, keys: [
    [0, {}],
    [0.4, { shR: [-0.9, 0.3, -0.3], elR: [-1.3, 0, 0], head: [0.1, 0.15, 0] }],
    [1.0, { shR: [-0.7, 0.3, -0.5], elR: [-1.0, 0, 0], head: [-0.05, -0.1, 0] }],
    [1.6, {}]] },
  point: { dur: 0.8, hold: true, keys: [[0, {}], [0.4, { shR: [-1.6, 0.2, 0], elR: [0, 0, 0], chest: [0, -0.3, 0], head: [0, 0.2, 0] }]] },
  float: { dur: 0.6, hold: true, keys: [[0, {}], [0.6, { pos: [0, 1.3, 0], chest: [-0.3, 0, 0], shL: [-0.4, 0, 1.2], shR: [-0.4, 0, -1.2], hipL: [-0.2, 0, 0], knL: [0.6, 0, 0], hipR: [0.1, 0, 0], knR: [0.8, 0, 0] }]] },
  grab: { dur: 0.5, hold: true, keys: [[0, {}], [0.5, { chest: [0.5, 0, 0], shL: [-1.6, 0, -0.3], elL: [-0.3, 0, 0], shR: [-1.6, 0, 0.3], elR: [-0.3, 0, 0], hipL: [-0.6, 0, 0], knL: [0.7, 0, 0], hipR: [0.5, 0, 0], knR: [0.5, 0, 0], pos: [0, -0.15, 0.1] }]] },
  hang: { dur: 0.5, hold: true, keys: [[0, {}], [0.5, { shL: [-2.9, 0, 0.5], elL: [0, 0, 0], shR: [-2.9, 0, -0.5], elR: [0, 0, 0], head: [0.6, 0, 0], chest: [0.15, 0, 0], hipL: [0.1, 0, 0], hipR: [-0.05, 0, 0], knL: [0.2, 0, 0] }]] },
};
// normaliza: canais ausentes herdam do keyframe anterior
for (const k in CLIPS) {
  const c = CLIPS[k], chans = new Set();
  for (const [, p] of c.keys) for (const ch in p) chans.add(ch);
  c.chans = [...chans];
  let prev = {};
  for (const kf of c.keys) {
    const p = kf[1];
    for (const ch of c.chans) if (!p[ch]) p[ch] = prev[ch] || (ch === 'pos' ? [0, 0, 0] : (REST[ch] || [0, 0, 0]));
    prev = p;
  }
}

const ease = (t) => t * t * (3 - 2 * t);
export class Animator {
  constructor(rig) {
    this.rig = rig; this.phase = 0; this.t = 0;
    this.clip = null; this.ct = 0; this.w = 0; this.fadeOut = false;
    this.combat = 0; this.stance = S.stanceDagger;
    this.cur = {}; for (const ch of CH) this.cur[ch] = [0, 0, 0]; this.cur.pos = [0, 0, 0];
    this.onStep = null; this.lastStepSign = 0; this.speedMul = 1;
  }
  play(name, opts = {}) {
    const c = CLIPS[name]; if (!c) return;
    this.clip = c; this.clipName = name; this.ct = 0; this.fadeOut = false;
    this.opts = opts; this.speedMul = opts.speed || 1; this.firedEv = new Set();
    if (opts.instant) { this.w = 1; if (c.hold) this.ct = c.dur; }
  }
  stop(fade = true) { if (this.clip) { this.fadeOut = true; if (!fade) { this.clip = null; this.w = 0; } } }
  get busy() { return this.clip && !this.fadeOut; }
  sample(c, t) {
    const ks = c.keys; let i = 0;
    while (i < ks.length - 1 && ks[i + 1][0] <= t) i++;
    if (i >= ks.length - 1) return ks[ks.length - 1][1];
    const [t0, p0] = ks[i], [t1, p1] = ks[i + 1];
    const f = ease(Math.min(1, (t - t0) / Math.max(0.0001, t1 - t0)));
    const out = {};
    for (const ch of c.chans) { const a = p0[ch], b = p1[ch]; out[ch] = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f]; }
    return out;
  }
  update(dt, speed, o = {}) {
    this.t += dt;
    const J = this.rig.joints;
    // ---- locomoção base ----
    const a = Math.min(speed / 4.2, 1.5);
    this.phase += dt * Math.PI * 2 * (0.55 + speed * 0.19);
    const p = this.phase, sp = Math.sin(p), cp = Math.cos(p);
    const base = {};
    const cw = this.combat * Math.max(0, 1 - a * 1.4);
    const st = this.stance;
    const L = (ch, v) => { const s = st[ch] || REST[ch] || [0, 0, 0]; return [v[0] * (1 - cw) + s[0] * cw, v[1] * (1 - cw) + s[1] * cw, v[2] * (1 - cw) + s[2] * cw]; };
    const breath = Math.sin(this.t * 2.1) * 0.025;
    base.body = L('body', [0, 0, 0]);
    base.hips = [0, sp * 0.12 * a, 0];
    base.chest = L('chest', [0.1 * a + (o.sprint ? 0.25 : 0) + breath, -sp * 0.18 * a, 0]);
    base.neck = [0, 0, 0];
    base.head = [-0.08 * a, sp * 0.1 * a, 0];
    base.shL = L('shL', [sp * 0.75 * a, 0, 0.12 + 0.05 * a + breath]);
    base.shR = L('shR', [-sp * 0.75 * a, 0, -0.12 - 0.05 * a - breath]);
    base.elL = L('elL', [-0.25 - 0.7 * a, 0, 0]);
    base.elR = L('elR', [-0.25 - 0.7 * a, 0, 0]);
    base.hipL = L('hipL', [-sp * 0.8 * a, 0, 0]);
    base.hipR = L('hipR', [sp * 0.8 * a, 0, 0]);
    base.knL = L('knL', [Math.max(0, cp) * 1.25 * a + 0.08 * a, 0, 0]);
    base.knR = L('knR', [Math.max(0, -cp) * 1.25 * a + 0.08 * a, 0, 0]);
    const sPos = st.pos || [0, 0, 0];
    base.pos = [sPos[0] * cw, (Math.abs(sp) - 0.6) * 0.07 * a + sPos[1] * cw, sPos[2] * cw];
    if (o.fly) { base.pos[1] += 0; }
    // passos
    if (a > 0.15) { const sg = Math.sign(sp); if (sg !== this.lastStepSign) { this.lastStepSign = sg; this.onStep && this.onStep(); } }

    // ---- clipe ----
    let pose = null;
    if (this.clip) {
      const c = this.clip;
      this.ct += dt * this.speedMul;
      if (!this.fadeOut) this.w = Math.min(1, this.w + dt / (this.opts.blendIn ?? 0.06));
      else { this.w = Math.max(0, this.w - dt / 0.12); if (this.w === 0) this.clip = null; }
      if (c.ev) for (const k in c.ev) if (this.ct >= +k && !this.firedEv.has(k)) { this.firedEv.add(k); this.opts.onEvent && this.opts.onEvent(c.ev[k]); }
      if (this.ct >= c.dur && !this.fadeOut) {
        if (c.hold) this.ct = c.dur;
        else if (this.opts.loop) { this.ct = 0; this.firedEv = new Set(); }
        else { this.fadeOut = true; const cb = this.opts.onEnd; cb && cb(); }
      }
      if (this.clip) pose = this.sample(c, Math.min(this.ct, c.dur));
    }
    const w = this.w;
    const upperOnly = this.clip && this.clip.upper;
    // ---- aplica com suavização ----
    const k = 1 - Math.exp(-dt * 30);
    for (const ch of [...CH, 'pos']) {
      let v = base[ch] || [0, 0, 0];
      if (pose && pose[ch] && (!upperOnly || UPPER.has(ch) || ch === 'pos' && false)) {
        const pv = pose[ch];
        v = [v[0] + (pv[0] - v[0]) * w, v[1] + (pv[1] - v[1]) * w, v[2] + (pv[2] - v[2]) * w];
      }
      const c = this.cur[ch];
      // rotação do corpo (rolamento) não deve ser suavizada a ponto de atrasar
      const kk = ch === 'body' ? 1 - Math.exp(-dt * 60) : k;
      c[0] += (v[0] - c[0]) * kk; c[1] += (v[1] - c[1]) * kk; c[2] += (v[2] - c[2]) * kk;
    }
    for (const ch of CH) { const j = J[ch]; if (!j) continue; const c = this.cur[ch]; j.rotation.set(c[0], c[1], c[2]); }
    J.body.position.set(this.cur.pos[0], 0.95 + this.cur.pos[1], this.cur.pos[2]);
    if (o.bodyExtraY) J.body.position.y += o.bodyExtraY;
  }
}
