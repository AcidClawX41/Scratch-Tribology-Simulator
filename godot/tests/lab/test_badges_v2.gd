## Los logros de lo nuevo de la 2.0 (unidad 4p; Lab.BADGES_V2), aparte de los 15 de la 1.x, que no cambian (los compara el
## oráculo: test_lab_state y el golden 1.x).
## 1. Las dos listas: ids distintos, los de la 1.x intactos y, con la física 1.x, ninguno de la 2.0.
## 2. Cada logro del banco con un ensayo que lo da y otro, parecido, que no: los aguijones, el velocirraptor (el de verdad y
##    el de cine), las zonas del cuerpo, el hueso, el ángulo de ataque, la uña que se parte y la ventanilla templada.
## 3. Los del coche en marcha (quieto encima a 100 km/h o más y un golpe que abolla), por LabState y su estado.
## 4. La tarjeta de los logros: las fichas de la 2.0 debajo, con su propio contador, y lo que se guarda y se recupera.
extends "res://tests/case.gd"

const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Physics = preload("res://core/lab/physics.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const BadgesCard = preload("res://app/lab/badges_card.gd")
const ArtCache = preload("res://app/common/art_cache.gd")


## Los parámetros de un ensayo del banco con ids del catálogo 2.0 (almendra natural, 25 mm, arañazo, rayado, modelo 2.0).
static func P(over: Dictionary) -> Dictionary:
	var p := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, String(over.get("geom", "almendra"))),
		"base": Catalog.find_by_id(Catalog.BASES, String(over.get("base", "natural"))),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, String(over.get("inlay", "none"))),
		"claw": Catalog.find_by_id(Catalog.CLAWS, String(over.claw)) if over.has("claw") else null,
		"target": Catalog.find_by_id(Catalog.TARGETS, String(over.target)), "type": Catalog.find_by_id(Catalog.TYPES, "aranazo"),
		"force": float(over.force), "length": 25.0, "tear": false, "method": String(over.get("method", "rayado")),
		"strike": bool(over.get("strike", false)), "passes": 1.0, "wet": false, "model": String(over.get("model", Physics.MODEL_V2)),
	}
	for k: String in ["zone", "attack_deg"]:
		if over.has(k):
			p[k] = over[k]
	return p


## Los logros que da un ensayo, solo (sin los de antes), con la física del ensayo.
static func earned(over: Dictionary) -> Array:
	var p := P(over)
	var r := Physics.compute(p)
	var ctx := { "res": r, "target": p.target, "inlay": p.inlay, "claw": p.claw, "method": p.method, "strike": p.strike, "runs": 1 }
	return Lab.earn_badges_model({}, ctx, p.model).keys()


static func ids(list: Array) -> Array:
	return list.map(func(b: Dictionary) -> String: return String(b.id))


func test_dos_listas_y_la_1x_intacta() -> void:
	var v1 := ids(Lab.BADGES)
	var v2 := ids(Lab.BADGES_V2)
	assert_eq(v1.size(), 15, "los 15 de la 1.x")
	assert_eq(v2.size(), 11, "los 11 de la 2.0")
	for id: String in v2:
		assert_false(v1.has(id), "«%s» no es de la 1.x" % id)
	assert_eq(Lab.BADGE_ORDER.size(), v1.size(), "el orden de la 1.x, sin los de la 2.0")
	for b: Dictionary in Lab.BADGES_V2:
		assert_true(String(b.t) != "" and String(b.t).length() <= 24, "«%s»: un título corto (%s)" % [b.id, b.t])
	# con la física 1.x, los de siempre y ninguno de la 2.0, aunque el ensayo sea de lo nuevo
	var bee := earned({ "claw": "abeja", "target": "piel", "force": 0.00575, "method": "puncion", "model": Physics.MODEL_V1 })
	for id: String in v2:
		assert_false(bee.has(id), "1.x: sin «%s»" % id)
	var p := P({ "claw": "gato", "target": "piel", "force": 15.0 })
	var r := Physics.compute(p)
	var ctx := { "res": r, "target": p.target, "inlay": p.inlay, "claw": p.claw, "method": p.method, "strike": p.strike, "runs": 3 }
	assert_eq(Lab.earn_badges_model({}, ctx, Physics.MODEL_V1), Lab.earn_badges({}, ctx), "con la 1.x es earn_badges, tal cual")


