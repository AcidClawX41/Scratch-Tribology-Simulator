## Cetrería · la lente de la cámara (unidad 5t-B; desde el 13-10, parte del juego): una capa sobre la vista 3D con un
## sombreador que lee la imagen de detrás (lens.gdshader; en el teléfono, lens_simple.gdshader, sin leer la pantalla), no
## objetos en la escena. Solo dibujo: el resultado de cada garra, la anchura y la hondura de cada rayón y el índice
## `obscuration` son del motor (la calle C, core/lab/claw_care_reaction.gd); aquí se pintan.
##
## - La lente puesta (`set_lens(id, daño)`): cuatro por nivel («plastico», «vidrio», «vidrio_templado», «zafiro»), cada una
##   con su daño guardado. Los rayones, los desgarros y las grietas se quedan en esa lente (no se limpian); cambiar de
##   lente (la tienda de la 5u) es ponerle otra con su propio daño. Solo las manchas se van con el paño (`clean()`).
## - El daño se pinta en un mapa (lens_shapes.gd, en un SubViewport que solo se vuelve a dibujar cuando cambia) y el
##   sombreador lo lee: refracción y brillo en el surco, el borde blanquecino o astillado, la grieta con su zona lechosa,
##   la grasa, lo pegado y la pérdida de contraste y de nitidez donde hay daños, según `obscuration`.
## - Durante el golpe, los rayones se dibujan a la vez que avanzan las garras (`live_begin`, `live_point`, `live_end`).
## - La calidad de imagen de cada lente (dibujo, se puede quitar): la de plástico, algo menos nítida y con viñeta; las de
##   vidrio y zafiro, limpias. El destello del impacto (`flash`).
## - Accesibilidad: `set_effect_enabled(false)` quita el efecto entero (el daño sigue en el motor y se dice con texto).
## Coste: sin daños ni calidad que enseñar, la capa no se dibuja; con ellos, una pasada a pantalla completa (≤ 0,5 ms en
## escritorio) y el mapa solo cuando cambia.
## Unidades: el trazo, en coordenadas normalizadas de la vista (0-1, y hacia abajo); los anchos, en µm del motor.
extends CanvasLayer

signal cleaned(count: int)

const LensShapes = preload("res://app/lab/cetreria/reaction/lens_shapes.gd")
const LENS_SHADER = preload("res://app/lab/cetreria/reaction/lens.gdshader")
const LENS_SIMPLE_SHADER = preload("res://app/lab/cetreria/reaction/lens_simple.gdshader")

## Las cuatro lentes (ids del motor, LENSES de la calle C) y su calidad de imagen (dibujo): el desenfoque base (mipmap),
## la viñeta y el tinte. Una lente que no esté aquí, limpia.
const QUALITY := {
	"plastico": { "soft_lod": 0.55, "vignette": 0.32, "tint": Color(1.0, 0.985, 0.955) },
	"vidrio": { "soft_lod": 0.0, "vignette": 0.0, "tint": Color(1.0, 1.0, 1.0) },
	"vidrio_templado": { "soft_lod": 0.0, "vignette": 0.0, "tint": Color(1.0, 1.0, 1.0) },
	"zafiro": { "soft_lod": 0.0, "vignette": 0.0, "tint": Color(0.995, 1.0, 1.0) },
}
## Ancho en pantalla de un rayón (dibujo): su anchura del motor × WIDTH_PX_PER_UM px de una vista de 1280 px (una lente de
## ~32 mm a lo ancho), con su mínimo y su máximo.
const WIDTH_PX_PER_UM := 0.04
const WIDTH_MIN_PX := 1.2
const WIDTH_MAX_PX := 18.0
## La hondura que se ve oscura del todo (µm; dibujo): por encima, el surco ya no se ve más hondo.
const DEPTH_FULL_UM := 60.0
## Lo que dura el destello (s) y el paño (s).
const FLASH_S := 0.08
const WIPE_S := 0.7
## Resolución del mapa frente a la de la vista: escritorio y teléfono.
const MAP_SCALE := { "escritorio": 1.0, "movil": 0.5 }
const MAP_MAX_W := 1600
## La grieta: el radio de la estrella (fracción del ancho; dibujo).
const CRACK_RADIUS := 0.16
## El color de lo que deja una garra de metal (dibujo): el oro, un brillo dorado; el acero y el titanio, un trazo gris.
const DEPOSIT := {
	"oro": Color(0.86, 0.69, 0.26, 0.32), "acero": Color(0.44, 0.46, 0.49, 0.42), "titanio": Color(0.5, 0.5, 0.52, 0.36),
}

