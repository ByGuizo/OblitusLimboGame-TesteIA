// =====================================================================
//  OBLITUS LIMBO — núcleo: renderização, entrada, diretor, menus, loop
// =====================================================================
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { G, updateSystems, separateActors, clearSystems, on } from './world.js';
import { FX } from './fx.js';
import { U } from './models.js';
import { LEVELS } from './levels.js';
import { Player } from './actors.js';
import { CameraCtl } from './camera.js';
import { Audio } from './audio.js';
import { ui } from './ui.js';
import { CHAPTERS, CODEX, DEATH_QUOTES, titleScene } from './story.js';

const $ = (id) => document.getElementById(id);
const V3 = THREE.Vector3;

// ---------------------------------------------------------------------
//  Configurações persistentes
// ---------------------------------------------------------------------
const SAVE_KEY = 'oblitus_limbo_v1';
function loadSave() { try { return JSON.parse(localStorage.getItem(SAVE_KEY)) || {}; } catch (e) { return {}; } }
function writeSave(s) { try { localStorage.setItem(SAVE_KEY, JSON.stringify(s)); } catch (e) {} }
const save = Object.assign({ unlocked: 3, ch: 0, seg: 0, opts: { master: 0.8, music: 0.55, sfx: 0.9, sens: 1, quality: 'high', diff: 1 } }, loadSave());
G.quality = save.opts.quality; G.difficulty = save.opts.diff;

// ---------------------------------------------------------------------
//  Renderizador e pós-processamento
// ---------------------------------------------------------------------
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
const camera = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.1, 400);
G.camera = camera; G.renderer = renderer;
G.scene = new THREE.Scene();

const rt = new THREE.WebGLRenderTarget(innerWidth, innerHeight, { type: THREE.HalfFloatType, samples: 4 });
const composer = new EffectComposer(renderer, rt);
const renderPass = new RenderPass(G.scene, camera);
composer.addPass(renderPass);
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.55, 0.55, 0.82);
composer.addPass(bloom);
composer.addPass(new OutputPass());
const gradeShader = {
  uniforms: { tDiffuse: { value: null }, uTime: { value: 0 }, uHurt: { value: 0 }, uRed: { value: 0 }, uDesat: { value: 0 }, uFlash: { value: 0 }, uHarm: { value: 0 }, uVig: { value: 0 }, uFade: { value: 0 } },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: `uniform sampler2D tDiffuse; uniform float uTime,uHurt,uRed,uDesat,uFlash,uHarm,uVig,uFade; varying vec2 vUv;
    void main(){
      vec2 uv = vUv; vec2 c = uv - 0.5; float d = length(c);
      float ca = 0.0015 + uHurt*0.006 + uRed*0.004;
      vec3 col = vec3(texture2D(tDiffuse, uv + c*ca).r, texture2D(tDiffuse, uv).g, texture2D(tDiffuse, uv - c*ca).b);
      float l = dot(col, vec3(0.299,0.587,0.114));
      // memória: sépia dessaturada
      vec3 sep = vec3(l*1.08, l*0.98, l*0.82);
      col = mix(col, sep, uDesat);
      // apagão: vermelho e preto
      vec3 red = vec3(pow(l,0.8)*1.7, l*0.10, l*0.12);
      col = mix(col, red, uRed*0.78);
      // manifestação harmônica: brilho ciano-dourado
      col += vec3(0.03,0.06,0.07)*uHarm + vec3(0.05,0.03,0.0)*uHarm*l;
      // leve gradação cinematográfica
      col = mix(col, col*vec3(0.95,1.0,1.06), (1.0-l)*0.25);
      float vig = smoothstep(0.9, 0.22, d*(1.0 + uVig + uRed*0.7 + uHurt*0.6 + uDesat*0.5));
      col *= mix(0.22, 1.0, vig);
      col = mix(col, vec3(0.55,0.0,0.02), uHurt*0.3*(1.0-vig));
      float n = fract(sin(dot(uv*vec2(uTime*13.1+1.7, uTime*17.3+3.1), vec2(12.9898,78.233)))*43758.5453);
      col += (n-0.5)*(0.03 + uDesat*0.05);
      col = mix(col, vec3(1.0), uFlash);
      col *= 1.0 - uFade;
      gl_FragColor = vec4(col, 1.0);
    }`,
};
const grade = new ShaderPass(gradeShader);
composer.addPass(grade);
G.post = { hurt: 0, flash: 0, harmonic: 0, red: 0, desat: 0, desatTarget: 0, vig: 0 };

