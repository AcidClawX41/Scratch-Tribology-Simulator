import React, { useState } from "react";

/* ════════ THEME · glam-lab ════════ */
const C = {
  bg: "#170E1C", panel: "#221530", panel2: "#2C1D3D", line: "#3C2B4D",
  text: "#F4E9F0", dim: "#A892B0", dimmer: "#6E5A7C",
  rose: "#F2A6C0", gold: "#E6B450", mint: "#5BE0C8", coral: "#FF6B7A", ice: "#BFE9FF",
};
const DISP = "'Syne', system-ui, sans-serif";
const MONO = "'Space Mono', ui-monospace, monospace";

/* ════════ DATA · dureza Vickers (HV, kgf/mm²) + Mohs ════════ */
const GEOMS = [
  { id: "cuadrada", name: "Cuadrada", area: 9.0, ay: 48, path: "M28 150 L28 60 Q28 48 40 48 L60 48 Q72 48 72 60 L72 150 Z" },
  { id: "redonda", name: "Redonda", area: 3.5, ay: 50, path: "M28 150 L28 72 Q28 50 50 50 Q72 50 72 72 L72 150 Z" },
  { id: "coffin", name: "Ataúd", area: 2.8, ay: 46, path: "M30 150 L30 74 L44 46 L56 46 L70 74 L70 150 Z" },
  { id: "almendra", name: "Almendra", area: 0.9, ay: 36, path: "M30 150 L30 80 Q34 42 50 36 Q66 42 70 80 L70 150 Z" },
  { id: "stiletto", name: "Stiletto", area: 0.15, ay: 26, path: "M30 150 L30 84 Q38 40 50 26 Q62 40 70 84 L70 150 Z" },
];
const BASES = [
  { id: "natural", name: "Uña natural", short: "Queratina", hv: 25, mohs: 2.5 },
  { id: "gel", name: "Gel UV", short: "Gel", hv: 30, mohs: 3.0 },
  { id: "acrilico", name: "Acrílico", short: "Acrílico", hv: 22, mohs: 3.0 },
];
const INLAYS = [
  { id: "none", name: "Sin incrustación", short: "—", hv: null, area: null, col: null },
  { id: "oro", name: "Pan de oro", short: "Oro", hv: 30, mohs: 2.5, area: 0.40, col: "#E6C36B" },
  { id: "acero", name: "Tachuela de acero", short: "Acero", hv: 200, mohs: 5.5, area: 0.12, col: "#C7CDD6" },
  { id: "titanio", name: "Titanio", short: "Titanio", hv: 150, mohs: 6.0, area: 0.12, col: "#B8BFC7" },
  { id: "tungsteno", name: "Carburo de tungsteno", short: "Tungsteno", hv: 2000, mohs: 9.0, area: 0.08, col: "#787E86" },
  { id: "vidrio", name: "Strass de vidrio", short: "Strass", hv: 550, mohs: 5.5, area: 0.15, col: "#EAF6FF" },
  { id: "swarovski", name: "Cristal Swarovski", short: "Swarovski", hv: 600, mohs: 6.0, area: 0.10, col: "#DCEFFF" },
  { id: "hematites", name: "Hematites", short: "Hematites", hv: 1000, mohs: 6.0, area: 0.12, col: "#5A5560" },
  { id: "cuarzo", name: "Cuarzo (cristal roca)", short: "Cuarzo", hv: 1100, mohs: 7.0, area: 0.10, col: "#F0EAF4" },
  { id: "circonita", name: "Circonita (CZ)", short: "CZ", hv: 1300, mohs: 8.0, area: 0.08, col: "#E8F4FF" },
  { id: "zafiro", name: "Zafiro", short: "Zafiro", hv: 2000, mohs: 9.0, area: 0.07, col: "#7FB6FF" },
  { id: "moissanita", name: "Moissanita (SiC)", short: "Moissanita", hv: 2800, mohs: 9.25, area: 0.05, col: "#EAF7E9" },
  { id: "diamante", name: "Diamante", short: "Diamante", hv: 10000, mohs: 10, area: 0.04, col: "#FFFFFF" },
];
// Garras y talones: queratina (Mohs ~2,5-3), NO más duras que la uña.
// Lo que cambia es el afilado (área) y la curvatura (ángulo de ataque / rasgado).
const CLAWS = [
  // ── Mamíferos ──
  { id: "gato", group: "Mamíferos", name: "Gato", hv: 28, mohs: 2.8, area: 0.02, curve: 0.80, mass: 4.5, force: 15, col: "#E9DCC8", desc: "Retráctil y afiladísima. Punta diminuta → presión brutal pese a poca fuerza." },
  { id: "tigre", group: "Mamíferos", name: "Tigre", hv: 30, mohs: 3.0, area: 0.06, curve: 0.80, mass: 220, force: 260, col: "#D9C49E", desc: "Un gato gigante: retráctil, curva y muy afilada, con muchísima fuerza detrás." },
  { id: "oso", group: "Mamíferos", name: "Oso pardo", hv: 26, mohs: 2.7, area: 0.50, curve: 0.55, mass: 300, force: 300, col: "#46392E", desc: "Enorme y curva pero roma (excava): mucha fuerza repartida en punta ancha." },
  // ── Rapaces ──
  { id: "aguila", group: "Rapaces", name: "Águila", hv: 32, mohs: 3.0, area: 0.04, curve: 0.85, mass: 5, force: 150, col: "#2E2A26", desc: "Talón de rapaz (queratina-β tenaz): garra que aprieta con varias veces su peso." },
  { id: "arpia", group: "Rapaces", name: "Águila arpía", hv: 33, mohs: 3.0, area: 0.06, curve: 0.90, mass: 9, force: 400, reach: 40, col: "#3A3530", desc: "La rapaz más poderosa: talón trasero de ~12-13 cm, caza monos y perezosos en la copa. Fuerza de agarre estimada." },
  { id: "halcon", group: "Rapaces", name: "Halcón peregrino", hv: 32, mohs: 3.0, area: 0.02, curve: 0.85, mass: 1, force: 30, col: "#5A5048", desc: "Garra corta y muy afilada: golpea en picado a >300 km/h y remata con el pico. Agarra activamente al posarse." },
  { id: "buho", group: "Rapaces", name: "Búho", hv: 30, mohs: 3.0, area: 0.03, curve: 0.85, mass: 2, force: 20, col: "#4A4034", desc: "Garra silenciosa, curvatura cerrada y punta de aguja." },
  { id: "lechuza", group: "Rapaces", name: "Lechuza", hv: 30, mohs: 3.0, area: 0.015, curve: 0.85, mass: 0.35, force: 10, col: "#C8B090", desc: "Rapaz nocturna ligera: agujas finísimas y trinquete tendinoso que bloquea el cierre (por eso cuesta soltarla)." },
  { id: "buitre", group: "Rapaces", name: "Buitre leonado", hv: 28, mohs: 2.8, area: 0.30, curve: 0.45, mass: 8, force: 60, col: "#6B5A45", desc: "Carroñero: garras romas para caminar, no para agarrar. Mucho pájaro, poca garra." },
  // ── Aves corredoras (ratites) ──
  { id: "casuario", group: "Aves corredoras", name: "Casuario", hv: 32, mohs: 3.0, area: 0.05, curve: 0.25, mass: 60, force: 500, reach: 110, col: "#1F2A44", desc: "El ave más peligrosa: daga recta de ~10-12 cm en el dedo interno y patada a 50 km/h. En Punción + Impacto se comporta como una puñalada. Fuerza de patada estimada." },
  { id: "emu", group: "Aves corredoras", name: "Emú", hv: 30, mohs: 3.0, area: 0.12, curve: 0.30, mass: 40, force: 300, reach: 40, col: "#7A6A55", desc: "Pariente del casuario pero sin la daga: tres garras robustas y patada fuerte, menos afiladas. Fuerza estimada." },
  { id: "avestruz", group: "Aves corredoras", name: "Avestruz", hv: 30, mohs: 3.0, area: 0.35, curve: 0.20, mass: 120, force: 900, reach: 60, col: "#8A7D6B", desc: "El ave más pesada: solo dos dedos, uña gruesa casi pezuña. Patada brutal pero punta roma. Fuerza estimada." },
  // ── Otras aves ──
  { id: "gallo", group: "Otras aves", name: "Gallo", title: "Espolón de gallo", hv: 28, mohs: 2.8, area: 0.04, curve: 0.35, mass: 3, force: 40, reach: 25, col: "#B5793A", desc: "Espolón de queratina sobre núcleo óseo en la pata. En pelea salta y golpea: pequeño pero traicionero." },
  { id: "guacamayo", group: "Otras aves", name: "Guacamayo", hv: 30, mohs: 3.0, area: 0.03, curve: 0.80, mass: 1.2, force: 25, col: "#3F6FB5", desc: "Pata zigodáctila (2 dedos delante, 2 detrás) para trepar y agarrar. El peligro real es el pico, no la garra." },
  { id: "pajaro", group: "Otras aves", name: "Pájaro", hv: 26, mohs: 2.6, area: 0.02, curve: 0.70, mass: 0.03, force: 1.5, col: "#C9B8A0", desc: "Fina y afilada pero frágil: apenas puede aplicar fuerza." },
  // ── Reptiles ──
  { id: "vibora", group: "Reptiles", name: "Colmillo de víbora", hv: 70, mohs: 3.5, area: 0.008, curve: 0.90, mass: 1, force: 4, fang: true, reach: 18, col: "#E4E0D8", desc: "Aguja hipodérmica evolucionada: la punta más fina del lab. Pincha casi sin fuerza, pero la dentina (Mohs ~3,5) cede a ~4 N. No aprieta: inyecta." },
  { id: "gabon", group: "Reptiles", name: "Colmillo de Gabón", hv: 70, mohs: 3.5, area: 0.012, curve: 0.85, mass: 9, force: 30, fang: true, reach: 50, col: "#C9B79A", desc: "Los colmillos más largos del mundo (~5 cm). Víbora pesada y robusta: más fuerza y muchísimo más alcance. Inyecta a varios centímetros de profundidad." },
];
const CLAW_GROUPS = ["Mamíferos", "Rapaces", "Aves corredoras", "Otras aves", "Reptiles"];
const clawTitle = (c) => c.title || (c.fang ? c.name : `Garra de ${c.name.toLowerCase()}`);
const TARGETS = [
  { id: "piel", name: "Piel", hv: 8, mohs: null, col: "#E8B89A", skin: true, mu: 0.5, W: 0.05, fact: "El tejido vivo no está en Mohs. Su tracción de rotura ronda ~2 MPa; por debajo solo enrojece, por encima rompe la epidermis." },
  { id: "madera", name: "Madera de pino", hv: 5, mohs: 1.6, col: "#C79A5E", mu: 0.4, W: 0.03, fact: "Blanda y fibrosa (HV~5). Dúctil: hace falta poca presión para arar." },
  { id: "puertamadera", name: "Puerta de madera barnizada", hv: 6, mohs: 1.8, col: "#9A6B3A", woodDoor: true, thickness: 35, fibrous: true, mu: 0.4, W: 0.03, fact: "Como el coche pero al revés de grosores: una laca fina y dura (~30 µm) sobre madera maciza de ~35 mm. La laca se raya y se pule; la madera cede fácil. Atravesarla DE LADO A LADO (estilo El Resplandor) pide impacto (golpe) y mucha fuerza: un empuje estático no basta." },
  { id: "puertametal", name: "Puerta de aluminio (casa)", hv: 60, mohs: 2.8, col: "#9CA3AA", thickness: 1.5, mu: 0.5, W: 0.02, fact: "Chapa metálica fina (~1,5 mm). Dúctil pero resistente: una punta blanda (dentina, queratina, uña) ni la marca. Para perforarla hace falta un punzón duro (titanio, tungsteno, diamante) y fuerza." },
  { id: "una", name: "Uña ajena", hv: 25, mohs: 2.5, col: "#F0D9D0", mu: 0.3, W: 0.04, fact: "Queratina contra queratina (HV~25): empate técnico, se pulen mutuamente." },
  { id: "plastico", name: "Plástico ABS", hv: 16, mohs: 2.8, col: "#5C6B7A", mu: 0.4, W: 0.04, fact: "HV~16, dúctil. El acrílico apenas lo iguala; las gemas lo aran fácil." },
  { id: "coche", name: "Pintura de coche", hv: 15, mohs: null, col: "#7E2B3A", paint: true, mu: 0.5, W: 0.04, fact: "Sistema multicapa OEM: barniz ~45µm · color ~15µm · imprimación ~25µm · anticorrosivo (e-coat) ~25µm · luego la chapa (~110µm en total). El barniz es un polímero blando (~0,15 GPa): se marra con remolinos fácilmente, pero lo que solo llega al barniz se pule. Aquí manda la PROFUNDIDAD, no solo la dureza." },
  { id: "cobre", name: "Moneda de cobre", hv: 90, mohs: 3.0, col: "#C8814B", mu: 0.4, W: 0.02, fact: "HV~90, dúctil. Una punta roma a poca fuerza solo desliza: hace falta presión cercana a su dureza para dejar surco." },
  { id: "vidrio", name: "Vidrio común", hv: 550, mohs: 5.5, col: "#9FD8D2", brittle: true, mu: 0.6, W: 0.03, fact: "HV~550, frágil. El acero blando (HV~200) NO lo raya; el cuarzo, zafiro o diamante sí, por microfractura." },
  { id: "acero", name: "Acero inox.", hv: 200, mohs: 5.6, col: "#AEB6BF", mu: 0.5, W: 0.02, fact: "HV~200, dúctil. Más blando que el vidrio pese a un Mohs parecido: por eso Mohs engaña." },
  { id: "movil", name: "Pantalla móvil", hv: 650, mohs: 6.5, col: "#2B3340", brittle: true, mu: 0.5, W: 0.03, fact: "Aluminosilicato reforzado (HV~650), frágil. El acero no lo raya, pero el cuarzo (la arena) sí: por eso se raya en el bolsillo." },
  { id: "cuarzo", name: "Encimera de cuarzo", hv: 1100, mohs: 7.0, col: "#D8CFC4", brittle: true, mu: 0.5, W: 0.02, fact: "HV~1100, frágil. Solo zafiro, moissanita, tungsteno y diamante pueden." },
  { id: "zafiro", name: "Cristal de zafiro", hv: 2000, mohs: 9.0, col: "#6FA8E0", brittle: true, mu: 0.4, W: 0.02, fact: "HV~2000 (corindón), frágil. Lo rayan la moissanita y el diamante." },
  { id: "diamante", name: "Diamante", hv: 10000, mohs: 10, col: "#DDE9FE", brittle: true, mu: 0.1, W: 0.01, fact: "HV~10000. Solo el diamante lo iguala, y apenas raya." },
];
const TYPES = [
  { id: "roce", name: "Roce", k: 0.55 },
  { id: "aranazo", name: "Arañazo", k: 1.0 },
  { id: "surco", name: "Surco profundo", k: 1.7 },
];

