/* ════════ ART ════════
   Ilustraciones compartidas por escritorio (React DOM) y móvil (react-native-svg).
   Cada función devuelve un grafo de escena: nodos { tag, attrs, children } con etiquetas SVG y
   atributos en camelCase de React (stopColor, strokeWidth, clipPath…), válidos en las dos
   plataformas. Cada app solo los traduce a elementos. Sin filtros SVG (móvil no los soporta):
   todo el realismo sale de degradados, capas y detalle procedural DETERMINISTA (mismo dibujo
   en cada render y en las dos apps). No calcula física: solo pinta resultados del motor. */
import { PAINT_LAYERS, SKIN_LAYERS, TARGETS, carLayers } from "./data.js";
import { C } from "./theme.js";
import { fmtDepth } from "./physics.js";

/* ── Grafo de escena ── */
export const h = (tag, attrs = {}, ...children) => ({ tag, attrs, children: children.flat(Infinity).filter(Boolean) });

/* ── Aleatorio determinista (mulberry32) y semilla a partir de un texto ── */
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export const seedOf = (s) => { let x = 2166136261; for (const ch of String(s)) x = Math.imul(x ^ ch.charCodeAt(0), 16777619); return x >>> 0; };

/* ── Color ── */
const cl = (x, a, b) => Math.max(a, Math.min(b, x));
const toRgb = (c) => { const n = parseInt(c.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const toHex = (r, g, b) => "#" + [r, g, b].map((v) => Math.round(cl(v, 0, 255)).toString(16).padStart(2, "0")).join("").toUpperCase();
export const mix = (a, b, t) => { const A = toRgb(a), B = toRgb(b); return toHex(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t); };
export const lighten = (c, t) => mix(c, "#FFFFFF", t);
export const darken = (c, t) => mix(c, "#000000", t);
export const rgba = (c, a) => { const [r, g, b] = toRgb(c); return `rgba(${r},${g},${b},${a})`; };

/* ── Utilidades SVG ── */
const r2 = (v) => Math.round(v * 100) / 100;
const pts = (arr) => arr.map(([x, y]) => `${r2(x)},${r2(y)}`).join(" ");
const poly = (arr, close = true) => "M" + arr.map(([x, y]) => `${r2(x)} ${r2(y)}`).join(" L") + (close ? " Z" : "");
const lin = (id, stops, g = {}) => h("linearGradient", { id, x1: g.x1 ?? 0, y1: g.y1 ?? 0, x2: g.x2 ?? 0, y2: g.y2 ?? 1, ...(g.user ? { gradientUnits: "userSpaceOnUse" } : {}) },
  stops.map(([o, c, op = 1], i) => h("stop", { key: i, offset: o, stopColor: c, stopOpacity: op })));
const rad = (id, stops, g = {}) => h("radialGradient", { id, cx: g.cx ?? 0.5, cy: g.cy ?? 0.5, r: g.r ?? 0.5, ...(g.fx != null ? { fx: g.fx, fy: g.fy } : {}) },
  stops.map(([o, c, op = 1], i) => h("stop", { key: i, offset: o, stopColor: c, stopOpacity: op })));
/** Destello de 4 puntas (brillo de gema o cristal). */
export const sparkle = (cx, cy, r) => `M${r2(cx)} ${r2(cy - r)} Q${r2(cx)} ${r2(cy)} ${r2(cx + r)} ${r2(cy)} Q${r2(cx)} ${r2(cy)} ${r2(cx)} ${r2(cy + r)} Q${r2(cx)} ${r2(cy)} ${r2(cx - r)} ${r2(cy)} Q${r2(cx)} ${r2(cy)} ${r2(cx)} ${r2(cy - r)} Z`;
/** Línea ondulada horizontal (vetas de madera, fibras). */
function wavy(x0, x1, y, amp, freq, phase, n = 14) {
  const out = [];
  for (let i = 0; i <= n; i++) { const x = x0 + ((x1 - x0) * i) / n; out.push([x, y + amp * Math.sin(phase + freq * x) + amp * 0.35 * Math.sin(phase * 1.7 + freq * 2.3 * x)]); }
  return poly(out, false);
}

/* ════════ MATERIALES ════════ */
export const MATERIAL_LOOK = {
  piel: { kind: "skin", base: "#EFC3A6", lo: "#D9977B", ink: "#B8735B" },
  madera: { kind: "wood", base: "#E6C08A", lo: "#C8985C", ink: "#9C6C37", knot: true },
  puertamadera: { kind: "wood", base: "#A36E40", lo: "#6B4222", ink: "#43260F", lacquer: true },
  puertametal: { kind: "brushed", base: "#D0D6DD", lo: "#98A1AB" },
  una: { kind: "keratin", base: "#F6D8D4", lo: "#E4B6B2" },
  plastico: { kind: "plastic", base: "#667688", lo: "#465261" },
  coche: { kind: "paint", base: "#A1263C", lo: "#560F1F", flake: "#FFB3C1" },
  cocheclasico: { kind: "paint", base: "#2F6B57", lo: "#163B30", flake: null },       // esmalte liso de época, sin metalizado
  cochealu: { kind: "paint", base: "#8FA8C2", lo: "#4B6078", flake: "#FFFFFF" },       // gris azulado metalizado
  cocheplastico: { kind: "paint", base: "#ECEAE4", lo: "#B9B6AE", flake: "#FFFFFF" },  // blanco nacarado
  cobre: { kind: "copper", base: "#E7A064", lo: "#9C5426", ink: "#5E8C6A" },
  vidrio: { kind: "glass", base: "#CBF1EC", lo: "#86CBC6" },
  acero: { kind: "brushed", base: "#CBD2DA", lo: "#8B95A1", tint: "#AFC6DB" },
  movil: { kind: "screen", base: "#27303F", lo: "#0B1018" },
  cuarzo: { kind: "stone", base: "#EEE8DF", lo: "#D3CABC", flecks: ["#8E867B", "#655F58", "#C9BBA3", "#FFFFFF", "#AFA597"] },
  zafiro: { kind: "crystal", base: "#8CBDF0", lo: "#2F58A0" },
  diamante: { kind: "diamond", base: "#F1F7FF", lo: "#BFD1EA" },
  // capas de los cortes (pintura OEM y puerta)
  "capa-barniz": { kind: "clear", base: "#E2F3F8", lo: "#B4D6E3" },
  "capa-color": { kind: "paint", base: "#A1263C", lo: "#6A1426", flake: "#FFB3C1" },
  "capa-imprimacion": { kind: "matte", base: "#B6BBC0", lo: "#979DA4" },
  "capa-anticorrosivo": { kind: "matte", base: "#5C6854", lo: "#434C3D" },
  // carrocerías (corte de capas del coche)
  "capa-acero-bh": { kind: "brushed", base: "#C3CAD2", lo: "#8C95A0" },
  "capa-acero-dulce": { kind: "brushed", base: "#B4BBC3", lo: "#7A838D" },
  "capa-aluminio": { kind: "brushed", base: "#DDE3EA", lo: "#A7B1BD" },
  "capa-plastico-carroceria": { kind: "plastic", base: "#43484F", lo: "#26292E" },
  "capa-laca": { kind: "lacquer", base: "#DDAE5B", lo: "#B7822F" },
  "capa-roble": { kind: "wood", base: "#A36E40", lo: "#6B4222", ink: "#43260F" },
  // capas de la piel (corte de tejido)
  "tejido-cornea": { kind: "cornea", base: "#F6E7D8", lo: "#E9CFB9" },
  "tejido-epidermis": { kind: "cells", base: "#EDBBA2", lo: "#DB9C82", ink: "#B8735B" },
  "tejido-dermis": { kind: "collagen", base: "#E0A09A", lo: "#C57872", ink: "#9E4B4B", vessel: "#C2303A" },
  "tejido-grasa": { kind: "fat", base: "#F3D98A", lo: "#E0B95A", ink: "#C9A04A" },
  "tejido-fascia": { kind: "fascia", base: "#ECEEF3", lo: "#C9CDD8" },
  "tejido-musculo": { kind: "muscle", base: "#B23F48", lo: "#7E232C", ink: "#5E1720" },
};
/** Aspecto de cada capa de la piel (los ids coinciden con SKIN_LAYERS). */
export const SKIN_LAYER_LOOK = { cornea: "tejido-cornea", epidermis: "tejido-epidermis", dermis: "tejido-dermis", grasa: "tejido-grasa", fascia: "tejido-fascia", musculo: "tejido-musculo" };
/** Aspecto de cada capa de pintura (los ids coinciden con PAINT_LAYERS). */
export const PAINT_LAYER_LOOK = { barniz: "capa-barniz", color: "capa-color", imprimacion: "capa-imprimacion", anticorrosivo: "capa-anticorrosivo" };
/** Aspecto de cada carrocería (los ids coinciden con CAR_BODIES[…].id). */
export const BODY_LOOK = { "acero-bh": "capa-acero-bh", "acero-dulce": "capa-acero-dulce", aluminio: "capa-aluminio", "plastico-carroceria": "capa-plastico-carroceria" };

/** Rellena el rectángulo (x, y, w, h) con el aspecto del material. `detail` 0-1 reduce el detalle en miniaturas. */
export function surfaceArt(lookId, { x = 0, y = 0, w, h: H, uid = "s", detail = 1, rx = 0 }) {
  const L = MATERIAL_LOOK[lookId] || MATERIAL_LOOK.plastico;
  const R = rng(seedOf(`${lookId}:${Math.round(w)}x${Math.round(H)}`));
  const id = `${uid}-${lookId}`;
  const n = (k) => Math.max(1, Math.round(k * detail));
  const defs = [
    lin(`${id}-g`, [[0, lighten(L.base, 0.08)], [0.55, L.base], [1, L.lo]]),
    h("clipPath", { id: `${id}-c` }, h("rect", { x, y, width: w, height: H, rx })),
  ];
  const body = [h("rect", { x, y, width: w, height: H, rx, fill: `url(#${id}-g)` })];
  const add = (node) => body.push(node);
  const sheen = (op, from = 0, to = 0.45) => {
    defs.push(lin(`${id}-sh`, [[0, "#FFFFFF", op], [1, "#FFFFFF", 0]]));
    add(h("rect", { x, y: y + H * from, width: w, height: H * (to - from), fill: `url(#${id}-sh)` }));
  };
  switch (L.kind) {
    case "skin": {
      defs.push(rad(`${id}-hl`, [[0, "#FFFFFF", 0.28], [1, "#FFFFFF", 0]], { cx: 0.35, cy: 0.3, r: 0.6 }));
      add(h("rect", { x, y, width: w, height: H, fill: `url(#${id}-hl)` }));
      for (let i = 0; i < n(4); i++) { const yy = y + H * (0.2 + 0.6 * R()); add(h("path", { d: wavy(x, x + w, yy, 0.6 + R(), 0.05 + 0.05 * R(), R() * 6), stroke: L.ink, strokeOpacity: 0.18, strokeWidth: 0.5, fill: "none" })); }
      for (let i = 0; i < n((w * H) / 55); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.25 + R() * 0.4, fill: L.ink, fillOpacity: 0.28 }));
      break;
    }
    case "wood": {
      const lines = n(H / 3.2);
      for (let i = 0; i < lines; i++) {
        const yy = y + ((i + 0.5) * H) / lines + (R() - 0.5) * 2;
        add(h("path", { d: wavy(x - 2, x + w + 2, yy, 0.6 + R() * 1.6, 0.03 + R() * 0.04, R() * 6), stroke: L.ink, strokeOpacity: 0.25 + R() * 0.35, strokeWidth: 0.4 + R() * 1.1, fill: "none" }));
      }
      if (L.knot && detail > 0.6) {
        const kx = x + w * (0.25 + 0.5 * R()), ky = y + H * (0.35 + 0.3 * R());
        for (let k = 0; k < 4; k++) add(h("ellipse", { cx: kx, cy: ky, rx: 3 + k * 2.4, ry: 1.5 + k * 1.2, stroke: L.ink, strokeOpacity: 0.45 - k * 0.08, strokeWidth: 0.7, fill: k === 0 ? L.ink : "none", fillOpacity: 0.5 }));
      }
      if (L.lacquer) { sheen(0.3, 0, 0.5); add(h("rect", { x, y: y + H * 0.1, width: w, height: 0.8, fill: "#FFFFFF", fillOpacity: 0.35 })); }
      break;
    }
    case "brushed": {
      for (let i = 0; i < n(H / 1.1); i++) {
        const yy = y + R() * H;
        add(h("line", { x1: x, y1: yy, x2: x + w, y2: yy, stroke: R() > 0.5 ? "#FFFFFF" : "#000000", strokeOpacity: 0.04 + R() * 0.09, strokeWidth: 0.3 + R() * 0.5 }));
      }
      defs.push(lin(`${id}-sp`, [[0, "#FFFFFF", 0], [0.5, "#FFFFFF", 0.32], [1, "#FFFFFF", 0]], { x1: 0, y1: 0, x2: 1, y2: 0 }));
      add(h("rect", { x: x + w * 0.35, y, width: w * 0.25, height: H, fill: `url(#${id}-sp)` }));
      if (L.tint) add(h("rect", { x, y, width: w, height: H, fill: L.tint, fillOpacity: 0.12 }));
      break;
    }
    case "keratin": {
      for (let xx = x + 2; xx < x + w; xx += 3 + R() * 2) add(h("line", { x1: xx, y1: y, x2: xx + (R() - 0.5) * 2, y2: y + H, stroke: R() > 0.5 ? "#FFFFFF" : L.lo, strokeOpacity: 0.22, strokeWidth: 0.6 }));
      sheen(0.35, 0, 0.35);
      break;
    }
    case "plastic": {
      for (let i = 0; i < n((w * H) / 18); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.2 + R() * 0.3, fill: R() > 0.5 ? "#FFFFFF" : "#000000", fillOpacity: 0.1 + R() * 0.12 }));
      sheen(0.14, 0, 0.3);
      break;
    }
    case "paint": {
      // metalizado: escamas de aluminio en la capa de color; un esmalte liso de época solo tiene "piel de naranja"
      if (L.flake) for (let i = 0; i < n((w * H) / 10); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.25 + R() * 0.45, fill: R() > 0.3 ? L.flake : "#FFFFFF", fillOpacity: 0.12 + R() * 0.38 }));
      else for (let i = 0; i < n((w * H) / 40); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.6 + R() * 0.9, fill: "#FFFFFF", fillOpacity: 0.04 + R() * 0.05 }));
      defs.push(lin(`${id}-cc`, [[0, "#FFFFFF", 0], [0.5, "#FFFFFF", 0.22], [1, "#FFFFFF", 0]]));
      add(h("path", { d: `M${x} ${y + H * 0.18} Q${x + w * 0.5} ${y - H * 0.05} ${x + w} ${y + H * 0.22} L${x + w} ${y + H * 0.42} Q${x + w * 0.5} ${y + H * 0.2} ${x} ${y + H * 0.4} Z`, fill: `url(#${id}-cc)` }));
      add(h("path", { d: `M${x + w * 0.05} ${y + H * 0.22} Q${x + w * 0.5} ${y + H * 0.04} ${x + w * 0.95} ${y + H * 0.25}`, stroke: "#FFFFFF", strokeOpacity: 0.45, strokeWidth: 0.7, fill: "none" }));
      break;
    }
    case "copper": {
      defs.push(lin(`${id}-d`, [[0, lighten(L.base, 0.25)], [0.45, L.base], [1, L.lo]], { x1: 0, y1: 0, x2: 1, y2: 1 }));
      body[0] = h("rect", { x, y, width: w, height: H, rx, fill: `url(#${id}-d)` });
      defs.push(rad(`${id}-hl`, [[0, "#FFFFFF", 0.35], [1, "#FFFFFF", 0]], { cx: 0.3, cy: 0.3, r: 0.55 }));
      add(h("rect", { x, y, width: w, height: H, fill: `url(#${id}-hl)` }));
      for (let i = 0; i < n(H / 1.4); i++) { const yy = y + R() * H; add(h("line", { x1: x, y1: yy, x2: x + w, y2: yy + (R() - 0.5) * 3, stroke: "#FFFFFF", strokeOpacity: 0.05 + R() * 0.07, strokeWidth: 0.4 })); }
      for (let i = 0; i < n(6); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.6 + R() * 1.6, fill: L.ink, fillOpacity: 0.18 + R() * 0.15 }));
      break;
    }
    case "glass": {
      body[0] = h("rect", { x, y, width: w, height: H, rx, fill: `url(#${id}-g)`, fillOpacity: 0.85 });
      add(h("polygon", { points: pts([[x + w * 0.12, y], [x + w * 0.2, y], [x + w * 0.1, y + H], [x + w * 0.02, y + H]]), fill: "#FFFFFF", fillOpacity: 0.3 }));
      add(h("polygon", { points: pts([[x + w * 0.24, y], [x + w * 0.27, y], [x + w * 0.17, y + H], [x + w * 0.14, y + H]]), fill: "#FFFFFF", fillOpacity: 0.18 }));
      add(h("polygon", { points: pts([[x + w * 0.66, y], [x + w * 0.74, y], [x + w * 0.64, y + H], [x + w * 0.56, y + H]]), fill: "#FFFFFF", fillOpacity: 0.12 }));
      add(h("rect", { x, y, width: w, height: 0.9, fill: "#FFFFFF", fillOpacity: 0.7 }));
      break;
    }
    case "screen": {
      defs.push(lin(`${id}-rf`, [[0, "#FFFFFF", 0.12], [1, "#FFFFFF", 0]], { x1: 0, y1: 0, x2: 1, y2: 1 }));
      add(h("polygon", { points: pts([[x, y], [x + w * 0.55, y], [x + w * 0.25, y + H], [x, y + H]]), fill: `url(#${id}-rf)` }));
      defs.push(rad(`${id}-gl`, [[0, "#4A7BD0", 0.22], [1, "#4A7BD0", 0]], { cx: 0.7, cy: 0.6, r: 0.5 }));
      add(h("rect", { x, y, width: w, height: H, fill: `url(#${id}-gl)` }));
      add(h("rect", { x, y, width: w, height: 0.8, fill: "#FFFFFF", fillOpacity: 0.3 }));
      break;
    }
    case "stone": {
      for (let i = 0; i < n((w * H) / 9); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.25 + R() * R() * 1.4, fill: L.flecks[Math.floor(R() * L.flecks.length)], fillOpacity: 0.35 + R() * 0.55 }));
      for (let i = 0; i < n(2); i++) add(h("path", { d: wavy(x, x + w, y + H * (0.2 + 0.6 * R()), 2 + R() * 3, 0.02 + R() * 0.03, R() * 6, 10), stroke: "#FFFFFF", strokeOpacity: 0.35, strokeWidth: 0.6, fill: "none" }));
      sheen(0.16, 0, 0.3);
      break;
    }
    case "crystal":
    case "diamond": {
      const k = L.kind === "diamond";
      for (let i = 0; i < n(k ? 26 : 14); i++) {
        const cx = x + R() * w, cy = y + R() * H, s = 3 + R() * (k ? 8 : 12);
        add(h("polygon", { points: pts([[cx, cy - s], [cx + s * (0.6 + R() * 0.6), cy + s * 0.4], [cx - s * (0.5 + R() * 0.6), cy + s * (0.2 + R() * 0.5)]]), fill: R() > (k ? 0.45 : 0.6) ? "#FFFFFF" : L.lo, fillOpacity: 0.07 + R() * (k ? 0.25 : 0.16) }));
      }
      for (let i = 0; i < n(k ? 5 : 2); i++) add(h("path", { d: sparkle(x + R() * w, y + R() * H * 0.8, 1.5 + R() * 2.5), fill: "#FFFFFF", fillOpacity: 0.85 }));
      sheen(0.25, 0, 0.35);
      break;
    }
    case "clear": {
      body[0] = h("rect", { x, y, width: w, height: H, rx, fill: `url(#${id}-g)`, fillOpacity: 0.8 });
      add(h("rect", { x, y: y + H * 0.15, width: w, height: Math.max(0.6, H * 0.08), fill: "#FFFFFF", fillOpacity: 0.5 }));
      break;
    }
    case "matte": {
      for (let i = 0; i < n((w * H) / 12); i++) add(h("circle", { cx: x + R() * w, cy: y + R() * H, r: 0.2 + R() * 0.35, fill: R() > 0.5 ? "#FFFFFF" : "#000000", fillOpacity: 0.08 + R() * 0.1 }));
      break;
    }
    case "lacquer": {
      for (let i = 0; i < n(H / 4); i++) add(h("path", { d: wavy(x, x + w, y + R() * H, 0.5 + R(), 0.05, R() * 6), stroke: darken(L.lo, 0.3), strokeOpacity: 0.25, strokeWidth: 0.5, fill: "none" }));
      sheen(0.4, 0, 0.5);
      break;
    }
    case "cornea": {   // escamas de células muertas, apiladas
      for (let i = 0; i < n(w / 5); i++) { const xx = x + R() * w, yy = y + R() * H; add(h("path", { d: `M${r2(xx - 3)} ${r2(yy)} q3 ${r2(-0.8 - R())} 6 0`, stroke: L.lo, strokeOpacity: 0.6, strokeWidth: 0.5, fill: "none" })); }
      sheen(0.35, 0, 0.6);
      break;
    }
    case "cells": {    // queratinocitos: células redondeadas con núcleo
      for (let i = 0; i < n((w * H) / 14); i++) { const cx = x + R() * w, cy = y + R() * H, r = 1 + R() * 0.8; add(h("circle", { cx: r2(cx), cy: r2(cy), r: r2(r), fill: "none", stroke: L.ink, strokeOpacity: 0.28, strokeWidth: 0.35 })); add(h("circle", { cx: r2(cx), cy: r2(cy), r: 0.35, fill: L.ink, fillOpacity: 0.45 })); }
      break;
    }
    case "collagen": { // haces de colágeno ondulados y capilares arriba (papilas)
      for (let i = 0; i < n(H / 2.2); i++) add(h("path", { d: wavy(x, x + w, y + R() * H, 0.8 + R() * 1.2, 0.08 + R() * 0.08, R() * 6, 18), stroke: R() > 0.5 ? "#FFFFFF" : L.ink, strokeOpacity: 0.16 + R() * 0.14, strokeWidth: 0.5 + R() * 0.6, fill: "none" }));
      for (let i = 0; i < n(w / 12); i++) { const xx = x + ((i + R()) * w) / n(w / 12); add(h("path", { d: `M${r2(xx - 2)} ${r2(y + 0.5)} q2 ${r2(3 + R() * 3)} 4 0`, stroke: L.vessel, strokeOpacity: 0.7, strokeWidth: 0.6, fill: "none" })); }
      break;
    }
    case "fat": {      // lóbulos de adipocitos
      for (let i = 0; i < n((w * H) / 16); i++) { const cx = x + R() * w, cy = y + R() * H, r = 1.6 + R() * 1.8; add(h("circle", { cx: r2(cx), cy: r2(cy), r: r2(r), fill: "#FFF3C8", fillOpacity: 0.35, stroke: L.ink, strokeOpacity: 0.45, strokeWidth: 0.4 })); }
      break;
    }
    case "fascia": {   // lámina brillante de colágeno paralelo
      for (let i = 0; i < n(H / 0.9); i++) { const yy = y + R() * H; add(h("line", { x1: x, y1: r2(yy), x2: x + w, y2: r2(yy + (R() - 0.5)), stroke: R() > 0.4 ? "#FFFFFF" : L.lo, strokeOpacity: 0.5, strokeWidth: 0.35 })); }
      sheen(0.5, 0, 0.7);
      break;
    }
    case "muscle": {   // fibras con estrías
      for (let i = 0; i < n(H / 2.6); i++) { const yy = y + ((i + 0.5) * H) / n(H / 2.6); add(h("line", { x1: x, y1: r2(yy), x2: x + w, y2: r2(yy + (R() - 0.5) * 1.5), stroke: L.ink, strokeOpacity: 0.45, strokeWidth: 0.7 })); }
      for (let xx = x + 1; xx < x + w; xx += 2.2 + R()) add(h("line", { x1: r2(xx), y1: y, x2: r2(xx + (R() - 0.5)), y2: y + H, stroke: "#FFFFFF", strokeOpacity: 0.06, strokeWidth: 0.5 }));
      break;
    }
    default: break;
  }
  return { defs, body: [h("g", { clipPath: `url(#${id}-c)` }, body)] };
}

