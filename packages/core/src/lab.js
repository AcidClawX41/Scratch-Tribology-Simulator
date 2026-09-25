/* ════════ LAB ════════
   Lógica de laboratorio compartida por escritorio y móvil: logros, etiqueta del ensayo y textos de
   fundamentos. No es física, pero vive aquí para que las dos apps no la dupliquen ni diverjan
   (paso previo al paquete de estado compartido del ROADMAP). */
import { clawTitle, HUMAN, TARGETS, PAINT_LAYERS, carLayers } from "./data.js";
import { compute, fmtDepth, fmtF, fmtJ, fmtP } from "./physics.js";

export const BADGES = [
  { id: "vidrio", t: "Barrera del vidrio" }, { id: "movil", t: "Pantalla a salvo" },
  { id: "zafiro", t: "Cazadora de zafiros" }, { id: "diamante", t: "Diamante vs diamante" },
  { id: "piel", t: "Marca en la piel" }, { id: "fisico", t: "Físico de bata" },
  { id: "coche", t: "Pintura al descubierto" }, { id: "depredador", t: "Depredador" },
  { id: "resplandor", t: "🪓 ¡Aquí está Johnny!" }, { id: "metal", t: "Marca en el metal" },
  { id: "casuario", t: "🦖 Dinosaurio vivo" }, { id: "colmillo", t: "🦷 Colmillo roto" },
  { id: "banera", t: "🛁 Uña de bañera" }, { id: "abrelatas", t: "🥫 Abrelatas" },
  { id: "cristal", t: "💥 Cristal roto" },
];
/** Número de ensayos que da el logro "Físico de bata". */
export const BADGE_RUNS = 8;

/** Logros tras un ensayo. `prev` es un Set de ids; devuelve un Set nuevo (no muta `prev`). */
export function earnBadges(prev, { res, target, inlay, claw, method, strike, runs }) {
  const nb = new Set(prev);
  if (res.scratched === true && target.id === "vidrio") nb.add("vidrio");
  if (res.scratched === true && target.id === "zafiro") nb.add("zafiro");
  if (res.toolWorn && target.id === "movil") nb.add("movil");
  if (target.id === "diamante" && inlay.id === "diamante") nb.add("diamante");
  if (target.id === "piel" && res.scratched) nb.add("piel");
  if (target.paint && res.depthUm >= 45) nb.add("coche");
  if (target.body && res.through) nb.add("abrelatas");
  if (res.shattered) nb.add("cristal");
  if (target.id === "puertamadera" && res.verdict === "ATRAVIESA LA PUERTA") nb.add("resplandor");
  if (target.id === "puertametal" && res.scratched) nb.add("metal");
  if (claw) nb.add("depredador");
  if (claw && claw.id === "casuario" && method === "puncion" && strike && target.id === "piel" && res.scratched) nb.add("casuario");
  if (res.toolBroken && claw && claw.fang) nb.add("colmillo");
  if (res.wet && !res.scratched && !target.skin) nb.add("banera");
  if (runs >= BADGE_RUNS) nb.add("fisico");
  return nb;
}

/** Nombre del material de una garra reforjada, en minúscula salvo siglas: "acero", "zafiro", "CZ". */
export const materialName = (inlay) => (/^[A-Z]{2,}$/.test(inlay.short) ? inlay.short : inlay.short.toLowerCase());

/** Ficha de una garra o colmillo con la herramienta resuelta (resolveTool): una garra reforjada muestra su
 *  material y su dureza, no la de la queratina; una garra empapada, la dureza que le queda. */
export function clawSpec(claw, inlay, tool) {
  return {
    title: `${clawTitle(claw)}${tool.hasGem ? ` de ${materialName(inlay)}` : ""}`,
    material: tool.hasGem ? materialName(inlay) : `${claw.fang ? "dentina" : "queratina"}${tool.wet ? " húmeda" : ""}`,
    hardness: `${fmtP(tool.hv)} HV · Mohs ${tool.mohs}`,
  };
}

