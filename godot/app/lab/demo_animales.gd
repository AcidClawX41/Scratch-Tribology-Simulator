## Galería de los animales del coche en marcha (unidades 4h y 4l), para revisar el modelado: todas las especies, en
## todas sus posturas y estados, a su tamaño real (el de MovingCar.BODIES, el mismo que da el estado a la vista) sobre un
## trozo de techo. Páginas:
##   1 · rapaces con las alas plegadas: quietas y con viento fuerte (plumaje erizado y agitado);
##   2 · rapaces asustadas y con las garras reforjadas;
##   3 · rapaces con las alas abiertas: con poca sustentación y con mucha (las alas se levantan);
##   4 · tigre y oso, agazapados y de pie, quietos y asustados;
##   5 · casuario (hembra y macho, quieto y pateando) y los dos velocirraptores (reconstrucción y de película);
##   6 · garras reforjadas de colores: melladas, partidas y dobladas;
##   7 · todos juntos al tamaño de la tarjeta (≈ 87 px/m en el escritorio), como se ven sobre el coche;
##   8-11 · primeros planos (cada animal a su escala): el casuario, el tigre y el oso, las rapaces y los velocirraptores,
##          de lado y de tres cuartos (la vista gira la raíz en un golpe de costado), con el salto, la patada y las garras;
##   12-13 · detalles: los pies, las garras y las cabezas del casuario y de los velocirraptores;
##   14 · los cuerpos de la cetrería en el coche (unidad 4r, animals/hd3d.gd: la ficha «hd»), todos a la escala de la página;
##   15 · sus garras de cerca, con los metales de la biblioteca (el acero y el oro reflejan la carretera: unidad 5q).
## En cada página la escala es la misma para todos (la de la página o, si alguno no cabe en su celda, la mayor con la que
## caben todos); en los primeros planos, cada uno a la suya.
## El velocirraptor aún no está en MovingCar (llega en la 4i-B2): su tamaño sale de core/lab/velociraptor.gd (2,07 m de
## largo y 0,5 m de cadera; «solo dibujo»); el de película, provisional (0,87 m de cadera y 3,4 m, Deinonychus).
## Captura:   node godot/tools/godot.mjs capture res://app/lab/demo_animales.tscn --frames=40 --out=<carpeta> -- --pagina=N
##            (sin --pagina, cada página dura PAGE_S s; con --phone, al tamaño de un teléfono).
## Métricas: al acabar cada página escribe en la salida lo que tardó en construirse y en dibujarse.
extends Control

