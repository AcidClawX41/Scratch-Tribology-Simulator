## Sección «Tribología biológica»: el laboratorio de la 1.x (uñas, garras y colmillos) con la misma interfaz 2D.
## Tres páginas, cada una con su botón en la barra de arriba (PAGES):
## - «Banco de ensayo»: la composición de App.jsx, dos columnas en ventanas anchas (herramienta, material y parámetros |
##   ARAÑAR, banco y resultado, modo dual, comparativa y logros) y una columna con desplazamiento en el teléfono;
## - «Coche en marcha» (2.0): la tarjeta del coche a todo lo ancho (hasta CAR_MAX), con su propio selector de animal;
## - «Cetrería» (2.0, unidad 5b): el cuidado de las garras en 3D, con las herramientas en la mano y el tutorial
##   (app/lab/cetreria/care_page.gd).
## Antes el coche iba en la misma página que el banco y se amontonaban tarjetas y sonidos (Eric). La página que no se ve
## no calcula ni suena: el banco no avanza ni zumba en las otras, el coche no pinta ni golpea fuera de la suya, y la
## cetrería para su reloj, su escena 3D y sus bucles de sonido al salir de la suya.
## - Estado: core/lab/lab_state.gd (LabState). La interfaz se construye una vez y se pone al día cuando el banco avisa
##   (señal changed), como mucho una vez por fotograma. La física es siempre la del core: aquí no se calcula nada.
## - Dibujos: una caché compartida (ArtCache) que construye y rasteriza en hilos, solo cuando cambian las entradas.
## - Sonido: los WAV de la 1.x por el bus «Lab», con el volumen que pide LabState. El interruptor general del
##   programa silencia «Master». Con un aguijón (2.0), el efecto de cada resultado lo elige SfxInsects (el de la 1.x
##   para lo demás) y el zumbido del insecto es un bucle horneado por especie (assets/sfx/lab/zumbido-*.wav) que suena
##   con el volumen que pide el banco (Bench.buzz_state): al llegar, mientras pica y al irse.
## - Vibración (solo en el teléfono): cada efecto que suena da su pulso (app/common/haptics.gd), también con el sonido
##   silenciado, salvo que se apague con el interruptor de la tarjeta de logros.
## - Contrato con el programa (main.gd): la raíz es un Control; oculta, main la pone en PROCESS_MODE_DISABLED y así
##   se paran el reloj del banco, las animaciones y los sonidos pendientes. Ofrece headline(), fundamentos() y
##   fundamentos_note() para la barra superior.
## - Atajo: Ctrl+Intro (⌘+Intro en macOS) lanza el ensayo desde cualquier parte de la sección.
## - Ajustes (CONTRATOS.md → «Ajustes»): main.gd pone settings_path (user://ajustes.cfg) antes de mostrarla; la sección
##   guarda en [lab] los logros, el cuaderno y el número de ensayos (badges, notebook, count), si vibra (haptics), la
##   página (page) y si ya se ha visto la invitación de la cetrería (care_intro) y la de su laboratorio experimental de la
##   reforja (forge_intro), y los recupera al abrir. Sin settings_path (tests, demo, la escena suelta) no se guarda nada.
extends Control

