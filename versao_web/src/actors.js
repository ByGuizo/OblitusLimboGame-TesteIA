// =====================================================================
//  Atores: jogador, inimigos, chefes, aliados e NPCs
// =====================================================================
import * as THREE from 'three';
import { Animator, buildCharacter, updateCloth, Tentacle, glowMat, CLIPS } from './models.js';
import { T } from './textures.js';
import { G, damage, areaAttack, spawnProjectile, addHazard, nearestEnemy, enemiesOf, angDiff, yawTo, dist2D, fwd, rnd, clamp, resolveCollision, emit, after } from './world.js';
const later = (fn, ms) => after(ms / 1000, fn);
import { Audio } from './audio.js';

const V3 = THREE.Vector3;
const up = new V3(0, 1, 0);
const rightOf = (yaw) => new V3(-Math.cos(yaw), 0, Math.sin(yaw));

// =====================================================================
//  ATOR BASE
// =====================================================================
export class Actor {
  constructor(id, o = {}) {
    this.id = id;
    this.rig = o.rig || buildCharacter(id, o.rigOpts || {});
    this.anim = new Animator(this.rig);
    this.root = this.rig.root; this.pos = this.root.position;
    if (o.pos) this.pos.copy(o.pos);
    this.yaw = o.yaw || 0; this.team = o.team || 'enemy'; this.name = o.name || id;
    this.hp = this.maxHp = o.hp || 100; this.alive = true;
    this.radius = o.radius || 0.42; this.mass = o.mass || 1;
    this.vel = new V3(); this.knock = new V3(); this.speed = 0;
    this.iframes = 0; this.hitFlash = 0; this.state = 'idle'; this.stateT = 0;
    this.knockResist = o.knockResist ?? 1;
    this.flashMats = [];
    this.rig.root.traverse(m => {
      if (m.isMesh && m.material && m.material.isMeshToonMaterial) {
        m.material = m.material.clone(); m.material.userData.baseEm = m.material.emissive.clone();
        this.flashMats.push(m.material);
      }
    });
    this.root.rotation.y = this.yaw;
    G.scene.add(this.root);
    G.actors.push(this);
  }
  get forward() { return fwd(this.yaw); }
  setState(s) { this.state = s; this.stateT = 0; }
  faceTo(target, dt, rate = 10) {
    const want = typeof target === 'number' ? target : yawTo(this.pos, target);
    const d = angDiff(want, this.yaw);
    this.yaw += clamp(d, -rate * dt, rate * dt);
  }
  move(dir, speed, dt, accel = 12) {
    const tx = dir.x * speed, tz = dir.z * speed, k = 1 - Math.exp(-accel * dt);
    this.vel.x += (tx - this.vel.x) * k; this.vel.z += (tz - this.vel.z) * k;
  }
  baseUpdate(dt, animOpts = {}) {
    const kd = Math.exp(-dt * 7);
    this.knock.multiplyScalar(kd);
    this.pos.x += (this.vel.x + this.knock.x) * dt;
    this.pos.z += (this.vel.z + this.knock.z) * dt;
    if (!this.flying) this.pos.y += ((G.level && G.level.floorY || 0) - this.pos.y) * Math.min(1, dt * 10);
    if (!this.noCollide) resolveCollision(this);
    this.root.rotation.y = this.yaw;
    this.speed = Math.hypot(this.vel.x, this.vel.z);
    this.stateT += dt; this.stateTime = this.stateT;
    this.anim.update(dt, this.alive ? this.speed : 0, animOpts);
    updateCloth(this.rig, dt, this.speed, G.time);
    if (this.hitFlash > 0) {
      this.hitFlash -= dt;
      const f = Math.max(0, this.hitFlash / 0.12);
      for (const m of this.flashMats) m.emissive.copy(m.userData.baseEm).lerp(this.flashColor || new THREE.Color(1, 1, 1), f * 0.85);
      if (this.hitFlash <= 0) for (const m of this.flashMats) m.emissive.copy(m.userData.baseEm);
    }
    if (this.iframes > 0) this.iframes -= dt;
  }
  remove() {
    this.alive = false;
    G.scene.remove(this.root);
    G.actors = G.actors.filter(a => a !== this);
  }
  headPos(off = 0) { return this.pos.clone().add(new V3(0, this.rig.height * 0.92 + off, 0)); }
  chestPos() { return this.pos.clone().add(new V3(0, this.rig.height * 0.65, 0)); }
}

// =====================================================================
//  JOGADOR
// =====================================================================
const KITS = {
  kiana: {
    name: 'Kiana', hp: 100, color: '#bfe8ff', speed: 5.1, sprint: 7.8,
    combo: [
      { clip: 'atk1', dmg: 12, range: 2.3, arc: 2.1, slash: { roll: -0.25 } },
      { clip: 'atk2', dmg: 13, range: 2.3, arc: 2.1, slash: { roll: 0.75, flip: true } },
      { clip: 'atk3', dmg: 24, range: 2.7, arc: 1.4, heavy: true, lunge: 6, slash: { roll: 1.5, big: true, scale: 0.9 } },
      { clip: 'spin', dmg: 20, range: 2.8, arc: 6.3, heavy: true, slash: { roll: 0, big: true }, furyOnly: true },
    ],
  },
  viktor: {
    name: 'Viktor', hp: 160, color: '#9fe0ff', speed: 5.0, sprint: 7.5,
    combo: [
      { clip: 'punch', dmg: 17, range: 2.3, arc: 1.6, ice: true },
      { clip: 'punchL', dmg: 17, range: 2.3, arc: 1.6, ice: true },
      { clip: 'uppercut', dmg: 32, range: 2.8, arc: 1.8, heavy: true, ice: true, lunge: 4 },
    ],
  },
};

export class Player extends Actor {
  constructor(kit = 'kiana', o = {}) {
    super(kit, { ...o, team: 'player', hp: KITS[kit].hp, radius: 0.38, mass: 1.5 });
    this.kit = kit; this.K = KITS[kit];
    this.energy = this.maxEnergy = 100; this.stamina = this.maxStamina = 100; this.fury = 0;
    this.potions = 3; this.combo = 0; this.comboT = 0; this.buffer = null;
    this.cd = [0, 0, 0]; this.lockTarget = null; this.controllable = true;
    this.staminaDelay = 0; this.guardT = 0; this.guarding = false; this.sprinting = false;
    this.healT = 0; this.furyActive = 0; this.ult = null; this.exhausted = 0;
    this.anim.combat = 0; this.combatT = 0;
    this.anim.onStep = () => { if (this.speed > 1) Audio.sfx('step', { wood: G.level && G.level.surface === 'wood', vol: this.sprinting ? 1 : 0.7 }); };
    if (kit === 'viktor') {
      this.fists = [this.rig.handL, this.rig.handR].map(h => { const m = new THREE.Mesh(new THREE.SphereGeometry(0.07, 10, 8), new THREE.MeshBasicMaterial({ color: new THREE.Color('#7fd8ff').multiplyScalar(2), transparent: true, opacity: 0.5, toneMapped: false, depthWrite: false })); h.add(m); return m; });
    }
    this.skills = kit === 'kiana' ? [
      { name: 'Acorde Cortante', cost: 18, cd: 1.4, icon: 'blade' },
      { name: 'Ressonância', cost: 35, cd: 7, icon: 'wave' },
      { name: 'Passo Sombrio', cost: 25, cd: 4.5, icon: 'blink' },
    ] : [
      { name: 'Lança de Gelo', cost: 15, cd: 1.2, icon: 'spear' },
      { name: 'Floresta de Lanças', cost: 35, cd: 6, icon: 'forest' },
      { name: 'Gelo Negro', cost: 25, cd: 4.5, icon: 'blackice' },
    ];
  }
  get dmgMul() { return (this.furyActive > 0 ? 1.6 : 1) * (this.exhausted > 0 ? 0.6 : 1); }
  gainFury(v) {
    if (this.furyActive > 0 || this.ult) return;
    const before = this.fury;
    this.fury = Math.min(100, this.fury + v * (this.kit === 'viktor' ? 1.4 : 1));
    if (before < 100 && this.fury >= 100) { Audio.sfx('heartbeat'); G.ui && G.ui.toast(this.furyName() + ' PRONTO — [F]', '#ff4a3a'); }
  }
  furyName() {
    if (this.kit === 'viktor') return 'PUNHO FLAMEJANTE';
    return G.flags.harmonic ? 'MANIFESTAÇÃO HARMÔNICA' : 'APAGÃO';
  }
  stun() {}
  guardBreak() { this.guarding = false; this.anim.play('hit'); this.setState('hit'); this.stateLock = 0.8; Audio.sfx('hitHeavy'); G.ui && G.ui.toast('GUARDA QUEBRADA', '#ff8060'); }

  onHit(src, amt, o) {
    this.combatT = 4;
    if (this.ult || this.state === 'cine') return;
    if (this.state === 'dodge') return;
    if (o.fx === false || amt < 5) return;           // dano contínuo não atordoa
    if (o.heavy && amt > 12 && !this.guarding) {
      this.anim.play('knock', { speed: 1.3 }); this.setState('hit'); this.stateLock = 0.8; this.iframes = 0.8;
    } else if (!this.guarding) {
      if (this.state !== 'attack' || amt > 10) { this.anim.play('hit'); this.setState('hit'); this.stateLock = 0.28; }
    }
    Audio.sfx('hurt', { vol: 0.8 });
  }
  die() {
    if (!this.alive) return;
    this.alive = false; this.hp = 0; this.anim.play('death');
    Audio.sfx('die'); G.slow = { t: 2, scale: 0.3 };
    this.endFury();
    later(() => emit('playerDead'), 1600);
  }

