## Tarjeta «Coche en marcha» (app/lab/moving_car_card.gd) y su dibujo, su gráfica y su barra de energía. Se comprueba:
##   - que cada texto sale del core (MovingCarState, y este de MovingCar) con el formato de siempre, y que coincide con
##     llamar a MovingCar a mano;
##   - que la banda del despegue está siempre a la vista, y en el golpe la suya (unidad 4j: todo a favor y todo en contra);
##   - que las estimaciones van marcadas, con su fuente;
##   - que en un teléfono (390 × 844) va en una columna, sin desbordar, con controles de tamaño táctil;
##   - que la velocidad va en directo sin rehacer la gráfica y que lo caro espera a soltar el deslizador; con hilo, lo
##     mismo que sin hilo;
##   - que la escena quieta no se redibuja;
##   - el fallo que ya nos ha pasado dos veces: dentro del árbol, cambiar el recorrido de un deslizador recorta su valor
##     y emite value_changed; la tarjeta pone recorrido y valor con las señales bloqueadas (set_slider);
##   - que la interfaz no calcula física (vigilancia del código);
##   - la unidad 4d cableada (el material de las garras, el animal asustado y el casuario, que solo patea), los
##     experimentos de un clic, el porqué, el «¿sabías que…?» con su fuente, la moraleja y el sonido del golpe;
##   - que una unidad no se parte al final de un renglón («400 km/» y «h»);
##   - lo que pidió la 4i-B2 (unidad 4j): las variantes del velocirraptor, el color de la ficción, el deslizador «Afilado»
##     y la caída escondida en un salto, y que todo cabe en un teléfono.
## El ejecutor falla si aparece «SCRIPT ERROR» en la salida.
extends "res://tests/case.gd"

