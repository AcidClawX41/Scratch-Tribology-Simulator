/* Empaquetado de escritorio en Linux. El sonido (Web Audio de WebKitGTK) sale por GStreamer, y que suene
   depende de cómo se construyen el AppImage, el .deb y el .rpm (docs/AUDIO-NATIVO.md); que el AppImage arranque
   con Mesa reciente, de que deje libwayland-client al sistema. Estos tests leen la configuración real de Tauri,
   el workflow de release y los avisos de licencias, como el de las versiones. */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Sin \r: con Git para Windows (core.autocrlf) los archivos llegan con CRLF
const read = (f) => readFileSync(new URL(`../../../${f}`, import.meta.url), "utf8").replace(/\r\n/g, "\n");
const conf = JSON.parse(read("apps/desktop/src-tauri/tauri.conf.json"));
const linux = conf.bundle.linux;
const release = read(".github/workflows/release.yml");

const DEB = ["gstreamer1.0-plugins-base", "gstreamer1.0-plugins-good", "gstreamer1.0-alsa"];   // Debian y Ubuntu
const RPM = ["gstreamer1-plugins-base", "gstreamer1-plugins-good"];                            // Fedora (alsasink va en base)
// Web Audio en WebKitGTK: appsrc ! clocksync ! audioconvert ! audioresample ! autoaudiosink → pulsesink o alsasink
const WEB_AUDIO = ["coreelements", "app", "audioconvert", "audioresample", "autodetect", "pulseaudio", "alsa"];
// linuxdeploy de Tauri 2.12 (07333c6): deja fuera libwayland-client, que con Mesa 25 o posterior hace abortar a WebKit
// (tauri-apps/tauri#15976). Tauri 2.11 lo usa si está en su caché
const LINUXDEPLOY = "releases/download/linuxdeploy-07333c6/linuxdeploy-x86_64.AppImage";

/** Pasos de un job de release.yml como texto, sin parser YAML: cada «- » a 6 espacios abre un paso. */
function steps(job) {
  const lines = release.split(/\r?\n/);
  const start = lines.indexOf(`  ${job}:`);
  assert.ok(start >= 0, `release.yml no tiene el job ${job}`);
  const end = lines.findIndex((l, i) => i > start && /^ {2}\S/.test(l));
  const body = lines.slice(start + 1, end < 0 ? undefined : end);
  const from = body.indexOf("    steps:");
  assert.ok(from >= 0, `el job ${job} no tiene steps`);
  const out = [];
  for (const l of body.slice(from + 1)) {
    if (l.startsWith("      - ")) out.push(l);
    else if (out.length && (l.startsWith("        ") || !l.trim())) out[out.length - 1] += `\n${l}`;
  }
  return out;
}
const desktop = steps("desktop");
const build = desktop.findIndex((s) => /uses: tauri-apps\/tauri-action@/.test(s));
const onLinux = (s) => s.includes("if: startsWith(matrix.platform, 'ubuntu')");
const checkAt = desktop.findIndex((s, i) => i > build && s.includes("--appimage-extract"));
const check = desktop[checkAt];
// Linux se compila en un contenedor de Ubuntu (matrix.container): su versión fija la glibc mínima y las bibliotecas del AppImage
const ubuntu = release.match(/^ +container: ubuntu:(\d\d\.\d\d)$/m)?.[1];

