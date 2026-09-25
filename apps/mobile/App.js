import React, { useCallback, useState } from "react";
import { View, Text, ScrollView, Pressable, StyleSheet, StatusBar, useWindowDimensions } from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import * as SplashScreen from "expo-splash-screen";
import { useFonts } from "expo-font";
import { Syne_600SemiBold, Syne_700Bold, Syne_800ExtraBold } from "@expo-google-fonts/syne";
import { SpaceMono_400Regular, SpaceMono_700Bold } from "@expo-google-fonts/space-mono";

import { C, CLAWS, FUNDAMENTOS, FUNDAMENTOS_NOTE, LICENSE_NOTE } from "@sts/core";
import { DISP, DISP8, MONO, MONOB } from "./src/theme";
import { IconButton, SpeakerIcon, s as ui } from "./src/components/ui";
import { ClawIcon } from "./src/components/art";
import { ToolCard } from "./src/cards/ToolCard";
import { TargetCard } from "./src/cards/TargetCard";
import { ParamsCard } from "./src/cards/ParamsCard";
import { ResultCard } from "./src/cards/ResultCard";
import { CompareCard } from "./src/cards/CompareCard";
import { DualCard } from "./src/cards/DualCard";
import { BadgesCard } from "./src/cards/BadgesCard";
import { useLab } from "./src/hooks/useLab";
import { useSound } from "./src/sound";

SplashScreen.preventAutoHideAsync().catch(() => {});

/* ════════ APP ════════
   Una columna en el iPhone; dos (configuración | banco y resultados) en el iPad apaisado. */
export default function App() {
  const [fontsLoaded] = useFonts({ Syne_600SemiBold, Syne_700Bold, Syne_800ExtraBold, SpaceMono_400Regular, SpaceMono_700Bold });
  const onLayoutRoot = useCallback(async () => { if (fontsLoaded) await SplashScreen.hideAsync().catch(() => {}); }, [fontsLoaded]);
  if (!fontsLoaded) return <View style={{ flex: 1, backgroundColor: C.bg }} />;
  return (
    <SafeAreaProvider>
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} onLayout={onLayoutRoot}>
        <StatusBar barStyle="light-content" backgroundColor={C.bg} />
        <Lab />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

function RunButton({ running, onPress }) {
  return (
    <Pressable onPress={onPress} disabled={running} accessibilityRole="button" accessibilityState={{ disabled: running, busy: running }}
      accessibilityLabel={running ? "Ensayando" : "Arañar: correr el ensayo"} style={({ pressed }) => [{ marginBottom: 14 }, pressed && { opacity: 0.85 }]}>
      {running
        ? <View style={[st.run, { backgroundColor: C.panel2 }]}><Text style={[st.runTxt, { color: C.dim }]}>Ensayando…</Text></View>
        : <LinearGradient colors={[C.rose, C.gold]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={st.run}><Text style={[st.runTxt, { color: "#2a0e1e" }]}>▸ ARAÑAR</Text></LinearGradient>}
    </Pressable>
  );
}

function Lab() {
  const [soundOn, toggleSound, play] = useSound();
  const lab = useLab(play);
  const [showModel, setShowModel] = useState(false);
  const { width } = useWindowDimensions();
  const wide = width >= 900;
  const running = lab.phase === "running";

  const config = (<><ToolCard lab={lab} /><TargetCard lab={lab} /><ParamsCard lab={lab} /></>);
  const results = (<><RunButton running={running} onPress={lab.run} /><ResultCard lab={lab} /><DualCard lab={lab} /><CompareCard lab={lab} /><BadgesCard lab={lab} /></>);

  return (
    <ScrollView style={{ flex: 1, backgroundColor: C.bg }} keyboardShouldPersistTaps="handled"
      contentContainerStyle={[st.content, { maxWidth: wide ? 1240 : 600 }]}>
      <View style={st.top}>
        <View style={{ flexDirection: "row", alignItems: "center", gap: 10, flex: 1, minWidth: 0 }}>
          <View style={[ui.previewArt, { width: 44, height: 44, padding: 3, borderRadius: 13 }]}>
            <ClawIcon claw={CLAWS[0]} uid="logo" width={32} height={38} label={false} />
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <Text style={st.kicker} numberOfLines={1}>SCRATCH TRIBOLOGY SIMULATOR</Text>
            <Text style={ui.h1} accessibilityRole="header">¿Qué raya a qué?</Text>
          </View>
        </View>
      </View>
      <View style={st.actions}>
        <IconButton on={showModel} onPress={() => setShowModel((x) => !x)} label={showModel ? "Ocultar fundamentos físicos" : "Ver fundamentos físicos"}>
          <Text style={[st.btnTxt, showModel && { color: C.mint }]}>∑ Fundamentos</Text>
        </IconButton>
        <IconButton on={soundOn} onPress={toggleSound} label={soundOn ? "Sonido y vibración activados: toca para silenciar" : "Sonido y vibración desactivados: toca para activar"}>
          <SpeakerIcon on={soundOn} color={soundOn ? C.mint : C.dim} />
          <Text style={[st.btnTxt, soundOn && { color: C.mint }]}>{soundOn ? "Sonido" : "Silencio"}</Text>
        </IconButton>
      </View>

      {showModel && (
        <View style={[ui.card, { padding: 14 }]}>
          <Text style={st.modelTitle}>Fundamentos físicos</Text>
          {FUNDAMENTOS.map(([k, v]) => <Text key={k} style={st.modelLine}>· <Text style={{ color: C.text, fontFamily: MONOB }}>{k}</Text>: {v}</Text>)}
          <Text style={[st.modelLine, { color: C.dimmer, marginTop: 6 }]}>{FUNDAMENTOS_NOTE}</Text>
        </View>
      )}

      {wide
        ? <View style={{ flexDirection: "row", gap: 16, alignItems: "flex-start" }}>
            <View style={{ flex: 5, minWidth: 0 }}>{config}</View>
            <View style={{ flex: 6, minWidth: 0 }}>{results}</View>
          </View>
        : <>{config}{results}</>}

      <Text style={st.footer}>
        Modelo educativo v2 con datos publicados: nanoindentación de uña (E ≈ 2,9 GPa), barniz de coche (0,2–0,4 GPa), punción de piel in vivo (Davis 2004), colmillos de víbora (Estrada 2026) y agarre de rapaces (Sustaita &amp; Hertel 2010). Fuerzas y golpes de animales: estimaciones. Mohs↔Vickers no es lineal.{"\n"}{LICENSE_NOTE}
      </Text>
    </ScrollView>
  );
}

const st = StyleSheet.create({
  content: { padding: 14, paddingBottom: 48, width: "100%", alignSelf: "center" },
  top: { flexDirection: "row", alignItems: "center", marginBottom: 10 },
  kicker: { fontFamily: MONO, fontSize: 10.5, letterSpacing: 2, color: C.mint },
  actions: { flexDirection: "row", gap: 8, marginBottom: 14, flexWrap: "wrap" },
  btnTxt: { fontFamily: MONO, fontSize: 12, color: C.dim },
  modelTitle: { fontFamily: DISP, fontSize: 15, color: C.text, marginBottom: 8 },
  modelLine: { fontFamily: MONO, fontSize: 11.5, color: C.dim, lineHeight: 18, marginBottom: 4 },
  run: { paddingVertical: 16, borderRadius: 16, alignItems: "center" },
  runTxt: { fontFamily: DISP8, fontSize: 18, letterSpacing: 0.5 },
  footer: { fontFamily: MONO, fontSize: 10, color: C.dimmer, lineHeight: 15, marginTop: 4 },
});
