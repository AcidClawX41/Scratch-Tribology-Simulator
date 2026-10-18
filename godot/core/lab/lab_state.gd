## Tribología biológica · estado del banco (port de packages/core/src/labState.js, sin React).
##
## Las selecciones del banco, el ensayo y su animación, los sonidos, los logros, el cuaderno y el modo dual, en un
## solo objeto que la interfaz lee y modifica con set_*(). En la 1.x era un hook de React; aquí es un RefCounted:
## cada cambio se aplica al momento y emite `changed`, así que la interfaz no recalcula nada.
##
## Temporizadores deterministas: en lugar de setTimeout, una cola que avanza con advance(ms) (la interfaz la llama
## desde _process con delta·1000; los tests, con los mismos pasos que el reloj simulado de node:test). Al
## avanzar, el reloj salta al final del paso y después disparan, en orden de hora y de alta, los temporizadores
## vencidos. Se cancelan todos al cambiar cualquier parámetro o repetir el ensayo, así ningún ensayo viejo pisa
## al nuevo.
##
## Inyectados:
##   - play: Callable(id: String, volume: float) reproduce un efecto de sonido. Donde el JS llamaba play(id) sin
##     volumen, aquí va DEFAULT_VOLUME (0,7, lo que ponían las dos apps 1.x); la fanfarria de un logro, 0,5.
##   - sfx_picker: Callable(res: Dictionary, target: Dictionary) -> String elige el efecto de un resultado
##     (core/lab/sfx.gd → sfx_for_result).
##
## Física con versión: `model` ("2.0" en la aplicación; los tests del oráculo ponen "1.x"). Todo lo que la interfaz
## calcula pasa por compute(), duel() y tool() de este objeto, que llevan ese modelo al core; la interfaz no llama a
## Physics.compute, Physics.resolve_tool ni Lab.duel directamente (lo vigila tests/app/test_lab_model.gd).
## Uso: const LabState = preload("res://core/lab/lab_state.gd"); var lab := LabState.new(play, Sfx.sfx_for_result)
extends RefCounted

signal changed

