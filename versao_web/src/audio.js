// =====================================================================
//  OBLITUS LIMBO — Sistema de áudio procedural (Web Audio)
//  Toda a música e todos os efeitos são sintetizados em tempo real.
// =====================================================================

const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
const rnd = (a, b) => a + Math.random() * (b - a);

class AudioSystem {
  constructor() {
    this.ctx = null;
    this.ready = false;
    this.tracks = {};
    this.current = null;
    this.intensity = 0;           // 0..1 — camadas dinâmicas de combate
    this.flags = {};              // ex.: flags.harmonic (melodia do ukulele no chefe final)
    this.ksCache = new Map();
    this.loops = new Map();
    this.vol = { master: 0.8, music: 0.6, sfx: 0.9 };
  }

  init() {
    if (this.ready) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const ctx = this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.master = ctx.createGain(); this.master.gain.value = this.vol.master;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 4; comp.attack.value = 0.005; comp.release.value = 0.2;
    this.master.connect(comp); comp.connect(ctx.destination);

    this.reverb = ctx.createConvolver();
    this.reverb.buffer = this._impulse(3.2, 2.6);
    this.revOut = ctx.createGain(); this.revOut.gain.value = 0.55;
    this.reverb.connect(this.revOut); this.revOut.connect(this.master);

    this.musicBus = ctx.createGain(); this.musicBus.gain.value = this.vol.music;
    this.musicBus.connect(this.master);
    this.musicRev = ctx.createGain(); this.musicRev.gain.value = 0.45;
    this.musicBus.connect(this.musicRev); this.musicRev.connect(this.reverb);

    this.sfxBus = ctx.createGain(); this.sfxBus.gain.value = this.vol.sfx;
    this.sfxBus.connect(this.master);
    this.sfxRev = ctx.createGain(); this.sfxRev.gain.value = 0.25;
    this.sfxBus.connect(this.sfxRev); this.sfxRev.connect(this.reverb);

    // ruído branco compartilhado
    const len = ctx.sampleRate * 2;
    this.noise = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noise.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    // ruído marrom (vento, rumble)
    this.brown = ctx.createBuffer(1, len, ctx.sampleRate);
    const b = this.brown.getChannelData(0); let last = 0;
    for (let i = 0; i < len; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; b[i] = last * 3.5; }

    this._defineTracks();
    this.ready = true;
    this._timer = setInterval(() => this._schedule(), 40);
  }

  setVolume(kind, v) {
    this.vol[kind] = v;
    if (!this.ready) return;
    const node = kind === 'master' ? this.master : kind === 'music' ? this.musicBus : this.sfxBus;
    node.gain.setTargetAtTime(v, this.ctx.currentTime, 0.05);
  }

