## Invariantes físicas del laboratorio (port de packages/core/test/physics.test.js al motor GDScript).
##
## test_oracle.gd demuestra que hoy physics.gd da lo mismo que el motor 1.x; estas invariantes vigilan que siga
## teniendo sentido físico si algún día se toca: «más fuerza nunca da menos profundidad», «más pasadas no dan
## menos», «nada se hunde más que su propia garra»… Mismas comprobaciones y mensajes que el JS. Las rejillas más
## caras (las del golpe, que integra la energía paso a paso) usan un juego representativo de herramientas en vez
## de las 88 del banco; cada test dice cuál. El barrido completo lo cubre el oráculo.
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const Contact = preload("res://core/shared/contact.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")

var all_tools: Array = []  # formas de uña × bases, gemas sobre uña y garras (con y sin tungsteno): ALL_TOOLS del JS
var rep_tools: Array = []  # juego representativo para las rejillas caras: uñas, gemas, garras y garras reforjadas
var hard_tools: Array = []  # puntas duras de los coches: HARD del JS
var solids: Array = []  # materiales sin piel, pintura ni puerta de madera


func before_each() -> void:
	if not all_tools.is_empty():
		return
	for g: Dictionary in Data.GEOMS:
		for b: Dictionary in Data.BASES:
			all_tools.append({ "label": "uña %s/%s" % [g.id, b.id], "geom": g, "base": b })
	for i: Dictionary in Data.INLAYS.slice(1):
		all_tools.append({ "label": "uña+%s" % i.id, "inlay": i })
	for c: Dictionary in Data.CLAWS:
		all_tools.append({ "label": c.id, "claw": c })
	for c: Dictionary in Data.CLAWS:
		all_tools.append({ "label": "%s+tungsteno" % c.id, "claw": c, "inlay": I("tungsteno") })
	rep_tools = [
		{ "label": "uña cuadrada/natural", "geom": G("cuadrada") }, { "label": "uña almendra/natural", "geom": G("almendra") },
		{ "label": "uña stilettoxl/natural", "geom": G("stilettoxl") }, { "label": "uña stiletto/metal", "geom": G("stiletto"), "base": B("metal") },
		{ "label": "uña cuadrada/diamante", "geom": G("cuadrada"), "base": B("diamante") }, { "label": "uña+cuarzo", "inlay": I("cuarzo") },
		{ "label": "uña+diamante", "inlay": I("diamante") }, { "label": "gato", "claw": K("gato") }, { "label": "oso", "claw": K("oso") },
		{ "label": "casuario", "claw": K("casuario") }, { "label": "vibora", "claw": K("vibora") }, { "label": "gabon", "claw": K("gabon") },
		{ "label": "gato+tungsteno", "claw": K("gato"), "inlay": I("tungsteno") }, { "label": "aguila+acero", "claw": K("aguila"), "inlay": I("acero") },
	]
	hard_tools = [
		{ "label": "águila de acero", "claw": K("aguila"), "inlay": I("acero") }, { "label": "águila de zafiro", "claw": K("aguila"), "inlay": I("zafiro") },
		{ "label": "tigre de tungsteno", "claw": K("tigre"), "inlay": I("tungsteno") }, { "label": "oso de diamante", "claw": K("oso"), "inlay": I("diamante") },
		{ "label": "uña stiletto de metal", "geom": G("stiletto"), "base": B("metal") },
		{ "label": "uña stiletto XL + cuarzo", "geom": G("stilettoxl"), "inlay": I("cuarzo") },
	]
	for t: Dictionary in Data.TARGETS:
		if not t.get("skin", false) and not t.get("paint", false) and not t.get("woodDoor", false):
			solids.append(t)


static func G(id: String) -> Dictionary:
	return Data.find_by_id(Data.GEOMS, id)


static func B(id: String) -> Dictionary:
	return Data.find_by_id(Data.BASES, id)


static func I(id: String) -> Dictionary:
	return Data.find_by_id(Data.INLAYS, id)