const Lab = preload("res://core/lab/lab.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Ui = preload("res://app/common/ui.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const SfxPlayer = preload("res://app/common/sfx_player.gd")
const Haptics = preload("res://app/common/haptics.gd")
const ToolCard = preload("res://app/lab/tool_card.gd")
const TargetCard = preload("res://app/lab/target_card.gd")
const ParamsCard = preload("res://app/lab/params_card.gd")
const ResultCard = preload("res://app/lab/result_card.gd")
const DualCard = preload("res://app/lab/dual_card.gd")
const MovingCarCard = preload("res://app/lab/moving_car_card.gd")
const MovingCarState = preload("res://core/lab/moving_car_state.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CompareCard = preload("res://app/lab/compare_card.gd")
const BadgesCard = preload("res://app/lab/badges_card.gd")
const RunButton = preload("res://app/lab/run_button.gd")
const Bench = preload("res://app/lab/bench.gd")
const Segmented = preload("res://app/common/segmented.gd")
const CarePage = preload("res://app/lab/cetreria/care_page.gd")

## Emite el titular de la barra superior del programa al cambiar de página (main.gd lo escucha si existe).
signal headline_changed(text: String)

## Páginas de la sección (la barra de arriba): el banco de ensayo, el coche en marcha y la cetrería.
const PAGE_BENCH := "banco"
const PAGE_CAR := "coche"
const PAGE_CARE := "cetreria"
const PAGES := [
	{ "id": PAGE_BENCH, "name": "Banco de ensayo", "title": "Qué raya, corta o perfora a qué: uñas, garras, colmillos y aguijones" },
	{ "id": PAGE_CAR, "name": "Coche en marcha", "title": "Una rapaz, un tigre o un oso encima de un coche en marcha, o un casuario que lo patea" },
	{ "id": PAGE_CARE, "name": "Cetrería", "title": "Recortar, limar y afilar las garras de una rapaz, un tigre, un oso o un velocirraptor dormido, en 3D y con su tutorial" },
]
## Nombres cortos de las páginas para las pantallas estrechas (con tres botones, los largos no caben en un teléfono).
const PAGE_SHORT := { PAGE_BENCH: "Banco", PAGE_CAR: "Coche", PAGE_CARE: "Cetrería" }
## Por debajo de este ancho (px lógicos), la barra de páginas usa los nombres cortos.
const PAGE_SHORT_BELOW := 640.0
## Titular de la barra superior en cada página.
const HEADLINES := { PAGE_BENCH: "¿Qué raya a qué?", PAGE_CAR: "¿Aguanta encima del coche?", PAGE_CARE: "¿Afilada como una daga?" }
## Ancho máximo de la página del coche en marcha: una columna centrada (más ancha, los párrafos se leen peor).
const CAR_MAX := 1040.0

## Ancho (px lógicos) a partir del cual hay dos columnas: el @media (min-width: 1060px) de la 1.x.
const WIDE := 1060.0
const NARROW_MAX := 640.0
const WIDE_MAX := 1320.0
const GUTTER := 16.0
## Mientras se arrastra un deslizador, la comparativa y el modo dual (hasta 17 y 8 ensayos) se recalculan como
## mucho cada HEAVY_MS milisegundos.
const HEAVY_MS := 150.0
## Sección de los ajustes del laboratorio en el archivo del programa.
const SETTINGS_SECTION := "lab"

var lab: LabState
## Script del estado del banco (LabState o una subclase: los tests ponen un espía antes de setup()).
var state_script: GDScript = LabState
## Archivo de ajustes (lo pone main.gd antes de setup(); vacío: no se guarda ni se recupera nada).
var settings_path := ""
var _care_intro_seen := false
var _forge_intro_seen := false
var art: ArtCache
var sound: SfxPlayer
## Zumbido del insecto del banco principal y el bucle que suena ("" en silencio).
var buzz: AudioStreamPlayer
var buzz_id := ""
## Vibración (la crea setup(); los tests ponen antes una que cuenta los pulsos).
var haptics: Haptics
## Página visible (PAGE_BENCH o PAGE_CAR), su barra y el margen de la barra (el mismo que el del contenido).
var page := PAGE_BENCH
var page_bar: Segmented
var bar_margin: MarginContainer
var scroll: ScrollContainer
var content: MarginContainer
var columns: BoxContainer
var left_col: VBoxContainer
var right_col: VBoxContainer
var tool_card: ToolCard
var target_card: TargetCard
var params_card: ParamsCard
var run_button: RunButton
var result_card: ResultCard
var dual_card: DualCard
## El coche en marcha (2.0): la rapaz que se agarra, el tigre o el oso que se abalanza o el casuario que patea (su estado
## y sus hilos, dentro).
var moving_car_card: MovingCarCard
var compare_card: CompareCard
var badges_card: BadgesCard
## La cetrería (2.0, unidad 5b): su estado, su hilo y su escena 3D, dentro.
var care_page: CarePage
var model_note: Label
var benches: Array[Bench] = []
var reduce_motion := false
## Tiempo de la sección (ms): la suma de los pasos de step().
var clock_ms := 0.0
## Métrica: duración del último refresco de la interfaz (ms).
var last_refresh_ms := 0.0
var _built := false
var _dirty := false
var _heavy_dirty := false
var _last_heavy := -1.0e9
var _wide := true
var _saved_progress := ""  # firma del progreso guardado (se vuelve a guardar cuando cambia)


func _ready() -> void:
	setup()


## Construye la sección (una vez). Los tests la llaman sin árbol de escena.
func setup() -> void:
	if _built:
		return
	_built = true
	if theme == null and not _has_theme_above():
		theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reduce_motion = Ui.reduce_motion()
	art = ArtCache.new()
	sound = SfxPlayer.new("Lab")
	add_child(sound)
	buzz = AudioStreamPlayer.new()
	buzz.name = "Zumbido"
	buzz.bus = &"Lab"
	add_child(buzz)
	if haptics == null:
		haptics = Haptics.new()
	lab = state_script.new(_play, SfxInsects.sfx_for_result)
	_load_settings()
	lab.changed.connect(_on_lab_changed)
	_build()
	moving_car_card.reduce_motion = reduce_motion
	moving_car_card.play_sfx = _play  # el golpe del coche en marcha suena por el bus «Lab», como el banco
	care_page.setup(_play)  # la cetrería suena por el bus «Lab», con la vibración del teléfono
	# la invitación «¿Primera vez? Empieza aquí» de la cetrería se enseña hasta que se pulsa (y se recuerda)
	care_page.set_intro_seen(_care_intro_seen)
	care_page.intro_done.connect(func() -> void: _save_settings({ "care_intro": true }))
	care_page.try_on_bench.connect(_care_to_bench)
	# el laboratorio experimental de la reforja (unidad 5f), dentro de la cetrería; su invitación también se recuerda
	care_page.lab_intro_seen = _forge_intro_seen
	care_page.lab_intro_done.connect(func() -> void: _save_settings({ "forge_intro": true }))
	care_page.plug_reforge_lab()
	# 5t-B · las opciones de accesibilidad de la reacción del animal (el efecto de la lente y el temblor de la cámara), en [lab]
	care_page.set_reaction_options(_load_reaction_options())
	care_page.reaction_options_changed.connect(func(o: Dictionary) -> void:
		_save_settings({ "reaction_lens_fx": bool(o.get("lens_fx", true)), "reaction_shake": bool(o.get("shake", true)) }))
	# 5u · el progreso del veterinario, junto a los ajustes (user://cetreria.cfg en el programa; sin ajustes, no se guarda)
	if settings_path != "":
		care_page.set_progress_path(settings_path.get_base_dir().path_join("cetreria.cfg"))
	for c: Control in [tool_card, target_card, params_card, result_card, dual_card, moving_car_card, compare_card, badges_card]:
		c.call("setup", lab, art)
	badges_card.show_haptics(haptics.available, haptics.enabled)
	badges_card.haptics_toggled.connect(set_haptics)
	run_button.pressed.connect(run)
	run_button.shortcut_label = "" if OS.has_feature("mobile") else ("⌘ ↩" if OS.get_name() == "macOS" else "Ctrl ↩")
	benches = [result_card.bench]
	benches.append_array(dual_card.benches)
	for b in benches:
		b.reduce_motion = reduce_motion
	# precarga de las losas en hilos: todas en el banco principal; los coches en los del modo dual
	result_card.bench.prewarm(Catalog.TARGETS.map(func(t: Dictionary) -> String: return t.id))
	for b in dual_card.benches:
		b.prewarm(Lab.DUEL_CARS.map(func(t: Dictionary) -> String: return t.id))
	resized.connect(_layout)
	set_page(page, false)
	refresh_now()


## ¿Hereda ya un tema (el del programa)?
func _has_theme_above() -> bool:
	var n := get_parent()
	while n != null:
		if n is Control and (n as Control).theme != null:
			return true
		n = n.get_parent()
	return false


func _build() -> void:
	# la barra de páginas queda fija arriba; debajo, la página con su desplazamiento
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	bar_margin = Ui.margin(16, 12, 16, 2)
	root.add_child(bar_margin)
	page_bar = Segmented.new(PAGES.map(func(p: Dictionary) -> Dictionary: return { "id": p.id, "label": p.name, "title": p.title }),
		page, "Página de la tribología biológica")
	page_bar.selected.connect(set_page)
	bar_margin.add_child(page_bar)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# el hueco de la barra siempre reservado: si la página mide casi lo mismo que lo que se ve, la barra que aparece y
	# desaparece cambiaba el ancho, el dibujo del banco (que guarda su proporción) cambiaba de alto y la barra volvía a
	# cambiar, sin fin: la cola de mensajes se llenaba y Godot se cerraba (visto en el banco con un resultado, 4q)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.follow_focus = true
	root.add_child(scroll)
	content = Ui.margin(16, 18, 16, 40)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var page := Ui.vbox(16)
	content.add_child(page)
	columns = BoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	page.add_child(columns)
	left_col = Ui.vbox(16)
	right_col = Ui.vbox(16)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)
	columns.add_child(right_col)
	tool_card = ToolCard.new()
	target_card = TargetCard.new()
	params_card = ParamsCard.new()
	for c: Control in [tool_card, target_card, params_card]:
		left_col.add_child(c)
	run_button = RunButton.new()
	result_card = ResultCard.new()
	dual_card = DualCard.new()
	moving_car_card = MovingCarCard.new()
	compare_card = CompareCard.new()
	badges_card = BadgesCard.new()
	for c: Control in [run_button, result_card, dual_card, moving_car_card, compare_card, badges_card]:
		right_col.add_child(c)
	care_page = CarePage.new()
	care_page.visible = false
	page.add_child(care_page)
	model_note = Ui.para(Lab.model_note(lab.model), "Footer")  # el pie de la física elegida (Lab.model_note, 4n)
	page.add_child(model_note)
	# al final: con el hueco de la barra reservado, el desplazamiento avisa de su tamaño nada más entrar en el árbol
	scroll.resized.connect(_layout)


## Cambia de página (la barra de arriba): enseña sus tarjetas, esconde las de la otra y lo recuerda en los ajustes.
func set_page(id: String, remember := true) -> void:
	if not HEADLINES.has(id):
		id = PAGE_BENCH
	var changed := id != page
	page = id
	page_bar.set_value(id)
	var car := id == PAGE_CAR
	var care := id == PAGE_CARE
	var bench := id == PAGE_BENCH
	columns.visible = not care
	left_col.visible = bench
	for c: Control in [run_button, result_card, dual_card, compare_card, badges_card, model_note]:
		c.visible = bench
	moving_car_card.visible = car
	care_page.visible = care
	care_page.set_active(care and is_inside_tree() and can_process())
	if not bench and buzz != null and buzz.playing:
		buzz.stop()
		buzz_id = ""
	_layout()
	if changed:
		scroll.scroll_vertical = 0
		_dirty = true
		headline_changed.emit(headline())
		# al entrar en el coche en marcha con una herramienta sin datos (la uña del arranque), la página salía vacía
		# («Con una uña no hay coche en marcha»): se elige el primer animal con datos, como al pulsar su píldora (4q)
		if car and lab.model == MovingCarState.MODEL and not (lab.claw != null and MovingCar.supports(lab.claw)):
			var first: Dictionary = MovingCarState.supported_animals()[0]
			lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, String(first.id)))
		if remember:
			_save_settings({ "page": id })


