## Casos de referencia del simulador de afilado (tests/fixtures/spec/afilado.json): el ejecutor de referencia con
## los modelos físicos (grinding.gd, edge_thermal.gd, sharpening_machines.gd, sharpening_heat.gd) y la comprobación
## de lo esperado. El simulador integrado de la oleada 2 (core/taller/sharpening_sim.gd) tiene que dar lo mismo
## dentro de las tolerancias: puede usar check() con sus propias salidas.
##
## Formato de un caso: { id, kind, input, expect: { campo: { value, tol } | { min } | { max } | { min, max } },
## source }. tol es absoluta, en las unidades del campo. Los campos con punto («hardness.loss_hrc») entran en los
## diccionarios. Un campo «aviso_<código>» vale true si la salida trae ese aviso y false si no.
## Tipos (kind): velocidad · amolado · termico · broca_labios · broca_incidencia · broca_revision ·
## fresa_desplazamiento · revenido · color.
extends RefCounted

const Heat = preload("res://core/taller/sharpening_heat.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const Grinding = preload("res://core/taller/grinding.gd")
const EdgeThermal = preload("res://core/taller/edge_thermal.gd")

const INCH_MM := 25.4


## Lee los casos del archivo de la especificación.
static func load_cases(path: String = "res://tests/fixtures/spec/afilado.json") -> Array:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return []
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return []
	return (data as Dictionary).get("cases", [])


## Ejecuta un caso con los modelos físicos y devuelve sus salidas.
static func run_case(c: Dictionary) -> Dictionary:
	var input: Dictionary = c.get("input", {})
	match str(c.get("kind", "")):
		"velocidad":
			return Machines.wheel_speed(str(input["machine_id"]), input.get("wheel", 0), Heat.input_num(input, "rpm", -1.0), Heat.input_num(input, "diameter_mm", -1.0))
		"amolado":
			return _with_warnings(Grinding.grind(input))
		"termico":
			return thermal(input)
		"broca_labios":
			return Grinding.drill_point_offset(input)
		"broca_incidencia":
			var a := Heat.input_num(input, "clearance_deg", 10.0)
			return {
				"effective_clearance_deg": Grinding.effective_clearance(a, Heat.input_num(input, "feed_mm_rev", 0.1), Heat.input_num(input, "r_mm", 1.0)),
				"feed_helix_deg": Grinding.feed_helix_deg(Heat.input_num(input, "feed_mm_rev", 0.1), Heat.input_num(input, "r_mm", 1.0)),
				"chisel_deg": Grinding.chisel_angle_deg(a),
				"wedge_deg": Grinding.lip_wedge_deg(a, Heat.input_num(input, "rake_deg", 30.0)),
			}
		"broca_revision":
			var r := Grinding.drill_check(input)
			var out := { "ok": r["ok"] }
			for f in r["findings"]:
				out["aviso_" + str(f["code"])] = true
			return out
		"fresa_desplazamiento":
			var d_mm := Heat.input_num(input, "diameter_mm", 0.0)
			if d_mm <= 0.0:
				d_mm = Heat.input_num(input, "diameter_in", 0.0) * INCH_MM
			var alpha := Heat.input_num(input, "angle_deg", 7.0)
			var off := Sharpening.cutter_grinder_offset(alpha, d_mm)
			return { "offset_mm": off, "offset_in": off / INCH_MM, "offset_exact_mm": Sharpening.cutter_grinder_offset_exact(alpha, d_mm) }
		"revenido":
			var steel := str(input["steel_id"])
			var p := Heat.hollomon_jaffe(Heat.input_num(input, "temp_c", 20.0), Heat.input_num(input, "time_s", 3600.0), Heat.curve_hj_c(steel))
			return Heat.temper_loss(steel, p)
		"color":
			return EdgeThermal.tint(str(input["steel_id"]), Heat.input_num(input, "temp_c", 20.0))
	return {}


## Ensayo térmico: una sección del filo en la máquina, con la fuerza y el contacto del caso.
## input = { machine_id, wheel, rpm, tool { kind, steel_id, per_side_deg | side_a_deg + side_b_deg, thickness_mm,
## spine_mm, height_mm, apex_um | diameter_mm, point_deg }, contact_len_mm, force_n, contact { on_s, off_s, count },
## cooling_on (por defecto, película de agua si la muela es húmeda y aire si no), cooling_off, dt_s }.
## El calor de cada paso sale de grinding.gd con la temperatura de la cara del contacto del paso anterior (decide si
## el agua enfría). Devuelve el summary() de la sección más { vs_ms, power_w, heat_flux_w_m2, rpm, stalled }.
static func thermal(input: Dictionary) -> Dictionary:
	var tool: Dictionary = input.get("tool", {})
	var steel := str(tool.get("steel_id", "x50crmov15"))
	var prof: Dictionary
	var area := 0.0
	if str(tool.get("kind", "cuchillo")) == "broca":
		prof = EdgeThermal.drill_profile(tool)
		area = float(prof["heated_area_mm2"])
	else:
		var beta := Heat.input_num(tool, "per_side_deg", 17.5)
		prof = EdgeThermal.edge_profile({
			"side_a_deg": Heat.input_num(tool, "side_a_deg", beta),
			"side_b_deg": Heat.input_num(tool, "side_b_deg", beta),
			"shoulder_mm": Heat.input_num(tool, "thickness_mm", 0.6),
			"spine_mm": Heat.input_num(tool, "spine_mm", 2.0),
			"height_mm": Heat.input_num(tool, "height_mm", 40.0),
			"apex_um": Heat.input_num(tool, "apex_um", 1.0),
		})
		area = float(prof["face_width_mm"]) * Heat.input_num(input, "contact_len_mm", 10.0)
	var sec := EdgeThermal.new(prof, steel)
	var g_in := {
		"machine_id": input.get("machine_id", ""), "wheel": input.get("wheel", 0), "rpm": input.get("rpm"),
		"force_n": input.get("force_n", 10.0), "contact_area_mm2": area, "steel_id": steel,
	}
	if input.get("wet") != null:
		g_in["wet"] = input["wet"]
	var cold := Grinding.grind(g_in.merged({ "surface_c": Heat.AMBIENT_C }))
	var hot := Grinding.grind(g_in.merged({ "surface_c": Heat.BURNOUT_WATER_C + 1.0 }))
	var cooling_on := str(input.get("cooling_on", "pelicula_agua" if bool(cold["wet"]) else "aire"))
	var cooling_off := str(input.get("cooling_off", "aire"))
	var contact: Dictionary = input.get("contact", {})
	var on := Heat.input_num(contact, "on_s", 1.0)
	var off := Heat.input_num(contact, "off_s", 0.0)
	var count := maxi(int(Heat.input_num(contact, "count", 1)), 1)
	var dt := Heat.input_num(input, "dt_s", 0.002)
	for _k in count:
		for _s in int(round(on / dt)):
			var g: Dictionary = cold if sec.contact_surface_c() < Heat.BURNOUT_WATER_C else hot
			sec.step(dt, float(g["heat_flux_w_m2"]), 1.0, cooling_on)
		for _s in int(round(off / dt)):
			sec.step(dt, 0.0, 0.0, cooling_off)
	var out := sec.summary()
	out["vs_ms"] = cold["vs_ms"]
	out["rpm"] = cold["rpm"]
	out["stalled"] = cold["stalled"]
	out["power_w"] = cold["power_w"]
	out["heat_flux_w_m2"] = cold["heat_flux_w_m2"]
	return out


## Lo que no cumple un caso (vacío si todo cumple).
static func check(c: Dictionary, out: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var expect: Dictionary = c.get("expect", {})
	for field in expect:
		var rule: Dictionary = expect[field]
		var got: Variant = lookup(out, str(field))
		if got == null and str(field).begins_with("aviso_"):
			got = false
		if rule.has("value") and (typeof(rule["value"]) == TYPE_BOOL or typeof(rule["value"]) == TYPE_STRING):
			if got == null or typeof(got) != typeof(rule["value"]) or got != rule["value"]:
				bad.append("%s.%s: %s, se esperaba %s" % [c.get("id", "?"), field, str(got), str(rule["value"])])
			continue
		if typeof(got) != TYPE_FLOAT and typeof(got) != TYPE_INT:
			bad.append("%s.%s: sin valor numérico (%s)" % [c.get("id", "?"), field, str(got)])
			continue
		var x := float(got)
		if rule.has("value") and absf(x - float(rule["value"])) > float(rule.get("tol", 0.0)) + 1e-12:
			bad.append("%s.%s = %s, se esperaba %s ± %s" % [c.get("id", "?"), field, str(x), str(rule["value"]), str(rule.get("tol", 0.0))])
		if rule.has("min") and x < float(rule["min"]):
			bad.append("%s.%s = %s < %s" % [c.get("id", "?"), field, str(x), str(rule["min"])])
		if rule.has("max") and x > float(rule["max"]):
			bad.append("%s.%s = %s > %s" % [c.get("id", "?"), field, str(x), str(rule["max"])])
	return bad


## Valor de un campo con puntos («hardness.loss_hrc») o null.
static func lookup(out: Dictionary, path: String) -> Variant:
	var node: Variant = out
	for part in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = node[part]
	return node


static func _with_warnings(r: Dictionary) -> Dictionary:
	var out := r.duplicate()
	for w in r.get("warnings", []):
		out["aviso_" + str(w["code"])] = true
	return out
