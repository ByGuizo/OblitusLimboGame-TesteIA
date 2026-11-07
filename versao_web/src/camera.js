// =====================================================================
//  Câmera dinâmica: ombro, trava de alvo, tremor, FOV e cinemáticas
// =====================================================================
import * as THREE from 'three';
import { G, clamp, angDiff, yawTo } from './world.js';

const V3 = THREE.Vector3;
const ray = new THREE.Raycaster();
const ease = (t) => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

export class CameraCtl {
  constructor(camera) {
    this.cam = camera;
    this.yaw = 0; this.pitch = 0.22; this.dist = 4.4;
    this.trauma = 0; this.fovKick = 0; this.fovBase = 62; this.sens = 1;
    this.pos = new V3(0, 3, -5); this.look = new V3();
    this.pivot = new V3(); this.mode = 'follow';
    this.shotQ = null; this.blendBack = 0;
    this.t = 0; this.roll = 0; this.lockSide = 1;
  }
  shake(a) { this.trauma = Math.min(1, this.trauma + a); }
  kick(f) { this.fovKick = Math.max(this.fovKick, f); }
  snapBehind(yaw) { this.yaw = yaw; this.pitch = 0.2; }

  // ---- cinemática ----
  shot(o) {
    this.mode = 'cine';
    this.shotQ = {
      fromPos: this.cam.position.clone(), fromLook: this.look.clone(), fromFov: this.cam.fov,
      pos: o.pos.clone(), look: o.look.clone(), pos2: (o.pos2 || o.pos).clone(), look2: (o.look2 || o.look).clone(),
      blend: o.blend ?? 0.6, dur: o.dur ?? 3, t: 0, fov: o.fov ?? 50, fov2: o.fov2 ?? o.fov ?? 50, track: o.track, cut: o.cut,
    };
    if (o.cut) { this.shotQ.blend = 0.0001; }
  }
  release(blend = 0.8) {
    if (this.mode !== 'cine') return;
    this.mode = 'follow'; this.blendBack = blend; this.blendFrom = { pos: this.cam.position.clone(), look: this.look.clone() }; this.blendT = 0;
    this.shotQ = null;
  }

