## La biología de la 2.0 en el banco (app/lab/bench_biology.gd y bench.gd):
## - la herramienta inclinada con el ángulo de ataque del resultado, con el convenio de core/lab/attack.gd (el eje con la
##   superficie, medido hacia donde avanza; la uña, su placa): de punta a 90°, la base por delante por debajo (la uña,
##   dada la vuelta, arrastrando) y por detrás por encima (de gancho). Al empezar el ensayo pasa de la inclinación de la
##   espera a la del resultado; con movimiento reducido, salta;
## - la lupa de la punción que llega al hueso o a la cavidad: la punta entra con el sonido del resultado, topa, marca,
##   atraviesa o se rompe según el resultado, acaba antes de levantarse y sale con la retirada; la herida mide lo que
##   dice el resultado.
## Todo sin nodos nuevos y sin redibujar cuando está quieto.
extends "res://tests/case.gd"

const Bench = preload("res://app/lab/bench.gd")
const BenchBiology = preload("res://app/lab/bench_biology.gd")
const BenchMaterials = preload("res://app/lab/bench_materials.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Attack = preload("res://core/lab/attack.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtBiology = preload("res://core/lab/art_biology.gd")

## Las punciones de la biología de la demo (casos 17-19) y las del Gabón y el casuario en el brazo.
const BONE_CASES := {
	"víbora en el pómulo": { "claw": "vibora", "target": "piel", "zone": "cara", "method": "puncion", "force": 4.0 },
	"casuario de tungsteno en el brazo": { "claw": "casuario", "inlay": "tungsteno", "target": "piel", "zone": "brazo", "method": "puncion",
		"strike": true, "force": 500.0 },
	"Gabón en el abdomen": { "claw": "gabon", "target": "piel", "zone": "abdomen", "method": "puncion", "strike": true, "force": 30.0 },
	"Gabón en el brazo": { "claw": "gabon", "target": "piel", "method": "puncion", "strike": true, "force": 30.0 },
	"casuario en el brazo": { "claw": "casuario", "target": "piel", "method": "puncion", "strike": true, "force": 500.0 },
}

## Dirección de la base de cada dibujo de la 1.x desde su punta (pantalla, y hacia abajo): la garra cuelga de punta y la
## uña de perfil sale de la losa a NAIL_ATTACK_DEG con el dedo arriba a la izquierda.
const CLAW_AXIS := Vector2(0.0, -1.0)


static func nail_axis() -> Vector2:
	var a := deg_to_rad(BenchMaterials.NAIL_ATTACK_DEG)
	return Vector2(-cos(a), -sin(a))


## Ángulo de ataque que se ve en el banco: el de la base vista desde la punta, medido desde +x (hacia donde avanza) con
## la y hacia arriba.
static func drawn_attack(axis: Vector2, t: Dictionary) -> float:
	var d := BenchBiology.tool_xform(Vector2.ZERO, Vector2.ZERO, 1.0, t, 1.0).basis_xform(axis)
	return rad_to_deg(atan2(-d.y, d.x))


static func tool_of(o: Dictionary) -> Dictionary:
	return {
		"claw": Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null,
		"geom": Catalog.find_by_id(Catalog.GEOMS, o.get("geom", "almendra")), "base": Catalog.find_by_id(Catalog.BASES, o.get("base", "natural")),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")), "wet": false,
	}


static func run(o: Dictionary) -> Dictionary:
	var t := tool_of(o)
	return Physics.compute({
		"geom": t.geom, "base": t.base, "inlay": t.inlay, "claw": t.claw, "target": Catalog.find_by_id(Catalog.TARGETS, o.target),
		"force": o.get("force", 10.0), "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": o.get("method", "rayado"),
		"strike": o.get("strike", false), "passes": 1.0, "wet": false, "attack_deg": o.get("attack"), "zone": o.get("zone"),
		"model": o.get("model", Physics.MODEL_V2),
	})


func test_el_dibujo_con_el_angulo_del_resultado() -> void:
	for att: float in [10.0, 20.0, 45.0, 60.0, 89.0, 90.0, 91.0, 120.0, 145.0, 170.0]:
		var claw := BenchBiology.tool_tilt(run({ "claw": "tigre", "target": "madera", "attack": att }), tool_of({ "claw": "tigre" }), false)
		assert_near(drawn_attack(CLAW_AXIS, claw), att, 0.0, 1e-4, "garra a %s°" % att)
		var nail := BenchBiology.tool_tilt(run({ "geom": "stiletto", "target": "madera", "attack": att }), tool_of({ "geom": "stiletto" }), false)
		assert_near(drawn_attack(nail_axis(), nail), att, 0.0, 1e-4, "uña a %s°" % att)
		# la base por delante (tumbada, arrastrando) por debajo de 90°; por detrás (de gancho) por encima
		var want := 1 if att < 90.0 else (-1 if att > 90.0 else 0)
		assert_eq(int(claw.lean), want, "garra a %s°: hacia dónde va la base" % att)
		assert_eq(float(nail.sx) < 0.0, att < 90.0, "uña a %s°: dada la vuelta si arrastra" % att)
	# la uña de gancho de 145° es el dibujo de la 1.x tal cual; la garra de punta, también
	var hook := BenchBiology.tool_tilt(run({ "geom": "stiletto", "target": "madera", "attack": 145.0 }), tool_of({ "geom": "stiletto" }), false)
	assert_near(float(hook.angle), 0.0, 0.0, 1e-12, "uña a 145°: sin girar")
	assert_eq(float(hook.sx), 1.0)
	var tip := BenchBiology.tool_tilt(run({ "claw": "gato", "target": "madera" }), tool_of({ "claw": "gato" }), false)
	assert_eq(float(tip.angle), 0.0, "garra de punta (90°, la de la 1.x)")
	# con la 1.x, el dibujo de la 1.x; al punzar, la garra baja de punta aunque se pida otro ángulo
	assert_eq(BenchBiology.tool_tilt(run({ "geom": "stiletto", "target": "madera", "model": Physics.MODEL_V1 }), tool_of({}), false),
		BenchBiology.none(), "la 1.x")
	var pr := run({ "claw": "tigre", "target": "madera", "attack": 30.0, "method": "puncion" })
	assert_eq(float(BenchBiology.tool_tilt(pr, tool_of({ "claw": "tigre" }), true).angle), 0.0, "la garra punza de punta")
	# en espera: el ángulo de la herramienta (45° la uña, 90° la garra) o el pedido
	assert_near(drawn_attack(nail_axis(), BenchBiology.tool_tilt(null, tool_of({}), false)), Attack.NAIL_DEG, 0.0, 1e-4, "uña en espera")
	assert_near(drawn_attack(nail_axis(), BenchBiology.tool_tilt(null, tool_of({}), false, 120.0)), 120.0, 0.0, 1e-4, "el ángulo pedido")
	assert_eq(float(BenchBiology.tool_tilt(null, tool_of({ "claw": "oso" }), false).angle), 0.0, "garra en espera")


func test_la_vuelta_pasa_por_el_canto() -> void:
	var a := BenchBiology.tool_tilt(null, tool_of({}), false, 45.0)
	var b := BenchBiology.tool_tilt(null, tool_of({}), false, 150.0)
	assert_eq(BenchBiology.tilt_at(a, b, 0.0).sx, a.sx)
	assert_near(float(BenchBiology.tilt_at(a, b, 0.5).sx), 0.0, 0.0, 1e-12, "a mitad de la vuelta, de canto")
	assert_eq(BenchBiology.tilt_at(a, b, 1.0).sx, b.sx)
	assert_near(float(BenchBiology.tilt_at(a, b, 1.0).angle), float(b.angle), 0.0, 1e-12)


func test_en_el_banco_se_inclina_al_empezar() -> void:
	var art := ArtCache.new()
	art.threaded = false
	var b: Bench = add_to_tree(Bench.new())
	b.size = Vector2(720, 340)
	b.setup(art, "t")
	var draws := [0]
	b.draw.connect(func() -> void: draws[0] += 1)
	var o := { "geom": "stiletto", "target": "madera", "attack": 20.0, "force": 10.0 }
	var tool := tool_of(o)
	var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "madera")
	var res := run(o)
	b.set_state({ "target": target, "res": null, "phase": "idle", "length": 25.0, "method": "rayado", "tool": tool, "run": 0 })
	assert_near(drawn_attack(nail_axis(), b.tool_tilt()), Attack.NAIL_DEG, 0.0, 1e-4, "en espera, a 45°")
	b.set_state({ "target": target, "res": res, "phase": "running", "length": 25.0, "method": "rayado", "tool": tool, "run": 1 })
	assert_true(b.is_animating())
	var nodes := b.get_child_count()
	var seen: Array = []
	for i in 12:
		b.advance(40.0)
		seen.append(drawn_attack(nail_axis(), b.tool_tilt()))
		await wait_frames(1)
	assert_near(seen[-1], 20.0, 0.0, 1e-4, "en %s ms, a los 20° del ensayo" % BenchBiology.TILT_MS)
	for i in range(1, seen.size()):
		assert_true(seen[i] <= seen[i - 1] + 1e-9, "se va tumbando sin volver atrás")
	assert_eq(b.get_child_count(), nodes, "sin nodos nuevos")
	b.set_state({ "target": target, "res": res, "phase": "done", "length": 25.0, "method": "rayado", "tool": tool, "run": 1 })
	for i in 30:
		b.advance(50.0)
		await wait_frames(1)
	assert_false(b.is_animating(), "quieto al acabar")
	var n0: int = draws[0]
	for i in 4:
		b.advance(16.0)
		await wait_frames(1)
	assert_eq(draws[0], n0, "quieto, sin redibujar")
	# movimiento reducido: ya inclinada
	b.reduce_motion = true
	b.set_state({ "target": target, "res": null, "phase": "idle", "length": 25.0, "method": "rayado", "tool": tool, "run": 1 })
	b.set_state({ "target": target, "res": res, "phase": "running", "length": 25.0, "method": "rayado", "tool": tool, "run": 2 })
	assert_near(drawn_attack(nail_axis(), b.tool_tilt()), 20.0, 0.0, 1e-4, "sin animación")
	# la lupa de una uña que arrastra (la base por delante) va a la izquierda
	var t2 := tool.duplicate()
	t2["lean"] = 1
	var rec := run({ "geom": "almendra", "target": "coche", "force": 4.0 })
	var pl := BenchMaterials.plan(rec, t2, Bench.X1, Bench.X1 + 70.0 + 25.0 / 60.0 * 222.0)
	assert_eq(pl.lupa.pos, BenchMaterials.LUPA_LEFT, "la lupa, lejos del dedo")
	b.queue_free()
	art.dispose()


