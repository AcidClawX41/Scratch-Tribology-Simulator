## Lo que aguantan de lado unas garras reforjadas clavadas en la chapa (unidad 4p; docs/fisica/coche-en-marcha.md §17):
## MovingCar.claws_hold_n con el menor de la flexión de la garra, su cortante (ClawFracture.shear_limit_n) y la chapa que se
## aplasta alrededor del agujero (MovingCar.sheet_bearing_n, EN 1993-1-3 y AISC 360-16), y el texto dice cuál manda.
## 1. Los casos a mano: los talones de tungsteno del águila clavados hasta la base en el coche moderno (antes «3.0 MN» por la
##    flexión con un brazo casi nulo; ahora manda la chapa, ~21 kN) y los de vidrio (manda el cortante de la garra); el
##    cortante, en la sección de la cara de fuera del metal, por donde ya ha pasado toda la carga de la chapa.
## 2. Invariantes: el límite nunca pasa del de la garra sola ni del de la flexión de antes; manda el menor; más espesor de chapa
##    nunca aguanta menos (en las chapas de carrocería, de 0,5 a 1,25 mm, y la banda desfavorable con cualquier espesor); lo que
##    aguanta la chapa crece con su espesor y con el diámetro de la garra.
## 3. Lo que se lee: la lectura «Garras clavadas» dice cuál manda y las fuentes del ensayo citan la regla de la chapa.
extends "res://tests/case.gd"

const MC = preload("res://core/lab/moving_car.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const CF = preload("res://core/lab/claw_fracture.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")

## Los animales que se quedan encima y los materiales con resistencia medida (los que dan un límite).
const ANIMALS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "tigre", "oso", "velociraptor", "velociraptor_pelicula"]
const MATERIALS := ["oro", "acero", "titanio", "tungsteno", "vidrio", "swarovski", "cuarzo", "circonita", "zafiro", "moissanita",
	"diamante", "rubi", "alumina"]
const CARS := ["coche", "cocheclasico", "cochealu"]


static func C(id: String) -> Dictionary:
	return ClawsV2.apply(Catalog.find_by_id(Catalog.CLAWS, id))


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


static func I(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.INLAYS, id)


## Un coche con su misma chapa (material, f_u) pero de otro espesor (mm), con la pintura de siempre.
static func with_sheet(car: String, t_mm: float) -> Dictionary:
	var t: Dictionary = T(car).duplicate(true)
	t.body.t = t_mm * 1000.0
	t.thickness = (float(Data.PAINT_LAYERS[-1].to) + t_mm * 1000.0) / 1000.0
	return t