/** Subtítulo de cada material en las fichas: su dureza o, en un coche, qué hay bajo la pintura. */
export function targetSub(t) {
  if (t.skin) return "tejido vivo";
  if (t.body) return `pintura + ${t.body.name.toLowerCase()} ${(t.body.t / 1000).toFixed(1).replace(".", ",")} mm`;
  return `${t.layers ? t.layers.film.hv : t.hv} HV${t.brittle ? " · frágil" : ""}`;
}

/** Nombre corto de la herramienta para el cuaderno de ensayos. */
export function toolLabel({ claw, geom, inlay, res }) {
  // una garra "reforjada" es de ese material; en una uña, la piedra va incrustada
  const gem = res.hasGem ? (claw ? ` de ${materialName(inlay)}` : ` + ${inlay.short}`) : "";
  const wet = res.wet ? " (húmeda)" : "";
  return claw ? `${clawTitle(claw)}${gem}${wet}` : `${geom.name}${gem}${wet}`;
}

/** Fundamentos físicos (resumen de docs/FISICA.md) que muestran las dos apps. */
export const FUNDAMENTOS = [
  ["Presión", "nominal P = F/A (lo que la punta «pide»); la REAL nunca supera la dureza de quien cede (Tabor)."],
  ["Punta esfero-cónica", "radio R = √(A/π) y semiángulo α. Una punta roma trabaja como esfera (h ∝ F); una afilada, como cono (h ∝ √F)."],
  ["Hertz", "por debajo de p0 = 1,6·Y el contacto es elástico y no deja huella. La fricción adelanta la plastificación (von Mises √(1+3μ²))."],
  ["Quién cede", "con r = HV_punta/HV_obj < 0,8 cede la punta (Pintaude); por encima se deforma cada vez menos hasta r ≈ 2."],
  ["Profundidad", "la carga la soporta H·π·a² (punción) o H·π·a²/2 al rayar (solo trabaja el frente del surco)."],
  ["Multicapa", "pintura sobre la carrocería (acero de 0,7 mm en un coche moderno, acero dulce de ~0,9 mm en uno clásico, aluminio de 1 mm o plástico de ~2,5 mm): la queratina no corta el metal. Laca dura sobre roble (efecto cáscara de huevo)."],
  ["Chapa fina", "una punta dura primero rompe la chapa (dureza) y luego abre el agujero en pétalos: E = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4] (Wierzbicki 1999). Perforar es que la punta asome por detrás; atravesar, que pase la garra entera."],
  ["Vidrio de ventana", "la hoja de 4 mm se parte al flexar hasta 45 MPa (EN 572-1): ~200 N en el centro (Roark), aunque la punta sea blanda. En un golpe cuenta la fuerza de pico, que el tejido blando de la pata amortigua: un gato no la rompe; un oso, sí."],
  ["Frágil", "vidrio y gemas se rayan por microfractura cuando la punta es más dura; el acero blando no raya el vidrio."],
  ["Piel", "capas: córnea, epidermis (sin vasos), dermis (aguanta y sangra), grasa, fascia y músculo. Romperla exige la fuerza medida in vivo (Davis 2004); dentro, la punta acuña una grieta (F = 2·J·a) y al arrastrar la garra rasga: F = ∫J dz (tenacidad al desgarro de cada capa)."],
  ["Impacto", "½·m·v² de cada garra más el trabajo del empuje = trabajo de penetración ∫F·dh. El casuario es el único que atraviesa la puerta de roble."],
  ["Límites", "nada se hunde más que su propia garra, y los colmillos se rompen a ~30 N (Estrada 2026)."],
  ["Queratina húmeda", "empapada pierde ~80 % de rigidez y resistencia (Farran 2009): una uña mojada apenas raya."],
  ["Modo de abrasión (Hokkirigawa-Kato)", "Dp = h/a decide arado (< 0,1: desplaza) → cuña → corte (> 0,2: arranca viruta). Fricción de rayado μ = μ_adh + μ_arado."],
  ["Desgaste (Archard)", "V ∝ F·L/H, por la fracción realmente arrancada."],
  ["Adhesión (Van der Waals, JKR)", "F_adh = 1,5·π·R·W: despreciable a escala macro."],
];
export const FUNDAMENTOS_NOTE = "Mohs es ordinal y no lineal; el motor calcula en Vickers. Detalle y fuentes en docs/FISICA.md.";

