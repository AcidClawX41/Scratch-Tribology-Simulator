## Física de los aguijones (core/lab/sting.gd): valores de referencia medidos, invariantes («más fuerza nunca da menos
## profundidad», «un material más rígido nunca pandea antes»…), anclaje y autotomía, durezas contra los sólidos del
## banco y los casos de referencia de la integración (tests/fixtures/spec/aguijones.json), comprobados contra la
## implementación de referencia: Sting.sting_report para el bloque `sting` y Sting.solid_params + el motor de siempre
## para los sólidos.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Insects = preload("res://core/lab/insects.gd")
const Sting = preload("res://core/lab/sting.gd")

const SPEC := "res://tests/fixtures/spec/aguijones.json"
## Rango medido de la fuerza de perforación de la abeja (A. cerana): 1,34 mN (Ling 2016), 2-3 mN en piel de cerdo
## (Zhao 2015) y 5,75 mN en piel de conejo (Ling 2017).
const BEE_MEASURED := [0.00134, 0.00575]
## Avispa papelera: 6-8 mN en piel de cerdo (Zhao 2015, Polistes sp.).
const PAPER_WASP_MEASURED := [0.006, 0.008]

var skin: Dictionary
var solids: Array = []


func before_each() -> void:
	if not skin.is_empty():
		return
	skin = T("piel")
	for t: Dictionary in Data.TARGETS:
		if not t.get("skin", false):
			solids.append(t)


static func S(id: String) -> Dictionary:
	return Insects.find_by_id(id)


static func T(id: String) -> Dictionary:
	return Data.find_by_id(Data.TARGETS, id)


static func I(id: String) -> Dictionary:
	return Data.find_by_id(Data.INLAYS, id)


## Parámetros de compute() con los valores por defecto del oráculo (norm() de export-fixtures.mjs).
static func params(claw: Dictionary, target: Dictionary, force: float, over: Dictionary = {}) -> Dictionary:
	var p := {
		"geom": Data.GEOMS[3], "base": Data.BASES[0], "inlay": Data.INLAYS[0], "claw": claw, "target": target,
		"force": force, "length": 25.0, "type": Data.TYPES[1], "tear": false, "method": "puncion", "strike": false,
		"passes": 1, "wet": false,
	}
	p.merge(over, true)
	return p


static func skin_depth(claw: Dictionary, f: float, inlay: Variant = null) -> float:
	return Sting.skin_sting({ "claw": claw, "inlay": inlay, "target": Data.find_by_id(Data.TARGETS, "piel"), "force": f }).depthUm


# ── 1 · Perforación ──

func test_el_ajuste_de_davis_no_sirve_para_un_aguijon() -> void:
	# con la punta de 1,25 µm de la abeja, Davis (physics.gd) cae a su mínimo de 0,08 N: 14-60 veces lo medido
	var bee := S("abeja")
	var davis := Physics.skin_puncture_force(bee.area)
	assert_eq(davis, Physics.MODEL.skinPunctureMin, "Davis se queda en su mínimo medido")
	assert_true(davis / BEE_MEASURED[1] > 10.0, "Davis pide más de 10 veces la mayor fuerza medida")
	assert_eq(Sting.davis_in_range(bee.area), 0.0, "fuera de su rango no se usa")
	assert_eq(Sting.puncture_regime(bee.area), "fractura", "para un aguijón manda la fractura")


func test_la_abeja_perfora_con_la_fuerza_medida() -> void:
	var f := Sting.puncture_force(S("abeja").area)
	assert_true(f >= BEE_MEASURED[0] and f <= BEE_MEASURED[1], "abeja: %s N dentro de 1,34-5,75 mN" % f)
	# 2·J·R con J = 1,7 kJ/m² (capa córnea, SKIN_LAYERS) y R = 1,25 µm: 4,25 mN, sin calibrar nada
	assert_near(f, 2.0 * 1.7 * 0.00125, 1e-12, 0.0, "F = 2·J·R")


