import { C } from "./theme.js";
import { HUMAN, PAINT_LAYERS, SKIN_LAYERS, carLayers } from "./data.js";

export const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
export const FMIN = 0.5, FMAX = 2000;
export const fToT = (f) => (Math.log10(clamp(f, FMIN, FMAX)) - Math.log10(FMIN)) / (Math.log10(FMAX) - Math.log10(FMIN));
export const tToF = (t) => Math.pow(10, Math.log10(FMIN) + t * (Math.log10(FMAX) - Math.log10(FMIN)));
export const fmtF = (f) => (f >= 10 ? f.toFixed(0) : f.toFixed(1));
/** Energía legible en julios: 0,35 · 1,4 · 160. */
export const fmtJ = (j) => (j >= 10 ? j.toFixed(0) : j >= 1 ? j.toFixed(1) : j.toFixed(2));
export const fmtP = (p) => (p >= 100 ? p.toFixed(0) : p >= 10 ? p.toFixed(1) : p.toFixed(2));
export const hvBar = (hv) => clamp((Math.log10(hv) - Math.log10(2)) / (Math.log10(10000) - Math.log10(2)) * 100, 4, 100);
/** Profundidad legible: µm con 1 decimal por debajo de 10 µm, mm a partir de 1000 µm. */
export const fmtDepth = (um) => (um >= 1000 ? `${(um / 1000).toFixed(1)} mm` : `${um < 10 ? um.toFixed(1) : um.toFixed(0)} µm`);
export const smoothstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

/* ════════ PHYSICS (modelo v2) ════════
   Unidades internas: fuerza N · longitud mm · presión y dureza MPa (= N/mm²) · energía mJ (= N·mm).
   1 HV = 9,807 MPa. Cada constante lleva su fuente (o la etiqueta "estimación") en docs/FISICA.md.

   1. Punta esfero-cónica: radio R = √(área/π) y semiángulo α. El contacto crece con la carga.
   2. Contacto elástico de Hertz: si la presión máxima no alcanza 1,6·Y el material solo rebota
      (φ → 0). Con fricción, la cizalla adelanta la plastificación (factor de von Mises √(1+3μ²)).
   3. Contacto plástico: la presión media REAL nunca supera la dureza del material que cede.
      Área que soporta la carga: π·a² en punción; π·a²/2 al rayar (solo trabaja el frente).
   4. Durezas: con r = H_punta/H_objetivo < 0,8 cede la punta (Pintaude/Richardson); por encima la
      punta se deforma cada vez menos hasta r ≈ 2. Se modela como dureza efectiva H/η(r).
   5. Multicapa: dureza compuesta H(h) (pintura sobre la carrocería; laca dura sobre madera blanda).
   6. Impacto: ½·m·v² + F·h = ∫ F_resistencia dh (trabajo de penetración).
   7. Piel: perforarla exige la fuerza medida in vivo (Davis 2004); después la punta avanza
      abriendo una grieta con la tenacidad de corte de la piel (Pereira 1997).
   8. Abrasión (Hokkirigawa-Kato), fricción de arado (Bowden-Tabor), Archard y adhesión JKR.
   9. Chapa fina (coches, puerta de aluminio): se indenta hasta romperla; después el agujero se abre en
      pétalos (Wierzbicki 1999). Vidrio de ventana: la hoja se parte al flexar (Roark; EN 572-1). */
export const HV_MPA = 9.807;
export const MODEL = {
  rOff: 0.8,             // r por debajo del cual la punta no raya (Pintaude; Richardson)
  rFull: 2.0,            // r a partir del cual la punta ya no se deforma (hipótesis del modelo)
  tabor: 2.8,            // H ≈ 2,8·Y (Tabor)
  yieldOnset: 1.6,       // plastificación bajo una esfera cuando p0 = 1,6·Y (Johnson)
  nu: 0.3,               // coeficiente de Poisson común
  skinPunctureSlope: 190,    // N/mm² · Davis 2004: F = 0,00019·A[µm²] − 0,66 N (piel humana in vivo)
  skinPunctureOffset: 0.66,  // N
  skinPunctureMin: 0.08,     // N · la menor fuerza medida por Davis 2004
  skinPunctureToughness: 30.1, // kJ/m² = N/mm · tenacidad de punción G_p (Davis 2004)
  // Rayado de piel (apartado 7). Tenacidades y espesores por capa: SKIN_LAYERS (data.js).
  skinStressMark: 1,         // MPa · por debajo, la punta resbala sin huella (heurística calibrada)
  skinStressAbrade: 4,       // MPa · levanta la capa córnea: rasguño blanco (heurística calibrada)
  skinStressExcoriate: 16,   // MPa · arranca la epidermis: excoriación (heurística calibrada)
  skinExcoriatePasses: 5,    // pasadas para que una excoriación llegue a las papilas y sangre (estimación)
  skinPapillaryUm: 300,      // µm · dermis papilar, la de los capilares (estimación, 0,1-0,4 mm)
  skinHook: 0.7,             // enganche de la garra curva en la piel: ×(1 + 0,7·curvatura) (estimación)
  wetKeratin: 0.2,       // queratina empapada: E y resistencia caen ~×0,2 (Farran 2009; Bonser en McKittrick 2012)
  passExp: 0.4,          // pasadas: profundidad ∝ n^0,4 (heurística sublineal)
  clawBase: 0.15,        // radio de la sección de una garra en su base ≈ 0,15 × su alcance (estimación)
  fangBase: 0.04,        // colmillo: aguja fina, ≈ 0,04 × su alcance (estimación)
  limbStiffness: 10,     // N/mm · rigidez del tejido blando de una pata o un dedo que golpea (estimación)
};
const DEG = Math.PI / 180;

/* ── Geometría esfero-cónica ── tangencia esfera-cono en a_t = R·cos α, h_t = R·(1 − sin α).
   Una garra no es un cono infinito: `amax` (mm) es el radio de su sección en la base. Solo limita el
   agujero que abre en una chapa (holeRadius): en un sólido, el fuste enterrado sigue rozando. */
