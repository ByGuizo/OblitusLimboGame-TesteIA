// =====================================================================
//  ROTEIRO — adaptação de "Oblitus Limbo: Volume I" (ByGuizo)
// =====================================================================
import * as THREE from 'three';
import { G, rnd, fwd, yawTo, dist2D, after, spawnProjectile } from './world.js';
import { Npc, Thug, Archer, Darius, Elemental, Krauser, Ally, Player } from './actors.js';
import { Audio } from './audio.js';
import { ui } from './ui.js';
import { glowMat } from './models.js';

const V3 = THREE.Vector3;
const v = (x, y, z) => new V3(x, y, z);

// ---------------------------------------------------------------------
//  Utilidades de cena
// ---------------------------------------------------------------------
function orbit(center, r, h, a0, a1, dur, lookH = 1.4) {
  return { pos: center.clone(), look: center.clone(), dur, blend: 0.0001, track: (t) => {
    const a = a0 + (a1 - a0) * Math.min(1, t / dur);
    return { pos: center.clone().add(v(Math.sin(a) * r, h, Math.cos(a) * r)), look: center.clone().add(v(0, lookH, 0)) };
  } };
}
// tomada sobre o ombro de A olhando para B
function ots(a, b, { side = 1, dist = 1.6, h = 1.55, fov = 42, dur = 4, blend = 0.6 } = {}) {
  const dir = b.pos.clone().sub(a.pos).setY(0).normalize();
  const right = v(-dir.z, 0, dir.x).multiplyScalar(side);
  const pos = a.pos.clone().addScaledVector(dir, -dist).addScaledVector(right, 0.7).add(v(0, h, 0));
  const look = b.pos.clone().add(v(0, (b.rig ? b.rig.height * 0.85 : 1.5), 0));
  return { pos, look, pos2: pos.clone().addScaledVector(dir, 0.25), look2: look, fov, dur, blend };
}
function closeup(a, { dist = 1.5, side = 0.4, h = 0, fov = 38, dur = 4, blend = 0.6 } = {}) {
  const f = fwd(a.yaw), r = v(-f.z, 0, f.x);
  const head = a.headPos(-0.08 + h);
  const pos = head.clone().addScaledVector(f, dist).addScaledVector(r, side);
  return { pos, look: head, pos2: pos.clone().addScaledVector(f, -0.2), look2: head, fov, dur, blend };
}
function face(actor, target) { actor.yaw = yawTo(actor.pos, target.pos || target); actor.root.rotation.y = actor.yaw; }
function task(D, fn) { fn().catch(e => { if (!e || !e.abort) console.error(e); }); }
function tintActor(a, f) {
  for (const m of a.flashMats) { if (!m.userData.baseCol) m.userData.baseCol = m.color.clone(); m.color.copy(m.userData.baseCol).multiplyScalar(f); }
}
function restoreTint(a) { for (const m of a.flashMats) if (m.userData.baseCol) m.color.copy(m.userData.baseCol); }
const diff = () => G.difficulty || 1;

export const DEATH_QUOTES = [
  '“Se eu não lembrava do que tinha feito, como eu podia garantir que não faria de novo?”',
  '“A gente segue lembrando, Kiana. Não da morte... mas do que veio antes dela.”',
  '“Você não nasceu para ser odiada, mas para ser a resposta que este mundo ainda não sabe que precisa.”',
  '“O tempo não cura todas as feridas, mas nos ensina a construir algo novo sobre as cicatrizes.”',
  '“Corações pesados são lentos. Corações partidos são fáceis de esmagar.”',
];

// =====================================================================
//  TELA-TÍTULO — Vardun ao luar
// =====================================================================
export async function titleScene(D, G, loadLevel, first = false) {
  await loadLevel('vardun', { label: first ? 'DESPERTANDO VARDUN' : 'CARREGANDO' });
  const k = new Npc('kiana', { pos: v(0.6, 0, -18), yaw: 0.25, name: 'Kiana' });
  const n = new Npc('near', { pos: v(-2.8, 0, -12), yaw: 2.6, name: 'Near' });
  n.anim.play('kneel');
  for (let i = 0; i < 4; i++) new Npc('townsfolk', { pos: v(rnd(-3, 3), 0, rnd(-4, 30)), yaw: rnd(0, 6), seed: i * 13 + 5, wander: 2 });
  G.cam.mode = 'cine';
  G.cam.shot({ pos: v(0, 3, -26), look: v(0, 2, -10), dur: 60, blend: 0.0001, track: (t) => {
    const a = -0.6 + Math.sin(t * 0.05) * 0.5;
    return { pos: v(0.6 + Math.sin(a) * 6.5, 2.0 + Math.sin(t * 0.07) * 0.4, -18 - Math.cos(a) * 6.5), look: v(0.6 + Math.sin(t * 0.04) * 0.6, 2.3, -18) };
  } });
  Audio.music('title', 2); Audio.stopLoops(); Audio.loop('wind', true, 0.4);
}

// =====================================================================
//  PRÓLOGO — A PRESENÇA
// =====================================================================
async function prologue(D, G) {
  ui.showHUD(false);
  await D.fade(1, 0.01);
  const L = await D.load('limbo', { label: 'O LIMBO' });
  Audio.music('limbo', 2); Audio.stopLoops(); Audio.loop('rumble', true, 0.8);
  // a Segunda
  const seg = new Npc('shadow', { pos: v(0, 0, 4), yaw: 0, name: 'A Segunda' });
  seg.anim.play('float'); seg.flying = true;
  tintActor(seg, 1);
  const tears = G.fx.custom(9999, () => { if (Math.random() < 0.15) G.fx.burst('blood', seg.headPos(-0.1).add(fwd(seg.yaw).multiplyScalar(0.1)), { n: 1 }); });
  D.cine(true); ui.showHUD(false);
  G.cam.shot({ pos: v(0, 2, -10), look: v(0, 4, 30), pos2: v(0, 2.6, -2), look2: v(0, 4.5, 30), dur: 14, blend: 0.0001, fov: 50 });
  await D.fade(0, 3);
  await D.card({ c3: 'No coração do Limbo, a escuridão não era o fim do dia.\nEra uma entidade viva, pulsante,\ncomo as paredes de um estômago faminto.', dur: 6.5, cls: 'clear' });
  G.cam.shot({ pos: v(1.6, 2.2, 1.2), look: seg.headPos(), dur: 8, fov: 40 });
  await D.say([
    { who: 'segunda', text: 'Mestre... o Quinto Fio foi cortado.' },
  ], { keepCine: true });
  Audio.sfx('heartbeat', { vol: 1.5 }); G.cam.shake(0.5);
  G.cam.shot({ pos: v(0, 3, -1), look: v(0, 4.5, 30), pos2: v(0, 3.5, 6), dur: 10, fov: 45 });
  const rumble = (fn) => () => { Audio.sfx('heartbeat', { vol: 1.4 }); G.cam.shake(0.45); fn && fn(); };
  await D.say([
    { who: 'presenca', text: 'E a Peça Perdida?', fn: rumble() },
    { who: 'segunda', text: 'Continua oculta. Mas, ao perecer, ele arrastou consigo *Aquele que Sabe*... e seus companheiros.' },
    { who: 'presenca', text: '...', fn: rumble(() => Audio.sfx('reveal', { vol: 0.5 })) },
    { who: 'presenca', text: 'Não os cace. Deixe-os vagar pelo desespero das terras esquecidas.', fn: rumble() },
    { who: 'presenca', text: 'Eles acham que sobreviveram a uma batalha, mas apenas entraram no matadouro por vontade própria.', fn: rumble() },
    { who: 'presenca', text: 'Vigie, Segunda. A caçada não acabou. Ela apenas se tornou... *doméstica*.', fn: rumble(() => { G.post.flash = 0.3; }) },
  ], { keepCine: true });
  tears.kill = true;
  await D.fade(1, 2.5);
  Audio.stopLoops();
  await D.card({ c3: 'Mas toda queda tem um começo.', dur: 3.2 });
}

