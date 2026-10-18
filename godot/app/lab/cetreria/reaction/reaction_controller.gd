## Cetrería · la reacción del animal estresado (unidad 5t-B): el plano del zarpazo contra la cámara y la lente rayada.
## Solo pinta lo que decide el motor (la calle C): cuándo se revuelve (ClawCareState.view().animal.reaction: seq, warning,
## kind, intensity, lens) y lo que le pasa a la lente garra a garra (lens: ClawCareReaction.lens_hit). El guion de cada
## especie está en docs/fase2/5tb-guion.md y sus claves en reaction_keys.gd.
##
## - Aviso (warning): la postura de amenaza de su especie, sin golpe y sin cambiar de cámara (la pata se tensa: se ve también
##   de cerca); su voz, baja.
## - Reacción (seq nuevo): corte al plano del zarpazo, anticipación, golpe (su duración real sale de core/lab/care_strike.gd,
##   enseñada a cámara lenta con su rótulo), contacto según el resultado (rebota si no raya, arrastra si raya, se frena y se
##   queda si desgarra o raja), recuperación y vuelta a la cámara del jugador. Temblor, destello y sonido en el fotograma
##   del impacto; los rayones se dibujan a la vez que avanzan las garras (lens_layer.gd) y, al acabar el contacto, la señal
##   lens_record(seq, trazos) los lleva al motor (ClawCareState.lens_record), que los guarda en la lente.
## - Con una intensidad muy baja (el animal casi no puede moverse), solo un tirón de la pata dormida.
## - Si una garra se desconcha (chips), esquirlas deterministas (rng.gd) del color de la garra.
## Determinista: todo sale de advance(dt) (el reloj de la escena) y de semillas. En cada fotograma no se crea nada.
extends Node

signal lens_record(seq: int, traces: Dictionary)
signal sfx(id: String, volume: float, pitch: float)
signal phase_changed(phase: String)

const Keys = preload("res://app/lab/cetreria/reaction/reaction_keys.gd")
const ReactionRig = preload("res://app/lab/cetreria/reaction/reaction_rig.gd")
const LensLayer = preload("res://app/lab/cetreria/reaction/lens_layer.gd")
const AnimBird = preload("res://app/lab/cetreria/reaction/anim_bird.gd")
const AnimTiger = preload("res://app/lab/cetreria/reaction/anim_tiger.gd")
const AnimBear = preload("res://app/lab/cetreria/reaction/anim_bear.gd")
const AnimRaptor = preload("res://app/lab/cetreria/reaction/anim_raptor.gd")
const CareStrike = preload("res://core/lab/care_strike.gd")
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const CareReactionText = preload("res://core/lab/care_reaction_text.gd")
const Rng = preload("res://core/shared/rng.gd")
const Js = preload("res://core/shared/js.gd")
const FONT = preload("res://assets/fonts/space-mono-latin-700-normal.woff2")

## El aviso crece en WARN_IN s y se apaga en WARN_OUT s.
const WARN_IN := 0.4
const WARN_OUT := 0.8
## Temblor de la cámara en el impacto: el giro máximo (rad, con intensidad 1) y lo que tarda en apagarse (s). Dibujo.
const SHAKE_RAD := 0.011
const SHAKE_TAU := 0.08
## Esquirlas de la garra que se desconcha: cuántas como mucho, lo que duran (s) y la gravedad (m/s²).
const SHARDS := 24
const SHARD_LIFE := 1.3
const GRAVITY := 9.81
## Lo que se aparta la pata al rebotar (fracción de la distancia de la lente) y el arco del golpe (fracción del recorrido).
const REBOUND_K := 0.18
const ARC_K := 0.35
## Hasta cuántas veces su largo de reposo llega el segmento del miembro (el estirón suave: estirar y encoger).
const REACH_K := 1.18
## Lo que pueden apartarse del centro las garras al girar el plano hacia la cabeza (fracción de la mitad del campo, dibujo).
const AIM_MAX := 0.45
## El tramo más corto que se dibuja de un rayón (fracción del contacto, dibujo: que se vea).
const MARK_MIN := 0.2
## Cómo se ven en la lente las marcas de cada tipo de garra (dibujo, para que se lean de un vistazo): la garra del golpe
## (Reaction.IMPACT_FINGER) arrastra de verdad (su punta proyectada en la pantalla) y las demás la siguen a su lado, separadas
## lo que separa sus dedos (spacingMm del motor, a la distancia de la lente): «front» van paralelas a ella (el orden, el de la
## mano) y «back» (el pulgar de las rapaces; en las nocturnas, también el IV, que se vuelve hacia atrás) salen de delante y
## van a su encuentro, como al cerrar el pie. En el velocirraptor, la hoz delante y el III y el IV a un lado (offsets).
const PATTERNS := {
	"rapaz": { "front": ["II", "III", "IV"], "back": ["I"] },
	"nocturna": { "front": ["II", "III"], "back": ["I", "IV"] },
	"felino": { "front": ["II", "III", "IV", "V"], "back": [] },
	"oso": { "front": ["I", "II", "III", "IV", "V"], "back": [] },
	"dinosaurio": { "front": ["II", "III", "IV"], "back": [], "offsets": [0.0, 1.3, 2.4] },
}
## Las del otro grupo: si no se ven sus puntas, a cuántas separaciones por delante empiezan; y lo que se cierran hacia la del
## golpe al arrastrar (fracción del camino hasta ella).
const BACK_AHEAD := 2.2
const BACK_K := 0.45
## La separación en pantalla, entre estos tantos por uno del alto (que se vea y que quepa).
const SPACING_MIN := 0.035
const SPACING_MAX := 0.12
## El margen de la vista que dejan libre las marcas (normalizado, dibujo).
const FIT_MARGIN := 0.08
## El volumen de la voz del animal y del golpe en la lente (0-1, dibujo de sonido): con los picos de sfx_reaction.gd (≤ 0,66),
## la voz y el golpe a la vez no pasan de ~0,8 (margen; nada satura).
const VOL_VOICE := 0.6
const VOL_IMPACT := 0.6
## La pausa para calmarlo (dibujo): lo que tarda en entrar y salir (s), la penumbra (alfa del velo en las rapaces), lo que
## se frena la respiración (factor) y la postura tranquila (los canales de reaction_keys.gd: los ojos entornados, la cabeza
## apoyada; en las aves, la membrana nictitante a medias).
const REST_IN := 1.2
const REST_OUT := 0.8
const REST_DIM := 0.32
const REST_BREATH := 0.55
const REST_POSE := {
	"ave": { "eye": 0.35, "head_pitch": -0.04, "nict": 0.35 },
	"grande": { "eye": 0.45, "head_pitch": -0.04 },
}

var lens: LensLayer
var shake_enabled := true
## La lente la pone otro (la demo, con su propia lente del motor): la de la vista del estado no se aplica.
var external_lens := false
var mobile := false
## Lo que el rótulo de la cámara lenta no debe tapar (el medidor «Forma de la garra» de la escena, abajo a la izquierda): si a
## su derecha queda sitio, va allí; si no, encima de él. null: de lado a lado, abajo.
var caption_avoid: Control = null
var phase := "idle"
var info_last := {}

