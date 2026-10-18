## Cetrería · las medidas de cada animal entero (core/lab/care_anatomy.gd, unidad 5i): cada dibujo de la cetrería tiene
## sus medidas con fuente y calidad, dentro de su rango; la masa es la de la garra del banco; los velocirraptores leen su
## ficha sin copias; y lo que es solo dibujo no se enseña como dato.
extends "res://tests/case.gd"

const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Data = preload("res://core/lab/data.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const VelociraptorFilm = preload("res://core/lab/velociraptor_film.gd")


static func _bench(id: String) -> Dictionary:
	for c: Dictionary in Data.CLAWS:
		if String(c.id) == id:
			return c
	return {}


func test_cada_dibujo_tiene_sus_medidas_con_fuente() -> void:
	for raptor: String in CareData.RAPTOR_IDS:
		assert_true(CareAnatomy.ARTS.has(raptor), "%s: la rapaz del banco tiene cuerpo" % raptor)
	for art: String in CareAnatomy.ARTS:
		var rows: Array = CareAnatomy.rows(art)
		assert_true(rows.size() >= 3, "%s: largo, tamaño y masa (%d medidas)" % [art, rows.size()])
		for r: Dictionary in rows:
			var what := "%s.%s" % [art, r.key]
			assert_true(String(r.quality) in CareAnatomy.QUALITIES, "%s: calidad «%s»" % [what, r.quality])
			assert_true(String(r.source).length() > 30, "%s: con su fuente" % what)
			var v := float(r.value)
			assert_true(v > 0.0, "%s: positiva" % what)
			if r.min != null:
				assert_true(float(r.min) <= v + 1e-9, "%s: el valor (%s) no baja del mínimo (%s)" % [what, v, r.min])
			if r.max != null:
				assert_true(v <= float(r.max) + 1e-9, "%s: ni pasa del máximo (%s)" % [what, r.max])
		assert_true(CareAnatomy.draw_length_m(art) > 0.2, "%s: un largo con el que dibujarlo" % art)


func test_la_masa_es_la_del_banco() -> void:
	for art: String in CareAnatomy.RAPTOR_ARTS + ["tigre", "oso"]:
		var bench := _bench(art)
		assert_false(bench.is_empty(), "%s: está en el banco" % art)
		assert_near(CareAnatomy.value(art, "mass_kg"), float(bench.mass), 0.0, 1e-9, "%s: la masa del banco" % art)
	assert_near(CareAnatomy.value("velociraptor", "mass_kg"), float(Velociraptor.MASS.value), 0.0, 1e-9, "el velocirraptor, la de su ficha")
	assert_near(CareAnatomy.value("velociraptor_pelicula", "mass_kg"), float(VelociraptorFilm.MASS.value), 0.0, 1e-9, "y el de cine, la suya")


func test_los_velocirraptores_leen_su_ficha() -> void:
	var v := CareAnatomy.of("velociraptor")
	assert_eq(v.length_m, Velociraptor.BODY.lengthM, "el largo, el de su ficha")
	assert_eq(v.hip_m, Velociraptor.BODY.hipM, "la cadera, la de su ficha")
	var f := CareAnatomy.of("velociraptor_pelicula")
	assert_eq(f.length_m, VelociraptorFilm.BODY.lengthM, "el de cine: el largo de Deinonychus")
	assert_true(bool(f.film), "y marcado como de película")
	# una copia: cambiarla no toca la ficha
	(v.length_m as Dictionary)["value"] = -1.0
	assert_near(float(Velociraptor.BODY.lengthM.value), 2.07, 0.0, 1e-9, "la ficha no cambia")


func test_proporciones_que_cuadran() -> void:
	for art: String in CareAnatomy.RAPTOR_ARTS:
		assert_true(CareAnatomy.value(art, "span_m") >= 1.8 * CareAnatomy.value(art, "length_m"), "%s: la envergadura, de casi el doble del largo en adelante" % art)
		var w := CareAnatomy.folded_wing_m(art)
		assert_true(w > 0.25 * CareAnatomy.value(art, "span_m") and w < 0.36 * CareAnatomy.value(art, "span_m"), "%s: el ala plegada, ~0,3 de la envergadura" % art)
		var d: Dictionary = CareAnatomy.of(art).draw
		assert_eq(String(d.quality), "dibujo", "%s: las proporciones del dibujo, marcadas como dibujo" % art)
	# la lechuza: el ala medida
	assert_near(CareAnatomy.folded_wing_m("lechuza"), 0.292, 0.0, 1e-9, "la lechuza: el ala medida (BTO)")
	# el tigre: cabeza y cuerpo más cola, el largo total; la cola no pasa de la mitad
	var hb := CareAnatomy.value("tigre", "head_body_m")
	var tail := CareAnatomy.value("tigre", "tail_m")
	assert_near(hb + tail, CareAnatomy.value("tigre", "total_m"), 0.0, 0.005, "el tigre: cabeza y cuerpo más cola = el largo total")
	assert_true(tail <= 0.5 * hb + 1e-9, "la cola no pasa de la mitad de la cabeza y el cuerpo (Mazák 1981)")
	# el oso, escalado de los machos de Yellowstone (164,3 cm con 193 kg) a 300 kg
	assert_near(CareAnatomy.value("oso", "head_body_m"), 1.643 * pow(300.0 / 193.0, 1.0 / 3.0), 0.0, 0.01, "el oso: el largo escalado con la masa")
	assert_near(CareAnatomy.draw_length_m("tigre"), hb, 0.0, 1e-9, "el tigre se dibuja con la cabeza y el cuerpo")
	assert_near(CareAnatomy.draw_length_m("velociraptor"), 2.07, 0.0, 1e-9, "el velocirraptor, con su largo total")
	assert_true(CareAnatomy.of("nada").is_empty(), "un dibujo que no existe: vacío")


## Las medidas de las cabezas (5n): cada una con su fuente y su calidad, también lo que se describe sin número (el disco
## facial, el iris, los labios); y las proporciones de dibujo, marcadas como dibujo.
func test_las_cabezas_tienen_sus_medidas_con_fuente() -> void:
	var want := {
		"oso": ["skull_m", "skull_width_m", "rostrum_width_m", "interorbital_m", "nasal_m", "ear_m", "head_m", "face"],
		"tigre": ["skull_m", "skull_width_m", "interorbital_m", "rostrum_width_m", "eye_mm", "face", "ears"],
		"velociraptor": ["skull_m", "skull_depth_m", "skull_width_m", "lacrimal_width_m", "snout_m", "snout_depth_m", "snout_width_m",
			"mandible_m", "mandible_depth_m", "snout_profile", "lips"],
		"buho": ["ear_tuft_m", "facial_disc", "iris"],
		"lechuza": ["facial_disc", "iris"],
	}
	for art: String in want:
		var e := CareAnatomy.of(art)
		for key: String in want[art]:
			var m: Variant = e.get(key)
			assert_true(m is Dictionary, "%s.%s: está" % [art, key])
			if not m is Dictionary:
				continue
			var d: Dictionary = m
			assert_true(String(d.get("quality", "")) in CareAnatomy.QUALITIES, "%s.%s: calidad «%s»" % [art, key, d.get("quality", "")])
			assert_true(String(d.get("source", "")).length() > 40, "%s.%s: con su fuente" % [art, key])
			assert_true(d.get("value") != null and str(d.value) != "", "%s.%s: con su valor" % [art, key])
	# las medidas, también en las filas de «Valores y fuentes»
	var keys := []
	for r: Dictionary in CareAnatomy.rows("velociraptor"):
		keys.append(String(r.key))
	assert_true(keys.has("skull_m") and keys.has("snout_m"), "el cráneo del velocirraptor sale en sus filas")
	assert_false(keys.has("lips"), "lo descrito sin número no sale como medida")
	# lo que es solo dibujo, marcado como dibujo
	for art: String in ["oso", "tigre", "velociraptor"]:
		var hd: Dictionary = CareAnatomy.of(art).get("head_draw", {})
		assert_eq(String(hd.get("quality", "")), "dibujo", "%s: las proporciones de la cabeza, marcadas como dibujo" % art)
	assert_eq(CareAnatomy.head_draw("oso", "nada", 7.0), 7.0, "una proporción que no está: la de por defecto")


## Las medidas de las cabezas cuadran entre sí (5n): el cráneo cabe en la cabeza, el hocico es más estrecho que la frente,
## el del velocirraptor es el 60 % del cráneo y su mandíbula, algo más corta.
func test_las_cabezas_cuadran() -> void:
	var v := func(art: String, key: String) -> float: return CareAnatomy.value(art, key, -1.0)
	assert_true(v.call("oso", "skull_m") < v.call("oso", "head_m"), "el oso: el cráneo, más corto que la cabeza con su piel y su trufa")
	assert_true(v.call("oso", "rostrum_width_m") < v.call("oso", "interorbital_m") and v.call("oso", "interorbital_m") < v.call("oso", "skull_width_m"),
		"el oso: el hocico, más estrecho que la frente, y la frente, que los pómulos")
	assert_true(v.call("oso", "nasal_m") < 0.4 * v.call("oso", "skull_m"), "el oso: el caballete del hocico, menos de la mitad del cráneo")
	assert_true(v.call("tigre", "rostrum_width_m") < 0.5 * v.call("tigre", "skull_width_m"), "el tigre: el hocico, menos de la mitad de ancho que los pómulos")
	assert_near(v.call("velociraptor", "snout_m") / v.call("velociraptor", "skull_m"), 0.6, 0.0, 0.02, "el velocirraptor: el hocico, el 60 % del cráneo")
	assert_true(v.call("velociraptor", "snout_width_m") < v.call("velociraptor", "lacrimal_width_m") and v.call("velociraptor", "lacrimal_width_m") < v.call("velociraptor", "skull_width_m"),
		"el velocirraptor: el hocico estrecho y el cráneo ancho detrás de las órbitas")
	assert_true(v.call("velociraptor", "mandible_m") < v.call("velociraptor", "skull_m"), "la mandíbula, algo más corta que el cráneo")
	assert_true(v.call("velociraptor", "snout_depth_m") < v.call("velociraptor", "skull_depth_m"), "el hocico, más bajo que el cráneo")
	# el de película no lleva el cráneo medido: su cabeza es de cine
	assert_false(CareAnatomy.of("velociraptor_pelicula").has("skull_m"), "el de película, sin el cráneo de la reconstrucción")
	assert_true(String((CareAnatomy.of("velociraptor").lips as Dictionary).source).contains("Cullen"), "los labios, con la fuente de Cullen et al. 2023")
