## Fuente de perfil SIMULADA para la demo del torno 3D. No es el núcleo del torno (eso es la unidad 3): solo
## cumple el contrato del perfil (CONTRATOS.md) y arranca material anillo a anillo con la envolvente de una
## plaquita de radio de punta rε mientras recorre un programa corto sobre la pieza A de CONTRATOS.md (eje
## escalonado de C45E, bruto Ø50 × 85 con 25 mm dentro del plato): refrentado, cuatro pasadas de desbaste,
## pasada de acabado del contorno, pulido con tela abrasiva del Ø40 e inspección. El tiempo va acelerado (unas
## 8 veces en el desbaste) para que todo quepa en unos 10 s.
##
## Ra de cada pasada: el teórico de un radio de punta, Ra ≈ f²/(32·rε) (desbaste f = 0,4 → 6,3 µm; acabado
## f = 0,15 → 0,9 µm); el pulido deja unos 0,2 µm y el bruto laminado en caliente, con calamina, unos 25 µm
## (estimaciones de orden de magnitud, docs/taller/fuentes-u9.md).
##
## Para enseñar la capa de desviación, el acabado del Ø30 h9 se da a Ø29,92 (un corrector de desgaste mal
## introducido): queda pasado de medida y sale en rojo en la inspección.
extends RefCounted

const LatheMesh = preload("res://core/taller/lathe_mesh.gd")

const DZ := 0.02
const Z_START := -84.0  # extremo de la pieza dentro del plato
const Z_END := 1.0  # 1 mm de creces en la cara para el refrentado
const R_RAW := 25.0
const RA_RAW := 25.0
const NOSE := 0.8
const TAN5 := 0.087489  # tan 5°: filo secundario
const KC := 2000.0  # N/mm², presión específica de corte del C45 (orden de magnitud, estimación)
const PARK := Vector2(34.0, 8.0)

var z0 := Z_START
var n := 0
var r := PackedFloat64Array()
var ring_ra := PackedFloat32Array()
var ring_pass := PackedByteArray()

var tool := PARK  ## (r, z) de la punta teórica (mm)
var rpm := 0.0
var cutting := false
var coolant := false
var pc_kw := 0.0
var feed := 0.0
var op := "Arranque del cabezal"
var view := "general"  ## vista de cámara que pide el paso actual (coreografía de la demo)
var overlay := "acabado"  ## capa que pide el paso actual
var t := 0.0
var finished := false

var _dirty := Vector2i(-1, -1)
var _program: Array[Dictionary] = []
var _step := 0
var _step_t := 0.0
var _from := PARK
var _rpm_from := 0.0
var _removed := 0.0  # mm³ arrancados en el fotograma (para la potencia)


func _init() -> void:
	n = int(round((Z_END - Z_START) / DZ)) + 1
	r.resize(n)
	r.fill(R_RAW)
	ring_ra.resize(n)
	ring_ra.fill(RA_RAW)
	ring_pass.resize(n)
	ring_pass.fill(0)
	_build_program()


## Perfil según el contrato. `dirty` son los anillos cambiados desde la última lectura; leerlo lo pone a cero.
func profile() -> Dictionary:
	var d := _dirty
	_dirty = Vector2i(-1, -1)
	return {"z0": z0, "dz": DZ, "r": r, "ring_ra": ring_ra, "ring_pass": ring_pass, "dirty": d}


## Punta teórica de la herramienta (r, z) en mm: la escena la lee sola en cada fotograma.
func tool_pose() -> Vector2:
	return tool


## Banda de tolerancia del plano de la pieza A (ISO 286: h9 en Ø30 y Ø40; ±0,1 en Ø46; chaflán ±0,2 según
## ISO 2768-m). Fuera de la pieza (la zona de amarre) no hay plano.
func plan_band() -> Dictionary:
	var segs := [
		{"z_from": -1.0, "z_to": 0.0, "d_from": 30.0, "d_to": 28.0, "es_um": 200.0, "ei_um": -200.0},
		{"z_from": -20.0, "z_to": -1.0, "d_from": 30.0, "d_to": 30.0, "es_um": 0.0, "ei_um": -52.0},
		{"z_from": -40.0, "z_to": -20.0, "d_from": 40.0, "d_to": 40.0, "es_um": 0.0, "ei_um": -62.0},
		{"z_from": -55.0, "z_to": -40.0, "d_from": 46.0, "d_to": 46.0, "es_um": 100.0, "ei_um": -100.0},
		{"z_from": 0.0, "z_to": Z_END + 1.0, "d_from": 0.0, "d_to": 0.0, "es_um": 0.0, "ei_um": 0.0},
	]
	return LatheMesh.band_from_segments(segs, z0, DZ, n)


