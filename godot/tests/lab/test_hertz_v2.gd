## El pico de Hertz en el resultado del modelo 2.0 (unidad 4p; docs/FISICA.md, «Cambios de la 2.0»): p0MPa, hertzRadiusUm y
## hertzYield (Physics._hertz, Johnson 1985).
## 1. El caso de la 4n: la uña almendra a 4 N sobre el vidrio. La presión media F/A es de 4,44 MPa, pero la punta solo toca en
##    un círculo de ~81 µm de radio, con un pico de ~294 MPa en su centro; la queratina ya pasa de su límite elástico.
## 2. El contrato: los campos existen en los dos modelos, a null en la 1.x, y en la 2.0 solo hay pico con un sólido homogéneo,
##    sin golpe y con el contacto elástico o a medias (φ < 1).
## 3. Invariantes: el pico siempre pasa de la media F/A y es 1,5 veces la media de su círculo; el círculo cabe en la esfera
##    de la punta; más fuerza nunca da menos pico ni un círculo menor; quién cede, con los umbrales del motor; en una chapa o
##    una hoja, el círculo es pequeño frente a su espesor (como un semiespacio).
## 4. Los textos de la tarjeta: la presión media y el pico, la frase que dice cuál es cuál y su fuente.
extends "res://tests/case.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const BenchTexts = preload("res://core/lab/bench_texts.gd")
const Contact = preload("res://core/shared/contact.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const Format = preload("res://core/shared/format.gd")

const V2 := Physics.MODEL_V2
const V1 := Physics.MODEL_V1
const FIELDS := ["p0MPa", "hertzRadiusUm", "hertzYield"]


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Los parámetros de siempre (almendra natural, 25 mm, arañazo, rayado, modelo 2.0) con los ids que se pidan encima.
static func P(over: Dictionary) -> Dictionary:
	var p := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, String(over.get("geom", "almendra"))),
		"base": Catalog.find_by_id(Catalog.BASES, String(over.get("base", "natural"))),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, String(over.get("inlay", "none"))),
		"claw": Catalog.find_by_id(Catalog.CLAWS, String(over.claw)) if over.has("claw") else null,
		"target": T(String(over.get("target", "vidrio"))), "type": Catalog.find_by_id(Catalog.TYPES, "aranazo"),
		"force": float(over.get("force", 4.0)), "length": 25.0, "tear": bool(over.get("tear", false)),
		"method": String(over.get("method", "rayado")), "strike": bool(over.get("strike", false)), "passes": 1.0,
		"wet": bool(over.get("wet", false)), "model": String(over.get("model", V2)),
	}
	if over.has("zone"):
		p["zone"] = over.zone
	return p


## Herramientas variadas: uñas de varias formas y materiales, una gema y garras y colmillos, con y sin reforjar.
static func tools() -> Array:
	return [{}, { "geom": "stiletto" }, { "geom": "cuadrada" }, { "wet": true }, { "geom": "cuadrada", "base": "zafiro" },
		{ "geom": "redonda", "base": "gel" }, { "base": "metal" }, { "inlay": "diamante" }, { "inlay": "vidrio" },
		{ "claw": "gato" }, { "claw": "oso" }, { "claw": "buitre", "inlay": "acero" }, { "claw": "vibora" },
		{ "claw": "aguila", "inlay": "zafiro", "tear": true }]


static func with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