  // ---- entrada ----
  update(dt) {
    const inp = G.input;
    if (!this.alive) { this.vel.multiplyScalar(0.9); this.baseUpdate(dt); return; }
    const ctl = this.controllable && !G.cine && !G.paused;
    // timers
    for (let i = 0; i < 3; i++) this.cd[i] = Math.max(0, this.cd[i] - dt);
    this.comboT -= dt; if (this.comboT <= 0) this.combo = 0;
    this.combatT -= dt; this.staminaDelay -= dt; this.exhausted -= dt;
    if (this.dodgeT !== undefined) this.dodgeT += dt;
    this.energy = Math.min(this.maxEnergy, this.energy + dt * (this.exhausted > 0 ? 2 : 7));
    if (this.staminaDelay <= 0 && !this.sprinting) this.stamina = Math.min(this.maxStamina, this.stamina + dt * (this.exhausted > 0 ? 8 : 30));
    if (this.healT > 0) { this.healT -= dt; this.hp = Math.min(this.maxHp, this.hp + dt * 32); if (Math.random() < 0.5) G.fx.burst('heal', this.pos, { n: 1 }); }
    if (this.lockTarget && !this.lockTarget.alive) { this.lockTarget = null; this.lockTarget = nearestEnemy(this, 18); }
    if (this.furyActive > 0) this.updateFury(dt);
    if (this.ult) this.updateUlt(dt);
    this.anim.combat += ((this.combatT > 0 || this.lockTarget || G.inCombat ? 1 : 0) - this.anim.combat) * Math.min(1, dt * 4);

    // movimento desejado (relativo à câmera)
    let mx = 0, mz = 0;
    if (ctl) {
      if (inp.held('KeyW')) mz += 1; if (inp.held('KeyS')) mz -= 1;
      if (inp.held('KeyA')) mx -= 1; if (inp.held('KeyD')) mx += 1;
    }
    const cy = G.cam.yaw, f = fwd(cy), r = rightOf(cy);
    const wish = new V3().addScaledVector(f, mz).addScaledVector(r, mx);
    if (wish.lengthSq() > 0) wish.normalize();
    this.wish = wish;

    // ações
    if (ctl) {
      const prev = this.buffer;
      if (inp.pressed('KeyQ') || inp.mousePressed(1)) this.toggleLock();
      if (inp.mousePressed(0)) this.buffer = 'attack';
      if (inp.pressed('Space')) this.buffer = 'dodge';
      if (inp.pressed('Digit1')) this.buffer = 's0';
      if (inp.pressed('Digit2')) this.buffer = 's1';
      if (inp.pressed('Digit3')) this.buffer = 's2';
      if (inp.pressed('KeyF')) this.buffer = 'fury';
      if (inp.pressed('KeyR') || inp.pressed('Tab')) this.usePotion();
      if (this.buffer !== prev || inp.mousePressed(0)) this.bufferT = G.time;
    }
    if (this.buffer && G.time - (this.bufferT || 0) > 0.5) this.buffer = null;
    // a fúria rompe o atordoamento
    if (this.buffer === 'fury' && this.state === 'hit' && this.fury >= 100) { this.buffer = null; this.anim.stop(); this.setState('move'); this.activateFury(); }
    this.guarding = false;
    const s = this.state;
    if (this.ult) { this.vel.multiplyScalar(0.8); }
    else if (s === 'idle' || s === 'move') {
      const guardHeld = ctl && inp.mouseHeld(2) && this.stamina > 5;
      this.sprinting = ctl && inp.held('ShiftLeft') && wish.lengthSq() > 0 && this.stamina > 1 && !guardHeld && !this.lockTarget;
      if (this.sprinting) { this.stamina -= dt * 16; this.staminaDelay = 0.5; }
      const spd = guardHeld ? 1.8 : this.sprinting ? this.K.sprint : this.K.speed;
      const mul = (this.furyActive > 0 ? 1.3 : 1) * (this.exhausted > 0 ? 0.6 : 1);
      this.move(wish, spd * mul, dt, 14);
      if (this.lockTarget) this.faceTo(this.lockTarget.pos, dt, 12);
      else if (wish.lengthSq() > 0) this.faceTo(Math.atan2(wish.x, wish.z), dt, 13);
      if (guardHeld) {
        if (!this.wasGuard) { this.guardT = 0; this.anim.play('guard'); }
        this.guarding = true; this.guardT += dt; this.combatT = 2;
        if (this.lockTarget) this.faceTo(this.lockTarget.pos, dt, 14);
        else { const n = nearestEnemy(this, 6); if (n) this.faceTo(n.pos, dt, 10); }
      } else if (this.wasGuard) this.anim.stop();
      this.wasGuard = guardHeld;
      this.consumeBuffer();
    } else if (s === 'attack') {
      this.wasGuard = false;
      const atk = this.curAtk;
      const lunge = atk && atk.lungeT > 0 ? atk.lungeSpd : 0;
      if (atk) atk.lungeT -= dt;
      this.move(this.forward, lunge, dt, 30);
      if (this.buffer && this.anim.ct >= (atk ? atk.cancelAt : 0)) {
        if (this.buffer === 'attack' && this.combo < this.comboList().length) { this.buffer = null; this.startAttack(); }
        else if (this.buffer !== 'attack') { this.anim.stop(); this.setState('move'); this.consumeBuffer(); }
      }
    } else if (s === 'dodge') {
      const t = this.stateT, sp = Math.max(0, 13 * (1 - t / 0.42));
      this.move(this.dodgeDir, sp, dt, 40);
      if (t > 0.3 && this.buffer === 'attack') { this.setState('move'); this.consumeBuffer(); }
      else if (t >= 0.42) this.setState('move');
    } else if (s === 'cast') {
      this.move(this.forward, this.castMove || 0, dt, 20);
      if (this.stateT >= this.castDur) { this.setState('move'); }
    } else if (s === 'hit') {
      this.move(wish, 0, dt, 10);
      if (this.stateT >= (this.stateLock || 0.3)) { this.setState('move'); this.consumeBuffer(); }
    } else if (s === 'cine') {
      this.vel.multiplyScalar(Math.exp(-dt * 8));
      this.wasGuard = false;
    }
    if (this.state !== 'idle' && this.state !== 'move') this.sprinting = false;
    this.baseUpdate(dt, { sprint: this.sprinting });
    // detalhes visuais
    if (this.rig.weapon && this.rig.weapon.userData.glow) this.rig.weapon.userData.glow.material.color.setScalar(1.6 + Math.sin(G.time * 4) * 0.4).multiply(new THREE.Color('#6fdcff'));
    if (this.fists) for (const fm of this.fists) { fm.scale.setScalar(1 + Math.sin(G.time * 8) * 0.1); if (Math.random() < 0.15) G.fx.burst('ice', fm.getWorldPosition(new V3()), { n: 1, speed: 0.3 }); }
    this.bossNear = G.boss && G.boss.alive && dist2D(G.boss.pos, this.pos) < 14;
  }
  comboList() { return this.K.combo.filter(c => !c.furyOnly || this.furyActive > 0); }
  consumeBuffer() {
    const b = this.buffer; if (!b) return;
    this.buffer = null;
    if (b === 'attack') this.startAttack();
    else if (b === 'dodge') this.dodge();
    else if (b === 'fury') this.activateFury();
    else if (b[0] === 's') this.useSkill(+b[1]);
  }
  toggleLock() {
    if (this.lockTarget) { this.lockTarget = null; Audio.sfx('ui', { vol: 0.5 }); return; }
    // alvo mais próximo do centro da câmera
    let best = null, bs = 1e9;
    for (const e of enemiesOf(this)) {
      const d = dist2D(e.pos, this.pos); if (d > 25) continue;
      const a = Math.abs(angDiff(yawTo(this.pos, e.pos), G.cam.yaw));
      const sc = a * 6 + d * 0.3; if (sc < bs) { bs = sc; best = e; }
    }
    this.lockTarget = best; if (best) Audio.sfx('ui', { vol: 0.7 });
  }
  autoTarget(range = 5) {
    if (this.lockTarget && this.lockTarget.alive && dist2D(this.lockTarget.pos, this.pos) < range + 3) return this.lockTarget;
    const dirYaw = this.wish && this.wish.lengthSq() > 0 ? Math.atan2(this.wish.x, this.wish.z) : this.yaw;
    let best = null, bs = 1e9;
    for (const e of enemiesOf(this)) {
      const d = dist2D(e.pos, this.pos) - e.radius; if (d > range) continue;
      const a = Math.abs(angDiff(yawTo(this.pos, e.pos), dirYaw));
      if (a > 1.6 && d > 1.5) continue;
      const sc = d + a * 2; if (sc < bs) { bs = sc; best = e; }
    }
    return best;
  }

  // ---- ataques corpo-a-corpo ----
  startAttack() {
    if (this.exhausted > 0 && this.stamina < 5) return;
    const list = this.comboList();
    if (this.combo >= list.length) this.combo = 0;
    const atk = list[this.combo];
    this.combo++; this.comboT = 0.9;
    this.setState('attack'); this.combatT = 4;
    // apagão: teleporte até o alvo distante
    let tgt = this.autoTarget(this.furyActive > 0 ? 12 : 5.5);
    if (tgt && this.furyActive > 0 && dist2D(tgt.pos, this.pos) > 3.2) this.blinkTo(tgt);
    const info = { ...atk, lungeT: 0, lungeSpd: 0, cancelAt: 0 };
    if (tgt) {
      this.yaw = yawTo(this.pos, tgt.pos);
      const d = dist2D(tgt.pos, this.pos) - tgt.radius - 0.9;
      if (d > 0.2) { info.lungeT = 0.14; info.lungeSpd = Math.min(16, d / 0.14); }
    } else if (atk.lunge) { info.lungeT = 0.18; info.lungeSpd = atk.lunge; }
    if (this.wish && this.wish.lengthSq() > 0 && !tgt) this.yaw = Math.atan2(this.wish.x, this.wish.z);
    const spd = (this.kit === 'kiana' ? 1.15 : 1.05) * (this.furyActive > 0 ? 1.45 : 1) * (this.exhausted > 0 ? 0.7 : 1);
    const hitT = Object.keys(CLIPS[atk.clip].ev || { 0.13: 1 })[0];
    info.cancelAt = (+hitT || 0.13) + 0.06;
    this.curAtk = info;
    this.anim.play(atk.clip, { speed: spd, blendIn: 0.04, onEvent: () => this.meleeHit(info), onEnd: () => { if (this.state === 'attack') this.setState('move'); } });
    Audio.sfx(atk.heavy ? 'swingHeavy' : 'swing', { delay: 0.05 });
    this.stamina = Math.max(0, this.stamina - 4); this.staminaDelay = 0.4;
  }
  meleeHit(atk) {
    const pos = this.pos, yaw = this.yaw;
    const sp = pos.clone().add(new V3(0, 1.1 * this.rig.scale / 0.93, 0)).addScaledVector(fwd(yaw), 0.2);
    const col = this.furyActive > 0 ? '#ff2a2a' : (atk.ice ? '#8fe0ff' : this.K.color);
    if (atk.slash) G.fx.slash(sp, yaw, { ...atk.slash, color: col, dark: this.furyActive > 0, intensity: this.furyActive > 0 ? 3 : 2.2 });
    if (atk.ice) {
      const hp = pos.clone().add(new V3(0, 1.3, 0)).addScaledVector(fwd(yaw), 1.2);
      G.fx.burst('ice', hp, { n: atk.heavy ? 22 : 10 });
      G.fx.sphere(hp, { color: '#9fe0ff', r1: atk.heavy ? 1.6 : 0.8, life: 0.25, opacity: 0.5 });
      Audio.sfx('ice', { vol: 0.6 });
    }
    let hits = 0;
    for (const e of enemiesOf(this)) {
      const d = dist2D(e.pos, pos);
      if (d > atk.range + e.radius) continue;
      if (Math.abs(angDiff(yawTo(pos, e.pos), yaw)) > atk.arc / 2 && d > e.radius + 0.6) continue;
      const crit = Math.random() < (this.furyActive > 0 ? 0.35 : 0.12);
      damage(this, e, atk.dmg * this.dmgMul, { heavy: atk.heavy, knock: atk.heavy ? 7 : 3, crit, element: atk.ice ? 'ice' : undefined,
        sparkColor: this.furyActive > 0 ? '#ff6060' : undefined, sparkColor2: this.furyActive > 0 ? '#600000' : undefined });
      if (this.furyActive > 0) { this.hp = Math.min(this.maxHp, this.hp + 2); }
      hits++;
    }
    if (hits && atk.heavy) G.cam.kick(4);
  }

