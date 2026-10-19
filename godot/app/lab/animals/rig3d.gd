## Esqueleto de los animales en 3D (unidad 4l): huesos con su pivote y las mallas que cuelgan de cada uno.
##
## Por qué una jerarquía de nodos y no Skeleton3D: las poses de la vista son articulaciones claras (cadera, rodilla,
## tobillo, dedos, hombro, codo, muñeca, cuello, tramos de la cola) y cada pieza lleva su propio material (pluma, pelo,
## escama, queratina), así que un hueso = un Node3D con su malla rígida. Las uniones se esconden con casquetes del
## grosor de la sección (se solapan como músculo bajo la piel) y bajo el plumaje o el pelo. En cada fotograma solo se
## giran unos pocos nodos: nada de piel que recalcular en la CPU ni en la GPU, igual en Forward+, Mobile y
## Compatibility, y la vista puede girar la raíz entera (tres cuartos en un golpe de costado).
##
## La especie describe su cuerpo en la pose de reposo, en centímetros de su anatomía (los pies en el origen, el morro
## hacia +x, la y hacia arriba y el lado de quien mira hacia +z): huesos con su pivote absoluto y piezas (lofts) en
## coordenadas absolutas que Model pasa al marco de su hueso. Las posturas son giros de los huesos (en radianes), así
## que el tigre agazapado y de pie es el mismo tigre, con el mismo tamaño.
## Solo dibujo.
extends RefCounted

const Loft = preload("res://app/lab/animals/loft.gd")
const ClawGeo = preload("res://app/common/claw_geo.gd")


