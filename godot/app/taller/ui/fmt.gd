## Taller industrial · números de la interfaz. Todo pasa por core/shared/js.gd (to_fixed, el redondeo de
## JavaScript), con coma decimal y punto de miles, como los mensajes de core/taller (12.250 rpm; 1,5 mm). Sin valor
## (null, NaN), «—»; infinito, «sin fin». Aquí solo se da formato: ningún cálculo físico.
extends RefCounted

const Js = preload("res://core/shared/js.gd")

const QUALITY := { "primary": "primaria", "secondary": "secundaria", "estimate": "estimación" }


static func is_value(x: Variant) -> bool:
	return (x is float or x is int) and not is_nan(float(x))


## x con decimals decimales: «12.250», «1,5», «—».
static func num(x: Variant, decimals: int = 0) -> String:
	if not is_value(x):
		return "—"
	var v := float(x)
	if is_inf(v):
		return "sin fin" if v > 0.0 else "−sin fin"
	var s := Js.to_fixed(v, decimals)
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var int_part := s
	var frac := ""
	var dot := s.find(".")
	if dot >= 0:
		int_part = s.substr(0, dot)
		frac = s.substr(dot + 1)
	if int_part.length() > 3:
		var grouped := ""
		var n := 0
		for i in range(int_part.length() - 1, -1, -1):
			grouped = int_part[i] + grouped
			n += 1
			if n % 3 == 0 and i > 0:
				grouped = "." + grouped
		int_part = grouped
	var out := int_part + ("," + frac if frac != "" else "")
	var zero := out.replace("0", "").replace(",", "").replace(".", "") == ""
	return ("−" + out) if neg and not zero else out


## Número con unidad: «12,5 mm» o «—». Con espacio de no separación: en una columna estrecha (teléfono) la unidad
## no se queda sola en la línea siguiente.
static func unit(x: Variant, decimals: int, u: String) -> String:
	if not is_value(x):
		return "—"
	if u == "":
		return num(x, decimals)
	return "%s\u00a0%s" % [num(x, decimals), u]


## Número con los decimales justos para su tamaño (3 cifras significativas, como mucho `max_dec` decimales).
static func auto(x: Variant, max_dec: int = 3) -> String:
	if not is_value(x):
		return "—"
	var a := absf(float(x))
	var d := 0
	if a < 1.0:
		d = 3
	elif a < 10.0:
		d = 2
	elif a < 100.0:
		d = 1
	return num(x, mini(d, max_dec))


## Intervalo «a–b».
static func span(a: Variant, b: Variant, decimals: int) -> String:
	return "%s–%s" % [num(a, decimals), num(b, decimals)]


## Calidad de un dato: «primaria», «secundaria» o «estimación».
static func quality(q: Variant) -> String:
	return QUALITY.get(str(q), str(q))


## Tiempo en segundos: «83,0 s» o «2 min 05 s».
static func seconds(t: Variant) -> String:
	if not is_value(t):
		return "—"
	var v := float(t)
	if is_inf(v):
		return "sin fin"
	if v < 120.0:
		return unit(v, 1, "s")
	var m := floori(v / 60.0)
	var s := int(Js.js_round(v - m * 60.0))
	if s == 60:
		m += 1
		s = 0
	return "%d min %02d s" % [m, s]
