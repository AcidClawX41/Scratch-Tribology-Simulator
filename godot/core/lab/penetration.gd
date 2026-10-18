## Tribología biológica · penetración profunda en la piel, por zonas del cuerpo (modelo 2.0).
##
## Lo que cambia respecto a la 1.x (physics.gd → _skin_result; FISICA.md, apartados 7-9), con su fuente:
##   1. Zonas del cuerpo (zones.gd): capas propias y, debajo, hueso o la cavidad abdominal.
##   2. La grieta se abre en TODAS las capas que atraviesa la parte que se ensancha de la punta, no solo en la capa
##      de la punta, y nunca es más ancha que la herramienta (su base, como en las chapas: Contact.hole_radius).
##      La energía de la grieta es ∫ 2·J(z)·ρ(h − z) dz y su derivada es la fuerza:
##        F_grieta(h) = 2·Σ_i J_i·[ρ(h − z_i,arriba) − ρ(h − z_i,abajo)]
##      con ρ(s) el radio de la herramienta a una distancia s por detrás del ápice y J_i = jC de cada capa. Con una
##      sola capa y una punta sin base es exactamente la 1.x, 2·J·a(h) (grieta plana en modo I que avanza con la
##      punta: Shergold & Fleck 2005). La resistencia ya no cae de golpe al salir de la dermis: el cono sigue
##      ensanchando la grieta de la dermis mientras pasa por ella.
##   3. Fricción en los flancos (Shergold & Fleck 2005: «el roce de los flancos hace que la carga suba con la
##      profundidad»). La grieta acuñada aprieta los flancos con la presión media de Fregonese & Bacca (2022),
##      calculada para un sólido de Ogden con α = 9, el de la piel humana (Shergold, Fleck & Radford 2006):
##        ⟨p⟩ = μ·[0,8613 + 1,434·(J/(μ·ρ))^0,844]     (μ = E/3, material incompresible)
##      y el roce de Coulomb τ = ξ·⟨p⟩ sobre la superficie lateral enterrada:
##        F_roce(h) = ∫₀ʰ ξ·⟨p⟩(z)·2π·ρ(h − z) dz,  con ξ = 0,05 (estimación: el centro de lo que Fregonese & Bacca
##      ajustan en sólidos blandos, 0,02-0,06; es el dato más incierto del modelo: con 0,1 un colmillo de víbora
##      empujado con 4 N ya no pasaría de la dermis).
##   4. Hueso: la punta que llega a la cortical tiene que indentarla (dureza, FISICA.md §4-5):
##        F_hueso(δ) = (H/η)·π·[ρ(δ)² − ρ(δ − t)²]
##      con δ lo que ha entrado, t la cortical y η = Contact.hardness_efficiency(HV_punta/HV_hueso). Por debajo de
##      r = 1,25, el umbral de la «marca tenue» de la 1.x (Richardson 1968: la superficie resiste a un abrasivo que
##      no la supera en un 25 %), el hueso es una pared y detiene la punta: toda la queratina (r ≤ 0,83) y la dentina
##      de los colmillos contra el húmero y los metacarpianos (r = 1,06-1,16) en cuanto el contacto sale del esmalte de
##      la punta. Pasada la cortical, la médula (como grasa, estimación).
##   5. La punta de los colmillos es de esmalte (fang_enamel.gd): cuenta en la dureza con la que indenta el hueso.
## Romper la superficie es Sting.puncture_force (fractura con la jC de la capa de arriba, o Davis 2004 en su rango):
## no se duplica aquí. skin_report() junta la punción, el rayado por zonas y lo que la 1.x ya calcula: es la referencia
## de la integración en compute() (docs/fisica/pulido-biologia.md, §9).
## Unidades: fuerza N · longitud mm (las profundidades de salida, en µm) · presión MPa · energía mJ = N·mm (J en la
## salida) · tenacidad kJ/m² = N/mm · E del tejido kPa. Determinista (V8.js_pow, V8.js_atan2), sin estado estático:
## cada ensayo prepara su propio «banco» (rig), un diccionario que nadie más toca.
## Uso: const Penetration = preload("res://core/lab/penetration.gd"), y después Penetration.puncture({...}).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Physics = preload("res://core/lab/physics.gd")
const Sting = preload("res://core/lab/sting.gd")
const Zones = preload("res://core/lab/zones.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")

const SRC_SHERGOLD_2005 := "Shergold OA, Fleck NA (2005). Experimental investigation into the deep penetration of soft solids by sharp and blunt punches, with application to the piercing of skin. J. Biomech. Eng. 127:838-848 (una punta afilada entra abriendo una grieta plana en modo I que avanza con ella; el roce en los flancos hace que la carga suba con la profundidad). doi:10.1115/1.1992528"
const SRC_FREGONESE_2022 := "Fregonese S, Bacca M (2022). How friction and adhesion affect the mechanics of deep penetration in soft solids. Soft Matter 18:6882-6887 (P = P₀ + ⟨τ⟩·2πR·d; ⟨p⟩/μ = ⟨p⟩₀/μ + B₁·(G_c/μR)^b₁, tabla 1: α = 9 → 0,8613, 1,434 y 0,844; texto en arXiv:2412.02013). doi:10.1039/d2sm00638c"
const SRC_SHERGOLD_2006 := "Shergold OA, Fleck NA, Radford D (2006). The uniaxial stress versus strain response of pig skin and silicone rubber at low and high strain rates. Int. J. Impact Eng. 32:1384-1402, tabla 1 (piel humana: Ogden de un término con α = 9, μ = 0,11 MPa). doi:10.1016/j.ijimpeng.2004.11.010"