var lens_id := "plastico"
## El daño de la lente (copia local; el del motor manda cuando llega): { scratches, cracks, smudges, obscuration }.
var damage := { "scratches": [], "cracks": [], "smudges": [], "obscuration": 0.0 }
var effect_enabled := true
var quality_enabled := true
var simple := false

var _vp: SubViewport
var _mesh_node: MeshInstance2D
var _mesh := ArrayMesh.new()
var _rect: ColorRect
var _mat: ShaderMaterial
var _live: Array = []
var _dirty := true
var _flash_t := -1.0
var _flash_k := 0.0
var _flash_at := Vector2(0.5, 0.5)
var _wipe := -1.0
var _map_size := Vector2i.ZERO
var _renders := 0
var _t := 0.0
var _light := Vector2(-0.55, -0.83)
var _core_serial := -1


func _init() -> void:
	name = "Lente"
	layer = 1
	_vp = SubViewport.new()
	_vp.name = "MapaDeDanos"
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.own_world_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(64, 32)
	add_child(_vp)
	_mesh_node = MeshInstance2D.new()
	_mesh_node.name = "Danos"
	_mesh_node.mesh = _mesh
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mesh_node.material = cm
	_vp.add_child(_mesh_node)
	_rect = ColorRect.new()
	_rect.name = "EfectoDeLaLente"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = LENS_SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _ready() -> void:
	_mat.set_shader_parameter("damage_map", _vp.get_texture())
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_resized):
		vp.size_changed.connect(_on_resized)
	_on_resized()


# ─────────────────────────────── API ───────────────────────────────

## Pone la lente id con su daño guardado (el del motor, `to_dict()`; vacío: nueva). Lo que había se va con la lente de antes.
func set_lens(id: String, saved: Dictionary = {}) -> void:
	lens_id = id
	_core_serial = -1
	_live.clear()
	_wipe = -1.0
	damage = { "scratches": [], "cracks": [], "smudges": [], "obscuration": 0.0 }
	if not saved.is_empty():
		apply_damage(saved)
	_dirty = true
	_apply_uniforms()


## El daño de la lente puesta tal como lo da el motor (ClawCareLens.view(), la calle C; manda sobre la copia local): { lens,
## scratches: [{ id, kind (rayon | rayon_hondo | desgarro | grieta), trace (normalizado), widthUm, depthUm, finger, material,
## seq }], smudges: [{ id, trace, finger, material, transfer, seq }], obscuration, serial }. La grieta es un rayón de un
## punto (donde se rajó). Solo se rehace si cambia su serial.
func apply_damage(d: Dictionary, force := false) -> void:
	var ser := int(d.get("serial", -1))
	var lid := String(d.get("lens", lens_id))
	if not force and ser >= 0 and ser == _core_serial and lid == lens_id:
		return
	_core_serial = ser
	if lid != "":
		lens_id = lid
	var out := { "scratches": [], "cracks": [], "smudges": [], "obscuration": clampf(float(d.get("obscuration", 0.0)), 0.0, 1.0) }
	for sc: Variant in d.get("scratches", []):
		if not (sc is Dictionary):
			continue
		var sd: Dictionary = sc
		if String(sd.get("kind", "")) == "grieta":
			var tr := _points(sd.get("trace", []))
			if not tr.is_empty():
				var sid := int(sd.get("id", 1))
				(out.cracks as Array).append({ "at": tr[0], "radius": CRACK_RADIUS, "rays": 6 + sid % 4, "seed": 7919 * sid + 13 })
			continue
		var it := scratch_item(sd)
		if not it.is_empty():
			(out.scratches as Array).append(it)
	for sm: Variant in d.get("smudges", []):
		if sm is Dictionary:
			var it := smudge_item(sm as Dictionary)
			if not it.is_empty():
				(out.smudges as Array).append(it)
	damage = out
	_dirty = true
	_apply_uniforms()


