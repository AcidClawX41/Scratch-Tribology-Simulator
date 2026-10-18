## Integración del laboratorio: la física en GDScript (physics.gd) alimenta directamente los dibujos (art.gd + svg.gd)
## y el sonido (sfx.gd), sin pasar por los resultados guardados del oráculo. Tiene que salir lo mismo que en la 1.x:
##   - el sonido de los 40 escenarios del golden y de los ~19.000 ensayos de la muestra;
##   - el SVG, byte a byte, de los surcos, huellas y cortes que el oráculo dibuja con resultados reales
##     (export-fixtures.mjs: cuatro ensayos por material, rayado y punción, uña y garra).
## Así se comprueba la cadena entera: un último bit distinto en la física que cambiara un umbral de sonido o un número
## escrito en el SVG saldría aquí.
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Art = preload("res://core/lab/art.gd")
const Svg = preload("res://core/lab/svg.gd")
const Sfx = preload("res://core/lab/sfx.gd")

const RESULT_ART := ["grooveArt", "punctureArt", "carSectionArt", "skinSectionArt"]
const MAX_REPORTED := 8

var _by_id := {}


func before_each() -> void:
	if not _by_id.is_empty():
		return
	var catalogs := { "GEOMS": Data.GEOMS, "BASES": Data.BASES, "INLAYS": Data.INLAYS, "CLAWS": Data.CLAWS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES }
	for key: String in catalogs:
		var index := {}
		for x: Dictionary in catalogs[key]:
			index[x.id] = x
		_by_id[key] = index


func _find(key: String, id: Variant) -> Variant:
	return null if id == null else _by_id[key][id]


## norm() de export-fixtures.mjs: los parámetros por defecto de un ensayo.
static func _norm(p: Dictionary) -> Dictionary:
	return {
		"geom": p.get("geom", "almendra"), "base": p.get("base", "natural"), "inlay": p.get("inlay", "none"),
		"target": p.target, "force": float(p.force), "length": float(p.get("length", 25.0)),
		"type": p.get("type", "aranazo"), "claw": p.get("claw"), "tear": p.get("tear", false),
		"method": p.get("method", "rayado"), "strike": p.get("strike", false), "passes": float(p.get("passes", 1.0)),
		"wet": p.get("wet", false),
	}


## Con el modelo "1.x": la cadena se compara con el oráculo, que es el motor 1.x.
func _compute(p: Dictionary) -> Dictionary:
	return Physics.compute({
		"geom": _find("GEOMS", p.geom), "base": _find("BASES", p.base), "inlay": _find("INLAYS", p.inlay),
		"claw": _find("CLAWS", p.get("claw")), "target": _find("TARGETS", p.target), "type": _find("TYPES", p.type),
		"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike,
		"passes": p.passes, "wet": p.wet, "model": Physics.MODEL_V1,
	})


func test_golden_fisica_y_sonido_de_godot() -> void:
	var golden: Array = load_json("res://tests/fixtures/lab-golden.json")
	for g: Dictionary in golden:
		var res := _compute(g.params)
		var got := Sfx.sfx_for_result(res, _find("TARGETS", g.params.target))
		assert_eq(got, g.sfx, "«%s»" % g.name)
	assert_eq(golden.size(), 40, "escenarios del golden")


func test_muestra_fisica_y_sonido_de_godot() -> void:
	# Sin decode() del archivo entero (28 MB): solo hacen falta los parámetros (ids y números cortos) y el sonido.
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/generated/lab-sample.json"))
	var trials: Array = sample.trials
	var bad := 0
	for t: Dictionary in trials:
		var p: Dictionary = t.params
		var got := Sfx.sfx_for_result(_compute(p), _find("TARGETS", p.target))
		if got != t.sfx:
			bad += 1
			if bad <= MAX_REPORTED:
				fail("%s: suena «%s» y el oráculo «%s»" % [JSON.stringify(p), got, t.sfx])
	if bad > MAX_REPORTED:
		fail("… %d discrepancias en total" % bad)
	assert_true(trials.size() > 19000, "ensayos de la muestra: %d" % trials.size())
	print("    (info) %d ensayos: física → sonido en GDScript, %d discrepancias" % [trials.size(), bad])


func test_surcos_huellas_y_cortes_con_la_fisica_de_godot() -> void:
	var fx: Array = []
	for e: Dictionary in load_json("res://tests/fixtures/generated/art-svg.json"):
		if RESULT_ART.has(e.fn):
			fx.append(e)
	# Misma secuencia que export-fixtures.mjs: por material, cuatro ensayos y, de cada uno, su surco o su huella y,
	# si es un coche o la piel, su corte.
	var built: Array = []
	for t: Dictionary in Data.TARGETS:
		var runs := [
			_norm({ "target": t.id, "force": 4.0 }),
			_norm({ "target": t.id, "force": 300.0, "claw": "oso" }),
			_norm({ "target": t.id, "force": 30.0, "method": "puncion" }),
			_norm({ "target": t.id, "force": 500.0, "claw": "casuario", "method": "puncion", "strike": true }),
		]
		for p: Dictionary in runs:
			var res := _compute(p)
			if p.method == "rayado":
				built.append(["grooveArt", Art.groove_art(t.id, res, { "x1": 14.0, "x2": 286.0, "y": 30.0, "uid": "gv" })])
			else:
				built.append(["punctureArt", Art.puncture_art(t.id, res, { "cx": 150.0, "cy": 30.0, "uid": "pc", "fangs": p.get("claw") == "vibora" })])
			if t.get("body") != null:
				built.append(["carSectionArt", Art.car_section_art(res, t, { "uid": "car" })])
			if Js.truthy(t.get("skin")):
				built.append(["skinSectionArt", Art.skin_section_art(res, { "uid": "sk" })])
	assert_eq(built.size(), fx.size(), "dibujos con resultados reales")
	var same_svg := 0
	for i in mini(built.size(), fx.size()):
		var e: Dictionary = fx[i]
		if built[i][0] != e.fn:
			fail("%s: se esperaba %s y se ha dibujado %s" % [e.id, e.fn, built[i][0]])
			continue
		var svg := Svg.scene_to_svg(built[i][1], { "viewBox": e.viewBox, "width": e.width, "height": e.height })
		if svg == e.svg:
			same_svg += 1
		elif i - same_svg < MAX_REPORTED:
			fail("%s: el SVG con la física de Godot no es idéntico al del oráculo" % e.id)
	assert_eq(same_svg, fx.size(), "SVG idénticos")
	print("    (info) física → dibujo en GDScript: %d/%d SVG idénticos al del oráculo" % [same_svg, fx.size()])