/* ════════ MARCAS: SURCO Y PERFORACIÓN ════════ */
const BRITTLE = new Set(["glass", "screen", "stone", "crystal", "diamond"]);
const METALLIC = new Set(["brushed", "copper"]);
/** El coche (material con carrocería) de ese id, o null. */
const carOf = (targetId) => TARGETS.find((t) => t.id === targetId && t.body) || null;
/** Color del fondo del surco en la pintura según la capa alcanzada (se ve la capa de debajo): el color
 *  de cada coche y, al pasar la pintura, su carrocería (acero o aluminio brillante, plástico gris oscuro). */
function paintGrooveColor(depthUm, targetId = "coche") {
  const car = carOf(targetId), body = car ? car.body : null;
  if (depthUm > PAINT_LAYERS.at(-1).to) return body && !body.metal ? "#50565E" : lighten(body ? body.col : "#C3CAD2", 0.45);
  const l = PAINT_LAYERS.find((p) => depthUm <= p.to) || PAINT_LAYERS.at(-1);
  const look = MATERIAL_LOOK[targetId] || MATERIAL_LOOK.coche;
  return { barniz: "#F4F1F2", color: lighten(look.base, 0.12), imprimacion: "#CDD1D5", anticorrosivo: body && !body.metal ? "#A9AEB4" : "#76846B" }[l.id];
}

