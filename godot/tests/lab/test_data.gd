## Catálogos del laboratorio (core/lab/data.gd, lab.gd, lab_state.gd, physics.gd y core/shared/format.gd) contra
## los del motor 1.x (tests/fixtures/lab-data.json): mismas claves, mismos valores y mismos derivados.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Format = preload("res://core/shared/format.gd")

var fx: Dictionary


func before_each() -> void:
	if fx.is_empty():
		fx = load_json("res://tests/fixtures/lab-data.json")


func _same_as_oracle(got: Variant, key: String) -> void:
	var diffs := oracle_diff(got, fx[key], key)
	assert_eq(diffs.size(), 0, "%s distinto del motor 1.x: %s" % [key, "; ".join(diffs)])


func test_catalogos_iguales_que_data_js() -> void:
	_same_as_oracle(Data.GEOMS, "GEOMS")
	_same_as_oracle(Data.BASES, "BASES")
	_same_as_oracle(Data.BASE_GROUPS, "BASE_GROUPS")
	_same_as_oracle(Data.INLAYS, "INLAYS")
	_same_as_oracle(Data.HUMAN, "HUMAN")
	_same_as_oracle(Data.CLAWS, "CLAWS")
	_same_as_oracle(Data.CLAW_GROUPS, "CLAW_GROUPS")
	_same_as_oracle(Data.PAINT_LAYERS, "PAINT_LAYERS")
	_same_as_oracle(Data.CAR_BODIES, "CAR_BODIES")
	_same_as_oracle(Data.SKIN_LAYERS, "SKIN_LAYERS")
	_same_as_oracle(Data.TARGETS, "TARGETS")
	_same_as_oracle(Data.TYPES, "TYPES")
	_same_as_oracle(Data.C, "C")


func test_mismo_orden_en_cada_catalogo() -> void:
	# la interfaz los enseña en este orden, y la muestra del oráculo recorre los catálogos por índice
	var catalogs := {
		"GEOMS": Data.GEOMS, "BASES": Data.BASES, "INLAYS": Data.INLAYS, "CLAWS": Data.CLAWS, "PAINT_LAYERS": Data.PAINT_LAYERS,
		"SKIN_LAYERS": Data.SKIN_LAYERS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES,
	}
	for key: String in catalogs:
		var ours: Array = catalogs[key]
		var ids: Array = []
		for x: Dictionary in ours:
			ids.append(x.id)
		var want: Array = []
		for x: Dictionary in fx[key]:
			want.append(x.id)
		assert_eq(ids, want, "orden de %s" % key)


func test_los_coches_comparten_su_carroceria() -> void:
	# en data.js, target.body y target.layers.sub son el mismo objeto de CAR_BODIES
	for t: Dictionary in Data.TARGETS:
		if t.get("body") != null:
			assert_true(is_same(t.body, t.layers.sub), "%s: body y layers.sub deberían ser la misma carrocería" % t.id)
	assert_true(is_same(Data.TARGETS[0].tissue, Data.SKIN_LAYERS), "la piel usa SKIN_LAYERS")


func test_modelo_y_constantes() -> void:
	_same_as_oracle(Physics.MODEL, "MODEL")
	assert_eq(Physics.HV_MPA, fx["HV_MPA"])
	assert_eq(Format.FMIN, fx["FMIN"])
	assert_eq(Format.FMAX, fx["FMAX"])


func test_laboratorio_logros_fundamentos_y_licencia() -> void:
	_same_as_oracle(Lab.BADGES, "BADGES")
	assert_eq(Lab.BADGE_RUNS, fx["BADGE_RUNS"])
	_same_as_oracle(Lab.FUNDAMENTOS, "FUNDAMENTOS")
	assert_eq(Lab.FUNDAMENTOS_NOTE, fx["FUNDAMENTOS_NOTE"])
	assert_eq(Lab.license_note(fx["APP_VERSION"]), fx["LICENSE_NOTE"], "aviso de licencia con la versión del oráculo")
	var ids: Array = []
	for b: Dictionary in Lab.BADGES:
		ids.append(b.id)
	for id: String in Lab.BADGE_ORDER:
		assert_true(ids.has(id), "condición de un logro que no existe: %s" % id)
	assert_eq(Lab.BADGE_ORDER.size(), Lab.BADGES.size(), "cada logro tiene su condición")


