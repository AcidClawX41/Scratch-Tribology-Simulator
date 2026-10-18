## Hornea los bucles de sonido del taller en assets/sfx/taller/ (WAV PCM de 16 bits, mono, 22.050 Hz).
##
## Cada bucle sale de las tablas de core/taller/machine_sound.gd (frecuencias y proporciones del marco en la
## entrada de referencia de ese bucle) y de los bloques de core/shared/dsp.gd. Es determinista: el azar sale de
## rng.gd con una semilla por bucle, así que hornear dos veces da los mismos bytes.
## Costura sin clic: los tonos tienen un número entero de ciclos en la duración del bucle (se calculan sin
## acumular fase) y el ruido se funde sobre el principio (Dsp.loop_crossfade).
## Uso, desde la raíz del repositorio:
##   node godot/tools/godot.mjs run --headless --script res://tools/bake_sounds.gd            escribe los WAV
##   node godot/tools/godot.mjs run --headless --script res://tools/bake_sounds.gd -- --check   solo comprueba
## Después, `npm run godot:import` (o godot:test) los reimporta. El horneado deja cada .import con bucle hacia
## delante, PCM sin comprimir y edit/loop_end igual al número de muestras (si el .import ya existe, solo cambia
## esos parámetros y conserva su uid). Ojo: en Godot 4.7.2, edit/loop_end = −1 se importa como N − 1 y la
## reproducción trata loop_end como exclusivo: se perdería la última muestra en cada vuelta (medido con Movie
## Maker: salto de fase de 16° a 1 kHz cada 1,2 s).
extends SceneTree

const Dsp = preload("res://core/shared/dsp.gd")
const Rng = preload("res://core/shared/rng.gd")
const MachineSound = preload("res://core/taller/machine_sound.gd")

const OUT_DIR := "res://assets/sfx/taller"
const SR := MachineSound.SAMPLE_RATE
const XFADE_S := 0.15  # s de fundido en la costura del ruido
const CHIP_S := 0.08  # s de cada grano de viruta


func _init() -> void:
	# godot.mjs run no reenvía el separador «--»: --check puede llegar como argumento de usuario o del motor
	var check := OS.get_cmdline_user_args().has("--check") or OS.get_cmdline_args().has("--check")
	var stale: Array[String] = []
	if not check:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id in ids():
		var bytes := wav_bytes(id)
		var path := OUT_DIR.path_join(id + ".wav")
		if check:
			if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path) != bytes:
				stale.append(id)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		_ensure_import(path + ".import", (bytes.size() - 44) / 2, not id.begins_with("chip_"))
	if check:
		if stale.is_empty():
			print("Bucles del taller al día (%d archivos)." % ids().size())
		else:
			print("Bucles del taller desactualizados: %s. Vuelve a hornear con tools/bake_sounds.gd."
				% ", ".join(stale))
	else:
		print("%d archivos horneados en %s." % [ids().size(), OUT_DIR])
	quit(1 if not stale.is_empty() else 0)


## Todos los archivos que hornea: los bucles de MachineSound.LOOPS y los granos de viruta.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for k in MachineSound.LOOPS:
		out.append(str(k))
	for i in MachineSound.CHIP_GRAINS:
		out.append("chip_%d" % i)
	return out


## Bytes del WAV de un bucle o grano.
static func wav_bytes(id: String) -> PackedByteArray:
	return Dsp.encode_wav(render(id), SR)


## Muestras de un bucle o grano, en [−1, 1].
static func render(id: String) -> PackedFloat32Array:
	if id.begins_with("chip_"):
		return _chip(int(id.substr(5)))
	if id.begins_with("spindle_"):
		return _spindle(id)
	match id:
		"motor":
			return _motor()
		"jaws", "teeth", "segments":
			return _pass(id)
		"cut":
			return _cut()
		"sheet":
			return _sheet()
		"chatter":
			return _chatter()
		"coolant":
			return _coolant()
		"crackle":
			return _crackle()
		"stone_rub":
			return _stone_rub()
	push_error("bucle desconocido: %s" % id)
	return PackedFloat32Array()


# ── Recetas ──


## Zumbido del motor de inducción: 2·f de red y múltiplos pares, y un soplo de ventilador.
static func _motor() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["motor"]
	var rng := Rng.from_text("taller:motor")
	var n := _len(info)
	var out := _zeros(n)
	var parts: Array = []
	for h in MachineSound.MOTOR_HUM:
		parts.append([float(h[1]) * MachineSound.MAINS_HZ, float(info["level"]) * float(h[2]), rng.next() * TAU])
	Dsp.partials(out, SR, parts)
	var fan := Dsp.pink(n + _xf(), rng)
	Dsp.filter_all(fan, "hp", 150.0, 0.7, SR)
	Dsp.filter_all(fan, "lp", 1500.0, 0.7, SR)
	Dsp.mix_into(out, _seam(fan, n, 0.08 * float(info["level"])))
	return out


