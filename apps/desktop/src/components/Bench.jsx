import { C, surfaceArt, grooveArt, punctureArt, clawArt, nailSideArt, MATERIAL_LOOK, darken } from "@sts/core";
import { renderNodes, memoArt } from "./Scene.jsx";

/* ════════ BANCO DE ENSAYO ════════
   Losa del material con su textura real, la herramienta dibujada (uña de lado o garra colgando) y
   la marca que deja. Rayado: la punta avanza y el surco se revela con ella. Punción: baja e impacta. */
const W = 360, TOP = 104, FACE = 38, GY = TOP + FACE * 0.46, CX = 180;

export function Bench({ res, phase, length, target, method, tool }) {
  const { claw, geom, base, inlay, wet } = tool;
  const puncture = res ? res.puncture : method === "puncion";
  const x1 = 46, len = 70 + (length / 60) * 222, x2 = x1 + len;
  const look = MATERIAL_LOOK[target.id];
  const surf = memoArt(`bench:${target.id}`, () => surfaceArt(target.id, { x: 12, y: TOP, w: W - 24, h: FACE, uid: "bench", rx: 5 }));
  const art = memoArt(`btool:${claw ? claw.id : `${geom.id}:${base.id}`}:${inlay.id}:${wet}`,
    () => (claw ? clawArt(claw, { orient: "down", inlay, uid: "bt" }) : nailSideArt({ geom, base, inlay, wet, uid: "bt" })));
  const scale = claw ? 0.56 : 0.78;
  const done = phase === "done", idle = phase === "idle";
  const tipX = puncture ? CX : idle ? x1 : x2;
  // Punción: baja, impacta y, al terminar, se retira un poco para que se vea la herida.
  const tipY = puncture ? (idle ? GY - 34 : done ? GY - 13 : GY + 1.5) : GY;
  const groove = res && !res.puncture ? grooveArt(target.id, res, { x1, x2, y: GY, uid: "bg" }) : null;
  const hole = res && res.puncture ? punctureArt(target.id, res, { cx: CX, cy: GY, uid: "bp", fangs: !!(claw && claw.fang) }) : null;
  const move = { transform: `translate(${tipX}px, ${tipY}px)`,
    transition: puncture ? (done ? "transform 0.5s cubic-bezier(.2,.8,.3,1)" : "transform 0.9s cubic-bezier(.6,0,.9,.4)") : "transform 1.1s cubic-bezier(.45,.05,.25,1)" };
  return (
    <svg viewBox={`0 0 ${W} 170`} style={{ width: "100%", height: "auto", display: "block" }} role="img"
      aria-label={res ? `Banco: ${res.verdict}` : `Banco listo: ${target.name}`}>
      <defs>
        {renderNodes(surf.defs, "sd")}
        {hole && renderNodes(hole.defs, "hd")}
        <linearGradient id="bench-face" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={darken(look.lo, 0.25)} /><stop offset="1" stopColor={darken(look.lo, 0.55)} />
        </linearGradient>
        <radialGradient id="bench-shadow"><stop offset="0" stopColor="#000" stopOpacity="0.45" /><stop offset="1" stopColor="#000" stopOpacity="0" /></radialGradient>
        <radialGradient id="bench-floor" cx="0.5" cy="0.2" r="0.7"><stop offset="0" stopColor="#000" stopOpacity="0.35" /><stop offset="1" stopColor="#000" stopOpacity="0" /></radialGradient>
      </defs>
      <ellipse cx={W / 2} cy={TOP + FACE + 18} rx={W / 2 - 10} ry="12" fill="url(#bench-floor)" />
      <rect x="12" y={TOP + FACE - 6} width={W - 24} height="22" rx="5" fill="url(#bench-face)" />
      {renderNodes(surf.body, "sb")}
      <rect x="12" y={TOP} width={W - 24} height={FACE} rx="5" fill="none" stroke="rgba(255,255,255,.12)" />
      {groove && (
        <g>
          {groove.lines.map((n, i) => {
            const { key, ...a } = n.attrs;
            return <line key={i} {...a} style={{ strokeDashoffset: idle ? groove.length : 0, transition: "stroke-dashoffset 1.1s cubic-bezier(.45,.05,.25,1)" }} />;
          })}
          <g style={{ opacity: done ? 1 : 0, transition: "opacity .35s" }}>{renderNodes(groove.extras, "ge")}</g>
        </g>
      )}
      {hole && <g style={{ opacity: done ? 1 : 0, transition: "opacity .25s" }}>{renderNodes(hole.body, "hb")}</g>}
      <g className="tool" style={move}>
        <ellipse cx="0" cy={puncture ? (idle ? 34 : done ? 15 : 2) : 2} rx="14" ry="3.2" fill="url(#bench-shadow)" />
        <g transform={`scale(${scale}) translate(${-art.tip.x} ${-art.tip.y})`}>
          {renderNodes(art.defs.length ? [{ tag: "defs", attrs: {}, children: art.defs }] : [], "td")}
          {renderNodes(art.body, "tb")}
        </g>
      </g>
      {res && res.toolWorn && done && <circle cx={tipX} cy={GY - 3} r="4" fill={C.coral} opacity="0.85" />}
    </svg>
  );
}
