## Golden del modelo 2.0 del laboratorio: tests/fixtures/lab-golden-v2.json.
##
## Las salidas de la física 2.0 (Physics.compute con model = "2.0") para los 40 escenarios del golden 1.x
## (tests/fixtures/lab-golden.json, los de packages/core/scripts/scenarios.js) y, detrás, para los escenarios nuevos
## de la 2.0 (EXTRA_SCENARIOS). Mismo formato que el golden 1.x que exporta el oráculo (export-fixtures.mjs):
##   [{ name, params, result, sfx, toolLabel, damage?, damageStage?, badgesAfter }]
## - params: los normalizados del golden 1.x (normalize(), el norm() del exportador), con ids del catálogo de la 2.0
##   (core/lab/catalog.gd), así que un aguijón de insects.gd se escribe igual que una garra. Los escenarios nuevos
##   pueden traer además los parámetros de la 2.0 `zone` (zona del cuerpo), `attack_deg` (ángulo de ataque, en grados) y
##   `sharpness` (el afilado de una garra reforjada, 0-1; unidad 4i).
## - Números como los escribe JSON.stringify de JavaScript (String(n)); los no finitos, { "$num": "Infinity" }. Un
##   ensayo que la 2.0 no cambia da lo mismo que en el golden 1.x con la política del oráculo (el port puede diferir en
##   el último bit, algunas claves van en otro orden y lo que en JavaScript es undefined aquí se escribe null).
## - badgesAfter: logros acumulados a lo largo de toda la serie (los 40 y luego los nuevos), como en el golden 1.x, con los de
##   lo nuevo de la 2.0 detrás de los de la 1.x en cada ensayo (Lab.earn_badges_model; unidad 4p).
## Se regenera SOLO a propósito, con `npm run godot:golden`, y cada diferencia con la 1.x se explica en docs/FISICA.md
## («Cambios de la 2.0»). Lo comprueba tests/lab/test_golden_v2.gd, con la política del oráculo (case.gd → oracle_diff).
## Uso: npm run godot:golden (o godot --headless --path godot --script res://tools/golden_v2.gd).
extends SceneTree

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
## El efecto de la 2.0 (el de los aguijones; con todo lo demás, el de la 1.x): lo que suena en la aplicación.
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const Js = preload("res://core/shared/js.gd")
const Case = preload("res://tests/case.gd")

const SOURCE := "res://tests/fixtures/lab-golden.json"
const OUT := "res://tests/fixtures/lab-golden-v2.json"
const MODEL := Physics.MODEL_V2

