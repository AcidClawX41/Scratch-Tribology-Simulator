## Tarjeta 1 · Herramienta (ToolCard de la 1.x): la uña (forma, material e incrustación), la garra o el colmillo (por
## grupos, y reforjados en otro material) o, en la 2.0, el aguijón de un insecto; la ficha con su dibujo y sus datos, y el
## estado de la queratina. Los aguijones (grupo «Insectos») tienen su propia opción y su ficha: masa en mg, púas, índice
## de Schmidt, aleteo, fuentes y calidad de los datos (textos de core/lab/sting_lab.gd).
## 2.0 · el velocirraptor reconstruido (grupo «Dinosaurios (reconstrucción)», unidad 4i) va con las garras: su ficha dice
## «reconstrucción», la banda de la masa y de la garra y la punta como pregunta abierta, con su dibujo (art_dino.gd) y los
## textos de core/lab/dino_lab.gd. Y una garra o un colmillo reforjados se pueden afilar: el deslizador «Afilado» (0-1),
## con las marcas de ClawSharpness.REFERENCES y dos barras, la presión que sube y la carga que aguanta de lado, que baja
## (LabState.sharpness_view; docs/fisica/velociraptor.md §10.4). Las dos barras van en fila y, por debajo de
## SHARP_ROW_MIN (un teléfono), una debajo de otra.
## Se construye una vez; refresh() la pone al día con el estado del banco.
extends "res://app/common/card.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Lab = preload("res://core/lab/lab.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const DinoViews = preload("res://app/lab/dino_views.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const Bar = preload("res://app/common/bar.gd")
const Palette = preload("res://app/theme/palette.gd")
const ForceMarks = preload("res://app/lab/force_marks.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const ArtView = preload("res://app/common/art_view.gd")
const ContentButton = preload("res://app/common/content_button.gd")
const Pill = preload("res://app/common/pill.gd")
const Segmented = preload("res://app/common/segmented.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const LabUi = preload("res://app/lab/lab_ui.gd")
const LabArt = preload("res://app/lab/lab_art.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const ArtCache = preload("res://app/common/art_cache.gd")

var lab: LabState
var art: ArtCache
var kind_seg: Segmented
var claw_box: VBoxContainer
var nail_box: VBoxContainer
var claw_view: ArtView
var claw_title: Label
var claw_desc: Label
var claw_stats: Array[HBoxContainer] = []
var claw_source: Label
var claw_tiles := {}  # id → ContentButton
var claw_groups := {}  # grupo → [rótulo, rejilla] (se ven los de la familia elegida: garras o insectos)
var nail_front: ArtView
var nail_side: ArtView
var nail_title: Label
var nail_stats: Array[HBoxContainer] = []
var geom_tiles := {}
var base_pills := {}
var base_note: Label
var inlay_label: Label
var inlay_pills := {}
var inlay_note: Label
var wet_box: VBoxContainer
var wet_seg: Segmented
var wet_note: Label
## 2.0 · afilado de una garra reforjada: deslizador con sus marcas y su leyenda, las dos barras y la nota.
var sharp_box: VBoxContainer
var sharp: ValueSlider
var sharp_marks: ForceMarks
var sharp_legend: HFlowContainer
var sharp_items: Array = []  # [fila, muestra de color, texto] por marca
var sharp_bars: WrapBox
var sharp_bar_parts := {}  # "pressure" | "lateral" → [título, barra, texto]
var sharp_note: Label
var _last_claw: Dictionary = Catalog.CLAWS[0]
var _last_insect: Dictionary = Insects.STINGERS[0]

## Texto de la opción de las garras: entero si cabe y corto en una tarjeta estrecha (un teléfono), para que las tres
## opciones quepan en una fila.
const KIND_CLAWS := ["🐾 Garras y colmillos", "🐾 Garras"]
const NARROW_CARD := 520.0
## Ancho (px) a partir del cual las dos barras del afilado van en fila; por debajo, una debajo de otra.
const SHARP_ROW_MIN := 440.0
## Marcas del deslizador del afilado: la punta de la ficha y las seis referencias medidas (ClawSharpness.REFERENCES).
const SHARP_MARKS_MAX := 7
## Paso del deslizador del afilado (0-1).
const SHARP_STEP := 0.01


func _init() -> void:
	super("Herramienta", "1")
	kind_seg = Segmented.new([{ "id": "unas", "label": "💅 Uñas" }, { "id": "garras", "label": KIND_CLAWS[0] },
		{ "id": "insectos", "label": "🐝 Insectos", "title": "Aguijones de abejas, avispas y hormigas (fuerzas en mN)" }], "unas",
		"Tipo de herramienta")
	right.add_child(kind_seg)
	resized.connect(_on_resized)
	_build_claws()
	_build_nails()
	inlay_label = Ui.sub_label("")
	body.add_child(inlay_label)
	var inlays := Ui.flow()
	for i: Dictionary in Catalog.INLAYS:
		var b := ContentButton.new("Pill")
		var row := Ui.hbox(7)
		if i.id != "none":
			var g := LabUi.view(Vector2(16, 16))
			row.add_child(g)
			b.set_meta("gem", g)
		var name := Ui.label(String(i.name), "PillText")
		row.add_child(name)
		b.main_labels.append(name)
		if i.get("mohs") != null:
			var m := Ui.label("M" + Ui.num(i.mohs), "PillMono")
			m.modulate.a = 0.8
			row.add_child(m)
			b.main_labels.append(m)
		b.set_body(row)
		b.tooltip_text = "%s HV" % Ui.num(i.hv) if i.hv != null else ""
		b.accessibility_name = String(i.name)
		inlays.add_child(b)
		inlay_pills[i.id] = b
	body.add_child(inlays)
	inlay_note = Ui.para("", "Note")
	body.add_child(inlay_note)
	_build_sharpness()
	wet_box = Ui.vbox(8)
	wet_box.add_child(Ui.sub_label("Estado de la queratina"))
	wet_seg = Segmented.new([{ "id": "seca", "label": "Seca" }, { "id": "humeda", "label": "💧 Húmeda (remojada)" }], "seca",
		"Estado de la queratina")
	wet_box.add_child(wet_seg)
	wet_note = Ui.para("", "Note")
	wet_box.add_child(wet_note)
	body.add_child(wet_box)


func _build_claws() -> void:
	claw_box = Ui.vbox(8)
	var preview := WrapBox.new(14.0, 10.0)
	var box := PanelContainer.new()
	box.theme_type_variation = &"PreviewArt"
	box.custom_minimum_size = Vector2(118, 150)
	claw_view = LabUi.view(Vector2(100, 132))
	box.add_child(claw_view)
	preview.add_child(box)
	var txt := Ui.vbox(5)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claw_title = Ui.para("", "Title")
	txt.add_child(claw_title)
	claw_desc = Ui.para("", "Body")
	claw_desc.add_theme_font_size_override("font_size", 12)
	txt.add_child(claw_desc)
	var stats := Ui.flow(12, 2)
	for i in 10:
		var s := LabUi.stat()
		stats.add_child(s)
		claw_stats.append(s)
	txt.add_child(stats)
	claw_source = Ui.para("", "Small", "dimmer")
	claw_source.mouse_filter = Control.MOUSE_FILTER_PASS
	txt.add_child(claw_source)
	txt.custom_minimum_size.x = 200.0
	preview.add_child(txt)
	claw_box.add_child(preview)
	for g: String in Catalog.CLAW_GROUPS:
		var label := Ui.sub_label(g)
		claw_box.add_child(label)
		var grid := TileGrid.new(74.0)
		for c: Dictionary in Catalog.CLAWS:
			if c.group != g:
				continue
			var t := LabUi.tile(Vector2(44, 58), String(c.name), "", String(c.desc))
			grid.add_child(t)
			claw_tiles[c.id] = t
		claw_box.add_child(grid)
		claw_groups[g] = [label, grid]
	body.add_child(claw_box)


func _build_nails() -> void:
	nail_box = Ui.vbox(8)
	var preview := WrapBox.new(14.0, 10.0)
	var pics := Ui.hbox(14)
	var front := PanelContainer.new()
	front.theme_type_variation = &"PreviewArt"
	front.custom_minimum_size = Vector2(92, 150)
	nail_front = LabUi.view(Vector2(80, 134))
	front.add_child(nail_front)
	pics.add_child(front)
	var side := PanelContainer.new()
	side.theme_type_variation = &"PreviewArt"
	side.custom_minimum_size = Vector2(150, 150)
	nail_side = LabUi.view(Vector2(140, 104))
	side.add_child(nail_side)
	pics.add_child(side)
	preview.add_child(pics)
	var txt := Ui.vbox(4)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size.x = 170.0
	nail_title = Ui.para("", "Title")
	nail_title.add_theme_font_size_override("font_size", 17)
	txt.add_child(nail_title)
	for i in 3:
		var s := LabUi.stat()
		(s.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(s.get_child(1) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(s)
		nail_stats.append(s)
	preview.add_child(txt)
	nail_box.add_child(preview)
	nail_box.add_child(Ui.sub_label("Forma"))
	var grid := TileGrid.new(74.0)
	for g: Dictionary in Catalog.GEOMS:
		var tip := "Área de la punta %s mm² · semiángulo %s° · uña libre %s mm" % [Ui.num(g.area), Ui.num(g.alpha), Ui.num(g.reach)]
		var t := LabUi.tile(Vector2(37, 62), String(g.name), "%s mm²" % Ui.num(g.area), tip)
		grid.add_child(t)
		geom_tiles[g.id] = t
	nail_box.add_child(grid)
	for grp: String in Catalog.BASE_GROUPS:
		nail_box.add_child(Ui.sub_label("Material · salón" if grp == "Salón" else "Material · experimentos (uña maciza)"))
		var chips := Ui.flow()
		for b: Dictionary in Catalog.BASES:
			if b.group != grp:
				continue
			var p := Pill.new(String(b.name))
			p.icon = AppTheme.icon_texture(LabArt.swatch_svg(b.id))
			p.tooltip_text = String(b.get("desc", "%s HV · Mohs %s" % [Ui.num(b.hv), Ui.num(b.mohs)]))
			chips.add_child(p)
			base_pills[b.id] = p
		nail_box.add_child(chips)
	base_note = Ui.para("", "Note", "dim")
	nail_box.add_child(base_note)
	body.add_child(nail_box)


## 2.0 · el afilado: deslizador (0-1) con sus marcas bajo la pista y su leyenda, las dos barras y la nota.
func _build_sharpness() -> void:
	sharp_box = Ui.vbox(8)
	sharp_box.add_child(Ui.sub_label("Afilado de la punta · experimento"))
	sharp = ValueSlider.new("Afilado", "(escala log)", 0.0, 1.0, SHARP_STEP)
	sharp_box.add_child(sharp)
	sharp_marks = ForceMarks.new(sharp.slider)
	sharp.slider.add_child(sharp_marks)
	sharp_legend = Ui.flow(12, 4)
	for i in SHARP_MARKS_MAX:
		var item := Ui.hbox(6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var text := Ui.label("", "Small")
		item.add_child(text)
		sharp_legend.add_child(item)
		sharp_items.append([item, swatch, text])
	sharp_box.add_child(sharp_legend)
	sharp_bars = WrapBox.new(14.0, 10.0)
	sharp_bars.row_min = SHARP_ROW_MIN
	sharp_bars.equal = true
	sharp_bars.align_top = true
	for key: String in ["pressure", "lateral"]:
		var col := Ui.vbox(5)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Ui.label("", "SliderLabel")
		col.add_child(title)
		var bar := Bar.new(9.0)
		col.add_child(bar)
		var text := Ui.para("", "Small")
		col.add_child(text)
		sharp_bars.add_child(col)
		sharp_bar_parts[key] = [title, bar, text]
	sharp_box.add_child(sharp_bars)
	sharp_note = Ui.para("", "Note")
	sharp_box.add_child(sharp_note)
	body.add_child(sharp_box)


## Recorrido y valor de un deslizador con las señales bloqueadas: dentro del árbol, Godot recorta el valor al cambiar el
## recorrido y emitiría value_changed (el patrón de MillPage.set_slider y MovingCarCard.set_slider).
static func set_slider(s: HSlider, lo: float, hi: float, value: float) -> void:
	s.set_block_signals(true)
	s.min_value = lo
	s.max_value = maxf(hi, lo)
	s.value = value
	s.set_block_signals(false)


## Conecta los controles con el estado del banco y la caché de dibujos (una vez).
func setup(p_lab: LabState, p_art: ArtCache) -> void:
	lab = p_lab
	art = p_art
	kind_seg.selected.connect(_on_kind)
	for id: String in claw_tiles:
		(claw_tiles[id] as Button).pressed.connect(_on_claw.bind(id))
		DinoViews.show_claw(LabUi.tile_art(claw_tiles[id]), art, Catalog.find_by_id(Catalog.CLAWS, id), null, "t" + id)
	claw_source.tooltip_text = ""
	for id: String in geom_tiles:
		(geom_tiles[id] as Button).pressed.connect(_on_geom.bind(id))
	for id: String in base_pills:
		(base_pills[id] as Button).pressed.connect(_on_base.bind(id))
	for id: String in inlay_pills:
		(inlay_pills[id] as Button).pressed.connect(_on_inlay.bind(id))
		var inlay: Dictionary = Catalog.find_by_id(Catalog.INLAYS, id)
		if (inlay_pills[id] as Node).has_meta("gem"):
			LabUi.show_gem((inlay_pills[id] as Node).get_meta("gem"), art, inlay)
	wet_seg.selected.connect(_on_wet)
	sharp.value_changed.connect(_on_sharpness)


func _on_resized() -> void:
	kind_seg.set_label("garras", KIND_CLAWS[1] if size.x < NARROW_CARD else KIND_CLAWS[0])


func _on_kind(id: String) -> void:
	match id:
		"garras":
			lab.set_claw(_last_claw)
		"insectos":
			lab.set_claw(_last_insect)
		_:
			lab.set_claw(null)


func _on_claw(id: String) -> void:
	if lab.claw != null and lab.claw.id == id:
		refresh()
		return
	lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, id))


func _on_geom(id: String) -> void:
	if lab.geom.id == id:
		refresh()
		return
	lab.set_geom(Catalog.find_by_id(Catalog.GEOMS, id))


func _on_base(id: String) -> void:
	if lab.base.id == id:
		refresh()
		return
	lab.set_base(Catalog.find_by_id(Catalog.BASES, id))


func _on_inlay(id: String) -> void:
	if lab.inlay.id == id:
		refresh()
		return
	lab.set_inlay(Catalog.find_by_id(Catalog.INLAYS, id))


func _on_wet(id: String) -> void:
	lab.set_wet(id == "humeda")


## El afilado del deslizador, en centésimas (su paso, SHARP_STEP).
func _on_sharpness(v: float) -> void:
	var s := Js.js_round(v * 100.0) / 100.0
	if s != lab.sharpness:
		lab.set_sharpness(s)


func refresh() -> void:
	var claw: Variant = lab.claw
	var inlay: Dictionary = lab.inlay
	var tool: Dictionary = lab.tool()
	var insect := claw != null and Insects.is_stinger(claw)
	if insect:
		_last_insect = claw
	elif claw != null:
		_last_claw = claw
	kind_seg.set_value("insectos" if insect else ("garras" if claw != null else "unas"))
	claw_box.visible = claw != null
	nail_box.visible = claw == null
	# las fichas de la familia elegida: las garras y colmillos de la 1.x o los insectos
	for g: String in claw_groups:
		var shown := (g == Insects.GROUP) == insect
		for n: Control in claw_groups[g]:
			n.visible = shown
	if claw != null:
		_refresh_claw(claw, inlay, tool)
	else:
		_refresh_nail(lab.geom, lab.base, inlay, lab.wet, tool)
	if insect:
		inlay_label.text = "Material del aguijón · experimento: el mismo aguijón, reforjado en otro material"
	else:
		inlay_label.text = ("Material de la garra · experimento: la misma garra, reforjada en otro material" if claw != null
			else "Incrustación · piedras en la uña (la de la punta es la que araña)")
	for id: String in inlay_pills:
		(inlay_pills[id] as ContentButton).set_on(id == inlay.id)
	var note := ""
	if insect and inlay.id != "none":
		var m: Dictionary = lab.sting_marks()
		note = "aguijón reforjado en %s: la misma forma, con %s HV y %s GPa; pandea a ~%s (el de quitina, a ~%s). Las púas y la autotomía no cambian: son de la geometría y del insecto." % [
			Lab.material_name(inlay), Ui.num(inlay.hv), Ui.num(inlay.E), StingLab.fmt_force(m.buckle), StingLab.fmt_force(m.buckleNatural)]
	elif claw != null and inlay.id != "none":
		if Js.truthy(claw.get("fang")):
			note = "colmillo reforjado en %s: aguja con dureza de %s HV (ya no se rompe a %s N)" % [
				Lab.material_name(inlay), Ui.num(inlay.hv), Js.template_str(claw.get("fBreak"))]
		else:
			note = "garra reforjada en %s: la misma forma, con dureza de %s HV" % [Lab.material_name(inlay), Ui.num(inlay.hv)]
	inlay_note.text = note
	inlay_note.visible = note != ""
	_refresh_sharpness()
	var keratin: bool = tool.keratin
	wet_box.visible = keratin or (lab.wet and not insect)
	wet_seg.set_value("humeda" if lab.wet else "seca")
	if insect:
		wet_note.text = "La cutícula de un aguijón no es queratina: el agua no la ablanda (y los datos de dureza son de aguijones secos)."
	elif not keratin:
		wet_note.text = "Esta punta no es queratina (gel, acrílico, metal, gema o dentina): el agua no la cambia."
	elif lab.wet:
		wet_note.text = "Empapada, la queratina pierde ~80 % de rigidez y resistencia (Farran 2009): se dobla y apenas raya."
	else:
		wet_note.text = "Humedad normal de la uña (14-30 % de agua). Prueba a remojarla."


func _refresh_claw(claw: Dictionary, inlay: Dictionary, tool: Dictionary) -> void:
	var spec := Lab.claw_spec(claw, inlay, tool)
	var insect := Insects.is_stinger(claw)
	var dino := DinoLab.is_dino(claw)
	DinoViews.show_claw(claw_view, art, claw, inlay, "main", null, insect or dino)
	claw_title.text = spec.title
	claw_desc.text = String(claw.desc)
	var rows: Array
	if insect:
		rows = StingLab.spec_rows(claw, inlay, tool)  # masa en mg, púas, Schmidt, aleteo y calidad de los datos
		claw_source.text = "Fuentes: " + StingLab.short_sources(String(claw.get("source", "")))
		claw_source.tooltip_text = String(claw.get("source", ""))
	elif dino:
		# 2.0 · la reconstrucción: bandas de la masa y de la garra, la punta sin medir, el agarre de un pie y el golpe
		rows = DinoLab.spec_rows(claw, spec.material, spec.hardness, tool)
		claw_source.text = DinoLab.sources_line(claw)
		claw_source.tooltip_text = String(claw.get("source", ""))
	else:
		rows = [
			[spec.material, spec.hardness],
			["punta", "R %s µm · α %s°" % [Js.to_fixed(tool.tipRadiusUm, 0), Ui.num(tool.alpha)]],
			["curvatura", "%s %%" % Js.to_fixed(claw.curve * 100.0, 0)],
			["longitud útil", "%s mm" % Ui.num(claw.reach)],
			["peso", "%s kg" % Ui.num(claw.mass)],
			["fuerza", "~%s N" % Ui.num(claw.force)],
			["golpe", "~%s J" % Format.fmt_j(tool.strikeJ)],
		]
	claw_source.visible = insect or dino
	# la línea de la garra de cine, del color de la ficción (como su etiqueta en el resultado); las demás, apagadas
	Ui.set_color(claw_source, "rose" if dino and DinoLab.is_film(claw) else "dimmer")
	for i in claw_stats.size():
		claw_stats[i].visible = i < rows.size()
		if i < rows.size():
			LabUi.set_stat(claw_stats[i], rows[i][0], rows[i][1])
	for id: String in claw_tiles:
		(claw_tiles[id] as ContentButton).set_on(id == claw.id)


## 2.0 · el afilado: solo con una garra o un colmillo reforjados (LabState.sharpenable). Todos los textos y los niveles de
## las barras salen del estado (LabState.sharpness_view).
func _refresh_sharpness() -> void:
	var view: Dictionary = lab.sharpness_view()
	sharp_box.visible = not view.is_empty()
	if view.is_empty():
		return
	set_slider(sharp.slider, 0.0, 1.0, lab.sharpness)
	sharp.display.text = String(view.display)
	sharp.slider.accessibility_description = String(view.spoken)
	var marks: Array = view.marks
	sharp_marks.set_marks(marks.map(func(m: Dictionary) -> Array: return [float(m.t), Palette.color(String(m.color))]))
	for i in sharp_items.size():
		var item: Array = sharp_items[i]
		(item[0] as Control).visible = i < marks.size()
		if i < marks.size():
			var c := Palette.color(String(marks[i].color))
			(item[1] as ColorRect).color = c
			(item[2] as Label).text = String(marks[i].text)
			Ui.set_color(item[2], c)
	for key: String in sharp_bar_parts:
		var parts: Array = sharp_bar_parts[key]
		var b: Dictionary = view[key]
		(parts[0] as Label).text = String(b.title)
		(parts[1] as Bar).set_level(float(b.level), Palette.color(String(b.color)))
		(parts[2] as Label).text = String(b.text)
		Ui.set_color(parts[2], String(b.color))
	sharp_note.text = String(view.note)


func _refresh_nail(geom: Dictionary, base: Dictionary, inlay: Dictionary, wet: bool, tool: Dictionary) -> void:
	LabUi.show_nail(nail_front, art, geom, base, inlay, wet, "main")
	LabUi.show_nail_side(nail_side, art, geom, base, inlay, wet, "main")
	nail_title.text = "%s · %s" % [geom.name, base.short]
	LabUi.set_stat(nail_stats[0], "dureza", "%s HV · Mohs %s" % [Format.fmt_p(tool.hv), Js.template_str(tool.get("mohs"))])
	LabUi.set_stat(nail_stats[1], "punta", "%s mm² · R %s µm · α %s°" % [Js.to_fixed(tool.area, 2), Js.to_fixed(tool.tipRadiusUm, 0),
		Ui.num(tool.alpha)])
	LabUi.set_stat(nail_stats[2], "uña libre", "%s mm" % Ui.num(geom.reach))
	for id: String in geom_tiles:
		var t: ContentButton = geom_tiles[id]
		t.set_on(id == geom.id)
		LabUi.show_nail(LabUi.tile_art(t), art, Catalog.find_by_id(Catalog.GEOMS, id), base, Catalog.INLAYS[0], false, "t" + id)
	for id: String in base_pills:
		(base_pills[id] as Pill).set_on(id == base.id)
	var desc: Variant = base.get("desc")
	base_note.text = "🧪 " + String(desc) if desc != null else ""
	base_note.visible = desc != null