func test_la_una_almendra_sobre_el_vidrio() -> void:
	var q := P({ "target": "vidrio", "force": 4.0 })
	var r := Physics.compute(q)
	var r1 := Physics.compute(with(q, { "model": V1 }))
	# Hertz a mano (Johnson 1985): la esfera de la punta de la almendra (0,9 mm²) contra el vidrio, con ν = 0,3
	var tool := Physics.resolve_tool(q)
	var radius := sqrt(0.9 / PI)
	var nu := 0.3
	var estar := 1000.0 / ((1.0 - nu * nu) * (1.0 / 2.9 + 1.0 / 72.0))  # MPa: E de la uña 2,9 GPa y del vidrio 72
	var load: float = 4.0 + float(r.Fadh_mN) / 1000.0  # la fuerza y la adhesión de Van der Waals, como el motor
	var a := pow(3.0 * load * radius / (4.0 * estar), 1.0 / 3.0)
	var p0 := 3.0 * load / (2.0 * PI * a * a)
	assert_near(float(tool.E), 2.9, 1e-12, 0.0, "módulo de la uña")
	assert_near(r.p0MPa, p0, 1e-9, 0.0, "el pico de Hertz: %s MPa" % r.p0MPa)
	assert_near(r.hertzRadiusUm, a * 1000.0, 1e-9, 0.0, "el radio del círculo de contacto: %s µm" % r.hertzRadiusUm)
	assert_near(r.p0MPa, 293.8, 0.002, 0.0, "~294 MPa, los que dijo la 4n")
	assert_near(r.hertzRadiusUm, 80.6, 0.002, 0.0, "~81 µm de radio")
	# la presión media del motor es F/A, la fuerza repartida por toda la punta: 66 veces menos que el pico
	assert_near(r.pressure, 4.4445, 1e-4, 0.0, "la media F/A: %s MPa" % r.pressure)
	assert_eq(r.pressure, r.pNominal, "en un contacto elástico la media es la nominal (sin tope)")
	assert_true(float(r.p0MPa) / float(r.pressure) > 60.0, "el pico pasa de largo a la media")
	# la queratina (25 HV) empieza a ceder cuando p0·√(1+3μ²) pasa de 1,6·Y = 1,6·H/2,8 = 140 MPa: es la punta la que cede
	assert_eq(r.hertzYield, "punta", "cede la uña, no el vidrio")
	assert_eq(r.phi, 0.0, "el vidrio sigue elástico (φ = 0, como siempre)")
	# lo de siempre no cambia: el veredicto, la profundidad y la presión de la 1.x
	assert_eq([r.verdict, r.depthUm, r.pressure], [r1.verdict, r1.depthUm, r1.pressure], "el ensayo es el de la 1.x")
	for k: String in FIELDS:
		assert_true(r1.has(k) and r1[k] == null, "1.x: «%s» a null" % k)
	# apretando (sin rozar) el pico es el mismo: la fricción no cambia la presión normal, solo adelanta la cesión
	var rp := Physics.compute(with(q, { "method": "puncion" }))
	assert_near(rp.p0MPa, r.p0MPa, 1e-12, 0.0, "punzando, el mismo pico")


func test_contrato_de_los_campos() -> void:
	var n := 0
	var hits := 0
	var methods := [["rayado", false], ["puncion", false], ["puncion", true]]
	for t: Dictionary in Catalog.TARGETS:
		for tl: Dictionary in tools():
			for m: Array in methods:
				for f in [0.5, 4.0, 30.0, 300.0]:
					var q := P(with(tl, { "target": t.id, "method": m[0], "strike": m[1], "force": f }))
					var r := Physics.compute(q)
					var r1 := Physics.compute(with(q, { "model": V1 }))
					var where := "%s → %s %s%s %s N" % [tl, t.id, m[0], " con golpe" if m[1] else "", f]
					n += 1
					for k: String in FIELDS:
						assert_true(r.has(k), "%s: «%s» existe en la 2.0" % [where, k])
						assert_true(r1.has(k) and r1[k] == null, "%s: «%s» a null en la 1.x" % [where, k])
					var p0: Variant = r.p0MPa
					assert_eq(p0 == null, r.hertzRadiusUm == null, "%s: el pico y el radio van juntos" % where)
					if p0 == null:
						assert_eq(r.hertzYield, null, "%s: sin pico, nadie cede por Hertz" % where)
						continue
					hits += 1
					assert_false(Physics.truthy(t.get("skin")), "%s: en la piel no hay contacto de Hertz" % where)
					assert_false(Physics.truthy(t.get("layers")), "%s: con pintura o laca, tampoco" % where)
					assert_false(m[1], "%s: en un golpe el contacto plastifica" % where)
					assert_true(float(r.phi) < 1.0, "%s: el material no plastifica del todo" % where)
					assert_true([null, "punta", "objetivo", "las dos"].has(r.hertzYield), "%s: hertzYield %s" % [where, r.hertzYield])
	assert_true(hits > 100 and hits < n, "con pico de Hertz: %d de %d ensayos" % [hits, n])
	# una piel con otra zona y un aguijón, tampoco
	for q: Dictionary in [P({ "target": "piel", "zone": "palma", "force": 4.0 }), P({ "claw": "abeja", "target": "vidrio", "force": 0.005, "method": "puncion" })]:
		var r := Physics.compute(q)
		for k: String in FIELDS:
			assert_true(r.has(k) and r[k] == null, "%s: «%s» a null" % [q.target.id, k])


