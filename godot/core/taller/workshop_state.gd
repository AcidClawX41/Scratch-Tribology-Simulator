## Taller industrial · estado del taller: el gemelo de core/lab/lab_state.gd para la segunda sección.
##
## La máquina activa (torno, radial, afiladora o calculadoras) y todo lo que la interfaz del taller lee y cambia, en
## un solo objeto sin nodos. Cada cambio se aplica al momento con los módulos de core/taller y emite `changed`: la
## interfaz pinta, nunca calcula.
##
## Torno. Pieza A, B o C (bruto, torreta y plano), programa Fagor 8055 T editable con los errores y avisos del
## intérprete (con su línea y su N; el intérprete recibe las tablas de herramientas y correctores de la torreta del
## programa, para que G41/G42 compensen), el torno con el modelo de corte de verdad (Cutting.model_callable) y la reproducción:
## marcha, pausa, bloque a bloque, reinicio, RESET y velocidad de ×0,25 a ×50. advance(dt) avanza el tiempo simulado
## en subpasos de SUBSTEP_S; como el torno cuenta ticks enteros de 1 ms, cualquier reparto del tiempo da la misma
## pieza (la pieza A a ×50 sale igual que en tests/integration/test_taller_pipeline.gd). Al terminar el programa se
## mide la pieza contra su plano (Inspection.inspect_part). En manual (torno paralelo): cabezal, avance automático,
## manivelas de 0,001/0,01/0,1 mm, herramienta, material del bruto y taladrina.
## Radial, afiladora y calculadoras: sus parámetros y la salida del core (disc_check + cut_panel,
## recommend_sharpening, turning/milling/drilling), recalculada en cada cambio.
##
## Determinista: sin azar ni reloj. Los mensajes (status) van en español; los números, en la interfaz con js.gd.
## Uso: const WorkshopState = preload("res://core/taller/workshop_state.gd"); var ws := WorkshopState.new()
extends RefCounted

signal changed

