## Cetrería · la tarjeta «Colocar la pieza de la reforja» (unidad 5o, petición 43): la pieza que llega sin pegar y cada paso
## que hace el usuario (preparar la garra, el adhesivo, el acrílico o la resina con la lámpara, colocar y sujetar, quitar lo que
## rebosa, limar y probar la unión), con sus números y el «en la vida real tardaría…». Solo pinta la vista de ClawCareState
## (view().bond) y manda órdenes con post(op, args): no calcula nada.
## Uso: var c := CareBondCard.new(func(op, args): runner.post(op, args)); c.paint(v.bond, v.time_scale)
extends "res://app/common/card.gd"

const Pill = preload("res://app/common/pill.gd")
const PillChoice = preload("res://app/lab/cetreria/pill_choice.gd")
const Js = preload("res://core/shared/js.gd")
const Bond = preload("res://core/lab/claw_care_bond.gd")

const TOUCH := 44.0
## Lo que gira la pieza cada toque (grados): elección de la interfaz.
const TURN_DEG := 2.0

var post: Callable
var compact := false
var piece_label: Label
var fiction_label: Label
var stage_label: Label
var real_label: Label
var notice_label: Label
var method_choice: PillChoice
var prep_label: Label
var adh_box: VBoxContainer
var adh_choice: PillChoice
var hold_button: Button
var tilt_label: Label
var acr_box: VBoxContainer
var ratio_choice: PillChoice
var layer_choice: PillChoice
var heat_label: Label
var res_box: VBoxContainer
var lamp_choice: PillChoice
var dist_choice: PillChoice
var time_choice: PillChoice
var lamp_label: Label
var finish_label: Label
var weld_button: Button
var buttons := {}  # id → Button (para la demo y los tests)
var _key := ""
var _method_key := ""


