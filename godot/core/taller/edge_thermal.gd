## Taller · afiladora: temperatura transitoria del filo y lo que le hace al acero (color de revenido, revenido
## acumulado y pérdida de dureza). Detalle, validación y fuentes: docs/taller/afilado-simulador.md.
##
## Modelo: aleta 1D de sección variable. x es la distancia desde el vértice del filo por el plano medio de la hoja;
## en cada x la sección tiene una sola temperatura (la media en el espesor). Vale porque cerca del filo el espesor es
## de micras a décimas de milímetro y el calor lo cruza en t²/α = milisegundos, mucho menos de lo que dura una
## pasada (décimas de segundo); a lo largo de x, en cambio, tarda w²/α ≈ 0,1–0,3 s en recorrer el bisel.
## - Ecuación: ρ·c·A(x)·∂T/∂t = ∂/∂x(k·A(x)·∂T/∂x) + q·P_q(x) − h·P_h(x)·(T − T∞), con A el área de la sección
##   (en un cuchillo, el espesor por metro de filo), P_q el borde calentado (la cara del bisel que toca la muela) y
##   P_h el que se enfría (las dos caras). q (W/m²) es el calor que entra por la cara: lo calcula grinding.gd.
## - Discretización: volúmenes finitos en una malla geométrica (celdas de micras en el vértice y de milímetros en el
##   lomo), conductancias exactas para un espesor lineal por tramos (∫dx/(k·A)) y Euler implícito: un sistema
##   tridiagonal por paso (algoritmo de Thomas). Es incondicionalmente estable y no oscila con los pulsos de calor,
##   así que el paso de tiempo lo fija la precisión (2–5 ms), no la celda más pequeña.
## - Cada instancia es UNA sección de la hoja, con su estado propio (sin variables estáticas ni cachés). Las
##   secciones no se tocan entre sí (se desprecia la conducción a lo largo del filo), así que se pueden avanzar en
##   paralelo y combinar en un orden fijo con combine(): el resultado es el mismo, al bit, con uno o con varios
##   hilos. El perfil que comparten solo se lee. Con WorkerThreadPool, prioridad alta y una tarea por sección y
##   fotograma: add_group_task(f, n, -1, true) (las de prioridad baja solo usan una parte de los hilos).
## - Revenido: el parámetro de Hollomon–Jaffe de cada celda empieza en el del revenido de fábrica y crece con la
##   regla del tiempo equivalente (sharpening_heat.gd, accumulate_temper). La curva de revenido de cada acero lo pasa
##   a dureza; el pico de temperatura de la cara, a un color de revenido (tabla de panels.gd).
## - Superficie: la cara que toca la muela está más caliente que la media de la sección: q·t/(3k) en una placa de
##   espesor t calentada por una cara y enfriada por conducción a lo largo (perfil parabólico). Se suma al pico de
##   la cara para el color.
## Unidades: la interfaz habla en mm, µm, s, °C y W/m²; dentro, SI (m, s, K, W). En los cuchillos y las cuñas las
## magnitudes van por metro de filo; en la punta de broca, absolutas.
## Uso:
##   const EdgeThermal = preload("res://core/taller/edge_thermal.gd")
##   var prof := EdgeThermal.knife_profile({ "per_side_deg": 17.5, "thickness_mm": 0.6 })
##   var sec := EdgeThermal.new(prof, "x50crmov15")
##   sec.step(0.005, q_w_m2, 1.0, "aire")      # 5 ms con la muela tocando toda la sección
##   var r := sec.summary()                     # edge_c, tint, hardness, t_over_temper_s…
extends RefCounted

const Heat = preload("res://core/taller/sharpening_heat.gd")
const Panels = preload("res://core/taller/panels.gd")

const SURFACE_FACTOR := 1.0 / 3.0  # exceso de la cara calentada sobre la media: q·t/(3k) (placa, perfil parabólico)
const OVER_TEMPER_REL := 0.01  # «pasa el revenido»: el parámetro del vértice supera en un 1 % el de fábrica
const DEFAULT_AMBIENT_C := 20.0

## Enfriamiento de las caras. h en W/(m²·K), por tramos de temperatura de la superficie (°C). Todo es estimación
## dentro de los intervalos de los libros: no hay medidas del enfriamiento de una hoja al afilar.
const COOLING := {
	"aire": {
		"name": "aire en calma",
		"h": 15.0, "min": 2.0, "max": 25.0,
		"source": "Incropera, DeWitt, Bergman y Lavine, Fundamentals of Heat and Mass Transfer, 6.ª ed. (2007), tabla 1.1: convección natural en gases, 2–25 W/(m²·K)",
		"quality": "estimate",
	},
	"pelicula_agua": {
		"name": "película de agua (muela húmeda o goteo)",
		"h": 500.0, "min": 50.0, "max": 1000.0,
		"h_boiling": 10000.0,
		"burnout_c": 130.0,
		"source": "Incropera et al. (2007), tabla 1.1: convección natural en líquidos 50–1000 W/(m²·K) y con ebullición 2500–100 000; Malkin y Guo 2007 (CIRP Annals 56/2): el agua deja de enfriar hacia 130 °C (ebullición en película). Por encima, la película se seca y la cara se enfría como en aire",
		"quality": "estimate",
	},
	"inmersion": {
		"name": "sumergida en agua",
		"h": 500.0, "min": 50.0, "max": 1000.0,
		"h_boiling": 10000.0,
		"h_film": 250.0,
		"nucleate_to_c": 130.0,
		"film_from_c": 300.0,
		"source": "Incropera et al. (2007), tabla 1.1 (líquidos 50–1000; ebullición 2500–100 000 W/(m²·K)); regímenes del agua a 1 atm: ebullición nucleada con 5–30 K de exceso sobre 100 °C, transición y película por encima de ≈200 K (nuclear-power.com, según Incropera); en la etapa de película del temple en agua, h ≈ 200–300 W/(m²·K) (Cukrov et al. 2025, Applied Sciences 15:1021, vía buscador). Entre 130 y 300 °C se interpola en logaritmo",
		"quality": "estimate",
	},
}

