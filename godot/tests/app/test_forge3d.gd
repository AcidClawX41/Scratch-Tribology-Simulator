## Escena 3D del laboratorio experimental de la reforja (app/lab/cetreria/forge_3d.tscn, unidad 5f) sin ventana, en un
## SubViewport de tamaño fijo: carga con su API; lo de cada máquina se ve en su marcha (la bola de Verneuil crece hacia
## abajo, la prensa se cierra y se abre, el plasma de la CVD late, el crisol cuela en el molde, la pieza sinterizada
## encoge); el ratón coge un tarro, vierte en la balanza, gira un dial y arranca el horno (los gestos llegan al estado
## como órdenes); los fotogramas no crean nodos, las mallas de la garra y de la funda solo se rehacen con una forma nueva,
## y lo que cuesta un fotograma de la escena cabe en el presupuesto. Desde la 5m, la carga que entra por la puerta, la cera
## perdida, el tallado por pasadas en su herramienta y la sala con ventanas al campo y materiales con relieve.
extends "res://tests/case.gd"

const SCENE := "res://app/lab/cetreria/forge_3d.tscn"
const Runner = preload("res://app/lab/cetreria/forge_runner.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const ClawMaterial = preload("res://app/common/claw_material.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const Forge3D = preload("res://app/lab/cetreria/forge_3d.gd")
const ForgePage = preload("res://app/lab/cetreria/forge_page.gd")
const ForgeLooks = preload("res://app/lab/cetreria/forge_looks.gd")

const FRAME := 1.0 / 30.0
const VIEWPORT := Vector2i(800, 600)
## Presupuesto de un fotograma de la escena (ms de media de advance(), sin el dibujo): holgado para la integración
## continua; en un portátil, bastante menos.
const BUDGET_MS := 4.0


func _host() -> Array:
	var vp := SubViewport.new()
	vp.size = VIEWPORT
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	return [vp, s]


static func _runner(process := "zafiro") -> Runner:
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila" })
	r.post("set_process", [process])
	return r


static func _wire(s: Node3D, r: Runner) -> void:
	s.connect("gesture", func(op: String, args: Array) -> void: r.post(op, args))


func _frame(s: Node3D, r: Runner) -> void:
	s.call("advance", FRAME)
	r.post("tick", [FRAME])
	s.call("show_view", r.latest())


func _mouse(s: Node3D, p: Vector2, button := -1, pressed := false, shift := false) -> void:
	if button < 0:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.shift_pressed = shift
		s.call("handle_pointer", mm)
		return
	var mb := InputEventMouseButton.new()
	mb.button_index = button as MouseButton
	mb.pressed = pressed
	mb.position = p
	mb.shift_pressed = shift
	s.call("handle_pointer", mb)


## La prótesis de una garra rota se dibuja sobre lo que queda y hasta la punta natural de la garra de su dedo (rehace lo que
## falta; unidad 5j): la malla de la garra acaba en el muñón y la de la prótesis, en la punta natural más su pared.
func test_la_protesis_de_la_garra_rota_llega_a_la_punta_natural() -> void:
	var care := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "digit": "II", "overgrowth_days": 0.0 })
	var prof: Dictionary = care.snapshot().profile
	var bs := PackedFloat64Array()
	var br := PackedFloat64Array()
	for i in (prof.s as PackedFloat64Array).size():
		if float(prof.s[i]) <= 20.0:
			bs.append(float(prof.s[i]))
			br.append(float(prof.r[i]))
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila", "digit": "II", "paw": "izquierda", "broken": true,
		"profile": { "s": bs, "r": br }, "from_care": { "stump_mm": 20.0, "digit": "II", "paw": "izquierda" } })
	var v := r.latest()
	assert_eq(String(v.shape), "protesis", "la garra rota, con la prótesis entera")
	var nat := care.natural_mm()
	var u_claw: PackedVector2Array = (v.claw_mesh.arrays as Array)[Mesh.ARRAY_TEX_UV]
	var u_sheath: PackedVector2Array = (v.sheath_mesh.arrays as Array)[Mesh.ARRAY_TEX_UV]
	var claw_max := 0.0
	var sh_min := INF
	var sh_max := 0.0
	for uv: Vector2 in u_claw:
		claw_max = maxf(claw_max, uv.x)
	for uv: Vector2 in u_sheath:
		sh_min = minf(sh_min, uv.x)
		sh_max = maxf(sh_max, uv.x)
	assert_near(claw_max, bs[bs.size() - 1], 1e-6, 1e-6, "la garra se dibuja hasta el muñón")
	assert_near(sh_max, nat + float(v.sheath.wall_mm), 1e-6, 1e-6, "y la prótesis, hasta la punta natural más su pared (%s mm)" % sh_max)
	assert_true(sh_min < bs[bs.size() - 1], "pegada sobre lo que queda")