  update(dt, rdt) {
    this.t += rdt;
    const P = G.player, cam = this.cam;
    let desiredPos = new V3(), desiredLook = new V3(), fov = this.fovBase;

    if (this.mode === 'cine' && this.shotQ) {
      const s = this.shotQ; s.t += rdt;
      const tb = Math.min(1, s.t / Math.max(0.0001, s.blend));
      const td = Math.min(1, s.t / Math.max(0.0001, s.dur));
      let p = s.pos.clone().lerp(s.pos2, ease(td)), l = s.look.clone().lerp(s.look2, ease(td));
      if (s.track) { const r = s.track(s.t); if (r.pos) p = r.pos; if (r.look) l = r.look; }
      const e = ease(tb);
      desiredPos.copy(s.fromPos).lerp(p, e); desiredLook.copy(s.fromLook).lerp(l, e);
      fov = s.fromFov + ((s.fov + (s.fov2 - s.fov) * td) - s.fromFov) * e;
      cam.position.copy(desiredPos); this.look.copy(desiredLook);
    } else if (P) {
      const inp = G.input;
      if (inp && inp.locked && !G.paused) {
        this.yaw -= inp.mdx * 0.0024 * this.sens;
        this.pitch = clamp(this.pitch + inp.mdy * 0.0019 * this.sens, -0.3, 1.0);
      }
      const tgt = P.lockTarget && P.lockTarget.alive ? P.lockTarget : null;
      let dist = this.dist + (P.sprinting ? 0.5 : 0);
      if (tgt) {
        const big = tgt.big ? 1.6 : 0;
        const want = yawTo(P.pos, tgt.pos);
        this.yaw += angDiff(want, this.yaw) * (1 - Math.exp(-rdt * 6));
        const d = Math.hypot(tgt.pos.x - P.pos.x, tgt.pos.z - P.pos.z);
        const wantPitch = clamp(0.2 + big * 0.08 - d * 0.004, 0.1, 0.5);
        this.pitch += (wantPitch - this.pitch) * (1 - Math.exp(-rdt * 3));
        dist += 0.6 + big;
      } else if (P.bossNear) dist += 1.2;
      const fwd = new V3(Math.sin(this.yaw), 0, Math.cos(this.yaw));
      const right = new V3(-Math.cos(this.yaw), 0, Math.sin(this.yaw));
      const pv = P.pos.clone(); pv.y += 1.45 * (P.rig ? P.rig.scale / 0.93 : 1);
      this.pivot.lerp(pv, 1 - Math.exp(-rdt * 14));
      const shoulder = 0.55;
      desiredPos.copy(this.pivot)
        .addScaledVector(fwd, -Math.cos(this.pitch) * dist)
        .addScaledVector(right, shoulder)
        .add(new V3(0, Math.sin(this.pitch) * dist, 0));
      desiredLook.copy(this.pivot).addScaledVector(right, shoulder * 0.7).addScaledVector(fwd, 2.5);
      if (tgt) { const tl = tgt.pos.clone(); tl.y += tgt.big ? 1.6 : 1.0; desiredLook.lerp(tl, 0.35); }
      desiredLook.y -= 0.15;
      // colisão com limites da sala
      const L = G.level;
      if (L) {
        const b = L.camBounds || L.bounds;
        if (b && b.type === 'box') { desiredPos.x = clamp(desiredPos.x, b.minX + 0.4, b.maxX - 0.4); desiredPos.z = clamp(desiredPos.z, b.minZ + 0.4, b.maxZ - 0.4); }
        else if (b && b.type === 'circle') {
          const dx = desiredPos.x - (b.cx || 0), dz = desiredPos.z - (b.cz || 0), d = Math.hypot(dx, dz), m = b.r + (L.camExtra ?? 2);
          if (d > m) { desiredPos.x = (b.cx || 0) + dx / d * m; desiredPos.z = (b.cz || 0) + dz / d * m; }
        }
        if (L.camColliders && L.camColliders.length) {
          const dir = desiredPos.clone().sub(this.pivot), len = dir.length();
          ray.set(this.pivot, dir.normalize()); ray.far = len;
          const hit = ray.intersectObjects(L.camColliders, false)[0];
          if (hit) desiredPos.copy(this.pivot).addScaledVector(dir, Math.max(0.6, hit.distance - 0.35));
        }
        if (L.ceiling) desiredPos.y = Math.min(desiredPos.y, L.ceiling - 0.4);
        desiredPos.y = Math.max(desiredPos.y, (L.floorY || 0) + 0.4);
      }
      if (this.blendBack > 0) {
        this.blendT += rdt;
        const e = ease(Math.min(1, this.blendT / this.blendBack));
        desiredPos = this.blendFrom.pos.clone().lerp(desiredPos, e);
        desiredLook = this.blendFrom.look.clone().lerp(desiredLook, e);
        if (e >= 1) this.blendBack = 0;
        cam.position.copy(desiredPos); this.look.copy(desiredLook);
      } else {
        const k = 1 - Math.exp(-rdt * 18);
        cam.position.lerp(desiredPos, k); this.look.lerp(desiredLook, k);
      }
      fov = this.fovBase + (P.sprinting ? 7 : 0) + (tgt ? -3 : 0);
    }

    // tremor
    this.trauma = Math.max(0, this.trauma - rdt * 1.6);
    const sh = this.trauma * this.trauma;
    const t = this.t * 40;
    const off = new V3(Math.sin(t * 1.1) + Math.sin(t * 2.3) * 0.5, Math.sin(t * 1.7 + 3) + Math.sin(t * 3.1) * 0.4, Math.sin(t * 1.3 + 7)).multiplyScalar(sh * 0.22);
    this.fovKick = Math.max(0, this.fovKick - rdt * 30);
    cam.fov += ((fov + this.fovKick) - cam.fov) * (1 - Math.exp(-rdt * 8));
    cam.updateProjectionMatrix();
    const lookAt = this.look.clone().add(off);
    cam.position.add(off.multiplyScalar(0.6));
    cam.lookAt(lookAt);
    cam.rotateZ(Math.sin(t * 0.9) * sh * 0.05);
  }
}
