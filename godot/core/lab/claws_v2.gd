## Tribología biológica · correcciones de datos de las garras para el modelo 2.0 (unidad 1k: revisión de las rapaces).
##
## data.gd es el port exacto de data.js (el oráculo 1.x) y no se toca. Aquí van las correcciones y confirmaciones de
## la 2.0 por id de garra: cada campo es { value, source, quality } y, si tiene incertidumbre, también min y max (la
## banda que la interfaz enseña). quality: "primary" (medido en la especie), "secondary" (medido en una especie
## cercana o escalado poco) o "estimate" (sin medición en la especie; se dice por qué).
## Catalog aplica OVERRIDES solo en el modelo 2.0 (apply() hace lo mismo y es idempotente).
##
## Qué se corrige y por qué (detalle en docs/fisica/coche-en-marcha.md, apartado 8):
##   - Agarre: la 1.x escalaba LINEALMENTE desde el gavilán de Cooper (~22 N por kg). Sustaita & Hertel (2010) midieron
##     el agarre in vivo y dan su escalado: pendiente RMA 0,97 (IC 95 % 0,79-1,15) en accipítridos y 0,86 (0,71-1,01)
##     en halcones. Se escala desde su tabla 1 con esa pendiente y se da la banda: abajo, la pendiente baja del IC;
##     arriba, ×2,96, porque la técnica de Ward et al. (2002) midió 7,7 N en cernícalos donde ellos midieron 2,6 N
##     (y porque las aves no siempre aprietan al máximo contra un transductor). Los «400 psi» del águila calva o los
##     «500 psi» del búho no tienen medición publicada (y una presión no es una fuerza): no se usan.
##   - Halcón peregrino: su agarre está medido (12,7 N la hembra de 774 g): la 1.x ya estaba bien; se confirma con
##     fuente. Su picado: los >300 km/h de la ficha no están medidos en la naturaleza (radar: 31-39 m/s, Alerstam 1987).
##   - Búho, lechuza y buitre: sin medición propia; se confirma el valor 1.x con su banda (los búhos aprietan al menos
##     como un gavilán de su tamaño, Ward 2002; el buitre tiene pie de caminar, Wang et al. 2024).
##   - Dureza y módulo de la queratina (hv, E): sin medición en talones de rapaz; se quedan los de la garra de avestruz
##     (McKittrick et al. 2012), y así la queratina (~30 HV) nunca raya el acero (~100 HV) de un coche.
##   - Casuario (no es una rapaz; corrección de la ficha pedida en la unidad 4b): la 1.x decía «patada a 50 km/h», pero
##     esa es su velocidad de carrera (Healy 2022). La patada que modela el coche en marcha (unidad 4d) es un salto con los
##     pies por delante a unos 17 km/h (4,84 m/s: el trabajo por kilo de músculo del salto de un ave, Henry et al. 2005,
##     con la masa muscular de la pata de una ratite, Hutchinson et al. 2015): estimación. La ficha lo dice desde la 4b y,
##     desde la unidad 4i, el golpe del banco (`strike`) sale de esa patada (kick_strike: su velocidad, con la masa de los
##     músculos de la pata que patea); la 1.x le daba 8 m/s y 5 kg (160 J, una estimación sin fuente). Desde la unidad 4i-B2,
##     su masa es la de la hembra del coche en marcha (casuario_mass: 58 kg, Grzimek 2003), no los 60 kg sin fuente de la 1.x.
## OVERRIDES junta las correcciones fijas (_FIXED) con el golpe del casuario, que se calcula una sola vez al cargar el
## script con las funciones del coche en marcha (MovingCar.kick_leap_ms y MovingCar.KICK): no se copian sus números. Nadie
## lo vuelve a escribir (es de solo lectura, como una constante; lo vigila tests/lab/test_threads.gd). La precarga
## ClawsV2 ↔ MovingCar es cíclica a propósito: MovingCar aplica estas correcciones y ClawsV2 usa su patada.
## Uso: const ClawsV2 = preload("res://core/lab/claws_v2.gd"); ClawsV2.apply(claw) devuelve una copia corregida.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Data = preload("res://core/lab/data.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")

