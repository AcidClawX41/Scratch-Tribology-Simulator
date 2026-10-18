## Tribología biológica · física del laboratorio (port 1:1 de packages/core/src/physics.js, motor 1.x, «modelo v2»).
##
## El motor JavaScript es el ORÁCULO y queda congelado: este archivo tiene que dar los mismos resultados que él
## (textos, veredictos, capas y booleanos idénticos; números con error relativo ≤ 1e-9). Por eso:
##   - la mecánica de contacto, los resolvedores y el modo de abrasión salen de core/shared (contact.gd y
##     abrasion.gd), probados contra el motor 1.x: aquí no se copian sus fórmulas;
##   - cada expresión conserva el orden de operaciones del JS (en coma flotante, (a·b)·c ≠ a·(b·c));
##   - x ** 2 se escribe x·x: es lo que calcula el pow de V8 (fdlibm) con exponente 2, sin pasar por libm;
##   - Math.pow, exp, log, sin, cos y tan son los de V8 (core/shared/v8_math.gd), nunca los de la libm de cada
##     plataforma, que difieren en el último bit: así la física da lo mismo, bit a bit, en todas (lo vigila
##     tests/shared/test_v8_math.gd);
##   - los textos usan js.gd y format.gd (toFixed y String(n) de JavaScript), nunca str() ni "%.1f";
##   - `undefined` del JS es null aquí, y sus `||`, `&&` y `!!` sobre valores falsos (0, "", null, NaN) pasan
##     por truthy().
##
## Modelo (fuentes y estimaciones en docs/FISICA.md):
##   1. Punta esfero-cónica: radio R = √(área/π) y semiángulo α. El contacto crece con la carga.
##   2. Contacto elástico de Hertz: si la presión máxima no alcanza 1,6·Y el material solo rebota (φ → 0). Con
##      fricción, la cizalla adelanta la plastificación (factor de von Mises √(1+3μ²)).
##   3. Contacto plástico: la presión media REAL nunca supera la dureza del material que cede. Área que soporta la
##      carga: π·a² en punción; π·a²/2 al rayar (solo trabaja el frente).
##   4. Durezas: con r = H_punta/H_objetivo < 0,8 cede la punta (Pintaude/Richardson); por encima la punta se
##      deforma cada vez menos hasta r ≈ 2. Se modela como dureza efectiva H/η(r).
##   5. Multicapa: dureza compuesta H(h) (pintura sobre la carrocería; laca dura sobre madera blanda).
##   6. Impacto: ½·m·v² + F·h = ∫ F_resistencia dh (trabajo de penetración).
##   7. Piel: perforarla exige la fuerza medida in vivo (Davis 2004); después la punta avanza abriendo una grieta
##      con la tenacidad de corte de la piel (Pereira 1997).
##   8. Abrasión (Hokkirigawa-Kato), fricción de arado (Bowden-Tabor), Archard y adhesión JKR.
##   9. Chapa fina (coches, puerta de aluminio): se indenta hasta romperla; después el agujero se abre en pétalos
##      (Wierzbicki 1999). Vidrio de ventana: la hoja se parte al flexar (Roark; EN 572-1).
## Unidades internas: fuerza N · longitud mm · presión y dureza MPa (= N/mm²) · energía mJ (= N·mm). 1 HV = 9,807 MPa.
## Las variables llevan los símbolos del JS y de docs/FISICA.md (Neff, Htool, Ft, Dp…) para leer los dos a la par.
##
## compute() recibe { geom, base, inlay, target, force, length, type, claw, tear, method, strike, passes, wet, model }
## con las entradas de core/lab/data.gd y devuelve un diccionario con los MISMOS campos que el JS (depthUm, verdict,
## vsub, vcol, cede, layer, sev…). Uso: const Physics = preload("res://core/lab/physics.gd").
##
## Física con versión (CONTRATOS.md → «Laboratorio 2.0»): `model` es "2.0" (por defecto, la de la aplicación) o "1.x"
## (el motor 1.x al bit, el que usan los tests del oráculo). Los aguijones de insectos (catálogo de la 2.0) van a su
## propio ensayo (sting_lab.gd). Los cambios de la 2.0 van en ramas localizadas que preguntan al contexto del ensayo
## (`if c.v2:` en _skin_result y _solid_result, que reciben el ctx de compute()) o a is_v2(p), cada uno con su fuente
## en «Cambios de la 2.0» de docs/FISICA.md y su test. El camino 1.x no se toca: solo lleva los campos nuevos a null.
## Materiales y fractura (docs/fisica/pulido-materiales.md §7): la uña cede (bending.gd) y a la punta solo llega su
## carga de cesión; grietas de Hertz y astillado en los frágiles (fracture.gd); los no frágiles se clasifican con la
## huella que queda al levantar la punta (recovery.gd); la chapa se abolla (dent.gd); la ventanilla templada estalla y
## el parabrisas laminado se agrieta sin caer (glazing.gd); y el mellado de las garras frágiles, solo informativo.
## Biología (docs/fisica/pulido-biologia.md §9; unidad 4b): la piel de cinco zonas del cuerpo (zones.gd) con el hueso o la
## cavidad de debajo; al punzar, la grieta en todas las capas, el roce en los flancos y el hueso (penetration.gd); el
## ángulo de ataque, uno por ensayo (attack.gd: flexa la uña y decide el modo de abrasión); y el esmalte de la punta de
## los colmillos contra lo duro (fang_enamel.gd).
## Afilado (docs/fisica/velociraptor.md §3 y §10.2; unidad 4i): con una garra o un colmillo reforjados, p.sharpness (0-1)
## afila la punta (claw_sharpness.gd): resolve_tool cambia su área y su radio, y el resto del motor es el de siempre. El
## resultado lleva el compromiso (`sharpness`): cuánto sube la presión y cuánta carga lateral aguanta la punta afilada.
extends RefCounted

## Perfiles de dureza del objetivo (hardness_profile): homogéneo, pintura sobre carrocería y laca sobre madera.
enum { PROFILE_SOLID, PROFILE_PAINT, PROFILE_DOOR }

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Format = preload("res://core/shared/format.gd")
const Data = preload("res://core/lab/data.gd")
## Modelo 2.0: los aguijones de insectos tienen su propia física (sting.gd, docs/fisica/aguijones.md); su ensayo y su
## herramienta los arma sting_lab.gd (que a su vez usa este motor: la precarga cíclica es a propósito).
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
## Modelo 2.0 · materiales y fractura (docs/fisica/pulido-materiales.md, unidad 1f; integrados en la 4a): grietas de
## Hertz y astillado de los frágiles, uñas que se doblan o se parten, recuperación elástica, abolladura de la chapa,
## vidrios de coche (templado y laminado) y mellado de las garras frágiles (informativo).
const Fracture = preload("res://core/lab/fracture.gd")
const Bending = preload("res://core/lab/bending.gd")
const Recovery = preload("res://core/lab/recovery.gd")
const Dent = preload("res://core/lab/dent.gd")
const Glazing = preload("res://core/lab/glazing.gd")
## Modelo 2.0 · biología (docs/fisica/pulido-biologia.md, unidad 1g; integrados en la 4b): zonas del cuerpo, penetración
## profunda (grieta por capas, roce en los flancos y hueso), ángulo de ataque y esmalte de los colmillos. La precarga
## Physics ↔ Penetration (y Physics ↔ Sting, por StingLab) es cíclica a propósito.
const Zones = preload("res://core/lab/zones.gd")
const Penetration = preload("res://core/lab/penetration.gd")
const Attack = preload("res://core/lab/attack.gd")
const FangEnamel = preload("res://core/lab/fang_enamel.gd")
const Sting = preload("res://core/lab/sting.gd")
## Modelo 2.0 · afilado de las garras reforjadas (docs/fisica/velociraptor.md §3, unidad 4e; integrado en la 4i).
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")

const HV_MPA := Contact.HV_MPA
const C := Data.C
## Constantes del modelo (las mismas claves y valores que MODEL en physics.js). Las cinco primeras son las del
## contacto, compartidas con el taller (Contact.CONTACT).
const MODEL := {
	"rOff": Contact.CONTACT["rOff"],  # r por debajo del cual la punta no raya (Pintaude; Richardson)
	"rFull": Contact.CONTACT["rFull"],  # r a partir del cual la punta ya no se deforma (hipótesis del modelo)
	"tabor": Contact.CONTACT["tabor"],  # H ≈ 2,8·Y (Tabor)
	"yieldOnset": Contact.CONTACT["yieldOnset"],  # plastificación bajo una esfera cuando p0 = 1,6·Y (Johnson)
	"nu": Contact.CONTACT["nu"],  # coeficiente de Poisson común
	"skinPunctureSlope": 190.0,  # N/mm² · Davis 2004: F = 0,00019·A[µm²] − 0,66 N (piel humana in vivo)
	"skinPunctureOffset": 0.66,  # N
	"skinPunctureMin": 0.08,  # N · la menor fuerza medida por Davis 2004
	"skinPunctureToughness": 30.1,  # kJ/m² = N/mm · tenacidad de punción G_p (Davis 2004)
	# Rayado de piel (apartado 7). Tenacidades y espesores por capa: SKIN_LAYERS (data.gd).
	"skinStressMark": 1.0,  # MPa · por debajo, la punta resbala sin huella (heurística calibrada)
	"skinStressAbrade": 4.0,  # MPa · levanta la capa córnea: rasguño blanco (heurística calibrada)
	"skinStressExcoriate": 16.0,  # MPa · arranca la epidermis: excoriación (heurística calibrada)
	"skinExcoriatePasses": 5.0,  # pasadas para que una excoriación llegue a las papilas y sangre (estimación)
	"skinPapillaryUm": 300.0,  # µm · dermis papilar, la de los capilares (estimación, 0,1-0,4 mm)
	"skinHook": 0.7,  # enganche de la garra curva en la piel: ×(1 + 0,7·curvatura) (estimación)
	"wetKeratin": 0.2,  # queratina empapada: E y resistencia caen ~×0,2 (Farran 2009; Bonser en McKittrick 2012)
	"passExp": 0.4,  # pasadas: profundidad ∝ n^0,4 (heurística sublineal)
	"clawBase": 0.15,  # radio de la sección de una garra en su base ≈ 0,15 × su alcance (estimación)
	"fangBase": 0.04,  # colmillo: aguja fina, ≈ 0,04 × su alcance (estimación)
	"limbStiffness": 10.0,  # N/mm · rigidez del tejido blando de una pata o un dedo que golpea (estimación)
}
## Severidad de una herida de piel por profundidad (µm → 0-1): continua y creciente (log), con los hitos de cada
## capa (fin de la epidermis, dermis papilar, grasa, fascia, músculo).
const SKIN_SEV := [
	[0.0, 0.25], [75.0, 0.3], [75.0 + MODEL["skinPapillaryUm"], 0.45], [2200.0, 0.62], [13000.0, 0.8],
	[13300.0, 0.86], [40000.0, 0.97],
]


## Versiones del modelo físico. MODEL_V1 reproduce el motor 1.x (packages/core) al bit; MODEL_V2 es la física de la
## aplicación: la 1.x más los cambios de «Cambios de la 2.0» (docs/FISICA.md): los aguijones, los materiales y la
## biología (zonas del cuerpo, punción por capas hasta el hueso, ángulo de ataque y esmalte de los colmillos).
const MODEL_V1 := "1.x"
const MODEL_V2 := "2.0"
const MODELS := [MODEL_V1, MODEL_V2]
const MODEL_DEFAULT := MODEL_V2

## Campos del resultado que añade la 2.0 (docs/fisica/pulido-materiales.md §7.2 y pulido-biologia.md §9.3). Existen
## también en la 1.x, a null (el test de contrato; el oráculo ignora las claves a null). En la 2.0 son null cuando no se
## calculan, salvo residualDepthUm, que nunca lo es (vale depthUm cuando no hay recuperación), y attackDeg, el ángulo del
## ensayo (Physics.attack_deg), que solo es null con un aguijón (solo pica; sting_lab.gd). zone y pen, solo en la piel
## (un aguijón da la zona, pero su informe va en `sting`); tipHv, DpEff y faceDeg, solo en los sólidos (sin aguijón);
## sharpness, solo con una garra o un colmillo reforjados (sharpenable; docs/fisica/velociraptor.md §10.2), también sin
## afilar (s = 0: el compromiso de la punta natural). p0MPa, hertzRadiusUm y hertzYield (unidad 4p), el contacto elástico
## de Hertz: solo en los sólidos homogéneos, sin golpe y mientras el material no plastifica del todo (φ < 1; _hertz).
const V2_FIELDS := [
	"fracture", "nail", "recovery", "residualDepthUm", "dent", "glazing", "tipChip",
	"zone", "pen", "tipHv", "DpEff", "faceDeg", "attackDeg", "sharpness",
	"p0MPa", "hertzRadiusUm", "hertzYield",
]
## La fuente del contacto elástico (unidad 4p): las fórmulas de Hertz y los dos umbrales que ya usa el motor para φ.
const SRC_HERTZ := "Johnson KL (1985). Contact Mechanics. Cambridge University Press: contacto de una esfera, a = (3FR/4E*)^(1/3) y p0 = 3F/(2π·a²), con la presión media 2/3 del pico (cap. 4); bajo la esfera el material empieza a ceder cuando p0 = 1,6·Y y la plasticidad es completa cuando la presión media llega a la dureza (cap. 6); H ≈ 2,8·Y (Tabor D (1951). The Hardness of Metals. Clarendon Press, Oxford)"
## La recuperación se cuenta en el subtítulo a partir de un cuarto de la profundidad bajo carga. Es una elección de
## texto, no física: por debajo, la huella residual apenas se distingue de la de bajo carga.
const RECOVERY_TEXT_FRACTION := 0.25


## Versión del modelo de un ensayo: p.model o, si no la lleva, la de la aplicación. Es la comprobación central: toda
## rama nueva de la 2.0 pregunta aquí (o a ctx.v2, que sale de aquí). Un modelo desconocido es un error de programación:
## con depuración se detiene (assert) y en una exportación se usa el de la aplicación.
static func model_of(p: Dictionary) -> String:
	var m: Variant = p.get("model")
	if m == null:
		return MODEL_DEFAULT
	var s := String(m)
	if MODELS.has(s):
		return s
	push_error("Physics: modelo desconocido «%s» (los válidos son %s)" % [s, ", ".join(MODELS)])
	assert(MODELS.has(s), "Physics: modelo desconocido (ver el error de arriba)")
	return MODEL_DEFAULT


## ¿Se aplican los cambios de la 2.0 a este ensayo?
static func is_v2(p: Dictionary) -> bool:
	return model_of(p) == MODEL_V2


