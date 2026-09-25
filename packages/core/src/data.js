/* ════════ DATA ════════
   Dureza Vickers (HV, kgf/mm²) + Mohs orientativo. Áreas en mm², fuerzas en N, masas en kg,
   módulos de Young E en GPa, longitudes (reach) en mm, ángulos en grados, velocidades en m/s.
   Cualquier valor nuevo debe documentar su fuente o marcarse como estimación en docs/FISICA.md.

   Geometría de punta (modelo esfero-cónico, ver physics.js):
   · area  → "afilado": área de la punta; su radio equivalente es R = √(area/π).
   · alpha → semiángulo del cono de la punta (cuanto menor, más aguda). Estimación salvo colmillos.
   · reach → lo máximo que la punta puede hundirse antes de que tope la base (uña libre, garra, colmillo). */

// Formas de uña: área de contacto de la punta y semiángulo en planta (estimaciones de salón).
// curl: curvatura "de pinza" del borde libre hacia abajo (solo dibujo de la vista lateral).
export const GEOMS = [
  { id: "cuadrada", name: "Cuadrada", area: 9.0, alpha: 75, reach: 4, curl: 0.1, ay: 48, path: "M28 150 L28 60 Q28 48 40 48 L60 48 Q72 48 72 60 L72 150 Z" },
  { id: "redonda", name: "Redonda", area: 3.5, alpha: 65, reach: 4, curl: 0.2, ay: 50, path: "M28 150 L28 72 Q28 50 50 50 Q72 50 72 72 L72 150 Z" },
  { id: "coffin", name: "Ataúd", area: 2.8, alpha: 55, reach: 6, curl: 0.25, ay: 46, path: "M30 150 L30 74 L44 46 L56 46 L70 74 L70 150 Z" },
  { id: "almendra", name: "Almendra", area: 0.9, alpha: 40, reach: 6, curl: 0.4, ay: 36, path: "M30 150 L30 80 Q34 42 50 36 Q66 42 70 80 L70 150 Z" },
  { id: "stiletto", name: "Stiletto", area: 0.15, alpha: 22, reach: 8, curl: 0.6, ay: 26, path: "M30 150 L30 84 Q38 40 50 26 Q62 40 70 84 L70 150 Z" },
  { id: "stilettoxl", name: "Stiletto XL", area: 0.08, alpha: 16, reach: 12, curl: 1.0, ay: 14, path: "M31 150 L31 88 Q35 42 50 6 Q65 42 69 88 L69 150 Z" },
];
// keratin: la queratina se ablanda con el agua (modo "húmeda"). Gel y acrílico son polímeros: no.
// Experimentos: la uña ENTERA de otro material (no una gema en la punta): manda su dureza con la
// geometría de la forma elegida. Durezas y módulos de manual, los mismos que sus incrustaciones.
export const BASES = [
  { id: "natural", group: "Salón", name: "Uña natural", short: "Queratina", hv: 25, mohs: 2.5, E: 2.9, keratin: true },
  { id: "gel", group: "Salón", name: "Gel UV", short: "Gel", hv: 30, mohs: 3.0, E: 2.5 },
  { id: "acrilico", group: "Salón", name: "Acrílico", short: "Acrílico", hv: 22, mohs: 3.0, E: 3.0 },
  { id: "metal", group: "Experimentos", name: "Acero macizo", short: "Acero", hv: 200, mohs: 5.5, E: 200, desc: "Uña entera de acero inoxidable: raya plásticos, madera y cobre; contra otro acero, empate (marca tenue). Nunca el vidrio (HV 200 < 550)." },
  { id: "titanio", group: "Experimentos", name: "Titanio macizo", short: "Titanio", hv: 150, mohs: 6.0, E: 105, desc: "Ligero y tenaz, pero más blando que el acero (Mohs alto, Vickers modesto): raya plástico y cobre; el acero inoxidable ya no." },
  { id: "zafiro", group: "Experimentos", name: "Zafiro puro", short: "Zafiro", hv: 2000, mohs: 9.0, E: 400, desc: "Corindón macizo: raya el acero con cualquier forma; vidrio, pantalla y cuarzo, cuanto más fina es la punta (una punta roma se queda en contacto elástico). Frágil: se desconcharía con un golpe." },
  { id: "diamante", group: "Experimentos", name: "Diamante puro", short: "Diamante", hv: 10000, mohs: 10, E: 1050, desc: "Lo más duro del banco: con punta fina raya hasta el zafiro; con punta roma, el contacto con lo duro se queda elástico. Contra otro diamante, empate técnico." },
];
export const BASE_GROUPS = ["Salón", "Experimentos"];
// Gemas y metales: punta facetada o tachuela; semiángulo común de 50° (estimación).
const GEM_ALPHA = 50;
export const INLAYS = [
  { id: "none", name: "Sin incrustación", short: "—", hv: null, area: null, col: null },
  { id: "oro", name: "Pan de oro", short: "Oro", hv: 30, mohs: 2.5, E: 79, area: 0.40, alpha: GEM_ALPHA, col: "#E6C36B" },
  { id: "acero", name: "Tachuela de acero", short: "Acero", hv: 200, mohs: 5.5, E: 200, area: 0.12, alpha: GEM_ALPHA, col: "#C7CDD6" },
  { id: "titanio", name: "Titanio", short: "Titanio", hv: 150, mohs: 6.0, E: 105, area: 0.12, alpha: GEM_ALPHA, col: "#B8BFC7" },
  { id: "tungsteno", name: "Carburo de tungsteno", short: "Tungsteno", hv: 2000, mohs: 9.0, E: 620, area: 0.08, alpha: GEM_ALPHA, col: "#787E86" },
  { id: "vidrio", name: "Strass de vidrio", short: "Strass", hv: 550, mohs: 5.5, E: 70, area: 0.15, alpha: GEM_ALPHA, col: "#EAF6FF" },
  { id: "swarovski", name: "Cristal Swarovski", short: "Swarovski", hv: 600, mohs: 6.0, E: 60, area: 0.10, alpha: GEM_ALPHA, col: "#DCEFFF" },
  { id: "hematites", name: "Hematites", short: "Hematites", hv: 1000, mohs: 6.0, E: 200, area: 0.12, alpha: GEM_ALPHA, col: "#5A5560" },
  { id: "cuarzo", name: "Cuarzo (cristal roca)", short: "Cuarzo", hv: 1100, mohs: 7.0, E: 95, area: 0.10, alpha: GEM_ALPHA, col: "#F0EAF4" },
  { id: "circonita", name: "Circonita (CZ)", short: "CZ", hv: 1300, mohs: 8.0, E: 210, area: 0.08, alpha: GEM_ALPHA, col: "#E8F4FF" },
  { id: "zafiro", name: "Zafiro", short: "Zafiro", hv: 2000, mohs: 9.0, E: 400, area: 0.07, alpha: GEM_ALPHA, col: "#7FB6FF" },
  { id: "moissanita", name: "Moissanita (SiC)", short: "Moissanita", hv: 2800, mohs: 9.25, E: 440, area: 0.05, alpha: GEM_ALPHA, col: "#EAF7E9" },
  { id: "diamante", name: "Diamante", short: "Diamante", hv: 10000, mohs: 10, E: 1050, area: 0.04, alpha: GEM_ALPHA, col: "#FFFFFF" },
];
// La mano humana: fuerza máxima de un arañazo decidido con una uña y golpe de dedo (estimaciones).
export const HUMAN = { force: 30, strike: { v: 5, m: 0.4 } };

