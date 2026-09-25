import React, { useEffect, useRef } from "react";
import { Animated, Easing, View } from "react-native";
import Svg, { G, Defs, Rect, Ellipse, Line, Circle, LinearGradient, RadialGradient, Stop } from "react-native-svg";
import { C, surfaceArt, grooveArt, punctureArt, clawArt, nailSideArt, MATERIAL_LOOK, darken } from "@sts/core";
import { renderNodes, memoArt } from "./Scene";

/* ════════ BANCO DE ENSAYO ════════
   Gemelo de apps/desktop/src/components/Bench.jsx: losa con la textura real del material, la
   herramienta dibujada y la marca que deja. Rayado: la punta avanza y el surco se revela con ella.
   Punción: baja e impacta. Animated sustituye a las transiciones CSS. */
const W = 360, TOP = 104, FACE = 38, GY = TOP + FACE * 0.46, CX = 180;
const AG = Animated.createAnimatedComponent(G);
const ALine = Animated.createAnimatedComponent(Line);
const AEllipse = Animated.createAnimatedComponent(Ellipse);

export function Bench({ res, phase, length, target, method, tool }) {
  const { claw, geom, base, inlay, wet } = tool;
  const puncture = res ? res.puncture : method === "puncion";
  const x1 = 46, len = 70 + (length / 60) * 222, x2 = x1 + len;
  const look = MATERIAL_LOOK[target.id];
  const surf = memoArt(`bench:${target.id}`, () => surfaceArt(target.id, { x: 12, y: TOP, w: W - 24, h: FACE, uid: "bench", rx: 5 }));
  const art = memoArt(`btool:${claw ? claw.id : `${geom.id}:${base.id}`}:${inlay.id}:${wet}`,
    () => (claw ? clawArt(claw, { orient: "down", inlay, uid: "bt" }) : nailSideArt({ geom, base, inlay, wet, uid: "bt" })));
  const scale = claw ? 0.56 : 0.78;
  const groove = res && !res.puncture ? grooveArt(target.id, res, { x1, x2, y: GY, uid: "bg" }) : null;
  const hole = res && res.puncture ? punctureArt(target.id, res, { cx: CX, cy: GY, uid: "bp", fangs: !!(claw && claw.fang) }) : null;

  // t: 0 = herramienta en reposo · 1 = final del ensayo · lift: tras la punción, la punta se retira un poco
  const t = useRef(new Animated.Value(0)).current;
  const lift = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (phase === "idle") { t.stopAnimation(); t.setValue(0); lift.setValue(0); return; }
    if (phase === "running") {
      t.setValue(0); lift.setValue(0);
      Animated.timing(t, {
        toValue: 1, duration: puncture ? 900 : 1100, useNativeDriver: false,
        easing: puncture ? Easing.bezier(0.6, 0, 0.9, 0.4) : Easing.bezier(0.45, 0.05, 0.25, 1),
      }).start();
    }
    if (phase === "done" && puncture) Animated.timing(lift, { toValue: 1, duration: 500, useNativeDriver: false, easing: Easing.bezier(0.2, 0.8, 0.3, 1) }).start();
  }, [phase, res]);

  const toolX = puncture ? CX : t.interpolate({ inputRange: [0, 1], outputRange: [x1, x2] });
  const toolY = puncture
    ? Animated.add(t.interpolate({ inputRange: [0, 1], outputRange: [GY - 34, GY + 1.5] }), lift.interpolate({ inputRange: [0, 1], outputRange: [0, -14.5] }))
    : GY;
  const shadowY = puncture
    ? Animated.add(t.interpolate({ inputRange: [0, 1], outputRange: [34, 2] }), lift.interpolate({ inputRange: [0, 1], outputRange: [0, 13] }))
    : 2;
  const dash = groove ? t.interpolate({ inputRange: [0, 1], outputRange: [groove.length, 0] }) : 0;
  const reveal = t.interpolate({ inputRange: [0, puncture ? 0.78 : 0.85, 1], outputRange: [0, 0, 1] });
  const defs = [...surf.defs, ...(hole ? hole.defs : []), ...art.defs];

  return (
    <View style={{ width: "100%", aspectRatio: W / 170 }}
      accessible accessibilityRole="image" accessibilityLabel={res && phase === "done" ? `Banco: ${res.verdict}` : `Banco listo: ${target.name}`}>
      <Svg viewBox={`0 0 ${W} 170`} width="100%" height="100%">
        <Defs>
          {renderNodes(defs, "d")}
          <LinearGradient id="bench-face" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={darken(look.lo, 0.25)} /><Stop offset="1" stopColor={darken(look.lo, 0.55)} />
          </LinearGradient>
          <RadialGradient id="bench-shadow"><Stop offset="0" stopColor="#000" stopOpacity="0.45" /><Stop offset="1" stopColor="#000" stopOpacity="0" /></RadialGradient>
          <RadialGradient id="bench-floor" cx="0.5" cy="0.2" r="0.7"><Stop offset="0" stopColor="#000" stopOpacity="0.35" /><Stop offset="1" stopColor="#000" stopOpacity="0" /></RadialGradient>
        </Defs>
        <Ellipse cx={W / 2} cy={TOP + FACE + 18} rx={W / 2 - 10} ry="12" fill="url(#bench-floor)" />
        <Rect x="12" y={TOP + FACE - 6} width={W - 24} height="22" rx="5" fill="url(#bench-face)" />
        {renderNodes(surf.body, "s")}
        <Rect x="12" y={TOP} width={W - 24} height={FACE} rx="5" fill="none" stroke="rgba(255,255,255,0.12)" />
        {groove && groove.lines.map((n, i) => {
          const { key, ...a } = n.attrs;
          return <ALine key={i} {...a} strokeDashoffset={dash} />;
        })}
        {groove && <AG opacity={reveal}>{renderNodes(groove.extras, "e")}</AG>}
        {hole && <AG opacity={reveal}>{renderNodes(hole.body, "h")}</AG>}
        <AG x={toolX} y={toolY}>
          <AEllipse cx="0" cy={shadowY} rx="14" ry="3.2" fill="url(#bench-shadow)" />
          <G transform={`scale(${scale}) translate(${-art.tip.x} ${-art.tip.y})`}>{renderNodes(art.body, "t")}</G>
        </AG>
        {res && res.toolWorn && phase === "done" && <Circle cx={puncture ? CX : x2} cy={GY - 3} r="4" fill={C.coral} opacity={0.85} />}
      </Svg>
    </View>
  );
}
