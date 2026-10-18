## Cetrería · la tarjeta «Tu consulta de veterinario» (unidad 5u; petición 62): el nivel y su barra de experiencia, los créditos
## del juego, la lente de la cámara (y lo rayada que está), el encargo en curso con lo que pide, el resultado del último
## (cumplido, con lo que se cobra y lo que restan los errores, o por qué no), la lista de los encargos y la tienda de lentes.
## Solo pinta la vista del progreso que le da la página (paint(view): los textos con números salen de core/lab/vet_progress.gd)
## y manda lo que hace el usuario con post(op, args) a la página, que es la dueña del progreso y lo guarda: no calcula nada.
## Ops: «accept» [id], «abandon», «bring» [id] (traer a la mesa el animal del encargo), «buy» [id], «wear» [id] y «restart»
## (empezar el juego de nuevo).
## La lista de los encargos se pliega (en el teléfono la tarjeta ocupa poco hasta que se abre). La tienda de lentes se abre en
## su hoja superpuesta, en una capa por encima de la página, con su propio botón fuera de esta tarjeta y del panel de las
## herramientas y las garras, junto al de la reforja (peticiones de Eric del 17-10; el botón lo pone la página). Con la lente
## que ya no deja ver, la hoja lo dice arriba, con las salidas: cambiarla o empezar el juego de nuevo (con confirmación).
## Uso: var c := CareProgressCard.new(func(op, args): …); c.paint(view)
extends "res://app/common/card.gd"

const Pill = preload("res://app/common/pill.gd")
const Overlay = preload("res://app/common/overlay.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const CareMeter = preload("res://app/lab/cetreria/care_meter.gd")
const Js = preload("res://core/shared/js.gd")

const TOUCH := 44.0
const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "text" }
## Lo que se dice siempre de los números: son del juego (los créditos, nunca dinero real).
const GAME_NOTE := "La experiencia, los niveles, los créditos y los precios son números del juego; los créditos son honorarios ficticios, nunca dinero real. Lo que piden los encargos es la práctica veterinaria de verdad, con su fuente."

var post: Callable
var compact := false
var level_label: Label
var credits_label: Label
var xp_meter: CareMeter
var xp_label: Label
var lens_label: Label
var lens_note: Label
## Lo peligroso que es para la lente el animal de la mesa (danger, de la física de las garras): en la tarjeta y en la tienda.
var danger_label: Label
var shop_danger: Label
var notice_label: Label
var active_box: PanelContainer
var active_title: Label
var active_text: Label
var active_asks: VBoxContainer
var active_where: Label
var bring_button: Button
var leave_button: Button
## (unidad 5v) La ficha del encargo en curso (con qué llega el animal, el tutorial, por qué) y su minijuego: el objetivo, la barra,
## lo que falta y el aviso; y el aviso de que la garra se ha roto y el encargo pasa a «repararla».
var active_card: Label
var mini_box: VBoxContainer
var mini_title: Label
var mini_meter: CareMeter
var mini_text: Label
var mini_warn: Label
var repair_label: Label
var result_box: PanelContainer
var result_title: Label
var result_items: VBoxContainer
var jobs_toggle: Pill
var jobs_box: VBoxContainer
var shop_box: VBoxContainer
## La hoja de la tienda (en su capa, por encima de la página) y los créditos que se ven dentro.
var shop_layer: CanvasLayer
var shop_overlay: Overlay
var shop_credits: Label
## Arriba de la hoja, la lente que ya no deja ver (VetProgress.blind_view); abajo, empezar el juego de nuevo (dos pulsaciones).
var blind_box: PanelContainer
var blind_label: Label
var restart_button: Button
var restart_warn: Label
## El aviso y el botón de empezar de nuevo van juntos: abajo de la hoja, o dentro del aviso rojo con la lente que no deja ver.
var restart_box: VBoxContainer
var _blind_col: VBoxContainer
var _restart_armed := false
## Los botones de la lista y de la tienda (para la demo y los tests): «encargo:<id>» y «lente:<id>».
var buttons := {}
var _keys := {}