func test_el_guion_de_la_puncion_hasta_el_hueso() -> void:
	var x2 := Bench.X1 + 70.0 + 25.0 / 60.0 * 222.0
	var sound_ms := LabState.RUN_MS * 0.78  # LabState.run(): el sonido de una punción, al impactar
	for name: String in BONE_CASES:
		var o: Dictionary = BONE_CASES[name]
		var res := run(o)
		var pl := BenchBiology.with_biology(BenchMaterials.plan(res, tool_of(o), Bench.X1, x2), res, tool_of(o), x2)
		assert_false(pl.is_empty(), "%s: con guion" % name)
		var b: Dictionary = pl.bone
		assert_eq(b.kind, ArtBiology.lupa_kind(res), name)
		assert_true(float(pl.lupa.at) < float(pl.touch) - 200.0, "%s: la lupa ya se ve cuando la punta toca" % name)
		assert_true(absf(float(b.hit) - sound_ms) <= 100.0, "%s: topa (o llega) con el sonido (%s ms y %s ms)" % [name, b.hit, sound_ms])
		assert_true(float(b.full) <= LabState.RUN_MS, "%s: llega al fondo antes de levantarse" % name)
		assert_eq(bool(b.pierced), res.pen.bonePierced == true, name)
		assert_eq(bool(b.broken), res.pen.toolBroken == true, name)
		# la pose: la punta baja sin volver atrás hasta el fondo, y sale al levantarla
		var prev := -INF
		var ms := 0.0
		while ms <= float(pl.end):
			var p := BenchBiology.bone_pose(pl, ms)
			assert_true(float(p.tip) >= prev - 1e-12, "%s: a los %s ms la punta no sube" % [name, ms])
			assert_true(float(p.reached) >= 0.0 and float(p.reached) <= 2.0, name)
			prev = float(p.tip)
			ms += 10.0
		var last := BenchBiology.bone_pose(pl, float(pl.end))
		assert_eq(float(last.tip), 2.0 if b.pierced else 1.0, "%s: en el fondo" % name)
		assert_eq(float(last.out), 0.0, "%s: sin levantar" % name)
		assert_eq(float(BenchBiology.bone_pose(pl, float(pl.end), 1.0).out), 1.0, "%s: fuera al levantarla" % name)
		# el golpe: solo contra el hueso; el rebote, solo si no lo marca; el respingo, si se rompe
		var at_hit := BenchBiology.bone_pose(pl, float(b.hit) + 1.0)
		assert_eq(float(at_hit.flash) > 0.0, b.kind == "hueso", "%s: el destello del golpe" % name)
		var mid := BenchBiology.bone_pose(pl, float(b.hit) + BenchBiology.HIT_MS / 2.0)
		assert_eq(float(mid.bounce) > 0.0, b.kind == "hueso" and not b.pierced and not b.broken and not b.marks, "%s: rebote" % name)
		assert_eq(bool(mid.broken) and float(mid.recoil) > 0.0, bool(b.broken), "%s: respingo del colmillo roto" % name)
		# la herida de la lupa (la forma de la punta del modelo en su fondo) mide lo que dice el resultado
		var dyn: Dictionary = ArtBiology.lupa_art({}, res).dyn
		assert_near(2.0 * BenchBiology.tip_half_width(float(dyn.depth), dyn), float(res.grooveWidthUm) * float(dyn.k), 1e-6, 1e-9,
			"%s: el agujero, grooveWidthUm" % name)
	# sin hueso ni cavidad, nada
	var none := run({ "claw": "vibora", "target": "piel", "method": "puncion", "force": 4.0 })
	assert_true(BenchBiology.with_biology(BenchMaterials.plan(none, tool_of({ "claw": "vibora" }), Bench.X1, x2), none, tool_of({}), x2).is_empty())


