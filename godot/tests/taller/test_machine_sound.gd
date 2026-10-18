## Sonido de máquina del taller (unidad 8): DSP compartida (core/shared/dsp.gd) contra el motor 1.x, función de
## marco (core/taller/machine_sound.gd) y bucles horneados (tools/bake_sounds.gd → assets/sfx/taller/).
extends "res://tests/case.gd"

const Dsp = preload("res://core/shared/dsp.gd")
const Rng = preload("res://core/shared/rng.gd")
const MS = preload("res://core/taller/machine_sound.gd")
const Bake = preload("res://tools/bake_sounds.gd")

const SR := 22050
const SCRATCH := 1.12  # s: lo que dura un rayado en sfx.js
const KINDS := [
	"acero", "inox", "fundicion", "aluminio", "laton", "titanio", "niquel", "madera", "plastico", "piedra", "vidrio",
]

var sfx_fx: Dictionary
var _renders := {}  # bucles ya horneados en memoria en este archivo de tests (id → muestras)


func before_each() -> void:
	if sfx_fx.is_empty():
		sfx_fx = load_json("res://tests/fixtures/sfx.json")


# ── La DSP es un port exacto de sfx.js: los 22 efectos del laboratorio salen con los mismos bytes ──


func test_dsp_reproduce_los_22_efectos_de_la_1x() -> void:
	var ids: Array = sfx_fx["ids"]
	assert_eq(ids.size(), 22, "número de efectos de la 1.x")
	for id in ids:
		var wav := Dsp.encode_wav(_render_sfx(id), int(sfx_fx["rate"]))
		var h := HashingContext.new()
		h.start(HashingContext.HASH_SHA256)
		h.update(wav)
		assert_eq(h.finish().hex_encode(), sfx_fx["sha256"][id], "sha256 de %s.wav" % id)


func test_wav_pcm_16_bits_como_encode_wav() -> void:
	# 0,5·32767 = 16383,5 y −16383,5: empates exactos (0,5 es exacto en float32)
	var x := PackedFloat32Array([0.0, 0.5, -0.5, 1.0, -1.0, 2.0, -2.0, 0.25])
	var b := Dsp.encode_wav(x, 22050)
	assert_eq(b.size(), 44 + 16, "tamaño")
	assert_eq(b.slice(0, 4).get_string_from_ascii(), "RIFF")
	assert_eq(b.slice(8, 16).get_string_from_ascii(), "WAVEfmt ")
	assert_eq(b.decode_u32(4), 36 + 16, "tamaño RIFF")
	assert_eq(b.decode_u16(20), 1, "PCM")
	assert_eq(b.decode_u16(22), 1, "mono")
	assert_eq(b.decode_u32(24), 22050, "frecuencia")
	assert_eq(b.decode_u32(28), 44100, "bytes por segundo")
	assert_eq(b.decode_u16(34), 16, "bits")
	var want := [0, 16384, -16383, 32767, -32767, 32767, -32767, 8192]  # Math.round: los empates suben
	for i in want.size():
		assert_eq(b.decode_s16(44 + i * 2), want[i], "muestra %d" % i)


func test_biquad_rbj_ganancias() -> void:
	# Paso bajo: ganancia 1 en continua; paso alto: 0 en continua; paso banda: 1 en su centro (RBJ, pico 0 dB)
	var lp := Dsp.biquad("lp", 0.707, float(SR), 1000.0)
	var hp := Dsp.biquad("hp", 0.707, float(SR), 1000.0)
	var y_lp := 0.0
	var y_hp := 0.0
	for i in 4000:
		y_lp = lp.run(1.0)
		y_hp = hp.run(1.0)
	assert_near(y_lp, 1.0, 1e-9, 1e-9, "paso bajo en continua")
	assert_near(y_hp, 0.0, 1e-9, 1e-9, "paso alto en continua")
	var bp := Dsp.biquad("bp", 2.0, float(SR), 1500.0)
	var amp := 0.0
	for i in 20000:
		var y := bp.run(sin(TAU * 1500.0 * i / SR))
		if i > 10000:
			amp = maxf(amp, absf(y))
	assert_near(amp, 1.0, 2e-3, 0.0, "paso banda en su centro")


# ── Función de marco ──


func test_marco_frecuencias_de_giro_paso_motor_y_engrane() -> void:
	# Radial de 125 mm a 11.000 rpm en vacío: el disco a 183,3 Hz
	var g := MS.frame({ "process": "grinder", "rpm": 11000.0 })
	assert_near(_hz(g, "spindle_1x"), 11000.0 / 60.0, 1e-12, 0.0, "radial 1×")
	assert_near(_hz(g, "rotor"), 3.0 * 11000.0 / 60.0, 1e-12, 0.0, "rotor del motor universal a 3×")
	# Fresa de 4 dientes a 3000 rpm: paso de dientes a 200 Hz
	var m := MS.frame({ "process": "mill", "rpm": 3000.0, "teeth": 4 })
	assert_near(_hz(m, "teeth_pass"), 200.0, 1e-12, 0.0, "fresa z = 4")
	var m2 := MS.frame({ "process": "mill", "rpm": 3000.0, "teeth": 2 })
	assert_near(_hz(m2, "teeth_pass"), 100.0, 1e-12, 0.0, "fresa z = 2")
	# Torno: paso de garras jaws·n/60 y engrane 47·n/60
	var l := MS.frame({ "process": "lathe", "rpm": 1200.0, "jaws": 3 })
	assert_near(_hz(l, "jaws_pass"), 60.0, 1e-12, 0.0, "plato de 3 garras")
	var l4 := MS.frame({ "process": "lathe", "rpm": 1200.0, "jaws": 4 })
	assert_near(_hz(l4, "jaws_pass"), 80.0, 1e-12, 0.0, "plato de 4 garras")
	assert_near(_hz(l, "gear_mesh"), 47.0 * 20.0, 1e-12, 0.0, "frecuencia de engrane")
	assert_near(_hz(l, "spindle_1x"), 20.0, 1e-12, 0.0, "giro n/60")
	# Taladro: dos labios
	var dr := MS.frame({ "process": "drill", "rpm": 900.0, "teeth": 2 })
	assert_near(_hz(dr, "teeth_pass"), 30.0, 1e-12, 0.0, "broca de 2 labios")
	# Motor de inducción: 2·f de red y múltiplos pares (50 Hz en Europa; 60 Hz si se pide)
	assert_near(_hz(l, "motor_2f"), 100.0, 1e-12, 0.0, "zumbido a 100 Hz")
	assert_near(_hz(l, "motor_4f"), 200.0, 1e-12, 0.0, "armónico a 200 Hz")
	var us := MS.frame({ "process": "lathe", "rpm": 1200.0, "mains_hz": 60.0 })
	assert_near(_hz(us, "motor_2f"), 120.0, 1e-12, 0.0, "red de 60 Hz")
	# Refrigerante: bomba y paso de álabes
	var c := MS.frame({ "process": "lathe", "rpm": 1200.0, "coolant": true })
	assert_near(_hz(c, "pump_vanes"), 280.0, 1e-12, 0.0, "álabes de la bomba")
	assert_true(c["coolant_gain"] > 0.0 and l["coolant_gain"] == 0.0, "refrigerante solo si está abierto")


