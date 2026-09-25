/* Tests del motor. Se ejecutan con `npm test` (node:test, sin dependencias).
   Tres capas: integridad de datos · invariantes físicas · regresión (golden). */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  GEOMS, BASES, INLAYS, CLAWS, CLAW_GROUPS, TARGETS, TYPES, PAINT_LAYERS, HUMAN,
  compute, FMIN, FMAX, fToT, tToF, HV_MPA, MODEL, SKIN_LAYERS,
  tipGeometry, contactRadius, depthForRadius, plasticFraction, hardnessEfficiency,
  BADGES, BADGE_RUNS, earnBadges, toolLabel, maxForceHint, clawSpec, resolveTool, LICENSE_NOTE, APP_VERSION,
  carLayers, sheetOf, petalEnergy, paneBreak, CAR_BODIES, fmtDepth, fmtP,
  duel, duelVerdict, damageReport, damageStage, fmtLen, DUEL_CARS, DUEL_DEFAULT, DUEL_MODES, targetSub,
} from "../src/index.js";
import { SCENARIOS, runScenario, snapshot } from "../scripts/scenarios.js";

const base = (over = {}) => ({
  geom: GEOMS.find((g) => g.id === "almendra"), base: BASES.find((b) => b.id === "natural"),
  inlay: INLAYS.find((i) => i.id === "none"), target: TARGETS.find((t) => t.id === "coche"),
  force: 4, length: 25, type: TYPES.find((t) => t.id === "aranazo"), claw: null,
  tear: false, method: "rayado", strike: false, passes: 1, wet: false, ...over,
});
const T = (id) => TARGETS.find((t) => t.id === id);
const K = (id) => CLAWS.find((c) => c.id === id);
const I = (id) => INLAYS.find((i) => i.id === id);
const G = (id) => GEOMS.find((g) => g.id === id);
const logGrid = (a, b, n) => Array.from({ length: n }, (_, i) => a * Math.pow(b / a, i / (n - 1)));
const solids = TARGETS.filter((t) => !t.skin && !t.paint && !t.woodDoor);
// Todas las puntas del banco: formas de uña × bases, gemas sobre uña y garras (con y sin tungsteno)
const ALL_TOOLS = [
  ...GEOMS.flatMap((g) => BASES.map((b) => ({ label: `uña ${g.id}/${b.id}`, geom: g, base: b }))),
  ...INLAYS.slice(1).map((i) => ({ label: `uña+${i.id}`, inlay: i })),
  ...CLAWS.map((c) => ({ label: c.id, claw: c })),
  ...CLAWS.map((c) => ({ label: `${c.id}+tungsteno`, claw: c, inlay: I("tungsteno") })),
];

describe("integridad de datos", () => {
  test("ids únicos en cada catálogo", () => {
    for (const [name, arr] of Object.entries({ GEOMS, BASES, INLAYS, CLAWS, TARGETS, TYPES, PAINT_LAYERS })) {
      const ids = arr.map((x) => x.id);
      assert.equal(new Set(ids).size, ids.length, `ids duplicados en ${name}`);
    }
  });
  test("cada garra/colmillo tiene campos físicos válidos", () => {
    for (const c of CLAWS) {
      assert.ok(CLAW_GROUPS.includes(c.group), `${c.id}: grupo desconocido "${c.group}"`);
      assert.ok(c.hv > 0 && c.area > 0 && c.mass > 0 && c.E > 0, `${c.id}: hv/area/mass/E deben ser > 0`);
      assert.ok(c.curve >= 0 && c.curve <= 1, `${c.id}: curve fuera de [0,1]`);
      assert.ok(c.alpha > 0 && c.alpha < 90, `${c.id}: semiángulo alpha fuera de (0°, 90°)`);
      assert.ok(c.reach > 0, `${c.id}: falta alcance (reach, mm)`);
      assert.ok(c.strike && c.strike.v > 0 && c.strike.m > 0, `${c.id}: falta golpe (strike.v, strike.m)`);
      assert.ok(c.strike.m < c.mass, `${c.id}: la masa efectiva del golpe no puede superar la del animal`);
      assert.ok(c.force >= FMIN && c.force <= FMAX, `${c.id}: fuerza ${c.force} N fuera del deslizador`);
      assert.ok(c.desc && c.desc.length > 20, `${c.id}: falta descripción`);
      if (c.fang) assert.ok(c.fBreak > c.force, `${c.id}: un colmillo debe aguantar su propia fuerza máxima`);
    }
  });
  test("formas, bases e incrustaciones tienen geometría y módulo", () => {
    for (const g of GEOMS) assert.ok(g.area > 0 && g.alpha > 0 && g.alpha < 90 && g.reach > 0, `${g.id}: geometría incompleta`);
    for (const b of BASES) assert.ok(b.hv > 0 && b.E > 0, `${b.id}: falta hv/E`);
    for (const i of INLAYS.slice(1)) assert.ok(i.hv > 0 && i.E > 0 && i.area > 0 && i.alpha > 0, `${i.id}: gema incompleta`);
    assert.ok(HUMAN.force >= FMIN && HUMAN.strike.v > 0 && HUMAN.strike.m > 0);
  });
  test("cada material tiene dato divulgativo, módulo y capas coherentes", () => {
    for (const t of TARGETS) {
      assert.ok(t.fact && t.fact.length > 20, `${t.id}: falta fact`);
      if (!t.skin) assert.ok(t.E > 0, `${t.id}: falta módulo E`);
      if (t.layers) {
        const { film, sub, kind } = t.layers;
        assert.ok(film.t > 0 && film.hv > 0 && sub.hv > 0, `${t.id}: capas incompletas`);
        if (kind === "hard-on-soft") assert.ok(film.hv > sub.hv, `${t.id}: "${kind}" no cuadra con las durezas`);
        else assert.equal(kind, "paint-on-body", `${t.id}: tipo de capas desconocido`);
      }
    }
    // la tabla de capas de pintura es contigua; debajo va la carrocería de cada coche
    for (let i = 1; i < PAINT_LAYERS.length; i++) assert.equal(PAINT_LAYERS[i].from, PAINT_LAYERS[i - 1].to);
    for (const t of TARGETS.filter((x) => x.paint)) {
      const L = carLayers(t), body = t.body;
      assert.equal(t.layers.film.t, PAINT_LAYERS.at(-1).to, `${t.id}: la pintura no acaba donde empieza la carrocería`);
      for (let i = 1; i < L.length; i++) assert.equal(L[i].from, L[i - 1].to, `${t.id}: capas no contiguas`);
      assert.ok(Math.abs(L.at(-1).to - t.thickness * 1000) < 1e-9, `${t.id}: el espesor total no cuadra con pintura + carrocería`);
      assert.ok(body.t > 0 && body.sigma0 > 0 && body.hv > 0 && body.E > 0, `${t.id}: carrocería incompleta`);
    }
    for (const t of TARGETS.filter((x) => sheetOf(x))) assert.ok(sheetOf(t).to > sheetOf(t).from, `${t.id}: chapa sin espesor`);
  });
  test("conversión fuerza↔deslizador es inversa (log)", () => {
    for (const f of [FMIN, 1, 4, 30, 500, FMAX]) assert.ok(Math.abs(tToF(fToT(f)) - f) / f < 1e-9);
  });
});