## Malla por defecto (celdas en el bisel y en el cuerpo; primera celda en el vértice, µm). Con 32 + 16 celdas el
## vértice queda a < 0,5 % de la solución convergida (tests/taller/test_edge_thermal.gd).
const GRID := { "n_bevel": 32, "n_body": 16, "h0_um": 5.0 }

## Punta de broca: fracción de metal de la sección (lo que dejan las ranuras), alma y parte del cono que toca la
## muela en cada instante. Estimaciones: no hay medida publicada para una broca genérica.
const DRILL := {
	"fill": { "value": 0.55, "source": "estimación: sección de una broca helicoidal menos sus dos ranuras (≈45 % del círculo)", "quality": "estimate" },
	"web": { "value": 0.15, "source": "estimación: alma de ≈15 % del diámetro en la punta (del orden de la arista transversal de una broca de uso general)", "quality": "estimate" },
	"heated": { "value": 0.25, "source": "estimación: el flanco de un labio ocupa ≈1/4 de la vuelta del cono de la punta", "quality": "estimate" },
}

# ─────────────────────────────── Estado de una sección ───────────────────────────────
var steel_id := ""
var profile_kind := ""
var _per_meter := true
var _n := 0
var _k := 30.0
var _alpha := 0.0
var _hj_c := Heat.HJ_C
var _p_factory := 0.0
var _temperable := false
var _soft := PackedFloat64Array()  # intervalos de P en los que se pierde ≥ 1 HRC (Heat.loss_ranges)
var _xc := PackedFloat64Array()  # m
var _cap := PackedFloat64Array()  # J/K (por metro de filo en un cuchillo)
var _g := PackedFloat64Array()  # W/K entre la celda i y la i+1
var _heat := PackedFloat64Array()  # m² (o m por metro de filo) de cara calentada
var _conv := PackedFloat64Array()  # m² (o m por metro) de caras que se enfrían
var _teff := PackedFloat64Array()  # m: espesor medio de la celda (radio medio en la broca)
var _t := PackedFloat64Array()  # °C
var _p := PackedFloat64Array()  # parámetro de Hollomon–Jaffe
var _peak := PackedFloat64Array()  # pico de la temperatura media (°C)
var _peak_surf := PackedFloat64Array()  # pico de la cara calentada (°C)
var _hp := PackedFloat64Array()  # h·P de cada celda en el último paso (W/K)
var _time := 0.0
var _e_in := 0.0
var _e_conv := 0.0
var _e_end := 0.0
var _e0 := 0.0
var _t0 := DEFAULT_AMBIENT_C
var _t_over := -1.0
var _t_loss1 := -1.0
var _last_q := 0.0
var _last_cov := 0.0
var _end_flux := 0.0  # W/m² por la cara del vértice (x = 0): solo para validar con soluciones analíticas
var _far_fixed := false
var _far_c := 0.0
var _g_far := 0.0
# Tridiagonal: diagonales, término independiente y auxiliares de Thomas (reservados una vez)
var _ta := PackedFloat64Array()
var _tb := PackedFloat64Array()
var _tc := PackedFloat64Array()
var _td := PackedFloat64Array()
var _cprime := PackedFloat64Array()
var _dprime := PackedFloat64Array()


## Una sección de la hoja con el perfil de knife_profile(), edge_profile() o drill_profile().
## thermal: { k, rho, cp } para un material sin datos en STEELS (si falta y el acero no está, las del 1.4116).
## opts.far_fixed_c: temperatura fija en el extremo lejano (solo para validar; por defecto el lomo es adiabático).
func _init(profile: Dictionary, steel: String, t0_c: float = DEFAULT_AMBIENT_C, thermal: Dictionary = {}, opts: Dictionary = {}) -> void:
	steel_id = steel
	var th: Dictionary = thermal
	if th.is_empty():
		th = Heat.STEELS[steel]["thermal"] if Heat.STEELS.has(steel) else Heat.STEELS["x50crmov15"]["thermal"]
	_k = float(th["k"])
	var rho_c := float(th["rho"]) * float(th["cp"])
	_alpha = _k / rho_c
	profile_kind = str(profile.get("kind", ""))
	_per_meter = bool(profile.get("per_meter", true))
	var xc: PackedFloat64Array = profile["xc"]
	var vol: PackedFloat64Array = profile["vol"]
	var rint: PackedFloat64Array = profile["rint"]
	var heat: PackedFloat64Array = profile["heat_area"]
	var conv: PackedFloat64Array = profile["conv_area"]
	var teff: PackedFloat64Array = profile["teff"]
	_xc = xc.duplicate()
	_n = _xc.size()
	_heat = heat.duplicate()
	_conv = conv.duplicate()
	_teff = teff.duplicate()
	_cap.resize(_n)
	_g.resize(maxi(_n - 1, 0))
	for i in _n:
		_cap[i] = rho_c * vol[i]
	for i in _n - 1:
		_g[i] = _k / rint[i]
	if opts.has("far_fixed_c"):
		_far_fixed = true
		_far_c = float(opts["far_fixed_c"])
		_g_far = _k / float(profile["rint_far"])
	_t0 = t0_c
	_temperable = Heat.STEELS.has(steel) and Heat.TEMPER_CURVES.has(steel)
	if Heat.STEELS.has(steel):
		_hj_c = Heat.curve_hj_c(steel)
		_p_factory = Heat.factory_temper_p(steel)
	if _temperable:
		_soft = Heat.loss_ranges(steel, 1.0)
	_t.resize(_n)
	_p.resize(_n)
	_peak.resize(_n)
	_peak_surf.resize(_n)
	_hp.resize(_n)
	_ta.resize(_n)
	_tb.resize(_n)
	_tc.resize(_n)
	_td.resize(_n)
	_cprime.resize(_n)
	_dprime.resize(_n)
	for i in _n:
		_t[i] = t0_c
		_p[i] = _p_factory
		_peak[i] = t0_c
		_peak_surf[i] = t0_c
	_e0 = _energy()


