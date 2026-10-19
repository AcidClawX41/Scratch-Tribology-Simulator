## Pesar los polvos para la pieza de esta garra (unidad 5w; core/lab/claw_forge.gd mix_plan, mix_status y evaluate_mix con el
## plan; core/lab/claw_forge_state.gd la balanza). Invariantes:
##   - los gramos objetivo de los polvos suman el total que se pesa, y ese total es lo que pide la pieza (su volumen por la
##     densidad del material) con lo que se pesa de más; cada polvo, su fracción en peso de la receta;
##   - con la mezcla en tolerancia se puede cargar el crisol, y fuera de ella no (ni poca, ni mucha, ni fuera de la proporción);
##   - el arreglo que propone la balanza (echar o compensar) deja la mezcla en tolerancia; si no cabe, pide vaciar;
##   - una pieza más grande pide más gramos; el tutorial y la balanza dicen los mismos números, y lo recomendado es el objetivo.
extends "res://tests/case.gd"

const State = preload("res://core/lab/claw_forge_state.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

const CLAWS := [["rapaz", "aguila"], ["rapaz", "halcon"], ["tigre", "tigre"], ["oso", "oso"]]
const SHAPES := [0.2, 0.4, 0.7]


static func _forge(rid: String, animal := "rapaz", claw := "aguila", cover := 0.4) -> ClawForge:
	return ClawForge.new({ "animal": animal, "claw": claw, "recipe": rid, "cover_frac": cover })


func test_los_gramos_objetivo_suman_el_total_de_la_pieza() -> void:
	var extra := float(ForgeData.MIX_PLAN.extra.value)
	var over := float(ForgeData.MIX_PLAN.over.value)
	for rid: String in ForgeData.RECIPE_IDS:
		for c: Array in CLAWS:
			for cov: float in SHAPES:
				var f := _forge(rid, c[0], c[1], cov)
				var plan := f.mix_plan()
				var tag := "%s %s/%s %s" % [rid, c[0], c[1], str(cov)]
				assert_true(bool(plan.ok), "%s: hay plan" % tag)
				var sum := 0.0
				var aims := 0.0
				for p: Dictionary in plan.powders:
					sum += float(p.targetG)
					aims += float(p.aim)
					assert_near(float(p.targetG), float(p.aim) * float(plan.targetG), 1e-12, 1e-12, "%s/%s: su fracción en peso del total" % [tag, String(p.id)])
					# 5w · la de la receta o, si está en el borde de su margen, un poco por dentro (nunca fuera de él)
					var band := float(p.fracMax) - float(p.fracMin)
					assert_true(float(p.aim) >= float(p.fracMin) - 1e-12 and float(p.aim) <= float(p.fracMax) + 1e-12, "%s/%s: dentro del margen de la receta" % [tag, String(p.id)])
					assert_true(absf(float(p.aim) - float(p.frac)) <= float(ForgeData.MIX_PLAN.inner.value) * band + 1e-12, "%s/%s: cerca de la de la receta" % [tag, String(p.id)])
					assert_true(float(p.minG) <= float(p.targetG) + 1e-12 and float(p.targetG) <= float(p.maxG) + 1e-12, "%s/%s: el objetivo, dentro de lo que vale" % [tag, String(p.id)])
				assert_near(sum, float(plan.targetG), 1e-12, 1e-12, "%s: los gramos objetivo suman el total que se pesa" % tag)
				assert_near(aims, 1.0, 1e-12, 1e-12, "%s: las proporciones que se pesan suman el 100 %%" % tag)
				assert_near(float(plan.targetG), float(plan.needG) * (1.0 + extra), 1e-12, 1e-12, "%s: lo que pide la pieza y lo que se pesa de más" % tag)
				assert_near(float(plan.maxG), float(plan.needG) * (1.0 + over), 1e-12, 1e-12, "%s: lo que se admite" % tag)
				assert_near(float(plan.productG), float(plan.densityKgM3) * float(plan.volumeMm3) * 1.0e-6, 1e-12, 1e-12, "%s: volumen por densidad" % tag)
				assert_eq(float(plan.densityKgM3), float(ForgeData.density_of(String(ForgeData.RECIPES[rid].product))), "%s: la densidad del material, con su fuente" % tag)
				assert_true(String(plan.source) != "" and String(plan.quality) != "", "%s: con fuente y calidad" % tag)
				# el volumen, el de lo que se hace: el cilindro del cristal, la funda o la cera con su bebedero
				var sh: Dictionary = f.snapshot().sheath
				match String(ForgeData.RECIPES[rid].form):
					"bola", "cristal":
						assert_near(float(plan.volumeMm3), float(sh.rawVolumeMm3), 1e-9, 0.0, "%s: el cilindro del que se talla" % tag)
					"sinterizada", "capa":
						assert_near(float(plan.volumeMm3), float(sh.volumeMm3), 1e-9, 0.0, "%s: la funda" % tag)
					"colada":
						assert_true(float(plan.volumeMm3) > float(sh.volumeMm3), "%s: la cera con su bebedero, más que la funda" % tag)
				if rid == "diamante_hpht":
					assert_near(float(plan.needG) * 0.3, float(plan.productG), 1e-12, 1e-12, "%s: el grafito es el carbono del cristal" % tag)
				else:
					assert_near(float(plan.needG), float(plan.productG), 1e-12, 1e-12, "%s: la carga es la pieza" % tag)


func test_la_proporcion_en_el_borde_se_pesa_por_dentro() -> void:
	# el 0,25 % de MgO de la alúmina es el mínimo de la receta: con lo que no distingue la balanza, apuntar a él dejaba la mezcla
	# fuera; se pesa un 10 % del margen por dentro, y la balanza lo dice
	var plan := _forge("alumina").mix_plan()
	var mgo: Dictionary = plan.powders[1]
	assert_eq(String(mgo.id), "mgo", "el segundo polvo de la alúmina, el MgO")
	assert_near(float(mgo.aim), 0.00275, 1e-12, 1e-12, "se pesa para el 0,275 % (del 0,25 % al 0,5 %)")
	assert_true(String(plan.note).contains("borde de su margen") and String(plan.note).contains("juego"), "y lo dice, como juego: %s" % String(plan.note))
	assert_true(ClawForge.plan_sentence(plan).contains(String(plan.note)), "en la frase de la balanza y del tutorial")
	# las demás recetas pesan su proporción de siempre
	for rid: String in ["rubi", "metal_duro", "diamante_hpht"]:
		for p: Dictionary in _forge(rid).mix_plan().powders:
			assert_near(float(p.aim), float(p.frac), 1e-12, 1e-12, "%s/%s: la de la receta" % [rid, String(p.id)])


func test_una_pieza_mas_grande_pide_mas_gramos() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var prev := 0.0
		for cov: float in SHAPES:
			var g := float(_forge(rid, "rapaz", "aguila", cov).mix_plan().targetG)
			assert_true(g > prev, "%s: con más funda (%s), más gramos (%s g)" % [rid, str(cov), str(g)])
			prev = g
		assert_true(float(_forge(rid, "oso", "oso").mix_plan().targetG) > float(_forge(rid, "rapaz", "lechuza").mix_plan().targetG), "%s: la garra del oso pide más que la de la lechuza" % rid)


func test_la_colada_pide_lo_que_llena_la_cera() -> void:
	for rid: String in ["acero", "oro", "titanio", "vidrio"]:
		var f := _forge(rid)
		var before := float(f.mix_plan().needG)
		var w := f.wax({ "compensate": true, "mold": String(ForgeData.RECIPES[rid].mold.value) })
		assert_near(float(f.mix_plan().needG), float(w.metalG), 1e-12, 1e-12, "%s: lo que pide la pieza es lo que llena la cera con su bebedero" % rid)
		assert_near(before, float(w.metalG), 1e-12, 1e-12, "%s: y antes de la cera, el mismo (la cera a la medida y el molde de la receta)" % rid)


func test_en_tolerancia_se_carga_y_fuera_no() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := State.new({ "animal": "rapaz", "claw": "aguila" })
		st.set_process(rid)
		var plan := st.forge.mix_plan()
		var target := {}
		for p: Dictionary in plan.powders:
			target[String(p.id)] = float(p.targetG)
		# en tolerancia: lo de la receta, lo justo y lo máximo
		for k: float in [1.0, float(plan.minG) / float(plan.targetG), float(plan.maxG) / float(plan.targetG) * (1.0 - 1e-9)]:
			var g := {}
			for id: String in target:
				g[id] = float(target[id]) * k
			assert_true(bool(st.forge.mix_status(g).ok), "%s ×%s: en tolerancia" % [rid, str(k)])
			assert_true(bool(ClawForge.evaluate_mix(ForgeData.recipe(rid), g, plan).ok), "%s ×%s: el motor la acepta" % [rid, str(k)])
		# fuera: poca, mucha y, con varios polvos, uno que se pasa
		var bad: Array = []
		var low := {}
		var high := {}
		for id: String in target:
			low[id] = float(target[id]) * float(plan.minG) / float(plan.targetG) * 0.97
			high[id] = float(target[id]) * float(plan.maxG) / float(plan.targetG) * 1.03
		bad.append(["poca", low])
		bad.append(["mucha", high])
		if target.size() > 1:
			var skew := target.duplicate()
			var last := String(plan.powders[plan.powders.size() - 1].id)
			skew[last] = float(plan.powders[plan.powders.size() - 1].maxG) * 1.6 + 1e-4
			bad.append(["un polvo que se pasa", skew])
		for b: Array in bad:
			st.clear_pan()
			for id: String in b[1]:
				st.add_powder(id, float(b[1][id]))
			var n := st.calls.size()
			st.load_crucible()
			assert_eq(st.calls.size(), n, "%s, %s: no se carga el crisol" % [rid, b[0]])
			assert_true(st.loaded.is_empty(), "%s, %s: el crisol sigue vacío" % [rid, b[0]])
			assert_true(st.notice.begins_with("No se carga."), "%s, %s: y lo dice: %s" % [rid, b[0], st.notice])
			assert_false(bool(st.bench_view().ready), "%s, %s: la balanza no dice «Listo»" % [rid, b[0]])
		# en tolerancia, sí
		st.clear_pan()
		for id: String in target:
			st.add_powder(id, float(target[id]))
		assert_eq(String(st.bench_view().status_text), "Listo: carga el crisol (L).", "%s: con los objetivos, «Listo»" % rid)
		st.load_crucible()
		assert_eq(String(st.calls[-1][0]), "mix", "%s: y se carga" % rid)
		assert_true(bool(st.snap().mix.ok), "%s: con la mezcla buena" % rid)


func test_el_arreglo_deja_la_mezcla_en_tolerancia() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var f := _forge(rid)
		var plan := f.mix_plan()
		var cases: Array = []
		# un solo polvo, la mitad de su objetivo
		var half := { String(plan.powders[0].id): float(plan.powders[0].targetG) * 0.5 }
		cases.append(half)
		# todos, pero cortos
		var short := {}
		for p: Dictionary in plan.powders:
			short[String(p.id)] = float(p.targetG) * 0.8
		cases.append(short)
		# el último se pasa un poco de su margen (con varios polvos): se compensa con los otros
		if (plan.powders as Array).size() > 1:
			var skew := {}
			for p: Dictionary in plan.powders:
				skew[String(p.id)] = float(p.targetG)
			var lp: Dictionary = plan.powders[plan.powders.size() - 1]
			skew[String(lp.id)] = float(lp.maxG) * 1.05
			cases.append(skew)
		for g: Dictionary in cases:
			var ms := f.mix_status(g)
			assert_false(bool(ms.ok), "%s %s: fuera de tolerancia" % [rid, var_to_str(g)])
			var fix: Dictionary = ms.fix
			if String(fix.kind) in ["echar", "compensar"]:
				var g2 := g.duplicate()
				for k: String in fix.add:
					g2[k] = float(g2.get(k, 0.0)) + float(fix.add[k])
				assert_true(bool(f.mix_status(g2).ok), "%s %s: lo que dice que eche (%s) la deja en tolerancia" % [rid, var_to_str(g), var_to_str(fix.add)])
				assert_true(String(fix.text).contains("echa"), "%s: y lo dice: %s" % [rid, String(fix.text)])
			else:
				assert_true(String(fix.kind) == "vaciar", "%s %s: si no se puede compensar, vaciar (%s)" % [rid, var_to_str(g), String(fix.kind)])
	# solo una parte del carburo y nada de cobalto: no sobra nada, faltan los dos (antes decía «sobra carburo»)
	var mw := _forge("metal_duro")
	var fw: Dictionary = mw.mix_status({ "wc": float(mw.mix_plan().powders[0].targetG) * 0.3 }).fix
	assert_eq(String(fw.kind), "echar", "con poco carburo y sin cobalto, echar")
	assert_true(String(fw.text).begins_with("Falta: echa") and String(fw.text).contains("Co"), "y dice cuánto de cada uno: %s" % String(fw.text))
	# el metal duro con el cobalto pasado del todo: no cabe compensarlo, hay que vaciar
	var md := _forge("metal_duro")
	var mp := md.mix_plan()
	var g3 := { "wc": float(mp.powders[0].targetG) * 0.7, "co": float(mp.powders[1].targetG) * 2.5 }
	var fx: Dictionary = md.mix_status(g3).fix
	assert_eq(String(fx.kind), "vaciar", "el cobalto al 250 %%: compensarlo no cabe")
	assert_true(String(fx.text).contains("vacía el plato"), "y lo dice: %s" % String(fx.text))
	assert_true(String(fx.text).begins_with("Te has pasado de cobalto"), "y de qué se ha pasado: %s" % String(fx.text))
	# con un solo polvo que se pasa, se quita con la espátula
	var zf := _forge("zafiro")
	var zp := zf.mix_plan()
	var fz: Dictionary = zf.mix_status({ "al2o3": float(zp.maxG) * 1.5 }).fix
	assert_eq(String(fz.kind), "quitar", "un solo polvo que se pasa: se quita")
	assert_near(float(fz.take.al2o3), float(zp.maxG) * 1.5 - float(zp.targetG), 1e-12, 1e-12, "lo que sobra sobre el objetivo")


func test_lo_recomendado_es_el_objetivo_y_la_balanza_dice_lo_mismo_que_el_tutorial() -> void:
	for rid: String in ForgeData.RECIPE_IDS:
		var st := State.new({ "animal": "rapaz", "claw": "aguila" })
		st.set_process(rid)
		var plan := st.forge.mix_plan()
		var rec: Dictionary = st.forge.recommended().mix
		for p: Dictionary in plan.powders:
			assert_near(float(rec[String(p.id)]), float(p.targetG), 1e-12, 1e-12, "%s/%s: lo recomendado, su objetivo" % [rid, String(p.id)])
		var pesar: Dictionary = st.forge.tutorial(rid).filter(func(s: Dictionary) -> bool: return String(s.id) == "pesar")[0]
		var bv := st.bench_view()
		for j: Dictionary in bv.jars:
			if float(j.target_g) > 0.0:
				assert_true(String(pesar.detail).contains(String(j.formula) + " " + String(j.target_text)), "%s: el tutorial y la balanza, el mismo objetivo de %s (%s)" % [rid, String(j.id), String(j.target_text)])
				assert_true(String(j.line).begins_with("Llevas "), "%s/%s: lo que lleva" % [rid, String(j.id)])
				assert_true(String(j.line).contains("faltan " + String(j.target_text)), "%s/%s: y lo que falta, con el plato vacío todo" % [rid, String(j.id)])
		assert_true(String(bv.plan_text).contains(ClawForge.fmt_mass(float(plan.needG), float(plan.targetG))), "%s: la balanza dice lo que pide la pieza" % rid)
		var pt := String(bv.plan_text)
		assert_eq(String(pesar.detail), "Para esta pieza: " + pt.substr(0, 1).to_lower() + pt.substr(1), "%s: con la misma frase que el tutorial" % rid)
		assert_true(String(pesar.text).contains(String(pesar.detail)), "%s: y el paso la lleva en su texto" % rid)
		assert_eq((bv.hud as Array).size(), (plan.powders as Array).size(), "%s: junto a la balanza, una línea por polvo" % rid)


func test_la_balanza_va_con_el_objetivo() -> void:
	# las dosis de cada polvo van con su objetivo y nunca bajan de lo que distingue la balanza
	var st := State.new({ "animal": "rapaz", "claw": "aguila" })
	st.set_process("alumina")
	var rd := float(ForgeData.MIX_PLAN.readability_g.value)
	for p: Dictionary in st.forge.mix_plan().powders:
		var ds: Array = st.doses_for(String(p.id))
		assert_true(float(ds[0]) <= float(p.targetG) + 1e-12, "%s: la dosis grande cabe en el objetivo" % String(p.id))
		assert_true(float(ds[0]) * 10.0 > float(p.targetG), "%s: y es la potencia de diez que cabe" % String(p.id))
		for d: float in ds:
			assert_true(d >= rd - 1e-15, "%s: ninguna dosis por debajo de 0,1 mg" % String(p.id))
	# los miligramos de MgO de una funda se pueden pesar: su margen es mayor que la dosis más fina
	var mgo: Dictionary = st.forge.mix_plan().powders[1]
	assert_true(float(mgo.maxG) - float(mgo.minG) > float(st.doses_for("mgo")[2]) * 5.0, "el margen del MgO, más que cinco dosis finas")
	assert_true(st.scale_text().ends_with(" g") and st.scale_text().contains(".0000"), "la pantalla, con cuatro decimales")
	# vertiendo con el tarro unos dos segundos, el objetivo
	st.pick_jar("al2o3")
	st.set_pouring(true)
	for i in 60:
		st.tick(1.0 / 30.0)
	st.set_pouring(false)
	assert_near(float(st.pan.al2o3), float(st.forge.mix_plan().powders[0].targetG), 1e-6, 1e-6, "dos segundos de chorro, su objetivo")