## Ángulo de ataque de un ensayo de la 2.0 (grados; attack.gd: el que forma el eje de la herramienta con la superficie,
## medido hacia donde avanza; en una uña, el de su placa): p.attack_deg, dentro del rango del deslizador (10-170°), o, si
## no lo trae, el de su tipo de herramienta (Attack.default_deg: 45° en las uñas, 90° en garras y colmillos). Es el único
## sitio que lo decide: el mismo ángulo flexa la uña (bending.gd) y decide el modo de abrasión (Attack.abrasion).
static func attack_deg(p: Dictionary) -> float:
	var a: Variant = p.get("attack_deg")
	return Attack.clamp_deg(float(a)) if a != null else Attack.default_deg(p.get("claw"))


## 2.0 · ¿se puede afilar la herramienta de un ensayo? Una garra o un colmillo reforjados en otro material (p.inlay no es
## «none»; docs/fisica/velociraptor.md §3: el material cambia la dureza y el módulo, y el afilado, la punta). No un aguijón
## (tiene su propia punta medida) ni una uña, y nunca en la 1.x.
static func sharpenable(p: Dictionary) -> bool:
	var claw: Variant = p.get("claw")
	var inlay: Variant = p.get("inlay")
	return is_v2(p) and Js.truthy(claw) and not Insects.is_stinger(claw) and Js.truthy(inlay) and inlay.id != "none"


## 2.0 · el afilado del ensayo, s ∈ [0, 1] (p.sharpness; ClawSharpness.radius_at: de la punta de la ficha al filo más fino
## medido, en escala logarítmica). 0 si no lo trae o si la herramienta no se puede afilar (sharpenable).
static func sharpness_of(p: Dictionary) -> float:
	var s: Variant = p.get("sharpness")
	if s == null or not sharpenable(p):
		return 0.0
	return Contact.clamp_js(float(s), 0.0, 1.0)


## 2.0 · la uña del ensayo (bending.gd) con una carga normal force_n (N): null si la herramienta es una garra, un colmillo
## o un aguijón, o si su base no tiene datos (el diamante macizo). Lo que se dobla es la placa de la base: si es de
## queratina y está mojada se ablanda (×0,2, Farran 2009), también bajo una gema, que no se ablanda (la dureza y el módulo
## del contacto siguen siendo los de la gema, tool.wet de la 1.x; unidad 4b).
static func _nail_for(p: Dictionary, tool: Dictionary, force_n: float, sliding: bool) -> Variant:
	if tool.useClaw:
		return null
	var base: Dictionary = p.base
	var plate_wet: bool = Js.truthy(p.get("wet")) and Js.truthy(base.get("keratin"))
	return Bending.evaluate(String(base.id), float(tool.reach), plate_wet, force_n, float(p.target.mu), sliding,
		attack_deg(p))


## Verdad de JavaScript (!!v), `v === true` y `${v}`: viven en core/shared/js.gd, la semántica de JS compartida.
## Se quedan estos alias porque el laboratorio y sus tests los llaman como Physics.truthy(…).
static func truthy(v: Variant) -> bool:
	return Js.truthy(v)


static func is_true(v: Variant) -> bool:
	return Js.is_true(v)


static func template_str(v: Variant) -> String:
	return Js.template_str(v)


## Número de un parámetro opcional: undefined del JS (null aquí) opera como NaN.
static func _num(v: Variant) -> float:
	return NAN if v == null else float(v)


# ── Resolución de la herramienta (uña, gema o garra) ──

## Ventaja mecánica del desgarro: la garra curva hace de gancho y palanca.
static func tear_leverage(claw: Variant) -> float:
	return 1.0 + 1.3 * claw.curve if Js.truthy(claw) else 1.0


## Profundidad relativa tras n pasadas por el mismo surco: n^0,4 (heurística sublineal).
static func pass_depth_factor(n: Variant) -> float:
	return V8.js_pow(maxf(float(n) if Js.truthy(n) else 1.0, 1.0), MODEL.passExp)


## La herramienta que calcula: material (dureza, módulo), forma (área, semiángulo, alcance), golpe y humedad.
## p.model (model_of) elige la versión de la física: en la 2.0, un aguijón no es queratina, su base es su radio real y
## fBreak es su carga de pandeo (StingLab.adjust_tool, docs/fisica/aguijones.md §7.1); una garra reforjada y afilada
## (p.sharpness > 0, sharpness_of) tiene la punta de ClawSharpness.sharpen: otra área y otro radio, con el mismo semiángulo
## (docs/fisica/velociraptor.md §10.2). Todo lo demás es igual: sin afilar, la herramienta es la de siempre, al bit.
static func resolve_tool(p: Dictionary) -> Dictionary:
	var geom: Variant = p.get("geom")
	var base: Variant = p.get("base")
	var inlay: Variant = p.get("inlay")
	var claw: Variant = p.get("claw")
	var use_claw := Js.truthy(claw)
	var has_gem: bool = Js.truthy(inlay) and inlay.id != "none"
	var fang: bool = use_claw and Js.truthy(claw.get("fang"))
	var mat: Dictionary = inlay if has_gem else (claw if use_claw else base)
	# Una garra o un colmillo «reforjados» en otro material (acero, zafiro…) conservan su forma: el material
	# cambia la dureza, no la geometría. En una uña, la piedra de la punta es la que araña.
	var shape: Dictionary = claw if use_claw else (inlay if has_gem else geom)
	var keratin: bool = not has_gem and ((not fang) if use_claw else Js.truthy(base.get("keratin")))
	var is_wet: bool = Js.truthy(p.get("wet")) and keratin
	var wet_k: float = MODEL.wetKeratin if is_wet else 1.0
	var strike: Dictionary = claw.strike if use_claw else Data.HUMAN.strike
	var sv: float = strike.v
	var tool := {
		"hv": mat.hv * wet_k, "mohs": mat.get("mohs"), "E": mat.E * wet_k,
		"area": shape.area, "alpha": shape.alpha,
		"tipRadiusUm": sqrt(shape.area / PI) * 1000.0,  # radio de la esfera de la punta (apartado 1)
		"reach": claw.reach if use_claw else geom.reach,
		"baseR": claw.reach * (MODEL.fangBase if fang else MODEL.clawBase) if use_claw else INF,  # mm (estimación)
		"fBreak": claw.get("fBreak") if use_claw and not has_gem else null,
		"strike": strike, "strikeJ": 0.5 * strike.m * (sv * sv),  # energía cinética del golpe, ½·m·v²
		"curve": claw.curve if use_claw else 0.0,
		"keratin": keratin, "wet": is_wet, "hasGem": has_gem, "fang": fang, "useClaw": use_claw,
	}
	if use_claw and Insects.is_stinger(claw) and is_v2(p):
		StingLab.adjust_tool(tool, claw, inlay)
	# 2.0 · la punta afilada de una garra reforjada: solo su área y su radio (se afila la punta, no toda la ficha)
	var s := sharpness_of(p)
	if s > 0.0:
		var sharp := ClawSharpness.sharpen({ "area": shape.area, "alpha": shape.alpha }, s)
		tool.area = sharp.area
		tool.tipRadiusUm = sharp.tipRadiusUm
	return tool


# ── Perfil de dureza del objetivo en MPa ──
# H(h, a): dureza que opone el material con la punta hundida h (mm) y un contacto de radio a (mm). Hmax(h): la
# dureza más alta atravesada hasta h. El embotamiento de la punta es irreversible, así que su eficiencia la marca
# el material más duro que ha tenido que cortar. Se guarda como datos ({ kind, Hf, Hs, t… }) y lo evalúan
# _profile_h y _profile_hmax, que hacen lo mismo que las funciones H y Hmax del JS.
static func hardness_profile(target: Dictionary) -> Dictionary:
	var L: Variant = target.get("layers")
	if not Js.truthy(L):
		var H: float = target.hv * HV_MPA
		return { "kind": PROFILE_SOLID, "Hf": H, "Hs": H, "t": 0.0, "Hsurf": H, "hvSurf": target.hv, "Esurf": target.E }
	var Hf: float = L.film.hv * HV_MPA
	var Hs: float = L.sub.hv * HV_MPA
	var t: float = L.film.t / 1000.0
	# Coche: manda la pintura hasta la carrocería; después, su material. Con acero o aluminio es un escalón HACIA
	# ARRIBA (la profundidad se queda en la chapa, nunca salta); con plástico, más blando que el barniz, hacia
	# abajo. La punta ya se ha embotado con lo más duro que haya cortado.
	# Puerta: laca dura sobre madera blanda. La laca se hunde con la madera (efecto cáscara de huevo) y su aporte
	# decae con el TAMAÑO del contacto (modelo tipo Jönsson-Hogmark). Con esta forma, H·π·a² crece siempre con a:
	# la profundidad sube de forma continua al romper la laca.
	var kind := PROFILE_PAINT if L.kind == "paint-on-body" else PROFILE_DOOR
	return {
		"kind": kind, "Hf": Hf, "Hs": Hs, "t": t, "Hsurf": Hf, "hvSurf": L.film.hv, "Esurf": L.film.E,
		"film": L.film, "sub": L.sub,
	}


## H(h, a) del perfil.
static func _profile_h(prof: Dictionary, h: float, a: float) -> float:
	match int(prof.kind):
		PROFILE_PAINT:
			return prof.Hf if h <= prof.t else prof.Hs
		PROFILE_DOOR:
			return prof.Hs + (prof.Hf - prof.Hs) * V8.js_exp(-a / prof.t)
	return prof.Hf


## Hmax(h) del perfil.
static func _profile_hmax(prof: Dictionary, h: float) -> float:
	if int(prof.kind) == PROFILE_PAINT:
		return prof.Hf if h <= prof.t else maxf(prof.Hf, prof.Hs)
	return prof.Hf


# ── Resistencia a la penetración F_res(h) (N) ──
## enamel_tool (2.0): un colmillo natural (FangEnamel.applies), cuya punta es de esmalte: su dureza depende del contacto
## (fang_enamel.gd). Sin él, la resistencia de la 1.x con la dureza constante Htool.
static func _make_resistance(
	tip: Dictionary, prof: Dictionary, Htool: float, load_share: float, m: float, enamel_tool: Variant = null
) -> Callable:
	if enamel_tool != null:
		return _make_enamel_resistance(tip, prof, enamel_tool, load_share, m)
	return func(h: float) -> float:
		var a := Contact.contact_radius(tip, h / m)
		if a <= 0.0:
			return 0.0
		var eta := Contact.hardness_efficiency(Htool / _profile_hmax(prof, h))
		return (_profile_h(prof, h, a) / eta) * load_share * PI * a * a if eta > 0.0 else INF


## 2.0 · la resistencia con la punta de esmalte de un colmillo (docs/fisica/pulido-biologia.md §6 y §9.2): la de la 1.x
## con la eficiencia de la punta en cada contacto, η(a) = FangEnamel.efficiency(tool, a, Hmax(h)). Sigue creciendo con la
## profundidad y se hace infinita cuando el contacto sale del esmalte (r < 0,8): la punta se queda donde el esmalte puede.
static func _make_enamel_resistance(tip: Dictionary, prof: Dictionary, tool: Dictionary, load_share: float, m: float) -> Callable:
	return func(h: float) -> float:
		var a := Contact.contact_radius(tip, h / m)
		if a <= 0.0:
			return 0.0
		var eta := FangEnamel.efficiency(tool, a, _profile_hmax(prof, h))
		return (_profile_h(prof, h, a) / eta) * load_share * PI * a * a if eta > 0.0 else INF


# ── Chapa fina: perforación en pétalos (Wierzbicki 1999) ──
# Hasta que la punta sale por detrás, la chapa se indenta como un sólido (dureza). Una vez rota deja de oponerse
# como un bloque: el agujero se abre en pétalos que se doblan y se rasgan. Energía para abrir un agujero de radio l
# en una chapa de espesor t, con fractura dúctil (δt/t = 1), ecuación 57:
#   E(l) = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4]      (mJ, con σ0 en MPa y longitudes en mm)
# La fuerza es su derivada respecto a la profundidad de la punta: el agujero tiene el radio de la herramienta a esa
# profundidad. Una punta afilada (tan α pequeña) se cuela; una ancha cuesta mucho más.

## Energía (mJ) para abrir en pétalos un agujero de radio l (mm) en una chapa de espesor t (mm).
static func petal_energy(l: float, t: float, sigma0: float) -> float:
	return sigma0 * t * t * l * (1.23 + 8.9 * V8.js_pow(l / t, 0.4)) if l > 0.0 else 0.0


## Chapa perforable del material: tramo de profundidades que ocupa (mm), espesor y σ0. null si no tiene.
static func sheet_of(target: Dictionary) -> Variant:
	if Js.truthy(target.get("body")):
		return {
			"from": target.layers.film.t / 1000.0, "to": target.thickness, "t": target.body.t / 1000.0,
			"sigma0": target.body.sigma0,
		}
	if Js.truthy(target.get("sigma0")) and Js.truthy(target.get("thickness")):
		return { "from": 0.0, "to": target.thickness, "t": target.thickness, "sigma0": target.sigma0 }
	return null


static func _make_sheet_resistance(
	tip: Dictionary, prof: Dictionary, Htool: float, load_share: float, m: float, sheet: Dictionary,
	enamel_tool: Variant = null
) -> Callable:
	var solid := _make_resistance(tip, prof, Htool, load_share, m, enamel_tool)
	var st: float = sheet.t
	var sigma0: float = sheet.sigma0
	var to: float = sheet.to
	var E := func(h: float) -> float: return petal_energy(Contact.hole_radius(tip, maxf(h, 0.0) / m), st, sigma0)
	var d := 1e-4
	return func(h: float) -> float:
		return solid.call(h) if h <= to else (load_share * (E.call(h + d) - E.call(h - d))) / (2.0 * d)


# ── Hoja de vidrio que se parte al flexar ──
# Placa circular apoyada de radio a con la carga en el centro (Roark): en la cara de atrás
#   σ = 3F/(2π·t²)·[(1+ν)·ln(a/r0') + 1],  con r0' = √(1,6·r0² + t²) − 0,675·t si r0 < 0,5·t (Westergaard).
# Se parte cuando σ llega a la resistencia a flexión fg,k (EN 572-1). Rigidez de la placa en el centro:
# k = 4π·E·t³ / (3·a²·(3+ν)·(1−ν)); en un golpe, _solid_result compara con F la fuerza de pico (la hoja y la pata en
# serie). U = F²/2k es la energía que la hoja almacena al partirse (la que se queda el vidrio). No hace falta
# dureza: un puño también rompe una ventana.

## { F (N), k (N/mm), U (mJ) } de la hoja pane con módulo Egpa (GPa) y la carga repartida en un radio r0 (mm).
static func pane_break(pane: Dictionary, Egpa: float, r0: float = 0.0) -> Dictionary:
	var t: float = pane.t
	var a: float = pane.a
	var fgk: float = pane.fgk
	var nu: float = pane.nu
	var r0e := sqrt(1.6 * r0 * r0 + t * t) - 0.675 * t if r0 < 0.5 * t else r0
	var F := (fgk * 2.0 * PI * t * t) / (3.0 * ((1.0 + nu) * V8.js_log(a / r0e) + 1.0))
	var k := (4.0 * PI * Egpa * 1000.0 * V8.js_pow(t, 3.0)) / (3.0 * a * a * (3.0 + nu) * (1.0 - nu))
	return { "F": F, "k": k, "U": (F * F) / (2.0 * k) }