## Dos columnas si caben (1.x: 460-560 px la de configuración) y, si no, una de hasta 640 px, centrada. La página del
## coche en marcha es una columna de hasta CAR_MAX.
func _layout() -> void:
	var w := size.x
	_wide = w >= WIDE
	var inner := minf(w - 2.0 * GUTTER, WIDE_MAX if _wide else NARROW_MAX)
	if page == PAGE_CAR:
		inner = minf(w - 2.0 * GUTTER, CAR_MAX)
	elif page == PAGE_CARE:
		inner = minf(w - 2.0 * GUTTER, WIDE_MAX)
		# en escritorio, la cetrería ocupa el alto visible: la vista 3D a la vista y las tarjetas con su desplazamiento
		care_page.set_fit_height(maxf(scroll.size.y - 58.0, 480.0))
	var short := w < PAGE_SHORT_BELOW
	for p: Dictionary in PAGES:
		page_bar.set_label(String(p.id), String(PAGE_SHORT[p.id]) if short else String(p.name))
	var side := int(maxf(GUTTER, floorf((w - inner) / 2.0)))
	content.add_theme_constant_override("margin_left", side)
	content.add_theme_constant_override("margin_right", side)
	bar_margin.add_theme_constant_override("margin_left", side)
	bar_margin.add_theme_constant_override("margin_right", side)
	columns.vertical = not _wide
	if _wide:
		left_col.custom_minimum_size.x = clampf((inner - 16.0) * 0.47, 460.0, 560.0)
		left_col.size_flags_horizontal = Control.SIZE_FILL
	else:
		left_col.custom_minimum_size.x = 0.0
		left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(delta: float) -> void:
	step(delta * 1000.0)


