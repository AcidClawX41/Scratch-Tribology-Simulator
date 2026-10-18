## Casos de referencia de la unidad 4e (tests/fixtures/spec/velociraptor.json, docs/fisica/velociraptor.md §9) contra los
## módulos puros de la fase A: core/lab/velociraptor.gd, claw_sharpness.gd y claw_mass.gd; y, de la fase B (unidad 4i, el
## tramo del banco), los casos «banco», a través de Physics.compute con el catálogo 2.0 (el velocirraptor, su garra
## reforjada y afilada, y la patada del casuario). Los del coche en marcha (MovingCar) llegarán con su tramo.
## Formato: `expect` es { ruta con puntos dentro del resultado: { value | min | max, tol } }; `tol` es relativa; `value`
## sin `tol` exige igualdad exacta; `min` y `max` son inclusivos. Un caso que no se cumple no se ajusta: se averigua si el
## fallo es del código o de la especificación.
extends "res://tests/case.gd"

const Velociraptor = preload("res://core/lab/velociraptor.gd")
const Sharp = preload("res://core/lab/claw_sharpness.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")

const SPEC := "res://tests/fixtures/spec/velociraptor.json"
const KINDS := ["masa", "agarre", "fuerzas", "locomocion", "garra", "frontal", "afilado", "afilado_limite", "presion", "compromiso", "masa_garra",
	"banco"]

var cases: Array = []


func before_each() -> void:
	if cases.is_empty():
		cases = load_json(SPEC)


## El resultado de un caso, con los nombres de campo del JSON.
static func run_case(inp: Dictionary) -> Dictionary:
	match String(inp.kind):
		"masa":
			var r := Velociraptor.mass_report()
			var cqe := Velociraptor.cqe_mass_kg(float(inp.femurCircMm), float(inp.alpha2))
			return {
				"cqeKg": cqe, "cqeMinKg": cqe * (1.0 - Velociraptor.CQE_PPE), "cqeMaxKg": cqe * (1.0 + Velociraptor.CQE_PPE),
				"value": r.value, "min": r.min, "max": r.max,
			}
		"agarre":
			var m := float(inp.massKg)
			return { "value": Velociraptor.grip_n(m), "min": Velociraptor.grip_n(m, "min"), "max": Velociraptor.grip_n(m, "max") }
		"fuerzas":
			var m := float(inp.massKg)
			return {
				"replicaN": Velociraptor.replica_load_n(m), "clawMuscleN": Velociraptor.claw_muscle_n(m),
				"clawMuscleStrongN": Velociraptor.claw_muscle_n(m, true),
			}
		"locomocion":
			return {
				"runMs": Velociraptor.run_speed_ms(), "runHiMs": Velociraptor.run_speed_ms(true),
				"leapMs": Velociraptor.leap_speed_ms(), "leapHiMs": Velociraptor.leap_speed_ms(true),
				"leapHeightM": Velociraptor.leap_height_m(), "leapHeightHiM": Velociraptor.leap_height_m(true),
			}
		"garra":
			var b := Velociraptor.keratin_band_mm()
			return {
				"keratinMm": b.value, "keratinMinMm": b.min, "keratinMaxMm": b.max,
				"tipRadiusUm": Velociraptor.tip_radius_um(), "tipOpen": Velociraptor.SICKLE.tipRadiusUm.get("open") == true,
			}
		"frontal":
			return { "areaM2": Velociraptor.frontal_area_m2(float(inp.massKg)) }
		"afilado":
			var tip := Sharp.tip_of(float(inp.rUm), float(inp.alphaDeg))
			var e := Sharp.evaluate(tip, inp.strength, float(inp.lateralN))
			e["chipNaturalN"] = Sharp.chip_load_n(Sharp.tip_of(float(inp.r0Um), float(inp.alphaDeg)), float(inp.strength.value))
			e["pressureGain"] = Sharp.pressure_gain(float(inp.r0Um), float(inp.rUm))
			return e
		"afilado_limite":
			return { "sharpestUm": Sharp.sharpest_surviving_um(float(inp.alphaDeg), float(inp.sigmaMPa), float(inp.lateralN)) }
		"presion":
			var f := float(inp.forceN)
			var et := float(inp.eToolGPa)
			var eg := float(inp.eTargetGPa)
			var h := float(inp.hMPa)
			var a := float(inp.alphaDeg)
			return {
				"p0NaturalMPa": Sharp.hertz_peak_mpa(f, float(inp.r0Um), et, eg), "p0MPa": Sharp.hertz_peak_mpa(f, float(inp.rUm), et, eg),
				"yieldOnsetNaturalN": Sharp.yield_onset_n(float(inp.r0Um), et, eg, h), "yieldOnsetN": Sharp.yield_onset_n(float(inp.rUm), et, eg, h),
				"depthNaturalUm": Sharp.plastic_depth_um(float(inp.r0Um), a, f, h), "depthUm": Sharp.plastic_depth_um(float(inp.rUm), a, f, h),
			}
		"compromiso":
			return Sharp.tradeoff(
				float(inp.r0Um), float(inp.alphaDeg), float(inp.sharpness), float(inp.eToolGPa), inp.strength,
				float(inp.forceN), float(inp.mu), float(inp.eTargetGPa), float(inp.hMPa))
		"masa_garra":
			var reach := float(inp.reachMm)
			var v := ClawMass.cone_volume_mm3(reach)
			if inp.has("heightMm"):
				v = ClawMass.elliptic_cone_volume_mm3(reach, float(inp.heightMm), float(inp.widthMm))
			var out: Dictionary = ClawMass.energy_effect(
				inp.inlay, v, int(inp.nClaws), float(inp.animalKg), float(inp.strikeMKg), float(inp.strikeVMs))
			out["volumeMm3"] = v
			return out
		"banco":
			return Physics.compute(bench_params(inp))
	return {}


