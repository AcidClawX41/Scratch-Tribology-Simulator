## Galería de los materiales de las garras (unidad 5e), para revisarlos a ojo: la misma garra en cada material, bajo la
## luz del taller (el cielo de la nave, workshop_sky, con las paredes claras de la cetrería, el mismo sol y el mismo
## relleno) y delante de un telón gris, como en una foto de producto. Los materiales salen de la biblioteca
## (app/common/claw_material.gd) con los datos ópticos de core/lab/claw_optics.gd; la garra, de los datos del catálogo
## (app/common/claw_geo.gd: el perfil del motor y la curva del banco). Páginas:
##   1 · todos los materiales, pulidos (los metales sin facetas; las gemas y los vidrios, tallados y pulidos);
##   2 · las gemas de cerca: el fuego del diamante y de la moissanita, el rojo del rubí, el azul del zafiro;
##   3 · los metales de cerca: el oro amarillo, el acero y el titanio grises con su matiz, el carburo oscuro, la hematites;
##   4-6 · cada material en tres estados (petición 37), con la superficie de la cetrería (surface_tex): recién limado con
##       la lima gruesa (picado bastardo), pulido, y quemado o desconchado en la punta;
##   7 · los acabados de la reforja: el zafiro y el acero pulidos, tallados, limados, en bruto, mellados, agrietados u
##       oxidados;
##   8 · la garra de cada animal, de queratina con su color, a la misma escala (la lupa);
##   9 · la reforja: el zafiro incoloro de Verneuil, las capas de nitruro de titanio y de cromo, la alúmina de plasma, el
##       diamante CVD en bruto y el esmalte;
##   10 · la lupa sobre los animales del coche en marcha (app/lab/animals/, con la misma biblioteca): la garra mayor del
##       lado de quien mira de cada uno, natural (arriba) y reforjada (abajo), cada una con su cámara.
## Las garras giran despacio para que la luz pase por las facetas (con el tiempo de Movie Maker, la captura sale igual).
## Captura:   node godot/tools/godot.mjs capture res://app/lab/demo_materiales.tscn --frames=12 --out=<carpeta> -- --pagina=N
##            (sin --pagina, cada página dura PAGE_S s; con --phone, al tamaño de un teléfono y con el preset «movil»).
## Al acabar cada página escribe lo que costó construirla y el coste por fotograma (en cada fotograma no se crea nada).
extends Control

const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawGeo = preload("res://app/common/claw_geo.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const SKY_SHADER = preload("res://app/taller/lathe3d/workshop_sky.gdshader")
const Animal3D = preload("res://app/lab/animals/animal3d.gd")
const AnimalArt = preload("res://app/lab/animals/animal_art.gd")
const DemoAnimales = preload("res://app/lab/demo_animales.gd")
const Js = preload("res://core/shared/js.gd")

const PAGE_S := 4.0
## La garra de la galería: el talón del águila (35 mm de alcance en el catálogo).
const CLAW := "aguila"
const MM := 0.001
## Distancia del telón detrás de las garras (m) y tamaño de cada celda de la rejilla, en largos de la garra.
const BACKDROP_Z := 0.12
const CELL := 1.32
const ANIMAL_CLAWS := ["aguila", "arpia", "halcon", "buho", "lechuza", "buitre", "tigre", "oso", "casuario", "velociraptor", "velociraptor_pelicula"]
## Los tres estados de la petición 37 y la lima con la que se limó (la gruesa de la cetrería).
const STATES := ["limado", "pulido", "quemado"]
const STATE_NAMES := { "limado": "recién limada (lima gruesa)", "pulido": "pulida", "quemado": "quemada o desconchada" }
const COARSE_FILE := "lima_bastarda"
## Estaciones de la superficie de muestra (una cada 0,5 mm, como las del motor).
const SURFACE_STEP_MM := 0.5
## La lupa (página 10): los animales y el material reforjado de cada uno, y lo que se separan en el mundo compartido (m).
const LUPA := [["aguila", "diamante"], ["tigre", "acero"], ["oso", "oro"], ["velociraptor", "rubi"]]
const LUPA_SPACING := 40.0

var _page := -1
var _only := -1
var _mobile := false
var _t := 0.0
var _page_t := 0.0
var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _items: Array = []  # [{ node, label, phase }]
var _labels: Control
var _title: Label
var _build_us := 0
var _frame_us: Array = []
var _label_drop := 0.02
var _surfaces := {}
var _row_labels: Array = []
var _row_x := 0.0
var _row_y0 := 0.0
var _row_dy := 0.0
var _svc: SubViewportContainer
var _env: Environment
## La lupa: la rejilla de vistas, el mundo que comparten, sus animales y la caché de modelos.
var _lupa: GridContainer
var _lupa_world: World3D
var _lupa_rigs: Array = []
var _lupa_cache := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pagina="):
			_only = clampi(int(a.substr(9)) - 1, 0, _pages().size() - 1)
		elif a == "--movil":
			_mobile = true
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_svc.add_child(_vp)
	_build_world()
	_labels = Control.new()
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	_title = Label.new()
	_title.position = Vector2(16, 10)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Palette.color("text"))
	add_child(_title)
	resized.connect(_rebuild)
	_show(_only if _only >= 0 else 0)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_t += delta
	_page_t += delta
	for it: Dictionary in _items:
		var n: Node3D = it.node
		n.rotation.y = 0.35 * sin(_t * 0.6 + float(it.phase))
	_frame_us.append(Time.get_ticks_usec() - t0)
	if _only < 0 and _page_t >= PAGE_S:
		_report()
		_show((_page + 1) % _pages().size())
	_layout_labels()


