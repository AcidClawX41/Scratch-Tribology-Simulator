## Simulador DE PRUEBA de la demo de la afiladora 3D (app/taller/demo_afilado3d.tscn).
##
## ATENCIÓN: DATOS INVENTADOS. No es la física del afilado: las temperaturas del filo, la rebaba, el ritmo de las
## chispas y los tiempos son curvas de dibujo elegidas para enseñar la escena (el filo que pasa de paja a azul en la
## pasada lenta, la piedra húmeda que lo deja frío, el hacha que apenas se calienta). La simulación de verdad la
## enchufa la oleada 2 con sharpening_sim.gd y edge_thermal.gd, con los mismos diccionarios (CONTRATOS.md → «Vista 3D
## de la afiladora»).
## Lo que sí sale de datos: las vistas de máquina (copias de SharpeningMachines.view() de la unidad 1b: Einhell
## TC-BG 150, Tormek T-8 y Einhell TE-AG 125 CE), la fuerza y el rozamiento de la operación nominal
## (sharpening.gd, NOMINAL_OPERATION) y la velocidad periférica (sharpening.gd).
##
## frame_at(t) es una función pura del tiempo (todo menos los picos de temperatura); step(dt) avanza el reloj y
## guarda el pico que alcanza cada punto del filo (el color de revenido no se va al enfriarse). Determinista.
extends RefCounted

const Sharpening = preload("res://core/taller/sharpening.gd")

const DURATION := 8.0
const SAMPLES := 48  # muestras de edge_temp_c a lo largo del filo
const AMBIENT_C := 20.0

## Vistas de máquina: copias de SharpeningMachines.view(id, muela) (unidad 1b).
const TC_BG_150 := { "machine_id": "einhell_tc_bg_150", "kind": "banco", "rpm": 2980.0, "wet": false,
	"water_trough": false, "quench_pot": false, "wheels": [
		{ "id": "grueso", "position": "izquierda", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
			"grit": "K36", "rpm": 2980.0, "wet": false, "honing": false, "selected": false },
		{ "id": "fino", "position": "derecha", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
			"grit": "K60", "rpm": 2980.0, "wet": false, "honing": false, "selected": true }] }
const TORMEK_T8 := { "machine_id": "tormek_t8", "kind": "humeda_lenta", "rpm": 100.0, "wet": true,
	"water_trough": true, "quench_pot": false, "wheels": [
		{ "id": "sg250", "position": "piedra", "d_mm": 250.0, "width_mm": 50.0, "abrasive_id": "al2o3",
			"grit": "220", "rpm": 100.0, "wet": true, "honing": false, "selected": true },
		{ "id": "la220", "position": "cuero", "d_mm": 220.0, "width_mm": 31.0, "abrasive_id": "",
			"grit": "", "rpm": 100.0, "wet": false, "honing": true, "selected": false }] }
const TE_AG_125 := { "machine_id": "einhell_te_ag_125_ce", "kind": "amoladora", "rpm": 12000.0, "wet": false,
	"water_trough": false, "quench_pot": false, "wheels": [
		{ "id": "laminas", "position": "disco", "d_mm": 125.0, "width_mm": null, "abrasive_id": "al2o3",
			"grit": "P60", "rpm": 12000.0, "wet": false, "honing": false, "selected": true }] }
## Cuchillo de cocina de acero al carbono (colores de revenido de la tabla «acero» de panels.gd, la que usa
## EdgeThermal.tint(); un inoxidable no toma color hasta ≈290 °C).
const KNIFE := { "kind": "cuchillo", "length_mm": 200.0, "width_mm": 45.0, "spine_mm": 2.5, "steel_id": "1095" }
const AXE := { "kind": "hacha", "length_mm": 175.0, "width_mm": 95.0, "spine_mm": 28.0, "steel_id": "1095" }

