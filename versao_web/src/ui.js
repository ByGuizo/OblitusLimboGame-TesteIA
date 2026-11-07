// =====================================================================
//  Interface: HUD, minimapa, diálogos, cartões, notificações
// =====================================================================
import * as THREE from 'three';
import { G } from './world.js';
import { Audio } from './audio.js';

const $ = (id) => document.getElementById(id);
const V3 = THREE.Vector3;

export const PORTRAITS = {
  kiana: { img: 'assets/portraits/kiana.jpg', pos: '54% 20%', size: '230%', name: 'Kiana' },
  near: { img: 'assets/portraits/near.jpg', pos: '50% 22%', size: '240%', name: 'Near Shade' },
  amnon: { img: 'assets/portraits/amnon.jpg', pos: '45% 28%', size: '190%', name: 'Amnon Akmenos' },
  darin: { img: 'assets/portraits/darin.jpg', pos: '50% 15%', size: '220%', name: 'Darin Leafheart' },
  calista: { img: 'assets/portraits/calista.jpg', pos: '42% 18%', size: '220%', name: 'Calista Vanshee' },
  viktor: { img: 'assets/portraits/viktor.jpg', pos: '50% 8%', size: '300%', name: 'Viktor Vanshee' },
};
const NAMES = { krauser: 'Lorde Krauser', darius: 'Darius', mira: 'Velha Mira', rurik: 'Rurik', presenca: 'A Presença', segunda: 'A Segunda', lanis: 'Tia Lanis', emma: 'Emma', gyotto: 'Gyotto', voz: '???', mascarado: 'O Mascarado', capanga: 'Capanga', narr: '' };

const ICONS = {
  blade: `<svg viewBox="0 0 48 48"><defs><linearGradient id="gb" x1="0" x2="1"><stop offset="0" stop-color="#c890ff"/><stop offset="1" stop-color="#5ae8ff"/></linearGradient></defs><path d="M8 34C16 14 34 8 42 10C30 14 20 24 16 40Z" fill="url(#gb)"/><path d="M12 30c8-10 18-14 26-16" stroke="#fff" stroke-width="1.5" fill="none" opacity=".8"/><circle cx="38" cy="12" r="2" fill="#fff"/></svg>`,
  wave: `<svg viewBox="0 0 48 48"><g fill="none" stroke="#ffcf70" stroke-width="3" stroke-linecap="round"><path d="M24 30a6 6 0 0 1 0-12"/><path d="M24 30a6 6 0 0 0 0-12"/><path d="M14 36a14 14 0 0 1 0-24" opacity=".85"/><path d="M34 36a14 14 0 0 0 0-24" opacity=".85"/><path d="M7 41a22 22 0 0 1 0-34" opacity=".55"/><path d="M41 41a22 22 0 0 0 0-34" opacity=".55"/></g><circle cx="24" cy="24" r="3" fill="#fff"/></svg>`,
  blink: `<svg viewBox="0 0 48 48"><path d="M24 4l4 22-4 6-4-6z" fill="#ff4a50"/><rect x="18" y="31" width="12" height="3" fill="#ffd0c0"/><rect x="22.5" y="34" width="3" height="9" fill="#5a2020"/><path d="M6 20c6 2 8 8 6 14M42 20c-6 2-8 8-6 14" stroke="#ff3050" stroke-width="2.5" fill="none" opacity=".7"/></svg>`,
  spear: `<svg viewBox="0 0 48 48"><path d="M40 8L18 30l-3 9 9-3L46 14z" fill="#bfefff"/><path d="M8 40l8-8" stroke="#7fd0ff" stroke-width="3"/><path d="M40 8l-6 2 4 4z" fill="#fff"/></svg>`,
  forest: `<svg viewBox="0 0 48 48"><g fill="#a8e8ff"><path d="M10 42l4-22 4 22z"/><path d="M20 42l4-32 4 32z"/><path d="M30 42l4-18 4 18z"/></g><path d="M4 43h40" stroke="#7fd0ff" stroke-width="2"/></svg>`,
  blackice: `<svg viewBox="0 0 48 48"><g fill="#1a3048" stroke="#7fd0ff" stroke-width="1.5"><path d="M6 40l5-14 5 14z"/><path d="M16 40l6-22 6 22z"/><path d="M28 40l5-16 5 16z"/></g><path d="M4 22h18M8 16h14" stroke="#9fe0ff" stroke-width="2" opacity=".7"/></svg>`,
  fury: `<svg viewBox="0 0 48 48"><path d="M24 4c4 8 12 12 12 22a12 12 0 0 1-24 0c0-6 4-8 4-14 3 3 4 6 4 9 4-5 4-11 4-17z" fill="#ff3030"/><circle cx="24" cy="30" r="4" fill="#200"/><circle cx="24" cy="30" r="1.6" fill="#ff8080"/></svg>`,
  harmonic: `<svg viewBox="0 0 48 48"><ellipse cx="20" cy="32" rx="9" ry="10" fill="#c08040"/><circle cx="20" cy="30" r="3" fill="#2a1408"/><rect x="25" y="8" width="4" height="20" transform="rotate(30 27 18)" fill="#8a5a2a"/><path d="M34 10l6-4M36 16l7-2M35 22l7 1" stroke="#7ff0ff" stroke-width="2"/></svg>`,
  punch: `<svg viewBox="0 0 48 48"><circle cx="24" cy="24" r="14" fill="#fff0c0"/><circle cx="24" cy="24" r="20" fill="none" stroke="#ffc040" stroke-width="3" opacity=".7"/><path d="M18 18h12v14H18z" fill="#c08a50"/></svg>`,
  potion: `<svg viewBox="0 0 48 48"><path d="M20 6h8v8l8 10a12 12 0 1 1-24 0l8-10z" fill="#5a1018" stroke="#e8c8a0" stroke-width="1.5"/><path d="M13 30a11 11 0 0 0 22 0z" fill="#e02838"/><circle cx="20" cy="32" r="2" fill="#ff9aa0"/></svg>`,
};

