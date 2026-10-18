## Tarjeta 3 · Parámetros del ensayo (ParamsCard de la 1.x): fuerza (deslizador logarítmico y botón de fuerza
## máxima), método (rayado o punción), golpe, largo, pasadas, tipo de arañazo y modo de garra, con sus notas.
## Los textos con números salen de core (Format y el estado del banco) con los formatos de JavaScript.
## La escala del deslizador es la de la herramienta (Lab.force_range): de 0,5 a 2000 N con las de la 1.x, como siempre,
## y en mN con un aguijón. La fuerza del banco va siempre en N.
## Con un aguijón (2.0) el método es siempre la punción, sin golpe (LabState lo fija): no se enseñan esos selectores, y
## el deslizador lleva dos marcas con su leyenda, la fuerza para perforar la piel y la carga de pandeo (StingLab.marks).
## Ángulo de ataque (2.0; core/lab/attack.gd, docs/fisica/pulido-biologia.md §9.1): de 10° a 170°, y por defecto el de la
## herramienta (45° en las uñas, 90° en garras y colmillos: Physics.attack_deg). Se enseña donde cambia algo: con una uña
## siempre (la flexa, y al rayar un sólido decide el modo de abrasión) y con una garra o un colmillo al rayar un sólido.
extends "res://app/common/card.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const Physics = preload("res://core/lab/physics.gd")
const Attack = preload("res://core/lab/attack.gd")
## De dónde salen la velocidad y la masa del golpe (unidad 4n).
const BenchTexts = preload("res://core/lab/bench_texts.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ContentButton = preload("res://app/common/content_button.gd")
const Pill = preload("res://app/common/pill.gd")
const Segmented = preload("res://app/common/segmented.gd")
const ValueSlider = preload("res://app/common/value_slider.gd")
const AppTheme = preload("res://app/theme/app_theme.gd")
const Palette = preload("res://app/theme/palette.gd")
const ForceMarks = preload("res://app/lab/force_marks.gd")

const PASS_CHIPS := [1, 5, 20, 50, 100]
## Marcas bajo el deslizador con la escala de la 1.x (0,5-2000 N).
const TICKS_N := ["0,5 N", "roce humano", "zarpazo", "2000 N"]

var lab: LabState
var force: ValueSlider
var ticks: Array[Label] = []
var _ticks_for := ""  # escala de las marcas que se ven (unidad|mín|máx)
## Marcas de un aguijón sobre la pista y su leyenda: [fila, muestra de color, texto] por marca.
var marks: ForceMarks
var marks_row: HFlowContainer
var mark_items: Array = []
var max_button: ContentButton
var max_main: Label
var max_note: Label
var method_label: Label
var method_seg: Segmented
var puncture_box: VBoxContainer
var puncture_note: Label
var strike_label: Label
var strike_seg: Segmented
var strike_note: Label
var scratch_box: VBoxContainer
var length: ValueSlider
var passes: ValueSlider
var pass_pills := {}  # n → Pill
var passes_note: Label
var type_seg: Segmented
var claw_box: VBoxContainer
var tear_seg: Segmented
var tear_note: Label
## 2.0 · ángulo de ataque: deslizador, vuelta al de la herramienta y nota.
var attack_box: VBoxContainer
var attack: ValueSlider
var attack_reset: Pill
var attack_note: Label


func _init() -> void:
	super("Parámetros del ensayo", "3")
	force = ValueSlider.new("Fuerza", "(escala log)", 0.0, 1.0, 0.004)
	body.add_child(force)
	marks = ForceMarks.new(force.slider)
	force.slider.add_child(marks)
	var tick_row := Ui.hbox(4)
	for i in 4:
		var t := Ui.label(TICKS_N[i], "Small")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_CENTER,
			HORIZONTAL_ALIGNMENT_RIGHT][i]
		tick_row.add_child(t)
		ticks.append(t)
	body.add_child(tick_row)
	marks_row = Ui.flow(14, 4)
	for i in 2:
		var item := Ui.hbox(6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var text := Ui.label("", "Small")
		item.add_child(text)
		marks_row.add_child(item)
		mark_items.append([item, swatch, text])
	body.add_child(marks_row)
	max_button = ContentButton.new("PillGold", false)
	var col := Ui.vbox(3)
	max_main = Ui.para("", "PillText")
	max_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(max_main)
	max_button.main_labels.append(max_main)
	max_note = Ui.para("", "Small")
	max_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(max_note)
	max_button.set_body(col)
	max_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(Ui.gap(4))
	body.add_child(max_button)
	method_label = Ui.sub_label("Método")
	body.add_child(method_label)
	method_seg = Segmented.new([{ "id": "rayado", "label": "Rayado (arrastre)" }, { "id": "puncion", "label": "Punción / inyección" }],
		"rayado", "Método")
	body.add_child(method_seg)
	puncture_box = Ui.vbox(8)
	puncture_note = Ui.para("", "Note")
	puncture_box.add_child(puncture_note)
	strike_label = Ui.sub_label("Golpe")
	puncture_box.add_child(strike_label)
	strike_seg = Segmented.new([{ "id": "estatico", "label": "Estático" }, { "id": "impacto", "label": "💥 Impacto (golpe)" }],
		"estatico", "Golpe")
	puncture_box.add_child(strike_seg)
	strike_note = Ui.para("", "Note")
	puncture_box.add_child(strike_note)
	body.add_child(puncture_box)
	scratch_box = Ui.vbox(8)
	length = ValueSlider.new("Longitud", "", 5.0, 60.0, 1.0)
	scratch_box.add_child(length)
	passes = ValueSlider.new("Pasadas", "(mismo surco)", 1.0, 100.0, 1.0)
	scratch_box.add_child(passes)
	var chips := Ui.hbox(7)
	for n: int in PASS_CHIPS:
		var p := Pill.new("%s×" % Ui.num(n))
		p.accessibility_name = "%s %s" % [Ui.num(n), "pasada" if n == 1 else "pasadas"]
		p.add_theme_font_override("font", AppTheme.MONO)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chips.add_child(p)
		pass_pills[n] = p
	scratch_box.add_child(chips)
	passes_note = Ui.para("", "Note")
	scratch_box.add_child(passes_note)
	scratch_box.add_child(Ui.sub_label("Tipo de arañazo"))
	var types: Array = []
	for t: Dictionary in Catalog.TYPES:
		types.append({ "id": t.id, "label": t.name })
	type_seg = Segmented.new(types, "aranazo", "Tipo de arañazo")
	scratch_box.add_child(type_seg)
	claw_box = Ui.vbox(8)
	claw_box.add_child(Ui.sub_label("Modo de garra"))
	tear_seg = Segmented.new([{ "id": "arrastre", "label": "Arrastre" }, { "id": "desgarro", "label": "🪝 Desgarro (palanca)" }],
		"arrastre", "Modo de garra")
	claw_box.add_child(tear_seg)
	tear_note = Ui.para("", "Note")
	claw_box.add_child(tear_note)
	scratch_box.add_child(claw_box)
	body.add_child(scratch_box)
	attack_box = Ui.vbox(8)
	attack = ValueSlider.new("Ángulo de ataque", "(90° = de punta)", Attack.MIN_DEG, Attack.MAX_DEG, 1.0)
	attack_box.add_child(attack)
	attack_reset = Pill.new("↺ El de la herramienta", "Pill", false)
	attack_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	attack_box.add_child(attack_reset)
	attack_note = Ui.para("", "Note")
	attack_box.add_child(attack_note)
	body.add_child(attack_box)
	for seg: Segmented in [method_seg, strike_seg, type_seg, tear_seg]:
		_fluid(seg)


## Un selector que ocupa el ancho de la tarjeta y cuyos textos se parten en dos líneas si no caben: en un teléfono de
## 390 px, «Rayado (arrastre) | Punción / inyección» no cabía en una línea y la columna desbordaba 4 px por la derecha
## (lo detectó tests/app/test_layout.gd).
static func _fluid(seg: Segmented) -> void:
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b: Button in seg.buttons.values():
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func setup(p_lab: LabState, _art: ArtCache) -> void:
	lab = p_lab
	force.value_changed.connect(_on_force)
	max_button.pressed.connect(_on_max)
	method_seg.selected.connect(func(id: String) -> void: lab.set_method(id))
	strike_seg.selected.connect(func(id: String) -> void: lab.set_strike(id == "impacto"))
	length.value_changed.connect(_on_length)
	passes.value_changed.connect(_on_passes_slider)
	for n: int in pass_pills:
		(pass_pills[n] as Button).pressed.connect(_on_pass_chip.bind(n))
	type_seg.selected.connect(func(id: String) -> void: lab.set_type(Catalog.find_by_id(Catalog.TYPES, id)))
	tear_seg.selected.connect(func(id: String) -> void: lab.set_tear_mode(id == "desgarro"))
	attack.value_changed.connect(_on_attack)
	attack_reset.pressed.connect(func() -> void: lab.set_attack_deg(null))


## Deslizador logarítmico: la posición t da la fuerza, redondeada a décimas por debajo de 10 N y a unidades
## por encima (setForce de la 1.x).
static func force_from_slider(t: float) -> float:
	var f := Format.t_to_f(t)
	return Js.js_round(f * 10.0) / 10.0 if f < 10.0 else Js.js_round(f)


## Lo mismo en la escala r de una herramienta (Lab.force_range). Con la de la 1.x es force_from_slider; en mN, la
## fuerza se redondea a centésimas de mN por debajo de 1 mN, a décimas hasta 10 mN y a unidades por encima.
static func force_from_slider_in(t: float, r: Dictionary) -> float:
	if r.unit == "N" and r.min == Format.FMIN and r.max == Format.FMAX:
		return force_from_slider(t)
	var f := Format.t_to_f_in(t, r.min, r.max)
	if r.unit != "mN":
		return Js.js_round(f * 10.0) / 10.0 if f < 10.0 else Js.js_round(f)
	var mn := f * 1000.0
	var nice := Js.js_round(mn)
	if mn < 1.0:
		nice = Js.js_round(mn * 100.0) / 100.0
	elif mn < 10.0:
		nice = Js.js_round(mn * 10.0) / 10.0
	return clampf(nice / 1000.0, r.min, r.max)


## Marcas bajo el deslizador en la escala r: las de la 1.x o, en mN, los extremos y dos décadas intermedias.
static func tick_texts(r: Dictionary) -> Array:
	if r.unit != "mN":
		return TICKS_N
	var lo := Js.log10(r.min)
	var hi := Js.log10(r.max)
	var out: Array = []
	for k in 4:
		var e := lo + (hi - lo) * k / 3.0
		var v: float = r.min if k == 0 else (r.max if k == 3 else pow(10.0, roundf(e)))
		out.append("%s mN" % Js.js_num_str(Js.js_round(v * 1e5) / 100.0).replace(".", ","))
	return out


func _on_force(t: float) -> void:
	var f := force_from_slider_in(t, lab.force_range())
	if f != lab.force:
		lab.set_force(f)


func _on_max() -> void:
	var f: float = lab.max_f().force
	if f != lab.force:
		lab.set_force(f)


func _on_length(v: float) -> void:
	var l := Js.js_round(v)
	if l != lab.length:
		lab.set_length(l)


func _on_passes_slider(v: float) -> void:
	var n := Js.js_round(v)
	if n != lab.passes:
		lab.set_passes_slider(n)


## El ángulo del deslizador, en grados enteros; mover el deslizador fija el ángulo aunque coincida con el de la herramienta.
func _on_attack(v: float) -> void:
	var a := Js.js_round(v)
	if lab.attack_deg == null or a != float(lab.attack_deg):
		lab.set_attack_deg(a)


func _on_pass_chip(n: int) -> void:
	if float(n) == lab.passes:
		refresh()
		return
	lab.set_passes(float(n))


func refresh() -> void:
	var claw: Variant = lab.claw
	var tool: Dictionary = lab.tool()
	var r: Dictionary = lab.force_range()
	var mn: bool = r.unit == "mN"
	var spoken := ("%s milinewtons" % Format.fmt_mn(lab.force)) if mn else ("%s newtons" % Format.fmt_f(lab.force))
	force.set_value(Format.f_to_t_in(lab.force, r.min, r.max), Format.fmt_force(lab.force, r.unit), spoken)
	var ticks_for := "%s|%s|%s" % [r.unit, r.min, r.max]
	if ticks_for != _ticks_for:
		_ticks_for = ticks_for
		var texts := tick_texts(r)
		for i in ticks.size():
			ticks[i].text = texts[i]
	var mf: Dictionary = lab.max_f()
	# en la letra de los botones (Syne), la virgulilla sale como un punto o un guion corto («· ·300 N»): «unos 300 N»
	max_main.text = "⤓ Usar fuerza MÁX. %s · unos %s" % [mf.label, Format.fmt_force(mf.force, "mN") if mn else "%s N" % Ui.num(mf.force)]
	max_note.text = String(mf.note)
	# su texto va en etiquetas dentro del botón: el nombre para los lectores de pantalla, aparte (4q)
	max_button.accessibility_name = "%s. %s" % [max_main.text.trim_prefix("⤓ "), max_note.text]
	var sting := lab.is_stinger()
	_refresh_marks(r)
	# un aguijón solo pica: sin selector de método ni de golpe (LabState fija la punción estática)
	method_label.visible = not sting
	method_seg.visible = not sting
	strike_label.visible = not sting
	strike_seg.visible = not sting
	strike_note.visible = not sting
	method_seg.set_value(lab.method)
	var puncture := lab.method == "puncion"
	puncture_box.visible = puncture
	scratch_box.visible = not puncture
	if puncture and sting:
		puncture_note.text = "Un aguijón solo pica: la punta entra recta, sin arrastre ni golpe, y luego las lancetas lo llevan dentro por turnos. Es hueco: inyecta veneno. Nada entra más que su longitud útil: aquí, ≤ %s mm." % Ui.num(tool.reach)
	elif puncture:
		var fang := claw != null and Js.truthy(claw.get("fang"))
		var what := "uña libre"
		if claw != null:
			what = "aguja" if fang else "garra"
		puncture_note.text = "Penetración vertical, sin arrastre: la punta entra recta. %s Nada se hunde más que su propia %s: aquí, ≤ %s mm." % [
			"El colmillo, además, es hueco → inyecta veneno en el tejido." if fang else "Solo los colmillos inyectan; el resto hace punción seca.",
			what, Ui.num(tool.reach)]
	if puncture:
		strike_seg.set_value("impacto" if lab.strike else "estatico")
		if lab.strike:
			strike_note.text = ("Golpe dinámico: ½·m·v² ≈ %s J (%s m/s, %s kg efectivos %s) + el trabajo del empuje = trabajo de penetración. Velocidad y masa: %s."
				% [Format.fmt_j(lab.strike_j()), _short_num(float(tool.strike.v)), _short_num(float(tool.strike.m)), "por garra" if claw != null else "del dedo",
				BenchTexts.strike_origin(claw)])
		else:
			strike_note.text = "Empuje cuasi-estático (equilibrio de fuerzas): conservador. Cambia a Impacto para una mordedura, patada o zarpazo real."
	else:
		length.set_value(lab.length, "%s mm" % Ui.num(lab.length), "%s milímetros" % Ui.num(lab.length))
		passes.set_value(lab.passes, "%s×" % Ui.num(lab.passes), "%s pasadas" % Ui.num(lab.passes))
		for n: int in pass_pills:
			(pass_pills[n] as Pill).set_on(float(n) == lab.passes)
		passes_note.visible = lab.passes > 1.0
		passes_note.text = ("Arañar %s veces en la misma línea profundiza ×%s (sublineal: cada pasada arranca menos). Si la herramienta no marca ni una vez, mil pasadas tampoco: solo se desgasta la punta."
			% [Ui.num(lab.passes), Js.to_fixed(lab.pass_factor(), 1)])
		type_seg.set_value(lab.type.id)
		claw_box.visible = claw != null
		if claw != null:
			tear_seg.set_value("desgarro" if lab.tear_mode else "arrastre")
			tear_note.text = ("Gancho + palanca: la garra curva rasga en vez de arrastrar. Ventaja mecánica ×%s en la punta."
				% Js.to_fixed(lab.tear_lever(), 1)) if lab.tear_mode else "Arrastre liso (como una uña). Cambia a Desgarro para que la curvatura haga palanca."
	_refresh_attack()


## ¿Se enseña el ángulo de ataque? Solo en la 2.0 y donde cambia algo: con una uña (la flexa) y, con una garra o un
## colmillo, al rayar un sólido (el modo de abrasión; en la piel, el modelo por capas no lo usa). Un aguijón solo pica.
func attack_shown() -> bool:
	if lab.model != Physics.MODEL_V2 or lab.is_stinger():
		return false
	return lab.claw == null or (lab.method == "rayado" and not Physics.truthy(lab.target.get("skin")))


func _refresh_attack() -> void:
	var shown := attack_shown()
	attack_box.visible = shown
	if not shown:
		return
	var a: float = lab.attack()
	attack.set_value(a, "%s°" % Js.js_num_str(a), "%s grados" % Js.js_num_str(a))
	attack_reset.visible = lab.attack_deg != null
	var d: Dictionary = lab.attack_default()
	var own := "%s°, estimación" % Js.js_num_str(d.value)
	if lab.claw == null:
		attack_note.text = ("Entre la placa de la uña y la superficie, hacia donde avanza (por defecto %s: nadie lo ha medido al rayar; lo más parecido medido son las posturas del dedo en una pantalla táctil, de 15° a 90°: Holz y Baudisch 2010). El mismo ángulo decide cuánto se dobla la uña (la carga normal y el roce la flexan) y si la cara que avanza ara, hace cuña o corta (Hokkirigawa y Kato 1988; Challen y Oxley 1979)."
			% own)
	else:
		attack_note.text = ("Entre el eje de la punta y la superficie, hacia donde avanza (por defecto de punta, %s: la geometría de la 1.x; nadie ha medido con qué ángulo ataca una garra, es una pregunta abierta). Tumbada, la cara que avanza ara; de gancho (más de 90°), clava y corta (Challen y Oxley 1979; Sedriks y Mulhearn 1963). El surco mide lo mismo: cambia cómo se arranca el material."
			% own)


## Marcas de un aguijón en el deslizador y su leyenda (§7.5): la fuerza para perforar la piel (solo si el objetivo es
## piel) y la carga de pandeo en su material; sin aguijón, ninguna.
func _refresh_marks(r: Dictionary) -> void:
	var m: Dictionary = lab.sting_marks()
	var list: Array = []  # [fuerza (N), color, texto]
	if not m.is_empty():
		if m.puncture != null:
			list.append([m.puncture, "coral", "perfora la piel · ~%s" % StingLab.fmt_force(m.puncture)])
		list.append([m.buckle, "gold", "pandea · ~%s" % StingLab.fmt_force(m.buckle)])
	marks.set_marks(list.map(func(x: Array) -> Array: return [Format.f_to_t_in(x[0], r.min, r.max), Palette.color(x[1])]))
	marks_row.visible = not list.is_empty()
	for i in mark_items.size():
		var item: Array = mark_items[i]
		(item[0] as Control).visible = i < list.size()
		if i < list.size():
			var c := Palette.color(list[i][1])
			(item[1] as ColorRect).color = c
			(item[2] as Label).text = list[i][2]
			Ui.set_color(item[2], c)


## Un número de la nota del golpe con tres cifras como mucho («4.84», «7.55», «12», «0.08»): la velocidad y la masa corregidas
## de la 2.0 salen de cuentas y se enseñaban con todos sus decimales («4.839918240611507 m/s»).
static func _short_num(x: float) -> String:
	if x == 0.0 or absf(x) >= 100.0:
		return Js.js_num_str(Js.js_round(x))
	var digits := clampi(2 - int(floor(log(absf(x)) / log(10.0))), 0, 3)
	var k := pow(10.0, float(digits))
	return Js.js_num_str(Js.js_round(x * k) / k)