# ── Escalado del agarre (Sustaita & Hertel 2010, J. Exp. Biol. 213:2617, tabla 1 y fig. 2) ──
## Gavilán de Cooper (Accipiter cooperii), hembra adulta: 9,77 ± 0,73 N (n = 6) con 450,4 g.
const COOPER_GRIP_N := 9.77
const COOPER_MASS_KG := 0.4504
## Pendiente RMA del agarre frente a la masa en accipítridos: 0,97 (IC 95 % 0,79-1,15).
const ACCIPITER_SLOPE := 0.97
const ACCIPITER_SLOPE_LO := 0.79
const ACCIPITER_SLOPE_HI := 1.15
## Halcón peregrino (Falco peregrinus), hembra: 12,7 ± 2,60 N (n = 3) con 773,8 g; pendiente de los halcones 0,86
## (IC 95 % 0,71-1,01).
const PEREGRINE_GRIP_N := 12.7
const PEREGRINE_GRIP_SEM_N := 2.6
const PEREGRINE_MASS_KG := 0.7738
const FALCON_SLOPE := 0.86
const FALCON_SLOPE_LO := 0.71
const FALCON_SLOPE_HI := 1.01
## Dispersión entre técnicas: Ward et al. (2002) midieron 7,7 N en cernícalos de 122 g; Sustaita & Hertel, 2,6 N en
## cernícalos de 112 g (lo discuten ellos mismos). Es la cota alta de la banda: 7,7/2,6.
const TECHNIQUE_FACTOR := 7.7 / 2.6

const SRC_SUSTAITA := "Sustaita D, Hertel F (2010). In vivo bite and grip forces, morphology and prey-killing behavior of North American accipiters (Accipitridae) and falcons (Falconidae). J. Exp. Biol. 213:2617-2628, tabla 1 y fig. 2. doi:10.1242/jeb.041731"
const SRC_WARD := "Ward AB, Weigl PD, Conroy RM (2002). Functional morphology of raptor hindlimbs: implications for resource partitioning. Auk 119:1052-1063. doi:10.1642/0004-8038(2002)119[1052:FMORHI]2.0.CO;2 (citado por Sustaita & Hertel 2010: 7,7 ± 1,6 N en cernícalos de 122 g; los búhos aprietan más que las rapaces diurnas de su tamaño)"
const SRC_WANG_2024 := "Wang et al. (2024). A comparative study on grasping-related muscles in five Accipitriformes species. Anat. Rec. 307:3344-3354. doi:10.1002/ar.25433 (el buitre negro dedica su musculatura a flexores proximales: agarre rudimentario)"
const SRC_ALERSTAM_1987 := "Alerstam T (1987). Radar observations of the stoop of the Peregrine Falcon Falco peregrinus and the Goshawk Accipiter gentilis. Ibis 129:267-273 (máximos de 31-39 m/s en intervalos de 10 s)"
const SRC_TUCKER_1998 := "Tucker VA, Cade TJ, Tucker AE (1998). Diving speeds and angles of a gyrfalcon (Falco rusticolus). J. Exp. Biol. 201:2061-2070 (52-58 m/s en los siete picados más rápidos)"
const SRC_MCKITTRICK := "McKittrick J, Chen P-Y, Bodde SG, Yang W, Novitskaya EE, Meyers MA (2012). The structure, functions, and mechanical properties of keratin. JOM 64:449-468 (queratina de garra de avestruz, Bonser: E 2,0 GPa a 50 % HR). doi:10.1007/s11837-012-0302-8"
## Casuario: las mismas citas que la patada del coche en marcha (unidad 4d).
const SRC_HEALY_2022 := "Healy TP (2022). Southern cassowary (Casuarius casuarius), Birds of the World, Cornell Lab of Ornithology («hasta 50 km/h»; recopilación, sin la medición original)"
const SRC_HENRY_2005 := "Henry HT, Ellerby DJ, Marsh RL (2005). Performance of guinea fowl Numida meleagris during jumping requires storage and release of elastic energy. J. Exp. Biol. 208:3293-3302, doi:10.1242/jeb.01764 (salto máximo: 5,3 pesos corporales y 45 J por kg de músculo de la pata, unos dos tercios del máximo esperable en el músculo esquelético)"
const SRC_HUTCHINSON_2015 := "Hutchinson JR et al. (2015). Musculoskeletal modelling of an ostrich (Struthio camelus) pelvic limb. PeerJ 3:e1001, doi:10.7717/peerj.1001, tabla 2 (músculos de una pata de un avestruz hembra de 65,3 kg, disecados: 8,50 kg, el 13,0 % de su masa)"

