## El afilado que se entiende (unidad 5s, petición 60): para qué sirve cada herramienta, el medidor de la punta (que dice lo
## mismo que el motor y cuántas pasadas faltan) y el aviso para afilar después de recortar (claw_care_sharpen_help.gd).
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Help = preload("res://core/lab/claw_care_sharpen_help.gd")


## Un águila con la garra recortada remove_mm (cortada remojada, para que no raje, y vuelta a la humedad natural).
static func _clipped(remove_mm: float, digit := "III") -> ClawCare:
	var c := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "digit": digit, "seed": "afilar", "sedation": "sujecion",
		"humidity": "humeda", "overgrowth_days": 0.0 })
	c.clip({ "tool": "guillotina", "remove_mm": remove_mm })
	c.set_humidity("natural")
	return c


static func _pass(c: ClawCare, tool: String, angle: float, force := 3.0, mm := Help.REF_PASS_MM) -> Dictionary:
	return c.file({ "tool": tool, "zone": "punta", "angle_deg": angle, "force_n": force, "travel_mm": mm, "direction": "a_favor" })


func test_cada_herramienta_tiene_su_linea_de_para_que_sirve() -> void:
	var sharp: Array = []
	for t: Dictionary in State.TRAY:
		var p := Help.purpose(String(t.id))
		assert_false(p.is_empty(), "%s: tiene para qué sirve" % t.id)
		if p.is_empty():
			continue
		assert_true(String(p.line).length() > 8 and String(p.roleText) != "", "%s: una línea y su papel" % t.id)
		assert_true(String(p.source).length() > 10, "%s: con su fuente" % t.id)
		if String(p.sharpens) != "":
			sharp.append(String(t.id))
	assert_eq(sharp, ["lima_fina", "torno", "amoladora", "lima_diamante_fina"], "afilan: las finas con control y las giratorias, que se pasan")
	assert_eq(String(Help.purpose("lima_fina").sharpens), "si", "la lima fina afila con control")
	assert_eq(String(Help.purpose("amoladora").sharpens), "rapido", "la amoladora afila en un instante")
	assert_eq(String(Help.purpose("guillotina").roleText), "acorta", "el cortaúñas acorta")
	assert_eq(String(Help.purpose("lima_bastarda").roleText), "quita largo y da forma", "la gruesa da forma")
	assert_eq(String(Help.purpose("lija_p240").roleText), "pule", "la P240 pule")
	assert_near(float(Help.purpose("lima_fina").edgeUm), float(CareData.TOOTH_GEOMETRY.tip_um), 1e-12, 0.0, "la punta más fina que deja, la de su arista")


## El medidor dice lo mismo que el motor: la aguja es la «Demasiado fina» de ClawCare.shape y la roma, su «Roma».
func test_el_medidor_coincide_con_el_motor() -> void:
	var c := _clipped(2.0)
	var seen := {}
	for i in 60:
		var m := Help.meter(c, { "tool": "lima_bastarda", "force_n": 3.0, "angle_deg": 22.0 })
		var sh := c.shape()
		var ts := c.tip_state()
		assert_near(float(m.ratio), float(ts.ratio), 1e-12, 0.0, "el radio, el del motor")
		assert_eq(String(m.zone) == "aguja", String(sh.verdict) == "fina", "pasada %d: aguja ↔ «Demasiado fina» (%s, %s)" % [i, m.zone, sh.verdict])
		if String(sh.verdict) == "roma":
			assert_eq(String(m.zone), "roma", "pasada %d: roma ↔ «Roma»" % i)
		assert_true(float(m.pos) >= 0.0 and float(m.pos) <= 1.0, "la flecha, dentro del medidor")
		seen[String(m.zone)] = true
		if String(m.zone) == "aguja":
			break
		_pass(c, "lima_bastarda", 22.0)
	assert_true(seen.has("roma") and seen.has("aguja"), "de roma a aguja: %s" % str(seen.keys()))
	var m2 := Help.meter(c, {})
	assert_true(float(m2.bandPos[0]) < Help.pos_of(1.0) and Help.pos_of(1.0) < float(m2.bandPos[1]), "la natural, dentro de la banda buena")


## Invariante: más pasadas de afilado (en faceta y adelgazando los flancos, queratina a su humedad natural) nunca dejan una
## punta más roma.
func test_mas_pasadas_nunca_dan_una_punta_mas_roma() -> void:
	for cut: float in [1.0, 2.0]:
		for tool: String in ["lima_bastarda", "lima_fina", "lima_diamante_fina"]:
			for ang: float in [20.0, 25.0, 35.0]:
				var c := _clipped(cut)
				var prev := float(c.tip_state().tipRadiusUm)
				for i in 40:
					var r := _pass(c, tool, ang)
					var now := float(c.tip_state().tipRadiusUm)
					if bool(r.chipped):
						break
					assert_true(now <= prev + 1e-9, "%s a %s° tras cortar %s mm, pasada %d: %s → %s µm" % [tool, ang, cut, i, prev, now])
					prev = now


