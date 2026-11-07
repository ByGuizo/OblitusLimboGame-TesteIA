// =====================================================================
//  Estado global do jogo + sistemas de combate compartilhados
// =====================================================================
import * as THREE from 'three';
import { Audio } from './audio.js';
import { glowMat } from './models.js';
import { T } from './textures.js';

const V3 = THREE.Vector3;
export const G = {
  scene: null, fx: null, player: null, actors: [], projectiles: [], hazards: [], areas: [],
  level: null, cam: null, ui: null, input: null, time: 0, realTime: 0,
  hitstop: 0, slow: { t: 0, scale: 1 }, attackTokens: 0, maxTokens: 2,
  post: null, paused: true, flags: {}, killCount: 0, events: [], timers: [],
};

export const rnd = (a, b) => a + Math.random() * (b - a);
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; };
export const yawTo = (from, to) => Math.atan2(to.x - from.x, to.z - from.z);
export const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
export const fwd = (yaw) => new V3(Math.sin(yaw), 0, Math.cos(yaw));

// temporizadores em tempo de jogo (respeitam pausa, hitstop e câmera lenta)
export function after(sec, fn) { G.timers.push({ t: sec, fn }); }
function updateTimers(dt) {
  const ts = G.timers; G.timers = [];
  for (const x of ts) { x.t -= dt; if (x.t <= 0) { try { x.fn(); } catch (e) { console.error(e); } } else G.timers.push(x); }
}
export function emit(name, data) { for (const e of G.events) if (e.name === name) e.fn(data); }
export function on(name, fn) { const e = { name, fn }; G.events.push(e); return () => { G.events = G.events.filter(x => x !== e); }; }

export function enemiesOf(actor) { return G.actors.filter(a => a.alive && a.team !== actor.team && a.team !== 'neutral' && !a.untargetable); }
export function nearestEnemy(actor, maxDist = 99, cone = null) {
  let best = null, bd = maxDist;
  for (const e of enemiesOf(actor)) {
    const d = dist2D(actor.pos, e.pos);
    if (d > bd) continue;
    if (cone !== null && d > 1.2 && Math.abs(angDiff(yawTo(actor.pos, e.pos), actor.yaw)) > cone) continue;
    best = e; bd = d;
  }
  return best;
}

// ---------------------------------------------------------------------
//  Colisão (círculos + caixas + limites da arena)
// ---------------------------------------------------------------------
export function resolveCollision(a) {
  const L = G.level; if (!L) return;
  const p = a.pos;
  if (L.obstacles) for (const o of L.obstacles) {
    if (o.r !== undefined) {
      const dx = p.x - o.x, dz = p.z - o.z, d = Math.hypot(dx, dz), m = o.r + a.radius;
      if (d < m && d > 0.0001) { p.x = o.x + dx / d * m; p.z = o.z + dz / d * m; }
    } else {
      const minX = o.minX - a.radius, maxX = o.maxX + a.radius, minZ = o.minZ - a.radius, maxZ = o.maxZ + a.radius;
      if (p.x > minX && p.x < maxX && p.z > minZ && p.z < maxZ) {
        const dl = p.x - minX, dr = maxX - p.x, db = p.z - minZ, df = maxZ - p.z, m = Math.min(dl, dr, db, df);
        if (m === dl) p.x = minX; else if (m === dr) p.x = maxX; else if (m === db) p.z = minZ; else p.z = maxZ;
      }
    }
  }
  const b = L.bounds;
  if (b) {
    if (b.type === 'circle') {
      const dx = p.x - (b.cx || 0), dz = p.z - (b.cz || 0), d = Math.hypot(dx, dz), m = b.r - a.radius;
      if (d > m) { p.x = (b.cx || 0) + dx / d * m; p.z = (b.cz || 0) + dz / d * m; }
    } else {
      p.x = clamp(p.x, b.minX + a.radius, b.maxX - a.radius);
      p.z = clamp(p.z, b.minZ + a.radius, b.maxZ - a.radius);
    }
  }
}
export function separateActors() {
  const A = G.actors;
  for (let i = 0; i < A.length; i++) {
    const a = A[i]; if (!a.alive || a.noCollide) continue;
    for (let j = i + 1; j < A.length; j++) {
      const b = A[j]; if (!b.alive || b.noCollide) continue;
      const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z, d = Math.hypot(dx, dz), m = a.radius + b.radius;
      if (d < m && d > 0.0001) {
        const push = (m - d) / 2, nx = dx / d, nz = dz / d;
        const wa = a.mass ? b.mass / (a.mass + b.mass) : 0.5, wb = 1 - wa;
        a.pos.x -= nx * push * 2 * wa; a.pos.z -= nz * push * 2 * wa;
        b.pos.x += nx * push * 2 * wb; b.pos.z += nz * push * 2 * wb;
      }
    }
  }
}

