## Materiales y fractura del modelo 2.0 INTEGRADOS en el banco (unidad 4a; docs/fisica/pulido-materiales.md §7):
## 1. Los casos de referencia de la unidad 1f (tests/fixtures/spec/pulido-materiales.json) a través de Physics.compute()
##    con el catálogo de la aplicación, veredictos incluidos (test_pulido_spec.gd los reconstruye con los módulos sueltos).
## 2. El contrato de los campos nuevos (fracture, nail, recovery, residualDepthUm, dent, glazing, tipChip): existen en los
##    dos modelos, a null en la 1.x, y en la 2.0 con los valores y los nulos que dice §7.2.
## 3. Invariantes de la 2.0: más fuerza nunca da menos profundidad (con una uña, la profundidad se queda en la de su punto
##    de cesión); la huella residual nunca es mayor que la de bajo carga; ni un aguijón ni la queratina agrietan un frágil;
##    el laminado no cae; más energía (o más fuerza) nunca da menos abolladura.
## 4. La prioridad de los veredictos (§7.3) y lo que cuentan los subtítulos.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const Bending = preload("res://core/lab/bending.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const Insects = preload("res://core/lab/insects.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const Contact = preload("res://core/shared/contact.gd")
const Attack = preload("res://core/lab/attack.gd")

const SPEC := "res://tests/fixtures/spec/pulido-materiales.json"
const V2 := Physics.MODEL_V2
const V1 := Physics.MODEL_V1
## Frágiles del banco (los de fracture.gd y los vidrios de coche).
const BRITTLE_IDS := ["vidrio", "movil", "cuarzo", "zafiro", "diamante", "ventanilla", "parabrisas"]


static func G(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.GEOMS, id)