## Duración total del programa (s).
func duration() -> float:
	var s := 0.0
	for st in _program:
		s += float(st["dur"])
	return s


## Avanza la simulación dt segundos.
func advance(dt: float) -> void:
	t += dt
	_removed = 0.0
	var left := dt
	while left > 0.0 and _step < _program.size():
		var st: Dictionary = _program[_step]
		var dur := float(st["dur"])
		var take := minf(left, dur - _step_t)
		var a := _step_t / dur if dur > 0.0 else 1.0
		_step_t += take
		left -= take
		var b := _step_t / dur if dur > 0.0 else 1.0
		op = st["op"]
		view = st.get("view", view)
		overlay = st.get("overlay", "acabado")
		feed = float(st.get("f", 0.0))
		coolant = bool(st.get("coolant", false))
		rpm = lerpf(_rpm_from, float(st.get("rpm", _rpm_from)), smoothstep(0.0, 1.0, b)) if st.has("rpm") else _rpm_from
		var kind: String = st["kind"]
		cutting = kind == "feed"
		if st.has("to"):
			var to: Vector2 = st["to"]
			var p_a := _from.lerp(to, a)
			var p_b := _from.lerp(to, b)
			if kind == "feed":
				_sweep(p_a, p_b, int(st["pass"]), float(st["ra"]))
			tool = p_b
		elif kind == "polish":
			var za: float = st["z_from"]
			var zb: float = st["z_to"]
			var sweeps := float(st.get("sweeps", 2.0))
			_polish(_polish_z(za, zb, sweeps, a), _polish_z(za, zb, sweeps, b), float(st["ra"]))
		if _step_t >= dur - 1e-9:
			if st.has("to"):
				_from = st["to"]
			if st.has("rpm"):
				_rpm_from = float(st["rpm"])
			_step += 1
			_step_t = 0.0
	if _step >= _program.size():
		finished = true
		cutting = false
	# Potencia de corte aproximada: Pc = kc·(volumen arrancado por segundo) · (tiempo real / tiempo de la demo)
	pc_kw = KC * _removed / maxf(dt, 1e-6) / 1.0e6 / 8.0 if cutting else 0.0


func _polish_z(za: float, zb: float, sweeps: float, u: float) -> float:
	var ph := u * sweeps
	var k := fmod(ph, 2.0)
	return lerpf(za, zb, k if k <= 1.0 else 2.0 - k)


func _build_program() -> void:
	var p := _program
	p.append({"kind": "wait", "dur": 0.45, "op": "Arranque del cabezal", "rpm": 1200.0, "view": "general"})
	p.append({"kind": "rapid", "to": Vector2(26.0, 0.0), "dur": 0.3, "op": "Aproximación en rápido", "view": "frontal"})
	p.append({"kind": "feed", "to": Vector2(-0.6, 0.0), "dur": 0.55, "op": "Refrentado", "f": 0.2, "pass": 1, "ra": 3.2})
	p.append({"kind": "rapid", "to": Vector2(-0.6, 1.5), "dur": 0.06, "op": "Retirada"})
	p.append({"kind": "rapid", "to": Vector2(23.2, 1.5), "dur": 0.16, "op": "Retirada"})
	var passes := [[23.2, -55.0, 0.85, "frontal"], [20.2, -40.0, 0.62, "frontal"], [17.6, -20.0, 0.34, "detalle"], [15.2, -20.0, 0.34, "detalle"]]
	for i in passes.size():
		var ps: Array = passes[i]
		var rr: float = ps[0]
		var zz: float = ps[1]
		var label := "Desbaste %d de 4 · Ø%s" % [i + 1, _fmt(rr * 2.0, 1)]
		p.append({"kind": "feed", "to": Vector2(rr, zz), "dur": ps[2], "op": label, "f": 0.4, "pass": 1, "ra": 6.3, "rpm": 1200.0, "view": ps[3]})
		p.append({"kind": "rapid", "to": Vector2(rr + 0.8, zz), "dur": 0.04, "op": "Retirada"})
		p.append({"kind": "rapid", "to": Vector2(rr + 0.8, 1.5), "dur": 0.1, "op": "Retirada"})
		if i + 1 < passes.size():
			p.append({"kind": "rapid", "to": Vector2(passes[i + 1][0], 1.5), "dur": 0.05, "op": "Retirada"})
	# Medición tras el desbaste, con la herramienta apartada: todo el contorno con creces (ámbar)
	p.append({"kind": "rapid", "to": Vector2(30.0, 12.0), "dur": 0.12, "op": "Retirada", "view": "frontal"})
	p.append({"kind": "wait", "dur": 0.75, "op": "Medición tras el desbaste: quedan creces", "view": "frontal", "overlay": "desviacion"})
	p.append({"kind": "rapid", "to": Vector2(13.5, 0.5), "dur": 0.12, "op": "Aproximación en rápido"})
	# Acabado del contorno (con el Ø30 a 29,92 por el corrector mal puesto)
	var fin := [[Vector2(14.0, 0.0), 0.05], [Vector2(14.96, -0.96), 0.07], [Vector2(14.96, -20.0), 0.52], [Vector2(19.985, -20.0), 0.15],
		[Vector2(19.985, -40.0), 0.55], [Vector2(22.99, -40.0), 0.1], [Vector2(22.99, -55.0), 0.42], [Vector2(25.6, -55.0), 0.07]]
	for e in fin:
		p.append({"kind": "feed", "to": e[0], "dur": e[1], "op": "Acabado del contorno", "f": 0.15, "pass": 2, "ra": 0.9, "rpm": 1600.0, "coolant": true, "view": "detalle"})
	p.append({"kind": "rapid", "to": PARK, "dur": 0.28, "op": "Retirada", "rpm": 900.0, "view": "frontal"})
	p.append({"kind": "polish", "z_from": -21.0, "z_to": -39.0, "sweeps": 3.0, "dur": 0.85, "op": "Pulido con tela abrasiva · Ø40", "ra": 0.2, "rpm": 900.0})
	p.append({"kind": "wait", "dur": 0.35, "op": "Paro del cabezal", "rpm": 0.0, "view": "superior", "overlay": "desviacion"})
	p.append({"kind": "wait", "dur": 1.6, "op": "Inspección: Ø30 pasado de medida (corrector −0,08 mm)", "view": "superior", "overlay": "desviacion"})