export function tipGeometry(areaMm2, alphaDeg, amax = Infinity) {
  const R = Math.sqrt(areaMm2 / Math.PI), al = alphaDeg * DEG;
  return { R, tanA: Math.tan(al), at: R * Math.cos(al), ht: R * (1 - Math.sin(al)), amax };
}
/** Radio del contacto a (mm) cuando la punta se ha hundido h (mm). */
export function contactRadius(tip, h) {
  if (h <= 0) return 0;
  if (h <= tip.ht) return Math.sqrt(Math.max(2 * tip.R * h - h * h, 0));
  return tip.at + (h - tip.ht) * tip.tanA;
}
/** Radio del agujero que la herramienta abre en una chapa: nunca más ancho que su propia sección. */
export const holeRadius = (tip, h) => Math.min(contactRadius(tip, h), tip.amax ?? Infinity);
/** Inversa: profundidad h (mm) que corresponde a un radio de contacto a (mm). */
export function depthForRadius(tip, a) {
  if (a <= 0) return 0;
  if (a <= tip.at) return tip.R - Math.sqrt(tip.R * tip.R - a * a);
  return tip.ht + (a - tip.at) / tip.tanA;
}
/** Eficiencia de la punta según la relación de durezas r (0 → cede la punta, 1 → punta rígida). */
export const hardnessEfficiency = (r) => smoothstep(MODEL.rOff, MODEL.rFull, r);

/** Fracción plástica del contacto φ (Hertz): 0 si todo es elástico, 1 si la presión media llega a H. */
export function plasticFraction(F, R, Etool, Etarget, H, fMu = 1) {
  const Estar = 1000 / ((1 - MODEL.nu ** 2) * (1 / Etool + 1 / Etarget));   // MPa (E en GPa)
  const aH = Math.cbrt((3 * F * R) / (4 * Estar));                          // mm
  const p0 = (3 * F) / (2 * Math.PI * aH * aH);                              // MPa
  const q = (p0 * fMu) / (MODEL.yieldOnset * (H / MODEL.tabor));
  const qFull = (1.5 * MODEL.tabor) / MODEL.yieldOnset;                       // p_media = H
  return { phi: smoothstep(1, qFull, q), p0, aH };
}

/* ── Resolución de la herramienta (uña, gema o garra) ── */
/** Ventaja mecánica del desgarro: la garra curva hace de gancho y palanca. */
export const tearLeverage = (claw) => (claw ? 1 + 1.3 * claw.curve : 1);
/** Profundidad relativa tras n pasadas por el mismo surco: n^0,4 (heurística sublineal). */
export const passDepthFactor = (n) => Math.pow(Math.max(n || 1, 1), MODEL.passExp);

export function resolveTool({ geom, base, inlay, claw, wet }) {
  const useClaw = !!claw;
  const hasGem = !!inlay && inlay.id !== "none";
  const fang = useClaw && !!claw.fang;
  const mat = hasGem ? inlay : (useClaw ? claw : base);
  // Una garra o un colmillo "reforjados" en otro material (acero, zafiro…) conservan su forma: el material
  // cambia la dureza, no la geometría. En una uña, la piedra de la punta es la que araña.
  const shape = useClaw ? claw : (hasGem ? inlay : geom);
  const keratin = !hasGem && (useClaw ? !fang : !!base.keratin);
  const isWet = !!wet && keratin;
  const wetK = isWet ? MODEL.wetKeratin : 1;
  const strike = useClaw ? claw.strike : HUMAN.strike;
  return {
    hv: mat.hv * wetK, mohs: mat.mohs, E: mat.E * wetK,
    area: shape.area, alpha: shape.alpha,
    tipRadiusUm: Math.sqrt(shape.area / Math.PI) * 1000,   // radio de la esfera de la punta (apartado 1)
    reach: useClaw ? claw.reach : geom.reach,
    baseR: useClaw ? claw.reach * (fang ? MODEL.fangBase : MODEL.clawBase) : Infinity,   // mm (estimación)
    fBreak: useClaw && !hasGem ? claw.fBreak : undefined,
    strike, strikeJ: 0.5 * strike.m * strike.v ** 2,       // energía cinética del golpe, ½·m·v²
    curve: useClaw ? claw.curve : 0,
    keratin, wet: isWet, hasGem, fang, useClaw,
  };
}

/* ── Perfil de dureza del objetivo en MPa ──
   H(h, a): dureza que opone el material con la punta hundida h (mm) y un contacto de radio a (mm).
   Hmax(h): la dureza más alta atravesada hasta h. El embotamiento de la punta es irreversible, así
   que su eficiencia la marca el material más duro que ha tenido que cortar. */
function hardnessProfile(target) {
  const L = target.layers;
  if (!L) {
    const H = target.hv * HV_MPA;
    return { H: () => H, Hmax: () => H, Hsurf: H, hvSurf: target.hv, Esurf: target.E };
  }
  const Hf = L.film.hv * HV_MPA, Hs = L.sub.hv * HV_MPA, t = L.film.t / 1000;
  if (L.kind === "paint-on-body") {
    // Coche: manda la pintura hasta la carrocería; después, su material. Con acero o aluminio es un
    // escalón HACIA ARRIBA (la profundidad se queda en la chapa, nunca salta); con plástico, más blando
    // que el barniz, hacia abajo. La punta ya se ha embotado con lo más duro que haya cortado.
    const H = (h) => (h <= t ? Hf : Hs);
    const Hmax = (h) => (h <= t ? Hf : Math.max(Hf, Hs));
    return { H, Hmax, Hsurf: Hf, hvSurf: L.film.hv, Esurf: L.film.E, film: L.film, sub: L.sub };
  }
  // Puerta: laca dura sobre madera blanda. La laca se hunde con la madera (efecto cáscara de huevo)
  // y su aporte decae con el TAMAÑO del contacto (modelo tipo Jönsson-Hogmark). Con esta forma,
  // H·π·a² crece siempre con a: la profundidad sube de forma continua al romper la laca.
  const H = (_h, a) => Hs + (Hf - Hs) * Math.exp(-a / t);
  return { H, Hmax: () => Hf, Hsurf: Hf, hvSurf: L.film.hv, Esurf: L.film.E, film: L.film, sub: L.sub };
}

/* ── Resistencia a la penetración F_res(h) (N) y resolución estática / por energía ── */
function makeResistance(tip, prof, Htool, loadShare, m) {
  return (h) => {
    const a = contactRadius(tip, h / m);
    if (a <= 0) return 0;
    const eta = hardnessEfficiency(Htool / prof.Hmax(h));
    return eta > 0 ? (prof.H(h, a) / eta) * loadShare * Math.PI * a * a : Infinity;
  };
}
/* ── Chapa fina: perforación en pétalos (Wierzbicki 1999) ──
   Hasta que la punta sale por detrás, la chapa se indenta como un sólido (dureza). Una vez rota deja de
   oponerse como un bloque: el agujero se abre en pétalos que se doblan y se rasgan. Energía para abrir un
   agujero de radio l en una chapa de espesor t, con fractura dúctil (δt/t = 1), ecuación 57:
     E(l) = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4]      (mJ, con σ0 en MPa y longitudes en mm)
   La fuerza es su derivada respecto a la profundidad de la punta: el agujero tiene el radio de la
   herramienta a esa profundidad. Una punta afilada (tan α pequeña) se cuela; una ancha cuesta mucho más. */