/**
 * Surco horizontal de x1 a x2 en la altura y. Devuelve { lines, extras, length }: las `lines` admiten
 * la animación de trazo (strokeDasharray = length); los `extras` (esquirlas, gotas, fibras) aparecen al final.
 */
export function grooveArt(targetId, res, { x1, x2, y, uid = "gv" }) {
  const L = MATERIAL_LOOK[targetId] || MATERIAL_LOOK.plastico;
  const R = rng(seedOf(`${uid}:${targetId}:${res.verdict}`));
  const length = x2 - x1;
  const sev = cl(res.sev || 0, 0, 1);
  const w = 1.2 + sev * 6.5;
  const lines = [], extras = [];
  const line = (attrs) => lines.push(h("line", { x1, y1: y, x2, y2: y, strokeLinecap: "round", strokeDasharray: length, ...attrs }));
  if (res.skin) {
    if (!res.scratched) return { lines, extras, length };
    const red = sev > 0.8 ? "#8E1B22" : "#C33A3A";
    line({ stroke: "#E0707A", strokeOpacity: 0.35, strokeWidth: 3 + sev * 5 });            // enrojecimiento
    if (res.bleeds) {
      line({ stroke: red, strokeOpacity: 0.85, strokeWidth: 0.8 + sev * 2.2 });
      if (res.layer && /grasa/i.test(res.layer)) line({ stroke: "#F1D27A", strokeOpacity: 0.7, strokeWidth: 0.6 });   // asoma la grasa
      for (let i = 0; i < Math.round(2 + sev * 9); i++) extras.push(h("circle", { cx: x1 + R() * length, cy: y + (R() - 0.3) * 2.5, r: 0.5 + R() * sev * 1.6, fill: "#A31F29", fillOpacity: 0.75 }));
      if (res.tearing) {   // desgarro: colgajos de piel levantados a los dos lados de la herida
        for (let i = 0; i < 6 + Math.round(sev * 10); i++) {
          const cx = x1 + R() * length, side = R() > 0.5 ? 1 : -1, s = 1.2 + R() * (1.6 + sev * 2.5), y0 = y + side * (1 + sev * 1.5);
          // epidermis levantada (más clara) con el borde en carne viva
          extras.push(h("polygon", { points: pts([[cx, y0], [cx + s * 1.4, y0 + side * s * 0.95], [cx + s * 2.6, y0]]), fill: "#FCE6DC", fillOpacity: 0.97, stroke: "#8E1B22", strokeOpacity: 0.85, strokeWidth: 0.45 }));
        }
      }
    } else if (res.depthUm > 0) {
      // sin sangre: raya blanca (capa córnea levantada) o línea en carne viva (epidermis excoriada)
      line({ stroke: res.depthUm <= 20 ? "#FFFFFF" : "#F7C9BF", strokeOpacity: 0.9, strokeWidth: res.depthUm <= 20 ? 0.7 : 1.3 });
    }
    return { lines, extras, length };
  }
  if (!res.scratched) {
    // Roce sin marca: solo un pulido tenue
    line({ stroke: "#FFFFFF", strokeOpacity: res.depthUm > 0.01 ? 0.18 : 0.08, strokeWidth: 1.4 });
    return { lines, extras, length };
  }
  const brittle = BRITTLE.has(L.kind), metal = METALLIC.has(L.kind);
  const car = carOf(targetId);
  const inner = car ? paintGrooveColor(res.depthUm, targetId)
    : L.kind === "wood" ? (L.lacquer && res.layer && String(res.layer).startsWith("laca") ? "#F3E2BD" : "#F0D39E")
      : metal ? lighten(L.base, 0.55)
        : brittle ? "#FFFFFF"
          : L.kind === "plastic" ? lighten(L.base, 0.45) : lighten(L.base, 0.35);
  line({ stroke: "#000000", strokeOpacity: 0.35, strokeWidth: w + 1.4 });                  // sombra del surco
  line({ stroke: inner, strokeOpacity: brittle ? 0.85 : 0.95, strokeWidth: brittle ? Math.max(0.8, w * 0.45) : w });
  line({ stroke: "#FFFFFF", strokeOpacity: metal ? 0.6 : 0.3, strokeWidth: 0.7, y1: y - w / 2, y2: y - w / 2 }); // labio iluminado
  if (brittle) {
    for (let i = 0; i < 6 + Math.round(sev * 14); i++) {
      const cx = x1 + R() * length, up = R() > 0.5 ? -1 : 1, s = 0.8 + R() * (1 + sev * 3);
      extras.push(h("polygon", { points: pts([[cx, y], [cx + s, y + up * s * 0.9], [cx + s * 1.8, y]]), fill: "#FFFFFF", fillOpacity: 0.5 + R() * 0.4 }));
      if (R() > 0.6) extras.push(h("line", { x1: cx, y1: y, x2: cx + (R() - 0.5) * 8, y2: y + up * (2 + R() * 5), stroke: "#FFFFFF", strokeOpacity: 0.45, strokeWidth: 0.35 }));
    }
  } else if (L.kind === "wood") {
    for (let i = 0; i < 4 + Math.round(sev * 10); i++) { const cx = x1 + R() * length; extras.push(h("line", { x1: cx, y1: y + (R() - 0.5) * w, x2: cx + 3 + R() * 5, y2: y + (R() - 0.5) * (w + 3), stroke: "#F5DEB0", strokeOpacity: 0.8, strokeWidth: 0.5 })); }
  } else if (metal) {
    line({ stroke: darken(L.lo, 0.35), strokeOpacity: 0.5, strokeWidth: 0.6, y1: y + w / 2, y2: y + w / 2 });   // rebaba
  }
  // Desgarro: la garra enganchada arranca material a los lados del surco. Los frágiles no se desgarran:
  // se astillan (ya dibujado arriba).
  if (res.tearing && !brittle) {
    const flap = L.kind === "wood" ? "#F5DEB0" : car ? lighten(L.base, 0.15) : metal ? lighten(L.base, 0.6)
      : L.kind === "plastic" ? "#EEF1F4" : lighten(L.base, 0.45);
    for (let i = 0; i < 8 + Math.round(sev * 16); i++) {
      const cx = x1 + R() * length, side = R() > 0.5 ? 1 : -1, s = 1 + R() * (1.5 + sev * 3), y0 = y + side * w * 0.5;
      extras.push(h("polygon", { points: pts([[cx, y0], [cx + s * 1.5, y0 + side * s * (0.7 + R() * 0.7)], [cx + s * 2.6, y0 + side * 0.2]]), fill: flap, fillOpacity: 0.9, stroke: "#000000", strokeOpacity: 0.3, strokeWidth: 0.3 }));
      if (L.kind === "wood" && R() > 0.35) {   // fibras largas arrancadas
        const l = 4 + R() * (5 + sev * 6);
        extras.push(h("line", { x1: cx + s, y1: y0, x2: cx + s + l * 0.9, y2: y0 + side * l * 0.45, stroke: "#F5DEB0", strokeOpacity: 0.85, strokeWidth: 0.45 }));
      }
      if (car && R() > 0.5) {  // escamas de pintura saltadas, con la imprimación debajo
        extras.push(h("ellipse", { cx: cx + s, cy: y0 + side * (s + 1.5), rx: 0.9 + R() * 1.4, ry: 0.5 + R() * 0.8, fill: paintGrooveColor(85, targetId), fillOpacity: 0.85 }));
      }
    }
    line({ stroke: "#000000", strokeOpacity: 0.25, strokeWidth: 0.5, y1: y - w * 0.5, y2: y - w * 0.5 });  // borde irregular en sombra
  }
  // Chapa rajada de lado a lado: se ve el hueco oscuro y los bordes doblados hacia dentro
  if (res.through && !res.puncture) {
    const edge = car && !car.body.metal ? "#8A9098" : lighten(car ? car.body.col : L.base, 0.5);
    line({ stroke: "#06080B", strokeOpacity: 0.92, strokeWidth: Math.max(1.2, w * 0.5) });
    for (let i = 0; i < 12 + Math.round(sev * 10); i++) {
      const cx = x1 + R() * length, side = R() > 0.5 ? 1 : -1, l = 1.5 + R() * 3;
      extras.push(h("line", { x1: cx, y1: y + side * w * 0.28, x2: cx + l, y2: y + side * (w * 0.28 + 0.8 + R() * 1.6), stroke: edge, strokeOpacity: 0.85, strokeWidth: 0.55 }));
    }
  }
  if (res.shattered) extras.push(...crackArt((x1 + x2) / 2, y, R));   // la carga partió la hoja de vidrio
  return { lines, extras, length };
}

/** Hoja de vidrio rota alrededor de (cx, cy): grietas radiales, anillos concéntricos y el hueco del impacto.
 *  En perspectiva (la losa se ve de canto), así que lo vertical se aplasta ×0,3 y nunca se sale de la cara. */
