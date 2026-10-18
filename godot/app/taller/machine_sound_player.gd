## Reproduce el sonido de una máquina del taller.
##
## 60 veces por segundo (_physics_process) pide a core/taller/machine_sound.gd el marco de la entrada de sonido
## vigente y sus voces, y lleva hacia ellas, con suavizado exponencial, el volumen y el pitch_scale de cada
## bucle horneado (assets/sfx/taller/) y los filtros del corte. No sintetiza nada muestra a muestra.
## - Motor: AudioStreamPlayer (el motor va dentro de la bancada: no se sitúa).
## - Plato: AudioStreamPlayer3D en chuck_position con el giro del husillo y, en el torno, el paso de garras.
## - Punta: AudioStreamPlayer3D en tool_pos con el corte (bus «MaquinaCorte»), la chapa, el chatter (tono y dos
##   bandas laterales), el refrigerante, el roce de la piedra húmeda (afiladora lenta), el paso de dientes o
##   segmentos, el crujido denso y los granos de viruta.
##   Los granos se disparan en un AudioStreamPolyphonic con rng.gd (grano, tono y volumen): a diferencia de
##   AudioStreamRandomizer, así la misma sesión suena igual en cada ejecución (y la captura es reproducible).
## - Bus «MaquinaCorte» (envía a «Maquina»): paso banda (fc, Q = 2·resonance) y paso bajo del corte.
##   Bus «Maquina»: paso alto fijo a 25 Hz y panoramizador. Con escena 3D panoramizan los AudioStreamPlayer3D
##   y el panoramizador queda en 0; con use_3d = false (vista 2D, sin Camera3D) todo es AudioStreamPlayer y el
##   paneo sale del marco (tool_pos.x).
## Los filtros del bus son compartidos: suena una máquina cada vez.
## Uso: var s := MachineSoundPlayer.new(); s.use_3d = false (solo en vistas 2D, antes de add_child); add_child(s);
##      s.set_input({ "process": "lathe", "rpm": 1200.0, … }) cada vez que cambie el estado de la máquina.
## Los volúmenes llegan 12 dB por debajo (MachineSound.HEADROOM_DB) y el bus «Maquina» los recupera.
extends Node3D

const MachineSound = preload("res://core/taller/machine_sound.gd")
const Rng = preload("res://core/shared/rng.gd")

const SFX_DIR := "res://assets/sfx/taller/"
const BUS := &"Maquina"
const CUT_BUS := &"MaquinaCorte"
## Voces de bucle y dónde suenan (plato o punta). «pass» cambia de sitio según la máquina.
const LOOP_VOICES := [
	"motor", "spindle", "pass", "cut", "sheet", "chatter", "chatter_lo", "chatter_hi", "coolant", "crackle", "rub",
]
const AT_CHUCK := ["spindle"]
const TAU_VOLUME := 0.05  # s: constante de tiempo del suavizado de volumen
const TAU_PITCH := 0.08  # s: del tono
const TAU_FILTER := 0.08  # s: de los filtros del bus
const SILENT := 1e-4  # por debajo de este volumen lineal la voz se detiene
const GRAIN_PITCH := Vector2(0.85, 1.2)  # margen del tono de cada grano
const GRAIN_DB := Vector2(-8.0, 0.0)  # margen de volumen de cada grano (dB)

## Posición del plato en el sistema local de este nodo (m).
@export var chuck_position := Vector3(-0.3, 0.0, 0.0)
## false en vistas sin Camera3D: voces no posicionales y paneo desde el marco. Se lee al entrar en el árbol:
## cambiarlo después no tiene efecto.
@export var use_3d := true
## Semilla de los granos de viruta (la misma semilla, la misma secuencia).
@export var grain_seed := "virutas"

## Entrada de sonido vigente (CONTRATOS.md). Vacía = máquina parada.
var input: Dictionary = {}
## Último marco calculado (para la interfaz, la depuración o los tests).
var last_frame: Dictionary = {}
## Últimas voces calculadas.
var last_voices: Dictionary = {}

var _voices := {}  # id → { player, loop, vol, pitch }
var _streams := {}  # id de bucle → AudioStreamWAV
var _chuck: Node3D
var _tip: Node3D
var _grain_player: Node
var _grain_playback: AudioStreamPlaybackPolyphonic
var _grain_streams: Array[AudioStream] = []
var _grain_idle := 0.0  # s desde el último grano (el reproductor polifónico se para al quedar libre)
var _rng: Rng
var _was_cutting := false
var _bus_ready := false
var _bpf: AudioEffectBandPassFilter
var _lpf: AudioEffectLowPassFilter
var _panner: AudioEffectPanner
var _cut_hz := 3000.0
var _cut_res := 1.0
var _cut_lp := 16000.0
var _pan := 0.0
var _is_3d := true  # use_3d al entrar en el árbol