## Avanza la sección ms milisegundos: reloj del banco, dibujos que llegan de los hilos, interfaz y animaciones.
func step(ms: float) -> void:
	clock_ms += ms
	lab.advance(ms)
	art.poll()
	if _dirty:
		_refresh(true)
	elif _heavy_dirty and clock_ms - _last_heavy >= HEAVY_MS:
		_refresh(false)
	if page == PAGE_CAR:
		moving_car_card.step(ms)  # lo caro del coche en marcha que llega de su hilo y su dibujo
		return
	if page == PAGE_CARE:
		care_page.step(ms)  # la cetrería: la escena 3D, el reloj de su hilo y la vista nueva
		return
	if compare_card.poll():
		compare_card.paint()  # filas de la comparativa que llegan de los hilos
	for b in benches:
		b.advance(ms)
	_update_buzz()


## El zumbido que pide el banco principal ({ id, volume, pitch }; sin id o sin volumen, en silencio). El bucle se
## carga una vez por especie y se reproduce por el bus «Lab».
func _update_buzz() -> void:
	var b: Dictionary = result_card.bench.buzz_state()
	var id: String = b.get("id", "")
	var vol: float = b.get("volume", 0.0)
	if id == "" or vol <= 0.0:
		if buzz.playing:
			buzz.stop()
		buzz_id = ""
		return
	if id != buzz_id:
		buzz_id = id
		buzz.stream = sound.stream_of(id)
		buzz.stop()
	buzz.volume_db = linear_to_db(maxf(vol * Sfx.gain(id), 0.0001))  # con el ajuste de la mezcla
	buzz.pitch_scale = float(b.get("pitch", 1.0))
	if not buzz.playing and buzz.stream != null and buzz.is_inside_tree():
		buzz.play()


