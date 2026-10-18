## Hornea los sonidos del laboratorio que añade la 2.0 (core/lab/sfx_insects.gd: el zumbido de cada insecto, el
## picotazo, el desgarro del aguijón y el pandeo; core/lab/sfx_care.gd: el motor del torno de uñas, el roce de la lima,
## el motor de la amoladora y el arranque y la parada de la cetrería; core/lab/sfx_forge.gd: la muela, el horno, la llama, la
## bobina de inducción, la prensa, la colada y el temple de la reforja) en assets/sfx/lab/, junto a los 22 WAV de la 1.x
## (que no se tocan): WAV PCM de 16 bits, mono, 22.050 Hz.
##
## Determinista: hornear dos veces da los mismos bytes (tests/lab/test_sfx_insects.gd, test_sfx_care.gd y test_sfx_forge.gd comprueban que
## los del repositorio están al día). El .import de cada WAV queda como el de los efectos de la 1.x (una vez, comprimido) o, en los
## zumbidos, en bucle hacia delante de la muestra 0 a la última del bucle (edit/loop_end = número de muestras del bucle: con
## −1, Godot 4.7.2 pierde la última muestra en cada vuelta, lo midió la unidad del sonido del taller) y sin comprimir, para
## que la costura no salte. Detrás del bucle va su cola (Sfx.LOOP_TAIL muestras de su principio), que solo lee la
## interpolación al dar la vuelta: sin ella, cada vuelta daba un chasquido (docs/fase2/qa-sonido.md). Si el .import ya existe, solo cambian esos parámetros y se conserva su uid.
## Uso, desde la raíz del repositorio:
##   node godot/tools/godot.mjs run --headless --script res://tools/bake_lab_extra.gd            escribe los WAV
##   node godot/tools/godot.mjs run --headless --script res://tools/bake_lab_extra.gd -- --check   solo comprueba
##   … -- --ids=torno-garras,lima-garra,amoladora-garras,motor-arranque,motor-parada   solo esos (los zumbidos de los aguijones tardan varios minutos)
##   … -- --ids=forja-muela,forja-horno,forja-llama,forja-induccion,forja-prensa,forja-colada,forja-temple   los de la reforja
## Después, `npm run godot:import` (o godot:test) los importa.
extends SceneTree

const SfxInsects = preload("res://core/lab/sfx_insects.gd")
const SfxCare = preload("res://core/lab/sfx_care.gd")
const SfxForge = preload("res://core/lab/sfx_forge.gd")
## Unidad 5t-B: la reacción del animal y la lente de la cámara.
const SfxReaction = preload("res://core/lab/sfx_reaction.gd")
const Sfx = preload("res://core/lab/sfx.gd")


func _init() -> void:
	# godot.mjs run no reenvía el separador «--»: --check puede llegar como argumento de usuario o del motor
	var check := OS.get_cmdline_user_args().has("--check") or OS.get_cmdline_args().has("--check")
	var only: Array = []
	for a: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--ids="):
			only = Array(a.substr(6).split(",", false))
	var stale: Array[String] = []
	var total := 0
	# [id, módulo]: los de los aguijones, los de la cetrería y los de la reforja
	var jobs: Array = []
	for id: String in SfxInsects.ids():
		jobs.append([id, "aguijones"])
	for id: String in SfxCare.ids():
		jobs.append([id, "cetreria"])
	for id: String in SfxForge.ids():
		jobs.append([id, "reforja"])
	for id: String in SfxReaction.ids():
		jobs.append([id, "reaccion"])
	for job: Array in jobs:
		var id: String = job[0]
		if not only.is_empty() and not only.has(id):
			continue
		total += 1
		var module := String(job[1])
		var bytes: PackedByteArray = SfxInsects.wav_bytes(id) if module == "aguijones" else (SfxCare.wav_bytes(id) if module == "cetreria" else (SfxReaction.wav_bytes(id) if module == "reaccion" else SfxForge.wav_bytes(id)))
		var path := Sfx.path_of(id)
		if check:
			if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path) != bytes:
				stale.append(id)
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		var looped: bool = SfxInsects.is_loop(id) if module == "aguijones" else (SfxCare.is_loop(id) if module == "cetreria" else (false if module == "reaccion" else SfxForge.is_loop(id)))
		# los bucles llevan detrás su cola (Sfx.LOOP_TAIL muestras del principio): el bucle se cierra antes de ella
		ensure_import(path + ".import", (bytes.size() - 44) / 2 - (Sfx.LOOP_TAIL if looped else 0), looped)
	if check:
		if stale.is_empty():
			print("Sonidos de la 2.0 del laboratorio al día (%d archivos)." % total)
		else:
			print("Sonidos de la 2.0 del laboratorio desactualizados: %s. Vuelve a hornear con tools/bake_lab_extra.gd." % ", ".join(stale))
	else:
		print("%d archivos horneados en %s." % [total, Sfx.SFX_DIR])
	quit(1 if not stale.is_empty() else 0)


## Parámetros del .import de un efecto: los de los WAV de la 1.x (una vez, comprimido) o, si es un bucle, hacia delante
## de la muestra 0 a `frames` (exclusiva) y sin comprimir.
static func import_params(frames: int, looped: bool) -> Dictionary:
	if looped:
		return { "edit/loop_mode": "2", "edit/loop_begin": "0", "edit/loop_end": str(frames), "compress/mode": "0" }
	return { "edit/loop_mode": "0", "edit/loop_begin": "0", "edit/loop_end": "-1", "compress/mode": "2" }


## Deja el .import con esos parámetros. Si no existe, escribe uno mínimo y Godot completa uid y rutas al importar.
static func ensure_import(path: String, frames: int, looped: bool) -> void:
	var params := import_params(frames, looped)
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	else:
		text = "[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[params]\n\n"
		text += "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\n"
		text += "edit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=2\n"
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