func test_la_avispa_papelera_perfora_con_la_fuerza_medida() -> void:
	# la punta de Polistes se escala desde la abeja con la anchura de la lanceta (estimación): no se ajusta a los 6-8 mN
	var f := Sting.puncture_force(S("papelera").area)
	assert_true(f >= PAPER_WASP_MEASURED[0] * 0.75 and f <= PAPER_WASP_MEASURED[1] * 1.3, "papelera: %s N en 6-8 mN ±25 %%" % f)
	assert_true(f > Sting.puncture_force(S("abeja").area), "la avispa necesita más fuerza que la abeja (Zhao 2015)")


func test_la_ley_de_perforacion_no_cambia_ninguna_herramienta_del_banco() -> void:
	# uñas (formas), gemas y garras: manda Davis, así que la 2.0 da exactamente lo mismo que la 1.x
	var areas: Array = []
	for g: Dictionary in Data.GEOMS:
		areas.append(g.area)
	for i: Dictionary in Data.INLAYS.slice(1):
		areas.append(i.area)
	for c: Dictionary in Data.CLAWS:
		areas.append(c.area)
	for a: float in areas:
		assert_eq(Sting.puncture_force(a), Physics.skin_puncture_force(a), "área %s: la misma fuerza que Davis" % a)
		assert_eq(Sting.puncture_regime(a), "davis", "área %s: régimen de Davis" % a)


func test_la_ley_de_perforacion_es_continua_y_creciente() -> void:
	var prev := 0.0
	var a := 1e-8
	while a < 20.0:
		var f := Sting.puncture_force(a)
		assert_true(f >= prev, "una punta más ancha nunca pide menos fuerza (área %s)" % a)
		if prev > 0.0:
			assert_true(f / prev < 1.1, "sin saltos entre áreas vecinas (área %s: ×%s)" % [a, f / prev])
		prev = f
		a *= 1.01


# ── 2 · Profundidad y capa ──

func test_mas_fuerza_nunca_da_menos_profundidad_en_la_piel() -> void:
	for c: Dictionary in Insects.STINGERS:
		for inlay: Variant in [null, I("acero"), I("diamante"), I("oro")]:
			var prev := -1.0
			var f := 1e-4
			while f <= 5.0:
				var d := skin_depth(c, f, inlay)
				assert_true(d >= prev, "%s (%s): %s N no da menos profundidad" % [c.id, inlay.id if inlay else "natural", f])
				prev = d
				f *= 1.2


func test_la_profundidad_es_la_longitud_util_y_la_capa_la_de_la_piel() -> void:
	var want := {
		"abeja": "dermis", "avispa": "dermis", "papelera": "dermis", "abejorro": "dermis",
		"avispon": "grasa", "velutina": "grasa", "hormigabala": "grasa", "pepsis": "grasa",
	}
	for c: Dictionary in Insects.STINGERS:
		var r := Sting.skin_sting({ "claw": c, "inlay": null, "target": skin, "force": c.force })
		assert_true(r.pierces, "%s: perfora con su empuje típico" % c.id)
		assert_eq(r.depthUm, c.reach * 1000.0, "%s: entra hasta el bulbo" % c.id)
		assert_eq(r.layerId, want[c.id], "%s: capa alcanzada" % c.id)
	# la abeja deja el veneno en la dermis, no en el subcutáneo (Ramirez-Esquivel 2023)
	var bee := Sting.skin_sting({ "claw": S("abeja"), "inlay": null, "target": skin, "force": S("abeja").force })
	assert_true(bee.depthUm > 75.0 and bee.depthUm < 2200.0, "abeja: más allá de la epidermis y antes de la grasa")


func test_el_empuje_tipico_perfora_sin_pandear() -> void:
	# un insecto que pica de verdad empuja entre la fuerza de perforación y la de pandeo
	for c: Dictionary in Insects.STINGERS:
		var fp := Sting.puncture_force(c.area)
		var fcr: float = Sting.buckling(c).F
		assert_true(fp < c.force, "%s: el empuje típico (%s N) rompe la piel (%s N)" % [c.id, c.force, fp])
		assert_true(c.force < fcr, "%s: el empuje típico no dobla el aguijón (%s N)" % [c.id, fcr])


# ── 3 · Pandeo ──

