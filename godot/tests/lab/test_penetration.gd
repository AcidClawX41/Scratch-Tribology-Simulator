## Penetración profunda por zonas (core/lab/penetration.gd, modelo 2.0): la grieta por capas, el roce de los flancos,
## el hueso y los resolvedores. Invariantes más que números: más fuerza nunca entra menos, más roce nunca entra más, el
## hueso para la queratina, nada entra más que su alcance…
extends "res://tests/case.gd"

const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const Sting = preload("res://core/lab/sting.gd")
const Zones = preload("res://core/lab/zones.gd")
const Pen = preload("res://core/lab/penetration.gd")

const BONE_ZONES := ["brazo", "palma", "dorsomano", "cara"]


static func K(id: String) -> Dictionary:
	return Data.find_by_id(Data.CLAWS, id)


static func I(id: String) -> Dictionary:
	return Data.find_by_id(Data.INLAYS, id)


static func G(id: String) -> Dictionary:
	return Data.find_by_id(Data.GEOMS, id)


## La herramienta resuelta y su punta, como las prepara compute(). tool: { claw?, inlay?, geom?, base?, wet? }.
static func tool_of(t: Dictionary) -> Dictionary:
	var p := {
		"geom": t.get("geom", G("almendra")), "base": t.get("base", Data.BASES[0]), "inlay": t.get("inlay", I("none")),
		"claw": t.get("claw"), "wet": t.get("wet", false),
	}
	return Physics.resolve_tool(p)


static func tip_of(tool: Dictionary) -> Dictionary:
	return Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)


static func punct(t: Dictionary, zone: String, force: float, strike := false, xi: Variant = null) -> Dictionary:
	var tool := tool_of(t)
	var p := {
		"tool": tool, "tip": tip_of(tool), "zone": zone, "force": force, "strike": strike,
		"energyJ": tool.strikeJ if strike else 0.0,
	}
	if xi != null:
		p.xi = xi
	return Pen.puncture(p)


static func rig_of(t: Dictionary, zone: String, xi := 0.05, h_max := 60.0) -> Dictionary:
	var tool := tool_of(t)
	return Pen.make_rig(tip_of(tool), tool, Zones.stack(zone), Zones.bone(zone), xi, minf(h_max, tool.reach))


## Parámetros de compute() (los del banco por defecto, con over encima) sobre la piel, con el motor 1.x: lo que
## skin_report necesita de él (q_of). Unidad 4b: el modelo va explícito, porque el 2.0 por defecto ya integra este informe.
static func params(over: Dictionary) -> Dictionary:
	var p := {
		"geom": G("almendra"), "base": Data.BASES[0], "inlay": I("none"), "claw": null,
		"target": Data.find_by_id(Data.TARGETS, "piel"), "type": Data.find_by_id(Data.TYPES, "aranazo"), "force": 4.0,
		"length": 25.0, "tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false, "model": "1.x",
	}
	p.merge(over, true)
	return p


## Lo que skin_report necesita del motor 1.x, sacado del resultado de compute() (r1) con los mismos parámetros.
static func q_of(p: Dictionary, r1: Dictionary, zone: Variant) -> Dictionary:
	var tool := Physics.resolve_tool(p)
	return {
		"tool": tool, "tip": tip_of(tool), "zone": zone, "puncture": p.method == "puncion", "strike": p.strike,
		"Neff": float(p.force) + float(r1.Fadh_mN) / 1000.0, "energyJ": r1.energyJ, "passes": p.passes,
		"stress": r1.stress, "tearForce": r1.get("tearForce", 0.0), "ruptures": r1.get("ruptures", false),
	}


## Garras y colmillos del banco (naturales), una uña afilada y una roma.
static func bench_tools() -> Array:
	var out: Array = [{ "label": "uña stiletto", "geom": G("stiletto") }, { "label": "uña almendra", "geom": G("almendra") }]
	for c: Dictionary in Data.CLAWS:
		out.append({ "label": c.id, "claw": c })
	return out


# ── La grieta ──

