/* Escenarios de referencia ("golden"). Si cambias la física A PROPÓSITO, regenera con
   `npm run golden:update` y explica en el PR qué cambió y por qué (con fuente). */
import { GEOMS, BASES, INLAYS, CLAWS, TARGETS, TYPES, compute } from "../src/index.js";

const G = (id) => GEOMS.find((x) => x.id === id);
const B = (id) => BASES.find((x) => x.id === id);
const I = (id) => INLAYS.find((x) => x.id === id);
const K = (id) => CLAWS.find((x) => x.id === id);
const T = (id) => TARGETS.find((x) => x.id === id);
const TY = (id) => TYPES.find((x) => x.id === id);

export const SCENARIOS = [
  // [nombre, parámetros]
  ["uña almendra 4N sobre pintura", { geom: "almendra", target: "coche", force: 4 }],
  ["uña stiletto 30N sobre piel", { geom: "stiletto", target: "piel", force: 30 }],
  ["uña cuadrada 30N sobre piel", { geom: "cuadrada", target: "piel", force: 30 }],
  ["uña + diamante 30N sobre zafiro", { geom: "almendra", inlay: "diamante", target: "zafiro", force: 30 }],
  ["uña natural sobre vidrio", { geom: "almendra", target: "vidrio", force: 30 }],
  ["gato 15N sobre pintura", { claw: "gato", target: "coche", force: 15 }],
  ["oso 300N sobre pintura", { claw: "oso", target: "coche", force: 300 }],
  ["oso 300N desgarro sobre pintura", { claw: "oso", target: "coche", force: 300, tear: true }],
  ["gato 15N sobre piel", { claw: "gato", target: "piel", force: 15 }],
  ["gato 3N sobre piel (mimo)", { claw: "gato", target: "piel", force: 3 }],
  ["pájaro 1.5N sobre piel", { claw: "pajaro", target: "piel", force: 1.5 }],
  ["gato 12N sobre puerta aluminio (punción)", { claw: "gato", target: "puertametal", force: 12, method: "puncion" }],
  ["víbora 4N sobre piel (punción)", { claw: "vibora", target: "piel", force: 4, method: "puncion" }],
  ["víbora 4N sobre puerta madera (punción)", { claw: "vibora", target: "puertamadera", force: 4, method: "puncion" }],
  ["gabón 30N impacto sobre piel", { claw: "gabon", target: "piel", force: 30, method: "puncion", strike: true }],
  ["casuario 500N impacto sobre piel", { claw: "casuario", target: "piel", force: 500, method: "puncion", strike: true }],
  ["casuario 500N sobre pintura", { claw: "casuario", target: "coche", force: 500 }],
  ["avestruz 900N sobre pintura", { claw: "avestruz", target: "coche", force: 900 }],
  ["buitre 60N sobre pintura", { claw: "buitre", target: "coche", force: 60 }],
  ["garra+tungsteno 200N impacto puerta madera", { claw: "gato", inlay: "tungsteno", target: "puertamadera", force: 200, method: "puncion", strike: true }],
  ["uña almendra 20 pasadas sobre pintura", { geom: "almendra", target: "coche", force: 4, passes: 20 }],
  ["uña natural sobre acero 100 pasadas", { geom: "stiletto", target: "acero", force: 30, passes: 100 }],
  // Modelo v2: humedad, gemas, rotura de colmillo, impacto por energía
  ["uña almendra húmeda 30N sobre pintura", { geom: "almendra", target: "coche", force: 30, wet: true }],
  ["uña + cuarzo 30N sobre pantalla móvil", { geom: "almendra", inlay: "cuarzo", target: "movil", force: 30 }],
  ["víbora 40N punción sobre vidrio (rompe)", { claw: "vibora", target: "vidrio", force: 40, method: "puncion" }],
  ["casuario 500N impacto puerta madera", { claw: "casuario", target: "puertamadera", force: 500, method: "puncion", strike: true }],
  ["pájaro 1.5N punción sobre piel", { claw: "pajaro", target: "piel", force: 1.5, method: "puncion" }],
  // Piel por capas (v2.2): rasguños, excoriación a fuerza de pasadas, desgarro y laceración
  ["uña almendra 4N sobre piel (rascarse)", { geom: "almendra", target: "piel", force: 4 }],
  ["uña almendra 30N ×20 sobre piel", { geom: "almendra", target: "piel", force: 30, passes: 20 }],
  ["gato 15N desgarro sobre piel", { claw: "gato", target: "piel", force: 15, tear: true }],
  ["tigre 260N sobre piel", { claw: "tigre", target: "piel", force: 260 }],
  // Coches (v2.3): carrocería clásica, moderna, de aluminio y de plástico; la chapa se perfora en pétalos
  ["águila de acero, golpe, coche clásico", { claw: "aguila", inlay: "acero", target: "cocheclasico", force: 20, method: "puncion", strike: true }],
  ["uña stiletto de metal, golpe, coche moderno", { geom: "stiletto", base: "metal", target: "coche", force: 30, method: "puncion", strike: true }],
  ["uña stiletto de metal, golpe, coche clásico", { geom: "stiletto", base: "metal", target: "cocheclasico", force: 30, method: "puncion", strike: true }],
  ["águila de zafiro, golpe, coche de aluminio", { claw: "aguila", inlay: "zafiro", target: "cochealu", force: 20, method: "puncion", strike: true }],
  ["oso, zarpazo, aleta de plástico", { claw: "oso", target: "cocheplastico", force: 300, method: "puncion", strike: true }],
  ["oso de diamante 300N sobre coche moderno", { claw: "oso", inlay: "diamante", target: "coche", force: 300 }],
  ["tigre de tungsteno, zarpazo, puerta de aluminio", { claw: "tigre", inlay: "tungsteno", target: "puertametal", force: 260, method: "puncion", strike: true }],
  // Vidrio de ventana (hoja de 4 mm): se parte por flexión, no por dureza
  ["gato, zarpazo, ventana", { claw: "gato", target: "vidrio", force: 15, method: "puncion", strike: true }],
  ["oso, zarpazo, ventana", { claw: "oso", target: "vidrio", force: 300, method: "puncion", strike: true }],
];

export function runScenario(p) {
  return compute({
    geom: G(p.geom || "almendra"),
    base: B(p.base || "natural"),
    inlay: I(p.inlay || "none"),
    target: T(p.target),
    force: p.force,
    length: p.length ?? 25,
    type: TY(p.type || "aranazo"),
    claw: p.claw ? K(p.claw) : null,
    tear: !!p.tear,
    method: p.method || "rayado",
    strike: !!p.strike,
    passes: p.passes ?? 1,
    wet: !!p.wet,
  });
}

export const snapshot = (r) => ({
  verdict: r.verdict,
  depthUm: Math.round(r.depthUm * 10) / 10,
  pressureMPa: Math.round(r.pressure * 10) / 10,
  layer: r.layer ?? null,
});