// ---------------------------------------------------------------------
//  Dano
// ---------------------------------------------------------------------
export function damage(src, target, amount, o = {}) {
  if (!target || !target.alive) return false;
  if (target.invulnerable) return false;
  const P = G.player;
  // esquiva (i-frames) — esquiva perfeita
  if (target.iframes > 0 && !o.unavoidable) {
    if (target === P && target.dodgeT !== undefined && target.dodgeT < 0.22 && !target.perfectUsed) {
      target.perfectUsed = true;
      G.slow = { t: 0.9, scale: 0.25 };
      P.gainFury(15);
      G.ui && G.ui.toast('ESQUIVA PERFEITA', '#9fd8ff');
      Audio.sfx('parry', { vol: 0.5 });
      G.post && (G.post.flash = 0.25);
    }
    return false;
  }
  const dir = new V3(target.pos.x - (o.from ? o.from.x : src.pos.x), 0, target.pos.z - (o.from ? o.from.z : src.pos.z));
  if (dir.lengthSq() < 0.0001) dir.set(Math.sin(src.yaw || 0), 0, Math.cos(src.yaw || 0));
  dir.normalize();
  // defesa / parry
  if (target.guarding && !o.unblockable) {
    const facing = Math.abs(angDiff(yawTo(target.pos, o.from || src.pos), target.yaw)) < 1.2;
    if (facing) {
      if (target.guardT < 0.22 && src.stun) {          // PARRY
        src.stun(1.6);
        Audio.sfx('parry');
        G.fx.burst('spark', target.pos.clone().add(new V3(0, 1.3, 0)).addScaledVector(dir, -0.5), { n: 30, color: '#ffffff', color2: '#80c0ff' });
        G.fx.flash(target.pos.clone().add(new V3(0, 1.4, 0)), '#bfe0ff', 10, 0.2);
        G.slow = { t: 0.6, scale: 0.3 }; G.cam && G.cam.shake(0.35);
        target.gainFury && target.gainFury(20);
        G.ui && G.ui.toast('APARADO!', '#ffe08a');
        return false;
      }
      const cost = amount * 1.6;
      target.stamina = Math.max(0, (target.stamina || 0) - cost);
      Audio.sfx('block');
      G.fx.burst('spark', target.pos.clone().add(new V3(0, 1.2, 0)).addScaledVector(dir, -0.4), { n: 10 });
      target.knock && target.knock.addScaledVector(dir, 3);
      if (target.stamina <= 0) { target.guardBreak && target.guardBreak(); }
      else { amount *= 0.15; if (amount < 1) return true; }
    }
  }
  // resistências
  if (target.resist && o.element && target.resist[o.element]) amount *= target.resist[o.element];
  if (target.dmgTakenMul) amount *= target.dmgTakenMul;
  amount = Math.round(amount * (o.crit ? 1.5 : 1));
  if (target.minHp !== undefined) amount = Math.min(amount, Math.max(0, target.hp - target.minHp));
  target.hp -= amount;
  target.lastHitBy = src; target.hitFlash = 0.12;
  // efeitos
  const hp = target.pos.clone(); hp.y += (target.rig ? target.rig.height * 0.6 : 1.2);
  if (o.fx !== false) {
    G.fx.burst('spark', hp, { n: o.heavy ? 22 : 12, dir, color: o.sparkColor, color2: o.sparkColor2 });
    if (target.bleeds !== false) G.fx.burst('blood', hp, { n: o.heavy ? 10 : 5, dir });
  }
  Audio.sfx(o.crit ? 'crit' : o.heavy ? 'hitHeavy' : 'hit', { vol: o.vol ?? 1 });
  G.ui && G.ui.damageNumber(hp, amount, { crit: o.crit, player: target === P, color: o.numColor });
  if (src === P || src.team === 'player') {
    G.hitstop = Math.max(G.hitstop, o.heavy ? 0.09 : 0.045);
    G.cam && G.cam.shake(o.heavy ? 0.3 : 0.13);
    P && P.gainFury && src === P && P.gainFury(o.furyGain ?? 3.5);
  }
  if (target === P) {
    G.cam && G.cam.shake(0.35 + Math.min(0.4, amount / 60));
    G.post && (G.post.hurt = 0.5);
    P.gainFury && P.gainFury(amount * 0.6);
  }
  // reação
  const kb = o.knock ?? 3;
  target.knock && target.knock.addScaledVector(dir, kb * (target.knockResist ?? 1));
  if (target.onHit) target.onHit(src, amount, o);
  if (target.hp <= 0) { target.hp = 0; target.die && target.die(src, o); }
  return true;
}

