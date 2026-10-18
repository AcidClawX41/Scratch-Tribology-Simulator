## Interfaz del laboratorio (app/lab): la sección se construye sin ventana y los ensayos se hacen como los haría
## alguien: pulsando fichas, píldoras y selectores, moviendo deslizadores, pulsando ARAÑAR y dejando correr el reloj.
## Lo que MUESTRA la interfaz (veredicto, color, subtítulo, métricas, etiquetas, corte, cuaderno, sonido y modo dual)
## tiene que ser exactamente lo que da el core con esos parámetros: Physics.compute(), Lab.duel(),
## Lab.damage_report(), Lab.tool_label() y Sfx.sfx_for_result(). La interfaz no calcula física.
extends "res://tests/case.gd"

const LabSection = preload("res://app/lab/lab_section.tscn")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const ResultCard = preload("res://app/lab/result_card.gd")
const BenchTexts = preload("res://core/lab/bench_texts.gd")

## Ensayos: herramienta, material y parámetros (force: "max" = el botón de fuerza máxima; un número = el deslizador).
const TRIALS := [
	{ "name": "uña almendra natural contra vidrio", "geom": "almendra", "base": "natural", "target": "vidrio", "force": 4.0 },
	{ "name": "uña natural, fuerza MÁX. humana, contra vidrio", "geom": "almendra", "base": "natural", "target": "vidrio", "force": "max" },
	{ "name": "uña de diamante contra zafiro", "geom": "stiletto", "base": "diamante", "target": "zafiro", "force": "max" },
	{ "name": "uña cuadrada de acero contra madera", "geom": "cuadrada", "base": "metal", "target": "madera", "force": 20.0 },
	{ "name": "gel con zafiro contra la pantalla", "geom": "redonda", "base": "gel", "inlay": "zafiro", "target": "movil", "force": "max" },
	{ "name": "uña mojada contra una uña", "geom": "coffin", "base": "natural", "wet": true, "target": "una", "force": 4.0 },
	{ "name": "stiletto XL de acrílico con tungsteno contra acero", "geom": "stilettoxl", "base": "acrilico", "inlay": "tungsteno", "target": "acero", "force": 3.2 },
	{ "name": "surco profundo en la piel, 5 pasadas", "geom": "almendra", "base": "natural", "target": "piel", "force": 20.0, "type": "surco", "passes": 5 },
	{ "name": "uña contra coche moderno, 40 mm", "geom": "almendra", "base": "natural", "target": "coche", "force": "max", "length": 40.0 },
	{ "name": "uña punzando la puerta de madera", "geom": "stiletto", "base": "natural", "target": "puertamadera", "force": "max", "method": "puncion" },
	{ "name": "stiletto de titanio contra cobre", "geom": "stiletto", "base": "titanio", "target": "cobre", "force": 20.0 },
	{ "name": "zafiro macizo contra cuarzo, 20 pasadas, roce", "geom": "cuadrada", "base": "zafiro", "target": "cuarzo", "force": "max", "passes": 20, "type": "roce" },
	{ "name": "garra de tigre contra coche moderno", "claw": "tigre", "target": "coche", "force": "max" },
	{ "name": "garra de tigre desgarrando el coche moderno", "claw": "tigre", "target": "coche", "force": "max", "tear": true },
	{ "name": "colmillo de víbora punzando piel", "claw": "vibora", "target": "piel", "force": "max", "method": "puncion" },
	{ "name": "casuario con golpe contra piel", "claw": "casuario", "target": "piel", "force": "max", "method": "puncion", "strike": true },
	{ "name": "oso con golpe contra el vidrio", "claw": "oso", "target": "vidrio", "force": "max", "method": "puncion", "strike": true },
	{ "name": "águila con golpe contra la puerta de aluminio", "claw": "aguila", "target": "puertametal", "force": "max", "method": "puncion", "strike": true },
	{ "name": "gato arañando piel", "claw": "gato", "target": "piel", "force": 4.0 },
	{ "name": "colmillo de Gabón de zafiro punzando piel", "claw": "gabon", "inlay": "zafiro", "target": "piel", "force": 20.0, "method": "puncion" },
	{ "name": "halcón en picado contra el vidrio", "claw": "halcon", "target": "vidrio", "force": "max", "method": "puncion", "strike": true },
	{ "name": "casuario contra la puerta de roble", "claw": "casuario", "target": "puertamadera", "force": "max", "method": "puncion", "strike": true },
	{ "name": "emú contra la aleta de plástico", "claw": "emu", "target": "cocheplastico", "force": "max" },
	{ "name": "buitre punzando el coche de aluminio", "claw": "buitre", "target": "cochealu", "force": "max", "method": "puncion" },
	{ "name": "lechuza contra el diamante", "claw": "lechuza", "target": "diamante", "force": "max" },
	{ "name": "avestruz con golpe contra el coche clásico", "claw": "avestruz", "target": "cocheclasico", "force": "max", "method": "puncion", "strike": true },
	{ "name": "garra de oso de acero desgarrando piel", "claw": "oso", "inlay": "acero", "target": "piel", "force": 60.0, "tear": true },
]

var s: Control


func before_each() -> void:
	if s == null:
		s = LabSection.instantiate()
		s.setup()
		s.art.threaded = false


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Pulsa un control visible de la interfaz (como un clic) y deja que la sección se ponga al día.
func _click(b: BaseButton) -> void:
	var n: Node = b
	while n != null and n != s:
		if n is CanvasItem and not (n as CanvasItem).visible:
			fail("se ha pulsado un control oculto (%s, dentro de %s)" % [b.name, n.name])
			return
		n = n.get_parent()
	b.pressed.emit()
	s.step(0.0)


## Mueve un deslizador: Range ajusta el valor a su paso y avisa (fuera del árbol Range no emite value_changed, así que
## se emite aquí con el valor ya ajustado, como lo haría el motor).
func _slide(r: Range, v: float) -> void:
	var before := r.value
	r.value = v
	if r.value != before:
		r.value_changed.emit(r.value)
	s.step(0.0)


## Elige un ensayo con los controles y devuelve los parámetros que esperamos que use (los de compute()).
func _select(c: Dictionary) -> Dictionary:
	var tc: Control = s.tool_card
	var pc: Control = s.params_card
	var lab: LabState = s.lab
	if lab.wet:
		_click(tc.wet_seg.buttons["seca"])
	var claw: Variant = null
	if c.has("claw"):
		_click(tc.kind_seg.buttons["garras"])
		_click(tc.claw_tiles[c.claw])
		claw = Catalog.find_by_id(Catalog.CLAWS, c.claw)
	else:
		_click(tc.kind_seg.buttons["unas"])
		_click(tc.geom_tiles[c.geom])
		_click(tc.base_pills[c.base])
	_click(tc.inlay_pills[c.get("inlay", "none")])
	if c.get("wet", false):
		_click(tc.wet_seg.buttons["humeda"])
	_click(s.target_card.tiles[c.target])
	var method: String = c.get("method", "rayado")
	_click(pc.method_seg.buttons[method])
	if method == "puncion":
		_click(pc.strike_seg.buttons["impacto" if c.get("strike", false) else "estatico"])
	else:
		_slide(pc.length.slider, c.get("length", 25.0))
		_click(pc.pass_pills[int(c.get("passes", 1))])
		_click(pc.type_seg.buttons[c.get("type", "aranazo")])
		if claw != null:
			_click(pc.tear_seg.buttons["desgarro" if c.get("tear", false) else "arrastre"])
	var force: float
	if c.force is String:
		_click(pc.max_button)
		force = claw.force if claw != null else Catalog.HUMAN.force
	else:
		# el deslizador va a saltos de 0,004 en escala log y redondea: la fuerza queda cerca de la pedida
		_slide(pc.force.slider, Format.f_to_t(c.force))
		force = lab.force
		assert_true(absf(force - c.force) <= 0.02 * c.force, "%s: el deslizador deja %s N (se pedían %s)" % [c.get("name", ""), force, c.force])
	return {
		"geom": lab.geom if claw != null else Catalog.find_by_id(Catalog.GEOMS, c.geom),
		"base": lab.base if claw != null else Catalog.find_by_id(Catalog.BASES, c.base),
		"inlay": Catalog.find_by_id(Catalog.INLAYS, c.get("inlay", "none")), "target": T(c.target), "force": force,
		"length": c.get("length", 25.0), "type": Catalog.find_by_id(Catalog.TYPES, c.get("type", "aranazo")), "claw": claw,
		"tear": c.get("tear", false), "method": method, "strike": c.get("strike", false), "passes": float(c.get("passes", 1)),
		"wet": c.get("wet", false),
	}


