/* Guardián de la CSP de la app empaquetada. Tauri añade un nonce a style-src por cada <style> del
   HTML y, con un nonce presente, el navegador ignora 'unsafe-inline': un <style> creado en tiempo de
   ejecución (JSX o createElement) se bloquea en macOS, Windows y Linux aunque en el navegador funcione.
   Los estilos globales van en src/styles.css; los de componente, en línea (CSSOM, permitido). */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const src = fileURLToPath(new URL("../src/", import.meta.url));
const files = (dir) => readdirSync(dir).flatMap((f) => (statSync(join(dir, f)).isDirectory() ? files(join(dir, f)) : [join(dir, f)]));
const bad = [];
for (const f of files(src).filter((x) => /\.(jsx?|mjs)$/.test(x))) {
  readFileSync(f, "utf8").split("\n").forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, "").replace(/\/\*.*?\*\//g, "");
    if ((f.endsWith(".jsx") && /<style[\s>]/.test(code)) || /createElement\(\s*["']style["']/.test(code)) bad.push(`${f.slice(src.length)}:${i + 1}: ${line.trim()}`);
  });
}
if (bad.length) {
  console.error("✗ <style> generado en tiempo de ejecución: la CSP de Tauri lo bloqueará. Muévelo a src/styles.css.\n  " + bad.join("\n  "));
  process.exit(1);
}
console.log("✓ CSP: sin <style> generados en tiempo de ejecución");