func test_fbreak_del_catalogo_es_el_pandeo_del_modelo() -> void:
	for c: Dictionary in Insects.STINGERS:
		assert_near(c.fBreak, Sting.buckling(c).F, 1e-5, 0.0, "%s: fBreak = carga de pandeo de Euler" % c.id)
		assert_eq(Sting.buckling(c).mode, "euler", "%s: la quitina pandea elásticamente (λ > λc)" % c.id)


func test_el_pandeo_de_la_abeja_reproduce_la_medida() -> void:
	# Ling 2016 midió 6,72 mN en A. cerana, cuyo aguijón mide 1,62 mm (Das 2018): sin ajustar nada, Euler da ~5,7 mN
	var bee := S("abeja")
	var e := Sting.graded_modulus(bee.stinger.material)
	var f: float = Sting.buckling_load(e, Sting.column_material(bee).yield, Sting.section(bee.stinger), 1.62).F
	assert_near(f, bee.stinger.bucklingN.value, 0.3, 0.0, "pandeo de A. cerana ±30 %%: %s N" % f)
	# y el de A. mellifera (1,32 mm libres) es del mismo orden
	var fm: float = Sting.buckling(bee).F
	assert_true(fm > 0.5 * bee.stinger.bucklingN.value and fm < 2.0 * bee.stinger.bucklingN.value, "A. mellifera: mismo orden")


func test_el_modulo_con_gradiente_lo_decide_la_base() -> void:
	var mat: Dictionary = S("abeja").stinger.material
	var e := Sting.graded_modulus(mat)
	assert_true(e < mat.base.E and e > mat.mid.E, "E efectivo entre el de la base y el del medio: %s" % e)
	assert_near(Sting.BUCKLE_W_BASE + Sting.BUCKLE_W_MID + Sting.BUCKLE_W_TIP, 1.0, 1e-12, 0.0, "los pesos suman 1")
	var uniform := { "tip": { "E": 2.0, "H": 0.1 }, "mid": { "E": 2.0, "H": 0.1 }, "base": { "E": 2.0, "H": 0.1 } }
	assert_near(Sting.graded_modulus(uniform), 2.0, 1e-12, 0.0, "sin gradiente, el E del material")


func test_un_material_mas_rigido_nunca_pandea_antes() -> void:
	var sec := Sting.section(S("abeja").stinger)
	# con el mismo límite elástico, más E nunca da menos carga (Euler ∝ E; la parábola de Johnson crece con E)
	for y: float in [30.0, 150.0, 700.0, 7000.0]:
		var prev := 0.0
		var e := 0.1
		while e < 2000.0:
			var f: float = Sting.buckling_load(e, y, sec, 1.32).F
			assert_true(f >= prev, "Y %s MPa, E %s GPa: no pandea antes" % [y, e])
			prev = f
			e *= 1.3
	# con el mismo E, más límite elástico tampoco
	for e2: float in [2.0, 70.0, 200.0]:
		var prev2 := 0.0
		var y2 := 10.0
		while y2 < 20000.0:
			var f2: float = Sting.buckling_load(e2, y2, sec, 1.32).F
			assert_true(f2 >= prev2, "E %s GPa, Y %s MPa: no pandea antes" % [e2, y2])
			prev2 = f2
			y2 *= 1.3
	# y con los materiales del banco, para la geometría de cada aguijón: si un material es a la vez más rígido y de
	# mayor límite elástico (Y = H/2,8), nunca pandea antes
	for c: Dictionary in Insects.STINGERS:
		for a: Dictionary in Data.INLAYS.slice(1):
			for b: Dictionary in Data.INLAYS.slice(1):
				if a.E >= b.E and a.hv >= b.hv:
					assert_true(Sting.buckling(c, a).F >= Sting.buckling(c, b).F, "%s: %s (E %s) no pandea antes que %s (E %s)" % [c.id, a.id, a.E, b.id, b.E])
			assert_true(Sting.buckling(c, a).F > Sting.buckling(c).F, "%s: reforjado en %s aguanta más que la quitina" % [c.id, a.id])


