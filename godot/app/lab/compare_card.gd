## Tarjeta · Comparativa (CompareCard de la 1.x): con una garra, todas las garras y colmillos con la misma fuerza
## sobre el mismo material; con un aguijón (2.0), todos los aguijones (solo pican; la fuerza, en mN); con una uña, todas
## las formas con el mismo material de uña (sin incrustación). Cada fila es un compute() del core con esos parámetros y
## el modelo del banco (lab.compute), ordenadas por presión nominal (de mayor a menor, estable como el sort de
## JavaScript); cada fila enseña la presión real, con «(tope)» cuando la nominal pasa de una dureza (BenchTexts, 4n).
## Pulsar una fila elige esa herramienta.
## Las filas se calculan en hilos (WorkerThreadPool.add_group_task, una tarea por fila y prioridad alta) sin parar la
## interfaz: la sección llama a poll() en cada fotograma y las pinta cuando llegan. Cada hilo escribe solo su fila y la
## lista se ordena después, así que el resultado no depende del número de hilos (tests/app/test_lab_ui.gd lo compara
## con el cálculo en serie). La primera vez y al cambiar de familia (uñas, garras o aguijones) se esperan (finish), para
## no enseñar filas de otra familia; refresh_now() de la sección también.
## Los hilos no se quedan con nada que tenga estado (RowsJob): WorkerThreadPool suelta cada tarea en el hilo que la ha
## corrido y después de despertar a quien la espera, así que lo que una tarea retenga puede acabar destruyéndose en ese
## hilo. Antes la tarea era una lambda que capturaba el estado del banco (LabState, con su señal conectada a la sección)
## y, si el hilo principal lo soltaba en ese momento, el estado moría en el hilo de trabajo mientras la sección se
## liberaba en el principal (signal 11). tests/app/test_compare_threads.gd lo vigila.
extends "res://app/common/card.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const Format = preload("res://core/shared/format.gd")
const Js = preload("res://core/shared/js.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Palette = preload("res://app/theme/palette.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ArtView = preload("res://app/common/art_view.gd")
const Bar = preload("res://app/common/bar.gd")
const ContentButton = preload("res://app/common/content_button.gd")
const LabUi = preload("res://app/lab/lab_ui.gd")
## La garra del velocirraptor (2.0) con su dibujo propio; el resto, LabUi.show_claw.
const DinoViews = preload("res://app/lab/dino_views.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
## La presión de cada fila: la real, con «(tope)» si la limita una dureza (unidad 4n).
const BenchTexts = preload("res://core/lab/bench_texts.gd")

var lab: LabState
var art: ArtCache
var intro: Label
var row_buttons: Array[ContentButton] = []
var row_parts: Array = []  # [icono, nombre, veredicto, meta, barra]
var footnote: Label
## Filas calculadas: [{ id, res }] en el orden de la tarjeta.
var rows: Array = []
## ¿Se calculan las filas en hilos? (los tests lo apagan para comparar con el cálculo en serie)
var threaded := true
var _sig := ""
var _rows_family := ""  # familia de las filas que se ven
## Cálculos en marcha, en el orden en que se lanzaron: [{ task, sig, family, jobs, job (RowsJob) }].
var _tasks: Array = []


## Una tanda de filas para los hilos. WorkerThreadPool solo recibe `run` como Callable de método, que es una referencia
## débil (un ObjectID): la tanda, con el estado del banco que la calcula y las filas, la guarda la tarjeta en _tasks y la
## suelta el hilo principal después de esperarla (poll, finish o al liberarse la tarjeta). Así, lo que tiene estado
## siempre muere en el hilo principal, aunque el resto de la interfaz haya soltado ya el estado del banco.
class RowsJob:
	extends RefCounted
	var state: LabState
	var model: String  # el modelo del banco, leído en el hilo principal al lanzar la tanda
	var params: Array  # parámetros de compute() de cada fila
	var out: Array  # resultados de compute(), en el orden de params
	var _lock := Mutex.new()

	func _init(p_state: LabState, p_params: Array) -> void:
		state = p_state
		model = p_state.model
		params = p_params
		out.resize(p_params.size())

	## La fila k (en un hilo de trabajo): solo lee sus parámetros y escribe su hueco.
	func run(k: int) -> void:
		var r: Dictionary = state.compute(params[k], model)
		_lock.lock()
		out[k] = r
		_lock.unlock()


func _init() -> void:
	super("Comparativa por forma")
	intro = Ui.para("", "Body")
	body.add_child(intro)
	var list := Ui.vbox(2)
	for i in maxi(Catalog.CLAWS.size(), Catalog.GEOMS.size()):
		var b := ContentButton.new("RowButton")
		var h := Ui.hbox(12)
		var icon := LabUi.view(Vector2(30, 42))
		h.add_child(icon)
		var col := Ui.vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := Ui.hbox(8)
		var name := Ui.label("", "RowName")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var verdict := Ui.label("", "Small")
		verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		verdict.custom_minimum_size.x = 90.0
		verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(verdict)
		col.add_child(top)
		var meta := Ui.para("", "Small")
		col.add_child(meta)
		var bar := Bar.new(6.0, false)
		bar.duration = 0.4
		col.add_child(bar)
		h.add_child(col)
		b.set_body(h)
		b.tooltip_text = "Usar esta herramienta"
		list.add_child(b)
		row_buttons.append(b)
		row_parts.append([icon, name, verdict, meta, bar])
	body.add_child(list)
	footnote = Ui.para("", "Small")
	body.add_child(footnote)


func setup(p_lab: LabState, p_art: ArtCache) -> void:
	lab = p_lab
	art = p_art
	for i in row_buttons.size():
		row_buttons[i].pressed.connect(_on_row.bind(i))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t: Dictionary in _tasks:
			WorkerThreadPool.wait_for_group_task_completion(t.task)
		_tasks.clear()


func _on_row(i: int) -> void:
	if i >= rows.size():
		return
	var id: String = rows[i].id
	if lab.claw != null:
		if lab.claw.id != id:
			lab.set_claw(Catalog.find_by_id(Catalog.CLAWS, id))
			return
	elif lab.geom.id != id:
		lab.set_geom(Catalog.find_by_id(Catalog.GEOMS, id))
		return
	refresh()


## Familia de la herramienta elegida: "unas", "garras" (garras y colmillos) o "insectos" (los aguijones de la 2.0).
func family() -> String:
	if lab.claw == null:
		return "unas"
	return "insectos" if lab.is_stinger() else "garras"


## Firma de lo que decide las filas (todos los parámetros menos la herramienta que se compara, y el modelo).
func signature() -> String:
	var claw: Variant = lab.claw
	var who: String = "%s:%s" % [family(), lab.inlay.id] if claw != null else "uñas:%s" % lab.base.id
	# 2.0: la zona del cuerpo, el ángulo de ataque pedido y el afilado también cambian las filas (params() los lleva)
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [who, lab.target.id, lab.force, lab.length, lab.passes, lab.type.id, lab.wet,
		lab.method, lab.strike, lab.tear_mode, lab.geom.id if claw != null else "-", lab.model, lab.zone, lab.attack_deg, lab.sharpness]


func rows_stale() -> bool:
	return signature() != _sig


## Lo que se compara: [{ id, i (orden en el catálogo), p (parámetros de compute) }]. Las garras o los aguijones, según
## la familia de la herramienta elegida, o las formas de uña.
func _jobs() -> Array:
	var params: Dictionary = lab.params()
	var out: Array = []
	if lab.claw != null:
		var insects := lab.is_stinger()
		for i in Catalog.CLAWS.size():
			var c: Dictionary = Catalog.CLAWS[i]
			if Insects.is_stinger(c) != insects:
				continue
			var p := params.duplicate()
			p.claw = c
			p.tear = lab.tear_mode
			out.append({ "id": c.id, "i": i, "p": p })
	else:
		for i in Catalog.GEOMS.size():
			var g: Dictionary = Catalog.GEOMS[i]
			var p := params.duplicate()
			p.geom = g
			p.inlay = Catalog.INLAYS[0]
			p.claw = null
			out.append({ "id": g.id, "i": i, "p": p })
	return out


## Recalcula las filas con compute() si han cambiado sus entradas: en hilos (llegan con poll o finish) o en serie.
func update_rows() -> void:
	var sig := signature()
	if sig == _sig:
		return
	_sig = sig
	var jobs := _jobs()
	var fam := family()
	if not threaded or jobs.size() < 2:
		var results: Array = []
		for j: Dictionary in jobs:
			results.append(lab.compute(j.p))
		_apply(fam, jobs, results)
		return
	var job := RowsJob.new(lab, jobs.map(func(j: Dictionary) -> Dictionary: return j.p))
	var task := WorkerThreadPool.add_group_task(job.run, jobs.size(), -1, true, "comparativa del laboratorio")
	_tasks.append({ "task": task, "sig": sig, "family": fam, "jobs": jobs, "job": job })


## Recoge las filas calculadas en hilos que ya han acabado. true si han llegado las de ahora (hay que repintar).
func poll() -> bool:
	var fresh := false
	while not _tasks.is_empty() and WorkerThreadPool.is_group_task_completed(_tasks[0].task):
		fresh = _collect(_tasks.pop_front()) or fresh
	return fresh


## Espera a las filas que se están calculando. true si han llegado las de ahora.
func finish() -> bool:
	var fresh := false
	while not _tasks.is_empty():
		fresh = _collect(_tasks.pop_front()) or fresh
	return fresh


func _collect(t: Dictionary) -> bool:
	WorkerThreadPool.wait_for_group_task_completion(t.task)
	if t.sig != _sig:
		return false  # de unos parámetros que ya han cambiado
	_apply(t.family, t.jobs, t.job.out)
	return true


## Filas ordenadas a partir de los resultados, que llegan en el orden de jobs.
func _apply(fam: String, jobs: Array, results: Array) -> void:
	var list: Array = []
	for k in jobs.size():
		list.append({ "id": jobs[k].id, "i": jobs[k].i, "res": results[k] })
	list.sort_custom(_by_pressure)
	rows = list
	_rows_family = fam


## Orden de la 1.x: presión nominal de mayor a menor; a igualdad, el orden del catálogo (sort estable).
static func _by_pressure(a: Dictionary, b: Dictionary) -> bool:
	var pa: float = a.res.pNominal
	var pb: float = b.res.pNominal
	if pa != pb:
		return pa > pb
	return int(a.i) < int(b.i)


func refresh(defer_rows := false) -> void:
	var fam := family()
	# al cambiar de familia (uñas, garras o aguijones) las filas son otras: nunca se aplaza, y se esperan
	if rows_stale() and (not defer_rows or rows.is_empty() or _rows_family != fam):
		update_rows()
	if rows.is_empty() or _rows_family != fam:
		finish()
	paint()


## Pinta la tarjeta con las filas que hay.
func paint() -> void:
	var claw: Variant = lab.claw
	var inlay: Dictionary = lab.inlay
	var fam := family()
	var unit: String = lab.force_range().unit
	var with_inlay := (" con %s" % inlay.short) if inlay.id != "none" else ""
	match fam:
		"insectos":
			title_label.text = "Comparar aguijones"
			intro.text = "Misma fuerza (%s) sobre %s%s. Todos pican: cambian la punta (R), el grosor del estilete (cuándo pandea), lo que entra y las púas." % [
				Format.fmt_force(lab.force, unit), lab.target.name, with_inlay]
			footnote.text = "barra = severidad · pulsa una fila para usar ese aguijón"
		"garras":
			title_label.text = "Comparar garras y colmillos"
			intro.text = "Misma fuerza (%s) sobre %s%s. Queratina (Mohs ~2,5-3) y dentina: lo que cambia es el afilado (R, α), la curvatura y la gema de la punta." % [
				Format.fmt_force(lab.force, unit), lab.target.name, with_inlay]
			footnote.text = "barra = severidad · %s · pulsa una fila para usar esa herramienta" % BenchTexts.COMPARE_PRESSURE_NOTE
		_:
			title_label.text = "Comparativa por forma"
			intro.text = "Misma fuerza (%s) y material (%s) sobre %s. Solo cambia la forma → el área de la punta → la presión, el desgaste y el rayado. (Sin incrustación, para aislar la forma.)" % [
				Format.fmt_force(lab.force, unit), lab.base.name, lab.target.name]
			footnote.text = "barra = severidad del surco · %s · pulsa una fila para usar esa forma" % BenchTexts.COMPARE_PRESSURE_NOTE
	accessibility_name = title_label.text
	for i in row_buttons.size():
		var b := row_buttons[i]
		b.visible = i < rows.size()
		if not b.visible:
			continue
		var row: Dictionary = rows[i]
		var r: Dictionary = row.res
		var parts: Array = row_parts[i]
		var vcol := Palette.color(r.vcol)
		var depth := (" · " + Format.fmt_depth(r.depthUm)) if r.depthUm > 0.1 else ""
		if claw != null:
			var c: Dictionary = Catalog.find_by_id(Catalog.CLAWS, row.id)
			DinoViews.show_claw(parts[0], art, c, inlay, "cmp", r.vcol)
			(parts[1] as Label).text = String(c.name)
			if r.get("sting") is Dictionary:
				(parts[3] as Label).text = sting_meta(r) + depth
			else:
				(parts[3] as Label).text = "%s · α %s° · %s%s" % [DinoLab.tip_size(r), Ui.num(r.alphaDeg), BenchTexts.compare_pressure(r), depth]
			b.set_on(c.id == claw.id)
		else:
			var g: Dictionary = Catalog.find_by_id(Catalog.GEOMS, row.id)
			LabUi.show_nail(parts[0], art, g, lab.base, Catalog.INLAYS[0], false, "cmp")
			(parts[1] as Label).text = String(g.name)
			(parts[3] as Label).text = "%s mm² · %s · desgaste %s%s" % [Js.to_fixed(r.area, 2), BenchTexts.compare_pressure(r),
				Js.template_str(r.get("wearIdx")), depth]
			b.set_on(g.id == lab.geom.id)
		(parts[2] as Label).text = String(r.verdict)
		Ui.set_color(parts[2], vcol)
		(parts[4] as Bar).set_level(maxf(4.0, float(r.sev) * 100.0) / 100.0, vcol)
		b.accessibility_name = "%s: %s" % [(parts[1] as Label).text, r.verdict]


## Línea de un aguijón en la comparativa: en la piel, con cuánto perfora y a cuánto pandea; en un sólido, la relación de
## durezas a la escala de la punta y el pandeo.
static func sting_meta(r: Dictionary) -> String:
	var s: Dictionary = r.sting
	if s.fPunctureN != null:
		return "perfora con ~%s · pandea a ~%s" % [StingLab.fmt_force(s.fPunctureN), StingLab.fmt_force(s.fBuckleN)]
	return "r %s en la punta · pandea a ~%s" % [Js.to_fixed(s.hardnessRatio, 2), StingLab.fmt_force(s.fBuckleN)]
