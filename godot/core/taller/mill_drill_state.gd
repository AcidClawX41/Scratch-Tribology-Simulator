## Taller industrial · estado de la fresadora y del taladro (unidad 1e, fase 2).
##
## El gemelo de workshop_state.gd para las páginas «Fresadora» y «Taladro»: herramienta, pieza, condiciones de corte y
## máquina de cada una. Cada cambio se recalcula al momento con core/taller/cutting.gd (milling y drilling) y emite
## `changed`: la interfaz pinta, nunca calcula.
##
## Además saca de la salida del modelo lo que necesitan los esquemas animados, el sonido y los barridos, y lleva la
## animación del proceso (advance: la pasada de la fresa a lo largo de la pieza y el ciclo del taladro, a su vf real):
## - fresado (mill_engagement): el arco de contacto que ha usado el modelo, Δφ = 2π·zc/z; por dónde entra y sale cada
##   diente según la posición de la fresa (centrada, en concordancia o en oposición), y el espesor de viruta a lo
##   largo del arco, h(φ) = fz·sen κ·sen φ, cuya media en el arco es hm y cuyo máximo es hex;
## - taladrado (drill_geometry): el largo de cada filo b = (D/2)/sen(σ/2) (b·h = D·f/4, el área por filo del
##   modelo), el largo de la punta cónica y el tiempo para taladrar la profundidad pedida;
## - barridos (potencia frente a ae, empuje frente al avance…): bloques independientes en WorkerThreadPool que se
##   juntan en orden, así que el resultado no depende del número de hilos; la interfaz no espera: poll() los recoge.
## Máquinas de ejemplo con su ficha: la fresadora de torreta Lagun FTV 2 y el taladro de columna ERLO TSAR-32. Su
## potencia, su tope de giro y su rendimiento se pueden cambiar; la sobrecarga y el tope los avisa el modelo de corte.
##
## Determinista y sin nodos (CONTRATOS.md). Unidades: mm, m/min, mm/diente, mm/vuelta, mm/min, rpm, kW, N·m, N,
## cm³/min, s. Fuentes y límites: docs/taller/fresado-taladro.md.
## Uso: const MillDrillState = preload("res://core/taller/mill_drill_state.gd"); var md := MillDrillState.new()
extends RefCounted

signal changed
## Ha llegado un barrido nuevo (kind: "mill" o "drill"): sweep(kind) lo devuelve.
signal sweep_ready(kind: String)