## Lo que enseñan las métricas: etiqueta → [texto, color].
func _metrics() -> Dictionary:
	var out := {}
	for m in s.result_card.metrics:
		if m.visible:
			out[m.key] = [m.value.text, m.value.get_theme_color("font_color")]
	return out


func _check_metric(shown: Dictionary, key: String, text: String, name: String, color: Variant = null) -> void:
	assert_true(shown.has(key), "%s: falta la métrica «%s»" % [name, key])
	if not shown.has(key):
		return
	assert_eq(shown[key][0], text, "%s: «%s»" % [name, key])
	if color != null:
		assert_eq(shown[key][1], color, "%s: color de «%s»" % [name, key])


func test_ensayos_por_la_interfaz_iguales_que_compute() -> void:
	var total_ms := 0.0
	var refresh_ms := 0.0
	for c: Dictionary in TRIALS:
		var name: String = c.name
		var p := _select(c)
		assert_eq(s.lab.force, p.force, "%s: fuerza que deja la interfaz" % name)
		assert_eq(s.params_card.force.display.text, "%s N" % Format.fmt_f(p.force), "%s: fuerza en pantalla" % name)
		var t0 := Time.get_ticks_usec()
		_click(s.run_button)
		assert_eq(s.lab.phase, "running", "%s: ARAÑAR lanza el ensayo" % name)
		assert_true(s.run_button.disabled, "%s: mientras se ensaya, ARAÑAR no se puede pulsar" % name)
		s.step(LabState.RUN_MS + 50.0)
		total_ms += (Time.get_ticks_usec() - t0) / 1000.0
		refresh_ms += s.last_refresh_ms
		var res := Physics.compute(p)
		var d := oracle_diff(s.lab.res, res)
		assert_eq(d.size(), 0, "%s: la interfaz pasa al banco los parámetros elegidos %s" % [name, d])
		var rc: ResultCard = s.result_card
		assert_true(rc.details.visible and not rc.hint.visible, "%s: al terminar se ve el resultado" % name)
		assert_eq(rc.verdict.text, res.verdict, "%s: veredicto" % name)
		var vcol := Palette.color(res.vcol)
		assert_eq(rc.verdict.get_theme_color("font_color"), vcol, "%s: color del veredicto" % name)
		assert_eq(rc.vsub.text, res.vsub, "%s: subtítulo" % name)
		assert_eq(rc.tag_tear.visible, Js.truthy(res.get("tearing")), "%s: etiqueta DESGARRO" % name)
		assert_eq(rc.tag_wet.visible, Js.truthy(res.get("wet")), "%s: etiqueta HÚMEDA" % name)
		var skin := Js.truthy(res.get("skin"))
		var puncture := Js.truthy(res.get("puncture"))
		var shown := _metrics()
		# la real con su tope y la nominal F/A, que por encima de la dureza no tiene sentido (BenchTexts, 4n); con un contacto
		# elástico, la media F/A y el pico de Hertz, con su frase (4p)
		for row: Array in BenchTexts.pressure_rows(res):
			_check_metric(shown, row[0], row[2], name)
		if res.get("p0MPa") != null:
			_check_metric(shown, "Presión media", "%s MPa" % Format.fmt_p(res.pressure), name)
			_check_metric(shown, "Pico de Hertz", "%s MPa" % Format.fmt_p(res.p0MPa), name)
			assert_true(rc.hertz_note.visible and rc.hertz_note.text == BenchTexts.hertz_note(res), "%s: la frase del pico" % name)
		else:
			assert_false(rc.hertz_note.visible, "%s: sin contacto elástico, sin la frase del pico" % name)
			_check_metric(shown, "Presión real", "%s MPa" % Format.fmt_p(res.pressure), name)
			if res.pressure >= res.pNominal:
				_check_metric(shown, "Presión nominal", "%s MPa" % Format.fmt_p(res.pNominal), name)
		var depth_key := "Profundidad punción" if puncture else ("Profundidad herida" if skin else "Profundidad surco")
		var depth_txt := "sin herida" if skin and res.depthUm <= 0.0 else "≈ %s%s" % [Format.fmt_depth(res.depthUm), " (tope)" if Js.truthy(res.get("fullReach")) else ""]
		_check_metric(shown, depth_key, depth_txt, name, vcol)
		if skin:
			_check_metric(shown, "Fuerza para perforar" if puncture else "Fuerza para romper la piel", "≈ %s N" % Format.fmt_f(res.fPuncture), name)
			_check_metric(shown, "Sangra", "sí" if Js.truthy(res.get("bleeds")) else "no", name)
		else:
			_check_metric(shown, "Ratio dureza", "%s×" % Js.to_fixed(res.ratio, 2), name)
			_check_metric(shown, "Contacto plástico", "%s %%" % Js.to_fixed(res.phi * 100.0, 0), name)
		if Js.truthy(res.get("absMode")):
			_check_metric(shown, "Modo abrasión", ResultCard.ABS[res.absMode][0], name, Palette.color(ResultCard.ABS[res.absMode][1]))
		if res.get("paneN") != null:
			_check_metric(shown, "La hoja se parte con", "≈ %s N" % Format.fmt_f(res.paneN), name)
		_check_metric(shown, "Adhesión vdW", "%s mN" % Js.to_fixed(res.Fadh_mN, 2), name)
		_check_metric(shown, "Desgaste Archard", "%s u.a." % Js.template_str(res.wearIdx), name)
		_check_metric(shown, "Qué cede", String(res.cede), name)
		if puncture:
			assert_false(shown.has("Longitud"), "%s: en una punción no hay longitud" % name)
		else:
			_check_metric(shown, "Longitud", "%s mm" % Js.js_num_str(p.length), name)
		# corte: piel, coche, puerta o perfil de la huella
		var key: String = rc.section_view.key
		var kind := "sks:" if skin else ("cars:" if Js.truthy(res.get("paint")) else ("door:" if Js.truthy(res.get("woodDoor")) else "xs:"))
		assert_true(key.begins_with(kind), "%s: corte %s (se pinta %s)" % [name, kind, key])
		assert_eq(rc.skin_table.visible, skin, "%s: tabla de la piel" % name)
		# el banco pinta este resultado y el cuaderno lo apunta
		assert_eq(rc.bench.res, s.lab.res, "%s: el banco pinta el resultado del ensayo" % name)
		assert_eq(rc.bench.phase, "done")
		var entry: Array = s.badges_card.book_rows[0]
		var label := Lab.tool_label({ "claw": p.claw, "geom": p.geom, "inlay": p.inlay, "res": res })
		assert_eq(entry[2].text, "%s → %s" % [label, p.target.name], "%s: cuaderno" % name)
		assert_eq(entry[3].text, res.verdict, "%s: veredicto del cuaderno" % name)
		# el sonido del resultado (el rayado, al momento; la punción, al impactar): el que elige la sección, el de la 2.0
		# (SfxInsects.sfx_for_result: el de la 1.x salvo los aguijones y los materiales de la 2.0, como la uña que se dobla)
		var want := SfxInsects.sfx_for_result(res, p.target)
		var ids: Array = s.sound.played.map(func(x: Array) -> String: return x[0])
		assert_true(ids.has(want), "%s: suena «%s» (sonaron %s)" % [name, want, ids.slice(-4)])
	print("    (info) %d ensayos por la interfaz: %.1f ms de media por ensayo (clics, ensayo, animación y refresco; refresco final %.1f ms)" % [
		TRIALS.size(), total_ms / TRIALS.size(), refresh_ms / TRIALS.size()])