func test_mas_rigido_no_basta_el_oro_cede_antes_que_el_vidrio() -> void:
	# el oro es más rígido que el vidrio (79 frente a 70 GPa) pero muy blando (30 HV, Y ≈ 105 MPa): en la columna
	# robusta de una avispa (λ ≈ 79) plastifica antes de pandear (Johnson) y cede antes que el vidrio, que pandea
	# elásticamente. En la abeja, más esbelta (λ ≈ 112), la plasticidad apenas recorta y el oro aguanta más.
	var wasp := S("avispa")
	var gold := Sting.buckling(wasp, I("oro"))
	var glass := Sting.buckling(wasp, I("vidrio"))
	assert_eq(gold.mode, "johnson", "el oro plastifica")
	assert_eq(glass.mode, "euler", "el vidrio pandea")
	assert_true(gold.F < glass.F, "avispa: el oro (%s N) cede antes que el vidrio (%s N)" % [gold.F, glass.F])
	var bee := S("abeja")
	assert_true(Sting.buckling(bee, I("oro")).F > Sting.buckling(bee, I("vidrio")).F, "abeja: el oro aguanta más que el vidrio")


func test_johnson_solo_manda_en_una_columna_blanda_y_corta() -> void:
	var bee := S("abeja")
	assert_eq(Sting.buckling(bee, I("oro")).mode, "johnson", "el oro (Y ≈ 105 MPa) plastifica antes de pandear")
	assert_eq(Sting.buckling(bee, I("acero")).mode, "euler", "el acero pandea elásticamente")
	var gold := Sting.buckling(bee, I("oro"))
	var sec := Sting.section(bee.stinger)
	var le_bee: float = 2.0 * bee.reach
	var euler: float = PI * PI * float(I("oro").E) * 1000.0 * float(sec.I) / (le_bee * le_bee)
	assert_true(gold.F < euler, "Johnson queda por debajo de Euler")
	assert_true(gold.lambda < gold.lambdaC, "λ < λc en Johnson")
	# en la transición las dos curvas coinciden (σ = Y/2)
	var y := 100.0
	var e := 80.0
	var lam_c := PI * sqrt(2.0 * e * 1000.0 / y)
	var le: float = lam_c * sec.rg
	var at_c: float = Sting.buckling_load(e, y, sec, le / 2.0).F
	assert_near(at_c, 0.5 * y * sec.A, 1e-9, 0.0, "en λc la carga es (Y/2)·A por los dos lados")


func test_en_la_piel_el_aguijon_pandea_solo_si_la_piel_aguanta_mas() -> void:
	var bee := S("abeja")
	# con cualquier empuje, la piel cede (4,25 mN) antes de que el aguijón pandee (8,6 mN)
	for f: float in [0.001, 0.005, 0.01, 0.1, 1.0]:
		assert_false(Sting.skin_sting({ "claw": bee, "inlay": null, "target": skin, "force": f }).buckled, "abeja: %s N no la dobla" % f)
	# una piel 3 veces más tenaz (p. ej. callosa) pediría 12,8 mN: el aguijón de quitina pandea antes
	var tough := skin.duplicate(true)
	var stack: Array = Data.SKIN_LAYERS.duplicate(true)
	stack[0].jC = 5.1
	tough.tissue = stack
	var r := Sting.skin_sting({ "claw": bee, "inlay": null, "target": tough, "force": 0.02 })
	assert_true(r.buckled and not r.pierces, "piel más tenaz: pandea y no perfora")
	var steel := Sting.skin_sting({ "claw": bee, "inlay": I("acero"), "target": tough, "force": 0.02 })
	assert_true(steel.pierces and not steel.buckled, "la abeja de acero sí la perfora")


# ── 4 y 5 · Anclaje, clavado y autotomía ──

func test_la_abeja_se_queda_clavada_y_las_demas_se_retiran() -> void:
	for c: Dictionary in Insects.STINGERS:
		var r := Sting.skin_sting({ "claw": c, "inlay": null, "target": skin, "force": c.force })
		if c.id == "abeja":
			assert_true(r.stuck, "la abeja se queda clavada")
			assert_true(r.autotomy, "y pierde el aparato del aguijón")
			assert_true(r.anchorN >= 0.1135 and r.anchorN <= 0.13604, "fuerza de extracción en el rango medido: %s N" % r.anchorN)
			assert_true(r.pullToWeight > 100.0, "arrancarlo cuesta más de 100 veces su peso")
		else:
			assert_false(r.stuck, "%s: se retira" % c.id)
			assert_false(r.autotomy, "%s: no pierde el aguijón" % c.id)
	assert_eq(Sting.skin_sting({ "claw": S("avispa"), "inlay": null, "target": skin, "force": 0.0099 }).stuckRisk, "a veces", "la avispa común, a veces")