// ---------------------------------------------------------------------
//  Ataques em área com aviso (telegraph)
// ---------------------------------------------------------------------
export function inShape(p, s, extraR = 0) {
  const dx = p.x - s.pos.x, dz = p.z - s.pos.z, d = Math.hypot(dx, dz);
  if (s.shape === 'circle' || !s.shape) return d <= s.radius + extraR && (s.inner ? d >= s.inner - extraR : true);
  if (s.shape === 'cone') return d <= s.radius + extraR && Math.abs(angDiff(Math.atan2(dx, dz), s.yaw)) <= s.angle / 2 + 0.1;
  if (s.shape === 'rect') {
    const f = Math.sin(s.yaw) * dx + Math.cos(s.yaw) * dz, l = Math.cos(s.yaw) * dx - Math.sin(s.yaw) * dz;
    return f >= -extraR && f <= s.length + extraR && Math.abs(l) <= s.width / 2 + extraR;
  }
  return false;
}
export function areaAttack(o) {
  const s = { shape: o.shape || 'circle', pos: o.pos.clone(), radius: o.radius || 2, angle: o.angle || 1, yaw: o.yaw || 0, width: o.width || 2, length: o.length || 6, inner: o.inner };
  const tel = o.delay > 0 && o.telegraph !== false ? G.fx.telegraph(s.pos, { shape: s.shape === 'circle' ? null : s.shape, radius: s.radius, angle: s.angle, yaw: s.yaw, width: s.width, length: s.length, time: o.delay, color: o.color }) : null;
  if (o.delay > 0 && o.sound !== false) Audio.sfx('telegraph', { vol: 0.6 });
  const area = { t: 0, delay: o.delay || 0, s, o, tel };
  G.areas.push(area);
  return area;
}
function triggerArea(a) {
  const { s, o } = a;
  if (a.tel) a.tel.kill = true;
  if (o.onTrigger) o.onTrigger(s);
  for (const t of [...G.actors]) {
    if (!t.alive || t.team === o.team || t.team === 'neutral') continue;
    if (o.only && !o.only(t)) continue;
    if (inShape(t.pos, s, t.radius * 0.6)) damage(o.src, t, o.dmg, { knock: o.knock ?? 6, heavy: o.heavy ?? true, from: o.from || s.pos, element: o.element, unblockable: o.unblockable, crit: o.crit, furyGain: o.furyGain, fx: o.fx });
  }
}

// ---------------------------------------------------------------------
//  Projéteis
// ---------------------------------------------------------------------
const projGeo = {
  orb: new THREE.SphereGeometry(0.18, 12, 10),
  bolt: new THREE.CylinderGeometry(0.015, 0.015, 0.5, 5).rotateX(Math.PI / 2),
  spear: new THREE.ConeGeometry(0.13, 1.4, 6).rotateX(Math.PI / 2),
};
function crescentGeo() {
  const sh = new THREE.Shape();
  sh.absarc(0, 0, 0.7, -1.2, 1.2, false);
  sh.absarc(-0.22, 0, 0.6, 1.1, -1.1, true);
  const g = new THREE.ShapeGeometry(sh, 16); g.rotateX(-Math.PI / 2); g.rotateY(-Math.PI / 2); return g;
}
projGeo.crescent = crescentGeo();