## Avanza dt segundos. q_face: calor que entra por la cara del bisel mientras toca la muela (W/m²); coverage: parte
## del paso (0–1) en que la toca (el calor se reparte en el paso); cooling: clave de COOLING o un medio a medida
## { h } (W/(m²·K)); t_inf_c: temperatura del aire o del agua (°C).
func step(dt: float, q_face: float, coverage: float = 1.0, cooling: Variant = "aire", t_inf_c: float = DEFAULT_AMBIENT_C) -> void:
	if not (dt > 0.0) or not is_finite(dt):
		return
	var q := q_face if is_finite(q_face) and q_face > 0.0 else 0.0
	var cov := clampf(coverage, 0.0, 1.0) if is_finite(coverage) else 0.0
	var qc := q * cov
	var cool: Dictionary = medium(cooling)
	var h_cold := float(cool["h"])
	var boils := cool.has("h_boiling")
	var t_inf := t_inf_c if is_finite(t_inf_c) else DEFAULT_AMBIENT_C
	var n := _n
	var s_in := 0.0
	# Euler implícito: (C/dt + ΣG + H)·T'ᵢ − G·T'vecinos = C/dt·Tᵢ + S + H·T∞ (h con la temperatura anterior)
	for i in n:
		var ti := _t[i]
		var hc := (_h_of(cool, ti) if boils and ti > 100.0 else h_cold) * _conv[i]
		_hp[i] = hc
		var gl := _g[i - 1] if i > 0 else 0.0
		var gr := _g[i] if i < n - 1 else 0.0
		var src := qc * _heat[i]
		if i == 0 and _end_flux != 0.0:
			src += _end_flux * _teff[0]
		var cdt := _cap[i] / dt
		var diag := cdt + gl + gr + hc
		var rhs := cdt * ti + src + hc * t_inf
		if _far_fixed and i == n - 1:
			diag += _g_far
			rhs += _g_far * _far_c
		_ta[i] = -gl
		_tb[i] = diag
		_tc[i] = -gr
		_td[i] = rhs
		s_in += src
	_thomas()
	# Balance de energía del paso, con la misma ponderación que el esquema (todo en la temperatura nueva)
	var loss := 0.0
	for i in n:
		loss += _hp[i] * (_t[i] - t_inf)
	_e_in += s_in * dt
	_e_conv += loss * dt
	if _far_fixed:
		_e_end += _g_far * (_t[n - 1] - _far_c) * dt
	_time += dt
	_last_q = q
	_last_cov = cov
	# Picos, color y revenido. El revenido solo se calcula en las celdas donde dt cuenta frente al tiempo
	# equivalente de lo ya revenido (la misma regla que accumulate_temper, sin llamarla en las frías).
	var surf_q := q * SURFACE_FACTOR / _k if cov > 0.0 else 0.0
	var skip_log := log(dt / 3600.0) / Heat.LN10 + 7.0
	var p_edge_before := _p[0]
	for i in n:
		var ti := _t[i]
		if ti > _peak[i]:
			_peak[i] = ti
		var ts := ti + surf_q * _teff[i] if _heat[i] > 0.0 else ti
		if ts > _peak_surf[i]:
			_peak_surf[i] = ts
		if _temperable and _p[i] / (ti + 273.15) - _hj_c <= skip_log:
			_p[i] = Heat.accumulate_temper(_p[i], ti, dt, _hj_c)
	if _temperable and _p[0] > p_edge_before:
		if _t_over < 0.0 and _p[0] > _p_factory * (1.0 + OVER_TEMPER_REL):
			_t_over = _time
		if _t_loss1 < 0.0 and _p[0] > _p_factory and _softened(_p[0]):
			_t_loss1 = _time


## Avanza duration segundos en pasos de dt con las mismas condiciones (cómodo para los casos de referencia).
func run(duration: float, dt: float, q_face: float, coverage: float = 1.0, cooling: Variant = "aire", t_inf_c: float = DEFAULT_AMBIENT_C) -> void:
	if not (dt > 0.0) or not (duration > 0.0):
		return
	var steps := int(round(duration / dt))
	for _i in steps:
		step(dt, q_face, coverage, cooling, t_inf_c)


## Flujo por la cara del vértice (W/m²), que se mantiene hasta cambiarlo. Solo sirve para validar el modelo con la
## solución del sólido semiinfinito (calor que entra por x = 0).
func set_end_flux(q_w_m2: float) -> void:
	_end_flux = q_w_m2 if is_finite(q_w_m2) else 0.0


## Temperatura del vértice del filo (°C, media de la primera celda).
func edge_c() -> float:
	return _t[0]


## Temperatura máxima de la sección ahora (°C).
func max_c() -> float:
	var m := _t[0]
	for i in _n:
		m = maxf(m, _t[i])
	return m


