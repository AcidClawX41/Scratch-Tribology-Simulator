import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import Slider from "@react-native-community/slider";
import Svg, { Path } from "react-native-svg";
import { C, DISP, DISP8, MONO, MONOB } from "../theme";

/* Primitivas de interfaz, gemelas de apps/desktop/src/components/ui.jsx. Sin estado propio. */

export function Card({ step, title, right, children, style }) {
  return (
    <View style={[s.card, style]}>
      {(title || right) && (
        <View style={s.cardHead}>
          <View style={s.cardTitleRow}>
            {step ? <View style={s.step}><Text style={s.stepTxt}>{step}</Text></View> : null}
            {title ? <Text style={s.cardTitle} accessibilityRole="header">{title}</Text> : null}
          </View>
          {right}
        </View>
      )}
      {children}
    </View>
  );
}

export const SubLabel = ({ children, style }) => <Text style={[s.subLabel, style]}>{String(children).toUpperCase()}</Text>;
export const Note = ({ children, style }) => <Text style={[s.note, style]}>{children}</Text>;

export function Pill({ on, onPress, children, icon, hint }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected: !!on }} accessibilityHint={hint}
      style={({ pressed }) => [s.pill, on && s.pillOn, pressed && s.pressed]}>
      {icon}
      <Text style={[s.pillTxt, { color: on ? C.bg : C.dim }]}>{children}</Text>
    </Pressable>
  );
}