static func K(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Data.find_by_id(Data.TARGETS, id)


static func TY(id: String) -> Dictionary:
	return Data.find_by_id(Data.TYPES, id)


## Los parámetros de base() del JS: almendra natural sin gema, sobre el coche moderno, 4 N, arañazo de 25 mm.
static func base(over: Dictionary = {}) -> Dictionary:
	var p := {
		"geom": G("almendra"), "base": B("natural"), "inlay": I("none"), "target": T("coche"),
		"force": 4.0, "length": 25.0, "type": TY("aranazo"), "claw": null,
		"tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false,
	}
	p.merge(over, true)
	p.erase("label")
	return p


static func run(over: Dictionary) -> Dictionary:
	return Physics.compute(base(over))


static func with(tool: Dictionary, over: Dictionary) -> Dictionary:
	var p := tool.duplicate()
	p.merge(over, true)
	return p


static func log_grid(a: float, b: float, n: int) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append(a * pow(b / a, float(i) / (n - 1)))
	return out


static func f1(x: float) -> String:
	return Js.to_fixed(x, 1)


static func who(t: Dictionary) -> String:
	return t.claw.id if t.get("claw") != null else (t.geom.id if t.get("geom") != null else "almendra")


# ── Integridad de datos ──

func test_ids_unicos_en_cada_catalogo() -> void:
	var catalogs := { "GEOMS": Data.GEOMS, "BASES": Data.BASES, "INLAYS": Data.INLAYS, "CLAWS": Data.CLAWS, "TARGETS": Data.TARGETS, "TYPES": Data.TYPES, "PAINT_LAYERS": Data.PAINT_LAYERS }
	for name: String in catalogs:
		var seen := {}
		for x: Dictionary in catalogs[name]:
			assert_false(seen.has(x.id), "id duplicado en %s: %s" % [name, x.id])
			seen[x.id] = true


func test_cada_garra_tiene_campos_fisicos_validos() -> void:
	for c: Dictionary in Data.CLAWS:
		assert_true(Data.CLAW_GROUPS.has(c.group), "%s: grupo desconocido «%s»" % [c.id, c.group])
		assert_true(c.hv > 0 and c.area > 0 and c.mass > 0 and c.E > 0, "%s: hv/area/mass/E deben ser > 0" % c.id)
		assert_true(c.curve >= 0 and c.curve <= 1, "%s: curve fuera de [0,1]" % c.id)
		assert_true(c.alpha > 0 and c.alpha < 90, "%s: semiángulo alpha fuera de (0°, 90°)" % c.id)
		assert_true(c.reach > 0, "%s: falta alcance (reach, mm)" % c.id)
		assert_true(c.strike.v > 0 and c.strike.m > 0, "%s: falta golpe (strike.v, strike.m)" % c.id)
		assert_true(c.strike.m < c.mass, "%s: la masa efectiva del golpe no puede superar la del animal" % c.id)
		assert_true(c.force >= Format.FMIN and c.force <= Format.FMAX, "%s: fuerza fuera del deslizador" % c.id)
		assert_true(String(c.get("desc", "")).length() > 20, "%s: falta descripción" % c.id)
		if c.get("fang", false):
			assert_true(c.fBreak > c.force, "%s: un colmillo debe aguantar su propia fuerza máxima" % c.id)


func test_formas_bases_e_incrustaciones_tienen_geometria_y_modulo() -> void:
	for g: Dictionary in Data.GEOMS:
		assert_true(g.area > 0 and g.alpha > 0 and g.alpha < 90 and g.reach > 0, "%s: geometría incompleta" % g.id)
	for b: Dictionary in Data.BASES:
		assert_true(b.hv > 0 and b.E > 0, "%s: falta hv/E" % b.id)
	for i: Dictionary in Data.INLAYS.slice(1):
		assert_true(i.hv > 0 and i.E > 0 and i.area > 0 and i.alpha > 0, "%s: gema incompleta" % i.id)
	assert_true(Data.HUMAN.force >= Format.FMIN and Data.HUMAN.strike.v > 0 and Data.HUMAN.strike.m > 0)


func test_cada_material_tiene_dato_modulo_y_capas_coherentes() -> void:
	for t: Dictionary in Data.TARGETS:
		assert_true(String(t.get("fact", "")).length() > 20, "%s: falta fact" % t.id)
		if not t.get("skin", false):
			assert_true(t.E > 0, "%s: falta módulo E" % t.id)
		if t.get("layers") != null:
			var L: Dictionary = t.layers
			assert_true(L.film.t > 0 and L.film.hv > 0 and L.sub.hv > 0, "%s: capas incompletas" % t.id)
			if L.kind == "hard-on-soft":
				assert_true(L.film.hv > L.sub.hv, "%s: «%s» no cuadra con las durezas" % [t.id, L.kind])
			else:
				assert_eq(L.kind, "paint-on-body", "%s: tipo de capas desconocido" % t.id)
	# la tabla de capas de pintura es contigua; debajo va la carrocería de cada coche
	for i in range(1, Data.PAINT_LAYERS.size()):
		assert_eq(Data.PAINT_LAYERS[i].from, Data.PAINT_LAYERS[i - 1].to)
	for t: Dictionary in Data.TARGETS:
		if not t.get("paint", false):
			continue
		var L: Array = Data.car_layers(t)
		assert_eq(t.layers.film.t, Data.PAINT_LAYERS[-1].to, "%s: la pintura no acaba donde empieza la carrocería" % t.id)
		for i in range(1, L.size()):
			assert_eq(L[i].from, L[i - 1].to, "%s: capas no contiguas" % t.id)
		assert_true(absf(L[-1].to - t.thickness * 1000.0) < 1e-9, "%s: el espesor total no cuadra con pintura + carrocería" % t.id)
		assert_true(t.body.t > 0 and t.body.sigma0 > 0 and t.body.hv > 0 and t.body.E > 0, "%s: carrocería incompleta" % t.id)
	for t: Dictionary in Data.TARGETS:
		var sheet: Variant = Physics.sheet_of(t)
		if sheet != null:
			assert_true(sheet.to > sheet.from, "%s: chapa sin espesor" % t.id)


# ── Geometría de contacto (capa compartida) ──

func test_punta_esfero_conica_inversa_y_continua() -> void:
	for row in [[0.008, 17.0], [0.9, 40.0], [9.0, 75.0], [0.04, 50.0]]:
		var tip := Contact.tip_geometry(row[0], row[1])
		var ht: float = tip.ht
		for h in [1e-4, ht * 0.5, ht, ht * 1.001, ht * 3.0, 5.0]:
			var a := Contact.contact_radius(tip, h)
			assert_true(absf(Contact.depth_for_radius(tip, a) - h) < 1e-9, "inversa rota en h=%s" % Js.js_num_str(h))
		assert_true(absf(Contact.contact_radius(tip, ht - 1e-9) - Contact.contact_radius(tip, ht + 1e-9)) < 1e-6, "salto en la tangencia")


func test_hertz_y_eficiencia_por_durezas() -> void:
	var H := 20.0 * Physics.HV_MPA
	var prev := -1.0
	for F in log_grid(0.01, 1000.0, 60):
		var phi: float = Contact.plastic_fraction(F, 0.5, 2.9, 3.2, H).phi
		assert_true(phi >= prev - 1e-12, "φ baja al subir la fuerza")
		prev = phi
	assert_true(Contact.plastic_fraction(1.0, 0.1, 2.9, 3.2, H).phi > Contact.plastic_fraction(1.0, 1.7, 2.9, 3.2, H).phi)
	assert_eq(Contact.hardness_efficiency(0.79), 0.0)
	assert_eq(Contact.hardness_efficiency(Physics.MODEL.rFull), 1.0)
	assert_true(Contact.hardness_efficiency(1.2) > 0.0 and Contact.hardness_efficiency(1.2) < 1.0)


# ── Invariantes físicas ──

func test_presion_nominal_crece_al_afilar() -> void:
	var sorted := Data.GEOMS.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area < b.area)
	var p: Array = sorted.map(func(g: Dictionary) -> float: return run({ "geom": g, "force": 10.0 }).pNominal)
	for i in range(1, p.size()):
		assert_true(p[i - 1] >= p[i], "presión no decrece con el área (%s)" % sorted[i].id)


## En la 2.0 (unidad 4b) la dureza de la punta de un colmillo es la de su casquete de esmalte en el contacto (tipHv,
## fang_enamel.gd), que pasa de la de su dentina (hvTool): la presión real no supera la de la punta.
func test_la_presion_real_nunca_supera_ninguna_dureza() -> void:
	for t: Dictionary in all_tools:
		for target: Dictionary in Data.TARGETS:
			for method in ["rayado", "puncion"]:
				for force in [0.5, 30.0, Format.FMAX]:
					var r := run(with(t, { "target": target, "force": force, "method": method }))
					var tip_hv: float = r.tipHv if r.get("tipHv") != null else r.hvTool
					assert_true(r.pressure <= tip_hv * Physics.HV_MPA * (1 + 1e-9), "%s→%s: %s MPa > dureza de la punta" % [t.label, target.id, Js.to_fixed(r.pressure, 0)])
					if not target.get("skin", false):
						assert_true(r.pressure <= r.tHV * Physics.HV_MPA * (1 + 1e-9), "%s→%s: presión > dureza del material" % [t.label, target.id])


## «Más blanda» es la punta: en la 2.0 (unidad 4b) la de un colmillo es de esmalte (321 HV, fang_enamel.gd) sobre la
## dentina (50 HV), así que se compara la dureza de la punta al primer contacto (la del esmalte).
func test_una_punta_mas_blanda_nunca_raya_ni_perfora_un_solido() -> void:
	for c: Dictionary in Data.CLAWS:
		var tip_hv: float = FangEnamel.tip_hv(Physics.resolve_tool(base({ "claw": c })), 0.0)
		for t: Dictionary in solids:
			if tip_hv / t.hv >= 0.8:
				continue
			for force in [1.0, 30.0, 500.0, Format.FMAX]:
				for method in ["rayado", "puncion"]:
					var r := run({ "claw": c, "target": t, "force": force, "method": method, "strike": method == "puncion" })
					if r.shattered:  # flexión, no dureza
						assert_true(r.depthUm < 1, "%s parte %s pero además lo perfora" % [c.id, t.id])
						continue
					assert_false(Physics.is_true(r.scratched), "%s (%s HV) daña %s (%s HV) a %s N (%s)" % [c.id, c.hv, t.id, t.hv, force, method])