## Temperatura de la cara que toca la muela, la más alta de la zona de contacto (°C). La usa grinding.gd para saber
## si el agua todavía enfría (por debajo de ≈130 °C).
func contact_surface_c() -> float:
	var m := -INF
	var surf_q := _last_q * SURFACE_FACTOR / _k if _last_cov > 0.0 else 0.0
	for i in _n:
		if _heat[i] > 0.0:
			m = maxf(m, _t[i] + surf_q * _teff[i])
	return m if m > -INF else _t[0]


func time_s() -> float:
	return _time


func cell_count() -> int:
	return _n


## Copia de las temperaturas de las celdas (°C), del vértice al lomo.
func temps() -> PackedFloat64Array:
	return _t.duplicate()


## Posición del centro de cada celda (mm desde el vértice).
func x_mm() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(_n)
	for i in _n:
		out[i] = _xc[i] * 1000.0
	return out


## Picos de la cara calentada por celda (°C): para pintar los colores de revenido a lo ancho del bisel.
func surface_peaks() -> PackedFloat64Array:
	return _peak_surf.duplicate()


## Parámetros de Hollomon–Jaffe por celda (revenido acumulado).
func temper_params() -> PackedFloat64Array:
	return _p.duplicate()


## Balance de energía desde el principio: lo que entra = lo almacenado + lo perdido por las caras + lo perdido por el
## extremo fijo. En J (por metro de filo si el perfil es por metro).
func energy_balance() -> Dictionary:
	var stored := _energy() - _e0
	var err := stored - (_e_in - _e_conv - _e_end)
	return {
		"in_j": _e_in,
		"stored_j": stored,
		"convected_j": _e_conv,
		"end_j": _e_end,
		"error_j": err,
		"relative": absf(err) / maxf(absf(_e_in), 1e-300),
		"per_meter": _per_meter,
	}


## Resumen para la interfaz y los casos de referencia:
## { time_s, edge_c, max_c, max_x_mm, peak_edge_c, peak_max_c, edge_surface_peak_c, tint { temp_c, hex, name,
## table } | null, tint_width_mm, hardness (Heat.temper_loss del vértice) | null, temper_equiv_c, softened_width_mm
## (pierde ≥ 1 HRC), t_over_temper_s y t_loss_1hrc_s (−1 si no pasa), burned (≥ 723 °C), burn_width_mm, energy,
## validity, quality, sources }.
func summary() -> Dictionary:
	var hot := 0
	var peak_max := _peak[0]
	for i in _n:
		if _t[i] > _t[hot]:
			hot = i
		peak_max = maxf(peak_max, _peak[i])
	var tint_info: Variant = null
	var col := tint(steel_id, _peak_surf[0])
	if not col.is_empty():
		tint_info = col
	var tint_w := 0.0
	var first_tint := first_tint_c(steel_id)
	var hard: Variant = null
	var equiv_c: Variant = null
	var soft_w := 0.0
	var burn_w := 0.0
	for i in _n:
		if _peak_surf[i] >= first_tint:
			tint_w = _xc[i] * 1000.0
		if _peak[i] >= Heat.BURN_C:
			burn_w = _xc[i] * 1000.0
	if _temperable:
		hard = Heat.temper_loss(steel_id, _p[0])
		equiv_c = Heat.curve_hardness(steel_id, _p[0]).get("curve_temp_c")
		for i in _n:
			if _p[i] > _p_factory and _softened(_p[i]):
				soft_w = _xc[i] * 1000.0
	var sources: Array[String] = [
		"Aleta 1D de sección variable, volúmenes finitos y Euler implícito (docs/taller/afilado-simulador.md)",
		str(Heat.THRESHOLDS["hollomon_jaffe_c"]["source"]),
		Panels.TEMPER_SOURCE,
	]
	if _temperable:
		sources.append(str(Heat.TEMPER_CURVES[steel_id]["source"]))
	var ce := _contact_end()
	return {
		"time_s": _time,
		"edge_c": _t[0],
		"max_c": _t[hot],
		"max_x_mm": _xc[hot] * 1000.0,
		"peak_edge_c": _peak[0],
		"peak_max_c": peak_max,
		"edge_surface_peak_c": _peak_surf[0],
		"tint": tint_info,
		"tint_width_mm": tint_w,
		"hardness": hard,
		"temper_equiv_c": equiv_c,
		"softened_width_mm": soft_w,
		"t_over_temper_s": _t_over,
		"t_loss_1hrc_s": _t_loss1,
		"burned": _peak[0] >= Heat.BURN_C,
		"burn_width_mm": burn_w,
		"energy": energy_balance(),
		"validity": {
			"through_thickness_ms": 1000.0 * _teff[ce] * _teff[ce] / _alpha,
			"note": "Aleta 1D: vale mientras el calor cruza el espesor (t²/α) mucho más deprisa de lo que dura el contacto. En el bisel de un cuchillo son milisegundos; en una broca gruesa, décimas de segundo: allí la cara calentada va más caliente que la media (se suma q·t/(3k)) y el modelo es una tendencia.",
		},
		"quality": "estimate",
		"sources": sources,
	}


# ─────────────────────────────── Hoja entera (varias secciones) ───────────────────────────────

## La hoja entera son n instancias con el mismo perfil, una por sección a lo largo del filo:
##   var secs := []; for i in n: secs.append(EdgeThermal.new(prof, steel))
## Cada una se avanza con su propio step() (se pueden repartir entre hilos: no comparten nada que se escriba).