const Card = preload("res://app/lab/moving_car_card.gd")
const LabSection = preload("res://app/lab/lab_section.tscn")
const LabState = preload("res://core/lab/lab_state.gd")
const MCS = preload("res://core/lab/moving_car_state.gd")
const MC = preload("res://core/lab/moving_car.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Energy = preload("res://app/lab/moving_car_energy.gd")
const Pill = preload("res://app/common/pill.gd")
const Palette = preload("res://app/theme/palette.gd")
const Bar = preload("res://app/common/bar.gd")

const UI_FILES := ["res://app/lab/moving_car_card.gd", "res://app/lab/moving_car_view.gd", "res://app/lab/moving_car_chart.gd",
	"res://app/lab/moving_car_energy.gd"]


static func C(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.CLAWS, id)


static func T(id: String) -> Dictionary:
	return Catalog.find_by_id(Catalog.TARGETS, id)


## Una tarjeta suelta, con su banco, un animal y lo caro sin hilos (en el acto).
func _card(claw_id := "aguila", threaded := false) -> Control:
	var card: Control = Card.new()
	card.theme = AppTheme.get_theme()
	var lab := LabState.new()
	card.setup(lab, ArtCache.new())
	card.st.threaded = threaded
	if claw_id != "":
		lab.set_claw(C(claw_id))
		card.refresh()
	card.finish()
	return card


## Lo que se lee en una etiqueta: sin el espacio duro ni la unión de palabras que pegan las unidades (Card.nb).
static func plain(s: String) -> String:
	return s.replace("\u2060", "").replace("\u00a0", " ")


## Textos de una rejilla de dos columnas: [[clave, valor]] de las filas que se ven.
static func _grid_rows(grid: GridContainer) -> Array:
	var out: Array = []
	for i in range(0, grid.get_child_count(), 2):
		var k := grid.get_child(i) as Label
		if k.visible:
			out.append([k.text, plain((grid.get_child(i + 1) as Label).text)])
	return out


## Fichas que se ven: [{ title, value, sub, quality, tip }].
static func _tiles(pool: Array) -> Array:
	var out: Array = []
	for t: Array in pool:
		if (t[0] as Control).visible:
			out.append({ "title": (t[1] as Label).text, "value": plain((t[2] as Label).text), "sub": plain((t[3] as Label).text),
				"quality": (t[4] as Label).text if (t[4] as Label).visible else "", "tip": (t[0] as Control).tooltip_text })
	return out


func test_sin_animal_con_datos_dice_cuales_los_tienen() -> void:
	var card := _card("")
	assert_true(card.off_box.visible and not card.main_box.visible, "con una uña, solo el texto")
	for a: Dictionary in MCS.supported_animals():
		assert_true(card.off_text.text.contains(String(a.name).to_lower()), "nombra %s: %s" % [a.name, card.off_text.text])
		assert_true((card.animal_pills[a.id] as Control).visible, "y deja elegir %s" % a.name)
	card.lab.set_claw(C("gato"))
	card.refresh()
	assert_true(card.off_box.visible, "el gato no tiene datos")
	assert_true(card.off_text.text.contains("sin datos aerodinámicos de garra de gato"), "con el motivo de MovingCar: %s" % card.off_text.text)
	(card.animal_pills["oso"] as Button).pressed.emit()
	card.refresh()
	assert_eq(String(card.lab.claw.id), "oso", "pulsar un animal lo elige en el banco")
	assert_true(card.main_box.visible and not card.off_box.visible, "y aparece la tarjeta")
	assert_eq(card.title_label.text, "Coche en marcha · Oso pardo", "con el nombre de la especie")
	card.lab.set_model("1.x")
	card.refresh()
	assert_true(card.off_box.visible and card.off_text.text.contains("física 2.0"), "con el motor 1.x no hay coche en marcha")
	card.free()


func test_cada_texto_sale_del_core() -> void:
	var card := _card("aguila")
	var st: RefCounted = card.st
	card.speed.slider.value_changed.emit(110.0)
	card.finish()
	card.step(16.0)
	# a mano, con MovingCar: el mismo ensayo y la misma velocidad
	var p: Dictionary = st.hold_params()
	var s := MC.setup(p)
	var a := MC.at_speed(s, 110.0)
	var d := MC.detach(s)
	var v := MC.detach_verdict(s, d)
	assert_eq(card.verdict_label.text, Card.headline(String(v.verdict)), "veredicto de MovingCar")
	assert_eq(plain(card.vsub.text), String(v.vsub), "con su texto y su banda")
	assert_eq(card.speed.display.text, "110 km/h", "velocidad del deslizador")
	var tiles := {}
	for t: Dictionary in _tiles(card.tiles):
		tiles[t.title] = t
	assert_eq(tiles.size(), st.hold_readings().size(), "una ficha por lectura")
	assert_eq(tiles["Resistencia (D)"].value, Format.fmt_f(a.dragN) + " N", "resistencia: %s" % tiles["Resistencia (D)"].value)
	assert_eq(tiles["Sustentación (L)"].value, Format.fmt_f(a.liftN) + " N", "sustentación")
	assert_eq(tiles["Peso (m·g)"].value, Format.fmt_f(a.weightN) + " N", "peso")
	assert_eq(tiles["Normal contra el panel (R)"].value, Format.fmt_f(a.normalN) + " N", "normal")
	assert_eq(tiles["Fuerza necesaria"].value, Format.fmt_f(a.needN) + " N", "necesaria")
	assert_eq(tiles["Fuerza necesaria"].sub, "banda de %s N a %s N" % [Format.fmt_f(a.needMinN), Format.fmt_f(a.needMaxN)], "con su banda")
	assert_eq(tiles["Fuerza disponible (μ·R + anclaje)"].value, Format.fmt_f(a.availN) + " N", "disponible")
	assert_eq(tiles["Margen"].value, Format.fmt_f(a.marginN) + " N", "margen")
	assert_eq(tiles["Carga"].value, Js.to_fixed(a.loadRatio * 100.0, 0) + " %", "carga")
	assert_eq(tiles["Aire en el animal"].value, Js.to_fixed(a.localKmh, 0) + " km/h", "aire local")
	assert_eq(tiles["Potencia que roba al motor"].value, Format.fmt_f(a.powerW) + " W", "potencia")
	assert_eq(tiles["Frente al coche entero"].value, Js.to_fixed(a.dragShare * 100.0, 0) + " %", "reparto")
	assert_eq(_grid_rows(card.hold_report), st.hold_rows(), "informe del estado")
	var rep := MC.hold_report(p)
	var rows := {}
	for r: Array in _grid_rows(card.hold_report):
		rows[r[0]] = r[1]
	assert_true(String(rows["Frenada máxima que aguanta"]).begins_with(CarFormat.fmt_g_max(rep.brakingG) + " a 110 km/h"),
		"frenada de hold_report: %s" % rows["Frenada máxima que aguanta"])
	assert_eq(rows["Aire"], MC.air_txt(rep.air), "el aire en palabras")
	assert_eq(plain(card.air_label.text), MC.air_txt(rep.air), "leyenda del aire")
	# el golpe: los textos de impact()
	card.lab.set_claw(C("tigre"))
	card.refresh()
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	(card.izone_pills["puerta"] as Button).pressed.emit()
	card.speed.slider.value_changed.emit(50.0)
	card.finish()
	var hit := MC.impact(st.impact_params())
	assert_eq(card.verdict_label.text, Card.headline(String(hit.verdict)), "veredicto del golpe")
	assert_eq(plain(card.vsub.text), String(hit.vsub), "su texto")
	assert_eq(_grid_rows(card.impact_report), hit.report, "informe de daños de impact()")
	var itiles := {}
	for t: Dictionary in _tiles(card.impact_tiles):
		itiles[t.title] = t
	assert_eq(itiles["Velocidad relativa"].value, Js.to_fixed(hit.vRelKmh, 0) + " km/h", "velocidad relativa")
	assert_eq(itiles["Energía respecto al coche"].value, MC.fmt_energy(hit.energyJ), "energía")
	assert_eq(itiles["Abolladura"].value, MC.fmt_long(float(hit.dent.depthMm) * 1000.0), "abolladura en mm")
	var terms: Array = hit.energy.terms
	assert_eq(card.energy.terms, terms, "la barra: los términos de impact(), en su orden")
	for i in terms.size():
		var label: Label = card.energy.items[i][2]
		assert_true(label.text.begins_with("%s %s" % [terms[i].short, Energy.share_txt(terms[i].share)]), "leyenda: %s" % label.text)
	# el formato de la barra es el del core (unidad 4j: un solo sitio para los formatos)
	for share: float in [0.0, 0.0004, 0.001, 0.004, 0.0099, 0.01, 0.55, 1.0]:
		assert_eq(Energy.share_txt(share), CarFormat.fmt_share(share), "parte %s" % share)
	card.free()


func test_la_banda_siempre_a_la_vista() -> void:
	var card := _card("aguila")
	var st: RefCounted = card.st
	var cases := [["aguila", "techo", "plegadas", "crucero"], ["aguila", "techo", "abiertas", "crucero"],
		["aguila", "retrovisor", "plegadas", "crucero"], ["oso", "techo", "de_pie", "emergencia"], ["tigre", "capo", "tumbado", "curva_fuerte"]]
	for c: Array in cases:
		card.lab.set_claw(C(c[0]))
		card.refresh()
		st.set_zone(c[1])
		st.set_posture(c[2])
		st.set_maneuver(c[3])
		card.finish()
		card.step(16.0)
		var b: Dictionary = st.band()
		var tag := "%s %s %s %s" % c
		assert_true(card.band_bar.visible and card.band_text.visible, "%s: la barra y el texto de la banda se ven" % tag)
		var band_txt := plain(card.band_text.text)
		assert_true(band_txt.contains(String(b.lo_txt)) and band_txt.contains(String(b.hi_txt)), "%s: con los dos extremos: %s" % [tag, band_txt])
		assert_true(band_txt.contains(String(b.central)), "%s: y el valor central" % tag)
		assert_false(band_txt.contains("de ni parado") or band_txt.contains("de no se suelta"), "%s: la banda se lee bien: %s" % [tag, band_txt])
		# el rótulo va en Syne, cuya virgulilla parece un guion: «A ~24 km/h» se dice «A UNOS 24 km/h»
		assert_false(card.verdict_label.text.contains("~"), "%s: rótulo sin virgulilla: %s" % [tag, card.verdict_label.text])
		assert_eq(card.verdict_label.text.contains(" A UNOS "), String(st.verdict.verdict).contains(" A ~"),
			"%s: con «unos» donde MovingCar dice «~»: %s" % [tag, card.verdict_label.text])
		assert_eq(card.chart.det, st.det, "%s: la gráfica sombrea la misma banda" % tag)
		assert_true(card.now_band.text.contains("en contra") and card.now_band.text.contains("a favor"), "%s: y a esta velocidad" % tag)
	st.set_mode("impact")
	card.finish()
	card.step(16.0)
	# unidad 4j: en el golpe, su banda (MovingCar.impact_band), en una frase del estado
	var itxt := plain(card.band_text.text)
	assert_true(card.band_text.visible and itxt == plain(Card.nb(st.impact_band_text())), "en el golpe, la banda del golpe: %s" % itxt)
	assert_true(itxt.begins_with("Banda de los datos, de todo a favor del coche a todo en contra: ") and itxt.contains("contra el panel"), itxt)
	assert_false(card.band_text.text.contains("MovingCar"), "sin nombres internos en el texto: %s" % card.band_text.text)
	card.free()


func test_las_estimaciones_van_marcadas() -> void:
	var card := _card("tigre")
	var drag: Dictionary = _tiles(card.tiles).filter(func(t: Dictionary) -> bool: return t.title == "Resistencia (D)")[0]
	assert_eq(drag.quality, "estimación", "la resistencia del tigre es una estimación")
	assert_true(String(drag.tip).begins_with("Fuente: ") and String(drag.tip).contains("Hoerner"), "con su fuente: %s" % drag.tip)
	var marked := 0
	for row: Array in card.sources_rows:
		if not (row[0] as Control).visible:
			continue
		var head: String = (row[1] as Label).text
		var src: String = (row[2] as Label).text
		assert_true(src.begins_with("Fuente: ") and src.length() > 12, "«%s» con su fuente" % head)
		if head.ends_with("· estimación"):
			marked += 1
	var est: int = card.st.sources().filter(func(r: Dictionary) -> bool: return r.quality == "estimate").size()
	assert_true(est >= 3, "hay estimaciones: %d" % est)
	assert_eq(marked, est, "todas marcadas en «Fuentes y estimaciones»")
	# unidad 4j: la lista es larga; empieza plegada, con el resumen del estado a la vista, y se despliega
	assert_false(card.sources_list.visible, "la lista empieza plegada")
	assert_eq(plain(card.sources_summary.text), card.st.sources_summary(), "con su resumen: %s" % card.sources_summary.text)
	assert_true(card.sources_summary.text.contains("estimaciones"), card.sources_summary.text)
	(card.sources_toggle as Button).pressed.emit()
	assert_true(card.sources_list.visible and card.sources_toggle.text == "Ocultar", "y se despliega")
	(card.sources_toggle as Button).pressed.emit()
	assert_false(card.sources_list.visible, "y se vuelve a plegar")
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	card.finish()
	var legend := ""
	for it: Array in card.energy.items:
		if (it[0] as Control).visible:
			legend += (it[2] as Label).text + "\n"
	assert_true(legend.contains("animal") and legend.contains("(estimación)"), "lo que se queda el animal, marcado: %s" % legend)
	card.free()


func test_en_el_telefono_va_en_una_columna() -> void:
	for c: Array in [[Vector2(390, 844), true], [Vector2(1240, 880), false]]:
		var size: Vector2 = c[0]
		var phone: bool = c[1]
		var host := Control.new()
		host.size = size
		add_to_tree(host)
		var s: Control = LabSection.instantiate()
		host.add_child(s)
		s.set_page(s.PAGE_CAR, false)
		await wait_frames(3)
		var card: Control = s.moving_car_card
		s.lab.set_claw(C("tigre"))
		s.refresh_now()
		for mode: String in ["hold", "impact"]:
			(card.mode_seg.buttons[mode] as Button).pressed.emit()
			s.refresh_now()
			await wait_frames(4)
			var where := "%dx%d %s" % [size.x, size.y, mode]
			var r: Rect2 = card.get_global_rect()
			assert_true(r.position.x >= -0.5 and r.end.x <= size.x + 0.5, "%s: la tarjeta cabe (%s)" % [where, r])
			assert_true(s.content.size.x <= size.x + 0.5, "%s: nada más ancho que la pantalla (%s px)" % [where, s.content.size.x])
			assert_eq(card.compact, phone, "%s: disposición de teléfono" % where)
			for ctl: Control in [card.view, card.speed, card.verdict_box, card.chart if mode == "hold" else card.energy]:
				var cr := ctl.get_global_rect()
				assert_true(cr.end.x <= size.x + 0.5, "%s: %s dentro de la pantalla (%s)" % [where, ctl.get_class(), cr])
		if phone:
			assert_true(s.columns.vertical, "una columna")
			for sl: Control in card._sliders():
				assert_eq((sl as Control).get("slider").custom_minimum_size.y, Card.TOUCH, "deslizador de tamaño táctil")
			for b: Control in [card.car_pills["coche"], card.maneuver_pills["frenada"], card.mode_seg.buttons["hold"]]:
				assert_true(b.get_combined_minimum_size().y >= Card.TOUCH, "botón de tamaño táctil (%s)" % b.get_combined_minimum_size())
		host.remove_child(s)
		s.free()


func test_la_velocidad_va_en_directo_sin_rehacer_la_grafica() -> void:
	var card := _card("aguila")
	var st: RefCounted = card.st
	card.step(16.0)
	card.chart._ensure_built()  # fuera del árbol no se dibuja: se construye a mano, como en su primer dibujo
	var builds: int = card.chart.builds
	var setup_v: int = st.setup_version
	card.speed.slider.drag_started.emit()
	for v in range(0, 151, 5):
		card.speed.slider.value_changed.emit(float(v))
		card.step(16.0)
		assert_eq(card.speed.display.text, "%s km/h" % v, "a %s km/h: el valor" % v)
		assert_eq(card.chart.v_kmh, st.at.vKmh, "a %s km/h: el punto de la gráfica" % v)
	assert_eq(st.setup_version, setup_v, "sin setup mientras se arrastra")
	card.chart._ensure_built()
	assert_eq(card.chart.builds, builds, "la gráfica no se rehace en cada fotograma")
	assert_false(st.heavy_fresh(), "lo caro espera a soltar el deslizador")
	card.speed.slider.drag_ended.emit(true)
	card.step(16.0)
	assert_true(st.heavy_fresh(), "al soltar, llega")
	# el aire mueve la gráfica en directo (with_air + curve, sin compute)
	card.temp.slider.value_changed.emit(35.0)
	card.step(16.0)
	assert_eq(card.chart.curve, st.chart, "la gráfica es la del aire nuevo")
	assert_true(plain(card.chart_air.text).contains("35 °C"), "con el aire como leyenda: %s" % card.chart_air.text)
	card.finish()
	card.step(16.0)
	assert_true(card.chart_air.text.contains("con el de referencia"), "y el despegue de referencia: %s" % card.chart_air.text)
	assert_eq(card.chart.ref_kmh, float(st.ref_detach().kmh), "la línea de referencia en la gráfica")
	card.free()


func test_con_hilo_la_tarjeta_dice_lo_mismo() -> void:
	var a := _card("oso", false)
	var b := _card("oso", true)
	for card: Control in [a, b]:
		card.st.set_posture("de_pie")
		card.st.set_maneuver("frenada")
		card.speed.slider.value_changed.emit(80.0)
		card.finish()
		card.step(16.0)
	assert_eq(_grid_rows(b.hold_report), _grid_rows(a.hold_report), "el informe, igual con hilo")
	for card: Control in [a, b]:
		(card.mode_seg.buttons["impact"] as Button).pressed.emit()
		(card.izone_pills["capo"] as Button).pressed.emit()
		card.finish()
		card.step(16.0)
	assert_eq(_grid_rows(b.impact_report), _grid_rows(a.impact_report), "el informe del golpe, igual con hilo")
	assert_eq(b.verdict_label.text, a.verdict_label.text, "y el veredicto")
	a.free()
	b.free()


func test_la_escena_quieta_no_se_redibuja() -> void:
	var host := Control.new()
	host.size = Vector2(700, 1200)
	add_to_tree(host)
	var card := _card("aguila")
	card.size = Vector2(680, 0)
	host.add_child(card)
	card.speed.slider.value_changed.emit(0.0)
	card.step(16.0)
	await wait_frames(3)
	var view: Control = card.view
	var d0: int = view.draws
	for i in 10:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.draws, d0, "coche parado: el dibujo no se repite")
	card.speed.slider.value_changed.emit(90.0)
	for i in 5:
		card.step(16.0)
		await wait_frames(1)
	assert_true(view.draws >= d0 + 4, "en marcha, el viento y la carretera se mueven (%d dibujos)" % (view.draws - d0))
	view.reduce_motion = true
	card.reduce_motion = true
	card.speed.slider.value_changed.emit(100.0)
	card.step(16.0)
	await wait_frames(2)
	var d1: int = view.draws
	for i in 10:
		card.step(16.0)
		await wait_frames(1)
	assert_eq(view.draws, d1, "con movimiento reducido, quieto")
	host.remove_child(card)
	card.free()


