## Geometría procedural del trozo de chapa de puerta: superficie curva, cantos, paredes del surco, rebabas e
## hilos de plástico fundido. Todo comparte el shader corte_chapa.gdshader, que colorea por atributos:
##   UV  = (u, v) en mm sobre la superficie exterior: u a lo largo del corte (el corte empieza en el canto u = 0),
##         v a través (el surco está centrado en v = 0);
##   UV2 = (profundidad en mm desde la cara pintada, tipo de cara): 0 cara pintada · 1 cara interior · 2 canto
##         (sección) · 3 pared del surco · 4 rebaba · 5 hilo de plástico · 6 fondo de un surco sin atravesar.
## Modo manual (build_manual_walls, build_manual_burrs): paredes, fondo y rebabas de toda la línea de corte, hechas una
## vez por chapa; el shader corte_manual.gdshader las coloca con el mapa del surco de core/taller/radial_manual.gd.
## Unidades de la escena: metros. Solo geometría y dibujo: los tamaños (surco, rebaba…) llegan del modelo.
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")

## Tamaño del trozo de chapa (mm).
const U_MAX := 230.0
const V_MIN := -80.0
const V_MAX := 80.0
## Curvatura de una puerta: bombeo transversal (radio ~1,1 m) y longitudinal suave (~3,5 m), con una línea de
## carácter (arista viva) a v = −45 mm. Formas de dibujo, no medidas de un coche concreto.
const R_V := 1.1
const R_U := 3.5
const U_MID := 115.0
const CREASE_V := -45.0
const CREASE_H_MM := 1.1
const CREASE_W_MM := 7.0

const FACE_OUTER := 0.0
const FACE_INNER := 1.0
const FACE_EDGE := 2.0
const FACE_WALL := 3.0
const FACE_BURR := 4.0
const FACE_THREAD := 5.0
const FACE_FLOOR := 6.0  # fondo de un surco que aún no atraviesa (modo manual)
## Paso (mm) a lo largo de la línea de las mallas del modo manual.
const MANUAL_STEP_MM := 0.5
const BURR_STEP_MM := 0.35

## Sentido de giro de las caras visibles en Godot (horario visto desde delante): con WINDING = −1, el producto
## (b − a) × (c − a) apunta en contra de la normal de la cara.
const WINDING := -1.0


## Altura (m) de la cara pintada en (u, v) mm.
static func height(u: float, v: float) -> float:
	var x := (u - U_MID) / 1000.0
	var z := v / 1000.0
	var y := -z * z / (2.0 * R_V) - x * x / (2.0 * R_U)
	var c := clampf(1.0 - absf(v - CREASE_V) / CREASE_W_MM, 0.0, 1.0)
	return y + CREASE_H_MM / 1000.0 * c * c * (3.0 - 2.0 * c)


## Punto de la cara pintada (m) en (u, v) mm.
static func surface(u: float, v: float) -> Vector3:
	return Vector3(u / 1000.0, height(u, v), v / 1000.0)


## Normal de la cara pintada (hacia fuera, hacia +y).
static func normal(u: float, v: float) -> Vector3:
	var e := 0.25
	var du := (height(u + e, v) - height(u - e, v)) / (2.0 * e / 1000.0)
	var dv := (height(u, v + e) - height(u, v - e)) / (2.0 * e / 1000.0)
	return Vector3(-du, 1.0, -dv).normalized()


## Punto (m) a una profundidad d (mm) bajo la cara pintada.
static func inside(u: float, v: float, d: float) -> Vector3:
	return surface(u, v) - normal(u, v) * (d / 1000.0)


## Centro del surco a la profundidad d (mm): con el disco inclinado, el surco se ladea tan(α)·d.
static func kerf_center(d: float, tilt_tan: float) -> float:
	return tilt_tan * d


## Semiancho del surco en la dirección v (mm): kerf/(2·cos α).
static func kerf_half(kerf_mm: float, tilt_tan: float) -> float:
	return 0.5 * kerf_mm * sqrt(1.0 + tilt_tan * tilt_tan)


## Vértice para tri(): posición (m), normal, (u, v) y (profundidad, cara).
static func vx(pos: Vector3, n: Vector3, uv: Vector2, depth: float, face: float) -> Dictionary:
	return {"p": pos, "n": n, "uv": uv, "uv2": Vector2(depth, face)}


## Triángulo orientado según la normal de su primer vértice (sea cual sea el orden en que llegan).
static func tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	var pa: Vector3 = a["p"]
	var pb: Vector3 = b["p"]
	var pc: Vector3 = c["p"]
	var g := (pb - pa).cross(pc - pa)
	var n: Vector3 = a["n"]
	var tri := [a, b, c] if g.dot(n) * WINDING >= 0.0 else [a, c, b]
	for v in tri:
		st.set_normal(v["n"])
		st.set_uv(v["uv"])
		st.set_uv2(v["uv2"])
		st.add_vertex(v["p"])


