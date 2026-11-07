// =====================================================================
//  Efeitos visuais: partículas, cortes, ondas, avisos, luzes
// =====================================================================
import * as THREE from 'three';
import { T } from './textures.js';

const rnd = (a, b) => a + Math.random() * (b - a);
const _v = new THREE.Vector3();

class ParticlePool {
  constructor(scene, max, blending, tex) {
    this.max = max; this.n = 0;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(max * 3); this.col = new Float32Array(max * 3);
    this.alpha = new Float32Array(max); this.size = new Float32Array(max);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('pcolor', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e5);
    this.mat = new THREE.ShaderMaterial({
      uniforms: { map: { value: tex }, uScale: { value: 600 } },
      vertexShader: `attribute float size; attribute float alpha; attribute vec3 pcolor; varying float vA; varying vec3 vC;
        uniform float uScale;
        void main(){ vec4 mv = modelViewMatrix * vec4(position,1.0); gl_Position = projectionMatrix * mv;
          gl_PointSize = size * uScale / max(0.1, -mv.z); vA = alpha; vC = pcolor; }`,
      fragmentShader: `uniform sampler2D map; varying float vA; varying vec3 vC;
        void main(){ vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vC * t.rgb, t.a * vA); if(gl_FragColor.a < 0.003) discard; }`,
      transparent: true, depthWrite: false, blending,
    });
    this.points = new THREE.Points(g, this.mat); this.points.frustumCulled = false;
    this.points.renderOrder = blending === THREE.AdditiveBlending ? 10 : 9;
    scene.add(this.points);
    // dados
    this.vel = new Float32Array(max * 3); this.life = new Float32Array(max); this.maxLife = new Float32Array(max);
    this.s0 = new Float32Array(max); this.s1 = new Float32Array(max);
    this.c0 = new Float32Array(max * 3); this.c1 = new Float32Array(max * 3);
    this.grav = new Float32Array(max); this.drag = new Float32Array(max); this.a0 = new Float32Array(max);
  }
  emit(p, v, life, s0, s1, c0, c1, grav = 0, drag = 0, a0 = 1) {
    if (this.n >= this.max) return;
    const i = this.n++, i3 = i * 3;
    this.pos[i3] = p.x; this.pos[i3 + 1] = p.y; this.pos[i3 + 2] = p.z;
    this.vel[i3] = v.x; this.vel[i3 + 1] = v.y; this.vel[i3 + 2] = v.z;
    this.life[i] = this.maxLife[i] = life; this.s0[i] = s0; this.s1[i] = s1;
    this.c0[i3] = c0.r; this.c0[i3 + 1] = c0.g; this.c0[i3 + 2] = c0.b;
    this.c1[i3] = c1.r; this.c1[i3 + 1] = c1.g; this.c1[i3 + 2] = c1.b;
    this.grav[i] = grav; this.drag[i] = drag; this.a0[i] = a0;
  }
  update(dt) {
    let i = 0;
    while (i < this.n) {
      this.life[i] -= dt;
      if (this.life[i] <= 0) { this._swap(i, --this.n); continue; }
      const i3 = i * 3, f = 1 - this.life[i] / this.maxLife[i];
      const d = Math.max(0, 1 - this.drag[i] * dt);
      this.vel[i3] *= d; this.vel[i3 + 1] = this.vel[i3 + 1] * d - this.grav[i] * dt; this.vel[i3 + 2] *= d;
      this.pos[i3] += this.vel[i3] * dt; this.pos[i3 + 1] += this.vel[i3 + 1] * dt; this.pos[i3 + 2] += this.vel[i3 + 2] * dt;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * f;
      for (let k = 0; k < 3; k++) this.col[i3 + k] = this.c0[i3 + k] + (this.c1[i3 + k] - this.c0[i3 + k]) * f;
      this.alpha[i] = this.a0[i] * Math.min(1, f * 12) * (1 - f * f);
      i++;
    }
    const g = this.points.geometry;
    g.setDrawRange(0, this.n);
    for (const k of ['position', 'pcolor', 'alpha', 'size']) g.attributes[k].needsUpdate = true;
  }
  _swap(a, b) {
    if (a === b) return;
    const A = [this.pos, this.vel, this.c0, this.c1, this.col], S1 = [this.life, this.maxLife, this.s0, this.s1, this.grav, this.drag, this.a0, this.size, this.alpha];
    for (const arr of A) for (let k = 0; k < 3; k++) arr[a * 3 + k] = arr[b * 3 + k];
    for (const arr of S1) arr[a] = arr[b];
  }
  clear() { this.n = 0; }
}