// =====================================================================
//  CAPÍTULO I — UM FOGO QUE NÃO PERTENCE A ESTE MUNDO
// =====================================================================
async function c1_vardun(D, G) {
  await D.fade(1, 0.01);
  await D.card({ c1: 'CAPÍTULO I', c2: 'Um Fogo que Não Pertence a Este Mundo', c3: 'Vardun', dur: 5 });
  const L = await D.load('vardun', { player: 'kiana', label: 'VARDUN' });
  Audio.music('vardun', 2); Audio.stopLoops(); Audio.loop('wind', true, 0.35);
  const P = G.player;
  const mira = new Npc('mira', { pos: L.points.mira, yaw: -1.2, name: 'Velha Mira' });
  const rurik = new Npc('rurik', { pos: L.points.rurik, yaw: Math.PI / 2, name: 'Rurik' });
  const near = new Npc('near', { pos: L.points.near, yaw: Math.PI / 2 + 0.4, name: 'Near' });
  const folks = [];
  for (let i = 0; i < 7; i++) folks.push(new Npc('townsfolk', { pos: v(rnd(-3, 3), 0, rnd(-20, 34)), yaw: rnd(0, 6), seed: i * 31 + 2, wander: 2.5 }));
  ui.quest('A Fúria de Vardun', '');
  D.cine(true);
  D.shot({ pos: v(2, 7, 30), look: v(0, 1, -10), pos2: v(1.5, 2.6, -16), look2: P.headPos(), dur: 8, blend: 0.0001, fov: 55 });
  await D.fade(0, 2.5);
  await D.wait(6.5);
  D.shot(closeup(P, { dur: 6, dist: 1.7 }));
  await D.say([
    { who: 'kiana', text: 'Três dias desde o aniversário do Viktor. Três dias desde que encontraram a Lili naquela viela.' },
    { who: 'kiana', text: 'Ele pegou a adaga do Kael, me olhou como quem já tinha decidido tudo — “Vou acabar com isso” — e sumiu na noite.' },
    { who: 'kiana', text: 'Ninguém em Vardun diz nada. Mas todo mundo sabe de alguma coisa.' },
  ]);
  ui.toast('WASD mover · Mouse câmera · Shift correr', '#e8dcc0', 3.5);
  D.objective('A Fúria de Vardun', 'Despeça-se de Lili no memorial', L.points.memorial);
  await D.interact(mira.pos, 2.6, 'Falar com a Velha Mira');
  face(P, mira); face(mira, P);
  D.cine(true);
  D.shot(ots(P, mira, { dur: 30 }));
  await D.say([
    { who: 'mira', text: 'Ela gostava de morder frutas azedas demais só pra rir do próprio susto. Você lembra?' },
    { who: 'kiana', text: 'Lembro. Ela merecia mais do que uma viela escura e um bando de covardes.' },
    { who: 'mira', text: 'A gente segue lembrando, Kiana. Não da morte... mas do que veio antes dela.', fn: () => D.shot(closeup(mira, { dur: 8, dist: 1.3 })) },
    { who: 'mira', text: 'E você, minha menina, tem algo dentro de si que ainda não compreendeu.' },
    { who: 'mira', text: '*Um fogo que não pertence a este mundo.*', fn: () => { Audio.sfx('reveal', { vol: 0.4 }); G.fx.burst('ember', P.pos, { n: 25, r: 1 }); } },
    { who: 'kiana', text: 'Fogo? Vovó Mira, eu mal consigo controlar o meu rubor.', fn: () => D.shot(closeup(P, { dur: 6 })) },
    { who: 'mira', text: 'Hehe. Vá. O Rurik sabe mais do que diz.' },
  ]);
  ui.questDone();
  D.objective(null, 'Vá até a Taverna de Rurik', L.points.rurik);
  let nearSpoke = false;
  task(D, async () => { await D.reach(near.pos, 4.5); if (!nearSpoke) { nearSpoke = true; ui.bark('near', 'Kiana. Você não dormiu de novo, né?', 3.5); } });
  await D.interact(rurik.pos, 2.6, 'Falar com Rurik');
  face(P, rurik); face(rurik, P);
  D.cine(true);
  D.shot(ots(P, rurik, { dur: 30, side: -1 }));
  await D.say([
    { who: 'kiana', text: 'Três dias, Rurik. Nenhuma notícia. E você aí, polindo copo como se nada estivesse acontecendo.' },
    { who: 'rurik', text: 'O Viktor sabe se cuidar, garota.' },
    { who: 'kiana', text: 'Ele é SEU FILHO! Como você consegue ficar parado?!', fn: () => { G.cam.shake(0.2); D.shot(closeup(rurik, { dur: 8, dist: 1.6, h: 0.1 })); } },
    { who: 'rurik', text: '...' },
    { who: 'rurik', text: 'Darius. O Viktor estava atrás do Darius.' },
    { who: 'kiana', text: 'O maior criminoso de Vardun. Ótimo.', fn: () => D.shot(closeup(P, { dur: 6 })) },
    { who: 'rurik', text: 'Kiana. Não vá sozinha.' },
    { who: 'kiana', text: 'Eu vou resolver isso. Sozinha.' },
  ]);
  ui.bark('near', 'Kiana, espera—', 2.5);
  ui.questDone();
  D.objective(null, 'Encontre a taverna de Darius no bairro pobre', L.points.darius);
  await D.reach(L.points.darius, 2.4);
  D.cine(true);
  D.shot({ pos: P.pos.clone().add(v(2.5, 1.4, -2.5)), look: v(0, 2.5, 41), dur: 4, fov: 45 });
  await D.say([{ who: 'kiana', text: 'Um tumor antigo, sufocado entre construções tortas. Combina com o dono.' }], { keepCine: true });
  Audio.sfx('whoosh');
  await D.fade(1, 1.4);
}

async function c1_tavern(D, G) {
  await D.fade(1, 0.01);
  const L = await D.load('tavern', { player: 'kiana', label: 'A TAVERNA DE DARIUS' });
  Audio.music('silence'); Audio.stopLoops(); Audio.loop('fire', true, 0.5);
  const P = G.player;
  ui.quest('A Fúria de Vardun', 'Confronte Darius');
  const dar = new Npc('darius', { pos: L.points.darius.clone(), yaw: Math.PI, name: 'Darius' });
  const spots = [[-3.5, 1.5], [3.5, 2], [-5.5, -1.5], [5.5, -2], [-2, 5.2], [2.5, 5.6]];
  const thugs = spots.map(([x, z], i) => { const t = new Thug({ pos: v(x, 0, z), seed: i * 7 + 3 }); face(t, P); t.ai = 'spawn'; return t; });
  D.cine(true);
  D.shot({ pos: v(2.2, 1.9, -9.4), look: v(0, 1.3, 3), pos2: v(1.6, 1.7, -7.4), dur: 6, blend: 0.0001, fov: 50 });
  await D.fade(0, 2);
  Audio.sfx('step', { wood: true }); await D.wait(1.5);
  D.shot(closeup(dar, { dur: 10, dist: 2.2, side: 0.6, fov: 40 }));
  await D.say([
    { who: 'darius', text: 'Ora, ora. A aberração de estimação do Vanshee.' },
    { who: 'kiana', text: 'Onde ele está, Darius?', fn: () => D.shot(ots(P, dar, { dur: 20 })) },
    { who: 'darius', text: 'Eu só fiz o trabalho sujo, menina. Um mascarado apareceu do nada... obrigou meus rapazes a caçar aqueles tieflings.' },
    { who: 'darius', text: 'E o mestre desse mascarado queria o seu Viktor. *Vivo*.' },
    { who: 'kiana', text: 'O que vocês fizeram com ele?!' },
    { who: 'darius', text: 'Rapazes... façam o que quiserem com ela.', fn: () => { dar.yaw = 0; dar.root.rotation.y = 0; Audio.sfx('grunt'); } },
  ], { keepCine: true });
  D.shot(closeup(P, { dur: 8, dist: 1.0, fov: 34 }));
  G.post.vig = 0.5;
  await D.say([
    { who: 'kiana', text: 'Todo mundo sempre machuca quem eu amo. E eu nunca consigo fazer nada. Nunca consigo proteger ninguém.' },
    { who: 'kiana', text: 'Já que vocês machucaram ele...', fn: () => { Audio.sfx('heartbeat', { vol: 1.5 }); } },
    { who: 'kiana', text: '*VOU MATAR TODOS VOCÊS!*', fn: () => { G.flags.apagao = true; Audio.sfx('fury'); G.cam.shake(0.6); for (const e of P.rig.eyes) e.scale.multiplyScalar(1.8); } },
  ], { keepCine: true });
  G.flags.apagao = false; G.post.vig = 0; for (const e of P.rig.eyes) e.scale.set(1.2, 0.8, 0.5);
  dar.remove();
  D.cine(false); G.inCombat = true;
  Audio.music('battle', 0.5); Audio.intensity = 0.5;
  P.fury = 100;
  ui.toast('A FÚRIA TRANSBORDA — [F] APAGÃO', '#ff3030', 3);
  ui.bark('narr', 'Clique: atacar (combo) · Espaço: esquivar · Clique direito: defender (no tempo certo, aparar) · 1 2 3: habilidades · Q: travar alvo', 9);
  // ---- ondas ----
  let killed = 0; const TOTAL = 19;
  const upd = () => ui.killCount(`HOMENS DE DARIUS · ${killed} / ${TOTAL}`);
  upd();
  D.listen('kill', (e) => { if (e instanceof Thug || e instanceof Archer) { killed++; upd(); } });
  D.objective(null, 'Sobreviva aos homens de Darius', null);
  for (const t of thugs) { t.ai = 'approach'; t.cd = rnd(0.2, 1.5); }
  await D.until(() => thugs.every(t => !t.alive));
  const doors = [L.points.doorBack, L.points.doorRight, L.points.doorLeft, L.points.stairs];
  const spawnWave = async (defs) => {
    const list = [];
    for (let i = 0; i < defs.length; i++) {
      const d = defs[i], at = doors[i % doors.length].clone().add(v(rnd(-0.6, 0.6), 0, rnd(-0.6, 0.6)));
      G.fx.burst('dust', at, { n: 8 });
      const e = d === 'archer' ? new Archer({ pos: at, seed: 4 + i }) : new Thug({ pos: at, seed: i * 11 + (d === 'heavy' ? 2 : 1), weapon: d === 'heavy' ? 'axe' : undefined, hp: d === 'heavy' ? 80 : 42 });
      face(e, P); list.push(e);
      if (i % 2 === 1) await D.wait(0.9);
    }
    return list;
  };
  ui.bark('darius', 'Que diabos estão esperando?! PEGUEM ELA!', 3);
  Audio.intensity = 0.7;
  let w = await spawnWave(['thug', 'thug', 'archer', 'thug', 'thug', 'archer']);
  await D.until(() => w.every(t => !t.alive));
  await D.wait(1);
  ui.bark('capanga', 'Ela... ela não é humana!', 2.5);
  w = await spawnWave(['heavy', 'thug', 'archer', 'thug', 'heavy', 'thug', 'archer']);
  await D.until(() => w.every(t => !t.alive));
  ui.killCount(null);
  // ---- Darius ----
  await D.wait(0.8);
  D.cine(true);
  const boss = new Darius({ pos: v(0, 0, 6.5), yaw: Math.PI });
  boss.maxHp = boss.hp = Math.round(720 * diff());
  face(boss, P);
  D.shot({ pos: v(1.5, 1.2, 3.5), look: boss.headPos(), pos2: v(1.0, 1.0, 4.2), dur: 4, fov: 40 });
  boss.anim.play('roar'); Audio.sfx('roar');
  await D.say([{ who: 'darius', text: 'Inúteis. Todos vocês. Eu mesmo faço isso.' }], { keepCine: true });
  D.cine(false);
  ui.boss(boss); Audio.music('boss_darius', 0.6);
  D.objective(null, 'Derrote Darius', null);
  boss.minHp = 1;
  D.listen('bossPhase', async (e) => {
    if (e.boss !== boss) return;
    ui.bark('darius', 'ACABEM COM ESSA ABERRAÇÃO!', 3);
    const extra = await spawnWave(['thug', 'archer', 'thug', 'heavy']);
    task(D, async () => { await D.until(() => extra.every(t => !t.alive)); });
  });
  await D.until(() => boss.hp <= 1);
  // ---- golpe final ----
  boss.invulnerable = true; boss.clearPending(); boss.busy = true;
  for (const a of G.actors) if (a !== P && a !== boss && a.team === 'enemy') a.die && a.die();
  D.cine(true); ui.boss(null);
  G.slow = { t: 2.5, scale: 0.25 }; G.flags.apagao = true;
  P.pos.copy(boss.pos).addScaledVector(fwd(boss.yaw), 1.3); face(P, boss);
  G.fx.burst('shadow', P.pos.clone().setY(1), { n: 40, r: 0.5, speed: 2 });
  D.shot({ pos: boss.pos.clone().add(v(2.4, 1.3, 0.4)), look: P.pos.clone().lerp(boss.pos, 0.5).setY(1.4), dur: 3, fov: 36, cut: true });
  P.anim.play('atk3', { speed: 0.8 });
  Audio.sfx('blink'); await D.wait(0.25);
  Audio.sfx('crit'); G.cam.shake(0.7); G.post.flash = 0.5;
  G.fx.burst('blood', boss.chestPos(), { n: 30 }); G.fx.burst('spark', boss.chestPos(), { n: 30, color: '#ffffff', color2: '#80c0ff' });
  boss.anim.play('kneel');
  await D.wait(0.6);
  ui.toast('Darius morreu sem entender como morreu tão rápido.', '#e8dcc0', 3);
  boss.minHp = undefined; boss.invulnerable = false; boss.hp = 0; boss.die(P);
  await D.wait(0.7);
  G.flags.apagao = false;
  Audio.music('silence', 2);
  await D.fade(1, 2);
  await D.card({ cls: 'memory', c3: '“Minha memória daquela noite não era um borrão. Era um buraco.\nUm abismo negro onde o tempo tinha sumido.”', dur: 6 });
  await D.card({ cls: 'memory', c3: '“Eu lembrava de entrar na taverna...\ne depois, lembrava de estar parada no meio de corpos mutilados.\nO meio — o grito, o corte, a fúria — tinha sido roubado de mim.”', dur: 7 });
  // Near chega
  P.anim.play('kneel'); G.inCombat = false;
  const near = new Npc('near', { pos: L.points.doorBack.clone().add(v(0, 0, 1)), yaw: 0, name: 'Near' });
  face(near, P);
  D.shot({ pos: P.pos.clone().add(v(-2.2, 1.0, -1.6)), look: P.headPos(-0.5), dur: 8, blend: 0.0001, fov: 40 });
  await D.fade(0, 2);
  await D.say([
    { who: 'near', text: 'Kiana...?' },
    { who: 'kiana', text: '...Near? O que... o que aconteceu aqui?' },
    { who: 'near', text: '...', fn: () => D.shot(closeup(near, { dur: 6 })) },
    { who: 'near', text: 'Você não lembra.' },
    { who: 'kiana', text: 'Tem uma carta. Debaixo dele. Ensanguentada.', fn: () => D.shot(closeup(P, { dur: 6, h: -0.3 })) },
  ], { keepCine: true });
  await D.fade(1, 1.5);
  await D.card({ cls: 'diary', c1: 'A CARTA ENSANGUENTADA', c3: '“...Calista retorna de EmberFall...\n...a cidade murada de Hikari...\n...algum dos presságios está escondido...”', dur: 7 });
  await D.card({ c3: 'O sangue seco sob as unhas levou três dias para sair.\nE uma certeza muda ficou no peito:\nalgo dentro dela sabia exatamente como matar.\nE esse algo estava acordado.', dur: 8 });
}

