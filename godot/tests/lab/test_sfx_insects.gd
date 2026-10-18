## Sonidos de los aguijones (core/lab/sfx_insects.gd, horneados con tools/bake_lab_extra.gd en assets/sfx/lab/): los WAV
## del repositorio están al día y hornear da siempre los mismos bytes; cada zumbido suena a la frecuencia de aleteo de
## su especie (Herrera et al. 2023) y cierra el bucle sin salto; los .import son los que toca (bucle o una vez); y el
## efecto de cada resultado de la 2.0 es el de los aguijones o, con todo lo demás, el de la 1.x.
extends "res://tests/case.gd"

const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const Insects = preload("res://core/lab/insects.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Bake = preload("res://tools/bake_lab_extra.gd")

const SR := SfxInsects.SR

var _renders := {}


func _render(id: String) -> PackedFloat32Array:
	if not _renders.has(id):
		_renders[id] = SfxInsects.render(id)
	return _renders[id]


## Los bytes que hornea tools/bake_lab_extra.gd: los bucles, con su cola (Sfx.with_loop_tail).
func _baked(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(_render(id)) if SfxInsects.is_loop(id) else _render(id), SR)


static func _sha256(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


## Potencia de x a la frecuencia f (Goertzel, con ventana de Hann).
static func goertzel(x: PackedFloat32Array, f: float) -> float:
	var n := x.size()
	var w := TAU * f / SR
	var coeff := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in n:
		var hann := 0.5 - 0.5 * cos(TAU * i / (n - 1))
		var s := x[i] * hann + coeff * s1 - s2
		s2 = s1
		s1 = s
	return s1 * s1 + s2 * s2 - coeff * s1 * s2


func test_ids_y_zumbidos_por_especie() -> void:
	var buzz := SfxInsects.buzz_ids()
	assert_eq(buzz.size(), 6, "zumban las seis especies con aleteo medido")
	for s: Dictionary in Insects.STINGERS:
		var hz: Variant = s.stinger.wingbeat.get("hz")
		assert_eq(SfxInsects.buzz_id(s), ("" if hz == null else "zumbido-" + String(s.id)), "%s: su zumbido" % s.id)
	assert_eq(SfxInsects.buzz_id(Insects.find_by_id("hormigabala")), "", "la hormiga bala no tiene alas: no zumba")
	assert_eq(SfxInsects.buzz_id(Insects.find_by_id("pepsis")), "", "de Pepsis no hay medida del aleteo: no se inventa")
	assert_eq(SfxInsects.buzz_id(Catalog.find_by_id(Catalog.CLAWS, "gato")), "", "una garra no zumba")
	assert_eq(SfxInsects.ids().size(), buzz.size() + 3, "los zumbidos, el picotazo, el desgarro y el pandeo")
	for id in SfxInsects.ids():
		assert_false(Sfx.SFX_IDS.has(id), "%s no pisa un efecto de la 1.x" % id)


func test_el_fundamental_del_bucle_es_el_aleteo_medido() -> void:
	for id in SfxInsects.buzz_ids():
		var claw := SfxInsects.species_of(id)
		var hz: float = claw.stinger.wingbeat.hz
		var f0 := SfxInsects.loop_hz(claw)
		assert_true(absf(f0 - hz) <= SfxInsects.HZ_STEP / 2.0 + 1e-9, "%s: %s Hz frente a %s medidos" % [id, f0, hz])
		assert_true(absf(f0 - hz) < float(claw.stinger.wingbeat.sdHz) / 10.0, "%s: el redondeo es mucho menor que la dispersión medida" % id)
		var cycles := f0 * SfxInsects.LOOP_S
		assert_near(cycles, roundf(cycles), 0.0, 1e-9, "%s: ciclos enteros en el bucle (%s)" % [id, cycles])
	assert_eq(SfxInsects.loop_hz(Insects.find_by_id("abeja")), 231.5, "la abeja, 231,5 Hz (Herrera et al. 2023)")


func test_cada_zumbido_suena_a_su_aleteo() -> void:
	# el pico está en el fundamental del bucle: más potencia que a ±10 %, ±20 % y que en el aleteo de las otras especies
	var all: Array = []
	for id in SfxInsects.buzz_ids():
		all.append(SfxInsects.loop_hz(SfxInsects.species_of(id)))
	for id in SfxInsects.buzz_ids():
		var x := _render(id)
		var f0 := SfxInsects.loop_hz(SfxInsects.species_of(id))
		var p0 := goertzel(x, f0)
		for k: float in [0.8, 0.9, 1.1, 1.2, 1.5, 0.5]:
			assert_true(p0 > 10.0 * goertzel(x, f0 * k), "%s: el fundamental (%s Hz) domina sobre %s Hz" % [id, f0, f0 * k])
		for f: float in all:
			if absf(f - f0) > 3.0:
				assert_true(p0 > 10.0 * goertzel(x, f), "%s: no suena a %s Hz (otra especie)" % [id, f])
		# el vibrato reparte cada armónico k en bandas laterales a ±1,5 Hz (índice k·β): se mira la banda entera
		var h2 := 0.0
		for df: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
			h2 = maxf(h2, goertzel(x, 2.0 * f0 + df))
		assert_true(h2 > 0.01 * p0, "%s: con armónicos, no un seno puro" % id)


func test_los_bucles_cierran_sin_salto_y_sin_saturar() -> void:
	for id in SfxInsects.ids():
		var x := _render(id)
		var peak := Dsp.peak(x)
		assert_true(peak > 0.1 and peak < 0.95, "%s: pico %s (se oye y no satura)" % [id, peak])
		if not SfxInsects.is_loop(id):
			assert_eq(x[0], 0.0, "%s: empieza en silencio (fundido)" % id)
			continue
		var n := x.size()
		assert_eq(n, int(SfxInsects.LOOP_S * SR), "%s: %s s" % [id, SfxInsects.LOOP_S])
		var d := PackedFloat32Array()
		d.resize(n - 1)
		for i in n - 1:
			d[i] = absf(x[i + 1] - x[i])
		d.sort()
		var p999: float = d[int(0.999 * (n - 2))]
		var seam := absf(x[0] - x[n - 1])
		assert_true(seam <= p999, "%s: salto en la costura (%s) mayor que el 99,9 %% de los saltos (%s)" % [id, seam, p999])
		assert_near(Dsp.rms(x), SfxInsects.BUZZ_RMS * sqrt(1.0 + SfxInsects.BREATH * SfxInsects.BREATH), 0.05, 0.0, "%s: mismo volumen en todos" % id)


func test_hornear_dos_veces_da_los_mismos_bytes() -> void:
	for id in [SfxInsects.STING, "zumbido-abeja"]:
		assert_eq(_sha256(SfxInsects.wav_bytes(id)), _sha256(SfxInsects.wav_bytes(id)), "%s: sha256 de dos horneados" % id)


func test_wav_del_repo_al_dia() -> void:
	for id in SfxInsects.ids():
		var path := Sfx.path_of(id)
		assert_true(FileAccess.file_exists(path), "%s existe" % path)
		var disk := FileAccess.get_file_as_bytes(path)
		var mem := _baked(id)
		assert_eq(_sha256(disk), _sha256(mem), "%s al día (vuelve a hornear con tools/bake_lab_extra.gd)" % id)


func test_importados_en_bucle_o_de_una_vez() -> void:
	for id in SfxInsects.ids():
		var s := load(Sfx.path_of(id)) as AudioStreamWAV
		assert_true(s != null, "%s se importa como AudioStreamWAV" % id)
		if s == null:
			continue
		assert_eq(s.mix_rate, SR, "%s: 22.050 Hz" % id)
		assert_false(s.stereo, "%s: mono" % id)
		if SfxInsects.is_loop(id):
			assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "%s: PCM de 16 bits, sin comprimir (la costura no salta)" % id)
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: bucle hacia delante" % id)
			assert_eq(s.loop_begin, 0, "%s: el bucle empieza en 0" % id)
			assert_eq(s.loop_end, s.data.size() / 2 - Sfx.LOOP_TAIL, "%s: el bucle acaba en su última muestra; detrás, la cola" % id)
			for i in Sfx.LOOP_TAIL:
				if s.data.decode_s16((s.loop_end + i) * 2) != s.data.decode_s16(i * 2):
					fail("%s: la muestra %d de la cola no repite la %d del principio" % [id, s.loop_end + i, i])
					break
		else:
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s: suena una vez" % id)
	assert_eq(Bake.import_params(100, true)["edit/loop_end"], "100", "loop_end = número de muestras (no −1)")


func test_el_efecto_de_cada_resultado() -> void:
	var skin: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "piel")
	var pine: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "madera")
	var bee: Dictionary = Insects.find_by_id("abeja")
	var p := {
		"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.INLAYS[0], "claw": bee, "target": skin,
		"force": bee.force, "length": 25.0, "type": Catalog.TYPES[1], "tear": false, "method": "puncion", "strike": false,
		"passes": 1.0, "wet": false,
	}
	assert_eq(SfxInsects.sfx_for_result(Physics.compute(p), skin), SfxInsects.STING, "la abeja pica: el picotazo")
	p.force = 0.001
	assert_eq(SfxInsects.sfx_for_result(Physics.compute(p), skin), "press", "sin perforar: la piel se hunde")
	p.merge({ "target": pine, "force": bee.force }, true)
	assert_eq(SfxInsects.sfx_for_result(Physics.compute(p), pine), "press", "la punta se aplasta contra el pino")
	p.merge({ "inlay": Catalog.find_by_id(Catalog.INLAYS, "acero"), "force": 1.0 }, true)
	var r := Physics.compute(p)
	assert_true(bool(r.toolBroken), "la abeja de acero pandea con 1 N")
	assert_eq(SfxInsects.sfx_for_result(r, pine), SfxInsects.BEND, "y cruje al doblarse")
	p.force = 0.5
	var r2 := Physics.compute(p)
	assert_eq(SfxInsects.sfx_for_result(r2, pine), Sfx.sfx_for_result(r2, pine), "si entra en el pino, el sonido de siempre")
	# con las herramientas de la 1.x, el mismo efecto que el oráculo (los 40 escenarios del golden, con la 2.0), salvo la
	# uña que se dobla (materiales de la 2.0, unidad 4a): «SE DOBLA LA UÑA» cruje como el aguijón que pandea; y la punta
	# que el hueso del brazo detiene (biología de la 2.0, §9.7): suena a pared, «press» (el casuario de 500 N)
	var golden: Array = load_json("res://tests/fixtures/lab-golden.json")
	var bent := 0
	var boned := 0
	for g: Dictionary in golden:
		var t: Dictionary = Catalog.find_by_id(Catalog.TARGETS, g.params.target)
		var q := {
			"geom": Catalog.find_by_id(Catalog.GEOMS, g.params.geom), "base": Catalog.find_by_id(Catalog.BASES, g.params.base),
			"inlay": Catalog.find_by_id(Catalog.INLAYS, g.params.inlay),
			"claw": Catalog.find_by_id(Catalog.CLAWS, g.params.claw) if g.params.claw != null else null, "target": t,
			"type": Catalog.find_by_id(Catalog.TYPES, g.params.type), "force": float(g.params.force),
			"length": float(g.params.length), "tear": g.params.tear, "method": g.params.method, "strike": g.params.strike,
			"passes": float(g.params.passes), "wet": g.params.wet,
		}
		var res := Physics.compute(q)
		var bends: bool = res.get("nail") is Dictionary and Physics.truthy(res.get("toolBroken")) and res.nail.mode == "dobla"
		if bends:
			bent += 1
			assert_eq(res.verdict, "SE DOBLA LA UÑA", "«%s»: la uña cedida es el veredicto" % g.name)
			assert_eq(SfxInsects.sfx_for_result(res, t), SfxInsects.BEND, "«%s»: la uña que se dobla cruje" % g.name)
		elif SfxInsects.bone_sfx(res) != "":
			boned += 1
			assert_eq(SfxInsects.sfx_for_result(res, t), "press", "«%s»: el húmero la para sin marcarlo" % g.name)
		else:
			assert_eq(SfxInsects.sfx_for_result(res, t), Sfx.sfx_for_result(res, t), "«%s»: el efecto de la 1.x" % g.name)
	assert_true(bent > 0, "en el golden hay uñas que se doblan (%d)" % bent)
	assert_eq(boned, 1, "en el golden, una punta que topa con el hueso (el casuario)")