const Cutting = preload("res://core/taller/cutting.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Chips = preload("res://core/taller/chips.gd")
const Js = preload("res://core/shared/js.gd")

const KINDS := ["mill", "drill"]

## Máquinas de ejemplo. pmax_kw y rpm_max van al modelo de corte (sobrecarga y tope de giro). El rendimiento no lo
## publica ninguna ficha: el 0,8 del modelo (TZ, p. 212, da 0,7-0,85).
const SRC_ETA := "Tabellenbuch Zerspantechnik (2015), p. 212: rendimiento de la máquina η = 0,7-0,85; se toma 0,8"
const MACHINES := {
	"mill": {
		"id": "lagun_ftv2", "name": "Fresadora de torreta Lagun FTV 2",
		"pmax_kw": 3.7, "rpm_min": 50.0, "rpm_max": 4000.0, "eta": 0.8,
		"source": "Lagun Machinery, catálogo «Fresadoras convencionales» (2016), p. 16: FTV 2, motor principal de 3,7 kW, "
			+ "50-4000 rpm a 50 Hz (60-4200 a 60 Hz) y cono ISO 40",
		"quality": "primary",
	},
	"drill": {
		"id": "erlo_tsar32", "name": "Taladro de columna ERLO TSAR-32",
		"pmax_kw": 1.1, "rpm_min": 75.0, "rpm_max": 2010.0, "eta": 0.8,
		"feeds_mm_rev": [0.1, 0.2, 0.3], "capacity_mm": 32.0,
		"source": "ERLO TSAR-32 (taladro de columna de engranajes): motor de dos velocidades de 1/1,5 HP (≈ 0,75/1,1 kW), "
			+ "75-2010 rpm, avances automáticos de 0,10, 0,20 y 0,30 mm/vuelta y Ø32 como máximo en acero de 70 kg/mm², "
			+ "según las fichas de venta de GMF Maquinaria y Rastro Máquinas",
		"quality": "secondary",
	},
}

## Tipos de fresa. tool_ids: los materiales de corte del catálogo (tool_materials.gd) con los que se fabrica cada una:
## plaquitas intercambiables en la de planear y fresa enteriza de acero rápido o de metal duro en la de mango (elección
## didáctica, no un catálogo de fabricante). kappas: ángulos de posición κr que se ofrecen (45° el del ejemplo de
## Sandvik, 90° para escuadrar). defaults: el ensayo de partida al elegir el tipo (entradas de ejemplo, no
## recomendaciones de un fabricante).
const MILL_TOOLS := {
	"planear": {
		"name": "Fresa de planear", "desc": "plato con plaquitas intercambiables",
		"tool_ids": ["hm_coated", "hm", "cermet", "ceramica_al2o3", "ceramica_si3n4", "cbn", "pcd"],
		"kappas": [45.0, 90.0],
		"defaults": {
			"dc_mm": 63.0, "z": 5, "kappa_deg": 45.0, "tool_id": "hm_coated", "vc": 180.0, "fz_mm": 0.12,
			"ap_mm": 1.5, "ae_mm": 40.0, "position": "centrada",
		},
	},
	"mango": {
		"name": "Fresa de mango", "desc": "enteriza, para ranurar, escuadrar y contornear",
		"tool_ids": ["hss_m2", "hss_co_m42", "hm", "hm_coated"],
		"kappas": [90.0],
		"defaults": {
			"dc_mm": 16.0, "z": 4, "kappa_deg": 90.0, "tool_id": "hm_coated", "vc": 120.0, "fz_mm": 0.05,
			"ap_mm": 8.0, "ae_mm": 4.0, "position": "concordancia",
		},
	},
}
## Brocas helicoidales de dos filos: de acero rápido (también con TiN) o de metal duro.
const DRILL_TOOL_IDS := ["hss_m2", "hss_co_m42", "hss_tin", "hm", "hm_coated"]

## Posición de la fresa respecto a la pieza. El modelo de potencia solo distingue la centrada (arco simétrico) de la
## lateral desde un borde; en la lateral, el sentido del giro frente al avance decide si el diente entra con la
## viruta gruesa (concordancia) o con espesor cero (oposición). El arco, hm, kc y Pc son los mismos.
const SRC_UPDOWN := (
	"Sandvik Coromant, «Down milling vs. up milling» (guía de fresado): en concordancia el espesor de viruta baja desde "
	+ "la entrada hasta cero a la salida y el filo no roza antes de cortar; en oposición empieza en cero y crece, el "
	+ "filo roza y bruñe la superficie endurecida por el diente anterior, y las fuerzas tienden a levantar la pieza; en "
	+ "concordancia la fresa tira de la pieza y la máquina tiene que eliminar la holgura del husillo de la mesa"
)
const POSITIONS := {
	"centrada": {
		"name": "Centrada", "centered": true,
		"note": "La fresa, centrada sobre la pieza: cada diente entra y sale con el mismo espesor de viruta.",
		"source": "Sandvik Coromant, Metalcutting Technical Guide (D) Milling, 2005, pp. D23-D25", "quality": "primary",
	},
	"concordancia": {
		"name": "En concordancia", "centered": false,
		"note": "El diente entra con la viruta gruesa y sale con espesor cero: no roza al entrar. La fresa tira de la "
			+ "pieza: hace falta una mesa sin holgura.",
		"source": SRC_UPDOWN, "quality": "secondary",
	},
	"oposicion": {
		"name": "En oposición", "centered": false,
		"note": "El diente entra con espesor cero y sale con la viruta gruesa: al entrar roza y bruñe la superficie, y "
			+ "las fuerzas tienden a levantar la pieza.",
		"source": SRC_UPDOWN, "quality": "secondary",
	},
}

## Muestras de h(φ) de 0 a π para el esquema (cada 2°).
const H_SAMPLES := 91

## Barridos: SWEEP_POINTS puntos, en bloques de SWEEP_BLOCK por tarea de WorkerThreadPool.
const SWEEP_POINTS := 41
const SWEEP_BLOCK := 6
## Qué se puede barrer (clave de la entrada de cutting.gd) y en qué recorrido (de interfaz). El ancho de corte va del
## 2 % al 100 % del diámetro de la fresa.
const SWEEP_AXES := {
	"mill": {
		"ae_mm": { "label": "Ancho de corte ae", "unit": "mm", "decimals": 1 },
		"fz_mm": { "label": "Avance por diente fz", "unit": "mm", "decimals": 3, "range": [0.02, 0.4] },
		"ap_mm": { "label": "Profundidad axial ap", "unit": "mm", "decimals": 1, "range": [0.2, 10.0] },
		"vc": { "label": "Velocidad de corte vc", "unit": "m/min", "decimals": 0, "range": [20.0, 400.0] },
	},
	"drill": {
		"f_mm_rev": { "label": "Avance f", "unit": "mm/vuelta", "decimals": 2, "range": [0.02, 0.5] },
		"d_mm": { "label": "Diámetro de la broca", "unit": "mm", "decimals": 1, "range": [2.0, 32.0] },
		"vc": { "label": "Velocidad de corte vc", "unit": "m/min", "decimals": 0, "range": [5.0, 120.0] },
	},
}
## Qué se lee de cada punto del barrido (claves de la salida del modelo): [clave, rótulo, unidad, decimales].
const SWEEP_OUTPUTS := {
	"mill": [
		["pmotor_kw", "Potencia en el motor", "kW", 2], ["torque_nm", "Par en el husillo", "N·m", 1],
		["fc_mean_n", "Fuerza de corte media", "N", 0], ["life_min", "Vida (Taylor, estimación)", "min", 1],
	],
	"drill": [
		["pmotor_kw", "Potencia en el motor", "kW", 2], ["thrust_n", "Empuje", "N", 0],
		["torque_nm", "Par", "N·m", 1], ["life_min", "Vida (Taylor, estimación)", "min", 1],
	],
}

## Animación del proceso (no es física: el ensayo que se ve). La fresa hace pasadas a lo largo de una pieza de
## MILL_BLOCK_D diámetros de largo (entre MILL_BLOCK_MIN y MILL_BLOCK_MAX mm), entrando y saliendo con MILL_CLEAR_MM de
## holgura; la broca baja en rápido hasta DRILL_APPROACH_MM por encima de la cara, taladra con su avance hasta que el
## diámetro entero llega a la profundidad pedida y sube en rápido. Los rápidos duran RAPID_S y entre ciclo y ciclo hay
## PAUSE_S. El avance de trabajo es el vf del modelo, a tiempo real multiplicado por la velocidad de la animación.
const ANIM_SPEEDS := [1.0, 5.0, 20.0]
const MILL_BLOCK_D := 3.0
const MILL_BLOCK_MIN := 48.0
const MILL_BLOCK_MAX := 200.0
const MILL_CLEAR_MM := 5.0
const DRILL_CLEAR_MM := 8.0
const DRILL_APPROACH_MM := 1.0
const RAPID_S := 0.6
const PAUSE_S := 0.6
## Muestras del arco de contacto para la fracción que ya está dentro de la pieza (entrada y salida de la fresa).
const ENGAGE_SAMPLES := 64

## Fundamentos de estas dos máquinas para el botón «Fundamentos» (se suman a los del taller).
const FUNDAMENTOS := [
	["Fresado", "cada diente arranca una viruta en forma de coma: su espesor es h = fz·sen κ·sen φ a lo largo del arco de contacto, y el espesor medio hm decide kc (Kienzle, Tabellenbuch Zerspantechnik). Pc = ap·ae·vf·kc/(60·10⁶) y el par, Mc = Pc·30 000/(π·n) (Sandvik Coromant)."],
	["Concordancia y oposición", "en concordancia el diente entra con la viruta gruesa y sale sin espesor; en oposición entra con espesor cero y roza antes de cortar. Sandvik Coromant prefiere la concordancia si la mesa no tiene holgura, porque la fresa tira de la pieza. El espesor medio y la potencia son los mismos."],
	["Taladrado", "los dos filos de la broca cortan cada uno la mitad del avance: h = (f/2)·sen(σ/2) y b = (D/2)/sen(σ/2). El par sale de la fuerza de los dos filos a D/4 del eje y el empuje, de Ff ≈ 0,5·kc·(D/2)·f·sen(σ/2) (Sandvik Coromant)."],
]

# ── Fresadora ──
var mill := {
	"tool_type": "planear", "dc_mm": 63.0, "z": 5, "kappa_deg": 45.0, "tool_id": "hm_coated", "work_id": "c45e",
	"speed_mode": "vc", "vc": 180.0, "rpm": 900.0, "fz_mm": 0.12, "ap_mm": 1.5, "ae_mm": 40.0,
	"position": "centrada", "wear": "nuevo", "coolant": false,
}
var mill_machine: Dictionary = _machine_params("mill")
var mill_result: Dictionary = {}

# ── Taladro ──
var drill := {
	"d_mm": 10.0, "point_angle_deg": 118.0, "tool_id": "hss_m2", "work_id": "c45e", "speed_mode": "vc", "vc": 30.0,
	"rpm": 950.0, "f_mm_rev": 0.1, "wear": "nuevo", "coolant": false, "depth_mm": 25.0,
}
var drill_machine: Dictionary = _machine_params("drill")
var drill_result: Dictionary = {}

## Marcha o paro de cada máquina (animación y sonido).
var running := { "mill": true, "drill": true }
## Velocidad de la animación de cada máquina (múltiplo del tiempo real, uno de ANIM_SPEEDS).
var anim_speed := { "mill": 1.0, "drill": 1.0 }
## Estado de la animación de la fresadora: { t_s (tiempo de la pasada), x_mm (centro de la fresa desde el principio de la
## pieza, a lo largo del avance), phase ("corte" | "pausa"), cutting, engaged (fracción de la potencia del arco completo
## que corta ahora: ∫h dφ de la parte del arco que está dentro de la pieza), pass_time_s, length_mm, passes }.
var mill_anim := {}
## Estado de la animación del taladro: { t_s (tiempo con la punta dentro), depth_mm (punta bajo la cara; negativa por
## encima), bottom_mm (lo más hondo que ha llegado la punta en este agujero), hole_mm (hondo del agujero a diámetro
## entero), phase ("aproximacion" | "taladrando" | "retirada" | "pausa"), cutting, engaged (fracción del filo que corta
## mientras entra la punta: r/(D/2)), target_mm (profundidad + punta), holes }.
var drill_anim := {}
## Qué se barre en cada máquina.
var sweep_x := { "mill": "ae_mm", "drill": "f_mm_rev" }
## false: los barridos se calculan al momento, en este hilo (tests y herramientas sin bucle de fotogramas).
var threaded := true

var _sweeps := { "mill": {}, "drill": {} }  # último barrido completo de cada máquina
var _jobs := {}  # kind → barrido en curso: { task, key, xs, blocks, mutex, serial }
var _again := {}  # kind → true si las entradas cambiaron mientras corría un barrido
var _serial := { "mill": 0, "drill": 0 }  # cambia con cada recálculo


func _init() -> void:
	_refresh("mill")
	_refresh("drill")
	reset_anim("mill")
	reset_anim("drill")


func _notification(what: int) -> void:
	# Ningún hilo puede quedar trabajando para un estado que ya no existe
	if what == NOTIFICATION_PREDELETE:
		for kind in _jobs.keys():
			WorkerThreadPool.wait_for_group_task_completion(int(_jobs[kind]["task"]))
		_jobs.clear()


# ══════════════════════════════ Fresadora ══════════════════════════════

## Cambia una entrada de la fresadora y recalcula. Otro tipo de fresa trae su ensayo de partida; un material de corte
## que no se fabrica en ese tipo, un κr que no tiene o una posición desconocida se ignoran. El ancho de corte nunca
## pasa del diámetro. Al pasar de vc a rpm (o al revés) se conserva el giro que ya había.
func set_mill(key: String, value: Variant) -> void:
	var m := mill.duplicate()
	var tool_def: Dictionary = MILL_TOOLS.get(str(m["tool_type"]), MILL_TOOLS["planear"])
	match key:
		"tool_type":
			if not MILL_TOOLS.has(str(value)):
				return
			m["tool_type"] = str(value)
			m.merge(MILL_TOOLS[str(value)]["defaults"], true)
		"tool_id":
			if not (tool_def["tool_ids"] as Array).has(str(value)):
				return
			m["tool_id"] = str(value)
		"kappa_deg":
			if not (tool_def["kappas"] as Array).has(float(value)):
				return
			m["kappa_deg"] = float(value)
		"position":
			if not POSITIONS.has(str(value)):
				return
			m["position"] = str(value)
		"work_id":
			if WorkMaterials.get_material(str(value)).is_empty():
				return
			m["work_id"] = str(value)
		"speed_mode":
			if not (str(value) in ["vc", "rpm"]):
				return
			m["speed_mode"] = str(value)
			_keep_speed(m, mill_result)
		"z":
			m["z"] = maxi(1, int(value))
		"wear":
			m["wear"] = str(value)
		"coolant":
			m["coolant"] = bool(value)
		"dc_mm", "vc", "rpm", "fz_mm", "ap_mm", "ae_mm":
			m[key] = float(value)
		_:
			return
	m["ae_mm"] = minf(float(m["ae_mm"]), float(m["dc_mm"]))
	mill = m
	_refresh("mill")
	changed.emit()


## Entrada de Cutting.milling con los parámetros de la fresadora y su máquina.
func mill_request() -> Dictionary:
	var m := mill
	var p := {
		"work_id": m["work_id"], "tool_id": m["tool_id"], "dc_mm": m["dc_mm"], "z": m["z"], "fz_mm": m["fz_mm"],
		"ap_mm": m["ap_mm"], "ae_mm": m["ae_mm"], "kappa_deg": m["kappa_deg"],
		"centered": bool(POSITIONS[str(m["position"])]["centered"]), "wear": m["wear"],
		"machine": mill_machine.duplicate(),
	}
	if m["speed_mode"] == "rpm":
		p["rpm"] = m["rpm"]
	else:
		p["vc"] = m["vc"]
	return p


## Arco de contacto de la fresa y espesor de viruta a lo largo de él, sacados de la salida del modelo ({} si el modelo
## no pudo calcular el contacto: faltan datos). Ángulos en radianes, medidos desde la normal a la dirección de avance
## en el sentido de giro (horario visto desde arriba, M03), como en cutting.gd; el diente entra en phi_in y sale en
## phi_out. Devuelve:
##   { phi_in, phi_out, contact_deg, position, centered, climb: bool | null, material_side: 1 (lado de φ = 0, el de
##     la oposición) · −1 (el de la concordancia) · 0 (centrada), h_scale_mm (= fz·sen κ), h_samples (h cada 2° de 0
##     a 180°), hm_mm, hex_mm, entry_h_mm, exit_h_mm, zc, z, dc_mm, ae_mm (el que usó el modelo), chip_color }
func mill_engagement() -> Dictionary:
	return engagement_of(mill_result, int(mill["z"]), str(mill["position"]), float(mill["kappa_deg"]),
		float(mill["dc_mm"]), str(WorkMaterials.get_material(str(mill["work_id"])).get("kind", "acero")))


## La misma cuenta de mill_engagement para una salida cualquiera de Cutting.milling (tests y barridos).
## Δφ = 2π·zc/z es el arco que ha usado el modelo (zc = dientes en corte de media). Centrada: simétrico respecto a la
## dirección de avance. Oposición: de 0 a Δφ (entra con espesor cero). Concordancia: de π − Δφ a π (entra gruesa).
static func engagement_of(r: Dictionary, z: int, position: String, kappa_deg: float, dc_mm: float,
		work_kind: String) -> Dictionary:
	if r.get("zc") == null or r.get("fz_mm") == null or z < 1 or not POSITIONS.has(position):
		return {}
	var dphi := TAU * float(r["zc"]) / float(z)
	var centered: bool = POSITIONS[position]["centered"]
	var phi_in := 0.0
	var phi_out := dphi
	var side := 1
	var climb: Variant = false
	if centered:
		phi_in = (PI - dphi) / 2.0
		phi_out = PI - phi_in
		side = 0
		climb = null
	elif position == "concordancia":
		phi_in = PI - dphi
		phi_out = PI
		side = -1
		climb = true
	var hs := float(r["fz_mm"]) * sin(deg_to_rad(kappa_deg))
	var samples := PackedFloat64Array()
	samples.resize(H_SAMPLES)
	for i in H_SAMPLES:
		samples[i] = hs * sin(PI * float(i) / float(H_SAMPLES - 1))
	# El ae que usó el modelo (lo limita al diámetro): sale del mismo arco
	var ae_used := dc_mm * (cos(phi_in) - cos(phi_out)) / 2.0 if centered else dc_mm * (1.0 - cos(dphi)) / 2.0
	return {
		"phi_in": phi_in, "phi_out": phi_out, "contact_deg": rad_to_deg(dphi), "position": position,
		"centered": centered, "climb": climb, "material_side": side, "h_scale_mm": hs, "h_samples": samples,
		"hm_mm": r.get("hm_mm"), "hex_mm": r.get("hex_mm"), "entry_h_mm": hs * sin(phi_in),
		"exit_h_mm": hs * sin(phi_out), "zc": r["zc"], "z": z, "dc_mm": dc_mm, "ae_mm": ae_used,
		"chip_color": Chips.temper_color(work_kind, float(r.get("vc", 0.0)) if r.get("vc") != null else 0.0),
	}


## Espesor de viruta (mm) en el ángulo phi del arco de contacto de un engagement (mill_engagement): h = fz·sen κ·sen φ
## dentro del arco y 0 fuera (ahí el diente no corta). La interfaz lo pide para el diente que dibuja.
static func chip_h(eng: Dictionary, phi: float) -> float:
	if eng.is_empty() or phi < float(eng["phi_in"]) - 1e-9 or phi > float(eng["phi_out"]) + 1e-9:
		return 0.0
	return float(eng["h_scale_mm"]) * maxf(sin(phi), 0.0)


## Entrada de sonido de la fresadora (CONTRATOS.md): paso de dientes z·n/60. load: fracción de la potencia de corte
## que se oye (1 = el arco entero dentro de la pieza); < 0, la de la animación (0 si la fresa está fuera de la pieza).
## Parada, sin giro; sin datos de fuerza (madera, plásticos), sin carga.
func mill_sound_input(load: float = -1.0) -> Dictionary:
	var f := load
	if f < 0.0:
		f = float(mill_anim.get("engaged", 0.0)) if bool(mill_anim.get("cutting", false)) else 0.0
	return _sound_input("mill", mill_result, int(mill["z"]), float(mill["dc_mm"]), str(mill["work_id"]),
		bool(mill["coolant"]), float(mill_machine["pmax_kw"]), bool(running["mill"]), f)


# ══════════════════════════════ Taladro ══════════════════════════════

## Cambia una entrada del taladro y recalcula (el material de corte, entre los de las brocas; al pasar de vc a rpm, o al
## revés, se conserva el giro que ya había).
func set_drill(key: String, value: Variant) -> void:
	var d := drill.duplicate()
	match key:
		"tool_id":
			if not DRILL_TOOL_IDS.has(str(value)):
				return
			d["tool_id"] = str(value)
		"work_id":
			if WorkMaterials.get_material(str(value)).is_empty():
				return
			d["work_id"] = str(value)
		"speed_mode":
			if not (str(value) in ["vc", "rpm"]):
				return
			d["speed_mode"] = str(value)
			_keep_speed(d, drill_result)
		"wear":
			d["wear"] = str(value)
		"coolant":
			d["coolant"] = bool(value)
		"d_mm", "point_angle_deg", "vc", "rpm", "f_mm_rev", "depth_mm":
			d[key] = float(value)
		_:
			return
	drill = d
	_refresh("drill")
	changed.emit()


## Entrada de Cutting.drilling con los parámetros del taladro y su máquina.
func drill_request() -> Dictionary:
	var d := drill
	var p := {
		"work_id": d["work_id"], "tool_id": d["tool_id"], "d_mm": d["d_mm"], "f_mm_rev": d["f_mm_rev"],
		"point_angle_deg": d["point_angle_deg"], "wear": d["wear"], "machine": drill_machine.duplicate(),
	}
	if d["speed_mode"] == "rpm":
		p["rpm"] = d["rpm"]
	else:
		p["vc"] = d["vc"]
	return p


## Geometría de la broca y del agujero para el esquema, con los números del modelo:
##   { d_mm, sigma_deg, lips (2), f_mm_rev, fz_mm (= f/2, lo que corta cada filo), h_mm (del modelo), b_mm (largo de
##     cada filo, (D/2)/sen(σ/2)), area_mm2 (b·h = D·f/4 por filo), tip_mm (largo de la punta, (D/2)/tan(σ/2)),
##     depth_mm, time_s ((profundidad + punta)/vf, o null sin avance), helix (tipo de hélice para dibujar la broca),
##     point_rec (ángulo de punta recomendado para el material, de sharpening.gd, o {}), chip_color }
func drill_geometry() -> Dictionary:
	var d := drill
	var r := drill_result
	var dd := float(d["d_mm"])
	var sigma := float(d["point_angle_deg"])
	var half := deg_to_rad(sigma / 2.0)
	var f := float(d["f_mm_rev"])
	var kind := str(WorkMaterials.get_material(str(d["work_id"])).get("kind", "acero"))
	var b := dd / 2.0 / sin(half) if dd > 0.0 and sigma > 0.0 and sigma < 180.0 else NAN
	var tip := dd / 2.0 / tan(half) if dd > 0.0 and sigma > 0.0 and sigma < 180.0 else NAN
	var h: Variant = r.get("h_mm")
	var vf: Variant = r.get("vf_mm_min")
	var time: Variant = null
	if vf != null and float(vf) > 0.0 and not is_nan(tip):
		time = (float(d["depth_mm"]) + tip) / float(vf) * 60.0
	return {
		"d_mm": dd, "sigma_deg": sigma, "lips": 2, "f_mm_rev": f, "fz_mm": f / 2.0, "h_mm": h, "b_mm": b,
		"area_mm2": b * float(h) if h != null and not is_nan(b) else null, "tip_mm": tip,
		"depth_mm": float(d["depth_mm"]), "time_s": time, "helix": drill_helix(kind), "point_rec": point_angle_for(kind),
		"chip_color": Chips.temper_color(kind, float(r.get("vc", 0.0)) if r.get("vc") != null else 0.0),
	}


## Ángulo de punta recomendado para un material (kind de CONTRATOS.md), de las tablas del afilado (sharpening.gd):
## { value, min, max, source, quality } o {} si las fuentes no lo dan para ese material.
static func point_angle_for(work_kind: String) -> Dictionary:
	var points: Dictionary = Sharpening.SHARPENING_ANGLES["broca"]["punta"]
	if not points.has(work_kind):
		return {}
	var p: Dictionary = points[work_kind]
	return { "value": p["value"], "min": p["min"], "max": p["max"], "source": p["source"], "quality": p["quality"] }


## Hélice de la broca para dibujarla: el tipo que dan las tablas del afilado para ese material (N normal, H corta, W
## larga) y el centro de su intervalo; si no dan tipo, la normal. { type, name, deg, min, max, source }.
static func drill_helix(work_kind: String) -> Dictionary:
	var drill_data: Dictionary = Sharpening.SHARPENING_ANGLES["broca"]
	var t := "N"
	var points: Dictionary = drill_data["punta"]
	if points.has(work_kind) and str(points[work_kind]["helix"]) != "":
		t = str(points[work_kind]["helix"])
	var hx: Dictionary = drill_data["helices"][t]
	return {
		"type": t, "name": hx["name"], "deg": (float(hx["min"]) + float(hx["max"])) / 2.0, "min": hx["min"],
		"max": hx["max"], "source": hx["source"],
	}


## Hélice de una fresa de mango para dibujarla: la que dan las tablas del afilado para ese material (Travers, Nachi) o,
## si no la dan, la del acero. { deg, source, quality, own (true si es la del material) }.
static func mill_helix(work_kind: String) -> Dictionary:
	var table: Dictionary = Sharpening.SHARPENING_ANGLES["fresa"]["helice"]
	var own := table.has(work_kind)
	var h: Dictionary = table[work_kind] if own else table["acero"]
	return { "deg": float(h["value"]), "source": h["source"], "quality": h["quality"], "own": own }


## Entrada de sonido del taladro: los dos labios de la broca son sus «dientes» (paso 2·n/60). load: como en la fresa;
## < 0, la de la animación: mientras entra la punta, los filos cortan hasta el radio r = profundidad·tan(σ/2) y, con kc
## constante, la potencia crece como r² (P = kc·f·ω·r²/2).
func drill_sound_input(load: float = -1.0) -> Dictionary:
	var f := load
	if f < 0.0:
		var e := float(drill_anim.get("engaged", 0.0))
		f = e * e if bool(drill_anim.get("cutting", false)) else 0.0
	return _sound_input("drill", drill_result, 2, float(drill["d_mm"]), str(drill["work_id"]), bool(drill["coolant"]),
		float(drill_machine["pmax_kw"]), bool(running["drill"]), f)


# ══════════════════════════════ Máquina, marcha y avisos ══════════════════════════════

## Ficha de la máquina de ejemplo (MACHINES[kind]).
static func machine_ficha(kind: String) -> Dictionary:
	return MACHINES.get(kind, {})


## Cambia la potencia (pmax_kw), el tope de giro (rpm_max) o el rendimiento (eta) de la máquina y recalcula.
func set_machine_param(kind: String, key: String, value: float) -> void:
	if not (kind in KINDS) or not (key in ["pmax_kw", "rpm_max", "eta"]):
		return
	var m: Dictionary = (mill_machine if kind == "mill" else drill_machine).duplicate()
	m[key] = maxf(float(value), 0.01)
	if kind == "mill":
		mill_machine = m
	else:
		drill_machine = m
	_refresh(kind)
	changed.emit()


## Vuelve a la ficha de la máquina de ejemplo.
func reset_machine(kind: String) -> void:
	if not (kind in KINDS):
		return
	if kind == "mill":
		mill_machine = _machine_params("mill")
	else:
		drill_machine = _machine_params("drill")
	_refresh(kind)
	changed.emit()


## ¿Son los parámetros de la máquina los de su ficha?
func machine_is_ficha(kind: String) -> bool:
	var m: Dictionary = mill_machine if kind == "mill" else drill_machine
	return m == _machine_params(kind)


func set_running(kind: String, on: bool) -> void:
	if not (kind in KINDS) or bool(running[kind]) == on:
		return
	running = running.duplicate()
	running[kind] = on
	changed.emit()


func toggle_running(kind: String) -> void:
	set_running(kind, not bool(running.get(kind, false)))


## Avisos de la máquina que el modelo de corte no conoce: giro por debajo del mínimo de la ficha y, en el taladro, una
## broca más gruesa que la capacidad de la máquina.
func machine_notes(kind: String) -> Array[String]:
	var out: Array[String] = []
	var ficha: Dictionary = MACHINES.get(kind, {})
	var r: Dictionary = mill_result if kind == "mill" else drill_result
	if r.get("rpm") != null and float(r["rpm"]) > 0.0 and float(r["rpm"]) < float(ficha["rpm_min"]):
		out.append("La %s no gira por debajo de %s rpm (ficha): harían falta %s rpm." % [
			str(ficha["name"]), _fmt(float(ficha["rpm_min"]), 0), _fmt(float(r["rpm"]), 0)])
	if kind == "drill" and float(drill["d_mm"]) > float(ficha["capacity_mm"]):
		out.append("La ficha de la %s da Ø%s como máximo (en acero de 70 kg/mm²): la broca de Ø%s es más gruesa." % [
			str(ficha["name"]), _fmt(float(ficha["capacity_mm"]), 0), _fmt(float(drill["d_mm"]), 1)])
	return out


## Número para los mensajes: to_fixed de js.gd con coma decimal (como lathe.gd y sharpening.gd), sin «,0» final.
static func _fmt(x: float, decimals: int) -> String:
	var s := Js.to_fixed(x, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")


# ══════════════════════════════ Animación ══════════════════════════════

## Velocidad de la animación de una máquina (uno de ANIM_SPEEDS).
func set_anim_speed(kind: String, x: float) -> void:
	if not (kind in KINDS) or not ANIM_SPEEDS.has(x) or float(anim_speed[kind]) == x:
		return
	anim_speed = anim_speed.duplicate()
	anim_speed[kind] = x
	changed.emit()


## Pieza de la animación de la fresadora: { length_mm (a lo largo del avance), width_mm }. Centrada, tan ancha como ae
## (se planea el ancho entero); en fresado lateral, un diámetro más que ae.
func mill_block() -> Dictionary:
	var dc := float(mill["dc_mm"])
	var centered: bool = POSITIONS[str(mill["position"])]["centered"]
	return {
		"length_mm": clampf(MILL_BLOCK_D * dc, MILL_BLOCK_MIN, MILL_BLOCK_MAX),
		"width_mm": float(mill["ae_mm"]) if centered else float(mill["ae_mm"]) + dc,
	}


## Vuelve a empezar la animación de una máquina (pasada o agujero nuevos).
func reset_anim(kind: String) -> void:
	if kind == "mill":
		var r := float(mill["dc_mm"]) / 2.0
		var length := float(mill_block()["length_mm"])
		mill_anim = {
			"t_s": 0.0, "x_mm": -r - MILL_CLEAR_MM, "phase": "corte", "cutting": false, "engaged": 0.0,
			"pass_time_s": _pass_time(length, r), "length_mm": length, "passes": int(mill_anim.get("passes", 0)),
			"pause_s": 0.0,
		}
	elif kind == "drill":
		drill_anim = {
			"t_s": 0.0, "depth_mm": -DRILL_CLEAR_MM, "phase": "aproximacion", "cutting": false, "engaged": 0.0,
			"target_mm": _drill_target(), "holes": int(drill_anim.get("holes", 0)), "pause_s": 0.0, "hole_mm": 0.0,
			"bottom_mm": 0.0,
		}


## Avanza la animación de una máquina dt segundos reales (por su velocidad de animación). Parada, sin giro o sin avance,
## no se mueve.
func advance(kind: String, dt: float) -> void:
	if dt <= 0.0:
		return
	if kind == "mill":
		_advance_mill(dt * float(anim_speed["mill"]))
	elif kind == "drill":
		_advance_drill(dt * float(anim_speed["drill"]))


## Fracción de la potencia del arco completo que corta con el centro de la fresa en x_mm (la pieza va de 0 a length_mm a
## lo largo del avance): ∫ sen φ dφ de la parte del arco cuyos dientes están dentro de la pieza (x + R·sen φ entre 0 y el
## largo), entre la del arco entero. Con h ∝ sen φ, el volumen que arranca cada diente, y con él la potencia, es
## proporcional a esa integral. 0 fuera de la pieza, 1 con el arco entero dentro.
static func engaged_fraction(eng: Dictionary, x_mm: float, length_mm: float) -> float:
	if eng.is_empty():
		return 0.0
	var r := float(eng["dc_mm"]) / 2.0
	var a := float(eng["phi_in"])
	var b := float(eng["phi_out"])
	var total := 0.0
	var inside := 0.0
	for i in ENGAGE_SAMPLES:
		var phi := a + (b - a) * (float(i) + 0.5) / float(ENGAGE_SAMPLES)
		var w := sin(phi)
		total += w
		var xt := x_mm + r * sin(phi)
		if xt >= 0.0 and xt <= length_mm:
			inside += w
	return inside / total if total > 0.0 else 0.0


## Cámara lenta para ver girar la herramienta en los esquemas: { rev_s (vueltas por segundo que se dibujan: las reales si
## son menos que rev_s_max), time_scale (dibujado / real, ≤ 1), factor (real / dibujado, ≥ 1), s_per_rev (segundos por
## vuelta dibujada; 0 parada) }. Es solo la velocidad del dibujo.
static func slow_motion(rpm: float, rev_s_max: float) -> Dictionary:
	var real := maxf(rpm, 0.0) / 60.0
	if real <= 0.0:
		return { "rev_s": 0.0, "time_scale": 1.0, "factor": 1.0, "s_per_rev": 0.0 }
	var shown := minf(real, rev_s_max)
	return { "rev_s": shown, "time_scale": shown / real, "factor": real / shown, "s_per_rev": 1.0 / shown }


func _advance_mill(t: float) -> void:
	var a := mill_anim.duplicate()
	var r := float(mill["dc_mm"]) / 2.0
	var length := float(mill_block()["length_mm"])
	var vf: Variant = mill_result.get("vf_mm_min")
	var moving := bool(running["mill"]) and vf != null and float(vf) > 0.0
	a["length_mm"] = length
	a["pass_time_s"] = _pass_time(length, r)
	if str(a["phase"]) == "pausa":
		a["pause_s"] = float(a["pause_s"]) + t
		if float(a["pause_s"]) >= PAUSE_S:
			a["phase"] = "corte"
			a["pause_s"] = 0.0
			a["x_mm"] = -r - MILL_CLEAR_MM
			a["t_s"] = 0.0
			a["passes"] = int(a["passes"]) + 1
	elif moving:
		a["x_mm"] = float(a["x_mm"]) + float(vf) / 60.0 * t
		a["t_s"] = float(a["t_s"]) + t
		if float(a["x_mm"]) - r > length + MILL_CLEAR_MM:
			a["phase"] = "pausa"
			a["pause_s"] = 0.0
	var frac := engaged_fraction(mill_engagement(), float(a["x_mm"]), length) if str(a["phase"]) == "corte" else 0.0
	a["engaged"] = frac
	a["cutting"] = moving and frac > 0.0
	mill_anim = a


func _advance_drill(t: float) -> void:
	var a := drill_anim.duplicate()
	var target := _drill_target()
	a["target_mm"] = target
	var vf: Variant = drill_result.get("vf_mm_min")
	var moving := bool(running["drill"]) and vf != null and float(vf) > 0.0
	var left := t if moving else 0.0
	var guard := 0
	while left > 0.0 and guard < 8:
		guard += 1
		var depth := float(a["depth_mm"])
		match str(a["phase"]):
			"aproximacion":  # en rápido hasta DRILL_APPROACH_MM por encima de la cara
				var sp := (DRILL_CLEAR_MM - DRILL_APPROACH_MM) / RAPID_S
				var need := (-DRILL_APPROACH_MM - depth) / sp
				if need <= left:
					a["depth_mm"] = -DRILL_APPROACH_MM
					a["phase"] = "taladrando"
					left -= maxf(need, 0.0)
				else:
					a["depth_mm"] = depth + sp * left
					left = 0.0
			"taladrando":  # con el avance vf hasta que el diámetro entero llega a la profundidad
				var v := float(vf) / 60.0
				var need := (target - depth) / v
				if need <= left:
					a["depth_mm"] = maxf(target, depth)  # si la profundidad pedida ha bajado, sale desde donde está
					a["phase"] = "retirada"
					left -= maxf(need, 0.0)
				else:
					a["depth_mm"] = depth + v * left
					left = 0.0
				a["t_s"] = maxf(float(a["depth_mm"]), 0.0) / v
				a["bottom_mm"] = maxf(float(a.get("bottom_mm", 0.0)), float(a["depth_mm"]))
			"retirada":  # en rápido hasta DRILL_CLEAR_MM por encima de la cara
				var sp := (maxf(target, 0.0) + DRILL_CLEAR_MM) / RAPID_S
				var need := (depth + DRILL_CLEAR_MM) / sp
				if need <= left:
					a["depth_mm"] = -DRILL_CLEAR_MM
					a["phase"] = "pausa"
					a["pause_s"] = 0.0
					left -= maxf(need, 0.0)
				else:
					a["depth_mm"] = depth - sp * left
					left = 0.0
			_:  # pausa entre agujeros
				var need := PAUSE_S - float(a["pause_s"])
				if need <= left:
					a["phase"] = "aproximacion"
					a["pause_s"] = 0.0
					a["t_s"] = 0.0
					a["bottom_mm"] = 0.0  # un agujero nuevo
					a["holes"] = int(a["holes"]) + 1
					left -= maxf(need, 0.0)
				else:
					a["pause_s"] = float(a["pause_s"]) + left
					left = 0.0
	var tip := float(drill_geometry()["tip_mm"])
	var cutting := moving and str(a["phase"]) == "taladrando" and float(a["depth_mm"]) > 0.0
	a["cutting"] = cutting
	a["engaged"] = clampf(float(a["depth_mm"]) / tip, 0.0, 1.0) if cutting and tip > 0.0 else 0.0
	# Hondo del agujero a diámetro entero (lo que se acota), desde su fondo (lo más hondo que ha llegado la punta en este
	# agujero): no cambia al sacar la broca; un agujero nuevo empieza sin fondo
	a["hole_mm"] = clampf(float(a.get("bottom_mm", 0.0)) - (tip if not is_nan(tip) else 0.0), 0.0, float(drill["depth_mm"]))
	drill_anim = a


## Lo que necesita la escena 3D de la fresadora (una vista del estado, no física nueva):
## { tool_type, dc_mm, z, kappa_deg, helix_deg (fresa de mango), ap_mm, ae_mm (el que usó el modelo), position,
##   material_side, phi_out (salida del diente, rad), length_mm, width_mm, x_mm, rpm (0 parada), cutting, engaged,
##   coolant, work_kind, tool_id, vc, pc_kw (la que corta ahora), chip_color (sRGB lineal) }.
func mill_3d_view() -> Dictionary:
	var eng := mill_engagement()
	var r := mill_result
	var blk := mill_block()
	var on := bool(running["mill"]) and r.get("rpm") != null and float(r["rpm"]) > 0.0
	var kind := str(WorkMaterials.get_material(str(mill["work_id"])).get("kind", "acero"))
	var cutting := bool(mill_anim.get("cutting", false))
	var pc := float(r["pc_kw"]) * float(mill_anim.get("engaged", 0.0)) if cutting and r.get("pc_kw") != null else 0.0
	# El lado de la pieza: el del contacto o, sin contacto (faltan datos), el de la posición elegida
	var side := 0
	if not eng.is_empty():
		side = int(eng["material_side"])
	elif not bool(POSITIONS[str(mill["position"])]["centered"]):
		side = -1 if str(mill["position"]) == "concordancia" else 1
	return {
		"tool_type": mill["tool_type"], "dc_mm": mill["dc_mm"], "z": mill["z"], "kappa_deg": mill["kappa_deg"],
		"helix_deg": float(mill_helix(kind)["deg"]), "ap_mm": mill["ap_mm"],
		"ae_mm": float(eng.get("ae_mm", minf(float(mill["ae_mm"]), float(mill["dc_mm"])))), "position": mill["position"],
		"material_side": side, "phi_out": float(eng.get("phi_out", PI / 2.0)), "length_mm": blk["length_mm"],
		"width_mm": blk["width_mm"], "x_mm": float(mill_anim.get("x_mm", 0.0)), "rpm": float(r["rpm"]) if on else 0.0,
		"cutting": cutting, "engaged": float(mill_anim.get("engaged", 0.0)), "coolant": bool(mill["coolant"]) and on,
		"work_kind": kind, "tool_id": mill["tool_id"], "vc": float(r["vc"]) if on and r.get("vc") != null else 0.0,
		"pc_kw": pc, "chip_color": Chips.temper_color(kind, float(r["vc"]) if r.get("vc") != null else 0.0),
	}


## Lo que necesita la escena 3D del taladro: { d_mm, sigma_deg, tip_mm, helix_deg, depth_mm (punta), bottom_mm,
## hole_mm, target_mm, depth_goal_mm, phase, rpm (0 parado), cutting, engaged, coolant, work_kind, tool_id, vc, pc_kw
## (la que corta ahora), chip_color, chip_form }.
func drill_3d_view() -> Dictionary:
	var g := drill_geometry()
	var r := drill_result
	var on := bool(running["drill"]) and r.get("rpm") != null and float(r["rpm"]) > 0.0
	var kind := str(WorkMaterials.get_material(str(drill["work_id"])).get("kind", "acero"))
	var cutting := bool(drill_anim.get("cutting", false))
	var e := float(drill_anim.get("engaged", 0.0))
	var pc := float(r["pc_kw"]) * e * e if cutting and r.get("pc_kw") != null else 0.0
	return {
		"d_mm": g["d_mm"], "sigma_deg": g["sigma_deg"], "tip_mm": g["tip_mm"], "helix_deg": (g["helix"] as Dictionary)["deg"],
		"depth_mm": float(drill_anim.get("depth_mm", 0.0)), "bottom_mm": float(drill_anim.get("bottom_mm", 0.0)),
		"hole_mm": float(drill_anim.get("hole_mm", 0.0)), "target_mm": float(drill_anim.get("target_mm", 0.0)),
		"depth_goal_mm": drill["depth_mm"], "phase": str(drill_anim.get("phase", "")), "rpm": float(r["rpm"]) if on else 0.0,
		"cutting": cutting, "engaged": e, "coolant": bool(drill["coolant"]) and on, "work_kind": kind,
		"tool_id": drill["tool_id"], "vc": float(r["vc"]) if on and r.get("vc") != null else 0.0, "pc_kw": pc,
		"chip_color": g["chip_color"], "chip_form": Chips.form_for(kind),
	}


## Tiempo de una pasada entera de la fresa (s): de fuera a fuera de la pieza con su holgura, a vf. null sin avance.
func _pass_time(length: float, r: float) -> Variant:
	var vf: Variant = mill_result.get("vf_mm_min")
	if vf == null or float(vf) <= 0.0:
		return null
	return (length + 2.0 * r + 2.0 * MILL_CLEAR_MM) / float(vf) * 60.0


## Hasta dónde baja la punta: la profundidad pedida más el largo de la punta cónica.
func _drill_target() -> float:
	var tip := float(drill_geometry()["tip_mm"])
	return float(drill["depth_mm"]) + (tip if not is_nan(tip) else 0.0)


# ══════════════════════════════ Barridos ══════════════════════════════

## Qué se barre en una máquina (una clave de SWEEP_AXES[kind]).
func set_sweep_x(kind: String, key: String) -> void:
	if not SWEEP_AXES.get(kind, {}).has(key) or sweep_x[kind] == key:
		return
	sweep_x = sweep_x.duplicate()
	sweep_x[kind] = key
	_request_sweep(kind)
	changed.emit()


## Último barrido completo de una máquina: { kind, key, label, unit, decimals, xs: PackedFloat64Array, points: [{ x,
## overload, <SWEEP_OUTPUTS> }], serial } ({} si aún no ha llegado ninguno) y pending: si hay otro en camino.
func sweep(kind: String) -> Dictionary:
	var s: Dictionary = (_sweeps.get(kind, {}) as Dictionary).duplicate()
	if not s.is_empty():
		s["pending"] = _jobs.has(kind) or _again.has(kind)
	return s


## ¿Hay un barrido en camino (en hilos, o esperando para repetirse con las entradas nuevas)?
func sweep_pending(kind: String) -> bool:
	return _jobs.has(kind) or _again.has(kind)


## ¿Corresponde el último barrido a las entradas de ahora?
func sweep_is_current(kind: String) -> bool:
	var s: Dictionary = _sweeps.get(kind, {})
	return not s.is_empty() and int(s["serial"]) == int(_serial[kind]) and str(s["key"]) == str(sweep_x[kind])


## Recoge los barridos que hayan terminado (llamar en cada fotograma). Devuelve cuántos han llegado.
func poll() -> int:
	var n := 0
	for kind in KINDS:
		if _jobs.has(kind) and WorkerThreadPool.is_group_task_completed(int(_jobs[kind]["task"])):
			_finish(kind)
			n += 1
	return n


## Espera a que acaben los barridos en curso y los recoge (demo, tests y al cerrar).
func wait_sweeps() -> void:
	var guard := 0
	while not _jobs.is_empty() and guard < 8:
		for kind in KINDS:
			if _jobs.has(kind):
				_finish(kind)
		guard += 1


## Cierra el barrido en curso de kind (espera a su grupo de tareas, que deja de existir al terminar), guarda sus
## puntos y, si las entradas cambiaron mientras tanto, lanza otro.
func _finish(kind: String) -> void:
	var job: Dictionary = _jobs[kind]
	WorkerThreadPool.wait_for_group_task_completion(int(job["task"]))
	_jobs.erase(kind)
	_store_sweep(kind, job, _merge_blocks(job["blocks"]))
	if _again.has(kind):
		_again.erase(kind)
		_request_sweep(kind)


## Valores de x de un barrido: SWEEP_POINTS puntos repartidos en el recorrido de SWEEP_AXES (ae: del 2 % al 100 % del
## diámetro de la fresa), alargado hasta el ensayo actual si queda fuera (la curva siempre llega a su punto).
func sweep_values(kind: String, key: String) -> PackedFloat64Array:
	var axis: Dictionary = SWEEP_AXES[kind][key]
	var lo := 0.0
	var hi := 0.0
	if key == "ae_mm":
		lo = float(mill["dc_mm"]) * 0.02
		hi = float(mill["dc_mm"])
	else:
		lo = float(axis["range"][0])
		hi = float(axis["range"][1])
	var cur := sweep_current_x(kind, key)
	if cur > 0.0 and is_finite(cur):
		lo = minf(lo, cur)
		hi = maxf(hi, cur)
	var xs := PackedFloat64Array()
	xs.resize(SWEEP_POINTS)
	for i in SWEEP_POINTS:
		xs[i] = lo + (hi - lo) * float(i) / float(SWEEP_POINTS - 1)
	xs[SWEEP_POINTS - 1] = hi  # el extremo, exacto (lo + (hi − lo) puede no dar hi al bit)
	return xs


## x del ensayo actual en un barrido: la vc del resultado (la que da el giro, aunque se elija por rpm o la recorte la
## máquina), el ae que usó el modelo o la entrada tal cual. NAN si no la hay.
func sweep_current_x(kind: String, key: String) -> float:
	var p: Dictionary = mill if kind == "mill" else drill
	var r: Dictionary = mill_result if kind == "mill" else drill_result
	if r.get(key) != null and (key == "vc" or key == "ae_mm"):
		return float(r[key])
	return float(p.get(key, NAN)) if p.get(key) != null else NAN


## Un punto del barrido: la entrada base con key = x (al barrer vc, sin rpm) y lo que interesa de la salida.
static func sweep_point(kind: String, base: Dictionary, key: String, x: float) -> Dictionary:
	var p := base.duplicate(true)
	p[key] = x
	if key == "vc":
		p.erase("rpm")
	var r := Cutting.milling(p) if kind == "mill" else Cutting.drilling(p)
	var out := { "x": x, "overload": bool(r.get("overload", false)) }
	for o in SWEEP_OUTPUTS[kind]:
		out[o[0]] = r.get(o[0])
	return out


## Un barrido completo, al momento. Con threads ≤ 1, un bucle; con más, bloques de SWEEP_BLOCK puntos en
## WorkerThreadPool y espera. El resultado es el mismo con cualquier número de hilos (se juntan en orden).
static func run_sweep(kind: String, base: Dictionary, key: String, xs: PackedFloat64Array, threads: int) -> Array:
	if threads <= 1:
		var out: Array = []
		for x in xs:
			out.append(sweep_point(kind, base, key, x))
		return out
	var job := _new_job(kind, base, key, xs)
	var task := _launch(job, threads)
	WorkerThreadPool.wait_for_group_task_completion(task)
	return _merge_blocks(job["blocks"])


# ══════════════════════════════ auxiliares ══════════════════════════════

## Parámetros de la máquina que recibe el modelo de corte (de su ficha).
static func _machine_params(kind: String) -> Dictionary:
	var f: Dictionary = MACHINES[kind]
	return { "pmax_kw": f["pmax_kw"], "rpm_max": f["rpm_max"], "eta": f["eta"] }


## Al cambiar entre vc y rpm se conserva el giro que daba el modelo (ya recortado por la máquina).
static func _keep_speed(p: Dictionary, r: Dictionary) -> void:
	if p["speed_mode"] == "rpm" and r.get("rpm") != null and float(r["rpm"]) > 0.0:
		p["rpm"] = float(r["rpm"])
	elif p["speed_mode"] == "vc" and r.get("vc") != null and float(r["vc"]) > 0.0:
		p["vc"] = float(r["vc"])


func _refresh(kind: String) -> void:
	if kind == "mill":
		mill_result = Cutting.milling(mill_request())
	else:
		drill_result = Cutting.drilling(drill_request())
	_serial = _serial.duplicate()
	_serial[kind] = int(_serial[kind]) + 1
	_request_sweep(kind)


func _request_sweep(kind: String) -> void:
	var key: String = sweep_x[kind]
	var base := mill_request() if kind == "mill" else drill_request()
	var xs := sweep_values(kind, key)
	if not threaded:
		var job := _new_job(kind, base, key, xs)
		job["serial"] = _serial[kind]
		_store_sweep(kind, job, run_sweep(kind, base, key, xs, 1))
		return
	if _jobs.has(kind):
		_again[kind] = true  # se repite con las entradas nuevas en cuanto acabe el que corre
		return
	var job := _new_job(kind, base, key, xs)
	job["serial"] = _serial[kind]
	job["task"] = _launch(job, -1)
	_jobs[kind] = job


static func _new_job(kind: String, base: Dictionary, key: String, xs: PackedFloat64Array) -> Dictionary:
	var n_blocks := ceili(float(xs.size()) / float(SWEEP_BLOCK))
	var blocks: Array = []
	blocks.resize(n_blocks)
	return { "kind": kind, "base": base, "key": key, "xs": xs, "blocks": blocks, "mutex": Mutex.new(), "serial": -1 }


## Lanza las tareas de un barrido (una por bloque) y devuelve el id del grupo. threads < 0: los que decida Godot.
static func _launch(job: Dictionary, threads: int) -> int:
	var n_blocks: int = (job["blocks"] as Array).size()
	var task := func(b: int) -> void: _run_block(job, b)
	return WorkerThreadPool.add_group_task(task, n_blocks, threads, false, "barrido de fresado y taladrado")


## Un bloque: calcula sus puntos sin tocar nada compartido y los deja en su casilla (con el cerrojo del trabajo).
static func _run_block(job: Dictionary, b: int) -> void:
	var xs: PackedFloat64Array = job["xs"]
	var lo := b * SWEEP_BLOCK
	var hi := mini(lo + SWEEP_BLOCK, xs.size())
	var local: Array = []
	for i in range(lo, hi):
		local.append(sweep_point(str(job["kind"]), job["base"], str(job["key"]), xs[i]))
	var mutex: Mutex = job["mutex"]
	mutex.lock()
	job["blocks"][b] = local
	mutex.unlock()


## Junta los bloques en su orden.
static func _merge_blocks(blocks: Array) -> Array:
	var out: Array = []
	for bl in blocks:
		if bl is Array:
			out.append_array(bl)
	return out


func _store_sweep(kind: String, job: Dictionary, points: Array) -> void:
	var axis: Dictionary = SWEEP_AXES[kind][str(job["key"])]
	_sweeps = _sweeps.duplicate()
	_sweeps[kind] = {
		"kind": kind, "key": job["key"], "label": axis["label"], "unit": axis["unit"], "decimals": axis["decimals"],
		"xs": job["xs"], "points": points, "serial": job["serial"],
	}
	sweep_ready.emit(kind)


## Entrada de sonido común: con la máquina en marcha y giro, el giro del modelo; con la herramienta dentro de la
## pieza, la fracción load de la potencia de corte neta (la carga del motor es Pc/Pmáx, como en el torno).
static func _sound_input(process: String, r: Dictionary, teeth: int, d_mm: float, work_id: String, coolant: bool,
		pmax_kw: float, switched_on: bool, load: float) -> Dictionary:
	var rpm: Variant = r.get("rpm")
	var on := switched_on and rpm != null and float(rpm) > 0.0
	var pc: Variant = r.get("pc_kw")
	return {
		"process": process, "rpm": float(rpm) if on else 0.0, "teeth": teeth,
		"pc_kw": float(pc) * clampf(load, 0.0, 1.0) if on and pc != null else 0.0, "pmax_kw": pmax_kw,
		"work_kind": str(WorkMaterials.get_material(work_id).get("kind", "acero")), "chatter": null,
		"coolant": coolant and on, "tool_pos": Vector3.ZERO, "vc": float(r["vc"]) if on and r.get("vc") != null else 0.0,
		"diameter_mm": d_mm,
	}