static func quad(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary, d: Dictionary) -> void:
	tri(st, a, b, c)
	tri(st, a, c, d)


## Filas en v: más densas junto al surco (v = 0) y en la línea de carácter.
static func _v_rows() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var v := V_MIN
	while v < V_MAX - 1e-6:
		out.append(v)
		var fine := absf(v) < 12.0 or absf(v - CREASE_V) < 9.0
		v += 1.0 if fine else 4.0
	out.append(V_MAX)
	return out


static func _u_cols() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var u := 0.0
	while u < U_MAX - 1e-6:
		out.append(u)
		u += 1.0 if u < 6.0 else 5.0
	out.append(U_MAX)
	return out


## Chapa completa (sin surco: el surco lo abre el shader). total_mm: pintura + metal + cataforesis interior.
static func build_panel(total_mm: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var us := _u_cols()
	var vs := _v_rows()
	for face: float in [FACE_OUTER, FACE_INNER]:
		var depth := 0.0 if face == FACE_OUTER else total_mm
		var sgn := 1.0 if face == FACE_OUTER else -1.0
		for i in us.size() - 1:
			for j in vs.size() - 1:
				var q: Array[Dictionary] = []
				var corners := [
					Vector2(us[i], vs[j]), Vector2(us[i + 1], vs[j]), Vector2(us[i + 1], vs[j + 1]), Vector2(us[i], vs[j + 1])]
				for p: Vector2 in corners:
					q.append(vx(inside(p.x, p.y, depth), normal(p.x, p.y) * sgn, p, depth, face))
				quad(st, q[0], q[1], q[2], q[3])
	_edge(st, vs, true, 0.0, total_mm, Vector3(-1, 0, 0))
	_edge(st, vs, true, U_MAX, total_mm, Vector3(1, 0, 0))
	_edge(st, us, false, V_MIN, total_mm, Vector3(0, 0, -1))
	_edge(st, us, false, V_MAX, total_mm, Vector3(0, 0, 1))
	return st.commit()


## Un canto: tira entre la cara pintada y la interior a lo largo de `line` (v si fixed_u, u si no).
static func _edge(
	st: SurfaceTool, line: PackedFloat32Array, fixed_u: bool, at: float, total_mm: float, out: Vector3
) -> void:
	for i in line.size() - 1:
		var a := Vector2(at, line[i]) if fixed_u else Vector2(line[i], at)
		var b := Vector2(at, line[i + 1]) if fixed_u else Vector2(line[i + 1], at)
		quad(st,
			vx(inside(a.x, a.y, 0.0), out, a, 0.0, FACE_EDGE),
			vx(inside(b.x, b.y, 0.0), out, b, 0.0, FACE_EDGE),
			vx(inside(b.x, b.y, total_mm), out, b, total_mm, FACE_EDGE),
			vx(inside(a.x, a.y, total_mm), out, a, total_mm, FACE_EDGE))


## Paredes del surco (3) de u = 0 a u_len, a ambos lados.
static func build_walls(kerf_mm: float, tilt_tan: float, total_mm: float, u_len: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := kerf_half(kerf_mm, tilt_tan)
	var lateral := Vector3(0, 0, 1).rotated(Vector3(1, 0, 0), -atan(tilt_tan))
	var step := 2.0
	for side: float in [-1.0, 1.0]:
		var n := -side * lateral  # la pared mira hacia dentro del surco
		var u := 0.0
		while u < u_len - 1e-6:
			var u2 := minf(u + step, u_len)
			var q: Array[Dictionary] = []
			for e in [[u, 0.0], [u2, 0.0], [u2, total_mm], [u, total_mm]]:
				var v: float = side * half + kerf_center(e[1], tilt_tan)
				var uv := Vector2(e[0], v)
				q.append(vx(inside(uv.x, uv.y, e[1]), n, uv, e[1], FACE_WALL))
			quad(st, q[0], q[1], q[2], q[3])
			u = u2
	return st.commit()


## Rebabas (4): un labio que cuelga del borde del surco en la cara de salida (la interior). heights_um: altura
## media [lado −, lado +] (el disco inclinado empuja más material hacia un lado). Con plástico (melt > 0) es un
## cordón fundido arriba y abajo. Dientes deterministas (gotas de metal resolidificado) con la semilla dada.
static func build_burrs(
	heights_um: Array, kerf_mm: float, tilt_tan: float, total_mm: float, u_len: float, melt: float, seed_text: String
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := Rng.new(Rng.seed_of(seed_text))
	var half := kerf_half(kerf_mm, tilt_tan)
	var faces := [total_mm] if melt <= 0.0 else [total_mm, 0.0]
	for face_d in faces:
		var down := 1.0 if face_d > 0.0 else -1.0  # hacia fuera de la chapa
		for si in 2:
			var side := -1.0 if si == 0 else 1.0
			var h_base := float(heights_um[si]) / 1000.0 * (1.0 if down > 0.0 else 0.6)
			if h_base <= 0.0:
				continue
			var step := 0.35
			var prev: Array = []
			var u := 0.0
			var tooth := 0.0
			while u <= u_len + 1e-6:
				tooth -= step
				var spike := 1.0
				if tooth <= 0.0:
					tooth = lerpf(0.5, 1.6, rng.next())
					spike = lerpf(1.25, 1.8, rng.next())
				var h := h_base * lerpf(0.55, 1.0, rng.next()) * spike
				if melt > 0.0:
					h = h_base * lerpf(0.7, 1.1, rng.next())
				var v_root := side * half + kerf_center(face_d, tilt_tan)
				var th := maxf(h * (0.9 if melt > 0.0 else 0.45), 0.02)
				var curl := h * (0.5 if melt > 0.0 else 0.3)
				# sección: A (arista del surco), B (hacia fuera, pegado a la chapa), C (punta, colgando y algo hacia fuera)
				var ring := [
					[Vector2(u, v_root), face_d],
					[Vector2(u, v_root + side * th), face_d],
					[Vector2(u, v_root + side * curl), face_d + down * h],
				]
				if prev.size() > 0:
					_burr_quad(st, prev[0], ring[0], ring[2], prev[2])
					_burr_quad(st, prev[2], ring[2], ring[1], prev[1])
				else:
					_burr_cap(st, ring)  # tapa en u = 0: la rebaba vista en la sección
				prev = ring
				u += step
	return st.commit()


static func _burr_point(e: Array) -> Vector3:
	var p: Vector2 = e[0]
	return inside(p.x, p.y, float(e[1]))


static func _burr_vx(e: Array, n: Vector3) -> Dictionary:
	return vx(_burr_point(e), n, e[0], float(e[1]), FACE_BURR)


## Cara de la rebaba por los dos lados (es fina y se ve desde dentro y desde fuera del surco).
static func _burr_quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	var pa := _burr_point(a)
	var g := (_burr_point(b) - pa).cross(_burr_point(c) - pa)
	if g.length_squared() < 1e-24:
		g = (_burr_point(c) - pa).cross(_burr_point(d) - pa)
	var n := g.normalized() if g.length_squared() > 0.0 else Vector3.DOWN
	for s: float in [1.0, -1.0]:
		quad(st, _burr_vx(a, n * s), _burr_vx(b, n * s), _burr_vx(c, n * s), _burr_vx(d, n * s))


static func _burr_cap(st: SurfaceTool, ring: Array) -> void:
	for s: float in [1.0, -1.0]:
		var n := Vector3(-1, 0, 0) * s
		tri(st, _burr_vx(ring[0], n), _burr_vx(ring[1], n), _burr_vx(ring[2], n))


## Hilos de plástico fundido (5): cuelgan de los bordes del surco o lo cruzan de lado a lado, combados.
static func build_threads(
	kerf_mm: float, tilt_tan: float, total_mm: float, u_len: float, melt: float, seed_text: String
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := Rng.new(Rng.seed_of(seed_text))
	var half := kerf_half(kerf_mm, tilt_tan)
	var count := int(round(melt * u_len * 0.45))
	for k in count:
		var u := rng.next() * u_len
		var bridge := rng.next() < 0.45
		var side := -1.0 if rng.next() < 0.5 else 1.0
		var top := rng.next() < 0.35
		var d0 := 0.0 if top else total_mm
		var pts := PackedVector3Array()
		var nseg := 10
		if bridge:
			var u2 := u + lerpf(-0.8, 0.8, rng.next())
			var sag := lerpf(0.3, 1.8, rng.next())
			var a := inside(u, -half + kerf_center(d0, tilt_tan), d0)
			var b := inside(u2, half + kerf_center(d0, tilt_tan), d0)
			var nrm := normal(u, 0.0)
			for s in nseg + 1:
				var t := float(s) / float(nseg)
				pts.append(a.lerp(b, t) - nrm * (sag / 1000.0) * 4.0 * t * (1.0 - t))
		else:
			var length := lerpf(2.0, 12.0, rng.next())
			var p := inside(u, side * half + kerf_center(d0, tilt_tan), d0)
			var out_dir := Vector3(0, 0, side)
			var nrm := normal(u, side * half)
			var drift := Vector3(lerpf(-0.4, 0.4, rng.next()), 0, 0)
			for s in nseg + 1:
				pts.append(p)
				var t := float(s) / float(nseg)
				var dir := (out_dir * (1.0 - t) * 0.8 - nrm * (0.4 + 1.2 * t) + drift).normalized()
				p += dir * (length / 1000.0 / float(nseg))
		_ribbon(st, pts, lerpf(0.06, 0.18, rng.next()) / 1000.0, u)
	return st.commit()


static func _ribbon(st: SurfaceTool, pts: PackedVector3Array, w: float, u: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var t := (b - a).normalized()
		var side := t.cross(Vector3.UP)
		if side.length_squared() < 1e-6:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized() * (w * 0.5)
		var n := side.cross(t).normalized()
		for s: float in [1.0, -1.0]:
			var q: Array[Dictionary] = []
			for p: Vector3 in [a - side, b - side, b + side, a + side]:
				q.append(vx(p, n * s, Vector2(u, 0.0), 0.0, FACE_THREAD))
			quad(st, q[0], q[1], q[2], q[3])


# ───────────────────────────── modo manual ─────────────────────────────
## Vértice de una malla del modo manual: en la línea central de la cara pintada (u, 0) y con la normal de la chapa;
## corte_manual.gdshader lo lleva a su sitio con el mapa del surco. uv = (u, lado), uv2 = (papel, cara).
static func _mv(st: SurfaceTool, u: float, side: float, role: float, face: float) -> void:
	st.set_normal(normal(u, 0.0))
	st.set_uv(Vector2(u, side))
	st.set_uv2(Vector2(role, face))
	st.add_vertex(surface(u, 0.0))


## Paredes del surco (3: papel 0 arriba y 1 abajo, a los dos lados) y su fondo (6), a lo largo de toda la línea y en la
## línea central: el vertex shader las abre con el mapa del surco. Se hacen una vez por chapa (nunca en un fotograma).
static func build_manual_walls(u_len: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u := 0.0
	while u < u_len - 1e-6:
		var u2 := minf(u + MANUAL_STEP_MM, u_len)
		for side: float in [-1.0, 1.0]:
			for e in [[u, 0.0], [u2, 0.0], [u2, 1.0], [u, 0.0], [u2, 1.0], [u, 1.0]]:
				_mv(st, e[0], side, e[1], FACE_WALL)
		for e in [[u, -1.0], [u2, -1.0], [u2, 1.0], [u, -1.0], [u2, 1.0], [u, 1.0]]:
			_mv(st, e[0], e[1], 1.0, FACE_FLOOR)
		u = u2
	return st.commit()


static func _bv(st: SurfaceTool, u: float, side: float, shape: Color) -> void:
	st.set_normal(normal(u, 0.0) * (-1.0 if shape.b > 0.5 else 1.0))
	st.set_uv(Vector2(u, side))
	st.set_uv2(Vector2(0.0, FACE_BURR))
	st.set_custom(0, shape)
	st.add_vertex(surface(u, 0.0))


## Rebabas del modo manual (4) a lo largo de toda la línea y a los dos lados: el labio de la cara de salida y, en
## plástico, también el cordón fundido de la cara pintada. Cada anillo lleva su forma por unidad de altura en CUSTOM0
## (salida lateral, caída, cara: 1 de salida · 0 pintada), con dientes deterministas como build_burrs; la altura de
## cada punto la pone el mapa del surco (0 donde no se ha atravesado: el labio no se ve). Se hacen una vez por chapa.
static func build_manual_burrs(u_len: float, plastic: bool, seed_text: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var rng := Rng.new(Rng.seed_of(seed_text))
	var faces: Array = [1.0, 0.0] if plastic else [1.0]
	for face_role: float in faces:
		for side: float in [-1.0, 1.0]:
			var prev: Array = []
			var u := 0.0
			var tooth := 0.0
			while u <= u_len + 1e-6:
				tooth -= BURR_STEP_MM
				var spike := 1.0
				if tooth <= 0.0:
					tooth = lerpf(0.5, 1.6, rng.next())
					spike = lerpf(1.25, 1.8, rng.next())
				var f := lerpf(0.55, 1.0, rng.next()) * spike
				if plastic:
					f = lerpf(0.7, 1.1, rng.next())
				# sección: A (arista del surco), B (hacia fuera, pegado a la chapa), C (punta, colgando algo hacia fuera)
				var ring := [
					[u, Color(0.0, 0.0, face_role, 0.0)],
					[u, Color(f * (0.9 if plastic else 0.45), 0.0, face_role, 0.0)],
					[u, Color(f * (0.5 if plastic else 0.3), f, face_role, 0.0)],
				]
				if prev.size() > 0:
					for q in [[prev[0], ring[0], ring[2], prev[2]], [prev[2], ring[2], ring[1], prev[1]]]:
						for k: int in [0, 1, 2, 0, 2, 3]:
							_bv(st, q[k][0], side, q[k][1])
				prev = ring
				u += BURR_STEP_MM
	return st.commit()