func test_tungsteno_hasta_la_base_manda_la_chapa() -> void:
	var h: Dictionary = MC.claws_hold_n(C("aguila"), I("tungsteno"), T("coche"), 4)
	# a mano: la base de la garra, 0,15 × 35 mm de radio, en la chapa de 0,7 mm de acero de horno (Rm 340 MPa)
	var d := 2.0 * 0.15 * 35.0
	var kt := (0.8 * 0.7 + 1.5) / 2.5
	assert_near(h.dMm, d, 1e-12, 0.0, "el diámetro de la garra en la chapa: la base")
	assert_near(h.kt, kt, 1e-12, 0.0, "k_t de la chapa de 0,7 mm (la recta de EN 1993-1-3)")
	assert_near(h.value, 4.0 * 2.5 * kt * 340.0 * d * 0.7, 1e-12, 0.0, "las cuatro, ~20,6 kN: %s" % h.value)
	assert_near(h.max, 4.0 * 3.0 * 360.0 * d * 0.7, 1e-12, 0.0, "con todo a favor, 3·Rm·d·t con 360 MPa (AISC 360-16)")
	assert_eq([h.governs, h.governsMax], ["chapa", "chapa"], "manda la chapa")
	assert_true(h.atBase == true and h.depthMm == float(C("aguila").reach), "clavadas hasta la base")
	# la garra sola aguantaría mucho más: su cortante en la base (3068 MPa en 4V/3A) y, aún más, su flexión
	var shear := 3068.0 * 0.75 * PI * (d / 2.0) * (d / 2.0)
	assert_near(h.perClaw.shearN, shear, 1e-12, 0.0, "el cortante de una garra: ~199 kN")
	assert_true(4.0 * float(h.perClaw.bendN) > 3.0e6, "la flexión, con un brazo casi nulo, daba los «3.0 MN» de antes: %s" % h.perClaw.bendN)
	assert_true(float(h.value) < 30000.0, "ni rastro de los «3.0 MN» de antes: %s" % h.value)
	assert_true(MC.claws_hold_txt(h).begins_with("manda la chapa: se aplasta alrededor del agujero con ~5148 N por garra"), MC.claws_hold_txt(h))
	# lo peor: la punta recién asomada, donde la garra es fina y la flexión manda (el caso aguila-tungsteno-techo-clavada)
	assert_eq(h.governsMin, "flexion", "recién asomada, manda la flexión")
	assert_near(h.min, 567.1133, 1e-5, 0.0, "las cuatro recién asomadas: ~567 N, como antes")
	# y el agarre sigue mandando en el anclaje (2 pies × 101 N): no se suelta ni a 400 km/h
	var s := MC.setup({ "claw": Catalog.find_by_id(Catalog.CLAWS, "aguila"), "target": T("coche"), "zone": "techo",
		"posture": "plegadas", "embedded": true, "inlay": "tungsteno" })
	assert_near(s.anchorN.value, 201.8, 0.001, 0.0, "el anclaje es el agarre")
	assert_true(MC.detach(s).never, "no se suelta")


func test_vidrio_se_cizalla_antes_que_la_chapa() -> void:
	var h: Dictionary = MC.claws_hold_n(C("aguila"), I("vidrio"), T("coche"), 4)
	var r := 0.15 * 35.0
	assert_eq(h.governs, "cortante", "manda el cortante de la garra")
	assert_near(h.value, 4.0 * 45.0 * 0.75 * PI * r * r, 1e-12, 0.0, "4 × 45 MPa × 3πr²/4: ~11,7 kN")
	assert_true(MC.claws_hold_txt(h).begins_with("manda la garra: se cizalla a la altura de la chapa"), MC.claws_hold_txt(h))
	# una dúctil fluye a cortante con σ/√3 (von Mises): el acero, si mandara
	var tip := MC.claw_tip(C("aguila"), I("acero"))
	var st: Dictionary = CF.strength("acero")
	var x := MC.load_point_mm(Physics.sheet_of(T("coche")), float(tip.reach))
	assert_near(CF.shear_limit_n(tip, x, float(st.value), "fluencia"), float(st.value) / sqrt(3.0) * 0.75 * PI * r * r, 1e-12, 0.0,
		"el acero, con la tensión de flujo de Tabor entre √3")
	assert_near(MC.claws_hold_n(C("aguila"), I("acero"), T("coche"), 4).perClaw.shearN, float(st.value) / sqrt(3.0) * 0.75 * PI * r * r,
		1e-12, 0.0, "y es el que mira claws_hold_n, en la base")


func test_el_cortante_es_el_de_la_cara_de_fuera_del_metal() -> void:
	# recién asomada, la carga de la chapa entra por toda la parte clavada (de la punta a la cara de fuera del metal, una chapa
	# entera) y el cortante es el de la sección por donde ya ha pasado toda: con la presión repartida por el espesor, como en la
	# regla de la chapa (en un cono, el mismo en toda la parte clavada); la flexión, con la carga a media chapa
	var sheet: Dictionary = Physics.sheet_of(T("coche"))
	var t_metal := float(sheet.to) - float(sheet.from)
	for m: String in ["acero", "titanio", "vidrio", "zafiro", "tungsteno"]:
		for aid: String in ["aguila", "oso", "tigre"]:
			var claw := C(aid)
			var nc: int = MC.body_of(claw).contact
			var tip := MC.claw_tip(claw, I(m))
			var st: Dictionary = CF.strength(m)
			var h: Dictionary = MC.claws_hold_n(claw, I(m), T("coche"), nc, float(sheet.to))
			assert_near(h.perClaw.shearN, CF.shear_limit_n(tip, t_metal, float(st.value), String(st.kind)), 1e-12, 0.0,
				"%s %s: el cortante, a una chapa del vértice" % [aid, m])
			# más arriba la garra es más gruesa: el cortante de la cara de fuera aguanta más que el del plano medio
			assert_true(float(h.perClaw.shearN) > CF.shear_limit_n(tip, 0.5 * t_metal, float(st.value), String(st.kind)),
				"%s %s: más que a media chapa" % [aid, m])