func _phone() -> bool:
	return _mobile or size.x < 700.0


## La luz del taller: el cielo de la nave con las paredes claras de la sala de curas, el sol y el relleno de la cetrería.
func _build_world() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("wall_color", Color(0.72, 0.76, 0.76))
	sky_mat.set_shader_parameter("wall_low_color", Color(0.55, 0.6, 0.6))
	sky_mat.set_shader_parameter("floor_color", Color(0.46, 0.5, 0.5))
	# el techo, claro como el de un estudio de fotos (dibujo de la galería: con el gris oscuro de la nave, el dorso pulido
	# de un metal refleja casi negro y no se ve su color)
	sky_mat.set_shader_parameter("ceiling_color", Color(0.5, 0.51, 0.52))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_env = env
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.93)
	sun.basis = Basis.looking_at(Vector3(0.6, -1.4, -1.0), Vector3.UP)
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.78, 0.84, 1.0)
	fill.light_specular = 0.2
	fill.basis = Basis.looking_at(Vector3(-0.8, -0.5, 0.9), Vector3.UP)
	_vp.add_child(fill)
	# el telón: gris medio mate detrás de las garras, como en una foto de producto (lo que se refleja es la nave del
	# taller; lo que se ve detrás, y a través de las gemas, es el telón)
	var back := MeshInstance3D.new()
	var bm := QuadMesh.new()
	bm.size = Vector2(6.0, 4.0)
	back.mesh = bm
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("#5d6166")
	cloth.roughness = 0.95
	back.material_override = cloth
	back.position = Vector3(0.0, 0.0, -BACKDROP_Z)
	_vp.add_child(back)
	_world = Node3D.new()
	_vp.add_child(_world)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_vp.add_child(_cam)
	_cam.current = true


## La superficie de muestra de un estado (petición 37) para una garra de largo length_mm: { id, tex, length_mm }.
func _surface(state: String, length_mm: float) -> Dictionary:
	var key := "%s|%.1f" % [state, length_mm]
	if _surfaces.has(key):
		return _surfaces[key]
	var tool: Dictionary = CareData.TOOLS[COARSE_FILE]
	var ra_file := float(ClawOptics.finish("limado", ClawOptics.tool_grain_um(tool)).sigma_um) / 1.25
	var ra_polish := float(ClawOptics.finish("pulido").sigma_um) / 1.25
	var st: Array = []
	var n := int(ceil(length_mm / SURFACE_STEP_MM)) + 1
	for i in n:
		var s := float(i) * SURFACE_STEP_MM
		var u := s / maxf(length_mm, 1.0)
		var e := { "ra_um": ra_polish, "burn": 0.0, "chip": 0.0, "scratch_deg": 0.0 }
		match state:
			"limado":
				# la lima pasa de la base a la punta: las rayas van a lo largo, algo oblicuas
				e["ra_um"] = ra_file
				e["scratch_deg"] = 12.0
			"quemado":
				# el último tercio, quemado por el torno y con dos desconchones cerca de la punta
				e["ra_um"] = ra_file * 0.4
				e["scratch_deg"] = 90.0
				e["burn"] = smoothstep(0.55, 0.8, u)
				e["chip"] = 1.0 if (u > 0.8 and u < 0.86) or (u > 0.92 and u < 0.96) else 0.0
		st.append(e)
	var tex := ImageTexture.create_from_image(ClawMaterial.surface_image(st))
	var out := { "id": key, "tex": tex, "length_mm": length_mm }
	_surfaces[key] = out
	return out


