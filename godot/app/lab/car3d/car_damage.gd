## Daños del coche en marcha en 3D (unidad 4k): del resultado de impact() o de hold_report() (a través del estado) a las
## listas que pintan los shaders del coche (car_damage.gdshaderinc en la pintura y las piezas, car_glass.gdshader en las
## lunas), en metros del coche. Funciones puras, deterministas (el azar de core/shared/rng.gd) y sin nodos: se llaman
## cuando llega un golpe nuevo, nunca en cada fotograma.
##
## Por qué en el material y no con Decal: el renderizador Compatibility (el de los equipos sin Vulkan, al que el proyecto
## cae con fallback_to_opengl3, y el de las capturas) no pinta los Decal; un daño en el shader de la pintura se ve en los
## tres renderizadores, se hunde con la abolladura, enseña la capa a la que llega con la luz de la propia chapa (el metal
## brillante refleja el cielo) y no depende de la resolución de una textura (la lupa lo ve igual de nítido).
##
## De los datos a la escala real:
##   - surcos (marks: count, lengthMm, widthUm, depthUm, residualUm, layers, reachesBody): marks.count rayas de
##     widthUm de ancho y lengthMm de largo desde el punto del golpe en la dirección del resbalón (sin pasar del panel
##     dibujado), con el color de la capa más honda que cortan (Data.PAINT_LAYERS y la carrocería); si su profundidad
##     pasa del espesor de la pintura y la chapa (target.body.t), la atraviesan: ranura (el plástico rajado, 4g) o tajo
##     (la chapa rajada por garras reforjadas, 4d), con el hueco oscuro;
##   - punciones (puncture: through, holeUm): un agujero de holeUm de diámetro donde entra cada garra, con el borde
##     desgarrado; en la chapa, los pétalos de Wierzbicki (1999); en el plástico, el labio blanqueado;
##   - abolladuras (dent: depthMm, patches): dent.patches hoyos de depthMm, con el fondo del tamaño del apoyo
##     (MovingCar.BODIES[…].contact_mm) y el borde hasta DENT_SPREAD veces la profundidad (dibujo: la física da la
##     profundidad, no el radio);
##   - parabrisas (windshield.cracked): una estrella de grietas con su telaraña bajo cada apoyo; el PVB lo sujeta;
##   - desgarros del animal asustado quieto encima (defense.tear): de sus patas al borde del panel.
## Lo que es solo dibujo (dónde va cada garra de la pata, la separación de las patas, el radio de la abolladura, el de la
## estrella de grietas, los pétalos) va marcado «dibujo»: la física da las medidas, no la colocación.
extends RefCounted

const CarShape = preload("res://app/lab/car3d/car_shape.gd")
const CurveKit = preload("res://app/lab/car3d/curve_kit.gd")
const Rng = preload("res://core/shared/rng.gd")
const Js = preload("res://core/shared/js.gd")

## Tope de cada lista (los arrays de uniformes de los shaders).
const MAX_GROOVES := 48
const MAX_HOLES := 40
const MAX_DENTS := 16
const MAX_CRACKS := 6
## Capas del color de un surco: 0 barniz · 1 color · 2 imprimación · 3 anticorrosivo (o promotor) · 4 la carrocería ·
## 5 la atraviesa.
const LAYER_BODY := 4
const LAYER_THROUGH := 5
## Ejes de los daños: arriba (x, z) o en el costado de +z (x, y).
const AXIS_TOP := 0
const AXIS_SIDE := 1
## Dibujo: separación entre las garras de una pata y entre las dos patas o los dos pies (m), el borde de la abolladura
## (veces su profundidad), el apoyo por defecto (el casuario no tiene contact_mm) y los pétalos de la chapa perforada.
const CLAW_GAP := { "mamifero": 0.028, "ave": 0.02, "corredora": 0.03, "teropodo": 0.03 }
const PAW_SEP := { "mamifero": 0.22, "ave": 0.09, "corredora": 0.12, "teropodo": 0.15 }
const SIDE_PAW_SEP := 0.12
const SIDE_TOP_Y := 0.9
const DENT_SPREAD := 2.6
const DENT_CORE_SPREAD := 2.2
const DEFAULT_CONTACT_MM := 40.0
const PETALS := 4
## Dibujo: radio de la estrella de grietas del parabrisas (m) según lo que la fuerza de pico pasa de la que lo agrieta.
const CRACK_R := Vector2(0.1, 0.32)
## La lupa: el campo para unos agujeros (veces su radio, y como poco) y para los surcos de una pata (m).
const LUPA_HOLE := 14.0
const LUPA_MIN_M := 0.05
const LUPA_RAKE_M := 0.1


## Un conjunto vacío.
static func empty() -> Dictionary:
	return { "grooves": [], "holes": [], "dents": [], "cracks": [], "shatter": { "front": 0.0, "rear": 0.0, "frag_m": 0.0056 },
		"focus": Vector3.INF, "focus_m": 0.0 }