class UI {
  constructor() {
    this.dn = []; this.toastsEl = $('toasts'); this.mm = $('minimap').getContext('2d');
    this.hpLagV = 1; this.bossLagV = 1; this.dlg = null; this.cardP = null;
  }
  showHUD(on) { $('hud').classList.toggle('off', !on); }
  cine(on) { document.body.classList.toggle('cine', on); this.showHUD(!on && !!G.player); }
  setPlayer(p) {
    const pr = PORTRAITS[p.kit];
    const im = $('pimg'); im.style.backgroundImage = `url(${pr.img})`; im.style.backgroundSize = pr.size; im.style.backgroundPosition = pr.pos;
    $('pname').textContent = (p.kit === 'kiana' ? 'KIANA' : 'VIKTOR VANSHEE');
    const sk = $('skills'); sk.innerHTML = '';
    const mk = (icon, num, big = false, cnt = null) => {
      const d = document.createElement('div'); d.className = 'sk' + (big ? ' big' : '');
      d.innerHTML = `<div class="dia"></div><div class="ico">${ICONS[icon]}</div><div class="cdm"></div><div class="cdt"></div><div class="num">${num}</div>${cnt !== null ? `<div class="cnt">x${cnt}</div>` : ''}`;
      sk.appendChild(d); return d;
    };
    this.skEls = p.skills.map((s, i) => mk(s.icon, i + 1));
    this.furyEl = mk(p.kit === 'viktor' ? 'punch' : 'fury', 'F', true);
    this.potEl = mk('potion', 'R', false, p.potions);
    this.updateFuryIcon(p);
  }
  updateFuryIcon(p) {
    if (!this.furyEl) return;
    const ic = p.kit === 'viktor' ? 'punch' : G.flags.harmonic ? 'harmonic' : 'fury';
    if (this.furyEl.dataset.ic !== ic) { this.furyEl.dataset.ic = ic; this.furyEl.querySelector('.ico').innerHTML = ICONS[ic]; }
  }
  skillFlash(i) { const e = this.skEls && this.skEls[i]; if (!e) return; e.classList.add('flash'); setTimeout(() => e.classList.remove('flash'), 150); }
  quest(title, obj) {
    if (title !== undefined && title !== null) $('qTitle').textContent = title;
    const o = $('qObj'); o.classList.remove('done'); o.querySelector('span').textContent = obj || '';
    o.style.display = obj ? 'flex' : 'none';
    $('quest').classList.remove('flash'); void $('quest').offsetWidth; $('quest').classList.add('flash');
    if (obj) Audio.sfx('uiOk', { vol: 0.5 });
  }
  questDone() { $('qObj').classList.add('done'); }
  boss(b) {
    this.bossActor = b;
    $('boss').classList.toggle('hidden', !b);
    if (b) { $('bossName').textContent = b.name.toUpperCase(); $('bossTitle').textContent = b.title || ''; this.bossLagV = b.hp / b.maxHp; }
  }
  killCount(txt) { const k = $('killcount'); k.classList.toggle('hidden', !txt); if (txt) k.textContent = txt; }
  toast(text, color = '#fff', dur = 1.2, big = false) {
    const d = document.createElement('div'); d.className = 'toast' + (big ? ' big' : ''); d.style.color = color; d.textContent = text;
    d.style.animationDuration = (dur + 0.4) + 's';
    this.toastsEl.appendChild(d); setTimeout(() => d.remove(), (dur + 0.4) * 1000);
    while (this.toastsEl.children.length > 3) this.toastsEl.firstChild.remove();
  }
  bark(who, text, dur = 3) {
    const b = $('bark'); const nm = NAMES[who] ?? (PORTRAITS[who] ? PORTRAITS[who].name : who);
    b.innerHTML = (nm ? `<b>${nm}</b>` : '') + text; b.style.opacity = 1;
    clearTimeout(this.barkT); this.barkT = setTimeout(() => { b.style.opacity = 0; }, dur * 1000);
  }
  prompt(txt) { const p = $('prompt'); if (!txt) { p.classList.add('hidden'); return; } p.classList.remove('hidden'); p.innerHTML = txt; }
  damageNumber(pos, amt, o = {}) {
    if (amt <= 0) return;
    const d = document.createElement('div'); d.className = 'dn' + (o.crit ? ' crit' : '') + (o.player ? ' pl' : '');
    d.textContent = (o.crit ? '' : '') + amt; if (o.color) d.style.color = o.color;
    $('dmg').appendChild(d);
    this.dn.push({ el: d, pos: pos.clone().add(new V3((Math.random() - 0.5) * 0.6, 0, (Math.random() - 0.5) * 0.6)), t: 0, vy: 1.4 + Math.random() });
    if (this.dn.length > 40) { const x = this.dn.shift(); x.el.remove(); }
  }
  toScreen(p) {
    const v = p.clone().project(G.camera);
    return { x: (v.x * 0.5 + 0.5) * innerWidth, y: (-v.y * 0.5 + 0.5) * innerHeight, vis: v.z < 1 && v.z > -1 };
  }