## Con una sola capa y una punta sin base, la grieta 2.0 es la de la 1.x: 2·J·a(h).
func test_una_capa_y_sin_base_es_la_grieta_de_la_1x() -> void:
	var one := [{ "id": "dermis", "from": 0.0, "to": 1e9, "jT": 17.0, "jC": 1.7, "E": 210.0 }]
	for t: Dictionary in [{ "geom": G("stiletto") }, { "geom": G("cuadrada") }, { "claw": K("gato") }, { "claw": K("vibora") }]:
		var tool := tool_of(t)
		var tip := Contact.tip_geometry(tool.area, tool.alpha)  # sin base
		var rig := Pen.make_rig(tip, tool, one, null, 0.0, 50.0)
		for h in [1e-4, 0.01, 0.05, 0.3, 2.0, 12.0, 45.0]:
			var got: float = Pen.parts(rig, h).crack
			var want := 2.0 * 1.7 * Contact.contact_radius(tip, h)
			assert_near(got, want, 1e-12, 1e-15, "%s h=%s" % [tool.alpha, h])
			assert_eq(Pen.parts(rig, h).friction, 0.0, "sin roce con ξ = 0")


## La grieta nunca es más ancha que la herramienta: con base, la fuerza de la grieta no pasa de 2·máx(J)·a_base.
func test_la_grieta_nunca_es_mas_ancha_que_la_herramienta() -> void:
	for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("gabon") }, { "claw": K("gato") }, { "claw": K("casuario") }]:
		var tool := tool_of(t)
		var rig := rig_of(t, "brazo", 0.0)
		var cap: float = 2.0 * 1.7 * tool.baseR
		for h in [0.5, 2.0, 5.0, 20.0, 40.0]:
			if h <= tool.reach:
				assert_true(Pen.parts(rig, h).crack <= cap * (1.0 + 1e-9), "%s a %s mm" % [t.claw.id, h])


## La resistencia de la grieta es continua al pasar de una capa a otra (ya no cae de golpe al salir de la dermis). Junto
## a la frontera cambia como la raíz de la distancia (el casquete esférico de la punta, ρ ≈ √(2R·s)): con ε = 10⁻¹² mm
## el salto es de ~10⁻⁷ N, y se hace 100 veces menor al acercarse 10⁴ veces más.
func test_la_grieta_es_continua_entre_capas() -> void:
	for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("gato") }, { "claw": K("tigre") }, { "geom": G("stiletto") }]:
		for zone: String in Zones.ids():
			var rig := rig_of(t, zone, 0.0)
			for l: Dictionary in Zones.stack(zone):
				var b: float = l.to / 1000.0
				if b >= rig.hMax:
					continue
				var jump := func(eps: float) -> float: return absf(Pen.parts(rig, b + eps).crack - Pen.parts(rig, b - eps).crack)
				var who: String = t.claw.id if t.has("claw") else "uña"
				assert_true(jump.call(1e-12) < 1e-5, "%s en %s: salto de %s N en %s" % [who, zone, jump.call(1e-12), l.id])
				assert_true(jump.call(1e-12) <= jump.call(1e-8) / 20.0 + 1e-15, "%s en %s: no se cierra en %s" % [who, zone, l.id])


# ── El roce de los flancos ──

func test_presion_de_los_flancos() -> void:
	# ⟨p⟩/μ = 0,8613 + 1,434·(J/μR)^0,844 (Fregonese & Bacca 2022, α = 9)
	var mu := 210.0 / 3.0 / 1000.0
	var want := mu * (0.8613 + 1.434 * pow(1.7 / (mu * 0.5), 0.844))
	assert_near(Pen.flank_pressure_mpa(210.0, 1.7, 0.5), want, 1e-9, 1e-12, "dermis, R = 0,5 mm")
	var prev := INF
	for r in [0.01, 0.05, 0.2, 1.0, 5.0]:
		var p := Pen.flank_pressure_mpa(210.0, 1.7, r)
		assert_true(p < prev and p > 0.8613 * mu, "más ancha, menos presión (y nunca menos que ⟨p⟩₀)")
		prev = p
	# la grasa, blandísima, aprieta menos que la dermis con la misma herramienta
	assert_true(Pen.flank_pressure_mpa(1.9, 0.41, 0.5) < Pen.flank_pressure_mpa(210.0, 1.7, 0.5))
	assert_eq(Pen.layer_e_kpa({ "E": null }), 210.0, "sin E: el de la dermis")