func test_marco_chatter_cerca_del_modo_y_no_sincrono() -> void:
	var base := { "process": "lathe", "rpm": 1200.0, "pc_kw": 2.0, "chatter": { "risk": 1.5, "mode_hz": 820.0 } }
	var ch: Dictionary = MS.frame(base)["chatter"]
	assert_near(ch["hz"], 820.0 * sqrt(1.0 + 2.0 * MS.CHATTER_ZETA), 1e-12, 0.0, "f_c = f_n·√(1+2ζ)")
	assert_true(ch["hz"] > 820.0 and ch["hz"] < 820.0 * 1.05, "justo por encima del modo")
	var ratio: float = ch["hz"] / ch["mod_hz"]
	assert_true(absf(ratio - roundf(ratio)) > 0.05, "no es múltiplo del paso por vuelta (%s)" % ratio)
	assert_true(ch["gain"] > 0.0 and ch["depth"] > 0.0, "suena y se modula")
	# Fresado: bandas laterales a ±paso de dientes
	var mill_in := { "process": "mill", "rpm": 3000.0, "teeth": 4, "pc_kw": 1.0, "chatter": { "risk": 1.4, "mode_hz": 1500.0 } }
	var mill := MS.frame(mill_in)
	assert_near(mill["chatter"]["mod_hz"], 4.0 * mill["rpm"] / 60.0, 1e-12, 0.0, "modulación al paso de dientes (giro real)")
	assert_true(mill["rpm"] < 3000.0 and mill["rpm"] > 2900.0, "con la caída de giro del motor de inducción")
	# Estable (risk < 1) o sin cortar: no hay chatter
	var stable := base.duplicate(true)
	stable["chatter"] = { "risk": 0.9, "mode_hz": 820.0 }
	assert_eq(MS.frame(stable)["chatter"]["gain"], 0.0, "estable")
	var idle := base.duplicate(true)
	idle["pc_kw"] = 0.0
	assert_eq(MS.frame(idle)["chatter"]["gain"], 0.0, "sin corte")
	# Más riesgo, más chatter
	var last := -1.0
	for r in [1.0, 1.1, 1.2, 1.3, 1.4, 1.5]:
		var d := base.duplicate(true)
		d["chatter"] = { "risk": r, "mode_hz": 820.0 }
		var gain: float = MS.frame(d)["chatter"]["gain"]
		assert_true(gain >= last, "chatter monótono con el riesgo")
		last = gain


func test_marco_mas_pc_mas_corte_y_sin_corte_nada() -> void:
	for p in MS.PROCESSES:
		for kind in KINDS:
			var pmax: float = MS.MACHINES[p]["pmax_kw"]
			var base := { "process": p, "rpm": float(MS.MACHINES[p]["rpm_ref"]), "work_kind": kind, "pmax_kw": pmax,
				"chatter": { "risk": 1.5, "mode_hz": 900.0 }, "disc_id": "diamante" }
			var idle := MS.frame(base)
			assert_eq(idle["noise"]["gain"], 0.0, "%s/%s: sin corte, ganancia de corte 0" % [p, kind])
			assert_eq(idle["crackle_rate"], 0.0, "%s/%s: sin corte no hay viruta" % [p, kind])
			assert_eq(idle["chatter"]["gain"], 0.0, "%s/%s: sin corte no hay chatter" % [p, kind])
			assert_eq(_gain(idle, "sheet_ring"), 0.0, "%s/%s: la chapa no suena sin corte" % [p, kind])
			var last := 0.0
			for i in range(1, 13):
				var d := base.duplicate()
				d["pc_kw"] = pmax * i / 10.0
				var gain: float = MS.frame(d)["noise"]["gain"]
				assert_true(gain > last, "%s/%s: más Pc, más corte (%s ≤ %s con Pc = %s)" % [p, kind, gain, last, d["pc_kw"]])
				last = gain


func test_marco_puro_y_determinista() -> void:
	var inp := { "process": "grinder", "rpm": 11000.0, "pc_kw": 0.4, "work_kind": "acero", "disc_id": "grueso_3mm",
		"chatter": { "risk": 1.2, "mode_hz": 700.0 }, "coolant": false, "tool_pos": Vector3(0.3, 0.0, 0.1) }
	var copy := inp.duplicate(true)
	var a := MS.frame(inp)
	var b := MS.frame(inp)
	assert_true(same(a, b), "misma entrada, mismo marco")
	assert_true(same(inp, copy), "la entrada no se modifica")
	assert_true(same(MS.voices(a), MS.voices(b)), "mismas voces")
	assert_near(a["pan"], 0.3 / MS.PAN_HALF_M, 1e-6, 0.0, "paneo desde tool_pos.x (Vector3 guarda float32)")
	# Entrada vacía o rara: marco válido (torno parado), sin errores
	var z := MS.frame({})
	assert_eq(z["process"], "lathe")
	assert_eq(z["rpm"], 0.0)
	var odd := MS.frame({ "process": "nave", "work_kind": "queso", "rpm": -5, "pc_kw": -1, "tool_pos": "aquí" })
	assert_eq(odd["noise"]["gain"], 0.0, "entrada rara: sin corte")


func test_radial_suena_distinto_segun_material_y_disco() -> void:
	var base := { "process": "grinder", "rpm": 11000.0, "pc_kw": 0.4, "disc_id": "fino_1mm" }
	var fr := {}
	for kind in ["acero", "aluminio", "plastico"]:
		var d := base.duplicate()
		d["work_kind"] = kind
		fr[kind] = MS.frame(d)
	# El acero chirría (banda alta y estrecha); aluminio y plástico, más apagados (banda más baja y paso bajo)
	var nz := {}
	for kind in fr:
		nz[kind] = fr[kind]["noise"]
	assert_true(nz["acero"]["fc_hz"] > nz["aluminio"]["fc_hz"], "acero más agudo que aluminio")
	assert_true(nz["aluminio"]["fc_hz"] > nz["plastico"]["fc_hz"], "aluminio más agudo que plástico")
	assert_true(nz["acero"]["q"] > nz["aluminio"]["q"], "el chirrido del acero es más estrecho")
	assert_true(nz["acero"]["lp_hz"] > nz["aluminio"]["lp_hz"] and nz["aluminio"]["lp_hz"] > nz["plastico"]["lp_hz"], "apagado")
	# La chapa resuena: mucho en acero, algo en aluminio, casi nada en plástico (amortigua y se funde)
	var ring := {}
	for kind in fr:
		ring[kind] = _gain(fr[kind], "sheet_ring")
	assert_true(ring["acero"] > ring["aluminio"], "«ring»: acero > aluminio (%s)" % ring)
	assert_true(ring["aluminio"] > 5.0 * ring["plastico"], "«ring»: aluminio ≫ plástico (%s)" % ring)
	assert_true(fr["acero"]["crackle_rate"] > fr["aluminio"]["crackle_rate"] and fr["plastico"]["crackle_rate"] == 0.0, "chispas")
	# Los modos de la chapa escalan con h·c_p: aluminio de 1 mm frente al acero de 0,8 mm
	var ratio := _hz(fr["aluminio"], "sheet_ring") / _hz(fr["acero"], "sheet_ring")
	assert_near(ratio, MS.sheet_scale("aluminio", 1.0), 1e-12, 0.0, "escala de la chapa")
	assert_near(MS.sheet_scale("acero", 0.8), 1.0, 1e-12, 0.0, "referencia")
	# Cada disco suena distinto; el de diamante silba a segmentos·n/60
	var seen := []
	for disc in MS.DISCS:
		var d := base.duplicate()
		d["work_kind"] = "acero"
		d["disc_id"] = disc
		var f := MS.frame(d)
		var sig := [f["noise"]["fc_hz"], f["noise"]["q"], f["noise"]["gain"], f["crackle_rate"], f["rpm"]]
		assert_false(seen.has(sig), "el disco %s suena distinto" % disc)
		seen.append(sig)
		var seg := _tone(f, "segments_pass")
		if disc == "diamante":
			assert_near(seg["hz"], 10.0 * f["rpm"] / 60.0, 1e-12, 0.0, "segmentos del disco de diamante")
		else:
			assert_true(seg.is_empty(), "sin segmentos en %s" % disc)