## Junta dos conjuntos (b encima de a), sin pasar de los topes (se quedan los más nuevos).
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := empty()
	for k: String in ["grooves", "holes", "dents", "cracks"]:
		var list: Array = (a[k] as Array) + (b[k] as Array)
		var cap: int = { "grooves": MAX_GROOVES, "holes": MAX_HOLES, "dents": MAX_DENTS, "cracks": MAX_CRACKS }[k]
		out[k] = list.slice(maxi(0, list.size() - cap))
	out.shatter = { "front": maxf(float(a.shatter.front), float(b.shatter.front)), "rear": maxf(float(a.shatter.rear), float(b.shatter.rear)),
		"frag_m": float(b.shatter.frag_m) if float(b.shatter.front) + float(b.shatter.rear) > 0.0 else float(a.shatter.frag_m) }
	merge_glass(out, a, b)  # unidad 4v: la luneta
	out.focus = b.focus if b.focus != Vector3.INF else a.focus
	out.focus_m = b.focus_m if b.focus != Vector3.INF else a.focus_m
	return out


## La parte de arriba del coche muestreada cada SURF_DX m (de la zaga al morro), una vez: CurveKit.top_y recorre toda la
## curva en cada llamada, y un surco largo la pediría cientos de veces en cada golpe.
const SURF_DX := 0.005
static var _surf := PackedFloat32Array()
static var _surf_of := Vector4.ZERO  # la curva del muestreo: puntos, primer x, último x y alto del primero


## Alto (m) de la parte de arriba del coche en x, del muestreo (top: CarShape.top_curve()).
static func surf_y(top: PackedVector2Array, x: float) -> float:
	var key := Vector4(top.size(), top[0].x, top[top.size() - 1].x, top[0].y)
	if _surf.is_empty() or key != _surf_of:
		_surf_of = key
		# una pasada por la curva: en cada muestra, lo más alto de los tramos que la cubren (lo mismo que CurveKit.top_y)
		var n := int(ceilf(CarShape.CAR_L / SURF_DX)) + 1
		_surf.resize(n)
		_surf.fill(0.0)
		for k in top.size() - 1:
			var a := top[k]
			var b := top[k + 1]
			if a.x == b.x:
				continue
			for i in range(maxi(0, ceili(minf(a.x, b.x) / SURF_DX)), mini(n - 1, floori(maxf(a.x, b.x) / SURF_DX)) + 1):
				_surf[i] = maxf(_surf[i], lerpf(a.y, b.y, (float(i) * SURF_DX - a.x) / (b.x - a.x)))
	var f := clampf(x / SURF_DX, 0.0, float(_surf.size() - 1))
	var i0 := int(f)
	var i1 := mini(i0 + 1, _surf.size() - 1)
	return lerpf(_surf[i0], _surf[i1], f - float(i0))


## x donde se acaba un surco de largo len_m (m, medido sobre la chapa) que sale de x0 por la parte de arriba del coche
## (top: CarShape.top_curve()) en la dirección dir (±1), sin pasar de [x_min, x_max].
static func walk_top(top: PackedVector2Array, x0: float, len_m: float, dir: float, x_min: float, x_max: float) -> float:
	var x := x0
	var y := surf_y(top, x)
	var left := len_m
	var step := SURF_DX
	while left > 0.0:
		var nx := x + dir * step
		if nx < x_min or nx > x_max:
			return clampf(nx, x_min, x_max)
		var ny := surf_y(top, nx)
		var ds := Vector2(step, ny - y).length()
		if ds >= left:
			return x + dir * step * left / ds
		left -= ds
		x = nx
		y = ny
	return x


## Punto del golpe en metros: el de la zona (su draw: el de MovingCar.IMPACT_ZONES si lo trae, como la ventanilla, o el de
## MovingCar.ZONES) o, en la puerta, CarShape.DOOR_DRAW; arriba, sobre la superficie de la silueta. draw: el punto draw de
## la zona (0-1) o null.
static func impact_point(zone: String, draw: Variant, top: PackedVector2Array) -> Vector3:
	var d: Vector2 = CarShape.DOOR_DRAW if draw == null else Vector2(draw.x, draw.y)
	var w := Vector2(CarShape.CAR_L * (1.0 - d.x), CarShape.CAR_H * d.y)
	if side_zone(zone):
		return Vector3(w.x, w.y, CarShape.HALF_W)
	var y := CurveKit.top_y(top, w.x)
	return Vector3(w.x, y if not is_nan(y) else w.y, 0.0)


## ¿La zona está en un costado (el golpe llega de lado)? La puerta, la aleta y la ventanilla («luna», unidad 4m).
static func side_zone(zone: String) -> bool:
	return zone == "puerta" or zone == "aleta" or zone == "luna"