func test_el_roce_crece_con_la_profundidad_y_con_xi() -> void:
	for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("aguila") }, { "geom": G("stiletto") }]:
		var r05 := rig_of(t, "brazo", 0.05)
		var r10 := rig_of(t, "brazo", 0.1)
		var prev := 0.0
		for h in Pen._grid(r05, r05.hMax):
			var f: float = Pen.parts(r05, h).friction
			assert_true(f >= prev - 1e-9, "%s: el roce baja a %s mm" % [t, h])
			prev = f
			assert_near(Pen.parts(r10, h).friction, 2.0 * f, 1e-9, 1e-12, "el roce es proporcional a ξ")


## Las integrales tabuladas del perfil coinciden con las exactas, y la exacta con una integración numérica de ρ(s).
func test_tablas_del_perfil() -> void:
	for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("oso") }, { "geom": G("cuadrada") }, { "geom": G("stiletto") }]:
		var tool := tool_of(t)
		var tip := tip_of(tool)
		var prof := Pen.make_profile(tip, tool.reach, 0.156)
		for s in [1e-5, 3e-4, 0.002, 0.03, 0.2, 1.1, 7.0, tool.reach * 0.9]:
			assert_near(Pen._table(prof, "c1", s), Pen.radius_integral(tip, s), 2e-3, 1e-12, "c1 %s" % s)
			assert_near(Pen._table(prof, "cq", s), Pen.radius_power_integral(tip, s, 0.156), 2e-3, 1e-12, "cq %s" % s)
			# Simpson con 400 tramos tras el cambio u = s·w² (quita la raíz de ρ junto al ápice): ∫₀ˢ f du = ∫₀¹ f(s·w²)·2s·w dw
			var n := 400
			var w1 := 0.0
			var wq := 0.0
			for k in n + 1:
				var w := float(k) / n
				var c := 1.0 if k == 0 or k == n else (4.0 if k % 2 == 1 else 2.0)
				var rho := Pen.tool_radius(tip, s * w * w)
				var jac: float = 2.0 * s * w
				w1 += c * rho * jac
				wq += c * (pow(rho, 0.156) if rho > 0.0 else 0.0) * jac
			assert_near(Pen.radius_integral(tip, s), w1 / (3.0 * n), 1e-3, 1e-12, "∫ρ %s" % s)
			assert_near(Pen.radius_power_integral(tip, s, 0.156), wq / (3.0 * n), 2e-3, 1e-12, "∫ρ^q %s" % s)


# ── Ensayos ──

func test_perforar_la_superficie_es_la_ley_de_sting() -> void:
	for zone: String in Zones.ids():
		for t: Dictionary in bench_tools():
			var r := punct(t, zone, 1.0)
			assert_eq(r.fPuncture, Sting.puncture_force(tool_of(t).area, Zones.stack(zone)), "%s en %s" % [t.label, zone])
			assert_eq(r.pierces, 1.0 >= r.fPuncture)
	assert_false(punct({ "claw": K("pajaro") }, "brazo", 1.5).pierces, "el pájaro no perfora con 1,5 N (la 1.x)")


func test_mas_fuerza_nunca_entra_menos() -> void:
	for zone: String in ["brazo", "palma", "abdomen"]:
		for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("gato") }, { "claw": K("oso") }, { "geom": G("stiletto") }]:
			var prev := -1.0
			for f in [0.5, 1.0, 2.0, 3.5, 6.0, 12.0, 30.0, 100.0, 400.0]:
				var d: float = punct(t, zone, f).depthUm
				assert_true(d >= prev - 1e-6, "%s en %s: %s N entra menos" % [t, zone, f])
				prev = d


