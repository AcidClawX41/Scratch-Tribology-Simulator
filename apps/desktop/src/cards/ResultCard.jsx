import { C, SKIN_LAYERS, fmtF, fmtP, fmtDepth, fmtLen, hvBar, fmtJ } from "@sts/core";
import { DISP, MONO } from "../theme.js";
import { Card, Metric } from "../components/ui.jsx";
import { Bench } from "../components/Bench.jsx";
import { PaintLayers, DoorLayers, CrossSection, SkinLayers, SkinTable } from "../components/sections.jsx";

const ABS = { corte: ["corte (arranca viruta)", C.coral], "cuña": ["cuña (apila proa)", C.gold], arado: ["arado (desplaza)", C.mint] };

function HardnessBars({ res }) {
  return (
    <div style={{ marginTop: 14 }}>
      {[[res.claw ? "Garra" : "Tu uña", res.hvTool, res.mohsTool, C.rose], [res.woodDoor ? "Laca" : "Objetivo", res.tHV, res.tMohs, C.mint]].map(([n, hv, m, c]) => (
        <div key={n} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
          <span style={{ fontFamily: MONO, fontSize: 11.5, color: C.dim, width: 64, flexShrink: 0 }}>{n}</span>
          <div style={{ flex: 1, height: 9, background: C.panel2, borderRadius: 6, overflow: "hidden", border: `1px solid ${C.line}` }}>
            <div style={{ width: `${hvBar(hv)}%`, height: "100%", background: `linear-gradient(90deg, ${c}, ${c}CC)`, borderRadius: 6, transition: "width .6s" }} />
          </div>
          <span style={{ fontFamily: MONO, fontSize: 12, color: c, minWidth: 118, textAlign: "right", whiteSpace: "nowrap" }}>{fmtP(hv)} HV{m ? ` · M${m}` : ""}</span>
        </div>
      ))}
      <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, textAlign: "right" }}>escala logarítmica</div>
    </div>
  );
}