## Casos de la demo (tiempos en s). rpm: el giro de la muela (en la amoladora, su posición más lenta, ≈3000 rpm,
## la que pide su ficha para un hacha); spin_up: arranque (dibujo); contact: [entra, sale]; sweep: contact_pos al
## entrar y al salir (back_and_forth: la amoladora va y viene); heat: temperatura del punto que toca, al empezar y
## al acabar la pasada (INVENTADA); sparks: chispas por segundo en contacto (INVENTADO; el color y el largo los
## pone sparks.gd con la firma del acero); burr: rebaba al empezar y al acabar (INVENTADA); force_n: fuerza (10 N,
## la de la mano de NOMINAL_OPERATION, que también es una estimación; los 15 N de la amoladora, INVENTADOS);
## tint_depth_mm: hasta dónde llega el calor desde el filo hacia el lomo (INVENTADO).
const CASES := [
	{
		"id": "banco", "t0": 0.0, "t1": 3.2, "machine": TC_BG_150, "tool": KNIFE, "wheel": "derecha",
		"title": "Esmeriladora de banco a 2980 rpm · cuchillo de acero al carbono · pasada lenta: de paja a azul",
		"angle_deg": 20.0, "rpm": 2980.0, "spin_up": 0.8, "contact": [1.3, 3.0], "sweep": [0.1, 0.9],
		"heat": [185.0, 330.0], "sparks": 900.0, "burr": [0.0, 0.85], "force_n": 10.0, "tint_depth_mm": 6.0,
		"views": [[0.0, "general"], [1.55, "filo"]],
		"sound": { "process": "sharpener", "machine_kind": "banco", "work_kind": "acero", "tool_pos": Vector3(0.14, 0.0, 0.0) },
	},
	{
		"id": "humeda", "t0": 3.2, "t1": 5.6, "machine": TORMEK_T8, "tool": KNIFE, "wheel": "piedra",
		"title": "Afiladora húmeda lenta a 100 rpm · el agua se lleva el calor: el filo sigue frío",
		"angle_deg": 20.0, "rpm": 100.0, "spin_up": 0.0, "contact": [3.5, 5.45], "sweep": [0.15, 0.85],
		"heat": [23.0, 26.0], "sparks": 0.0, "burr": [0.1, 0.55], "force_n": 10.0,
		"views": [[3.2, "general"], [4.3, "seccion"]],
		"sound": { "process": "sharpener", "machine_kind": "humeda_lenta", "work_kind": "acero", "tool_pos": Vector3(-0.2, 0.0, 0.0) },
	},
	{
		"id": "amoladora", "t0": 5.6, "t1": 8.0, "machine": TE_AG_125, "tool": AXE, "wheel": "disco",
		"title": "Amoladora con disco de láminas a ≈3000 rpm · hacha en el tornillo: se calienta poco",
		"angle_deg": 14.0, "rpm": 3000.0, "spin_up": 0.25, "contact": [6.1, 7.85], "sweep": [0.15, 0.85],
		"back_and_forth": true, "heat": [60.0, 140.0], "sparks": 1200.0, "burr": [0.0, 0.6], "force_n": 15.0,
		"tint_depth_mm": 8.0,
		"views": [[5.6, "general"], [6.9, "filo"]],
		"sound": { "process": "grinder", "disc_id": "laminas", "sheet_mm": 0.0, "work_kind": "acero", "tool_pos": Vector3(0.16, 0.0, 0.0) },
	},
]

var t := 0.0
var _case := ""
var _peaks := PackedFloat32Array()


static func case_at(time: float) -> Dictionary:
	var tt := fposmod(time, DURATION)
	for c in CASES:
		if tt >= float(c["t0"]) and tt < float(c["t1"]):
			return c
	return CASES[CASES.size() - 1]