func test_mas_roce_nunca_entra_mas() -> void:
	for zone: String in ["brazo", "cara", "abdomen"]:
		for t: Dictionary in [{ "claw": K("vibora") }, { "claw": K("gato") }, { "claw": K("lechuza") }]:
			for f in [3.5, 8.0, 20.0]:
				var d: Array = [0.0, 0.02, 0.05, 0.1].map(func(xi: float) -> float: return punct(t, zone, f, false, xi).depthUm)
				for i in range(1, d.size()):
					assert_true(d[i] <= d[i - 1] + 1e-6, "%s en %s a %s N: %s" % [t.claw.id, zone, f, d])


func test_nada_entra_mas_que_su_alcance() -> void:
	for zone: String in Zones.ids():
		for t: Dictionary in bench_tools():
			for strike in [false, true]:
				var tool := tool_of(t)
				var r := punct(t, zone, 2000.0, strike)
				assert_true(r.depthUm <= tool.reach * 1000.0 + 1e-6, "%s en %s: %s µm" % [t.label, zone, r.depthUm])
				if r.fullReach:
					assert_true(r.depthUm >= tool.reach * 1000.0 - 1e-6)


## El hueso detiene la queratina: con r = HV_punta/HV_hueso < 1,25 (la «marca tenue» de la 1.x) la punta no entra en la
## cortical, por mucha fuerza o energía que lleve; y ninguna garra de queratina atraviesa una cortical. El águila arpía
## (33 HV) contra el cigomático (40 HV) es el caso límite: r = 0,825.
func test_el_hueso_detiene_la_queratina() -> void:
	for zone: String in BONE_ZONES:
		var b: Dictionary = Zones.bone(zone)
		var claws: Array = Data.CLAWS.filter(func(c: Dictionary) -> bool: return not c.get("fang", false))
		for c: Dictionary in claws:
			for strike in [false, true]:
				# húmeda (×0,2 en dureza) solo con unas pocas: es la misma pared con más margen
				for wet in ([false, true] if c.id in ["arpia", "casuario"] else [false]):
					var t := { "claw": c, "wet": wet }
					var r := punct(t, zone, 2000.0, strike)
					var where := "%s%s en %s%s" % [c.id, " húmeda" if wet else "", zone, " (golpe)" if strike else ""]
					assert_false(r.bonePierced, "%s: atraviesa la cortical" % where)
					assert_true(tool_of(t).hv / b.hv < float(Pen.MODEL.boneMinRatio), "%s: la queratina marcaría el hueso" % where)
					assert_eq(r.boneIndentUm, 0.0, "%s: entra en el hueso" % where)
					assert_true(r.depthUm <= b.fromUm + 1e-6, "%s: pasa del hueso" % where)
					if r.boneHit:
						assert_true(r.stoppedBy == "hueso" or r.stoppedBy == "alcance", "%s: %s" % [where, r.stoppedBy])
	var harpy := punct({ "claw": K("arpia") }, "cara", 200.0, true)
	assert_eq(harpy.stoppedBy, "hueso", "la arpía topa con el pómulo")
	assert_eq(harpy.depthUm, Zones.bone_depth_um("cara"), "y se queda en su superficie")
	assert_eq(harpy.boneN, null, "contra una pared, en un golpe, la fuerza del hueso depende de la pata: null")


## La dentina de un colmillo (50 HV) no llega a 1,25 veces el húmero (47,25) ni los metacarpianos (43): solo el esmalte de la
## punta los marca, y en cuanto el contacto crece el hueso es una pared. Con el umbral en la mano, la resistencia del
## hueso pasa de finita a infinita donde tip_hv/HV_hueso cruza 1,25.
func test_la_dentina_no_entra_en_el_hueso() -> void:
	for zone: String in ["brazo", "palma", "dorsomano"]:
		var b: Dictionary = Zones.bone(zone)
		var tool := tool_of({ "claw": K("vibora") })
		assert_true(50.0 / b.hv < float(Pen.MODEL.boneMinRatio), "%s: la dentina marcaría el hueso" % zone)
		var rig := rig_of({ "claw": K("vibora") }, zone)
		var d0: float = b.fromUm / 1000.0
		# a 1 µm de hueso el esmalte todavía marca; a 0,5 mm la punta ya es dentina: pared
		assert_true(is_finite(float(Pen.parts(rig, d0 + 0.001).bone)), "%s: el esmalte de la punta entra" % zone)
		assert_eq(Pen.parts(rig, d0 + 0.5).bone, INF, "%s: la dentina no" % zone)
	# el cigomático (40 HV) es más blando: la dentina aún marca (r = 1,25 justo)
	var cara := rig_of({ "claw": K("vibora") }, "cara")
	assert_true(is_finite(float(Pen.parts(cara, Zones.bone_depth_um("cara") / 1000.0 + 0.5).bone)), "cara: la dentina marca el pómulo")


