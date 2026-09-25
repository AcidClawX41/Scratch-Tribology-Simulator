import { C } from "@sts/core";
export { C };
export const DISP = "'Syne', system-ui, sans-serif";
export const MONO = "'Space Mono', ui-monospace, monospace";

/** Publica la paleta y las tipografías como variables CSS (--c-*, --font-*) para styles.css.
 *  Se hace por CSSOM, que la CSP de Tauri permite (un <style> generado no pasaría). */
export function applyThemeVars(root = document.documentElement) {
  for (const [k, v] of Object.entries(C)) root.style.setProperty(`--c-${k}`, v);
  root.style.setProperty("--font-disp", DISP);
  root.style.setProperty("--font-mono", MONO);
}