  // ---------- diálogo ----------
  dialogue(lines) {
    return new Promise((resolve) => {
      this.dlg = { lines, i: -1, resolve, shown: 0, full: '' };
      $('dialog').classList.remove('hidden');
      this.nextLine();
    });
  }
  nextLine() {
    const d = this.dlg; d.i++;
    if (d.i >= d.lines.length) { $('dialog').classList.add('hidden'); const r = d.resolve; this.dlg = null; r(); return; }
    const L = d.lines[d.i];
    const who = L.who || L[0], text = L.text || L[1];
    const pr = PORTRAITS[who];
    const dp = $('dPortrait');
    if (pr) { dp.classList.remove('none'); dp.style.backgroundImage = `url(${pr.img})`; dp.style.backgroundPosition = pr.pos.replace(/\d+%$/, m => (parseInt(m) * 0.7) + '%'); dp.style.backgroundSize = 'cover'; }
    else dp.classList.add('none');
    $('dName').textContent = (NAMES[who] ?? (pr ? pr.name : who)).toUpperCase();
    d.full = text; d.shown = 0; d.onLine = L.fn;
    $('dText').innerHTML = '';
    L.fn && L.fn();
    Audio.sfx('ui', { vol: 0.35 });
  }
  updateDialogue(dt) {
    const d = this.dlg; if (!d) return;
    if (d.shown < d.full.length) {
      d.shown = Math.min(d.full.length, d.shown + dt * 48);
      $('dText').innerHTML = d.full.slice(0, Math.floor(d.shown)).replace(/\*(.+?)\*/g, '<em>$1</em>').replace(/\*/g, '');
    }
    const inp = G.input;
    if (inp.pressed('Space') || inp.pressed('Enter') || inp.pressed('KeyE') || inp.mousePressed(0)) {
      if (d.shown < d.full.length) { d.shown = d.full.length; $('dText').innerHTML = d.full.replace(/\*(.+?)\*/g, '<em>$1</em>'); }
      else this.nextLine();
    }
  }