func test_modo_dual_muestra_los_dos_coches_con_lab_duel() -> void:
	var p := _select({ "claw": "casuario", "target": "coche", "force": "max", "method": "puncion", "strike": true })
	var dc: Control = s.dual_card
	assert_false(dc.on_box.visible, "el modo dual empieza apagado")
	_click(dc.toggle)
	assert_true(s.lab.dual and dc.on_box.visible, "Activar enciende el modo dual")
	for pass_i in 2:
		_click(s.run_button)
		s.step(LabState.RUN_MS + 50.0)
		var cars: Array = s.lab.dual_cars()
		var rows := Lab.duel(s.lab.params(), s.lab.claw, cars)
		var current: Dictionary = {}
		for r: Dictionary in rows:
			if r.p.method == "puncion" and r.p.strike:
				current = r
		assert_eq(current.id, "golpe", "el ensayo del banco es el golpe")
		for i in 2:
			var res: Dictionary = current.res[i]
			assert_eq(dc.benches[i].target.id, cars[i].id, "banco %d: coche" % i)
			assert_eq(oracle_diff(dc.benches[i].res, res).size(), 0, "banco %d: resultado de Lab.duel" % i)
			assert_eq(dc.car_verdict[i].text, res.verdict, "coche %d: veredicto" % i)
			assert_eq(dc.car_verdict[i].get_theme_color("font_color"), Palette.color(res.vcol), "coche %d: color" % i)
			assert_eq(dc.car_vsub[i].text, res.vsub, "coche %d: subtítulo" % i)
			var report := Lab.damage_report(res, cars[i], s.lab.length)
			var shown: Array = []
			for l: Label in dc.car_damage[i].get_children():
				if l.visible:
					shown.append(l.text)
			var want: Array = []
			for pair: Array in report:
				want.append_array(pair)
			assert_eq(shown, want, "coche %d: informe de daños" % i)
		assert_eq(dc.head_names[0].text, cars[0].name)
		assert_eq(dc.head_names[1].text, cars[1].name)
		for k in rows.size():
			var row: Dictionary = dc.rows[k]
			var is_cur: bool = rows[k].id == "golpe"
			assert_eq(row.name.text, String(rows[k].name) + (" ◂" if is_cur else ""), "fila %s" % rows[k].id)
			assert_eq(row.cells[0][0].text, rows[k].res[0].verdict)
			assert_eq(row.cells[1][0].text, rows[k].res[1].verdict)
			assert_eq(row.who.text, Lab.duel_verdict(rows[k].res[0], rows[k].res[1], cars).text)
		if pass_i == 0:
			assert_eq(cars[0].id, "cocheclasico", "pareja por defecto: clásico…")
			assert_eq(cars[1].id, "coche", "… frente a moderno")
			_click(dc.car_pills[1]["cochealu"])
			assert_eq(s.lab.phase, "idle", "cambiar un coche resetea el banco")
	_click(dc.toggle)
	assert_false(s.lab.dual, "Desactivar")
	assert_true(p.claw != null)


func test_comparativa_con_compute_y_orden_estable() -> void:
	_select({ "claw": "gato", "target": "piel", "force": 4.0 })
	s.refresh_now()
	var cc: Control = s.compare_card
	assert_eq(cc.title_label.text, "Comparar garras y colmillos")
	var claws_1x := Catalog.CLAWS.filter(func(c: Dictionary) -> bool: return not Insects.is_stinger(c))
	assert_eq(claws_1x.size(), 19, "las 17 garras y colmillos de la 1.x y los dos velocirraptores de la 2.0 (unidades 4i y 4i-B2)")
	assert_eq(cc.rows.size(), claws_1x.size(), "una fila por garra o colmillo (los aguijones tienen su propia comparativa)")
	var prev := INF
	for i in cc.rows.size():
		var row: Dictionary = cc.rows[i]
		var p: Dictionary = s.lab.params()
		p.claw = Catalog.find_by_id(Catalog.CLAWS, row.id)
		p.tear = s.lab.tear_mode
		var res := Physics.compute(p)
		assert_eq(oracle_diff(row.res, res).size(), 0, "fila %s: compute()" % row.id)
		assert_true(res.pNominal <= prev, "de mayor a menor presión nominal")
		if i > 0 and res.pNominal == prev:
			assert_true(Catalog.CLAWS.find(Catalog.find_by_id(Catalog.CLAWS, cc.rows[i - 1].id)) < Catalog.CLAWS.find(p.claw), "empates en el orden del catálogo")
		prev = res.pNominal
		assert_eq(cc.row_parts[i][2].text, res.verdict)
		# la presión real de la fila, con «(tope)» si la nominal pasa de una dureza (4n)
		assert_true(cc.row_parts[i][3].text.contains(" · %s" % BenchTexts.compare_pressure(res)), "fila %s: %s" % [row.id, cc.row_parts[i][3].text])
	assert_true(cc.footnote.text.contains(BenchTexts.COMPARE_PRESSURE_NOTE), "la nota de la presión real")
	# pulsar una fila elige esa garra
	var last: String = cc.rows[-1].id
	_click(cc.row_buttons[cc.rows.size() - 1])
	assert_eq(s.lab.claw.id, last, "pulsar una fila usa esa herramienta")
	_click(s.tool_card.kind_seg.buttons["unas"])
	s.refresh_now()
	assert_eq(cc.title_label.text, "Comparativa por forma")
	assert_eq(cc.rows.size(), Catalog.GEOMS.size())
	var visible := 0
	for b in cc.row_buttons:
		visible += 1 if b.visible else 0
	assert_eq(visible, Catalog.GEOMS.size(), "una fila por forma")