## Escenarios nuevos de la 2.0, detrás de los 40 de la 1.x: { "name": String, "params": { … } }. Los parámetros que
## falten toman los valores de normalize() (uña almendra natural, 25 mm, arañazo, rayado…).
## Aguijones (docs/fisica/aguijones.md §7.9): la abeja y la avispa en la piel con su empuje típico, el avispón hasta la
## grasa, la abeja contra el pino, la abeja de acero y la de diamante empujadas hasta pandear, y la abeja contra la
## cutícula de otro insecto. Materiales (docs/fisica/pulido-materiales.md, al menos uno por tema): grietas de Hertz al
## rayar y cono al apretar, astillado, la uña de acrílico que se parte, la recuperación del ABS, la abolladura, la
## ventanilla que estalla por flexión y por una grieta, el parabrisas que se agrieta y el talón de zafiro que se mella.
## Biología (docs/fisica/pulido-biologia.md §9, al menos uno por tema): el callo de la palma, el corte y la punción que
## llegan al hueso (lo marcan, lo atraviesan o rompen el colmillo), el roce de los flancos, la herida penetrante del
## abdomen, el aguijón en otra zona, el ángulo de ataque (la uña tumbada que ara, la de gancho que aguanta y corta, y la
## garra que pasa de cortar a hacer cuña), el esmalte de la punta del colmillo y la uña con gema mojada (la placa de
## queratina se ablanda aunque la gema no). Velocirraptor (docs/fisica/velociraptor.md §10; unidad 4i): su golpe en el
## brazo, su garra de queratina rayando el coche y la de diamante afilada rayando el acero. Velocirraptor de cine
## (FICCIÓN, docs/fisica/velociraptor.md §11; unidad 4i-B2): su garra de película rayando el coche y su golpe contra él.
const EXTRA_SCENARIOS := [
	{ "name": "Abeja picando la piel", "params": { "claw": "abeja", "target": "piel", "force": 0.00575, "method": "puncion" } },
	{ "name": "Avispa común picando la piel", "params": { "claw": "avispa", "target": "piel", "force": 0.0099, "method": "puncion" } },
	{ "name": "Avispón europeo picando la piel", "params": { "claw": "avispon", "target": "piel", "force": 0.014, "method": "puncion" } },
	{ "name": "Abeja contra la madera de pino", "params": { "claw": "abeja", "target": "madera", "force": 0.00575, "method": "puncion" } },
	{ "name": "Abeja de acero empujada hasta pandear en el pino", "params": { "claw": "abeja", "inlay": "acero", "target": "madera", "force": 1.0, "method": "puncion" } },
	{ "name": "Abeja de diamante empujada hasta pandear contra el vidrio", "params": { "claw": "abeja", "inlay": "diamante", "target": "vidrio", "force": 5.0, "method": "puncion" } },
	{ "name": "Abeja contra la cutícula de otro insecto", "params": { "claw": "abeja", "target": "cuticula", "force": 0.00575, "method": "puncion" } },
	{ "name": "Abeja de acero contra la cutícula de otro insecto", "params": { "claw": "abeja", "inlay": "acero", "target": "cuticula", "force": 0.5, "method": "puncion" } },
	{ "name": "Uña cuadrada de zafiro rayando el vidrio: grietas de Hertz", "params": { "geom": "cuadrada", "base": "zafiro", "target": "vidrio", "force": 30.0 } },
	{ "name": "Uña cuadrada de diamante apretando la encimera: cono de Hertz", "params": { "geom": "cuadrada", "base": "diamante", "target": "cuarzo", "force": 300.0, "method": "puncion" } },
	{ "name": "Stiletto de zafiro rayando el vidrio: astillado", "params": { "geom": "stiletto", "base": "zafiro", "target": "vidrio", "force": 30.0 } },
	{ "name": "Stiletto XL de acrílico sobre la piel: se parte la uña", "params": { "geom": "stilettoxl", "base": "acrilico", "target": "piel", "force": 30.0 } },
	{ "name": "Garra de gato sobre el ABS: recuperación elástica", "params": { "claw": "gato", "target": "plastico", "force": 15.0 } },
	{ "name": "Zarpazo de oso contra el coche moderno: abolla la chapa", "params": { "claw": "oso", "target": "coche", "force": 300.0, "method": "puncion", "strike": true } },
	{ "name": "Zarpazo de oso contra la ventanilla templada: estalla", "params": { "claw": "oso", "target": "ventanilla", "force": 300.0, "method": "puncion", "strike": true } },
	{ "name": "Garra de tigre de diamante apretando la ventanilla: martillo de emergencia", "params": { "claw": "tigre", "inlay": "diamante", "target": "ventanilla", "force": 260.0, "method": "puncion" } },
	{ "name": "Zarpazo de oso contra el parabrisas laminado: se agrieta y no cae", "params": { "claw": "oso", "target": "parabrisas", "force": 300.0, "method": "puncion", "strike": true } },
	{ "name": "Talón de águila de zafiro arrastrado sobre el coche: la punta se mella", "params": { "claw": "aguila", "inlay": "zafiro", "target": "coche", "force": 110.0 } },
	{ "name": "Pájaro rayando la palma: callo pulido", "params": { "claw": "pajaro", "target": "piel", "force": 1.5, "zone": "palma" } },
	{ "name": "Garra de tigre en el dorso de la mano: laceración hasta el hueso", "params": { "claw": "tigre", "target": "piel", "force": 260.0, "zone": "dorsomano" } },
	{ "name": "Gato punzando el brazo con 3,2 N: la grieta y el roce lo paran en la grasa", "params": { "claw": "gato", "target": "piel", "force": 3.2, "method": "puncion" } },
	{ "name": "Víbora punzando el pómulo: se clava en el hueso", "params": { "claw": "vibora", "target": "piel", "force": 4.0, "method": "puncion", "zone": "cara" } },
	{ "name": "Víbora mordiendo el dorso de la mano: el colmillo se rompe contra el metacarpiano", "params": { "claw": "vibora", "target": "piel", "force": 4.0, "method": "puncion", "strike": true, "zone": "dorsomano" } },
	{ "name": "Casuario de tungsteno, golpe en el brazo: atraviesa el húmero", "params": { "claw": "casuario", "inlay": "tungsteno", "target": "piel", "force": 500.0, "method": "puncion", "strike": true } },
	{ "name": "Gabón mordiendo el abdomen: herida penetrante", "params": { "claw": "gabon", "target": "piel", "force": 30.0, "method": "puncion", "strike": true, "zone": "abdomen" } },
	{ "name": "Abeja picando la palma: el veneno queda en la grasa", "params": { "claw": "abeja", "target": "piel", "force": 0.00575, "method": "puncion", "zone": "palma" } },
	{ "name": "Uña stiletto tumbada (ataque de 20°), 10 N sobre el pino: ara en vez de cortar", "params": { "geom": "stiletto", "target": "madera", "force": 10.0, "attack_deg": 20.0 } },
	{ "name": "Uña cuadrada de gancho (ataque de 150°), 30 N sobre el pino: aguanta y corta", "params": { "geom": "cuadrada", "target": "madera", "force": 30.0, "attack_deg": 150.0 } },
	{ "name": "Garra de gato tumbada (ataque de 20°) sobre el ABS: cuña en vez de corte", "params": { "claw": "gato", "target": "plastico", "force": 15.0, "attack_deg": 20.0 } },
	{ "name": "Colmillo de víbora rayando el cobre: el esmalte de la punta lo marca", "params": { "claw": "vibora", "target": "cobre", "force": 4.0 } },
	{ "name": "Uña con diamante mojada, 10 N sobre el vidrio: la placa húmeda se dobla", "params": { "inlay": "diamante", "target": "vidrio", "force": 10.0, "wet": true } },
	{ "name": "Velocirraptor, golpe en el brazo: la garra topa con el húmero", "params": { "claw": "velociraptor", "target": "piel", "force": 381.5, "method": "puncion", "strike": true } },
	{ "name": "Velocirraptor rayando el coche moderno: la queratina no corta el acero", "params": { "claw": "velociraptor", "target": "coche", "force": 381.5 } },
	{ "name": "Velocirraptor de diamante afilado a media escala rayando el acero: entra más y la punta se mella", "params": { "claw": "velociraptor", "inlay": "diamante", "target": "acero", "force": 381.5, "sharpness": 0.5 } },
	{ "name": "Velocirraptor de cine rayando el coche moderno (ficción): la garra de película raja la chapa", "params": { "claw": "velociraptor_pelicula", "target": "coche", "force": 1841.0 } },
	{ "name": "Velocirraptor de cine, golpe contra el coche moderno (ficción): la garra de película perfora la chapa", "params": { "claw": "velociraptor_pelicula", "target": "coche", "force": 1841.0, "method": "puncion", "strike": true } },
]