func _ready() -> void:
	_is_3d = use_3d
	_rng = Rng.new(Rng.seed_of(grain_seed))
	_chuck = Node3D.new()
	_chuck.name = "Plato"
	_chuck.position = chuck_position
	add_child(_chuck)
	_tip = Node3D.new()
	_tip.name = "Punta"
	add_child(_tip)
	_setup_buses()
	for id in LOOP_VOICES:
		var parent: Node = self if id == "motor" else (_chuck if id in AT_CHUCK else _tip)
		var p := _make_player(parent, id, id != "motor", CUT_BUS if id == "cut" else BUS)
		_voices[id] = { "player": p, "loop": "", "vol": 0.0, "pitch": 1.0 }
	for i in MachineSound.CHIP_GRAINS:
		_grain_streams.append(load("%schip_%d.wav" % [SFX_DIR, i]))
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 16
	_grain_player = _make_player(_tip, "granos", true, BUS)
	_grain_player.set("stream", poly)


func _exit_tree() -> void:
	stop_now()


## Cambia la entrada de sonido (se aplica en el siguiente paso de 60 Hz, con suavizado).
func set_input(d: Dictionary) -> void:
	input = d.duplicate()


## Para la máquina: todas las voces se funden a silencio.
func stop_all() -> void:
	input = {}


## Corta en seco todas las voces (al cerrar una escena o al final de un guion, ya en silencio). El servidor
## de audio suelta cada reproducción en la siguiente mezcla; si el programa se cierra sonando (Movie Maker
## con --quit-after), Godot avisa al salir de que quedaron reproducciones vivas.
func stop_now() -> void:
	input = {}
	for id in _voices:
		var vs: Dictionary = _voices[id]
		vs["player"].call("stop")
		vs["vol"] = 0.0
	if _grain_player != null:
		_grain_player.call("stop")
	_grain_playback = null


func _physics_process(delta: float) -> void:
	var fr := MachineSound.frame(input if not input.is_empty() else { "rpm": 0.0 })
	var v := MachineSound.voices(fr)
	last_frame = fr
	last_voices = v
	var k_vol := 1.0 - exp(-delta / TAU_VOLUME)
	var k_pitch := 1.0 - exp(-delta / TAU_PITCH)
	var pos: Variant = input.get("tool_pos", Vector3.ZERO)
	_tip.position = pos if pos is Vector3 else Vector3.ZERO
	_chuck.position = chuck_position
	# El paso de garras suena en el plato; el de dientes y segmentos, donde corta la herramienta
	_reparent_pass(fr["process"] == "lathe")
	for id in LOOP_VOICES:
		_apply(id, v.get(id, {}), k_vol, k_pitch)
	_update_bus(v["bus"], float(fr["pan"]), 1.0 - exp(-delta / TAU_FILTER))
	_update_grains(v["grains"], fr, delta)


func _apply(id: String, target: Dictionary, k_vol: float, k_pitch: float) -> void:
	var vs: Dictionary = _voices[id]
	var p: Node = vs["player"]
	var loop := str(target.get("loop", ""))
	var vol := float(target.get("volume", 0.0))
	var pitch := float(target.get("pitch", 1.0))
	if loop != "" and loop != vs["loop"]:
		p.call("stop")
		p.set("stream", _stream(loop))
		vs["loop"] = loop
		vs["pitch"] = pitch  # otro bucle: sin deslizar desde el tono del anterior
	var was: float = vs["vol"]
	var cur: float = was + (vol - was) * k_vol
	if cur < SILENT and vol < SILENT:
		cur = 0.0
	vs["vol"] = cur
	var cp: float = vs["pitch"]
	if vol < SILENT:
		pass  # se apaga: conserva su tono (una voz que calla no se desliza hacia el tono de una capa inactiva)
	elif was < SILENT:
		cp = maxf(pitch, 0.01)  # entra desde el silencio: directa a su tono, sin barrido
	else:
		cp *= pow(maxf(pitch, 0.01) / maxf(cp, 0.01), k_pitch)  # en escala logarítmica: los semitonos tardan igual
	vs["pitch"] = cp
	var playing: bool = p.get("playing")
	if cur <= 0.0 or vs["loop"] == "":
		if playing:
			p.call("stop")
		return
	p.set("pitch_scale", clampf(cp, 0.01, 16.0))
	p.set("volume_db", linear_to_db(cur))
	if not playing:
		p.call("play")


func _update_bus(bus: Dictionary, pan: float, k: float) -> void:
	if not _bus_ready:
		return
	# fc en escala logarítmica, resonancia y paso bajo suavizados igual que el volumen
	_cut_hz *= pow(maxf(float(bus["cut_hz"]), 20.0) / _cut_hz, k)
	_cut_res += (float(bus["cut_resonance"]) - _cut_res) * k
	_cut_lp *= pow(maxf(float(bus["cut_lp_hz"]), 200.0) / _cut_lp, k)
	_pan += ((0.0 if _is_3d else pan) - _pan) * k
	_bpf.cutoff_hz = _cut_hz
	_bpf.resonance = _cut_res
	_lpf.cutoff_hz = _cut_lp
	_panner.pan = _pan


