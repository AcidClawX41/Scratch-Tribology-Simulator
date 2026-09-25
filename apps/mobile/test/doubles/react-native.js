/* Doble mínimo de React Native para la prueba de humo (test/smoke.mjs): comprueba lo que RN exige en tiempo de ejecución. */
import React from "react";
import { host, checkText } from "./host.js";
export const View = host("View");
export const Text = host("Text", true);
export const ScrollView = host("ScrollView");
export const StatusBar = host("StatusBar");
export function Pressable({ style, children, ...rest }) {
  const st = typeof style === "function" ? style({ pressed: true }) : style;   // evalúa también el estilo "pulsado"
  const kids = typeof children === "function" ? children({ pressed: false }) : children;
  checkText("Pressable", kids);
  return React.createElement("Pressable", { ...rest, style: st }, kids);
}
export const StyleSheet = { create: (x) => x, hairlineWidth: 1, absoluteFill: {} };
export const Platform = { OS: "ios", select: (o) => (o.ios ?? o.default) };
export const useWindowDimensions = () => ({ width: globalThis.__WIDTH__ || 390, height: 844, scale: 3, fontScale: 1 });
class Value {
  constructor(v) { this.v = v; }
  setValue(v) { this.v = v; }
  stopAnimation() {}
  interpolate({ inputRange, outputRange }) {
    if (inputRange.length !== outputRange.length) throw new Error("interpolate: rangos de distinta longitud");
    for (let i = 1; i < inputRange.length; i++) if (inputRange[i] < inputRange[i - 1]) throw new Error("interpolate: inputRange no creciente");
    return { __interp: [inputRange, outputRange] };
  }
}
export const Animated = {
  Value,
  timing: (v, cfg) => { if (typeof cfg.useNativeDriver !== "boolean") throw new Error("Animated.timing sin useNativeDriver"); return { start: (cb) => { v.setValue(cfg.toValue); if (cb) cb({ finished: true }); } }; },
  createAnimatedComponent: (C) => C,
  add: (a, b) => { for (const v of [a, b]) if (v == null || (typeof v !== "number" && !v.__interp)) throw new Error("Animated.add con un valor no animable"); return { __add: [a, b] }; },
};
export const Easing = { bezier: (...a) => { if (a.length !== 4) throw new Error("Easing.bezier necesita 4 valores"); return (t) => t; } };
