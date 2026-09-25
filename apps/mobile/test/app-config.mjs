/* Comprueba app.json sin instalar Expo: todo archivo que cita existe y la pantalla de arranque tiene
   imagen. Con Expo SDK 52, el prebuild de Android enlaza siempre @drawable/splashscreen_logo, pero
   solo genera ese PNG si hay imagen: sin ella el APK no compila («resource drawable/splashscreen_logo
   not found»). Uso (desde la raíz): npm run check:mobile */
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const app = join(dirname(fileURLToPath(import.meta.url)), "..");
const { expo } = JSON.parse(readFileSync(join(app, "app.json"), "utf8"));
const problems = [];

const files = [];
JSON.stringify(expo, (key, value) => {
  if (typeof value === "string" && value.startsWith("./")) files.push(value);
  return value;
});
for (const f of files) if (!existsSync(join(app, f))) problems.push(`app.json cita ${f}, que no existe`);

const plugin = (expo.plugins ?? []).find((p) => (Array.isArray(p) ? p[0] : p) === "expo-splash-screen");
const splash = Array.isArray(plugin) ? plugin[1] : expo.splash;
if (!splash?.image) problems.push("la pantalla de arranque no tiene imagen: el APK no compilaría (drawable/splashscreen_logo)");

for (const p of problems) console.log(`  ✗ ${p}`);
if (problems.length) {
  console.log("\nConfiguración de la app móvil: FALLA");
  process.exit(1);
}
console.log(`Configuración de la app móvil: OK (${files.length} archivos citados; pantalla de arranque con imagen)`);