var _r: ReactionRig = null
var _paw_rig: Dictionary = {}
var _setup: Dictionary = {}
var _model := ""
var _last_seq := -1
var _queued: Dictionary = {}
var _ev: Dictionary = {}
var _k: Dictionary = {}
var _kind := ""
var _var: Dictionary = {}
var _hit: Dictionary = {}
var _t := 0.0
var _clock := 0.0
var _since := 99.0
var _durs := {}
var _strike := {}
var _slowmo := 1.0
var _warn := 0.0
var _warning := false
## El rótulo de la cámara lenta, a la derecha del medidor solo si le quedan estos px; y el campo más abierto del teléfono.
const CAPTION_MIN_W := 300.0
const PORTRAIT_FOV_MAX := 85.0
## El margen de la vista en que acaba el arrastre y lo menos que se acorta.
const DRAG_MARGIN := 0.1
const DRAG_MIN := 0.35
## Lo que la cámara del teléfono corrige en cada fotograma hacia la garra del golpe (0-1).
const YAW_FOLLOW := 0.35
var _cam: Camera3D
var _cam_xf := Transform3D.IDENTITY
var _cam_fov := 50.0
## Ancho entre alto de la vista del plano (para el recorrido del zarpazo).
var _aspect := 1.6
## Lo que se acorta el arrastre para acabar dentro de la vista (−1: aún sin calcular; se calcula al tocar la lente).
var _drag_k := -1.0
## El giro de lado de la cámara del plano en una vista más alta que ancha (rad): sigue a la garra del golpe hasta que toca.
var _yaw := 0.0
var _cam_lens := 0.2
var _p_cock := Transform3D.IDENTITY
var _p_imp := Transform3D.IDENTITY
var _p_end := Transform3D.IDENTITY
var _fingers: Array = []
var _live_index := {}
var _traces := {}
var _contact := "rebote"
var _impacted := false
var _recorded := false
var _shake_t := -1.0
var _shake_seed := 0.0
var _caption_layer: CanvasLayer
var _caption: Label
var _shard_mmi: MultiMeshInstance3D
var _shards: Array = []
var _shard_t := -1.0
var _twitch := -1.0
var _reach_m := 0.0
## El dedo que llega primero (Reaction.IMPACT_FINGER) y, de cada garra que raya, la parte del contacto en que aprieta lo
## bastante para marcar (la del medio: lengthMm / SWIPE_MM del motor) → { dedo: [u0, u1] }.
var _lead := ""
## El porqué de que el zarpazo no haya rayado la lente (CareReactionText), para el rótulo de después; "" si raya.
var _lens_text := ""
## La pausa para calmarlo (view().animal.resting, la 5t-A): la postura tranquila (los ojos entornados, la cabeza en la mesa),
## la luz más baja y la respiración más lenta, con su peso (0-1) que entra y sale despacio.
var resting := false
var _rest_w := 0.0
var _dim: ColorRect
var _windows := {}
var _marks := {}
## Dónde tocó la garra del golpe (normalizado): de ahí sale el dibujo de las demás (PATTERNS).
var _lead_start := Vector2(-1.0, -1.0)
## El centro de las puntas del otro grupo en el impacto (en píxeles; las de delante de las rapaces).
var _other_center := Vector2(-1.0, -1.0)
## Lo que se mueve el dibujo de las marcas para que quepa en la vista (normalizado; _fit_shift).
var _pat_shift := Vector2.ZERO
## La dirección del arrastre de verdad en la pantalla (cero hasta que la garra del golpe se mueve).
var _dir_lock := Vector2.ZERO


func _init() -> void:
	name = "ReaccionDelAnimal"
	lens = LensLayer.new()
	add_child(lens)
	_caption_layer = CanvasLayer.new()
	_caption_layer.name = "RotuloDeLaReaccion"
	_caption_layer.layer = 3
	add_child(_caption_layer)
	_caption = Label.new()
	_caption.add_theme_font_override("font", FONT)
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_caption.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.07, 0.9))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -54.0
	_caption.offset_bottom = -30.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	_caption_layer.add_child(_caption)
	# la luz baja de la pausa (como el capirote o la penumbra que calman a una rapaz): un velo oscuro sobre la vista
	var dim_layer := CanvasLayer.new()
	dim_layer.name = "PenumbraDeLaPausa"
	dim_layer.layer = 1
	add_child(dim_layer)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0.02, 0.02, 0.05, 0.0)
	_dim.visible = false
	dim_layer.add_child(_dim)
	_shard_mmi = MultiMeshInstance3D.new()
	_shard_mmi.name = "Esquirlas"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _shard_mesh()
	mm.instance_count = SHARDS
	mm.visible_instance_count = 0
	_shard_mmi.multimesh = mm
	_shard_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shard_mmi)


# ─────────────────────────────── API ───────────────────────────────

## El animal de la escena (el rig de care_animal.gd): al cambiar de animal, se corta lo que estuviera en marcha.
func bind(paw_rig: Dictionary) -> void:
	if _r != null and _r.valid():
		_r.reset()
	_paw_rig = paw_rig
	_r = null
	_set_phase("idle")
	_warn = 0.0


## La cámara que mueve el plano (la de la escena).
func set_camera(cam: Camera3D) -> void:
	_cam = cam


## La vista del estado (ClawCareState.view()): la reacción del animal y la lente puesta.
func show_view(v: Dictionary) -> void:
	_setup = v.get("setup", {})
	_model = String(v.get("model", ""))
	var lv: Variant = v.get("lens")
	if not external_lens and lv is Dictionary and not (lv as Dictionary).is_empty():
		lens.apply_damage(lv)
	var an: Variant = v.get("animal")
	var ev: Dictionary = {}
	if an is Dictionary:
		ev = (an as Dictionary).get("reaction", {})
		resting = bool((an as Dictionary).get("resting", false))
	trigger_event(ev)