func test_mas_fuerza_nunca_da_un_surco_menos_profundo() -> void:
	for tid in ["coche", "plastico", "cobre", "puertamadera", "madera"]:
		for tool in [{ "claw": K("gato") }, { "claw": K("casuario") }, { "inlay": I("diamante") }, { "geom": G("cuadrada") }]:
			var prev := -1.0
			for force in log_grid(0.5, Format.FMAX, 40):
				var d: float = run(with(tool, { "target": T(tid), "force": force })).depthUm
				assert_true(d >= prev - 1e-9, "%s: profundidad baja al subir fuerza a %s N" % [tid, f1(force)])
				prev = d


## La geometría del contacto, con el modelo 1.x (la misma mecánica de contacto que la 2.0). En la 2.0 (unidad 4a) una
## uña más afilada también es más larga y cede antes (bending.gd), así que la comparación vale a igual fuerza EN LA
## PUNTA: con 6 N no cede ninguna uña natural (la Stiletto XL, la primera, a ~8,6 N con la fricción del coche).
func test_a_igual_fuerza_la_punta_mas_afilada_llega_mas_hondo() -> void:
	var sorted := Data.GEOMS.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area < b.area)
	for row in [[Physics.MODEL_V1, 20.0], [Physics.MODEL_V2, 6.0]]:
		for tid in ["coche", "plastico", "madera"]:
			var rs: Array = sorted.map(func(g: Dictionary) -> Dictionary: return run({ "geom": g, "force": row[1], "target": T(tid), "model": row[0] }))
			for i in range(1, rs.size()):
				assert_true(rs[i - 1].depthUm >= rs[i].depthUm - 1e-9, "%s (%s): %s más hondo que una forma más afilada" % [tid, row[0], sorted[i].id])
				if row[0] == Physics.MODEL_V2:
					assert_false(rs[i].nail.broken, "%s: a %s N la uña %s no cede" % [tid, row[1], sorted[i].id])


## Regresión (bug real): un umbral binario daba 0,0 µm justo por debajo y el tope justo por encima. Los saltos
## físicos sí existen (pasar de la pintura a un plástico más blando o romper una chapa): se vigila lo anterior.
## Rejilla reducida: cuatro puntas (uña, uña de metal, gema de diamante y garra de tungsteno) en empuje contra todos
## los sólidos, y el casuario al golpe contra las chapas y la puerta de roble (en el JS, las 88 puntas del banco en
## empuje y golpe contra todos).
func test_la_puncion_crece_de_forma_continua() -> void:
	var cases: Array = []
	for t: Dictionary in [rep_tools[1], rep_tools[3], rep_tools[6], rep_tools[12]]:
		for target: Dictionary in Data.TARGETS:
			if not target.get("skin", false):
				cases.append([t, target, false])
	for tid in ["coche", "cocheplastico", "puertametal", "puertamadera"]:
		cases.append([rep_tools[9], T(tid), true])
	var forces := log_grid(0.5, 200.0, 160)
	for row: Array in cases:
		var t: Dictionary = row[0]
		var target: Dictionary = row[1]
		var pop := _pop_at(target)
		var d: Array[float] = []
		for force in forces:
			var um: float = run(with(t, { "target": target, "force": force, "method": "puncion", "strike": row[2] })).depthUm
			if um < pop - 1e-6:
				d.append(um)
		for i in range(1, d.size()):
			# Con +4 % de fuerza, h ∝ √F crece ~2 % (hasta ~10 % al hundirse la laca en la madera). Se toleran 15 %
			# relativos (u 8 µm al arrancar desde 0). El bug original saltaba de 0 a ~130 µm.
			var jump := d[i] - d[i - 1]
			var allowed := maxf(8.0, 0.15 * d[i - 1])
			assert_true(jump <= allowed, "%s→%s%s: salto de %s µm (máx %s)" % [t.label, target.id, " (golpe)" if row[2] else "", f1(jump), f1(allowed)])


static func _pop_at(t: Dictionary) -> float:
	if t.get("body") != null and t.body.hv < t.layers.film.hv:
		return t.layers.film.t
	var sheet: Variant = Physics.sheet_of(t)
	return sheet.to * 1000.0 if sheet != null else INF


func test_mas_pasadas_nunca_reducen_el_surco() -> void:
	for t: Dictionary in Data.TARGETS:
		if t.get("skin", false):
			continue
		var one := run({ "target": t, "force": 20.0 })
		var many := run({ "target": t, "force": 20.0, "passes": 100.0 })
		assert_true(many.depthUm >= one.depthUm - 1e-9, "%s: 100 pasadas < 1 pasada" % t.id)
		if one.ratio != null and one.ratio < 0.8:
			assert_false(Physics.is_true(many.scratched), "%s: 100 pasadas rayan algo más duro" % t.id)


func test_un_roce_no_desgasta_mas_que_un_aranazo_ni_este_que_un_surco() -> void:
	for tid in ["coche", "plastico", "madera", "cobre"]:
		var w: Array = Data.TYPES.map(func(ty: Dictionary) -> float: return run({ "target": T(tid), "force": 20.0, "type": ty }).wearIdx)
		for i in range(1, w.size()):
			assert_true(w[i] >= w[i - 1], "%s: desgaste %s" % [tid, w])


func test_puncion_nunca_mas_honda_que_la_propia_garra() -> void:
	for c: Dictionary in Data.CLAWS:
		for target: Dictionary in Data.TARGETS:
			for strike in [false, true]:
				var r := run({ "claw": c, "target": target, "force": Format.FMAX, "method": "puncion", "strike": strike })
				assert_true(r.depthUm <= c.reach * 1000.0 + 1e-6, "%s→%s: %s µm > %s mm" % [c.id, target.id, Js.js_num_str(r.depthUm), c.reach])


func test_rayando_tampoco_y_entonces_marca_el_tope() -> void:
	for t: Dictionary in all_tools:
		var reach: float = t.claw.reach if t.get("claw") != null else (t.get("geom", G("almendra")) as Dictionary).reach
		for target: Dictionary in Data.TARGETS:
			for tear in [false, true]:
				for passes in [1.0, 100.0]:
					var r := run(with(t, { "target": target, "force": Format.FMAX, "tear": tear, "passes": passes, "type": Data.TYPES[2] }))
					assert_true(r.depthUm <= reach * 1000.0 + 1e-6, "%s→%s: surco de %s µm > %s mm" % [t.label, target.id, Js.js_num_str(r.depthUm), reach])
					if r.depthUm >= reach * 1000.0 - 1e-6:
						assert_true(r.fullReach, "%s→%s: llega al tope sin decirlo" % [t.label, target.id])
	# el caso que lo destapó: una garra de pájaro de 4 mm abría un surco de 9,5 mm en madera de pino a 300 N
	assert_eq(run({ "claw": K("pajaro"), "target": T("madera"), "force": 300.0 }).depthUm, K("pajaro").reach * 1000.0)


## Rejilla reducida: las puntas representativas (en el JS, las 88 del banco).
func test_un_golpe_nunca_penetra_menos_que_el_empuje_estatico() -> void:
	for t: Dictionary in rep_tools:
		for target: Dictionary in Data.TARGETS:
			for force in [1.0, 20.0, 300.0]:
				var s := run(with(t, { "target": target, "force": force, "method": "puncion" }))
				var k := run(with(t, { "target": target, "force": force, "method": "puncion", "strike": true }))
				assert_true(k.depthUm >= s.depthUm - 1e-6 or k.toolBroken, "%s→%s a %s N: golpe %s < estático %s" % [t.label, target.id, force, k.depthUm, s.depthUm])


