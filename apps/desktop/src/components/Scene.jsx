import { createElement } from "react";

/* Traduce el grafo de escena de @sts/core (art.js) a elementos SVG de React DOM.
   La app móvil tiene su gemelo con react-native-svg: los dos pintan exactamente el mismo dibujo. */
export function renderNodes(nodes, prefix = "k") {
  return nodes.map((n, i) => {
    const { key, ...attrs } = n.attrs;
    return createElement(n.tag, { key: key ?? `${prefix}${i}`, ...attrs }, n.children.length ? renderNodes(n.children, `${prefix}${i}.`) : undefined);
  });
}

// El dibujo es determinista: se calcula una vez por combinación y se reutiliza entre renders.
const cache = new Map();
export function memoArt(key, make) {
  let v = cache.get(key);
  if (!v) { if (cache.size > 600) cache.clear(); v = make(); cache.set(key, v); }
  return v;
}

export function Art({ art, viewBox, width = "100%", height = "100%", label, style, children }) {
  return (
    <svg viewBox={viewBox} width={width} height={height} style={{ display: "block", overflow: "hidden", ...style }}
      role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : "true"}>
      <defs>{renderNodes(art.defs, "d")}</defs>
      {renderNodes(art.body, "b")}
      {children}
    </svg>
  );
}
