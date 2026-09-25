import React from "react";
import { View, Text } from "react-native";
import Svg, { G, Defs, Path, Rect, Line, Circle, Polygon, Text as SvgText } from "react-native-svg";
import { C, clamp, CAR_SECTION, carSectionArt, SKIN_LAYERS, SKIN_SECTION, skinSectionArt, surfaceArt, paneFractureArt, fmtDepth } from "@sts/core";
import { MONO, MONOB } from "../theme";
import { renderNodes, memoArt } from "./Scene";

/* Cortes transversales con la textura real de cada capa. Gemelo de apps/desktop/src/components/sections.jsx. */
const layerArt = (look, x, y, w, h) => memoArt(`layer:${look}:${x}:${Math.round(y)}:${w}:${Math.round(h)}`, () => surfaceArt(look, { x, y, w, h, uid: `ly-${look}-${Math.round(y)}`, detail: 0.8 }));

const Frame = ({ ratio, label, children }) => (
  <View style={{ width: "100%", maxWidth: 560, alignSelf: "center", aspectRatio: ratio }} accessible accessibilityRole="image" accessibilityLabel={label}>
    {children}
  </View>
);

function Wedge({ top, dY, vcol, label, labelY }) {
  return (
    <G>
      <Polygon points={`76,${top} 90,${top} 83,${dY}`} fill={vcol} stroke="rgba(0,0,0,0.35)" strokeWidth={0.6} />
      <Line x1="8" y1={dY} x2="158" y2={dY} stroke={vcol} strokeWidth={1.4} strokeDasharray={[4, 3]} />
      <Circle cx="83" cy={dY} r="3" fill={vcol} stroke="#000" strokeOpacity={0.4} strokeWidth={0.6} />
      <SvgText x="166" y={labelY} fontFamily={MONOB} fontSize="9.5" fill={vcol}>{label}</SvgText>
    </G>
  );
}

/* Corte del coche: las capas de pintura ampliadas, la carrocería (acero, aluminio o plástico) y el hueco
   de la puerta. El dibujo entero sale del motor (carSectionArt), el mismo que en escritorio. */
export function PaintLayers({ res, target }) {
  const art = carSectionArt(res, target, { uid: "cars" });
  return (
    <Frame ratio={CAR_SECTION.w / CAR_SECTION.h} label={`Corte de ${target.name.toLowerCase()}: ${res.verdict.toLowerCase()}, ≈ ${fmtDepth(res.depthUm)}`}>
      <Svg viewBox={`0 0 ${CAR_SECTION.w} ${CAR_SECTION.h}`} width="100%" height="100%">
        <Defs>{renderNodes(art.defs, "d")}</Defs>
        {renderNodes(art.body, "b")}
        {art.labels.map((l, i) => <SvgText key={i} x={l.x} y={l.y} fontFamily={l.bold ? MONOB : MONO} fontSize={l.size} fill={l.color}>{l.text}</SvgText>)}
      </Svg>
    </Frame>
  );
}

/* Corte de la puerta: laca fina sobre roble macizo. Espesores del material (motor). */
export function DoorLayers({ depthUm, vcol, lacaUm, thicknessMm }) {
  const H = 150, top = 6, draw = H - 12, thickUm = thicknessMm * 1000;
  const lacaH = draw * 0.16, woodH = draw * 0.84, woodTop = top + lacaH;
  const through = depthUm >= thickUm;
  let dY;
  if (depthUm <= lacaUm) dY = top + (clamp(depthUm, 0, lacaUm) / lacaUm) * lacaH;
  else { const frac = clamp((depthUm - lacaUm) / (thickUm - lacaUm), 0, 1); dY = woodTop + Math.sqrt(frac) * woodH; }
  if (through) dY = top + draw;
  const dTxt = through ? `ATRAVIESA · ${thicknessMm} mm` : `≈ ${fmtDepth(depthUm)}`;
  const laca = layerArt("capa-laca", 8, top, 150, lacaH), wood = layerArt("capa-roble", 8, woodTop, 150, woodH);
  return (
    <Frame ratio={300 / 156} label={`Corte de la puerta: ${dTxt}`}>
      <Svg viewBox="0 0 300 156" width="100%" height="100%">
        <Defs>{renderNodes([...laca.defs, ...wood.defs], "d")}</Defs>
        {renderNodes(laca.body, "l")}{renderNodes(wood.body, "w")}
        <SvgText x="166" y={top + lacaH / 2 + 3} fontFamily={MONO} fontSize="8.5" fill={C.dim}>{`Laca · 0–${lacaUm} µm`}</SvgText>
        <SvgText x="166" y={woodTop + 16} fontFamily={MONO} fontSize="8.5" fill={C.dim}>Roble macizo</SvgText>
        <SvgText x="166" y={woodTop + 29} fontFamily={MONO} fontSize="8.5" fill={C.dimmer}>{`${lacaUm} µm – ${thicknessMm} mm`}</SvgText>
        <Rect x="8" y={top} width="150" height={draw} fill="none" stroke={C.line2} strokeWidth={1} />
        <Wedge top={top} dY={dY} vcol={vcol} label={dTxt} labelY={dY < 22 ? dY + 15 : dY - 5} />
      </Svg>
    </Frame>
  );
}