function applyQuality() {
  const q = G.quality;
  const pr = Math.min(devicePixelRatio, q === 'high' ? 1.5 : q === 'med' ? 1.1 : 0.85);
  renderer.setPixelRatio(pr);
  renderer.shadowMap.enabled = q !== 'low';
  bloom.enabled = q !== 'low';
  resize();
}
function resize() {
  renderer.setSize(innerWidth, innerHeight, false);
  composer.setPixelRatio(renderer.getPixelRatio());
  composer.setSize(innerWidth, innerHeight);
  camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  if (G.fx) G.fx.setScale(innerHeight * renderer.getPixelRatio() * 0.85);
}
addEventListener('resize', resize);

// ---------------------------------------------------------------------
//  Entrada
// ---------------------------------------------------------------------
class Input {
  constructor() {
    this.keys = new Set(); this.pr = new Set(); this.mb = new Set(); this.mp = new Set();
    this.mdx = 0; this.mdy = 0; this.locked = false;
    addEventListener('keydown', (e) => {
      if (['Tab', 'Space', 'ArrowUp', 'ArrowDown'].includes(e.code)) e.preventDefault();
      if (e.repeat) return;
      this.keys.add(e.code); this.pr.add(e.code);
      if (e.code === 'Escape') onEscape();
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('mousedown', (e) => { this.mb.add(e.button); this.mp.add(e.button); if (e.button === 1) e.preventDefault(); });
    addEventListener('mouseup', (e) => this.mb.delete(e.button));
    addEventListener('contextmenu', (e) => e.preventDefault());
    addEventListener('mousemove', (e) => { if (this.locked) { this.mdx += e.movementX; this.mdy += e.movementY; } });
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === canvas;
      if (!this.locked && state.mode === 'game' && !G.paused && !state.dead) pause(true);
    });
    addEventListener('blur', () => { this.keys.clear(); this.mb.clear(); });
  }
  held(c) { return this.keys.has(c); }
  pressed(c) { return this.pr.has(c); }
  mouseHeld(b) { return this.mb.has(b); }
  mousePressed(b) { return this.mp.has(b); }
  endFrame() { this.pr.clear(); this.mp.clear(); this.mdx = 0; this.mdy = 0; }
}
G.input = new Input();
G.cam = new CameraCtl(camera);
G.ui = ui;
function lockPointer() { try { const p = canvas.requestPointerLock(); if (p && p.catch) p.catch(() => {}); } catch (e) {} }

// ---------------------------------------------------------------------
//  Carregamento de níveis
// ---------------------------------------------------------------------
function disposeScene(s) {
  s.traverse(o => {
    if (o.geometry && !o.geometry.userData.keep) o.geometry.dispose();
  });
}
const nextFrame = () => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
export async function loadLevel(name, o = {}) {
  $('loading').classList.remove('hidden'); $('loadTxt').textContent = o.label || 'CARREGANDO';
  await nextFrame();
  for (const a of G.actors) a.alive = false;
  clearSystems();
  if (G.fx) G.fx.clear();
  disposeScene(G.scene);
  G.scene = new THREE.Scene();
  renderPass.scene = G.scene;
  G.actors = []; G.player = null; G.boss = null; G.attackTokens = 0; G.objective = null; G.inCombat = false;
  G.fx = new FX(G.scene); G.fx.setScale(innerHeight * renderer.getPixelRatio() * 0.85);
  G.level = LEVELS[name]();
  G.level.key = name;
  if (o.player) {
    const p = new Player(o.player, { pos: (o.pos || G.level.spawn.pos).clone(), yaw: o.yaw ?? G.level.spawn.yaw });
    if (G.difficulty) { p.dmgTakenMul = G.difficulty; }
    G.player = p; ui.setPlayer(p);
    G.cam.snapBehind(p.yaw);
    G.cam.pivot.copy(p.pos).add(new V3(0, 1.5, 0));
    camera.position.copy(p.pos).add(new V3(-Math.sin(p.yaw) * 4, 2.5, -Math.cos(p.yaw) * 4));
    G.cam.look.copy(p.pos).add(new V3(0, 1.4, 0));
  }
  G.cam.mode = 'follow'; G.cam.shotQ = null; G.cam.blendBack = 0;
  // pré-compila shaders para evitar engasgos
  try { renderer.compile(G.scene, camera); } catch (e) {}
  ui.boss(null); ui.killCount(null); ui.prompt(null);
  $('loading').classList.add('hidden');
  return G.level;
}

