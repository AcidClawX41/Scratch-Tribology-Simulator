## El afilado de las garras reforjadas en el banco (modelo 2.0; unidad 4i, docs/fisica/velociraptor.md §3 y §10.2):
##   - p.sharpness (0-1) solo afila una garra o un colmillo reforjados (Physics.sharpenable): resolve_tool cambia el área
##     y el radio de la punta (ClawSharpness.sharpen) y el resto del motor es el de siempre;
##   - con s = 0 (o sin el parámetro) el ensayo es el de siempre, al bit, en los escenarios del golden 2.0 y en una
##     rejilla de garras reforjadas, objetivos y métodos; y en la 1.x el parámetro no existe;
##   - el campo `sharpness` del resultado es ClawSharpness.tradeoff con la resistencia de claw_fracture.gd (unidad 4d), la
##     fricción del motor (al rayar, la del material; al punzar, ninguna) y la carga que llega a la punta, y la interfaz
##     (Physics.sharpness_report) ve lo mismo antes de ensayar;
##   - invariantes: más afilado nunca da menos hondura con la misma fuerza, y una punta más afilada nunca aguanta más carga
##     lateral (frágiles y dúctiles).
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Contact = preload("res://core/shared/contact.gd")
const Format = preload("res://core/shared/format.gd")
const GoldenV2 = preload("res://tools/golden_v2.gd")

const V1 := Physics.MODEL_V1
const V2 := Physics.MODEL_V2
## Holgura de «nunca menos hondo» (relativa y en µm): la de las bisecciones de los resolvedores.
const REL := 1e-9
const ABS_UM := 1e-6
const METHODS := [["rayado", false], ["puncion", false], ["puncion", true]]
## Materiales frágiles (se mellan con su resistencia a flexión) y dúctiles (se doblan con H/2,8), los de claw_fracture.gd.
const BRITTLE := ["tungsteno", "diamante", "zafiro", "moissanita", "circonita", "cuarzo", "vidrio", "swarovski"]
const DUCTILE := ["acero", "titanio", "oro"]


