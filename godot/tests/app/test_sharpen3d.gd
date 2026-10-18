## Afiladora 3D (app/taller/sharpen3d/sharpen_3d.tscn) sin ventana: la escena se carga, acepta los diccionarios de
## vista de las cinco máquinas y de las herramientas (CONTRATOS.md → «Vista 3D de la afiladora»), avanza con
## advance() como haría _process y, en cada fotograma, no crea nodos. El sonido de la demo es determinista.
## Las vistas de máquina son copias de lo que da SharpeningMachines.view() (unidad 1b); si el catálogo está en el
## árbol (rama de integración), se prueban además todas sus máquinas y muelas.
extends "res://tests/case.gd"

const SCENE := "res://app/taller/sharpen3d/sharpen_3d.tscn"
const MachineSound = preload("res://core/taller/machine_sound.gd")
const Demo = preload("res://app/taller/demo_afilado3d.gd")
const DemoSim = preload("res://app/taller/sharpen3d/demo_sim.gd")
const CATALOG := "res://core/taller/sharpening_machines.gd"
const FRAME := 1.0 / 30.0

## Vistas de máquina como las de SharpeningMachines.view(id) (unidad 1b), con los campos que la escena lee.
const MACHINE_VIEWS := {
	"einhell_tc_bg_150": { "machine_id": "einhell_tc_bg_150", "kind": "banco", "rpm": 2980.0, "wet": false,
		"water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "grueso", "position": "izquierda", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
				"grit": "K36", "rpm": 2980.0, "wet": false, "honing": false, "selected": true },
			{ "id": "fino", "position": "derecha", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
				"grit": "K60", "rpm": 2980.0, "wet": false, "honing": false, "selected": false }] },
	"einhell_tc_wd_200_150": { "machine_id": "einhell_tc_wd_200_150", "kind": "banco", "rpm": 134.0, "wet": true,
		"water_trough": true, "quench_pot": false, "wheels": [
			{ "id": "seca", "position": "derecha", "d_mm": 150.0, "width_mm": 20.0, "abrasive_id": "al2o3",
				"grit": "K36", "rpm": 2980.0, "wet": false, "honing": false, "selected": false },
			{ "id": "humeda", "position": "piedra", "d_mm": 200.0, "width_mm": 40.0, "abrasive_id": "",
				"grit": "K200", "rpm": 134.0, "wet": true, "honing": false, "selected": true }] },
	"vevor_md150_4": { "machine_id": "vevor_md150_4", "kind": "banco", "rpm": 1750.0, "wet": false,
		"water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "grueso", "position": "izquierda", "d_mm": 150.0, "width_mm": null, "abrasive_id": "al2o3",
				"grit": "36", "rpm": 1750.0, "wet": false, "honing": false, "selected": true },
			{ "id": "fino", "position": "derecha", "d_mm": 150.0, "width_mm": null, "abrasive_id": "al2o3",
				"grit": "60", "rpm": 1750.0, "wet": false, "honing": false, "selected": false }] },
	"vevor_md150g_450": { "machine_id": "vevor_md150g_450", "kind": "banco", "rpm": 3450.0, "wet": false,
		"water_trough": false, "quench_pot": true, "wheels": [
			{ "id": "grueso", "position": "izquierda", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
				"grit": "36", "rpm": 3450.0, "wet": false, "honing": false, "selected": true },
			{ "id": "fino", "position": "derecha", "d_mm": 150.0, "width_mm": 16.0, "abrasive_id": "al2o3",
				"grit": "60", "rpm": 3450.0, "wet": false, "honing": false, "selected": false }] },
	"tormek_t8": { "machine_id": "tormek_t8", "kind": "humeda_lenta", "rpm": 100.0, "wet": true,
		"water_trough": true, "quench_pot": false, "wheels": [
			{ "id": "sg250", "position": "piedra", "d_mm": 250.0, "width_mm": 50.0, "abrasive_id": "al2o3",
				"grit": "220", "rpm": 100.0, "wet": true, "honing": false, "selected": true },
			{ "id": "la220", "position": "cuero", "d_mm": 220.0, "width_mm": 31.0, "abrasive_id": "",
				"grit": "", "rpm": 100.0, "wet": false, "honing": true, "selected": false }] },
	"einhell_te_ag_125_ce": { "machine_id": "einhell_te_ag_125_ce", "kind": "amoladora", "rpm": 12000.0,
		"wet": false, "water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "laminas", "position": "disco", "d_mm": 125.0, "width_mm": null, "abrasive_id": "al2o3",
				"grit": "P60", "rpm": 12000.0, "wet": false, "honing": false, "selected": true }] },
	"einhell_te_ag_125_ce_desbaste": { "machine_id": "einhell_te_ag_125_ce", "kind": "amoladora", "rpm": 12000.0,
		"wet": false, "water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "desbaste", "position": "disco", "d_mm": 125.0, "width_mm": 7.2, "abrasive_id": "al2o3",
				"grit": "", "rpm": 12000.0, "wet": false, "honing": false, "selected": true }] },
	"mrcm_mr_13a": { "machine_id": "mrcm_mr_13a", "kind": "afilabrocas", "rpm": 4400.0, "wet": false,
		"water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "cbn", "position": "disco", "d_mm": 78.0, "width_mm": 10.0, "abrasive_id": "cbn",
				"grit": "230", "rpm": 4400.0, "wet": false, "honing": false, "selected": true }] },
	"mrcm_mr_x3": { "machine_id": "mrcm_mr_x3", "kind": "afilafresas", "rpm": 4400.0, "wet": false,
		"water_trough": false, "quench_pot": false, "wheels": [
			{ "id": "sdc", "position": "disco", "d_mm": 78.0, "width_mm": 10.0, "abrasive_id": "diamante",
				"grit": "230", "rpm": 4400.0, "wet": false, "honing": false, "selected": true }] },
}
## Herramientas: las cinco de la escena, con medidas y sin ellas (null o ausentes: las de dibujo)
const TOOL_VIEWS := [
	{ "kind": "cuchillo", "length_mm": 200.0, "width_mm": 45.0, "spine_mm": 2.5, "steel_id": "x50crmov15" },
	{ "kind": "cuchillo", "use": "hacha", "length_mm": 170.0, "width_mm": 90.0, "spine_mm": 25.0, "steel_id": "1095" },
	{ "kind": "hacha", "steel_id": "1095" },
	{ "kind": "cortacesped", "length_mm": 480.0, "width_mm": 50.0, "spine_mm": 4.0, "steel_id": "" },
	{ "kind": "broca", "diameter_mm": 10.0, "length_mm": 133.0, "steel_id": "m2" },
	{ "kind": "broca", "diameter_mm": null, "steel_id": "m2" },
	{ "kind": "fresa", "diameter_mm": 12.0, "length_mm": 83.0, "flutes": 4, "steel_id": "metal_duro" },
	{ "kind": "fresa", "diameter_mm": 8.0, "flutes": 3, "steel_id": "m2" },
]