## La funda tallada y pulida lleva la superficie del motor (la de la última muela o el último grano; lo pidió la 5f, unidad
## 5j), con el codificador de la biblioteca, como en la cetrería: surface_tex y surface_range hasta la punta de la funda; en
## bruto, la de su acabado. La textura se hace al tallar o pulir, no en cada fotograma.
func test_la_funda_lleva_la_superficie_del_motor() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("zafiro")
	for op: String in ["apply_recommended", "load_crucible", "insert_charge", "start", "skip", "cool_piece", "skip"]:
		r.post(op)
	s.call("show_view", r.latest())
	assert_eq(String(s.call("info").surface), "", "en bruto, sin superficie: la de su acabado")
	r.post("carve")
	r.post("skip")
	var v := r.latest()
	s.call("show_view", v)
	var sf: Dictionary = v.piece.look.surface
	assert_true(bool(sf.ok) and String(sf.by) == "talla", "tallada, la de la muela")
	var mi: MeshInstance3D = (s.get("_piece_shapes") as Dictionary).funda
	var mat := mi.material_override as ShaderMaterial
	var nat_s: PackedFloat64Array = v.profile.nat_s
	var length := nat_s[nat_s.size() - 1] + float(v.sheath.wall_mm)
	assert_eq(mat.get_shader_parameter("surface_range"), Vector2(0.0, length), "a lo largo de la funda, hasta su punta")
	var tex: Variant = mat.get_shader_parameter("surface_tex")
	assert_true(tex is ImageTexture and (tex as ImageTexture).get_width() == (sf.stations as Array).size(), "con la textura de la biblioteca, una columna por estación")
	var img := ClawMaterial.surface_image(sf.stations)
	assert_near(img.get_pixel(0, 0).r, ClawMaterial.surface_r(float(sf.raUm)), 0.0, 1.0 / 255.0 + 1e-6, "R: la rugosidad, con el codificador de la biblioteca")
	assert_near(img.get_pixel(0, 0).b, float(sf.chip), 0.0, 1e-6, "B: el desconchón")
	var key0 := String(s.call("info").surface)
	for i in 10:
		_frame(s, r)
	assert_eq(String(s.call("info").surface), key0, "sin tallar ni pulir, la misma superficie")
	# pulida, la del grano: más lisa
	for op: String in ["protect", "skip", "bond", "skip", "polish", "skip"]:
		r.post(op)
	v = r.latest()
	s.call("show_view", v)
	var sp: Dictionary = v.piece.look.surface
	assert_true(String(sp.by) == "pulido" and float(sp.raUm) < float(sf.raUm), "pulida: la del grano, más lisa (%s < %s µm)" % [sp.raUm, sf.raUm])
	assert_true(String(s.call("info").surface) != key0, "otra superficie")
	var mat2 := (s.get("_claw_sheath") as MeshInstance3D).material_override as ShaderMaterial
	assert_eq(mat2.get_shader_parameter("surface_range"), Vector2(0.0, length), "la funda pegada a la garra, también")