func _init(p_post: Callable = Callable()) -> void:
	super._init("Tu consulta de veterinario")
	name = "TuConsulta"
	post = p_post
	var head := Ui.flow(10, 4)
	level_label = Ui.label("", "CardTitle", "gold")
	head.add_child(level_label)
	credits_label = Ui.label("", "Body", "mint")
	head.add_child(credits_label)
	body.add_child(head)
	xp_meter = CareMeter.new(10.0)
	xp_meter.name = "Experiencia"
	body.add_child(xp_meter)
	xp_label = Ui.para("", "Small", "dim")
	body.add_child(xp_label)
	lens_label = Ui.para("", "Body")
	body.add_child(lens_label)
	lens_note = Ui.para("", "Small", "dim")
	body.add_child(lens_note)
	danger_label = Ui.para("", "Small", "gold")
	body.add_child(danger_label)
	notice_label = Ui.para("", "Small", "gold")
	body.add_child(notice_label)
	# el resultado de la última comprobación
	result_box = PanelContainer.new()
	result_box.theme_type_variation = &"VerdictBox"
	var rc := Ui.vbox(4)
	result_title = Ui.para("", "Body")
	rc.add_child(result_title)
	result_items = Ui.vbox(2)
	rc.add_child(result_items)
	result_box.add_child(rc)
	body.add_child(result_box)
	# el encargo en curso
	active_box = PanelContainer.new()
	active_box.theme_type_variation = &"VerdictBox"
	var ac := Ui.vbox(4)
	active_title = Ui.para("", "Body", "gold")
	active_text = Ui.para("", "Small", "text")
	active_asks = Ui.vbox(2)
	active_where = Ui.para("", "Small", "dim")
	active_card = Ui.para("", "Small", "ice")
	for c: Control in [active_title, active_text, active_card, active_asks, active_where]:
		ac.add_child(c)
	# (5v) el minijuego del encargo en curso
	mini_box = Ui.vbox(2)
	mini_box.name = "Minijuego"
	mini_title = Ui.para("", "Small", "gold")
	mini_meter = CareMeter.new(10.0)
	mini_meter.name = "BarraDelMinijuego"
	mini_text = Ui.para("", "Small", "text")
	mini_warn = Ui.para("", "Small", "coral")
	for c: Control in [mini_title, mini_meter, mini_text, mini_warn]:
		mini_box.add_child(c)
	mini_box.visible = false
	ac.add_child(mini_box)
	repair_label = Ui.para("", "Small", "coral")
	repair_label.visible = false
	ac.add_child(repair_label)
	var arow := Ui.flow()
	bring_button = _button("Traer al animal a la mesa", "PillGold", "Empieza una consulta nueva con el animal y la garra del encargo (la sujeción la eliges tú).")
	bring_button.pressed.connect(func() -> void: _send("bring", [String(get_meta("active", ""))]))
	arow.add_child(bring_button)
	leave_button = _button("Dejar el encargo", "Pill", "Vuelve a la lista sin perder nada.")
	leave_button.pressed.connect(func() -> void: _send("abandon"))
	arow.add_child(leave_button)
	ac.add_child(arow)
	active_box.add_child(ac)
	body.add_child(active_box)
	# la lista de los encargos y la tienda, plegadas
	var trow := Ui.flow()
	jobs_toggle = Pill.new("Encargos")
	jobs_toggle.pressed.connect(func() -> void: set_open("jobs", not jobs_box.visible))
	_a11y(jobs_toggle, "Ver u ocultar los encargos", "La lista de los encargos: disponibles, en curso, hechos y los que piden más nivel.")
	trow.add_child(jobs_toggle)
	body.add_child(trow)
	jobs_box = Ui.vbox(8)
	jobs_box.visible = false
	body.add_child(jobs_box)
	# la tienda, en su hoja: una capa por encima de todo, para que la hoja cubra la página entera y no la columna
	shop_layer = CanvasLayer.new()
	shop_layer.layer = 10
	add_child(shop_layer)
	shop_overlay = Overlay.new("Tienda de lentes de la cámara")
	# la capa no hereda el tema de la página: se lo damos (fuentes, el fondo de la hoja y los botones)
	shop_overlay.theme = AppTheme.get_theme()
	shop_overlay.name = "TiendaDeLentes"
	shop_layer.add_child(shop_overlay)
	blind_box = PanelContainer.new()
	blind_box.theme_type_variation = &"VerdictBox"
	_blind_col = Ui.vbox(8)
	blind_box.add_child(_blind_col)
	blind_label = Ui.para("", "Body", "coral")
	_blind_col.add_child(blind_label)
	blind_box.visible = false
	shop_overlay.content.add_child(blind_box)
	shop_credits = Ui.label("", "Body", "mint")
	shop_overlay.content.add_child(shop_credits)
	shop_danger = Ui.para("", "Small", "gold")
	shop_overlay.content.add_child(shop_danger)
	shop_overlay.content.add_child(Ui.para("Cuatro lentes, de la más blanda a la más dura. Una lente nueva viene sin rayones; reponer la misma cuesta menos.", "Note", "dim"))
	shop_box = Ui.vbox(8)
	shop_box.visible = false
	shop_overlay.content.add_child(shop_box)
	restart_button = _button("Empezar el juego de nuevo", "Pill", "Vuelve al nivel 1, sin experiencia ni créditos ni encargos, con la lente de plástico nueva. Pide confirmación.")
	restart_button.pressed.connect(_on_restart)
	restart_warn = Ui.para("Pierdes el nivel, la experiencia, los créditos, los encargos hechos y las lentes compradas. Pulsa otra vez para confirmarlo.", "Small", "coral")
	restart_warn.visible = false
	restart_box = Ui.vbox(6)
	restart_box.add_child(restart_warn)
	restart_box.add_child(restart_button)
	shop_overlay.content.add_child(restart_box)
	shop_overlay.content.add_child(Ui.para(GAME_NOTE, "Note", "dimmer"))
	shop_overlay.closed.connect(func() -> void:
		shop_box.visible = false
		_arm_restart(false))
	body.add_child(Ui.para(GAME_NOTE, "Note", "dimmer"))