/** Energía (mJ) para abrir en pétalos un agujero de radio l (mm) en una chapa de espesor t (mm). */
export function petalEnergy(l, t, sigma0) {
  return l > 0 ? sigma0 * t * t * l * (1.23 + 8.9 * Math.pow(l / t, 0.4)) : 0;
}
/** Chapa perforable del material: tramo de profundidades que ocupa (mm), espesor y σ0. null si no tiene. */
export function sheetOf(target) {
  if (target.body) return { from: target.layers.film.t / 1000, to: target.thickness, t: target.body.t / 1000, sigma0: target.body.sigma0 };
  if (target.sigma0 && target.thickness) return { from: 0, to: target.thickness, t: target.thickness, sigma0: target.sigma0 };
  return null;
}
function makeSheetResistance(tip, prof, Htool, loadShare, m, sheet) {
  const solid = makeResistance(tip, prof, Htool, loadShare, m);
  const E = (h) => petalEnergy(holeRadius(tip, Math.max(h, 0) / m), sheet.t, sheet.sigma0);
  const d = 1e-4;
  return (h) => (h <= sheet.to ? solid(h) : (loadShare * (E(h + d) - E(h - d))) / (2 * d));
}

/* ── Hoja de vidrio que se parte al flexar ──
   Placa circular apoyada de radio a con la carga en el centro (Roark): en la cara de atrás
     σ = 3F/(2π·t²)·[(1+ν)·ln(a/r0') + 1],  con r0' = √(1,6·r0² + t²) − 0,675·t si r0 < 0,5·t (Westergaard).
   Se parte cuando σ llega a la resistencia a flexión fg,k (EN 572-1). Rigidez de la placa en el centro:
   k = 4π·E·t³ / (3·a²·(3+ν)·(1−ν)); en un golpe, solidResult compara con F la fuerza de pico (la hoja y la
   pata en serie). U = F²/2k es la energía que la hoja almacena al partirse (la que se queda el vidrio).
   No hace falta dureza: un puño también rompe una ventana. */
export function paneBreak(pane, Egpa, r0 = 0) {
  const { t, a, fgk, nu } = pane;
  const r0e = r0 < 0.5 * t ? Math.sqrt(1.6 * r0 * r0 + t * t) - 0.675 * t : r0;
  const F = (fgk * 2 * Math.PI * t * t) / (3 * ((1 + nu) * Math.log(a / r0e) + 1));
  const k = (4 * Math.PI * Egpa * 1000 * t ** 3) / (3 * a * a * (3 + nu) * (1 - nu));
  return { F, k, U: (F * F) / (2 * k) };                                      // N · N/mm · mJ
}

const H_MAX = 400; // mm: más allá no tiene sentido físico en este banco
/** Menor profundidad h (mm) en la que la resistencia iguala a la fuerza F (bisección). */
export function solveStatic(F, res, hMax = H_MAX) {
  if (F <= 0) return 0;
  if (res(hMax) < F) return hMax;
  let lo = 0, hi = hMax;
  for (let i = 0; i < 80; i++) { const mid = (lo + hi) / 2; if (res(mid) >= F) hi = mid; else lo = mid; }
  return hi;
}
/**
 * Primer h (mm) en que res(h) ≥ F cuando res crece dentro de cada capa pero puede CAER al pasar a la
 * siguiente (la piel: tras la dermis, la grasa cede con mucha menos fuerza). La punta atraviesa cada
 * capa cuya resistencia no alcanza F y se detiene en la primera que sí. `breaks`: fronteras en mm.
 */
export function solveLayered(F, res, breaks, hMax = H_MAX) {
  if (F <= 0) return 0;
  const edges = [0, ...breaks.filter((b) => b > 0 && b < hMax), hMax];
  for (let i = 1; i < edges.length; i++) {
    const end = i === edges.length - 1 ? hMax : edges[i] - 1e-9;
    if (res(end) < F) continue;
    let lo = edges[i - 1], hi = end;
    for (let k = 0; k < 80; k++) { const mid = (lo + hi) / 2; if (res(mid) >= F) hi = mid; else lo = mid; }
    return hi;
  }
  return hMax;
}
/** Trabajo ∫_a^b F_res dh (mJ) por trapecios; Infinity si en el tramo hay una "pared" (la punta no la corta). */
function workBetween(res, a, b, n) {
  let w = 0, x0 = a, f0 = res(a);
  for (let k = 1; k <= n; k++) {
    const x = a + ((b - a) * k) / n, f = res(x);
    if (!Number.isFinite(f)) return Infinity;
    w += 0.5 * (f0 + f) * (x - x0); x0 = x; f0 = f;
  }
  return w;
}
/** Trabajo de penetración ∫₀ʰ F_res dh (J) hasta la profundidad final, por tramos entre `breaks` (mm).
 *  Se detiene en una pared que la punta no corta: lo que queda de un golpe no entra (rebota o abolla). */
function absorbedWork(res, h, breaks = []) {
  const edges = [0, ...breaks.filter((b) => b > 0 && b < h), h];
  let w = 0;
  for (let i = 1; i < edges.length; i++) {
    const a = edges[i - 1], b = i === edges.length - 1 ? edges[i] : edges[i] - 1e-9, n = 80;
    let x0 = a, f0 = res(a);
    for (let k = 1; k <= n; k++) {
      const x = a + ((b - a) * k) / n, f = res(x);
      if (!Number.isFinite(f) || !Number.isFinite(f0)) return w / 1000;
      w += 0.5 * (f0 + f) * (x - x0); x0 = x; f0 = f;
    }
  }
  return w / 1000;
}
/** Profundidad en la que el trabajo de penetración ∫F_res iguala la energía E (mJ) + el trabajo de F. */
export function solveEnergy(Emj, F, res, hMax = H_MAX) {
  const N = 300, h0 = 1e-5;
  let W = 0, hPrev = 0;
  for (let i = 0; i <= N; i++) {
    const h = h0 * Math.pow(hMax / h0, i / N);
    const dW = workBetween(res, hPrev, h, 2);
    if (W + dW - Emj - F * h >= 0) {
      // El balance se cruza en este tramo: bisección con integración fina. Si hay una pared (p. ej. la
      // chapa bajo la pintura), converge justo a ella: la energía sobrante no la atraviesa.
      let lo = hPrev, hi = h;
      for (let k = 0; k < 40; k++) {
        const mid = (lo + hi) / 2;
        if (W + workBetween(res, hPrev, mid, 16) - Emj - F * mid >= 0) hi = mid; else lo = mid;
      }
      return hi;
    }
    W += dW; hPrev = h;
  }
  return hMax;
}

