import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { C, SKIN_LAYERS, fmtF, fmtP, fmtJ, fmtDepth, fmtLen, hvBar } from "@sts/core";
import { DISP8, MONO, MONOB } from "../theme";
import { Card, Metric } from "../components/ui";
import { Bench } from "../components/Bench";
import { PaintLayers, DoorLayers, CrossSection, SkinLayers, SkinTable } from "../components/sections";

const ABS = { corte: ["corte (arranca viruta)", C.coral], "cuña": ["cuña (apila proa)", C.gold], arado: ["arado (desplaza)", C.mint] };

function HardnessBars({ res }) {
  return (
    <View style={{ marginTop: 12 }}>
      {[[res.claw ? "Garra" : "Tu uña", res.hvTool, res.mohsTool, C.rose], [res.woodDoor ? "Laca" : "Objetivo", res.tHV, res.tMohs, C.mint]].map(([n, hv, m, col]) => (
        <View key={n} style={st.barRow}>
          <Text style={st.barName}>{n}</Text>
          <View style={st.barTrack}><View style={{ width: `${hvBar(hv)}%`, height: "100%", backgroundColor: col, borderRadius: 5 }} /></View>
          <Text style={[st.barVal, { color: col }]} numberOfLines={1}>{fmtP(hv)} HV{m ? ` · M${m}` : ""}</Text>
        </View>
      ))}
      <Text style={[st.small, { textAlign: "right" }]}>escala logarítmica</Text>
    </View>
  );
}

export function ResultCard({ lab }) {
  const { res, phase, length, target, method, claw, geom, base, inlay, wet } = lab;
  const done = phase === "done" && res;
  return (
    <Card title="Banco de ensayo" right={<Text style={st.small}>{target.name}</Text>}>
      <View style={st.benchBox}>
        <Bench res={res} phase={phase} length={length} target={target} method={method} tool={{ claw, geom, base, inlay, wet }} />
      </View>
      {!done && <Text style={st.hint}>{phase === "running" ? "Ensayando…" : "Pulsa ARAÑAR para correr el ensayo."}</Text>}
      {done && (
        <View accessibilityLiveRegion="polite">
          <View style={[st.verdict, { borderColor: res.vcol, borderLeftColor: res.vcol }]}>
            <View style={{ flexDirection: "row", alignItems: "center", flexWrap: "wrap", gap: 8 }}>
              <Text style={[st.verdictTxt, { color: res.vcol }]} accessibilityRole="header">{res.verdict}</Text>
              {res.tearing && <Text style={[st.tag, { backgroundColor: C.gold }]}>DESGARRO</Text>}
              {res.wet && <Text style={[st.tag, { backgroundColor: C.ice }]}>HÚMEDA</Text>}
            </View>
            <Text style={st.vsub}>{res.vsub}</Text>
          </View>
          {!res.skin && !res.paint && <HardnessBars res={res} />}
          <View style={st.metrics}>
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
              : <Metric label="Fricción Coulomb" sym="μ · Ft" val={`${res.mu.toFixed(2)} · ${fmtF(res.Ffric)} N`} />}
            {res.absMode && <Metric label="Modo abrasión" val={ABS[res.absMode][0]} col={ABS[res.absMode][1]} />}
            <Metric label="Adhesión vdW" sym="JKR" val={`${res.Fadh_mN.toFixed(2)} mN`} />
            <Metric label="Desgaste Archard" val={`${res.wearIdx} u.a.`} />
            <Metric label="Qué cede" val={res.cede} />
            {res.puncture
              ? <Metric label="Inyección" val={res.inject ? (res.pierces ? "sí · veneno" : "no perfora") : "no (punción seca)"} col={res.inject && res.pierces ? C.coral : C.dim} />
              : <Metric label="Longitud" val={`${length} mm`} />}
          </View>
          <View style={st.section}>
            {res.skin ? <SkinLayers res={res} />
              : res.paint ? <PaintLayers res={res} target={target} />
                : res.woodDoor ? <DoorLayers depthUm={res.depthUm} vcol={res.vcol} lacaUm={target.layers.film.t} thicknessMm={target.thickness} />
                  : <CrossSection res={res} target={target} />}
            {res.skin && <View style={{ marginTop: 10 }}><SkinTable reachedId={res.depthUm > 0 ? (SKIN_LAYERS.find((l) => l.name === res.layer) || {}).id : null} /></View>}
          </View>
          <Text style={st.fact}>{target.fact}</Text>
          <Text style={st.factDim}>
            Adhesión Van der Waals: {res.Fadh_mN.toFixed(2)} mN, minúscula frente a la fuerza aplicada. Solo domina a escala micro/nano o en superficies muy lisas a carga casi nula (gecko / stiction).
          </Text>
        </View>
      )}
    </Card>
  );
}

const st = StyleSheet.create({
  small: { fontFamily: MONO, fontSize: 10.5, color: C.dimmer },
  benchBox: { backgroundColor: C.panel2, borderColor: C.line, borderWidth: 1, borderRadius: 16, padding: 4, overflow: "hidden" },
  hint: { fontFamily: MONO, fontSize: 11.5, color: C.dimmer, marginTop: 10 },
  verdict: { marginTop: 12, padding: 12, borderRadius: 14, backgroundColor: C.panel2, borderWidth: 1, borderLeftWidth: 4 },
  verdictTxt: { fontFamily: DISP8, fontSize: 22, lineHeight: 26 },
  tag: { fontFamily: MONOB, fontSize: 10, color: C.bg, borderRadius: 7, paddingHorizontal: 7, paddingVertical: 2, overflow: "hidden" },
  vsub: { fontFamily: MONO, fontSize: 11, color: C.dim, marginTop: 4, lineHeight: 16 },
  barRow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 5 },
  barName: { fontFamily: MONO, fontSize: 11, color: C.dim, width: 58 },
  barTrack: { flex: 1, height: 8, backgroundColor: C.panel2, borderRadius: 5, overflow: "hidden", borderWidth: 1, borderColor: C.line },
  barVal: { fontFamily: MONO, fontSize: 11, minWidth: 104, textAlign: "right" },
  metrics: { flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between", rowGap: 8, marginTop: 12 },
  section: { marginTop: 12, backgroundColor: C.panel2, borderColor: C.line, borderWidth: 1, borderRadius: 14, padding: 8 },
  fact: { fontFamily: MONO, fontSize: 11, color: C.dim, lineHeight: 17, marginTop: 10 },
  factDim: { fontFamily: MONO, fontSize: 10, color: C.dimmer, lineHeight: 15, marginTop: 6 },
});
