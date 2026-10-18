## Demostración del sonido de máquina: guion determinista de 12,5 s.
##
## Torno paralelo (motor de 5,5 kW, plato de 3 garras):
##   arranque del cabezal y subida a 1200 rpm, entrada de la herramienta, corte en acero C45 (Ø50) con Pc
##   creciente, corte en aluminio 6082 (Ø40) a 2400 rpm, chatter (voladizo largo), refrigerante y parada.
## Radial de 125 mm sobre chapa de carrocería de acero de 0,8 mm (como en un rescate):
##   arranque, vacío a 11.000 rpm (183,3 Hz), corte limpio con disco fino y corte sucio con disco grueso forzado,
##   en el que el giro se hunde con la carga, y parada.
## Las potencias son ilustrativas (Kienzle con kc de catálogo: C45 ≈ 2500 N/mm², 6082 ≈ 1200 N/mm² con h = 0,2 mm);
## el modelo de corte del taller es de la unidad 5. Todo se mueve con el reloj fijo de la física (60 Hz): el
## mismo guion da el mismo sonido en cada ejecución.
## Captura (desde la raíz): npm run godot:capture -- res://app/taller/demo_sonido.tscn --frames=375 --out=/tmp/demo
## (375 fotogramas a 30 por segundo = 12,5 s: el guion acaba con todo en silencio y detenido).
## Al grabar con Movie Maker escribe junto al vídeo demo_previsto.json: el marco previsto en las ventanas que
## analiza la verificación (frecuencias, niveles y tiempos).
extends Node3D

const MachineSound = preload("res://core/taller/machine_sound.gd")
const MachineSoundPlayer = preload("res://app/taller/machine_sound_player.gd")
const Js = preload("res://core/shared/js.gd")