func _init(p_post: Callable = Callable()) -> void:
	super._init("Colocar la pieza de la reforja")
	name = "ColocarLaPieza"
	post = p_post
	piece_label = Ui.para("", "Body")
	body.add_child(piece_label)
	fiction_label = Ui.para("", "Note", "gold")
	body.add_child(fiction_label)
	stage_label = Ui.para("", "Body", "mint")
	body.add_child(stage_label)
	real_label = Ui.para("", "Note", "dim")
	body.add_child(real_label)
	method_choice = PillChoice.new([], "", "Método")
	body.add_child(method_choice)
	# preparar la garra
	body.add_child(Ui.sub_label("Preparar la garra"))
	var prep := Ui.flow()
	_btn(prep, "alcohol", "Limpiar con alcohol", func() -> void: _send("bond_clean", ["alcohol"]), "Limpia y desengrasa donde va a pegar; se evapora en unos segundos (también: el alcohol de la batea y un clic en la garra).")
	_btn(prep, "clorhexidina", "Con clorhexidina", func() -> void: _send("bond_clean", ["clorhexidina"]), "Limpia y desinfecta; es agua: hay que secarla con la gasa.")
	_btn(prep, "gasa", "Coger la gasa", func() -> void: _send("pick", ["presion"]), "Aprieta la gasa sobre la garra unos segundos para secarla.")
	_btn(prep, "lija", "Coger la lija P240", func() -> void: _send("pick", ["lija_p240"]), "Una pasada suave donde va a pegar, de la base a la punta.")
	body.add_child(prep)
	prep_label = Ui.para("", "Note", "dim")
	body.add_child(prep_label)
	# el adhesivo
	adh_box = Ui.vbox(6)
	adh_box.add_child(Ui.sub_label("Adhesivo"))
	adh_choice = PillChoice.new([], "", "Adhesivo")
	adh_choice.selected.connect(func(id: String) -> void: _send("bond_adhesive", [id]))
	adh_box.add_child(adh_choice)
	var arow := Ui.flow()
	_btn(arow, "purgar", "Purgar la cánula", func() -> void: _send("bond_purge"), "Las jeringas dobles: lo primero que sale va mal mezclado y se tira.")
	_btn(arow, "aplicar", "Poner el adhesivo", func() -> void: _send("bond_apply"), "Un cordón sobre la pieza; empieza su tiempo de trabajo.")
	_btn(arow, "coger", "Coger la pieza", func() -> void: _send("bond_grab", [true]), "La pieza a la mano: llévala al muñón con el ratón (o el dedo) y gírala con A/D.")
	_btn(arow, "izq", "◀ Girar", func() -> void: _send("bond_turn", [-TURN_DEG]), "Gira la pieza en la mano (tecla A).")
	_btn(arow, "der", "Girar ▶", func() -> void: _send("bond_turn", [TURN_DEG]), "Gira la pieza en la mano (tecla D).")
	adh_box.add_child(arow)
	var hrow := Ui.flow()
	hold_button = Button.new()
	hold_button.text = "Apretar y sujetar (K)"
	hold_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hold_button.theme_type_variation = &"RunButton"
	hold_button.custom_minimum_size.y = TOUCH
	hold_button.button_down.connect(func() -> void: _send("bond_hold", [true, -1.0]))
	hold_button.button_up.connect(func() -> void: _send("bond_hold", [false]))
	hold_button.accessibility_name = "Apretar la pieza sobre el muñón y sujetarla"
	hold_button.tooltip_text = "Mientras lo mantienes pulsado, la sujetas quieta; al soltarlo, la sueltas. También la tecla K o el botón del ratón sobre la garra."
	hrow.add_child(hold_button)
	buttons["sujetar"] = hold_button
	_btn(hrow, "vendar", "Vendar", func() -> void: _send("bond_wrap"), "Una venda autoadherente la sujeta mientras fija una cola lenta.")
	_btn(hrow, "quitar_venda", "Quitar la venda", func() -> void: _send("bond_unwrap"), "Cuando ya ha fijado.")
	adh_box.add_child(hrow)
	tilt_label = Ui.para("", "Note", "dim")
	adh_box.add_child(tilt_label)
	body.add_child(adh_box)
	# el acrílico dental
	acr_box = Ui.vbox(6)
	acr_box.add_child(Ui.sub_label("Acrílico dental (polvo y líquido)"))
	ratio_choice = PillChoice.new([], "2", "Proporción polvo:líquido en peso")
	acr_box.add_child(ratio_choice)
	var crow := Ui.flow()
	_btn(crow, "mezclar", "Mezclar en el vaso", func() -> void: _send("bond_mix", [float(ratio_choice.value)]), "Polvo y líquido en la proporción elegida, unos 30 s.")
	acr_box.add_child(crow)
	body.add_child(acr_box)
	# la resina con la lámpara
	res_box = Ui.vbox(6)
	res_box.add_child(Ui.sub_label("Resina y lámpara"))
	lamp_choice = PillChoice.new([], "azul", "Lámpara")
	res_box.add_child(lamp_choice)
	dist_choice = PillChoice.new([], "1", "Distancia de la lámpara")
	res_box.add_child(dist_choice)
	time_choice = PillChoice.new([], "20", "Tiempo de luz")
	res_box.add_child(time_choice)
	for c: PillChoice in [lamp_choice, dist_choice, time_choice]:
		c.selected.connect(func(_id: String) -> void: _send("bond_lamp", [lamp_choice.value, float(dist_choice.value), float(time_choice.value)]))
	var rrow := Ui.flow()
	_btn(rrow, "ojos", "Tapar los ojos y el filtro", func() -> void: _send("bond_eyes", [true]), "La capucha o un paño sobre los ojos del animal y el filtro naranja delante: la luz azul intensa daña la retina.")
	_btn(rrow, "lampara", "Encender la lámpara (L)", func() -> void: _send("bond_lamp_on"), "Se apaga sola al acabar su intervalo; pita cada 10 s.")
	res_box.add_child(rrow)
	lamp_label = Ui.para("", "Note", "dim")
	res_box.add_child(lamp_label)
	body.add_child(res_box)
	# las capas (el acrílico y la resina, con la espátula)
	layer_choice = PillChoice.new([{ "id": "fina", "label": "Capa fina (1 mm)" }, { "id": "gruesa", "label": "Capa gruesa (3 mm)" }], "fina", "Alto de la capa")
	layer_choice.selected.connect(func(id: String) -> void: _send("set_layer_kind", [id]))
	body.add_child(layer_choice)
	var lrow := Ui.flow()
	_btn(lrow, "capa", "Aplicar la capa (espátula)", func() -> void: _send("bond_layer"), "Del vaso (el acrílico en masa) o de la jeringa (la resina), sobre el muñón o la capa de antes. También: la espátula de la batea y un clic en la garra.")
	body.add_child(lrow)
	heat_label = Ui.para("", "Note", "dim")
	body.add_child(heat_label)
	# acabar y probar
	body.add_child(Ui.sub_label("Acabar a mano y probar"))
	var frow := Ui.flow()
	_btn(frow, "espatula", "Quitar lo que rebosa (espátula)", func() -> void: _send("bond_scrape"), "En fresco; ya duro, con la lima sobre la unión.")
	_btn(frow, "lima", "Coger la lima gruesa (1)", func() -> void: _send("pick", ["lima_bastarda"]), "Lo que rebosa ya duro, el escalón, la forma y la punta.")
	_btn(frow, "probar", "Probar la unión", func() -> void: _send("bond_test"), "Un tirón suave de lado con la mitad del agarre de la garra.")
	_btn(frow, "quitar", "Quitar y empezar de nuevo", func() -> void: _send("bond_remove"), "La pieza vuelve a la bandeja; hay que limpiar y preparar otra vez.")
	weld_button = _btn(frow, "soldar", "¿Soldar con TIG?", func() -> void: _send("bond_weld"), "Por qué no se suelda una garra de metal sobre la garra: con sus números.")
	body.add_child(frow)
	finish_label = Ui.para("", "Note", "dim")
	body.add_child(finish_label)
	notice_label = Ui.para("", "Note", "gold")
	body.add_child(notice_label)
	visible = false