## Combina las secciones en un orden fijo (0, 1, 2…): lo peor de la hoja y la media del vértice. El resultado no
## depende del hilo que avanzó cada sección.
static func combine(sections: Array) -> Dictionary:
	var worst_edge := -INF
	var worst_i := -1
	var worst_loss := 0.0
	var mean_edge := 0.0
	var burned := false
	var tinted := 0
	for i in sections.size():
		var s: Variant = sections[i]
		var r: Dictionary = s.summary()
		mean_edge += float(r["edge_c"])
		if float(r["peak_edge_c"]) > worst_edge:
			worst_edge = float(r["peak_edge_c"])
			worst_i = i
		if r["hardness"] is Dictionary:
			worst_loss = maxf(worst_loss, float(r["hardness"]["loss_hrc"]))
		burned = burned or bool(r["burned"])
		if r["tint"] != null:
			tinted += 1
	var count := maxi(sections.size(), 1)
	return {
		"sections": sections.size(),
		"peak_edge_c": worst_edge,
		"hottest_section": worst_i,
		"mean_edge_c": mean_edge / float(count),
		"max_loss_hrc": worst_loss,
		"tinted_sections": tinted,
		"burned": burned,
	}


## Parte del paso dt (0–1) en que la sección situada en z_mm (a lo largo del filo) está dentro de un contacto de
## ancho len_mm centrado en c0_mm al empezar el paso y que se mueve a v_mm_s. Para barrer el filo por la muela.
static func sweep_coverage(z_mm: float, c0_mm: float, len_mm: float, v_mm_s: float, dt: float) -> float:
	if not (dt > 0.0) or not (len_mm > 0.0):
		return 0.0
	var half := 0.5 * len_mm
	if absf(v_mm_s) < 1e-12:
		return 1.0 if absf(z_mm - c0_mm) <= half else 0.0
	# el centro pasa por z ± half en t = (z ± half − c0)/v
	var t1 := (z_mm - half - c0_mm) / v_mm_s
	var t2 := (z_mm + half - c0_mm) / v_mm_s
	var lo := minf(t1, t2)
	var hi := maxf(t1, t2)
	var overlap := minf(hi, dt) - maxf(lo, 0.0)
	return clampf(overlap / dt, 0.0, 1.0)


# ─────────────────────────────── Color de revenido ───────────────────────────────

## Tabla de colores de revenido del acero: la del acero al carbono (1095 y, por aproximación, M2) o la del inox en
## aire (1.4116, VG-10, 14C28N: medida en 1.4301, ESTIMACIÓN para los martensíticos). panels.gd, TEMPER_COLORS.
static func tint_table(steel: String) -> String:
	var fam := str(Heat.STEELS.get(steel, {}).get("family", ""))
	return "inox" if fam.begins_with("inoxidable") else "acero"


## Primera temperatura con color en la tabla del acero (°C).
static func first_tint_c(steel: String) -> float:
	var rows: Array = Panels.TEMPER_COLORS[tint_table(steel)]
	return float(rows[0]["t"])


## Color de revenido para un pico de temperatura (°C): { temp_c, hex, name, table } o {} por debajo del primero.
## El color depende también del tiempo (a 275 °C durante 30 min sale el azul que a 300 °C sale al momento; Nature
## 109:106, 1922): con exposiciones de décimas de segundo el color real aparece a algo más de temperatura.
static func tint(steel: String, temp_c: float) -> Dictionary:
	var table := tint_table(steel)
	var rows: Array = Panels.TEMPER_COLORS[table]
	var hit: Dictionary = {}
	for row in rows:
		if temp_c >= float(row["t"]):
			hit = row
	if hit.is_empty():
		return {}
	return { "temp_c": temp_c, "hex": hit["hex"], "name": hit["name"], "table": table }


# ─────────────────────────────── Perfiles ───────────────────────────────