## Dentro del árbol, Godot recorta el valor de un deslizador al cambiarle el recorrido y emite value_changed (el fallo
## de la muela y de la fresa). La tarjeta pone recorrido y valor con las señales bloqueadas: ni el recorte ni el
## refresco llegan al ensayo.
func test_cambiar_el_recorrido_de_un_deslizador_no_cambia_el_ensayo() -> void:
	var card := _card("aguila")
	add_to_tree(card)
	await wait_frames(2)
	var slider: HSlider = card.speed.slider
	slider.value = 120.0  # dentro del árbol: emite, y el ensayo pasa a 120 km/h
	assert_eq(card.st.v_kmh, 120.0, "el deslizador mueve el ensayo")
	# el peligro: un deslizador del árbol conectado emite al recortar
	var probe := HSlider.new()
	probe.max_value = 150.0
	add_to_tree(probe)
	probe.value = 120.0
	var hits := [0]
	probe.value_changed.connect(func(_v: float) -> void: hits[0] += 1)
	probe.max_value = 50.0
	assert_eq(hits[0], 1, "Godot recorta el valor y emite dentro del árbol")
	# la tarjeta: recorrido nuevo que recorta, sin que el ensayo se entere
	var count := [0]
	slider.value_changed.connect(func(_v: float) -> void: count[0] += 1)
	Card.set_slider(slider, 0.0, 50.0, 30.0)
	assert_eq(slider.value, 30.0, "recorrido y valor puestos")
	assert_eq(count[0], 0, "sin emitir")
	assert_eq(card.st.v_kmh, 120.0, "el ensayo sigue a 120 km/h")
	# y el refresco de la tarjeta pone todos sus deslizadores igual, sin emitir
	var lv: int = card.st.live_version
	card._paint_inputs()
	card._paint_setup()
	assert_eq(count[0], 0, "el refresco no emite")
	assert_eq(slider.value, 120.0, "vuelve a su recorrido y a su valor")
	assert_eq(card.st.live_version, lv, "y no cambia el ensayo")
	# vigilancia: nadie más toca min_value, max_value ni value de un deslizador
	var code := code_only(FileAccess.get_file_as_string("res://app/lab/moving_car_card.gd"))
	var at := code.find("static func set_slider(")
	var body := code.substr(at, code.find("\nfunc ", at + 1) - at) if code.find("\nfunc ", at + 1) > 0 else code.substr(at)
	for prop: String in [".min_value =", ".max_value =", ".value ="]:
		assert_eq(code.count(prop), body.count(prop), "%s solo en set_slider" % prop)