const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Lab = preload("res://core/lab/lab.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
## Modelo 2.0 · biología (docs/fisica/pulido-biologia.md §9.1): la zona del cuerpo de la piel y el ángulo de ataque.
const Zones = preload("res://core/lab/zones.gd")
const Attack = preload("res://core/lab/attack.gd")
## Modelo 2.0 · el afilado de las garras reforjadas y los textos de su deslizador (unidad 4i).
const DinoLab = preload("res://core/lab/dino_lab.gd")
## Modelo 2.0 · «Fuentes y estimaciones» del ensayo a la vista (unidad 4n).
const BenchTexts = preload("res://core/lab/bench_texts.gd")

const RUN_MS := 1150.0  # duración de la animación del banco
## Volumen de un efecto cuando labState.js llamaba play(id) sin volumen: el valor por defecto de playSfx(id, volume = 0.7)
## en las dos apps 1.x (apps/desktop/src/sound.js y apps/mobile/src/sound.js). Así se conserva el equilibrio con la
## fanfarria (0,5).
const DEFAULT_VOLUME := 0.7
const LOG_SIZE := 6  # entradas del cuaderno
## Efecto del desgarro del aparato del aguijón (la autotomía de la abeja), que suena con el guion de sting_lab.gd.
const SFX_TEAR := "desgarro-aguijon"
## Selección inicial del banco: almendra de acrílico sobre una uña ajena, 4 N, arañazo de 25 mm. Las entradas van
## por índice (una constante no admite búsquedas) en el catálogo de la 2.0 (core/lab/catalog.gd), cuya parte 1.x es
## la de data.gd. No pueden desplazarse sin avisar: test_data.gd fija el orden y los ids de cada catálogo a los del
## oráculo y comprueba estos ids, y test_catalog.gd, que la parte 1.x del catálogo es Data. Ojo: GDScript pliega las
## constantes de otro script en copias, así que las selecciones se comparan por valor (==), no con is_same().
const LAB_DEFAULTS := {
	"geom": Catalog.GEOMS[3], "base": Catalog.BASES[2], "inlay": Catalog.INLAYS[0], "target": Catalog.TARGETS[4], "type": Catalog.TYPES[1],
	"force": 4.0, "length": 25.0, "passes": 1.0,
}

## Versión de la física del banco (Physics.MODELS): "2.0", la de la aplicación, o "1.x", la del motor 1.x.
var model: String = Physics.MODEL_V2
var geom: Dictionary = LAB_DEFAULTS.geom
var base: Dictionary = LAB_DEFAULTS.base
var inlay: Dictionary = LAB_DEFAULTS.inlay
var claw: Variant = null  # garra o colmillo (Dictionary), o null con una uña
var tear_mode := false
var method := "rayado"
var strike := false
var wet := false
var passes: float = LAB_DEFAULTS.passes
var target: Dictionary = LAB_DEFAULTS.target
var force: float = LAB_DEFAULTS.force
var length: float = LAB_DEFAULTS.length
var type: Dictionary = LAB_DEFAULTS.type
## 2.0 · zona del cuerpo cuando el material es la piel (id de zones.gd): el brazo, el de la 1.x, por defecto.
var zone: String = Zones.DEFAULT_ID
## 2.0 · ángulo de ataque pedido (grados, 10-170) o null: el de la herramienta (Attack.default_deg: 45° en las uñas, 90°
## en garras y colmillos). Vuelve a null al pasar de uña a garra o al revés (su ángulo significa otra cosa).
var attack_deg: Variant = null
## 2.0 · afilado de una garra o un colmillo reforjados (0-1; docs/fisica/velociraptor.md §3 y §10.2): de la punta de la
## ficha al filo más fino medido, en escala logarítmica. Solo cuenta con una herramienta que se puede afilar
## (sharpenable()); se conserva al cambiar de garra o de material, como la fuerza.
var sharpness := 0.0
var phase := "idle"  # idle → running → done
var res: Variant = null  # resultado del último ensayo (Physics.compute) o null
var notebook: Array = []  # cuaderno (`log` en el JS): { id, tool, tgt, verdict, col }, el más reciente primero
var badges: Dictionary = {}  # logros ganados: id → true, en orden de inserción
var count := 0  # ensayos hechos (los recuerda ajustes.cfg y se reinician con reset_progress)
## Ensayos de esta sesión, sin reiniciarse nunca: identifica cada ensayo en la interfaz (animación del banco, tarjeta
## del resultado). No se usa count porque, tras reiniciar los logros, volvería a repetir números.
var run_seq := 0
## Modo dual: el mismo ensayo en dos coches (por defecto, clásico frente a moderno)
var dual := false
var dual_pair: Array = Lab.DUEL_DEFAULT.duplicate()

var _play: Callable
var _sfx_picker: Callable
## Método, golpe y desgarro de antes de elegir un aguijón (que solo pica): se recuperan al volver a una garra o una uña.
var _before_sting: Dictionary = {}
var _now := 0.0  # ms del reloj de los temporizadores
var _seq := 0
var _timers: Array = []  # [{ at: ms, seq: orden de alta, fn: Callable }]


func _init(play: Callable = Callable(), sfx_picker: Callable = Callable()) -> void:
	_play = play
	_sfx_picker = sfx_picker


# ── Temporizadores ──

## Avanza el reloj ms milisegundos y dispara, en orden, los temporizadores que vencen.
func advance(ms: float) -> void:
	_now += ms
	while true:
		var next := -1
		for i in _timers.size():
			var t: Dictionary = _timers[i]
			if t.at > _now:
				continue
			if next < 0 or t.at < _timers[next].at or (t.at == _timers[next].at and t.seq < _timers[next].seq):
				next = i
		if next < 0:
			return
		var fn: Callable = _timers[next].fn
		_timers.remove_at(next)
		fn.call()


## Temporizadores pendientes (para los tests y la depuración).
func pending_timers() -> int:
	return _timers.size()


## Cancela los temporizadores vivos (el cleanup del useEffect del JS) y deja el banco en un estado estable: un ensayo
## a medio animar se da por terminado, sin sus sonidos pendientes. La interfaz lo llama al cerrar el banco; para
## pausarlo (al cambiar de sección) basta con dejar de llamar a advance().
func dispose() -> void:
	_clear_timers()
	if phase == "running":
		phase = "done"
		changed.emit()


func _clear_timers() -> void:
	_timers.clear()


func _later(fn: Callable, ms: float) -> void:
	_seq += 1
	_timers.append({ "at": _now + ms, "seq": _seq, "fn": fn })


func _sound(id: String, volume: float = DEFAULT_VOLUME) -> void:
	if _play.is_valid():
		_play.call(id, volume)


# ── Selecciones ──

func _reset() -> void:
	_clear_timers()
	phase = "idle"
	res = null


## Cambio de un parámetro del ensayo: resetea el banco y suena el clic de la interfaz (sfx "" = sin clic).
func _changed(sfx: String = "tap") -> void:
	if sfx != "":
		_sound(sfx)
	changed.emit()


func set_geom(v: Dictionary) -> void:
	_reset()
	geom = v
	_changed()


func set_base(v: Dictionary) -> void:
	_reset()
	base = v
	_changed()


func set_inlay(v: Dictionary) -> void:
	_reset()
	inlay = v
	_fit_force()
	_changed()


## Garra, colmillo o aguijón (Dictionary de Catalog.CLAWS), o null para volver a la uña. Si la fuerza no cabe en la
## escala de la nueva herramienta (Lab.force_range: de un aguijón en mN a una garra en N, o al revés; también al
## reforjarlo o dejar de hacerlo, set_inlay), pasa a la fuerza por defecto de esa escala; entre herramientas de la misma
## escala se conserva, como en la 1.x.
func set_claw(v: Variant) -> void:
	_reset()
	var was_sting := is_stinger()
	if Attack.kind_of(v) != Attack.kind_of(claw):
		attack_deg = null  # el ángulo por defecto del nuevo tipo de herramienta
	claw = v
	# un aguijón solo pica (docs/fisica/aguijones.md §7.2): sin rayado, desgarro ni golpe; al dejarlo, lo de antes
	if is_stinger() and not was_sting:
		_before_sting = { "method": method, "strike": strike, "tear_mode": tear_mode }
	elif was_sting and not is_stinger() and not _before_sting.is_empty():
		method = _before_sting.method
		strike = _before_sting.strike
		tear_mode = _before_sting.tear_mode
		_before_sting = {}
	if is_stinger():
		method = "puncion"
		strike = false
		tear_mode = false
	_fit_force()
	_changed()


## ¿La herramienta elegida es un aguijón de insecto?
func is_stinger() -> bool:
	return Insects.is_stinger(claw)


## Si la fuerza no cabe en la escala de la herramienta (Lab.force_range), la de por defecto de esa escala.
func _fit_force() -> void:
	var r := force_range()
	if force < r.min or force > r.max:
		force = r.default


## Con un aguijón, el método es siempre la punción, sin golpe ni desgarro (la interfaz ni siquiera los enseña).
func set_tear_mode(v: bool) -> void:
	_reset()
	tear_mode = v and not is_stinger()
	_changed()


func set_method(v: String) -> void:
	_reset()
	method = "puncion" if is_stinger() else v
	_changed()


func set_strike(v: bool) -> void:
	_reset()
	strike = v and not is_stinger()
	_changed()


## Húmeda: suena una gota al mojarla y el clic al secarla.
func set_wet(v: bool) -> void:
	_reset()
	wet = v
	_changed("drip" if v else "tap")


func set_passes(v: float) -> void:
	_reset()
	passes = v
	_changed()


func set_target(v: Dictionary) -> void:
	_reset()
	target = v
	_changed()


func set_type(v: Dictionary) -> void:
	_reset()
	type = v
	_changed()


## Los deslizadores (fuerza, largo y pasadas) resetean el banco pero no hacen clic en cada paso.
func set_force(v: float) -> void:
	_reset()
	force = v
	_changed("")


func set_length(v: float) -> void:
	_reset()
	length = v
	_changed("")


func set_passes_slider(v: float) -> void:
	_reset()
	passes = v
	_changed("")


## 2.0 · la zona del cuerpo de la piel (id de zones.gd; uno desconocido, el brazo).
func set_zone(id: String) -> void:
	_reset()
	zone = Zones.resolve(id).id
	_changed()


## 2.0 · el ángulo de ataque pedido (grados; se acota a 10-170) o null para volver al de la herramienta. Es un
## deslizador: resetea el banco sin clic en cada paso.
func set_attack_deg(v: Variant) -> void:
	_reset()
	attack_deg = null if v == null else Attack.clamp_deg(float(v))
	_changed("")


## 2.0 · el afilado (0-1; se acota). Es un deslizador: resetea el banco sin clic en cada paso.
func set_sharpness(v: float) -> void:
	_reset()
	sharpness = clampf(v, 0.0, 1.0)
	_changed("")


## Cambiar la versión de la física resetea el banco (sin clic: no es un control del ensayo).
func set_model(v: String) -> void:
	_reset()
	model = v
	_changed("")


## Activar el modo dual no borra el ensayo; cambiar un coche de la pareja, sí.
func set_dual(v: bool) -> void:
	dual = v
	_changed("on" if v else "off")


func set_dual_car(slot: int, id: String) -> void:
	_reset()
	dual_pair = dual_pair.duplicate()
	dual_pair[slot] = id
	_changed()


# ── Lecturas ──

## Parámetros del ensayo sin la garra ni el desgarro: { geom, base, inlay, target, force, length, type, method,
## strike, passes, wet } (los `params` del JS), el modelo de la física (model) y, de la 2.0, la zona del cuerpo (zone), el
## ángulo de ataque pedido (attack_deg, null si es el de la herramienta) y el afilado (sharpness: el motor solo lo usa
## con una garra o un colmillo reforjados). La 1.x no los usa.
func params() -> Dictionary:
	return {
		"geom": geom, "base": base, "inlay": inlay, "target": target, "force": force, "length": length, "type": type,
		"method": method, "strike": strike, "passes": passes, "wet": wet, "model": model, "zone": zone,
		"attack_deg": attack_deg, "sharpness": sharpness,
	}


## Physics.compute con el modelo del banco: el de cualquier ensayo que la interfaz calcule (el del banco, las filas de
## la comparativa…). p son unos parámetros de compute(); su `model`, si lo trae, se sustituye por el del banco.
## bench_model: el modelo del banco leído antes en el hilo principal, para llamarla desde otro hilo (las filas de la
## comparativa) sin leer el estado mientras cambia; vacío, el de ahora.
func compute(p: Dictionary, bench_model := "") -> Dictionary:
	var q := p.duplicate()
	q.model = bench_model if bench_model != "" else model
	return _core_compute(q)


## El ensayo actual en los dos coches del modo dual y en cada manera de atacar (Lab.duel), con el modelo del banco.
func duel() -> Array:
	return _core_duel(params(), claw, dual_cars())


## La herramienta resuelta (Physics.resolve_tool) con la selección actual y el modelo del banco (afilada, si se puede).
func tool() -> Dictionary:
	return _core_tool({
		"geom": geom, "base": base, "inlay": inlay, "claw": claw, "wet": wet, "model": model, "sharpness": sharpness,
	})


## 2.0 · ¿se puede afilar la herramienta elegida? Una garra o un colmillo reforjados (Physics.sharpenable), en la 2.0.
func sharpenable() -> bool:
	return Physics.sharpenable({ "claw": claw, "inlay": inlay, "model": model })


## 2.0 · el compromiso del afilado con la selección actual, sin ensayar (Physics.sharpness_report: el mismo campo
## `sharpness` que dará el ensayo) o null si la herramienta no se puede afilar.
func sharpness_report() -> Variant:
	if not sharpenable():
		return null
	var p := params()
	p.claw = claw
	p.tear = tear_mode
	return _core_sharpness(p)


## 2.0 · el deslizador «Afilado» y sus dos barras, con sus textos (DinoLab.sharpness_view), o {} si la herramienta no se
## puede afilar.
func sharpness_view() -> Dictionary:
	var rep: Variant = sharpness_report()
	if rep == null:
		return {}
	return DinoLab.sharpness_view(rep, Lab.material_name(inlay))


## 2.0 · «Fuentes y estimaciones» del ensayo a la vista (BenchTexts.sources): cada dato de la 2.0 que ha usado, con su
## valor, su calidad y su fuente legible. Vacío sin ensayo o con un resultado de la 1.x. Cambiar cualquier parámetro borra el
## resultado, así que la selección de ahora es la del ensayo.
func trial_sources() -> Array:
	if res == null:
		return []
	return BenchTexts.sources(res, { "claw": claw, "inlay": inlay, "target": target })


## Las únicas llamadas al core de la física (los tests las espían con una subclase: tests/app/lab_state_spy.gd).
func _core_compute(p: Dictionary) -> Dictionary:
	return Physics.compute(p)


func _core_duel(p: Dictionary, claw_v: Variant, cars: Array) -> Array:
	return Lab.duel(p, claw_v, cars)


func _core_tool(p: Dictionary) -> Dictionary:
	return Physics.resolve_tool(p)


func _core_sharpness(p: Dictionary) -> Variant:
	return Physics.sharpness_report(p)


## Las notas de los parámetros (lo que profundizan las pasadas y la palanca del desgarro) con la física del banco: la
## interfaz las lee de aquí y no de Physics, para que un cambio de la 2.0 en esas funciones le llegue igual que a
## compute(). Hoy son las de la 1.x en los dos modelos.
func pass_factor() -> float:
	return Physics.pass_depth_factor(passes)


func tear_lever() -> float:
	return Physics.tear_leverage(claw)


## Energía del golpe (J) de la herramienta actual.
func strike_j() -> float:
	return tool().strikeJ


## 2.0 · el ángulo de ataque del ensayo (grados): el pedido o el de la herramienta (Physics.attack_deg, el único sitio
## que lo decide).
func attack() -> float:
	return Physics.attack_deg({ "claw": claw, "attack_deg": attack_deg })


## 2.0 · el ángulo de ataque por defecto de la herramienta actual y de dónde sale ({ value, source, quality }).
func attack_default() -> Dictionary:
	return Attack.DEFAULTS[Attack.kind_of(claw)]


## 2.0 · la zona del cuerpo elegida (la entrada de zones.gd: name, short, site, fact…).
func zone_info() -> Dictionary:
	return Zones.resolve(zone)


## Botón de fuerza máxima (humana o del animal).
func max_f() -> Dictionary:
	return Lab.max_force_hint(claw)


## Escala de fuerza de la herramienta elegida (Lab.force_range, con su material), siempre en N: la del deslizador y la
## de la fuerza.
func force_range() -> Dictionary:
	return Lab.force_range(claw, inlay)


## Marcas del deslizador con un aguijón (StingLab.marks): la fuerza para perforar la piel (null en un sólido) y la carga
## de pandeo, en N; {} con otra herramienta.
func sting_marks() -> Dictionary:
	return StingLab.marks(claw, inlay, target) if is_stinger() else {}


## Los dos coches del modo dual (entradas de Catalog.TARGETS).
func dual_cars() -> Array:
	var out: Array = []
	for id: String in dual_pair:
		out.append(Catalog.find_by_id(Catalog.TARGETS, id))
	return out


# ── Ensayo ──

## Hace el ensayo: resultado al momento, animación de RUN_MS, sonido (el rayado mientras la punta avanza; la
## punción, al impactar), logros con fanfarria diferida y una entrada nueva en el cuaderno.
func run() -> void:
	_clear_timers()
	var p := params()
	p.claw = claw
	p.tear = tear_mode
	var r := compute(p)
	res = r
	phase = "running"
	_later(_finish_run, RUN_MS)
	var sfx: String = _sfx_picker.call(r, target) if _sfx_picker.is_valid() else ""
	if sfx != "":
		if r.puncture:
			_later(_sound.bind(sfx, DEFAULT_VOLUME), RUN_MS * 0.78)
		else:
			_sound(sfx)
	# la abeja se desgarra al irse: el aparato del aguijón se queda (el momento, del guion de sting_lab.gd)
	if r.get("sting") is Dictionary and r.sting.get("autotomy") == true:
		_later(_sound.bind(SFX_TEAR, DEFAULT_VOLUME), StingLab.timeline(r, RUN_MS).tear)
	var runs := count + 1
	run_seq += 1
	# los logros de la 1.x y, con la física 2.0, los de lo nuevo de la 2.0 (unidad 4p: Lab.BADGES_V2)
	var next := Lab.earn_badges_model(badges, {
		"res": r, "target": target, "inlay": inlay, "claw": claw, "method": method, "strike": strike, "runs": runs,
	}, model)
	if next.size() > badges.size():
		_later(_sound.bind("badge", 0.5), RUN_MS + 150.0)
	badges = next
	count = runs
	var label := Lab.tool_label({ "claw": claw, "geom": geom, "inlay": inlay, "res": r })
	# 2.0: en la piel, la zona si no es la de siempre (el brazo): «Piel · Palma»
	var tgt: String = target.name
	if r.get("zone") != null and r.zone != Zones.DEFAULT_ID:
		tgt += " · " + String(Zones.resolve(r.zone).short)
	var entry := { "id": runs, "tool": label, "tgt": tgt, "verdict": r.verdict, "col": r.vcol }
	notebook = ([entry] + notebook).slice(0, LOG_SIZE)
	changed.emit()


func _finish_run() -> void:
	phase = "done"
	changed.emit()


## Logros del coche en marcha (unidad 4p): los pide su página con lo que enseña (Lab.earn_car_badges: { mode, holds, vKmh,
## hit }) y suenan como los del banco. Solo con la física 2.0, la única que tiene coche en marcha.
func earn_car_badges(ctx: Dictionary) -> void:
	if model != Physics.MODEL_V2:
		return
	var next := Lab.earn_car_badges(badges, ctx)
	if next.size() > badges.size():
		badges = next
		_sound("badge", 0.5)
		changed.emit()


# ── Progreso: logros, cuaderno y ensayos, que la aplicación recuerda entre sesiones ──

## Lo que se guarda en ajustes.cfg (sección [lab]): { badges: [ids en orden], notebook: [entradas], count }.
func progress() -> Dictionary:
	return { "badges": badges.keys(), "notebook": notebook.duplicate(true), "count": count }


## Recupera lo guardado. Lo que no se entienda (un archivo viejo o editado a mano) se descarta sin romper el banco:
## logros que no existen, entradas del cuaderno sin sus campos, un número de ensayos imposible…
func restore_progress(d: Dictionary) -> void:
	var known := {}
	for b: Dictionary in Lab.BADGES + Lab.BADGES_V2:
		known[b.id] = true
	var nb := {}
	var saved_badges: Variant = d.get("badges")
	if saved_badges is Array or saved_badges is PackedStringArray:
		for id: Variant in saved_badges:
			if (id is String or id is StringName) and known.has(String(id)):
				nb[String(id)] = true
	var book: Array = []
	var saved_book: Variant = d.get("notebook")
	if saved_book is Array:
		for e: Variant in saved_book:
			if book.size() >= LOG_SIZE:
				break
			if not (e is Dictionary):
				continue
			var ok: bool = (typeof(e.get("id")) in [TYPE_INT, TYPE_FLOAT]) and e.get("tool") is String and e.get("tgt") is String \
				and e.get("verdict") is String and e.get("col") is String
			# un número de ensayo posible (NaN no pasa) y un color de veredicto (#RRGGBB, el vcol del core)
			ok = ok and float(e.id) >= 1.0 and float(e.id) < 1e9 and Color.html_is_valid(e.col)
			if ok:
				book.append({ "id": int(e.id), "tool": e.tool, "tgt": e.tgt, "verdict": e.verdict, "col": e.col })
	var n: Variant = d.get("count")
	var c := int(n) if typeof(n) in [TYPE_INT, TYPE_FLOAT] and float(n) >= 0.0 and float(n) < 1e9 else 0
	for e: Dictionary in book:
		c = maxi(c, int(e.id))  # el cuaderno no puede tener ensayos que no se han hecho
	badges = nb
	notebook = book
	count = c
	changed.emit()


## «Reiniciar logros y cuaderno»: sin logros, cuaderno vacío y cero ensayos (el ensayo a la vista no se toca).
func reset_progress() -> void:
	badges = {}
	notebook = []
	count = 0
	changed.emit()