export function spawnProjectile(o) {
  let mesh;
  const color = new THREE.Color(o.color || '#ffffff');
  if (o.kind === 'crescent') {
    mesh = new THREE.Group();
    const m1 = new THREE.Mesh(projGeo.crescent, new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(3), transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, depthWrite: false, toneMapped: false }));
    const m2 = m1.clone(); m2.material = m1.material.clone(); m2.material.color = new THREE.Color(o.color2 || '#ffd27a').multiplyScalar(2.5); m2.rotation.z = Math.PI / 2; m2.scale.setScalar(0.8);
    mesh.add(m1, m2); mesh.scale.setScalar(o.scale || 1);
  } else if (o.kind === 'bolt' || o.kind === 'arrow') {
    mesh = new THREE.Mesh(projGeo.bolt, o.glow ? glowMat(o.color || '#ffffff', 3) : new THREE.MeshBasicMaterial({ color: '#d8c8a8' }));
  } else if (o.kind === 'spear') {
    mesh = new THREE.Mesh(projGeo.spear, new THREE.MeshStandardMaterial({ color: '#cfefff', emissive: '#3a9ad8', emissiveIntensity: 1.2, roughness: 0.1, flatShading: true }));
    mesh.scale.setScalar(o.scale || 1);
  } else {
    mesh = new THREE.Mesh(projGeo.orb, glowMat(o.color || '#ffffff', 2.5)); mesh.scale.setScalar(o.scale || 1);
  }
  mesh.position.copy(o.pos);
  G.scene.add(mesh);
  const p = { mesh, pos: mesh.position, vel: o.vel.clone(), team: o.team, dmg: o.dmg, radius: o.radius || 0.4, life: o.life || 3, src: o.src,
    pierce: o.pierce || false, hit: new Set(), homing: o.homing || 0, target: o.target, trail: o.trail, onHit: o.onHit, gravity: o.gravity || 0,
    knock: o.knock ?? 3, element: o.element, heavy: o.heavy, spin: o.spin, crit: o.crit, onExpire: o.onExpire, color: o.color, furyGain: o.furyGain };
  G.projectiles.push(p);
  return p;
}

