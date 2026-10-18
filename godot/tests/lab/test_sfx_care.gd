## Sonidos de la cetrería (core/lab/sfx_care.gd, horneados con tools/bake_lab_extra.gd en assets/sfx/lab/): los tres
## bucles y el arranque y la parada del repositorio están al día y hornear da siempre los mismos bytes; los bucles cierran
## sin salto y nada satura; el motor del torno suena al giro de su primera velocidad (CareData.TOOLS.torno.rpm_steps) y el
## de la amoladora al de la suya (8000 rpm), el arranque sube de tono y la parada baja, y el roce late con los dientes que
## pasan; los bucles se importan en bucle y sin comprimir; y el estado los pide (motor encendido con su tono, que sube con
## las rpm y baja al apretar; roce al limar).
extends "res://tests/case.gd"

const SfxCare = preload("res://core/lab/sfx_care.gd")
const Sfx = preload("res://core/lab/sfx.gd")
const Dsp = preload("res://core/shared/dsp.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const State = preload("res://core/lab/claw_care_state.gd")
const Bake = preload("res://tools/bake_lab_extra.gd")

const SR := SfxCare.SR

var _renders := {}


func _render(id: String) -> PackedFloat32Array:
	if not _renders.has(id):
		_renders[id] = SfxCare.render(id)
	return _renders[id]


## Los bytes que hornea tools/bake_lab_extra.gd: los bucles, con su cola (Sfx.with_loop_tail).
func _baked(id: String) -> PackedByteArray:
	return Dsp.encode_wav(Sfx.with_loop_tail(_render(id)) if SfxCare.is_loop(id) else _render(id), SR)


static func _sha256(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


## Potencia de x a la frecuencia f (Goertzel, con ventana de Hann).
static func _goertzel(x: PackedFloat32Array, f: float) -> float:
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


func test_ids_y_fundamental_del_motor() -> void:
	assert_eq(SfxCare.ids(), [SfxCare.MOTOR, SfxCare.RASP, SfxCare.GRINDER, SfxCare.SPIN_UP, SfxCare.SPIN_DOWN, SfxCare.BEEP], "tres bucles, el arranque, la parada y el pitido de la lámpara (unidad 5o)")
	assert_eq(SfxCare.ids().filter(func(id: String) -> bool: return SfxCare.is_loop(id)), [SfxCare.MOTOR, SfxCare.RASP, SfxCare.GRINDER], "los bucles")
	var rpm := float((CareData.TOOLS.torno.rpm_steps as Array)[0])
	assert_eq(rpm, 6500.0, "la primera velocidad del Dremel 7300-PT")
	assert_near(SfxCare.motor_hz(), 108.5, 1e-12, 0.0, "6500 rpm = 108,3 Hz, redondeado a 0,5 Hz para cerrar el bucle")
	var x := _render(SfxCare.MOTOR)
	var p0 := _goertzel(x, SfxCare.motor_hz())
	var off := _goertzel(x, SfxCare.motor_hz() * 1.5)
	assert_true(p0 > 20.0 * off, "el motor suena a su giro (fundamental frente a 1,5 f0: %s / %s)" % [p0, off])


func test_la_amoladora_suena_a_su_giro_y_arranca_y_para() -> void:
	assert_eq(SfxCare.base_rpm(SfxCare.GRINDER), 8000.0, "la primera velocidad de la amoladora (manual de la Dremel Lite 7760)")
	assert_eq(SfxCare.base_rpm(SfxCare.MOTOR), 6500.0, "y la del torno")
	assert_eq(SfxCare.motor_of("amoladora"), SfxCare.GRINDER, "la amoladora, su bucle")
	assert_eq(SfxCare.motor_of("torno"), SfxCare.MOTOR, "el torno, el suyo")
	assert_near(SfxCare.grinder_hz(), 133.5, 1e-12, 0.0, "8000 rpm = 133,3 Hz, redondeado a 0,5 Hz para cerrar el bucle")
	var x := _render(SfxCare.GRINDER)
	var p0 := _goertzel(x, SfxCare.grinder_hz())
	var off := _goertzel(x, SfxCare.grinder_hz() * 1.5)
	assert_true(p0 > 20.0 * off, "la amoladora suena a su giro (%s / %s)" % [p0, off])
	assert_eq(SfxCare.SPIN_BASE_RPM, SfxCare.base_rpm(SfxCare.GRINDER), "el arranque y la parada, horneados a la primera velocidad")
	# el arranque sube de tono y la parada baja: el fundamental pesa al final del arranque y al principio de la parada
	var up := _render(SfxCare.SPIN_UP)
	var down := _render(SfxCare.SPIN_DOWN)
	var q := int(0.2 * SR)
	var f0 := SfxCare.grinder_hz()
	assert_true(_goertzel(up.slice(up.size() - q), f0) > 4.0 * _goertzel(up.slice(int(0.03 * SR), int(0.03 * SR) + q), f0), "el arranque llega a su giro al final")
	assert_true(_goertzel(down.slice(int(0.01 * SR), int(0.01 * SR) + q), f0) > 4.0 * _goertzel(down.slice(down.size() - q), f0), "la parada lo pierde")
	for id in [SfxCare.SPIN_UP, SfxCare.SPIN_DOWN]:
		var pk := Dsp.peak(_render(id))
		assert_true(pk > 0.1 and pk < 0.95, "%s: pico %s (se oye y no satura)" % [id, pk])


func test_el_roce_late_con_los_dientes() -> void:
	var x := _render(SfxCare.RASP)
	# la envolvente (valor absoluto) tiene una línea fuerte a los dientes por segundo
	var env := PackedFloat32Array()
	env.resize(x.size())
	for i in x.size():
		env[i] = absf(x[i])
	var at := _goertzel(env, SfxCare.RASP_TPS)
	var near := _goertzel(env, SfxCare.RASP_TPS * 1.37)
	assert_true(at > 10.0 * near, "late a %s dientes por segundo (%s frente a %s)" % [SfxCare.RASP_TPS, at, near])
	assert_eq(SfxCare.RASP_TPS, State.RASP_REF_TPS, "el mismo de referencia que el tono del estado")


func test_los_bucles_cierran_sin_salto_y_sin_saturar() -> void:
	for id in SfxCare.ids().filter(func(i: String) -> bool: return SfxCare.is_loop(i)):
		var x := _render(id)
		var n := x.size()
		assert_eq(n, int(SfxCare.LOOP_S * SR), "%s: %s s" % [id, SfxCare.LOOP_S])
		var peak := Dsp.peak(x)
		assert_true(peak > 0.1 and peak < 0.95, "%s: pico %s (se oye y no satura)" % [id, peak])
		var d := PackedFloat32Array()
		d.resize(n - 1)
		for i in n - 1:
			d[i] = absf(x[i + 1] - x[i])
		d.sort()
		var p999: float = d[int(0.999 * (n - 2))]
		var seam := absf(x[0] - x[n - 1])
		assert_true(seam <= p999, "%s: salto en la costura (%s) mayor que el 99,9 %% de los saltos (%s)" % [id, seam, p999])


func test_hornear_dos_veces_da_los_mismos_bytes() -> void:
	for id in SfxCare.ids():
		assert_eq(_sha256(SfxCare.wav_bytes(id)), _sha256(_baked(id)), "%s: sha256 de dos horneados" % id)


func test_wav_del_repo_al_dia() -> void:
	for id in SfxCare.ids():
		var path := Sfx.path_of(id)
		assert_true(FileAccess.file_exists(path), "%s existe" % path)
		var disk := FileAccess.get_file_as_bytes(path)
		var mem := _baked(id)
		assert_eq(_sha256(disk), _sha256(mem), "%s al día (vuelve a hornear con tools/bake_lab_extra.gd)" % id)


func test_importados_en_bucle() -> void:
	for id in SfxCare.ids().filter(func(i: String) -> bool: return SfxCare.is_loop(i)):
		var s := load(Sfx.path_of(id)) as AudioStreamWAV
		assert_true(s != null, "%s se importa como AudioStreamWAV" % id)
		if s == null:
			continue
		assert_eq(s.mix_rate, SR, "%s: 22.050 Hz" % id)
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "%s: sin comprimir (la costura no salta)" % id)
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: bucle hacia delante" % id)
		assert_eq(s.loop_end, s.data.size() / 2 - Sfx.LOOP_TAIL, "%s: el bucle acaba en su última muestra; detrás, la cola" % id)
		for i in Sfx.LOOP_TAIL:
			if s.data.decode_s16((s.loop_end + i) * 2) != s.data.decode_s16(i * 2):
				fail("%s: la muestra %d de la cola no repite la %d del principio" % [id, s.loop_end + i, i])
				break
	assert_eq(Bake.import_params(100, true)["edit/loop_mode"], "2", "los bucles, hacia delante")


func test_el_estado_pide_cada_bucle() -> void:
	var st := State.new()
	var snd := st.sound_view()
	assert_false(bool(snd.motor) or bool(snd.rasp), "en silencio al empezar: las herramientas en la bandeja")
	st.pick("torno")
	st.set_rotary(true)
	assert_true(bool(st.sound_view().motor), "el torno encendido suena")
	assert_near(float(st.sound_view().motor_pitch), 1.0, 1e-12, 0.0, "a 6500 rpm, el tono del bucle")
	st.cycle_rpm()
	assert_near(float(st.sound_view().motor_pitch), 2.0, 1e-12, 0.0, "a 13 000 rpm, una octava más alto")
	st.set_paused(true)
	assert_false(bool(st.sound_view().motor), "en pausa, no")
	st.set_paused(false)
	# la amoladora: su bucle, con el tono de cada velocidad (sube con las rpm) y que baja al apretar contra la garra
	st.pick("amoladora")
	assert_false(bool(st.sound_view().motor), "al coger la amoladora, apagada")
	st.set_rotary(true)
	var g := st.sound_view()
	assert_eq(String(g.motor_id), SfxCare.GRINDER, "suena la amoladora")
	assert_near(float(g.motor_pitch), 1.0, 1e-12, 0.0, "a 8000 rpm, el tono del bucle")
	var prev := float(g.motor_pitch)
	for i in 3:
		st.cycle_rpm()
		assert_true(float(st.sound_view().motor_pitch) > prev, "más rpm, más agudo (%s rpm)" % st.rpm())
		prev = float(st.sound_view().motor_pitch)
	assert_near(prev, 25000.0 / 8000.0, 1e-12, 0.0, "a 25 000 rpm")
	st.press_on(st.care.apex_mm() - 0.5)
	st.tick(1.0 / 60.0)
	var loaded := st.sound_view()
	assert_true(float(loaded.motor_load) > 0.0 and float(loaded.motor_pitch) < prev, "apretando contra la garra, baja (%s)" % loaded.motor_pitch)
	st.set_force(State.FORCE_MAX)
	assert_true(float(st.sound_view().motor_pitch) < float(loaded.motor_pitch), "y más cuanto más aprieta")
	st.release()
	assert_near(float(st.sound_view().motor_pitch), prev, 1e-12, 0.0, "al levantarla, vuelve a su giro")
	st.pick("lima_bastarda")
	assert_false(bool(st.sound_view().motor), "al dejar el torno, se apaga")
	st.press_on(st.care.apex_mm() - 1.0)
	st.drag(10.0, 10.0, 0.0, 1.0 / 60.0)
	st.tick(1.0 / 60.0)
	assert_true(bool(st.sound_view().rasp), "limando, el roce")
	var pitch := float(st.sound_view().rasp_pitch)
	assert_true(pitch >= 0.6 and pitch <= 1.8, "con su tono (%s)" % pitch)
	st.release()
	for i in 30:
		st.tick(1.0 / 60.0)
	assert_false(bool(st.sound_view().rasp), "sin limar, se calla")