## Un modelo en construcción.
class Model:
	extends RefCounted
	## [{ name, parent, pivot (cm) }], los padres antes que los hijos.
	var bones: Array = []
	var index := {}
	var accs := {}
	## Puntos con nombre (cm, en reposo) y el hueso del que cuelgan: name → [bone, Vector3].
	var anchors := {}
	## Garras: [{ bone, tip_bone, tip (cm), len (cm), dir, far, name, base (cm), d0 y up (el marco de la base) }].
	var claws: Array = []
	## Materiales: id → { shader, … }.
	var mats := {}
	## Posturas: nombre → { hueso: Vector3 (giro en radianes, orden YXZ de Godot), «@hueso»: Vector3 (desplazamiento, cm) }.
	var postures := {}
	## Caja de referencia (cm): la del cuerpo en la postura de referencia (lo que tiene que caber en alto × largo).
	var fit := AABB()
	## Huesos cuyas mallas no cuentan en la caja (mechones, cola de los mamíferos, alas abiertas…).
	var fit_skip: Array = []
	## Lo demás (tipo, alas, colores de las garras…).
	var info := {}
	## 1 en el escritorio; 0,5 en el teléfono (anillos y segmentos).
	var detail := 1.0

	func _init(p_detail := 1.0) -> void:
		detail = p_detail

	## Un hueso: su padre ("" = la raíz del modelo) y su pivote absoluto (cm).
	func bone(name: String, parent: String, pivot: Vector3) -> void:
		index[name] = bones.size()
		bones.append({ "name": name, "parent": parent, "pivot": pivot })

	func pivot(name: String) -> Vector3:
		return bones[index[name]].pivot if index.has(name) else Vector3.ZERO

	## El acumulador de las piezas de un hueso (lo que se le añade pasa al marco del hueso).
	func acc(name: String) -> Loft.Acc:
		if not accs.has(name):
			var a := Loft.Acc.new()
			a.xf = Transform3D(Basis.IDENTITY, -pivot(name))
			accs[name] = a
		return accs[name]

	## Segmentos alrededor (par) y tramos a lo largo, según el detalle.
	func segs(n: int) -> int:
		return maxi(int(roundf(float(n) * lerpf(0.55, 1.0, detail) / 2.0)) * 2, 6)

	func rings(n: int) -> int:
		return maxi(int(roundf(float(n) * lerpf(0.5, 1.0, detail))), 2)

	## Un loft en el hueso b, con el detalle del modelo (o: como Loft.loft; segs y rings se escalan).
	func loft(b: String, mat: String, st: Array, o := {}) -> void:
		var oo := o.duplicate()
		oo["segs"] = segs(int(o.get("segs", 16)))
		oo["rings"] = rings(int(o.get("rings", 8)))
		Loft.loft(acc(b), mat, st, oo)

	func blob(b: String, mat: String, c: Vector3, axis: Vector3, half: float, hu: float, hd: float, w: float, o := {}) -> void:
		var oo := o.duplicate()
		oo["segs"] = segs(int(o.get("segs", 14)))
		oo["rings"] = rings(int(o.get("rings", 4)))
		Loft.blob(acc(b), mat, c, axis, half, hu, hd, w, oo)

	## Una garra que cuelga del hueso b (la base, casi toda la garra) y de su punta (el hueso tip_bone, hijo de b: se
	## dobla o se pierde): base, dirección, «arriba», largo (cm), alto y ancho de la base y curvatura (grados). La malla es la
	## de la biblioteca de materiales (ClawGeo.model_claw, unidad 5e): la misma línea media en arco, con s (mm desde la base)
	## en UV.x, la vuelta en UV.y y el radio (mm) en UV2.x, para que el material de cada garra (ClawMaterial) la vista sin
	## deformarla; la base, cerrada dentro del dedo.
	func claw(b: String, name: String, base: Vector3, dir: Vector3, up: Vector3, len: float, h: float, w: float, curve_deg: float, far := false) -> void:
		var d := dir.normalized()
		var u := (up - d * up.dot(d)).normalized()
		var side := d.cross(u).normalized()
		var frame := Basis(d, u, side)
		var base_bone := "garra_" + name
		var tip_bone := "garra_" + name + "_punta"
		# la punta: el último 40 % (una garra mellada lo pierde; una doblada lo tuerce)
		# unidad 4w: con más vueltas y tramos (de 10 × 14 a 24 × 28 en el escritorio): en «Garras de cerca» del coche, a ~50
		# aumentos, la garra se veía de pocos polígonos (la mitad en el teléfono, con detail)
		var g := ClawGeo.model_claw(len * 10.0, h * 10.0, w * 10.0, curve_deg, rings(10), rings(18), segs(24), 0.6)
		var cut_p := base + frame * ((g.cut_point as Vector3) * 0.1)
		var tip_p := base + frame * ((g.tip_point as Vector3) * 0.1)
		bone(base_bone, b, base)
		bone(tip_bone, base_bone, cut_p)
		_put_mm(base_bone, "garra", g.base, frame, base)
		_put_mm(tip_bone, "garra", g.tip, frame, base)
		# name, base, d0 y up: el marco de la base (la cetrería cuelga ahí su propia garra; unidad 5c)
		claws.append({ "bone": base_bone, "tip_bone": tip_bone, "tip": tip_p, "len": len, "dir": frame * (g.tip_dir as Vector3), "far": far,
			"name": name, "base": base, "d0": d, "up": u,
			# unidad 4y: lo que hace falta para la garra doblada o mellada de una pieza (en mm, en el marco frame; el corte, en
			# cut_mm: la punta cuelga de él)
			"geo": { "length": len * 10.0, "h": h * 10.0, "w": w * 10.0, "arc": curve_deg, "k": float(g.k), "cut_mm": g.cut_point,
				"frame": frame, "rows": rings(18), "ring": segs(24), "tip_arrays": g.tip } })
		fit_skip.append(base_bone)
		fit_skip.append(tip_bone)

	## Arrays en mm de ClawGeo (en el marco frame, con el origen en origin, cm) en la superficie mat del hueso b: los
	## vértices pasan a cm y al marco del hueso; UV y UV2 se quedan en mm (los lee el material).
	func _put_mm(b: String, mat: String, arrays: Array, frame: Basis, origin: Vector3) -> void:
		var a := acc(b)
		var q := a.s(mat)
		var first := q.v.size()
		var xf := a.xf
		var nb := xf.basis.orthonormalized()
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i in vs.size():
			q.v.append(xf * (origin + frame * (vs[i] * 0.1)))
			q.n.append((nb * (frame * ns[i])).normalized())
			var tw := (nb * (frame * Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2]))).normalized()
			q.t.append_array(PackedFloat32Array([tw.x, tw.y, tw.z, ts[i * 4 + 3]]))
			q.c.append(Color(1, 1, 1, 0))
			q.uv.append(uvs[i])
			q.uv2.append(uv2s[i])
		for j: int in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
			q.idx.append(first + j)

	## Un diente (colmillo): un cono curvo de una pieza en el hueso b, del material «diente» (no es una garra: no se tiñe
	## ni se rompe).
	func tooth(b: String, base: Vector3, dir: Vector3, up: Vector3, len: float, h: float, w: float, curve_deg: float) -> void:
		var d := dir.normalized()
		var u := (up - d * up.dot(d)).normalized()
		Loft.claw(acc(b), "diente", base, d, u, len, h, w, curve_deg, { "segs": segs(8), "rings": rings(5), "stations": 5 })

	## Postura por posiciones: los huesos de chain (de la raíz a la punta de una pata) giran en el plano sagital (en z)
	## hacia targets (cm, en el modelo; uno por articulación y, al final, el de la punta, cuya posición de reposo es
	## tip_rest). Los dos primeros huesos se resuelven con cinemática inversa de dos huesos (sus largos no cambian): la
	## segunda articulación cae justo en targets[2] y la del medio, en el lado de targets[1] (la pista del codo o la
	## rodilla). Los demás apuntan desde donde ha quedado su articulación. La primera articulación no se mueve.
	func pose_chain(post: String, chain: Array, targets: Array, tip_rest: Vector3) -> void:
		if not postures.has(post):
			postures[post] = {}
		var rot: Dictionary = postures[post]
		var tg := targets.duplicate()
		if chain.size() >= 2 and tg.size() >= 3:
			var p0: Vector3 = (globals_of(rot)[chain[0]] as Transform3D).origin
			var l1 := pivot(chain[1]).distance_to(pivot(chain[0]))
			var nxt2: Vector3 = pivot(chain[2]) if chain.size() > 2 else tip_rest
			var l2 := nxt2.distance_to(pivot(chain[1]))
			var t2: Vector3 = tg[2]
			var d := Vector2(t2.x - p0.x, t2.y - p0.y)
			var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
			var off := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
			var hint := Vector2((tg[1] as Vector3).x - p0.x, (tg[1] as Vector3).y - p0.y)
			var best := INF
			var joint := Vector2.ZERO
			for sgn: float in [1.0, -1.0]:
				var a := atan2(d.y, d.x) + sgn * off
				var j := Vector2(cos(a), sin(a)) * l1
				if j.distance_to(hint) < best:
					best = j.distance_to(hint)
					joint = j
			tg[1] = Vector3(p0.x + joint.x, p0.y + joint.y, (tg[1] as Vector3).z)
		for i in chain.size():
			var b: String = chain[i]
			var parent: String = bones[index[b]].parent
			var xf := globals_of(rot)
			var pb: Basis = (xf[parent] as Transform3D).basis if parent != "" and xf.has(parent) else Basis.IDENTITY
			var here: Vector3 = (xf[b] as Transform3D).origin
			var nxt: Vector3 = pivot(chain[i + 1]) if i + 1 < chain.size() else tip_rest
			var r := nxt - pivot(b)
			var dd := pb.inverse() * ((tg[i + 1] as Vector3) - here)
			rot[b] = Vector3(0, 0, atan2(dd.y, dd.x) - atan2(r.y, r.x))

	## Transformaciones de los huesos con la postura rot (como globals(), para este modelo en construcción).
	func globals_of(rot: Dictionary) -> Dictionary:
		var out := {}
		for b: Dictionary in bones:
			var name: String = b.name
			var parent: String = b.parent
			var local_pos: Vector3 = (b.pivot as Vector3) - (pivot(parent) if parent != "" else Vector3.ZERO) + (rot.get("@" + name, Vector3.ZERO) as Vector3)
			var t := Transform3D(Basis(Quaternion.from_euler(rot.get(name, Vector3.ZERO))), local_pos)
			out[name] = (out[parent] as Transform3D) * t if parent != "" and out.has(parent) else t
		return out

	## Termina: las mallas de cada hueso y todo lo que se guarda en la caché.
	func finish() -> Dictionary:
		var meshes := {}
		var verts := 0
		for name: String in accs:
			var a: Loft.Acc = accs[name]
			if a.surf.is_empty():
				continue
			verts += a.vertex_count()
			meshes[name] = a.commit()
		return { "bones": bones, "meshes": meshes, "anchors": anchors, "claws": claws, "mats": mats, "postures": postures, "fit": fit,
			"fit_skip": fit_skip, "info": info, "verts": verts }