func test_la_interfaz_no_calcula_fisica() -> void:
	for f: String in UI_FILES:
		var raw := FileAccess.get_file_as_string(f)
		var code := code_only(raw)
		for call: String in ["MovingCar.setup(", "MovingCar.at_speed(", "MovingCar.hold_report(", "MovingCar.impact(", "MovingCar.detach(",
				"MovingCar.detach_verdict(", "MovingCar.curve(", "MovingCar.with_air(", "MovingCar.max_braking_g(", "MovingCar.energy_balance(",
				"MovingCar.dent_of(", "MovingCar.windshield_", "MovingCar.air_density(", "MovingCar.air_of(", "MovingCar._", "Physics.",
				"compute(", "ClawsV2.", "9.807", "9.81", "3.6", "0.5 * rho", "js_pow("]:
			assert_false(code.contains(call), "%s no puede usar %s" % [f.get_file(), call])
		for fmt: String in ["%.1f", "%.2f", "%.0f", "%d km"]:
			assert_false(raw.contains(fmt), "%s: números con Js o Format, no con %s" % [f.get_file(), fmt])
		assert_eq(RegEx.create_from_string("(?<![\\w.])(str|round)\\(").search_all(code).size(), 0, "%s: sin str() ni round()" % f.get_file())
	# el estado es de core: sin nodos
	var state := code_only(FileAccess.get_file_as_string("res://core/lab/moving_car_state.gd"))
	assert_true(state.contains("extends RefCounted"), "el estado no es un nodo")
	for bad: String in ["get_tree(", "add_child(", "get_node(", "queue_redraw("]:
		assert_false(state.contains(bad), "el estado no toca nodos: %s" % bad)