func _btn(parent: Control, id: String, text: String, cb: Callable, help: String) -> Button:
	var b := Pill.new(text, "Pill", false)
	b.custom_minimum_size.y = TOUCH if compact else 32.0
	b.pressed.connect(cb)
	b.accessibility_name = text
	b.tooltip_text = help
	parent.add_child(b)
	buttons[id] = b
	return b


func _send(op: String, args: Array = []) -> void:
	if post.is_valid():
		post.call(op, args)


static func _n(x: float, d: int = 1) -> String:
	return Js.to_fixed(x, d)


## Las opciones que dependen de la pieza (los métodos y los adhesivos con su holgura), al cambiar de pieza.
func _options(bv: Dictionary) -> void:
	var mk := "%s|%s|%s" % [String(bv.kind), String(bv.material), var_to_str(bv.gapMm)]
	if mk == _method_key:
		return
	_method_key = mk
	for c: Node in [method_choice, adh_choice, ratio_choice, lamp_choice, dist_choice, time_choice]:
		c.queue_free()
	var idx_m := method_choice.get_index()
	method_choice = PillChoice.new((bv.methods as Array).map(func(m: Dictionary) -> Dictionary: return { "id": m.id, "label": m.name }), String(bv.method), "Método")
	method_choice.selected.connect(func(id: String) -> void: _send("bond_method", [id]))
	body.add_child(method_choice)
	body.move_child(method_choice, idx_m)
	adh_choice = PillChoice.new((bv.adhesives as Array).map(func(a: Dictionary) -> Dictionary: return { "id": a.id,
		"label": String(a.name).split(" (")[0] + ("" if bool(a.fills) else " · no llena"),
		"title": "%s MPa de cortante · llena hasta %s mm · fija en %s · %s. %s" % [_n(float(a.tauMPa)), _n(float(a.gapMaxMm), 2), String(a.fixText), String(a.mix), String(a.source)] }), String(bv.adhesive), "Adhesivo")
	adh_choice.selected.connect(func(id: String) -> void: _send("bond_adhesive", [id]))
	adh_box.add_child(adh_choice)
	adh_box.move_child(adh_choice, 1)
	ratio_choice = PillChoice.new((bv.ratios as Array).map(func(r: float) -> Dictionary: return { "id": Js.js_num_str(r), "label": "%s:1%s" % [_n(r), " (la de la ficha)" if r == float(bv.ratio) else ""] }), Js.js_num_str(float(bv.ratio)), "Proporción polvo:líquido en peso")
	acr_box.add_child(ratio_choice)
	acr_box.move_child(ratio_choice, 1)
	lamp_choice = PillChoice.new([{ "id": "azul", "label": "Azul de dentista (430-480 nm)" }, { "id": "uv", "label": "UV de uñas (365-405 nm)" }], String(bv.lamp), "Lámpara")
	dist_choice = PillChoice.new((bv.distances as Array).map(func(d: float) -> Dictionary: return { "id": Js.js_num_str(d), "label": "a %s mm" % _n(d, 0) }), Js.js_num_str(float(bv.lampMm)), "Distancia de la lámpara")
	time_choice = PillChoice.new((bv.times as Array).map(func(t: float) -> Dictionary: return { "id": Js.js_num_str(t), "label": "%s s" % _n(t, 0) }), Js.js_num_str(float(bv.lampS)), "Tiempo de luz")
	var at := 1
	for c: PillChoice in [lamp_choice, dist_choice, time_choice]:
		c.selected.connect(func(_id: String) -> void: _send("bond_lamp", [lamp_choice.value, float(dist_choice.value), float(time_choice.value)]))
		res_box.add_child(c)
		res_box.move_child(c, at)
		at += 1