func test_invariantes() -> void:
	var n := 0
	for aid: String in ANIMALS:
		var claw := C(aid)
		var body: Variant = MC.body_of(claw)
		var nc: int = body.contact
		for car: String in CARS:
			var sheet: Dictionary = Physics.sheet_of(T(car))
			for m: String in MATERIALS:
				var inl := I(m)
				var st: Variant = CF.strength(m)
				for embed: float in [INF, 1.0, 5.0, 20.0]:
					var h: Variant = MC.claws_hold_n(claw, inl, T(car), nc, embed)
					if st == null:
						assert_eq(h, null, "%s: sin resistencia, sin límite" % m)
						continue
					n += 1
					var where := "%s %s %s clavada %s" % [aid, car, m, embed]
					var tip := MC.claw_tip(claw, inl)
					var reach: float = tip.reach
					var x_val := MC.load_point_mm(sheet, maxf(minf(embed, reach), float(sheet.to)))
					var x_min := MC.load_point_mm(sheet, float(sheet.to))
					# nunca pasa de lo que aguanta la garra sola (su flexión y su cortante) ni de la flexión de antes
					var bend_val: float = float(st.value) / float(CF.peak(tip, reach, x_val).factor)
					var bend_min: float = float(st.min) / float(CF.peak(tip, reach, x_min).factor)
					var bend_max: float = float(st.max) / float(CF.peak(tip, reach, x_val).factor)
					assert_true(float(h.value) <= float(h.clawN) * (1.0 + 1e-12), "%s: no pasa de la garra sola" % where)
					assert_true(float(h.value) <= nc * bend_val * (1.0 + 1e-12), "%s: no pasa de la flexión de antes" % where)
					assert_true(float(h.min) <= nc * bend_min * (1.0 + 1e-12), "%s: ni recién asomada" % where)
					assert_true(float(h.max) <= nc * bend_max * (1.0 + 1e-12), "%s: ni con todo a favor" % where)
					assert_true(float(h.value) <= float(h.sheetN) * (1.0 + 1e-12), "%s: ni de lo que aguanta la chapa" % where)
					# manda el menor, y el texto lo dice
					var pc: Dictionary = h.perClaw
					var low := minf(float(pc.bendN), minf(float(pc.shearN), float(pc.bearingN)))
					assert_near(h.value, nc * low, 1e-12, 0.0, "%s: el menor de los tres" % where)
					var want := "chapa" if float(pc.bearingN) <= minf(float(pc.bendN), float(pc.shearN)) else (
						"cortante" if float(pc.shearN) <= float(pc.bendN) else "flexion")
					assert_eq(h.governs, want, "%s: manda %s" % [where, want])
					var txt := MC.claws_hold_txt(h)
					assert_true(txt.begins_with("manda la chapa" if want == "chapa" else "manda la garra"), "%s: %s" % [where, txt])
					# la banda contiene al valor
					assert_true(float(h.min) <= float(h.value) * (1.0 + 1e-12) and float(h.value) <= float(h.max) * (1.0 + 1e-12),
						"%s: banda %s ≤ %s ≤ %s" % [where, h.min, h.value, h.max])
	assert_true(n > 500, "límites comprobados: %d" % n)