  dodge() {
    if (this.stamina < 18) { G.ui && G.ui.toast('Sem fôlego', '#c0c0c0', 0.8); return; }
    this.stamina -= 22; this.staminaDelay = 0.6;
    const dir = this.wish && this.wish.lengthSq() > 0 ? this.wish.clone() : this.forward.multiplyScalar(-1);
    this.dodgeDir = dir; this.dodgeT = 0; this.perfectUsed = false;
    this.iframes = 0.34;
    const back = !(this.wish && this.wish.lengthSq() > 0);
    if (!back) this.yaw = Math.atan2(dir.x, dir.z);
    this.setState('dodge');
    this.anim.play(back ? 'backstep' : 'dodge', { speed: 1, blendIn: 0.03 });
    Audio.sfx('dodge'); G.cam.kick(3);
    G.fx.burst('dust', this.pos, { n: 6, size: 0.6 });
    if (this.kit === 'kiana') G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + 0.8), { n: 8, r: 0.3, color: '#140a1a' });
  }
  usePotion() {
    if (this.potions <= 0 || this.hp >= this.maxHp || this.healT > 0) { G.ui && G.ui.toast(this.potions <= 0 ? 'Sem poções' : 'Vida cheia', '#c0c0c0', 0.8); return; }
    this.potions--; this.healT = 1.6; Audio.sfx('potion');
    G.fx.burst('heal', this.pos, { n: 25 });
  }
  blinkTo(tgt) {
    const behind = tgt.pos.clone().addScaledVector(fwd(tgt.yaw), -(tgt.radius + 0.9));
    G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + 1), { n: 18, r: 0.4, speed: 2 });
    G.fx.burst('magic', this.pos.clone().setY(this.pos.y + 1), { n: 10, color: '#ff2040', color2: '#300010' });
    this.pos.x = behind.x; this.pos.z = behind.z;
    resolveCollision(this);
    this.yaw = yawTo(this.pos, tgt.pos);
    G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + 1), { n: 18, r: 0.4, speed: 2 });
    Audio.sfx('blink'); G.cam.shake(0.15);
  }

  // ---- habilidades ----
  useSkill(i) {
    const sk = this.skills[i];
    if (this.cd[i] > 0) { G.ui && G.ui.toast('Recarregando', '#a0a0a0', 0.6); return; }
    if (this.energy < sk.cost) { G.ui && G.ui.toast('Energia insuficiente', '#80c0ff', 0.8); return; }
    const tgt = this.autoTarget(i === 2 ? 14 : 16);
    if (i === 2 && this.kit === 'kiana' && !tgt) { G.ui && G.ui.toast('Nenhum alvo', '#a0a0a0', 0.6); return; }
    this.energy -= sk.cost; this.cd[i] = sk.cd; this.combatT = 4;
    if (tgt) this.yaw = yawTo(this.pos, tgt.pos);
    G.ui && G.ui.skillFlash(i);
    if (this.kit === 'kiana') this.kianaSkill(i, tgt); else this.viktorSkill(i, tgt);
  }
  ukuleleFront(on) {
    const u = this.rig.ukulele; if (!u) return;
    if (on) { u.position.set(-0.02, 0.22, 0.2); u.rotation.set(0.15, 0.1, 1.15); }
    else { u.position.copy(this.rig.ukuleleBack.pos); u.rotation.copy(this.rig.ukuleleBack.rot); }
  }
  kianaSkill(i, tgt) {
    if (i === 0) {          // Acorde Cortante — lâmina de som
      this.setState('cast'); this.castDur = 0.42; this.castMove = 0;
      this.anim.play('cast', { speed: 1.2, onEvent: () => {
        const start = this.pos.clone().add(new V3(0, 1.15, 0)).addScaledVector(this.forward, 0.6);
        const dir = tgt ? tgt.chestPos().sub(start).normalize() : this.forward;
        Audio.sfx('soundBlade');
        for (let k = -1; k <= 1; k += (this.furyActive > 0 ? 1 : 2)) {
          const d = dir.clone().applyAxisAngle(up, k * 0.12);
          spawnProjectile({ kind: 'crescent', pos: start, vel: d.multiplyScalar(20), team: 'player', dmg: 22 * this.dmgMul, radius: 0.7, life: 1.2, src: this, pierce: true,
            color: '#b070ff', color2: '#60e8ff', scale: 1.1, knock: 4, target: tgt, homing: tgt ? 3 : 0, furyGain: 2,
            trail: (p) => { if (Math.random() < 0.8) G.fx.burst('magic', p.pos, { n: 1, speed: 0.4, size: 0.8 }); },
            onHit: (p, t) => this.resonate(t) });
        }
      } });
    } else if (i === 1) {   // Ressonância — onda de choque
      this.setState('cast'); this.castDur = 0.72; this.castMove = 0; this.iframes = 0.4;
      this.ukuleleFront(true);
      this.anim.play('strum', { onEvent: () => {
        Audio.sfx('shock'); G.cam.shake(0.45); G.cam.kick(6);
        const c = this.pos.clone();
        G.fx.ring(c, { color: '#ffd27a', r1: 6.5, life: 0.55, intensity: 3 });
        G.fx.ring(c, { color: '#60e8ff', r1: 5, life: 0.4, intensity: 2 });
        G.fx.sphere(c.clone().setY(c.y + 1), { color: '#ffd8a0', r1: 3, life: 0.3, opacity: 0.4 });
        G.fx.burst('gold', c.clone().setY(c.y + 0.5), { n: 40, r: 2 });
        G.fx.flash(c.clone().setY(c.y + 1.5), '#ffd080', 14, 0.35, 12);
        areaAttack({ pos: c, radius: 6, dmg: 30 * this.dmgMul, team: 'player', src: this, delay: 0, knock: 14, heavy: true, telegraph: false, furyGain: 3,
          onTrigger: () => {} });
        for (const e of enemiesOf(this)) if (dist2D(e.pos, c) < 6.5) { e.stun && e.stun(1.2); this.resonate(e); }
      }, onEnd: () => this.ukuleleFront(false) });
    } else if (i === 2) {   // Passo Sombrio — teleporte e estocada
      this.blinkTo(tgt);
      this.setState('attack'); this.combatT = 4;
      const info = { clip: 'atk3', dmg: 38, range: 2.8, arc: 1.6, heavy: true, slash: { roll: 1.5, big: true, scale: 1.0 }, lungeT: 0.1, lungeSpd: 6, cancelAt: 0.4 };
      this.curAtk = info;
      this.anim.play('atk3', { speed: 1.4, onEvent: () => {
        G.fx.burst('magic', tgt.chestPos(), { n: 20, color: '#ff3050', color2: '#200010' });
        this.meleeHit({ ...info, dmg: 38 });
      }, onEnd: () => { if (this.state === 'attack') this.setState('move'); } });
    }
  }
  resonate(t) { if (t && t.resonance !== undefined) { t.resonance = Math.min(99, t.resonance + 1); } }
  viktorSkill(i, tgt) {
    if (i === 0) {          // Lança de Gelo
      this.setState('cast'); this.castDur = 0.45;
      this.anim.play('cast', { speed: 1.2, onEvent: () => {
        const start = this.pos.clone().add(new V3(0, 1.3, 0)).addScaledVector(this.forward, 0.8);
        const dir = tgt ? tgt.chestPos().sub(start).normalize() : this.forward;
        Audio.sfx('ice');
        spawnProjectile({ kind: 'spear', pos: start, vel: dir.multiplyScalar(26), team: 'player', dmg: 30, radius: 0.5, life: 1.2, src: this, element: 'ice', scale: 1.2, knock: 6, heavy: true,
          trail: (p) => G.fx.burst('ice', p.pos, { n: 1, speed: 0.3 }), onExpire: (p) => G.fx.burst('ice', p.pos, { n: 12 }) });
      } });
    } else if (i === 1) {   // Floresta de Lanças
      this.setState('cast'); this.castDur = 0.8;
      const c = tgt ? tgt.pos.clone() : this.pos.clone().addScaledVector(this.forward, 6);
      this.anim.play('slam', { speed: 1.6, onEvent: () => {
        Audio.sfx('shatter'); G.cam.shake(0.5);
        for (let k = 0; k < 16; k++) {
          const a = k / 16 * Math.PI * 2 + rnd(0, 0.4), r = rnd(0.4, 3.2);
          later(() => G.fx.iceSpike(new V3(c.x + Math.cos(a) * r, 0, c.z + Math.sin(a) * r), { h: rnd(1.5, 3.2), r: rnd(0.2, 0.4), life: 2.2 }), k * 18);
        }
        areaAttack({ pos: c, radius: 3.6, dmg: 48, team: 'player', src: this, delay: 0.1, knock: 4, element: 'ice', telegraph: false });
        for (const e of enemiesOf(this)) if (dist2D(e.pos, c) < 3.6) e.stun && e.stun(1.5);
      } });
    } else if (i === 2) {   // Gelo Negro — investida
      this.setState('cast'); this.castDur = 0.5; this.castMove = 16; this.iframes = 0.5;
      this.anim.play('charge', { blendIn: 0.03 });
      Audio.sfx('ice'); Audio.sfx('dodge');
      const start = this.pos.clone(), y = this.yaw;
      for (let k = 0; k < 9; k++) later(() => {
        const p = start.clone().addScaledVector(fwd(y), k * 0.9);
        G.fx.iceSpike(p.clone().addScaledVector(rightOf(y), rnd(-0.6, 0.6)), { black: true, h: rnd(0.8, 1.6), r: 0.18, life: 1.4, silent: true });
      }, k * 45);
      areaAttack({ shape: 'rect', pos: start, yaw: y, width: 2.2, length: 8, dmg: 36, team: 'player', src: this, delay: 0.25, knock: 6, element: 'ice', telegraph: false });
      later(() => this.anim.stop(), 450);
    }
  }

  // ---- fúria ----
  activateFury() {
    if (this.fury < 100) { G.ui && G.ui.toast('Fúria insuficiente', '#ff6050', 0.8); return; }
    if (this.kit === 'viktor') { this.punhoFlamejante(); return; }
    if (G.flags.harmonic) { this.startUlt(); return; }
    this.furyActive = 9; this.fury = 100;
    G.flags.apagao = true; Audio.sfx('fury'); G.cam.shake(0.6); G.cam.kick(10);
    G.slow = { t: 0.5, scale: 0.2 };
    G.fx.burst('shadow', this.pos.clone().setY(1), { n: 40, r: 0.6, speed: 3, size: 1.4 });
    G.fx.ring(this.pos, { color: '#ff1020', r1: 8, life: 0.6, intensity: 3 });
    for (const e of this.rig.eyes) e.scale.multiplyScalar(1.6);
    G.ui && G.ui.toast('— APAGÃO —', '#ff2020', 1.6, true);
  }
  updateFury(dt) {
    this.furyActive -= dt; this.fury = Math.max(0, (this.furyActive / 9) * 100);
    if (Math.random() < 0.6) G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + 0.5), { n: 1, r: 0.35, color: '#1a0006' });
    if (this.furyActive <= 0) this.endFury();
  }
  endFury() {
    if (this.furyActive <= 0 && !G.flags.apagao) return;
    this.furyActive = 0; G.flags.apagao = false; this.fury = 0;
    for (const e of this.rig.eyes) e.scale.set(1.2, 0.8, 0.5);
  }
  startUlt() {
    this.fury = 0; this.ult = { t: 0, beat: 0, n: 0 };
    this.setState('cast'); this.castDur = 999;
    this.ukuleleFront(true); this.anim.play('play');
    this.dmgTakenMul = 0.3;
    Audio.flags.harmonic = true; Audio.sfx('reveal'); G.cam.shake(0.4);
    G.ui && G.ui.toast('MANIFESTAÇÃO HARMÔNICA', '#ffe08a', 2, true);
    G.fx.ring(this.pos, { color: '#60f0ff', r1: 10, life: 1, intensity: 3 });
    G.post && (G.post.harmonic = 1);
  }
  updateUlt(dt) {
    const u = this.ult; u.t += dt; u.beat -= dt;
    if (this.rig.ukulele) this.rig.ukulele.userData.strings.material.color.setScalar(2 + Math.sin(G.time * 30));
    if (Math.random() < 0.9) G.fx.burst('magic', this.pos.clone().add(new V3(rnd(-2, 2), rnd(0.5, 2.5), rnd(-2, 2))), { n: 1, color: Math.random() < 0.5 ? '#60f0ff' : '#ffd070', color2: '#ffffff', speed: 0.6 });
    const tg = this.lockTarget || nearestEnemy(this, 30);
    if (tg) this.faceTo(tg.pos, dt, 4);
    if (u.beat <= 0) {
      u.beat = 0.42; u.n++;
      const chords = [[69, 72, 76, 81], [65, 69, 72, 77], [67, 71, 74, 79], [64, 68, 71, 76]];
      Audio.sfx('chord', { notes: chords[u.n % 4] });
      const start = this.pos.clone().add(new V3(0, 1.2, 0));
      for (const e of enemiesOf(this)) {
        if (dist2D(e.pos, this.pos) > 30) continue;
        const dir = e.chestPos().sub(start).normalize().applyAxisAngle(up, rnd(-0.6, 0.6));
        spawnProjectile({ kind: 'crescent', pos: start.clone().add(new V3(rnd(-1, 1), rnd(0, 1), rnd(-1, 1))), vel: dir.multiplyScalar(16), team: 'player', dmg: 16, radius: 0.8, life: 2, src: this, color: u.n % 2 ? '#60f0ff' : '#ffd070', color2: '#ffffff', target: e, homing: 6, scale: 1.2, furyGain: 0,
          trail: (p) => { if (Math.random() < 0.7) G.fx.burst('magic', p.pos, { n: 1, color: '#80f8ff', color2: '#ffe090', speed: 0.3 }); }, onHit: (p, t) => this.resonate(t) });
      }
      if (u.n % 3 === 0) {
        G.fx.ring(this.pos, { color: '#ffd27a', r1: 7, life: 0.5, intensity: 3 });
        areaAttack({ pos: this.pos, radius: 7, dmg: 20, team: 'player', src: this, delay: 0, knock: 10, telegraph: false, furyGain: 0 });
        G.cam.shake(0.25);
      }
    }
    if (u.t >= 7.5) this.endUlt();
  }
  endUlt() {
    this.ult = null; this.dmgTakenMul = 1; this.anim.stop(); this.ukuleleFront(false);
    this.setState('move'); Audio.flags.harmonic = false;
    this.energy = 0; this.stamina = 0; this.exhausted = 4;
    G.post && (G.post.harmonic = 0);
    G.ui && G.ui.toast('Exausta... reflexos lentos', '#a0a0c0', 1.6);
    emit('ultEnd');
  }
  punhoFlamejante() {
    const tgt = this.autoTarget(8) || nearestEnemy(this, 8);
    this.fury = 0;
    this.setState('cast'); this.castDur = 1.1; this.castMove = 0; this.iframes = 1.2;
    if (tgt) this.yaw = yawTo(this.pos, tgt.pos);
    G.slow = { t: 0.8, scale: 0.25 }; G.cam.kick(12);
    G.ui && G.ui.toast('PUNHO FLAMEJANTE!', '#fff0b0', 1.6, true);
    Audio.sfx('fury');
    const fist = this.rig.handR;
    const glowF = new THREE.Mesh(new THREE.SphereGeometry(0.16, 12, 10), new THREE.MeshBasicMaterial({ color: new THREE.Color('#fff0c0').multiplyScalar(4), toneMapped: false }));
    fist.add(glowF);
    let tt = 0;
    const it = G.fx.custom(1.2, (_, dt) => { tt += dt; glowF.scale.setScalar(1 + tt * 3); G.fx.burst('fire', fist.getWorldPosition(new V3()), { n: 2, color: '#ffffff', color2: '#ffc040', size: 0.6, r: 0.05 }); }, () => fist.remove(glowF));
    this.anim.play('uppercut', { speed: 0.8, onEvent: () => {
      const c = this.pos.clone().addScaledVector(this.forward, 1.6);
      Audio.sfx('explosion'); Audio.sfx('fire');
      G.cam.shake(1); G.post && (G.post.flash = 1);
      G.fx.sphere(c.clone().setY(1.4), { color: '#fff4d0', r1: 6, life: 0.7, intensity: 4 });
      G.fx.ring(c, { color: '#ffd060', r1: 10, life: 0.8, intensity: 4 });
      G.fx.burst('fire', c, { n: 80, r: 1.5, color: '#ffffff', color2: '#ffb020', size: 1.6, up: 2 });
      G.fx.burst('spark', c.clone().setY(1.4), { n: 60, color: '#ffffff', color2: '#ffc040' });
      G.fx.flash(c.clone().setY(2), '#fff0c0', 30, 0.8, 25);
      if (tgt) { tgt.armorBroken = 12; }
      areaAttack({ pos: c, radius: 4.5, dmg: 240, team: 'player', src: this, delay: 0, knock: 18, telegraph: false, element: 'fire', unblockable: true, heavy: true, furyGain: 0 });
      emit('punho', tgt);
    } });
  }
}

