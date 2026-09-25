/* Barrido del catálogo completo: cada herramienta (formas de uña × bases × piedras, y garras × materiales
   de reforja) contra cada material, con cada método, fuerzas de 0,5 a 2000 N, seca y húmeda, y 1 o 20
   pasadas. Busca lo que un test puntual no ve: textos rotos (NaN, undefined…), números no finitos,
   profundidades negativas o más hondas que la herramienta, y fallos del informe de daños, el duelo y las
   etiquetas. Tarda unos 20 s. Uso: npm run audit (sale con código 1 si encuentra algo). */
import {
  GEOMS, BASES, INLAYS, CLAWS, TARGETS, TYPES, compute, damageReport, duel, duelVerdict, DUEL_CARS,
  toolLabel, clawSpec, resolveTool, fmtLen, targetSub, maxForceHint,
} from "../src/index.js";

const BAD = /NaN|undefined|Infinity|null|\[object/;
const TEXT = ["verdict", "vsub", "cede", "layer", "where"];
const NUM = ["depthUm", "pressure", "pNominal", "grooveWidthUm", "sev", "Fadh_mN", "wearIdx", "Ffric", "contactAreaMm2", "tipRadiusUm"];
const OPT = ["muEff", "ratio", "chi", "workJ", "paneN", "peakN", "energyJ", "fPuncture", "tearForce", "phi", "eta", "Dp"];
const METHODS = [
  { method: "rayado", strike: false, tear: false },
  { method: "rayado", strike: false, tear: true },
  { method: "puncion", strike: false, tear: false },
  { method: "puncion", strike: true, tear: false },
];
const FORCES = [0.5, 4, 30, 300, 2000];

const problems = new Map();
const note = (kind, ctx) => {
  if (!problems.has(kind)) problems.set(kind, { n: 0, ctx });
  problems.get(kind).n++;
};
const tools = [
  ...GEOMS.flatMap((geom) => BASES.flatMap((base) => INLAYS.map((inlay) => ({ geom, base, inlay, claw: null })))),
  ...CLAWS.flatMap((claw) => INLAYS.map((inlay) => ({ geom: GEOMS[0], base: BASES[0], inlay, claw }))),
];

const t0 = Date.now();
let runs = 0;
for (const tool of tools) {
  for (const wet of [false, true]) {
    if (tool.claw) {
      for (const [k, v] of Object.entries(clawSpec(tool.claw, tool.inlay, resolveTool({ ...tool, wet })))) {
        if (BAD.test(String(v))) note(`ficha de la garra (${k}): ${v}`, tool.claw.id);
      }
    }
    for (const target of TARGETS) for (const m of METHODS) {
      if (m.tear && !tool.claw) continue;
      for (const force of FORCES) for (const passes of m.method === "rayado" ? [1, 20] : [1]) {
        const who = tool.claw ? tool.claw.id : `${tool.geom.id}/${tool.base.id}`;
        const ctx = `${who}+${tool.inlay.id} → ${target.id} · ${m.method}${m.strike ? "+golpe" : ""}${m.tear ? "+desgarro" : ""} · ${force} N${wet ? " · húmeda" : ""}`;
        let r;
        try {
          r = compute({ ...tool, target, force, length: 25, type: TYPES[1], passes, wet, ...m });
        } catch (e) {
          note(`excepción: ${e.message}`, ctx);
          continue;
        }
        runs++;
        for (const k of TEXT) if (r[k] != null && BAD.test(String(r[k]))) note(`texto roto en ${k}`, `${ctx}: ${r[k]}`);
        for (const k of NUM) if (!Number.isFinite(r[k])) note(`${k} no es finito`, ctx);
        for (const k of OPT) if (typeof r[k] === "number" && !Number.isFinite(r[k])) note(`${k} no es finito`, ctx);
        if (r.depthUm < 0) note("profundidad negativa", ctx);
        if (r.sev < 0 || r.sev > 1) note("gravedad fuera de [0, 1]", ctx);
        if (r.depthUm > r.reachMm * 1000 + 1e-6) note("más hondo que la propia herramienta", ctx);
        if (r.depthUm >= r.reachMm * 1000 - 1e-6 && !r.fullReach && !r.toolBroken && !r.shattered) note("en el tope sin marcarlo", ctx);
        if (target.thickness && r.depthUm > target.thickness * 1000 + 1e-6 && !r.fullReach && !r.through) note("más hondo que el espesor sin atravesarlo", ctx);
        if (target.body || target.pane || target.thickness) {
          for (const [k, v] of damageReport(r, target, { length: 25 })) if (BAD.test(`${k} ${v}`)) note(`informe de daños roto (${k})`, `${ctx}: ${v}`);
        }
        const label = toolLabel({ claw: tool.claw, geom: tool.geom, inlay: tool.inlay, res: r });
        if (BAD.test(label)) note("etiqueta del cuaderno rota", `${ctx}: ${label}`);
      }
    }
  }
}
// Modo dual: cada garra (natural, de acero y de diamante) con cada pareja de coches
for (const tool of tools.filter((t) => t.claw && ["none", "acero", "diamante"].includes(t.inlay.id))) {
  const params = { geom: tool.geom, base: tool.base, inlay: tool.inlay, force: tool.claw.force, length: 25, type: TYPES[1], passes: 1, wet: false };
  for (const a of DUEL_CARS) for (const b of DUEL_CARS) {
    for (const row of duel(params, tool.claw, [a, b])) {
      runs += 2;
      const v = duelVerdict(row.res[0], row.res[1], [a, b]);
      const ctx = `${tool.claw.id}+${tool.inlay.id} · ${a.id} vs ${b.id} · ${row.id}`;
      if (BAD.test(v.text)) note("veredicto del duelo roto", `${ctx}: ${v.text}`);
      for (const r of row.res) if (BAD.test(fmtLen(r.depthUm)) || (r.through && BAD.test(fmtLen(r.grooveWidthUm)))) note("longitud del duelo rota", ctx);
    }
  }
}
for (const t of TARGETS) if (BAD.test(targetSub(t))) note("subtítulo del material roto", `${t.id}: ${targetSub(t)}`);
for (const c of [null, ...CLAWS]) {
  const hint = maxForceHint(c);
  if (!Number.isFinite(hint.force) || BAD.test(hint.label)) note("botón de fuerza máxima roto", c ? c.id : "mano");
}

console.log(`${runs.toLocaleString("es-ES")} ensayos en ${((Date.now() - t0) / 1000).toFixed(0)} s · ${problems.size} tipos de problema`);
for (const [kind, { n, ctx }] of problems) console.log(`  ${n}× ${kind}\n      p. ej. ${ctx}`);
if (problems.size) process.exit(1);