## Parámetros de compute() de un caso «banco»: el catálogo 2.0 (Catalog) con los valores por defecto del golden (uña
## almendra natural, arañazo de 25 mm, una pasada) y el modelo 2.0; `sharpness` y `zone` si los trae; `strikeBand`
## ("max"), el golpe de la banda de la corrección de la 2.0 (ClawsV2.band) en lugar del valor.
static func bench_params(inp: Dictionary) -> Dictionary:
	var claw: Dictionary = Catalog.find_by_id(Catalog.CLAWS, inp.claw)
	if inp.get("strikeBand") != null:
		claw = claw.duplicate(true)
		claw.strike = ClawsV2.band(claw, "strike")[inp.strikeBand]
	var p := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, inp.get("inlay", "none")), "claw": claw,
		"target": Catalog.find_by_id(Catalog.TARGETS, inp.target), "type": Catalog.find_by_id(Catalog.TYPES, "aranazo"),
		"force": float(inp.force), "length": 25.0, "tear": false, "method": inp.get("method", "rayado"),
		"strike": inp.get("strike", false), "passes": 1.0, "wet": false, "model": Physics.MODEL_V2,
	}
	for k in ["sharpness", "zone"]:
		if inp.get(k) != null:
			p[k] = inp[k]
	return p


static func at_path(root: Dictionary, path: String) -> Variant:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not cur.has(key):
			return "<falta>"
		cur = cur[key]
	return cur


## Motivo por el que un valor no cumple lo esperado, o "" si lo cumple.
static func mismatch(got: Variant, exp: Dictionary) -> String:
	if exp.has("value"):
		var want: Variant = exp.value
		if want == null or typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
			if not (typeof(got) == typeof(want) and got == want):
				return "%s ≠ %s" % [show(got), show(want)]
		elif not is_num(got):
			return "%s no es un número" % show(got)
		elif exp.has("tol"):
			if absf(float(got) - float(want)) > float(exp.tol) * absf(float(want)):
				return "%s ≠ %s ± %s %%" % [show(got), show(want), float(exp.tol) * 100.0]
		elif float(got) != float(want):
			return "%s ≠ %s" % [show(got), show(want)]
	if exp.has("min") and not (is_num(got) and float(got) >= float(exp.min)):
		return "%s < %s" % [show(got), show(exp.min)]
	if exp.has("max") and not (is_num(got) and float(got) <= float(exp.max)):
		return "%s > %s" % [show(got), show(exp.max)]
	return ""


