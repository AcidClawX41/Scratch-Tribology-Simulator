## Los materiales de la 2.0 en el banco (app/lab/bench_materials.gd y bench.gd): el guion sale del resultado (cada cosa
## pasa cuando la carga llega a su umbral: la cesión de la uña, la carga que parte o abre la ventanilla, el colapso de la
## chapa), la pose de cada momento (la uña que se dobla o se parte, la ventanilla que estalla de golpe y deja caer los
## trozos del hueco, el parabrisas que no cae, la huella que sube al levantar la punta), el movimiento reducido (el final,
## quieto) y, dentro del árbol, la animación de los casos de la demo sin crear nodos por fotograma y sin redibujar cuando
## la escena está quieta.
extends "res://tests/case.gd"

const BenchMaterials = preload("res://app/lab/bench_materials.gd")
const Bench = preload("res://app/lab/bench.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")

const X1 := 46.0
const X2 := 46.0 + 70.0 + 25.0 / 60.0 * 222.0
## Los casos de materiales de la demo del laboratorio (10-15).
const DEMO := [
	{ "geom": "stiletto", "base": "natural", "target": "piel" },
	{ "geom": "almendra", "base": "natural", "target": "coche", "force": 4.0 },
	{ "claw": "oso", "target": "coche", "method": "puncion", "strike": true, "force": 900.0 },
	{ "geom": "cuadrada", "base": "zafiro", "target": "vidrio" },
	{ "claw": "tigre", "inlay": "diamante", "target": "ventanilla", "method": "puncion", "force": 260.0 },
	{ "claw": "oso", "target": "parabrisas", "method": "puncion", "strike": true, "force": 900.0 },
]


static func tool_of(o: Dictionary) -> Dictionary:
	return {
		"claw": Catalog.find_by_id(Catalog.CLAWS, o.claw) if o.has("claw") else null,
		"geom": Catalog.find_by_id(Catalog.GEOMS, o.get("geom", "almendra")), "base": Catalog.find_by_id(Catalog.BASES, o.get("base", "natural")),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, o.get("inlay", "none")), "wet": false,
	}


static func run(o: Dictionary) -> Dictionary:
	var t := tool_of(o)
	var p := {
		"geom": t.geom, "base": t.base, "inlay": t.inlay, "claw": t.claw, "target": Catalog.find_by_id(Catalog.TARGETS, o.target),
		"force": o.get("force", 30.0), "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": o.get("method", "rayado"),
		"strike": o.get("strike", false), "passes": 1.0, "wet": false,
	}
	if o.has("model"):
		p["model"] = o.model
	return Physics.compute(p)


static func plan_of(o: Dictionary) -> Dictionary:
	return BenchMaterials.plan(run(o), tool_of(o), X1, X2)


func test_la_una_se_dobla_cuando_la_carga_llega_a_su_cesion() -> void:
	var o: Dictionary = DEMO[0]
	var res := run(o)
	var pl := plan_of(o)
	assert_eq(String(pl.nail.mode), "dobla", "la uña natural se dobla")
	assert_near(float(pl.load), 30.0, 1e-9, 0.0, "la carga pedida, de la cesión y la tensión del resultado")
	# la carga crece en el primer cuarto del recorrido: llega a breakN (13,8 N de 30 N) a los 0,25·13,8/30 del recorrido
	var e := BenchMaterials.eased_at(float(pl.nail.at), false)
	assert_near(e, BenchMaterials.RAMP * float(res.nail.breakN) / 30.0, 1e-6, 1e-9, "se dobla al llegar a su carga de cesión")
	assert_eq(BenchMaterials.pose(pl, float(pl.nail.at) - 1.0).nail.angle, 0.0, "antes, recta")
	var bent: float = BenchMaterials.pose(pl, float(pl.nail.at) + BenchMaterials.BEND_MS).nail.angle
	assert_near(bent, -BenchMaterials.BEND_DEG * PI / 180.0, 1e-12, 0.0, "después, doblada hacia el dorso")
	assert_eq(float(pl.x_stop), X2, "doblada sigue rayando")
	assert_true(float(pl.end) <= BenchMaterials.SCRATCH_MS, "al rayar, todo dentro del recorrido")
	# una uña más larga o más débil cede antes
	var soft := plan_of({ "geom": "stilettoxl", "base": "natural", "target": "piel" })
	assert_true(float(soft.nail.at) < float(pl.nail.at), "la stiletto XL cede antes")


func test_la_una_que_se_parte_cae_y_deja_de_rayar() -> void:
	var o := { "geom": "stiletto", "base": "gel", "target": "piel" }
	var res := run(o)
	assert_eq(String(res.verdict), "SE PARTE LA UÑA")
	var pl := plan_of(o)
	assert_eq(String(pl.nail.mode), "parte")
	assert_true(float(pl.x_stop) > X1 and float(pl.x_stop) < X2, "deja de rayar donde se parte: x = %s" % pl.x_stop)
	assert_near(float(pl.x_stop), float(pl.nail.x), 1e-9, 0.0)
	var before: Dictionary = BenchMaterials.pose(pl, float(pl.nail.at) - 1.0).nail
	assert_true(float(before.snap) < 0.0 and float(before.angle) < 0.0, "antes de partirse flexa un poco")
	var prev := -1.0
	var t := float(pl.nail.at)
	while t <= float(pl.nail.at) + BenchMaterials.SNAP_MS:
		var snap: float = BenchMaterials.pose(pl, t).nail.snap
		assert_true(snap >= prev, "el trozo cae sin volver atrás (%s ms)" % t)
		prev = snap
		t += 40.0
	assert_eq(BenchMaterials.pose(pl, float(pl.end)).nail.snap, 1.0, "al final, tumbado en la losa")


