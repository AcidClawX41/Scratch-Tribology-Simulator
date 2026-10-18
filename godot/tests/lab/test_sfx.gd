## Sonidos del laboratorio (core/lab/sfx.gd) contra el oráculo del motor 1.x: el efecto de cada resultado en los
## 40 escenarios del golden y en toda la muestra del barrido, y los 22 WAV idénticos a los de la 1.x.
##
## lab-golden.json y lab-sample.json guardan los números como decimales, y el lector de Godot no redondea bien los
## largos: "110.00000000000001" (una garra que se queda justo al llegar a la chapa) lo lee como 110, y entonces
## `depthUm > 110` cambia de respuesta y de sonido. Por eso, antes de interpretar el JSON, los depthUm y sev que
## caen junto a un umbral de sfx_for_result (1 y 110 µm; 0,6) se sustituyen por su double exacto.
extends "res://tests/case.gd"

const Sfx = preload("res://core/lab/sfx.gd")
const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const SfxCare = preload("res://core/lab/sfx_care.gd")
const SfxForge = preload("res://core/lab/sfx_forge.gd")
const SfxReaction = preload("res://core/lab/sfx_reaction.gd")

## Umbrales de sfx_for_result por campo.
const _THRESHOLDS := { "depthUm": [1.0, 110.0], "sev": [0.6] }

var data: Dictionary
var targets := {}


func before_each() -> void:
	if data.is_empty():
		data = load_json("res://tests/fixtures/lab-data.json")
		for t: Dictionary in data["TARGETS"]:
			targets[t["id"]] = t


## El double exacto que JavaScript escribió como `text` (String(n)): el vecino del valor aproximado de Godot cuyo
## String(n) es ese mismo texto. El lector de Godot se equivoca como mucho en unos pocos ulp.
static func exact_float(text: String) -> float:
	var approx := text.to_float()
	for k in 9:
		var step := int((k + 1) / 2.0) * (1 if k % 2 else -1)  # 0, +1, −1, +2, −2…
		var x := _ulp_step(approx, step)
		if _Js.js_num_str(x) == text:
			return x
	return approx


static func _ulp_step(x: float, n: int) -> float:
	if n == 0 or x == 0.0:
		return x
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, absf(x))
	b.encode_s64(0, b.decode_s64(0) + n)
	return b.decode_double(0) * signf(x)


## El texto JSON con los depthUm y sev junto a un umbral cambiados por { "$f64": … } (el double exacto).
static func exact_near_thresholds(text: String) -> String:
	var re := RegEx.create_from_string("\"(depthUm|sev)\":(-?[0-9][0-9.eE+-]*)")
	var out := PackedStringArray()
	var pos := 0
	for m: RegExMatch in re.search_all(text):
		var num := m.get_string(2)
		var v := num.to_float()
		var near := false
		for th: float in _THRESHOLDS[m.get_string(1)]:
			near = near or absf(v - th) <= 1e-9 * th
		if not near:
			continue
		var b := PackedByteArray()
		b.resize(8)
		b.encode_double(0, exact_float(num))
		out.append(text.substr(pos, m.get_start(2) - pos))
		out.append("{\"$f64\":\"%s\"}" % b.hex_encode())
		pos = m.get_end(2)
	out.append(text.substr(pos))
	return "".join(out)


func test_lectura_exacta_de_los_decimales_largos() -> void:
	assert_eq("110.00000000000001".to_float(), 110.0, "el lector de Godot (si esto cambia, el arreglo sobra)")
	assert_true(exact_float("110.00000000000001") > 110.0, "110.00000000000001 > 110")
	assert_eq(exact_float("110"), 110.0)
	assert_eq(_Js.js_num_str(exact_float("0.6000000000000001")), "0.6000000000000001")
	assert_eq(_Js.js_num_str(exact_float("1.0000000000000002")), "1.0000000000000002")
	var fixed: Dictionary = decode(JSON.parse_string(exact_near_thresholds("{\"depthUm\":110.00000000000001,\"sev\":0.3,\"x\":110.00000000000001}")))
	assert_true(fixed["depthUm"] > 110.0 and fixed["sev"] == 0.3 and fixed["x"] == 110.0, "solo los campos junto a un umbral")


func test_ids_y_frecuencia_de_sfx_js() -> void:
	var fx: Dictionary = load_json("res://tests/fixtures/sfx.json")
	assert_eq(Sfx.SFX_IDS, fx["ids"], "SFX_IDS en el orden de sfx.js")
	assert_eq(Sfx.SFX_IDS, data["SFX_IDS"], "SFX_IDS de lab-data.json")
	assert_eq(Sfx.SFX_RATE, int(fx["rate"]), "frecuencia de muestreo")
	assert_eq(Sfx.path_of("tap"), "res://assets/sfx/lab/tap.wav")