// Módulo de la queratina de garra a ~50 % HR: 2,0 GPa (garra de avestruz, Bonser; en McKittrick 2012).
const KERATIN_E = 2.0;
// Dentina de colmillo: módulo típico de dentina (~18 GPa) · dureza 0,4-0,6 GPa (Estrada et al. 2026).
const DENTIN_E = 18;
// Garras y talones: queratina (Mohs ~2,5-3), NO más duras que la uña.
// Lo que cambia es el afilado (área, semiángulo), la curvatura (gancho) y la fuerza/energía detrás.
// strike: velocidad (m/s) y masa efectiva (kg) del golpe → energía ½·m·v². Estimaciones salvo víboras.
export const CLAWS = [
  // ── Mamíferos ──
  { id: "gato", group: "Mamíferos", name: "Gato", hv: 28, mohs: 2.8, E: KERATIN_E, area: 0.02, alpha: 14, reach: 10, curve: 0.80, mass: 4.5, force: 15, strike: { v: 4, m: 0.15 }, col: "#E9DCC8", desc: "Retráctil y afiladísima. Punta diminuta → presión brutal pese a poca fuerza. Fuerza de zarpazo estimada." },
  { id: "tigre", group: "Mamíferos", name: "Tigre", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.06, alpha: 16, reach: 40, curve: 0.80, mass: 220, force: 260, strike: { v: 8, m: 3 }, col: "#D9C49E", desc: "Un gato gigante: retráctil, curva y muy afilada, con muchísima fuerza detrás. Fuerza y golpe estimados." },
  { id: "oso", group: "Mamíferos", name: "Oso pardo", hv: 26, mohs: 2.7, E: KERATIN_E, area: 0.50, alpha: 26, reach: 60, curve: 0.55, mass: 300, force: 300, strike: { v: 7, m: 4 }, col: "#46392E", desc: "Enorme y curva pero roma (excava): mucha fuerza repartida en punta ancha. Fuerza y golpe estimados." },
  // ── Rapaces ── (agarre escalado desde mediciones in vivo: Sustaita & Hertel 2010)
  { id: "aguila", group: "Rapaces", name: "Águila", hv: 32, mohs: 3.0, E: KERATIN_E, area: 0.04, alpha: 15, reach: 35, curve: 0.85, mass: 5, force: 110, strike: { v: 12, m: 1 }, col: "#2E2A26", desc: "Talón de rapaz (queratina-β tenaz). Agarre estimado escalando el medido en gavilanes (~22 N por kg de ave)." },
  { id: "arpia", group: "Rapaces", name: "Águila arpía", hv: 33, mohs: 3.0, E: KERATIN_E, area: 0.06, alpha: 15, reach: 40, curve: 0.90, mass: 9, force: 200, strike: { v: 9, m: 1.8 }, col: "#3A3530", desc: "La rapaz más poderosa: talón trasero de ~12-13 cm, caza monos y perezosos en la copa. Agarre estimado (escalado por masa)." },
  { id: "halcon", group: "Rapaces", name: "Halcón peregrino", hv: 32, mohs: 3.0, E: KERATIN_E, area: 0.02, alpha: 15, reach: 18, curve: 0.85, mass: 1, force: 15, strike: { v: 40, m: 0.25 }, col: "#5A5048", desc: "Garra corta y muy afilada. Los halcones agarran menos que los gavilanes (rematan con el pico), pero golpean en picado a >300 km/h: su arma es la energía." },
  { id: "buho", group: "Rapaces", name: "Búho", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.03, alpha: 15, reach: 30, curve: 0.85, mass: 2, force: 45, strike: { v: 6, m: 0.5 }, col: "#4A4034", desc: "Garra silenciosa, curvatura cerrada y punta de aguja. Agarre estimado (escalado por masa)." },
  { id: "lechuza", group: "Rapaces", name: "Lechuza", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.015, alpha: 13, reach: 15, curve: 0.85, mass: 0.35, force: 8, strike: { v: 5, m: 0.08 }, col: "#C8B090", desc: "Rapaz nocturna ligera: agujas finísimas y trinquete tendinoso que bloquea el cierre (por eso cuesta soltarla)." },
  { id: "buitre", group: "Rapaces", name: "Buitre leonado", hv: 28, mohs: 2.8, E: KERATIN_E, area: 0.30, alpha: 28, reach: 25, curve: 0.45, mass: 8, force: 60, strike: { v: 2, m: 1 }, col: "#6B5A45", desc: "Carroñero: garras romas para caminar, no para agarrar. Mucho pájaro, poca garra. Fuerza estimada." },
  // ── Aves corredoras (ratites) ──
  { id: "casuario", group: "Aves corredoras", name: "Casuario", hv: 32, mohs: 3.0, E: KERATIN_E, area: 0.05, alpha: 14, curve: 0.25, mass: 60, force: 500, reach: 110, strike: { v: 8, m: 5 }, col: "#1F2A44", desc: "El ave más peligrosa: daga recta de ~10-12 cm en el dedo interno y patada a 50 km/h. En Punción + Impacto se comporta como una puñalada. Fuerza y energía de la patada estimadas." },
  { id: "emu", group: "Aves corredoras", name: "Emú", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.12, alpha: 22, curve: 0.30, mass: 40, force: 300, reach: 40, strike: { v: 7, m: 2.5 }, col: "#7A6A55", desc: "Pariente del casuario pero sin la daga: tres garras robustas y patada fuerte, menos afiladas. Fuerza estimada." },
  { id: "avestruz", group: "Aves corredoras", name: "Avestruz", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.35, alpha: 32, curve: 0.20, mass: 120, force: 900, reach: 60, strike: { v: 10, m: 8 }, col: "#8A7D6B", desc: "El ave más pesada: solo dos dedos, uña gruesa casi pezuña. Patada brutal pero punta roma. Fuerza estimada." },
  // ── Otras aves ──
  { id: "gallo", group: "Otras aves", name: "Gallo", title: "Espolón de gallo", hv: 28, mohs: 2.8, E: KERATIN_E, area: 0.04, alpha: 16, curve: 0.35, mass: 3, force: 40, reach: 25, strike: { v: 5, m: 0.4 }, col: "#B5793A", desc: "Espolón de queratina sobre núcleo óseo en la pata. En pelea salta y golpea: pequeño pero traicionero." },
  { id: "guacamayo", group: "Otras aves", name: "Guacamayo", hv: 30, mohs: 3.0, E: KERATIN_E, area: 0.03, alpha: 18, reach: 15, curve: 0.80, mass: 1.2, force: 25, strike: { v: 1.5, m: 0.1 }, col: "#3F6FB5", desc: "Pata zigodáctila (2 dedos delante, 2 detrás) para trepar y agarrar. El peligro real es el pico, no la garra." },
  { id: "pajaro", group: "Otras aves", name: "Pájaro", hv: 26, mohs: 2.6, E: KERATIN_E, area: 0.02, alpha: 16, reach: 4, curve: 0.70, mass: 0.03, force: 1.5, strike: { v: 1, m: 0.01 }, col: "#C9B8A0", desc: "Fina y afilada pero frágil: apenas puede aplicar fuerza, y su uña mide pocos milímetros." },
  // ── Reptiles ── (Estrada et al. 2026: dentina 0,4-0,6 GPa; rotura a ~30 N; ataque a 2,0-2,6 m/s y 2,5-3,0 J)
  { id: "vibora", group: "Reptiles", name: "Colmillo de víbora", hv: 50, mohs: 3.5, E: DENTIN_E, area: 0.008, alpha: 17, curve: 0.90, mass: 1, force: 4, fBreak: 30, fang: true, reach: 18, strike: { v: 2.8, m: 0.35 }, col: "#E4E0D8", desc: "Aguja hipodérmica evolucionada: la punta más fina del lab. Pincha casi sin fuerza. Colmillos hidratados aguantan ~30 N antes de romperse por la punta. No aprieta: inyecta." },
  { id: "gabon", group: "Reptiles", name: "Colmillo de Gabón", hv: 50, mohs: 3.5, E: DENTIN_E, area: 0.012, alpha: 15, curve: 0.85, mass: 9, force: 20, fBreak: 30, fang: true, reach: 50, strike: { v: 2.5, m: 1.0 }, col: "#C9B79A", desc: "Los colmillos más largos del mundo (~5 cm). Víbora pesada y robusta: más fuerza y muchísimo más alcance. Inyecta a varios centímetros de profundidad." },
];
export const CLAW_GROUPS = ["Mamíferos", "Rapaces", "Aves corredoras", "Otras aves", "Reptiles"];
export const clawTitle = (c) => c.title || (c.fang ? c.name : `Garra de ${c.name.toLowerCase()}`);

