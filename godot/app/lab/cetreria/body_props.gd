## Cetrería · lo que lleva encima el animal de la cetrería (unidad 5i, petición 37; dibujo hecho en código): la toalla que
## envuelve a la rapaz, la capucha de cuero con su penacho, la mascarilla del isoflurano con su tubo y la pinza del
## pulsioxímetro en la lengua de los grandes. Funciones puras que devuelven arrays (en el marco de la raíz o en el de la
## cabeza); care_body.gd hace los nodos y los materiales una vez por animal y calidad.
##   - La toalla (Samour 2006: el cuerpo y las alas dentro, las patas fuera): una tela que sale del banco por detrás del
##     lomo, sube por encima del ala y acaba en una solapa sobre el flanco, sin tapar la tripa por donde salen las patas;
##     con pliegues de tela de verdad (los de compresión junto a las aberturas del cuello y de la cola, arrugas sueltas y
##     la tela que se apoya en el banco), su dobladillo en los bordes y la sombra de cada pliegue horneada en los vértices.
##   - La capucha: una pieza de cuero que sigue la cabeza (de la nuca a la boca, que deja el pico fuera), con las piezas de
##     los ojos de otro color, el canto de la abertura, las correas de atrás con sus borlas y el penacho de plumas sobre
##     el botón de la coronilla.
##   - La mascarilla: un cono de plástico transparente con su diafragma de goma alrededor de la cara y el tubo anillado.
##   - La pinza: la lengua fuera, por un lado de la boca, con la pinza de plástico y su cable.
extends RefCounted

const BodyKit = preload("res://app/lab/cetreria/body_kit.gd")
const Rng = preload("res://core/shared/rng.gd")


# ─────────────────────────────── la toalla ───────────────────────────────

