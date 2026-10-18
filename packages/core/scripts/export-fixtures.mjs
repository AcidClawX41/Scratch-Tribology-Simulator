/* Exporta el ORÁCULO del motor 1.x para el port a Godot (godot/tests/fixtures/).
   El motor JavaScript queda congelado: la V2 en GDScript tiene que reproducir estos datos (textos idénticos,
   números con error relativo ≤ 1e-9, SVG byte a byte). Uso (desde la raíz): npm run godot:fixtures

   Archivos pequeños y estables (se versionan):
     lab-data.json      catálogos de data.js, lab.js, art.js y sfx.js
     lab-golden.json    los 40 escenarios del golden con TODAS las salidas de compute() y lo que depende de ellas
     js-semantics.json  cómo formatea y redondea JavaScript (toFixed, Math.round, String(n), log10…) (*)
     rng.json           secuencias de mulberry32 y semillas de seedOf (*)
     shared.json        vectores de la capa compartida: punta, contacto, Hertz, solvers y modo de abrasión (*)
     sfx.json           ids de los efectos y sha256 de los WAV de apps/mobile/assets/sfx
   Archivos grandes (generated/, no se versionan):
     lab-sample.json    muestra determinista (~20.000) del barrido de audit.js, más el modo dual
     art-svg.json       el SVG canónico de una batería de llamadas a art.js (*)
   (*) con los números exactos al bit ({ "$f64": … }): ver `exact` más abajo. */
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import * as C from "../src/index.js";
import { SCENARIOS, runScenario } from "./scenarios.js";
import { sceneToSvg } from "./lib/scene-svg.mjs";

const ROOT = new URL("../../../", import.meta.url);
const OUT = new URL("godot/tests/fixtures/", ROOT);
const GEN = new URL("generated/", OUT);
mkdirSync(GEN, { recursive: true });

// JSON sin pérdidas: NaN e ±Infinity → { "$num": "NaN" | "Infinity" | "-Infinity" }. undefined → clave ausente.
const enc = (_k, v) => (typeof v === "number" && !Number.isFinite(v) ? { $num: String(v) } : v);
// Exacto al bit: el lector de números de Godot no redondea bien los decimales largos ("0.9999999999999999"
// lo lee como 1.0), así que donde hace falta el double exacto (semántica de JS, aleatorio, dibujos) cada número
// no entero va como { "$f64": "<8 bytes little-endian en hexadecimal>" }. Los enteros hasta 2^53 van tal cual.
const f64 = (v) => { const b = Buffer.alloc(8); b.writeDoubleLE(v); return { $f64: b.toString("hex") }; };
const exact = (k, v) => (typeof v !== "number" ? v : !Number.isFinite(v) ? { $num: String(v) }
  : Number.isInteger(v) && Math.abs(v) <= 2 ** 53 ? v : f64(v));
const write = (dir, name, data, replacer = enc) => {
  writeFileSync(new URL(name, dir), JSON.stringify(data, replacer) + "\n");
  return name;
};
const byId = (list, id) => list.find((x) => x.id === id);
const idOf = (x) => (x ? x.id : null);

