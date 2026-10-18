## Rejilla de fichas como `grid-template-columns: repeat(auto-fill, minmax(min_col, 1fr))` de la 1.x: tantas columnas
## como quepan de al menos min_col px, que se reparten el ancho; cada fila, tan alta como su ficha más alta. Los hijos
## ocultos no ocupan sitio. Sirve igual en la ventana de escritorio y en el teléfono.
## Uso: const TileGrid = preload("res://app/common/tile_grid.gd"); var g := TileGrid.new(74.0)
extends Container

var min_col := 74.0
var gap := 8.0
var row_gap := 8.0
var _min_h := 0.0


func _init(p_min_col := 74.0, p_gap := 8.0) -> void:
	min_col = p_min_col
	gap = p_gap
	row_gap = p_gap
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Columnas que caben en un ancho (al menos una).
func columns_for(width: float) -> int:
	return maxi(1, int(floor((width + gap) / (min_col + gap))))


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
	var heights: Array[float] = []
	for k in kids:
		heights.append(k.get_combined_minimum_size().y)
	var out := arrange(size.x, heights, min_col, gap, row_gap)
	var rects: Array = out.rects
	for i in kids.size():
		fit_child_in_rect(kids[i], rects[i])
	var h: float = out.height
	if absf(h - _min_h) > 0.5:
		_min_h = h
		update_minimum_size()


## Disposición (función pura): un Rect2 por hijo y el alto total, para un ancho y las alturas mínimas de los hijos.
static func arrange(width: float, heights: Array[float], p_min_col: float, p_gap: float, p_row_gap: float) -> Dictionary:
	var cols := maxi(1, int(floor((width + p_gap) / (p_min_col + p_gap))))
	var cw := (width - p_gap * (cols - 1)) / cols
	var rects: Array = []
	var y := 0.0
	var i := 0
	while i < heights.size():
		var end := mini(i + cols, heights.size())
		var row_h := 0.0
		for k in range(i, end):
			row_h = maxf(row_h, heights[k])
		for k in range(i, end):
			rects.append(Rect2((k - i) * (cw + p_gap), y, cw, row_h))
		y += row_h
		if end < heights.size():
			y += p_row_gap
		i = end
	return { "rects": rects, "height": y, "columns": cols }


func _get_minimum_size() -> Vector2:
	return Vector2(min_col, _min_h)