const _SRC_SCALED_ACC := "Escalado desde el gavilán de Cooper hembra (9,77 N, 450 g) con la pendiente de los accipítridos, 0,97 (banda: pendiente 0,79 abajo; ×2,96 arriba, la dispersión entre técnicas con Ward et al. 2002). " + SRC_SUSTAITA

## Correcciones y confirmaciones fijas de la 2.0 (sin el golpe del casuario, que se calcula: OVERRIDES). force: agarre
## máximo de UN pie (N), el mismo sentido que en la 1.x («máximo esfuerzo: zarpazo o agarre»). min y max: banda de
## incertidumbre. desc: texto corregido de la ficha.
const _FIXED := {
	"aguila": {
		"force": {
			"value": 100.9, "min": 65.4, "max": 298.8, "unit": "N", "quality": "estimate",
			"source": "Águila real de 5 kg. " + _SRC_SCALED_ACC + ". La 1.x usaba 110 N (22 N/kg lineal); dentro de la banda.",
		},
		"desc": {
			"value": "Águila real (Aquila chrysaetos), talón de queratina-β. Agarre de ~100 N por pie (65-300 N): escalado de los gavilanes medidos in vivo (Sustaita & Hertel 2010). Los «400 psi» que circulan no tienen medición publicada. La queratina no corta el acero: en un coche solo marca la pintura.",
			"quality": "estimate", "source": SRC_SUSTAITA,
		},
	},
	"arpia": {
		"force": {
			"value": 178.5, "min": 104.1, "max": 528.5, "unit": "N", "quality": "estimate",
			"source": "Arpía hembra de 9 kg. " + _SRC_SCALED_ACC + ". La 1.x usaba 200 N; dentro de la banda. Sin medición en la especie: sus patas enormes podrían ponerla en la parte alta.",
		},
		"desc": {
			"value": "La rapaz más poderosa: caza monos y perezosos en la copa. Agarre de ~180 N por pie (100-530 N), escalado de los gavilanes medidos (Sustaita & Hertel 2010): nadie lo ha medido en una arpía. Su talón trasero, de hasta ~13 cm, es el más largo de las águilas vivas.",
			"quality": "estimate", "source": SRC_SUSTAITA + "; talón: Guinness World Records, «Longest eagle talons» (hasta 13 cm)",
		},
	},
	"halcon": {
		"force": {
			"value": 15.8, "min": 12.1, "max": 46.9, "unit": "N", "quality": "secondary",
			"source": "Halcón peregrino hembra de 1,0 kg: 12,7 ± 2,6 N medidos con 774 g, escalados con la pendiente de los halcones, 0,86 (banda: la media menos su error con pendiente 0,71; ×2,96 arriba). " + SRC_SUSTAITA + ". La 1.x (15 N) ya encajaba.",
		},
		"strike": {
			"value": { "v": 40.0, "m": 0.25 }, "quality": "secondary",
			"source": "v: máximos de 31-39 m/s medidos por radar en picados reales (" + SRC_ALERSTAM_1987 + "); un gerifalte adiestrado llegó a 52-58 m/s (" + SRC_TUCKER_1998 + "). m: masa efectiva por garra, estimación de la 1.x.",
		},
		"desc": {
			"value": "Garra corta y muy afilada. Los halcones agarran menos que los gavilanes (rematan con el pico): 12,7 N medidos en hembras. En picado real el radar ha medido hasta ~140 km/h (y un gerifalte adiestrado, ~200 km/h); los 389 km/h de «Frightful» (1999) son un récord de cetrería sin publicación científica.",
			"quality": "secondary", "source": SRC_SUSTAITA + "; " + SRC_ALERSTAM_1987 + "; " + SRC_TUCKER_1998,
		},
	},
	"buho": {
		"force": {
			"value": 45.0, "min": 41.5, "max": 122.9, "unit": "N", "quality": "estimate",
			"source": "Búho de 2 kg. Sin medición publicada verificable: abajo, lo que apretaría un gavilán de su masa (41,5 N con la pendiente 0,97, " + SRC_SUSTAITA + "), porque los búhos aprietan al menos como las rapaces diurnas de su tamaño (" + SRC_WARD + "); arriba, ×2,96 por la técnica. Se mantiene el valor 1.x.",
		},
		"desc": {
			"value": "Garra silenciosa, curvatura cerrada y punta de aguja. Los búhos aprietan más que las rapaces diurnas de su tamaño (Ward et al. 2002), pero los «500 psi» que circulan no tienen medición publicada: agarre estimado de 45 N (40-120 N).",
			"quality": "estimate", "source": SRC_WARD,
		},
	},
	"lechuza": {
		"force": {
			"value": 8.0, "min": 7.3, "max": 22.7, "unit": "N", "quality": "estimate",
			"source": "Lechuza de 0,35 kg: un gavilán de su masa daría 7,3-8,0 N con las pendientes 0,79-1,15 (" + SRC_SUSTAITA + "); arriba, ×2,96 por la técnica (" + SRC_WARD + "). Se mantiene el valor 1.x.",
		},
	},
	"buitre": {
		"force": {
			"value": 60.0, "min": 20.3, "max": 159.2, "unit": "N", "quality": "estimate",
			"source": "Buitre leonado de 8 kg: pie de caminar, con agarre rudimentario (" + SRC_WANG_2024 + "). Arriba, lo que apretaría un gavilán de su masa (159 N, " + SRC_SUSTAITA + "); abajo, ÷2,96. Se mantiene el valor 1.x.",
		},
	},
	"casuario": {
		"desc": {
			"value": "El ave más peligrosa: daga recta de ~10-12 cm en el dedo interno. Corre a unos 50 km/h, pero patea saltando con los pies por delante, a unos 17 km/h (estimación con el salto de un ave y el músculo de su pata). En Punción + Impacto se comporta como una puñalada. Fuerza y energía de la patada estimadas.",
			"quality": "estimate",
			"source": "Carrera: " + SRC_HEALY_2022 + ". Patada: salto con los pies por delante a 4,84 m/s, estimación del modelo del coche en marcha del programa, con el trabajo por kilo de músculo del salto de " + SRC_HENRY_2005 + " y la masa muscular de la pata de " + SRC_HUTCHINSON_2015,
		},
	},
}