func _a11y(c: Control, a_name: String, description := "") -> void:
	c.accessibility_name = a_name
	if description != "":
		c.accessibility_description = description
		if c is BaseButton or c is Range:
			c.tooltip_text = description


func _button(text: String, variation := "Pill", description := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = StringName(variation)
	b.custom_minimum_size.y = TOUCH if compact else 32.0
	_a11y(b, text, description)
	return b


func _send(op: String, args: Array = []) -> void:
	if post.is_valid():
		post.call(op, args)


## Abre o pliega la lista de los encargos («jobs»), o abre o cierra la hoja de la tienda («shop»).
func set_open(part: String, on: bool) -> void:
	var box := jobs_box if part == "jobs" else shop_box
	box.visible = on
	if part == "jobs":
		jobs_toggle.set_on(on)
	else:
		if on:
			shop_overlay.open()
		elif shop_overlay.visible:
			shop_overlay.close()


## Empezar el juego de nuevo: la primera pulsación pide confirmación; la segunda lo manda («restart»).
func _on_restart() -> void:
	if not _restart_armed:
		_arm_restart(true)
		return
	_arm_restart(false)
	_send("restart")


func _arm_restart(on: bool) -> void:
	_restart_armed = on
	restart_button.text = "Sí, empezar de nuevo" if on else "Empezar el juego de nuevo"
	restart_warn.visible = on
	restart_button.theme_type_variation = &"PillGold" if on else &"Pill"
	restart_button.accessibility_name = restart_button.text


## Pinta la vista del progreso: { level (level_view), credits_text, lens (lens_view), lens_info ({ text, source } de la ficha
## de la lente de la cetrería, o {}), active ({ id, title, text, where, asks [{ text, source }] } o {}), result (last_result),
## notice, jobs (jobs_view), shop (shop_view), lens_infos ({ id: { text, source } }), blind (blind_view) }. Solo rehace lo
## que cambia.
func paint(v: Dictionary) -> void:
	if v.is_empty():
		return
	var lv: Dictionary = v.level
	level_label.text = String(lv.text)
	credits_label.text = String(v.credits_text)
	shop_credits.text = "Tienes " + String(v.credits_text) + "."
	var dg: Dictionary = v.get("danger", {})
	var dtext := ""
	if String(dg.get("text", "")) != "":
		dtext = "Con el animal de la mesa (%s): %s" % [String(v.get("animal_name", "")), String(dg.text).substr(0, 1).to_lower() + String(dg.text).substr(1)]
	for l: Label in [danger_label, shop_danger]:
		l.text = dtext
		l.visible = dtext != ""
		Ui.set_color(l, ["mint", "mint", "gold", "coral", "coral"][clampi(int(dg.get("rank", 0)), 0, 4)])
		l.tooltip_text = ("Fuente: %s" % String(dg.get("source", ""))) if dtext != "" else ""
		l.mouse_filter = Control.MOUSE_FILTER_STOP if dtext != "" else Control.MOUSE_FILTER_IGNORE
	var bv: Dictionary = v.get("blind", {})
	blind_box.visible = bool(bv.get("blind", false))
	blind_label.text = String(bv.get("text", ""))
	var home: Node = _blind_col if blind_box.visible else shop_overlay.content
	if restart_box.get_parent() != home:
		restart_box.reparent(home, false)
		if home == shop_overlay.content:
			home.move_child(restart_box, shop_box.get_index() + 1)
	xp_meter.set_state(float(lv.frac), -1.0, "bien" if bool(lv.max) else "aviso")
	xp_label.text = String(lv.next_text)
	var ln: Dictionary = v.lens
	lens_label.text = "Lente de la cámara: %s · %s" % [String(ln.name), String(ln.text)]
	Ui.set_color(lens_label, String(TONE.get(String(ln.tone), "text")))
	var li: Dictionary = v.get("lens_info", {})
	lens_note.text = String(li.get("short", ""))
	lens_note.visible = lens_note.text != ""
	notice_label.text = String(v.get("notice", ""))
	notice_label.visible = notice_label.text != ""
	_paint_active(v.get("active", {}))
	_paint_result(v.get("result", {}))
	var jk := var_to_str(v.jobs).hash()
	if int(_keys.get("jobs", 0)) != jk:
		_keys["jobs"] = jk
		_paint_jobs(v.jobs)
	var sk := var_to_str([v.shop, v.get("lens_infos", {}), dg.get("lenses", {})]).hash()
	if int(_keys.get("shop", 0)) != sk:
		_keys["shop"] = sk
		_paint_shop(v.shop, v.get("lens_infos", {}), dg.get("lenses", {}))
	var done := 0
	for e: Dictionary in v.jobs:
		if String(e.state) == "hecho":
			done += 1
	jobs_toggle.text = "Encargos (%s de %s hechos)" % [Js.to_fixed(float(done), 0), Js.to_fixed(float((v.jobs as Array).size()), 0)]


func _paint_active(a: Dictionary) -> void:
	active_box.visible = not a.is_empty()
	if a.is_empty():
		return
	var key := var_to_str(a).hash()
	if int(_keys.get("active", 0)) == key:
		return
	_keys["active"] = key
	set_meta("active", String(a.id))
	active_title.text = "Encargo en curso: %s" % String(a.title)
	active_text.text = String(a.text)
	active_card.text = card_line(a)
	active_card.visible = active_card.text != ""
	active_where.text = String(a.get("where", ""))
	_clear(active_asks)
	for it: Dictionary in a.asks:
		var l := Ui.para("○ %s" % String(it.text), "Small", "text")
		if String(it.get("source", "")) != "":
			l.tooltip_text = "Fuente: %s" % String(it.source)
			l.mouse_filter = Control.MOUSE_FILTER_STOP
		active_asks.add_child(l)
	bring_button.visible = String(a.get("kind", "")) == "cetreria"


## (5v) La línea de la ficha: con qué llega el animal, el tutorial que abre, el minijuego y por qué («juego» o su fuente).
static func card_line(e: Dictionary) -> String:
	var parts: Array = []
	if String(e.get("arrives", "")) != "":
		parts.append(String(e.arrives))
	if String(e.get("tutorial_name", "")) != "":
		parts.append("Abre el tutorial «%s»." % String(e.tutorial_name))
	if String(e.get("minigame_name", "")) != "":
		parts.append("Minijuego: %s." % String(e.minigame_name))
	if parts.is_empty():
		return ""
	var why := String(e.get("why", ""))
	if why != "":
		parts.append("Por qué: %s." % why)
	return " ".join(parts)


## (5v) El minijuego del encargo en curso (VetMinigames.view) y el aviso de «repararla», en cada vista de la consulta.
func paint_minigame(m: Dictionary, repair_text: String = "") -> void:
	mini_box.visible = not m.is_empty()
	if not m.is_empty():
		mini_title.text = "%s · %s" % [String(m.title), String(m.goal)]
		mini_meter.set_state(float(m.progress), -1.0, "bien" if bool(m.ok) else "aviso")
		mini_text.text = ("Hecho: %s" % String(m.text)) if bool(m.ok) else String(m.text)
		Ui.set_color(mini_text, "mint" if bool(m.ok) else "text")
		mini_warn.text = String(m.get("warn", ""))
		mini_warn.visible = mini_warn.text != ""
	repair_label.text = repair_text
	repair_label.visible = repair_text != ""


func _paint_result(r: Dictionary) -> void:
	result_box.visible = not r.is_empty() and String(r.get("text", "")) != ""
	if not result_box.visible:
		return
	var key := var_to_str(r).hash()
	if int(_keys.get("result", 0)) == key:
		return
	_keys["result"] = key
	result_title.text = String(r.text)
	Ui.set_color(result_title, String(TONE.get(String(r.get("tone", "")), "text")) if bool(r.get("ok", false)) else ("coral" if not bool(r.get("practice", false)) else "dim"))
	_clear(result_items)
	for it: Dictionary in r.get("items", []):
		var ok := bool(it.ok)
		var t := ("✓ %s" % String(it.text)) if ok else ("✗ %s%s" % [String(it.text), (": " + String(it.why)) if String(it.why) != "" else ""])
		result_items.add_child(Ui.para(t, "Small", "mint" if ok else "coral"))
	for d: Dictionary in r.get("deductions", []):
		result_items.add_child(Ui.para("−%s %%: %s. %s" % [Js.to_fixed(float(d.frac) * 100.0, 0), String(d.text).substr(0, 1).to_upper() + String(d.text).substr(1), String(d.why)], "Small", "gold"))
		result_items.add_child(Ui.para("Fuente: %s" % String(d.source), "Small", "dimmer"))
	var pr: Dictionary = r.get("practice_result", {})
	if String(pr.get("text", "")) != "":
		result_items.add_child(Ui.para(String(pr.text), "Small", "mint" if bool(pr.get("ok", false)) else "dim"))
	if bool(r.get("level_up", false)):
		result_items.add_child(Ui.para("¡Subes de nivel! Mira la tienda: hay una lente nueva a tu alcance.", "Body", "gold"))


func _paint_jobs(jobs: Array) -> void:
	_clear(jobs_box)
	for k: String in buttons.keys():
		if k.begins_with("encargo:"):
			buttons.erase(k)
	for e: Dictionary in jobs:
		var box := PanelContainer.new()
		box.theme_type_variation = &"SectionBox"
		var col := Ui.vbox(3)
		box.add_child(col)
		var st := String(e.state)
		col.add_child(Ui.para("%s · %s" % [String(e.title), String(e.state_text)], "Body", { "hecho": "mint", "en_curso": "gold", "bloqueado": "dim" }.get(st, "text")))
		# lo hecho, lo que está en curso (arriba, con lo que pide) y lo que pide más nivel, en una línea
		if st == "hecho":
			col.add_child(Ui.para(String(e.reward_text), "Small", "dim"))
		elif st == "en_curso":
			col.add_child(Ui.para("En curso: lo que pide está arriba.", "Small", "dim"))
		elif st == "bloqueado":
			col.add_child(Ui.para(String(e.text), "Small", "dim"))
		else:
			col.add_child(Ui.para(String(e.text), "Small", "text"))
			var cl := card_line(e)
			if cl != "":
				col.add_child(Ui.para(cl, "Small", "ice"))
			for it: Dictionary in e.asks:
				var l := Ui.para("· %s" % String(it.text), "Small", "dim")
				if String(it.get("source", "")) != "":
					l.tooltip_text = "Fuente: %s" % String(it.source)
					l.mouse_filter = Control.MOUSE_FILTER_STOP
				col.add_child(l)
			col.add_child(Ui.para("%s · %s" % [String(e.reward_text), String(e.where)], "Small", "dimmer"))
			var b := _button("Aceptar el encargo", "PillGold", "Lo pone en curso: se comprobará con el informe de %s." % ("la reforja" if String(e.kind) == "reforja" else "la consulta, al terminar"))
			var id := String(e.id)
			b.pressed.connect(func() -> void: _send("accept", [id]))
			col.add_child(b)
			buttons["encargo:" + id] = b
		jobs_box.add_child(box)


func _paint_shop(shop: Array, infos: Dictionary, danger: Dictionary = {}) -> void:
	_clear(shop_box)
	for k: String in buttons.keys():
		if k.begins_with("lente:"):
			buttons.erase(k)
	for e: Dictionary in shop:
		var box := PanelContainer.new()
		box.theme_type_variation = &"SectionBox"
		var col := Ui.vbox(3)
		box.add_child(col)
		var id := String(e.id)
		var state := "puesta" if bool(e.on) else ("tuya" if bool(e.owned) else "")
		col.add_child(Ui.para("%s · %s%s" % [String(e.name), String(e.level_text), (" · " + state) if state != "" else ""], "Body", "mint" if bool(e.on) else "text"))
		var info: Dictionary = infos.get(id, {})
		if String(info.get("text", "")) != "":
			col.add_child(Ui.para(String(info.text), "Small", "text"))
			var src := Ui.para("Fuente: %s" % _short(String(info.get("source", ""))), "Small", "dimmer")
			src.tooltip_text = "Fuente: %s" % String(info.get("source", ""))
			src.mouse_filter = Control.MOUSE_FILTER_STOP
			col.add_child(src)
		var dl: Dictionary = danger.get(id, {})
		if not dl.is_empty():
			var hurt := bool(dl.cracked) or int(dl.scratches) > 0
			col.add_child(Ui.para("Un zarpazo del animal de la mesa, con toda su fuerza: %s." % ("se raja" if bool(dl.cracked) else String(dl.text)), "Small", "coral" if hurt else "mint"))
		col.add_child(Ui.para("Precio: %s" % String(e.price_text), "Small", "dim"))
		if bool(e.owned) and float(e.obscuration) > 0.0:
			col.add_child(Ui.para("Rayada: %s %% tapado" % Js.to_fixed(float(e.obscuration) * 100.0, 0), "Small", "gold"))
		if String(e.why) != "":
			col.add_child(Ui.para(String(e.why), "Small", "coral"))
		# la puesta solo se repone si está rayada
		if not bool(e.on) or (String(e.action) == "reponer" and float(e.obscuration) > 0.0):
			var b := _button(String(e.action_text), "PillGold" if bool(e.can) else "Pill", "Comprar una lente nueva quita los rayones (es otra lente); reponer la misma cuesta menos.")
			b.disabled = not bool(e.can)
			var op := "wear" if String(e.action) == "poner" else "buy"
			b.pressed.connect(func() -> void: _send(op, [id]))
			col.add_child(b)
			buttons["lente:" + id] = b
		shop_box.add_child(box)


## Una fuente, hasta su primera explicación (la entera, en la ayuda emergente).
static func _short(src: String) -> String:
	var cut := src.length()
	for sep: String in [": ", " (", "; "]:
		var i := src.find(sep)
		if i > 12:
			cut = mini(cut, i)
	return src.substr(0, cut)


static func _clear(box: Node) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