func test_la_regla_de_las_puas_reproduce_la_tabla_de_autotomia() -> void:
	# Bissessarsingh & Starr 2021 (Sr ≥ 1 u 8 púas o más) + enfundado (Mulfinger 1992) frente a la clase documentada
	var checked := 0
	for c: Dictionary in Insects.STINGERS:
		var b: Dictionary = c.stinger.barbs
		var rule := Sting.risk_from_serration(b.serrationIndex, b.perLancet, b.sheathable)
		if rule == "":
			continue
		checked += 1
		assert_eq(rule, Sting.stuck_risk(c), "%s: la regla de las púas coincide con la tabla" % c.id)
	assert_true(checked >= 6, "la regla se comprueba en las especies con datos de púas (%d)" % checked)


func test_las_puas_se_enganchan_en_la_piel_y_no_en_la_cuticula_ni_en_los_solidos() -> void:
	var bee := S("abeja")
	var a_skin := Sting.anchoring(bee, skin)
	assert_true(a_skin.engaged, "la piel se estira un %s y lo recupera (hasta 54 %%)" % a_skin.barbStrain)
	var a_cut := Sting.anchoring(bee, Sting.CUTICLE)
	assert_false(a_cut.engaged, "la cutícula de un insecto solo recupera un %s: la púa talla un surco" % a_cut.tissueStrain)
	assert_eq(a_cut.anchorN, 0.0, "sin enganche no hay fuerza de extracción")
	assert_false(Sting.withdrawal(bee, Sting.CUTICLE).stuck, "la abeja saca el aguijón de otro insecto (Tautz 2008)")
	assert_true(a_cut.barbStrain > a_cut.tissueStrain, "el estiramiento que pide la púa supera el que recupera la cutícula")
	for t: Dictionary in solids:
		for c: Dictionary in Insects.STINGERS:
			if c.stinger.barbs.depthUm != null and c.stinger.barbs.depthUm > 0.0 and Sting.barb_strain(c.stinger) > 0.06:
				assert_false(Sting.anchoring(c, t).engaged, "%s no se engancha en %s" % [c.id, t.id])
	for t2: Dictionary in solids:
		assert_true(Sting.recoverable_strain(t2) < 0.06, "%s recupera menos del 6 %%" % t2.id)


func test_sin_puas_no_hay_anclaje() -> void:
	var r := Sting.anchoring(S("pepsis"), skin)
	assert_false(r.engaged, "Pepsis: lancetas lisas")
	assert_eq(r.anchorN, 0.0, "Pepsis: nada que enganchar")
	assert_true(r.barbsKnown, "se sabe que no tiene púas (no es un dato que falte)")


func test_el_material_no_cambia_ni_el_anclaje_ni_la_autotomia() -> void:
	var bee := S("abeja")
	var nat := Sting.skin_sting({ "claw": bee, "inlay": null, "target": skin, "force": bee.force })
	for i: Dictionary in Data.INLAYS.slice(1):
		var ref := Sting.skin_sting({ "claw": bee, "inlay": i, "target": skin, "force": bee.force })
		assert_eq(ref.fPunctureN, nat.fPunctureN, "abeja de %s: la misma fuerza de perforación (manda la geometría)" % i.id)
		assert_eq(ref.depthUm, nat.depthUm, "abeja de %s: la misma profundidad" % i.id)
		assert_eq(ref.stuck, nat.stuck, "abeja de %s: se queda clavada igual" % i.id)
		assert_eq(ref.autotomy, nat.autotomy, "abeja de %s: la autotomía es del abdomen" % i.id)
		assert_eq(ref.anchorN, nat.anchorN, "abeja de %s: el mismo anclaje" % i.id)
		assert_true(ref.fBuckleN > 20.0 * nat.fBuckleN, "abeja de %s: pandea mucho más tarde" % i.id)
		assert_true(ref.reforged and ref.material == i.id, "abeja de %s: se marca como reforjada" % i.id)


