## Taller industrial · demo guionizada de la fresadora y el taladro, para las capturas con Movie Maker:
##   1 · fresadora: fresa de planear centrada, fresa de mango en concordancia y en oposición;
##   2 · taladro: broca de HSS en C45E a ×5 (baja, corta y sube) y la misma en aluminio con la punta recomendada.
## Captura (desde la raíz del repositorio):
##   npm run godot:capture -- res://app/taller/mill3d/demo_fresado_taladro.tscn --frames=150 --out=<carpeta>
## Teléfono:  … -- --ancho=390 --alto=844 (la sección va en un SubViewport de ese tamaño, centrado, con el guion al lado)
## Una parte: … -- --parte=fresadora|taladro · Vista 3D: … -- --vista=maquina [--camara=detalle|frontal|superior|general]
## El tiempo es la suma de los delta (Movie Maker los da fijos), así que cada captura sale igual. No guarda ajustes.
## La demo corre dentro del árbol (los tests no): tras cada cambio comprueba con assert que la página no ha cambiado el
## estado (un deslizador que recorta su valor al cambiar de recorrido emite value_changed) y que enseña el resultado del
## modelo. En depuración, un assert que falla sale como «SCRIPT ERROR» y hace fallar la captura.
extends Control

const SECTION := preload("res://app/taller/taller_section.tscn")
const Style = preload("res://app/taller/ui/style.gd")
const Cutting = preload("res://core/taller/cutting.gd")

const CAPTIONS := {
	"fresadora": "Fresadora · fresa de planear centrada, fresa de mango en concordancia y en oposición",
	"taladro": "Taladro · broca de HSS en C45E y en aluminio con la punta recomendada",
}

var section: Control
var md = null
var part := "todo"
var vista := "esquema"
var camara := ""
var phone := false
var phone_size := Vector2i(390, 844)
var caption: Label
var _queue: Array = []
var _step := 0
var _t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parte="):
			part = a.substr(8)
		elif a.begins_with("--vista="):
			vista = a.substr(8)
		elif a.begins_with("--camara="):
			camara = a.substr(9)
		elif a.begins_with("--ancho="):
			phone = true
			phone_size.x = int(a.substr(8))
		elif a.begins_with("--alto="):
			phone = true
			phone_size.y = int(a.substr(7))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	section = SECTION.instantiate()
	if phone:
		_build_phone()
	else:
		var bg := ColorRect.new()
		bg.color = Style.c("bg")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		add_child(section)
	md = section.get("md")
	_queue = ["fresadora", "taladro"] if part == "todo" else [part]
	_start(_queue.pop_front())


func _build_phone() -> void:
	var bg := ColorRect.new()
	bg.color = Style.c("bg2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(phone_size)
	box.size = Vector2(phone_size)
	box.position = Vector2(floorf((1240.0 - phone_size.x) / 2.0), floorf((880.0 - phone_size.y) / 2.0))
	add_child(box)
	var vp := SubViewport.new()
	vp.size = phone_size
	box.add_child(vp)
	var pbg := ColorRect.new()
	pbg.color = Style.c("bg")
	pbg.size = Vector2(phone_size)
	vp.add_child(pbg)
	vp.add_child(section)
	caption = Style.label("", "TallerTitulo", true)
	caption.theme = Style.theme()
	caption.position = Vector2(24, 60)
	caption.size = Vector2(box.position.x - 48.0, 300)
	caption.custom_minimum_size.x = box.position.x - 48.0
	add_child(caption)


func _start(p: String) -> void:
	part = p
	_step = 0
	_t = 0.0
	section.call("select_machine", p)
	var pg: Control = section.call("page", p)
	pg.call("set_view", vista)
	if camara != "":
		pg.call("set_cam_view", camara)
	if caption != null:
		caption.text = CAPTIONS.get(p, "")


func _process(delta: float) -> void:
	_t += delta
	match part:
		"fresadora":
			_fresadora()
		"taladro":
			_taladro()


## Los resultados del estado son los del modelo con sus entradas (nada los ha cambiado por detrás).
func _check_current() -> void:
	assert(var_to_str(md.mill_result) == var_to_str(Cutting.milling(md.mill_request())), "fresado desfasado")
	assert(var_to_str(md.drill_result) == var_to_str(Cutting.drilling(md.drill_request())), "taladrado desfasado")


func _next_part() -> void:
	if _queue.is_empty():
		part = "fin"
		return
	_start(_queue.pop_front())


func _fresadora() -> void:
	match _step:
		0:
			md.set_mill("tool_type", "planear")
			md.set_mill("position", "centrada")
			md.set_anim_speed("mill", 5.0)
			_step = 1
		1:
			if _t >= 1.6:
				md.set_mill("tool_type", "mango")  # en concordancia, su ensayo de partida
				md.set_anim_speed("mill", 5.0)
				assert(float(md.mill["ae_mm"]) == 4.0, "la página cambió ae al rehacer los deslizadores")
				_check_current()
				_step = 2
		2:
			if _t >= 3.2:
				md.set_mill("position", "oposicion")
				_check_current()
				_step = 3
		3:
			if _t >= 4.8:
				_next_part()


func _taladro() -> void:
	match _step:
		0:
			md.set_drill("work_id", "c45e")
			md.set_anim_speed("drill", 5.0)
			md.reset_anim("drill")
			_step = 1
		1:
			if _t >= 4.4:  # a ×5, el primer agujero ya está hecho y la broca fuera
				md.set_drill("work_id", "al6082_t6")
				md.set_drill("point_angle_deg", 140.0)
				md.reset_anim("drill")
				assert(float(md.drill["point_angle_deg"]) == 140.0, "la página cambió el ángulo de punta")
				_check_current()
				_step = 2
		2:
			if _t >= 8.6:
				_next_part()