## Cuña de filo con cuerpo (cuchillo, hacha, cuchilla de cortacésped, labio de broca). p (mm, grados, µm):
##   apex_um: anchura del vértice (el filo real no es una arista: Verhoeven midió 0,3–4 µm; por defecto 1 µm)
##   side_a_deg: ángulo de la cara que toca la muela, por lado · side_b_deg: el de la otra cara (igual por defecto;
##     0 en un bisel de un solo lado) · shoulder_mm: espesor donde acaba el bisel · spine_mm: espesor en el lomo ·
##   height_mm: del vértice al lomo · contact_mm: ancho de la cara que toca la muela, desde el vértice (por
##   defecto, todo el bisel) · n_bevel, n_body, h0_um: malla · body: false para quedarse solo con la cuña (acaba en
##   el hombro del bisel; sirve para validar con la solución exacta de la cuña).
## Devuelve el perfil por metro de filo: { kind, per_meter, xc, faces, vol, rint, rint_far, heat_area, conv_area,
## teff (m), x_shoulder_mm, face_width_mm, contact_face_mm, height_mm, side_a_deg, side_b_deg, apex_um, shoulder_mm }.
static func edge_profile(p: Dictionary) -> Dictionary:
	var a_deg := clampf(Heat.input_num(p, "side_a_deg", 17.5), 1.0, 60.0)
	var b_deg := clampf(Heat.input_num(p, "side_b_deg", a_deg), 0.0, 60.0)
	var apex := maxf(Heat.input_num(p, "apex_um", 1.0), 0.05) * 1e-6
	var t_sh := maxf(Heat.input_num(p, "shoulder_mm", 0.6), 0.01) * 1e-3
	t_sh = maxf(t_sh, apex * 2.0)
	var t_sp := maxf(Heat.input_num(p, "spine_mm", maxf(2.0, t_sh * 1000.0)), t_sh * 1000.0) * 1e-3
	var ta := tan(deg_to_rad(a_deg))
	var tb := tan(deg_to_rad(b_deg))
	var x_sh := (t_sh - apex) / (ta + tb)
	var height := maxf(Heat.input_num(p, "height_mm", 40.0) * 1e-3, x_sh * 1.5)
	var cos_a := cos(deg_to_rad(a_deg))
	var cos_b := cos(deg_to_rad(b_deg))
	var contact_x := x_sh
	if p.get("contact_mm") != null:
		contact_x = clampf(Heat.input_num(p, "contact_mm", x_sh * 1000.0 / cos_a) * 1e-3 * cos_a, 0.0, x_sh)
	var n_bevel := maxi(int(Heat.input_num(p, "n_bevel", GRID["n_bevel"])), 2)
	var n_body := maxi(int(Heat.input_num(p, "n_body", GRID["n_body"])), 1)
	var h0 := maxf(Heat.input_num(p, "h0_um", GRID["h0_um"]), 0.01) * 1e-6
	var with_body := Heat.input_flag(p, "body", true)
	var faces := _geom_faces(0.0, x_sh, n_bevel, h0)
	if with_body:
		var last_w := faces[faces.size() - 1] - faces[faces.size() - 2]
		var body := _geom_faces(x_sh, height, n_body, last_w)
		for j in range(1, body.size()):
			faces.append(body[j])
	else:
		height = x_sh
	var xs := PackedFloat64Array([0.0, x_sh, height]) if with_body else PackedFloat64Array([0.0, x_sh])
	var ts := PackedFloat64Array([apex, t_sh, t_sp]) if with_body else PackedFloat64Array([apex, t_sh])
	var n := faces.size() - 1
	var xc := PackedFloat64Array()
	var vol := PackedFloat64Array()
	var teff := PackedFloat64Array()
	var heat := PackedFloat64Array()
	var conv := PackedFloat64Array()
	var rint := PackedFloat64Array()
	for i in n:
		var x0 := faces[i]
		var x1 := faces[i + 1]
		xc.append(0.5 * (x0 + x1))
		var v := _int_lin(xs, ts, x0, x1)
		vol.append(v)
		teff.append(v / (x1 - x0))
		var in_bevel := maxf(0.0, minf(x1, x_sh) - x0)
		var in_body := (x1 - x0) - in_bevel
		heat.append(maxf(0.0, minf(x1, contact_x) - x0) / cos_a)
		conv.append(in_bevel * (1.0 / cos_a + 1.0 / cos_b) + 2.0 * in_body)
	for i in n - 1:
		rint.append(_int_inv_lin(xs, ts, xc[i], xc[i + 1]))
	var out := { "xc": xc, "vol": vol, "teff": teff, "heat_area": heat, "conv_area": conv, "rint": rint }
	out["faces"] = faces
	out["rint_far"] = _int_inv_lin(xs, ts, xc[n - 1], faces[n])
	out["kind"] = "filo"
	out["per_meter"] = true
	out["x_shoulder_mm"] = x_sh * 1000.0
	out["face_width_mm"] = x_sh / cos_a * 1000.0
	out["contact_face_mm"] = contact_x / cos_a * 1000.0
	out["height_mm"] = height * 1000.0
	out["side_a_deg"] = a_deg
	out["side_b_deg"] = b_deg
	out["apex_um"] = apex * 1e6
	out["shoulder_mm"] = t_sh * 1000.0
	out["source"] = "Geometría de la cuña: espesor t(x) = vértice + x·(tan a + tan b) hasta el hombro del bisel y lineal hasta el lomo; anchura de la cara w = x/cos a (con a = b, w = (t/2)/sen β, sharpening.gd)"
	out["quality"] = "primary"
	return out


## Cuchillo: cuña simétrica con el ángulo por lado de sharpening.gd. p: per_side_deg (17,5), thickness_mm (espesor
## tras el bisel, 0,6), spine_mm (2), height_mm (40), apex_um (1), contact_mm (cara en contacto; todo el bisel).
static func knife_profile(p: Dictionary) -> Dictionary:
	var beta := Heat.input_num(p, "per_side_deg", 17.5)
	var q := {
		"side_a_deg": beta,
		"side_b_deg": beta,
		"shoulder_mm": Heat.input_num(p, "thickness_mm", 0.6),
		"spine_mm": Heat.input_num(p, "spine_mm", 2.0),
		"height_mm": Heat.input_num(p, "height_mm", 40.0),
		"apex_um": Heat.input_num(p, "apex_um", 1.0),
	}
	for key in ["contact_mm", "n_bevel", "n_body", "h0_um"]:
		if p.get(key) != null:
			q[key] = p[key]
	var prof := edge_profile(q)
	prof["kind"] = "cuchillo"
	return prof


