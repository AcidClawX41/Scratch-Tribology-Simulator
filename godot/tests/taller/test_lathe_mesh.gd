## Malla de revolución de la pieza (core/taller/lathe_mesh.gd) y virutas (core/taller/chips.gd).
## Invariantes: recuentos, normales unitarias hacia fuera, bytes idénticos a los que guarda Godot, reescribir un
## rango = reconstruir entera, banda de tolerancia del plano, rendimiento con 2000 anillos × 64 lados y
## determinismo de las virutas.
extends "res://tests/case.gd"

const LatheMesh = preload("res://core/taller/lathe_mesh.gd")
const Chips = preload("res://core/taller/chips.gd")


## Perfil del contrato con todos los anillos iguales (barra en bruto).
func _profile(n: int, r0 := 25.0, p_z0 := -84.0, p_dz := 0.02) -> Dictionary:
	var r := PackedFloat64Array()
	r.resize(n)
	r.fill(r0)
	var ra := PackedFloat32Array()
	ra.resize(n)
	ra.fill(12.5)
	var ps := PackedByteArray()
	ps.resize(n)
	return {"z0": p_z0, "dz": p_dz, "r": r, "ring_ra": ra, "ring_pass": ps, "dirty": Vector2i(-1, -1)}


## Pieza A de CONTRATOS.md ya torneada (chaflán, Ø30, Ø40, Ø46 y la barra en bruto hasta el plato).
func _turned(p: Dictionary) -> void:
	var r: PackedFloat64Array = p["r"]
	for i in r.size():
		var z := float(p["z0"]) + float(i) * float(p["dz"])
		var d := 50.0
		if z > 0.0:
			d = 0.0
		elif z > -1.0:
			d = 28.0 - 2.0 * z  # chaflán 1 × 45°: Ø30 en Z−1, Ø28 en la cara
		elif z > -20.0:
			d = 30.0
		elif z > -40.0:
			d = 40.0
		elif z > -55.0:
			d = 46.0
		r[i] = d * 0.5


func _plan_a(p: Dictionary) -> Dictionary:
	var segs := [
		{"z_from": -1.0, "z_to": 0.0, "d_from": 30.0, "d_to": 28.0, "es_um": 200.0, "ei_um": -200.0},
		{"z_from": -20.0, "z_to": -1.0, "d_from": 30.0, "d_to": 30.0, "es_um": 0.0, "ei_um": -52.0},
		{"z_from": -40.0, "z_to": -20.0, "d_from": 40.0, "d_to": 40.0, "es_um": 0.0, "ei_um": -62.0},
		{"z_from": -55.0, "z_to": -40.0, "d_from": 46.0, "d_to": 46.0, "es_um": 100.0, "ei_um": -100.0},
	]
	return LatheMesh.band_from_segments(segs, float(p["z0"]), float(p["dz"]), (p["r"] as PackedFloat64Array).size())


func _decode_normal(code: int) -> Vector3:
	return Vector3.octahedron_decode(Vector2(float(code & 0xFFFF) / 65535.0, float((code >> 16) & 0xFFFF) / 65535.0))


# ─── Malla ───────────────────────────────────────────────────────────────────────────────────────────────