func _scene() -> Node3D:
	return (load(SCENE) as PackedScene).instantiate() as Node3D


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c


func _state(t: float, contact: bool, angle: float) -> Dictionary:
	var temps := PackedFloat32Array()
	for k in 8:
		temps.append(20.0 + 300.0 * t * (1.0 - absf(float(k) / 7.0 - 0.5)))
	return {
		"angle_deg": angle, "force_n": 10.0, "contact": contact, "contact_pos": fposmod(t * 0.3, 1.0),
		"edge_temp_c": temps, "max_temp_c": 20.0 + 300.0 * t, "burr": clampf(t, 0.0, 1.0),
		"sparks": { "rate": 900.0, "color": "#FFC860", "length_mm": 300.0 }, "water": true,
	}


func test_la_escena_carga_con_su_api() -> void:
	var s := _scene()
	for m in ["set_machine", "set_tool", "set_state", "set_view"]:
		assert_true(s.has_method(m), "la raíz expone %s()" % m)
	s.call("advance", FRAME)
	var info: Dictionary = s.call("info")
	assert_eq(info["machine_kind"], "banco", "por defecto, la esmeriladora de banco")
	assert_eq(info["tool_kind"], "cuchillo", "y un cuchillo")
	assert_eq(info["view"], "general", "vista general")
	s.free()


