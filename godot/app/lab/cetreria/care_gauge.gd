## Cetrería · el indicador de la forma de la garra en directo (unidad 5h, petición 35), sobre la vista 3D: la silueta de
## perfil de la garra de ahora (rellena) frente a la forma natural sana (a trazos), con la carne viva si se ve y la punta
## marcada, y las lecturas del estado: la punta, el largo que queda, la distancia a la carne viva, la faceta y lo que
## aguanta, con su tono, y si va bien o mal. No calcula nada: los números y los tonos son los de ClawCareState
## (view().readouts; el veredicto, la forma en directo del motor, snapshot().shape, salvo si la garra está rota o
## sangra), y la silueta es el perfil del motor dibujado de lado. Se repinta solo cuando cambia la vista. El botón
## enciende o apaga la silueta fantasma de la forma sana en la escena (señal ghost_toggled).
extends PanelContainer

signal ghost_toggled(on: bool)

const Palette = preload("res://app/theme/palette.gd")
const ClawMesh = preload("res://app/lab/cetreria/claw_mesh.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-400-normal.woff2")
const FONT_BOLD = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## Las lecturas que se enseñan (ids de ClawCareState.readouts), en orden; en el teléfono, solo las dos primeras y sin la
## silueta (la vista es pequeña: la garra de la escena es la forma). Con su nota (lo natural) solo las que la tienen corta.
const ROWS := ["punta", "sobrante", "carne", "faceta", "aguante"]
const WITH_NOTE := ["punta", "faceta"]
const ROWS_PHONE := ["punta", "sobrante"]
const TONE := { "bien": "mint", "aviso": "gold", "mal": "coral", "": "text" }
## El veredicto, por el peor tono de las lecturas (si el motor no da el suyo).
const VERDICT := { "mal": "Va mal", "aviso": "Mejorable", "bien": "Va bien", "": "Va bien" }
## Ancho del indicador (px) en escritorio y en el teléfono.
const WIDTH := 270.0
const WIDTH_PHONE := 160.0

var compact := false
var _sil: Control
var _rows: VBoxContainer
var _labels := {}
var _verdict: Label
var _ghost_btn: Button
var _title: Label
var _key := ""
## La silueta: polígonos en el plano de la curva (mm), ya listos para dibujar.
var _cur := PackedVector2Array()
var _nat := PackedVector2Array()
var _quick := PackedVector2Array()
var _tip := Vector2.ZERO
var _box := Rect2()
var _claw_col := Color(0.2, 0.18, 0.16)