func test_la_ventanilla_estalla_de_golpe_y_caen_los_trozos_del_hueco() -> void:
	var o: Dictionary = DEMO[4]
	var res := run(o)
	var pl := plan_of(o)
	var g: Dictionary = pl.glazing
	assert_eq(String(g.kind), "templado")
	# al apretar, la carga llega en LOAD_MS tras tocar: estalla cuando llega a la que abre la grieta (pierceN)
	assert_near(float(g.at), float(pl.touch) + BenchMaterials.LOAD_MS * float(res.glazing.pierceN) / BenchMaterials.tip_load(res), 1e-9, 0.0)
	var p0 := BenchMaterials.pose(pl, float(g.at) - 1.0)
	assert_eq(p0.glazing, 0.0, "entera hasta el instante")
	var p1 := BenchMaterials.pose(pl, float(g.at))
	assert_true(p1.glazing == 1.0 and p1.flash == 1.0, "de golpe, con un destello")
	var done := float(g.at) + BenchMaterials.FALL_DELAY + BenchMaterials.FALL_MS
	var p2 := BenchMaterials.pose(pl, done)
	assert_true(p2.fall == 1.0 and p2.flash == 0.0, "los trozos del hueco ya han caído")
	assert_true(float(pl.end) >= done, "el guion no acaba antes de que caigan (no quedan a medias)")
	# las radiales crecen con la carga (a la 2/3) desde que toca
	var c0: float = BenchMaterials.pose(pl, float(pl.touch)).crack
	var c1: float = BenchMaterials.pose(pl, float(pl.touch) + BenchMaterials.LOAD_MS / 2.0).crack
	var c2: float = BenchMaterials.pose(pl, float(pl.touch) + BenchMaterials.LOAD_MS).crack
	assert_true(c0 == 0.0 and c2 == 1.0 and absf(c1 - pow(0.5, 2.0 / 3.0)) < 1e-9, "grietas: %s %s %s" % [c0, c1, c2])
	# un golpe: estalla al impacto
	var hit := plan_of({ "claw": "oso", "target": "ventanilla", "method": "puncion", "strike": true, "force": 900.0 })
	assert_eq(float(hit.glazing.at), float(hit.touch), "el golpe, al tocar")


func test_el_parabrisas_se_agrieta_y_no_cae_nada() -> void:
	var pl := plan_of(DEMO[5])
	assert_eq(String(pl.glazing.kind), "laminado")
	var t := 0.0
	while t <= float(pl.end):
		assert_eq(BenchMaterials.pose(pl, t).fall, -1.0, "la lámina sujeta los trozos (%s ms)" % t)
		t += 50.0
	assert_eq(BenchMaterials.pose(pl, float(pl.end)).glazing, 1.0, "agrietado al final")


func test_la_abolladura_se_hunde_al_golpear_y_al_rayar_desde_el_colapso() -> void:
	var pl := plan_of(DEMO[2])
	assert_eq(float(pl.dent.at), float(pl.touch), "al golpear, al tocar")
	assert_eq(BenchMaterials.pose(pl, float(pl.touch)).dent, 0.0)
	assert_eq(BenchMaterials.pose(pl, float(pl.touch) + BenchMaterials.DENT_MS).dent, 1.0, "hundida en DENT_MS")
	var o := { "claw": "oso", "target": "coche", "force": 300.0 }
	var res := run(o)
	var sc := plan_of(o)
	var e := BenchMaterials.eased_at(float(sc.dent.at), false)
	assert_near(e, BenchMaterials.RAMP * float(res.dent.collapseN) / 300.0, 1e-6, 1e-9, "al rayar, desde que la carga pasa del colapso")
	assert_near(float(sc.dent.x), X1 + (X2 - X1) * e, 1e-9, 0.0)