/* ── Catálogos ── */
const labData = {
  GEOMS: C.GEOMS, BASES: C.BASES, BASE_GROUPS: C.BASE_GROUPS, INLAYS: C.INLAYS, HUMAN: C.HUMAN, CLAWS: C.CLAWS,
  CLAW_GROUPS: C.CLAW_GROUPS, PAINT_LAYERS: C.PAINT_LAYERS, CAR_BODIES: C.CAR_BODIES, SKIN_LAYERS: C.SKIN_LAYERS,
  TARGETS: C.TARGETS, TYPES: C.TYPES, MODEL: C.MODEL, HV_MPA: C.HV_MPA, FMIN: C.FMIN, FMAX: C.FMAX, C: C.C,
  MATERIAL_LOOK: C.MATERIAL_LOOK, SKIN_LAYER_LOOK: C.SKIN_LAYER_LOOK, PAINT_LAYER_LOOK: C.PAINT_LAYER_LOOK,
  BODY_LOOK: C.BODY_LOOK, CAR_SECTION: C.CAR_SECTION, SKIN_SECTION: C.SKIN_SECTION, BADGES: C.BADGES,
  BADGE_RUNS: C.BADGE_RUNS, FUNDAMENTOS: C.FUNDAMENTOS, FUNDAMENTOS_NOTE: C.FUNDAMENTOS_NOTE, APP_VERSION: C.APP_VERSION,
  LICENSE_NOTE: C.LICENSE_NOTE, DUEL_DEFAULT: C.DUEL_DEFAULT, DUEL_MODES: C.DUEL_MODES,
  DUEL_CARS: C.DUEL_CARS.map((t) => t.id), RUN_MS: C.RUN_MS, LOG_SIZE: C.LOG_SIZE,
  LAB_DEFAULTS: Object.fromEntries(Object.entries(C.LAB_DEFAULTS).map(([k, v]) => [k, v && typeof v === "object" ? v.id : v])),
  SFX_IDS: C.SFX_IDS, SFX_RATE: C.SFX_RATE,
  // valores derivados que la interfaz pinta y que dependen solo de los catálogos
  carLayers: Object.fromEntries(C.TARGETS.filter((t) => t.body).map((t) => [t.id, C.carLayers(t)])),
  targetSub: Object.fromEntries(C.TARGETS.map((t) => [t.id, C.targetSub(t)])),
  clawTitle: Object.fromEntries(C.CLAWS.map((c) => [c.id, C.clawTitle(c)])),
  maxForceHint: [null, ...C.CLAWS].map((c) => ({ claw: idOf(c), ...C.maxForceHint(c) })),
  nailSwatch: Object.fromEntries(C.BASES.map((b) => [b.id, C.nailSwatch(b.id)])),
};

/* ── Un ensayo completo: resultado y todo lo que la interfaz saca de él ── */
function trial(p) {
  const tool = {
    geom: byId(C.GEOMS, p.geom), base: byId(C.BASES, p.base), inlay: byId(C.INLAYS, p.inlay),
    claw: p.claw ? byId(C.CLAWS, p.claw) : null,
  };
  const target = byId(C.TARGETS, p.target), type = byId(C.TYPES, p.type);
  const result = C.compute({ ...tool, target, type, force: p.force, length: p.length, tear: p.tear, method: p.method,
    strike: p.strike, passes: p.passes, wet: p.wet });
  const out = { params: p, result, sfx: C.sfxForResult(result, target), toolLabel: C.toolLabel({ ...tool, res: result }) };
  if (target.body || target.pane || target.thickness) out.damage = C.damageReport(result, target, { length: p.length });
  if (target.body) out.damageStage = C.damageStage(result);
  return out;
}
const norm = (p) => ({
  geom: p.geom || "almendra", base: p.base || "natural", inlay: p.inlay || "none", target: p.target, force: p.force,
  length: p.length ?? 25, type: p.type || "aranazo", claw: p.claw || null, tear: !!p.tear, method: p.method || "rayado",
  strike: !!p.strike, passes: p.passes ?? 1, wet: !!p.wet,
});

/* ── Golden: los 40 escenarios de scripts/scenarios.js, con todas las salidas ── */
let badges = new Set();
const golden = SCENARIOS.map(([name, raw], i) => {
  const p = norm(raw), t = trial(p);
  const r = runScenario(raw);
  if (JSON.stringify(r) !== JSON.stringify(t.result)) throw new Error(`el escenario «${name}» no coincide con runScenario`);
  // logros acumulados a lo largo de la serie de escenarios (earnBadges devuelve un conjunto nuevo)
  const ctx = { res: r, target: byId(C.TARGETS, p.target), inlay: byId(C.INLAYS, p.inlay), claw: p.claw ? byId(C.CLAWS, p.claw) : null,
    method: p.method, strike: p.strike, runs: i + 1 };
  badges = C.earnBadges(badges, ctx);
  return { name, ...t, badgesAfter: [...badges] };
});