  _impulse(sec, decay) {
    const ctx = this.ctx, len = ctx.sampleRate * sec;
    const buf = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const d = buf.getChannelData(c);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
    }
    return buf;
  }

  // ------------------------------------------------------------------
  //  Instrumentos
  // ------------------------------------------------------------------
  _ks(freq, bright = 0.5, dur = 2.4) {
    const key = Math.round(freq * 10) + ':' + bright;
    if (this.ksCache.has(key)) return this.ksCache.get(key);
    const sr = this.ctx.sampleRate, len = Math.floor(sr * dur);
    const buf = this.ctx.createBuffer(1, len, sr), out = buf.getChannelData(0);
    const N = Math.max(2, Math.round(sr / freq));
    const line = new Float32Array(N);
    for (let i = 0; i < N; i++) line[i] = Math.random() * 2 - 1;
    // suaviza a excitação (timbre de nylon do ukulele)
    for (let p = 0; p < (bright > 0.6 ? 1 : 3); p++)
      for (let i = 1; i < N; i++) line[i] = (line[i] + line[i - 1]) * 0.5;
    let idx = 0; const damp = 0.4985 + bright * 0.0012;
    for (let i = 0; i < len; i++) {
      const cur = line[idx], nxt = line[(idx + 1) % N];
      out[i] = cur;
      line[idx] = (cur + nxt) * damp;
      idx = (idx + 1) % N;
    }
    this.ksCache.set(key, buf);
    return buf;
  }

  pluck(m, t, vol = 0.3, dest = this.musicBus, bright = 0.5, pan = 0) {
    const ctx = this.ctx, src = ctx.createBufferSource();
    src.buffer = this._ks(mtof(m), bright);
    const g = ctx.createGain(); g.gain.value = vol;
    const p = ctx.createStereoPanner(); p.pan.value = pan;
    src.connect(g); g.connect(p); p.connect(dest);
    src.start(t); src.stop(t + 2.4);
  }

  strum(notes, t, vol = 0.22, dest = this.musicBus, spread = 0.018, down = true) {
    const ns = down ? notes : [...notes].reverse();
    ns.forEach((n, i) => this.pluck(n, t + i * spread, vol, dest, 0.5, (i - 1.5) * 0.15));
  }

  osc(type, m, t, dur, vol, dest, { attack = 0.01, release = 0.2, cutoff = 4000, q = 0.7, detune = 0, vib = 0, glide = 0 } = {}) {
    const ctx = this.ctx;
    const o = ctx.createOscillator(); o.type = type;
    const f = m; // sempre em Hz
    if (glide) { o.frequency.setValueAtTime(f * glide, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.08); }
    else o.frequency.value = f;
    o.detune.value = detune;
    if (vib) {
      const l = ctx.createOscillator(); l.frequency.value = 5.2;
      const lg = ctx.createGain(); lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(f * vib, t + 0.4);
      l.connect(lg); lg.connect(o.frequency); l.start(t); l.stop(t + dur + release + 0.1);
    }
    const flt = ctx.createBiquadFilter(); flt.type = 'lowpass'; flt.frequency.value = cutoff; flt.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(vol, t + attack);
    g.gain.setValueAtTime(vol, t + Math.max(attack, dur));
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur + release);
    o.connect(flt); flt.connect(g); g.connect(dest);
    o.start(t); o.stop(t + dur + release + 0.05);
    return { o, g, flt };
  }

  pad(notes, t, dur, vol = 0.05, dest = this.musicBus, cutoff = 1200) {
    for (const n of notes) for (const dt of [-9, 0, 8]) {
      this.osc('sawtooth', mtof(n), t, dur, vol / 3, dest, { attack: dur * 0.35, release: dur * 0.4, cutoff, detune: dt });
    }
  }

  strings(m, t, dur, vol = 0.06, dest = this.musicBus) {
    this.osc('sawtooth', mtof(m), t, dur, vol, dest, { attack: 0.12, release: 0.3, cutoff: 2400, vib: 0.006, detune: -5 });
    this.osc('sawtooth', mtof(m), t, dur, vol * 0.7, dest, { attack: 0.14, release: 0.3, cutoff: 2000, vib: 0.005, detune: 6 });
  }

  lead(m, t, dur, vol = 0.07, dest = this.musicBus) {
    this.osc('triangle', mtof(m), t, dur, vol, dest, { attack: 0.03, release: 0.25, cutoff: 3500, vib: 0.008, glide: 0.98 });
    this.osc('sawtooth', mtof(m), t, dur, vol * 0.25, dest, { attack: 0.05, release: 0.2, cutoff: 1800, vib: 0.008 });
  }

  choir(m, t, dur, vol = 0.05, dest = this.musicBus, vowel = 'a') {
    const ctx = this.ctx;
    const forms = vowel === 'o' ? [[450, 8], [800, 10], [2830, 14]] : [[800, 8], [1150, 10], [2900, 14]];
    const out = ctx.createGain();
    out.gain.setValueAtTime(0, t);
    out.gain.linearRampToValueAtTime(vol, t + dur * 0.3);
    out.gain.setValueAtTime(vol, t + dur * 0.7);
    out.gain.linearRampToValueAtTime(0.0001, t + dur + 0.6);
    out.connect(dest);
    for (const dt of [-12, 0, 11]) {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = mtof(m); o.detune.value = dt;
      const l = ctx.createOscillator(); l.frequency.value = rnd(4.5, 5.8);
      const lg = ctx.createGain(); lg.gain.value = mtof(m) * 0.006; l.connect(lg); lg.connect(o.frequency);
      for (const [f, q] of forms) {
        const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = f; bp.Q.value = q;
        o.connect(bp); bp.connect(out);
      }
      o.start(t); o.stop(t + dur + 0.8); l.start(t); l.stop(t + dur + 0.8);
    }
  }

  bell(m, t, vol = 0.08, dest = this.musicBus, len = 3) {
    const ratios = [1, 2.76, 5.4, 8.93];
    ratios.forEach((r, i) => {
      this.osc('sine', mtof(m) * r, t, 0.005, vol / (i + 1), dest, { attack: 0.002, release: len / (i + 1), cutoff: 12000 });
    });
  }

  organ(notes, t, dur, vol = 0.04, dest = this.musicBus) {
    for (const n of notes) for (const h of [1, 2, 4]) {
      this.osc('sine', mtof(n) * h, t, dur, vol / h, dest, { attack: 0.08, release: 0.5, cutoff: 6000 });
    }
  }

  bass(m, t, dur, vol = 0.14, dest = this.musicBus) {
    this.osc('sine', mtof(m), t, dur, vol, dest, { attack: 0.01, release: 0.15 });
    this.osc('sawtooth', mtof(m), t, dur, vol * 0.3, dest, { attack: 0.01, release: 0.1, cutoff: 400 });
  }

  noiseHit(t, { vol = 0.3, dur = 0.15, type = 'bandpass', freq = 1500, q = 1, dest = this.musicBus, attack = 0.002, freqEnd = null, buf = null } = {}) {
    const ctx = this.ctx, src = ctx.createBufferSource();
    src.buffer = buf || this.noise; src.loop = true;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(freq, t); f.Q.value = q;
    if (freqEnd) f.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(dest);
    src.start(t, Math.random()); src.stop(t + dur + 0.05);
  }

  drum(kind, t, vol = 1, dest = this.musicBus) {
    const ctx = this.ctx;
    if (kind === 'kick' || kind === 'taiko') {
      const o = ctx.createOscillator(), g = ctx.createGain();
      const f0 = kind === 'taiko' ? 140 : 120, f1 = kind === 'taiko' ? 48 : 42;
      o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + 0.18);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.55 * vol, t + 0.004);
      g.gain.exponentialRampToValueAtTime(0.0001, t + (kind === 'taiko' ? 0.7 : 0.35));
      o.connect(g); g.connect(dest); o.start(t); o.stop(t + 0.8);
      if (kind === 'taiko') this.noiseHit(t, { vol: 0.12 * vol, dur: 0.12, freq: 600, dest });
    } else if (kind === 'snare') {
      this.noiseHit(t, { vol: 0.22 * vol, dur: 0.16, freq: 2200, q: 0.6, dest });
      this.osc('triangle', 180, t, 0.02, 0.12 * vol, dest, { attack: 0.001, release: 0.08 });
    } else if (kind === 'frame') {
      this.noiseHit(t, { vol: 0.12 * vol, dur: 0.1, freq: 900, q: 2, dest });
      this.osc('sine', 95, t, 0.01, 0.2 * vol, dest, { attack: 0.002, release: 0.18 });
    } else if (kind === 'shaker') {
      this.noiseHit(t, { vol: 0.05 * vol, dur: 0.06, type: 'highpass', freq: 6000, dest });
    } else if (kind === 'heart') {
      this.osc('sine', 52, t, 0.02, 0.4 * vol, dest, { attack: 0.005, release: 0.18 });
      this.osc('sine', 48, t + 0.22, 0.02, 0.3 * vol, dest, { attack: 0.005, release: 0.2 });
    } else if (kind === 'anvil') {
      this.bell(84, t, 0.05 * vol, dest, 0.6);
    }
  }

  // ------------------------------------------------------------------
  //  Sequenciador de música
  // ------------------------------------------------------------------
  _defineTracks() {
    const A = this;
    // Progressão de "O Alvorecer da Ausência" — Lá menor
    const songChords = [[57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67], [52, 55, 59, 64],
                        [53, 57, 60, 65], [52, 55, 60, 64], [50, 53, 57, 62], [52, 56, 59, 64]];
    const songMelody = [
      [[69, 1], [72, 1], [76, 1.5], [74, .5]], [[72, 1], [71, 1], [69, 2]],
      [[67, 1], [69, 1], [71, 1.5], [72, .5]], [[71, 1], [67, 1], [64, 2]],
      [[65, 1], [69, 1], [72, 1.5], [74, .5]], [[76, 1], [74, 1], [72, 1], [71, 1]],
      [[69, 1], [71, 1], [72, 1], [76, 1]], [[69, 4]],
    ];
    const playMelody = (bar, t, beat, fn) => {
      let acc = 0;
      for (const [n, d] of songMelody[bar % 8]) { fn(n, t + acc * beat, d * beat); acc += d; }
    };

    this.tracks = {
      title: { bpm: 72, bar(i, t, b) {
        const ch = songChords[i % 8];
        A.pad(ch.map(n => n - 12), t, b * 4, 0.035, this.out, 900);
        A.strum(ch, t, 0.12, this.out); A.strum(ch, t + b * 2, 0.09, this.out, 0.02, false);
        if (i >= 2) playMelody(i, t, b, (n, tt) => A.pluck(n + 12, tt, 0.26, this.out, 0.7));
        A.bass(ch[0] - 12, t, b * 3.5, 0.08, this.out);
      } },
      vardun: { bpm: 66, bar(i, t, b) {
        const prog = [[50, 57, 62, 65], [46, 53, 58, 62], [53, 60, 65, 69], [45, 52, 57, 61]];
        const ch = prog[i % 4];
        A.pad(ch, t, b * 4, 0.03, this.out, 700);
        for (let k = 0; k < 8; k++) A.pluck(ch[(k * 3) % 4] + (k > 3 ? 12 : 0), t + k * b / 2, 0.11, this.out, 0.4, k % 2 ? 0.3 : -0.3);
        if (i % 2 === 1) A.lead(ch[3] + 12, t + b * 2, b * 1.8, 0.03, this.out);
        A.bass(ch[0] - 12, t, b * 4, 0.07, this.out);
      } },
      battle: { bpm: 138, bar(i, t, b) {
        const roots = [45, 45, 41, 43];
        const r = roots[i % 4];
        for (let k = 0; k < 8; k++) A.osc('sawtooth', mtof(r), t + k * b / 2, b * 0.4, 0.06, this.out, { cutoff: 900, release: 0.05 });
        A.drum('taiko', t, 1, this.out); A.drum('taiko', t + b * 1.5, 0.7, this.out);
        A.drum('taiko', t + b * 2, 0.9, this.out); A.drum('frame', t + b * 3, 0.8, this.out); A.drum('frame', t + b * 3.5, 0.6, this.out);
        for (let k = 0; k < 8; k++) A.drum('shaker', t + k * b / 2, 0.7, this.out);
        if (A.intensity > 0.3) { A.drum('snare', t + b, 0.8, this.out); A.drum('snare', t + b * 3, 0.8, this.out); }
        if (i % 8 >= 4) playMelody(i * 2, t, b / 2, (n, tt, d) => A.strings(n, tt, d * 0.9, 0.05, this.out));
        else if (i % 2 === 0) A.strings(r + 24, t, b * 4, 0.035, this.out);
      } },
      boss_darius: { bpm: 150, bar(i, t, b) {
        const roots = [40, 40, 43, 38];
        const r = roots[i % 4];
        for (let k = 0; k < 4; k++) A.drum('kick', t + k * b, 1, this.out);
        A.drum('taiko', t + b * 0.5, 0.6, this.out); A.drum('taiko', t + b * 2.5, 0.6, this.out);
        A.drum('snare', t + b, 1, this.out); A.drum('snare', t + b * 3, 1, this.out);
        for (let k = 0; k < 8; k++) A.osc('sawtooth', mtof(r + (k % 4 === 3 ? 3 : 0)), t + k * b / 2, b * 0.35, 0.07, this.out, { cutoff: 700 });
        // metais graves
        A.pad([r + 12, r + 15, r + 19], t, b * 0.5, 0.09, this.out, 1600);
        A.pad([r + 12, r + 15, r + 19], t + b * 1.5, b * 0.5, 0.07, this.out, 1600);
        if (i % 2 === 0) A.choir(r + 24, t, b * 4, 0.035, this.out);
        if (i % 4 === 3) A.drum('anvil', t + b * 3.5, 1, this.out);
      } },
      valley: { bpm: 56, bar(i, t, b) {
        const ch = i % 2 ? [52, 53, 59] : [52, 55, 58];
        A.pad(ch, t, b * 4, 0.035, this.out, 600);
        A.drum('heart', t, 0.8, this.out); A.drum('heart', t + b * 2, 0.6, this.out);
        const scale = [64, 65, 67, 70, 71, 74, 76];
        for (let k = 0; k < 3; k++) if (Math.random() < 0.6)
          A.bell(scale[Math.floor(Math.random() * scale.length)] + 12, t + Math.random() * b * 4, 0.025, this.out, 2.5);
        if (i % 4 === 0) A.choir(64, t, b * 4, 0.02, this.out, 'o');
      } },
      boss_elemental: { bpm: 160, bar(i, t, b) {
        const roots = [45, 46, 45, 43];
        const r = roots[i % 4];
        for (let k = 0; k < 4; k++) A.drum('kick', t + k * b, 0.9, this.out);
        A.drum('snare', t + b, 0.9, this.out); A.drum('snare', t + b * 3, 0.9, this.out);
        A.drum('taiko', t + b * 2.5, 0.7, this.out);
        for (let k = 0; k < 16; k++) A.drum('shaker', t + k * b / 4, 0.5, this.out);
        const arp = [0, 7, 12, 15, 12, 7, 3, 7];
        for (let k = 0; k < 8; k++) A.osc('square', mtof(r + 12 + arp[k]), t + k * b / 2, b * 0.3, 0.025, this.out, { cutoff: 2200, release: 0.05 });
        A.bass(r - 12, t, b * 2, 0.12, this.out); A.bass(r - 12, t + b * 2, b * 2, 0.12, this.out);
        if (i % 8 >= 4) A.strings(r + 24 + (i % 2 ? 3 : 0), t, b * 4, 0.05, this.out);
        if (i % 2 === 0) A.choir(r + 12, t, b * 4, 0.03, this.out);
      } },
      throne: { bpm: 60, bar(i, t, b) {
        const prog = [[45, 52, 57, 60], [44, 51, 56, 60], [43, 50, 55, 58], [44, 52, 56, 59]];
        A.organ(prog[i % 4], t, b * 4, 0.03, this.out);
        A.choir(prog[i % 4][2] + 12, t, b * 4, 0.025, this.out, 'o');
        if (i % 2 === 0) A.bell(69, t, 0.04, this.out, 4);
      } },
      boss_krauser: { bpm: 132, bar(i, t, b) {
        const prog = [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [44, 52, 56, 59]];
        const ch = prog[i % 4], r = ch[0];
        A.drum('taiko', t, 1, this.out); A.drum('kick', t + b, 0.8, this.out);
        A.drum('taiko', t + b * 2, 1, this.out); A.drum('taiko', t + b * 2.75, 0.6, this.out); A.drum('kick', t + b * 3, 0.8, this.out);
        A.drum('snare', t + b, 0.6, this.out); A.drum('snare', t + b * 3, 0.7, this.out);
        for (let k = 0; k < 8; k++) A.osc('sawtooth', mtof(r - 12 + (k === 7 ? 1 : 0)), t + k * b / 2, b * 0.4, 0.06, this.out, { cutoff: 600 });
        A.choir(ch[2] + 12, t, b * 2, 0.04, this.out); A.choir(ch[3] + 12, t + b * 2, b * 2, 0.04, this.out);
        A.organ([ch[1], ch[2]], t, b * 4, 0.02, this.out);
        if (i % 4 === 3) A.bell(r + 36, t + b * 3, 0.05, this.out, 2);
        if (A.flags.harmonic) {
          const sc = songChords[i % 8];
          A.strum(sc.map(n => n + 12), t, 0.1, this.out, 0.012);
          A.strum(sc.map(n => n + 12), t + b * 2, 0.08, this.out, 0.012, false);
          playMelody(i, t, b, (n, tt) => A.pluck(n + 12, tt, 0.3, this.out, 0.75));
        }
        if (A.flags.viktor) { A.strings(r + 24, t, b * 2, 0.05, this.out); A.strings(r + 31, t + b * 2, b * 2, 0.05, this.out); }
      } },
      flashback: { bpm: 64, bar(i, t, b) {
        const ch = songChords[i % 8];
        playMelody(i, t, b, (n, tt) => A.bell(n + 12, tt, 0.05, this.out, 2.2));
        A.pad(ch.map(n => n - 12), t, b * 4, 0.02, this.out, 500);
      } },
      limbo: { bpm: 40, bar(i, t, b) {
        A.pad([33, 34, 40], t, b * 4, 0.05, this.out, 260);
        A.noiseHit(t, { vol: 0.12, dur: b * 4, type: 'lowpass', freq: 120, attack: b * 1.5, dest: this.out, buf: A.brown });
        A.drum('heart', t + b, 0.9, this.out); A.drum('heart', t + b * 3, 0.7, this.out);
        if (i % 2 === 1) A.choir(46, t, b * 4, 0.03, this.out, 'o');
      } },
      silence: { bpm: 60, bar() {} },
    };
    for (const k in this.tracks) {
      const tr = this.tracks[k];
      tr.out = this.ctx.createGain(); tr.out.gain.value = 0; tr.out.connect(this.musicBus);
      tr.bar = tr.bar.bind(tr);
    }
  }

  music(name, fade = 1.5) {
    if (!this.ready) { this._pendingMusic = name; return; }
    if (this.current && this.current.name === name) return;
    const now = this.ctx.currentTime;
    if (this.current) {
      const old = this.current.tr;
      old.out.gain.cancelScheduledValues(now);
      old.out.gain.setValueAtTime(old.out.gain.value, now);
      old.out.gain.linearRampToValueAtTime(0, now + fade);
      old.active = false;
    }
    const tr = this.tracks[name];
    if (!tr) { this.current = null; return; }
    tr.active = true;
    tr.out.gain.cancelScheduledValues(now);
    tr.out.gain.setValueAtTime(tr.out.gain.value, now);
    tr.out.gain.linearRampToValueAtTime(1, now + fade);
    this.current = { name, tr, bar: 0, next: now + 0.1 };
  }

  _schedule() {
    if (!this.ready || !this.current) return;
    const c = this.current, ctx = this.ctx;
    const beat = 60 / c.tr.bpm;
    while (c.next < ctx.currentTime + 0.35) {
      try { c.tr.bar(c.bar, c.next, beat); } catch (e) { console.warn(e); }
      c.bar++; c.next += beat * 4;
    }
  }

  // ------------------------------------------------------------------
  //  Efeitos sonoros
  // ------------------------------------------------------------------
  sfx(name, o = {}) {
    if (!this.ready) return;
    const t = this.ctx.currentTime + (o.delay || 0), S = this.sfxBus, v = o.vol ?? 1;
    switch (name) {
      case 'swing':
        this.noiseHit(t, { vol: 0.25 * v, dur: 0.18, freq: rnd(1800, 2600), freqEnd: rnd(500, 800), q: 1.4, dest: S, attack: 0.04 }); break;
      case 'swingHeavy':
        this.noiseHit(t, { vol: 0.35 * v, dur: 0.32, freq: 900, freqEnd: 220, q: 1.2, dest: S, attack: 0.08 }); break;
      case 'hit':
        this.noiseHit(t, { vol: 0.4 * v, dur: 0.09, freq: rnd(1200, 1800), q: 0.8, dest: S });
        this.osc('sine', rnd(110, 140), t, 0.02, 0.4 * v, S, { attack: 0.002, release: 0.12 });
        this.noiseHit(t, { vol: 0.15 * v, dur: 0.2, type: 'lowpass', freq: 500, dest: S }); break;
      case 'hitHeavy':
        this.noiseHit(t, { vol: 0.5 * v, dur: 0.18, freq: 700, q: 0.7, dest: S });
        this.osc('sine', 70, t, 0.04, 0.6 * v, S, { attack: 0.002, release: 0.3, glide: 2 }); break;
      case 'crit':
        this.sfx('hitHeavy', { vol: v });
        this.osc('square', 1760, t, 0.01, 0.05 * v, S, { attack: 0.001, release: 0.25, cutoff: 6000 }); break;
      case 'block':
        [1, 2.7, 4.1].forEach((r, i) => this.osc('triangle', 520 * r, t, 0.005, 0.12 * v / (i + 1), S, { attack: 0.001, release: 0.35, cutoff: 9000 }));
        this.noiseHit(t, { vol: 0.2 * v, dur: 0.07, freq: 3500, dest: S }); break;
      case 'parry':
        [1, 2.4, 3.9, 6.1].forEach((r, i) => this.osc('sine', 880 * r, t, 0.005, 0.15 * v / (i + 1), S, { attack: 0.001, release: 0.9, cutoff: 12000 }));
        this.noiseHit(t, { vol: 0.3 * v, dur: 0.1, freq: 5000, dest: S }); break;
      case 'dodge':
        this.noiseHit(t, { vol: 0.2 * v, dur: 0.28, freq: 600, freqEnd: 2400, q: 2, dest: S, attack: 0.05 }); break;
      case 'step':
        this.noiseHit(t, { vol: 0.06 * v * rnd(0.7, 1), dur: 0.06, type: 'lowpass', freq: o.wood ? 900 : rnd(1500, 2200), dest: S });
        if (o.wood) this.osc('sine', rnd(90, 120), t, 0.01, 0.05 * v, S, { attack: 0.001, release: 0.06 }); break;
      case 'hurt':
        this.osc('sawtooth', rnd(260, 320), t, 0.08, 0.08 * v, S, { attack: 0.005, release: 0.15, cutoff: 1200, glide: 1.3 });
        this.sfx('hit', { vol: v * 0.8 }); break;
      case 'grunt':
        this.osc('sawtooth', rnd(110, 150), t, 0.12, 0.08 * v, S, { attack: 0.01, release: 0.2, cutoff: 700, glide: 1.2 }); break;
      case 'die':
        this.osc('sawtooth', rnd(150, 180), t, 0.3, 0.08 * v, S, { attack: 0.01, release: 0.5, cutoff: 600, glide: 1.5 });
        this.noiseHit(t + 0.25, { vol: 0.2 * v, dur: 0.25, type: 'lowpass', freq: 300, dest: S }); break;
      case 'roar':
        for (const f of [55, 82, 110]) this.osc('sawtooth', f * (o.pitch || 1), t, 1.0, 0.1 * v, S, { attack: 0.1, release: 0.6, cutoff: 900, vib: 0.03 });
        this.noiseHit(t, { vol: 0.25 * v, dur: 1.4, type: 'bandpass', freq: 400, q: 0.5, attack: 0.15, dest: S }); break;
      case 'fire':
        this.noiseHit(t, { vol: 0.35 * v, dur: 0.6, type: 'lowpass', freq: 2000, freqEnd: 300, attack: 0.03, dest: S });
        this.osc('sine', 80, t, 0.1, 0.25 * v, S, { attack: 0.01, release: 0.4, glide: 1.6 }); break;
      case 'ice':
        for (let k = 0; k < 5; k++) this.osc('sine', rnd(2000, 5000), t + k * 0.02, 0.005, 0.04 * v, S, { attack: 0.001, release: 0.25, cutoff: 12000 });
        this.noiseHit(t, { vol: 0.25 * v, dur: 0.25, type: 'highpass', freq: 3000, dest: S }); break;
      case 'shatter':
        for (let k = 0; k < 9; k++) this.osc('triangle', rnd(1800, 6000), t + k * 0.015, 0.005, 0.05 * v, S, { attack: 0.001, release: 0.4, cutoff: 14000 });
        this.noiseHit(t, { vol: 0.4 * v, dur: 0.3, freq: 4000, q: 0.5, dest: S }); break;
      case 'magic':
        [0, 4, 7, 12].forEach((n, i) => this.osc('sine', mtof(76 + n + (o.pitch || 0)), t + i * 0.04, 0.05, 0.05 * v, S, { attack: 0.005, release: 0.5 })); break;
      case 'soundBlade': {
        const ch = [[69, 72, 76, 81], [65, 69, 72, 77], [67, 71, 74, 79], [64, 67, 71, 76]][Math.floor(Math.random() * 4)];
        this.strum(ch, t, 0.32 * v, S, 0.012);
        this.noiseHit(t, { vol: 0.18 * v, dur: 0.25, freq: 3000, freqEnd: 800, q: 3, dest: S }); break;
      }
      case 'chord': this.strum(o.notes || [69, 72, 76, 81], t, 0.35 * v, S, 0.015); break;
      case 'shock':
        this.osc('sine', 60, t, 0.1, 0.6 * v, S, { attack: 0.002, release: 0.6, glide: 3 });
        this.noiseHit(t, { vol: 0.35 * v, dur: 0.5, type: 'lowpass', freq: 1200, freqEnd: 100, dest: S });
        this.strum([57, 64, 69, 72, 76], t, 0.3 * v, S, 0.01); break;
      case 'blink':
        this.noiseHit(t, { vol: 0.25 * v, dur: 0.2, freq: 4000, freqEnd: 300, q: 4, dest: S });
        this.osc('sine', 1200, t, 0.05, 0.08 * v, S, { attack: 0.002, release: 0.2, glide: 0.4 }); break;
      case 'fury':
        this.osc('sine', 40, t, 0.6, 0.6 * v, S, { attack: 0.01, release: 1.2, glide: 2.5 });
        this.noiseHit(t, { vol: 0.4 * v, dur: 1.2, type: 'lowpass', freq: 3000, freqEnd: 80, attack: 0.01, dest: S });
        this.osc('sawtooth', 110, t, 0.5, 0.06 * v, S, { attack: 0.2, release: 0.6, cutoff: 500, vib: 0.05 }); break;
      case 'potion':
        for (let k = 0; k < 4; k++) this.osc('sine', rnd(400, 900), t + k * 0.07, 0.03, 0.08 * v, S, { attack: 0.005, release: 0.1, glide: 0.7 });
        this.sfx('magic', { vol: 0.6 * v, delay: 0.3 }); break;
      case 'ui': this.osc('triangle', 1100, t, 0.01, 0.06 * v, S, { attack: 0.001, release: 0.08 }); break;
      case 'uiOk': this.osc('triangle', 880, t, 0.02, 0.07 * v, S, { attack: 0.001, release: 0.15 }); this.osc('triangle', 1320, t + 0.06, 0.02, 0.07 * v, S, { attack: 0.001, release: 0.25 }); break;
      case 'explosion':
        this.osc('sine', 50, t, 0.2, 0.7 * v, S, { attack: 0.002, release: 1.0, glide: 2.5 });
        this.noiseHit(t, { vol: 0.6 * v, dur: 1.2, type: 'lowpass', freq: 2500, freqEnd: 60, dest: S }); break;
      case 'arrow':
        this.noiseHit(t, { vol: 0.15 * v, dur: 0.22, freq: 2500, freqEnd: 1200, q: 6, dest: S });
        this.osc('triangle', 220, t, 0.01, 0.1 * v, S, { attack: 0.001, release: 0.1 }); break;
      case 'splash':
        this.noiseHit(t, { vol: 0.4 * v, dur: 0.5, type: 'lowpass', freq: 3000, freqEnd: 400, dest: S });
        for (let k = 0; k < 4; k++) this.osc('sine', rnd(500, 1300), t + k * 0.05, 0.02, 0.06 * v, S, { attack: 0.002, release: 0.08, glide: 0.6 }); break;
      case 'wind':
        this.noiseHit(t, { vol: 0.3 * v, dur: 1.4, freq: 500, freqEnd: 1600, q: 3, attack: 0.4, dest: S }); break;
      case 'tentacle':
        this.osc('sawtooth', 70, t, 0.2, 0.15 * v, S, { attack: 0.02, release: 0.3, cutoff: 500, glide: 0.5 });
        this.noiseHit(t, { vol: 0.25 * v, dur: 0.35, type: 'lowpass', freq: 900, dest: S }); break;
      case 'telegraph':
        this.osc('sine', 220, t, 0.25, 0.06 * v, S, { attack: 0.05, release: 0.2, glide: 0.5 }); break;
      case 'portal':
        this.osc('sawtooth', 30, t, 3, 0.2 * v, S, { attack: 1, release: 2, cutoff: 300, vib: 0.1 });
        this.noiseHit(t, { vol: 0.4 * v, dur: 4, type: 'lowpass', freq: 200, freqEnd: 2000, attack: 2, dest: S, buf: this.brown });
        this.choir(40, t, 3, 0.05 * v, S, 'o'); break;
      case 'bell': this.bell(o.note || 69, t, 0.1 * v, S, 3); break;
      case 'heartbeat': this.drum('heart', t, v, S); break;
      case 'gong': this.bell(45, t, 0.3 * v, S, 6); this.drum('taiko', t, v, S); break;
      case 'whoosh':
        this.noiseHit(t, { vol: 0.3 * v, dur: 0.8, freq: 300, freqEnd: 3000, q: 1, attack: 0.5, dest: S }); break;
      case 'reveal':
        this.osc('sine', 50, t, 0.3, 0.6 * v, S, { attack: 0.002, release: 1.5, glide: 2 });
        this.choir(57, t, 1.5, 0.05 * v, S); this.choir(64, t, 1.5, 0.04 * v, S); break;
    }
  }

  // ambiências em loop (vento, fogueira, multidão)
  loop(name, on, vol = 1) {
    if (!this.ready) return;
    const ex = this.loops.get(name);
    if (!on) {
      if (ex) { ex.g.gain.setTargetAtTime(0, this.ctx.currentTime, 0.4); setTimeout(() => { try { ex.src.stop(); } catch (e) {} }, 2000); this.loops.delete(name); }
      return;
    }
    if (ex) { ex.g.gain.setTargetAtTime(ex.base * vol, this.ctx.currentTime, 0.3); return; }
    const ctx = this.ctx, src = ctx.createBufferSource();
    src.buffer = name === 'wind' || name === 'rumble' ? this.brown : this.noise; src.loop = true;
    const f = ctx.createBiquadFilter(), g = ctx.createGain();
    let base = 0.1;
    if (name === 'wind') { f.type = 'bandpass'; f.frequency.value = 500; f.Q.value = 0.6; base = 0.35;
      const l = ctx.createOscillator(); l.frequency.value = 0.13; const lg = ctx.createGain(); lg.gain.value = 300; l.connect(lg); lg.connect(f.frequency); l.start(); }
    if (name === 'fire') { f.type = 'lowpass'; f.frequency.value = 1400; base = 0.06; }
    if (name === 'rumble') { f.type = 'lowpass'; f.frequency.value = 140; base = 0.5; }
    if (name === 'tavern') { f.type = 'bandpass'; f.frequency.value = 700; f.Q.value = 0.4; base = 0.035; }
    g.gain.value = 0; g.gain.setTargetAtTime(base * vol, ctx.currentTime, 0.5);
    src.connect(f); f.connect(g); g.connect(this.sfxBus); src.start();
    this.loops.set(name, { src, g, base });
  }

  stopLoops() { for (const k of [...this.loops.keys()]) this.loop(k, false); }
}

export const Audio = new AudioSystem();
