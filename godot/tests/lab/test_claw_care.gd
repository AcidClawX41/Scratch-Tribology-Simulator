## Cetrería y cuidado de garras (unidad 5a): contrato del modelo e invariantes físicas de core/lab/claw_care.gd, sus
## datos (claw_care_data.gd) y su tutorial (claw_care_tutorial.gd). Los casos con número y cálculo a mano están en
## tests/fixtures/spec/cetreria.json (test_claw_care_spec.gd); aquí, sobre todo, lo que nunca puede pasar.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")

const QUALITIES := ["primary", "secondary", "estimate", "dibujo"]
const STEEL_FILES := ["lima_bastarda", "lima_entrefina", "lima_fina"]
const HARD_INLAYS := ["hematites", "cuarzo", "circonita", "zafiro", "moissanita", "tungsteno", "diamante"]
const Sfx = preload("res://core/lab/sfx.gd")


func _fx(x: float, d := 3) -> String:
	return _Js.to_fixed(x, d)


## Una garra con la carne viva a cover_mm de la punta: un corte limpio, sin la grieta de un cortaúñas (negativo: dentro
## de la carne viva).
func _short(animal: String, cover_mm: float, setup: Dictionary = {}) -> ClawCare:
	var s := setup.duplicate()
	s["animal"] = animal
	var c := ClawCare.new(s)
	c._cut_to(c.apex_mm() - (c.quick_cover_mm() - cover_mm))
	return c


## Posición del flanco (at_mm desde la punta) a s mm de la base.
func _at(c: ClawCare, s: float) -> float:
	return c.apex_mm() - s


# ════════ Datos ════════

func test_cada_dato_lleva_fuente_y_calidad() -> void:
	var entries: Array = []
	for hid: String in CareData.HUMIDITY_IDS:
		entries.append(["queratina %s" % hid, CareData.KERATIN[hid]])
	for key: String in CareData.THERMAL:
		entries.append(["calor %s" % key, CareData.THERMAL[key]])
	for aid: String in CareData.ANIMAL_IDS:
		var a: Dictionary = CareData.ANIMALS[aid]
		for key: String in ["core_ratio", "growth_mm_day", "layers", "regrow_days"]:
			if a.has(key):
				entries.append(["%s %s" % [aid, key], a[key]])
	for tid: String in CareData.TOOL_IDS:
		entries.append(["herramienta %s" % tid, CareData.TOOLS[tid]])
	for key: String in CareData.HEMOSTASIS:
		entries.append(["hemostasia %s" % key, CareData.HEMOSTASIS[key]])
	for pair: Array in [
		["entre capas", CareData.INTERLAMINAR], ["escama", CareData.PEEL_DEPTH], ["grano crítico", CareData.CRITICAL_GRAIN_UM],
		["diente", CareData.TOOTH_GEOMETRY], ["grano", CareData.GRAIN_GEOMETRY], ["carne viva", CareData.CORE_RATIO],
		["carne viva (mamíferos)", CareData.CORE_RATIO_MAMMAL],
	]:
		entries.append(pair)
	for pair: Array in entries:
		var e: Dictionary = pair[1]
		assert_true(String(e.get("source", "")).length() > 20, "%s: fuente" % pair[0])
		assert_true(QUALITIES.has(String(e.get("quality", ""))), "%s: calidad %s" % [pair[0], e.get("quality")])
		if e.has("min") and e.has("max") and e.has("value") and typeof(e.value) != TYPE_STRING:
			assert_true(float(e.min) <= float(e.value) and float(e.value) <= float(e.max), "%s: el valor dentro de su banda" % pair[0])
	for key: String in CareData.SEDATION:
		assert_true(String(CareData.SEDATION[key].source).length() > 20, "sujeción %s: fuente" % key)
	# los identificadores y las claves son los mismos
	assert_eq(CareData.ANIMAL_IDS.size(), CareData.ANIMALS.size(), "un animal por id")
	for aid: String in CareData.ANIMAL_IDS:
		assert_eq(String(CareData.ANIMALS[aid].id), aid, "id de %s" % aid)
		assert_false(CareData.claw_entry(String(CareData.ANIMALS[aid].claw)).is_empty(), "%s: su garra está en el banco" % aid)
	assert_eq(CareData.TOOL_IDS.size(), CareData.TOOLS.size(), "una herramienta por id")
	for tid: String in CareData.TOOL_IDS:
		assert_eq(String(CareData.TOOLS[tid].id), tid, "id de %s" % tid)
	for rid: String in CareData.RAPTOR_IDS:
		assert_false(CareData.claw_entry(rid).is_empty(), "rapaz %s en el banco" % rid)
	# la tabla de la lesión térmica: más caliente, antes
	var tab: Array = CareData.INJURY_TABLE
	for i in range(1, tab.size()):
		assert_true(float(tab[i][0]) > float(tab[i - 1][0]) and float(tab[i][1]) < float(tab[i - 1][1]), "Moritz & Henriques: fila %d" % i)


# ════════ Estado inicial ════════

func test_se_crea_cada_animal() -> void:
	for aid: String in CareData.ANIMAL_IDS:
		var c := ClawCare.new({ "animal": aid })
		var snap := c.snapshot()
		var claw: Dictionary = snap.claw
		assert_true(float(claw.lengthMm) > float(claw.naturalMm), "%s: empieza con crecimiento de más" % aid)
		assert_true(float(claw.quickMm) > 0.0 and float(claw.quickMm) < float(claw.naturalMm), "%s: la carne viva dentro de la garra" % aid)
		assert_near(float(snap.tip.tipRadiusUm), float(snap.tip.naturalUm), 1e-12, 0.0, "%s: la punta natural" % aid)
		assert_eq(c.report().verdict, "larga", "%s: sin tocar, larga" % aid)
		assert_false(bool(snap.damage.broken) or bool(snap.bleeding.active), "%s: sana" % aid)
		print("    (info) %s: largo %s mm, natural %s, carne viva a %s, punta %s µm" % [aid, _fx(float(claw.lengthMm)), _fx(float(claw.naturalMm)), _fx(float(claw.quickMm)), _fx(float(snap.tip.tipRadiusUm))])
	# ajustes desconocidos: los de por defecto
	var d := ClawCare.new({ "animal": "grifo", "claw": "?", "inlay": "?", "humidity": "?", "sedation": "?" })
	assert_eq(d.setup().animal, "rapaz", "animal desconocido: la rapaz")
	assert_eq(d.setup().inlay, "none", "material desconocido: queratina")
	assert_eq(d.setup().humidity, "natural", "humedad desconocida: natural")
	assert_eq(d.setup().sedation, "sujecion", "sujeción desconocida: la del animal")


func test_la_carne_viva_hasta_la_punta_del_hueso() -> void:
	var e := ClawCare.new({ "animal": "rapaz" })
	assert_near(float(e.snapshot().claw.quickMm), 0.699 * 35.0, 1e-12, 0.0, "águila: 0,699 × 35 mm (Hedrick 2019)")
	var v := ClawCare.new({ "animal": "velociraptor" })
	assert_near(float(v.snapshot().claw.quickMm), 0.699 * 92.7, 1e-12, 0.0, "velocirraptor: el hueso fósil de la reconstrucción")
	for aid: String in CareData.ANIMAL_IDS:
		var band: Dictionary = CareData.ANIMALS[aid].core_ratio
		var L := float(CareData.claw_entry(String(CareData.ANIMALS[aid].claw)).reach)
		var lo := ClawCare.new({ "animal": aid, "quick": "min" })
		var hi := ClawCare.new({ "animal": aid, "quick": "max" })
		assert_near(float(lo.snapshot().claw.quickMm), float(band.min) * L, 1e-12, 0.0, "%s: banda baja" % aid)
		assert_near(float(hi.snapshot().claw.quickMm), float(band.max) * L, 1e-12, 0.0, "%s: banda alta" % aid)
		var seen := {}
		for seed: String in ["a", "b", "c", "d", "e"]:
			var h1 := ClawCare.new({ "animal": aid, "quick": "oculta", "seed": seed })
			var h2 := ClawCare.new({ "animal": aid, "quick": "oculta", "seed": seed })
			var q := float(h1.snapshot().claw.quickMm)
			assert_eq(q, float(h2.snapshot().claw.quickMm), "%s: la misma semilla, el mismo sitio" % aid)
			assert_true(q >= float(band.min) * L - 1e-9 and q <= float(band.max) * L + 1e-9, "%s: oculta dentro de la banda" % aid)
			seen[q] = true
		assert_true(seen.size() > 1, "%s: semillas distintas, sitios distintos" % aid)


