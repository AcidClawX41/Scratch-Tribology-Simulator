/* ════════ SFX ════════
   Efectos de sonido sintetizados en JS puro, sin archivos ni red: la misma receta suena igual en
   escritorio (se renderiza al vuelo a un AudioBuffer) y en móvil (se prerenderiza a WAV con
   `npm run sfx:render -w @sts/mobile`). Determinista: semilla fija por efecto.
   Técnicas: ruido filtrado (biquad RBJ), osciladores con barrido, resonancias modales (metal,
   vidrio), chasquidos granulares (madera, astillas) y envolventes exponenciales. */
import { MATERIAL_LOOK, rng, seedOf } from "./art.js";

export const SFX_RATE = 22050;
const TAU = Math.PI * 2;

/* ── DSP ── */
function filter(type, q, sr) {
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0, B0 = 0, B1 = 0, B2 = 0, A1 = 0, A2 = 0;
  const set = (f) => {
    const w = (TAU * Math.min(f, sr * 0.45)) / sr, cs = Math.cos(w), a = Math.sin(w) / (2 * q);
    let b0, b1, b2;
    if (type === "bp") { b0 = a; b1 = 0; b2 = -a; }
    else if (type === "lp") { b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = (1 - cs) / 2; }
    else { b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = (1 + cs) / 2; }
    const a0 = 1 + a;
    B0 = b0 / a0; B1 = b1 / a0; B2 = b2 / a0; A1 = (-2 * cs) / a0; A2 = (1 - a) / a0;
  };
  const run = (x) => { const y = B0 * x + B1 * x1 + B2 * x2 - A1 * y1 - A2 * y2; x2 = x1; x1 = x; y2 = y1; y1 = y; return y; };
  return { set, run };
}
const envAR = (t, a, r, dur) => (t < 0 || t > dur ? 0 : Math.min(1, t / Math.max(a, 1e-4)) * Math.min(1, (dur - t) / Math.max(r, 1e-4)));
const decay = (t, tau) => (t < 0 ? 0 : Math.exp(-t / tau));

/** Banda de ruido: fc(t) y env(t) en segundos relativos a t0. am = modulación "stick-slip". */
function noiseBand(out, sr, R, { t0 = 0, dur, fc, q = 1, env, gain = 1, type = "bp", am = 0, amRate = 40 }) {
  const f = filter(type, q, sr), i0 = Math.floor(t0 * sr), n = Math.floor(dur * sr);
  let amv = 1, amPhase = 0;
  for (let i = 0; i < n && i0 + i < out.length; i++) {
    const t = i / sr;
    if (i % 32 === 0) {
      f.set(typeof fc === "function" ? fc(t) : fc);
      if (am) { amPhase += (32 * amRate) / sr; if (amPhase >= 1) { amPhase -= 1; amv = 1 - am + am * R() * 1.6; } }
    }
    out[i0 + i] += f.run(R() * 2 - 1) * env(t) * gain * amv;
  }
}
/** Tono con frecuencia variable f(t). */
function tone(out, sr, { t0 = 0, dur, f, env, gain = 1, shape = "sine" }) {
  const i0 = Math.floor(t0 * sr), n = Math.floor(dur * sr);
  let ph = 0;
  for (let i = 0; i < n && i0 + i < out.length; i++) {
    const t = i / sr;
    ph += (typeof f === "function" ? f(t) : f) / sr;
    const s = shape === "tri" ? 1 - 4 * Math.abs((ph % 1) - 0.5) : Math.sin(TAU * ph);
    out[i0 + i] += s * env(t) * gain;
  }
}
/** Resonancia modal: parciales [frecuencia, tau, amplitud] excitados por un golpe. */
function modal(out, sr, { t0 = 0, partials, gain = 1 }) {
  const i0 = Math.floor(t0 * sr);
  for (const [fr, tau, amp] of partials) {
    const n = Math.floor(tau * 6 * sr);
    for (let i = 0; i < n && i0 + i < out.length; i++) { const t = i / sr; out[i0 + i] += Math.sin(TAU * fr * t) * Math.exp(-t / tau) * amp * gain; }
  }
}
/** Chasquidos aleatorios (fibras de madera, esquirlas, crujidos): ráfagas cortas filtradas. */
function clicks(out, sr, R, { t0 = 0, dur, rate, fc, q = 2, gain = 1, len = 0.004 }) {
  const count = Math.round(rate * dur);
  for (let k = 0; k < count; k++) {
    const f = filter("bp", q, sr);
    f.set(typeof fc === "function" ? fc(R()) : fc * (0.7 + R() * 0.6));
    const i0 = Math.floor((t0 + R() * dur) * sr), n = Math.floor(len * sr * (0.6 + R()));
    const g = gain * (0.35 + R() * 0.65);
    for (let i = 0; i < n + 400 && i0 + i < out.length; i++) out[i0 + i] += f.run(i < n ? (R() * 2 - 1) * (1 - i / n) : 0) * g;
  }
}
function finish(out, level) {
  let peak = 1e-9;
  for (let i = 0; i < out.length; i++) peak = Math.max(peak, Math.abs(out[i]));
  const g = level / peak, fade = Math.min(out.length, 64);
  for (let i = 0; i < out.length; i++) out[i] = Math.tanh(out[i] * g * 1.1) / Math.tanh(1.1);
  for (let i = 0; i < fade; i++) { out[i] *= i / fade; out[out.length - 1 - i] *= i / fade; }
  return out;
}

