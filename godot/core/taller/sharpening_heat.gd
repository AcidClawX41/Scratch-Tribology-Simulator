## Taller · afiladora: riesgo térmico al amolar una herramienta. Da un índice relativo, no una temperatura.
##
## Modelo de Malkin y Guo (2007), «Thermal analysis of grinding», CIRP Annals 56/2, 760–782:
## - Una fracción ε de la potencia de amolado entra como calor en la pieza, que aquí es la herramienta que se
##   afila: q = ε·P/A. Con muelas convencionales ε ≈ 0,60–0,85; con CBN ≈ 0,20, porque el grano de CBN conduce
##   el calor hacia la muela.
## - Si el contacto barre la herramienta a la velocidad V, la fuente de calor es una banda que se mueve sobre un
##   sólido semiinfinito (ecuación 2 del artículo): θmax = 1,595·q·√(α·l)/(k·√V), con l la media longitud del
##   contacto en la dirección del barrido. V es la velocidad del contacto respecto de la herramienta (en el
##   artículo, la de la pieza), no la periférica de la muela: esa ya está dentro de la potencia, P = Ft·Vs.
## - Si la herramienta se queda quieta sobre la muela, la fuente es un círculo fijo (Carslaw y Jaeger 1959): el
##   calentamiento crece con √t y se satura en q·a/k. Barrer nunca calienta más que quedarse quieto, así que se
##   toma el menor de los dos.
## - El agua solo enfría mientras la superficie no pasa de ≈130 °C: por encima hierve en película y deja de
##   mojar (Malkin y Guo). Entonces el reparto vuelve a ser el de en seco.
## - Umbrales: 130 °C (el agua deja de enfriar), el revenido del acero ajustado al tiempo de exposición con el
##   parámetro de Hollomon y Jaffe (1945) y ≈723 °C (eutectoide: el acero austeniza y se quema).
## No se da la temperatura del filo: la solución es la de un cuerpo grueso y un filo fino no lo es (se calienta
## más). Sirve para comparar máquinas, abrasivos, presión y tiempo.
## Unidades: W, mm², m/s, s y °C en la interfaz; dentro, SI (m, W/m², m²/s).
extends RefCounted

const Js = preload("res://core/shared/js.gd")

const AMBIENT_C := 20.0  # temperatura de partida de la herramienta y del agua (supuesto del modelo)
const BURNOUT_WATER_C := 130.0  # el fluido acuoso deja de enfriar (ebullición en película)
const BURN_C := 723.0  # eutectoide del acero al carbono: empieza la austenización (quemado)
const HJ_C := 15.0  # constante de Hollomon y Jaffe con el tiempo en horas (aceros de ≈0,9–1 % C)
const MOVING_COEF := 1.595  # ecuación 2 de Malkin y Guo (banda uniforme, fuente rápida)
const LN10 := 2.302585092994046  # ln 10, para log10 con el logaritmo nativo en los cálculos internos (no se enseñan)

## Umbrales y constantes del modelo, con su fuente.
const THRESHOLDS := {
	"burnout_water_c": {
		"value": 130.0,
		"source": "Malkin y Guo 2007: el fluido solo enfría hasta la ebullición en película, ≈130 °C con fluidos acuosos (300–350 °C con aceite entero)",
		"quality": "primary",
	},
	"burn_c": {
		"value": 723.0,
		"source": "Malkin y Guo 2007: el umbral del quemado visible coincide con el inicio de la austenización, el eutectoide de 723 °C del acero al carbono (≈800 °C para volver a formar martensita)",
		"quality": "primary",
	},
	"hollomon_jaffe_c": {
		"value": 15.0,
		"source": "Hollomon y Jaffe 1945, reanalizado por Thomas, Speer, Matlock, Krauss y Hackenberg (ICOMAT-08, TMS 2009): c = 12,2 con t en segundos (≈15,8 en horas) para su acero W de 0,89 % C; c baja con el carbono y cambia con la dureza, así que la equivalencia es aproximada",
		"quality": "estimate",
	},
	"ambient_c": {
		"value": 20.0,
		"source": "supuesto del modelo: la herramienta y el agua empiezan a 20 °C",
		"quality": "estimate",
	},
}