# ════════ Invariante 1: limar más nunca alarga ════════

func test_limar_mas_nunca_alarga() -> void:
	for aid: String in CareData.ANIMAL_IDS:
		var alpha := ClawCare.new({ "animal": aid }).tip_alpha_deg()
		for angle: float in [90.0, alpha + 8.0, maxf(alpha - 3.0, 2.0)]:
			var c := ClawCare.new({ "animal": aid })
			var prev := c.apex_mm()
			var removed := 0.0
			var ok := true
			for k in 40:
				c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": angle, "force_n": 6.0, "travel_mm": 40.0 })
				var sn := c.snapshot()
				if c.apex_mm() > prev + 1e-12 or float(sn.claw.removedMm3) < removed - 1e-12:
					ok = false
				prev = c.apex_mm()
				removed = float(sn.claw.removedMm3)
			assert_true(ok, "%s a %s°: la garra nunca crece ni recupera volumen" % [aid, _fx(angle, 0)])
			assert_true(removed > 0.0, "%s a %s°: la lima arranca" % [aid, _fx(angle, 0)])
		# el flanco y el torno tampoco la alargan
		var f := ClawCare.new({ "animal": aid })
		var p0 := f.apex_mm()
		for k in 10:
			f.file({ "tool": "lija_p180", "zone": "flanco", "at_mm": 2.0 + float(k), "force_n": 4.0, "travel_mm": 40.0 })
			f.file({ "tool": "torno", "zone": "punta", "angle_deg": 45.0, "force_n": 0.5, "dwell_s": 0.2 })
			assert_true(f.apex_mm() <= p0 + 1e-12, "%s: flanco y torno no alargan" % aid)
			p0 = f.apex_mm()


# ════════ Invariante 2: un grano más grueso arranca más en cada pasada ════════

func test_grano_mas_grueso_arranca_mas() -> void:
	var tools: Dictionary = {}
	for tid: String in CareData.TOOL_IDS:
		tools[tid] = CareData.tool(tid)
	var pairs := [
		["lima_bastarda", "lima_entrefina"], ["lima_entrefina", "lima_fina"], ["lima_diamante_gruesa", "lima_diamante_fina"],
		["lija_p180", "lija_p240"],
	]
	for hum: String in CareData.HUMIDITY_IDS:
		var h := ClawCare.hardness_mpa(32.0, hum)
		for w: float in [0.3, 1.0, 2.4, 6.0]:
			for f: float in [0.5, 3.0, 10.0]:
				for pr: Array in pairs:
					var coarse := ClawCare.removal_mm3(tools[pr[0]], f, 40.0, w, w, 32.0, h)
					var fine := ClawCare.removal_mm3(tools[pr[1]], f, 40.0, w, w, 32.0, h)
					assert_true(coarse >= fine, "%s: %s (%s) ≥ %s (%s) con %s N y %s mm" % [hum, pr[0], _fx(coarse, 5), pr[1], _fx(fine, 5), _fx(f, 1), _fx(w, 1)])
	# y en la garra: la primera pasada de frente sobre la cara de un corte (en la punta natural toca una sola fila de
	# dientes con cualquier lima y arrancan lo mismo)
	var got := {}
	for tid: String in ["lima_bastarda", "lima_fina", "lima_diamante_gruesa", "lima_diamante_fina", "lija_p180", "lija_p240"]:
		var c := ClawCare.new({ "animal": "rapaz" })
		c._cut_to(c.apex_mm() - c.overgrowth_left_mm())
		got[tid] = float(c.file({ "tool": tid, "zone": "punta", "angle_deg": 90.0, "force_n": 3.0, "travel_mm": 40.0 }).removedMm3)
	assert_true(float(got.lima_bastarda) > float(got.lima_fina), "bastarda > fina en la garra")
	assert_true(float(got.lima_diamante_gruesa) > float(got.lima_diamante_fina), "diamante grueso > fino en la garra")
	assert_true(float(got.lija_p180) > float(got.lija_p240), "P180 > P240 en la garra")


# ════════ Invariante 3: en contra de las capas se deshoja antes ════════

func _peel_onset(humidity: String, direction: String) -> float:
	var f := 0.5
	while f <= 40.0:
		var c := ClawCare.new({ "animal": "rapaz", "humidity": humidity })
		if bool(c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": f, "travel_mm": 20.0, "direction": direction }).peeled):
			return f
		f += 0.5
	return INF


func test_en_contra_de_las_capas_se_deshoja_antes() -> void:
	var onset := {}
	for hum: String in CareData.HUMIDITY_IDS:
		var against := _peel_onset(hum, "en_contra")
		var back_forth := _peel_onset(hum, "vaiven")
		assert_true(is_finite(against), "%s: en contra se deshoja con fuerza suficiente" % hum)
		assert_false(is_finite(_peel_onset(hum, "a_favor")), "%s: a favor nunca se deshoja" % hum)
		assert_true(back_forth <= against, "%s: en vaivén, como en contra" % hum)
		onset[hum] = against
		print("    (info) %s: se deshoja en contra desde %s N" % [hum, _fx(against, 1)])
	for hum: String in CareData.HUMIDITY_IDS:
		assert_true(float(onset.empapada) <= float(onset[hum]), "empapada se deshoja antes que %s (Farran 2008)" % hum)
	assert_true(float(onset.empapada) < float(onset.natural), "empapada antes que natural")
	# la escama se quita limando a favor hasta su espesor
	var c := ClawCare.new({ "animal": "rapaz" })
	c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 30.0, "travel_mm": 20.0, "direction": "en_contra" })
	assert_false(c.snapshot().damage.peels.is_empty(), "queda una escama")
	for k in 60:
		c.file({ "tool": "lima_bastarda", "zone": "flanco", "at_mm": 1.0, "length_mm": 2.5, "force_n": 5.0, "travel_mm": 40.0 })
	assert_true(c.snapshot().damage.peels.is_empty(), "limando a favor, la escama se va")


# ════════ Invariante 4: seca se raja antes que mojada ════════