function crackArt(cx, cy, R) {
  const out = [], nRad = 9 + Math.round(R() * 4);
  for (let i = 0; i < nRad; i++) {
    const a = (i / nRad) * Math.PI * 2 + (R() - 0.5) * 0.5, sa = Math.abs(Math.sin(a) * 0.3);
    const len = (0.45 + R() * 0.55) * (sa > 0.01 ? Math.min(150, 15 / sa) : 150);
    const path = [[cx, cy]];
    for (let j = 1; j <= 6; j++) {
      const f = j / 6, jit = (R() - 0.5) * 4;
      path.push([cx + Math.cos(a) * len * f - Math.sin(a) * jit, cy + (Math.sin(a) * len * f + Math.cos(a) * jit) * 0.3]);
    }
    out.push(h("path", { d: poly(path, false), stroke: "#FFFFFF", strokeOpacity: 0.75, strokeWidth: 0.55, fill: "none" }));
  }
  for (const rr of [9, 20]) {
    const ring = [];
    for (let j = 0; j < 16; j++) { const a = (j / 16) * Math.PI * 2, r = rr * (0.85 + R() * 0.3); ring.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r * 0.3]); }
    out.push(h("path", { d: poly(ring, true), stroke: "#FFFFFF", strokeOpacity: 0.5, strokeWidth: 0.45, fill: "none" }));
  }
  out.push(h("polygon", { points: pts([[cx - 3, cy - 0.6], [cx - 0.5, cy - 1.6], [cx + 3.2, cy - 0.4], [cx + 1, cy + 1.5], [cx - 2.4, cy + 1]]), fill: "#0A1418", fillOpacity: 0.8 }));
  return out;
}

/** Hoja de vidrio partida vista en corte (perfil de la huella), en el rectángulo x, y, w × H. Al flexar,
 *  la cara de atrás trabaja a tracción: las grietas nacen ahí, bajo la carga, y cruzan todo el espesor;
 *  en el centro salta un trozo. Determinista: la misma semilla da el mismo dibujo. */
export function paneFractureArt({ x, y, w, h: H, seed = "pane" }) {
  const R = rng(seedOf(seed)), out = [], cx = x + w / 2, n = 7;
  for (let i = 0; i < n; i++) {
    const k = i - (n - 1) / 2, x0 = cx + k * (w / 10) + (R() - 0.5) * 6;
    const path = [[x0, y + H]];
    for (let j = 1; j <= 5; j++) path.push([x0 + k * j * 0.9 + (R() - 0.5) * 6, y + H - (H * j) / 5]);
    out.push(h("path", { d: poly(path, false), stroke: "#FFFFFF", strokeOpacity: 0.8, strokeWidth: 0.7, fill: "none" }));
  }
  out.push(h("polygon", { points: pts([[cx - 8, y + H], [cx - 3, y + H * 0.55], [cx + 4, y + H * 0.62], [cx + 9, y + H]]), fill: "#0A1418", fillOpacity: 0.55 }));
  return out;
}

/* ════════ CORTE DEL COCHE POR CAPAS ════════
   Lienzo 300 × 164: las cuatro capas de pintura (110 µm) ampliadas arriba, la carrocería de verdad debajo
   (0,7-2,5 mm) y, al fondo, el hueco de dentro de la puerta: ahí se ve si la punta se quedó en la pintura,
   se clavó en la chapa, la perforó o la atravesó entera. Dentro de cada zona la escala es lineal. */
export const CAR_SECTION = { w: 300, h: 164 };
export function carSectionArt(res, target, { uid = "car" } = {}) {
  const x = 8, w = 150, top = 6, cx = x + w * 0.42;
  const paintUm = PAINT_LAYERS.at(-1).to, body = target.body, L = carLayers(target);
  const yPaint = top + 64, yBody = yPaint + 56, bottom = yBody + 30;
  const yOf = (um) => {
    if (um <= paintUm) return top + (cl(um, 0, paintUm) / paintUm) * (yPaint - top);
    if (um <= paintUm + body.t) return yPaint + ((um - paintUm) / body.t) * (yBody - yPaint);
    const pastMm = (um - paintUm - body.t) / 1000;
    return yBody + (bottom - yBody - 2) * (pastMm / (pastMm + 8));      // detrás de la chapa: escala que se satura
  };
  const defs = [], out = [], labels = [];
  for (const l of L) {
    const isBody = l.id === "carroceria", y0 = yOf(l.from), y1 = isBody ? yBody : yOf(l.to);
    const a = surfaceArt(isBody ? BODY_LOOK[body.id] : PAINT_LAYER_LOOK[l.id], { x, y: y0, w, h: y1 - y0, uid: `${uid}-${l.id}`, detail: 0.8 });
    defs.push(...a.defs); out.push(...a.body);
    if (y0 > top) out.push(h("line", { x1: x, y1: y0, x2: x + w, y2: y0, stroke: "#000000", strokeOpacity: 0.25, strokeWidth: 0.5 }));
    const t = l.to - l.from;
    labels.push({ x: 166, y: (y0 + y1) / 2 + 3, text: `${l.name} · ${t >= 1000 ? `${(t / 1000).toFixed(1).replace(".", ",")} mm` : `${t} µm`}`, size: 8, color: isBody ? C.text : C.dim, bold: isBody });
  }
  out.push(h("rect", { x, y: yBody, width: w, height: bottom - yBody, fill: "#0B0E12" }));        // el hueco de la puerta
  labels.push({ x: 166, y: yBody + 17, text: "detrás: hueco de la puerta", size: 8, color: C.dimmer });
  out.push(h("rect", { x, y: top, width: w, height: yBody - top, fill: "none", stroke: C.line2, strokeWidth: 1 }));
  const d = res ? res.depthUm : 0;
  if (res && d > 0 && res.scratched) {
    const dy = yOf(d), cut = "#101418";
    const hw = res.through ? cl(1.5 + (res.grooveWidthUm || 0) / 1000 * 0.9, 2.5, 22) : cl(1.6 + Math.sqrt(res.grooveWidthUm || 0) / 6, 1.6, 12);
    if (res.puncture) out.push(h("polygon", { points: pts([[cx - hw, top], [cx + hw, top], [cx, dy]]), fill: cut, fillOpacity: 0.95, stroke: "#000000", strokeOpacity: 0.4, strokeWidth: 0.5 }));
    else out.push(h("path", { d: `M${r2(cx - hw)} ${top} Q${r2(cx - hw * 0.25)} ${top + 0.5} ${r2(cx)} ${r2(dy)} Q${r2(cx + hw * 0.25)} ${top + 0.5} ${r2(cx + hw)} ${top} Z`, fill: cut, fillOpacity: 0.95, stroke: "#000000", strokeOpacity: 0.35, strokeWidth: 0.5 }));
    if (res.through) {
      // pétalos (o bordes de la raja) doblados hacia dentro, por debajo de la chapa
      const petal = body.metal ? lighten(body.col, 0.25) : "#6A7078", ew = Math.min(hw, 10);
      for (const side of [-1, 1]) {
        const xe = cx + side * ew * 0.55;
        out.push(h("polygon", { points: pts([[xe, yBody], [xe + side * 4, yBody], [xe + side * 1.2, yBody + 7 + ew * 0.3]]), fill: petal, fillOpacity: 0.95, stroke: "#000000", strokeOpacity: 0.4, strokeWidth: 0.4 }));
      }
    }
    out.push(h("line", { x1: x, y1: r2(dy), x2: x + w, y2: r2(dy), stroke: res.vcol, strokeWidth: 1, strokeDasharray: "3 2" }));
    const hole = res.through ? ` · Ø ${fmtDepth(res.grooveWidthUm || 0)}` : "";
    // el rótulo no invade la columna de nombres de capa (x ≥ 166)
    const txt = `≈ ${fmtDepth(d)}${hole}`, tw = txt.length * 5.2 + 6, tx = Math.min(cx + 10, x + w + 2 - tw), ty = cl(dy + 3, top + 8, bottom - 2);
    out.push(h("rect", { x: tx - 3, y: ty - 8, width: tw, height: 11, rx: 3, fill: C.bg, fillOpacity: 0.8 }));
    labels.push({ x: tx, y: ty, text: txt, size: 8.5, color: res.vcol, bold: true });
  }
  return { defs, body: out, labels };
}

/* ════════ CORTE DE LA PIEL POR CAPAS ════════
   Lienzo 300 × 164: bloque de tejido (x 8-158) con una banda por capa de SKIN_LAYERS, alturas fijas para
   que se vean también las finas, y la herida hasta la profundidad del resultado. Dentro de cada banda la
   escala es lineal. Los rótulos se devuelven como datos (labels): cada app los escribe con su tipografía. */
const SKIN_BAND = { cornea: 9, epidermis: 12, dermis: 34, grasa: 40, fascia: 8, musculo: 49 };
export const SKIN_SECTION = { w: 300, h: 164 };
export function skinSectionArt(res, { uid = "sk" } = {}) {
  const x = 8, w = 150, top = 6, cx = x + w * 0.42;
  let y = top;
  const bands = SKIN_LAYERS.map((l) => { const hh = SKIN_BAND[l.id] || 20, b = { l, y0: y, y1: y + hh }; y += hh; return b; });
  const bottom = y;
  const yOf = (um) => { const b = bands.find((k) => um <= k.l.to) || bands[bands.length - 1]; return b.y0 + cl((um - b.l.from) / (b.l.to - b.l.from), 0, 1) * (b.y1 - b.y0); };
  const defs = [], body = [], labels = [];
  for (const b of bands) {
    const a = surfaceArt(SKIN_LAYER_LOOK[b.l.id], { x, y: b.y0, w, h: b.y1 - b.y0, uid: `${uid}-${b.l.id}`, detail: 0.8 });
    defs.push(...a.defs); body.push(...a.body);
    if (b.y0 > top) body.push(h("line", { x1: x, y1: b.y0, x2: x + w, y2: b.y0, stroke: "#000000", strokeOpacity: 0.2, strokeWidth: 0.5 }));
    const t = b.l.to - b.l.from;
    const thick = b.l.id === "musculo" ? "" : t >= 1000 ? ` · ${(t / 1000).toFixed(1).replace(".", ",")} mm` : ` · ${t} µm`;
    labels.push({ x: 166, y: (b.y0 + b.y1) / 2 + 3, text: `${b.l.short || b.l.name}${thick}`, size: 8, color: C.dim });
  }
  body.push(h("rect", { x, y: top, width: w, height: bottom - top, fill: "none", stroke: C.line2, strokeWidth: 1 }));
  const d = res ? res.depthUm : 0;
  if (res && d > 0) {
    const dy = yOf(d), wound = res.bleeds ? "#7E1520" : "#FBF1E8";
    if (res.puncture) {
      const hw = cl(1.6 + Math.sqrt(res.grooveWidthUm || 0) / 9, 1.6, 7);
      body.push(h("polygon", { points: pts([[cx - hw, top], [cx + hw, top], [cx, dy]]), fill: wound, fillOpacity: 0.95, stroke: "#000000", strokeOpacity: 0.35, strokeWidth: 0.5 }));
      if (res.inject) body.push(h("ellipse", { cx, cy: dy - 1, rx: 3.2, ry: 2.2, fill: "#E3D466", fillOpacity: 0.9 }));
    } else {
      const hw = cl(2 + Math.sqrt(res.grooveWidthUm || 0) / 4, 2.5, 26);
      const notch = `M${r2(cx - hw)} ${top} Q${r2(cx - hw * 0.25)} ${top + 0.5} ${r2(cx)} ${r2(dy)} Q${r2(cx + hw * 0.25)} ${top + 0.5} ${r2(cx + hw)} ${top} Z`;
      body.push(h("path", { d: notch, fill: wound, fillOpacity: 0.95, stroke: "#000000", strokeOpacity: 0.3, strokeWidth: 0.5 }));
      if (res.tearing) {   // bordes desgarrados: fibras arrancadas
        const R = rng(seedOf(`${uid}:tear`));
        for (let k = 0; k < 10; k++) {
          const f = (k + 0.5) / 10, yy = top + (dy - top) * f, side = k % 2 ? 1 : -1, xx = cx + side * hw * (1 - f) * 0.8;
          body.push(h("line", { x1: r2(xx), y1: r2(yy), x2: r2(xx + side * (2 + R() * 3)), y2: r2(yy - 1 - R() * 2), stroke: "#FFFFFF", strokeOpacity: 0.7, strokeWidth: 0.5 }));
        }
      }
    }
    if (res.bleeds) for (let k = 0; k < 3; k++) body.push(h("circle", { cx: r2(cx - 6 + k * 6), cy: top - 1.2 + (k % 2) * 0.6, r: 1.4 - (k % 2) * 0.4, fill: "#A31F29" }));
    body.push(h("line", { x1: x, y1: r2(dy), x2: x + w, y2: r2(dy), stroke: res.vcol, strokeWidth: 1, strokeDasharray: "3 2" }));
    const txt = `≈ ${fmtDepth(d)}`, tw = txt.length * 5.2 + 6, tx = cx + 10, ty = cl(dy + 3, top + 8, bottom - 2);
    body.push(h("rect", { x: tx - 3, y: ty - 8, width: tw, height: 11, rx: 3, fill: C.bg, fillOpacity: 0.78 }));
    labels.push({ x: tx, y: ty, text: txt, size: 8.5, color: res.vcol, bold: true });
  }
  return { defs, body, labels };
}