func test_modos_de_la_chapa_de_kirchhoff() -> void:
	# f_11 de una placa apoyada de acero de 0,8 mm y 300 × 200 mm: (π/2)·h·c_p/√12·((1/a)² + (1/b)²)
	var cp := sqrt(210e9 / (7850.0 * (1.0 - 0.09)))
	var want := PI / 2.0 * 0.0008 / sqrt(12.0) * cp * (1.0 / 0.09 + 1.0 / 0.04)
	assert_near(MS.plate_mode_hz(1, 1, 0.8, 300.0, 200.0, "acero"), want, 1e-12, 0.0, "f_11")
	assert_near(want, 71.0, 0.01, 0.0, "f_11 ≈ 71 Hz")
	var modes := MS.sheet_modes()
	assert_true(modes.size() >= 10, "el «ring» tiene una docena de modos: %d" % modes.size())
	for md in modes:
		assert_true(int(md[0]) % 2 == 1 and int(md[1]) % 2 == 1, "modos impar-impar")
	assert_near(MS.sheet_key_hz(), modes[0][2], 1e-12, 0.0, "modo clave = el más grave")


func test_fichas_con_fuente_y_calidad() -> void:
	var catalogs := { "MACHINES": MS.MACHINES, "KIND": MS.KIND, "GRINDER_KIND": MS.GRINDER_KIND, "DISCS": MS.DISCS, "SHEET": MS.SHEET,
		"SHARPENERS": MS.SHARPENERS }
	for cat in catalogs:
		var c: Dictionary = catalogs[cat]
		for id in c:
			assert_true(str(c[id].get("source", "")).length() > 20, "%s.%s: lleva source" % [cat, id])
			assert_true(MS.QUALITIES.has(c[id].get("quality", "")), "%s.%s: quality válida" % [cat, id])
	for kind in KINDS:
		assert_true(MS.KIND.has(kind), "KIND cubre %s (CONTRATOS.md)" % kind)


func test_radial_disco_en_cualquier_material_y_banda_acotada() -> void:
	# El disco cambia el sonido también fuera de las chapas (p. ej., diamante frente a láminas sobre piedra)
	var sigs := []
	for disc in MS.DISCS:
		var f := MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.4, "work_kind": "piedra", "disc_id": disc })
		var sig := [f["noise"]["fc_hz"], f["noise"]["q"], f["noise"]["gain"], f["crackle_rate"]]
		assert_false(sigs.has(sig), "piedra con %s suena distinto" % disc)
		sigs.append(sig)
	# La banda cae siempre dentro del ruido horneado, en cualquier máquina, material y disco
	for p in MS.PROCESSES:
		for kind in KINDS:
			for disc in MS.DISCS:
				var inp := { "process": p, "rpm": float(MS.MACHINES[p]["rpm_ref"]) * 2.0, "pc_kw": 0.3, "work_kind": kind, "disc_id": disc }
				var fc: float = MS.frame(inp)["noise"]["fc_hz"]
				assert_true(fc >= MS.CUT_FC_MIN and fc <= MS.CUT_FC_MAX, "%s/%s/%s: banda a %s Hz" % [p, kind, disc, fc])
	# Chispas proporcionales a la carga (la ficha da las de plena carga)
	var light: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.18, "work_kind": "acero" })["crackle_rate"]
	var full: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.72, "work_kind": "acero" })["crackle_rate"]
	assert_near(full, 120.0, 1e-9, 0.0, "chispas a plena carga")
	assert_near(light, 30.0, 1e-9, 0.0, "a un cuarto de carga, un cuarto de chispas")


func test_giro_nunca_negativo() -> void:
	# Caída grande y sobrecarga: el giro se queda en 0, nada sale NaN
	var f := MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 1.08, "speed_droop": 0.9, "work_kind": "acero" })
	assert_true(f["rpm"] >= 0.0 and f["vc"] >= 0.0, "giro y vc no negativos: %s rpm" % f["rpm"])
	assert_false(is_nan(float(f["noise"]["fc_hz"])), "banda definida")
	for v in MS.voices(f).values():
		if v is Dictionary and v.has("volume"):
			assert_false(is_nan(float(v["volume"])) or is_inf(float(v["volume"])), "volúmenes finitos")


func test_bajada_de_rpm_bajo_carga() -> void:
	var last := INF
	for pc in [0.0, 0.2, 0.4, 0.6, 0.72, 0.9]:
		var rpm: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": pc })["rpm"]
		assert_true(rpm < last, "más carga, menos giro (%s rpm con %s kW)" % [rpm, pc])
		last = rpm
	var full: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.72 })["rpm"]
	assert_true(full <= 11000.0 * 0.75, "el motor universal cae mucho: %s rpm" % full)
	var lathe: float = MS.frame({ "process": "lathe", "rpm": 1200.0, "pc_kw": 5.5 })["rpm"]
	assert_true(lathe >= 1200.0 * 0.95 and lathe < 1200.0, "el de inducción cae poco (deslizamiento): %s rpm" % lathe)
	var fino: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.4, "disc_id": "fino_1mm" })["rpm"]
	var grueso: float = MS.frame({ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.4, "disc_id": "grueso_3mm" })["rpm"]
	assert_true(grueso < fino, "el disco grueso roza más y frena más")
	var regulated: float = MS.frame({ "process": "lathe", "rpm": 1200.0, "pc_kw": 5.5, "speed_droop": 0.0 })["rpm"]
	assert_eq(regulated, 1200.0, "con variador (speed_droop = 0) no cae")