func _on_lab_changed() -> void:
	_dirty = true


## Pone al día toda la interfaz ahora (tests y demo), con las filas de la comparativa y el coche en marcha ya
## calculados.
func refresh_now() -> void:
	_refresh(false)
	if page == PAGE_CAR:
		moving_car_card.finish()
	elif page == PAGE_CARE:
		care_page.refresh()
	elif compare_card.finish():
		compare_card.paint()


func _refresh(allow_defer: bool) -> void:
	var t0 := Time.get_ticks_usec()
	_dirty = false
	if page == PAGE_CAR:
		# solo la página que se ve: la tarjeta del coche (el banco se pone al día al volver)
		moving_car_card.refresh()
	elif page == PAGE_CARE:
		care_page.refresh()
	else:
		tool_card.refresh()
		target_card.refresh()
		params_card.refresh()
		run_button.set_running(lab.phase == "running")
		result_card.refresh()
		var defer := allow_defer and lab.phase == "idle" and clock_ms - _last_heavy < HEAVY_MS
		dual_card.refresh(defer)
		compare_card.refresh(defer)
		if not defer:
			_last_heavy = clock_ms
		_heavy_dirty = dual_card.rows_stale() or compare_card.rows_stale()
		badges_card.refresh()
		model_note.text = Lab.model_note(lab.model)  # Label no repinta si el texto no cambia
	if _progress_sig() != _saved_progress:
		_save_progress()
	last_refresh_ms = (Time.get_ticks_usec() - t0) / 1000.0