## La toalla que envuelve el tronco (lo: el loft del tronco; de u_a a u_b de su largo). → arrays (UV en m: a lo largo y
## alrededor; COLOR.r: la sombra de los pliegues).
static func towel(lo: Dictionary, u_a: float, u_b: float, girth: float, mobile: bool, seed: String) -> Array:
	var rng := Rng.new(Rng.seed_of("toalla|" + seed))
	var arc: PackedFloat32Array = lo.arc
	var total := arc[arc.size() - 1]
	var n_u := 22 if mobile else 64
	var n_t := 18 if mobile else 52
	var thick := girth * 0.06
	var amp := girth * 0.05
	var skirt := girth * 0.55
	# pliegues sueltos: crestas al azar por la superficie (u, t), cada una con su dirección, su largo y su alto
	var ridges: Array = []
	for k in (6 if mobile else 14):
		ridges.append({ "u": rng.next(), "t": rng.next() * 0.9, "ang": (rng.next() - 0.5) * 2.2, "len": 0.15 + 0.3 * rng.next(),
			"w": 0.025 + 0.03 * rng.next(), "h": (0.5 + rng.next()) * (1.0 if rng.next() > 0.3 else -0.6) })
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var shade := PackedFloat32Array()
	var grid_w := n_t + 1
	var a_flap := 0.63
	# de las columnas, las primeras siguen el cuerpo y las últimas van por el banco
	var n_hug := int(round(float(n_t) * 0.72))
	for i in n_u + 1:
		var u := float(i) / float(n_u)
		var along := lerpf(u_a, u_b, u) * total
		var fi := BodyKit.station_at(lo, clampf(along, 0.0, total))
		# los extremos: la tela se abre algo más allá del cuerpo (las aberturas del cuello y de la cola)
		var flare := (1.0 - smoothstep(0.0, 0.12, u)) + (1.0 - smoothstep(0.0, 0.12, 1.0 - u))
		var off := thick * (1.0 + flare * 1.6)
		var wing_off := girth * 0.13
		var edge_a := a_flap + 0.035 * sin(u * 9.0 + 1.3) + 0.02 * sin(u * 23.0)
		# hasta dónde sigue el cuerpo: desde la solapa (sobre el flanco de arriba), por encima y por el lomo, hasta que llega
		# a la altura del banco
		var a_end := edge_a + 0.6
		for k in 60:
			var a_try := edge_a + 0.3 + float(k) * 0.006
			var sp_try: Array = BodyKit.surface_point(lo, fi, fposmod(a_try, 1.0))
			if ((sp_try[0] as Vector3) + (sp_try[1] as Vector3) * off).y < thick * 1.4:
				a_end = a_try
				break
		var path := PackedVector3Array()
		var path_n := PackedVector3Array()
		for j in n_hug + 1:
			var a := fposmod(lerpf(edge_a, a_end, float(j) / float(n_hug)), 1.0)
			var sp: Array = BodyKit.surface_point(lo, fi, a)
			# sobre el flanco de arriba va el ala plegada: la tela pasa por encima
			var over_wing := smoothstep(0.58, 0.66, a) * (1.0 - smoothstep(0.9, 0.97, a)) if a > 0.5 else 0.0
			path.append((sp[0] as Vector3) + (sp[1] as Vector3) * (off + wing_off * over_wing))
			path_n.append(sp[1])
		# en el banco: hacia fuera (por detrás del lomo), con ondas suaves que se apoyan
		var c := path[path.size() - 1]
		c.y = thick * 0.6
		path[path.size() - 1] = c
		var out := Vector3(path_n[path_n.size() - 1].x, 0.0, 0.0)
		out = out.normalized() if out.length_squared() > 1e-6 else Vector3(-1.0, 0.0, 0.0)
		for j in range(n_hug + 1, n_t + 1):
			var dist := float(j - n_hug) / float(n_t - n_hug) * skirt
			var p := c + out * dist
			p.y = thick * 0.5 + amp * 0.4 * maxf(sin(dist / girth * 7.0 + u * 5.0), 0.0) * smoothstep(0.0, skirt * 0.3, dist)
			path.append(p)
			path_n.append(Vector3.UP)
		for j in n_t + 1:
			var t := float(j) / float(n_t)
			var p := path[j]
			var nn := path_n[j]
			# los pliegues: de compresión junto a las aberturas (muchos y apretados), las crestas sueltas y una onda larga
			var comp := sin(t * 38.0 + sin(u * 7.0) * 2.0) * flare * 1.3
			var wav := sin(u * 13.0 + t * 4.0) * 0.35 + sin(u * 29.0 - t * 9.0) * 0.15
			var rid := 0.0
			for rd: Dictionary in ridges:
				var du := u - float(rd.u)
				var dt := t - float(rd.t)
				var ca := cos(float(rd.ang))
				var sa := sin(float(rd.ang))
				var along_r := du * ca + dt * sa
				var across := -du * sa + dt * ca
				rid += float(rd.h) * exp(-pow(across / float(rd.w), 2.0)) * (1.0 - smoothstep(float(rd.len) * 0.5, float(rd.len) * 0.5 + 0.08, absf(along_r)))
			var dsp := amp * (comp + wav + rid * 0.9)
			# el dobladillo de la solapa: un poco más gruesa y levantada
			var hem := (1.0 - smoothstep(0.0, 0.04, t)) * thick * 1.2
			var on_table := p.y < thick * 1.2
			p += nn * (dsp * (0.35 if on_table else 1.0) + hem)
			p.y = maxf(p.y, 0.0012)
			verts.append(p)
			uvs.append(Vector2(along * 1.0, t * girth * 3.4))
			var s := 0.84 + 0.16 * clampf(comp * 0.4 + wav + rid * 0.5, -1.5, 1.5)
			# bajo el dobladillo de la solapa y donde la tela toca el banco, más sombra
			s -= 0.18 * smoothstep(0.012, 0.0, p.y - 0.0012) * (1.0 if j > n_hug else 0.0)
			shade.append(clampf(s, 0.45, 1.0))
	# normales de la rejilla y la sombra de los valles
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in n_u + 1:
		for j in n_t + 1:
			var k := i * grid_w + j
			var ip := mini(i + 1, n_u) * grid_w + j
			var im := maxi(i - 1, 0) * grid_w + j
			var jp := i * grid_w + mini(j + 1, n_t)
			var jm := i * grid_w + maxi(j - 1, 0)
			var nrm := (verts[jp] - verts[jm]).cross(verts[ip] - verts[im])
			norms[k] = nrm.normalized() if nrm.length_squared() > 1e-20 else Vector3.UP
	# hacia fuera del cuerpo (o hacia arriba en el banco): la de referencia es la normal del cuerpo de cada columna
	var ref := PackedVector3Array()
	for i in n_u + 1:
		var u := float(i) / float(n_u)
		var fi := BodyKit.station_at(lo, clampf(lerpf(u_a, u_b, u) * total, 0.0, total))
		for j in n_t + 1:
			var t := float(j) / float(n_t)
			if j > n_hug:
				ref.append(Vector3.UP)
			else:
				var sp: Array = BodyKit.surface_point(lo, fi, fposmod(a_flap + t / 0.72 * 0.6, 1.0))
				ref.append(sp[1])
	for k in norms.size():
		if norms[k].dot(ref[k]) < 0.0:
			norms[k] = -norms[k]
	var tans := PackedFloat32Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	for k in verts.size():
		tans.append_array([1.0, 0.0, 0.0, 1.0])
		uv2s.append(Vector2(0.0, 0.0))
		cols.append(Color(shade[k], 0.0, 0.0, 1.0))
	var idx := PackedInt32Array()
	for i in n_u:
		for j in n_t:
			var a0 := i * grid_w + j
			var b0 := (i + 1) * grid_w + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return BodyKit.pack(verts, norms, tans, uvs, uv2s, cols, idx)