## Todo lo del instante `time` salvo los picos: { t, case, title, machine, tool, view, state, sound }. Pura.
static func frame_at(time: float) -> Dictionary:
	var c := case_at(time)
	var tt := fposmod(time, DURATION)
	var local := tt - float(c["t0"])
	var c0: float = c["contact"][0]
	var c1: float = c["contact"][1]
	var contact := tt >= c0 and tt < c1
	var k := clampf((tt - c0) / (c1 - c0), 0.0, 1.0)  # fracción de la pasada
	var s0: float = c["sweep"][0]
	var s1: float = c["sweep"][1]
	var u := lerpf(s0, s1, k)
	if bool(c.get("back_and_forth", false)):
		u = lerpf(s0, s1, 0.5 - 0.5 * cos(k * TAU * 1.5))
	# Giro: arranque lineal (dibujo) hasta las rpm del caso
	var spin_up: float = c["spin_up"]
	var rpm: float = c["rpm"] * (clampf(local / spin_up, 0.0, 1.0) if spin_up > 0.0 else 1.0)
	# Temperatura (INVENTADA): el punto que toca llega a heat(k); por delante cae en ±6 % del filo y por detrás,
	# donde ya ha pasado la muela, se enfría más despacio
	var h0: float = c["heat"][0]
	var h1: float = c["heat"][1]
	var t_c := lerpf(h0, h1, pow(k, 1.3)) if contact else AMBIENT_C
	var temps := PackedFloat32Array()
	temps.resize(SAMPLES)
	for i in SAMPLES:
		var x := float(i) / float(SAMPLES - 1)
		var dx := x - u
		var w := exp(-(dx / 0.06) * (dx / 0.06)) if dx >= 0.0 else exp(dx / 0.1)
		temps[i] = AMBIENT_C + (t_c - AMBIENT_C) * w if contact else AMBIENT_C
	var b0: float = c["burr"][0]
	var b1: float = c["burr"][1]
	var burr := lerpf(b0, b1, k) if tt >= c0 else b0
	var sparks := { "rate": float(c["sparks"]) if contact else 0.0 }
	var view := "general"
	for v in c["views"]:
		if tt >= float(v[0]):
			view = v[1]
	var state := {
		"angle_deg": float(c["angle_deg"]), "force_n": float(c["force_n"]), "contact": contact, "contact_pos": u,
		"edge_temp_c": temps, "max_temp_c": t_c, "sparks": sparks, "water": str(c["machine"]["kind"]) == "humeda_lenta",
		"rpm_actual": rpm, "burr": burr, "wheel": c["wheel"],
	}
	if c.has("tint_depth_mm"):
		state["tint_depth_mm"] = float(c["tint_depth_mm"])
	# Sonido: la potencia de contacto μ·F·v de la operación nominal (sharpening.gd), con la velocidad periférica
	var d_mm := 0.0
	for w in c["machine"]["wheels"]:
		if str(w["position"]) == str(c["wheel"]):
			d_mm = float(w["d_mm"])
	if str(c["machine"]["kind"]) == "amoladora":
		d_mm *= 0.75  # la zona del disco que apoya (dibujo: machine_grinder.gd, CONTACT_R)
	var mu := float(Sharpening.NOMINAL_OPERATION["force_ratio"]["value"])
	var pc_kw := mu * float(c["force_n"]) * Sharpening.peripheral_speed(d_mm, rpm) / 1000.0 if contact else 0.0
	var sound: Dictionary = (c["sound"] as Dictionary).duplicate()
	sound["rpm"] = rpm
	sound["pc_kw"] = pc_kw
	return {
		"t": tt, "case": c["id"], "title": c["title"], "machine": c["machine"], "tool": c["tool"], "view": view,
		"state": state, "sound": sound,
	}


## Avanza dt y devuelve frame_at(t) con edge_peak_c: el pico de cada punto del filo en el caso que está en curso.
func step(dt: float) -> Dictionary:
	var fr := frame_at(t)
	if fr["case"] != _case:
		_case = fr["case"]
		_peaks = PackedFloat32Array()
		_peaks.resize(SAMPLES)
		_peaks.fill(AMBIENT_C)
	var temps: PackedFloat32Array = fr["state"]["edge_temp_c"]
	for i in SAMPLES:
		_peaks[i] = maxf(_peaks[i], temps[i])
	fr["state"]["edge_peak_c"] = _peaks.duplicate()
	t += dt
	return fr
