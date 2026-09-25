/* Tests de las ilustraciones (art.js) y los efectos de sonido (sfx.js) compartidos por las dos apps. */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  GEOMS, BASES, INLAYS, CLAWS, TARGETS, TYPES, PAINT_LAYERS, compute,
  MATERIAL_LOOK, PAINT_LAYER_LOOK, SKIN_LAYER_LOOK, SKIN_LAYERS, skinSectionArt, surfaceArt, grooveArt, punctureArt, nailArt, nailSideArt, clawArt, gemArt,
  BODY_LOOK, CAR_BODIES, carSectionArt, paneFractureArt,
  SFX_IDS, SFX_RATE, renderSfx, sfxForResult, encodeWav,
} from "../src/index.js";

// Recorre el grafo de escena y devuelve todos los valores de atributos (para buscar NaN/undefined).
const walk = (nodes, out = []) => { for (const n of nodes) { out.push(n.tag, ...Object.values(n.attrs)); walk(n.children, out); } return out; };
const clean = (nodes, label) => {
  for (const v of walk(nodes)) assert.ok(!(typeof v === "number" && !Number.isFinite(v)) && !String(v).includes("NaN") && v !== undefined, `${label}: atributo inválido (${v})`);
};
const all = (a) => [...(a.defs || []), ...(a.body || []), ...(a.lines || []), ...(a.extras || [])];