## Lanza el ensayo (el botón ARAÑAR y el atajo). No hace nada mientras se ensaya ni en la página del coche.
func run() -> void:
	if lab.phase == "running" or page != PAGE_BENCH:
		return
	lab.run()
	_refresh(false)


## Se atiende antes que la interfaz (_input), como el keydown de la ventana en la 1.x: así un botón con el foco no
## se come el Intro.
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.is_command_or_control_pressed():
		run()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


# ── Ajustes: el progreso del laboratorio en [lab] ──

## Firma de lo que se guarda: cambia con cada ensayo, cada logro y al reiniciar.
func _progress_sig() -> String:
	return "%d|%s|%s" % [lab.count, ",".join(lab.badges.keys()), lab.notebook.map(func(e: Dictionary) -> int: return e.id)]


## «Probar en el banco» desde la cetrería: la garra de ese animal, con su material y su afilado (el deslizador del banco),
## en la página «Banco de ensayo». Sin física nueva: la del banco con esos tres ajustes.
func _care_to_bench(b: Dictionary) -> void:
	var c: Variant = Catalog.find_by_id(Catalog.CLAWS, String(b.get("claw", "")))
	if c == null:
		return
	lab.set_claw(c)
	var inl: Variant = Catalog.find_by_id(Catalog.INLAYS, String(b.get("inlay", "none")))
	if inl != null:
		lab.set_inlay(inl)
	lab.set_sharpness(float(b.get("sharpness", 0.0)))
	set_page(PAGE_BENCH)


## Recupera los logros, el cuaderno y el número de ensayos guardados, y si vibra (si hay archivo de ajustes).
func _load_settings() -> void:
	if settings_path != "":
		var cfg := ConfigFile.new()
		if cfg.load(settings_path) == OK:
			var saved := {}
			for k: String in ["badges", "notebook", "count"]:
				if cfg.has_section_key(SETTINGS_SECTION, k):
					saved[k] = cfg.get_value(SETTINGS_SECTION, k)
			lab.restore_progress(saved)
			var h: Variant = cfg.get_value(SETTINGS_SECTION, "haptics", true)
			haptics.enabled = h if h is bool else true
			var ci: Variant = cfg.get_value(SETTINGS_SECTION, "care_intro", false)
			_care_intro_seen = ci is bool and bool(ci)
			var fi: Variant = cfg.get_value(SETTINGS_SECTION, "forge_intro", false)
			_forge_intro_seen = fi is bool and bool(fi)
			var pg: Variant = cfg.get_value(SETTINGS_SECTION, "page", PAGE_BENCH)
			page = String(pg) if pg is String and HEADLINES.has(pg) else PAGE_BENCH
	_saved_progress = _progress_sig()