/* ── Recetas ── */
const SCRATCH = 1.12; // s: dura lo que la animación del banco
const RECIPES = {
  // Interfaz
  tap: (o, sr, R) => { tone(o, sr, { dur: 0.03, f: 2400, env: (t) => decay(t, 0.006) }); noiseBand(o, sr, R, { dur: 0.01, fc: 5000, q: 2, env: (t) => decay(t, 0.002), gain: 0.4 }); return 0.035; },
  on: (o, sr) => { tone(o, sr, { dur: 0.07, f: 660, env: (t) => envAR(t, 0.004, 0.04, 0.07) }); tone(o, sr, { t0: 0.07, dur: 0.1, f: 990, env: (t) => envAR(t, 0.004, 0.06, 0.1) }); return 0.18; },
  off: (o, sr) => { tone(o, sr, { dur: 0.07, f: 990, env: (t) => envAR(t, 0.004, 0.04, 0.07) }); tone(o, sr, { t0: 0.07, dur: 0.1, f: 560, env: (t) => envAR(t, 0.004, 0.06, 0.1) }); return 0.18; },
  badge: (o, sr) => { [1046.5, 1318.5, 1568, 2093].forEach((f, i) => modal(o, sr, { t0: i * 0.085, partials: [[f, 0.35, 1], [f * 2.76, 0.12, 0.25], [f * 5.4, 0.05, 0.12]], gain: 0.8 })); return 1.0; },
  drip: (o, sr) => { [0, 0.13].forEach((t0, i) => tone(o, sr, { t0, dur: 0.07, f: (t) => 1700 - i * 250 - 15000 * t, env: (t) => decay(t, 0.02) })); return 0.24; },
  // Rayado
  slide: (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.9, type: "hp", fc: 2600, q: 0.7, env: (t) => envAR(t, 0.15, 0.4, 0.9), gain: 0.5 }); return 0.9; },
  squeak: (o, sr, R) => { tone(o, sr, { dur: 0.55, f: (t) => 950 + 380 * t + 35 * Math.sin(TAU * 11 * t), env: (t) => envAR(t, 0.04, 0.2, 0.55), shape: "tri", gain: 0.6 }); noiseBand(o, sr, R, { dur: 0.55, fc: 3000, q: 1, env: (t) => envAR(t, 0.05, 0.2, 0.55), gain: 0.25 }); return 0.6; },
  "scratch-soft": (o, sr, R) => { noiseBand(o, sr, R, { dur: SCRATCH, fc: (t) => 1500 + 500 * Math.sin(TAU * 1.3 * t), q: 1.1, env: (t) => envAR(t, 0.05, 0.14, SCRATCH), am: 0.45, amRate: 55 }); clicks(o, sr, R, { dur: SCRATCH, rate: 18, fc: 2500, gain: 0.5 }); return SCRATCH; },
  "scratch-deep": (o, sr, R) => { noiseBand(o, sr, R, { dur: SCRATCH, fc: 1100, q: 0.7, env: (t) => envAR(t, 0.04, 0.16, SCRATCH), am: 0.7, amRate: 38 }); noiseBand(o, sr, R, { dur: SCRATCH, type: "lp", fc: 260, q: 0.8, env: (t) => envAR(t, 0.05, 0.2, SCRATCH), gain: 1.4 }); clicks(o, sr, R, { dur: SCRATCH, rate: 55, fc: 1800, gain: 0.8 }); return SCRATCH; },
  "scratch-wood": (o, sr, R) => { noiseBand(o, sr, R, { dur: SCRATCH, fc: 850, q: 0.8, env: (t) => envAR(t, 0.04, 0.15, SCRATCH), am: 0.55, amRate: 30 }); clicks(o, sr, R, { dur: SCRATCH, rate: 70, fc: (r) => 700 + r * 2200, q: 3, gain: 1.1, len: 0.006 }); return SCRATCH; },
  "scratch-metal": (o, sr, R) => { noiseBand(o, sr, R, { dur: SCRATCH, fc: (t) => 3300 + 400 * Math.sin(TAU * 2.1 * t), q: 3, env: (t) => envAR(t, 0.03, 0.15, SCRATCH), am: 0.5, amRate: 70 }); for (let k = 0; k < 5; k++) modal(o, sr, { t0: k * 0.21, partials: [[2150, 0.09, 0.6], [3470, 0.07, 0.4], [5310, 0.05, 0.3]], gain: 0.35 }); return SCRATCH; },
  "scratch-glass": (o, sr, R) => { noiseBand(o, sr, R, { dur: SCRATCH, fc: 5200, q: 2.5, env: (t) => envAR(t, 0.03, 0.12, SCRATCH), am: 0.6, amRate: 90, gain: 0.8 }); clicks(o, sr, R, { dur: SCRATCH, rate: 26, fc: (r) => 4000 + r * 4000, q: 6, gain: 1.2, len: 0.002 }); return SCRATCH; },
  // Piel
  "skin-rub": (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.85, type: "lp", fc: 650, q: 0.7, env: (t) => envAR(t, 0.12, 0.3, 0.85), am: 0.3, amRate: 20 }); return 0.85; },
  "skin-cut": (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.8, type: "lp", fc: 600, q: 0.7, env: (t) => envAR(t, 0.1, 0.3, 0.8), gain: 0.6 }); noiseBand(o, sr, R, { t0: 0.18, dur: 0.32, fc: (t) => 700 + 6000 * t, q: 2, env: (t) => envAR(t, 0.02, 0.12, 0.32), am: 0.5, amRate: 60 }); return 0.8; },
  // Punción
  press: (o, sr, R) => { tone(o, sr, { dur: 0.12, f: (t) => 140 - 300 * t, env: (t) => decay(t, 0.03) }); noiseBand(o, sr, R, { dur: 0.08, type: "lp", fc: 500, env: (t) => decay(t, 0.02), gain: 0.5 }); return 0.14; },
  pierce: (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.04, fc: 2200, q: 1.5, env: (t) => decay(t, 0.008) }); tone(o, sr, { t0: 0.01, dur: 0.14, f: (t) => 190 - 700 * t, env: (t) => decay(t, 0.035), gain: 0.9 }); return 0.17; },
  inject: (o, sr, R) => { RECIPES.pierce(o, sr, R); noiseBand(o, sr, R, { t0: 0.12, dur: 0.45, type: "hp", fc: 4200, q: 0.8, env: (t) => envAR(t, 0.03, 0.25, 0.45), gain: 0.45 }); tone(o, sr, { t0: 0.52, dur: 0.07, f: (t) => 1500 - 12000 * t, env: (t) => decay(t, 0.02), gain: 0.5 }); return 0.62; },
  "pierce-solid": (o, sr, R) => { modal(o, sr, { partials: [[180, 0.05, 1], [410, 0.03, 0.6], [930, 0.015, 0.3]] }); noiseBand(o, sr, R, { dur: 0.1, fc: 1500, q: 1, env: (t) => decay(t, 0.025), gain: 0.8 }); clicks(o, sr, R, { t0: 0.02, dur: 0.12, rate: 60, fc: 1800, gain: 0.5 }); return 0.25; },
  "pierce-brittle": (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.012, type: "hp", fc: 2000, env: (t) => decay(t, 0.003), gain: 1.2 }); modal(o, sr, { partials: [[4200, 0.05, 0.7], [6800, 0.035, 0.5], [9100, 0.02, 0.35]], gain: 0.7 }); clicks(o, sr, R, { t0: 0.02, dur: 0.25, rate: 30, fc: (r) => 5000 + r * 3000, q: 8, gain: 0.8, len: 0.0015 }); return 0.35; },
  breakthrough: (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.3, fc: 900, q: 0.6, env: (t) => decay(t, 0.09), gain: 1.3 }); tone(o, sr, { dur: 0.35, f: (t) => 95 - 90 * t, env: (t) => decay(t, 0.1), gain: 1.4 }); clicks(o, sr, R, { dur: 0.9, rate: 70, fc: (r) => 600 + r * 2600, q: 3, gain: 0.9, len: 0.006 }); return 1.0; },
  // Ventana que se parte: chasquido seco, crujido de la hoja y lluvia de trozos (tintineos agudos que caen)
  shatter: (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.02, type: "hp", fc: 2500, env: (t) => decay(t, 0.004), gain: 1.4 }); noiseBand(o, sr, R, { dur: 0.35, fc: 3200, q: 0.7, env: (t) => decay(t, 0.08), gain: 0.9 }); modal(o, sr, { partials: [[3100, 0.08, 0.6], [5200, 0.06, 0.45], [7400, 0.04, 0.3]], gain: 0.6 }); clicks(o, sr, R, { t0: 0.08, dur: 0.9, rate: 50, fc: (r) => 3500 + r * 5000, q: 6, gain: 0.8, len: 0.012 }); return 1.0; },
  snap: (o, sr, R) => { noiseBand(o, sr, R, { dur: 0.01, type: "hp", fc: 1500, env: (t) => decay(t, 0.002), gain: 1.4 }); modal(o, sr, { partials: [[2600, 0.03, 0.8], [5600, 0.018, 0.5], [1300, 0.05, 0.4]] }); clicks(o, sr, R, { t0: 0.05, dur: 0.18, rate: 25, fc: 3000, q: 4, gain: 0.6, len: 0.002 }); return 0.3; },
};
const LEVEL = { tap: 0.35, on: 0.4, off: 0.4, badge: 0.6, drip: 0.45, slide: 0.35, squeak: 0.5, "skin-rub": 0.5 };
export const SFX_IDS = Object.keys(RECIPES);