static func K(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Parámetros de compute() con los del golden por defecto y lo que traiga spec (entradas del catálogo, no ids).
static func P(spec: Dictionary) -> Dictionary:
	var p := {
		"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": null, "target": T("acero"),
		"type": Catalog.TYPES[1], "force": 20.0, "length": 25.0, "tear": false, "method": "rayado", "strike": false,
		"passes": 1.0, "wet": false, "model": V2,
	}
	p.merge(spec, true)
	return p


static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


## ¿Idénticos al bit? (same() de case.gd, con el signo de los ceros)
static func identical(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not identical(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not identical(a[i], b[i]):
				return false
		return true
	if is_num(a) and is_num(b) and float(a) == 0.0 and float(b) == 0.0:
		return signf(1.0 / float(a)) == signf(1.0 / float(b))
	return same(a, b)


# ── Quién se afila ──

func test_solo_se_afilan_las_garras_y_colmillos_reforjados() -> void:
	assert_true(Physics.sharpenable(P({ "claw": K("velociraptor"), "inlay": I("diamante") })), "velocirraptor de diamante")
	assert_true(Physics.sharpenable(P({ "claw": K("tigre"), "inlay": I("acero") })), "tigre de acero")
	assert_true(Physics.sharpenable(P({ "claw": K("vibora"), "inlay": I("zafiro") })), "colmillo reforjado")
	assert_false(Physics.sharpenable(P({ "claw": K("velociraptor") })), "la garra de queratina: su punta es la de la ficha")
	assert_false(Physics.sharpenable(P({ "inlay": I("diamante") })), "una uña con gema no es una garra")
	assert_false(Physics.sharpenable(P({ "claw": K("abeja"), "inlay": I("acero") })), "un aguijón tiene su punta medida")
	assert_false(Physics.sharpenable(P({ "claw": K("tigre"), "inlay": I("acero"), "model": V1 })), "en la 1.x no existe")
	assert_eq(Physics.sharpness_of(P({ "claw": K("tigre"), "inlay": I("acero"), "sharpness": 1.7 })), 1.0, "se acota a [0, 1]")
	assert_eq(Physics.sharpness_of(P({ "claw": K("tigre"), "inlay": I("acero"), "sharpness": -0.2 })), 0.0)
	assert_eq(Physics.sharpness_of(P({ "claw": K("tigre"), "sharpness": 0.5 })), 0.0, "sin reforjar, nada")


func test_la_herramienta_afilada_solo_cambia_la_punta() -> void:
	for id: String in ["velociraptor", "gato", "oso", "casuario", "vibora"]:
		for mat: String in ["diamante", "acero"]:
			var base := P({ "claw": K(id), "inlay": I(mat) })
			var t0 := Physics.resolve_tool(base)
			for s: float in [0.1, 0.5, 1.0]:
				var t := Physics.resolve_tool(_with(base, { "sharpness": s }))
				var r0 := ClawSharpness.radius_um_of_area(float(K(id).area))
				var want_r := ClawSharpness.radius_at(r0, s)
				assert_eq(float(t.tipRadiusUm), want_r, "%s de %s, s = %s: el radio de ClawSharpness.radius_at" % [id, mat, s])
				assert_eq(float(t.area), ClawSharpness.area_of_radius_um(want_r), "%s: el área de ese radio" % id)
				assert_true(float(t.area) < float(t0.area), "%s: la punta afilada es más pequeña" % id)
				for k: String in t0:
					if k != "area" and k != "tipRadiusUm":
						assert_true(identical(t[k], t0[k]), "%s de %s, s = %s: %s no cambia" % [id, mat, s, k])


# ── Sin afilar, el de siempre, al bit ──

func test_sin_afilar_el_ensayo_es_el_de_siempre_al_bit() -> void:
	# los escenarios del golden 2.0 (con sus garras reforjadas), con s = 0 y sin el parámetro
	var n := 0
	for sc: Dictionary in GoldenV2.scenarios():
		var q: Dictionary = GoldenV2.compute_params(sc.params)
		var plain := q.duplicate()
		plain.erase("sharpness")
		var a := Physics.compute(plain)
		var b := Physics.compute(_with(plain, { "sharpness": 0.0 }))
		assert_true(identical(a, b), "«%s»: con s = 0, el mismo resultado al bit" % sc.name)
		assert_true(identical(Physics.resolve_tool(plain), Physics.resolve_tool(_with(plain, { "sharpness": 0.0 }))), "«%s»: la misma herramienta" % sc.name)
		n += 1
	# y una rejilla de garras reforjadas, objetivos y métodos
	for id: String in ["velociraptor", "tigre", "aguila", "vibora"]:
		for mat: String in ["tungsteno", "zafiro", "acero", "hematites"]:
			for tid: String in ["piel", "coche", "acero", "vidrio", "ventanilla", "puertamadera"]:
				for m: Array in METHODS:
					var q := P({ "claw": K(id), "inlay": I(mat), "target": T(tid), "method": m[0], "strike": m[1], "force": 60.0 })
					var a := Physics.compute(q)
					assert_true(identical(a, Physics.compute(_with(q, { "sharpness": 0.0 }))), "%s de %s → %s %s: s = 0 al bit" % [id, mat, tid, m])
					n += 1
	assert_true(n > 250, "ensayos comparados: %d" % n)


func test_la_1x_y_las_demas_herramientas_no_ven_el_afilado() -> void:
	var cases := [
		{ "claw": K("velociraptor") }, { "inlay": I("diamante") }, { "geom": Catalog.GEOMS[0] },
		{ "claw": K("abeja"), "inlay": I("acero"), "force": 0.5, "method": "puncion" },
		{ "claw": K("tigre"), "inlay": I("diamante"), "model": V1 },
	]
	for spec: Dictionary in cases:
		for tid: String in ["piel", "acero", "coche"]:
			var q := _with(P(spec), { "target": T(tid) })
			var a := Physics.compute(q)
			var b := Physics.compute(_with(q, { "sharpness": 0.8 }))
			assert_true(identical(a, b), "%s → %s: el afilado no cambia nada" % [JSON.stringify(spec.keys()), tid])
			assert_true(a.has("sharpness") and a.sharpness == null, "%s → %s: sharpness existe y es null" % [JSON.stringify(spec.keys()), tid])


# ── El campo del resultado ──

func test_el_campo_sharpness_es_el_compromiso_de_claw_sharpness() -> void:
	var raptor := K("velociraptor")
	for mat: String in BRITTLE + DUCTILE + ["hematites"]:
		for tid: String in ["acero", "coche", "vidrio", "madera"]:
			for s: float in [0.0, 0.5]:
				var q := P({ "claw": raptor, "inlay": I(mat), "target": T(tid), "force": 381.5, "sharpness": s })
				var r := Physics.compute(q)
				var sh: Variant = r.sharpness
				assert_true(sh is Dictionary, "%s → %s: con una garra reforjada hay compromiso" % [mat, tid])
				if not (sh is Dictionary):
					continue
				var prof := Physics.hardness_profile(T(tid))
				var want := ClawSharpness.tradeoff(Velociraptor_r0(), float(raptor.alpha), s, float(I(mat).E), ClawFracture.strength(mat), 381.5,
					float(T(tid).mu), float(prof.Esurf), float(prof.Hsurf))
				for k: String in want:
					assert_true(identical(sh[k], want[k]), "%s → %s, s = %s: %s como ClawSharpness.tradeoff" % [mat, tid, s, k])
				assert_eq([sh.material, sh.mu, sh.forceN], [mat, float(T(tid).mu), 381.5], "%s: material, μ del motor y carga en la punta" % mat)
				assert_eq(float(sh.tipRadiusUm), float(r.tipRadiusUm), "%s: el radio del campo es el de la punta del ensayo" % mat)
				var st: Variant = ClawFracture.strength(mat)
				assert_eq(sh.kind, st.kind if st != null else null, "%s: frágil o dúctil (claw_fracture.gd)" % mat)
				if st == null:
					assert_eq(sh.fracture.mode, "sin_datos", "%s: sin resistencia medida no se predice" % mat)
	# al punzar no hay carga lateral; al golpear, la carga es la del camino (la que da la abolladura o la punción)
	var punz := Physics.compute(P({ "claw": raptor, "inlay": I("diamante"), "method": "puncion", "force": 381.5, "sharpness": 0.5 }))
	assert_eq([punz.sharpness.mu, punz.sharpness.lateralN, punz.sharpness.survives], [0.0, 0.0, true], "de frente no se mella")
	# en la piel manda la grieta: sin presión de Hertz ni hondura plástica, pero con la carga lateral al rayar
	var skin := Physics.compute(P({ "claw": raptor, "inlay": I("diamante"), "target": T("piel"), "force": 50.0, "sharpness": 0.5 }))
	assert_eq([skin.sharpness.p0MPa, skin.sharpness.depthUm], [null, null], "piel: sin Hertz ni hondura plástica")
	assert_eq(float(skin.sharpness.lateralN), 0.5 * 50.0, "piel: μ·F")
	# la interfaz ve lo mismo antes de ensayar (Physics.sharpness_report, sin golpe)
	for tid: String in ["acero", "piel", "coche"]:
		for m: String in ["rayado", "puncion"]:
			for tear: bool in [false, true]:
				var q := P({ "claw": K("tigre"), "inlay": I("zafiro"), "target": T(tid), "method": m, "tear": tear, "force": 120.0, "sharpness": 0.4 })
				assert_true(identical(Physics.sharpness_report(q), Physics.compute(q).sharpness), "%s %s%s: el informe es el del ensayo" % [tid, m, " (desgarro)" if tear else ""])


static func Velociraptor_r0() -> float:
	return ClawSharpness.radius_um_of_area(float(K("velociraptor").area))


# ── Invariantes ──

func test_mas_afilado_nunca_da_menos_hondura_con_la_misma_fuerza() -> void:
	var targets: Array = Catalog.TARGETS.filter(func(t: Dictionary) -> bool: return t.id != "cuticula")
	var tools := [["velociraptor", "diamante"], ["velociraptor", "acero"], ["gato", "tungsteno"], ["oso", "cuarzo"], ["vibora", "zafiro"]]
	var steps := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
	var n := 0
	for tl: Array in tools:
		for t: Dictionary in targets:
			for m: Array in METHODS:
				for f: float in [5.0, 300.0]:
					var prev := -1.0
					var prev_s := 0.0
					for s: float in steps:
						var q := P({ "claw": K(tl[0]), "inlay": I(tl[1]), "target": t, "method": m[0], "strike": m[1], "force": f, "sharpness": s })
						var d: float = Physics.compute(q).depthUm
						n += 1
						if prev >= 0.0:
							assert_true(d >= prev * (1.0 - REL) - ABS_UM, "%s de %s → %s %s a %s N: s = %s da %s µm, menos que %s µm con s = %s" % [
								tl[0], tl[1], t.id, m, f, s, d, prev, prev_s])
						prev = d
						prev_s = s
	assert_true(n > 3000, "ensayos: %d" % n)


func test_una_punta_mas_afilada_nunca_aguanta_mas_de_lado() -> void:
	for mat: String in BRITTLE + DUCTILE:
		for id: String in ["velociraptor", "gato", "oso"]:
			var prev := INF
			for i in 11:
				var s := float(i) / 10.0
				var q := P({ "claw": K(id), "inlay": I(mat), "target": T("acero"), "force": 100.0, "sharpness": s })
				var sh: Dictionary = Physics.compute(q).sharpness
				var chip: float = sh.chipN
				assert_true(chip <= prev, "%s de %s: con s = %s aguanta %s N de lado, más que con menos afilado (%s N)" % [id, mat, s, chip, prev])
				if i == 0:
					assert_eq(chip, float(sh.chipNaturalN), "%s de %s: sin afilar, la de la punta natural" % [id, mat])
				prev = chip
			# y la ley de R²: a la mitad de radio, la cuarta parte (en el cono, α ≤ 30°)
			var r0 := ClawSharpness.radius_um_of_area(float(K(id).area))
			var s_half := ClawSharpness.sharpness_for(r0, r0 / 2.0)
			var half: Dictionary = Physics.compute(P({ "claw": K(id), "inlay": I(mat), "force": 100.0, "sharpness": s_half })).sharpness
			assert_near(float(half.chipN), float(half.chipNaturalN) / 4.0, 1e-6, 0.0, "%s de %s: R/2 aguanta la cuarta parte" % [id, mat])


func test_mas_afilado_mas_presion_con_la_misma_fuerza() -> void:
	var prev_gain := 0.0
	var prev_p0 := 0.0
	for i in 11:
		var s := float(i) / 10.0
		var r := Physics.compute(P({ "claw": K("velociraptor"), "inlay": I("diamante"), "force": 1.0, "sharpness": s }))
		var sh: Dictionary = r.sharpness
		assert_true(float(sh.pressureGain) >= prev_gain and float(sh.p0MPa) >= prev_p0, "s = %s: la presión sube" % s)
		assert_near(float(sh.pressureGain), pow(float(sh.naturalUm) / float(sh.tipRadiusUm), 2.0 / 3.0), 1e-9, 0.0, "(R0/R)^(2/3)")
		prev_gain = sh.pressureGain
		prev_p0 = sh.p0MPa
	# la presión nominal del ensayo (F/A) también sube
	var a := Physics.compute(P({ "claw": K("velociraptor"), "inlay": I("diamante"), "force": 1.0 }))
	var b := Physics.compute(P({ "claw": K("velociraptor"), "inlay": I("diamante"), "force": 1.0, "sharpness": 0.5 }))
	assert_true(float(b.pNominal) > float(a.pNominal), "p = F/A sube al afilar")


func test_el_subtitulo_del_mellado_de_una_punta_afilada_va_en_su_unidad() -> void:
	# el zafiro arrastrado se mella (tipChip de la 1f): sin afilar, en N como siempre; afilada, lo que aguanta baja a mN
	var p := P({ "claw": K("velociraptor"), "inlay": I("zafiro"), "force": 381.5 })
	var r0 := Physics.compute(p)
	assert_true(r0.tipChip is Dictionary and bool(r0.tipChip.chipped), "se mella sin afilar")
	assert_true(String(r0.vsub).contains("aguanta ~%s N de lado" % Format.fmt_f(r0.tipChip.chipN)), r0.vsub)
	var r := Physics.compute(_with(p, { "sharpness": 0.5 }))
	assert_true(float(r.tipChip.chipN) < 1e-2, "afilada aguanta mN")
	assert_true(String(r.vsub).contains("aguanta ~%s de lado y la fricción le da ~%s" % [Format.fmt_small_force(r.tipChip.chipN),
		Format.fmt_small_force(r.tipChip.lateralN)]), r.vsub)
	assert_false(String(r.vsub).contains("~0.0 N"), "ni «~0.0 N»: %s" % r.vsub)
	assert_eq([Format.fmt_small_force(44.57), Format.fmt_small_force(0.0129), Format.fmt_small_force(3.7e-6), Format.fmt_small_force(3.6e-10)],
		["45 N", "13 mN", "3.7 µN", "0.36 nN"])