/* ── Muestra del barrido de audit.js (mismos bucles, uno de cada STRIDE) ── */
const METHODS = [
  { method: "rayado", strike: false, tear: false },
  { method: "rayado", strike: false, tear: true },
  { method: "puncion", strike: false, tear: false },
  { method: "puncion", strike: true, tear: false },
];
const FORCES = [0.5, 4, 30, 300, 2000];
const STRIDE = 31;
const tools = [
  ...C.GEOMS.flatMap((geom) => C.BASES.flatMap((base) => C.INLAYS.map((inlay) => ({ geom, base, inlay, claw: null })))),
  ...C.CLAWS.flatMap((claw) => C.INLAYS.map((inlay) => ({ geom: C.GEOMS[0], base: C.BASES[0], inlay, claw }))),
];
const sample = [], clawSpecs = [];
let idx = 0;
for (const tool of tools) {
  for (const wet of [false, true]) {
    if (tool.claw) clawSpecs.push({ claw: tool.claw.id, inlay: tool.inlay.id, wet, spec: C.clawSpec(tool.claw, tool.inlay, C.resolveTool({ ...tool, wet })) });
    for (const target of C.TARGETS) for (const m of METHODS) {
      if (m.tear && !tool.claw) continue;
      for (const force of FORCES) for (const passes of m.method === "rayado" ? [1, 20] : [1]) {
        if (idx++ % STRIDE !== 0) continue;
        sample.push(trial({ geom: tool.geom.id, base: tool.base.id, inlay: tool.inlay.id, target: target.id, force, length: 25,
          type: C.TYPES[1].id, claw: idOf(tool.claw), passes, wet, ...m }));
      }
    }
  }
}
// resolveTool de todas las herramientas (seca y húmeda): la ficha que pinta la interfaz
const resolved = tools.flatMap((t) => [false, true].map((wet) => ({ geom: t.geom.id, base: t.base.id, inlay: t.inlay.id, claw: idOf(t.claw), wet,
  tool: C.resolveTool({ ...t, wet }) })));
// Modo dual: garras naturales, de acero y de diamante contra cada pareja de coches (uno de cada 3)
const duels = [];
let d = 0;
for (const tool of tools.filter((t) => t.claw && ["none", "acero", "diamante"].includes(t.inlay.id))) {
  const params = { geom: tool.geom, base: tool.base, inlay: tool.inlay, force: tool.claw.force, length: 25, type: C.TYPES[1], passes: 1, wet: false };
  for (const a of C.DUEL_CARS) for (const b of C.DUEL_CARS) {
    if (d++ % 3 !== 0) continue;
    for (const row of C.duel(params, tool.claw, [a, b])) {
      duels.push({ claw: tool.claw.id, inlay: tool.inlay.id, cars: [a.id, b.id], row: row.id, res: row.res,
        verdict: C.duelVerdict(row.res[0], row.res[1], [a, b]),
        lens: row.res.map((r) => ({ depth: C.fmtLen(r.depthUm), groove: C.fmtLen(r.grooveWidthUm) })) });
    }
  }
}

/* ── Semántica numérica de JavaScript (la que tiene que imitar core/shared/js.gd) ── */
const R = C.rng(20260925);
const xs = [0, -0, 0.5, 1.5, 2.5, 3.5, -0.5, -1.5, -2.5, 0.125, 0.375, 0.625, 1.005, 1.255, 2.675, 0.045, 0.005, 0.015, 12.5, 7.5,
  99.95, 999.5, 0.05, 0.25, 0.35, 0.45, 1e-7, 3e-10, 1.5e-6, 123.456, 0.1 + 0.2, 1 / 3, 2 / 3, 1e15 + 0.3, 2 ** 52 + 0.5,
  1e20, 1e21, 1.5e21, -1e-7, -123.456, 9.995, 19.995, 0.9999999999999999, 1.0000000000000002, 4.35, 8.675, 1234.5678];