// ---------------------------------------------------------------------
//  Diretor (roteiro assíncrono com reinício de trecho)
// ---------------------------------------------------------------------
const ABORT = { abort: true };
class Director {
  constructor() { this.waits = []; this.token = 0; this.listeners = []; this.cur = { ch: 0, seg: 0 }; }
  update(dt) {
    const ws = this.waits; this.waits = [];
    for (const w of ws) {
      if (w.token !== this.token) continue;
      w.t += dt;
      let ok = false; try { ok = w.cond(w); } catch (e) { console.error(e); ok = true; }
      if (ok) w.resolve(); else this.waits.push(w);
    }
  }
  until(cond) { const token = this.token; return new Promise((resolve, reject) => this.waits.push({ cond, resolve, reject, token, t: 0 })); }
  wait(sec) { return this.until(w => w.t >= sec); }
  guard(p) { const tok = this.token; return p.then(v => { if (tok !== this.token) throw ABORT; return v; }); }
  abort() {
    this.token++;
    const ws = this.waits; this.waits = [];
    for (const w of ws) w.reject(ABORT);
    for (const off of this.listeners) off(); this.listeners = [];
    if (ui.dlg) { $('dialog').classList.add('hidden'); ui.dlg = null; }
    if (ui.cardP) { $('card').classList.remove('on'); ui.cardP = null; }
    G.cine = false; ui.cine(false); G.flags = {}; Audio.flags = {};
    G.post.desatTarget = 0; G.post.harmonic = 0;
    $('fade').style.opacity = 0;
  }
  listen(name, fn) { this.listeners.push(on(name, fn)); }
  // ---- utilidades de roteiro ----
  load(name, o) { return this.guard(loadLevel(name, o)); }
  async say(lines, { keepCine = false } = {}) {
    this.cine(true);
    await this.guard(ui.dialogue(lines));
    if (!keepCine) this.cine(false);
  }
  card(o) { return this.guard(ui.card(o)); }
  fade(v, d = 1) { return this.guard(ui.fade(v, d)); }
  cine(on) {
    G.cine = on; ui.cine(on);
    if (G.player) {
      if (on) { G.player.setState('cine'); G.player.anim.stop(); G.player.lockTarget = null; G.player.endFury && G.player.furyActive > 0 && G.player.endFury(); }
      else if (G.player.state === 'cine') G.player.setState('move');
    }
    if (!on) G.cam.release(0.9);
  }
  shot(o) { G.cam.shot(o); }
  objective(title, text, pos) { ui.quest(title, text); G.objective = pos ? pos.clone() : null; }
  reach(pos, r = 2) { return this.until(() => G.player && G.player.pos.distanceTo(pos) < r); }
  interact(pos, r, label) {
    return this.until(() => {
      const P = G.player; if (!P || G.cine) return false;
      const near = Math.hypot(P.pos.x - pos.x, P.pos.z - pos.z) < r;
      if (near) { ui.prompt(`<kbd>E</kbd>${label}`); this._prompted = true; }
      else if (this._prompted) { ui.prompt(null); this._prompted = false; }
      if (near && G.input.pressed('KeyE')) { ui.prompt(null); this._prompted = false; return true; }
      return false;
    });
  }
}
export const D = new Director();
G.D = D;

