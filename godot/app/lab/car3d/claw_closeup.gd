## El primer plano de las garras del coche en marcha (unidad 4s, petición de Eric del 13-10-2026: «que se vean bien las
## garras en 3D en el simulador del coche en marcha, con las marcas de arañazos, punzadas y demás en alta calidad»): una
## segunda cámara, en perspectiva, que comparte el mundo 3D de la vista (car_scene.gd) y se acerca a la pata y a las garras
## que tocan la chapa, la pintura o el vidrio, y las sigue durante el zarpazo y el arrastre.
##   - Dos tamaños: una ventana dentro de la vista del coche (la lupa de las garras) o la vista entera (el primer plano, que
##     se elige en la tarjeta con «Vista»). La vista (moving_car_view.gd) decide dónde va y a qué apunta: las puntas de las
##     garras que tocan el panel (de la pose del animal), la normal del panel y el largo de la garra (el del catálogo).
##   - Lo que se ve es lo de siempre, de cerca: las marcas en el material del coche (car_damage.gd, con los números del
##     motor y su relieve) y las garras de la biblioteca (ClawGeo y ClawMaterial) con el material elegido, su brillo y sus
##     roturas. No ve el viento (de cerca, cada partícula sería una mancha).
##   - Resolución: el SubViewport se dibuja a los píxeles de verdad de la pantalla (el tamaño en la interfaz por la escala de
##     la ventana: ×2-×3 en un teléfono, pixel_scale()), sin el 0,7 de la vista móvil (lo que pixelaba el animal en el
##     teléfono, 4r), con un tope de píxeles (MAX_PX) para que un teléfono no pague más que un escritorio.
##   - Coste: solo se renderiza cuando cambia lo que enseña (algo se mueve o la cámara llega a su sitio); quieto, una vez; la
##     ventana, a la mitad de fotogramas mientras algo se mueve (15 por segundo a 30), y la vista entera en cada uno (entonces
##     el coche entero no se renderiza).
## Solo dibujo: el campo, el ángulo, el seguimiento y el marco. El texto lo da el estado (MovingCarState.closeup_caption).
extends Control

const Palette = preload("res://app/theme/palette.gd")
const Js = preload("res://core/shared/js.gd")
const LayerCut = preload("res://app/lab/car3d/layer_cut.gd")

## Campo de visión vertical de la cámara (grados): un teleobjetivo corto, para que la garra no se deforme (dibujo).
const FOV_DEG := 28.0
## Lo que se ve alrededor de la garra, en el lado corto: tantas veces su largo, entre dos topes (m). Dibujo: la garra entera
## con su dedo y el principio del surco que deja detrás.
const FIELD_K := 1.9
const FIELD_MIN := 0.035
const FIELD_MAX := 0.16
## Desde dónde mira (grados): lo que se levanta sobre el panel y lo que gira a lo largo del coche (hacia delante o hacia
## atrás, lo elige la vista). Dibujo.
const ELEV_DEG := 22.0
## En un costado (la puerta, la aleta, la ventanilla) mira más de frente: a ras, la chapa solo refleja el cielo y la abolladura
## tapa las garras. Dibujo.
const ELEV_SIDE_DEG := 50.0
## Lo que se queda la cámara, como poco, por fuera de la chapa sin abollar (m): dentro de una abolladura honda, la cámara no
## se mete en la carrocería.
const OUTSIDE_M := 0.03
const YAW_DEG := 38.0
## La marca de cerca (unidad 4s, segunda ronda): lo menos que se ve (m), su ángulo sobre el panel (grados) y la luz de relleno
## que la acompaña en la vista entera (un foco junto a la cámara, como la lámpara de quien mira un arañazo de cerca: hace
## brillar el barniz y deja ver el relieve del surco y sus labios). Dibujo.
const MARK_FIELD_MIN := 0.003
const MARK_ELEV_DEG := 40.0
const KEY_ENERGY := 1.1
const KEY_ANGLE_DEG := 34.0
## Seguimiento: la cámara recorre el 63 % de lo que le falta en FOLLOW_S s (dibujo: sin tirones si el animal tiembla).
const FOLLOW_S := 0.12
## Por debajo de esto (m) ya ha llegado.
const SETTLE_M := 0.0004
## Tope de píxeles del render (teléfonos ×3): 1,6 millones.
const MAX_PX := 1.6e6
## Esquinas redondeadas (px) y el alto de la franja del texto (px).
const RADIUS := 10.0
const BAND_H := 30.0
const BAND_H_SMALL := 18.0
## Lo que crece la franja por cada línea de más (px).
const LINE_H := 13.0
const LINE_H_SMALL := 11.0