## Un evento de reacción (el contrato con la calle C, o la demo): { seq, warning, kind, intensity, lens }. El primero que llega
## solo fija el seq de partida (una reacción vieja no se repite al abrir la página).
func trigger_event(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	var seq := int(ev.get("seq", 0))
	_warning = bool(ev.get("warning", false))
	if _last_seq < 0:
		_last_seq = seq
		return
	if seq > _last_seq:
		_last_seq = seq
		if phase == "idle" and _since >= Keys.MIN_GAP_S:
			_start(ev)
		else:
			_queued = ev.duplicate(true)


## Lanza ya una reacción (la demo y los tests): como si el motor hubiera subido el seq.
func play(ev: Dictionary) -> void:
	_last_seq = int(ev.get("seq", _last_seq + 1))
	_since = 99.0
	_start(ev)


func is_playing() -> bool:
	return phase != "idle"


## Las fases y el plano, para los tests y la demo.
func info() -> Dictionary:
	return {
		"phase": phase, "t": _t, "kind": _kind, "variant": String(_var.get("id", "")), "contact": _contact, "warn": _warn,
		"strike_s": float(_durs.get("S", 0.0)), "strike_real_s": float(_strike.get("tS", 0.0)), "slowmo": _slowmo,
		"traces": _traces.duplicate(true), "fingers": _fingers.duplicate(true), "impacted": _impacted, "recorded": _recorded,
		"shards": _shard_mmi.multimesh.visible_instance_count, "caption": _caption.text if _caption.visible else "",
		"seq": _last_seq, "twitch": _twitch >= 0.0, "lens": lens.info(), "reach_m": _reach_m, "rest": _rest_w, "dim": _dim.color.a,
	}


## La duración del plano entero (s): del corte a que la cámara vuelve.
func total_s() -> float:
	return Keys.key_time("R", 1.0, _durs) + Keys.HOLD_S + Keys.BACK_S


func advance(dt: float) -> void:
	_clock += dt
	_since += dt
	lens.advance(dt)
	_advance_shards(dt)
	if _r == null and not _paw_rig.is_empty():
		_bind_rig()
	if _r == null or not _r.valid():
		return
	if _twitch >= 0.0:
		_advance_twitch(dt)
		return
	if phase == "idle":
		_advance_rest(dt)
		_advance_warning(dt)
		if not _queued.is_empty() and _since >= Keys.MIN_GAP_S:
			var q := _queued
			_queued = {}
			_start(q)
		return
	_t += dt
	_animate()


## La cámara del plano manda mientras dura (con el temblor del impacto); al final vuelve con suavidad a la del jugador. La
## llama la escena después de mover su cámara orbital y antes de su luz.
func camera_override(cam: Camera3D) -> void:
	if phase == "idle" or _cam_xf == Transform3D.IDENTITY:
		return
	var end_r := Keys.key_time("R", 1.0, _durs) + Keys.HOLD_S
	var xf := _cam_xf
	var back_u := 0.0
	if _t > end_r:
		var u := clampf((_t - end_r) / Keys.BACK_S, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		back_u = u
		var orbit := cam.global_transform
		xf = Transform3D(_cam_xf.basis.slerp(orbit.basis.orthonormalized(), u), _cam_xf.origin.lerp(orbit.origin, u))
		cam.fov = lerpf(_cam_fov, cam.fov, u)
	else:
		cam.fov = _cam_fov
		cam.near = minf(cam.near, 0.01)
	# en una vista más alta que ancha (el teléfono), la cámara gira de lado siguiendo a la garra del golpe hasta que toca la
	# lente (y luego se queda): la mano del oso es más ancha que lo que se ve de lado y esa garra, con sus rayones, quedaba en
	# el borde
	if _aspect < 1.0 and _r != null:
		if not _impacted:
			var lt: Variant = _r.tip_world(_lead)
			if lt != null:
				var lc := (Transform3D(Basis(xf.basis.y.normalized(), _yaw) * xf.basis, xf.origin)).affine_inverse() * (lt as Vector3)
				if lc.z < -1e-4:
					_yaw += atan2(-lc.x, -lc.z) * YAW_FOLLOW
		xf.basis = Basis(xf.basis.y.normalized(), _yaw * (1.0 - back_u)) * xf.basis
	if shake_enabled and _shake_t >= 0.0:
		var a := SHAKE_RAD * float(_ev.get("intensity", 0.6)) * exp(-(_t - _shake_t) / SHAKE_TAU)
		if a > 1e-5:
			var rx := a * sin(_t * 97.0 + _shake_seed)
			var ry := a * sin(_t * 131.0 + 2.0 * _shake_seed)
			xf.basis = xf.basis * Basis(Vector3.RIGHT, rx) * Basis(Vector3.UP, ry)
	cam.global_transform = xf


# ─────────────────────────────── por dentro ───────────────────────────────

func _bind_rig() -> void:
	var animal := String(_setup.get("animal", (_paw_rig.get("animal", "rapaz"))))
	var claw := String(_setup.get("claw", ""))
	var kind := _kind_of(animal, claw)
	_r = ReactionRig.new(_paw_rig, kind, String(Keys.kind(kind).paw))
	if not _r.valid():
		_r = null


static func _kind_of(animal: String, claw: String) -> String:
	match animal:
		"tigre":
			return "felino"
		"oso":
			return "oso"
		"velociraptor":
			return "dinosaurio"
	return "nocturna" if claw in ["buho", "lechuza"] else "rapaz"


func _set_phase(p: String) -> void:
	if p != phase:
		phase = p
		phase_changed.emit(p)


func _start(ev: Dictionary) -> void:
	if _r == null and not _paw_rig.is_empty():
		_bind_rig()
	if _r == null:
		return
	_ev = ev.duplicate(true)
	_since = 0.0
	_kind = String(ev.get("kind", _r.kind))
	if not Keys.KINDS.has(_kind):
		_kind = _r.kind
	_k = Keys.kind(_kind)
	if float(ev.get("intensity", 1.0)) < Keys.TWITCH_INTENSITY:
		_twitch = 0.0
		return
	var rng := Rng.new(Rng.seed_of("reaccion|%s|%d" % [_kind, int(ev.get("seq", 0))]))
	var vars: Array = _k.variants
	_var = vars[mini(int(rng.next() * float(vars.size())), vars.size() - 1)]
	_shake_seed = rng.next() * 10.0
	_hit = ev.get("lens", {})
	_lens_text = CareReactionText.no_scratch(_hit)
	_fingers = []
	for c: Variant in _hit.get("claws", []):
		if c is Dictionary and String((c as Dictionary).get("outcome", "nada")) != "nada":
			_fingers.append((c as Dictionary).duplicate(true))
	_traces = {}
	_marks = {}
	_live_index = {}
	_windows = _mark_windows(_fingers, String(Reaction.IMPACT_FINGER.get(_kind, "")))
	_lead_start = Vector2(-1.0, -1.0)
	_other_center = Vector2(-1.0, -1.0)
	_dir_lock = Vector2.ZERO
	_impacted = false
	_recorded = false
	_shake_t = -1.0
	_r.force_claws_visible()
	_plan()
	_t = 0.0
	_set_phase("corte")
	# la rapaz nocturna ataca en silencio (sus plumas no hacen ruido; el chasquido del pico y el bufido son del aviso)
	if _kind != "nocturna":
		sfx.emit(_voice_id(), VOL_VOICE, 1.0)


## El plano: la cámara, la pose recogida, la del impacto y las duraciones (el golpe, de la física).
func _plan() -> void:
	var cam: Dictionary = _k.cam
	var parent_xf := (_r.root.get_parent() as Node3D).global_transform * _r.root_rest
	var ex := parent_xf.basis.x.normalized()
	var ey := parent_xf.basis.y.normalized()
	var ez := parent_xf.basis.z.normalized()
	var rest_w := _r.paw_rest_world()
	var hc: Vector3 = _r.head.global_position if _r.head != null else rest_w.origin - ex * 0.3 - ez * 0.4
	var vsz := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640.0, 400.0)
	_cam_fov = portrait_fov(float(cam.fov) + (8.0 if mobile else 0.0), vsz)
	_aspect = vsz.x / maxf(vsz.y, 1.0)
	_drag_k = -1.0
	_yaw = 0.0
	_cam_lens = float(cam.lens)
	# la pose recogida (la anticipación): la pata atrás, arriba y con los dedos levantados
	var ck: Dictionary = _k.cock
	_p_cock = Transform3D(Basis(ez, float(ck.ang)) * rest_w.basis, rest_w.origin - ex * float(ck.back) + ey * float(ck.up))
	# la del impacto: la mano o el pie girado en el talón o en el codo (lo que alcanza el miembro), con la planta hacia fuera
	# de la mesa y hacia arriba, donde se pone la cámara; la variante lo apunta un poco más a un lado o más arriba
	var at: Vector2 = _var.get("at", Vector2(0.5, 0.5))
	var n_out := (ex * float(cam.out) + ey * float(cam.up) - ez * float(cam.side)).normalized()
	var up_ref := (ey - n_out * ey.dot(n_out)).normalized()
	var side_ref := n_out.cross(up_ref).normalized()
	n_out = (n_out + side_ref * (at.x - 0.5) * 0.8 - up_ref * (at.y - 0.5) * 0.8).normalized()
	up_ref = (ey - n_out * ey.dot(n_out)).normalized()
	side_ref = n_out.cross(up_ref).normalized()
	var toe := float(_var.get("toe", 0.0))
	var y_w := -n_out
	var x_w := (up_ref * cos(toe) + side_ref * sin(toe)).normalized()
	var imp_b := Basis(x_w, y_w, x_w.cross(y_w)).orthonormalized()
	var heel := rest_w * _r.anchor_local
	var imp := Transform3D(imp_b, heel + ex * float(ck.thrust) + ey * float(ck.lift) - imp_b * _r.anchor_local)
	# las garras que tocan (y la que llega primero: el dedo del golpe del motor, Reaction.IMPACT_FINGER)
	var names: Array = []
	for c: Dictionary in _fingers:
		names.append(String(c.finger))
	if names.is_empty():
		names = (Reaction.FINGERS.get(_kind, ["I", "II", "III", "IV", "V"]) as Array).duplicate()
	_lead = String(Reaction.IMPACT_FINGER.get(_kind, ""))
	var tips := _r.tips_local(names)
	var cen := Vector3.ZERO
	for f: String in tips:
		cen += (tips[f] as Vector3) / float(tips.size())
	# el dedo del golpe por delante: el pie o la mano gira alrededor del centro de las puntas hasta que esa garra es la que
	# llega antes a la lente (el I de las rapaces, el III del tigre y del oso, la hoz del velocirraptor)
	var lead_tips := _r.tips_local([_lead])
	if lead_tips.has(_lead) and tips.size() > 1:
		var r_w := imp.basis * ((lead_tips[_lead] as Vector3) - cen)
		var axis := r_w.cross(n_out)
		if axis.length() > 1e-6:
			var rot := Basis(axis.normalized(), float(_k.get("lead", 0.2)))
			var c0 := imp * cen
			imp = Transform3D(rot * imp.basis, c0 + rot * (imp.origin - c0))
	# la mano algo ladeada (tilt, rad), para que las uñas del tigre se vean de lado y no de punta
	if absf(float(_k.get("tilt", 0.0))) > 1e-6:
		var rt := Basis(side_ref, float(_k.tilt))
		var c1 := imp * cen
		imp = Transform3D(rt * imp.basis, c1 + rt * (imp.origin - c1))
	var reach := _reach_excess(imp)
	_reach_m = reach.length()
	imp.origin -= reach
	_p_imp = imp
	# la cámara: delante de las garras, a lo largo de la planta, mirando hacia la cabeza (al fondo); la lente, en sus puntas
	var c_w := imp * cen
	var pos := c_w + n_out * (_cam_lens * 1.3)
	# mira a las garras, girada hacia la cabeza una fracción del ángulo entre las dos, sin que las garras se vayan del centro
	# (como mucho AIM_MAX de la mitad del campo; al acercar la cámara a la lente, el ángulo crece hasta 1,3 veces)
	var d_tip := (c_w - pos).normalized()
	var d_head := (hc - pos).normalized()
	var ang := d_tip.angle_to(d_head)
	var aim := d_tip
	if ang > 1e-4:
		# el tope, con el medio campo más estrecho (el de lado en el teléfono): si no, las garras quedaban en el borde
		var half := atan(tan(deg_to_rad(_cam_fov) * 0.5) * minf(_aspect, 1.0))
		var off := minf(float(cam.toward_head) * ang, AIM_MAX * half / 1.3)
		aim = d_tip.slerp(d_head, off / ang)
	_cam_xf = Transform3D(Basis.looking_at(aim, Vector3.UP), pos)
	var min_d := INF
	for f: String in tips:
		min_d = minf(min_d, -(_cam_xf.affine_inverse() * (imp * (tips[f] as Vector3))).z)
	if min_d < INF:
		_cam_xf.origin -= _cam_xf.basis.z * (min_d - _cam_lens)
	# el golpe: su duración real (trabajo y energía, core) y la cámara lenta que lo enseña
	var travel := _p_cock.origin.distance_to(_p_imp.origin)
	_strike = CareStrike.strike(String(_setup.get("claw", "aguila")), String(_setup.get("inlay", "none")), travel, maxi(tips.size(), 1))
	var t_real := float(_strike.get("tClawS", 0.08) if bool(_strike.get("appreciable", false)) else _strike.get("tS", 0.08)) if bool(_strike.get("ok", false)) else 0.08
	_slowmo = Keys.slowmo_for(t_real)
	_contact = _contact_mode()
	var a_s := float(_k.a_s) * (1.25 if bool(_var.get("feint", false)) else 1.0)
	_durs = { "A": a_s, "S": t_real / _slowmo, "C": float(Keys.CONTACT_S[_contact]), "R": float(_k.r_s) }


## Lo que pasa del alcance del miembro la pose de impacto imp (mundo): el vector que hay que acercarla a la rodilla o al
## hombro (cero si llega). El segmento llega hasta REACH_K veces su largo de reposo.
func _reach_excess(imp: Transform3D) -> Vector3:
	var parent_xf := (_r.root.get_parent() as Node3D).global_transform * _r.root_rest
	for k: String in ["thigh", "arm"]:
		var s: Dictionary = _r.spec.get(k, {})
		if s.is_empty():
			continue
		var p: Vector3 = parent_xf * (s.pivot as Vector3)
		var e0: Vector3 = parent_xf * (s.get("heel", s.get("elbow", _r.paw_rest * _r.anchor_local)) as Vector3)
		var l0 := p.distance_to(e0)
		var heel := imp * _r.anchor_local
		var d := heel.distance_to(p)
		if d > l0 * REACH_K:
			return (heel - p).normalized() * (d - l0 * REACH_K)
	return Vector3.ZERO


func _contact_mode() -> String:
	var mode := "rebote"
	for c: Dictionary in _fingers:
		var o := String(c.get("outcome", ""))
		if o in ["desgarro", "grieta"]:
			return "frenazo"
		if bool(c.get("scratched", false)) or o in ["rayon", "rayon_hondo"]:
			mode = "arrastre"
	return mode


func _animate() -> void:
	var tA := Keys.CUT_S
	var tS := Keys.key_time("S", 0.0, _durs)
	var tC := Keys.key_time("C", 0.0, _durs)
	var tR := Keys.key_time("R", 0.0, _durs)
	var tEnd := Keys.key_time("R", 1.0, _durs)
	var p := "corte"
	if _t >= tEnd + Keys.HOLD_S + Keys.BACK_S:
		_finish()
		return
	if _t >= tEnd:
		p = "vuelta"
	elif _t >= tR:
		p = "recuperacion"
	elif _t >= tC:
		p = "contacto"
	elif _t >= tS:
		p = "golpe"
	elif _t >= tA:
		p = "anticipacion"
	_set_phase(p)
	# el cuerpo: los canales de la especie
	var ch := {}
	for c: String in (_k.keys as Dictionary):
		ch[c] = Keys.eval(_k, c, _t, _durs)
	for c: String in (_k.threat as Dictionary):
		if not ch.has(c):
			ch[c] = float(_k.threat[c])
	_apply_body(ch)
	# la pata que golpea
	var rest_w := _r.paw_rest_world()
	var coil := float(ch.get("coil", 0.0))
	var xf: Transform3D
	if _t < tS:
		var c2 := coil
		if bool(_var.get("feint", false)):
			var u := (_t - tA) / maxf(tS - tA, 1e-6)
			c2 = coil * (1.0 - 0.6 * sin(PI * clampf((u - 0.35) / 0.3, 0.0, 1.0)))
		xf = _blend(rest_w, _p_cock, c2)
	elif _t < tC:
		var s := clampf((_t - tS) / maxf(tC - tS, 1e-6), 0.0, 1.0)
		xf = _strike_pose(s * s)
	elif _t < tR:
		xf = _contact_pose(clampf((_t - tC) / maxf(tR - tC, 1e-6), 0.0, 1.0))
		_p_end = xf
	else:
		var u := clampf((_t - tR) / maxf(tEnd - tR, 1e-6), 0.0, 1.0)
		xf = _blend(_p_end if _impacted else _p_imp, rest_w, _ease_out_back(u))
	if _t >= tC and not _impacted:
		# el impacto, con la pata ya en la lente (un fotograma muy largo puede saltarse el contacto: se apunta igual)
		_r.set_paw_world(_p_imp if _t >= tR else xf)
		_impact()
	if _t >= tR and not _recorded:
		_end_contact()
	_r.set_paw_world(xf)
	# las garras: el tigre las saca en el golpe; todas se cierran al agarrar
	var flex := 0.0
	if _t >= tC and _t < tR:
		flex = float(_k.flex) * 0.6 * clampf((_t - tC) / maxf(tR - tC, 1e-6) * 1.5, 0.0, 1.0)
	elif _t >= tR:
		flex = float(_k.flex) * 0.6 * (1.0 - clampf((_t - tR) / maxf((tEnd - tR) * 0.5, 1e-6), 0.0, 1.0))
	_r.pose_claws(flex, float(ch.get("claw_out", -1.0)) if _kind == "felino" else -1.0)
	if _kind == "dinosaurio":
		_r.pose_sickle(float(ch.get("sickle", 0.0)))
	_r.force_claws_visible()
	# los rayones mientras toca
	if _t >= tC and _t < tR:
		_sample_traces()
	_paint_caption(p)


func _apply_body(ch: Dictionary) -> void:
	match _kind:
		"felino":
			AnimTiger.apply(_r, ch, _clock)
		"oso":
			AnimBear.apply(_r, ch, _clock)
		"dinosaurio":
			AnimRaptor.apply(_r, ch, _clock)
		_:
			AnimBird.apply(_r, ch, _clock, _kind == "nocturna")


## La postura del aviso: la de amenaza de su especie con peso w, la pata tensa (tiembla un poco) y, en el tigre, las uñas
## que asoman.
func _advance_warning(dt: float) -> void:
	var goal := 1.0 if _warning else 0.0
	if goal > _warn:
		_warn = minf(_warn + dt / WARN_IN, 1.0)
	elif goal < _warn:
		_warn = maxf(_warn - dt / WARN_OUT, 0.0)
		if _warn <= 0.0:
			_r.reset()
			return
	if _warn <= 0.0:
		return
	if _warning and _warn > 0.0 and _warn - dt / WARN_IN <= 0.0:
		sfx.emit(_voice_id(), 0.5, 1.0)
	var w := _warn * _warn * (3.0 - 2.0 * _warn)
	var ch := {}
	for c: String in (_k_for_warn().threat as Dictionary):
		ch[c] = float(_k_for_warn().threat[c]) * w
	ch["eye"] = lerpf(1.0, float((_k_for_warn().threat as Dictionary).get("eye", 1.0)), w)
	_apply_body(ch)
	var rest_w := _r.paw_rest_world()
	var j := 0.004 * w * sin(_clock * 23.0)
	_r.set_paw_world(Transform3D(rest_w.basis.rotated(rest_w.basis.z.normalized(), 0.06 * w + j * 4.0), rest_w.origin + rest_w.basis.y.normalized() * (0.006 * w)))
	if _kind == "felino":
		_r.pose_claws(0.0, float(_k_for_warn().threat.get("claw_out", 0.0)) * w)
		_r.force_claws_visible()


## La pausa para calmarlo: el peso entra en REST_IN s y sale en REST_OUT s; mientras pesa (y sin aviso), la postura tranquila
## de su especie (REST_POSE) y la penumbra (REST_DIM en las rapaces, la mitad en los demás).
func _advance_rest(dt: float) -> void:
	var goal := 1.0 if resting and _warn <= 0.0 else 0.0
	var was := _rest_w
	if goal > _rest_w:
		_rest_w = minf(_rest_w + dt / REST_IN, 1.0)
	elif goal < _rest_w:
		_rest_w = maxf(_rest_w - dt / REST_OUT, 0.0)
	var bird := _r.kind in ["rapaz", "nocturna"]
	_dim.visible = _rest_w > 0.0
	_dim.color.a = REST_DIM * (1.0 if bird else 0.5) * _rest_w
	if _rest_w <= 0.0:
		if was > 0.0:
			_r.reset()
		return
	var w := _rest_w * _rest_w * (3.0 - 2.0 * _rest_w)
	var pose: Dictionary = REST_POSE.get("ave" if bird else "grande", {})
	var ch := {}
	for c: String in pose:
		ch[c] = float(pose[c]) * w
	ch["eye"] = lerpf(1.0, float(pose.get("eye", 1.0)), w)
	_kind = _r.kind
	_apply_body(ch)


## Lo que respira más despacio el animal en la pausa (factor del reloj de la respiración, para care_3d.gd).
func breath_rate() -> float:
	return lerpf(1.0, REST_BREATH, _rest_w)


func _k_for_warn() -> Dictionary:
	if _k.is_empty():
		_kind = _r.kind
		_k = Keys.kind(_kind)
	return _k


func _advance_twitch(dt: float) -> void:
	_twitch += dt
	var rest_w := _r.paw_rest_world()
	var u := _twitch / Keys.TWITCH_S
	if u >= 1.0:
		_twitch = -1.0
		_r.reset()
		return
	var a := 0.12 * sin(PI * u) * sin(u * 28.0)
	_r.set_paw_world(Transform3D(rest_w.basis.rotated(rest_w.basis.z.normalized(), a), rest_w.origin))


func _blend(a: Transform3D, b: Transform3D, u: float) -> Transform3D:
	return Transform3D(a.basis.orthonormalized().slerp(b.basis.orthonormalized(), clampf(u, 0.0, 1.2)), a.origin.lerp(b.origin, u))


## El golpe: del recogido a la lente por un arco (Bézier con el punto de control fuera de la recta); la mano gira hacia la
## cámara antes de llegar.
func _strike_pose(s: float) -> Transform3D:
	var a := _p_cock.origin
	var b := _p_imp.origin
	var arc: Vector2 = _var.get("arc", Vector2(0.3, 0.6))
	var ctrl := (a + b) * 0.5 + (_cam_xf.basis.x * arc.x + _cam_xf.basis.y * arc.y) * a.distance_to(b) * ARC_K
	var p := a.lerp(ctrl, s).lerp(ctrl.lerp(b, s), s)
	var sr := clampf(s / 0.75, 0.0, 1.0)
	sr = sr * sr * (3.0 - 2.0 * sr)
	return Transform3D(_p_cock.basis.orthonormalized().slerp(_p_imp.basis.orthonormalized(), sr), p)


## El contacto (u, 0-1): rebota (se aparta), arrastra por el arco del zarpazo (salida suave) o se frena y se queda.
func _contact_pose(u: float) -> Transform3D:
	var b := _cam_xf.basis
	var d: Vector2 = _var.get("drag", Vector2(0.2, 1.0))
	var dir := (b.x * d.x - b.y * d.y).normalized()
	# el ancho que se ve a la distancia de la lente (como mucho el de una vista de 16:10): en el teléfono, más estrecho, el
	# zarpazo recorre la misma parte de la vista y sus rayones no se salen por los bordes
	var width := 2.0 * _cam_lens * tan(deg_to_rad(_cam_fov) * 0.5) * minf(_aspect, 1.6)
	var off := Vector3.ZERO
	if _drag_k < 0.0 and _lead_start.x >= 0.0:
		var dn := d.normalized() if d.length() > 1e-6 else Vector2.DOWN
		var span := float(_k.drag) * minf(_aspect, 1.6)
		_drag_k = drag_fit(_lead_start, Vector2(dn.x * span / maxf(_aspect, 1e-3), dn.y * span), DRAG_MARGIN)
	width *= maxf(_drag_k, 0.0) if _drag_k >= 0.0 else 1.0
	match _contact:
		"arrastre":
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			off = dir * float(_k.drag) * width * e + dir.cross(b.z) * float(_k.drag) * width * 0.08 * sin(PI * e)
		"frenazo":
			# desgarra un trecho corto (que se lean las marcas de cada garra) y se queda clavada
			var e2 := clampf(u / 0.45, 0.0, 1.0)
			off = dir * float(_k.drag) * width * 0.7 * (1.0 - (1.0 - e2) * (1.0 - e2))
		_:
			off = -b.z * REBOUND_K * _cam_lens * sin(PI * 0.5 * u) - b.y * 0.01 * u
	return Transform3D(_p_imp.basis, _p_imp.origin + off)


## La parte del arrastre (DRAG_MIN-1) con la que la garra del golpe, que toca la lente en start (normalizado) y se iría du
## más allá, acaba dentro de la vista con un margen m: el zarpazo de lado del oso se salía por el borde y sus rayones se
## quedaban pegados a él.
static func drag_fit(start: Vector2, du: Vector2, m: float) -> float:
	var k := 1.0
	for i in 2:
		var s0 := start[i]
		var d := du[i]
		if d > 1e-6:
			k = minf(k, (1.0 - m - s0) / d)
		elif d < -1e-6:
			k = minf(k, (m - s0) / d)
	return clampf(k, DRAG_MIN, 1.0)


## El fotograma del impacto: temblor, destello, sonido, la grieta y las manchas donde tocan las garras, los rayones que
## empiezan y las esquirlas de la garra que se desconcha.
func _impact() -> void:
	_impacted = true
	_shake_t = _t
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640.0, 400.0)
	var items: Array = []
	var idx := 0
	var first := Vector2(-1.0, -1.0)
	for c: Dictionary in _fingers:
		var f := String(c.finger)
		var fuv: Variant = _finger_uv(f, vs)
		if fuv == null:
			continue
		var uv: Vector2 = fuv
		_traces[f] = [uv]
		_marks[f] = []
		if first.x < 0.0 or f == _lead:
			first = uv
		if bool(c.get("scratched", false)):
			var it := lens.scratch_item({ "trace": [uv, uv + Vector2(0.001, 0.0)], "kind": String(c.get("scratch", "rayon")),
				"widthUm": float(c.get("widthUm", 0.0)), "depthUm": float(c.get("depthUm", 0.0)), "material": String(c.get("material", "none")),
				"finger": f })
			if not it.is_empty():
				items.append(it)
				_live_index[f] = idx
				idx += 1
		if String(c.outcome) == "grieta":
			lens.add_crack(uv, LensLayer.CRACK_RADIUS, 7, int(_last_seq) * 31 + 5)
	lens.live_begin(items)
	for f: String in _live_index:
		if float((_windows.get(f, [0.0, 1.0]) as Array)[0]) <= 0.0:
			(_marks[f] as Array).append((_traces[f] as Array)[0])
			lens.live_point(int(_live_index[f]), (_traces[f] as Array)[0])
	if first.x >= 0.0:
		lens.flash(first, float(_ev.get("intensity", 0.6)))
	sfx.emit(_impact_sfx(), VOL_IMPACT, 1.0)
	_spawn_shards()


