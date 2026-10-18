## Cetrería · la garra en 3D (dibujo, sin nodos): de la instantánea de ClawCare a los arrays de sus mallas, en mm (la
## escena los escala a metros con el nodo). Se puede llamar desde un hilo: solo crea arrays empaquetados.
##
## No calcula física: la forma es el perfil del motor (profile.s, profile.r y profile.core: el radio del estuche y el de
## la carne viva a lo largo de la curva, cada 0,5 mm, y la punta) y la curva es la del dibujo del banco (art.gd,
## _claw_geometry: la línea media gira 35° + 115°·curve a lo largo del largo natural; con el crecimiento de más, la
## misma curva sigue, como en una garra que se enrosca). Lo que es solo dibujo va marcado.
##
## La sección de cada garra (unidad 5h, petición 36) es una superelipse con su ancho, su alto (el de la cara de arriba y
## el de la de abajo) y lo redondeada que es cada mitad: la rapaz, redondeada y con la cara de abajo plana; el felino,
## comprimida de lado, alta y estrecha, con el filo abajo; el oso, gruesa y algo aplanada abajo; el velocirraptor, la hoz
## muy comprimida de lado. Con la medida del motor (la 5g: snapshot().claw.sectionRatio, k = alto/ancho, y ventralFlat),
## con el área de la física (redonda, de radio r): alto = 2·r·√k y ancho = 2·r/√k; sin ella, la de dibujo de su animal,
## con el radio del motor como alto de la cara de arriba. El arco medido (arcDeg) da la curva (claw_curvature). El rayo
## del puntero toca la misma superficie que se dibuja.
##
## Marco de la garra (mm): la base en el origen, la tangente de partida +X, la garra se curva hacia −Y (la cara ventral)
## y Z es el lado. UV.x = s (mm desde la base), UV.y = ángulo alrededor de la línea media (0-1, 0 arriba); UV2.x = radio
## (mm) y UV2.y = capa (0 estuche, 1 carne viva, 2 hueso, 3 acrílico, 4 la forma sana).
## Uso: var a := ClawMesh.tube_arrays(ss, rs, k, 40, 0.0, ClawMesh.section_of(view))  →  mesh.add_surface_from_arrays(…)
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")

## Segmentos de cada anillo (escritorio) y en el teléfono: con la sección comprimida y su filo hacen falta más que en un
## tubo redondo para que la silueta no se vea facetada de cerca.
const RING := 40
const RING_MOBILE := 20
## El hueso dentro de la carne viva: esta fracción de su radio (dibujo; el motor da el núcleo con su dermis).
const BONE_FRACTION := 0.72
## Lado de la garra (constante: la curva es plana).
const LATERAL := Vector3(0.0, 0.0, 1.0)
## La sección de cada tipo de animal (dibujo, petición 36): w, el medio ancho (fracción del radio del motor); h, el alto
## de la cara de arriba (1 si falta); b, el de la cara de abajo (fracción del de arriba); n_top y n_bot, el exponente de la
## superelipse de cada mitad (2: redonda; más: más plana; menos: con filo).
const SECTIONS := {
	"ave": { "w": 0.84, "b": 0.86, "n_top": 2.0, "n_bot": 3.2 },
	"felino": { "w": 0.58, "b": 1.0, "n_top": 2.25, "n_bot": 1.5 },
	"oso": { "w": 0.74, "b": 0.92, "n_top": 2.1, "n_bot": 2.4 },
	"dinosaurio": { "w": 0.5, "b": 1.0, "n_top": 2.15, "n_bot": 1.6 },
}
const ROUND := { "w": 1.0, "b": 1.0, "n_top": 2.0, "n_bot": 2.0 }
const KIND_OF := { "rapaz": "ave", "tigre": "felino", "oso": "oso", "velociraptor": "dinosaurio" }
## Pasos de la bisección del rayo (la entrada, a menos de una milésima de milímetro) y tramos de cada grupo del descarte.
const RAY_STEPS := 18
const RAY_CHUNK := 8
## Tolerancia de las estaciones de la punta (mm).
const STATION_EPS := 1e-4
## La punta de la lupa en la malla: hasta dónde (mm desde el vértice) y uno de cada cuántos de sus anillos (dibujo: lo que se ve
## de cerca sin rehacer una malla mucho más pesada en cada pasada).
const TIP_MESH_MM := 1.2
const TIP_MESH_STRIDE := 4
## Lo que se hunde la cara de una mella (fracción del radio de la cara; dibujo).
const CHIP_DEPTH := 0.6
## La faceta con caras planas (dibujo): el exponente de la mitad de arriba de la sección (1: dos planos) y en qué parte del
## largo de la faceta pasa de la sección de la garra a la de las caras.
const FACET_N := 1.0
const FACET_BLEND := 0.3


## Curvatura de la línea media (1/mm): el giro del dibujo del banco a lo largo del largo natural.
static func curvature(natural_mm: float, curve: float) -> float:
	return deg_to_rad(35.0 + 115.0 * curve) / maxf(natural_mm, 1.0)


## La curvatura de la garra de una instantánea (snap.claw): el arco medido de la garra de ese dedo, si lo trae (arcDeg: la
## fuente única del arco, CareData.CLAW_SHAPES de la 5g, con Fowler et al. 2009, tabla S1, en las rapaces), a lo largo de su
## largo natural; si no, el del dibujo del banco (35° + 115°·curve). La garra que ha crecido de más sigue la misma curva.
static func claw_curvature(claw: Dictionary) -> float:
	var nat := float(claw.get("naturalMm", 30.0))
	if claw.get("arcDeg") != null and float(claw.arcDeg) > 0.0:
		return deg_to_rad(float(claw.arcDeg)) / maxf(nat, 1.0)
	return curvature(nat, float(claw.get("curve", 0.5)))