## El SubViewport (comparte el mundo de la vista), su cámara y lo que lo enseña.
var vp: SubViewport
var cam: Camera3D
## La luz de relleno del primer plano (solo con la vista entera: el coche entero no se renderiza entonces).
var key: SpotLight3D
var tex: TextureRect
## Ocupa la vista entera (el primer plano) o es la ventana de la lupa de las garras.
var full := false
## El texto: dos líneas (material y punta; lo que les pasa) y el aumento.
var lines: Array = ["", ""]
var zoom_txt := ""
## Unidad 4s (petición del 17-10): el corte de la chapa con la marca (MovingCarState.tear_now), pequeño, arriba a la izquierda.
var cut: Dictionary = {}
## Lo que se ve en el lado corto (m) a la distancia del foco (para la barra de escala).
var field_m := 0.08
## Renders pedidos (para las pruebas) y si hay que pedir otro.
var renders := 0
var _dirty := true
var _goal_pos := Vector3.ZERO
var _goal_at := Vector3.ZERO
var _goal_up := Vector3.UP
var _pos := Vector3.ZERO
var _at := Vector3.ZERO
var _aimed := false
var _placed := false
var _tick := 0
## Los marcos (se hacen una vez).
var _sb_fill := StyleBoxFlat.new()
var _sb_border := StyleBoxFlat.new()
var _moving := false


func _init() -> void:
	name = "PrimerPlano"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	accessibility_name = "Primer plano de las garras sobre la chapa"


## Construye el SubViewport y la cámara (una vez), en el mundo de la vista. cull_mask: lo que ve la cámara (sin el viento).
func setup(world: World3D, msaa: Viewport.MSAA, cull_mask: int) -> void:
	if vp != null:
		return
	vp = SubViewport.new()
	vp.name = "Render"
	vp.transparent_bg = true
	vp.audio_listener_enable_3d = false
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.msaa_3d = msaa
	vp.scaling_3d_scale = 1.0
	vp.world_3d = world
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.name = "CamaraGarras"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = FOV_DEG
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.002
	cam.far = 40.0
	cam.cull_mask = cull_mask
	vp.add_child(cam)
	cam.current = true
	key = SpotLight3D.new()
	key.name = "LuzDeCerca"
	key.light_energy = KEY_ENERGY
	key.light_color = Color(1.0, 0.97, 0.92)
	key.spot_angle = KEY_ANGLE_DEG
	key.spot_attenuation = 0.6
	key.shadow_enabled = true
	key.visible = false
	vp.add_child(key)
	tex = TextureRect.new()
	tex.name = "Imagen"
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.texture = vp.get_texture()
	add_child(tex)
	tex.draw.connect(_draw_frame)


## Escala de la pantalla de un control (px de verdad por px de la interfaz: la de la ventana, ×2-×3 en un teléfono), entre
## 1 y 4.
static func pixel_scale(c: Control) -> float:
	if not c.is_inside_tree():
		return 1.0
	return clampf(c.get_screen_transform().get_scale().x, 1.0, 4.0)


## El tamaño del render (px de verdad) de un control de size px de la interfaz, sin pasar de max_px píxeles.
static func render_size(size_px: Vector2, k: float, max_px := MAX_PX) -> Vector2i:
	var s := size_px * k
	var area := s.x * s.y
	if area > max_px and area > 0.0:
		s *= sqrt(max_px / area)
	return Vector2i(maxi(int(s.x), 2), maxi(int(s.y), 2))