const DURATION := 12.5
const LATHE := {
	"process": "lathe", "rpm": 0.0, "jaws": 3, "pc_kw": 0.0, "pmax_kw": 5.5, "work_kind": "acero",
	"diameter_mm": 50.0, "chatter": null, "coolant": false, "tool_pos": Vector3(0.08, 0.035, 0.0),
}
const GRINDER := {
	"process": "grinder", "rpm": 0.0, "pc_kw": 0.0, "pmax_kw": 0.72, "work_kind": "acero", "sheet_mm": 0.8,
	"disc_id": "fino_1mm", "chatter": null, "coolant": false, "tool_pos": Vector3(0.0, 0.0, 0.0),
}
const CHUCK_LATHE := Vector3(-0.14, 0.0, 0.0)
## Cabezal de la radial (motor, engrane y giro) respecto al punto de corte: va en la mano, avanza con el disco
const GRINDER_HEAD := Vector3(0.14, 0.08, 0.0)
## Posiciones de la punta en el torno (m; x = Z del torno, con la cara de la pieza en 0; y = radio)
const OUT := Vector3(0.08, 0.035, 0.0)  # retirada
const FACE := Vector3(0.0, 0.026, 0.0)  # frente a la cara (Ø50)
const IN := Vector3(-0.002, 0.025, 0.0)  # dentro del material
const MID := Vector3(-0.03, 0.025, 0.0)  # a 30 mm de la cara
const DEEP := Vector3(-0.055, 0.024, 0.0)  # al final de la pasada
const AL_IN := Vector3(-0.002, 0.02, 0.0)  # dentro del aluminio (Ø40)
const AL_MID := Vector3(-0.03, 0.02, 0.0)
## Radial: la línea de corte en la chapa (m)
const CUT_A := Vector3(-0.08, 0.0, 0.0)
const CUT_B := Vector3(-0.14, 0.0, 0.0)
const CHATTER := { "risk": 1.5, "mode_hz": 820.0 }  # voladizo largo: b/b_lim = 1,5 y modo de 820 Hz
const WOBBLE := [2.5, 0.22]  # corte sucio: la presión oscila a 2,5 Hz (±22 %)
## Tramos: [t0, t1, título, base, entrada al principio, entrada al final]. Los números y los Vector3 se
## interpolan; lo demás toma el valor del final del tramo. «wobble» hace oscilar Pc (corte sucio).
## Aluminio: Ø40 a 2400 rpm (302 m/min).
const SEGMENTS := [
	[0.0, 0.3, "Torno parado", "lathe", {}, {}],
	[0.3, 1.3, "Arranque del cabezal", "lathe", { "rpm": 0.0 }, { "rpm": 1200.0 }],
	[1.3, 2.2, "En vacío a 1200 rpm: la herramienta se acerca", "lathe",
		{ "rpm": 1200.0 }, { "rpm": 1200.0, "tool_pos": FACE }],
	[2.2, 2.4, "Entrada de la herramienta", "lathe",
		{ "rpm": 1200.0, "tool_pos": FACE }, { "rpm": 1200.0, "pc_kw": 0.8, "tool_pos": IN }],
	[2.4, 4.0, "Acero C45 a 188 m/min: Pc de 0,8 a 3,2 kW", "lathe",
		{ "rpm": 1200.0, "pc_kw": 0.8, "tool_pos": IN }, { "rpm": 1200.0, "pc_kw": 3.2, "tool_pos": MID }],
	[4.0, 4.3, "Salida y cambio a aluminio", "lathe",
		{ "rpm": 1200.0, "tool_pos": MID },
		{ "rpm": 2400.0, "work_kind": "aluminio", "diameter_mm": 40.0, "tool_pos": AL_IN }],
	[4.3, 5.1, "Aluminio 6082 a 2400 rpm (302 m/min)", "lathe",
		{ "rpm": 2400.0, "pc_kw": 1.8, "work_kind": "aluminio", "diameter_mm": 40.0, "tool_pos": AL_IN },
		{ "rpm": 2400.0, "pc_kw": 1.8, "work_kind": "aluminio", "diameter_mm": 40.0, "tool_pos": AL_MID }],
	[5.1, 5.3, "Vuelta al acero", "lathe",
		{ "rpm": 2400.0, "work_kind": "aluminio", "diameter_mm": 40.0, "tool_pos": AL_MID },
		{ "rpm": 1200.0, "tool_pos": FACE }],
	[5.3, 6.3, "Chatter: voladizo largo (modo de 820 Hz)", "lathe",
		{ "rpm": 1200.0, "pc_kw": 2.0, "chatter": CHATTER, "tool_pos": IN },
		{ "rpm": 1200.0, "pc_kw": 2.0, "chatter": CHATTER, "tool_pos": MID }],
	[6.3, 7.3, "Refrigerante", "lathe",
		{ "rpm": 1200.0, "pc_kw": 2.4, "coolant": true, "tool_pos": MID },
		{ "rpm": 1200.0, "pc_kw": 2.4, "coolant": true, "tool_pos": DEEP }],
	[7.3, 7.6, "Retirada", "lathe",
		{ "rpm": 1200.0, "pc_kw": 2.4, "tool_pos": DEEP }, { "rpm": 1200.0, "pc_kw": 0.0, "tool_pos": OUT }],
	[7.6, 8.4, "Parada del cabezal", "lathe", { "rpm": 1200.0 }, { "rpm": 0.0 }],
	[8.4, 8.9, "Radial de 125 mm: arranque", "grinder", { "rpm": 0.0 }, { "rpm": 11000.0 }],
	[8.9, 9.6, "Radial en vacío a 11.000 rpm (183,3 Hz)", "grinder", { "rpm": 11000.0 }, { "rpm": 11000.0 }],
	[9.6, 10.7, "Chapa de acero de 0,8 mm, disco fino: corte limpio", "grinder",
		{ "rpm": 11000.0, "pc_kw": 0.36 }, { "rpm": 11000.0, "pc_kw": 0.36, "tool_pos": CUT_A }],
	[10.7, 11.8, "Disco grueso forzado: corte sucio (el giro se hunde)", "grinder",
		{ "rpm": 11000.0, "pc_kw": 0.62, "disc_id": "grueso_3mm", "wobble": WOBBLE, "tool_pos": CUT_A },
		{ "rpm": 11000.0, "pc_kw": 0.62, "disc_id": "grueso_3mm", "wobble": WOBBLE, "tool_pos": CUT_B }],
	[11.8, 12.2, "Parada: se suelta el gatillo (con freno)", "grinder", { "rpm": 11000.0 }, { "rpm": 0.0 }],
	[12.2, 12.5, "Fin", "grinder", {}, {}],
]
## Ventanas que analiza la verificación (s): [nombre, t0, t1].
const WINDOWS := [
	["torno_parado", 0.05, 0.28], ["torno_vacio", 1.5, 2.15], ["acero_1", 2.5, 3.0], ["acero_2", 3.0, 3.5],
	["acero_3", 3.5, 4.0], ["aluminio", 4.45, 5.05], ["chatter", 5.5, 6.25], ["refrigerante", 6.5, 7.25],
	["radial_vacio", 9.15, 9.55], ["radial_limpio", 9.85, 10.65], ["radial_sucio", 10.95, 11.75],
]