# ── 6 · Durezas ──

func test_ningun_aguijon_natural_raya_ni_perfora_los_solidos() -> void:
	for c: Dictionary in Insects.STINGERS:
		for t: Dictionary in solids:
			var rep: Dictionary = Sting.solid_sting({ "claw": c, "inlay": null, "target": t, "force": c.force })
			assert_true(rep.tipCrushed, "%s contra %s: la punta cede (r = %s)" % [c.id, t.id, rep.hardnessRatio])
			for method: String in ["puncion", "rayado"]:
				var r := Physics.compute(Sting.solid_params(params(c, t, c.force, { "method": method })))
				assert_false(Physics.truthy(r.scratched), "%s contra %s (%s): %s" % [c.id, t.id, method, r.verdict])
				assert_true(r.depthUm <= 1.0, "%s contra %s (%s): no entra (%s µm)" % [c.id, t.id, method, r.depthUm])


func test_sin_la_pared_celular_la_abeja_perforaria_el_pino() -> void:
	# por qué la 2.0 mira la dureza a la escala de la punta: con la del bloque (Janka, 2,5 HV), el motor 1.x dejaría
	# que una punta de 7 HV se hundiera en el pino
	var bee := S("abeja")
	var plain := Physics.compute(params(bee, T("madera"), bee.force, { "model": "1.x" }))
	assert_true(plain.depthUm > 1.0, "con la dureza del bloque entraría %s µm" % plain.depthUm)
	assert_eq(Sting.micro_hv(T("madera")), 45.9, "pared celular ~0,45 GPa")
	assert_eq(Sting.micro_hv(T("vidrio")), 550.0, "un sólido homogéneo: su dureza de siempre")
	assert_eq(Sting.micro_hv(T("puertamadera")), 45.9, "la puerta: laca (18 HV) y, debajo, la pared celular")


func test_un_aguijon_reforjado_duro_raya_los_solidos_mas_blandos() -> void:
	# el criterio de siempre (r ≳ 1,25; con r ≥ 2 la punta ya no se deforma): con la mitad de su carga de pandeo
	var n := 0
	for c: Dictionary in [S("abeja"), S("avispon")]:
		for i: Dictionary in Data.INLAYS.slice(1):
			for t: Dictionary in solids:
				var rep: Dictionary = Sting.solid_sting({ "claw": c, "inlay": i, "target": t, "force": 0.0 })
				if rep.hardnessRatio < 2.0:
					continue
				var f := minf(0.5 * rep.fBuckleN, 1.0)
				var r := Physics.compute(Sting.solid_params(params(c, t, f, { "inlay": i, "method": "rayado" })))
				assert_true(Physics.truthy(r.scratched), "%s de %s raya %s (r %s): %s" % [c.id, i.id, t.id, rep.hardnessRatio, r.verdict])
				n += 1
	assert_true(n > 50, "combinaciones comprobadas: %d" % n)


func test_mas_fuerza_nunca_da_menos_profundidad_en_los_solidos() -> void:
	# con el pandeo como límite de la herramienta (fBreak), la profundidad se congela al pandear, nunca baja
	var cases := [["abeja", "acero", "madera"], ["abeja", "diamante", "vidrio"], ["abeja", "oro", "plastico"], ["avispon", "zafiro", "acero"], ["abeja", "tungsteno", "cobre"]]
	for cs: Array in cases:
		var prev := -1.0
		var f := 0.001
		while f <= 10.0:
			var r := Physics.compute(Sting.solid_params(params(S(cs[0]), T(cs[2]), f, { "inlay": I(cs[1]) })))
			assert_true(r.depthUm >= prev - 1e-9, "%s de %s en %s: %s N no da menos profundidad" % [cs[0], cs[1], cs[2], f])
			prev = r.depthUm
			f *= 1.25