## El ejecutor corre los tests en su _init, sin árbol todavía: _ready se llama a mano, como lo haría el árbol.
func test_ready_sin_errores() -> void:
	var s := _scene()
	s.call("_ready")
	var info: Dictionary = s.call("info")
	assert_eq(info["machine_kind"], "banco", "_ready construye la máquina por defecto")
	assert_eq(info["tool_kind"], "cuchillo", "y la herramienta")
	var cam := s.find_child("Camera3D", true, false) as Camera3D
	assert_true(cam != null and cam.current, "con su cámara")
	s.call("_process", FRAME)
	assert_eq(int(s.call("info")["frames"]), 1, "_process avanza un fotograma")
	s.free()


func test_acepta_las_cinco_maquinas_y_las_vistas_del_catalogo() -> void:
	var s := _scene()
	var seen := {}
	for id in MACHINE_VIEWS:
		var v: Dictionary = MACHINE_VIEWS[id]
		s.call("set_machine", v)
		s.call("set_state", _state(0.2, true, 20.0))
		s.call("advance", FRAME)
		var info: Dictionary = s.call("info")
		assert_eq(info["machine_kind"], v["kind"], "%s: tipo" % id)
		assert_eq(info["wheels"], (v["wheels"] as Array).size(), "%s: una muela por cada una de la vista" % id)
		seen[v["kind"]] = true
	assert_eq(seen.size(), 5, "las cinco máquinas de la vista 3D")
	# Si el catálogo de la unidad 1b está en el árbol, todas sus máquinas y cada muela seleccionada
	if ResourceLoader.exists(CATALOG):
		var SM: Script = load(CATALOG)
		var machines: Dictionary = SM.get("MACHINES")
		for id in machines:
			for i in (machines[id]["wheels"] as Array).size():
				var v: Dictionary = SM.call("view", id, i)
				s.call("set_machine", v)
				s.call("advance", FRAME)
				assert_eq(s.call("info")["machine_kind"], v["kind"], "%s (muela %d)" % [id, i])
	s.free()


func test_ancho_null_y_rpm_por_muela() -> void:
	var s := _scene()
	s.call("set_machine", MACHINE_VIEWS["vevor_md150_4"])
	s.call("advance", FRAME)
	var info: Dictionary = s.call("info")
	assert_eq(info["wheels"], 2, "dos muelas aunque no se sepa su ancho")
	assert_near(float(info["rpm"]), 1750.0, 1e-12, 0.0, "las rpm de la muela")
	# Combinada: cada muela gira a las suyas (la piedra a 134 rpm y la seca a 2980)
	s.call("set_machine", MACHINE_VIEWS["einhell_tc_wd_200_150"])
	s.call("set_state", { "wheel": "piedra" })
	s.call("advance", FRAME)
	assert_near(float(s.call("info")["rpm"]), 134.0, 1e-12, 0.0, "la piedra, a 134 rpm")
	s.call("set_state", { "wheel": "derecha" })
	s.call("advance", FRAME)
	assert_near(float(s.call("info")["rpm"]), 2980.0, 1e-12, 0.0, "la muela seca, a 2980 rpm")
	s.free()


func test_acepta_las_herramientas() -> void:
	var s := _scene()
	var fits := {
		"banco": ["cuchillo", "hacha", "cortacesped", "broca"],
		"humeda_lenta": ["cuchillo", "hacha", "cortacesped", "broca"],
		"amoladora": ["cuchillo", "hacha", "cortacesped"],
		"afilabrocas": ["broca"],
		"afilafresas": ["fresa"],
	}
	for id in ["einhell_tc_bg_150", "tormek_t8", "einhell_te_ag_125_ce", "mrcm_mr_13a", "mrcm_mr_x3"]:
		var mv: Dictionary = MACHINE_VIEWS[id]
		s.call("set_machine", mv)
		for tv in TOOL_VIEWS:
			s.call("set_tool", tv)
			s.call("set_state", _state(0.5, true, 118.0 if tv["kind"] == "broca" else (7.0 if tv["kind"] == "fresa" else 20.0)))
			for k in 3:
				s.call("advance", FRAME)
			var info: Dictionary = s.call("info")
			var kind: String = "hacha" if tv.get("use", "") == "hacha" else tv["kind"]
			assert_eq(info["tool_kind"], kind, "%s: herramienta %s" % [id, kind])
			var ok: bool = (fits[mv["kind"]] as Array).has(kind)
			assert_eq(info["compatible"], ok, "%s con %s: %s" % [id, kind, "se afila" if ok else "queda en la mesa"])
			if ok:
				assert_true(info["contact"], "%s con %s: en contacto" % [id, kind])
				var cp: Vector3 = s.call("contact_point")
				assert_true(cp.length() > 0.01 and cp.length() < 1.0, "%s con %s: contacto en la máquina (%s)" % [id, kind, cp])
	s.free()