## Páginas: [título, celdas [id del material, acabado o «», rótulo, garra (id del catálogo) o «», estado o «»], columnas].
func _pages() -> Array:
	var p1: Array = []
	for id: String in ClawOptics.MATERIAL_IDS:
		p1.append([id, "", String(ClawOptics.MATERIALS[id].name), "", ""])
	var p2: Array = []
	for id: String in ["diamante", "moissanita", "circonita", "rubi", "zafiro", "cuarzo"]:
		var lk := ClawOptics.look(id)
		p2.append([id, "", "%s\nn %s · fuego %s" % [String(lk.name), Js.to_fixed(float(lk.n_d), 3), Js.to_fixed(float(lk.dispersion_bg), 3)], "", ""])
	var p3: Array = []
	for id: String in ["oro", "acero", "titanio", "tungsteno", "hematites", "tin"]:
		p3.append([id, "", String(ClawOptics.MATERIALS[id].name), "", ""])
	# tres estados: una columna por material y una fila por estado (el nombre del material, solo en la primera)
	var states: Array = []
	for group: Array in [["none", "oro", "acero", "titanio", "tungsteno"], ["vidrio", "cuarzo", "zafiro", "rubi", "diamante"],
			["swarovski", "circonita", "moissanita", "hematites", "alumina"]]:
		var cells: Array = []
		for stt: String in STATES:
			for id: String in group:
				cells.append([id, "", String(ClawOptics.MATERIALS[id].name) if stt == STATES[0] else "", "", stt])
		states.append(cells)
	var state_rows: Array = []
	for stt: String in STATES:
		state_rows.append(String(STATE_NAMES[stt]))
	var p7: Array = []
	for id: String in ["zafiro", "acero"]:
		for f: String in ["pulido", "tallado", "limado", "bruto", "mellado", "agrietado" if id == "zafiro" else "oxidado"]:
			p7.append([id, f, "%s\n%s" % [String(ClawOptics.MATERIALS[id].name), String(ClawOptics.FINISH_NAMES[f]).to_lower()], "", ""])
	var p8: Array = []
	for cid: String in ANIMAL_CLAWS:
		var sp := ClawGeo.spec_of(cid)
		p8.append(["none", "", "%s\n%s mm" % [_claw_name(cid), Js.js_num_str(Js.js_round(float(sp.length_mm)))], cid, ""])
	var p9: Array = [["zafiro_incoloro", "pulido", "Zafiro incoloro (Verneuil)", "", ""], ["tin", "pulido", "Capa de nitruro de titanio", "", ""],
		["cromo", "pulido", "Cromo duro", "", ""], ["alumina", "poroso", "Alúmina de plasma", "", ""], ["diamante", "bruto", "Diamante CVD en bruto", "", ""],
		["vidrio", "pulido", "Esmalte vítreo", "", ""]]
	return [
		["Los materiales de las garras, pulidos, bajo la luz del taller", p1, 5],
		["Las gemas de cerca: el fuego, el rojo del rubí y el azul del zafiro", p2, 3],
		["Los metales de cerca: el color de su reflejo medido", p3, 3],
		["Tres estados: la queratina y los metales", states[0], 5, state_rows],
		["Tres estados: el vidrio y las gemas", states[1], 5, state_rows],
		["Tres estados: el cristal, las gemas, la hematites y la alúmina", states[2], 5, state_rows],
		["Los acabados de la reforja: pulido, tallado, limado, en bruto, mellado, agrietado u oxidado", p7, 6],
		["La garra de cada animal, de queratina con su color, a la misma escala", p8, 6],
		["La reforja: zafiro incoloro, capas y piezas en bruto", p9, 3],
		["La lupa sobre las garras de los animales del coche en marcha: naturales y reforjadas", [], 4, [], "lupa"],
	]