describe("geometría de contacto", () => {
  test("punta esfero-cónica: radio y profundidad son inversos y continuos en la tangencia", () => {
    for (const [area, alpha] of [[0.008, 17], [0.9, 40], [9, 75], [0.04, 50]]) {
      const tip = tipGeometry(area, alpha);
      for (const h of [1e-4, tip.ht * 0.5, tip.ht, tip.ht * 1.001, tip.ht * 3, 5]) {
        const a = contactRadius(tip, h);
        assert.ok(Math.abs(depthForRadius(tip, a) - h) < 1e-9, `inversa rota en h=${h}`);
      }
      const eps = 1e-9;
      assert.ok(Math.abs(contactRadius(tip, tip.ht - eps) - contactRadius(tip, tip.ht + eps)) < 1e-6, "salto en la tangencia");
    }
  });
  test("Hertz: la fracción plástica crece con la fuerza y una punta roma plastifica más tarde", () => {
    const H = 20 * HV_MPA;
    let prev = -1;
    for (const F of logGrid(0.01, 1000, 60)) {
      const { phi } = plasticFraction(F, 0.5, 2.9, 3.2, H);
      assert.ok(phi >= prev - 1e-12, "φ baja al subir la fuerza"); prev = phi;
    }
    assert.ok(plasticFraction(1, 0.1, 2.9, 3.2, H).phi > plasticFraction(1, 1.7, 2.9, 3.2, H).phi);
  });
  test("eficiencia por durezas: 0 bajo r=0,8 (cede la punta) y 1 desde r≈2", () => {
    assert.equal(hardnessEfficiency(0.79), 0);
    assert.equal(hardnessEfficiency(MODEL.rFull), 1);
    assert.ok(hardnessEfficiency(1.2) > 0 && hardnessEfficiency(1.2) < 1);
  });
});