## Fracción de la energía de amolado que entra en la herramienta (ε), por abrasivo (claves de unión).
const ENERGY_PARTITION := {
	"al2o3": {
		"value": 0.725,
		"min": 0.60,
		"max": 0.85,
		"source": "Malkin y Guo 2007: 60–85 % en amolado ligero con muelas convencionales; Kohli, Guo y Malkin 1995: 60–75 % con Al₂O₃ (se toma el centro del intervalo)",
		"quality": "primary",
	},
	"sic": {
		"value": 0.725,
		"min": 0.60,
		"max": 0.85,
		"source": "sin medición propia: se toma la de las muelas convencionales (Malkin y Guo 2007)",
		"quality": "estimate",
	},
	"cbn": {
		"value": 0.20,
		"source": "Malkin y Guo 2007: ≈20 % con CBN, por la alta conductividad del grano (Kohli, Guo y Malkin 1995)",
		"quality": "primary",
	},
	"diamante": {
		"value": 0.20,
		"source": "sin medición en acero (no se amola acero con diamante): igual que el CBN, porque el diamante conduce aún mejor el calor",
		"quality": "estimate",
	},
}

## Factor que el agua aplica a ε mientras la superficie está por debajo de la ebullición en película.
const WET_FACTOR := {
	"value": 0.42,
	"source": "estimación a partir del modelo de grano único de Malkin y Guo 2007: en su ejemplo con CBN, ε baja del 36,5 % sin fluido al 15,5 % con fluido acuoso por debajo de la ebullición (factor 0,42)",
	"quality": "estimate",
}

## Aceros de afilado (claves de unión de CONTRATOS.md): dureza, revenido de referencia y propiedades térmicas.
## El revenido de referencia es la temperatura y el tiempo más bajos que el fabricante recomienda para ese uso:
## una exposición que iguale su parámetro de Hollomon–Jaffe empieza a ablandar el filo.
## thermal: k en W/(m·K), rho en kg/m³, cp en J/(kg·K).
const STEELS := {
	"vg10": {
		"name": "VG-10 (Takefu)",
		"family": "inoxidable martensítico",
		"hrc": {
			"value": 61.0,
			"source": "Takefu Special Steel, ficha de VG10: 61 HRC tras el temple (61,5 con subcero)",
			"quality": "primary",
		},
		"temper": {
			"c": 150.0,
			"min_c": 150.0,
			"max_c": 250.0,
			"time_s": 7200.0,
			"source": "Takefu Special Steel, ficha de VG10: revenido a 150–250 °C, como mínimo 120 min a 150 °C",
			"quality": "primary",
		},
		"thermal": {
			"k": 30.0,
			"rho": 7700.0,
			"cp": 460.0,
			"source": "Takefu no publica propiedades térmicas: se toman las del 1.4116 (SIJ), otro inoxidable martensítico de ≈15 % Cr",
			"quality": "estimate",
		},
	},
	"x50crmov15": {
		"name": "1.4116 (X50CrMoV15)",
		"family": "inoxidable martensítico",
		"hrc": {
			"value": 56.0,
			"source": "SIJ Metal Ravne, SINOXX 4116 (1.4116): «excelente dureza (Rc 56)»",
			"quality": "primary",
		},
		"temper": {
			"c": 150.0,
			"time_s": 3600.0,
			"source": "SIJ Metal Ravne, diagrama de revenido de 1 h: la dureza baja de forma continua desde ≈100 °C. No hay temperatura de revenido de fábrica publicada para cuchillos: se toman 150 °C",
			"quality": "estimate",
		},
		"thermal": {
			"k": 30.0,
			"rho": 7700.0,
			"cp": 460.0,
			"source": "SIJ Metal Ravne, SINOXX 4116: 30,0 W/(m·K), 7,7 g/cm³ y 0,46 J/(g·K) a temperatura ambiente",
			"quality": "primary",
		},
	},
	"14c28n": {
		"name": "Alleima 14C28N",
		"family": "inoxidable martensítico",
		"hrc": {
			"value": 59.0,
			"source": "Alleima, guía de temple de 14C28N: 59 HRC con revenido de 2 h a 175 °C (57 a 225 °C y 55 a 350 °C); la ficha da 61 → 55,5 HRC entre 100 y 350 °C",
			"quality": "primary",
		},
		"temper": {
			"c": 175.0,
			"min_c": 175.0,
			"max_c": 350.0,
			"time_s": 7200.0,
			"source": "Alleima, guía de temple de 14C28N (piezas): revenido de 2 h a 175, 225 o 350 °C",
			"quality": "primary",
		},
		"thermal": {
			"k": 30.0,
			"rho": 7700.0,
			"cp": 460.0,
			"source": "Alleima solo publica la densidad (7,7 g/cm³); k y cp del 1.4116 (SIJ) por analogía",
			"quality": "estimate",
		},
	},
	"m2": {
		"name": "M2 · 1.3343 (HS6-5-2)",
		"family": "acero rápido",
		"hrc": {
			"value": 64.0,
			"min": 62.0,
			"max": 67.0,
			"source": "Böhler S600 (M2): mínimo 62 HRC en barra templada y revenida; 64–67 HRC en su diagrama de revenido (3 × 2 h)",
			"quality": "primary",
		},
		"temper": {
			"c": 550.0,
			"min_c": 550.0,
			"max_c": 570.0,
			"time_s": 7200.0,
			"source": "Böhler S600 (M2): revenido a 550–570 °C, al menos 2 h y 3 ciclos",
			"quality": "primary",
		},
		"thermal": {
			"k": 21.8,
			"rho": 8070.0,
			"cp": 433.0,
			"source": "Böhler S600 a 20 °C: 8,07 kg/dm³, 21,8 W/(m·K) y 0,433 kJ/(kg·K)",
			"quality": "primary",
		},
	},
	"1095": {
		"name": "AISI 1095 · 1.1274 (C100S)",
		"family": "acero al carbono",
		"hrc": {
			"value": 60.0,
			"min": 60.0,
			"max": 61.0,
			"source": "New Jersey Steel Baron (tabla basada en ASM y Crucible): 60–61 HRC con revenido de 2 × 2 h a 204 °C",
			"quality": "secondary",
		},
		"temper": {
			"c": 204.0,
			"min_c": 177.0,
			"max_c": 232.0,
			"time_s": 7200.0,
			"source": "New Jersey Steel Baron: 2 × 2 h; 177 °C → 63–64 HRC, 204 °C → 60–61, 232 °C → 57–58. Knife Steel Nerds: 204 °C (400 °F) como punto de partida para cuchillos",
			"quality": "secondary",
		},
		"thermal": {
			"k": 49.0,
			"rho": 7900.0,
			"cp": 460.0,
			"source": "HS-Folien, ficha técnica del 1.1274 (C100S): 49 W/(m·K) a 20 °C, 7,9 g/cm³ y 460 J/(kg·K)",
			"quality": "secondary",
		},
	},
}