static func _claw_name(cid: String) -> String:
	var names := { "aguila": "Águila", "arpia": "Arpía", "halcon": "Halcón", "buho": "Búho", "lechuza": "Lechuza", "buitre": "Buitre",
		"tigre": "Tigre", "oso": "Oso pardo", "casuario": "Casuario", "velociraptor": "Velocirraptor", "velociraptor_pelicula": "Velocirraptor (cine)" }
	return String(names.get(cid, cid))


func _show(i: int) -> void:
	_page = i
	_page_t = 0.0
	_frame_us.clear()
	_rebuild()


func _rebuild() -> void:
	if _page < 0 or size.x <= 0.0:
		return
	for it: Dictionary in _items:
		(it.node as Node).queue_free()
		(it.label as Node).queue_free()
	_items.clear()
	for lb: Node in _row_labels:
		lb.queue_free()
	_row_labels.clear()
	_clear_lupa()
	var page: Array = _pages()[_page]
	_svc.visible = page.size() <= 4
	if page.size() > 4 and String(page[4]) == "lupa":
		_title.text = "%d · %s" % [_page + 1, page[0]]
		_rebuild_lupa()
		return
	var cells: Array = page[1]
	var phone := _phone()
	var cols := int(page[2])
	var row_names: Array = page[3] if page.size() > 3 else []
	if phone and row_names.is_empty():
		cols = mini(cols, 3 if cells.size() % 3 == 0 and cells.size() <= 15 else 2)
	var rows := ceili(float(cells.size()) / float(cols))
	for r in row_names.size():
		var rl := Label.new()
		rl.text = String(row_names[r])
		rl.add_theme_font_size_override("font_size", 11 if phone else 14)
		rl.add_theme_color_override("font_color", Palette.color("gold"))
		rl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		rl.add_theme_constant_override("outline_size", 4)
		_labels.add_child(rl)
		_row_labels.append(rl)
	_title.text = "%d · %s" % [_page + 1, page[0]]
	var t0 := Time.get_ticks_usec()
	var q := "movil" if phone else "escritorio"
	# la escala: la garra más grande de la página llena su celda (m por mm); la celda, CELL largos de esa garra
	var biggest := 0.0
	for c: Array in cells:
		var cid := String(c[3]) if String(c[3]) != "" else CLAW
		biggest = maxf(biggest, float(ClawGeo.spec_of(cid).length_mm))
	var cell_m := biggest * MM * CELL
	for k in cells.size():
		var c: Array = cells[k]
		var cid := String(c[3]) if String(c[3]) != "" else CLAW
		var spec := ClawGeo.spec_of(cid)
		var length := float(spec.length_mm)
		# la sección medida de su especie (alto/ancho, CareData.claw_shape, de la 5g): un gato, alta y estrecha; un oso, gruesa
		var mesh := ClawGeo.claw_mesh(cid, ClawGeo.RING_MOBILE if phone else 64, -1.0, float(CareData.claw_shape(cid).sectionRatio))
		var mid := String(c[0])
		var f: Dictionary = ClawOptics.finish(String(c[1])) if String(c[1]) != "" else ClawOptics.default_finish(mid)
		var opts := { "quality": q, "env": "taller", "apex_mm": length, "seed": float(k % 7) * 0.37,
			"color": ClawOptics.keratin_color(cid, String(spec.color)) }
		if String(c[4]) != "":
			opts["surface"] = _surface(String(c[4]), length)
		var mat := ClawMaterial.material(mid, f, opts)
		var holder := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		# la garra en metros, con la base a la izquierda y la punta hacia abajo (de lado, la cara exterior a la cámara),
		# centrada en su celda
		mi.scale = Vector3.ONE * MM
		var tip := ClawGeo.tip_point(float(spec.k), length)
		mi.position = -tip * 0.5 * MM
		holder.add_child(mi)
		var col := k % cols
		var row := k / cols
		holder.position = Vector3((float(col) - 0.5 * float(cols - 1)) * cell_m, (0.5 * float(rows - 1) - float(row)) * cell_m * 0.95, 0.0)
		_world.add_child(holder)
		var lb := Label.new()
		lb.text = String(c[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11 if phone else 13)
		lb.add_theme_color_override("font_color", Palette.color("text"))
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lb.add_theme_constant_override("outline_size", 4)
		_labels.add_child(lb)
		_items.append({ "node": holder, "label": lb, "phase": float(k) * 0.9 })
	# la cámara encuadra la rejilla (un poco desde arriba: así se ven las luminarias del techo reflejadas en el dorso); con
	# rótulos de fila, deja sitio a la izquierda
	var w := float(cols) * cell_m + (cell_m * 0.9 if not row_names.is_empty() else 0.0)
	var h := float(rows) * cell_m * 0.95 + cell_m * 0.25
	var aspect := size.x / maxf(size.y - 40.0, 1.0)
	var half := maxf(h * 0.5, w * 0.5 / maxf(aspect, 0.2))
	var dist := half / tan(deg_to_rad(_cam.fov * 0.5)) * 1.04
	var shift := -cell_m * 0.45 if not row_names.is_empty() else 0.0
	_cam.position = Vector3(shift, dist * 0.18, dist)
	_cam.look_at(Vector3(shift, -cell_m * 0.08, 0.0), Vector3.UP)
	_build_us = Time.get_ticks_usec() - t0
	_label_drop = cell_m * 0.42
	_row_x = (-0.5 * float(cols - 1) - 0.62) * cell_m
	_row_y0 = 0.5 * float(rows - 1) * cell_m * 0.95
	_row_dy = cell_m * 0.95
	_layout_labels()


func _clear_lupa() -> void:
	for r: RefCounted in _lupa_rigs:
		r.call("free_nodes")
	_lupa_rigs.clear()
	if _lupa != null:
		_lupa.queue_free()
		_lupa = null


## La lupa: cada animal del coche en marcha (a su tamaño del estado, con la biblioteca de materiales en sus garras) en un
## mundo compartido, separados LUPA_SPACING m, y una vista por garra: la mayor del lado de quien mira, natural arriba y
## reforjada abajo, encuadrada de lado y algo desde arriba.
func _rebuild_lupa() -> void:
	var t0 := Time.get_ticks_usec()
	var phone := _phone()
	if _lupa_world == null:
		_lupa_world = World3D.new()
		_lupa_world.environment = _env
	_lupa = GridContainer.new()
	_lupa.columns = 2 if phone else LUPA.size()
	_lupa.position = Vector2(8, 40)
	_lupa.size = Vector2(size.x - 16.0, size.y - 48.0)
	_lupa.add_theme_constant_override("h_separation", 6)
	_lupa.add_theme_constant_override("v_separation", 6)
	add_child(_lupa)
	var cols := _lupa.columns
	var rows := ceili(float(LUPA.size() * 2) / float(cols))
	var cell := Vector2((_lupa.size.x - 6.0 * float(cols - 1)) / float(cols), (_lupa.size.y - 6.0 * float(rows - 1)) / float(rows))
	var host: SubViewport = null
	var k := 0
	for reforged: bool in [false, true]:
		for e: Array in LUPA:
			var id := String(e[0])
			var mat_id := String(e[1]) if reforged else "none"
			var svc := SubViewportContainer.new()
			svc.stretch = true
			svc.custom_minimum_size = cell
			_lupa.add_child(svc)
			var vp := SubViewport.new()
			vp.world_3d = _lupa_world
			vp.msaa_3d = Viewport.MSAA_4X
			svc.add_child(vp)
			if host == null:
				host = vp
				_lupa_lights(host)
			var rig := Animal3D.build(id, String(AnimalArt.postures_of(id)[0]), DemoAnimales.size_of(id),
				{ "cache": _lupa_cache, "quality": "movil" if phone else "escritorio", "claw_env": "taller" })
			_lupa_rigs.append(rig)
			var root: Node3D = rig.get("root")
			root.position = Vector3(float(k) * LUPA_SPACING, 0.0, 0.0)
			host.add_child(root)
			rig.call("pose", { "t": 0.0 })
			if reforged:
				rig.call("set_claws", false, mat_id, Color.WHITE)
			var cam := Camera3D.new()
			cam.fov = 30.0
			vp.add_child(cam)
			cam.current = true
			_aim_lupa(cam, rig)
			var lb := Label.new()
			var nm := String(ClawOptics.MATERIALS[mat_id].name) if reforged else "queratina natural"
			lb.text = "%s · %s" % [_claw_name(id), nm]
			lb.add_theme_font_size_override("font_size", 11 if phone else 13)
			lb.add_theme_color_override("font_color", Palette.color("text"))
			lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			lb.add_theme_constant_override("outline_size", 4)
			lb.position = Vector2(8, cell.y - 24.0)
			svc.add_child(lb)
			k += 1
	_build_us = Time.get_ticks_usec() - t0


## Las luces de la lupa (las de la galería) en el mundo compartido.
func _lupa_lights(host: SubViewport) -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.93)
	sun.basis = Basis.looking_at(Vector3(0.6, -1.4, -1.0), Vector3.UP)
	host.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.78, 0.84, 1.0)
	fill.light_specular = 0.2
	fill.basis = Basis.looking_at(Vector3(-0.8, -0.5, 0.9), Vector3.UP)
	host.add_child(fill)