// =====================================================================
//  CAPÍTULO II — O VALE DAS FLORES SANGRENTAS
// =====================================================================
async function c2_valley(D, G) {
  await D.fade(1, 0.01);
  await D.card({ c1: 'CAPÍTULO II', c2: 'O Vale das Flores Sangrentas', c3: 'Entre Vardun e Hikari', dur: 5 });
  Audio.music('valley', 2);
  await D.card({ cls: 'diary', c1: 'DIÁRIO DE KIANA — DIA 1', c3: 'Near, Amnon e Darin estavam no portão de Vardun, mochilas nas costas.\nNinguém perguntou nada. Eu também não expliquei.', dur: 6 });
  await D.card({ cls: 'diary', c1: 'DIA 3', c3: 'A comida acabou.', dur: 3 });
  await D.card({ cls: 'diary', c1: 'DIA 5', c3: 'As árvores são as mesmas. Eu juro que são as mesmas árvores.', dur: 4 });
  await D.card({ cls: 'diary', c1: 'DIA 7', c3: 'Amnon tentou morder o braço do Darin durante a vigília.\n“Só um pedacinho”, ele disse.', dur: 5 });
  const L = await D.load('valley', { player: 'kiana', label: 'O VALE DAS FLORES SANGRENTAS' });
  Audio.stopLoops(); Audio.loop('wind', true, 0.5); Audio.loop('fire', true, 0.3);
  const P = G.player;
  const near = new Npc('near', { pos: v(-2.2, 0, 1.4), yaw: 2.2, name: 'Near' }); near.anim.play('kneel');
  const amnon = new Npc('amnon', { pos: v(1.9, 0, -2.0), yaw: -0.5, name: 'Amnon' }); amnon.anim.play('lie');
  const darin = new Npc('darin', { pos: L.points.tree.clone().add(v(-0.6, 0, -0.9)), name: 'Darin' }); face(darin, v(5, 0, 9));
  ui.quest('O Vale das Flores Sangrentas', '');
  D.cine(true);
  D.shot({ pos: v(-9, 5, -9), look: v(0, 1, 0), pos2: v(-4, 2.4, -6), look2: P.headPos(), dur: 7, blend: 0.0001, fov: 50 });
  await D.fade(0, 2.5); await D.wait(5);
  D.shot(closeup(P, { dur: 8 }));
  await D.say([
    { who: 'kiana', text: 'Dia oito. As flores têm um cheiro doce e ferroso...' },
    { who: 'kiana', text: 'O mesmo cheiro que impregnava as minhas roupas quando acordei naquela taverna.' },
    { who: 'amnon', text: 'Se eu morrer aqui, fico devendo dez pratas pro Darin no outro mundo. Inaceitável.', fn: () => D.shot(closeup(amnon, { dur: 6, dist: 1.6, h: -0.6 })) },
    { who: 'darin', text: 'Kiana... vem cá. Olha essa casca.' },
  ]);
  D.objective(null, 'Examine a árvore com Darin', L.points.tree);
  // o loop espacial
  let loops = 0;
  G.onFrame = () => {
    const d = Math.hypot(P.pos.x, P.pos.z);
    if (d > 20.5 && !G.cine) {
      P.pos.x = -P.pos.x * 0.92; P.pos.z = -P.pos.z * 0.92; G.cam.pivot.copy(P.pos).setY(1.5);
      G.post.flash = 0.35; Audio.sfx('whoosh', { vol: 0.5 });
      loops++; ui.toast(loops < 2 ? '...as mesmas árvores.' : 'O vale te devolve ao mesmo lugar.', '#c0a0b0', 2);
    }
  };
  await D.interact(darin.pos, 2.4, 'Examinar a árvore');
  G.onFrame = null;
  D.cine(true);
  face(darin, v(5, 0, 9));
  D.shot({ pos: v(2.6, 1.8, 6.2), look: v(5, 1.6, 9), dur: 8, fov: 42 });
  darin.anim.play('point');
  await D.say([{ who: 'darin', text: 'Tem alguma coisa aqui. Debaixo da madeira...' }], { keepCine: true });
  Audio.sfx('magic', { pitch: -5 }); Audio.sfx('reveal', { vol: 0.5 });
  G.fx.custom(2, (it) => { L.runeBand.material.opacity = Math.min(1, it.t / 1.5); }, () => { L.runeBand.material.opacity = 1; });
  G.fx.burst('magic', v(5, 1.6, 9), { n: 40, color: '#60b0ff', color2: '#ffffff' });
  await D.wait(1.5);
  await D.say([
    { who: 'darin', text: 'Runas. Escondidas na própria árvore. Despertaram quando eu toquei.' },
    { who: 'amnon', text: 'Ótimo. Alguém aqui lê árvore?' },
    { who: 'near', text: '...Tem alguém atrás de você, Kiana.', fn: () => D.shot(closeup(near, { dur: 4 })) },
  ], { keepCine: true });
  // Calista surge e desarma Kiana
  const cal = new Npc('calista', { pos: P.pos.clone().addScaledVector(fwd(P.yaw), -1.6), rigOpts: { hood: true }, name: 'Encapuzada' });
  face(cal, P); face(P, cal);
  G.fx.burst('smoke', cal.pos, { n: 15, r: 0.6 });
  D.shot(ots(P, cal, { dur: 5, fov: 40, blend: 0.3 }));
  P.anim.play('atk1');
  await D.wait(0.15);
  cal.anim.play('claw'); Audio.sfx('parry'); G.cam.shake(0.3);
  P.rig.weapon.visible = false;
  const flying = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.35, 0.06), glowMat('#9fe0ff', 1.5)); flying.position.copy(P.chestPos()); G.scene.add(flying);
  const land = P.pos.clone().addScaledVector(fwd(P.yaw), 3).setY(0.15);
  G.fx.custom(0.7, (it) => { const f = it.t / 0.7; flying.position.lerpVectors(P.chestPos(), land, f); flying.position.y += Math.sin(f * Math.PI) * 1.5; flying.rotation.z += 0.5; });
  await D.wait(0.8);
  await D.say([
    { who: 'calista', text: 'Lenta demais, pequena.' },
    { who: 'kiana', text: '...Calista?!', fn: () => D.shot(closeup(P, { dur: 4 })) },
    { who: 'calista', text: 'Oito dias andando em círculos. O Viktor teria vergonha de vocês.', fn: () => D.shot(closeup(cal, { dur: 10, dist: 1.4 })) },
    { who: 'calista', text: 'Eu sei ler runas. Não tanto quanto o Viktor, claro.' },
    { who: 'calista', text: 'Isto é uma *barreira do infinito*. A criatura que mantém este loop vive do outro lado. Há uns vinte anos.' },
    { who: 'kiana', text: 'Então a gente atravessa.' },
    { who: 'calista', text: 'Fiquem juntos. E não morram. Eu não vou explicar pro Viktor que perdi os filhotes dele.' },
  ], { keepCine: true });
  G.scene.remove(flying); P.rig.weapon.visible = true;
  D.shot({ pos: v(1.2, 2.2, 3.2), look: v(5, 1.6, 9), dur: 5, fov: 50 });
  Audio.sfx('portal');
  G.fx.custom(3, () => { G.fx.burst('magic', v(5 + rnd(-1, 1), rnd(0.5, 3), 9 + rnd(-1, 1)), { n: 3, color: '#60b0ff', color2: '#ffffff', speed: 2 }); });
  await D.wait(2);
  G.post.flash = 1;
  await D.fade(1, 1);
  G.post.flash = 0;
}