const NOTE := "Índice relativo: 0 es no calentar y 1 es llegar al revenido de este acero en ese tiempo. Es el modelo de cuerpo grueso de Malkin y Guo (2007), no la temperatura del filo: un filo fino no cumple la hipótesis de sólido semiinfinito y se calienta más. Umbrales: 130 °C (el agua deja de enfriar), revenido ajustado al tiempo con Hollomon–Jaffe y ≈723 °C (quemado)."

## C de Hollomon–Jaffe (t en horas) de la curva maestra del acero W de 0,89 % C: c = 12,2 con t en segundos, que
## con t en horas es 12,2 + log10(3600) (Thomas, Speer, Matlock, Krauss y Hackenberg, ICOMAT-08, fig. 1).
const HJ_C_STEEL_W := 15.756302500767288

## Curva de revenido del 14C28N (Alleima): [T °C, HRC] tras 30 min. La usa también el VG-10 por analogía.
const CURVE_14C28N := [[100.0, 61.0], [175.0, 59.5], [225.0, 57.4], [275.0, 55.9], [350.0, 55.5], [450.0, 56.1], [500.0, 56.6]]

## Curvas de revenido: dureza (HRC) frente a la temperatura de revenido en un tiempo dado (time_s + points
## [[T °C, HRC]]) o frente al parámetro de Hollomon–Jaffe (points_p [[P, HRC]], P = T(K)·(hj_c + log10 t_h)).
## hj_c es la C (t en horas) con la que se pasa cualquier exposición a esa curva. band: [[T, HRC mín, HRC máx]]
## cuando la fuente da dos curvas. Sirven para convertir el revenido acumulado de un filo en pérdida de dureza
## (core/taller/edge_thermal.gd). Los valores están leídos de las figuras de cada ficha (±0,5 HRC, ±5 °C).
const TEMPER_CURVES := {
	"x50crmov15": {
		"time_s": 3600.0,
		"hj_c": HJ_C,
		"points": [[25.0, 57.55], [100.0, 56.95], [150.0, 56.25], [200.0, 54.85], [250.0, 54.0], [300.0, 53.55], [350.0, 53.5], [400.0, 53.9], [450.0, 54.25], [500.0, 52.85], [525.0, 49.35], [550.0, 44.05], [575.0, 40.2], [600.0, 36.6], [625.0, 33.85]],
		"band": [[25.0, 55.2, 59.9], [100.0, 54.8, 59.1], [150.0, 54.1, 58.4], [200.0, 52.3, 57.4], [250.0, 51.5, 56.5], [300.0, 51.4, 55.7], [350.0, 51.4, 55.6], [400.0, 51.9, 55.9], [450.0, 52.5, 56.0], [500.0, 51.4, 54.3], [525.0, 47.0, 51.7], [550.0, 42.1, 46.0], [575.0, 39.2, 41.2], [600.0, 36.3, 36.9], [625.0, 33.0, 34.7]],
		"source": "SIJ Metal Ravne, SINOXX 4116 (1.4116): diagrama de revenido de 1 h con dos curvas (banda); se usa la línea media. Valores leídos de la figura",
		"quality": "primary",
	},
	"14c28n": {
		"time_s": 1800.0,
		"hj_c": HJ_C,
		"points": CURVE_14C28N,
		"source": "Alleima, ficha de 14C28N (2024): revenido de 30 min, fleje de 2,5 mm templado a 1050 °C 5 min en aceite; valores leídos de la figura (61 → 55,5 HRC entre 100 y 350 °C, 56,6 a 500 °C)",
		"quality": "primary",
	},
	"vg10": {
		"time_s": 1800.0,
		"hj_c": HJ_C,
		"points": CURVE_14C28N,
		"source": "ESTIMACIÓN: Takefu no publica la curva de revenido del VG-10 (solo 150–250 °C y endurecimiento secundario hasta ≈450 °C); se usa la forma de la del 14C28N (Alleima), otro inoxidable de cuchillo de ≈61 HRC. Solo se usa la diferencia de dureza, no el valor absoluto",
		"quality": "estimate",
	},
	"m2": {
		"time_s": 21600.0,
		"hj_c": HJ_C,
		"points": [[400.0, 61.1], [420.0, 61.2], [460.0, 62.5], [500.0, 64.6], [520.0, 65.4], [540.0, 65.7], [560.0, 65.0], [580.0, 63.5], [600.0, 61.9], [620.0, 59.6], [625.0, 57.6]],
		"source": "Böhler S600 (M2): diagrama de revenido de 3 × 2 h en vacío, probeta de 25 mm, curva de temple a 1180 °C; valores leídos de la figura (400–625 °C)",
		"quality": "primary",
	},
	"1095": {
		"hj_c": HJ_C_STEEL_W,
		"points_p": [[5000.0, 66.8], [6000.0, 67.8], [6500.0, 66.5], [7000.0, 64.2], [7500.0, 62.3], [8000.0, 60.0], [8500.0, 58.2], [9000.0, 56.2], [9500.0, 53.2], [10000.0, 50.8], [10500.0, 48.2], [11000.0, 45.8], [11500.0, 44.0], [12000.0, 41.0], [12500.0, 38.0], [13000.0, 35.2], [13500.0, 32.5], [14000.0, 29.2], [14500.0, 26.2], [15000.0, 22.8], [15500.0, 19.4], [16000.0, 16.2], [16700.0, 12.0]],
		"source": "Curva maestra de Hollomon y Jaffe (1945) del acero W de 0,89 % C (revenidos de 100 a 700 °C), dibujada por Thomas, Speer, Matlock, Krauss y Hackenberg (ICOMAT-08, TMS 2009), fig. 1: HRC frente a T(log t + 12,2), t en s. Valores leídos de la figura (dispersión ±1,5 HRC). Coincide con la tabla de New Jersey Steel Baron para el 1095 (2 × 2 h) dentro de 1,5 HRC",
		"quality": "secondary",
	},
}


