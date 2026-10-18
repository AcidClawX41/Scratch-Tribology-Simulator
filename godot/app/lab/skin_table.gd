## Tabla de las capas de la piel (SkinTable de sections.jsx): espesor, rigidez E y tenacidad J de cada capa, con la
## capa alcanzada resaltada. Con la física 2.0, las capas de la zona del cuerpo del ensayo y el hueso de debajo
## (core/lab/zones.gd → section_layers: su profundidad, su módulo y su dureza Vickers); con la 1.x, las del brazo de
## siempre (core/lab/catalog.gd → SKIN_LAYERS), sin hueso. La nota de cada capa va en la ayuda emergente de su fila.
extends VBoxContainer

const Catalog = preload("res://core/lab/catalog.gd")
const Zones = preload("res://core/lab/zones.gd")
const Js = preload("res://core/shared/js.gd")
const Palette = preload("res://app/theme/palette.gd")
const Ui = preload("res://app/common/ui.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")

const RATIOS := [1.7, 1.35, 0.9, 1.0]
## La zona de las filas que se ven antes de la primera: ninguna.
const NO_ZONE := "-"
## Letra de las celdas (y lo más que baja si las columnas no caben), lo que ocupa el cuadro de color de la primera (9 px
## más la separación) y lo fijo de cada fila: sus márgenes (6 + 6) y las tres separaciones entre columnas (8 px).
const CELL_FS := 11
const CELL_FS_MIN := 10
const SWATCH_W := 15.0
## Márgenes laterales de cada fila y separación entre columnas: los de siempre y, si ni con la letra más pequeña caben
## las columnas (un teléfono), los apretados.
const ROW_PAD := 6
const COL_SEP := 8
const ROW_PAD_TIGHT := 3
const COL_SEP_TIGHT := 5

## El espacio entre un número y su unidad, que en la columna estrecha del teléfono se partía («18» y «µm» en dos líneas).
static var _num_unit := RegEx.create_from_string("(?<=[0-9]) (?=(?:µm|mm|kPa|GPa|HV|kJ)(?![A-Za-z]))")

var caption: Label
var rows := {}  # id → PanelContainer
var zone: Variant = NO_ZONE  # la zona de las filas (null: las de la 1.x)


func _init() -> void:
	add_theme_constant_override("separation", 0)
	caption = Ui.para("", "Small")
	add_child(caption)
	add_child(Ui.gap(6))
	add_child(_row(["Capa", "Profundidad", "Rigidez E", "Tenacidad J"], "", "dimmer"))
	set_zone(null)


## Las filas de una zona del cuerpo (id de zones.gd, con su hueso) o, con null, las de la 1.x (el brazo, sin hueso).
func set_zone(zone_id: Variant) -> void:
	if zone_id != null:
		zone_id = Zones.resolve(zone_id).id
	if zone_id == zone:
		return
	zone = zone_id
	for id: String in rows:
		var old: Node = rows[id]
		remove_child(old)
		old.queue_free()
	rows.clear()
	if zone_id == null:
		caption.text = "Capas de la piel · brazo de un adulto. En tejido blando no hay dureza Vickers: rigidez E y tenacidad J."
		for l: Dictionary in Catalog.SKIN_LAYERS:
			var depth := ("> " + fmt_um(l.from)) if l.id == "musculo" else "%s – %s" % [fmt_um(l.from), fmt_um(l.to)]
			_add_layer(l, depth)
		_fit_columns()
		return
	var z := Zones.resolve(zone_id)
	caption.text = "Capas de la piel · %s. En tejido blando no hay dureza Vickers: rigidez E y tenacidad J; el hueso sí la tiene." % z.name
	var bone: Variant = Zones.bone(zone_id)
	for l: Dictionary in Zones.section_layers(zone_id):
		if l.id == "hueso":
			var r := _row([String(l.name), "%s – %s" % [fmt_um(l.from), fmt_um(l.to)], "%s GPa" % Js.js_num_str(bone.E),
				"dureza %s HV" % Js.js_num_str(bone.hv)], String(l.col), "dim")
			r.tooltip_text = "%s (cortical de %s)" % [bone.note, fmt_um(bone.corticalUm)]
			_keep(r, "hueso")
		else:
			var depth := ("> " + fmt_um(l.from)) if l.id == "cavidad" else "%s – %s" % [fmt_um(l.from), fmt_um(l.to)]
			_add_layer(l, depth)
	_fit_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_columns()