## Campos que la 2.0 confirma sin cambiar el valor (se citan en la ficha): dureza y módulo de la queratina.
const KERATIN_SOURCE := { "source": SRC_MCKITTRICK, "quality": "secondary" }

## Todas las correcciones de la 2.0: las fijas (_FIXED) y el golpe del casuario (kick_override), calculado al cargar el
## script con la patada del coche en marcha. De solo lectura: se lee como una constante.
static var OVERRIDES: Dictionary = _overrides_2_0()


static func _overrides_2_0() -> Dictionary:
	var out: Dictionary = _FIXED.duplicate()  # superficial: las entradas fijas siguen siendo las constantes
	var cas: Dictionary = (out["casuario"] as Dictionary).duplicate()
	var mass := casuario_mass()
	cas["mass"] = mass
	cas["strike"] = kick_override(float(mass.value))
	cas.make_read_only()
	out["casuario"] = cas
	out.make_read_only()
	return out


## La masa del casuario en la 2.0 (unidad 4i-B2, coherencia banco ↔ coche): la de la hembra del coche en marcha
## (MovingCar.BODIES, la del sexo por defecto, la más pesada; Grzimek 2003, hasta 76 kg según Latch 2007), no los 60 kg sin
## fuente de la 1.x. Así el banco y el coche ensayan el mismo animal. { value, min, max, unit, quality, source }.
static func casuario_mass() -> Dictionary:
	var sex: String = MovingCar.SEXES[0]
	var m: Dictionary = MovingCar.BODIES.casuario.mass_kg[sex]
	return {
		"value": float(m.value), "min": float(m.min), "max": float(m.max), "unit": "kg", "quality": String(m.quality),
		"source": "La %s del coche en marcha (la que sale por defecto, la más pesada): %s. La 1.x usaba 60 kg, sin fuente" % [
			String(MovingCar.SEX_NAMES.get(sex, sex)).to_lower(), String(m.source)],
	}