func test_seca_se_raja_mas_que_mojada() -> void:
	var split := {}
	for hum: String in CareData.HUMIDITY_IDS:
		var c := ClawCare.new({ "animal": "rapaz", "humidity": hum })
		split[hum] = float(c.clip({ "tool": "guillotina", "remove_mm": c.overgrowth_left_mm() }).splitMm)
	assert_true(float(split.seca) > float(split.natural), "seca raja más que natural")
	assert_true(float(split.natural) > float(split.humeda) and float(split.natural) > float(split.empapada), "natural raja más que mojada")
	print("    (info) grieta del cortaúñas de guillotina: seca %s, natural %s, húmeda %s, empapada %s mm" % [_fx(float(split.seca), 2), _fx(float(split.natural), 2), _fx(float(split.humeda), 2), _fx(float(split.empapada), 2)])
	# la de tijera raja más que la de guillotina (más cuña)
	var g := ClawCare.new({ "animal": "rapaz" })
	var t := ClawCare.new({ "animal": "rapaz" })
	assert_true(float(t.clip({ "tool": "tijera", "remove_mm": 3.0 }).splitMm) > float(g.clip({ "tool": "guillotina", "remove_mm": 3.0 }).splitMm), "la tijera raja más")
	# seca, la punta se mella (frágil); mojada, se aplasta (dúctil)
	assert_eq(ClawCare.keratin_strength("seca").kind, "flexion", "seca: frágil")
	assert_eq(ClawCare.keratin_strength("natural").kind, "flexion", "natural: frágil (6,7 %)")
	assert_eq(ClawCare.keratin_strength("empapada").kind, "fluencia", "empapada: dúctil (50,5 %)")
	# remojar marca el paso del tutorial
	var r := ClawCare.new({ "animal": "rapaz" })
	assert_false(r.check("remojada"), "sin remojar")
	r.set_humidity("empapada")
	assert_true(r.check("remojada"), "remojada")


# ════════ Invariante 5: más vueltas y más fuerza, más calor ════════

func _flank_peak(force: float, rpm: float, secs: float) -> float:
	var c := ClawCare.new({ "animal": "rapaz" })
	c.file({ "tool": "torno", "zone": "flanco", "at_mm": _at(c, 8.0), "force_n": force, "dwell_s": secs, "rpm": rpm })
	c.advance(30.0)
	return float(c.snapshot().thermal.peakQuickC)


func test_mas_vueltas_y_mas_fuerza_mas_calor() -> void:
	var prev_f := {}
	for rpm: float in [6500.0, 13000.0]:
		var prev := -INF
		for f: float in [0.25, 0.5, 1.0, 2.0]:
			var p := _flank_peak(f, rpm, 2.0)
			assert_true(p > prev, "%s rpm: con %s N más calor (%s °C)" % [_fx(rpm, 0), _fx(f, 2), _fx(p, 2)])
			prev = p
			if prev_f.has(f):
				assert_true(p > float(prev_f[f]), "%s N: a 13 000 rpm más calor que a 6500" % _fx(f, 2))
			prev_f[f] = p
	assert_near(ClawCare.heat_power_w(2.0, 4.0), 2.0 * ClawCare.heat_power_w(1.0, 4.0), 1e-12, 0.0, "P ∝ F")
	assert_near(ClawCare.heat_power_w(1.0, 8.0), 2.0 * ClawCare.heat_power_w(1.0, 4.0), 1e-12, 0.0, "P ∝ v")


func test_a_mano_la_lima_no_calienta() -> void:
	var c := _short("rapaz", 1.5)
	for k in 150:
		for tid: String in ["lima_bastarda", "lija_p180", "lima_diamante_gruesa"]:
			var r := c.file({ "tool": tid, "zone": "flanco", "at_mm": 2.0, "force_n": 8.0, "travel_mm": 40.0, "speed_mm_s": 300.0 })
			assert_eq(float(r.heatW), 0.0, "a mano no entra calor")
	assert_eq(float(c.snapshot().thermal.peakQuickC), float(CareData.THERMAL.bed_c.value), "la carne viva sigue a su temperatura")


func test_toques_cortos_con_pausas_calientan_menos() -> void:
	var cont := ClawCare.new({ "animal": "rapaz" })
	var pulses := ClawCare.new({ "animal": "rapaz" })
	cont.file({ "tool": "torno", "zone": "flanco", "at_mm": _at(cont, 8.0), "force_n": 0.5, "dwell_s": 4.0 })
	cont.advance(60.0)
	for k in 4:
		pulses.file({ "tool": "torno", "zone": "flanco", "at_mm": _at(pulses, 8.0), "force_n": 0.5, "dwell_s": 1.0 })
		pulses.advance(15.0)
	pulses.advance(15.0)
	var pc := float(cont.snapshot().thermal.peakQuickC)
	var pp := float(pulses.snapshot().thermal.peakQuickC)
	print("    (info) 4 s de torno en el flanco: seguidos %s °C, en toques de 1 s con 15 s de pausa %s °C" % [_fx(pc, 1), _fx(pp, 1)])
	assert_true(pp < pc, "con pausas, menos calor (Dremel)")
	assert_near(float(cont.snapshot().claw.removedMm3), float(pulses.snapshot().claw.removedMm3), 0.05, 0.0, "y casi lo mismo arrancado")


func test_lejos_de_la_carne_viva_no_llega_el_calor() -> void:
	var c := ClawCare.new({ "animal": "oso" })
	assert_true(c.quick_cover_mm() > float(CareData.THERMAL.max_depth_mm.value), "la carne viva está a más de 12 mm")
	c.file({ "tool": "torno", "zone": "punta", "angle_deg": 90.0, "force_n": 0.3, "dwell_s": 1.0 })
	assert_true(c.quick_cover_mm() > float(CareData.THERMAL.max_depth_mm.value), "sigue lejos")
	assert_near(float(c.snapshot().thermal.quickC), float(CareData.THERMAL.bed_c.value), 0.0, 1e-9, "no llega")
	assert_true(float(c.snapshot().thermal.faceC) > float(CareData.THERMAL.bed_c.value), "la cara sí se calienta")


func test_el_calor_sigue_la_solucion_estacionaria() -> void:
	# losa del flanco con el área del contacto: en régimen, θ_cara = P/(k·A/L + h·A) y la carne viva, en proporción
	var c := ClawCare.new({ "animal": "rapaz" })
	c._flank_contact_mm2 = 10.0
	var p := 0.02
	c._run(800.0, p, "flanco", 8.0, 0.5)
	var n: int = c._th.size()
	var n_live: int = c._th_live
	var dx := ClawCare.THERMAL_DX_MM / 1000.0
	var L := float(n - 1) * dx
	var a := 10.0e-6
	var k := ClawCare.keratin_conductivity()
	var h_air: float = CareData.THERMAL.h_air.value
	var face := p / (k * a / L + h_air * a)
	var sn := c.snapshot()
	var bed: float = CareData.THERMAL.bed_c.value
	assert_near(float(sn.thermal.faceC) - bed, face, 1e-6, 0.0, "cara en régimen")
	assert_near(float(sn.thermal.quickC) - bed, face * float(n_live) * dx / L, 1e-6, 0.0, "carne viva en régimen")
	# transitorio: flujo constante q en un sólido largo que pierde h·θ por la cara (Carslaw y Jaeger): para β = h·√(t/(k·ρ·c))
	# pequeño, θ = 2q·√(t/(π·k·ρ·c))·(1 − (√π/2)·β + (2/3)·β²); 5 % con la malla de 0,1 mm
	var d := ClawCare.new({ "animal": "rapaz" })
	d._flank_contact_mm2 = 10.0
	var s_far := d.apex_mm() - 1.0
	var t := 10.0
	d._run(t, p, "flanco", s_far, 0.5)
	assert_false(d._th_reach, "la carne viva, lejos: sólido largo")
	var rho_c: float = CareData.KERATIN_DENSITY * float(CareData.THERMAL.specific_heat_j_kg_k.value)
	var q := p / a
	var beta := h_air * sqrt(t / (k * rho_c))
	var want := 2.0 * q * sqrt(t / (PI * k * rho_c)) * (1.0 - 0.5 * sqrt(PI) * beta + 2.0 / 3.0 * beta * beta)
	var got := float(d.snapshot().thermal.faceC) - bed
	assert_near(got, want, 0.05, 0.0, "cara en el transitorio (%s frente a %s K)" % [_fx(got, 3), _fx(want, 3)])


# ════════ Invariante 6: cortar más allá de la carne viva siempre sangra ════════