func test_textos_de_la_herramienta_y_los_parametros() -> void:
	_select({ "claw": "vibora", "target": "piel", "force": "max", "method": "puncion" })
	var tc: Control = s.tool_card
	var tool: Dictionary = s.lab.tool()
	assert_eq(tc.claw_title.text, Lab.claw_spec(s.lab.claw, s.lab.inlay, tool).title)
	assert_eq(tc.claw_desc.text, s.lab.claw.desc)
	assert_eq(tc.claw_stats[1].get_child(1).text, "R %s µm · α %s°" % [Js.to_fixed(tool.tipRadiusUm, 0), Js.js_num_str(tool.alpha)])
	assert_eq(tc.claw_stats[6].get_child(1).text, "~%s J" % Format.fmt_j(tool.strikeJ))
	var pc: Control = s.params_card
	assert_true(pc.puncture_box.visible and not pc.scratch_box.visible, "punción: golpe sí, largo y pasadas no")
	assert_true(pc.puncture_note.text.contains("inyecta veneno"), "el colmillo inyecta")
	assert_true(pc.puncture_note.text.ends_with("≤ %s mm." % Js.js_num_str(tool.reach)))
	assert_eq(pc.max_main.text, "⤓ Usar fuerza MÁX. del colmillo · unos %s N" % Js.js_num_str(s.lab.claw.force))
	# 4q: el botón lleva su texto en etiquetas; los lectores de pantalla lo leen por su nombre, y las pasadas también
	assert_true(String(pc.max_button.accessibility_name).begins_with("Usar fuerza MÁX. del colmillo"), "el botón de la fuerza máxima tiene nombre")
	assert_eq(String((pc.pass_pills[1] as Button).accessibility_name), "1 pasada")
	assert_eq(String((pc.pass_pills[20] as Button).accessibility_name), "20 pasadas")
	assert_eq(pc.force.display.text, "%s N" % Format.fmt_f(s.lab.force))
	_click(pc.strike_seg.buttons["impacto"])
	assert_true(pc.strike_note.text.begins_with("Golpe dinámico: ½·m·v² ≈ %s J" % Format.fmt_j(s.lab.strike_j())))
	assert_true(pc.strike_note.text.ends_with("Velocidad y masa: %s." % BenchTexts.strike_origin(s.lab.claw)), "de dónde salen la velocidad y la masa")
	assert_false(tc.wet_box.visible, "la dentina no es queratina: sin selector de humedad")
	_select({ "geom": "almendra", "base": "natural", "target": "vidrio", "force": 4.0, "passes": 5 })
	assert_true(tc.wet_box.visible, "la uña natural es queratina")
	assert_true(pc.passes_note.visible)
	assert_true(pc.passes_note.text.contains("×%s" % Js.to_fixed(Physics.pass_depth_factor(5.0), 1)))
	assert_eq(pc.passes.display.text, "5×")
	assert_eq(s.target_card.tiles["coche"].sub_labels[0].text, Lab.target_sub(T("coche")))


func test_escala_de_fuerza_en_mn_con_un_aguijon() -> void:
	# la abeja melífera (el primer aguijón del catálogo, core/lab/insects.gd), elegida con la opción «Insectos»: el
	# deslizador pasa a mN y vuelve a N con una uña
	_click(s.tool_card.kind_seg.buttons["unas"])
	_click(s.tool_card.kind_seg.buttons["insectos"])
	_click(s.tool_card.claw_tiles["abeja"])
	var bee: Dictionary = Insects.STINGERS[0]
	assert_eq(s.lab.claw.id, "abeja", "«Insectos» elige la abeja melífera")
	var pc: Control = s.params_card
	var r: Dictionary = s.lab.force_range()
	var bee_mn := "%s mN" % Format.fmt_mn(bee.force)
	assert_eq(s.lab.force, 0.00575, "la fuerza del aguijón (N): el empuje de la abeja, 5,75 mN")
	assert_eq(pc.force.display.text, bee_mn, "fuerza en pantalla, en mN")
	var ticks: Array = pc.ticks.map(func(l: Label) -> String: return l.text)
	assert_eq(ticks, ["0,01 mN", "1 mN", "10 mN", "1000 mN"], "marcas de la escala de los aguijones")
	assert_near(pc.force.slider.value, Format.f_to_t_in(0.00575, r.min, r.max), 0.0, 0.0021, "el deslizador, en la escala del aguijón")
	assert_true(pc.max_main.text.ends_with("unos " + bee_mn), "botón de fuerza máxima en mN: %s" % pc.max_main.text)
	assert_false(pc.max_main.text.contains("~"), "sin virgulilla en la letra de los botones")
	assert_true(pc.max_note.text.contains("peso ~70 mg"), "y el peso de la abeja en mg: %s" % pc.max_note.text)
	assert_true(s.compare_card.intro.text.begins_with("Misma fuerza (%s)" % bee_mn), "la comparativa, en mN")
	# reforjado en diamante: la escala llega a 5000 mN (para ver el pandeo hacia 3,8 N); sin reforjar, vuelve a 1000
	_click(s.tool_card.inlay_pills["diamante"])
	var rf: Dictionary = s.lab.force_range()
	assert_eq(pc.ticks.map(func(l: Label) -> String: return l.text), ["0,01 mN", "1 mN", "100 mN", "5000 mN"], "escala reforjada")
	_slide(pc.force.slider, Format.f_to_t_in(3.8, rf.min, rf.max))
	assert_near(s.lab.force, 3.8, 0.05, 0.0, "el deslizador llega a ~3,8 N")
	_click(s.tool_card.inlay_pills["none"])
	assert_eq(s.lab.force, 0.00575, "sin reforjar, 3,8 N no caben: vuelve a la fuerza del aguijón")
	_slide(pc.force.slider, Format.f_to_t_in(0.03, r.min, r.max))
	assert_near(s.lab.force, 0.03, 0.05, 0.0, "el deslizador da ~30 mN")
	assert_eq(pc.force.display.text, "%s mN" % Format.fmt_mn(s.lab.force))
	_click(s.tool_card.kind_seg.buttons["unas"])
	assert_eq(s.lab.force, 4.0, "de vuelta a una uña, 4 N")
	assert_eq(pc.force.display.text, "4.0 N")
	ticks = pc.ticks.map(func(l: Label) -> String: return l.text)
	assert_eq(ticks, ["0,5 N", "roce humano", "zarpazo", "2000 N"], "marcas de la 1.x")