## Capa del color de unas marcas: la más honda que cortan, la carrocería si llegan a ella o «la atraviesan» si su
## profundidad pasa del espesor de la pintura y la chapa. -1 si no hay marca.
static func mark_layer(marks: Dictionary, target: Dictionary) -> int:
	var layers: Variant = marks.get("layers", [])
	var n: int = (layers as Array).size() if layers is Array else int(layers)
	if n <= 0:
		return -1
	var body: Variant = target.get("body")
	var paint_um := 110.0
	var total_um := paint_um + (float(body.t) if body != null else 0.0)
	var depth := float(marks.get("depthUm", 0.0))
	if body != null and depth >= total_um - 1e-6:
		return LAYER_THROUGH
	if bool(marks.get("reachesBody", false)):
		return LAYER_BODY
	return clampi(n - 1, 0, 3)


## Lo que sube el labio de unas marcas, en fracciones de su hondura: el volumen que el arado aparta y no arranca,
## 1 − f_ab (Hokkirigawa y Kato 1988, la fracción arrancada del motor: marks.fab), con la anchura del labio igual a la del medio
## surco (dibujo). 0 sin dato.
static func lip_of(marks: Dictionary) -> float:
	if not marks.has("fab"):
		return 0.0
	return clampf(1.0 - float(marks.fab), 0.0, 1.0)


## Una punzada sin atravesar (unidad 4s): el cono de la punta en c (coordenadas del plano del daño), con el diámetro en la
## superficie (hole_um) y la hondura (depth_um) de la punción del motor, y su labio.
static func pit(c: Vector2, hole_um: float, depth_um: float, lip: float, axis: int, hit: int, seed: float) -> Dictionary:
	return { "c": c, "r": hole_um / 2.0e6, "petals": 0, "axis": axis, "hit": hit, "seed": seed, "pit_um": depth_um, "lip": lip }


## Las rayas de count garras en groups patas, que salen de p0 (m) en la dirección dir (±1 en x) y miden len_m sobre la
## chapa, sin pasar de su panel. hw: medio ancho (m); layer: la capa. Dibujo: dónde va cada garra.
static func claw_rakes(p0: Vector3, axis: int, count: int, groups: int, kind: String, len_m: float, dir: float, panel: Vector2,
		hw: float, layer: int, hit: int, top: PackedVector2Array, seed_text: String, depth_um := 0.0, lip := 0.0) -> Array:
	var out: Array = []
	var rng := Rng.new(Rng.seed_of(seed_text))
	var per := ceili(float(count) / float(maxi(groups, 1)))
	var gap: float = CLAW_GAP.get(kind, 0.025)
	var sep: float = PAW_SEP.get(kind, 0.15) if groups > 1 else 0.0
	if axis == AXIS_SIDE:
		# en un costado, las dos patas una encima de otra, más juntas, y todo por encima del paso de rueda y por debajo de la
		# cintura (lo que hay entre los dos es la chapa: dibujo)
		sep = minf(sep, SIDE_PAW_SEP)
		var half := sep * 0.5 + gap * float(per - 1) * 0.5 + 0.02
		var x1 := clampf(p0.x + dir * len_m, panel.x, panel.y)
		var floor_y := 0.0
		for k in 9:
			floor_y = maxf(floor_y, CarShape.arch_top(lerpf(p0.x, x1, float(k) / 8.0)))
		p0.y = clampf(p0.y, floor_y + half, maxf(floor_y + half, SIDE_TOP_Y - half))
	var made := 0
	for g in groups:
		for c in per:
			if made >= count:
				break
			made += 1
			var across := (float(g) - float(groups - 1) * 0.5) * sep + (float(c) - float(per - 1) * 0.5) * gap
			across += (rng.next() - 0.5) * gap * 0.3
			var x0 := p0.x + (rng.next() - 0.5) * 0.03
			var x1: float
			if axis == AXIS_TOP:
				x1 = walk_top(top, x0, len_m, dir, panel.x, panel.y)
				var drift := (rng.next() - 0.5) * 0.02 * absf(x1 - x0)
				out.append({ "a": Vector2(x0, p0.z + across), "b": Vector2(x1, p0.z + across + drift), "hw": hw, "layer": layer,
					"axis": axis, "hit": hit, "depth_um": depth_um, "lip": lip })
			else:
				x1 = clampf(x0 + dir * len_m, panel.x, panel.y)
				var drop := (rng.next() - 0.5) * 0.02 * absf(x1 - x0)
				out.append({ "a": Vector2(x0, p0.y + across), "b": Vector2(x1, p0.y + across + drop), "hw": hw, "layer": layer,
					"axis": axis, "hit": hit, "depth_um": depth_um, "lip": lip })
	return out


