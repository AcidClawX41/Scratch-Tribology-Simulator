#!/usr/bin/env node
/* Emoji de los textos del programa Godot y su fuente de reserva: un subconjunto de Noto Color Emoji (SIL OFL 1.1) con
   solo esos emoji, en godot/assets/fonts/noto-color-emoji-subset.ttf (app/theme/app_theme.gd la pone de reserva de
   Syne y Space Mono). Uso desde la raíz del repositorio:
     node godot/tools/emoji.mjs                            lista los emoji que usan los textos (core/ y app/)
     node godot/tools/emoji.mjs --build <NotoColorEmoji.ttf>
                                                           regenera el subconjunto con fontTools
   fontTools: pip install --target <carpeta> fonttools, y PYTHONPATH=<carpeta> (o instalado en el sistema).
   Noto Color Emoji: https://github.com/googlefonts/noto-emoji (fonts/NotoColorEmoji.ttf) o el paquete
   fonts-noto-color-emoji de Debian/Ubuntu (/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf).
   Qué cuenta como emoji (lo mismo que tests/app/test_emoji.gd, que falla si falta alguno en la fuente o si sobra):
   los caracteres de U+1F000 a U+1FAFF, los del plano básico con Emoji_Presentation=Yes (Unicode 15.1) y cualquiera
   seguido del selector de variación U+FE0F (que también entra). */
import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const PROJECT = resolve(here, "..");
const OUT = join(PROJECT, "assets/fonts/noto-color-emoji-subset.ttf");
// Emoji_Presentation=Yes del plano básico (emoji-data.txt de Unicode 15.1)
const BMP = [[0x231A, 0x231B], [0x23E9, 0x23EC], [0x23F0, 0x23F0], [0x23F3, 0x23F3], [0x25FD, 0x25FE], [0x2614, 0x2615],
  [0x2648, 0x2653], [0x267F, 0x267F], [0x2693, 0x2693], [0x26A1, 0x26A1], [0x26AA, 0x26AB], [0x26BD, 0x26BE], [0x26C4, 0x26C5],
  [0x26CE, 0x26CE], [0x26D4, 0x26D4], [0x26EA, 0x26EA], [0x26F2, 0x26F3], [0x26F5, 0x26F5], [0x26FA, 0x26FA], [0x26FD, 0x26FD],
  [0x2705, 0x2705], [0x270A, 0x270B], [0x2728, 0x2728], [0x274C, 0x274C], [0x274E, 0x274E], [0x2753, 0x2755], [0x2757, 0x2757],
  [0x2795, 0x2797], [0x27B0, 0x27B0], [0x27BF, 0x27BF], [0x2B1B, 0x2B1C], [0x2B50, 0x2B50], [0x2B55, 0x2B55]];

export const isEmoji = (cp) => (cp >= 0x1F000 && cp <= 0x1FAFF) || BMP.some(([a, b]) => cp >= a && cp <= b);

function gdFiles(dir, out = []) {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) gdFiles(p, out);
    else if (f.endsWith(".gd")) out.push(p);
  }
  return out;
}

/** Emoji (código → archivos) de los scripts de core/ y app/. */
export function usedEmoji() {
  const used = new Map();
  for (const f of [...gdFiles(join(PROJECT, "core")), ...gdFiles(join(PROJECT, "app"))].sort()) {
    const cps = [...readFileSync(f, "utf8")].map((c) => c.codePointAt(0));
    cps.forEach((cp, i) => {
      const hit = isEmoji(cp) || cps[i + 1] === 0xFE0F || (cp === 0xFE0F && i > 0);
      if (!hit) return;
      if (!used.has(cp)) used.set(cp, new Set());
      used.get(cp).add(f.slice(PROJECT.length + 1));
    });
  }
  return new Map([...used].sort((a, b) => a[0] - b[0]));
}

const used = usedEmoji();
const hex = (cp) => cp.toString(16).toUpperCase().padStart(4, "0");
const buildArg = process.argv.indexOf("--build");
if (buildArg < 0) {
  for (const [cp, files] of used) console.log(`U+${hex(cp)} ${String.fromCodePoint(cp)}  ${[...files].join(", ")}`);
  console.log(`${used.size} emoji`);
} else {
  const src = process.argv[buildArg + 1];
  if (!src) { console.error("Falta la fuente: --build /ruta/a/NotoColorEmoji.ttf"); process.exit(2); }
  const unicodes = [...used.keys()].map((cp) => `U+${hex(cp)}`).join(",");
  const r = spawnSync("python3", ["-m", "fontTools.subset", src, `--unicodes=${unicodes}`, `--output-file=${OUT}`,
    "--layout-features=*", "--no-hinting"], { stdio: "inherit" });
  if (r.status !== 0) process.exit(r.status ?? 1);
  console.log(`${OUT}: ${used.size} emoji, ${statSync(OUT).size} bytes`);
}