## Parámetro de Hollomon y Jaffe: P = T·(C + log10 t), con T en kelvin y t en horas.
static func hollomon_jaffe(t_c: float, time_s: float, c: float = HJ_C) -> float:
	return (t_c + 273.15) * (c + Js.log10(_hours(time_s)))


## Temperatura (°C) con la que time_s segundos dan el parámetro p: el mismo revenido en otro tiempo.
static func hj_temperature(p: float, time_s: float, c: float = HJ_C) -> float:
	return p / (c + Js.log10(_hours(time_s))) - 273.15


## Tiempo (s) que da el parámetro p a t_c grados.
static func hj_time(p: float, t_c: float, c: float = HJ_C) -> float:
	return 3600.0 * pow(10.0, p / (t_c + 273.15) - c)


## Temperatura (°C) a la que hay que estar time_s segundos para revenir como ref_c grados durante ref_s segundos.
static func equivalent_temperature(ref_c: float, ref_s: float, time_s: float, c: float = HJ_C) -> float:
	return hj_temperature(hollomon_jaffe(ref_c, ref_s, c), time_s, c)


## Tiempo (s) a t_c grados que reviene como ref_c grados durante ref_s segundos.
static func equivalent_time(ref_c: float, ref_s: float, t_c: float, c: float = HJ_C) -> float:
	return hj_time(hollomon_jaffe(ref_c, ref_s, c), t_c, c)