## Pinta la vista de la colocación (ClawCareState.bond_view); {} la esconde.
func paint(bv: Dictionary, time_scale: float = 1.0) -> void:
	visible = not bv.is_empty()
	if bv.is_empty():
		return
	var key := "%s|%s|%s|%s|%s|%s|%s" % [int(bv.serial), String(bv.stage_text), String(bv.notice), Js.to_fixed(float(bv.holdS), 0),
		Js.to_fixed(float(bv.quickC), 1), Js.to_fixed(float(bv.lampLeftS), 0), Js.to_fixed(time_scale, 0)]
	if key == _key:
		return
	_key = key
	_options(bv)
	var m := String(bv.method)
	piece_label.text = "%s (%s) · %s mm² pegados%s.%s" % [String(bv.name), String(bv.get("label", bv.kind)),
		_n(float(bv.areaMm2)), (" · holgura de %s mm" % _n(float(bv.gapMm), 2)) if m == "adhesivo" else (" · hay que construir %s mm" % _n(float(bv.needMm))),
		(" " + String(bv.lab_text)) if String(bv.get("lab_text", "")) != "" else ""]
	fiction_label.text = String(bv.note)
	fiction_label.visible = String(bv.note) != ""
	stage_label.text = String(bv.stage_text)
	real_label.text = String(bv.real_time)
	real_label.visible = String(bv.real_time) != ""
	method_choice.set_value(m)
	method_choice.visible = (bv.methods as Array).size() > 1
	prep_label.text = "Limpia: %s · Seca: %s · Lijada: %s (Ra %s µm)" % ["sí, con " + String(bv.cleaner) if String(bv.cleaner) != "" else "no",
		"no" if bool(bv.wet) or String(bv.cleaner) == "" else "sí", "sí" if bool(bv.sanded) else "no", _n(float(bv.raUm), 2)]
	adh_box.visible = m == "adhesivo"
	acr_box.visible = m == "acrilico"
	res_box.visible = m == "resina"
	layer_choice.visible = m != "adhesivo"
	(buttons.capa as Button).visible = m != "adhesivo"
	heat_label.visible = m != "adhesivo"
	adh_choice.set_value(String(bv.adhesive))
	layer_choice.set_value(String(bv.layerKind))
	(buttons.purgar as Button).visible = bool(bv.twoPart)
	(buttons.vendar as Button).visible = bool(bv.placed) and not bool(bv.fixed) and not bool(bv.wrapped)
	(buttons.quitar_venda as Button).visible = bool(bv.wrapped)
	weld_button.visible = String(bv.material) in ["acero", "oro", "titanio", "tungsteno"]
	if m == "adhesivo":
		var t := "En la mano, inclinada %s° del eje (se toleran %s°)." % [_n(absf(float(bv.tiltDeg)), 0), _n(float(bv.tolTiltDeg), 0)] if bool(bv.held) else ""
		if bool(bv.placed) and not bool(bv.fixed):
			t = "Sujeta %s de %s%s." % [_dur(float(bv.holdS)), _dur(float(bv.fixS)), " · vendada" if bool(bv.wrapped) else ""]
		elif bool(bv.applied) and not bool(bv.placed):
			t = "Tiempo de trabajo: quedan %s. %s" % [_dur(float(bv.workLeftS)), t]
		tilt_label.text = t
		tilt_label.visible = t != ""
	elif m == "acrilico":
		heat_label.text = "Vaso: %s · %s capas, %s de %s mm · carne viva a %s °C (pico %s; duele desde %s)." % [
			{"": "vacío", "liquida": "líquida", "masa": "en masa", "dura": "ya no se modela", "fraguada": "fraguada"}.get(String(bv.mixPhase), ""),
			int(bv.layers), _n(float(bv.builtMm)), _n(float(bv.needMm)), _n(float(bv.quickC)), _n(float(bv.peakQuickC)), _n(float(bv.painC), 0)]
	else:
		var last := "sin capas"
		if not (bv.resin as Array).is_empty():
			var l: Dictionary = (bv.resin as Array).back()
			last = "la última, de %s mm, curada %s mm" % [_n(float(l.h)), _n(float(l.cdMm))]
		heat_label.text = "%s capas, %s de %s mm · %s." % [(bv.resin as Array).size(), _n(float(bv.builtMm)), _n(float(bv.needMm)), last]
		lamp_label.text = "%s a %s mm: %s mW/cm²; en %s s cura %s mm%s%s." % [String(bv.lampName), _n(float(bv.lampMm), 0), _n(float(bv.irradiance), 0), _n(float(bv.lampS), 0),
			_n(float(bv.cureDepthMm)), " · encendida: %s" % _dur(float(bv.lampLeftS)) if bool(bv.lampOn) else "", "" if bool(bv.eyes) else " · ojos sin tapar"]
		lamp_choice.set_value(String(bv.lamp))
	var fin := "Lo que rebosa: %s mm³%s · escalón: %s mm (se nota de %s) · curado %s %% · aguanta %s N; la prueba tira con %s N." % [
		_n(float(bv.flashMm3), 2), " (fresco)" if bool(bv.fresh) and float(bv.flashMm3) > 0.0 else "", _n(float(bv.stepMm), 2), _n(float(bv.stepOkMm), 1),
		_n(float(bv.curePct), 0), _n(float(bv.capN), 0), _n(float(bv.testN), 0)]
	if not (bv.test as Dictionary).is_empty():
		fin += " " + String(bv.test.text)
	finish_label.text = fin
	notice_label.text = String(bv.notice)
	notice_label.visible = String(bv.notice) != ""


static func _dur(s: float) -> String:
	return Bond.dur(s)