## Constantes del modelo 2.0 de penetración (fuentes arriba y en docs/fisica/pulido-biologia.md).
const MODEL := {
	"flankFriction": 0.05,  # ξ, roce de Coulomb herramienta-tejido húmedo (estimación: 0,02-0,06 ajustado en sólidos blandos)
	"ogdenAlpha": 9.0,  # piel humana (Shergold 2006)
	"flankP0": 0.8613,  # ⟨p⟩₀/μ con α = 9 (Fregonese & Bacca 2022, tabla 1)
	"flankB1": 1.434,  # B₁ con α = 9
	"flankB1Exp": 0.844,  # b₁ con α = 9
	"fallbackEKpa": 210.0,  # E de las capas sin dato (capa córnea, epidermis, fascia): el de la dermis (estimación)
	"boneMinRatio": 1.25,  # r mínima para entrar en el hueso: la de la marca de verdad de la 1.x (Richardson 1968, FISICA §4)
	"marrowJC": 0.41,  # médula amarilla ≈ grasa: jC de la grasa (estimación)
	"marrowEKpa": 1.9,  # ídem, E de la grasa
	"gridN": 360,  # puntos de las tablas del perfil
	"gridS0": 1e-6,  # mm: primer punto de las tablas
	"marchN": 240,  # pasos de la rejilla del resolvedor (más las fronteras de capa y del hueso)
}


# ════════ PERFIL DE LA HERRAMIENTA ════════
# ρ(s): radio a una distancia s (mm) por detrás del ápice: esfera de radio R hasta ht, cono de semiángulo α y, si la
# herramienta tiene base (amax, la de resolve_tool), cilindro. Es Contact.hole_radius. Para el roce hacen falta
# ∫₀ˢ ρ du y ∫₀ˢ ρ^q du (q = 1 − b₁): se tabulan una vez por ensayo, así el resolvedor no llama a potencias.

## Radio de la herramienta (mm) a una distancia s (mm) por detrás del ápice.
static func tool_radius(tip: Dictionary, s: float) -> float:
	return Contact.hole_radius(tip, s)


## Profundidad (mm) a la que la herramienta alcanza su anchura máxima (INF si no tiene base).
static func cap_depth(tip: Dictionary) -> float:
	var amax: float = tip.get("amax", INF)
	return Contact.depth_for_radius(tip, amax) if is_finite(amax) else INF


## arcsen con la atan2 de V8 (determinista).
static func _asin(y: float) -> float:
	return V8.js_atan2(y, sqrt(maxf(0.0, 1.0 - y * y)))