func test_los_parametros_para_solidos_no_vuelven_a_entrar_aqui() -> void:
	var p := params(S("abeja"), T("madera"), 0.5, { "inlay": I("acero"), "wet": true, "strike": true })
	var sp := Sting.solid_params(p)
	assert_false(sp.strike, "un aguijón no golpea: empuje estático")
	assert_false(sp.claw.has("stinger"), "sin el bloque stinger")
	assert_eq(sp.inlay.id, "none", "sin incrustación: el material ya va en la garra")
	assert_eq(sp.claw.hv, 200.0, "dureza del acero")
	assert_eq(sp.claw.E, 200.0, "módulo del acero")
	assert_near(sp.claw.fBreak, Sting.buckling(S("abeja"), I("acero")).F, 1e-12, 0.0, "fBreak = pandeo del acero")
	assert_eq(sp.target.hv, 45.9, "el pino con la dureza de su pared celular")
	assert_eq(sp.model, "1.x", "el motor de siempre")
	assert_false(sp.wet, "la cutícula no es queratina")
	assert_true(S("abeja").has("stinger"), "el catálogo no se toca")
	assert_eq(T("madera").hv, 2.5, "el catálogo no se toca")


# ── Veneno, giro y textos ──

func test_el_veneno_de_la_abeja_sale_en_un_minuto() -> void:
	var st: Dictionary = S("abeja").stinger
	assert_near(Sting.venom_fraction(st, 20.0), 0.9, 1e-12, 0.0, "90 % en 20 s (Schumacher 1994)")
	assert_true(Sting.venom_fraction(st, 60.0) >= 0.99, "todo en 1 min")
	assert_eq(Sting.venom_fraction(st, 0.0), 0.0, "nada antes de clavarlo")
	var prev := 0.0
	for k in 121:
		var fr := Sting.venom_fraction(st, k * 0.5)
		assert_true(fr >= prev and fr <= 1.0, "creciente y como mucho 1 (t = %s s)" % (k * 0.5))
		prev = fr
	# quitarlo a los 2 s deja pasar solo ~20 %: por eso cuenta la rapidez, no el método (Visscher 1996)
	var at2: float = Sting.venom_delivered_ug(st, 2.0)
	assert_true(at2 < 0.25 * st.venom.ug, "a los 2 s, menos de un cuarto del veneno: %s µg" % at2)
	var wasp: Dictionary = S("avispa").stinger
	assert_eq(Sting.venom_fraction(wasp, wasp.venom.totalS), 1.0, "la avispa lo inyecta durante la picadura")
	assert_eq(Sting.venom_delivered_ug(S("abejorro").stinger, 10.0), null, "sin dato, null")


func test_el_giro_helicoidal_de_la_abeja() -> void:
	var bee := S("abeja")
	assert_eq(Sting.twist_deg(bee.stinger, bee.reach * 1000.0, bee.reach), -8.4, "−8,4° con todo el aguijón dentro (Wu 2014)")
	assert_eq(Sting.twist_deg(bee.stinger, 0.0, bee.reach), 0.0, "sin girar antes de entrar")
	assert_eq(Sting.twist_deg(S("avispa").stinger, 1000.0, S("avispa").reach), null, "sin medida en la avispa")


func test_los_textos_usan_milinewtons_como_javascript() -> void:
	assert_eq(Sting.fmt_mn(0.000018), "0.02 mN", "mosquito (0,018 mN)")
	assert_eq(Sting.fmt_mn(0.00864), "8.6 mN", "pandeo de la abeja")
	assert_eq(Sting.fmt_mn(0.0864), "86 mN", "decenas sin decimales")
	var bee := S("abeja")
	var ok := Sting.skin_verdict(Sting.skin_sting({ "claw": bee, "inlay": null, "target": skin, "force": bee.force }))
	assert_eq(ok.verdict, "SE QUEDA CLAVADO", "veredicto de la abeja")
	var no_r := Sting.skin_sting({ "claw": bee, "inlay": null, "target": skin, "force": 0.001 })
	var no := Sting.skin_verdict(no_r)
	assert_eq(no.verdict, "NO PERFORA", "veredicto sin perforar")
	assert_true(String(no.vsub).contains(Sting.fmt_mn(no_r.fPunctureN)), "cita la fuerza que haría falta: %s" % no.vsub)
	var wasp := Sting.skin_verdict(Sting.skin_sting({ "claw": S("avispa"), "inlay": null, "target": skin, "force": 0.0099 }))
	assert_eq(wasp.verdict, "PICA Y SE VA", "veredicto de la avispa")
	assert_eq(Sting.sting_report(params(Data.CLAWS[0], skin, 10.0)), null, "una garra no tiene bloque sting")