// Severidad 0-1 con escala logarítmica (monótona, sin escalones): 0,3 µm → ~0, hFull → 1.
const sevLog = (um, fullUm) => clamp(Math.log1p(um / 0.3) / Math.log1p(fullUm / 0.3), 0, 1);

/* ════════ COMPUTE ════════ */
export function compute({ geom, base, inlay, target, force, length, type, claw, tear, method, strike, passes, wet }) {
  const tool = resolveTool({ geom, base, inlay, claw, wet });
  const tip = tipGeometry(tool.area, tool.alpha, tool.baseR);
  const { useClaw, hasGem } = tool;
  const puncture = method === "puncion";
  const tearing = !!tear && useClaw && !puncture;                 // desgarro/palanca: solo garras
  const lever = tearing ? tearLeverage(claw) : 1;                 // gancho curvo → ventaja mecánica
  const mu = target.mu;
  const fMu = Math.sqrt(1 + 3 * mu * mu);                         // von Mises con cizalla de Coulomb
  const Fadh = 1.5 * Math.PI * tip.R * 1e-3 * target.W;           // N (JKR, Van der Waals)
  const Neff = force + Fadh;
  const Htool = tool.hv * HV_MPA;
  const pNominal = Neff / tool.area;                               // MPa: lo que la punta "pide"
  const energyJ = puncture && strike ? 0.5 * tool.strike.m * tool.strike.v ** 2 : 0;
  const passN = Math.max(passes || 1, 1);
  const common = {
    hasGem, area: tool.area, hvTool: tool.hv, mohsTool: tool.mohs, mu, Fadh_mN: Fadh * 1000, pNominal,
    claw: useClaw, wet: tool.wet, reachMm: tool.reach, tipRadiusUm: tip.R * 1000, alphaDeg: tool.alpha,
    skin: !!target.skin, paint: !!target.paint, woodDoor: !!target.woodDoor, tName: target.name,
  };
  return target.skin
    ? skinResult({ tool, tip, target, force, Neff, pNominal, Htool, puncture, strike, energyJ, type, fMu, lever, length, passN, tearing, common })
    : solidResult({ tool, tip, target, force, Neff, pNominal, Htool, puncture, strike, energyJ, type, fMu, lever, length, passN, tearing, common });
}

/* ════════ PIEL (multicapa) ════════
   Capa córnea, epidermis, dermis, grasa, fascia y músculo (SKIN_LAYERS). Tres mecanismos:
   1. Romper la superficie: fuerza de punción medida in vivo (Davis 2004), lineal con el área de la punta.
      Al arrastrar ayudan la cizalla y la piel tensa por delante: F_ef = N·√(1+3μ²)·enganche·palanca.
   2. Entrar de frente ya rota: la punta acuña una grieta plana (Shergold & Fleck 2005) → F = 2·jC·a(h),
      con la tenacidad al corte de la capa en la que está. Tras la dermis la resistencia CAE (Knight 1975).
   3. Arrastrar ya rota: la garra rasga un corte de profundidad h. Energía por unidad de longitud:
      F_t = ∫₀ʰ jT dz (tenacidad al desgarro, Comley & Fleck 2010). Sin romper, solo hay abrasión
      de la capa córnea o de la epidermis (umbrales de esfuerzo calibrados). */
/** Capa de piel alcanzada a una profundidad (µm): tocar el fondo de una capa no es entrar en la siguiente. */
export const skinLayerAt = (um, stack = SKIN_LAYERS) => stack.find((l) => um <= l.to) ?? stack[stack.length - 1];
/** Fuerza de punción de la piel (N) para una punta de área A (mm²), Davis 2004. */
export const skinPunctureForce = (areaMm2) => Math.max(MODEL.skinPunctureMin, MODEL.skinPunctureSlope * areaMm2 - MODEL.skinPunctureOffset);
/** Profundidad (mm) del corte que abre una fuerza de desgarro Ft (N): inversa de ∫₀ʰ jT dz. La última capa no acaba. */
export function skinTearDepth(Ft, stack = SKIN_LAYERS) {
  let w = 0;
  for (let i = 0; i < stack.length; i++) {
    const l = stack[i], a = l.from / 1000, b = i === stack.length - 1 ? Infinity : l.to / 1000;
    if (w + l.jT * (b - a) >= Ft) return a + (Ft - w) / l.jT;
    w += l.jT * (b - a);
  }
  return Infinity;
}
// Severidad por profundidad: continua y creciente (log), con los hitos de cada capa.
const SKIN_SEV = [[0, 0.25], [75, 0.3], [75 + MODEL.skinPapillaryUm, 0.45], [2200, 0.62], [13000, 0.8], [13300, 0.86], [40000, 0.97]];
function skinSeverity(um) {
  if (um <= 0) return 0;
  const lg = (x) => Math.log(1 + x);
  for (let i = 1; i < SKIN_SEV.length; i++) {
    const [u0, s0] = SKIN_SEV[i - 1], [u1, s1] = SKIN_SEV[i];
    if (um <= u1) return s0 + ((s1 - s0) * (lg(um) - lg(u0))) / (lg(u1) - lg(u0));
  }
  return SKIN_SEV[SKIN_SEV.length - 1][1];
}
/** Dónde queda la punta, en palabras (para el veredicto). */
function skinWhere(um, stack) {
  const l = skinLayerAt(um, stack);
  return {
    cornea: "en la capa córnea", epidermis: "en la epidermis (sin vasos)",
    dermis: um <= 75 + MODEL.skinPapillaryUm ? "en la dermis papilar (capilares)" : "en la dermis reticular",
    grasa: "en la grasa (subcutáneo)", fascia: "en la fascia profunda", musculo: "en el músculo (intramuscular)",
  }[l.id];
}