for (let k = -8; k <= 8; k++) for (let j = 0; j < 12; j++) { const v = R() * 10 ** k; xs.push(v, -v, Math.round(v * 1000) / 1000, Math.round(v * 2) / 2); }
const pos = xs.filter((x) => x > 0);
const jsSem = {
  toFixed: xs.flatMap((x) => [0, 1, 2, 3].map((dg) => [x, dg, x.toFixed(dg)])),
  round: xs.map((x) => [x, Math.round(x)]),
  str: xs.map((x) => [x, String(x)]),
  log10: pos.map((x) => [x, Math.log10(x)]),
  log1p: pos.map((x) => [x, Math.log1p(x)]),
  cbrt: xs.map((x) => [x, Math.cbrt(x)]),
  atan2: xs.slice(0, 60).map((y, i) => { const x = xs[(i * 7 + 3) % xs.length]; return [y, x, Math.atan2(y, x)]; }),
  pow: pos.slice(0, 60).map((x, i) => { const e = [0.4, 1 / 3, 2, 0.26, -0.26, 1.5][i % 6]; return [x, e, Math.pow(x, e)]; }),
  imul: Array.from({ length: 64 }, () => { const a = Math.floor(R() * 2 ** 32), b = Math.floor(R() * 2 ** 32); return [a, b, Math.imul(a, b)]; }),
  hex2: [0, 5, 15, 16, 127, 128, 200, 255].map((n) => [n, n.toString(16).padStart(2, "0")]),
  mixColor: [["#FF0000", "#0000FF", 0.5], ["#170E1C", "#FFFFFF", 0.25], ["#EFC3A6", "#000000", 0.33], ["#123456", "#ABCDEF", 0.999]].map(([a, b, t]) => [a, b, t, C.mix(a, b, t)]),
};

/* ── Math.exp, log, sin, cos, tan y pow de V8 en los valores que usa la física del laboratorio ──
   core/shared/v8_math.gd tiene que dar exactamente lo mismo, al bit (tests/shared/test_v8_math.gd): así la física no
   depende de la libm de cada plataforma. Con su propio aleatorio, para no mover los vectores de arriba. */
const R2 = C.rng(20260926);
const DEG = Math.PI / 180;
const alphas = [...new Set([...C.GEOMS, ...C.INLAYS.filter((i) => i.alpha), ...C.CLAWS].map((x) => x.alpha))];
const LN2 = Math.LN2;
Object.assign(jsSem, {
  // la punta esfero-cónica (tipGeometry): sin, cos y tan del semiángulo de cada herramienta, y otros
  trig: [...alphas.map((a) => a * DEG), ...Array.from({ length: 181 }, (_, i) => i * 0.5 * DEG), 0, -0, 1e-9, Math.PI / 4,
    Math.PI / 2, Math.PI, 3, 10, 100, 1e5, -2.5, ...Array.from({ length: 60 }, () => (R2() - 0.5) * 20)]
    .map((x) => [x, Math.sin(x), Math.cos(x), Math.tan(x)]),
  // la laca de la puerta (exp(−a/t) con t = 30 µm), casos especiales y valores al azar
  exp: [0, -0, 1, -1, 0.5, -0.5, LN2 / 2, -LN2 / 2, 1.5 * LN2, -1.5 * LN2, 2 ** -28, -(2 ** -29), 1e-300, 709.7, 709.78, 710,
    -745, -745.2, -800, 1000, 50, -50, 20.5, -20.5, Infinity, -Infinity, NaN,
    ...Array.from({ length: 200 }, (_, i) => -(i * 0.025) / 0.03), ...Array.from({ length: 150 }, () => (R2() - 0.5) * 1400),
    ...Array.from({ length: 100 }, () => (R2() - 0.5) * 4)].map((x) => [x, Math.exp(x)]),
  // la severidad de la piel (log(1 + µm)), la hoja de vidrio (log(a/r0')), casos especiales y valores al azar
  log: [1, 2, 0.5, Math.E, 10, 1e-300, 5e-324, 1e300, 1.0000000001, 0.9999999999, 0, -1, Infinity, NaN,
    ...Array.from({ length: 150 }, (_, i) => 1 + i * 250), ...Array.from({ length: 100 }, () => 10 ** ((R2() - 0.5) * 40)),
    ...Array.from({ length: 50 }, () => 300 / (0.2 + R2() * 4))].map((x) => [x, Math.log(x)]),
  // pasadas (n^0,4), pétalos ((l/t)^0,4), t³ de la hoja, el deslizador (10^x en N y en mN) y solveEnergy
  powPhysics: [...Array.from({ length: 100 }, (_, i) => [i + 1, 0.4]), ...Array.from({ length: 100 }, () => [R2() * 30, 0.4]),
    ...[4, 3, 2.5, 1.5, 0.7, 12.3456].map((t) => [t, 3]),
    ...Array.from({ length: 101 }, (_, i) => [10, Math.log10(0.5) + (i / 100) * (Math.log10(2000) - Math.log10(0.5))]),
    ...Array.from({ length: 101 }, (_, i) => [10, Math.log10(1 / 100000) + (i / 100) * (Math.log10(1) - Math.log10(1 / 100000))]),
    ...Array.from({ length: 301 }, (_, i) => [400 / 1e-5, i / 300])].map(([x, y]) => [x, y, Math.pow(x, y)]),
});