func test_la_queratina_no_corta_la_chapa_de_acero() -> void:
	for c: Dictionary in Data.CLAWS:
		if c.get("fang", false):
			continue
		for tear in [false, true]:
			var r := run({ "claw": c, "force": Format.FMAX, "tear": tear, "passes": 100.0, "type": Data.TYPES[-1] })
			assert_true(r.depthUm <= 110 + 1e-6, "%s: %s µm atraviesa el acero" % [c.id, Js.to_fixed(r.depthUm, 0)])
	assert_true(run({ "inlay": I("diamante"), "force": 500.0 }).depthUm > 110, "un diamante sí debe entrar en la chapa")


func test_la_daga_del_casuario_llega_mas_hondo_que_la_una_del_avestruz() -> void:
	for row in [["coche", 5.0], ["coche", 15.0], ["plastico", 50.0], ["plastico", 500.0]]:
		var cas := run({ "claw": K("casuario"), "target": T(row[0]), "force": row[1] })
		var ost := run({ "claw": K("avestruz"), "target": T(row[0]), "force": row[1] })
		assert_true(cas.depthUm > ost.depthUm, "%s a %s N: casuario %s ≤ avestruz %s" % [row[0], row[1], cas.depthUm, ost.depthUm])


func test_solo_la_patada_del_casuario_atraviesa_la_puerta_de_roble() -> void:
	var through: Array = []
	for c: Dictionary in Data.CLAWS:
		if run({ "claw": c, "target": T("puertamadera"), "force": c.force, "method": "puncion", "strike": true }).verdict == "ATRAVIESA LA PUERTA":
			through.append(c.id)
	assert_eq(through, ["casuario"])


func test_los_colmillos_se_rompen_por_encima_de_30_newtons() -> void:
	assert_eq(run({ "claw": K("vibora"), "target": T("vidrio"), "force": 40.0, "method": "puncion" }).toolBroken, true)
	var ok := run({ "claw": K("vibora"), "target": T("piel"), "force": 4.0, "method": "puncion" })
	# en la 2.0 (unidad 4b) la piel dice si se rompe (contra el hueso puede): false; en la 1.x no lo decía (null)
	assert_false(Js.truthy(ok.get("toolBroken")), "en piel, a su fuerza máxima, no debe romperse")


func test_una_una_humeda_nunca_raya_mas_que_seca() -> void:
	for g: Dictionary in Data.GEOMS:
		for t: Dictionary in Data.TARGETS:
			if t.get("skin", false):
				continue
			for force in [4.0, 30.0]:
				var dry := run({ "geom": g, "target": t, "force": force })
				var wet := run({ "geom": g, "target": t, "force": force, "wet": true })
				assert_true(wet.depthUm <= dry.depthUm + 1e-9, "%s→%s: húmeda %s > seca %s" % [g.id, t.id, wet.depthUm, dry.depthUm])
	# el gel y el acrílico no son queratina: el agua no los cambia
	var acr := { "base": B("acrilico"), "force": 30.0 }
	assert_eq(run(with(acr, { "wet": true })).depthUm, run(acr).depthUm)


func test_piel_por_capas_continua_y_la_dermis_resiste_mas() -> void:
	var L: Array = Data.SKIN_LAYERS
	for i in L.size():
		var l: Dictionary = L[i]
		assert_true(l.to > l.from and l.jT > 0 and l.jC > 0 and l.jC <= l.jT, "%s: capa inválida" % l.id)
		if i > 0:
			assert_eq(l.from, L[i - 1].to, "%s: hueco o solape con la capa de arriba" % l.id)
	var dermis: Dictionary = Data.find_by_id(L, "dermis")
	for id in ["grasa", "fascia", "musculo"]:
		var l: Dictionary = Data.find_by_id(L, id)
		assert_true(l.jC < dermis.jC and l.jT < dermis.jT, "%s resiste más que la dermis" % id)


func test_piel_al_rayar_mas_fuerza_pasadas_o_tipo_nunca_dejan_menos_herida() -> void:
	var tools: Array = [{}, { "geom": G("stiletto") }, { "geom": G("cuadrada") }]
	for c: Dictionary in Data.CLAWS:
		tools.append({ "claw": c })
	for c: Dictionary in Data.CLAWS:
		if c.curve > 0.5:
			tools.append({ "claw": c, "tear": true })
	for t: Dictionary in tools:
		var label := who(t) + ("+desgarro" if t.get("tear", false) else "")
		var prev := -1.0
		var prev_sev := -1.0
		for force in log_grid(Format.FMIN, Format.FMAX, 60):
			var r := run(with(t, { "target": T("piel"), "force": force }))
			assert_true(r.depthUm >= prev - 1e-9 and r.sev >= prev_sev - 1e-9, "%s: %s N da menos herida" % [label, f1(force)])
			prev = r.depthUm
			prev_sev = r.sev
		var prev_p := -1.0
		for passes in [1.0, 2.0, 5.0, 20.0, 100.0]:
			var d: float = run(with(t, { "target": T("piel"), "force": 8.0, "passes": passes })).depthUm
			assert_true(d >= prev_p - 1e-9, "%s: más pasadas, menos herida" % label)
			prev_p = d
		var by_type: Array = ["roce", "aranazo", "surco"].map(func(id: String) -> float: return run(with(t, { "target": T("piel"), "force": 8.0, "type": TY(id) })).depthUm)
		assert_true(by_type[0] <= by_type[1] + 1e-9 and by_type[1] <= by_type[2] + 1e-9, "%s: roce ≤ arañazo ≤ surco" % label)


func test_piel_desgarrar_hiere_mas_que_arrastrar() -> void:
	for c: Dictionary in Data.CLAWS:
		for force in [2.0, 15.0, 150.0]:
			var drag := run({ "claw": c, "target": T("piel"), "force": force })
			var tear := run({ "claw": c, "target": T("piel"), "force": force, "tear": true })
			assert_true(tear.depthUm >= drag.depthUm - 1e-9, "%s %s N" % [c.id, force])


func test_piel_si_perfora_empujando_arrastrando_tambien_rompe() -> void:
	var tools: Array = [{}, { "geom": G("stiletto") }]
	for c: Dictionary in Data.CLAWS:
		tools.append({ "claw": c })
	for t: Dictionary in tools:
		for force in log_grid(Format.FMIN, 200.0, 30):
			var stab := run(with(t, { "target": T("piel"), "force": force, "method": "puncion" }))
			if stab.pierces:
				assert_eq(run(with(t, { "target": T("piel"), "force": force })).ruptures, true, "%s %s N" % [who(t), Js.to_fixed(force, 2)])