func _init() -> void:
	var records := build()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("no se puede escribir %s" % OUT)
		quit(1)
		return
	file.store_string(to_json(records) + "\n")
	file.close()
	var changed := changed_vs_v1(records)
	var main := verdict_or_depth_changed(records)
	print("%s: %d escenarios (%d de la 1.x y %d nuevos de la 2.0)" % [OUT, records.size(), records.size() - EXTRA_SCENARIOS.size(),
		EXTRA_SCENARIOS.size()])
	if changed.is_empty():
		print("Los %d escenarios de la 1.x dan lo mismo que en el golden 1.x." % (records.size() - EXTRA_SCENARIOS.size()))
	else:
		print("Escenarios de la 1.x que cambian con la 2.0 (explica cada uno en docs/FISICA.md → «Cambios de la 2.0»):")
		for line in changed:
			print("  · " + line)
		print("De ellos, %d cambian el veredicto o la profundidad:" % main.size())
		for line in main:
			print("  · " + line)
	quit(0)


## Parámetros de un ensayo con los valores por defecto del golden 1.x (norm() de export-fixtures.mjs) y, solo si el
## escenario los trae, los de la 2.0: la zona del cuerpo (`zone`), el ángulo de ataque (`attack_deg`, en grados) y el
## afilado (`sharpness`, 0-1).
static func normalize(p: Dictionary) -> Dictionary:
	var out := {
		"geom": p.get("geom", "almendra"), "base": p.get("base", "natural"), "inlay": p.get("inlay", "none"),
		"target": p.target, "force": float(p.force), "length": float(p.get("length", 25.0)), "type": p.get("type", "aranazo"),
		"claw": p.get("claw"), "tear": bool(p.get("tear", false)), "method": p.get("method", "rayado"),
		"strike": bool(p.get("strike", false)), "passes": float(p.get("passes", 1.0)), "wet": bool(p.get("wet", false)),
	}
	if p.get("zone") != null:
		out["zone"] = String(p.zone)
	if p.get("attack_deg") != null:
		out["attack_deg"] = float(p.attack_deg)
	if p.get("sharpness") != null:
		out["sharpness"] = float(p.sharpness)
	return out