## El golpe de una patada de casuario de masa mass_kg en el banco: la patada del coche en marcha (MovingCar.KICK, unidad 4d;
## docs/fisica/coche-en-marcha.md §10.3). { value, min, max: { v (m/s), m (kg) }, energyJ: { value, min, max } }.
##   - v: la velocidad del salto con los pies por delante, MovingCar.kick_leap_ms() = √(4·w·f), con w, el trabajo por kilo
##     de músculo del salto máximo de la gallina de Guinea (Henry et al. 2005), y f, la masa de los músculos de cada pata
##     de un avestruz (Hutchinson et al. 2015). La misma para cualquier masa (Hill 1950).
##   - m: la masa de los músculos de la pata que patea, f·M (MovingCar.KICK.muscle_fraction): ½·m·v².
##   - Banda alta: todo el trabajo de esos músculos, w·f·M = ½·(M/2)·v²: el pie con la mitad del impulso del salto (como el
##     golpe del velocirraptor, que cae con los dos pies). La banda baja es el valor.
## En el coche en marcha (MovingCar.impact) la patada lleva el animal entero, con la masa reducida con la del coche, y la
## pata no pasa de su fuerza máxima (KICK.force_bw): casi toda esa energía vuelve a la pata. El banco no tiene ese tope, y
## aquí la masa eficaz es la de la pata (estimación).
static func kick_strike(mass_kg: float) -> Dictionary:
	var v := MovingCar.kick_leap_ms()
	var m := float(MovingCar.KICK.muscle_fraction.value) * mass_kg
	var hi := mass_kg / 2.0
	var e := 0.5 * m * (v * v)
	var e_hi := 0.5 * hi * (v * v)
	return {
		"value": { "v": v, "m": m }, "min": { "v": v, "m": m }, "max": { "v": v, "m": hi },
		"energyJ": { "value": e, "min": e, "max": e_hi },
	}