function skinResult({ tool, tip, target, force, Neff, pNominal, Htool, puncture, strike, energyJ, type, fMu, lever, length, passN, tearing, common }) {
  const stack = target.tissue || SKIN_LAYERS;
  const breaks = stack.slice(1).map((l) => l.from / 1000);
  const epi = (stack.find((l) => l.id === "epidermis") || stack[0]).to;
  const pressure = Math.min(pNominal, Htool);                      // la piel nunca aplasta la punta
  const Hsoft = 15;                                                 // referencia de desgaste (u.a.)
  const fPuncture = skinPunctureForce(tool.area);
  const reachUm = tool.reach * 1000;
  const widthAt = (um) => 2 * contactRadius(tip, um / 1000) * 1000;
  const skinCommon = { ...common, ratio: null, chi: null, Ffric: target.mu * Neff, toolWorn: false, contactAreaMm2: tool.area, phi: 1, eta: 1, fPuncture, energyJ,
    through: false, shattered: false, paneN: null, peakN: null, workJ: null };

  if (puncture) {
    const eRupture = MODEL.skinPunctureToughness * tool.area;     // mJ: G_p·A
    const Emj = energyJ * 1000;
    const pierces = Neff >= fPuncture || (strike && Emj >= eRupture);
    const res = (h) => 2 * skinLayerAt(h * 1000, stack).jC * contactRadius(tip, h);
    let hMm = 0;
    if (pierces) hMm = strike ? solveEnergy(Emj, Neff, res) : solveLayered(Neff, res, breaks);
    const depthUm = Math.min(hMm * 1000, reachUm);
    const inject = tool.fang;
    const where = skinWhere(depthUm, stack), mm = (depthUm / 1000).toFixed(1);
    const reached = skinLayerAt(depthUm, stack);
    const out = !pierces
      ? { verdict: "NO PERFORA", vcol: C.mint, vsub: `hunde la piel pero no la rompe (necesita ~${fPuncture.toFixed(1)} N)`, cede: "nada", scratched: false }
      : inject
        ? { verdict: "PUNCIÓN · INYECTA", vcol: C.coral, vsub: `perfora y deja el veneno a ~${mm} mm, ${where}`, cede: "la piel (2 punciones)", scratched: true }
        : { verdict: depthUm > 2200 ? "PUNCIÓN PROFUNDA" : "PUNCIÓN", vcol: C.coral, vsub: `perfora ~${mm} mm: la punta queda ${where}`, cede: depthUm > 2200 ? "la piel entera" : "la piel (perforada)", scratched: true };
    return {
      ...skinCommon, ...out, pressure, stress: pressure,
      sev: pierces ? Math.max(0.3, skinSeverity(depthUm)) : 0.08,
      wearIdx: Math.round((400 * force * (strike ? 2 : 1)) / Hsoft),
      depthUm, layer: pierces ? reached.name : null, bleeds: pierces && depthUm > epi, tearing: false,
      puncture: true, inject, pierces, fullReach: depthUm >= reachUm - 1e-6, grooveWidthUm: pierces ? widthAt(depthUm) : 0,
    };
  }

  // Rayado. La dureza de la herramienta no interviene: cualquier punta es ≫ más dura que la piel.
  const hook = common.claw ? 1 + MODEL.skinHook * tool.curve : 1;
  const stress = pressure * type.k * fMu * hook * lever;           // esfuerzo en la superficie (MPa)
  const ruptures = Neff * fMu * hook * lever >= fPuncture;
  const passF = passDepthFactor(passN);
  // Fuerza que abre el corte: arrastrando, la fricción; desgarrando, el tirón entero de la garra enganchada.
  // (La adhesión de Van der Waals, de milinewtons, no tira de la garra hacia delante: se usa la fuerza aplicada.)
  const Ft = (tearing ? force * lever : target.mu * force * hook) * type.k * passF;
  const abrUm = stress >= MODEL.skinStressExcoriate ? epi : stress >= MODEL.skinStressAbrade ? stack[0].to : 0;
  const cutUm = ruptures ? Math.min(skinTearDepth(Ft, stack) * 1000, reachUm) : 0;
  const depthUm = Math.max(abrUm, cutUm);
  const where = skinWhere(depthUm, stack), mm = depthUm >= 1000 ? `${(depthUm / 1000).toFixed(1)} mm` : `${depthUm.toFixed(0)} µm`;
  const reached = skinLayerAt(depthUm, stack);
  const excoriateBleeds = !ruptures && abrUm === epi && passN >= MODEL.skinExcoriatePasses;
  let out;
  if (depthUm <= 0) {
    out = stress < MODEL.skinStressMark
      ? { scratched: false, sev: 0, verdict: "SIN MARCA", vcol: C.mint, vsub: "la punta resbala, sin huella", cede: "nada" }
      : { scratched: "faint", sev: 0.1, verdict: "MARCA ROJA", vcol: C.gold, vsub: "esfuerzo bajo: enrojece y se va sola; no rompe", cede: "piel (reversible)" };
  } else if (!ruptures) {
    out = excoriateBleeds
      ? { scratched: true, sev: 0.35, verdict: "RASGUÑOS QUE SANGRAN", vcol: C.coral, vsub: `${passN} pasadas excorian la epidermis hasta las papilas de la dermis: puntitos de sangre`, cede: "la epidermis" }
      : abrUm === epi
        ? { scratched: "faint", sev: 0.22, verdict: "RASGUÑOS", vcol: C.gold, vsub: "arranca la epidermis (~75 µm): escuece, pero no sangra (la epidermis no tiene vasos)", cede: "la epidermis" }
        : { scratched: "faint", sev: 0.15, verdict: "RASGUÑO BLANCO", vcol: C.gold, vsub: "solo levanta la capa córnea (~18 µm): raya blanca, sin herida", cede: "la capa córnea" };
  } else {
    const id = reached.id, papillary = depthUm <= epi + MODEL.skinPapillaryUm;
    const name = tearing
      ? { cornea: "DESGARRO SUPERFICIAL", epidermis: "DESGARRO SUPERFICIAL", dermis: papillary ? "DESGARRO" : "DESGARRO PROFUNDO", grasa: "DESGARRO ABIERTO", fascia: "DESGARRO MUSCULAR", musculo: "DESGARRO MUSCULAR" }[id]
      : { cornea: "ARAÑAZO SUPERFICIAL", epidermis: "ARAÑAZO SUPERFICIAL", dermis: papillary ? "ARAÑAZO QUE SANGRA" : "ARAÑAZO PROFUNDO", grasa: "LACERACIÓN", fascia: "LACERACIÓN PROFUNDA", musculo: "LACERACIÓN PROFUNDA" }[id];
    const sub = {
      cornea: "rompe la superficie sin llegar a la dermis: no sangra", epidermis: "rompe la epidermis sin llegar a la dermis: no sangra",
      dermis: papillary ? `abre la dermis papilar (~${mm}): sangra` : `llega a la dermis reticular (~${mm}): sangra y puede dejar cicatriz`,
      grasa: `atraviesa la piel (~${mm}): asoma la grasa`, fascia: `corta hasta la fascia profunda (~${mm})`, musculo: `llega al músculo (~${mm})`,
    }[id];
    out = {
      scratched: true, sev: Math.min(1, skinSeverity(depthUm) + (tearing ? 0.03 : 0)), verdict: name,
      vcol: id === "cornea" || id === "epidermis" ? C.gold : C.coral, vsub: tearing ? `la garra engancha y rasga: ${sub}` : sub,
      cede: id === "dermis" ? "la dermis" : id === "grasa" ? "piel y grasa" : id === "fascia" || id === "musculo" ? "piel, grasa y músculo" : "la epidermis",
    };
  }
  return {
    ...skinCommon, ...out, pressure, stress, muAdh: target.mu, muPlough: 0, muEff: target.mu,
    absMode: null, Dp: 0, fab: 1, wearIdx: Math.round((1500 * force * length * passN) / Hsoft),
    depthUm, layer: depthUm > 0 ? reached.name : null, where, bleeds: depthUm > epi || excoriateBleeds, ruptures, tearForce: Ft,
    tearing, puncture: false, grooveWidthUm: depthUm > 0 ? widthAt(depthUm) : 0, fullReach: cutUm > 0 && cutUm >= reachUm - 1e-6,
  };
}

