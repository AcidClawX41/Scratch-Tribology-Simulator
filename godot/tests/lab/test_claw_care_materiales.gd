## Los materiales nuevos de la reforja en el banco y en la cetrería (unidad 5g; docs/fisica/cetreria.md §11 y
## docs/fisica/reforja.md §8): el rubí y la alúmina de ForgeData.NEW_MATERIALS entran en el catálogo 2.0 (Catalog.V2_INLAYS)
## sin tocar el oráculo 1.x; ClawMass, ClawFracture y ClawSharpness tienen sus datos con fuente; ClawCare los lima con su
## propio id. Invariante: el rubí es corindón, con la mecánica del zafiro salvo el color, en todos los motores.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")

const NEW := ["rubi", "alumina"]


static func _inl(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


## Un texto o un volcado con el rubí escrito como el zafiro (para comparar todo lo demás al bit).
static func _as_sapphire(s: String) -> String:
	for pair: Array in [["Rubí sintético", "Zafiro"], ["rubí sintético", "zafiro"], ["Rubí", "Zafiro"], ["rubí", "zafiro"],
			["\"rubi\"", "\"zafiro\""], ["#C8102E", "#7FB6FF"]]:
		s = s.replace(String(pair[0]), String(pair[1]))
	return s


## Compara dos volcados con el rubí escrito como el zafiro y sin las fuentes (las del rubí dicen que es corindón: son otro
## texto); si difieren, dice dónde (un trozo alrededor de la primera diferencia).
func _same_dump(got: String, want: String, msg: String) -> void:
	var re := RegEx.create_from_string("\"source\": \"(?:[^\"\\\\]|\\\\.)*\"")
	got = re.sub(_as_sapphire(got), "\"source\": \"\"", true)
	want = re.sub(_as_sapphire(want), "\"source\": \"\"", true)
	if got == want:
		assert_true(true, msg)
		return
	var i := 0
	while i < mini(got.length(), want.length()) and got[i] == want[i]:
		i += 1
	var a := maxi(i - 120, 0)
	fail("%s: difieren en %d: «…%s» frente a «…%s»" % [msg, i, got.substr(a, 240), want.substr(a, 240)])


func test_en_el_catalogo_2_0_y_no_en_el_oraculo() -> void:
	assert_eq(Catalog.V2_INLAYS.size(), 2, "dos materiales nuevos")
	for id: String in NEW:
		var e: Variant = _inl(id)
		assert_true(e != null, "%s está en Catalog.INLAYS" % id)
		assert_eq(Data.find_by_id(Data.INLAYS, id), null, "%s no está en data.gd: el oráculo 1.x no cambia" % id)
		assert_true(Catalog.is_v2("INLAYS", id), "%s es un añadido de la 2.0" % id)
		assert_true(same(e, ForgeData.NEW_MATERIALS[id]), "%s: la entrada de ForgeData.NEW_MATERIALS, tal cual" % id)
		for k: String in ["name", "short", "col"]:
			assert_true(String(e[k]).length() >= 3, "%s: %s para la interfaz" % [id, k])
		assert_true(String(e.source).length() > 40 and String(e.quality) == "secondary", "%s: fuente y calidad" % id)
	assert_eq(Data.INLAYS.size(), 13, "data.gd sigue con sus 13 entradas")
	assert_eq(Catalog.INLAYS.size(), Data.INLAYS.size() + 2, "el catálogo, con las dos de la 2.0 detrás")


func test_masa_rotura_y_afilado_con_su_fuente() -> void:
	for id: String in NEW:
		var d: Variant = ClawMass.density_of(id)
		assert_true(d != null and String(d.source).length() > 30, "%s: densidad con fuente" % id)
		assert_true(float(d.min) <= float(d.value) and float(d.value) <= float(d.max), "%s: dentro de su banda" % id)
		var st: Variant = ClawFracture.strength(id)
		assert_true(st != null and String(st.kind) == "flexion", "%s: frágil, con su resistencia a flexión" % id)
		assert_true(String(st.source).length() > 30 and String(st.quality) == "secondary", "%s: con fuente" % id)
		assert_eq(ClawFracture.behavior(id), "fragil", "%s: se mella o se parte" % id)
		assert_true(ClawFracture.NOUNS.has(id), "%s: con su nombre en los textos" % id)
		assert_true(ClawSharpness.strength_of(id) != null, "%s: ClawSharpness lee su resistencia" % id)
		# las cifras de los motores de la garra son las de ForgeData.NEW_MATERIALS (un solo dato)
		var nm: Dictionary = ForgeData.NEW_MATERIALS[id]
		assert_eq(float(d.value), float(nm.density), "%s: la densidad de la reforja" % id)
		assert_eq([float(st.value), float(st.min), float(st.max), float(st.kic)],
			[float(nm.strength_mpa), float(nm.strength_min), float(nm.strength_max), float(nm.kic)], "%s: la resistencia de la reforja" % id)
		assert_eq(ForgeData.density_of(id), float(d.value), "%s: la reforja lee lo mismo" % id)
		assert_eq(float(ForgeData.strength_of(id).value), float(st.value), "%s: la reforja lee lo mismo" % id)
	var al: Dictionary = ClawFracture.strength("alumina")
	assert_eq([float(al.value), float(al.kic), String(al.family)], [379.0, 4.5, "ceramica"], "alúmina: 379 MPa y 4,5 MPa·√m (CoorsTek AD-995)")
	assert_eq(float(ClawMass.density_of("alumina").value), 3900.0, "3,90 g/cm³")


## El rubí es corindón: la mecánica del zafiro en todo, salvo el color.
func test_el_rubi_es_el_zafiro_salvo_el_color() -> void:
	var ru := _inl("rubi")
	var za := _inl("zafiro")
	for k: String in ["hv", "mohs", "E", "area", "alpha"]:
		assert_eq(float(ru[k]), float(za[k]), "el mismo %s" % k)
	assert_true(String(ru.col) != String(za.col), "otro color (solo dibujo)")
	for k: String in ["value", "min", "max"]:
		assert_eq(float(ClawMass.density_of("rubi")[k]), float(ClawMass.density_of("zafiro")[k]), "la misma densidad (%s)" % k)
	var s1: Dictionary = ClawFracture.strength("rubi")
	var s2: Dictionary = ClawFracture.strength("zafiro")
	for k: String in ["value", "min", "max", "kic"]:
		assert_eq(float(s1[k]), float(s2[k]), "la misma resistencia (%s)" % k)
	assert_eq(String(s1.kind), String(s2.kind))
	# la garra como viga en voladizo y la punta afilada: lo mismo al bit
	var tip := Contact.tip_geometry(0.04, 15.0, 0.15 * 35.0)
	var e1: Dictionary = ClawFracture.evaluate(ru, tip, 35.0, 200.0, 0.4, 2.0)
	var e2: Dictionary = ClawFracture.evaluate(za, tip, 35.0, 200.0, 0.4, 2.0)
	assert_true(e1 != null and bool(e1.ok), "ClawFracture evalúa la garra de rubí (con su entrada del catálogo)")
	_same_dump((var_to_str(e1)), var_to_str(e2), "la rotura de la garra de rubí es la del zafiro")
	assert_true(ClawFracture.is_reforged(ru), "una garra de rubí es reforjada")
	for s: float in [0.0, 0.3, 0.7, 1.0]:
		var t1 := ClawSharpness.tradeoff(113.0, 15.0, s, float(ru.E), ClawSharpness.strength_of("rubi"), 5.0, 0.3, 70.0, 5400.0)
		var t2 := ClawSharpness.tradeoff(113.0, 15.0, s, float(za.E), ClawSharpness.strength_of("zafiro"), 5.0, 0.3, 70.0, 5400.0)
		_same_dump((var_to_str(t1)), var_to_str(t2), "el afilado del rubí es el del zafiro (s = %s)" % s)


## En el banco: una uña con la gema y una garra reforjada de rubí dan lo mismo que con zafiro (salvo los nombres).
func test_en_el_banco_el_rubi_da_lo_que_el_zafiro() -> void:
	var T := func(id: String) -> Dictionary: return Catalog.find_by_id(Catalog.TARGETS, id)
	var C := func(id: String) -> Dictionary: return Catalog.find_by_id(Catalog.CLAWS, id)
	var cases: Array = [
		{ "geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "claw": null, "target": T.call("vidrio"), "force": 30.0 },
		{ "geom": Catalog.GEOMS[0], "claw": C.call("aguila"), "target": T.call("coche"), "force": 110.0 },
		{ "geom": Catalog.GEOMS[0], "claw": C.call("tigre"), "target": T.call("piel"), "force": 80.0, "method": "puncion" },
		{ "geom": Catalog.GEOMS[0], "claw": C.call("oso"), "target": T.call("madera"), "force": 300.0, "sharpness": 0.5 },
	]
	for base_p: Dictionary in cases:
		var out := {}
		for id: String in ["rubi", "zafiro"]:
			var p := {
				"geom": base_p.geom, "base": Catalog.BASES[0], "inlay": _inl(id), "claw": base_p.claw, "target": base_p.target,
				"type": Catalog.TYPES[1], "force": base_p.force, "length": 25.0, "passes": 1.0, "wet": false, "model": "2.0",
			}
			for k: String in ["method", "sharpness"]:
				if base_p.has(k):
					p[k] = base_p[k]
			out[id] = Physics.compute(p)
		var what := "%s sobre %s" % [String(base_p.claw.id) if base_p.claw != null else "uña", String(base_p.target.id)]
		_same_dump((var_to_str(out.rubi)), var_to_str(out.zafiro), "%s: el rubí da lo que el zafiro" % what)
	# la alúmina: su dureza y su resistencia en el banco (no tiene gemelo)
	var pa := {
		"geom": Catalog.GEOMS[0], "base": Catalog.BASES[0], "inlay": _inl("alumina"), "claw": C.call("aguila"),
		"target": T.call("coche"), "type": Catalog.TYPES[1], "force": 110.0, "length": 25.0, "passes": 1.0, "wet": false,
		"model": "2.0", "sharpness": 0.5,
	}
	var ra := Physics.compute(pa)
	assert_eq(float(ra.hvTool), 1438.0, "la dureza de la alúmina (HV ≈ HK de CoorsTek)")
	assert_true(ra.sharpness is Dictionary and float(ra.sharpness.sigmaMPa) == 379.0, "el afilado, con su resistencia")


## En la cetrería: el rubí se lima como el zafiro; la alúmina, con su propio id, más dura que la lima de acero.
func test_en_la_cetreria_con_su_propio_id() -> void:
	for id: String in NEW:
		assert_true(ClawCare.supports_inlay(id), "%s: la cetrería lo conoce" % id)
		var c := ClawCare.new({ "animal": "rapaz", "inlay": id })
		assert_eq(String(c.setup().inlay), id, "%s: con su propio id" % id)
		assert_true(bool(c.snapshot().reforged), "%s: reforjada" % id)
		assert_eq(String(c.snapshot().claw.color), String(_inl(id).col), "%s: con su color (dibujo)" % id)
		var r := c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
		assert_true(bool(r.noBite) and float(r.removedMm3) == 0.0, "%s: la lima de acero no la muerde" % id)
		var d := ClawCare.new({ "animal": "rapaz", "inlay": id })
		var rd := d.file({ "tool": "lima_diamante_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
		assert_true(float(rd.removedMm3) > 0.0, "%s: la de diamante sí" % id)
		assert_false(bool(ClawCare.new({ "animal": "rapaz", "inlay": id }).clip({ "tool": "guillotina", "remove_mm": 2.0 }).cut), "%s: el cortaúñas no corta" % id)
	assert_false(ClawCare.supports_inlay("adamantium"), "un material que no existe, no")
	# la misma sesión con rubí y con zafiro: la misma garra
	var snaps := {}
	var reps := {}
	for id: String in ["rubi", "zafiro"]:
		var c := ClawCare.new({ "animal": "tigre", "inlay": id, "seed": "corindon" })
		c.file({ "tool": "lima_diamante_gruesa", "zone": "punta", "angle_deg": 90.0, "force_n": 8.0, "travel_mm": 40.0 })
		c.file({ "tool": "lima_diamante_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 40.0 })
		c.file({ "tool": "lija_p180", "zone": "flanco", "at_mm": 10.0, "force_n": 3.0, "travel_mm": 40.0 })
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 3.0, "travel_mm": 40.0 })
		c.clip({ "tool": "tenaza", "remove_mm": 1.0 })
		var sn := c.snapshot()
		sn.erase("serial")
		snaps[id] = sn
		reps[id] = c.report()
	_same_dump((var_to_str(snaps.rubi)), var_to_str(snaps.zafiro), "la misma garra (salvo el id y el color)")
	_same_dump((var_to_str(reps.rubi)), var_to_str(reps.zafiro), "el mismo informe (salvo el nombre)")


## La reforja pasa el rubí y la alúmina a la cetrería con su propio id, no «como zafiro».
func test_la_reforja_los_pasa_con_su_id() -> void:
	for rid: String in ["rubi", "alumina"]:
		var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": rid })
		for st: Dictionary in f.tutorial():
			if String(st.get("action", "")) != "":
				f.do_step(st)
		var rc := f.result_claw()
		assert_true(bool(rc.ok), "%s: la receta sale bien siguiendo su tutorial" % rid)
		var cs := f.care_setup()
		assert_eq([String(cs.inlay), bool(cs.careSupported)], [rid, true], "%s: a la cetrería con su propio id" % rid)
		var care := ClawCare.new(cs)
		assert_eq(String(care.setup().inlay), rid, "%s: ClawCare la toma así" % rid)


## En la página de la cetrería se pueden elegir (lo pidió la 5e): ClawCareState valida el material contra el catálogo 2.0
## (Catalog.INLAYS), no contra el de la 1.x.
func test_se_eligen_en_la_cetreria() -> void:
	var ids: Array = (State.inlay_options() as Array).map(func(o: Dictionary) -> String: return String(o.id))
	for id: String in NEW:
		assert_true(ids.has(id), "%s: entre los materiales que se eligen" % id)
		var st := State.new({ "animal": "rapaz", "seed": "elegir" })
		st.set_inlay(id)
		assert_eq(String(st.setup.inlay), id, "%s: elegido" % id)
		assert_eq(String(st.care.setup().inlay), id, "%s: y la garra es de ese material" % id)
		assert_true(st.is_reforged(), "%s: reforjada" % id)
		assert_true(State.material_for(st.setup).contains(String(_inl(id).name)), "%s: con su nombre y su dureza" % id)