const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const FMIN = 0.5, FMAX = 2000;
const fToT = (f) => (Math.log10(clamp(f, FMIN, FMAX)) - Math.log10(FMIN)) / (Math.log10(FMAX) - Math.log10(FMIN));
const tToF = (t) => Math.pow(10, Math.log10(FMIN) + t * (Math.log10(FMAX) - Math.log10(FMIN)));
const fmtF = (f) => (f >= 10 ? f.toFixed(0) : f.toFixed(1));
const fmtP = (p) => (p >= 100 ? p.toFixed(0) : p >= 10 ? p.toFixed(1) : p.toFixed(2));
const hvBar = (hv) => clamp((Math.log10(hv) - Math.log10(2)) / (Math.log10(10000) - Math.log10(2)) * 100, 4, 100);

/* ════════ PHYSICS ════════
   · Dureza Vickers HV; 1 HV ≈ 9,81 MPa
   · Presión de contacto P = N/A
   · Rayar exige DOS cosas: ser más duro (r = HV_uña/HV_objetivo ≥ 1,25) Y
     presión suficiente para deformar/fracturar (penetración χ = P / H_objetivo).
     A poca presión el contacto es elástico → desliza sin marcar.
   · Frágil (vidrio, gemas): se raya por microfractura con poca presión.
     Dúctil (metales, madera, plástico): hay que acercarse a su dureza para arar.
   · Desgaste: Archard  V ∝ K·F·L / H ; Adhesión: pull-off JKR F_adh = 1,5·π·R·W (Van der Waals)
*/
function compute({ geom, base, inlay, target, force, length, type, claw, tear, method, strike, passes }) {
  const useClaw = !!claw;
  const tearing = !!tear && useClaw;                 // desgarro/palanca: solo garras
  const lever = tearing ? (1 + 1.3 * claw.curve) : 1; // gancho curvo → ventaja mecánica
  const hasGem = inlay.id !== "none";
  const fang = useClaw && !!claw.fang;
  // Un colmillo "reforjado" en otro material (titanio, vidrio, diamante…) conserva su
  // geometría de aguja: la incrustación cambia la DUREZA, no el área de la punta.
  const area = hasGem ? (fang ? claw.area : inlay.area) : (useClaw ? claw.area : geom.area);
  const hvTool = hasGem ? inlay.hv : (useClaw ? claw.hv : base.hv);
  const mohsTool = hasGem ? inlay.mohs : (useClaw ? claw.mohs : base.mohs);
  const mu = target.mu;
  // la curvatura de una garra aumenta el ángulo de ataque y el rasgado → más penetración
  const curveBoost = useClaw ? (1 + 0.7 * claw.curve) : 1;

  const R = Math.sqrt(area / Math.PI) * 1e-3;
  const Fadh = 1.5 * Math.PI * R * target.W;        // N (Van der Waals / JKR)
  const Neff = force + Fadh;
  const pressure = Neff / area;                     // MPa
  const pen = hvTool >= 800 ? 1.3 : hvTool >= 100 ? 0.9 : 0.5;
  // Fricción de Coulomb: fuerza tangencial Ft = μ·N. La cizalla que añade (τ = μ·P)
  // sube el esfuerzo equivalente de von Mises: σ_eq = P·√(1 + 3μ²) → ayuda a arar/cortar.
  const Ffric = mu * Neff;                           // N (Coulomb)
  const fMu = Math.sqrt(1 + 3 * mu * mu);            // factor de esfuerzo equivalente

  let verdict, vcol, vsub, scratched, sev, Hsoft, cede, ratio = null, chi = null, stress = null, toolWorn = false, depthUm = 0, layer = null;

  /* ════ PUNCIÓN / INYECCIÓN: penetración vertical, sin arrastre lateral ════ */
  if (method === "puncion") {
    ratio = hvTool / target.hv;
    chi = pressure / (target.hv * 9.81);
    const inject = !!(useClaw && claw.fang);          // colmillo hueco = inyecta
    const cShape = 24.5 * clamp(area / 0.1, 0.2, 200);
    const woodish = target.skin || target.woodDoor || target.id === "madera";
    const Hp_Pa = target.skin ? 2e6 : (target.paint ? 15 * 9.81e6 : target.hv * 9.81e6);
    const Aproj = Neff / Hp_Pa;
    // alcance del punzón: hasta dónde puede hundirse la herramienta (cm para colmillos)
    const reachUm = (useClaw && claw.reach) ? claw.reach * 1000 : (inject ? 18000 : useClaw ? 9000 : 4000);
    // Golpe: una mordedura/golpe real es dinámico, no cuasi-estático → la energía cinética
    // clava mucho más que un empuje suave (supera lo que el equilibrio de fuerzas predice).
    const strikeK = strike ? 4 : 1;
    const breakthroughCap = target.thickness ? target.thickness * 1000 : Infinity;
    // en tejido blando o fibroso la punta no aplasta: separa/fractura → penetra más
    const softK = target.skin ? 9 : (target.fibrous ? 6 : 1);
    const dBase = Math.sqrt(Math.max(Aproj, 0) / cShape) * pen * curveBoost * 1e6 * softK * strikeK;
    Hsoft = target.skin ? 15 : target.hv;
    const wearIdx = Math.round((400 * force * (strike ? 2 : 1)) / Math.max(Hsoft, 5));
    const through = (d) => target.thickness && d >= breakthroughCap;

    // Penetración CONTINUA (sin escalón): la profundidad sube suave con la fuerza.
    // Eficiencia = cuánto supera la presión la resistencia plástica del material (ramp 0→1).
    const Hflow = target.skin ? 2 : (target.paint ? 15 * 9.81 : target.hv * 9.81);
    const penEff = clamp(pressure / Hflow, 0, 1);
    let pierces;
    if (target.skin) {
      const pStress = pressure * pen * fMu * curveBoost * (strike ? 1.6 : 1);
      stress = pStress;
      pierces = pStress >= 2;
      depthUm = pierces ? clamp(dBase, 0, reachUm) : 0;
      sev = pierces ? clamp(depthUm / reachUm, 0.2, 1) : 0.08;
      if (!pierces) { verdict = "NO PERFORA"; vcol = C.mint; vsub = "la punta hunde la piel pero no la rompe"; cede = "nada"; scratched = false; }
      else if (inject) { verdict = "PUNCIÓN · INYECTA"; vcol = C.coral; vsub = `perfora y deja el veneno a ~${(depthUm / 1000).toFixed(1)} mm en el tejido`; cede = "la piel (2 punciones)"; scratched = true; }
      else { verdict = "PUNCIÓN"; vcol = C.coral; vsub = `perfora la piel ~${(depthUm / 1000).toFixed(1)} mm (punción seca, sin veneno)`; cede = "la piel (perforada)"; scratched = true; }
    } else if (target.paint) {
      depthUm = clamp(dBase * penEff, 0, 130);
      const L = [[45, "el barniz (clearcoat)", "barniz"], [60, "el color (basecoat)", "color"], [85, "la imprimación", "imprimacion"], [110, "el anticorrosivo (e-coat)", "anticorrosivo"]];
      const hit = L.find(([d]) => depthUm <= d);
      layer = hit ? hit[2] : "chapa"; cede = hit ? hit[1] : "la chapa";
      pierces = depthUm > 1;
      sev = clamp(depthUm / 122, 0.05, 1);
      if (!pierces) { verdict = "APENAS ROZA"; vcol = C.mint; vsub = "marca mínima en el barniz"; scratched = false; cede = "nada (pulible)"; }
      else { verdict = "PUNCIÓN"; vcol = C.coral; vsub = `agujero hasta ${cede}`; scratched = true; }
    } else if (target.woodDoor) {
      const dRaw = dBase * penEff;
      depthUm = clamp(dRaw, 0, breakthroughCap);
      const broke = dRaw >= breakthroughCap;
      layer = depthUm <= 30 ? "laca" : "madera";
      pierces = depthUm > 1;
      sev = clamp(depthUm / breakthroughCap, 0.05, 1);
      if (!pierces) { verdict = "APENAS ROZA"; vcol = C.mint; vsub = "marca mínima en la laca"; cede = "nada"; scratched = false; }
      else if (broke) { verdict = "ATRAVIESA LA PUERTA"; vcol = C.coral; vsub = "de lado a lado — ¡aquí está Johnny!"; cede = "la puerta entera"; scratched = true; }
      else if (depthUm <= 30) { verdict = "PUNCIÓN EN LA LACA"; vcol = C.gold; vsub = `agujero de ~${depthUm.toFixed(0)} µm, solo el barniz`; cede = "la laca"; scratched = true; }
      else { verdict = "CLAVADA EN LA MADERA"; vcol = C.coral; vsub = `entra ~${(depthUm / 1000).toFixed(1)} mm de los 35 mm; falta para atravesar`; cede = "la madera"; scratched = true; }
    } else {
      const harder = hvTool >= target.hv * (target.brittle ? 0.6 : 1);   // la punta debe poder ceder el material
      const dRaw = harder ? dBase * penEff : 0;
      depthUm = clamp(dRaw, 0, Math.min(reachUm, breakthroughCap));
      const broke = harder && dRaw >= breakthroughCap;
      pierces = depthUm > 1;
      sev = pierces ? clamp(depthUm / (breakthroughCap === Infinity ? 200 : breakthroughCap), 0.1, 1) : 0.06;
      if (broke) {
        verdict = "ATRAVIESA LA PUERTA"; vcol = C.coral; vsub = `de lado a lado (${target.thickness} mm de metal perforados)`; cede = "la puerta de metal"; scratched = true;
      } else if (!harder) {
        verdict = "NO PERFORA"; vcol = C.mint; vsub = "la punta se embota/rompe antes de entrar"; cede = "la punta"; toolWorn = true; scratched = false;
      } else if (pierces) {
        verdict = target.brittle ? "PERFORA · ASTILLA" : "PERFORA";
        vcol = C.coral; vsub = target.brittle ? `microfractura: pozo de punción en ${target.name.toLowerCase()}` : `pozo de punción ~${depthUm.toFixed(0)} µm${target.thickness ? ` de ${target.thickness} mm` : ""}`;
        cede = `${target.name.toLowerCase()} (pozo)`; scratched = true;
      } else {
        verdict = "APENAS MARCA"; vcol = C.gold; vsub = `pozo incipiente ~${depthUm.toFixed(1)} µm (sube la fuerza)`; cede = target.name.toLowerCase(); scratched = false;
      }
    }
    return {
      hasGem, area, hvTool, mohsTool, pressure, mu, Ffric, Fadh_mN: Fadh * 1000, ratio, chi, sev,
      verdict, vcol, vsub, scratched, wearIdx, cede, stress, toolWorn, depthUm, layer, claw: useClaw, tearing: false,
      skin: !!target.skin, paint: !!target.paint, tHV: target.hv, tMohs: target.mohs, tName: target.name,
      puncture: true, inject, pierces, woodDoor: !!target.woodDoor,
    };
  }

  // pasadas repetidas en el mismo surco: profundizan de forma sublineal (cada pasada arranca
  // menos al ensancharse el surco). Solo amplifican donde la herramienta ya marca.
  const passF = Math.pow(Math.max(passes || 1, 1), 0.4);

  if (target.skin) {
    stress = pressure * pen * type.k * fMu * curveBoost * lever;
    Hsoft = 15;
    // Romper la piel = umbral de TENSIÓN (~2 MPa): una punta fina lo logra con poca fuerza
    // (espina, aguja, garra). Pero el TAMAÑO de la herida lo limita la FUERZA absoluta:
    // lacerar exige fuerza para abrir el tejido, no solo presión en un punto.
    if (stress < 0.5) { scratched = false; sev = 0; verdict = "SIN MARCA"; vcol = C.mint; vsub = "la punta resbala, sin huella"; cede = "nada"; }
    else if (stress < 2) { scratched = "faint"; sev = 0.12; verdict = "MARCA ROJA"; vcol = C.gold; vsub = "< 2 MPa: enrojece, no rompe"; cede = "piel (reversible)"; }
    else if (force >= 12 && stress >= 8) { scratched = true; sev = 0.92; verdict = "CORTE"; vcol = C.coral; vsub = "fuerza suficiente para lacerar y abrir el tejido"; cede = "la piel"; }
    else if (force >= 4 && stress >= 4) { scratched = true; sev = 0.6; verdict = "ARAÑAZO PROFUNDO"; vcol = C.coral; vsub = "penetra y puede sangrar"; cede = "dermis superficial"; }
    else { scratched = true; sev = 0.3; verdict = "ARAÑAZO"; vcol = C.coral; vsub = "rompe la epidermis · rasguño fino (falta fuerza para más)"; cede = "la epidermis"; }
  } else if (target.paint) {
    // Sistema multicapa. Profundidad de surco por modelo de indentación (pirámide auto-similar):
    // H = F/A_proj ; A_proj = c·h²  →  h = √(F/(H·c)). c crece con la bluntez de la punta.
    ratio = hvTool / target.hv;
    const Hpa = target.hv * 9.81e6;                 // Pa (barniz)
    chi = pressure / (target.hv * 9.81);
    const cShape = 24.5 * clamp(area / 0.1, 0.2, 200);
    const Aproj = Neff / Hpa;                        // m²
    // embotamiento: una punta poco más dura que el objetivo se deforma y no penetra hondo.
    // En desgarro, el gancho propaga un rasgado en vez de indentar → embotamiento más suave.
    const bluntF = tearing ? clamp((ratio - 1) / 1.8, 0.3, 1) : clamp((ratio - 1) / 3, 0, 1);
    depthUm = ratio >= 1.0 ? Math.sqrt(Math.max(Aproj, 0) / cShape) * 1e6 * type.k * 0.7 * curveBoost * bluntF * lever * passF : 0;
    Hsoft = target.hv;
    // capas acumuladas (µm): barniz 45 · color 60 · imprimación 85 · anticorrosivo 110 · metal >
    if (ratio < 1.0 || depthUm < 1.5) {
      scratched = false; depthUm = Math.min(depthUm, 1.2); sev = clamp(depthUm / 110, 0, 1);
      verdict = "ROZA / REMOLINO"; vcol = C.mint; vsub = "marca de barniz pulible, no penetra"; cede = "nada (pulible)"; layer = "barniz · superficie";
    } else if (depthUm < 45) {
      scratched = "faint"; sev = clamp(depthUm / 110, 0, 1);
      verdict = "ARAÑAZO EN BARNIZ"; vcol = C.gold; vsub = "queda en el clearcoat · se pule"; cede = "el barniz"; layer = "barniz (clearcoat)";
    } else if (depthUm < 60) {
      scratched = true; sev = clamp(depthUm / 110, 0, 1);
      verdict = "LLEGA AL COLOR"; vcol = C.coral; vsub = "atraviesa el barniz · necesita retoque"; cede = "el color (basecoat)"; layer = "color (basecoat)";
    } else if (depthUm < 85) {
      scratched = true; sev = clamp(depthUm / 110, 0, 1);
      verdict = "HASTA IMPRIMACIÓN"; vcol = C.coral; vsub = "se ve gris/blanco del primer"; cede = "la imprimación"; layer = "imprimación (primer)";
    } else if (depthUm < 110) {
      scratched = true; sev = clamp(depthUm / 110, 0, 1);
      verdict = "HASTA ANTICORROSIVO"; vcol = C.coral; vsub = "expone el e-coat"; cede = "el anticorrosivo"; layer = "anticorrosivo (e-coat)";
    } else {
      scratched = true; sev = 1;
      verdict = "HASTA EL METAL"; vcol = C.coral; vsub = "chapa expuesta · riesgo de óxido"; cede = "la chapa"; layer = "metal (chapa)";
    }
  } else if (target.woodDoor) {
    // Laca dura (~18 HV) sobre madera blanda (6 HV). El surco interactúa primero con la laca.
    const lacaHV = 18;
    ratio = hvTool / lacaHV;
    chi = pressure / (lacaHV * 9.81);
    const cShape = 24.5 * clamp(area / 0.1, 0.2, 200);
    const Aproj = Neff / (lacaHV * 9.81e6);
    const bluntF = tearing ? clamp((ratio - 1) / 1.8, 0.3, 1) : clamp((ratio - 1) / 3, 0, 1);
    depthUm = ratio >= 1.0 ? Math.sqrt(Math.max(Aproj, 0) / cShape) * 1e6 * type.k * 0.7 * curveBoost * bluntF * lever * passF : 0;
    Hsoft = lacaHV;
    if (ratio < 1.0 || depthUm < 1.5) {
      scratched = false; depthUm = Math.min(depthUm, 1.2); sev = 0.05;
      verdict = "ROZA LA LACA"; vcol = C.mint; vsub = "marca superficial pulible, no penetra la laca"; cede = "nada (pulible)"; layer = "laca · superficie";
    } else if (depthUm <= 30) {
      scratched = "faint"; sev = clamp(depthUm / 60, 0.1, 0.5);
      verdict = "ARAÑAZO EN LA LACA"; vcol = C.gold; vsub = `queda en el barniz (~${depthUm.toFixed(0)} µm) · se pule`; cede = "la laca"; layer = "laca (barniz)";
    } else {
      scratched = true; sev = clamp(depthUm / 400, 0.45, 1);
      verdict = "LLEGA A LA MADERA"; vcol = C.coral; vsub = `atraviesa la laca y entra ~${(depthUm / 1000).toFixed(2)} mm en la madera desnuda`; cede = "la madera"; layer = "madera";
    }
  } else {
    ratio = hvTool / target.hv;
    const Hmpa = target.hv * 9.81;
    chi = pressure / Hmpa;
    const brittle = target.brittle ? 8 : 1;
    const chiEff = chi * brittle * fMu;   // incluye la cizalla de Coulomb (von Mises)
    // factor de presión (0..1): ¿hay bastante para deformar/fracturar?
    const Pf = clamp((Math.log10(chiEff + 0.002) - Math.log10(0.004)) / (Math.log10(0.6) - Math.log10(0.004)), 0, 1);
    // factor de dureza
    let Hf;
    if (ratio < 0.8) Hf = 0;
    else if (ratio < 1.25) Hf = 0.35;
    else Hf = clamp(0.6 + 0.4 * Math.log10(ratio), 0.6, 1);
    sev = clamp(Hf * Pf * type.k, 0, 1);

    if (ratio < 0.8) {
      scratched = false; sev = 0; toolWorn = true; verdict = "NO RAYA"; vcol = C.mint;
      vsub = "más blanda: la uña se desgasta"; Hsoft = hvTool; cede = "tu uña";
    } else if (sev < 0.08) {
      scratched = false; sev = 0; verdict = "ROZA SIN MARCAR"; vcol = C.mint;
      vsub = ratio >= 1.25 ? "más dura, pero presión insuficiente (contacto elástico)" : "dureza similar y poca presión";
      Hsoft = hvTool; cede = "nada (desliza)";
    } else if (ratio < 1.25 || sev < 0.40) {
      scratched = "faint"; verdict = ratio < 1.25 ? "MARCA TENUE" : "RAYA LEVE"; vcol = C.gold;
      vsub = ratio < 1.25 ? "dureza similar · pulido mutuo" : "surco incipiente";
      Hsoft = Math.min(hvTool, target.hv); cede = ratio < 1.25 ? "ambos por igual" : `el ${target.name.toLowerCase()} (leve)`;
    } else {
      scratched = true; verdict = "RAYA"; vcol = C.coral; vsub = "surco plástico/frágil claro";
      Hsoft = target.hv; cede = target.name.toLowerCase();
    }
  }
  if (!target.skin && !target.paint && !target.woodDoor) {
    const cShape = 24.5 * clamp(area / 0.1, 0.2, 200);
    const Aproj = Neff / (target.hv * 9.81e6);
    const factor = scratched ? 1 : 0;   // mismo surco que la pintura a igual dureza; 0 solo si no marca
    const bluntF = tearing ? clamp((ratio - 1) / 1.8, 0.3, 1) : (ratio ? clamp((ratio - 1) / 3, 0, 1) : 1);
    depthUm = factor * Math.sqrt(Math.max(Aproj, 0) / cShape) * 1e6 * type.k * 0.7 * curveBoost * bluntF * lever * passF;
  }
  // ── Abrasión (Hokkirigawa-Kato 1988): el grado de penetración Dp = h/a decide el modo:
  // arado (desplaza) → cuña → corte (arranca). Y la fricción de rayado es SCOF = μ_adh + μ_arado.
  const aHalf = Math.sqrt(area / Math.PI) * 1e-3;            // m, semiancho de contacto
  const Dp = (depthUm * 1e-6) / Math.max(aHalf, 1e-9);      // grado de penetración
  let absMode = null, fab = 1, muPlough = 0;
  if (!target.skin && depthUm > 0.5 && scratched) {
    muPlough = clamp(0.9 * Dp, 0, 1.2);                     // fricción de arado ~ tan(ángulo de ataque) ~ Dp
    if (Dp < 0.1) { absMode = "arado"; fab = clamp(Dp / 0.1 * 0.15, 0.02, 0.15); }
    else if (Dp < 0.2) { absMode = "cuña"; fab = clamp(0.15 + (Dp - 0.1) / 0.1 * 0.45, 0.15, 0.6); }
    else { absMode = "corte"; fab = clamp(0.6 + (Dp - 0.2) * 2, 0.6, 1); }
  }
  const muAdh = target.mu;
  const muEff = muAdh + muPlough;
  const FfricEff = muEff * Neff;                             // fuerza tangencial real (adhesión + arado)
  // Archard da el volumen DEFORMADO; lo realmente arrancado = fab·volumen (arado desplaza, corte arranca)
  const wearIdx = Math.round((1500 * force * length * Math.max(passes || 1, 1) * (absMode ? fab : 1)) / Math.max(Hsoft, 5));
  return {
    hasGem, area, hvTool, mohsTool, pressure, mu, Ffric: FfricEff, muAdh, muPlough, muEff, absMode, Dp, fab,
    Fadh_mN: Fadh * 1000, ratio, chi, sev,
    verdict, vcol, vsub, scratched, wearIdx, cede, stress, toolWorn, depthUm, layer, claw: useClaw, tearing,
    skin: !!target.skin, paint: !!target.paint, woodDoor: !!target.woodDoor, tHV: target.hv, tMohs: target.mohs, tName: target.name,
  };
}