## Coste por fotograma con el deslizador de la velocidad en movimiento (en el hilo principal: at_speed, el refresco de la
## tarjeta y el dibujo) y el del golpe en su hilo, con la tarjeta en el árbol. Lo apunta en la salida; falla solo si
## pasa del presupuesto de un fotograma a 60 Hz.
func test_coste_por_fotograma() -> void:
	var host := Control.new()
	host.size = Vector2(700, 1400)
	add_to_tree(host)
	var card := _card("aguila", true)
	card.size = Vector2(680, 0)
	host.add_child(card)
	await wait_frames(3)
	var slider: HSlider = card.speed.slider
	var step_us: Array = []
	var live_us: Array = []
	var draw_us: Array = []
	slider.drag_started.emit()
	for i in 60:
		slider.value = float(i) * 2.5
		var t0 := Time.get_ticks_usec()
		card.step(16.0)
		step_us.append(Time.get_ticks_usec() - t0)
		live_us.append(card.st.last_live_us)
		await wait_frames(1)
		draw_us.append(card.view.last_draw_us)
	slider.drag_ended.emit(true)
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	card.lab.set_claw(C("tigre"))
	card.refresh()
	card.finish()
	var hits: int = card.st.hit_version
	var impact_step: Array = []
	slider.drag_started.emit()
	for i in 60:
		slider.value = 30.0 + float(i)
		var t0 := Time.get_ticks_usec()
		card.step(16.0)
		impact_step.append(Time.get_ticks_usec() - t0)
		await wait_frames(1)
	slider.drag_ended.emit(true)
	card.finish()
	var during: int = card.st.hit_version - hits - 1
	var avg := func(a: Array) -> int: return int(a.reduce(func(s: int, x: int) -> int: return s + x, 0) / maxi(a.size(), 1))
	print("    (info) coche en marcha, arrastrando la velocidad: %s µs de media por fotograma en el hilo principal (máx. %s; at_speed %s µs; dibujo %s µs); con el golpe, %s µs por fotograma y impact() en su hilo %s µs (%s resultados durante el arrastre)" % [
		avg.call(step_us), step_us.max(), avg.call(live_us), avg.call(draw_us), avg.call(impact_step), card.st.last_heavy_us, during])
	assert_true(avg.call(step_us) < 16700, "cabe en un fotograma a 60 Hz: %s µs" % avg.call(step_us))
	assert_true(avg.call(impact_step) < 16700, "el golpe no para la interfaz: %s µs" % avg.call(impact_step))
	assert_true(during >= 1, "el golpe se ve mientras se arrastra (%d)" % during)
	host.remove_child(card)
	card.free()


