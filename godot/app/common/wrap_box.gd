## Caja que pone sus hijos en fila si caben y, si no, uno debajo de otro: el flex-wrap de la 1.x para dos o tres
## bloques (cabecera de tarjeta, barra superior, vista previa de la herramienta, columnas del modo dual).
## - En fila: los hijos con SIZE_EXPAND se reparten el sitio que sobra (según su stretch_ratio); si `equal`, todos
##   miden lo mismo. Centrados en vertical, o arriba si `align_top`.
## - En columna: los hijos con SIZE_FILL ocupan todo el ancho; el resto, su ancho mínimo, a la izquierda.
## Su ancho mínimo es el del hijo más ancho (el de la columna), así nunca obliga a desbordar la ventana.
## Uso: const WrapBox = preload("res://app/common/wrap_box.gd"); var w := WrapBox.new(12.0)
extends Container

var gap := 12.0
var vgap := 10.0
## Ancho a partir del cual va en fila (0 = la suma de los anchos mínimos de los hijos y los huecos).
var row_min := 0.0
var equal := false
var align_top := false
var is_row := true
var _min_h := 0.0


func _init(p_gap := 12.0, p_vgap := 10.0) -> void:
	gap = p_gap
	vgap = p_vgap


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _shown() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and (c as Control).visible and not (c as Control).top_level:
			out.append(c)
	return out


func _sort() -> void:
	var kids := _shown()
	if kids.is_empty():
		return
	var items: Array = []
	for k in kids:
		items.append({
			"min": k.get_combined_minimum_size(), "expand": bool(k.size_flags_horizontal & Control.SIZE_EXPAND),
			"ratio": k.size_flags_stretch_ratio, "fill": bool(k.size_flags_horizontal & Control.SIZE_FILL),
			"end": bool(k.size_flags_horizontal & Control.SIZE_SHRINK_END), "fill_v": bool(k.size_flags_vertical & Control.SIZE_FILL),
		})
	var out := arrange(size.x, items, gap, vgap, row_min, equal, align_top)
	is_row = out.row
	var rects: Array = out.rects
	for i in kids.size():
		fit_child_in_rect(kids[i], rects[i])
	var h: float = out.height
	if absf(h - _min_h) > 0.5:
		_min_h = h
		update_minimum_size()


## Disposición (función pura). items: [{ min: Vector2, expand, ratio, fill, end, fill_v }]. Devuelve
## { row: bool, rects: [Rect2], height }.
static func arrange(width: float, items: Array, p_gap: float, p_vgap: float, p_row_min: float, p_equal: bool,
		p_align_top: bool) -> Dictionary:
	var n := items.size()
	var need := p_row_min
	if need <= 0.0:
		need = p_gap * maxi(n - 1, 0)
		for it: Dictionary in items:
			need += (it.min as Vector2).x
	var row := width + 0.5 >= need
	var rects: Array = []
	var h := 0.0
	if row:
		var widths: Array[float] = []
		var free := width - p_gap * (n - 1)
		var ratio_sum := 0.0
		for it: Dictionary in items:
			widths.append((it.min as Vector2).x)
			free -= (it.min as Vector2).x
			if p_equal or it.expand:
				ratio_sum += float(it.ratio)
		if p_equal:
			var w := (width - p_gap * (n - 1)) / n
			for i in n:
				widths[i] = maxf(w, widths[i])
		elif ratio_sum > 0.0 and free > 0.0:
			for i in n:
				if items[i].expand:
					widths[i] += free * float(items[i].ratio) / ratio_sum
		for it: Dictionary in items:
			h = maxf(h, (it.min as Vector2).y)
		var x := 0.0
		for i in n:
			var kh: float = (items[i].min as Vector2).y
			var y := 0.0 if p_align_top else floorf((h - kh) / 2.0)
			var tall: bool = items[i].fill_v and p_align_top
			rects.append(Rect2(x, y, widths[i], h if tall else kh))
			x += widths[i] + p_gap
	else:
		var y := 0.0
		for i in n:
			var it: Dictionary = items[i]
			var ms: Vector2 = it.min
			var w := width if it.fill else minf(ms.x, width)
			var x := width - w if (not it.fill and it.end) else 0.0
			rects.append(Rect2(x, y, w, ms.y))
			y += ms.y
			if i < n - 1:
				y += p_vgap
		h = y
	return { "row": row, "rects": rects, "height": h }


func _get_minimum_size() -> Vector2:
	var w := 0.0
	for k in _shown():
		w = maxf(w, k.get_combined_minimum_size().x)
	return Vector2(w, _min_h)
