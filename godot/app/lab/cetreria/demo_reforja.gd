## Demo guionizada del «Laboratorio experimental (reforja)» de la cetrería (unidad 5f) para las capturas: la sección del
## laboratorio en su página «Cetrería», con el laboratorio abierto desde su interruptor, manejado como una persona: el ratón
## (se ve el puntero) coge los tarros y vierte en el plato de la balanza, carga el crisol, gira y pulsa los mandos del horno
## y toca los sitios del taller en la vista 3D; los botones y las teclas de la página hacen el resto. Diecisiete escenas:
##   1 · el tutorial del horno: la invitación de la primera vez y cada mando, que se ilumina (el dial, girado con el ratón);
##   2 · zafiro de Verneuil bien hecho: pesar la alúmina con el ratón, cargar, el modo, meter la carga por la puerta, los
##       parámetros de la receta, la llama y la bola que crece hacia abajo con su reloj, enfriar, tallar por pasadas, proteger
##       la carne viva, pulir y probar el ajuste; la ficha (5m: sin pegar);
##   3 · zafiro con un defecto: sin la carga dentro no arranca; la llama demasiado fría no funde la alúmina, y el error
##       explicado con su arreglo;
##   4 · diamante HPHT: la prensa que se cierra, su manómetro, el reloj de días a ×3600 y a ×36 000 (5m) y la pieza;
##   5 · la garra viva recubierta (FICCIÓN): la barrera sobre la parte viva, la pistola y el termómetro de la carne viva;
##   6 · el tallado por pasadas de la bola de zafiro hasta la forma de la garra (5m): la sierra, la muela gruesa, la fresa y la
##       fina con el indicador de la forma, de cerca; la herramienta más blanda que no muerde y la gruesa que se pasa;
##   7 · la funda pasa a la cetrería sin pegar: «Pasar a la cetrería para colocarla» y allí, la garra de zafiro;
##   8 · la garra rota en la cetrería: se para la sangre, «Reforjar con material» la lleva al laboratorio (prótesis
##       entera), se hace la pieza y vuelve como un bloque en bruto pegado al muñón, para limarlo allí (ficción);
##   9 · las máquinas de cada modo: inducción y colada (acero), horno de vacío y colada (oro), plasma (diamante CVD),
##       sinterizado (metal duro) y el rubí en la llama;
##  10 · la prótesis de verdad (unidad 5j): otra garra rota, «Reforjar con material» y el acrílico dental junto a las recetas
##       de fantasía; un clic en su estuche lo mezcla y vuelve a la cetrería como un bloque sin ficción, que se lima allí;
##  11 · la prótesis de una garra rota hecha entera en el laboratorio (unidad 5j): con lo que queda de ella y para la garra
##       de su dedo, rehace lo que falta hasta la punta natural;
##  12 · cada carga en su máquina (5m): la alúmina en la tolva de Verneuil, la cápsula entre los yunques, el sustrato bajo la
##       campana, la pastilla en la bandeja y el crisol en la bobina, cada una por la puerta;
##  13 · el reloj del tiempo de verdad a dos velocidades (5m): la alúmina sinterizada (horas) a ×600 y a ×36 000;
##  14 · la cera perdida con la garra de un tigre (5m): el modelo de cera, el revestimiento, el quemado con su ciclo, la colada
##       del oro en el molde, romper el molde, cortar el bebedero, limar, pulir, probar el ajuste y pasarla a la cetrería;
##  15 · la mesa de soldar (5r): la funda de acero y su punta, la soldadora láser, alinear, la costura punto a punto con el puntero
##       apretado (el destello, el punto incandescente y el cordón), limar la costura y pasarla a la cetrería;
##  16 · el titanio sin argón: la soldadura sale contaminada (azul o gris) y se explica;
##  17 · una punta de metal duro en la funda de acero: con plata y el soplete (el metal duro no se funde);
##  18 · pesar los polvos del metal duro (5w): la tarjeta del paso con los gramos de cada polvo para la funda de la garra, lo
##       que lleva y lo que falta junto a la balanza, el cobalto que se pasa y cómo se arregla, y «Listo: carga el crisol (L)».
## Orden: 1, 2, 12, 13, 3, 4, 9, 14, 6, 5, 7, 8, 10, 11, 15, 16, 17 y 18.
## Captura:   node godot/tools/godot.mjs capture res://app/lab/cetreria/demo_reforja.tscn --frames=4500 --out=<carpeta>
## Teléfono:  … con --phone (390 × 844: una columna). Un caso: … -- --caso=2 (y menos fotogramas).
## El estado va en el hilo de la interfaz (cada captura sale igual). No guarda ajustes. Al final escribe lo que cuesta un
## fotograma de la escena 3D y un repintado de la página.
extends Control

const LabSection = preload("res://app/lab/lab_section.tscn")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const State = preload("res://core/lab/claw_forge_state.gd")
const CareState = preload("res://core/lab/claw_care_state.gd")

const SCENES := [
	"El tutorial del horno: cada mando, qué hace y por qué importa",
	"Zafiro de Verneuil, bien hecho: pesar, meter la carga, la llama con su reloj, enfriar, tallar por pasadas, pulir y probar el ajuste",
	"Zafiro con un defecto: la llama demasiado fría",
	"Diamante HPHT: la prensa de alta presión",
	"La garra viva recubierta (FICCIÓN): la barrera y el termómetro de la carne viva",
	"El tallado por pasadas de la bola de zafiro hasta la forma de la garra",
	"La funda terminada pasa a la cetrería, sin pegar",
	"La garra rota en la cetrería: «Reforjar con material»",
	"Las máquinas de cada modo: inducción, vacío, plasma, sinterizado y la llama",
	"La prótesis de verdad: el acrílico dental para la garra rota",
	"La prótesis de una garra rota, con lo que queda de ella",
	"Cada carga en su máquina, por la puerta del horno",
	"El reloj del tiempo de verdad, a dos velocidades",
	"La cera perdida con la garra de un tigre: el oro colado con su forma",
	"La mesa de soldar: una punta de acero soldada con láser, de principio a fin",
	"La mesa de soldar: el titanio sin argón sale contaminado",
	"La mesa de soldar: una punta de metal duro, con plata y el soplete",
	"Pesar los polvos del metal duro: cuántos gramos de cada uno pide la funda",
]
const MAIN_ORDER := [0, 1, 11, 12, 2, 3, 8, 13, 5, 4, 6, 7, 9, 10, 14, 15, 16, 17]