## Unidad 4d cableada con los nombres de la guía (§9.10): el material de las garras y el animal asustado en los dos modos;
## el casuario, solo en el golpe (la opción de quedarse encima, desactivada y con su porqué) y con su sexo.
func test_lo_de_la_unidad_4d_esta_cableado() -> void:
	var card := _card("tigre")
	assert_eq(card.inlay_pills.size(), Catalog.INLAYS.size(), "un material por incrustación del catálogo")
	assert_eq((card.inlay_pills["none"] as Button).text, "Queratina", "«none» es la queratina")
	(card.inlay_pills["zafiro"] as Button).pressed.emit()
	assert_eq(card.st.inlay, "zafiro", "el material va al estado")
	assert_true((card.inlay_pills["zafiro"] as Pill).button_pressed, "y queda marcado")
	assert_eq(card.inlay_note.text, card.st.inlay_note(), "con su nota del estado: %s" % card.inlay_note.text)
	card.defense_pill.pressed.emit()
	assert_true(card.st.defense, "asustado")
	card.finish()
	card.step(16.0)
	var rows := _grid_rows(card.hold_report)
	assert_true(rows.any(func(r: Array) -> bool: return r[0] == "Defensa"), "la fila Defensa del informe")
	var t := _tiles(card.tiles).filter(func(x: Dictionary) -> bool: return x.title == "Fuerza de defensa")
	assert_eq(t.size(), 1, "la ficha de la fuerza de defensa")
	assert_true(String(t[0].sub).contains("banda"), "con su banda: %s" % t[0].sub)
	assert_eq(t[0].quality, "estimación", "estimación, marcada")
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	(card.izone_pills["puerta"] as Button).pressed.emit()
	card.finish()
	card.step(16.0)
	var ir := _grid_rows(card.impact_report)
	assert_true(ir.any(func(r: Array) -> bool: return r[0] == "Garras"), "la fila Garras (la rotura del zafiro)")
	assert_true(ir.any(func(r: Array) -> bool: return r[0] == "Defensa"), "y la de la defensa")
	# el casuario: solo el golpe
	card.lab.set_claw(C("casuario"))
	card.refresh()
	card.finish()
	card.step(16.0)
	assert_true(card.main_box.visible, "el casuario tiene tarjeta")
	assert_eq(card.st.mode, "impact", "en el golpe")
	assert_true((card.mode_seg.buttons["hold"] as Button).disabled, "«Encima del coche», desactivado")
	assert_eq((card.mode_seg.buttons["hold"] as Button).tooltip_text, MC.HOLD_NO_REASON, "con su porqué")
	assert_true(card.hold_no.visible and card.hold_no.text.contains(MC.HOLD_NO_REASON), "y dicho en la tarjeta")
	assert_true(card.sex_box.visible, "con su sexo")
	(card.sex_seg.buttons["macho"] as Button).pressed.emit()
	card.finish()
	card.step(16.0)
	assert_eq(card.st.sex, "macho", "el sexo va al estado")
	assert_true(_grid_rows(card.impact_report).any(func(r: Array) -> bool: return r[0] == "Patada"), "la fila Patada")
	var zones: Array = card.izone_pills.keys().filter(func(id: String) -> bool: return (card.izone_pills[id] as Control).visible)
	assert_eq(zones, MC.KICK_ZONES, "solo lo que tiene a la altura de las patas")
	card.free()


## Los experimentos: un botón por experimento, que carga el ensayo entero (y el animal del banco); «aire», solo encima.
func test_experimentos_de_un_clic() -> void:
	var card := _card("aguila")
	assert_eq(card.experiment_pills.size(), MCS.EXPERIMENTS.size(), "un botón por experimento")
	for e: Dictionary in MCS.EXPERIMENTS:
		assert_eq((card.experiment_pills[e.id] as Button).text, String(e.name), "con su nombre")
		assert_eq((card.experiment_pills[e.id] as Button).tooltip_text, MCS.experiment_tip(e.id), "y su ayuda del estado")
	(card.experiment_pills["oso_frenada"] as Button).pressed.emit()
	assert_eq(String(card.lab.claw.id), "oso", "el banco cambia al oso")
	assert_true(card.st.experiment_matches("oso_frenada"), "el estado carga el experimento")
	assert_true((card.experiment_pills["oso_frenada"] as Pill).button_pressed, "y su botón queda marcado")
	card.refresh()
	card.finish()
	card.step(16.0)
	assert_true(card.st.experiment_matches("oso_frenada"), "refrescar desde el banco no lo deshace")
	assert_eq(card.speed.display.text, "90 km/h", "el deslizador, a su velocidad")
	(card.experiment_pills["aire"] as Button).pressed.emit()
	assert_eq([card.st.temp_c, card.st.altitude_m], [35.0, 2000.0], "el mismo, a 35 °C y 2000 m")
	card.finish()
	card.step(16.0)
	assert_eq(card.temp.display.text, "35 °C", "y el deslizador de la temperatura")
	(card.experiment_pills["casuario_puerta"] as Button).pressed.emit()
	card.refresh()
	card.finish()
	card.step(16.0)
	assert_eq(card.st.mode, "impact", "la patada, en el golpe")
	assert_false((card.experiment_pills["aire"] as Control).visible, "«aire» no se enseña en el golpe")
	# unidad 4p: la patada abolla la puerta y la página del coche da el logro «Abollado en marcha» (Lab.BADGES_V2)
	assert_true(card.st.hit.dent.visible, "la patada deja una abolladura que se ve")
	assert_true(card.lab.badges.has("abollado"), "y con ella, el logro del coche en marcha")
	card.free()