func test_cortar_la_carne_viva_siempre_sangra() -> void:
	for aid: String in CareData.ANIMAL_IDS:
		for q: String in ["min", "valor", "max", "oculta"]:
			var st := { "animal": aid, "quick": q, "seed": "cetreria" }
			# con el cortaúñas
			var c := ClawCare.new(st)
			var r := c.clip({ "tool": "tenaza", "remove_mm": c.quick_cover_mm() + 0.05 })
			if not bool(r.cut):
				# (unidad 5l) la garra del oso y la del velocirraptor miden ~18 mm donde acaba la carne viva: cortarlas secas pide
				# ~10 kN y la mano con las tenazas no llega; remojadas, la queratina pide 5 veces menos y sí
				assert_true(float(r.forceN) > float(r.capacityN), "%s/%s: si no corta, es por la fuerza (%s > %s N)" % [aid, q, r.forceN, r.capacityN])
				c = ClawCare.new(st.merged({ "humidity": "humeda" }))
				r = c.clip({ "tool": "tenaza", "remove_mm": c.quick_cover_mm() + 0.05 })
			assert_true(bool(r.bled) and bool(c.snapshot().bleeding.active), "%s/%s: el corte en la carne viva sangra" % [aid, q])
			assert_true(c.report().verdict in ["corta_sangra", "rota"], "%s/%s: veredicto" % [aid, q])
			# de frente (con el torno: las garras grandes tienen mucha sección): sangra en cuanto la punta pasa de la carne viva
			var f := _short(aid, 0.3, st)
			var crossed_dry := false
			var bled := false
			for k in 400:
				var rr := f.file({ "tool": "torno", "zone": "punta", "angle_deg": 90.0, "force_n": 2.0, "dwell_s": 0.1 })
				if bool(rr.bled):
					bled = true
					break
				if f.quick_cover_mm() < -1e-9:
					crossed_dry = true
			assert_true(bled and not crossed_dry, "%s/%s: limando de frente sangra en cuanto llega" % [aid, q])
			# con una faceta
			var g := _short(aid, 0.3, st)
			var fb := false
			for k in 400:
				if bool(g.file({ "tool": "torno", "zone": "punta", "angle_deg": g.tip_alpha_deg() + 10.0, "force_n": 2.0, "dwell_s": 0.1 }).bled):
					fb = true
					break
			assert_true(fb, "%s/%s: la faceta que llega a la carne viva sangra" % [aid, q])
	# una garra reforjada no tiene carne viva: nunca sangra, aunque se corte donde estaría
	var z := ClawCare.new({ "animal": "rapaz", "inlay": "oro" })
	z._cut_to(0.5 * float(z.snapshot().claw.naturalMm))
	for k in 20:
		z.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 30.0, "force_n": 10.0, "travel_mm": 40.0 })
		z.file({ "tool": "torno", "zone": "flanco", "at_mm": 3.0, "force_n": 2.0, "dwell_s": 0.5 })
	assert_false(bool(z.snapshot().bleeding.bled), "la de oro no sangra")
	assert_eq(float(z.snapshot().thermal.peakQuickC), float(CareData.THERMAL.bed_c.value), "ni se calienta una carne viva que no tiene")
	assert_true(z.snapshot().claw.quickCoverMm == null, "sin carne viva: null")


func test_cerca_de_la_carne_viva_el_cortaunas_aprieta() -> void:
	var c := ClawCare.new({ "animal": "rapaz" })
	var r := c.clip({ "tool": "guillotina", "remove_mm": 11.3 })
	assert_true(bool(r.cut) and bool(r.crushed) and not bool(r.bled), "a 2,8 mm de la carne viva (menos de un radio) la aprieta sin cortarla")
	assert_false(bool(c.snapshot().bleeding.active) or bool(c.snapshot().damage.broken), "ni la raja")
	assert_near(float(c.snapshot().animal.maxPain), float(CareData.PAIN.quick_crush), 1e-12, 0.0, "y duele")
	# más cerca, la grieta de la cuña llega a la carne viva; remojada, raja menos y no llega
	var d := ClawCare.new({ "animal": "rapaz" })
	assert_true(bool(d.clip({ "tool": "guillotina", "remove_mm": 12.6 }).reachesQuick), "a 1,5 mm la raja hasta la carne viva")
	assert_eq(d.report().verdict, "rota", "rota")
	var n := ClawCare.new({ "animal": "rapaz" })
	var w := ClawCare.new({ "animal": "rapaz", "humidity": "empapada" })
	assert_true(bool(n.clip({ "tool": "guillotina", "remove_mm": 12.0 }).reachesQuick), "a 2,1 mm, a la humedad natural, llega")
	assert_false(bool(w.clip({ "tool": "guillotina", "remove_mm": 12.0 }).reachesQuick), "remojada, no")
	# cerca de la carne viva las garras grandes no caben en el cortaúñas de guillotina (7 mm); con tenazas, sí
	for aid: String in ["tigre", "oso", "velociraptor"]:
		var b := ClawCare.new({ "animal": aid })
		var deep := b.quick_cover_mm() - 1.0
		var rb := b.clip({ "tool": "guillotina", "remove_mm": deep })
		assert_false(bool(rb.cut), "%s: no cabe en la guillotina" % aid)
		assert_true(b.events().any(func(e: Dictionary) -> bool: return e.code == "no_cabe"), "%s: aviso" % aid)
		# con tenazas, sí; las garras de ~18 mm del oso y del velocirraptor, remojadas (unidad 5l: secas pide más fuerza de la
		# que da la mano por la palanca de las tenazas)
		var rt := ClawCare.new({ "animal": aid }).clip({ "tool": "tenaza", "remove_mm": deep })
		if not bool(rt.cut):
			assert_true(float(rt.forceN) > float(rt.capacityN), "%s: si no corta seca, es por la fuerza" % aid)
			rt = ClawCare.new({ "animal": aid, "humidity": "humeda" }).clip({ "tool": "tenaza", "remove_mm": deep })
		assert_true(bool(rt.cut), "%s: con tenazas sí" % aid)
	var bear := ClawCare.new({ "animal": "oso" })
	assert_false(bool(bear.clip({ "tool": "guillotina", "remove_mm": bear.overgrowth_left_mm() }).cut), "la garra del oso no cabe ni en su sobrante")


# ════════ Invariante 7: una punta más fina nunca aguanta más de lado ════════

func test_una_punta_mas_fina_nunca_aguanta_mas() -> void:
	for hum: String in CareData.HUMIDITY_IDS:
		var st := ClawCare.keratin_strength(hum)
		for alpha: float in [10.0, 15.0, 20.0, 26.0, 35.0]:
			var prev := -INF
			var r := 5.0
			while r <= 800.0:
				var cap := ClawCare.lateral_capacity_n(r, alpha, st)
				assert_true(cap >= prev, "%s, %s°: %s µm aguanta %s N" % [hum, _fx(alpha, 0), _fx(r, 0), _fx(cap, 4)])
				prev = cap
				r *= 1.25
	# al afilar con una faceta, la punta se afina y aguanta cada vez menos
	var c := ClawCare.new({ "animal": "rapaz" })
	c.clip({ "tool": "guillotina", "remove_mm": c.overgrowth_left_mm() })
	var prev_r := INF
	var prev_n := INF
	for k in 200:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 22.0, "force_n": 4.0, "travel_mm": 40.0 })
		var ts := c.tip_state()
		assert_true(float(ts.tipRadiusUm) <= prev_r + 1e-9, "la faceta nunca engorda la punta")
		assert_true(float(ts.lateralN) <= prev_n + 1e-9, "más fina, aguanta menos")
		prev_r = float(ts.tipRadiusUm)
		prev_n = float(ts.lateralN)
		if prev_r <= float(CareData.TOOTH_GEOMETRY.tip_um) + 1e-9:
			break
	assert_near(prev_r, float(CareData.TOOTH_GEOMETRY.tip_um), 1e-12, 0.0, "la punta acaba con el radio de la arista")