## Con el modelo 1.x (el de la piel es el mismo en la 2.0). En la 2.0 (unidad 4a) la uña natural cede antes de los 30 N
## (bending.gd): por debajo de su carga de cesión siguen todas las situaciones, y por encima manda «SE DOBLA LA UÑA» con el
## daño hecho hasta entonces (abajo).
func test_piel_todas_las_situaciones_existen() -> void:
	var v := func(over: Dictionary) -> String: return run(with({ "target": T("piel"), "model": Physics.MODEL_V1 }, over)).verdict
	assert_eq(v.call({ "geom": G("cuadrada"), "force": 0.5 }), "SIN MARCA")
	assert_eq(v.call({ "force": 1.0 }), "MARCA ROJA")
	assert_eq(v.call({ "force": 4.0 }), "RASGUÑO BLANCO")  # rascarse: raya blanca
	assert_eq(v.call({ "geom": G("cuadrada"), "force": 30.0 }), "RASGUÑO BLANCO")  # solo la capa córnea
	assert_eq(v.call({ "force": 30.0 }), "RASGUÑOS")  # almendra: excoria la epidermis
	assert_eq(v.call({ "force": 30.0, "passes": 20.0 }), "RASGUÑOS QUE SANGRAN")  # a fuerza de pasadas
	assert_eq(v.call({ "claw": K("gato"), "force": 3.0 }), "ARAÑAZO QUE SANGRA")
	assert_eq(v.call({ "claw": K("gato"), "force": 15.0, "tear": true }), "DESGARRO PROFUNDO")
	assert_eq(v.call({ "claw": K("tigre"), "force": 260.0 }), "LACERACIÓN PROFUNDA")
	assert_eq(v.call({ "claw": K("vibora"), "force": 4.0, "method": "puncion" }), "PUNCIÓN · INYECTA")
	assert_eq(v.call({ "force": 30.0, "method": "puncion" }), "NO PERFORA")
	# una uña humana roma nunca perfora ni desgarra piel sana con su fuerza máxima
	assert_false(run({ "geom": G("cuadrada"), "target": T("piel"), "force": Data.HUMAN.force }).ruptures)
	# 2.0: por debajo de la cesión de la uña (almendra, ~18,3 N con la fricción de la piel), las mismas situaciones
	var v2 := func(over: Dictionary) -> Dictionary: return run(with({ "target": T("piel") }, over))
	assert_eq(v2.call({ "force": 18.0 }).verdict, "RASGUÑOS", "2.0: excoria la epidermis por debajo de la cesión")
	assert_eq(v2.call({ "force": 18.0, "passes": 20.0 }).verdict, "RASGUÑOS QUE SANGRAN", "2.0: a fuerza de pasadas")
	assert_eq(v2.call({ "force": 4.0 }).verdict, "RASGUÑO BLANCO", "2.0: rascarse")
	for over: Dictionary in [{ "geom": G("cuadrada"), "force": 30.0 }, { "force": 30.0 }, { "force": 30.0, "passes": 20.0 }]:
		var r: Dictionary = v2.call(over)
		# el daño de la carga de cesión, tal cual lo describe la piel (el mismo modelo en la 1.x, sin la uña)
		var at_break: Dictionary = v2.call(with(over, { "force": r.nail.breakN, "model": Physics.MODEL_V1 }))
		assert_eq(r.verdict, "SE DOBLA LA UÑA", "2.0: a 30 N la uña natural se dobla (%s)" % JSON.stringify(over))
		assert_true(String(r.vsub).ends_with("hasta entonces, " + String(at_break.vsub)), "2.0: con el daño de la carga de cesión (%s)" % r.vsub)
		assert_eq(r.depthUm, at_break.depthUm, "2.0: la profundidad de la carga de cesión")


func test_piel_solo_sangra_si_pasa_la_epidermis() -> void:
	var epi: float = Data.find_by_id(Data.SKIN_LAYERS, "epidermis").to
	var tools: Array = [{}, { "geom": G("stiletto") }]
	for c: Dictionary in Data.CLAWS:
		tools.append({ "claw": c })
	for t: Dictionary in tools:
		for force in [1.0, 4.0, 15.0, 60.0]:
			for method in ["rayado", "puncion"]:
				var r := run(with(t, { "target": T("piel"), "force": force, "method": method }))
				if r.depthUm > epi:
					assert_true(r.bleeds, "%s: pasa la epidermis y no sangra" % r.verdict)
				if r.depthUm < epi and r.depthUm > 0:
					assert_true(not r.bleeds or r.verdict == "RASGUÑOS QUE SANGRAN", "%s: sangra sin llegar a la dermis" % r.verdict)


func test_piel_puncion_con_la_fuerza_medida_in_vivo() -> void:
	for c: Dictionary in Data.CLAWS:
		var f_puncture: float = run({ "claw": c, "target": T("piel"), "force": 1.0, "method": "puncion" }).fPuncture
		if f_puncture > Format.FMIN * 1.05:
			assert_eq(run({ "claw": c, "target": T("piel"), "force": f_puncture * 0.95, "method": "puncion" }).pierces, false, "%s perfora por debajo" % c.id)
		assert_eq(run({ "claw": c, "target": T("piel"), "force": maxf(f_puncture * 1.05, Format.FMIN), "method": "puncion" }).pierces, true, "%s no perfora por encima" % c.id)
	# una uña almendra no perfora la piel empujando con la fuerza máxima humana
	assert_eq(run({ "target": T("piel"), "force": Data.HUMAN.force, "method": "puncion" }).pierces, false)


func test_solo_los_colmillos_inyectan() -> void:
	for c: Dictionary in Data.CLAWS:
		var r := run({ "claw": c, "target": T("piel"), "force": c.force, "method": "puncion" })
		assert_eq(Physics.truthy(r.get("inject")), Physics.truthy(c.get("fang")), "%s: inject=%s" % [c.id, r.get("inject")])


## Contrato del resultado: todo lo que pinta la interfaz existe y es finito (regresión: al rayar piel faltaba
## grooveWidthUm). Rejilla reducida: las puntas representativas (en el JS, las 88 del banco).
func test_contrato_del_resultado() -> void:
	for t: Dictionary in rep_tools:
		for target: Dictionary in Data.TARGETS:
			for m in [["rayado", false, false], ["rayado", false, true], ["puncion", false, false], ["puncion", true, false]]:
				for force in [Format.FMIN, 7.0, 150.0, Format.FMAX]:
					var r := run(with(t, { "target": target, "force": force, "method": m[0], "strike": m[1], "tear": m[2] }))
					var where := "%s→%s %s%s" % [t.label, target.id, m[0], "+golpe" if m[1] else ""]
					for k in ["depthUm", "pressure", "pNominal", "sev", "wearIdx", "Fadh_mN", "Ffric", "mu", "phi", "energyJ", "contactAreaMm2", "tipRadiusUm", "alphaDeg"]:
						assert_true(is_num(r.get(k)) and is_finite(r[k]), "%s: %s=%s" % [where, k, r.get(k)])
					for k in ["verdict", "vsub", "vcol", "cede"]:
						assert_true(r.get(k) is String, "%s: %s" % [where, k])
					# la piel no tiene dureza Vickers: ratio y χ son null; la anchura de la herida sí se calcula
					for k in ["ratio", "chi"]:
						if target.get("skin", false):
							assert_true(r.has(k) and r[k] == null, "%s: %s debería ser null en la piel" % [where, k])
						else:
							assert_true(is_num(r.get(k)) and is_finite(r[k]) and r[k] >= 0, "%s: %s=%s" % [where, k, r.get(k)])
					assert_true(is_num(r.get("grooveWidthUm")) and is_finite(r.grooveWidthUm) and r.grooveWidthUm >= 0, "%s: grooveWidthUm" % where)
					if target.get("skin", false):
						assert_true(r.layer == null if r.depthUm == 0 else r.layer is String, "%s: capa alcanzada" % where)
					if not r.skin and not r.puncture and not r.paint:
						assert_true(is_finite(r.muEff), "%s: muEff" % where)
					assert_true(r.sev >= 0 and r.sev <= 1, "%s: sev fuera de [0,1]" % where)


