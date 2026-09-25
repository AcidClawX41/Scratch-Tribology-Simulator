/* Prerenderiza los efectos de sonido de @sts/core a WAV para la app móvil (expo-audio reproduce
   archivos, no muestras en memoria) y genera src/sfxAssets.js con los require().
   Uso (desde la raíz):  npm run sfx:mobile           → regenera
                         npm run sfx:mobile -- --check → falla si los WAV no coinciden con el motor */
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { SFX_IDS, SFX_RATE, renderSfx, encodeWav } from "../../../packages/core/src/index.js";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "assets", "sfx");
const mapFile = join(here, "..", "src", "sfxAssets.js");
const check = process.argv.includes("--check");

const map = `/* Generado por scripts/render-sfx.mjs a partir de @sts/core/sfx.js. No editar a mano. */\nexport const SFX_FILES = {\n${SFX_IDS.map((id) => `  "${id}": require("../assets/sfx/${id}.wav"),`).join("\n")}\n};\n`;
const stale = [];
if (!check) mkdirSync(outDir, { recursive: true });
for (const id of SFX_IDS) {
  const wav = Buffer.from(encodeWav(renderSfx(id, SFX_RATE), SFX_RATE));
  const file = join(outDir, `${id}.wav`);
  if (check) { if (!existsSync(file) || !readFileSync(file).equals(wav)) stale.push(`${id}.wav`); }
  else writeFileSync(file, wav);
}
const extra = existsSync(outDir) ? readdirSync(outDir).filter((f) => f.endsWith(".wav") && !SFX_IDS.includes(f.slice(0, -4))) : [];
if (check) {
  if (!existsSync(mapFile) || readFileSync(mapFile, "utf8") !== map) stale.push("src/sfxAssets.js");
  stale.push(...extra.map((f) => `${f} (sobra)`));
  if (stale.length) { console.error(`Sonidos móviles desactualizados: ${stale.join(", ")}\n→ ejecuta: npm run sfx:mobile`); process.exit(1); }
  console.log(`sonidos móviles al día (${SFX_IDS.length} efectos)`);
} else {
  writeFileSync(mapFile, map);
  console.log(`${SFX_IDS.length} efectos → apps/mobile/assets/sfx/${extra.length ? ` · sobran: ${extra.join(", ")}` : ""}`);
}