describe("empaquetado de Linux: sonido con GStreamer", () => {
  test("Tauri genera AppImage, .deb y .rpm, y el AppImage lleva GStreamer dentro (bundleMediaFramework)", () => {
    assert.equal(conf.bundle.targets, "all");
    assert.equal(linux.appimage?.bundleMediaFramework, true, "sin él, el AppImage sale mudo donde falten los plugins");
  });

  test("el .deb exige los plugins; el .rpm los recomienda sin dejar de instalarse en ninguna distribución", () => {
    for (const p of DEB) assert.ok(linux.deb?.depends?.includes(p), `.deb: falta ${p}`);
    assert.ok(!linux.deb.depends.some((p) => p.startsWith("gstreamer1-")), "nombre de Fedora en el .deb");
    for (const p of RPM) assert.ok(linux.rpm?.recommends?.includes(p), `.rpm: falta la recomendación ${p}`);
    assert.ok(!linux.rpm.recommends.some((p) => p.startsWith("gstreamer1.0-")), "nombre de Debian en el .rpm");
    // Una dependencia fuerte con nombres de Fedora deja el .rpm sin instalar en openSUSE (y al revés)
    assert.ok(!(linux.rpm.depends || []).some((p) => /^gstreamer/.test(p)), "el .rpm exige plugins con nombres de una sola distribución");
    for (const deps of [linux.deb.depends, linux.rpm.recommends]) assert.equal(new Set(deps).size, deps.length, "dependencia repetida");
  });

  test("release.yml instala en el runner lo que pide el .deb y elige los plugins ANTES de compilar", () => {
    assert.ok(build > 0, "release.yml ya no compila el escritorio con tauri-action");
    assert.match(release, /platform: ubuntu-/, "el escritorio de Linux se compila en Ubuntu");
    // Dentro de un contenedor de Ubuntu (null en macOS y Windows), como root y sin lo que trae el ejecutor de GitHub
    assert.ok(ubuntu, "Linux no se compila en un contenedor de Ubuntu (matrix.container)");
    assert.match(release, /^ {4}container: \$\{\{ matrix\.container \|\| null \}\}$/m, "el job no usa matrix.container");
    const code = (s) => s.split("\n").filter((l) => !l.trim().startsWith("#")).join("\n");
    for (const s of desktop.filter(onLinux)) {
      assert.ok(!/\b(sudo|gh api)\b/.test(code(s)), `el contenedor no trae sudo ni gh: ${s.split("\n")[0].trim()}`);
    }
    const before = desktop.slice(0, build).filter(onLinux);
    for (const p of linux.deb.depends) {
      const re = new RegExp(`apt-get install[^\\n]*\\s${p.replace(/[.+]/g, "\\$&")}(\\s|$)`, "m");
      assert.ok(before.some((s) => re.test(s)), `el runner no instala ${p} antes de tauri-action`);
    }
    // linuxdeploy copiaría la carpeta entera de plugins (y con ella bibliotecas GPL): solo van los elegidos
    const pick = before.find((s) => s.includes("GSTREAMER_PLUGINS_DIR=") && s.includes("GITHUB_ENV"));
    assert.ok(pick, "no se eligen los plugins del AppImage (GSTREAMER_PLUGINS_DIR) antes de tauri-action");
    const chosen = pick.match(/for p in ([^;]+); do/)?.[1].trim().split(/\s+/) || [];
    for (const p of WEB_AUDIO) assert.ok(chosen.includes(p), `el AppImage no llevaría libgst${p}.so`);
    for (const p of ["aasink", "cacasink", "pipewire"]) assert.ok(!chosen.includes(p), `el AppImage llevaría libgst${p}.so`);
    // tauri#15976: el linuxdeploy de Tauri 2.12, verificado, en la caché de herramientas de Tauri antes de compilar
    const tools = before.find((s) => s.includes(LINUXDEPLOY));
    assert.ok(tools, "el AppImage se empaquetaría con el linuxdeploy viejo, que mete libwayland-client (tauri#15976)");
    assert.match(tools, /\/tauri"\n[^]*-o "\$tools\/linuxdeploy-x86_64\.AppImage"/, "el linuxdeploy nuevo no va donde lo busca Tauri 2.11");
    assert.match(tools, /echo "[0-9a-f]{64} {2}\$tools\/linuxdeploy-x86_64\.AppImage" \| sha256sum -c -/, "el linuxdeploy descargado no se verifica");
  });

  test("release.yml comprueba después de compilar el AppImage, sus licencias, el .deb y el .rpm, e imprime el tamaño", () => {
    assert.ok(check, "no hay paso que extraiga el AppImage (--appimage-extract) después de tauri-action");
    assert.ok(onLinux(check), "la comprobación debe ir solo en Linux");
    for (const needle of [...WEB_AUDIO.map((p) => `libgst${p}.so`), "GSTREAMER_PLUGINS_DIR", "GST_PLUGIN_SYSTEM_PATH_1_0",
      "stat -c %s \"$appimage\"", "dpkg -S", "libslang2", "libgpm2", "linux-appimage-licenses.txt", "/usr/share/doc/",
      "dpkg-deb -I", "rpm -qpR", "rpm -qp --recommends", "jq -r '.bundle.linux.deb.depends[]'", "jq -r '.bundle.linux.rpm.recommends[]'",
      "-name 'libwayland-client.so*'"]) {
      assert.ok(check.includes(needle), `falta en la comprobación: ${needle}`);
    }
    // pipewiresink tiene rango NONE: autoaudiosink nunca lo elige, así que no cuenta como salida
    assert.ok(!check.includes("libgstpipewire.so"), "pipewire no es una salida de audio para autoaudiosink");
    const upload = desktop.slice(checkAt + 1).find((s) => onLinux(s) && s.includes("releases/$RELEASE_ID/assets") && s.includes(".txt"));
    assert.ok(upload, "la lista de paquetes y licencias del AppImage no se sube a la Release");
  });

  test("THIRD-PARTY-NOTICES.md cita lo que lleva el AppImage, con licencia y fuentes de la Ubuntu donde se compila", () => {
    const notices = read("THIRD-PARTY-NOTICES.md");
    const codename = { "22.04": "jammy", "24.04": "noble", "26.04": "resolute" }[ubuntu];
    assert.ok(codename, `Ubuntu ${ubuntu} del contenedor de Linux: añade su nombre en clave y actualiza los enlaces de THIRD-PARTY-NOTICES.md`);
    for (const name of ["GStreamer", "WebKitGTK", "GTK 3", "LGPL", "linux-appimage-licenses.txt"]) assert.ok(notices.includes(name), name);
    const gst = ["gstreamer1.0", "gst-plugins-base1.0", "gst-plugins-good1.0"];
    for (const src of [...gst, "webkit2gtk", "gtk+3.0"]) {
      assert.ok(notices.includes(`https://launchpad.net/ubuntu/${codename}/+source/${src}`), `faltan las fuentes de ${src} (${codename})`);
    }
    // La release solo deja pasar plugins de esos tres paquetes fuente (los bad, ugly o libav no están en el aviso)
    const allow = check?.match(/grep -vxE '([^']+)'/)?.[1];
    assert.ok(allow, "la comprobación no filtra de qué paquete fuente salen los plugins");
    const re = new RegExp(`^(?:${allow})$`);
    for (const src of gst) assert.ok(re.test(src), `${src} está en el aviso pero la release lo rechaza`);
    for (const src of ["gst-plugins-bad1.0", "gst-plugins-ugly1.0", "gst-libav1.0"]) assert.ok(!re.test(src), `la release deja pasar ${src}`);
  });

  test("docs/AUDIO-NATIVO.md explica cada dependencia de audio del .deb y del .rpm", () => {
    const doc = read("docs/AUDIO-NATIVO.md");
    for (const p of [...linux.deb.depends, ...linux.rpm.recommends]) assert.ok(doc.includes(`\`${p}\``), `sin explicar: ${p}`);
  });
});
