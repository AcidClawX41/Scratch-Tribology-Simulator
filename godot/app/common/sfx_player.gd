## Reproductor de efectos cortos: varias voces (AudioStreamPlayer) en un bus, para que un sonido no corte al anterior.
## Los WAV se cargan la primera vez que suenan. Guarda los últimos que ha tocado (tests y demo).
## Mezcla (docs/fase2/qa-sonido.md): cada efecto suena con el ajuste de su clase (Sfx.gain) y, si el mismo efecto aún
## suena en otras voces, entra STACK_DB más bajo por cada una (las pasadas seguidas de la cetrería, cada 0,3 s con efectos
## de 1 s, se apilaban hasta cuatro y llevaban la mezcla al limitador). Se coge una voz libre; si no queda, la más antigua.
## Uso: var sfx := SfxPlayer.new("Lab"); add_child(sfx); sfx.play("tap", 0.7)
extends Node

const Sfx = preload("res://core/lab/sfx.gd")

const VOICES := 6
const LOG_SIZE := 32
## Lo que baja (dB) un efecto por cada copia suya que aún suena.
const STACK_DB := -6.0

var bus := &"Master"
## Últimos efectos pedidos: [id, volumen], el más reciente al final.
var played: Array = []
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _next := 0
## El efecto de cada voz (el último que tocó).
var _voice_id: Array[String] = []


func _init(p_bus := "Master") -> void:
	bus = StringName(p_bus)
	name = "Sonido%s" % p_bus


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
		_voice_id.append("")


func _exit_tree() -> void:
	for p in _players:
		p.stop()


## Stream del efecto (null si no existe).
func stream_of(id: String) -> AudioStream:
	if not _streams.has(id):
		var path := Sfx.path_of(id)
		_streams[id] = load(path) if ResourceLoader.exists(path) else null
	return _streams[id]


## Duración del efecto en segundos (0 si no existe).
func length_of(id: String) -> float:
	var s := stream_of(id)
	return s.get_length() if s != null else 0.0


## Toca un efecto con volumen lineal (0-1), como el playSfx(id, volume) de la 1.x, con el ajuste de la mezcla.
func play(id: String, volume := 0.7) -> void:
	played.append([id, volume])
	if played.size() > LOG_SIZE:
		played.pop_front()
	var s := stream_of(id)
	if s == null or _players.is_empty() or not is_inside_tree():
		return
	var i := _free_voice()
	var p := _players[i]
	p.stream = s
	p.volume_db = volume_db_for(id, volume, copies_playing(id))
	p.play()
	_voice_id[i] = id


## Volumen (dB) de un efecto pedido a `volume` con `copies` copias suyas sonando: el de la mezcla, más bajo si se apila.
static func volume_db_for(id: String, volume: float, copies := 0) -> float:
	return linear_to_db(maxf(volume * Sfx.gain(id), 0.0001)) + STACK_DB * copies


## Cuántas voces tocan ahora el efecto id.
func copies_playing(id: String) -> int:
	var n := 0
	for i in _players.size():
		if _voice_id[i] == id and _players[i].playing:
			n += 1
	return n


## Una voz libre (la siguiente en la rueda) o, si todas suenan, la más antigua de la rueda.
func _free_voice() -> int:
	for k in _players.size():
		var i := (_next + k) % _players.size()
		if not _players[i].playing:
			_next = (i + 1) % _players.size()
			return i
	var j := _next
	_next = (_next + 1) % _players.size()
	return j
