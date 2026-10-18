## El insecto en el banco (app/lab/bench_insect.gd y bench.gd): la pose de cada momento sigue el guion de
## core/lab/sting_lab.gd. La abeja llega, pica, mete el aguijón hasta su longitud útil con el giro medido, tira, se
## desgarra y se va, y el aparato se queda con el saco latiendo mientras bombea; la avispa lo saca y se va; un aguijón
## que pandea se dobla. Con movimiento reducido se enseña quieto el momento que explica el resultado, y el zumbido suena
## solo mientras vuela o pica.
extends "res://tests/case.gd"

const BenchInsect = preload("res://app/lab/bench_insect.gd")
const Bench = preload("res://app/lab/bench.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")

const RUN := StingLab.RUN_MS
const O := { "cx": 180.0, "gy": 121.48 }


static func S(id: String) -> Dictionary:
	return Insects.find_by_id(id)


static func params(claw: Dictionary, target_id: String, force: float, inlay_id := "none") -> Dictionary:
	return {
		"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.find_by_id(Catalog.INLAYS, inlay_id), "claw": claw,
		"target": Catalog.find_by_id(Catalog.TARGETS, target_id), "force": force, "length": 25.0, "type": Catalog.TYPES[1],
		"tear": false, "method": "puncion", "strike": false, "passes": 1.0, "wet": false,
	}


func test_la_abeja_pica_se_desgarra_y_el_saco_bombea() -> void:
	var bee := S("abeja")
	var res := Physics.compute(params(bee, "piel", 0.00575))
	var tl := StingLab.timeline(res, RUN)
	assert_true(tl.autotomy, "la abeja se queda sin aguijón")
	var g := BenchInsect.geometry(bee, res)
	var p0 := BenchInsect.pose(bee, res, 0.0, RUN, O)
	assert_eq(p0.stage, "approach", "empieza llegando")
	assert_true(p0.show_insect and float(p0.flying) == 1.0, "volando")
	assert_eq(p0.extend, 1.0, "la abeja llega con el aguijón fuera (Zhao et al. 2015)")
	var press := BenchInsect.pose(bee, res, (tl.contact + tl.pierce) / 2.0, RUN, O)
	assert_eq(press.stage, "press", "aprieta")
	assert_true(float(press.dimple) > 0.0, "la piel se hunde bajo la punta")
	assert_eq(press.inserted, 0.0, "todavía no ha entrado")
	var mid := BenchInsect.pose(bee, res, (tl.pierce + tl.insertEnd) / 2.0, RUN, O)
	assert_eq(mid.stage, "insert", "entra")
	assert_true(float(mid.inserted) > 0.0 and float(mid.inserted) < float(g.depth), "a medio camino")
	assert_true(float(mid.twist) < 0.0 and float(mid.twist) > float(bee.stinger.twistDeg.value), "giro parcial: %s°" % mid.twist)
	var hold := BenchInsect.pose(bee, res, tl.insertEnd + 1.0, RUN, O)
	assert_near(float(hold.inserted), float(g.depth), 1e-12, 0.0, "dentro hasta la longitud útil")
	assert_near(float(hold.twist), float(bee.stinger.twistDeg.value), 1e-12, 0.0, "con el giro medido (Wu et al. 2014)")
	assert_near(float(hold.visible), float(g.len) - float(g.depth), 1e-9, 0.0, "asoma lo que no ha entrado")
	var pull := BenchInsect.pose(bee, res, (tl.pullStart + tl.tear) / 2.0, RUN, O)
	assert_eq(pull.stage, "pull", "tira")
	assert_true(float(pull.filament) > 0.0 and (pull.gaster as Vector2).y < (pull.base as Vector2).y, "el aparato se estira")
	var gone := BenchInsect.pose(bee, res, tl.leaveEnd + 10.0, RUN, O)
	assert_false(gone.show_insect, "la abeja se ha ido")
	assert_true(gone.apparatus and not gone.attached, "el aparato se queda clavado")
	# el saco se vacía con la bomba de válvulas (×10) y late mientras bombea
	var before := 2.0
	var pulsed := false
	var t: float = tl.tear
	while t < float(tl.pumpEnd):
		var p := BenchInsect.pose(bee, res, t, RUN, O)
		assert_true(float(p.sac_fill) <= before, "el saco nunca se llena (%s ms)" % t)
		before = float(p.sac_fill)
		pulsed = pulsed or float(p.sac_pulse) != 1.0
		t += 137.0
	assert_true(pulsed, "el saco late mientras bombea")
	var end := BenchInsect.pose(bee, res, tl.end, RUN, O)
	assert_eq(end.sac_pulse, 1.0, "acabado el bombeo, quieto")
	assert_true(float(end.sac_fill) < 0.01, "y casi vacío (todo en 1 min)")
	assert_true(float(end.venom.fraction) > 0.99)