/** Marca de punción en (cx, cy) sobre la cara superior. `fangs` = dos punciones (mordedura). */
export function punctureArt(targetId, res, { cx, cy, uid = "pc", fangs = false }) {
  const L = MATERIAL_LOOK[targetId] || MATERIAL_LOOK.plastico;
  const R = rng(seedOf(`${uid}:${targetId}:${res.verdict}`));
  const sev = cl(res.sev || 0, 0, 1);
  const out = [], defs = [];
  const at = fangs ? [cx - 5, cx + 5] : [cx];
  if (res.skin) {
    for (const x of at) {
      if (!res.pierces) { out.push(h("ellipse", { cx: x, cy, rx: 3.5, ry: 1.4, fill: "#C9777A", fillOpacity: 0.35 })); continue; }
      out.push(h("ellipse", { cx: x, cy, rx: 3.6, ry: 1.6, fill: "#E0707A", fillOpacity: 0.4 }));
      out.push(h("ellipse", { cx: x, cy, rx: 1.3 + sev, ry: 0.7 + sev * 0.4, fill: "#7A1016" }));
      out.push(h("circle", { cx: x + 0.6, cy: cy + 1.6, r: 0.8, fill: res.inject ? "#D8C95A" : "#A31F29", fillOpacity: 0.85 }));
    }
    return { defs, body: out };
  }
  const id = `${uid}-${targetId}-hole`;
  if (res.shattered) return { defs, body: crackArt(cx, cy, R) };      // la hoja se ha partido entera
  const car = carOf(targetId);
  if (res.through && (car || targetId === "puertametal")) {
    // Chapa perforada: agujero con 4-6 pétalos doblados hacia dentro (Wierzbicki 1999). Detrás de la
    // puerta de un coche está oscuro; por la de casa entra la luz del otro lado.
    const holeMm = (res.grooveWidthUm || 0) / 1000;
    const hx = cl(1.8 + holeMm * 0.55, 2.2, 12), hy = hx * 0.42;
    const petal = car && !car.body.metal ? "#5A6068" : lighten(car ? car.body.col : L.base, 0.3);
    defs.push(rad(id, [[0, car ? "#040608" : "#FFF3C4", car ? 1 : 0.95], [0.75, "#000000", 0.75], [1, "#000000", 0.3]]));
    if (car) out.push(h("ellipse", { cx, cy, rx: hx * 1.7, ry: hy * 1.7, fill: paintGrooveColor(PAINT_LAYERS.at(-1).to + 5, targetId), fillOpacity: 0.9 }));
    out.push(h("ellipse", { cx, cy, rx: hx, ry: hy, fill: `url(#${id})` }));
    const nP = 4 + Math.floor(R() * 3);
    for (let i = 0; i < nP; i++) {
      const a = (i / nP) * Math.PI * 2 + R() * 0.5, da = (Math.PI / nP) * 0.85;
      const p1 = [cx + Math.cos(a - da) * hx, cy + Math.sin(a - da) * hy], p2 = [cx + Math.cos(a + da) * hx, cy + Math.sin(a + da) * hy];
      const tip = [cx + Math.cos(a) * hx * 0.3, cy + Math.sin(a) * hy * 0.3 + hy * 0.55];
      out.push(h("polygon", { points: pts([p1, tip, p2]), fill: petal, fillOpacity: 0.92, stroke: darken(petal, 0.45), strokeOpacity: 0.7, strokeWidth: 0.35 }));
    }
    return { defs, body: out };
  }
  const rx = res.through ? 9 : 1.2 + sev * 5.5, ry = rx * 0.42;
  if (!res.scratched && !res.toolBroken) {
    out.push(h("ellipse", { cx, cy, rx: 3, ry: 1.2, fill: "#000000", fillOpacity: 0.18 }));
    return { defs, body: out };
  }
  defs.push(rad(id, [[0, res.through ? "#FFF3C4" : "#000000", res.through ? 0.95 : 0.85], [0.7, "#000000", 0.6], [1, "#000000", 0.15]]));
  if (BRITTLE.has(L.kind)) {
    for (let i = 0; i < 5 + Math.round(sev * 5); i++) { const a = R() * Math.PI * 2, l = 3 + R() * (5 + sev * 8); out.push(h("line", { x1: cx, y1: cy, x2: cx + Math.cos(a) * l, y2: cy + Math.sin(a) * l * 0.45, stroke: "#FFFFFF", strokeOpacity: 0.6, strokeWidth: 0.4 })); }
    out.push(h("ellipse", { cx, cy, rx: rx * 1.9, ry: ry * 1.9, stroke: "#FFFFFF", strokeOpacity: 0.35, strokeWidth: 0.4, fill: "none" }));
  }
  if (L.kind === "wood") for (let i = 0; i < 6 + Math.round(sev * 8); i++) { const a = R() * Math.PI * 2, l = rx + 1 + R() * (3 + sev * 4); out.push(h("line", { x1: cx + Math.cos(a) * rx * 0.8, y1: cy + Math.sin(a) * ry * 0.8, x2: cx + Math.cos(a) * l, y2: cy + Math.sin(a) * l * 0.45, stroke: "#F0D39E", strokeOpacity: 0.85, strokeWidth: 0.6 })); }
  if (METALLIC.has(L.kind)) out.push(h("ellipse", { cx, cy, rx: rx + 1.2, ry: ry + 0.6, fill: lighten(L.base, 0.5), fillOpacity: 0.7 }));
  out.push(h("ellipse", { cx, cy, rx, ry, fill: `url(#${id})` }));
  if (car) out.push(h("ellipse", { cx, cy: cy + ry * 0.2, rx: rx * 0.5, ry: ry * 0.45, fill: paintGrooveColor(res.depthUm, targetId), fillOpacity: 0.9 }));
  return { defs, body: out };
}

/* ════════ GEMAS Y TACHUELAS ════════ */
const METAL_INLAYS = new Set(["oro", "acero", "titanio", "tungsteno", "hematites"]);
export function gemArt(inlay, cx, cy, r, uid = "gem") {
  const id = `${uid}-${inlay.id}`, col = inlay.col;
  if (METAL_INLAYS.has(inlay.id)) {
    return {
      defs: [rad(`${id}-m`, [[0, lighten(col, 0.7)], [0.45, col], [1, darken(col, 0.5)]], { cx: 0.35, cy: 0.3, r: 0.75 })],
      body: [
        h("circle", { cx, cy, r, fill: `url(#${id}-m)`, stroke: darken(col, 0.45), strokeWidth: Math.max(0.3, r * 0.08) }),
        h("ellipse", { cx: cx - r * 0.3, cy: cy - r * 0.35, rx: r * 0.35, ry: r * 0.2, fill: "#FFFFFF", fillOpacity: 0.7 }),
      ],
    };
  }
  const dark = col === "#FFFFFF" ? "#8FA9CC" : darken(col, 0.35);
  const out = [], G = [], T = [];
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2 + Math.PI / 8;
    G.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    T.push([cx + Math.cos(a) * r * 0.55, cy + Math.sin(a) * r * 0.55]);
  }
  for (let i = 0; i < 8; i++) {
    const j = (i + 1) % 8;
    out.push(h("polygon", { points: pts([G[i], G[j], T[j], T[i]]), fill: i % 2 ? lighten(col, 0.25) : mix(col, dark, 0.55), stroke: "#FFFFFF", strokeOpacity: 0.55, strokeWidth: Math.max(0.2, r * 0.04) }));
  }
  out.push(h("polygon", { points: pts(T), fill: lighten(col, 0.4), stroke: "#FFFFFF", strokeOpacity: 0.7, strokeWidth: Math.max(0.2, r * 0.04) }));
  out.push(h("path", { d: sparkle(cx + r * 0.25, cy - r * 0.3, r * 0.55), fill: "#FFFFFF", fillOpacity: 0.95 }));
  return { defs: [], body: out };
}