## Biología de la 2.0 (pulido-biologia.md §9.7): la punta contra el hueso, con los efectos que ya había.
func test_la_punta_contra_el_hueso() -> void:
	var skin: Dictionary = Catalog.find_by_id(Catalog.TARGETS, "piel")
	var run := func(claw: String, zone: Variant, force: float, strike: bool, inlay := "none") -> Dictionary:
		return Physics.compute({
			"geom": Catalog.GEOMS[3], "base": Catalog.BASES[0], "inlay": Catalog.find_by_id(Catalog.INLAYS, inlay),
			"claw": Catalog.find_by_id(Catalog.CLAWS, claw), "target": skin, "force": force, "length": 25.0, "type": Catalog.TYPES[1],
			"tear": false, "method": "puncion", "strike": strike, "passes": 1.0, "wet": false, "zone": zone,
		})
	var marks: Dictionary = run.call("vibora", "cara", 4.0, false)
	assert_true(marks.pen.boneHit and float(marks.pen.boneIndentUm) > 0.0, "la víbora entra en el pómulo")
	assert_eq(SfxInsects.sfx_for_result(marks, skin), "pierce-solid", "lo marca: punción en un sólido")
	var through: Dictionary = run.call("casuario", "brazo", 500.0, true, "tungsteno")
	assert_true(through.pen.bonePierced, "el casuario de tungsteno atraviesa el húmero")
	assert_eq(SfxInsects.sfx_for_result(through, skin), "pierce-solid", "lo atraviesa")
	var wall: Dictionary = run.call("casuario", "brazo", 500.0, true)
	assert_true(wall.pen.boneHit and float(wall.pen.boneIndentUm) == 0.0 and not wall.pen.bonePierced, "la queratina topa sin marcarlo")
	assert_eq(SfxInsects.sfx_for_result(wall, skin), "press", "una pared que la para")
	var broken: Dictionary = run.call("gabon", "brazo", 30.0, true)
	assert_true(broken.toolBroken, "el colmillo se rompe contra el húmero")
	assert_eq(SfxInsects.sfx_for_result(broken, skin), "snap", "punta rota")
	var belly: Dictionary = run.call("gabon", "abdomen", 30.0, true)
	assert_eq(SfxInsects.sfx_for_result(belly, skin), Sfx.sfx_for_result(belly, skin), "sin hueso, el de siempre")
	# efectos que ya estaban horneados (assets/sfx/lab): no se inventa ninguno
	for id: String in ["pierce-solid", "press", "snap"]:
		assert_true(FileAccess.file_exists("res://assets/sfx/lab/%s.wav" % id), "%s.wav horneado" % id)