/** Renderiza un efecto a muestras PCM en [-1, 1]. Mismo resultado en cada llamada. */
export function renderSfx(id, sampleRate = SFX_RATE) {
  const recipe = RECIPES[id];
  if (!recipe) throw new Error(`efecto de sonido desconocido: ${id}`);
  const out = new Float32Array(Math.ceil(1.1 * sampleRate));
  const R = rng(seedOf(`sfx:${id}`));
  const dur = recipe(out, sampleRate, R);
  return finish(out.subarray(0, Math.min(out.length, Math.ceil((dur + 0.05) * sampleRate))), LEVEL[id] ?? 0.8);
}

/** Qué efecto corresponde al resultado de un ensayo (cada situación suena distinta). */
export function sfxForResult(res, target) {
  const kind = (MATERIAL_LOOK[target.id] || {}).kind;
  const brittle = ["glass", "screen", "stone", "crystal", "diamond"].includes(kind);
  if (res.shattered) return "shatter";
  if (res.toolBroken) return "snap";
  if (res.puncture) {
    if (res.skin) return res.pierces ? (res.inject ? "inject" : "pierce") : "press";
    if (res.through) return "breakthrough";
    if (!res.scratched || res.depthUm <= 1) return "press";
    return brittle ? "pierce-brittle" : "pierce-solid";
  }
  if (res.skin) return res.scratched === true ? "skin-cut" : "skin-rub";
  if (!res.scratched) return res.toolWorn && brittle ? "squeak" : "slide";
  // chapa de coche o puerta: la garra rechina contra el metal (o raja el plástico)
  const body = target.body;
  if (res.through) return body && !body.metal ? "scratch-deep" : "scratch-metal";
  if (body && body.metal && res.depthUm > 110) return "scratch-metal";
  if (brittle) return "scratch-glass";
  if (kind === "brushed" || kind === "copper") return "scratch-metal";
  if (kind === "wood") return "scratch-wood";
  if (res.absMode === "corte" && res.sev > 0.6) return "scratch-deep";
  return "scratch-soft";
}

/** WAV PCM de 16 bits mono (para prerenderizar los efectos de la app móvil). */
export function encodeWav(samples, sampleRate = SFX_RATE) {
  const n = samples.length, buf = new ArrayBuffer(44 + n * 2), v = new DataView(buf);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  str(0, "RIFF"); v.setUint32(4, 36 + n * 2, true); str(8, "WAVE"); str(12, "fmt ");
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, sampleRate, true);
  v.setUint32(28, sampleRate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); str(36, "data"); v.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), true);
  return new Uint8Array(buf);
}
