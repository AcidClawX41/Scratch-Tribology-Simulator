/* Dobles de los módulos Expo usados por la app (audio, vibración, fuentes, degradado, splash, safe area, slider). */
import { host } from "./host.js";
export const LinearGradient = host("ExpoLinearGradient");
export const preventAutoHideAsync = () => Promise.resolve(); export const hideAsync = () => Promise.resolve();
export const useFonts = () => [true];
export const Syne_600SemiBold = 1, Syne_700Bold = 2, Syne_800ExtraBold = 3, SpaceMono_400Regular = 4, SpaceMono_700Bold = 5;
export const SafeAreaProvider = host("SafeAreaProvider"), SafeAreaView = host("SafeAreaView");
export const played = [];
export function createAudioPlayer(src) {
  if (src === undefined) throw new Error("createAudioPlayer sin fuente");
  return { volume: 1, play() { played.push(src); }, seekTo: () => Promise.resolve(), remove() {} };
}
export const setAudioModeAsync = (m) => { if (!["mixWithOthers", "doNotMix", "duckOthers"].includes(m.interruptionMode)) throw new Error("interruptionMode inválido"); return Promise.resolve(); };
export const haptics = [];
export const ImpactFeedbackStyle = { Light: "light", Medium: "medium", Heavy: "heavy", Soft: "soft", Rigid: "rigid" };
export const NotificationFeedbackType = { Success: "success", Warning: "warning", Error: "error" };
const ok = (k) => (arg) => { if (arg === undefined && k !== "selection") throw new Error(`haptic ${k} sin estilo`); haptics.push(`${k}:${arg ?? ""}`); return Promise.resolve(); };
export const impactAsync = ok("impact"), notificationAsync = ok("notification"), selectionAsync = ok("selection");
const Slider = host("Slider");
export default Slider;