/* ════════ SÓLIDOS (homogéneos y multicapa) ════════ */
function solidResult({ tool, tip, target, force, Neff, pNominal, Htool, puncture, strike, energyJ, type, fMu, lever, length, passN, tearing, common }) {
  const prof = hardnessProfile(target);
  const ratio = tool.hv / prof.hvSurf;
  const eta = hardnessEfficiency(ratio);
  const Feff = Neff * lever;
  // ¿plastifica el contacto? (en impacto la carga dinámica lo garantiza)
  const { phi: phiHertz } = plasticFraction(Feff, tip.R, tool.E, prof.Esurf, prof.Hsurf, puncture ? 1 : fMu);
  const phi = puncture && strike ? 1 : phiHertz;
  const passF = puncture ? 1 : passDepthFactor(passN);
  const m = phi * (puncture ? 1 : type.k * passF);                 // multiplicador geométrico de profundidad
  const loadShare = puncture ? 1 : 0.5;
  // Chapa fina: al romperla, la resistencia puede CAER (pétalos) → primer equilibrio por tramos, como en la piel.
  const sheet = sheetOf(target);
  const res = m <= 1e-9 ? () => Infinity
    : sheet ? makeSheetResistance(tip, prof, Htool, loadShare, m, sheet) : makeResistance(tip, prof, Htool, loadShare, m);
  // Tramos en los que la resistencia solo crece: pintura, chapa entera y pétalos mientras el agujero se
  // ensancha. Cuando ya tiene la anchura de la garra (hCap), los pétalos no piden más: desliza.
  const hCap = Number.isFinite(tip.amax) ? depthForRadius(tip, tip.amax) * Math.max(m, 1e-9) : Infinity;
  const breaks = sheet ? [sheet.from, sheet.to, ...(hCap > sheet.to ? [hCap] : [])] : [];
  let hMm = m <= 1e-9 ? 0
    : puncture && strike ? solveEnergy(energyJ * 1000, Feff, res)
      : sheet ? solveLayered(Feff, res, breaks) : solveStatic(Feff, res);

  // Límites de la herramienta: alcance (longitud útil) y rotura (colmillos). Nada entra más que su
  // propia garra o su uña libre: ni al punzar, ni al rajar una chapa, ni al rayar un sólido blando
  // (madera, plástico): con toda la garra dentro, la pata o el dedo tocan la superficie.
  const reach = tool.reach;
  let fullReach = false, toolBroken = false;
  if (hMm >= reach) { hMm = reach; fullReach = true; }
  // carga que soporta la punta: la aplicada (sin la adhesión, que es de nanonewtons), o la resistencia
  // del material si la punta ya está enterrada hasta la base o frena un golpe. En una chapa el pico llega
  // al romperla (luego los pétalos ceden con menos fuerza): cuenta el máximo del camino, no el final.
  const peakRes = (h) => Math.max(res(h), ...breaks.filter((b) => b > 0 && b < h).map((b) => res(b - 1e-9)));
  const fTool = puncture && (fullReach || strike) ? peakRes(hMm) : force * lever;
  if (tool.fBreak && fTool > tool.fBreak) {
    toolBroken = true;
    hMm = Math.min(hMm, sheet ? solveLayered(tool.fBreak, res, breaks) : solveStatic(tool.fBreak, res));
  }
  let depthUm = hMm * 1000;

  // Presión media real: nunca más que la dureza de quien cede (punta u objetivo)
  const pressure = Math.min(pNominal, Math.min(Htool, prof.Hsurf));
  const aUm = contactRadius(tip, hMm / Math.max(m, 1e-9)) * 1000;
  const contactAreaMm2 = Neff / Math.max(pressure, 1e-9);
  const chi = pNominal / prof.Hsurf;
  let through = !!target.thickness && depthUm >= target.thickness * 1000 - 1e-6;
  const holeUm = 2 * (sheet ? holeRadius(tip, hMm / Math.max(m, 1e-9)) * 1000 : aUm);   // anchura del agujero o de la raja

  // Vidrio de ventana: la hoja se parte si la carga normal la flexa hasta fg,k, o si una punta dura la
  // atraviesa. En un golpe, la fuerza de pico sale de la masa contra dos muelles en serie: la hoja (k) y el
  // tejido blando de la pata o del dedo (MODEL.limbStiffness): F = v·√(m·k_ef). Por eso un zarpazo de gato
  // no rompe una ventana y el picado de un halcón sí. A la hoja nunca llega más fuerza de la que aguanta
  // la herramienta: un colmillo se rompe antes.
  let shattered = false, paneN = null, paneJ = null, peakN = null, punched = false;
  if (target.pane) {
    const pb = paneBreak(target.pane, target.E, aUm / 1000);
    const kEff = 1 / (1 / pb.k + 1 / MODEL.limbStiffness);                      // N/mm
    const fStrike = puncture && strike ? tool.strike.v * Math.sqrt(tool.strike.m * kEff * 1000) : 0;
    paneN = pb.F; paneJ = pb.U / 1000; peakN = Math.max(Neff, fStrike);
    punched = depthUm >= target.pane.t * 1000 - 1e-6;
    const canPush = !tool.fBreak || tool.fBreak >= pb.F;
    shattered = punched || (canPush && peakN >= pb.F);
    // rota la hoja, la punta no puede estar más honda que su espesor: pasa por el hueco
    if (shattered) { depthUm = Math.min(depthUm, target.pane.t * 1000); through = depthUm >= target.pane.t * 1000 - 1e-6; }
  }

  let v = target.paint ? paintVerdict(depthUm, ratio, puncture, { target, through, fullReach, holeUm })
    : target.woodDoor ? doorVerdict(depthUm, ratio, puncture, through, target)
      : genericVerdict(depthUm, ratio, puncture, through, target, { sheet, fullReach, holeUm });
  if (shattered) {
    const { t, fgk } = target.pane;
    v = { ...v, verdict: "ROMPE EL VIDRIO", vcol: C.coral, cede: "el vidrio (en pedazos)", scratched: true, sev: 1, layer: null,
      vsub: punched ? `la punta atraviesa la hoja de ${t} mm y la parte`
        : Neff >= paneN ? `${fmtF(Neff)} N en el centro flexan la hoja de ${t} mm hasta ${fgk} MPa (se parte desde ~${fmtF(paneN)} N)`
          : `el golpe da un pico de ~${fmtF(peakN)} N: la hoja de ${t} mm flexa hasta ${fgk} MPa (se parte desde ~${fmtF(paneN)} N)` };
  }
  if (toolBroken) {
    // El daño hecho antes de romperse se conserva (capa, severidad); cambia el protagonista.
    v = { ...v, verdict: "SE ROMPE LA PUNTA", vcol: C.gold, cede: tool.fang ? "el colmillo" : "la punta",
      vsub: `el ${tool.fang ? "colmillo" : "punzón"} cede a ~${tool.fBreak} N tras entrar ${fmtDepth(depthUm)}` };
  }
  const toolWorn = ratio < MODEL.rOff;

  // ── Abrasión (Hokkirigawa-Kato 1988): Dp = h/a decide arado → cuña → corte ──
  const Dp = aUm > 0 ? depthUm / aUm : 0;
  let absMode = null, fab = 1, muPlough = 0;
  if (!puncture && depthUm > 0.5 && v.scratched) {
    muPlough = clamp(0.9 * Dp, 0, 1.2);                              // arado ≈ tan(ángulo de ataque) (Bowden-Tabor)
    if (Dp < 0.1) { absMode = "arado"; fab = clamp(Dp / 0.1 * 0.15, 0.02, 0.15); }
    else if (Dp < 0.2) { absMode = "cuña"; fab = clamp(0.15 + (Dp - 0.1) / 0.1 * 0.45, 0.15, 0.6); }
    else { absMode = "corte"; fab = clamp(0.6 + (Dp - 0.2) * 2, 0.6, 1); }
  }
  const muEff = target.mu + muPlough;
  const HsoftHV = (toolWorn ? Htool : Math.min(Htool, prof.Hsurf)) / HV_MPA;
  // Archard da el volumen deformado; lo arrancado es fab·volumen. Sin surco solo hay pulido (2 %,
  // el mínimo del arado): así un roce nunca "desgasta" más que un arañazo.
  const wearIdx = puncture
    ? Math.round((400 * force * (strike ? 2 : 1)) / Math.max(HsoftHV, 5))
    : Math.round((1500 * force * length * passN * (absMode ? fab : 0.02)) / Math.max(HsoftHV, 5));
  return {
    ...common, ...v, pressure, ratio, chi, stress: null, toolWorn, depthUm, sev: v.sev,
    Ffric: puncture ? target.mu * Neff : muEff * Neff, muAdh: target.mu, muPlough, muEff, absMode, Dp, fab, wearIdx,
    tearing, puncture, inject: false, pierces: puncture ? depthUm > 1 : undefined, energyJ, toolBroken, fullReach, through,
    shattered, paneN, peakN,
    // energía que se queda el material: en una hoja rota, la que la partió (después la punta pasa por el hueco)
    workJ: shattered ? paneJ : absorbedWork(res, depthUm / 1000, breaks),
    tHV: prof.hvSurf, tMohs: target.mohs, phi, eta, grooveWidthUm: holeUm, contactAreaMm2,
  };
}