// =====================================================================
//  INIMIGO BASE
// =====================================================================
export class Enemy extends Actor {
  constructor(id, o = {}) {
    super(id, { ...o, team: 'enemy' });
    this.dmg = o.dmg ?? 10; this.moveSpeed = o.speed ?? 3.4; this.range = o.range ?? 1.9;
    this.poiseMax = o.poise ?? 0; this.poiseCur = this.poiseMax;
    this.cd = rnd(0.6, 2); this.token = false; this.strafe = Math.random() < 0.5 ? 1 : -1;
    this.ai = 'spawn'; this.aiT = 0; this.stunT = 0; this.circleR = rnd(3, 4.2);
    this.anim.combat = 0.6;
    this.anim.stance = { shR: [-0.5, 0, -0.2], elR: [-0.6, 0, 0], shL: [-0.3, 0, 0.3], elL: [-0.7, 0, 0], chest: [0.1, 0, 0], hipL: [-0.2, 0, 0], knL: [0.3, 0, 0], hipR: [0.15, 0, 0], knR: [0.3, 0, 0], pos: [0, -0.04, 0] };
    this.target = null; this.bleeds = o.bleeds ?? true;
    this.resonance = 0;
    this.anim.onStep = () => { if (this.speed > 2 && Math.random() < 0.5) Audio.sfx('step', { wood: G.level && G.level.surface === 'wood', vol: 0.35 }); };
  }
  pickTarget() {
    if (this.allyAggro && Math.random() < 0.45) {
      const al = G.actors.filter(a => a.alive && a.team === 'player' && a !== G.player && !a.downed);
      if (al.length) return al[Math.floor(Math.random() * al.length)];
    }
    return G.player;
  }
  takeToken() { if (this.token) return true; if (G.attackTokens < G.maxTokens) { G.attackTokens++; this.token = true; return true; } return false; }
  dropToken() { if (this.token) { G.attackTokens = Math.max(0, G.attackTokens - 1); this.token = false; } }
  stun(t) {
    if (!this.alive || this.unstoppable) return;
    this.dropToken(); this.stunT = t; this.ai = 'stun'; this.anim.play(t > 1 ? 'knock' : 'hit', { speed: t > 1 ? 1 : 0.8 });
    this.aiT = 0; this.cancelAttack && this.cancelAttack();
  }
  onHit(src, amt, o) {
    if (!this.alive) return;
    if (this.poiseMax > 0) {
      this.poiseCur -= amt * (o.heavy ? 1.5 : 1);
      if (this.poiseCur <= 0) { this.poiseCur = this.poiseMax; this.stun(1.8); G.ui && G.ui.toast('ATORDOADO', '#ffd060', 0.8); }
      return;
    }
    if (this.ai === 'windup' && !o.heavy && Math.random() < 0.5) return; // às vezes resiste
    this.dropToken();
    this.ai = 'hurt'; this.aiT = 0; this.stunT = o.heavy ? 0.6 : 0.35;
    this.anim.play(o.heavy && amt > 20 ? 'knock' : 'hit', { speed: o.heavy && amt > 20 ? 1.3 : 1 });
    if (this.cancelAttack) this.cancelAttack();
  }
  die(src) {
    if (!this.alive && this.dead) return;
    this.dead = true; this.alive = false; this.dropToken();
    this.anim.play('death', { speed: rnd(0.9, 1.2) });
    Audio.sfx('die', { vol: 0.7 });
    G.killCount++; emit('kill', this);
    if (this.cancelAttack) this.cancelAttack();
    let t = 0;
    const sinkAfter = this.corpseTime ?? 6;
    G.fx.custom(sinkAfter + 2, (_, dt) => {
      t += dt;
      this.anim.update(dt, 0);
      if (t > sinkAfter) this.root.position.y -= dt * 0.6;
    }, () => this.remove());
    G.actors = G.actors.filter(a => a !== this);
  }
  update(dt) {
    if (!this.alive) return;
    const P = G.player;
    this.retarget = (this.retarget ?? rnd(3, 6)) - dt;
    if (this.retarget <= 0 && !this.busy) { this.retarget = rnd(4, 7); this.target = this.pickTarget(); }
    this.target = this.target && this.target.alive && !this.target.downed ? this.target : this.pickTarget();
    if (G.cine || !P) { this.vel.multiplyScalar(0.85); this.baseUpdate(dt); return; }
    this.aiT += dt; this.cd -= dt;
    this.think(dt);
    this.baseUpdate(dt);
  }
  think(dt) {}
  // ---- auxiliares comuns ----
  glint() {
    const h = this.rig.handR.getWorldPosition(new V3());
    G.fx.burst('spark', h, { n: 6, color: '#ffffff', color2: '#ff3020' });
    G.fx.flash(h, '#ff4020', 3, 0.25, 4);
    Audio.sfx('telegraph', { vol: 0.5 });
  }
  circleAround(dt, t) {
    const tp = t.pos, d = dist2D(this.pos, tp);
    const toT = new V3(tp.x - this.pos.x, 0, tp.z - this.pos.z).normalize();
    const side = new V3(-toT.z, 0, toT.x).multiplyScalar(this.strafe);
    const radial = clamp((d - this.circleR) * 0.8, -1, 1);
    const dir = side.multiplyScalar(0.7).addScaledVector(toT, radial);
    if (dir.lengthSq() > 0) dir.normalize();
    this.move(dir, this.moveSpeed * 0.45, dt, 6);
    this.faceTo(tp, dt, 8);
    if (Math.random() < dt * 0.3) this.strafe *= -1;
  }
}