## La sección de la garra de una vista de ClawCareState (o de una instantánea): la de dibujo de su animal, con la medida
## de cada garra si la trae: de la 5g, sectionRatio (k, alto/ancho en la base, con el área de la física: alto = 2·r·√k y
## ancho = 2·r/√k; la cara de abajo guarda su proporción con la de arriba) y ventralFlat (la cara de abajo plana); o
## claw.section (los parámetros, con su fuente).
static func section_of(view: Dictionary) -> Dictionary:
	var sn: Dictionary = view.get("snap", view)
	var kind := String(KIND_OF.get(String(sn.get("animal_id", "")), ""))
	var out: Dictionary = (SECTIONS.get(kind, ROUND) as Dictionary).duplicate()
	out["h"] = 1.0
	var c: Dictionary = sn.get("claw", {})
	if bool(c.get("ventralFlat", false)):
		out["n_bot"] = maxf(float(out.n_bot), float(SECTIONS.ave.n_bot))
		out["b"] = minf(float(out.b), float(SECTIONS.ave.b))
	var ratio: Variant = c.get("sectionRatio")
	if ratio != null and float(ratio) > 0.0:
		var sk := sqrt(float(ratio))
		out["w"] = 1.0 / sk
		out["h"] = 2.0 * sk / (1.0 + float(out.b))
	var given: Variant = c.get("section")
	if given is Dictionary:
		for key: String in ["w", "h", "b", "n_top", "n_bot"]:
			if (given as Dictionary).has(key):
				out[key] = float((given as Dictionary)[key])
	out["w"] = clampf(float(out.w), 0.2, 2.0)
	out["h"] = clampf(float(out.h), 0.5, 3.0)
	out["b"] = clampf(float(out.b), 0.2, 1.0)
	return out


## Lo más lejos de la línea media que llega la sección, en radios del motor (el rayo del puntero lo usa de cota).
static func section_reach(sec: Dictionary) -> float:
	return maxf(maxf(float(sec.get("h", 1.0)), float(sec.get("w", 1.0))), 1.0)


## Punto de la línea media en s (mm).
static func point_at(s: float, k: float) -> Vector3:
	if absf(k) < 1e-9:
		return Vector3(s, 0.0, 0.0)
	return Vector3(sin(k * s) / k, (cos(k * s) - 1.0) / k, 0.0)


## Tangente (hacia la punta) en s.
static func tangent_at(s: float, k: float) -> Vector3:
	return Vector3(cos(k * s), -sin(k * s), 0.0)


## Arriba (la cara dorsal, hacia fuera de la curva) en s.
static func up_at(s: float, k: float) -> Vector3:
	return Vector3(sin(k * s), cos(k * s), 0.0)


## Punto de la sección de radio 1 en la fracción a (0-1) de la vuelta: (alto, lado) = (y, z); 0 arriba, 0,25 al lado +Z.
static func section_yz(a: float, sec: Dictionary) -> Vector2:
	var ang := a * TAU
	var c := cos(ang)
	var s := sin(ang)
	var top := c >= 0.0
	var n := float(sec.get("n_top", 2.0)) if top else float(sec.get("n_bot", 2.0))
	var e := 2.0 / maxf(n, 0.5)
	var y := signf(c) * pow(absf(c), e) * (1.0 if top else float(sec.get("b", 1.0))) * float(sec.get("h", 1.0))
	var z := signf(s) * pow(absf(s), e) * float(sec.get("w", 1.0))
	return Vector2(y, z)


## Dirección radial de un anillo en s y en la fracción a de la vuelta (sección redonda): 0 arriba, 0,25 al lado +Z.
static func radial_at(s: float, k: float, a: float) -> Vector3:
	var ang := a * TAU
	return up_at(s, k) * cos(ang) + LATERAL * sin(ang)


## Punto de la superficie de radio r en s y a, con la sección sec (redonda si se omite).
static func surface_point(s: float, r: float, k: float, a: float, sec: Dictionary = ROUND) -> Vector3:
	var yz := section_yz(a, sec)
	return point_at(s, k) + up_at(s, k) * (yz.x * r) + LATERAL * (yz.y * r)