func test_insectos_en_la_tarjeta_de_la_herramienta_y_los_parametros() -> void:
	var tc: Control = s.tool_card
	var pc: Control = s.params_card
	var lab: LabState = s.lab
	# una garra rayando con desgarro: al elegir un insecto, solo punción (sin golpe ni desgarro) y, al volver, lo de antes
	_select({ "claw": "tigre", "target": "piel", "force": 20.0, "tear": true })
	assert_true(lab.tear_mode and lab.method == "rayado", "la garra raya con desgarro")
	_click(tc.kind_seg.buttons["insectos"])
	_click(tc.claw_tiles["abeja"])
	assert_true(lab.is_stinger() and lab.claw.id == "abeja", "«Insectos» y la ficha de la abeja")
	assert_eq([lab.method, lab.strike, lab.tear_mode], ["puncion", false, false], "un aguijón solo pica")
	assert_false(pc.method_seg.visible or pc.method_label.visible, "sin selector de método")
	assert_false(pc.strike_seg.visible or pc.strike_label.visible or pc.strike_note.visible, "ni de golpe")
	assert_true(pc.puncture_box.visible and not pc.scratch_box.visible, "punción, sin largo ni pasadas")
	assert_true(pc.puncture_note.text.begins_with("Un aguijón solo pica"), pc.puncture_note.text)
	# marcas del deslizador: perforar la piel y pandear (StingLab.marks), en su sitio de la escala
	var m := StingLab.marks(lab.claw, lab.inlay, lab.target)
	var r := lab.force_range()
	assert_true(pc.marks_row.visible, "leyenda de las marcas")
	assert_eq(pc.mark_items[0][2].text, "perfora la piel · ~%s" % StingLab.fmt_force(m.puncture))
	assert_eq(pc.mark_items[1][2].text, "pandea · ~%s" % StingLab.fmt_force(m.buckle))
	assert_eq(pc.marks.marks.size(), 2, "dos marcas en la pista")
	assert_eq(pc.marks.marks[0][0], Format.f_to_t_in(m.puncture, r.min, r.max), "la de perforar")
	assert_eq(pc.marks.marks[1][0], Format.f_to_t_in(m.buckle, r.min, r.max), "la de pandear")
	# fichas: solo las de los insectos; la del aguijón, con sus datos (StingLab.spec_rows) y sus fuentes
	for g: String in tc.claw_groups:
		assert_eq((tc.claw_groups[g][1] as Control).visible, g == Insects.GROUP, "fichas del grupo %s" % g)
	var tool: Dictionary = lab.tool()
	var rows := StingLab.spec_rows(lab.claw, lab.inlay, tool)
	for i in rows.size():
		assert_eq(tc.claw_stats[i].get_child(0).text, rows[i][0], "ficha: clave %d" % i)
		assert_eq(tc.claw_stats[i].get_child(1).text, rows[i][1], "ficha: %s" % rows[i][0])
	assert_true(tc.claw_source.visible and tc.claw_source.text.begins_with("Fuentes: "), tc.claw_source.text)
	assert_eq(tc.claw_source.tooltip_text, String(lab.claw.source), "la cita entera, en la ayuda")
	assert_false(tc.wet_box.visible, "la cutícula no es queratina: sin selector de humedad")
	assert_false(tc.inlay_note.visible, "sin reforjar, sin nota")
	# reforjado en acero: la nota con el pandeo en acero y en quitina
	_click(tc.inlay_pills["acero"])
	var mk: Dictionary = lab.sting_marks()
	assert_true(tc.inlay_note.visible and tc.inlay_note.text.contains("pandea a ~%s" % StingLab.fmt_force(mk.buckle)), tc.inlay_note.text)
	assert_true(tc.inlay_note.text.contains("(el de quitina, a ~%s)" % StingLab.fmt_force(mk.buckleNatural)), tc.inlay_note.text)
	assert_eq(pc.mark_items[1][2].text, "pandea · ~%s" % StingLab.fmt_force(mk.buckle), "la marca del pandeo, en acero")
	_click(tc.inlay_pills["none"])
	# otro insecto
	_click(tc.claw_tiles["avispa"])
	assert_eq(lab.claw.id, "avispa")
	assert_eq(tc.claw_title.text, Lab.claw_spec(lab.claw, lab.inlay, lab.tool()).title)
	# de vuelta a las garras: la de antes, rayando con desgarro
	_click(tc.kind_seg.buttons["garras"])
	assert_eq(lab.claw.id, "tigre", "vuelve la última garra")
	assert_eq([lab.method, lab.tear_mode], ["rayado", true], "y su método y su desgarro")
	assert_true(pc.method_seg.visible and pc.method_label.visible, "vuelve el selector de método")
	assert_false(pc.marks_row.visible, "sin marcas de aguijón")
	assert_false(tc.claw_source.visible, "las garras de la 1.x no llevan la línea de fuentes")
	for g: String in tc.claw_groups:
		assert_eq((tc.claw_groups[g][1] as Control).visible, g != Insects.GROUP, "fichas del grupo %s" % g)
	_click(tc.kind_seg.buttons["insectos"])
	assert_eq(lab.claw.id, "avispa", "la opción «Insectos» recuerda el último insecto")


func test_ensayo_de_un_aguijon_por_la_interfaz() -> void:
	var tc: Control = s.tool_card
	var lab: LabState = s.lab
	_click(tc.kind_seg.buttons["insectos"])
	_click(tc.claw_tiles["abeja"])
	_click(tc.inlay_pills["none"])
	_click(s.target_card.tiles["piel"])
	_click(s.params_card.max_button)
	assert_eq(lab.force, 0.00575, "fuerza MÁX. de la abeja")
	var bee: Dictionary = lab.claw
	s.sound.played.clear()
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	var p := lab.params()
	p.claw = bee
	p.tear = false
	var res := Physics.compute(p)
	assert_eq(oracle_diff(lab.res, res).size(), 0, "la interfaz pasa al banco los parámetros elegidos")
	var rc: ResultCard = s.result_card
	assert_eq(res.verdict, "SE QUEDA CLAVADO", "la abeja se queda clavada")
	assert_eq(rc.verdict.text, res.verdict, "veredicto")
	assert_eq(rc.verdict.get_theme_color("font_color"), Palette.color(res.vcol), "color del veredicto")
	assert_eq(rc.vsub.text, res.vsub, "subtítulo")
	assert_true(rc.moral.visible and rc.moral.text == StingLab.moral(res, lab.target), "moraleja: %s" % rc.moral.text)
	var shown := _metrics()
	var want: Array = ResultCard.sting_metric_rows(res)
	assert_eq(shown.size(), want.size(), "las métricas del aguijón")
	for row: Array in want:
		_check_metric(shown, row[0], row[2], "abeja", Palette.color(row[3]))
	for key: String in shown:
		assert_false(String(shown[key][0]).ends_with(" N"), "«%s» no se escribe en N: %s" % [key, shown[key][0]])
	_check_metric(shown, "Fuerza para perforar", "≈ %s" % StingLab.fmt_force(res.sting.fPunctureN), "abeja")
	_check_metric(shown, "Pandea a", "≈ %s" % StingLab.fmt_force(res.sting.fBuckleN), "abeja")
	_check_metric(shown, "Se queda clavado", "sí · autotomía", "abeja")
	_check_metric(shown, "Capa alcanzada", String(res.layer), "abeja")
	assert_true(rc.section_view.key.begins_with("sts:"), "corte de la piel con el aguijón: %s" % rc.section_view.key)
	assert_true(rc.skin_table.visible, "tabla de la piel")
	assert_false(rc.hardness.visible, "en la piel no hay barras de dureza")
	# el cuaderno y los sonidos: el picotazo al perforar y el desgarro del aparato cuando la abeja se va
	var entry: Array = s.badges_card.book_rows[0]
	assert_eq(entry[2].text, "%s → %s" % [Lab.tool_label({ "claw": bee, "geom": lab.geom, "inlay": lab.inlay, "res": res }), lab.target.name])
	assert_eq(entry[3].text, res.verdict, "veredicto del cuaderno")
	var ids: Array = s.sound.played.map(func(x: Array) -> String: return x[0])
	assert_eq(SfxInsects.sfx_for_result(res, lab.target), "picotazo")
	assert_true(ids.has("picotazo"), "suena el picotazo: %s" % [ids])
	assert_false(ids.has(LabState.SFX_TEAR), "el desgarro, todavía no")
	var tl := StingLab.timeline(res, LabState.RUN_MS)
	s.step(tl.tear - LabState.RUN_MS)
	ids = s.sound.played.map(func(x: Array) -> String: return x[0])
	assert_true(ids.has(LabState.SFX_TEAR), "y el desgarro del aparato cuando la abeja se va: %s" % [ids])
	# un sólido: la abeja de acero contra el pino entra unas micras; la de quitina, contra el vidrio, se aplasta
	_click(tc.inlay_pills["acero"])
	_click(s.target_card.tiles["vidrio"])
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	var p2 := lab.params()
	p2.claw = bee
	p2.tear = false
	var res2 := Physics.compute(p2)
	assert_eq(oracle_diff(lab.res, res2).size(), 0, "abeja de acero contra el vidrio")
	assert_eq(rc.verdict.text, res2.verdict)
	assert_true(rc.hardness.visible and rc.hard_rows[0][0].text == "Aguijón", "barras de dureza: el aguijón y el vidrio")
	shown = _metrics()
	for row: Array in ResultCard.sting_metric_rows(res2):
		_check_metric(shown, row[0], row[2], "abeja de acero contra el vidrio", Palette.color(row[3]))
	assert_true(rc.section_view.key.begins_with("xs:"), "en un sólido, el perfil de la huella")
	_click(tc.inlay_pills["none"])