// ---------- capanga de Darius / sombra ----------
export class Thug extends Enemy {
  constructor(o = {}) {
    super(o.shadow ? 'shadow' : 'thug', { hp: o.hp ?? 42, dmg: o.dmg ?? 9, speed: o.speed ?? 3.6, ...o, rigOpts: { seed: o.seed, weapon: o.weapon, giant: o.giant } });
    this.shadow = !!o.shadow; this.heavyType = o.weapon === 'axe' || (o.seed % 3 === 2 && !o.shadow);
    if (this.shadow) { this.bleeds = false; this.corpseTime = 0.3; this.flashColor = new THREE.Color('#ff2050'); }
  }
  cancelAttack() { if (this.tel) { this.tel.kill = true; this.tel = null; } }
  think(dt) {
    const t = this.target; if (!t) return;
    const d = dist2D(this.pos, t.pos);
    if (this.shadow && Math.random() < dt * 6) G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + rnd(0.3, 1.6)), { n: 1, r: 0.3 });
    switch (this.ai) {
      case 'spawn': if (this.aiT > 0.6) this.ai = 'approach'; this.vel.multiplyScalar(0.8); break;
      case 'stun': case 'hurt':
        this.vel.multiplyScalar(0.85);
        if (this.aiT > this.stunT) { this.ai = 'circle'; this.aiT = 0; }
        break;
      case 'approach':
        if (d > 5.5) { this.move(new V3(t.pos.x - this.pos.x, 0, t.pos.z - this.pos.z).normalize(), this.moveSpeed, dt); this.faceTo(t.pos, dt, 8); }
        else this.ai = 'circle';
        break;
      case 'circle':
        if (d > 7) { this.ai = 'approach'; break; }
        this.circleAround(dt, t);
        if (this.cd <= 0 && (t !== G.player || this.takeToken())) { this.ai = 'engage'; this.aiT = 0; }
        else if (this.cd <= 0) this.cd = rnd(0.3, 0.8);
        break;
      case 'engage':
        this.faceTo(t.pos, dt, 10);
        if (d > this.range + t.radius - 0.2) this.move(new V3(t.pos.x - this.pos.x, 0, t.pos.z - this.pos.z).normalize(), this.moveSpeed * 1.15, dt);
        else this.startAttack();
        if (this.aiT > 3.5) { this.dropToken(); this.ai = 'circle'; this.cd = 1; }
        break;
      case 'windup': case 'attack':
        this.vel.multiplyScalar(0.8);
        if (this.ai === 'windup') this.faceTo(t.pos, dt, 5);
        break;
      case 'recover':
        this.vel.multiplyScalar(0.85);
        if (this.aiT > 0.5) { this.dropToken(); this.ai = 'circle'; this.aiT = 0; this.cd = rnd(1.6, 3.4); }
        break;
    }
  }
  startAttack() {
    this.ai = 'windup'; this.aiT = 0; this.vel.set(0, 0, 0);
    const heavy = this.heavyType;
    const clip = this.shadow ? 'claw' : heavy ? 'heavy' : 'swing';
    if (heavy) this.tel = G.fx.telegraph(this.pos.clone().addScaledVector(this.forward, 1.6), { radius: 1.4, time: 0.75 });
    later(() => this.alive && this.ai === 'windup' && this.glint(), heavy ? 350 : 200);
    this.anim.play(clip, { speed: this.shadow ? 0.75 : 1, onEvent: () => {
      if (!this.alive || this.ai !== 'windup') return;
      this.ai = 'attack'; this.cancelAttack();
      Audio.sfx(heavy ? 'swingHeavy' : 'swing', { vol: 0.8 });
      const yaw = this.yaw, P = this.target;
      const reach = heavy ? 2.6 : this.range + 0.4;
      G.fx.slash(this.pos.clone().add(new V3(0, 1.1, 0)), yaw, { color: this.shadow ? '#ff2050' : '#ffb080', intensity: 1.2, roll: heavy ? 1.5 : 0.6, scale: 0.9, dark: this.shadow });
      for (const t of [G.player, ...G.actors.filter(a => a.team === 'player' && a !== G.player)]) {
        if (!t || !t.alive) continue;
        const d = dist2D(this.pos, t.pos);
        if (d < reach + t.radius && Math.abs(angDiff(yawTo(this.pos, t.pos), yaw)) < 1.0)
          damage(this, t, this.dmg * (heavy ? 1.6 : 1), { heavy, knock: heavy ? 8 : 4 });
      }
      if (heavy) { G.fx.burst('dust', this.pos.clone().addScaledVector(this.forward, 1.6), { n: 10 }); G.cam.shake(0.15); }
    }, onEnd: () => { if (this.ai === 'attack' || this.ai === 'windup') { this.ai = 'recover'; this.aiT = 0; } } });
  }
  die(src) {
    super.die(src);
    if (this.shadow) {
      G.fx.burst('shadow', this.pos.clone().setY(this.pos.y + 1), { n: 30, r: 0.5, speed: 2, size: 1.3 });
      this.root.visible = false;
    }
  }
}

// ---------- besteiro ----------
export class Archer extends Enemy {
  constructor(o = {}) { super('thug', { hp: 32, dmg: 8, speed: 3.2, ...o, rigOpts: { seed: o.seed ?? 4, weapon: 'crossbow' } }); this.circleR = rnd(8, 10); }
  cancelAttack() { if (this.laser) { G.scene.remove(this.laser); this.laser = null; } }
  think(dt) {
    const t = this.target; if (!t) return;
    const d = dist2D(this.pos, t.pos);
    switch (this.ai) {
      case 'spawn': if (this.aiT > 0.6) this.ai = 'circle'; break;
      case 'stun': case 'hurt': this.vel.multiplyScalar(0.85); if (this.aiT > this.stunT) { this.ai = 'circle'; this.aiT = 0; } break;
      case 'circle':
        if (d < 5) { this.move(new V3(this.pos.x - t.pos.x, 0, this.pos.z - t.pos.z).normalize(), this.moveSpeed, dt); this.faceTo(t.pos, dt, 6); }
        else this.circleAround(dt, t);
        if (this.cd <= 0 && d < 16) { this.ai = 'aim'; this.aiT = 0; this.anim.play('shoot', { speed: 0.55 }); }
        break;
      case 'aim': {
        this.vel.multiplyScalar(0.8); this.faceTo(t.pos, dt, 6);
        const from = this.rig.handR.getWorldPosition(new V3()), to = t.chestPos();
        if (!this.laser) {
          this.laser = new THREE.Mesh(new THREE.CylinderGeometry(0.008, 0.008, 1, 4, 1, true), new THREE.MeshBasicMaterial({ color: new THREE.Color('#ff2010').multiplyScalar(3), transparent: true, opacity: 0.6, toneMapped: false, blending: THREE.AdditiveBlending }));
          G.scene.add(this.laser);
        }
        const len = from.distanceTo(to);
        this.laser.position.copy(from).add(to).multiplyScalar(0.5); this.laser.scale.y = len;
        this.laser.quaternion.setFromUnitVectors(up, to.clone().sub(from).normalize());
        this.laser.material.opacity = 0.2 + Math.min(1, this.aiT / 0.9) * 0.6 + (this.aiT > 0.75 ? Math.sin(this.aiT * 60) * 0.3 : 0);
        if (this.aiT > 0.95) {
          this.cancelAttack();
          Audio.sfx('arrow');
          const dir = to.sub(from).normalize();
          spawnProjectile({ kind: 'bolt', pos: from, vel: dir.multiplyScalar(26), team: 'enemy', dmg: this.dmg, radius: 0.35, life: 2, src: this, knock: 2 });
          this.ai = 'recover'; this.aiT = 0;
        }
        break;
      }
      case 'recover': if (this.aiT > 0.6) { this.ai = 'circle'; this.cd = rnd(2.5, 4); } break;
    }
  }
}

// =====================================================================
//  CHEFE BASE
// =====================================================================
class Boss extends Enemy {
  constructor(id, o) {
    super(id, o);
    this.big = true; this.boss = true; this.unstoppable = false;
    this.attacks = []; this.busy = false; this.knockResist = 0.15;
    this.title = o.title || ''; this.phase = 1;
    G.boss = this;
  }
  stun(t) { if (this.busyUnstoppable) return; super.stun(t); this.busy = false; this.clearPending(); }
  clearPending() { if (this.pend) { for (const a of this.pend) { if (a.tel) a.tel.kill = true; G.areas = G.areas.filter(x => x !== a); } this.pend = []; } }
  queueArea(o) { const a = areaAttack({ team: 'enemy', src: this, ...o }); (this.pend = this.pend || []).push(a); return a; }
  chooseAttack(d) {
    const opts = this.attacks.filter(a => (a.min ?? 0) <= d && d <= (a.max ?? 99) && (a.cdLeft || 0) <= 0 && (!a.phase || a.phase.includes(this.phase)));
    if (!opts.length) return null;
    let tot = opts.reduce((s, a) => s + a.w, 0), r = Math.random() * tot;
    for (const a of opts) { r -= a.w; if (r <= 0) return a; }
    return opts[0];
  }
  think(dt) {
    for (const a of this.attacks) a.cdLeft = (a.cdLeft || 0) - dt;
    const t = this.target; if (!t) return;
    const d = dist2D(this.pos, t.pos);
    if (this.ai === 'stun' || this.ai === 'hurt') { this.vel.multiplyScalar(0.85); if (this.aiT > this.stunT) { this.ai = 'chase'; this.aiT = 0; } return; }
    if (this.ai === 'spawn') { if (this.aiT > 0.5) this.ai = 'chase'; return; }
    if (this.busy) { if (this.busyUpdate) this.busyUpdate(dt, t, d); else this.vel.multiplyScalar(Math.exp(-dt * 6)); return; }
    // perseguição
    const pref = this.prefDist ?? 2.4;
    const dir = new V3(t.pos.x - this.pos.x, 0, t.pos.z - this.pos.z).normalize();
    if (d > pref) this.move(dir, this.moveSpeed, dt, 6);
    else this.move(new V3(-dir.z, 0, dir.x).multiplyScalar(this.strafe), this.moveSpeed * 0.3, dt, 4);
    this.faceTo(t.pos, dt, 4);
    if (this.cd <= 0) {
      const a = this.chooseAttack(d);
      if (a) { a.cdLeft = a.cd || 3; this.busy = true; this.ai = 'attack'; this.aiT = 0; this.vel.set(0, 0, 0); a.fn.call(this, t, d); this.cd = (this.cdBase ?? 1.6) * rnd(0.7, 1.2); }
      else this.cd = 0.3;
    }
  }
  done(after = 0.4) { later(() => { if (this.alive) { this.busy = false; this.busyUpdate = null; this.ai = 'chase'; this.unstoppable = false; } }, after * 1000); }
  onHit(src, amt, o) {
    if (!this.alive) return;
    this.poiseCur -= amt * (o.heavy ? 1.4 : 1);
    if (this.poiseCur <= 0 && !this.busyUnstoppable) { this.poiseCur = this.poiseMax; this.stun(2.2); G.ui && G.ui.toast('ATORDOADO!', '#ffd060', 1); }
    this.checkPhase && this.checkPhase();
  }
  die(src) { this.clearPending(); super.die(src); emit('bossDead', this); }
}