/* ════════ UÑA (vista frontal, viewBox 0 0 100 168) ════════ */
const NAIL_LOOK = {
  natural: { bed: ["#F4BFC5", "#E8A1AB"], edge: "#FBF2E8", edgeOp: 0.92, lunula: true, ridges: true },
  gel: { bed: ["#E4588E", "#A8235A"], edge: "#D9477F", edgeOp: 1, gloss: 0.7 },
  acrilico: { bed: ["#F3CDCB", "#E2AEAB"], edge: "#F6DAD6", edgeOp: 1, gloss: 0.55 },
  // experimentos: uñas macizas
  metal: { bed: ["#E4E9EE", "#8D97A2"], edge: "#C9D0D8", edgeOp: 1, gloss: 0.8, brushed: true },
  titanio: { bed: ["#B9B3D6", "#6F7E9C"], edge: "#A8A6C8", edgeOp: 1, gloss: 0.65, brushed: true },
  zafiro: { bed: ["#8EC2F4", "#2A5AA8"], edge: "#6FA6E6", edgeOp: 0.9, gloss: 0.9, facets: true },
  diamante: { bed: ["#FFFFFF", "#C9D9EE"], edge: "#EEF5FF", edgeOp: 0.9, gloss: 0.95, facets: true, sparkles: true },
};
/** Colores de la placa de cada material de uña (muestras de color de la interfaz). */
export const nailSwatch = (baseId) => (NAIL_LOOK[baseId] || NAIL_LOOK.natural).bed;
export function nailArt({ geom, base, inlay, wet = false, uid = "nail" }) {
  const N = NAIL_LOOK[base.id] || NAIL_LOOK.natural;
  const id = `${uid}-${geom.id}-${base.id}`;
  const tipY = 84; // punta del dedo (hiponiquio): por encima empieza el borde libre
  const defs = [
    lin(`${id}-skin`, [[0, "#C9876E"], [0.22, "#EDB9A0"], [0.55, "#F3C7B0"], [1, "#C07A62"]], { x1: 0, y1: 0, x2: 1, y2: 0 }),
    lin(`${id}-bed`, [[0, N.bed[0]], [1, N.bed[1]]]),
    lin(`${id}-gl`, [[0, "#FFFFFF", N.gloss ?? 0.5], [1, "#FFFFFF", 0]]),
    h("clipPath", { id: `${id}-nc` }, h("path", { d: geom.path })),
  ];
  // curvatura en C: la placa es un tubo abierto (bordes en sombra, centro iluminado)
  defs.push(lin(`${id}-cc`, [[0, "#000000", 0.28], [0.18, "#000000", 0.06], [0.42, "#FFFFFF", 0.08], [0.62, "#000000", 0], [1, "#000000", 0.3]], { x1: 0, y1: 0, x2: 1, y2: 0 }));
  const R = rng(seedOf(id));
  const body = [
    // dedo con sombreado cilíndrico y pliegues
    h("path", { d: "M22 168 L22 104 Q22 78 50 76 Q78 78 78 104 L78 168 Z", fill: `url(#${id}-skin)` }),
    h("path", { d: "M30 158 Q50 152 70 158", stroke: "#A8664F", strokeOpacity: 0.35, strokeWidth: 0.8, fill: "none" }),
    h("path", { d: "M34 163 Q50 158 66 163", stroke: "#A8664F", strokeOpacity: 0.25, strokeWidth: 0.7, fill: "none" }),
    // placa de la uña (recortada a la forma)
    h("g", { clipPath: `url(#${id}-nc)` }, [
      h("rect", { x: 0, y: 0, width: 100, height: 168, fill: `url(#${id}-bed)` }),
      h("path", { d: `M0 0 L100 0 L100 ${tipY + 2} Q50 ${tipY - 8} 0 ${tipY + 2} Z`, fill: N.edge, fillOpacity: N.edgeOp }),
      N.lunula && h("ellipse", { cx: 50, cy: 136, rx: 17, ry: 9, fill: "#FFF4F2", fillOpacity: 0.55 }),
      N.ridges && [36, 43, 50, 57, 64].map((x) => h("line", { key: x, x1: x, y1: 20, x2: x + 0.5, y2: 140, stroke: "#FFFFFF", strokeOpacity: 0.18, strokeWidth: 0.6 })),
      N.brushed && Array.from({ length: 40 }, (_, i) => { const yy = 4 + i * 3.6 + R() * 2; return h("line", { key: `b${i}`, x1: 20, y1: yy, x2: 80, y2: yy + (R() - 0.5), stroke: R() > 0.5 ? "#FFFFFF" : "#000000", strokeOpacity: 0.06 + R() * 0.1, strokeWidth: 0.5 }); }),
      N.facets && Array.from({ length: 16 }, (_, i) => { const cx = 28 + R() * 44, cy = 10 + R() * 130, sz = 5 + R() * 9; return h("polygon", { key: `f${i}`, points: pts([[cx, cy - sz], [cx + sz * 0.8, cy + sz * 0.5], [cx - sz * 0.7, cy + sz * 0.4]]), fill: R() > 0.5 ? "#FFFFFF" : darken(N.bed[1], 0.2), fillOpacity: 0.1 + R() * 0.2 }); }),
      h("rect", { x: 0, y: 0, width: 100, height: 168, fill: `url(#${id}-cc)` }),
      h("path", { d: "M34 150 L34 40 Q36 30 40 28 L42 150 Z", fill: `url(#${id}-gl)` }),
      h("ellipse", { cx: 40, cy: 48, rx: 2.4, ry: 5, fill: "#FFFFFF", fillOpacity: 0.55 }),
      N.sparkles && [[58, 40, 4], [44, 96, 3], [60, 118, 2.4]].map(([x, y, r], i) => h("path", { key: `s${i}`, d: sparkle(x, y, r), fill: "#FFFFFF", fillOpacity: 0.95 })),
    ]),
    h("path", { d: geom.path, fill: "none", stroke: darken(N.bed[1], 0.25), strokeOpacity: 0.55, strokeWidth: 0.9 }),
    // pliegue proximal (cutícula) que tapa la base de la uña
    h("path", { d: "M24 168 L24 140 Q50 126 76 140 L76 168 Z", fill: "#E7AE95" }),
    h("path", { d: "M26 140 Q50 127 74 140", stroke: "#C98770", strokeWidth: 1.1, fill: "none" }),
  ];
  if (inlay && inlay.id !== "none") {
    // pedrería decorativa en abanico junto a la cutícula (solo adorno: la que araña es la de la punta)
    const small = cl(Math.sqrt(inlay.area) * 5.5, 2.2, 3.8);
    for (const [gx, gy, f] of [[50, 118, 1], [41.5, 114, 0.8], [58.5, 114, 0.8], [35, 106, 0.62], [65, 106, 0.62], [50, 104, 0.7]]) {
      const g = gemArt(inlay, gx, gy, small * f, `${id}-p${gx}${gy}`);
      defs.push(...g.defs); body.push(...g.body);
    }
    const g = gemArt(inlay, 50, geom.ay + 10, cl(Math.sqrt(inlay.area) * 10, 3.4, 8), id);
    defs.push(...g.defs); body.push(...g.body);
  }
  if (wet) body.push(h("path", { d: geom.path, fill: "#9FD8FF", fillOpacity: 0.12 }), ...wetDrops(id, [[40, 70, 3.2], [60, 100, 2.4], [30, 124, 2.8], [66, 132, 2]]));
  return { defs, body };
}
function wetDrops(id, list) {
  return list.map(([x, y, r], i) => h("g", { key: `d${i}` }, [
    h("ellipse", { cx: x, cy: y, rx: r, ry: r * 1.15, fill: "#DDF3FF", fillOpacity: 0.45, stroke: "#FFFFFF", strokeOpacity: 0.7, strokeWidth: 0.4 }),
    h("ellipse", { cx: x - r * 0.3, cy: y - r * 0.4, rx: r * 0.3, ry: r * 0.22, fill: "#FFFFFF", fillOpacity: 0.9 }),
  ]));
}

/** Punta de dedo vista de lado, con la punta de la uña en (0, 0) y el dedo hacia arriba-izquierda (banco y ficha). */
export function nailSideArt({ geom = null, base, inlay, wet = false, uid = "nside" }) {
  const N = NAIL_LOOK[base.id] || NAIL_LOOK.natural;
  const id = `${uid}-${base.id}-${geom ? geom.id : "x"}`;
  // u: a lo largo del dedo hacia la punta · v: hacia el dorso. La uña ataca la superficie a 35°.
  // El borde libre y su curva de pinza dependen de la forma: la Stiletto XL es larga y se curva
  // hacia abajo como una garra.
  const th = (35 * Math.PI) / 180, c = Math.cos(th), sn = Math.sin(th);
  const free = geom ? 16 + geom.reach * 2.4 : 28, curl = geom ? geom.curl : 0.5;
  const u0 = -(free + 36);                                                          // cutícula
  const vBot = (u) => (u < -free ? 0.3 : 0.3 - (2 + 9 * curl) * ((u + free) / free) ** 2);
  const thick = (u) => (u < -free ? 3.3 : 3.3 - 2.1 * ((u + free) / free));
  const tipUV = [0, vBot(0) + thick(0) * 0.5];
  const P = (u, v) => [(u - tipUV[0]) * c + (v - tipUV[1]) * sn, (u - tipUV[0]) * sn - (v - tipUV[1]) * c];
  const shape = (list) => poly(list.map(([u, v]) => P(u, v)));
  const plate = (a, b) => {
    const top = [], bot = [];
    for (let i = 0; i <= 18; i++) { const u = a + ((b - a) * i) / 18; top.push([u, vBot(u) + thick(u)]); bot.push([u, vBot(u)]); }
    return shape([...top, ...bot.reverse()]);
  };
  const fc = -free - 1, tipArc = [];                                                // yema: centro del arco
  for (let a = 90; a >= -90; a -= 15) tipArc.push([fc + 11 * Math.cos((a * Math.PI) / 180), -10.5 + 10.8 * Math.sin((a * Math.PI) / 180)]);
  const back = u0 - 96;
  // El dedo se difumina hacia atrás (máscara), así entra en escena sin un corte seco en el banco.
  const [f0x, f0y] = P(back, -10), [f1x, f1y] = P(u0 - 28, -10);
  const defs = [
    lin(`${id}-sk`, [[0, "#F4CDB8"], [0.6, "#E9AF96"], [1, "#C4806A"]]),
    lin(`${id}-nl`, [[0, lighten(N.bed[0], 0.12)], [1, N.bed[1]]]),
    lin(`${id}-fg`, [[0, "#FFFFFF", 0], [1, "#FFFFFF", 1]], { user: true, x1: r2(f0x), y1: r2(f0y), x2: r2(f1x), y2: r2(f1y) }),
    h("mask", { id: `${id}-fade`, maskUnits: "userSpaceOnUse", x: -420, y: -320, width: 460, height: 360 },
      [h("rect", { x: -420, y: -320, width: 460, height: 360, fill: `url(#${id}-fg)` })]),
  ];
  const body = [
    h("path", { d: shape([[back, 0.3], ...tipArc, [back, -21.3]]), fill: `url(#${id}-sk)` }),
    h("path", { d: shape([[fc - 14, -21.2], [fc - 7, -20.8], [fc, -21.2]]), stroke: "#B8735B", strokeOpacity: 0.35, strokeWidth: 0.6, fill: "none" }),
    h("path", { d: plate(u0, 0), fill: `url(#${id}-nl)`, stroke: darken(N.bed[1], 0.25), strokeOpacity: 0.6, strokeWidth: 0.5 }),
    h("path", { d: plate(-free - 2, 0), fill: N.edge, fillOpacity: N.edgeOp }),
    h("path", { d: shape([[u0 + 4, 3.1], [-free, 3.2], [-free * 0.55, vBot(-free * 0.55) + thick(-free * 0.55) - 0.3], [-5, vBot(-5) + thick(-5) - 0.4]]), stroke: "#FFFFFF", strokeOpacity: 0.6, strokeWidth: 0.8, fill: "none" }),
    h("path", { d: shape([[back - 2, 0.2], [u0 - 4, -0.4], [u0 + 2, 1.6], [u0 + 3.5, 4.4], [u0 - 2, 6.6], [back - 2, 6]]), fill: "#E3A58C" }),
    h("path", { d: shape([[u0, 6.2], [u0 + 3.2, 4.4], [u0 + 2.4, 1.4]]), stroke: "#B8735B", strokeOpacity: 0.55, strokeWidth: 0.7, fill: "none" }),
  ];
  if (inlay && inlay.id !== "none") { const [gx, gy] = P(-5, vBot(-5) + thick(-5) + 1.2); const g = gemArt(inlay, gx, gy, 3.2, id); defs.push(...g.defs); body.push(...g.body); }
  if (wet) { const [x1, y1] = P(u0 + 22, 5.6), [x2, y2] = P(-free + 6, 4.4); body.push(...wetDrops(id, [[x1, y1, 2.2], [x2, y2, 1.6]])); }
  return { defs, body: [h("g", { mask: `url(#${id}-fade)` }, body)], tip: { x: 0, y: 0 } };
}