# ─────────────────────────────── la capucha ───────────────────────────────

## La capucha de cuero en el marco de la cabeza (x hacia el pico, y arriba, z a la derecha; lx, ly, lz el cráneo): la pieza
## que sigue la cabeza y deja el pico fuera, el canto de la abertura, las correas con sus borlas y el botón del penacho.
## → { leather (arrays), trim (arrays: el canto, las correas y el botón), plume (las plumas del penacho, tarjetas) }
static func hood(lx: float, ly: float, lz: float, mobile: bool, plume_col: Color) -> Dictionary:
	var ring := 20 if mobile else 40
	var n := 14 if mobile else 28
	var g := 1.14
	var pts := PackedVector3Array([Vector3(-lx * 0.68, -ly * 0.02, 0.0), Vector3(-lx * 0.25, ly * 0.03, 0.0), Vector3(lx * 0.2, ly * 0.04, 0.0), Vector3(lx * 0.47, -ly * 0.02, 0.0)])
	var sp := BodyKit.spine(pts, n)
	var top := BodyKit.profile(n, [[0.0, ly * 0.4 * g], [0.25, ly * 0.56 * g], [0.62, ly * 0.56 * g], [1.0, ly * 0.46 * g]])
	var bot := BodyKit.profile(n, [[0.0, ly * 0.36 * g], [0.3, ly * 0.4], [0.65, ly * 0.36], [1.0, ly * 0.3]])
	var sd := BodyKit.profile(n, [[0.0, lz * 0.42 * g], [0.3, lz * 0.55 * g], [0.62, lz * 0.55 * g], [1.0, lz * 0.45 * g]])
	# la forma de la capucha: abombada sobre los ojos (dos bultos) y con el botón arriba
	var bumps: Array = []
	for s: float in [-1.0, 1.0]:
		bumps.append({ "c": Vector3(lx * 0.12, ly * 0.2, s * lz * 0.45), "r": Vector3(lx * 0.25, ly * 0.22, lz * 0.2), "amt": lz * 0.06 })
	var shell := BodyKit.loft({ "spine": sp, "up": Vector3.UP, "ring": ring, "top": top, "bot": bot, "sr": sd, "sl": sd, "nt": 2.3,
		"nb": 1.8, "cap_start": true, "cap_end": false, "cap_k": 0.7, "bumps": bumps, "s0": 0.0, "s1": 1.0, "zone": 0.0 })
	var trim: Array = []
	# el canto de la abertura de delante
	var rim_pts := PackedVector3Array()
	var last_i := n - 1
	for j in ring + 1:
		var a := float(j) / float(ring) * TAU
		var yz := BodyKit.section_point(a, top[last_i], bot[last_i], sd[last_i], sd[last_i], 2.3, 1.8)
		rim_pts.append(sp[last_i] + Vector3(0.0, yz.x, yz.y))
	var rr := BodyKit.filled(rim_pts.size(), lz * 0.022)
	trim.append((BodyKit.loft({ "spine": rim_pts, "up": Vector3.RIGHT, "ring": 8, "top": rr, "bot": rr, "sr": rr, "sl": rr,
		"cap_start": false, "cap_end": false }) as Dictionary).arrays)
	# las correas de atrás (dos tiras de cuero que cuelgan de la nuca) con sus borlas
	for s: float in [-1.0, 1.0]:
		var a0 := Vector3(-lx * 0.55, -ly * 0.1, s * lz * 0.2)
		var c_pts := PackedVector3Array([a0, a0 + Vector3(-lx * 0.12, -ly * 0.2, s * lz * 0.05), a0 + Vector3(-lx * 0.18, -ly * 0.45, s * lz * 0.1)])
		var csp := BodyKit.spine(c_pts, 8)
		var cr := BodyKit.filled(csp.size(), lz * 0.03)
		var cw := BodyKit.filled(csp.size(), lz * 0.06)
		trim.append((BodyKit.loft({ "spine": csp, "up": Vector3(0.0, 0.0, s), "ring": 8, "top": cw, "bot": cw, "sr": cr, "sl": cr }) as Dictionary).arrays)
		var tip: Vector3 = csp[csp.size() - 1]
		var t_pts := PackedVector3Array([tip, tip + Vector3(-lx * 0.02, -ly * 0.12, 0.0)])
		var tsp := BodyKit.spine(t_pts, 6)
		var tr := BodyKit.profile(tsp.size(), [[0.0, lz * 0.03], [0.5, lz * 0.06], [1.0, lz * 0.04]])
		trim.append((BodyKit.loft({ "spine": tsp, "up": Vector3.RIGHT, "ring": 10, "top": tr, "bot": tr, "sr": tr, "sl": tr }) as Dictionary).arrays)
	# el botón del penacho, en la coronilla
	var knob_c := Vector3(-lx * 0.05, ly * 0.56 * g + ly * 0.04, 0.0)
	var k_pts := PackedVector3Array([knob_c - Vector3(0.0, ly * 0.04, 0.0), knob_c + Vector3(0.0, ly * 0.1, 0.0)])
	var ksp := BodyKit.spine(k_pts, 6)
	var kr := BodyKit.profile(ksp.size(), [[0.0, lz * 0.1], [0.6, lz * 0.07], [1.0, lz * 0.04]])
	trim.append((BodyKit.loft({ "spine": ksp, "up": Vector3.RIGHT, "ring": 12, "top": kr, "bot": kr, "sr": kr, "sl": kr }) as Dictionary).arrays)
	# el penacho: plumas cortas y teñidas que salen del botón, hacia arriba y hacia atrás
	var cards: Array = []
	var rng := Rng.new(Rng.seed_of("penacho"))
	for i in (5 if mobile else 11):
		var a := float(i) / 10.0 * TAU
		var ax := Vector3(-0.45 + 0.25 * cos(a), 1.0, 0.35 * sin(a)).normalized()
		cards.append({ "p": knob_c + Vector3(0.0, ly * 0.08, 0.0), "axis": ax, "nrm": Vector3(cos(a), 0.0, sin(a)), "len": ly * (0.55 + 0.25 * rng.next()),
			"wid": ly * 0.16, "bend": -0.25, "lift": 0.0, "cup": 0.05, "twist": a, "col": plume_col * (0.85 + 0.3 * rng.next()), "kind": 5,
			"pattern": 0, "param": 0.0, "seed": rng.next(), "breath": 0.0, "shade": 1.0, "segs": 3, "lat": 1 })
	return { "leather": shell.arrays, "trim": BodyKit.merge(trim), "plume": BodyKit.cards(cards) }