  // ---------- cartões ----------
  card(o) {
    return new Promise((resolve) => {
      const c = $('card');
      c.className = (o.cls || '') + ' on';
      $('c1').textContent = o.c1 || ''; $('c2').textContent = o.c2 || ''; $('c3').textContent = o.c3 || ''; $('c4').textContent = o.c4 || '';
      $('crule').style.display = o.c2 && (o.c3 || o.c1) ? 'block' : 'none';
      $('c2').style.display = o.c2 ? 'block' : 'none';
      $('cskip').textContent = o.wait ? 'CLIQUE PARA CONTINUAR ▸' : '';
      this.cardP = { t: 0, dur: o.dur ?? 4, wait: o.wait, resolve, minT: o.minT ?? 1.2 };
    });
  }
  updateCard(dt) {
    const p = this.cardP; if (!p) return;
    p.t += dt;
    const inp = G.input;
    const skip = p.t > p.minT && (inp.pressed('Space') || inp.pressed('Enter') || inp.mousePressed(0));
    if ((!p.wait && p.t >= p.dur) || skip) {
      $('card').classList.remove('on'); this.cardP = null;
      setTimeout(p.resolve, 900);
    }
  }
  fade(to, dur = 1) {
    const f = $('fade'); f.style.transition = `opacity ${dur}s`; f.style.opacity = to;
    return new Promise(r => setTimeout(r, dur * 1000));
  }

