## Demo guionizada de la cetrería (unidades 5b y 5c) para las capturas: la sección del laboratorio en su página
## «Cetrería», manejada como una persona: el ratón (se ve el puntero) coge las herramientas de la bandeja y las lleva sobre
## la garra en la vista 3D, y los botones y las teclas de la página hacen el resto. Siete escenas y cinco más con --caso:
##   7 · el escenario y los animales enteros (unidad 5c): el águila encapuchada y envuelta en el banco del centro de
##       cetrería, el búho y el halcón; el tigre y el oso anestesiados en la mesa de la clínica; el velocirraptor, el de la
##       reconstrucción y el de cine;
##   8 · las patas (unidad 5c): limar una garra de la pata derecha y otra de la izquierda del águila, la garra siguiente
##       con G, y una pata trasera del tigre;
##   9 · la amoladora con protector (unidad 5c): cogerla del carro, encenderla con un clic en el aire, sus cuatro
##       velocidades (Q), apretar con el deslizador de la vista y trabajar la punta de una garra del tigre;
##   1 · el tutorial con el águila: preparar (capucha y toalla), remojar, cortar poco a poco con el cortaúñas de
##       guillotina, limar la cara del corte de frente hasta que no quede grieta, limar de la base a la punta a 22° con la
##       lima gruesa y dar la punta con la fina hasta que quede algo más fina que la natural, la crema y el informe
##       («perfecta y afilada como una daga»);
##   2 · sangra: la tenaza corta de más y salta «Si sangra»; hemostático y presión (con el reloj a ×10) y clorhexidina;
##   3 · se quiebra: seca, la tenaza raja la garra hasta la carne viva; hemostático y la reconstrucción de metacrilato;
##   4 · se mella: una garra reforjada de vidrio con la lima de diamante a 20°: la punta se mella (el motor solo mella las
##       garras frágiles; una de queratina demasiado fina queda «afilada como una daga, pero frágil»);
##   5 · el tigre anestesiado: su garra clara deja ver la carne viva a trasluz, y el calor del torno (solo con --caso=5);
##   6 · una garra reforjada de acero con el torno: las chispas (solo con --caso=6);
##  10 · los animales enteros en alta definición (unidad 5i; solo con --caso=10): cada uno de lejos (la vista del animal) y
##       de cerca (el cuerpo y la cabeza): el águila encapuchada y envuelta, el búho despierto, el halcón con la
##       mascarilla, el tigre con la mascarilla y la pinza, el oso sedado y los dos velocirraptores.
##  11 · el limado según la dureza (unidad 5l): sobre una garra reforjada de zafiro, la lima de acero resbala sin polvo y
##       chirría, la de diamante la muerde (polvo blanco), el tambor de corindón casi no la muerde, calienta y se vidria (la
##       banda brillante en la bandeja) y una nueva (N) vuelve a cortar, hasta que el zafiro la vidria otra vez (solo con
##       --caso=11);
##  12 · las chispas de cada metal (unidad 5l): el titanio (blancas), el metal duro (casi ninguna: pocas, cortas y
##       anaranjadas) y el oro (ninguna), con el torno, y el acero (solo con --caso=12).
##  13 · colocar a mano una funda de acero con epoxi (unidad 5o; solo con --caso=13): la del laboratorio de la reforja (la
##       5m: colada, limada, pulida y probada en la garra) llega sin pegar, se limpia con alcohol,
##       se lija, se purga la cánula, se pone el adhesivo, se coge la pieza, se gira al eje, se aprieta sobre la garra y se
##       venda (el reloj a ×3600 deja esperar la fijación), lo que rebosa y el escalón con la lima, la forma, la punta y la
##       prueba;
##  14 · la prótesis de acrílico dental en la garra rota (unidad 5o; solo con --caso=14): la tenaza la raja, hemostasia,
##       limpiar y lijar, mezclar en su proporción, esperar a la masa, capas con la espátula (el calor del fraguado en la
##       carne viva), lo que rebosa en fresco, limar hasta la forma y la punta, y probar;
##  15 · la resina con la lámpara (unidad 5o; solo con --caso=15): la misma garra rota, capas de resina curadas con la
##       lámpara azul casi tocando (con los ojos tapados y el filtro), limar y probar;
##  16 · la hoz del velocirraptor de cerca (unidad 5o, petición 48; solo con --caso=16): su base, la del núcleo óseo medido
##       más el estuche.
##  17 · la cetrería guiada (petición 51; solo con --caso=17): la barra del estado del animal encima de la vista; la rapaz sin
##       capucha se inquieta, el tutorial resalta «Capucha y toalla»; se corta de más y «Si sangra» va en su orden (coger el
##       polvo, apretar con su cuenta de segundos, soltar antes de tiempo y lo dice, y desinfectar); y el tigre sin sedar se
##       revuelve al segundo toque: la sesión se para con la explicación;
##  18 · las limas, claras (petición 51; solo con --caso=18): en una garra de zafiro, la lima de acero no muerde y dice por qué y
##       qué coger; la de diamante gruesa desbasta y la línea dice lo que ha quitado, la superficie y cuánto falta; la fina pule.
##  19 · el guiado (unidad 5y; solo con --caso=19): con el tutorial y «Guiado» activados, cada acción señalada con su aviso
##       corto sobre la vista: el mando del panel con su borde (capucha y toalla), la herramienta de la bandeja con su
##       contorno (la vista general), la zona de la garra de cerca (cortar, la grieta, dar la punta), el tigre (la carne viva a
##       trasluz y «Si sangra»), el velocirraptor de cine, la rapaz que se estresa (la pausa) y la que se suelta («Recogerla y
##       encapucharla»). Cada toma, ~1,6 s; la salida dice en qué segundo empieza cada una (× 30 = el fotograma).
## Orden: 7, 8, 9, 1, 2, 3 y 4.
## Captura:   node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_cetreria.tscn --frames=3300 --out=<carpeta>
## Teléfono:  … con --phone (390 × 844: una columna). Un caso: … -- --caso=3 (y menos fotogramas).
## El tiempo es la suma de los delta (Movie Maker los da fijos) y el estado va en el hilo de la interfaz, así que cada
## captura sale igual. No guarda ajustes. Al final escribe el coste de la escena 3D por fotograma.
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const ForgeState = preload("res://core/lab/claw_forge_state.gd")

const SCENES := [
	"El tutorial con el águila: preparar, recortar, limar, dar la punta y terminar",
	"Error: se corta de más y sangra (hemostático, presión y clorhexidina)",
	"Error: seca, la tenaza la raja hasta la carne viva (y se reconstruye)",
	"Error: una garra reforjada de vidrio, demasiado fina, se mella",
	"El tigre anestesiado: la carne viva a trasluz y el calor del torno",
	"Una garra reforjada de acero con el torno: chispas",
	"El escenario y los animales enteros: el centro de cetrería y la clínica veterinaria",
	"Las patas: cada garra de cada pata, su propio ensayo",
	"La amoladora con protector: encenderla, sus velocidades y la presión",
	"Los animales enteros en alta definición: de lejos y de cerca",
	"El limado según la dureza: lo que muerde, lo que resbala y lo que se gasta",
	"Las chispas de cada metal: titanio, metal duro y oro",
	"Colocar a mano una funda de acero con epoxi: preparar, pegar, sujetar, limar y probar",
	"La prótesis de acrílico dental en la garra rota: mezclar, capas, el calor del fraguado y limar",
	"Una capa de resina con la lámpara azul: capas finas, la dosis de luz y limar",
	"La hoz del velocirraptor de cerca: la base del núcleo medido más el estuche",
	"La cetrería guiada: la barra del animal, el tutorial paso a paso y «Si sangra» con su cuenta",
	"Las limas, claras: para qué sirve cada una, qué ha hecho cada pasada y por qué no muerde",
	"El guiado: cada acción señalada, con su aviso corto, en la escena y en el panel",
]
## Las escenas de la captura completa, en orden (5, 6, 10, 11 y 12, solo con --caso).
const MAIN_ORDER := [6, 7, 8, 0, 1, 2, 3]
const F := 1.0 / 30.0

var lab: Control
var page: Control
var scene: Node3D
var caption: Label
var cursor: Panel
var _t := 0.0
var _only := -1
var _pointer := Vector2(-1.0, -1.0)
var _down := false
var _upd_max := 0.0
var _upd_sum := 0.0
var _upd_n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	page = lab.care_page
	page.threaded = false
	lab.set_page(lab.PAGE_CARE, false)
	scene = page.scene
	_build_overlay()
	_run()