// ---------------------------------------------------------------------
//  Fluxo de jogo
// ---------------------------------------------------------------------
const state = { mode: 'boot', dead: false };
async function runFrom(ch, seg) {
  state.mode = 'game'; state.dead = false; G.paused = false;
  hideScreens(); lockPointer();
  while (true) {
    const chapter = CHAPTERS[ch];
    if (!chapter) { await showCredits(); return; }
    if (seg >= chapter.segments.length) { ch++; seg = 0; save.unlocked = Math.max(save.unlocked, ch); writeSave(save); continue; }
    D.cur = { ch, seg }; save.ch = ch; save.seg = seg; writeSave(save);
    try {
      for (const off of D.listeners) off(); D.listeners = [];
      await chapter.segments[seg](D, G);
      seg++;
    } catch (e) {
      if (e === ABORT) return;
      console.error(e); seg++;
    }
  }
}
function restartSegment() {
  D.abort(); hideScreens(); state.dead = false;
  const { ch, seg } = D.cur;
  setTimeout(() => runFrom(ch, seg), 50);
}
on('playerDead', () => {
  if (state.mode !== 'game' || !G.player || G.player.alive) return;
  state.dead = true;
  $('deathQuote').textContent = DEATH_QUOTES[Math.floor(Math.random() * DEATH_QUOTES.length)];
  $('death').classList.remove('hidden'); requestAnimationFrame(() => $('death').classList.add('on'));
  document.exitPointerLock && document.exitPointerLock();
  Audio.music('limbo', 2);
});

function hideScreens() { for (const id of ['title', 'chapters', 'codex', 'options', 'pause', 'death', 'credits', 'splash']) { $(id).classList.add('hidden'); } $('death').classList.remove('on'); }
function pause(on) {
  if (state.mode !== 'game' || state.dead) return;
  G.paused = on;
  $('pause').classList.toggle('hidden', !on);
  if (on) { document.exitPointerLock && document.exitPointerLock(); Audio.setVolume('music', save.opts.music * 0.4); }
  else { $('options').classList.add('hidden'); lockPointer(); Audio.setVolume('music', save.opts.music); }
}
function onEscape() {
  if (!$('options').classList.contains('hidden') || !$('chapters').classList.contains('hidden') || !$('codex').classList.contains('hidden')) { back(); return; }
  if (state.mode === 'game' && !state.dead) pause(!G.paused);
}
let panelReturn = 'title';
function back() {
  for (const id of ['chapters', 'codex', 'options']) $(id).classList.add('hidden');
  if (panelReturn === 'title') $('title').classList.remove('hidden');
  Audio.sfx('ui');
}
async function toTitle() {
  D.abort(); state.mode = 'title'; G.paused = false; state.dead = false;
  hideScreens(); document.exitPointerLock && document.exitPointerLock();
  ui.showHUD(false); ui.cine(false);
  await titleScene(D, G, loadLevel);
  $('title').classList.remove('hidden');
  $('btnContinue').disabled = !(save.ch > 0 || save.seg > 0);
}
async function showCredits() {
  state.mode = 'credits';
  document.exitPointerLock && document.exitPointerLock();
  ui.showHUD(false);
  const roll = $('creditsRoll');
  roll.innerHTML = `
    <div class="big">OBLITUS LIMBO</div><p><i>Volume I — Demo</i></p>
    <h3>BASEADO NA OBRA DE</h3><p>Guilherme O. Silva (ByGuizo)</p>
    <h3>UM JOGO DA</h3><p>Cordel Interactive</p>
    <h3>PERSONAGENS</h3><p>Kiana · Near Shade · Amnon Akmenos · Darin Leafheart</p><p>Viktor Vanshee · Calista Vanshee</p><p>Lorde Krauser · Darius · Velha Mira · Rurik</p>
    <h3>MÚSICA</h3><p>“O Alvorecer da Ausência” — tema de Kiana</p><p>Trilha procedural sintetizada em tempo real</p>
    <h3>ARTE</h3><p>Ilustrações dos personagens: material original do livro</p><p>Modelos, texturas e efeitos gerados proceduralmente</p>
    <h3>AGRADECIMENTOS</h3><p>Aqueles Que Sabem</p>
    <p style="margin-top:80px;font-style:italic">“O tempo não cura todas as feridas,<br>mas nos ensina a construir algo novo sobre as cicatrizes.”</p>
    <h3 style="margin-top:80px">CONTINUA EM</h3><div class="big" style="font-size:40px">OBLITUS LIMBO: VOLUME II</div>`;
  $('credits').classList.remove('hidden');
  Audio.music('title', 2);
  roll.style.animation = 'none'; void roll.offsetWidth; roll.style.animation = '';
  await new Promise(r => { const t = setTimeout(r, 50000); $('credits').onclick = () => { clearTimeout(t); r(); }; });
  $('credits').classList.add('hidden');
  toTitle();
}

