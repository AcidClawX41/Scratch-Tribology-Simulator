## Tarjeta · Banco de ensayo (ResultCard de la 1.x): el banco animado y, al terminar, el veredicto con su color, las
## barras de dureza, las métricas del resultado, el corte (coche, piel, puerta o perfil de la huella), la tabla de la
## piel y la ficha del material. Todo sale del `res` de compute(): aquí solo se escribe con los formatos de core.
## Con un aguijón (2.0, res.sting): sus métricas con las fuerzas en mN (perforar, pandear, clavado y autotomía, púas,
## veneno, giro, dolor y aleteo), el corte de la piel con el aguijón dentro y la moraleja (StingLab.moral).
## Materiales de la 2.0 (docs/fisica/pulido-materiales.md §7.4): la uña que cede, la huella que queda al levantar la
## punta, las grietas de los frágiles, la abolladura, los vidrios de coche y el mellado (materials_rows).
## Biología de la 2.0 (docs/fisica/pulido-biologia.md §9.3): la zona del cuerpo, el hueso, lo que frena la punta al
## punzar (la grieta y el roce en los flancos), la punta de esmalte de los colmillos y el ángulo de ataque
## (biology_rows); la tabla de la piel enseña las capas de la zona con su hueso.
## Unidad 4n (core/lab/bench_texts.gd): la presión real con quién le pone el tope (la nominal F/A solo cuando es la real: por
## encima de la dureza no tiene sentido) y χ legible con las puntas afiladas; la etiqueta FICCIÓN y su nota con el
## velocirraptor de cine; y «Fuentes y estimaciones de este ensayo», plegada y con su resumen (LabState.trial_sources), con
## cada dato de la 2.0 que ha usado el ensayo, su calidad y, con «Citas completas», su cita legible. En el teléfono las
## métricas van de dos en dos, como en la 1.x móvil (fit_metrics).
## Unidad 4p: con un contacto elástico (res.p0MPa), la presión media F/A y el pico de Hertz, y debajo de las métricas la frase
## que dice cuál es cuál (BenchTexts.hertz_note).
extends "res://app/common/card.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Art = preload("res://core/lab/art.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const Physics = preload("res://core/lab/physics.gd")
const Zones = preload("res://core/lab/zones.gd")
## 2.0 · la fila de la punta afilada de una garra reforjada (unidad 4i).
const DinoLab = preload("res://core/lab/dino_lab.gd")
## 2.0 · los textos del banco de la unidad 4n: presión, ficción y fuentes del ensayo.
const BenchTexts = preload("res://core/lab/bench_texts.gd")
const Palette = preload("res://app/theme/palette.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ArtView = preload("res://app/common/art_view.gd")
const Bar = preload("res://app/common/bar.gd")
const Metric = preload("res://app/common/metric.gd")
const Pill = preload("res://app/common/pill.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const Bench = preload("res://app/lab/bench.gd")
const LabArt = preload("res://app/lab/lab_art.gd")
const SkinTable = preload("res://app/lab/skin_table.gd")

## Modo de abrasión (Hokkirigawa-Kato): texto y color, como ABS en la 1.x.
const ABS := { "corte": ["corte (arranca viruta)", "coral"], "cuña": ["cuña (apila proa)", "gold"], "arado": ["arado (desplaza)", "mint"] }
const MAX_METRICS := 28
## Color de cada calidad en «Fuentes y estimaciones» (los de la tarjeta del coche en marcha).
const QUALITY_COLOR := { "primary": "mint", "secondary": "ice", "estimate": "gold", "ficcion": "rose", "model": "text", "": "dim" }
## Ancho mínimo de las métricas: el minmax(158px, 1fr) de la 1.x de escritorio y, cuando no caben dos así (el teléfono),
## dos columnas de lo que quepa, como la 1.x móvil (width 48,5 %), pero no más estrechas que METRIC_COL_MIN.
const METRIC_COL := 158.0
const METRIC_COL_MIN := 120.0

var lab: LabState
var art: ArtCache
var target_name: Label
var bench: Bench
var hint: Label
var details: VBoxContainer
var verdict_box: PanelContainer
var verdict: Label
var tag_tear: Label
var tag_wet: Label
## 2.0 · el velocirraptor de cine: la etiqueta FICCIÓN y la nota de lo que haría la garra de verdad (BenchTexts.fiction).
var tag_fiction: Label
var fiction_note: Label
var vsub: Label
## Moraleja de un aguijón (StingLab.moral), oculta con las demás herramientas.
var moral: Label
var hardness: VBoxContainer
var hard_rows: Array = []  # [nombre, barra, valor]
var metrics_grid: TileGrid
var metrics: Array[Metric] = []
## 2.0 · con un contacto elástico, la frase que dice cuál es la presión media y cuál el pico de Hertz (BenchTexts.hertz_note,
## unidad 4p), debajo de las métricas.
var hertz_note: Label
var section_view: ArtView
var skin_table: SkinTable
var fact: Label
var adhesion: Label
## 2.0 · «Fuentes y estimaciones de este ensayo» (LabState.trial_sources): plegada, con su resumen.
var sources_box: VBoxContainer
var sources_toggle: Pill
var sources_summary: Label
var sources_list: VBoxContainer
## «Citas completas»: debajo de cada dato, su cita entera (en la lista desplegada; en escritorio, también en la ayuda).
var sources_full: Pill
var sources_rows: Array = []  # [caja, cabecera, fuente]
var _full_cites := false
var _sources: Array = []  # las filas que se ven (para repintarlas al cambiar de citas)
var _verdict_style: StyleBoxFlat
var _shown_run := -1
var _serial := 0


func _init() -> void:
	super("Banco de ensayo")
	target_name = Ui.label("", "Small")
	right.add_child(target_name)
	var box := PanelContainer.new()
	box.theme_type_variation = &"BenchBox"
	bench = Bench.new()
	box.add_child(bench)
	body.add_child(box)
	hint = Ui.para("", "Body", "dimmer")
	body.add_child(hint)
	details = Ui.vbox(14)
	details.accessibility_live = AccessibilityServer.LIVE_POLITE
	body.add_child(details)
	verdict_box = PanelContainer.new()
	verdict_box.theme_type_variation = &"VerdictBox"
	_verdict_style = AppTheme.box(Palette.color("panel2"), 14, Palette.color("line"), 1, 14.0, 12.0)
	_verdict_style.border_width_left = 5
	_verdict_style.content_margin_left = 16.0
	verdict_box.add_theme_stylebox_override("panel", _verdict_style)
	var vcol := Ui.vbox(6)
	var top := WrapBox.new(10.0, 6.0)
	verdict = Ui.para("", "Verdict")
	top.add_child(verdict)
	var tags := Ui.hbox(8)
	tag_tear = Ui.label("DESGARRO", "Tag")
	tags.add_child(tag_tear)
	tag_wet = Ui.label("HÚMEDA", "Tag")
	tag_wet.add_theme_stylebox_override("normal", AppTheme.box(Palette.color("ice"), 7, Color.TRANSPARENT, 0, 8.0, 2.0))
	tags.add_child(tag_wet)
	tag_fiction = Ui.label("FICCIÓN", "Tag")
	tag_fiction.add_theme_stylebox_override("normal", AppTheme.box(Palette.color("rose"), 7, Color.TRANSPARENT, 0, 8.0, 2.0))
	tags.add_child(tag_fiction)
	top.add_child(tags)
	vcol.add_child(top)
	vsub = Ui.para("", "Body")
	vcol.add_child(vsub)
	fiction_note = Ui.para("", "Note", "rose")
	fiction_note.visible = false
	vcol.add_child(fiction_note)
	verdict_box.add_child(vcol)
	details.add_child(verdict_box)
	moral = Ui.para("", "Note")
	moral.visible = false
	details.add_child(moral)
	hardness = Ui.vbox(6)
	for i in 2:
		var row := Ui.hbox(10)
		var n := Ui.label("", "Cell")
		n.custom_minimum_size.x = 64.0
		row.add_child(n)
		var b := Bar.new(9.0)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		var v := Ui.label("", "Cell")
		v.custom_minimum_size.x = 118.0
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		hardness.add_child(row)
		hard_rows.append([n, b, v])
	var scale := Ui.label("escala logarítmica", "Small")
	scale.add_theme_font_size_override("font_size", 10)
	scale.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hardness.add_child(scale)
	details.add_child(hardness)
	metrics_grid = TileGrid.new(METRIC_COL)
	metrics_grid.resized.connect(fit_metrics)
	for i in MAX_METRICS:
		var m := Metric.new()
		metrics_grid.add_child(m)
		metrics.append(m)
	details.add_child(metrics_grid)
	hertz_note = Ui.para("", "Note")
	hertz_note.visible = false
	details.add_child(hertz_note)
	var sec := PanelContainer.new()
	sec.theme_type_variation = &"SectionBox"
	var sec_col := Ui.vbox(10)
	section_view = ArtView.new()
	section_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_view.max_width = 560.0
	section_view.stale_ok = false
	sec_col.add_child(section_view)
	skin_table = SkinTable.new()
	sec_col.add_child(skin_table)
	sec.add_child(sec_col)
	details.add_child(sec)
	fact = Ui.para("", "Body")
	details.add_child(fact)
	adhesion = Ui.para("", "Note")
	details.add_child(adhesion)
	_build_sources()


## 2.0 · «Fuentes y estimaciones de este ensayo»: el título con su botón «Ver», el resumen y la lista (plegada).
func _build_sources() -> void:
	sources_box = Ui.vbox(6)
	var head := Ui.hbox(8)
	var title := Ui.sub_label("Fuentes y estimaciones de este ensayo")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	sources_toggle = Pill.new("Ver", "Pill", false)
	sources_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sources_toggle.accessibility_name = "Ver las fuentes y estimaciones del ensayo"
	head.add_child(sources_toggle)
	sources_box.add_child(head)
	sources_summary = Ui.para("", "Small")
	sources_box.add_child(sources_summary)
	sources_list = Ui.vbox(6)
	sources_list.visible = false
	sources_full = Pill.new("Citas completas", "Pill", false)
	sources_full.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sources_full.accessibility_name = "Ver las citas completas"
	sources_list.add_child(sources_full)
	sources_box.add_child(sources_list)
	sources_box.visible = false
	details.add_child(sources_box)


func setup(p_lab: LabState, p_art: ArtCache) -> void:
	lab = p_lab
	art = p_art
	bench.setup(art, "main")
	sources_toggle.pressed.connect(toggle_sources)
	sources_full.pressed.connect(toggle_full_cites)


## Columnas de las métricas para el ancho que tienen: las de la 1.x de escritorio (158 px) o, si no caben dos, dos.
func fit_metrics() -> void:
	var w := metrics_grid.size.x
	var col := METRIC_COL
	if w < 2.0 * METRIC_COL + metrics_grid.gap:
		col = maxf(METRIC_COL_MIN, floorf((w - metrics_grid.gap) / 2.0))
	if col != metrics_grid.min_col:
		metrics_grid.min_col = col
		metrics_grid.queue_sort()


## Abre o pliega la lista de fuentes y estimaciones.
func toggle_sources() -> void:
	sources_list.visible = not sources_list.visible
	sources_toggle.text = "Ocultar" if sources_list.visible else "Ver"
	sources_toggle.set_on(sources_list.visible)
	sources_toggle.accessibility_name = ("Ocultar" if sources_list.visible else "Ver") + " las fuentes y estimaciones del ensayo"


## Enseña u oculta la cita entera debajo de cada dato.
func toggle_full_cites() -> void:
	_full_cites = not _full_cites
	sources_full.set_on(_full_cites)
	sources_full.accessibility_name = "Ocultar las citas completas" if _full_cites else "Ver las citas completas"
	_fill_sources(_sources)


## El banco en el estado actual (lo llama la sección en cada cambio).
func bench_state() -> Dictionary:
	var v2 := lab.model == Physics.MODEL_V2
	return {
		"target": lab.target, "res": lab.res, "phase": lab.phase, "length": lab.length, "method": lab.method, "run": lab.run_seq,
		"tool": { "claw": lab.claw, "geom": lab.geom, "base": lab.base, "inlay": lab.inlay, "wet": lab.wet },
		# 2.0: el ángulo de ataque del ensayo, para que la herramienta en espera ya se incline al moverlo
		"attack": lab.attack() if v2 else null, "model": lab.model,
	}


func refresh() -> void:
	target_name.text = String(lab.target.name)
	bench.set_state(bench_state())
	var res: Variant = lab.res
	var done: bool = lab.phase == "done" and res != null
	hint.visible = not done
	hint.text = "Ensayando…" if lab.phase == "running" else "Pulsa ARAÑAR para correr el ensayo."
	details.visible = done
	if not done or _shown_run == lab.run_seq:
		return
	_shown_run = lab.run_seq
	show_result(res, lab.target, lab.length)


## Pinta un resultado (también lo usan los tests con cualquier `res` de compute()).
func show_result(res: Dictionary, target: Dictionary, length: float) -> void:
	var vcol := Palette.color(res.vcol)
	verdict.text = String(res.verdict)
	verdict.add_theme_color_override("font_color", vcol)
	_verdict_style.border_color = vcol
	tag_tear.visible = Js.truthy(res.get("tearing"))
	tag_wet.visible = Js.truthy(res.get("wet"))
	vsub.text = String(res.vsub)
	# 2.0 · el velocirraptor de cine: la garra es de película y la tarjeta lo dice (la selección es la del ensayo)
	var fic: Dictionary = BenchTexts.fiction(lab.claw, lab.inlay) if lab != null else {}
	tag_fiction.visible = not fic.is_empty()
	fiction_note.visible = not fic.is_empty()
	fiction_note.text = String(fic.get("note", ""))
	var sting := res.get("sting") is Dictionary
	var mo := StingLab.moral(res, target)
	moral.text = mo
	moral.visible = mo != ""
	var solid := not Js.truthy(res.get("skin")) and not Js.truthy(res.get("paint"))
	hardness.visible = solid
	if solid:
		var who := "Tu uña"
		if Js.truthy(res.get("claw")):
			who = "Aguijón" if sting else "Garra"
		var rows := [
			[who, res.hvTool, res.get("mohsTool"), "rose"],
			["Laca" if Js.truthy(res.get("woodDoor")) else "Objetivo", res.tHV, res.get("tMohs"), "mint"],
		]
		for i in 2:
			var r: Array = rows[i]
			var c := Palette.color(r[3])
			(hard_rows[i][0] as Label).text = r[0]
			(hard_rows[i][1] as Bar).set_level(Format.hv_bar(r[1]) / 100.0, c)
			var m := (" · M" + Ui.num(r[2])) if Js.truthy(r[2]) else ""
			(hard_rows[i][2] as Label).text = "%s HV%s" % [Format.fmt_p(r[1]), m]
			Ui.set_color(hard_rows[i][2], c)
	var list := metric_rows(res, length)
	for i in metrics.size():
		metrics[i].visible = i < list.size()
		if i < list.size():
			var d: Array = list[i]
			metrics[i].set_data(d[0], d[1], d[2], Palette.color(d[3]))
	var hn := BenchTexts.hertz_note(res)  # 2.0: la presión media y el pico de Hertz de un contacto elástico (unidad 4p)
	hertz_note.text = hn
	hertz_note.visible = hn != ""
	_show_section(res, target)
	fact.text = String(target.fact)
	adhesion.text = ("Adhesión Van der Waals: %s mN, minúscula frente a la fuerza aplicada. Solo domina a escala micro/nano o en superficies muy lisas a carga casi nula (gecko / stiction)."
		% Js.to_fixed(res.Fadh_mN, 2))
	_fill_sources(lab.trial_sources() if lab != null and lab.res != null else [])


## La lista de fuentes y estimaciones del ensayo: una fila por dato («Etiqueta: valor · calidad», del color de su calidad)
## y, con «Citas completas», su cita entera debajo; en escritorio la cita sale también en la ayuda emergente del dato. No se
## abrevian: muchas fuentes de la 2.0 son frases con números y una abreviatura automática las parte. Las filas se crean la
## primera vez que hacen falta y se reutilizan.
func _fill_sources(rows: Array) -> void:
	_sources = rows
	sources_box.visible = not rows.is_empty()
	sources_summary.text = BenchTexts.sources_summary(rows)
	while sources_rows.size() < rows.size():
		var box := Ui.vbox(1)
		var head := Ui.para("", "Cell")
		box.add_child(head)
		var src := Ui.para("", "Small")
		box.add_child(src)
		sources_list.add_child(box)
		sources_rows.append([box, head, src])
	for i in sources_rows.size():
		var it: Array = sources_rows[i]
		(it[0] as Control).visible = i < rows.size()
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		var q: String = r.quality
		var tag := (" · " + String(BenchTexts.QUALITY_TEXT[q])) if BenchTexts.QUALITY_TEXT.has(q) else ""
		(it[1] as Label).text = "%s: %s%s" % [r.label, r.value, tag]
		Ui.set_color(it[1], QUALITY_COLOR.get(q, "dim"))
		var src: String = r.source
		(it[1] as Label).tooltip_text = src
		(it[1] as Label).mouse_filter = Control.MOUSE_FILTER_PASS
		(it[2] as Label).text = "Fuente: %s" % src
		(it[2] as Label).visible = _full_cites and src != ""


func _show_section(res: Dictionary, target: Dictionary) -> void:
	_serial += 1
	var run := "%d:%s" % [_serial, target.id]
	var r := res.duplicate(true)
	skin_table.visible = Js.truthy(res.get("skin"))
	if skin_table.visible:
		skin_table.set_zone(res.get("zone"))  # 2.0: las capas de la zona con su hueso; la 1.x, las del brazo
	var sting: Variant = res.get("sting")
	var sting_claw: Variant = StingLab.claw_of(res)
	if Js.truthy(res.get("skin")) and sting_claw != null:
		# el corte de la piel con el aguijón dentro hasta la capa que alcanza (y, si se queda, el aparato con el saco)
		var claw: Dictionary = sting_claw
		var inlay: Dictionary = Catalog.find_by_id(Catalog.INLAYS, sting.material) if sting.reforged else Catalog.INLAYS[0]
		section_view.aspect = 184.0 / 300.0
		section_view.set_art(art, "sts:" + run, LabArt.sting_section.bind(r, claw, inlay), Rect2(0, 0, 300, 184))
		skin_table.highlight(sting.layerId if sting.pierces == true else null)
	elif Js.truthy(res.get("skin")):
		section_view.aspect = 164.0 / 300.0
		section_view.set_art(art, "sks:" + run, Art.skin_section_art.bind(r, { "uid": "sks" }), Rect2(0, 0, 300, 164))
		section_view.accessibility_name = ("Corte de la piel: la herida llega a %s, %s" % [Format.fmt_depth(res.depthUm), res.layer]
			if res.depthUm > 0.0 else "Corte de la piel: sin herida")
		var reached: Variant = null
		var pen: Variant = res.get("pen")
		if pen is Dictionary:
			reached = pen.layerId if res.depthUm > 0.0 else null  # 2.0: el informe de penetration.gd lo da por su id
		elif res.depthUm > 0.0:
			for l: Dictionary in Catalog.SKIN_LAYERS:
				if l.name == res.get("layer"):
					reached = l.id
					break
		skin_table.highlight(reached)
	elif Js.truthy(res.get("paint")):
		section_view.aspect = 164.0 / 300.0
		section_view.set_art(art, "cars:" + run, Art.car_section_art.bind(r, target, { "uid": "cars" }), Rect2(0, 0, 300, 164))
		section_view.accessibility_name = "Corte de %s: %s, ≈ %s" % [String(target.name).to_lower(), String(res.verdict).to_lower(),
			Format.fmt_depth(res.depthUm)]
	elif Js.truthy(res.get("woodDoor")):
		section_view.aspect = 156.0 / 300.0
		section_view.set_art(art, "door:" + run, LabArt.door_section.bind(res.depthUm, res.vcol, target.layers.film.t, target.thickness),
			Rect2(0, 0, 300, 156))
	else:
		section_view.aspect = 112.0 / 320.0
		section_view.set_art(art, "xs:" + run, LabArt.cross_section.bind(r, target), Rect2(0, 0, 320, 112))


## Las métricas del resultado, en el orden y con las condiciones de la 1.x: [etiqueta, símbolo, valor, color]. Las de
## un aguijón, en sting_metric_rows.
static func metric_rows(res: Dictionary, length: float) -> Array:
	if res.get("sting") is Dictionary:
		return sting_metric_rows(res)
	var out: Array = []
	var skin := Js.truthy(res.get("skin"))
	var puncture := Js.truthy(res.get("puncture"))
	var paint := Js.truthy(res.get("paint"))
	var vcol: String = res.vcol
	var depth: float = res.depthUm
	# 2.0 · la presión real con su tope; la nominal solo cuando es la real (unidad 4n, BenchTexts.pressure_rows)
	out.append_array(BenchTexts.pressure_rows(res))
	var depth_label := "Profundidad punción" if puncture else ("Profundidad herida" if skin else "Profundidad surco")
	var depth_val := "sin herida" if (skin and depth <= 0.0) else "≈ %s%s" % [Format.fmt_depth(depth), " (tope)" if Js.truthy(res.get("fullReach")) else ""]
	out.append([depth_label, "", depth_val, vcol])
	out.append_array(recovery_nail_rows(res))
	if skin:
		var hurt := Js.truthy(res.get("pierces")) if puncture else Js.truthy(res.get("ruptures"))
		out.append(["Fuerza para perforar" if puncture else "Fuerza para romper la piel", "", "≈ %s N" % Format.fmt_f(res.fPuncture),
			"coral" if hurt else "mint"])
		out.append(["Sangra", "", "sí" if Js.truthy(res.get("bleeds")) else "no", "coral" if Js.truthy(res.get("bleeds")) else "mint"])
		if not puncture and not Js.truthy(res.get("ruptures")):
			out.append(["Esfuerzo en la superficie", "", "%s MPa" % Format.fmt_p(res.stress), "text"])
	else:
		var ratio: float = res.ratio
		out.append(["Ratio dureza", "r", "%s×" % Js.to_fixed(ratio, 2), "coral" if ratio >= 1.25 else ("gold" if ratio >= 0.8 else "mint")])
	var energy := _num(res, "energyJ")
	if puncture and energy > 0.0:
		out.append(["Energía del golpe", "", "%s J" % Format.fmt_j(energy), "text"])
	if Js.truthy(res.get("through")) and not skin:
		out.append(["Agujero" if puncture else "Raja", "", "Ø %s" % Format.fmt_len(_num(res, "grooveWidthUm")), vcol])
	if puncture and energy > 0.0 and res.get("workJ") != null:
		out.append(["Energía que absorbe", "", "%s J" % Format.fmt_j(minf(res.workJ, energy)), "text"])
	if res.get("paneN") != null:
		out.append(["La hoja se parte con", "", "≈ %s N" % Format.fmt_f(res.paneN), "coral" if Js.truthy(res.get("shattered")) else "mint"])
	out.append_array(materials_rows(res))
	out.append_array(biology_rows(res))
	if paint or Js.truthy(res.get("woodDoor")) or skin:
		var layer: Variant = res.get("layer")
		out.append(["Capa alcanzada", "", String(layer) if layer != null else "ninguna", vcol])
	if not puncture and not skin and not paint:
		var chi: float = res.chi
		out.append(["Penetración", "χ = P/H", BenchTexts.chi_text(chi), "coral" if chi >= 0.1 else "dim"])
	if not puncture and depth > 0.05 and res.get("grooveWidthUm") != null:
		out.append(["Anchura de la herida" if skin else "Anchura del surco", "", "≈ %s" % Format.fmt_depth(res.grooveWidthUm), "text"])
	if not skin:
		var phi: float = res.phi
		out.append(["Contacto plástico", "φ", "%s %%" % Js.to_fixed(phi * 100.0, 0), "mint" if phi < 0.5 else "dim"])
	var abs_mode: Variant = res.get("absMode")
	if Js.truthy(abs_mode):
		out.append(["Fricción de rayado", "SCOF", "μ %s = %s adh + %s arado" % [Js.to_fixed(res.muEff, 2), Js.to_fixed(res.muAdh, 2),
			Js.to_fixed(res.muPlough, 2)], "coral" if res.muPlough > 0.3 else "dim"])
		out.append(["Modo abrasión", "", ABS[abs_mode][0], ABS[abs_mode][1]])
	else:
		out.append(["Fricción Coulomb", "μ · Ft", "%s · %s N" % [Js.to_fixed(res.mu, 2), Format.fmt_f(res.Ffric)], "text"])
	out.append(["Adhesión vdW", "JKR", "%s mN" % Js.to_fixed(res.Fadh_mN, 2), "text"])
	out.append(["Desgaste Archard", "", "%s u.a." % Js.template_str(res.get("wearIdx")), "text"])
	out.append(["Qué cede", "", String(res.get("cede", "")) if res.get("cede") != null else "", "text"])
	if puncture:
		var inject := Js.truthy(res.get("inject"))
		var pierces := Js.truthy(res.get("pierces"))
		out.append(["Inyección", "", ("sí · veneno" if pierces else "no perfora") if inject else "no (punción seca)",
			"coral" if inject and pierces else "dim"])
	else:
		out.append(["Longitud", "", "%s mm" % Ui.num(length), "text"])
	return out


## Materiales de la 2.0 junto a la profundidad (bajo carga): la huella que queda al levantar la punta en los no frágiles
## (res.recovery) y la carga con la que la uña cede (res.nail). Vacío con un resultado de la 1.x (esos campos a null).
static func recovery_nail_rows(res: Dictionary) -> Array:
	var out: Array = []
	var rec: Variant = res.get("recovery")
	if rec is Dictionary and res.get("fracture") == null:
		var left: float = res.residualDepthUm
		# el «%» pegado a su número (espacio duro): en la casilla estrecha del teléfono, «%)» quedaba solo en otra línea
		out.append(["Queda al levantar la punta", "Oliver-Pharr", "≈ %s (recupera %s %%)" % [Format.fmt_depth(left),
			Js.to_fixed(float(rec.fraction) * 100.0, 0)], "mint" if left < 0.05 else "text"])
	var nail: Variant = res.get("nail")
	if nail is Dictionary:
		var parts: bool = nail.mode == "parte"
		out.append(["La uña cede a", "σ·Z/L", "≈ %s N (se %s)" % [Format.fmt_f(nail.breakN), "parte" if parts else "dobla"],
			("coral" if parts else "gold") if nail.broken else "dim"])
	return out


## Materiales de la 2.0 tras la hoja de vidrio: las grietas de los frágiles (Hertz o astillado), los vidrios de coche,
## la abolladura y el mellado de una garra frágil. Vacío con un resultado de la 1.x.
static func materials_rows(res: Dictionary) -> Array:
	var out: Array = []
	var fr: Variant = res.get("fracture")
	if fr is Dictionary:
		var txt: String
		var col: String
		match String(fr.mode):
			"hertz":
				txt = "%s desde ≈ %s N" % ["cono" if fr.pattern == "cono" else "herraduras", Format.fmt_f(fr.hertzN)]
				col = "gold"
			"radial":
				txt = "%s ≈ %s" % ["astillado" if fr.pattern == "astillado" else "radiales", Format.fmt_depth(fr.crackUm)]
				col = "coral"
			_:
				txt = ("no (Hertz desde ≈ %s N)" % Format.fmt_f(fr.hertzN)) if fr.harderTool else "no: la punta es más blanda"
				col = "mint"
		out.append(["Grietas", "Hertz · Lawn-Evans", txt, col])
	var gl: Variant = res.get("glazing")
	if gl is Dictionary:
		if gl.kind == "templado":
			out.append(["Estalla por una grieta con", "punta dura", "≈ %s N" % Format.fmt_f(gl.pierceN), "coral" if gl.cause == "grieta" else "dim"])
			out.append(["Trozos al estallar", "Nielsen", "~%s por 5 × 5 cm, de ~%s mm" % [Js.js_num_str(Js.js_round(gl.fragments25)),
				Js.to_fixed(gl.fragmentMm, 1)], "coral" if gl.shattered else "dim"])
		else:
			var pen := Js.to_fixed(gl.penetrationJ, 1)
			var risk: bool = gl.penetrationRisk
			var through_txt := "no (homologado hasta %s J)" % pen
			if risk:
				through_txt = "podría (%s J > %s J)" % [Format.fmt_j(_num(res, "energyJ")), pen]
			out.append(["Atravesarlo", "homologación", through_txt, "coral" if risk else "mint"])
	var dent: Variant = res.get("dent")
	if dent is Dictionary:
		var d: float = dent.depthMm
		var dent_txt := "no (se abolla desde ≈ %s N)" % Format.fmt_f(dent.collapseN)
		if d > 0.0:
			dent_txt = "≈ %s mm" % (Js.to_fixed(d, 2) if d < 1.0 else Js.to_fixed(d, 1))
			if _num(res, "energyJ") > 0.0:
				# la energía que se queda la chapa (la de «Energía que absorbe» es la del agujero en la pintura)
				dent_txt += " (se queda %s J)" % Format.fmt_j(dent.panelJ)
		out.append(["Abolladura", "Jones · Nippon Steel", dent_txt, "coral" if dent.visible else "dim"])
	# 2.0 · la punta afilada de una garra reforjada (unidad 4i): cuánto aguanta de lado frente a lo que le llega. Afilada,
	# esa fila cuenta el mellado (con las resistencias de claw_fracture.gd, en mN si hace falta) en lugar de la de la 1f
	var sharp: Variant = DinoLab.sharpness_row(res)
	var chip: Variant = res.get("tipChip")
	if chip is Dictionary and sharp == null:
		out.append(["La punta se mella con", "de lado", "≈ %s N (lleva ≈ %s N)" % [Format.fmt_f(chip.chipN), Format.fmt_f(chip.lateralN)],
			"coral" if chip.chipped else "dim"])
	if sharp != null:
		out.append(sharp)
	return out


## Biología de la 2.0 (docs/fisica/pulido-biologia.md §9.3): en la piel, la zona, el hueso (a qué profundidad está y si
## la punta lo topa, lo marca o lo atraviesa) y, en una punción que perfora, lo que frena la punta en el punto final (la
## grieta en todas las capas y el roce en los flancos); en un sólido, la punta de esmalte de un colmillo; y el ángulo de
## ataque del ensayo donde cuenta: con la cara que avanza en un sólido y, en la piel, solo con una uña (la flexa). Vacío
## con un resultado de la 1.x.
static func biology_rows(res: Dictionary) -> Array:
	var out: Array = []
	var pen: Variant = res.get("pen")
	if pen is Dictionary:
		out.append(["Zona", "", String(pen.zoneName), "text"])
		out.append(bone_row(res.get("zone"), pen))
		if pen.method == "puncion" and pen.pierces:
			out.append(["Frenan la punta", "grieta + roce", "≈ %s N + %s N" % [Format.fmt_f(pen.crackN), Format.fmt_f(pen.frictionN)], "text"])
	var tip_hv: Variant = res.get("tipHv")
	if tip_hv != null and float(tip_hv) != float(res.hvTool):
		out.append(["Punta de esmalte", "H(a)", "≈ %s HV en el contacto (dentina %s HV)" % [Format.fmt_p(tip_hv), Format.fmt_p(res.hvTool)],
			"gold"])
	var att: Variant = res.get("attackDeg")
	# el ángulo cuenta al rayar un sólido (la cara que avanza decide el modo de abrasión) y, con una uña, siempre (la
	# flexa); una garra que punza o que raya la piel no lo usa (el modelo por capas no tiene modo de abrasión)
	var face: Variant = res.get("faceDeg") if not Js.truthy(res.get("puncture")) else null
	if att != null and (face != null or res.get("nail") is Dictionary):
		var txt := "%s°" % Js.js_num_str(att)
		if face != null:
			txt += " · cara a %s°" % Js.js_num_str(face)
		out.append(["Ángulo de ataque", "θ = ataque − α" if face != null else "", txt, "text"])
	return out


## La fila del hueso de una zona (el informe pen de compute()): dónde está y qué le hace la punta.
static func bone_row(zone: Variant, pen: Dictionary) -> Array:
	var bone: Variant = Zones.bone(zone)
	if bone == null or pen.get("boneDepthUm") == null:
		return ["Hueso", "", "no hay: debajo, la cavidad abdominal", "dim"]
	var head := "%s a %s" % [bone.name, Format.fmt_depth(pen.boneDepthUm)]
	if pen.get("bonePierced") == true:
		return ["Hueso", "", "%s: atraviesa la cortical" % head, "coral"]
	var indent: float = float(pen.get("boneIndentUm", 0.0))
	if indent >= Physics.BONE_MARK_UM:
		return ["Hueso", "", "%s: entra ≈ %s" % [head, Format.fmt_depth(indent)], "coral"]
	if pen.boneHit:
		return ["Hueso", "", "%s: topa con él" % head, "gold"]
	return ["Hueso", "", "%s: no llega" % head, "dim"]


## Las métricas de un aguijón (2.0), con las fuerzas en mN (StingLab.fmt_force; en N solo por encima de 1 N): en la piel,
## perforar y pandear, profundidad, capa, sangre, si se queda clavado (y la autotomía), el anclaje de las púas, el veneno,
## el giro y la inserción; en un sólido, las presiones, la dureza a la escala de la punta y el pandeo. Y en los dos, el
## dolor (Schmidt) y el aleteo. Todo sale de res y de res.sting (Sting.sting_report).
static func sting_metric_rows(res: Dictionary) -> Array:
	var s: Dictionary = res.sting
	var out: Array = []
	var vcol: String = res.vcol
	var depth: float = res.depthUm
	var buckle := ["Pandea a", "Euler" if s.bucklingMode == "euler" else "Johnson", "≈ %s" % StingLab.fmt_force(s.fBuckleN)]
	if Js.truthy(res.get("skin")):
		var pierces: bool = s.pierces == true
		out.append(["Fuerza para perforar", "2·J·R" if s.punctureRegime == "fractura" else "Davis",
			"≈ %s" % StingLab.fmt_force(s.fPunctureN), "coral" if pierces else "mint"])
		out.append(buckle + ["gold" if s.buckled else "dim"])
		out.append(["Profundidad punción", "", "sin herida" if depth <= 0.0 else "≈ %s%s" % [Format.fmt_depth(depth),
			" (tope)" if Js.truthy(res.get("fullReach")) else ""], vcol])
		var layer: Variant = res.get("layer")
		out.append(["Capa alcanzada", "", String(layer) if layer != null else "ninguna", vcol])
		var bleeds := Js.truthy(res.get("bleeds"))
		out.append(["Sangra", "", "sí" if bleeds else "no", "coral" if bleeds else "mint"])
		if pierces:
			out.append(["Se queda clavado", "", _stuck_text(s), "coral" if s.stuck else ("gold" if s.stuckRisk == "a veces" else "mint")])
			if s.stuck and s.engaged and float(s.anchorN) > 0.0:  # las que se quedan: lo que costaría arrancarlo
				out.append(["Anclaje de las púas", "", "≈ %s · %s× su peso" % [StingLab.fmt_force(s.anchorN),
					Js.js_num_str(Js.js_round(s.pullToWeight))], "coral"])
			if s.venomUg != null:
				out.append(["Veneno", "", _venom_text(s), "gold"])
			if s.twistDeg != null:
				out.append(["Giro al entrar", "", "%s° (visto desde la base)" % Js.to_fixed(s.twistDeg, 1), "text"])
			if s.insertionS != null:
				out.append(["Inserción", "lancetas", "%s s" % Js.js_num_str(s.insertionS), "text"])
		out.append(["Inyección", "", "sí · veneno" if pierces else "no perfora", "coral" if pierces else "dim"])
	else:
		out.append_array(BenchTexts.pressure_rows(res))
		out.append(["Profundidad punción", "", "≈ %s" % Format.fmt_depth(depth), vcol])
		var ratio: float = s.hardnessRatio
		out.append(["Ratio dureza", "r (punta)", "%s×" % Js.to_fixed(ratio, 2), "coral" if ratio >= 1.25 else ("gold" if ratio >= 0.8 else "mint")])
		out.append(buckle + ["gold" if Js.truthy(res.get("toolBroken")) else "dim"])
		if Js.truthy(res.get("through")):
			out.append(["Agujero", "", "Ø %s" % Format.fmt_len(_num(res, "grooveWidthUm")), vcol])
		if res.get("paneN") != null:
			out.append(["La hoja se parte con", "", "≈ %s N" % Format.fmt_f(res.paneN), "coral" if Js.truthy(res.get("shattered")) else "mint"])
		if Js.truthy(res.get("paint")) or Js.truthy(res.get("woodDoor")):
			var layer: Variant = res.get("layer")
			out.append(["Capa alcanzada", "", String(layer) if layer != null else "ninguna", vcol])
		var phi: float = res.phi
		out.append(["Contacto plástico", "φ", "%s %%" % Js.to_fixed(phi * 100.0, 0), "mint" if phi < 0.5 else "dim"])
		out.append(["Adhesión vdW", "JKR", "%s mN" % Js.to_fixed(res.Fadh_mN, 2), "text"])
	if s.schmidt != null:
		out.append(["Dolor (Schmidt)", "", "%s de 4" % Js.js_num_str(s.schmidt), "text"])
	if s.wingbeatHz != null:
		out.append(["Aleteo", "", "%s Hz" % Js.js_num_str(s.wingbeatHz), "text"])
	out.append(["Qué cede", "", String(res.get("cede", "")) if res.get("cede") != null else "", "text"])
	return out


## «sí · autotomía» (la abeja se va sin él), «sí», «no (a veces sí)» o «no: lo saca».
static func _stuck_text(s: Dictionary) -> String:
	if s.autotomy:
		return "sí · autotomía"
	if s.stuck:
		return "sí"
	return "no (a veces sí)" if s.stuckRisk == "a veces" else "no: lo saca"


## Veneno de la especie: «~147 µg · 90 % en 20 s, todo en 60 s» (bomba de válvulas) o «~3 µg en ~0.5 s» (el saco se
## exprime mientras dura la picadura).
static func _venom_text(s: Dictionary) -> String:
	var ug := "~%s µg" % Js.js_num_str(s.venomUg)
	if s.pumpT90S != null:
		return "%s · 90 %% en %s s%s" % [ug, Js.js_num_str(s.pumpT90S), (", todo en %s s" % Js.js_num_str(s.pumpTotalS)) if s.pumpTotalS != null else ""]
	if s.pumpTotalS != null:
		return "%s en ~%s s" % [ug, Js.js_num_str(s.pumpTotalS)]
	return ug


static func _num(res: Dictionary, key: String) -> float:
	var v: Variant = res.get(key)
	return float(v) if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) else 0.0
