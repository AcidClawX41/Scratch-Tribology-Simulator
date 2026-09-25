import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { C, GEOMS, CLAWS, INLAYS, compute, fmtF, fmtP, fmtDepth } from "@sts/core";
import { DISP, MONO } from "../theme";
import { Card } from "../components/ui";
import { ClawIcon, NailFront } from "../components/art";

function Row({ icon, name, verdict, vcol, meta, sev, on, onPress }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected: !!on }} accessibilityHint="Usar esta herramienta"
      style={({ pressed }) => [st.row, on && st.rowOn, pressed && { opacity: 0.75 }]}>
      <View style={{ width: 28, height: 40 }}>{icon}</View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <View style={st.head}>
          <Text style={st.name} numberOfLines={1}>{name}</Text>
          <Text style={[st.verdict, { color: vcol }]} numberOfLines={1}>{verdict}</Text>
        </View>
        <Text style={st.meta}>{meta}</Text>
        <View style={st.track}><View style={{ width: `${Math.max(4, sev * 100)}%`, height: "100%", backgroundColor: vcol, borderRadius: 5 }} /></View>
      </View>
    </Pressable>
  );
}

export function CompareCard({ lab }) {
  const { claw, base, inlay, target, force, params, tearMode, set } = lab;
  if (claw) {
    const rows = CLAWS.map((c) => ({ c, ...compute({ ...params, claw: c, tear: tearMode }) })).sort((a, b) => b.pNominal - a.pNominal);
    return (
      <Card title="Comparar garras y colmillos">
        <Text style={st.intro}>
          Misma fuerza ({fmtF(force)} N) sobre {target.name}{inlay.id !== "none" ? ` con ${inlay.short}` : ""}. Queratina (Mohs ~2,5-3) y dentina: lo que cambia es el afilado (R, α), la curvatura y la gema de la punta.
        </Text>
        {rows.map((r) => (
          <Row key={r.c.id} on={r.c.id === claw.id} onPress={() => set.claw(r.c)} name={r.c.name} verdict={r.verdict} vcol={r.vcol} sev={r.sev}
            icon={<ClawIcon claw={r.c} inlay={inlay} tipColor={r.vcol} uid="cmp" width={28} height={40} label={false} />}
            meta={`${r.area.toFixed(3)} mm² · α ${r.alphaDeg}° · ${fmtP(r.pNominal)} MPa nom.${r.depthUm > 0.1 ? ` · ${fmtDepth(r.depthUm)}` : ""}`} />
        ))}
        <Text style={st.foot}>barra = severidad · toca una fila para usar esa herramienta</Text>
      </Card>
    );
  }
  const rows = GEOMS.map((g) => ({ g, ...compute({ ...params, geom: g, inlay: INLAYS[0], claw: null }) })).sort((a, b) => b.pNominal - a.pNominal);
  return (
    <Card title="Comparativa por forma">
      <Text style={st.intro}>
        Misma fuerza ({fmtF(force)} N) y material ({base.name}) sobre {target.name}. Solo cambia la forma → el área de la punta → la presión, el desgaste y el rayado. (Sin incrustación, para aislar la forma.)
      </Text>
      {rows.map((r) => (
        <Row key={r.g.id} on={r.g.id === lab.geom.id} onPress={() => set.geom(r.g)} name={r.g.name} verdict={r.verdict} vcol={r.vcol} sev={r.sev}
          icon={<NailFront geom={r.g} base={base} inlay={INLAYS[0]} uid="cmp" width={24} height={40} label={false} />}
          meta={`${r.area.toFixed(2)} mm² · ${fmtP(r.pNominal)} MPa nom. · desgaste ${r.wearIdx}${r.depthUm > 0.1 ? ` · ${fmtDepth(r.depthUm)}` : ""}`} />
      ))}
      <Text style={st.foot}>barra = severidad del surco · toca una fila para usar esa forma</Text>
    </Card>
  );
}

const st = StyleSheet.create({
  intro: { fontFamily: MONO, fontSize: 11, color: C.dim, lineHeight: 17, marginBottom: 4 },
  row: { flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 9, paddingHorizontal: 6, borderRadius: 12, borderTopWidth: 1, borderTopColor: C.line },
  rowOn: { backgroundColor: C.panel3, borderWidth: 1, borderColor: C.line2 },
  head: { flexDirection: "row", justifyContent: "space-between", alignItems: "baseline", gap: 6 },
  name: { fontFamily: DISP, fontSize: 13, color: C.text, flexShrink: 1 },
  verdict: { fontFamily: MONO, fontSize: 10.5, flexShrink: 1, textAlign: "right" },
  meta: { fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 2, marginBottom: 5 },
  track: { height: 6, backgroundColor: C.panel2, borderRadius: 5, overflow: "hidden" },
  foot: { fontFamily: MONO, fontSize: 9.5, color: C.dimmer, marginTop: 8 },
});