// ---------- DARIUS ----------
export class Darius extends Boss {
  constructor(o = {}) {
    super('darius', { hp: 720, dmg: 20, speed: 2.7, poise: 110, radius: 0.75, mass: 6, title: 'O Maior Criminoso de Vardun', ...o });
    this.name = 'Darius'; this.prefDist = 2.6; this.cdBase = 1.4;
    this.attacks = [
      { w: 3, max: 3.6, cd: 2.5, fn: this.cleave },
      { w: 3, max: 3.4, cd: 3, fn: this.sweep },
      { w: 2, min: 4.5, cd: 6, fn: this.charge },
      { w: 1.5, max: 6, cd: 9, fn: this.slam },
      { w: 2, max: 4, cd: 7, fn: this.triple, phase: [2] },
    ];
  }
  checkPhase() {
    if (this.phase === 1 && this.hp < this.maxHp * 0.5) {
      this.phase = 2; this.moveSpeed *= 1.2; this.cdBase = 1.0;
      this.clearPending(); this.busy = true; this.busyUnstoppable = true; this.ai = 'attack';
      this.anim.play('roar'); Audio.sfx('roar'); G.cam.shake(0.6);
      emit('bossPhase', { boss: this, phase: 2 });
      later(() => { this.busyUnstoppable = false; this.done(0); }, 1600);
    }
  }
  cleave(t) {
    this.faceTo(t.pos, 1, 99);
    const p = this.pos.clone(), y = this.yaw;
    this.queueArea({ shape: 'rect', pos: p, yaw: y, width: 1.6, length: 3.6, delay: 0.78 / 0.95, dmg: this.dmg * 1.1, knock: 9,
      onTrigger: (s) => { G.fx.burst('dust', p.clone().addScaledVector(fwd(y), 2.6), { n: 14, size: 1.2 }); G.fx.burst('spark', p.clone().addScaledVector(fwd(y), 2.6).setY(0.2), { n: 14 }); G.cam.shake(0.35); Audio.sfx('hitHeavy', { vol: 0.6 }); } });
    this.anim.play('heavy', { speed: 0.95, onEvent: () => { Audio.sfx('swingHeavy'); G.fx.slash(this.pos.clone().setY(1.6), y, { roll: 1.55, big: true, color: '#ffb070', intensity: 1.4, scale: 1.2 }); } });
    this.done(1.35);
  }
  sweep(t) {
    this.faceTo(t.pos, 1, 99);
    const p = this.pos.clone(), y = this.yaw;
    this.queueArea({ shape: 'cone', pos: p, yaw: y, radius: 3.6, angle: 2.8, delay: 0.55, dmg: this.dmg * 0.8, knock: 8 });
    this.anim.play('sweep', { onEvent: () => { Audio.sfx('swingHeavy'); G.fx.slash(this.pos.clone().setY(1.4), y, { roll: 0, big: true, color: '#ffb070', intensity: 1.4, scale: 1.3, flip: true }); } });
    this.done(1.05);
  }
  charge(t) {
    this.faceTo(t.pos, 1, 99);
    const y = yawTo(this.pos, t.pos), len = Math.min(13, dist2D(this.pos, t.pos) + 3);
    (this.pend = this.pend || []).push({ tel: G.fx.telegraph(this.pos.clone(), { shape: 'rect', yaw: y, width: 1.8, length: len, time: 0.9 }) });
    this.anim.play('charge'); Audio.sfx('roar', { pitch: 1.4, vol: 0.6 });
    this.busyUnstoppable = true;
    let hit = false;
    later(() => {
      if (!this.alive) return;
      this.yaw = y; let tt = 0;
      this.busyUpdate = (dt) => {
        tt += dt;
        const before = this.pos.clone();
        this.vel.copy(fwd(y)).multiplyScalar(14);
        if (Math.random() < 0.6) G.fx.burst('dust', this.pos, { n: 2 });
        for (const a of [G.player, ...G.actors.filter(x => x.team === 'player')]) {
          if (!hit && a && a.alive && dist2D(a.pos, this.pos) < this.radius + a.radius + 0.4) { hit = true; damage(this, a, this.dmg * 1.2, { heavy: true, knock: 13 }); }
        }
        const moved = dist2D(before, this.pos) / Math.max(dt, 1e-4);
        if (tt > len / 14 || (tt > 0.2 && moved < 3)) {
          this.vel.set(0, 0, 0); this.anim.stop(); this.busyUpdate = null; this.busyUnstoppable = false;
          if (tt > 0.2 && moved < 3) { G.cam.shake(0.5); Audio.sfx('hitHeavy'); this.stun(1.6); G.ui && G.ui.toast('Darius se chocou!', '#ffd060', 1); }
          else this.done(0.5);
        }
      };
    }, 900);
  }
  slam(t) {
    const p = this.pos.clone();
    this.busyUnstoppable = true;
    this.queueArea({ pos: p, radius: 4.8, delay: 0.85 / 0.9, dmg: this.dmg * 0.9, knock: 12,
      onTrigger: () => { G.fx.ring(p, { color: '#ffb070', r1: 5.5, life: 0.5 }); G.fx.burst('dust', p, { n: 30, size: 1.5, speed: 2 }); G.cam.shake(0.7); Audio.sfx('explosion', { vol: 0.6 }); } });
    this.anim.play('slam', { speed: 0.9, onEnd: () => { this.busyUnstoppable = false; } });
    this.done(1.6);
  }
  triple(t) {
    let n = 0;
    const go = () => {
      if (!this.alive || this.ai === 'stun') return;
      this.faceTo(this.target.pos, 1, 99);
      const p = this.pos.clone(), y = this.yaw;
      this.queueArea({ shape: 'rect', pos: p, yaw: y, width: 1.6, length: 3.4, delay: 0.62, dmg: this.dmg * 0.9, knock: 7 });
      this.anim.play('swing', { speed: 1.4, onEvent: () => { Audio.sfx('swingHeavy'); G.fx.slash(this.pos.clone().setY(1.5), y, { roll: 1.2 * (n % 2 ? -1 : 1), big: true, color: '#ff9050', intensity: 1.4 }); } });
      n++; if (n < 3) later(go, 720);
    };
    go(); this.done(2.5);
  }
}

// ---------- A CRIATURA MUTÁVEL (Vale das Flores Sangrentas) ----------
export class Elemental extends Boss {
  constructor(o = {}) {
    super('elemental', { hp: 1500, dmg: 16, speed: 2.6, poise: 160, radius: 1.15, mass: 12, title: 'A Essência Mutável', bleeds: false, ...o });
    this.name = 'Criatura do Vale'; this.prefDist = 3.2; this.allyAggro = true;
    this.light = new THREE.PointLight('#60c0ff', 4, 12, 2); G.scene.add(this.light);
    this.setForm('water');
    this.attacks = [
      { w: 3, max: 4.5, cd: 2.5, fn: this.whip, phase: [1, 3] },
      { w: 2, min: 3, cd: 5, fn: this.wave, phase: [1] },
      { w: 2, cd: 6, fn: this.orbs, phase: [1] },
      { w: 3, cd: 7, fn: this.tornado, phase: [2] },
      { w: 3, min: 3, cd: 4, fn: this.gust, phase: [2] },
      { w: 2, max: 7, cd: 6, fn: this.cyclone, phase: [2] },
      { w: 3, cd: 5, fn: this.meteors, phase: [3] },
      { w: 2, cd: 4, fn: this.fireballs, phase: [3] },
      { w: 2, max: 8, cd: 8, fn: this.flameRing, phase: [3] },
    ];
  }
  setForm(f) {
    this.form = f;
    const m = this.rig.elemMat;
    m.map = null; m.emissiveMap = null;
    for (const r of this.rig.rocks) r.visible = f === 'fire';
    if (f === 'water') { m.color.set('#2a7fd6'); m.emissive.set('#06284a'); m.opacity = 0.82; m.transparent = true; m.roughness = 0.1; this.light.color.set('#60c0ff'); this.rig.core.material.color.set('#9ff0ff').multiplyScalar(3); this.flying = false; }
    if (f === 'wind') { m.color.set('#dbe7f5'); m.emissive.set('#3a5a7a'); m.opacity = 0.38; m.transparent = true; m.roughness = 0.6; this.light.color.set('#c0e0ff'); this.rig.core.material.color.set('#ffffff').multiplyScalar(3); this.flying = true; }
    if (f === 'fire') { m.color.set('#ffffff'); m.map = T.get('lava'); m.emissiveMap = T.pair('lava').emit; m.emissive.set('#ff6a20'); m.emissiveIntensity = 1.6; m.opacity = 1; m.transparent = false; m.roughness = 0.9; this.light.color.set('#ff7020'); this.rig.core.material.color.set('#ffd060').multiplyScalar(4); this.flying = false; }
    m.needsUpdate = true;
    this.resist = f === 'water' ? null : null;
  }
  checkPhase() {
    const f = this.hp / this.maxHp;
    if (this.phase === 1 && f < 0.67) this.transform(2, 'wind');
    else if (this.phase === 2 && f < 0.34) this.transform(3, 'fire');
  }
  transform(ph, form) {
    this.phase = ph; this.clearPending(); this.busy = true; this.busyUnstoppable = true; this.ai = 'attack';
    this.invulnerable = true;
    this.anim.play('roar'); Audio.sfx('roar', { pitch: 0.7 }); G.cam.shake(0.7);
    G.fx.burst(this.form === 'water' ? 'water' : 'wind', this.chestPos(), { n: 50, r: 3 });
    later(() => {
      this.setForm(form);
      G.fx.sphere(this.chestPos(), { color: form === 'wind' ? '#ffffff' : '#ff8030', r1: 5, life: 0.6 });
      G.fx.flash(this.chestPos(), form === 'wind' ? '#c0e0ff' : '#ff7020', 20, 0.6, 20);
      Audio.sfx(form === 'wind' ? 'wind' : 'fire'); Audio.sfx('explosion', { vol: 0.5 });
      emit('bossPhase', { boss: this, phase: ph, form });
    }, 700);
    later(() => { this.invulnerable = false; this.busyUnstoppable = false; this.done(0); }, 2000);
  }
  update(dt) {
    super.update(dt);
    if (!this.alive) return;
    const cp = this.chestPos(); this.light.position.copy(cp);
    this.light.intensity = 4 + Math.sin(G.time * 6) * 1;
    this.rig.core.scale.setScalar(1 + Math.sin(G.time * 8) * 0.12);
    if (this.form === 'wind') { this.pos.y = 0.9 + Math.sin(G.time * 2) * 0.2; if (Math.random() < 0.7) G.fx.burst('wind', this.pos, { n: 1, r: 1.6, h: 4 }); }
    if (this.form === 'fire' && Math.random() < 0.8) G.fx.burst('fire', this.pos.clone().add(new V3(rnd(-1, 1), rnd(1, 4), rnd(-1, 1))), { n: 1, size: 1.3 });
    if (this.form === 'water' && Math.random() < 0.3) G.fx.burst('water', this.pos.clone().add(new V3(rnd(-0.8, 0.8), rnd(1, 3.5), rnd(-0.8, 0.8))), { n: 1 });
  }
  remove() { super.remove(); G.scene.remove(this.light); }
  whip(t) {
    this.faceTo(t.pos, 1, 99); const p = this.pos.clone(), y = this.yaw;
    const col = this.form === 'fire' ? '#ff7020' : '#60c0ff';
    this.queueArea({ shape: 'cone', pos: p, yaw: y, radius: 5, angle: 2.4, delay: 0.55, dmg: this.dmg, knock: 9, color: '#ff3020',
      onTrigger: () => { G.fx.burst(this.form === 'fire' ? 'fire' : 'water', p.clone().addScaledVector(fwd(y), 3).setY(1), { n: 25, r: 1.5 }); } });
    this.anim.play('sweep', { speed: 1.0, onEvent: () => { Audio.sfx(this.form === 'fire' ? 'fire' : 'splash'); G.fx.slash(this.chestPos(), y, { big: true, scale: 1.8, color: col, intensity: 2, flip: true }); } });
    this.done(1.1);
  }
  wave(t) {
    this.faceTo(t.pos, 1, 99); const p = this.pos.clone(), y = yawTo(this.pos, t.pos);
    this.queueArea({ shape: 'rect', pos: p, yaw: y, width: 3.4, length: 16, delay: 1.0, dmg: this.dmg * 1.15, knock: 12,
      onTrigger: () => { Audio.sfx('splash'); for (let k = 0; k < 16; k++) later(() => G.fx.burst('water', p.clone().addScaledVector(fwd(y), k).setY(0.3), { n: 8 }), k * 25); G.cam.shake(0.4); } });
    this.anim.play('slam', { speed: 1.1 });
    this.done(1.5);
  }
  orbs(t) {
    this.anim.play('cast', { speed: 0.6 }); Audio.sfx('magic', { pitch: -12 });
    for (let k = 0; k < 4; k++) later(() => {
      if (!this.alive) return;
      const s = this.chestPos().add(new V3(rnd(-1.5, 1.5), rnd(0, 1), rnd(-1.5, 1.5)));
      const tg = this.pickTarget();
      spawnProjectile({ kind: 'orb', pos: s, vel: tg.chestPos().sub(s).normalize().multiplyScalar(7), team: 'enemy', dmg: 9, radius: 0.5, life: 5, src: this, color: '#60c8ff', scale: 1.8, target: tg, homing: 1.4,
        trail: (p) => { if (Math.random() < 0.5) G.fx.burst('water', p.pos, { n: 1 }); }, onExpire: (p) => { G.fx.burst('water', p.pos, { n: 12 }); Audio.sfx('splash', { vol: 0.4 }); } });
    }, k * 260);
    this.done(1.4);
  }
  tornado(t) {
    this.anim.play('roar', { speed: 1.6 }); Audio.sfx('wind');
    for (let k = 0; k < 3; k++) {
      const a = this.yaw + (k - 1) * 0.8;
      const p = this.pos.clone().addScaledVector(fwd(a), 3);
      addHazard({ kind: 'wind', pos: p, radius: 1.3, dps: 14, life: 6, follow: this.pickTarget(), pull: 2.2, src: this });
    }
    this.done(1.2);
  }
  gust(t) {
    const y = yawTo(this.pos, t.pos), len = Math.min(14, dist2D(this.pos, t.pos) + 3);
    (this.pend = this.pend || []).push({ tel: G.fx.telegraph(this.pos.clone(), { shape: 'rect', yaw: y, width: 2.8, length: len, time: 0.8 }) });
    this.anim.play('charge'); Audio.sfx('whoosh');
    this.busyUnstoppable = true; let hit = new Set();
    later(() => {
      if (!this.alive) return;
      this.yaw = y; let tt = 0;
      this.busyUpdate = (dt) => {
        tt += dt; this.vel.copy(fwd(y)).multiplyScalar(18);
        G.fx.burst('wind', this.pos, { n: 3, r: 1.5, h: 3 });
        for (const a of G.actors) if (a.team === 'player' && a.alive && !hit.has(a) && dist2D(a.pos, this.pos) < this.radius + a.radius + 0.5) { hit.add(a); damage(this, a, this.dmg, { heavy: true, knock: 14 }); }
        if (tt > len / 18) { this.vel.set(0, 0, 0); this.anim.stop(); this.busyUpdate = null; this.busyUnstoppable = false; this.done(0.6); }
      };
    }, 800);
  }
  cyclone() {
    const p = this.pos.clone();
    this.queueArea({ pos: p, radius: 5.5, delay: 1.1, dmg: this.dmg, knock: 15,
      onTrigger: () => { G.fx.ring(p, { color: '#e0f0ff', r1: 6, life: 0.6 }); G.fx.burst('wind', p, { n: 60, r: 5, h: 3 }); Audio.sfx('wind'); G.cam.shake(0.4); } });
    this.anim.play('roar', { speed: 1.4 });
    this.done(1.6);
  }
  meteors() {
    this.anim.play('roar', { speed: 1.3 }); Audio.sfx('fire');
    const targets = G.actors.filter(a => a.alive && a.team === 'player');
    for (let k = 0; k < 6; k++) {
      const tg = targets[k % targets.length];
      const p = tg.pos.clone().add(new V3(rnd(-2, 2), 0, rnd(-2, 2))); if (k < 2) p.copy(G.player.pos);
      later(() => {
        if (!this.alive) return;
        this.queueArea({ pos: p, radius: 1.7, delay: 1.1, dmg: this.dmg * 1.1, knock: 8,
          onTrigger: () => { G.fx.burst('fire', p, { n: 30, r: 0.8, size: 1.5, up: 2 }); G.fx.burst('spark', p.clone().setY(0.3), { n: 15 }); G.fx.flash(p.clone().setY(1), '#ff6020', 8, 0.3); Audio.sfx('explosion', { vol: 0.5 }); G.cam.shake(0.25);
            addHazard({ kind: 'fire', pos: p, radius: 1.4, dps: 12, life: 4, src: this }); } });
        // meteoro caindo
        const m = new THREE.Mesh(new THREE.SphereGeometry(0.4, 10, 8), glowMat('#ff8030', 3)); m.position.set(p.x, 14, p.z); G.scene.add(m);
        G.fx.custom(1.1, (it) => { m.position.y = 14 * (1 - it.t / 1.1); G.fx.burst('fire', m.position, { n: 2, size: 1.2, r: 0.1 }); }, () => G.scene.remove(m));
      }, k * 180);
    }
    this.done(1.8);
  }
  fireballs() {
    this.anim.play('cast', { speed: 0.7 }); Audio.sfx('fire');
    for (let k = 0; k < 5; k++) later(() => {
      if (!this.alive) return;
      const s = this.chestPos().add(new V3(0, 1, 0)); const tg = this.pickTarget();
      const dir = tg.chestPos().sub(s).normalize().applyAxisAngle(up, (k - 2) * 0.12);
      spawnProjectile({ kind: 'orb', pos: s, vel: dir.multiplyScalar(15), team: 'enemy', dmg: 10, radius: 0.5, life: 3, src: this, color: '#ff7020', scale: 1.5,
        trail: (p) => G.fx.burst('fire', p.pos, { n: 1, r: 0.05, size: 0.8 }), onExpire: (p) => { G.fx.burst('fire', p.pos, { n: 12, r: 0.3 }); } });
    }, k * 150);
    this.done(1.2);
  }
  flameRing() {
    const p = this.pos.clone();
    this.queueArea({ pos: p, radius: 7.5, inner: 2.6, delay: 1.3, dmg: this.dmg * 1.2, knock: 10, color: '#ff4010',
      onTrigger: () => { G.fx.ring(p, { color: '#ff6020', r0: 2.6, r1: 8, life: 0.6, intensity: 3 }); for (let k = 0; k < 40; k++) { const a = k / 40 * Math.PI * 2; G.fx.burst('fire', p.clone().add(new V3(Math.cos(a) * 5, 0, Math.sin(a) * 5)), { n: 2, size: 1.4 }); } Audio.sfx('fire'); G.cam.shake(0.5); } });
    this.anim.play('slam', { speed: 0.9 });
    this.done(1.8);
  }
}