# ════════ Invariante 8: la lima de acero no lima lo que es más duro ════════

func test_la_lima_de_acero_no_lima_lo_mas_duro() -> void:
	for iid: String in HARD_INLAYS:
		for tid: String in STEEL_FILES:
			var c := ClawCare.new({ "animal": "rapaz", "inlay": iid })
			var r := c.file({ "tool": tid, "zone": "punta", "angle_deg": 90.0, "force_n": 10.0, "travel_mm": 40.0 })
			assert_eq(float(r.removedMm3), 0.0, "%s con %s: nada" % [iid, tid])
			assert_true(bool(r.noBite), "%s con %s: no muerde" % [iid, tid])
			assert_false(c.check("lima_adecuada"), "%s: la lima no es la adecuada" % iid)
			var ids: Array = c.report().criteria.map(func(x: Dictionary) -> String: return String(x.id))
			assert_true(ids.has("lima_no_muerde"), "%s: el informe lo dice" % iid)
		# la de acero de las hojas tampoco corta
		assert_false(bool(ClawCare.new({ "animal": "rapaz", "inlay": iid }).clip({ "tool": "guillotina", "remove_mm": 2.0 }).cut), "%s: el cortaúñas no corta" % iid)
		var d := ClawCare.new({ "animal": "rapaz", "inlay": iid })
		var rd := d.file({ "tool": "lima_diamante_gruesa", "zone": "punta", "angle_deg": 90.0, "force_n": 10.0, "travel_mm": 40.0 })
		if iid != "diamante":
			assert_true(float(rd.removedMm3) > 0.0 and d.check("lima_adecuada"), "%s: la de diamante sí" % iid)
	for iid: String in ["oro", "acero", "titanio", "vidrio", "swarovski"]:
		var c := ClawCare.new({ "animal": "rapaz", "inlay": iid })
		assert_true(float(c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 10.0, "travel_mm": 40.0 }).removedMm3) > 0.0, "%s: la de acero lo lima" % iid)
	# el aviso sale una vez por herramienta, no en cada pasada
	var z := ClawCare.new({ "animal": "rapaz", "inlay": "zafiro" })
	for k in 5:
		z.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
	assert_eq(z.events().filter(func(e: Dictionary) -> bool: return e.code == "no_muerde").size(), 1, "un aviso")


# ════════ Humedad ════════

func test_la_humedad_ablanda_y_arranca_mas() -> void:
	var hs: Array = CareData.HUMIDITY_IDS.map(func(h: String) -> float: return ClawCare.hardness_mpa(32.0, h))
	assert_true(float(hs[0]) > float(hs[1]) and float(hs[1]) > float(hs[2]), "seca > natural > húmeda")
	assert_near(float(hs[2]) / float(hs[1]), 14.0 / 69.0, 1e-12, 0.0, "mojada, ×0,203 (Taylor 2004; el ×0,2 del banco)")
	var prev := -INF
	for hum: String in ["seca", "natural", "humeda"]:
		var c := ClawCare.new({ "animal": "rapaz", "humidity": hum })
		var v := float(c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 3.0, "travel_mm": 40.0 }).removedMm3)
		assert_true(v > prev, "%s: más blanda, más arranque" % hum)
		prev = v
	assert_eq(ClawCare.hardness_mpa(200.0, "empapada", true), 200.0 * 9.807, "el agua no ablanda el acero")


# ════════ Sangre, dolor y sujeción ════════

func test_hemostasia() -> void:
	# con hemostático: 30 s de presión
	var a := _short("rapaz", -0.5)
	assert_true(bool(a.snapshot().bleeding.active), "sangra")
	assert_near(float(a.hemostasis({ "tool": "hemostatico", "pressure_s": 10.0 }).needS), 20.0, 1e-9, 0.0, "con 10 s de presión faltan 20 (30 s con hemostático)")
	assert_true(bool(a.snapshot().bleeding.active), "a los 10 s aún sangra")
	assert_true(bool(a.hemostasis({ "tool": "hemostatico", "pressure_s": 20.0 }).stopped), "a los 30 s, parada")
	assert_true(a.check("hemostasia"), "paso del tutorial")
	# solo presión: 5 minutos
	var b := _short("rapaz", -0.5)
	assert_false(bool(b.hemostasis({ "tool": "", "pressure_s": 200.0 }).stopped), "200 s de presión no bastan")
	assert_true(bool(b.hemostasis({ "tool": "", "pressure_s": 100.0 }).stopped), "300 s sí (VCA)")
	# sin nada: para sola a los 10 minutos
	var c := _short("rapaz", -0.5)
	c.advance(590.0)
	assert_true(bool(c.snapshot().bleeding.active), "a los 590 s sigue")
	c.advance(20.0)
	assert_false(bool(c.snapshot().bleeding.active), "a los 10 min para sola")
	var ids: Array = c.report().criteria.map(func(x: Dictionary) -> String: return String(x.id))
	assert_true(ids.has("sin_desinfectar"), "sin clorhexidina, el informe lo dice")
	c.apply({ "tool": "clorhexidina" })
	assert_true(c.check("desinfectada"), "desinfectada")
	# el nitrato de plata escuece: una rapaz sujeta con capucha y toalla se mueve
	var d := _short("rapaz", -0.5)
	var moved := int(d.snapshot().animal.moved)
	d.hemostasis({ "tool": "nitrato_plata", "pressure_s": 30.0 })
	assert_true(int(d.snapshot().animal.moved) > moved, "el nitrato duele y se mueve")
	var e := _short("rapaz", -0.5)
	var me := int(e.snapshot().animal.moved)
	e.hemostasis({ "tool": "hemostatico", "pressure_s": 30.0 })
	assert_eq(int(e.snapshot().animal.moved), me, "el subsulfato férrico no")


func test_sujecion_y_anestesia() -> void:
	# una rapaz suelta se mueve con poco dolor; con anestesia, nunca
	for sed: String in ["libre", "sujecion", "sedacion", "anestesia"]:
		var c := ClawCare.new({ "animal": "rapaz", "sedation": sed })
		c.clip({ "tool": "tenaza", "remove_mm": c.quick_cover_mm() + 0.5 })
		var moved := int(c.snapshot().animal.moved)
		if sed == "anestesia":
			assert_eq(moved, 0, "anestesiada no se mueve")
		elif sed != "sedacion":
			assert_true(moved > 0, "%s: el corte en la carne viva la hace moverse" % sed)
	assert_false(ClawCare.new({ "animal": "rapaz", "sedation": "libre" }).check("sujecion"), "suelta, no")
	assert_true(ClawCare.new({ "animal": "rapaz" }).check("sujecion"), "encapuchada y envuelta, sí")
	# un tigre, un oso o un velocirraptor sin sedar: nota 0
	for aid: String in ["tigre", "oso", "velociraptor"]:
		var w := ClawCare.new({ "animal": aid, "sedation": "sujecion" })
		assert_false(w.check("sujecion"), "%s: sujetarlo no basta" % aid)
		assert_eq(float(w.report().grade), 0.0, "%s: nota 0" % aid)
		assert_true(ClawCare.new({ "animal": aid, "sedation": "sedacion" }).check("sujecion"), "%s: sedado, sí" % aid)
		assert_true(ClawCare.new({ "animal": aid }).check("sujecion"), "%s: por defecto, anestesiado" % aid)