## Transformaciones de reposo + postura de cada hueso, relativas a la raíz del modelo (cm): name → Transform3D. rot: el
## giro de cada hueso (Vector3, radianes) y, con la clave «@hueso», su desplazamiento (cm).
static func globals(data: Dictionary, rot: Dictionary) -> Dictionary:
	var out := {}
	for b: Dictionary in data.bones:
		var name: String = b.name
		var parent: String = b.parent
		var local_pos: Vector3 = b.pivot - (_pivot_of(data, parent) if parent != "" else Vector3.ZERO) + (rot.get("@" + name, Vector3.ZERO) as Vector3)
		var q := Quaternion.from_euler(rot.get(name, Vector3.ZERO))
		var t := Transform3D(Basis(q), local_pos)
		out[name] = (out[parent] as Transform3D) * t if parent != "" and out.has(parent) else t
	return out


static func _pivot_of(data: Dictionary, name: String) -> Vector3:
	for b: Dictionary in data.bones:
		if b.name == name:
			return b.pivot
	return Vector3.ZERO


## Caja (cm) de las mallas con las transformaciones dadas, sin las de los huesos de skip.
static func posed_box(data: Dictionary, xf: Dictionary, skip: Array = []) -> AABB:
	var out := AABB()
	var first := true
	for name: String in data.meshes:
		if skip.has(name):
			continue
		if not xf.has(name):
			continue
		var box := Loft.bounds((data.meshes[name] as Array)[0], xf[name])
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