func test_comparativa_de_aguijones_en_hilos_igual_que_en_serie() -> void:
	var tc: Control = s.tool_card
	var cc: Control = s.compare_card
	_click(tc.kind_seg.buttons["insectos"])
	_click(tc.claw_tiles["abeja"])
	_click(tc.inlay_pills["none"])
	_click(s.target_card.tiles["piel"])
	_click(s.params_card.max_button)
	s.refresh_now()
	assert_true(cc.threaded, "la comparativa calcula en hilos")
	assert_eq(cc.title_label.text, "Comparar aguijones")
	assert_true(cc.intro.text.begins_with("Misma fuerza (%s mN)" % Format.fmt_mn(0.00575)), cc.intro.text)
	assert_eq(cc.rows.size(), Insects.STINGERS.size(), "una fila por aguijón")
	var prev := INF
	for i in cc.rows.size():
		var row: Dictionary = cc.rows[i]
		var c: Variant = Insects.find_by_id(row.id)
		assert_true(c != null, "fila %s: un aguijón" % row.id)
		var p: Dictionary = s.lab.params()
		p.claw = c
		p.tear = false
		var res := Physics.compute(p)
		assert_eq(oracle_diff(row.res, res).size(), 0, "fila %s: la de compute() en serie" % row.id)
		assert_true(res.pNominal <= prev, "de mayor a menor presión nominal")
		prev = res.pNominal
		assert_eq(cc.row_parts[i][2].text, res.verdict)
		assert_eq(cc.row_parts[i][3].text, cc.sting_meta(res) + ((" · " + Format.fmt_depth(res.depthUm)) if res.depthUm > 0.1 else ""))
	# las mismas filas sin hilos (se recalculan al cambiar la fuerza y volver)
	var in_threads: Array = cc.rows.duplicate()
	cc.threaded = false
	s.lab.set_force(0.006)
	s.refresh_now()
	s.lab.set_force(0.00575)
	s.refresh_now()
	assert_eq(cc.rows.size(), in_threads.size())
	for i in cc.rows.size():
		assert_eq(cc.rows[i].id, in_threads[i].id, "fila %d: mismo orden en serie y en hilos" % i)
		assert_true(same(cc.rows[i].res, in_threads[i].res), "fila %s: idéntica en serie y en hilos" % cc.rows[i].id)
	cc.threaded = true
	# pulsar una fila elige ese aguijón
	_click(cc.row_buttons[cc.rows.size() - 1])
	assert_eq(s.lab.claw.id, cc.rows[-1].id, "pulsar una fila usa ese aguijón")
	assert_true(s.lab.is_stinger())


## Materiales de la 2.0 (unidad 4a): la ventanilla templada se elige en la tarjeta del objetivo y el ensayo se pinta con
## su veredicto y sus filas; y cada tema (uña que cede, huella residual, abolladura, grietas, vidrios y mellado) tiene su
## fila en la tarjeta del resultado, con los números de compute() y los formatos de core. Con un resultado de la 1.x no
## aparece ninguna.
func test_tarjeta_con_los_materiales_de_la_2_0() -> void:
	var rc: ResultCard = s.result_card
	# por la interfaz: la garra de tigre de diamante apretando la ventanilla (el truco del martillo de emergencia)
	var p := _select({ "claw": "tigre", "inlay": "diamante", "target": "ventanilla", "force": "max", "method": "puncion" })
	assert_eq(Lab.target_sub(p.target), "550 HV · templado · frágil", "la ficha del objetivo dice cómo está hecho")
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	var res := Physics.compute(p)
	assert_eq(oracle_diff(s.lab.res, res).size(), 0, "el banco usa compute() con la física 2.0")
	assert_eq(rc.verdict.text, "ESTALLA LA VENTANILLA")
	assert_eq(rc.vsub.text, res.vsub)
	var shown := _metrics()
	_check_metric(shown, "Estalla por una grieta con", "≈ %s N" % Format.fmt_f(res.glazing.pierceN), "ventanilla", Palette.color("coral"))
	_check_metric(shown, "Trozos al estallar", "~%s por 5 × 5 cm, de ~%s mm" % [Js.js_num_str(Js.js_round(res.glazing.fragments25)),
		Js.to_fixed(res.glazing.fragmentMm, 1)], "ventanilla", Palette.color("coral"))
	_check_metric(shown, "La hoja se parte con", "≈ %s N" % Format.fmt_f(res.paneN), "ventanilla", Palette.color("coral"))
	# cada tema, pintando resultados de compute() en la tarjeta
	var base := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.INLAYS[0], "claw": null, "type": Catalog.find_by_id(Catalog.TYPES, "aranazo"), "length": 25.0,
		"tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false,
	}
	var show := func(over: Dictionary) -> Dictionary:
		var q := base.duplicate()
		q.merge(over, true)
		var r := Physics.compute(q)
		rc.show_result(r, q.target, 25.0)
		assert_eq(rc.verdict.text, r.verdict)
		assert_eq(rc.vsub.text, r.vsub)
		return r
	var nail: Dictionary = show.call({ "geom": Catalog.find_by_id(Catalog.GEOMS, "stiletto"), "target": T("piel"), "force": 30.0 })
	assert_eq(rc.verdict.text, "SE DOBLA LA UÑA")
	_check_metric(_metrics(), "La uña cede a", "≈ %s N (se dobla)" % Format.fmt_f(nail.nail.breakN), "stiletto", Palette.color("gold"))
	var paint: Dictionary = show.call({ "target": T("coche"), "force": 4.0 })
	shown = _metrics()
	_check_metric(shown, "Profundidad surco", "≈ %s" % Format.fmt_depth(paint.depthUm), "barniz", Palette.color(paint.vcol))
	# el «%» va pegado a su número con un espacio duro (4q: en el teléfono, «%)» quedaba solo en otra línea)
	_check_metric(shown, "Queda al levantar la punta", "≈ %s (recupera 100 %%)" % Format.fmt_depth(0.0), "barniz", Palette.color("mint"))
	_check_metric(shown, "La uña cede a", "≈ %s N (se dobla)" % Format.fmt_f(paint.nail.breakN), "barniz", Palette.color("dim"))
	var dent: Dictionary = show.call({ "claw": Catalog.find_by_id(Catalog.CLAWS, "oso"), "target": T("coche"), "force": 300.0,
		"method": "puncion", "strike": true })
	assert_eq(rc.verdict.text, "ABOLLA LA CHAPA")
	_check_metric(_metrics(), "Abolladura", "≈ %s mm (se queda %s J)" % [Js.to_fixed(dent.dent.depthMm, 1), Format.fmt_j(dent.dent.panelJ)],
		"oso", Palette.color("coral"))
	var hertz: Dictionary = show.call({ "geom": Catalog.find_by_id(Catalog.GEOMS, "cuadrada"), "base": Catalog.find_by_id(Catalog.BASES, "zafiro"),
		"target": T("vidrio"), "force": 30.0 })
	assert_eq(rc.verdict.text, "GRIETAS DE HERTZ")
	_check_metric(_metrics(), "Grietas", "herraduras desde ≈ %s N" % Format.fmt_f(hertz.fracture.hertzN), "Hertz", Palette.color("gold"))
	var chip: Dictionary = show.call({ "geom": Catalog.find_by_id(Catalog.GEOMS, "stiletto"), "base": Catalog.find_by_id(Catalog.BASES, "zafiro"),
		"target": T("vidrio"), "force": 30.0 })
	_check_metric(_metrics(), "Grietas", "astillado ≈ %s" % Format.fmt_depth(chip.fracture.crackUm), "astillado", Palette.color("coral"))
	var screen: Dictionary = show.call({ "claw": Catalog.find_by_id(Catalog.CLAWS, "oso"), "target": T("parabrisas"), "force": 300.0,
		"method": "puncion", "strike": true })
	assert_eq(rc.verdict.text, "SE AGRIETA (NO CAE)")
	_check_metric(_metrics(), "Atravesarlo", "podría (%s J > 88.7 J)" % Format.fmt_j(screen.energyJ), "parabrisas", Palette.color("coral"))
	var eagle: Dictionary = show.call({ "claw": Catalog.find_by_id(Catalog.CLAWS, "aguila"), "inlay": Catalog.find_by_id(Catalog.INLAYS, "zafiro"),
		"target": T("coche"), "force": 110.0 })
	_check_metric(_metrics(), "La punta se mella con", "≈ %s N (lleva ≈ %s N)" % [Format.fmt_f(eagle.tipChip.chipN),
		Format.fmt_f(eagle.tipChip.lateralN)], "águila de zafiro", Palette.color("coral"))
	# con un resultado de la 1.x, ninguna fila de la 2.0
	var q1 := base.duplicate()
	q1.merge({ "target": T("coche"), "force": 4.0, "model": "1.x" }, true)
	rc.show_result(Physics.compute(q1), q1.target, 25.0)
	shown = _metrics()
	for key in ["Queda al levantar la punta", "La uña cede a", "Abolladura", "Grietas", "Atravesarlo", "La punta se mella con",
			"Estalla por una grieta con", "Trozos al estallar"]:
		assert_false(shown.has(key), "1.x: sin la fila «%s»" % key)