// Pintura OEM de coche: capas acumuladas (µm). La física y los cortes de la UI usan esta misma tabla.
// Debajo va la carrocería de cada coche (CAR_BODIES): carLayers() la añade como última capa.
export const PAINT_LAYERS = [
  { id: "barniz", name: "Barniz", from: 0, to: 45, col: "#AED2E0", cede: "el barniz (clearcoat)" },
  { id: "color", name: "Color", from: 45, to: 60, col: "#7E2B3A", cede: "el color (basecoat)" },
  { id: "imprimacion", name: "Imprimación", from: 60, to: 85, col: "#9AA0A6", cede: "la imprimación" },
  { id: "anticorrosivo", name: "Anticorrosivo", from: 85, to: 110, col: "#5E6B52", cede: "el anticorrosivo (e-coat)" },
];

/* Carrocerías (lo que hay debajo de la pintura). t: espesor (µm). hv y E: dureza y módulo. σ0 (MPa):
   tensión de flujo media de Wierzbicki (1999, ec. 65), σ0 = √(σy·σu/(1+n)), la que manda cuando la
   chapa se abre en pétalos. La dureza de los metales sale de Tabor con endurecimiento de Hollomon:
   H = 2,8·σ(ε = 8 %), σ = K·εⁿ, K = σu·(e/n)ⁿ. Fuentes y cuentas: docs/FISICA.md, apartado 14. */
