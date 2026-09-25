/* Estado del laboratorio compartido por escritorio y móvil.
   No importa React: cada app le pasa sus hooks (createLabHook(React)). Así core sigue sin
   dependencias y las dos apps usan el mismo código para el ensayo, sus temporizadores, los logros,
   el cuaderno y los sonidos. */
import { GEOMS, BASES, INLAYS, TARGETS, TYPES } from "./data.js";
import { compute, resolveTool } from "./physics.js";
import { earnBadges, toolLabel, maxForceHint, DUEL_DEFAULT } from "./lab.js";
import { sfxForResult } from "./sfx.js";

export const RUN_MS = 1150;   // duración de la animación del banco
export const LOG_SIZE = 6;    // entradas del cuaderno

/** Selección inicial del banco: almendra de acrílico sobre una uña ajena, 4 N, arañazo de 25 mm. */
export const LAB_DEFAULTS = {
  geom: GEOMS.find((g) => g.id === "almendra"), base: BASES.find((b) => b.id === "acrilico"),
  inlay: INLAYS[0], target: TARGETS.find((t) => t.id === "una"), type: TYPES.find((t) => t.id === "aranazo"),
  force: 4, length: 25, passes: 1,
};

/**
 * Devuelve el hook useLab(play) construido con los hooks de React que le pases
 * ({ useState, useRef, useEffect }). play(id, volumen) reproduce un efecto de sonido (o nada).
 */
export function createLabHook({ useState, useRef, useEffect }) {
  return function useLab(play = () => {}) {
    const [geom, setGeom] = useState(LAB_DEFAULTS.geom);
    const [base, setBase] = useState(LAB_DEFAULTS.base);
    const [inlay, setInlay] = useState(LAB_DEFAULTS.inlay);
    const [claw, setClaw] = useState(null);
    const [tearMode, setTearMode] = useState(false);
    const [method, setMethod] = useState("rayado");
    const [strike, setStrike] = useState(false);
    const [wet, setWet] = useState(false);
    const [passes, setPasses] = useState(LAB_DEFAULTS.passes);
    const [target, setTarget] = useState(LAB_DEFAULTS.target);
    const [force, setForce] = useState(LAB_DEFAULTS.force);
    const [length, setLength] = useState(LAB_DEFAULTS.length);
    const [type, setType] = useState(LAB_DEFAULTS.type);
    const [phase, setPhase] = useState("idle");
    const [res, setRes] = useState(null);
    const [log, setLog] = useState([]);
    const [badges, setBadges] = useState(() => new Set());
    const [count, setCount] = useState(0);
    // Modo dual: el mismo ensayo en dos coches (por defecto, clásico frente a moderno)
    const [dual, setDual] = useState(false);
    const [dualPair, setDualPair] = useState(DUEL_DEFAULT);
    // Temporizadores vivos (fin de animación, sonido de impacto, fanfarria): se cancelan al cambiar
    // cualquier parámetro o repetir el ensayo, así ningún ensayo viejo pisa al nuevo.
    const timers = useRef([]);
    const clearTimers = () => { timers.current.forEach(clearTimeout); timers.current = []; };
    const later = (fn, ms) => { timers.current.push(setTimeout(fn, ms)); };
    useEffect(() => clearTimers, []);

    const reset = () => { clearTimers(); setPhase("idle"); setRes(null); };
    /** Envuelve un setter: resetea el banco y suena el clic de la interfaz. */
    const wrap = (fn, sfx = "tap") => (v) => { reset(); fn(v); if (sfx) play(sfx); };

    const params = { geom, base, inlay, target, force, length, type, method, strike, passes, wet };
    const tool = resolveTool({ geom, base, inlay, claw, wet });
    const run = () => {
      clearTimers();
      const r = compute({ ...params, claw, tear: tearMode });
      setRes(r); setPhase("running");
      later(() => setPhase("done"), RUN_MS);
      // el rayado suena mientras la punta avanza; la punción, cuando impacta
      const sfx = sfxForResult(r, target);
      if (r.puncture) later(() => play(sfx), RUN_MS * 0.78); else play(sfx);
      const runs = count + 1;
      const next = earnBadges(badges, { res: r, target, inlay, claw, method, strike, runs });
      if (next.size > badges.size) later(() => play("badge", 0.5), RUN_MS + 150);
      setBadges(next);
      setCount(runs);
      setLog((p) => [{ id: runs, tool: toolLabel({ claw, geom, inlay, res: r }), tgt: target.name, verdict: r.verdict, col: r.vcol }, ...p].slice(0, LOG_SIZE));
    };

    return {
      geom, base, inlay, claw, tearMode, method, strike, wet, passes, target, force, length, type,
      phase, res, log, badges, params, tool, maxF: maxForceHint(claw),
      strikeJ: tool.strikeJ,
      dual, dualCars: dualPair.map((id) => TARGETS.find((t) => t.id === id)),
      set: {
        geom: wrap(setGeom), base: wrap(setBase), inlay: wrap(setInlay), claw: wrap(setClaw), tearMode: wrap(setTearMode),
        method: wrap(setMethod), strike: wrap(setStrike), wet: (v) => { reset(); setWet(v); play(v ? "drip" : "tap"); },
        passes: wrap(setPasses), target: wrap(setTarget), type: wrap(setType),
        // activar el modo dual no borra el ensayo; cambiar un coche de la pareja, sí
        dual: (v) => { setDual(v); play(v ? "on" : "off"); },
        dualCar: (slot, id) => { reset(); setDualPair((p) => p.map((x, i) => (i === slot ? id : x))); play("tap"); },
        // los deslizadores no hacen clic en cada paso
        force: wrap(setForce, null), length: wrap(setLength, null), passesSlider: wrap(setPasses, null),
      },
      run,
    };
  };
}