/* ════════ GARRAS, TALONES, ESPOLONES Y COLMILLOS (viewBox 0 0 100 132) ════════ */
// Rasgos visuales de cada animal (solo dibujo): base del dedo, pelaje, escamas o encía.
const CLAW_ART = {
  gato: { kind: "mammal", toe: "#CFB38E", fur: ["#EAD7B8", "#A98A64", "#6E5A45"], w0: 10, ivory: true },
  tigre: { kind: "mammal", toe: "#E39B45", fur: ["#F4BA68", "#C57A2D", "#221812"], stripes: true, w0: 12, ivory: true },
  oso: { kind: "mammal", toe: "#5C4433", fur: ["#80614A", "#4A3527", "#2A1F18"], w0: 15 },
  aguila: { kind: "raptor", toe: "#E2B73F", w0: 12.5 },
  arpia: { kind: "raptor", toe: "#E1B23B", w0: 13.5 },
  halcon: { kind: "raptor", toe: "#E8C44B", w0: 10.5 },
  buho: { kind: "owl", toe: "#CDB690", w0: 11 },
  lechuza: { kind: "owl", toe: "#EEE0C8", w0: 8.5 },
  buitre: { kind: "scaly", toe: "#908D88", w0: 13 },
  casuario: { kind: "scaly", toe: "#7F8FA6", w0: 12 },
  emu: { kind: "scaly", toe: "#71685D", w0: 12.5 },
  avestruz: { kind: "scaly", toe: "#C9A89A", w0: 17 },
  gallo: { kind: "scaly", toe: "#E3A74C", w0: 12 },
  guacamayo: { kind: "scaly", toe: "#908D8B", w0: 9 },
  pajaro: { kind: "scaly", toe: "#B59F88", w0: 7 },
  vibora: { kind: "fang", toe: "#EAA7AA", jaw: "#8E7B58", w0: 5.2 },
  gabon: { kind: "fang", toe: "#E9A2A6", jaw: "#B99D6D", w0: 6.2 },
};

/** Geometría de la garra: línea media en arco (curvatura) y grosor según afilado (área) y semiángulo α. */
function clawGeometry(claw, art) {
  const fang = art.kind === "fang";
  const theta = ((fang ? 55 + 45 * claw.curve : 35 + 115 * claw.curve) * Math.PI) / 180;
  const phi0 = -Math.PI / 2 - 0.15 * theta;
  const N = 40, Lm = 100, P = [], phi = [];
  let x = 0, y = 0;
  for (let i = 0; i <= N; i++) {
    const a = phi0 + (theta * i) / N;
    P.push([x, y]); phi.push(a);
    x += (Lm / N) * Math.cos(a); y += (Lm / N) * Math.sin(a);
  }
  const wTip = cl(Math.sqrt(claw.area) * 5, 0.35, 3.2);
  const taper = Math.tan((cl(claw.alpha, 10, 40) * Math.PI) / 180);
  const W = (s) => Math.max(wTip, Math.min(art.w0 * Math.pow(1 - s, 0.65), wTip + (1 - s) * Lm * taper));
  const dors = [], vent = [], ws = [];
  for (let i = 0; i <= N; i++) {
    const s = i / N, w = W(s), a = phi[i];
    const nx = -Math.sin(a), ny = Math.cos(a);        // normal hacia el centro de curvatura (cara ventral)
    ws.push(w);
    dors.push([P[i][0] - nx * w * 1.08, P[i][1] - ny * w * 1.08]);
    vent.push([P[i][0] + nx * w * 0.92, P[i][1] + ny * w * 0.92]);
  }
  const aT = phi[N];
  const tip = [P[N][0] + Math.cos(aT) * wTip, P[N][1] + Math.sin(aT) * wTip];
  return { P, phi, dors, vent, ws, tip, wTip, N };
}

/**
 * Garra o colmillo. orient "up": base abajo y punta arriba (ficha); "down": colgando, punta abajo
 * (colmillo en la ficha y herramienta del banco). Devuelve { defs, body, tip:{x,y}, tipAngle }.
 */
export function clawArt(claw, { inlay = null, uid = "claw", tipColor = null, orient, drop = false } = {}) {
  const art = CLAW_ART[claw.id] || { kind: "scaly", toe: "#999999", w0: 6 };
  const fang = art.kind === "fang";
  const o = orient || (fang ? "down" : "up");
  const g = clawGeometry(claw, art);
  // Ajuste al viewBox: escala uniforme para que la garra quepa entre y 10 y la base en y 112.
  const all = [...g.dors, ...g.vent, g.tip];
  const minX = Math.min(...all.map((p) => p[0])), maxX = Math.max(...all.map((p) => p[0]));
  const minY = Math.min(...all.map((p) => p[1])), maxY = Math.max(...all.map((p) => p[1]));
  const k = Math.min(80 / (maxX - minX), 96 / (maxY - minY));
  const ox = 50 - ((minX + maxX) / 2) * k, oy = 112 - maxY * k;
  let T = ([x, y]) => [ox + x * k, oy + y * k];
  if (o === "down") { const U = T; T = (p) => { const [x, y] = U(p); return [100 - x, 132 - y]; }; }
  const D = g.dors.map(T), V = g.vent.map(T), C = g.P.map(T), tip = T(g.tip), base = T([0, 0]);
  // Garra o colmillo "reforjados" en otro material: misma forma, pintados en ese material
  const forged = inlay && inlay.id !== "none" ? inlay : null;
  const id = `${uid}-${claw.id}${forged ? `-${forged.id}` : ""}`;
  const pale = !forged && (art.ivory || fang);
  const col = forged ? forged.col : claw.col;
  const light = forged ? lighten(col, 0.6) : art.ivory ? "#FBF3E6" : fang ? "#F5EEE2" : lighten(col, 0.28);
  const dark = forged ? darken(col, 0.45) : art.ivory ? "#D9C6AA" : fang ? "#E8DCC6" : darken(col, 0.35);
  const defs = [lin(`${id}-k`, [[0, light], [0.6, pale ? mix(light, dark, 0.5) : col], [1, pale ? "#FFFDF8" : dark]], { user: true, x1: base[0], y1: base[1], x2: tip[0], y2: tip[1] })];
  const outline = poly([...D, tip, ...V.slice().reverse()]);
  const body = [];
  // Base anatómica: lo de detrás se pinta antes que la garra y el mechón delantero, después
  const toe = toeArt(art, base, o, id, defs, k * art.w0, tip);
  body.push(...toe.back);
  // Garra: relleno, cara ventral en sombra, estrías de crecimiento y brillo dorsal
  body.push(h("path", { d: outline, fill: `url(#${id}-k)`, fillOpacity: pale ? 0.96 : 1, stroke: darken(pale ? dark : col, 0.35), strokeOpacity: 0.6, strokeWidth: 0.7 }));
  body.push(h("path", { d: poly([...C.slice(0, g.N), ...V.slice(0, g.N).reverse()]), fill: "#000000", fillOpacity: pale ? 0.1 : 0.22 }));
  for (const f of [-0.55, -0.15, 0.3]) {
    const line = g.P.slice(3, Math.round(g.N * 0.86)).map((p, i) => { const j = i + 3, a = g.phi[j]; return T([p[0] - Math.sin(a) * g.ws[j] * f, p[1] + Math.cos(a) * g.ws[j] * f]); });
    if (!forged) body.push(h("path", { d: poly(line, false), stroke: darken(pale ? dark : col, 0.3), strokeOpacity: 0.22, strokeWidth: 0.45, fill: "none" }));   // estrías: solo en queratina
  }
  const hl = g.P.slice(2, Math.round(g.N * 0.8)).map((p, i) => { const j = i + 2, a = g.phi[j]; return T([p[0] + Math.sin(a) * g.ws[j] * 0.6, p[1] - Math.cos(a) * g.ws[j] * 0.6]); });
  body.push(h("path", { d: poly(hl, false), stroke: "#FFFFFF", strokeOpacity: pale || forged ? 0.7 : 0.4, strokeWidth: forged ? 1.4 : 1.1, fill: "none", strokeLinecap: "round" }));
  if (fang) {
    // canal del veneno y orificio de salida cerca de la punta
    const canal = g.P.slice(4, Math.round(g.N * 0.9)).map((p, i) => { const j = i + 4, a = g.phi[j]; return T([p[0] - Math.sin(a) * g.ws[j] * 0.35, p[1] + Math.cos(a) * g.ws[j] * 0.35]); });
    body.push(h("path", { d: poly(canal, false), stroke: "#B8A58A", strokeOpacity: 0.6, strokeWidth: 0.6, fill: "none" }));
    const oe = canal[canal.length - 1];
    body.push(h("ellipse", { cx: oe[0], cy: oe[1], rx: 0.9, ry: 0.5, fill: "#8C7B63" }));
    if (drop) body.push(h("path", { d: `M${r2(tip[0])} ${r2(tip[1] + 0.5)} Q${r2(tip[0] + 2.4)} ${r2(tip[1] + 4)} ${r2(tip[0])} ${r2(tip[1] + 6)} Q${r2(tip[0] - 2.4)} ${r2(tip[1] + 4)} ${r2(tip[0])} ${r2(tip[1] + 0.5)} Z`, fill: "#E3D466", fillOpacity: 0.85 }));
  }
  body.push(...toe.front);
  // Material reforjado: las gemas (no los metales) brillan con destellos a lo largo de la garra
  if (forged && !METAL_INLAYS.has(forged.id)) {
    for (const f of [0.35, 0.7]) { const p = T(g.P[Math.round(g.N * f)]); body.push(h("path", { d: sparkle(p[0], p[1], 2.4 + 1.2 * f), fill: "#FFFFFF", fillOpacity: 0.85 })); }
  }
  // Punta: color de veredicto
  if (tipColor) {
    body.push(h("circle", { cx: tip[0], cy: tip[1], r: Math.max(1.6, g.wTip * k * 0.9), fill: tipColor, fillOpacity: 0.95 }));
  }
  const aT = g.phi[g.N];
  const tipAngle = o === "down" ? Math.atan2(-Math.sin(aT), -Math.cos(aT)) : aT;
  return { defs, body, tip: { x: tip[0], y: tip[1] }, tipAngle };
}