## Lo que se pinta de un rayón del motor: { points, w_px, depth, edge, chips, tear, deposit, seed, outcome, finger,
## widthUm, depthUm }. {} si no tiene trazo. El borde, según la lente (blanquecino en el plástico, astillado en el vidrio y
## el zafiro); un metal blando que raya deja algo de su color (el oro, un brillo dorado; el acero y el titanio, gris).
func scratch_item(sc: Dictionary) -> Dictionary:
	var pts := _points(sc.get("trace", sc.get("points", [])))
	if pts.size() < 2:
		return {}
	var outcome := String(sc.get("kind", sc.get("outcome", "rayon")))
	var w_um := float(sc.get("widthUm", 40.0))
	var d_um := float(sc.get("depthUm", 4.0))
	var glass := lens_id != "plastico"
	var tear := outcome == "desgarro"
	var deep := outcome in ["rayon_hondo", "desgarro"]
	var edge := 0.5 if glass else (0.9 if tear else (0.6 if deep else 0.22))
	var it := {
		"points": pts, "w_px": clampf(w_um * WIDTH_PX_PER_UM, WIDTH_MIN_PX, WIDTH_MAX_PX) * (1.6 if tear else 1.0),
		"depth": clampf(log(1.0 + maxf(d_um, 0.0)) / log(1.0 + DEPTH_FULL_UM), 0.12, 1.0), "edge": edge,
		"chips": glass and (deep or d_um > 1.0), "tear": tear,
		"seed": int(sc.get("id", 0)) * 7349 + 11 if sc.has("id") else (hash(str(pts)) & 0x7fffffff),
		"outcome": outcome, "finger": String(sc.get("finger", "")), "widthUm": w_um, "depthUm": d_um, "progress": 1.0,
	}
	var mat := String(sc.get("material", "none"))
	if DEPOSIT.has(mat):
		it["deposit"] = DEPOSIT[mat]
	return it


## Lo que se pinta de una mancha del motor: el trazo de un metal blando que resbala sin rayar (transfer) o la grasa y el
## polvo de la punta donde tocó. {} sin trazo.
func smudge_item(sm: Dictionary) -> Dictionary:
	var pts := _points(sm.get("trace", []))
	if pts.is_empty():
		return {}
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p / float(pts.size())
	var sid := int(sm.get("id", 1))
	var tr := String(sm.get("transfer", ""))
	if tr != "" and pts.size() >= 2:
		return { "kind": "metal", "points": pts, "at": c, "size": 0.03, "color": DEPOSIT.get(tr, Color(0.45, 0.47, 0.5, 0.55)), "seed": sid }
	var dust := String(sm.get("material", "none")) == "none" and sid % 3 == 0
	# la grasa: la mancha de la almohadilla al final y su rastro a lo largo del trazo (points)
	return { "kind": "polvo" if dust else "grasa", "at": pts.back() if not dust else c, "points": pts if not dust else [],
		"size": 0.045 + 0.015 * float(sid % 3), "seed": 104729 * sid + 7 }


static func _points(v: Variant) -> Array:
	var out: Array = []
	if v is PackedVector2Array:
		for p: Vector2 in v:
			out.append(p)
	elif v is Array:
		for p: Variant in v:
			if p is Vector2:
				out.append(p)
			elif p is Array and (p as Array).size() >= 2:
				out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Empieza a dibujar los rayones de un golpe: items, los de scratch_item() sin trazo todavía (points: []). Devuelve cuántos.