// ---------- LORDE KRAUSER, O QUINTO PRESSÁGIO ----------
export class Krauser extends Boss {
  constructor(o = {}) {
    super('krauser', { hp: 1900, dmg: 15, speed: 3.2, poise: 150, radius: 0.6, mass: 5, title: 'O Quinto Presságio', ...o });
    this.name = 'Lorde Krauser'; this.prefDist = 2.6; this.cdBase = 1.3;
    this.tentacles = [new Tentacle(G.scene, -1, 1), new Tentacle(G.scene, 1, 1), new Tentacle(G.scene, -1, -0.3), new Tentacle(G.scene, 1, -0.3)];
    this.tentaclesOn = true;
    this.armorLight = new THREE.PointLight('#3a7aff', 0, 8, 2); G.scene.add(this.armorLight);
    this.aura = new THREE.PointLight('#b070ff', 7, 7, 1.6); G.scene.add(this.aura);
    this.attacks = [
      { w: 3, max: 3.4, cd: 2.4, fn: this.clawCombo },
      { w: 3, cd: 4, fn: this.tentacleSlam },
      { w: 2, max: 6, cd: 7, fn: this.tentacleSweep },
      { w: 2, min: 2, max: 12, cd: 8, fn: this.breath },
      { w: 2, cd: 9, fn: this.blueNova, phase: [2, 3] },
      { w: 1, cd: 14, fn: this.summon, phase: [1, 2] },
    ];
    this.armor = false; this.armorBroken = 0;
  }
  setArmor(on) {
    this.armor = on;
    this.resist = on ? { ice: 0.25 } : null;
    this.armorLight.intensity = on ? 4 : 0;
  }
  update(dt) {
    super.update(dt);
    if (!this.alive && !this.dying) return;
    const back = fwd(this.yaw).multiplyScalar(-1), right = rightOf(this.yaw);
    const base = this.chestPos().addScaledVector(back, 0.25);
    for (const tc of this.tentacles) { tc.setVisible(this.tentaclesOn); if (this.tentaclesOn) tc.update(dt, G.time, base, back, right); }
    if (this.rig.crystal) this.rig.crystal.rotation.y += dt * 3;
    // veneno estrutural: a música corrói por dentro
    this.dmgTakenMul = 1 + Math.min(0.5, (this.resonance || 0) * 0.008);
    if (this.resonance > 20 && Math.random() < 0.15) G.fx.burst('magic', this.chestPos(), { n: 1, color: '#80f0ff', color2: '#ffd070', speed: 0.4, size: 0.6 });
    this.aura.visible = this.root.visible;
    this.aura.position.copy(this.chestPos()).addScaledVector(fwd(this.yaw), 1.1).add(new V3(0, 0.6, 0));
    if (this.armorBroken > 0) { this.armorBroken -= dt; if (this.armor) this.setArmor(false); if (this.armorBroken <= 0 && this.phase >= 3) this.setArmor(true); }
    if (this.armor) {
      this.armorLight.position.copy(this.chestPos());
      if (Math.random() < 0.9) G.fx.burst('fire', this.pos.clone().add(new V3(rnd(-0.5, 0.5), rnd(0.2, 2), rnd(-0.5, 0.5))), { n: 1, color: '#d0e8ff', color2: '#1030ff', size: 0.9, r: 0.05 });
    }
    if (this.phase >= 2 && Math.random() < 0.3) G.fx.burst('shadow', this.pos.clone().setY(rnd(0.2, 2)), { n: 1, r: 0.6 });
  }
  checkPhase() {
    if (this.phaseLock) return;
    if (this.phase === 1 && this.hp <= this.maxHp * 0.6 + 1) { this.phaseLock = true; emit('krauserThreshold', 1); }
    else if (this.phase === 2 && this.hp <= this.maxHp * 0.12 + 1) { this.phaseLock = true; emit('krauserThreshold', 2); }
  }
  remove() { super.remove(); for (const t of this.tentacles) t.dispose(); G.scene.remove(this.armorLight); G.scene.remove(this.aura); }
  tentacleStrike(tc, p, delay = 0.9, dmg = this.dmg * 1.15) {
    this.queueArea({ pos: p, radius: 1.5, delay, dmg, knock: 9,
      onTrigger: () => { G.fx.burst('dust', p, { n: 12 }); G.fx.burst('shadow', p.clone().setY(0.5), { n: 10, r: 0.5 }); G.cam.shake(0.3); Audio.sfx('hitHeavy', { vol: 0.6 }); } });
    later(() => {
      if (!this.alive) return;
      Audio.sfx('tentacle');
      tc.target = p.clone().setY(0.2); let e = 0;
      G.fx.custom(0.7, (it, dt) => { e = it.t < 0.18 ? it.t / 0.18 : Math.max(0, 1 - (it.t - 0.35) / 0.35); tc.extend = e; }, () => { tc.extend = 0; tc.target = null; });
    }, Math.max(0, delay - 0.2) * 1000);
  }
  clawCombo(t) {
    let n = 0;
    const go = () => {
      if (!this.alive || this.ai === 'stun') return;
      this.faceTo(this.target.pos, 1, 99);
      const clip = n % 2 ? 'claw2' : 'claw', y = this.yaw;
      this.vel.copy(fwd(y)).multiplyScalar(3);
      this.anim.play(clip, { speed: 0.85, onEvent: () => {
        Audio.sfx('swing');
        G.fx.slash(this.pos.clone().setY(1.4), y, { roll: n % 2 ? -0.8 : 0.8, flip: n % 2 === 1, color: this.phase >= 2 ? '#6aa0ff' : '#c040ff', intensity: 2, dark: true, scale: 1.1 });
        for (const a of G.actors) if (a.team === 'player' && a.alive && dist2D(a.pos, this.pos) < 2.8 + a.radius && Math.abs(angDiff(yawTo(this.pos, a.pos), y)) < 1.1)
          damage(this, a, this.dmg, { knock: 5 });
      } });
      n++; if (n < (this.phase >= 2 ? 3 : 2)) later(go, 520);
    };
    later(go, 150); this.glint();
    this.done(this.phase >= 2 ? 1.9 : 1.3);
  }
  tentacleSlam(t) {
    this.anim.play('point'); Audio.sfx('tentacle');
    const n = this.phase >= 2 ? 4 : 3;
    const targets = G.actors.filter(a => a.alive && a.team === 'player');
    for (let k = 0; k < n; k++) {
      const tg = k === 0 ? G.player : targets[k % targets.length];
      const p = tg.pos.clone().add(new V3(rnd(-1.6, 1.6), 0, rnd(-1.6, 1.6))); if (k === 0) p.copy(G.player.pos);
      later(() => this.alive && this.tentacleStrike(this.tentacles[k % 4], p), k * 260);
    }
    later(() => this.anim.stop(), 900);
    this.done(1.6);
  }
  tentacleSweep() {
    const p = this.pos.clone();
    this.queueArea({ pos: p, radius: 6, delay: 1.15, dmg: this.dmg * 1.1, knock: 14,
      onTrigger: () => { G.fx.ring(p, { color: '#a040ff', r1: 6.5, life: 0.5 }); G.fx.burst('shadow', p.clone().setY(0.6), { n: 40, r: 4 }); G.cam.shake(0.5); Audio.sfx('tentacle'); Audio.sfx('swingHeavy'); } });
    this.anim.play('roar', { speed: 1.4 });
    let sp = 0;
    G.fx.custom(1.6, (it, dt) => { sp += dt; for (const [i, tc] of this.tentacles.entries()) { if (it.t > 1.0 && it.t < 1.5) { const a = this.yaw + i * Math.PI / 2 + (it.t - 1.0) * 14; tc.target = p.clone().add(new V3(Math.cos(a) * 5, 0.5, Math.sin(a) * 5)); tc.extend = 1; } } },
      () => { for (const tc of this.tentacles) { tc.target = null; tc.extend = 0; } });
    this.done(1.7);
  }
  breath(t) {
    this.faceTo(t.pos, 1, 99);
    const y = this.yaw, p = this.pos.clone();
    const tel = G.fx.telegraph(p, { shape: 'cone', angle: 1.0, radius: 9, yaw: y, time: 0.85, color: this.phase >= 2 ? '#2a60ff' : '#ff4010' });
    (this.pend = this.pend || []).push({ tel });
    this.anim.play('charge'); Audio.sfx('roar', { pitch: 1.2, vol: 0.5 });
    const blue = this.phase >= 2;
    later(() => {
      if (!this.alive || this.ai === 'stun') return;
      Audio.sfx('fire'); Audio.sfx('fire', { delay: 0.5 }); Audio.sfx('fire', { delay: 1.0 });
      let ticks = 0;
      G.fx.custom(1.5, (it, dt) => {
        const mouth = this.headPos(-0.15).addScaledVector(fwd(y), 0.3);
        for (let k = 0; k < 3; k++) {
          const d = fwd(y + rnd(-0.42, 0.42)).multiplyScalar(rnd(8, 13)); d.y = rnd(-1.2, 0.1);
          G.fx.glowP.emit(mouth, d, rnd(0.45, 0.75), 0.2, 0.9, new THREE.Color(blue ? '#a0c8ff' : '#ffb050').multiplyScalar(1.1), new THREE.Color(blue ? '#0a2080' : '#801000'), -1, 1.2, 0.45);
          if (k === 0) G.fx.norm.emit(mouth, d.clone().multiplyScalar(0.7), 0.9, 0.3, 1.3, new THREE.Color('#2a1a18'), new THREE.Color('#0a0808'), -0.5, 1, 0.35);
        }
        if (it.t > ticks * 0.25) { ticks++; for (const a of G.actors) if (a.team === 'player' && a.alive && dist2D(a.pos, p) < 9 && Math.abs(angDiff(yawTo(p, a.pos), y)) < 0.55) damage(this, a, 6, { knock: 2, fx: false, vol: 0.5, element: 'fire' }); }
      }, () => { if (blue) addHazard({ kind: 'blueflame', pos: p.clone().addScaledVector(fwd(y), 5), radius: 2, dps: 12, life: 5, src: this }); });
      later(() => this.anim.stop(), 1500);
    }, 850);
    this.done(2.6);
  }
  blueNova() {
    this.anim.play('roar'); Audio.sfx('reveal', { vol: 0.6 });
    G.ui && G.ui.bark('Krauser', 'Armadura Arcana: Frio Absoluto!');
    const b = G.level.bounds;
    for (let k = 0; k < 6; k++) {
      const a = rnd(0, Math.PI * 2), r = rnd(2, (b && b.r ? b.r : 10) - 2);
      const p = new V3((b.cx || 0) + Math.cos(a) * r, 0, (b.cz || 0) + Math.sin(a) * r);
      if (k === 0) p.copy(G.player.pos);
      this.queueArea({ pos: p, radius: 2, delay: 1.2, dmg: this.dmg, knock: 6, color: '#2a60ff',
        onTrigger: () => { G.fx.burst('fire', p, { n: 20, color: '#e0f0ff', color2: '#1040ff', size: 1.4, up: 2 }); addHazard({ kind: 'blueflame', pos: p, radius: 1.8, dps: 14, life: 6, src: this }); } });
    }
    this.done(1.8);
  }
  summon() {
    this.anim.play('roar', { speed: 1.2 }); Audio.sfx('roar', { pitch: 0.6, vol: 0.6 });
    emit('summonShadows', { n: this.phase >= 2 ? 4 : 3 });
    this.done(1.6);
  }
}