func test_voces_tono_y_volumen_desde_el_marco() -> void:
	var inputs := [
		{ "process": "lathe", "rpm": 800.0, "jaws": 4, "pc_kw": 2.0, "work_kind": "inox", "coolant": true,
			"chatter": { "risk": 1.3, "mode_hz": 640.0 } },
		{ "process": "mill", "rpm": 4500.0, "teeth": 3, "pc_kw": 1.2, "work_kind": "aluminio" },
		{ "process": "drill", "rpm": 600.0, "teeth": 2, "pc_kw": 0.5 },
		{ "process": "grinder", "rpm": 11000.0, "pc_kw": 0.5, "disc_id": "diamante", "work_kind": "aluminio" },
		{ "process": "sharpener", "rpm": 2850.0, "pc_kw": 0.1, "work_kind": "acero" },
	]
	for inp in inputs:
		var fr := MS.frame(inp)
		var v := MS.voices(fr)
		var master: float = fr["master_gain"]
		var keys := {}
		for t in fr["tones"]:
			if not keys.has(t["layer"]):
				keys[t["layer"]] = t
		for layer in keys:
			var t: Dictionary = keys[layer]
			var info: Dictionary = MS.LOOPS[v[layer]["loop"]]
			var where := "%s/%s" % [inp["process"], layer]
			var ref := MS.loop_ref_hz(v[layer]["loop"])
			assert_true(ref > 0.0, "%s: el bucle tiene tono clave" % where)
			assert_near(v[layer]["pitch"] * ref, t["hz"], 1e-12, 0.0, "%s: pitch·ref = tono clave" % where)
			var want_vol := master * MS.HEADROOM_GAIN * float(t["gain"]) / float(info["level"])
			assert_near(v[layer]["volume"], want_vol, 1e-12, 0.0, "%s: volumen" % where)
		assert_near(v["bus"]["cut_resonance"] * 2.0, fr["noise"]["q"], 1e-12, 0.0, "Q del paso banda = 2·resonance")
		assert_near(v["bus"]["cut_hz"], fr["noise"]["fc_hz"], 1e-12, 0.0, "centro del corte")
		var ch: Dictionary = fr["chatter"]
		if ch["gain"] > 0.0:
			assert_near(v["chatter"]["pitch"] * 1000.0, ch["hz"], 1e-12, 0.0, "tono del chatter")
			assert_near(v["chatter_lo"]["pitch"] * 1000.0, ch["hz"] - ch["mod_hz"], 1e-12, 0.0, "banda lateral inferior")
			assert_near(v["chatter_hi"]["pitch"] * 1000.0, ch["hz"] + ch["mod_hz"], 1e-12, 0.0, "banda lateral superior")
		assert_true(v["grains"]["rate"] <= MS.GRAIN_RATE_MAX, "granos acotados")


# ── Afiladoras (process "sharpener" y sus variantes) ──


func test_afiladoras_giro_motor_y_variantes() -> void:
	# Esmeriladora de banco (la variante por defecto): motor de inducción de 2 polos a 2950 rpm → 49,2 Hz
	var bench := MS.frame({ "process": "sharpener", "rpm": 2950.0 })
	assert_eq(bench["machine_kind"], "banco", "sin machine_kind, la esmeriladora de banco")
	assert_near(_hz(bench, "spindle_1x"), 2950.0 / 60.0, 1e-12, 0.0, "giro n/60 = 49,2 Hz")
	assert_near(_hz(bench, "spindle_2x"), 2.0 * 2950.0 / 60.0, 1e-12, 0.0, "2×")
	assert_near(_hz(bench, "spindle_3x"), 3.0 * 2950.0 / 60.0, 1e-12, 0.0, "3×")
	assert_near(_hz(bench, "motor_2f"), 100.0, 1e-12, 0.0, "zumbido del motor a 2·50 Hz")
	assert_true(same(bench, MS.frame({ "process": "sharpener", "machine_kind": "banco", "rpm": 2950.0 })), "«banco» explícito")
	assert_true(same(bench, MS.frame({ "process": "sharpener", "machine_kind": "tostadora", "rpm": 2950.0 })), "variante desconocida → banco")
	assert_eq(_layer_count(bench, "spindle"), 3, "la esmeriladora tiene 1×, 2× y 3×")
	# Afiladora húmeda lenta: sin tono de giro (1,67 Hz no se oye), con el roce de la piedra, que sigue al giro
	var wet := MS.frame({ "process": "sharpener", "machine_kind": "humeda_lenta", "rpm": 100.0, "coolant": true })
	assert_eq(_layer_count(wet, "spindle"), 0, "la piedra lenta no da un tono de giro")
	assert_near(_hz(wet, "motor_2f"), 100.0, 1e-12, 0.0, "el motor de inducción zumba a 100 Hz")
	assert_true(float(wet["rub"]["gain"]) > 0.0, "la piedra suena al girar mojada")
	assert_near(float(wet["rub"]["pitch"]), 1.0, 1e-12, 0.0, "a las rpm de referencia, el bucle tal cual")
	assert_eq(float(wet["coolant_gain"]), 0.0, "sin bomba de taladrina: el agua va en su bandeja")
	var wet120 := MS.frame({ "process": "sharpener", "machine_kind": "humeda_lenta", "rpm": 120.0 })
	assert_near(float(wet120["rub"]["pitch"]), 1.2, 1e-12, 0.0, "el roce late más deprisa a 120 rpm")
	assert_true(float(wet120["rub"]["gain"]) > float(wet["rub"]["gain"]), "y suena más")
	var wet_stop := MS.frame({ "process": "sharpener", "machine_kind": "humeda_lenta", "rpm": 0.0 })
	assert_eq(float(wet_stop["rub"]["gain"]), 0.0, "parada, la piedra no suena")
	# Afiladoras compactas de brocas y de fresas: motor universal a 4400 rpm con la muela en su eje
	for mk in ["afilabrocas", "afilafresas"]:
		var c := MS.frame({ "process": "sharpener", "machine_kind": mk, "rpm": 4400.0 })
		assert_eq(c["machine_kind"], mk, mk)
		assert_near(_hz(c, "spindle_1x"), 4400.0 / 60.0, 1e-12, 0.0, "%s: giro n/60" % mk)
		assert_near(_hz(c, "commutator"), 12.0 * 4400.0 / 60.0, 1e-12, 0.0, "%s: delgas del colector" % mk)
		assert_eq(MS.voices(c)["spindle"]["loop"], "spindle_compact", "%s: su bucle" % mk)
		assert_eq(float(c["rub"]["gain"]), 0.0, "%s: sin piedra húmeda" % mk)
	# Las demás máquinas no cambian: sin variante ni roce
	for p in ["lathe", "mill", "drill", "grinder"]:
		var f := MS.frame({ "process": p, "rpm": float(MS.MACHINES[p]["rpm_ref"]), "machine_kind": "humeda_lenta" })
		assert_eq(f["machine_kind"], "", "%s: sin variante" % p)
		assert_eq(float(f["rub"]["gain"]), 0.0, "%s: sin roce" % p)
		assert_eq(float(MS.voices(f)["rub"]["volume"]), 0.0, "%s: la voz del roce calla" % p)
	# Nivel: la esmeriladora (82 dB(A)) suena más que la lenta (59 dB(A))
	assert_true(float(bench["master_gain"]) > 2.0 * float(wet["master_gain"]), "esmeriladora más fuerte que la piedra lenta")


