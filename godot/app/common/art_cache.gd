## Caché de ilustraciones: grafo de escena (core/lab/art.gd o un dibujo de la interfaz) → SVG (core/lab/svg.gd) →
## textura (ThorVG, con los arreglos de svg_texture.gd). Construir y serializar un dibujo cuesta de 1 a ~180 ms (el
## cuarzo del banco es el peor), así que ese trabajo va a hilos de WorkerThreadPool y la interfaz no se congela: una
## vista pide la textura y, si aún no está, la recibe en un fotograma posterior (señal art_ready).
## - Se rasteriza solo cuando cambian las entradas: la clave identifica el dibujo y la escala en píxeles; el SVG se
##   guarda por clave, así que cambiar de tamaño solo repite ThorVG (1-5 ms).
## - Además del grafo, guarda los datos que devuelve el dibujo (tip, labels, length…): meta(key).
## - Sin hilos (threaded = false, tests) todo se hace al momento.
## - Las entradas del dibujo (make) no deben cambiar después: los resultados y los catálogos no se modifican nunca.
## Uso: var art := ArtCache.new(); var tex := art.texture("sw:madera", Art.surface_art.bind("madera", o), view, 2.0)
##      y en _process: art.poll(). Al cerrar: art.dispose().
extends RefCounted

signal art_ready(key: String)

const Svg = preload("res://core/lab/svg.gd")
const SvgTexture = preload("res://app/common/svg_texture.gd")

## Claves del grafo que no son datos del dibujo.
const GRAPH_KEYS := ["defs", "body", "lines", "extras"]

var threaded := true
var max_textures := 220
var max_pixels := 40_000_000
var max_svgs := 400
## Métricas: dibujos rasterizados y tiempo total de construcción + serialización + ThorVG (ms).
var rasterized := 0
var work_ms := 0.0
var max_ms := 0.0

var _svgs := {}  # key → { svg: String, meta: Dictionary }
var _tex := {}  # tkey → Texture2D (orden de uso: el último, el más reciente)
var _tex_px := {}
var _total_px := 0
var _jobs := {}  # tkey → id de tarea de WorkerThreadPool
var _waited := {}  # tkey → true (tareas ya esperadas por wait_all)
var _results: Array = []  # resultados de los hilos, protegidos por _mutex
var _mutex := Mutex.new()


## Clave de la textura: dibujo + escala redondeada a la centésima.
static func texture_key(key: String, scale: float) -> String:
	return "%s@%d" % [key, int(round(scale * 100.0))]


static func snap_scale(scale: float) -> float:
	return clampf(round(scale * 100.0) / 100.0, 0.1, SvgTexture.MAX_SCALE)


## Textura del dibujo `key` a esa escala, o null si todavía se está preparando (llegará con art_ready).
## make() devuelve el grafo; view = { viewBox, width, height } (tamaño en px lógicos del SVG).
func texture(key: String, make: Callable, view: Dictionary, scale: float) -> Texture2D:
	var sc := snap_scale(scale)
	var tkey := texture_key(key, sc)
	if _tex.has(tkey):
		var t: Texture2D = _tex[tkey]
		_tex.erase(tkey)
		_tex[tkey] = t
		return t
	if _jobs.has(tkey):
		return null
	var cached: Dictionary = _svgs.get(key, {})
	if not threaded:
		_store(_build(key, tkey, make, view, sc, cached))
		return _tex.get(tkey)
	_jobs[tkey] = WorkerThreadPool.add_task(_job.bind(key, tkey, make, view, sc, cached), false, "dibujo del laboratorio")
	return null


## ¿Está ya la textura? (sin pedirla)
func has_texture(key: String, scale: float) -> bool:
	return _tex.has(texture_key(key, snap_scale(scale)))


## Datos del dibujo (tip, labels, length…) si ya se ha construido; {} si no.
func meta(key: String) -> Dictionary:
	var e: Dictionary = _svgs.get(key, {})
	return e.get("meta", {})


## SVG del dibujo si ya se ha construido ("" si no).
func svg(key: String) -> String:
	var e: Dictionary = _svgs.get(key, {})
	return e.get("svg", "")


## Tareas pendientes.
func pending() -> int:
	return _jobs.size()


## Recoge lo que han terminado los hilos (llamar cada fotograma). Devuelve cuántos dibujos han llegado.
func poll() -> int:
	_mutex.lock()
	var done := _results
	_results = []
	_mutex.unlock()
	for r: Dictionary in done:
		var tkey: String = r.tkey
		if _jobs.has(tkey):
			if not _waited.has(tkey):
				WorkerThreadPool.wait_for_task_completion(_jobs[tkey])
			_jobs.erase(tkey)
			_waited.erase(tkey)
		_store(r)
		art_ready.emit(String(r.key))
	return done.size()


## Espera a que acaben todas las tareas y recoge sus dibujos (demo, tests y al cerrar).
func wait_all() -> void:
	for tkey: String in _jobs:
		if not _waited.has(tkey):
			WorkerThreadPool.wait_for_task_completion(_jobs[tkey])
			_waited[tkey] = true
	poll()


## Antes de soltar la caché: ningún hilo puede quedar trabajando para ella.
func dispose() -> void:
	wait_all()
	_tex.clear()
	_tex_px.clear()
	_total_px = 0


func _job(key: String, tkey: String, make: Callable, view: Dictionary, scale: float, cached: Dictionary) -> void:
	var r := _build(key, tkey, make, view, scale, cached)
	_mutex.lock()
	_results.append(r)
	_mutex.unlock()


## Construye, serializa y rasteriza (en un hilo o no). No toca nada compartido.
static func _build(key: String, tkey: String, make: Callable, view: Dictionary, scale: float, cached: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var svg_text: String = cached.get("svg", "")
	var meta_data: Dictionary = cached.get("meta", {})
	if svg_text == "":
		var art: Variant = make.call()
		svg_text = Svg.scene_to_svg(art, view)
		meta_data = {}
		if art is Dictionary:
			for k: String in art:
				if not GRAPH_KEYS.has(k):
					meta_data[k] = art[k]
	var img := SvgTexture.rasterize_image(svg_text, scale)
	return {
		"key": key, "tkey": tkey, "svg": svg_text, "meta": meta_data, "image": img,
		"ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}


func _store(r: Dictionary) -> void:
	var key: String = r.key
	if not _svgs.has(key):
		_svgs[key] = { "svg": r.svg, "meta": r.meta }
		while _svgs.size() > max_svgs:
			_svgs.erase(_svgs.keys()[0])
	rasterized += 1
	work_ms += float(r.ms)
	max_ms = maxf(max_ms, float(r.ms))
	var img: Image = r.image
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	var tkey: String = r.tkey
	var px := img.get_width() * img.get_height()
	if _tex.has(tkey):
		_total_px -= int(_tex_px[tkey])
	_tex[tkey] = tex
	_tex_px[tkey] = px
	_total_px += px
	while _tex.size() > 1 and (_tex.size() > max_textures or _total_px > max_pixels):
		var old: String = _tex.keys()[0]
		_total_px -= int(_tex_px[old])
		_tex.erase(old)
		_tex_px.erase(old)