## 5t-B · las opciones de la reacción guardadas en [lab] (reaction_lens_fx, reaction_shake; las dos, sí, si no hay archivo).
func _load_reaction_options() -> Dictionary:
	var out := { "lens_fx": true, "shake": true }
	if settings_path == "":
		return out
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		var fx: Variant = cfg.get_value(SETTINGS_SECTION, "reaction_lens_fx", true)
		var sh: Variant = cfg.get_value(SETTINGS_SECTION, "reaction_shake", true)
		out.lens_fx = fx if fx is bool else true
		out.shake = sh if sh is bool else true
	return out


## Guarda el progreso en [lab].
func _save_progress() -> void:
	_saved_progress = _progress_sig()
	_save_settings(lab.progress())


## Guarda valores en [lab] sin tocar el resto del archivo ([app] y las demás secciones).
func _save_settings(values: Dictionary) -> void:
	if settings_path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	for k: String in values:
		cfg.set_value(SETTINGS_SECTION, k, values[k])
	cfg.save(settings_path)


## Enciende o apaga la vibración (el interruptor de la tarjeta de logros), con un pulso que lo confirma al encenderla.
func set_haptics(on: bool) -> void:
	haptics.enabled = on
	badges_card.show_haptics(haptics.available, on)
	_save_settings({ "haptics": on })
	haptics.play("on")


func _play(id: String, volume: float) -> void:
	haptics.play(id)
	if AudioServer.is_bus_mute(0):
		return
	sound.play(id, volume)


## Desplaza la columna hasta que se vea `c` (la demo lo usa en el teléfono).
func scroll_to(c: Control, margin := 12.0, animate := true) -> void:
	var y := c.get_global_rect().position.y - content.get_global_rect().position.y - margin
	var target_y := clampf(y, 0.0, maxf(0.0, content.size.y - scroll.size.y))
	if not animate or not is_inside_tree():
		scroll.scroll_vertical = int(target_y)
		return
	var tw := create_tween()
	tw.tween_property(scroll, "scroll_vertical", int(target_y), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


# ── Para la barra superior del programa ──

func headline() -> String:
	return String(HEADLINES.get(page, HEADLINES[PAGE_BENCH]))


## Los titulares de todas las páginas: la barra del programa toma su forma con el más largo, así no cambia al pasar de
## página (solo el tamaño del titular).
func headlines() -> Array:
	return HEADLINES.values()


## Los de la 1.x (con «Impacto» para las dos físicas), los de los materiales y la biología de la 2.0 y el de los
## aguijones (Lab.fundamentos, unidad 4n).
func fundamentos() -> Array:
	return Lab.fundamentos()


## La nota sin rutas del proyecto: las fuentes de cada ensayo van debajo del resultado.
func fundamentos_note() -> String:
	return Lab.FUNDAMENTOS_NOTE_V2


## Oculta (main la desactiva), el zumbido se calla: step() no corre y no lo apagaría. La cetrería para su reloj, su
## escena y sus bucles, y los vuelve a poner en marcha al volver si es la página que se ve.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and buzz != null:
		buzz.stop()
		buzz_id = ""
	if care_page != null and (what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED):
		care_page.set_active(what == NOTIFICATION_ENABLED and page == PAGE_CARE and is_inside_tree())


func _exit_tree() -> void:
	if buzz != null:
		buzz.stop()
		buzz_id = ""
	if compare_card != null:
		compare_card.finish()
	if moving_car_card != null:
		moving_car_card.dispose()
	if care_page != null:
		care_page.dispose()
	if lab != null:
		lab.dispose()
	if art != null:
		art.dispose()
