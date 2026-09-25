import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { C, DUEL_CARS, duel, duelVerdict, damageReport, fmtLen } from "@sts/core";
import { DISP, DISP8, MONO, MONOB } from "../theme";
import { Card, Pill, SubLabel, s as ui } from "../components/ui";
import { Bench } from "../components/Bench";

/* ════════ MODO DUAL ════════
   Gemelo de apps/desktop/src/cards/DualCard.jsx: el mismo ensayo en dos coches, los dos bancos
   animados con el ARAÑAR principal y la tabla de qué raya, desgarra, punza o golpea en cada uno.
   Todo se calcula en core (duel, duelVerdict, damageReport). */

function CarPicker({ value, onPick }) {
  return (
    <View style={[ui.wrapRow, { marginBottom: 8 }]}>
      {DUEL_CARS.map((t) => <Pill key={t.id} on={t.id === value} onPress={() => onPick(t.id)} hint={`Comparar con ${t.name.toLowerCase()}`}>{t.name}</Pill>)}
    </View>
  );
}

function DamageList({ rows }) {
  return (
    <View style={{ marginTop: 6 }}>
      {rows.map(([k, v]) => (
        <View key={k} style={st.dRow}>
          <Text style={st.dKey}>{k}</Text>
          <Text style={st.dVal}>{v}</Text>
        </View>
      ))}
    </View>
  );
}

/** Fila de la tabla: una manera de atacar en los dos coches y quién aguanta mejor. */
function DuelRow({ row, cars, current }) {
  const v = duelVerdict(row.res[0], row.res[1], cars);
  return (
    <View style={[st.row, current && { backgroundColor: C.panel3 }]}>
      <Text style={st.mode}>{row.name}{current ? " ◂" : ""}</Text>
      <View style={{ flexDirection: "row", gap: 8 }}>
        {row.res.map((r, i) => (
          <View key={i} style={{ flex: 1 }}>
            <Text style={[st.cellV, { color: r.vcol, fontFamily: v.winner === i ? MONOB : MONO }]}>{r.verdict}</Text>
            <Text style={st.cellD}>{r.depthUm > 0 ? fmtLen(r.depthUm) : "—"}{r.through ? ` · Ø ${fmtLen(r.grooveWidthUm)}` : ""}</Text>
          </View>
        ))}
      </View>
      <Text style={[st.who, { color: v.winner == null ? C.dim : C.mint }]}>{v.text}</Text>
    </View>
  );
}

export function DualCard({ lab }) {
  const { dual, dualCars, params, claw, tearMode, method, phase, length, geom, base, inlay, wet, set } = lab;
  if (!dual) {
    return (
      <Card title="Modo dual · antiguo vs moderno" right={<Pill on={false} onPress={() => set.dual(true)} hint="Activar el modo dual">Activar</Pill>}>
        <Text style={st.intro}>
          El mismo ensayo en dos coches a la vez: un clásico de acero dulce más grueso frente a uno moderno de acero fino
          (o de aluminio, o con aletas de plástico). Qué raya, desgarra, punza o atraviesa cada uno, cuántos milímetros y qué daño deja.
        </Text>
      </Card>
    );
  }
  const rows = duel(params, claw, dualCars);
  const isCurrent = (r) => r.p.method === method && r.p.strike === (method === "puncion" && !!params.strike) && r.p.tear === (method === "rayado" && !!(claw && tearMode));
  const current = rows.find(isCurrent) || rows[0];
  const tool = { claw, geom, base, inlay, wet };
  const done = phase === "done";
  return (
    <Card title="Modo dual · antiguo vs moderno" right={<Pill on onPress={() => set.dual(false)} hint="Desactivar el modo dual">Desactivar</Pill>}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 14 }}>
        {dualCars.map((car, i) => (
          <View key={i} style={{ flexGrow: 1, flexBasis: 280 }}>
            <SubLabel style={{ marginTop: 0 }}>{i === 0 ? "Coche A" : "Coche B"}</SubLabel>
            <CarPicker value={car.id} onPick={(id) => set.dualCar(i, id)} />
            <View style={st.benchBox}>
              <Bench res={phase === "idle" ? null : current.res[i]} phase={phase} length={length} target={car} method={method} tool={tool} />
            </View>
            {done && (
              <View accessibilityLiveRegion="polite" style={{ marginTop: 8 }}>
                <Text style={[st.verdict, { color: current.res[i].vcol }]}>{current.res[i].verdict}</Text>
                <Text style={st.vsub}>{current.res[i].vsub}</Text>
                <DamageList rows={damageReport(current.res[i], car, { length })} />
              </View>
            )}
          </View>
        ))}
      </View>
      {!done && <Text style={st.hint}>{phase === "running" ? "Ensayando en los dos coches…" : "Pulsa ARAÑAR: el ensayo corre a la vez en los dos coches."}</Text>}
      <SubLabel>Qué hace esta herramienta en cada coche</SubLabel>
      <View style={{ flexDirection: "row", gap: 8, paddingHorizontal: 8, marginBottom: 2 }}>
        {dualCars.map((c) => <Text key={c.id} style={[st.cellD, { flex: 1 }]}>{c.name}</Text>)}
      </View>
      {rows.map((r) => <DuelRow key={r.id} row={r} cars={dualCars} current={r === current} />)}
      <Text style={st.hint}>misma herramienta, fuerza y largo · ◂ = el ensayo del banco · negrita = el que aguanta mejor</Text>
    </Card>
  );
}

const st = StyleSheet.create({
  intro: { fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 18 },
  benchBox: { backgroundColor: C.panel2, borderWidth: 1, borderColor: C.line, borderRadius: 14, paddingHorizontal: 4, paddingTop: 4 },
  verdict: { fontFamily: DISP8, fontSize: 18 },
  vsub: { fontFamily: MONO, fontSize: 11.5, color: C.dim, lineHeight: 16 },
  dRow: { flexDirection: "row", gap: 10, marginTop: 3 },
  dKey: { fontFamily: MONO, fontSize: 11, color: C.dimmer, width: 118 },
  dVal: { fontFamily: MONO, fontSize: 11, color: C.text, flex: 1 },
  hint: { fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 8, lineHeight: 15 },
  row: { borderTopWidth: 1, borderTopColor: C.line, paddingVertical: 7, paddingHorizontal: 8, borderRadius: 8 },
  mode: { fontFamily: DISP, fontSize: 13, color: C.text, marginBottom: 3 },
  cellV: { fontSize: 11.5 },
  cellD: { fontFamily: MONO, fontSize: 10.5, color: C.dimmer },
  who: { fontFamily: MONO, fontSize: 11, marginTop: 4 },
});
