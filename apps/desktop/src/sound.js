/* Efectos de sonido de escritorio: las recetas de @sts/core se renderizan una vez a un AudioBuffer
   (Web Audio, disponible en WebKit, WebView2 y WebKitGTK) y se reproducen al instante.
   La preferencia (activado/desactivado) se guarda en el propio equipo con localStorage. */
import { useCallback, useRef, useState } from "react";
import { renderSfx, SFX_RATE } from "@sts/core";

const KEY = "sts.sound";
const cache = new Map();
let ctx = null;

const readPref = () => { try { return localStorage.getItem(KEY) !== "off"; } catch { return true; } };
const writePref = (on) => { try { localStorage.setItem(KEY, on ? "on" : "off"); } catch { /* modo privado: sin persistencia */ } };

function audio() {
  if (!ctx) {
    const AC = typeof window !== "undefined" && (window.AudioContext || window.webkitAudioContext);
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === "suspended") ctx.resume().catch(() => {});
  return ctx;
}

/** Reproduce un efecto por id (ver SFX_IDS). Si el sistema no tiene audio, no hace nada. */
export function playSfx(id, volume = 0.7) {
  const c = audio();
  if (!c) return;
  let buf = cache.get(id);
  if (!buf) {
    const pcm = renderSfx(id, SFX_RATE);
    buf = c.createBuffer(1, pcm.length, SFX_RATE);
    buf.getChannelData(0).set(pcm);
    cache.set(id, buf);
  }
  const src = c.createBufferSource(), gain = c.createGain();
  gain.gain.value = volume;
  src.buffer = buf;
  src.connect(gain).connect(c.destination);
  src.start();
}

/** Estado del sonido: [activado, alternar, reproducir-si-activado]. */
export function useSound() {
  const [on, setOn] = useState(readPref);
  // La referencia deja que un sonido diferido (impacto, fanfarria) respete un silencio posterior.
  const onRef = useRef(on);
  onRef.current = on;
  const toggle = useCallback(() => {
    const next = !onRef.current;
    onRef.current = next;
    setOn(next);
    writePref(next);
    playSfx(next ? "on" : "off", 0.6);   // confirmación audible en los dos sentidos
  }, []);
  const play = useCallback((id, volume) => { if (onRef.current) playSfx(id, volume); }, []);
  return [on, toggle, play];
}
