## La semántica numérica de JavaScript (core/shared/js.gd) contra los valores que da el propio motor 1.x
## (tests/fixtures/js-semantics.json, exportado por packages/core/scripts/export-fixtures.mjs).
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

var fx: Dictionary


func before_each() -> void:
	if fx.is_empty():
		fx = load_json("res://tests/fixtures/js-semantics.json")


func test_to_fixed_igual_que_javascript() -> void:
	var bad := 0
	for row in fx["toFixed"]:
		var got := Js.to_fixed(float(row[0]), int(row[1]))
		if got != row[2]:
			bad += 1
			if bad <= 8:
				fail("toFixed(%s, %d) = «%s», JavaScript «%s»" % [var_to_str(float(row[0])), row[1], got, row[2]])
	assert_eq(bad, 0, "casos de toFixed distintos de JavaScript")


func test_empates_de_to_fixed() -> void:
	# printf redondea al par; JavaScript elige el mayor
	assert_eq(Js.to_fixed(0.125, 2), "0.13")
	assert_eq(Js.to_fixed(2.5, 0), "3")
	assert_eq(Js.to_fixed(-2.5, 0), "-3")
	assert_eq(Js.to_fixed(1.005, 2), "1.00")  # en binario es 1,00499…
	assert_eq(Js.to_fixed(-0.0001, 2), "-0.00")
	assert_eq(Js.to_fixed(-0.0, 1), "0.0")


func test_math_round() -> void:
	var bad := 0
	for row in fx["round"]:
		var got := Js.js_round(float(row[0]))
		if not same(got, row[1]):
			bad += 1
			if bad <= 8:
				fail("Math.round(%s) = %s, JavaScript %s" % [var_to_str(float(row[0])), got, row[1]])
	assert_eq(bad, 0, "casos de Math.round distintos")
	assert_eq(Js.js_round(-2.5), -2.0)
	assert_eq(Js.js_round(0.49999999999999994), 0.0)


func test_string_de_un_numero() -> void:
	var bad := 0
	for row in fx["str"]:
		var got := Js.js_num_str(float(row[0]))
		if got != row[1]:
			bad += 1
			if bad <= 8:
				fail("String(%s) = «%s», JavaScript «%s»" % [var_to_str(float(row[0])), got, row[1]])
	assert_eq(bad, 0, "casos de String(n) distintos")
	assert_eq(Js.js_num_str(0.1 + 0.2), "0.30000000000000004")
	assert_eq(Js.js_num_str(1e-7), "1e-7")
	assert_eq(Js.js_num_str(1e21), "1e+21")


func test_funciones_matematicas_hasta_el_ultimo_bit() -> void:
	# log10, log1p y cbrt (js.gd) y atan2 y pow (v8_math.gd) son los de V8, al bit: se exige igualdad exacta
	var bad := 0
	for name in ["log10", "log1p", "cbrt"]:
		for row in fx[name]:
			var x := float(row[0])
			var got: float = Js.log10(x) if name == "log10" else (Js.log1p(x) if name == "log1p" else Js.cbrt(x))
			if not same(got, float(row[1])):
				bad += 1
				if bad <= 8:
					fail("%s(%s) = %s, V8 %s" % [name, Js.js_num_str(x), Js.js_num_str(got), Js.js_num_str(float(row[1]))])
	for row in fx["atan2"]:
		if not same(V8.js_atan2(float(row[0]), float(row[1])), float(row[2])):
			bad += 1
			fail("atan2(%s, %s)" % [Js.js_num_str(float(row[0])), Js.js_num_str(float(row[1]))])
	for row in fx["pow"]:
		if not same(V8.js_pow(float(row[0]), float(row[1])), float(row[2])):
			bad += 1
			fail("pow(%s, %s)" % [Js.js_num_str(float(row[0])), Js.js_num_str(float(row[1]))])
	assert_eq(bad, 0, "valores distintos de los de V8")


func test_enteros_de_32_bits() -> void:
	for row in fx["imul"]:
		assert_eq(Js.imul32(int(row[0]), int(row[1])), int(row[2]), "Math.imul(%s, %s)" % [row[0], row[1]])
	assert_eq(Js.ushr(-1, 0), 4294967295)
	assert_eq(Js.u32(-2), 4294967294)
	for row in fx["hex2"]:
		assert_eq(Js.hex2(int(row[0])), row[1])