async function c2_creature(D, G) {
  await D.fade(1, 0.01);
  const L = await D.load('domain', { player: 'kiana', pos: v(0, 0, -9), yaw: 0, label: 'A BARREIRA DO INFINITO' });
  Audio.music('silence'); Audio.stopLoops(); Audio.loop('wind', true, 0.3);
  const P = G.player;
  const near = new Ally('near', { pos: v(-2, 0, -10), role: 'melee', name: 'Near', ang: 3.6 }); near.downText = 'Ngh—!';
  const amnon = new Ally('amnon', { pos: v(2, 0, -10.5), role: 'ranged', name: 'Amnon', ang: 5.2 });
  const darin = new Ally('darin', { pos: v(-3.5, 0, -8), role: 'melee', name: 'Darin', ang: 0.6, rigOpts: { claws: false } });
  const cal = new Ally('calista', { pos: v(3.5, 0, -8.5), role: 'ranged', name: 'Calista', ang: 2.2, rigOpts: { ponytail: true } });
  const allies = [near, amnon, darin, cal];
  for (const a of allies) a.scripted = true;
  const boss = new Elemental({ pos: v(0, -5, 6), yaw: Math.PI });
  boss.maxHp = boss.hp = Math.round(1700 * diff());
  boss.invulnerable = true;
  ui.quest('O Vale das Flores Sangrentas', 'Derrote a criatura do vale');
  D.cine(true);
  D.shot({ pos: v(0, 1.6, -13), look: v(0, 1.2, 6), dur: 6, blend: 0.0001, fov: 50 });
  await D.fade(0, 2);
  Audio.sfx('splash'); Audio.sfx('roar', { pitch: 0.6 }); G.cam.shake(0.6);
  D.shot(orbit(v(0, 0, 6), 9, 2.2, -2.6, -3.6, 5, 3));
  G.fx.custom(2.5, (it) => { boss.pos.y = -5 + Math.min(1, it.t / 2.2) * 5; G.fx.burst('water', v(rnd(-1.5, 1.5), 0.2, 6 + rnd(-1.5, 1.5)), { n: 3 }); }, () => { boss.pos.y = 0; });
  await D.wait(2.6);
  boss.anim.play('roar');
  await D.say([
    { who: 'calista', text: 'Água, vento e fogo... é uma essência mutável. Cada forma tem um núcleo — mirem no coração!' },
    { who: 'amnon', text: 'Claro. Mirar no coração do monstro de água gigante. Por que eu não pensei nisso.' },
  ], { keepCine: true });
  D.cine(false); G.inCombat = true;
  for (const a of allies) a.scripted = false;
  boss.invulnerable = false;
  ui.boss(boss); Audio.music('boss_elemental', 0.6);
  ui.bark('narr', 'Seus companheiros lutam ao seu lado. A criatura também os ataca.', 4);
  // Near derrubado
  task(D, async () => {
    await D.until(() => boss.hp < boss.maxHp * 0.86 && near.downed <= 0);
    near.knockDown(9); G.fx.burst('water', near.chestPos(), { n: 20 });
    await D.wait(0.4); ui.bark('kiana', 'NEAR!', 2);
  });
  // fases
  D.listen('bossPhase', (e) => {
    if (e.boss !== boss) return;
    if (e.form === 'wind') task(D, async () => {
      ui.bark('calista', 'Deixa o vento comigo!', 3);
      cal.scripted = true; cal.flying = true; cal.anim.play('float'); cal.noCollide = true;
      let shots = 0;
      G.fx.custom(7, (it, dt) => {
        cal.pos.y = Math.min(3.2, cal.pos.y + dt * 3);
        if (it.t < 6.5) cal.pos.y = 3.2 + Math.sin(it.t * 2) * 0.3;
        G.fx.burst('wind', cal.pos.clone().setY(cal.pos.y - 1.5), { n: 1, r: 0.8, h: 1 });
        face(cal, boss);
        if (it.t > shots * 0.35 + 0.6 && it.t < 6 && boss.alive) {
          shots++;
          const s = cal.chestPos(), dir = boss.chestPos().sub(s).normalize();
          Audio.sfx('arrow', { vol: 0.5 });
          spawnProjectile({ kind: 'arrow', pos: s, vel: dir.multiplyScalar(32), team: 'player', dmg: 12, radius: 0.5, life: 1.5, src: cal, glow: true, color: '#ff2030', furyGain: 0, knock: 0,
            trail: (p) => G.fx.burst('magic', p.pos, { n: 1, color: '#ff2030', color2: '#600010', speed: 0.1, size: 0.6 }) });
        }
      }, () => { cal.flying = false; cal.anim.stop(); cal.scripted = false; cal.noCollide = false; });
    });
    if (e.form === 'fire') task(D, async () => {
      boss.minHp = Math.round(boss.maxHp * 0.05);
      darin.rig.claws.forEach(c => c.visible = true);
      darin.extra = () => { if (Math.random() < 0.3) G.fx.burst('magic', darin.chestPos(), { n: 1, color: '#40ffa0', color2: '#10a050', speed: 0.5 }); };
      ui.bark('darin', '*INSTINTO DE CAÇA!*', 3); Audio.sfx('roar', { pitch: 1.6, vol: 0.5 });
      G.fx.ring(darin.pos, { color: '#40ffa0', r1: 4, life: 0.6 });
      await D.wait(3.5); ui.bark('amnon', 'Eu odeio fogo. Eu odeio muito fogo.', 3);
    });
  });
  // QTE — Amnon segura o núcleo
  while (true) {
    await D.until(() => boss.minHp && boss.hp <= boss.minHp + 1 && !boss.invulnerable);
    boss.invulnerable = true; boss.busy = true; boss.clearPending(); boss.vel.set(0, 0, 0); boss.anim.play('roar', { speed: 0.5 });
    amnon.scripted = true; amnon.downed = 0; amnon.untargetable = false; amnon.anim.stop();
    amnon.pos.copy(boss.pos).addScaledVector(fwd(boss.yaw), 1.7); face(amnon, boss); amnon.anim.play('grab');
    Audio.sfx('fire'); G.cam.shake(0.5);
    D.shot({ pos: amnon.pos.clone().add(v(1.8, 1.6, 0)).addScaledVector(fwd(amnon.yaw), -1.2), look: boss.chestPos(), dur: 3, fov: 40, cut: true });
    ui.bark('amnon', 'AGORA! EU SEGURO ESSA COISA!', 3);
    G.slow = { t: 99, scale: 0.18 };
    const burn = G.fx.custom(99, () => { G.fx.burst('fire', amnon.rig.handL.getWorldPosition(new V3()), { n: 2, size: 0.8, r: 0.05 }); });
    await D.wait(0.25);
    G.cam.release(0.4);
    ui.bark('calista', 'Kiana! O NÚCLEO!', 3);
    ui.prompt('<kbd>E</kbd>GOLPEIE O NÚCLEO');
    P.lockTarget = boss;
    const t0 = G.realTime;
    await D.until(() => G.input.pressed('KeyE') || G.realTime - t0 > 4.5);
    ui.prompt(null);
    const hit = G.realTime - t0 <= 4.5;
    G.slow = { t: 0, scale: 1 };
    if (hit) {
      burn.kill = true;
      D.cine(true);
      P.pos.copy(boss.pos).addScaledVector(fwd(boss.yaw), 2.2).add(v(0.8, 0, 0)); face(P, boss);
      G.fx.burst('shadow', P.pos.clone().setY(1), { n: 20, r: 0.4 });
      D.shot({ pos: boss.pos.clone().add(v(4, 2.5, 0)).addScaledVector(fwd(boss.yaw), 3), look: boss.chestPos(), dur: 4, fov: 45, cut: true });
      P.anim.play('atk3', { speed: 0.7 }); Audio.sfx('blink');
      G.slow = { t: 2, scale: 0.3 };
      await D.wait(0.35);
      Audio.sfx('shatter'); Audio.sfx('explosion'); G.cam.shake(1); G.post.flash = 0.8;
      G.fx.sphere(boss.chestPos(), { color: '#ffd080', r1: 6, life: 0.8, intensity: 3 });
      G.fx.burst('fire', boss.chestPos(), { n: 80, r: 1.5, size: 1.6 });
      G.fx.burst('spark', boss.chestPos(), { n: 60 });
      boss.rig.core.visible = false;
      break;
    } else {
      burn.kill = true;
      ui.toast('Amnon foi arremessado!', '#ff9060', 2);
      amnon.scripted = false; amnon.knockDown(5); amnon.knock.addScaledVector(fwd(boss.yaw), 10);
      boss.hp = Math.min(boss.maxHp, boss.hp + boss.maxHp * 0.08);
      boss.invulnerable = false; boss.busy = false; boss.ai = 'chase';
      await D.wait(6);
    }
  }
  // vitória
  ui.boss(null); Audio.music('silence', 1);
  boss.minHp = undefined; boss.invulnerable = false; boss.hp = 0;
  boss.die(P);
  G.fx.custom(1.6, (it) => { G.fx.burst('smoke', boss.pos.clone().setY(rnd(0.5, 4)), { n: 3, r: 1.2, color: '#3a2a2a' }); boss.root.scale.setScalar(Math.max(0.01, 1 - it.t / 1.5)); }, () => { boss.root.visible = false; });
  await D.wait(2.2);
  for (const a of allies) { a.scripted = true; a.downed = 0; a.anim.stop(); a.untargetable = false; }
  amnon.anim.play('kneel');
  const away = amnon.pos.clone().sub(boss.pos).setY(0).normalize();
  face(amnon, amnon.pos.clone().add(away));
  D.shot({ pos: amnon.pos.clone().addScaledVector(away, 2.4).add(v(0.6, 1.3, 0)), look: amnon.headPos(-0.4), dur: 10, fov: 42 });
  Audio.music('valley', 2);
  await D.say([
    { who: 'amnon', text: 'Ai. Ai, ai, ai. Alguém tem gelo?' },
    { who: 'darin', text: 'Só o Viktor.' },
    { who: 'calista', text: 'Então vamos buscá-lo. Hikari fica a dois dias de carroça.' },
    { who: 'near', text: '...Bom trabalho, Amnon.' },
    { who: 'amnon', text: 'Anota isso, Darin. O Near me elogiou. Isso vale pelo menos as dez pratas.' },
  ], { keepCine: true });
  await D.fade(1, 2);
}