## Arrays de un tubo a lo largo de la línea media con radios rs en las estaciones ss (mm) y la sección sec. La base queda
## abierta (entra en el dedo). En la punta: cara plana si el último radio es > 0, o un vértice. layer: la capa de UV2.y.
## Las normales son las de la superficie (la sección y lo que cambia el radio a lo largo), así la silueta es suave.
static func tube_arrays(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, ring: int, layer: float = 0.0, sec: Dictionary = ROUND,
		cap := true) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := mini(ss.size(), rs.size())
	# hasta la última estación con radio (la carne viva acaba antes que el estuche)
	var last := n - 1
	while last > 0 and rs[last] <= 0.0 and rs[last - 1] <= 0.0:
		last -= 1
	if last < 1:
		return _pack(verts, norms, uvs, uv2s, idx)
	var cols := ring + 1
	# la sección y su derivada alrededor, una vez por anillo (iguales en todas las estaciones)
	var yz := PackedVector2Array()
	var dyz := PackedVector2Array()
	var eps := 0.25 / float(ring)
	for j in cols:
		var a := float(j) / float(ring)
		yz.append(section_yz(a, sec))
		dyz.append((section_yz(a + eps, sec) - section_yz(a - eps, sec)) / (2.0 * eps))
	for i in last + 1:
		var s := ss[i]
		var r := maxf(rs[i], 0.0)
		# pendiente del radio (para la normal): diferencias centradas
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, last)
		var ds := ss[i1] - ss[i0]
		var drds := (rs[i1] - rs[i0]) / ds if ds > 1e-9 else 0.0
		var p := point_at(s, k)
		var t := tangent_at(s, k)
		var up := up_at(s, k)
		for j in cols:
			var o := up * yz[j].x + LATERAL * yz[j].y
			verts.append(p + o * r)
			# ∂S/∂a ∝ up·y' + lado·z'; ∂S/∂s = t·(1 + r·k·y) + r'·o (up' = k·t)
			var da := up * dyz[j].x + LATERAL * dyz[j].y
			var dsv := t * (1.0 + r * k * yz[j].x) + o * drds
			var nrm := da.cross(dsv)
			if nrm.dot(o) < 0.0:
				nrm = -nrm
			norms.append(nrm.normalized() if nrm.length_squared() > 1e-14 else o.normalized())
			uvs.append(Vector2(s, float(j) / float(ring)))
			uv2s.append(Vector2(r, layer))
	for i in last:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	# la punta: cara plana (un abanico) si queda radio; si no, el último anillo ya es un punto
	var r_end := rs[last]
	var s_end := ss[last]
	if r_end > 0.0 and cap:
		_cap(verts, norms, uvs, uv2s, idx, s_end, r_end, k, ring, layer, yz, tangent_at(s_end, k))
	return _pack(verts, norms, uvs, uv2s, idx)


## La punta limada con caras planas (vuelta de pulido de la 5s): el tramo de la faceta como tube_arrays, pero con la mitad
## de arriba de la sección en dos planos (superelipse de exponente FACET_N: la lima deja caras, no un cono), pasando de la
## sección de la garra a la de las caras en los primeros blend_mm (sin hueco en la arista). Solo el dibujo: el motor la
## trata como un cono del mismo radio (UV2.x, el radio del motor, igual).
static func facet_arrays(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, ring: int, sec: Dictionary, blend_mm: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := mini(ss.size(), rs.size())
	if n < 2:
		return _pack(verts, norms, uvs, uv2s, idx)
	var flat := sec.duplicate()
	flat["n_top"] = FACET_N
	var cols := ring + 1
	var round_yz := PackedVector2Array()
	var flat_yz := PackedVector2Array()
	for j in cols:
		var a := float(j) / float(ring)
		round_yz.append(section_yz(a, sec))
		flat_yz.append(section_yz(a, flat))
	var grid: Array = []
	var last_yz := PackedVector2Array()
	for i in n:
		var w := smoothstep(0.0, maxf(blend_mm, 1e-6), ss[i] - ss[0])
		var p := point_at(ss[i], k)
		var up := up_at(ss[i], k)
		var r := maxf(rs[i], 0.0)
		last_yz = PackedVector2Array()
		for j in cols:
			var yz := round_yz[j].lerp(flat_yz[j], w)
			last_yz.append(yz)
			verts.append(p + (up * yz.x + LATERAL * yz.y) * r)
			uvs.append(Vector2(ss[i], float(j) / float(ring)))
			uv2s.append(Vector2(r, 0.0))
		grid.append(p)
	# las normales, de la malla (diferencias en los dos sentidos): planas en cada cara
	for i in n:
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, n - 1)
		for j in cols:
			var jm := (j - 1 + ring) % ring
			var jp := (j + 1) % ring
			var da := verts[i * cols + jp] - verts[i * cols + jm]
			var dsv := verts[i1 * cols + j] - verts[i0 * cols + j]
			if dsv.length_squared() < 1e-16:
				dsv = tangent_at(ss[i], k)
			var o := verts[i * cols + j] - (grid[i] as Vector3)
			var nrm := da.cross(dsv)
			if nrm.dot(o) < 0.0:
				nrm = -nrm
			norms.append(nrm.normalized() if nrm.length_squared() > 1e-20 else o.normalized())
	for i in n - 1:
		for j in ring:
			var a0 := i * cols + j
			var b0 := (i + 1) * cols + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	if rs[n - 1] > 0.0:
		_cap(verts, norms, uvs, uv2s, idx, ss[n - 1], rs[n - 1], k, ring, 0.0, last_yz, tangent_at(ss[n - 1], k))
	return _pack(verts, norms, uvs, uv2s, idx)


## Una tapa plana en s (radio r): un abanico de cara a dir (la punta limada, o el corte de un trozo que cae).
static func _cap(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array, idx: PackedInt32Array,
		s: float, r: float, k: float, ring: int, layer: float, yz: PackedVector2Array, dir: Vector3) -> void:
	var p := point_at(s, k)
	var up := up_at(s, k)
	var c := verts.size()
	verts.append(p)
	norms.append(dir)
	uvs.append(Vector2(s, 0.0))
	uv2s.append(Vector2(0.0, layer))
	var base := verts.size()
	for j in ring + 1:
		verts.append(p + (up * yz[j].x + LATERAL * yz[j].y) * r)
		norms.append(dir)
		uvs.append(Vector2(s, float(j) / float(ring)))
		uv2s.append(Vector2(r, layer))
	var forward := dir.dot(tangent_at(s, k)) > 0.0
	for j in ring:
		if forward:
			idx.append_array([c, base + j + 1, base + j])
		else:
			idx.append_array([c, base + j, base + j + 1])