static func B(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.BASES, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


static func K(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Los parámetros de siempre (almendra natural, 25 mm, arañazo, rayado, modelo 2.0) con los que se pidan encima.
static func P(over: Dictionary) -> Dictionary:
	var p := {
		"geom": G("almendra"), "base": B("natural"), "inlay": I("none"), "claw": null, "target": T("coche"),
		"type": Catalog.find_by_id(Catalog.TYPES, "aranazo"), "force": 4.0, "length": 25.0, "tear": false, "method": "rayado",
		"strike": false, "passes": 1.0, "wet": false, "model": V2,
	}
	p.merge(over, true)
	return p


static func run(over: Dictionary) -> Dictionary:
	return Physics.compute(P(over))


static func log_grid(a: float, b: float, n: int) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append(a * pow(b / a, float(i) / (n - 1)))
	return out


## Uñas representativas: la natural en cada forma extrema, seca y mojada, las del salón, las macizas y una con gema.
static func nail_tools() -> Array:
	return [
		{ "label": "almendra natural" }, { "label": "stiletto natural", "geom": G("stiletto") },
		{ "label": "cuadrada natural", "geom": G("cuadrada") }, { "label": "almendra mojada", "wet": true },
		{ "label": "stiletto XL de acrílico", "geom": G("stilettoxl"), "base": B("acrilico") },
		{ "label": "redonda de gel", "geom": G("redonda"), "base": B("gel") },
		{ "label": "stiletto de acero", "geom": G("stiletto"), "base": B("metal") },
		{ "label": "almendra de titanio", "base": B("titanio") }, { "label": "cuadrada de zafiro", "geom": G("cuadrada"), "base": B("zafiro") },
		{ "label": "almendra + diamante", "inlay": I("diamante") },
	]


static func with(tool: Dictionary, over: Dictionary) -> Dictionary:
	var p := tool.duplicate()
	p.erase("label")
	p.merge(over, true)
	return p


func _at(d: Variant, path: String) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if not (cur is Dictionary) or not (cur as Dictionary).has(part):
			return "<falta>"
		cur = cur[part]
	return cur


# ── 1. Casos de referencia ──

func test_casos_de_referencia_con_compute() -> void:
	var cases: Array = load_json(SPEC)
	var passed := 0
	var failed: Array = []
	for c: Dictionary in cases:
		var inp: Dictionary = c.input
		var p := {
			"geom": G(inp.geom), "base": B(inp.base), "inlay": I(inp.inlay), "claw": K(inp.claw) if inp.claw != null else null,
			"target": T(inp.target), "type": Catalog.find_by_id(Catalog.TYPES, inp.type), "force": float(inp.force),
			"length": float(inp.length), "tear": inp.tear, "method": inp.method, "strike": inp.strike, "passes": float(inp.passes),
			"wet": inp.wet, "model": inp.model,
		}
		assert_eq(p.model, V2, "%s: caso del modelo 2.0" % c.id)
		assert_true(p.target != null, "%s: el objetivo está en el catálogo de la aplicación" % c.id)
		var r := Physics.compute(p)
		var ok := true
		for k: String in c.expect:
			var e: Dictionary = c.expect[k]
			var got: Variant = _at(r, k)
			var where := "%s · %s" % [c.id, k]
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
			assert_true(good, "%s: %s frente a %s" % [where, show(got), JSON.stringify(e)])
			ok = ok and good
		if ok:
			passed += 1
		else:
			failed.append(c.id)
	assert_eq(cases.size(), 37, "los 37 casos de la unidad 1f")
	assert_eq(passed, cases.size(), "casos que cumple el compute() integrado (fallan: %s)" % ", ".join(failed))
	print("    (info) casos de referencia de los materiales: %d/%d con el compute() integrado" % [passed, cases.size()])


# ── 2. Contrato de los campos nuevos ──

func test_contrato_de_los_campos_nuevos() -> void:
	var tools: Array = nail_tools() + [
		{ "label": "gato", "claw": K("gato") }, { "label": "oso", "claw": K("oso") }, { "label": "víbora", "claw": K("vibora") },
		{ "label": "águila de zafiro", "claw": K("aguila"), "inlay": I("zafiro") }, { "label": "tigre de diamante", "claw": K("tigre"), "inlay": I("diamante") },
		{ "label": "abeja", "claw": Insects.find_by_id("abeja") }, { "label": "abeja de diamante", "claw": Insects.find_by_id("abeja"), "inlay": I("diamante") },
	]
	var n := 0
	for t: Dictionary in tools:
		for target: Dictionary in Catalog.TARGETS:
			for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
				for force in [0.001, 4.0, 60.0, 900.0]:
					var q := P(with(t, { "target": target, "method": m[0], "strike": m[1], "force": force }))
					var r2 := Physics.compute(q)
					q.model = V1
					var r1 := Physics.compute(q)
					var where := "%s → %s %s%s %s N" % [t.label, target.id, m[0], "+golpe" if m[1] else "", force]
					n += 1
					for k: String in Physics.V2_FIELDS:
						assert_true(r1.has(k) and r1[k] == null, "%s: «%s» existe en la 1.x y vale null" % [where, k])
						assert_true(r2.has(k), "%s: «%s» existe en la 2.0" % [where, k])
					var res_um: Variant = r2.get("residualDepthUm")
					assert_true(is_num(res_um) and is_finite(res_um) and res_um >= 0.0 and res_um <= r2.depthUm + 1e-9,
						"%s: residualDepthUm = %s (bajo carga %s)" % [where, res_um, r2.depthUm])
					var sting := Insects.is_stinger(q.get("claw"))
					# fracture: solo en los frágiles
					assert_eq(r2.fracture != null, Fracture.props(target) != null, "%s: fracture solo en los frágiles" % where)
					# nail: solo en las uñas con datos (no en garras, colmillos ni aguijones; no en el diamante macizo)
					var has_nail: bool = q.claw == null and Bending.nail_of(q.base.id) != null
					assert_eq(r2.nail != null, has_nail, "%s: nail solo en las uñas con datos" % where)
					# glazing: solo en los vidrios de coche
					var glazed := Js.truthy(target.get("tempered")) or Js.truthy(target.get("laminated"))
					assert_eq(r2.glazing != null, glazed, "%s: glazing solo en los vidrios de coche" % where)
					if glazed:
						assert_eq(r2.glazing.kind, "templado" if Js.truthy(target.get("tempered")) else "laminado", where)
					# recovery: nunca en la piel ni en la madera, ni si la punta atraviesa
					if Js.truthy(target.get("skin")) or target.id == "madera" or target.id == "puertamadera" or Js.truthy(r2.get("through")):
						assert_eq(r2.recovery, null, "%s: sin recuperación" % where)
					# dent: solo en chapas metálicas sin perforar
					if r2.dent != null:
						assert_false(Js.truthy(r2.get("through")), "%s: una chapa perforada no se abolla" % where)
						assert_true(target.get("body") != null or target.id == "puertametal", "%s: abolladura solo en chapas" % where)
					# tipChip: solo en garras reforjadas en zafiro o cuarzo (no en uñas ni aguijones)
					if r2.tipChip != null:
						assert_true(q.claw != null and not sting and ["zafiro", "cuarzo"].has(q.inlay.id), "%s: tipChip" % where)
					for k: String in ["verdict", "vsub", "vcol", "cede"]:
						assert_true(r2.get(k) is String and String(r2[k]) != "", "%s: %s" % [where, k])
					assert_true(r2.sev >= 0.0 and r2.sev <= 1.0, "%s: sev" % where)
	assert_true(n > 2000, "ensayos del contrato: %d" % n)


# ── 3. Invariantes ──

func test_mas_fuerza_nunca_da_menos_profundidad_y_la_una_se_queda_en_su_cesion() -> void:
	var forces := log_grid(0.5, Format.FMAX, 28)
	for t: Dictionary in nail_tools():
		for target: Dictionary in Catalog.TARGETS:
			for method in ["rayado", "puncion"]:
				var prev := -1.0
				var at_break: Variant = null
				for f in forces:
					var r := run(with(t, { "target": target, "force": f, "method": method }))
					var where := "%s → %s %s a %s N" % [t.label, target.id, method, Js.to_fixed(f, 1)]
					assert_true(r.depthUm >= prev - 1e-9, "%s: profundidad baja al subir la fuerza (%s < %s)" % [where, r.depthUm, prev])
					prev = r.depthUm
					if r.nail != null and r.nail.broken:
						# la profundidad es la de la fuerza de cesión: el resto se queda en el dedo
						if at_break == null:
							at_break = run(with(t, { "target": target, "force": r.nail.breakN, "method": method })).depthUm
						assert_near(r.depthUm, at_break, 1e-12, 1e-12, "%s: la profundidad del punto de cesión" % where)


func test_la_huella_residual_nunca_es_mayor_que_la_de_bajo_carga() -> void:
	var tools: Array = nail_tools() + [{ "label": "gato", "claw": K("gato") }, { "label": "oso de diamante", "claw": K("oso"), "inlay": I("diamante") }]
	for t: Dictionary in tools:
		for target: Dictionary in Catalog.TARGETS:
			for method in ["rayado", "puncion"]:
				for f in [1.0, 15.0, 300.0]:
					var r := run(with(t, { "target": target, "force": f, "method": method, "passes": 20.0 }))
					assert_true(r.residualDepthUm <= r.depthUm + 1e-9, "%s → %s: residual %s > %s" % [t.label, target.id, r.residualDepthUm, r.depthUm])
					if r.recovery != null:
						assert_true(r.recovery.fraction >= 0.0 and r.recovery.fraction <= 1.0, "%s → %s: fracción recuperada" % [t.label, target.id])
						assert_near(r.recovery.recoveredUm, r.depthUm - r.residualDepthUm, 1e-9, 1e-9, "%s → %s: recuperada" % [t.label, target.id])


func test_ni_un_aguijon_ni_la_queratina_agrietan_un_fragil() -> void:
	var tools: Array = []
	for g: Dictionary in Catalog.GEOMS:
		for wet in [false, true]:
			tools.append({ "label": "uña %s natural%s" % [g.id, " mojada" if wet else ""], "geom": g, "wet": wet })
	for c: Dictionary in Catalog.CLAWS:
		if Insects.is_stinger(c) or not Js.truthy(c.get("fang")):
			tools.append({ "label": c.id, "claw": c })  # garras de queratina y aguijones de quitina, sin reforjar
	var checked := 0
	for t: Dictionary in tools:
		var sting := Insects.is_stinger(t.get("claw"))
		var fmax: float = 1.0 if sting else Format.FMAX
		for id: String in BRITTLE_IDS:
			for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
				if sting and m[0] == "rayado":
					continue  # un aguijón solo pica
				for f in log_grid(0.001 if sting else 0.5, fmax, 6):
					var r := run(with(t, { "target": T(id), "force": f, "method": m[0], "strike": m[1] }))
					var where := "%s → %s %s a %s N" % [t.label, id, m[0], f]
					checked += 1
					assert_true(r.fracture == null or not r.fracture.cracks, "%s agrieta el frágil (%s)" % [where, r.fracture])
					assert_false(String(r.verdict).contains("HERTZ"), "%s: %s" % [where, r.verdict])
					if r.glazing != null:
						assert_true(r.glazing.cause != "grieta", "%s: una punta blanda no abre la grieta del templado" % where)
	assert_true(checked > 1000, "ensayos: %d" % checked)


func test_el_laminado_no_cae() -> void:
	var tools: Array = nail_tools() + [
		{ "label": "gato", "claw": K("gato") }, { "label": "oso", "claw": K("oso") }, { "label": "casuario", "claw": K("casuario") },
		{ "label": "tigre de diamante", "claw": K("tigre"), "inlay": I("diamante") }, { "label": "águila de acero", "claw": K("aguila"), "inlay": I("acero") },
		{ "label": "halcón en picado", "claw": K("halcon") },
	]
	var cracked := 0
	for t: Dictionary in tools:
		for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
			for f in [4.0, 60.0, 300.0, Format.FMAX]:
				var r := run(with(t, { "target": T("parabrisas"), "force": f, "method": m[0], "strike": m[1] }))
				var where := "%s %s%s a %s N" % [t.label, m[0], "+golpe" if m[1] else "", f]
				assert_false(r.shattered, "%s: el laminado no se rompe en pedazos" % where)
				assert_false(["ROMPE EL VIDRIO", "ESTALLA LA VENTANILLA"].has(r.verdict), "%s: %s" % [where, r.verdict])
				assert_eq(r.glazing.kind, "laminado", where)
				if not r.glazing.penetrationRisk:
					assert_true(r.depthUm <= 4200.0 + 1e-9 and not r.through, "%s: la punta no pasa del vidrio (%s µm)" % [where, r.depthUm])
				if r.glazing.cracked:
					cracked += 1
					assert_true(r.verdict == "SE AGRIETA (NO CAE)" or r.toolBroken, "%s: %s" % [where, r.verdict])
					assert_true(String(r.vsub).contains("PVB") or r.toolBroken, "%s: la lámina sujeta los trozos (%s)" % [where, r.vsub])
	assert_true(cracked > 10, "hay ensayos que lo agrietan: %d" % cracked)


func test_mas_energia_nunca_da_menos_abolladura() -> void:
	# el zarpazo del oso con más o menos velocidad (la misma garra): la energía crece con v²
	for id in ["coche", "cocheclasico", "cochealu", "puertametal"]:
		var prev := -1.0
		for v in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0]:
			var bear: Dictionary = K("oso").duplicate(true)
			bear.strike.v = v
			var r := run({ "claw": bear, "target": T(id), "force": 30.0, "method": "puncion", "strike": true })
			if Js.truthy(r.get("through")):
				break  # perforada, ya no se abolla
			assert_true(r.dent != null, "%s: la chapa se abolla o no, pero se calcula" % id)
			assert_true(r.dent.depthMm >= prev - 1e-12, "%s a %s m/s: menos abolladura con más energía (%s < %s)" % [id, v, r.dent.depthMm, prev])
			prev = r.dent.depthMm
		assert_true(prev > 0.1, "%s: el oso rápido la abolla" % id)
	# y empujando o rayando, más fuerza, más abolladura
	for method in ["rayado", "puncion"]:
		var prev := -1.0
		for f in log_grid(10.0, Format.FMAX, 20):
			var r := run({ "claw": K("avestruz"), "target": T("coche"), "force": f, "method": method })
			if Js.truthy(r.get("through")):
				break
			assert_true(r.dent.depthMm >= prev - 1e-12, "%s a %s N: menos abolladura" % [method, f])
			prev = r.dent.depthMm


# ── 4. Prioridad de los veredictos y textos ──

func test_prioridad_de_los_veredictos() -> void:
	# la uña cede sin daño: el veredicto se queda y la cesión va en el subtítulo
	var glass := run({ "target": T("vidrio"), "force": 30.0 })
	assert_eq(glass.verdict, "NO RAYA", "la lección de durezas se conserva")
	assert_true(glass.nail.broken and String(glass.vsub).ends_with("(además, a ~%s N la uña se dobla)" % Format.fmt_f(glass.nail.breakN)), glass.vsub)
	assert_false(Js.truthy(glass.toolBroken), "sin daño, la herramienta no es la protagonista")
	# con daño, la uña es la protagonista y el daño hecho se conserva
	var skin := run({ "geom": G("stiletto"), "target": T("piel"), "force": 30.0 })
	# el daño de la carga de cesión tal cual (la piel es la misma en la 1.x, sin la uña; en la 2.0 también cedería)
	var at_break := run({ "geom": G("stiletto"), "target": T("piel"), "force": skin.nail.breakN, "model": V1 })
	assert_eq(skin.verdict, "SE DOBLA LA UÑA")
	assert_true(skin.toolBroken, "la uña cede: toolBroken")
	assert_eq(skin.depthUm, at_break.depthUm, "la profundidad del punto de cesión")
	assert_eq(skin.layer, at_break.layer, "la capa alcanzada se conserva")
	assert_eq(skin.sev, at_break.sev, "la severidad se conserva")
	assert_true(String(skin.vsub).contains("hasta entonces, " + String(at_break.vsub)), "el subtítulo cuenta el daño: %s" % skin.vsub)
	var acr := run({ "geom": G("stilettoxl"), "base": B("acrilico"), "target": T("piel"), "force": 30.0 })
	assert_eq(acr.verdict, "SE PARTE LA UÑA")
	assert_eq(acr.vcol, Physics.C.coral, "una rotura, en coral")
	assert_true(String(acr.vsub).begins_with("el acrílico se parte a ~"), acr.vsub)
	# toolBroken de una uña ⇔ su veredicto
	for t: Dictionary in nail_tools():
		for target: Dictionary in Catalog.TARGETS:
			var r := run(with(t, { "target": target, "force": 60.0 }))
			var own := ["SE DOBLA LA UÑA", "SE PARTE LA UÑA"].has(r.verdict)
			assert_eq(Js.truthy(r.get("toolBroken")), own, "%s → %s: toolBroken y «%s»" % [t.label, target.id, r.verdict])
			if own:
				assert_true(r.nail.broken and Js.truthy(r.scratched), "%s → %s: solo si cede y hubo daño" % [t.label, target.id])
	# grietas de Hertz: solo sin surco; rayando, herraduras; apretando, cono
	var hertz := run({ "geom": G("cuadrada"), "base": B("zafiro"), "target": T("vidrio"), "force": 30.0 })
	assert_eq(hertz.verdict, "GRIETAS DE HERTZ")
	assert_true(hertz.depthUm < Fracture.GROOVE_MIN_UM and hertz.fracture.pattern == "herradura", "sin surco, en herradura")
	assert_eq(hertz.scratched, false, "no raya: el daño son las grietas")
	var cone := run({ "geom": G("cuadrada"), "base": B("diamante"), "target": T("cuarzo"), "force": 300.0, "method": "puncion" })
	assert_eq([cone.verdict, cone.fracture.pattern], ["CONO DE HERTZ", "cono"])
	# astillado: el veredicto de siempre con el subtítulo del astillado
	var chip := run({ "geom": G("stiletto"), "base": B("zafiro"), "target": T("vidrio"), "force": 30.0 })
	assert_eq([chip.verdict, chip.fracture.mode, chip.fracture.pattern], ["RAYA", "radial", "astillado"])
	assert_true(String(chip.vsub).contains("astillan el borde"), chip.vsub)
	# abolladura: manda al golpear sin perforar; rayando va en el subtítulo
	var hit := run({ "claw": K("oso"), "target": T("coche"), "force": 300.0, "method": "puncion", "strike": true })
	assert_eq(hit.verdict, "ABOLLA LA CHAPA")
	assert_true(String(hit.vsub).begins_with("no la perfora, pero la abolla ~"), hit.vsub)
	var door := run({ "claw": K("oso"), "target": T("puertametal"), "force": 300.0, "method": "puncion", "strike": true })
	if door.dent != null and door.dent.visible and not door.through:
		assert_eq(door.verdict, "ABOLLA LA PUERTA")
	var drag := run({ "claw": K("avestruz"), "target": T("coche"), "force": 900.0 })
	assert_eq(drag.verdict, "HASTA EL METAL", "rayando, el veredicto de la pintura se queda")
	assert_true(String(drag.vsub).ends_with("y abolla la chapa ~%s mm" % Js.to_fixed(drag.dent.depthMm, 1)), drag.vsub)
	# vidrios de coche
	var bear_side := run({ "claw": K("oso"), "target": T("ventanilla"), "force": 300.0, "method": "puncion", "strike": true })
	assert_eq([bear_side.verdict, bear_side.glazing.cause, bear_side.shattered], ["ESTALLA LA VENTANILLA", "flexión", true])
	var hammer := run({ "claw": K("tigre"), "inlay": I("diamante"), "target": T("ventanilla"), "force": 260.0, "method": "puncion" })
	assert_eq([hammer.verdict, hammer.glazing.cause], ["ESTALLA LA VENTANILLA", "grieta"])
	assert_true(String(hammer.vsub).contains("martillo de emergencia"), hammer.vsub)
	var screen := run({ "claw": K("oso"), "target": T("parabrisas"), "force": 300.0, "method": "puncion", "strike": true })
	assert_eq([screen.verdict, screen.shattered, screen.glazing.penetrationRisk], ["SE AGRIETA (NO CAE)", false, true])
	assert_true(String(screen.vsub).contains("podría atravesarlo"), screen.vsub)
	# el mellado es informativo: la profundidad y el veredicto son los de la 1.x
	var eagle := { "claw": K("aguila"), "inlay": I("zafiro"), "target": T("coche"), "force": 110.0 }
	var e2 := run(eagle)
	var e1 := run(with(eagle, { "model": V1 }))
	assert_true(e2.tipChip.chipped, "la punta de zafiro se mella")
	assert_eq([e2.verdict, e2.depthUm], [e1.verdict, e1.depthUm], "el mellado no cambia el veredicto ni la profundidad")
	assert_true(String(e2.vsub).contains("se mella"), e2.vsub)


func test_golpe_con_una_una() -> void:
	# la stiletto de acero se dobla contra la chapa antes de perforarla (en el 1.x la perfora)
	var metal := { "geom": G("stiletto"), "base": B("metal"), "target": T("coche"), "force": 30.0, "method": "puncion", "strike": true }
	var r2 := run(metal)
	var r1 := run(with(metal, { "model": V1 }))
	assert_eq(r1.verdict, "PERFORA LA CHAPA")
	assert_eq(r2.verdict, "SE DOBLA LA UÑA")
	assert_true(r2.depthUm < r1.depthUm and not r2.through, "no la perfora")
	# la profundidad es la de un empuje con su carga de cesión (la receta de la guía de integración)
	var push := run(with(metal, { "force": r2.nail.breakN, "strike": false }))
	assert_near(r2.depthUm, push.depthUm, 1e-12, 1e-12, "la profundidad del empuje con la carga de cesión")
	# una uña natural no aguanta la fuerza que rompe la piel: se dobla antes y no perfora, ni de un golpe
	for g: Dictionary in Catalog.GEOMS:
		var r := run({ "geom": g, "target": T("piel"), "force": 30.0, "method": "puncion", "strike": true })
		assert_eq(r.pierces, false, "%s natural: no perfora la piel de un golpe (%s)" % [g.id, r.verdict])
		assert_true(r.nail.broken, "%s natural: el golpe la dobla" % g.id)
	# una hoja que la uña puede partir se rompe antes de que ceda la uña
	var sapphire := run({ "geom": G("cuadrada"), "base": B("zafiro"), "target": T("vidrio"), "force": 30.0, "method": "puncion", "strike": true })
	if sapphire.shattered:
		assert_eq(sapphire.verdict, "ROMPE EL VIDRIO", "la hoja se rompe antes que la uña de zafiro")
		assert_false(sapphire.nail.broken, "la uña de zafiro no llega a ceder")


## Empujando, una hoja que se parte con una carga que la uña aguanta cede antes que la uña: la uña no llega a ceder y
## el ensayo es el de la 1.x (más los campos de la 2.0). El laminado, en cambio, se agrieta y sigue sujeto: se puede
## seguir empujando hasta que cede la uña.
func test_la_hoja_que_se_parte_antes_no_deja_ceder_la_una() -> void:
	var seen := 0
	for t: Dictionary in nail_tools():
		for method in ["rayado", "puncion"]:
			for f in [250.0, 400.0, 1000.0, Format.FMAX]:
				var q := with(t, { "target": T("vidrio"), "force": f, "method": method })
				var r2 := run(q)
				if not r2.shattered:
					continue
				seen += 1
				var where := "%s %s a %s N" % [t.label, method, f]
				assert_eq(r2.verdict, "ROMPE EL VIDRIO", where)
				assert_true(r2.nail == null or not r2.nail.broken, "%s: la hoja se parte antes de que ceda la uña" % where)
				assert_false(Js.truthy(r2.toolBroken), "%s: la herramienta no cede" % where)
				var r1 := run(with(q, { "model": V1 }))
				var a := r2.duplicate()
				var b := r1.duplicate()
				for k: String in Physics.V2_FIELDS:
					a.erase(k)
					b.erase(k)
				# unidad 4b: al rayar, el modo de abrasión lleva el ángulo de ataque de la uña (45°, attack.gd), el mismo que la
				# flexiona; la 1.x va de frente. Esas claves son las de Attack.abrasion con el ensayo de la 1.x.
				if method == "rayado" and r2.absMode != null:
					var full := P(q)
					var tool := Physics.resolve_tool(full)
					var m: float = float(r1.phi) * float(full.type.k) * Physics.pass_depth_factor(full.passes)
					var ab := Attack.abrasion(r1.Dp, r1.depthUm, m, Contact.tip_geometry(tool.area, tool.alpha, tool.baseR), tool.alpha,
						r2.attackDeg)
					assert_eq([r2.absMode, r2.fab, r2.muPlough, r2.DpEff], [ab.absMode, ab.fab, ab.muPlough, ab.DpEff],
						"%s: la abrasión con el ángulo de la uña" % where)
					for k in ["absMode", "fab", "muPlough", "muEff", "Ffric", "wearIdx"]:
						a.erase(k)
						b.erase(k)
				assert_eq(oracle_diff(a, b).size(), 0, "%s: el ensayo de la 1.x (%s)" % [where, oracle_diff(a, b)])
	assert_true(seen >= 10, "ensayos en que la hoja se parte con una uña que aguanta: %d" % seen)
	var lam := run({ "geom": G("cuadrada"), "base": B("metal"), "target": T("parabrisas"), "force": 1000.0, "method": "puncion" })
	assert_true(lam.glazing.cracked and lam.nail.broken, "el parabrisas se agrieta y, empujando más, cede la uña")
	assert_eq(lam.verdict, "SE DOBLA LA UÑA")
	assert_true(String(lam.vsub).contains("PVB"), lam.vsub)


func test_tiempo_de_compute_2_0() -> void:
	# la física 2.0 en serie, con una parte de la muestra del oráculo (la cifra de referencia de la unidad 4a)
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/generated/lab-sample.json"))
	var trials: Array = (sample.trials as Array).slice(0, 3000)
	var by_id := {}
	for key in ["GEOMS", "BASES", "INLAYS", "CLAWS", "TARGETS", "TYPES"]:
		var index := {}
		for x: Dictionary in Catalog.list(key):
			index[x.id] = x
		by_id[key] = index
	var params: Array = []
	for t: Dictionary in trials:
		var p: Dictionary = t.params
		params.append({
			"geom": by_id.GEOMS[p.geom], "base": by_id.BASES[p.base], "inlay": by_id.INLAYS[p.inlay],
			"claw": by_id.CLAWS[p.claw] if p.get("claw") != null else null, "target": by_id.TARGETS[p.target], "type": by_id.TYPES[p.type],
			"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike, "passes": p.passes,
			"wet": p.wet, "model": V2,
		})
	var t0 := Time.get_ticks_usec()
	for q: Dictionary in params:
		Physics.compute(q)
	var us := float(Time.get_ticks_usec() - t0) / params.size()
	assert_true(us > 0.0)
	print("    (info) compute() 2.0 en serie: %d ensayos de la muestra, %s µs por ensayo" % [params.size(), Js.to_fixed(us, 1)])
