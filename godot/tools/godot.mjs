#!/usr/bin/env node
/* Envoltorio de Godot para la línea de órdenes (Linux, macOS y la nube). Uso desde la raíz del repo:
     node godot/tools/godot.mjs import                        importa el proyecto (sin ventana)
     node godot/tools/godot.mjs test [--filter=x] [--verbose]  datos del oráculo + importación + tests
     node godot/tools/godot.mjs golden                         regenera el golden 2.0 del laboratorio (a propósito)
     node godot/tools/godot.mjs capture <escena> [--frames=90] [--out=dir] [--size=1240x880] [--fps=30]
                                        [--phone[=390x844]] [--driver=opengl3] [-- args de la escena]
                                                               captura PNG + WAV con Movie Maker; con --phone, al
                                                               tamaño de un teléfono y sin marco (override.cfg temporal)
     node godot/tools/godot.mjs run [args…]                   Godot con el proyecto y el entorno de estos scripts
   El binario se toma de la variable GODOT o de `godot`/`godot4` en el PATH (Godot 4.7.2, editor estándar).
   Los ajustes del editor de estas ejecuciones van a .godot-home/ (ignorado), para no tocar los tuyos; con
   STS_GODOT_KEEP_HOME=1 se usan los normales (p. ej. para exportar con tus plantillas). */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const PROJECT = resolve(here, "..");
const ROOT = resolve(PROJECT, "..");
const [cmd = "help", ...argv] = process.argv.slice(2);
const sep = argv.indexOf("--");
const opts = sep >= 0 ? argv.slice(0, sep) : argv;
const passthrough = sep >= 0 ? argv.slice(sep + 1) : [];
const opt = (name, def) => {
  const hit = opts.find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return def;
  return hit.includes("=") ? hit.slice(hit.indexOf("=") + 1) : true;
};

function godotBin() {
  if (process.env.GODOT) return process.env.GODOT;
  // El que instala tools/setup-godot.mjs (npm run godot:setup), si está
  const local = join(ROOT, ".godot-home", "bin", process.platform === "win32" ? "godot.exe" : "godot");
  if (existsSync(local)) return local;
  for (const c of ["godot", "godot4"]) {
    const r = spawnSync("sh", ["-c", `command -v ${c}`], { encoding: "utf8" });
    if (r.status === 0 && r.stdout.trim()) return r.stdout.trim();
  }
  console.error("No encuentro Godot 4.7.2: instálalo con «npm run godot:setup», define GODOT=/ruta/al/binario o ponlo en el PATH.");
  process.exit(2);
}

const env = { ...process.env };
if (!process.env.STS_GODOT_KEEP_HOME) {
  const home = join(ROOT, ".godot-home");
  Object.assign(env, { XDG_CONFIG_HOME: join(home, "config"), XDG_DATA_HOME: join(home, "data"), XDG_CACHE_HOME: join(home, "cache") });
}

// Líneas de Godot que indican un fallo aunque el código de salida sea 0 (GDScript no tiene excepciones)
const FATAL = /SCRIPT ERROR|Parse Error|Failed to load script|Invalid (call|get|set|access)|Nonexistent function|Cannot call method/;