const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const Animal3D = preload("res://app/lab/animals/animal3d.gd")
const HdAnimal = preload("res://app/lab/animals/hd3d.gd")
const CarScene = preload("res://app/lab/car3d/car_scene.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const Js = preload("res://core/shared/js.gd")

const RAPTORS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre"]
const NAMES := { "aguila": "Águila real", "arpia": "Arpía", "halcon": "Halcón peregrino", "buho": "Búho real", "lechuza": "Lechuza común",
	"buitre": "Buitre leonado", "tigre": "Tigre", "oso": "Oso pardo", "casuario": "Casuario", "velociraptor": "Velocirraptor",
	"velociraptor_pelicula": "Velocirraptor de película (ficción)" }
## Tamaño provisional del de película (m): el de Deinonychus, hasta que MovingCar.BODIES traiga el suyo (4i-B2).
const FILM_SIZE := { "heightM": 0.87, "lengthM": 3.4, "spanM": 0.0 }
const PAGE_S := 4.0
## Color del techo: el del coche moderno (Catalog.TARGETS «coche»).
const ROOF := "#7E2B3A"

var _page := -1
var _only := -1
var _t := 0.0
var _page_t := 0.0
var _cells: Array = []  # [{ id, posture, state, label, rig, rect, pose, ppm }]
var _ppm := 100.0
var _own_scale := false
var _title := ""
var _cache := {}
var _build_us := 0
var _draw_us: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pagina="):
			_only = clampi(int(a.substr(9)) - 1, 0, _pages().size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_rebuild)
	_show(_only if _only >= 0 else 0)


func _process(delta: float) -> void:
	_t += delta
	_page_t += delta
	if _only < 0 and _page_t >= PAGE_S:
		_report()
		_show((_page + 1) % _pages().size())
	queue_redraw()


## Tamaño del animal (alto, largo, envergadura; m): el de MovingCar.BODIES, lo mismo que MovingCarState.draw_size().
static func size_of(id: String) -> Vector3:
	var d := size_dict(id)
	return Vector3(d.heightM, d.lengthM, d.spanM)


## El mismo tamaño en números de 64 bits (los de Vector3 son de 32: para los rótulos, «0.8», no «0.800000011920929»).
static func size_dict(id: String) -> Dictionary:
	var b: Variant = MovingCar.body_of(id)
	if b != null:
		return { "heightM": float(b.height_m), "lengthM": float(b.length_m), "spanM": float(b.span_m.value) if b.has("span_m") else 0.0 }
	if id == "velociraptor_pelicula":
		return FILM_SIZE
	var body: Dictionary = Velociraptor.BODY
	return { "heightM": float(body.hipM.value), "lengthM": float(body.lengthM.value), "spanM": 0.0 }


## Páginas: [título, px/m (escritorio; 0 = cada uno a su escala), celdas [id, postura, estado, rótulo]]. El estado son
## fichas separadas por «+»: quieto, viento[:m/s], asustado, alas:sustentación, patada[:k], salto[:k], reforjada:material, hd
## [:mella|parte|dobla], macho, giro:grados (tres cuartos: la raíz girada hacia quien mira).
static func _pages() -> Array:
	var p1: Array = []
	for id: String in RAPTORS:
		p1.append([id, "plegadas", "quieto", "quieta"])
		p1.append([id, "plegadas", "viento:30", "viento a 30 m/s"])
	var p2: Array = []
	for id: String in RAPTORS:
		p2.append([id, "plegadas", "asustado", "asustada"])
		p2.append([id, "plegadas", "reforjada:tungsteno", "tungsteno"])
	var p3: Array = []
	for id: String in RAPTORS:
		p3.append([id, "abiertas", "alas:0.2", "poca sustentación"])
		p3.append([id, "abiertas", "alas:1.0", "casi despega"])
	var p4: Array = []
	for id: String in ["tigre", "oso"]:
		for post: String in ["tumbado", "de_pie"]:
			p4.append([id, post, "quieto", "agazapado" if post == "tumbado" else "de pie"])
			p4.append([id, post, "asustado", ("agazapado" if post == "tumbado" else "de pie") + ", asustado"])
	var p5: Array = [["casuario", "de_pie", "quieto", "hembra"], ["casuario", "de_pie", "macho", "macho"],
		["casuario", "de_pie", "patada", "hembra, pateando"], ["velociraptor", "tumbado", "quieto", "agazapado"],
		["velociraptor", "tumbado", "asustado", "reconstrucción asustada"],
		["velociraptor_pelicula", "tumbado", "quieto", "ficción"], ["velociraptor_pelicula", "tumbado", "asustado", "ficción, amenazante"]]
	var p6: Array = [["aguila", "plegadas", "reforjada:zafiro", "zafiro"], ["aguila", "plegadas", "reforjada:diamante:mella", "diamante, mellada"],
		["tigre", "tumbado", "reforjada:acero:dobla", "acero, doblada"], ["tigre", "tumbado", "reforjada:cuarzo:parte", "cuarzo, partida"],
		["oso", "tumbado", "reforjada:oro", "oro"], ["casuario", "de_pie", "reforjada:tungsteno", "tungsteno"],
		["velociraptor", "tumbado", "reforjada:zafiro", "zafiro"], ["buitre", "plegadas", "reforjada:moissanita", "moissanita"]]
	var p7: Array = []
	for id: String in RAPTORS + ["tigre", "oso", "casuario", "velociraptor", "velociraptor_pelicula"]:
		p7.append([id, AnimalArt.postures_of(id)[0], "quieto", ""])
	var p8: Array = [["casuario", "de_pie", "quieto", "hembra, de lado"], ["casuario", "de_pie", "giro:-40", "hembra, de tres cuartos"],
		["casuario", "de_pie", "patada+giro:-25", "la patada, con la daga delante"], ["casuario", "de_pie", "macho+giro:40", "macho, de tres cuartos"]]
	var p9: Array = [["tigre", "de_pie", "giro:-35", "de pie, de tres cuartos"], ["tigre", "tumbado", "asustado+giro:-20", "agazapado, garras fuera"],
		["tigre", "de_pie", "salto", "el salto"], ["oso", "de_pie", "giro:-35", "de pie, de tres cuartos"], ["oso", "tumbado", "asustado", "tumbado, asustado"],
		["oso", "de_pie", "salto", "el golpe"]]
	var p10: Array = [["aguila", "plegadas", "giro:-40", "de tres cuartos"], ["aguila", "abiertas", "alas:0.8+giro:-30", "alas abiertas, tres cuartos"],
		["arpia", "plegadas", "giro:-35+asustado", "asustada: erizada, talones fuera"], ["buho", "plegadas", "giro:-30", "búho real"],
		["lechuza", "plegadas", "viento:30+giro:-30", "con viento"], ["buitre", "abiertas", "alas:0.5+giro:-25", "buitre, alas abiertas"]]
	var p11: Array = [["velociraptor", "de_pie", "quieto", "reconstrucción, de pie (la cadera del estado)"],
		["velociraptor", "tumbado", "giro:-35", "reconstrucción, agazapado, tres cuartos"], ["velociraptor", "tumbado", "salto", "el salto, con las hoces"],
		["velociraptor_pelicula", "de_pie", "quieto", "ficción, de pie"], ["velociraptor_pelicula", "tumbado", "giro:-35", "ficción, tres cuartos"],
		["velociraptor_pelicula", "tumbado", "asustado+salto", "ficción, el salto"]]
	var p12: Array = [["casuario", "de_pie", "zoom:garra:0.42", "el pie: tres dedos que apoyan y la daga"],
		["casuario", "de_pie", "zoom:garra:0.42+giro:-45", "el pie de tres cuartos"], ["casuario", "de_pie", "zoom:eye:0.4", "la cabeza y el casco"],
		["casuario", "de_pie", "zoom:eye:0.4+giro:-50", "la cabeza de tres cuartos"],
		["casuario", "de_pie", "zoom:garra:0.42+giro:-30+reforjada:tungsteno", "la daga, de carburo de tungsteno"],
		["tigre", "tumbado", "zoom:garra:0.3+giro:-30+reforjada:oro:mella", "zarpa de oro, mellada"]]
	var p13: Array = [["velociraptor", "de_pie", "zoom:garra:0.3", "el pie: la hoz levantada"], ["velociraptor", "de_pie", "zoom:eye:0.34", "la cabeza, de lado"],
		["velociraptor", "tumbado", "zoom:eye:0.42+giro:-35+asustado", "asustado, de tres cuartos"],
		["velociraptor_pelicula", "de_pie", "zoom:garra:0.5", "ficción: el pie y la hoz"], ["velociraptor_pelicula", "de_pie", "zoom:eye:0.6", "ficción: la cabeza"],
		["velociraptor_pelicula", "tumbado", "zoom:eye:0.75+giro:-35+asustado", "ficción: amenazante, tres cuartos"],
		["velociraptor", "de_pie", "zoom:garra:0.3+giro:-30+reforjada:zafiro", "la hoz, de zafiro"],
		["velociraptor_pelicula", "de_pie", "zoom:garra:0.5+giro:-30+reforjada:acero:dobla", "ficción: hoz de acero, doblada"]]
	var p14: Array = []
	for id: String in RAPTORS + ["tigre", "oso", "velociraptor", "velociraptor_pelicula"]:
		p14.append([id, AnimalArt.postures_of(id)[0], "hd", "cetrería"])
	p14.append(["tigre", "de_pie", "hd", "cetrería, de pie"])
	p14.append(["oso", "de_pie", "hd", "cetrería, de pie"])
	var p15: Array = [["tigre", "de_pie", "hd+zoom:garra:0.25+giro:-30+reforjada:acero", "cetrería: zarpa de acero"],
		["oso", "tumbado", "hd+zoom:garra:0.3+giro:-30+reforjada:oro", "cetrería: zarpa de oro"],
		["aguila", "plegadas", "hd+zoom:garra:0.25+giro:-30+reforjada:tungsteno", "cetrería: talones de tungsteno"],
		["velociraptor", "tumbado", "hd+zoom:garra:0.25+giro:-30+reforjada:zafiro", "cetrería: la hoz de zafiro"],
		["tigre", "de_pie", "hd+zoom:garra:0.25+giro:-30", "cetrería: queratina"],
		["buho", "plegadas", "hd+zoom:eye:0.3+giro:-40", "cetrería: la cabeza"]]
	return [
		["Rapaces con las alas plegadas: quietas y con viento fuerte", 210.0, p1],
		["Rapaces asustadas y con garras de carburo de tungsteno", 210.0, p2],
		["Rapaces con las alas abiertas: se levantan con la sustentación", 105.0, p3],
		["Tigre y oso pardo: agazapados y de pie, quietos y asustados", 120.0, p4],
		["Casuario (hembra y macho, pateando) y velocirraptores", 125.0, p5],
		["Garras reforjadas: su color, melladas, partidas y dobladas", 130.0, p6],
		["Todos a la escala de la tarjeta (87 px/m), sobre el techo", 87.0, p7],
		["Primer plano: el casuario", 0.0, p8],
		["Primer plano: el tigre y el oso pardo", 0.0, p9],
		["Primer plano: las rapaces", 0.0, p10],
		["Primer plano: los velocirraptores", 0.0, p11],
		["Detalles: pies, garras y cabezas", 0.0, p12],
		["Detalles: los velocirraptores", 0.0, p13],
		["Los cuerpos de la cetrería en el coche (4r)", 110.0, p14],
		["Los cuerpos de la cetrería: las garras de cerca", 0.0, p15],
	]


func _show(i: int) -> void:
	_page = i
	_page_t = 0.0
	_draw_us.clear()
	_rebuild()


## Coloca las celdas de la página y construye sus animales (una vez por página y tamaño).
func _rebuild() -> void:
	if _page < 0 or size.x <= 0.0:
		return
	var page: Array = _pages()[_page]
	_title = "%s · %s" % [Ui.num(_page + 1), page[0]]
	var cells: Array = page[2]
	var phone := size.x < 700.0
	var cols := 2 if phone else (4 if cells.size() > 6 else 3)
	if _page == 6:
		cols = 2 if phone else 5
	if cells.size() == 4 and not phone:
		cols = 2
	var rows := ceili(float(cells.size()) / float(cols))
	var top := 58.0
	var cw := (size.x - 24.0) / float(cols)
	var ch := (size.y - top - 12.0) / float(rows)
	_own_scale = float(page[1]) <= 0.0
	_ppm = float(page[1]) * (0.55 if phone else 1.0)
	if _page == 6:
		_ppm = float(page[1]) * (0.62 if phone else 1.0)
	for cell: Dictionary in _cells:
		remove_child(cell.container)
		(cell.container as Node).queue_free()
	_cells.clear()
	var t0 := Time.get_ticks_usec()
	var built: Array = []
	for k in cells.size():
		var c: Array = cells[k]
		var id: String = c[0]
		var state: String = c[2]
		var opts := {}
		if state.split("+").has("macho"):
			opts["sex"] = "macho"
		opts["quality"] = "movil" if phone else "escritorio"
		opts["cache"] = _cache
		var hd := state.split("+").has("hd")
		var rig: RefCounted = HdAnimal.build(id, c[1], size_of(id), opts) if hd else Animal3D.build(id, c[1], size_of(id), opts)
		var col := k % cols
		var row := k / cols
		var rect := Rect2(12.0 + cw * float(col), top + ch * float(row), cw - 8.0, ch - 8.0)
		# lo que ocupa entero (con la cola y las alas) y la escala con la que cabe en su celda
		var full: Rect2 = rig.get("full_box") if rig.get("full_box") != null else rig.get("fit_box")
		if state.contains("salto") or state.contains("patada"):
			# el salto y la patada estiran el cuerpo más allá de la caja de la postura construida
			full = full.grow_individual(full.size.x * 0.12, 0.0, full.size.x * 0.12, full.size.y * 0.1)
		if state.contains("alas:"):
			# las alas abiertas se levantan con la sustentación: media envergadura hacia arriba y algo hacia atrás
			var half := size_of(id).z * 0.5
			full = full.grow_individual(half * 0.35, 0.0, half * 0.1, half * 0.85)
		var fit_ppm := minf((rect.size.x - 20.0) / maxf(full.size.x, 0.01), (rect.size.y - 70.0) / maxf(full.size.y, 0.01))
		built.append([c, rig, rect, full, fit_ppm])
		if not _own_scale:
			_ppm = minf(_ppm, fit_ppm)
	for e: Array in built:
		var c: Array = e[0]
		var rig: RefCounted = e[1]
		var rect: Rect2 = e[2]
		var full: Rect2 = e[3]
		var ppm: float = e[4] if _own_scale else _ppm
		var container := SubViewportContainer.new()
		container.position = rect.position
		container.size = rect.size - Vector2(0, 28)
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(vp)
		add_child(container)
		var scene := CarScene.new()
		vp.add_child(scene)
		scene.build(Color(ROOF), "movil" if phone else "escritorio")
		for mesh: Node in scene.find_children("*", "MeshInstance3D", true, false):
			(mesh as Node3D).visible = false
		var root: Node3D = rig.get("root")
		scene.animal_root.add_child(root)
		var yaw := _yaw_of(String(c[2]))
		root.rotation.y = deg_to_rad(yaw)
		var feet_x: float = rect.size.x * 0.5 - full.get_center().x * ppm * cos(deg_to_rad(yaw))
		var oy := container.size.y - 2.0
		var zoom := _zoom_of(String(c[2]))
		if not zoom.is_empty():
			# un detalle: la celda se centra en un ancla (la garra, el ojo…) con zoom[1] m de ancho
			var at := _anchor_point(rig, String(zoom[0]), yaw)
			ppm = (rect.size.x - 20.0) / float(zoom[1])
			feet_x = rect.size.x * 0.5 - at.x * ppm
			oy = container.size.y * 0.5 + at.y * ppm
		scene.frame(container.size, ppm, feet_x, oy)
		_cells.append({ "id": c[0], "posture": c[1], "state": c[2], "label": c[3], "rig": rig, "rect": rect, "container": container,
			"pose": _pose_for(String(c[0]), String(c[2])), "ppm": ppm })
	_build_us = Time.get_ticks_usec() - t0
	queue_redraw()


## El detalle de un estado: [ancla, ancho en m] («zoom:garra:0.5») o [].
static func _zoom_of(state: String) -> Array:
	for tok: String in state.split("+"):
		if tok.begins_with("zoom:"):
			var parts := tok.split(":")
			return [parts[1], float(parts[2]) if parts.size() > 2 else 0.5]
	return []


## Un ancla del animal (m) vista de lado con la raíz girada yaw grados: «garra» (la primera garra) o una de anchors.
static func _anchor_point(rig: RefCounted, name: String, yaw: float) -> Vector2:
	var an: Dictionary = rig.get("anchors")
	var p := Vector3.ZERO
	if name == "garra" and an.has("claws") and not (an.claws as Array).is_empty():
		p = an.claws[0]
	elif an.has(name):
		var v: Vector2 = an[name]
		p = Vector3(v.x, v.y, 0.0)
	var r := deg_to_rad(yaw)
	return Vector2(p.x * cos(r) + p.z * sin(r), p.y)


## Giro de la raíz (grados; negativo: la cabeza hacia quien mira) de un estado.
static func _yaw_of(state: String) -> float:
	for tok: String in state.split("+"):
		if tok.begins_with("giro:"):
			return float(tok.substr(5))
	return 0.0


## La pose de cada estado (la misma que le daría la vista).
static func _pose_for(id: String, state: String) -> Dictionary:
	var kind := AnimalArt.kind_of(id)
	var pose := { "t": 0.0, "live": true, "alpha": 1.0, "natural": true, "claws_out": 1.0 if kind != "mamifero" else 0.0 }
	if id == "oso":
		pose.claws_out = 1.0  # las garras del oso no se retraen
	for tok: String in state.split("+"):
		var parts := tok.split(":")
		match parts[0]:
			"viento":
				pose.bristle = 0.5
				pose.flutter = 1.0
				pose.wind_local_ms = float(parts[1]) if parts.size() > 1 else 30.0
				pose.lean = 0.10
			"asustado":
				pose.scared = 1.0
				pose.bristle = 0.6
				pose.claws_out = 1.0
			"alas":
				pose.wing_open = 1.0
				pose.wing_lift = float(parts[1])
			"patada":
				pose.kick = float(parts[1]) if parts.size() > 1 else 1.0
			"salto":
				pose.leap = float(parts[1]) if parts.size() > 1 else 1.0
				pose.claws_out = 1.0
			"reforjada":
				var inlay: Variant = Catalog.find_by_id(Catalog.INLAYS, parts[1])
				pose.natural = false
				pose.claw_col = Palette.color(String(inlay.col))
				pose.claws_out = 1.0
				pose.inlay = parts[1]
				if parts.size() > 2:
					match parts[2]:
						"mella":
							pose.claw_len = 0.55
						"parte":
							pose.claw_gone = true
						"dobla":
							pose.claw_bend = 1.0
	return pose


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color("bg"))
	var font := get_theme_default_font()
	draw_string(AppTheme.DISP, Vector2(14, 30), _title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 17, Palette.color("text"))
	var sub := "Cada uno a su escala (primer plano); el alto, el largo y la envergadura son los del estado. Todo lo demás es dibujo." if _own_scale else \
		"A escala: %s px por metro; la envergadura, el alto y el largo son los del estado. Todo lo demás es dibujo." % Ui.num(snappedf(_ppm, 1.0))
	draw_string(font, Vector2(14, 48), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 11, Palette.color("dim"))
	for c: Dictionary in _cells:
		_draw_cell(c, font)
	_draw_us.append(Time.get_ticks_usec() - t0)