## Lo coloca en rect (px de la vista) y ajusta el render a su tamaño de verdad.
func place(rect: Rect2, p_full: bool) -> void:
	if key != null:
		key.visible = p_full
	if rect == Rect2(position, size) and p_full == full and vp != null and vp.size != Vector2i.ZERO and _placed:
		return
	_placed = true
	_dirty = true
	full = p_full
	position = rect.position
	size = rect.size
	if vp != null:
		var want := render_size(size, pixel_scale(self))
		if vp.size != want:
			vp.size = want
	queue_redraw()
	if tex != null:
		tex.queue_redraw()


## Apunta a focus (m, en el coche): la normal del panel (normal), hacia quien mira la vista del coche (viewer, para elegir de
## qué lado se mira), lo que hay que ver en el lado corto (field, m) y de qué lado mira a lo largo del coche (cam_side, ±1:
## +1 desde delante). Con snap, va directa (otro animal, otro ensayo); si no, la sigue con suavidad (advance).
## below: lo que está focus por debajo de la chapa sin abollar (m: dentro de una abolladura); side_panel: un costado.
## elev_deg (> 0): otro ángulo sobre el panel; field_min: lo menos que se ve (la marca de cerca baja a MARK_FIELD_MIN).
func aim(focus: Vector3, normal: Vector3, viewer: Vector3, field: float, snap := false, cam_side := 1.0, below := 0.0,
		side_panel := false, elev_deg := -1.0, field_min := FIELD_MIN) -> void:
	field_m = clampf(field, field_min, FIELD_MAX)
	var n := normal.normalized() if normal.length() > 1e-6 else Vector3.UP
	# el marco del panel: a lo largo del coche (x en el plano del panel) y, de través, hacia quien mira (arriba, en un costado)
	var along := Vector3.RIGHT - n * n.x
	along = along.normalized() if along.length() > 1e-4 else Vector3.BACK
	var side := n.cross(along).normalized()
	if side.dot(viewer) < 0.0:
		side = -side
	var e := deg_to_rad(elev_deg if elev_deg > 0.0 else (ELEV_SIDE_DEG if side_panel else ELEV_DEG))
	var y := deg_to_rad(YAW_DEG) * (1.0 if cam_side >= 0.0 else -1.0)
	var dir := (n * sin(e) + side * cos(e) * cos(y) + along * cos(e) * sin(y)).normalized()
	var aspect := size.x / maxf(size.y, 1.0)
	var half := tan(deg_to_rad(FOV_DEG) * 0.5) * minf(aspect, 1.0)
	var dist := field_m * 0.5 / maxf(half, 1e-3)
	# fuera de la carrocería: si la abolladura es más honda que lo que la cámara se levanta, se levanta más
	var out := dir.dot(n) * dist
	var need := maxf(below, 0.0) + OUTSIDE_M if below > 0.0 else 0.0
	if out < need:
		var flat := (dir - n * dir.dot(n)).normalized() * dist * cos(e)
		dir = (flat + n * need).normalized()
		dist = (flat + n * need).length()
	_goal_at = focus
	_goal_pos = focus + dir * dist
	_goal_up = n if absf(dir.dot(n)) < 0.97 else side
	if snap or not _aimed:
		_pos = _goal_pos
		_at = _goal_at
		_aimed = true
		_apply()


## Avanza dt segundos el seguimiento. Devuelve si la cámara se ha movido (hay que renderizar).
func advance(dt: float) -> bool:
	if not _aimed:
		return false
	var gap := maxf(_pos.distance_to(_goal_pos), _at.distance_to(_goal_at))
	if gap < SETTLE_M:
		if gap > 0.0:
			_pos = _goal_pos
			_at = _goal_at
			_apply()
			return true
		return false
	var k := 1.0 - exp(-maxf(dt, 0.0) / FOLLOW_S)
	_pos = _pos.lerp(_goal_pos, k)
	_at = _at.lerp(_goal_at, k)
	_apply()
	return true