export const CAR_BODIES = {
  // Acero de horno (bake hardening) tipo HC180B: 0,7 mm (Nippon Steel 2013); Rp0,2 180-230 MPa + 35 al
  // hornear la pintura, Rm 290-360 (usamos 340, Nippon), n ≥ 0,17 (voestalpine).
  moderno: { id: "acero-bh", name: "Acero BH", long: "acero de horno (HC180B)", noun: "la chapa", metal: true,
    t: 700, hv: 101, E: 210, sigma0: 264, col: "#C3CAD2" },
  // Acero dulce de embutición (equivalente moderno: DC04, Re 140-210, Rm 270-350, n ≥ 0,18,
  // ArcelorMittal). Espesor: ESTIMACIÓN de 0,9 mm (calibre 20), antes de reducir espesores.
  clasico: { id: "acero-dulce", name: "Acero dulce", long: "acero dulce (tipo DC04)", noun: "la chapa", metal: true,
    t: 900, hv: 92, E: 210, sigma0: 214, col: "#B9C0C8" },
  // Aluminio AA6016 tras el horneado de la pintura: Rp0,2 212 MPa, Rm 273, n 0,30 (Prillhofer 2014);
  // paneles exteriores de 0,8-1,25 mm (Hirsch 2011): usamos 1,0 mm.
  aluminio: { id: "aluminio", name: "Aluminio", long: "aluminio AA6016", noun: "la chapa", metal: true,
    t: 1000, hv: 71, E: 70, sigma0: 211, col: "#DCE3EA" },
  // Termoplástico PPE/PA (Noryl GTX964W, SABIC): fluencia 44-50 MPa, rotura al 50-56 %. Aletas en más
  // de 10 millones de coches desde 2001 (GE Plastics 2007). Espesor: ESTIMACIÓN de 2,5 mm (misma aleta
  // con la mitad de peso que el acero de 0,7 mm). Dureza por Tabor desde la fluencia (aprox. en polímeros).
  plastico: { id: "plastico-carroceria", name: "Plástico PPE/PA", long: "termoplástico PPE/PA (Noryl GTX)", noun: "el plástico", metal: false,
    t: 2500, hv: 13, E: 1.8, sigma0: 47, col: "#3B4046" },
};
/** Capas de un coche: la pintura común y, debajo, su carrocería. En plástico no hay e-coat: la capa de
 *  25 µm es un promotor de adherencia. `null` si el material no es un coche. */