func test_cada_logro_del_banco_con_su_ensayo() -> void:
	# [logro, el ensayo que lo da, uno parecido que no]
	var cases := [
		["kamikaze", { "claw": "abeja", "target": "piel", "force": 0.00575, "method": "puncion" },
			{ "claw": "avispa", "target": "piel", "force": 0.0099, "method": "puncion" }],
		["raptor", { "claw": "velociraptor", "target": "piel", "force": 381.5, "method": "puncion", "strike": true },
			{ "claw": "velociraptor_pelicula", "target": "piel", "force": 381.5, "method": "puncion", "strike": true }],
		["cine", { "claw": "velociraptor_pelicula", "target": "coche", "force": 1841.0 },
			{ "claw": "velociraptor", "target": "coche", "force": 381.5 }],
		["callo", { "claw": "pajaro", "target": "piel", "force": 1.5, "zone": "palma" }, { "claw": "pajaro", "target": "piel", "force": 1.5 }],
		["penetrante", { "claw": "gabon", "target": "piel", "force": 30.0, "method": "puncion", "strike": true, "zone": "abdomen" },
			{ "claw": "gabon", "target": "piel", "force": 30.0, "method": "puncion", "zone": "palma" }],
		["hueso", { "claw": "vibora", "target": "piel", "force": 4.0, "method": "puncion", "zone": "cara" },
			{ "claw": "vibora", "target": "piel", "force": 4.0, "method": "puncion" }],
		["gancho", { "geom": "cuadrada", "target": "madera", "force": 30.0, "attack_deg": 150.0 },
			{ "geom": "stiletto", "target": "madera", "force": 10.0, "attack_deg": 20.0 }],
		["unarota", { "geom": "stilettoxl", "base": "acrilico", "target": "piel", "force": 30.0 },
			{ "geom": "stiletto", "target": "piel", "force": 30.0 }],
		["martillo", { "claw": "tigre", "inlay": "diamante", "target": "ventanilla", "force": 260.0, "method": "puncion" },
			{ "claw": "oso", "target": "ventanilla", "force": 300.0, "method": "puncion", "strike": true }],
	]
	for c: Array in cases:
		var yes := earned(c[1])
		var no := earned(c[2])
		assert_true(yes.has(c[0]), "«%s» con %s (ganados: %s)" % [c[0], c[1], yes])
		assert_false(no.has(c[0]), "sin «%s» con %s (ganados: %s)" % [c[0], c[2], no])
	# los del coche en marcha nunca salen del banco
	for c: Array in cases:
		for id: String in ["polizon", "abollado"]:
			assert_false(earned(c[1]).has(id), "«%s» no sale del banco" % id)


func test_los_del_coche_en_marcha() -> void:
	var held := Lab.earn_car_badges({}, { "mode": "hold", "holds": true, "vKmh": 120.0, "hit": {} })
	assert_eq(held.keys(), ["polizon"], "aguanta encima a 120 km/h: «Polizón»")
	assert_eq(Lab.earn_car_badges({}, { "mode": "hold", "holds": true, "vKmh": 90.0, "hit": {} }).keys(), [], "a 90 km/h, todavía no")
	assert_eq(Lab.earn_car_badges({}, { "mode": "hold", "holds": false, "vKmh": 150.0, "hit": {} }).keys(), [], "si se suelta, no")
	var dent := { "ok": true, "dent": { "visible": true } }
	assert_eq(Lab.earn_car_badges({}, { "mode": "impact", "hit": dent }).keys(), ["abollado"], "un golpe que abolla: «Abollado en marcha»")
	assert_eq(Lab.earn_car_badges({}, { "mode": "impact", "hit": { "ok": true, "dent": { "visible": false } } }).keys(), [], "sin abolladura, no")
	var prev := { "vidrio": true }
	var nb := Lab.earn_car_badges(prev, { "mode": "impact", "hit": dent })
	assert_eq(prev.keys(), ["vidrio"], "no toca el conjunto de antes")
	assert_eq(nb.keys(), ["vidrio", "abollado"], "añade detrás")
	# por LabState, con la página del coche: el estado de verdad, el águila quieta en el techo a 120 km/h y la patada del
	# casuario contra la puerta; con la física 1.x, nada
	var lab := LabState.new()
	var st: RefCounted = MCS.new(Catalog.find_by_id(Catalog.CLAWS, "aguila"), Catalog.find_by_id(Catalog.TARGETS, "coche"))
	st.threaded = false
	st.set_speed(120.0)
	st.finish()
	var ctx := { "mode": st.mode, "holds": st.at.get("holds"), "vKmh": st.v_kmh, "hit": st.hit }
	lab.set_model(Physics.MODEL_V1)
	lab.earn_car_badges(ctx)
	assert_eq(lab.badges.size(), 0, "1.x: el coche en marcha no existe")
	lab.set_model(Physics.MODEL_V2)
	lab.earn_car_badges(ctx)
	assert_eq(lab.badges.has("polizon"), st.at.get("holds") == true, "el águila en el techo a 120 km/h: aguanta %s" % st.at.get("holds"))
	assert_true(st.load_experiment("casuario_puerta"), "la patada del casuario contra la puerta")
	st.finish()
	lab.earn_car_badges({ "mode": st.mode, "holds": st.at.get("holds"), "vKmh": st.v_kmh, "hit": st.hit })
	assert_true(lab.badges.has("abollado"), "abolla la puerta")
	st.dispose()


func test_la_tarjeta_y_el_progreso() -> void:
	var lab := LabState.new()
	var card: Control = BadgesCard.new()
	card.setup(lab, ArtCache.new())
	lab.badges = { "vidrio": true, "kamikaze": true, "abollado": true }
	card.refresh()
	assert_eq(card.count.text, "1/15", "la cabecera, los de la 1.x")
	assert_eq(card.count_v2.text, "2/11", "y los de la 2.0, su contador")
	assert_eq(card.badges_v2.size(), 11, "una ficha por logro de la 2.0")
	for b: Dictionary in Lab.BADGES_V2:
		var l: Label = card.badges_v2[b.id]
		var has: bool = lab.badges.has(b.id)
		assert_eq(l.text, ("★ " if has else "○ ") + String(b.t), "ficha de «%s»" % b.id)
		assert_eq(l.theme_type_variation, &"BadgeOn" if has else &"BadgeOff", "color de «%s»" % b.id)
	card.free()
	# lo que se guarda y se recupera, con los de la 2.0 (y sin los que no existen)
	var saved := lab.progress()
	var back := LabState.new()
	back.restore_progress({ "badges": (saved.badges as Array) + ["no-existe"], "notebook": [], "count": 3 })
	assert_eq(back.badges.keys(), ["vidrio", "kamikaze", "abollado"], "los de la 2.0 también se recuperan, en su orden")