func _sample_traces() -> void:
	if _cam == null:
		return
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640.0, 400.0)
	var tC := Keys.key_time("C", 0.0, _durs)
	var u := clampf((_t - tC) / maxf(Keys.key_time("R", 0.0, _durs) - tC, 1e-6), 0.0, 1.0)
	for c: Dictionary in _fingers:
		var f := String(c.finger)
		var fuv: Variant = _finger_uv(f, vs)
		if fuv == null:
			continue
		var uv: Vector2 = fuv
		var tr: Array = _traces.get(f, [])
		if tr.is_empty() or (tr.back() as Vector2).distance_to(uv) > 0.002:
			tr.append(uv)
			_traces[f] = tr
			var w: Array = _windows.get(f, [0.0, 1.0])
			if _live_index.has(f) and u >= float(w[0]) and u <= float(w[1]):
				(_marks[f] as Array).append(uv)
				lens.live_point(int(_live_index[f]), uv)


## Acaba el contacto: los rayones dibujados se quedan en la lente y sus trazos van al motor (lens_record).
func _end_contact() -> void:
	_recorded = true
	lens.live_end()
	var out := {}
	for f: String in _traces:
		var tr: Array = _traces[f]
		# la garra que raya, solo el tramo en que aprieta lo bastante (y la que raja, desde donde golpeó)
		var mk: Array = _marks.get(f, [])
		if mk.size() >= 2:
			tr = ([tr[0]] + mk) if _crack_finger(f) else mk
		if tr.size() == 1:
			tr = [tr[0], (tr[0] as Vector2) + Vector2(0.002, 0.002)]
		var pts: Array = []
		for p: Vector2 in tr:
			pts.append([clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, 1.0)])
		out[f] = pts
	# las manchas, también en la lente de la escena hasta que llegue la del motor
	for c: Dictionary in _fingers:
		if String(c.outcome) == "mancha" and out.has(String(c.finger)):
			lens.add_smudge(lens.smudge_item({ "trace": out[String(c.finger)], "transfer": String(c.get("transfer", "")),
				"material": String(c.get("material", "none")), "id": _last_seq * 7 + out.keys().find(String(c.finger)) + 1 }))
	if _contact == "arrastre":
		sfx.emit("lente-rasguno", VOL_IMPACT, 1.0)
	lens_record.emit(_last_seq, out)