const Gcode = preload("res://core/taller/gcode.gd")
const Programs = preload("res://core/taller/gcode_programs.gd")
const Lathe = preload("res://core/taller/lathe.gd")
const LatheTools = preload("res://core/taller/lathe_tools.gd")
const Cutting = preload("res://core/taller/cutting.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const Drawing = preload("res://core/taller/drawing.gd")
const Inspection = preload("res://core/taller/inspection.gd")
const Radial = preload("res://core/taller/radial.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")
const Panels = preload("res://core/taller/panels.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")

const MACHINES := ["torno", "radial", "afiladora", "calculadoras"]
## Velocidades de reproducción (tiempo simulado por segundo real).
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
## Subpaso del tiempo simulado (s): el mismo paso que el test de integración.
const SUBSTEP_S := 0.05
## Tope de tiempo simulado por llamada a advance() (s): un fotograma lento no dispara una avalancha de cálculo.
const MAX_ADVANCE_S := 4.0
## Bloque a bloque: subpaso fino (s) y tope de un bloque (s simulados).
const BLOCK_SUBSTEP_S := 0.01
const BLOCK_MAX_S := 900.0
## Pasos de la manivela (mm; en X, de diámetro, como el visualizador). El de 1 mm es para acercarse: con los finos
## (los del volante de un CNC) un clic apenas se ve en la escena.
const JOG_STEPS := [0.001, 0.01, 0.1, 1.0]
## En manual, la punta empieza a esta distancia (mm) del bruto en radio y delante de la cara: cerca, pero sin tocar.
const MANUAL_START_GAP_MM := 5.0
## Programas de ejemplo y la pieza (bruto y plano) que mecanizan.
const PROGRAM_PIECE := { "pieza_a": "A", "pieza_b": "B", "pieza_a_g42": "A", "pieza_b_g42": "B", "pieza_c": "C", "errores": "A" }
const PROGRAM_IDS := ["pieza_a", "pieza_b", "pieza_a_g42", "pieza_b_g42", "pieza_c", "errores"]
## Discos y chapas de la radial que la escena 3D sabe dibujar (CONTRATOS.md): las 4 carrocerías del laboratorio y
## las 2 piezas de rescate.
const RADIAL_DISCS := ["fino_1mm", "grueso_3mm", "diamante", "laminas"]
const RADIAL_PANELS := ["acero-dulce", "acero-bh", "aluminio", "plastico-carroceria", "boro-22mnb5", "dp800"]
const SHARPEN_TOOLS := ["cuchillo", "broca", "fresa"]
## Máquina de afilar por defecto de cada herramienta (la de sharpening.gd).
const SHARPEN_DEFAULT_MACHINE := { "cuchillo": "tormek_t8", "broca": "esmeriladora_banco", "fresa": "afiladora_universal" }
const CALC_KINDS := ["torneado", "fresado", "taladrado"]

## Fundamentos del taller para el botón «Fundamentos» de la barra superior (app/main.gd: [[título, texto]]). Cada
## uno resume un modelo de core/taller con su fuente; el detalle, en docs/taller/fuentes-u*.md.
const FUNDAMENTOS := [
	["Velocidad de corte", "vc = π·D·n/1000 (m/min). Con G96 el control mantiene vc subiendo el giro al bajar el diámetro, hasta el tope de G92 S (Fagor 8055 T)."],
	["Fuerza de corte", "kc = kc1.1·h^−mc (Kienzle), con las correcciones del Tabellenbuch Zerspantechnik por desprendimiento, herramienta, desgaste y proceso; Fc = kc·b·h y Pc = Fc·vc. El torno usa el volumen que arranca de verdad en cada vuelta: Pc = kc·ΔV/Δt."],
	["Rugosidad", "la punta de radio rε deja una cresta cada avance f: Rt ≈ f²/(8·rε) y Ra ≈ f²/(32·rε). El torno la mide sobre el perfil simulado, como un rugosímetro (ISO 4287 e ISO 4288)."],
	["Tolerancias", "ISO 286 fija los diámetros ajustados (h9, h8, js9) e ISO 2768-m el resto. El programa apunta al centro de cada tolerancia y el informe mide cada cota como un inspector: palpador sobre las crestas y regla del 16 % para Ra."],
	["Radio de la punta", "sin compensación, la punta teórica recorre el contorno y los chaflanes, conos y radios salen desplazados rε; con G41/G42 el control (como el Fagor 8055 T) desplaza la trayectoria con el radio R y el código de forma F del corrector y salen a cota (piezas A y B con G42)."],
	["Roscado", "rosca métrica ISO: H = 0,866·P y profundidad h3 = 0,6134·P (ISO 68-1). G86 da las pasadas B·√n con un incremento mínimo E y la última de acabado; cada pasada espera a la misma posición del cabezal para cortar la misma hélice (Fagor 8055 T)."],
	["Disco de radial", "el borde va a v = π·D·n/60 000 (m/s) y nunca debe pasar de las rpm marcadas en el disco (EN 12413): por encima, un disco puede reventar."],
	["Corte abrasivo", "cada grano araña como una punta (arado, cuña o corte, Hokkirigawa y Kato); la energía específica, unos 25 J/mm³ en acero, decide la potencia, el calor, la rebaba y lo limpio del corte (Awan et al. 2022; Rowe et al. 2003)."],
	["Afilado y calor", "con muelas convencionales llega a la herramienta del 60 al 85 % del calor; con CBN, alrededor del 20 % (Malkin y Guo 2007). Si el filo pasa de su temperatura de revenido, pierde dureza; el agua solo enfría hasta unos 130 °C."],
]
const FUNDAMENTOS_NOTE := "Modelos orientativos con fuentes; lo que no tiene medición publicada va marcado como estimación. Educativo: no es un procedimiento de taller ni de rescate. Detalle en docs/taller/."

# ── Máquina activa ──
var machine := "torno"

# ── Torno ──
var lathe_mode := "cnc"  # «cnc» (Fagor 8055 TC) o «manual» (torno paralelo)
var program_id := "pieza_a"
var program_text: String = Programs.EXAMPLE_PROGRAMS["pieza_a"]["text"]
var interp: Dictionary = {}  # interpret_program: { moves, errors, warnings, summary }
var piece := "A"  # bruto y plano: «A», «B» o «C»
var playing := false
var speed := 1.0
var status := ""  # última noticia del torno, en español («» si no hay)
var lathe: Lathe
var lathe_serial := 0  # cambia con cada torno nuevo (la escena 3D se vuelve a configurar)
var drawing: Dictionary = {}
var band: Dictionary = {}  # banda de tolerancia del plano en la rejilla del torno (capa de desviación)
var report: Variant = null  # informe de inspección (Inspection.inspect_part) o null
# Manual
var jog_step := 0.1
var manual_rpm := 517.0
var manual_feed := 0.2  # mm/vuelta del carro longitudinal; el transversal va a la relación de la caja
var manual_tool: String = LatheTools.ROUGH
var manual_work := ""  # material del bruto en manual («» = el del plano)
var coolant := false

# ── Radial ──
var radial := {
	"disc_id": "fino_1mm", "diameter_mm": 125.0, "rpm": 11000.0, "angle_deg": 0.0, "feed_mm_s": 20.0,
	"panel_id": "acero-dulce", "cut_length_mm": 200.0,
}
var radial_result: Dictionary = {}
var radial_check: Dictionary = {}

# ── Afiladora ──
var sharpen := {
	"kind": "cuchillo", "steel_id": "x50crmov15", "style": "occidental", "use": "cocina", "work_material": "acero",
	"diameter_mm": 10.0, "machine_id": "tormek_t8", "wheel_diameter_mm": 250.0, "rpm": 100.0,
	"wheel_abrasive_id": "", "wet": true,
}
var sharpen_result: Dictionary = {}

# ── Calculadoras ──
var calc_kind := "torneado"
var calc := {
	"torneado": {
		"work_id": "c45e", "tool_id": "hm_coated", "d_mm": 50.0, "vc": 180.0, "f_mm_rev": 0.25, "ap_mm": 2.0,
		"kappa_deg": 95.0, "nose_r_mm": 0.8, "wear": "nuevo",
	},
	"fresado": {
		"work_id": "c45e", "tool_id": "hm_coated", "dc_mm": 50.0, "z": 4, "vc": 180.0, "fz_mm": 0.15, "ap_mm": 3.0,
		"ae_mm": 30.0, "centered": true, "wear": "nuevo",
	},
	"taladrado": {
		"work_id": "c45e", "tool_id": "hss_m2", "d_mm": 10.0, "vc": 25.0, "f_mm_rev": 0.15, "point_angle_deg": 118.0,
		"wear": "nuevo",
	},
}
var calc_result: Dictionary = {}

var _st: Dictionary = {}  # último state() del torno
var _profile: Dictionary = {}  # último perfil leído del torno
var _view_dirty := Vector2i(-1, -1)  # anillos cambiados desde la última lectura de profile() (escena 3D)
var _alarm_count := 0


func _init() -> void:
	_interpret()
	_new_lathe()
	_refresh_radial()
	_refresh_sharpen()
	_refresh_calc()


# ══════════════════════════════ Máquina activa ══════════════════════════════

## Cambia de máquina. Al salir del torno, su programa se para (una máquina a la vez, también en el sonido).
func set_machine(id: String) -> void:
	if not (id in MACHINES) or id == machine:
		return
	if machine == "torno":
		playing = false
	machine = id
	changed.emit()


# ══════════════════════════════ Torno ══════════════════════════════

## Carga un programa de ejemplo (texto, pieza y torreta) y pone un bruto nuevo.
func set_program(id: String) -> void:
	if not Programs.EXAMPLE_PROGRAMS.has(id):
		return
	program_id = id
	program_text = Programs.EXAMPLE_PROGRAMS[id]["text"]
	piece = PROGRAM_PIECE[id]
	lathe_mode = "cnc"
	_interpret()
	_new_lathe()
	status = ""
	changed.emit()


## Texto del programa editado: se vuelve a interpretar (errores y avisos con su línea) y se pone un bruto nuevo.
func set_program_text(text: String) -> void:
	if text == program_text:
		return
	program_text = text
	_interpret()
	if lathe_mode == "cnc":
		_new_lathe()
	status = ""
	changed.emit()


## «cnc» (el programa manda) o «manual» (torno paralelo con manivelas). Cada modo es otra máquina: bruto nuevo.
func set_lathe_mode(mode: String) -> void:
	if not (mode in ["cnc", "manual"]) or mode == lathe_mode:
		return
	lathe_mode = mode
	_new_lathe()
	status = ""
	changed.emit()


## Bruto y plano en manual («A» o «B»); en CNC la pieza la da el programa.
func set_piece(p: String) -> void:
	if not Lathe.STOCKS.has(p) or p == piece:
		return
	piece = p
	_new_lathe()
	changed.emit()


func play() -> void:
	if lathe_mode != "cnc" or playing:
		return
	if not errors().is_empty():
		status = "El programa tiene errores: corrígelos antes de ejecutarlo (el control no ejecuta un bloque erróneo)."
		changed.emit()
		return
	if lathe.is_halted():
		status = "Máquina en alarma: pulsa RESET y reinicia la pieza."
		changed.emit()
		return
	if lathe.is_done():
		_new_lathe()
	playing = true
	status = ""
	changed.emit()


func pause() -> void:
	if not playing:
		return
	playing = false
	changed.emit()


func toggle_play() -> void:
	if playing:
		pause()
	else:
		play()


## Bloque a bloque: ejecuta hasta que empieza el siguiente bloque N (un ciclo fijo es un solo bloque) y se para.
func step_block() -> void:
	if lathe_mode != "cnc":
		return
	playing = false
	if not errors().is_empty() or lathe.is_halted():
		play()  # deja el mensaje de por qué no arranca
		return
	if lathe.is_done():
		_new_lathe()
	var n0 := int(lathe.state()["block_n"])
	var t := 0.0
	while t < BLOCK_MAX_S and not lathe.is_done() and not lathe.is_halted():
		lathe.step(BLOCK_SUBSTEP_S)
		t += BLOCK_SUBSTEP_S
		var n := int(lathe.state()["block_n"])
		if n >= 0 and n != n0:
			break
	_after_steps()
	changed.emit()


## Bruto nuevo con el mismo programa y la misma pieza (o la misma máquina, en manual).
func restart() -> void:
	_new_lathe()
	status = ""
	changed.emit()


## RESET del control: sale del estado de alarma y cancela el programa (la pieza se queda como está).
func reset_alarm() -> void:
	lathe.reset()
	playing = false
	_sync()
	status = "RESET: alarma borrada y programa cancelado. Reinicia para mecanizar un bruto nuevo."
	changed.emit()


func set_speed(x: float) -> void:
	speed = clampf(x, SPEEDS[0], SPEEDS[-1])
	changed.emit()


## Avanza dt_s segundos reales (× speed de tiempo simulado, en subpasos). En CNC solo con el programa en marcha; en
## manual siempre (cabezal, avances y manivelas). Emite changed al terminar el programa, con una alarma nueva o al
## pararse la máquina.
func advance(dt_s: float) -> void:
	if lathe == null or dt_s <= 0.0:
		return
	var running := lathe_mode == "manual" or playing
	if not running:
		return
	var sim := minf(dt_s * speed, MAX_ADVANCE_S)
	var n := floori(sim / SUBSTEP_S)
	var rest := sim - n * SUBSTEP_S
	for k in n:
		lathe.step(SUBSTEP_S)
		if _stop_now():
			break
	if rest > 1e-9 and not _stop_now():
		lathe.step(rest)
	if _after_steps():
		changed.emit()


func _stop_now() -> bool:
	return lathe.is_halted() or (lathe_mode == "cnc" and lathe.is_done())


## Tras avanzar: perfil, estado y noticias. Devuelve true si hay algo nuevo para la interfaz.
func _after_steps() -> bool:
	_sync()
	var news := false
	var count := lathe.alarms().size()
	if count != _alarm_count:
		_alarm_count = count
		news = true
	if lathe.is_halted():
		if playing:
			playing = false
			news = true
		if not status.begins_with("Alarma"):
			status = "Alarma: la máquina se ha detenido. Mira la lista de alarmas, pulsa RESET y reinicia."
			news = true
	elif lathe_mode == "cnc" and lathe.is_done() and report == null:
		playing = false
		report = Inspection.inspect_part(_profile, drawing)
		status = "Programa terminado: informe de inspección de la pieza contra su plano."
		news = true
	return news


## El texto con las tablas de herramientas y correctores de la torreta del programa (Programs.options): con ellas,
## G41/G42 compensan con el radio y el código de forma de cada plaquita.
func _interpret() -> void:
	interp = Gcode.interpret_program(program_text, Programs.options(program_id))


func _new_lathe() -> void:
	var st: Dictionary = (Lathe.STOCKS[piece] as Dictionary).duplicate()
	if lathe_mode == "manual" and manual_work != "":
		var m := WorkMaterials.get_material(manual_work)
		if not m.is_empty():
			st["work_id"] = manual_work
			st["work_kind"] = m["kind"]
	lathe = Lathe.new(st, lathe_mode, Cutting.model_callable())
	drawing = Drawing.get_drawing(piece)
	if lathe_mode == "cnc":
		lathe.set_tool_table(Programs.EXAMPLE_PROGRAMS[program_id]["turret"])
		lathe.load_moves(interp.get("moves", []))
	else:
		lathe.set_tool(manual_tool)
		lathe.set_coolant(coolant)
		# el torno deja la punta a 40 mm del bruto (sitio para la torreta de un programa); en manual se empieza cerca
		lathe.place_tool(0.5 * float(st["d"]) + MANUAL_START_GAP_MM, float(st["face_z"]) + MANUAL_START_GAP_MM)
	playing = false
	report = null
	_alarm_count = 0
	_profile = {}
	_sync()
	var n := (_profile["r"] as PackedFloat64Array).size()
	# Bruto nuevo: para quien ya pintaba la pieza anterior (con la misma rejilla), han cambiado todos los anillos
	_view_dirty = Vector2i(0, n - 1)
	band = Drawing.tolerance_band(drawing, _profile["z0"], _profile["dz"], n)
	lathe_serial += 1


## Lee el estado y el perfil del torno (una sola vez: profile() consume el rango sucio) y acumula el rango sucio
## para la escena 3D.
func _sync() -> void:
	_st = lathe.state()
	var p: Dictionary = lathe.profile()
	var d: Vector2i = p["dirty"]
	if d.x >= 0:
		if _view_dirty.x < 0:
			_view_dirty = d
		else:
			_view_dirty = Vector2i(mini(_view_dirty.x, d.x), maxi(_view_dirty.y, d.y))
	_profile = p


# ── Lecturas del torno ──

## state() del torno (el último leído).
func lathe_state() -> Dictionary:
	return _st


## Perfil del contrato para la escena 3D: el rango sucio es el acumulado desde la lectura anterior (así la escena
## 3D no pierde cambios aunque el torno avance varias veces entre fotogramas). La vista 2D y los tests usan
## peek_profile(), que no lo consume.
func profile() -> Dictionary:
	var p := _profile.duplicate()
	p["dirty"] = _view_dirty
	_view_dirty = Vector2i(-1, -1)
	return p


func peek_profile() -> Dictionary:
	return _profile


## Punta teórica de la herramienta (r, z) en mm, para la escena 3D (set_profile_source la lee sola).
func tool_pose() -> Vector2:
	var tip: Dictionary = _st["tip"]
	return Vector2(tip["r"], tip["z"])


## Bruto del torno actual (claves de Lathe.STOCKS, con el material que tenga).
func stock() -> Dictionary:
	return lathe.stock()


func errors() -> Array:
	return interp.get("errors", [])


func warnings() -> Array:
	return interp.get("warnings", [])


func is_running() -> bool:
	return lathe_mode == "manual" or playing


## Alarmas con su título y si detienen la máquina: [{ code, n, message, title, halt }].
func lathe_alarms() -> Array:
	var out: Array = []
	for a in lathe.alarms():
		var info: Dictionary = Lathe.ALARMS.get(a["code"], { "title": a["code"], "halt": false })
		out.append({ "code": a["code"], "n": a["n"], "message": a["message"], "title": info["title"], "halt": info["halt"] })
	return out


## Lecturas del torno para la interfaz: lo que publica state(), más la vc en la punta con el cabezal girando sin
## cortar (Cutting.vc_from_rpm) y el Ra del anillo recién mecanizado detrás de la punta (ring_ra del perfil).
func lathe_readings() -> Dictionary:
	var st := _st
	var sp: Dictionary = st["spindle"]
	var rpm := float(sp["rpm"])
	var cutting := bool(st["cutting"])
	var vc := float(st["vc_m_min"]) if cutting else Cutting.vc_from_rpm(rpm, float(st["x_diam"]))
	var fd: Dictionary = st["feed"]
	var m := lathe.machine()
	var summary: Dictionary = interp.get("summary", {})
	return {
		"t_s": st["t_s"], "program_time_s": summary.get("time_s", null) if lathe_mode == "cnc" else null,
		"rpm": rpm, "rpm_goal": sp["rpm_goal"], "dir": sp["dir"], "css": sp["css"], "vc": vc,
		"feed_mode": fd["mode"], "feed": fd["value"], "ap_mm": st["ap_mm"], "h_mm": st["h_mm"],
		"pc_kw": st["pc_kw"], "pc_peak_kw": st["pc_peak_kw"], "power_kw": m["power_kw"], "fc_n": st["fc_n"],
		"kc": st["kc"], "cutting": cutting, "cut_ok": st["cut_ok"], "cut_reason": st["cut_reason"],
		"ra_um": _ra_behind_tip(), "removed_mm3": st["removed_mm3"], "volume_mm3": st["volume_mm3"],
		"block_n": st["block_n"], "line": st["line"], "motion": st["motion"], "coolant": st["coolant"],
		"tool_id": st["tool_id"], "re_mm": st["re_mm"], "x_diam": st["x_diam"], "z": (st["tip"] as Dictionary)["z"],
		"halted": st["halted"], "done": st["program_done"], "machine_name": m["name"],
		# roscado en curso (G33, G86): { pitch, pass, passes, depth, total, kind, … } o null
		"thread": st.get("thread", null),
	}


## Ra (µm) del anillo que queda 0,5 mm por detrás del contacto de la punta (el centro del radio de punta está en
## z + rε): la superficie que acaba de dejar al cilindrar hacia el plato. null si ese anillo no está mecanizado.
func _ra_behind_tip() -> Variant:
	if _profile.is_empty():
		return null
	var rr: PackedFloat64Array = _profile["r"]
	var ra: PackedFloat32Array = _profile["ring_ra"]
	var ps: PackedByteArray = _profile["ring_pass"]
	var z := float((_st["tip"] as Dictionary)["z"]) + float(_st.get("nose_center", { "dz": _st["re_mm"] })["dz"]) + 0.5
	var i := roundi((z - float(_profile["z0"])) / float(_profile["dz"]))
	# (un anillo roscado no es una superficie de rugosímetro: su perfil es el diente de la rosca)
	if i < 0 or i >= rr.size() or rr[i] <= 0.0 or ps[i] < Lathe.PASS_ROUGH or ps[i] == Lathe.PASS_THREAD:
		return null
	return float(ra[i])


## Entrada de sonido del torno ya convertida (CONTRATOS.md): tool_pos en metros y en el sistema del nodo de sonido
## (ver sound_pos_m). El CNC regula el giro con variador (speed_droop 0); con el programa en pausa el cabezal gira
## pero los ejes no avanzan: no hay corte.
func lathe_sound_input() -> Dictionary:
	var inp: Dictionary = lathe.sound_input()
	var pos: Vector3 = inp["tool_pos"]  # (z, r, 0) en mm, coordenadas de la pieza
	inp["tool_pos"] = sound_pos_m(pos.x, pos.y)
	if lathe_mode == "cnc":
		inp["speed_droop"] = 0.0
	if bool(_st["cutting"]):
		inp["vc"] = float(_st["vc_m_min"])
	if not is_running():
		inp["pc_kw"] = 0.0
		inp["chatter"] = null
	return inp


## Posición del plato para el reproductor de sonido (m, en el mismo sistema que sound_pos_m): la cara de las garras.
func lathe_chuck_pos_m() -> Vector3:
	var st := lathe.stock()
	var z_jaw := float(st["face_z"]) - float(st["length"]) + float(st["clamp"])
	return sound_pos_m(z_jaw, 0.0)


## Del sistema de la pieza (z y r en mm) al del nodo de sonido (m): origen en Z0 sobre el eje del cabezal, x hacia el
## contrapunto (Z+, a la derecha del operario), y hacia arriba y z hacia el operario (el radio de la punta de la
## torreta delantera). Es el marco de la escena 3D (lathe_3d.gd → tool_tip_local) con el origen en Z0.
static func sound_pos_m(z_mm: float, r_mm: float) -> Vector3:
	return Vector3(z_mm / 1000.0, 0.0, r_mm / 1000.0)


# ── Mando manual (torno paralelo) ──

## Cabezal a mano: «cw» (M3), «ccw» (M4) o «stop», con las rpm elegidas (la caja da la velocidad más cercana).
func manual_spindle(dir: String) -> void:
	if lathe_mode != "manual":
		return
	lathe.set_spindle(manual_rpm, dir)
	_sync()
	changed.emit()


## rpm de la caja del cabezal. Si el cabezal ya gira, cambia al momento.
func set_manual_rpm(rpm: float) -> void:
	manual_rpm = rpm
	if lathe_mode == "manual":
		var dir := str((_st["spindle"] as Dictionary)["dir"])
		if dir != "stop":
			lathe.set_spindle(manual_rpm, dir)
			_sync()
	changed.emit()


## Velocidades de la caja del torno paralelo (rpm).
func manual_speeds() -> Array:
	return Lathe.MACHINES["manual"]["speeds"]


## Intervalo de avances del carro longitudinal (mm/vuelta) de la ficha del torno paralelo.
func manual_feed_range() -> Array:
	return Lathe.MACHINES["manual"]["feeds_z"]


func set_manual_feed(f: float) -> void:
	var r := manual_feed_range()
	manual_feed = clampf(f, float(r[0]), float(r[1]))
	changed.emit()


## Avance del carro transversal (mm/vuelta) con el avance elegido: la caja del torno paralelo lo da a la relación de
## su ficha (0,025–0,375 frente a 0,05–0,75 mm/vuelta del longitudinal).
func manual_feed_x() -> float:
	var m: Dictionary = Lathe.MACHINES["manual"]
	return manual_feed * float(m["feeds_x"][1]) / float(m["feeds_z"][1])


## Avance automático: eje «z» (cilindrar) o «x» (refrentar), sign −1 hacia el plato o hacia el eje.
func manual_auto_feed(axis: String, sign: float) -> void:
	if lathe_mode != "manual":
		return
	var f := manual_feed_x() if axis == "x" else manual_feed
	lathe.set_feed(axis, f * signf(sign), true)
	_sync()
	changed.emit()


func manual_feed_stop() -> void:
	lathe.set_feed("z", 0.0, false)
	_sync()
	changed.emit()


## Manivela: clicks pasos de jog_step (X en diámetro). Con el cabezal en marcha corta; parado, se detiene al tocar.
func jog(axis: String, clicks: int) -> void:
	if lathe_mode != "manual":
		return
	lathe.jog(axis, float(clicks) * jog_step)
	changed.emit()


func set_jog_step(s: float) -> void:
	jog_step = s
	changed.emit()


## Herramienta del catálogo de lathe_tools («PORTA/PLAQUITA»).
func set_manual_tool(id: String) -> void:
	if LatheTools.tool(id).is_empty():
		return
	manual_tool = id
	if lathe_mode == "manual":
		lathe.set_tool(id)
		_sync()
	changed.emit()


## Material del bruto en manual (id de work_materials; «» = el del plano). Bruto nuevo.
func set_manual_work(id: String) -> void:
	manual_work = id
	if lathe_mode == "manual":
		_new_lathe()
	changed.emit()


func set_coolant(on: bool) -> void:
	coolant = on
	if lathe_mode == "manual":
		lathe.set_coolant(on)
		_sync()
	changed.emit()


## Mide la pieza tal como está contra su plano (en manual; en CNC el informe sale al terminar el programa).
func measure() -> void:
	report = Inspection.inspect_part(_profile, drawing)
	changed.emit()


# ══════════════════════════════ Radial ══════════════════════════════

## Cambia un parámetro de la radial (claves de la entrada de cut_panel) y recalcula. Al cambiar de disco se queda
## en un diámetro que el fabricante haga de ese disco; al cambiar de diámetro, la radial es la de ese diámetro y gira
## a sus rpm nominales.
func set_radial(key: String, value: Variant) -> void:
	radial = radial.duplicate()
	radial[key] = value
	if key == "disc_id":
		var ds := radial_diameters()
		var d := float(radial["diameter_mm"])
		if not ds.has(d):
			var best: float = ds[0]
			for x: float in ds:
				if absf(x - 125.0) < absf(best - 125.0):
					best = x
			radial["diameter_mm"] = best
			radial["rpm"] = float(Radial.grinder_for(best)["rpm"])
	elif key == "diameter_mm":
		radial["rpm"] = float(Radial.grinder_for(float(value))["rpm"])
	_refresh_radial()
	changed.emit()


## Diámetros (mm) que el fabricante hace del disco (rpm_by_diameter de abrasives.gd), de menor a mayor.
func radial_diameters(disc_id: String = "") -> Array[float]:
	var id := disc_id if disc_id != "" else str(radial["disc_id"])
	var out: Array[float] = []
	var disc: Dictionary = Abrasives.DISCS.get(id, {})
	for d in disc.get("rpm_by_diameter", {}):
		out.append(float(d))
	out.sort()
	return out


## Radial de ese diámetro (Radial.GRINDERS): nombre, potencia útil y rpm nominales.
func radial_grinder() -> Dictionary:
	return Radial.grinder_for(float(radial["diameter_mm"]))


func _refresh_radial() -> void:
	radial_check = Radial.disc_check({
		"disc_id": radial["disc_id"], "diameter_mm": radial["diameter_mm"], "rpm": radial["rpm"],
	})
	radial_result = Radial.cut_panel(radial)


## Entrada de sonido de la radial. cutting: si el disco está dentro de la chapa ahora (lo sabe la escena 3D).
func radial_sound_input(cutting: bool) -> Dictionary:
	var panel := Panels.get_panel(str(radial["panel_id"]))
	return {
		"process": "grinder", "rpm": radial["rpm"], "disc_id": radial["disc_id"],
		"pc_kw": float(radial_result.get("power_kw", 0.0)) if cutting else 0.0,
		"pmax_kw": radial_grinder()["power_kw"], "work_kind": panel.get("kind", "acero"),
		"sheet_mm": panel.get("t_mm", 1.0), "coolant": false, "chatter": null, "tool_pos": Vector3.ZERO,
	}


# ══════════════════════════════ Afiladora ══════════════════════════════

## Cambia un parámetro de la afiladora y recalcula. Otra máquina trae su muela de serie (diámetro, rpm y húmedo o
## seco); otra herramienta, su acero y su máquina por defecto.
func set_sharpen(key: String, value: Variant) -> void:
	sharpen = sharpen.duplicate()
	sharpen[key] = value
	if key == "kind":
		sharpen["steel_id"] = "x50crmov15" if value == "cuchillo" else "m2"
		sharpen["diameter_mm"] = 10.0 if value == "broca" else 12.0
		_machine_defaults(SHARPEN_DEFAULT_MACHINE.get(value, "esmeriladora_banco"))
	elif key == "machine_id":
		_machine_defaults(str(value))
	_refresh_sharpen()
	changed.emit()


func _machine_defaults(id: String) -> void:
	var m: Dictionary = Sharpening.SHARPENING_MACHINES.get(id, {})
	if m.is_empty():
		return
	sharpen["machine_id"] = id
	sharpen["wheel_diameter_mm"] = float(m["wheel_diameter_mm"]["value"])
	sharpen["rpm"] = float(m["rpm"]["value"]) if m["rpm"] is Dictionary else 0.0  # 0: el centro de lo recomendado
	sharpen["wet"] = bool(m["wet"])
	sharpen["wheel_abrasive_id"] = ""


## Petición de recommend_sharpening con los parámetros actuales.
func sharpen_request() -> Dictionary:
	var s := sharpen
	var req := {
		"tool": {
			"kind": s["kind"], "steel_id": s["steel_id"], "style": s["style"], "use": s["use"],
			"work_material": s["work_material"], "diameter_mm": s["diameter_mm"],
		},
		"machine_id": s["machine_id"], "wheel_diameter_mm": s["wheel_diameter_mm"], "wet": s["wet"],
	}
	if float(s["rpm"]) > 0.0:
		req["rpm"] = s["rpm"]
	if str(s["wheel_abrasive_id"]) != "":
		req["wheel_abrasive_id"] = s["wheel_abrasive_id"]
	return req


func _refresh_sharpen() -> void:
	sharpen_result = Sharpening.recommend_sharpening(sharpen_request())


## Entrada de sonido de la afiladora: la máquina a sus rpm con la potencia de la operación nominal del modelo
## térmico (μ·F·v); sin ella (metal duro), en vacío.
func sharpen_sound_input() -> Dictionary:
	var m: Dictionary = sharpen_result.get("machine", {})
	var heat: Variant = sharpen_result.get("heat")
	var pc := 0.0
	if heat is Dictionary and (heat as Dictionary).get("inputs") is Dictionary:
		pc = float(heat["inputs"]["power_w"]) / 1000.0
	return {
		"process": "sharpener", "rpm": m.get("rpm", 0.0), "pc_kw": pc, "coolant": bool(m.get("wet", false)),
		"work_kind": "acero", "chatter": null, "tool_pos": Vector3.ZERO,
	}


# ══════════════════════════════ Calculadoras ══════════════════════════════

func set_calc_kind(kind: String) -> void:
	if not (kind in CALC_KINDS):
		return
	calc_kind = kind
	_refresh_calc()
	changed.emit()


## Cambia una entrada de la calculadora activa y recalcula.
func set_calc(key: String, value: Variant) -> void:
	calc = calc.duplicate(true)
	calc[calc_kind][key] = value
	_refresh_calc()
	changed.emit()


## Entrada de la calculadora activa, como la recibe cutting.gd. El torneado lleva la máquina del torno CNC (potencia,
## tope de rpm y rendimiento por defecto); la fresadora y el taladro no tienen ficha en el taller: sin máquina no hay
## aviso de sobrecarga.
func calc_request() -> Dictionary:
	var p: Dictionary = (calc[calc_kind] as Dictionary).duplicate()
	if calc_kind == "torneado":
		var m: Dictionary = Lathe.MACHINES["cnc"]
		p["machine"] = { "pmax_kw": m["power_kw"], "rpm_max": m["rpm_max"], "eta": Cutting.ETA_DEFAULT }
	return p


func _refresh_calc() -> void:
	var p := calc_request()
	match calc_kind:
		"torneado":
			calc_result = Cutting.turning(p)
		"fresado":
			calc_result = Cutting.milling(p)
		_:
			calc_result = Cutting.drilling(p)