/* ════════ GEM ════════ */
function Gem({ cx, cy, r, col }) {
  if (!col) return null;
  return (
    <g>
      <polygon points={`${cx},${cy - r} ${cx + r},${cy} ${cx},${cy + r} ${cx - r},${cy}`} fill={col} stroke="rgba(255,255,255,.85)" strokeWidth="0.6" />
      <polygon points={`${cx},${cy - r} ${cx + r * 0.5},${cy - r * 0.1} ${cx - r * 0.5},${cy - r * 0.1}`} fill="rgba(255,255,255,.55)" />
      <line x1={cx} y1={cy - r} x2={cx} y2={cy + r} stroke="rgba(255,255,255,.4)" strokeWidth="0.4" />
      <line x1={cx - r} y1={cy} x2={cx + r} y2={cy} stroke="rgba(255,255,255,.4)" strokeWidth="0.4" />
    </g>
  );
}

function FingerPreview({ geom, inlay }) {
  const r = inlay.id !== "none" ? clamp(Math.sqrt(inlay.area) * 9, 3.2, 7.5) : 0;
  return (
    <svg viewBox="0 0 100 168" style={{ width: "100%", height: "100%" }}>
      <defs>
        <linearGradient id="fg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#E8C6C2" /><stop offset="1" stopColor="#C99B98" /></linearGradient>
        <linearGradient id="ng" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FBEFF4" /><stop offset="1" stopColor="#E9CBD8" /></linearGradient>
      </defs>
      <rect x="24" y="80" width="52" height="86" rx="24" fill="url(#fg)" />
      <path d={geom.path} fill="url(#ng)" stroke="#D9A9BC" strokeWidth="1.2" />
      <path d={geom.path} fill="none" stroke="rgba(255,255,255,.5)" strokeWidth="2" style={{ clipPath: "inset(0 55% 0 0)" }} />
      {r > 0 && <Gem cx={50} cy={geom.ay + 8} r={r} col={inlay.col} />}
    </svg>
  );
}

