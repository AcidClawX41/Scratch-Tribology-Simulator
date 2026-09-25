import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { C, BADGES } from "@sts/core";
import { MONO } from "../theme";
import { Card } from "../components/ui";

export function BadgesCard({ lab }) {
  const { badges, log } = lab;
  return (
    <Card title="Logros de laboratorio" right={<Text style={st.count}>{badges.size}/{BADGES.length}</Text>}>
      <View style={st.chips}>
        {BADGES.map((b) => {
          const got = badges.has(b.id);
          return (
            <Text key={b.id} style={[st.badge, got ? st.got : null]} accessibilityLabel={`${b.t}: ${got ? "conseguido" : "pendiente"}`}>
              {got ? "★ " : "○ "}{b.t}
            </Text>
          );
        })}
      </View>
      {log.length > 0 && (
        <>
          <Text style={st.logHead}>CUADERNO · ÚLTIMOS ENSAYOS</Text>
          {log.map((e, i) => (
            <View key={e.id} style={[st.logRow, i > 0 && { borderTopWidth: 1, borderTopColor: C.line }]}>
              <Text style={st.logTool} numberOfLines={1}>{e.tool} → {e.tgt}</Text>
              <Text style={[st.logVerdict, { color: e.col }]}>{e.verdict}</Text>
            </View>
          ))}
        </>
      )}
    </Card>
  );
}

const st = StyleSheet.create({
  count: { fontFamily: MONO, fontSize: 11.5, color: C.gold },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 7 },
  badge: {
    fontFamily: MONO, fontSize: 11, paddingHorizontal: 9, paddingVertical: 5, borderRadius: 9, borderWidth: 1, overflow: "hidden",
    backgroundColor: C.panel2, color: C.dimmer, borderColor: C.line,
  },
  got: { backgroundColor: C.gold, color: C.bg, borderColor: C.gold },
  logHead: { fontFamily: MONO, fontSize: 10.5, letterSpacing: 1.2, color: C.dimmer, marginTop: 16, marginBottom: 6 },
  logRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 10, paddingVertical: 7 },
  logTool: { fontFamily: MONO, fontSize: 11.5, color: C.dim, flex: 1 },
  logVerdict: { fontFamily: MONO, fontSize: 11.5, flexShrink: 0 },
});