func test_el_formato_de_los_casos() -> void:
	assert_true(cases.size() >= 15, "casos: %d" % cases.size())
	var ids := {}
	for c: Dictionary in cases:
		assert_false(ids.has(c.id), "%s: id único" % c.id)
		ids[c.id] = true
		assert_true(KINDS.has(String(c.input.get("kind", ""))), "%s: tipo de caso conocido" % c.id)
		assert_true(String(c.get("note", "")).length() > 40, "%s: nota que explica el caso" % c.id)
		assert_true(String(c.get("source", "")).length() > 20, "%s: fuente" % c.id)
		assert_true(c.expect.size() > 0, "%s: algo que comprobar" % c.id)


func test_los_casos_de_referencia() -> void:
	for c: Dictionary in cases:
		var got := run_case(c.input)
		assert_true(not got.is_empty(), "%s: el caso se calcula" % c.id)
		for path: String in c.expect:
			var why := mismatch(at_path(got, path), c.expect[path])
			assert_true(why == "", "%s · %s: %s" % [c.id, path, why])


func test_los_datos_del_caso_coinciden_con_el_catalogo() -> void:
	# los casos de la garra y de la masa usan los números de la ficha: si cambia la ficha, hay que revisar los casos
	var e: Dictionary = Velociraptor.ENTRY
	for c: Dictionary in cases:
		var inp: Dictionary = c.input
		if inp.kind == "agarre" or inp.kind == "fuerzas":
			assert_eq(float(inp.massKg), float(e.mass), "%s: la masa de la ficha" % c.id)
		if inp.kind == "masa_garra" and inp.get("animalKg") == 19.7:
			assert_eq(float(inp.reachMm), float(e.reach), "%s: el alcance de la ficha" % c.id)
			assert_near(float(inp.strikeMKg), float(e.strike.m), 1e-12, 0.0, "%s: la masa del golpe" % c.id)
		# fase B: la patada del casuario de la 2.0 es la de ClawsV2.kick_strike (MovingCar.KICK)
		if inp.kind == "masa_garra" and String(c.id).contains("patada"):
			var k := ClawsV2.kick_strike(float(inp.animalKg))
			assert_near(float(inp.strikeMKg), float(k.value.m), 1e-12, 0.0, "%s: la masa del golpe de la patada" % c.id)
			assert_near(float(inp.strikeVMs), MovingCar.kick_leap_ms(), 1e-12, 0.0, "%s: la velocidad del salto" % c.id)
		if inp.kind == "banco":
			assert_true(Catalog.find_by_id(Catalog.CLAWS, inp.claw) != null, "%s: %s está en el catálogo 2.0" % [c.id, inp.claw])
		if inp.kind == "afilado" or inp.kind == "compromiso":
			assert_near(float(inp.r0Um), Velociraptor.tip_radius_um(), 0.0, 0.05, "%s: la punta de la ficha" % c.id)
		# las resistencias de los casos son las de claw_fracture.gd (unidad 4d)
		if inp.has("material"):
			var s: Variant = ClawFracture.strength(inp.material)
			assert_true(s != null, "%s: %s tiene resistencia en claw_fracture.gd" % [c.id, inp.material])
			if s == null:
				continue
			if inp.has("strength"):
				for key: String in ["value", "min", "max"]:
					assert_near(float(inp.strength[key]), float(s[key]), 1e-9, 0.0, "%s: %s.%s" % [c.id, inp.material, key])
				assert_eq(inp.strength.kind, s.kind, "%s: kind" % c.id)
				if s.kic != null:
					assert_near(float(inp.strength.kic), float(s.kic), 1e-12, 0.0, "%s: kic" % c.id)
			else:
				assert_near(float(inp.sigmaMPa), float(s.value), 1e-12, 0.0, "%s: σ" % c.id)