func test_la_anestesia_cuenta_desde_la_primera_accion_sobre_la_garra() -> void:
	# anestesiar al tigre antes de tocarle las garras es el protocolo: el informe no lo castiga
	var before := ClawCare.new({ "animal": "tigre", "sedation": "sujecion" })
	before.set_sedation("anestesia")
	before.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 20.0 })
	var rb := before.report()
	assert_true(String(rb.verdict) != "rota" and float(rb.grade) > 0.0, "anestesiado antes de empezar: %s, nota %s" % [rb.verdict, rb.grade])
	# empezar sin anestesia y anestesiar después no lo borra: nota 0
	var after := ClawCare.new({ "animal": "tigre", "sedation": "sujecion" })
	after.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 20.0 })
	after.set_sedation("anestesia")
	var ra := after.report()
	assert_eq(float(ra.grade), 0.0, "lo tocó sin anestesia: nota 0 aunque luego lo anestesie")
	assert_eq(String(ra.verdict), "peligro", "y el veredicto lo dice (petición 51: el peligro, con su propio veredicto)")
	# a una rapaz se la maneja con capucha y toalla: sin anestesia no es un peligro
	var bird := ClawCare.new({ "animal": "rapaz" })
	bird.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 20.0 })
	assert_true(float(bird.report().grade) > 0.0, "la rapaz encapuchada y envuelta, con nota")

# ════════ Veredictos ════════

func test_una_sesion_bien_hecha_con_la_rapaz() -> void:
	# limar el sobrante con una faceta que sigue la curva (de la base a la punta), rematar la punta con toques ligeros
	var c := ClawCare.new({ "animal": "rapaz" })
	var alpha := c.tip_alpha_deg()
	var over := c.overgrowth_left_mm()
	var strokes := 0
	while c.overgrowth_left_mm() > 0.05 * over and strokes < 300:
		c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": alpha + 7.0, "force_n": 5.0, "travel_mm": 40.0 })
		strokes += 1
	assert_true(strokes < 100, "el sobrante se lima en menos de 100 pasadas (%d)" % strokes)
	assert_eq(c.report().verdict, "daga_fragil", "la faceta deja una aguja: afilada como una daga pero frágil")
	var taps := 0
	while float(c.tip_state().ratio) < 0.5 and taps < 50:
		c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
		taps += 1
	c.apply({ "tool": "crema" })
	var rep := c.report()
	print("    (info) sesión: %d pasadas y %d toques; punta %s µm (natural %s), aguanta el %s %%; %s, %s" % [strokes, taps, _fx(float(c.tip_state().tipRadiusUm), 0), _fx(float(c.tip_state().naturalUm), 0), _fx(float(c.tip_state().strengthRatio) * 100.0, 0), rep.verdict, rep.gradeText])
	assert_true(rep.verdict in ["perfecta_daga", "perfecta"], "bien hecha: %s" % rep.verdict)
	assert_true(float(rep.grade) >= 9.5, "nota alta: %s" % rep.gradeText)
	for key: String in ["sujecion", "sin_sangre", "a_favor", "curva", "largo", "punta", "sin_calor", "crema"]:
		assert_true(c.check(key), "paso %s hecho" % key)
	assert_true(rep.regrow == null, "no falta nada que crezca")


func test_los_otros_veredictos() -> void:
	# roma: de frente y sin rematar
	var r := ClawCare.new({ "animal": "rapaz" })
	for k in 12:
		r.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
	assert_eq(r.report().verdict, "roma", "de frente: roma")
	# agrietada: el cortaúñas raja; limar la cara de frente quita la grieta
	var g := ClawCare.new({ "animal": "rapaz" })
	g.clip({ "tool": "guillotina", "remove_mm": g.overgrowth_left_mm() })
	assert_eq(g.report().verdict, "agrietada", "con la grieta del cortaúñas")
	assert_false(g.check("sin_grieta"), "grieta")
	var k := 0
	while not g.check("sin_grieta") and k < 100:
		g.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 5.0, "travel_mm": 40.0 })
		k += 1
	assert_true(g.check("sin_grieta"), "limando la cara, la grieta se va (%d pasadas)" % k)
	# corta: al borde de la carne viva sin llegar
	var s := _short("rapaz", 1.0)
	s.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 90.0, "force_n": 0.5, "travel_mm": 1.0 })
	assert_true(s.report().verdict in ["corta", "agrietada"], "corta: %s" % s.report().verdict)
	var ids: Array = s.report().criteria.map(func(x: Dictionary) -> String: return String(x.id))
	assert_true(ids.has("corta"), "muy cerca de la carne viva")
	# rota: la tenaza raja hasta la carne viva; parar, limpiar y reconstruir
	var b := ClawCare.new({ "animal": "rapaz", "humidity": "seca" })
	var cut := b.clip({ "tool": "tenaza", "remove_mm": b.quick_cover_mm() - 0.4 })
	assert_true(bool(cut.reachesQuick), "la grieta llega a la carne viva")
	var rep := b.report()
	assert_eq(rep.verdict, "rota", "rota")
	assert_true(rep.regrow != null and float(rep.regrow.days) == 75.0, "2-3 meses en rehacerse (Samour)")
	assert_false(bool(b.apply({ "tool": "metacrilato" }).ok), "no se reconstruye sangrando")
	b.hemostasis({ "tool": "hemostatico", "pressure_s": 30.0 })
	b.apply({ "tool": "clorhexidina" })
	assert_true(bool(b.apply({ "tool": "metacrilato" }).ok) and b.check("reconstruida"), "reconstruida")
	var rep2 := b.report()
	assert_eq(rep2.verdict, "reconstruida", "rota y reconstruida")
	assert_true(float(rep2.grade) > float(rep.grade), "reconstruirla sube la nota (%s → %s)" % [rep.gradeText, rep2.gradeText])
	var ids2: Array = rep2.criteria.map(func(x: Dictionary) -> String: return String(x.id))
	assert_false(ids2.has("sin_reconstruir") or ids2.has("sin_hemostasia") or ids2.has("sin_desinfectar"), "hecho lo que tocaba")
	assert_false(ids2.has("grieta") or ids2.has("corta"), "la grieta que la rompió no cuenta dos veces")
	# larga: sin tocar
	assert_eq(ClawCare.new({ "animal": "oso" }).report().verdict, "larga", "sin tocar, larga")


# ════════ Tutorial ════════

func test_el_tutorial_de_cada_proceso() -> void:
	for aid: String in CareData.ANIMAL_IDS:
		for inl: String in ["none", "zafiro"]:
			for pid: String in Tutorial.PROCESS_IDS:
				assert_true(Tutorial.PROCESS_NAMES.has(pid), "%s: nombre" % pid)
				var steps := Tutorial.steps(aid, pid, inl)
				var ids := {}
				for st: Dictionary in steps:
					var where := "%s/%s/%s/%s" % [aid, inl, pid, st.get("id", "?")]
					assert_false(ids.has(st.id), "%s: id único" % where)
					ids[st.id] = true
					assert_true(String(st.title).length() > 3 and String(st.text).length() > 30, "%s: título y texto" % where)
					assert_true(String(st.source).length() > 20, "%s: fuente" % where)
					assert_true(String(st.check) == "" or ClawCare.CHECK_KEYS.has(String(st.check)) or Tutorial.STATE_CHECKS.has(String(st.check)), "%s: condición conocida (%s)" % [where, st.check])
			assert_true(Tutorial.steps(aid, "preparar", inl).size() >= 2, "%s: preparar tiene pasos" % aid)
	var c := ClawCare.new({ "animal": "rapaz" })
	for pid: String in Tutorial.PROCESS_IDS:
		for st: Dictionary in c.tutorial(pid):
			if String(st.check) == "":
				assert_true(st.done == null, "%s/%s: informativo" % [pid, st.id])
			else:
				assert_true(typeof(st.done) == TYPE_BOOL, "%s/%s: hecho o no" % [pid, st.id])
	for key: String in ClawCare.CHECK_KEYS:
		assert_true(typeof(c.check(key)) == TYPE_BOOL, "condición %s" % key)


# ════════ Contrato con la escena ════════