func test_una_punta_dura_si_entra_en_el_hueso() -> void:
	var r := punct({ "claw": K("casuario"), "inlay": I("tungsteno") }, "brazo", 500.0, true)
	assert_true(r.boneIndentUm > 1000.0, "una daga de tungsteno a 50 km/h entra en el húmero (%s µm)" % r.boneIndentUm)
	assert_true(r.bonePierced and r.layerId == "medula", "y atraviesa la cortical")
	assert_eq(r.stoppedBy, "energia", "pasada la cortical, la para la energía, no el hueso")
	var d := punct({ "claw": K("gato"), "inlay": I("diamante") }, "dorsomano", 200.0)
	assert_true(d.boneHit and d.boneIndentUm > 0.0, "un gato de diamante empujado con 200 N marca el metacarpiano")


## Un colmillo que golpea el hueso se rompe (30 N, Estrada 2026): el Gabón en el brazo, la víbora en la mano o la cara.
func test_los_colmillos_se_rompen_contra_el_hueso() -> void:
	for row in [["gabon", "brazo"], ["gabon", "cara"], ["vibora", "dorsomano"], ["vibora", "cara"], ["vibora", "palma"]]:
		var r := punct({ "claw": K(row[0]) }, row[1], K(row[0]).force, true)
		assert_true(r.toolBroken and r.boneHit, "%s en %s: %s" % [row[0], row[1], r.stoppedBy])
		assert_eq(r.stoppedBy, "rotura")
		assert_true(absf(r.depthUm - Zones.bone_depth_um(row[1])) < 500.0, "se rompe al llegar al hueso")
		assert_eq(r.toolLoadN, 30.0, "la carga en la punta, la de rotura")
	# en el abdomen no hay hueso: el colmillo entra entero y no se rompe
	var abd := punct({ "claw": K("gabon") }, "abdomen", 20.0, true)
	assert_false(abd.toolBroken)
	assert_true(abd.fullReach)
	assert_eq(abd.layerId, "cavidad", "el Gabón deja el veneno dentro de la cavidad abdominal")


func test_un_golpe_nunca_entra_menos_que_el_empuje() -> void:
	for zone: String in ["brazo", "dorsomano", "abdomen"]:
		for t: Dictionary in [{ "claw": K("gato") }, { "claw": K("vibora") }, { "claw": K("aguila") }, { "claw": K("casuario") }]:
			for f in [4.0, 30.0, 200.0]:
				var s := punct(t, zone, f)
				var k := punct(t, zone, f, true)
				assert_true(k.depthUm >= s.depthUm - 1e-3 or k.toolBroken, "%s en %s a %s N: golpe %s < empuje %s" % [t.claw.id, zone, f, k.depthUm, s.depthUm])


func test_energia_y_cargas_finitas() -> void:
	for zone: String in Zones.ids():
		for t: Dictionary in bench_tools():
			for strike in [false, true]:
				var r := punct(t, zone, 300.0, strike)
				var where := "%s en %s%s" % [t.label, zone, " (golpe)" if strike else ""]
				assert_true(is_finite(r.workJ) and r.workJ >= 0.0, "%s: workJ" % where)
				for k in ["crackN", "frictionN", "resN", "depthUm"]:
					assert_true(is_finite(float(r[k])) and float(r[k]) >= 0.0, "%s: %s=%s" % [where, k, r[k]])
				if r.boneN != null:
					assert_true(is_finite(float(r.boneN)) and float(r.boneN) >= 0.0, "%s: boneN" % where)
				if strike:
					assert_true(r.energyLeftJ != null and r.energyLeftJ >= 0.0, "%s: energía sobrante" % where)
				else:
					assert_eq(r.energyLeftJ, null)
				if r.pierces:
					assert_true(r.layerId is String, "%s: capa" % where)