/** Versión que enseñan las dos apps en el pie. Un test comprueba que es la de package.json, app.json,
 *  tauri.conf.json y Cargo.toml (la de los instaladores y las tiendas). */
export const APP_VERSION = "1.0.0";

/** Aviso de licencia del pie de las dos apps (textos completos en LICENSE y THIRD-PARTY-NOTICES.md). */
export const LICENSE_NOTE = `Scratch Tribology Simulator ${APP_VERSION} © 2026 Eric Valls Gramunt · Licencia MIT. Tipografías Syne y Space Mono: SIL Open Font License 1.1.`;

/** Texto del botón de fuerza máxima (humana o del animal). */
export function maxForceHint(claw) {
  if (!claw) return { force: HUMAN.force, label: "humana", note: "arañazo decidido, 1 uña. Una stiletto real se partiría antes. Un roce normal es ~1–5 N" };
  if (claw.fang) return { force: claw.force, label: "del colmillo", note: `los colmillos hidratados aguantan ~${claw.fBreak} N antes de romperse (Estrada 2026). Refórjalo en metal (incrustación) para empujar más.` };
  return { force: claw.force, label: `del ${claw.name.toLowerCase()}`, note: `máximo esfuerzo (zarpazo o agarre) · peso ~${claw.mass} kg. Un mimo/juego es mucho menos (~1–4 N)` };
}

/* ════════ MODO DUAL: EL MISMO ENSAYO EN DOS COCHES ════════
   Qué raya, punza, desgarra o atraviesa la herramienta en cada coche, cuántos milímetros (o
   centímetros) y qué daño deja. Lo usan las dos apps: aquí se calcula, allí solo se pinta. */
/** Coches del modo dual (los que tienen carrocería) y la pareja por defecto: antiguo frente a moderno. */
export const DUEL_CARS = TARGETS.filter((t) => t.body);
export const DUEL_DEFAULT = ["cocheclasico", "coche"];
/** Maneras de atacar: rayar, desgarrar (solo garras), punzar empujando y golpear. */
export const DUEL_MODES = [
  { id: "rayado", name: "Raya", p: { method: "rayado", strike: false, tear: false } },
  { id: "desgarro", name: "Desgarra", p: { method: "rayado", strike: false, tear: true }, clawOnly: true },
  { id: "puncion", name: "Punza", p: { method: "puncion", strike: false, tear: false } },
  { id: "golpe", name: "Golpea", p: { method: "puncion", strike: true, tear: false } },
];

/** Longitud legible con centímetros a partir de 1 cm: 350 µm · 6.1 mm · 35 mm (3.5 cm). */
export function fmtLen(um) {
  if (um < 10000) return fmtDepth(um);
  // hasta 100 mm, con el mismo decimal que fmtDepth (Ø 10.5 mm, no 11), sin ".0" de relleno
  const mm = um / 1000;
  const mmTxt = mm >= 100 ? mm.toFixed(0) : mm.toFixed(1).replace(/\.0$/, "");
  return `${mmTxt} mm (${(um / 10000).toFixed(1)} cm)`;
}