func test_recuentos_y_nivel_de_detalle() -> void:
	var lm := LatheMesh.new(64, 2000)
	var p := _profile(4251)
	var b := lm.build(p)
	assert_eq(lm.ring_step, 3, "4251 anillos del núcleo con tope 2000 → uno de cada 3")
	assert_eq(lm.n_rings, 1418, "anillos de la malla")
	assert_eq(lm.core_index(lm.n_rings - 1), 4250, "el último anillo de la malla muestrea el último del núcleo")
	var vc := 1 + 65 + 1418 * 65 + 65 + 1
	assert_eq(lm.vertex_count, vc, "vértices: tapas + anillos (65 por anillo con la costura)")
	assert_eq(lm.index_count, (1417 * 64 * 2 + 2 * 64) * 3, "índices")
	var arrays: Array = b["arrays"]
	assert_eq((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), vc, "posiciones")
	assert_eq((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size(), vc, "normales")
	assert_eq((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(), vc * 4, "tangentes")
	assert_eq((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size(), vc, "UV")
	assert_eq((arrays[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array).size(), vc * 4, "CUSTOM0")
	assert_eq((b["pos"] as PackedByteArray).size(), vc * LatheMesh.POS_STRIDE, "bytes de posiciones")
	assert_eq((b["nt"] as PackedByteArray).size(), vc * LatheMesh.NT_STRIDE, "bytes de normal + tangente")
	assert_eq((b["attr"] as PackedByteArray).size(), vc * LatheMesh.ATTR_STRIDE, "bytes de atributos")
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(idx.size(), lm.index_count, "tamaño del array de índices")
	var mx := 0
	for i in idx:
		mx = maxi(mx, i)
	assert_eq(mx, vc - 1, "los índices recorren todos los vértices")
	# Menos lados y sin diezmar
	var small := LatheMesh.new(8, 5000)
	small.build(_profile(101))
	assert_eq(small.ring_step, 1, "sin diezmar si cabe")
	assert_eq(small.vertex_count, 1 + 9 + 101 * 9 + 9 + 1, "vértices con 8 lados")


func test_normales_unitarias_y_caras_hacia_fuera() -> void:
	var lm := LatheMesh.new(24, 400)
	var p := _profile(4251)
	_turned(p)
	var b := lm.build(p)
	var arrays: Array = b["arrays"]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad := 0
	for nn in n:
		if absf(nn.length() - 1.0) > 1e-5:
			bad += 1
	assert_eq(bad, 0, "normales con módulo distinto de 1")
	# Las normales codificadas se decodifican en las mismas (precisión de 16 bits)
	var codes := (b["nt"] as PackedByteArray).to_int32_array()
	var worst := 1.0
	for i in range(0, v.size(), 7):
		worst = minf(worst, _decode_normal(codes[2 * i]).dot(n[i]))
	assert_true(worst > 0.99999, "normal codificada ≈ normal (peor coseno %s)" % str(worst))
	# Cilindro: normal radial; tapas: ±x
	var m := 64  # 400 anillos como tope → uno de cada 11: z ≈ −84 + 64·11·0,02 = −69,9 → Ø50 en bruto
	var i0 := lm.ring_vertex(m) + 5
	var radial := Vector3(0.0, v[i0].y, v[i0].z).normalized()
	assert_true(n[i0].dot(radial) > 0.99999, "normal radial en el cilindro")
	assert_true(n[0].is_equal_approx(Vector3(-1, 0, 0)), "tapa del plato hacia −x")
	assert_true(n[n.size() - 1].is_equal_approx(Vector3(1, 0, 0)), "tapa del contrapunto hacia +x")
	# Triángulos en sentido horario vistos desde fuera (convenio de Godot): (v1 − v0) × (v2 − v0) apunta hacia
	# dentro. Comprobación global: la malla es cerrada (tubo + dos tapas), así que la suma de v0·(v1 × v2)/6 es
	# el volumen con signo, negativo con este convenio y de valor el del sólido de revolución poligonal.
	# Comprobación local: en las zonas lisas (las tres normales de vértice parecidas) cada triángulo mira hacia
	# donde dicen sus normales; en las aristas vivas la normal suavizada no sirve de referencia.
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var wrong := 0
	var checked := 0
	var vol := 0.0
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var c1 := idx[t + 1]
		var c2 := idx[t + 2]
		vol += v[a].dot(v[c1].cross(v[c2])) / 6.0
		var fn := (v[c1] - v[a]).cross(v[c2] - v[a])
		if fn.length() < 1e-6 or n[a].dot(n[c1]) < 0.9 or n[a].dot(n[c2]) < 0.9:
			continue  # degenerado sobre el eje (anillos sin material) o arista viva
		checked += 1
		if fn.dot(n[a] + n[c1] + n[c2]) >= 0.0:
			wrong += 1
	assert_true(checked > 1000, "triángulos comprobados")
	assert_eq(wrong, 0, "triángulos orientados al revés")
	var k := 0.5 * float(lm.sides) * sin(TAU / float(lm.sides))  # área del polígono de radio 1
	var want := 0.0
	for q in lm.n_rings - 1:
		var r1: float = (p["r"] as PackedFloat64Array)[lm.core_index(q)]
		var r2: float = (p["r"] as PackedFloat64Array)[lm.core_index(q + 1)]
		want += (lm.ring_z(q + 1) - lm.ring_z(q)) / 3.0 * k * (r1 * r1 + r2 * r2 + r1 * r2)
	assert_near(-vol, want, 1e-4, 1e-6, "volumen con signo = −volumen del sólido (todas las caras bien orientadas)")


func test_bytes_como_godot() -> void:
	var lm := LatheMesh.new(16, 400)
	var p := _profile(1201, 25.0, -20.0)
	_turned(p)
	var plan := _plan_a(p)
	var b := lm.build(p, plan)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b["arrays"], [], {}, LatheMesh.CUSTOM_FORMAT)
	var fmt := mesh.surface_get_format(0)
	var vc := lm.vertex_count
	assert_eq(RenderingServer.mesh_surface_get_format_vertex_stride(fmt, vc), LatheMesh.POS_STRIDE, "paso de posiciones")
	assert_eq(RenderingServer.mesh_surface_get_format_normal_tangent_stride(fmt, vc), LatheMesh.NT_STRIDE, "paso de normal + tangente")
	assert_eq(RenderingServer.mesh_surface_get_format_attribute_stride(fmt, vc), LatheMesh.ATTR_STRIDE, "paso de atributos")
	assert_eq(RenderingServer.mesh_surface_get_format_offset(fmt, vc, Mesh.ARRAY_NORMAL), vc * LatheMesh.POS_STRIDE, "desplazamiento de la normal")
	assert_eq(RenderingServer.mesh_surface_get_format_offset(fmt, vc, Mesh.ARRAY_TANGENT), vc * LatheMesh.POS_STRIDE + 4, "desplazamiento de la tangente")
	assert_eq(RenderingServer.mesh_surface_get_format_offset(fmt, vc, Mesh.ARRAY_TEX_UV), 0, "desplazamiento de la UV")
	assert_eq(RenderingServer.mesh_surface_get_format_offset(fmt, vc, Mesh.ARRAY_CUSTOM0), 8, "desplazamiento de CUSTOM0")
	var sd := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var vd: PackedByteArray = sd["vertex_data"]
	var ad: PackedByteArray = sd["attribute_data"]
	var mine: PackedByteArray = (b["pos"] as PackedByteArray) + (b["nt"] as PackedByteArray)
	assert_eq(vd.size(), mine.size(), "tamaño del búfer de vértices")
	assert_true(vd == mine, "búfer de vértices idéntico al de Godot (posiciones + normales y tangentes octaédricas)")
	assert_true(ad == b["attr"], "búfer de atributos idéntico al de Godot (UV + CUSTOM0)")


func test_custom0_ra_pasada_y_desviacion() -> void:
	var lm := LatheMesh.new(16, 5000)
	var p := _profile(2001, 25.0, -40.0)  # z de −40 a 0, sin diezmar
	_turned(p)
	var r: PackedFloat64Array = p["r"]
	var ra: PackedFloat32Array = p["ring_ra"]
	var ps: PackedByteArray = p["ring_pass"]
	var plan := _plan_a(p)
	# z = −10 (Ø30 h9: 29,948…30,000): pasado de medida, Ø29,90
	var i_past := 1500
	r[i_past] = 14.95
	ra[i_past] = 0.8
	ps[i_past] = 2
	# z = −30 (Ø40 h9): con creces, Ø40,40
	var i_excess := 500
	r[i_excess] = 20.2
	ra[i_excess] = 6.3
	ps[i_excess] = 1
	var b := lm.build(p, plan)
	var f := (b["attr"] as PackedByteArray).to_float32_array()
	for row in [[i_past, -10.0, 0.8, 2.0, (29.90 - 29.974) * 1000.0, 26.0], [i_excess, -30.0, 6.3, 1.0, (40.40 - 39.969) * 1000.0, 31.0]]:
		var o := (lm.ring_vertex(int(row[0])) + 3) * 6  # cuarto vértice del anillo
		assert_near(f[o], float(row[1]), 1e-6, 1e-5, "UV.x = z del anillo")
		assert_near(f[o + 1], 3.0 / 16.0, 1e-6, 1e-7, "UV.y = j/lados")
		assert_near(f[o + 2], float(row[2]), 1e-6, 1e-6, "CUSTOM0.x = Ra")
		assert_eq(f[o + 3], float(row[3]), "CUSTOM0.y = tipo de pasada")
		assert_near(f[o + 4], float(row[4]), 1e-4, 1e-2, "CUSTOM0.z = desviación del diámetro (µm)")
		assert_near(f[o + 5], float(row[5]), 1e-4, 1e-2, "CUSTOM0.w = semiancho de la tolerancia (µm)")
	assert_true(absf(f[(lm.ring_vertex(i_past) + 3) * 6 + 4]) > f[(lm.ring_vertex(i_past) + 3) * 6 + 5], "Ø29,90 queda fuera de h9 (pasado)")
	# Sin plano: semiancho −1
	var nb := LatheMesh.new(16, 5000).build(p)
	var g := (nb["attr"] as PackedByteArray).to_float32_array()
	assert_eq(g[(lm.ring_vertex(1000) + 3) * 6 + 5], LatheMesh.NO_PLAN, "sin plano → −1")


func test_banda_de_tolerancia() -> void:
	var p := _profile(3001, 25.0, -60.0)
	var plan := _plan_a(p)
	var rmin: PackedFloat64Array = plan["r_min"]
	var rmax: PackedFloat64Array = plan["r_max"]
	var at := func(z: float) -> int: return int(round((z + 60.0) / 0.02))
	assert_near(rmin[at.call(-10.0)], (30.0 - 0.052) * 0.5, 1e-12, 1e-12, "Ø30 h9: mínimo")
	assert_near(rmax[at.call(-10.0)], 15.0, 1e-12, 1e-12, "Ø30 h9: máximo")
	assert_near(rmin[at.call(-50.0)], 22.95, 1e-12, 1e-12, "Ø46 ±0,1: mínimo")
	assert_near(rmax[at.call(-50.0)], 23.05, 1e-12, 1e-12, "Ø46 ±0,1: máximo")
	assert_near(rmax[at.call(-0.5)], (29.0 + 0.2) * 0.5, 1e-9, 1e-9, "chaflán: el diámetro varía en el tramo")
	# En el hombro de Z−20 se acepta la unión de las dos bandas
	var ish: int = at.call(-20.0)
	assert_true(rmin[ish] <= 14.974 + 1e-9 and rmax[ish] >= 20.0 - 1e-9, "hombro: unión de bandas")
	# Fuera de la pieza (zona de amarre) no hay plano
	assert_eq(rmax[at.call(-58.0)], LatheMesh.NO_PLAN, "zona de amarre sin plano")


func test_rango_igual_que_reconstruir() -> void:
	# [lados, tope de anillos, anillos del núcleo] → sin diezmar, diezmado ×3 y diezmado con resto
	for cfg in [[12, 5000, 301], [16, 400, 1201], [24, 2000, 4251]]:
		var lm := LatheMesh.new(cfg[0], cfg[1])
		var p := _profile(cfg[2], 25.0, -float(cfg[2] - 1) * 0.02 + 1.0)
		var plan := _plan_a(p)
		var streams := lm.build(p, plan)
		var n: int = cfg[2]
		var r: PackedFloat64Array = p["r"]
		var ra: PackedFloat32Array = p["ring_ra"]
		var ps: PackedByteArray = p["ring_pass"]
		# Ediciones: centro, principio (tapa del plato), final (tapa del contrapunto), un solo anillo, un
		# anillo que la malla no muestrea y un chaflán (cambia las normales)
		var edits := [[n / 3, n / 3 + 37, 23.0], [0, 4, 24.0], [n - 6, n - 1, 0.0], [n / 2, n / 2, 20.0], [n / 4 * 3 + 1, n / 4 * 3 + 1, 21.0], [n / 5, n / 5 + 60, -1.0]]
		for e in edits:
			var a: int = e[0]
			var z: int = e[1]
			for i in range(a, z + 1):
				r[i] = float(e[2]) if float(e[2]) >= 0.0 else 18.0 + 0.02 * float(i - a)
				ra[i] = 0.4 + 0.01 * float(i % 7)
				ps[i] = 1 + i % 3
			var upd := lm.update(p, plan, a, z)
			if not upd.is_empty():
				streams = LatheMesh.apply_update(streams, upd)
			var fresh := LatheMesh.new(cfg[0], cfg[1]).build(p, plan)
			var where := "%d anillos, edición [%d, %d]" % [n, a, z]
			assert_true(streams["pos"] == fresh["pos"], "posiciones: rango = reconstrucción (%s)" % where)
			assert_true(streams["nt"] == fresh["nt"], "normales: rango = reconstrucción (%s)" % where)
			assert_true(streams["attr"] == fresh["attr"], "atributos: rango = reconstrucción (%s)" % where)
		# Un rango que la malla no muestrea no cambia nada
		if lm.ring_step > 1:
			assert_true(lm.update(p, plan, 1, 1).is_empty(), "rango sin anillos muestreados → sin cambios")
	# Rango no válido
	var lm2 := LatheMesh.new(8, 100)
	var p2 := _profile(50)
	lm2.build(p2)
	assert_true(lm2.update(p2, {}, -1, -1).is_empty(), "dirty (−1, −1) → sin cambios")


## Sin estado compartido (CONTRATOS.md, rendimiento): cuatro mallas construidas a la vez en el WorkerThreadPool dan
## los mismos bytes que una construida en serie.
func test_mallas_en_varios_hilos_iguales_que_en_serie() -> void:
	var p := _profile(4251)
	_turned(p)
	var plan := _plan_a(p)
	var ref: Dictionary = LatheMesh.new(64, 2000).build(p, plan)
	var outs: Array = [null, null, null, null]
	var lock := Mutex.new()
	var task := func(i: int) -> void:
		var built: Dictionary = LatheMesh.new(64, 2000).build(p, plan)
		lock.lock()
		outs[i] = built
		lock.unlock()
	var gid := WorkerThreadPool.add_group_task(task, outs.size())
	WorkerThreadPool.wait_for_group_task_completion(gid)
	for i in outs.size():
		var got: Dictionary = outs[i]
		assert_eq(got.pos, ref.pos, "hilo %d: posiciones" % i)
		assert_eq(got.nt, ref.nt, "hilo %d: normales y tangentes" % i)
		assert_eq(got.attr, ref.attr, "hilo %d: atributos" % i)


func test_rendimiento_2000_anillos_64_lados() -> void:
	# Una pasada de desbaste que avanza 0,5 mm por fotograma (25 anillos del núcleo y la huella de la punta).
	var lm := LatheMesh.new(64, 2000)
	var p := _profile(3999, 25.0, -79.0)
	var plan := _plan_a(p)
	var t_build := Time.get_ticks_usec()
	lm.build(p, plan)
	t_build = Time.get_ticks_usec() - t_build
	assert_eq(lm.n_rings, 2000, "malla de 2000 anillos")
	assert_eq(lm.sides, 64, "64 lados")
	var r: PackedFloat64Array = p["r"]
	var times: Array[int] = []
	var zt := 3998
	for frame in 120:
		var a := maxi(zt - 25, 0)
		for i in range(a, zt + 1):
			r[i] = 23.0
		var t0 := Time.get_ticks_usec()
		var upd := lm.update(p, plan, a, mini(zt + 40, 3998))
		times.append(Time.get_ticks_usec() - t0)
		assert_false(upd.is_empty())
		zt = a - 1
		if zt < 30:
			zt = 3998
	times.sort()
	var median := times[times.size() / 2]
	var p95 := times[int(times.size() * 0.95)]
	var t_full := Time.get_ticks_usec()
	lm.update(p, plan, 0, 3998)
	t_full = Time.get_ticks_usec() - t_full
	print("    (rendimiento) 2000 anillos × 64 lados: actualización por fotograma mediana %s ms, p95 %s ms; malla entera %s ms; construcción %s ms" % [
		_ms(median), _ms(p95), _ms(t_full), _ms(t_build)])
	assert_true(median <= 2000, "actualización por fotograma ≤ 2 ms (mediana %s ms)" % _ms(median))


func _ms(us: int) -> String:
	return "%.3f" % (float(us) / 1000.0)


# ─── Virutas ─────────────────────────────────────────────────────────────────────────────────────────────

func _run(ch: RefCounted, frames: int, rate: float, vc := 200.0) -> void:
	for f in frames:
		ch.emit(1.0 / 32.0, Vector3(0.0, 1.1, 0.02), Vector3(0.2, 1.0, 0.6), rate, vc)
		ch.step(1.0 / 32.0)


func test_virutas_deterministas() -> void:
	var a := Chips.new("acero", "torno:virutas", 200)
	var b := Chips.new("acero", "torno:virutas", 200)
	var c := Chips.new("acero", "otra semilla", 200)
	_run(a, 64, 40.0)
	_run(b, 64, 40.0)
	_run(c, 64, 40.0)
	assert_true(a.buffer == b.buffer, "misma semilla y mismas llamadas → mismas virutas")
	assert_false(a.buffer == c.buffer, "otra semilla → otras virutas")
	assert_eq(a.count, b.count, "mismo número de virutas")


func test_virutas_recuentos() -> void:
	var ch := Chips.new("acero", "recuento", 50)
	_run(ch, 32, 32.0)  # 1 s a 32 virutas/s con dt = 1/32 (exacto en binario)
	assert_eq(ch.emitted, 32, "32 virutas en 1 s a 32/s")
	assert_eq(ch.count, 32, "instancias visibles")
	_run(ch, 64, 32.0)
	assert_eq(ch.emitted, 96, "total emitidas")
	assert_eq(ch.count, 50, "el anillo de 50 se recicla: nunca más de la capacidad")
	assert_eq(ch.buffer.size(), 50 * Chips.FLOATS, "búfer de 16 floats por instancia (TRANSFORM_3D + color)")
	assert_eq(Chips.rate_for("acero", 0.0, 1200.0), 0.0, "sin corte no hay virutas")
	assert_eq(Chips.rate_for("acero", 2.0, 0.0), 0.0, "con el cabezal parado no hay virutas")
	assert_eq(Chips.rate_for("acero", 2.0, -1200.0), Chips.rate_for("acero", 2.0, 1200.0), "al revés (M04) salen igual")
	assert_true(Chips.rate_for("laton", 2.0, 1200.0) > Chips.rate_for("acero", 2.0, 1200.0), "el latón sale a puñados")
	assert_true(Chips.rate_for("aluminio", 2.0, 1200.0) < Chips.rate_for("acero", 2.0, 1200.0), "la espiral sale poca y larga")


func test_virutas_balistica_y_bandeja() -> void:
	var ch := Chips.new("laton", "bandeja", 300)
	ch.floor_y = 0.7
	_run(ch, 16, 64.0)
	var above := 0
	for i in ch.count:
		if ch.position_of(i).y > 1.1 + 0.002:
			above += 1
	assert_true(above > 0, "salen hacia arriba desde la punta")
	for f in 160:  # 5 s más sin emitir
		ch.step(1.0 / 32.0)
	assert_eq(ch.flying(), 0, "todas acaban en reposo")
	var below := 0
	for i in ch.count:
		if ch.position_of(i).y < ch.floor_y - 1e-6:  # float32 en PackedVector3Array
			below += 1
		assert_eq(ch.state_of(i), Chips.RESTING, "viruta %d en reposo" % i)
	assert_eq(below, 0, "ninguna atraviesa la bandeja")


func test_virutas_sobre_el_carro_se_mueven_con_el() -> void:
	var ch := Chips.new("acero", "carro", 100)
	ch.floor_y = 0.5
	# Superficie del carro justo debajo de la punta (y = 1,05) que cubre toda la zona de caída
	ch.set_box(0, Rect2(-1.0, -1.0, 2.0, 2.0), 1.05)
	_run(ch, 8, 64.0)
	for f in 200:
		ch.step(1.0 / 32.0)
	assert_eq(ch.flying(), 0, "todas en reposo")
	var on_box := 0
	for i in ch.count:
		if absf(ch.position_of(i).y - 1.05) < 0.01:
			on_box += 1
	assert_eq(on_box, ch.count, "todas sobre el carro, no en la bandeja")
	var before := ch.position_of(0)
	ch.set_box(0, Rect2(-0.9, -1.0, 2.0, 2.0), 1.05)  # el carro avanza 10 cm en x
	assert_true(ch.position_of(0).is_equal_approx(before + Vector3(0.1, 0.0, 0.0)), "la viruta viaja con el carro")
	# Una superficie más alta que la viruta no la «atrapa» desde abajo
	var g := ch.ground_at(0.0, 0.0, 0.8)
	assert_eq(g.y, -1.0, "desde 0,8 m no se apoya en una superficie a 1,05 m")


func test_virutas_colores_de_revenido() -> void:
	var cold := Chips.temper_color("acero", 30.0)
	assert_true(cold.is_equal_approx(Chips.KINDS["acero"]["base"]), "acero a 30 m/min: sin color de óxido")
	var straw := Chips.temper_color("acero", 110.0)
	var blue := Chips.temper_color("acero", 200.0)
	assert_true(straw.r > straw.b, "a 110 m/min: pajizo (más rojo que azul)")
	assert_true(blue.b > blue.r, "a 200 m/min con metal duro: azul")
	assert_true(Chips.chip_temperature(300.0) > Chips.chip_temperature(200.0), "más vc, más temperatura")
	assert_true(Chips.temper_color("aluminio", 400.0).is_equal_approx(Chips.KINDS["aluminio"]["base"]), "el aluminio no toma color")
	assert_true(Chips.temper_color("inox", 200.0).r > Chips.temper_color("inox", 200.0).b, "inoxidable a 200 m/min: todavía dorado")


func test_virutas_formas_y_fuentes() -> void:
	for k in ["acero", "inox", "fundicion", "aluminio", "laton", "titanio", "niquel", "madera", "plastico", "piedra", "vidrio"]:
		assert_true(Chips.KINDS.has(k), "falta el material «%s» de CONTRATOS.md" % k)
		var e: Dictionary = Chips.KINDS[k]
		assert_true(Chips.FORMS.has(e["form"]), "%s: forma conocida" % k)
		assert_true(str(e.get("source", "")) != "", "%s: fuente" % k)
		assert_true(["primary", "secondary", "estimate"].has(e.get("quality")), "%s: calidad del dato" % k)
	assert_eq(Chips.form_for("acero"), "rizada")
	assert_eq(Chips.form_for("aluminio"), "espiral")
	assert_eq(Chips.form_for("laton"), "astillada")
	assert_eq(Chips.form_for("fundicion"), "astillada")
	assert_eq(Chips.form_for("desconocido"), "rizada", "material desconocido → como el acero")


func test_virutas_transformacion_en_el_bufer() -> void:
	var ch := Chips.new("acero", "bufer", 20)
	_run(ch, 4, 64.0)
	for i in ch.count:
		var o := i * Chips.FLOATS
		var f := ch.buffer
		var bx := Vector3(f[o], f[o + 4], f[o + 8])
		var by := Vector3(f[o + 1], f[o + 5], f[o + 9])
		var bz := Vector3(f[o + 2], f[o + 6], f[o + 10])
		var origin := Vector3(f[o + 3], f[o + 7], f[o + 11])
		assert_true(origin.is_equal_approx(ch.position_of(i)), "origen = posición de la viruta")
		assert_near(bx.dot(by), 0.0, 1e-6, 1e-5, "ejes ortogonales")
		assert_near(bx.length(), bz.length(), 1e-5, 1e-6, "escala uniforme")
		assert_true(f[o + 15] == 1.0, "alfa del color = 1")