func test_set_state_no_crea_nodos() -> void:
	var s := _scene()
	for pair in [["einhell_tc_bg_150", 0], ["tormek_t8", 0], ["einhell_te_ag_125_ce", 2], ["mrcm_mr_13a", 4],
			["mrcm_mr_x3", 6], ["einhell_tc_wd_200_150", 3]]:
		s.call("set_machine", MACHINE_VIEWS[pair[0]])
		s.call("set_tool", TOOL_VIEWS[pair[1]])
		for v in ["general", "filo", "seccion"]:
			s.call("set_view", v, true)
			s.call("advance", FRAME)
			var before := _count(s)
			var kind: String = TOOL_VIEWS[pair[1]]["kind"]
			for f in 45:
				var t := float(f) / 45.0
				var base_angle := 118.0 if kind == "broca" else (7.0 if kind == "fresa" else 20.0)
				# El ángulo cambia (la punta de la broca se vuelve a tallar sin nodos nuevos), el contacto entra y sale
				s.call("set_state", _state(t, f % 15 < 11, base_angle + 6.0 * sin(t * TAU)))
				s.call("advance", FRAME)
			assert_eq(_count(s), before, "%s · %s · %s: los fotogramas no crean nodos" % [pair[0], kind, v])
	s.free()


func test_giro_sin_efecto_estroboscopico() -> void:
	var s := _scene()
	s.call("set_machine", MACHINE_VIEWS["einhell_tc_bg_150"])
	s.call("advance", FRAME)
	var info: Dictionary = s.call("info")
	# 2980 rpm a 30 fps: 596° por fotograma. Se enseña desenfocada y girando despacio hacia delante
	assert_near(float(info["deg_per_frame"]), 2980.0 / 60.0 * 360.0 * FRAME, 1e-9, 0.0, "giro real por fotograma")
	assert_true(float(info["blur_rad"]) > PI, "desenfoque de más de media vuelta en la exposición")
	var w: Dictionary = (s.get("_mrig")["wheels"] as Array)[0]
	var a0 := float(w["angle"])
	s.call("advance", FRAME)
	var step := fposmod(float(w["angle"]) - a0, TAU)
	assert_true(step > 0.0 and step < deg_to_rad(6.0), "giro aparente pequeño y en su sentido (%s°)" % rad_to_deg(step))
	# La piedra lenta a 100 rpm se ve girar de verdad (20° por fotograma a 30 fps)
	s.call("set_machine", MACHINE_VIEWS["tormek_t8"])
	s.call("advance", FRAME)
	var ws: Dictionary = (s.get("_mrig")["wheels"] as Array)[0]
	var b0 := float(ws["angle"])
	s.call("advance", FRAME)
	var real := deg_to_rad(100.0 / 60.0 * 360.0 * FRAME)
	assert_near(fposmod(float(ws["angle"]) - b0, TAU), real, 0.05, 0.0, "la piedra lenta gira a su velocidad")
	s.free()


func test_chispas_en_seco_y_ninguna_en_humedo() -> void:
	var s := _scene()
	s.call("set_machine", MACHINE_VIEWS["einhell_tc_bg_150"])
	s.call("set_tool", TOOL_VIEWS[0])
	for f in 20:
		s.call("set_state", _state(0.3, true, 20.0))
		s.call("advance", FRAME)
	assert_true(int(s.call("info")["sparks"]["alive"]) > 0, "esmeriladora: chispas")
	s.call("set_machine", MACHINE_VIEWS["tormek_t8"])
	for f in 20:
		s.call("set_state", _state(0.3, true, 20.0))
		s.call("advance", FRAME)
	assert_eq(int(s.call("info")["sparks"]["alive"]), 0, "piedra húmeda: ninguna chispa")
	s.free()