## Severidad 0-1 con escala logarítmica (monótona, sin escalones): 0,3 µm → ~0, full_um → 1.
static func _sev_log(um: float, full_um: float) -> float:
	return Contact.clamp_js(Js.log1p(um / 0.3) / Js.log1p(full_um / 0.3), 0.0, 1.0)


# ════════ COMPUTE ════════

## Un ensayo: la herramienta contra el material, rayando o punzando (con o sin golpe), con la física de p.model.
static func compute(p: Dictionary) -> Dictionary:
	var model := model_of(p)
	# 2.0: un aguijón de insecto pica con su propia física (sting.gd) y el motor de siempre en los sólidos
	if model == MODEL_V2 and Insects.is_stinger(p.get("claw")):
		return StingLab.compute(p)
	var target: Dictionary = p.target
	var claw: Variant = p.get("claw")
	var tool := resolve_tool(p)
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	var use_claw: bool = tool.useClaw
	var puncture: bool = p.get("method") == "puncion"
	var strike := Js.truthy(p.get("strike"))
	var tearing := Js.truthy(p.get("tear")) and use_claw and not puncture  # desgarro/palanca: solo garras
	var lever := tear_leverage(claw) if tearing else 1.0  # gancho curvo → ventaja mecánica
	var mu: float = target.mu
	var f_mu := sqrt(1.0 + 3.0 * mu * mu)  # von Mises con cizalla de Coulomb
	var Fadh: float = 1.5 * PI * tip.R * 1e-3 * target.W  # N (JKR, Van der Waals)
	var force: float = p.force
	# 2.0 · la uña cede (bending.gd; docs/fisica/pulido-materiales.md §7.1): si la placa no aguanta la carga pedida, a la
	# punta solo llega la de cesión y el ensayo se hace con ella. En un golpe lo decide la resistencia del camino, como la
	# rotura del colmillo (_solid_result y _skin_result).
	var nail: Variant = null
	if model == MODEL_V2:
		nail = _nail_for(p, tool, force, not puncture)
		if nail != null and nail.broken and not (puncture and strike):
			force = nail.breakN
	var Neff := force + Fadh
	var Htool: float = tool.hv * HV_MPA
	var p_nominal: float = Neff / tool.area  # MPa: lo que la punta «pide»
	var sv: float = tool.strike.v
	var energy_j: float = 0.5 * tool.strike.m * (sv * sv) if puncture and strike else 0.0
	var pass_n := maxf(float(p.passes) if Js.truthy(p.get("passes")) else 1.0, 1.0)
	var common := {
		"hasGem": tool.hasGem, "area": tool.area, "hvTool": tool.hv, "mohsTool": tool.mohs, "mu": mu,
		"Fadh_mN": Fadh * 1000.0, "pNominal": p_nominal, "claw": use_claw, "wet": tool.wet, "reachMm": tool.reach,
		"tipRadiusUm": tip.R * 1000.0, "alphaDeg": tool.alpha, "skin": Js.truthy(target.get("skin")),
		"paint": Js.truthy(target.get("paint")), "woodDoor": Js.truthy(target.get("woodDoor")), "tName": target.name,
	}
	# El contexto viaja a _skin_result y _solid_result; `model` y `v2` deciden las ramas de la 2.0 (`if c.v2:`). Los
	# datos de los materiales de la 2.0: los parámetros (p), la uña (nail) y la adhesión (Fadh, que no pasa por la uña).
	# Los de la biología: la zona del cuerpo (zones.gd; una desconocida o ninguna, el brazo de la 1.x).
	var ctx := {
		"tool": tool, "tip": tip, "target": target, "force": force, "Neff": Neff, "pNominal": p_nominal,
		"Htool": Htool, "puncture": puncture, "strike": strike, "energyJ": energy_j, "type": p.get("type"),
		"fMu": f_mu, "lever": lever, "length": _num(p.get("length")), "passN": pass_n, "tearing": tearing,
		"common": common, "model": model, "v2": model == MODEL_V2, "p": p, "nail": nail, "Fadh": Fadh,
		"zone": Zones.resolve(p.get("zone")).id,
	}
	var r: Dictionary = _skin_result(ctx) if Js.truthy(target.get("skin")) else _solid_result(ctx)
	if model != MODEL_V2:
		# los campos de la 2.0 existen también en la 1.x, a null (el oráculo ignora las claves a null)
		for k: String in V2_FIELDS:
			r[k] = null
	return r


# ════════ PIEL (multicapa) ════════
# Capa córnea, epidermis, dermis, grasa, fascia y músculo (SKIN_LAYERS). Tres mecanismos:
#   1. Romper la superficie: fuerza de punción medida in vivo (Davis 2004), lineal con el área de la punta. Al
#      arrastrar ayudan la cizalla y la piel tensa por delante: F_ef = N·√(1+3μ²)·enganche·palanca.
#   2. Entrar de frente ya rota: la punta acuña una grieta plana (Shergold & Fleck 2005) → F = 2·jC·a(h), con la
#      tenacidad al corte de la capa en la que está. Tras la dermis la resistencia CAE (Knight 1975).
#   3. Arrastrar ya rota: la garra rasga un corte de profundidad h. Energía por unidad de longitud:
#      F_t = ∫₀ʰ jT dz (tenacidad al desgarro, Comley & Fleck 2010). Sin romper, solo hay abrasión de la capa
#      córnea o de la epidermis (umbrales de esfuerzo calibrados).

## Capa de piel alcanzada a una profundidad (µm): tocar el fondo de una capa no es entrar en la siguiente.
static func skin_layer_at(um: float, stack: Array = Data.SKIN_LAYERS) -> Dictionary:
	for l: Dictionary in stack:
		if um <= l.to:
			return l
	return stack[-1]


## Fuerza de punción de la piel (N) para una punta de área A (mm²), Davis 2004.
static func skin_puncture_force(area_mm2: float) -> float:
	return maxf(MODEL.skinPunctureMin, MODEL.skinPunctureSlope * area_mm2 - MODEL.skinPunctureOffset)


## Profundidad (mm) del corte que abre una fuerza de desgarro Ft (N): inversa de ∫₀ʰ jT dz. La última capa no acaba.
static func skin_tear_depth(Ft: float, stack: Array = Data.SKIN_LAYERS) -> float:
	var w := 0.0
	for i in stack.size():
		var l: Dictionary = stack[i]
		var jT: float = l.jT
		var a: float = l.from / 1000.0
		var b: float = INF if i == stack.size() - 1 else l.to / 1000.0
		if w + jT * (b - a) >= Ft:
			return a + (Ft - w) / jT
		w += jT * (b - a)
	return INF


## Severidad por profundidad (µm): interpolación logarítmica entre los hitos de SKIN_SEV.
static func _skin_severity(um: float) -> float:
	if um <= 0.0:
		return 0.0
	for i in range(1, SKIN_SEV.size()):
		var u0: float = SKIN_SEV[i - 1][0]
		var s0: float = SKIN_SEV[i - 1][1]
		var u1: float = SKIN_SEV[i][0]
		var s1: float = SKIN_SEV[i][1]
		if um <= u1:
			return s0 + ((s1 - s0) * (V8.js_log(1.0 + um) - V8.js_log(1.0 + u0))) / (V8.js_log(1.0 + u1) - V8.js_log(1.0 + u0))
	return SKIN_SEV[-1][1]


## Dónde queda la punta, en palabras (para el veredicto). epi_um: el fin de la epidermis (75 µm en el brazo de la 1.x; en
## la 2.0, el de la zona): la dermis papilar son los 300 µm de debajo. layer_id: el de la capa, si ya se sabe (en la 2.0,
## también «hueso», «medula» y «cavidad», que no están en las pilas de partes blandas).
static func _skin_where(um: float, stack: Array, epi_um: float = 75.0, layer_id: Variant = null) -> Variant:
	var id: Variant = layer_id if layer_id != null else skin_layer_at(um, stack).id
	return {
		"cornea": "en la capa córnea", "epidermis": "en la epidermis (sin vasos)",
		"dermis": "en la dermis papilar (capilares)" if um <= epi_um + MODEL.skinPapillaryUm else "en la dermis reticular",
		"grasa": "en la grasa (subcutáneo)", "fascia": "en la fascia profunda", "musculo": "en el músculo (intramuscular)",
		"hueso": "clavada en el hueso", "medula": "en la médula del hueso", "cavidad": "en la cavidad abdominal (herida penetrante)",
	}.get(id)


## Primera capa con ese id o, si no hay, la primera de la pila (stack.find(…) || stack[0]).
static func _layer_or_first(stack: Array, id: String) -> Dictionary:
	for l: Dictionary in stack:
		if l.id == id:
			return l
	return stack[0]