describe("invariantes físicas", () => {
  test("presión nominal = F/A: a igual fuerza, la forma más fina da más presión", () => {
    const sorted = [...GEOMS].sort((a, b) => a.area - b.area);
    const p = sorted.map((g) => compute(base({ geom: g, force: 10 })).pNominal);
    for (let i = 1; i < p.length; i++) assert.ok(p[i - 1] >= p[i], `presión no decrece con el área (${sorted[i].id})`);
  });

  test("la presión real nunca supera la dureza de la punta ni la del material", () => {
    for (const t of ALL_TOOLS) for (const target of TARGETS) for (const method of ["rayado", "puncion"]) for (const force of [0.5, 30, FMAX]) {
      const r = compute(base({ ...t, target, force, method }));
      const cap = r.hvTool * HV_MPA * (1 + 1e-9);
      assert.ok(r.pressure <= cap, `${t.label}→${target.id}: ${r.pressure.toFixed(0)} MPa > dureza de la punta`);
      if (!target.skin) assert.ok(r.pressure <= r.tHV * HV_MPA * (1 + 1e-9), `${t.label}→${target.id}: presión > dureza del material`);
    }
  });

  test("regla de dureza: una punta claramente más blanda (r < 0,8) nunca raya ni perfora un sólido", () => {
    for (const c of CLAWS) for (const t of solids) {
      if (c.hv / t.hv >= 0.8) continue;
      for (const force of [1, 30, 500, FMAX]) for (const method of ["rayado", "puncion"]) {
        const r = compute(base({ claw: c, target: t, force, method, strike: method === "puncion" }));
        if (r.shattered) { assert.equal(r.depthUm < 1, true, `${c.id} parte ${t.id} pero además lo perfora`); continue; }   // flexión, no dureza
        assert.notEqual(r.scratched, true, `${c.id} (${c.hv} HV) daña ${t.id} (${t.hv} HV) a ${force} N (${method})`);
      }
    }
  });

  test("más fuerza nunca da un surco menos profundo (rayado)", () => {
    for (const tid of ["coche", "plastico", "cobre", "puertamadera", "madera"]) {
      for (const tool of [{ claw: K("gato") }, { claw: K("casuario") }, { inlay: I("diamante") }, { geom: G("cuadrada") }]) {
        let prev = -1;
        for (const force of logGrid(0.5, FMAX, 40)) {
          const d = compute(base({ ...tool, target: T(tid), force })).depthUm;
          assert.ok(d >= prev - 1e-9, `${tid}: profundidad baja al subir fuerza a ${force.toFixed(1)} N`);
          prev = d;
        }
      }
    }
  });

  test("a igual fuerza, la punta más afilada llega más hondo (misma base, mismo material)", () => {
    const sorted = [...GEOMS].sort((a, b) => a.area - b.area);
    for (const tid of ["coche", "plastico", "madera"]) {
      const d = sorted.map((g) => compute(base({ geom: g, force: 20, target: T(tid) })).depthUm);
      for (let i = 1; i < d.length; i++) assert.ok(d[i - 1] >= d[i] - 1e-9, `${tid}: ${sorted[i].id} más hondo que una forma más afilada`);
    }
  });

  test("regresión: la punción crece de forma continua, sin saltos de 0 a perforar", () => {
    // Bug real detectado por el usuario: umbral binario → 0,0 µm justo por debajo y tope justo por encima.
    // Se comprueba en TODAS las puntas del banco y todos los sólidos, en empuje y en impacto.
    // Los saltos físicos sí existen: pasar de la pintura a un plástico más blando o romper una chapa (la
    // punta "cae" al otro lado, como en la piel al llegar a la grasa). Se vigila todo lo anterior.
    const popAt = (t) => (t.body && t.body.hv < t.layers.film.hv ? t.layers.film.t : sheetOf(t) ? sheetOf(t).to * 1000 : Infinity);
    for (const t of ALL_TOOLS) for (const target of TARGETS.filter((x) => !x.skin)) for (const strike of [false, true]) {
      const d = logGrid(0.5, 200, 160).map((force) => compute(base({ ...t, target, force, method: "puncion", strike })).depthUm)
        .filter((um) => um < popAt(target) - 1e-6);
      for (let i = 1; i < d.length; i++) {
        // Con +4 % de fuerza, h ∝ √F crece ~2 % (hasta ~10 % al hundirse la laca en la madera).
        // Toleramos 15 % relativo (o 8 µm en arranque desde 0). El bug original saltaba de 0 a ~130 µm.
        const jump = d[i] - d[i - 1];
        const allowed = Math.max(8, 0.15 * d[i - 1]);
        assert.ok(jump <= allowed, `${t.label}→${target.id}${strike ? " (golpe)" : ""}: salto de ${jump.toFixed(1)} µm (máx ${allowed.toFixed(1)})`);
      }
    }
  });

  test("más pasadas nunca reducen el surco; y si no marca a 1 pasada, no marca a 100", () => {
    for (const t of TARGETS.filter((t) => !t.skin)) {
      const one = compute(base({ target: t, force: 20 }));
      const many = compute(base({ target: t, force: 20, passes: 100 }));
      assert.ok(many.depthUm >= one.depthUm - 1e-9, `${t.id}: 100 pasadas < 1 pasada`);
      if (one.ratio !== null && one.ratio < 0.8) assert.notEqual(many.scratched, true, `${t.id}: 100 pasadas rayan algo más duro`);
    }
  });

  test("un roce no desgasta más que un arañazo, ni un arañazo más que un surco profundo", () => {
    for (const t of ["coche", "plastico", "madera", "cobre"]) {
      const w = TYPES.map((ty) => compute(base({ target: T(t), force: 20, type: ty })).wearIdx);
      for (let i = 1; i < w.length; i++) assert.ok(w[i] >= w[i - 1], `${t}: desgaste ${w.join(" > ")}`);
    }
  });

  test("punción: nunca más hondo que la propia garra/colmillo (alcance)", () => {
    for (const c of CLAWS) for (const target of TARGETS) for (const strike of [false, true]) {
      const r = compute(base({ claw: c, target, force: FMAX, method: "puncion", strike }));
      assert.ok(r.depthUm <= c.reach * 1000 + 1e-6, `${c.id}→${target.id}: ${r.depthUm} µm > ${c.reach} mm`);
    }
  });

  test("rayando tampoco: ningún surco es más hondo que la garra o la uña libre, y entonces marca el tope", () => {
    for (const t of ALL_TOOLS) for (const target of TARGETS) for (const tear of [false, true]) for (const passes of [1, 100]) {
      const reach = t.claw ? t.claw.reach : (t.geom || G("almendra")).reach;
      const r = compute(base({ ...t, target, force: FMAX, tear, passes, type: TYPES[2] }));
      assert.ok(r.depthUm <= reach * 1000 + 1e-6, `${t.label}→${target.id}: surco de ${r.depthUm} µm > ${reach} mm`);
      if (r.depthUm >= reach * 1000 - 1e-6) assert.equal(r.fullReach, true, `${t.label}→${target.id}: llega al tope sin decirlo`);
    }
    // el caso que lo destapó: una garra de pájaro de 4 mm abría un surco de 9,5 mm en madera de pino a 300 N
    assert.equal(compute(base({ claw: K("pajaro"), target: T("madera"), force: 300 })).depthUm, K("pajaro").reach * 1000);
  });

  test("impacto: un golpe nunca penetra menos que el empuje estático con la misma fuerza", () => {
    for (const t of ALL_TOOLS) for (const target of TARGETS) for (const force of [1, 20, 300]) {
      const s = compute(base({ ...t, target, force, method: "puncion" }));
      const k = compute(base({ ...t, target, force, method: "puncion", strike: true }));
      assert.ok(k.depthUm >= s.depthUm - 1e-6 || k.toolBroken, `${t.label}→${target.id} a ${force} N: golpe ${k.depthUm} < estático ${s.depthUm}`);
    }
  });

  test("pintura: la queratina no puede cortar la chapa de acero (se queda en 110 µm)", () => {
    for (const c of CLAWS.filter((c) => !c.fang)) for (const tear of [false, true]) {
      const r = compute(base({ claw: c, force: FMAX, tear, passes: 100, type: TYPES.at(-1) }));
      assert.ok(r.depthUm <= 110 + 1e-6, `${c.id}: ${r.depthUm.toFixed(0)} µm atraviesa el acero`);
    }
    const dia = compute(base({ inlay: I("diamante"), force: 500 }));
    assert.ok(dia.depthUm > 110, "un diamante sí debe entrar en la chapa");
  });

  test("a igual fuerza, la daga del casuario llega más hondo que la uña roma del avestruz", () => {
    // En la pintura por debajo de la chapa (a partir de ~50 N las dos garras ya la exponen) y en ABS grueso.
    for (const [tid, force] of [["coche", 5], ["coche", 15], ["plastico", 50], ["plastico", 500]]) {
      const cas = compute(base({ claw: K("casuario"), target: T(tid), force }));
      const ost = compute(base({ claw: K("avestruz"), target: T(tid), force }));
      assert.ok(cas.depthUm > ost.depthUm, `${tid} a ${force} N: casuario ${cas.depthUm} ≤ avestruz ${ost.depthUm}`);
    }
  });

  test("puerta de roble: solo la patada del casuario (daga larga + energía) la atraviesa", () => {
    const through = CLAWS.filter((c) => compute(base({ claw: c, target: T("puertamadera"), force: c.force, method: "puncion", strike: true })).verdict === "ATRAVIESA LA PUERTA");
    assert.deepEqual(through.map((c) => c.id), ["casuario"]);
  });

  test("colmillos: aguantan ~30 N (Estrada 2026); con más carga contra algo duro, se rompen", () => {
    const r = compute(base({ claw: K("vibora"), target: T("vidrio"), force: 40, method: "puncion" }));
    assert.equal(r.toolBroken, true);
    const ok = compute(base({ claw: K("vibora"), target: T("piel"), force: 4, method: "puncion" }));
    assert.equal(ok.toolBroken, undefined, "en piel, a su fuerza máxima, no debe romperse");
  });

  test("uña húmeda: nunca raya más que seca (la queratina empapada se ablanda)", () => {
    for (const g of GEOMS) for (const t of TARGETS.filter((t) => !t.skin)) for (const force of [4, 30]) {
      const dry = compute(base({ geom: g, target: t, force }));
      const wet = compute(base({ geom: g, target: t, force, wet: true }));
      assert.ok(wet.depthUm <= dry.depthUm + 1e-9, `${g.id}→${t.id}: húmeda ${wet.depthUm} > seca ${dry.depthUm}`);
    }
    // el gel y el acrílico no son queratina: el agua no los cambia
    const acr = { base: BASES.find((b) => b.id === "acrilico"), force: 30 };
    assert.equal(compute(base({ ...acr, wet: true })).depthUm, compute(base(acr)).depthUm);
  });

  test("piel por capas: pila continua, sin huecos, y la dermis es la capa que más resiste (Knight 1975)", () => {
    for (let i = 0; i < SKIN_LAYERS.length; i++) {
      const l = SKIN_LAYERS[i];
      assert.ok(l.to > l.from && l.jT > 0 && l.jC > 0 && l.jC <= l.jT, `${l.id}: capa inválida`);
      if (i) assert.equal(l.from, SKIN_LAYERS[i - 1].to, `${l.id}: hueco o solape con la capa de arriba`);
    }
    const dermis = SKIN_LAYERS.find((l) => l.id === "dermis");
    for (const l of SKIN_LAYERS.filter((x) => ["grasa", "fascia", "musculo"].includes(x.id))) assert.ok(l.jC < dermis.jC && l.jT < dermis.jT, `${l.id} resiste más que la dermis`);
  });

  test("piel al rayar: más fuerza, más pasadas o un rayado más fuerte nunca dejan menos herida", () => {
    const tools = [{}, { geom: G("stiletto") }, { geom: G("cuadrada") }, ...CLAWS.map((c) => ({ claw: c })), ...CLAWS.filter((c) => c.curve > 0.5).map((c) => ({ claw: c, tear: true }))];
    for (const t of tools) {
      let prev = -1, prevSev = -1;
      for (const force of logGrid(FMIN, FMAX, 60)) {
        const r = compute(base({ ...t, target: T("piel"), force }));
        assert.ok(r.depthUm >= prev - 1e-9 && r.sev >= prevSev - 1e-9, `${t.claw ? t.claw.id : t.geom ? t.geom.id : "almendra"}${t.tear ? "+desgarro" : ""}: ${force.toFixed(1)} N da menos herida`);
        prev = r.depthUm; prevSev = r.sev;
      }
      let prevP = -1;
      for (const passes of [1, 2, 5, 20, 100]) { const d = compute(base({ ...t, target: T("piel"), force: 8, passes })).depthUm; assert.ok(d >= prevP - 1e-9, "más pasadas, menos herida"); prevP = d; }
      const [roce, aranazo, surco] = ["roce", "aranazo", "surco"].map((id) => compute(base({ ...t, target: T("piel"), force: 8, type: TYPES.find((x) => x.id === id) })).depthUm);
      assert.ok(roce <= aranazo + 1e-9 && aranazo <= surco + 1e-9, "roce ≤ arañazo ≤ surco");
    }
  });

  test("piel: desgarrar con una garra curva hiere más que arrastrarla", () => {
    for (const c of CLAWS) for (const force of [2, 15, 150]) {
      const drag = compute(base({ claw: c, target: T("piel"), force })), tear = compute(base({ claw: c, target: T("piel"), force, tear: true }));
      assert.ok(tear.depthUm >= drag.depthUm - 1e-9, `${c.id} ${force} N`);
    }
  });

  test("piel: en armonía con la punción, si una punta perfora empujando, arrastrándola también rompe la piel", () => {
    for (const t of [{}, { geom: G("stiletto") }, ...CLAWS.map((c) => ({ claw: c }))]) for (const force of logGrid(FMIN, 200, 30)) {
      const stab = compute(base({ ...t, target: T("piel"), force, method: "puncion" }));
      if (stab.pierces) assert.equal(compute(base({ ...t, target: T("piel"), force })).ruptures, true, `${t.claw ? t.claw.id : "uña"} ${force.toFixed(2)} N`);
    }
  });

  test("piel: todas las situaciones existen (sin marca, marca roja, rasguños, sangra, desgarro, laceración, punción)", () => {
    const v = (over) => compute(base({ target: T("piel"), ...over })).verdict;
    assert.equal(v({ geom: G("cuadrada"), force: 0.5 }), "SIN MARCA");
    assert.equal(v({ force: 1 }), "MARCA ROJA");
    assert.equal(v({ force: 4 }), "RASGUÑO BLANCO");                                          // rascarse: raya blanca
    assert.equal(v({ geom: G("cuadrada"), force: 30 }), "RASGUÑO BLANCO");                 // solo la capa córnea
    assert.equal(v({ force: 30 }), "RASGUÑOS");                                               // almendra: excoria la epidermis
    assert.equal(v({ force: 30, passes: 20 }), "RASGUÑOS QUE SANGRAN");                      // a fuerza de pasadas
    assert.equal(v({ claw: K("gato"), force: 3 }), "ARAÑAZO QUE SANGRA");
    assert.equal(v({ claw: K("gato"), force: 15, tear: true }), "DESGARRO PROFUNDO");
    assert.equal(v({ claw: K("tigre"), force: 260 }), "LACERACIÓN PROFUNDA");
    assert.equal(v({ claw: K("vibora"), force: 4, method: "puncion" }), "PUNCIÓN · INYECTA");
    assert.equal(v({ force: 30, method: "puncion" }), "NO PERFORA");
    // una uña humana roma nunca perfora ni desgarra piel sana con su fuerza máxima
    assert.ok(!compute(base({ geom: G("cuadrada"), target: T("piel"), force: HUMAN.force })).ruptures);
  });

  test("piel: una herida sangra solo si pasa la epidermis (no tiene vasos)", () => {
    const epi = SKIN_LAYERS.find((l) => l.id === "epidermis").to;
    for (const t of [{}, { geom: G("stiletto") }, ...CLAWS.map((c) => ({ claw: c }))]) for (const force of [1, 4, 15, 60]) for (const method of ["rayado", "puncion"]) {
      const r = compute(base({ ...t, target: T("piel"), force, method }));
      if (r.depthUm > epi) assert.ok(r.bleeds, `${r.verdict}: pasa la epidermis y no sangra`);
      if (r.depthUm < epi && r.depthUm > 0) assert.ok(!r.bleeds || r.verdict === "RASGUÑOS QUE SANGRAN", `${r.verdict}: sangra sin llegar a la dermis`);
    }
  });

  test("piel (punción): no perfora por debajo de la fuerza medida in vivo (Davis 2004) y sí por encima", () => {
    for (const c of CLAWS) {
      const { fPuncture } = compute(base({ claw: c, target: T("piel"), force: 1, method: "puncion" }));
      if (fPuncture > FMIN * 1.05) assert.equal(compute(base({ claw: c, target: T("piel"), force: fPuncture * 0.95, method: "puncion" })).pierces, false, `${c.id} perfora por debajo`);
      assert.equal(compute(base({ claw: c, target: T("piel"), force: Math.max(fPuncture * 1.05, FMIN), method: "puncion" })).pierces, true, `${c.id} no perfora por encima`);
    }
    // una uña almendra no perfora la piel empujando con la fuerza máxima humana
    assert.equal(compute(base({ target: T("piel"), force: HUMAN.force, method: "puncion" })).pierces, false);
  });

  test("solo los colmillos inyectan", () => {
    for (const c of CLAWS) {
      const r = compute(base({ claw: c, target: T("piel"), force: c.force, method: "puncion" }));
      assert.equal(!!r.inject, !!c.fang, `${c.id}: inject=${r.inject}`);
    }
  });

  test("contrato del resultado: todo lo que pintan las apps existe y es finito en todo el banco", () => {
    // Regresión: al rayar piel faltaba grooveWidthUm y el perfil de la huella tumbaba la interfaz.
    for (const t of ALL_TOOLS) for (const target of TARGETS) for (const [method, strike, tear] of [["rayado", false, false], ["rayado", false, true], ["puncion", false, false], ["puncion", true, false]])
      for (const force of [FMIN, 7, 150, FMAX]) {
        const r = compute(base({ ...t, target, force, method, strike, tear }));
        const where = `${t.label}→${target.id} ${method}${strike ? "+golpe" : ""}`;
        for (const k of ["depthUm", "pressure", "pNominal", "sev", "wearIdx", "Fadh_mN", "Ffric", "mu", "phi", "energyJ", "contactAreaMm2", "tipRadiusUm", "alphaDeg"])
          assert.ok(Number.isFinite(r[k]), `${where}: ${k}=${r[k]}`);
        for (const k of ["verdict", "vsub", "vcol", "cede"]) assert.equal(typeof r[k], "string", `${where}: ${k}`);
        // La piel no tiene dureza Vickers: ratio y χ son null (nunca undefined). La anchura de la herida sí se calcula.
        for (const k of ["ratio", "chi"]) {
          if (target.skin) assert.ok(r[k] === null, `${where}: ${k} debería ser null en la piel`);
          else assert.ok(Number.isFinite(r[k]) && r[k] >= 0, `${where}: ${k}=${r[k]}`);
        }
        assert.ok(Number.isFinite(r.grooveWidthUm) && r.grooveWidthUm >= 0, `${where}: grooveWidthUm=${r.grooveWidthUm}`);
        if (target.skin) assert.ok(r.depthUm === 0 ? r.layer === null : typeof r.layer === "string", `${where}: capa alcanzada`);
        if (!r.skin && !r.puncture && !r.paint) assert.ok(Number.isFinite(r.muEff), `${where}: muEff`);
        assert.ok(r.sev >= 0 && r.sev <= 1, `${where}: sev fuera de [0,1]`);
      }
  });
});