## Casuario: en el brazo la patada se para en el húmero (la 1.x la dejaba en 110 mm de músculo); en el abdomen, sin hueso,
## entra entera en la cavidad.
func test_el_casuario_y_el_hueso() -> void:
	var arm := punct({ "claw": K("casuario") }, "brazo", 500.0, true)
	assert_eq(arm.stoppedBy, "hueso")
	assert_near(arm.depthUm, 41400.0, 1e-6, 1e-3, "hasta el húmero")
	assert_true(arm.energyLeftJ > 100.0, "casi toda la patada se la llevan el hueso y la pata")
	var abd := punct({ "claw": K("casuario") }, "abdomen", 500.0, true)
	assert_true(abd.fullReach and abd.layerId == "cavidad", "herida penetrante de abdomen")


## Rayar: el desgarro de la 1.x con las capas de la zona, hasta el hueso.
func test_el_desgarro_se_para_en_el_hueso() -> void:
	var gato := Pen.tear(3.0, "brazo", 10.0)
	assert_eq(gato.depthUm, Physics.skin_tear_depth(3.0) * 1000.0, "en el brazo, como la 1.x")
	var hand := Pen.tear(500.0, "dorsomano", 40.0)
	assert_eq(hand.depthUm, 5640.0, "en el dorso de la mano, el tigre topa con el metacarpiano")
	assert_true(hand.boneHit and not hand.fullReach)
	var abd := Pen.tear(500.0, "abdomen", 40.0)
	assert_true(abd.fullReach and not abd.boneHit, "en el abdomen, hasta el alcance")
	# más fuerza de desgarro nunca rasga menos, en ninguna zona
	for zone: String in Zones.ids():
		var prev := -1.0
		for ft in [0.1, 1.0, 5.0, 30.0, 100.0, 1000.0]:
			var d: float = Pen.tear(ft, zone, 60.0).depthUm
			assert_true(d >= prev, "%s: %s N" % [zone, ft])
			prev = d


# ── El informe de piel (skin_report), la referencia de la integración ──

## Al rayar en el brazo, el informe reproduce los campos de siempre de la 1.x (los arañazos del golden y alguno más)
## mientras el corte no llegue al húmero, que la 1.x no tiene: el oso que desgarra con 300 N se para en él.
func test_el_informe_de_rayado_en_el_brazo_es_la_1x() -> void:
	for over in [{ "geom": G("stiletto"), "force": 30.0 }, { "geom": G("cuadrada"), "force": 30.0 },
			{ "claw": K("gato"), "force": 15.0 }, { "claw": K("gato"), "force": 3.0 }, { "claw": K("pajaro"), "force": 1.5 },
			{ "force": 4.0 }, { "force": 30.0, "passes": 20.0 }, { "force": 30.0, "passes": 4.0 },
			{ "claw": K("gato"), "force": 15.0, "tear": true }, { "claw": K("tigre"), "force": 260.0 }, { "force": 0.5 }]:
		var p := params(over)
		var r1 := Physics.compute(p)
		for zone in [null, "brazo", "inventada"]:
			var rep := Pen.skin_report(q_of(p, r1, zone))
			var where := "%s en %s" % [JSON.stringify(over.keys()), zone]
			for k in ["depthUm", "layer", "bleeds", "fullReach", "ruptures"]:
				assert_eq(rep[k], r1[k], "%s: %s" % [where, k])
			assert_eq(rep.zone, "brazo", where)
	var bear := params({ "claw": K("oso"), "force": 300.0, "tear": true })
	var r_bear := Physics.compute(bear)
	assert_eq(r_bear.depthUm, 60000.0, "la 1.x: la garra entera (60 mm) en el músculo")
	var rep_bear := Pen.skin_report(q_of(bear, r_bear, "brazo"))
	assert_true(rep_bear.boneHit and rep_bear.depthUm == 41400.0 and not rep_bear.fullReach, "la 2.0: hasta el húmero")