## Husillo: los tonos de la capa «spindle» del marco de referencia y un ruido mecánico modulado a 1×. En los
## motores de escobillas (la radial y las afiladoras compactas de continua) el ruido es más agudo: el de las
## escobillas sobre el colector.
static func _spindle(id: String) -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS[id]
	var rng := Rng.from_text("taller:" + id)
	var n := _len(info)
	var out := _zeros(n)
	var tones := _layer_tones(MachineSound.frame(MachineSound.reference_input(id)), "spindle")
	var key_gain: float = tones[0]["gain"]
	var parts: Array = []
	for t in tones:
		parts.append([float(t["hz"]), float(info["level"]) * float(t["gain"]) / key_gain, rng.next() * TAU])
	Dsp.partials(out, SR, parts)
	# Rodamientos y aire: ruido de banda ancha que late una vez por vuelta (periódico: empalma igual)
	var f_rot: float = tones[0]["hz"]
	var grinder := id == "spindle_grinder" or id == "spindle_compact"
	var nz := Dsp.pink(n + _xf(), rng)
	Dsp.filter_all(nz, "hp", 1500.0 if grinder else 400.0, 0.7, SR)
	Dsp.filter_all(nz, "lp", 9000.0 if grinder else 4000.0, 0.7, SR)
	var mod := PackedFloat32Array()
	mod.resize(nz.size())
	for i in nz.size():
		mod[i] = 1.0 + 0.3 * sin(TAU * f_rot * i / SR)
	for i in nz.size():
		nz[i] *= mod[i]
	Dsp.mix_into(out, _seam(nz, n, (0.35 if grinder else 0.12) * float(info["level"])))
	return out


## Paso de garras (aire batido), dientes (impactos) o segmentos del disco de diamante. El bucle cambia de tono
## con el paso y no lleva resonancias fijas que se transpongan con él: las garras son aire (su espectro escala
## con la velocidad, como el bucle); dientes y segmentos, un tren de impulsos armónico y ruido de banda ancha.
## El timbre del material lo pone la banda del corte, que no se transpone.
static func _pass(id: String) -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS[id]
	var rng := Rng.from_text("taller:" + id)
	var n := _len(info)
	var out := _zeros(n)
	var f0: float = _layer_tones(MachineSound.frame(MachineSound.reference_input(id)), "pass")[0]["hz"]
	var level: float = info["level"]
	var parts: Array = []
	if id == "jaws":
		# Soplo que se repite con cada garra: armónicos suaves con fases fijas
		for k in range(1, 13):
			parts.append([f0 * k, level / pow(k, 1.2), rng.next() * TAU])
	else:
		# Impactos: tren de pulsos en coseno (todas las fases alineadas, un golpe por paso)
		var kmax := 16 if id == "teeth" else 5
		for k in range(1, kmax + 1):
			parts.append([f0 * k, level / k, PI / 2.0])
	Dsp.partials(out, SR, parts)
	# Ruido que sopla o cruje con cada paso (envolvente periódica)
	var nz := Dsp.pink(n + _xf(), rng)
	if id == "jaws":
		Dsp.filter_all(nz, "bp", 700.0, 0.8, SR)  # soplo de las garras a 1200 rpm
	else:
		Dsp.filter_all(nz, "hp", 200.0, 0.7, SR)  # chasquido de banda ancha
		Dsp.filter_all(nz, "lp", 9000.0, 0.7, SR)
	for i in nz.size():
		var ph := fmod(f0 * i / SR, 1.0)
		nz[i] *= (0.5 - 0.5 * cos(TAU * ph)) if id == "jaws" else exp(-ph * 6.0)
	Dsp.mix_into(out, _seam(nz, n, (0.3 if id == "jaws" else 0.15) * level))
	return out


## Corte: ruido rosa de banda [band_lo, band_hi] con la modulación «stick-slip» de sfx.js, suavizada. La banda
## la recorta en tiempo real el bus «MaquinaCorte».
static func _cut() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["cut"]
	var rng := Rng.from_text("taller:cut")
	var n := _len(info)
	var nz := Dsp.pink(n + _xf(), rng)
	Dsp.filter_all(nz, "hp", float(info["band_lo"]), 0.7, SR)
	Dsp.filter_all(nz, "lp", float(info["band_hi"]), 0.7, SR)
	_stick_slip(nz, rng, 45.0, 0.3)
	return _seam(nz, n, float(info["level"]))


