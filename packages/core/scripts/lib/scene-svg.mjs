/* Serializador canónico del grafo de escena de art.js ({ tag, attrs, children }) a texto SVG.
   Lo usan el exportador del oráculo (export-fixtures.mjs) y los scripts de demostración. El port en
   GDScript (godot/core/lab/svg.gd) tiene que producir exactamente los mismos bytes: mismas reglas de
   nombres, mismo orden de atributos (el de inserción) y números escritos como String(n) de JavaScript. */

// Atributos de presentación que React DOM escribe con guion (strokeWidth → stroke-width). Los demás
// (gradientUnits, maskUnits, viewBox…) se quedan en camelCase, como en SVG.
const KEBAB = new Set([
  "clipPath", "clipRule", "dominantBaseline", "fillOpacity", "fillRule", "fontFamily", "fontSize", "fontWeight",
  "letterSpacing", "stopColor", "stopOpacity", "strokeDasharray", "strokeDashoffset", "strokeLinecap",
  "strokeLinejoin", "strokeMiterlimit", "strokeOpacity", "strokeWidth", "textAnchor",
]);
export const svgAttrName = (k) => (KEBAB.has(k) ? k.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`) : k);
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** Nodos → SVG. Se omiten `key` (solo sirve a React) y los valores null, undefined o false. */
export function nodesToSvg(nodes) {
  let out = "";
  for (const n of nodes) {
    out += `<${n.tag}`;
    for (const [k, v] of Object.entries(n.attrs)) {
      if (k === "key" || v === undefined || v === null || v === false) continue;
      out += ` ${svgAttrName(k)}="${esc(String(v))}"`;
    }
    out += n.children.length ? `>${nodesToSvg(n.children)}</${n.tag}>` : "/>";
  }
  return out;
}

/** Documento SVG completo de una ilustración: defs, body, lines y extras, en ese orden (como el banco). */
export function sceneToSvg(art, { viewBox, width, height }) {
  const nodes = Array.isArray(art) ? { body: art } : art;
  let out = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="${viewBox}">`;
  if (nodes.defs && nodes.defs.length) out += `<defs>${nodesToSvg(nodes.defs)}</defs>`;
  for (const k of ["body", "lines", "extras"]) if (Array.isArray(nodes[k])) out += nodesToSvg(nodes[k]);
  return `${out}</svg>`;
}