## Barra de espesor constante (por metro de ancho), para validar el modelo con soluciones exactas: sólido
## semiinfinito, aleta y cuerpo concentrado. p: thickness_mm (1), length_mm (50), n (100), h0_um (1), heated_mm
## (tramo calentado por una cara desde x = 0; 0 por defecto).
static func bar_profile(p: Dictionary) -> Dictionary:
	var t := maxf(Heat.input_num(p, "thickness_mm", 1.0), 1e-3) * 1e-3
	var length := maxf(Heat.input_num(p, "length_mm", 50.0), 1e-3) * 1e-3
	var n := maxi(int(Heat.input_num(p, "n", 100)), 2)
	var h0 := maxf(Heat.input_num(p, "h0_um", 1.0), 1e-3) * 1e-6
	var heated := maxf(Heat.input_num(p, "heated_mm", 0.0), 0.0) * 1e-3
	var faces := _geom_faces(0.0, length, n, h0)
	var xc := PackedFloat64Array()
	var vol := PackedFloat64Array()
	var teff := PackedFloat64Array()
	var heat := PackedFloat64Array()
	var conv := PackedFloat64Array()
	var rint := PackedFloat64Array()
	for i in n:
		var dx := faces[i + 1] - faces[i]
		xc.append(0.5 * (faces[i] + faces[i + 1]))
		vol.append(t * dx)
		teff.append(t)
		heat.append(maxf(0.0, minf(faces[i + 1], heated) - faces[i]))
		conv.append(2.0 * dx)
	for i in n - 1:
		rint.append((xc[i + 1] - xc[i]) / t)
	return {
		"xc": xc, "vol": vol, "teff": teff, "heat_area": heat, "conv_area": conv, "rint": rint, "faces": faces,
		"rint_far": (faces[n] - xc[n - 1]) / t, "kind": "barra", "per_meter": true,
		"source": "Barra de espesor constante (validación)", "quality": "primary",
	}


## Punta de broca como un cono truncado (modelo axial): x es la distancia desde la punta por el eje. p: diameter_mm
## (8), point_deg (118), length_mm (cuerpo que se considera, 5·D), fill, web, heated (DRILL), n_point, n_body, h0_um.
## Magnitudes absolutas (no por metro). La cara calentada es el flanco de un labio (DRILL.heated del cono).
static func drill_profile(p: Dictionary) -> Dictionary:
	var d := maxf(Heat.input_num(p, "diameter_mm", 8.0), 0.5) * 1e-3
	var point := clampf(Heat.input_num(p, "point_deg", 118.0), 60.0, 170.0)
	var fill := clampf(Heat.input_num(p, "fill", DRILL["fill"]["value"]), 0.1, 1.0)
	var web := clampf(Heat.input_num(p, "web", DRILL["web"]["value"]), 0.02, 0.5)
	var heated := clampf(Heat.input_num(p, "heated", DRILL["heated"]["value"]), 0.0, 1.0)
	var length := maxf(Heat.input_num(p, "length_mm", 5.0 * d * 1000.0) * 1e-3, d)
	var half := deg_to_rad(point / 2.0)
	var tp := tan(half)
	var cp := cos(half)
	var r_big := d / 2.0
	var r0 := web * d / 2.0
	var l_point := (r_big - r0) / tp
	length = maxf(length, l_point * 1.5)
	var n_point := maxi(int(Heat.input_num(p, "n_point", 30)), 2)
	var n_body := maxi(int(Heat.input_num(p, "n_body", 15)), 1)
	var h0 := maxf(Heat.input_num(p, "h0_um", 10.0), 0.01) * 1e-6
	var faces := _geom_faces(0.0, l_point, n_point, h0)
	var last_w := faces[faces.size() - 1] - faces[faces.size() - 2]
	var body := _geom_faces(l_point, length, n_body, last_w)
	for j in range(1, body.size()):
		faces.append(body[j])
	var n := faces.size() - 1
	var xc := PackedFloat64Array()
	var vols := PackedFloat64Array()
	var teff := PackedFloat64Array()
	var heats := PackedFloat64Array()
	var convs := PackedFloat64Array()
	var rint := PackedFloat64Array()
	for i in n:
		var x0 := faces[i]
		var x1 := faces[i + 1]
		xc.append(0.5 * (x0 + x1))
		var pa := minf(x1, l_point) - x0  # tramo en el cono
		var vol := 0.0
		var heat := 0.0
		var conv := 0.0
		if pa > 0.0:
			var ra := r0 + x0 * tp
			var rb := r0 + minf(x1, l_point) * tp
			vol += fill * PI * (rb * rb * rb - ra * ra * ra) / (3.0 * tp)
			var lat := PI * (ra + rb) * pa / cp  # superficie lateral del tronco de cono
			heat += heated * lat
			conv += lat
		var pb := x1 - maxf(x0, l_point)
		if pb > 0.0:
			vol += fill * PI * r_big * r_big * pb
			conv += 2.0 * PI * r_big * pb
		vols.append(vol)
		heats.append(heat)
		convs.append(conv)
		teff.append(_drill_r(0.5 * (x0 + x1), r0, tp, l_point, r_big))
	for i in n - 1:
		rint.append(_drill_rint(xc[i], xc[i + 1], r0, tp, l_point, r_big, fill))
	var out := { "xc": xc, "vol": vols, "teff": teff, "heat_area": heats, "conv_area": convs, "rint": rint }
	out["faces"] = faces
	out["rint_far"] = _drill_rint(xc[n - 1], faces[n], r0, tp, l_point, r_big, fill)
	out["kind"] = "broca"
	out["per_meter"] = false
	out["point_length_mm"] = l_point * 1000.0
	out["diameter_mm"] = d * 1000.0
	out["point_deg"] = point
	out["heated_area_mm2"] = heated * PI * (r_big * r_big - r0 * r0) / sin(half) * 1e6
	out["source"] = "Geometría del cono de la punta: radio r0 + x·tan(punta/2) hasta el diámetro; sección llena al " + str(DRILL["fill"]["source"]) + "; " + str(DRILL["web"]["source"]) + "; " + str(DRILL["heated"]["source"])
	out["quality"] = "estimate"
	return out


static func _drill_r(x: float, r0: float, tp: float, l_point: float, r_big: float) -> float:
	return r0 + x * tp if x < l_point else r_big