describe("ilustraciones (art.js)", () => {
  test("cada material y cada capa de pintura tiene aspecto y se dibuja sin NaN", () => {
    for (const t of TARGETS) assert.ok(MATERIAL_LOOK[t.id], `${t.id}: sin aspecto visual`);
    for (const l of PAINT_LAYERS) assert.ok(MATERIAL_LOOK[PAINT_LAYER_LOOK[l.id]], `capa ${l.id}: sin aspecto`);
    for (const l of SKIN_LAYERS) assert.ok(MATERIAL_LOOK[SKIN_LAYER_LOOK[l.id]], `tejido ${l.id}: sin aspecto`);
    for (const id of Object.keys(MATERIAL_LOOK)) for (const [w, h, detail] of [[300, 60, 1], [28, 20, 0.5]]) clean(all(surfaceArt(id, { w, h, detail, uid: "t" })), id);
  });
  test("es determinista: el mismo material se dibuja igual en cada render (y en las dos apps)", () => {
    assert.deepEqual(surfaceArt("madera", { w: 200, h: 40 }), surfaceArt("madera", { w: 200, h: 40 }));
    assert.deepEqual(clawArt(CLAWS[0]), clawArt(CLAWS[0]));
  });
  test("garras y colmillos: dibujo válido y punta dentro del lienzo en las dos orientaciones", () => {
    for (const c of CLAWS) for (const orient of ["up", "down"]) for (const inlay of [INLAYS[0], INLAYS.at(-1)]) {
      const a = clawArt(c, { orient, inlay, uid: "t" });
      clean(all(a), `${c.id}/${orient}`);
      assert.ok(a.tip.x >= 0 && a.tip.x <= 100 && a.tip.y >= 0 && a.tip.y <= 132, `${c.id}/${orient}: punta fuera (${a.tip.x}, ${a.tip.y})`);
      assert.ok(Number.isFinite(a.tipAngle));
    }
  });
  test("uñas (todas las formas × bases, secas y húmedas), vista lateral y gemas", () => {
    for (const g of GEOMS) for (const b of BASES) for (const wet of [false, true]) clean(all(nailArt({ geom: g, base: b, inlay: INLAYS[3], wet })), `${g.id}/${b.id}`);
    for (const b of BASES) { const s = nailSideArt({ base: b, inlay: INLAYS.at(-1), wet: true }); clean(all(s), `lado ${b.id}`); assert.deepEqual(s.tip, { x: 0, y: 0 }); }
    for (const i of INLAYS.slice(1)) clean(all(gemArt(i, 10, 10, 4)), i.id);
  });
  test("solo usa elementos SVG que pintan igual React DOM y react-native-svg (sin filtros)", () => {
    const SAFE = new Set(["g", "defs", "path", "rect", "circle", "ellipse", "line", "polygon", "polyline", "text", "linearGradient", "radialGradient", "stop", "mask", "clipPath"]);
    const tags = (nodes, out = new Set()) => { for (const n of nodes) { out.add(n.tag); tags(n.children, out); } return out; };
    const scenes = [
      ...CLAWS.map((c) => clawArt(c, { inlay: INLAYS.at(-1) })),
      ...GEOMS.map((g) => nailArt({ geom: g, base: BASES[0], inlay: INLAYS[3], wet: true })),
      ...GEOMS.map((g) => nailSideArt({ geom: g, base: BASES[0], inlay: INLAYS[3], wet: true })),
      ...Object.keys(MATERIAL_LOOK).map((id) => surfaceArt(id, { w: 120, h: 40 })),
    ];
    for (const a of scenes) for (const t of tags(all(a))) assert.ok(SAFE.has(t), `elemento SVG no soportado en las dos apps: <${t}>`);
  });
  test("el desgarro se dibuja distinto del arrastre (colgajos), salvo en los frágiles, que se astillan", () => {
    const base = { geom: GEOMS[3], base: BASES[0], inlay: INLAYS.find((i) => i.id === "tungsteno"), length: 25, type: TYPES[1], strike: false, passes: 1, method: "rayado", claw: CLAWS.find((c) => c.id === "oso"), force: 300 };
    for (const id of ["madera", "coche", "plastico", "cobre", "puertamadera", "vidrio", "piel"]) {
      const target = TARGETS.find((t) => t.id === id);
      const drag = grooveArt(id, compute({ ...base, target, tear: false }), { x1: 10, x2: 200, y: 50 });
      const tear = grooveArt(id, compute({ ...base, target, tear: true }), { x1: 10, x2: 200, y: 50 });
      if (target.brittle) assert.equal(tear.extras.filter((n) => n.tag === "polygon").length > 0, drag.extras.filter((n) => n.tag === "polygon").length > 0, `${id}: un frágil no se desgarra`);
      else assert.ok(tear.extras.length > drag.extras.length, `${id}: el desgarro no añade colgajos`);
    }
  });
  test("coches: cada carrocería tiene aspecto y su corte no tiene NaN en ninguna herida", () => {
    for (const b of Object.values(CAR_BODIES)) assert.ok(MATERIAL_LOOK[BODY_LOOK[b.id]], `carrocería ${b.id}: sin aspecto`);
    const base = { geom: GEOMS[3], base: BASES[0], length: 25, type: TYPES[1], passes: 1, tear: false };
    for (const target of TARGETS.filter((t) => t.paint)) for (const claw of [null, CLAWS[0], CLAWS[2]]) for (const inlay of [INLAYS[0], INLAYS.find((i) => i.id === "tungsteno")])
      for (const force of [1, 60, 2000]) for (const [method, strike] of [["rayado", false], ["puncion", false], ["puncion", true]]) {
        const res = compute({ ...base, target, claw, inlay, force, method, strike });
        const a = carSectionArt(res, target, { uid: "t" });
        clean(all(a), `corte ${target.id}`);
        for (const l of a.labels) assert.ok(typeof l.text === "string" && !l.text.includes("NaN") && Number.isFinite(l.x) && Number.isFinite(l.y), `${target.id}: rótulo inválido`);
      }
  });
  test("chapa perforada con pétalos, raja de lado a lado y ventana rota con grietas", () => {
    const base = { geom: GEOMS[3], base: BASES[0], length: 25, type: TYPES[1], passes: 1, tear: false };
    const eagle = { claw: CLAWS.find((c) => c.id === "aguila"), inlay: INLAYS.find((i) => i.id === "acero"), force: 20, method: "puncion", strike: true };
    for (const id of ["coche", "cocheclasico", "cochealu", "cocheplastico", "puertametal"]) {
      const target = TARGETS.find((t) => t.id === id), res = compute({ ...base, ...eagle, target });
      assert.ok(res.through, `${id}: el águila de acero debería perforarla`);
      const art = punctureArt(id, res, { cx: 100, cy: 50 });
      clean(all(art), `agujero ${id}`);
      assert.ok(art.body.filter((n) => n.tag === "polygon").length >= 4, `${id}: el agujero no tiene pétalos`);
    }
    const glass = TARGETS.find((t) => t.id === "vidrio");
    const broken = compute({ ...base, claw: CLAWS.find((c) => c.id === "oso"), inlay: INLAYS[0], force: 300, method: "puncion", strike: true, target: glass });
    assert.ok(broken.shattered, "el zarpazo de oso debería partir la ventana");
    const cracks = punctureArt("vidrio", broken, { cx: 100, cy: 50 });
    clean(all(cracks), "vidrio roto");
    assert.ok(cracks.body.filter((n) => n.tag === "path").length >= 9, "la ventana rota no tiene grietas");
    // el perfil de la huella dibuja la hoja partida aunque la punta no deje huella (depthUm = 0)
    const box = { x: 8, y: 38, w: 304, h: 56, seed: "vidrio" }, section = paneFractureArt(box);
    clean(section, "hoja partida en corte");
    assert.deepEqual(section, paneFractureArt(box), "el corte de la hoja rota debe ser determinista");
    const xy = section.flatMap((n) => (n.attrs.d || n.attrs.points).match(/-?[\d.]+/g).map(Number));
    for (let i = 0; i < xy.length; i += 2) {
      assert.ok(xy[i] >= box.x && xy[i] <= box.x + box.w && xy[i + 1] >= box.y && xy[i + 1] <= box.y + box.h, `grieta fuera de la hoja: ${xy[i]}, ${xy[i + 1]}`);
    }
    const slit = compute({ ...base, claw: CLAWS.find((c) => c.id === "oso"), inlay: INLAYS.find((i) => i.id === "diamante"), force: 2000, target: TARGETS.find((t) => t.id === "cocheplastico") });
    if (slit.through) clean(all(grooveArt("cocheplastico", slit, { x1: 10, x2: 200, y: 50 })), "raja");
  });
  test("corte de la piel por capas: sin NaN para cualquier herida, con un rótulo por capa", () => {
    const base = { geom: GEOMS[3], base: BASES[0], inlay: INLAYS[0], length: 25, type: TYPES[1], strike: false, passes: 1, target: TARGETS.find((t) => t.id === "piel") };
    for (const claw of [null, ...CLAWS]) for (const force of [0.5, 4, 30, 300, 2000]) for (const method of ["rayado", "puncion"]) for (const tear of [false, true]) {
      const res = compute({ ...base, claw, force, method, tear });
      const a = skinSectionArt(res, { uid: "t" });
      clean(all(a), `piel ${claw ? claw.id : "uña"} ${force} N ${method}`);
      for (const l of a.labels) assert.ok(Number.isFinite(l.x) && Number.isFinite(l.y) && l.text, "rótulo inválido");
    }
    assert.equal(skinSectionArt(null).labels.length, SKIN_LAYERS.length);
  });
  test("surcos y punciones para todas las combinaciones del banco", () => {
    const base = { geom: GEOMS[3], base: BASES[0], inlay: INLAYS[0], length: 25, type: TYPES[1], tear: false, strike: false, passes: 1 };
    for (const target of TARGETS) for (const claw of [null, CLAWS[0], CLAWS.at(-2)]) for (const force of [1, 30, 800]) for (const method of ["rayado", "puncion"]) for (const tear of [false, true]) {
      const res = compute({ ...base, target, claw, force, method, tear });
      clean(all(grooveArt(target.id, res, { x1: 10, x2: 200, y: 50 })), `surco ${target.id}`);
      clean(all(punctureArt(target.id, res, { cx: 100, cy: 50, fangs: !!(claw && claw.fang) })), `punción ${target.id}`);
    }
  });
});

