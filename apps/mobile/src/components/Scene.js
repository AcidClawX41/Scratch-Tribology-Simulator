import React from "react";
import Svg, {
  G, Defs, Path, Rect, Circle, Ellipse, Line, Polygon, Polyline, Text as SvgText,
  LinearGradient, RadialGradient, Stop, Mask, ClipPath,
} from "react-native-svg";

/* Traduce el grafo de escena de @sts/core (art.js) a react-native-svg. Es el gemelo de
   apps/desktop/src/components/Scene.jsx: los dos pintan exactamente el mismo dibujo.
   Qué elementos puede usar art.js lo vigila un test de core (sin filtros SVG). */
const TAGS = {
  g: G, defs: Defs, path: Path, rect: Rect, circle: Circle, ellipse: Ellipse, line: Line,
  polygon: Polygon, polyline: Polyline, text: SvgText, linearGradient: LinearGradient,
  radialGradient: RadialGradient, stop: Stop, mask: Mask, clipPath: ClipPath,
};

export function renderNodes(nodes, prefix = "k") {
  return nodes.map((n, i) => {
    const Comp = TAGS[n.tag];
    if (!Comp) return null;
    const { key, ...attrs } = n.attrs;
    return React.createElement(Comp, { key: key ?? `${prefix}${i}`, ...attrs }, n.children.length ? renderNodes(n.children, `${prefix}${i}.`) : undefined);
  });
}

// El dibujo es determinista: se calcula una vez por combinación y se reutiliza entre renders.
const cache = new Map();
export function memoArt(key, make) {
  let v = cache.get(key);
  if (!v) { if (cache.size > 600) cache.clear(); v = make(); cache.set(key, v); }
  return v;
}

/** Lienzo SVG con un dibujo de core. label: texto para VoiceOver/TalkBack (si falta, es decorativo). */
export function Art({ art, viewBox, width = "100%", height = "100%", label, children }) {
  return (
    <Svg viewBox={viewBox} width={width} height={height}
      accessible={!!label} accessibilityLabel={label} accessibilityRole={label ? "image" : undefined}
      importantForAccessibility={label ? "yes" : "no-hide-descendants"}>
      <Defs>{renderNodes(art.defs, "d")}</Defs>
      {renderNodes(art.body, "b")}
      {children}
    </Svg>
  );
}