/* Perfil de la huella en un sólido: dibujo exagerado con la proporción y el modo que da el motor
   (arado, cuña, corte, grietas en frágiles, agujero pasante). */
const XW = 320, XTOP = 38, XH = 56, XCX = 160;
const crackLines = (cx, y, d, n) => Array.from({ length: n }, (_, i) => {
  const a = Math.PI / 2 + (i - (n - 1) / 2) * 0.55, l = 10 + d * 0.6 + (i % 2) * 6;
  return `M${cx} ${y} l${(Math.cos(a) * l * 0.55).toFixed(1)} ${(Math.sin(a) * l * 0.5).toFixed(1)} l${(Math.cos(a) * l * 0.45 + (i % 2 ? 2 : -2)).toFixed(1)} ${(Math.sin(a) * l * 0.5).toFixed(1)}`;
});

export function CrossSection({ res, target }) {
  if (!res) return null;
  const block = memoArt(`xs:${target.id}`, () => surfaceArt(target.id, { x: 8, y: XTOP, w: XW - 16, h: XH, uid: "xs", rx: 5, detail: 0.7 }));
  // Al rayar piel el motor no calcula la profundidad (grooveWidthUm = null): se dibuja por gravedad.
  const skinScratch = res.skin && !res.puncture;
  const known = res.depthUm > 0 && res.grooveWidthUm > 0;
  const marked = skinScratch ? res.scratched === true : res.sev > 0.02 && res.depthUm > 0.05;
  const through = !!res.through;
  const d = through ? XH : 3 + res.sev * 38;
  // proporción real de la huella que da el motor (semianchura frente a profundidad), acotada para que se vea
  const ratio = known ? res.grooveWidthUm / 2 / res.depthUm : 1.6;
  const hw = clamp(d * ratio, 4, 118);
  const pile = !marked ? 0 : res.absMode === "cuña" ? d * 0.3 : res.absMode === "arado" ? d * 0.2 : res.puncture && !target.brittle ? d * 0.08 : 0;
  const L = XCX - hw, R = XCX + hw, bot = XTOP + d;
  const profile = res.puncture
    ? `M${L - 12} ${XTOP} Q${L - 5} ${XTOP - pile} ${L} ${XTOP} L${XCX - 1.2} ${bot} Q${XCX} ${bot + 1.5} ${XCX + 1.2} ${bot} L${R} ${XTOP} Q${R + 5} ${XTOP - pile} ${R + 12} ${XTOP}`
    : `M${L - 14} ${XTOP} Q${L - 7} ${XTOP - pile} ${L} ${XTOP} C${XCX - hw * 0.45} ${XTOP} ${XCX - hw * 0.28} ${bot} ${XCX} ${bot} C${XCX + hw * 0.28} ${bot} ${XCX + hw * 0.45} ${XTOP} ${R} ${XTOP} Q${R + 7} ${XTOP - pile} ${R + 14} ${XTOP}`;
  const dims = !known ? "profundidad no calculada" : res.puncture ? `↓ ${fmtDepth(res.depthUm)}` : `↔ ${fmtDepth(res.grooveWidthUm)}  ↓ ${fmtDepth(res.depthUm)}`;
  // Una hoja de vidrio se parte por flexión aunque la punta no deje huella: grietas de lado a lado.
  const label = marked ? dims : res.shattered ? "hoja partida por flexión" : "sin huella medible";
  return (
    <Frame ratio={XW / 112} label={marked ? `Perfil de la huella: ${dims}` : res.shattered ? "La hoja de vidrio se ha partido por flexión" : "Sin huella medible"}>
      <Svg viewBox={`0 0 ${XW} 112`} width="100%" height="100%">
        <Defs>{renderNodes(block.defs, "d")}</Defs>
        {renderNodes(block.body, "b")}
        {marked && (
          <G>
            <Path d={through ? `M${L} ${XTOP - 1} L${R} ${XTOP - 1} L${R} ${XTOP + XH + 1} L${L} ${XTOP + XH + 1} Z` : `${profile} L${R + 14} ${XTOP - 12} L${L - 14} ${XTOP - 12} Z`} fill={C.panel2} />
            {!through && <Path d={profile} fill="none" stroke={res.vcol} strokeWidth={1.8} strokeLinejoin="round" />}
            {through && <Path d={`M${L} ${XTOP} L${L} ${XTOP + XH} M${R} ${XTOP} L${R} ${XTOP + XH}`} stroke={res.vcol} strokeWidth={1.8} />}
            {target.brittle && res.sev > 0.3 && crackLines(XCX, bot, d, 5).map((c, i) => <Path key={i} d={c} fill="none" stroke="#FFFFFF" strokeOpacity={0.55} strokeWidth={0.8} />)}
            {res.absMode === "corte" && <Path d={`M${R + 2} ${XTOP - 1} q10 -4 12 -14 q1 -7 -6 -7 q-6 1 -3 7`} fill="none" stroke={res.vcol} strokeWidth={2.2} strokeLinecap="round" />}
          </G>
        )}
        {!marked && <Path d={`M8 ${XTOP} L${XW - 8} ${XTOP}`} stroke={res.vcol} strokeWidth={1.6} />}
        {res.shattered && renderNodes(paneFractureArt({ x: 8, y: XTOP, w: XW - 16, h: XH, seed: target.id }), "pf")}
        <SvgText x="10" y="16" fontFamily={MONO} fontSize="8.5" fill={C.dim}>{res.puncture ? "Perfil del agujero" : skinScratch ? "Perfil del arañazo" : "Perfil del surco"}</SvgText>
        <SvgText x={XW - 10} y="16" textAnchor="end" fontFamily={MONOB} fontSize="8.5" fill={marked || res.shattered ? res.vcol : C.dimmer}>{label}</SvgText>
        <SvgText x={XW / 2} y="108" textAnchor="middle" fontFamily={MONO} fontSize="7" fill={C.dimmer}>{known ? "dibujo exagerado · proporción y modo según el modelo" : "esquema según la gravedad del resultado"}</SvgText>
      </Svg>
    </Frame>
  );
}