## La parte del contacto (u de 0 a 1) en que raya cada garra: la del medio, tan larga como la parte del zarpazo en que
## aprieta más de lo que pide marcar la lente (lengthMm / SWIPE_MM del motor; al menos MARK_MIN); la del golpe, un poco
## antes que las demás (llega primero). → { dedo: [u0, u1] }.
static func _mark_windows(fingers: Array, lead: String) -> Dictionary:
	var out := {}
	for c: Dictionary in fingers:
		if not bool(c.get("scratched", false)):
			continue
		var frac := clampf(float(c.get("lengthMm", Reaction.SWIPE_MM)) / Reaction.SWIPE_MM, MARK_MIN, 1.0)
		var mid := 0.45 if String(c.finger) == lead else 0.55
		var u0 := clampf(mid - 0.5 * frac, 0.0, 1.0 - frac)
		out[String(c.finger)] = [u0, u0 + frac]
	return out


## Dónde toca la lente la garra f (normalizado): la punta de verdad de la garra del golpe y las demás según el dibujo de su
## tipo (PATTERNS). null si no hay punta.
func _finger_uv(f: String, vs: Vector2) -> Variant:
	if _cam == null:
		return null
	var lt: Variant = _r.tip_world(_lead)
	if lt == null:
		lt = _r.tip_world(f)
		if lt == null:
			return null
		return _cam.unproject_position(lt as Vector3) / vs
	var lead_uv := _cam.unproject_position(lt as Vector3) / vs
	if _lead_start.x < 0.0:
		_lead_start = lead_uv
		_pat_shift = _fit_shift(lead_uv, vs)
	return _pattern_uv(f, lead_uv, vs) + _pat_shift


