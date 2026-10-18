## Guion visual del insecto en el banco (bench.gd lo pinta): dónde está y qué hace en cada ms del ensayo de un
## aguijón. Los momentos salen del guion de core/lab/sting_lab.gd (StingLab.timeline: llegada, contacto, perforación,
## inserción a su velocidad medida, retirada o autotomía, vuelo de salida y bombeo del veneno enseñado ×10) y el veneno,
## de StingLab.venom_state; aquí solo se decide cómo se ve (trayectorias, suavizados, cuánto se hunde la piel, lo que se
## dobla un aguijón que pandea), que es ritmo de animación y no dato.
## Funciones puras (sin nodos): los tests pueden pedir la pose de cualquier resultado en cualquier momento.
## Unidades del banco (lienzo de 360 × 170); el aguijón y el insecto, a la escala LabArt.insect_k (unidades por mm).
## Uso: const BenchInsect = preload("res://app/lab/bench_insect.gd"); var p := BenchInsect.pose(claw, res, ms, 1150.0, o)
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Sting = preload("res://core/lab/sting.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
const LabArt = preload("res://app/lab/lab_art.gd")

## De dónde llega, adónde se va y dónde espera (desplazamientos de la base del aguijón respecto a la pose de picar).
const APPROACH_FROM := Vector2(-118.0, -62.0)
const LEAVE_TO := Vector2(135.0, -95.0)
const IDLE_AT := Vector2(-34.0, -24.0)
## Lo que se hunde la piel bajo la punta antes de romperse (unidades), lo que sube la abeja al desgarrarse y la flecha
## de la punta de un aguijón que pandea (fracción de su longitud).
const DIMPLE := 1.6
const RISE := 7.0
const BEND_MAX := 0.32
## Ancho mínimo y máximo del aguijón dibujado (unidades): a escala, el de la abeja mediría media unidad.
const WIDTH_MIN := 1.3
const WIDTH_MAX := 2.6
## Latido del saco del veneno mientras bombea (Hz de pantalla) y su amplitud.
const PULSE_HZ := 2.4
const PULSE := 0.09


static func _ease_out(u: float) -> float:
	var v := 1.0 - clampf(u, 0.0, 1.0)
	return 1.0 - v * v * v


static func _ease_in(u: float) -> float:
	var v := clampf(u, 0.0, 1.0)
	return v * v


static func _smooth(u: float) -> float:
	var v := clampf(u, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


static func _frac(ms: float, a: float, b: float) -> float:
	return clampf((ms - a) / (b - a), 0.0, 1.0) if b > a else (1.0 if ms >= b else 0.0)


## Geometría del aguijón en el banco: { k, len (unidades), width, depth (lo que entra, unidades) }.
static func geometry(claw: Dictionary, res: Variant) -> Dictionary:
	var k := LabArt.insect_k(claw)
	var st: Dictionary = claw.stinger
	var len := float(Sting.sval(st, "shaftMm")) * k
	var width := clampf(float(Sting.sval(st, "diameterUm")) / 1000.0 * k * 3.0, WIDTH_MIN, WIDTH_MAX)
	var depth := 0.0
	if res is Dictionary and res.get("depthUm") != null:
		depth = minf(float(res.depthUm) / 1000.0 * k, len * 0.9)
	return { "k": k, "len": len, "width": width, "depth": depth }


## ¿Saca el aguijón antes de tocar? Los ápidos (abeja, abejorro) llegan con él fuera; los demás lo sacan al tocar
## (Zhao et al. 2015, en Polistes).
static func extends_early(claw: Dictionary) -> bool:
	return String(claw.stinger.get("family", "")) == "Apidae"


## Momento que se enseña quieto con movimiento reducido: el final si la abeja se queda sin aguijón (el aparato clavado),
## la picadura con el aguijón dentro si entra, y si no el instante en que se dobla o se aplasta.
static func still_ms(res: Dictionary, run_ms: float) -> float:
	var tl := StingLab.timeline(res, run_ms)
	if tl.autotomy:
		return tl.end
	if tl.entered:
		return tl.insertEnd
	return tl.pierce


## Pose en espera (antes de ARAÑAR): quieto por encima del punto de picar, con las alas plegadas.
static func idle_pose(claw: Dictionary, o: Dictionary) -> Dictionary:
	var g := geometry(claw, null)
	var sting_at := Vector2(float(o.cx), float(o.gy) - g.len) + IDLE_AT
	return _pose_dict(g, {
		"stage": "idle", "gaster": sting_at, "base": sting_at, "extend": 1.0 if extends_early(claw) else 0.0, "flying": 0.0,
	})


static func _pose_dict(g: Dictionary, over: Dictionary) -> Dictionary:
	var p := {
		"stage": "idle", "show_insect": true, "gaster": Vector2.ZERO, "base": Vector2.ZERO, "len": g.len, "width": g.width,
		"visible": g.len, "inserted": 0.0, "bend": 0.0, "extend": 1.0, "tilt": 0.0, "attached": true, "filament": 0.0,
		"apparatus": false, "sac_fill": 1.0, "sac_pulse": 1.0, "venom": { "realS": 0.0, "fraction": 0.0, "ug": null },
		"twist": null, "dimple": 0.0, "wound": 0.0, "crush": 0.0, "flying": 0.0, "buzz": 0.0, "k": g.k,
	}
	p.merge(over, true)
	return p


## Pose del insecto a los `ms` del ensayo (desde que se pulsa ARAÑAR). res: el resultado del ensayo (con `sting`);
## o = { cx, gy }: dónde pica, en unidades del banco. Devuelve { stage, show_insect, gaster (dónde va la base del aguijón
## del dibujo del insecto), base (la base del aguijón), len, width, visible (lo que asoma), inserted, bend, extend, tilt,
## attached, filament (0-1, el aparato estirándose al tirar), apparatus (el aparato clavado tras la autotomía), sac_fill,
## sac_pulse, venom (StingLab.venom_state), twist (° o null), dimple, wound, crush, flying (0-1, las alas), buzz (0-1,
## volumen del zumbido), k }.
static func pose(claw: Dictionary, res: Dictionary, ms: float, run_ms: float, o: Dictionary) -> Dictionary:
	var g := geometry(claw, res)
	var tl := StingLab.timeline(res, run_ms)
	var s: Dictionary = res.sting
	var skin := Js.truthy(res.get("skin"))
	var cx := float(o.cx)
	var gy := float(o.gy)
	var len: float = g.len
	var rest := Vector2(cx, gy - len)  # base del aguijón con la punta tocando la superficie
	var early := extends_early(claw)
	var buckled: bool = s.get("buckled") == true
	var crushed: bool = s.get("tipCrushed") == true
	var entered: bool = tl.entered
	var p := { "stage": "approach", "extend": 1.0 if early else 0.0 }
	var offset := Vector2.ZERO
	var inserted := 0.0
	var bend := 0.0
	var dimple := 0.0
	var rise := 0.0
	var tilt := 0.0
	var flying := 0.35  # mientras pica, las alas tiemblan
	var buzz := 0.22
	var t_contact: float = tl.contact
	var t_pierce: float = tl.pierce
	var t_ins: float = tl.insertEnd
	var t_pull: float = tl.pullStart
	var t_leave: float = tl.leave
	var t_gone: float = tl.leaveEnd
	# lo que se dobla y se hunde hasta el momento de perforar (o de ceder)
	var press_u := _frac(ms, t_contact, t_pierce)
	if buckled:
		bend = _smooth((press_u - 0.3) / 0.7) * BEND_MAX * len
	if skin and not buckled:
		dimple = _smooth(press_u)
	if ms < t_contact:
		var u := ms / t_contact
		var e := _ease_out(u)
		offset = APPROACH_FROM.lerp(Vector2.ZERO, e) + Vector2(0.0, 2.2 * sin(ms / 1000.0 * TAU * 2.6) * (1.0 - e))
		tilt = -0.12 * (1.0 - e)
		flying = 1.0
		buzz = 0.5 * minf(1.0, ms / 200.0)
		if not early:
			p.extend = _smooth((u - 0.82) / 0.18)
	elif ms < t_pierce:
		p.stage = "press"
	elif entered and ms < t_ins:
		p.stage = "insert"
		var u := _frac(ms, t_pierce, t_ins)
		inserted = g.depth * _smooth(u)
		dimple = 1.0 - _smooth(u / 0.25) if skin else 0.0
		offset.y = 0.3 * sin(ms / 1000.0 * TAU * 7.0)  # las lancetas avanzan por turnos
	elif entered and ms < t_pull:
		p.stage = "hold"
		inserted = g.depth
		dimple = 0.0
	elif entered and ms < t_leave:
		p.stage = "pull"
		var e := _smooth(_frac(ms, t_pull, t_leave))
		if tl.autotomy:
			inserted = g.depth
			rise = e * RISE
			p.filament = e
		else:
			inserted = g.depth * (1.0 - e)
	elif not entered and ms < t_leave:
		p.stage = "hold"  # sigue apretando: la piel hundida, el aguijón doblado o la punta aplastada
	elif ms < t_gone:
		p.stage = "leave"
		var e := _ease_in(_frac(ms, t_leave, t_gone))
		offset = LEAVE_TO * e
		tilt = 0.18 * e
		flying = 1.0
		buzz = 0.5 * (1.0 - e)
		inserted = g.depth if tl.autotomy else 0.0
		rise = RISE if tl.autotomy else 0.0
		bend *= 1.0 - e  # el pandeo es elástico: al soltar, se endereza
		dimple = 0.0
	else:
		p.stage = "gone"
		p.show_insect = false
		flying = 0.0
		buzz = 0.0
		inserted = g.depth if tl.autotomy else 0.0
		bend = 0.0
		dimple = 0.0
	if not entered and ms >= t_leave:
		dimple = 0.0
	if ms >= t_contact:
		p.extend = 1.0  # desde que toca, fuera en todas las especies
	# la base del aguijón: baja lo que entra, lo que se hunde la piel y lo que se acorta al doblarse
	var base := rest + Vector2(0.0, inserted + dimple * DIMPLE + bend * 0.45)
	var gaster := base + offset + Vector2(0.0, -rise)
	if p.stage in ["approach", "leave", "gone"] and not (tl.autotomy and ms >= t_leave):
		base = gaster  # en vuelo, el aguijón va con el insecto
	var torn: bool = tl.autotomy and ms >= t_leave
	p.merge({
		"gaster": gaster, "base": base, "inserted": inserted, "visible": maxf(len - inserted, 0.0), "bend": bend, "tilt": tilt,
		"dimple": dimple, "flying": flying, "buzz": buzz, "attached": not torn, "apparatus": torn,
	}, true)
	if torn:
		p.filament = 0.0
	# marcas en la superficie: la herida desde que perfora; en un sólido, la huella si ha entrado algo
	if entered and ms >= t_pierce:
		p.wound = _smooth(_frac(ms, t_pierce, t_pierce + 120.0))
	if crushed and ms >= t_pierce - 60.0:
		p.crush = 1.0 - _frac(ms, t_pierce + 80.0, t_pierce + 700.0)
	# el giro helicoidal, a medida que entra (Wu et al. 2014: el total al final; el reparto lineal es una hipótesis)
	if skin and entered and s.get("twistDeg") != null and ms >= t_pierce and not torn:
		p.twist = float(s.twistDeg) * (inserted / g.depth if g.depth > 0.0 else 0.0)
	# veneno: el saco se vacía con la bomba (la abeja clavada, ×10) o mientras dura la picadura (los véspidos)
	var v := StingLab.venom_state(claw, res, ms, run_ms)
	p.venom = v
	p.sac_fill = 1.0 - float(v.fraction)
	if torn and (tl.pumpEnd < 0.0 or ms < float(tl.pumpEnd)):
		p.sac_pulse = 1.0 + PULSE * sin(ms / 1000.0 * TAU * PULSE_HZ)
	return _pose_dict(g, p)


## Volumen del zumbido de la pose (0 si la especie no zumba: sin alas o sin medida).
static func buzz_volume(pose_d: Dictionary, buzz_id: String) -> float:
	if buzz_id == "" or not pose_d.show_insect:
		return 0.0
	return float(pose_d.buzz)
