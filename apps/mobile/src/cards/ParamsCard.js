import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { C, TYPES, fToT, tToF, fmtF, fmtJ, passDepthFactor, tearLeverage } from "@sts/core";
import { DISP, MONO, MONOB } from "../theme";
import { Card, Segmented, SubLabel, Note, SliderRow } from "../components/ui";

export function ParamsCard({ lab }) {
  const { claw, method, strike, force, length, passes, type, tearMode, tool, strikeJ, maxF, set } = lab;
  const setForce = (t) => { const f = tToF(t); set.force(f < 10 ? Math.round(f * 10) / 10 : Math.round(f)); };
  return (
    <Card step="3" title="Parámetros del ensayo">
      <SliderRow title="Fuerza" hint="(escala log)" display={`${fmtF(force)} N`} value={fToT(force)} min={0} max={1} step={0.004}
        onChange={setForce} valueText={`${fmtF(force)} newtons`} />
      <View style={st.scale}>
        {["0,5 N", "roce humano", "zarpazo", "2000 N"].map((x) => <Text key={x} style={st.scaleTxt}>{x}</Text>)}
      </View>
      <Pressable onPress={() => set.force(maxF.force)} accessibilityRole="button" style={({ pressed }) => [st.maxBtn, pressed && { opacity: 0.75 }]}>
        <Text style={st.maxTxt}>⤓ Usar fuerza MÁX. {maxF.label} · ~{maxF.force} N</Text>
        <Text style={st.maxSub}>{maxF.note}</Text>
      </Pressable>

      <SubLabel>Método</SubLabel>
      <Segmented label="Método" value={method} onChange={set.method}
        options={[{ id: "rayado", label: "Rayado (arrastre)" }, { id: "puncion", label: "Punción / inyección" }]} />
      {method === "puncion" ? (
        <>
          <Note>
            Penetración vertical, sin arrastre: la punta entra recta. {claw && claw.fang ? "El colmillo, además, es hueco → inyecta veneno en el tejido." : "Solo los colmillos inyectan; el resto hace punción seca."} Nada se hunde más que su propia {claw ? (claw.fang ? "aguja" : "garra") : "uña libre"}: aquí, ≤ {tool.reach} mm.
          </Note>
          <SubLabel>Golpe</SubLabel>
          <Segmented label="Golpe" value={strike ? "impacto" : "estatico"} onChange={(v) => set.strike(v === "impacto")}
            options={[{ id: "estatico", label: "Estático" }, { id: "impacto", label: "💥 Impacto (golpe)" }]} />
          <Note>{strike
            ? `Golpe dinámico: ½·m·v² ≈ ${fmtJ(strikeJ)} J (${tool.strike.v} m/s, ${tool.strike.m} kg efectivos ${claw ? "por garra" : "del dedo"}) + el trabajo del empuje = trabajo de penetración.`
            : "Empuje cuasi-estático (equilibrio de fuerzas): conservador. Cambia a Impacto para una mordedura, patada o zarpazo real."}</Note>
        </>
      ) : (
        <>
          <SliderRow title="Longitud" display={`${length} mm`} value={length} min={5} max={60} step={1} onChange={(v) => set.length(Math.round(v))} valueText={`${length} milímetros`} />
          <SliderRow title="Pasadas" hint="(mismo surco)" display={`${passes}×`} value={passes} min={1} max={100} step={1} onChange={(v) => set.passesSlider(Math.round(v))} valueText={`${passes} pasadas`} />
          <View style={st.presets}>
            {[1, 5, 20, 50, 100].map((n) => (
              <Pressable key={n} onPress={() => set.passes(n)} accessibilityRole="button" accessibilityState={{ selected: passes === n }}
                style={[st.preset, passes === n && { backgroundColor: C.rose, borderColor: C.rose }]}>
                <Text style={[st.presetTxt, { color: passes === n ? C.bg : C.dim }]}>{n}×</Text>
              </Pressable>
            ))}
          </View>
          {passes > 1 && <Note>Arañar {passes} veces en la misma línea profundiza ×{passDepthFactor(passes).toFixed(1)} (sublineal: cada pasada arranca menos). Si la herramienta no marca ni una vez, mil pasadas tampoco: solo se desgasta la punta.</Note>}
          <SubLabel>Tipo de arañazo</SubLabel>
          <Segmented label="Tipo de arañazo" value={type.id} onChange={(id) => set.type(TYPES.find((t) => t.id === id))} options={TYPES.map((t) => ({ id: t.id, label: t.name }))} />
          {claw && (
            <>
              <SubLabel>Modo de garra</SubLabel>
              <Segmented label="Modo de garra" value={tearMode ? "desgarro" : "arrastre"} onChange={(v) => set.tearMode(v === "desgarro")}
                options={[{ id: "arrastre", label: "Arrastre" }, { id: "desgarro", label: "🪝 Desgarro (palanca)" }]} />
              <Note>{tearMode
                ? `Gancho + palanca: la garra curva rasga en vez de arrastrar. Ventaja mecánica ×${tearLeverage(claw).toFixed(1)} en la punta.`
                : "Arrastre liso (como una uña). Cambia a Desgarro para que la curvatura haga palanca."}</Note>
            </>
          )}
        </>
      )}
    </Card>
  );
}

const st = StyleSheet.create({
  scale: { flexDirection: "row", justifyContent: "space-between", marginTop: -2 },
  scaleTxt: { fontFamily: MONO, fontSize: 9.5, color: C.dimmer },
  maxBtn: { marginTop: 12, paddingVertical: 10, paddingHorizontal: 12, borderRadius: 12, borderWidth: 1, borderColor: C.gold, backgroundColor: C.panel2 },
  maxTxt: { fontFamily: DISP, fontSize: 13, color: C.gold, textAlign: "center" },
  maxSub: { fontFamily: MONO, fontSize: 10, color: C.dimmer, marginTop: 3, textAlign: "center", lineHeight: 14 },
  presets: { flexDirection: "row", gap: 6, marginTop: 8 },
  preset: { flex: 1, paddingVertical: 8, borderRadius: 10, borderWidth: 1, borderColor: C.line, backgroundColor: C.panel2, alignItems: "center" },
  presetTxt: { fontFamily: MONOB, fontSize: 12 },
});