export function ResultCard({ lab }) {
  const { res, phase, length, target, method, claw, geom, base, inlay, wet } = lab;
  const done = phase === "done" && res;
  return (
    <Card title="Banco de ensayo" right={<span style={{ fontFamily: MONO, fontSize: 11.5, color: C.dimmer }}>{target.name}</span>}>
      <div style={{ background: `radial-gradient(120% 100% at 50% 0%, ${C.panel3}, ${C.panel2})`, border: `1px solid ${C.line}`, borderRadius: 16, padding: "6px 6px 2px" }}>
        <Bench res={res} phase={phase} length={length} target={target} method={method} tool={{ claw, geom, base, inlay, wet }} />
      </div>
      {!done && <p style={{ fontFamily: MONO, fontSize: 12, color: C.dimmer, margin: "12px 2px 0" }}>{phase === "running" ? "Ensayando…" : "Pulsa ARAÑAR para correr el ensayo."}</p>}
      {done && (
        <div aria-live="polite">
          <div className="verdict" style={{ borderColor: res.vcol, boxShadow: `inset 4px 0 0 ${res.vcol}` }}>
            <span style={{ fontFamily: DISP, fontWeight: 800, fontSize: 25, color: res.vcol, lineHeight: 1.1 }}>{res.verdict}</span>
            {res.tearing && <span className="tag" style={{ background: C.gold }}>DESGARRO</span>}
            {res.wet && <span className="tag" style={{ background: C.ice }}>HÚMEDA</span>}
            <span style={{ fontFamily: MONO, fontSize: 12, color: C.dim, flexBasis: "100%" }}>{res.vsub}</span>
          </div>
          {!res.skin && !res.paint && <HardnessBars res={res} />}
          <div className="metrics">
            <Metric label="Presión real" val={`${fmtP(res.pressure)} MPa`} />
            <Metric label="Presión nominal" sym="F/A" val={`${fmtP(res.pNominal)} MPa`} col={res.pNominal > res.pressure * 1.01 ? C.gold : C.dim} />
            <Metric label={res.puncture ? "Profundidad punción" : res.skin ? "Profundidad herida" : "Profundidad surco"}
              val={res.skin && res.depthUm <= 0 ? "sin herida" : `≈ ${fmtDepth(res.depthUm)}${res.fullReach ? " (tope)" : ""}`} col={res.vcol} />
            {res.skin && <Metric label={res.puncture ? "Fuerza para perforar" : "Fuerza para romper la piel"} val={`≈ ${fmtF(res.fPuncture)} N`} col={(res.puncture ? res.pierces : res.ruptures) ? C.coral : C.mint} />}
            {res.skin && <Metric label="Sangra" val={res.bleeds ? "sí" : "no"} col={res.bleeds ? C.coral : C.mint} />}
            {res.skin && !res.puncture && !res.ruptures && <Metric label="Esfuerzo en la superficie" val={`${fmtP(res.stress)} MPa`} />}
            {!res.skin && <Metric label="Ratio dureza" sym="r" val={`${res.ratio.toFixed(2)}×`} col={res.ratio >= 1.25 ? C.coral : res.ratio >= 0.8 ? C.gold : C.mint} />}
            {res.puncture && res.energyJ > 0 && <Metric label="Energía del golpe" val={`${fmtJ(res.energyJ)} J`} />}
            {res.through && !res.skin && <Metric label={res.puncture ? "Agujero" : "Raja"} val={`Ø ${fmtLen(res.grooveWidthUm)}`} col={res.vcol} />}
            {res.puncture && res.energyJ > 0 && res.workJ != null && <Metric label="Energía que absorbe" val={`${fmtJ(Math.min(res.workJ, res.energyJ))} J`} />}
            {res.paneN != null && <Metric label="La hoja se parte con" val={`≈ ${fmtF(res.paneN)} N`} col={res.shattered ? C.coral : C.mint} />}
            {(res.paint || res.woodDoor || res.skin) && <Metric label="Capa alcanzada" val={res.layer ?? "ninguna"} col={res.vcol} />}
            {!res.puncture && !res.skin && !res.paint && <Metric label="Penetración" sym="χ = P/H" val={res.chi.toFixed(3)} col={res.chi >= 0.1 ? C.coral : C.dim} />}
            {!res.puncture && res.depthUm > 0.05 && <Metric label={res.skin ? "Anchura de la herida" : "Anchura del surco"} val={`≈ ${fmtDepth(res.grooveWidthUm)}`} />}
            {!res.skin && <Metric label="Contacto plástico" sym="φ" val={`${(res.phi * 100).toFixed(0)} %`} col={res.phi < 0.5 ? C.mint : C.dim} />}
            {res.absMode
              ? <Metric label="Fricción de rayado" sym="SCOF" val={`μ ${res.muEff.toFixed(2)} = ${res.muAdh.toFixed(2)} adh + ${res.muPlough.toFixed(2)} arado`} col={res.muPlough > 0.3 ? C.coral : C.dim} />
              : <Metric label="Fricción Coulomb" sym="μ · Ft" val={`${res.mu.toFixed(2)} · ${fmtF(res.Ffric)}\u00A0N`} />}
            {res.absMode && <Metric label="Modo abrasión" val={ABS[res.absMode][0]} col={ABS[res.absMode][1]} />}
            <Metric label="Adhesión vdW" sym="JKR" val={`${res.Fadh_mN.toFixed(2)} mN`} />
            <Metric label="Desgaste Archard" val={`${res.wearIdx} u.a.`} />
            <Metric label="Qué cede" val={res.cede} />
            {res.puncture
              ? <Metric label="Inyección" val={res.inject ? (res.pierces ? "sí · veneno" : "no perfora") : "no (punción seca)"} col={res.inject && res.pierces ? C.coral : C.dim} />
              : <Metric label="Longitud" val={`${length} mm`} />}
          </div>
          <div style={{ marginTop: 14, background: C.panel2, border: `1px solid ${C.line}`, borderRadius: 14, padding: 10 }}>
            {res.skin ? <SkinLayers res={res} />
              : res.paint ? <PaintLayers res={res} target={target} />
                : res.woodDoor ? <DoorLayers depthUm={res.depthUm} vcol={res.vcol} lacaUm={target.layers.film.t} thicknessMm={target.thickness} />
                  : <CrossSection res={res} target={target} />}
            {res.skin && <div style={{ marginTop: 10 }}><SkinTable reachedId={res.depthUm > 0 ? (SKIN_LAYERS.find((l) => l.name === res.layer) || {}).id : null} /></div>}
          </div>
          <p style={{ fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 1.6, margin: "12px 2px 4px" }}>{target.fact}</p>
          <p style={{ fontFamily: MONO, fontSize: 11, color: C.dimmer, lineHeight: 1.55, margin: "0 2px" }}>
            Adhesión Van der Waals: {res.Fadh_mN.toFixed(2)} mN, minúscula frente a la fuerza aplicada. Solo domina a escala micro/nano o en superficies muy lisas a carga casi nula (gecko / stiction).
          </p>
        </div>
      )}
    </Card>
  );
}