static func _pack(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


## ¿Tiene triángulos?
static func has_triangles(arrays: Array) -> bool:
	return arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >= 3


## Corte longitudinal (vista de sección): una banda en el plano de la curva (z = z0) de −r a +r a lo largo de la línea
## media, con UV2.y = capa. Las capas se dibujan unas delante de otras (z0 crece hacia la cámara).
static func band_arrays(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, z0: float, layer: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := mini(ss.size(), rs.size())
	var last := n - 1
	while last > 0 and rs[last] <= 0.0 and rs[last - 1] <= 0.0:
		last -= 1
	if last < 1:
		return _pack(verts, norms, uvs, uv2s, idx)
	for i in last + 1:
		var p := point_at(ss[i], k)
		var u := up_at(ss[i], k)
		var r := maxf(rs[i], 0.0)
		for side: float in [1.0, -1.0]:
			verts.append(p + u * r * side + Vector3(0.0, 0.0, z0))
			norms.append(LATERAL)
			uvs.append(Vector2(ss[i], 0.5 + 0.5 * side))
			uv2s.append(Vector2(r, layer))
	for i in last:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	return _pack(verts, norms, uvs, uv2s, idx)


## Radios del hueso (dibujo): BONE_FRACTION del de la carne viva.
static func bone_radii(core: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(core.size())
	for i in core.size():
		out[i] = core[i] * BONE_FRACTION
	return out


## La forma natural sana de la garra (la de su ficha, sin el crecimiento de más): el perfil de partida corrido lo que
## creció de más (el motor lo construye desde la punta: el radio depende de la distancia a la punta). Sin cuentas nuevas:
## los mismos números del perfil de partida. → { s, r } (vacío si no hay perfil de partida).
static func natural_profile(view: Dictionary) -> Dictionary:
	var init: Dictionary = view.get("initial_profile", {})
	if not init.has("s"):
		return {}
	var c: Dictionary = view.snap.claw
	var shift := maxf(float(c.startMm) - float(c.naturalMm), 0.0)
	var nat := float(c.naturalMm)
	var ss0: PackedFloat64Array = init.s
	var rs0: PackedFloat64Array = init.r
	var ss := PackedFloat64Array()
	var rs := PackedFloat64Array()
	for i in mini(ss0.size(), rs0.size()):
		var s := ss0[i] - shift
		if s < 0.0:
			continue
		if ss.is_empty() and s > 0.0:
			# la estación de la base, en s = 0 (interpolada)
			ss.append(0.0)
			rs.append(radius_at(ss0, rs0, shift))
		ss.append(minf(s, nat))
		rs.append(rs0[i])
	return { "s": ss, "r": rs }


## Todas las mallas de la garra para una vista de ClawCareState (sheath: el estuche; block: el bloque reforjado en bruto
## sobre el muñón, de claw.block.fromMm a la punta, con su material, o vacío; quick y bone: la carne viva y el hueso, solo
## si se ven; section: las bandas del corte; ghost: la garra de partida, para el acrílico de la reconstrucción; healthy:
## la forma natural sana, la silueta para comparar; key: cambia si cambia la forma). ring: segmentos por anillo.
static func claw_arrays(view: Dictionary, ring: int = RING) -> Dictionary:
	var sn: Dictionary = view.snap
	var prof: Dictionary = sn.profile
	var ss: PackedFloat64Array = prof.s
	var rs: PackedFloat64Array = prof.r
	var core: PackedFloat64Array = prof.core
	var k := claw_curvature(sn.claw)
	var sec := section_of(view)
	var revealed := bool(view.hints.revealed)
	var inner := sec.duplicate()
	# la carne viva y el hueso, por dentro: la misma sección, algo más redonda
	inner["n_bot"] = lerpf(float(sec.n_bot), 2.0, 0.5)
	# con el bloque reforjado en bruto (la 5g: claw.block), el estuche acaba en el muñón y el bloque sigue hasta la punta
	var block: Variant = sn.claw.get("block")
	var from := float((block as Dictionary).get("fromMm", INF)) if block is Dictionary else INF
	var block_arr: Array = []
	var sheath: Array
	# la punta de verdad (unidad 5s): el radio y la faceta del motor a escala de micras (la ayuda del afilado, tip_help.lupa)
	var lp: Dictionary = (view.get("tip_help", {}) as Dictionary).get("lupa", {})
	var tip := refine_tip(ss, rs, lp)
	var ts: PackedFloat64Array = tip.s
	var tr: PackedFloat64Array = tip.r
	var fl := float(lp.get("facetLenMm", 0.0))
	if from < float(sn.claw.lengthMm):
		var parts := split_profile(ts, tr, from)
		sheath = tube_arrays(parts.a_s, parts.a_r, k, ring, 0.0, sec)
		block_arr = tube_arrays(parts.b_s, parts.b_r, k, ring, 0.0, sec)
	elif fl > STATION_EPS and fl < float(sn.claw.lengthMm) - STATION_EPS:
		# la faceta, una cara de corte limpio: la malla se parte donde empieza (la arista, con las normales de cada lado)
		var at := float(lp.apexMm) - fl
		var fp := split_profile(ts, tr, at)
		(fp.a_r as PackedFloat64Array)[(fp.a_r as PackedFloat64Array).size() - 1] = float(lp.get("facetFromR", 0.0))
		(fp.b_r as PackedFloat64Array)[0] = float(lp.get("facetFromR", 0.0))
		sheath = merge_arrays(tube_arrays(fp.a_s, fp.a_r, k, ring, 0.0, sec, false), facet_arrays(fp.b_s, fp.b_r, k, ring, sec, FACET_BLEND * fl))
	else:
		sheath = tube_arrays(ts, tr, k, ring, 0.0, sec)
	if bool(lp.get("chipped", false)) and block_arr.is_empty():
		chip_cap(sheath, ring, k, float(lp.apexMm), float(lp.get("flatMm", 0.0)), String((lp.get("chip", {}) as Dictionary).get("seed", "mella")))
	_notch(sheath, sn.get("damage", {}).get("splits", []))
	_notch(block_arr, sn.get("damage", {}).get("splits", []))
	var out := {
		"key": geometry_key(view), "k": k, "ring": ring, "shape": sec,
		"sheath": sheath, "block": block_arr,
		"quick": tube_arrays(ss, core, k, ring, 1.0, inner) if revealed else [],
		"bone": tube_arrays(ss, bone_radii(core), k, maxi(ring / 2, 8), 2.0, inner) if revealed else [],
		"section": {
			"sheath": band_arrays(ss, rs, k, 0.0, 0.0),
			"quick": band_arrays(ss, core, k, 0.02, 1.0) if revealed else [],
			"bone": band_arrays(ss, bone_radii(core), k, 0.04, 2.0) if revealed else [],
		},
		"apex": float(sn.claw.lengthMm), "tip": point_at(float(sn.claw.lengthMm), k),
		"profile": { "s": ss, "r": rs },
	}
	var init: Dictionary = view.get("initial_profile", {})
	if init.has("s"):
		out["ghost"] = tube_arrays(init.s, init.r, k, ring, 3.0, sec)
	var nat := natural_profile(view)
	if nat.has("s"):
		out["healthy"] = tube_arrays(nat.s, nat.r, k, maxi(ring * 3 / 4, 12), 4.0, sec)
		out["healthy_profile"] = nat
	return out


## La punta del perfil del motor a escala de micras (unidad 5s): las estaciones de snap.profile (cada 0,5 mm) hasta donde
## empieza la lupa de la punta y, desde ahí, las suyas (lp = SharpenHelp.lupa: más juntas cerca del vértice; la esfera de la
## punta de su radio, la cara plana o la punta natural). Así se ve la diferencia entre una punta de 113 µm y una aguja de
## 5 µm, y la faceta recta. Sin lupa, el perfil tal cual. → { s, r }.
static func refine_tip(ss: PackedFloat64Array, rs: PackedFloat64Array, lp: Dictionary) -> Dictionary:
	if lp.is_empty() or not lp.has("d") or (lp.d as PackedFloat64Array).size() < 2:
		return { "s": ss, "r": rs }
	var a := float(lp.apexMm)
	var ld: PackedFloat64Array = lp.d
	var lr: PackedFloat64Array = lp.r
	# en la malla, hasta TIP_MESH_MM del vértice y un anillo de cada TIP_MESH_STRIDE de la lupa (el primero, el del vértice, siempre)
	var last := ld.size() - 1
	while last > 1 and ld[last] > TIP_MESH_MM:
		last -= 1
	var cut := a - ld[last]
	var os := PackedFloat64Array()
	var orr := PackedFloat64Array()
	for i in mini(ss.size(), rs.size()):
		if ss[i] < cut - STATION_EPS:
			os.append(ss[i])
			orr.append(rs[i])
	for j in range(last, -1, -1):
		if j != 0 and j != last and j % TIP_MESH_STRIDE != 0:
			continue
		var s := a - ld[j]
		if not os.is_empty() and s <= os[os.size() - 1] + 1e-7:
			continue
		os.append(s)
		orr.append(lr[j])
	if os.size() < 2:
		return { "s": ss, "r": rs }
	return { "s": os, "r": orr }


## Dos juegos de arrays de malla en uno (los índices del segundo, corridos).
static func merge_arrays(a: Array, b: Array) -> Array:
	if not has_triangles(a):
		return b
	if not has_triangles(b):
		return a
	var off := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var out := a.duplicate()
	for t: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var x: Variant = a[t].duplicate()
		x.append_array(b[t])
		out[t] = x
	var idx: PackedInt32Array = (a[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	for i: int in b[Mesh.ARRAY_INDEX]:
		idx.append(i + off)
	out[Mesh.ARRAY_INDEX] = idx
	return out


## La punta mellada (unidad 5s; el motor la mella al probarla o al limarla si no aguanta de lado: damage.breaks «mella»): la cara
## de la rotura no es plana, sino un desconchón irregular. Hunde los vértices de la tapa de la punta (los últimos ring + 2 de
## tube_arrays) una fracción del radio de la cara, con un azar determinista por rotura (core/shared/rng.gd), y tuerce sus normales.
## Dibujo: la forma del desconchón no es un dato del motor.
static func chip_cap(arrays: Array, ring: int, k: float, apex: float, flat: float, seed_text: String) -> void:
	if not has_triangles(arrays) or flat <= 0.0:
		return
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var n := v.size()
	var first := n - (ring + 2)
	if first < 0:
		return
	var rng := Rng.new(Rng.seed_of(seed_text))
	var t := tangent_at(apex, k)
	var up := up_at(apex, k)
	var depth := CHIP_DEPTH * flat
	# el centro, hundido; el borde, a saltos (lo que se ha desprendido de cada lado)
	v[first] -= t * depth * (0.55 + 0.3 * rng.next())
	var lumps := PackedFloat64Array()
	for j in 7:
		lumps.append(rng.next())
	for j in ring + 1:
		var u := float(j % ring) / float(ring) * 7.0
		var i0 := int(floorf(u)) % 7
		var w := u - floorf(u)
		var h := lumps[i0] * (1.0 - w) + lumps[(i0 + 1) % 7] * w
		v[first + 1 + j] -= t * depth * (0.15 + 0.85 * h)
		nr[first + 1 + j] = (t + (up * (rng.next() - 0.5) + LATERAL * (rng.next() - 0.5)) * 0.9).normalized()
	nr[first] = (t + up * 0.2).normalized()
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nr


## Un perfil partido en s = at (mm): { a_s, a_r } de la base hasta at y { b_s, b_r } de at a la punta, los dos con la
## estación de at (interpolada).
static func split_profile(ss: PackedFloat64Array, rs: PackedFloat64Array, at: float) -> Dictionary:
	var a_s := PackedFloat64Array()
	var a_r := PackedFloat64Array()
	var b_s := PackedFloat64Array()
	var b_r := PackedFloat64Array()
	var r_at := radius_at(ss, rs, at)
	for i in mini(ss.size(), rs.size()):
		if ss[i] < at:
			a_s.append(ss[i])
			a_r.append(rs[i])
		elif ss[i] > at:
			if b_s.is_empty():
				b_s.append(at)
				b_r.append(r_at)
			b_s.append(ss[i])
			b_r.append(rs[i])
	a_s.append(at)
	a_r.append(r_at)
	if b_s.is_empty():
		b_s.append(at)
		b_r.append(r_at)
	return { "a_s": a_s, "a_r": a_r, "b_s": b_s, "b_r": b_r }


## Clave de la forma: cambia cuando cambia el perfil (lo arrancado, el largo, la cara plana), las grietas, si se ve la
## carne viva o la garra que se trabaja (cada una tiene su carne viva). Con la misma clave no hace falta rehacer las mallas.
static func geometry_key(view: Dictionary) -> String:
	var sn: Dictionary = view.snap
	var cracks := ""
	for c: Dictionary in sn.get("damage", {}).get("splits", []):
		cracks += "%s-%s;" % [var_to_str(float(c.get("from_s", 0.0))), var_to_str(float(c.get("to_s", 0.0)))]
	var block: Variant = sn.claw.get("block")
	var bk := "%s@%s" % [String(block.material), var_to_str(float(block.fromMm))] if block is Dictionary else ""
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [String(sn.claw_id), var_to_str(float(sn.claw.lengthMm)), var_to_str(float(sn.claw.removedMm3)),
		var_to_str(float(sn.tip.flatMm)), str(bool(view.hints.revealed)), str((sn.profile.s as PackedFloat64Array).size()),
		String(view.get("paw", "")), String(view.get("digit", "")), cracks, bk]


## Las grietas del motor (damage.splits: de from_s a to_s), abiertas en la malla: un surco en V por la línea de arriba
## (y otro más corto por la de abajo, en la mitad de la punta), que se abre hacia la punta. Dibujo: el ancho y la
## hondura del surco no son datos del motor (el sombreador pinta la raja y si llega a la carne viva).
static func _notch(arrays: Array, splits: Array) -> void:
	if splits.is_empty() or not has_triangles(arrays):
		return
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for i in v.size():
		var s := uv[i].x
		var a := uv[i].y
		var r := uv2[i].x
		var depth := 0.0
		for c: Dictionary in splits:
			var s0 := float(c.get("from_s", 0.0))
			var s1 := float(c.get("to_s", 0.0))
			if s < s0 or s > s1 or s1 <= s0:
				continue
			var open := smoothstep(s0, s0 + minf(0.8, (s1 - s0) * 0.5), s)
			var d_top := absf(fposmod(a + 0.5, 1.0) - 0.5)
			var d_bot := absf(a - 0.5)
			var w := 0.035
			var top := maxf(1.0 - d_top / w, 0.0)
			var bot := maxf(1.0 - d_bot / (w * 0.8), 0.0) * (1.0 if s >= s0 + 0.5 * (s1 - s0) else 0.0)
			depth = maxf(depth, r * 0.28 * open * maxf(top, bot * 0.7))
		if depth > 0.0:
			v[i] -= nr[i] * depth
	arrays[Mesh.ARRAY_VERTEX] = v


## Radio (mm) del perfil en s (interpolado; 0 más allá del último punto).
static func radius_at(ss: PackedFloat64Array, rs: PackedFloat64Array, s: float) -> float:
	var n := mini(ss.size(), rs.size())
	if n == 0 or s < 0.0 or s > ss[n - 1]:
		return 0.0
	for i in range(1, n):
		if s <= ss[i]:
			var u := (s - ss[i - 1]) / maxf(ss[i] - ss[i - 1], 1e-9)
			return lerpf(rs[i - 1], rs[i], u)
	return rs[n - 1]


## El trozo que se separa de la garra cuando se corta o se parte (dibujo de lo que dice el motor: el perfil de antes, de
## s_from hasta su punta), con la cara del corte cerrada. Centrado en su centro (mm): así gira sobre sí mismo al caer.
## → { arrays, center (en el marco de la garra), length } o {} si no queda trozo.
static func piece_arrays(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, ring: int, sec: Dictionary, s_from: float) -> Dictionary:
	var n := mini(ss.size(), rs.size())
	if n < 2 or s_from >= ss[n - 1] - 0.05:
		return {}
	var ps := PackedFloat64Array([s_from])
	var pr := PackedFloat64Array([radius_at(ss, rs, s_from)])
	for i in n:
		if ss[i] > s_from + 1e-6:
			ps.append(ss[i])
			pr.append(rs[i])
	var arrays := tube_arrays(ps, pr, k, ring, 0.0, sec)
	if not has_triangles(arrays):
		return {}
	# la cara del corte, de cara hacia la base
	var yz := PackedVector2Array()
	for j in ring + 1:
		yz.append(section_yz(float(j) / float(ring), sec))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_cap(verts, norms, uvs, uv2s, idx, s_from, pr[0], k, ring, 0.0, yz, -tangent_at(s_from, k))
	var center := point_at(0.5 * (s_from + ps[ps.size() - 1]), k)
	for i in verts.size():
		verts[i] -= center
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	return { "arrays": arrays, "center": center, "length": ps[ps.size() - 1] - s_from }


## El rayo (origen o, dirección d, en mm y en el marco de la garra) contra el estuche: { hit, s, point, normal, t }. Cada
## tramo entre estaciones es un tronco con la sección de la garra; los que pasan a menos de su radio del rayo son
## candidatos, y la entrada se busca por bisección contra todos ellos, desde el primer punto de dentro hacia atrás (así s
## sigue al puntero, sin saltar de estación en estación). grace (mm) engorda el estuche: la punta, de décimas de
## milímetro, se puede tocar con el ratón o el dedo. sec: la sección (redonda si se omite); la normal es la de esa
## superficie.
static func ray_hit(ss: PackedFloat64Array, rs: PackedFloat64Array, k: float, o: Vector3, d: Vector3, grace := 0.0, sec: Dictionary = ROUND,
		mid: PackedVector3Array = PackedVector3Array()) -> Dictionary:
	var best := { "hit": false, "s": -1.0, "point": Vector3.ZERO, "normal": Vector3.UP, "t": INF }
	var n := mini(ss.size(), rs.size())
	if n < 2 or d.length_squared() < 1e-12:
		return best
	var pts := mid if mid.size() == n else midline(ss, k)
	var dir := d.normalized()
	var segs: Array = []
	var t_in := INF
	var reach := 1.0
	# la sección puede ir más allá del radio del motor (alta y estrecha): la cota, con lo que llega
	var sr := section_reach(sec)
	# por grupos de RAY_CHUNK tramos, primero una esfera que los contiene: el rayo descarta de golpe casi toda la garra
	for c0 in range(0, n - 1, RAY_CHUNK):
		var c1 := mini(c0 + RAY_CHUNK, n - 1)
		var mr := 0.0
		for i in range(c0, c1 + 1):
			mr = maxf(mr, rs[i])
		var cc := (pts[c0] + pts[c1]) * 0.5
		var crad := 0.5 * absf(ss[c1] - ss[c0]) + mr * sr + grace + 1e-6
		var tc := maxf((cc - o).dot(dir), 0.0)
		if (o + dir * tc).distance_squared_to(cc) > crad * crad:
			continue
		for i in range(c0, c1):
			var a := pts[i]
			var b := pts[i + 1]
			var ra := rs[i] * sr + grace
			var rb := rs[i + 1] * sr + grace
			# descarte rápido: el centro del tramo, lejos del rayo (sin la cuenta entera ni diccionarios)
			var m := (a + b) * 0.5
			var tm0 := maxf((m - o).dot(dir), 0.0)
			if (o + dir * tm0).distance_squared_to(m) > pow(maxf(ra, rb) + 0.5 * a.distance_to(b) + 1e-6, 2.0):
				continue
			var cp := _closest_ray_segment(o, dir, a, b)
			if float(cp.dist) > maxf(ra, rb) + 1e-6:
				continue
			# [a, b, ra, rb, ¿el último?, i, arriba en a, arriba en b, lo cerca que pasa el rayo, centro, cota²]
			var bound := maxf(ra, rb) + 0.5 * a.distance_to(b) + 1e-6
			var seg := [a, b, rs[i], rs[i + 1], i == n - 2, i, up_at(ss[i], k), up_at(ss[i + 1], k), float(cp.dist), m,
				bound * bound]
			segs.append(seg)
			reach = maxf(reach, 2.0 * maxf(ra, rb) + a.distance_to(b) + 1.0)
			if float(cp.t) < t_in and not _outside_seg(o + dir * float(cp.t), seg, grace, sec):
				t_in = float(cp.t)
	if t_in == INF:
		return best
	# los tramos que más cerca pasan del rayo, primero: el que contiene el punto suele ser de los primeros
	segs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[8]) < float(y[8]))
	# un punto de fuera antes de la entrada (si la cámara está dentro de la garra, no hay toque)
	var t_out := maxf(t_in - reach, 0.0)
	while not _outside_all(o + dir * t_out, segs, grace, sec):
		if t_out <= 0.0:
			return best
		t_out = maxf(t_out - reach, 0.0)
	for it in RAY_STEPS:
		var tm := 0.5 * (t_in + t_out)
		if _outside_all(o + dir * tm, segs, grace, sec):
			t_out = tm
		else:
			t_in = tm
	var p := o + dir * t_in
	for seg: Array in segs:
		if _outside_seg(p, seg, grace, sec):
			continue
		var i := int(seg[5])
		var ab: Vector3 = seg[1] - seg[0]
		var u := clampf((p - (seg[0] as Vector3)).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
		var s := lerpf(ss[i], ss[i + 1], u)
		return { "hit": true, "s": s, "point": p, "normal": surface_normal(p, s, lerpf(rs[i], rs[i + 1], u) + grace, k, sec), "t": t_in }
	return best


## Los puntos de la línea media en cada estación (para el rayo: se calculan una vez por forma).
static func midline(ss: PackedFloat64Array, k: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(ss.size())
	for i in ss.size():
		out[i] = point_at(ss[i], k)
	return out


## Normal de la superficie (sección sec, radio r en s) en el punto p, cerca de ella: el gradiente de la superelipse.
static func surface_normal(p: Vector3, s: float, r: float, k: float, sec: Dictionary = ROUND) -> Vector3:
	var up := up_at(s, k)
	var rel := p - point_at(s, k)
	var y := rel.dot(up)
	var z := rel.dot(LATERAL)
	var top := y >= 0.0
	var n := float(sec.get("n_top", 2.0)) if top else float(sec.get("n_bot", 2.0))
	var ry := maxf(r * (1.0 if top else float(sec.get("b", 1.0))) * float(sec.get("h", 1.0)), 1e-6)
	var rz := maxf(r * float(sec.get("w", 1.0)), 1e-6)
	var gy := signf(y) * pow(absf(y) / ry, n - 1.0) / ry
	var gz := signf(z) * pow(absf(z) / rz, n - 1.0) / rz
	var nrm := up * gy + LATERAL * gz
	if nrm.length_squared() < 1e-14:
		return up if top else -up
	return nrm.normalized()


static func _outside_all(p: Vector3, segs: Array, grace: float, sec: Dictionary) -> bool:
	for seg: Array in segs:
		# lejos del tramo (fuera de la esfera que lo contiene): sin la cuenta entera; el último tramo, con su punta, entero
		if not bool(seg[4]) and p.distance_squared_to(seg[9] as Vector3) > float(seg[10]):
			continue
		if not _outside_seg(p, seg, grace, sec):
			return false
	return true


## ¿Está p fuera del tramo [a (radio ra), b (radio rb)] con la sección sec (engordada grace)? Lo que cae antes de a o
## después de b es del tramo vecino; en el último tramo (tip), más allá de b hay una esfera de radio rb + grace: la punta.
static func _outside_seg(p: Vector3, seg: Array, grace: float, sec: Dictionary) -> bool:
	var a: Vector3 = seg[0]
	var b: Vector3 = seg[1]
	var ab := b - a
	var len2 := ab.length_squared()
	var ra := float(seg[2])
	var rb := float(seg[3])
	var reach := section_reach(sec)
	if len2 < 1e-12:
		return p.distance_to(a) > maxf(ra, rb) * reach + grace
	var u := (p - a).dot(ab) / len2
	if u < 0.0:
		return true
	if u > 1.0:
		return not bool(seg[4]) or p.distance_to(b) > rb * reach + grace
	var r := lerpf(ra, rb, u)
	var up: Vector3 = (seg[6] as Vector3).lerp(seg[7] as Vector3, u).normalized()
	var rel := p - (a + ab * u)
	var y := rel.dot(up)
	var z := rel.dot(LATERAL)
	var top := y >= 0.0
	var n := float(sec.get("n_top", 2.0)) if top else float(sec.get("n_bot", 2.0))
	var ry := r * (1.0 if top else float(sec.get("b", 1.0))) * float(sec.get("h", 1.0)) + grace
	var rz := r * float(sec.get("w", 1.0)) + grace
	if ry <= 1e-9 or rz <= 1e-9:
		return true
	var qy := absf(y) / ry
	var qz := absf(z) / rz
	if qy > 1.0 or qz > 1.0:
		return true
	if n == 2.0:
		return qy * qy + qz * qz > 1.0
	return pow(qy, n) + pow(qz, n) > 1.0


## Acercamiento máximo entre un rayo (o + t·d, t ≥ 0) y un segmento [a, b]: { t, u (0-1 en el segmento), dist }.
static func _closest_ray_segment(o: Vector3, d: Vector3, a: Vector3, b: Vector3) -> Dictionary:
	var ab := b - a
	var len2 := ab.length_squared()
	var w := o - a
	var bb := d.dot(ab)
	var dd := d.dot(w)
	var ee := ab.dot(w)
	var den := len2 - bb * bb
	var u := 0.0
	if len2 > 1e-12:
		u = clampf((ee - bb * dd) / den, 0.0, 1.0) if absf(den) > 1e-12 else 0.0
	var t := maxf(bb * u - dd, 0.0)
	# vuelve a proyectar el punto del rayo sobre el segmento
	var q := o + d * t
	u = clampf((q - a).dot(ab) / len2, 0.0, 1.0) if len2 > 1e-12 else 0.0
	var pa := a + ab * u
	t = maxf((pa - o).dot(d), 0.0)
	var dist := (o + d * t).distance_to(pa)
	return { "t": t, "u": u, "dist": dist }