# ─────────────────────────────── la mascarilla ───────────────────────────────

## La mascarilla en el marco de la cabeza: el cono transparente de base0 (alrededor de la cara, radio r0) a tip (radio r1),
## el diafragma de goma en la boca del cono y el tubo anillado que sale de la punta y baja hacia la mesa. tube_to: el
## final del tubo (en el marco de la cabeza). El cono se mantiene ancho y se estrecha al final, hasta la boquilla del
## tubo, como una copa (5n: así caben dentro el hocico entero y la trufa del oso y del tigre). → { cone, rubber, tube }
static func mask(base0: Vector3, tip: Vector3, r0: float, r1: float, tube_to: Vector3, mobile: bool) -> Dictionary:
	var ring := 18 if mobile else 36
	var ax := (tip - base0).normalized()
	var up := (Vector3.UP - ax * Vector3.UP.dot(ax)).normalized()
	var n := 8
	var pts := PackedVector3Array()
	var rs := PackedFloat32Array()
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(base0.lerp(tip, t))
		rs.append(lerpf(r0, r1, pow(t, 2.0)))
	var cone := BodyKit.loft({ "spine": pts, "up": up, "ring": ring, "top": rs, "bot": rs, "sr": rs, "sl": rs, "cap_start": false, "cap_end": true, "cap_k": 0.4 })
	var rb_pts := PackedVector3Array()
	for j in ring + 1:
		var a := float(j) / float(ring) * TAU
		var side := ax.cross(up)
		rb_pts.append(base0 + (up * cos(a) + side * sin(a)) * r0 * 0.98)
	var rr := BodyKit.filled(rb_pts.size(), r0 * 0.09)
	var rubber := BodyKit.loft({ "spine": rb_pts, "up": ax, "ring": 10, "top": rr, "bot": rr, "sr": rr, "sl": rr, "cap_start": false, "cap_end": false })
	# el tubo: sale de la punta, sigue un poco y baja en curva
	var t_pts := PackedVector3Array([tip, tip + ax * r1 * 4.0, tube_to.lerp(tip + ax * r1 * 4.0, 0.4) + Vector3(0.0, -r1 * 2.0, 0.0), tube_to])
	var tsp := BodyKit.spine(t_pts, 40 if not mobile else 16)
	var tr := PackedFloat32Array()
	for i in tsp.size():
		tr.append(r1 * (0.85 + (0.12 * absf(sin(float(i) * 1.7)) if not mobile else 0.0)))
	var tube := BodyKit.loft({ "spine": tsp, "up": up, "ring": 12, "top": tr, "bot": tr, "sr": tr, "sl": tr, "cap_start": false, "cap_end": true })
	return { "cone": cone.arrays, "rubber": rubber.arrays, "tube": tube.arrays }