## En el teléfono, el deslizador grande tapa la derecha de la vista: la vista «Horno» encuadra el panel en lo que queda a la
## izquierda y su columna derecha ya no queda debajo (lo pidió la 5f; unidad 5j); sin el deslizador, la vista de siempre.
func test_el_deslizador_no_tapa_el_panel_del_horno() -> void:
	var w := 390.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(w), 439)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_to_tree(vp)
	var s: Node3D = (load(SCENE) as PackedScene).instantiate()
	s.set("auto_process", false)
	vp.add_child(s)
	s.call("set_view", "horno", true)
	var cam: Camera3D = s.call("camera")
	var front := Forge3D.FRONT_Z + 0.013
	var edge := Forge3D.PANEL_SIZE.x * 0.5
	var free := w - (112.0 + ForgePage.TOUCH_GAP)
	assert_true(cam.unproject_position(Vector3(edge, 0.47, front)).x > free, "sin descontarlo, el borde derecho de la placa del panel quedaría debajo del deslizador")
	s.call("set_inset_right", (w - free) / w)
	s.call("set_view", "horno", true)
	for id: String in ["pressure_mpa", "cool", "modo", "atmosphere"]:
		var p: Vector2 = s.call("target_screen_point", "mando:" + id)
		assert_true(p.x > 0.0 and p.x < free, "%s: a la vista, fuera del deslizador (%s px; libre hasta %s)" % [id, p.x, free])
	var right := cam.unproject_position(Vector3(edge, 0.47, front)).x
	var left := cam.unproject_position(Vector3(-edge, 0.47, front)).x
	assert_true(right <= free + 0.5 and left >= -0.5, "la placa entera, de borde a borde, en lo que queda (%s-%s px)" % [left, right])
	# sin el deslizador (escritorio), como antes: centrado
	s.call("set_inset_right", 0.0)
	s.call("set_view", "horno", true)
	var c := cam.unproject_position(Vector3(0.0, 0.47, front)).x
	assert_near(c, w * 0.5, 0.0, 1.0, "sin el deslizador, el panel centrado")


func test_carga_con_su_api() -> void:
	var h := _host()
	var s: Node3D = h[1]
	for m in ["show_view", "set_view", "info", "advance", "handle_pointer", "hit_at", "target_screen_point", "camera", "node_count", "set_quality", "is_mobile"]:
		assert_true(s.has_method(m), "la escena expone %s()" % m)
	var r := _runner()
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	var info: Dictionary = s.call("info")
	assert_eq(String(info.view), "general", "empieza en la vista general")
	assert_true(int(info.targets) >= 30, "los tarros, los mandos, los botones y los sitios del taller se pueden tocar (%d)" % int(info.targets))
	assert_eq(int(info.mesh_builds), 2, "la malla de la garra y la de la funda")
	for v: String in s.get("VIEWS"):
		s.call("set_view", v, true)
		assert_eq(String(s.call("info").view), v, "la vista %s" % v)


## Lo de cada máquina en su marcha, con lo recomendado por la receta.
func test_cada_maquina_en_su_marcha() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var cases := { "zafiro": "verneuil", "diamante_hpht": "hpht", "diamante_cvd": "cvd", "oro": "fundir", "acero": "fundir", "metal_duro": "bandeja" }
	for pid: String in cases:
		var r := _runner(pid)
		# lo más rápido: la marcha de unos segundos (la del diamante HPHT, a ×3600, duraría el tope de la pantalla)
		r.post("set_speed", [State.SPEEDS.size() - 1])
		r.post("apply_recommended")
		r.post("load_crucible")
		r.post("insert_charge")
		r.post("start")
		s.call("show_view", r.latest())
		var seen_closed := false
		var seen_plasma := false
		var seen_pour := false
		var max_boule := 0.0
		for i in 400:
			_frame(s, r)
			var info: Dictionary = s.call("info")
			assert_eq(String(info.mode), String(cases[pid]), "%s: se ve su máquina" % pid)
			max_boule = maxf(max_boule, float(info.boule_mm))
			if float(info.anvil_gap) < 0.2:
				seen_closed = true
			if (s.get("_plasma") as Node3D).visible:
				seen_plasma = true
			if (s.get("_pour") as Node3D).visible:
				seen_pour = true
			if not bool(r.latest().run.active) and i > 30:
				break
		match pid:
			"zafiro":
				assert_true(max_boule > 10.0, "la bola crece (%s mm)" % max_boule)
			"diamante_hpht":
				assert_true(seen_closed, "la prensa se cierra")
			"diamante_cvd":
				assert_true(seen_plasma, "el plasma se enciende sobre el molde")
			"oro", "acero":
				assert_true(seen_pour, "%s: cuela en el molde" % pid)
		# al acabar la prensa se abre
		if pid == "diamante_hpht":
			for i in 90:
				_frame(s, r)
			assert_true(float(s.call("info").anvil_gap) > 0.8, "y se abre al acabar")


