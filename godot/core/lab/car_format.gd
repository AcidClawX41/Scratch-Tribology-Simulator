## Tribología biológica · coche en marcha: los formatos de los números de sus textos, en un solo sitio (unidad 4j).
##
## Los usan MovingCar (veredictos e informe de daños), MovingCarState (lecturas, porqués, datos y fuentes) y la tarjeta
## y su barra de energía. Las funciones de antes con el mismo nombre (MovingCar.fmt_long, fmt_energy, _fmt_n, _kmh_txt;
## MovingCarState.fmt_n, fmt_kmh, fmt_w, fmt_pct, fmt_share, fmt_g, num, fmt_band, fmt_n_band; MovingCarEnergy.share_txt)
## siguen existiendo y delegan aquí: los textos son los de siempre, al carácter.
## Todo pasa por core/shared/js.gd y format.gd (los números como JavaScript: nunca str(), round() ni "%.1f").
## Unidades: fuerza N (kN desde 10 kN) · velocidad km/h · potencia W (kW desde 1 kW) · longitud µm, mm y cm (m desde
## 1 m) · energía J (kJ desde 1000 J) · aceleración g.
## Uso: const CarFormat = preload("res://core/lab/car_format.gd"), y después CarFormat.fmt_n(f).
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")


## Fuerza legible: N hasta 10 kN (Format.fmt_f), kN con un decimal después y, desde 1 MN (lo que aguantan de lado unas garras
## clavadas hasta la base), MN con un decimal en vez de «3032.0 kN» (unidad 4o); con su signo («-2648 N»), sin «-0.0 N».
static func fmt_n(n: float) -> String:
	var a := absf(n)
	var s := (Format.fmt_f(a) + " N") if a < 10000.0 else (
		(Js.to_fixed(a / 1000.0, 1) + " kN") if a < 1.0e6 else (Js.to_fixed(a / 1.0e6, 1) + " MN"))
	return ("-" + s) if n < 0.0 and a >= 0.05 else s


## Fuerza legible que puede ser muy pequeña (la que aguanta de lado la punta afilada de una garra reforjada; la rotura de
## las garras, ClawFracture): como fmt_n y, por debajo de 0,05 N, en mN, µN o nN (Format.fmt_small_force) en vez de
## «0.0 N».
static func fmt_n_small(f: float) -> String:
	if f > 0.0 and f < 0.05:
		return Format.fmt_small_force(f)
	return fmt_n(f)


## Banda de dos fuerzas: «de 2.8 N a 17.6 N».
static func fmt_n_band(lo: float, hi: float) -> String:
	return "de %s a %s" % [fmt_n(lo), fmt_n(hi)]


## Velocidad en km/h sin decimales y sin la unidad; «∞» si no es finita (no se suelta ni a 400 km/h).
static func kmh_txt(v: float) -> String:
	return Js.to_fixed(v, 0) if is_finite(v) else "∞"


## Velocidad en km/h sin decimales: «196 km/h»; «∞ km/h» si no es finita.
static func fmt_kmh(v: float) -> String:
	return kmh_txt(v) + " km/h"


## Velocidad en km/h con un decimal (lo poco que le quita el aire a un salto): «0.2 km/h».
static func fmt_kmh1(v: float) -> String:
	return Js.to_fixed(v, 1) + " km/h"


## Velocidad en m/s con digits decimales (el salto de un animal): «4.84 m/s», «2.7 m/s».
static func fmt_mps(v: float, digits: int) -> String:
	return Js.to_fixed(v, digits) + " m/s"


## Una altura o una distancia en metros con digits decimales (lo que sube un salto, la altura de un panel): «1.19 m».
static func fmt_m(v: float, digits: int) -> String:
	return Js.to_fixed(v, digits) + " m"


## Un tiempo en segundos con dos decimales (el vuelo de un salto o de una caída): «0.32 s».
static func fmt_s(s: float) -> String:
	return Js.to_fixed(s, 2) + " s"


## Potencia: W hasta 1 kW (Format.fmt_f) y kW con un decimal después; con su signo (negativa: el animal hace de vela).
static func fmt_w(w: float) -> String:
	var a := absf(w)
	var s := (Js.to_fixed(a / 1000.0, 1) + " kW") if a >= 1000.0 else (Format.fmt_f(a) + " W")
	return ("-" + s) if w < 0.0 and a >= 0.05 else s


## Proporción (0-1) en tanto por ciento sin decimales; «∞ %» si no es finita.
static func fmt_pct(x: float) -> String:
	return (Js.to_fixed(x * 100.0, 0) if is_finite(x) else "∞") + " %"


## Una parte (0-1) con su decimal cuando es pequeña: «55 %», «3 %», «0.4 %», «<0.1 %» si hay algo pero no llega, y
## «0 %» si no hay nada.
static func fmt_share(x: float) -> String:
	if not is_finite(x):
		return "∞ %"
	var p := x * 100.0
	if p <= 0.0:
		return "0 %"
	if p < 0.1:
		return "<0.1 %"
	return (Js.to_fixed(p, 1) if p < 1.0 else Js.to_fixed(p, 0)) + " %"


## Aceleración en g con dos decimales: «0.90 g».
static func fmt_g(g: float) -> String:
	return Js.to_fixed(g, 2) + " g"


## La frenada máxima que aguanta, en g con dos decimales redondeados hacia abajo (lo que aguanta seguro): 0.8966 g es
## «0.89 g» y no «0.90 g», que es la de emergencia, que no aguanta (unidad 4o). El 1e-9, para que 0.29 (28.999… centésimas
## en coma flotante) no baje a 0.28.
static func fmt_g_max(g: float) -> String:
	return Js.to_fixed(floorf(g * 100.0 + 1e-9) / 100.0, 2) + " g"


## Un tiempo (s) en milisegundos sin decimales: «207 ms».
static func fmt_ms(s: float) -> String:
	return Js.to_fixed(s * 1000.0, 0) + " ms"


## Un número de un dato tal cual (String(n) de JavaScript): «0.45», «2000».
static func num(v: float) -> String:
	return Js.js_num_str(v)


## Banda de un dato { value, min, max }: «0.4 (0.24…0.6)», «-0.45 (-0.64…-0.3)», «0.685 m² (0.597…0.75 m²)»; sin banda,
## el valor solo.
static func fmt_band(b: Dictionary, unit := "") -> String:
	var u := (" " + unit) if unit != "" else ""
	var v := num(float(b.value)) + u
	if b.get("min") == null or (float(b.min) == float(b.value) and float(b.get("max", b.value)) == float(b.value)):
		return v
	return "%s (%s…%s%s)" % [v, num(float(b.min)), num(float(b.max)), u]


## El espesor de un panel del coche con su pintura (um en µm), en mm con dos decimales (unidad 4o: lo que atraviesa una marca
## de lado a lado): «0.81 mm» (la pintura y el acero de 0,7 mm) · «2.61 mm» (la aleta de plástico).
static func fmt_panel(um: float) -> String:
	return Js.to_fixed(um / 1000.0, 2) + " mm"


## Longitud legible con metros a partir de 1 m (um en µm): 350 µm · 6.1 mm · 35 mm (3.5 cm) · 1.6 m.
static func fmt_long(um: float) -> String:
	if um >= 1e6:
		return Js.to_fixed(um / 1e6, 1) + " m"
	return Format.fmt_len(um)


## Energía legible: J hasta 1000 J (Format.fmt_j); después kJ con un decimal.
static func fmt_energy(j: float) -> String:
	if j >= 1000.0:
		return Js.to_fixed(j / 1000.0, 1) + " kJ"
	return Format.fmt_j(j) + " J"