func live_begin(items: Array) -> int:
	_live.clear()
	for it: Dictionary in items:
		var c := it.duplicate(true)
		c["points"] = []
		_live.append(c)
	_dirty = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_apply_uniforms()
	return _live.size()


## Un punto nuevo (normalizado) del rayón i que se está dibujando.
func live_point(i: int, uv: Vector2) -> void:
	if i < 0 or i >= _live.size():
		return
	var pts: Array = _live[i].points
	if pts.is_empty() or (pts.back() as Vector2).distance_to(uv) > 0.0005:
		pts.append(uv)
		_dirty = true


## Acaba el golpe: los rayones dibujados pasan al daño de la lente (hasta que llegue el del motor) y se devuelven, para
## pasárselos al motor (`strokes`: [{ finger, outcome, points (normalizados), widthUm, depthUm }]).
func live_end() -> Array:
	var out: Array = []
	for it: Dictionary in _live:
		if (it.points as Array).size() < 2:
			continue
		(damage.scratches as Array).append(it)
		var pts: Array = []
		for p: Vector2 in it.points:
			pts.append([p.x, p.y])
		out.append({ "finger": it.get("finger", ""), "outcome": it.get("outcome", "rayon"), "points": pts,
			"widthUm": float(it.get("widthUm", 0.0)), "depthUm": float(it.get("depthUm", 0.0)) })
	_live.clear()
	_dirty = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_apply_uniforms()
	return out


## Una grieta en estrella desde at (normalizado).
func add_crack(at: Vector2, radius: float, rays: int, seed: int) -> void:
	(damage.cracks as Array).append({ "at": at, "radius": radius, "rays": rays, "seed": seed })
	_dirty = true
	_apply_uniforms()


## Una mancha: kind «grasa» (las almohadillas), «polvo» o «metal» (un trazo del color de la garra que resbala sin rayar).
func add_smudge(sm: Dictionary) -> void:
	(damage.smudges as Array).append(sm.duplicate(true))
	_dirty = true
	_apply_uniforms()


## El índice de cuánto cuesta ver (0-1, del motor).
func set_obscuration(x: float) -> void:
	damage["obscuration"] = clampf(x, 0.0, 1.0)
	_apply_uniforms()


## El paño: pasa en WIPE_S y se lleva las manchas (los rayones se quedan). Devuelve cuántas manchas había.
func clean() -> int:
	var n := (damage.smudges as Array).size()
	_wipe = 0.0
	_apply_uniforms()
	return n


func is_cleaning() -> bool:
	return _wipe >= 0.0


## El destello del impacto en at (normalizado), con fuerza k (0-1).
func flash(at: Vector2, k: float) -> void:
	_flash_at = at
	_flash_k = clampf(k, 0.0, 1.0) * 0.25
	_flash_t = 0.0
	_apply_uniforms()


## Quita o pone todo el efecto (accesibilidad).
func set_effect_enabled(on: bool) -> void:
	effect_enabled = on
	_apply_uniforms()


## Quita o pone la calidad de imagen de la lente (la viñeta y el desenfoque de la de plástico).
func set_quality_enabled(on: bool) -> void:
	quality_enabled = on
	_apply_uniforms()


## La versión sencilla (el teléfono): sin leer la pantalla.
func set_simple(on: bool) -> void:
	if on == simple:
		return
	simple = on
	_mat.shader = LENS_SIMPLE_SHADER if on else LENS_SHADER
	_mat.set_shader_parameter("damage_map", _vp.get_texture())
	_on_resized()


## La dirección de la luz en la pantalla para el brillo del surco (se mueve un poco con la cámara).
func set_light(dir: Vector2) -> void:
	if dir.length_squared() > 1e-8:
		_light = dir.normalized()
		_mat.set_shader_parameter("light_dir", _light)