## Revenido equivalente (°C, sin tope) de un acero para una exposición de exposure_s segundos: la temperatura con
## la que ese tiempo iguala su revenido de referencia (Hollomon–Jaffe).
static func temper_equivalent_c(steel_id: String, exposure_s: float, c: float = HJ_C) -> float:
	var temper: Dictionary = STEELS[steel_id]["temper"]
	return equivalent_temperature(temper["c"], temper["time_s"], exposure_s, c)


## Umbral de revenido (°C) de un acero para una exposición de exposure_s segundos. Nunca por encima del quemado.
static func temper_threshold_c(steel_id: String, exposure_s: float, c: float = HJ_C) -> float:
	return minf(temper_equivalent_c(steel_id, exposure_s, c), BURN_C)


## Difusividad térmica α = k/(ρ·cp) del acero, en m²/s.
static func diffusivity(steel_id: String) -> float:
	var th: Dictionary = STEELS[steel_id]["thermal"]
	return th["k"] / (th["rho"] * th["cp"])


## C de Hollomon–Jaffe (t en horas) con la que se lleva cualquier exposición a la curva de revenido del acero: la
## de su curva (1095: la del acero W) o, si no tiene curva, HJ_C.
static func curve_hj_c(steel_id: String) -> float:
	var curve: Dictionary = TEMPER_CURVES.get(steel_id, {})
	return float(curve.get("hj_c", HJ_C))


## Parámetro de Hollomon–Jaffe del revenido de fábrica del acero (STEELS.temper), con la C de su curva.
static func factory_temper_p(steel_id: String) -> float:
	var temper: Dictionary = STEELS[steel_id]["temper"]
	return hollomon_jaffe(temper["c"], temper["time_s"], curve_hj_c(steel_id))


## Revenido acumulado: nuevo parámetro de Hollomon–Jaffe tras dt_s segundos a t_c grados, partiendo de p. Lo ya
## revenido se pasa a su tiempo equivalente a t_c (t_eq = 10^(p/T − c) horas) y se le suma dt (regla de adición del
## tiempo equivalente; exacta por tramos isotermos). Nunca baja: a menos temperatura no se «desreviene». Si dt no
## llega a una diezmillonésima de t_eq, devuelve p tal cual (no cambia nada y ahorra la potencia).
static func accumulate_temper(p: float, t_c: float, dt_s: float, c: float = HJ_C) -> float:
	if dt_s <= 0.0:
		return p
	var t_k := t_c + 273.15
	if t_k <= 0.0:
		return p
	var dt_h := dt_s / 3600.0
	var log_teq := p / t_k - c  # log10 del tiempo equivalente en horas
	var log_dt := log(dt_h) / LN10
	if log_teq > log_dt + 7.0:
		return p
	var teq := pow(10.0, log_teq)
	var p_new := t_k * (c + log(teq + dt_h) / LN10)
	return maxf(p, p_new)