var t := 0.0
var sound: MachineSoundPlayer
var _label: Label
var _values: Label
var _lathe: Node3D
var _grinder: Node3D
var _grinder_tool: Node3D
var _chuck_mesh: MeshInstance3D
var _work_mesh: MeshInstance3D
var _tool_mesh: MeshInstance3D
var _disc_mesh: MeshInstance3D
var _spin := 0.0
var _stopped := false


func _ready() -> void:
	_build_scene()
	sound = MachineSoundPlayer.new()
	sound.name = "SonidoMaquina"
	sound.chuck_position = CHUCK_LATHE
	add_child(sound)
	_write_prediction()


## Entrada de sonido del guion en el instante s (función del tiempo: determinista).
static func input_at(s: float) -> Dictionary:
	var seg: Array = SEGMENTS[SEGMENTS.size() - 1]
	for g in SEGMENTS:
		if s >= float(g[0]) and s < float(g[1]):
			seg = g
			break
	var base: Dictionary = (LATHE if seg[3] == "lathe" else GRINDER).duplicate()
	var a: Dictionary = seg[4]
	var b: Dictionary = seg[5]
	var u := clampf((s - float(seg[0])) / (float(seg[1]) - float(seg[0])), 0.0, 1.0)
	for k in a:
		base[k] = a[k]
	for k in b:
		var va: Variant = a.get(k, base.get(k))
		var vb: Variant = b[k]
		if (va is float or va is int) and (vb is float or vb is int):
			base[k] = lerpf(float(va), float(vb), u)
		elif va is Vector3 and vb is Vector3:
			base[k] = (va as Vector3).lerp(vb, u)
		else:
			base[k] = vb
	if base.has("wobble"):
		var w: Array = base["wobble"]
		# Presión irregular: una oscilación y otra a 2,3 veces, sin relación con el giro
		var f: float = w[0]
		var wob := sin(TAU * f * s) + 0.5 * sin(TAU * 2.3 * f * s + 1.0)
		base["pc_kw"] = float(base["pc_kw"]) * (1.0 + float(w[1]) * wob)
		base.erase("wobble")
	base["title"] = seg[2]
	return base


func _physics_process(delta: float) -> void:
	var inp := input_at(t)
	var title: String = inp["title"]
	inp.erase("title")
	var lathe: bool = inp["process"] == "lathe"
	sound.chuck_position = CHUCK_LATHE if lathe else (inp["tool_pos"] as Vector3) + GRINDER_HEAD
	sound.set_input(inp)
	_update_visuals(inp, delta)
	_label.text = title
	var fr: Dictionary = sound.last_frame
	if not fr.is_empty():
		var extra := ""
		if inp["process"] == "grinder":
			extra = " · %s" % MachineSound.DISCS[fr["disc_id"]]["label"].to_lower()
		_values.text = "t = %s s · n = %s rpm · Pc = %s kW · banda del corte %s Hz%s" % [_num(t, 1),
			_num(float(fr["rpm"]), 0), _num(float(inp["pc_kw"]), 2), _num(float(fr["noise"]["fc_hz"]), 0), extra]
	t += delta
	if t >= DURATION - 0.1 and not _stopped:
		sound.stop_now()  # ya en silencio: se sueltan las reproducciones antes de que acabe la grabación
		_stopped = true
	if t >= DURATION + 1.0:
		t = 0.0  # en pantalla, el guion se repite
		_stopped = false


## Número con coma decimal (español de España).
static func _num(x: float, digits: int) -> String:
	return Js.to_fixed(x, digits).replace(".", ",")


func _update_visuals(inp: Dictionary, delta: float) -> void:
	var lathe: bool = inp["process"] == "lathe"
	_lathe.visible = lathe
	_grinder.visible = not lathe
	var fr: Dictionary = sound.last_frame
	var rpm: float = fr["rpm"] if not fr.is_empty() else 0.0
	_spin = fmod(_spin + rpm / 60.0 * TAU * delta, TAU)
	var pos: Vector3 = inp["tool_pos"]
	if lathe:
		_chuck_mesh.rotation = Vector3(_spin, 0.0, PI / 2.0)
		_work_mesh.rotation = Vector3(_spin, 0.0, PI / 2.0)
		var d: float = inp.get("diameter_mm", 50.0)
		_work_mesh.scale = Vector3(d / 50.0, 1.0, d / 50.0)
		_tool_mesh.position = pos + Vector3(0.0, 0.03, 0.0)
	else:
		_disc_mesh.rotation = Vector3(0.0, 0.0, _spin)
		_grinder_tool.position = Vector3(pos.x, 0.0, 0.0)


