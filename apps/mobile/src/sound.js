/* Efectos de sonido y vibración en móvil. Los sonidos son los mismos de @sts/core (sfx.js),
   prerenderizados a WAV con scripts/render-sfx.mjs y reproducidos con expo-audio.
   - iOS: respetan el interruptor de silencio y se mezclan con la música del usuario (no la cortan).
   - Un solo interruptor "efectos" activa o silencia sonido y vibración.
   Pendiente (ROADMAP): recordar la preferencia entre sesiones. */
import { useCallback, useEffect, useRef, useState } from "react";
import { Platform } from "react-native";
import { createAudioPlayer, setAudioModeAsync } from "expo-audio";
import * as Haptics from "expo-haptics";
import { SFX_FILES } from "./sfxAssets";

const players = new Map();
let modeSet = false;

function player(id) {
  let p = players.get(id);
  if (!p && SFX_FILES[id]) { p = createAudioPlayer(SFX_FILES[id]); players.set(id, p); }
  return p;
}

// Vibración que acompaña a cada efecto (Taptic Engine en iPhone; vibrador en Android).
const { ImpactFeedbackStyle: I, NotificationFeedbackType: N } = Haptics;
const HAPTIC = {
  tap: () => Haptics.selectionAsync(), on: () => Haptics.selectionAsync(), off: () => Haptics.selectionAsync(), drip: () => Haptics.selectionAsync(),
  slide: () => Haptics.impactAsync(I.Soft), squeak: () => Haptics.impactAsync(I.Soft), "skin-rub": () => Haptics.impactAsync(I.Soft), press: () => Haptics.impactAsync(I.Soft),
  "scratch-soft": () => Haptics.impactAsync(I.Light), "scratch-wood": () => Haptics.impactAsync(I.Light), "skin-cut": () => Haptics.impactAsync(I.Medium),
  "scratch-metal": () => Haptics.impactAsync(I.Rigid), "scratch-glass": () => Haptics.impactAsync(I.Rigid), "scratch-deep": () => Haptics.impactAsync(I.Heavy),
  pierce: () => Haptics.impactAsync(I.Medium), inject: () => Haptics.impactAsync(I.Medium), "pierce-solid": () => Haptics.impactAsync(I.Heavy),
  "pierce-brittle": () => Haptics.impactAsync(I.Rigid), breakthrough: () => Haptics.impactAsync(I.Heavy),
  shatter: () => Haptics.notificationAsync(N.Warning),
  snap: () => Haptics.notificationAsync(N.Error), badge: () => Haptics.notificationAsync(N.Success),
};

/** Reproduce un efecto por id (ver SFX_IDS) con su vibración. Si el sistema falla, no hace nada. */
export function playSfx(id, volume = 0.7) {
  try {
    if (!modeSet) {
      modeSet = true;
      if (Platform.OS === "ios") setAudioModeAsync({ interruptionMode: "mixWithOthers", playsInSilentMode: false }).catch(() => {});
    }
    const p = player(id);
    if (p) { p.volume = volume; p.seekTo(0).catch(() => {}); p.play(); }
    const h = HAPTIC[id];
    if (h) h().catch(() => {});
  } catch { /* sin audio: la app sigue funcionando en silencio */ }
}

/** Estado de los efectos: [activados, alternar, reproducir-si-activados]. */
export function useSound() {
  const [on, setOn] = useState(true);
  const onRef = useRef(on);   // un sonido diferido (impacto, fanfarria) respeta un silencio posterior
  onRef.current = on;
  const toggle = useCallback(() => {
    const next = !onRef.current;
    onRef.current = next;
    setOn(next);
    playSfx(next ? "on" : "off", 0.6);   // confirmación en los dos sentidos
  }, []);
  const play = useCallback((id, volume) => { if (onRef.current) playSfx(id, volume); }, []);
  useEffect(() => () => { players.forEach((p) => p.remove()); players.clear(); }, []);
  return [on, toggle, play];
}