// ---------------------------------------------------------------------
//  Menus
// ---------------------------------------------------------------------
function buildChapterList() {
  const el = $('chapList'); el.innerHTML = '';
  CHAPTERS.forEach((c, i) => {
    const d = document.createElement('div'); d.className = 'chap' + (i > save.unlocked ? ' locked' : '');
    d.innerHTML = `<div class="n">${c.num}</div><div class="t">${c.name}</div><div class="d">${i > save.unlocked ? 'Bloqueado' : c.desc}</div>`;
    d.onclick = () => { Audio.sfx('uiOk'); $('chapters').classList.add('hidden'); startGame(i, 0); };
    el.appendChild(d);
  });
}
function buildCodex() {
  const el = $('codexList'); el.innerHTML = '';
  for (const c of CODEX) {
    const d = document.createElement('div'); d.className = 'cx';
    d.innerHTML = `<div class="im" style="background-image:url(${c.img});${c.pos ? `background-position:${c.pos}` : ''}"></div><div><div class="nm">${c.name}</div><div class="ep">${c.ep}</div><div class="tx">${c.text}</div></div>`;
    el.appendChild(d);
  }
}
function syncOptions() {
  const o = save.opts;
  $('oMaster').value = o.master; $('oMusic').value = o.music; $('oSfx').value = o.sfx; $('oSens').value = o.sens; $('oQuality').value = o.quality; $('oDiff').value = String(o.diff);
}
function bindOptions() {
  const o = save.opts;
  $('oMaster').oninput = (e) => { o.master = +e.target.value; Audio.setVolume('master', o.master); writeSave(save); };
  $('oMusic').oninput = (e) => { o.music = +e.target.value; Audio.setVolume('music', o.music); writeSave(save); };
  $('oSfx').oninput = (e) => { o.sfx = +e.target.value; Audio.setVolume('sfx', o.sfx); Audio.sfx('hit'); writeSave(save); };
  $('oSens').oninput = (e) => { o.sens = +e.target.value; G.cam.sens = o.sens; writeSave(save); };
  $('oQuality').onchange = (e) => { o.quality = e.target.value; G.quality = o.quality; applyQuality(); writeSave(save); };
  $('oDiff').onchange = (e) => { o.diff = +e.target.value; G.difficulty = o.diff; if (G.player) G.player.dmgTakenMul = o.diff; writeSave(save); };
}
function startGame(ch, seg) {
  Audio.sfx('uiOk');
  hideScreens();
  D.abort();
  runFrom(ch, seg);
}
document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-act]'); if (!b) return;
  const a = b.dataset.act; Audio.sfx('ui');
  if (a === 'new') { save.unlocked = Math.max(save.unlocked, 0); startGame(0, 0); }
  else if (a === 'continue') startGame(save.ch, save.seg);
  else if (a === 'chapters') { panelReturn = 'title'; $('title').classList.add('hidden'); buildChapterList(); $('chapters').classList.remove('hidden'); }
  else if (a === 'codex') { panelReturn = 'title'; $('title').classList.add('hidden'); buildCodex(); $('codex').classList.remove('hidden'); }
  else if (a === 'options') { panelReturn = state.mode === 'game' ? 'pause' : 'title'; if (panelReturn === 'title') $('title').classList.add('hidden'); syncOptions(); $('options').classList.remove('hidden'); }
  else if (a === 'credits') { $('title').classList.add('hidden'); showCredits(); }
  else if (a === 'back') back();
  else if (a === 'resume') pause(false);
  else if (a === 'restartSeg') { G.paused = false; $('pause').classList.add('hidden'); restartSegment(); lockPointer(); }
  else if (a === 'retry') { restartSegment(); lockPointer(); }
  else if (a === 'quit') { toTitle(); }
});
canvas.addEventListener('click', () => { if (state.mode === 'game' && !G.paused && !state.dead && !G.input.locked) lockPointer(); });