func test_zona_angulo_y_filas_de_la_biologia_de_la_2_0() -> void:
	# docs/fisica/pulido-biologia.md §9: la zona del cuerpo (con la piel), el ángulo de ataque (donde cambia algo) y las
	# filas nuevas del resultado; todo sale de compute() con los parámetros elegidos
	var rc: ResultCard = s.result_card
	var tc: Control = s.target_card
	var pc: Control = s.params_card
	_select({ "claw": "vibora", "target": "cobre", "force": 4.0 })
	assert_false(tc.zone_box.visible, "sin piel no hay zona")
	var p := _select({ "claw": "vibora", "target": "piel", "force": 4.0, "method": "puncion" })
	assert_true(tc.zone_box.visible, "con la piel se elige la zona")
	assert_true(tc.zone_pills["brazo"].button_pressed, "por defecto, el brazo de la 1.x")
	_click(tc.zone_pills["cara"])
	assert_eq(s.lab.zone, "cara")
	assert_true(tc.zone_pills["cara"].button_pressed and not tc.zone_pills["brazo"].button_pressed)
	assert_true(tc.zone_note.text.begins_with("Cara (pómulo): "), tc.zone_note.text)
	assert_false(pc.attack_box.visible, "un colmillo punzando: el ángulo no cambia nada")
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	p["zone"] = "cara"
	var res := Physics.compute(p)
	assert_eq(oracle_diff(s.lab.res, res).size(), 0, "el banco usa la zona elegida")
	assert_eq(rc.verdict.text, "SE CLAVA EN EL HUESO")
	var shown := _metrics()
	_check_metric(shown, "Zona", "Cara (pómulo)", "pómulo")
	_check_metric(shown, "Hueso", "Hueso cigomático a %s: entra ≈ %s" % [Format.fmt_depth(res.pen.boneDepthUm),
		Format.fmt_depth(res.pen.boneIndentUm)], "pómulo", Palette.color("coral"))
	_check_metric(shown, "Frenan la punta", "≈ %s N + %s N" % [Format.fmt_f(res.pen.crackN), Format.fmt_f(res.pen.frictionN)], "pómulo")
	_check_metric(shown, "Capa alcanzada", "Hueso cigomático", "pómulo")
	assert_eq(rc.skin_table.zone, "cara", "la tabla de la piel, la del pómulo")
	assert_eq(rc.skin_table.rows["hueso"].theme_type_variation, &"RowOn", "con el hueso resaltado")
	assert_true(String(s.badges_card.book_rows[0][2].text).ends_with("→ Piel · Pómulo"), "el cuaderno nombra la zona")
	_click(tc.zone_pills["brazo"])
	assert_eq(s.lab.zone, "brazo")
	# el ángulo de ataque: con una uña, siempre; con una garra, al rayar un sólido
	var q := _select({ "geom": "stiletto", "base": "natural", "target": "madera", "force": 30.0 })
	assert_true(pc.attack_box.visible, "con una uña se elige el ángulo")
	assert_eq(pc.attack.display.text, "45°", "por defecto, 45° (estimación)")
	assert_false(pc.attack_reset.visible, "sin ángulo pedido no hay nada que deshacer")
	_slide(pc.attack.slider, 20.0)
	assert_eq(s.lab.attack_deg, 20.0)
	assert_true(pc.attack_reset.visible)
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	q["attack_deg"] = 20.0
	var tilted := Physics.compute(q)
	assert_eq(oracle_diff(s.lab.res, tilted).size(), 0, "el banco usa el ángulo elegido")
	assert_true(rc.vsub.text.contains("ataque de 20°"), rc.vsub.text)
	_check_metric(_metrics(), "Ángulo de ataque", "20° · cara a %s°" % Js.js_num_str(tilted.faceDeg), "stiletto tumbada")
	_click(pc.attack_reset)
	assert_eq([s.lab.attack_deg, pc.attack.display.text], [null, "45°"], "vuelve al de la herramienta")
	_select({ "claw": "gato", "target": "piel", "force": 4.0 })
	assert_false(pc.attack_box.visible, "una garra en la piel: el modelo por capas no usa el ángulo")
	_select({ "claw": "gato", "target": "plastico", "force": 15.0 })
	assert_true(pc.attack_box.visible)
	assert_eq(pc.attack.display.text, "90°", "una garra va de punta")
	# la punta de esmalte de un colmillo contra lo duro, y ninguna fila de la biología con un resultado de la 1.x
	var base := {
		"geom": Catalog.find_by_id(Catalog.GEOMS, "almendra"), "base": Catalog.find_by_id(Catalog.BASES, "natural"),
		"inlay": Catalog.INLAYS[0], "claw": Catalog.find_by_id(Catalog.CLAWS, "vibora"), "target": T("cobre"),
		"type": Catalog.find_by_id(Catalog.TYPES, "aranazo"), "force": 4.0, "length": 25.0, "tear": false, "method": "rayado",
		"strike": false, "passes": 1.0, "wet": false,
	}
	var fang := Physics.compute(base)
	rc.show_result(fang, base.target, 25.0)
	_check_metric(_metrics(), "Punta de esmalte", "≈ %s HV en el contacto (dentina %s HV)" % [Format.fmt_p(fang.tipHv), Format.fmt_p(fang.hvTool)],
		"víbora sobre cobre", Palette.color("gold"))
	var old := base.duplicate()
	old.merge({ "target": T("piel"), "method": "puncion", "model": "1.x" }, true)
	rc.show_result(Physics.compute(old), old.target, 25.0)
	shown = _metrics()
	for key in ["Zona", "Hueso", "Frenan la punta", "Punta de esmalte", "Ángulo de ataque"]:
		assert_false(shown.has(key), "1.x: sin la fila «%s»" % key)
	assert_eq(rc.skin_table.zone, null, "1.x: la tabla de siempre, sin hueso")
	assert_false(rc.skin_table.rows.has("hueso"))


