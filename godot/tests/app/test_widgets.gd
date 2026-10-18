## Piezas comunes de la interfaz: suavizado cubic-bezier, rejilla auto-fill, caja que pasa de fila a columna, caché
## de dibujos (rasteriza solo cuando cambian las entradas) y la animación del banco (la punta recorre la losa y el
## surco se revela con ella; en la punción baja, impacta y se retira). Mide también el coste de rasterizar.
extends "res://tests/case.gd"

const Ui = preload("res://app/common/ui.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const WrapBox = preload("res://app/common/wrap_box.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Bench = preload("res://app/lab/bench.gd")
const LabArt = preload("res://app/lab/lab_art.gd")
const ParamsCard = preload("res://app/lab/params_card.gd")
const Art = preload("res://core/lab/art.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Format = preload("res://core/shared/format.gd")


func test_cubic_bezier_como_css() -> void:
	assert_eq(Ui.cubic_bezier(0.25, 0.1, 0.25, 1.0, 0.0), 0.0)
	assert_eq(Ui.cubic_bezier(0.25, 0.1, 0.25, 1.0, 1.0), 1.0)
	# «ease» de CSS a mitad de tiempo: 0,8024 (valor de referencia de los navegadores)
	assert_near(Ui.cubic_bezier(0.25, 0.1, 0.25, 1.0, 0.5), 0.8024033877399112, 1e-4)
	# lineal
	assert_near(Ui.cubic_bezier(0.0, 0.0, 1.0, 1.0, 0.3), 0.3, 1e-6)
	var prev := -1.0
	for i in 101:
		var y := Ui.cubic_bezier(0.45, 0.05, 0.25, 1.0, i / 100.0)
		assert_true(y >= prev - 1e-9, "monótona")
		prev = y


func test_rejilla_auto_fill_y_caja_que_se_parte() -> void:
	var g := TileGrid.new(74.0, 8.0)
	assert_eq(g.columns_for(560.0 - 34.0), 6, "escritorio: las 6 formas de uña en una fila")
	assert_eq(g.columns_for(358.0 - 34.0), 4, "teléfono (390 px): 4 columnas de 74 px, como el auto-fill de la 1.x")
	assert_eq(g.columns_for(300.0), 3, "300 px: 3 columnas")
	assert_eq(g.columns_for(10.0), 1, "al menos una")
	g.free()
	var heights: Array[float] = [20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0]
	var out := TileGrid.arrange(326.0, heights, 74.0, 8.0, 8.0)
	assert_eq(out.columns, 4)
	var rects: Array = out.rects
	# 4 columnas de (326 - 24) / 4 px; filas de 23 y 26 px (la más alta de cada una) con 8 px entre ellas
	assert_near((rects[1] as Rect2).size.x, (326.0 - 24.0) / 4.0, 1e-9)
	assert_near((rects[4] as Rect2).position.y, 23.0 + 8.0, 1e-9)
	assert_near((rects[5] as Rect2).position.x, (326.0 - 24.0) / 4.0 + 8.0, 1e-9)
	assert_near(out.height, 23.0 + 8.0 + 26.0, 1e-9)
	var items := [
		{ "min": Vector2(200, 30), "expand": true, "ratio": 1.0, "fill": true, "end": false, "fill_v": false },
		{ "min": Vector2(150, 20), "expand": false, "ratio": 1.0, "fill": false, "end": false, "fill_v": false },
	]
	var row := WrapBox.arrange(400.0, items, 10.0, 6.0, 0.0, false, false)
	assert_true(row.row, "caben en fila")
	assert_near((row.rects[0] as Rect2).size.x, 400.0 - 150.0 - 10.0, 1e-9, 1e-9, "el que se expande se queda el sitio que sobra")
	assert_near((row.rects[1] as Rect2).position.y, 5.0, 1e-9, 1e-9, "centrados en vertical")
	var col := WrapBox.arrange(300.0, items, 10.0, 6.0, 0.0, false, false)
	assert_false(col.row, "no caben: uno debajo de otro")
	assert_near((col.rects[0] as Rect2).size.x, 300.0, 1e-9, 1e-9, "el que rellena ocupa todo el ancho")
	assert_near((col.rects[1] as Rect2).size.x, 150.0, 1e-9, 1e-9, "el otro, su ancho mínimo")
	assert_near((col.rects[1] as Rect2).position.y, 36.0, 1e-9)
	var eq := WrapBox.arrange(600.0, items, 14.0, 6.0, 514.0, true, true)
	assert_true(eq.row, "con row_min, en fila a partir de ese ancho")
	assert_near((eq.rects[0] as Rect2).size.x, (eq.rects[1] as Rect2).size.x, 1e-9, 1e-9, "equal: columnas iguales")
	assert_false(WrapBox.arrange(500.0, items, 14.0, 6.0, 514.0, true, true).row)
	var w := WrapBox.new()
	var a := Control.new()
	a.custom_minimum_size = Vector2(200, 30)
	var b := Control.new()
	b.custom_minimum_size = Vector2(150, 20)
	w.add_child(a)
	w.add_child(b)
	assert_near(w.get_combined_minimum_size().x, 200.0, 1e-9, 1e-9, "su mínimo es el del hijo más ancho, nunca la suma")
	w.free()


func test_fuerza_del_deslizador_como_la_1x() -> void:
	# setForce de la 1.x: décimas por debajo de 10 N, unidades por encima
	assert_eq(ParamsCard.force_from_slider(Format.f_to_t(3.2)), 3.2)
	assert_eq(ParamsCard.force_from_slider(Format.f_to_t(260.0)), 260.0)
	assert_eq(ParamsCard.force_from_slider(0.0), Format.FMIN)
	assert_eq(ParamsCard.force_from_slider(1.0), Format.FMAX)


func test_cache_de_dibujos_rasteriza_solo_si_cambian_las_entradas() -> void:
	var art := ArtCache.new()
	art.threaded = false
	var claw: Dictionary = Data.CLAWS[1]
	var view := { "viewBox": "0 0 100 132", "width": 100.0, "height": 132.0 }
	var make := Art.claw_art.bind(claw, { "uid": "t" })
	var t1 := art.texture("ci:t:tigre", make, view, 2.0)
	assert_true(t1 != null, "textura")
	assert_eq(t1.get_width(), 200, "a la escala pedida (×2)")
	assert_eq(art.rasterized, 1)
	assert_true(art.texture("ci:t:tigre", make, view, 2.0) == t1, "misma entrada: la misma textura, sin volver a rasterizar")
	assert_true(art.texture("ci:t:tigre", make, view, 2.004) == t1, "la escala se redondea a centésimas")
	assert_eq(art.rasterized, 1)
	var t3 := art.texture("ci:t:tigre", make, view, 3.0)
	assert_eq(t3.get_width(), 300, "otra escala: se rasteriza de nuevo…")
	assert_eq(art.svg("ci:t:tigre"), Svg_of(make, view), "… con el SVG ya guardado")
	assert_eq(art.meta("ci:t:tigre").tip, Art.claw_art(claw, { "uid": "t" }).tip, "guarda los datos del dibujo (tip)")
	# con hilos: la textura llega en un fotograma posterior, con art_ready
	var bg := ArtCache.new()
	var got: Array = []
	bg.art_ready.connect(func(k: String) -> void: got.append(k))
	assert_true(bg.texture("sw:madera", Art.surface_art.bind("madera", { "w": 120.0, "h": 34.0 }), { "viewBox": "0 0 120 34", "width": 120.0, "height": 34.0 }, 1.0) == null)
	assert_eq(bg.pending(), 1)
	bg.wait_all()
	assert_eq(got, ["sw:madera"])
	assert_eq(bg.pending(), 0)
	assert_true(bg.has_texture("sw:madera", 1.0))
	bg.dispose()
	art.dispose()


static func Svg_of(make: Callable, view: Dictionary) -> String:
	return preload("res://core/lab/svg.gd").scene_to_svg(make.call(), view)


func test_el_banco_revela_el_surco_con_la_punta_y_la_puncion_se_retira() -> void:
	var art := ArtCache.new()
	art.threaded = false
	var b := Bench.new()
	b.setup(art, "t")
	var target: Dictionary = Data.find_by_id(Data.TARGETS, "coche")
	var tool := { "claw": Data.find_by_id(Data.CLAWS, "tigre"), "geom": Data.GEOMS[3], "base": Data.BASES[0], "inlay": Data.INLAYS[0], "wet": false }
	var p := { "geom": tool.geom, "base": tool.base, "inlay": tool.inlay, "claw": tool.claw, "target": target, "force": 260.0, "length": 25.0,
		"type": Data.TYPES[1], "tear": false, "method": "rayado", "strike": false, "passes": 1.0, "wet": false }
	var res := Physics.compute(p)
	b.set_state({ "target": target, "res": null, "phase": "idle", "length": 25.0, "method": "rayado", "tool": tool, "run": 0 })
	b.set_state({ "target": target, "res": res, "phase": "running", "length": 25.0, "method": "rayado", "tool": tool, "run": 1 })
	var x2 := Bench.X1 + 70.0 + (25.0 / 60.0) * 222.0
	assert_near(b._pose.x, Bench.X1, 1e-6, 1e-6, "empieza en x1")
	assert_eq(b.reveal(), 0.0, "los extras aparecen al final")
	var xs: Array = []
	for i in 11:
		b.advance(110.0)
		xs.append(b._pose.x)
	assert_near(xs[-1], x2, 1e-6, 1e-6, "en 1,1 s llega a x2")
	for i in range(1, xs.size()):
		assert_true(xs[i] >= xs[i - 1], "la punta avanza sin volver atrás")
	assert_eq(b.reveal(), 1.0, "al final del recorrido, los extras a la vista")
	b.set_state({ "target": target, "res": res, "phase": "done", "length": 25.0, "method": "rayado", "tool": tool, "run": 1 })
	assert_false(b.is_animating())
	# punción con golpe: baja, impacta y se retira 14,5 unidades
	p.method = "puncion"
	p.strike = true
	var pr := Physics.compute(p)
	b.set_state({ "target": target, "res": pr, "phase": "running", "length": 25.0, "method": "puncion", "tool": tool, "run": 2 })
	assert_near(b._pose.y, Bench.GY - 34.0, 1e-6, 1e-6, "arriba antes de bajar")
	b.advance(900.0)
	assert_near(b._pose.y, Bench.GY + 1.5, 1e-6, 1e-6, "impacta en 0,9 s")
	b.set_state({ "target": target, "res": pr, "phase": "done", "length": 25.0, "method": "puncion", "tool": tool, "run": 2 })
	b.advance(500.0)
	assert_near(b._pose.y, Bench.GY + 1.5 - 14.5, 1e-6, 1e-6, "y se retira para que se vea la herida")
	# movimiento reducido: el banco salta al final
	b.reduce_motion = true
	b.set_state({ "target": target, "res": res, "phase": "running", "length": 25.0, "method": "rayado", "tool": tool, "run": 3 })
	assert_near(b._pose.x, x2, 1e-6, 1e-6, "sin animación")
	b.free()
	art.dispose()


func test_la_herramienta_del_banco_cabe_en_su_caja() -> void:
	# la punta de cada garra (colgando) y de la uña de perfil cae dentro de la caja que se rasteriza
	for c: Dictionary in Data.CLAWS:
		var a := LabArt.bench_tool(c, Data.GEOMS[0], Data.BASES[0], Data.INLAYS[0], false)
		assert_true(Bench.CLAW_VIEW.has_point(Vector2(a.tip.x, a.tip.y)), "punta de %s" % c.id)
	assert_true(Bench.NAIL_VIEW.has_point(Vector2.ZERO), "punta de la uña")


func test_tiempos_de_rasterizado() -> void:
	# construir + serializar + ThorVG, sin hilos, a ×2 (pantalla HiDPI): lo peor es la superficie del banco
	var art := ArtCache.new()
	art.threaded = false
	var t0 := Time.get_ticks_usec()
	for t: Dictionary in Data.TARGETS:
		art.texture("bench:" + t.id, LabArt.bench_base.bind(t.id), { "viewBox": "0 0 360 170", "width": 360.0, "height": 170.0 }, 2.0)
	var bench_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for c: Dictionary in Data.CLAWS:
		art.texture("ci:t" + c.id, Art.claw_art.bind(c, { "uid": "t" + c.id }), { "viewBox": "0 0 100 132", "width": 100.0, "height": 132.0 }, 1.0)
	var claw_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for t: Dictionary in Data.TARGETS:
		art.texture("bench:" + t.id, LabArt.bench_base.bind(t.id), { "viewBox": "0 0 360 170", "width": 360.0, "height": 170.0 }, 3.0)
	var rescale_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_eq(art.rasterized, Data.TARGETS.size() * 2 + Data.CLAWS.size())
	print("    (info) rasterizado: losa del banco %.1f ms de media (peor %.1f ms), ficha de garra %.1f ms; cambiar de escala (SVG ya hecho) %.1f ms" % [
		bench_ms / Data.TARGETS.size(), art.max_ms, claw_ms / Data.CLAWS.size(), rescale_ms / Data.TARGETS.size()])
	art.dispose()