## Daños de un golpe (impact(), unidad 1k con los añadidos de la 4d y la 4g). ctx: zone, draw (el de la zona del golpe o
## de MovingCar.ZONES, o null), target, kind («ave», «mamifero», «corredora» o «teropodo»), kicker, size (alto, largo y envergadura, m), claws
## (garras que tocan: MovingCar.BODIES[…].contact), contact_mm, dir (±1: hacia dónde resbala a lo largo del coche), hit
## (número del golpe), shift (desplazamiento del punto del golpe en el panel, m: los golpes que se acumulan no caen uno
## encima de otro) y top (CarShape.top_curve()).
static func from_hit(hit: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := empty()
	if hit.is_empty() or not bool(hit.get("ok", false)):
		return out
	var zone: String = ctx.zone
	var top: PackedVector2Array = ctx.top
	var axis := AXIS_SIDE if side_zone(zone) else AXIS_TOP
	var p0 := impact_point(zone, ctx.get("draw"), top)
	var shift: Vector2 = ctx.get("shift", Vector2.ZERO)
	var panel: Vector2 = CarShape.PANELS.get(zone, Vector2(0.0, CarShape.CAR_L))
	p0.x = clampf(p0.x + shift.x, panel.x + 0.02, panel.y - 0.02)
	if axis == AXIS_TOP:
		p0.z += shift.y
		var y := CurveKit.top_y(top, p0.x)
		if not is_nan(y):
			p0.y = y
	else:
		p0.y += shift.y
	var hit_id: int = ctx.get("hit", 0)
	var kind: String = ctx.get("kind", "mamifero")
	var kicker: bool = ctx.get("kicker", false)
	var target: Dictionary = ctx.target
	var metal: bool = target.get("body") != null and bool(target.body.get("metal", true))
	var dir: float = ctx.get("dir", -1.0)
	var size: Vector3 = ctx.get("size", Vector3(1.0, 1.0, 0.0))
	var groups := 1 if kicker or int(ctx.get("claws", 4)) <= 2 else 2
	var seed := "%s|%s|%d" % [zone, ctx.get("claw_id", ""), hit_id]
	out.focus = p0
	# abolladura: dent.patches hoyos bajo los apoyos
	var dent: Variant = hit.get("dent")
	if dent != null and bool(dent.get("applies", false)) and float(dent.depthMm) > 0.0:
		var depth := float(dent.depthMm) / 1000.0
		var core := float(ctx.get("contact_mm", DEFAULT_CONTACT_MM)) / 1000.0
		var big := maxf(maxf(core * DENT_CORE_SPREAD, depth * DENT_SPREAD), 0.05)
		var patches := int(dent.get("patches", 1))
		for k in patches:
			var c := p0
			if axis == AXIS_SIDE:
				# de lado golpea con el cuerpo (hombro y cadera): a lo largo del coche
				c.x += (float(k) - float(patches - 1) * 0.5) * size.y * 0.55 / maxf(float(patches - 1), 1.0)
			elif patches >= 4:
				c.x += (0.5 - float(k / 2)) * size.y * 0.45
				c.z += (float(k % 2) - 0.5) * float(PAW_SEP.get(kind, 0.2))
			elif patches >= 2:
				c.z += (float(k) - float(patches - 1) * 0.5) * float(PAW_SEP.get(kind, 0.2))
			if axis == AXIS_TOP:
				var y := CurveKit.top_y(top, c.x)
				if not is_nan(y):
					c.y = y
			out.dents.append({ "c": c, "r": big, "core": core, "depth": depth, "axis": axis, "hit": hit_id })
		out.focus_m = maxf(float(out.focus_m), big * 1.2)
	# surcos, ranuras o tajos
	var marks: Dictionary = hit.get("marks", {})
	var count := int(marks.get("count", 0))
	var layer := mark_layer(marks, target)
	if bool(ctx.get("glass", false)):
		# en el vidrio no hay capas de pintura: una garra más dura que él lo raya (el shader de las lunas lo pinta claro)
		layer = 0 if float(marks.get("depthUm", 0.0)) > 0.0 else -1
	var len_m := float(marks.get("lengthMm", 0.0)) / 1000.0
	var hw := float(marks.get("widthUm", 0.0)) / 2.0e6
	if count > 0 and layer >= 0 and len_m > 0.0:
		out.grooves = claw_rakes(p0, axis, count, groups, kind, len_m, dir, panel, hw, layer, hit_id, top, seed,
			float(marks.get("depthUm", 0.0)), lip_of(marks))
		out.focus_m = maxf(float(out.focus_m), 0.08)
	# punciones que atraviesan: un agujero donde entra cada garra; las que no, la punzada de la punta (unidad 4s)
	var pn: Variant = hit.get("puncture")
	if pn != null and not bool(pn.get("through", false)) and not bool(ctx.get("glass", false)) \
			and float(pn.get("depthUm", 0.0)) > float(marks.get("depthUm", 0.0)) + 0.5 and float(pn.get("holeUm", 0.0)) > 0.0:
		var n_p := 1 if kicker else maxi(count, int(ctx.get("claws", 4)))
		var starts_p: Array = out.grooves
		if starts_p.is_empty():
			starts_p = claw_rakes(p0, axis, n_p, groups, kind, 0.0, dir, panel, 0.0, 0, hit_id, top, seed)
		var rng_p := Rng.new(Rng.seed_of(seed + "|punzadas"))
		for g: Dictionary in starts_p.slice(0, mini(n_p, MAX_HOLES)):
			out.holes.append(pit(g.a, float(pn.holeUm), float(pn.depthUm), lip_of(marks), axis, hit_id, rng_p.next()))
	if pn != null and bool(pn.get("through", false)):
		var r := float(pn.get("holeUm", 0.0)) / 2.0e6
		var n := 1 if kicker else maxi(count, int(ctx.get("claws", 4)))
		var starts: Array = out.grooves
		if starts.is_empty():
			starts = claw_rakes(p0, axis, n, groups, kind, 0.0, dir, panel, 0.0, 0, hit_id, top, seed)
		var rng := Rng.new(Rng.seed_of(seed + "|agujeros"))
		for g: Dictionary in starts.slice(0, mini(n, MAX_HOLES)):
			out.holes.append({ "c": g.a, "r": r, "petals": PETALS if metal else 0, "axis": axis, "hit": hit_id, "seed": rng.next(),
				"pit_um": 0.0, "lip": 0.0 })
		out.focus_m = maxf(float(out.focus_m), r * 12.0)
	# el parabrisas laminado: una estrella de grietas con su telaraña bajo cada apoyo
	var shield: Variant = hit.get("windshield")
	if shield != null and bool(shield.get("cracked", false)):
		var patches := int(hit.get("dent", {}).get("patches", 2)) if hit.get("dent") != null else 2
		patches = clampi(patches, 1, 4)
		var over := float(shield.get("peakN", 1.0)) / maxf(float(shield.get("bendN", 1.0)), 1e-6)
		var big := lerpf(CRACK_R.x, CRACK_R.y, clampf(log(maxf(over, 1.0)) / log(20.0), 0.0, 1.0))
		var rng := Rng.new(Rng.seed_of(seed + "|grietas"))
		for k in patches:
			var c := p0
			c.z += (float(k) - float(patches - 1) * 0.5) * float(PAW_SEP.get(kind, 0.2)) * 1.4
			out.cracks.append({ "c": c, "r": big, "seed": rng.next() * 100.0, "radials": 11.0 + floorf(rng.next() * 6.0),
				"hit": hit_id, "kind": 0 })
		out.focus_m = maxf(float(out.focus_m), big * 1.1)
	# la ventanilla templada que estalla (sideWindow, cuando la física la golpee: Glazing.tempered_result)
	var sw: Variant = hit.get("sideWindow")
	if sw != null and bool(sw.get("shattered", false)):
		var pane := "rear" if String(sw.get("pane", "front")) == "rear" else "front"
		out.shatter[pane] = 1.0
		out.shatter.frag_m = float(sw.get("fragmentMm", 5.6)) / 1000.0
	return out


## Daños del animal quieto encima (hold_report): las marcas de sus garras y el parabrisas que se agrieta bajo su peso
## (windshield). ctx: como from_hit, con zone la zona en la que se agarra, feet el punto de sus patas (m) y, desde la unidad
## 4s:
##   - speed: lo que hay a la velocidad del deslizador (CarSpeedMarks.at, a través del estado: marks_now): el surco de cada
##     garra con la carga de esa velocidad (hondura, ancho, capas, si raja el panel) y la punta clavada (puncture: la
##     punzada o, si atraviesa, el agujero). Sin ella, las marcas de su peso (scen.scratch) o, asustado, sus desgarros
##     (defense.tear), como hasta la 4r.
##   - tips: dónde están las puntas de las garras que tocan el panel (m, en el coche; las da la vista con la pose del
##     animal): cada surco sale de una punta y mide lo que resbala (lengthMm, o el desgarro del asustado; el animal resbala
##     hacia atrás con el aire: el surco va de la punta hacia atrás, por el panel, como los desgarros); la punzada, en la
##     punta. Sin tips, desde las patas, de dibujo (claw_rakes).
## Cuántas: las garras que agarran (claws: MovingCar.BODIES[…].contact).
static func from_hold(scen: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := empty()
	if scen.is_empty() or not bool(scen.get("ok", false)):
		return out
	var zone: String = ctx.zone
	var top: PackedVector2Array = ctx.top
	var feet: Vector3 = ctx.feet
	var kind: String = ctx.get("kind", "mamifero")
	var seed := "%s|%s|quieto" % [zone, ctx.get("claw_id", "")]
	var dfn: Variant = scen.get("defense")
	var sm: Dictionary = ctx.get("speed", {})
	var glass := bool(ctx.get("glass", false))
	var target: Dictionary = ctx.target
	var metal: bool = target.get("body") != null and bool(target.body.get("metal", true))
	var marks: Dictionary = {}
	var len_m := 0.0
	if not sm.is_empty():
		marks = sm.marks
		var tear_mm: Variant = (dfn.tear as Dictionary).get("lengthMm") if dfn != null else null
		len_m = float(tear_mm if tear_mm != null else marks.get("lengthMm", 0.0)) / 1000.0
	elif dfn != null:
		marks = dfn.tear
		len_m = float(marks.get("lengthMm", 0.0)) / 1000.0
	elif ctx.has("speed"):
		# la gráfica del daño aún no ha llegado del hilo: las de su peso, parado
		marks = scen.get("scratch", {})
		len_m = float((scen.get("holdCtx", {}) as Dictionary).get("slideMm", 0.0)) / 1000.0
	# unidad 4s: la raja que corre por el panel (CarTear, a través de la vista: tear_mm) alarga los surcos que atraviesan
	len_m = maxf(len_m, float(ctx.get("tear_mm", 0.0)) / 1000.0)
	var side := side_zone(zone)
	var axis := AXIS_SIDE if side else AXIS_TOP
	var panel: Vector2 = CarShape.hold_panel(zone, Vector2(0.0, CarShape.CAR_L))  # unidad 4v: la luneta
	var count := int(ctx.get("claws", 4))
	var tips: Array = (ctx.get("tips", []) as Array).slice(0, count)
	var layer := mark_layer(marks, target) if not marks.is_empty() else -1
	if glass:
		layer = 0 if float(marks.get("depthUm", 0.0)) > 0.0 else -1
	var on_paint: bool = CarShape.TEAR_ZONES.has(zone) or glass
	var hw := float(marks.get("widthUm", 0.0)) / 2.0e6
	var depth := float(marks.get("depthUm", 0.0))
	var lip := lip_of(marks)
	if on_paint and layer >= 0 and Js.truthy(marks.get("scratched", depth > 0.0)) and hw > 0.0:
		if tips.is_empty():
			var p0 := feet
			p0.x = clampf(p0.x, panel.x, panel.y)
			out.grooves = claw_rakes(p0, axis, count, 1 if count <= 2 else 2, kind, len_m, -1.0, panel, hw, layer, 0, top, seed, depth, lip)
		else:
			for t: Vector3 in tips:
				var a := Vector2(t.x, t.y if side else t.z)
				var bx: float
				if side:
					bx = clampf(t.x - len_m, panel.x, panel.y)
				else:
					bx = walk_top(top, clampf(t.x, panel.x, panel.y), len_m, -1.0, panel.x, panel.y)
				out.grooves.append({ "a": a, "b": Vector2(bx, a.y), "hw": hw, "layer": layer, "axis": axis, "hit": 0,
					"depth_um": depth, "lip": lip })
		out.focus = feet if tips.is_empty() else tips[0]
		out.focus_m = 0.08
	# la punta clavada: la punzada (o el agujero, si atraviesa) en cada garra que toca
	var pn: Variant = sm.get("puncture") if not sm.is_empty() else null
	if pn != null and on_paint and not glass and float(pn.get("holeUm", 0.0)) > 0.0:
		var punct_um := float(sm.get("punctUm", pn.get("depthUm", 0.0)))
		var through := Js.truthy(sm.get("punctThrough", pn.get("through", false)))
		if through or punct_um > depth + 0.5:
			var starts: Array = []
			for t: Vector3 in tips:
				starts.append(Vector2(t.x, t.y if side else t.z))
			if starts.is_empty():
				for g: Dictionary in claw_rakes(feet, axis, count, 1 if count <= 2 else 2, kind, 0.0, -1.0, panel, 0.0, 0, 0, top, seed):
					starts.append(g.a)
			var rng := Rng.new(Rng.seed_of(seed + "|punzadas"))
			for c: Vector2 in starts.slice(0, MAX_HOLES):
				if through:
					out.holes.append({ "c": c, "r": float(pn.holeUm) / 2.0e6, "petals": PETALS if metal else 0, "axis": axis, "hit": 0,
						"seed": rng.next(), "pit_um": 0.0, "lip": 0.0 })
				else:
					out.holes.append(pit(c, float(pn.holeUm), punct_um, lip, axis, 0, rng.next()))
			if out.focus == Vector3.INF:
				out.focus = feet if tips.is_empty() else tips[0]
				out.focus_m = 0.08
	var shield: Variant = scen.get("windshield")
	if shield != null and bool(shield.get("cracked", false)):
		hold_cracks(out, shield, ctx, tips, seed)  # unidad 4v: las de lo que tapa al conductor (CarGlass.view_loss)
	hold_glass(out, scen, ctx)  # unidad 4v: la luneta que estalla bajo el animal
	return out


## La lupa de la vista: el daño más fino del último golpe del conjunto (o del animal quieto encima) y el campo que hay que
## ver para enseñarlo (m): los agujeros de las garras de una pata (LUPA_HOLE veces el radio de un agujero, como poco
## LUPA_MIN_M), los surcos o las ranuras de una pata (LUPA_RAKE_M), una estrella de grietas (2,2 veces su radio) o, si solo
## hay abolladuras, la última (2,4 veces su radio). { on, focus (m, en la chapa), field_m }. top: CarShape.top_curve().
static func lupa(s: Dictionary, top: PackedVector2Array) -> Dictionary:
	var last := -INF
	for k: String in ["holes", "grooves", "cracks", "dents"]:
		for it: Dictionary in s[k]:
			last = maxf(last, float(it.hit))
	var off := { "on": false, "focus": Vector3.ZERO, "field_m": 0.1, "normal": Vector3.BACK }
	var pick := func(k: String) -> Array: return (s[k] as Array).filter(func(it: Dictionary) -> bool: return float(it.hit) == last)
	var holes: Array = pick.call("holes")
	var grooves: Array = pick.call("grooves")
	if not holes.is_empty() or not grooves.is_empty():
		var first: Dictionary = holes[0] if not holes.is_empty() else grooves[0]
		var a: Vector2 = first.c if not holes.is_empty() else first.a
		var axis: int = first.axis
		# las garras de la misma pata: las que empiezan a menos de 6 cm de la primera
		var sum := Vector2.ZERO
		var n := 0
		for it: Dictionary in (holes if not holes.is_empty() else grooves):
			var q: Vector2 = it.c if not holes.is_empty() else it.a
			if q.distance_to(a) < 0.06:
				sum += q
				n += 1
		var c := sum / float(maxi(n, 1))
		var field := LUPA_RAKE_M
		if not holes.is_empty():
			field = maxf(LUPA_MIN_M, float(first.r) * LUPA_HOLE)
		elif not grooves.is_empty():
			var g: Dictionary = grooves[0]
			var along: Vector2 = (g.b - g.a)
			if along.length() > 0.001:
				c += along.normalized() * minf(LUPA_RAKE_M * 0.3, along.length() * 0.5)
		var fp := surface_point(c, axis, top)
		return { "on": true, "focus": fp, "field_m": field, "normal": surface_normal(fp, axis, top) }
	var cracks: Array = pick.call("cracks")
	if not cracks.is_empty():
		var cc: Vector3 = cracks[0].c
		return { "on": true, "focus": cc, "field_m": float(cracks[0].r) * 2.2, "normal": surface_normal(cc, AXIS_TOP, top) }
	var dents: Array = pick.call("dents")
	if not dents.is_empty():
		var dc: Vector3 = dents[0].c
		return { "on": true, "focus": dc, "field_m": float(dents[0].r) * 2.4, "normal": surface_normal(dc, int(dents[0].axis), top) }
	return off


## La normal de la chapa en p (m): la del costado a su altura o la de la parte de arriba con su pendiente en x.
static func surface_normal(p: Vector3, axis: int, top: PackedVector2Array) -> Vector3:
	if axis == AXIS_SIDE:
		return CarShape.body_normal(p.y)
	var y0 := CurveKit.top_y(top, p.x - 0.02)
	var y1 := CurveKit.top_y(top, p.x + 0.02)
	if is_nan(y0) or is_nan(y1):
		return Vector3.UP
	return Vector3(-(y1 - y0) / 0.04, 1.0, 0.0).normalized()


## Un punto de un panel (sus coordenadas en el plano del daño) en la chapa (m): en un costado, sobre su cara; arriba,
## sobre la silueta.
static func surface_point(c: Vector2, axis: int, top: PackedVector2Array) -> Vector3:
	if axis == AXIS_SIDE:
		return Vector3(c.x, c.y, CarShape.body_hw(c.y))
	var y := CurveKit.top_y(top, c.x)
	return Vector3(c.x, y if not is_nan(y) else CarShape.CAR_H, c.y)


## Las listas de los arrays de uniformes de los shaders (del tamaño justo; los shaders miran n_*).
static func pack(s: Dictionary) -> Dictionary:
	var gab: Array[Vector4] = []
	var gp: Array[Vector4] = []
	for g: Dictionary in s.grooves:
		gab.append(Vector4(g.a.x, g.a.y, g.b.x, g.b.y))
		gp.append(Vector4(g.hw, float(g.layer) + clampf(float(g.get("depth_um", 0.0)), 0.0, 9999.0) / 10000.0,
			float(g.axis) + 2.0 * roundf(clampf(float(g.get("lip", 0.0)), 0.0, 1.0) * 500.0), float(g.hit)))
	var hc: Array[Vector4] = []
	var hp: Array[Vector4] = []
	for h: Dictionary in s.holes:
		var pit_um := float(h.get("pit_um", 0.0))
		hc.append(Vector4(h.c.x, h.c.y, h.r, -1.0 - clampf(float(h.get("lip", 0.0)), 0.0, 1.0) if pit_um > 0.0 else float(h.petals)))
		hp.append(Vector4(float(h.axis), float(h.hit), float(h.seed), pit_um))
	var dc: Array[Vector4] = []
	var dp: Array[Vector4] = []
	for d: Dictionary in s.dents:
		dc.append(Vector4(d.c.x, d.c.y, d.c.z, d.r))
		dp.append(Vector4(d.depth, float(d.axis), d.core, float(d.hit)))
	var cc: Array[Vector4] = []
	var cp: Array[Vector4] = []
	for c: Dictionary in s.cracks:
		cc.append(Vector4(c.c.x, c.c.y, c.c.z, c.r))
		cp.append(Vector4(c.seed, c.radials, float(c.hit), float(c.kind)))
	return { "n_grooves": gab.size(), "groove_ab": _pad(gab, MAX_GROOVES), "groove_p": _pad(gp, MAX_GROOVES),
		"n_holes": hc.size(), "hole_c": _pad(hc, MAX_HOLES), "hole_p": _pad(hp, MAX_HOLES),
		"n_dents": dc.size(), "dent_c": _pad(dc, MAX_DENTS), "dent_p": _pad(dp, MAX_DENTS),
		"n_cracks": cc.size(), "crack_c": _pad(cc, MAX_CRACKS), "crack_p": _pad(cp, MAX_CRACKS) }


static func _pad(a: Array[Vector4], n: int) -> Array[Vector4]:
	var out: Array[Vector4] = a.duplicate()
	while out.size() < n:
		out.append(Vector4.ZERO)
	return out


# ════════ Cristales (unidad 4v) ════════
# El parabrisas agrietado bajo el animal, dibujado como lo cuenta la estimación de lo que tapa al conductor (CarGlass.view_loss:
# una estrella de STAR_RADIUS_M por apoyo si lo parte el peso, o grietas cortas a lo largo de los surcos si lo agrietan las
# garras), y la luneta templada que estalla bajo el animal (shatter.luneta). La física es la del estado; aquí, dónde va cada
# cosa (dibujo).

const CarGlass = preload("res://core/lab/car_glass.gd")
## Radio de la estrella de cada garra dura que agrieta el vidrio al apoyarse (m): la franja de la estimación (dibujo).
const CLAW_CRACK_R := 0.04


## La luneta en la mezcla de dos conjuntos (la más estallada) y el tamaño de sus trozos.
static func merge_glass(out: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var la := float((a.shatter as Dictionary).get("luneta", 0.0))
	var lb := float((b.shatter as Dictionary).get("luneta", 0.0))
	out.shatter["luneta"] = maxf(la, lb)
	if lb > 0.0:
		out.shatter.frag_m = float(b.shatter.frag_m)
	elif la > 0.0 and float(out.shatter.front) + float(out.shatter.rear) <= 0.0:
		out.shatter.frag_m = float(a.shatter.frag_m)


## Las grietas del parabrisas con el animal quieto encima: si lo parte su peso, una estrella de CarGlass.STAR_RADIUS_M bajo
## cada apoyo (las 2 patas de delante y las 2 de detrás de un mamífero, o los 2 pies); si lo agrietan sus garras, una estrella
## pequeña en cada punta que toca (tips; sin ellas, junto a las patas), como mucho MAX_CRACKS.
static func hold_cracks(out: Dictionary, shield: Dictionary, ctx: Dictionary, tips: Array, seed: String) -> void:
	var top: PackedVector2Array = ctx.top
	var feet: Vector3 = ctx.feet
	var kind: String = ctx.get("kind", "mamifero")
	var vl: Variant = shield.get("viewLoss")
	var by_claws: bool = vl != null and String(vl.cause) == "grieta"
	var rng := Rng.new(Rng.seed_of(seed + "|grietas"))
	var spots: Array = []
	if by_claws:
		for t: Vector3 in tips.slice(0, MAX_CRACKS):
			spots.append(t)
		if spots.is_empty():
			for k in 2:
				spots.append(feet + Vector3(0.0, 0.0, (float(k) - 0.5) * float(PAW_SEP.get(kind, 0.2))))
	else:
		var patches := 4 if kind == "mamifero" else 2
		var size: Vector3 = ctx.get("size", Vector3(1.0, 1.0, 0.0))
		for k in patches:
			var c := feet
			if patches >= 4:
				c.x += (0.5 - float(k / 2)) * minf(size.y * 0.45, 0.5)
				c.z += (float(k % 2) - 0.5) * float(PAW_SEP.get(kind, 0.2)) * 1.6
			else:
				c.z += (float(k) - 0.5) * float(PAW_SEP.get(kind, 0.2)) * 1.6
			spots.append(c)
	var r := CLAW_CRACK_R if by_claws else CarGlass.STAR_RADIUS_M
	for c: Vector3 in spots:
		var p := c
		var y := CurveKit.top_y(top, p.x)
		if not is_nan(y):
			p.y = y
		out.cracks.append({ "c": p, "r": r, "seed": rng.next() * 100.0, "radials": 8.0 + floorf(rng.next() * 6.0), "hit": 0, "kind": 1 })
	out.cracks = (out.cracks as Array).slice(maxi(0, (out.cracks as Array).size() - MAX_CRACKS))
	out.focus = feet
	out.focus_m = maxf(r * 2.0, CRACK_R.x)


## La luneta templada que estalla bajo el animal: la de setup (estalla parado) o la de la velocidad del deslizador
## (ctx.speed.rearShattered), con el tamaño de sus trozos (Glazing.fragment_size_mm).
static func hold_glass(out: Dictionary, scen: Dictionary, ctx: Dictionary) -> void:
	var rear: Variant = scen.get("rearWindow")
	if rear == null:
		return
	var sm: Dictionary = ctx.get("speed", {})
	var shattered := bool(rear.shattered) or bool(sm.get("rearShattered", false))
	if not shattered:
		return
	var rw: Variant = rear if bool(rear.shattered) else sm.get("rearWindow")
	out.shatter["luneta"] = 1.0
	out.shatter.frag_m = float(rw.fragmentMm) / 1000.0 if rw != null else 0.0056