## Las columnas, iguales en todas las filas (la tabla sigue alineada), miden al menos su trozo más largo que no se puede
## partir (una palabra, o un número con su unidad): en el teléfono, «Tercer metacarpiano» se partía a mitad de palabra.
## Si en total no caben, la letra baja hasta CELL_FS_MIN y, en último caso, los mínimos se reparten en proporción: antes
## partir una palabra que salirse de la tarjeta.
func _fit_columns() -> void:
	var avail := size.x
	var table: Array = []
	for r: Node in get_children():
		if r.has_meta("cells"):
			table.append(r)
	if avail <= 1.0 or table.is_empty():
		return
	var head: PanelContainer = table[0]
	var panel := head.get_theme_stylebox(&"panel").get_minimum_size().x
	var pad := ROW_PAD
	var sep := COL_SEP
	var fs := CELL_FS
	var need := _column_needs(table, fs)
	while fs > CELL_FS_MIN and _sum(need) + panel + 2 * pad + 3 * sep > avail:
		fs -= 1
		need = _column_needs(table, fs)
	if _sum(need) + panel + 2 * pad + 3 * sep > avail:
		pad = ROW_PAD_TIGHT
		sep = COL_SEP_TIGHT
	var fixed := panel + 2 * pad + 3 * sep
	var k := 1.0 if _sum(need) + fixed <= avail else maxf(0.0, avail - fixed) / _sum(need)
	for r: Node in table:
		var m: MarginContainer = r.get_meta("margin")
		m.add_theme_constant_override("margin_left", pad)
		m.add_theme_constant_override("margin_right", pad)
		(r.get_meta("hbox") as HBoxContainer).add_theme_constant_override("separation", sep)
		var cells: Array = r.get_meta("cells")
		for i in cells.size():
			(cells[i] as Control).custom_minimum_size.x = floorf(float(need[i]) * k)
			var l: Label = (r.get_meta("labels") as Array)[i]
			if l.get_theme_font_size(&"font_size") != fs:
				l.add_theme_font_size_override(&"font_size", fs)


## Lo que pide cada columna a fs px: su trozo más largo entre espacios normales (el espacio duro une el número y su unidad).
static func _column_needs(table: Array, fs: int) -> Array:
	var need := [30.0, 30.0, 30.0, 30.0]
	for r: Node in table:
		var labels: Array = r.get_meta("labels")
		var swatch := SWATCH_W if bool(r.get_meta("has_swatch")) else 0.0
		for i in labels.size():
			for chunk in (labels[i] as Label).text.split(" ", false):
				var w := AppTheme.MONO.get_string_size(chunk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0 + (swatch if i == 0 else 0.0)
				need[i] = maxf(float(need[i]), w)
	return need


static func _sum(a: Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s


## El texto de una celda con el número pegado a su unidad (espacio duro) y «kJ/m²» sin partir por la barra (una unión de
## palabras, sin ancho ni glifo): se lee igual.
static func glue(s: String) -> String:
	return _num_unit.sub(s.replace("kJ/m²", "kJ/⁠m²"), " ", true)


func _add_layer(l: Dictionary, depth: String) -> void:
	var e := "%s kPa" % Js.js_num_str(l.E) if l.get("E") != null else "—"
	var j := "—" if l.id in ["cornea", "epidermis"] else "%s kJ/m²" % Js.js_num_str(l.jT)
	var r := _row([String(l.name), depth, e, j], String(l.col), "dim")
	r.tooltip_text = String(l.note)
	_keep(r, String(l.id))


func _keep(r: PanelContainer, id: String) -> void:
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(r)
	rows[id] = r


## fmtUm de sections.jsx: «18 µm» o «2,2 mm».
static func fmt_um(um: float) -> String:
	return "%s mm" % Js.to_fixed(um / 1000.0, 1).replace(".", ",") if um >= 1000.0 else "%s µm" % Js.js_num_str(um)


func _row(cells: Array, swatch: String, color: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Row"
	var col := Ui.vbox(0)
	var line := ColorRect.new()
	line.color = Palette.color("line")
	line.custom_minimum_size.y = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var m := Ui.margin(ROW_PAD, 5, ROW_PAD, 5)
	var h := Ui.hbox(COL_SEP)
	var row_cells: Array = []
	var row_labels: Array = []
	for i in cells.size():
		var cell: Control
		var l := Ui.label(glue(String(cells[i])), "Cell", color)
		l.add_theme_font_size_override("font_size", CELL_FS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0 and swatch != "":
			var box := Ui.hbox(6)
			var sq := ColorRect.new()
			sq.color = Palette.color(swatch)
			sq.custom_minimum_size = Vector2(9, 9)
			sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.add_child(sq)
			box.add_child(l)
			cell = box
		else:
			cell = l
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = RATIOS[i]
		cell.custom_minimum_size.x = 30.0
		row_cells.append(cell)
		row_labels.append(l)
		h.add_child(cell)
	# para _fit_columns: las celdas (el ancho mínimo de cada columna), sus etiquetas y si la primera lleva el cuadro de color
	p.set_meta("cells", row_cells)
	p.set_meta("labels", row_labels)
	p.set_meta("has_swatch", swatch != "")
	p.set_meta("margin", m)
	p.set_meta("hbox", h)
	m.add_child(h)
	col.add_child(m)
	p.add_child(col)
	Ui.ignore_mouse(col)
	return p


## Resalta la capa alcanzada (id de la pila: SKIN_LAYERS, las de la zona o «hueso»; la médula va dentro del hueso) o
## ninguna (null).
func highlight(reached: Variant) -> void:
	if reached == Zones.MARROW.id:
		reached = "hueso"
	for id: String in rows:
		var on: bool = reached != null and id == reached
		var p: PanelContainer = rows[id]
		p.theme_type_variation = &"RowOn" if on else &"Row"
		for l in p.find_children("*", "Label", true, false):
			Ui.set_color(l, "text" if on else "dim")