func test_el_raton_pesa_gira_y_arranca() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("zafiro")
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "banco", true)
	for i in 3:
		_frame(s, r)
	var st: State = r.state
	var jar: Vector2 = s.call("target_screen_point", "tarro:al2o3")
	assert_true(jar.x >= 0.0, "el tarro de la alúmina se ve")
	_mouse(s, jar)
	_mouse(s, jar, MOUSE_BUTTON_LEFT, true)
	for i in 2:
		_frame(s, r)
	assert_eq(st.held_jar, "al2o3", "el clic coge el tarro")
	var pan: Vector2 = s.call("target_screen_point", "balanza")
	for k in 6:
		_mouse(s, jar.lerp(pan, float(k + 1) / 6.0))
		_frame(s, r)
	assert_true(st.pouring, "sobre el plato, vierte")
	for i in 30:
		_frame(s, r)
	_mouse(s, pan, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_false(st.pouring, "al soltar, deja de verter")
	assert_true(float(st.pan.get("al2o3", 0.0)) > 3.0, "y en el plato hay alúmina (%s g)" % st.pan.get("al2o3", 0.0))
	# el dial de la temperatura, arrastrando hacia arriba
	s.call("set_view", "horno", true)
	for i in 3:
		_frame(s, r)
	var dial: Vector2 = s.call("target_screen_point", "mando:temp_c")
	assert_true(dial.x >= 0.0, "el dial de la temperatura se ve")
	var t0 := float(st.dial.temp_c)
	_mouse(s, dial)
	_mouse(s, dial, MOUSE_BUTTON_LEFT, true)
	for k in 10:
		_mouse(s, dial + Vector2(0.0, -14.0 * float(k + 1)))
	_mouse(s, dial + Vector2(0.0, -140.0), MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(st.selected_control, "temp_c", "el clic elige el dial")
	# de 20 °C, el primer paso va a la rejilla de 25 °C y los otros nueve, de 25 en 25
	assert_eq(t0, 20.0, "el horno estaba frío")
	assert_eq(float(st.dial.temp_c), State.TEMP_STEP * 10.0, "arrastrar diez pasos hacia arriba lo sube diez pasos")
	# un selector: un clic, la opción siguiente
	var sel: Vector2 = s.call("target_screen_point", "mando:modo")
	var m0 := String(st.dial.modo)
	_mouse(s, sel)
	_mouse(s, sel, MOUSE_BUTTON_LEFT, true)
	_mouse(s, sel, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_true(String(st.dial.modo) != m0, "el clic en el selector pasa a la opción siguiente")
	# el botón de arrancar, con la carga dentro de su máquina
	r.post("apply_recommended")
	r.post("load_crucible")
	r.post("insert_charge")
	_frame(s, r)
	var start: Vector2 = s.call("target_screen_point", "arrancar")
	_mouse(s, start)
	_mouse(s, start, MOUSE_BUTTON_LEFT, true)
	_mouse(s, start, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_true(st.running(), "el botón rojo arranca el horno")


## Un clic coge el tarro (y no lo suelta al levantar el dedo); otro clic sobre el mismo lo deja; con el tarro en la mano,
## mantener pulsado sobre el plato vierte y soltar deja de verter.
func test_un_clic_coge_el_tarro_y_otro_lo_deja() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("rubi")
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "banco", true)
	for i in 3:
		_frame(s, r)
	var st: State = r.state
	var jar: Vector2 = s.call("target_screen_point", "tarro:cr2o3")
	assert_true(jar.x >= 0.0, "el tarro del óxido de cromo se ve")
	_mouse(s, jar)
	_mouse(s, jar, MOUSE_BUTTON_LEFT, true)
	_frame(s, r)
	_mouse(s, jar, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(st.held_jar, "cr2o3", "el clic lo coge y no lo suelta al levantar el dedo")
	var pan: Vector2 = s.call("target_screen_point", "balanza")
	_mouse(s, pan)
	_mouse(s, pan, MOUSE_BUTTON_LEFT, true)
	for i in 10:
		_frame(s, r)
	assert_true(st.pouring, "mantener pulsado sobre el plato vierte")
	_mouse(s, pan, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_false(st.pouring, "soltar deja de verter")
	assert_true(float(st.pan.get("cr2o3", 0.0)) > 0.0, "y en el plato hay óxido de cromo")
	jar = s.call("target_screen_point", "tarro:cr2o3")
	_mouse(s, jar)
	_mouse(s, jar, MOUSE_BUTTON_LEFT, true)
	_frame(s, r)
	_mouse(s, jar, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(st.held_jar, "", "otro clic sobre el mismo tarro lo deja")


## El estuche del acrílico dental (la prótesis de verdad de una garra rota; unidad 5j), en la mesa de la balanza: se ve,
## el tutorial lo ilumina en su paso y un clic lo mezcla; la caja de las piedras sigue comprando la piedra.
func test_el_estuche_del_acrilico_lo_mezcla() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := Runner.new({ "animal": "rapaz", "claw": "aguila", "broken": true, "from_care": { "animal": "rapaz", "claw": "aguila", "stump_mm": 18.0 } })
	r.post("tutorial_goto", [State.ACRYLIC])
	_wire(s, r)
	s.call("show_view", r.latest())
	s.call("set_view", "banco", true)
	for i in 3:
		_frame(s, r)
	var st: State = r.state
	var kit: Vector2 = s.call("target_screen_point", "acrilico")
	assert_true(kit.x >= 0.0 and kit.x < float(VIEWPORT.x) and kit.y >= 0.0 and kit.y < float(VIEWPORT.y), "el estuche se ve en «La balanza» (%s)" % kit)
	assert_eq(String(s.call("hit_at", kit)), "acrilico", "y se puede tocar")
	st.tutorial_next()
	st.tutorial_next()
	_frame(s, r)
	assert_eq(String(st.tutorial_view().step.id), "mezclar", "(el paso de mezclar)")
	assert_eq(String(s.call("info").highlight), "acrilico", "el tutorial ilumina el estuche")
	_mouse(s, kit)
	_mouse(s, kit, MOUSE_BUTTON_LEFT, true)
	_frame(s, r)
	_mouse(s, kit, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(String(st.snap().piece.get("material", "")), "acrilico", "un clic lo mezcla")
	assert_true(bool(st.care_view().ok), "y la garra rota ya puede volver a la cetrería")
	var box: Vector2 = s.call("target_screen_point", "tienda")
	_mouse(s, box)
	_mouse(s, box, MOUSE_BUTTON_LEFT, true)
	_frame(s, r)
	_mouse(s, box, MOUSE_BUTTON_LEFT, false)
	_frame(s, r)
	assert_eq(String(st.snap().piece.get("material", "")), st.stone, "la caja de las piedras compra la piedra")


## Las piezas llevan los materiales de la biblioteca común de las garras (ClawMaterial, unidad 5e), pedidos solo cuando
## cambia lo que enseñan (la biblioteca los construye una vez por clave): la bola de Verneuil, zafiro incoloro en bruto; la
## funda pegada, el de ClawMaterial.for_forge con la garra que sale. El brillo del calor va en su capa (material_overlay):
## al rojo, puesta sobre la variante opaca; fría, sin capa y con el material de siempre.
func test_las_piezas_con_la_biblioteca_de_materiales() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("zafiro")
	r.post("apply_recommended")
	r.post("load_crucible")
	r.post("insert_charge")
	r.post("start")
	s.call("show_view", r.latest())
	for i in 40:
		_frame(s, r)
	var boule: MeshInstance3D = s.get("_boule_body")
	var bo := "zafiro_incoloro"
	# al rojo, la variante opaca de la biblioteca (la de las gemas lee la pantalla y taparía la capa del calor)
	var want := ClawMaterial.material(bo, ClawOptics.finish_from_forge("bruto", null, bo), { "quality": "movil", "uv_mode": 1, "thick_mm": float(ForgeData.RECIPES.zafiro.growth.diameter_mm) })
	assert_true(boule.material_override == want, "la bola de Verneuil al rojo: zafiro incoloro en bruto, de la biblioteca (opaco)")
	assert_true(boule.material_overlay != null, "y el brillo del calor, en su capa")
	var built := ClawMaterial.built
	for i in 60:
		_frame(s, r)
	assert_eq(ClawMaterial.built, built, "los fotogramas no construyen materiales")
	r.post("skip")
	r.post("cool_piece")
	r.post("skip")
	for op: String in ["carve", "skip", "protect", "bond", "polish", "check", "skip"]:
		r.post(op)
	for i in 20:
		_frame(s, r)
	var v: Dictionary = r.latest()
	var res: Dictionary = v.piece.look.result
	assert_true(bool(res.ok), "la garra reforjada sale")
	var ss: PackedFloat64Array = v.profile.nat_s
	var apex := ss[ss.size() - 1]
	# con la superficie de la funda pulida (5j): la misma clave de la biblioteca (la textura la hizo la escena)
	var surf := { "id": String(s.call("info").surface), "tex": null, "length_mm": apex + float(v.sheath.wall_mm) }
	assert_true(String(surf.id) != "", "(la funda pulida lleva su superficie)")
	var sheath_want := ClawMaterial.for_forge(res, { "quality": "escritorio", "apex_mm": apex, "surface": surf }, String(v.piece.look.variety), v.piece.look.grain_um)
	assert_true((s.get("_claw_sheath") as MeshInstance3D).material_override == sheath_want, "la funda pegada: ClawMaterial.for_forge con la garra que sale")
	for mi: MeshInstance3D in s.get("_piece_mis"):
		assert_true(mi.material_overlay == null, "fría, sin la capa del calor")


func test_los_fotogramas_no_crean_nodos_y_las_mallas_solo_con_la_forma() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("zafiro")
	s.call("show_view", r.latest())
	s.call("advance", FRAME)
	var nodes := int(s.call("node_count"))
	var builds := int(s.call("info").mesh_builds)
	r.post("apply_recommended")
	r.post("load_crucible")
	r.post("insert_charge")
	r.post("start")
	for i in 260:
		_frame(s, r)
	r.post("cool_piece")
	for i in 60:
		_frame(s, r)
	r.post("carve")
	for i in 100:
		_frame(s, r)
	r.post("protect")
	r.post("bond")
	r.post("polish")
	r.post("check")
	for i in 80:
		_frame(s, r)
	assert_eq(int(s.call("node_count")), nodes, "los fotogramas no crean nodos")
	assert_eq(int(s.call("info").mesh_builds), builds + 1, "solo la barrera, que es una forma nueva")
	# otra forma de la funda: otra malla de la funda; la garra, la misma
	r.post("set_shape", ["funda_larga"])
	_frame(s, r)
	assert_eq(int(s.call("info").mesh_builds), builds + 2, "la funda larga, otra malla")
	assert_eq(int(s.call("node_count")), nodes, "y ningún nodo nuevo")


## 5m · la carga entra por la puerta (que se abre y se cierra) y cada máquina enseña su carga solo si está metida: la alúmina
## en la tolva de Verneuil, la cápsula de la prensa, el sustrato de la CVD, la pastilla del sinterizado y el crisol de la bobina.
func test_la_carga_entra_por_la_puerta() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var cases := { "zafiro": "hopper", "diamante_hpht": "capsule", "diamante_cvd": "substrate", "metal_duro": "pellet", "acero": "crucible" }
	for pid: String in cases:
		var r := _runner(pid)
		_wire(s, r)
		r.post("apply_recommended")
		r.post("load_crucible")
		_frame(s, r)
		assert_false(bool(s.call("info")[cases[pid]]), "%s: sin meterla, la máquina está vacía" % pid)
		r.post("insert_charge")
		var opened := 0.0
		var carried := ""
		for i in 60:
			_frame(s, r)
			opened = maxf(opened, float(s.call("info").door))
			if String(s.call("info").carry) != "":
				carried = String(s.call("info").carry)
		assert_true(opened > 0.1, "%s: la puerta se abre (%s m)" % [pid, opened])
		assert_true(carried != "", "%s: y se ve entrar la carga (%s)" % [pid, carried])
		assert_near(float(s.call("info").door), 0.0, 1e-9, 0.0, "%s: y se cierra" % pid)
		assert_true(bool(s.call("info")[cases[pid]]), "%s: dentro, su carga (%s)" % [pid, cases[pid]])
		s.disconnect("gesture", s.get_signal_connection_list("gesture")[0].callable)
	# un clic en la puerta también la mete
	var r2 := _runner("rubi")
	_wire(s, r2)
	r2.post("apply_recommended")
	r2.post("load_crucible")
	s.call("set_view", "horno", true)
	for i in 3:
		_frame(s, r2)
	var door: Vector2 = s.call("target_screen_point", "ventana")
	_mouse(s, door)
	_mouse(s, door, MOUSE_BUTTON_LEFT, true)
	_mouse(s, door, MOUSE_BUTTON_LEFT, false)
	_frame(s, r2)
	assert_eq(r2.state.charge_inside(), "alimentador", "el clic en la puerta mete la alúmina en la tolva")


## 5m · la cera perdida: el modelo de cera en el banco, el molde revestido, el molde en la bandeja del horno al quemar la cera y en
## la máquina de colar, la colada dentro del molde hasta romperlo y la funda con su bebedero al sacarla.
func test_la_cera_perdida_en_la_escena() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("oro")
	r.post("set_speed", [State.SPEEDS.size() - 1])
	r.post("make_wax")
	_frame(s, r)
	assert_true(bool(s.call("info").wax_model), "el modelo de cera de la funda, en el banco")
	r.post("invest")
	r.post("skip")
	_frame(s, r)
	assert_false(bool(s.call("info").wax_model), "revestido, la cera ya no se ve")
	assert_true(bool(s.call("info").flask), "se ve el molde revestido")
	r.post("apply_recommended")
	r.post("insert_charge")
	_frame(s, r)
	assert_true(bool(s.call("info").flask_oven) and not bool(s.call("info").flask), "el molde, en la bandeja del horno")
	r.post("start")
	for i in 150:
		_frame(s, r)
	assert_true(bool(r.latest().snap.burnout.ok), "la cera, quemada")
	r.post("set_control", ["modo", "fundir_colar"])
	for k: String in ["temp_c", "time_s", "atmosphere"]:
		r.post("set_control", [k, r.state.forge.recommended().fire[k]])
	r.post("load_crucible")
	r.post("insert_charge")
	_frame(s, r)
	assert_true(bool(s.call("info").flask_cast), "el molde, en la máquina de colar")
	r.post("start")
	for i in 200:
		_frame(s, r)
	assert_true(bool(r.latest().snap.fire.ok), "colado: %s" % r.latest().snap.fire.text)
	r.post("cool_piece")
	r.post("skip")
	_frame(s, r)
	assert_true(bool(s.call("info").flask), "fría, la colada sigue dentro del molde")
	assert_eq(String(s.call("info").piece_shape), "", "y no se ve la pieza")
	r.post("divest")
	r.post("skip")
	_frame(s, r)
	assert_false(bool(s.call("info").flask), "roto el molde")
	assert_eq(String(s.call("info").piece_shape), "funda", "sale la funda con la forma de la garra")
	assert_true(bool(s.call("info").sprue), "con su bebedero")
	r.post("set_carve_tool", ["sierra"])
	r.post("carve_pass", [false])
	r.post("skip")
	_frame(s, r)
	assert_false(bool(s.call("info").sprue), "la sierra corta el bebedero")


## 5m · el tallado por pasadas: la pieza en su palo va a la sierra, a la muela de su grano o al eje flexible, y su silueta (la del
## motor) se rehace solo con cada pasada, no en cada fotograma.
func test_el_tallado_por_pasadas_en_su_herramienta() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var r := _runner("zafiro")
	r.post("set_speed", [State.SPEEDS.size() - 1])
	for op: String in ["apply_recommended", "load_crucible", "insert_charge", "start", "skip", "cool_piece", "skip"]:
		r.post(op)
	_frame(s, r)
	r.post("set_carve_tool", ["sierra"])
	r.post("carve_pass", [false])
	_frame(s, r)
	assert_eq(String(s.call("info").piece_at), "sierra", "en la sierra")
	assert_true(bool(s.call("info").dop), "pegada en su palo")
	var at_saw: Vector3 = s.call("info").piece_pos
	assert_true(at_saw.distance_to(Forge3D.SAW_POS) < 0.2, "junto al disco (%s)" % at_saw)
	r.post("skip")
	r.post("carve_pass", [false])
	r.post("skip")
	_frame(s, r)
	assert_eq(String(s.call("info").piece_shape), "tallando", "con el tocho sacado, la silueta del motor")
	var builds := int(s.call("info").mesh_builds)
	for i in 20:
		_frame(s, r)
	assert_eq(int(s.call("info").mesh_builds), builds, "sin pasadas, la misma malla")
	r.post("set_carve_tool", ["muela_gruesa"])
	r.post("carve_pass", [false])
	_frame(s, r)
	assert_eq(String(s.call("info").piece_at), "muela", "en la máquina de muelas")
	assert_eq(int(s.call("info").mesh_builds), builds + 1, "una pasada, una silueta nueva")
	r.post("skip")
	r.post("set_carve_tool", ["fresa"])
	r.post("carve_pass", [false])
	_frame(s, r)
	assert_eq(String(s.call("info").piece_at), "fresa", "y en el eje flexible")


## 5m · la sala (petición 45): ventanas al campo (el vidrio, la hierba hasta el horizonte y el cielo del entorno) y materiales con
## relieve de forge_looks.gd (con su mapa de normales, triplanares), hechos una vez y compartidos entre escenas; los tornillos, en un
## solo MultiMesh.
func test_la_sala_con_ventanas_al_campo_y_materiales_con_relieve() -> void:
	var h := _host()
	var s: Node3D = h[1]
	var world: Node3D = s.get("_world")
	var glass := world.get_node("Paredes").find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as MeshInstance3D).material_override == ForgeLooks.glass())
	assert_eq(glass.size(), 2, "dos ventanas en la pared del fondo")
	var grass: MeshInstance3D = world.get_node("Campo/Hierba")
	assert_true((grass.mesh as PlaneMesh).size.y >= 100.0, "la hierba sigue hasta el horizonte")
	var env := (s.get_node("Entorno") as WorldEnvironment).environment
	assert_true(env.sky.sky_material is ProceduralSkyMaterial, "el cielo de un día claro")
	for id: String in ["madera", "acero", "hierro", "refractario", "ladrillo", "hormigon"]:
		var m := ForgeLooks.material(id)
		assert_true(m.normal_enabled and m.normal_texture != null, "%s: con relieve" % id)
		assert_true(m.uv1_triplanar and m.albedo_texture != null, "%s: con su textura, triplanar" % id)
	var mmi := world.get_node("Tornillos") as MultiMeshInstance3D
	assert_true(mmi.multimesh.instance_count >= 24, "los tornillos de las mesas y del horno (%d), en un MultiMesh" % mmi.multimesh.instance_count)
	var built := ForgeLooks.built
	var h2 := _host()
	assert_true(h2[1] != null, "otra escena")
	assert_eq(ForgeLooks.built, built, "otra escena no hace materiales nuevos: se comparten")


func test_coste_por_fotograma() -> void:
	for q: String in ["escritorio", "movil"]:
		var h := _host()
		var s: Node3D = h[1]
		s.call("set_quality", q)
		var r := _runner("rubi")
		r.post("apply_recommended")
		r.post("load_crucible")
		r.post("insert_charge")
		r.post("start")
		s.call("show_view", r.latest())
		s.call("set_view", "dentro", true)
		for i in 20:
			_frame(s, r)
		var f0 := int(s.call("info").frames)
		var sum0 := float(s.call("info").update_ms_avg) * float(f0)
		# la vista nueva de cada fotograma (show_view), aparte de advance()
		var show_us := 0
		var show_max := 0
		for i in 240:
			s.call("advance", FRAME)
			r.post("tick", [FRAME])
			var t0 := Time.get_ticks_usec()
			s.call("show_view", r.latest())
			var us := Time.get_ticks_usec() - t0
			show_us += us
			show_max = maxi(show_max, us)
		var info: Dictionary = s.call("info")
		var n := int(info.frames) - f0
		var avg := (float(info.update_ms_avg) * float(info.frames) - sum0) / float(maxi(n, 1))
		var show_avg := float(show_us) / 240.0 / 1000.0
		print("    (coste) %s: %s ms de media por fotograma de la escena (máximo %s ms) y %s ms la vista nueva (máximo %s ms)" % [q, Js.to_fixed(avg, 3), Js.to_fixed(float(info.update_ms_max), 3), Js.to_fixed(show_avg, 3), Js.to_fixed(float(show_max) / 1000.0, 3)])
		assert_true(avg < BUDGET_MS, "%s: %s ms de media (presupuesto %s ms)" % [q, avg, BUDGET_MS])
		assert_true(show_avg < BUDGET_MS, "%s: la vista nueva, %s ms de media" % [q, show_avg])


const Js = preload("res://core/shared/js.gd")