func test_mas_chapa_nunca_aguanta_menos() -> void:
	var checked := 0
	for aid: String in ANIMALS:
		var claw := C(aid)
		var nc: int = MC.body_of(claw).contact
		for car: String in CARS:
			for m: String in MATERIALS:
				if CF.strength(m) == null:
					continue
				# clavadas hasta la base, en las chapas de carrocería (de 0,5 a 1,25 mm): el valor y las dos bandas
				var prev := {}
				for t_mm: float in [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.25]:
					var h: Dictionary = MC.claws_hold_n(claw, I(m), with_sheet(car, t_mm), nc)
					checked += 1
					for k: String in ["value", "min", "max"]:
						if prev.has(k):
							assert_true(float(h[k]) >= float(prev[k]) * (1.0 - 1e-12), "%s %s %s: %s mm, %s baja de %s a %s" % [
								aid, car, m, t_mm, k, prev[k], h[k]])
						prev[k] = h[k]
				# la banda desfavorable (la punta recién asomada por detrás), con cualquier espesor
				var prev_min := 0.0
				for t_mm: float in [0.3, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0]:
					var h: Dictionary = MC.claws_hold_n(claw, I(m), with_sheet(car, t_mm), nc)
					assert_true(float(h.min) >= prev_min * (1.0 - 1e-12), "%s %s %s: recién asomada, %s mm baja" % [aid, car, m, t_mm])
					prev_min = h.min
	assert_true(checked > 1000, "chapas comprobadas: %d" % checked)
	# la chapa sola: más espesor o una garra más gruesa, siempre más (también por encima de 1,25 mm, donde k_t = 1)
	for car: String in CARS:
		for which: String in ["value", "min", "max"]:
			var prev := 0.0
			for t_mm: float in [0.3, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]:
				var f := MC.sheet_bearing_n(with_sheet(car, t_mm), 5.0, which)
				assert_true(f > prev, "%s %s: la chapa de %s mm aguanta más (%s)" % [car, which, t_mm, f])
				prev = f
			assert_true(MC.sheet_bearing_n(T(car), 6.0, which) > MC.sheet_bearing_n(T(car), 3.0, which), "%s: garra más gruesa" % car)
	assert_near(MC.bearing_kt(0.75), 0.84, 1e-12, 0.0, "k_t al empezar la norma")
	assert_near(MC.bearing_kt(1.25), 1.0, 1e-12, 0.0, "k_t = 1 desde 1,25 mm")
	assert_eq(MC.bearing_kt(3.0), 1.0, "y por encima")
	assert_eq(MC.sheet_bearing_n(T("cocheplastico"), 5.0), INF, "el plástico no tiene f_u: la regla de la chapa no limita")


func test_lo_que_se_lee() -> void:
	var st: RefCounted = MCS.new(Catalog.find_by_id(Catalog.CLAWS, "aguila"), T("coche"))
	st.threaded = false
	st.set_inlay("tungsteno")
	st.set_embedded(true)
	st.finish()
	var rd: Array = st.hold_readings().filter(func(r: Dictionary) -> bool: return r.id == "clavadas")
	assert_eq(rd.size(), 1, "la lectura de las garras clavadas")
	var r: Dictionary = rd[0]
	assert_eq(r.value, "20.6 kN", "lo que aguantan las cuatro: %s" % r.value)
	assert_true(String(r.sub).contains("hundidas hasta la base · manda la chapa: se aplasta alrededor del agujero"), r.sub)
	assert_true(String(r.sub).contains("lo peor: la punta recién asomada"), r.sub)
	assert_eq(r.quality, "estimate", "la regla de la chapa es una estimación con el caso medido más parecido")
	assert_true(String(r.source).contains("EN 1993-1-3") and String(r.source).contains("AISC 360-16"), r.source)
	var src: Array = st.sources().filter(func(x: Dictionary) -> bool: return String(x.label).begins_with("Chapa alrededor del agujero"))
	assert_eq(src.size(), 1, "en las fuentes, la chapa alrededor del agujero")
	assert_true(String(src[0].value).contains("Rm 340 MPa (de 290 a 360)"), src[0].value)