func _apply() -> void:
	_dirty = true
	if cam == null:
		return
	var up := _goal_up
	var fwd := (_at - _pos).normalized()
	if absf(fwd.dot(up)) > 0.999:
		up = Vector3.BACK
	cam.look_at_from_position(_pos, _at, up)
	if key != null:
		# por encima y algo de lado de la cámara, hacia donde el barniz refleja la luz hacia quien mira: el brillo cae junto al
		# surco, no encima
		var n := _goal_up
		var c := (_pos - _at)
		var dist := c.length()
		var m := (n * 2.0 * n.dot(c) - c).normalized()  # el reflejo de la cámara en el panel
		var dir := (m.lerp(c.normalized(), 0.3) + n * 0.15).normalized()
		key.spot_range = dist * 6.0
		var at_pos := _at + dir * dist * 1.8
		if absf(dir.dot(Vector3.UP)) < 0.99:
			key.look_at_from_position(at_pos, _at, Vector3.UP)
		else:
			key.look_at_from_position(at_pos, _at, Vector3.BACK)


## Lo que ve la cámara (capas de render).
func set_cull(mask: int) -> void:
	if cam != null and cam.cull_mask != mask:
		cam.cull_mask = mask
		_dirty = true


## Pide el render de este fotograma: en cada uno si algo se mueve (live), o uno solo si ha cambiado lo que enseña.
func request(live: bool) -> void:
	if vp == null or not visible:
		return
	if live and full:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		renders += 1
	elif live:
		# la ventana, a la mitad de fotogramas mientras algo se mueve (el coche entero ya se renderiza en cada uno): su coste
		# por fotograma, la mitad
		_tick += 1
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE if _tick % 2 == 0 else SubViewport.UPDATE_DISABLED
		renders += 1 if _tick % 2 == 0 else 0
	elif _dirty or vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		renders += 1
	_dirty = false


## Deja de renderizar (escondido).
func stop() -> void:
	if key != null:
		key.visible = false
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_dirty = true


## El texto del marco (dos líneas) y el aumento.
func set_text(p_lines: Array, p_zoom: String) -> void:
	var l := p_lines.duplicate()
	while l.size() < 2:
		l.append("")
	if l != lines or p_zoom != zoom_txt:
		lines = l
		zoom_txt = p_zoom
		if tex != null:
			tex.queue_redraw()


## El corte de la chapa (un tear_now; {} lo quita).
func set_cut(t: Dictionary) -> void:
	if LayerCut._key(t) != LayerCut._key(cut):
		cut = t
		if tex != null:
			tex.queue_redraw()


## Un largo redondo (m) para la barra de escala: 1, 2 o 5 por potencia de diez, sin pasar de target.
static func nice_length(target: float) -> float:
	var out := 0.001
	for l: float in [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1]:
		if l <= target:
			out = l
	return out