## Lo que hay que mover el dibujo entero para que las marcas (de donde empiezan a donde acabará el arrastre) queden dentro
## de la vista, con un margen FIT_MARGIN (normalizado). Cero si ya caben.
func _fit_shift(lead_uv: Vector2, vs: Vector2) -> Vector2:
	var d: Vector2 = _var.get("drag", Vector2(0.2, 1.0))
	var dir := d.normalized() if d.length() > 1e-6 else Vector2.DOWN
	var k := 0.0
	match _contact:
		"arrastre":
			k = 1.0
		"frenazo":
			k = 0.7
	# el arrastre en pantalla: lo de _contact_pose (drag · 1,6 veces el alto que se ve a la distancia de la lente)
	var drag_px := float(_k.drag) * 1.6 * vs.y * k
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Dictionary in _fingers:
		var s := _pattern_uv(String(c.finger), lead_uv, vs)
		for q: Vector2 in [s, s + dir * drag_px / vs]:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if lo.x == INF:
		return Vector2.ZERO
	var shift := Vector2.ZERO
	for ax in 2:
		var a := FIT_MARGIN
		var b := 1.0 - FIT_MARGIN
		if hi[ax] - lo[ax] > b - a:
			shift[ax] = 0.5 - 0.5 * (lo[ax] + hi[ax])
		elif lo[ax] < a:
			shift[ax] = a - lo[ax]
		elif hi[ax] > b:
			shift[ax] = b - hi[ax]
	return shift