async function c2_road(D, G) {
  ui.showHUD(false);
  Audio.music('vardun', 2);
  await D.card({ c1: 'NA CARROÇA, A CAMINHO DE HIKARI', c2: 'A Lenda de Kynare e o Corvo Celeste', c3: 'Kynare era um homem consumido pela própria fome de poder.\nO Corvo Celeste lhe ofereceu força, domínio e glória eterna\nem troca de uma única coisa: seguir o caminho que o Corvo apontasse.', dur: 9 });
  await D.card({ c3: 'Kynare aceitou. Aceitou rápido demais.\nCorrentes surgiram sob seus pés — finas como fios de cabelo,\nbrilhantes como estrelas distantes — e ele nem percebeu.', dur: 8 });
  await D.card({ c3: '“Nada é mais fácil de controlar\ndo que alguém que acha que está no comando.”', c4: '— CALISTA VANSHEE', dur: 6 });
  await D.card({ c3: '“Viktor carrega algo singular... mas essa mesma dádiva é a fresta na armadura.\nA força dele é, também, a sua maldição.”', c4: '— CALISTA VANSHEE', dur: 7 });
  await D.card({ c1: 'HIKARI', c3: 'Uma cidade murada, dominada por um castelo hipnótico.\nUma estátua de balança quebrada chamada Justiça Desequilibrada.\nUm Lorde Draconato adorado pelo povo — Krauser.', dur: 8 });
  await D.card({ c3: 'Uma anciã chamada Matilde, uma pulseira de ouro velho.\nUm livro chamado “O Inventor do Tempo”.\nUm encapuzado de sorriso impossível, uma caverna de tieflings acorrentados.\nE Krauser, sozinho no centro do símbolo, absorvendo a poeira negra pela pele.', dur: 9 });
  Audio.music('title', 1.5);
  await D.card({ c1: 'O FESTIVAL DE HONRA', c2: 'O Alvorecer da Ausência', c3: 'O gigante ensinou o sol a caminhar,\nMoldou o ferro antes do fogo se apagar.\nErgueu um farol onde o abismo era lar,\nE jurou que a sombra nunca iria nos alcançar.', dur: 11 });
  await D.card({ c3: 'A luz que se foi ainda queima no olhar,\nUm vazio dourado que insiste em brilhar.\nSe o forte sucumbe ao peso de lutar,\nEu serei o eco que o silêncio vai quebrar.', c4: '— KIANA', dur: 11 });
  Audio.music('silence', 0.5); Audio.sfx('gong');
  await D.card({ c3: 'A praça permaneceu em silêncio absoluto por três segundos eternos\nantes de explodir em aplausos.\n\nKiana procurou Calista na plateia.\nO lugar dela estava vazio.', dur: 8 });
  Audio.sfx('roar', { pitch: 0.5 });
  await D.card({ c3: 'Minutos depois, as sombras atacaram.', dur: 4 });
}