# ── Uñas experimentales (macizas de otro material) y Stiletto XL ──

static func _scratches(geom: String, mat: String, target: String, force: float = 30.0, model: String = Physics.MODEL_V2) -> Variant:
	return run({ "geom": G(geom), "base": B(mat), "target": T(target), "force": force, "model": model }).scratched


## A igual fuerza en la punta, afilar nunca resta: con el modelo 1.x siempre (la misma mecánica de contacto), y con la
## 2.0 mientras ninguna de las tres uñas ceda (unidad 4a: la stiletto, más larga, se dobla o se parte antes que la
## cuadrada, y entonces a su punta llega menos fuerza; bending.gd).
func test_afilar_nunca_resta() -> void:
	var compared := 0
	for model in [Physics.MODEL_V1, Physics.MODEL_V2]:
		for b: Dictionary in Data.BASES:
			for t: Dictionary in Data.TARGETS:
				for force in [1.0, 5.0, 30.0, 200.0, 2000.0]:
					for method in ["rayado", "puncion"]:
						var rs: Array = ["cuadrada", "stiletto", "stilettoxl"].map(func(g: String) -> Dictionary: return run({ "geom": G(g), "base": b, "target": t, "force": force, "method": method, "model": model }))
						if model == Physics.MODEL_V2 and rs.any(func(r: Dictionary) -> bool: return r.nail != null and r.nail.broken):
							continue
						var d: Array = rs.map(func(r: Dictionary) -> float: return r.depthUm)
						compared += 1
						assert_true(d[0] <= d[1] + 1e-9 and d[1] <= d[2] + 1e-9, "%s→%s %s N %s (%s): %s" % [b.id, t.id, force, method, model, d])
	assert_true(compared > 1000, "comparaciones: %d" % compared)


## La lección de durezas, con el modelo 1.x. En la 2.0 (unidad 4a) el veredicto de los no frágiles es la huella que queda
## al levantar la punta (Oliver & Pharr 1992): la cuadrada de acero, roma, se hunde en el ABS pero el ABS la recupera
## entera; las demás formas siguen rayándolo, y el cobre, todas. El vidrio y el acero, nunca.
func test_acero_macizo_raya_plastico_y_cobre_nunca_el_vidrio() -> void:
	for g: Dictionary in Data.GEOMS:
		assert_eq(_scratches(g.id, "metal", "plastico", 30.0, Physics.MODEL_V1), true, g.id)
		assert_eq(_scratches(g.id, "metal", "cobre", 30.0, Physics.MODEL_V1), true, g.id)
		assert_eq(_scratches(g.id, "metal", "vidrio", 30.0, Physics.MODEL_V1), false, g.id)
		assert_eq(_scratches(g.id, "titanio", "acero", 30.0, Physics.MODEL_V1), false, g.id)
		# 2.0
		var abs_r := run({ "geom": g, "base": B("metal"), "target": T("plastico"), "force": 30.0 })
		if g.id == "cuadrada":
			assert_true(abs_r.depthUm > 1.0 and abs_r.residualDepthUm <= 0.0 and not Physics.truthy(abs_r.scratched), "cuadrada de acero en el ABS: se hunde y recupera (%s)" % abs_r.verdict)
		else:
			assert_eq(abs_r.scratched, true, "%s de acero raya el ABS" % g.id)
		assert_eq(_scratches(g.id, "metal", "cobre"), true, "%s de acero raya el cobre (2.0)" % g.id)
		assert_eq(_scratches(g.id, "metal", "vidrio"), false, "%s de acero no raya el vidrio (2.0)" % g.id)
		assert_eq(_scratches(g.id, "titanio", "acero"), false, "%s de titanio no raya el acero (2.0)" % g.id)


func test_zafiro_y_diamante_macizos_rayan_el_vidrio_con_punta_fina() -> void:
	for m in ["zafiro", "diamante"]:
		assert_eq(_scratches("stiletto", m, "vidrio"), true, "%s stiletto" % m)
		assert_eq(_scratches("stilettoxl", m, "cuarzo"), true, "%s stiletto XL → cuarzo" % m)
		var blunt := run({ "geom": G("cuadrada"), "base": B(m), "target": T("vidrio"), "force": Data.HUMAN.force })
		assert_eq(blunt.scratched, false, "%s cuadrada" % m)
		assert_true(blunt.phi < 0.5, "%s cuadrada: φ = %s" % [m, blunt.phi])
	assert_eq(_scratches("stilettoxl", "diamante", "zafiro"), true)
	assert_false(Physics.is_true(_scratches("stilettoxl", "zafiro", "diamante")), "el zafiro no raya el diamante")


func test_solo_la_queratina_se_ablanda_con_agua() -> void:
	for b: Dictionary in Data.BASES:
		if b.get("keratin", false):
			continue
		for t: Dictionary in solids:
			var p := { "base": b, "target": t, "force": 30.0 }
			assert_eq(run(with(p, { "wet": true })).depthUm, run(p).depthUm, "%s→%s" % [b.id, t.id])


# ── Coches, chapas finas y vidrio ──

## Etapa de daño en punción: 0 nada · 1 pintura · 2 se clava en la carrocería · 3 la perfora · 4 la atraviesa
static func _stage(r: Dictionary) -> int:
	var v: String = r.verdict
	if v.begins_with("ATRAVIESA"):
		return 4
	if v.begins_with("PERFORA LA") or v.begins_with("PERFORA EL"):
		return 3
	if r.depthUm > 110 + 1:
		return 2
	return 1 if Physics.truthy(r.scratched) else 0


static func _cars(metal_only := false) -> Array:
	return Data.TARGETS.filter(func(t: Dictionary) -> bool: return t.get("paint", false) and (not metal_only or t.body.metal))


func test_queratina_y_dentina_no_pasan_de_la_pintura_en_un_coche_de_metal() -> void:
	for c: Dictionary in Data.CLAWS:
		for t: Dictionary in _cars(true):
			for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
				for force in [1.0, 30.0, 500.0, Format.FMAX]:
					var r := run({ "claw": c, "target": t, "force": force, "method": m[0], "strike": m[1] })
					assert_true(r.depthUm <= 110 + 1e-6, "%s→%s %s%s %s N: %s µm en el metal" % [c.id, t.id, m[0], "+golpe" if m[1] else "", force, Js.to_fixed(r.depthUm, 0)])
	var bear := run({ "claw": K("oso"), "target": T("cocheplastico"), "force": 300.0, "method": "puncion", "strike": true })
	assert_true(_stage(bear) >= 3, "el zarpazo de oso debería perforar la aleta de plástico (%s)" % bear.verdict)