func test_atajo_y_logros() -> void:
	var before: int = s.lab.count
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.pressed = true
	e.ctrl_pressed = true
	e.meta_pressed = true
	s._input(e)
	assert_eq(s.lab.count, before + 1, "Ctrl+Intro (⌘+Intro en macOS) lanza el ensayo")
	s._input(e)
	assert_eq(s.lab.count, before + 1, "mientras se ensaya, el atajo no hace nada")
	s.step(LabState.RUN_MS + 50.0)
	var got := 0
	for id: String in s.badges_card.badges:
		var l: Label = s.badges_card.badges[id]
		var has: bool = s.lab.badges.has(id)
		got += 1 if has else 0
		assert_eq(l.theme_type_variation, &"BadgeOn" if has else &"BadgeOff", "logro %s" % id)
		assert_true(l.text.begins_with("★ " if has else "○ "))
	assert_eq(s.badges_card.count.text, "%d/%d" % [got, Lab.BADGES.size()])
	assert_true(got >= 1, "a estas alturas algún logro hay")


## Unidad 4n: la presión real con su tope (la nominal, sin sentido por encima de la dureza), la etiqueta FICCIÓN del
## velocirraptor de cine y «Fuentes y estimaciones de este ensayo» (plegada, con su resumen) por la interfaz.
func test_presion_ficcion_y_fuentes_del_ensayo() -> void:
	var rc: ResultCard = s.result_card
	var lab: LabState = s.lab
	# el velocirraptor de cine contra el coche moderno: ficción, con su nota, y sus fuentes
	_select({ "claw": "velociraptor_pelicula", "target": "coche", "force": "max" })
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	var fic: Dictionary = BenchTexts.fiction(lab.claw, lab.inlay)
	assert_false(fic.is_empty(), "la garra de cine es ficción")
	assert_true(rc.tag_fiction.visible and rc.fiction_note.visible, "etiqueta FICCIÓN y su nota")
	assert_eq(rc.fiction_note.text, String(fic.note))
	var rows: Array = lab.trial_sources()
	assert_true(rows.size() >= 3, "fuentes del velocirraptor de cine (%d)" % rows.size())
	assert_true(rc.sources_box.visible, "se ve «Fuentes y estimaciones de este ensayo»")
	assert_eq(rc.sources_summary.text, BenchTexts.sources_summary(rows))
	assert_false(rc.sources_list.visible, "la lista empieza plegada")
	_click(rc.sources_toggle)
	assert_true(rc.sources_list.visible and rc.sources_toggle.text == "Ocultar", "«Ver» la despliega")
	for i in rows.size():
		var r: Dictionary = rows[i]
		var it: Array = rc.sources_rows[i]
		assert_true((it[0] as Control).visible, "fila %d a la vista" % i)
		assert_true((it[1] as Label).text.begins_with("%s: %s" % [r.label, r.value]), "fila %d: %s" % [i, (it[1] as Label).text])
		assert_eq((it[1] as Label).tooltip_text, r.source, "fila %d: la cita, en la ayuda del dato" % i)
		assert_false((it[2] as Label).visible, "fila %d: sin la cita debajo hasta «Citas completas»" % i)
		assert_true(String(r.source) != "", "fila %d (%s): con fuente" % [i, r.label])
	assert_true(rc.sources_full.visible, "«Citas completas»")
	_click(rc.sources_full)
	for i in rows.size():
		var src: Label = rc.sources_rows[i][2]
		assert_true(src.visible, "fila %d: la cita, debajo" % i)
		assert_eq(src.text, "Fuente: %s" % rows[i].source, "fila %d: la cita entera" % i)
	_click(rc.sources_full)
	assert_false((rc.sources_rows[0][2] as Label).visible, "y se vuelven a ocultar")
	_click(rc.sources_toggle)
	assert_false(rc.sources_list.visible, "«Ocultar» la pliega")
	# la garra de tigre contra el coche: sin ficción, y la presión nominal pasa de la dureza
	_select({ "claw": "tigre", "target": "coche", "force": 30.0 })
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	assert_false(rc.tag_fiction.visible or rc.fiction_note.visible, "una garra de verdad no es ficción")
	var res: Dictionary = lab.res
	assert_true(res.pNominal > res.pressure * BenchTexts.CAP_MARGIN, "la punta de la garra pasa de la dureza")
	var shown := _metrics()
	_check_metric(shown, "Presión nominal", "sin sentido: pasa de la dureza", "tigre")
	_check_metric(shown, "Presión real", "%s MPa" % Format.fmt_p(res.pressure), "tigre")
	assert_eq(rc.sources_summary.text, BenchTexts.sources_summary(lab.trial_sources()))
	# con la 1.x no hay datos de la 2.0 que citar
	lab.set_model(Physics.MODEL_V1)
	_click(s.run_button)
	s.step(LabState.RUN_MS + 50.0)
	assert_eq(lab.trial_sources(), [], "1.x: sin fuentes de la 2.0")
	assert_false(rc.sources_box.visible, "1.x: sin «Fuentes y estimaciones»")
	lab.set_model(Physics.MODEL_V2)


## En el teléfono las métricas van de dos en dos, como en la 1.x móvil; en escritorio, las columnas de 158 px de la 1.x.
func test_metricas_de_dos_en_dos_en_el_telefono() -> void:
	var rc := ResultCard.new()
	var g: Control = rc.metrics_grid
	assert_true(g.resized.is_connected(rc.fit_metrics), "se ajusta cada vez que cambia de ancho")
	for c: Array in [[640.0, 158.0, 3], [334.0, 158.0, 2], [318.0, 155.0, 2], [300.0, 146.0, 2], [200.0, 120.0, 1]]:
		g.size = Vector2(c[0], 40.0)
		rc.fit_metrics()  # fuera del árbol no llega la señal resized
		assert_eq(g.min_col, c[1], "%s px: columnas de al menos %s px" % [c[0], c[1]])
		assert_eq(g.columns_for(c[0]), c[2], "%s px: %d columnas" % [c[0], c[2]])
	rc.free()


func test_ultimo_libera_la_seccion() -> void:
	assert_true(s.art.pending() == 0, "sin hilos pendientes")
	s.free()
	s = null
	assert_true(s == null)