func test_afiladoras_amolado_sube_con_la_potencia_de_contacto() -> void:
	for mk in MS.SHARPENER_KINDS:
		var m := MS.machine_def("sharpener", mk)
		var pmax: float = m["pmax_kw"]
		var base := { "process": "sharpener", "machine_kind": mk, "rpm": float(m["rpm_ref"]), "pmax_kw": pmax }
		var idle := MS.frame(base)
		assert_eq(float(idle["noise"]["gain"]), 0.0, "%s: sin contacto no hay amolado" % mk)
		assert_eq(float(idle["crackle_rate"]), 0.0, "%s: ni chispas" % mk)
		var last := 0.0
		for i in range(1, 13):
			var d := base.duplicate()
			d["pc_kw"] = pmax * i / 10.0
			var f := MS.frame(d)
			var g: float = f["noise"]["gain"]
			assert_true(g > last, "%s: más potencia de contacto, más ruido de amolado (%s ≤ %s)" % [mk, g, last])
			last = g
			var fc: float = f["noise"]["fc_hz"]
			assert_true(fc >= MS.CUT_FC_MIN and fc <= MS.CUT_FC_MAX, "%s: banda dentro del ruido horneado (%s Hz)" % [mk, fc])
			if mk == "humeda_lenta":
				assert_eq(float(f["crackle_rate"]), 0.0, "en húmedo no hay chispas")
		assert_true(float(m["grind"]["sparks"]) >= 0.0 and str(m["source"]).length() > 20, "%s: ficha con fuente" % mk)
	# Chispas de la esmeriladora proporcionales a la carga
	var sp: float = MS.MACHINES["sharpener"]["grind"]["sparks"]
	var full: float = MS.frame({ "process": "sharpener", "rpm": 2950.0, "pc_kw": 0.37 })["crackle_rate"]
	var quarter: float = MS.frame({ "process": "sharpener", "rpm": 2950.0, "pc_kw": 0.0925 })["crackle_rate"]
	assert_near(full, sp, 1e-9, 0.0, "chispas a plena carga")
	assert_near(quarter, sp / 4.0, 1e-9, 0.0, "a un cuarto de carga, un cuarto de chispas")
	# La piedra lenta suena más grave y apagada que la esmeriladora
	var nb: Dictionary = MS.frame({ "process": "sharpener", "rpm": 2950.0, "pc_kw": 0.1 })["noise"]
	var nw: Dictionary = MS.frame({ "process": "sharpener", "machine_kind": "humeda_lenta", "rpm": 100.0, "pc_kw": 0.05 })["noise"]
	assert_true(float(nw["fc_hz"]) < float(nb["fc_hz"]) and float(nw["lp_hz"]) < float(nb["lp_hz"]), "húmeda: más grave y apagada")


func test_amoladora_sobre_pieza_maciza_sin_chapa() -> void:
	# Un hacha en el tornillo de banco no es una chapa que vibre: sheet_mm = 0 quita el «ring»
	var base := { "process": "grinder", "rpm": 11000.0, "pc_kw": 0.3, "disc_id": "laminas", "work_kind": "acero" }
	assert_true(_gain(MS.frame(base), "sheet_ring") > 0.0, "sobre chapa, la chapa canta")
	var solid := base.duplicate()
	solid["sheet_mm"] = 0.0
	var f := MS.frame(solid)
	assert_true(_tone(f, "sheet_ring").is_empty(), "pieza maciza: sin modos de chapa")
	assert_true(float(f["noise"]["gain"]) > 0.0 and float(f["crackle_rate"]) > 0.0, "pero sí amolado y chispas")


func test_combinada_trabajando_en_la_piedra_humeda() -> void:
	# Esmeriladora combinada (muela seca a 2980 rpm y piedra húmeda reducida a 134 rpm en el mismo motor): el motor
	# y el eje rápido suenan igual; la piedra añade su roce y, trabajando en ella, el amolado es el húmedo
	var dry := { "process": "sharpener", "machine_kind": "banco", "rpm": 2980.0, "pc_kw": 0.1 }
	var on_stone := dry.duplicate()
	on_stone["stone_rpm"] = 134.0
	on_stone["grind_kind"] = "humeda_lenta"
	on_stone["vc"] = PI * 200.0 * 134.0 / 1000.0  # la de la piedra de Ø200 (m/min)
	var fd := MS.frame(dry)
	var fw := MS.frame(on_stone)
	assert_eq(float(fd["rub"]["gain"]), 0.0, "sin piedra, sin roce")
	assert_true(float(fw["rub"]["gain"]) > 0.0, "la piedra reducida suena mojada")
	assert_near(float(fw["rub"]["pitch"]), 1.34 * float(fw["rpm"]) / 2980.0, 1e-12, 0.0, "late con la piedra (y con la caída del motor)")
	assert_near(_hz(fw, "spindle_1x"), float(fw["rpm"]) / 60.0, 1e-12, 0.0, "el eje rápido sigue a n/60")
	assert_near(_hz(fw, "motor_2f"), 100.0, 1e-12, 0.0, "y el motor zumba a 100 Hz")
	assert_eq(float(fw["crackle_rate"]), 0.0, "en la piedra húmeda no hay chispas")
	assert_true(float(fd["crackle_rate"]) > 0.0, "en la muela seca, sí")
	assert_true(float(fw["noise"]["fc_hz"]) < float(fd["noise"]["fc_hz"]), "el amolado húmedo es más grave")
	assert_true(float(fw["noise"]["gain"]) > 0.0, "pero se oye")
	# Parada: la piedra calla con el motor
	var stop := on_stone.duplicate()
	stop["rpm"] = 0.0
	stop["pc_kw"] = 0.0
	assert_eq(float(MS.frame(stop)["rub"]["gain"]), 0.0, "motor parado, piedra parada")
	# Un grind_kind desconocido se ignora
	var odd := dry.duplicate()
	odd["grind_kind"] = "tostadora"
	assert_true(same(MS.frame(odd), fd), "grind_kind desconocido → el de la máquina")


func test_caches_seguras_para_hilos() -> void:
	# Las cachés estáticas (tono clave de cada bucle y modo de la chapa) van con cerrojo: varios hilos a la vez,
	# con las cachés vacías, calculan exactamente lo mismo que uno solo.
	var inputs: Array = []
	for p in MS.PROCESSES:
		inputs.append({ "process": p, "rpm": float(MS.MACHINES[p]["rpm_ref"]), "pc_kw": 0.1, "coolant": true })
	for mk in MS.SHARPENER_KINDS:
		inputs.append({ "process": "sharpener", "machine_kind": mk, "rpm": float(MS.machine_def("sharpener", mk)["rpm_ref"]),
			"pc_kw": 0.05 })
	var loops: Array = MS.LOOPS.keys()
	var job := func(i: int) -> Variant:
		if i < loops.size():
			return MS.loop_ref_hz(loops[i])
		var fr := MS.frame(inputs[(i - loops.size()) % inputs.size()])
		return [fr, MS.voices(fr)]
	var n := loops.size() + 4 * inputs.size()
	MS.clear_caches()
	var seq: Array = []
	for i in n:
		seq.append(job.call(i))
	MS.clear_caches()
	var par: Array = []
	par.resize(n)
	var lock := Mutex.new()
	var task := func(i: int) -> void:
		var r: Variant = job.call(i)
		lock.lock()
		par[i] = r
		lock.unlock()
	var id := WorkerThreadPool.add_group_task(task, n, 8, true, "test de sonido")
	WorkerThreadPool.wait_for_group_task_completion(id)
	assert_eq(var_to_str(par), var_to_str(seq), "8 hilos con las cachés vacías = 1 hilo")
	assert_near(MS.sheet_key_hz(), MS.sheet_modes()[0][2], 0.0, 0.0, "la caché de la chapa, al bit")


# ── Bucles horneados ──


