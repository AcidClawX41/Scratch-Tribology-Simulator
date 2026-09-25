/* Prueba de humo de la app móvil sin instalar Expo.
   Empaqueta App.js con esbuild sustituyendo react-native, react-native-svg y los módulos Expo por
   dobles mínimos (test/doubles), la renderiza con react-test-renderer y recorre la interfaz pulsando
   botones reales. Falla si algo lanza, si hay errores de React en consola o si un texto queda fuera
   de <Text> (en React Native eso tumba la app). Uso (desde la raíz): npm run test:mobile */
import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import React from "react";
import TR from "react-test-renderer";
import { APP_VERSION } from "../../../packages/core/src/index.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const D = (f) => join(here, "doubles", f);
const out = join(root, "node_modules", ".cache", "mobile-smoke.mjs");
const expo = D("expo.js");
await build({
  entryPoints: [join(here, "..", "App.js")], bundle: true, format: "esm", platform: "node", outfile: out,
  loader: { ".js": "jsx", ".wav": "text" }, logLevel: "warning", external: ["react"],
  alias: {
    "react-native": D("react-native.js"), "react-native-svg": D("svg.js"),
    "expo-linear-gradient": expo, "expo-splash-screen": expo, "expo-font": expo, "@expo-google-fonts/syne": expo,
    "@expo-google-fonts/space-mono": expo, "react-native-safe-area-context": expo, "@react-native-community/slider": expo,
    "expo-audio": expo, "expo-haptics": expo,
  },
});

// Reloj simulado para los temporizadores del laboratorio (React en Node usa setImmediate).
let now = 0;
const queue = [];
globalThis.setTimeout = (fn, ms = 0) => { queue.push({ at: now + ms, fn }); return queue.length; };
globalThis.clearTimeout = (id) => { if (queue[id - 1]) queue[id - 1].fn = null; };
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const { act } = TR;
const tick = (ms) => act(() => {
  now += ms;
  for (const t of queue.filter((x) => x.fn && x.at <= now).sort((a, b) => a.at - b.at)) { const f = t.fn; t.fn = null; f(); }
});
const consoleErrors = [];
console.error = (...a) => consoleErrors.push(a.map(String).join(" ").slice(0, 300));

const { default: App } = await import(out);
const { problems } = await import(D("errors.js"));
let r;
act(() => { r = TR.create(React.createElement(App)); });
const textOf = (n) => (typeof n === "string" ? n : n.children.map(textOf).join(""));
const all = (type) => r.root.findAll((n) => n.type === type);
const press = (re) => {
  const n = all("Pressable").find((p) => re.test(textOf(p)) || re.test(p.props.accessibilityLabel || ""));
  if (!n) throw new Error(`no encuentro el botón ${re}`);
  act(() => n.props.onPress());
};
const verdict = () => {
  const h = all("Text").find((t) => t.props.accessibilityRole === "header" && /[A-ZÁÉÍÓÚÑ]{4}/.test(textOf(t)) && !/Qué raya/.test(textOf(t)));
  return h ? textOf(h) : "(sin veredicto)";
};
const run = () => { press(/ARAÑAR/); tick(1200); return verdict(); };
const expect = (label, got, want) => { if (!want.test(got)) problems.push(`${label}: "${got}" no encaja con ${want}`); console.log(`  ${label.padEnd(34)} ${got}`); };