// ---------------------------------------------------------------------
//  Zonas perigosas (fogo, chamas azuis...)
// ---------------------------------------------------------------------
export function addHazard(o) {
  const h = { pos: o.pos.clone(), radius: o.radius || 1.5, dps: o.dps || 10, life: o.life || 5, team: o.team || 'enemy', t: 0, tick: 0, kind: o.kind || 'fire', src: o.src, pull: o.pull || 0, vel: o.vel ? o.vel.clone() : null, follow: o.follow };
  // visual de base
  const col = o.kind === 'blueflame' ? '#3a8aff' : o.kind === 'wind' ? '#c8d8f0' : o.kind === 'water' ? '#40a0ff' : '#ff5a10';
  const mat = new THREE.MeshBasicMaterial({ map: T.get('telegraph'), color: new THREE.Color(col).multiplyScalar(1.2), transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
  h.mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
  h.mesh.rotation.x = -Math.PI / 2; h.mesh.position.copy(h.pos); h.mesh.position.y = 0.06; h.mesh.scale.setScalar(h.radius);
  G.scene.add(h.mesh);
  G.hazards.push(h);
  return h;
}

// ---------------------------------------------------------------------
//  Atualização dos sistemas
// ---------------------------------------------------------------------
const _tmp = new V3();
export function updateSystems(dt) {
  updateTimers(dt);
  // áreas com atraso
  for (let i = G.areas.length - 1; i >= 0; i--) {
    const a = G.areas[i]; a.t += dt;
    if (a.t >= a.delay) { G.areas.splice(i, 1); triggerArea(a); }
  }
  // projéteis
  for (let i = G.projectiles.length - 1; i >= 0; i--) {
    const p = G.projectiles[i];
    p.life -= dt;
    if (p.homing && p.target && p.target.alive) {
      _tmp.copy(p.target.pos); _tmp.y += 1.1; _tmp.sub(p.pos).normalize().multiplyScalar(p.vel.length());
      p.vel.lerp(_tmp, Math.min(1, p.homing * dt));
    }
    p.vel.y -= p.gravity * dt;
    p.pos.addScaledVector(p.vel, dt);
    if (p.vel.lengthSq() > 0.01) { _tmp.copy(p.pos).add(p.vel); p.mesh.lookAt(_tmp); }
    if (p.spin) p.mesh.rotateZ(p.spin * dt);
    if (p.trail) p.trail(p, dt);
    let dead = p.life <= 0 || p.pos.y < -0.5;
    // limites
    const b = G.level && G.level.bounds;
    if (b && !dead) {
      if (b.type === 'circle' && Math.hypot(p.pos.x - (b.cx || 0), p.pos.z - (b.cz || 0)) > b.r + 1) dead = true;
      if (b.type === 'box' && (p.pos.x < b.minX - 1 || p.pos.x > b.maxX + 1 || p.pos.z < b.minZ - 1 || p.pos.z > b.maxZ + 1)) dead = true;
    }
    if (!dead) for (const t of G.actors) {
      if (!t.alive || t.team === p.team || t.team === 'neutral' || p.hit.has(t)) continue;
      const h = t.rig ? t.rig.height : 1.8;
      if (Math.hypot(t.pos.x - p.pos.x, t.pos.z - p.pos.z) < t.radius + p.radius && p.pos.y > t.pos.y - 0.2 && p.pos.y < t.pos.y + h + 0.3) {
        p.hit.add(t);
        const ok = damage(p.src, t, p.dmg, { knock: p.knock, from: p.pos.clone().sub(p.vel.clone().setY(0).normalize()), element: p.element, heavy: p.heavy, crit: p.crit, furyGain: p.furyGain });
        p.onHit && p.onHit(p, t, ok);
        if (!p.pierce) { dead = true; break; }
      }
    }
    if (dead) {
      p.onExpire && p.onExpire(p);
      G.scene.remove(p.mesh); G.projectiles.splice(i, 1);
    }
  }
  // perigos
  for (let i = G.hazards.length - 1; i >= 0; i--) {
    const h = G.hazards[i]; h.t += dt; h.tick -= dt;
    if (h.vel) h.pos.addScaledVector(h.vel, dt);
    if (h.follow && h.follow.alive) { _tmp.copy(h.follow.pos).sub(h.pos).setY(0); if (_tmp.length() > 0.1) h.pos.addScaledVector(_tmp.normalize(), dt * 2.2); }
    h.mesh.position.set(h.pos.x, 0.06, h.pos.z);
    const fade = Math.min(1, h.t * 3) * Math.min(1, (h.life - h.t) * 2);
    h.mesh.material.opacity = 0.45 * fade;
    // partículas
    if (Math.random() < dt * 30 * h.radius) {
      const q = h.pos.clone().add(new V3(rnd(-1, 1) * h.radius * 0.8, 0, rnd(-1, 1) * h.radius * 0.8));
      if (h.kind === 'fire') G.fx.burst('fire', q, { n: 1, r: 0.1 });
      else if (h.kind === 'blueflame') G.fx.burst('fire', q, { n: 1, r: 0.1, color: '#c0e0ff', color2: '#1040ff' });
      else if (h.kind === 'wind') G.fx.burst('wind', h.pos, { n: 2, r: h.radius, h: 4 });
      else if (h.kind === 'water') G.fx.burst('water', q, { n: 1 });
      else if (h.kind === 'shadow') G.fx.burst('shadow', q, { n: 1 });
    }
    for (const t of G.actors) {
      if (!t.alive || t.team === h.team || t.team === 'neutral') continue;
      const d = dist2D(t.pos, h.pos);
      if (h.pull && d < h.radius * 2.2 && d > 0.3) { _tmp.copy(h.pos).sub(t.pos).setY(0).normalize(); t.pos.addScaledVector(_tmp, h.pull * dt); }
      if (d < h.radius + t.radius * 0.5 && h.tick <= 0) damage(h.src || t, t, h.dps * 0.33, { knock: 0.5, fx: false, vol: 0.4, unblockable: true, numColor: h.kind === 'blueflame' ? '#7ab0ff' : '#ffa060' });
    }
    if (h.tick <= 0) h.tick = 0.33;
    if (h.t >= h.life) { G.scene.remove(h.mesh); h.mesh.geometry.dispose(); h.mesh.material.dispose(); G.hazards.splice(i, 1); }
  }
}

export function clearSystems() {
  for (const p of G.projectiles) G.scene && G.scene.remove(p.mesh);
  for (const h of G.hazards) G.scene && G.scene.remove(h.mesh);
  G.projectiles = []; G.hazards = []; G.areas = []; G.timers = [];
}