var lab: Control
var care: Control
var page: Control
var caption: Label
var cursor: Panel
var _t := 0.0
var _only := -1
var _pointer := Vector2(-1.0, -1.0)
var _paint_sum := 0
var _paint_n := 0
var _paint_max := 0
var _seen_paints := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--caso="):
			_only = clampi(int(a.substr(7)) - 1, 0, SCENES.size() - 1)
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab = LabSection.instantiate()
	add_child(lab)
	care = lab.care_page
	care.threaded = false
	lab.set_page(lab.PAGE_CARE, false)
	_build_overlay()
	_run()


func _build_overlay() -> void:
	var vs := get_viewport_rect().size
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Sheet"
	caption = Ui.label("Laboratorio experimental (reforja)", "CardTitle")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = minf(vs.x - 60.0, 620.0)
	pill.add_child(caption)
	add_child(pill)
	pill.position = Vector2(14, vs.y - 96.0) if vs.x < 600.0 else Vector2(16, vs.y - 64.0)
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
	if page != null and int(page.paints) != _seen_paints:
		_seen_paints = int(page.paints)
		var us := int(page.last_paint_us)
		_paint_sum += us
		_paint_n += 1
		_paint_max = maxi(_paint_max, us)


# ─────────────────────────────── guion ───────────────────────────────

func _run() -> void:
	await get_tree().process_frame
	var order: Array = MAIN_ORDER if _only < 0 else [_only]
	for i: int in order:
		await call("_scene_%d" % (i + 1))
	var sc := _scene()
	if sc == null:
		return
	var inf: Dictionary = sc.call("info")
	var avg := float(inf.get("update_ms_avg", 0.0))
	var mx := float(inf.get("update_ms_max", 0.0))
	var pavg := float(_paint_sum) / float(maxi(_paint_n, 1)) / 1000.0
	_caption_text("Fin · escena 3D: %s ms de media por fotograma (máximo %s ms) · página: %s ms por repintado" % [_fmt(avg), _fmt(mx), _fmt(pavg)])
	print("Coste de la escena 3D: %s ms de media por fotograma, máximo %s ms (%d fotogramas)." % [_fmt(avg), _fmt(mx), int(inf.get("frames", 0))])
	print("Coste de la página: %s ms de media por repintado, máximo %s ms (%d repintados)." % [_fmt(pavg), _fmt(float(_paint_max) / 1000.0), _paint_n])


static func _fmt(x: float) -> String:
	return String.num(x, 3)


func _caption(i: int, extra := "") -> void:
	_caption_text("%d · %s%s" % [i + 1, SCENES[i], (" · " + extra) if extra != "" else ""])


func _caption_text(t: String) -> void:
	caption.text = t


func _log(t: String) -> void:
	print("[demo %s s] %s" % [String.num(_t, 1), t])


func _wait(secs: float) -> void:
	var end := _t + secs
	while _t < end:
		await get_tree().process_frame


func _st() -> State:
	return page.runner.state


func _scene() -> Node3D:
	return page.scene if page != null else null


func _post(op: String, args: Array = []) -> void:
	page.runner.post(op, args)


func _press(b: BaseButton) -> void:
	if b != null and b.is_visible_in_tree() and not b.disabled:
		b.pressed.emit()