## Granos de viruta como un proceso de Poisson: en cada paso de 60 Hz, un grano con probabilidad tasa·dt.
## Al entrar la herramienta en el material, un golpe (dos granos fuertes).
func _update_grains(g: Dictionary, fr: Dictionary, delta: float) -> void:
	if _grain_player == null:
		return
	var cutting: bool = float(fr["load"]) > 0.0 and float(fr["noise"]["gain"]) > 0.0
	var vol: float = g["volume"]
	_grain_idle += delta
	if cutting and not _was_cutting and vol > 0.0:
		for i in 2:
			_play_grain(minf(1.0, vol * 2.0))
	_was_cutting = cutting
	if vol > 0.0 and _rng.next() < float(g["rate"]) * delta:
		_play_grain(vol)
	# Sin granos durante medio segundo (cada uno dura 80 ms): el reproductor se para
	if _grain_playback != null and _grain_idle > 0.5:
		_grain_player.call("stop")
		_grain_playback = null


func _play_grain(vol: float) -> void:
	if _grain_playback == null:
		_grain_player.call("play")
		_grain_playback = _grain_player.call("get_stream_playback") as AudioStreamPlaybackPolyphonic
	_grain_idle = 0.0
	var s: AudioStream = _grain_streams[int(_rng.next() * _grain_streams.size()) % _grain_streams.size()]
	var pitch := lerpf(GRAIN_PITCH.x, GRAIN_PITCH.y, _rng.next())
	var db := linear_to_db(maxf(vol, 1e-6)) + lerpf(GRAIN_DB.x, GRAIN_DB.y, _rng.next())
	_grain_playback.play_stream(s, 0.0, db, pitch)


func _reparent_pass(at_chuck: bool) -> void:
	var p: Node = _voices["pass"]["player"]
	var want: Node = _chuck if at_chuck else _tip
	if p.get_parent() != want:
		p.reparent(want, false)


func _stream(loop: String) -> AudioStream:
	if not _streams.has(loop):
		_streams[loop] = load(SFX_DIR + loop + ".wav")
	return _streams[loop]


func _make_player(parent: Node, id: String, positional: bool, bus: StringName) -> Node:
	var p: Node
	if positional and _is_3d:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 1.0  # 0 dB a 1 m; el inverso de la distancia a partir de ahí
		p3.max_db = 6.0
		p3.attenuation_filter_cutoff_hz = 20500.0  # sin el filtro de distancia de Godot: a 1–2 m el aire no apaga nada
		p3.panning_strength = 1.0
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.name = id
	p.set("bus", bus)
	parent.add_child(p)
	return p


## Busca los buses y sus efectos (default_bus_layout.tres). Si faltan (otro diseño de buses), los crea.
func _setup_buses() -> void:
	var main := AudioServer.get_bus_index(BUS)
	if main < 0:
		AudioServer.add_bus()
		main = AudioServer.bus_count - 1
		AudioServer.set_bus_name(main, BUS)
		AudioServer.set_bus_send(main, &"Master")
	if _find_effect(main, "AudioEffectAmplify") == null:
		var amp := AudioEffectAmplify.new()
		amp.volume_db = MachineSound.HEADROOM_DB  # recupera el margen que dejan las voces
		AudioServer.add_bus_effect(main, amp, 0)
	_panner = _find_effect(main, "AudioEffectPanner") as AudioEffectPanner
	if _panner == null:
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 25.0
		AudioServer.add_bus_effect(main, hp)
		_panner = AudioEffectPanner.new()
		AudioServer.add_bus_effect(main, _panner)
	var cut := AudioServer.get_bus_index(CUT_BUS)
	if cut < 0:
		AudioServer.add_bus()
		cut = AudioServer.bus_count - 1
		AudioServer.set_bus_name(cut, CUT_BUS)
		AudioServer.set_bus_send(cut, BUS)
	_bpf = _find_effect(cut, "AudioEffectBandPassFilter") as AudioEffectBandPassFilter
	if _bpf == null:
		_bpf = AudioEffectBandPassFilter.new()
		AudioServer.add_bus_effect(cut, _bpf)
	_lpf = _find_effect(cut, "AudioEffectLowPassFilter") as AudioEffectLowPassFilter
	if _lpf == null:
		_lpf = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(cut, _lpf)
	_bpf.db = AudioEffectFilter.FILTER_6DB  # una sola etapa: Q efectivo = 2·resonance (lo que supone voices())
	_bus_ready = true


static func _find_effect(bus: int, cls: String) -> AudioEffect:
	for i in AudioServer.get_bus_effect_count(bus):
		var e := AudioServer.get_bus_effect(bus, i)
		if e.get_class() == cls:
			return e
	return null