// =====================================================================
//  CAPÍTULO III — OBLITUS LIMBO
// =====================================================================
function setupThrone(L) {
  const kr = new Krauser({ pos: v(0, 0, 7.5), yaw: Math.PI });
  kr.maxHp = kr.hp = Math.round(1900 * diff());
  return kr;
}
async function c3_throne(D, G) {
  await D.fade(1, 0.01);
  await D.card({ c1: 'CAPÍTULO III', c2: 'Oblitus Limbo', c3: 'O Castelo de Hikari', dur: 5 });
  const L = await D.load('throne', { player: 'kiana', pos: v(0, 0, -9), yaw: 0, label: 'O SALÃO DO TRONO' });
  Audio.music('throne', 2); Audio.stopLoops(); Audio.loop('rumble', true, 0.3);
  const P = G.player;
  const kr = setupThrone(L);
  kr.tentaclesOn = false;
  const vik = new Npc('viktor', { pos: L.points.viktor, yaw: Math.PI, name: 'Viktor' }); vik.anim.play('hang');
  tintActor(vik, 0.45);
  const veins = G.fx.custom(9999, () => { if (Math.random() < 0.4) G.fx.burst('shadow', vik.chestPos().add(v(rnd(-0.3, 0.3), rnd(-0.5, 0.5), rnd(-0.3, 0.3))), { n: 1, r: 0.1, size: 0.5 }); });
  const cal = new Npc('calista', { pos: L.points.calista, yaw: 2.5, name: 'Calista', rigOpts: { ponytail: true } }); cal.anim.play('lie');
  ui.quest('Oblitus Limbo', '');
  D.cine(true);
  D.shot({ pos: v(0, 1.6, -12), look: v(0, 2.5, 8), pos2: v(0, 1.8, -7), dur: 7, blend: 0.0001, fov: 50 });
  await D.fade(0, 2);
  await D.wait(3);
  D.shot(closeup(kr, { dur: 12, dist: 2.4, side: 0.5, fov: 38 }));
  await D.say([
    { who: 'krauser', text: 'Bem-vinda, pequena loba. Você chegou bem a tempo do último ato.' },
    { who: 'kiana', text: 'Krauser... foi você. O tempo todo.', fn: () => D.shot(ots(P, kr, { dur: 20 })) },
    { who: 'krauser', text: 'Dez anos usando a máscara de Lorde heroico. O encapuzado da caverna? Um peão. Uma distração encenada para ganhar a confiança de vocês.' },
    { who: 'krauser', text: 'Eu sou o verdadeiro *Quinto Presságio*.', fn: () => { Audio.sfx('reveal'); G.cam.shake(0.3); } },
    { who: 'kiana', text: 'Viktor...!', fn: () => D.shot({ pos: vik.pos.clone().add(v(1.5, 1.6, -2.2)), look: vik.headPos(-0.2), dur: 6, fov: 40 }) },
  ], { keepCine: true });
  // Calista
  cal.anim.stop(); cal.pos.copy(vik.pos).add(v(1.1, 0, -0.6)); face(cal, vik); cal.anim.play('kneel');
  D.shot({ pos: vik.pos.clone().add(v(2.6, 1.2, -1.6)), look: vik.pos.clone().lerp(cal.pos, 0.5).setY(1.1), dur: 20, fov: 38 });
  Audio.music('flashback', 2);
  await D.say([
    { who: 'calista', text: 'Kiana... fica longe dele...' },
    { who: 'calista', text: 'Viktor. Eu... nunca te disse.' },
    { who: 'calista', text: 'Eu nunca soube caminhar sem ter você como norte.' },
    { who: 'calista', text: 'Agora, Viktor, por favor... *salve todo mundo. Salve a Kiana.*' },
  ], { keepCine: true });
  // o beijo — a corrupção migra
  Audio.sfx('portal', { vol: 0.5 });
  G.fx.custom(3, (it) => {
    const a = vik.chestPos(), b = cal.chestPos();
    for (let k = 0; k < 4; k++) { const p = a.clone().lerp(b, Math.random()); G.fx.burst('shadow', p, { n: 1, r: 0.05, size: 0.6 }); }
    tintActor(vik, 0.45 + 0.55 * Math.min(1, it.t / 3)); tintActor(cal, 1 - 0.55 * Math.min(1, it.t / 3));
  }, () => { restoreTint(vik); veins.kill = true; });
  await D.wait(3.3);
  cal.anim.play('lie'); Audio.sfx('heartbeat'); Audio.sfx('heartbeat', { delay: 0.9, vol: 0.5 });
  await D.wait(1.5);
  D.shot(closeup(P, { dur: 4, dist: 1.2, fov: 34 }));
  G.post.flash = 0.2;
  await D.say([{ who: 'kiana', text: '*CALISTA!*', fn: () => { G.cam.shake(0.5); Audio.sfx('fury'); } }], { keepCine: true });
  Audio.music('silence', 0.5);
  D.shot(ots(P, kr, { dur: 20 }));
  await D.say([
    { who: 'krauser', text: 'Dez anos acumulando poder para ser desafiado por uma arqueira moribunda e uma criança.' },
    { who: 'krauser', text: 'Você luta com o coração, Kiana, e é por isso que vai perder! Corações pesados são lentos! Corações partidos são fáceis de esmagar!' },
    { who: 'kiana', text: 'O meu coração não está partido, Krauser.', fn: () => D.shot(closeup(P, { dur: 8, dist: 1.3 })) },
    { who: 'kiana', text: 'Ele arde. *Como um acorde sustentado até doer.*', fn: () => { G.flags.apagao = true; Audio.sfx('heartbeat', { vol: 1.5 }); } },
  ], { keepCine: true });
  // o soco
  P.pos.copy(kr.pos).addScaledVector(fwd(kr.yaw), 1.4); face(P, kr);
  G.fx.burst('shadow', P.pos.clone().setY(1), { n: 30, r: 0.4 });
  D.shot({ pos: kr.pos.clone().add(v(3, 1.4, -1.5)), look: kr.chestPos(), dur: 3, fov: 40, cut: true });
  P.anim.play('punch', { speed: 0.7 }); Audio.sfx('blink');
  await D.wait(0.2);
  Audio.sfx('crit'); G.cam.shake(0.8); G.post.flash = 0.4;
  kr.anim.play('knock'); kr.knock.copy(fwd(P.yaw).multiplyScalar(14));
  G.fx.burst('blood', kr.chestPos(), { n: 20 }); G.fx.burst('spark', kr.chestPos(), { n: 25 });
  await D.wait(1.3);
  G.flags.apagao = false;
  ui.toast('Krauser sangrou. Pela primeira vez.', '#e8dcc0', 2.5);
  await D.wait(0.8);
  D.shot(closeup(kr, { dur: 6, dist: 2.6, fov: 42 }));
  kr.anim.play('roar'); Audio.sfx('roar', { pitch: 0.8 }); Audio.sfx('tentacle');
  kr.tentaclesOn = true; G.fx.burst('shadow', kr.chestPos(), { n: 60, r: 0.8, speed: 3, size: 1.4 }); G.cam.shake(0.6);
  await D.say([{ who: 'krauser', text: 'Sua insolente... *TENTÁCULOS DO ABISMO!*' }], { keepCine: true });
  D.cine(false); G.inCombat = true;
  ui.boss(kr); Audio.music('boss_krauser', 0.5); Audio.loop('rumble', false);
  D.objective(null, 'Derrote Lorde Krauser', null);
  kr.minHp = Math.round(kr.maxHp * 0.6);
  D.listen('summonShadows', ({ n }) => {
    for (let i = 0; i < n; i++) {
      const a = rnd(0, Math.PI * 2), p = v(Math.cos(a) * 8, 0, Math.sin(a) * 8);
      G.fx.burst('shadow', p.clone().setY(0.6), { n: 25, r: 0.6, speed: 2 });
      const s = new Thug({ pos: p, shadow: true, hp: 30, dmg: 8, speed: 4, seed: i });
      face(s, P);
    }
    ui.bark('krauser', 'Levantem-se, filhos da sombra.', 2.5);
  });
  // ---- limiar 1: o cristal ----
  await D.until(() => kr.phaseLock && kr.phase === 1);
  kr.clearPending(); kr.busy = true; kr.invulnerable = true;
  for (const a of G.actors) if (a.team === 'enemy' && a !== kr) a.die && a.die();
  D.cine(true);
  P.pos.copy(kr.pos).addScaledVector(fwd(kr.yaw), 4); face(P, kr); face(kr, P);
  D.shot(closeup(kr, { dur: 6, dist: 2.2, fov: 38, blend: 0.5 }));
  kr.anim.play('point');
  await D.say([{ who: 'krauser', text: 'Chega de brincadeira. Vamos ver o que você esconde dentro dessa cabeça, aberração.' }], { keepCine: true });
  Audio.sfx('reveal'); Audio.sfx('portal', { vol: 0.4 });
  G.fx.beam(kr.rig.crystal.getWorldPosition(new V3()), P.headPos(), { color: '#ff1030', width: 0.08, life: 2.5 });
  G.fx.custom(2.5, () => G.fx.beam(kr.rig.crystal.getWorldPosition(new V3()), P.headPos(), { color: '#ff1030', width: 0.05, life: 0.1 }));
  P.anim.play('hit'); G.cam.shake(0.5); G.post.flash = 0.6;
  await D.wait(1.5);
  // ---- FLASHBACK: o orfanato ----
  G.post.desatTarget = 1; Audio.music('flashback', 1.5);
  await D.card({ cls: 'memory', c1: 'O ORFANATO', c3: 'Paredes cinzas. Janelas altas.\nUm sino de jantar metálico e impessoal.', dur: 6 });
  await D.card({ cls: 'memory', c1: 'TIA LANIS', c3: '“Não aperte tanto as cordas, Kiana.\nTrate o instrumento como um amigo, não como uma arma.”', dur: 7 });
  await D.card({ cls: 'memory', c1: 'TYLER', c3: '“Aqui é um lugar para gente normal, Kiana.\nNão é um lugar para monstros ou aberrações como você.”\n\nO ukulele partido contra o rosto. O nariz quebrado.\nE a mentira para proteger quem a machucou.', dur: 9 });
  await D.card({ cls: 'memory', c1: 'EMMA', c3: '“Eu gosto de você. E a Tia Lanis também.”', dur: 5 });
  Audio.sfx('heartbeat', { vol: 1.5 });
  await D.card({ cls: 'memory', c3: 'E então, numa noite de tinta negra e fogo...\num garoto magro, de olhos como globos de escuridão absoluta.', dur: 7 });
  await D.card({ cls: 'memory', c1: 'GYOTTO, O SEXTO PRESSÁGIO', c3: '“Todos dormiram... menos você.\nSerá porque você não é humana?”', dur: 7 });
  await D.card({ cls: 'memory', c1: 'TIA LANIS', c3: '“Enquanto eles viam uma praga, eu sempre acreditei no contrário:\nque você é a cura de algo muito maior.\nVocê não nasceu para ser odiada,\nmas para ser a resposta que este mundo ainda não sabe que precisa.”', dur: 10 });
  await D.card({ cls: 'memory', c3: 'Um homem de branco e azul, chegando tarde demais.\nUma estaca de gelo cristalino.\nMãos cheias de cicatrizes erguendo-a do chão.\n\nViktor.', dur: 9 });
  G.post.desatTarget = 0;
  D.shot(closeup(P, { dur: 10, dist: 1.4, fov: 36, blend: 0.0001 }));
  Audio.music('silence', 0.3);
  await D.say([
    { who: 'kiana', text: 'Eu lembro.' },
    { who: 'kiana', text: 'Eu lembro de *TUDO*.', fn: () => { G.cam.shake(0.4); Audio.sfx('reveal'); } },
    { who: 'krauser', text: 'Impossível... o cristal deveria te quebrar!', fn: () => D.shot(closeup(kr, { dur: 5 })) },
    { who: 'kiana', text: 'Posso não ter despertado meu sigilo ainda, Krauser...', fn: () => D.shot(closeup(P, { dur: 8, dist: 1.6 })) },
    { who: 'kiana', text: '...mas tenho habilidades que só eu sei usar.' },
  ], { keepCine: true });
  // arranca o colar
  P.pos.copy(kr.pos).addScaledVector(fwd(kr.yaw), 1.2); face(P, kr);
  P.anim.play('claw'); Audio.sfx('blink'); Audio.sfx('shatter');
  kr.rig.crystal.visible = false;
  ui.toast('— AGORA ESTÁ COMIGO! —', '#ff4060', 2, true);
  G.post.flash = 1;
  await D.wait(0.8);
  // ---- dentro da mente de Krauser ----
  G.post.desatTarget = 0.7;
  Audio.music('limbo', 1);
  await D.card({ cls: 'memory', c1: 'DENTRO DA MENTE DE KRAUSER', c3: '“Eu não sou pai de um monstro... de um dragão!”\nUma mulher chamada Layla, estrangulada diante do próprio filho.\nUm menino que incinerou o pai vivo.\nCriado no ódio. Batizado no fogo.', dur: 10 });
  await D.card({ cls: 'memory', c3: 'Um adulto que encontrou numa floresta uma criança rejeitada,\ncom poderes de tinta negra — e a corrompeu,\nreproduzindo sem hesitar o ciclo que o formara.', dur: 8 });
  await D.card({ cls: 'memory', c1: 'O CONSELHO, SOB A LUA QUE SORRI', c3: '“O nome dele é Viktor Vanshee!\nO mesmo homem que tirou a vida de Gauss.”', c4: '— O MASCARADO', dur: 8 });
  await D.card({ cls: 'memory', c3: '“Você vai para Hikari, Largato. Mate o Lorde, tome o lugar dele...\ne apodreça lá.”', c4: '— O MASCARADO', dur: 7 });
  G.post.desatTarget = 0; G.post.flash = 0.8;
  D.shot(closeup(kr, { dur: 4, dist: 1.8, blend: 0.0001 }));
  await D.say([{ who: 'krauser', text: '*SAI DA MINHA CABEÇA!*', fn: () => { G.cam.shake(1); Audio.sfx('roar'); } }], { keepCine: true });
  // ---- fase 2 ----
  G.flags.harmonic = true; P.fury = 100; ui.updateFuryIcon(P);
  kr.phase = 2; kr.phaseLock = false; kr.busy = false; kr.invulnerable = false; kr.ai = 'chase';
  kr.minHp = Math.round(kr.maxHp * 0.12);
  kr.cdBase = 1.1; kr.moveSpeed *= 1.15;
  D.cine(false);
  Audio.music('boss_krauser', 0.4);
  ui.toast('MANIFESTAÇÃO HARMÔNICA — [F]', '#ffe08a', 3, true);
  ui.bark('narr', 'A Manifestação Harmônica consome toda a sua energia. Cada acorde deixa um veneno estrutural no inimigo.', 6);
  await D.until(() => kr.phaseLock && kr.phase === 2);
  // ---- Kiana cai ----
  kr.clearPending(); kr.busy = true; kr.invulnerable = true;
  for (const a of G.actors) if (a.team === 'enemy' && a !== kr) a.die && a.die();
  if (P.ult) P.endUlt();
  D.cine(true);
  P.pos.copy(kr.pos).addScaledVector(fwd(kr.yaw), 2.2); face(P, kr); face(kr, P);
  D.shot({ pos: kr.pos.clone().add(v(2.8, 1.5, 0.5)), look: P.chestPos().lerp(kr.chestPos(), 0.5), dur: 3, fov: 40, cut: true });
  P.anim.play('guard');
  await D.say([{ who: 'kiana', text: 'Meus reflexos... estão lentos... como se eu estivesse submersa em breu...' }], { keepCine: true });
  kr.anim.play('claw', { speed: 0.6 });
  await D.wait(0.5);
  G.slow = { t: 1.5, scale: 0.2 }; Audio.sfx('crit'); G.cam.shake(1); G.post.flash = 0.6;
  G.fx.burst('blood', P.chestPos(), { n: 40 });
  P.anim.play('death');
  await D.wait(1.2);
  Audio.music('silence', 0.2);
  await D.fade(1, 1.5);
  await D.card({ cls: 'memory', c3: 'A dor veio antes do som.\nO chão de mármore estava frio.\nE do outro lado do salão, algo se levantou.', dur: 7 });
}