/** Coche: qué capa de pintura cede y, debajo, qué le pasa a la carrocería (marcarla, perforarla, que la
 *  herramienta entera la atraviese o, rayando, rajarla de lado a lado). */
function paintVerdict(depthUm, ratio, puncture, { target, through, fullReach, holeUm }) {
  const L = carLayers(target), body = target.body;
  const paintUm = PAINT_LAYERS.at(-1).to, bodyEnd = paintUm + body.t;
  const hit = L.find((l) => depthUm <= l.to) || L[L.length - 1];
  const sev = clamp(depthUm / paintUm, puncture ? 0.05 : 0, 1);
  const BODY = body.metal ? "LA CHAPA" : "EL PLÁSTICO", bodyLayer = body.metal ? "metal (chapa)" : "plástico";
  const thick = fmtDepth(body.t), hole = fmtDepth(holeUm);
  if (ratio < MODEL.rOff || depthUm < 1.5) {
    return puncture
      ? { verdict: "APENAS ROZA", vcol: C.mint, vsub: "marca mínima en el barniz", cede: "nada (pulible)", scratched: false, layer: "barniz", sev }
      : { verdict: "ROZA / REMOLINO", vcol: C.mint, vsub: "marca de barniz pulible, no penetra", cede: "nada (pulible)", scratched: false, layer: "barniz · superficie", sev };
  }
  if (puncture) {
    if (through && fullReach) {
      return { verdict: `ATRAVIESA ${BODY}`, vcol: C.coral, vsub: `la punta entera pasa al otro lado: agujero de ~${hole} en ${body.long} de ${thick}`,
        cede: `${body.noun} (de lado a lado)`, scratched: true, layer: bodyLayer, sev: 1 };
    }
    if (through) {
      return { verdict: `PERFORA ${BODY}`, vcol: C.coral, vsub: `la punta sale ~${fmtDepth(depthUm - bodyEnd)} por detrás · agujero de ~${hole} con pétalos`,
        cede: `${body.noun} (perforada)`, scratched: true, layer: bodyLayer, sev: 0.92 };
    }
    const inBody = depthUm > paintUm + 1;
    return { verdict: "PUNCIÓN", vcol: C.coral, cede: hit.cede, scratched: true, layer: hit.id, sev,
      vsub: inBody ? `atraviesa la pintura y se clava ~${fmtDepth(depthUm - paintUm)} en ${body.noun} (de ${thick})` : `agujero hasta ${hit.cede}` };
  }
  if (through) {
    return { verdict: `RAJA ${BODY}`, vcol: C.coral, vsub: `corta ${body.noun} de ${thick} de lado a lado: raja de ~${hole} de ancho`,
      cede: `${body.noun} (rajada)`, scratched: true, layer: bodyLayer, sev: 1 };
  }
  const table = {
    barniz: ["ARAÑAZO EN BARNIZ", C.gold, "queda en el clearcoat · se pule", "faint", "barniz (clearcoat)"],
    color: ["LLEGA AL COLOR", C.coral, "atraviesa el barniz · necesita retoque", true, "color (basecoat)"],
    imprimacion: ["HASTA IMPRIMACIÓN", C.coral, "se ve gris/blanco del primer", true, "imprimación (primer)"],
    anticorrosivo: body.metal ? ["HASTA ANTICORROSIVO", C.coral, "expone el e-coat", true, "anticorrosivo (e-coat)"]
      : ["HASTA EL PROMOTOR", C.coral, "queda el promotor de adherencia sobre el plástico", true, "promotor de adherencia"],
    carroceria: body.metal ? ["HASTA EL METAL", C.coral, "chapa expuesta · riesgo de óxido", true, bodyLayer]
      : ["HASTA EL PLÁSTICO", C.coral, "plástico al aire: se ve el material sin pintar", true, bodyLayer],
  };
  const reachedBody = depthUm > paintUm - 1e-6;
  const [verdict, vcol, vsub0, scratched, layer] = table[reachedBody ? "carroceria" : hit.id];
  const vsub = reachedBody && depthUm > paintUm + 5 ? `${vsub0} · surco de ~${fmtDepth(depthUm - paintUm)} en ${body.noun} de ${thick}` : vsub0;
  return { verdict, vcol, vsub, cede: reachedBody ? body.noun : hit.cede, scratched, layer, sev };
}