describe("uñas experimentales (maciza de otro material) y Stiletto XL", () => {
  const B = (id) => BASES.find((b) => b.id === id);
  const scratches = (geom, mat, target, force = HUMAN.force) => compute(base({ geom: G(geom), base: B(mat), target: T(target), force })).scratched;
  test("afilar nunca resta: cuadrada ≤ stiletto ≤ stiletto XL en profundidad (todas las bases, materiales, fuerzas y métodos)", () => {
    for (const b of BASES) for (const t of TARGETS) for (const force of [1, 5, 30, 200, 2000]) for (const method of ["rayado", "puncion"]) {
      const d = ["cuadrada", "stiletto", "stilettoxl"].map((g) => compute(base({ geom: G(g), base: b, target: t, force, method })).depthUm);
      assert.ok(d[0] <= d[1] + 1e-9 && d[1] <= d[2] + 1e-9, `${b.id}→${t.id} ${force} N ${method}: ${d.map((x) => x.toFixed(2))}`);
    }
  });
  test("acero macizo: raya plástico y cobre, nunca el vidrio; el titanio (más blando) no raya el acero inox.", () => {
    for (const g of GEOMS) {
      assert.equal(scratches(g.id, "metal", "plastico"), true, g.id);
      assert.equal(scratches(g.id, "metal", "cobre"), true, g.id);
      assert.equal(scratches(g.id, "metal", "vidrio"), false, g.id);
      assert.equal(scratches(g.id, "titanio", "acero"), false, g.id);
    }
  });
  test("zafiro y diamante macizos rayan el vidrio con punta fina; con punta roma el contacto se queda elástico (Hertz)", () => {
    for (const m of ["zafiro", "diamante"]) {
      assert.equal(scratches("stiletto", m, "vidrio"), true, `${m} stiletto`);
      assert.equal(scratches("stilettoxl", m, "cuarzo"), true, `${m} stiletto XL → cuarzo`);
      const blunt = compute(base({ geom: G("cuadrada"), base: B(m), target: T("vidrio"), force: HUMAN.force }));
      assert.equal(blunt.scratched, false, `${m} cuadrada`);
      assert.ok(blunt.phi < 0.5, `${m} cuadrada: φ = ${blunt.phi}`);
    }
    assert.equal(scratches("stilettoxl", "diamante", "zafiro"), true);
    assert.notEqual(scratches("stilettoxl", "zafiro", "diamante"), true, "el zafiro no raya el diamante");
  });
  test("solo la queratina se ablanda con agua: una uña maciza da lo mismo seca que húmeda", () => {
    for (const b of BASES.filter((x) => !x.keratin)) for (const t of solids) {
      const p = { base: b, target: t, force: 30 };
      assert.equal(compute(base({ ...p, wet: true })).depthUm, compute(base(p)).depthUm, `${b.id}→${t.id}`);
    }
  });
});