func test_las_lupas_quietas_en_el_banco() -> void:
	# el callo (caso 16), el ataque (21) y el esmalte (22) de la demo: aparecen cuando las de los materiales, lejos de la
	# herramienta, y el rótulo es el de su dibujo
	var cases := [
		{ "claw": "pajaro", "target": "piel", "zone": "palma", "force": 1.5, "want": "callo" },
		{ "geom": "stiletto", "target": "madera", "attack": 20.0, "force": 10.0, "want": "ataque" },
		{ "claw": "vibora", "target": "cobre", "force": 4.0, "want": "esmalte" },
		{ "claw": "tigre", "target": "piel", "zone": "dorsomano", "force": 260.0, "want": "laceracion" },
	]
	var x2 := Bench.X1 + 70.0 + 25.0 / 60.0 * 222.0
	var cache := ArtCache.new()
	cache.threaded = false
	var b: Bench = add_to_tree(Bench.new())
	b.setup(cache, "t")
	b.size = Vector2(540.0, 255.0)
	var run_id := 0
	for o: Dictionary in cases:
		var res := run(o)
		var tool := tool_of(o)
		var tilt := BenchBiology.tool_tilt(res, tool, false)
		var t := tool.duplicate()
		t["lean"] = tilt.lean
		var pl := BenchBiology.with_biology(BenchMaterials.plan(res, t, Bench.X1, x2), res, t, x2)
		assert_eq(String(pl.lupa.kind), String(o.want), "%s: su lupa" % o.want)
		assert_eq(float(pl.lupa.at), BenchMaterials.ms_at_eased(BenchMaterials.LUPA_E, false), "%s: cuando las de los materiales" % o.want)
		assert_eq(pl.lupa.pos, BenchMaterials.lupa_pos(false, x2, t), "%s: su sitio" % o.want)
		assert_true(float(pl.end) <= BenchMaterials.SCRATCH_MS, "%s: acaba con el recorrido" % o.want)
		assert_false(pl.has("bone"), "%s: sin guion de punción" % o.want)
		run_id += 1
		var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, o.target)
		var st := { "target": target, "res": res, "phase": "running", "length": 25.0, "method": "rayado", "tool": tool, "run": run_id }
		b.set_state(st)
		var nodes := b.get_child_count()
		var ms := 0.0
		while b.is_animating() and ms < 5000.0:
			b.advance(50.0)
			ms += 50.0
			if ms >= LabState.RUN_MS and b.phase == "running":
				st.phase = "done"
				b.set_state(st)
			await wait_frames(1)
		assert_false(b.is_animating(), "%s: acaba" % o.want)
		assert_eq(b.get_child_count(), nodes, "%s: sin nodos nuevos" % o.want)
		var text: String = cache.meta("bml:t:%d:%s" % [run_id, target.id]).get("text", "")
		assert_true(b.lupa_label.visible and b.lupa_label.text == text and text != "", "%s: el rótulo: «%s»" % [o.want, text])
	b.queue_free()
	cache.dispose()