## La corrección `strike` del casuario (kick_strike con su fuente y su calidad), de solo lectura.
static func kick_override(mass_kg: float) -> Dictionary:
	var k := kick_strike(mass_kg)
	var val: Dictionary = k.value
	var hi: Dictionary = k.max
	var out := k.duplicate(true)
	out.merge({
		"quality": "estimate",
		"source": ("La velocidad de la patada del coche en marcha del programa: v, la del salto con "
			+ "los pies por delante, √(4·w·f) = %s m/s, con w = %s J por kg de músculo, el del salto máximo "
			+ "de la gallina de Guinea (%s), y f = %s %% de la masa en los músculos de cada pata, los disecados de un avestruz (%s). "
			+ "m: los músculos de la pata que patea, f × %s kg = %s kg: ½·m·v² ≈ %s J. Banda alta, todo el trabajo de esos músculos, "
			+ "w·f·M = ½·(M/2)·v² ≈ %s J (%s kg: el pie con la mitad del impulso del salto, como el golpe del velocirraptor). "
			+ "Suposición: el músculo del casuario rinde como el de esas dos aves; nadie ha medido la masa eficaz de su patada. "
			+ "La 1.x usaba 8 m/s y 5 kg (160 J, estimación sin fuente)") % [
				Js.to_fixed(float(val.v), 2), Js.js_num_str(float(MovingCar.KICK.work_j_per_kg.value)), SRC_HENRY_2005,
				Js.to_fixed(float(MovingCar.KICK.muscle_fraction.value) * 100.0, 1), SRC_HUTCHINSON_2015,
				Js.js_num_str(mass_kg), Js.to_fixed(float(val.m), 1), Js.to_fixed(float(k.energyJ.value), 0),
				Js.to_fixed(float(k.energyJ.max), 0), Js.js_num_str(float(hi.m))],
	}, true)
	for key: String in ["value", "min", "max", "energyJ"]:
		(out[key] as Dictionary).make_read_only()
	out.make_read_only()
	return out


## Agarre (N) de un accipítrido de masa m (kg) con la pendiente k, desde el gavilán de Cooper hembra. pow de V8
## (v8_math.gd): el mismo resultado, al bit, en todas las plataformas.
static func accipiter_grip(mass_kg: float, slope: float = ACCIPITER_SLOPE) -> float:
	return COOPER_GRIP_N * V8.js_pow(mass_kg / COOPER_MASS_KG, slope)


## Agarre (N) de un halcón de masa m (kg) con la pendiente k, desde el halcón peregrino hembra (o desde f_ref).
static func falcon_grip(mass_kg: float, slope: float = FALCON_SLOPE, f_ref: float = PEREGRINE_GRIP_N) -> float:
	return f_ref * V8.js_pow(mass_kg / PEREGRINE_MASS_KG, slope)


## ¿Tiene la garra (o su id) alguna corrección de la 2.0?
static func has_overrides(claw_or_id: Variant) -> bool:
	return OVERRIDES.has(_id_of(claw_or_id))


## La corrección de un campo ({ value, source, quality, min?, max? }) o null.
static func override_of(claw_or_id: Variant, key: String) -> Variant:
	var o: Variant = OVERRIDES.get(_id_of(claw_or_id))
	if o == null:
		return null
	return o.get(key)


## Valor de un campo en el modelo 2.0: el corregido si lo hay; si no, el del catálogo.
static func value(claw: Dictionary, key: String) -> Variant:
	var o: Variant = override_of(claw, key)
	return o.value if o != null else claw.get(key)


## Banda { value, min, max } de un campo numérico: la de la corrección o, sin corrección, el valor sin banda.
static func band(claw: Dictionary, key: String) -> Dictionary:
	var o: Variant = override_of(claw, key)
	var v: Variant = value(claw, key)
	if o == null:
		return { "value": v, "min": v, "max": v }
	return { "value": v, "min": o.get("min", v), "max": o.get("max", v) }


## Copia de la garra con los valores corregidos de la 2.0 (el catálogo no se toca). Idempotente: aplicarla dos veces
## da lo mismo. Añade `sources2`: { campo: { source, quality } } con la procedencia de cada campo corregido.
static func apply(claw: Dictionary) -> Dictionary:
	var out := claw.duplicate(true)
	var o: Variant = OVERRIDES.get(claw.get("id"))
	if o == null:
		return out
	var srcs: Dictionary = out.get("sources2", {}).duplicate(true)
	for key: String in o:
		var entry: Dictionary = o[key]
		var v: Variant = entry.value
		out[key] = v.duplicate(true) if v is Dictionary else v
		srcs[key] = { "source": entry.source, "quality": entry.quality }
	out["sources2"] = srcs
	return out


static func _id_of(claw_or_id: Variant) -> String:
	if claw_or_id is Dictionary:
		return String(claw_or_id.get("id", ""))
	return String(claw_or_id)
