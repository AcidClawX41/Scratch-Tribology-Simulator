/* Integración nativa del frontend de escritorio (macOS · Windows · Linux) y de la versión web.
   El shell de Tauri no tiene lógica: todo lo que hace que la app "se sienta" nativa vive aquí. */
import { useEffect, useRef } from "react";

/** ¿Estamos dentro de la ventana de Tauri (y no en un navegador)? */
export const isTauri = typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

/** Sistema operativo, para atajos y detalles visuales: "mac" · "windows" · "linux" · "other". */
export const platform = (() => {
  if (typeof navigator === "undefined") return "other";
  const p = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || navigator.userAgent || "";
  if (/mac|iphone|ipad/i.test(p)) return "mac";
  if (/win/i.test(p)) return "windows";
  if (/linux|x11/i.test(p)) return "linux";
  return "other";
})();

/** Etiqueta del atajo para lanzar el ensayo, con el modificador de cada sistema. */
export const runShortcutLabel = platform === "mac" ? "⌘ ↩" : "Ctrl ↩";

/** Ctrl+Enter (⌘+Enter en macOS) lanza el ensayo desde cualquier parte de la ventana. */
export function useRunShortcut(run, enabled) {
  const ref = useRef(run);
  ref.current = run;
  useEffect(() => {
    const onKey = (e) => {
      const mod = platform === "mac" ? e.metaKey : e.ctrlKey;
      if (mod && e.key === "Enter" && enabled) { e.preventDefault(); ref.current(); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [enabled]);
}

/** Ajustes que solo tienen sentido dentro de la app nativa (no en la web). */
export function installNativeBehaviour() {
  document.documentElement.dataset.platform = platform;
  if (!isTauri) return;
  document.documentElement.dataset.native = "tauri";
  // Una app de escritorio no enseña el menú contextual del navegador (Recargar, Atrás, Imprimir…).
  window.addEventListener("contextmenu", (e) => {
    if (!(e.target instanceof HTMLElement && e.target.closest("input, textarea, [contenteditable=true]"))) e.preventDefault();
  });
  // Recargar o imprimir la vista web no tiene sentido en la app: se perdería el estado del banco.
  window.addEventListener("keydown", (e) => {
    const mod = platform === "mac" ? e.metaKey : e.ctrlKey;
    const k = e.key.toLowerCase();
    if (e.key === "F5" || (mod && (k === "r" || k === "p"))) e.preventDefault();
  });
}