export function carLayers(target) {
  const body = target && target.body;
  if (!body) return null;
  const paint = body.metal ? PAINT_LAYERS
    : PAINT_LAYERS.map((l) => (l.id === "anticorrosivo" ? { ...l, name: "Promotor de adherencia", cede: "el promotor de adherencia" } : l));
  const top = PAINT_LAYERS.at(-1).to;
  return [...paint, { id: "carroceria", name: body.name, from: top, to: top + body.t, col: body.col, cede: body.noun }];
}

/* Piel humana por capas, en la cara posterior del brazo de un adulto (zona típica de un arañazo o una
   mordedura). Profundidades acumuladas en µm. En tejido blando no existe dureza Vickers: se describe
   con su rigidez (E, kPa) y su tenacidad (J, kJ/m² = N/mm), la energía para abrir una grieta.
   · jT: tenacidad al desgarro (ensayo de "pantalón"): la que gasta una garra que arrastra y rasga.
   · jC: tenacidad al corte: la que gasta una punta que entra de frente (grieta plana en modo I).
   Fuentes y estimaciones: docs/FISICA.md, apartado 7. */
export const SKIN_LAYERS = [
  { id: "cornea", name: "Capa córnea", short: "Capa córnea", from: 0, to: 18, jT: 17, jC: 1.7, E: null, col: "#F4E3D3",
    note: "células muertas; se despega con 1-8 J/m²: un roce la blanquea" },
  { id: "epidermis", name: "Epidermis viva", short: "Epidermis", from: 18, to: 75, jT: 17, jC: 1.7, E: null, col: "#EDB9A0",
    note: "sin vasos: una herida que solo llega aquí no sangra" },
  { id: "dermis", name: "Dermis", short: "Dermis", from: 75, to: 2200, jT: 17, jC: 1.7, E: 210, col: "#D98A86",
    note: "colágeno y capilares (arriba, en las papilas): sangra y aguanta ~22 MPa" },
  { id: "grasa", name: "Hipodermis (grasa)", short: "Grasa", from: 2200, to: 13000, jT: 4.1, jC: 0.41, E: 1.9, col: "#F1D27A",
    note: "lóbulos de grasa: la punta avanza con muy poca fuerza" },
  { id: "fascia", name: "Fascia profunda", short: "Fascia", from: 13000, to: 13300, jT: 2.1, jC: 0.21, E: null, col: "#E4E6EC",
    note: "lámina de colágeno que envuelve el músculo" },
  { id: "musculo", name: "Músculo", short: "Músculo", from: 13300, to: 60000, jT: 0.84, jC: 0.084, E: 53, col: "#A8363F",
    note: "fibras musculares; la herida ya es intramuscular" },
];