## Chapa que vibra: los modos impar-impar del panel de referencia, cada uno un resonador de Q = 1/η, excitados
## por los impactos de los granos del disco (unos 1500 por segundo, de amplitud y signo aleatorios: se solapan
## y la chapa canta en continuo, con un factor de cresta moderado).
static func _sheet() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["sheet"]
	var rng := Rng.from_text("taller:sheet")
	var n := _len(info)
	var total := n + _xf()
	var hits := _zeros(total)
	var p := 1500.0 / SR
	for i in total:
		if rng.next() < p:
			hits[i] = (0.3 + 0.7 * rng.next()) * (1.0 if rng.next() < 0.5 else -1.0)
	var modes := MachineSound.sheet_modes()
	var f_key: float = modes[0][2]
	var eta: float = MachineSound.SHEET[MachineSound.SHEET_REF["kind"]]["eta"]
	var ring := _zeros(total)
	for md in modes:
		var f: float = md[2]
		var b := Dsp.biquad("bp", 1.0 / eta, float(SR), f)
		var w := sqrt(f_key / f)
		for i in total:
			ring[i] += b.run(hits[i]) * w
	return _seam(ring, n, float(info["level"]))


## Chatter: un tono con dos armónicos y un leve vaivén de 5 Hz (periódico en el bucle).
static func _chatter() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["chatter"]
	var rng := Rng.from_text("taller:chatter")
	var n := _len(info)
	var out := _zeros(n)
	var f: float = info["ref_hz"]
	var level: float = info["level"]
	var mod := PackedFloat32Array()
	mod.resize(n)
	for i in n:
		mod[i] = 1.0 + 0.1 * sin(TAU * 5.0 * i / SR)
	var parts := [
		[f, level, rng.next() * TAU], [2.0 * f, 0.3 * level, rng.next() * TAU], [3.0 * f, 0.1 * level, rng.next() * TAU],
	]
	Dsp.partials(out, SR, parts, 0, n, mod)
	return out


## Refrigerante: bomba (giro y paso de álabes), chorro que salpica y gotas.
static func _coolant() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["coolant"]
	var rng := Rng.from_text("taller:coolant")
	var n := _len(info)
	var out := _zeros(n)
	var level: float = info["level"]
	var parts: Array = []
	for c in MachineSound.COOLANT:
		parts.append([float(c[1]) * MachineSound.COOLANT_PUMP_HZ, level * float(c[2]), rng.next() * TAU])
	Dsp.partials(out, SR, parts)
	var nz := Dsp.pink(n + _xf(), rng)
	Dsp.filter_all(nz, "bp", 3000.0, 0.7, SR)
	_stick_slip(nz, rng, 25.0, 0.5)
	var drops := _zeros(nz.size())
	Dsp.clicks(drops, SR, rng, { "dur": float(nz.size()) / SR, "rate": 25.0, "q": 4.0, "gain": 1.0, "len": 0.003,
		"fc": func(r: float) -> float: return 1500.0 + r * 3000.0 })
	# Cada gota llega a 2,5 veces el valor eficaz del chorro
	Dsp.mix_into(nz, drops, 2.5 * Dsp.rms(nz) / maxf(Dsp.peak(drops), 1e-9))
	Dsp.mix_into(out, _seam(nz, n, 0.5 * level))
	return out


## Roce de la piedra húmeda (afiladora lenta, a las rpm de referencia): un siseo suave de 250 Hz a 3 kHz que late
## una vez por vuelta (la piedra no es perfectamente redonda ni lisa: 1,67 Hz a 100 rpm, dos vueltas en el bucle),
## el chapoteo grave del agua en la bandeja (una ola por bucle) y gotas que caen. Sin tono clave: el reproductor
## lo mueve con pitch_scale = rpm/rpm_ref. Receta de dibujo sonoro (estimación), sin medición publicada.
static func _stone_rub() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["stone_rub"]
	var rng := Rng.from_text("taller:stone_rub")
	var n := _len(info)
	var total := n + _xf()
	var turn: float = info["turn_hz"]
	var hiss := Dsp.pink(total, rng)
	Dsp.filter_all(hiss, "hp", 250.0, 0.7, SR)
	Dsp.filter_all(hiss, "lp", 3000.0, 0.7, SR)
	for i in total:
		hiss[i] *= 1.0 + 0.35 * sin(TAU * turn * i / SR)
	var slosh := Dsp.pink(total, rng)
	Dsp.filter_all(slosh, "hp", 60.0, 0.7, SR)
	Dsp.filter_all(slosh, "lp", 350.0, 0.7, SR)
	for i in total:
		slosh[i] *= 0.6 + 0.4 * sin(TAU * turn * 0.5 * i / SR + 1.3)
	var drops := _zeros(total)
	Dsp.clicks(drops, SR, rng, { "dur": float(total) / SR, "rate": 7.0, "q": 6.0, "gain": 1.0, "len": 0.004,
		"fc": func(r: float) -> float: return 1400.0 + r * 2200.0 })
	Dsp.mix_into(hiss, slosh, 0.8 * Dsp.rms(hiss) / maxf(Dsp.rms(slosh), 1e-9))
	Dsp.mix_into(hiss, drops, 1.5 * Dsp.rms(hiss) / maxf(Dsp.peak(drops), 1e-9))
	return _seam(hiss, n, float(info["level"]))