func test_bucles_dft_radial_fresa_y_garras() -> void:
	# [bucle, tono clave del marco de referencia, frecuencia esperada]
	var cases := [
		["spindle_grinder", "spindle_1x", 11000.0 / 60.0], ["teeth", "teeth_pass", 200.0], ["jaws", "jaws_pass", 60.0],
		["spindle_lathe", "gear_mesh", 940.0], ["segments", "segments_pass", 10.0 * 11000.0 / 60.0],
	]
	for c in cases:
		var id: String = c[0]
		var f: float = c[2]
		assert_near(_hz(MS.frame(MS.reference_input(id)), c[1]), f, 1e-12, 0.0, "%s: el marco de referencia da %s Hz" % [id, f])
		var x := _render(id)
		var pk := _dft_peak(x, f * 0.95, f * 1.05)
		assert_true(absf(pk[0] / f - 1.0) <= 0.02, "%s: pico DFT a %s Hz, esperado %s Hz ±2 %%" % [id, pk[0], f])
		var floor_amp := _dft_median(x, f * 0.7, f * 1.3, 24)
		assert_true(pk[1] > 10.0 * floor_amp, "%s: el pico destaca del fondo (%s frente a %s)" % [id, pk[1], floor_amp])
	# El bucle de la radial lleva también el rotor (3×); el del motor, el zumbido a 100 Hz
	var pk_rotor := _dft_peak(_render("spindle_grinder"), 520.0, 580.0)
	assert_true(absf(pk_rotor[0] / 550.0 - 1.0) <= 0.02, "rotor de la radial a 550 Hz: %s" % pk_rotor[0])
	var pk_motor := _dft_peak(_render("motor"), 90.0, 110.0)
	assert_true(absf(pk_motor[0] / 100.0 - 1.0) <= 0.02, "zumbido a 100 Hz: %s" % pk_motor[0])
	# Todos los bucles con tono: el pico está donde dice loop_ref_hz (la frecuencia con la que se calcula el
	# pitch_scale en tiempo real), no solo donde lo copiamos a mano
	for id in MS.LOOPS:
		var f := MS.loop_ref_hz(id)
		if f <= 0.0 or id == "sheet":
			continue
		var x := _render(id)
		var pk := _dft_peak(x, f * 0.95, f * 1.05)
		assert_true(absf(pk[0] / f - 1.0) <= 0.02, "%s: pico DFT a %s Hz, clave %s Hz" % [id, pk[0], f])
		assert_true(pk[1] > 10.0 * _dft_median(x, f * 0.7, f * 1.3, 24), "%s: el tono clave destaca" % id)


func test_bucles_de_las_afiladoras_dft() -> void:
	# Esmeriladora de banco a 2950 rpm: giro a 49,2 Hz, con su 2× y su 3×
	var bench := _render("spindle_sharpener")
	for k in [1.0, 2.0, 3.0]:
		var f: float = k * 2950.0 / 60.0
		var pk := _dft_peak(bench, f * 0.95, f * 1.05)
		assert_true(absf(pk[0] / f - 1.0) <= 0.02, "esmeriladora %s×: pico a %s Hz, esperado %s" % [k, pk[0], f])
		assert_true(pk[1] > 10.0 * _dft_median(bench, f * 0.7, f * 1.3, 24), "esmeriladora %s×: destaca" % k)
	assert_near(MS.loop_ref_hz("spindle_sharpener"), 2950.0 / 60.0, 1e-12, 0.0, "tono clave del bucle: 49,2 Hz")
	# Afiladoras compactas: 4400 rpm (73,3 Hz) y las delgas del colector (12 × n/60 = 880 Hz)
	var compact := _render("spindle_compact")
	for f in [4400.0 / 60.0, 880.0]:
		var pk := _dft_peak(compact, f * 0.95, f * 1.05)
		assert_true(absf(pk[0] / f - 1.0) <= 0.02, "compacta: pico a %s Hz, esperado %s" % [pk[0], f])
		assert_true(pk[1] > 10.0 * _dft_median(compact, f * 0.7, f * 1.3, 24), "compacta: %s Hz destaca" % f)
	# Piedra húmeda: ruido sin tono clave que late con el giro (100 rpm → 1,67 Hz, dos latidos en 1,2 s)
	assert_eq(MS.loop_ref_hz("stone_rub"), 0.0, "el roce no tiene tono clave")
	var rub := _render("stone_rub")
	var win := 441  # ventanas de 20 ms
	var env := PackedFloat32Array()
	for w in rub.size() / win:
		env.append(Dsp.rms(rub.slice(w * win, (w + 1) * win)))
	var mean := 0.0
	for v in env:
		mean += v
	mean /= env.size()
	for i in env.size():
		env[i] -= mean
	var beat := _goertzel(env, 2)  # 2 ciclos en el bucle = 1,67 Hz
	var others := 0.0
	for k in range(3, 12):
		others = maxf(others, _goertzel(env, k))
	assert_true(beat > 2.0 * others, "el roce late a 1,67 Hz: %s frente a %s" % [beat, others])
	assert_true(Dsp.rms(rub) > 0.1, "el roce suena (valor eficaz %s)" % Dsp.rms(rub))


func test_bucles_sin_clic_en_la_costura_ni_saturacion() -> void:
	for id in Bake.ids():
		var x := _render(id)
		var n := x.size()
		assert_true(Dsp.peak(x) < 0.95, "%s: pico %s (sin saturar)" % [id, Dsp.peak(x)])
		if id.begins_with("chip_"):
			assert_near(Dsp.peak(x), MS.CHIP_PEAK, 1e-6, 0.0, "%s: pico exacto" % id)
			continue
		var d := PackedFloat32Array()
		d.resize(n - 1)
		for i in n - 1:
			d[i] = absf(x[i + 1] - x[i])
		d.sort()
		var p999: float = d[int(0.999 * (n - 2))]
		var seam := absf(x[0] - x[n - 1])
		assert_true(seam <= p999, "%s: salto en la costura %s mayor que el 99,9 %% de los saltos (%s)" % [id, seam, p999])
		var info: Dictionary = MS.LOOPS[id]
		assert_eq(n, roundi(float(info["dur"]) * SR), "%s: duración" % id)
		if MS.loop_ref_hz(id) > 0.0 and id != "sheet":
			var cycles: float = MS.loop_ref_hz(id) * float(info["dur"])
			assert_near(cycles, roundf(cycles), 1e-9, 1e-9, "%s: ciclos enteros del tono clave" % id)


func test_hornear_dos_veces_da_los_mismos_bytes() -> void:
	for id in ["spindle_grinder", "sheet", "chip_2", "spindle_sharpener", "spindle_compact", "stone_rub"]:
		assert_eq(_sha256(Bake.wav_bytes(id)), _sha256(Bake.wav_bytes(id)), "%s: sha256 de dos horneados" % id)


func test_wav_del_repo_al_dia() -> void:
	for id in Bake.ids():
		var path := "res://assets/sfx/taller/%s.wav" % id
		assert_true(FileAccess.file_exists(path), "%s existe" % path)
		var disk := FileAccess.get_file_as_bytes(path)
		var mem := Dsp.encode_wav(_render(id), SR)
		assert_eq(_sha256(disk), _sha256(mem), "%s al día (vuelve a hornear con tools/bake_sounds.gd)" % id)


func test_bucles_importados_en_bucle_y_sin_comprimir() -> void:
	for id in Bake.ids():
		var s := load("res://assets/sfx/taller/%s.wav" % id) as AudioStreamWAV
		assert_true(s != null, "%s se importa como AudioStreamWAV" % id)
		if s == null:
			continue
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "%s: PCM de 16 bits" % id)
		assert_eq(s.mix_rate, SR, "%s: 22.050 Hz" % id)
		assert_false(s.stereo, "%s: mono" % id)
		if id.begins_with("chip_"):
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s: grano sin bucle" % id)
		else:
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s: bucle hacia delante" % id)
			assert_eq(s.loop_begin, 0, "%s: el bucle empieza en 0" % id)
			assert_eq(s.loop_end, s.data.size() / 2, "%s: el bucle acaba en la última muestra" % id)