// arco para cortes (u ao longo do ângulo)
function arcGeometry(r0, r1, theta, seg = 24) {
  const pos = [], uv = [], idx = [];
  for (let i = 0; i <= seg; i++) {
    const t = i / seg, a = -theta / 2 + theta * t;
    for (let j = 0; j < 2; j++) {
      const r = j ? r1 : r0;
      pos.push(Math.sin(a) * r, 0, Math.cos(a) * r); uv.push(t, j);
    }
    if (i < seg) { const b = i * 2; idx.push(b, b + 1, b + 2, b + 1, b + 3, b + 2); }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx); return g;
}

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.add = new ParticlePool(scene, 6000, THREE.AdditiveBlending, T.get('spark'));
    this.glowP = new ParticlePool(scene, 2500, THREE.AdditiveBlending, T.get('glow'));
    this.norm = new ParticlePool(scene, 2500, THREE.NormalBlending, T.get('smoke'));
    this.items = [];
    this.lights = [];
    for (let i = 0; i < 5; i++) { const l = new THREE.PointLight(0xffffff, 0, 8, 2); l.userData.t = 0; scene.add(l); this.lights.push(l); }
    this.slashGeo = arcGeometry(0.55, 1.45, 2.6);
    this.slashGeoBig = arcGeometry(0.8, 2.6, 3.2);
    this.decals = [];
  }
  setScale(s) { for (const p of [this.add, this.glowP, this.norm]) p.mat.uniforms.uScale.value = s; }

  // ---------- partículas pré-definidas ----------
  burst(type, p, o = {}) {
    const n = o.n ?? 12, C = (c) => new THREE.Color(c);
    const dir = o.dir;
    for (let i = 0; i < n; i++) {
      const rv = () => _v.set(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)).normalize();
      switch (type) {
        case 'spark': {
          const v = rv().multiplyScalar(rnd(3, 9)); if (dir) v.addScaledVector(dir, 5); v.y += 2;
          this.add.emit(p, v, rnd(0.2, 0.5), rnd(0.06, 0.12), 0.01, C(o.color || '#fff2c0').multiplyScalar(3), C(o.color2 || '#ff6a10').multiplyScalar(2), 14, 2);
          break; }
        case 'blood': {
          const v = rv().multiplyScalar(rnd(1.5, 4.5)); if (dir) v.addScaledVector(dir, 3); v.y += 2;
          this.norm.emit(p, v, rnd(0.4, 0.8), rnd(0.07, 0.14), 0.04, C('#6a0008'), C('#2a0004'), 12, 1, 0.95);
          break; }
        case 'fire': {
          const q = _v.set(p.x + rnd(-1, 1) * (o.r || 0.2), p.y + rnd(0, 0.2), p.z + rnd(-1, 1) * (o.r || 0.2)).clone();
          this.glowP.emit(q, new THREE.Vector3(rnd(-0.4, 0.4), rnd(1.5, 3.5) * (o.up ?? 1), rnd(-0.4, 0.4)), rnd(0.4, 0.9), rnd(0.25, 0.5) * (o.size || 1), 0.05,
            C(o.color || '#ffcf60').multiplyScalar(2.5), C(o.color2 || '#ff2a00').multiplyScalar(1.2), -1, 1.5);
          break; }
        case 'smoke': {
          const q = _v.set(p.x + rnd(-1, 1) * (o.r || 0.3), p.y, p.z + rnd(-1, 1) * (o.r || 0.3)).clone();
          this.norm.emit(q, new THREE.Vector3(rnd(-0.5, 0.5), rnd(0.4, 1.4), rnd(-0.5, 0.5)), rnd(1, 2), rnd(0.4, 0.8) * (o.size || 1), rnd(1.2, 2.2) * (o.size || 1), C(o.color || '#2a2a30'), C(o.color2 || '#101014'), -0.2, 0.6, o.alpha ?? 0.55);
          break; }
        case 'dust': {
          const v = new THREE.Vector3(rnd(-1, 1), 0, rnd(-1, 1)).normalize().multiplyScalar(rnd(1, 4) * (o.speed || 1)); v.y = rnd(0.2, 1.2);
          this.norm.emit(p, v, rnd(0.6, 1.2), rnd(0.3, 0.6) * (o.size || 1), rnd(1, 1.8) * (o.size || 1), C(o.color || '#6a5a48'), C('#3a3028'), 0.5, 2.5, 0.5);
          break; }
        case 'magic': {
          const v = rv().multiplyScalar(rnd(0.5, 3) * (o.speed || 1)); if (dir) v.addScaledVector(dir, 3);
          this.glowP.emit(p, v, rnd(0.4, 0.9), rnd(0.12, 0.3) * (o.size || 1), 0.02, C(o.color || '#b070ff').multiplyScalar(3), C(o.color2 || '#40e0ff').multiplyScalar(2), o.grav ?? -0.5, 2);
          break; }
        case 'ice': {
          const v = rv().multiplyScalar(rnd(2, 6) * (o.speed || 1)); v.y += 1.5;
          this.add.emit(p, v, rnd(0.3, 0.7), rnd(0.06, 0.14), 0.02, C('#ffffff').multiplyScalar(3), C('#40b0ff').multiplyScalar(2), 10, 1.5);
          if (i % 2) this.glowP.emit(p, v.clone().multiplyScalar(0.4), rnd(0.4, 0.8), rnd(0.2, 0.4), 0.05, C('#a0e8ff').multiplyScalar(1.5), C('#2060ff'), 0, 2);
          break; }
        case 'shadow': {
          const v = rv().multiplyScalar(rnd(0.3, 1.5) * (o.speed || 1)); v.y = Math.abs(v.y) + 0.5;
          this.norm.emit(p.clone().add(_v.set(rnd(-1, 1), rnd(-0.2, 1), rnd(-1, 1)).multiplyScalar(o.r || 0.3)), v, rnd(0.6, 1.4), rnd(0.3, 0.6) * (o.size || 1), rnd(0.8, 1.4) * (o.size || 1), C(o.color || '#08040c'), C('#000000'), -0.4, 1.2, 0.85);
          break; }
        case 'heal': {
          const q = p.clone().add(_v.set(rnd(-0.4, 0.4), rnd(0, 1.6), rnd(-0.4, 0.4)));
          this.glowP.emit(q, new THREE.Vector3(0, rnd(0.6, 1.6), 0), rnd(0.6, 1.2), rnd(0.1, 0.2), 0.02, C(o.color || '#80ff90').multiplyScalar(2), C(o.color2 || '#20a040'), -0.3, 0.5);
          break; }
        case 'water': {
          const v = rv().multiplyScalar(rnd(2, 6)); v.y = Math.abs(v.y) * 2 + 2;
          this.glowP.emit(p, v, rnd(0.4, 0.9), rnd(0.1, 0.22), 0.03, C('#a8e0ff').multiplyScalar(1.6), C('#2060c0'), 12, 0.5);
          break; }
        case 'wind': {
          const a = rnd(0, Math.PI * 2), r = rnd(0.5, o.r || 2.5);
          const q = new THREE.Vector3(p.x + Math.cos(a) * r, p.y + rnd(0, o.h || 3), p.z + Math.sin(a) * r);
          const v = new THREE.Vector3(-Math.sin(a), 0.4, Math.cos(a)).multiplyScalar(rnd(4, 8));
          this.norm.emit(q, v, rnd(0.4, 0.8), rnd(0.2, 0.4), rnd(0.6, 1.0), C('#c8d8e8'), C('#8090a0'), -0.5, 1, 0.35);
          break; }
        case 'gold': {
          const q = p.clone().add(_v.set(rnd(-1, 1), rnd(-0.5, 1.5), rnd(-1, 1)).multiplyScalar(o.r || 0.5));
          this.glowP.emit(q, new THREE.Vector3(rnd(-0.3, 0.3), rnd(0.3, 1), rnd(-0.3, 0.3)), rnd(0.8, 1.6), rnd(0.08, 0.18) * (o.size || 1), 0.01, C(o.color || '#ffd070').multiplyScalar(2.5), C(o.color2 || '#ff9020'), -0.2, 0.5);
          break; }
        case 'petal': {
          const q = p.clone().add(_v.set(rnd(-1, 1) * (o.r || 6), rnd(0, 3), rnd(-1, 1) * (o.r || 6)));
          this.norm.emit(q, new THREE.Vector3(rnd(-0.6, 0.6), rnd(-0.4, 0.1), rnd(-0.6, 0.6)), rnd(3, 6), 0.08, 0.06, C('#a01020'), C('#500008'), 0.05, 0.1, 0.9);
          break; }
        case 'ember': {
          const q = p.clone().add(_v.set(rnd(-1, 1) * (o.r || 6), rnd(0, 0.5), rnd(-1, 1) * (o.r || 6)));
          this.add.emit(q, new THREE.Vector3(rnd(-0.3, 0.3), rnd(0.3, 1.0), rnd(-0.3, 0.3)), rnd(2, 4), rnd(0.03, 0.06), 0.01, C(o.color || '#ffa040').multiplyScalar(3), C(o.color2 || '#ff2000'), -0.05, 0.1);
          break; }
        case 'mote': {
          const q = p.clone().add(_v.set(rnd(-1, 1) * (o.r || 8), rnd(0, 4), rnd(-1, 1) * (o.r || 8)));
          this.glowP.emit(q, new THREE.Vector3(rnd(-0.2, 0.2), rnd(-0.1, 0.2), rnd(-0.2, 0.2)), rnd(3, 6), rnd(0.05, 0.12), 0.01, C(o.color || '#8090ff').multiplyScalar(1.5), C(o.color2 || '#4050a0'), 0, 0);
          break; }
      }
    }
  }

  // ---------- corte (arco luminoso) ----------
  slash(pos, yaw, o = {}) {
    const mat = new THREE.MeshBasicMaterial({
      map: T.get('slash'), color: new THREE.Color(o.color || '#bfe8ff').multiplyScalar(o.intensity || 2.2),
      transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false,
    });
    const m = new THREE.Mesh(o.big ? this.slashGeoBig : this.slashGeo, mat);
    m.position.copy(pos);
    m.rotation.order = 'YXZ';
    m.rotation.set(o.pitch || 0, yaw, o.roll || 0);
    m.scale.setScalar(o.scale || 1);
    if (o.flip) m.scale.x *= -1;
    this.scene.add(m);
    // segundo arco escuro (contraste anime)
    let m2 = null;
    if (o.dark) {
      const mat2 = new THREE.MeshBasicMaterial({ map: T.get('slash'), color: '#000', transparent: true, opacity: 0.6, depthWrite: false, side: THREE.DoubleSide });
      m2 = new THREE.Mesh(m.geometry, mat2); m2.position.copy(pos); m2.rotation.copy(m.rotation); m2.scale.copy(m.scale).multiplyScalar(1.06); this.scene.add(m2);
    }
    const life = o.life || 0.22, sweep = o.sweep ?? 0.9;
    this.items.push({ t: 0, life, update: (it, dt) => {
      const f = it.t / life;
      mat.opacity = Math.max(0, 1 - f * f);
      m.rotation.y = yaw + (o.flip ? 1 : -1) * sweep * (f - 0.5) * 0.6;
      if (m2) { m2.material.opacity = 0.6 * (1 - f); m2.rotation.y = m.rotation.y; }
      const s = (o.scale || 1) * (1 + f * 0.15); m.scale.set(o.flip ? -s : s, s, s);
    }, dispose: () => { this.scene.remove(m); mat.dispose(); if (m2) { this.scene.remove(m2); m2.material.dispose(); } } });
  }

  // ---------- onda de choque no chão ----------
  ring(pos, o = {}) {
    const mat = new THREE.MeshBasicMaterial({ map: T.get('ring'), color: new THREE.Color(o.color || '#ffd080').multiplyScalar(o.intensity || 2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, side: THREE.DoubleSide });
    const m = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
    m.rotation.x = -Math.PI / 2; m.position.copy(pos); m.position.y += 0.05;
    if (o.vertical) { m.rotation.set(0, o.yaw || 0, 0); }
    this.scene.add(m);
    const life = o.life || 0.5, r0 = o.r0 ?? 0.2, r1 = o.r1 ?? 4;
    this.items.push({ t: 0, life, update: (it) => {
      const f = it.t / life, e = 1 - Math.pow(1 - f, 3);
      m.scale.setScalar(r0 + (r1 - r0) * e); mat.opacity = 1 - f;
    }, dispose: () => { this.scene.remove(m); m.geometry.dispose(); mat.dispose(); } });
  }
  sphere(pos, o = {}) {
    const mat = new THREE.MeshBasicMaterial({ color: new THREE.Color(o.color || '#ffffff').multiplyScalar(o.intensity || 2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
    const m = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), mat); m.position.copy(pos); this.scene.add(m);
    const life = o.life || 0.4, r0 = o.r0 ?? 0.2, r1 = o.r1 ?? 2;
    this.items.push({ t: 0, life, update: (it) => { const f = it.t / life; m.scale.setScalar(r0 + (r1 - r0) * (1 - Math.pow(1 - f, 2))); mat.opacity = (1 - f) * (o.opacity ?? 0.8); },
      dispose: () => { this.scene.remove(m); m.geometry.dispose(); mat.dispose(); } });
  }
  // feixe entre dois pontos
  beam(a, b, o = {}) {
    const mat = new THREE.MeshBasicMaterial({ color: new THREE.Color(o.color || '#ff3050').multiplyScalar(o.intensity || 3), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
    const len = a.distanceTo(b);
    const m = new THREE.Mesh(new THREE.CylinderGeometry(o.width || 0.05, o.width || 0.05, len, 8, 1, true), mat);
    m.position.copy(a).add(b).multiplyScalar(0.5);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize());
    this.scene.add(m);
    const life = o.life || 0.25;
    this.items.push({ t: 0, life, update: (it) => { const f = it.t / life; mat.opacity = 1 - f; m.scale.x = m.scale.z = 1 + f * 2; },
      dispose: () => { this.scene.remove(m); m.geometry.dispose(); mat.dispose(); } });
  }
  // espinho de gelo subindo do chão
  iceSpike(pos, o = {}) {
    const h = o.h || rnd(1.2, 2.2), r = o.r || rnd(0.18, 0.32);
    const mat = new THREE.MeshStandardMaterial({ color: o.black ? '#0a1a2a' : '#bfe8ff', emissive: o.black ? '#102040' : '#2a7ab0', emissiveIntensity: 0.6, roughness: 0.1, metalness: 0.2, transparent: true, opacity: 0.9, flatShading: true });
    const m = new THREE.Mesh(new THREE.ConeGeometry(r, h, 5), mat);
    m.position.copy(pos); m.position.y = (pos.y || 0) - h / 2;
    m.rotation.set(rnd(-0.25, 0.25), rnd(0, 6), rnd(-0.25, 0.25));
    m.castShadow = true; this.scene.add(m);
    const life = o.life || 1.6, base = m.position.y;
    this.items.push({ t: 0, life, update: (it) => {
      const t = it.t;
      if (t < 0.12) m.position.y = base + h * (t / 0.12);
      else m.position.y = base + h;
      if (t > life - 0.3) { mat.opacity = Math.max(0, (life - t) / 0.3) * 0.9; m.scale.setScalar(1 + (t - life + 0.3)); }
    }, dispose: () => { this.scene.remove(m); m.geometry.dispose(); mat.dispose(); if (!o.silent) this.burst('ice', m.position.clone().setY(base + h * 0.7), { n: 6 }); } });
  }

  // ---------- decalque de aviso ----------
  telegraph(pos, o = {}) {
    let geo;
    if (o.shape === 'cone') geo = new THREE.CircleGeometry(1, 24, -Math.PI / 2 - o.angle / 2, o.angle);
    else if (o.shape === 'rect') { geo = new THREE.PlaneGeometry(o.width, o.length); geo.translate(0, -o.length / 2, 0); }
    else geo = new THREE.PlaneGeometry(2, 2);
    const mat = new THREE.MeshBasicMaterial({ map: o.shape ? null : T.get('telegraph'), color: new THREE.Color(o.color || '#ff2a20').multiplyScalar(1.6), transparent: true, opacity: 0.0, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, side: THREE.DoubleSide });
    const grp = new THREE.Group();
    grp.position.copy(pos); grp.position.y = (pos.y || 0) + 0.04; grp.rotation.y = o.yaw || 0;
    const m = new THREE.Mesh(geo, mat); m.rotation.x = -Math.PI / 2; grp.add(m);
    const R = o.radius || 1;
    if (o.shape !== 'rect') m.scale.setScalar(R);
    // preenchimento crescente (indica o tempo)
    const solid = !!o.shape;
    const fillMat = mat.clone(); fillMat.opacity = solid ? 0.16 : 0.35;
    const fill = new THREE.Mesh(geo, fillMat); fill.rotation.x = -Math.PI / 2; fill.position.y = 0.005; grp.add(fill);
    this.scene.add(grp);
    const life = o.time || 1;
    const item = { t: 0, life, group: grp, update: (it) => {
      const f = Math.min(1, it.t / life);
      mat.opacity = solid ? 0.13 + Math.sin(it.t * 25) * 0.05 + f * 0.1 : 0.5 + Math.sin(it.t * 25) * 0.15;
      if (o.shape === 'rect') fill.scale.set(1, f, 1);
      else fill.scale.setScalar(R * f);
    }, dispose: () => { this.scene.remove(grp); geo.dispose(); mat.dispose(); fillMat.dispose(); } };
    this.items.push(item);
    return item;
  }

  // ---------- flash de luz ----------
  flash(pos, color = '#ffffff', intensity = 6, dur = 0.15, dist = 8) {
    let l = this.lights.find(l => l.userData.t <= 0) || this.lights[0];
    l.position.copy(pos); l.color.set(color); l.distance = dist; l.userData.t = dur; l.userData.dur = dur; l.userData.I = intensity; l.intensity = intensity;
  }

  // genérico: objeto com update customizado
  custom(life, update, dispose) { const it = { t: 0, life, update, dispose }; this.items.push(it); return it; }

  update(dt) {
    this.add.update(dt); this.glowP.update(dt); this.norm.update(dt);
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.t += dt;
      if (it.t >= it.life || it.kill) { it.dispose && it.dispose(); this.items.splice(i, 1); continue; }
      it.update && it.update(it, dt);
    }
    for (const l of this.lights) {
      if (l.userData.t > 0) { l.userData.t -= dt; l.intensity = l.userData.I * Math.max(0, l.userData.t / l.userData.dur); }
      else l.intensity = 0;
    }
  }
  clear() {
    for (const it of this.items) it.dispose && it.dispose();
    this.items = []; this.add.clear(); this.glowP.clear(); this.norm.clear();
  }
}