## Crujido denso: chasquidos cortos a 200 por segundo (para cuando la viruta o las chispas son muchas).
static func _crackle() -> PackedFloat32Array:
	var info: Dictionary = MachineSound.LOOPS["crackle"]
	var rng := Rng.from_text("taller:crackle")
	var n := _len(info)
	var total := n + _xf()
	var buf := _zeros(total)
	Dsp.clicks(buf, SR, rng, { "dur": float(total) / SR, "rate": float(info["rate"]), "q": 3.0, "gain": 1.0, "len": 0.002,
		"fc": func(r: float) -> float: return 2000.0 + r * 5000.0 })
	return _seam(buf, n, float(info["level"]))


## Grano de viruta: una ráfaga corta de ruido y el tintineo de la viruta al chocar (sin bucle). Empieza a los
## 3 ms, después del fundido de entrada de finish(), y se escala a un pico exacto de CHIP_PEAK.
static func _chip(i: int) -> PackedFloat32Array:
	var rng := Rng.from_text("taller:chip:%d" % i)
	var out := _zeros(roundi(CHIP_S * SR))
	Dsp.clicks(out, SR, rng, { "t0": 0.003, "dur": 0.004, "rate": 250.0 + 250.0 * i, "q": 2.0, "gain": 1.0,
		"len": 0.004 + 0.002 * i, "fc": func(r: float) -> float: return 2500.0 + r * 3000.0 })
	var f := 3100.0 + 700.0 * i
	Dsp.modal(out, SR, { "t0": 0.003, "partials": [[f, 0.008, 0.5], [f * 1.63, 0.005, 0.3]], "gain": 0.6 })
	Dsp.finish(out, MachineSound.CHIP_PEAK)
	Dsp.scale(out, MachineSound.CHIP_PEAK / maxf(Dsp.peak(out), 1e-9))
	return out


# ── Utilidades ──


static func _len(info: Dictionary) -> int:
	return roundi(float(info["dur"]) * SR)


static func _xf() -> int:
	return roundi(XFADE_S * SR)


static func _zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


## Tonos de una capa del marco, en orden (el primero es el clave).
static func _layer_tones(fr: Dictionary, layer: String) -> Array:
	var out: Array = []
	for t in fr["tones"]:
		if t["layer"] == layer:
			out.append(t)
	return out


## Funde la cola de un ruido de n + x muestras sobre su principio y lo escala a un valor eficaz dado.
static func _seam(buf: PackedFloat32Array, n: int, target_rms: float) -> PackedFloat32Array:
	var out := Dsp.loop_crossfade(buf, n)
	Dsp.scale(out, target_rms / maxf(Dsp.rms(out), 1e-12))
	return out


## Modulación «stick-slip» (como la de noise_band en sfx.js) pero interpolada, para que el bucle no chasquee:
## cada 1/rate s un nuevo nivel aleatorio 1 − am + am·r·1,6.
static func _stick_slip(buf: PackedFloat32Array, rng: Rng, rate: float, am: float) -> void:
	var step := float(SR) / rate
	var a := 1.0
	var b := 1.0 - am + am * rng.next() * 1.6
	var pos := 0.0
	for i in buf.size():
		if pos >= step:
			pos -= step
			a = b
			b = 1.0 - am + am * rng.next() * 1.6
		buf[i] *= a + (b - a) * (pos / step)
		pos += 1.0


## Deja el .import de un WAV con los parámetros del taller: PCM sin comprimir y, si es bucle, hacia delante de
## la muestra 0 a la frames (exclusiva). Si no existe, escribe uno mínimo y Godot completa uid y rutas al importar.
static func _ensure_import(path: String, frames: int, looped: bool) -> void:
	var params := {
		"edit/loop_mode": str(2 if looped else 1), "edit/loop_begin": "0",
		"edit/loop_end": str(frames if looped else -1),
		"compress/mode": "0",
	}
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	else:
		text = "[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[params]\n\n"
		text += "force/8_bit=false\nforce/mono=false\n"
		text += "force/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\n"
		text += "edit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n"
	var lines := text.split("\n")
	for i in lines.size():
		var eq := lines[i].find("=")
		if eq > 0 and params.has(lines[i].substr(0, eq)):
			lines[i] = "%s=%s" % [lines[i].substr(0, eq), params[lines[i].substr(0, eq)]]
	var out := "\n".join(lines)
	if out != text or not FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(out)
		f.close()