describe("efectos de sonido (sfx.js)", () => {
  test("cada efecto se renderiza: finito, sin recortar, audible y de duración razonable", () => {
    for (const id of SFX_IDS) {
      const x = renderSfx(id);
      let peak = 0, sq = 0;
      for (const v of x) { assert.ok(Number.isFinite(v), `${id}: NaN`); peak = Math.max(peak, Math.abs(v)); sq += v * v; }
      assert.ok(peak <= 1, `${id}: recorta`);
      assert.ok(Math.sqrt(sq / x.length) > 0.01, `${id}: casi silencio`);
      assert.ok(x.length / SFX_RATE > 0.02 && x.length / SFX_RATE <= 1.2, `${id}: duración ${x.length / SFX_RATE} s`);
    }
  });
  test("determinista: el mismo efecto produce exactamente las mismas muestras", () => {
    for (const id of ["scratch-wood", "breakthrough", "badge"]) assert.deepEqual(renderSfx(id), renderSfx(id));
  });
  test("cada resultado posible del banco tiene un efecto existente", () => {
    const base = { geom: GEOMS[3], base: BASES[0], inlay: INLAYS[0], length: 25, type: TYPES[1], passes: 1 };
    const used = new Set();
    for (const target of TARGETS) for (const claw of [null, ...CLAWS]) for (const [method, strike, tear] of [["rayado", false, false], ["rayado", false, true], ["puncion", false, false], ["puncion", true, false]])
      for (const force of [0.5, 5, 60, 2000]) for (const wet of [false, true]) for (const inlay of [INLAYS[0], INLAYS.at(-1)]) {
        const id = sfxForResult(compute({ ...base, target, claw, force, method, strike, tear, wet, inlay }), target);
        assert.ok(SFX_IDS.includes(id), `efecto desconocido: ${id}`);
        used.add(id);
      }
    // todas las situaciones de ensayo tienen su sonido (los de interfaz se usan desde las apps)
    for (const id of ["slide", "squeak", "scratch-soft", "scratch-wood", "scratch-metal", "scratch-glass", "skin-rub", "skin-cut", "press", "pierce", "inject", "pierce-solid", "pierce-brittle", "breakthrough", "snap", "shatter"])
      assert.ok(used.has(id), `el efecto ${id} no se usa nunca`);
  });
  test("WAV: cabecera RIFF/WAVE, 16 bits mono y tamaño correcto", () => {
    const x = renderSfx("tap"), w = encodeWav(x), v = new DataView(w.buffer);
    assert.equal(String.fromCharCode(...w.slice(0, 4)), "RIFF");
    assert.equal(String.fromCharCode(...w.slice(8, 12)), "WAVE");
    assert.equal(v.getUint16(22, true), 1);
    assert.equal(v.getUint32(24, true), SFX_RATE);
    assert.equal(v.getUint16(34, true), 16);
    assert.equal(v.getUint32(40, true), x.length * 2);
    assert.equal(w.length, 44 + x.length * 2);
  });
});