describe("coches, chapas finas y vidrio", () => {
  const CARS = TARGETS.filter((t) => t.paint);
  const METAL_CARS = CARS.filter((t) => t.body.metal);
  // Etapa de daño en punción: 0 nada · 1 pintura · 2 se clava en la carrocería · 3 la perfora · 4 la atraviesa
  const stage = (r) => (/^ATRAVIESA/.test(r.verdict) ? 4 : /^PERFORA (LA|EL)/.test(r.verdict) ? 3 : r.depthUm > 110 + 1 ? 2 : r.scratched ? 1 : 0);
  const HARD = [
    { label: "águila de acero", claw: K("aguila"), inlay: I("acero") }, { label: "águila de zafiro", claw: K("aguila"), inlay: I("zafiro") },
    { label: "tigre de tungsteno", claw: K("tigre"), inlay: I("tungsteno") }, { label: "oso de diamante", claw: K("oso"), inlay: I("diamante") },
    { label: "uña stiletto de metal", geom: G("stiletto"), base: BASES.find((b) => b.id === "metal") },
    { label: "uña stiletto XL + cuarzo", geom: G("stilettoxl"), inlay: I("cuarzo") },
  ];

  test("la queratina y la dentina no pasan de la pintura en un coche de metal; en la aleta de plástico, sí", () => {
    for (const c of CLAWS) for (const t of METAL_CARS) for (const [method, strike] of [["rayado", false], ["puncion", false], ["puncion", true]]) for (const force of [1, 30, 500, FMAX]) {
      const r = compute(base({ claw: c, target: t, force, method, strike }));
      assert.ok(r.depthUm <= 110 + 1e-6, `${c.id}→${t.id} ${method}${strike ? "+golpe" : ""} ${force} N: ${r.depthUm.toFixed(0)} µm en el metal`);
    }
    const bear = compute(base({ claw: K("oso"), target: T("cocheplastico"), force: 300, method: "puncion", strike: true }));
    assert.ok(stage(bear) >= 3, `el zarpazo de oso debería perforar la aleta de plástico (${bear.verdict})`);
  });

  test("etapas: más fuerza nunca retrocede de etapa ni de profundidad", () => {
    for (const t of HARD) for (const target of [...CARS, T("puertametal")]) {
      let prev = null;
      for (const force of logGrid(1, FMAX, 36)) {
        const r = compute(base({ ...t, target, force, method: "puncion" }));
        if (prev) {
          assert.ok(stage(r) >= stage(prev), `${t.label}→${target.id} ${force.toFixed(0)} N: de «${prev.verdict}» a «${r.verdict}»`);
          assert.ok(r.depthUm >= prev.depthUm - 1e-6, `${t.label}→${target.id} ${force.toFixed(0)} N: menos profundidad`);
        }
        prev = r;
      }
    }
  });

  test("el coche clásico (acero más grueso) nunca se perfora antes que el moderno", () => {
    // Ojo: su acero dulce es más BLANDO, así que una punta dura lo marca algo más hondo; lo que cuesta
    // más es perforarlo (hay más metal que romper y abrir en pétalos). Se comparan las etapas 3 y 4.
    const holed = (r) => (stage(r) >= 3 ? stage(r) : 0);
    for (const t of [...ALL_TOOLS, ...HARD]) for (const [method, strike] of [["puncion", false], ["puncion", true]]) for (const force of [20, 300, FMAX]) {
      const old = compute(base({ ...t, target: T("cocheclasico"), force, method, strike }));
      const now = compute(base({ ...t, target: T("coche"), force, method, strike }));
      assert.ok(holed(old) <= holed(now), `${t.label} ${force} N${strike ? " golpe" : ""}: clásico «${old.verdict}» peor que moderno «${now.verdict}»`);
      if (stage(old) === 4 && stage(now) === 4) assert.ok(old.workJ >= now.workJ - 1e-9, `${t.label}: el clásico absorbe menos energía (${old.workJ} < ${now.workJ})`);
    }
  });

  test("perforar es que la punta salga por detrás; atravesar, que la herramienta entera pase al otro lado", () => {
    for (const t of [...ALL_TOOLS, ...HARD]) for (const target of [...CARS, T("puertametal")]) for (const [method, strike] of [["rayado", false], ["puncion", false], ["puncion", true]]) for (const force of [30, FMAX]) {
      const r = compute(base({ ...t, target, force, method, strike }));
      const where = `${t.label}→${target.id} ${method}${strike ? "+golpe" : ""} ${force} N`;
      if (/^ATRAVIESA/.test(r.verdict)) assert.ok(r.through && r.fullReach, `${where}: atraviesa sin pasar entera`);
      if (/^PERFORA (LA|EL)/.test(r.verdict)) assert.ok(r.through && !r.fullReach, `${where}: perfora sin salir por detrás`);
      if (/^RAJA/.test(r.verdict)) assert.ok(r.through && !r.puncture, `${where}: raja sin cortar de lado a lado`);
      if (r.through && !r.toolBroken) assert.match(r.verdict, /^(ATRAVIESA|PERFORA|RAJA)/, `${where}: la atraviesa pero dice «${r.verdict}»`);
      assert.ok(Number.isFinite(r.workJ) && r.workJ >= 0, `${where}: workJ=${r.workJ}`);
    }
  });

  test("pétalos (Wierzbicki 1999): la energía crece con el agujero, el espesor y la resistencia del metal", () => {
    assert.equal(petalEnergy(0, 0.7, 264), 0);
    for (const l of [0.2, 1, 5, 20]) {
      assert.ok(petalEnergy(l * 1.1, 0.7, 264) > petalEnergy(l, 0.7, 264));
      assert.ok(petalEnergy(l, 0.9, 264) > petalEnergy(l, 0.7, 264));
      assert.ok(petalEnergy(l, 0.7, 300) > petalEnergy(l, 0.7, 264));
    }
    // ec. 58: con R/t > 5 el término principal es 3,37·σ0·t^1,6·D^1,4
    const t = 0.7, R = 5, E = petalEnergy(R, t, 264), main = 3.37 * 264 * t ** 1.6 * (2 * R) ** 1.4;
    assert.ok(E > main && E < main * 1.1, `ec. 57 vs 58: ${E.toFixed(0)} frente a ${main.toFixed(0)} mJ`);
  });

  test("vidrio: la hoja se parte por flexión (Roark), sin depender de la dureza de la punta", () => {
    const pane = T("vidrio").pane, pb = paneBreak(pane, T("vidrio").E, 0);
    assert.ok(paneBreak({ ...pane, t: 8 }, 72, 0).F > 3 * pb.F, "el doble de espesor debería aguantar ~4 veces más");
    for (const g of [G("cuadrada"), G("almendra")]) {
      const below = compute(base({ geom: g, target: T("vidrio"), force: pb.F * 0.9, method: "puncion" }));
      const above = compute(base({ geom: g, target: T("vidrio"), force: pb.F * 1.2, method: "puncion" }));
      assert.equal(below.shattered, false, `${g.id}: se parte por debajo de ${pb.F.toFixed(0)} N`);
      assert.equal(above.shattered, true, `${g.id}: no se parte por encima de ${pb.F.toFixed(0)} N`);
      assert.equal(above.verdict, "ROMPE EL VIDRIO");
    }
    const hit = (id) => compute(base({ claw: K(id), target: T("vidrio"), force: K(id).force, method: "puncion", strike: true }));
    assert.equal(hit("gato").shattered, false, "un zarpazo de gato no rompe una ventana");
    assert.equal(hit("oso").shattered, true, "un zarpazo de oso sí");
    for (const f of ["vibora", "gabon"]) assert.equal(hit(f).shattered, false, `${f}: el colmillo se rompe antes que el vidrio`);
  });

  test("garras reforjadas en acero o zafiro: cambia la dureza, no la forma", () => {
    for (const c of [K("aguila"), K("tigre"), K("vibora")]) for (const id of ["acero", "zafiro", "diamante"]) {
      const a = compute(base({ claw: c, target: T("madera"), force: 20 })), b = compute(base({ claw: c, inlay: I(id), target: T("madera"), force: 20 }));
      assert.equal(b.alphaDeg, a.alphaDeg, `${c.id} de ${id}: cambia el ángulo`);
      assert.equal(b.tipRadiusUm, a.tipRadiusUm, `${c.id} de ${id}: cambia la punta`);
      assert.equal(b.hvTool, I(id).hv, `${c.id} de ${id}: no tiene la dureza del material`);
    }
  });
});