## Las pasadas que faltan, con la geometría del motor: lo que dice el medidor es lo que pasa al limar (±1 pasada con la fina;
## con la gruesa el ancho del contacto cambia al acortar y se da algo de margen).
func test_las_pasadas_que_faltan_son_las_del_motor() -> void:
	var cases := [["lima_fina", 1.0, 1], ["lima_bastarda", 2.0, 3], ["lima_diamante_fina", 1.0, 1]]
	for k: Array in cases:
		var tool := String(k[0])
		var c := _clipped(float(k[1]))
		var hand := { "tool": tool, "force_n": 3.0, "angle_deg": 22.0 }
		var m := Help.meter(c, hand)
		var want := int(m.passes.toBand)
		assert_true(want > 0, "%s: faltan pasadas (%d)" % [tool, want])
		var n := 0
		while float(c.tip_state().ratio) > float(CareData.MARGINS.tip_ratio_hi) and n < 120:
			_pass(c, tool, 22.0)
			n += 1
		assert_true(absi(n - want) <= int(k[2]), "%s: el medidor dice %d pasadas y el motor tarda %d" % [tool, want, n])
		# y cuántas faltan para cerrar la cara (la aguja), con las de adelgazar los flancos: al bit con la geometría
		var m2 := Help.meter(c, hand)
		var close := int(m2.passes.toClose)
		var j := 0
		while float(c.tip_state().flatMm) > 0.0 and j < 120:
			_pass(c, tool, 22.0)
			j += 1
		assert_true(absi(j - close) <= 1, "%s: cerrar la cara, %d pasadas dichas y %d hechas" % [tool, close, j])
		assert_eq(String(Help.meter(c, hand).zone), "aguja", "%s: cerrada la cara, una aguja (el radio de sus filos)" % tool)


## Con la giratoria se pasa enseguida: la amoladora llega a la banda y cierra la cara en décimas de segundo.
func test_la_amoladora_se_pasa_enseguida() -> void:
	var c := _clipped(2.0)
	var p := Help.passes(c, { "tool": "amoladora", "force_n": 3.0, "angle_deg": 45.0, "rpm": 8000.0 })
	assert_eq(String(p.unit), "toque", "con una giratoria, toques")
	assert_true(float(p.secondsToClose) > 0.0 and float(p.secondsToClose) < 0.5, "cierra la cara en %s s" % p.secondsToClose)
	assert_true(bool(p.overshoot), "y el toque que llega a la banda ya la deja como una aguja")


## El aviso para afilar sale después de recortar, con el ángulo bueno de esta garra y la herramienta que muerde la punta.
func test_el_aviso_para_afilar_despues_de_recortar() -> void:
	var nat := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "afilar" })
	assert_false(bool(Help.advice(nat, { "tool": "lima_fina", "angle_deg": 22.0 }).show), "sin recortar, no hace falta")
	var c := _clipped(2.0)
	var a := Help.advice(c, { "tool": "guillotina" })
	assert_true(bool(a.show), "recortada y roma: sale")
	var a0 := float(c.tip_state().naturalAlphaDeg)
	assert_near(float(a.angleLo), a0 + 0.5 * float(CareData.MARGINS.facet_deg), 1e-12, 0.0, "más abierto que la garra")
	assert_near(float(a.angleHi), a0 + float(CareData.MARGINS.facet_deg), 1e-12, 0.0, "sin pasar del margen del informe")
	assert_true(String(a.text).begins_with("Para afilar: lima fina o lima de diamante fina, ángulo de 20-25° (la garra es de 15°)"), String(a.text))
	assert_true(String(a.fix).contains("lima fina"), "con el cortaúñas en la mano: coge la lima fina")
	assert_true(String(Help.advice(c, { "tool": "lima_fina", "angle_deg": 90.0 }).fix).contains("de frente"), "de frente: gira la lima")
	assert_eq(String(Help.advice(c, { "tool": "lima_fina", "angle_deg": 22.0 }).fix), "", "con la lima fina a 22°, nada que cambiar")
	# una garra de zafiro: solo la de diamante la muerde
	var z := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "inlay": "zafiro", "seed": "afilar" })
	assert_eq(Help.sharpeners_for(z), ["lima_diamante_fina"], "el zafiro, solo con diamante")