func test_la_avispa_lo_saca_y_se_va() -> void:
	var wasp := S("avispa")
	var res := Physics.compute(params(wasp, "piel", float(wasp.force)))
	var tl := StingLab.timeline(res, RUN)
	assert_false(tl.autotomy or tl.stuck, "la avispa no se queda")
	var p0 := BenchInsect.pose(wasp, res, 0.0, RUN, O)
	assert_true(float(p0.extend) < 1.0, "las avispas sacan el aguijón al tocar")
	var leave := BenchInsect.pose(wasp, res, tl.leave + 1.0, RUN, O)
	assert_eq(leave.stage, "leave")
	assert_eq(leave.inserted, 0.0, "se lo ha sacado")
	assert_true(leave.attached and not leave.apparatus, "y se lo lleva")
	var t := 0.0
	while t <= float(tl.end):
		assert_false(BenchInsect.pose(wasp, res, t, RUN, O).apparatus, "nunca deja el aparato (%s ms)" % t)
		t += 100.0
	assert_false(BenchInsect.pose(wasp, res, tl.end + 1.0, RUN, O).show_insect, "al final se ha ido")


func test_el_aguijon_que_pandea_se_dobla() -> void:
	var bee := S("abeja")
	var res := Physics.compute(params(bee, "madera", 1.0, "acero"))
	assert_eq(res.verdict, "SE DOBLA EL AGUIJÓN", "la abeja de acero contra el pino a 1 N")
	var tl := StingLab.timeline(res, RUN)
	var g := BenchInsect.geometry(bee, res)
	assert_eq(BenchInsect.pose(bee, res, tl.contact, RUN, O).bend, 0.0, "al tocar, recto")
	var p := BenchInsect.pose(bee, res, tl.pierce + 10.0, RUN, O)
	assert_near(float(p.bend), BenchInsect.BEND_MAX * float(g.len), 1e-9, 0.0, "doblado del todo al ceder")
	var after := BenchInsect.pose(bee, res, tl.leaveEnd - 1.0, RUN, O)
	assert_true(float(after.bend) < float(p.bend), "el pandeo es elástico: al irse se endereza")
	var still := BenchInsect.still_ms(res, RUN)
	assert_true(still >= float(tl.pierce) and still < float(tl.leave), "con movimiento reducido, un momento con el aguijón apoyado")
	assert_near(float(BenchInsect.pose(bee, res, still, RUN, O).bend), BenchInsect.BEND_MAX * float(g.len), 1e-9, 0.0, "y doblado")
	var crushed := Physics.compute(params(bee, "madera", 0.00575))
	var tc := StingLab.timeline(crushed, RUN)
	assert_true(float(BenchInsect.pose(bee, crushed, tc.pierce + 100.0, RUN, O).crush) > 0.0, "la punta de quitina se aplasta")


func test_el_banco_anima_al_insecto_y_pide_su_zumbido() -> void:
	var cache := ArtCache.new()
	cache.threaded = false
	var b: Bench = Bench.new()
	b.setup(cache, "t")
	var bee := S("abeja")
	var tool := { "claw": bee, "geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "wet": false }
	var piel: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "piel")
	b.set_state({ "target": piel, "res": null, "phase": "idle", "length": 25.0, "method": "puncion", "run": 0, "tool": tool })
	assert_true(b.is_insect(), "un aguijón: el banco pinta el insecto")
	assert_eq(b.insect_pose().stage, "idle", "en espera")
	assert_eq(b.buzz_state().id, "", "en espera no zumba")
	var res := Physics.compute(params(bee, "piel", 0.00575))
	b.set_state({ "target": piel, "res": res, "phase": "running", "length": 25.0, "method": "puncion", "run": 1, "tool": tool })
	b.advance(100.0)
	var z: Dictionary = b.buzz_state()
	assert_eq(z.id, "zumbido-abeja", "llega zumbando")
	assert_true(float(z.volume) > 0.0, "con volumen")
	assert_true(b.is_animating())
	b.set_state({ "target": piel, "res": res, "phase": "done", "length": 25.0, "method": "puncion", "run": 1, "tool": tool })
	var tl := StingLab.timeline(res, RUN)
	var t := 100.0
	while t < float(tl.end):
		b.advance(250.0)
		t += 250.0
	b.advance(250.0)
	assert_false(b.is_animating(), "acaba cuando acaba el bombeo")
	assert_true(b.insect_pose().apparatus, "y deja el aparato clavado")
	assert_eq(b.buzz_state().volume, 0.0, "sin la abeja, sin zumbido")
	assert_true(b.venom_label.visible and b.venom_label.text.contains("147 µg"), "rótulo del veneno: %s" % b.venom_label.text)
	# con movimiento reducido: el momento que explica el resultado, quieto y sin zumbido
	b.reduce_motion = true
	b.set_state({ "target": piel, "res": res, "phase": "running", "length": 25.0, "method": "puncion", "run": 2, "tool": tool })
	assert_eq(b.insect_ms(), BenchInsect.still_ms(res, RUN), "salta al momento quieto")
	b.advance(16.0)
	assert_eq(b.insect_ms(), BenchInsect.still_ms(res, RUN), "y no se mueve")
	assert_eq(b.buzz_state().id, "", "sin zumbido")
	b.set_state({ "target": piel, "res": res, "phase": "done", "length": 25.0, "method": "puncion", "run": 2, "tool": tool })
	assert_false(b.is_animating(), "terminado, no anima")
	b.free()
	cache.dispose()
