## Casos de referencia de la unidad 5d (tests/fixtures/spec/reforja.json, docs/fisica/reforja.md §8) contra
## core/lab/claw_forge.gd: cada caso lleva su cálculo a mano en la nota.
## Formato: `expect` es { ruta con puntos dentro del resultado: { value | min | max, tol } }; `tol` es relativa; `value`
## sin `tol` exige igualdad exacta; `min` y `max` son inclusivos. Un caso que no se cumple no se ajusta: se averigua si el
## fallo es del código o de la especificación.
extends "res://tests/case.gd"

const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Spec = preload("res://tests/lab/test_velociraptor_spec.gd")

const SPEC := "res://tests/fixtures/spec/reforja.json"
const KINDS := [
	"kennedy", "kingery", "manson", "temple", "temple_zafiro", "desconchado", "bifano", "union", "union2", "funda",
	"crecimiento", "sinterizado", "ald", "muerde", "permanente", "barrera", "masa", "proceso", "mezcla", "hpht",
	"calentar", "cuarzo",
]

var cases: Array = []


func before_each() -> void:
	if cases.is_empty():
		cases = load_json(SPEC)


## Sigue la receta de f al pie de la letra (los pasos con acción de su tutorial).
static func _follow(f: RefCounted) -> void:
	for st: Dictionary in f.tutorial():
		if String(st.action) != "":
			f.do_step(st)


## El resultado de un caso, con los nombres de campo del JSON.
static func run_case(inp: Dictionary) -> Dictionary:
	match String(inp.kind):
		"kennedy":
			return { "pMinMPa": ClawForge.kennedy_mpa(float(inp.tC)), "tMaxC": ClawForge.kennedy_t_max(float(inp.pMPa)) }
		"kingery":
			return { "dtK": ClawForge.shock_dt(float(inp.sigmaMPa), float(inp.eGPa), float(inp.alpha)) }
		"manson":
			var out := {}
			var i := 0
			for b: float in inp.betas:
				out["psi%d" % i] = ClawForge.manson_psi(b)
				i += 1
			return out
		"temple":
			return { "limitC": ClawForge.shock_limit_c(String(inp.material), String(inp.medium), float(inp.aMm)) }
		"temple_zafiro":
			var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "zafiro" })
			var rec: Dictionary = f.recommended()
			f.mix(rec.mix)
			f.fire(rec.fire)
			var sn: Dictionary = f.snapshot()
			return {
				"agua": ClawForge.shock_limit_c("zafiro", "agua", 6.5), "aceite": ClawForge.shock_limit_c("zafiro", "aceite", 6.5),
				"aire": ClawForge.shock_limit_c("zafiro", "aire", 6.5),
				"aguaDefect": ClawForge.evaluate_cool(sn.piece, "agua", sn.sheath).defect,
				"aireOk": ClawForge.evaluate_cool(sn.piece, "aire", sn.sheath).ok,
			}
		"desconchado":
			var out := {}
			var i := 0
			for k: float in inp.kics:
				out["f%d" % i] = ClawForge.edge_chip_n(k, float(inp.dMm))
				i += 1
			return out
		"bifano":
			var out := {}
			var i := 0
			for row: Array in inp.rows:
				out["dc%d" % i] = ClawForge.ductile_depth_um(float(row[0]), float(row[1]), float(row[2]))
				i += 1
			return out
		"union":
			return ClawForge.bond_capacity(String(inp.adhesive), float(inp.gapMm), float(inp.areaMm2), String(inp.humidity))
		"union2":
			var wet := ClawForge.bond_capacity("epoxi", 0.15, 178.69, "empapada")
			var cy := ClawForge.bond_capacity("cianoacrilato", 0.2, 178.69, "natural")
			return { "wetN": wet.capacityN, "cyanoCures": cy.cures, "cyanoN": cy.capacityN }
		"funda":
			return ClawForge.sheath_geometry(CareData.claw_entry(String(inp.claw)), float(inp.coverMm), float(inp.wallMm))
		"crecimiento":
			var out := {}
			for pair: Array in [["zafiro", "verneuilS"], ["diamante_hpht", "hphtS"], ["diamante_cvd", "cvdS"]]:
				var f := ClawForge.new({ "animal": String(inp.animal), "claw": String(inp.claw), "recipe": pair[0] })
				var rec: Dictionary = f.recommended()
				f.mix(rec.mix)
				var r: Dictionary = f.fire(rec.fire)
				out[pair[1]] = r.timeNeedS
				if pair[0] == "diamante_hpht":
					out["hphtMg"] = r.need
			return out
		"sinterizado":
			var out := {}
			var i := 0
			for t: float in inp.temps:
				out["t%d" % i] = ClawForge.alumina_time_s(t)
				i += 1
			return out
		"ald":
			var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
			var c: Dictionary = f.coat({ "method": "ald_alumina", "target": "garra_viva", "cycles": float(inp.cycles), "time_s": 60.0 })
			return c
		"muerde":
			var out := {}
			var i := 0
			for pr: Array in inp.pairs:
				out["eta%d" % i] = ClawForge.bite_efficiency(float(pr[0]), float(pr[1]))
				i += 1
			return out
		"permanente", "barrera":
			return ClawForge.barrier_heating(float(inp.tC), float(inp.timeS), String(inp.barrier), float(inp.barrierMm), float(inp.wallMm))
		"masa":
			var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": String(inp.recipe) })
			_follow(f)
			return f.result_claw()
		"proceso":
			var f := ClawForge.new({ "animal": String(inp.animal), "claw": String(inp.claw), "recipe": String(inp.recipe) })
			_follow(f)
			var rc: Dictionary = f.result_claw()
			rc["verdict"] = f.report().verdict
			return rc
		"mezcla":
			return ClawForge.evaluate_mix(ForgeData.recipe(String(inp.recipe)), inp.grams)
		"hpht":
			var out := {}
			var i := 0
			for t: float in inp.temps:
				var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "diamante_hpht" })
				var rec: Dictionary = f.recommended()
				f.mix(rec.mix)
				var p: Dictionary = (rec.fire as Dictionary).duplicate()
				p["temp_c"] = t
				out["d%d" % i] = f.fire(p).defect
				i += 1
			return out
		"calentar":
			var out := {}
			var i := 0
			for row: Array in inp.rows:
				var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
				f.choose(String(row[0]))
				out["d%d" % i] = f.heat({ "temp_c": float(row[1]), "atmosphere": String(row[2]) }).defect
				i += 1
			return out
		"cuarzo":
			var out := {}
			for medium: String in ["aire", "horno"]:
				var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila" })
				f.choose("cuarzo")
				f.heat({ "temp_c": float(inp.tC), "atmosphere": "aire" })
				out[medium] = f.cool(medium).defect
			return out
	return {}


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
			var why := Spec.mismatch(Spec.at_path(got, path), c.expect[path])
			assert_true(why == "", "%s · %s: %s" % [c.id, path, why])