func test_buses_de_la_maquina() -> void:
	var main := AudioServer.get_bus_index(&"Maquina")
	var cut := AudioServer.get_bus_index(&"MaquinaCorte")
	assert_true(main >= 0 and cut >= 0, "buses Maquina y MaquinaCorte")
	if main < 0 or cut < 0:
		return
	assert_eq(str(AudioServer.get_bus_send(cut)), "Maquina", "el corte va al bus de la máquina")
	assert_eq(str(AudioServer.get_bus_send(main)), "Master", "la máquina va al maestro (con su limitador)")
	var kinds := []
	for i in AudioServer.get_bus_effect_count(cut):
		kinds.append(AudioServer.get_bus_effect(cut, i).get_class())
	assert_eq(kinds, ["AudioEffectBandPassFilter", "AudioEffectLowPassFilter"], "filtros del corte")
	var bpf := AudioServer.get_bus_effect(cut, 0) as AudioEffectBandPassFilter
	assert_eq(bpf.db, AudioEffectFilter.FILTER_6DB, "una sola etapa: Q = 2·resonance")
	var amp := AudioServer.get_bus_effect(main, 0) as AudioEffectAmplify
	assert_true(amp != null, "el bus de la máquina recupera el margen de las voces")
	if amp != null:
		assert_near(amp.volume_db, MS.HEADROOM_DB, 1e-9, 0.0, "ganancia de recuperación = HEADROOM_DB")
	assert_near(MS.HEADROOM_GAIN, db_to_linear(-MS.HEADROOM_DB), 1e-9, 0.0, "HEADROOM_GAIN = 10^(−HEADROOM_DB/20)")


# ── Ayudas ──


func _tone(fr: Dictionary, name: String) -> Dictionary:
	for t in fr["tones"]:
		if t["name"] == name:
			return t
	return {}


func _hz(fr: Dictionary, name: String) -> float:
	var t := _tone(fr, name)
	if t.is_empty():
		fail("falta el tono %s" % name)
		return NAN
	return t["hz"]


func _gain(fr: Dictionary, name: String) -> float:
	var t := _tone(fr, name)
	return 0.0 if t.is_empty() else float(t["gain"])


func _layer_count(fr: Dictionary, layer: String) -> int:
	var n := 0
	for t in fr["tones"]:
		if t["layer"] == layer:
			n += 1
	return n


func _render(id: String) -> PackedFloat32Array:
	if not _renders.has(id):
		_renders[id] = Bake.render(id)
	return _renders[id]


static func _sha256(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


## Amplitud de la DFT de x en el bin k (Goertzel). Un tono de amplitud a con ciclos enteros da a.
static func _goertzel(x: PackedFloat32Array, k: int) -> float:
	var n := x.size()
	var coeff := 2.0 * cos(TAU * k / n)
	var s1 := 0.0
	var s2 := 0.0
	for v in x:
		var s0 := v + coeff * s1 - s2
		s2 = s1
		s1 = s0
	return 2.0 * sqrt(maxf(0.0, s1 * s1 + s2 * s2 - coeff * s1 * s2)) / n


## [frecuencia, amplitud] del bin más alto de la DFT entre f1 y f2 (resolución sr/N: 0,83 Hz en 1,2 s).
static func _dft_peak(x: PackedFloat32Array, f1: float, f2: float) -> Array:
	var n := x.size()
	var best := [0.0, -1.0]
	for k in range(maxi(1, floori(f1 * n / SR)), ceili(f2 * n / SR) + 1):
		var a := _goertzel(x, k)
		if a > best[1]:
			best = [float(k) * SR / n, a]
	return best


## Mediana de la amplitud de count bins repartidos entre f1 y f2 (fondo del espectro alrededor de un pico).
static func _dft_median(x: PackedFloat32Array, f1: float, f2: float, count: int) -> float:
	var n := x.size()
	var v := PackedFloat32Array()
	for i in count:
		v.append(_goertzel(x, roundi(lerpf(f1, f2, (i + 0.5) / count) * n / SR)))
	v.sort()
	return v[count / 2]


# ── Recetas de sfx.js portadas para el test del port ──


## renderSfx de sfx.js con las recetas portadas abajo.
func _render_sfx(id: String) -> PackedFloat32Array:
	var sr: int = Dsp.SFX_RATE
	var out := PackedFloat32Array()
	out.resize(ceili(1.1 * sr))
	var rng := Rng.new(Rng.seed_of("sfx:" + id))
	var dur: float = call("_sfx_" + id.replace("-", "_"), out, sr, rng)
	var levels := {  # LEVEL de sfx.js (0,8 si no está)
		"tap": 0.35, "on": 0.4, "off": 0.4, "badge": 0.6, "drip": 0.45, "slide": 0.35, "squeak": 0.5, "skin-rub": 0.5 }
	return Dsp.finish(out.slice(0, mini(out.size(), ceili((dur + 0.05) * sr))), levels.get(id, 0.8))


func _sfx_tap(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.tone(o, sr, { "dur": 0.03, "f": 2400.0, "env": func(t: float) -> float: return Dsp.decay(t, 0.006) })
	Dsp.noise_band(o, sr, rng, { "dur": 0.01, "fc": 5000.0, "q": 2.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.002), "gain": 0.4 })
	return 0.035


func _sfx_on(o: PackedFloat32Array, sr: int, _rng: Rng) -> float:
	Dsp.tone(o, sr, { "dur": 0.07, "f": 660.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.004, 0.04, 0.07) })
	Dsp.tone(o, sr, { "t0": 0.07, "dur": 0.1, "f": 990.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.004, 0.06, 0.1) })
	return 0.18


func _sfx_off(o: PackedFloat32Array, sr: int, _rng: Rng) -> float:
	Dsp.tone(o, sr, { "dur": 0.07, "f": 990.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.004, 0.04, 0.07) })
	Dsp.tone(o, sr, { "t0": 0.07, "dur": 0.1, "f": 560.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.004, 0.06, 0.1) })
	return 0.18


func _sfx_badge(o: PackedFloat32Array, sr: int, _rng: Rng) -> float:
	var notes := [1046.5, 1318.5, 1568.0, 2093.0]
	for i in notes.size():
		var f: float = notes[i]
		Dsp.modal(o, sr, { "t0": i * 0.085, "partials": [[f, 0.35, 1.0], [f * 2.76, 0.12, 0.25], [f * 5.4, 0.05, 0.12]],
			"gain": 0.8 })
	return 1.0


func _sfx_drip(o: PackedFloat32Array, sr: int, _rng: Rng) -> float:
	var starts := [0.0, 0.13]
	for i in starts.size():
		Dsp.tone(o, sr, { "t0": starts[i], "dur": 0.07, "f": func(t: float) -> float: return 1700 - i * 250 - 15000 * t,
			"env": func(t: float) -> float: return Dsp.decay(t, 0.02) })
	return 0.24


func _sfx_slide(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.9, "type": "hp", "fc": 2600.0, "q": 0.7,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.15, 0.4, 0.9), "gain": 0.5 })
	return 0.9


func _sfx_squeak(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.tone(o, sr, { "dur": 0.55, "f": func(t: float) -> float: return 950 + 380 * t + 35 * sin(TAU * 11 * t),
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.04, 0.2, 0.55), "shape": "tri", "gain": 0.6 })
	Dsp.noise_band(o, sr, rng, { "dur": 0.55, "fc": 3000.0, "q": 1.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.05, 0.2, 0.55), "gain": 0.25 })
	return 0.6



