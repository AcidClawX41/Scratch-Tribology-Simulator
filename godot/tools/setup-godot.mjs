#!/usr/bin/env node
/* Instala las herramientas de Godot que usa el proyecto, en la versión exacta y comprobadas con las sumas SHA-512
   oficiales (godot-4.7.2.sha512, copiado de SHA512-SUMS.txt de la release 4.7.2-stable). Así el entorno se puede
   rehacer en cualquier equipo o sesión sin guardar en el repositorio binarios de más de 100 MB.
     node godot/tools/setup-godot.mjs                  editor de Godot 4.7.2 para esta plataforma
     node godot/tools/setup-godot.mjs --templates      y además las plantillas de exportación (~1 GB)
     node godot/tools/setup-godot.mjs --dir=/ruta      carpeta de instalación (por defecto .godot-home/bin)
   Al acabar dice qué poner en GODOT. godot.mjs también encuentra solo .godot-home/bin/godot. */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, chmodSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const VERSION = "4.7.2";
const TAG = `${VERSION}-stable`;
const BASE = `https://github.com/godotengine/godot/releases/download/${TAG}`;
const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, "..", "..");
const args = process.argv.slice(2);
const opt = (name, def) => {
  const hit = args.find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return def;
  return hit.includes("=") ? hit.slice(hit.indexOf("=") + 1) : true;
};
const dir = resolve(String(opt("dir", join(ROOT, ".godot-home", "bin"))));
const sums = Object.fromEntries(readFileSync(join(here, `godot-${VERSION}.sha512`), "utf8").trim().split("\n")
  .map((l) => l.trim().split(/\s+/)).map(([h, f]) => [f, h]));

function editorFile() {
  const { platform, arch } = process;
  if (platform === "linux") return arch === "arm64" ? `Godot_v${TAG}_linux.arm64.zip` : `Godot_v${TAG}_linux.x86_64.zip`;
  if (platform === "win32") return arch === "arm64" ? `Godot_v${TAG}_windows_arm64.exe.zip` : `Godot_v${TAG}_win64.exe.zip`;
  if (platform === "darwin") return `Godot_v${TAG}_macos.universal.zip`;
  throw new Error(`Plataforma sin editor de Godot previsto: ${platform}/${arch}`);
}

function sha512(file) {
  return new Promise((ok, ko) => {
    const h = createHash("sha512");
    createReadStream(file).on("data", (d) => h.update(d)).on("end", () => ok(h.digest("hex"))).on("error", ko);
  });
}

async function download(name) {
  const dest = join(dir, name);
  if (existsSync(dest) && (await sha512(dest)) === sums[name]) {
    console.log(`Ya descargado y comprobado: ${name}`);
    return dest;
  }
  console.log(`Descargando ${BASE}/${name} …`);
  const r = spawnSync("curl", ["-fL", "--retry", "3", "-o", `${dest}.part`, `${BASE}/${name}`], { stdio: "inherit" });
  if (r.status !== 0) throw new Error(`No se pudo descargar ${name} (curl ${r.status})`);
  const got = await sha512(`${dest}.part`);
  if (got !== sums[name]) {
    rmSync(`${dest}.part`, { force: true });
    throw new Error(`La suma SHA-512 de ${name} no coincide con la oficial: el archivo no se usa`);
  }
  renameSync(`${dest}.part`, dest);
  console.log(`Comprobado con SHA-512: ${name}`);
  return dest;
}

function unzip(file, into) {
  mkdirSync(into, { recursive: true });
  const r = process.platform === "win32"
    ? spawnSync("tar", ["-xf", file, "-C", into], { stdio: "inherit" })
    : spawnSync("unzip", ["-oq", file, "-d", into], { stdio: "inherit" });
  if (r.status !== 0) throw new Error(`No se pudo descomprimir ${file}`);
}

function dataDir() {
  if (process.env.XDG_DATA_HOME) return join(process.env.XDG_DATA_HOME, "godot");
  if (process.platform === "win32") return join(process.env.APPDATA || "", "Godot");
  if (process.platform === "darwin") return join(process.env.HOME || "", "Library", "Application Support", "Godot");
  return join(process.env.HOME || "", ".local", "share", "godot");
}

mkdirSync(dir, { recursive: true });
const zip = await download(editorFile());
const unpacked = join(dir, `Godot_v${TAG}`);
unzip(zip, unpacked);
let exe = "";
if (process.platform === "darwin") {
  exe = join(unpacked, "Godot.app", "Contents", "MacOS", "Godot");
} else {
  const found = readdirSync(unpacked).find((f) => f.startsWith(`Godot_v${TAG}`) && !f.includes("console"));
  exe = join(unpacked, found || "");
  if (process.platform !== "win32") chmodSync(exe, 0o755);
}
// Enlace estable que usa godot.mjs: .godot-home/bin/godot (o godot.exe)
const link = join(dir, process.platform === "win32" ? "godot.exe" : "godot");
rmSync(link, { force: true });
const copy = spawnSync(process.platform === "win32" ? "cmd" : "ln",
  process.platform === "win32" ? ["/c", "copy", "/y", exe, link] : ["-s", exe, link], { stdio: "inherit" });
if (copy.status !== 0) throw new Error("No se pudo crear el enlace del editor");
const ver = spawnSync(link, ["--version", "--headless"], { encoding: "utf8" });
console.log(`Editor: ${link} → ${(ver.stdout || "").trim() || "(sin respuesta a --version)"}`);

if (opt("templates", false)) {
  const tpz = await download(`Godot_v${TAG}_export_templates.tpz`);
  const target = join(dataDir(), "export_templates", `${VERSION}.stable`);
  const tmp = join(dir, "templates-tmp");
  rmSync(tmp, { recursive: true, force: true });
  unzip(tpz, tmp);
  mkdirSync(dirname(target), { recursive: true });
  rmSync(target, { recursive: true, force: true });
  renameSync(join(tmp, "templates"), target);
  rmSync(tmp, { recursive: true, force: true });
  console.log(`Plantillas de exportación en ${target}`);
}
console.log(`\nListo. Para los scripts del proyecto: export GODOT=${link}`);