const SNAPSHOT_PATHS := [
	"serial", "t_s", "animal_id", "claw_id", "inlay", "reforged", "profile.s", "profile.r", "profile.core",
	"claw.lengthMm", "claw.naturalMm", "claw.startMm", "claw.overgrowthLeftMm", "claw.quickMm", "claw.quickCoverMm",
	"claw.baseRadiusMm", "claw.curve", "claw.color", "claw.colorQuality", "claw.quickVisible", "claw.sign", "claw.humidity",
	"claw.humidityName", "claw.removedMm3", "claw.digit", "claw.hind", "claw.arcDeg", "claw.arcInnerDeg", "claw.arcMethod", "claw.sectionRatio",
	"claw.ventralFlat", "claw.shapeQuality", "claw.shapeSource", "claw.sectionQuality", "claw.sectionSource", "claw.block", "tip.tipRadiusUm", "tip.naturalUm", "tip.ratio", "tip.alphaDeg",
	"tip.naturalAlphaDeg", "tip.lateralN", "tip.naturalLateralN", "tip.strengthRatio", "tip.facetDeg", "tip.flatMm",
	"thermal.quickC", "thermal.faceC", "thermal.peakQuickC", "thermal.painC", "thermal.painS", "thermal.injuryDose",
	"thermal.injured", "thermal.cells", "thermal.quickCell", "thermal.zone", "thermal.sZone", "thermal.dxMm", "thermal.axis",
	"thermal.spanMm", "bleeding.active", "bleeding.bled", "bleeding.areaMm2",
	"bleeding.elapsedS", "bleeding.totalS", "bleeding.needS", "bleeding.agent", "damage.splits", "damage.peels", "damage.chips",
	"damage.flattened", "damage.broken", "damage.quickCut", "damage.wallThrough", "damage.repaired", "damage.breaks",
	"damage.lastBreak", "animal.sedation", "animal.sedationName", "animal.pain", "animal.maxPain", "animal.stress", "animal.moved",
	"animal.movedHere", "animal.unsafe", "animal.stressQuality", "shape.verdict", "shape.title", "shape.tone", "shape.text",
	"shape.source", "surface.stationMm", "surface.lengthMm", "surface.n", "surface.ra_um", "surface.burn", "surface.chip",
	"surface.scratch_deg", "surface.raStartUm", "events",
]
const REPORT_PATHS := [
	"verdict", "verdictText", "grade", "gradeText", "criteria", "advice", "regrow", "rubricSource", "facts.lengthMm",
	"facts.naturalMm", "facts.overgrowthLeftMm", "facts.quickCoverMm", "facts.safeMarginMm", "facts.tip",
	"facts.peakQuickC", "facts.injuryDose", "facts.moved", "facts.stress",
]


static func _has_path(root: Dictionary, path: String) -> bool:
	var cur: Variant = root
	for key in path.split("."):
		if not (cur is Dictionary) or not (cur as Dictionary).has(key):
			return false
		cur = cur[key]
	return true


func test_la_escena_tiene_todo_lo_que_pinta() -> void:
	var cases: Array = [ClawCare.new({ "animal": "rapaz" }), ClawCare.new({ "animal": "tigre", "inlay": "zafiro" }), _short("oso", -0.3)]
	for c: ClawCare in cases:
		c.file({ "tool": "torno", "zone": "punta", "angle_deg": 45.0, "force_n": 0.5, "dwell_s": 0.5 })
		var sn := c.snapshot()
		for p: String in SNAPSHOT_PATHS:
			assert_true(_has_path(sn, p), "%s: instantánea.%s" % [sn.animal_id, p])
		var rep := c.report()
		for p: String in REPORT_PATHS:
			assert_true(_has_path(rep, p), "%s: informe.%s" % [sn.animal_id, p])
		assert_true(ClawCare.VERDICTS.has(rep.verdict), "veredicto con texto")
		for cr: Dictionary in rep.criteria:
			assert_true(String(cr.source).length() > 10 and float(cr.lost) >= 0.0, "criterio %s con fuente" % cr.id)
		for ad: Dictionary in rep.advice:
			assert_true(String(ad.source).length() > 10, "consejo %s con fuente" % ad.id)
		# el perfil: de la base a la punta, la carne viva dentro
		var ps: PackedFloat64Array = sn.profile.s
		var pr: PackedFloat64Array = sn.profile.r
		var pc: PackedFloat64Array = sn.profile.core
		assert_true(ps.size() == pr.size() and pr.size() == pc.size() and ps.size() >= 2, "perfil completo")
		for i in ps.size():
			if i > 0:
				assert_true(ps[i] > ps[i - 1], "s crece")
			assert_true(pr[i] >= 0.0 and pc[i] >= 0.0, "radios positivos")
		assert_near(ps[ps.size() - 1], float(sn.claw.lengthMm), 1e-12, 0.0, "acaba en la punta")
		for e: Dictionary in sn.events:
			assert_true(String(e.source).length() > 10 and String(e.message).length() > 10, "suceso %s con fuente" % e.code)
		var serial := c.serial()
		c.advance(1.0)
		assert_true(c.serial() > serial, "el número de serie cambia con el estado")
		for cell: float in sn.thermal.cells:
			assert_true(is_finite(cell), "temperaturas finitas")


# ════════ Determinismo ════════

func _session(c: ClawCare) -> void:
	c.clip({ "tool": "guillotina", "remove_mm": 2.0 })
	c.file({ "tool": "lima_bastarda", "zone": "punta", "angle_deg": 90.0, "force_n": 4.0, "travel_mm": 40.0, "direction": "en_contra" })
	c.file({ "tool": "torno", "zone": "flanco", "at_mm": 20.0, "force_n": 0.8, "dwell_s": 1.5 })
	c.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 24.0, "force_n": 3.0, "travel_mm": 40.0 })
	c.advance(12.0)
	c.hemostasis({ "tool": "hemostatico", "pressure_s": 5.0 })


func test_determinista_y_a_trozos() -> void:
	var a := ClawCare.new({ "animal": "rapaz", "quick": "oculta", "seed": "x" })
	var b := ClawCare.new({ "animal": "rapaz", "quick": "oculta", "seed": "x" })
	_session(a)
	_session(b)
	assert_eq(var_to_str(a.snapshot()), var_to_str(b.snapshot()), "la misma sesión, la misma instantánea")
	assert_eq(var_to_str(a.report()), var_to_str(b.report()), "y el mismo informe")
	# sin tocar la garra, el tiempo a trozos da lo mismo que de una vez
	var p := ClawCare.new({ "animal": "rapaz" })
	var q := ClawCare.new({ "animal": "rapaz" })
	for x: ClawCare in [p, q]:
		x.file({ "tool": "torno", "zone": "flanco", "at_mm": _at(x, 8.0), "force_n": 1.0, "dwell_s": 2.0 })
	p.advance(10.0)
	for i in 40:
		q.advance(0.25)
	var sp := p.snapshot()
	var sq := q.snapshot()
	sp.erase("serial")
	sq.erase("serial")
	assert_eq(var_to_str(sp), var_to_str(sq), "advance a trozos")



func test_a_trozos_que_no_caen_en_los_bloques_de_enfriamiento() -> void:
	# 0,1 s son 6 pasos, que no casan con los bloques de COOL_BLOCK: aun así, lo mismo que de una vez
	var p := ClawCare.new({ "animal": "rapaz" })
	var q := ClawCare.new({ "animal": "rapaz" })
	for x: ClawCare in [p, q]:
		x.file({ "tool": "torno", "zone": "flanco", "at_mm": _at(x, 8.0), "force_n": 1.0, "dwell_s": 2.0 })
	p.advance(10.0)
	for i in 100:
		q.advance(0.1)
	var sp := p.snapshot()
	var sq := q.snapshot()
	sp.erase("serial")
	sq.erase("serial")
	assert_eq(var_to_str(sp), var_to_str(sq), "advance a trozos de 0,1 s")