## La lupa: la punta natural es la de su ficha; afilada, una aguja del radio de los filos; probada de lado, mellada.
func test_la_lupa_de_la_punta() -> void:
	var c := _clipped(1.0)
	var l0 := Help.lupa(c)
	assert_eq(String(l0.kind), "cara", "recortada: una cara plana")
	assert_true(float(l0.scaleUm) > 0.0 and float(l0.scaleUm) * 3.0 <= float(l0.fieldMm) * 1000.0 + 1e-6, "la barra de escala cabe")
	while float(c.tip_state().flatMm) > 0.0:
		_pass(c, "lima_fina", 22.0)
	var l1 := Help.lupa(c)
	assert_eq(String(l1.kind), "punta", "cerrada la cara: una punta")
	assert_near(float(l1.tipRadiusUm), float(CareData.TOOTH_GEOMETRY.tip_um), 1e-9, 0.0, "con el radio de la arista de la lima")
	var rs: PackedFloat64Array = l1.r
	var ds: PackedFloat64Array = l1.d
	assert_true(rs[0] < 1e-9 and float(l1.startMm) > 0.0, "la esfera tangente al cono queda por detrás del vértice")
	for i in range(1, ds.size()):
		assert_true(ds[i] > ds[i - 1] and rs[i] >= rs[i - 1] - 1e-9, "el radio crece hacia la base (%d)" % i)
	assert_true(float(l1.fieldMm) < float(l0.fieldMm), "una aguja se mira más de cerca que una cara")
	var pr := c.probe_tip({})
	assert_eq(String(pr.verdict), "mella", "una aguja de queratina se mella al probarla")
	var l2 := Help.lupa(c, c.snapshot())
	assert_true(bool(l2.chipped) and String(l2.kind) == "cara", "y la lupa la enseña mellada")
	_pass(c, "lima_fina", 90.0, 0.5, 1.0)
	assert_false(bool(Help.lupa(c).chipped), "limada de nuevo, ya no está mellada")


func test_determinista() -> void:
	var a := Help.view(_clipped(2.0), { "tool": "lima_fina", "force_n": 3.0, "angle_deg": 22.0 })
	var b := Help.view(_clipped(2.0), { "tool": "lima_fina", "force_n": 3.0, "angle_deg": 22.0 })
	assert_eq(var_to_str(a), var_to_str(b), "lo mismo dos veces")


## (última vuelta de la 5s) Cada garra con lo que ha crecido de más: las de las patas del tigre, lo del gato (0,08 frente a
## 0,13 mm/día); donde no hay diferencia medida, la física de la garra no cambia (la misma ClawCare que con overgrowth_days).
func test_cada_garra_con_su_crecimiento() -> void:
	for a: Array in [["rapaz", "aguila"], ["tigre", "tigre"], ["oso", "oso"], ["velociraptor", "velociraptor"]]:
		var st := State.new({ "animal": a[0], "claw": a[1], "seed": "crece", "overgrowth_days": 90.0 })
		var growth := float((CareData.animal(String(a[0])).growth_mm_day as Dictionary).value)
		for p: String in State.paws_of(String(a[0])):
			for d: String in State.digit_ids(String(a[0])):
				var cs := st.care_setup(p, d)
				var sn := ClawCare.new(cs).snapshot()
				var over := float(sn.claw.startMm) - float(sn.claw.naturalMm)
				var hind_tiger := String(a[0]) == "tigre" and p.begins_with("trasera")
				if hind_tiger:
					assert_near(over, 90.0 * 0.08, 1e-9, 1e-9, "tigre %s %s: crece lo de las patas del gato" % [p, d])
				else:
					assert_false(cs.has("overgrowth_mm"), "%s %s %s: sin diferencia, con overgrowth_days" % [a[1], p, d])
					var plain := cs.duplicate()
					var ref := ClawCare.new(plain).snapshot()
					assert_eq(var_to_str(sn.profile.s), var_to_str(ref.profile.s), "%s %s %s: la misma garra" % [a[1], p, d])
					assert_near(over, 90.0 * growth, 1e-9, 1e-9, "%s %s %s: lo de la ficha del animal" % [a[1], p, d])
		# la garra que se trabaja: la del estado, la misma que la de care_setup
		assert_eq(var_to_str(st.care.snapshot().profile.r), var_to_str(ClawCare.new(st.care_setup(st.paw, st.digit)).snapshot().profile.r), "%s: la elegida, de care_setup" % a[1])


