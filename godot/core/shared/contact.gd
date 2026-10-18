## Capa física compartida · mecánica de contacto.
##
## La usan las dos secciones del programa. El laboratorio la usa con uñas, garras y colmillos contra piel,
## pintura o vidrio. El taller la usa con un grano abrasivo contra acero en la radial y la afiladora, y con la
## punta de una herramienta. Port 1:1 de packages/core/src/physics.js, que sigue siendo el oráculo: los tests
## comparan con él.
##   - Punta esfero-cónica: radio R = √(área/π) y semiángulo α (tip_geometry, contact_radius…).
##   - Ratio de dureza herramienta/objetivo: eficiencia 0 → 1 entre r = 0,8 y 2,0 (Pintaude; Richardson).
##   - Hertz: fracción plástica φ del contacto (plastificación cuando p0 = 1,6·Y; H ≈ 2,8·Y, Tabor).
##   - Resolución de la profundidad: estática, por capas y por energía (bisección y trapecios).
## Unidades: N · mm · MPa · mJ (= N·mm). E en GPa.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

const HV_MPA := 9.807  # 1 HV = 9,807 MPa
## Constantes del contacto (las mismas claves y valores que MODEL en physics.js)
const CONTACT := {
	"rOff": 0.8,  # r por debajo del cual la punta no raya (Pintaude; Richardson)
	"rFull": 2.0,  # r a partir del cual la punta ya no se deforma (hipótesis del modelo)
	"tabor": 2.8,  # H ≈ 2,8·Y (Tabor)
	"yieldOnset": 1.6,  # plastificación bajo una esfera cuando p0 = 1,6·Y (Johnson)
	"nu": 0.3,  # coeficiente de Poisson común
}
const H_MAX := 400.0  # mm: más allá no tiene sentido físico en el banco
const DEG := PI / 180.0


## Math.max(a, Math.min(b, x)), en el mismo orden que JavaScript.
static func clamp_js(x: float, a: float, b: float) -> float:
	return maxf(a, minf(b, x))