func _build_scene() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.32, 0.95)
	cam.fov = 40.0
	add_child(cam)
	cam.look_at(Vector3(-0.03, 0.0, 0.0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#170E1C")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.45, 0.55)
	add_child(env)
	# Torno: plato, pieza y herramienta
	_lathe = Node3D.new()
	add_child(_lathe)
	_chuck_mesh = _cylinder(_lathe, 0.08, 0.05, Color("#8a8f99"), CHUCK_LATHE)
	for i in 3:
		var jaw := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.025, 0.035)
		jaw.mesh = bm
		# En la cara del plato que mira a la pieza
		jaw.position = Vector3(0.05 * cos(TAU * i / 3.0), -0.03, 0.05 * sin(TAU * i / 3.0))
		jaw.material_override = _mat(Color("#c9ced6"))
		_chuck_mesh.add_child(jaw)
	_work_mesh = _cylinder(_lathe, 0.025, 0.14, Color("#b7bcc4"), Vector3(-0.07, 0.0, 0.0))
	_tool_mesh = MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.012, 0.06, 0.012)
	_tool_mesh.mesh = tb
	_tool_mesh.material_override = _mat(Color("#E6B450"))
	_lathe.add_child(_tool_mesh)
	# Radial y chapa: la chapa quieta y la radial avanzando por la línea de corte
	_grinder = Node3D.new()
	add_child(_grinder)
	var sheet := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.5, 0.002, 0.3)
	sheet.mesh = sm
	sheet.position = Vector3(0.0, -0.001, 0.0)
	sheet.material_override = _mat(Color("#5BE0C8"))
	_grinder.add_child(sheet)
	_grinder_tool = Node3D.new()
	_grinder.add_child(_grinder_tool)
	_disc_mesh = MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.0625
	dm.bottom_radius = 0.0625
	dm.height = 0.002
	_disc_mesh.mesh = dm
	_disc_mesh.material_override = _mat(Color("#BCA9C7"))
	_disc_mesh.position = Vector3(0.0, 0.05, 0.0)
	var holder := Node3D.new()
	holder.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	_grinder_tool.add_child(holder)
	holder.add_child(_disc_mesh)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.22, 0.06, 0.06)
	body.mesh = bb
	body.position = Vector3(0.14, 0.08, 0.0)
	body.material_override = _mat(Color("#F2A6C0"))
	_grinder_tool.add_child(body)
	_grinder.visible = false
	# Textos
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 18)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color("#5BE0C8"))
	layer.add_child(_label)
	_values = Label.new()
	_values.position = Vector2(24, 56)
	_values.add_theme_font_size_override("font_size", 18)
	_values.add_theme_color_override("font_color", Color("#BCA9C7"))
	layer.add_child(_values)


func _cylinder(parent: Node3D, radius: float, length: float, color: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	mi.mesh = cm
	mi.position = at
	mi.rotation = Vector3(0.0, 0.0, PI / 2.0)
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.metallic = 0.3
	return m


## Con Movie Maker (--write-movie ruta), deja en su carpeta demo_previsto.json: por cada ventana de
## WINDOWS, la entrada en su punto medio con el Pc medio de la ventana y el marco previsto, para comparar con
## el WAV grabado.
func _write_prediction() -> void:
	var movie := Engine.get_write_movie_path()
	if movie == "":
		return
	var out := []
	for w in WINDOWS:
		var mid := (float(w[1]) + float(w[2])) / 2.0
		var inp := input_at(mid)
		var title: String = inp["title"]
		inp.erase("title")
		# Pc medio de la ventana (en el corte sucio oscila)
		var pcs := 0.0
		var steps := 60
		for k in steps:
			pcs += float(input_at(lerpf(float(w[1]), float(w[2]), (k + 0.5) / steps))["pc_kw"])
		inp["pc_kw"] = pcs / steps
		var fr := MachineSound.frame(inp)
		out.append({ "name": w[0], "t0": w[1], "t1": w[2], "title": title, "pc_mean_kw": pcs / steps,
			"input": _jsonable(inp), "frame": _jsonable(fr), "voices": MachineSound.voices(fr) })
	var f := FileAccess.open(movie.get_base_dir().path_join("demo_previsto.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "duration": DURATION, "windows": out }, "  "))
		f.close()


static func _jsonable(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v: Variant = d[k]
		out[k] = [v.x, v.y, v.z] if v is Vector3 else v
	return out