func test_mas_fuerza_nunca_retrocede_de_etapa_ni_de_profundidad() -> void:
	for t: Dictionary in hard_tools:
		for target: Dictionary in _cars() + [T("puertametal")]:
			var prev: Variant = null
			for force in log_grid(1.0, Format.FMAX, 36):
				var r := run(with(t, { "target": target, "force": force, "method": "puncion" }))
				if prev != null:
					assert_true(_stage(r) >= _stage(prev), "%s→%s %s N: de «%s» a «%s»" % [t.label, target.id, Js.to_fixed(force, 0), prev.verdict, r.verdict])
					assert_true(r.depthUm >= prev.depthUm - 1e-6, "%s→%s %s N: menos profundidad" % [t.label, target.id, Js.to_fixed(force, 0)])
				prev = r


## Rejilla reducida: las puntas representativas y las duras (en el JS, las 88 del banco y las duras).
func test_el_coche_clasico_nunca_se_perfora_antes_que_el_moderno() -> void:
	# su acero dulce es más BLANDO, así que una punta dura lo marca algo más hondo; lo que cuesta más es
	# perforarlo (hay más metal que romper y abrir en pétalos). Se comparan las etapas 3 y 4.
	for t: Dictionary in rep_tools + hard_tools:
		for strike in [false, true]:
			for force in [20.0, 300.0, Format.FMAX]:
				var old := run(with(t, { "target": T("cocheclasico"), "force": force, "method": "puncion", "strike": strike }))
				var now := run(with(t, { "target": T("coche"), "force": force, "method": "puncion", "strike": strike }))
				var holed_old := _stage(old) if _stage(old) >= 3 else 0
				var holed_now := _stage(now) if _stage(now) >= 3 else 0
				assert_true(holed_old <= holed_now, "%s %s N%s: clásico «%s» peor que moderno «%s»" % [t.label, force, " golpe" if strike else "", old.verdict, now.verdict])
				if _stage(old) == 4 and _stage(now) == 4:
					assert_true(old.workJ >= now.workJ - 1e-9, "%s: el clásico absorbe menos energía" % t.label)


## Rejilla reducida: las puntas representativas y las duras (en el JS, las 88 del banco y las duras).
func test_perforar_es_asomar_y_atravesar_es_pasar_entera() -> void:
	for t: Dictionary in rep_tools + hard_tools:
		for target: Dictionary in _cars() + [T("puertametal")]:
			for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
				for force in [30.0, Format.FMAX]:
					var r := run(with(t, { "target": target, "force": force, "method": m[0], "strike": m[1] }))
					var where := "%s→%s %s%s %s N" % [t.label, target.id, m[0], "+golpe" if m[1] else "", force]
					var v: String = r.verdict
					if v.begins_with("ATRAVIESA"):
						assert_true(r.through and r.fullReach, "%s: atraviesa sin pasar entera" % where)
					if v.begins_with("PERFORA LA") or v.begins_with("PERFORA EL"):
						assert_true(r.through and not r.fullReach, "%s: perfora sin salir por detrás" % where)
					if v.begins_with("RAJA"):
						assert_true(r.through and not r.puncture, "%s: raja sin cortar de lado a lado" % where)
					if r.through and not r.toolBroken:
						assert_true(v.begins_with("ATRAVIESA") or v.begins_with("PERFORA") or v.begins_with("RAJA"), "%s: la atraviesa pero dice «%s»" % [where, v])
					assert_true(is_finite(r.workJ) and r.workJ >= 0, "%s: workJ=%s" % [where, r.workJ])


func test_petalos_de_wierzbicki() -> void:
	assert_eq(Physics.petal_energy(0.0, 0.7, 264.0), 0.0)
	for l in [0.2, 1.0, 5.0, 20.0]:
		assert_true(Physics.petal_energy(l * 1.1, 0.7, 264.0) > Physics.petal_energy(l, 0.7, 264.0))
		assert_true(Physics.petal_energy(l, 0.9, 264.0) > Physics.petal_energy(l, 0.7, 264.0))
		assert_true(Physics.petal_energy(l, 0.7, 300.0) > Physics.petal_energy(l, 0.7, 264.0))
	# ec. 58: con R/t > 5 el término principal es 3,37·σ0·t^1,6·D^1,4
	var t := 0.7
	var R := 5.0
	var E := Physics.petal_energy(R, t, 264.0)
	var main := 3.37 * 264.0 * pow(t, 1.6) * pow(2.0 * R, 1.4)
	assert_true(E > main and E < main * 1.1, "ec. 57 frente a 58: %s frente a %s mJ" % [Js.to_fixed(E, 0), Js.to_fixed(main, 0)])


func test_el_vidrio_se_parte_por_flexion() -> void:
	var glass := T("vidrio")
	var pb := Physics.pane_break(glass.pane, glass.E, 0.0)
	var thick: Dictionary = glass.pane.duplicate()
	thick.t = 8.0
	assert_true(Physics.pane_break(thick, 72.0, 0.0).F > 3 * pb.F, "el doble de espesor debería aguantar ~4 veces más")
	# con el modelo 1.x; en la 2.0 (unidad 4a) la uña natural se dobla mucho antes de dar ~200 N (bending.gd), así que la
	# hoja la parte una punta que no cede: la garra de oso, blanda como una uña (no hace falta dureza: un puño también
	# rompe una ventana)
	for g: Dictionary in [G("cuadrada"), G("almendra")]:
		var below := run({ "geom": g, "target": glass, "force": pb.F * 0.9, "method": "puncion", "model": Physics.MODEL_V1 })
		var above := run({ "geom": g, "target": glass, "force": pb.F * 1.2, "method": "puncion", "model": Physics.MODEL_V1 })
		assert_eq(below.shattered, false, "%s: se parte por debajo de %s N" % [g.id, Js.to_fixed(pb.F, 0)])
		assert_eq(above.shattered, true, "%s: no se parte por encima de %s N" % [g.id, Js.to_fixed(pb.F, 0)])
		assert_eq(above.verdict, "ROMPE EL VIDRIO")
		var nail := run({ "geom": g, "target": glass, "force": pb.F * 1.2, "method": "puncion" })
		assert_true(not nail.shattered and nail.nail.broken, "%s natural (2.0): se dobla antes de partir la hoja" % g.id)
	var bear_below := run({ "claw": K("oso"), "target": glass, "force": pb.F * 0.9, "method": "puncion" })
	var bear_above := run({ "claw": K("oso"), "target": glass, "force": pb.F * 1.2, "method": "puncion" })
	assert_eq([bear_below.shattered, bear_above.shattered, bear_above.verdict], [false, true, "ROMPE EL VIDRIO"], "la garra de oso la parte al flexarla (2.0)")
	var hit := func(id: String) -> Dictionary: return run({ "claw": K(id), "target": glass, "force": K(id).force, "method": "puncion", "strike": true })
	assert_eq(hit.call("gato").shattered, false, "un zarpazo de gato no rompe una ventana")
	assert_eq(hit.call("oso").shattered, true, "un zarpazo de oso sí")
	for f in ["vibora", "gabon"]:
		assert_eq(hit.call(f).shattered, false, "%s: el colmillo se rompe antes que el vidrio" % f)