/** Dedo, pata o encía de la que sale la garra/colmillo. bw = semiancho de la base de la garra (viewBox). */
function toeArt(art, base, o, id, defs, bw, tip) {
  const [bx, by] = base, down = o === "down", dir = down ? -1 : 1;
  const back = [], front = [];
  const R = rng(seedOf(id));
  if (art.kind === "fang") {
    // Maxilar de víbora de perfil, boca abierta: el colmillo cuelga delante, bajo el hocico, y se curva
    // hacia la garganta. u: a lo largo de la cabeza (+ hacia el hocico) · t: alejándose del colmillo.
    const sx = tip && tip[0] > bx ? -1 : 1;
    const X = (u) => r2(bx + sx * u), Y = (t) => r2(by + dir * t);
    const head = `M${X(bw * 3.4)} ${Y(-0.6)} Q${X(bw * 4.3)} ${Y(9)} ${X(bw * 2.2)} ${Y(15)} Q${X(-18)} ${Y(23)} ${X(-100)} ${Y(25)} L${X(-100)} ${Y(-1.5)} Q${X(-30)} ${Y(-3.2)} ${X(bw * 3.4)} ${Y(-0.6)} Z`;
    defs.push(lin(`${id}-jaw`, [[0, lighten(art.jaw, 0.22)], [1, darken(art.jaw, 0.3)]], { user: true, x1: bx, y1: Y(0), x2: bx, y2: Y(25) }));
    defs.push(lin(`${id}-gum`, [[0, lighten(art.toe, 0.15)], [1, darken(art.toe, 0.2)]]));
    defs.push(h("clipPath", { id: `${id}-hc` }, h("path", { d: head })));
    defs.push(lin(`${id}-hf`, [[0, "#FFFFFF", 0], [1, "#FFFFFF", 1]], { user: true, x1: X(-100), y1: by, x2: X(-48), y2: by }));
    defs.push(h("mask", { id: `${id}-hm`, maskUnits: "userSpaceOnUse", x: -200, y: -200, width: 500, height: 540 },
      h("rect", { x: -200, y: -200, width: 500, height: 540, fill: `url(#${id}-hf)` })));
    const scales = [];
    for (let r = 0; r < 5; r++) for (let c = 0; c < 14; c++) {
      const u = bw * 3.2 - c * 8.5 - (r % 2) * 4.2, t = 3.5 + r * 5.2;
      scales.push(h("path", { d: `M${X(u - 4.4)} ${Y(t)} Q${X(u)} ${Y(t + 5.2)} ${X(u + 4.4)} ${Y(t)}`, stroke: darken(art.jaw, 0.4), strokeOpacity: 0.5, strokeWidth: 0.6, fill: lighten(art.jaw, 0.04 + R() * 0.1) }));
    }
    // labiales: fila de escamas claras a lo largo del borde de la boca
    for (let c = 0; c < 9; c++) {
      const u = bw * 2.6 - c * 9.5;
      scales.push(h("rect", { x: Math.min(X(u), X(u - 8)), y: Math.min(Y(-0.8), Y(3.4)), width: 8, height: 4.2, rx: 1.6, fill: lighten(art.jaw, 0.35), fillOpacity: 0.55, stroke: darken(art.jaw, 0.35), strokeOpacity: 0.4, strokeWidth: 0.5 }));
    }
    const eu = -16, et = 15;
    back.push(h("g", { mask: `url(#${id}-hm)` },
      h("path", { d: head, fill: `url(#${id}-jaw)` }),
      h("g", { clipPath: `url(#${id}-hc)` }, scales),
      // ojo con pupila vertical y escama supraocular
      h("path", { d: `M${X(eu - 7)} ${Y(et + 4.5)} Q${X(eu)} ${Y(et + 8.5)} ${X(eu + 7)} ${Y(et + 4.5)}`, stroke: darken(art.jaw, 0.5), strokeWidth: 1.2, fill: "none", strokeLinecap: "round" }),
      h("circle", { cx: X(eu), cy: Y(et), r: 4.4, fill: "#C99A3B", stroke: darken(art.jaw, 0.55), strokeWidth: 0.8 }),
      h("ellipse", { cx: X(eu), cy: Y(et), rx: 0.95, ry: 3.6, fill: "#15110C" }),
      h("circle", { cx: X(eu + 1.6), cy: Y(et + 1.6), r: 0.9, fill: "#FFFFFF", fillOpacity: 0.85 }),
      h("path", { d: head, fill: "none", stroke: darken(art.jaw, 0.45), strokeOpacity: 0.55, strokeWidth: 0.8 })));
    // vaina de encía de la que sale el colmillo
    back.push(h("ellipse", { cx: bx, cy: by + dir * 0.6, rx: bw * 2.1, ry: bw * 0.9 + 1.4, fill: `url(#${id}-gum)` }));
    front.push(h("path", { d: `M${r2(bx - bw * 1.9)} ${r2(by + 0.8 * dir)} Q${bx} ${r2(by + (1.2 + bw * 0.8) * dir)} ${r2(bx + bw * 1.9)} ${r2(by + 0.8 * dir)}`, stroke: darken(art.toe, 0.3), strokeOpacity: 0.5, strokeWidth: 0.8, fill: "none" }));
    return { back, front };
  }
  if (art.kind === "mammal" || art.kind === "owl") {
    // Dedo cubierto de pelo (o de plumas, en los búhos) del que asoma la garra. El pelo apunta hacia
    // la garra, las rayas del tigre cruzan el dedo y un mechón tapa la raíz. Se difumina hacia atrás.
    const owl = art.kind === "owl";
    const dw = bw * 1.95, len = 92, top = by - bw * 0.35 * dir;
    const Y = (t) => r2(top + dir * t);
    const hair = owl ? ["#FFFFFF", lighten(art.toe, 0.25), darken(art.toe, 0.2)] : art.fur;
    const digit = `M${r2(bx - dw)} ${Y(len)} L${r2(bx - dw)} ${Y(dw)} Q${r2(bx - dw)} ${Y(-dw * 0.35)} ${r2(bx)} ${Y(-dw * 0.35)} Q${r2(bx + dw)} ${Y(-dw * 0.35)} ${r2(bx + dw)} ${Y(dw)} L${r2(bx + dw)} ${Y(len)} Z`;
    defs.push(lin(`${id}-paw`, [[0, darken(art.toe, 0.3)], [0.38, lighten(art.toe, 0.12)], [0.7, art.toe], [1, darken(art.toe, 0.38)]], { x1: 0, y1: 0, x2: 1, y2: 0 }));
    defs.push(lin(`${id}-pf`, [[0, "#FFFFFF", 1], [1, "#FFFFFF", 0]], { user: true, x1: bx, y1: Y(len * 0.4), x2: bx, y2: Y(len * 0.9) }));
    defs.push(h("mask", { id: `${id}-pm`, maskUnits: "userSpaceOnUse", x: -200, y: -200, width: 500, height: 540 },
      h("rect", { x: -200, y: -200, width: 500, height: 540, fill: `url(#${id}-pf)` })));
    defs.push(h("clipPath", { id: `${id}-pc` }, h("path", { d: digit })));
    const fur = [h("path", { d: digit, fill: `url(#${id}-paw)` })];
    const inside = [];
    // pelo del dorso: trazos cortos a lo largo del dedo, apuntando hacia la garra
    for (let i = 0; i < 90; i++) {
      const t = R() * len * 0.85, x0 = bx + (R() * 2 - 1) * dw * 0.95, l = bw * (0.5 + R() * 0.6);
      const a = -dir * Math.PI / 2 + (x0 - bx) / dw * 0.35 + (R() - 0.5) * 0.4;
      inside.push(h("path", { d: `M${r2(x0)} ${Y(t)} l${r2(Math.cos(a) * l)} ${r2(Math.sin(a) * l)}`, stroke: hair[Math.floor(R() * 3)], strokeOpacity: 0.55, strokeWidth: owl ? 1.1 : 0.7, strokeLinecap: "round" }));
    }
    // rayas transversales del tigre, afiladas y alternando lado
    if (art.stripes) for (let i = 0; i < 4; i++) {
      const t = dw * (1.1 + i * 1.05), side = i % 2 ? 1 : -1, x0 = bx + side * dw * 1.05, x1 = bx - side * dw * (0.35 + 0.1 * i);
      inside.push(h("path", { d: `M${r2(x0)} ${Y(t)} Q${r2((x0 + x1) / 2)} ${Y(t - bw * 0.3)} ${r2(x1)} ${Y(t + bw * 0.12)} Q${r2((x0 + x1) / 2)} ${Y(t + bw * 0.3)} ${r2(x0)} ${Y(t + bw * 0.55)} Z`, fill: art.fur[2], fillOpacity: 0.75 }));
    }
    fur.push(h("g", { clipPath: `url(#${id}-pc)` }, inside));
    // pelo del contorno: sobresale del perfil hacia fuera y hacia la garra
    for (let i = 0; i < 70; i++) {
      const side = i % 2 ? 1 : -1, t = dw * 0.4 + R() * len * 0.8, l = bw * (0.45 + R() * 0.7) * (owl ? 1.3 : 1);
      const a = Math.atan2(-dir * 0.75, side * 0.65) + (R() - 0.5) * 0.5;
      fur.push(h("path", { d: `M${r2(bx + side * dw * (0.86 + R() * 0.1))} ${Y(t)} q${r2(Math.cos(a) * l * 0.5 + (R() - 0.5))} ${r2(Math.sin(a) * l * 0.5)} ${r2(Math.cos(a) * l)} ${r2(Math.sin(a) * l)}`, stroke: hair[Math.floor(R() * 3)], strokeWidth: owl ? 1.3 : 0.9, strokeLinecap: "round", fill: "none", strokeOpacity: 0.9 }));
    }
    back.push(h("g", { mask: `url(#${id}-pm)` }, fur));
    // mechón delantero que cubre la raíz de la garra
    for (let i = 0; i < 28; i++) {
      const x0 = bx + (R() - 0.5) * dw * 1.7, t = dw * (0.15 + R() * 0.45);
      const l = bw * (0.6 + R() * 0.6) * (owl ? 1.25 : 1), a = -dir * Math.PI / 2 + (x0 - bx) / dw * 0.6 + (R() - 0.5) * 0.5;
      front.push(h("path", { d: `M${r2(x0)} ${Y(t)} q${r2(Math.cos(a) * l * 0.5 + (R() - 0.5) * 1.5)} ${r2(Math.sin(a) * l * 0.5)} ${r2(Math.cos(a) * l)} ${r2(Math.sin(a) * l)}`, stroke: hair[Math.floor(R() * 3)], strokeWidth: owl ? 1.3 : 1, strokeLinecap: "round", fill: "none" }));
    }
    return { back, front };
  }
  // dedo escamoso (rapaces, ratites, gallo, loros, pájaros)
  // Dedo largo con escudetes transversales; se difumina hacia el extremo (máscara) para que no
  // parezca un tornillo cuando nada lo recorta (banco de ensayo).
  defs.push(lin(`${id}-toe`, [[0, darken(art.toe, 0.25)], [0.35, lighten(art.toe, 0.18)], [1, darken(art.toe, 0.3)]], { x1: 0, y1: 0, x2: 1, y2: 0 }));
  const tw = bw * 1.45, top = by - bw * 0.2 * dir, len = 96;
  defs.push(lin(`${id}-tf`, [[0, "#FFFFFF", 1], [1, "#FFFFFF", 0]], { user: true, x1: bx, y1: r2(top + len * 0.42 * dir), x2: bx, y2: r2(top + len * 0.92 * dir) }));
  defs.push(h("mask", { id: `${id}-tm`, maskUnits: "userSpaceOnUse", x: -200, y: -200, width: 500, height: 540 },
    h("rect", { x: -200, y: -200, width: 500, height: 540, fill: `url(#${id}-tf)` })));
  const toe = [h("rect", { x: r2(bx - tw), y: r2(down ? top - len : top), width: r2(tw * 2), height: len, rx: r2(tw * 0.9), fill: `url(#${id}-toe)` })];
  for (let r = 0; r * bw * 0.8 + bw * 0.55 < len - bw; r++) {
    const sy = top + (r * bw * 0.8 + bw * 0.55) * dir;
    toe.push(h("path", { d: `M${r2(bx - tw * 0.92)} ${r2(sy)} Q${r2(bx)} ${r2(sy + bw * 0.55 * dir)} ${r2(bx + tw * 0.92)} ${r2(sy)}`, stroke: darken(art.toe, 0.45), strokeOpacity: 0.6, strokeWidth: 0.8, fill: "none" }));
    toe.push(h("path", { d: `M${r2(bx - tw * 0.6)} ${r2(sy + bw * 0.12 * dir)} Q${r2(bx)} ${r2(sy + bw * 0.45 * dir)} ${r2(bx + tw * 0.6)} ${r2(sy + bw * 0.12 * dir)}`, stroke: "#FFFFFF", strokeOpacity: 0.18, strokeWidth: 0.6, fill: "none" }));
  }
  back.push(h("g", { mask: `url(#${id}-tm)` }, toe));
  front.push(h("path", { d: `M${r2(bx - tw * 0.95)} ${r2(top + bw * 0.1 * dir)} Q${r2(bx)} ${r2(top + bw * 0.9 * dir)} ${r2(bx + tw * 0.95)} ${r2(top + bw * 0.1 * dir)}`, stroke: darken(art.toe, 0.5), strokeOpacity: 0.7, strokeWidth: 1.1, fill: "none" }));
  return { back, front };
}