## ∫ dx / A(x) entre x0 y x1 para la broca: en el cono A = fill·π·(r0 + x·tan)², en el cuerpo A = fill·π·R².
static func _drill_rint(x0: float, x1: float, r0: float, tp: float, l_point: float, r_big: float, fill: float) -> float:
	var s := 0.0
	var a := x0
	var b := minf(x1, l_point)
	if b > a:
		s += (1.0 / (r0 + a * tp) - 1.0 / (r0 + b * tp)) / (fill * PI * tp)
	var c := maxf(x0, l_point)
	if x1 > c:
		s += (x1 - c) / (fill * PI * r_big * r_big)
	return s


## Caras de n celdas entre x0 y x1: la primera de anchura h0 y crecimiento geométrico (razón por bisección).
static func _geom_faces(x0: float, x1: float, n: int, h0: float) -> PackedFloat64Array:
	var f := PackedFloat64Array()
	var length := x1 - x0
	if n <= 1 or h0 * float(n) >= length:
		for i in n + 1:
			f.append(x0 + length * float(i) / float(n))
		return f
	var lo := 1.0 + 1e-12
	var hi := 10.0
	for _it in 200:
		var r := 0.5 * (lo + hi)
		var s := h0 * (pow(r, n) - 1.0) / (r - 1.0)
		if s > length:
			hi = r
		else:
			lo = r
	var ratio := 0.5 * (lo + hi)
	f.append(x0)
	var w := h0
	for _i in n:
		f.append(f[f.size() - 1] + w)
		w *= ratio
	f[n] = x1
	return f


## ∫ t(x) dx entre a y b con t lineal a trozos (vértices xs, ts).
static func _int_lin(xs: PackedFloat64Array, ts: PackedFloat64Array, a: float, b: float) -> float:
	var s := 0.0
	for j in xs.size() - 1:
		var u := maxf(a, xs[j])
		var v := minf(b, xs[j + 1])
		if v > u:
			s += 0.5 * (_lin(xs, ts, j, u) + _lin(xs, ts, j, v)) * (v - u)
	return s


## ∫ dx / t(x) entre a y b con t lineal a trozos: ln(t2/t1)·Δx/Δt en cada tramo (Δx/t si es constante).
static func _int_inv_lin(xs: PackedFloat64Array, ts: PackedFloat64Array, a: float, b: float) -> float:
	var s := 0.0
	for j in xs.size() - 1:
		var u := maxf(a, xs[j])
		var v := minf(b, xs[j + 1])
		if v > u:
			var tu := _lin(xs, ts, j, u)
			var tv := _lin(xs, ts, j, v)
			if absf(tv - tu) <= 1e-12 * maxf(tu, tv):
				s += (v - u) / tu
			else:
				s += (v - u) * log(tv / tu) / (tv - tu)
	return s


static func _lin(xs: PackedFloat64Array, ts: PackedFloat64Array, j: int, x: float) -> float:
	return ts[j] + (ts[j + 1] - ts[j]) * (x - xs[j]) / (xs[j + 1] - xs[j])


# ─────────────────────────────── Internos ───────────────────────────────

## Medio de enfriamiento: una clave de COOLING, o un diccionario con al menos «h» (W/(m²·K)); si no, el aire.
static func medium(cooling: Variant) -> Dictionary:
	if cooling is Dictionary and (cooling as Dictionary).has("h") and is_finite(float(cooling["h"])) and float(cooling["h"]) >= 0.0:
		return cooling
	if cooling is String or cooling is StringName:
		return COOLING.get(str(cooling), COOLING["aire"])
	return COOLING["aire"]


## h (W/(m²·K)) del medio con la superficie a t_c grados.
static func _h_of(cool: Dictionary, t_c: float) -> float:
	var h := float(cool["h"])
	if not cool.has("h_boiling") or t_c <= 100.0:
		return h
	if cool.has("burnout_c"):
		# película de agua: ebullición nucleada hasta que se seca; luego, como en aire
		return float(cool["h_boiling"]) if t_c <= float(cool["burnout_c"]) else float(COOLING["aire"]["h"])
	var t1 := float(cool["nucleate_to_c"])
	var t2 := float(cool["film_from_c"])
	var hb := float(cool["h_boiling"])
	var hf := float(cool["h_film"])
	if t_c <= t1:
		return hb
	if t_c >= t2:
		return hf
	var f := (t_c - t1) / (t2 - t1)
	return exp(log(hb) + f * (log(hf) - log(hb)))


## Algoritmo de Thomas sobre _ta, _tb, _tc, _td: deja la solución en _t.
func _thomas() -> void:
	var n := _n
	_cprime[0] = _tc[0] / _tb[0]
	_dprime[0] = _td[0] / _tb[0]
	for i in range(1, n):
		var m := _tb[i] - _ta[i] * _cprime[i - 1]
		_cprime[i] = _tc[i] / m if i < n - 1 else 0.0
		_dprime[i] = (_td[i] - _ta[i] * _dprime[i - 1]) / m
	_t[n - 1] = _dprime[n - 1]
	for i in range(n - 2, -1, -1):
		_t[i] = _dprime[i] - _cprime[i] * _t[i + 1]


func _energy() -> float:
	var e := 0.0
	for i in _n:
		e += _cap[i] * (_t[i] - _t0)
	return e


## Si un parámetro de revenido ya supone perder ≥ 1 HRC (Heat.temper_loss, con los cortes calculados al crear la
## sección).
func _softened(p: float) -> bool:
	var i := 0
	while i + 1 < _soft.size():
		if p >= _soft[i] and p <= _soft[i + 1]:
			return true
		i += 2
	return false


## Índice de la última celda calentada (para la validez del modelo).
func _contact_end() -> int:
	var last := 0
	for i in _n:
		if _heat[i] > 0.0:
			last = i
	return last