static func smoothstep(a: float, b: float, x: float) -> float:
	var t := clamp_js((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Punta esfero-cónica: tangencia esfera-cono en a_t = R·cos α, h_t = R·(1 − sin α). amax (mm) es el radio de la
## sección en la base (solo limita el agujero que abre en una chapa).
static func tip_geometry(area_mm2: float, alpha_deg: float, amax: float = INF) -> Dictionary:
	var R := sqrt(area_mm2 / PI)
	var al := alpha_deg * DEG
	return { "R": R, "tanA": V8.js_tan(al), "at": R * V8.js_cos(al), "ht": R * (1.0 - V8.js_sin(al)), "amax": amax }


## Radio del contacto a (mm) cuando la punta se ha hundido h (mm).
static func contact_radius(tip: Dictionary, h: float) -> float:
	if h <= 0.0:
		return 0.0
	if h <= tip["ht"]:
		return sqrt(maxf(2.0 * tip["R"] * h - h * h, 0.0))
	return tip["at"] + (h - tip["ht"]) * tip["tanA"]


## Radio del agujero que la herramienta abre en una chapa: nunca más ancho que su propia sección.
static func hole_radius(tip: Dictionary, h: float) -> float:
	return minf(contact_radius(tip, h), tip.get("amax", INF))


## Inversa: profundidad h (mm) que corresponde a un radio de contacto a (mm).
static func depth_for_radius(tip: Dictionary, a: float) -> float:
	if a <= 0.0:
		return 0.0
	if a <= tip["at"]:
		return tip["R"] - sqrt(tip["R"] * tip["R"] - a * a)
	return tip["ht"] + (a - tip["at"]) / tip["tanA"]


## Eficiencia de la punta según el ratio de durezas r (0 → cede la punta, 1 → punta rígida).
static func hardness_efficiency(r: float) -> float:
	return smoothstep(CONTACT["rOff"], CONTACT["rFull"], r)


## Fracción plástica del contacto φ (Hertz): 0 si todo es elástico, 1 si la presión media llega a H.
## F en N, R en mm, E en GPa, H en MPa; f_mu = factor de von Mises √(1+3μ²) si hay fricción.
static func plastic_fraction(F: float, R: float, Etool: float, Etarget: float, H: float, f_mu: float = 1.0) -> Dictionary:
	var nu: float = CONTACT["nu"]
	var Estar := 1000.0 / ((1.0 - nu * nu) * (1.0 / Etool + 1.0 / Etarget))  # MPa
	var aH := Js.cbrt((3.0 * F * R) / (4.0 * Estar))  # mm
	var p0 := (3.0 * F) / (2.0 * PI * aH * aH)  # MPa
	var q := (p0 * f_mu) / (CONTACT["yieldOnset"] * (H / CONTACT["tabor"]))
	var q_full: float = (1.5 * CONTACT["tabor"]) / CONTACT["yieldOnset"]  # p_media = H
	return { "phi": smoothstep(1.0, q_full, q), "p0": p0, "aH": aH }


## Menor profundidad h (mm) en la que la resistencia res(h) (N) iguala a la fuerza F (bisección).
static func solve_static(F: float, res: Callable, h_max: float = H_MAX) -> float:
	if F <= 0.0:
		return 0.0
	if res.call(h_max) < F:
		return h_max
	var lo := 0.0
	var hi := h_max
	for i in 80:
		var mid := (lo + hi) / 2.0
		if res.call(mid) >= F:
			hi = mid
		else:
			lo = mid
	return hi


## Primer h (mm) en que res(h) ≥ F cuando res crece dentro de cada capa pero puede CAER al pasar a la
## siguiente (la piel: tras la dermis, la grasa cede con mucha menos fuerza). breaks: fronteras en mm.
static func solve_layered(F: float, res: Callable, breaks: Array, h_max: float = H_MAX) -> float:
	if F <= 0.0:
		return 0.0
	var edges: Array[float] = [0.0]
	for b in breaks:
		if b > 0.0 and b < h_max:
			edges.append(float(b))
	edges.append(h_max)
	for i in range(1, edges.size()):
		var end := h_max if i == edges.size() - 1 else edges[i] - 1e-9
		if res.call(end) < F:
			continue
		var lo := edges[i - 1]
		var hi := end
		for k in 80:
			var mid := (lo + hi) / 2.0
			if res.call(mid) >= F:
				hi = mid
			else:
				lo = mid
		return hi
	return h_max


## Trabajo ∫_a^b F_res dh (mJ) por trapecios; INF si en el tramo hay una «pared» (la punta no la corta).
static func work_between(res: Callable, a: float, b: float, n: int) -> float:
	var w := 0.0
	var x0 := a
	var f0: float = res.call(a)
	for k in range(1, n + 1):
		var x := a + ((b - a) * k) / n
		var f: float = res.call(x)
		if not is_finite(f):
			return INF
		w += 0.5 * (f0 + f) * (x - x0)
		x0 = x
		f0 = f
	return w


## Trabajo de penetración ∫₀ʰ F_res dh (J) hasta la profundidad final, por tramos entre breaks (mm). Se
## detiene en una pared que la punta no corta.
static func absorbed_work(res: Callable, h: float, breaks: Array = []) -> float:
	var edges: Array[float] = [0.0]
	for b in breaks:
		if b > 0.0 and b < h:
			edges.append(float(b))
	edges.append(h)
	var w := 0.0
	for i in range(1, edges.size()):
		var a := edges[i - 1]
		var b := edges[i] if i == edges.size() - 1 else edges[i] - 1e-9
		var n := 80
		var x0 := a
		var f0: float = res.call(a)
		for k in range(1, n + 1):
			var x := a + ((b - a) * k) / n
			var f: float = res.call(x)
			if not is_finite(f) or not is_finite(f0):
				return w / 1000.0
			w += 0.5 * (f0 + f) * (x - x0)
			x0 = x
			f0 = f
	return w / 1000.0


## Pasos de solve_energy: h_i = h0·(h_max/h0)^(i/N), de 1e-5 mm a h_max en N pasos geométricos.
const _ENERGY_N := 300
const _ENERGY_H0 := 1e-5


static func _energy_steps(h_max: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(_ENERGY_N + 1)
	for i in range(0, _ENERGY_N + 1):
		out[i] = _ENERGY_H0 * V8.js_pow(h_max / _ENERGY_H0, float(i) / _ENERGY_N)
	return out


## Los pasos con el h_max de siempre (H_MAX), calculados una vez al cargar: pow de V8 en GDScript es lento y el golpe
## los recorre en cada ensayo. Es una constante (nadie la escribe después): segura para hilos.
static var _ENERGY_STEPS: PackedFloat64Array = _energy_steps(H_MAX)


## Profundidad en la que el trabajo de penetración ∫F_res iguala la energía E (mJ) más el trabajo de F.
static func solve_energy(Emj: float, F: float, res: Callable, h_max: float = H_MAX) -> float:
	var N := _ENERGY_N
	var steps: PackedFloat64Array = _ENERGY_STEPS if h_max == H_MAX else _energy_steps(h_max)
	var W := 0.0
	var h_prev := 0.0
	for i in range(0, N + 1):
		var h := steps[i]
		var dW := work_between(res, h_prev, h, 2)
		if W + dW - Emj - F * h >= 0.0:
			var lo := h_prev
			var hi := h
			for k in 40:
				var mid := (lo + hi) / 2.0
				if W + work_between(res, h_prev, mid, 16) - Emj - F * mid >= 0.0:
					hi = mid
				else:
					lo = mid
			return hi
		W += dW
		h_prev = h
	return h_max