func test_la_huella_sube_al_levantar_la_punta() -> void:
	var o: Dictionary = DEMO[1]
	var res := run(o)
	var pl := plan_of(o)
	assert_true(pl.wake, "al rayar, la estela del surco que se cierra")
	var mid := BenchMaterials.ms_at_eased(0.5, false)
	assert_near(float(pl.rec.pass), mid, 1e-9, 0.0, "la punta cruza el corte de la lupa a mitad del surco")
	var dyn: Dictionary = ArtMaterials.lupa_art(Catalog.find_by_id(Catalog.TARGETS, "coche"), res).dyn
	var before := BenchMaterials.pose(pl, mid - BenchMaterials.PASS_MS)
	assert_eq(BenchMaterials.rec_depth(dyn, before.rec), 0.0, "antes de pasar, la superficie intacta")
	var at := BenchMaterials.pose(pl, mid)
	assert_near(BenchMaterials.rec_depth(dyn, at.rec), float(dyn.dLoad), 1e-9, 1e-9, "con la punta dentro, lo que se hunde bajo carga")
	var after := BenchMaterials.pose(pl, mid + BenchMaterials.PASS_MS)
	assert_near(BenchMaterials.rec_depth(dyn, after.rec), float(dyn.dRes), 1e-9, 1e-9, "al irse, lo que queda (el barniz recupera todo)")
	var prev := INF
	var t := mid
	while t <= mid + BenchMaterials.PASS_MS / 2.0:
		var d := BenchMaterials.rec_depth(dyn, BenchMaterials.pose(pl, t).rec)
		assert_true(d <= prev + 1e-12, "el fondo sube al irse la punta (%s ms)" % t)
		prev = d
		t += 20.0
	# al punzar, sube con la retirada de la punta
	var po := { "geom": "almendra", "target": "coche", "force": 4.0, "method": "puncion" }
	var pr := run(po)
	var pp := plan_of(po)
	assert_eq(ArtMaterials.lupa_kind(pr), "recuperacion", "al punzar el barniz también recupera")
	assert_false(pp.wake, "sin estela al punzar")
	var dp: Dictionary = ArtMaterials.lupa_art(Catalog.find_by_id(Catalog.TARGETS, "coche"), pr).dyn
	assert_near(BenchMaterials.rec_depth(dp, BenchMaterials.pose(pp, float(pp.end), 0.0).rec), float(dp.dLoad), 1e-9, 1e-9, "con la punta dentro")
	assert_near(BenchMaterials.rec_depth(dp, BenchMaterials.pose(pp, float(pp.end), 1.0).rec), float(dp.dRes), 1e-9, 1e-9, "levantada")


func test_con_la_1x_no_hay_guion() -> void:
	for o: Dictionary in DEMO:
		var o1 := o.duplicate()
		o1["model"] = "1.x"
		assert_true(BenchMaterials.plan(run(o1), tool_of(o1), X1, X2).is_empty(), "%s (1.x): el banco de siempre" % o.target)
		assert_false(plan_of(o).is_empty(), "%s (2.0): con guion" % o.target)


## Nodos del árbol bajo n (n incluido).
static func count_nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += count_nodes(k)
	return c


func test_el_banco_anima_los_materiales_sin_nodos_nuevos_y_quieto_no_redibuja() -> void:
	var cache := ArtCache.new()
	cache.threaded = false
	var b: Bench = add_to_tree(Bench.new())
	b.setup(cache, "t")
	b.size = Vector2(540.0, 255.0)
	var draws := [0]
	b.draw.connect(func() -> void: draws[0] += 1)
	var run_id := 0
	for o: Dictionary in DEMO:
		var tool := tool_of(o)
		var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, o.target)
		var method: String = o.get("method", "rayado")
		var res := run(o)
		run_id += 1
		var st := { "target": target, "res": res, "phase": "running", "length": 25.0, "method": method, "tool": tool, "run": run_id }
		b.set_state(st)
		await wait_frames(1)
		var nodes := count_nodes(b)
		var ms := 0.0
		while b.is_animating() and ms < 5000.0:
			b.advance(50.0)
			ms += 50.0
			if ms >= 1150.0 and b.phase == "running":
				st.phase = "done"
				b.set_state(st)
			await wait_frames(1)
		assert_false(b.is_animating(), "%s: la animación acaba (%s ms)" % [o.target, ms])
		assert_eq(count_nodes(b), nodes, "%s: sin nodos nuevos durante la animación" % o.target)
		var pl := b.materials_plan()
		assert_false(pl.is_empty(), "%s: con guion de materiales" % o.target)
		assert_eq(b.materials_ms(), float(pl.end), "%s: al final del guion" % o.target)
		if pl.lupa != null:
			var text: String = cache.meta("bml:t:%d:%s" % [run_id, target.id]).get("text", "")
			assert_true(b.lupa_label.visible and b.lupa_label.text == text and text != "", "%s: el rótulo de la lupa: «%s»" % [o.target, b.lupa_label.text])
		# con la escena quieta, no se redibuja
		var n0: int = draws[0]
		for i in 4:
			b.advance(16.0)
			await wait_frames(1)
		assert_eq(draws[0], n0, "%s: quieto, sin redibujar" % o.target)
	# con movimiento reducido: el final del guion, de inmediato
	b.reduce_motion = true
	var o10: Dictionary = DEMO[0]
	b.set_state({ "target": Catalog.find_by_id(Catalog.TARGETS, "piel"), "res": run(o10), "phase": "running", "length": 25.0, "method": "rayado",
		"tool": tool_of(o10), "run": 99 })
	assert_eq(b.materials_ms(), float(b.materials_plan().end), "movimiento reducido: el final")
	assert_near(float(b.materials_pose().nail.angle), -BenchMaterials.BEND_DEG * PI / 180.0, 1e-12, 0.0, "la uña ya doblada")
	cache.dispose()
