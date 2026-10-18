## Biología de la 2.0 integrada en el banco (unidad 4b; docs/fisica/pulido-biologia.md §9): los casos de referencia de la
## unidad 1g con el compute() integrado, el contrato de los campos nuevos (zone, pen, tipHv, DpEff, faceDeg y attackDeg)
## y las invariantes de la 2.0: más fuerza nunca hunde menos en ninguna zona; el hueso para la punta sin que pase del
## alcance; la grieta en todas las capas y el roce en los flancos solo frenan; tumbar la herramienta nunca corta más ni
## deja a la uña aguantar más carga; y la uña con gema mojada se dobla con la queratina mojada. También el ángulo por
## defecto, los textos nuevos, la cesión de una uña que golpea (yieldN), el gancho, los aguijones por zonas y la zona y
## el ángulo en el estado del banco.
extends "res://tests/case.gd"

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Zones = preload("res://core/lab/zones.gd")
const Pen = preload("res://core/lab/penetration.gd")
const Attack = preload("res://core/lab/attack.gd")
const Bending = preload("res://core/lab/bending.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const LabState = preload("res://core/lab/lab_state.gd")

const SPEC := "res://tests/fixtures/spec/pulido-biologia.json"
const V1 := Physics.MODEL_V1
const V2 := Physics.MODEL_V2
## Holgura de las comparaciones «nunca más hondo» (relativa y en µm): la de las bisecciones del resolvedor.
const REL := 1e-9
const ABS_UM := 1e-6
## Claves del informe de penetration.gd en compute() (docs/fisica/pulido-biologia.md §9.3; yielded y demandN, unidad 4b).
const PEN_KEYS := ["zone", "zoneName", "method", "depthUm", "layerId", "layer", "bleeds", "fullReach", "boneHit", "epiUm",
	"deepUm", "boneDepthUm"]
const PEN_PUNCTURE_KEYS := ["pierces", "fPuncture", "stoppedBy", "boneIndentUm", "bonePierced", "toolBroken", "toolLoadN",
	"crackN", "frictionN", "boneN", "resN", "workJ", "energyLeftJ", "yielded", "demandN"]
const PEN_SCRATCH_KEYS := ["ruptures", "cutUm", "abrasionUm", "excoriation", "excoriationBleeds", "bleedPasses"]


# ── Parámetros ──

static func _entry(list: Array, id: String) -> Dictionary:
	var e: Variant = Catalog.find_by_id(list, id)
	assert(e != null, "no está en el catálogo: %s" % id)
	return e


## Parámetros de compute() a partir de ids: los del golden por defecto (uña almendra natural, arañazo de 25 mm, rayado,
## una pasada) con el modelo 2.0, y lo que traiga spec (ids de catálogo o valores).
static func Q(spec: Dictionary) -> Dictionary:
	var p := {
		"geom": _entry(Catalog.GEOMS, "almendra"), "base": _entry(Catalog.BASES, "natural"),
		"inlay": _entry(Catalog.INLAYS, "none"), "claw": null, "target": _entry(Catalog.TARGETS, "piel"),
		"type": _entry(Catalog.TYPES, "aranazo"), "force": 4.0, "length": 25.0, "tear": false, "method": "rayado",
		"strike": false, "passes": 1.0, "wet": false, "model": V2,
	}
	for k: String in spec:
		var v: Variant = spec[k]
		if k == "geom":
			p.geom = _entry(Catalog.GEOMS, v)
		elif k == "base":
			p.base = _entry(Catalog.BASES, v)
		elif k == "inlay":
			p.inlay = _entry(Catalog.INLAYS, v)
		elif k == "claw":
			p.claw = _entry(Catalog.CLAWS, v) if v != null else null
		elif k == "target":
			p.target = _entry(Catalog.TARGETS, v)
		else:
			p[k] = v
	return p


static func run(spec: Dictionary) -> Dictionary:
	return Physics.compute(Q(spec))


static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


static func _at(root: Variant, path: String) -> Variant:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not cur.has(key):
			return "<falta>"
		cur = cur[key]
	return cur


static func _label(spec: Dictionary) -> String:
	return JSON.stringify(spec)


# ── Casos de referencia (unidad 1g) ──

func test_los_casos_de_la_1g_con_el_compute_integrado() -> void:
	# cada caso de tests/fixtures/spec/pulido-biologia.json, con el compute() de la aplicación: su `expect` (en los cinco
	# que chocaban con los materiales de la 4a y en los dos del casuario con la patada de la 4i, el recalculado con la 2.0
	# entera; el de la 1g queda en expect1g)
	var cases: Array = load_json(SPEC)
	var passed := 0
	var failed: Array[String] = []
	for cs: Dictionary in cases:
		var inp: Dictionary = cs.input
		var spec := {}
		for k in ["geom", "base", "inlay", "claw", "target"]:
			spec[k] = inp.get(k)
		spec.merge({
			"type": _entry(Catalog.TYPES, inp.type), "force": float(inp.force), "length": float(inp.length), "tear": inp.tear,
			"method": inp.method, "strike": inp.strike, "passes": float(inp.passes), "wet": inp.wet, "model": inp.model,
		}, true)
		if inp.get("zone") != null:
			spec["zone"] = inp.zone
		if inp.get("attack_deg") != null:
			spec["attack_deg"] = float(inp.attack_deg)
		assert_eq(spec.model, V2, "%s: caso del modelo 2.0" % cs.id)
		var r := run(spec)
		var ok := true
		for field: String in cs.expect:
			var e: Dictionary = cs.expect[field]
			var got: Variant = _at(r, field)
			var good := true
			if e.has("value"):
				if e.has("tol"):
					good = is_num(got) and absf(float(got) - float(e.value)) <= float(e.tol) * absf(float(e.value))
				else:
					good = same(got, e.value)
			if e.has("min"):
				good = good and is_num(got) and float(got) >= float(e.min)
			if e.has("max"):
				good = good and is_num(got) and float(got) <= float(e.max)
			assert_true(good, "%s · %s: %s frente a %s" % [cs.id, field, show(got), JSON.stringify(e)])
			ok = ok and good
		if ok:
			passed += 1
		else:
			failed.append(cs.id)
		if cs.has("expect1g"):
			# recalculados con la 2.0 entera: los materiales (unidad 4b) o el golpe del casuario (la patada, unidad 4i)
			assert_true(String(cs.note).contains("4b") or String(cs.note).contains("4i"), "%s: el recálculo con la 2.0 entera está explicado en la nota" % cs.id)
	assert_eq(cases.size(), 47, "los 47 casos de la unidad 1g")
	assert_eq(passed, cases.size(), "casos que cumple el compute() integrado (fallan: %s)" % ", ".join(failed))
	print("    (info) casos de referencia de la biología: %d/%d con el compute() integrado" % [passed, cases.size()])


# ── Contrato de los campos ──

func test_los_campos_de_la_biologia_en_todos_los_ensayos() -> void:
	# existen en los dos modelos (a null en la 1.x); en la 2.0, zone y pen en la piel y tipHv, DpEff y faceDeg en los
	# sólidos; attackDeg siempre, salvo con un aguijón (solo pica)
	var tools := [{ "geom": "almendra" }, { "geom": "stiletto", "base": "metal" }, { "inlay": "diamante" },
		{ "claw": "gato" }, { "claw": "aguila", "inlay": "acero" }, { "claw": "vibora" }, { "claw": "gabon" },
		{ "claw": "abeja", "force": 0.00575 }]
	var modes := [{ "method": "rayado" }, { "method": "puncion" }, { "method": "puncion", "strike": true }]
	var places := [{ "target": "piel" }, { "target": "piel", "zone": "palma" }, { "target": "piel", "zone": "abdomen" },
		{ "target": "cobre" }, { "target": "coche" }, { "target": "vidrio" }, { "target": "madera", "attack_deg": 30.0 }]
	for t: Dictionary in tools:
		for m: Dictionary in modes:
			for pl: Dictionary in places:
				var spec := _with(_with({ "force": 8.0 }, t), _with(m, pl))
				var where := _label(spec)
				var r1 := run(_with(spec, { "model": V1 }))
				var r2 := run(spec)
				for k: String in ["zone", "pen", "tipHv", "DpEff", "faceDeg", "attackDeg"]:
					assert_true(Physics.V2_FIELDS.has(k), "%s en V2_FIELDS" % k)
					assert_true(r1.has(k) and r1[k] == null, "%s: %s a null en la 1.x" % [where, k])
					assert_true(r2.has(k), "%s: %s existe en la 2.0" % [where, k])
				var sting: bool = t.get("claw") == "abeja"
				var skin: bool = pl.target == "piel"
				if sting:
					assert_eq(r2.attackDeg, null, "%s: un aguijón solo pica" % where)
					assert_eq(r2.pen, null, "%s: el aguijón lleva su informe en sting" % where)
				else:
					assert_eq(r2.attackDeg, Physics.attack_deg(Q(spec)), "%s: el ángulo del ensayo" % where)
				if skin:
					assert_eq(r2.zone, Zones.resolve(pl.get("zone")).id, "%s: la zona" % where)
					assert_eq([r2.tipHv, r2.DpEff, r2.faceDeg], [null, null, null], "%s: en la piel no hay modo de abrasión" % where)
					if not sting:
						_check_pen(r2, where)
				else:
					assert_eq([r2.zone, r2.pen], [null, null], "%s: sin zona en un sólido" % where)
					if not sting:
						assert_true(is_num(r2.tipHv) and is_num(r2.DpEff) and is_num(r2.faceDeg), "%s: tipHv, DpEff y faceDeg" % where)
						assert_eq(r2.faceDeg, Attack.face_angle_deg(r2.alphaDeg, r2.attackDeg), "%s: la cara que avanza" % where)
						if not FangEnamel.applies(Physics.resolve_tool(Q(spec))):
							assert_eq(r2.tipHv, r2.hvTool, "%s: sin esmalte, la punta es la herramienta" % where)
						else:
							assert_true(r2.tipHv >= r2.hvTool and r2.tipHv <= FangEnamel.ENAMEL.hv, "%s: la punta, entre la dentina y el esmalte" % where)


func _check_pen(r: Dictionary, where: String) -> void:
	var pen: Variant = r.pen
	assert_true(pen is Dictionary, "%s: pen es el informe de penetration.gd" % where)
	if not (pen is Dictionary):
		return
	for k: String in PEN_KEYS:
		assert_true(pen.has(k), "%s: pen.%s" % [where, k])
	for k: String in PEN_PUNCTURE_KEYS if r.puncture else PEN_SCRATCH_KEYS:
		assert_true(pen.has(k), "%s: pen.%s" % [where, k])
	assert_eq([pen.zone, pen.depthUm, pen.layer, pen.bleeds, pen.fullReach], [r.zone, r.depthUm, r.layer, r.bleeds, r.fullReach],
		"%s: los campos de siempre salen del informe" % where)
	var bone: Variant = Zones.bone(r.zone)
	assert_eq(pen.boneDepthUm, bone.fromUm if bone != null else null, "%s: dónde está el hueso" % where)
	if r.puncture:
		assert_eq([r.workJ, r.toolBroken], [pen.workJ, pen.toolBroken], "%s: la punción da workJ y toolBroken (§9.3)" % where)


# ── Invariantes ──

func test_mas_fuerza_nunca_hunde_menos_en_ninguna_zona() -> void:
	var forces := [0.3, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0, 60.0, 120.0, 260.0, 500.0]
	var tools := [{ "claw": "gato" }, { "claw": "tigre" }, { "claw": "pajaro" }, { "claw": "casuario" }, { "claw": "vibora" },
		{ "claw": "gabon" }, { "geom": "almendra" }, { "geom": "stiletto", "base": "metal" }]
	var modes := [{ "method": "rayado" }, { "method": "rayado", "tear": true }, { "method": "puncion" },
		{ "method": "puncion", "strike": true }]
	var series := 0
	for zone: String in Zones.ids():
		for t: Dictionary in tools:
			for m: Dictionary in modes:
				if m.get("tear", false) and not t.has("claw"):
					continue
				series += 1
				var prev := -INF
				var prev_f := 0.0
				for f: float in forces:
					var spec := _with(_with(t, m), { "zone": zone, "force": f })
					var d: float = run(spec).depthUm
					assert_true(d >= prev * (1.0 - REL) - ABS_UM,
						"%s: con %s N hunde %s µm, menos que con %s N (%s µm)" % [_label(spec), f, d, prev_f, prev])
					prev = d
					prev_f = f
	assert_true(series >= 120, "series de fuerza: %d" % series)


func test_el_hueso_para_la_punta_sin_pasar_del_alcance() -> void:
	var tools := [{ "claw": "gato" }, { "claw": "tigre" }, { "claw": "oso" }, { "claw": "casuario" },
		{ "claw": "casuario", "inlay": "tungsteno" }, { "claw": "gato", "inlay": "diamante" }, { "claw": "vibora" },
		{ "claw": "gabon" }, { "geom": "stilettoxl", "base": "metal" }]
	var modes := [{ "method": "puncion" }, { "method": "puncion", "strike": true }, { "method": "rayado" },
		{ "method": "rayado", "tear": true }]
	var marked := 0
	var walls := 0
	for zone: String in Zones.ids():
		var bone: Variant = Zones.bone(zone)
		for t: Dictionary in tools:
			for m: Dictionary in modes:
				if m.get("tear", false) and not t.has("claw"):
					continue
				for f: float in [30.0, 260.0, 500.0, 2000.0]:
					var spec := _with(_with(t, m), { "zone": zone, "force": f })
					var where := _label(spec)
					var r := run(spec)
					var d: float = r.depthUm
					assert_true(d <= float(r.reachMm) * 1000.0 + ABS_UM, "%s: %s µm, más que el alcance" % [where, d])
					if bone == null:
						assert_false(r.pen.boneHit, "%s: sin hueso no hay nada que tocar" % where)
						continue
					if not r.puncture:
						assert_true(d <= float(bone.fromUm) + ABS_UM, "%s: el corte se para en el hueso (%s µm)" % [where, d])
						continue
					var pen: Dictionary = r.pen
					if not pen.bonePierced:
						assert_true(d <= float(bone.toUm) + ABS_UM, "%s: sin atravesar la cortical no pasa de ella" % where)
					assert_eq(pen.boneHit, d >= float(bone.fromUm) - ABS_UM, "%s: boneHit" % where)
					assert_near(float(pen.boneIndentUm), maxf(0.0, d - float(bone.fromUm)), 1e-12, 1e-9, "%s: lo que entra en el hueso" % where)
					var tool := Physics.resolve_tool(Q(spec))
					if not FangEnamel.applies(tool) and float(tool.hv) / float(bone.hv) < float(Pen.MODEL.boneMinRatio):
						# una punta más blanda que 1,25 veces el hueso no lo marca: la queratina topa con él (Richardson 1968)
						assert_eq(pen.boneIndentUm, 0.0, "%s: la punta blanda no marca el hueso" % where)
						if pen.boneHit:
							walls += 1
					if float(pen.boneIndentUm) >= Physics.BONE_MARK_UM:
						marked += 1
	assert_true(walls > 0 and marked > 0, "ensayos que topan con el hueso sin marcarlo (%d) y que lo marcan (%d)" % [walls, marked])


func test_la_grieta_y_el_roce_solo_frenan() -> void:
	# en el brazo (la pila de la 1.x), la grieta en todas las capas y el roce en los flancos añaden resistencia: la 2.0
	# nunca punza más hondo que la 1.x; y con más roce (ξ), nunca más hondo (Fregonese & Bacca 2022)
	var tools := [{ "claw": "gato" }, { "claw": "tigre" }, { "claw": "casuario" }, { "claw": "vibora" }, { "claw": "gabon" },
		{ "geom": "stiletto" }, { "geom": "almendra", "inlay": "diamante" }]
	for t: Dictionary in tools:
		for strike: bool in [false, true]:
			for f: float in [2.0, 4.0, 8.0, 30.0, 120.0]:
				var spec := _with(t, { "method": "puncion", "strike": strike, "force": f })
				var r2 := run(spec)
				var r1 := run(_with(spec, { "model": V1 }))
				assert_true(float(r2.depthUm) <= float(r1.depthUm) * (1.0 + REL) + ABS_UM,
					"%s: la 2.0 llega a %s µm y la 1.x a %s" % [_label(spec), r2.depthUm, r1.depthUm])
	for zone: String in Zones.ids():
		for claw: String in ["gato", "tigre", "vibora", "casuario"]:
			for strike: bool in [false, true]:
				for f: float in [2.0, 8.0, 30.0]:
					var spec := { "claw": claw, "zone": zone, "method": "puncion", "strike": strike, "force": f }
					var p := Q(spec)
					var r := Physics.compute(p)
					var tool := Physics.resolve_tool(p)
					var q := {
						"tool": tool, "tip": Contact.tip_geometry(tool.area, tool.alpha, tool.baseR), "zone": zone, "puncture": true,
						"strike": strike, "Neff": f + float(r.Fadh_mN) / 1000.0, "energyJ": r.energyJ,
					}
					var rep := Pen.skin_report(q)
					assert_eq(oracle_diff(r.pen, rep).size(), 0, "%s: pen es el informe de penetration.gd" % _label(spec))
					var d0: float = Pen.skin_report(_with(q, { "xi": 0.0 })).depthUm
					var d10: float = Pen.skin_report(_with(q, { "xi": 0.1 })).depthUm
					assert_true(float(rep.depthUm) <= d0 * (1.0 + REL) + ABS_UM, "%s: el roce no hunde más (%s > %s)" % [_label(spec), rep.depthUm, d0])
					assert_true(d10 <= float(rep.depthUm) * (1.0 + REL) + ABS_UM, "%s: más roce, no más hondo" % _label(spec))


func test_tumbar_la_herramienta_nunca_corta_mas() -> void:
	# el ángulo de ataque gira la cara que avanza (θ = ataque − α): con una garra, la profundidad no cambia y, de gancho
	# (170°) a tumbada (10°), Dp_ef, la fracción arrancada y la fricción de arado nunca suben (Hokkirigawa & Kato 1988)
	var angles := [170.0, 150.0, 120.0, 105.0, 90.0, 75.0, 60.0, 45.0, 30.0, 20.0, 10.0]
	var seen := {}
	for t: Dictionary in [{ "claw": "gato" }, { "claw": "tigre" }, { "claw": "oso" }, { "claw": "aguila", "inlay": "acero" }]:
		for target: String in ["plastico", "madera", "cobre", "coche", "puertametal"]:
			for f: float in [5.0, 30.0, 110.0]:
				var ref := run(_with(t, { "target": target, "force": f }))
				var prev: Variant = null
				for a: float in angles:
					var spec := _with(t, { "target": target, "force": f, "attack_deg": a })
					var r := run(spec)
					var where := _label(spec)
					assert_eq([r.verdict, r.depthUm], [ref.verdict, ref.depthUm], "%s: el ataque no cambia el surco" % where)
					if r.absMode != null:
						seen[r.absMode] = true
					if prev != null:
						assert_true(float(r.DpEff) <= float(prev.DpEff) * (1.0 + REL), "%s: Dp_ef sube al tumbarla" % where)
						assert_true(float(r.fab) <= float(prev.fab) + 1e-12, "%s: arranca más al tumbarla" % where)
						assert_true(float(r.muPlough) <= float(prev.muPlough) + 1e-12, "%s: ara más al tumbarla" % where)
					prev = r
				var at90 := run(_with(t, { "target": target, "force": f, "attack_deg": 90.0 }))
				for k in ["absMode", "fab", "muPlough", "muEff", "Ffric", "wearIdx", "Dp"]:
					assert_eq(at90[k], ref[k], "%s: una garra va de punta por defecto (90°) · %s" % [_label(t), k])
				assert_eq(ref.DpEff, ref.Dp, "a 90°, el Dp de la 1.x")
	assert_true(seen.has("corte") and seen.has("cuña") and seen.has("arado"), "modos vistos al tumbar las garras: %s" % [seen.keys()])


func test_entre_90_y_atan_mu_tumbar_la_una_no_la_deja_aguantar_mas() -> void:
	# la placa de la uña recibe F⊥ = N·(cos β + μ·sen β) (bending.gd): entre 90° y atan μ, tumbarla deja la reacción más
	# perpendicular a la placa, que se dobla ANTES. Así que tumbarla nunca le deja aguantar más carga ni hundir más; y,
	# con la misma carga en la punta (la uña no cede en ninguno de los dos ángulos), nunca corta más. Si cede, el surco
	# es más somero y puede quedarse en el casquete esférico de la punta, que no gira al tumbarla (attack.gd): ahí Dp_ef
	# es el de la esfera y puede subir aunque la uña esté más tumbada. (Por debajo de atan μ la flexión vuelve a bajar
	# hasta N con β → 0: ahí no se exige nada.)
	var same_load := 0
	for g: String in ["almendra", "stiletto", "cuadrada", "stilettoxl"]:
		for target: String in ["piel", "madera", "plastico", "coche", "vidrio"]:
			for f: float in [4.0, 15.0, 30.0]:
				var mu: float = _entry(Catalog.TARGETS, target).mu
				var lo := V8.js_atan2(mu, 1.0) / Contact.DEG
				var prev: Variant = null
				for a: float in [90.0, 80.0, 70.0, 60.0, 50.0, 45.0, 40.0, 35.0, 30.0, 27.0]:
					if a < lo:
						break
					var spec := { "geom": g, "target": target, "force": f, "attack_deg": a }
					var r := run(spec)
					var where := _label(spec)
					assert_true(r.nail is Dictionary, "%s: la uña se evalúa" % where)
					if prev != null:
						assert_true(float(r.nail.breakN) <= float(prev.nail.breakN) * (1.0 + REL), "%s: tumbada aguanta más" % where)
						assert_true(float(r.depthUm) <= float(prev.depthUm) * (1.0 + REL) + ABS_UM, "%s: tumbada hunde más" % where)
						if r.get("DpEff") != null and prev.get("DpEff") != null and not r.nail.broken and not prev.nail.broken:
							same_load += 1
							assert_true(float(r.DpEff) <= float(prev.DpEff) * (1.0 + REL), "%s: con la misma carga, tumbada corta más" % where)
					prev = r
	assert_true(same_load >= 50, "pares de ángulos con la misma carga en la punta: %d" % same_load)
	# y de gancho la uña se dobla menos que tumbada a 45°: el caso de la guía (uña cuadrada de 30 N sobre el pino)
	var hook := run({ "geom": "cuadrada", "target": "madera", "force": 30.0, "attack_deg": 150.0 })
	var flat := run({ "geom": "cuadrada", "target": "madera", "force": 30.0, "attack_deg": 45.0 })
	assert_true(float(hook.nail.breakN) > float(flat.nail.breakN), "de gancho aguanta más que a 45°")
	assert_false(hook.nail.broken, "a 150° la cuadrada aguanta los 30 N (cede a ~%s N)" % Js.to_fixed(hook.nail.breakN, 1))


func test_la_una_con_gema_mojada_se_dobla_con_la_queratina_mojada() -> void:
	# la gema no se ablanda (la dureza del contacto es la suya, como en la 1.x), pero la placa de queratina que la lleva sí
	# (×0,2, Farran 2009): la uña con gema mojada cede con la resistencia de la queratina mojada
	for inlay: String in ["diamante", "zafiro", "cuarzo", "acero"]:
		for g: String in ["almendra", "stiletto", "cuadrada"]:
			for target: String in ["vidrio", "piel", "madera"]:
				var spec := { "geom": g, "inlay": inlay, "target": target, "force": 10.0 }
				var dry := run(spec)
				var wet := run(_with(spec, { "wet": true }))
				var where := _label(spec)
				assert_near(float(wet.nail.breakN), float(dry.nail.breakN) * Bending.WET_STRENGTH, 1e-12, 0.0, "%s: la placa mojada" % where)
				assert_eq(wet.hvTool, dry.hvTool, "%s: la gema no se ablanda" % where)
				assert_true(float(wet.depthUm) <= float(dry.depthUm) * (1.0 + REL) + ABS_UM, "%s: mojada no hunde más" % where)
	# la misma placa que una uña natural mojada del mismo largo; y una base que no es queratina no se ablanda
	var nat := run({ "geom": "almendra", "target": "vidrio", "force": 10.0, "wet": true })
	var gem := run({ "geom": "almendra", "inlay": "diamante", "target": "vidrio", "force": 10.0, "wet": true })
	if float(nat.reachMm) == float(gem.reachMm):
		assert_near(float(gem.nail.breakN), float(nat.nail.breakN), 1e-12, 0.0, "la misma placa de queratina mojada")
	for base: String in ["gel", "acrilico", "metal", "titanio"]:
		var spec := { "geom": "almendra", "base": base, "inlay": "diamante", "target": "vidrio", "force": 10.0 }
		assert_eq(run(_with(spec, { "wet": true })).nail.breakN, run(spec).nail.breakN, "%s: mojada no cambia" % base)
	# el caso del golden: 10 N con diamante sobre el vidrio raya en seco y, mojada, la uña se dobla a ~3.4 N
	var g_dry := run({ "inlay": "diamante", "target": "vidrio", "force": 10.0 })
	var g_wet := run({ "inlay": "diamante", "target": "vidrio", "force": 10.0, "wet": true })
	assert_eq([g_dry.verdict, g_wet.verdict], ["RAYA", "SE DOBLA LA UÑA"])
	assert_true(String(g_wet.vsub).begins_with("la uña se dobla a ~3.4 N"), g_wet.vsub)


# ── Ángulo de ataque, textos y piezas ──

func test_angulo_de_ataque_por_defecto_y_acotado() -> void:
	assert_eq(Physics.attack_deg({}), 45.0, "uñas: 45°, estimación (Holz & Baudisch 2010)")
	assert_eq(Physics.attack_deg({ "claw": _entry(Catalog.CLAWS, "gato") }), 90.0, "garras: de punta, como la 1.x")
	assert_eq(Physics.attack_deg({ "claw": _entry(Catalog.CLAWS, "vibora") }), 90.0, "colmillos, igual")
	assert_eq(Physics.attack_deg({ "attack_deg": 5.0 }), Attack.MIN_DEG, "acotado al deslizador")
	assert_eq(Physics.attack_deg({ "attack_deg": 200.0 }), Attack.MAX_DEG)
	assert_eq(Physics.attack_deg({ "claw": _entry(Catalog.CLAWS, "gato"), "attack_deg": 30.0 }), 30.0, "el del usuario manda")
	assert_eq(Bending.ATTACK_DEG, Attack.NAIL_DEG, "un solo ángulo por defecto para la uña")
	for kind: String in Attack.DEFAULTS:
		var d: Dictionary = Attack.DEFAULTS[kind]
		assert_eq(d.quality, "estimate", "%s: el ángulo por defecto es una estimación" % kind)
		assert_true(String(d.source).length() > 40, "%s: con su razonamiento" % kind)
	assert_eq([Attack.kind_of(null), Attack.kind_of(_entry(Catalog.CLAWS, "tigre"))], ["uña", "garra"])
	# el mismo ángulo flexa la uña y decide el modo de abrasión, y el subtítulo lo cuenta
	var r := run({ "geom": "stiletto", "target": "madera", "force": 30.0, "attack_deg": 20.0 })
	assert_eq([r.attackDeg, r.faceDeg], [20.0, Attack.face_angle_deg(r.alphaDeg, 20.0)])
	assert_eq(r.nail.factor, Bending.bend_factor(20.0, float(r.mu), true), "la uña se flexa con el mismo ángulo")
	assert_true(String(r.vsub).contains("ataque de 20°"), r.vsub)
	assert_eq(r.absMode, "arado", "tumbada a 20°, la stiletto ara el pino (guía §5)")


func test_de_gancho_la_una_se_dobla_por_el_valor_absoluto() -> void:
	# hasta 90°, la fórmula de la unidad 4a al bit
	for a: float in [10.0, 30.0, 45.0, 60.0, 89.0, 90.0]:
		for mu: float in [0.0, 0.3, 0.5, 0.9]:
			for sliding: bool in [true, false]:
				var b := a * Contact.DEG
				assert_eq(Bending.bend_factor(a, mu, sliding), V8.js_cos(b) + (mu * V8.js_sin(b) if sliding else 0.0),
					"%s° μ %s" % [a, mu])
	# de gancho la proyección cambia de signo: cuenta su valor absoluto, que se anula donde la reacción va a lo largo de la
	# placa (90° + atan μ)
	var zero := 90.0 + V8.js_atan2(0.5, 1.0) / Contact.DEG
	assert_near(Bending.bend_factor(zero, 0.5, true), 0.0, 0.0, 1e-12, "sin flexión a 90° + atan μ")
	var b150 := 150.0 * Contact.DEG
	assert_eq(Bending.bend_factor(150.0, 0.5, true), absf(V8.js_cos(b150) + 0.5 * V8.js_sin(b150)))
	assert_true(Bending.bend_factor(150.0, 0.5, true) > 0.0 and Bending.bend_factor(150.0, 0.5, true) < Bending.bend_factor(45.0, 0.5, true))


func test_una_una_que_golpea_cede_con_su_carga_de_flexion() -> void:
	# yieldN (penetration.gd): la carga con que cede una herramienta sin romperse, la de una uña que se dobla (bending.gd);
	# como la rotura del colmillo, pero entera. El mecanismo, con una punta larga que empuja 10 N en el abdomen (perfora
	# con 8,8 N y se para en la cavidad, a ~39 mm, por la fuerza):
	var p := Q({ "claw": "casuario", "force": 10.0, "method": "puncion", "zone": "abdomen" })
	var tool := Physics.resolve_tool(p)
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	var base := { "tool": tool, "tip": tip, "zone": "abdomen", "force": 10.0, "strike": false }
	var free := Pen.puncture(base)
	assert_eq([free.pierces, free.yielded, free.stoppedBy, free.demandN], [true, false, "fuerza", 10.0], "sin tope")
	var f_p: float = free.fPuncture
	assert_true(f_p < 10.0, "perfora: %s N" % f_p)
	var low := Pen.puncture(_with(base, { "yieldN": f_p * 0.5 }))
	assert_eq([low.pierces, low.depthUm, low.stoppedBy, low.yielded], [false, 0.0, "sin perforar", false], "cede antes de romper la piel")
	var y := (f_p + 10.0) / 2.0
	var mid := Pen.puncture(_with(base, { "yieldN": y }))
	assert_eq([mid.pierces, mid.yielded, mid.stoppedBy, mid.toolBroken], [true, true, "cede", false])
	assert_eq([mid.toolLoadN, mid.demandN], [y, 10.0], "a la punta llega la carga de cesión; el camino pedía el empuje")
	var rig := Pen.make_rig(tip, tool, Zones.stack("abdomen"), Zones.bone("abdomen"), float(Pen.MODEL.flankFriction), float(tool.reach))
	assert_near(float(mid.depthUm), Pen.first_crossing(rig, y, float(tool.reach)) * 1000.0, 1e-12, 1e-9, "se queda donde la resistencia llega a ella")
	assert_true(float(mid.depthUm) < float(free.depthUm), "cediendo se queda antes (%s < %s µm)" % [mid.depthUm, free.depthUm])
	var high := Pen.puncture(_with(base, { "yieldN": 20.0 }))
	assert_eq(oracle_diff(high, free).size(), 0, "con un tope que no se alcanza, lo mismo que sin él")
	# una uña que golpea: si cede antes de la fuerza que rompe la piel (Davis 2004), no la perfora ni de un golpe
	var sp := Q({ "geom": "stiletto", "force": 30.0, "method": "puncion", "strike": true })
	var st := Physics.resolve_tool(sp)
	var hit := {
		"tool": st, "tip": Contact.tip_geometry(st.area, st.alpha, st.baseR), "zone": "brazo", "force": 30.0, "strike": true,
		"energyJ": Physics.compute(sp).energyJ,
	}
	var hit_fp: float = Pen.puncture(hit).fPuncture
	assert_true(Pen.puncture(hit).pierces and not Pen.puncture(_with(hit, { "yieldN": hit_fp * 0.9 })).pierces,
		"la uña que cede antes de romper la piel no la perfora de un golpe")
	# en compute(): la uña que golpea la piel cede exactamente cuando el informe dice que ha cedido
	for g: String in ["almendra", "stiletto", "stilettoxl", "cuadrada"]:
		for f: float in [4.0, 30.0, 120.0]:
			for zone: String in Zones.ids():
				var r := run({ "geom": g, "force": f, "method": "puncion", "strike": true, "zone": zone })
				if r.pen.pierces:
					assert_eq(r.pen.yielded, r.nail.broken, "%s %s N en %s: pen.yielded y la uña" % [g, f, zone])


func test_textos_de_los_veredictos_nuevos() -> void:
	# docs/fisica/pulido-biologia.md §9.5, con los números de los casos de referencia
	var cases := [
		[{ "claw": "pajaro", "force": 1.5, "zone": "palma" }, "CALLO PULIDO", "pule la capa córnea de la palma (~75 µm de 173): no sangra"],
		[{ "claw": "casuario", "force": 500.0, "method": "puncion", "strike": true }, "PUNCIÓN HASTA EL HUESO",
			"la punta topa con el húmero a ~41.4 mm y no lo marca"],
		[{ "claw": "vibora", "method": "puncion", "zone": "cara" }, "SE CLAVA EN EL HUESO",
			"entra ~15 µm en el hueso cigomático, a ~8.7 mm de la superficie; deja el veneno junto al hueso"],
		# (unidad 4i: con la patada del casuario de la 2.0, la daga acaba a 60,6 mm; con los 160 J de la 1.x, a 65,1; unidad 4i-B2:
		# con la hembra de 58 kg del coche en marcha, ~88 J, a 60,4 mm)
		[{ "claw": "casuario", "inlay": "tungsteno", "force": 500.0, "method": "puncion", "strike": true }, "ATRAVIESA EL HUESO",
			"atraviesa los 4.4 mm de cortical del húmero y acaba en la médula (~60.4 mm)"],
		[{ "claw": "vibora", "method": "puncion", "strike": true, "zone": "dorsomano" }, "SE ROMPE EL COLMILLO",
			"llega al tercer metacarpiano a ~5.6 mm y el colmillo cede a ~30 N: el veneno se queda a ~5.7 mm"],
		[{ "claw": "gabon", "force": 30.0, "method": "puncion", "strike": true, "zone": "abdomen" }, "HERIDA PENETRANTE",
			"pasa la pared del abdomen (~26.7 mm) y llega a ~50.0 mm, dentro de la cavidad; deja el veneno dentro"],
		[{ "claw": "tigre", "force": 260.0, "zone": "dorsomano" }, "LACERACIÓN HASTA EL HUESO", "corta hasta el tercer metacarpiano (~5.6 mm)"],
		[{ "claw": "tigre", "force": 260.0, "zone": "dorsomano", "tear": true }, "DESGARRO HASTA EL HUESO",
			"la garra engancha y rasga: corta hasta el tercer metacarpiano (~5.6 mm)"],
		[{ "claw": "tigre", "force": 260.0, "zone": "abdomen" }, "HERIDA PENETRANTE",
			"abre la pared del abdomen (~26.7 mm) y llega a ~40.0 mm, dentro de la cavidad"],
	]
	for c: Array in cases:
		var r := run(c[0])
		assert_eq([r.verdict, r.vsub], [c[1], c[2]], _label(c[0]))
	# ninguna contracción rota («a el», «de el») en los subtítulos de la piel de ninguna zona
	for zone: String in Zones.ids():
		for claw: String in ["gato", "tigre", "oso", "casuario", "vibora", "gabon"]:
			for m: Dictionary in [{ "method": "puncion" }, { "method": "puncion", "strike": true }, { "method": "rayado", "tear": true }]:
				for f: float in [4.0, 260.0, 2000.0]:
					var r := run(_with(m, { "claw": claw, "force": f, "zone": zone }))
					var sub := " " + String(r.vsub) + " "
					assert_false(sub.contains(" a el ") or sub.contains(" de el "), "%s %s: «%s»" % [claw, zone, r.vsub])


func test_los_aguijones_pican_en_la_zona() -> void:
	# docs/fisica/pulido-biologia.md §9.9: la fuerza para perforar no cambia (la capa de arriba es la misma), pero el
	# aguijón de la abeja (1,32 mm) deja el veneno en la dermis del brazo y en la grasa de la palma (su dermis es más fina)
	var arm := run({ "claw": "abeja", "force": 0.00575, "method": "puncion" })
	var palm := run({ "claw": "abeja", "force": 0.00575, "method": "puncion", "zone": "palma" })
	assert_eq([arm.zone, arm.layer], ["brazo", "Dermis"])
	assert_eq([palm.zone, palm.layer], ["palma", "Hipodermis (grasa)"])
	assert_eq(palm.fPuncture, arm.fPuncture, "la misma fuerza para perforar")
	assert_eq(palm.sev, maxf(0.3, Zones.severity("palma", palm.depthUm)), "la severidad, la de la zona")


func test_zona_y_angulo_en_el_estado_del_banco() -> void:
	var lab: RefCounted = LabState.new()
	lab.model = V2
	assert_eq([lab.zone, lab.attack_deg, lab.attack()], [Zones.DEFAULT_ID, null, 45.0], "por defecto, el brazo y la uña a 45°")
	assert_eq(lab.attack_default().value, Attack.NAIL_DEG)
	lab.set_zone("palma")
	assert_eq([lab.params().zone, lab.zone_info().id], ["palma", "palma"])
	lab.set_zone("rodilla")
	assert_eq(lab.zone, Zones.DEFAULT_ID, "una zona desconocida: el brazo")
	lab.set_attack_deg(5.0)
	assert_eq([lab.attack_deg, lab.attack(), lab.params().attack_deg], [Attack.MIN_DEG, Attack.MIN_DEG, Attack.MIN_DEG])
	lab.set_attack_deg(null)
	assert_eq(lab.attack(), 45.0, "null: el de la herramienta")
	lab.set_attack_deg(30.0)
	lab.set_claw(_entry(Catalog.CLAWS, "gato"))
	assert_eq([lab.attack_deg, lab.attack()], [null, 90.0], "de uña a garra, el ángulo vuelve al de la garra")
	lab.set_attack_deg(120.0)
	lab.set_claw(_entry(Catalog.CLAWS, "tigre"))
	assert_eq(lab.attack(), 120.0, "de garra a garra se conserva")
	lab.set_claw(null)
	assert_eq(lab.attack(), 45.0)
	# el ensayo del banco lleva la zona y el cuaderno la nombra si no es la de siempre
	lab.set_target(_entry(Catalog.TARGETS, "piel"))
	lab.set_zone("palma")
	lab.run()
	assert_eq([lab.res.zone, lab.notebook[0].tgt], ["palma", "Piel · Palma"])
	lab.set_zone("brazo")
	lab.run()
	assert_eq([lab.res.zone, lab.notebook[0].tgt], ["brazo", "Piel"])
	lab.set_model(V1)
	lab.set_zone("palma")
	lab.run()
	assert_eq([lab.res.zone, lab.notebook[0].tgt], [null, "Piel"], "la 1.x no tiene zonas")


func test_tiempo_de_compute_en_la_piel() -> void:
	# informativo: lo que cuesta la piel de la 2.0 (la punción por capas es la parte cara) frente a la 1.x
	var trials := {
		"punción": { "claw": "vibora", "method": "puncion" },
		"golpe": { "claw": "gabon", "force": 30.0, "method": "puncion", "strike": true },
		"rayado": { "claw": "gato", "force": 15.0 },
	}
	var parts: Array[String] = []
	for name: String in trials:
		var line := name
		for model: String in [V1, V2]:
			var p := Q(_with(trials[name], { "model": model }))
			Physics.compute(p)
			var t0 := Time.get_ticks_usec()
			for i in 20:
				Physics.compute(p)
			var us := float(Time.get_ticks_usec() - t0) / 20.0
			assert_true(us > 0.0)
			line += " %s %s µs" % [model, Js.to_fixed(us, 0)]
		parts.append(line)
	print("    (info) compute() en la piel del brazo: " + " · ".join(parts))