## Dureza (HRC) que da la curva de revenido del acero para un parámetro p (con la C de la curva). Devuelve
## { hrc, curve_temp_c (la temperatura equivalente en el tiempo de la curva; null si la curva es maestra), below,
## beyond } o {} si el acero no tiene curva. Fuera de la curva se toma el extremo y below/beyond lo dicen.
static func curve_hardness(steel_id: String, p: float) -> Dictionary:
	var curve: Dictionary = TEMPER_CURVES.get(steel_id, {})
	if curve.is_empty():
		return {}
	var c: float = curve["hj_c"]
	var x := p
	var pts: Array = []
	var temp: Variant = null
	if curve.has("points_p"):
		pts = curve["points_p"]
	else:
		pts = curve["points"]
		var th := float(curve["time_s"]) / 3600.0
		x = p / (c + log(th) / LN10) - 273.15
		temp = x
	var first: Array = pts[0]
	var last: Array = pts[pts.size() - 1]
	var hrc: float = first[1]
	if x >= float(last[0]):
		hrc = last[1]
	elif x > float(first[0]):
		for i in range(1, pts.size()):
			var hi: Array = pts[i]
			if x <= float(hi[0]):
				var lo: Array = pts[i - 1]
				var f := (x - float(lo[0])) / (float(hi[0]) - float(lo[0]))
				hrc = float(lo[1]) + f * (float(hi[1]) - float(lo[1]))
				break
	return { "hrc": hrc, "curve_temp_c": temp, "below": x < float(first[0]), "beyond": x > float(last[0]) }


## Pérdida de dureza de un filo con parámetro de revenido p frente al revenido de fábrica, en la curva del acero:
## { loss_hrc (≥ 0), hrc (la nominal de STEELS menos la pérdida), hrc_curve_factory, hrc_curve_now, beyond (p más
## allá del final de la curva: la pérdida es un mínimo), source, quality } o {} sin curva. Si la curva sube
## (endurecimiento secundario), la pérdida no baja de 0.
static func temper_loss(steel_id: String, p: float) -> Dictionary:
	if not STEELS.has(steel_id) or not TEMPER_CURVES.has(steel_id):
		return {}
	var p0 := factory_temper_p(steel_id)
	var ref := curve_hardness(steel_id, p0)
	var now := curve_hardness(steel_id, maxf(p, p0))
	var loss := maxf(0.0, float(ref["hrc"]) - float(now["hrc"]))
	var curve: Dictionary = TEMPER_CURVES[steel_id]
	return {
		"loss_hrc": loss,
		"hrc": float(STEELS[steel_id]["hrc"]["value"]) - loss,
		"hrc_curve_factory": ref["hrc"],
		"hrc_curve_now": now["hrc"],
		"beyond": bool(now["beyond"]),
		"source": curve["source"],
		"quality": curve["quality"],
	}