## ∫₀ˣ √(2R·u − u²) du (mm²), x ≤ R: la parte esférica. Cerca de 0 los dos términos exactos casi se anulan: serie.
static func _sphere_c1(R: float, x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x < 0.05 * R:
		var sx := sqrt(x)
		var x32 := x * sx
		return sqrt(2.0 * R) * (2.0 / 3.0 * x32 - 0.1 / R * x * x32 - 1.0 / (112.0 * R * R) * x * x * x32)
	return (x - R) / 2.0 * sqrt(maxf(0.0, 2.0 * R * x - x * x)) + R * R / 2.0 * (_asin((x - R) / R) + PI / 2.0)


## ∫₀ˣ (2R·u − u²)^(q/2) du, x ≤ R: la parte esférica de ∫ρ^q, con la serie de (1 − u/2R)^(q/2) hasta el 4.º término
## (u/2R ≤ 0,5 en la esfera de cualquier punta del banco: error < 0,1 %). k2r = (2R)^(q/2) y xc = x^(q/2) si ya están
## calculados (make_profile los lleva por recurrencia a lo largo de su rejilla geométrica).
static func _sphere_cq(R: float, x: float, q: float, k2r: float = -1.0, xc: float = -1.0) -> float:
	if x <= 0.0:
		return 0.0
	var c := q / 2.0
	if k2r < 0.0:
		k2r = V8.js_pow(2.0 * R, c)
	var base := k2r * x * (xc if xc >= 0.0 else V8.js_pow(x, c))  # (2R)^c · x^(c+1)
	var y := x / (2.0 * R)
	var a1 := -c
	var a2 := c * (c - 1.0) / 2.0
	var a3 := -c * (c - 1.0) * (c - 2.0) / 6.0
	var a4 := c * (c - 1.0) * (c - 2.0) * (c - 3.0) / 24.0
	return base * (1.0 / (c + 1.0) + a1 * y / (c + 2.0) + a2 * y * y / (c + 3.0) + a3 * y * y * y / (c + 4.0)
		+ a4 * y * y * y * y / (c + 5.0))


## ∫₀ˢ ρ du (mm²), exacta por tramos (esfera, cono, base).
static func radius_integral(tip: Dictionary, s: float) -> float:
	if s <= 0.0:
		return 0.0
	var R: float = tip.R
	var ht: float = tip.ht
	var sc := cap_depth(tip)
	var x := minf(s, sc)
	var out := _sphere_c1(R, minf(x, ht))
	if x > ht:
		var d := x - ht
		out += float(tip.at) * d + 0.5 * float(tip.tanA) * d * d
	if s > sc:
		out += float(tip.amax) * (s - sc)
	return out


## ∫₀ˢ ρ^q du (mm^(1+q)), exacta por tramos salvo la serie de la esfera.
static func radius_power_integral(tip: Dictionary, s: float, q: float) -> float:
	if s <= 0.0:
		return 0.0
	var R: float = tip.R
	var ht: float = tip.ht
	var sc := cap_depth(tip)
	var x := minf(s, sc)
	var out := _sphere_cq(R, minf(x, ht), q)
	if x > ht:
		var at: float = tip.at
		var rho := at + (x - ht) * float(tip.tanA)
		out += (V8.js_pow(rho, q + 1.0) - V8.js_pow(at, q + 1.0)) / ((q + 1.0) * float(tip.tanA))
	if s > sc:
		out += V8.js_pow(float(tip.amax), q) * (s - sc)
	return out


## Perfil tabulado hasta s_max (mm): { tip, q, s, c1, cq, sMax, invLogRatio }. Rejilla geométrica desde 1 nm; las
## partes constantes (la esfera entera, hasta la base) se calculan una vez, así cada punto cuesta como mucho una potencia.
## En la esfera, x^(q/2) va por recurrencia a lo largo de la rejilla (x_k = s0·r^k → x_k^c = s0^c·(r^c)^k), sin potencia
## por punto (unidad 4b: la tabla se hace en cada ensayo de punción); el error relativo, < 10⁻¹³, queda muy por debajo
## del de la interpolación lineal de la tabla.
static func make_profile(tip: Dictionary, s_max: float, q: float) -> Dictionary:
	var n: int = MODEL.gridN
	var s0: float = MODEL.gridS0
	var top := maxf(s_max, s0 * 10.0)
	var ratio := V8.js_pow(top / s0, 1.0 / float(n - 1))
	var R: float = tip.R
	var ht: float = tip.ht
	var at: float = tip.at
	var tan_a: float = tip.tanA
	var sc := cap_depth(tip)
	var amax: float = tip.get("amax", INF)
	var c := q / 2.0
	var k2r := V8.js_pow(2.0 * R, c)
	var sph_end := minf(ht, sc)  # donde acaba la esfera (o empieza la base, si llega antes)
	var c1_sph := _sphere_c1(R, sph_end)
	var cq_sph := _sphere_cq(R, sph_end, q, k2r)
	var at_q1 := at * V8.js_pow(at, q) if sc > ht else 0.0
	var c1_cap := radius_integral(tip, sc) if is_finite(sc) else 0.0
	var cq_cap := radius_power_integral(tip, sc, q) if is_finite(sc) else 0.0
	var amax_q := V8.js_pow(amax, q) if is_finite(amax) else 0.0
	var s := PackedFloat64Array()
	var c1 := PackedFloat64Array()
	var cq := PackedFloat64Array()
	s.resize(n)
	c1.resize(n)
	cq.resize(n)
	var x := s0
	var xc := V8.js_pow(s0, c)  # x^c, por recurrencia
	var rc := V8.js_pow(ratio, c)
	for k in n:
		if k == n - 1:
			x = top
			xc = V8.js_pow(top, c)
		s[k] = x
		if x <= sph_end:
			c1[k] = _sphere_c1(R, x)
			cq[k] = _sphere_cq(R, x, q, k2r, xc)
		elif x <= sc:
			var d := x - ht
			var rho := at + d * tan_a
			c1[k] = c1_sph + at * d + 0.5 * tan_a * d * d
			cq[k] = cq_sph + (rho * V8.js_pow(rho, q) - at_q1) / ((q + 1.0) * tan_a)
		else:
			c1[k] = c1_cap + amax * (x - sc)
			cq[k] = cq_cap + amax_q * (x - sc)
		x *= ratio
		xc *= rc
	return {
		"tip": tip, "q": q, "s": s, "c1": c1, "cq": cq, "sMax": top, "invLogRatio": 1.0 / V8.js_log(ratio),
	}


## Tramo de la tabla que contiene s: el k con s[k] ≤ s < s[k+1] (−1 antes de la tabla, n − 1 después). Búsqueda
## binaria con comparaciones: el tramo es exacto y el mismo en todas las plataformas (unidad 4b: antes se estimaba con
## un logaritmo y se corregía; da el mismo k, sin el coste del logaritmo).
static func _index(prof: Dictionary, s: float) -> int:
	return _index_xs(prof.s, s)


static func _index_xs(xs: PackedFloat64Array, s: float) -> int:
	var n := xs.size()
	if s < xs[0]:
		return -1
	if s >= xs[n - 1]:
		return n - 1
	var lo := 0
	var hi := n - 1  # xs[lo] ≤ s < xs[hi]
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if xs[mid] <= s:
			lo = mid
		else:
			hi = mid
	return lo


## Valor de una columna ("c1" o "cq") de la tabla en s, con su tramo k (_index): interpolación lineal; antes de la
## tabla, proporcional (tramo despreciable junto al ápice); después, la integral exacta.
static func _interp(prof: Dictionary, col: String, s: float, k: int) -> float:
	return _interp_ys(prof, prof.s, prof[col], col == "c1", s, k)


## _interp con la columna ya en la mano (ys; c1: si es la de ∫ρ o la de ∫ρ^q): la misma cuenta.
static func _interp_ys(prof: Dictionary, xs: PackedFloat64Array, ys: PackedFloat64Array, c1: bool, s: float, k: int) -> float:
	if s <= 0.0:
		return 0.0
	if k < 0:
		return ys[0] * s / xs[0]
	if k >= xs.size() - 1:
		return radius_integral(prof.tip, s) if c1 else radius_power_integral(prof.tip, s, prof.q)
	var t := (s - xs[k]) / (xs[k + 1] - xs[k])
	return ys[k] + (ys[k + 1] - ys[k]) * t


## Valor de una columna de la tabla en s.
static func _table(prof: Dictionary, col: String, s: float) -> float:
	return _interp(prof, col, s, _index(prof, s))


# ════════ PRESIÓN EN LOS FLANCOS ════════

## Presión media (MPa) de la grieta acuñada sobre un flanco de radio r_mm (Fregonese & Bacca 2022, α = 9), en un
## tejido de módulo e_kpa (kPa) y tenacidad j (kJ/m² = N/mm).
static func flank_pressure_mpa(e_kpa: float, j: float, r_mm: float) -> float:
	var mu := e_kpa / 3.0 / 1000.0
	if r_mm <= 0.0:
		return INF
	return mu * (float(MODEL.flankP0) + float(MODEL.flankB1) * V8.js_pow(j / (mu * r_mm), float(MODEL.flankB1Exp)))


## E (kPa) de una capa para el roce: el suyo o, si no tiene (capa córnea, epidermis, fascia), el de la dermis.
static func layer_e_kpa(layer: Dictionary) -> float:
	var e: Variant = layer.get("E")
	return float(e) if e != null and float(e) > 0.0 else float(MODEL.fallbackEKpa)


# ════════ BANCO DE UN ENSAYO ════════

## Prepara el banco de un ensayo: perfil tabulado, capas en mm con sus constantes de grieta y de roce, hueso.
##   tip: Contact.tip_geometry(area, alpha, baseR) · tool: Physics.resolve_tool(p) · stk: Zones.stack(zona)
##   bone: Zones.bone(zona) o null · xi: roce de los flancos · h_max: profundidad máxima (mm), el alcance.
static func make_rig(tip: Dictionary, tool: Dictionary, stk: Array, bone: Variant, xi: float, h_max: float) -> Dictionary:
	var b1: float = MODEL.flankB1Exp
	var q := 1.0 - b1
	var layers: Array = []
	for i in stk.size():
		var l: Dictionary = stk[i]
		var last: bool = i == stk.size() - 1
		layers.append(_rig_layer(float(l.from) / 1000.0, INF if last and bone == null else float(l.to) / 1000.0,
			float(l.jC), layer_e_kpa(l), xi))
	var b: Variant = null
	if bone != null:
		var from_mm: float = float(bone.fromUm) / 1000.0
		var t_mm: float = float(bone.corticalUm) / 1000.0
		b = { "from": from_mm, "t": t_mm, "hv": float(bone.hv), "H": float(bone.hv) * Contact.HV_MPA }
		layers.append(_rig_layer(from_mm + t_mm, INF, MODEL.marrowJC, MODEL.marrowEKpa, xi))  # médula
	var breaks: Array = []
	for L: Dictionary in layers:
		for x in [L.from, L.to]:
			if is_finite(x) and x > 0.0 and x < h_max and not breaks.has(x):
				breaks.append(x)
	if b != null and b.from < h_max and not breaks.has(b.from):
		breaks.append(b.from)
	breaks.sort()
	# las capas también en columnas (el resolvedor las recorre cientos de veces por ensayo: sin buscar en diccionarios)
	var cols := {}
	for key: String in ["from", "to", "J", "k1", "k2"]:
		var col := PackedFloat64Array()
		for L: Dictionary in layers:
			col.append(float(L[key]))
		cols[key] = col
	return {
		"tip": tip, "tool": tool, "prof": make_profile(tip, h_max, q), "layers": layers, "bone": b, "xi": xi,
		"hMax": h_max, "breaks": breaks, "cols": cols, "memo": {},
	}


## Capa del banco: { from, to (mm), J, k1, k2 } con dF_roce/ds = k1·ρ + k2·ρ^q.
static func _rig_layer(from_mm: float, to_mm: float, j: float, e_kpa: float, xi: float) -> Dictionary:
	var mu := e_kpa / 3.0 / 1000.0
	var b1: float = MODEL.flankB1Exp
	var k1 := 2.0 * PI * xi * mu * float(MODEL.flankP0)
	var k2 := 2.0 * PI * xi * float(MODEL.flankB1) * V8.js_pow(mu, 1.0 - b1) * V8.js_pow(j, b1)
	return { "from": from_mm, "to": to_mm, "J": j, "k1": k1, "k2": k2 }


## Fuerza de la grieta, del roce y del hueso (N) con la punta a h (mm): { crack, friction, bone, total }.
static func parts(rig: Dictionary, h: float) -> Dictionary:
	var soft := _soft(rig, h)
	var bone_n := _bone_force(rig, h)
	return { "crack": soft[0], "friction": soft[1], "bone": bone_n, "total": soft[0] + soft[1] + bone_n }


## La grieta y el roce (N) con la punta a h (mm): [crack, friction]. Recorre las capas de arriba abajo; donde una capa
## empieza justo donde acaba la de encima (todas salvo la médula), su borde de arriba es el de abajo de la anterior y se
## reutiliza (los mismos números, la mitad de búsquedas en la tabla). Es el lazo caliente del resolvedor (cientos de
## llamadas por ensayo): las cuentas de tool_radius (Contact.hole_radius), _index y _interp van en línea, iguales.
static func _soft(rig: Dictionary, h: float) -> PackedFloat64Array:
	var tip: Dictionary = rig.tip
	var R: float = tip.R
	var ht: float = tip.ht
	var at: float = tip.at
	var tan_a: float = tip.tanA
	var amax: float = tip.get("amax", INF)
	var prof: Dictionary = rig.prof
	var xs: PackedFloat64Array = prof.s
	var c1s: PackedFloat64Array = prof.c1
	var cqs: PackedFloat64Array = prof.cq
	var n := xs.size()
	var x0: float = xs[0]
	var x_end: float = xs[n - 1]
	var cols: Dictionary = rig.cols
	var lf: PackedFloat64Array = cols.from
	var lt: PackedFloat64Array = cols.to
	var lj: PackedFloat64Array = cols.J
	var lk1: PackedFloat64Array = cols.k1
	var lk2: PackedFloat64Array = cols.k2
	var crack := 0.0
	var friction := 0.0
	var prev_s := -1.0  # el borde de abajo de la capa anterior (s) y sus valores
	var prev_rho := 0.0
	var prev_c1 := 0.0
	var prev_cq := 0.0
	for i in lf.size():
		var from: float = lf[i]
		if from >= h:
			break
		var s_top: float = h - from
		var rho_top: float
		var c1_top: float
		var cq_top: float
		if s_top == prev_s:
			rho_top = prev_rho
			c1_top = prev_c1
			cq_top = prev_cq
		else:
			var s := s_top
			# tool_radius(tip, s)
			var a := 0.0
			if s > 0.0:
				a = sqrt(maxf(2.0 * R * s - s * s, 0.0)) if s <= ht else at + (s - ht) * tan_a
			rho_top = minf(a, amax)
			# _index_xs y _interp_ys
			if s <= 0.0:
				c1_top = 0.0
				cq_top = 0.0
			elif s < x0:
				c1_top = c1s[0] * s / x0
				cq_top = cqs[0] * s / x0
			elif s >= x_end:
				c1_top = radius_integral(tip, s)
				cq_top = radius_power_integral(tip, s, prof.q)
			else:
				var lo := 0
				var hi := n - 1
				while hi - lo > 1:
					var mid := (lo + hi) >> 1
					if xs[mid] <= s:
						lo = mid
					else:
						hi = mid
				var t := (s - xs[lo]) / (xs[lo + 1] - xs[lo])
				c1_top = c1s[lo] + (c1s[lo + 1] - c1s[lo]) * t
				cq_top = cqs[lo] + (cqs[lo + 1] - cqs[lo]) * t
		var sb := maxf(0.0, h - lt[i])
		var ab := 0.0
		if sb > 0.0:
			ab = sqrt(maxf(2.0 * R * sb - sb * sb, 0.0)) if sb <= ht else at + (sb - ht) * tan_a
		var rho_bot := minf(ab, amax)
		var c1_bot: float
		var cq_bot: float
		if sb <= 0.0:
			c1_bot = 0.0
			cq_bot = 0.0
		elif sb < x0:
			c1_bot = c1s[0] * sb / x0
			cq_bot = cqs[0] * sb / x0
		elif sb >= x_end:
			c1_bot = radius_integral(tip, sb)
			cq_bot = radius_power_integral(tip, sb, prof.q)
		else:
			var lo := 0
			var hi := n - 1
			while hi - lo > 1:
				var mid := (lo + hi) >> 1
				if xs[mid] <= sb:
					lo = mid
				else:
					hi = mid
			var t := (sb - xs[lo]) / (xs[lo + 1] - xs[lo])
			c1_bot = c1s[lo] + (c1s[lo + 1] - c1s[lo]) * t
			cq_bot = cqs[lo] + (cqs[lo + 1] - cqs[lo]) * t
		crack += 2.0 * lj[i] * (rho_top - rho_bot)
		friction += lk1[i] * (c1_top - c1_bot)
		friction += lk2[i] * (cq_top - cq_bot)
		prev_s = sb
		prev_rho = rho_bot
		prev_c1 = c1_bot
		prev_cq = cq_bot
	return PackedFloat64Array([crack, friction])


## La fuerza del hueso (N) con la punta a h (mm): 0 antes de llegar, INF si la punta no puede indentarlo (una pared).
static func _bone_force(rig: Dictionary, h: float) -> float:
	var b: Variant = rig.bone
	if b == null or h <= b.from:
		return 0.0
	var tip: Dictionary = rig.tip
	var d: float = h - b.from
	var a := tool_radius(tip, d)
	var a_in := tool_radius(tip, maxf(0.0, d - b.t))
	var r: float = FangEnamel.tip_hv(rig.tool, a) / b.hv
	var eta := Contact.hardness_efficiency(r) if r >= float(MODEL.boneMinRatio) else 0.0
	return INF if eta <= 0.0 else (b.H / eta) * PI * (a * a - a_in * a_in)


## Resistencia total (N) con la punta a h (mm).
static func resistance(rig: Dictionary, h: float) -> float:
	var soft := _soft(rig, h)
	return soft[0] + soft[1] + _bone_force(rig, h)


## La resistencia como Callable (para Contact.solve_energy y Contact.absorbed_work).
static func resistance_fn(rig: Dictionary) -> Callable:
	return func(h: float) -> float: return resistance(rig, h)


## Profundidades de muestreo hasta h_max: rejilla geométrica desde 0,1 µm más las fronteras de capa y del hueso.
static func _grid(rig: Dictionary, h_max: float) -> PackedFloat64Array:
	var n: int = MODEL.marchN
	var h0 := minf(1e-4, h_max)
	var ratio := V8.js_pow(h_max / h0, 1.0 / float(n))
	var pts: Array = []
	var x := h0
	for i in n:
		pts.append(x)
		x *= ratio
	pts.append(h_max)
	for bk in rig.breaks:
		if bk < h_max:
			pts.append(bk)
			pts.append(bk + 1e-9)
	pts.sort()
	var out := PackedFloat64Array()
	for p in pts:
		if out.is_empty() or p > out[out.size() - 1]:
			out.append(p)
	return out


## Recorre la rejilla hasta que la punta se para y afina el último tramo por bisección. Sin golpe (strike = false), se
## para en la primera profundidad en que la resistencia alcanza F (la resistencia puede bajar al pasar a una capa más
## blanda: por eso se recorre en orden y no se biseca a ciegas). Con golpe, donde el trabajo de penetración ∫F_res dh
## (trapecios sobre la rejilla) iguala la energía e_mj (mJ) más el trabajo del empuje F·h, como Contact.solve_energy.
## Una resistencia infinita (una pared) para la punta en ambos casos. Devuelve { h (mm), work (mJ), peak (N): la mayor
## resistencia del camino, la carga que llega a la punta en un golpe }.
static func march(rig: Dictionary, h_max: float, F: float, e_mj: float = 0.0, strike: bool = false) -> Dictionary:
	if F <= 0.0 and not strike:
		return { "h": 0.0, "work": 0.0, "peak": 0.0 }
	var g := _grid(rig, h_max)
	# la resistencia en los puntos de la rejilla es la misma en cada recorrido del mismo ensayo (el golpe, y después el
	# de la rotura o la cesión): se guarda en el banco y no se vuelve a calcular (los mismos números)
	var memo: Dictionary = rig.get("memo", {})
	var h0 := 0.0
	var r0 := 0.0
	var W := 0.0
	var peak := 0.0
	for h in g:
		var r: float
		if memo.has(h):
			r = memo[h]
		else:
			r = resistance(rig, h)
			memo[h] = r
		if _stops(r, W, r0, h0, h, F, e_mj, strike):
			var lo := h0
			var hi: float = h
			var r_hi := r
			for k in 60:
				var mid := (lo + hi) / 2.0
				var rm := resistance(rig, mid)
				if _stops(rm, W, r0, h0, mid, F, e_mj, strike):
					hi = mid
					r_hi = rm
				else:
					lo = mid
			# contra una pared la punta se queda en su borde: el último trapecio, con la resistencia de justo antes
			var r_end := r_hi if is_finite(r_hi) else resistance(rig, lo)
			return { "h": hi, "work": W + 0.5 * (r0 + r_end) * (hi - h0), "peak": maxf(peak, r_hi) }
		W += 0.5 * (r0 + r) * (h - h0)
		peak = maxf(peak, r)
		h0 = h
		r0 = r
	return { "h": h_max, "work": W, "peak": peak }


## ¿Se para la punta en h con resistencia r? (empuje: r ≥ F; golpe: trabajo ≥ energía + F·h; pared: siempre).
static func _stops(r: float, W: float, r0: float, h0: float, h: float, F: float, e_mj: float, strike: bool) -> bool:
	if not is_finite(r):
		return true
	if strike:
		return W + 0.5 * (r0 + r) * (h - h0) - e_mj - F * h >= 0.0
	return r >= F


## Primera profundidad (mm) en la que la resistencia alcanza F, hasta h_max (si no la alcanza, h_max).
static func first_crossing(rig: Dictionary, F: float, h_max: float) -> float:
	return march(rig, h_max, F).h


# ════════ ENSAYOS ════════

## Punción (empuje o golpe) en una zona. p:
##   tool: Physics.resolve_tool(...) · tip: Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
##   zone: id de zones.gd (null → la de por defecto) · force: N (el Neff de compute, con la adhesión)
##   strike: bool · energyJ: ½·m·v² (J) · xi (opcional): roce de los flancos
##   yieldN (opcional, N): la carga que la herramienta aguanta antes de CEDER sin romperse, la de una uña que se dobla
##     (bending.gd; unidad 4b). Como la rotura del colmillo, pero la herramienta sigue entera: si no llega a la fuerza
##     que rompe la piel, no perfora; si el camino le pide más, la punta se queda donde la resistencia llega a ella.
## Devuelve { zone, pierces, fPuncture, depthUm, layerId, stoppedBy ("sin perforar" | "fuerza" | "energia" |
## "alcance" | "hueso" | "rotura" | "cede"), fullReach, boneHit, boneDepthUm, boneIndentUm, bonePierced, toolBroken,
## toolLoadN, crackN, frictionN, boneN, resN, workJ, energyLeftJ, yielded, demandN }. demandN: la carga que pide el
## camino (la resistencia más alta en un golpe o enterrada hasta la base; el empuje, si no), sin el tope de la rotura ni
## de la cesión; null si un golpe choca con una pared.
static func puncture(p: Dictionary) -> Dictionary:
	var tool: Dictionary = p.tool
	var tip: Dictionary = p.tip
	var zone := Zones.resolve(p.get("zone"))
	var stk := Zones.stack(zone.id)
	var bone: Variant = Zones.bone(zone.id)
	var F: float = p.force
	var strike := Js.truthy(p.get("strike"))
	var energy_j: float = float(p.get("energyJ", 0.0)) if p.get("energyJ") != null else 0.0
	var xi: float = float(p.get("xi", MODEL.flankFriction))
	var reach: float = tool.reach
	var f_p := Sting.puncture_force(float(tool.area), stk)
	var e_mj := energy_j * 1000.0
	var yield_n: Variant = p.get("yieldN")
	var pierces := F >= f_p or (strike and e_mj >= float(Physics.MODEL.skinPunctureToughness) * float(tool.area))
	# una herramienta que cede antes de llegar a la fuerza que rompe la piel no la perfora (ni de un golpe)
	if yield_n != null and float(yield_n) < f_p:
		pierces = false
	var out := {
		"zone": zone.id, "pierces": pierces, "fPuncture": f_p, "depthUm": 0.0, "layerId": null,
		"stoppedBy": "sin perforar", "fullReach": false, "boneHit": false,
		"boneDepthUm": float(bone.fromUm) if bone != null else null, "boneIndentUm": 0.0, "bonePierced": false,
		"toolBroken": false, "toolLoadN": F, "crackN": 0.0, "frictionN": 0.0, "boneN": 0.0, "resN": 0.0, "workJ": 0.0,
		"energyLeftJ": energy_j if strike else null, "yielded": false, "demandN": F,
	}
	if not pierces:
		return out
	var rig := make_rig(tip, tool, stk, bone, xi, reach)
	var run := march(rig, reach, F, e_mj, strike)
	var h: float = run.h
	var work: float = run.work / 1000.0  # J
	# carga que soporta la punta: el empuje o, en un golpe o enterrada hasta la base, la resistencia del camino
	var full := h >= reach - 1e-9
	var load: float = run.peak if strike or full else F
	var broken := false
	var f_break: Variant = tool.get("fBreak")
	if Js.truthy(f_break) and load > float(f_break):
		broken = true
		var at_break := march(rig, reach, float(f_break))
		if at_break.h < h:
			h = at_break.h
			work = float(at_break.work) / 1000.0
	# la herramienta cede (una uña que se dobla) donde la resistencia llega a su carga de cesión: la misma receta
	var yielded := false
	if not broken and yield_n != null and load > float(yield_n):
		yielded = true
		var at_yield := march(rig, reach, float(yield_n))
		if at_yield.h < h:
			h = at_yield.h
			work = float(at_yield.work) / 1000.0
	# el residuo de la bisección contra una pared (≈10⁻¹⁸ mm) no es «entrar en el hueso»
	var bone_mm: float = float(bone.fromUm) / 1000.0 if bone != null else INF
	var wall := false
	if h > bone_mm and h - bone_mm < 1e-9 and not is_finite(resistance(rig, h)):
		h = bone_mm
		wall = true
	full = h >= reach - 1e-9
	var at_bone: bool = h >= bone_mm - 1e-9
	var pr := parts(rig, h)
	var depth_um := h * 1000.0
	var layer_id: Variant = Physics.skin_layer_at(depth_um, stk).id
	if bone != null and depth_um > float(bone.fromUm) + 1e-6:
		layer_id = "hueso" if depth_um <= float(bone.toUm) + 1e-6 else "medula"
	# quién la para: la rotura, el alcance, el hueso (si no ha atravesado la cortical) o, si no, la fuerza o la energía
	var through_cortex: bool = bone != null and depth_um > float(bone.toUm) + 1e-6
	var stopped := "fuerza"
	if broken:
		stopped = "rotura"
	elif yielded:
		stopped = "cede"
	elif full:
		stopped = "alcance"
	elif at_bone and not through_cortex:
		stopped = "hueso"
	elif strike:
		stopped = "energia"
	# Contra una pared (una punta que no puede indentar el hueso) la resistencia es infinita: lo que empuja el hueso es
	# el resto del empuje; en un golpe, depende de cómo frene la pata (no se modela) y se deja en null.
	var soft: float = pr.crack + pr.friction
	var bone_n: Variant = pr.bone
	var tool_load: Variant = load
	if broken:
		tool_load = minf(load, float(f_break))
	elif yielded:
		tool_load = minf(load, float(yield_n))
	if wall or not is_finite(pr.bone):
		bone_n = null if strike else maxf(0.0, F - soft)
	if not is_finite(float(tool_load)):
		tool_load = null if strike else F
	out.merge({
		"depthUm": depth_um, "layerId": layer_id, "stoppedBy": stopped, "fullReach": full, "boneHit": at_bone,
		"boneIndentUm": maxf(0.0, depth_um - float(bone.fromUm)) if bone != null else 0.0,
		"bonePierced": through_cortex, "toolBroken": broken,
		"toolLoadN": tool_load, "crackN": pr.crack, "frictionN": pr.friction, "boneN": bone_n,
		"resN": soft + (float(bone_n) if bone_n != null else 0.0), "workJ": work,
		"energyLeftJ": maxf(0.0, energy_j + F * h / 1000.0 - work) if strike else null,
		"yielded": yielded, "demandN": load if is_finite(load) else (null if strike else F),
	}, true)
	return out


## Nombre de la capa con ese id en la zona (el que compute() pone en `layer`): el de la capa blanda, el del hueso
## («Húmero»…) o el de la médula. null si no hay capa.
static func layer_name(zone_id: Variant, layer_id: Variant) -> Variant:
	if layer_id == null:
		return null
	if layer_id == "hueso":
		var b: Variant = Zones.bone(zone_id)
		return b.name if b != null else null
	if layer_id == Zones.MARROW.id:
		return Zones.MARROW.name
	var l: Variant = Zones.layer(Zones.stack(zone_id), String(layer_id))
	return l.name if l != null else null


## Lo que cambia con la zona en un ensayo sobre la piel (modelo 2.0): el bloque `pen` de compute() y los campos de
## siempre que salen de él (docs/fisica/pulido-biologia.md, guía de integración). Lo que no depende de la zona lo
## calcula el motor 1.x como siempre y llega en q:
##   tool, tip: los de compute() · zone: id (null o desconocido → brazo) · puncture: method == "puncion"
##   strike: bool · Neff: N (fuerza + adhesión) · energyJ: J del golpe · passes: pasadas
##   stress: MPa (el esfuerzo de rayado de la 1.x) · tearForce: N (el Ft de la 1.x) · ruptures: bool (la 1.x)
##   xi (opcional): roce de los flancos · yieldN (opcional, al punzar): la carga con que cede la herramienta (puncture)
## Devuelve { zone, zoneName, method, depthUm, layerId, layer, bleeds, fullReach, boneHit, boneDepthUm, epiUm, deepUm }
## y además, en punción, todos los campos de puncture(); al rayar, { ruptures, abrasionUm, cutUm, excoriation,
## excoriationBleeds, bleedPasses }.
static func skin_report(q: Dictionary) -> Dictionary:
	var zone := Zones.resolve(q.get("zone"))
	var stk := Zones.stack(zone.id)
	var epi := Zones.epidermis_end_um(stk)
	var tool: Dictionary = q.tool
	var bone: Variant = Zones.bone(zone.id)
	var out := {
		"zone": zone.id, "zoneName": zone.name, "epiUm": epi, "deepUm": Zones.deep_um(zone.id),
		"boneDepthUm": float(bone.fromUm) if bone != null else null,
	}
	if Js.truthy(q.get("puncture")):
		var p := {
			"tool": tool, "tip": q.tip, "zone": zone.id, "force": float(q.Neff), "strike": Js.truthy(q.get("strike")),
			"energyJ": float(q.get("energyJ", 0.0)) if q.get("energyJ") != null else 0.0,
		}
		if q.get("xi") != null:
			p.xi = q.xi
		if q.get("yieldN") != null:
			p.yieldN = q.yieldN
		var pr := puncture(p)
		out.merge(pr, true)
		out.merge({
			"method": "puncion", "layer": layer_name(zone.id, pr.layerId) if pr.pierces else null,
			"bleeds": pr.pierces and float(pr.depthUm) > epi,
		}, true)
		return out
	# Rayado: la abrasión sin romper (umbrales de esfuerzo de la 1.x, profundidades de la zona) o el corte que rasga Ft.
	var lim := Zones.abrasion_limits(zone.id)
	var stress: float = q.stress
	var passes := maxf(float(q.get("passes", 1.0)) if q.get("passes") != null else 1.0, 1.0)
	var excoriation := stress >= float(Physics.MODEL.skinStressExcoriate)
	var abr := 0.0
	if excoriation:
		abr = Zones.excoriation_depth_um(zone.id, passes)
	elif stress >= float(Physics.MODEL.skinStressAbrade):
		abr = lim.whiteUm
	var ruptures := Js.truthy(q.get("ruptures"))
	var cut: Dictionary = tear(float(q.tearForce), zone.id, float(tool.reach)) if ruptures else {}
	var cut_um: float = cut.get("depthUm", 0.0)
	var depth := maxf(abr, cut_um)
	var exc_bleeds: bool = not ruptures and excoriation and passes >= float(lim.bleedPasses)
	var layer_id: Variant = Physics.skin_layer_at(depth, stk).id if depth > 0.0 else null
	out.merge({
		"method": "rayado", "depthUm": depth, "layerId": layer_id, "layer": layer_name(zone.id, layer_id),
		"bleeds": depth > epi or exc_bleeds, "fullReach": cut.get("fullReach", false), "boneHit": cut.get("boneHit", false),
		"ruptures": ruptures, "abrasionUm": abr, "cutUm": cut_um, "excoriation": excoriation,
		"excoriationBleeds": exc_bleeds, "bleedPasses": lim.bleedPasses,
	}, true)
	return out


## Rayado: el corte que rasga una fuerza de desgarro Ft (N) en la zona (Physics.skin_tear_depth con sus capas), hasta
## el hueso (una garra no rasga hueso) y hasta el alcance de la herramienta (reach, mm). { depthUm, layerId, boneHit,
## fullReach }.
static func tear(Ft: float, zone_id: Variant, reach_mm: float) -> Dictionary:
	var zone := Zones.resolve(zone_id)
	var stk := Zones.stack(zone.id)
	var depth_um := Physics.skin_tear_depth(Ft, stk) * 1000.0
	var bone_um := Zones.bone_depth_um(zone.id)
	var reach_um := reach_mm * 1000.0
	var d := minf(depth_um, minf(bone_um, reach_um))
	return {
		"zone": zone.id, "depthUm": d, "layerId": Physics.skin_layer_at(d, stk).id if d > 0.0 else null,
		"boneHit": is_finite(bone_um) and d >= bone_um - 1e-6 and bone_um < reach_um,
		"fullReach": d >= reach_um - 1e-6,
	}