func _key(code: Key, shift := false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.shift_pressed = shift
	care.call("handle_key", k)


## Abre el laboratorio desde el interruptor de la cetrería (la primera vez crea su página).
func _open_lab() -> void:
	if not bool(care.lab_open):
		(care.lab_switch.buttons["reforja"] as Button).pressed.emit()
	page = care.lab_page
	await _wait(0.2)


func _view(id: String) -> void:
	page.call("set_view", id)


## Lleva una tarjeta a la vista: en escritorio, en la columna de las tarjetas; en el teléfono, en la sección.
func _reveal(c: Control) -> void:
	var rs: ScrollContainer = page.right_scroll
	if rs.visible and rs.is_ancestor_of(c):
		var y := c.get_global_rect().position.y - (page.right as Control).get_global_rect().position.y - 8.0
		var tw := create_tween()
		tw.tween_property(rs, "scroll_vertical", int(maxf(y, 0.0)), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		lab.call("scroll_to", c, 8.0)


## Una tarjeta al lado de lo que pasa en la vista: en escritorio, en su columna; en el teléfono no se mueve (la vista sigue
## a la vista).
func _reveal_side(c: Control) -> void:
	if (page.right_scroll as Control).visible:
		_reveal(c)


## En el teléfono, una tarjeta un rato (las tarjetas van debajo de la vista) y la vista otra vez; en escritorio, nada (la
## tarjeta ya está en su columna).
func _phone_card(c: Control) -> void:
	if (page.right_scroll as Control).visible:
		return
	lab.call("scroll_to", c, 8.0)
	await _wait(2.5)
	_reveal_view()
	await _wait(0.6)


## En el teléfono, la vista vuelve arriba (las tarjetas van debajo).
func _reveal_view() -> void:
	if not (page.right_scroll as Control).visible:
		lab.call("scroll_to", page.view_box, 8.0)


# ─────────────────────────────── el ratón en la vista 3D ───────────────────────────────

func _set_pointer(p: Vector2) -> void:
	_pointer = p
	var view3d: Control = page.view3d
	cursor.visible = true
	cursor.position = view3d.get_global_rect().position + p - cursor.size * 0.5
	var mm := InputEventMouseMotion.new()
	mm.position = p
	_scene().call("handle_pointer", mm)


func _button(pressed: bool, shift := false) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = _pointer
	mb.shift_pressed = shift
	_scene().call("handle_pointer", mb)
	var sb := cursor.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = Color(Palette.color("gold"), 0.8) if pressed else Color(1, 1, 1, 0.55)


## Lleva el puntero hasta el sitio id de la escena en secs (lo sigue aunque la cámara aún se mueva).
func _move_to(id: String, secs := 0.45) -> void:
	_reveal_view()
	var a := _pointer if _pointer.x >= 0.0 else Vector2(60.0, 60.0)
	var t0 := _t
	while _t - t0 < secs:
		var k := clampf((_t - t0) / secs, 0.0, 1.0)
		_set_pointer(a.lerp(_target(id), k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame
	_set_pointer(_target(id))
	await get_tree().process_frame


## El punto de la pantalla de un sitio de la escena ((−1, −1): detrás de la cámara; entonces, donde está el puntero).
func _target(id: String) -> Vector2:
	var p: Vector2 = _scene().call("target_screen_point", id)
	return p if p != Vector2(-1.0, -1.0) else _pointer


## Un clic sobre un sitio de la escena (un tarro, el crisol, un mando, un botón o un sitio del taller).
func _click(id: String) -> void:
	await _move_to(id)
	_button(true)
	await get_tree().process_frame
	_button(false)
	await _wait(0.25)


## Coge un tarro y vierte en el plato de la balanza durante secs (Mayús: gota a gota); después lo deja.
func _pour(jar: String, secs: float, fine := false) -> void:
	await _click("tarro:" + jar)
	await _move_to("balanza", 0.5)
	_button(true, fine)
	await _wait(secs)
	_button(false)
	await _wait(0.3)
	await _click("tarro:" + jar)


## Gira un dial con el ratón: apretar sobre él y arrastrar hacia arriba (pasos positivos) o hacia abajo.
func _turn(id: String, steps: int) -> void:
	await _move_to("mando:" + id)
	_button(true)
	var start := _pointer
	var px := float(steps) * 14.0
	var t0 := _t
	var secs := clampf(absf(px) / 220.0, 0.3, 1.2)
	while _t - t0 < secs:
		var k := clampf((_t - t0) / secs, 0.0, 1.0)
		_set_pointer(start + Vector2(0.0, -px * k))
		await get_tree().process_frame
	_set_pointer(start + Vector2(0.0, -px))
	await get_tree().process_frame
	_button(false)
	await _wait(0.2)


## Clic en un selector hasta que marca la opción value.
func _select(id: String, value: String) -> void:
	for i in 8:
		if String(_st().dial.get(id, "")) == value:
			return
		await _click("mando:" + id)


## Espera a que acabe la marcha del horno (o la animación del taller), como mucho secs.
func _wait_run(secs := 12.0) -> void:
	var t0 := _t
	while _t - t0 < secs and (_st().running() or (not _st().act.is_empty() and float(_st().act.t) < float(_st().act.dur))):
		await get_tree().process_frame


## El tutorial, hasta el paso sid: pasa con «Siguiente» los pasos informativos o ya hechos (como la persona después de
## leerlos); no se salta un paso que pide hacer algo y aún no está hecho.
func _tut_to(sid: String) -> void:
	for i in 14:
		var tv: Dictionary = page.runner.latest().tutorial
		var st: Dictionary = tv.step
		if st.is_empty() or String(st.id) == sid:
			return
		if String(st.status) == "pendiente":
			_log("el tutorial espera en «%s» (camino de %s)" % [String(st.id), sid])
			return
		_press(page.tut_next)
		await _wait(0.3)


## Hace con el tutorial (sus pasos y «Hazlo como dice el paso») lo que falta de la pieza hasta el paso sid, deprisa.
func _quick_to(sid: String) -> void:
	for i in 30:
		var st: Dictionary = _st().current_step()
		if st.is_empty() or String(st.get("id", "")) == sid:
			return
		_post("do_step")
		if _st().running():
			_post("skip")
		await _wait(0.12)
		_post("skip")


## Mete la carga en su máquina: un clic en la puerta del horno (que se abre y se cierra) y espera a que entre.
func _insert() -> void:
	await _click("ventana")
	await _wait_run(3.0)


## Pasadas con la herramienta tool (T; Mayús: suave) mientras el paso del tutorial sid no se cumpla, como mucho n; cada una
## dura lo que tarda de verdad a la velocidad elegida.
func _passes(tool: String, sid: String, n := 12, light := false) -> void:
	_post("set_carve_tool", [tool])
	for i in n:
		var st: Dictionary = _st().current_step()
		if st.is_empty() or String(st.get("id", "")) != sid:
			return
		_key(KEY_T, light)
		await _wait(0.15)
		await _wait_run(2.6)


func _summary(what: String) -> void:
	var v: Dictionary = page.runner.latest()
	_log("%s: %s · etapa %s · %s · cetrería: %s" % [what, v.process_name, v.stage_name, v.sheet.verdict_text, v.care.text])


# ─────────────────────────────── escenas ───────────────────────────────

func _scene_1() -> void:
	_caption(0, "la cetrería y su interruptor: «Laboratorio experimental (reforja)»")
	await _wait(1.4)
	await _open_lab()
	_caption(0, "la primera vez: «¿Primera vez? Empieza por el horno»")
	_reveal(page.intro_box)
	await _wait(1.4)
	for b: Node in page.intro_box.find_children("*", "Button", true, false):
		if (b as Button).text == "Empezar el tutorial del horno":
			(b as Button).pressed.emit()
	_reveal(page.tut_card)
	await _wait(1.6)
	for i in 10:
		var st: Dictionary = _st().current_step()
		if st.is_empty():
			break
		_caption(0, String(st.get("title", "")))
		if String(st.get("id", "")) == "mando_temp_c":
			await _wait(0.8)
			await _turn("temp_c", 12)
			await _wait(0.6)
		elif String(st.get("id", "")) == "mando_modo":
			await _wait(0.8)
			await _click("mando:modo")
			await _wait(0.6)
		else:
			await _wait(1.8)
		_press(page.tut_next)
		await _wait(0.2)
	_caption(0, "la ayuda (H): ratón, teclado y dedo")
	_key(KEY_H)
	await _wait(2.4)
	_key(KEY_H)


func _scene_2() -> void:
	await _open_lab()
	_caption(1, "el zafiro: sus polvos, sus márgenes y su gemelo del banco")
	_press(page.recipe_tiles["zafiro"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["zafiro"])
	_reveal(page.make_card)
	await _wait(1.8)
	_reveal(page.tut_card)
	await _wait(0.8)
	_caption(1, "pesar: coger el tarro de la alúmina y verter en el plato")
	await _pour("al2o3", 2.0)
	_log("en el plato: %s g" % String.num(_st().pan_total(), 2))
	_caption(1, "cargar el crisol (o el alimentador del soplete)")
	await _click("crisol")
	await _wait(1.2)
	await _tut_to("modo")
	await _wait(0.8)
	_caption(1, "el modo: un clic en el selector, la opción siguiente (el modo elige la máquina)")
	await _select("modo", "sintetizar")
	await _wait(0.6)
	_caption(1, "meter la carga: la alúmina va a la tolva del soplete de Verneuil, por la puerta")
	await _insert()
	await _wait(0.6)
	_caption(1, "los parámetros: el dial de la temperatura con el ratón; los demás, con sus deslizadores")
	await _turn("temp_c", 10)
	_reveal(page.furnace_card)
	var rec: Dictionary = _st().forge.recommended().fire
	for k: Array in [["temp_c", 2100.0], ["time_s", float(rec.time_s)], ["atmosphere", "aire"]]:
		_post("set_control", k)
		await _wait(0.45)
	_caption(1, "arrancar: el botón rojo")
	await _click("arrancar")
	_reveal_side(page.furnace_card)
	_caption(1, "la llama funde el polvo y la bola crece hacia abajo; el reloj, el tiempo de verdad a ×3600")
	await _wait_run(10.0)
	await _wait(0.8)
	await _tut_to("enfriar")
	await _wait(0.6)
	_caption(1, "enfriar: el botón amarillo (el reloj, lo que tarda de verdad en poder cogerse)")
	await _click("sacar")
	await _wait_run(6.0)
	await _wait(0.6)
	await _tut_to("tocho")
	_view("taller")
	_reveal_side(page.shop_card)
	_caption(1, "el tocho con la sierra de disco, con agua")
	await _passes("sierra", "tocho")
	_caption(1, "desbastar con la muela gruesa, pasada a pasada")
	await _passes("muela_gruesa", "desbastar")
	_caption(1, "vaciarla por dentro con la fresa del eje flexible")
	await _passes("fresa", "vaciar")
	_caption(1, "la forma con la muela fina, hasta la silueta de la garra")
	await _passes("muela_fina", "forma", 16)
	_caption(1, "proteger la carne viva con la barrera")
	await _click("barrera")
	await _wait_run(3.0)
	await _tut_to("pulir")
	_caption(1, "pulir con un abrasivo más duro que la pieza")
	await _click("pulidora")
	await _wait_run(3.0)
	_caption(1, "probar el ajuste en la garra, sin pegarla: se pega en la cetrería")
	await _click("garra")
	await _wait_run(3.0)
	_view("pieza")
	_caption(1, "la funda, terminada y sin pegar: antes → después")
	_reveal(page.sheet_card)
	await _wait(3.0)
	_caption(1, "«Valores y fuentes»: cada dato con su calidad y su fuente")
	page.values_toggle.pressed.emit()
	await _wait(0.2)
	_reveal(page.values_card)
	await _wait(2.4)
	_summary("zafiro")


func _scene_3() -> void:
	await _open_lab()
	_press(page.recipe_tiles["zafiro"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["zafiro"])
	_caption(2, "lo recomendado (P) y cargar (L); «Arrancar» sin meter la carga: no arranca, y dice por qué")
	_key(KEY_P)
	_key(KEY_L)
	await _wait(0.4)
	_reveal(page.furnace_card)
	await _click("arrancar")
	await _wait(2.4)
	_caption(2, "meter la carga (M) y la temperatura, muy por debajo de la de la receta")
	_key(KEY_M)
	await _wait_run(2.0)
	await _tut_to("parametros")
	await _wait(0.6)
	_post("set_control", ["temp_c", 1700.0])
	await _wait(1.6)
	await _click("arrancar")
	_view("dentro")
	await _wait_run(10.0)
	_caption(2, "qué ha pasado, cómo se arregla y con qué mando")
	_reveal(page.tut_card)
	await _wait(3.6)
	_summary("zafiro frío")


func _scene_4() -> void:
	await _open_lab()
	_caption(3, "grafito y el metal que lo disuelve (hierro y cobalto)")
	_press(page.recipe_tiles["diamante_hpht"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["diamante_hpht"])
	_reveal(page.make_card)
	await _wait(1.6)
	_key(KEY_P)
	_reveal(page.bench_card)
	await _wait(0.8)
	await _click("crisol")
	await _wait(0.6)
	_caption(3, "la cápsula, entre los yunques de la prensa (M)")
	_key(KEY_M)
	await _wait_run(2.0)
	await _tut_to("parametros")
	_reveal(page.furnace_card)
	await _wait(1.4)
	_caption(3, "5,5 GPa y unos 1350 °C: la prensa se cierra; días de verdad, a ×3600")
	await _click("arrancar")
	await _wait(4.0)
	_caption(3, "más deprisa (X): a ×36 000 lo que falta dura menos y sale lo mismo")
	_key(KEY_X)
	await _wait_run(12.0)
	await _wait(1.0)
	await _tut_to("enfriar")
	_key(KEY_E)
	await _wait_run(3.0)
	await _tut_to("tallar")
	_view("pieza")
	_caption(3, "el cristal de diamante")
	await _wait(2.2)
	_summary("diamante HPHT")


func _scene_5() -> void:
	await _open_lab()
	_caption(4, "esto es ficción: nadie recubre la garra de un animal vivo")
	_press(page.recipe_tiles[State.LIVE])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", [State.LIVE])
	_reveal(page.tut_card)
	await _wait(2.2)
	await _tut_to("proteger")
	await _wait(1.0)
	_caption(4, "la barrera sobre la mitad de la garra con carne viva")
	await _click("barrera")
	await _wait_run(3.0)
	await _tut_to("recubrir")
	await _wait(0.8)
	_caption(4, "la pistola: el termómetro dice cuánto calor llega a la carne viva")
	await _click("pistola")
	await _wait_run(4.0)
	await _wait(1.6)
	_view("pieza")
	await _wait(2.0)
	_reveal(page.sheet_card)
	await _wait(2.6)
	_summary("garra viva")


func _scene_6() -> void:
	await _open_lab()
	_caption(5, "una bola de zafiro recién sacada del horno, fría")
	_press(page.recipe_tiles["zafiro"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["zafiro"])
	await _quick_to("tocho")
	_reveal_side(page.shop_card)
	_view("pieza")
	await _wait(1.0)
	_caption(5, "una herramienta más blanda no muerde: la lima de acero resbala sobre el zafiro")
	_post("set_carve", ["abrasive", "lima_acero"])
	await _passes("sierra", "tocho", 1)
	await _wait(1.6)
	_post("set_carve", ["abrasive", "diamante"])
	_caption(5, "la sierra de diamante con su agua: los dos cortes del tocho, pegado en su palo")
	await _passes("sierra", "tocho")
	_caption(5, "la muela gruesa (grano 80) desbasta hacia la silueta de la garra")
	await _passes("muela_gruesa", "desbastar")
	_caption(5, "la fresa del eje flexible la vacía por dentro")
	await _passes("fresa", "vaciar")
	_caption(5, "la muela fina (grano 220) sigue la línea, pasada a pasada, hasta la silueta: mira el indicador")
	await _passes("muela_fina", "forma", 16, true)
	await _passes("muela_fina", "forma", 16)
	await _wait(1.6)
	_log("tallado: %s" % String(_st().forge.carve_state().text))
	_caption(5, "otra bola: la gruesa no sigue la línea, y una pasada de más se pasa de la silueta")
	_post("restart")
	_post("tutorial_goto", ["zafiro"])
	await _quick_to("vaciar")
	_post("set_carve_tool", ["muela_gruesa"])
	_key(KEY_T)
	await _wait_run(3.0)
	await _wait(2.4)
	_log("pasada de más: %s" % String(_st().forge.carve_state().text))
	_summary("tallado por pasadas")


func _scene_7() -> void:
	await _open_lab()
	_caption(6, "la funda de zafiro, terminada, pulida y probada en la garra, sin pegar")
	_press(page.recipe_tiles["zafiro"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["zafiro"])
	await _quick_to("")
	await _wait(0.4)
	_reveal(page.sheet_card)
	await _wait(2.0)
	_caption(6, "«Pasar a la cetrería para colocarla»: allí se pega sobre la garra y se acaba a mano")
	_press(page.care_button)
	await _wait(0.4)
	care.call("set_view", "garra")
	var cv: Dictionary = care.runner.latest()
	_log("en la cetrería: %s · reforjada %s" % [String(cv.setup.inlay), cv.reforged])
	await _wait(3.0)


func _scene_8() -> void:
	if bool(care.lab_open):
		(page.mode_seg.buttons["cetreria"] as Button).pressed.emit()
	_caption(7, "en la cetrería: seca, la tenaza raja la garra hasta la carne viva")
	care.call("set_view", "garra")
	var st: CareState = care.runner.state
	st.configure({ "inlay": "none" })
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	await _wait(0.8)
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4))
	await _wait(CareState.CLIP_CLOSE_S + 0.3)
	st.release()
	await _wait(1.2)
	_caption(7, "primero, parar la sangre: polvo hemostático y presión (reloj ×10)")
	st.pick("hemostatico")
	st.time_scale = 10.0
	var s0 := st.care.apex_mm()
	st.press_on(s0)
	var t0 := _t
	while _t - t0 < 4.0 and bool(st.care.snapshot().bleeding.active):
		st.drag(0.0, 0.0, s0, 1.0 / 30.0)
		await get_tree().process_frame
	st.release()
	st.time_scale = 1.0
	st.drop()
	await _wait(0.6)
	_caption(7, "«Reforjar con material»: una prótesis de otro material")
	# el botón, al pie de la explicación del error
	var btn: Control = care.reforge_button
	if (care.right_scroll as Control).visible:
		var tw := create_tween()
		var y := btn.get_global_rect().end.y - (care.right as Control).get_global_rect().position.y - (care.right_scroll as Control).size.y + 24.0
		tw.tween_property(care.right_scroll, "scroll_vertical", int(maxf(y, 0.0)), 0.45)
	else:
		lab.call("scroll_to", btn, 120.0)
	await _wait(2.4)
	_press(care.reforge_button)
	page = care.lab_page
	await _wait(0.4)
	_view("taller")
	_reveal(page.make_card)
	_caption(7, "en el laboratorio, con la forma «Prótesis entera»")
	await _wait(2.4)
	_log("garra rota: forma %s · perfil roto %s" % [String(page.runner.latest().shape), page.runner.latest().profile.broken])
	_caption(7, "la pieza de zafiro, hecha y enfriada (sin tallar: se le da forma en la cetrería)")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["zafiro"])
	await _quick_to("comprobar_pieza")
	_view("pieza")
	_reveal(page.sheet_card)
	await _wait(2.6)
	_caption(7, "«Pasar a la cetrería»: vuelve como un bloque en bruto pegado al muñón (FICCIÓN)")
	_press(page.care_button)
	await _wait(0.4)
	care.call("set_view", "garra")
	var blk: Variant = st.care.snapshot().claw.block
	_log("en la cetrería: bloque %s" % [blk.material if blk is Dictionary else "no"])
	await _wait(3.0)


func _scene_9() -> void:
	await _open_lab()
	_post("set_tutorial", [false])
	_reveal_view()
	for c: Array in [["acero", "inducción: la bobina calienta el crisol al rojo y cuela en el molde"], ["oro", "horno de vacío: funde y cuela"],
			["diamante_cvd", "plasma de metano e hidrógeno: el diamante crece capa a capa"], ["metal_duro", "sinterizado: la pieza encoge"],
			["rubi", "el rubí en la llama: un poco de óxido de cromo"]]:
		_caption(8, String(c[1]))
		_press(page.recipe_tiles[String(c[0])])
		_post("restart")
		_key(KEY_P)
		_key(KEY_L)
		_view("dentro")
		await _wait(0.8)
		_key(KEY_M)
		await _wait_run(2.0)
		_key(KEY_ENTER)
		await _wait(3.6)
		_key(KEY_SPACE)
		await _wait(1.2)
		_log("%s: %s" % [String(c[0]), String(page.runner.latest().run.get("visual", ""))])


## La prótesis de verdad (unidad 5j): la garra rota se repara con acrílico dental, que se mezcla sin horno, se pega sobre lo
## que queda y se lima en el animal (la técnica del pico de las aves): sin ficción.
func _scene_10() -> void:
	var st: CareState = await _break_claw(9)
	await _wait(0.4)
	_press(care.reforge_button)
	page = care.lab_page
	await _wait(0.4)
	_post("set_tutorial", [true])
	_reveal(page.make_card)
	_caption(9, "«Reforjar con material»: el acrílico dental, la vía real, junto a las recetas de fantasía")
	await _wait(2.6)
	_press(page.recipe_tiles[State.ACRYLIC])
	_post("tutorial_goto", [State.ACRYLIC])
	await _wait(0.3)
	_reveal(page.tut_card)
	_caption(9, "el tutorial: así se repara de verdad el pico de las aves; en una garra, la misma técnica")
	await _wait(2.6)
	await _tut_to("mezclar")
	_view("banco")
	_caption(9, "mezclar el polvo y el líquido: un clic en el estuche (fragua en frío, sin horno)")
	await _wait(1.4)
	await _click("acrilico")
	await _wait(1.2)
	_view("pieza")
	_reveal_side(page.sheet_card)
	_caption(9, "«Pasar a la cetrería»: un bloque de acrílico sobre lo que queda de la garra, sin ficción")
	await _wait(2.4)
	_summary("acrílico")
	_press(page.care_button)
	await _wait(0.4)
	care.call("set_view", "garra")
	var blk: Variant = st.care.snapshot().claw.block
	_log("en la cetrería: bloque %s · ficción %s" % [blk.material if blk is Dictionary else "no", blk.fiction if blk is Dictionary else "-"])
	await _wait(2.0)
	await _shape_block(st)


## Rompe la garra de la cetrería (seca, con la tenaza, hasta la carne viva) y para la sangre, para las escenas de la garra
## rota (i: su número). Devuelve el estado de la cetrería.
func _break_claw(i: int) -> CareState:
	if bool(care.lab_open):
		(page.mode_seg.buttons["cetreria"] as Button).pressed.emit()
	_caption(i, "otra garra rota: seca, la tenaza la raja hasta la carne viva")
	care.call("set_view", "garra")
	var st: CareState = care.runner.state
	st.configure({ "inlay": "none" })
	st.set_sedation("sujecion")
	st.set_humidity("seca")
	st.pick("tenaza")
	await _wait(0.8)
	st.press_on(st.care.apex_mm() - (st.care.quick_cover_mm() - 0.4))
	await _wait(CareState.CLIP_CLOSE_S + 0.3)
	st.release()
	await _wait(1.0)
	_caption(i, "primero, parar la sangre: polvo hemostático y presión (reloj ×10)")
	st.pick("hemostatico")
	st.time_scale = 10.0
	var s0 := st.care.apex_mm()
	st.press_on(s0)
	var t0 := _t
	while _t - t0 < 4.0 and bool(st.care.snapshot().bleeding.active):
		st.drag(0.0, 0.0, s0, 1.0 / 30.0)
		await get_tree().process_frame
	st.release()
	st.time_scale = 1.0
	st.drop()
	return st


## Le da forma al bloque de acrílico en la cetrería: la lima de acero y la amoladora a toques cortos.
func _shape_block(st: CareState) -> void:
	_caption(9, "se lima hasta la forma de la garra natural: la lima de acero muerde el acrílico (~20 HV)")
	st.pick("lima_fina")
	await _wait(0.6)
	for k in 6:
		var s1 := st.care.apex_mm() - 2.5
		st.press_on(s1)
		var t1 := _t
		while _t - t1 < 0.35:
			st.drag(0.6, 0.6, minf(s1 + (_t - t1) * 7.0, st.care.apex_mm()), 1.0 / 30.0)
			await get_tree().process_frame
		st.release()
		await _wait(0.12)
	_caption(9, "y con la amoladora, a toques cortos: el acrílico conduce el calor tan mal como la queratina")
	st.pick("amoladora")
	st.toggle_rotary()
	st.set_angle(30.0)
	await _wait(0.6)
	for k in 5:
		st.press_on(st.care.apex_mm() - 0.3)
		await _wait(1.0)
		st.release()
		await _wait(0.8)
	st.toggle_rotary()
	var sn: Dictionary = st.care.snapshot()
	_log("limado: %s mm³ quitados · punta %s µm · carne viva hasta %s °C" % [String.num(float(sn.claw.removedMm3), 1), String.num(float(sn.tip.tipRadiusUm), 0), String.num(float(sn.thermal.peakQuickC), 1)])
	await _wait(2.0)


## La prótesis de una garra rota hecha entera en el laboratorio (unidad 5j): la funda se calcula con lo que queda de la
## garra (stump_mm) y para la garra de su dedo; rehace lo que falta, maciza, hasta la punta natural, y se pega encima.
func _scene_11() -> void:
	await _break_claw(10)
	await _wait(0.4)
	_press(care.reforge_button)
	page = care.lab_page
	await _wait(0.4)
	_post("set_tutorial", [true])
	_press(page.recipe_tiles["zafiro"])
	_post("tutorial_goto", ["zafiro"])
	_caption(10, "la prótesis de zafiro (ficción) hecha en el laboratorio: tallada, pegada, pulida y probada")
	await _quick_to("")
	await _wait(0.4)
	_view("pieza")
	_reveal_side(page.make_card)
	_caption(10, "rehace lo que falta, maciza, hasta la punta natural de la garra de su dedo, y se pega sobre lo que queda")
	await _wait(3.2)
	_view("taller")
	await _wait(2.4)
	_log("prótesis: %s" % String(page.runner.latest().sheath.text))


## Cada carga en su máquina (5m; petición 42): la puerta se abre, la carga entra y se cierra; sin ella, «Arrancar» no deja.
func _scene_12() -> void:
	await _open_lab()
	_post("set_tutorial", [false])
	_reveal_view()
	for c: Array in [["zafiro", "la alúmina, en la tolva del soplete de Verneuil"], ["diamante_hpht", "la cápsula, entre los yunques de la prensa"],
			["diamante_cvd", "el sustrato, bajo la campana del reactor de plasma"], ["metal_duro", "la pastilla prensada, en la bandeja del horno de sinterizar"],
			["acero", "el crisol, dentro de la bobina de inducción"]]:
		_caption(11, String(c[1]))
		_press(page.recipe_tiles[String(c[0])])
		_post("restart")
		_key(KEY_P)
		_key(KEY_L)
		_view("general")
		await _wait(0.6)
		await _insert()
		_view("dentro")
		await _wait(2.0)
		_log("%s: dentro %s" % [String(c[0]), _st().charge_inside()])


## El reloj del tiempo de verdad (5m): la alúmina se sinteriza horas; a ×600 el reloj corre despacio y a ×36 000 acaba enseguida, y
## sale lo mismo.
func _scene_13() -> void:
	await _open_lab()
	_post("set_tutorial", [false])
	_press(page.recipe_tiles["alumina"])
	_post("restart")
	_key(KEY_P)
	_key(KEY_L)
	_key(KEY_M)
	await _wait_run(2.0)
	_post("set_speed", [1])
	_reveal(page.furnace_card)
	_view("dentro")
	_caption(12, "la alúmina sinterizada: horas de verdad; a ×600, el reloj corre despacio")
	_key(KEY_ENTER)
	await _wait(5.0)
	_log("a ×600: %s · %s" % [String(page.runner.latest().clock.text), String(page.runner.latest().clock.life)])
	_caption(12, "×36 000 (X, X): lo que falta dura menos; en la vida real tardaría lo mismo")
	_key(KEY_X)
	_key(KEY_X)
	await _wait_run(10.0)
	await _wait(1.6)
	_log("al acabar: %s · %s" % [String(page.runner.latest().clock.text), String(page.runner.latest().clock.life)])
	_post("set_speed", [State.DEFAULT_SPEED])


## La cera perdida con la garra de un tigre (5m; petición 42): el oro se cuela en un molde con la forma de la funda de su garra.
func _scene_14() -> void:
	await _open_lab()
	page.call("open_with", { "animal": "tigre", "claw": "tigre" })
	_post("set_tutorial", [true])
	_press(page.recipe_tiles["oro"])
	_post("restart")
	_post("tutorial_goto", ["oro"])
	_reveal(page.wax_card)
	_view("banco")
	_caption(13, "el modelo de cera de la funda de la garra del tigre, con su bebedero (C), a la medida de lo que encoge el oro")
	await _wait(1.2)
	await _click("cera")
	await _wait_run(3.0)
	await _wait(1.4)
	_caption(13, "revestirlo de yeso (C): fragua 2 h de verdad")
	_key(KEY_C)
	await _wait_run(4.0)
	await _wait(1.0)
	_caption(13, "quemar la cera: el molde al horno de calentar (P pone el ciclo, M lo mete) y el reloj del ciclo")
	_key(KEY_P)
	_view("general")
	await _insert()
	_view("dentro")
	_reveal_side(page.furnace_card)
	_key(KEY_ENTER)
	await _wait_run(8.0)
	await _wait(1.0)
	_caption(13, "pesar el oro, el modo «Fundir y colar», el crisol dentro y arrancar: cuela en el molde")
	await _quick_to("parametros")
	_post("do_step")
	_view("dentro")
	await _wait_run(8.0)
	await _wait(1.0)
	_caption(13, "enfriar y romper el molde: sale la funda con la forma de la garra y su bebedero")
	await _quick_to("romper")
	_view("pieza")
	_post("do_step")
	await _wait_run(3.0)
	await _wait(2.2)
	_caption(13, "cortar el bebedero con la sierra y limar el muñón con la muela fina")
	_view("taller")
	await _passes("sierra", "cortar_bebedero", 3)
	_view("pieza")
	await _passes("muela_fina", "limar", 12)
	_caption(13, "pulir, probar el ajuste y pasarla a la cetrería para colocarla")
	await _quick_to("pasar")
	_reveal(page.sheet_card)
	await _wait(2.6)
	_summary("oro a la cera perdida")


# ─────────────────────────────── 5r · la mesa de soldar ───────────────────────────────

## Una pieza de metal terminada con el tutorial de la receta rec (hasta el paso de pulirla), para soldar.
func _weld_piece(rec: String) -> void:
	await _open_lab()
	_post("set_tutorial", [true])
	_press(page.recipe_tiles[rec])
	_post("restart")
	_post("tutorial_goto", [rec])
	await _quick_to("pulir")
	_post("tutorial_goto", ["soldadura"])
	# los mandos recomendados para esta pieza (la energía que atraviesa su pared sin perforarla)
	_post("set_weld_params", [_st().forge.weld_recommended().weld_setup])


## Recorre la costura con el puntero apretado (el pedal): de u0 a u1 en secs; los pulsos salen al ritmo del aparato.
func _sweep_seam(u0: float, u1: float, secs: float) -> void:
	await _move_to("costura", 0.4)
	var p0: Vector2 = _scene().call("weld_seam_screen_point", u0)
	if p0.x < 0.0:
		return
	_set_pointer(p0)
	_button(true)
	var t0 := _t
	while _t - t0 < secs:
		var u := lerpf(u0, u1, clampf((_t - t0) / secs, 0.0, 1.0))
		var p: Vector2 = _scene().call("weld_seam_screen_point", fposmod(u, 1.0))
		if p.x >= 0.0:
			_set_pointer(p)
		await get_tree().process_frame
		var wl: Dictionary = page.runner.latest().weld
		if bool(wl.done) or int(wl.get("covered", 0)) >= int(wl.get("pulses_need", 1 << 30)):
			break
	_button(false)
	await _fill_seam_gaps(12.0)
	await _wait(0.3)


## Los tramos que el ratón no alcanza (en el teléfono la vuelta se ve de canto y la mitad de atrás queda tapada por la garra):
## con «Un punto (J)», que suelta el pulso en el primer tramo que falta, como haría una persona; como mucho secs.
func _fill_seam_gaps(secs: float) -> void:
	var t0 := _t
	while _t - t0 < secs:
		var wl: Dictionary = page.runner.latest().weld
		if bool(wl.done) or int(wl.get("covered", 0)) >= int(wl.get("pulses_need", 1 << 30)):
			return
		_key(KEY_J)
		await get_tree().process_frame


## El soplete por la costura como lo haría una persona: la llama en el primer tramo sin soldar hasta que la plata corre, y al
## siguiente (con el pedal apretado todo el rato); como mucho secs.
func _braze_seam(secs: float) -> void:
	await _move_to("costura", 0.4)
	var w: Dictionary = page.runner.latest().weld
	var n := maxi(int(w.get("pulses_need", 1)), 1)
	var p0: Vector2 = _scene().call("weld_seam_screen_point", 0.5 / float(n))
	if p0.x < 0.0:
		return
	_set_pointer(p0)
	_button(true)
	var t0 := _t
	while _t - t0 < secs:
		w = page.runner.latest().weld
		var cov := int(w.get("covered", 0))
		if bool(w.done) or cov >= n:
			break
		var p: Vector2 = _scene().call("weld_seam_screen_point", (float(cov) + 0.5) / float(n))
		if p.x >= 0.0:
			_set_pointer(p)
		await get_tree().process_frame
	_button(false)
	await _wait(0.3)


func _scene_15() -> void:
	await _weld_piece("acero")
	_reveal(page.weld_card)
	_view("soldar")
	_caption(14, "la funda de acero y su punta en la mesa: un clic en la soldadora láser las coloca, a ojo")
	_post("set_weld", ["method", "laser"])
	await _wait(0.8)
	await _click("soldadura")
	await _wait(1.2)
	_caption(14, "desalineadas: se alinean bajo el microscopio (I) antes de soldar")
	_key(KEY_I)
	await _wait(1.0)
	# en la tarjeta: lo que pide la costura, la barra «Pulsos: N de ~M» y, al acabar, el veredicto de la unión
	_reveal_side(page.weld_align_label)
	_caption(14, "con las gafas puestas y sin mirar el haz: apretado sobre la costura y recorriéndola, un punto por pulso")
	await _sweep_seam(0.0, 2.1, 26.0)
	await _wait(1.5)
	await _phone_card(page.weld_align_label)
	_caption(14, "costura entera y unión buena: el cordón que sobresale se lima con la muela fina y se pule")
	_view("pieza")
	await _passes("muela_fina", "limar_costura", 8)
	await _quick_to("pasar")
	_reveal(page.sheet_card)
	await _wait(2.0)
	_summary("acero soldado con láser")


func _scene_16() -> void:
	await _weld_piece("titanio")
	_reveal(page.weld_card)
	_view("soldar")
	_caption(15, "el titanio al aire, sin argón: el láser suelda, pero el oxígeno lo contamina")
	_post("set_weld", ["method", "laser"])
	_post("set_weld", ["gas", "aire"])
	await _click("soldadura")
	await _wait(0.8)
	_key(KEY_I)
	await _wait(0.6)
	_reveal_side(page.weld_align_label)
	# hasta cubrir la costura entera (para en cuanto la cubre): el veredicto de la unión contaminada sale en la tarjeta
	await _sweep_seam(0.0, 3.1, 40.0)
	_caption(15, "costura entera, pero azul y gris: el titanio sin argón se ha contaminado y la unión es frágil")
	_reveal_side(page.weld_align_label)
	await _wait(3.0)
	await _phone_card(page.weld_align_label)
	_summary("titanio sin argón")


func _scene_17() -> void:
	await _weld_piece("acero")
	_reveal(page.weld_card)
	_view("soldar")
	_caption(16, "una punta de metal duro en la funda de acero: no se funde; se suelda con plata y el soplete")
	_post("set_weld", ["method", "braze"])
	_post("set_weld", ["part", "punta"])
	_post("set_weld", ["material", "metal_duro"])
	await _click("soldadura")
	await _wait(0.8)
	_key(KEY_I)
	await _wait(0.6)
	_reveal_side(page.weld_align_label)
	# el soplete: tramo a tramo, la llama en el siguiente cuando el de antes ya ha soldado (refundir un tramo más de dos veces
	# agota el fundente)
	await _braze_seam(40.0)
	await _wait(2.5)
	_summary("punta de metal duro con plata")


func _scene_18() -> void:
	await _open_lab()
	_caption(17, "el metal duro, con su tutorial: el primer paso es pesar")
	_press(page.recipe_tiles["metal_duro"])
	_post("restart")
	_post("set_tutorial", [true])
	_post("tutorial_goto", ["metal_duro"])
	_reveal(page.tut_card)
	_view("banco")
	await _wait(2.0)
	_caption(17, "el carburo de tungsteno: coger el tarro y verter en el plato")
	await _pour("wc", 0.6)
	_reveal(page.bench_card)
	await _wait(1.6)
	await _phone_card(page.bench_card)
	_caption(17, "el cobalto, con los botones de la balanza: se pasa")
	var jars: Dictionary = page.jar_rows
	for b: Node in (jars["co"].box as Control).find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("+") and ((b as Button).text.contains("0.1 ") or (b as Button).text.contains("0,1 ")):
			for i in 4:
				_press(b as Button)
				await _wait(0.25)
			break
	await _wait(1.6)
	await _phone_card(page.bench_card)
	_caption(17, "el cobalto ya está mezclado con el carburo y no se separa: vaciar el plato (Retroceso)")
	_key(KEY_BACKSPACE)
	await _wait(1.0)
	_caption(17, "pesar con los botones de dosis de cada polvo, hasta lo que dice la balanza")
	for id: String in ["wc", "co"]:
		var row: Dictionary = jars[id]
		var target := 0.0
		for j: Dictionary in _st().bench_view().jars:
			if String(j.id) == id:
				target = float(j.target_g)
		for i in 3:
			var g := float((row.dose_g as Array)[i])
			for n in 12:
				if float(_st().pan.get(id, 0.0)) + g > target + 1e-12:
					break
				_press(row.dose_b[i] as Button)
				await _wait(0.06)
		await _wait(0.6)
	_reveal(page.bench_card)
	await _wait(1.6)
	await _phone_card(page.bench_card)
	_caption(17, "«Listo: carga el crisol (L)»: el tutorial sigue solo")
	_key(KEY_L)
	await _wait(2.0)
	_reveal(page.tut_card)
	await _wait(1.5)
	_log("en el plato: %s g · mezcla: %s" % [String.num(_st().pan_total(), 4), str(_st().snap().mix.get("ok", false))])