## Los escenarios del golden 2.0: { name, params } de los 40 del golden 1.x y, detrás, los nuevos (extra: los de la
## 2.0; los tests prueban el mecanismo con otros).
static func scenarios(extra: Array = EXTRA_SCENARIOS) -> Array:
	var out: Array = []
	for g: Dictionary in Case.load_json(SOURCE):
		out.append({ "name": g.name, "params": normalize(g.params) })
	for s: Dictionary in extra:
		out.append({ "name": s.name, "params": normalize(s.params) })
	return out


## Entrada del catálogo de la 2.0 (key: "GEOMS", "CLAWS"…) con ese id, o null si id es null.
static func find(key: String, id: Variant) -> Variant:
	if id == null:
		return null
	var hit: Variant = Catalog.find_by_id(Catalog.list(key), id)
	assert(hit != null, "golden 2.0: «%s» no está en Catalog.%s" % [id, key])
	return hit


## Los parámetros de compute() para unos params con ids, con la física 2.0 (y la zona y el ataque, si los trae).
static func compute_params(p: Dictionary) -> Dictionary:
	var q := {
		"geom": find("GEOMS", p.geom), "base": find("BASES", p.base), "inlay": find("INLAYS", p.inlay),
		"claw": find("CLAWS", p.get("claw")), "target": find("TARGETS", p.target), "type": find("TYPES", p.type),
		"force": p.force, "length": p.length, "tear": p.tear, "method": p.method, "strike": p.strike,
		"passes": p.passes, "wet": p.wet, "model": MODEL,
	}
	for k in ["zone", "attack_deg", "sharpness"]:
		if p.get(k) != null:
			q[k] = p[k]
	return q


## Todas las entradas del golden 2.0, en orden (los logros se acumulan a lo largo de la serie).
static func build(extra: Array = EXTRA_SCENARIOS) -> Array:
	var out: Array = []
	var badges := {}
	var list := scenarios(extra)
	for i in list.size():
		var s: Dictionary = list[i]
		var rec := record(s.params)
		var q := compute_params(s.params)
		# los logros de la aplicación con la física 2.0: los de la 1.x y los de lo nuevo de la 2.0 (unidad 4p: Lab.BADGES_V2)
		badges = Lab.earn_badges_model(badges, {
			"res": rec.result, "target": q.target, "inlay": q.inlay, "claw": q.claw, "method": q.method, "strike": q.strike,
			"runs": i + 1,
		}, MODEL)
		var entry := { "name": s.name }
		entry.merge(rec)
		entry["badgesAfter"] = badges.keys()
		out.append(entry)
	return out