## La cámara de una vista de la lupa: la garra más larga del lado de quien mira, de lado (desde +z) y algo desde arriba,
## que ocupe la mitad de la vista.
func _aim_lupa(cam: Camera3D, rig: RefCounted) -> void:
	var claws: Array = rig.get("claws")
	var data: Dictionary = rig.get("_data")
	var best := -1
	var best_len := 0.0
	for i in claws.size():
		var len := float((data.claws as Array)[i].len)
		if not bool(claws[i].far) and len > best_len:
			best_len = len
			best = i
	if best < 0:
		return
	var base: Vector3 = (claws[best].node as Node3D).global_position
	var tips: Array = rig.call("claw_points")
	var root: Node3D = rig.get("root")
	var tip: Vector3 = root.global_transform * (tips[best] as Vector3)
	var mid := (base + tip) * 0.5
	var span := maxf(base.distance_to(tip), best_len * float(rig.get("mpc")))
	var dist := span * 1.25 / tan(deg_to_rad(cam.fov * 0.5))
	cam.position = mid + Vector3(0.12, 0.35, 1.0).normalized() * dist
	cam.look_at(mid, Vector3.UP)
	cam.near = maxf(dist * 0.02, 0.001)


func _layout_labels() -> void:
	if _cam == null or not is_inside_tree():
		return
	var vs := size
	for it: Dictionary in _items:
		var n: Node3D = it.node
		var lb: Label = it.label
		var p := _cam.unproject_position(n.global_position + Vector3(0.0, -_label_drop, 0.0))
		var ms := lb.get_minimum_size()
		lb.position = Vector2(clampf(p.x - ms.x * 0.5, 4.0, vs.x - ms.x - 4.0), clampf(p.y, 40.0, vs.y - ms.y - 4.0))
	for r in _row_labels.size():
		var rl: Label = _row_labels[r]
		var p := _cam.unproject_position(Vector3(_row_x, _row_y0 - float(r) * _row_dy, 0.0))
		var ms := rl.get_minimum_size()
		rl.position = Vector2(clampf(p.x - ms.x, 4.0, vs.x - ms.x - 4.0), clampf(p.y - ms.y * 0.5, 40.0, vs.y - ms.y - 4.0))


func _report() -> void:
	var sum := 0
	var mx := 0
	for us: int in _frame_us:
		sum += us
		mx = maxi(mx, us)
	var avg := float(sum) / float(maxi(_frame_us.size(), 1))
	print("    galería, página %d: construida en %d µs (%d materiales en la caché, %d construidos), fotograma %s µs de media y %d de máximo" % [
		_page + 1, _build_us, ClawMaterial.cache_size(), ClawMaterial.built, "%.0f" % avg, mx])


func _exit_tree() -> void:
	_report()
