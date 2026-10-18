## Taller · afiladora: el ensayo de afilado paso a paso (docs/taller/afilado-simulador.md, §7 y «Integración,
## oleada 2»). Un objeto por simulación (RefCounted, sin variables estáticas ni nodos): la interfaz, la escena 3D y el
## sonido leen sus instantáneas; aquí no se pinta nada.
##
## Qué se elige: la máquina y su muela (sharpening_machines.gd), el giro (solo la amoladora regulable), el diámetro de
## una muela gastada; la herramienta (cuchillo, broca, fresa, hacha o cuchilla de cortacésped), su acero y su
## geometría; y la mano: fuerza, ángulo con plantilla o a pulso, pasadas barriendo el filo o quieto, velocidad o
## duración de la pasada, descanso entre pasadas y si se mete en agua.
## Qué se calcula en cada subpaso (DT ≤ 5 ms; 4 por fotograma a 60 fps):
## - grinding.gd: velocidad bajo carga, motor que se frena o se cala, potencia, calor a la herramienta y metal
##   arrancado. Dos llamadas por cambio de ajustes (con el agua enfriando y con el agua hirviendo, §7.2).
## - edge_thermal.gd: una sección por punto del filo (16 en un cuchillo, una por labio en una broca), con su
##   cobertura bajo la muela, su enfriamiento (película de agua, aire o inmersión) y su revenido. Las secciones no
##   comparten nada que se escriba: se avanzan en paralelo con WorkerThreadPool (una tarea por sección y tramo, con
##   prioridad alta) y se combinan en un orden fijo: el resultado es el mismo, al bit, con 1 o con N hilos.
## - sharpening_bevel.gd: el retroceso de cada cara (Q/A) hace avanzar el bisel hasta el filo; entonces sale la rebaba,
##   que se quita en el cuero (con la rueda alejándose del filo).
## - sharpening_report.gd: la nota y los consejos, con recommend_sharpening (sharpening.gd) para ángulos, abrasivo,
##   velocidad y granos.
## El reloj es un contador entero de subpasos: el estado tras k subpasos no depende de cómo se reparta el tiempo entre
## fotogramas. Por encima de 723 °C la temperatura no vale: se dice «quemado». Las temperaturas llevan ±40 %.
## Uso (siempre desde el mismo hilo; app/taller/ui/sharpen_runner.gd lo lleva a un hilo aparte con doble búfer):
##   const SharpeningSim = preload("res://core/taller/sharpening_sim.gd")
##   var sim := SharpeningSim.new({ "machine_id": "tormek_t8", "tool": { "kind": "cuchillo" } })
##   sim.start()
##   sim.advance(delta * speed)
##   var snap := sim.snapshot()        # lecturas, set_state de la escena 3D, sonido, avisos, informe…
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Rng = preload("res://core/shared/rng.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const G = preload("res://core/taller/grinding.gd")
const ET = preload("res://core/taller/edge_thermal.gd")
const Sparks = preload("res://core/taller/sparks.gd")
const Bevel = preload("res://core/taller/sharpening_bevel.gd")
const Report = preload("res://core/taller/sharpening_report.gd")

## Paso de tiempo (s): 4 subpasos por fotograma a 60 fps, dentro de los ≤ 5 ms de la especificación (§7.2).
const DT := 1.0 / 240.0
## Subpasos por tramo de trabajo en paralelo (y por punto de la gráfica): 33 ms de proceso como mucho.
const CHUNK := 8
## Temperatura del aire y del agua (°C): la de sharpening_heat.gd.
const AMBIENT_C := Heat.AMBIENT_C
## Puntos de la gráfica de temperatura: al llenarse, se juntan de dos en dos (el máximo de cada par).
const HISTORY_MAX := 4096

const TOOL_KINDS := ["cuchillo", "broca", "fresa", "hacha", "cortacesped"]
## Herramientas: nombre, secciones térmicas a lo largo del filo, materiales que se ofrecen y el de partida. La fresa no
## tiene perfil térmico en la especificación (§7.1): no se calcula su temperatura.
const KINDS := {
	"cuchillo": { "name": "Cuchillo", "sections": 16, "materials": ["x50crmov15", "vg10", "14c28n", "1095", "m2"], "steel": "x50crmov15", "edge": true },
	"hacha": { "name": "Hacha", "sections": 12, "materials": ["1095", "x50crmov15", "14c28n"], "steel": "1095", "edge": true },
	"cortacesped": { "name": "Cuchilla de cortacésped", "sections": 12, "materials": ["acero"], "steel": "acero", "edge": true },
	"broca": { "name": "Broca", "sections": 2, "materials": ["m2", "1095", "metal_duro"], "steel": "m2", "edge": false },
	"fresa": { "name": "Fresa", "sections": 0, "materials": ["m2", "metal_duro"], "steel": "m2", "edge": false },
}
## Acero de la cuchilla de cortacésped. Honda: son de acero dulce y se estropean si se calientan. No hay ficha del
## acero de las cuchillas: se usan las propiedades térmicas del 1095 (como el caso de referencia) y la energía de
## amolado del acero blando (grinding.gd, 40 J/mm³); sin curva de revenido, no se calcula la pérdida de dureza.
const MOWER_STEEL := "acero"
## Ángulo de una cuchilla de cortacésped (de un solo lado): mantener el original.
## All American Sharpener: 30° es el habitual; 35–45° para igualar el bisel de fábrica de algunas marcas.
const MOWER_ANGLE := {
	"value": 30.0, "min": 30.0, "max": 45.0, "brands_min": 35.0, "brands_max": 45.0,
	"source": Machines.SRC_MOWER_ANGLE + "; " + Machines.SRC_TOROBLADE, "quality": "secondary",
}
const MOWER_THERMAL_SOURCE := "ESTIMACIÓN: no hay ficha del acero de las cuchillas de cortacésped (Honda: acero dulce); propiedades térmicas del 1095 (HS-Folien, 1.1274), como en el caso de referencia de docs/taller/afilado-simulador.md"
const MATERIAL_NAMES := { "acero": "Acero dulce (cuchilla de cortacésped)" }

## Largo del contacto a lo largo del filo cuando el fabricante no da el ancho de la muela (mm). ESTIMACIONES, las
## mismas de los casos de referencia de afilado.json.
const CONTACT_LEN_FALLBACK := {
	"banco_lenta": { "value": 16.0, "source": "ESTIMACIÓN: VEVOR no da el ancho de la muela de la MD150-4; se toma el de la muela de 150 mm de Einhell (16 mm), como en el caso de referencia", "quality": "estimate" },
	"amoladora": { "value": 20.0, "source": "ESTIMACIÓN: franja del disco apoyada en el bisel, la de los casos de referencia (el disco de láminas no tiene ancho publicado)", "quality": "estimate" },
}

## Geometría de partida de cada herramienta (el usuario la cambia). Lo que no tiene fuente es un punto de partida
## para el ensayo, no un dato: se marca como estimación.
const TOOL_DEFAULTS := {
	"cuchillo": {
		"steel_id": "x50crmov15", "style": "occidental", "use": "cocina", "thickness_mm": 0.6, "spine_mm": 2.0,
		"height_mm": 40.0, "apex_um": 1.0, "length_mm": 200.0, "flat_um": 30.0,
		"source": "Cuchillo de referencia de docs/taller/afilado-simulador.md (0,6 mm tras el bisel, vértice de 1 µm: Verhoeven midió 0,3–4 µm); largo y filo romo, a elegir",
		"quality": "estimate",
	},
	"hacha": {
		"steel_id": "1095", "use": "hacha", "thickness_mm": 2.0, "spine_mm": 20.0, "height_mm": 70.0, "apex_um": 2.0,
		"length_mm": 90.0, "flat_um": 150.0,
		"source": "ESTIMACIÓN: hacha genérica (espesores, largo del filo y romo, a elegir); ángulo de Gränsfors Bruk (25–30°); acero al carbono como el 1095",
		"quality": "estimate",
	},
	"cortacesped": {
		"steel_id": "acero", "bevel_deg": 30.0, "thickness_mm": 3.0, "spine_mm": 3.0, "height_mm": 50.0, "apex_um": 20.0,
		"length_mm": 70.0, "flat_um": 300.0,
		"source": "Cuchilla del caso de referencia (bisel de 30° de un solo lado, 3 mm; All American Sharpener: 30° es el habitual); largo del filo y romo, a elegir (ESTIMACIÓN)",
		"quality": "estimate",
	},
	"broca": {
		"steel_id": "m2", "diameter_mm": 8.0, "lip_diff_mm": 0.0, "feed_mm_rev": 0.1, "work_material": "acero", "wear_um": 100.0,
		"source": "Punta e incidencia de sharpening.gd (TC 9-524, Nachi); avance de grinding.gd; desgaste a quitar, a elegir",
		"quality": "estimate",
	},
	"fresa": {
		"steel_id": "m2", "diameter_mm": 10.0, "teeth": 4, "work_material": "acero",
		"source": "Incidencias de sharpening.gd (TC 9-524, Nachi)",
		"quality": "primary",
	},
}

## La mano: puntos de partida por tipo de máquina (el usuario los cambia). La velocidad de barrido en las lentas es la
## de Verhoeven 2004 (≈1 pulgada por segundo en el Tormek, NOMINAL_OPERATION de sharpening.gd); la fuerza, la «ligera»
## de grinding.gd (10 N, estimación). Pasadas, descansos y duración, a elegir.
const HAND_DEFAULTS := {
	"banco": { "motion": "barrido", "sweep_mm_s": 50.0, "hold_s": 1.0, "passes": 6, "rest_s": 2.0 },
	"lenta": { "motion": "barrido", "sweep_mm_s": 25.0, "hold_s": 2.0, "passes": 20, "rest_s": 0.0 },
	"amoladora": { "motion": "barrido", "sweep_mm_s": 50.0, "hold_s": 1.0, "passes": 4, "rest_s": 3.0 },
	"broca": { "motion": "quieto", "sweep_mm_s": 25.0, "hold_s": 1.0, "passes": 6, "rest_s": 3.0 },
	"afiladora": { "motion": "quieto", "sweep_mm_s": 25.0, "hold_s": 2.0, "passes": 4, "rest_s": 1.0 },
}
const HAND_BASE := {
	"force_n": 10.0, "angle_mode": "plantilla", "wobble_deg": 3.0, "dip": false, "sides": "alternar", "mode": "periferia",
	"direction": "contra", "rest_gap_mm": 2.0, "contact_at": 0.5,
}
## Lo de la mano que cambia en marcha; el resto, al empezar el siguiente programa.
const LIVE_HAND := ["force_n", "dip", "direction", "mode", "rest_gap_mm"]
## Lo de la mano que depende de la herramienta: al cambiar de tipo vuelve a lo de partida (el ángulo, el del bisel de
## la herramienta nueva).
const KIND_HAND := ["angle_deg", "motion", "sides"]
## Pasadas por el cuero (con pasta) para quitar la rebaba. ESTIMACIÓN a partir de Verhoeven 2004 (12–15 pasadas en
## cuero con diamante de 1 µm; el cuero sin pasta no la quita): la rebaba también se dobla y se rompe.
const HONE_PASSES := { "value": 12.0, "source": "ESTIMACIÓN a partir de Verhoeven 2004, «Experiments on knife sharpening»: 12–15 pasadas en cuero con diamante de 1 µm quitan la rebaba; el cuero sin pasta no la quita", "quality": "estimate" }

## Grupos del catálogo para elegir máquina en la interfaz.
const MACHINE_GROUPS := [
	{ "id": "einhell", "name": "Einhell (banco, combinada y en húmedo)", "machines": ["einhell_tc_bg_150", "einhell_tc_wd_200_150", "einhell_tc_wg_200"] },
	{ "id": "vevor", "name": "VEVOR", "machines": ["vevor_md150g_450", "vevor_md150_4", "vevor_scm8082"] },
	{ "id": "amoladoras", "name": "Amoladoras (Einhell)", "machines": ["einhell_te_ag_125_ce", "einhell_tc_ag_125_850"] },
	{ "id": "afiladoras", "name": "Afiladoras de brocas y fresas (MRCM)", "machines": ["mrcm_mr_13a", "mrcm_mr_x3"] },
	{ "id": "referencia", "name": "Referencia", "machines": ["tormek_t8"] },
]

## Nombres de los abrasivos y de los tipos de máquina y de motor (textos de la interfaz).
const ABRASIVE_NAMES := { "al2o3": "corindón (Al₂O₃)", "sic": "carburo de silicio (SiC)", "cbn": "CBN", "diamante": "diamante (SDC)", "": "sin dato (se toma corindón)" }
const MACHINE_KIND_NAMES := {
	"banco": "esmeriladora de banco", "banco_lenta": "esmeriladora de banco lenta", "combinada": "combinada (seca y en húmedo)",
	"lenta_humeda": "lenta en húmedo", "amoladora": "amoladora", "afiladora_brocas": "afiladora de brocas",
	"afiladora_fresas": "afiladora de fresas",
}
const MOTOR_NAMES := { "induccion": "inducción", "universal": "universal (escobillas)", "universal_constante": "universal con electrónica de velocidad constante" }

# ─────────────────────────────── Estado ───────────────────────────────

## Una sección del filo: su temperatura (EdgeThermal) y su bisel. Cada tarea toca solo la suya.
class _Sec extends RefCounted:
	var et: ET = null
	var z_mm := 0.0
	var depth_a := 0.0  # retroceso de la cara A (mm; en brocas y fresas, el del flanco)
	var depth_b := 0.0
	var sharp := false
	var sharp_at := -1.0
	var burr_side := 0  # 0: sin rebaba · 1: en la cara B (se amoló la A) · 2: en la cara A
	var burr_ever := false
	var burr_removed := false
	var hone := 0.0  # pasadas por el cuero desde que salió la rebaba
	var contact_s := 0.0
	var pass_contact := 0.0  # contacto en la pasada que va (s)
	var max_pass_contact := 0.0  # el más largo de una pasada (s)
	var boiled := false
	var frame_max := -INF
	var summary: Dictionary = {}


## Envoltorio para ET.combine(): devuelve el resumen ya calculado en la tarea de la sección.
class _Cached extends RefCounted:
	var s: Dictionary = {}

	func summary() -> Dictionary:
		return s


var threads := -1  ## hilos del reparto de secciones: 1 = en serie; ≤ 0 = todos los de WorkerThreadPool

var _setup: Dictionary = {}
var _kind := "cuchillo"
var _steel := "x50crmov15"
var _machine: Dictionary = {}
var _wheel: Dictionary = {}
var _edge_len := 200.0
var _contact_len := 16.0
var _contact_len_src := ""
var _area := 16.0  # mm² con el ángulo nominal
var _contact: Dictionary = {}
var _profile: Dictionary = {}
var _geom: Dictionary = {}  # sharpening_bevel.gd
var _thermal := true
var _secs: Array = []
var _grind_base: Dictionary = {}
var _cold: Dictionary = {}
var _hot: Dictionary = {}
var _idle: Dictionary = {}
var _rec: Dictionary = {}
var _check: Dictionary = {}  # drill_check o mill_check
var _tool_sig := ""

# Programa de pasadas (fijado al empezar)
var _running := false
var _paused := false
var _finished := false
var _acc := 0.0  # tiempo pedido que aún no llega a un subpaso (s)
var _k := 0
var _k_end := 0
var _n_on := 1
var _n_per := 1
var _motion := "barrido"
var _v := 25.0
var _hold_c := 100.0
var _t_contact_pass := 1.0
var _pass_side := PackedInt32Array()
var _pass_scale := PackedFloat64Array()  # área nominal / área de la pasada (a pulso cambia el ángulo)
var _pass_beta := PackedFloat64Array()
var _dip := false
var _direction := "contra"
var _prog: Dictionary = {}  # la mano con la que empezó el programa

# Constantes del tramo (solo se leen durante las tareas)
var _fk0 := 0
var _fk1 := 0
var _kt0 := 0  # subpasos de la hoja al empezar el tramo
var _q_cold := 0.0
var _q_hot := 0.0
var _rate := 0.0  # retroceso de la cara (mm/s) con el área nominal
var _wet := false
var _honing := false
var _stalled := false
var _x0 := 0.0
var _ha0 := 0.0
var _hb0 := 0.0
var _tan_a := 0.0
var _tan_b := 0.0
var _cos_a := 1.0
var _cos_b := 1.0
var _ct_a := 0.0
var _ct_b := 0.0
var _single := false

# Historia de la hoja (hasta reset_blade). El tiempo sale del contador entero de subpasos (_kt·DT): no depende de cómo
# se reparta entre fotogramas.
var _kt := 0
var _t := 0.0
var _removed_mm3 := 0.0
var _hist_t := PackedFloat32Array()
var _hist_c := PackedFloat32Array()
var _hist_on := PackedByteArray()
var _wheel_log: Array = []  # [{ machine_id, wheel_id, grit_number, abrasive_id, honing, contact_s }]
var _events := {}  # códigos de aviso vistos durante el ensayo → { code, message, source }
var _stall_seen := false
var _overload_seen := false
var _passes_done := 0
var _report: Dictionary = {}
var _serial := 0


func _init(setup: Dictionary = {}) -> void:
	configure(setup)


# ─────────────────────────────── Ajustes ───────────────────────────────

## Cambia los ajustes (se mezclan con los actuales: { machine_id, wheel, rpm, diameter_mm, tool: {…}, hand: {…} }).
## - Otra herramienta (tipo, acero o geometría) es una hoja nueva: fría y con el filo romo del principio. Con otro tipo,
##   el ángulo, el movimiento y las caras de la mano vuelven a los de partida (KIND_HAND).
## - Otra máquina, muela, giro o diámetro para el programa en marcha (se levanta la herramienta). Al cambiar de máquina,
##   si no se dice otra cosa, su muela de partida, su giro y su diámetro de serie.
## - De la mano, la fuerza, el agua, el sentido, el modo y el apoyo cambian en marcha; el resto, al empezar el
##   siguiente programa.
func configure(p: Dictionary) -> void:
	var old := _setup.duplicate(true)
	var s := _setup.duplicate(true)
	var new_machine := p.has("machine_id") and str(p["machine_id"]) != str(old.get("machine_id", ""))
	if new_machine:
		for key in ["wheel", "rpm", "diameter_mm"]:
			if not p.has(key):
				s.erase(key)
	if p.has("wheel") and str(p["wheel"]) != str(old.get("wheel", "")) and not p.has("diameter_mm"):
		s.erase("diameter_mm")
	for key in ["machine_id", "wheel", "rpm", "diameter_mm"]:
		if p.has(key):
			s[key] = p[key]
	var tool: Dictionary = (s.get("tool", {}) as Dictionary).duplicate()
	if p.get("tool") is Dictionary:
		var pt: Dictionary = p["tool"]
		if pt.has("kind") and str(pt["kind"]) != str(tool.get("kind", "")):
			tool = {}  # otro tipo de herramienta: su geometría de partida
		tool.merge(pt, true)
	s["tool"] = _normalize_tool(tool)
	var tool_now: Dictionary = s["tool"]
	var mid := str(s.get("machine_id", ""))
	if not Machines.MACHINES.has(mid):
		mid = _default_machine(str(tool_now["kind"]))
	s["machine_id"] = mid
	var m: Dictionary = Machines.MACHINES[mid]
	if Machines.wheel(mid, str(s.get("wheel", ""))).is_empty():
		s["wheel"] = default_wheel(mid, str(tool_now["kind"]), str(tool_now["steel_id"]))
	s["wheel"] = str(s["wheel"])
	var rpm_info: Dictionary = m["motor"]["rpm_no_load"]
	s["rpm"] = Heat.input_num(s, "rpm", float(rpm_info["value"])) if rpm_info.has("steps") else float(Machines.wheel(mid, s["wheel"])["rpm"])
	s["diameter_mm"] = Heat.input_num(s, "diameter_mm", -1.0)
	var hand: Dictionary = (s.get("hand", {}) as Dictionary).duplicate()
	if str(tool_now["kind"]) != str((old.get("tool", {}) as Dictionary).get("kind", "")):
		# otra herramienta: su ángulo, su movimiento y sus caras de partida (si no se dicen en esta misma llamada)
		for key in KIND_HAND:
			hand.erase(key)
	if p.get("hand") is Dictionary:
		hand.merge(p["hand"], true)
	s["hand"] = _normalize_hand(hand, str(m["kind"]), str(tool_now["kind"]), tool_now)
	_setup = s
	var machine_changed := old.is_empty() or str(old.get("machine_id")) != mid or str(old.get("wheel")) != str(s["wheel"]) or float(old.get("rpm", 0.0)) != float(s["rpm"]) or float(old.get("diameter_mm", 0.0)) != float(s["diameter_mm"])
	var sig := var_to_str(s["tool"])
	var tool_changed := sig != _tool_sig
	_tool_sig = sig
	if (machine_changed or tool_changed) and _running:
		_stop_program()
	if _running:
		for key in LIVE_HAND:
			_prog[key] = s["hand"][key]
		_dip = bool(_prog["dip"])
		_direction = str(_prog["direction"])
	_rebuild(tool_changed)
	if not _finished:
		# (con el programa terminado, el informe es el de ese programa: no cambia al tocar los ajustes del siguiente)
		_report = Report.evaluate(_facts())
	_serial += 1


## Ajustes actuales (copia).
func setup() -> Dictionary:
	return _setup.duplicate(true)


## Hoja nueva con la misma herramienta: fría, sin revenido, con el filo romo del principio.
func reset_blade() -> void:
	_stop_program()
	_rebuild(true)
	_report = Report.evaluate(_facts())
	_serial += 1


## La muela de partida: la de afilar o acabar si es la montada y vale para el material; si no, la primera montada que
## valga; si ninguna montada vale, el recambio que sí (SDC para metal duro, CBN para HSS).
static func default_wheel(machine_id: String, _kind: String, steel_id: String) -> String:
	var m: Dictionary = Machines.MACHINES.get(machine_id, {})
	if m.is_empty():
		return ""
	var first := ""
	for w in m["wheels"]:
		if not bool(w["mounted"]) or bool(w["honing"]):
			continue
		if not Machines.abrasive_suits(str(w["abrasive_id"]), steel_id):
			continue
		if first == "":
			first = str(w["id"])
		if str(w["role"]) in ["acabado", "afilado"]:
			return str(w["id"])
	if first != "":
		return first
	for w in m["wheels"]:
		if not bool(w["honing"]) and Machines.abrasive_suits(str(w["abrasive_id"]), steel_id):
			return str(w["id"])
	return str(m["wheels"][0]["id"])


## La mano de partida para una máquina (kind del catálogo) y una herramienta.
static func default_hand(machine_kind: String, tool_kind: String) -> Dictionary:
	var key := "banco"
	if machine_kind == "lenta_humeda":
		key = "lenta"
	elif machine_kind == "amoladora":
		key = "amoladora"
	elif machine_kind in ["afiladora_brocas", "afiladora_fresas"]:
		key = "afiladora"
	elif tool_kind == "broca":
		key = "broca"
	var h: Dictionary = HAND_BASE.duplicate()
	h.merge(HAND_DEFAULTS[key], true)
	if tool_kind in ["broca", "fresa"]:
		h["motion"] = "quieto"
	return h


## Máquinas del catálogo en sus grupos, con su adecuación para una herramienta: [{ id, name, machines: [{ id, name,
## fit, why, source }] }].
static func machine_groups(tool_kind: String = "cuchillo") -> Array:
	var out: Array = []
	for g in MACHINE_GROUPS:
		var ms: Array = []
		for id in g["machines"]:
			var s := Machines.suitability(id, tool_kind)
			ms.append({ "id": id, "name": str(Machines.MACHINES[id]["name"]), "fit": s["fit"], "why": s["why"], "source": s["source"] })
		out.append({ "id": g["id"], "name": g["name"], "machines": ms })
	return out


## Ficha de la máquina para la interfaz: motor, giro, muelas (con la velocidad de cada una frente a la máxima
## marcada), apoyo, ruido, peso, fuente y calidad.
static func machine_card(machine_id: String, wheel_id: String = "", rpm: float = -1.0, diameter_mm: float = -1.0) -> Dictionary:
	var m: Dictionary = Machines.MACHINES.get(machine_id, {})
	if m.is_empty():
		return {}
	var motor: Dictionary = m["motor"]
	var rpm_info: Dictionary = motor["rpm_no_load"]
	var wheels: Array = []
	for w in m["wheels"]:
		var sel := str(w["id"]) == wheel_id
		var n := rpm if sel and rpm > 0.0 and rpm_info.has("steps") else float(w["rpm"])
		if sel and rpm_info.has("steps"):
			n = _nearest_step(rpm_info["steps"], n)
		var d := diameter_mm if sel and diameter_mm > 0.0 else float(w["diameter_mm"])
		var ws := Machines.wheel_speed(machine_id, str(w["id"]), n, d)
		wheels.append({
			"id": str(w["id"]), "role": str(w["role"]), "position": str(w["position"]), "mounted": bool(w["mounted"]),
			"selected": sel, "abrasive_id": str(w["abrasive_id"]), "abrasive_name": abrasive_name(str(w["abrasive_id"]), bool(w["honing"])),
			"abrasive_quality": str(w["abrasive_quality"]), "abrasive_note": str(w.get("abrasive_note", "")), "grit": str(w["grit"]),
			"grit_number": int(w["grit_number"]), "diameter_mm": float(w["diameter_mm"]), "diameter_min_mm": w["diameter_min_mm"],
			"width_mm": w["width_mm"], "bore_mm": w["bore_mm"], "rpm": n, "d_now_mm": d, "speed_ms": ws["speed_ms"],
			"declared_ms": ws["declared_ms"], "max_rpm": ws["max_rpm"], "max_speed_ms": ws["max_speed_ms"],
			"over_speed": ws["over_speed"], "wet": bool(w["wet"]), "honing": bool(w["honing"]), "source": str(w["source"]),
			"quality": str(w["quality"]),
		})
	var input: Dictionary = motor["input_w"]
	return {
		"id": machine_id, "name": str(m["name"]), "brand": str(m["brand"]), "model": str(m["model"]),
		"kind": str(m["kind"]), "kind_name": str(MACHINE_KIND_NAMES.get(str(m["kind"]), str(m["kind"]))),
		"market": str(m["market"]), "mains_hz": float(m["mains_hz"]),
		"motor": {
			"type": str(motor["type"]), "type_name": str(MOTOR_NAMES.get(str(motor["type"]), str(motor["type"]))),
			"input_w": float(input["value"]), "s1_w": input.get("s1"), "s2_30min_w": input.get("s2_30min"),
			"rpm_no_load": float(rpm_info["value"]), "rpm_min": rpm_info.get("min"), "rpm_max": rpm_info.get("max"),
			"steps": rpm_info.get("steps", []), "source": str(input["source"]), "quality": str(input["quality"]),
			"rpm_source": str(rpm_info["source"]), "rpm_quality": str(rpm_info["quality"]),
		},
		"wheels": wheels,
		"rest_gap_max_mm": m["rest_gap_max_mm"],
		"noise": m["noise"], "weight_kg": m["weight_kg"], "accessories": m["accessories"],
		"layout": m["layout"], "water_trough": bool(m["water_trough"]), "quench_pot": bool(m["quench_pot"]),
		"source": str(m["source"]), "quality": str(m["quality"]),
	}


## Nombre de un abrasivo (y de la rueda de cuero).
static func abrasive_name(id: String, honing: bool = false) -> String:
	if honing:
		return "cuero con pasta"
	return str(ABRASIVE_NAMES.get(id, id))


## Nombre de un material de herramienta.
static func material_name(id: String) -> String:
	if MATERIAL_NAMES.has(id):
		return str(MATERIAL_NAMES[id])
	if Heat.STEELS.has(id):
		return str(Heat.STEELS[id]["name"])
	if Sharpening.TOOL_MATERIALS.has(id):
		return str(Sharpening.TOOL_MATERIALS[id]["name"])
	return id


static func _nearest_step(steps: Array, req: float) -> float:
	var best: float = steps[0]
	for s in steps:
		if absf(float(s) - req) < absf(best - req):
			best = float(s)
	return best


## La máquina más adecuada del catálogo para una herramienta (Machines.machines_for).
static func best_machine(kind: String) -> String:
	var rows := Machines.machines_for(kind)
	return str(rows[0]["id"]) if not rows.is_empty() else "tormek_t8"


static func _default_machine(kind: String) -> String:
	return best_machine(kind)


## La fuerza de la mano en la escala de grinding.gd (HAND_FORCE, estimación): { name (la más cercana), kgf, source,
## quality }. kgf con la gravedad normal, 9,80665 m/s² (CGPM 1901).
static func hand_force_info(force_n: float) -> Dictionary:
	var best := ""
	var src := ""
	var dist := INF
	for k in G.HAND_FORCE:
		var v := float(G.HAND_FORCE[k]["value"])
		if absf(v - force_n) < dist:
			dist = absf(v - force_n)
			best = str(k).replace("_", " ")
			src = str(G.HAND_FORCE[k].get("source", ""))
	return { "name": best, "kgf": force_n / 9.80665, "source": src, "quality": "estimate" }


func _normalize_tool(t: Dictionary) -> Dictionary:
	var kind := str(t.get("kind", "cuchillo"))
	if not KINDS.has(kind):
		kind = "cuchillo"
	var out: Dictionary = (TOOL_DEFAULTS[kind] as Dictionary).duplicate()
	out.erase("source")
	out.erase("quality")
	out.merge(t, true)
	out["kind"] = kind
	var info: Dictionary = KINDS[kind]
	if not (str(out.get("steel_id", "")) in info["materials"]):
		out["steel_id"] = info["steel"]
	match kind:
		"cuchillo", "hacha":
			var rec := Sharpening.knife_angles({ "style": out.get("style", "occidental"), "use": out.get("use", "cocina") if kind == "cuchillo" else "hacha" })
			out["bevel_deg"] = clampf(Heat.input_num(out, "bevel_deg", float(rec["per_side"]["value"])), 5.0, 45.0)
			out["bevel_b_deg"] = out["bevel_deg"]
		"cortacesped":
			out["bevel_deg"] = clampf(Heat.input_num(out, "bevel_deg", 30.0), 10.0, 60.0)
			out["bevel_b_deg"] = 0.0
		"broca":
			out["diameter_mm"] = clampf(Heat.input_num(out, "diameter_mm", 8.0), 1.0, 20.0)
			var da := Sharpening.drill_angles({ "work_material": out.get("work_material", "acero"), "diameter_mm": out["diameter_mm"] })
			out["point_deg"] = clampf(Heat.input_num(out, "point_deg", float(da["point"]["value"])), 60.0, 170.0)
			out["clearance_deg"] = clampf(Heat.input_num(out, "clearance_deg", float(da["clearance"]["value"])), 0.0, 30.0)
			out["lip_diff_mm"] = clampf(Heat.input_num(out, "lip_diff_mm", 0.0), 0.0, 2.0)
			out["feed_mm_rev"] = clampf(Heat.input_num(out, "feed_mm_rev", 0.1), 0.0, 1.0)
			out["wear_um"] = clampf(Heat.input_num(out, "wear_um", 100.0), 1.0, 5000.0)
		"fresa":
			out["diameter_mm"] = clampf(Heat.input_num(out, "diameter_mm", 10.0), 1.0, 200.0)
			var ma := Sharpening.mill_angles({ "work_material": out.get("work_material", "acero"), "diameter_mm": out["diameter_mm"] })
			out["primary_deg"] = clampf(Heat.input_num(out, "primary_deg", float(ma["primary_clearance"]["value"])), 0.0, 30.0)
			out["secondary_deg"] = clampf(Heat.input_num(out, "secondary_deg", float(ma["secondary_clearance"]["value"])), 0.0, 45.0)
			out["teeth"] = clampi(int(Heat.input_num(out, "teeth", 4)), 1, 8)
	if bool(info["edge"]):
		# secciones térmicas a lo largo del filo: 16 en un cuchillo (la especificación pide 8–16); menos, solo en pruebas
		out["sections"] = clampi(int(Heat.input_num(out, "sections", float(info["sections"]))), 1, 32)
		out["thickness_mm"] = clampf(Heat.input_num(out, "thickness_mm", 0.6), 0.05, 20.0)
		out["spine_mm"] = maxf(Heat.input_num(out, "spine_mm", 2.0), float(out["thickness_mm"]))
		out["height_mm"] = clampf(Heat.input_num(out, "height_mm", 40.0), 5.0, 300.0)
		out["apex_um"] = clampf(Heat.input_num(out, "apex_um", 1.0), 0.1, 100.0)
		out["length_mm"] = clampf(Heat.input_num(out, "length_mm", 200.0), 10.0, 600.0)
		out["flat_um"] = clampf(Heat.input_num(out, "flat_um", 30.0), 1.0, 2000.0)
	return out


func _normalize_hand(h: Dictionary, machine_kind: String, tool_kind: String, tool: Dictionary) -> Dictionary:
	var out: Dictionary = default_hand(machine_kind, tool_kind)
	out.merge(h, true)
	out["force_n"] = clampf(Heat.input_num(out, "force_n", 10.0), 0.0, 200.0)
	out["motion"] = str(out.get("motion", "barrido")) if str(out.get("motion", "")) in ["barrido", "quieto"] else "barrido"
	if tool_kind in ["broca", "fresa"]:
		out["motion"] = "quieto"
	out["sweep_mm_s"] = clampf(Heat.input_num(out, "sweep_mm_s", 25.0), 1.0, 500.0)
	out["hold_s"] = clampf(Heat.input_num(out, "hold_s", 1.0), 0.02, 120.0)
	out["passes"] = clampi(int(Heat.input_num(out, "passes", 6)), 1, 200)
	out["rest_s"] = clampf(Heat.input_num(out, "rest_s", 0.0), 0.0, 60.0)
	out["dip"] = Heat.input_flag(out, "dip", false)
	out["sides"] = str(out.get("sides", "alternar")) if str(out.get("sides", "")) in ["alternar", "a", "b"] else "alternar"
	if tool_kind == "cortacesped":
		out["sides"] = "a"  # se amuela solo la cara de arriba (Toro, All American Sharpener)
	out["mode"] = "cara" if str(out.get("mode", "")) == "cara" else "periferia"
	out["direction"] = "a_favor" if str(out.get("direction", "")) == "a_favor" else "contra"
	out["angle_mode"] = "pulso" if str(out.get("angle_mode", "")) == "pulso" else "plantilla"
	out["wobble_deg"] = clampf(Heat.input_num(out, "wobble_deg", 3.0), 0.0, 15.0)
	out["rest_gap_mm"] = clampf(Heat.input_num(out, "rest_gap_mm", 2.0), 0.0, 30.0)
	out["contact_at"] = clampf(Heat.input_num(out, "contact_at", 0.5), 0.0, 1.0)
	out["angle_deg"] = clampf(Heat.input_num(out, "angle_deg", float(tool.get("bevel_deg", 20.0))), 5.0, 60.0)
	return out


## Ángulo por lado con el que se amuela: el del programa en marcha o, si no hay, el de la mano.
func _nominal_angle() -> float:
	return float(_prog["angle_deg"]) if _running and _prog.has("angle_deg") else float(_setup["hand"]["angle_deg"])


## Recalcula lo que sale de los ajustes. new_blade: herramienta nueva (secciones frías y bisel sin tocar).
func _rebuild(new_blade: bool) -> void:
	var s := _setup
	var tool: Dictionary = s["tool"]
	_kind = str(tool["kind"])
	_steel = str(tool["steel_id"])
	_machine = Machines.MACHINES[s["machine_id"]]
	_wheel = Machines.wheel(s["machine_id"], s["wheel"])
	var info: Dictionary = KINDS[_kind]
	var edge := bool(info["edge"])
	_edge_len = float(tool.get("length_mm", 0.0)) if edge else 0.0
	# Largo del contacto: el ancho de la muela (el de la ficha o la estimación), sin pasar del largo del filo
	_contact_len_src = str(_wheel["source"])
	var width: Variant = _wheel.get("width_mm")
	if width != null and str(_machine["kind"]) != "amoladora":
		_contact_len = float(width)
	else:
		var fb: Dictionary = CONTACT_LEN_FALLBACK["amoladora" if str(_machine["kind"]) == "amoladora" else "banco_lenta"]
		_contact_len = float(fb["value"])
		_contact_len_src = str(fb["source"])
	if edge:
		_contact_len = minf(_contact_len, _edge_len)
	# Perfil térmico (una vez por herramienta) y contacto
	match _kind:
		"cuchillo", "hacha", "cortacesped":
			if new_blade or _profile.is_empty():
				_profile = ET.edge_profile({
					"side_a_deg": tool["bevel_deg"], "side_b_deg": tool["bevel_b_deg"], "shoulder_mm": tool["thickness_mm"],
					"spine_mm": tool["spine_mm"], "height_mm": tool["height_mm"], "apex_um": tool["apex_um"],
				})
				_profile["kind"] = _kind
			_contact = _edge_contact(_nominal_angle())
			_area = float(_contact["area_mm2"])
		"broca":
			if new_blade or _profile.is_empty():
				_profile = ET.drill_profile({ "diameter_mm": tool["diameter_mm"], "point_deg": tool["point_deg"] })
			_area = float(_profile["heated_area_mm2"])
			_contact = { "area_mm2": _area, "contact_len_mm": 0.0, "source": str(_profile["source"]), "quality": "estimate" }
		_:
			_profile = {}
			_area = float(Sharpening.NOMINAL_OPERATION["contact_area_mm2"]["value"])
			_contact = { "area_mm2": _area, "contact_len_mm": 0.0, "source": str(Sharpening.NOMINAL_OPERATION["contact_area_mm2"]["source"]), "quality": "estimate" }
	_thermal = not _profile.is_empty() and (Heat.STEELS.has(_steel) or _steel == MOWER_STEEL)
	if new_blade:
		_new_sections(info)
	_geom = {}
	if edge:
		_geom = Bevel.blade({
			"side_a_deg": tool["bevel_deg"], "side_b_deg": tool["bevel_b_deg"], "flat_um": tool["flat_um"],
			"shoulder_mm": tool["thickness_mm"], "spine_mm": tool["spine_mm"], "height_mm": tool["height_mm"],
		})
		_prepare_bevel(_nominal_angle())
	_grind_all()
	_recommend()
	_check = {}
	if _kind == "broca":
		_check = G.drill_check({
			"diameter_mm": tool["diameter_mm"], "point_deg": tool["point_deg"], "clearance_deg": tool["clearance_deg"],
			"lip_height_diff_mm": tool["lip_diff_mm"], "feed_mm_rev": tool["feed_mm_rev"], "work_material": tool.get("work_material", "acero"),
		})
	elif _kind == "fresa":
		_check = G.mill_check({
			"diameter_mm": tool["diameter_mm"], "work_material": tool.get("work_material", "acero"),
			"primary_deg": tool["primary_deg"], "secondary_deg": tool["secondary_deg"], "wheel": "copa",
		})


## Secciones nuevas (hoja fría) y la historia a cero.
func _new_sections(info: Dictionary) -> void:
	_secs = []
	var tool: Dictionary = _setup["tool"]
	var n := int(tool.get("sections", info["sections"])) if bool(info["edge"]) else int(info["sections"])
	if _kind == "fresa":
		n = int(tool.get("teeth", 4))
	for i in n:
		var sec := _Sec.new()
		if _kind in ["broca", "fresa"]:
			sec.z_mm = float(i)
		else:
			sec.z_mm = (float(i) + 0.5) * _edge_len / float(n)
		if _thermal:
			sec.et = ET.new(_profile, _steel, AMBIENT_C, _thermal_props())
		_secs.append(sec)
	_kt = 0
	_t = 0.0
	_acc = 0.0
	_removed_mm3 = 0.0
	_hist_t = PackedFloat32Array()
	_hist_c = PackedFloat32Array()
	_hist_on = PackedByteArray()
	_wheel_log = []
	_events = {}
	_stall_seen = false
	_overload_seen = false
	_passes_done = 0
	_finished = false
	_k = 0
	_k_end = 0
	_prog = {}


## Propiedades térmicas del material: las de STEELS ({}: EdgeThermal las toma) o, en la cuchilla de cortacésped, las
## del 1095 (estimación).
func _thermal_props() -> Dictionary:
	if _steel == MOWER_STEEL:
		var th: Dictionary = (Heat.STEELS["1095"]["thermal"] as Dictionary).duplicate()
		th["source"] = MOWER_THERMAL_SOURCE
		th["quality"] = "estimate"
		return th
	return {}


## Contacto del bisel con la muela a un ángulo por lado (grinding.gd): la cara que toca, su ancho y el área.
func _edge_contact(beta: float) -> Dictionary:
	var tool: Dictionary = _setup["tool"]
	return G.edge_contact({
		"side_a_deg": beta, "side_b_deg": beta if _kind != "cortacesped" else 0.0, "shoulder_mm": tool["thickness_mm"],
		"contact_len_mm": _contact_len, "wheel_diameter_mm": float(_wheel["diameter_mm"]), "mode": _setup["hand"]["mode"],
	})


func _grind_all() -> void:
	var s := _setup
	var hand: Dictionary = s["hand"]
	_grind_base = {
		"machine_id": s["machine_id"], "wheel": s["wheel"], "force_n": hand["force_n"], "contact_area_mm2": _area,
		"steel_id": _steel, "mode": hand["mode"],
	}
	var rpm_info: Dictionary = _machine["motor"]["rpm_no_load"]
	if rpm_info.has("steps"):
		_grind_base["rpm"] = s["rpm"]
	if float(s["diameter_mm"]) > 0.0:
		_grind_base["diameter_mm"] = s["diameter_mm"]
	_cold = G.grind(_grind_base.merged({ "surface_c": AMBIENT_C }, true))
	_hot = G.grind(_grind_base.merged({ "surface_c": Heat.BURNOUT_WATER_C + 1.0 }, true))
	_idle = G.grind(_grind_base.merged({ "force_n": 0.0, "surface_c": AMBIENT_C }, true))


## grind() con los ajustes del simulador y la cara del contacto a surface_c grados (lo que usa cada subpaso).
func grind_at(surface_c: float = AMBIENT_C) -> Dictionary:
	return G.grind(_grind_base.merged({ "surface_c": surface_c }, true))


## Máquina genérica de sharpening.gd para las recomendaciones (ángulos, abrasivo, granos y velocidad recomendada).
func _generic_machine() -> String:
	var mk := str(_machine["kind"])
	if mk == "lenta_humeda" or (mk == "combinada" and bool(_wheel["wet"])):
		return "tormek_t8"
	if mk in ["afiladora_brocas", "afiladora_fresas"]:
		return "afiladora_universal"
	return "esmeriladora_banco"


func _recommend() -> void:
	var tool: Dictionary = _setup["tool"]
	var t := {
		"kind": "cuchillo" if _kind in ["hacha", "cortacesped"] else _kind, "steel_id": _steel,
		"style": tool.get("style", "occidental"), "use": "hacha" if _kind == "hacha" else tool.get("use", "cocina"),
		"work_material": tool.get("work_material", "acero"), "diameter_mm": tool.get("diameter_mm", 0.0),
		"thickness_mm": tool.get("thickness_mm", 0.0),
	}
	var ab := str(_wheel["abrasive_id"])
	var req := {
		"tool": t, "machine_id": _generic_machine(), "wheel_diameter_mm": float(_idle.get("diameter_mm", _wheel["diameter_mm"])),
		"rpm": float(_idle.get("rpm_no_load", _wheel["rpm"])), "wet": bool(_wheel["wet"]),
	}
	if ab in Sharpening.ABRASIVE_IDS:
		req["wheel_abrasive_id"] = ab
	_rec = Sharpening.recommend_sharpening(req)


# ─────────────────────────────── Programa de pasadas ───────────────────────────────

## Empieza un programa de pasadas con la mano de ahora, desde el estado de la hoja (fría si es nueva; si no, tal como
## quedó: se puede pasar de la piedra al cuero).
func start() -> void:
	var hand: Dictionary = _setup["hand"]
	_prog = hand.duplicate()
	_motion = str(hand["motion"])
	_v = float(hand["sweep_mm_s"])
	var plan := _plan(hand)
	_t_contact_pass = float(plan["t_contact_pass"])
	_n_on = int(plan["n_on"])
	_n_per = int(plan["n_per"])
	var passes := int(hand["passes"])
	_k = 0
	_acc = 0.0
	_k_end = passes * _n_per
	_hold_c = float(hand["contact_at"]) * _edge_len
	_dip = bool(hand["dip"])
	_direction = str(hand["direction"])
	# Cara (o labio, o diente) y ángulo de cada pasada
	_pass_side = PackedInt32Array()
	_pass_scale = PackedFloat64Array()
	_pass_beta = PackedFloat64Array()
	_pass_side.resize(passes)
	_pass_scale.resize(passes)
	_pass_beta.resize(passes)
	var rng := Rng.new(Rng.seed_of("pulso:%s:%s:%d" % [_kind, _steel, _wheel_log.size()]))
	var nominal := float(hand["angle_deg"])
	var sides := str(hand["sides"])
	var edge := bool(KINDS[_kind]["edge"])
	# el contacto con el ángulo nominal (el del programa)
	if edge:
		_contact = _edge_contact(nominal)
		_area = float(_contact["area_mm2"])
		_grind_all()
	for p in passes:
		var side := 0
		match _kind:
			"broca":
				side = p % 2
			"fresa":
				side = p % maxi(1, _secs.size())
			_:
				side = (p % 2) if sides == "alternar" else (1 if sides == "b" else 0)
		_pass_side[p] = side
		var beta := nominal
		var u := rng.next()
		if str(hand["angle_mode"]) == "pulso" and edge:
			beta = clampf(nominal + float(hand["wobble_deg"]) * (2.0 * u - 1.0), 5.0, 60.0)
		_pass_beta[p] = beta
		_pass_scale[p] = _area / float(_edge_contact(beta)["area_mm2"]) if edge and beta != nominal else 1.0
	_running = true
	_paused = false
	_finished = false
	_prepare_bevel(nominal)
	for sec: _Sec in _secs:
		sec.pass_contact = 0.0
	_log_wheel()
	_serial += 1


## Subpasos de un programa con esta mano: { n_on (en contacto por pasada), n_per (por pasada, con el descanso),
## t_contact_pass (lo que está cada punto del filo bajo la muela en una pasada, s) }. Quieto (y en brocas y fresas), la
## duración del contacto; barriendo, lo que tarda la muela en recorrer el filo y el tiempo de paso de su ancho.
func _plan(hand: Dictionary) -> Dictionary:
	var n_on := 1
	var t_pass := 0.0
	if _kind in ["broca", "fresa"] or str(hand["motion"]) == "quieto":
		n_on = maxi(1, int(round(float(hand["hold_s"]) / DT)))
		t_pass = float(n_on) * DT
	else:
		var v := float(hand["sweep_mm_s"])
		n_on = maxi(1, int(round((_edge_len + _contact_len) / v / DT)))
		t_pass = _contact_len / v
	var n_rest := int(round(float(hand["rest_s"]) / DT))
	return { "n_on": n_on, "n_per": n_on + n_rest, "t_contact_pass": t_pass }


## Pausa (true) o sigue (false). En pausa, advance() no hace nada.
func pause(on: bool = true) -> void:
	_paused = on and _running
	_serial += 1


## Para el programa (la herramienta se levanta de la muela).
func stop() -> void:
	_stop_program()
	_report = Report.evaluate(_facts())
	_serial += 1


func _stop_program() -> void:
	_running = false
	_paused = false
	_acc = 0.0


func is_running() -> bool:
	return _running and not _paused


func is_paused() -> bool:
	return _paused


func is_finished() -> bool:
	return _finished


## Duración del programa (s) y lo que va hecho. Sin programa (hoja nueva), lo que duraría con la mano de ahora.
func program_length_s() -> float:
	if _k_end > 0:
		return float(_k_end) * DT
	var hand: Dictionary = _setup["hand"]
	return float(int(hand["passes"]) * int(_plan(hand)["n_per"])) * DT


func program_time_s() -> float:
	return float(_k) * DT


## Constantes del bisel para el ángulo nominal: tangentes y la recta de la muela al tocar cada cara.
func _prepare_bevel(nominal: float) -> void:
	_single = _kind == "cortacesped"
	if _geom.is_empty():
		return
	var tool: Dictionary = _setup["tool"]
	var beta_b := nominal if not _single else float(tool["bevel_b_deg"])
	_x0 = float(_geom["x0"])
	_ha0 = Bevel.surface(_geom, 0, _x0)
	_hb0 = Bevel.surface(_geom, 1, _x0)
	_tan_a = tan(deg_to_rad(nominal))
	_tan_b = tan(deg_to_rad(beta_b))
	_cos_a = cos(deg_to_rad(nominal))
	_cos_b = cos(deg_to_rad(beta_b))
	_ct_a = Bevel.touch_offset(_geom, 0, nominal)
	_ct_b = Bevel.touch_offset(_geom, 1, beta_b)


func _log_wheel() -> void:
	_wheel_log.append({
		"machine_id": _setup["machine_id"], "wheel_id": str(_wheel["id"]), "grit": str(_wheel["grit"]),
		"grit_number": int(_wheel["grit_number"]), "abrasive_id": str(_wheel["abrasive_id"]),
		"honing": bool(_wheel["honing"]), "contact_s": 0.0,
	})


# ─────────────────────────────── Avance ───────────────────────────────

## Avanza sim_s segundos de proceso (en pasos de DT; lo que sobra se guarda para la siguiente llamada).
## thread_count: 1 = en serie; ≤ 0 = los de `threads`; N = N tareas. Devuelve los subpasos hechos.
func advance(sim_s: float, thread_count: int = 0) -> int:
	if not _running or _paused or not (sim_s > 0.0) or not is_finite(sim_s):
		return 0
	_acc += sim_s
	var n := int(floor(_acc / DT + 1e-9))
	n = mini(n, _k_end - _k)
	_acc = maxf(_acc - float(n) * DT, 0.0)
	var done := 0
	var tc := thread_count if thread_count != 0 else threads
	while done < n:
		var m := mini(CHUNK, n - done)
		_chunk(m, tc)
		done += m
	if _k >= _k_end:
		_complete()
	if done > 0:
		_serial += 1
	return done


## Todo el programa de una vez (sin ventana: tests y banco de pruebas), en tramos de CHUNK subpasos.
func run_program(thread_count: int = 0) -> void:
	if not _running:
		start()
	while _running and not _paused:
		var left := _k_end - _k
		if left <= 0:
			_complete()
			break
		advance(float(mini(left, CHUNK)) * DT, thread_count)


func _chunk(m: int, thread_count: int) -> void:
	_fk0 = _k
	_fk1 = _k + m
	_kt0 = _kt
	_q_cold = float(_cold["heat_flux_w_m2"])
	_q_hot = float(_hot["heat_flux_w_m2"])
	_rate = float(_cold["removal_mm3_s"]) / maxf(_area, 1e-9)
	_wet = bool(_cold["wet"])
	_honing = bool(_cold["honing"])
	_stalled = bool(_cold["stalled"])
	var n := _secs.size()
	if n > 0:
		if thread_count == 1 or n == 1:
			for i in n:
				_advance_section(i)
		else:
			var task := WorkerThreadPool.add_group_task(_advance_section, n, thread_count if thread_count > 0 else -1, true, "afilado: secciones del filo")
			WorkerThreadPool.wait_for_group_task_completion(task)
	# Lo que no es de ninguna sección: tiempo, metal arrancado, pasadas, avisos y gráfica (sumas subpaso a subpaso, para
	# que no dependan de cómo se reparte el tiempo)
	var on_steps := 0
	var q_dt := 0.0 if _stalled else float(_cold["removal_mm3_s"]) * DT
	var last: Dictionary = _wheel_log[_wheel_log.size() - 1]
	var contact_s := float(last["contact_s"])
	for k in range(_fk0, _fk1):
		var j := k % _n_per
		if j < _n_on:
			on_steps += 1
			_removed_mm3 += q_dt
			contact_s += DT
		if j == _n_per - 1:
			_passes_done += 1
	last["contact_s"] = contact_s
	if on_steps > 0:
		if _stalled:
			_stall_seen = true
		elif bool(_cold["overloaded"]):
			_overload_seen = true
	_k = _fk1
	_kt += m
	_t = float(_kt) * DT
	var fmax := -INF
	for sec: _Sec in _secs:
		fmax = maxf(fmax, sec.frame_max)
		if sec.boiled:
			_event("agua_hierve", "La cara del filo pasó de ≈130 °C: el agua hirvió en película y dejó de enfriar.", str(Heat.THRESHOLDS["burnout_water_c"]["source"]))
	if _thermal:
		var comb := combined()
		if bool(comb.get("burned", false)):
			_event("quemado", "El filo pasó de 723 °C: quemado (la cifra del modelo ya no vale; el acero se austeniza).", str(Heat.THRESHOLDS["burn_c"]["source"]))
		if float(comb.get("max_loss_hrc", 0.0)) >= 1.0:
			_event("revenido", "El filo ha perdido 1 HRC o más: se ha pasado de su revenido.", str(Heat.THRESHOLDS["hollomon_jaffe_c"]["source"]))
		if int(comb.get("tinted_sections", 0)) > 0:
			_event("color", "Ha salido color de revenido en el filo: el color llega tarde, el acero ya estaba perdiendo dureza.", "Knife Steel Nerds 2019; «The colours of tempered steel», Nature 109:106 (1922)")
		if fmax > -INF:
			_history(_t, fmax, on_steps > 0)


## Una sección durante el tramo [_fk0, _fk1): cobertura bajo la muela, calor, enfriamiento, revenido, bisel y rebaba.
## Solo lee lo común (constantes del tramo y del programa) y solo escribe su propia sección.
func _advance_section(i: int) -> void:
	var sec: _Sec = _secs[i]
	var et: ET = sec.et
	var fmax := -INF
	var half := 0.5 * _contact_len
	var tool_flank := _kind in ["broca", "fresa"]
	for k in range(_fk0, _fk1):
		var p := k / _n_per
		var j := k - p * _n_per
		var touching := j < _n_on
		if j == 0:
			sec.pass_contact = 0.0
		var cov := 0.0
		var side: int = _pass_side[p]
		if touching:
			if tool_flank:
				cov = 1.0 if i == side else 0.0
			elif _motion == "quieto":
				cov = 1.0 if absf(sec.z_mm - _hold_c) <= half else 0.0
			else:
				cov = ET.sweep_coverage(sec.z_mm, -half + _v * float(j) * DT, _contact_len, _v, DT)
		var scale: float = _pass_scale[p]
		if et != null:
			var hot := et.contact_surface_c() >= Heat.BURNOUT_WATER_C
			var q := (_q_hot if hot else _q_cold) * scale
			if hot and _wet and cov > 0.0:
				sec.boiled = true
			var cooling := "aire"
			if _wet and cov > 0.0:
				cooling = "pelicula_agua"
			elif _dip and not touching:
				cooling = "inmersion"
			et.step(DT, q if cov > 0.0 else 0.0, cov, cooling, AMBIENT_C)
			fmax = maxf(fmax, et.edge_c())
		if cov <= 0.0:
			continue
		sec.contact_s += cov * DT
		sec.pass_contact += cov * DT
		sec.max_pass_contact = maxf(sec.max_pass_contact, sec.pass_contact)
		if _honing:
			# Cuero: no arranca; con la rueda alejándose del filo, cada pasada entera cuenta para quitar la rebaba
			if _direction == "a_favor" and sec.burr_side != 0:
				sec.hone += cov * DT / maxf(_t_contact_pass, 1e-9)
				if sec.hone >= float(HONE_PASSES["value"]) - 1e-9:
					sec.burr_side = 0
					sec.burr_removed = true
			continue
		if _stalled or not (_rate > 0.0):
			continue
		var d := _rate * scale * cov * DT
		if side == 0 or tool_flank:
			sec.depth_a += d
		else:
			sec.depth_b += d
		if _geom.is_empty():
			continue
		if not sec.sharp and _thickness_x0(sec) <= 0.0:
			sec.sharp = true
			sec.sharp_at = float(_kt0 + k - _fk0 + 1) * DT
		if sec.sharp:
			# cada pasada por una cara con el filo ya hecho deja la rebaba en la otra
			sec.burr_side = 1 if side == 0 else 2
			sec.burr_ever = true
			sec.burr_removed = false
			sec.hone = 0.0
	sec.frame_max = fmax
	if et != null:
		sec.summary = et.summary()


## Espesor que queda en el plano romo (mm) con los retrocesos de la sección (≤ 0: ya hay filo).
func _thickness_x0(sec: _Sec) -> float:
	var ya := _ha0
	if sec.depth_a > 0.0:
		ya = minf(ya, _x0 * _tan_a + _ct_a - sec.depth_a / _cos_a)
	var yb := _hb0
	if sec.depth_b > 0.0 and not _single:
		yb = minf(yb, _x0 * _tan_b + _ct_b - sec.depth_b / _cos_b)
	return ya + yb


## Retroceso que falta (mm, repartido igual entre las caras que se amuelan) para llegar al filo: la raíz de una suma
## de funciones lineales a trozos (cada cara entra en min(altura de antes, recta de la muela)).
func _depth_left(sec: _Sec, use_a: bool, use_b: bool) -> float:
	if _thickness_x0(sec) <= 0.0:
		return 0.0
	if not use_a and not use_b:
		return INF
	var la := _x0 * _tan_a + _ct_a - sec.depth_a / _cos_a
	var lb := _x0 * _tan_b + _ct_b - sec.depth_b / _cos_b
	var wa := 1.0 / _cos_a if use_a else 0.0
	var wb := 1.0 / _cos_b if use_b and not _single else 0.0
	if wa == 0.0 and wb == 0.0:
		return INF
	# f(δ) = min(ha, la − wa·δ) + min(hb, lb − wb·δ): se busca el primer δ ≥ 0 con f ≤ 0
	var ya0 := _ha0 if (sec.depth_a <= 0.0 and wa == 0.0) else minf(_ha0, la)
	var yb0 := _hb0 if (sec.depth_b <= 0.0 and wb == 0.0) or _single else minf(_hb0, lb)
	var bps: Array[float] = [0.0]
	if wa > 0.0 and la > _ha0:
		bps.append((la - _ha0) / wa)
	if wb > 0.0 and lb > _hb0:
		bps.append((lb - _hb0) / wb)
	bps.sort()
	var f := func(dl: float) -> float:
		var a := ya0 if wa == 0.0 else minf(_ha0, la - wa * dl)
		var b := yb0 if wb == 0.0 else minf(_hb0, lb - wb * dl)
		return a + b
	for bi in bps.size():
		var d0: float = bps[bi]
		var f0: float = f.call(d0)
		if f0 <= 0.0:
			return d0
		var d1: float = bps[bi + 1] if bi + 1 < bps.size() else d0 + 1.0
		var f1: float = f.call(d1)
		if f1 <= 0.0 or bi + 1 >= bps.size():
			var slope := (f1 - f0) / (d1 - d0)
			if slope >= 0.0:
				return INF
			var root := d0 - f0 / slope
			if bi + 1 >= bps.size() or root <= d1:
				return root
	return INF


func _complete() -> void:
	_running = false
	_paused = false
	_finished = true
	_acc = 0.0
	_report = Report.evaluate(_facts())
	_serial += 1


func _event(code: String, message: String, source: String) -> void:
	if not _events.has(code):
		_events[code] = { "code": code, "message": message, "source": source }


func _history(t: float, c: float, on: bool) -> void:
	if _hist_t.size() >= HISTORY_MAX:
		# se juntan los puntos de dos en dos: el tiempo del segundo y el máximo de los dos
		var nt := PackedFloat32Array()
		var nc := PackedFloat32Array()
		var no := PackedByteArray()
		var i := 0
		while i + 1 < _hist_t.size():
			nt.append(_hist_t[i + 1])
			nc.append(maxf(_hist_c[i], _hist_c[i + 1]))
			no.append(1 if (_hist_on[i] != 0 or _hist_on[i + 1] != 0) else 0)
			i += 2
		_hist_t = nt
		_hist_c = nc
		_hist_on = no
	_hist_t.append(t)
	_hist_c.append(c)
	_hist_on.append(1 if on else 0)


# ─────────────────────────────── Lecturas ───────────────────────────────

func section_count() -> int:
	return _secs.size()


## Resumen de edge_thermal.gd de la sección i (el del último tramo), o {} sin temperatura.
func section_summary(i: int) -> Dictionary:
	if i < 0 or i >= _secs.size():
		return {}
	var sec: _Sec = _secs[i]
	if sec.et == null:
		return {}
	if sec.summary.is_empty():
		sec.summary = sec.et.summary()
	return sec.summary


## Las secciones combinadas en orden fijo (ET.combine con los resúmenes del último tramo) o {} sin temperatura.
func combined() -> Dictionary:
	if not _thermal or _secs.is_empty():
		return {}
	var wraps: Array = []
	for i in _secs.size():
		var c := _Cached.new()
		c.s = section_summary(i)
		wraps.append(c)
	return ET.combine(wraps)


## Resumen de la sección más caliente (la de ET.combine) o {}.
func hottest_summary() -> Dictionary:
	var c := combined()
	if c.is_empty():
		return {}
	return section_summary(int(c["hottest_section"]))


## Temperaturas de las celdas (°C) y parámetros de revenido de una sección (para las pruebas de hilos y la vista).
func section_temps(i: int) -> PackedFloat64Array:
	var sec: _Sec = _secs[i]
	return sec.et.temps() if sec.et != null else PackedFloat64Array()


func section_temper(i: int) -> PackedFloat64Array:
	var sec: _Sec = _secs[i]
	return sec.et.temper_params() if sec.et != null else PackedFloat64Array()


## Estado del bisel de la sección i.
func section_bevel(i: int) -> Dictionary:
	var sec: _Sec = _secs[i]
	return { "depth_a_um": sec.depth_a * 1000.0, "depth_b_um": sec.depth_b * 1000.0, "sharp": sec.sharp, "sharp_at_s": sec.sharp_at,
		"burr_side": sec.burr_side, "burr_ever": sec.burr_ever, "burr_removed": sec.burr_removed, "hone": sec.hone,
		"contact_s": sec.contact_s, "max_pass_contact_s": sec.max_pass_contact, "z_mm": sec.z_mm }


## Número que cambia con cada cambio de estado (la interfaz repinta solo si cambia).
func serial() -> int:
	return _serial


## Estado de la mano ahora: { touching, pass, side, contact_pos (0–1 a lo largo del filo), phase, beta }.
func _hand_now() -> Dictionary:
	var hand: Dictionary = _setup["hand"]
	if not _running or _k >= _k_end or _n_per <= 0:
		# pasadas hechas en el último programa (0 con una hoja nueva)
		var done := mini(_k / _n_per, int(_prog.get("passes", 0))) if _n_per > 0 and _k_end > 0 else 0
		return { "touching": false, "pass": done, "side": 0, "contact_pos": float(hand["contact_at"]), "phase": "fin" if _finished else "listo", "beta": float(hand["angle_deg"]) }
	var p := _k / _n_per
	var j := _k - p * _n_per
	var touching := j < _n_on
	var pos := 0.5
	if _kind in ["broca", "fresa"]:
		pos = float(_pass_side[p]) / float(maxi(1, _secs.size() - 1)) if _secs.size() > 1 else 0.5
	elif _motion == "quieto":
		pos = float(_prog.get("contact_at", 0.5))
	else:
		pos = clampf((-0.5 * _contact_len + _v * float(j) * DT) / maxf(_edge_len, 1e-9), 0.0, 1.0)
	return { "touching": touching, "pass": p + 1, "side": _pass_side[p], "contact_pos": pos, "phase": "contacto" if touching else "descanso", "beta": _pass_beta[p] }


## Instantánea completa para la interfaz, la escena 3D y el sonido. Un diccionario nuevo en cada llamada (se puede
## pasar a otro hilo): nada de lo que lleva se vuelve a escribir.
func snapshot() -> Dictionary:
	var hand: Dictionary = _setup["hand"]
	var tool: Dictionary = _setup["tool"]
	var edge := bool(KINDS[_kind]["edge"])
	var now := _hand_now()
	var touching := bool(now["touching"]) and is_running()
	var g: Dictionary = _cold if touching else _idle
	var comb := combined()
	var hs := hottest_summary()
	var temps := PackedFloat32Array()
	var tints := PackedStringArray()
	var burrs := PackedByteArray()
	var sharps := PackedByteArray()
	var cur_max := -INF
	for i in _secs.size():
		var sec: _Sec = _secs[i]
		burrs.append(sec.burr_side)
		sharps.append(1 if sec.sharp else 0)
		if sec.et != null:
			var e := sec.et.edge_c()
			temps.append(e)
			cur_max = maxf(cur_max, e)
			var tn: Variant = section_summary(i).get("tint")
			tints.append(str((tn as Dictionary)["hex"]) if tn is Dictionary else "")
	var q := float(_cold["heat_flux_w_m2"])
	var band_lo := float(_cold["heat_flux_min_w_m2"]) / q if q > 0.0 else 1.0
	var band_hi := float(_cold["heat_flux_max_w_m2"]) / q if q > 0.0 else 1.0
	var edge_now := cur_max if cur_max > -INF else AMBIENT_C
	var bevel := bevel_state()
	var sparks := _sparks(g, touching)
	var angle := float(now["beta"]) if edge else (float(tool.get("point_deg", 118.0)) / 2.0 if _kind == "broca" else float(tool.get("primary_deg", 7.0)))
	var dipped := _running and not _paused and not bool(now["touching"]) and _dip and _k < _k_end
	var state3d := {
		"angle_deg": angle,
		"force_n": float(hand["force_n"]) if touching else 0.0,
		"contact": touching,
		"contact_pos": float(now["contact_pos"]),
		"edge_temp_c": temps,
		"max_temp_c": edge_now,
		"sparks": { "rate": sparks["rate"], "color": sparks["color"], "length_mm": sparks["length_mm"] },
		"water": bool(_idle["wet"]),
		"rpm_actual": float(g["rpm"]) if _running and not _paused else 0.0,
		"burr": float(bevel["burr"]),
		"section_tint_hex": tints,
		"side": int(now["side"]),
		"dipped": dipped,
		"boiling": _events.has("agua_hierve") and touching and bool(_idle["wet"]),
	}
	return {
		"serial": _serial, "t_s": _t, "program_t_s": program_time_s(), "program_len_s": program_length_s(),
		"running": _running, "paused": _paused, "finished": _finished, "phase": now["phase"], "pass": now["pass"],
		"passes": int(_prog.get("passes", hand["passes"])) if _running or _finished else int(hand["passes"]), "passes_done": _passes_done,
		"side": ("A" if int(now["side"]) == 0 else "B") if edge and touching else "",
		"kind": _kind, "steel_id": _steel, "machine_id": _setup["machine_id"], "wheel_id": str(_wheel["id"]),
		"honing": bool(_wheel["honing"]), "abrasive_id": str(_wheel["abrasive_id"]),
		"vs_ms": g["vs_ms"], "vs_no_load_ms": _idle["vs_ms"], "rpm": g["rpm"], "rpm_no_load": _idle["rpm_no_load"],
		"max_speed_ms": _idle["max_speed_ms"], "over_speed": _idle["over_speed"],
		"load": g["load"], "overloaded": bool(_cold["overloaded"]), "stalled": bool(_cold["stalled"]),
		"force_n": float(hand["force_n"]) if touching else 0.0, "force_set_n": float(hand["force_n"]),
		"touching": touching, "dipped": dipped,
		"power_w": _cold["power_w"] if touching else 0.0, "power_set_w": _cold["power_w"],
		"power_min_w": _cold["power_min_w"], "power_max_w": _cold["power_max_w"],
		"heat_flux_w_m2": _cold["heat_flux_w_m2"], "heat_flux_min_w_m2": _cold["heat_flux_min_w_m2"], "heat_flux_max_w_m2": _cold["heat_flux_max_w_m2"],
		"partition": _cold["partition"], "coolant_effective": _cold["coolant_effective"], "water": bool(_idle["wet"]),
		"removal_mm3_s": _cold["removal_mm3_s"], "removed_mm3": _removed_mm3,
		"specific_energy_j_mm3": _cold["specific_energy_j_mm3"], "contact_area_mm2": _area, "contact_len_mm": _contact_len,
		"thermal": _thermal,
		"edge_temp_c": temps, "max_temp_c": edge_now, "peak_edge_c": comb.get("peak_edge_c", AMBIENT_C) if not comb.is_empty() else AMBIENT_C,
		"hottest_section": comb.get("hottest_section", -1),
		"temp_band": { "lo_c": AMBIENT_C + (edge_now - AMBIENT_C) * band_lo, "hi_c": AMBIENT_C + (edge_now - AMBIENT_C) * band_hi, "lo_factor": band_lo, "hi_factor": band_hi },
		"burned": bool(comb.get("burned", false)),
		"tint": hs.get("tint"), "tint_width_mm": hs.get("tint_width_mm", 0.0),
		"hardness": hs.get("hardness"), "hrc_nominal": Heat.STEELS[_steel]["hrc"]["value"] if Heat.STEELS.has(_steel) else null,
		"softened_width_mm": hs.get("softened_width_mm", 0.0), "t_over_temper_s": hs.get("t_over_temper_s", -1.0),
		"t_loss_1hrc_s": hs.get("t_loss_1hrc_s", -1.0), "max_loss_hrc": comb.get("max_loss_hrc", 0.0),
		"bevel": bevel, "burr": bevel["burr"], "section_burr": burrs, "section_sharp": sharps,
		"sparks": sparks, "sound": _sound(touching),
		"warnings": warnings(),
		"state3d": state3d,
		"section": section_view(int(comb.get("hottest_section", 0)) if not comb.is_empty() else 0),
		"history": { "t": _hist_t.duplicate(), "c": _hist_c.duplicate(), "on": _hist_on.duplicate() },
		"chart_lines": chart_lines(),
		"report": _report,
		"setup": _setup.duplicate(true),
		"rec": _rec, "check": _check,
		"view_machine": view_machine(), "view_tool": view_tool(),
		"quality": "estimate",
	}


## Avance del bisel y rebaba de toda la hoja: { edge (si hay bisel que dibujar), progress (0–1, el punto más
## atrasado; −1 si no se calcula), progress_mean, reached (parte del filo con vértice), gap_um (lo que más falta en el
## plano romo), depth_a_um, depth_b_um (medias), burr (parte con rebaba), burr_removed, burr_side, hone (pasadas por el
## cuero, mínimo), wear_um }.
func bevel_state() -> Dictionary:
	var n := _secs.size()
	var tool: Dictionary = _setup["tool"]
	var out := { "progress": 0.0, "progress_mean": 0.0, "reached": 0.0, "gap_um": 0.0, "depth_a_um": 0.0, "depth_b_um": 0.0,
		"burr": 0.0, "burr_removed": 0.0, "burr_side": "", "hone": 0.0, "edge": not _geom.is_empty(),
		"wear_um": float(tool.get("wear_um", 0.0)), "flat_um": float(tool.get("flat_um", 0.0)) }
	if n == 0:
		return out
	if _kind == "fresa":
		out["progress"] = -1.0
		out["progress_mean"] = -1.0
	var hand: Dictionary = _prog if _running else _setup["hand"]
	var use_a := str(hand.get("sides", "alternar")) != "b"
	var use_b := str(hand.get("sides", "alternar")) != "a" and not _single
	var prog_min := INF
	var prog_sum := 0.0
	var reached := 0
	var burr := 0
	var removed := 0
	var gap_max := 0.0
	var da := 0.0
	var db := 0.0
	var side_a := 0
	var side_b := 0
	var hone_min := INF
	for sec: _Sec in _secs:
		da += sec.depth_a
		db += sec.depth_b
		var prog := 0.0
		if not _geom.is_empty():
			var gap := maxf(_thickness_x0(sec), 0.0)
			gap_max = maxf(gap_max, gap * 1000.0)
			if sec.sharp or gap <= 0.0:
				prog = 1.0
				reached += 1
			else:
				var left := _depth_left(sec, use_a, use_b)
				var done_d := (sec.depth_a if use_a else 0.0) + (sec.depth_b if use_b else 0.0)
				var need := done_d + left * (float(int(use_a)) + float(int(use_b)))
				prog = clampf(done_d / need, 0.0, 1.0) if need > 0.0 and is_finite(need) else 0.0
		elif _kind == "broca":
			var wear := float(tool.get("wear_um", 0.0)) * 1e-3
			prog = clampf(sec.depth_a / wear, 0.0, 1.0) if wear > 0.0 else 0.0
			if prog >= 1.0:
				reached += 1
		prog_min = minf(prog_min, prog)
		prog_sum += prog
		if sec.burr_side != 0:
			burr += 1
			hone_min = minf(hone_min, sec.hone)
			if sec.burr_side == 1:
				side_b += 1
			else:
				side_a += 1
		if sec.burr_removed:
			removed += 1
	if _kind != "fresa":
		out["progress"] = prog_min
		out["progress_mean"] = prog_sum / float(n)
	out["reached"] = float(reached) / float(n)
	out["gap_um"] = gap_max
	out["depth_a_um"] = da / float(n) * 1000.0
	out["depth_b_um"] = db / float(n) * 1000.0
	out["burr"] = float(burr) / float(n)
	out["burr_removed"] = float(removed) / float(n)
	out["burr_side"] = "" if burr == 0 else ("B" if side_b >= side_a else "A")
	out["hone"] = hone_min if hone_min < INF else 0.0
	return out


## Sección para la vista 2D: { index, z_mm, x_mm, temp_c (celdas), tint_hex (color de la cara en cada celda),
## outline (sharpening_bevel.gd, con burr_side) }.
func section_view(i: int) -> Dictionary:
	if _secs.is_empty():
		return {}
	var idx := clampi(i, 0, _secs.size() - 1)
	var sec: _Sec = _secs[idx]
	var out := { "index": idx, "z_mm": sec.z_mm, "kind": _kind }
	if sec.et != null:
		var peaks := sec.et.surface_peaks()
		var hexes := PackedStringArray()
		for c in peaks:
			hexes.append(str(ET.tint(_steel, c).get("hex", "")))
		out["x_mm"] = _f32(sec.et.x_mm())
		out["temp_c"] = _f32(sec.et.temps())
		out["tint_hex"] = hexes
	if not _geom.is_empty():
		var tool: Dictionary = _setup["tool"]
		var beta := _nominal_angle()
		var faces := Bevel.faces_for(_geom, beta, sec.depth_a, beta if not _single else float(tool["bevel_b_deg"]), sec.depth_b if not _single else 0.0)
		var ol := Bevel.outline(_geom, faces)
		ol["burr_side"] = sec.burr_side
		ol["shoulder_x_mm"] = float(_geom["x_sh"])
		ol["x0_mm"] = float(_geom["x0"])
		out["outline"] = ol
	return out


## Líneas de la gráfica de temperatura: el revenido de fábrica del acero, los 130 °C del agua y el quemado.
func chart_lines() -> Array:
	var lines: Array = []
	if Heat.STEELS.has(_steel):
		var tp: Dictionary = Heat.STEELS[_steel]["temper"]
		lines.append({ "c": float(tp["c"]), "kind": "revenido", "label": "revenido de fábrica: %s °C" % Js.to_fixed(float(tp["c"]), 0), "source": str(tp["source"]), "quality": str(tp["quality"]) })
	lines.append({ "c": Heat.BURNOUT_WATER_C, "kind": "agua", "label": "130 °C: el agua deja de enfriar", "source": str(Heat.THRESHOLDS["burnout_water_c"]["source"]), "quality": "primary" })
	lines.append({ "c": Heat.BURN_C, "kind": "quemado", "label": "723 °C: quemado", "source": str(Heat.THRESHOLDS["burn_c"]["source"]), "quality": "primary" })
	return lines


## Avisos de ahora: los de grinding.gd con la fuerza de la mano, los que han salido en el ensayo y los propios del
## simulador, con su fuente: [{ code, message, source }].
func warnings() -> Array:
	var out: Array = []
	var seen := {}
	var lists: Array = [_cold.get("warnings", []), _events.values(), _extra_warnings()]
	for list in lists:
		for w in list:
			if not seen.has(str(w["code"])):
				out.append(w)
				seen[str(w["code"])] = true
	return out


## Avisos propios del simulador (máquina que no vale para la herramienta, apoyo, cuero al revés, sin datos térmicos).
func _extra_warnings() -> Array:
	var out: Array = []
	var fit := Machines.suitability(str(_setup["machine_id"]), _kind, _steel)
	if str(fit["fit"]) == "no":
		out.append({ "code": "maquina_no", "message": "%s no es para %s: %s" % [str(_machine["name"]), str(KINDS[_kind]["name"]).to_lower(), str(fit["why"])], "source": str(fit["source"]) })
	var hand: Dictionary = _setup["hand"]
	var gap_max: Variant = _machine.get("rest_gap_max_mm")
	if gap_max is Dictionary and float(hand["rest_gap_mm"]) > float(gap_max["value"]) + 1e-9 and str(_machine["kind"]) in ["banco", "banco_lenta", "combinada"]:
		out.append({ "code": "apoyo_lejos", "message": "El apoyo está a %s mm de la muela: el fabricante pide %s mm como mucho (la pieza se puede meter entre el apoyo y la muela)." % [_fmt(float(hand["rest_gap_mm"]), 1), _fmt(float(gap_max["value"]), 1)], "source": str(gap_max["source"]) + "; " + Machines.SRC_NPS })
	if bool(_wheel["honing"]) and str(hand["direction"]) == "contra":
		out.append({ "code": "cuero_contra", "message": "En el cuero, la rueda tiene que girar alejándose del filo: contra el filo, el filo corta el cuero y no quita la rebaba.", "source": "Tormek, «The Tormek way of sharpening»; Einhell TC-WG 200, manual; Verhoeven 2004" })
	if not _thermal:
		var why := "sin datos térmicos del material"
		if _kind == "fresa":
			why = "la especificación no define el perfil térmico del diente de una fresa"
		elif _steel == "metal_duro":
			why = "el metal duro no se reviene y aquí no están sus propiedades térmicas; su riesgo es la fisuración por calor, que no se calcula"
		out.append({ "code": "sin_temperatura", "message": "No se calcula la temperatura: %s." % why, "source": "docs/taller/afilado-simulador.md, §5 y §7.1; " + str(Sharpening.TOOL_MATERIALS["metal_duro"]["heat_note"]) })
	if _kind == "broca" and bool(hand["dip"]) and not bool(_idle["wet"]):
		out.append({ "code": "broca_agua", "message": "Si la broca está muy caliente, no la metas de golpe en agua fría: los filos pueden agrietarse.", "source": Machines.SRC_TC9524_DRILL + "; " + Machines.SRC_NPS })
	return out


## Chispas para la escena: sparks.gd con lo que arranca la muela ahora (sin contacto, ninguna).
func _sparks(g: Dictionary, touching: bool) -> Dictionary:
	var sp: Dictionary = g["sparks"]
	var rate := { "rate": float(sp["sparks"]["rate"]) if touching else 0.0 }
	return Sparks.resolve_stream(str(sp["material_id"]), rate, float(g["vs_ms"]))


## Entrada de sonido de máquina (CONTRATOS.md): la de grind() con el giro sin carga y la potencia de ahora, más el
## diámetro y el disco de la muela en uso. Máquina parada: {}. machine_sound.gd tiene cachés estáticas: frame() lo
## llama el reproductor desde el hilo principal.
func sound_input() -> Dictionary:
	var now := _hand_now()
	return _sound(bool(now["touching"]) and is_running())


func _sound(touching: bool) -> Dictionary:
	if not _running:
		return {}
	var g: Dictionary = _cold if touching else _idle
	var inp: Dictionary = (g["sound"] as Dictionary).duplicate()
	if inp.is_empty():
		return {}
	inp["diameter_mm"] = float(g["diameter_mm"])
	var wd: Variant = _wheel.get("disc_id")
	if wd != null:
		inp["disc_id"] = wd
	if _paused:
		inp["pc_kw"] = 0.0
	return inp


## Diccionario de set_machine(view) de la escena 3D (CONTRATOS.md → «Vista 3D de la afiladora»).
func view_machine() -> Dictionary:
	return Machines.view(str(_setup["machine_id"]), str(_wheel["id"]), float(_setup["diameter_mm"]))


## Diccionario de set_tool(view): { kind, steel_id, length_mm, width_mm o diameter_mm, spine_mm, … }.
func view_tool() -> Dictionary:
	var tool: Dictionary = _setup["tool"]
	var out := { "kind": _kind, "steel_id": _steel }
	match _kind:
		"broca", "fresa":
			out["diameter_mm"] = tool["diameter_mm"]
			if _kind == "broca":
				out["point_deg"] = tool["point_deg"]
			else:
				out["teeth"] = tool["teeth"]
		_:
			out["length_mm"] = tool["length_mm"]
			out["width_mm"] = tool["height_mm"]
			out["spine_mm"] = tool["spine_mm"]
			out["bevel_deg"] = tool["bevel_deg"]
			out["single_bevel"] = _single
	return out


## Diccionario de set_state(view) de la escena 3D.
func view_state() -> Dictionary:
	return snapshot()["state3d"]


## Recomendación de sharpening.gd para la herramienta con la muela de la máquina.
func recommendation() -> Dictionary:
	return _rec


## drill_check o mill_check de grinding.gd con la geometría de la herramienta ({} en las de filo).
func tool_check() -> Dictionary:
	return _check


## Informe (nota y consejos). Se calcula al terminar cada programa y al cambiar los ajustes.
func report() -> Dictionary:
	return _report


## Lo que el informe necesita saber del ensayo (números del core; la rúbrica está en sharpening_report.gd).
func _facts() -> Dictionary:
	var comb := combined()
	var max_contact := 0.0
	var contact_total := 0.0
	for sec: _Sec in _secs:
		max_contact = maxf(max_contact, sec.max_pass_contact)
		contact_total = maxf(contact_total, sec.contact_s)
	var threshold: Variant = null
	if Heat.STEELS.has(_steel) and max_contact > 0.0:
		threshold = Heat.temper_threshold_c(_steel, max_contact)
	return {
		"kind": _kind, "kind_name": str(KINDS[_kind]["name"]), "steel_id": _steel, "steel_name": material_name(_steel),
		"edge_tool": bool(KINDS[_kind]["edge"]), "single_bevel": _single,
		"machine": { "id": _setup["machine_id"], "name": str(_machine["name"]), "kind": str(_machine["kind"]),
			"steps": _machine["motor"]["rpm_no_load"].get("steps", []) },
		"wheel": { "id": str(_wheel["id"]), "grit": str(_wheel["grit"]), "grit_number": int(_wheel["grit_number"]),
			"abrasive_id": str(_wheel["abrasive_id"]), "honing": bool(_wheel["honing"]), "wet": bool(_wheel["wet"]),
			"diameter_mm": float(_idle["diameter_mm"]), "source": str(_wheel["source"]) },
		"has_leather": _has_leather(),
		"rest_gap_max_mm": _machine["rest_gap_max_mm"]["value"] if _machine["rest_gap_max_mm"] is Dictionary else null,
		"fit": Machines.suitability(str(_setup["machine_id"]), _kind, _steel),
		"best": Machines.machines_for(_kind).slice(0, 3),
		"tool": _setup["tool"], "hand": _prog if not _prog.is_empty() else _setup["hand"],
		"rec": _rec, "check": _check,
		"cold": _cold, "idle": _idle,
		"warnings": warnings(),
		"thermal": _thermal,
		"ran": _passes_done > 0 or _t > 0.0,
		"running": _running, "finished": _finished,
		"time_s": _t, "passes_done": _passes_done, "removed_mm3": _removed_mm3,
		"stall_seen": _stall_seen, "overload_seen": _overload_seen,
		"combined": comb, "hottest": hottest_summary(),
		"max_pass_contact_s": max_contact, "contact_total_s": contact_total, "temper_threshold_c": threshold,
		"bevel": bevel_state(), "wheel_log": _wheel_log.duplicate(true),
		"hone_passes": HONE_PASSES, "mower_angle": MOWER_ANGLE,
		"events": _events.duplicate(true),
		"hand_force_names": G.HAND_FORCE,
	}


func _has_leather() -> bool:
	for w in _machine["wheels"]:
		if bool(w["honing"]):
			return true
	return false


static func _f32(a: PackedFloat64Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i]
	return out


static func _fmt(x: float, decimals: int) -> String:
	var s := Js.to_fixed(x, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