## El porqué, el «¿sabías que…?» (con su fuente y otro dato con cada pulsación) y la moraleja salen del estado.
func test_el_porque_los_datos_y_la_moraleja() -> void:
	var card := _card("aguila")
	card.step(16.0)
	assert_eq(plain(card.why_label.text), "¿Por qué? " + card.st.why_text(), "el porqué del estado")
	assert_eq(plain(card.moral_label.text), "Moraleja: " + card.st.moral(), "la moraleja del estado")
	var facts: Array = card.st.facts()
	assert_eq(plain(card.fact_text.text), String(facts[0].text), "el primer dato")
	assert_true(card.fact_source.text.contains(String(facts[0].source)), "con su fuente: %s" % card.fact_source.text)
	card.fact_next.pressed.emit()
	assert_eq(plain(card.fact_text.text), String(facts[1].text), "«Otro dato» pasa al siguiente")
	for i in facts.size():
		card.fact_next.pressed.emit()
	assert_eq(plain(card.fact_text.text), String(facts[(facts.size() + 1) % facts.size()].text), "y vuelve a empezar")
	# con una estimación, se dice
	var est: Array = facts.filter(func(f: Dictionary) -> bool: return f.quality == "estimate")
	assert_false(est.is_empty(), "hay datos estimados")
	while plain(card.fact_text.text) != String(est[0].text):
		card.fact_next.pressed.emit()
	assert_true(card.fact_source.text.begins_with("Estimación."), "marcado como estimación: %s" % card.fact_source.text)
	card.free()


## El ajuste por palabras corta tras la barra de una unidad («ni a 400 km/» y «h» en el renglón siguiente) y entre el
## número y su unidad: la tarjeta los pega (Card.nb) sin cambiar lo que se lee. Con el ajuste de las etiquetas
## (AUTOWRAP_WORD_SMART) y la letra de los párrafos, a muchos anchos; sin pegar, el corte existe.
func test_las_unidades_no_se_parten() -> void:
	var txt := "¿Por qué? Nada la suelta: ni a 400 km/h, el tope de la búsqueda; con 0.899 kg/m³ de aire y 8.8 m/s² de frenada hacen falta 22 N y el golpe lleva 11.7 kJ."
	var glued := Card.nb(txt)
	assert_eq(plain(glued), txt, "se lee igual")
	assert_true(glued != txt, "con las unidades pegadas")
	var font: Font = AppTheme.get_theme().get_font("font", "Body")
	var cut := 0
	for w in range(120, 420, 2):
		for t: String in [txt, glued]:
			var p := TextParagraph.new()
			p.add_string(t, font, 12)
			p.width = float(w)
			p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			for i in p.get_line_count() - 1:
				var r := p.get_line_range(i)
				var line := plain(t.substr(r.x, r.y - r.x)).strip_edges()
				var bad := line.ends_with("/") or line.ends_with("400") or line.ends_with("0.899") or line.ends_with("8.8") \
				or line.ends_with("22") or line.ends_with("11.7")
				if t == glued:
					assert_false(bad, "a %d px, un renglón acaba en «%s»" % [w, line])
				elif bad:
					cut += 1
	assert_true(cut > 0, "sin pegar, alguno se parte")
	assert_eq(Card.nb("carga 24 % con 2 garras a 2000 metros"), "carga 24\u00a0% con 2 garras a 2000 metros", "solo las unidades")
	assert_eq(Card.headline("DESPEGA A ~24 km/h"), Card.nb("DESPEGA A UNOS 24 km/h"), "el rótulo, también pegado")


## El golpe suena al llegar al panel (MovingCarView.contact) con el efecto del banco que elige el estado; con
## movimiento reducido, al llegar el golpe; mientras se arrastra, no.
func test_el_golpe_suena_al_llegar() -> void:
	var played: Array = []
	var card := _card("tigre")
	card.play_sfx = func(id: String, volume: float) -> void: played.append([id, volume])
	(card.mode_seg.buttons["impact"] as Button).pressed.emit()
	(card.izone_pills["puerta"] as Button).pressed.emit()
	card.finish()
	card.step(16.0)
	assert_eq(played.size(), 0, "aún no ha llegado al panel")
	for i in 60:
		card.step(16.0)
	assert_eq(played, [[card.st.impact_sfx(), LabState.DEFAULT_VOLUME]], "suena una vez, al llegar: %s" % [played])
	assert_eq(String(played[0][0]), "scratch-metal", "los surcos hasta el metal")
	played.clear()
	card.reduce_motion = true
	card.view.reduce_motion = true
	card.st.set_impact("animal_kmh", 50.0)
	card.finish()
	card.step(16.0)
	assert_eq(played.size(), 1, "con movimiento reducido, en cuanto llega el golpe")
	played.clear()
	card.st.set_dragging(true)
	card.animal_speed.slider.value_changed.emit(30.0)
	for i in 30:
		card.st.poll()
		card.step(16.0)
	assert_eq(played.size(), 0, "mientras se arrastra, en silencio")
	card.free()