## Intervalos del parámetro P, en pares [desde, hasta] (INF si no se cierra), en los que un filo de este acero ha
## perdido al menos loss_hrc frente al revenido de fábrica: lo mismo que temper_loss(acero, P).loss_hrc >= loss_hrc,
## calculado una sola vez. La dureza de la curva es lineal a trozos en P (la temperatura de una curva de tiempo fijo
## es afín en P), así que los cortes son exactos. Vacío si el acero no tiene curva o nunca pierde tanto.
static func loss_ranges(steel_id: String, loss_hrc: float = 1.0) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not STEELS.has(steel_id) or not TEMPER_CURVES.has(steel_id):
		return out
	var curve: Dictionary = TEMPER_CURVES[steel_id]
	var p0 := factory_temper_p(steel_id)
	var limit := float(curve_hardness(steel_id, p0)["hrc"]) - loss_hrc
	# Vértices de la curva pasados a P (x = P/k − 273,15 en las curvas de tiempo fijo)
	var pts: Array = curve["points_p"] if curve.has("points_p") else curve["points"]
	var k := 1.0
	var off := 0.0
	if not curve.has("points_p"):
		k = float(curve["hj_c"]) + log(float(curve["time_s"]) / 3600.0) / LN10
		off = 273.15
	var bps := PackedFloat64Array([p0])
	for pt in pts:
		var pp := (float(pt[0]) + off) * k
		if pp > p0:
			bps.append(pp)
	# Entre dos vértices la dureza es lineal: el tramo donde queda por debajo del límite sale de un corte
	for i in bps.size() - 1:
		var a := bps[i]
		var b := bps[i + 1]
		var ha := float(curve_hardness(steel_id, a)["hrc"])
		var hb := float(curve_hardness(steel_id, b)["hrc"])
		var lo := INF
		var hi := -INF
		if ha <= limit and hb <= limit:
			lo = a
			hi = b
		elif ha <= limit:
			lo = a
			hi = a + (limit - ha) / (hb - ha) * (b - a)
		elif hb <= limit:
			lo = a + (limit - ha) / (hb - ha) * (b - a)
			hi = b
		if lo <= hi:
			if out.size() > 0 and out[out.size() - 1] >= lo:
				out[out.size() - 1] = hi
			else:
				out.append(lo)
				out.append(hi)
	# Más allá del último vértice la dureza ya no cambia
	var last := bps[bps.size() - 1]
	if float(curve_hardness(steel_id, last)["hrc"]) <= limit:
		if out.size() > 0 and out[out.size() - 1] >= last:
			out[out.size() - 1] = INF
		else:
			out.append(last)
			out.append(INF)
	return out


## Riesgo térmico relativo al amolar. p = { power_w, contact_area_mm2, speed_ms, wet, abrasive_id, steel_id,
## dwell_s, contact_length_mm (opcional) }:
## - power_w: potencia de amolado en el contacto (W), P = Ft·Vs.
## - speed_ms: velocidad con la que el contacto barre la herramienta (m/s); 0 si se mantiene quieta.
## - contact_length_mm: largo del contacto en la dirección del barrido (por defecto, √A).
## - dwell_s: tiempo seguido sobre la muela (s); también es la exposición que cuenta para el revenido.
## Devuelve { index, level: "bajo" | "medio" | "alto" | "quemado", threshold_c, threshold_kind, thresholds_c,
## partition, partition_dry, coolant_effective, regime, peclet, exposure_s, quality: "estimate", note, sources }.
static func heat_risk(p: Dictionary) -> Dictionary:
	var steel_id := str(p.get("steel_id", ""))
	if not STEELS.has(steel_id):
		return {
			"index": null,
			"level": null,
			"threshold_c": null,
			"threshold_kind": null,
			"thresholds_c": null,
			"partition": null,
			"partition_dry": null,
			"coolant_effective": null,
			"regime": null,
			"peclet": null,
			"exposure_s": null,
			"quality": "estimate",
			"note": "Sin datos de revenido para «%s»: el índice solo se calcula para los aceros de STEELS." % steel_id,
			"sources": [],
		}
	var steel: Dictionary = STEELS[steel_id]
	var thermal: Dictionary = steel["thermal"]
	var k: float = thermal["k"]
	var alpha := diffusivity(steel_id)
	var area_mm2 := maxf(input_num(p, "contact_area_mm2", 10.0), 1e-3)
	var area_m2 := area_mm2 * 1e-6
	var half_len_m := 0.5 * maxf(input_num(p, "contact_length_mm", sqrt(area_mm2)), 1e-3) * 1e-3
	var power := maxf(input_num(p, "power_w", 0.0), 0.0)
	var speed := maxf(input_num(p, "speed_ms", 0.0), 0.0)
	var dwell := maxf(input_num(p, "dwell_s", 1.0), 1e-3)
	var wet := input_flag(p, "wet", false)
	var abrasive_id := str(p.get("abrasive_id", "al2o3"))
	var partition: Dictionary = ENERGY_PARTITION.get(abrasive_id, ENERGY_PARTITION["al2o3"])
	var eps: float = partition["value"]
	var per_flux := _rise_per_flux(k, alpha, area_m2, half_len_m, speed, dwell)
	var unit: float = per_flux[0]  # K por W/m²
	var eps_eff := eps
	var rise := eps * power / area_m2 * unit
	var cooled := false
	if wet:
		var wet_factor: float = WET_FACTOR["value"]
		var rise_wet := eps * wet_factor * power / area_m2 * unit
		if AMBIENT_C + rise_wet < BURNOUT_WATER_C:
			rise = rise_wet
			eps_eff = eps * wet_factor
			cooled = true
	var temper_c := temper_equivalent_c(steel_id, dwell)
	var threshold := minf(temper_c, BURN_C)
	var theta := AMBIENT_C + rise
	var level := "bajo"
	if theta >= BURN_C:
		level = "quemado"
	elif theta >= threshold:
		level = "alto"
	elif theta >= BURNOUT_WATER_C:
		level = "medio"
	var sources: Array[String] = [
		"Malkin y Guo 2007, «Thermal analysis of grinding», CIRP Annals 56/2 (reparto de energía, ecuación 2, 130 °C y 723 °C)",
		"Carslaw y Jaeger 1959, «Conduction of heat in solids» (fuente circular fija sobre un sólido semiinfinito)",
		str(THRESHOLDS["hollomon_jaffe_c"]["source"]),
		str(partition["source"]),
		str(steel["temper"]["source"]),
		str(thermal["source"]),
	]
	if cooled:
		sources.append(str(WET_FACTOR["source"]))
	return {
		"index": rise / maxf(threshold - AMBIENT_C, 1e-9),
		"level": level,
		"threshold_c": threshold,
		# «quemado» si el revenido equivalente de ese tiempo queda por encima de 723 °C (aceros rápidos)
		"threshold_kind": "revenido" if temper_c < BURN_C else "quemado",
		"thresholds_c": { "burnout": BURNOUT_WATER_C, "temper": temper_c, "burn": BURN_C },
		"partition": eps_eff,
		"partition_dry": eps,
		"coolant_effective": cooled,
		"regime": per_flux[1],
		"peclet": per_flux[2],
		"exposure_s": dwell,
		"quality": "estimate",
		"note": NOTE,
		"sources": sources,
	}


