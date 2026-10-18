## Golden del modelo 2.0 (tests/fixtures/lab-golden-v2.json, tools/golden_v2.gd): la física 2.0 de ahora da lo que
## está guardado, con la política del oráculo (case.gd → oracle_diff: textos idénticos y números con error relativo
## ≤ 1e-9), y el archivo cubre los 40 escenarios del golden 1.x y los nuevos de la 2.0, en orden.
## Si falla por un cambio de física HECHO A PROPÓSITO: `npm run godot:golden` y explica cada escenario que cambia en
## docs/FISICA.md («Cambios de la 2.0»). Nunca se regenera para tapar un cambio que no se entiende.
extends "res://tests/case.gd"

const GoldenV2 = preload("res://tools/golden_v2.gd")
const Physics = preload("res://core/lab/physics.gd")

const HOW := "si el cambio es a propósito: npm run godot:golden y explícalo en docs/FISICA.md («Cambios de la 2.0»)"

var golden: Array


func before_each() -> void:
	if golden.is_empty():
		golden = load_json(GoldenV2.OUT)


func test_cubre_los_escenarios_de_la_1x_y_los_nuevos() -> void:
	var want := GoldenV2.scenarios()
	var v1: Array = load_json(GoldenV2.SOURCE)
	assert_eq(v1.size(), 40, "escenarios del golden 1.x")
	assert_eq(want.size(), v1.size() + GoldenV2.EXTRA_SCENARIOS.size(), "los 40 de la 1.x y los nuevos de la 2.0")
	assert_eq(golden.size(), want.size(), "entradas del golden 2.0 (%s)" % HOW)
	for i in mini(golden.size(), want.size()):
		var g: Dictionary = golden[i]
		assert_eq(g.name, want[i].name, "escenario %d" % i)
		var d := oracle_diff(g.params, want[i].params, "«%s» params" % want[i].name)
		assert_eq(d.size(), 0, "parámetros del escenario %d %s" % [i, d])
		if i < v1.size():
			assert_eq(oracle_diff(g.params, v1[i].params).size(), 0, "«%s»: los mismos parámetros que en el golden 1.x" % g.name)


func test_la_fisica_2_0_da_lo_guardado() -> void:
	var fresh := GoldenV2.build()
	var bad := 0
	for i in mini(golden.size(), fresh.size()):
		var d := oracle_diff(fresh[i], golden[i], "«%s»" % golden[i].name)
		if not d.is_empty():
			bad += 1
			if bad <= 6:
				fail("%s (%s)" % [d[0], HOW])
	assert_eq(fresh.size(), golden.size(), "escenarios")
	assert_eq(bad, 0, "escenarios del golden 2.0 con alguna diferencia")
	var changed := GoldenV2.changed_vs_v1(fresh)
	print("    (info) golden 2.0: %d escenarios; %d de la 1.x cambian con la 2.0" % [fresh.size(), changed.size()])


func test_mismo_formato_que_el_golden_1x() -> void:
	var v1: Array = load_json(GoldenV2.SOURCE)
	for i in mini(v1.size(), golden.size()):
		var a: Dictionary = golden[i]
		var b: Dictionary = v1[i]
		assert_eq(a.keys(), b.keys(), "«%s»: las mismas claves y en el mismo orden que el golden 1.x" % b.name)
	# y el archivo lo ha escrito el generador: JSON sin espacios, de una línea (números como JavaScript)
	var text := FileAccess.get_file_as_string(GoldenV2.OUT)
	assert_true(text.begins_with("[{\"name\":") and text.ends_with("}]\n") and text.count("\n") == 1, "formato de lab-golden-v2.json (%s)" % HOW)


func test_escenarios_nuevos_detras_de_los_40() -> void:
	# el mecanismo de los escenarios nuevos (los aguijones de la oleada 2), con uno de prueba
	var extra := [{ "name": "prueba: gato punzando piel", "params": { "claw": "gato", "target": "piel", "force": 2.0, "method": "puncion" } }]
	var built := GoldenV2.build(extra)
	assert_eq(built.size(), 41, "los 40 de la 1.x y el nuevo")
	var e: Dictionary = built[40]
	assert_eq(e.name, extra[0].name)
	assert_eq(e.keys(), ["name", "params", "result", "sfx", "toolLabel", "badgesAfter"], "la piel no tiene informe de daños")
	assert_eq(e.params.geom, "almendra", "los parámetros que faltan, con los valores del golden 1.x")
	var p: Dictionary = GoldenV2.compute_params(e.params)
	assert_eq(p.model, "2.0", "con la física 2.0")
	assert_eq(oracle_diff(e.result, Physics.compute(p)).size(), 0, "el resultado es el de compute()")
	assert_true((e.badgesAfter as Array).has("depredador"), "los logros se acumulan a lo largo de toda la serie")
	assert_eq(oracle_diff(built.slice(0, 40), GoldenV2.build([])).size(), 0, "los 40 primeros no dependen de los nuevos")


func test_json_como_javascript() -> void:
	assert_eq(GoldenV2.to_json({ "a": 4.0, "b": 0.1 + 0.2, "c": -0.0, "d": 1e21, "e": 2, "f": null, "g": [true, false] }),
		"{\"a\":4,\"b\":0.30000000000000004,\"c\":0,\"d\":1e+21,\"e\":2,\"f\":null,\"g\":[true,false]}")
	assert_eq(GoldenV2.to_json([INF, -INF, NAN]), "[{\"$num\":\"Infinity\"},{\"$num\":\"-Infinity\"},{\"$num\":\"NaN\"}]")
	assert_eq(GoldenV2.to_json("«uña» \"x\"\n\\\t\u0001 🦷"), "\"«uña» \\\"x\\\"\\n\\\\\\t\\u0001 🦷\"")
	assert_eq(GoldenV2.normalize({ "target": "piel", "force": 4 }), {
		"geom": "almendra", "base": "natural", "inlay": "none", "target": "piel", "force": 4.0, "length": 25.0, "type": "aranazo",
		"claw": null, "tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false })


func test_zona_y_ataque_solo_si_el_escenario_los_trae() -> void:
	# los parámetros de la 2.0 de la biología (unidad 4b): la zona del cuerpo y el ángulo de ataque
	var n := GoldenV2.normalize({ "target": "piel", "force": 4, "zone": "palma", "attack_deg": 20 })
	assert_eq([n.zone, n.attack_deg], ["palma", 20.0])
	var q := GoldenV2.compute_params(n)
	assert_eq([q.zone, q.attack_deg], ["palma", 20.0], "llegan a compute()")
	var plain := GoldenV2.compute_params(GoldenV2.normalize({ "target": "piel", "force": 4 }))
	assert_false(plain.has("zone") or plain.has("attack_deg"), "sin ellos, los de la 1.x (el brazo y el ataque por defecto)")
	var zoned := 0
	for s: Dictionary in GoldenV2.EXTRA_SCENARIOS:
		if (s.params as Dictionary).has("zone") or (s.params as Dictionary).has("attack_deg"):
			zoned += 1
	assert_true(zoned >= 6, "escenarios nuevos con zona o ataque: %d" % zoned)
	var by_name := {}
	for g: Dictionary in golden:
		by_name[g.name] = g
	var palm: Dictionary = by_name.get("Pájaro rayando la palma: callo pulido", {})
	assert_eq([palm.params.zone, palm.result.zone, palm.result.verdict], ["palma", "palma", "CALLO PULIDO"],
		"el escenario de la palma se guarda con su zona")