async function c3_viktor(D, G) {
  await D.fade(1, 0.01);
  const L = await D.load('throne', { player: 'viktor', pos: v(-3.2, 0, 8.4), yaw: Math.PI * 0.9, label: 'O PILAR DO GELO' });
  Audio.music('silence'); Audio.stopLoops();
  const P = G.player;
  const kr = setupThrone(L);
  kr.pos.set(0, 0, 0); kr.phase = 3; kr.cdBase = 1.0; kr.moveSpeed *= 1.2;
  kr.maxHp = kr.hp = Math.round(1100 * diff());
  kr.rig.crystal.visible = false;
  const kiana = new Npc('kiana', { pos: v(0.5, 0, 2.5), yaw: 0.5, name: 'Kiana' }); kiana.anim.play('lie', { instant: true });
  const cal = new Npc('calista', { pos: v(-2.2, 0, 9.8), yaw: 2.5, name: 'Calista', rigOpts: { ponytail: true } }); cal.anim.play('lie', { instant: true });
  face(kr, P);
  for (const ch of L.chains) ch.visible = false;
  D.cine(true);
  P.anim.play('kneel', { instant: true });
  D.shot({ pos: P.pos.clone().add(v(1.2, 0.9, -1.8)), look: P.headPos(-0.5), dur: 8, blend: 0.0001, fov: 38 });
  await D.fade(0, 2);
  Audio.music('flashback', 2);
  await D.say([
    { who: 'viktor', text: '...Calista.' },
    { who: 'viktor', text: 'Kiana.' },
  ], { keepCine: true });
  P.anim.stop();
  Audio.sfx('shatter'); Audio.sfx('reveal'); G.cam.shake(0.8); G.post.flash = 0.6;
  G.fx.ring(P.pos, { color: '#9fe0ff', r1: 14, life: 1.2, intensity: 3 });
  for (let k = 0; k < 24; k++) { const a = k / 24 * Math.PI * 2; after(k * 0.02, () => G.fx.iceSpike(P.pos.clone().add(v(Math.cos(a) * rnd(1.5, 4), 0, Math.sin(a) * rnd(1.5, 4))), { h: rnd(1, 2.6), life: 3 })); }
  D.shot({ pos: P.pos.clone().add(v(0, 1.0, -3.5)), look: P.headPos(), pos2: P.pos.clone().add(v(0, 1.4, -2.6)), dur: 6, fov: 40 });
  Audio.music('boss_krauser', 1); Audio.flags.viktor = true;
  await D.wait(1.2);
  await D.say([
    { who: 'viktor', text: 'Você se acha forte porque esmaga os fracos.' },
    { who: 'viktor', text: 'Mas diante de quem realmente conhece o desespero, você não passa de um ruído incômodo.' },
    { who: 'krauser', text: 'O picolé acordou! *Armadura Arcana: Frio Absoluto!*', fn: () => { D.shot(closeup(kr, { dur: 6, dist: 2.4 })); kr.setArmor(true); Audio.sfx('fire'); G.fx.burst('fire', kr.pos, { n: 60, color: '#e0f0ff', color2: '#1040ff', size: 1.5, up: 2, r: 0.6 }); } },
    { who: 'krauser', text: 'Você não pode congelar o que já é o próprio zero!' },
  ], { keepCine: true });
  D.cine(false); G.inCombat = true;
  ui.boss(kr); kr.title = 'Frio Absoluto'; ui.boss(kr);
  D.objective('Oblitus Limbo', 'Derrote Krauser — o gelo não basta', null);
  ui.bark('narr', 'O Frio Absoluto anula o gelo. Encha a CHAMA e libere o PUNHO FLAMEJANTE [F] para quebrar a armadura.', 7);
  P.fury = 40;
  kr.minHp = 1;
  let finale = false;
  D.listen('punho', (t) => { if (t === kr && kr.hp <= kr.maxHp * 0.32) finale = true; else ui.bark('krauser', 'Arg...! Essa chama... de onde?!', 2.5); });
  task(D, async () => {
    await D.until(() => kr.hp <= kr.maxHp * 0.32);
    ui.toast('ELE ESTÁ VULNERÁVEL', '#fff0b0', 2.5, true);
    ui.bark('viktor', 'Acabou, Krauser.', 3);
    P.fury = 100;
  });
  await D.until(() => finale);
  // ---- final ----
  kr.clearPending(); kr.busy = true; kr.invulnerable = true;
  for (const a of G.actors) if (a.team === 'enemy' && a !== kr) a.die && a.die();
  await D.wait(0.6);
  D.cine(true); ui.boss(null); kr.setArmor(false);
  kr.anim.play('kneel'); kr.tentaclesOn = false;
  for (const t of kr.tentacles) t.setVisible(false);
  face(P, kr);
  const melt = G.fx.custom(9999, () => {
    if (Math.random() < 0.8) G.fx.burst('shadow', kr.pos.clone().add(v(rnd(-0.4, 0.4), rnd(0.3, 1.8), rnd(-0.4, 0.4))), { n: 1, r: 0.1, size: 0.7, color: '#100810' });
    if (Math.random() < 0.3) G.fx.burst('magic', kr.chestPos(), { n: 1, color: '#80f0ff', color2: '#ffd070', speed: 0.8 });
  });
  D.shot(closeup(kr, { dur: 10, dist: 1.8, fov: 38, h: -0.4 }));
  Audio.music('silence', 1);
  await D.say([
    { who: 'krauser', text: 'O que... o que vocês fizeram comigo...? Eu estou... derretendo... por dentro...' },
    { who: 'krauser', text: '...A música...', fn: () => { Audio.sfx('chord', { notes: [57, 64, 69, 72] }); } },
    { who: 'viktor', text: 'Eu não fiz nada.', fn: () => D.shot(closeup(P, { dur: 8, dist: 1.5 })) },
    { who: 'viktor', text: '*Foi a Kiana quem te derrotou.*' },
    { who: 'krauser', text: 'Hah... hahaha... então... se eu cair...', fn: () => D.shot(closeup(kr, { dur: 6, dist: 2.2 })) },
    { who: 'krauser', text: '...VOCÊS CAEM COMIGO!' },
  ], { keepCine: true });
  // o ritual
  Audio.sfx('portal'); Audio.loop('rumble', true, 1);
  kr.anim.play('roar', { speed: 0.4 });
  const portalMat = new THREE.ShaderMaterial({
    uniforms: { uTime: { value: 0 }, uOpen: { value: 0.05 } },
    vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `uniform float uTime, uOpen; varying vec2 vUv;
      void main(){
        vec2 p = vUv * 2.0 - 1.0; float r = length(p); float a = atan(p.y, p.x);
        float sw = a * 3.0 + r * 14.0 - uTime * 3.0;
        float bands = 0.5 + 0.5 * sin(sw) * sin(sw * 0.5 + uTime);
        float inside = smoothstep(uOpen, uOpen - 0.06, r);
        float rim = exp(-pow((r - uOpen * 0.97) * 16.0, 2.0));
        vec3 col = vec3(0.75, 0.02, 0.08) * bands * (1.0 - r / max(uOpen, 0.001)) * 1.4;
        col *= smoothstep(0.0, 0.45 * uOpen, r);
        col += vec3(2.6, 0.25, 0.45) * rim;
        float alpha = clamp(max(inside, rim), 0.0, 1.0);
        if (alpha < 0.01) discard;
        gl_FragColor = vec4(col, alpha);
      }`,
    transparent: true, depthWrite: false, side: THREE.DoubleSide, toneMapped: false,
  });
  const portal = new THREE.Mesh(new THREE.PlaneGeometry(11, 11), portalMat); portal.position.set(0, 4.2, 0); G.scene.add(portal);
  G.fx.custom(30, (it) => {
    const f = Math.min(1, it.t / 7);
    portalMat.uniforms.uTime.value = it.t; portalMat.uniforms.uOpen.value = 0.05 + f * 0.9;
    portal.lookAt(G.camera.position);
    for (let k = 0; k < 4; k++) { const a = rnd(0, 6.28), r = rnd(4, 12); const p = v(Math.cos(a) * r, rnd(0, 6), Math.sin(a) * r); G.fx.norm.emit(p, portal.position.clone().sub(p).multiplyScalar(0.8), 1.2, 0.3, 0.05, new THREE.Color('#200008'), new THREE.Color('#000000'), 0, 0, 0.9); }
    if (Math.random() < 0.5) G.fx.burst('ember', portal.position.clone().setY(0), { n: 1, r: 6, color: '#ff2040', color2: '#300008' });
    G.cam.shake(0.05 * f);
  }, () => { G.scene.remove(portal); });
  D.shot({ pos: v(6, 2, -9), look: v(0, 3.5, 0), pos2: v(4, 1.6, -7), dur: 16, fov: 48 });
  const chant = ['Sanguis pro limine, anima pro vana...', 'In tenebris aeternis, mundus dissolvitur.', 'Aperi portam limbi, ubi lux moritur...'];
  for (const c of chant) { await D.say([{ who: 'krauser', text: `*${c}*`, fn: () => Audio.sfx('heartbeat', { vol: 1.5 }) }], { keepCine: true }); }
  D.shot(closeup(kr, { dur: 3, dist: 1.4, fov: 32, blend: 0.0001 }));
  await D.say([{ who: 'krauser', text: '*OBLITUS LIMBO!*', fn: () => { G.cam.shake(1); Audio.sfx('explosion'); Audio.sfx('roar', { pitch: 0.4 }); G.post.flash = 1; } }], { keepCine: true });
  melt.kill = true;
  kr.root.visible = false; for (const t of kr.tentacles) t.setVisible(false);
  D.shot({ pos: v(0, 1.2, -10), look: v(0, 4, 0), pos2: v(0, 2.5, -3), dur: 5, fov: 70 });
  // todos são sugados
  for (const a of [P, kiana, cal]) { a.noCollide = true; a.flying = true; }
  G.fx.custom(4, (it, dt) => {
    for (const a of [P, kiana]) { const d = v(0, 4, 0).sub(a.pos); a.pos.addScaledVector(d, dt * (0.3 + it.t * 0.5)); a.root.rotation.z += dt * 3; }
  });
  await D.wait(2.5);
  G.post.flash = 1;
  await D.fade(1, 1.2);
  Audio.stopLoops();
  Audio.flags.viktor = false;
}