## Lo que pidió la 4i-B2 para la tarjeta (unidad 4j): las dos variantes del velocirraptor bajo su píldora (la de cine por
## defecto, la reconstrucción a un clic, con la píldora del animal marcada en las dos), la ficción en su color (nunca como
## un dato ni como una estimación), el deslizador «Afilado» solo con garras reforjadas (con los textos del estado) y, en un
## salto desde la carretera, sin el deslizador de la caída.
func test_lo_que_pidio_la_4i_b2() -> void:
	var card := _card("velociraptor_pelicula")
	assert_true(card.main_box.visible and card.variant_box.visible, "el velocirraptor, con sus variantes")
	var shown: Array = card.variant_pills.keys().filter(func(id: String) -> bool: return (card.variant_pills[id] as Control).visible)
	assert_eq(shown, card.st.variants().map(func(v: Dictionary) -> String: return v.id), "las del estado: %s" % [shown])
	assert_eq((card.variant_pills["velociraptor_pelicula"] as Button).text, "De cine (ficción)", "la de cine")
	assert_eq((card.variant_pills["velociraptor"] as Button).text, "Reconstrucción (datos)", "y la reconstrucción")
	assert_true((card.variant_pills["velociraptor_pelicula"] as Pill).button_pressed, "la de cine, por defecto")
	assert_true((card.animal_pills["velociraptor_pelicula"] as Pill).button_pressed, "con la píldora del animal marcada")
	(card.variant_pills["velociraptor"] as Button).pressed.emit()
	card.refresh()
	card.finish()
	assert_eq([String(card.st.claw.id), String(card.lab.claw.id)], ["velociraptor", "velociraptor"], "la reconstrucción, en el estado y en el banco")
	assert_true((card.variant_pills["velociraptor"] as Pill).button_pressed, "marcada")
	assert_false((card.variant_pills["velociraptor_pelicula"] as Pill).button_pressed, "y la de cine, no")
	assert_true((card.animal_pills["velociraptor_pelicula"] as Pill).button_pressed, "la píldora del animal sigue marcada")
	card.lab.set_claw(C("tigre"))
	card.refresh()
	assert_false(card.variant_box.visible, "el tigre no tiene variantes")
	# la ficción, en su color
	assert_eq(String(Card.QUALITY_COLOR.ficcion), "rose", "la ficción, en rosa")
	assert_false(["mint", "ice", "gold", "dimmer"].has(String(Card.QUALITY_COLOR.ficcion)), "nunca como un dato ni como una estimación")
	(card.experiment_pills["velocirraptor_pelicula"] as Button).pressed.emit()
	card.refresh()
	card.finish()
	card.step(16.0)
	(card.sources_toggle as Button).pressed.emit()
	var fiction := 0
	for row: Array in card.sources_rows:
		if (row[0] as Control).visible and (row[1] as Label).text.ends_with("· ficción (película)"):
			fiction += 1
			assert_eq((row[1] as Label).get_theme_color("font_color"), Palette.color("rose"), "«%s», en rosa" % (row[1] as Label).text)
	assert_true(fiction >= 2, "la garra de película y las garras que golpean, como ficción: %d" % fiction)
	# en el salto no hay caída sobre el panel
	assert_eq(card.st.mode, "impact", "el experimento: el golpe")
	assert_false(card.drop.visible, "un salto desde la carretera: sin el deslizador de la caída")
	card.lab.set_claw(C("tigre"))
	card.refresh()
	(card.izone_pills["techo"] as Button).pressed.emit()
	card.finish()
	assert_true(card.drop.visible, "el tigre cae sobre el techo: con la caída")
	# el afilado: solo con garras reforjadas
	assert_false(card.sharp_box.visible, "con queratina no se afila")
	(card.inlay_pills["zafiro"] as Button).pressed.emit()
	card.finish()
	assert_true(card.sharp_box.visible, "con garras de zafiro, el deslizador «Afilado»")
	card.sharp.slider.value_changed.emit(0.5)
	card.finish()
	card.step(16.0)
	assert_eq(card.st.sharpness, 0.5, "el afilado va al estado")
	var v: Dictionary = card.st.sharpness_view()
	assert_eq(card.sharp.display.text, String(v.display), "su radio de punta: %s" % card.sharp.display.text)
	assert_eq(plain(card.sharp_note.text), String(v.note), "su nota")
	for key: String in ["pressure", "lateral"]:
		var parts: Array = card.sharp_bar_parts[key]
		assert_eq((parts[0] as Label).text, String(v[key].title), "la barra «%s»" % v[key].title)
		assert_eq(plain((parts[2] as Label).text), String(v[key].text), "con su texto")
		assert_near((parts[1] as Bar).level, float(v[key].level), 1e-12, 1e-12, "y su nivel")
	var marks: int = (v.marks as Array).size()
	assert_eq(card.sharp_items.filter(func(it: Array) -> bool: return (it[0] as Control).visible).size(), marks, "una marca por referencia")
	(card.inlay_pills["none"] as Button).pressed.emit()
	card.finish()
	assert_false(card.sharp_box.visible, "con queratina otra vez, oculto")
	card.free()


## En un teléfono (390 × 844) caben las variantes del velocirraptor, el deslizador «Afilado» con sus barras y su leyenda,
## la banda del golpe y el resumen de las fuentes: nada se sale de la pantalla.
func test_en_el_telefono_caben_las_variantes_y_el_afilado() -> void:
	var size := Vector2(390, 844)
	var host := Control.new()
	host.size = size
	add_to_tree(host)
	var s: Control = LabSection.instantiate()
	host.add_child(s)
	s.set_page(s.PAGE_CAR, false)
	await wait_frames(3)
	var card: Control = s.moving_car_card
	s.lab.set_claw(C("velociraptor_pelicula"))
	s.refresh_now()
	(card.experiment_pills["velocirraptor_pelicula"] as Button).pressed.emit()
	(card.inlay_pills["zafiro"] as Button).pressed.emit()
	card.finish()
	s.refresh_now()
	await wait_frames(4)
	assert_true(card.compact, "disposición de teléfono")
	assert_true(card.variant_box.visible and card.sharp_box.visible, "las variantes y el afilado se ven")
	var checked := 0
	for root: Control in [card.variant_box, card.sharp_box, card.band_text, card.sources_summary, card.impact_readings]:
		var stack: Array = [root]
		while not stack.is_empty():
			var c: Control = stack.pop_back()
			if not c.is_visible_in_tree():
				continue
			checked += 1
			var r := c.get_global_rect()
			assert_true(r.end.x <= size.x + 0.5, "%s dentro de la pantalla (%s)" % [c.get_class(), r])
			for ch: Node in c.get_children():
				if ch is Control:
					stack.append(ch)
	assert_true(checked > 20, "controles revisados: %d" % checked)
	for b: Control in card.variant_pills.values():
		if b.visible:
			assert_true(b.get_combined_minimum_size().y >= Card.TOUCH, "variante de tamaño táctil")
	assert_eq(card.sharp.slider.custom_minimum_size.y, Card.TOUCH, "el afilado, de tamaño táctil")
	host.remove_child(s)
	s.free()