func test_invariantes_del_pico() -> void:
	var seen := 0
	for t: Dictionary in Catalog.TARGETS:
		if Physics.truthy(t.get("skin")) or Physics.truthy(t.get("layers")):
			continue
		for tl: Dictionary in tools():
			for method: String in ["rayado", "puncion"]:
				var prev_p0 := 0.0
				var prev_a := 0.0
				for f in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 60.0, 120.0, 300.0]:
					var q := P(with(tl, { "target": t.id, "method": method, "force": f }))
					var r := Physics.compute(q)
					var where := "%s → %s %s %s N" % [tl, t.id, method, f]
					if r.p0MPa == null:
						continue
					seen += 1
					var p0: float = r.p0MPa
					var a_mm: float = float(r.hertzRadiusUm) / 1000.0
					var tool := Physics.resolve_tool(q)
					var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
					# el pico pasa de la media F/A (el círculo es más pequeño que la punta) y cabe en su esfera
					assert_true(p0 > float(r.pressure), "%s: el pico (%s) pasa de la media F/A (%s)" % [where, p0, r.pressure])
					assert_true(a_mm <= float(tip.at) + 1e-12 and a_mm < float(tip.R), "%s: el círculo cabe en la esfera de la punta" % where)
					# p0 es 1,5 veces la media del círculo: la carga entera, F·(palanca), reconstruida desde el pico (con una uña
					# que cede, a la punta solo llega su carga de cesión: no se reconstruye aquí)
					var nail: Variant = r.get("nail")
					if not (nail is Dictionary and nail.broken):
						var load := p0 * PI * a_mm * a_mm / 1.5
						var lever := Physics.tear_leverage(q.claw) if Physics.truthy(q.get("tear")) and method == "rayado" else 1.0
						assert_near(load, (f + float(r.Fadh_mN) / 1000.0) * lever, 1e-9, 0.0, "%s: la carga del círculo" % where)
					# quién cede, con los umbrales del motor: φ del material (el de la tarjeta) y el de la punta con su dureza
					var f_mu := 1.0 if method == "puncion" else sqrt(1.0 + 3.0 * float(t.mu) * float(t.mu))
					var h_tip: float = float(tool.hv) * Contact.HV_MPA
					if FangEnamel.applies(tool):
						h_tip = FangEnamel.tip_hv(tool, a_mm) * Contact.HV_MPA
					var tip_yields := p0 * f_mu > Contact.CONTACT.yieldOnset * h_tip / Contact.CONTACT.tabor
					var target_yields := float(r.phi) > 0.0
					var want: Variant = null
					if tip_yields and target_yields:
						want = "las dos"
					elif tip_yields:
						want = "punta"
					elif target_yields:
						want = "objetivo"
					assert_eq(r.hertzYield, want, "%s: quién pasa de su límite elástico" % where)
					# en una chapa o una hoja el círculo es pequeño frente al espesor: vale el semiespacio de Hertz
					var thick: Variant = t.get("thickness")
					if thick != null:
						assert_true(a_mm <= 0.25 * float(thick), "%s: círculo de %s mm en %s mm" % [where, a_mm, thick])
					# más fuerza nunca da menos pico ni un círculo menor (p0 ∝ F^(1/3), a ∝ F^(1/3))
					assert_true(p0 >= prev_p0 and a_mm >= prev_a, "%s: más fuerza, más pico y más círculo" % where)
					prev_p0 = p0
					prev_a = a_mm
	assert_true(seen > 200, "ensayos con pico: %d" % seen)