func advance(dt: float) -> void:
	_t += dt
	if _flash_t >= 0.0:
		_flash_t += dt
		if _flash_t >= FLASH_S:
			_flash_t = -1.0
		_apply_uniforms()
	if _wipe >= 0.0:
		_wipe += dt / WIPE_S * 1.15
		# las manchas por las que ya ha pasado el paño se van (detrás de él, sin que se note)
		var keep: Array = []
		for sm: Dictionary in damage.smudges:
			var at: Variant = sm.get("at", Vector2.ZERO)
			var x := (at as Vector2).x if at is Vector2 else (float((at as Array)[0]) if at is Array else 0.5)
			if x + float(sm.get("size", 0.05)) * 0.6 < _wipe * 1.6 - 0.08 - 0.12:
				continue
			keep.append(sm)
		if keep.size() != (damage.smudges as Array).size():
			var gone := (damage.smudges as Array).size() - keep.size()
			damage["smudges"] = keep
			_dirty = true
			if keep.is_empty():
				cleaned.emit(gone)
		if _wipe > 1.15:
			_wipe = -1.0
		_apply_uniforms()
	if _dirty:
		_rebuild()


## Para los tests y la interfaz.
func info() -> Dictionary:
	return {
		"lens": lens_id, "scratches": (damage.scratches as Array).size(), "cracks": (damage.cracks as Array).size(),
		"smudges": (damage.smudges as Array).size(), "obscuration": float(damage.get("obscuration", 0.0)), "live": _live.size(),
		"enabled": effect_enabled, "quality": quality_enabled, "simple": simple, "visible": _rect.visible, "renders": _renders,
		"cleaning": _wipe >= 0.0, "map": _map_size, "flash": _flash_t >= 0.0,
	}


## Los trazos de los rayones (normalizados) que se ven ahora, los guardados y los que se están dibujando.
func strokes() -> Array:
	var out: Array = []
	for it: Dictionary in damage.scratches + _live:
		out.append(it.points)
	return out


# ─────────────────────────────── por dentro ───────────────────────────────

func _has_damage() -> bool:
	return not (damage.scratches as Array).is_empty() or not (damage.cracks as Array).is_empty() or not (damage.smudges as Array).is_empty() or not _live.is_empty()


func _on_resized() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var vs := Vector2(vp.get_visible_rect().size)
	var q := float(MAP_SCALE.movil if simple else MAP_SCALE.escritorio)
	var w := clampi(int(vs.x * q), 32, MAP_MAX_W)
	var h := clampi(int(vs.y * q), 16, MAP_MAX_W)
	var ms := Vector2i(w, h)
	if ms != _map_size:
		_map_size = ms
		_vp.size = Vector2i(w * 3, h)
		_dirty = true
	_mat.set_shader_parameter("map_px", Vector2(w, h))
	_mat.set_shader_parameter("view_px", vs)
	_apply_uniforms()


func _rebuild() -> void:
	_dirty = false
	var a := LensShapes.build(damage, _live, float(_map_size.x), float(_map_size.y))
	_mesh.clear_surfaces()
	if LensShapes.has_triangles(a):
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	if _vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_renders += 1


func _apply_uniforms() -> void:
	var q: Dictionary = QUALITY.get(lens_id, QUALITY.vidrio) if quality_enabled else QUALITY.vidrio
	var dmg := _has_damage()
	var shows_quality := quality_enabled and (float(q.soft_lod) > 0.0 or float(q.vignette) > 0.0)
	var flashing := _flash_t >= 0.0
	_rect.visible = effect_enabled and (dmg or shows_quality or flashing or _wipe >= 0.0)
	_mat.set_shader_parameter("has_damage", dmg)
	_mat.set_shader_parameter("obscuration", float(damage.get("obscuration", 0.0)))
	_mat.set_shader_parameter("vignette", float(q.vignette))
	if not simple:
		_mat.set_shader_parameter("soft_lod", float(q.soft_lod))
		_mat.set_shader_parameter("tint", q.tint)
		_mat.set_shader_parameter("light_dir", _light)
	var fk := 0.0
	if flashing:
		fk = _flash_k * (1.0 - _flash_t / FLASH_S)
	_mat.set_shader_parameter("flash", fk)
	_mat.set_shader_parameter("flash_at", _flash_at)
	_mat.set_shader_parameter("wipe", _wipe)