func _sfx_scratch_soft(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH,
		"fc": func(t: float) -> float: return 1500 + 500 * sin(TAU * 1.3 * t), "q": 1.1,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.05, 0.14, SCRATCH), "am": 0.45, "am_rate": 55.0 })
	Dsp.clicks(o, sr, rng, { "dur": SCRATCH, "rate": 18.0, "fc": 2500.0, "gain": 0.5 })
	return SCRATCH


func _sfx_scratch_deep(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH, "fc": 1100.0, "q": 0.7,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.04, 0.16, SCRATCH), "am": 0.7, "am_rate": 38.0 })
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH, "type": "lp", "fc": 260.0, "q": 0.8,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.05, 0.2, SCRATCH), "gain": 1.4 })
	Dsp.clicks(o, sr, rng, { "dur": SCRATCH, "rate": 55.0, "fc": 1800.0, "gain": 0.8 })
	return SCRATCH


func _sfx_scratch_wood(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH, "fc": 850.0, "q": 0.8,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.04, 0.15, SCRATCH), "am": 0.55, "am_rate": 30.0 })
	Dsp.clicks(o, sr, rng, { "dur": SCRATCH, "rate": 70.0,
		"fc": func(r: float) -> float: return 700 + r * 2200, "q": 3.0, "gain": 1.1, "len": 0.006 })
	return SCRATCH


func _sfx_scratch_metal(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH,
		"fc": func(t: float) -> float: return 3300 + 400 * sin(TAU * 2.1 * t), "q": 3.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.03, 0.15, SCRATCH), "am": 0.5, "am_rate": 70.0 })
	for k in 5:
		Dsp.modal(o, sr, { "t0": k * 0.21, "partials": [[2150.0, 0.09, 0.6], [3470.0, 0.07, 0.4], [5310.0, 0.05, 0.3]],
			"gain": 0.35 })
	return SCRATCH


func _sfx_scratch_glass(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": SCRATCH, "fc": 5200.0, "q": 2.5,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.03, 0.12, SCRATCH), "am": 0.6, "am_rate": 90.0, "gain": 0.8 })
	Dsp.clicks(o, sr, rng, { "dur": SCRATCH, "rate": 26.0,
		"fc": func(r: float) -> float: return 4000 + r * 4000, "q": 6.0, "gain": 1.2, "len": 0.002 })
	return SCRATCH


func _sfx_skin_rub(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.85, "type": "lp", "fc": 650.0, "q": 0.7,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.12, 0.3, 0.85), "am": 0.3, "am_rate": 20.0 })
	return 0.85


func _sfx_skin_cut(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.8, "type": "lp", "fc": 600.0, "q": 0.7,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.1, 0.3, 0.8), "gain": 0.6 })
	Dsp.noise_band(o, sr, rng, { "t0": 0.18, "dur": 0.32,
		"fc": func(t: float) -> float: return 700 + 6000 * t, "q": 2.0,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.02, 0.12, 0.32), "am": 0.5, "am_rate": 60.0 })
	return 0.8


func _sfx_press(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.tone(o, sr, { "dur": 0.12, "f": func(t: float) -> float: return 140 - 300 * t,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.03) })
	Dsp.noise_band(o, sr, rng, { "dur": 0.08, "type": "lp", "fc": 500.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.02), "gain": 0.5 })
	return 0.14


func _sfx_pierce(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.04, "fc": 2200.0, "q": 1.5,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.008) })
	Dsp.tone(o, sr, { "t0": 0.01, "dur": 0.14, "f": func(t: float) -> float: return 190 - 700 * t,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.035), "gain": 0.9 })
	return 0.17


func _sfx_inject(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	_sfx_pierce(o, sr, rng)
	Dsp.noise_band(o, sr, rng, { "t0": 0.12, "dur": 0.45, "type": "hp", "fc": 4200.0, "q": 0.8,
		"env": func(t: float) -> float: return Dsp.env_ar(t, 0.03, 0.25, 0.45), "gain": 0.45 })
	Dsp.tone(o, sr, { "t0": 0.52, "dur": 0.07, "f": func(t: float) -> float: return 1500 - 12000 * t,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.02), "gain": 0.5 })
	return 0.62


func _sfx_pierce_solid(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.modal(o, sr, { "partials": [[180.0, 0.05, 1.0], [410.0, 0.03, 0.6], [930.0, 0.015, 0.3]] })
	Dsp.noise_band(o, sr, rng, { "dur": 0.1, "fc": 1500.0, "q": 1.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.025), "gain": 0.8 })
	Dsp.clicks(o, sr, rng, { "t0": 0.02, "dur": 0.12, "rate": 60.0, "fc": 1800.0, "gain": 0.5 })
	return 0.25


func _sfx_pierce_brittle(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.012, "type": "hp", "fc": 2000.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.003), "gain": 1.2 })
	Dsp.modal(o, sr, { "partials": [[4200.0, 0.05, 0.7], [6800.0, 0.035, 0.5], [9100.0, 0.02, 0.35]], "gain": 0.7 })
	Dsp.clicks(o, sr, rng, { "t0": 0.02, "dur": 0.25, "rate": 30.0,
		"fc": func(r: float) -> float: return 5000 + r * 3000, "q": 8.0, "gain": 0.8, "len": 0.0015 })
	return 0.35


func _sfx_breakthrough(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.3, "fc": 900.0, "q": 0.6,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.09), "gain": 1.3 })
	Dsp.tone(o, sr, { "dur": 0.35, "f": func(t: float) -> float: return 95 - 90 * t,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.1), "gain": 1.4 })
	Dsp.clicks(o, sr, rng, { "dur": 0.9, "rate": 70.0,
		"fc": func(r: float) -> float: return 600 + r * 2600, "q": 3.0, "gain": 0.9, "len": 0.006 })
	return 1.0


func _sfx_shatter(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.02, "type": "hp", "fc": 2500.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.004), "gain": 1.4 })
	Dsp.noise_band(o, sr, rng, { "dur": 0.35, "fc": 3200.0, "q": 0.7,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.08), "gain": 0.9 })
	Dsp.modal(o, sr, { "partials": [[3100.0, 0.08, 0.6], [5200.0, 0.06, 0.45], [7400.0, 0.04, 0.3]], "gain": 0.6 })
	Dsp.clicks(o, sr, rng, { "t0": 0.08, "dur": 0.9, "rate": 50.0,
		"fc": func(r: float) -> float: return 3500 + r * 5000, "q": 6.0, "gain": 0.8, "len": 0.012 })
	return 1.0


func _sfx_snap(o: PackedFloat32Array, sr: int, rng: Rng) -> float:
	Dsp.noise_band(o, sr, rng, { "dur": 0.01, "type": "hp", "fc": 1500.0,
		"env": func(t: float) -> float: return Dsp.decay(t, 0.002), "gain": 1.4 })
	Dsp.modal(o, sr, { "partials": [[2600.0, 0.03, 0.8], [5600.0, 0.018, 0.5], [1300.0, 0.05, 0.4]] })
	Dsp.clicks(o, sr, rng, { "t0": 0.05, "dur": 0.18, "rate": 25.0, "fc": 3000.0, "q": 4.0, "gain": 0.6, "len": 0.002 })
	return 0.3