func _init() -> void:
	name = "FormaDeLaGarra"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.09, 0.72)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = _label("Forma de la garra", 13, "text", true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_ghost_btn = Button.new()
	_ghost_btn.toggle_mode = true
	_ghost_btn.text = "Forma sana (F)"
	_ghost_btn.tooltip_text = "Enseña u oculta la silueta de la forma natural sana de la garra (tecla F)"
	_ghost_btn.focus_mode = Control.FOCUS_NONE
	_ghost_btn.add_theme_font_override("font", FONT)
	_ghost_btn.add_theme_font_size_override("font_size", 11)
	_ghost_btn.toggled.connect(func(on: bool) -> void: ghost_toggled.emit(on))
	head.add_child(_ghost_btn)
	_sil = Control.new()
	_sil.custom_minimum_size = Vector2(WIDTH, 96.0)
	_sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sil.draw.connect(_draw_silhouette)
	col.add_child(_sil)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows)
	for id: String in ROWS:
		var l := _label("", 11, "text", false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
		_rows.add_child(l)
		_labels[id] = l
	_verdict = _label("", 13, "mint", true)
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict.custom_minimum_size.x = WIDTH
	col.add_child(_verdict)


func _label(t: String, size: int, tone: String, bold: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.color(tone))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## El teléfono: más pequeño y con menos lecturas.
func set_compact(on: bool) -> void:
	compact = on
	var w := WIDTH_PHONE if on else WIDTH
	_sil.custom_minimum_size = Vector2(w, 96.0)
	_sil.visible = not on
	for id: String in ROWS:
		(_labels[id] as Label).visible = not on or ROWS_PHONE.has(id)
		(_labels[id] as Label).add_theme_font_size_override("font_size", 10 if on else 11)
		(_labels[id] as Label).custom_minimum_size.x = w
	_verdict.custom_minimum_size.x = w
	_title.add_theme_font_size_override("font_size", 11 if on else 13)
	_ghost_btn.text = "Forma sana" if on else "Forma sana (F)"
	_key = ""


func set_ghost(on: bool) -> void:
	_ghost_btn.set_pressed_no_signal(on)


## Pinta la vista de ClawCareState (sin cuentas: sus textos y su perfil). Barata si no ha cambiado la forma ni las lecturas.
func show_view(v: Dictionary) -> void:
	if v.is_empty():
		return
	var rows := {}
	for r: Dictionary in v.get("readouts", []):
		rows[String(r.id)] = r
	var sn: Dictionary = v.snap
	var shape: Variant = sn.get("shape", v.get("shape"))
	var sh: Dictionary = shape if shape is Dictionary else {}
	var dmg: Dictionary = sn.get("damage", {})
	var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [ClawMesh.geometry_key(v), str(rows.get("punta", {}).get("value", "")),
		str(rows.get("carne", {}).get("value", "")), str(rows.get("aguante", {}).get("value", "")), String(sh.get("title", "")),
		String(sh.get("text", "")), str(dmg.get("broken", false)), str(sn.get("bleeding", {}).get("active", false))]
	if key == _key:
		return
	_key = key
	var worst := ""
	for id: String in ROWS:
		var l: Label = _labels[id]
		var r: Dictionary = rows.get(id, {})
		l.visible = not r.is_empty() and (not compact or ROWS_PHONE.has(id))
		if r.is_empty():
			continue
		var tone := String(r.get("tone", ""))
		var note := String(r.note) if WITH_NOTE.has(id) and not compact else ""
		l.text = "%s: %s%s" % [String(r.label), String(r.value), (" · " + note) if note != "" else ""]
		l.add_theme_color_override("font_color", Palette.color(String(TONE.get(tone, "text"))))
		if tone == "mal" or (tone == "aviso" and worst != "mal") or (tone == "bien" and worst == ""):
			worst = tone
	# el veredicto: rota o sangrando (lo dice el motor, y corre más prisa); si no, la forma en directo del motor (su título
	# y, en el escritorio, su explicación); si no, el peor tono de las lecturas
	if bool(dmg.get("broken", false)) and not bool(dmg.get("repaired", false)):
		_verdict.text = "Va mal: garra rota (hay que reconstruirla)"
		worst = "mal"
	elif bool(sn.get("bleeding", {}).get("active", false)):
		_verdict.text = "Va mal: sangra (para la sangre)"
		worst = "mal"
	elif sh.has("title"):
		var why := String(sh.get("text", ""))
		_verdict.text = String(sh.title) + ((". " + why) if why != "" and not compact else "")
		worst = String(sh.get("tone", worst))
	else:
		var bad := ""
		for id: String in ROWS:
			var r2: Dictionary = rows.get(id, {})
			if String(r2.get("tone", "")) == worst and worst in ["mal", "aviso"]:
				bad = String(r2.label).to_lower()
				break
		_verdict.text = String(VERDICT.get(worst, "Va bien")) + ((": " + bad) if bad != "" else "")
	_verdict.add_theme_color_override("font_color", Palette.color(String(TONE.get(worst, "mint"))))
	if not compact:
		_build_silhouette(v, sn)
		_sil.queue_redraw()


## La silueta de perfil: el borde de arriba (la cara dorsal) y el de abajo, con el alto de la sección de la garra (la de la
## malla: ClawMesh.section_of), a lo largo de la línea media, en el plano de la curva.
func _build_silhouette(v: Dictionary, sn: Dictionary) -> void:
	var k := ClawMesh.claw_curvature(sn.claw)
	var sec := ClawMesh.section_of(v)
	# el alto de cada cara, el de la sección (con la medida del motor, el alto de la garra sale de k y del área)
	var top := float(sec.get("h", 1.0))
	var bottom := top * float(sec.b)
	_cur = _outline(sn.profile.s, sn.profile.r, k, top, bottom)
	var nat := ClawMesh.natural_profile(v)
	_nat = _outline(nat.s, nat.r, k, top, bottom) if nat.has("s") else PackedVector2Array()
	var revealed := bool(v.get("hints", {}).get("revealed", false))
	_quick = _outline(sn.profile.s, sn.profile.core, k, top, top) if revealed else PackedVector2Array()
	var apex := float(sn.claw.lengthMm)
	var tp := ClawMesh.point_at(apex, k)
	_tip = Vector2(tp.x, tp.y)
	_claw_col = Color(String(sn.claw.color))
	var box := Rect2()
	var first := true
	for poly: PackedVector2Array in [_cur, _nat]:
		for p in poly:
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	_box = box


static func _outline(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, top_k: float, bottom: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := mini(ss.size(), rs.size())
	var stride := maxi(n / 60, 1)
	for i in range(0, n, stride):
		var p := ClawMesh.point_at(ss[i], k)
		var u := ClawMesh.up_at(ss[i], k)
		var r := maxf(rs[i], 0.0)
		top.append(Vector2(p.x + u.x * r * top_k, p.y + u.y * r * top_k))
		bot.append(Vector2(p.x - u.x * r * bottom, p.y - u.y * r * bottom))
	if n > 0 and (n - 1) % stride != 0:
		var p2 := ClawMesh.point_at(ss[n - 1], k)
		var u2 := ClawMesh.up_at(ss[n - 1], k)
		var r2 := maxf(rs[n - 1], 0.0)
		top.append(Vector2(p2.x + u2.x * r2 * top_k, p2.y + u2.y * r2 * top_k))
		bot.append(Vector2(p2.x - u2.x * r2 * bottom, p2.y - u2.y * r2 * bottom))
	var out := PackedVector2Array(top)
	for i in range(bot.size() - 1, -1, -1):
		out.append(bot[i])
	return out


func _draw_silhouette() -> void:
	if _cur.size() < 3 or _box.size.x <= 0.0:
		return
	var area := Rect2(Vector2(4.0, 4.0), _sil.size - Vector2(8.0, 8.0))
	var sc := minf(area.size.x / maxf(_box.size.x, 1e-3), area.size.y / maxf(_box.size.y, 1e-3))
	var off := area.position + (area.size - _box.size * sc) * 0.5
	# en la pantalla, y hacia abajo: la garra se curva hacia abajo como en la escena
	var map := func(p: Vector2) -> Vector2: return off + Vector2(p.x - _box.position.x, _box.end.y - p.y) * sc
	var cur := PackedVector2Array()
	for p in _cur:
		cur.append(map.call(p))
	var fill := _claw_col.lightened(0.25)
	fill.a = 0.95
	if Geometry2D.triangulate_polygon(cur).size() >= 3:
		_sil.draw_colored_polygon(cur, fill)
	var closed := PackedVector2Array(cur)
	closed.append(cur[0])
	_sil.draw_polyline(closed, Palette.color("text"), 1.2, true)
	if _quick.size() >= 3:
		var q := PackedVector2Array()
		for p in _quick:
			q.append(map.call(p))
		if Geometry2D.triangulate_polygon(q).size() >= 3:
			_sil.draw_colored_polygon(q, Color(Palette.color("coral"), 0.75))
	if _nat.size() >= 3:
		var nat := PackedVector2Array()
		for p in _nat:
			nat.append(map.call(p))
		nat.append(nat[0])
		for i in nat.size() - 1:
			if i % 3 != 2:
				_sil.draw_line(nat[i], nat[i + 1], Color(Palette.color("mint"), 0.9), 1.4, true)
	_sil.draw_circle(map.call(_tip), 2.6, Palette.color("ice"))
