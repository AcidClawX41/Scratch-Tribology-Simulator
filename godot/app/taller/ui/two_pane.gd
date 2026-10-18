## Taller industrial · reparto de una página: en escritorio, dos columnas (la vista a la izquierda, las tarjetas a la
## derecha con su propio desplazamiento); en pantallas estrechas (teléfono), una sola columna desplazable con la
## vista arriba. Los dos contenedores, visual y side, son siempre los mismos: al cambiar de modo solo se mueven.
extends Control

const SIDE_W := 452.0
const PAD := 12

var visual := VBoxContainer.new()
var side := VBoxContainer.new()
var compact := false

var _wide := HBoxContainer.new()
var _side_scroll := ScrollContainer.new()
var _narrow := ScrollContainer.new()
var _narrow_col := VBoxContainer.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	_wide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wide.add_theme_constant_override("separation", PAD)
	add_child(_wide)
	_wide.add_child(visual)
	_side_scroll.custom_minimum_size.x = SIDE_W
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_scroll.follow_focus = true
	_wide.add_child(_side_scroll)
	_side_scroll.add_child(side)
	_narrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narrow.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_narrow.visible = false
	add_child(_narrow)
	_narrow_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrow_col.add_theme_constant_override("separation", 10)
	_narrow.add_child(_narrow_col)


## Una columna (true) o dos (false).
func set_compact(on: bool) -> void:
	if on == compact:
		return
	compact = on
	visual.get_parent().remove_child(visual)
	side.get_parent().remove_child(side)
	if on:
		_narrow_col.add_child(visual)
		_narrow_col.add_child(side)
		visual.size_flags_vertical = Control.SIZE_FILL
	else:
		_wide.add_child(visual)
		_wide.move_child(visual, 0)
		_side_scroll.add_child(side)
		visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wide.visible = not on
	_narrow.visible = on


## Desplaza la columna que toque hasta que se vea el control (el informe al terminar, un aviso…). En escritorio, lo
## que está en la parte visual no va dentro de la columna con desplazamiento: ya se ve y no hay nada que desplazar.
func reveal(control: Control) -> void:
	var sc := _narrow if compact else _side_scroll
	if sc.is_inside_tree() and control.is_inside_tree() and sc.is_ancestor_of(control):
		sc.ensure_control_visible(control)


## La barra de desplazamiento de las tarjetas (o de toda la página en teléfono).
func scroller() -> ScrollContainer:
	return _narrow if compact else _side_scroll