func _pattern_uv(f: String, lead_uv: Vector2, vs: Vector2) -> Vector2:
	var pat: Dictionary = PATTERNS.get(_kind, {})
	var front: Array = pat.get("front", [])
	var back: Array = pat.get("back", [])
	var d: Vector2 = _var.get("drag", Vector2(0.2, 1.0))
	var dir := d.normalized() if d.length() > 1e-6 else Vector2.DOWN
	var sp_m := float(_hit.get("spacingMm", 20.0)) / 1000.0
	var sp := clampf(sp_m * vs.y / (2.0 * _cam_lens * tan(deg_to_rad(_cam_fov) * 0.5)), SPACING_MIN * vs.y, SPACING_MAX * vs.y)
	var p := lead_uv * vs
	# la dirección del arrastre de verdad (la de la garra del golpe en la pantalla, en cuanto se ha movido algo): las demás,
	# separadas de través a ella, para que no caigan unas encima de otras
	if _dir_lock == Vector2.ZERO and _lead_start.x >= 0.0 and (p - _lead_start * vs).length() > 0.5 * sp:
		_dir_lock = (p - _lead_start * vs).normalized()
	if _dir_lock != Vector2.ZERO:
		dir = _dir_lock
	var perp := Vector2(-dir.y, dir.x)
	# las del grupo de la del golpe, paralelas a ella; las del otro grupo (en las rapaces, la del golpe es el pulgar, de las de
	# atrás: las de delante van a su encuentro), centradas en su línea, desde delante y contra el arrastre
	var own: Array = back if back.has(_lead) else front
	var other: Array = front if back.has(_lead) else back
	if own.has(f):
		return (p + perp * (_offset_of(f, own, pat if own == front else {}) - _offset_of(_lead, own, pat if own == front else {})) * sp) / vs
	if other.has(f):
		# salen de donde están de verdad (el centro de sus puntas en el impacto, repartidas a su separación) y se cierran hacia
		# la del golpe mientras arrastra (el pie que agarra)
		var s0 := _lead_start * vs
		if _other_center.x < 0.0:
			var c := Vector2.ZERO
			var k := 0
			for g: String in other:
				var t: Variant = _r.tip_world(g)
				if t != null:
					c += _cam.unproject_position(t as Vector3)
					k += 1
			_other_center = c / float(k) if k > 0 else s0 + dir * BACK_AHEAD * sp
		var start := _other_center + perp * _offset_of(f, other, {}) * sp
		var prog := clampf((p - s0).length() / (3.0 * sp), 0.0, 1.0)
		return (start.lerp(p, BACK_K * prog) + (p - s0) * 0.3) / vs
	return lead_uv