func test_textos_de_la_tarjeta() -> void:
	var r := Physics.compute(P({ "target": "vidrio", "force": 4.0 }))
	var rows := BenchTexts.pressure_rows(r)
	assert_eq(rows.size(), 2, "dos filas")
	assert_eq([rows[0][0], rows[0][2]], ["Presión media", "%s MPa" % Format.fmt_p(r.pressure)], "la media F/A")
	assert_eq([rows[1][0], rows[1][2]], ["Pico de Hertz", "%s MPa" % Format.fmt_p(r.p0MPa)], "el pico")
	assert_true(String(rows[0][1]).contains("toda la punta"), "la media dice que reparte la fuerza por toda la punta")
	assert_true(String(rows[1][1]).contains(Format.fmt_depth(r.hertzRadiusUm)) and String(rows[1][1]).contains("cota alta"),
		"el pico dice su círculo y que es una cota alta: %s" % rows[1][1])
	var note := BenchTexts.hertz_note(r)
	for part: String in ["%s MPa" % Format.fmt_p(r.pressure), "%s MPa" % Format.fmt_p(r.p0MPa), Format.fmt_depth(r.hertzRadiusUm),
		"toda la punta", "la punta ya pasa de su límite elástico", "%s MPa" % Format.fmt_p(25.0 * Contact.HV_MPA)]:
		assert_true(note.contains(part), "la frase dice «%s»: %s" % [part, note])
	# las otras tres maneras de ceder (o ninguna), cada una con su frase
	var fake := r.duplicate()
	for c: Array in [[null, "no queda huella"], ["objetivo", "el material ya pasa"], ["las dos", "la punta y el material"]]:
		fake["hertzYield"] = c[0]
		assert_true(BenchTexts.hertz_note(fake).contains(c[1]), "%s: %s" % [c[0], BenchTexts.hertz_note(fake)])
		var cota := String(BenchTexts.pressure_rows(fake)[1][1]).contains("cota alta")
		assert_eq(cota, c[0] != null, "%s: cota alta solo si alguien cede" % c[0])
	# un frágil que se agrieta sin que nada ceda (la cuadrada de zafiro sobre el vidrio): la frase dice que las grietas de
	# Hertz no son huella, y solo entonces
	var hz_crack := Physics.compute(P({ "geom": "cuadrada", "base": "zafiro", "target": "vidrio", "force": 30.0 }))
	assert_eq([hz_crack.verdict, hz_crack.hertzYield], ["GRIETAS DE HERTZ", null], "grietas de Hertz en contacto elástico")
	assert_true(BenchTexts.hertz_note(hz_crack).contains("no queda huella. Las grietas de Hertz no son huella"),
		BenchTexts.hertz_note(hz_crack))
	fake["hertzYield"] = null
	assert_false(BenchTexts.hertz_note(fake).contains("grietas"), "sin grietas, sin la frase de las grietas")
	# en «Fuentes y estimaciones», con su fuente (Johnson 1985)
	var src := BenchTexts.sources(r, { "claw": null, "inlay": Catalog.INLAYS[0], "target": T("vidrio") })
	var hz: Array = src.filter(func(x: Dictionary) -> bool: return String(x.label).begins_with("Contacto elástico"))
	assert_eq(hz.size(), 1, "una fila del contacto de Hertz")
	assert_eq(hz[0].quality, "model", "es un modelo publicado")
	assert_true(String(hz[0].source).begins_with("Johnson KL (1985)"), hz[0].source)
	# sin contacto elástico (la pintura, plástica), las filas de siempre y sin frase
	var rc := Physics.compute(P({ "target": "coche", "force": 30.0, "claw": "tigre" }))
	assert_eq(rc.p0MPa, null)
	assert_eq(BenchTexts.pressure_rows(rc)[0][0], "Presión real", "las filas de la 4n")
	assert_eq(BenchTexts.hertz_note(rc), "", "sin frase")