function godot(args, { timeout = 600_000, capture = true, xvfb = null } = {}) {
  const bin = godotBin();
  const full = xvfb ? ["xvfb-run", ["-a", "-s", `-screen 0 ${xvfb}x24`, bin, ...args]] : [bin, args];
  const r = spawnSync(full[0], full[1], { cwd: ROOT, env, encoding: "utf8", timeout, maxBuffer: 256 * 1024 * 1024,
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit" });
  const out = capture ? `${r.stdout || ""}${r.stderr || ""}` : "";
  return { status: r.status ?? 1, out, signal: r.signal };
}

// El oráculo (godot/tests/fixtures/, también generated/ con su sello .stamp) está versionado: lo generó el motor 1.x
// congelado con Node 22, cuyo V8 12.4 es el que porta godot/core/shared/v8_math.gd al bit. Así los tests dan lo mismo con
// cualquier Node instalado. Solo se regenera si cambia el motor 1.x (packages/core/src) o el exportador, y entonces con
// Node 22: con otro V8, algún pow() sale distinto en el último bit (con Node 24 fallaban cuatro casos en test_js y test_art).
const ORACLE_NODE_MAJOR = 22;

function fixtures(force = false) {
  const gen = join(PROJECT, "tests/fixtures/generated");
  const stampFile = join(gen, ".stamp");
  const h = createHash("sha256");
  const src = join(ROOT, "packages/core/src");
  // con los saltos de línea normalizados: en Windows, git puede poner CRLF al sacar los archivos y el sello no cambia
  const text = (f) => readFileSync(f, "utf8").replace(/\r\n/g, "\n");
  for (const f of readdirSync(src).sort()) h.update(text(join(src, f)));
  h.update(text(join(ROOT, "packages/core/scripts/export-fixtures.mjs")));
  const want = h.digest("hex");
  const have = existsSync(stampFile) ? readFileSync(stampFile, "utf8").trim() : "";
  if (!force && have === want && existsSync(join(gen, "lab-sample.json")) && existsSync(join(gen, "art-svg.json"))) return;
  const major = Number(process.versions.node.split(".")[0]);
  if (major !== ORACLE_NODE_MAJOR) {
    console.error(`Hay que regenerar el oráculo (${have === want ? "faltan archivos de generated/" : "ha cambiado el motor 1.x o el exportador"}), ` +
      `y eso se hace con Node ${ORACLE_NODE_MAJOR}, el del V8 que porta v8_math.gd (ahora: Node ${process.versions.node}). ` +
      `Por ejemplo: «nvm use ${ORACLE_NODE_MAJOR}» y repite.`);
    process.exit(1);
  }
  const r = spawnSync(process.execPath, [join(ROOT, "packages/core/scripts/export-fixtures.mjs")], { cwd: ROOT, stdio: "inherit" });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

function importProject() {
  const r = godot(["--headless", "--path", PROJECT, "--import"], { timeout: 900_000 });
  const errs = r.out.split("\n").filter((l) => FATAL.test(l));
  if (r.status !== 0 || errs.length) {
    const bad = r.out.split("\n").filter((l) => /ERROR|error/.test(l)).slice(0, 40);
    console.log(bad.join("\n"));
    if (process.env.GITHUB_ACTIONS === "true") {
      for (const l of [...errs, ...bad].slice(0, 20)) console.log(`::error title=Importación de Godot::${l.trim().replace(/%/g, "%25")}`);
    }
    console.error(`Importación del proyecto: FALLA (código ${r.status})`);
    process.exit(1);
  }
}

// En GitHub Actions, cada test fallido y cada error de script salen también como anotaciones («::error::»): se ven en
// el resumen de la ejecución y en la API de los check runs sin tener que descargar el registro entero.
function annotate(lines, fatal, r) {
  const esc = (t) => t.replace(/%/g, "%25").replace(/\r/g, "%0D").replace(/\n/g, "%0A");
  const failed = lines.filter((l) => /^\s*✗/.test(l));
  for (const l of [...failed, ...fatal].slice(0, 40)) console.log(`::error title=Tests de Godot::${esc(l.trim())}`);
  if (r.signal) console.log(`::error title=Tests de Godot::La batería se cortó (${r.signal})`);
  const summary = lines.filter((l) => /^\d+ tests, \d+ fallidos/.test(l)).pop();
  if (summary && (failed.length || fatal.length)) console.log(`::error title=Tests de Godot::${esc(summary)}`);
  if (!summary) console.log(`::error title=Tests de Godot::Sin resumen de la batería (código ${r.status}); últimas líneas: ${esc(lines.slice(-5).join(" | "))}`);
}

switch (cmd) {
  case "fixtures":
    fixtures(!!opt("force", false));
    break;
  case "import":
    importProject();
    console.log("Proyecto importado.");
    break;
  case "test": {
    fixtures();
    importProject();
    const user = [];
    if (opt("filter")) user.push(`--filter=${opt("filter")}`);
    if (opt("verbose")) user.push("--verbose");
    // la batería completa tarda unos 10 min con la máquina libre, y más con otros agentes trabajando a la vez: 40 min de
    // margen (con el límite general de 10 min se cortaba a medias, sin resumen)
    const r = godot(["--headless", "--path", PROJECT, "--script", "res://tests/run_tests.gd", "--", ...user], { timeout: 2_400_000 });
    const lines = r.out.split("\n").filter((l) => !/^Godot Engine v/.test(l) && l.trim() !== "");
    console.log(lines.join("\n"));
    if (r.signal) console.error(`\nLa batería se cortó (${r.signal}): pasó del límite de tiempo o se mató el proceso. No es un fallo de los tests: repítela.`);
    const fatal = lines.filter((l) => FATAL.test(l));
    if (fatal.length) console.error(`\n${fatal.length} errores de script en la salida: el conjunto se da por fallido.`);
    if (process.env.GITHUB_ACTIONS === "true") annotate(lines, fatal, r);
    if (r.status !== 0 || fatal.length) process.exit(1);
    break;
  }
  case "golden": {
    // tests/fixtures/lab-golden-v2.json: la física 2.0 en los escenarios del golden (tools/golden_v2.gd). Solo a
    // propósito: cada diferencia con la 1.x se explica en docs/FISICA.md («Cambios de la 2.0»).
    fixtures();
    importProject();
    const r = godot(["--headless", "--path", PROJECT, "--script", "res://tools/golden_v2.gd"]);
    const lines = r.out.split("\n").filter((l) => !/^Godot Engine v/.test(l) && l.trim() !== "");
    console.log(lines.join("\n"));
    const fatal = lines.filter((l) => FATAL.test(l));
    if (r.status !== 0 || fatal.length) process.exit(1);
    break;
  }
  case "capture": {
    const scene = opts.find((a) => !a.startsWith("--"));
    if (!scene) { console.error("Falta la escena: capture res://ruta/escena.tscn"); process.exit(2); }
    // --phone[=WxH]: Movie Maker graba al tamaño del lienzo del proyecto (1240 × 880); un override.cfg temporal junto a
    // project.godot lo cambia al del teléfono, así la escena se ve como en él y sin el marco de la demo. Se borra al acabar.
    const phoneOpt = opt("phone", false);
    const phone = phoneOpt === false ? null : phoneOpt === true ? "390x844" : String(phoneOpt);
    if (phone && !/^\d+x\d+$/.test(phone)) { console.error(`--phone=${phone}: se espera ANCHOxALTO (p. ej. 390x844)`); process.exit(2); }
    const frames = Number(opt("frames", 90)), fps = Number(opt("fps", 30)), size = phone ?? String(opt("size", "1240x880"));
    const out = resolve(ROOT, String(opt("out", join(ROOT, ".godot-home/capturas"))));
    mkdirSync(out, { recursive: true });
    importProject();
    const driver = String(opt("driver", "opengl3"));
    const headed = !!process.env.DISPLAY && !opt("xvfb", false);
    const args = ["--path", PROJECT, "--rendering-driver", driver, "--resolution", size, "--write-movie", join(out, "f.png"),
      "--fixed-fps", String(fps), "--quit-after", String(frames), scene, "--", ...passthrough];
    const override = join(PROJECT, "override.cfg");
    if (phone) {
      if (existsSync(override)) { console.error(`Ya hay un ${override}: bórralo o renómbralo antes de capturar con --phone.`); process.exit(2); }
      const [w, h] = phone.split("x");
      writeFileSync(override, `; Temporal: lo escribe \`godot.mjs capture --phone\` y lo borra al acabar (no se versiona).\n[display]\n\n`
        + `window/size/viewport_width=${w}\nwindow/size/viewport_height=${h}\n`);
      const clean = () => rmSync(override, { force: true });
      process.on("exit", clean);
      for (const sig of ["SIGINT", "SIGTERM"]) process.on(sig, () => { clean(); process.exit(130); });
    }
    let r;
    try {
      r = godot(args, { xvfb: headed ? null : size, timeout: 1_800_000 });
    } finally {
      if (phone) rmSync(override, { force: true });
    }
    const fatal = r.out.split("\n").filter((l) => FATAL.test(l));
    const pngs = existsSync(out) ? readdirSync(out).filter((f) => f.endsWith(".png")).length : 0;
    console.log(r.out.split("\n").filter((l) => /frames at|ERROR|WARNING|SCRIPT/.test(l)).slice(0, 30).join("\n"));
    console.log(`Captura: ${pngs} fotogramas PNG y ${existsSync(join(out, "f.wav")) ? "f.wav" : "sin WAV"} en ${out}`);
    if (r.status !== 0 || fatal.length || pngs === 0) process.exit(1);
    break;
  }
  case "run": {
    const r = godot(["--path", PROJECT, ...opts, ...passthrough], { capture: false, timeout: 0 });
    process.exit(r.status);
  }
  default:
  {
    const lines = readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n");
    console.log(lines.slice(1, lines.findIndex((l) => l.includes("*/")) + 1).join("\n"));
  }
}