/** Control segmentado (una sola opción activa). */
export function Segmented({ options, value, onChange, label, style }) {
  return (
    <View style={[s.seg, style]} accessibilityRole="radiogroup" accessibilityLabel={label}>
      {options.map((o) => {
        const on = value === o.id;
        return (
          <Pressable key={o.id} onPress={() => onChange(o.id)} accessibilityRole="radio" accessibilityState={{ checked: on }}
            style={({ pressed }) => [s.segBtn, on && s.segOn, pressed && s.pressed]}>
            <Text style={[s.segTxt, { color: on ? C.text : C.dim }]}>{o.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Ficha con ilustración (herramientas y materiales). width: porcentaje de la fila. */
export function Tile({ on, onPress, art, label, sub, artH = 52, width = "23%" }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected: !!on }} accessibilityLabel={sub ? `${label}, ${sub}` : label}
      style={({ pressed }) => [s.tile, { width }, on && s.tileOn, pressed && s.pressed]}>
      <View style={[s.tileArt, { height: artH }]}>{art}</View>
      <Text style={[s.tileLabel, { color: on ? C.text : C.dim }]} numberOfLines={2}>{label}</Text>
      {sub ? <Text style={s.tileSub} numberOfLines={1}>{sub}</Text> : null}
    </Pressable>
  );
}

/** Métrica con etiqueta en versalitas; sym (χ, φ…) se muestra tal cual para que no se confunda con una X. */
export function Metric({ label, sym, val, col }) {
  return (
    <View style={s.metric}>
      <Text style={s.metricLabel}>
        {String(label).toUpperCase()}{sym ? <Text style={s.metricSym}> {sym}</Text> : null}
      </Text>
      <Text style={[s.metricVal, { color: col || C.text }]}>{val}</Text>
    </View>
  );
}

/** Deslizador nativo con cabecera de valor. */
export function SliderRow({ title, hint, value, display, min, max, step, onChange, valueText }) {
  return (
    <View style={{ marginTop: 12 }}>
      <View style={s.sliderHead}>
        <Text style={s.sliderTitle}>
          {title}
          {hint ? <Text style={{ color: C.dimmer }}>{` ${hint}`}</Text> : null}
        </Text>
        <Text style={s.sliderVal}>{display}</Text>
      </View>
      <Slider
        style={{ width: "100%", height: 36 }}
        minimumValue={min} maximumValue={max} step={step} value={value} onValueChange={onChange}
        minimumTrackTintColor={C.rose} maximumTrackTintColor={C.line2} thumbTintColor={C.rose}
        accessibilityLabel={title} accessibilityValue={{ text: valueText || display }}
      />
    </View>
  );
}

export function IconButton({ on, onPress, label, children }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="switch" accessibilityState={{ checked: !!on }} accessibilityLabel={label} hitSlop={6}
      style={({ pressed }) => [s.iconBtn, on && { borderColor: C.line2 }, pressed && s.pressed]}>
      {children}
    </Pressable>
  );
}

/** Altavoz (activado / silenciado). */
export const SpeakerIcon = ({ on, color }) => (
  <Svg viewBox="0 0 24 24" width={18} height={18}>
    <Path d="M4 9v6h4l5 4V5L8 9H4z" fill={color} />
    {on
      ? <Path d="M16 9.5a4 4 0 0 1 0 5M18.5 7a7.5 7.5 0 0 1 0 10" stroke={color} strokeWidth={2} strokeLinecap="round" fill="none" />
      : <Path d="M17 9l5 6M22 9l-5 6" stroke={color} strokeWidth={2} strokeLinecap="round" fill="none" />}
  </Svg>
);

export const s = StyleSheet.create({
  card: {
    backgroundColor: C.panel, borderColor: C.line, borderWidth: 1, borderRadius: 20,
    padding: 15, marginBottom: 14,
  },
  cardHead: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 10, marginBottom: 12, flexWrap: "wrap" },
  cardTitleRow: { flexDirection: "row", alignItems: "center", gap: 9 },
  cardTitle: { fontFamily: DISP, fontSize: 15, color: C.text },
  step: { width: 26, height: 26, borderRadius: 9, backgroundColor: C.panel3, borderWidth: 1, borderColor: C.line2, alignItems: "center", justifyContent: "center" },
  stepTxt: { fontFamily: MONO, fontSize: 12.5, color: C.gold },
  subLabel: { fontFamily: MONO, fontSize: 10.5, letterSpacing: 1.2, color: C.dimmer, marginTop: 14, marginBottom: 8 },
  note: { fontFamily: MONO, fontSize: 10.5, color: C.dimmer, lineHeight: 16, marginTop: 7 },
  pill: {
    flexDirection: "row", alignItems: "center", gap: 6, paddingVertical: 8, paddingHorizontal: 11,
    borderRadius: 11, borderWidth: 1, backgroundColor: C.panel2, borderColor: C.line,
  },
  pillOn: { backgroundColor: C.rose, borderColor: C.rose },
  pillTxt: { fontFamily: DISP, fontSize: 12.5 },
  pressed: { opacity: 0.75, transform: [{ scale: 0.97 }] },
  seg: { flexDirection: "row", flexWrap: "wrap", gap: 4, backgroundColor: C.bg, borderColor: C.line, borderWidth: 1, borderRadius: 14, padding: 4, alignSelf: "flex-start" },
  segBtn: { paddingVertical: 8, paddingHorizontal: 12, borderRadius: 10 },
  segOn: { backgroundColor: C.panel3, borderWidth: 1, borderColor: C.line2 },
  segTxt: { fontFamily: DISP, fontSize: 12.5 },
  tile: {
    alignItems: "center", gap: 4, paddingVertical: 8, paddingHorizontal: 4, borderRadius: 14,
    backgroundColor: C.panel2, borderWidth: 1, borderColor: C.line,
  },
  tileOn: { borderColor: C.rose, backgroundColor: C.panel3 },
  tileArt: { width: "100%", alignItems: "center", justifyContent: "center", overflow: "hidden", borderRadius: 9 },
  tileLabel: { fontFamily: DISP, fontSize: 11.5, textAlign: "center", lineHeight: 14 },
  tileSub: { fontFamily: MONO, fontSize: 9.5, color: C.dimmer },
  metric: { backgroundColor: C.panel2, borderColor: C.line, borderWidth: 1, borderRadius: 12, paddingVertical: 9, paddingHorizontal: 11, width: "48.5%" },
  metricLabel: { fontFamily: MONO, fontSize: 9, color: C.dimmer, letterSpacing: 1 },
  metricSym: { fontFamily: MONO, fontSize: 11, letterSpacing: 0, color: C.dim },
  metricVal: { fontFamily: MONO, fontSize: 13.5, marginTop: 4 },
  sliderHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  sliderTitle: { fontFamily: MONO, fontSize: 12, color: C.dim },
  sliderVal: { fontFamily: MONOB, fontSize: 14, color: C.rose },
  iconBtn: {
    flexDirection: "row", alignItems: "center", gap: 7, paddingVertical: 8, paddingHorizontal: 11,
    borderRadius: 12, borderWidth: 1, borderColor: C.line, backgroundColor: C.panel,
  },
  wrapRow: { flexDirection: "row", flexWrap: "wrap", gap: 7 },
  tiles: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  previewArt: {
    backgroundColor: C.panel2, borderColor: C.line, borderWidth: 1, borderRadius: 16, padding: 6,
    alignItems: "center", justifyContent: "center", overflow: "hidden",
  },
  h1: { fontFamily: DISP8, fontSize: 28, color: C.text },
});