/** Coche: la pintura OEM (110 µm, 20 HV) sobre su carrocería. `thickness` es el total que hay que
 *  atravesar (pintura + chapa) para perforarla. */
const carTarget = (id, name, body, col, fact) => ({
  id, name, hv: 20, E: 3.2, mohs: null, col, paint: true, body, mu: 0.5, W: 0.04,
  thickness: (PAINT_LAYERS.at(-1).to + body.t) / 1000,
  layers: { kind: "paint-on-body", film: { name: "pintura", hv: 20, E: 3.2, t: PAINT_LAYERS.at(-1).to }, sub: body },
  fact,
});
const PAINT_FACT = "Pintura OEM: barniz ~45 µm · color ~15 · imprimación ~25 · anticorrosivo (e-coat) ~25. El barniz es un polímero blando (0,2-0,4 GPa por nanoindentación): se marca con remolinos, pero lo que solo llega al barniz se pule.";

/* Materiales. E en GPa. layers: sistemas multicapa con dureza compuesta que varía con la profundidad
   ("paint-on-body": pintura sobre la carrocería de un coche; "hard-on-soft": laca dura sobre madera blanda).
   Chapas finas (coches y puerta de aluminio): `sigma0` es la tensión de flujo que resiste los pétalos
   cuando la punta ya la ha roto (Wierzbicki 1999). Vidrio: `pane` es la hoja que se parte al flexar. */
