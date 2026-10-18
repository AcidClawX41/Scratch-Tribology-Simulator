## Piezas de la interfaz del laboratorio que se repiten en varias tarjetas: fichas con ilustración (Tile de la 1.x),
## vistas de dibujo, pares «clave valor» (Stat) y las claves de caché de cada ilustración (las mismas entradas que
## el memoArt de la 1.x: si no cambian, no se vuelve a rasterizar).
extends RefCounted

const Art = preload("res://core/lab/art.gd")
const ArtInsects = preload("res://core/lab/art_insects.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")
const Insects = preload("res://core/lab/insects.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Ui = preload("res://app/common/ui.gd")
const ArtView = preload("res://app/common/art_view.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ContentButton = preload("res://app/common/content_button.gd")

const CLAW_VIEW := Rect2(0, 0, 100, 132)
const NAIL_VIEW := Rect2(0, 0, 100, 168)
const NAIL_SIDE_VIEW := Rect2(-122, -80, 132, 98)
const GEM_VIEW := Rect2(0, 0, 20, 20)
## Lo más pequeño que se encoge el nombre de una ficha para que quepa su palabra más larga.
const TILE_LABEL_MIN := 10


## Vista de dibujo de tamaño fijo (w × h px lógicos); w = 0 ocupa todo el ancho.
static func view(size: Vector2) -> ArtView:
	var v := ArtView.new()
	v.custom_minimum_size = size
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL if size.x <= 0.0 else Control.SIZE_SHRINK_CENTER
	return v


## Ficha (.tile): ilustración de art_size (x = 0: todo el ancho), nombre y, si se da, un subtítulo.
static func tile(art_size: Vector2, label: String, sub := "", tip := "") -> ContentButton:
	var b := ContentButton.new("Tile")
	var col := Ui.vbox(5)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var art := view(art_size)
	col.add_child(art)
	var name := Ui.label(label, "TileLabel")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# entre palabras, nunca a mitad de una; si la más larga no cabe («Velocirraptor», «Guacamayo»), se encoge
	name.autowrap_mode = TextServer.AUTOWRAP_WORD
	name.custom_minimum_size.x = 30.0
	name.resized.connect(func() -> void: fit_tile_label(name))
	name.theme_changed.connect(func() -> void: fit_tile_label(name))
	col.add_child(name)
	b.main_labels.append(name)
	if sub != "":
		var s := Ui.label(sub, "TileSub")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size.x = 30.0
		col.add_child(s)
		b.sub_labels.append(s)
	b.set_body(col)
	b.tooltip_text = tip
	b.accessibility_name = label
	b.set_meta("art", art)
	return b


## La vista de dibujo de una ficha.
static func tile_art(b: Control) -> ArtView:
	return b.get_meta("art")


## El nombre de una ficha cuya palabra más larga no cabe en su ancho se salía por los lados de la ficha («Velocirraptor»
## y «Guacamayo», sobre todo en el teléfono): se encoge lo justo, hasta TILE_LABEL_MIN px. Con sitio, vuelve al del tema.
static func fit_tile_label(l: Label) -> void:
	var w := l.size.x
	var base := _theme_font_size(l)
	if w <= 1.0 or base <= 0:
		return
	var font := l.get_theme_font(&"font")
	var fs := base
	while fs > TILE_LABEL_MIN and _longest_word(font, l.text, fs) > w:
		fs -= 1
	if fs == base:
		if l.has_theme_font_size_override(&"font_size"):
			l.remove_theme_font_size_override(&"font_size")
	elif fs != l.get_theme_font_size(&"font_size"):
		l.add_theme_font_size_override(&"font_size", fs)


## El tamaño de letra de la etiqueta en el tema del programa, sin la sobrescritura de fit_tile_label (0 si aún no
## cuelga de un control con tema: el primer tamaño que veía era el de Godot, 16 px, y unas fichas quedaban más grandes).
static func _theme_font_size(l: Control) -> int:
	var n: Node = l
	while n != null:
		var c := n as Control
		if c != null and c.theme != null and c.theme.has_font_size(&"font_size", l.theme_type_variation):
			return c.theme.get_font_size(&"font_size", l.theme_type_variation)
		n = n.get_parent()
	return 0


static func _longest_word(font: Font, text: String, fs: int) -> float:
	var out := 0.0
	for word in text.split(" ", false):
		out = maxf(out, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return out


## Par «clave valor» de la ficha de la herramienta (Stat de la 1.x): clave en dimmer y valor en menta.
static func stat() -> HBoxContainer:
	var h := Ui.hbox(5)
	h.add_child(Ui.label("", "StatKey"))
	h.add_child(Ui.label("", "StatVal"))
	return h


## Un valor más ancho que STAT_WRAP_PX («~382 N (193–1130)» en el velocirraptor de cine) salta de línea a ese ancho: en una
## sola línea, la ficha ensanchaba la página del teléfono más que la pantalla.
const STAT_WRAP_PX := 220.0


static func set_stat(h: HBoxContainer, k: String, v: String) -> void:
	(h.get_child(0) as Label).text = k
	var val := h.get_child(1) as Label
	val.text = v
	var w := val.get_theme_font(&"font").get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, val.get_theme_font_size(&"font_size")).x
	if w > STAT_WRAP_PX:
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.custom_minimum_size.x = STAT_WRAP_PX
	else:
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.custom_minimum_size.x = 0.0


# ── Ilustraciones (clave de caché, constructor y vista) ──

## Garra o colmillo (ClawIcon de la 1.x) o, si es un aguijón, el insecto con su aguijón (ArtInsects): en la ficha de la
## herramienta (lupa = true), con una lupa que aumenta la punta y sus púas.
static func show_claw(v: ArtView, cache: ArtCache, claw: Dictionary, inlay: Variant, uid: String, tip_color: Variant = null,
		lupa := false) -> void:
	var key := "ci:%s:%s:%s:%s" % [uid, claw.id, inlay.id if inlay != null else "-", tip_color]
	var o := { "inlay": inlay, "tipColor": tip_color, "uid": uid }
	if Insects.is_stinger(claw):
		o.lupa = lupa
		v.set_art(cache, key + (":lupa" if lupa else ""), ArtInsects.insect_icon_art.bind(claw, o), CLAW_VIEW, null)
	else:
		v.set_art(cache, key, Art.claw_art.bind(claw, o), CLAW_VIEW, [])
	v.accessibility_name = Catalog.claw_title(claw)


## Uña de frente (NailFront).
static func show_nail(v: ArtView, cache: ArtCache, geom: Dictionary, base: Dictionary, inlay: Dictionary, wet: bool, uid: String) -> void:
	var key := "nf:%s:%s:%s:%s:%s" % [uid, geom.id, base.id, inlay.id, wet]
	var o := { "geom": geom, "base": base, "inlay": inlay, "wet": wet, "uid": uid }
	v.set_art(cache, key, Art.nail_art.bind(o), NAIL_VIEW, [])
	v.accessibility_name = "Uña %s de %s" % [String(geom.name).to_lower(), String(base.name).to_lower()]


## Uña de perfil (NailSide).
static func show_nail_side(v: ArtView, cache: ArtCache, geom: Dictionary, base: Dictionary, inlay: Dictionary, wet: bool, uid: String) -> void:
	var key := "ns:%s:%s:%s:%s:%s" % [uid, geom.id, base.id, inlay.id, wet]
	var o := { "geom": geom, "base": base, "inlay": inlay, "wet": wet, "uid": uid }
	v.set_art(cache, key, Art.nail_side_art.bind(o), NAIL_SIDE_VIEW, [])
	v.accessibility_name = "Vista lateral de la uña"


## Muestra de material (MaterialSwatch): 120 × 34, detalle 0,7. Los vidrios de coche de la 2.0, con su aspecto de vidrio.
static func show_swatch(v: ArtView, cache: ArtCache, target: Dictionary) -> void:
	var uid := "tg%s" % target.id
	var o := { "w": 120.0, "h": 34.0, "uid": uid, "detail": 0.7, "rx": 7.0 }
	v.set_art(cache, "sw:%s:120x34:0.7" % uid, ArtMaterials.surface_art.bind(target.id, o), Rect2(0, 0, 120, 34), [])


## Gema o tachuela (GemIcon).
static func show_gem(v: ArtView, cache: ArtCache, inlay: Dictionary) -> void:
	v.set_art(cache, "gem:%s" % inlay.id, Art.gem_art.bind(inlay, 10.0, 10.0, 8.0, "gi"), GEM_VIEW, [])