/* ── Capa física compartida (core/shared/contact.gd y abrasion.gd): vectores de prueba ── */
// Resistencias de prueba: las mismas funciones están escritas en godot/tests/shared/test_contact.gd.
const RES = {
  suave: (h) => 1500 * h * h,
  capas: (h) => (h < 0.3 ? 2000 * h : 400 * (h - 0.3) + 50),
  pared: (h) => (h < 0.2 ? 800 * h : Infinity),
};
// Copia congelada del modo de abrasión que está escrito dentro de solidResult (physics.js, líneas 517-532).
function abrasionModeFrozen(Dp) {
  let absMode, fab;
  const muPlough = C.clamp(0.9 * Dp, 0, 1.2);
  if (Dp < 0.1) { absMode = "arado"; fab = C.clamp(Dp / 0.1 * 0.15, 0.02, 0.15); }
  else if (Dp < 0.2) { absMode = "cuña"; fab = C.clamp(0.15 + (Dp - 0.1) / 0.1 * 0.45, 0.15, 0.6); }
  else { absMode = "corte"; fab = C.clamp(0.6 + (Dp - 0.2) * 2, 0.6, 1); }
  return { absMode, fab, muPlough };
}
const tipsIn = [
  ...C.GEOMS.map((g) => [g.area, g.alpha, Infinity]), ...C.INLAYS.filter((i) => i.area).map((i) => [i.area, i.alpha, Infinity]),
  ...C.CLAWS.map((c) => [c.area, c.alpha, c.reach * 0.15]),
];
const hs = [0, 1e-6, 1e-4, 0.001, 0.01, 0.03, 0.1, 0.25, 0.5, 1, 2.5, 7, 20];
const shared = {
  tips: tipsIn.map(([area, alpha, amax]) => {
    const tip = C.tipGeometry(area, alpha, amax);
    return { area, alpha, amax, tip, contact: hs.map((h) => C.contactRadius(tip, h)), hole: hs.map((h) => C.holeRadius(tip, h)),
      depth: hs.map((a) => C.depthForRadius(tip, a)) };
  }),
  hs,
  hardness: Array.from({ length: 301 }, (_, i) => [i / 100, C.hardnessEfficiency(i / 100)]),
  plastic: [0.5, 4, 30, 300, 2000].flatMap((F) => [0.05, 0.3, 1.2].flatMap((R) => [[2.9, 70], [210, 0.005], [1050, 400], [4, 4]].map(([Et, Eo]) =>
    [F, R, Et, Eo, 400 * 9.807, 1.2, C.plasticFraction(F, R, Et, Eo, 400 * 9.807, 1.2)]))),
  solve: Object.keys(RES).flatMap((name) => [0, 0.5, 5, 40, 300, 2000, 1e6].map((F) => ({
    name, F, static: C.solveStatic(F, RES[name]), layered: C.solveLayered(F, RES[name], [0.3]),
    energy: [0, 1, 10, 100, 1e4].map((E) => C.solveEnergy(E, F, RES[name])),
  }))),
  abrasion: [...Array.from({ length: 2501 }, (_, i) => i / 500), 0.1 - 1e-12, 0.1 + 1e-12, 0.2 - 1e-12, 0.2 + 1e-12, 0.09999999999999999]
    .map((Dp) => [Dp, abrasionModeFrozen(Dp)]),
  HV_MPA: C.HV_MPA,
  MODEL_CONTACT: { rOff: C.MODEL.rOff, rFull: C.MODEL.rFull, tabor: C.MODEL.tabor, yieldOnset: C.MODEL.yieldOnset, nu: C.MODEL.nu },
};