## Por zonas: el callo de la palma, el hueso de la mano y la cavidad del abdomen, con los mismos datos de la 1.x.
func test_el_informe_de_rayado_por_zonas() -> void:
	var mimo := params({ "claw": K("gato"), "force": 3.0 })
	var palm := Pen.skin_report(q_of(mimo, Physics.compute(mimo), "palma"))
	assert_false(palm.bleeds, "el mimo del gato no sangra en la palma")
	assert_eq(palm.layerId, "cornea")
	var rub := params({ "force": 30.0, "passes": 20.0 })
	var r_rub := Physics.compute(rub)
	var p20 := Pen.skin_report(q_of(rub, r_rub, "palma"))
	assert_true(p20.excoriation and not p20.bleeds and p20.layerId == "cornea", "20 pasadas: aún en el callo")
	var rub150 := params({ "force": 30.0, "passes": 150.0 })
	var p150 := Pen.skin_report(q_of(rub150, Physics.compute(rub150), "palma"))
	assert_true(p150.bleeds and p150.excoriationBleeds, "150 pasadas: la palma también acaba sangrando")
	assert_eq(p150.depthUm, 265.0, "hasta el final de la epidermis de la palma")
	assert_eq(p150.layer, "Epidermis viva")
	var tiger := params({ "claw": K("tigre"), "force": 260.0 })
	var r_tiger := Physics.compute(tiger)
	var hand := Pen.skin_report(q_of(tiger, r_tiger, "dorsomano"))
	assert_true(hand.boneHit and hand.depthUm == 5640.0 and not hand.fullReach, "el tigre topa con el metacarpiano")
	var belly := Pen.skin_report(q_of(tiger, r_tiger, "abdomen"))
	assert_true(belly.fullReach and belly.layerId == "cavidad" and belly.layer == "Cavidad abdominal", "herida penetrante")
	assert_eq(belly.depthUm, r_tiger.depthUm, "toda la garra, como en el brazo")


## Al punzar, el informe es puncture() con el nombre de la capa (o del hueso) y el sangrado de la zona.
func test_el_informe_de_puncion() -> void:
	var gabon := params({ "claw": K("gabon"), "force": 30.0, "method": "puncion", "strike": true })
	var rg := Pen.skin_report(q_of(gabon, Physics.compute(gabon), "brazo"))
	assert_true(rg.toolBroken and rg.layerId == "hueso", "el Gabón se rompe contra el húmero")
	assert_eq(rg.layer, "Húmero")
	assert_true(rg.bleeds and rg.method == "puncion")
	var dagger := params({ "claw": K("casuario"), "inlay": I("tungsteno"), "force": 500.0, "method": "puncion", "strike": true })
	var rd := Pen.skin_report(q_of(dagger, Physics.compute(dagger), "brazo"))
	assert_true(rd.bonePierced and rd.layer == "Médula ósea", "la daga de tungsteno llega a la médula")
	var bird := params({ "claw": K("pajaro"), "force": 1.5, "method": "puncion" })
	var rb := Pen.skin_report(q_of(bird, Physics.compute(bird), "palma"))
	assert_true(not rb.pierces and rb.layer == null and not rb.bleeds, "el pájaro no perfora")
	for zone: String in Zones.ids():
		var viper := params({ "claw": K("vibora"), "force": 4.0, "method": "puncion" })
		var r := Pen.skin_report(q_of(viper, Physics.compute(viper), zone))
		var direct := punct({ "claw": K("vibora") }, zone, 4.0 + float(Physics.compute(viper).Fadh_mN) / 1000.0)
		for k in ["depthUm", "layerId", "stoppedBy", "crackN", "frictionN", "toolBroken"]:
			assert_eq(r[k], direct[k], "%s: %s" % [zone, k])
		assert_true(r.layer is String and r.bleeds, "%s: capa y sangrado" % zone)
