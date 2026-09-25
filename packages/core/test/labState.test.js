/* Tests del estado compartido del laboratorio (createLabHook) con un "React" mínimo y relojes
   simulados: cubren los dos fallos de temporizadores que tenía la interfaz. */
import { test, describe, mock, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { createLabHook, RUN_MS, LOG_SIZE, LAB_DEFAULTS, TARGETS, CLAWS, compute, DUEL_DEFAULT } from "../src/index.js";

const T = (id) => TARGETS.find((t) => t.id === id);
const K = (id) => CLAWS.find((c) => c.id === id);

/** Monta el hook con hooks falsos (mismo orden de llamada en cada render, como React). */
function mount(play) {
  const slots = [], cleanups = [];
  let i = 0;
  const fakeReact = {
    useState(init) {
      const k = i++;
      if (!(k in slots)) slots[k] = { v: typeof init === "function" ? init() : init };
      const s = slots[k];
      return [s.v, (nv) => { s.v = typeof nv === "function" ? nv(s.v) : nv; }];
    },
    useRef(init) { const k = i++; if (!(k in slots)) slots[k] = { current: init }; return slots[k]; },
    useEffect(fn) { const k = i++; if (!(k in slots)) { slots[k] = true; const c = fn(); if (c) cleanups.push(c); } },
  };
  const useLab = createLabHook(fakeReact);
  return { render: () => { i = 0; return useLab(play); }, unmount: () => cleanups.forEach((c) => c()) };
}

describe("estado del laboratorio (createLabHook)", () => {
  let sounds, lab;
  beforeEach(() => {
    mock.timers.enable({ apis: ["setTimeout"] });
    sounds = [];
    lab = mount((id) => sounds.push(id));
  });
  afterEach(() => mock.timers.reset());

  test("modo dual: empieza apagado con clásico vs moderno; activarlo no borra el ensayo y cambiar un coche sí", () => {
    let s = lab.render();
    assert.equal(s.dual, false);
    assert.deepEqual(s.dualCars.map((t) => t.id), DUEL_DEFAULT);
    s.run(); mock.timers.tick(RUN_MS); s = lab.render();
    assert.equal(s.phase, "done");
    s.set.dual(true); s = lab.render();
    assert.equal(s.dual, true);
    assert.equal(s.phase, "done", "activar el modo dual no debe borrar el ensayo");
    s.set.dualCar(1, "cochealu"); s = lab.render();
    assert.deepEqual(s.dualCars.map((t) => t.id), [DUEL_DEFAULT[0], "cochealu"]);
    assert.equal(s.phase, "idle", "cambiar un coche de la pareja resetea el banco");
    assert.ok(sounds.includes("on"), "activar el modo dual suena");
  });
  test("valores iniciales y ensayo completo: running → done a los RUN_MS", () => {
    let s = lab.render();
    assert.equal(s.geom, LAB_DEFAULTS.geom);
    assert.equal(s.phase, "idle");
    s.run();
    s = lab.render();
    assert.equal(s.phase, "running");
    assert.deepEqual(s.res, compute({ ...s.params, claw: null, tear: false }));
    mock.timers.tick(RUN_MS);
    assert.equal(lab.render().phase, "done");
  });

  test("regresión: cambiar un parámetro a mitad de animación no deja la tarjeta vacía", () => {
    lab.render().run();
    mock.timers.tick(300);
    lab.render().set.target(T("movil"));
    mock.timers.tick(RUN_MS);                      // el temporizador viejo ya habría disparado
    const s = lab.render();
    assert.equal(s.phase, "idle");
    assert.equal(s.res, null);
  });

  test("regresión: un ensayo viejo no termina antes de tiempo el nuevo", () => {
    lab.render().run();                            // A: t = 0
    mock.timers.tick(500);
    lab.render().set.target(T("vidrio"));
    mock.timers.tick(100);
    lab.render().run();                            // B: t = 600
    mock.timers.tick(700);                         // t = 1300 (A habría terminado a 1150)
    assert.equal(lab.render().phase, "running");
    mock.timers.tick(RUN_MS - 700);
    assert.equal(lab.render().phase, "done");
  });

  test("sonidos: la punción suena al impactar; un reset cancela sonidos pendientes", () => {
    let s = lab.render();
    s.set.claw(K("vibora"));
    s = lab.render();
    s.set.target(T("piel"));
    s = lab.render();
    s.set.method("puncion");
    sounds.length = 0;
    lab.render().run();
    assert.deepEqual(sounds, [], "no suena antes del impacto");
    mock.timers.tick(RUN_MS * 0.78);
    assert.equal(sounds[0], "inject");
    // nuevo ensayo y cambio inmediato: el impacto pendiente no debe sonar
    sounds.length = 0;
    lab.render().run();
    lab.render().set.force(2);                     // deslizador: resetea sin clic
    mock.timers.tick(RUN_MS * 2);
    assert.deepEqual(sounds.filter((x) => x !== "badge"), []);
  });

  test("logros con fanfarria diferida y cuaderno limitado a LOG_SIZE con ids únicos", () => {
    const s = lab.render();
    s.set.claw(K("gato"));                         // "depredador" al primer ensayo con garra
    sounds.length = 0;
    lab.render().run();
    mock.timers.tick(RUN_MS + 150);
    assert.ok(sounds.includes("badge"));
    assert.ok(lab.render().badges.has("depredador"));
    for (let k = 0; k < LOG_SIZE + 3; k++) { lab.render().run(); mock.timers.tick(RUN_MS); }
    const { log } = lab.render();
    assert.equal(log.length, LOG_SIZE);
    assert.equal(new Set(log.map((e) => e.id)).size, LOG_SIZE);
  });

  test("al desmontar no queda ningún temporizador vivo", () => {
    lab.render().run();
    lab.unmount();
    sounds.length = 0;
    mock.timers.tick(RUN_MS * 3);
    assert.deepEqual(sounds, []);
  });
});