async function epilogue(D, G) {
  ui.showHUD(false);
  const L = await D.load('limbo', { label: 'O LIMBO' });
  Audio.music('limbo', 2); Audio.loop('rumble', true, 0.8);
  D.cine(true); ui.showHUD(false);
  G.cam.shot({ pos: v(0, 1.5, -8), look: v(0, 4, 30), pos2: v(0, 2.5, 8), look2: v(0, 5, 34), dur: 25, blend: 0.0001, fov: 50 });
  await D.fade(0, 3);
  await D.card({ cls: 'clear', c3: 'Kiana. Viktor. Near. Amnon. Darin.\nArrastados para dentro do Limbo —\no mesmo lugar onde esta história começou.', dur: 7 });
  L.eye.visible = true; Audio.sfx('reveal');
  await D.say([
    { who: 'presenca', text: '...', fn: () => { Audio.sfx('heartbeat', { vol: 1.5 }); G.cam.shake(0.4); } },
    { who: 'voz', text: 'Krauser foi uma decepção, admito. Mas o encerramento da sua história superou minhas expectativas.' },
    { who: 'voz', text: 'Conheço cada hesitação sua, Vanshee.' },
    { who: 'voz', text: 'Afinal... quem te entenderia melhor do que *o melhor amigo que você julgou ter deixado para trás?*', fn: () => { G.cam.shake(0.6); Audio.sfx('gong'); } },
  ], { keepCine: true });
  await D.fade(1, 3);
  Audio.stopLoops();
  Audio.music('title', 2);
  await D.card({ c2: 'OBLITUS LIMBO', c3: 'Continua em\nOBLITUS LIMBO: Volume II', c4: 'OBRIGADO POR JOGAR A DEMO', dur: 9 });
}

// =====================================================================
export const CHAPTERS = [
  { num: 'PRÓLOGO', name: 'A Presença', desc: 'No coração do Limbo, uma entidade recebe uma notícia.', segments: [prologue] },
  { num: 'CAPÍTULO I', name: 'Um Fogo que Não Pertence a Este Mundo', desc: 'Vardun. A taverna de Darius. Mais de vinte homens.', segments: [c1_vardun, c1_tavern] },
  { num: 'CAPÍTULO II', name: 'O Vale das Flores Sangrentas', desc: 'Oito dias presos num loop. Água, vento e fogo.', segments: [c2_valley, c2_creature, c2_road] },
  { num: 'CAPÍTULO III', name: 'Oblitus Limbo', desc: 'O salão do trono de Hikari. O verdadeiro Quinto Presságio.', segments: [c3_throne, c3_viktor, epilogue] },
];

export const CODEX = [
  { name: 'Kiana', ep: 'A bardo de Vardun · narradora e protagonista', img: 'assets/portraits/kiana.jpg', pos: '55% 20%', text: 'Meia-orc de “beleza improvável”, cabelos brancos como neve recém-assentada e olhos vermelhos que brilham no escuro. Encontrada por Tia Lanis na orla de uma floresta proibida, única sobrevivente do ataque de Gyotto ao orfanato. Carrega o ukulele às costas e a adaga de Kael à cintura. Seu Sigilo da Alma permanece um mistério.' },
  { name: 'Near Shade', ep: 'O elfo da máscara', img: 'assets/portraits/near.jpg', pos: '50% 25%', text: 'Elfo ladino de passos fantasmagóricos e olhos impossíveis de decifrar. Aprendeu a ler aos treze anos. Três anos de amizade com Kiana — e algo que cresce em silêncio.' },
  { name: 'Amnon Akmenos', ep: 'O tiefling exilado', img: 'assets/portraits/amnon.jpg', pos: '45% 30%', text: 'Expulso da própria linhagem, acusado de roubar a Relíquia de Nostradamus. Alegria “meio quebrada”. Segurou com as mãos nuas o núcleo em chamas da criatura do Vale.' },
  { name: 'Darin Leafheart', ep: 'O druida dos lobos', img: 'assets/portraits/darin.jpg', pos: '50% 15%', text: 'Sigilo Autoformado: Instinto de Caça — aura verde-esmeralda, manoplas translúcidas em forma de garras de lobo. Certa vez virou uma porca para atrair um rebanho fugido.' },
  { name: 'Viktor Vanshee', ep: 'O Pilar do Gelo · “o picolé”', img: 'assets/portraits/viktor.jpg', pos: '50% 10%', text: 'Meio-elfo nascido com o sigilo desperto — Herança Celestial: Manipulação do Gelo. Matou Gyotto, resgatou Kiana. Segundo o Mascarado, também tirou a vida de Gauss. No fim, o Mestre do Gelo manipulou o sol.' },
  { name: 'Calista Vanshee', ep: 'A arqueira de EmberFall', img: 'assets/portraits/calista.jpg', pos: '42% 18%', text: 'Esposa de Viktor. Manipulação de Fios de Sangue canalizada pelo arco. Leu as runas do Vale, desconfiou de Krauser primeiro — e deu a vida para purificar o marido.' },
  { name: 'Lorde Krauser', ep: 'O verdadeiro Quinto Presságio', img: 'assets/portraits/ref.webp', pos: '60% 50%', text: 'Híbrido humano-Draconato. Governou Hikari por dez anos sob identidade forjada. Tentáculos do Abismo e Armadura Arcana: Frio Absoluto. Derrotado por uma canção que ele mesmo pediu.' },
  { name: 'Os Presságios', ep: 'Fios da Presença', img: 'assets/portraits/ref.webp', pos: '90% 10%', text: '“Almas devoradas pela própria ambição. Homens e mulheres que entregaram a única coisa que realmente possuíam: o próprio livre-arbítrio.” Numerados — o Quinto, o Sexto. A Presença os chama de Fios.' },
];