# ─────────────────────────────── la lengua y la pinza ───────────────────────────────

## La lengua que asoma por un lado de la boca (de mouth, hacia dir y cayendo hacia la mesa) con la pinza del pulsioxímetro
## cerca de la punta y su cable. En el marco de la cabeza. → { tongue, clip, cable, led (Vector3) }
static func tongue_clip(mouth: Vector3, dir: Vector3, down: Vector3, length: float, width: float, mobile: bool) -> Dictionary:
	var ring := 16 if mobile else 28
	var pts := PackedVector3Array([mouth, mouth + dir * length * 0.45 + down * length * 0.1, mouth + dir * length * 0.8 + down * length * 0.35, mouth + dir * length + down * length * 0.55])
	var sp := BodyKit.spine(pts, 12 if mobile else 24)
	var nn := sp.size()
	var thick := BodyKit.profile(nn, [[0.0, width * 0.18], [0.7, width * 0.14], [1.0, width * 0.1]])
	var wid := BodyKit.profile(nn, [[0.0, width * 0.5], [0.6, width * 0.55], [0.9, width * 0.45], [1.0, width * 0.25]])
	var up := down.cross(dir).normalized()
	var tongue := BodyKit.loft({ "spine": sp, "up": -down, "ring": ring, "top": thick, "bot": thick, "sr": wid, "sl": wid, "nt": 2.6, "nb": 2.2,
		"cap_start": false, "cap_end": true, "cap_k": 0.5, "zone": 0.0 })
	# la pinza: dos mandíbulas de plástico que abrazan la lengua, con la bisagra
	var at: Vector3 = sp[int(nn * 0.7)]
	var t_dir: Vector3 = (sp[int(nn * 0.7) + 1] - sp[int(nn * 0.7) - 1]).normalized()
	var n_up := (-down - t_dir * (-down).dot(t_dir)).normalized()
	var side := t_dir.cross(n_up).normalized()
	var clip: Array = []
	for s: float in [-1.0, 1.0]:
		var c0 := at + n_up * s * width * 0.24
		var c_pts := PackedVector3Array([c0 - side * width * 0.65, c0 + side * width * 0.65, c0 + side * width * 0.9 + n_up * s * width * 0.15])
		var csp := BodyKit.spine(c_pts, 8)
		var cr := BodyKit.filled(csp.size(), width * 0.12)
		var cw := BodyKit.filled(csp.size(), width * 0.42)
		clip.append((BodyKit.loft({ "spine": csp, "up": n_up * s, "ring": 12, "top": cr, "bot": cr, "sr": cw, "sl": cw, "nt": 3.0, "nb": 3.0 }) as Dictionary).arrays)
	var hinge := at + side * width * 1.0
	var h_pts := PackedVector3Array([hinge - n_up * width * 0.3, hinge + n_up * width * 0.3])
	var hr := BodyKit.filled(2, width * 0.12)
	clip.append((BodyKit.loft({ "spine": BodyKit.spine(h_pts, 4), "up": side, "ring": 12, "top": BodyKit.filled(4, width * 0.1), "bot": BodyKit.filled(4, width * 0.1),
		"sr": BodyKit.filled(4, width * 0.1), "sl": BodyKit.filled(4, width * 0.1) }) as Dictionary).arrays)
	hr = hr
	var cab_pts := PackedVector3Array([hinge + side * width * 0.1, hinge + side * width * 1.5 + down * width * 0.5, hinge + side * width * 3.5 + down * width * 2.5 + dir * width * 2.0])
	var cab := BodyKit.tube(BodyKit.spine(cab_pts, 16), BodyKit.filled(16, width * 0.05), 8)
	return { "tongue": tongue.arrays, "clip": BodyKit.merge(clip), "cable": cab.arrays, "led": at + n_up * width * 0.38 }