describe("modo dual: el mismo ensayo en dos coches", () => {
  const cars = DUEL_DEFAULT.map(T);
  const p = (over) => base({ target: cars[0], force: 30, ...over });
  test("la pareja por defecto es clásico vs moderno y solo hay coches en el duelo", () => {
    assert.deepEqual(DUEL_DEFAULT, ["cocheclasico", "coche"]);
    for (const t of DUEL_CARS) assert.ok(t.body && t.paint, `${t.id} no es un coche`);
    for (const t of DUEL_CARS) assert.match(targetSub(t), /^pintura \+ /, `${t.id}: ficha sin carrocería`);
  });
  test("cada manera de atacar se calcula en los dos coches (desgarrar solo con garra)", () => {
    const nail = duel(p(), null, cars), claw = duel(p({ claw: K("aguila") }), K("aguila"), cars);
    assert.deepEqual(nail.map((r) => r.id), ["rayado", "puncion", "golpe"]);
    assert.deepEqual(claw.map((r) => r.id), DUEL_MODES.map((m) => m.id));
    for (const row of claw) {
      assert.equal(row.res.length, 2);
      row.res.forEach((r, i) => assert.equal(r.tName, cars[i].name));
      assert.deepEqual(row.res[0], compute({ ...p({ claw: K("aguila") }), ...row.p, claw: K("aguila"), target: cars[0] }), "el duelo no debe hacer física propia");
    }
  });
  test("el veredicto del duelo cuadra con las etapas de daño y no se contradice al cambiar el orden", () => {
    for (const t of [...ALL_TOOLS.slice(0, 60), { label: "águila de acero", claw: K("aguila"), inlay: I("acero") }]) for (const pair of [DUEL_DEFAULT, ["coche", "cocheplastico"], ["cochealu", "cocheclasico"]]) {
      const cs = pair.map(T);
      for (const row of duel(p({ ...t }), t.claw || null, cs)) {
        const v = duelVerdict(row.res[0], row.res[1], cs), w = duelVerdict(row.res[1], row.res[0], [cs[1], cs[0]]);
        const [a, b] = row.res.map(damageStage);
        if (a !== b) assert.equal(v.winner, a < b ? 0 : 1, `${t.label} ${row.id}: gana el más dañado`);
        assert.equal(v.winner == null, w.winner == null, `${t.label} ${row.id}: el empate depende del orden`);
        if (v.winner != null) assert.equal(v.winner, 1 - w.winner, `${t.label} ${row.id}: cambia el ganador al darles la vuelta`);
      }
    }
  });
  test("informe de daños: profundidad siempre; agujero si perfora; energía solo en golpes; cm desde 1 cm", () => {
    const hit = compute(p({ claw: K("aguila"), inlay: I("acero"), method: "puncion", strike: true, target: T("coche") }));
    const rep = Object.fromEntries(damageReport(hit, T("coche"), { length: 25 }));
    assert.ok(rep.Profundidad && rep.Agujero && rep["Energía absorbida"], JSON.stringify(rep));
    const scratch = Object.fromEntries(damageReport(compute(p({ target: T("coche") })), T("coche"), { length: 25 }));
    assert.equal(scratch["Energía absorbida"], undefined, "rayar no reparte energía de golpe");
    assert.equal(fmtLen(35000), "35 mm (3.5 cm)");
    assert.equal(fmtLen(10500), "10.5 mm (1.1 cm)");
    assert.equal(fmtLen(110000), "110 mm (11.0 cm)");
    // mismo número de milímetros que fmtDepth, que es lo que dicen los veredictos
    for (let um = 10000; um < 100000; um += 37) assert.equal(fmtLen(um).split(" mm")[0], fmtDepth(um).split(" mm")[0].replace(/\.0$/, ""), `${um} µm`);
    assert.equal(fmtLen(6100), fmtDepth(6100));
    const bear = compute(p({ claw: K("oso"), force: 300, method: "puncion", strike: true, target: T("coche") }));
    assert.ok(Object.fromEntries(damageReport(bear, T("coche"))).El_resto === undefined && damageReport(bear, T("coche")).some(([k]) => k === "El resto"), "el golpe que no entra debe decir adónde va la energía");
  });
});

