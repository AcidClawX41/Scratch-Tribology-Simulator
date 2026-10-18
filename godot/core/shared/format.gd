## Capa compartida · formatos de números para los textos de las dos secciones.
##
## Port 1:1 de los formatos de packages/core/src/physics.js (fmtF, fmtJ, fmtP, fmtDepth, hvBar, fToT, tToF) y de
## fmtLen de lab.js. Los veredictos del laboratorio los incrustan en sus textos, así que tienen que salir idénticos
## a los de JavaScript: todo pasa por core/shared/js.gd (toFixed de JS, no "%.1f", que redondea los empates al par).
## Unidades: fuerza N · energía J · presión MPa · profundidad y longitud µm (mm a partir de 1000 µm, y cm entre
## paréntesis a partir de 1 cm).
## Uso: const Format = preload("res://core/shared/format.gd"), y después Format.fmt_depth(um).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")

## Extremos del deslizador de fuerza (N). Es logarítmico: f_to_t y t_to_f pasan de fuerza a posición 0-1.
const FMIN := 0.5
const FMAX := 2000.0


## Posición 0-1 del deslizador para una fuerza f (N).
static func f_to_t(f: float) -> float:
	return (Js.log10(Contact.clamp_js(f, FMIN, FMAX)) - Js.log10(FMIN)) / (Js.log10(FMAX) - Js.log10(FMIN))


## Fuerza (N) para una posición t (0-1) del deslizador: inversa de f_to_t.
static func t_to_f(t: float) -> float:
	return V8.js_pow(10.0, Js.log10(FMIN) + t * (Js.log10(FMAX) - Js.log10(FMIN)))


## f_to_t con otra escala logarítmica, de fmin a fmax (N): las mismas operaciones en el mismo orden, así que con FMIN y
## FMAX da lo mismo que f_to_t, al bit. La escala de cada herramienta la da Lab.force_range().
static func f_to_t_in(f: float, fmin: float, fmax: float) -> float:
	return (Js.log10(Contact.clamp_js(f, fmin, fmax)) - Js.log10(fmin)) / (Js.log10(fmax) - Js.log10(fmin))


## t_to_f con otra escala logarítmica, de fmin a fmax (N): inversa de f_to_t_in.
static func t_to_f_in(t: float, fmin: float, fmax: float) -> float:
	return V8.js_pow(10.0, Js.log10(fmin) + t * (Js.log10(fmax) - Js.log10(fmin)))


## Fuerza legible en newtons: 0.5 · 4.0 · 30 · 2000.
static func fmt_f(f: float) -> String:
	return Js.to_fixed(f, 0) if f >= 10.0 else Js.to_fixed(f, 1)


## Fuerza f (N) legible en milinewtons: 0.01 · 0.25 · 2.5 · 30 · 1000.
static func fmt_mn(f: float) -> String:
	var mn := f * 1000.0
	if mn >= 10.0:
		return Js.to_fixed(mn, 0)
	return Js.to_fixed(mn, 1) if mn >= 1.0 else Js.to_fixed(mn, 2)


## Fuerza f (N) con la unidad de su escala: "4.0 N" (fmt_f) o "2.5 mN" (fmt_mn).
static func fmt_force(f: float, unit: String) -> String:
	return ("%s mN" % fmt_mn(f)) if unit == "mN" else ("%s N" % fmt_f(f))


## 2.0 · fuerza f (N) con la unidad que le toca, de newtons a nanonewtons (la carga que aguanta de lado una punta
## afilada; laboratorio, unidad 4i), con las cifras de fmt_f: 45 N · 13 mN · 2.3 mN · 3.7 µN · 0.36 nN.
static func fmt_small_force(f: float) -> String:
	if f >= 1.0:
		return "%s N" % fmt_f(f)
	for u: Array in [[1e-3, "mN"], [1e-6, "µN"]]:
		if f >= float(u[0]):
			var x := f / float(u[0])
			return "%s %s" % [Js.to_fixed(x, 0) if x >= 10.0 else Js.to_fixed(x, 1), u[1]]
	var nn := f * 1e9
	if nn >= 1.0:
		return "%s nN" % (Js.to_fixed(nn, 0) if nn >= 10.0 else Js.to_fixed(nn, 1))
	return "%s nN" % Js.to_fixed(nn, 2)


## 2.0 · radio de una punta legible (la punta afilada de unas garras reforjadas; laboratorio, unidades 4i y 4i-B2): 138 µm ·
## 18.0 µm · 2.35 µm · 155 nm · 40 nm.
static func fmt_tip_um(um: float) -> String:
	if um >= 100.0:
		return "%s µm" % Js.to_fixed(um, 0)
	if um >= 10.0:
		return "%s µm" % Js.to_fixed(um, 1)
	if um >= 1.0:
		return "%s µm" % Js.to_fixed(um, 2)
	return "%s nm" % Js.to_fixed(um * 1000.0, 0)


## Energía legible en julios: 0.35 · 1.4 · 160.
static func fmt_j(j: float) -> String:
	if j >= 10.0:
		return Js.to_fixed(j, 0)
	return Js.to_fixed(j, 1) if j >= 1.0 else Js.to_fixed(j, 2)


## Presión o dureza legible: 0.25 · 30.0 · 196.
static func fmt_p(p: float) -> String:
	if p >= 100.0:
		return Js.to_fixed(p, 0)
	return Js.to_fixed(p, 1) if p >= 10.0 else Js.to_fixed(p, 2)


## Longitud de la barra de dureza (4-100 %), logarítmica entre 2 y 10 000 HV.
static func hv_bar(hv: float) -> float:
	return Contact.clamp_js((Js.log10(hv) - Js.log10(2.0)) / (Js.log10(10000.0) - Js.log10(2.0)) * 100.0, 4.0, 100.0)


## Profundidad legible: µm con 1 decimal por debajo de 10 µm, mm a partir de 1000 µm.
static func fmt_depth(um: float) -> String:
	if um >= 1000.0:
		return Js.to_fixed(um / 1000.0, 1) + " mm"
	return (Js.to_fixed(um, 1) if um < 10.0 else Js.to_fixed(um, 0)) + " µm"


## Longitud legible con centímetros a partir de 1 cm: 350 µm · 6.1 mm · 35 mm (3.5 cm).
static func fmt_len(um: float) -> String:
	if um < 10000.0:
		return fmt_depth(um)
	# hasta 100 mm, con el mismo decimal que fmt_depth (Ø 10.5 mm, no 11), sin «.0» de relleno
	var mm := um / 1000.0
	var mm_txt := Js.to_fixed(mm, 0) if mm >= 100.0 else Js.to_fixed(mm, 1).trim_suffix(".0")
	return "%s mm (%s cm)" % [mm_txt, Js.to_fixed(um / 10000.0, 1)]