func test_golden_suena_igual() -> void:
	var golden: Array = decode(JSON.parse_string(exact_near_thresholds(FileAccess.get_file_as_string("res://tests/fixtures/lab-golden.json"))))
	assert_eq(golden.size(), 40, "escenarios del golden")
	var seen := {}
	for g: Dictionary in golden:
		var got := Sfx.sfx_for_result(g["result"], targets[g["params"]["target"]])
		assert_eq(got, g["sfx"], "«%s»" % g["name"])
		seen[got] = true
	print("    (info) el golden hace sonar %d efectos distintos" % seen.size())


func test_muestra_del_barrido_suena_igual() -> void:
	# lab-sample.json es grande: se lee sin decodificar entero y solo se decodifica el resultado de cada ensayo
	var text := FileAccess.get_file_as_string("res://tests/fixtures/generated/lab-sample.json")
	assert_true(text != "", "falta generated/lab-sample.json (npm run godot:fixtures)")
	var sample: Dictionary = JSON.parse_string(exact_near_thresholds(text))
	var trials: Array = sample["trials"]
	var bad := 0
	var count := {}
	for t: Dictionary in trials:
		var res: Dictionary = decode(t["result"])
		var want: String = t["sfx"]
		var got := Sfx.sfx_for_result(res, targets[t["params"]["target"]])
		count[want] = int(count.get(want, 0)) + 1
		if got != want:
			bad += 1
			if bad <= 8:
				fail("%s contra %s (%s): «%s», el oráculo «%s»" % [
					t["params"]["claw"] if t["params"]["claw"] != null else t["params"]["base"], t["params"]["target"],
					t["params"]["method"], got, want])
	assert_true(trials.size() > 19000, "ensayos de la muestra: %d" % trials.size())
	assert_eq(bad, 0, "ensayos cuyo sonido no coincide con el del oráculo")
	# todos los sonidos de resultado aparecen en la muestra (los de interfaz no dependen de un ensayo)
	for id in ["slide", "squeak", "scratch-soft", "scratch-deep", "scratch-wood", "scratch-metal", "scratch-glass",
			"skin-rub", "skin-cut", "press", "pierce", "inject", "pierce-solid", "pierce-brittle", "breakthrough", "shatter", "snap"]:
		assert_true(count.has(id), "la muestra cubre «%s»" % id)
	print("    (info) %d ensayos de la muestra, %d sonidos distintos, 0 discrepancias" % [trials.size(), count.size()])


func test_wav_identicos_a_los_de_la_1x() -> void:
	var fx: Dictionary = load_json("res://tests/fixtures/sfx.json")
	var sha: Dictionary = fx["sha256"]
	assert_eq(sha.size(), Sfx.SFX_IDS.size(), "un WAV por efecto")
	for id: String in Sfx.SFX_IDS:
		var path := Sfx.path_of(id)
		assert_true(FileAccess.file_exists(path), "existe %s" % path)
		assert_eq(FileAccess.get_sha256(path), sha.get(id, ""), "sha256 de %s.wav" % id)
	# en la carpeta están también los de la 2.0 (core/lab/sfx_insects.gd, los bucles de la cetrería, core/lab/sfx_care.gd, y
	# los de la reforja, core/lab/sfx_forge.gd, que comprueban test_sfx_insects.gd, test_sfx_care.gd y test_sfx_forge.gd):
	# nada más
	var wavs := Array(DirAccess.get_files_at(Sfx.SFX_DIR)).filter(func(f: String) -> bool: return f.ends_with(".wav"))
	var known: Array = Sfx.SFX_IDS.duplicate()
	known.append_array(SfxInsects.ids())
	known.append_array(SfxCare.ids())
	known.append_array(SfxForge.ids())
	# y los de la reacción del animal y de la lente (5t-B, core/lab/sfx_reaction.gd: test_sfx_reaction.gd)
	known.append_array(SfxReaction.ids())
	assert_eq(wavs.size(), known.size(), "no sobran WAV en %s" % Sfx.SFX_DIR)
	for f: String in wavs:
		assert_true(known.has(f.get_basename()), "%s es de la 1.x o de la 2.0" % f)
	# cabecera: PCM de 16 bits, mono, a SFX_RATE
	var head := FileAccess.get_file_as_bytes(Sfx.path_of("tap")).slice(0, 44)
	assert_eq(head.slice(0, 4).get_string_from_ascii(), "RIFF")
	assert_eq(head.decode_u16(20), 1, "PCM")
	assert_eq(head.decode_u16(22), 1, "mono")
	assert_eq(head.decode_u32(24), Sfx.SFX_RATE, "frecuencia")
	assert_eq(head.decode_u16(34), 16, "bits por muestra")