function clawPath(curve) {
  const bulge = 20 + curve * 22, tipX = 58 - curve * 10, tipY = 30 + curve * 26;
  return { d: `M30 122 C ${30 + bulge} 96, ${36 + bulge} 54, ${tipX} ${tipY} C ${tipX - 4} ${tipY - 2}, 48 78, 44 122 Z`, tipX, tipY };
}
function ClawGlyph({ claw, inlay = null, tipColor = "#F2A6C0" }) {
  const { d, tipX, tipY } = clawPath(claw.curve);
  const gem = inlay && inlay.id !== "none";
  const mW = clamp(Math.sqrt(gem ? inlay.area : claw.area) * 16, 2.4, 13);
  return (
    <svg viewBox="0 0 100 132" style={{ width: "100%", height: "100%" }}>
      <defs>
        <linearGradient id={`cl-${claw.id}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={claw.col} /><stop offset="1" stopColor="rgba(0,0,0,0.45)" />
        </linearGradient>
      </defs>
      <path d={d} fill={`url(#cl-${claw.id})`} stroke="rgba(0,0,0,0.5)" strokeWidth="1.2" />
      <path d={d} fill="none" stroke="rgba(255,255,255,0.28)" strokeWidth="1.4" style={{ clipPath: "inset(0 0 50% 0)" }} />
      {gem
        ? <Gem cx={tipX} cy={tipY} r={Math.max(3, mW / 2)} col={inlay.col} />
        : <ellipse cx={tipX} cy={tipY} rx={mW / 2} ry={Math.min(mW / 2, 3)} fill={tipColor} />}
    </svg>
  );
}

function GeomGlyph({ geom, col }) {
  return (
    <svg viewBox="0 0 100 165" style={{ width: 26, height: 44, flexShrink: 0, display: "block" }}>
      <path d={geom.path} fill="#2C1D3D" stroke={col || "#3C2B4D"} strokeWidth="3" />
    </svg>
  );
}

/* ════════ BENCH ════════ */
function Bench({ res, phase, length }) {
  const startX = 18, grooveStart = 46;
  const grooveLen = 40 + (length / 60) * 210;
  const endX = grooveStart + grooveLen - 30;
  const tx = phase === "idle" ? startX : endX;
  const show = res && (res.scratched === true || res.scratched === "faint");
  const gw = res ? 1.6 + res.sev * 7 : 0;
  return (
    <svg viewBox="0 0 320 150" style={{ width: "100%", height: "auto", display: "block" }}>
      <defs><clipPath id="strip"><rect x="20" y="78" width="284" height="54" rx="10" /></clipPath></defs>
      <rect x="20" y="78" width="284" height="54" rx="10" fill={res ? res._col : "#3a2a4a"} />
      <rect x="20" y="78" width="284" height="14" rx="10" fill="rgba(255,255,255,.10)" />
      <rect x="20" y="78" width="284" height="54" rx="10" fill="none" stroke={C.line} strokeWidth="1.2" />
      {show && (
        <g clipPath="url(#strip)">
          <line x1={grooveStart} y1="106" x2={grooveStart + grooveLen} y2="106" stroke="rgba(0,0,0,.45)" strokeWidth={gw} strokeLinecap="round" className="groove" strokeDasharray={grooveLen} strokeDashoffset={phase === "idle" ? grooveLen : 0} />
          <line x1={grooveStart} y1={106 - gw * 0.5} x2={grooveStart + grooveLen} y2={106 - gw * 0.5} stroke="rgba(255,255,255,.30)" strokeWidth="0.8" strokeLinecap="round" className="groove" strokeDasharray={grooveLen} strokeDashoffset={phase === "idle" ? grooveLen : 0} />
        </g>
      )}
      <g className="tool" style={{ transform: `translateX(${tx}px)` }}>
        <path d="M16 38 Q16 70 28 92 Q40 70 40 38 Q40 20 28 16 Q16 20 16 38 Z" fill="#EFD7E0" stroke="#D9A9BC" strokeWidth="1.4" />
        {res && res.hasGem && res._gemcol && <Gem cx={28} cy={84} r={4.5} col={res._gemcol} />}
        {res && res.toolWorn && <circle cx="28" cy="92" r="4" fill={C.coral} opacity="0.9" />}
      </g>
    </svg>
  );
}

function PaintLayers({ depthUm, vcol }) {
  const Hp = 150, maxU = 122, yOf = (u) => 6 + (clamp(u, 0, maxU) / maxU) * (Hp - 12);
  const LAY = [
    { n: "Barniz", a: 0, b: 45, c: "#AED2E0" },
    { n: "Color", a: 45, b: 60, c: "#7E2B3A" },
    { n: "Imprimación", a: 60, b: 85, c: "#9AA0A6" },
    { n: "Anticorrosivo", a: 85, b: 110, c: "#5E6B52" },
    { n: "Chapa", a: 110, b: 122, c: "#AEB6BF" },
  ];
  const dY = yOf(depthUm);
  return (
    <svg viewBox="0 0 300 156" style={{ width: "100%", height: "auto" }}>
      {LAY.map((l) => (
        <g key={l.n}>
          <rect x="8" y={yOf(l.a)} width="150" height={yOf(l.b) - yOf(l.a)} fill={l.c} opacity="0.85" />
          <text x="166" y={(yOf(l.a) + yOf(l.b)) / 2 + 3} fontFamily={MONO} fontSize="9" fill={C.dim}>{l.n} · {l.a}–{l.b}µm</text>
        </g>
      ))}
      <rect x="8" y="6" width="150" height={Hp - 12} fill="none" stroke={C.line} strokeWidth="1" />
      {/* surco que penetra */}
      <polygon points={`78,6 88,6 83,${dY}`} fill={vcol} />
      <line x1="8" y1={dY} x2="158" y2={dY} stroke={vcol} strokeWidth="1.4" strokeDasharray="4 3" />
      <circle cx="83" cy={dY} r="3" fill={vcol} />
      <text x="166" y={dY < 18 ? dY + 14 : dY - 4} fontFamily={MONO} fontSize="10" fill={vcol} fontWeight="700">≈ {depthUm < 10 ? depthUm.toFixed(1) : depthUm.toFixed(0)} µm</text>
    </svg>
  );
}

function DoorLayers({ depthUm, vcol }) {
  const H = 150, top = 6, draw = H - 12;
  const lacaH = draw * 0.16, woodH = draw * 0.84, woodTop = top + lacaH;
  const through = depthUm >= 35000;
  let dY;
  if (depthUm <= 30) dY = top + (clamp(depthUm, 0, 30) / 30) * lacaH;
  else { const frac = clamp((depthUm - 30) / (35000 - 30), 0, 1); dY = woodTop + Math.sqrt(frac) * woodH; }
  if (through) dY = top + draw;
  const dTxt = through ? "ATRAVIESA · 35 mm" : depthUm < 1000 ? `≈ ${depthUm < 10 ? depthUm.toFixed(1) : depthUm.toFixed(0)} µm` : `≈ ${(depthUm / 1000).toFixed(1)} mm`;
  return (
    <svg viewBox="0 0 300 156" style={{ width: "100%", height: "auto" }}>
      <rect x="8" y={top} width="150" height={lacaH} fill="#C9A24B" opacity="0.9" />
      <rect x="8" y={woodTop} width="150" height={woodH} fill="#8A5A2B" opacity="0.9" />
      <text x="166" y={top + lacaH / 2 + 3} fontFamily={MONO} fontSize="9" fill={C.dim}>Laca · 0–30 µm</text>
      <text x="166" y={woodTop + 14} fontFamily={MONO} fontSize="9" fill={C.dim}>Madera maciza</text>
      <text x="166" y={woodTop + 27} fontFamily={MONO} fontSize="9" fill={C.dimmer}>30 µm – 35 mm</text>
      <line x1="8" y1={woodTop} x2="158" y2={woodTop} stroke={C.bg} strokeWidth="1" strokeDasharray="3 2" />
      <rect x="8" y={top} width="150" height={draw} fill="none" stroke={C.line} strokeWidth="1" />
      <polygon points={`78,${top} 88,${top} 83,${dY}`} fill={vcol} />
      <line x1="8" y1={dY} x2="158" y2={dY} stroke={vcol} strokeWidth="1.4" strokeDasharray="4 3" />
      <circle cx="83" cy={dY} r="3" fill={vcol} />
      <text x="12" y={dY < 22 ? dY + 15 : dY - 5} fontFamily={MONO} fontSize="10" fill={vcol} fontWeight="700">{dTxt}</text>
    </svg>
  );
}

function CrossSection({ res }) {
  if (!res) return null;
  const d = 6 + res.sev * 34;
  const path = res.sev > 0.02
    ? `M10 26 L52 26 Q60 26 62 ${26 + d} Q70 ${26 + d + 6} 78 ${26 + d} Q80 26 88 26 L110 26`
    : `M10 26 L110 26`;
  return (
    <svg viewBox="0 0 120 80" style={{ width: "100%", height: 64 }}>
      <rect x="6" y="26" width="108" height="48" rx="4" fill={res._col} opacity="0.5" />
      <rect x="6" y="26" width="108" height="48" rx="4" fill="none" stroke={C.line} />
      <path d={path} fill="none" stroke={res.vcol} strokeWidth="2.4" strokeLinejoin="round" />
      <text x="60" y="70" textAnchor="middle" fontFamily={MONO} fontSize="8" fill={C.dimmer}>perfil del surco</text>
    </svg>
  );
}

function Metric({ label, val, col }) {
  return (
    <div style={{ background: C.panel2, borderRadius: 10, padding: "9px 11px" }}>
      <div style={{ fontFamily: MONO, fontSize: 9, color: C.dimmer, letterSpacing: 1, textTransform: "uppercase" }}>{label}</div>
      <div style={{ fontFamily: MONO, fontSize: 13.5, color: col || C.text, marginTop: 3 }}>{val}</div>
    </div>
  );
}

/* ════════ APP ════════ */
export default function App() {
  const [geom, setGeom] = useState(GEOMS[3]);
  const [base, setBase] = useState(BASES[2]);
  const [inlay, setInlay] = useState(INLAYS[0]);
  const [claw, setClaw] = useState(null);
  const [tearMode, setTearMode] = useState(false);
  const [method, setMethod] = useState("rayado");
  const [strike, setStrike] = useState(false);
  const [passes, setPasses] = useState(1);
  const [target, setTarget] = useState(TARGETS[4]);
  const [force, setForce] = useState(4);
  const [length, setLength] = useState(25);
  const [type, setType] = useState(TYPES[1]);
  const [phase, setPhase] = useState("idle");
  const [res, setRes] = useState(null);
  const [log, setLog] = useState([]);
  const [badges, setBadges] = useState(new Set());
  const [count, setCount] = useState(0);
  const [showModel, setShowModel] = useState(false);

  const reset = () => { setPhase("idle"); setRes(null); };

  const shapeRows = GEOMS
    .map((g) => ({ g, ...compute({ geom: g, base, inlay: INLAYS[0], target, force, length, type, method, strike, passes }) }))
    .sort((a, b) => b.pressure - a.pressure);
  const clawRows = CLAWS
    .map((c) => ({ c, ...compute({ geom, base, inlay, target, force, length, type, claw: c, tear: tearMode, method, strike, passes }) }))
    .sort((a, b) => b.pressure - a.pressure);
  const wrap = (fn) => (v) => { reset(); fn(v); };

  const run = () => {
    const r = compute({ geom, base, inlay, target, force, length, type, claw, tear: tearMode, method, strike, passes });
    r._col = target.col; r._gemcol = inlay.id !== "none" ? inlay.col : null;
    setRes(r); setPhase("running");
    setTimeout(() => setPhase("done"), 1150);
    const nb = new Set(badges);
    if (r.scratched === true && target.id === "vidrio") nb.add("vidrio");
    if (r.scratched === true && target.id === "zafiro") nb.add("zafiro");
    if (r.toolWorn && target.id === "movil") nb.add("movil");
    if (target.id === "diamante" && inlay.id === "diamante") nb.add("diamante");
    if (target.id === "piel" && r.scratched) nb.add("piel");
    if (target.id === "coche" && r.depthUm >= 45) nb.add("coche");
    if (target.id === "puertamadera" && r.verdict === "ATRAVIESA LA PUERTA") nb.add("resplandor");
    if (target.id === "puertametal" && r.scratched) nb.add("metal");
    if (claw) nb.add("depredador");
    if (claw && claw.id === "casuario" && method === "puncion" && strike && target.id === "piel" && r.scratched) nb.add("casuario");
    const nc = count + 1; if (nc >= 8) nb.add("fisico");
    setBadges(nb); setCount(nc);
    const toolLabel = claw ? `${clawTitle(claw)}${r.hasGem ? " + " + inlay.short : ""}` : `${geom.name}${r.hasGem ? " + " + inlay.short : ""}`;
    setLog((p) => [{ tool: toolLabel, tgt: target.name, verdict: r.verdict, col: r.vcol }, ...p].slice(0, 6));
  };

  const BADGES = [
    { id: "vidrio", t: "Barrera del vidrio" }, { id: "movil", t: "Pantalla a salvo" },
    { id: "zafiro", t: "Cazadora de zafiros" }, { id: "diamante", t: "Diamante vs diamante" },
    { id: "piel", t: "Marca en la piel" }, { id: "fisico", t: "Físico de bata" },
    { id: "coche", t: "Pintura al descubierto" }, { id: "depredador", t: "Depredador" },
    { id: "resplandor", t: "🪓 ¡Aquí está Johnny!" }, { id: "metal", t: "Marca en el metal" },
    { id: "casuario", t: "🦖 Dinosaurio vivo" },
  ];

  const Pill = ({ on, onClick, children }) => (
    <button onClick={onClick} aria-pressed={on}
      style={{ padding: "8px 11px", borderRadius: 10, cursor: "pointer", fontFamily: DISP, fontWeight: 700, fontSize: 12.5, whiteSpace: "nowrap", background: on ? C.rose : C.panel2, color: on ? C.bg : C.dim, border: `1px solid ${on ? C.rose : C.line}` }}>{children}</button>
  );
  const Label = ({ children }) => (
    <div style={{ fontFamily: MONO, fontSize: 11, letterSpacing: 1.5, color: C.gold, textTransform: "uppercase", marginBottom: 9 }}>{children}</div>
  );
  const Card = ({ children }) => (
    <div style={{ background: C.panel, border: `1px solid ${C.line}`, borderRadius: 16, padding: 15, marginBottom: 14 }}>{children}</div>
  );

  return (
    <div style={{ background: C.bg, minHeight: "100vh", padding: "20px 13px 44px", color: C.text }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Syne:wght@600;700;800&family=Space+Mono:wght@400;700&display=swap');
        *{box-sizing:border-box}
        input[type=range]{-webkit-appearance:none;appearance:none;height:4px;border-radius:4px;background:${C.line};outline:none;width:100%}
        input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:20px;height:20px;border-radius:50%;background:${C.rose};border:3px solid ${C.bg};cursor:pointer}
        input[type=range]::-moz-range-thumb{width:20px;height:20px;border-radius:50%;background:${C.rose};border:3px solid ${C.bg};cursor:pointer}
        .tool{transition:transform 1.1s cubic-bezier(.45,.05,.25,1)}
        .groove{transition:stroke-dashoffset 1.1s cubic-bezier(.45,.05,.25,1)}
        button:focus-visible{outline:2px solid ${C.mint};outline-offset:2px}
        .scroll::-webkit-scrollbar{height:6px}.scroll::-webkit-scrollbar-thumb{background:${C.line};border-radius:6px}
        @media (prefers-reduced-motion:reduce){.tool,.groove{transition:none}}
      `}</style>

      <div style={{ maxWidth: 560, margin: "0 auto" }}>
        <div style={{ fontFamily: MONO, fontSize: 11, letterSpacing: 2, color: C.mint, textTransform: "uppercase" }}>Salón de uñas · banco de tribología</div>
        <h1 style={{ fontFamily: DISP, fontWeight: 800, fontSize: 30, lineHeight: 1, margin: "6px 0 4px" }}>¿Qué raya a qué?</h1>
        <p style={{ color: C.dim, fontSize: 13.5, margin: "0 0 6px" }}>
          Dureza <b style={{ color: C.text }}>Vickers</b> + presión de contacto + desgaste de <b style={{ color: C.text }}>Archard</b> + adhesión de <b style={{ color: C.text }}>Van der Waals</b>.
        </p>
        <button onClick={() => setShowModel((s) => !s)} style={{ background: "none", border: "none", color: C.mint, fontFamily: MONO, fontSize: 11.5, cursor: "pointer", padding: 0, marginBottom: 14 }}>
          {showModel ? "▾ ocultar fundamentos" : "▸ fundamentos físicos"}
        </button>
        {showModel && (
          <div style={{ background: C.panel, border: `1px solid ${C.line}`, borderRadius: 14, padding: 14, marginBottom: 14, fontFamily: MONO, fontSize: 11.5, color: C.dim, lineHeight: 1.7 }}>
            <div>· <b style={{ color: C.text }}>Presión</b> P = N/A (MPa)</div>
            <div>· <b style={{ color: C.text }}>Rayar exige dos cosas</b>: ser más duro (r = HV_uña/HV_obj ≥ 1,25) Y presión suficiente (χ = P/H_obj). A poca presión → contacto elástico, desliza sin marcar.</div>
            <div>· <b style={{ color: C.text }}>Frágil</b> (vidrio, gemas) se raya con poca presión por microfractura; <b style={{ color: C.text }}>dúctil</b> (metales, madera, plástico) necesita acercarse a su dureza.</div>
            <div>· <b style={{ color: C.text }}>Fricción</b> de Coulomb: Ft = μ·N; la cizalla sube el esfuerzo equivalente σ_eq = P·√(1+3μ²) (von Mises) → ayuda a arar/cortar.</div>
            <div>· <b style={{ color: C.text }}>Fricción de rayado</b> (SCOF): μ = μ_adhesión + μ_arado. La componente de arado crece con el ángulo de ataque/penetración → Ft = (μ_adh+μ_arado)·N.</div>
            <div>· <b style={{ color: C.text }}>Modo de abrasión</b> (Hokkirigawa-Kato): el grado de penetración Dp = h/a decide <b style={{ color: C.text }}>arado</b> (Dp&lt;0,1: desplaza) → <b style={{ color: C.text }}>cuña</b> → <b style={{ color: C.text }}>corte</b> (Dp&gt;0,2: arranca viruta). Solo el corte remueve material de verdad (Archard·f_ab).</div>
            <div>· <b style={{ color: C.text }}>Criterio de Pintaude</b>: el abrasivo debe ser ≥ 1,2× más duro para rayar (de ahí el umbral r ≈ 1,25).</div>
            <div>· <b style={{ color: C.text }}>Embotamiento</b>: una punta poco más dura que el objetivo se deforma; la profundidad escala con (r−1) hasta r≈4 (gemas y metales gougean; la queratina no).</div>
            <div>· <b style={{ color: C.text }}>Profundidad</b> (indentación): h = √(F/(H·c)), c según lo roma de la punta.</div>
            <div>· <b style={{ color: C.text }}>Desgaste</b> (Archard): V ∝ K·F·L / H</div>
            <div>· <b style={{ color: C.text }}>Adhesión</b> (Van der Waals, JKR): F_adh = 1,5·π·R·W</div>
            <div>· <b style={{ color: C.text }}>Desgarro</b> (solo garras): la curva hace de gancho y palanca; rasga en vez de indentar → ventaja mecánica y menos embotamiento.</div>
            <div>· <b style={{ color: C.text }}>Piel</b>: rotura de epidermis ≈ 2 MPa</div>
            <div style={{ color: C.dimmer, marginTop: 6 }}>Mohs es ordinal y no lineal; el motor calcula en Vickers. Valores estilizados de literatura.</div>
          </div>
        )}

        <Card>
          <Label>1 · Herramienta</Label>
          <div style={{ display: "flex", gap: 7, marginBottom: 4 }}>
            <Pill on={!claw} onClick={() => wrap(setClaw)(null)}>Manicura humana</Pill>
          </div>
          {CLAW_GROUPS.map((g) => (
            <div key={g}>
              <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "10px 0 6px", letterSpacing: 1 }}>{g.toUpperCase()}</div>
              <div className="scroll" style={{ display: "flex", gap: 7, overflowX: "auto", paddingBottom: 4 }}>
                {CLAWS.filter((c) => c.group === g).map((c) => <Pill key={c.id} on={!!claw && claw.id === c.id} onClick={() => wrap(setClaw)(c)}>{c.name}</Pill>)}
              </div>
            </div>
          ))}
          <div style={{ height: 12 }} />

          {claw ? (
            <>
              <div style={{ display: "flex", gap: 14 }}>
                <div style={{ width: 78, height: 130, flexShrink: 0, background: C.panel2, borderRadius: 12, border: `1px solid ${C.line}`, padding: 6 }}>
                  <ClawGlyph claw={claw} inlay={inlay} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: DISP, fontWeight: 800, fontSize: 16, marginBottom: 4 }}>{clawTitle(claw)}</div>
                  <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dim, lineHeight: 1.5, marginBottom: 7 }}>{claw.desc}</div>
                  <div style={{ fontFamily: MONO, fontSize: 11, color: C.mint }}>
                    {claw.hv} HV <span style={{ color: C.dimmer }}>(Mohs {claw.mohs})</span><br />
                    <span style={{ color: C.dimmer }}>afilado</span> {claw.area.toFixed(claw.fang ? 3 : 2)} mm² · <span style={{ color: C.dimmer }}>curv</span> {(claw.curve * 100).toFixed(0)}%<br />
                    <span style={{ color: C.dimmer }}>peso</span> {claw.mass} kg · <span style={{ color: C.dimmer }}>fuerza</span> ~{claw.force} N
                  </div>
                </div>
              </div>
              <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "12px 0 5px" }}>INCRUSTACIÓN EN LA GARRA · si pones una gema, ella es la punta que araña (la garra mantiene su curvatura)</div>
              <div className="scroll" style={{ display: "flex", gap: 7, overflowX: "auto", paddingBottom: 6 }}>
                {INLAYS.map((i) => <Pill key={i.id} on={inlay.id === i.id} onClick={() => wrap(setInlay)(i)}>
                  {i.name}{i.mohs ? ` · M${i.mohs}` : ""}</Pill>)}
              </div>
              <div style={{ marginTop: 8, fontFamily: MONO, fontSize: 11.5, color: C.mint }}>
                Punta efectiva: <b>{inlay.id !== "none" ? inlay.hv : claw.hv} HV</b>
                <span style={{ color: C.dimmer }}> · contacto {(inlay.id !== "none" && !claw.fang ? inlay.area : claw.area).toFixed(claw.fang ? 3 : 2)} mm² · curvatura {(claw.curve * 100).toFixed(0)}%</span>
                {claw.fang && inlay.id !== "none" && <span style={{ display: "block", color: C.dimmer, marginTop: 2 }}>colmillo reforjado en {inlay.name.toLowerCase()}: aguja con dureza de {inlay.hv} HV</span>}
              </div>
            </>
          ) : (
            <>
              <div style={{ display: "flex", gap: 14 }}>
                <div style={{ width: 78, height: 130, flexShrink: 0, background: C.panel2, borderRadius: 12, border: `1px solid ${C.line}`, padding: 6 }}>
                  <FingerPreview geom={geom} inlay={inlay} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, marginBottom: 5 }}>FORMA</div>
                  <div className="scroll" style={{ display: "flex", gap: 7, overflowX: "auto", paddingBottom: 6 }}>
                    {GEOMS.map((g) => <Pill key={g.id} on={geom.id === g.id} onClick={() => wrap(setGeom)(g)}>{g.name}</Pill>)}
                  </div>
                  <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "8px 0 5px" }}>MATERIAL BASE</div>
                  <div style={{ display: "flex", gap: 7, flexWrap: "wrap" }}>
                    {BASES.map((b) => <Pill key={b.id} on={base.id === b.id} onClick={() => wrap(setBase)(b)}>{b.name}</Pill>)}
                  </div>
                </div>
              </div>
              <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "12px 0 5px" }}>INCRUSTACIÓN · metal / cristal / gema (la punta más dura araña)</div>
              <div className="scroll" style={{ display: "flex", gap: 7, overflowX: "auto", paddingBottom: 6 }}>
                {INLAYS.map((i) => <Pill key={i.id} on={inlay.id === i.id} onClick={() => wrap(setInlay)(i)}>
                  {i.name}{i.mohs ? ` · M${i.mohs}` : ""}</Pill>)}
              </div>
              <div style={{ marginTop: 8, fontFamily: MONO, fontSize: 11.5, color: C.mint }}>
                Dureza de tu uña: <b>{inlay.id !== "none" ? inlay.hv : base.hv} HV</b>
                <span style={{ color: C.dimmer }}> (Mohs {inlay.id !== "none" ? inlay.mohs : base.mohs}) · contacto {(inlay.id !== "none" ? inlay.area : geom.area).toFixed(2)} mm²</span>
              </div>
            </>
          )}
        </Card>

        <Card>
          <Label>2 · Material a rayar</Label>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            {TARGETS.map((t) => {
              const on = target.id === t.id;
              return (
                <button key={t.id} onClick={() => wrap(setTarget)(t)} aria-pressed={on}
                  style={{ display: "flex", alignItems: "center", gap: 7, padding: "7px 10px", borderRadius: 10, cursor: "pointer", fontFamily: DISP, fontWeight: 700, fontSize: 12, background: on ? C.panel2 : "transparent", color: on ? C.text : C.dim, border: `1px solid ${on ? C.rose : C.line}` }}>
                  <span style={{ width: 13, height: 13, borderRadius: 4, background: t.col, border: "1px solid rgba(255,255,255,.2)" }} />
                  {t.name}<span style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer }}>{t.skin ? "piel" : `${t.hv}HV${t.brittle ? "·frág" : ""}`}</span>
                </button>
              );
            })}
          </div>
        </Card>

        <Card>
          <Label>3 · Parámetros del ensayo</Label>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
            <span style={{ fontFamily: MONO, fontSize: 12, color: C.dim }}>Fuerza <span style={{ color: C.dimmer }}>(log)</span></span>
            <span style={{ fontFamily: MONO, fontSize: 14, color: C.rose }}>{fmtF(force)} N</span>
          </div>
          <input type="range" min="0" max="1" step="0.004" value={fToT(force)} aria-label="Fuerza"
            onChange={(e) => { const f = tToF(parseFloat(e.target.value)); wrap(setForce)(f < 10 ? Math.round(f * 10) / 10 : Math.round(f)); }} />
          <div style={{ display: "flex", justifyContent: "space-between", fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 3 }}>
            <span>0,5 N</span><span>roce humano</span><span>zarpazo</span><span>2000 N</span>
          </div>
          {claw && (
            <button onClick={() => wrap(setForce)(claw.force)}
              style={{ marginTop: 10, width: "100%", padding: "9px", borderRadius: 10, cursor: "pointer", fontFamily: DISP, fontWeight: 700, fontSize: 12.5, background: C.panel2, color: C.gold, border: `1px solid ${C.gold}` }}>
              ⤓ Usar fuerza MÁX. {claw.fang ? "del colmillo" : `del ${claw.name.toLowerCase()}`} · ~{claw.force} N
              <span style={{ display: "block", fontFamily: MONO, fontWeight: 400, fontSize: 9.5, color: C.dimmer, marginTop: 2 }}>
                {claw.fang
                  ? "límite del propio colmillo: la dentina cede a ~4 N. Refórjalo en metal (incrustación) y sube el deslizador para empujar más sin que se rompa."
                  : `máximo esfuerzo (zarpazo defensivo) · peso ~${claw.mass} kg. Un mimo/juego es mucho menos (~1–4 N)`}
              </span>
            </button>
          )}
          {!claw && (
            <button onClick={() => wrap(setForce)(30)}
              style={{ marginTop: 10, width: "100%", padding: "9px", borderRadius: 10, cursor: "pointer", fontFamily: DISP, fontWeight: 700, fontSize: 12.5, background: C.panel2, color: C.gold, border: `1px solid ${C.gold}` }}>
              ⤓ Usar fuerza MÁX. humana · ~30 N
              <span style={{ display: "block", fontFamily: MONO, fontWeight: 400, fontSize: 9.5, color: C.dimmer, marginTop: 2 }}>arañazo decidido, 1 uña (mujer ~50 kg). El límite es la uña: más y se dobla/rompe. Un roce normal es ~1–5 N</span>
            </button>
          )}
          <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "16px 0 7px" }}>MÉTODO</div>
          <div style={{ display: "flex", gap: 7 }}>
            <Pill on={method === "rayado"} onClick={() => wrap(setMethod)("rayado")}>Rayado (arrastre)</Pill>
            <Pill on={method === "puncion"} onClick={() => wrap(setMethod)("puncion")}>Punción / Inyección</Pill>
          </div>
          {method === "puncion" && (
            <div style={{ marginTop: 6 }}>
              <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, lineHeight: 1.5 }}>
                Penetración vertical, sin arrastre lateral: la punta entra recta y perfora. {claw && claw.fang ? "El colmillo, además, es hueco → inyecta veneno en el tejido." : "Solo el colmillo de víbora inyecta; el resto hace punción seca."} Manda la presión y la afiladez, no la longitud.
              </div>
              <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "12px 0 7px" }}>GOLPE</div>
              <div style={{ display: "flex", gap: 7 }}>
                <Pill on={!strike} onClick={() => wrap(setStrike)(false)}>Estático</Pill>
                <Pill on={strike} onClick={() => wrap(setStrike)(true)}>Impacto (golpe)</Pill>
              </div>
              <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 6, lineHeight: 1.5 }}>
                {strike
                  ? "Golpe dinámico: la energía cinética clava ×4 más hondo que un empuje estático. Lo que hace falta para atravesar una puerta de lado a lado."
                  : "Empuje cuasi-estático (equilibrio de fuerzas): conservador. Cambia a Impacto para una mordedura/golpe real."}
              </div>
            </div>
          )}
          {method === "rayado" && (<>
          <div style={{ display: "flex", justifyContent: "space-between", margin: "14px 0 6px" }}>
            <span style={{ fontFamily: MONO, fontSize: 12, color: C.dim }}>Longitud</span>
            <span style={{ fontFamily: MONO, fontSize: 14, color: C.rose }}>{length} mm</span>
          </div>
          <input type="range" min="5" max="60" step="1" value={length} aria-label="Longitud" onChange={(e) => wrap(setLength)(parseInt(e.target.value))} />
          <div style={{ display: "flex", justifyContent: "space-between", margin: "14px 0 6px" }}>
            <span style={{ fontFamily: MONO, fontSize: 12, color: C.dim }}>Pasadas <span style={{ color: C.dimmer }}>(mismo surco)</span></span>
            <span style={{ fontFamily: MONO, fontSize: 14, color: C.rose }}>{passes}×</span>
          </div>
          <input type="range" min="1" max="100" step="1" value={passes} aria-label="Pasadas" onChange={(e) => wrap(setPasses)(parseInt(e.target.value))} />
          <div style={{ display: "flex", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
            {[1, 5, 20, 50, 100].map((n) => (
              <button key={n} onClick={() => wrap(setPasses)(n)}
                style={{ flex: 1, minWidth: 44, padding: "6px 4px", borderRadius: 8, cursor: "pointer", fontFamily: MONO, fontSize: 12, fontWeight: 700, background: passes === n ? C.rose : C.panel2, color: passes === n ? C.bg : C.dim, border: `1px solid ${passes === n ? C.rose : C.line}` }}>
                {n}×
              </button>
            ))}
          </div>
          {passes > 1 && (
            <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 6, lineHeight: 1.5 }}>
              Arañar {passes} veces en la misma línea profundiza ×{Math.pow(passes, 0.4).toFixed(1)} (sublineal: cada pasada arranca menos). Puede ir cediendo capa a capa — pero si la herramienta no marca ni una vez, mil pasadas tampoco (solo se desgasta la punta).
            </div>
          )}
          <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "14px 0 7px" }}>TIPO DE ARAÑAZO</div>
          <div style={{ display: "flex", gap: 7 }}>
            {TYPES.map((t) => <Pill key={t.id} on={type.id === t.id} onClick={() => wrap(setType)(t)}>{t.name}</Pill>)}
          </div>
          {claw && (
            <>
              <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, margin: "14px 0 7px" }}>MODO DE GARRA</div>
              <div style={{ display: "flex", gap: 7 }}>
                <Pill on={!tearMode} onClick={() => wrap(setTearMode)(false)}>Arrastre</Pill>
                <Pill on={tearMode} onClick={() => wrap(setTearMode)(true)}>Desgarro (palanca)</Pill>
              </div>
              <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 6, lineHeight: 1.5 }}>
                {tearMode
                  ? `Gancho + palanca: la garra curva rasga en vez de arrastrar. Ventaja mecánica ×${(1 + 1.3 * claw.curve).toFixed(1)} y embotamiento reducido → mucho más profundo en lo desgarrable.`
                  : "Arrastre liso (como una uña). Cambia a Desgarro para que la curvatura haga palanca."}
              </div>
            </>
          )}
          </>)}
        </Card>

        <button onClick={run} disabled={phase === "running"}
          style={{ width: "100%", padding: "15px", borderRadius: 14, border: "none", cursor: "pointer", fontFamily: DISP, fontWeight: 800, fontSize: 17, letterSpacing: 0.5, background: phase === "running" ? C.panel2 : `linear-gradient(90deg,${C.rose},${C.gold})`, color: phase === "running" ? C.dim : "#2a0e1e", marginBottom: 14 }}>
          {phase === "running" ? "Arañando…" : "▸ ARAÑAR"}
        </button>

        <Card>
          <Label>Banco de ensayo</Label>
          <Bench res={res} phase={phase} length={length} />
          {phase === "done" && res && (
            <div style={{ marginTop: 10 }}>
              <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap" }}>
                <span style={{ fontFamily: DISP, fontWeight: 800, fontSize: 24, color: res.vcol }}>{res.verdict}</span>
                {res.tearing && <span style={{ fontFamily: MONO, fontSize: 10, color: C.bg, background: C.gold, borderRadius: 6, padding: "2px 7px", fontWeight: 700 }}>DESGARRO</span>}
                <span style={{ fontFamily: MONO, fontSize: 11, color: C.dim }}>{res.vsub}</span>
              </div>
              {!res.skin && !res.paint && (
                <div style={{ marginTop: 12 }}>
                  {[[res.claw ? "Garra" : "Tu uña", res.hvTool, res.mohsTool, C.rose], ["Objetivo", res.tHV, res.tMohs, C.mint]].map(([n, hv, m, c]) => (
                    <div key={n} style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 5 }}>
                      <span style={{ fontFamily: MONO, fontSize: 11, color: C.dim, width: 56 }}>{n}</span>
                      <div style={{ flex: 1, height: 8, background: C.panel2, borderRadius: 5, overflow: "hidden" }}>
                        <div style={{ width: `${hvBar(hv)}%`, height: "100%", background: c, borderRadius: 5 }} />
                      </div>
                      <span style={{ fontFamily: MONO, fontSize: 11.5, color: c, width: 74, textAlign: "right" }}>{hv} HV·M{m}</span>
                    </div>
                  ))}
                  <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, textAlign: "right" }}>escala log</div>
                </div>
              )}
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 12 }}>
                <Metric label="Presión contacto" val={`${fmtP(res.pressure)} MPa`} />
                {res.puncture
                  ? <Metric label="Profundidad punción" val={res.depthUm >= 1000 ? `≈ ${(res.depthUm / 1000).toFixed(1)} mm` : `≈ ${res.depthUm < 10 ? res.depthUm.toFixed(1) : res.depthUm.toFixed(0)} µm`} col={res.vcol} />
                  : res.skin
                    ? <Metric label="Esfuerzo penetr." val={`${fmtP(res.stress)} MPa`} col={res.vcol} />
                    : res.paint
                      ? <Metric label="Profundidad surco" val={`≈ ${res.depthUm < 10 ? res.depthUm.toFixed(1) : res.depthUm.toFixed(0)} µm`} col={res.vcol} />
                      : <Metric label="Ratio dureza r" val={`${res.ratio.toFixed(2)}×`} col={res.ratio >= 1.25 ? C.coral : res.ratio >= 0.8 ? C.gold : C.mint} />}
                {res.puncture && <Metric label={res.skin ? "Esfuerzo penetr." : "Ratio dureza r"} val={res.skin ? `${fmtP(res.stress)} MPa` : `${res.ratio.toFixed(2)}×`} col={res.vcol} />}
                {(res.paint || res.woodDoor) && <Metric label="Capa alcanzada" val={res.layer} col={res.vcol} />}
                {!res.puncture && !res.skin && !res.paint && <Metric label="Penetración χ" val={res.chi.toFixed(3)} col={res.chi >= 0.1 ? C.coral : C.dim} />}
                {!res.puncture && !res.skin && !res.paint && <Metric label="Profundidad surco" val={`≈ ${res.depthUm < 10 ? res.depthUm.toFixed(1) : res.depthUm.toFixed(0)} µm`} />}
                {res.absMode
                  ? <Metric label="Fricción rayado (SCOF)" val={`μ${res.muEff.toFixed(2)} = ${res.muAdh.toFixed(2)}adh + ${res.muPlough.toFixed(2)}arado`} col={res.muPlough > 0.3 ? C.coral : C.dim} />
                  : <Metric label="Fricción Coulomb" val={`μ${res.mu.toFixed(2)} · Ft ${res.Ffric.toFixed(2)}N`} />}
                {res.absMode && <Metric label="Modo abrasión" val={res.absMode === "corte" ? "corte (arranca viruta)" : res.absMode === "cuña" ? "cuña (apila proa)" : "arado (desplaza)"} col={res.absMode === "corte" ? C.coral : res.absMode === "cuña" ? C.gold : C.mint} />}
                <Metric label="Adhesión vdW (JKR)" val={`${res.Fadh_mN.toFixed(2)} mN`} />
                <Metric label="Desgaste Archard" val={`${res.wearIdx} u.a.`} />
                <Metric label="Qué cede" val={res.cede} />
                {res.puncture
                  ? <Metric label="Inyección" val={res.inject ? (res.pierces ? "sí · veneno" : "no perfora") : "no (punción seca)"} col={res.inject && res.pierces ? C.coral : C.dim} />
                  : <Metric label="Longitud" val={`${length} mm`} />}
              </div>
              <div style={{ marginTop: 12, background: C.panel2, borderRadius: 10, padding: 10 }}>
                {res.paint ? <PaintLayers depthUm={res.depthUm} vcol={res.vcol} /> : res.woodDoor ? <DoorLayers depthUm={res.depthUm} vcol={res.vcol} /> : <CrossSection res={res} />}
              </div>
              <p style={{ fontFamily: MONO, fontSize: 11, color: C.dim, lineHeight: 1.55, marginTop: 10, marginBottom: 4 }}>{TARGETS.find((t) => t.id === target.id).fact}</p>
              <p style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, lineHeight: 1.5, margin: 0 }}>
                Adhesión Van der Waals: {res.Fadh_mN.toFixed(2)} mN, minúscula frente a la fuerza aplicada. Solo domina a escala micro/nano o en superficies muy lisas a carga casi nula (gecko / stiction).
              </p>
            </div>
          )}
          {phase !== "done" && <p style={{ fontFamily: MONO, fontSize: 11.5, color: C.dimmer, marginTop: 8, marginBottom: 0 }}>Pulsa ARAÑAR para correr el ensayo.</p>}
        </Card>

        <Card>
          <Label>{claw ? "Comparar garras" : "Comparativa por forma"}</Label>
          {claw ? (
            <>
              <p style={{ fontFamily: MONO, fontSize: 11, color: C.dim, lineHeight: 1.5, margin: "0 0 4px" }}>
                Misma fuerza ({fmtF(force)} N) sobre {target.name}{inlay.id !== "none" ? ` con ${inlay.short}` : ""}. Todas son queratina (Mohs ~2,5-3): lo que cambia es el afilado, la curvatura y, si la pones, la gema de la punta.
              </p>
              {clawRows.map((r) => (
                <div key={r.c.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "9px 0", borderTop: `1px solid ${C.line}` }}>
                  <div style={{ width: 26, height: 34, flexShrink: 0 }}><ClawGlyph claw={r.c} inlay={inlay} tipColor={r.vcol} /></div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                      <span style={{ fontFamily: DISP, fontWeight: 700, fontSize: 13 }}>{r.c.name}</span>
                      <span style={{ fontFamily: MONO, fontSize: 10.5, color: r.vcol }}>{r.verdict}</span>
                    </div>
                    <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dimmer, margin: "2px 0 5px" }}>
                      {r.area.toFixed(2)} mm² · curv {(r.c.curve * 100).toFixed(0)}% · {fmtP(r.pressure)} MPa{r.depthUm > 0.1 ? ` · ${r.depthUm < 10 ? r.depthUm.toFixed(1) : r.depthUm.toFixed(0)}µm` : ""}
                    </div>
                    <div style={{ height: 6, background: C.panel2, borderRadius: 5, overflow: "hidden" }}>
                      <div style={{ width: `${Math.max(4, r.sev * 100)}%`, height: "100%", background: r.vcol, borderRadius: 5 }} />
                    </div>
                  </div>
                </div>
              ))}
              <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 8 }}>barra = rayado (severidad) · gato y rapaces ganan por punta diminuta + curvatura</div>
            </>
          ) : (
            <>
              <p style={{ fontFamily: MONO, fontSize: 11, color: C.dim, lineHeight: 1.5, margin: "0 0 4px" }}>
                Misma fuerza ({fmtF(force)} N) y base ({base.name}) sobre {target.name}. Solo cambia la forma → el área de contacto → la presión, el desgaste y el rayado. (Incrustación ignorada aquí para aislar la forma.)
              </p>
              {shapeRows.map((r) => (
                <div key={r.g.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "9px 0", borderTop: `1px solid ${C.line}` }}>
                  <GeomGlyph geom={r.g} col={r.vcol} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                      <span style={{ fontFamily: DISP, fontWeight: 700, fontSize: 13 }}>{r.g.name}</span>
                      <span style={{ fontFamily: MONO, fontSize: 10.5, color: r.vcol }}>{r.verdict}</span>
                    </div>
                    <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dimmer, margin: "2px 0 5px" }}>
                      {r.area.toFixed(2)} mm² · {fmtP(r.pressure)} MPa · desgaste {r.wearIdx}
                    </div>
                    <div style={{ height: 6, background: C.panel2, borderRadius: 5, overflow: "hidden" }}>
                      <div style={{ width: `${Math.max(4, r.sev * 100)}%`, height: "100%", background: r.vcol, borderRadius: 5 }} />
                    </div>
                  </div>
                </div>
              ))}
              <div style={{ fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 8 }}>barra = rayado (severidad del surco)</div>
            </>
          )}
        </Card>

        <Card>
          <Label>Logros de laboratorio</Label>
          <div style={{ display: "flex", gap: 7, flexWrap: "wrap" }}>
            {BADGES.map((b) => {
              const got = badges.has(b.id);
              return <span key={b.id} style={{ fontFamily: MONO, fontSize: 11, padding: "5px 9px", borderRadius: 8, background: got ? C.gold : C.panel2, color: got ? C.bg : C.dimmer, border: `1px solid ${got ? C.gold : C.line}` }}>{got ? "★ " : "○ "}{b.t}</span>;
            })}
          </div>
        </Card>

        {log.length > 0 && (
          <Card>
            <Label>Cuaderno · últimos ensayos</Label>
            {log.map((e, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "6px 0", borderBottom: i < log.length - 1 ? `1px solid ${C.line}` : "none" }}>
                <span style={{ fontFamily: MONO, fontSize: 11.5, color: C.dim, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{e.tool} → {e.tgt}</span>
                <span style={{ fontFamily: MONO, fontSize: 11.5, color: e.col, marginLeft: 8, flexShrink: 0 }}>{e.verdict}</span>
              </div>
            ))}
          </Card>
        )}

        <p style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, lineHeight: 1.5, marginTop: 4 }}>
          Modelo educativo con valores de dureza, fricción y adhesión aproximados de literatura (nanoindentación de uña ~2,9 GPa; rotura de piel ~2 MPa; adhesión JKR/Van der Waals). Mohs↔Vickers no es lineal.
        </p>
      </div>
    </div>
  );
}
