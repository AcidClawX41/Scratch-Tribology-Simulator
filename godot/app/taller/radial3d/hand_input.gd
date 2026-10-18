## Modo manual de la radial: lo que hace el ratón (o el dedo) sobre la vista 3D, traducido a movimientos de la mano
## (mm a lo largo de la línea de corte y hacia dentro de la chapa, grados de giro y de inclinación) y de la cámara. No
## sabe nada de física: la escena pasa estas órdenes a core/taller/radial_manual.gd (move_hand, turn_hand), que decide
## hasta dónde llega el disco.
##   botón izquierdo + arrastre: ← → lleva la radial a lo largo del corte (la velocidad del ratón, pasada a mm/s con la
##     escala de la vista, es el avance) · ↑ ↓ la acerca o la aparta (más fino cerca de la chapa)
##   Mayús + botón izquierdo: ← → gira la radial alrededor de la normal de la chapa · ↑ ↓ inclina el disco
##   rueda: acerca o aparta (en pasos más finos cerca de la chapa) · Mayús + rueda: inclina · Alt + rueda: rueda de
##     velocidad (una posición por muesca)
##   botón derecho + arrastre: gira la cámara · botón central (o Mayús + derecho): la desplaza · Ctrl + rueda o
##     pellizco: zoom
##   pantalla táctil: un dedo hace de botón izquierdo; con dos dedos se gira la cámara y, al separarlos o juntarlos,
##     zoom
extends RefCounted

## Giro de la radial y del disco: grados por píxel (mucho más fino con el disco metido en la chapa, donde torcerlo lo
## pellizca).
const YAW_DEG_PX := 0.25
const YAW_DEG_PX_ENGAGED := 0.03
const TILT_DEG_PX := 0.15
const WHEEL_TILT_DEG := 1.0
## Hacia dentro, cerca de la chapa (a menos de NEAR_MM) o con el disco metido, el arrastre vertical va NEAR_GEAR veces
## más despacio: para entrar en la chapa con suavidad.
const NEAR_MM := 2.0
const NEAR_GEAR := 0.2
## Paso de la rueda del ratón hacia dentro o hacia fuera: 0,1 mm cerca de la chapa; lejos, una quinta parte de la
## distancia (entre 0,2 y 5 mm).
const WHEEL_NEAR_MM := 0.1
## Cámara
const ORBIT_DEG_PX := 0.3
const ZOOM_STEP := 0.88

var dragging := ""  # "" · "radial" · "orbita" · "pan"
var _touches := {}  # índice del dedo → posición
var _pinch := 0.0


## Traduce un evento. geo = { px_u: Vector2 (píxeles por mm a lo largo de +u en la pantalla), px_n: Vector2 (por mm
## hacia fuera de la chapa), gap_mm (distancia del disco a la chapa, 0 si la toca), engaged (disco metido) }.
## → { handled, move: Vector2 (du mm, ddepth mm), turn: Vector2 (dyaw°, dtilt°), orbit: Vector2 (°), pan: Vector2 (px),
##   zoom (factor), dial (muescas), gesture_end }
func handle(event: InputEvent, geo: Dictionary) -> Dictionary:
	var out := { "handled": false, "move": Vector2.ZERO, "turn": Vector2.ZERO, "orbit": Vector2.ZERO, "pan": Vector2.ZERO,
		"zoom": 1.0, "dial": 0, "gesture_end": false }
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_pinch = _pinch_distance()
			if dragging == "radial":
				out["gesture_end"] = true
			dragging = ""
		out["handled"] = _touches.size() >= 2
		return out
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			if sd.index == 0:
				out["orbit"] = sd.relative * ORBIT_DEG_PX
			var d := _pinch_distance()
			if _pinch > 0.0 and d > 0.0:
				out["zoom"] = _pinch / d
			_pinch = d
			out["handled"] = true
		return out
	if _touches.size() >= 2:
		return out  # con dos dedos, el ratón emulado del primero no mueve la radial
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					dragging = "radial"
				elif dragging == "radial":
					dragging = ""
					out["gesture_end"] = true
				out["handled"] = true
			MOUSE_BUTTON_RIGHT:
				dragging = ("pan" if mb.shift_pressed else "orbita") if mb.pressed else ""
				out["handled"] = true
			MOUSE_BUTTON_MIDDLE:
				dragging = "pan" if mb.pressed else ""
				out["handled"] = true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed:
					return out
				var dir := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
				if mb.ctrl_pressed:
					out["zoom"] = ZOOM_STEP if dir < 0.0 else 1.0 / ZOOM_STEP
				elif mb.alt_pressed:
					out["dial"] = -int(dir)  # rueda hacia arriba: más rpm
				elif mb.shift_pressed:
					out["turn"] = Vector2(0.0, dir * WHEEL_TILT_DEG)
				else:
					out["move"] = Vector2(0.0, dir * wheel_step(float(geo.get("gap_mm", 0.0))))
					out["gesture_end"] = true
				out["handled"] = true
		return out
	if event is InputEventMouseMotion and dragging != "":
		var mm := event as InputEventMouseMotion
		var rel := mm.relative
		match dragging:
			"orbita":
				out["orbit"] = rel * ORBIT_DEG_PX
			"pan":
				out["pan"] = rel
			"radial":
				if mm.shift_pressed:
					var engaged := bool(geo.get("engaged", false))
					out["turn"] = Vector2(rel.x * (YAW_DEG_PX_ENGAGED if engaged else YAW_DEG_PX), rel.y * TILT_DEG_PX)
				else:
					var mv := screen_to_line(rel, geo.get("px_u", Vector2.RIGHT), geo.get("px_n", Vector2.UP))
					var ddepth := -mv.y
					if ddepth > 0.0 and (float(geo.get("gap_mm", 99.0)) < NEAR_MM or bool(geo.get("engaged", false))):
						ddepth *= NEAR_GEAR
					out["move"] = Vector2(mv.x, ddepth)
		out["handled"] = true
		return out
	if event is InputEventMagnifyGesture:
		out["zoom"] = 1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01)
		out["handled"] = true
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if pg.ctrl_pressed:
			out["zoom"] = 1.0 + pg.delta.y * 0.05
		else:
			out["move"] = Vector2(0.0, pg.delta.y * wheel_step(float(geo.get("gap_mm", 0.0))))
		out["handled"] = true
	return out


## Paso (mm) de una muesca de la rueda del ratón con el disco a gap_mm de la chapa.
static func wheel_step(gap_mm: float) -> float:
	if gap_mm <= NEAR_MM:
		return WHEEL_NEAR_MM
	return clampf(gap_mm * 0.2, 0.2, 5.0)


## Un desplazamiento del ratón en la pantalla (px) pasado a mm a lo largo de la línea de corte (x) y hacia fuera de la
## chapa (y), con las direcciones en pantalla de esos dos ejes (px por mm). Si la vista los ve casi alineados, cada uno
## se proyecta por separado.
static func screen_to_line(rel: Vector2, px_u: Vector2, px_n: Vector2) -> Vector2:
	var det := px_u.x * px_n.y - px_u.y * px_n.x
	if absf(det) > 0.15 * px_u.length() * px_n.length() and absf(det) > 1e-9:
		var a := (rel.x * px_n.y - rel.y * px_n.x) / det
		var b := (px_u.x * rel.y - px_u.y * rel.x) / det
		return Vector2(a, b)
	var du := rel.dot(px_u) / maxf(px_u.length_squared(), 1e-9)
	var dn := rel.dot(px_n) / maxf(px_n.length_squared(), 1e-9)
	return Vector2(du, dn)


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)
