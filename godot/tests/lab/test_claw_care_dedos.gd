## La forma de la garra de cada dedo (petición 36 y punto 4 de la unidad 5g): CareData.CLAW_SHAPES, CareData.claw_shape,
## ClawCare con digit y paw, y ClawCareState al elegir la pata y el dedo.
extends "res://tests/case.gd"

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Physics = preload("res://core/lab/physics.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const Catalog = preload("res://core/lab/catalog.gd")

const QUALITIES := ["primary", "secondary", "estimate"]


## Las garras que se pueden elegir de cada animal: [claw_id, dedos].
static func _all_claws() -> Array:
	var out: Array = []
	for aid: String in CareData.ANIMAL_IDS:
		for cid: String in CareData.ANIMALS[aid].claws:
			out.append([aid, cid, State.digit_ids(aid)])
	return out


func test_cada_dedo_tiene_su_forma_con_fuente() -> void:
	for item: Array in _all_claws():
		var cid := String(item[1])
		assert_true(CareData.CLAW_SHAPES.has(cid), "%s: con su forma" % cid)
		var entry: Dictionary = CareData.CLAW_SHAPES[cid]
		assert_true(String(entry.source).length() > 20 and String(entry.quality) in QUALITIES, "%s: fuente y calidad" % cid)
		assert_true((entry.digits as Dictionary).has(String(entry.ref_digit)), "%s: el dedo de referencia está" % cid)
		var ref: Dictionary = entry.digits[String(entry.ref_digit)]
		# la hoz del velocirraptor, desde la 5o: la base del núcleo medido más el estuche (CareData.VELOCIRAPTOR_BASE)
		var br := float(CareData.VELOCIRAPTOR_BASE.ratio) if cid == "velociraptor" else 1.0
		assert_eq([float(ref.length_ratio), float(ref.base_ratio)], [1.0, br], "%s: el de referencia es la garra del banco" % cid)
		for key: String in ["section_ratio", "ventral_flat"]:
			var d: Dictionary = entry[key]
			assert_true(String(d.source).length() > 5 and String(d.quality) in QUALITIES, "%s.%s: fuente y calidad" % [cid, key])
		for dg: String in item[2]:
			assert_true((entry.digits as Dictionary).has(dg), "%s: el dedo %s que se elige tiene forma" % [cid, dg])
			var sh := CareData.claw_shape(cid, dg)
			assert_eq(String(sh.digit), dg, "%s %s: el suyo" % [cid, dg])
			assert_true(float(sh.lengthRatio) > 0.4 and float(sh.lengthRatio) < 2.5, "%s %s: largo ×%s" % [cid, dg, sh.lengthRatio])
			assert_true(float(sh.baseRatio) > 0.5 and float(sh.baseRatio) < 2.0, "%s %s: base ×%s" % [cid, dg, sh.baseRatio])
			assert_true(float(sh.arcDeg) > 60.0 and float(sh.arcDeg) < 180.0, "%s %s: arco %s°" % [cid, dg, sh.arcDeg])
			if sh.arcInnerDeg != null:
				assert_true(float(sh.arcInnerDeg) < float(sh.arcDeg), "%s %s: la curva de dentro gira menos que la de fuera" % [cid, dg])
			assert_true(float(sh.sectionRatio) >= 1.0, "%s %s: alto/ancho ≥ 1" % [cid, dg])


## Lo medido (Fowler et al. 2009): en las águilas, la garra del dedo I, el talón, es la mayor; en los búhos, no.
func test_en_las_aguilas_el_talon_es_la_mayor() -> void:
	for cid: String in ["aguila", "arpia"]:
		var hallux := float(CareData.claw_shape(cid, "I").lengthRatio)
		for dg: String in ["II", "III", "IV"]:
			assert_true(hallux > float(CareData.claw_shape(cid, dg).lengthRatio), "%s: el talón mayor que el dedo %s" % [cid, dg])
		assert_true(float(CareData.claw_shape(cid, "II").lengthRatio) > 1.0, "%s: el dedo II, también agrandado" % cid)
		assert_true(float(CareData.claw_shape(cid, "IV").lengthRatio) < 1.0, "%s: el IV, la menor" % cid)
	assert_true(float(CareData.claw_shape("buho", "I").lengthRatio) < 1.0, "búho: el dedo I no es el mayor")
	assert_true(float(CareData.claw_shape("buitre", "I").lengthRatio) < 0.7, "el carroñero: la del dedo I, pequeña")
	for dg: String in ["I", "II", "III", "IV"]:
		var r := float(CareData.claw_shape("halcon", dg).lengthRatio)
		assert_true(r > 0.85 and r < 1.2, "halcón, dedo %s: las cuatro parecidas (×%s)" % [dg, _fx3(r)])
	# el águila real medida: el arco medio del dedo III, como el largo del banco (35 mm)
	assert_true(String(CareData.CLAW_SHAPES.aguila.source).contains("36,4 mm"), "el largo del banco es el del dedo III")
	assert_eq(String(CareData.CLAW_SHAPES.aguila.quality), "primary", "medida en el ejemplar")


static func _fx3(x: float) -> String:
	return String.num(x, 3)


## El dedo de referencia es la garra del banco: sin dedo, la misma garra; con otro dedo, su largo y su base.
func test_la_garra_de_cada_dedo_en_el_motor() -> void:
	for item: Array in _all_claws():
		var aid := String(item[0])
		var cid := String(item[1])
		var ce := CareData.claw_entry(cid)
		var base := ClawCare.new({ "animal": aid, "claw": cid, "seed": "dedos" })
		var ref_d := String(CareData.CLAW_SHAPES[cid].ref_digit)
		var ref := ClawCare.new({ "animal": aid, "claw": cid, "digit": ref_d, "seed": "dedos" })
		assert_eq(var_to_str(base.snapshot()), var_to_str(ref.snapshot()), "%s: sin dedo, el de referencia" % cid)
		assert_eq(base.natural_mm(), float(ce.reach), "%s: el largo del banco" % cid)
		var br2 := float(CareData.VELOCIRAPTOR_BASE.ratio) if cid == "velociraptor" else 1.0
		assert_eq(float(base.snapshot().claw.baseRadiusMm), float(Physics.MODEL["clawBase"]) * float(ce.reach) * br2, "%s: la base del banco" % cid)
		for dg: String in item[2]:
			var c := ClawCare.new({ "animal": aid, "claw": cid, "digit": dg, "seed": "dedos" })
			var sh := CareData.claw_shape(cid, dg)
			var sn := c.snapshot()
			assert_near(c.natural_mm(), float(ce.reach) * float(sh.lengthRatio), 1e-9, 0.0, "%s %s: su largo" % [cid, dg])
			assert_near(float(sn.claw.baseRadiusMm), float(Physics.MODEL["clawBase"]) * float(ce.reach) * float(sh.baseRatio), 1e-9, 0.0, "%s %s: su base" % [cid, dg])
			assert_eq(String(sn.claw.digit), dg, "la instantánea dice el dedo")
			assert_eq(float(sn.claw.arcDeg), float(sh.arcDeg), "y su arco")
			assert_near(35.0 + 115.0 * float(sn.claw.curve), float(sh.arcDeg), 1e-9, 0.0, "curve dibuja el arco medido (art.gd: 35° + 115°·curve)")
			assert_eq(float(sn.claw.sectionRatio), float(sh.sectionRatio), "y su sección")
			assert_eq(String(c.setup().digit), dg, "los ajustes guardan el dedo")
			# la carne viva, en la misma fracción del estuche
			if not bool(sn.reforged):
				assert_near(float(sn.claw.quickMm) / c.natural_mm(), float(base.snapshot().claw.quickMm) / base.natural_mm(), 1e-9, 0.0, "%s %s: la carne viva, en su sitio" % [cid, dg])


## Las patas traseras del tigre y del oso: su forma (como las de la mano, de momento) y dicho como estimación.
func test_las_patas_traseras() -> void:
	for cid: String in ["tigre", "oso"]:
		var fore := CareData.claw_shape(cid, "III", false)
		var hind := CareData.claw_shape(cid, "III", true)
		assert_true(bool(hind.hind) and not bool(fore.hind), "%s: la trasera se distingue" % cid)
		assert_eq(String(hind.quality), "estimate", "%s: sin medición propia" % cid)
		assert_true(String(hind.source).contains("patas traseras"), "%s: lo dice la fuente" % cid)
		var c := ClawCare.new({ "animal": cid, "digit": "III", "paw": "trasera_izquierda" })
		assert_true(bool(c.snapshot().claw.hind), "%s: ClawCare la toma de la pata" % cid)
	# las rapaces no tienen patas traseras
	assert_false(bool(CareData.claw_shape("aguila", "I", true).hind), "la rapaz: dos patas, sin traseras")


## La sección: la hoja del velocirraptor, medida; las demás, con su calidad.
func test_la_seccion_de_cada_garra() -> void:
	var v := CareData.claw_shape("velociraptor", "II")
	assert_near(float(v.sectionRatio), 18.7 / 7.1, 1e-9, 0.0, "velocirraptor: 18,7 × 7,1 mm en la base (Norell y Makovicky 1999)")
	assert_eq(String(v.sectionQuality), "primary", "medida")
	assert_eq(float(v.arcDeg), float(Velociraptor.SICKLE.arcDeg.value), "el arco de velociraptor.gd")
	assert_true(float(CareData.claw_shape("tigre", "III").sectionRatio) > float(CareData.claw_shape("oso", "III").sectionRatio), "el felino, más comprimido que el oso")
	assert_true(float(CareData.claw_shape("oso", "III").sectionRatio) > float(CareData.claw_shape("aguila", "III").sectionRatio), "el oso, más que la rapaz")
	assert_true(bool(CareData.claw_shape("aguila", "III").ventralFlat), "la rapaz, con la cara de abajo plana")
	for cid: String in ["tigre", "oso", "velociraptor"]:
		assert_false(bool(CareData.claw_shape(cid, String(CareData.CLAW_SHAPES[cid].ref_digit)).ventralFlat), "%s: sin cara plana" % cid)


## ClawCareState: cada garra de cada pata con su forma; la zona de la punta, la de su largo.
func test_el_estado_elige_la_garra_de_cada_dedo() -> void:
	var st := State.new({ "animal": "rapaz", "claw": "aguila", "seed": "dedos" })
	var nat3 := st.care.natural_mm()
	var zone3 := st.tip_zone_mm()
	st.select_claw("derecha", "I")
	assert_near(st.care.natural_mm(), nat3 * float(CareData.claw_shape("aguila", "I").lengthRatio), 1e-9, 0.0, "el talón, más largo")
	assert_true(st.tip_zone_mm() >= zone3, "y su zona de la punta, a su medida")
	assert_eq(String(st.care.snapshot().claw.digit), "I", "la instantánea dice el dedo")
	st.select_claw("izquierda", "IV")
	assert_near(st.care.natural_mm(), nat3 * float(CareData.claw_shape("aguila", "IV").lengthRatio), 1e-9, 0.0, "el dedo IV, más corto")
	# «Valores y fuentes»: la garra de este dedo y su sección, con su fuente
	var rows := st.values_table()
	var dig: Array = rows.filter(func(r: Dictionary) -> bool: return String(r.label) == "La garra del dedo IV")
	assert_eq(dig.size(), 1, "la fila de la garra de este dedo")
	assert_eq(String(dig[0].quality), "primary", "medida (Fowler et al. 2009)")
	assert_eq(rows.filter(func(r: Dictionary) -> bool: return String(r.label) == "Sección de la garra").size(), 1, "y la de la sección")
	# el tigre: las patas traseras, avisadas
	var t := State.new({ "animal": "tigre", "seed": "dedos" })
	t.select_claw("trasera_derecha", "IV")
	assert_true(bool(t.care.snapshot().claw.hind), "la trasera")
	var hrow: Array = t.values_table().filter(func(r: Dictionary) -> bool: return String(r.label) == "Garras de las patas traseras")
	assert_eq(hrow.size(), 1, "avisa de las patas traseras")
	assert_eq(String(hrow[0].quality), "estimate", "como estimación")


## Una sola fuente del arco de cada garra del banco (lo pidió la 5e): CareData.claw_arc, con su fuente y su calidad; el
## motor de la cetrería da el mismo.
func test_el_arco_de_cada_garra_del_banco() -> void:
	var animals := ["gato", "tigre", "oso", "aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "casuario", "emu", "avestruz", "gallo", "guacamayo", "pajaro", "velociraptor"]
	for e: Dictionary in Catalog.CLAWS:
		var cid := String(e.id)
		var a := CareData.claw_arc(cid)
		assert_true(float(a.arcDeg) >= 0.0 and float(a.arcDeg) < 200.0, "%s: arco de %s°" % [cid, a.arcDeg])
		assert_true(String(a.quality) in ["primary", "secondary", "estimate", "dibujo"], "%s: calidad" % cid)
		assert_true(String(a.source).length() > 20, "%s: con su fuente" % cid)
		assert_true(String(a.method) in ["exterior", "interior", "dibujo"], "%s: el método" % cid)
		if float(a.lengthMm) > 0.0 and float(a.arcDeg) > 0.0:
			assert_near(float(a.radiusMm), float(a.lengthMm) / deg_to_rad(float(a.arcDeg)), 1e-9, 0.0, "%s: el radio sale del largo y del arco" % cid)
		if cid in animals:
			assert_true(String(a.quality) != "dibujo", "%s: una garra de animal, con su arco medido o estimado" % cid)
	# lo medido: la daga del casuario ya no es de 64° ni de 14°
	assert_eq(float(CareData.claw_arc("casuario").arcDeg), 41.0, "el casuario medido: 41° (Pike y Maitland 2004)")
	assert_eq(float(CareData.claw_arc("guacamayo").arcDeg), 136.0, "el guacamayo macao: 136°")
	assert_true(float(CareData.claw_arc("avestruz").arcDeg) < float(CareData.claw_arc("casuario").arcDeg), "el avestruz, casi una pezuña, menos curva")
	assert_true(float(CareData.claw_arc("aguila", "I").arcDeg) > float(CareData.claw_arc("aguila", "III").arcDeg), "el talón del águila, más curvo que el dedo III")
	assert_eq(String(CareData.claw_arc("velociraptor").method), "interior", "el velocirraptor: el arco de dentro (Feduccia)")
	# el motor de la cetrería, el mismo arco
	for item: Array in _all_claws():
		for dg: String in item[2]:
			var c := ClawCare.new({ "animal": String(item[0]), "claw": String(item[1]), "digit": dg })
			var arc := CareData.claw_arc(String(item[1]), dg)
			assert_eq(float(c.snapshot().claw.arcDeg), float(arc.arcDeg), "%s %s: el mismo arco" % [item[1], dg])
			assert_near(float(arc.lengthMm), c.natural_mm(), 1e-9, 0.0, "y el mismo largo")