// =====================================================================
//  ALIADOS (Vale das Flores Sangrentas)
// =====================================================================
export class Ally extends Actor {
  constructor(id, o = {}) {
    super(id, { ...o, team: 'player', hp: 200, radius: 0.4, rigOpts: o.rigOpts });
    this.role = o.role || 'melee'; this.cd = rnd(1, 2.5); this.ang = o.ang ?? rnd(0, Math.PI * 2);
    this.downed = 0; this.anim.combat = 1; this.bleeds = true;
    this.anim.onStep = () => {};
  }
  onHit(src, amt, o) { if (this.downed) return; if (o.heavy) this.anim.play('hit'); }
  die() { this.hp = 1; this.knockDown(7); }
  knockDown(t) {
    this.downed = t; this.anim.play('lie'); this.untargetable = true;
    G.ui && G.ui.bark(this.name, this.downText || 'Argh...!');
  }
  update(dt) {
    if (G.cine) { this.vel.multiplyScalar(0.85); this.baseUpdate(dt); return; }
    if (this.downed > 0) {
      this.downed -= dt; this.vel.set(0, 0, 0);
      if (this.downed <= 0) { this.anim.stop(); this.hp = this.maxHp * 0.6; this.untargetable = false; }
      this.baseUpdate(dt); return;
    }
    if (this.scripted) { this.baseUpdate(dt); return; }
    this.hp = Math.min(this.maxHp, this.hp + dt * 3);
    const tgt = G.boss && G.boss.alive ? G.boss : nearestEnemy(this, 40);
    if (!tgt) { this.vel.multiplyScalar(0.8); this.baseUpdate(dt); return; }
    this.ang += dt * 0.25;
    const want = this.role === 'melee' ? tgt.radius + 1.6 : 8.5;
    const goal = tgt.pos.clone().add(new V3(Math.cos(this.ang) * want, 0, Math.sin(this.ang) * want));
    const to = new V3(goal.x - this.pos.x, 0, goal.z - this.pos.z), d = to.length();
    if (!this.anim.busy) {
      if (d > 0.4) this.move(to.normalize(), Math.min(5.5, d * 2), dt, 8); else this.vel.multiplyScalar(0.8);
      this.faceTo(tgt.pos, dt, 8);
    } else this.vel.multiplyScalar(0.8);
    this.cd -= dt;
    if (this.cd <= 0 && dist2D(this.pos, tgt.pos) < (this.role === 'melee' ? tgt.radius + 2.6 : 16)) { this.cd = rnd(1.4, 2.8); this.attack(tgt); }
    this.extra && this.extra(dt);
    this.baseUpdate(dt);
  }
  attack(tgt) {
    this.faceTo(tgt.pos, 1, 99);
    if (this.role === 'ranged') {
      this.anim.play('shoot', { onEvent: () => {
        const s = this.rig.handL.getWorldPosition(new V3());
        const dir = tgt.chestPos().sub(s).normalize();
        Audio.sfx('arrow', { vol: 0.5 });
        const red = this.id === 'calista';
        spawnProjectile({ kind: 'arrow', pos: s, vel: dir.multiplyScalar(30), team: 'player', dmg: red ? 8 : 6, radius: 0.4, life: 1.5, src: this, glow: red, color: '#ff2030', furyGain: 0, knock: 1,
          trail: red ? (p) => G.fx.burst('magic', p.pos, { n: 1, color: '#ff2030', color2: '#600010', speed: 0.1, size: 0.6 }) : null });
      } });
    } else {
      const clip = this.id === 'near' ? (Math.random() < 0.5 ? 'atk1' : 'atk2') : (Math.random() < 0.5 ? 'claw' : 'claw2');
      this.anim.play(clip, { onEvent: () => {
        Audio.sfx('swing', { vol: 0.5 });
        const col = this.id === 'darin' ? '#40ffa0' : '#b070ff';
        G.fx.slash(this.pos.clone().setY(1.1), this.yaw, { color: col, intensity: 2, scale: 0.9, roll: rnd(-0.8, 0.8) });
        if (dist2D(this.pos, tgt.pos) < tgt.radius + 2.8) damage(this, tgt, this.id === 'darin' ? 8 : 7, { knock: 0.5, furyGain: 0, vol: 0.5 });
      } });
    }
  }
}

// =====================================================================
//  NPC
// =====================================================================
export class Npc extends Actor {
  constructor(id, o = {}) {
    super(id, { ...o, team: 'neutral', hp: 999, radius: o.radius ?? 0.4, mass: 50 });
    this.name = o.name || id; this.idleClip = o.clip; this.wander = o.wander;
    if (o.clip) this.anim.play(o.clip, { loop: true });
    this.home = this.pos.clone(); this.wt = rnd(0, 5);
  }
  update(dt) {
    if (this.wander && !G.cine) {
      this.wt -= dt;
      if (this.wt <= 0) { this.wt = rnd(4, 9); this.goal = this.home.clone().add(new V3(rnd(-1, 1) * this.wander, 0, rnd(-1, 1) * this.wander)); }
      if (this.goal) { const to = this.goal.clone().sub(this.pos).setY(0); if (to.length() > 0.3) { this.move(to.normalize(), 1.3, dt, 4); this.faceTo(Math.atan2(to.x, to.z), dt, 4); } else this.vel.multiplyScalar(0.8); }
    } else this.vel.multiplyScalar(0.8);
    this.baseUpdate(dt);
  }
}