/** Etapa de daño de un resultado sobre un coche: 0 nada · 1 pintura · 2 carrocería · 3 perforada · 4 atravesada. */
export function damageStage(res) {
  if (/^(ATRAVIESA|RAJA)/.test(res.verdict)) return 4;
  if (/^PERFORA (LA|EL)/.test(res.verdict)) return 3;
  if (res.depthUm > PAINT_LAYERS.at(-1).to + 1) return 2;
  return res.scratched ? 1 : 0;
}

/** Informe de daños: pares [etiqueta, valor] listos para pintar. */
export function damageReport(res, target, { length = 25 } = {}) {
  const out = [];
  if (res.shattered) return [["Vidrio", `se parte (pico ~${fmtF(res.peakN)} N; aguanta ~${fmtF(res.paneN)} N)`]];
  if (!res.scratched) return [["Daño", res.toolBroken ? "ninguno: se rompe la punta" : "ninguno visible"]];
  out.push(["Profundidad", fmtLen(res.depthUm)]);
  if (res.through) out.push([res.puncture ? "Agujero" : "Raja", `Ø ${fmtLen(res.grooveWidthUm)}`]);
  else if (!res.puncture && res.grooveWidthUm > 0) out.push(["Surco", `${(length / 10).toFixed(1)} cm de largo × ${fmtDepth(res.grooveWidthUm)}`]);
  const L = carLayers(target);
  if (L) {
    const lower = (n) => n.charAt(0).toLowerCase() + n.slice(1);            // "Acero BH" → "acero BH"
    const broken = L.filter((l) => res.depthUm > l.from + 1e-6).map((l) => lower(l.name));
    const body = target.body;
    if (broken.length) out.push(["Capas", res.through ? `todas, y ${body.noun} de lado a lado` : broken.join(" · ")]);
  }
  // Energía: solo tiene sentido en un golpe. Lo que no entra rebota o abolla (la abolladura no se modela).
  if (res.puncture && res.energyJ > 0 && res.workJ != null) {
    const kept = Math.min(res.workJ, res.energyJ);
    out.push(["Energía absorbida", `${fmtJ(kept)} J de ${fmtJ(res.energyJ)} J`]);
    if (!res.through && kept < 0.5 * res.energyJ) out.push(["El resto", "rebota o abolla (la abolladura no se modela)"]);
  }
  return out;
}

/** El mismo ensayo (herramienta, fuerza, largo…) en dos coches y en cada manera de atacar. */
export function duel(params, claw, cars) {
  return DUEL_MODES.filter((m) => !m.clawOnly || claw).map((m) => ({
    ...m,
    res: cars.map((target) => compute({ ...params, claw, ...m.p, target })),
  }));
}

/** Quién aguanta mejor: menos etapa de daño; a igual etapa, menos profundidad o, si las dos quedan
 *  atravesadas de lado a lado, la que se queda más energía del golpe. */
export function duelVerdict(resA, resB, cars) {
  const a = damageStage(resA), b = damageStage(resB);
  const name = (t) => t.name.toLowerCase();
  if (a !== b) return { winner: a < b ? 0 : 1, text: `aguanta mejor ${name(cars[a < b ? 0 : 1])}` };
  if (a === 4) {
    const wA = resA.workJ ?? 0, wB = resB.workJ ?? 0;
    if (Math.abs(wA - wB) > 0.05) { const w = wA > wB ? 0 : 1; return { winner: w, text: `las dos ceden; ${name(cars[w])} absorbe más energía` }; }
    return { winner: null, text: "las dos ceden por igual" };
  }
  const dA = resA.depthUm, dB = resB.depthUm;
  if (a >= 1 && Math.abs(dA - dB) > 0.05 * Math.max(dA, dB)) {
    const w = dA < dB ? 0 : 1;
    return { winner: w, text: a === 3 ? `las dos se perforan; ${name(cars[w])} deja pasar menos punta` : `${name(cars[w])} se marca menos` };
  }
  return { winner: null, text: a === 0 ? "ninguno sufre daño" : "empate" };
}