func test_una_herida_nueva_pide_su_propia_hemostasia() -> void:
	var c := _short("rapaz", -0.5)
	assert_true(bool(c.snapshot().bleeding.active), "la carne viva al aire sangra")
	var need := float(CareData.HEMOSTASIS.pressure_s.value)
	assert_true(bool(c.hemostasis({ "tool": "", "pressure_s": need + 10.0 }).stopped), "con presión suficiente, para")
	# otro corte en la carne viva: la presión de la primera herida no cuenta para la segunda
	c._cut_to(c.apex_mm() - 1.0)
	var b: Dictionary = c.snapshot().bleeding
	assert_true(bool(b.active), "vuelve a sangrar")
	assert_near(float(b.needS), need, 1e-9, 1e-9, "y pide toda la presión otra vez")
	assert_false(bool(c.hemostasis({ "tool": "", "pressure_s": 1.0 }).stopped), "con un segundo de presión no para")

func test_la_faceta_es_la_misma_de_una_vez_o_a_trozos() -> void:
	var a := ClawCare.new({ "animal": "rapaz" })
	var b := ClawCare.new({ "animal": "rapaz" })
	var edge := float(CareData.TOOTH_GEOMETRY.tip_um)
	var ra: float = a._facet(24.0, 3.0, edge).removed
	var rb: float = float(b._facet(24.0, 1.0, edge).removed) + float(b._facet(24.0, 2.0, edge).removed)
	assert_near(rb, ra, 1e-6, 1e-9, "el mismo volumen")
	assert_near(b.apex_mm(), a.apex_mm(), 1e-9, 1e-9, "la misma punta")
	var sa := a.snapshot().profile.r as PackedFloat64Array
	var sb := b.snapshot().profile.r as PackedFloat64Array
	var worst := 0.0
	for i in mini(sa.size(), sb.size()):
		worst = maxf(worst, absf(sa[i] - sb[i]))
	assert_true(worst < 1e-6, "el mismo perfil (conos unos dentro de otros): %s mm" % _fx(worst, 9))


# ════════ Sonidos ════════

func test_cada_accion_suena_con_un_efecto_del_laboratorio() -> void:
	var seen := {}
	for iid: String in ["none", "oro", "zafiro"]:
		for tid: String in ["lima_bastarda", "lima_fina", "lija_p240", "lima_diamante_fina", "torno"]:
			var c := ClawCare.new({ "animal": "rapaz", "inlay": iid })
			var r := c.file({ "tool": tid, "zone": "punta", "angle_deg": 90.0, "force_n": 3.0, "travel_mm": 40.0, "dwell_s": 0.2 })
			assert_eq(String(r.tool), tid, "la salida dice la herramienta")
			seen[c.sfx_for("file", r)] = true
		var k := ClawCare.new({ "animal": "rapaz", "inlay": iid })
		var rc := k.clip({ "tool": "guillotina", "remove_mm": 2.0 })
		seen[k.sfx_for("clip", rc)] = true
	var b := _short("rapaz", -0.5)
	seen[b.sfx_for("hemostasis", b.hemostasis({ "tool": "", "pressure_s": 1.0 }))] = true
	var q := ClawCare.new({ "animal": "rapaz" })
	seen[q.sfx_for("clip", q.clip({ "tool": "tenaza", "remove_mm": q.quick_cover_mm() + 0.2 }))] = true
	for id: String in seen:
		assert_true(Sfx.SFX_IDS.has(id), "%s es un efecto del laboratorio" % id)
	for want: String in ["scratch-deep", "scratch-wood", "scratch-soft", "scratch-metal", "scratch-glass", "slide", "snap", "skin-cut", "drip"]:
		assert_true(seen.has(want), "suena %s" % want)


# ════════ El torno quieto sobre la carne viva (fallo visto por la 5b) ════════

## El caso de la 5b: el tigre anestesiado, el torno a 13 000 rpm apretado en el flanco sobre la carne viva durante 15 s.
## Antes, al atravesar la pared, la cara subía a decenas de miles de grados; ahora no pasa de la temperatura a la que la
## queratina se quema (CareData.THERMAL.char_c), y se avisa.
func _grind_tiger_quick(c: ClawCare, times: int) -> Array:
	var temps: Array = []
	for i in times:
		var sn := c.snapshot()
		var at := c.apex_mm() - (float(sn.claw.quickMm) - 2.0)
		c.file({ "tool": "torno", "zone": "flanco", "at_mm": at, "length_mm": 3.0, "force_n": 3.0, "dwell_s": 0.1,
			"rpm": 13000.0, "angle_deg": 45.0 })
		var th: Dictionary = c.snapshot().thermal
		temps.append([float(th.faceC), float(th.quickC)])
	return temps


func test_el_torno_quieto_no_pasa_de_la_temperatura_a_la_que_se_quema_la_queratina() -> void:
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	var cap: float = CareData.THERMAL.char_c.value
	var temps := _grind_tiger_quick(c, 150)
	var peak := 0.0
	for t: Array in temps:
		assert_true(float(t[0]) <= cap + 1e-6, "la cara no pasa de %s °C (llega a %s)" % [_fx(cap, 0), _fx(float(t[0]), 1)])
		assert_true(float(t[1]) <= cap + 1e-6, "la carne viva no pasa de %s °C (llega a %s)" % [_fx(cap, 0), _fx(float(t[1]), 1)])
		peak = maxf(peak, float(t[0]))
	var sn := c.snapshot()
	assert_true(bool(sn.thermal.charred), "15 s apretando el torno en el mismo sitio queman la queratina (pico de %s °C)" % _fx(peak, 1))
	assert_true(sn.events.any(func(e: Dictionary) -> bool: return e.code == "quema"), "se avisa de que la queratina se quema")
	assert_true(bool(sn.thermal.injured), "y la carne viva se lesiona")


func test_donde_ya_no_queda_garra_el_torno_no_calienta() -> void:
	var c := ClawCare.new({ "animal": "tigre", "sedation": "anestesia" })
	_grind_tiger_quick(c, 150)
	# el último tramo ya no arrancaba nada: allí no queda garra que tocar
	var sn := c.snapshot()
	var at := c.apex_mm() - (float(sn.claw.quickMm) - 2.0)
	var r := c.file({ "tool": "torno", "zone": "flanco", "at_mm": at, "length_mm": 3.0, "force_n": 3.0, "dwell_s": 0.1,
		"rpm": 13000.0, "angle_deg": 45.0 })
	if float(r.removedMm3) <= 0.0:
		assert_eq(float(r.heatW), 0.0, "sin garra bajo el torno no hay roce ni calor")


func test_en_una_garra_oscura_el_aviso_de_aplastar_no_dice_donde_esta_la_carne_viva() -> void:
	var dark_hits := 0
	for aid: String in CareData.ANIMAL_IDS:
		var a: Dictionary = CareData.ANIMALS[aid]
		var c := ClawCare.new({ "animal": aid, "sedation": "anestesia" })
		var sn := c.snapshot()
		if sn.claw.quickMm == null:
			continue
		# un corte justo por delante de la carne viva aprieta el tejido vivo
		c.clip({ "tool": "tenaza", "remove_mm": c.apex_mm() - float(sn.claw.quickMm) - 0.3 })
		for e: Dictionary in c.snapshot().events:
			if String(e.code) == "aplasta" and not bool(a.quick_visible):
				dark_hits += 1
				assert_false(String(e.message).contains(" mm "), "%s: garra oscura, el aviso no da la distancia: %s" % [aid, e.message])
	assert_true(dark_hits > 0, "al menos una garra oscura recibe el aviso de aplastar (el test comprueba algo)")