describe("laboratorio (logros y etiquetas compartidos)", () => {
  const ctx = (over) => ({ inlay: I("none"), claw: null, method: "rayado", strike: false, runs: 1, ...over });
  test("cada logro que se puede ganar existe en la lista", () => {
    const ids = new Set(BADGES.map((b) => b.id));
    const all = new Set();
    for (const t of TARGETS) for (const c of [null, ...CLAWS]) for (const [method, strike] of [["rayado", false], ["puncion", false], ["puncion", true]])
      for (const wet of [false, true]) for (const inlay of [I("none"), I("diamante")]) {
        const res = compute(base({ target: t, claw: c, method, strike, wet, inlay, force: c ? c.force : 30 }));
        for (const b of earnBadges(new Set(), ctx({ res, target: t, claw: c, method, strike, inlay, runs: BADGE_RUNS }))) all.add(b);
      }
    for (const b of all) assert.ok(ids.has(b), `logro sin definir: ${b}`);
    assert.deepEqual([...ids].filter((b) => !all.has(b)), [], "hay logros imposibles de conseguir");
  });
  test("earnBadges no muta el conjunto anterior", () => {
    const prev = new Set(["vidrio"]);
    const res = compute(base({ claw: K("gato"), target: T("piel"), force: 15 }));
    const next = earnBadges(prev, ctx({ res, target: T("piel"), claw: K("gato") }));
    assert.deepEqual([...prev], ["vidrio"]);
    assert.ok(next.has("piel") && next.has("depredador") && next.has("vidrio"));
  });
  test("etiqueta del cuaderno y botón de fuerza máxima", () => {
    const res = compute(base({ inlay: I("diamante"), wet: true }));
    assert.equal(toolLabel({ claw: null, geom: G("almendra"), inlay: I("diamante"), res }), "Almendra + Diamante");
    assert.equal(maxForceHint(null).force, HUMAN.force);
    assert.equal(maxForceHint(K("vibora")).force, K("vibora").force);
  });
  test("aviso de licencia: autor, MIT y la licencia de las tipografías empaquetadas", () => {
    assert.match(LICENSE_NOTE, /Eric Valls Gramunt/);
    assert.match(LICENSE_NOTE, /Licencia MIT/);
    assert.match(LICENSE_NOTE, /Open Font License/);
  });
  test("la versión del pie es la de todos los manifiestos (apps, instaladores y tiendas)", () => {
    const read = (f) => readFileSync(new URL(`../../../${f}`, import.meta.url), "utf8");
    const json = (f) => JSON.parse(read(f));
    const versions = {
      "package.json": json("package.json").version,
      "packages/core/package.json": json("packages/core/package.json").version,
      "apps/desktop/package.json": json("apps/desktop/package.json").version,
      "apps/desktop/src-tauri/tauri.conf.json": json("apps/desktop/src-tauri/tauri.conf.json").version,
      "apps/desktop/src-tauri/Cargo.toml": read("apps/desktop/src-tauri/Cargo.toml").match(/^version = "(.+)"$/m)?.[1],
      "apps/mobile/package.json": json("apps/mobile/package.json").version,
      "apps/mobile/app.json": json("apps/mobile/app.json").expo.version,
    };
    for (const [file, v] of Object.entries(versions)) assert.equal(v, APP_VERSION, file);
    assert.ok(LICENSE_NOTE.startsWith(`Scratch Tribology Simulator ${APP_VERSION} `));
  });
  test("la ficha de una garra muestra el material con el que calcula el motor", () => {
    const none = I("none"), spec = (c, inlay, wet = false) => clawSpec(c, inlay, resolveTool({ geom: G("almendra"), base: BASES[0], inlay, claw: c, wet }));
    assert.deepEqual(spec(K("aguila"), I("acero")), { title: "Garra de águila de acero", material: "acero", hardness: `${fmtP(I("acero").hv)} HV · Mohs ${I("acero").mohs}` });
    assert.equal(spec(K("aguila"), none).material, "queratina");
    const wet = spec(K("gato"), none, true);
    assert.equal(wet.material, "queratina húmeda");
    assert.equal(wet.hardness, `${fmtP(K("gato").hv * 0.2)} HV · Mohs ${K("gato").mohs}`);
    assert.equal(spec(K("vibora"), none).material, "dentina");
    assert.equal(spec(K("vibora"), I("zafiro")).title, "Colmillo de víbora de zafiro");
  });
});

describe("regresión (golden)", () => {
  const golden = JSON.parse(readFileSync(new URL("./golden.json", import.meta.url), "utf8"));
  for (const [name, params] of SCENARIOS) {
    test(name, () => assert.deepEqual(snapshot(runScenario(params)), golden[name],
      "Resultado distinto al de referencia. Si el cambio es intencionado: npm run golden:update y justifícalo en el PR."));
  }
});