func test_vistas_y_seccion() -> void:
	var s := _scene()
	for id in ["einhell_tc_bg_150", "einhell_te_ag_125_ce", "mrcm_mr_13a", "mrcm_mr_x3"]:
		s.call("set_machine", MACHINE_VIEWS[id])
		var tool: Dictionary = TOOL_VIEWS[{ "einhell_tc_bg_150": 0, "einhell_te_ag_125_ce": 3, "mrcm_mr_13a": 4,
			"mrcm_mr_x3": 6 }[id]]
		s.call("set_tool", tool)
		for v in ["general", "filo", "seccion", "sección", "detalle"]:
			s.call("set_view", v)
			s.call("set_state", _state(0.4, true, 118.0 if tool["kind"] == "broca" else (7.0 if tool["kind"] == "fresa" else 25.0)))
			for k in 4:
				s.call("advance", FRAME)
			var want: String = { "sección": "seccion", "detalle": "filo" }.get(v, v)
			assert_eq(s.call("info")["view"], want, "%s: vista %s" % [id, v])
			var cam := s.find_child("Camera3D", true, false) as Camera3D
			var ortho := cam.projection == Camera3D.PROJECTION_ORTHOGONAL
			assert_eq(ortho, want == "seccion", "%s · %s: cámara ortográfica solo en la sección" % [id, v])
			if want == "seccion":
				var sec := s.find_child("Seccion", true, false) as Node3D
				assert_true(sec.visible, "%s: dibujo de la sección" % id)
				var label := sec.find_child("Rotulo_angle", true, false) as Label3D
				assert_true(label.text.contains("°"), "%s: rótulo del ángulo (%s)" % [id, label.text])
				assert_true(cam.size > 0.004 and cam.size < 0.05, "%s: a escala del filo (%s m)" % [id, cam.size])
	s.free()


func test_rampa_de_revenido_en_escalones() -> void:
	var s := _scene()
	# Tabla de prueba (la de la aplicación la da edge_thermal.gd): tres escalones
	s.call("set_temper_ramp", [{ "t": 200.0, "hex": "#E6D8A6" }, [260.0, "#9E6A2A"], [300.0, Color("#2E4C9E")]])
	var tex: GradientTexture1D = s.get("_ramp_tex")
	assert_eq(tex.gradient.get_point_count(), 4, "transparente por debajo y tres colores")
	assert_eq(tex.gradient.interpolation_mode, Gradient.GRADIENT_INTERPOLATE_CONSTANT, "en escalones, como EdgeThermal.tint()")
	assert_near(tex.gradient.get_color(0).a, 0.0, 0.0, 1e-9, "sin color por debajo del primero")
	s.free()


func test_sonido_de_la_demo_determinista() -> void:
	# La demo mueve el sonido con su simulador de prueba: la misma hora da la misma entrada y el mismo marco
	for t in [0.0, 1.3, 2.7, 4.1, 5.6, 7.2, 8.9]:
		var a: Dictionary = Demo.sound_input_at(t)
		var b: Dictionary = Demo.sound_input_at(t)
		assert_true(same(a, b), "entrada a %s s" % t)
		assert_true(same(MachineSound.voices(MachineSound.frame(a)), MachineSound.voices(MachineSound.frame(b))), "voces a %s s" % t)
	# Esmeriladora en marcha: gira a n/60 ≈ 49 Hz y el motor zumba a 100 Hz
	var fr := MachineSound.frame(Demo.sound_input_at(1.0))
	var hz := {}
	for tone in fr["tones"]:
		hz[tone["name"]] = tone["hz"]
	assert_near(float(hz["motor_2f"]), 100.0, 1e-12, 0.0, "zumbido a 100 Hz")
	assert_true(absf(float(hz["spindle_1x"]) - 49.2) < 1.0, "giro de la muela ≈ 49 Hz (%s)" % hz["spindle_1x"])
	# Dos simulaciones de prueba iguales dan los mismos estados
	var s1 := DemoSim.new()
	var s2 := DemoSim.new()
	for k in 90:
		assert_true(same(s1.step(FRAME), s2.step(FRAME)), "simulador de prueba determinista (fotograma %d)" % k)