// ---------------------------------------------------------------------
//  Loop principal
// ---------------------------------------------------------------------
let last = performance.now(), fpsAcc = 0, fpsN = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const rdt = Math.min(0.05, (now - last) / 1000); last = now;
  tick(rdt);
}
function tick(rdt) {
  G.realTime += rdt;
  let dt = rdt;
  if (!G.paused) {
    if (G.slow.t > 0) { G.slow.t -= rdt; dt *= G.slow.scale; }
    if (G.hitstop > 0) { G.hitstop -= rdt; dt *= 0.04; }
    G.time += dt; U.time.value = G.time;
    D.update(dt);
    for (const a of [...G.actors]) if (a.alive || a.dying) a.update(dt);
    separateActors();
    updateSystems(dt);
    G.fx && G.fx.update(dt);
    G.level && G.level.update && G.level.update(dt, G.time);
    if (G.onFrame) G.onFrame(dt);
  } else dt = 0;
  ui.update(G.paused ? 0 : rdt);
  G.cam.update(dt, G.paused ? 0 : rdt);
  // pós-processamento
  const P = G.post, k = Math.min(1, rdt * 4);
  P.hurt = Math.max(0, P.hurt - rdt * 1.4);
  P.flash = Math.max(0, P.flash - rdt * 2.2);
  P.red += ((G.flags.apagao ? 1 : 0) - P.red) * k;
  P.desat += (P.desatTarget - P.desat) * Math.min(1, rdt * 1.5);
  P.harmonicV = (P.harmonicV || 0) + ((P.harmonic || 0) - (P.harmonicV || 0)) * k;
  const u = grade.uniforms;
  u.uTime.value = G.realTime; u.uHurt.value = P.hurt + (G.player && G.player.alive && G.player.hp / G.player.maxHp < 0.25 ? 0.25 + Math.sin(G.realTime * 6) * 0.1 : 0);
  u.uRed.value = P.red; u.uDesat.value = P.desat; u.uFlash.value = Math.min(1, P.flash); u.uHarm.value = P.harmonicV; u.uVig.value = P.vig;
  bloom.strength = 0.55 + P.red * 0.3 + P.harmonicV * 0.4;
  composer.render();
  G.input.endFrame();
}

// ---------------------------------------------------------------------
//  Inicialização
// ---------------------------------------------------------------------
async function boot() {
  applyQuality(); bindOptions(); syncOptions();
  G.cam.sens = save.opts.sens;
  requestAnimationFrame(frame);
  $('clickToStart').onclick = async () => {
    $('clickToStart').classList.add('hidden');
    Audio.init();
    G.paused = false;
    Audio.setVolume('master', save.opts.master); Audio.setVolume('music', save.opts.music); Audio.setVolume('sfx', save.opts.sfx);
    // splash
    $('splash').classList.remove('hidden');
    Audio.sfx('gong', { vol: 0.5 });
    const loadP = titleScene(D, G, loadLevel, true);
    await new Promise(r => setTimeout(r, 4300));
    await loadP;
    $('splash').classList.add('hidden');
    if (state.mode !== 'boot') return;
    state.mode = 'title';
    $('title').classList.remove('hidden');
    $('btnContinue').disabled = !(save.ch > 0 || save.seg > 0);
  };
}
boot();
// acesso de depuração
window.__G = G; window.__D = D; window.__run = (ch, seg) => startGame(ch, seg);
window.__step = (n = 60, dt = 1 / 60, keys = []) => { for (let i = 0; i < n; i++) { for (const k of keys) { if (typeof k === 'number') G.input.mp.add(k); else G.input.pr.add(k); } tick(dt); } return G.time; };