func _build_overlay() -> void:
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Cetrería", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 60.0, 620.0)
	pill.add_child(caption)
	add_child(pill)
	pill.position = Vector2(14, vs.y - 84.0) if vs.x < 600.0 else Vector2(16, vs.y - 64.0)
	cursor = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55)
	sb.border_color = Color(0.1, 0.05, 0.12, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(11)
	cursor.add_theme_stylebox_override("panel", sb)
	cursor.size = Vector2(22, 22)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	add_child(cursor)


func _process(delta: float) -> void:
	_t += delta
	if scene != null:
		var inf: Dictionary = scene.call("info")
		_upd_max = maxf(_upd_max, float(inf.update_ms_max))
		_upd_sum = float(inf.update_ms_avg)
		_upd_n = int(inf.frames)


# ─────────────────────────────── guion ───────────────────────────────

func _run() -> void:
	await get_tree().process_frame
	var order: Array = MAIN_ORDER if _only < 0 else [_only]
	for i: int in order:
		await call("_scene_%d" % (i + 1))
	_caption_text("Fin · coste de la escena 3D: %s ms de media por fotograma (máximo %s ms)" % [_fmt(_upd_sum), _fmt(_upd_max)])
	print("Coste de la escena 3D: %s ms de media por fotograma, máximo %s ms (%d fotogramas)." % [_fmt(_upd_sum), _fmt(_upd_max), _upd_n])
	page.call("set_active", false)


static func _fmt(x: float) -> String:
	return String.num(x, 2)


func _caption(i: int, extra := "") -> void:
	_caption_text("%d · %s%s" % [i + 1, SCENES[i], (" · " + extra) if extra != "" else ""])


func _caption_text(t: String) -> void:
	caption.text = t


func _log(t: String) -> void:
	print("[demo %s s] %s" % [String.num(_t, 1), t])


## Lo que ha pasado en la escena (en la salida de la captura, para revisarla).
func _summary(what: String) -> void:
	var sn: Dictionary = _st().care.snapshot()
	var rep: Dictionary = _st().care.report()
	_log("%s: %s · sangra %s (ha sangrado %s, %s) · rota %s, reconstruida %s, mellas %s · %s %s" % [what,
		str(_calls_of("clip").map(func(c: Array) -> String: return "%s %s mm" % [c[1].tool, String.num(float(c[1].remove_mm), 2)])),
		sn.bleeding.active, sn.bleeding.bled, sn.bleeding.agent, sn.damage.broken, sn.damage.repaired, sn.damage.chips,
		rep.verdict, rep.gradeText])


func _calls_of(op: String) -> Array:
	return _st().calls.filter(func(c: Array) -> bool: return String(c[0]) == op)


func _wait(secs: float) -> void:
	var end := _t + secs
	while _t < end:
		await get_tree().process_frame


func _st() -> State:
	return page.runner.state


func _apex() -> float:
	return _st().care.apex_mm()


func _press(b: BaseButton) -> void:
	if b != null and b.is_visible_in_tree() and not b.disabled:
		b.pressed.emit()


## Lleva una tarjeta a la vista: en escritorio, en la columna de las tarjetas (con su propio desplazamiento); en el
## teléfono, en la sección.
func _reveal(c: Control) -> void:
	var rs: ScrollContainer = page.right_scroll
	if rs.visible and rs.is_ancestor_of(c):
		var y := c.get_global_rect().position.y - (page.right as Control).get_global_rect().position.y - 8.0
		var tw := create_tween()
		tw.tween_property(rs, "scroll_vertical", int(maxf(y, 0.0)), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		lab.call("scroll_to", c, 8.0)


func _seg(seg: Control, id: String) -> void:
	var b: Button = seg.buttons.get(id)
	if b != null:
		b.pressed.emit()


func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	page.call("handle_key", k)


## El puntero de la vista 3D (px del visor) y el círculo que lo enseña en pantalla.
func _set_pointer(p: Vector2) -> void:
	_pointer = p
	var view3d: Control = page.view3d
	cursor.visible = true
	cursor.position = view3d.get_global_rect().position + p - cursor.size * 0.5
	var mm := InputEventMouseMotion.new()
	mm.position = p
	scene.call("handle_pointer", mm)


func _button(pressed: bool) -> void:
	_down = pressed
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = _pointer
	scene.call("handle_pointer", mb)
	var sb := cursor.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = Color(Palette.color("gold"), 0.8) if pressed else Color(1, 1, 1, 0.55)


## Lleva el puntero hasta p en secs (con la aceleración de una mano).
func _move(target: Vector2, secs: float) -> void:
	var a := _pointer if _pointer.x >= 0.0 else target + Vector2(120.0, 80.0)
	var t0 := _t
	while _t - t0 < secs:
		var k := clampf((_t - t0) / secs, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		_set_pointer(a.lerp(target, e))
		await get_tree().process_frame
	_set_pointer(target)


## Coge una herramienta de la bandeja con el ratón (clic sobre ella); si la bandeja no se ve, mira antes a la mesa
## (la vista general) y luego vuelve.
func _pick(id: String) -> void:
	var p: Vector2 = scene.call("tray_screen_point", id)
	var room := Rect2(Vector2(8.0, 8.0), (page.view3d as Control).size - Vector2(16.0, 16.0))
	var back := ""
	if not room.has_point(p):
		back = String(page.view)
		page.call("set_view", "general")
		await _wait(1.0)
	# el puntero va hacia donde está la herramienta en cada fotograma (la cámara aún puede estar llegando)
	var a := _pointer if _pointer.x >= 0.0 else Vector2(60.0, 60.0)
	var t0 := _t
	while _t - t0 < 0.45:
		var k := clampf((_t - t0) / 0.45, 0.0, 1.0)
		_set_pointer(a.lerp(scene.call("tray_screen_point", id), k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame
	_set_pointer(scene.call("tray_screen_point", id))
	await get_tree().process_frame
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(0.25)
	if String(_st().tool) != id:
		_log("no he cogido %s (en la mano: %s)" % [id, _st().tool])
	if back != "":
		page.call("set_view", back)
		await _wait(1.0)


## Punto de la pantalla del eje de la garra a d mm de la punta: el rayo entra por la cara que mira a la cámara a esa
## altura (por el borde, rozaría y tocaría más atrás).
func _claw_pt(d_from_tip: float, a := 0.0) -> Vector2:
	return scene.call("claw_screen_point", maxf(_apex() - d_from_tip, 0.0), a, 0.0)


## Dirección en la pantalla de la garra hacia la punta (px por mm) en d mm de la punta.
func _claw_dir(d_from_tip: float) -> Vector2:
	return _claw_pt(d_from_tip - 0.5) - _claw_pt(d_from_tip + 0.5)


## Espera (como mucho un segundo) a que el puntero, apuntando a d mm de la punta, toque la garra: la cámara puede estar
## aún llegando a su vista.
func _settle(d_from_tip: float, a := 0.0) -> void:
	for i in 30:
		var p := _aim(d_from_tip, a)
		_set_pointer(p)
		if not (scene.call("hit_at", p) as Dictionary).is_empty():
			return
		await get_tree().process_frame


## El punto de la pantalla donde el rayo del puntero toca la garra a d mm de la punta: el eje a esa altura y unos
## retoques a lo largo de la garra (de lado, el rayo entra por la cara de delante algo más atrás).
func _aim(d_from_tip: float, a := 0.0) -> Vector2:
	var want := maxf(_apex() - d_from_tip, 0.0)
	var p := _claw_pt(d_from_tip, a)
	for i in 6:
		var h: Dictionary = scene.call("hit_at", p)
		if h.is_empty():
			break
		var err := want - float(h.s)
		if absf(err) < 0.05:
			break
		p += _claw_dir(maxf(_apex() - float(h.s), 0.0)) * err
	return p


## Una pasada de lima: aprieta a d mm de la punta y arrastra mm milímetros en la dirección de la garra hacia la punta (de
## la base a la punta), en secs, sin salir del visor; luego levanta.
func _stroke(d_from_tip: float, mm: float, secs: float) -> void:
	await _move(_aim(d_from_tip), 0.12)
	await _settle(d_from_tip)
	var start := _pointer
	_button(true)
	var dir := _claw_dir(d_from_tip)
	var px_mm := dir.length()
	dir = dir / px_mm if px_mm > 0.01 else Vector2.RIGHT
	var end := start + dir * mm * maxf(px_mm, 1.0)
	var room := Rect2(Vector2(10.0, 10.0), (page.view3d as Control).size - Vector2(20.0, 20.0))
	end = end.clamp(room.position, room.end)
	var t0 := _t
	while _t - t0 < secs:
		var k := clampf((_t - t0) / secs, 0.0, 1.0)
		_set_pointer(start.lerp(end, k))
		await get_tree().process_frame
	_set_pointer(end)
	await get_tree().process_frame
	_button(false)
	await get_tree().process_frame


## Mantiene pulsado sobre la garra a d mm de la punta durante secs (cortaúñas, torno, hemostático).
func _hold(d_from_tip: float, secs: float, a := 0.0) -> void:
	await _move(_aim(d_from_tip, a), 0.3)
	await _settle(d_from_tip, a)
	_button(true)
	var t0 := _t
	while _t - t0 < secs:
		_set_pointer(_aim(d_from_tip, a))
		await get_tree().process_frame
	_button(false)
	await get_tree().process_frame


func _tap(d_from_tip: float) -> void:
	await _move(_aim(d_from_tip), 0.3)
	await _settle(d_from_tip)
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(0.25)


## Lleva el tutorial hasta el paso sid del proceso pid con sus botones: la píldora del proceso y «Siguiente».
func _tut_to(pid: String, sid := "") -> void:
	for i in 14:
		var tv: Dictionary = _st().tutorial_view()
		var here := String(tv.process) == pid
		if here and (sid == "" or String(tv.step.get("id", "")) == sid):
			return
		if here:
			_press(page.tut_next)
		else:
			_press(page.tut_flow.get_child(_st().flow().find(pid)) as BaseButton)
		await _wait(0.35)
	_log("el tutorial no llega a %s/%s" % [pid, sid])


# ─────────────────────────────── escenas ───────────────────────────────

func _scene_1() -> void:
	_caption(0, "la primera vez: «¿Primera vez? Empieza aquí»")
	page.call("set_view", "general")
	await _wait(1.6)
	for b: Node in page.intro_box.find_children("*", "Button", true, false):
		if (b as Button).text == "Empezar el tutorial":
			(b as Button).pressed.emit()
	await _wait(0.4)
	_caption(0, "preparar: capucha y toalla")
	await _wait(0.8)
	await _tut_to("preparar", "toalla")
	_seg(page.sedation_seg, "sujecion")
	await _wait(1.0)
	await _tut_to("inspeccionar")
	_caption(0, "inspeccionar: la garra es oscura y la carne viva no se ve")
	page.call("set_view", "garra")
	await _wait(1.6)
	await _tut_to("recortar", "remojar")
	_caption(0, "remojar y cortar poco a poco con el cortaúñas de guillotina")
	await _pick("agua")
	await _tap(4.0)
	await _wait(0.4)
	await _tut_to("recortar", "poco")
	_key(KEY_4)
	await _wait(0.3)
	await _hold(1.5, State.CLIP_CLOSE_S + 0.25)
	await _wait(0.8)
	await _hold(1.2, State.CLIP_CLOSE_S + 0.25)
	_log("cortes: %s mm" % str(_calls_of("clip").map(func(c: Array) -> String: return String.num(float(c[1].remove_mm), 2))))
	await _wait(0.6)
	await _tut_to("recortar", "cara")
	_seg(page.humidity_seg, "natural")
	_caption(0, "limar la cara del corte de frente, a 90°, hasta que no quede grieta")
	_key(KEY_1)
	page.angle_slider.slider.value = 90.0
	page.force_slider.slider.value = State.force_to_t(10.0)
	await _wait(0.4)
	var k := 0
	while not _st().care.check("sin_grieta") and k < 14:
		await _stroke(1.0, 12.0, 0.25)
		k += 1
	_log("cara del corte: %d pasadas, sin grieta %s, quedan %s mm" % [k, _st().care.check("sin_grieta"), String.num(_st().care.overgrowth_left_mm(), 2)])
	await _wait(0.4)
	await _tut_to("limar", "curva")
	_caption(0, "limar de la base a la punta siguiendo la curva, a 22°, con la lima gruesa")
	page.angle_slider.slider.value = 22.0
	await _wait(0.4)
	k = 0
	while float(_st().care.tip_state().ratio) >= 2.0 and k < 40:
		await _stroke(1.5, 12.0, 0.25)
		k += 1
	_log("faceta gruesa: %d pasadas, punta ×%s, quedan %s mm" % [k, String.num(float(_st().care.tip_state().ratio), 2), String.num(_st().care.overgrowth_left_mm(), 2)])
	await _tut_to("afilar", "lupa")
	_caption(0, "dar la punta con la lima fina, mirando la lupa: parar cuando quede algo más fina que la natural")
	_key(KEY_2)
	page.force_slider.slider.value = State.force_to_t(5.0)
	await _wait(0.5)
	k = 0
	while float(_st().care.tip_state().ratio) >= 1.0 and k < 24:
		await _stroke(0.8, 3.0, 0.2)
		k += 1
		await _wait(0.1)
	_log("faceta fina: %d pasadas, punta ×%s, aguanta %s" % [k, String.num(float(_st().care.tip_state().ratio), 2), String.num(float(_st().care.tip_state().strengthRatio), 2)])
	await _wait(0.8)
	page.call("set_view", "seccion")
	await _wait(1.6)
	page.call("set_view", "garra")
	await _tut_to("terminar", "crema")
	_caption(0, "terminar: crema de lanolina en la garra")
	await _pick("crema")
	await _tap(5.0)
	await _wait(0.6)
	_press(page.finish_button)
	_caption(0, "el informe: la garra antes → después, la nota y los consejos")
	await _wait(0.2)
	_reveal(page.report_card)
	var rep: Dictionary = _st().view().get("report", {})
	_log("informe: %s %s" % [rep.get("verdict", "?"), rep.get("gradeText", "?")])
	await _wait(3.4)
	_caption(0, "«Valores y fuentes»: cada dato con su calidad y su fuente")
	page.values_toggle.pressed.emit()
	await _wait(0.2)
	_reveal(page.values_card)
	await _wait(2.6)


func _scene_2() -> void:
	_key(KEY_R)
	_caption(1)
	_reveal(page.tut_card)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	await _wait(0.5)
	await _pick("tenaza")
	await _hold(_st().care.quick_cover_mm() + 1.0, State.CLIP_CLOSE_S + 0.25)
	_caption(1, "qué ha pasado y cómo se arregla")
	_reveal(page.tut_card)
	await _wait(2.4)
	_reveal(page.view_box)
	_caption(1, "polvo hemostático y presión (reloj ×10)")
	_seg(page.clock_seg, "10")
	await _pick("hemostatico")
	await _hold(0.6, 3.6)
	_seg(page.clock_seg, "1")
	await _wait(0.6)
	_caption(1, "y clorhexidina al 0,05 %")
	await _pick("clorhexidina")
	await _tap(2.0)
	await _wait(1.0)
	_summary("sangra")


func _scene_3() -> void:
	_key(KEY_R)
	_caption(2)
	_reveal(page.tut_card)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	_seg(page.humidity_seg, "seca")
	await _wait(0.5)
	await _pick("tenaza")
	await _hold(_st().care.quick_cover_mm() - 0.4, State.CLIP_CLOSE_S + 0.25)
	_reveal(page.tut_card)
	await _wait(1.6)
	_reveal(page.view_box)
	page.call("set_view", "seccion")
	await _wait(1.6)
	page.call("set_view", "garra")
	_caption(2, "hemostático y presión, y la reconstrucción con metacrilato")
	_seg(page.clock_seg, "10")
	await _pick("hemostatico")
	await _hold(0.6, 3.6)
	_seg(page.clock_seg, "1")
	await _pick("metacrilato")
	await _tap(0.5)
	await _wait(1.8)
	_summary("se quiebra")


func _scene_4() -> void:
	_caption(3, "el material, a la vista: una garra reforjada de vidrio")
	_reveal(page.inlay_flow)
	await _wait(0.8)
	_select_inlay("vidrio")
	await _wait(0.1)
	_reveal(page.inlay_flow)
	await _wait(1.2)
	_reveal(page.tut_card)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	await _pick("lima_diamante_fina")
	page.angle_slider.slider.value = 20.0
	page.force_slider.slider.value = State.force_to_t(3.0)
	await _wait(0.3)
	var k := 0
	while _st().care.snapshot().damage.chips == 0 and k < 6:
		await _stroke(1.5, 6.0, 0.35)
		k += 1
	_reveal(page.tut_card)
	await _wait(1.8)
	_press(page.finish_button)
	await _wait(0.2)
	_reveal(page.report_card)
	_summary("se mella")
	await _wait(2.6)


func _scene_5() -> void:
	_caption(4)
	_seg(page.animal_seg, "tigre")
	await _wait(0.4)
	_seg(page.sedation_seg, "anestesia")
	page.call("set_view", "garra")
	await _wait(1.2)
	await _pick("torno")
	_key(KEY_E)
	page.force_slider.slider.value = State.force_to_t(3.0)
	page.angle_slider.slider.value = 45.0
	# el error del tutorial («Solo la punta»): el tambor a 6500 rpm en el flanco, a 2 mm de donde acaba la carne viva,
	# con el reloj a ×5 (15 s de contacto seguido): la cara se calienta (a 13 000 rpm el motor se dispara: ver el
	# informe de la unidad)
	_caption(4, "el tambor en el flanco, cerca de la carne viva (reloj ×5)")
	_seg(page.clock_seg, "5")
	await _hold(_apex() - (float(_st().care.snapshot().claw.quickMm) - 2.0), 3.0)
	_seg(page.clock_seg, "1")
	var th: Dictionary = _st().care.snapshot().thermal
	_log("torno en el tigre: la cara a %s °C, la carne viva a %s °C (pico)" % [String.num(float(th.faceC), 1), String.num(float(th.peakQuickC), 1)])
	await _wait(2.0)


func _scene_6() -> void:
	_caption(5)
	_select_inlay("acero")
	await _wait(0.4)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	await _pick("torno")
	_key(KEY_E)
	_key(KEY_Q)
	page.force_slider.slider.value = State.force_to_t(4.0)
	await _hold(1.5, 1.5)
	_log("torno en el acero: %d chispas en el aire (en la mano %s, encendido %s, %d toques)" % [int(scene.call("info").sparks), _st().tool, _st().rotary_on, _calls_of("file").size()])
	await _hold(1.5, 1.0)
	await _wait(1.0)


func _select_inlay(id: String) -> void:
	var b: BaseButton = page.inlay_pills.get(id)
	if b != null:
		b.pressed.emit()


func _raptor(id: String) -> void:
	var b: BaseButton = page.raptor_pills.get(id)
	if b != null:
		b.pressed.emit()


func _scene_7() -> void:
	_caption(6, "el águila, encapuchada y envuelta en la toalla, en el banco del centro de cetrería")
	_seg(page.animal_seg, "rapaz")
	_raptor("aguila")
	await _wait(0.2)
	_seg(page.sedation_seg, "sujecion")
	page.call("set_view", "animal")
	await _wait(2.4)
	for pair: Array in [["buho", "el búho real"], ["halcon", "el halcón peregrino"]]:
		_raptor(String(pair[0]))
		_caption(6, "%s: cada rapaz, su modelo y su garra" % pair[1])
		await _wait(0.2)
		_seg(page.sedation_seg, "sujecion")
		await _wait(1.6)
	_raptor("aguila")
	_caption(6, "el tigre, anestesiado en la mesa de quirófano de la clínica veterinaria")
	_seg(page.animal_seg, "tigre")
	await _wait(0.2)
	_seg(page.sedation_seg, "anestesia")
	page.call("set_view", "animal")
	await _wait(2.4)
	_caption(6, "el oso pardo, anestesiado: sus cuatro patas hacia el borde de la mesa")
	_seg(page.animal_seg, "oso")
	await _wait(0.2)
	_seg(page.sedation_seg, "anestesia")
	await _wait(2.2)
	_caption(6, "el velocirraptor (reconstrucción), anestesiado: un experimento mental")
	_seg(page.animal_seg, "velociraptor")
	await _wait(0.2)
	_seg(page.sedation_seg, "anestesia")
	await _wait(2.0)
	_caption(6, "y el de película (solo el dibujo: la garra y su física son las de la reconstrucción)")
	_seg(page.model_choice, "pelicula")
	await _wait(2.0)
	_seg(page.model_choice, "reconstruccion")
	await _wait(0.4)


func _scene_8() -> void:
	_caption(7, "el águila: una garra de la pata derecha")
	_seg(page.animal_seg, "rapaz")
	_raptor("aguila")
	await _wait(0.2)
	_seg(page.sedation_seg, "sujecion")
	page.call("set_view", "general")
	await _wait(1.4)
	await _pick("lima_fina")
	page.call("set_view", "garra")
	page.angle_slider.slider.value = 30.0
	page.force_slider.slider.value = State.force_to_t(5.0)
	await _wait(1.0)
	for k in 3:
		await _stroke(1.2, 6.0, 0.25)
	_caption(7, "la pata izquierda: la cámara va a la pata elegida")
	_reveal(page.paw_box)
	_seg(page.paw_choices["rapaz"], "izquierda")
	await _wait(1.6)
	for k in 3:
		await _stroke(1.2, 6.0, 0.25)
	_caption(7, "G: la garra siguiente de la misma pata")
	_key(KEY_G)
	await _wait(1.6)
	page.call("set_view", "general")
	_caption(7, "el tigre: cuatro patas; la trasera izquierda")
	_seg(page.animal_seg, "tigre")
	await _wait(0.2)
	_seg(page.sedation_seg, "anestesia")
	_seg(page.paw_choices["tigre"], "trasera_izquierda")
	await _wait(1.8)
	page.call("set_view", "garra")
	await _wait(1.6)
	_summary("patas")


## La cámara, de cerca sobre una herramienta de la bandeja (solo la demo: la órbita de la escena).
func _look_at_tool(id: String, dist: float, yaw: float, pitch: float) -> void:
	var slots: Dictionary = scene.get("_slots")
	if not slots.has(id):
		return
	var at: Vector3 = (slots[id] as Transform3D).origin
	(scene.get("_rig") as Node).call("set_orbit", at, yaw, pitch, dist, 34.0, false)


func _scene_9() -> void:
	_caption(8, "el tigre anestesiado; en el carro, las herramientas: limas con su picado y su mango, el torno con su base de carga y la amoladora con su protector")
	_seg(page.animal_seg, "tigre")
	await _wait(0.2)
	_seg(page.sedation_seg, "anestesia")
	page.call("set_view", "general")
	await _wait(0.6)
	_look_at_tool("lima_diamante_fina", 0.42, 20.0, 50.0)
	await _wait(2.2)
	_look_at_tool("amoladora", 0.26, -10.0, 38.0)
	await _wait(2.0)
	_caption(8, "coger la amoladora del carro")
	page.call("set_view", "general")
	await _wait(1.4)
	await _pick("amoladora")
	page.call("set_view", "garra")
	await _wait(1.2)
	_caption(8, "un clic en el aire: el interruptor (arranca a 8000 rpm)")
	await _move(Vector2(40.0, 140.0), 0.3)
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(1.0)
	_caption(8, "apretar con el deslizador de la vista y tocar la punta unos segundos")
	page.touch_force.value = State.force_to_t(1.5)
	await _hold(0.6, 1.6)
	await _wait(0.5)
	_caption(8, "Q: más velocidad (14 000, 21 000 y 25 000 rpm): suena más agudo y calienta más")
	for i in 3:
		_key(KEY_Q)
		await _wait(0.5)
	page.touch_force.value = State.force_to_t(4.0)
	await _hold(0.6, 1.4)
	await _wait(0.4)
	_caption(8, "y un clic en el aire para apagarla")
	await _move(Vector2(40.0, 140.0), 0.3)
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(1.4)
	var th: Dictionary = _st().care.snapshot().thermal
	_log("amoladora en el tigre: %d toques, la cara a %s °C, la carne viva a %s °C (pico)" % [_calls_of("file").size(), String.num(float(th.faceC), 1), String.num(float(th.peakQuickC), 1)])


## La cámara, de cerca sobre el animal (solo la demo: la órbita de la escena): «cabeza» (a k veces el largo de su cabeza) o
## «cuerpo» (el centro del animal, a k veces su largo); al momento.
func _look_at_animal(part: String, k: float, yaw: float, pitch: float) -> void:
	var paw: Dictionary = scene.get("_paw")
	var body: Dictionary = paw.get("body", {})
	var box: AABB = paw.get("box", AABB())
	var at := box.get_center() + (paw.get("offset", Vector3.ZERO) as Vector3)
	var dist := box.size.z * k
	var head: Node3D = body.get("head")
	if head != null:
		if part == "cabeza":
			at = head.global_position
			dist = (body.get("head_size", Vector3(0.14, 0.1, 0.1)) as Vector3).x * k
		else:
			# entre la cabeza y el centro: el pecho, los hombros y el ala o el brazo
			at = head.global_position.lerp(at, 0.5)
	(scene.get("_rig") as Node).call("set_orbit", at, yaw, pitch, dist, 34.0, true)


func _scene_10() -> void:
	var cases := [
		["rapaz", "aguila", "", "sujecion", "el águila real, encapuchada y envuelta en la toalla, en el banco del centro de cetrería"],
		["rapaz", "buho", "", "libre", "el búho real, despierto: el disco de la cara, los penachos y los ojos con brillo"],
		["rapaz", "halcon", "", "anestesia", "el halcón peregrino, anestesiado: la mascarilla sobre el pico y la toalla"],
		["tigre", "", "", "anestesia", "el tigre anestesiado en la clínica: el pelo por capas, las rayas, la mascarilla y la pinza en la lengua"],
		["oso", "", "", "sedacion", "el oso pardo, sedado: el pelo largo con las puntas canosas y la manga de cada pata"],
		["velociraptor", "", "reconstruccion", "anestesia", "el velocirraptor de la reconstrucción: plumas en capas, alas en los brazos y el abanico de la cola"],
		["velociraptor", "", "pelicula", "libre", "el de película: escamas con rayas, dientes y la pupila en rendija"],
	]
	page.call("set_view", "animal")
	for c: Array in cases:
		_caption(9, String(c[4]))
		_seg(page.animal_seg, String(c[0]))
		if String(c[1]) != "":
			_raptor(String(c[1]))
		if String(c[2]) != "":
			_seg(page.model_choice, String(c[2]))
		# el velocirraptor cambia de dibujo después de cambiar de animal: espera a que la escena lo tenga
		await _wait(0.5 if String(c[2]) == "" else 1.2)
		_seg(page.sedation_seg, String(c[3]))
		await _wait(0.2)
		scene.call("set_view", "animal", true)
		await _wait(0.6)
		_log("5i: %s %s de lejos hasta el fotograma %d" % [c[0], c[1] if String(c[1]) != "" else c[2], Engine.get_process_frames()])
		_look_at_animal("cuerpo", 0.36, 62.0, 50.0)
		await _wait(0.6)
		_log("5i: %s %s, el cuerpo de cerca hasta el fotograma %d" % [c[0], c[1] if String(c[1]) != "" else c[2], Engine.get_process_frames()])
		_look_at_animal("cabeza", 3.0, 72.0, 36.0)
		await _wait(0.6)
		_log("5i: %s %s, la cabeza de cerca hasta el fotograma %d" % [c[0], c[1] if String(c[1]) != "" else c[2], Engine.get_process_frames()])
	_seg(page.model_choice, "reconstruccion")
	await _wait(0.2)


func _scene_11() -> void:
	_caption(10, "una garra reforjada de zafiro (2000 HV)")
	_select_inlay("zafiro")
	await _wait(0.4)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	await _wait(0.8)
	_caption(10, "la lima de acero (700 HV) no la muerde: resbala sin polvo, chirría y avisa")
	await _pick("lima_bastarda")
	page.force_slider.slider.value = State.force_to_t(6.0)
	page.angle_slider.slider.value = 90.0
	for k in 3:
		await _stroke(1.0, 10.0, 0.3)
	var la: Dictionary = _st().view().last_action
	_log("la lima de acero en el zafiro: no muerde = %s" % str((la.get("result", {}) as Dictionary).get("noBite", false)))
	await _wait(1.2)
	_caption(10, "la de diamante sí: arranca polvo blanco (el color del corindón en polvo)")
	await _pick("lima_diamante_gruesa")
	for k in 4:
		await _stroke(1.0, 10.0, 0.3)
	await _wait(1.0)
	_caption(10, "el tambor de corindón, tan duro como el zafiro: casi no muerde, roza, calienta y se vidria (reloj ×5)")
	await _pick("torno")
	_key(KEY_E)
	page.force_slider.slider.value = State.force_to_t(4.0)
	page.angle_slider.slider.value = 90.0
	_seg(page.clock_seg, "5")
	await _hold(0.4, 2.0)
	_seg(page.clock_seg, "1")
	var tw: Dictionary = _st().view().tools.torno
	_log("el torno en el zafiro: %s, filos de %s µm" % [String(tw.state), String.num(float(tw.edgeUm), 1)])
	await _wait(0.6)
	_caption(10, "la banda vidriada: las puntas del grano, planas y brillantes, en la tira que ha trabajado")
	_key(KEY_E)
	_key(KEY_ESCAPE)
	await _wait(0.4)
	# la vista general (en la de la garra la cámara sigue a la garra) y de cerca sobre el torno de la bandeja
	page.call("set_view", "general")
	await _wait(0.6)
	_look_at_tool("torno", 0.09, 25.0, 35.0)
	await _wait(2.6)
	page.call("set_view", "garra")
	await _wait(0.8)
	_caption(10, "una nueva de la bandeja (N) corta como el primer día, pero el zafiro la vuelve a vidriar en un momento: las gemas, con diamante")
	await _pick("torno")
	_key(KEY_N)
	await _wait(0.6)
	tw = _st().view().tools.torno
	_log("una nueva: %s, filos de %s µm" % [String(tw.state), String.num(float(tw.edgeUm), 1)])
	_key(KEY_E)
	await _hold(0.4, 1.0)
	_key(KEY_E)
	tw = _st().view().tools.torno
	_log("y tras 1 s en el zafiro: %s, filos de %s µm" % [String(tw.state), String.num(float(tw.edgeUm), 1)])
	await _wait(1.2)


func _scene_12() -> void:
	for pair: Array in [["titanio", "el titanio: un haz blanco (sus chispas arden más calientes que las del acero)"],
			["tungsteno", "el metal duro: casi ninguna (su haz es diminuto, corto y anaranjado, y el corindón apenas lo muerde)"],
			["oro", "el oro: ninguna (como el cobre: no arde)"], ["acero", "y el acero: las de siempre"]]:
		_caption(11, String(pair[1]))
		_select_inlay(String(pair[0]))
		await _wait(0.4)
		page.call("set_view", "garra")
		_seg(page.sedation_seg, "sujecion")
		await _pick("torno")
		_key(KEY_E)
		_key(KEY_Q)
		page.force_slider.slider.value = State.force_to_t(4.0)
		page.angle_slider.slider.value = 90.0
		await _hold(0.8, 1.6)
		_log("torno en %s: %d chispas (%s)" % [String(pair[0]), int(scene.call("info").sparks), String(scene.call("info").spark_mat)])
		_key(KEY_E)
		# se deja en la bandeja: así la siguiente vez se vuelve a coger (un clic sobre la que se tiene la deja)
		_key(KEY_ESCAPE)
		await _wait(0.6)


# ─────────────────────────────── colocar a mano la pieza de la reforja (unidad 5o) ───────────────────────────────

func _bond_btn(id: String) -> void:
	var bs: Dictionary = page.bond_card.buttons
	_press(bs.get(id))


func _bv() -> Dictionary:
	return _st().view().get("bond", {})


## Coge la pieza que espera en la bandeja de la colocación con el ratón (mira antes a la mesa) y vuelve a la garra.
func _grab_piece() -> void:
	page.call("set_view", "general")
	await _wait(1.2)
	var p: Vector2 = scene.call("bond_piece_screen_point")
	await _move(p, 0.5)
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(0.3)
	if not bool(_bv().get("held", false)):
		_log("no he cogido la pieza (en %s)" % str(p))
	page.call("set_view", "garra")
	await _wait(1.0)


## Gira la pieza en la mano hasta el eje de la garra (A/D), como una persona mirando la silueta.
func _align_piece() -> void:
	for i in 12:
		var t := float(_bv().get("tiltDeg", 0.0))
		if absf(t) < 1.0:
			break
		_key(KEY_A if t > 0.0 else KEY_D)
		await _wait(0.12)


## Limpia con alcohol (un toque sobre la garra a d mm de la punta), espera a que se evapore y lija un poco.
## La lija y su presión: la P240 suave en una garra entera; en la cara ancha de una rotura, la P180 apretando más (con 2 N la
## fuerza se reparte y la lija pule en vez de rayar).
func _prepare_claw(d_from_tip: float, paper := "lija_p240", force := 2.0, angle := 22.0) -> void:
	_caption_text("%d · limpiar y desengrasar con alcohol" % (_only + 1))
	await _pick("alcohol")
	await _tap(d_from_tip)
	_seg(page.clock_seg, "10")
	await _wait(3.4)
	_seg(page.clock_seg, "1")
	_caption_text("%d · lijar un poco donde va a pegar" % (_only + 1))
	await _pick(paper)
	page.angle_slider.slider.value = angle
	page.force_slider.slider.value = State.force_to_t(force)
	for i in 3:
		await _stroke(d_from_tip, 4.0, 0.3)
	_key(KEY_ESCAPE)
	_log("preparada: %s" % _bv().get("stage_text", ""))


## Lima a d mm de la punta hasta que la condición se cumpla (o n pasadas).
func _file_until(d_from_tip: float, cond: Callable, n: int, mm := 8.0) -> int:
	var k := 0
	while not cond.call() and k < n:
		await _stroke(d_from_tip, mm, 0.22)
		k += 1
	return k


## La forma y la punta, a mano: la lima gruesa siguiendo la curva y la fina en la punta, como en la escena 1.
func _shape_and_tip(coarse: String, fine: String) -> void:
	_caption_text("%d · la forma de la natural con la lima, mirando la silueta de la forma sana (F)" % (_only + 1))
	scene.call("set_ghost", true)
	await _pick(coarse)
	page.angle_slider.slider.value = 22.0
	page.force_slider.slider.value = State.force_to_t(8.0)
	var k := await _file_until(1.5, func() -> bool: return float(_st().care.tip_state().ratio) < 2.0, 30, 12.0)
	_log("forma: %d pasadas, punta ×%s" % [k, String.num(float(_st().care.tip_state().ratio), 2)])
	_caption_text("%d · dar la punta con la lima fina, pasadas suaves hasta que quede como la natural" % (_only + 1))
	await _pick(fine)
	page.force_slider.slider.value = State.force_to_t(1.5)
	# pasadas suaves y cortas, mirando la punta: se para en cuanto está en su margen (ni roma ni aguja)
	k = await _file_until(0.8, func() -> bool: return _st().care.check("punta"), 20, 1.5)
	_log("punta: %d pasadas, punta ×%s, forma %s" % [k, String.num(float(_st().care.tip_state().ratio), 2), String(_st().care.snapshot().shape.verdict)])
	_key(KEY_T)
	await _wait(0.6)
	scene.call("set_ghost", false)


## El acabado de una prótesis de acrílico o de resina ya dura: la unión con la lima gruesa (pasadas sobre ella hasta que no
## quede rebaba ni escalón, como con la funda), y la forma y la punta con la amoladora, como en la clínica (Matta et al. 2022;
## la lima gruesa tardaría cientos de pasadas en sacar la punta de un bloque de ~4 mm de radio): de frente en la punta hasta
## su largo y en faceta, con toques cada vez más cortos y suaves, hasta la punta de la natural.
func _grind_finish() -> void:
	var j := float(_bv().jointMm)
	_log("antes de limar, la carne viva como mucho a %s °C" % String.num(float(_st().care.snapshot().thermal.peakQuickC), 1))
	_caption_text("%d · ya dura: la amoladora (E la enciende), toques muy cortos y suaves sobre la unión: la carne viva está debajo" % (_only + 1))
	scene.call("set_ghost", true)
	# en el teléfono, la vista otra vez a la vista (la tarjeta la había desplazado)
	_reveal(page.view_box)
	await _pick("amoladora")
	page.angle_slider.slider.value = 45.0
	page.touch_force.value = State.force_to_t(1.0)
	var k := 0
	while (float(_bv().flashMm3) > 0.0 or float(_bv().stepMm) > float(_bv().stepOkMm)) and k < 120:
		_grinder_on()
		# sobre la pieza, justo pasada la unión (más allá, la herramienta no toca su borde; antes, lima el muñón)
		await _hold(_joint_d(j), 0.15)
		await _cool()
		k += 1
	_log("la unión: %d toques, rebosa %s, escalón %s, la carne viva como mucho a %s °C · %s" % [k, String.num(float(_bv().flashMm3), 3), String.num(float(_bv().stepMm), 3), String.num(float(_st().care.snapshot().thermal.peakQuickC), 1), _st().action_text()])
	_caption_text("%d · de frente en la punta, hasta su largo (mirando la silueta de la forma sana)" % (_only + 1))
	page.angle_slider.slider.value = 90.0
	page.touch_force.value = State.force_to_t(2.0)
	k = 0
	while float(_st().care.snapshot().claw.overgrowthLeftMm) > 0.1 and k < 30:
		_grinder_on()
		await _hold(_touching_d([0.6, 0.4, 0.9]), 0.4)
		await _cool()
		k += 1
	_log("el largo: %d toques, sobran %s mm, la carne viva como mucho a %s °C" % [k, String.num(float(_st().care.snapshot().claw.overgrowthLeftMm), 2), String.num(float(_st().care.snapshot().thermal.peakQuickC), 1)])
	_caption_text("%d · en faceta, toques cortos y suaves hasta la punta de la natural" % (_only + 1))
	page.angle_slider.slider.value = 22.0
	k = 0
	while not _st().care.check("punta") and float(_st().care.tip_state().ratio) >= 0.5 and k < 160:
		var coarse := float(_st().care.tip_state().ratio) > 10.0
		page.touch_force.value = State.force_to_t(3.0 if coarse else 0.8)
		_grinder_on()
		await _hold(_touching_d([1.0, 0.7, 1.4, 0.4]), 0.4 if coarse else 0.07)
		await _cool()
		k += 1
	if bool(_st().view().hand.rotary_on):
		_key(KEY_E)
	var shp: Dictionary = _st().care.snapshot().shape
	_log("la carne viva, como mucho a %s °C (duele desde %s °C)" % [String.num(float(_st().care.snapshot().thermal.peakQuickC), 1), String.num(float(_st().care.snapshot().thermal.painC), 0)])
	_log("punta: %d toques, punta ×%s, forma %s («%s») · %s" % [k, String.num(float(_st().care.tip_state().ratio), 2), String(shp.verdict), String(shp.get("text", "")), _st().action_text()])
	_key(KEY_T)
	await _wait(0.6)
	scene.call("set_ghost", false)


## La distancia a la punta (mm) donde el puntero cae sobre la pieza justo pasada la unión j (de 0,5 a 1,2 mm más allá).
func _joint_d(j: float) -> float:
	for off: float in [1.0, 0.8, 1.2, 0.6]:
		var d := _apex() - (j + off)
		var h: Dictionary = scene.call("hit_at", _aim(d))
		if not h.is_empty() and float(h.s) >= j + 0.5 and float(h.s) <= j + 1.2:
			return d
	return _apex() - (j + 1.0)


## La primera distancia a la punta (mm) donde el puntero cae sobre la garra: apretar en el aire apaga la amoladora.
func _touching_d(ds: Array) -> float:
	for d: float in ds:
		if not (scene.call("hit_at", _aim(d)) as Dictionary).is_empty():
			return d
	return float(ds[0])


## Entre toque y toque, deja que se enfríe (como pide la línea de arriba): si la carne viva se acerca al umbral del dolor, el
## reloj a ×10 hasta que baje; si no, un momento.
func _cool() -> void:
	var th: Dictionary = _st().care.snapshot().thermal
	if float(th.quickC) < float(th.painC) - 6.0:
		await _wait(0.1)
		return
	_seg(page.clock_seg, "10")
	var n := 0
	while float(_st().care.snapshot().thermal.quickC) > float(th.painC) - 8.0 and n < 20:
		await _wait(0.1)
		n += 1
	_seg(page.clock_seg, "1")


## Enciende la amoladora de la mano si está apagada (E), antes de cada toque.
func _grinder_on() -> void:
	if not bool(_st().view().hand.rotary_on):
		_key(KEY_E)


func _scene_17() -> void:
	_caption(16, "la barra del animal, arriba: el estrés, la sangre y el calor")
	_key(KEY_R)
	page.call("set_view", "garra")
	if not bool(_st().tutorial_on):
		_press(page.tut_toggle)
	_st().tutorial_goto("preparar")
	_reveal(page.tut_card)
	await _wait(1.6)
	page.growth_slider.slider.value = 60.0
	await _wait(0.3)
	_caption(16, "sin capucha, al tocarla se inquieta (el tutorial resalta «Capucha y toalla»)")
	await _pick("lima_bastarda")
	page.angle_slider.slider.value = 90.0
	for i in 3:
		await _stroke(0.5, 6.0, 0.3)
	await _wait(2.2)
	_log("estrés sin capucha: %s" % String.num(float(_st().patient.stress), 2))
	_caption(16, "encapuchada y envuelta: se calma el aumento")
	_seg(page.sedation_seg, "sujecion")
	await _wait(1.6)
	_caption(16, "se corta de más: sangra, y «Si sangra» va en su orden")
	await _pick("tenaza")
	await _hold(_st().care.quick_cover_mm() + 1.0, State.CLIP_CLOSE_S + 0.25)
	_reveal(page.tut_card)
	await _wait(1.8)
	_caption(16, "1 · coger el polvo hemostático (señalado en la batea)")
	await _pick("hemostatico")
	await _wait(0.8)
	_caption(16, "2 · apretar sobre la herida: la cuenta de los segundos; soltar antes de tiempo lo dice")
	await _hold(0.6, 1.4)
	await _wait(1.6)
	_caption(16, "otra vez, sin soltar, con el reloj ×10: hasta «Listo: ya puedes soltar»")
	_seg(page.clock_seg, "10")
	await _hold(0.6, 3.6)
	_seg(page.clock_seg, "1")
	await _wait(1.2)
	_caption(16, "3 · desinfectar con clorhexidina")
	await _pick("clorhexidina")
	await _tap(2.0)
	await _wait(1.6)
	_log("sangre perdida: %s mL de %s" % [String.num(float(_st().blood_state().lostMl), 1), String.num(float(_st().blood_state().volumeMl), 0)])
	_caption(16, "el tigre sin sedar: el primer toque avisa…")
	_seg(page.animal_seg, "tigre")
	await _wait(1.2)
	await _pick("lima_bastarda")
	page.angle_slider.slider.value = 90.0
	await _stroke(0.5, 6.0, 0.3)
	await _wait(2.2)
	_caption(16, "…y al segundo se revuelve: la sesión se para, con la explicación")
	await _stroke(0.5, 6.0, 0.3)
	await _wait(0.6)
	_reveal(page.report_card)
	await _wait(3.0)
	_log("parada: %s" % str(_st().halted.get("code", "")))


func _scene_18() -> void:
	_caption(17, "una garra reforjada de zafiro: la lima de acero no muerde, y dice por qué y qué coger")
	_seg(page.animal_seg, "rapaz")
	await _wait(0.3)
	page.growth_slider.slider.value = 60.0
	_st().set_inlay("zafiro")
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	await _wait(1.2)
	await _pick("lima_bastarda")
	page.angle_slider.slider.value = 90.0
	page.force_slider.slider.value = State.force_to_t(6.0)
	await _stroke(0.5, 6.0, 0.3)
	await _wait(2.4)
	_log("no muerde: %s" % _st().action_text())
	_caption(17, "la de diamante gruesa desbasta: lo que ha quitado, la superficie y cuánto falta")
	await _pick("lima_diamante_gruesa")
	for i in 3:
		await _stroke(0.5, 8.0, 0.3)
	await _wait(2.4)
	_log("desbastar: %s" % _st().action_text())
	_caption(17, "y la de diamante fina, en faceta, pule y da la punta")
	await _pick("lima_diamante_fina")
	page.angle_slider.slider.value = 22.0
	page.force_slider.slider.value = State.force_to_t(2.0)
	for i in 2:
		await _stroke(0.6, 3.0, 0.25)
	await _wait(2.4)
	_log("pulir: %s" % _st().action_text())


## La pieza hecha en el laboratorio de la reforja (5m), como al pulsar «Pasar a la cetrería para colocarla»: el estado del
## laboratorio sigue el tutorial de la receta (la carga en su máquina, la marcha, la colada con la forma de la garra, limarla,
## pulirla y probar el ajuste) y da la pieza terminada y sin pegar.
static func _lab_piece(recipe: String, paw: String, digit: String) -> Dictionary:
	var fs := ForgeState.new({ "animal": "rapaz", "claw": "aguila", "paw": paw, "digit": digit })
	fs.set_process(recipe)
	fs.tutorial_goto(fs.process)
	var n := 0
	while not fs.tutorial_done() and n < 80:
		fs.do_step()
		var m := 0
		while fs.running() and m < 6000:
			fs.tick(F)
			m += 1
		for i in 3000:
			if fs.act.is_empty() or float(fs.act.t) >= float(fs.act.dur):
				break
			fs.tick(F)
		n += 1
	return (fs.care_view().get("setup", {}) as Dictionary).duplicate(true)


func _scene_13() -> void:
	_caption(12, "la funda de acero del laboratorio llega sin pegar (a una garra ya recortada a su largo)")
	page.growth_slider.slider.value = 0.0
	await _wait(0.2)
	page.call("set_view", "garra")
	_seg(page.sedation_seg, "sujecion")
	var lab_fs := _lab_piece("acero", "derecha", "III")
	_log("del laboratorio: %s" % str(lab_fs.get("piece", {})))
	page.call("receive_forged", lab_fs)
	await _wait(0.4)
	_reveal(page.bond_card)
	await _wait(1.6)
	var j := float(_bv().jointMm)
	await _prepare_claw(4.0)
	_caption(12, "el epoxi: purgar la cánula y poner el cordón en la funda")
	_reveal(page.bond_card)
	_bond_btn("purgar")
	await _wait(0.6)
	_bond_btn("aplicar")
	await _wait(0.8)
	_caption(12, "coger la funda, girarla al eje de la garra y apretarla sobre ella")
	await _grab_piece()
	await _move(scene.call("claw_screen_point", j, 0.0, 0.0) + Vector2(60.0, -40.0), 0.4)
	await _align_piece()
	await _move(scene.call("claw_screen_point", j, 0.0, 0.0), 0.6)
	await _wait(0.3)
	_button(true)
	await _wait(0.8)
	_caption(12, "en fresco, lo que rebosa con la espátula (sin soltar la funda)")
	for i in 3:
		_bond_btn("espatula")
		await _wait(0.35)
	_caption(12, "el epoxi fija en unas 3 h: se venda para que no se mueva (reloj ×3600)")
	_bond_btn("vendar")
	await _wait(0.4)
	_button(false)
	_log("colocada: %s · fallo «%s»" % [_bv().stage_text, _bv().failure])
	_seg(page.clock_seg, "3600")
	await _wait(3.4)
	_seg(page.clock_seg, "1")
	_bond_btn("quitar_venda")
	await _wait(0.8)
	_log("fijada: %s · rebosa %s mm³, escalón %s mm" % [_bv().attached, String.num(float(_bv().flashMm3), 3), String.num(float(_bv().stepMm), 3)])
	_caption(12, "lo que rebosa ya está duro: con la lima, sobre la unión, hasta que no se note el escalón")
	_reveal(page.view_box)
	await _pick("lima_bastarda")
	page.angle_slider.slider.value = 10.0
	page.force_slider.slider.value = State.force_to_t(6.0)
	var d_joint := _apex() - j
	var k := await _file_until(d_joint, func() -> bool: return float(_bv().flashMm3) <= 0.0 and float(_bv().stepMm) <= float(_bv().stepOkMm), 60)
	_log("la unión: %d pasadas, rebosa %s, escalón %s" % [k, String.num(float(_bv().flashMm3), 3), String.num(float(_bv().stepMm), 3)])
	await _shape_and_tip("lima_diamante_gruesa", "lima_diamante_fina")
	_caption(12, "curada del todo (reloj ×3600) y la prueba: un tirón suave de lado")
	_seg(page.clock_seg, "3600")
	await _wait(2.0)
	_seg(page.clock_seg, "1")
	_reveal(page.bond_card)
	_bond_btn("probar")
	await _wait(0.4)
	_log("prueba: %s" % String(_bv().test.get("text", "")))
	await _wait(2.4)


## Rompe la garra con la tenaza (seca, hasta la carne viva) y para la sangre, como en la escena 3.
func _break_and_stop() -> void:
	_seg(page.sedation_seg, "sujecion")
	_seg(page.humidity_seg, "seca")
	await _wait(0.4)
	await _pick("tenaza")
	await _hold(_st().care.quick_cover_mm() - 0.4, State.CLIP_CLOSE_S + 0.25)
	await _wait(0.6)
	_seg(page.clock_seg, "10")
	await _pick("hemostatico")
	await _hold(0.6, 3.6)
	_seg(page.clock_seg, "1")
	_seg(page.humidity_seg, "natural")
	_key(KEY_ESCAPE)
	await _wait(0.4)


## La garra rota recibe la prótesis de verdad (el acrílico de la reforja, sin pegar).
func _receive_prosthesis() -> void:
	# la prótesis se hace con el ave anestesiada (isoflurano), como la reparación del pico: el fraguado y la amoladora calientan
	# cerca del muñón, y despierta se movería de dolor
	_caption_text("%d · la prótesis, con el ave anestesiada (isoflurano): el fraguado y la amoladora calientan cerca del muñón" % (_only + 1))
	_seg(page.sedation_seg, "anestesia")
	await _wait(0.8)
	var fs := { "careSupported": true, "paw": String(_st().paw), "digit": String(_st().digit),
		"block": { "material": "acrilico", "stump_mm": _apex(), "wall_mm": 1.0, "fiction": false,
			"note": "Así se repara de verdad: el acrílico se aplica sobre lo que queda y se lima en el animal.", "source": "Samour 2006" } }
	page.call("receive_forged", fs)
	await _wait(0.4)
	_reveal(page.bond_card)
	await _wait(1.4)


func _scene_14() -> void:
	_caption(13, "la garra se raja hasta la carne viva y se para la sangre")
	page.call("set_view", "garra")
	await _break_and_stop()
	await _receive_prosthesis()
	await _prepare_claw(0.6, "lija_p180", 8.0, 45.0)
	_reveal(page.bond_card)
	var guard := 0
	var first := true
	while float(_bv().builtMm) < float(_bv().needMm) - 1e-6 and guard < 8:
		_caption(13, "mezclar el polvo y el líquido (2:1 en peso) y esperar a la masa (reloj ×60)")
		_bond_btn("mezclar")
		_seg(page.clock_seg, "60")
		await _wait(1.7)
		_seg(page.clock_seg, "1")
		_seg(page.bond_card.layer_choice, "fina" if first else "gruesa")
		_caption(13, "una capa %s con la espátula: el fraguado calienta la carne viva" % ("fina" if first else "gruesa"))
		await _pick("espatula")
		await _tap(0.3)
		await _wait(0.6)
		_log("capa: %s de %s mm · carne viva %s °C" % [String.num(float(_bv().builtMm), 1), String.num(float(_bv().needMm), 1), String.num(float(_bv().quickC), 1)])
		first = false
		guard += 1
	_caption(13, "en fresco, lo que rebosa con la espátula")
	for i in 3:
		await _tap(_apex() - float(_bv().jointMm))
	_caption(13, "esperar a que fragüe, unos 10 min (reloj ×600): no se lima en fresco")
	_seg(page.clock_seg, "600")
	var w := 0
	while not bool(_bv().set) and w < 40:
		await _wait(0.25)
		w += 1
	_seg(page.clock_seg, "1")
	_log("fraguada: %s · pico de la carne viva %s °C · rebosa %s mm³" % [_bv().set, String.num(float(_bv().peakQuickC), 1), String.num(float(_bv().flashMm3), 3)])
	await _grind_finish()
	_caption(13, "y la prueba de la unión")
	_reveal(page.bond_card)
	_bond_btn("probar")
	await _wait(0.4)
	_log("prueba: %s · escalón %s · %s" % [String(_bv().test.get("text", "")), String.num(float(_bv().stepMm), 3), String(_bv().stage_text)])
	await _wait(2.4)


func _scene_15() -> void:
	_caption(14, "la misma garra rota: esta vez, resina con la lámpara")
	page.call("set_view", "garra")
	await _break_and_stop()
	await _receive_prosthesis()
	_seg(page.bond_card.method_choice, "resina")
	await _wait(0.6)
	await _prepare_claw(0.6, "lija_p180", 8.0, 45.0)
	_reveal(page.bond_card)
	_caption(14, "los ojos tapados (la capucha) y el filtro naranja: la luz azul daña la retina")
	_bond_btn("ojos")
	await _wait(0.8)
	var guard := 0
	var first := true
	while float(_bv().builtMm) < float(_bv().needMm) - 1e-6 and guard < 8:
		_seg(page.bond_card.layer_choice, "fina" if first else "gruesa")
		_seg(page.bond_card.time_choice, "20" if first else "40")
		_caption(14, "una capa %s de resina y la lámpara azul casi tocando, %s s (reloj ×10)" % ["fina" if first else "gruesa", "20" if first else "40"])
		await _pick("espatula")
		await _tap(0.3)
		_bond_btn("lampara")
		_seg(page.clock_seg, "10")
		await _wait(4.4)
		_seg(page.clock_seg, "1")
		var rl: Array = _bv().resin
		var l: Dictionary = rl.back() if not rl.is_empty() else {}
		_log("capa de resina: %s de %s mm · la última, curada %s mm de %s" % [String.num(float(_bv().builtMm), 1), String.num(float(_bv().needMm), 1), String.num(float(l.get("cdMm", 0.0)), 2), String.num(float(l.get("h", 0.0)), 1)])
		first = false
		guard += 1
	await _grind_finish()
	_caption(14, "y la prueba de la unión")
	_reveal(page.bond_card)
	_bond_btn("probar")
	await _wait(0.4)
	_log("prueba: %s · %s" % [String(_bv().test.get("text", "")), String(_bv().stage_text)])
	await _wait(2.4)


func _scene_16() -> void:
	_caption(15, "el velocirraptor de la reconstrucción, anestesiado")
	_seg(page.animal_seg, "velociraptor")
	await _wait(0.4)
	_seg(page.sedation_seg, "anestesia")
	page.call("set_view", "garra")
	await _wait(1.6)
	var sn: Dictionary = _st().care.snapshot()
	var r := float(sn.claw.baseRadiusMm)
	var k := float(sn.claw.sectionRatio)
	_caption(15, "la base de la hoz: %s × %s mm (el núcleo óseo de 18,7 × 7,1 mm más el estuche)" % [String.num(2.0 * r * sqrt(k), 1), String.num(2.0 * r / sqrt(k), 1)])
	_log("la hoz: radio equivalente de la base %s mm, %s × %s mm" % [String.num(r, 2), String.num(2.0 * r * sqrt(k), 1), String.num(2.0 * r / sqrt(k), 1)])
	scene.call("set_ghost", true)
	await _wait(2.4)
	page.call("set_view", "seccion")
	await _wait(2.0)
	page.call("set_view", "garra")
	await _wait(1.0)


# ─────────────────────────────── 19 · el guiado (unidad 5y) ───────────────────────────────

## Pulsa lo que señala el guiado en el estado (como el test de la 5y: la orden del mando, la herramienta o el gesto sobre la
## garra donde señala), al momento: la demo solo enseña cada toma.
func _guide_press(g: Dictionary) -> bool:
	var st := _st()
	var act: Dictionary = g.get("act", {})
	var op := String(act.get("op", ""))
	var args: Array = act.get("args", [])
	match op:
		"", "pieza":
			return false
		"esperar":
			for i in int(ceilf(float(args[0] if not args.is_empty() else 1.0) / 0.25)):
				st.tick(0.25)
		"gesto":
			var s0 := float(act.s_mm)
			var kind := String(act.kind)
			var secs := State.CLIP_CLOSE_S + 0.1 if kind == "corte" else float(act.get("secs", 0.0))
			var along := float(act.get("along_mm", 0.0))
			var n := maxi(int(ceilf(along / 150.0 * 60.0)), int(ceilf(secs * 60.0)))
			st.press_on(s0)
			for i in maxi(n, 1):
				if kind == "lima":
					st.drag(along / float(maxi(n, 1)), along / float(maxi(n, 1)), s0, 1.0 / 60.0)
				else:
					st.drag(0.0, 0.0, s0, 1.0 / 60.0)
				st.tick(1.0 / 60.0)
			st.release()
		_:
			if not st.has_method(op):
				return false
			st.callv(op, args)
	return true


## Juega lo señalado hasta que el guiado cumpla cond (o max pulsaciones) y enseña la toma.
func _guide_until(cond: Callable, max_presses := 400) -> Dictionary:
	var g: Dictionary = _st().view().guide
	for i in max_presses:
		if cond.call(g) or g.is_empty():
			break
		if not _guide_press(g):
			break
		g = _st().view().guide
	page.runner.post("tick", [0.0])
	page.refresh()
	return g


func _guide_shot(what: String, g: Dictionary, secs := 1.6) -> void:
	# el puntero, en una esquina de la vista: la herramienta de la mano no se queda delante de la garra
	_set_pointer((page.view3d as Control).size - Vector2(24.0, 24.0))
	cursor.visible = false
	_caption(18, what)
	_log("toma «%s» desde el fotograma %d: [%s] %s · %s" % [what, int(round(_t * 30.0)), String(g.get("id", "")), String(g.get("hint", "")), String(g.get("value", ""))])
	await _wait(secs)


func _scene_19() -> void:
	if not bool(_st().tutorial_on):
		_press(page.tut_toggle)
	_seg(page.animal_seg, "rapaz")
	_key(KEY_R)
	await _wait(0.6)
	var g := _guide_until(func(x: Dictionary) -> bool: return true)
	await _guide_shot("el águila: «Pon la capucha y la toalla», el mando del panel con su borde", g, 2.0)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("kind", "")) == "herramienta" and String(x.id) != "bandeja")
	await _guide_shot("coger lo que toca: la herramienta, con su contorno en la bandeja", g, 2.2)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("id", "")) == "garra:sobrante")
	await _guide_shot("la garra de cerca: cuánto cortar", g, 2.2)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("hint", "")).begins_with("Grieta") and String(x.get("kind", "")) == "garra")
	await _guide_shot("corregir: la grieta del cortaúñas, de frente", g, 2.0)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("hint", "")).begins_with("Afila"))
	await _guide_shot("dar la punta, a su ángulo, con lo que falta", g, 2.0)
	# el tigre: la carne viva a trasluz y la sangre
	_seg(page.animal_seg, "tigre")
	await _wait(0.8)
	g = _guide_until(func(x: Dictionary) -> bool: return true)
	await _guide_shot("el tigre: anestesia antes de tocarle las garras", g, 1.6)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("id", "")) == "garra:carne_viva")
	await _guide_shot("su garra clara: la carne viva a trasluz", g, 2.0)
	_st().pick("tenaza")
	var s_cut := _apex() - (_st().care.quick_cover_mm() + 0.6)
	_st().press_on(s_cut)
	for i in 40:
		_st().drag(0.0, 0.0, s_cut, 1.0 / 60.0)
		_st().tick(1.0 / 60.0)
	_st().release()
	g = _guide_until(func(x: Dictionary) -> bool: return true)
	await _guide_shot("sangra: coger el polvo hemostático", g, 2.2)
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("id", "")) == "garra:herida")
	await _guide_shot("y apretar sobre la herida, con lo que falta", g, 2.2)
	# el velocirraptor de cine
	_seg(page.animal_seg, "velociraptor")
	await _wait(0.6)
	_st().set_model("pelicula")
	g = _guide_until(func(x: Dictionary) -> bool: return String(x.get("id", "")) == "garra:pasada")
	await _guide_shot("el velocirraptor: de la base a la punta, a su ángulo", g, 2.2)
	# la rapaz que se estresa y la que se suelta
	_seg(page.animal_seg, "rapaz")
	await _wait(0.6)
	_st().set_sedation("sujecion")
	_st().patient.handled = true
	_st().patient.stress = 0.78
	_st().tick(0.05)
	g = _guide_until(func(x: Dictionary) -> bool: return true)
	await _guide_shot("se estresa: la pausa para calmarla", g, 2.0)
	_key(KEY_R)
	await _wait(0.4)
	_st().pick("lima_bastarda")
	for k in 300:
		if not _st().halted.is_empty():
			break
		var s0 := _apex() - 1.0
		_st().press_on(s0)
		for i in 30:
			_st().drag(2.0, 2.0, s0, 1.0 / 60.0)
			_st().tick(1.0 / 60.0)
		_st().release()
	g = _guide_until(func(x: Dictionary) -> bool: return true)
	await _guide_shot("se ha soltado: «Recogerla y encapucharla»", g, 2.4)
	# y con «Guiado» apagado: el tutorial sigue, pero nada se resalta ni se mueve solo
	_key(KEY_R)
	await _wait(0.3)
	_press(page.guide_pill)
	page.runner.post("tick", [0.0])
	page.refresh()
	_reveal(page.tools_card)
	await _guide_shot("«Guiado» apagado: nada se resalta ni se mueve solo", {}, 2.0)
	_press(page.guide_pill)