/* ── Aleatorio determinista de art.js ── */
const rngFx = {
  seedOf: ["", "a", "sfx:tap", "madera:300x60", "coche:28x20", "uña", "pane", "claw:oso", "Garra de águila"].map((s) => [s, C.seedOf(s)]),
  sequences: [0, 1, 42, 2 ** 31, 2 ** 32 - 1, C.seedOf("madera:300x60")].map((seed) => { const g = C.rng(seed); return [seed, Array.from({ length: 16 }, () => g())]; }),
};

/* ── Efectos de sonido: los WAV del laboratorio se reutilizan tal cual ── */
const sfxDir = new URL("apps/mobile/assets/sfx/", ROOT);
const sfx = {
  ids: C.SFX_IDS, rate: C.SFX_RATE,
  sha256: Object.fromEntries(readdirSync(sfxDir).filter((f) => f.endsWith(".wav")).sort()
    .map((f) => [f.replace(/\.wav$/, ""), createHash("sha256").update(readFileSync(new URL(f, sfxDir))).digest("hex")])),
};

/* ── Ilustraciones: SVG canónico de una batería de llamadas ── */
const art = [];
const addArt = (fn, args, view, make) => {
  const a = make();
  const data = Array.isArray(a) ? {} : Object.fromEntries(Object.entries(a).filter(([k]) => !["defs", "body", "lines", "extras"].includes(k)));
  art.push({ id: `${fn}#${art.length}`, fn, args, ...view, svg: sceneToSvg(a, view), data });
};
for (const id of Object.keys(C.MATERIAL_LOOK)) {
  for (const [w, hh, detail, rx] of [[300, 60, 1, 0], [28, 20, 0.5, 0], [120, 34, 0.7, 7]]) {
    addArt("surfaceArt", { lookId: id, w, h: hh, detail, rx, uid: "s" }, { viewBox: `0 0 ${w} ${hh}`, width: w, height: hh },
      () => C.surfaceArt(id, { w, h: hh, detail, rx, uid: "s" }));
  }
}
for (const g of C.GEOMS) for (const b of C.BASES) {
  addArt("nailArt", { geom: g.id, base: b.id, inlay: "none", wet: false, uid: "nf" }, { viewBox: "0 0 100 168", width: 100, height: 168 },
    () => C.nailArt({ geom: g, base: b, inlay: C.INLAYS[0], wet: false, uid: "nf" }));
}
for (const [i, inlay] of C.INLAYS.entries()) {
  const g = C.GEOMS[i % C.GEOMS.length], b = C.BASES[(i * 3) % C.BASES.length];
  addArt("nailArt", { geom: g.id, base: b.id, inlay: inlay.id, wet: i % 2 === 1, uid: "nf" }, { viewBox: "0 0 100 168", width: 100, height: 168 },
    () => C.nailArt({ geom: g, base: b, inlay, wet: i % 2 === 1, uid: "nf" }));
  addArt("nailSideArt", { geom: g.id, base: b.id, inlay: inlay.id, wet: i % 2 === 0, uid: "ns" }, { viewBox: "-122 -80 132 98", width: 132, height: 98 },
    () => C.nailSideArt({ geom: g, base: b, inlay, wet: i % 2 === 0, uid: "ns" }));
  if (inlay.id !== "none") addArt("gemArt", { inlay: inlay.id, cx: 10, cy: 10, r: 8, uid: "gi" }, { viewBox: "0 0 20 20", width: 20, height: 20 },
    () => C.gemArt(inlay, 10, 10, 8, "gi"));
}
for (const c of C.CLAWS) for (const orient of ["up", "down"]) for (const inl of ["none", "acero", "diamante"]) {
  const inlay = inl === "none" ? null : byId(C.INLAYS, inl);
  addArt("clawArt", { claw: c.id, inlay: inl === "none" ? null : inl, orient, uid: "ci", tipColor: null, drop: false }, { viewBox: "0 0 100 132", width: 100, height: 132 },
    () => C.clawArt(c, { inlay, orient, uid: "ci" }));
}
// Surcos, huellas y cortes con resultados reales: rayado y punción, fuerza baja y alta, uña y garra
for (const t of C.TARGETS) {
  const runs = [
    norm({ target: t.id, force: 4 }), norm({ target: t.id, force: 300, claw: "oso" }),
    norm({ target: t.id, force: 30, method: "puncion" }), norm({ target: t.id, force: 500, claw: "casuario", method: "puncion", strike: true }),
  ];
  for (const p of runs) {
    const { result } = trial(p);
    if (p.method === "rayado") {
      addArt("grooveArt", { targetId: t.id, res: result, x1: 14, x2: 286, y: 30, uid: "gv" }, { viewBox: "0 0 300 60", width: 300, height: 60 },
        () => C.grooveArt(t.id, result, { x1: 14, x2: 286, y: 30, uid: "gv" }));
    } else {
      addArt("punctureArt", { targetId: t.id, res: result, cx: 150, cy: 30, uid: "pc", fangs: p.claw === "vibora" }, { viewBox: "0 0 300 60", width: 300, height: 60 },
        () => C.punctureArt(t.id, result, { cx: 150, cy: 30, uid: "pc", fangs: p.claw === "vibora" }));
    }
    if (t.body) addArt("carSectionArt", { res: result, target: t.id, uid: "car" }, { viewBox: `0 0 ${C.CAR_SECTION.w} ${C.CAR_SECTION.h}`, width: C.CAR_SECTION.w, height: C.CAR_SECTION.h },
      () => C.carSectionArt(result, t, { uid: "car" }));
    if (t.skin) addArt("skinSectionArt", { res: result, uid: "sk" }, { viewBox: `0 0 ${C.SKIN_SECTION.w} ${C.SKIN_SECTION.h}`, width: C.SKIN_SECTION.w, height: C.SKIN_SECTION.h },
      () => C.skinSectionArt(result, { uid: "sk" }));
  }
}
for (const [x, y, w, hh, seed] of [[0, 0, 300, 60, "pane"], [10, 5, 200, 50, "ventana"], [0, 0, 120, 120, "p3"]]) {
  addArt("paneFractureArt", { x, y, w, h: hh, seed }, { viewBox: `0 0 ${x + w} ${y + hh}`, width: x + w, height: y + hh },
    () => C.paneFractureArt({ x, y, w, h: hh, seed }));
}

/* ── Escritura ── */
const files = [
  write(OUT, "lab-data.json", labData),
  write(OUT, "lab-golden.json", golden),
  write(OUT, "js-semantics.json", jsSem, exact),
  write(OUT, "rng.json", rngFx, exact),
  write(OUT, "shared.json", shared, exact),
  write(OUT, "sfx.json", sfx),
  write(GEN, "lab-sample.json", { stride: STRIDE, trials: sample, clawSpecs, resolved, duels }),
  write(GEN, "art-svg.json", art, exact),
];
// Sello: si cambia el motor o este script, el envoltorio de tests vuelve a generar los datos
const srcDir = new URL("packages/core/src/", ROOT);
const stamp = createHash("sha256");
for (const f of readdirSync(srcDir).sort()) stamp.update(readFileSync(new URL(f, srcDir)));
stamp.update(readFileSync(new URL(import.meta.url)));
writeFileSync(new URL(".stamp", GEN), stamp.digest("hex") + "\n");
console.log(`Oráculo exportado: ${files.join(", ")} (${golden.length} escenarios, ${sample.length} ensayos de muestra, ${duels.length} filas del modo dual, ${art.length} dibujos)`);