## Calentamiento por unidad de flujo (K por W/m²) de un cuerpo grueso: [subida, régimen, número de Péclet].
## Quieta: círculo de igual área fijo durante t (Carslaw y Jaeger). Barriendo: banda móvil de Malkin y Guo (ec. 2),
## válida con Péclet L = V·l/(2α) > 5 y aceptable hasta L = 1; por debajo sobrestima, y el mínimo con la fuente
## quieta lo corrige.
static func _rise_per_flux(k: float, alpha: float, area_m2: float, half_len_m: float, v: float, t: float) -> Array:
	var a := sqrt(area_m2 / PI)
	var tau := sqrt(alpha * t)
	var still := 2.0 * tau / k * (1.0 / sqrt(PI) - _ierfc(a / (2.0 * tau)))
	if v <= 0.0:
		return [still, "quieta", 0.0]
	var moving := MOVING_COEF * sqrt(alpha * half_len_m) / (k * sqrt(v))
	var peclet := v * half_len_m / (2.0 * alpha)
	if moving < still:
		return [moving, "barrido", peclet]
	return [still, "quieta", peclet]


## Función de error complementaria para x ≥ 0 (Abramowitz y Stegun 7.1.26, error absoluto ≤ 1,5·10⁻⁷).
static func _erfc(x: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var poly := t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))))
	return poly * exp(-x * x)


## Primera integral de erfc: ierfc(x) = e^(−x²)/√π − x·erfc(x).
static func _ierfc(x: float) -> float:
	return exp(-x * x) / sqrt(PI) - x * _erfc(x)


static func _hours(time_s: float) -> float:
	return maxf(time_s, 1e-3) / 3600.0


## Número de un diccionario de entrada (lo usan también las funciones de sharpening.gd): def si falta, si no es
## un número o si no es finito.
static func input_num(p: Dictionary, key: String, def: float) -> float:
	var v: Variant = p.get(key)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return def
	var f := float(v)
	return f if is_finite(f) else def


## Sí o no de un diccionario de entrada: un bool tal cual; un número, si no es 0; un texto, si es «true», «1»,
## «sí» o «si»; si falta o es otra cosa, def. Comparar con == true no sirve: con un entero es un error en Godot.
static func input_flag(p: Dictionary, key: String, def: bool) -> bool:
	var v: Variant = p.get(key)
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return float(v) != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v).strip_edges().to_lower() in ["true", "1", "sí", "si"]
	return def