## Copia de base con las claves de over encima: el { ...base, ...over } de JavaScript.
static func _spread(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(over, true)
	return out


## c: el contexto de compute(). Los cambios de la 2.0 en la piel van en ramas `if c.v2:`: la zona del cuerpo (sus capas y
## el hueso o la cavidad de debajo, zones.gd), la punción con la grieta en todas las capas, el roce en los flancos y el
## hueso (penetration.gd), el corte hasta el hueso, la uña que cede (también en un golpe) y los campos de la 2.0
## (_skin_v2). En el brazo y sin hueso a la vista, la 2.0 da lo de la 1.x salvo al punzar hondo (el roce y la grieta de
## las capas de arriba frenan la punta).
static func _skin_result(c: Dictionary) -> Dictionary:
	var tool: Dictionary = c.tool
	var tip: Dictionary = c.tip
	var target: Dictionary = c.target
	var force: float = c.force
	var Neff: float = c.Neff
	var strike: bool = c.strike
	var passN: float = c.passN
	var tearing: bool = c.tearing
	var common: Dictionary = c.common
	var nail: Variant = c.get("nail")  # 2.0: la uña (bending.gd) o null
	var v2: bool = c.v2
	# 2.0: las capas de la zona del cuerpo (en el brazo, las de la 1.x; el músculo acaba en el húmero)
	var stack: Array
	if v2:
		stack = Zones.stack(c.zone)
	else:
		stack = target.tissue if Js.truthy(target.get("tissue")) else Data.SKIN_LAYERS
	var breaks: Array = []
	for i in range(1, stack.size()):
		breaks.append(stack[i].from / 1000.0)
	var epi: float = _layer_or_first(stack, "epidermis").to
	var pressure := minf(c.pNominal, c.Htool)  # la piel nunca aplasta la punta
	var Hsoft := 15.0  # referencia de desgaste (u.a.)
	# 2.0: la ley de perforación de la unidad 1a (Sting.puncture_force); con uñas, garras y colmillos es la de la 1.x
	var f_puncture := Sting.puncture_force(tool.area, stack) if v2 else skin_puncture_force(tool.area)
	var reach_um: float = tool.reach * 1000.0
	var width_at := func(um: float) -> float: return 2.0 * Contact.contact_radius(tip, um / 1000.0) * 1000.0
	var skin_common := _spread(common, {
		"ratio": null, "chi": null, "Ffric": target.mu * Neff, "toolWorn": false, "contactAreaMm2": tool.area,
		"phi": 1.0, "eta": 1.0, "fPuncture": f_puncture, "energyJ": c.energyJ, "through": false, "shattered": false,
		"paneN": null, "peakN": null, "workJ": null,
	})

	if c.puncture:
		var e_rupture: float = MODEL.skinPunctureToughness * tool.area  # mJ: G_p·A
		var Emj: float = c.energyJ * 1000.0
		var pierces := Neff >= f_puncture or (strike and Emj >= e_rupture)
		var depth_um: float
		var pen: Variant = null
		if v2:
			# 2.0 · la grieta en todas las capas, el roce en los flancos y el hueso; con una uña que golpea, su cesión
			var pz := _skin_puncture_v2(c, nail, pierces, f_puncture)
			pen = pz.pen
			nail = pz.nail
			pierces = pen.pierces
			depth_um = pen.depthUm
		else:
			var res := func(h: float) -> float:
				return 2.0 * skin_layer_at(h * 1000.0, stack).jC * Contact.contact_radius(tip, h)
			var h_mm := 0.0
			if pierces:
				h_mm = Contact.solve_energy(Emj, Neff, res) if strike else Contact.solve_layered(Neff, res, breaks)
			depth_um = minf(h_mm * 1000.0, reach_um)
		var inject: bool = tool.fang
		var out: Dictionary
		if v2:
			out = _skin_puncture_verdict(c, pen, stack, epi, f_puncture)
		else:
			var where: Variant = _skin_where(depth_um, stack)
			var mm := Js.to_fixed(depth_um / 1000.0, 1)
			if not pierces:
				out = {
					"verdict": "NO PERFORA", "vcol": C.mint, "cede": "nada", "scratched": false,
					"vsub": "hunde la piel pero no la rompe (necesita ~%s N)" % Js.to_fixed(f_puncture, 1),
				}
			elif inject:
				out = {
					"verdict": "PUNCIÓN · INYECTA", "vcol": C.coral, "cede": "la piel (2 punciones)", "scratched": true,
					"vsub": "perfora y deja el veneno a ~%s mm, %s" % [mm, where],
				}
			else:
				out = {
					"verdict": "PUNCIÓN PROFUNDA" if depth_um > 2200.0 else "PUNCIÓN", "vcol": C.coral,
					"vsub": "perfora ~%s mm: la punta queda %s" % [mm, where],
					"cede": "la piel entera" if depth_um > 2200.0 else "la piel (perforada)", "scratched": true,
				}
		var sev: float
		var layer: Variant
		var bleeds: bool
		var full: bool
		if v2:
			sev = maxf(0.3, Zones.severity(c.zone, depth_um)) if pierces else 0.08
			layer = pen.layer
			bleeds = pen.bleeds
			full = pen.fullReach
		else:
			sev = maxf(0.3, _skin_severity(depth_um)) if pierces else 0.08
			layer = skin_layer_at(depth_um, stack).name if pierces else null
			bleeds = pierces and depth_um > epi
			full = depth_um >= reach_um - 1e-6
		var r := _spread(skin_common, out)
		r.merge({
			"pressure": pressure, "stress": pressure, "sev": sev,
			"wearIdx": Js.js_round((400.0 * force * (2.0 if strike else 1.0)) / Hsoft),
			"depthUm": depth_um, "layer": layer, "bleeds": bleeds,
			"tearing": false, "puncture": true, "inject": inject, "pierces": pierces,
			"fullReach": full, "grooveWidthUm": width_at.call(depth_um) if pierces else 0.0,
		}, true)
		if v2:
			# 2.0: el trabajo de la punción y si el colmillo se rompe contra el hueso (la 1.x no los daba en la piel; §9.3)
			r.merge({ "workJ": pen.workJ, "toolBroken": pen.toolBroken }, true)
			_skin_v2(c, r, nail, pen)
		return r

	# Rayado. La dureza de la herramienta no interviene: cualquier punta es ≫ más dura que la piel.
	var k: float = c.type.k
	var f_mu: float = c.fMu
	var lever: float = c.lever
	var hook: float = 1.0 + MODEL.skinHook * tool.curve if common.claw else 1.0
	var stress := pressure * k * f_mu * hook * lever  # esfuerzo en la superficie (MPa)
	var ruptures := Neff * f_mu * hook * lever >= f_puncture
	var pass_f := pass_depth_factor(passN)
	# Fuerza que abre el corte: arrastrando, la fricción; desgarrando, el tirón entero de la garra enganchada. (La
	# adhesión de Van der Waals, de milinewtons, no tira de la garra hacia delante: se usa la fuerza aplicada.)
	var mu: float = target.mu
	var Ft := (force * lever if tearing else mu * force * hook) * k * pass_f
	var abr_um: float = 0.0
	var cut_um: float
	var depth_um: float
	var excoriate_bleeds: bool
	var pen: Variant = null
	if v2:
		# 2.0 · la abrasión con las profundidades de la zona y el corte en sus capas, hasta el hueso (penetration.gd)
		pen = Penetration.skin_report({
			"tool": tool, "tip": tip, "zone": c.zone, "puncture": false, "passes": passN, "stress": stress,
			"tearForce": Ft, "ruptures": ruptures,
		})
		abr_um = pen.abrasionUm
		cut_um = pen.cutUm
		depth_um = pen.depthUm
		excoriate_bleeds = pen.excoriationBleeds
	else:
		if stress >= MODEL.skinStressExcoriate:
			abr_um = epi
		elif stress >= MODEL.skinStressAbrade:
			abr_um = stack[0].to
		cut_um = minf(skin_tear_depth(Ft, stack) * 1000.0, reach_um) if ruptures else 0.0
		depth_um = maxf(abr_um, cut_um)
		excoriate_bleeds = not ruptures and abr_um == epi and passN >= MODEL.skinExcoriatePasses
	var where: Variant = _skin_where(depth_um, stack, epi)
	var mm := (Js.to_fixed(depth_um / 1000.0, 1) + " mm") if depth_um >= 1000.0 else (Js.to_fixed(depth_um, 0) + " µm")
	var reached := skin_layer_at(depth_um, stack)
	var out: Dictionary
	if depth_um <= 0.0:
		if stress < MODEL.skinStressMark:
			out = {
				"scratched": false, "sev": 0.0, "verdict": "SIN MARCA", "vcol": C.mint,
				"vsub": "la punta resbala, sin huella", "cede": "nada",
			}
		else:
			out = {
				"scratched": "faint", "sev": 0.1, "verdict": "MARCA ROJA", "vcol": C.gold,
				"vsub": "esfuerzo bajo: enrojece y se va sola; no rompe", "cede": "piel (reversible)",
			}
	elif not ruptures:
		if excoriate_bleeds:
			out = {
				"scratched": true, "sev": 0.35, "verdict": "RASGUÑOS QUE SANGRAN", "vcol": C.coral, "cede": "la epidermis",
				"vsub": "%s pasadas excorian la epidermis hasta las papilas de la dermis: puntitos de sangre" % Js.js_num_str(passN),
			}
		elif v2 and pen.excoriation:
			out = _skin_excoriation(c, abr_um, epi, stack)
		elif not v2 and abr_um == epi:
			out = {
				"scratched": "faint", "sev": 0.22, "verdict": "RASGUÑOS", "vcol": C.gold, "cede": "la epidermis",
				"vsub": "arranca la epidermis (~75 µm): escuece, pero no sangra (la epidermis no tiene vasos)",
			}
		else:
			out = {
				"scratched": "faint", "sev": 0.15, "verdict": "RASGUÑO BLANCO", "vcol": C.gold, "cede": "la capa córnea",
				"vsub": ("solo levanta la capa córnea (~%s µm): raya blanca, sin herida" % Js.to_fixed(abr_um, 0)) if v2
					else "solo levanta la capa córnea (~18 µm): raya blanca, sin herida",
			}
	elif v2:
		out = _skin_cut_wound(c, pen, reached.id, depth_um, epi, mm, tearing, stack)
	else:
		out = _skin_wound(reached.id, depth_um, epi, mm, tearing, _skin_severity(depth_um))
	var r := _spread(skin_common, out)
	r.merge({
		"pressure": pressure, "stress": stress, "muAdh": mu, "muPlough": 0.0, "muEff": mu,
		"absMode": null, "Dp": 0.0, "fab": 1.0, "wearIdx": Js.js_round((1500.0 * force * c.length * passN) / Hsoft),
		"depthUm": depth_um, "layer": reached.name if depth_um > 0.0 else null, "where": where,
		"bleeds": depth_um > epi or excoriate_bleeds, "ruptures": ruptures, "tearForce": Ft, "tearing": tearing,
		"puncture": false, "grooveWidthUm": width_at.call(depth_um) if depth_um > 0.0 else 0.0,
		"fullReach": pen.fullReach if v2 else (cut_um > 0.0 and cut_um >= reach_um - 1e-6),
	}, true)
	if v2:
		_skin_v2(c, r, nail, pen)
	return r


## Herida que abre una punta que ha roto la piel al rayar: veredicto según la capa alcanzada (id), la profundidad
## (µm, y ya escrita en mm), el fin de la epidermis (epi, µm), si la garra engancha y rasga (desgarro) y la severidad de
## esa profundidad (base_sev: _skin_severity en la 1.x; Zones.severity de la zona en la 2.0).
static func _skin_wound(id: String, depth_um: float, epi: float, mm: String, tearing: bool, base_sev: float) -> Dictionary:
	var papillary := depth_um <= epi + MODEL.skinPapillaryUm
	var name: Variant
	if tearing:
		name = {
			"cornea": "DESGARRO SUPERFICIAL", "epidermis": "DESGARRO SUPERFICIAL",
			"dermis": "DESGARRO" if papillary else "DESGARRO PROFUNDO", "grasa": "DESGARRO ABIERTO",
			"fascia": "DESGARRO MUSCULAR", "musculo": "DESGARRO MUSCULAR",
		}.get(id)
	else:
		name = {
			"cornea": "ARAÑAZO SUPERFICIAL", "epidermis": "ARAÑAZO SUPERFICIAL",
			"dermis": "ARAÑAZO QUE SANGRA" if papillary else "ARAÑAZO PROFUNDO", "grasa": "LACERACIÓN",
			"fascia": "LACERACIÓN PROFUNDA", "musculo": "LACERACIÓN PROFUNDA",
		}.get(id)
	var sub: Variant = {
		"cornea": "rompe la superficie sin llegar a la dermis: no sangra",
		"epidermis": "rompe la epidermis sin llegar a la dermis: no sangra",
		"dermis": ("abre la dermis papilar (~%s): sangra" % mm) if papillary
			else ("llega a la dermis reticular (~%s): sangra y puede dejar cicatriz" % mm),
		"grasa": "atraviesa la piel (~%s): asoma la grasa" % mm, "fascia": "corta hasta la fascia profunda (~%s)" % mm,
		"musculo": "llega al músculo (~%s)" % mm,
	}.get(id)
	var cede := "la epidermis"
	if id == "dermis":
		cede = "la dermis"
	elif id == "grasa":
		cede = "piel y grasa"
	elif id == "fascia" or id == "musculo":
		cede = "piel, grasa y músculo"
	return {
		"scratched": true, "sev": minf(1.0, base_sev + (0.03 if tearing else 0.0)), "verdict": name,
		"vcol": C.gold if id == "cornea" or id == "epidermis" else C.coral,
		"vsub": ("la garra engancha y rasga: %s" % sub) if tearing else sub, "cede": cede,
	}


# ════════ BIOLOGÍA DE LA 2.0: ZONAS, HUESO Y PUNCIÓN PROFUNDA ════════
# docs/fisica/pulido-biologia.md §9 (unidad 1g, integrada en la 4b). Los números de los textos, con Js y Format.

## «de la zona» en los subtítulos (el callo de la palma…).
const ZONE_OF := {
	"brazo": "del brazo", "palma": "de la palma", "dorsomano": "del dorso de la mano", "cara": "del pómulo",
	"abdomen": "del abdomen",
}
## Por debajo de esto (µm) la punta no marca el hueso: el residuo de la bisección contra una pared no es una huella (el
## mismo umbral que «roza sin marcar» en los sólidos).
const BONE_MARK_UM := 0.05


## El nombre del hueso de una zona para los textos, sin artículo: «húmero», «primer metacarpiano», «hueso cigomático»
## (todos masculinos: «al húmero», «del húmero», «con el húmero»).
static func _bone_name(bone: Dictionary) -> String:
	return String(bone.name).to_lower()


## 2.0 · la punción de la piel por zonas (Penetration.skin_report): { pen, nail }. Con una uña que golpea y que
## perforaría (would_pierce: la ley de siempre), su carga de cesión (bending.gd, más la adhesión, que no pasa por la uña) es
## el tope de la punta: si no llega a la fuerza que rompe la piel, se dobla antes y no perfora (se evalúa con esa fuerza);
## si el camino le pide más, la punta se queda donde la resistencia llega a ella (la receta de la rotura del colmillo) y se
## evalúa con lo que el camino le pide (docs/fisica/pulido-materiales.md §7.11, con la resistencia de penetration.gd).
static func _skin_puncture_v2(c: Dictionary, nail: Variant, would_pierce: bool, f_puncture: float) -> Dictionary:
	var fadh: float = c.Fadh
	var q := {
		"tool": c.tool, "tip": c.tip, "zone": c.zone, "puncture": true, "strike": c.strike, "Neff": c.Neff,
		"energyJ": c.energyJ,
	}
	var hit: bool = nail != null and c.strike and would_pierce
	if hit:
		q["yieldN"] = float(nail.breakN) + fadh
	var pen := Penetration.skin_report(q)
	if hit:
		if not pen.pierces:
			nail = _nail_for(c.p, c.tool, f_puncture - fadh, false)
		else:
			var demand: Variant = pen.demandN
			nail = _nail_for(c.p, c.tool, maxf(float(demand) - fadh, 0.0) if demand != null else float(nail.breakN), false)
	return { "pen": pen, "nail": nail }


## 2.0 · veredicto de una punción de la piel por zonas (docs/fisica/pulido-biologia.md §9.5), por prioridad: el colmillo
## que se rompe; el hueso (lo atraviesa, lo marca o topa con él); la herida penetrante del abdomen; y, si no, los de la
## 1.x con el sitio de la zona. La uña que cede (prioridad 1 de los materiales) la aplica después _skin_v2.
static func _skin_puncture_verdict(c: Dictionary, pen: Dictionary, stack: Array, epi: float, f_puncture: float) -> Dictionary:
	var tool: Dictionary = c.tool
	var inject: bool = tool.fang
	if not pen.pierces:
		return {
			"verdict": "NO PERFORA", "vcol": C.mint, "cede": "nada", "scratched": false,
			"vsub": "hunde la piel pero no la rompe (necesita ~%s N)" % Js.to_fixed(f_puncture, 1),
		}
	var depth_um: float = pen.depthUm
	var mm := Js.to_fixed(depth_um / 1000.0, 1)
	var bone: Variant = Zones.bone(c.zone)
	var at_bone := Js.to_fixed(float(bone.fromUm) / 1000.0, 1) if bone != null else ""
	if pen.toolBroken:
		var who := "el colmillo" if tool.fang else "la punta"
		var head: String
		if pen.boneHit and bone != null:
			head = "llega al %s a ~%s mm y %s cede a ~%s N" % [_bone_name(bone), at_bone, who, Js.template_str(tool.get("fBreak"))]
		else:
			head = "%s cede a ~%s N tras entrar ~%s mm" % [who, Js.template_str(tool.get("fBreak")), mm]
		return {
			"verdict": "SE ROMPE EL COLMILLO" if tool.fang else "SE ROMPE LA PUNTA", "vcol": C.coral, "cede": who,
			"scratched": true, "vsub": head + (": el veneno se queda a ~%s mm" % mm if inject else ""),
		}
	if pen.boneHit and bone != null:
		var noun := _bone_name(bone)
		if pen.bonePierced:
			return {
				"verdict": "ATRAVIESA EL HUESO", "vcol": C.coral, "cede": "la piel entera y la cortical del hueso", "scratched": true,
				"vsub": "atraviesa los %s mm de cortical del %s y acaba en la médula (~%s mm)%s" % [
					Js.js_num_str(float(bone.corticalUm) / 1000.0), noun, mm, "; el veneno queda en la médula" if inject else ""],
			}
		if float(pen.boneIndentUm) >= BONE_MARK_UM:
			return {
				"verdict": "SE CLAVA EN EL HUESO", "vcol": C.coral, "cede": "la piel entera y la superficie del hueso", "scratched": true,
				"vsub": "entra ~%s en el %s, a ~%s mm de la superficie%s" % [Format.fmt_depth(float(pen.boneIndentUm)), noun, at_bone,
					"; deja el veneno junto al hueso" if inject else ""],
			}
		return {
			"verdict": "PUNCIÓN HASTA EL HUESO", "vcol": C.coral, "cede": "la piel entera (el hueso aguanta)", "scratched": true,
			"vsub": "la punta topa con el %s a ~%s mm y no lo marca%s" % [noun, at_bone, "; deja el veneno junto al hueso" if inject else ""],
		}
	if pen.layerId == "cavidad":
		var wall := Js.to_fixed(float(_layer_or_first(stack, "cavidad").from) / 1000.0, 1)
		return {
			"verdict": "HERIDA PENETRANTE", "vcol": C.coral, "cede": "la pared del abdomen", "scratched": true,
			"vsub": "pasa la pared del abdomen (~%s mm) y llega a ~%s mm, dentro de la cavidad%s" % [wall, mm,
				"; deja el veneno dentro" if inject else ""],
		}
	var where: Variant = _skin_where(depth_um, stack, epi)
	if inject:
		return {
			"verdict": "PUNCIÓN · INYECTA", "vcol": C.coral, "cede": "la piel (2 punciones)", "scratched": true,
			"vsub": "perfora y deja el veneno a ~%s mm, %s" % [mm, where],
		}
	var deep: bool = depth_um > float(_layer_or_first(stack, "dermis").to)  # en el brazo, 2200 µm: la de la 1.x
	return {
		"verdict": "PUNCIÓN PROFUNDA" if deep else "PUNCIÓN", "vcol": C.coral,
		"vsub": "perfora ~%s mm: la punta queda %s" % [mm, where],
		"cede": "la piel entera" if deep else "la piel (perforada)", "scratched": true,
	}


## 2.0 · la excoriación sin romper la piel (Zones.excoriation_depth_um, con las pasadas): arranca la epidermis entera (en
## el brazo, lo de la 1.x), parte de ella (el dorso de la mano, con 86 µm) o, si se queda en la capa córnea, la pule (el
## callo de la palma, de 173 µm: no sangra).
static func _skin_excoriation(c: Dictionary, abr_um: float, epi: float, stack: Array) -> Dictionary:
	var cornea: float = stack[0].to
	var um := Js.to_fixed(abr_um, 0)
	if abr_um >= epi:
		return {
			"scratched": "faint", "sev": 0.22, "verdict": "RASGUÑOS", "vcol": C.gold, "cede": "la epidermis",
			"vsub": "arranca la epidermis (~%s µm): escuece, pero no sangra (la epidermis no tiene vasos)" % um,
		}
	if abr_um > cornea:
		return {
			"scratched": "faint", "sev": 0.22, "verdict": "RASGUÑOS", "vcol": C.gold, "cede": "la epidermis",
			"vsub": "arranca la capa córnea y parte de la epidermis (~%s de %s µm): escuece, pero no sangra (la epidermis no tiene vasos)" % [
				um, Js.to_fixed(epi, 0)],
		}
	return {
		"scratched": "faint", "sev": 0.15, "verdict": "CALLO PULIDO", "vcol": C.gold, "cede": "la capa córnea",
		"vsub": "pule la capa córnea %s (~%s µm de %s): no sangra" % [ZONE_OF.get(c.zone, ""), um, Js.to_fixed(cornea, 0)],
	}


## 2.0 · la herida de una punta que ha roto la piel al rayar, en la zona: hasta el hueso (una garra no rasga hueso), en la
## cavidad del abdomen o, si no, la de la 1.x (_skin_wound) con la severidad de la zona.
static func _skin_cut_wound(
	c: Dictionary, pen: Dictionary, id: String, depth_um: float, epi: float, mm: String, tearing: bool, stack: Array
) -> Dictionary:
	var sev := Zones.severity(c.zone, depth_um)
	var bone: Variant = Zones.bone(c.zone)
	if pen.boneHit and bone != null:
		var sub := "corta hasta el %s (~%s)" % [_bone_name(bone), mm]
		return {
			"scratched": true, "sev": minf(1.0, sev + (0.03 if tearing else 0.0)),
			"verdict": "DESGARRO HASTA EL HUESO" if tearing else "LACERACIÓN HASTA EL HUESO", "vcol": C.coral,
			"vsub": ("la garra engancha y rasga: %s" % sub) if tearing else sub, "cede": "todo lo blando, hasta el hueso",
		}
	if id == "cavidad":
		var sub := "abre la pared del abdomen (~%s mm) y llega a ~%s, dentro de la cavidad" % [
			Js.to_fixed(float(_layer_or_first(stack, "cavidad").from) / 1000.0, 1), mm]
		return {
			"scratched": true, "sev": minf(1.0, sev + (0.03 if tearing else 0.0)), "verdict": "HERIDA PENETRANTE",
			"vcol": C.coral, "vsub": ("la garra engancha y rasga: %s" % sub) if tearing else sub, "cede": "la pared del abdomen",
		}
	return _skin_wound(id, depth_um, epi, mm, tearing, sev)


# ════════ MATERIALES DE LA 2.0: PIEL, UÑA Y MELLADO ════════
# docs/fisica/pulido-materiales.md §7. Los números de los textos, con Format y Js (como JavaScript).

## 2.0 · los campos de los materiales para un resultado ya hecho por el camino 1.x: el ensayo de un aguijón contra un
## sólido (sting_lab.gd, con Sting.solid_params). q: los parámetros con que se hizo; r: el resultado; f_tip: la carga que
## llega a la punta (N). Un aguijón pasa por Fracture.evaluate como cualquier punta (§7.10: el de quitina es blando y
## nunca agrieta). No cambia el veredicto ni la profundidad: un aguijón empuja con milinewtons (no abolla ni parte una
## hoja) y su veredicto lo escribe sting_lab.gd. Devuelve los campos de V2_FIELDS.
static func materials_fields(q: Dictionary, r: Dictionary, f_tip: float) -> Dictionary:
	var target: Dictionary = q.target
	var tool := resolve_tool(q)
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	var puncture: bool = q.get("method") == "puncion"
	var depth: float = r.depthUm
	var a_um: float = float(r.grooveWidthUm) / 2.0
	var through := Js.truthy(r.get("through"))
	var fracture: Variant = Fracture.evaluate(tool, tip, target, f_tip, not puncture, float(target.mu), depth, a_um)
	var recovery: Variant = Recovery.evaluate(target, depth, a_um, through)
	var glazing: Variant = null
	if r.get("paneN") != null:
		var peak: float = minf(float(r.peakN), f_tip)
		if Js.truthy(target.get("tempered")):
			glazing = Glazing.tempered_result(target, peak, float(r.paneN), tool.hv / target.hv >= 1.0, f_tip, tip.tanA)
		elif Js.truthy(target.get("laminated")):
			glazing = Glazing.laminated_result(target, peak, float(r.paneN), fracture != null and fracture.cracks,
				float(r.energyJ))
	return {
		"fracture": fracture, "nail": null, "recovery": recovery,
		"residualDepthUm": recovery.residualDepthUm if recovery != null else depth,
		"dent": Dent.evaluate(target, f_tip, false, 0.0, MODEL.limbStiffness, through), "glazing": glazing, "tipChip": null,
	}

## 2.0 · la piel: la uña (el veredicto, si cede con daño), sin fractura, recuperación ni abolladura (la piel tiene su
## modelo por capas), el mellado informativo de una garra frágil y los campos de la biología: la zona, el informe de
## penetration.gd (pen) y el ángulo de ataque del ensayo (el que flexa la uña; la piel no usa el modo de abrasión, así que
## DpEff y faceDeg van a null, como tipHv: el esmalte solo cuenta contra lo duro). r: el resultado de _skin_result.
static func _skin_v2(c: Dictionary, r: Dictionary, nail: Variant, pen: Variant) -> void:
	var f_tip := float(c.force) * float(c.lever)
	var chip: Variant = _tip_chip(c, f_tip)
	r.merge({
		"fracture": null, "nail": nail, "recovery": null, "residualDepthUm": r.depthUm, "dent": null, "glazing": null,
		"tipChip": chip, "zone": c.zone, "pen": pen, "tipHv": null, "DpEff": null, "faceDeg": null, "attackDeg": attack_deg(c.p),
		"sharpness": _sharpness_of(c.p, c.tool, c.target, f_tip, not c.puncture),
		# unidad 4p: en la piel manda la grieta por capas, no un contacto elástico de Hertz
		"p0MPa": null, "hertzRadiusUm": null, "hertzYield": null,
	}, true)
	if _nail_verdict(c, r, nail):
		r["toolBroken"] = true
	_tip_chip_text(c, r, chip)


## 2.0 · prioridad 1 de §7.3 con una uña: si cede y hubo daño (scratched verdadero o "faint"), la uña es la protagonista,
## «SE DOBLA LA UÑA» o «SE PARTE LA UÑA», y el daño hecho se conserva (capa, profundidad y severidad; el subtítulo lo
## cuenta tras «hasta entonces»). Si no hubo daño, el veredicto se queda y la cesión va en el subtítulo: así no se pierde
## la lección de durezas. v: el veredicto (o el resultado) que se modifica. Devuelve true si la uña pasa a ser el
## veredicto (y entonces la herramienta ha cedido: toolBroken).
static func _nail_verdict(c: Dictionary, v: Dictionary, nail: Variant) -> bool:
	if nail == null or not nail.broken:
		return false
	var parts: bool = nail.mode == "parte"
	var f := Format.fmt_f(nail.breakN)
	if not Js.truthy(v.get("scratched")):
		v["vsub"] = "%s (además, a ~%s N la uña se %s)" % [v.vsub, f, "parte" if parts else "dobla"]
		return false
	var head: String
	if parts:
		head = "%s se parte a ~%s N: la uña libre de %s mm hace de palanca" % [_nail_noun(c), f, Js.js_num_str(nail.lengthMm)]
	else:
		head = "la uña se dobla a ~%s N y el resto %s se queda en tu dedo (uña libre de %s mm en «C», ataque de %s°)" % [
			f, "del golpe" if c.puncture and c.strike else "de la fuerza", Js.js_num_str(nail.lengthMm),
			Js.js_num_str(attack_deg(c.p))]
	v.merge({
		"verdict": "SE PARTE LA UÑA" if parts else "SE DOBLA LA UÑA",
		"vcol": C.coral if parts or v.vcol == C.coral else C.gold, "cede": "la uña",
		"vsub": "%s; hasta entonces, %s" % [head, v.vsub],
	}, true)
	return true


## «el acrílico», «el gel», «el zafiro»… (para «… se parte a ~X N»); «la uña» si es la natural.
static func _nail_noun(c: Dictionary) -> String:
	var names := { "gel": "el gel", "acrilico": "el acrílico", "zafiro": "el zafiro", "metal": "el acero", "titanio": "el titanio" }
	return names.get(String(c.p.base.id), "la uña")


## 2.0 · mellado de la punta de una garra (o un colmillo) reforjada en un material frágil, zafiro o cuarzo
## (Fracture.tip_chip): { chipN, lateralN, chipped, quality, source } o null. Solo informativo (docs/fisica/
## pulido-materiales.md, tema 4): la profundidad no cambia. La fuerza lateral es la fricción al arrastrar (μ·F); al
## punzar, ninguna. f_tip: la carga normal que llega a la punta.
static func _tip_chip(c: Dictionary, f_tip: float) -> Variant:
	var tool: Dictionary = c.tool
	if not tool.useClaw or not tool.hasGem:
		return null
	var sliding: bool = not c.puncture
	return Fracture.tip_chip(String(c.p.inlay.id), c.tip, float(tool.reach), f_tip if sliding else 0.0,
		float(c.target.mu) if sliding else 0.0)


## 2.0 · el compromiso del afilado de una garra reforjada (docs/fisica/velociraptor.md §3 y §10.2): ClawSharpness.tradeoff
## con la punta natural de la ficha (su área y su semiángulo), el afilado del ensayo (sharpness_of), el módulo de la
## herramienta y la resistencia de su material (ClawSharpness.strength_of: la de claw_fracture.gd, unidad 4d), la carga
## normal f_tip que llega a la punta y la fricción del motor: la del material al rayar (sliding) y ninguna al punzar (de
## frente no hay carga lateral, como en el mellado de _tip_chip). La carga lateral μ·F va en el vértice. Contra un sólido,
## con el módulo y la dureza de su superficie; en la piel manda la grieta de penetration.gd, no la dureza, así que la
## presión de Hertz y la hondura plástica van a null. Añade material, sigmaMPa, kind («flexion» | «fluencia» | null), mu y
## forceN. null si la herramienta no se puede afilar (sharpenable).
static func _sharpness_of(p: Dictionary, tool: Dictionary, target: Dictionary, f_tip: float, sliding: bool) -> Variant:
	if not sharpenable(p):
		return null
	var claw: Dictionary = p.claw
	var inlay: Dictionary = p.inlay
	var s := sharpness_of(p)
	var r0 := ClawSharpness.radius_um_of_area(float(claw.area))
	var alpha := float(claw.alpha)
	var strength: Variant = ClawSharpness.strength_of(inlay)
	var mu := float(target.mu) if sliding else 0.0
	var force := maxf(f_tip, 0.0)
	var out: Dictionary
	if Js.truthy(target.get("skin")):
		var r := ClawSharpness.radius_at(r0, s)
		var lateral := mu * force
		var fr := ClawSharpness.evaluate(ClawSharpness.tip_of(r, alpha), strength, lateral)
		out = {
			"naturalUm": r0, "tipRadiusUm": r, "sharpness": ClawSharpness.sharpness_for(r0, r),
			"pressureGain": ClawSharpness.pressure_gain(r0, r), "p0MPa": null, "p0NaturalMPa": null, "yieldOnsetN": null,
			"yieldOnsetNaturalN": null, "depthUm": null, "depthNaturalUm": null, "lateralN": lateral, "chipN": fr.chipN,
			"chipNaturalN": ClawSharpness.chip_load_n(ClawSharpness.tip_of(r0, alpha), float(strength.value)) if strength != null else null,
			"sharpestSurvivingUm": ClawSharpness.sharpest_surviving_um(alpha, float(strength.value), lateral) if strength != null else null,
			"fracture": fr, "survives": not bool(fr.fails),
		}
	else:
		var prof := hardness_profile(target)
		out = ClawSharpness.tradeoff(r0, alpha, s, float(tool.E), strength, force, mu, float(prof.Esurf), float(prof.Hsurf))
	out.merge({
		"material": String(inlay.id), "sigmaMPa": strength.value if strength != null else null,
		"kind": strength.kind if strength != null else null, "mu": mu, "forceN": force,
	}, true)
	return out


## 2.0 · el afilado de la herramienta de unos parámetros de compute() sin hacer el ensayo (el deslizador «Afilado» de la
## interfaz, a través de LabState): el mismo campo `sharpness` que da compute(), con la fuerza pedida (y la palanca del
## desgarro) en la punta. En un ensayo, compute() usa la carga que de verdad llega a la punta (en un golpe, la resistencia
## del camino). null si la herramienta no se puede afilar.
static func sharpness_report(p: Dictionary) -> Variant:
	if not sharpenable(p):
		return null
	var puncture: bool = p.get("method") == "puncion"
	var lever := tear_leverage(p.claw) if Js.truthy(p.get("tear")) and not puncture else 1.0
	return _sharpness_of(p, resolve_tool(p), p.target, float(p.force) * lever, not puncture)


## 2.0 · la línea del mellado en el subtítulo, si la punta se mella (informativo: el veredicto no cambia).
## Con la punta afilada (sharpness_of > 0, unidad 4i) lo que aguanta baja a mN o menos: las fuerzas van en su unidad
## (Format.fmt_small_force); sin afilar, en N, como siempre.
static func _tip_chip_text(c: Dictionary, v: Dictionary, chip: Variant) -> void:
	if chip == null or not chip.chipped:
		return
	if sharpness_of(c.p) > 0.0:
		v["vsub"] = "%s; la punta de %s se mella: aguanta ~%s de lado y la fricción le da ~%s" % [
			v.vsub, String(c.p.inlay.name).to_lower(), Format.fmt_small_force(chip.chipN), Format.fmt_small_force(chip.lateralN)]
		return
	v["vsub"] = "%s; la punta de %s se mella: aguanta ~%s N de lado y la fricción le da ~%s N" % [
		v.vsub, String(c.p.inlay.name).to_lower(), Format.fmt_f(chip.chipN), Format.fmt_f(chip.lateralN)]


# ════════ SÓLIDOS (homogéneos y multicapa) ════════
## c: el contexto de compute(). Los cambios de la 2.0 en los sólidos van en ramas `if c.v2:` (docs/fisica/
## pulido-materiales.md §7): la uña que cede en un golpe, la fuerza que llega a la punta, la fractura de los frágiles, los
## vidrios de coche, la recuperación, la abolladura, el mellado y los veredictos con su prioridad (_solid_v2_verdict). Y
## de la biología (pulido-biologia.md §9.2): el esmalte de la punta de los colmillos (la resistencia y, con el contacto
## final, la dureza de la punta: ratio, eta, toolWorn y presión) y el ángulo de ataque en el modo de abrasión.
static func _solid_result(c: Dictionary) -> Dictionary:
	var tool: Dictionary = c.tool
	var tip: Dictionary = c.tip
	var target: Dictionary = c.target
	var force: float = c.force
	var Neff: float = c.Neff
	var p_nominal: float = c.pNominal
	var Htool: float = c.Htool
	var puncture: bool = c.puncture
	var strike: bool = c.strike
	var energy_j: float = c.energyJ
	var lever: float = c.lever
	var passN: float = c.passN
	var prof := hardness_profile(target)
	var ratio: float = tool.hv / prof.hvSurf
	var eta := Contact.hardness_efficiency(ratio)
	var Feff := Neff * lever
	# ¿plastifica el contacto? (en impacto la carga dinámica lo garantiza)
	var f_mu: float = 1.0 if puncture else float(c.fMu)
	var phi_hertz: float = Contact.plastic_fraction(Feff, tip.R, tool.E, prof.Esurf, prof.Hsurf, f_mu).phi
	var phi := 1.0 if puncture and strike else phi_hertz
	var pass_f := 1.0 if puncture else pass_depth_factor(passN)
	var m: float = phi * (1.0 if puncture else c.type.k * pass_f)  # multiplicador geométrico de profundidad
	var load_share := 1.0 if puncture else 0.5
	# 2.0 · la punta de esmalte de un colmillo natural (fang_enamel.gd): su dureza depende del contacto
	var enamel_tool: Variant = tool if c.v2 and FangEnamel.applies(tool) else null
	# Chapa fina: al romperla, la resistencia puede CAER (pétalos) → primer equilibrio por tramos, como en la piel.
	var sheet: Variant = sheet_of(target)
	var res: Callable
	if m <= 1e-9:
		res = func(_h: float) -> float: return INF
	elif sheet != null:
		res = _make_sheet_resistance(tip, prof, Htool, load_share, m, sheet, enamel_tool)
	else:
		res = _make_resistance(tip, prof, Htool, load_share, m, enamel_tool)
	# Tramos en los que la resistencia solo crece: pintura, chapa entera y pétalos mientras el agujero se ensancha.
	# Cuando ya tiene la anchura de la garra (hCap), los pétalos no piden más: desliza.
	var amax: float = tip.amax
	var h_cap := Contact.depth_for_radius(tip, amax) * maxf(m, 1e-9) if is_finite(amax) else INF
	var breaks: Array = []
	if sheet != null:
		breaks = [sheet.from, sheet.to]
		if h_cap > sheet.to:
			breaks.append(h_cap)
	var h_mm := 0.0
	if m > 1e-9:
		if puncture and strike:
			h_mm = Contact.solve_energy(energy_j * 1000.0, Feff, res)
		elif sheet != null:
			h_mm = Contact.solve_layered(Feff, res, breaks)
		else:
			h_mm = Contact.solve_static(Feff, res)

	# Límites de la herramienta: alcance (longitud útil) y rotura (colmillos). Nada entra más que su propia garra o
	# su uña libre: ni al punzar, ni al rajar una chapa, ni al rayar un sólido blando (madera, plástico): con toda la
	# garra dentro, la pata o el dedo tocan la superficie.
	var reach: float = tool.reach
	var full_reach := false
	var tool_broken := false
	if h_mm >= reach:
		h_mm = reach
		full_reach = true
	# carga que soporta la punta: la aplicada (sin la adhesión, que es de nanonewtons), o la resistencia del
	# material si la punta ya está enterrada hasta la base o frena un golpe. En una chapa el pico llega al romperla
	# (luego los pétalos ceden con menos fuerza): cuenta el máximo del camino, no el final.
	var f_tool := _peak_res(res, breaks, h_mm) if puncture and (full_reach or strike) else force * lever
	var f_break: Variant = tool.get("fBreak")
	if Js.truthy(f_break) and f_tool > f_break:
		tool_broken = true
		var h_break := Contact.solve_layered(f_break, res, breaks) if sheet != null else Contact.solve_static(f_break, res)
		h_mm = minf(h_mm, h_break)
	# 2.0 · golpe con una uña (§7.1): como el colmillo, cede si el camino le pide más que su carga de cesión, y la punta
	# se queda donde la resistencia llega a ella (más la adhesión, que no pasa por la uña). En una hoja de vidrio que la
	# uña puede partir (aguanta su carga de rotura) y que el golpe rompe, la hoja cede antes: la uña no pasa de esa fuerza.
	var nail: Variant = c.get("nail")
	var nail_yield := false
	if c.v2 and nail != null and puncture and strike:
		var f_seen := f_tool
		var pane0: Variant = target.get("pane")
		if Js.truthy(pane0):
			var pb0 := pane_break(pane0, target.E, Contact.contact_radius(tip, h_mm / maxf(m, 1e-9)))
			var k0: float = 1.0 / (1.0 / pb0.k + 1.0 / MODEL.limbStiffness)
			var peak0: float = maxf(Neff, tool.strike.v * sqrt(tool.strike.m * k0 * 1000.0))
			if nail.breakN >= pb0.F and peak0 >= pb0.F:
				f_seen = minf(f_seen, pb0.F)
		nail = _nail_for(c.p, tool, maxf(f_seen - float(c.Fadh), 0.0), false)
		if nail.broken:
			nail_yield = true
			var f_yield: float = nail.breakN + float(c.Fadh)
			var h_yield := Contact.solve_layered(f_yield, res, breaks) if sheet != null else Contact.solve_static(f_yield, res)
			h_mm = minf(h_mm, h_yield)
			full_reach = h_mm >= reach
	var depth_um := h_mm * 1000.0
	var a_um := Contact.contact_radius(tip, h_mm / maxf(m, 1e-9)) * 1000.0
	# 2.0 · la dureza de la punta de un colmillo con el contacto final (fang_enamel.gd): la del esmalte en un contacto
	# pequeño y la de la dentina en uno grande. Con ella, la relación de durezas, la eficiencia, si la punta cede y la
	# presión real. Para cualquier otra herramienta es su dureza (lo de la 1.x).
	var tip_hv: float = tool.hv
	if enamel_tool != null:
		tip_hv = FangEnamel.tip_hv(tool, a_um / 1000.0)
		Htool = tip_hv * HV_MPA
		ratio = tip_hv / prof.hvSurf
		eta = Contact.hardness_efficiency(ratio)

	# Presión media real: nunca más que la dureza de quien cede (punta u objetivo)
	var pressure := minf(p_nominal, minf(Htool, prof.Hsurf))
	var contact_area_mm2 := Neff / maxf(pressure, 1e-9)
	var chi: float = p_nominal / prof.Hsurf
	var through: bool = Js.truthy(target.get("thickness")) and depth_um >= target.thickness * 1000.0 - 1e-6
	# anchura del agujero (chapa) o de la raja
	var hole_um := 2.0 * (Contact.hole_radius(tip, h_mm / maxf(m, 1e-9)) * 1000.0 if sheet != null else a_um)

	# Vidrio de ventana: la hoja se parte si la carga normal la flexa hasta fg,k, o si una punta dura la atraviesa.
	# En un golpe, la fuerza de pico sale de la masa contra dos muelles en serie: la hoja (k) y el tejido blando de
	# la pata o del dedo (MODEL.limbStiffness): F = v·√(m·k_ef). Por eso un zarpazo de gato no rompe una ventana y
	# el picado de un halcón sí. A la hoja nunca llega más fuerza de la que aguanta la herramienta: un colmillo se
	# rompe antes.
	var shattered := false
	var pane_n: Variant = null
	var pane_j: Variant = null
	var peak_n: Variant = null
	var punched := false
	var pane: Variant = target.get("pane")
	var pb: Dictionary = {}
	var can_push := true
	if Js.truthy(pane):
		pb = pane_break(pane, target.E, a_um / 1000.0)
		var k_eff: float = 1.0 / (1.0 / pb.k + 1.0 / MODEL.limbStiffness)  # N/mm
		var f_strike: float = tool.strike.v * sqrt(tool.strike.m * k_eff * 1000.0) if puncture and strike else 0.0
		pane_n = pb.F
		pane_j = pb.U / 1000.0
		peak_n = maxf(Neff, f_strike)
		punched = depth_um >= pane.t * 1000.0 - 1e-6
		can_push = not Js.truthy(f_break) or f_break >= pb.F
		if c.v2 and nail != null and not c.get("paneFirst", false):
			can_push = can_push and nail.breakN >= pb.F  # 2.0: la uña cede antes de poder partirla
	# 2.0 · lo que llega a la punta (la carga de los módulos de la 1f): la fuerza pedida, ya limitada por la uña, con la
	# palanca del desgarro; en un golpe, la resistencia del camino (la del modelo de penetración), sin pasar de lo que
	# aguanta la herramienta ni, en una hoja, del pico del golpe. Y la fractura de los frágiles (fracture.gd).
	var f_tip: float = force * lever
	var fracture: Variant = null
	var glazing: Variant = null
	if c.v2:
		if puncture and strike:
			f_tip = f_tool
			if tool_broken:
				f_tip = minf(f_tip, float(f_break))
			if nail_yield:
				f_tip = minf(f_tip, float(nail.breakN))
			if Js.truthy(pane):
				f_tip = minf(f_tip, float(peak_n))
		fracture = Fracture.evaluate(tool, tip, target, f_tip, not puncture, float(target.mu), depth_um, a_um)
	if Js.truthy(pane):
		var tempered: bool = c.v2 and Js.truthy(target.get("tempered"))
		var laminated: bool = c.v2 and Js.truthy(target.get("laminated"))
		if tempered or laminated:
			# 2.0 · vidrios de coche (glazing.gd): la hoja flexa como la ventana, con su resistencia, y a ella no llega más
			# de lo que aguanta la herramienta
			var cap := INF
			if Js.truthy(f_break):
				cap = float(f_break)
			if nail != null and not c.get("paneFirst", false):
				cap = minf(cap, float(nail.breakN))
			var peak_glz: float = minf(float(peak_n), cap)
			if tempered:
				glazing = Glazing.tempered_result(target, peak_glz, pb.F, tool.hv / target.hv >= 1.0, f_tip, tip.tanA)
				shattered = glazing.shattered or punched
			else:
				glazing = Glazing.laminated_result(target, peak_glz, pb.F, fracture != null and fracture.cracks, energy_j)
				# el laminado no cae y la punta no pasa del vidrio, salvo con más energía que la de la homologación
				if glazing.penetrationRisk:
					through = depth_um >= pane.t * 1000.0 - 1e-6
				else:
					depth_um = minf(depth_um, pane.t * 1000.0)
		else:
			shattered = punched or (can_push and peak_n >= pb.F)
		# rota la hoja, la punta no puede estar más honda que su espesor: pasa por el hueco
		if shattered:
			depth_um = minf(depth_um, pane.t * 1000.0)
			through = depth_um >= pane.t * 1000.0 - 1e-6
	# 2.0 · empujando, una hoja que se parte (o que la punta atraviesa) ha cedido antes que la uña: se rompe con una carga
	# que la uña aguanta (can_push y el tope de la ventanilla lo exigen) y luego la punta pasa por el hueco. La uña no
	# llega a su carga de cesión ni limita nada, así que el ensayo se repite con la fuerza pedida (el de la 1.x, con los
	# campos de la 2.0). Con la carga de la cesión la hoja ya se partía, y con más también: su resistencia apenas crece
	# con el radio del contacto. El laminado no entra aquí: no se parte y se puede seguir empujando hasta que la uña cede.
	# En un golpe lo decide la comprobación de antes (la hoja cede antes y la uña no pasa de esa fuerza).
	if c.v2 and shattered and nail != null and nail.broken and not strike and not c.get("paneFirst", false):
		var f_gave: float = float(pb.F) - float(c.Fadh)
		if glazing != null and glazing.cause == "grieta":
			f_gave = float(glazing.pierceN)
		if punched:
			f_gave = minf(f_gave, float(res.call(pane.t)) - float(c.Fadh))
		return _solid_result(_pane_first_ctx(c, _nail_for(c.p, tool, clampf(f_gave, 0.0, float(nail.breakN)), not puncture)))

	# Energía que se queda el material: en una hoja rota, la que la partió (después la punta pasa por el hueco).
	var work_j: float = pane_j if shattered else Contact.absorbed_work(res, depth_um / 1000.0, breaks)
	# 2.0 · recuperación (recovery.gd) y abolladura (dent.gd). Los no frágiles se clasifican con la huella que queda al
	# levantar la punta; los frágiles, con la profundidad bajo carga (lo que se ve son las grietas y el astillado).
	var recovery: Variant = null
	var dent: Variant = null
	var vis_um := depth_um
	if c.v2:
		recovery = Recovery.evaluate(target, depth_um, a_um, through)
		if recovery != null and fracture == null:
			vis_um = recovery.residualDepthUm
		var f_cap := INF
		if tool_broken:
			f_cap = float(f_break)
		if nail != null and nail.broken:
			f_cap = minf(f_cap, float(nail.breakN))
		dent = Dent.evaluate(target, f_tip, puncture and strike, energy_j - work_j, MODEL.limbStiffness, through, f_cap)

	var v: Dictionary
	if Js.truthy(target.get("paint")):
		v = _paint_verdict(vis_um, ratio, puncture, target, through, full_reach, hole_um)
	elif Js.truthy(target.get("woodDoor")):
		v = _door_verdict(vis_um, ratio, puncture, through, target)
	else:
		v = _generic_verdict(vis_um, ratio, puncture, through, target, sheet, full_reach, hole_um)
	if c.v2:
		v = _solid_v2_verdict(c, v, depth_um, fracture, recovery, dent, through)
	if shattered and glazing != null:
		v = _spread(v, _tempered_verdict(c, glazing, pane, peak_n))
	elif shattered:
		var t_txt := Js.js_num_str(pane.t)
		var fgk_txt := Js.js_num_str(pane.fgk)
		var vsub: String
		if punched:
			vsub = "la punta atraviesa la hoja de %s mm y la parte" % t_txt
		elif Neff >= pane_n:
			vsub = "%s N en el centro flexan la hoja de %s mm hasta %s MPa (se parte desde ~%s N)" % [
				Format.fmt_f(Neff), t_txt, fgk_txt, Format.fmt_f(pane_n)]
		else:
			vsub = "el golpe da un pico de ~%s N: la hoja de %s mm flexa hasta %s MPa (se parte desde ~%s N)" % [
				Format.fmt_f(peak_n), t_txt, fgk_txt, Format.fmt_f(pane_n)]
		v = _spread(v, {
			"verdict": "ROMPE EL VIDRIO", "vcol": C.coral, "cede": "el vidrio (en pedazos)", "scratched": true, "sev": 1.0,
			"layer": null, "vsub": vsub,
		})
	if glazing != null and glazing.kind == "laminado" and glazing.cracked:
		v = _spread(v, _laminated_verdict(c, glazing, peak_n))
	if tool_broken:
		# El daño hecho antes de romperse se conserva (capa, severidad); cambia el protagonista.
		v = _spread(v, {
			"verdict": "SE ROMPE LA PUNTA", "vcol": C.gold, "cede": "el colmillo" if tool.fang else "la punta",
			"vsub": "el %s cede a ~%s N tras entrar %s" % [
				"colmillo" if tool.fang else "punzón", Js.js_num_str(f_break), Format.fmt_depth(depth_um)],
		})
	# 2.0 · la uña cede (prioridad 1, con el daño hecho) y el mellado de una garra frágil (informativo)
	var nail_verdict := false
	var chip: Variant = null
	if c.v2:
		nail_verdict = _nail_verdict(c, v, nail)
		chip = _tip_chip(c, f_tip)
		_tip_chip_text(c, v, chip)
	var tool_worn := ratio < MODEL.rOff

	# ── Abrasión (Hokkirigawa-Kato 1988): Dp = h/a decide arado → cuña → corte ──
	# 2.0 · con el ángulo de ataque del ensayo (attack.gd): inclinar la herramienta gira la cara que avanza y cambia el Dp
	# efectivo, no la profundidad. Con 90° (garras y colmillos, por defecto) es exactamente la 1.x.
	var Dp := depth_um / a_um if a_um > 0.0 else 0.0
	var abs_mode: Variant = null
	var fab := 1.0
	var mu_plough := 0.0
	var dp_eff := Dp
	var attack: float = attack_deg(c.p) if c.v2 else Attack.DEFAULT_DEG
	if not puncture and depth_um > 0.5 and Js.truthy(v.scratched):
		var ab := Attack.abrasion(Dp, depth_um, m, tip, tool.alpha, attack) if c.v2 else Abrasion.abrasion_mode(Dp)
		abs_mode = ab.absMode
		fab = ab.fab
		mu_plough = ab.muPlough
		if c.v2:
			dp_eff = ab.DpEff
	var mu: float = target.mu
	var mu_eff := mu + mu_plough
	var hsoft_hv := (Htool if tool_worn else minf(Htool, prof.Hsurf)) / HV_MPA
	# Archard da el volumen deformado; lo arrancado es fab·volumen. Sin surco solo hay pulido (2 %, el mínimo del
	# arado): así un roce nunca «desgasta» más que un arañazo.
	var wear_idx: float
	if puncture:
		wear_idx = Js.js_round((400.0 * force * (2.0 if strike else 1.0)) / maxf(hsoft_hv, 5.0))
	else:
		var removed := fab if abs_mode != null else 0.02
		wear_idx = Js.js_round((1500.0 * force * c.length * passN * removed) / maxf(hsoft_hv, 5.0))
	var r := _spread(c.common, v)
	r.merge({
		"pressure": pressure, "ratio": ratio, "chi": chi, "stress": null, "toolWorn": tool_worn, "depthUm": depth_um,
		"sev": v.sev, "Ffric": mu * Neff if puncture else mu_eff * Neff, "muAdh": mu, "muPlough": mu_plough,
		"muEff": mu_eff, "absMode": abs_mode, "Dp": Dp, "fab": fab, "wearIdx": wear_idx, "tearing": c.tearing,
		"puncture": puncture, "inject": false, "pierces": depth_um > 1.0 if puncture else null, "energyJ": energy_j,
		"toolBroken": tool_broken or nail_verdict, "fullReach": full_reach, "through": through, "shattered": shattered,
		"paneN": pane_n, "peakN": peak_n, "workJ": work_j,
		"tHV": prof.hvSurf, "tMohs": target.get("mohs"), "phi": phi, "eta": eta, "grooveWidthUm": hole_um,
		"contactAreaMm2": contact_area_mm2,
	}, true)
	if c.v2:
		r.merge({
			"fracture": fracture, "nail": nail, "recovery": recovery,
			"residualDepthUm": recovery.residualDepthUm if recovery != null else depth_um, "dent": dent, "glazing": glazing,
			"tipChip": chip, "zone": null, "pen": null, "tipHv": tip_hv, "DpEff": dp_eff,
			"faceDeg": Attack.face_angle_deg(tool.alpha, attack), "attackDeg": attack,
			"sharpness": _sharpness_of(c.p, tool, target, f_tip, not puncture),
		}, true)
		# unidad 4p: el pico de Hertz de un contacto elástico (la presión media del resultado reparte F por toda la punta)
		r.merge(_hertz(c, Feff, tip, prof, f_mu, enamel_tool, tool_broken), true)
	return r


## 2.0 · el contacto elástico de Hertz del ensayo (unidad 4p; SRC_HERTZ): el pico de presión p0 = 3F/(2π·a²) en el centro
## de un círculo de radio a = (3FR/4E*)^(1/3), los que Contact.plastic_fraction ya calcula para decidir φ, con la misma carga
## (la normal, con la adhesión y la palanca del desgarro) y la esfera de la punta. Mientras el contacto es elástico, la
## presión del resultado (F/A, la fuerza repartida por toda la punta) no es la que soporta el contacto: la punta solo toca
## en ese círculo. Vale donde el motor da el contacto por elástico o a medias (φ < 1: el material no plastifica del todo),
## con un sólido homogéneo (con pintura o laca, una capa más fina que el contacto, ya no es el de Hertz), sin golpe (la carga
## dinámica plastifica: φ = 1), sin la herramienta rota y mientras el círculo cabe en la esfera de la punta (a ≤ a_t: si no,
## manda el cono). Quién pasa de su límite elástico (p0, con el factor de von Mises del rayado, por encima de 1,6·Y, con
## Y = H/2,8: φ > 0 con su dureza; la punta de un colmillo, con la de su esmalte en ese contacto, fang_enamel.gd), en
## hertzYield: «punta», «objetivo», «las dos» o null si todo es elástico. Si alguno cede, el pico de Hertz es una cota alta:
## el de verdad es menor y la presión media no pasa de la dureza de quien cede. { p0MPa, hertzRadiusUm, hertzYield }, con todo
## a null si no aplica. f_eff: la carga (N); f_mu: el factor de von Mises (1 al punzar).
static func _hertz(
	c: Dictionary, f_eff: float, tip: Dictionary, prof: Dictionary, f_mu: float, enamel_tool: Variant, broken: bool
) -> Dictionary:
	var none := { "p0MPa": null, "hertzRadiusUm": null, "hertzYield": null }
	if (c.puncture and c.strike) or broken or int(prof.kind) != PROFILE_SOLID or not (f_eff > 0.0):
		return none
	var tool: Dictionary = c.tool
	var on_target := Contact.plastic_fraction(f_eff, tip.R, tool.E, prof.Esurf, prof.Hsurf, f_mu)
	var a: float = on_target.aH
	if float(on_target.phi) >= 1.0 or a > float(tip.at):
		return none
	var h_tip: float = c.Htool
	if enamel_tool != null:
		h_tip = FangEnamel.tip_hv(tool, a) * HV_MPA
	var on_tip := Contact.plastic_fraction(f_eff, tip.R, tool.E, prof.Esurf, h_tip, f_mu)
	var who: Variant = null
	if float(on_tip.phi) > 0.0 and float(on_target.phi) > 0.0:
		who = "las dos"
	elif float(on_tip.phi) > 0.0:
		who = "punta"
	elif float(on_target.phi) > 0.0:
		who = "objetivo"
	return { "p0MPa": on_target.p0, "hertzRadiusUm": a * 1000.0, "hertzYield": who }


## Máximo de res en el camino hasta h: el final y el último punto de cada tramo cruzado (Math.max(res(h), …)).
static func _peak_res(res: Callable, breaks: Array, h: float) -> float:
	var peak: float = res.call(h)
	for b: float in breaks:
		if b > 0.0 and b < h:
			peak = maxf(peak, res.call(b - 1e-9))
	return peak


## 2.0 · el contexto del ensayo que se repite cuando la hoja cede antes que la uña (_solid_result): la fuerza pedida, con
## la carga efectiva y la presión nominal de siempre (las de compute()), la uña evaluada con la carga con que cedió la
## hoja y la marca paneFirst (la uña ya no pone tope a la hoja ni a la ventanilla).
static func _pane_first_ctx(c: Dictionary, nail: Variant) -> Dictionary:
	var tool: Dictionary = c.tool
	var force: float = c.p.force
	var neff: float = force + float(c.Fadh)
	var p_nominal: float = neff / tool.area
	var common: Dictionary = c.common.duplicate()
	common["pNominal"] = p_nominal
	var out: Dictionary = c.duplicate()
	out.merge({ "force": force, "Neff": neff, "pNominal": p_nominal, "common": common, "nail": nail, "paneFirst": true }, true)
	return out


# ── Veredictos de los materiales de la 2.0 (docs/fisica/pulido-materiales.md §7.3 y §7.4) ──

## 2.0 · veredictos de los materiales en un sólido, de menos a más prioridad (el que manda se aplica el último): el
## astillado y la recuperación en el subtítulo (5), las grietas de Hertz (4) y la abolladura (3). Los vidrios (2) y la
## herramienta que cede (1) los aplica _solid_result después. El daño hecho se conserva: capa, profundidad y severidad.
## depth_um: la profundidad bajo carga; v: el veredicto del 1.x (con la huella residual en los no frágiles).
static func _solid_v2_verdict(
	c: Dictionary, v: Dictionary, depth_um: float, fracture: Variant, recovery: Variant, dent: Variant, through: bool
) -> Dictionary:
	var target: Dictionary = c.target
	var puncture: bool = c.puncture
	var out := v.duplicate()
	# (5) frágil con surco y grietas: el veredicto de siempre, con el subtítulo del astillado (Lawn & Evans 1977)
	if fracture != null and fracture.mode == "radial":
		var crack := Format.fmt_depth(fracture.crackUm)
		if puncture:
			out.vsub = "pozo de punción con grietas radiales (~%s de grieta)" % crack
		else:
			out.vsub = "surco con grietas laterales que astillan el borde (~%s de grieta)" % crack
	# (5) no frágil: se ve la huella que queda al levantar la punta (Oliver & Pharr 1992)
	if recovery != null and fracture == null and recovery.fraction >= RECOVERY_TEXT_FRACTION and depth_um >= 0.05:
		out.vsub = _recovery_text(c, out, depth_um, recovery)
	# (4) grietas de Hertz: la punta roma no hace surco, pero el material se agrieta (Auerbach; Ren & Zhang 2014)
	if fracture != null and fracture.mode == "hertz":
		var f := Format.fmt_f(fracture.hertzN)
		var why: String
		if puncture:
			why = "la punta roma no entra, pero a ~%s N salta un anillo que baja en cono bajo la superficie" % f
		else:
			why = "no raya: la punta roma se queda en contacto elástico, pero al deslizar abre grietas en herradura desde ~%s N (conos de Hertz a medias)" % f
		out.merge({
			"verdict": "CONO DE HERTZ" if puncture else "GRIETAS DE HERTZ", "vcol": C.gold,
			"cede": "%s (grietas de Hertz)" % String(target.name).to_lower(), "vsub": why,
		}, true)
	# (3) abolladura de la chapa: al punzar o golpear sin perforar manda; rayando, va en el subtítulo (surco abollado)
	if dent != null and dent.visible and not through:
		var door: bool = target.get("body") == null  # la puerta de aluminio (sin carrocería)
		var noun := "la puerta" if door else "la chapa"
		var mm := fmt_mm(dent.depthMm)
		if puncture:
			var how: String
			if c.strike:
				how = "no la perfora, pero la abolla ~%s mm: %s se queda %s J y el resto lo amortigua %s" % [
					mm, noun, Format.fmt_j(dent.panelJ), _striker(c)]
			else:
				how = "no la perfora, pero la abolla ~%s mm: %s cede desde ~%s N y la punta empuja con ~%s N" % [
					mm, noun, Format.fmt_f(dent.collapseN), Format.fmt_f(dent.peakN)]
			out.merge({
				"verdict": "ABOLLA LA PUERTA" if door else "ABOLLA LA CHAPA", "vcol": C.coral if out.vcol == C.coral else C.gold,
				"cede": "%s (abollada)" % noun, "vsub": "%s · %s" % [how, out.vsub],
			}, true)
		else:
			out.vsub = "%s · y abolla %s ~%s mm" % [out.vsub, noun, mm]
	return out


## Quién amortigua el golpe que no se queda la chapa (el muelle blando de MODEL.limbStiffness): tu dedo, la cabeza de la
## serpiente o la pata.
static func _striker(c: Dictionary) -> String:
	var tool: Dictionary = c.tool
	if not tool.useClaw:
		return "tu dedo"
	return "la cabeza de la serpiente" if tool.fang else "la pata"


## Milímetros legibles (la abolladura del subtítulo y del informe de daños, Lab.damage_report): 0.32 · 2.8.
static func fmt_mm(x: float) -> String:
	return Js.to_fixed(x, 2) if x < 1.0 else Js.to_fixed(x, 1)


## «se hunde 3.5 µm bajo carga, pero al levantar la punta el barniz recupera y no deja surco: marca pulible», o, si queda
## daño, el subtítulo de siempre con la huella que queda (Oliver & Pharr 1992).
static func _recovery_text(c: Dictionary, v: Dictionary, depth_um: float, rec: Dictionary) -> String:
	var paint := Js.truthy(c.target.get("paint"))
	var who := "el barniz" if paint else "el material"
	var pit := "huella" if c.puncture else "surco"
	var left := ("no deja %s" % pit) if rec.residualDepthUm <= 0.0 else ("deja %s de %s" % [pit, Format.fmt_depth(rec.residualDepthUm)])
	if not Js.truthy(v.get("scratched")):
		return "se hunde %s bajo carga, pero al levantar la punta %s recupera y %s%s" % [
			Format.fmt_depth(depth_um), who, left, ": marca pulible" if paint else ""]
	return "%s · se hunde %s bajo carga; al levantar la punta %s recupera y %s" % [v.vsub, Format.fmt_depth(depth_um), who, left]


## 2.0 · «ESTALLA LA VENTANILLA» (glazing.gd): por flexión, por una grieta que atraviesa la capa comprimida o porque la
## punta la atraviesa; el tamaño y el número de trozos, de Nielsen et al. (2022).
static func _tempered_verdict(c: Dictionary, glazing: Dictionary, pane: Dictionary, peak_n: float) -> Dictionary:
	var bits := "estalla en ~%s trocitos de ~%s mm por cada 5 × 5 cm, romos y sin filo" % [
		Js.js_num_str(Js.js_round(glazing.fragments25)), Js.to_fixed(glazing.fragmentMm, 1)]
	var t_txt := Js.js_num_str(pane.t)
	var vsub: String
	if glazing.cause == "grieta":
		vsub = "la punta dura abre una grieta que atraviesa la capa comprimida (~%s mm): toda la energía del temple se libera de golpe y %s. Es el truco del martillo de emergencia" % [
			Js.to_fixed(glazing.compressionMm, 2), bits]
	elif glazing.cause == "flexión" and c.Neff >= glazing.bendN:
		vsub = "%s N en el centro flexan la hoja templada de %s mm hasta %s MPa (se parte desde ~%s N): %s" % [
			Format.fmt_f(c.Neff), t_txt, Js.js_num_str(pane.fgk), Format.fmt_f(glazing.bendN), bits]
	elif glazing.cause == "flexión":
		vsub = "el golpe da ~%s N y el templado se parte desde ~%s N: %s" % [Format.fmt_f(peak_n), Format.fmt_f(glazing.bendN), bits]
	else:
		vsub = "la punta atraviesa la hoja templada de %s mm: %s" % [t_txt, bits]
	return {
		"verdict": "ESTALLA LA VENTANILLA", "vcol": C.coral, "cede": "la ventanilla (en trocitos)", "scratched": true,
		"sev": 1.0, "layer": null, "vsub": vsub,
	}


## 2.0 · «SE AGRIETA (NO CAE)» (glazing.gd): el parabrisas laminado se agrieta en estrella y telaraña, pero la lámina de
## PVB sujeta los trozos. Con más energía que la bola de la homologación (88,7 J) podría atravesarlo (sin medición con
## puntas: el modelo no dice cuánto aguanta).
static func _laminated_verdict(c: Dictionary, glazing: Dictionary, peak_n: float) -> Dictionary:
	var hold := "pero la lámina de PVB sujeta los trozos: no cae"
	var vsub: String
	if glazing.cause == "flexión" and c.Neff >= glazing.bendN:
		vsub = "%s N en el centro flexan el parabrisas (se agrieta desde ~%s N): estrella y telaraña, %s" % [
			Format.fmt_f(c.Neff), Format.fmt_f(glazing.bendN), hold]
	elif glazing.cause == "flexión":
		vsub = "el golpe da ~%s N y el vidrio se agrieta desde ~%s N, en estrella y telaraña, %s" % [
			Format.fmt_f(peak_n), Format.fmt_f(glazing.bendN), hold]
	else:
		vsub = "la punta dura abre grietas en el vidrio de fuera, %s" % hold
	if glazing.penetrationRisk:
		vsub += "; con %s J supera los %s J que garantiza la homologación: podría atravesarlo" % [
			Format.fmt_j(c.energyJ), Js.to_fixed(glazing.penetrationJ, 1)]
	return {
		"verdict": "SE AGRIETA (NO CAE)", "vcol": C.coral, "cede": "el parabrisas (agrietado, sujeto por la lámina)",
		"scratched": true, "sev": 1.0, "layer": null, "vsub": vsub,
	}


## Coche: qué capa de pintura cede y, debajo, qué le pasa a la carrocería (marcarla, perforarla, que la
## herramienta entera la atraviese o, rayando, rajarla de lado a lado).
static func _paint_verdict(
	depth_um: float, ratio: float, puncture: bool, target: Dictionary, through: bool, full_reach: bool, hole_um: float
) -> Dictionary:
	var L: Array = Data.car_layers(target)
	var body: Dictionary = target.body
	var paint_um: float = Data.PAINT_LAYERS[-1].to
	var body_end: float = paint_um + body.t
	var hit: Dictionary = L[-1]
	for l: Dictionary in L:
		if depth_um <= l.to:
			hit = l
			break
	var sev := Contact.clamp_js(depth_um / paint_um, 0.05 if puncture else 0.0, 1.0)
	var BODY := "LA CHAPA" if body.metal else "EL PLÁSTICO"
	var body_layer := "metal (chapa)" if body.metal else "plástico"
	var thick := Format.fmt_depth(body.t)
	var hole := Format.fmt_depth(hole_um)
	if ratio < MODEL.rOff or depth_um < 1.5:
		if puncture:
			return {
				"verdict": "APENAS ROZA", "vcol": C.mint, "vsub": "marca mínima en el barniz", "cede": "nada (pulible)",
				"scratched": false, "layer": "barniz", "sev": sev,
			}
		return {
			"verdict": "ROZA / REMOLINO", "vcol": C.mint, "vsub": "marca de barniz pulible, no penetra",
			"cede": "nada (pulible)", "scratched": false, "layer": "barniz · superficie", "sev": sev,
		}
	if puncture:
		if through and full_reach:
			return {
				"verdict": "ATRAVIESA %s" % BODY, "vcol": C.coral,
				"vsub": "la punta entera pasa al otro lado: agujero de ~%s en %s de %s" % [hole, body.long, thick],
				"cede": "%s (de lado a lado)" % body.noun, "scratched": true, "layer": body_layer, "sev": 1.0,
			}
		if through:
			return {
				"verdict": "PERFORA %s" % BODY, "vcol": C.coral,
				"vsub": "la punta sale ~%s por detrás · agujero de ~%s con pétalos" % [Format.fmt_depth(depth_um - body_end), hole],
				"cede": "%s (perforada)" % body.noun, "scratched": true, "layer": body_layer, "sev": 0.92,
			}
		var hole_to := "agujero hasta %s" % hit.cede
		if depth_um > paint_um + 1.0:  # atraviesa la pintura y entra en la carrocería
			hole_to = "atraviesa la pintura y se clava ~%s en %s (de %s)" % [Format.fmt_depth(depth_um - paint_um), body.noun, thick]
		return {
			"verdict": "PUNCIÓN", "vcol": C.coral, "cede": hit.cede, "scratched": true, "layer": hit.id, "sev": sev,
			"vsub": hole_to,
		}
	if through:
		return {
			"verdict": "RAJA %s" % BODY, "vcol": C.coral,
			"vsub": "corta %s de %s de lado a lado: raja de ~%s de ancho" % [body.noun, thick, hole],
			"cede": "%s (rajada)" % body.noun, "scratched": true, "layer": body_layer, "sev": 1.0,
		}
	var table := {
		"barniz": ["ARAÑAZO EN BARNIZ", C.gold, "queda en el clearcoat · se pule", "faint", "barniz (clearcoat)"],
		"color": ["LLEGA AL COLOR", C.coral, "atraviesa el barniz · necesita retoque", true, "color (basecoat)"],
		"imprimacion": ["HASTA IMPRIMACIÓN", C.coral, "se ve gris/blanco del primer", true, "imprimación (primer)"],
		"anticorrosivo": ["HASTA ANTICORROSIVO", C.coral, "expone el e-coat", true, "anticorrosivo (e-coat)"] if body.metal
			else ["HASTA EL PROMOTOR", C.coral, "queda el promotor de adherencia sobre el plástico", true, "promotor de adherencia"],
		"carroceria": ["HASTA EL METAL", C.coral, "chapa expuesta · riesgo de óxido", true, body_layer] if body.metal
			else ["HASTA EL PLÁSTICO", C.coral, "plástico al aire: se ve el material sin pintar", true, body_layer],
	}
	var reached_body := depth_um > paint_um - 1e-6
	var row: Array = table["carroceria" if reached_body else hit.id]
	var vsub: String = row[2]
	if reached_body and depth_um > paint_um + 5.0:
		vsub = "%s · surco de ~%s en %s de %s" % [row[2], Format.fmt_depth(depth_um - paint_um), body.noun, thick]
	return {
		"verdict": row[0], "vcol": row[1], "vsub": vsub, "cede": body.noun if reached_body else hit.cede,
		"scratched": row[3], "layer": row[4], "sev": sev,
	}


## Puerta de madera barnizada: la laca, la madera o de lado a lado.
static func _door_verdict(depth_um: float, ratio: float, puncture: bool, through: bool, target: Dictionary) -> Dictionary:
	var laca_um: float = target.layers.film.t
	var thick_um: float = target.thickness * 1000.0
	var sev := Contact.clamp_js(_sev_log(depth_um, thick_um), 0.05, 1.0)
	var layer := "laca" if depth_um <= laca_um else "madera"
	if ratio < MODEL.rOff or depth_um < 1.5:
		if puncture:
			return {
				"verdict": "APENAS ROZA", "vcol": C.mint, "vsub": "marca mínima en la laca", "cede": "nada",
				"scratched": false, "layer": layer, "sev": sev,
			}
		return {
			"verdict": "ROZA LA LACA", "vcol": C.mint, "vsub": "marca superficial pulible, no penetra la laca",
			"cede": "nada (pulible)", "scratched": false, "layer": "laca · superficie", "sev": sev,
		}
	if through:
		return {
			"verdict": "ATRAVIESA LA PUERTA", "vcol": C.coral, "vsub": "de lado a lado — ¡aquí está Johnny!",
			"cede": "la puerta entera", "scratched": true, "layer": "madera", "sev": 1.0,
		}
	if depth_um <= laca_um:
		if puncture:
			return {
				"verdict": "PUNCIÓN EN LA LACA", "vcol": C.gold, "cede": "la laca", "scratched": true, "layer": layer,
				"vsub": "agujero de ~%s µm, solo el barniz" % Js.to_fixed(depth_um, 0), "sev": sev,
			}
		return {
			"verdict": "ARAÑAZO EN LA LACA", "vcol": C.gold, "cede": "la laca", "scratched": "faint", "layer": "laca (barniz)",
			"vsub": "queda en el barniz (~%s µm) · se pule" % Js.to_fixed(depth_um, 0), "sev": sev,
		}
	if puncture:
		return {
			"verdict": "CLAVADA EN LA MADERA", "vcol": C.coral,
			"vsub": "entra ~%s de los %s mm; falta para atravesar" % [Format.fmt_depth(depth_um), Js.js_num_str(target.thickness)],
			"cede": "la madera", "scratched": true, "layer": layer, "sev": sev,
		}
	return {
		"verdict": "LLEGA A LA MADERA", "vcol": C.coral,
		"vsub": "atraviesa la laca y entra ~%s mm en la madera desnuda" % Js.to_fixed(depth_um / 1000.0, 2),
		"cede": "la madera", "scratched": true, "layer": layer, "sev": sev,
	}


## Sólidos homogéneos, chapa de la puerta de aluminio y vidrio.
static func _generic_verdict(
	depth_um: float, ratio: float, puncture: bool, through: bool, target: Dictionary, sheet: Variant, full_reach: bool,
	hole_um: float
) -> Dictionary:
	var name := String(target.name).to_lower()
	var thickness: Variant = target.get("thickness")
	var brittle := Js.truthy(target.get("brittle"))
	if puncture:
		var full_um: float = thickness * 1000.0 if Js.truthy(thickness) else 200.0
		if ratio < MODEL.rOff:
			return {
				"verdict": "NO PERFORA", "vcol": C.mint, "vsub": "la punta se embota/rompe antes de entrar",
				"cede": "la punta", "scratched": false, "sev": 0.06, "layer": null,
			}
		# Chapa fina: romperla (la punta asoma) no es lo mismo que la herramienta entera pase al otro lado.
		if through and sheet != null and not full_reach:
			return {
				"verdict": "PERFORA LA PUERTA", "vcol": C.coral,
				"vsub": "la punta sale ~%s por detrás · agujero de ~%s con pétalos" % [
					Format.fmt_depth(depth_um - full_um), Format.fmt_depth(hole_um)],
				"cede": "la puerta de metal (perforada)", "scratched": true, "sev": 0.92, "layer": null,
			}
		if through:
			# (una hoja de vidrio rota también llega aquí, sin thickness: el JS escribe «undefined» y el veredicto de
			# ROMPE EL VIDRIO tapa después este texto)
			return {
				"verdict": "ATRAVIESA LA PUERTA", "vcol": C.coral,
				"vsub": "de lado a lado (%s mm de metal perforados)" % Js.template_str(thickness),
				"cede": "la puerta de metal", "scratched": true, "sev": 1.0, "layer": null,
			}
		if depth_um > 1.0:
			var of_thick := (" de %s mm" % Js.js_num_str(thickness)) if Js.truthy(thickness) else ""
			return {
				"verdict": "PERFORA · ASTILLA" if brittle else "PERFORA", "vcol": C.coral,
				"vsub": ("microfractura: pozo de punción en %s" % name) if brittle
					else ("pozo de punción ~%s%s" % [Format.fmt_depth(depth_um), of_thick]),
				"cede": "%s (pozo)" % name, "scratched": true, "sev": Contact.clamp_js(_sev_log(depth_um, full_um), 0.1, 1.0),
				"layer": null,
			}
		return {
			"verdict": "APENAS MARCA", "vcol": C.gold, "vsub": "pozo incipiente ~%s µm (sube la fuerza)" % Js.to_fixed(depth_um, 1),
			"cede": name, "scratched": false, "sev": 0.06, "layer": null,
		}
	var sev := _sev_log(depth_um, 100.0)
	if ratio < MODEL.rOff:
		return {
			"verdict": "NO RAYA", "vcol": C.mint, "vsub": "más blanda: la punta se desgasta", "cede": "tu punta",
			"scratched": false, "sev": 0.0, "layer": null,
		}
	if through and sheet != null:
		return {
			"verdict": "RAJA LA PUERTA", "vcol": C.coral,
			"vsub": "corta los %s mm de metal de lado a lado: raja de ~%s de ancho" % [
				Js.js_num_str(thickness), Format.fmt_depth(hole_um)],
			"cede": "la puerta de metal (rajada)", "scratched": true, "sev": 1.0, "layer": null,
		}
	if depth_um < 0.05:
		return {
			"verdict": "ROZA SIN MARCAR", "vcol": C.mint,
			"vsub": "más dura, pero contacto elástico (presión insuficiente)" if ratio >= 1.25 else "dureza similar y poca presión",
			"cede": "nada (desliza)", "scratched": false, "sev": 0.0, "layer": null,
		}
	if ratio < 1.25:
		return {
			"verdict": "MARCA TENUE", "vcol": C.gold, "vsub": "dureza similar · pulido mutuo", "cede": "ambos por igual",
			"scratched": "faint", "sev": sev, "layer": null,
		}
	if depth_um < 1.0:
		return {
			"verdict": "RAYA LEVE", "vcol": C.gold, "vsub": "microrraya con astillado incipiente" if brittle else "surco incipiente",
			"cede": "%s (leve)" % name, "scratched": "faint", "sev": sev, "layer": null,
		}
	return {
		"verdict": "RAYA", "vcol": C.coral, "vsub": "surco con microfractura (astillado lateral)" if brittle else "surco plástico claro",
		"cede": name, "scratched": true, "sev": sev, "layer": null,
	}
