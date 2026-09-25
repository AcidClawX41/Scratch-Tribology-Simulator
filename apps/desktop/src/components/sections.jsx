import { C, clamp, CAR_SECTION, carSectionArt, SKIN_LAYERS, SKIN_SECTION, skinSectionArt, surfaceArt, paneFractureArt, fmtDepth } from "@sts/core";
import { MONO } from "../theme.js";
import { renderNodes, memoArt } from "./Scene.jsx";

/* Cortes transversales con la textura real de cada capa (la misma geometría que en el banco). */
// En ventanas anchas el corte no crece sin límite: el texto quedaría enorme.
const SECTION_STYLE = { width: "100%", maxWidth: 560, height: "auto", display: "block", margin: "0 auto" };
const layerArt = (look, x, y, w, h) => memoArt(`layer:${look}:${x}:${Math.round(y)}:${w}:${Math.round(h)}`, () => surfaceArt(look, { x, y, w, h, uid: `ly-${look}-${Math.round(y)}`, detail: 0.8 }));

function Wedge({ top, dY, vcol, label, labelY }) {
  return (
    <>
      <polygon points={`76,${top} 90,${top} 83,${dY}`} fill={vcol} stroke="rgba(0,0,0,.35)" strokeWidth="0.6" />
      <line x1="8" y1={dY} x2="158" y2={dY} stroke={vcol} strokeWidth="1.4" strokeDasharray="4 3" />
      <circle cx="83" cy={dY} r="3" fill={vcol} stroke="#000" strokeOpacity="0.4" strokeWidth="0.6" />
      <text x="166" y={labelY} fontFamily={MONO} fontSize="9.5" fill={vcol} fontWeight="700">{label}</text>
    </>
  );
}

/* Corte del coche: las capas de pintura ampliadas, la carrocería (acero, aluminio o plástico) y el hueco
   de la puerta. El dibujo entero sale del motor (carSectionArt), el mismo que en móvil. */
export function PaintLayers({ res, target }) {
  const art = carSectionArt(res, target, { uid: "cars" });
  return (
    <svg viewBox={`0 0 ${CAR_SECTION.w} ${CAR_SECTION.h}`} style={SECTION_STYLE} role="img"
      aria-label={`Corte de ${target.name.toLowerCase()}: ${res.verdict.toLowerCase()}, ≈ ${fmtDepth(res.depthUm)}`}>
      <defs>{renderNodes(art.defs, "d")}</defs>
      {renderNodes(art.body, "b")}
      {art.labels.map((l, i) => <text key={i} x={l.x} y={l.y} fontFamily={MONO} fontSize={l.size} fontWeight={l.bold ? 700 : 400} fill={l.color}>{l.text}</text>)}
    </svg>
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
    <svg viewBox="0 0 300 156" style={SECTION_STYLE} role="img" aria-label={`Corte de la puerta: ${dTxt}`}>
      <defs>{renderNodes([...laca.defs, ...wood.defs], "d")}</defs>
      {renderNodes(laca.body, "l")}{renderNodes(wood.body, "w")}
      <text x="166" y={top + lacaH / 2 + 3} fontFamily={MONO} fontSize="8.5" fill={C.dim}>Laca · 0–{lacaUm} µm</text>
      <text x="166" y={woodTop + 16} fontFamily={MONO} fontSize="8.5" fill={C.dim}>Roble macizo</text>
      <text x="166" y={woodTop + 29} fontFamily={MONO} fontSize="8.5" fill={C.dimmer}>{lacaUm} µm – {thicknessMm} mm</text>
      <rect x="8" y={top} width="150" height={draw} fill="none" stroke={C.line2} strokeWidth="1" />
      <Wedge top={top} dY={dY} vcol={vcol} label={dTxt} labelY={dY < 22 ? dY + 15 : dY - 5} />
    </svg>
  );
}

/* Perfil de la huella en un sólido: el bloque con su textura y la forma de la marca.
   Dibujo exagerado (la escala real va de nanómetros a milímetros), pero con las proporciones y
   el modo que da el motor: relación anchura/profundidad, rebordes de arado, viruta de corte,
   grietas en los frágiles y agujero pasante. */
const XW = 320, XTOP = 38, XH = 56, XCX = 160;