func test_garras_reforjadas_cambian_la_dureza_no_la_forma() -> void:
	for c: Dictionary in [K("aguila"), K("tigre"), K("vibora")]:
		for id in ["acero", "zafiro", "diamante"]:
			var a := run({ "claw": c, "target": T("madera"), "force": 20.0 })
			var b := run({ "claw": c, "inlay": I(id), "target": T("madera"), "force": 20.0 })
			assert_eq(b.alphaDeg, a.alphaDeg, "%s de %s: cambia el ángulo" % [c.id, id])
			assert_eq(b.tipRadiusUm, a.tipRadiusUm, "%s de %s: cambia la punta" % [c.id, id])
			assert_eq(b.hvTool, I(id).hv, "%s de %s: no tiene la dureza del material" % [c.id, id])


# ── Modo dual: el mismo ensayo en dos coches ──

func test_la_pareja_por_defecto_es_clasico_contra_moderno() -> void:
	assert_eq(Lab.DUEL_DEFAULT, ["cocheclasico", "coche"])
	for t: Dictionary in Lab.DUEL_CARS:
		assert_true(t.get("body") != null and t.get("paint", false), "%s no es un coche" % t.id)
		assert_true(Lab.target_sub(t).begins_with("pintura + "), "%s: ficha sin carrocería" % t.id)


func test_el_veredicto_del_duelo_no_depende_del_orden() -> void:
	var tools: Array = all_tools.slice(0, 60) + [{ "label": "águila de acero", "claw": K("aguila"), "inlay": I("acero") }]
	for t: Dictionary in tools:
		for pair in [Lab.DUEL_DEFAULT, ["coche", "cocheplastico"], ["cochealu", "cocheclasico"]]:
			var cs: Array = [T(pair[0]), T(pair[1])]
			for row: Dictionary in Lab.duel(base(with(t, { "target": cs[0], "force": 30.0 })), t.get("claw"), cs):
				var v := Lab.duel_verdict(row.res[0], row.res[1], cs)
				var w := Lab.duel_verdict(row.res[1], row.res[0], [cs[1], cs[0]])
				var a := Lab.damage_stage(row.res[0])
				var b := Lab.damage_stage(row.res[1])
				if a != b:
					assert_eq(v.winner, 0 if a < b else 1, "%s %s: gana el más dañado" % [t.label, row.id])
				assert_eq(v.winner == null, w.winner == null, "%s %s: el empate depende del orden" % [t.label, row.id])
				if v.winner != null:
					assert_eq(v.winner, 1 - w.winner, "%s %s: cambia el ganador al darles la vuelta" % [t.label, row.id])


func test_informe_de_danos() -> void:
	var hit := run({ "target": T("coche"), "force": 30.0, "claw": K("aguila"), "inlay": I("acero"), "method": "puncion", "strike": true })
	var rep := _pairs(Lab.damage_report(hit, T("coche"), 25.0))
	assert_true(rep.has("Profundidad") and rep.has("Agujero") and rep.has("Energía absorbida"), JSON.stringify(rep))
	var scratch := _pairs(Lab.damage_report(run({ "target": T("coche"), "force": 30.0 }), T("coche"), 25.0))
	assert_false(scratch.has("Energía absorbida"), "rayar no reparte energía de golpe")
	var bear := run({ "target": T("coche"), "force": 300.0, "claw": K("oso"), "method": "puncion", "strike": true })
	assert_true(_pairs(Lab.damage_report(bear, T("coche"))).has("El resto"), "el golpe que no entra debe decir adónde va la energía")


static func _pairs(rows: Array) -> Dictionary:
	var out := {}
	for row: Array in rows:
		out[row[0]] = row[1]
	return out


# ── Laboratorio (logros y etiquetas) ──

func test_cada_logro_que_se_puede_ganar_existe_y_ninguno_es_imposible() -> void:
	var ids := {}
	for b: Dictionary in Lab.BADGES:
		ids[b.id] = true
	var all := {}
	for t: Dictionary in Data.TARGETS:
		for c: Variant in [null] + Data.CLAWS:
			for m in [["rayado", false], ["puncion", false], ["puncion", true]]:
				for wet in [false, true]:
					for inlay: Dictionary in [I("none"), I("diamante")]:
						var res := run({ "target": t, "claw": c, "method": m[0], "strike": m[1], "wet": wet, "inlay": inlay, "force": c.force if c != null else 30.0 })
						var got := Lab.earn_badges({}, { "res": res, "target": t, "claw": c, "method": m[0], "strike": m[1], "inlay": inlay, "runs": Lab.BADGE_RUNS })
						all.merge(got)
	for b in all:
		assert_true(ids.has(b), "logro sin definir: %s" % b)
	assert_eq(ids.keys().filter(func(b: String) -> bool: return not all.has(b)), [], "hay logros imposibles de conseguir")


func test_earn_badges_no_modifica_el_conjunto_anterior() -> void:
	var prev := { "vidrio": true }
	var res := run({ "claw": K("gato"), "target": T("piel"), "force": 15.0 })
	var next := Lab.earn_badges(prev, { "res": res, "target": T("piel"), "claw": K("gato"), "inlay": I("none"), "method": "rayado", "strike": false, "runs": 1 })
	assert_eq(prev.keys(), ["vidrio"])
	assert_true(next.has("piel") and next.has("depredador") and next.has("vidrio"))


func test_etiqueta_del_cuaderno_y_boton_de_fuerza_maxima() -> void:
	var res := run({ "inlay": I("diamante"), "wet": true })
	assert_eq(Lab.tool_label({ "claw": null, "geom": G("almendra"), "inlay": I("diamante"), "res": res }), "Almendra + Diamante")
	assert_eq(Lab.max_force_hint(null).force, Data.HUMAN.force)
	assert_eq(Lab.max_force_hint(K("vibora")).force, K("vibora").force)


func test_aviso_de_licencia() -> void:
	var note := Lab.license_note("2.0.0")
	assert_true(note.begins_with("Scratch Tribology Simulator 2.0.0 "), note)
	assert_true(note.contains("Eric Valls Gramunt"))
	assert_true(note.contains("Licencia MIT"))
	assert_true(note.contains("Open Font License"))


func test_la_ficha_de_una_garra_muestra_el_material_con_el_que_calcula() -> void:
	var spec := func(c: Dictionary, inlay: Dictionary, wet: bool) -> Dictionary:
		return Lab.claw_spec(c, inlay, Physics.resolve_tool({ "geom": G("almendra"), "base": Data.BASES[0], "inlay": inlay, "claw": c, "wet": wet }))
	assert_eq(spec.call(K("aguila"), I("acero"), false), { "title": "Garra de águila de acero", "material": "acero", "hardness": "%s HV · Mohs %s" % [Format.fmt_p(I("acero").hv), Js.js_num_str(I("acero").mohs)] })
	assert_eq(spec.call(K("aguila"), I("none"), false).material, "queratina")
	var wet: Dictionary = spec.call(K("gato"), I("none"), true)
	assert_eq(wet.material, "queratina húmeda")
	assert_eq(wet.hardness, "%s HV · Mohs %s" % [Format.fmt_p(K("gato").hv * 0.2), Js.js_num_str(K("gato").mohs)])
	assert_eq(spec.call(K("vibora"), I("none"), false).material, "dentina")
	assert_eq(spec.call(K("vibora"), I("zafiro"), false).title, "Colmillo de víbora de zafiro")