function doorVerdict(depthUm, ratio, puncture, through, target) {
  const lacaUm = target.layers.film.t, thickUm = target.thickness * 1000;
  const sev = clamp(sevLog(depthUm, thickUm), 0.05, 1);
  const layer = depthUm <= lacaUm ? "laca" : "madera";
  if (ratio < MODEL.rOff || depthUm < 1.5) {
    return puncture
      ? { verdict: "APENAS ROZA", vcol: C.mint, vsub: "marca mínima en la laca", cede: "nada", scratched: false, layer, sev }
      : { verdict: "ROZA LA LACA", vcol: C.mint, vsub: "marca superficial pulible, no penetra la laca", cede: "nada (pulible)", scratched: false, layer: "laca · superficie", sev };
  }
  if (through) return { verdict: "ATRAVIESA LA PUERTA", vcol: C.coral, vsub: "de lado a lado — ¡aquí está Johnny!", cede: "la puerta entera", scratched: true, layer: "madera", sev: 1 };
  if (depthUm <= lacaUm) {
    return puncture
      ? { verdict: "PUNCIÓN EN LA LACA", vcol: C.gold, vsub: `agujero de ~${depthUm.toFixed(0)} µm, solo el barniz`, cede: "la laca", scratched: true, layer, sev }
      : { verdict: "ARAÑAZO EN LA LACA", vcol: C.gold, vsub: `queda en el barniz (~${depthUm.toFixed(0)} µm) · se pule`, cede: "la laca", scratched: "faint", layer: "laca (barniz)", sev };
  }
  return puncture
    ? { verdict: "CLAVADA EN LA MADERA", vcol: C.coral, vsub: `entra ~${fmtDepth(depthUm)} de los ${target.thickness} mm; falta para atravesar`, cede: "la madera", scratched: true, layer, sev }
    : { verdict: "LLEGA A LA MADERA", vcol: C.coral, vsub: `atraviesa la laca y entra ~${(depthUm / 1000).toFixed(2)} mm en la madera desnuda`, cede: "la madera", scratched: true, layer, sev };
}

function genericVerdict(depthUm, ratio, puncture, through, target, { sheet, fullReach, holeUm }) {
  const name = target.name.toLowerCase();
  if (puncture) {
    const fullUm = target.thickness ? target.thickness * 1000 : 200;
    if (ratio < MODEL.rOff) return { verdict: "NO PERFORA", vcol: C.mint, vsub: "la punta se embota/rompe antes de entrar", cede: "la punta", scratched: false, sev: 0.06, layer: null };
    // Chapa fina: romperla (la punta asoma) no es lo mismo que la herramienta entera pase al otro lado.
    if (through && sheet && !fullReach) {
      return { verdict: "PERFORA LA PUERTA", vcol: C.coral, vsub: `la punta sale ~${fmtDepth(depthUm - fullUm)} por detrás · agujero de ~${fmtDepth(holeUm)} con pétalos`,
        cede: "la puerta de metal (perforada)", scratched: true, sev: 0.92, layer: null };
    }
    if (through) return { verdict: "ATRAVIESA LA PUERTA", vcol: C.coral, vsub: `de lado a lado (${target.thickness} mm de metal perforados)`, cede: "la puerta de metal", scratched: true, sev: 1, layer: null };
    if (depthUm > 1) {
      return {
        verdict: target.brittle ? "PERFORA · ASTILLA" : "PERFORA", vcol: C.coral,
        vsub: target.brittle ? `microfractura: pozo de punción en ${name}` : `pozo de punción ~${fmtDepth(depthUm)}${target.thickness ? ` de ${target.thickness} mm` : ""}`,
        cede: `${name} (pozo)`, scratched: true, sev: clamp(sevLog(depthUm, fullUm), 0.1, 1), layer: null,
      };
    }
    return { verdict: "APENAS MARCA", vcol: C.gold, vsub: `pozo incipiente ~${depthUm.toFixed(1)} µm (sube la fuerza)`, cede: name, scratched: false, sev: 0.06, layer: null };
  }
  const sev = sevLog(depthUm, 100);
  if (ratio < MODEL.rOff) return { verdict: "NO RAYA", vcol: C.mint, vsub: "más blanda: la punta se desgasta", cede: "tu punta", scratched: false, sev: 0, layer: null };
  if (through && sheet) {
    return { verdict: "RAJA LA PUERTA", vcol: C.coral, vsub: `corta los ${target.thickness} mm de metal de lado a lado: raja de ~${fmtDepth(holeUm)} de ancho`,
      cede: "la puerta de metal (rajada)", scratched: true, sev: 1, layer: null };
  }
  if (depthUm < 0.05) return { verdict: "ROZA SIN MARCAR", vcol: C.mint, vsub: ratio >= 1.25 ? "más dura, pero contacto elástico (presión insuficiente)" : "dureza similar y poca presión", cede: "nada (desliza)", scratched: false, sev: 0, layer: null };
  if (ratio < 1.25) return { verdict: "MARCA TENUE", vcol: C.gold, vsub: "dureza similar · pulido mutuo", cede: "ambos por igual", scratched: "faint", sev, layer: null };
  if (depthUm < 1) return { verdict: "RAYA LEVE", vcol: C.gold, vsub: target.brittle ? "microrraya con astillado incipiente" : "surco incipiente", cede: `${name} (leve)`, scratched: "faint", sev, layer: null };
  return { verdict: "RAYA", vcol: C.coral, vsub: target.brittle ? "surco con microfractura (astillado lateral)" : "surco plástico claro", cede: name, scratched: true, sev, layer: null };
}