## El sitio de f en su grupo (en separaciones, centrado; o el de «offsets» del patrón).
static func _offset_of(f: String, group: Array, pat: Dictionary) -> float:
	var offs: Array = pat.get("offsets", [])
	var i := group.find(f)
	if i < 0:
		return 0.0
	return float(offs[i]) if i < offs.size() else float(i) - 0.5 * float(group.size() - 1)


func _crack_finger(f: String) -> bool:
	for c: Dictionary in _fingers:
		if String(c.finger) == f:
			return String(c.get("outcome", "")) == "grieta"
	return false


func _finish() -> void:
	_set_phase("idle")
	_r.reset()
	_caption.visible = false
	_cam_xf = Transform3D.IDENTITY
	info_last = info()


func _paint_caption(p: String) -> void:
	var early := p in ["golpe", "contacto"] or (p == "recuperacion" and _t < Keys.key_time("R", 0.35, _durs))
	# después, si no ha rayado, el porqué (CareReactionText, con los números del motor)
	var late := not early and p in ["recuperacion", "vuelta"] and _lens_text != ""
	_caption.visible = early or late
	if late:
		_caption.text = _lens_text.substr(0, 1).to_upper() + _lens_text.substr(1) + "."
		return
	if not early:
		return
	var txt := "Cámara lenta ×%s · el golpe real dura %s s" % [Js.to_fixed(_slowmo, 2), Js.to_fixed(float(_strike.get("tS", 0.0)), 2)]
	if _kind == "dinosaurio" and _model == "pelicula":
		txt += " · ficción (película)"
	_caption.text = txt
	_place_caption()


## El rótulo, sin tapar caption_avoid: a su derecha si caben CAPTION_MIN_W px; si no, encima de él, de lado a lado.
func _place_caption() -> void:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640.0, 400.0)
	_caption.offset_left = 0.0
	_caption.offset_top = -54.0
	_caption.offset_bottom = -30.0
	if caption_avoid == null or not is_instance_valid(caption_avoid) or not caption_avoid.is_visible_in_tree():
		return
	var r := caption_avoid.get_global_rect()
	if vs.x - r.end.x - 10.0 >= CAPTION_MIN_W:
		_caption.offset_left = r.end.x + 10.0
	else:
		_caption.offset_bottom = -(vs.y - r.position.y) - 6.0
		_caption.offset_top = _caption.offset_bottom - 40.0
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


## El campo vertical (grados) para que en una vista más alta que ancha (el teléfono) quepa de lado lo mismo que en una
## apaisada: el zarpazo de lado del oso y sus rayones se salían por los bordes. Como mucho PORTRAIT_FOV_MAX.
static func portrait_fov(fov: float, vs: Vector2) -> float:
	if vs.y <= 0.0 or vs.x >= vs.y:
		return fov
	var t := tan(deg_to_rad(fov) * 0.5) * vs.y / vs.x
	return minf(rad_to_deg(2.0 * atan(t)), PORTRAIT_FOV_MAX)


func _voice_id() -> String:
	match _kind:
		"nocturna":
			return "reaccion-buho"
		"felino":
			return "reaccion-tigre"
		"oso":
			return "reaccion-oso"
		"dinosaurio":
			return "reaccion-raptor"
	return "reaccion-rapaz"


func _impact_sfx() -> String:
	var plastic := String(_hit.get("lens", "plastico")) == "plastico"
	match String(_hit.get("outcome", "nada")):
		"grieta":
			return "lente-grieta"
		"desgarro", "rayon", "rayon_hondo":
			return "lente-plastico" if plastic else "lente-vidrio"
	return "lente-plastico" if plastic else "lente-vidrio"


static func _ease_out_back(u: float) -> float:
	var c := 1.4
	var x := u - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x


# ─────────────────────────────── esquirlas ───────────────────────────────

static func _shard_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(0.0, 0.0012, 0.0), Vector3(-0.0009, -0.0006, 0.0007), Vector3(0.001, -0.0005, 0.0006), Vector3(0.0, -0.0004, -0.0011)]
	for tri: Array in [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]:
		for i: int in tri:
			st.add_vertex(p[i])
	st.generate_normals()
	st.commit(am)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.95)
	mat.metallic = 0.2
	mat.roughness = 0.15
	am.surface_set_material(0, mat)
	return am


func _spawn_shards() -> void:
	var chips: Array = []
	for c: Dictionary in _fingers:
		if bool(c.get("chips", false)):
			chips.append(String(c.finger))
	if chips.is_empty():
		return
	var rng := Rng.new(Rng.seed_of("esquirlas|%d" % _last_seq))
	_shards.clear()
	var per := maxi(SHARDS / chips.size(), 4)
	for f: String in chips:
		var tip: Variant = _r.tip_world(f)
		if tip == null:
			continue
		var mi := _r.claw_mesh(f)
		if mi != null and mi.material_override is ShaderMaterial:
			pass
		for i in per:
			if _shards.size() >= SHARDS:
				break
			var v := (_cam_xf.basis.z * (0.4 + 0.8 * rng.next()) + _cam_xf.basis.x * (rng.next() - 0.5) * 1.6 + _cam_xf.basis.y * (0.3 + rng.next())) * (0.6 + rng.next())
			_shards.append({ "p": tip as Vector3, "v": v, "r": Vector3(rng.next(), rng.next(), rng.next()) * 20.0, "s": 0.6 + 0.9 * rng.next() })
	_shard_t = 0.0
	_shard_mmi.multimesh.visible_instance_count = _shards.size()
	sfx.emit("snap", VOL_IMPACT * 0.8, 1.4)


func _advance_shards(dt: float) -> void:
	if _shard_t < 0.0:
		return
	_shard_t += dt
	if _shard_t > SHARD_LIFE:
		_shard_t = -1.0
		_shard_mmi.multimesh.visible_instance_count = 0
		return
	var inv := _shard_mmi.global_transform.affine_inverse() if _shard_mmi.is_inside_tree() else Transform3D.IDENTITY
	for i in _shards.size():
		var s: Dictionary = _shards[i]
		s.v = (s.v as Vector3) + Vector3(0.0, -GRAVITY, 0.0) * dt
		s.p = (s.p as Vector3) + (s.v as Vector3) * dt * _slowmo
		var rot := (s.r as Vector3) * _shard_t
		_shard_mmi.multimesh.set_instance_transform(i, inv * Transform3D(Basis.from_euler(rot).scaled(Vector3.ONE * float(s.s)), s.p))