func test_modo_dual_y_estado_del_banco() -> void:
	_same_as_oracle(Lab.DUEL_DEFAULT, "DUEL_DEFAULT")
	_same_as_oracle(Lab.DUEL_MODES, "DUEL_MODES")
	var cars: Array = []
	for t: Dictionary in Lab.DUEL_CARS:
		cars.append(t.id)
	_same_as_oracle(cars, "DUEL_CARS")
	assert_eq(LabState.RUN_MS, fx["RUN_MS"])
	assert_eq(LabState.LOG_SIZE, fx["LOG_SIZE"])
	var defaults := {}
	for k in LabState.LAB_DEFAULTS:
		var v: Variant = LabState.LAB_DEFAULTS[k]
		defaults[k] = v.id if v is Dictionary else v
	_same_as_oracle(defaults, "LAB_DEFAULTS")


func test_derivados_de_los_catalogos() -> void:
	var layers := {}
	var subs := {}
	for t: Dictionary in Data.TARGETS:
		if t.get("body") != null:
			layers[t.id] = Data.car_layers(t)
		subs[t.id] = Lab.target_sub(t)
	_same_as_oracle(layers, "carLayers")
	_same_as_oracle(subs, "targetSub")
	assert_eq(Data.car_layers(Data.TARGETS[1]), null, "la madera no es un coche")
	assert_eq(Data.car_layers(null), null)
	var titles := {}
	for c: Dictionary in Data.CLAWS:
		titles[c.id] = Data.claw_title(c)
	_same_as_oracle(titles, "clawTitle")
	var hints: Array = []
	for c: Variant in [null] + Data.CLAWS:
		var h := { "claw": c.id if c != null else null }
		h.merge(Lab.max_force_hint(c))
		hints.append(h)
	_same_as_oracle(hints, "maxForceHint")


func test_car_layers_no_toca_los_catalogos() -> void:
	# el promotor de adherencia de la aleta de plástico es una copia: PAINT_LAYERS sigue diciendo «Anticorrosivo»
	var alu: Array = Data.car_layers(Data.find_by_id(Data.TARGETS, "cocheplastico"))
	assert_eq(alu[3].name, "Promotor de adherencia")
	assert_eq(Data.PAINT_LAYERS[3].name, "Anticorrosivo")
	assert_true(Data.PAINT_LAYERS[0].is_read_only(), "los catálogos son constantes de solo lectura")


func test_formatos() -> void:
	assert_eq(Format.fmt_f(4.0), "4.0")
	assert_eq(Format.fmt_f(12.5), "13")
	assert_eq(Format.fmt_j(0.354), "0.35")
	assert_eq(Format.fmt_j(1.44), "1.4")
	assert_eq(Format.fmt_j(160.0), "160")
	assert_eq(Format.fmt_p(0.125), "0.13", "empate de toFixed hacia arriba, como JavaScript")
	assert_eq(Format.fmt_p(30.0), "30.0")
	assert_eq(Format.fmt_p(196.14), "196")
	assert_eq(Format.fmt_depth(3.4857664928608507), "3.5 µm")
	assert_eq(Format.fmt_depth(110.00000000000101), "110 µm")
	assert_eq(Format.fmt_depth(35000.0), "35.0 mm")
	assert_eq(Format.fmt_len(35000.0), "35 mm (3.5 cm)")
	assert_eq(Format.fmt_len(10500.0), "10.5 mm (1.1 cm)")
	assert_eq(Format.fmt_len(110000.0), "110 mm (11.0 cm)")
	assert_eq(Format.fmt_len(6100.0), Format.fmt_depth(6100.0))
	# mismo número de milímetros que fmt_depth, que es lo que dicen los veredictos
	for um in range(10000, 100000, 37):
		assert_eq(Format.fmt_len(um).split(" mm")[0], Format.fmt_depth(um).split(" mm")[0].trim_suffix(".0"), "%d µm" % um)
	assert_eq(Format.hv_bar(10000.0), 100.0)
	assert_eq(Format.hv_bar(1.0), 4.0)
	for f in [Format.FMIN, 1.0, 4.0, 30.0, 500.0, Format.FMAX]:
		assert_near(Format.t_to_f(Format.f_to_t(f)), f, 1e-9, 0.0, "fuerza ↔ deslizador")
	assert_eq(Format.f_to_t(Format.FMIN), 0.0)
	assert_near(Format.f_to_t(Format.FMAX), 1.0, 1e-15, 0.0)