/* Corte de la piel por capas (dibujo y rótulos de @sts/core), con la herida hasta su profundidad. */
export function SkinLayers({ res }) {
  const art = skinSectionArt(res, { uid: "sks" });
  return (
    <Frame ratio={SKIN_SECTION.w / SKIN_SECTION.h} label={res.depthUm > 0 ? `Corte de la piel: la herida llega a ${fmtDepth(res.depthUm)}, ${res.layer}` : "Corte de la piel: sin herida"}>
      <Svg viewBox={`0 0 ${SKIN_SECTION.w} ${SKIN_SECTION.h}`} width="100%" height="100%">
        <Defs>{renderNodes(art.defs, "d")}</Defs>
        {renderNodes(art.body, "b")}
        {art.labels.map((l, i) => <SvgText key={i} x={l.x} y={l.y} fontFamily={l.bold ? MONOB : MONO} fontSize={l.size} fill={l.color}>{l.text}</SvgText>)}
      </Svg>
    </Frame>
  );
}

const fmtUm = (um) => (um >= 1000 ? `${(um / 1000).toFixed(1).replace(".", ",")} mm` : `${um} µm`);
/** Propiedades de cada capa: espesor, rigidez y tenacidad (en tejido blando no hay dureza Vickers). */
export function SkinTable({ reachedId }) {
  const cell = { fontFamily: MONO, fontSize: 10, color: C.dim };
  return (
    <View>
      <Text style={[cell, { color: C.dimmer, marginBottom: 6 }]}>Capas de la piel · brazo de un adulto. En tejido blando no hay dureza Vickers: rigidez E y tenacidad J.</Text>
      {SKIN_LAYERS.map((l) => {
        const on = l.id === reachedId;
        return (
          <View key={l.id} style={{ flexDirection: "row", alignItems: "center", gap: 6, paddingVertical: 5, borderTopWidth: 1, borderTopColor: C.line, backgroundColor: on ? C.panel3 : "transparent" }}
            accessible accessibilityLabel={`${l.name}: ${l.note}`}>
            <View style={{ width: 9, height: 9, borderRadius: 3, backgroundColor: l.col }} />
            <Text style={[cell, { flex: 1.3, color: on ? C.text : C.dim }]}>{l.name}</Text>
            <Text style={[cell, { flex: 1.3 }]}>{l.id === "musculo" ? `> ${fmtUm(l.from)}` : `${fmtUm(l.from)} – ${fmtUm(l.to)}`}</Text>
            <Text style={[cell, { flex: 0.8 }]}>{l.E ? `${l.E} kPa` : "—"}</Text>
            <Text style={[cell, { flex: 0.9 }]}>{l.id === "cornea" || l.id === "epidermis" ? "—" : `${l.jT} kJ/m²`}</Text>
          </View>
        );
      })}
    </View>
  );
}