## Sección de un loft cuyas estaciones ([Vector3 centro, arriba, abajo, lado]) van a lo largo de x: Vector4(y del eje,
## arriba, abajo, lado) en x (suavizado entre estaciones).
static func section_of(st: Array, x: float) -> Vector4:
	for i in st.size() - 1:
		var a: Array = st[i]
		var b: Array = st[i + 1]
		var xa := (a[0] as Vector3).x
		var xb := (b[0] as Vector3).x
		if x >= minf(xa, xb) and x <= maxf(xa, xb) and xa != xb:
			var t := smoothstep(0.0, 1.0, (x - xa) / (xb - xa))
			return Vector4(lerpf((a[0] as Vector3).y, (b[0] as Vector3).y, t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	var e: Array = st[0] if absf(x - (st[0][0] as Vector3).x) < absf(x - (st[st.size() - 1][0] as Vector3).x) else st[st.size() - 1]
	return Vector4((e[0] as Vector3).y, e[1], e[2], e[3])


## Punto de la superficie de ese loft en x, a un ángulo th desde el dorso (0) hacia el lado s (±1) y el vientre (π):
## [punto, normal hacia fuera, tangente hacia abajo].
static func surface_of(st: Array, x: float, th: float, s: float) -> Array:
	var e := section_of(st, x)
	var ry := e.y if cos(th) >= 0.0 else e.z
	var p := Vector3(x, e.x + ry * cos(th), s * e.w * sin(th))
	var nn := Vector3(0.0, cos(th) / maxf(ry, 0.1), s * sin(th) / maxf(e.w, 0.1)).normalized()
	var down := Vector3(0.0, -ry * sin(th), s * e.w * cos(th)).normalized()
	return [p, nn, down]


## Sección de un loft cuyas estaciones ([Vector3 centro, arriba, abajo, lado]) suben a lo largo de y (el tronco de un ave
## posada): Vector4(x del eje, arriba (la espalda), abajo (el pecho), lado) a la altura y.
static func section_of_y(st: Array, y: float) -> Vector4:
	for i in st.size() - 1:
		var a: Array = st[i]
		var b: Array = st[i + 1]
		var ya := (a[0] as Vector3).y
		var yb := (b[0] as Vector3).y
		if y >= minf(ya, yb) and y <= maxf(ya, yb) and ya != yb:
			var t := smoothstep(0.0, 1.0, (y - ya) / (yb - ya))
			return Vector4(lerpf((a[0] as Vector3).x, (b[0] as Vector3).x, t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	var e: Array = st[0] if y < (st[0][0] as Vector3).y else st[st.size() - 1]
	var f := 0.6 if y < (st[0][0] as Vector3).y else 1.0
	return Vector4((e[0] as Vector3).x, float(e[1]) * f, float(e[2]) * f, float(e[3]) * f)