func _draw_cell(c: Dictionary, font: Font) -> void:
	var r: Rect2 = c.rect
	draw_rect(r, Palette.color("panel"), true)
	draw_rect(r, Palette.color("line"), false, 1.0)
	# el trozo de techo: pintura del coche con su barniz
	var roof_y := r.end.y - 30.0
	var roof := Rect2(r.position.x + 6.0, roof_y, r.size.x - 12.0, 14.0)
	var paint := Palette.color(ROOF)
	draw_rect(roof, paint.darkened(0.25))
	draw_rect(Rect2(roof.position, Vector2(roof.size.x, 4.0)), paint.lightened(0.15))
	draw_line(roof.position + Vector2(0, 1), Vector2(roof.end.x, roof.position.y + 1), Color(1, 1, 1, 0.35), 1.0)
	var rig: RefCounted = c.rig
	var pose: Dictionary = c.pose
	pose.t = _t
	rig.call("pose", pose)
	if pose.has("inlay"):
		rig.call("set_claws", false, String(pose.inlay), pose.claw_col)
	var name: String = NAMES.get(c.id, c.id)
	var sz := size_dict(c.id)
	var dims := "%s × %s m" % [Js.js_num_str(sz.heightM), Js.js_num_str(sz.lengthM)]
	if float(sz.spanM) > 0.0:
		dims += " · envergadura %s m" % Js.js_num_str(sz.spanM)
	if _own_scale:
		dims += " · %s px/m" % Ui.num(snappedf(float(c.ppm), 1.0))
	var line := name if String(c.label) == "" else "%s · %s" % [name, c.label]
	draw_string(font, r.position + Vector2(8, 16), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 11, Palette.color("text"))
	draw_string(font, r.position + Vector2(8, 30), dims, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 9, Palette.color("dimmer"))
	draw_string(font, Vector2(r.position.x + 8.0, r.end.y - 5.0), "construido en %s ms · %s vértices" % [Js.to_fixed(float(rig.get("build_us")) / 1000.0, 1),
		Ui.num(int(rig.get("verts")))], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 8, Palette.color("dimmer"))


func _report() -> void:
	if _draw_us.is_empty():
		return
	var s := 0
	for v: int in _draw_us:
		s += v
	print("demo_animales: página %s · construida en %s ms · dibujo %s µs de media (máx. %s µs)" % [Ui.num(_page + 1), Js.to_fixed(float(_build_us) / 1000.0, 1),
		Ui.num(s / _draw_us.size()), Ui.num(_draw_us.max())])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_report()