func test_en_el_banco_la_punta_llega_al_hueso() -> void:
	var cache := ArtCache.new()
	cache.threaded = false
	var b: Bench = add_to_tree(Bench.new())
	b.setup(cache, "t")
	b.size = Vector2(540.0, 255.0)
	var draws := [0]
	b.draw.connect(func() -> void: draws[0] += 1)
	var run_id := 0
	for name: String in BONE_CASES:
		var o: Dictionary = BONE_CASES[name]
		var res := run(o)
		var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, o.target)
		run_id += 1
		var st := { "target": target, "res": res, "phase": "running", "length": 25.0, "method": "puncion", "tool": tool_of(o), "run": run_id }
		b.set_state(st)
		await wait_frames(1)
		var nodes := b.get_child_count()
		var ms := 0.0
		while b.is_animating() and ms < 5000.0:
			b.advance(50.0)
			ms += 50.0
			if ms >= LabState.RUN_MS and b.phase == "running":
				st.phase = "done"
				b.set_state(st)
			await wait_frames(1)
		assert_false(b.is_animating(), "%s: la animación acaba (%s ms)" % [name, ms])
		assert_eq(b.get_child_count(), nodes, "%s: sin nodos nuevos" % name)
		var pl := b.materials_plan()
		assert_eq(String(pl.lupa.kind), ArtBiology.lupa_kind(res), "%s: la lupa de la punción" % name)
		assert_eq(b.materials_ms(), float(pl.end), "%s: al final del guion" % name)
		assert_eq(float(b.materials_pose().bone.out), 1.0, "%s: la punta ya ha salido" % name)
		var text: String = cache.meta("bml:t:%d:%s" % [run_id, target.id]).get("text", "")
		assert_true(b.lupa_label.visible and b.lupa_label.text == text and text != "", "%s: el rótulo de la lupa: «%s»" % [name, text])
		var n0: int = draws[0]
		for i in 4:
			b.advance(16.0)
			await wait_frames(1)
		assert_eq(draws[0], n0, "%s: quieto, sin redibujar" % name)
	# con movimiento reducido: el final, de inmediato (la herida y lo que le ha pasado al hueso, la punta fuera)
	b.reduce_motion = true
	var o2: Dictionary = BONE_CASES["Gabón en el brazo"]
	b.set_state({ "target": Catalog.find_by_id(Catalog.TARGETS, "piel"), "res": run(o2), "phase": "running", "length": 25.0,
		"method": "puncion", "tool": tool_of(o2), "run": 99 })
	assert_eq(b.materials_ms(), float(b.materials_plan().end), "movimiento reducido: el final")
	var bp: Dictionary = b.materials_pose().bone
	assert_true(bool(bp.broken) and float(bp.out) == 1.0, "la punta rota se queda; el resto, fuera")
	b.queue_free()
	cache.dispose()