## La punta al empezar (petición de Eric en la 5s): roma · natural · afilada · aguja, en todos los animales. El radio, en ese
## orden; cada una en su zona del medidor; la roma más corta y la aguja más larga; más roma nunca pincha con menos fuerza y la
## aguja nunca aguanta más de lado; la natural, la de antes al bit.
func test_la_punta_al_empezar() -> void:
	const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
	for a: Array in [["rapaz", "aguila"], ["rapaz", "buho"], ["rapaz", "halcon"], ["tigre", "tigre"], ["oso", "oso"], ["velociraptor", "velociraptor"]]:
		var base := { "animal": a[0], "claw": a[1], "seed": "punta" }
		var prev: Dictionary = {}
		for t: String in ["roma", "natural", "afilada", "aguja"]:
			var c := ClawCare.new(base.merged({ "tip_start": t }))
			var ts := c.tip_state()
			var r := float(ts.tipRadiusUm)
			var push := ClawSharpness.yield_onset_n(r, 1.0, 1.0, 1.0)
			var side := float(ts.strengthRatio)
			assert_eq(String(Help.meter(c, { "tool": "" }).zone), t, "%s %s: en su zona del medidor" % [a[1], t])
			assert_eq(String(c.snapshot().claw.tipStart), t, "la instantánea dice con qué punta empieza")
			if not prev.is_empty():
				assert_true(r < float(prev.r), "%s: %s más fina que %s (%s < %s µm)" % [a[1], t, prev.t, r, prev.r])
				assert_true(c.apex_mm() > float(prev.apex), "%s: %s más larga que %s" % [a[1], t, prev.t])
				assert_true(float(prev.push) >= push, "%s: la más roma (%s) nunca pincha con menos fuerza" % [a[1], prev.t])
				assert_true(side <= float(prev.side) + 1e-12, "%s: la más fina (%s) nunca aguanta más de lado" % [a[1], t])
			prev = { "t": t, "r": r, "apex": c.apex_mm(), "push": push, "side": side }
		# la natural, la de antes al bit
		var n0 := ClawCare.new(base).snapshot()
		var n1 := ClawCare.new(base.merged({ "tip_start": "natural" })).snapshot()
		assert_eq(var_to_str(n1.profile), var_to_str(n0.profile), "%s: la natural, el mismo perfil" % a[1])
		assert_eq(var_to_str(n1.tip), var_to_str(n0.tip), "%s: la natural, la misma punta" % a[1])
	# en el estado: todas las garras del ensayo, y la natural sin la clave
	var st := State.new({ "animal": "tigre", "claw": "tigre", "seed": "punta" })
	assert_false(st.care_setup(st.paw, st.digit).has("tip_start"), "natural: sin tip_start (igual que antes)")
	st.set_tip_start("aguja")
	for p: String in State.paws_of("tigre"):
		assert_eq(String(st.care_setup(p, "III").get("tip_start", "")), "aguja", "todas las garras empiezan en aguja")
	assert_eq(String(st.care.snapshot().claw.tipStart), "aguja", "la elegida también")
	assert_true(st.tip_start_text().contains("se mella"), "la tarjeta dice que la aguja se mella")
	st.set_tip_start("roma")
	assert_true(st.tip_start_text().contains("más fuerza"), "y que la roma pide más fuerza para pinchar")


## Según su material (cierre de la 5s): con la misma punta, el material que aguanta menos según sus datos (su resistencia)
## nunca aguanta más de lado; la queratina se mella, los metales se doblan y los frágiles se parten; la aguja corta y la roma ara.
func test_la_punta_segun_su_material() -> void:
	const Catalog = preload("res://core/lab/catalog.gd")
	for t: String in ["aguja", "natural", "roma"]:
		var rows: Array = []
		for e: Dictionary in Catalog.INLAYS:
			var c := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "material", "inlay": String(e.id), "tip_start": t })
			var ch := Help.tip_character(c)
			if ch.lateralN == null or ch.strengthMPa == null:
				continue
			rows.append([float(ch.strengthMPa), float(ch.lateralN), String(e.id), String(ch.behavior)])
			match String(ch.behavior):
				"queratina":
					assert_true(String(ch.text).contains("se mella"), "la queratina se mella")
				"ductil":
					assert_true(String(ch.text).contains("se dobla"), "%s se dobla" % e.id)
				"fragil":
					assert_true(String(ch.text).contains("se parte"), "%s se parte" % e.id)
		for x: Array in rows:
			for y: Array in rows:
				if float(x[0]) < float(y[0]):
					assert_true(float(x[1]) <= float(y[1]) + 1e-12, "%s: %s (menos resistente) no aguanta más de lado que %s" % [t, x[2], y[2]])
	var needle := Help.tip_character(ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "m", "tip_start": "aguja" }))
	var blunt := Help.tip_character(ClawCare.new({ "animal": "rapaz", "claw": "aguila", "seed": "m", "tip_start": "roma" }))
	assert_eq(String(needle.mode), "corte", "la aguja corta y desgarra (Dp %s)" % needle.dp)
	assert_eq(String(blunt.mode), "arado", "la roma ara (Dp %s)" % blunt.dp)
	assert_true(float(needle.dp) > float(blunt.dp), "más fina, más Dp")