## Barrido de la herramienta de a a b (en pasos de 0,05 mm como mucho).
func _sweep(a: Vector2, b: Vector2, pass_type: int, ra: float) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b) / 0.05)))
	for s in range(1, steps + 1):
		_cut_at(a.lerp(b, float(s) / float(steps)), pass_type, ra)


## Material que quita la herramienta con la punta teórica en p = (r, z): envolvente inferior del arco de punta
## (centro en (r + rε, z + rε)) y del filo secundario a 5°. Solo anillos con z > z_punta: el filo principal
## (κr = 95°) va inclinado hacia atrás y no toca el material que aún no ha pasado.
func _cut_at(p: Vector2, pass_type: int, ra: float) -> void:
	var i0 := maxi(0, int(floor((p.y - z0) / DZ)))
	var i1 := mini(n - 1, int(ceil((p.y + NOSE + 1.0 - z0) / DZ)))
	for i in range(i0, i1 + 1):
		var dzt := z0 + float(i) * DZ - p.y
		if dzt < DZ * 0.5:
			continue
		var env: float
		if dzt <= NOSE:
			var u := NOSE - dzt
			env = p.x + NOSE - sqrt(maxf(NOSE * NOSE - u * u, 0.0))
		else:
			env = p.x + (dzt - NOSE) * TAN5
		env = maxf(env, 0.0)
		if env < r[i] - 1e-6:
			_removed += PI * (r[i] * r[i] - env * env) * DZ
			r[i] = env
			ring_ra[i] = ra
			ring_pass[i] = pass_type
			_mark(i)
		elif pass_type >= 2 and env <= r[i] + 0.003 and ring_pass[i] != pass_type:
			# La pasada de acabado roza el anillo aunque no arranque nada: lo deja con su Ra
			ring_ra[i] = ra
			ring_pass[i] = pass_type
			_mark(i)


## Pulido: la tela abrasiva cubre ±3 mm alrededor de z; deja Ra ≈ 0,2 µm y se lleva unas micras.
func _polish(za: float, zb: float, ra: float) -> void:
	var lo := minf(za, zb) - 3.0
	var hi := maxf(za, zb) + 3.0
	var i0 := maxi(0, int(floor((lo - z0) / DZ)))
	var i1 := mini(n - 1, int(ceil((hi - z0) / DZ)))
	for i in range(i0, i1 + 1):
		var z := z0 + float(i) * DZ
		if z < -39.6 or z > -20.4 or r[i] <= 0.0:
			continue
		if ring_pass[i] != 3:
			r[i] -= 0.0015
			ring_pass[i] = 3
		ring_ra[i] = maxf(ra, ring_ra[i] * 0.55)
		_mark(i)


func _mark(i: int) -> void:
	if _dirty.x < 0:
		_dirty = Vector2i(i, i)
	else:
		_dirty = Vector2i(mini(_dirty.x, i), maxi(_dirty.y, i))


## Número con coma decimal (español).
static func _fmt(x: float, d: int) -> String:
	return (("%." + str(d) + "f") % x).replace(".", ",")