  // ---------- atualização ----------
  update(dt) {
    this.updateDialogue(dt); this.updateCard(dt);
    // números de dano
    for (let i = this.dn.length - 1; i >= 0; i--) {
      const n = this.dn[i]; n.t += dt; n.pos.y += n.vy * dt; n.vy *= 0.94;
      const s = this.toScreen(n.pos);
      n.el.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-50%) scale(${n.t < 0.1 ? 1.6 - n.t * 6 : 1})`;
      n.el.style.opacity = s.vis ? Math.max(0, 1 - Math.max(0, n.t - 0.5) * 2) : 0;
      if (n.t > 1.1) { n.el.remove(); this.dn.splice(i, 1); }
    }
    const P = G.player; if (!P) return;
    // barras
    const hp = P.hp / P.maxHp;
    $('hpFill').style.transform = `scaleX(${hp})`;
    this.hpLagV = hp > this.hpLagV ? hp : this.hpLagV - (this.hpLagV - hp) * Math.min(1, dt * 2);
    $('hpLag').style.transform = `scaleX(${this.hpLagV})`;
    $('hpTxt').textContent = Math.ceil(P.hp) + ' / ' + P.maxHp;
    $('enFill').style.transform = `scaleX(${P.energy / P.maxEnergy})`;
    $('stFill').style.transform = `scaleX(${P.stamina / P.maxStamina})`;
    $('fuFill').style.transform = `scaleX(${P.fury / 100})`;
    $('fuBar').classList.toggle('full', P.fury >= 100 && !P.furyActive);
    $('fuTxt').textContent = P.furyActive > 0 ? 'APAGÃO' : P.ult ? 'MANIFESTAÇÃO' : (P.kit === 'viktor' ? 'CHAMA' : 'FÚRIA');
    // habilidades
    if (this.skEls) P.skills.forEach((s, i) => {
      const e = this.skEls[i], cd = P.cd[i];
      e.querySelector('.cdm').style.clipPath = `inset(${(1 - cd / s.cd) * 100}% 0 0 0)`;
      e.querySelector('.cdm').style.opacity = cd > 0 ? 1 : 0;
      e.querySelector('.cdt').textContent = cd > 0 ? Math.ceil(cd) : '';
      e.classList.toggle('nores', P.energy < s.cost);
    });
    if (this.furyEl) { this.furyEl.classList.toggle('ready', P.fury >= 100 && !P.furyActive && !P.ult); this.updateFuryIcon(P); this.furyEl.classList.toggle('nores', P.fury < 100); }
    if (this.potEl) this.potEl.querySelector('.cnt').textContent = 'x' + P.potions;
    // chefe
    const b = this.bossActor;
    if (b) {
      const f = Math.max(0, b.hp / b.maxHp);
      $('bossFill').style.transform = `scaleX(${f})`;
      this.bossLagV = f > this.bossLagV ? f : this.bossLagV - (this.bossLagV - f) * Math.min(1, dt * 1.5);
      $('bossLag').style.transform = `scaleX(${this.bossLagV})`;
      $('bossRes').textContent = b.resonance > 0 ? `RESSONÂNCIA ×${b.resonance}` : (b.armor ? 'FRIO ABSOLUTO — IMUNE A GELO' : '');
      $('bossRes').style.color = b.armor ? '#7aa8ff' : '#80f0ff';
    }
    // marcador de trava
    const lm = $('lockmark');
    if (P.lockTarget && P.lockTarget.alive) {
      const s = this.toScreen(P.lockTarget.chestPos());
      lm.classList.toggle('hidden', !s.vis); lm.style.left = s.x + 'px'; lm.style.top = s.y + 'px';
    } else lm.classList.add('hidden');
    this.drawMinimap();
  }
  drawMinimap() {
    const c = this.mm, W = 400, P = G.player, L = G.level; if (!P || !L) return;
    c.clearRect(0, 0, W, W);
    c.save();
    c.beginPath(); c.arc(W / 2, W / 2, W / 2, 0, Math.PI * 2); c.clip();
    const grd = c.createRadialGradient(W / 2, W / 2, 20, W / 2, W / 2, W / 2);
    grd.addColorStop(0, '#2a2a2e'); grd.addColorStop(1, '#0b0b0e'); c.fillStyle = grd; c.fillRect(0, 0, W, W);
    const scale = L.bounds.type === 'circle' || (L.bounds.maxX - L.bounds.minX) < 30 ? 8 : 6; // px por metro
    const yaw = G.cam.yaw;
    c.translate(W / 2, W / 2);
    c.rotate(yaw);
    const tx = (p) => [-(p.x - P.pos.x) * scale, -(p.z - P.pos.z) * scale];
    // forma do nível
    c.strokeStyle = 'rgba(200,180,140,.45)'; c.lineWidth = 3; c.fillStyle = 'rgba(80,70,60,.35)';
    const b = L.bounds;
    if (b.type === 'box') { const [x0, z0] = tx({ x: b.minX, z: b.minZ }), [x1, z1] = tx({ x: b.maxX, z: b.maxZ }); c.fillRect(Math.min(x0, x1), Math.min(z0, z1), Math.abs(x1 - x0), Math.abs(z1 - z0)); c.strokeRect(Math.min(x0, x1), Math.min(z0, z1), Math.abs(x1 - x0), Math.abs(z1 - z0)); }
    else { const [x, z] = tx({ x: b.cx || 0, z: b.cz || 0 }); c.beginPath(); c.arc(x, z, b.r * scale, 0, Math.PI * 2); c.fill(); c.stroke(); }
    c.fillStyle = 'rgba(30,26,22,.8)';
    for (const o of L.obstacles || []) {
      if (o.r !== undefined) { const [x, z] = tx(o); c.beginPath(); c.arc(x, z, Math.max(2, o.r * scale), 0, Math.PI * 2); c.fill(); }
      else { const [x0, z0] = tx({ x: o.minX, z: o.minZ }), [x1, z1] = tx({ x: o.maxX, z: o.maxZ }); c.fillRect(Math.min(x0, x1), Math.min(z0, z1), Math.abs(x1 - x0), Math.abs(z1 - z0)); }
    }
    // atores
    for (const a of G.actors) {
      if (a === P || !a.alive) continue;
      const [x, z] = tx(a.pos);
      c.fillStyle = a.team === 'enemy' ? (a.boss ? '#ff2020' : '#d83030') : a.team === 'player' ? '#50e090' : '#e8c870';
      c.beginPath(); c.arc(x, z, a.boss ? 11 : a.team === 'neutral' ? 6 : 7, 0, Math.PI * 2); c.fill();
      if (a.boss) { c.strokeStyle = '#ffb0a0'; c.lineWidth = 2; c.stroke(); }
    }
    // objetivo
    if (G.objective) {
      let [x, z] = tx(G.objective);
      const d = Math.hypot(x, z), m = W / 2 - 18;
      if (d > m) { x = x / d * m; z = z / d * m; }
      c.save(); c.translate(x, z); c.rotate(Math.PI / 4); c.fillStyle = '#ffd060'; c.strokeStyle = '#000'; c.lineWidth = 2;
      c.fillRect(-8, -8, 16, 16); c.strokeRect(-8, -8, 16, 16); c.restore();
    }
    c.restore();
    // jogador (seta) — sempre no centro, aponta para onde o personagem olha
    c.save(); c.translate(W / 2, W / 2); c.rotate(-(P.yaw - yaw));
    c.fillStyle = '#ffffff'; c.beginPath(); c.moveTo(0, -16); c.lineTo(11, 12); c.lineTo(0, 6); c.lineTo(-11, 12); c.closePath(); c.fill();
    c.restore();
    // aro
    c.strokeStyle = 'rgba(201,178,122,.6)'; c.lineWidth = 4; c.beginPath(); c.arc(W / 2, W / 2, W / 2 - 3, 0, Math.PI * 2); c.stroke();
  }
}
export const ui = new UI();