console.log("Recorrido de la app móvil:");
expect("uña almendra → uña ajena", run(), /ROZA|RAYA/);
for (const t of ["Piel", "Madera de pino", "Puerta de madera", "Coche moderno", "Coche clásico", "Coche de aluminio", "Aleta de plástico", "Vidrio de ventana", "Cristal de zafiro", "Diamante"]) { press(new RegExp(`^${t}`)); expect(`uña → ${t}`, run(), /./); }
press(/^Stiletto XL/); press(/^Diamante puro/); press(/^Encimera de cuarzo/); expect("Stiletto XL de diamante → cuarzo", run(), /RAYA|ROZA/);
press(/Garras y colmillos/);
press(/^Gato$/); press(/^Piel/); press(/Usar fuerza MÁX/); press(/Desgarro/); expect("gato desgarra piel", run(), /DESGARRO/);
press(/Rayado|Arrastre/); press(/^Tigre$/); expect("tigre sobre piel", run(), /LACERACI|ARAÑAZO|DESGARRO/);
press(/^Colmillo de víbora$/); press(/Punción/); expect("víbora pincha piel", run(), /PUNCIÓN/);
press(/^Casuario$/); press(/^Puerta de madera/); press(/Impacto/); press(/Usar fuerza MÁX/); expect("patada de casuario a la puerta", run(), /ATRAVIESA|PUERTA|ROZA|LACA/);
// experimentos: garra reforjada en acero contra un coche clásico, y un zarpazo de oso contra la ventana
press(/^Águila$/); press(/^Tachuela de acero/); press(/^Coche clásico/); expect("águila de acero → coche clásico", run(), /PERFORA|ATRAVIESA/);
if (!all("Text").some((t) => textOf(t) === "Garra de águila de acero")) problems.push("la ficha de la garra reforjada no dice su material");
press(/^Sin incrustación/); press(/^Oso pardo$/); press(/^Vidrio de ventana/); expect("zarpazo de oso → ventana", run(), /ROMPE EL VIDRIO/);
// modo dual: el mismo zarpazo en el coche clásico y en el moderno; luego la aleta de plástico como coche A
press(/^Activar$/);
run();
const texts = () => all("Text").map(textOf);
const reports = texts().filter((t) => t === "Energía absorbida").length;
if (reports !== 2) problems.push(`modo dual: ${reports} informes de daños tras el ensayo (esperados 2)`);
console.log(`  ${"modo dual (clásico vs moderno)".padEnd(34)} ${reports} informes de daños`);
act(() => all("Pressable").find((p) => /Comparar con aleta de plástico/.test(p.props.accessibilityHint || "")).props.onPress());
run();
const plastic = texts().filter((t) => t === "ATRAVIESA EL PLÁSTICO").length;
if (!plastic) problems.push("modo dual: el zarpazo de oso debería atravesar la aleta de plástico");
console.log(`  ${"modo dual (aleta de plástico)".padEnd(34)} ${plastic ? "ATRAVIESA EL PLÁSTICO" : "(no aparece)"}`);
press(/^Desactivar$/);
const rows = all("Pressable").filter((p) => p.props.accessibilityHint === "Usar esta herramienta");
if (rows.length !== 17) problems.push(`la comparativa tiene ${rows.length} filas (esperadas 17)`);
act(() => rows[rows.length - 1].props.onPress());
expect("fila de la comparativa", run(), /./);
press(/Ver fundamentos/);
if (!all("Text").some((t) => textOf(t) === "Fundamentos físicos")) problems.push("no se abren los fundamentos");
const footer = all("Text").map(textOf).find((t) => t.includes("Licencia MIT"));
if (!footer) problems.push("falta el aviso de licencia en el pie");
expect("versión en el pie", footer?.match(/Scratch Tribology Simulator (\S+)/)?.[1] ?? "(no aparece)", new RegExp(`^${APP_VERSION.replaceAll(".", "\\.")}$`));
press(/Sonido y vibración activados/);
expect("ensayo en silencio", run(), /./);
act(() => r.unmount());

const errs = [...new Set(consoleErrors)];
const probs = [...new Set(problems)];
for (const e of errs) console.log(`  ✗ consola: ${e}`);
for (const p of probs) console.log(`  ✗ ${p}`);
if (errs.length || probs.length) { console.log(`\nPrueba de humo móvil: FALLA (${errs.length} errores de consola, ${probs.length} problemas)`); process.exit(1); }
console.log("\nPrueba de humo móvil: OK (sin errores de consola ni textos fuera de <Text>)");