## Un ensayo y todo lo que la interfaz saca de él (trial() de export-fixtures.mjs): { params, result, sfx, toolLabel,
## damage?, damageStage? }.
static func record(p: Dictionary) -> Dictionary:
	var q := compute_params(p)
	var target: Dictionary = q.target
	var result := Physics.compute(q)
	var out := {
		"params": p, "result": result, "sfx": SfxInsects.sfx_for_result(result, target),
		"toolLabel": Lab.tool_label({ "claw": q.claw, "geom": q.geom, "inlay": q.inlay, "res": result }),
	}
	if Js.truthy(target.get("body")) or Js.truthy(target.get("pane")) or Js.truthy(target.get("thickness")):
		out["damage"] = Lab.damage_report(result, target, p.length)
	if Js.truthy(target.get("body")):
		out["damageStage"] = Lab.damage_stage(result)
	return out


## Escenarios de la 1.x cuyo resultado 2.0 difiere del golden 1.x (con la política del oráculo), sin contar los campos que
## solo existen en la 2.0 (Physics.V2_FIELDS: en la 1.x no están): «nombre: campo».
static func changed_vs_v1(records: Array) -> Array[String]:
	var out: Array[String] = []
	var golden: Array = Case.load_json(SOURCE)
	var checker: RefCounted = Case.new()
	for i in golden.size():
		var got: Dictionary = (records[i].result as Dictionary).duplicate()
		for k: String in Physics.V2_FIELDS:
			got.erase(k)
		var d: Array[String] = checker.oracle_diff(got, golden[i].result, "result")
		if not d.is_empty():
			out.append("%s: %s" % [golden[i].name, d[0]])
	return out


## Escenarios de la 1.x en los que la 2.0 cambia el veredicto o la profundidad bajo carga: «nombre: 1.x → 2.0».
static func verdict_or_depth_changed(records: Array) -> Array[String]:
	var out: Array[String] = []
	var golden: Array = Case.load_json(SOURCE)
	for i in golden.size():
		var a: Dictionary = golden[i].result
		var b: Dictionary = records[i].result
		var depth_a := float(Case.decode(a.depthUm))
		var depth_b := float(b.depthUm)
		if a.verdict != b.verdict or not Case.near(depth_b, depth_a):
			out.append("%s: %s · %s → %s · %s" % [golden[i].name, a.verdict, Js.js_num_str(depth_a), b.verdict, Js.js_num_str(depth_b)])
	return out


# ── JSON como JSON.stringify de JavaScript ──

## Texto JSON de v sin espacios, con las claves en su orden, los números con String(n) de JavaScript y los no finitos
## como { "$num": "NaN" | "Infinity" | "-Infinity" } (el `enc` de export-fixtures.mjs).
static func to_json(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var x: float = v
			if not is_finite(x):
				return "{\"$num\":\"%s\"}" % Js.js_num_str(x)
			return Js.js_num_str(x)
		TYPE_STRING, TYPE_STRING_NAME:
			return _quote(String(v))
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for k in v:
				parts.append(_quote(String(k)) + ":" + to_json(v[k]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var items := PackedStringArray()
			for x in v:
				items.append(to_json(x))
			return "[" + ",".join(items) + "]"
	push_error("golden 2.0: valor que no se puede escribir en JSON (%s)" % type_string(typeof(v)))
	return "null"


## Un texto entre comillas con los escapes de JSON.stringify (los caracteres no ASCII van tal cual).
static func _quote(s: String) -> String:
	var out := PackedStringArray()
	for i in s.length():
		var c := s.unicode_at(i)
		match c:
			0x22:
				out.append("\\\"")
			0x5C:
				out.append("\\\\")
			0x08:
				out.append("\\b")
			0x0C:
				out.append("\\f")
			0x0A:
				out.append("\\n")
			0x0D:
				out.append("\\r")
			0x09:
				out.append("\\t")
			_:
				out.append("\\u%04x" % c if c < 0x20 else s[i])
	return "\"" + "".join(out) + "\""