export const TARGETS = [
  { id: "piel", name: "Piel", hv: 8, mohs: null, col: "#E8B89A", skin: true, tissue: SKIN_LAYERS, mu: 0.5, W: 0.05, fact: "El tejido vivo no está en Mohs: se mide por capas. Capa córnea y epidermis (~75 µm, sin vasos), dermis (~2 mm, la que aguanta y sangra), grasa (~11 mm en el brazo), fascia y músculo. Perforarla exige una fuerza que crece con el área de la punta (0,1-3 N con microagujas, in vivo); arrastrando, una garra desgarra y una uña roma solo levanta la capa córnea." },
  { id: "madera", name: "Madera de pino", hv: 2.5, E: 0.8, mohs: 1.6, col: "#C79A5E", mu: 0.4, W: 0.03, fact: "Blanda y fibrosa: dureza Janka del pino silvestre 2.420 N, unos 24 MPa (~2,5 HV). Dúctil: hace falta poca presión para arar." },
  { id: "puertamadera", name: "Puerta de madera barnizada", hv: 5, E: 1.0, mohs: 1.8, col: "#9A6B3A", woodDoor: true, thickness: 35, fibrous: true, mu: 0.4, W: 0.03,
    layers: { kind: "hard-on-soft", film: { name: "laca", hv: 18, E: 2.0, t: 30 }, sub: { name: "madera", hv: 5, E: 1.0 } },
    fact: "Como el coche pero al revés de grosores: una laca fina y dura (~30 µm) sobre roble macizo de ~35 mm (Janka 4.980 N, ~5 HV). La laca se raya y se pule; la madera cede fácil (y encima la laca se hunde con ella: efecto cáscara de huevo). Atravesarla DE LADO A LADO (estilo El Resplandor) pide impacto y una garra larguísima: un empuje estático no basta." },
  // σ0: ESTIMACIÓN con valores típicos de manual de la aleación de perfilería 6063-T5 (σy 145, σu 186, n 0,10).
  { id: "puertametal", name: "Puerta de aluminio (casa)", hv: 60, E: 69, mohs: 2.8, col: "#9CA3AA", thickness: 1.5, sigma0: 157, mu: 0.5, W: 0.02, fact: "Chapa de aluminio de ~1,5 mm. Una punta blanda (dentina, queratina, uña) ni la marca. Un punzón duro (acero, tungsteno, zafiro, diamante) primero la rompe y luego abre el agujero en pétalos: perforarla es fácil, que pase la garra entera cuesta mucha más energía." },
  { id: "una", name: "Uña ajena", hv: 25, E: 2.9, mohs: 2.5, col: "#F0D9D0", mu: 0.3, W: 0.04, fact: "Queratina contra queratina (HV~25): empate técnico, se pulen mutuamente." },
  { id: "plastico", name: "Plástico ABS", hv: 16, E: 2.3, mohs: 2.8, col: "#5C6B7A", mu: 0.4, W: 0.04, fact: "HV~16, dúctil. El acrílico apenas lo iguala; las gemas lo aran fácil." },
  carTarget("coche", "Coche moderno", CAR_BODIES.moderno, "#7E2B3A",
    `${PAINT_FACT} Debajo, chapa de acero de horno de 0,7 mm: la pintura endurece el acero al hornearla. La queratina no la corta; una punta dura la perfora y, con energía de sobra, la atraviesa.`),
  carTarget("cocheclasico", "Coche clásico", CAR_BODIES.clasico, "#2F5D4F",
    `${PAINT_FACT} Debajo, acero dulce más grueso (~0,9 mm, estimación): más blando que el de ahora, pero hay más metal que romper y que abrir en pétalos.`),
  carTarget("cochealu", "Coche de aluminio", CAR_BODIES.aluminio, "#8FA6BC",
    `${PAINT_FACT} Debajo, aluminio AA6016 de 1,0 mm: más blando que el acero, por eso se usa más grueso (0,8-1,25 mm) para aguantar lo mismo.`),
  carTarget("cocheplastico", "Aleta de plástico", CAR_BODIES.plastico, "#E4E2DC",
    `${PAINT_FACT} Debajo, termoplástico PPE/PA de ~2,5 mm (estimación), como las aletas de muchos coches modernos (más de 10 millones desde 2001). Es más blando que la queratina: una garra sí lo corta, y un zarpazo fuerte lo perfora.`),
  { id: "cobre", name: "Moneda de cobre", hv: 90, E: 120, mohs: 3.0, col: "#C8814B", mu: 0.4, W: 0.02, fact: "HV~90 (cobre acuñado, endurecido en frío), dúctil. Una punta roma a poca fuerza solo desliza: hace falta presión cercana a su dureza para dejar surco." },
  // Hoja de 4 mm de vidrio float recocido: resistencia a flexión característica 45 MPa (EN 572-1). Ventana de
  // ~60 cm apoyada en el marco (ESTIMACIÓN): placa circular de radio 300 mm (Roark). ν 0,22.
  { id: "vidrio", name: "Vidrio de ventana", hv: 550, E: 72, mohs: 5.5, col: "#9FD8D2", brittle: true, mu: 0.6, W: 0.03,
    pane: { t: 4, a: 300, fgk: 45, nu: 0.22 },
    fact: "Hoja de vidrio recocido de 4 mm (HV~550, frágil). El acero blando (HV~200) NO lo raya; el cuarzo, el zafiro o el diamante sí, por microfractura. Pero para ROMPERLO no hace falta dureza: basta con que la hoja flexe hasta 45 MPa en la cara de atrás, con ~200 N en el centro. Un zarpazo de gato no llega; el golpe de un oso o el picado de un halcón, de sobra." },
  { id: "acero", name: "Acero inox.", hv: 200, E: 193, mohs: 5.6, col: "#AEB6BF", mu: 0.5, W: 0.02, fact: "HV~200, dúctil. Más blando que el vidrio pese a un Mohs parecido: por eso Mohs engaña." },
  { id: "movil", name: "Pantalla móvil", hv: 650, E: 72, mohs: 6.5, col: "#2B3340", brittle: true, mu: 0.5, W: 0.03, fact: "Aluminosilicato reforzado (HV~650), frágil. El acero no lo raya, pero el cuarzo (la arena) sí: por eso se raya en el bolsillo." },
  { id: "cuarzo", name: "Encimera de cuarzo", hv: 1100, E: 75, mohs: 7.0, col: "#D8CFC4", brittle: true, mu: 0.5, W: 0.02, fact: "HV~1100, frágil. Solo zafiro, moissanita, tungsteno y diamante pueden." },
  { id: "zafiro", name: "Cristal de zafiro", hv: 2000, E: 400, mohs: 9.0, col: "#6FA8E0", brittle: true, mu: 0.4, W: 0.02, fact: "HV~2000 (corindón), frágil. Lo rayan la moissanita y el diamante." },
  { id: "diamante", name: "Diamante", hv: 10000, E: 1050, mohs: 10, col: "#DDE9FE", brittle: true, mu: 0.1, W: 0.01, fact: "HV~10000. Solo el diamante lo iguala, y apenas raya." },
];
export const TYPES = [
  { id: "roce", name: "Roce", k: 0.55 },
  { id: "aranazo", name: "Arañazo", k: 1.0 },
  { id: "surco", name: "Surco profundo", k: 1.7 },
];
