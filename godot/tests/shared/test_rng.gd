## mulberry32 y seedOf (core/shared/rng.gd) contra las secuencias de art.js (tests/fixtures/rng.json).
extends "res://tests/case.gd"

const Rng = preload("res://core/shared/rng.gd")

var fx: Dictionary


func before_each() -> void:
	if fx.is_empty():
		fx = load_json("res://tests/fixtures/rng.json")


func test_seed_of_igual_que_art_js() -> void:
	for row in fx["seedOf"]:
		assert_eq(Rng.seed_of(row[0]), int(row[1]), "seedOf(«%s»)" % row[0])


func test_secuencias_identicas() -> void:
	for row in fx["sequences"]:
		var r := Rng.new(int(row[0]))
		var i := 0
		for want in row[1]:
			var got := r.next()
			assert_true(got == float(want), "semilla %s, valor %d: %s ≠ %s" % [row[0], i, str(got), str(float(want))])
			i += 1


func test_desde_texto() -> void:
	var a := Rng.from_text("madera:300x60")
	var b := Rng.new(Rng.seed_of("madera:300x60"))
	for i in 5:
		assert_eq(a.next(), b.next())
