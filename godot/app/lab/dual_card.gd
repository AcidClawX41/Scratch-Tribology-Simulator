## Tarjeta · Modo dual (DualCard de la 1.x): el mismo ensayo en dos coches (por defecto, el clásico frente al
## moderno). Los dos bancos se animan con el ARAÑAR principal; debajo, qué raya, desgarra, punza o golpea la
## herramienta en cada uno, cuánto y qué daño deja. Todo se calcula en core (lab.duel(), duel_verdict,
## damage_report): aquí solo se pinta. Con poco ancho (teléfono), los coches y las filas de la tabla se apilan.
extends "res://app/common/card.gd"

const Lab = preload("res://core/lab/lab.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Palette = preload("res://app/theme/palette.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const Pill = preload("res://app/common/pill.gd")
const Bench = preload("res://app/lab/bench.gd")

const TITLE := "Modo dual · coche antiguo vs moderno"
## Ancho a partir del cual los dos coches van en paralelo (dos columnas de 250 px, como el auto-fit de la 1.x).
const TWO_COLS := 514.0
## Ancho a partir del cual la tabla va en columnas.
const TABLE_ROW := 540.0

var lab: LabState
var toggle: Pill
var intro: Label
var on_box: VBoxContainer
var cars_box: Container
var car_pills: Array = [{}, {}]  # por coche: id → Pill
var benches: Array[Bench] = []
var car_result: Array[VBoxContainer] = []
var car_verdict: Array[Label] = []
var car_vsub: Array[Label] = []
var car_damage: Array[GridContainer] = []
var hint: Label
var table_head: Container
var head_names: Array[Label] = []
var head_name: Label
var head_who: Label
var rows: Array = []  # [{ panel, name, cells: [[verdict, depth]], who }]
var footnote: Label
## Filas calculadas (lab.duel(): Lab.duel con el modelo del banco) y la del ensayo del banco; se recalculan solo si
## cambian sus entradas.
var duel_rows: Array = []
var current_row: Dictionary = {}
var _sig := ""
var _narrow := false
var _claws := false


func _init() -> void:
	super(TITLE)
	toggle = Pill.new("Activar")
	toggle.accessibility_name = "Activar el modo dual"
	right.add_child(toggle)
	intro = Ui.para(("El mismo ensayo en dos coches a la vez: un clásico de acero dulce más grueso frente a uno moderno de acero fino "
		+ "(o de aluminio, o con aletas de plástico). Qué raya, desgarra, punza o atraviesa cada uno, cuántos milímetros y qué daño deja."),
		"Body")
	body.add_child(intro)
	on_box = Ui.vbox(10)
	var cols := WrapBox.new(14.0, 16.0)
	cols.equal = true
	cols.align_top = true
	cols.row_min = TWO_COLS
	cars_box = cols
	for i in 2:
		var col := Ui.vbox(8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(Ui.sub_label("Coche A" if i == 0 else "Coche B"))
		var chips := Ui.flow()
		for t: Dictionary in Lab.DUEL_CARS:
			var p := Pill.new(String(t.name))
			p.tooltip_text = String(t.fact)
			chips.add_child(p)
			car_pills[i][t.id] = p
		col.add_child(chips)
		var box := PanelContainer.new()
		box.theme_type_variation = &"BenchBox"
		var b := Bench.new()
		box.add_child(b)
		benches.append(b)
		col.add_child(box)
		var res_box := Ui.vbox(4)
		res_box.accessibility_live = AccessibilityServer.LIVE_POLITE
		var v := Ui.para("", "VerdictSmall")
		res_box.add_child(v)
		car_verdict.append(v)
		var sub := Ui.para("", "Body")
		sub.add_theme_font_size_override("font_size", 12)
		res_box.add_child(sub)
		car_vsub.append(sub)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 3)
		res_box.add_child(grid)
		car_damage.append(grid)
		col.add_child(res_box)
		car_result.append(res_box)
		cols.add_child(col)
	on_box.add_child(cols)
	hint = Ui.para("", "Body", "dimmer")
	on_box.add_child(hint)
	on_box.add_child(Ui.sub_label("Qué hace esta herramienta en cada coche"))
	table_head = _table_row(true)
	on_box.add_child(table_head)
	for i in Lab.DUEL_MODES.size():
		var r := _table_row(false)
		on_box.add_child(r)
	footnote = Ui.para("misma herramienta, fuerza y largo · ◂ = el ensayo del banco · negrita = el que aguanta mejor", "Small")
	on_box.add_child(footnote)
	body.add_child(on_box)
	resized.connect(_on_resized)


## Una fila de la tabla (o la cabecera): modo · coche A · coche B · quién aguanta.
func _table_row(head: bool) -> Container:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Row"
	var col := Ui.vbox(0)
	var line := ColorRect.new()
	line.color = Palette.color("line") if not head else Color.TRANSPARENT
	line.custom_minimum_size.y = 1.0
	col.add_child(line)
	var pad := Ui.margin(8, 7, 8, 7)
	var wrap := WrapBox.new(10.0, 4.0)
	wrap.row_min = TABLE_ROW
	wrap.align_top = true
	var name := Ui.para("", "RowName")
	name.add_theme_font_size_override("font_size", 13)
	name.size_flags_stretch_ratio = 0.9
	wrap.add_child(name)
	var cells := Ui.hbox(8)
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.size_flags_stretch_ratio = 2.6
	var cell_labels: Array = []
	for i in 2:
		var c := Ui.vbox(2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Ui.para("", "Cell", "dimmer" if head else "")
		c.add_child(v)
		var d: Label = null
		if not head:
			d = Ui.para("", "Small")
			c.add_child(d)
		cells.add_child(c)
		cell_labels.append([v, d])
	wrap.add_child(cells)
	var who := Ui.para("¿Quién aguanta?" if head else "", "Cell", "dimmer" if head else "")
	who.size_flags_stretch_ratio = 1.2
	wrap.add_child(who)
	pad.add_child(wrap)
	col.add_child(pad)
	panel.add_child(col)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if head:
		head_names = [cell_labels[0][0], cell_labels[1][0]]
		head_name = name
		head_who = who
	else:
		rows.append({ "panel": panel, "name": name, "cells": cell_labels, "who": who })
	return panel


func setup(p_lab: LabState, art: ArtCache) -> void:
	lab = p_lab
	toggle.pressed.connect(func() -> void: lab.set_dual(not lab.dual))
	for i in 2:
		benches[i].setup(art, "AB"[i])
		for id: String in car_pills[i]:
			(car_pills[i][id] as Button).pressed.connect(_on_car.bind(i, id))


func _on_car(slot: int, id: String) -> void:
	if lab.dual_pair[slot] == id:
		refresh()
		return
	lab.set_dual_car(slot, id)


func _on_resized() -> void:
	var narrow := size.x < TABLE_ROW + 40.0
	if narrow != _narrow:
		_narrow = narrow
		_head_layout()


## En columnas, la cabecera nombra los coches encima de sus celdas; apilada, solo quedan los nombres.
func _head_layout() -> void:
	head_name.visible = not _narrow
	head_who.visible = not _narrow


## Firma de lo que decide las filas del duelo (herramienta, fuerza, largo, pasadas, tipo, humedad, coches y modelo).
func signature() -> String:
	var claw: Variant = lab.claw
	# 2.0: el ángulo de ataque pedido cambia el duelo (flexa la uña y decide el modo de abrasión); la zona, no (coches); el
	# afilado de una garra reforjada, también (su punta)
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [claw.id if claw != null else "-", lab.geom.id, lab.base.id, lab.inlay.id,
		lab.force, lab.length, lab.passes, lab.type.id, lab.wet, lab.method, lab.strike, lab.tear_mode, lab.model, lab.attack_deg,
		lab.sharpness] + "|" + ",".join(lab.dual_pair)


## Recalcula las filas del duelo si han cambiado sus entradas (lo llama la sección; puede aplazarlo).
func update_rows() -> void:
	var sig := signature()
	if sig == _sig:
		return
	_sig = sig
	_claws = lab.claw != null
	duel_rows = lab.duel()
	current_row = {}
	for r: Dictionary in duel_rows:
		if _is_current(r):
			current_row = r
			break
	if current_row.is_empty() and not duel_rows.is_empty():
		current_row = duel_rows[0]


func _is_current(r: Dictionary) -> bool:
	var p: Dictionary = r.p
	var puncture := lab.method == "puncion"
	return (p.method == lab.method and p.strike == (puncture and lab.strike)
		and p.tear == (lab.method == "rayado" and lab.claw != null and lab.tear_mode))


## ¿Están las filas al día? (la sección las recalcula en diferido mientras se arrastra un deslizador)
func rows_stale() -> bool:
	return lab.dual and signature() != _sig


## defer_rows: no recalcular ahora las filas del duelo (mientras se arrastra un deslizador; la sección lo hace luego).
func refresh(defer_rows := false) -> void:
	toggle.text = "Desactivar" if lab.dual else "Activar"
	toggle.set_on(lab.dual)
	toggle.accessibility_name = "Desactivar el modo dual" if lab.dual else "Activar el modo dual"
	intro.visible = not lab.dual
	on_box.visible = lab.dual
	if not lab.dual:
		return
	if rows_stale() and (not defer_rows or lab.phase != "idle" or duel_rows.is_empty() or _claws != (lab.claw != null)):
		update_rows()
	var cars: Array = lab.dual_cars()
	var done := lab.phase == "done"
	for i in 2:
		var car: Dictionary = cars[i]
		for id: String in car_pills[i]:
			(car_pills[i][id] as Pill).set_on(id == car.id)
		var res: Variant = null if lab.phase == "idle" or current_row.is_empty() else current_row.res[i]
		benches[i].set_state({
			"target": car, "res": res, "phase": lab.phase, "length": lab.length, "method": lab.method, "run": lab.run_seq,
			"tool": { "claw": lab.claw, "geom": lab.geom, "base": lab.base, "inlay": lab.inlay, "wet": lab.wet },
		})
		car_result[i].visible = done and res != null
		if done and res != null:
			car_verdict[i].text = String(res.verdict)
			Ui.set_color(car_verdict[i], Palette.color(res.vcol))
			car_vsub[i].text = String(res.vsub)
			_fill_damage(car_damage[i], Lab.damage_report(res, car, lab.length))
	hint.visible = not done
	hint.text = "Ensayando en los dos coches…" if lab.phase == "running" else "Pulsa ARAÑAR: el ensayo corre a la vez en los dos coches."
	head_names[0].text = String(cars[0].name)
	head_names[1].text = String(cars[1].name)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var panel: PanelContainer = row.panel
		panel.visible = i < duel_rows.size()
		if not panel.visible:
			continue
		var d: Dictionary = duel_rows[i]
		var is_cur: bool = d == current_row
		panel.theme_type_variation = &"RowOn" if is_cur else &"Row"
		(row.name as Label).text = String(d.name) + (" ◂" if is_cur else "")
		var v := Lab.duel_verdict(d.res[0], d.res[1], cars)
		for k in 2:
			var r: Dictionary = d.res[k]
			var vl: Label = row.cells[k][0]
			var dl: Label = row.cells[k][1]
			vl.text = String(r.verdict)
			Ui.set_color(vl, Palette.color(r.vcol))
			vl.add_theme_font_override("font", AppTheme.MONO_BOLD if v.winner == k else AppTheme.MONO)
			var depth := Format.fmt_len(r.depthUm) if r.depthUm > 0.0 else "—"
			if Js.truthy(r.get("through")):
				depth += " · Ø " + Format.fmt_len(r.grooveWidthUm)
			dl.text = depth
		var who: Label = row.who
		who.text = String(v.text)
		Ui.set_color(who, "dim" if v.winner == null else "mint")


func _fill_damage(grid: GridContainer, report: Array) -> void:
	while grid.get_child_count() < report.size() * 2:
		var l := Ui.label("", "Cell")
		l.add_theme_font_size_override("font_size", 12)
		grid.add_child(l)
	for i in grid.get_child_count():
		var l: Label = grid.get_child(i)
		var row := i / 2
		l.visible = row < report.size()
		if not l.visible:
			continue
		var is_key := i % 2 == 0
		l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		l.text = String(report[row][0 if is_key else 1])
		Ui.set_color(l, "dimmer" if is_key else "text")
		if not is_key:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.x = 60.0