## Un texto partido en líneas que quepan en w, por las palabras (en el teléfono no cabía «(0.81 mm con la pintura)» y la
## línea se cortaba): la franja de abajo crece una línea por cada una de más. Una palabra sola más larga que w va entera.
static func wrap_words(font: Font, s: String, w: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word: String in s.split(" ", false):
		var probe := word if cur == "" else cur + " " + word
		if cur != "" and font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			out.append(cur)
			cur = word
		else:
			cur = probe
	if cur != "" or out.is_empty():
		out.append(cur)
	return out


func _draw() -> void:
	# la forma que recorta lo de dentro (esquinas redondeadas) y el fondo, por si el render aún no ha llegado
	_sb_fill.bg_color = Color(Palette.color("bg2"), 1.0)
	_sb_fill.set_corner_radius_all(int(RADIUS if not full else 4.0))
	_sb_fill.anti_aliasing = true
	draw_style_box(_sb_fill, Rect2(Vector2.ZERO, size))


## Encima del render: la franja con el texto, la barra de escala y el borde.
func _draw_frame() -> void:
	var font := get_theme_default_font()
	var small := size.y < 150.0
	var fs := 9 if small else 11
	var text := Palette.color("text")
	var dim := Palette.color("dim")
	var x := 8.0
	var w := size.x - 16.0
	# las dos líneas, partidas por palabras si no caben (la franja crece hacia arriba: LINE_H por línea)
	var rows: Array = []
	for t: String in wrap_words(font, String(lines[0]), w, fs):
		rows.append([t, fs, text])
	if not small:
		for t: String in wrap_words(font, String(lines[1]), w, fs - 1):
			rows.append([t, fs - 1, dim])
	var band := BAND_H_SMALL + LINE_H_SMALL * (rows.size() - 1) if small else BAND_H + LINE_H * (rows.size() - 2)
	tex.draw_rect(Rect2(0.0, size.y - band, size.x, band), Color(Palette.color("bg"), 0.72))
	var lh := LINE_H_SMALL if small else LINE_H
	for i in rows.size():
		var y := size.y - 5.0 - lh * float(rows.size() - 1 - i)
		tex.draw_string(font, Vector2(x, y), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, w, int(rows[i][1]), rows[i][2])
	# la barra de escala, arriba a la derecha: un largo redondo a la distancia del foco
	var short := minf(size.x, size.y)
	var bar := nice_length(field_m * 0.3)
	var px := bar / maxf(field_m, 1e-6) * short
	var y := 12.0
	var x1 := size.x - 10.0
	var x0 := x1 - px
	tex.draw_line(Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), Color(Palette.color("bg"), 0.8), 3.0)
	tex.draw_line(Vector2(x0, y), Vector2(x1, y), text, 1.5)
	for xx: float in [x0, x1]:
		tex.draw_line(Vector2(xx, y - 3.0), Vector2(xx, y + 3.0), text, 1.5)
	var lab := "%s mm" % Js.to_fixed(bar * 1000.0, 0) if bar < 0.01 else "%s cm" % Js.to_fixed(bar * 100.0, 0)
	if zoom_txt != "":
		lab = "%s · %s" % [zoom_txt, lab]
	tex.draw_string_outline(font, Vector2(x0 - 160.0, y + 14.0), lab, HORIZONTAL_ALIGNMENT_RIGHT, 160.0 + px, fs - 1, 3, Color(Palette.color("bg"), 0.85))
	tex.draw_string(font, Vector2(x0 - 160.0, y + 14.0), lab, HORIZONTAL_ALIGNMENT_RIGHT, 160.0 + px, fs - 1, text)
	if not cut.is_empty() and int(cut.get("level", 0)) > 0 and size.y >= 120.0:
		# el corte de la chapa, pequeño: las capas y el surco hasta donde llega, con su escalón
		var h := clampf(size.y * 0.28, 34.0, 90.0)
		var r := Rect2(10.0, 10.0, h * 0.32, h)
		var tw := glass_cut_w(cut)  # unidad 4v: los nombres del vidrio son más largos
		tex.draw_rect(Rect2(r.position - Vector2(4, 4), Vector2(r.size.x + tw + 6.0, r.size.y + 8.0)), Color(Palette.color("bg"), 0.6))
		LayerCut.draw_cut(tex, r, cut, font, fs - 1, false)
		var title: String = { "marca": "marca", "perfora": "perfora", "raja": "raja", "abre": "abre la puerta" }.get(String(cut.id), "")
		var tcol := "gold" if cut.id == "marca" else "coral"
		if LayerCut.GLASS_TITLES.has(String(cut.id)):  # unidad 4v: el corte del vidrio
			title = String(LayerCut.GLASS_TITLES[String(cut.id)][0]).to_lower()
			tcol = String(LayerCut.GLASS_TITLES[String(cut.id)][1])
		tex.draw_string(font, Vector2(r.end.x + 6.0, r.position.y + 10.0), title, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, Palette.color(tcol))
		var deepest := ""
		for l: Dictionary in cut.layers:
			if l.state != "intacta":
				deepest = String(l.name)
		# en minúscula solo la inicial: «acero BH», no «acero bh»
		deepest = deepest.left(1).to_lower() + deepest.substr(1)
		tex.draw_string(font, Vector2(r.end.x + 6.0, r.position.y + 24.0), deepest, HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 1, Palette.color("dim"))
	if not full:
		_sb_border.draw_center = false
		_sb_border.border_color = Color(text, 0.85)
		_sb_border.set_border_width_all(2)
		_sb_border.set_corner_radius_all(int(RADIUS))
		_sb_border.anti_aliasing = true
		tex.draw_style_box(_sb_border, Rect2(Vector2.ZERO, size))


# ════════ Cristales (unidad 4v) ════════

## Ancho (px) de los rótulos del corte pequeño: el de siempre o, en el vidrio («vidrio de fuera», «núcleo en tracción»), más.
static func glass_cut_w(cut: Dictionary) -> float:
	return 124.0 if bool(cut.get("glass", false)) else 86.0