# ── Casos de referencia de la integración ──

## Lo que compute() (modelo 2.0) tiene que devolver para un aguijón, según docs/fisica/aguijones.md: en la piel, los
## campos de siempre salen del bloque sting; en un sólido, del motor de siempre con solid_params.
func _reference_result(p: Dictionary) -> Dictionary:
	var rep: Dictionary = Sting.sting_report(p)
	if p.target.get("skin", false):
		var depth: float = rep.depthUm
		var epi: float = Data.find_by_id(Data.SKIN_LAYERS, "epidermis").to
		return {
			"pierces": rep.pierces, "depthUm": depth, "inject": true, "bleeds": rep.pierces and depth > epi,
			"layer": Physics.skin_layer_at(depth, Data.SKIN_LAYERS).name if rep.pierces else null,
			"fPuncture": rep.fPunctureN, "sting": rep,
		}
	var r := Physics.compute(Sting.solid_params(p))
	r["sting"] = rep
	return r


static func _at(root: Dictionary, path: String) -> Variant:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not cur.has(key):
			return "<falta>"
		cur = cur[key]
	return cur


func _check(got: Variant, exp: Dictionary, where: String) -> void:
	if exp.has("value"):
		var want: Variant = exp.value
		if want == null or typeof(want) == TYPE_BOOL or typeof(want) == TYPE_STRING:
			assert_eq(got, want, where)
		elif exp.has("tol"):
			assert_true(is_num(got), "%s: número (%s)" % [where, got])
			if is_num(got):
				assert_near(float(got), float(want), float(exp.tol), 0.0, where)
		else:
			assert_true(is_num(got) and float(got) == float(want), "%s: %s ≠ %s" % [where, got, want])
	if exp.has("min"):
		assert_true(is_num(got) and float(got) >= float(exp.min), "%s: %s ≥ %s" % [where, got, exp.min])
	if exp.has("max"):
		assert_true(is_num(got) and float(got) <= float(exp.max), "%s: %s ≤ %s" % [where, got, exp.max])


func test_casos_de_referencia_de_la_integracion() -> void:
	var cases: Variant = load_json(SPEC)
	assert_true(cases is Array and cases.size() >= 20, "el archivo de casos tiene al menos 20 casos")
	if not (cases is Array):
		return
	var ids := {}
	for cs: Dictionary in cases:
		assert_false(ids.has(cs.id), "id de caso repetido: %s" % cs.id)
		ids[cs.id] = true
		assert_true(String(cs.get("source", "")).length() > 5, "%s: tiene fuente" % cs.id)
		var inp: Dictionary = cs.input
		assert_eq(inp.get("model"), "2.0", "%s: caso del modelo 2.0" % cs.id)
		var p := {
			"geom": Data.find_by_id(Data.GEOMS, inp.geom), "base": Data.find_by_id(Data.BASES, inp.base),
			"inlay": Data.find_by_id(Data.INLAYS, inp.inlay), "claw": Insects.find_by_id(inp.claw),
			"target": Data.find_by_id(Data.TARGETS, inp.target), "type": Data.find_by_id(Data.TYPES, inp.type),
			"force": float(inp.force), "length": float(inp.length), "tear": inp.tear, "method": inp.method,
			"strike": inp.strike, "passes": inp.passes, "wet": inp.wet,
		}
		for k: String in ["geom", "base", "inlay", "claw", "target", "type"]:
			assert_true(p[k] != null, "%s: id válido en %s (%s)" % [cs.id, k, inp.get(k)])
		if p.claw == null or p.target == null:
			continue
		var r := _reference_result(p)
		for field: String in cs.expect:
			_check(_at(r, field), cs.expect[field], "%s · %s" % [cs.id, field])