function crackLines(cx, y, d, n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = Math.PI / 2 + (i - (n - 1) / 2) * 0.55, l = 10 + d * 0.6 + (i % 2) * 6;
    out.push(`M${cx} ${y} l${(Math.cos(a) * l * 0.55).toFixed(1)} ${(Math.sin(a) * l * 0.5).toFixed(1)} l${(Math.cos(a) * l * 0.45 + (i % 2 ? 2 : -2)).toFixed(1)} ${(Math.sin(a) * l * 0.5).toFixed(1)}`);
  }
  return out;
}

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
    <svg viewBox={`0 0 ${XW} 112`} style={SECTION_STYLE} role="img"
      aria-label={marked ? `Perfil de la huella: ${dims}` : res.shattered ? "La hoja de vidrio se ha partido por flexión" : "Sin huella medible"}>
      <defs>{renderNodes(block.defs, "d")}</defs>
      {renderNodes(block.body, "b")}
      {marked && (
        <>
          <path d={through ? `M${L} ${XTOP - 1} L${R} ${XTOP - 1} L${R} ${XTOP + XH + 1} L${L} ${XTOP + XH + 1} Z` : `${profile} L${R + 14} ${XTOP - 12} L${L - 14} ${XTOP - 12} Z`} fill={C.panel2} />
          {!through && <path d={profile} fill="none" stroke={res.vcol} strokeWidth="1.8" strokeLinejoin="round" />}
          {through && <path d={`M${L} ${XTOP} L${L} ${XTOP + XH} M${R} ${XTOP} L${R} ${XTOP + XH}`} stroke={res.vcol} strokeWidth="1.8" />}
          {target.brittle && res.sev > 0.3 && crackLines(XCX, bot, d, 5).map((c, i) => <path key={i} d={c} fill="none" stroke="#FFFFFF" strokeOpacity="0.55" strokeWidth="0.8" />)}
          {res.absMode === "corte" && (
            <path d={`M${R + 2} ${XTOP - 1} q10 -4 12 -14 q1 -7 -6 -7 q-6 1 -3 7`} fill="none" stroke={res.vcol} strokeWidth="2.2" strokeLinecap="round" />
          )}
        </>
      )}
      {!marked && <path d={`M8 ${XTOP} L${XW - 8} ${XTOP}`} stroke={res.vcol} strokeWidth="1.6" />}
      {res.shattered && renderNodes(paneFractureArt({ x: 8, y: XTOP, w: XW - 16, h: XH, seed: target.id }), "pf")}
      <text x="10" y="16" fontFamily={MONO} fontSize="8.5" fill={C.dim}>{res.puncture ? "Perfil del agujero" : skinScratch ? "Perfil del arañazo" : "Perfil del surco"}</text>
      <text x={XW - 10} y="16" textAnchor="end" fontFamily={MONO} fontSize="8.5" fontWeight="700" fill={marked || res.shattered ? res.vcol : C.dimmer}>{label}</text>
      <text x={XW / 2} y="108" textAnchor="middle" fontFamily={MONO} fontSize="7" fill={C.dimmer}>{known ? "dibujo exagerado · proporción y modo según el modelo" : "esquema según la gravedad del resultado"}</text>
    </svg>
  );
}

/* Corte de la piel por capas (dibujo y rótulos de @sts/core), con la herida hasta su profundidad. */
export function SkinLayers({ res }) {
  const art = skinSectionArt(res, { uid: "sks" });
  return (
    <svg viewBox={`0 0 ${SKIN_SECTION.w} ${SKIN_SECTION.h}`} style={SECTION_STYLE} role="img"
      aria-label={res.depthUm > 0 ? `Corte de la piel: la herida llega a ${fmtDepth(res.depthUm)}, ${res.layer}` : "Corte de la piel: sin herida"}>
      <defs>{renderNodes(art.defs, "d")}</defs>
      {renderNodes(art.body, "b")}
      {art.labels.map((l, i) => <text key={i} x={l.x} y={l.y} fontFamily={MONO} fontSize={l.size} fontWeight={l.bold ? 700 : 400} fill={l.color}>{l.text}</text>)}
    </svg>
  );
}

const fmtUm = (um) => (um >= 1000 ? `${(um / 1000).toFixed(1).replace(".", ",")} mm` : `${um} µm`);
/** Propiedades de cada capa: espesor, rigidez y tenacidad (en tejido blando no hay dureza Vickers). */
export function SkinTable({ reachedId }) {
  const cell = { padding: "5px 6px", borderTop: `1px solid ${C.line}` };
  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontFamily: MONO, fontSize: 11, color: C.dim }}>
        <caption style={{ textAlign: "left", color: C.dimmer, fontSize: 10.5, padding: "0 0 6px" }}>Capas de la piel · brazo de un adulto. En tejido blando no hay dureza Vickers: rigidez E y tenacidad J.</caption>
        <thead><tr style={{ color: C.dimmer, textAlign: "left" }}><th style={cell}>Capa</th><th style={cell}>Profundidad</th><th style={cell}>Rigidez E</th><th style={cell}>Tenacidad J</th></tr></thead>
        <tbody>
          {SKIN_LAYERS.map((l) => (
            <tr key={l.id} style={{ color: l.id === reachedId ? C.text : C.dim, background: l.id === reachedId ? C.panel3 : "transparent" }} title={l.note}>
              <td style={cell}><span style={{ display: "inline-block", width: 9, height: 9, borderRadius: 3, background: l.col, marginRight: 6 }} />{l.name}</td>
              <td style={cell}>{l.id === "musculo" ? `> ${fmtUm(l.from)}` : `${fmtUm(l.from)} – ${fmtUm(l.to)}`}</td>
              <td style={cell}>{l.E ? `${l.E} kPa` : "—"}</td>
              <td style={cell}>{l.id === "cornea" || l.id === "epidermis" ? "—" : `${l.jT} kJ/m²`}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