func test_los_datos_del_caso_coinciden_con_el_catalogo() -> void:
	# los cálculos a mano usan estos números: si cambian los datos, hay que rehacer los casos
	assert_eq(float(ForgeData.COOLING.agua.h), 80000.0, "agua: 8·10⁴ W/(m²·K)")
	assert_eq(float(ForgeData.COOLING.aceite.h), 23000.0, "aceite: 2,3·10⁴")
	assert_eq(float(ForgeData.COOLING.aire.h), 15.0, "aire: 15")
	assert_eq(float(ForgeData.MATERIALS.alumina.alpha.value), 8.2e-6)
	assert_eq(float(ForgeData.MATERIALS.alumina.k.value), 30.0)
	assert_eq(float(ForgeData.MATERIALS.zafiro.alpha.value), 8.8e-6)
	assert_eq(float(ForgeData.MATERIALS.zafiro.k.value), 40.0)
	assert_eq(float(ForgeData.NEW_MATERIALS.alumina.strength_mpa), 379.0)
	assert_eq(float(ForgeData.NEW_MATERIALS.alumina.E), 370.0)
	assert_eq(float(ForgeData.RECIPES.zafiro.growth.diameter_mm), 13.0, "bola de 13 mm")
	assert_eq(float(ForgeData.RECIPES.zafiro.growth.value), 10.0, "Verneuil a 10 mm/h")
	assert_eq(float(ForgeData.RECIPES.diamante_hpht.growth.value), 7.0, "HPHT a 7 mg/h")
	assert_eq(float(ForgeData.RECIPES.diamante_cvd.growth.value), 100.0, "CVD a 100 µm/h")
	assert_eq(float(ForgeData.EDGE_CHIP_BETA.value), 9.0)
	assert_eq(float(ForgeData.DUCTILE_REGIME_K.value), 0.15)
	assert_eq(float(ForgeData.ADHESIVES.epoxi.tau), 14.9)
	assert_eq(float(ForgeData.ADHESIVES.cianoacrilato.gap_max), 0.15)
	assert_eq(float(ForgeData.KERATIN_SHEAR.tresca), 0.5)
	assert_eq(float(CareData.INTERLAMINAR.value), 0.25)
	assert_eq(float(ForgeData.COATINGS.ald_alumina.per_cycle_um), 1.107e-4)
	assert_eq(float(ForgeData.BARRIERS.silicona.k), 0.2)
	assert_eq(float(ForgeData.SHEATH.cover_frac), 0.4, "la funda cubre el 40 %: 14 mm del águila")
	assert_eq(float(ForgeData.SHEATH.wall_mm), 1.0)
	var eagle := CareData.claw_entry("aguila")
	assert_eq([float(eagle.area), float(eagle.alpha), float(eagle.reach), float(eagle.force)], [0.04, 15.0, 35.0, 100.9], "la garra del águila del banco (con las correcciones de la 2.0)")
