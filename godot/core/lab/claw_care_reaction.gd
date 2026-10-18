## Tribología biológica · cetrería: la reacción del animal estresado y lo que su zarpazo le hace a la lente de la cámara
## (unidad 5t-A; peticiones 61 y 62 de Eric, 12 y 13-10-2026). Sin nodos, determinista y sin variables estáticas
## mutables. Guía y tabla valor → fuente → tipo: docs/fisica/cetreria.md §11.14.
##
## La cámara de la escena es una lente que depende del nivel del veterinario: plástico (metacrilato), vidrio óptico crown
## (N-BK7), vidrio de aluminosilicato templado químicamente y cristal de zafiro (LENSES). Si el animal se estresa de verdad
## (el umbral de REACTION, con la sujeción que no basta para su especie: claw_care_patient.gd), se revuelve y lanza la pata
## hacia la cámara; lens_hit() dice, garra a garra, qué le pasa a la lente puesta, con el motor del banco de siempre:
##   - rayar exige que la garra sea más dura que la lente: r = H_garra/H_lente ≥ 1,25, el umbral de la marca de verdad del
##     motor (Richardson 1968; el criterio de Pintaude, r ≳ 1,2). Por debajo, la garra solo deja una mancha (y un metal más
##     blando, su trazo, como los cubiertos de acero en la loza);
##   - la hondura y la anchura del rayón salen de Physics.compute() rayando la lente con la garra (su material, su punta
##     con el afilado de ahora y la fuerza con que aprieta): χ = P/H, el contacto plástico y el grado de penetración Dp de
##     Hokkirigawa y Kato (arado → rayón fino, cuña → rayón hondo, corte → desgarro en el plástico);
##   - la fuerza con que aprieta cada garra: la del animal asustado del coche en marcha (MovingCar.defense_force: el agarre
##     medido de las aves, los flexores de las garras del tigre y del oso; cota alta) por la intensidad de la reacción;
##   - la lente se raja si la fuerza de pico la flexa hasta su resistencia (Physics.pane_break: placa circular apoyada de
##     Roark, como la hoja de vidrio del banco); en el tigre, el oso y el velocirraptor, con el golpe del banco
##     (F = v·√(m·k_ef), la pata en serie con la lente); en las rapaces, sin la velocidad del vuelo (la pata empuja desde
##     parada), con la suma de lo que aprietan sus garras;
##   - una garra frágil (strass, Swarovski, cuarzo, zafiro…) puede desconcharse con la fuerza lateral μ·F
##     (ClawFracture.evaluate: la garra como viga en voladizo); una de metal se dobla, no se desconcha.
## Unidades: N · mm · µm · HV · MPa · GPa.
## Uso: const Reaction = preload("res://core/lab/claw_care_reaction.gd")
##      var hit := Reaction.lens_hit("vidrio", { "animal": "rapaz", "claw": "aguila", "inlay": "zafiro" })
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Data = preload("res://core/lab/data.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const MovingCar = preload("res://core/lab/moving_car.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

# ════════════════════════════════ La reacción ════════════════════════════════

## Cuándo se revuelve el animal (lo lee claw_care_patient.gd). Es una probabilidad (petición de Eric del 17-10: «cuantos más
## errores cometas, más posibilidades tienes de que el animal, estresado, te ataque»): cada roll_s el animal «tira el dado»
## con la probabilidad de chance(), que es 0 por debajo de low (el «inquieto» de la barra, CareData.ANIMAL_RISK.restless),
## crece con el estrés que dejan los errores (cada dolor lo sube) y llega a la movilidad entera con el estrés al máximo.
## threshold: el «estresado» de la barra (CareData.ANIMAL_RISK.stressed), donde la intensidad empieza a subir; warn_s: lo que
## dura la postura de amenaza antes del zarpazo, para poder parar a tiempo (s del reloj del ensayo); gap_s: lo que pasa como
## mucho entre dos reacciones. Solo con una sujeción que no basta para su especie (mobility > 0).
const REACTION := {
	"low": CareData.ANIMAL_RISK["restless"], "threshold": CareData.ANIMAL_RISK["stressed"], "roll_s": 2.0, "exponent": 1.5,
	"warn_s": 2.0, "gap_s": 20.0, "quality": "estimate",
	"source": "índice pedagógico del simulador, sin medición: el animal puede revolverse cuando su estrés pasa de «inquieto» y la sujeción no basta para su especie, y es más probable cuanto más estresado está; una rapaz sin sujetar puede «clavar» al que la maneja (Samour 2006, pp. 916-917) y a un tigre o a un oso solo se le tocan las garras anestesiado (Cat Tales 2024; Animals Asia). La probabilidad (una tirada cada 2 s, con la curva de exponente 1,5), el aviso de 2 s (la postura de amenaza) y una reacción cada 20 s como mucho son reglas del juego",
}
## Recoger al animal que se ha soltado (ClawCareState.recapture): la probabilidad de llevarse un zarpazo al cogerlo, que
## puede marcar la lente puesta (petición de Eric del 18-10-2026). Regla del juego.
const RECAPTURE := {
	"chance": 0.4, "quality": "juego",
	"source": "regla del juego (Eric Valls Gramunt, 18-10-2026): al recoger una rapaz que se ha soltado puede clavar las garras al que la coge (Samour 2006, pp. 916-917); el 40 % es del juego, sin medición",
}
## Lo que puede moverse el animal con cada sujeción que NO basta para su especie (0-1, índice de juego): suelto, del todo;
## sedado sin la anestesia que pide un animal grande, poco (un dolor fuerte lo despierta: CareData.SEDATION.sedacion); una
## toalla no sujeta a un tigre. Con la que basta (adequate_for), 0: no reacciona.
const MOBILITY := { "libre": 1.0, "sujecion": 1.0, "sedacion": 0.35, "anestesia": 0.0, "quality": "juego" }
## Lo que aún puede moverse con la sujeción que SÍ basta para su especie (petición de Eric del 17-10: «incluso un animal
## sedado, si sufre mucho estrés y daños, también podría atacar, pero casi ni casi anestesiado»): poco encapuchada, menos
## sedada y casi nada anestesiado; y solo con un dolor fuerte (pain_gate). Índice de juego.
const RESIDUAL := {
	"sujecion": 0.10, "sedacion": 0.05, "anestesia": 0.001, "pain_from": 0.5, "quality": "juego",
	"source": "regla del juego: un dolor fuerte despierta a un animal sedado (CareData.SEDATION.sedacion) y una rapaz encapuchada aún puede clavar las garras si le hacen daño (Samour 2006, pp. 916-917); con anestesia general no se mueve, salvo un plano anestésico demasiado ligero",
}
## La pausa para calmarlo (los métodos de relajación): mientras se le deja tranquilo (sin tocarlo, y la rapaz encapuchada y
## en penumbra), el estrés baja tanto por segundo según su sujeción; no se revuelve porque nadie le toca las garras. Juego.
const CALM := {
	"libre": 0.008, "sujecion": 0.02, "sedacion": 0.03, "anestesia": 0.05, "quality": "juego",
	"source": "índice pedagógico del simulador: a oscuras y encapuchada una rapaz se calma (Samour 2006, p. 916); con un gran carnívoro, distancia, silencio y tiempo, o más sedación (Cat Tales 2024). Las velocidades son reglas del juego",
}
## La intensidad de la reacción (0-1, índice de juego): la movilidad por lo que pasa del umbral; nunca menos de INTENSITY_MIN.
const INTENSITY_MIN := 0.25

## Cómo reacciona cada animal (la clave «kind» del contrato con la escena): «rapaz» (águila, arpía, halcón, buitre),
## «nocturna» (búho y lechuza), «felino» (tigre), «oso» y «dinosaurio» (velocirraptor).
const KINDS := ["rapaz", "nocturna", "felino", "oso", "dinosaurio"]
const NOCTURNAL := ["buho", "lechuza"]


## El tipo de reacción de un animal de la cetrería (CareData.ANIMAL_IDS) con la garra del banco claw_id.
static func kind_of(animal: String, claw_id: String = "") -> String:
	match animal:
		"tigre":
			return "felino"
		"oso":
			return "oso"
		"velociraptor":
			return "dinosaurio"
	return "nocturna" if claw_id in NOCTURNAL else "rapaz"


## ¿Basta esa sujeción para la especie? La que pide (CareData.ANIMALS[…].restraint) o más fuerte: a la rapaz le basta la
## capucha y la toalla (o sedarla, o anestesiarla); al tigre, al oso y al velocirraptor, solo la anestesia general.
static func adequate_for(animal: String, sedation: String) -> bool:
	var need := String((CareData.ANIMALS.get(animal, CareData.ANIMALS.rapaz) as Dictionary).restraint)
	var order := ["libre", "sujecion", "sedacion", "anestesia"]
	if need == "anestesia":
		return sedation == "anestesia"
	return order.find(sedation) >= order.find(need)


## Lo que puede moverse con esa sujeción (0-1, MOBILITY); con la que basta para su especie, solo el resto de RESIDUAL.
static func mobility_of(animal: String, sedation: String) -> float:
	if adequate_for(animal, sedation):
		return float(RESIDUAL.get(sedation, 0.0))
	return float(MOBILITY.get(sedation, 1.0))


## Con la sujeción que basta, solo un dolor fuerte le hace revolverse: 0 por debajo de RESIDUAL.pain_from, 1 con el dolor
## máximo (0-1, regla de juego). Con la que no basta, siempre 1.
static func pain_gate(animal: String, sedation: String, pain: float) -> float:
	if not adequate_for(animal, sedation):
		return 1.0
	var a := float(RESIDUAL.pain_from)
	return clampf((pain - a) / maxf(1.0 - a, 1e-9), 0.0, 1.0)


## La probabilidad de que se revuelva en una tirada (0-1, regla de juego) con ese estrés y esa movilidad: 0 por debajo de
## REACTION.low, ((estrés − low)/(1 − low))^exponent·movilidad por encima (con el estrés al máximo, la movilidad entera: un
## animal suelto y al límite ataca en la primera tirada; uno sedado, como mucho un 35 % de las veces).
static func chance(stress: float, mobility: float) -> float:
	var low := float(REACTION.low)
	if mobility <= 0.0 or stress < low:
		return 0.0
	var x := clampf((stress - low) / maxf(1.0 - low, 1e-9), 0.0, 1.0)
	return clampf(V8.js_pow(x, float(REACTION.exponent)) * mobility, 0.0, 1.0)


## La intensidad de una reacción (0-1, índice de juego) con esa movilidad y ese estrés: de INTENSITY_MIN en el umbral a la
## movilidad entera con el estrés al máximo.
static func intensity_of(mobility: float, stress: float) -> float:
	var th := float(REACTION.threshold)
	var over := clampf((stress - th) / maxf(1.0 - th, 1e-9), 0.0, 1.0)
	return clampf(mobility * (0.5 + 0.5 * over), INTENSITY_MIN, 1.0) if mobility > 0.0 else 0.0


# ════════════════════════════════ Las lentes ════════════════════════════════

const SRC_SCHOTT := "SCHOTT, ficha técnica del vidrio óptico N-BK7: dureza Knoop HK0,1/20 = 610, módulo de Young 82 GPa y Poisson 0,206 (valores orientativos a temperatura ambiente)"
const SRC_PMMA := "el metacrilato (PMMA) de la uña de acrílico del banco: ~23,6 HV y un módulo de 2,4-3,3 GPa en la literatura de resinas (se toman 22 HV y 3 GPa)"
const SRC_PMMA_FLEX := "60 MPa, el mínimo de la ISO 20795-1 para las resinas acrílicas autopolimerizables (tipo 2), dentro de lo medido en el PMMA autopolimerizable (42-86 MPa; Casucci et al. 2023): caso medido más parecido (el metacrilato de una lente es colado o inyectado)"
const SRC_EN12150 := "EN 12150-1 (vidrio templado): resistencia característica a flexión de 120 MPa (vía Saint-Gobain 2018), la de la ventanilla del banco: caso medido más parecido, cota baja (el templado químico, con hasta 1000 MPa de compresión en la cara, aguanta más)"
const SRC_WINDOW := "estimación: la ventana de delante de la cámara, como el puerto de una carcasa, de 40 mm de diámetro (radio de 20 mm) y 4 mm de espesor, la misma en las cuatro lentes para poder compararlas; el radio entra en el logaritmo de Roark y el espesor al cuadrado"
const SRC_ROARK := "placa circular apoyada con la carga en el centro (Young & Budynas 2002, Roark; radio equivalente de Westergaard), la hoja de vidrio del banco"
const SRC_NU_PMMA := "Poisson de 0,37, valor de manual del PMMA (estimación)"
const SRC_MU := "rozamiento de la pareja: el del material del banco más parecido (plástico ABS 0,4; vidrio 0,6; zafiro 0,4)"

## Cuatro lentes, una por nivel del veterinario (la 5u las vende). Cada una con la forma de un objetivo del banco
## (Data.TARGETS: hv, E, mu, W, brittle, pane, frac), que es lo que recibe Physics.compute(), y sus datos con su fuente en
## «data» (hv, E, strength, window, mu). pane: la ventana como placa de Roark (t y a en mm, fgk en MPa); frac: los datos de
## fractura de los frágiles (Fracture.BRITTLE).
const LENS_IDS := ["plastico", "vidrio", "vidrio_templado", "zafiro"]
const LENSES := {
	"plastico": {
		"id": "plastico", "level": 1, "name": "Lente de plástico (metacrilato)", "short": "Plástico", "material": "metacrilato (PMMA)",
		"hv": 22.0, "E": 3.0, "mohs": 3.0, "mu": 0.4, "W": 0.04, "brittle": false, "polymer": true, "col": "#E8EEF2",
		"pane": { "t": 4.0, "a": 20.0, "fgk": 60.0, "nu": 0.37 },
		"data": {
			"hv": { "value": 22.0, "quality": "secondary", "source": SRC_PMMA },
			"E": { "value": 3.0, "quality": "secondary", "source": SRC_PMMA },
			"strength": { "value": 60.0, "quality": "estimate", "source": SRC_PMMA_FLEX },
			"nu": { "value": 0.37, "quality": "estimate", "source": SRC_NU_PMMA },
			"mu": { "value": 0.4, "quality": "estimate", "source": SRC_MU },
			"window": { "value": 4.0, "quality": "estimate", "source": SRC_WINDOW },
		},
		"quality": "estimate",
		"fact": "Barata y ligera, pero blanda (~22 HV): la raya cualquier garra, también la de queratina (~30 HV).",
	},
	"vidrio": {
		"id": "vidrio", "level": 2, "name": "Lente de vidrio óptico (crown N-BK7)", "short": "Vidrio", "material": "vidrio óptico crown (N-BK7)",
		"hv": 610.0, "E": 82.0, "mohs": 5.5, "mu": 0.6, "W": 0.03, "brittle": true, "polymer": false, "col": "#DDF2F0",
		"pane": { "t": 4.0, "a": 20.0, "fgk": 45.0, "nu": 0.206 },
		"frac": Fracture.BRITTLE["vidrio"],
		"data": {
			"hv": { "value": 610.0, "quality": "estimate", "source": SRC_SCHOTT + ". La dureza Knoop se toma como Vickers: en los vidrios son del mismo orden (estimación)" },
			"E": { "value": 82.0, "quality": "secondary", "source": SRC_SCHOTT },
			"strength": { "value": 45.0, "quality": "estimate", "source": "caso medido más parecido: el vidrio recocido de la norma (" + ClawFracture.SRC_EN572 + "); el N-BK7 es un vidrio de silicato recocido y su resistencia la marcan los defectos de la cara" },
			"nu": { "value": 0.206, "quality": "secondary", "source": SRC_SCHOTT },
			"mu": { "value": 0.6, "quality": "estimate", "source": SRC_MU },
			"window": { "value": 4.0, "quality": "estimate", "source": SRC_WINDOW },
		},
		"quality": "estimate",
		"fact": "Vidrio de silicato (~610 HV): la queratina, el oro, el acero y el titanio no lo rayan; del cuarzo para arriba, sí. Un golpe fuerte lo raja.",
	},
	"vidrio_templado": {
		"id": "vidrio_templado", "level": 3, "name": "Lente de vidrio templado (aluminosilicato)", "short": "Templado",
		"material": "vidrio de aluminosilicato templado químicamente",
		"hv": 649.0, "E": 72.0, "mohs": 6.5, "mu": 0.6, "W": 0.03, "brittle": true, "polymer": false, "col": "#D6ECF4",
		"pane": { "t": 4.0, "a": 20.0, "fgk": 120.0, "nu": 0.21 },
		"frac": Fracture.BRITTLE["movil"],
		"data": {
			"hv": { "value": 649.0, "quality": "secondary", "source": String(Fracture.BRITTLE["movil"]["source"]) },
			"E": { "value": 72.0, "quality": "secondary", "source": "el de la pantalla de móvil del banco (aluminosilicato reforzado, 72 GPa)" },
			"strength": { "value": 120.0, "quality": "estimate", "source": SRC_EN12150 },
			"nu": { "value": 0.21, "quality": "secondary", "source": String(Fracture.BRITTLE["movil"]["source"]) },
			"mu": { "value": 0.6, "quality": "estimate", "source": SRC_MU },
			"window": { "value": 4.0, "quality": "estimate", "source": SRC_WINDOW },
		},
		"quality": "estimate",
		"fact": "Raya como el vidrio óptico (~650 HV), pero el temple químico deja la cara comprimida: aguanta golpes mucho más fuertes sin rajarse.",
	},
	"zafiro": {
		"id": "zafiro", "level": 4, "name": "Lente de cristal de zafiro", "short": "Zafiro", "material": "cristal de zafiro (corindón)",
		"hv": 2000.0, "E": 400.0, "mohs": 9.0, "mu": 0.4, "W": 0.02, "brittle": true, "polymer": false, "col": "#D2E4F6",
		"pane": { "t": 4.0, "a": 20.0, "fgk": 760.0, "nu": 0.29 },
		"frac": Fracture.BRITTLE["zafiro"],
		"data": {
			"hv": { "value": 2000.0, "quality": "secondary", "source": "el cristal de zafiro del banco (corindón, ~2000 HV, valores de manual)" },
			"E": { "value": 400.0, "quality": "secondary", "source": "el cristal de zafiro del banco (400 GPa, valor de manual)" },
			"strength": { "value": 760.0, "quality": "secondary", "source": ClawFracture.SRC_SAPPHIRE + " (se toma la menor)" },
			"nu": { "value": 0.29, "quality": "estimate", "source": String(Fracture.BRITTLE["zafiro"]["source"]) },
			"mu": { "value": 0.4, "quality": "estimate", "source": SRC_MU },
			"window": { "value": 4.0, "quality": "estimate", "source": SRC_WINDOW },
		},
		"quality": "estimate",
		"fact": "El de las tapas de cámara de los móviles (~2000 HV): solo lo rayan la moissanita y el diamante, y no hay zarpazo que lo raje.",
	},
}


## La lente id (copia), o la de plástico si no existe.
static func lens(id: String) -> Dictionary:
	return (LENSES.get(id, LENSES.plastico) as Dictionary).duplicate(true)


## La lente como objetivo del banco (la forma de Data.TARGETS) para Physics.compute(): id, name, hv, E, mohs, col, mu, W,
## brittle y, en los frágiles, pane y frac.
static func lens_target(id: String) -> Dictionary:
	var L := lens(id)
	var t := { "id": "lente_" + String(L.id), "name": String(L.name), "hv": float(L.hv), "E": float(L.E), "mohs": L.mohs,
		"col": String(L.col), "mu": float(L.mu), "W": float(L.W) }
	if bool(L.brittle):
		t["brittle"] = true
		t["frac"] = L.frac
	return t


## Las garras de Catalog.INLAYS (los materiales de la reforja, con la queratina) que rayan la lente id con el criterio del
## motor (r ≥ R_SCRATCH), para la tienda de la 5u: [{ id, name, hv, ratio }] de la más blanda a la más dura; la queratina
## de las garras del banco (~26-33 HV) va como «none».
static func scratched_by(id: String) -> Array:
	var hv := float(lens(id).hv)
	var out: Array = []
	for e: Dictionary in Catalog.INLAYS:
		var mat_hv := KERATIN_HV if String(e.id) == "none" else float(e.hv)
		if mat_hv / hv >= R_SCRATCH:
			out.append({ "id": String(e.id), "name": "queratina" if String(e.id) == "none" else String(e.name), "hv": mat_hv, "ratio": mat_hv / hv })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.hv) < float(b.hv))
	return out


## La carga (N) con la que se raja la lente id con el contacto de radio r0_mm (Physics.pane_break, Roark), y su rigidez
## en el centro (N/mm): { F, k, U }.
static func lens_break(id: String, r0_mm: float = 0.0) -> Dictionary:
	var L := lens(id)
	return Physics.pane_break(L.pane, float(L.E), r0_mm)


# ════════════════════════════════ El zarpazo contra la lente ════════════════════════════════

## El umbral de la marca de verdad del motor (Physics: «MARCA TENUE» por debajo; Richardson 1968, el criterio de Pintaude
## r ≳ 1,2).
const R_SCRATCH := 1.25
## Por debajo de esta hondura (µm) no queda surco (el «roza sin marcar» del motor).
const MARK_UM := 0.05
## La dureza de la queratina de las garras para scratched_by (la más alta del banco, la del águila arpía).
const KERATIN_HV := 33.0
## El largo del zarpazo sobre la lente (mm): de lado a lado de la ventana de 40 mm, menos un poco (dibujo).
const SWIPE_MM := 32.0
## Las garras que tocan la lente en el zarpazo, en el orden de los dedos de la pata: las rapaces y las nocturnas, los
## cuatro dedos (el I detrás; en las nocturnas, el IV también, zigodáctilas); el tigre, cuatro (el I, el espolón, no
## llega al suelo: la huella marca cuatro dedos); el oso, cinco; el velocirraptor, la hoz del dedo II y, si llegan, el III
## y el IV.
const FINGERS := {
	"rapaz": ["I", "II", "III", "IV"], "nocturna": ["I", "II", "III", "IV"], "felino": ["II", "III", "IV", "V"],
	"oso": ["I", "II", "III", "IV", "V"], "dinosaurio": ["II", "III", "IV"],
}
const FINGERS_SOURCE := "las huellas medidas: el tigre marca cuatro dedos (McDougal 1999, vía Sharma et al. 2003) y el oso pardo cinco (Mattson 2003); las rapaces, cuatro dedos con el I detrás, y las nocturnas, zigodáctilas (Samour 2006; Arent & Pollock); el velocirraptor ataca con la hoz del dedo II (Manning et al. 2006)"
## El dedo que llega primero (el del golpe y, si se raja la lente, el de la grieta): el I de las rapaces, el más grande; el
## III, el del medio, en el tigre y el oso; la hoz en el velocirraptor.
const IMPACT_FINGER := { "rapaz": "I", "nocturna": "I", "felino": "III", "oso": "III", "dinosaurio": "II" }
## Los dedos III y IV del velocirraptor llegan a la lente solo con un zarpazo de esta intensidad o más (regla del juego).
const DINO_SIDE_REACH := 0.5
## Los resultados, de menos a más grave (el global es el peor).
const OUTCOMES := ["nada", "mancha", "rayon", "rayon_hondo", "desgarro", "grieta"]
const OUTCOME_NAMES := {
	"nada": "no la toca", "mancha": "solo una mancha", "rayon": "un rayón fino", "rayon_hondo": "un rayón hondo",
	"desgarro": "un desgarro", "grieta": "una grieta",
}


## Lo peligroso que es un animal para la lente (petición de Eric del 17-10: «cada animal tiene su forma y tipo de garras,
## algunas más peligrosas que otras»): el zarpazo con más fuerza (intensidad 1) de sus garras naturales contra cada una de
## las cuatro lentes, con lens_hit (la física de siempre: dureza, fuerza de defensa y rotura de la ventana). No es un número
## nuevo: rank cuenta las lentes que daña (las raya o las raja: de 0, ninguna, a 4, todas) y worst es lo peor que le hace a
## la más blanda. Devuelve { animal, claw, rank (0-4), level (DANGER_LEVELS[rank]), lenses: { id: { outcome,
## text, cracked, scratches } }, text, source, quality }.
const DANGER_LEVELS := ["mínimo", "bajo", "medio", "alto", "muy alto"]
const DANGER_NAMES := { "plastico": "plástico", "vidrio": "vidrio", "vidrio_templado": "vidrio templado", "zafiro": "zafiro" }


## inlay y fingers (opcionales, como en lens_hit): el material de las garras y las de ahora, con su material y el radio de
## su punta (petición de Eric del 18-10: «cuanto más afilada esté una garra, más peligrosa puede ser para la lente»). Sin
## ellos, las garras naturales del animal.
static func danger_of(animal: String, claw_id: String = "", inlay: String = "none", fingers: Array = []) -> Dictionary:
	var lenses := {}
	var rank := 0
	var src := ""
	var q := "estimate"
	for id: String in LENS_IDS:
		var h := lens_hit(id, { "animal": animal, "claw": claw_id, "inlay": inlay, "fingers": fingers, "intensity": 1.0 })
		var hurt := bool(h.cracked) or int(h.scratches) > 0
		if hurt:
			rank += 1
		lenses[id] = { "outcome": String(h.outcome), "text": String(OUTCOME_NAMES[String(h.outcome)]), "cracked": bool(h.cracked), "scratches": int(h.scratches) }
		src = String(h.source)
		q = String(h.quality)
	var level := String(DANGER_LEVELS[rank])
	var cracks: Array = []
	var scrs: Array = []
	for id: String in LENS_IDS:
		var e: Dictionary = lenses[id]
		if bool(e.cracked):
			cracks.append(String(DANGER_NAMES[id]))
		elif int(e.scratches) > 0:
			scrs.append(String(DANGER_NAMES[id]))
	var parts: Array = []
	if not scrs.is_empty():
		parts.append("raya %s %s" % ["la de" if scrs.size() == 1 else "las de", _join_es(scrs)])
	if not cracks.is_empty():
		parts.append("raja %s %s" % ["la de" if cracks.size() == 1 else "las de", _join_es(cracks)])
	var t := "Peligro para la lente: %s. " % level
	t += ("Un zarpazo con toda su fuerza %s." % " y ".join(parts)) if not parts.is_empty() else "Ni con toda su fuerza raya ni raja ninguna lente: como mucho, una mancha."
	# con las garras de ahora: la punta más fina (una punta más fina raya más hondo: Hokkirigawa y Kato, el mismo motor)
	var sharpest := INF
	for f: Variant in fingers:
		if f is Dictionary and (f as Dictionary).has("tip_um"):
			sharpest = minf(sharpest, float((f as Dictionary).tip_um))
	if sharpest < INF:
		var cl := CareData.claw_entry(claw_id)
		var nat := ClawSharpness.radius_um_of_area(float(cl.get("area", 0.0))) if not cl.is_empty() else 0.0
		if nat > 0.0 and sharpest < 0.75 * nat:
			t += " Sus garras están más afiladas que las naturales (la más fina, %s µm frente a %s): cuanto más fina la punta, más hondo el rayón." % [Js.to_fixed(sharpest, 0), Js.to_fixed(nat, 0)]
		elif nat > 0.0 and sharpest > 1.5 * nat:
			t += " Sus garras están romas (la más fina, %s µm frente a %s): rayan menos hondo." % [Js.to_fixed(sharpest, 0), Js.to_fixed(nat, 0)]
	return { "animal": animal, "claw": claw_id, "inlay": inlay, "sharpestUm": sharpest if sharpest < INF else 0.0, "rank": rank, "level": level, "lenses": lenses, "text": t, "source": src, "quality": q }


## «a», «a y b», «a, b y c».
static func _join_es(items: Array) -> String:
	if items.size() <= 1:
		return "".join(items)
	return ", ".join(items.slice(0, items.size() - 1)) + " y " + String(items[-1])


## Lo que le hace a la lente id el zarpazo del animal. hit: { animal (CareData.ANIMAL_IDS), claw (la garra del banco: aguila,
## tigre…; sin ella, la de su ficha), inlay (el material de las garras: «none» la queratina), intensity (0-1, la de la
## reacción; 1 por defecto), fingers (opcional: [{ finger, inlay, tip_um }], las garras que tocan con su material y el radio
## de su punta de ahora, µm; las que falten, con el inlay del animal y la punta natural de su garra) }.
## Devuelve { lens, lensName, kind, claw, outcome (el peor), marks (las garras que la tocan), scratches (las que la rayan),
## spacingMm (la separación de los dedos, dibujo), claws: [{ finger, outcome, widthUm, depthUm, lengthMm, chips, material,
## forceN, tipUm, ratio, mode, transfer, scratched, scratch }], cracked, crackFinger, peakN, crackN, strikeN, intensity, forceN,
## reason, source, quality }. En claws, outcome es lo que deja esa garra («grieta» en la del golpe si la lente se raja,
## aunque además la raye: scratched, y scratch el rayón que deja: «rayon», «rayon_hondo», «desgarro» o «»), widthUm y
## depthUm los del surco (0 si no raya), lengthMm lo largo del rayón, chips si
## la garra se desconcha y transfer el metal que deja su trazo sin rayar («oro», «acero», «titanio» o «»; dibujo).
static func lens_hit(lens_id: String, hit: Dictionary) -> Dictionary:
	var L := lens(lens_id)
	var target := lens_target(String(L.id))
	var animal := String(hit.get("animal", "rapaz"))
	if not CareData.ANIMALS.has(animal):
		animal = "rapaz"
	var claw_id := String(hit.get("claw", (CareData.ANIMALS[animal] as Dictionary).claw))
	var claw := CareData.claw_entry(claw_id)
	if claw.is_empty():
		claw_id = String((CareData.ANIMALS[animal] as Dictionary).claw)
		claw = CareData.claw_entry(claw_id)
	var kind := kind_of(animal, claw_id)
	var intensity := clampf(float(hit.get("intensity", 1.0)), 0.0, 1.0)
	var base_inlay := String(hit.get("inlay", "none"))
	var given := {}
	for f: Variant in hit.get("fingers", []):
		if f is Dictionary:
			given[String((f as Dictionary).get("finger", ""))] = f
	# la fuerza con que aprieta cada garra: la del animal asustado (cota alta) por la intensidad
	var df: Variant = MovingCar.defense_force(claw)
	var per_claw := float(df.perClaw.value) if df != null else float(claw.get("force", 0.0)) / float((FINGERS[kind] as Array).size())
	var f_src := String(df.source) if df != null else "la fuerza de la ficha del banco repartida entre sus garras (estimación)"
	var f_q := String(df.quality) if df != null else "estimate"
	var fingers: Array = FINGERS[kind]
	var r0_um := ClawSharpness.radius_um_of_area(float(claw.area))
	var claws: Array = []
	var forces := 0.0
	for fid: String in fingers:
		var g: Dictionary = given.get(fid, {})
		var reach := intensity >= DINO_SIDE_REACH or kind != "dinosaurio" or fid == "II"
		var inl := String(g.get("inlay", base_inlay))
		var tip_um := maxf(float(g.get("tip_um", r0_um)), ClawSharpness.SHARPEST_UM)
		var f_n := per_claw * intensity if reach else 0.0
		forces += f_n
		claws.append(_claw_on_lens(fid, claw, inl, tip_um, f_n, target, L))
	# ¿se raja? La fuerza de pico contra la carga de rotura de la ventana (Roark): el golpe de la pata (tigre, oso,
	# velocirraptor) o, en las rapaces, lo que aprietan sus garras a la vez
	var strike_n := 0.0
	var pb := lens_break(String(L.id), 0.0)
	if kind in ["felino", "oso", "dinosaurio"]:
		var st: Dictionary = claw.get("strike", {})
		var k_eff := 1.0 / (1.0 / float(pb.k) + 1.0 / float(Physics.MODEL.limbStiffness))
		strike_n = intensity * float(st.get("v", 0.0)) * sqrt(float(st.get("m", 0.0)) * k_eff * 1000.0)
	var peak := maxf(forces, strike_n)
	var cracked := peak >= float(pb.F) and peak > 0.0
	var impact := String(IMPACT_FINGER[kind])
	if cracked:
		for c: Dictionary in claws:
			if String(c.finger) == impact:
				c["outcome"] = "grieta"
	# lo global: el peor resultado, cuántas garras la tocan y la rayan
	var worst := "nada"
	var marks := 0
	var scratches := 0
	for c: Dictionary in claws:
		if OUTCOMES.find(String(c.outcome)) > OUTCOMES.find(worst):
			worst = String(c.outcome)
		if String(c.outcome) != "nada":
			marks += 1
		if bool(c.scratched):
			scratches += 1
	var body: Variant = MovingCar.body_of(claw)
	var span := 60.0
	if body is Dictionary:
		span = float((body as Dictionary).get("paw_mm", 2.0 * float((body as Dictionary).get("contact_mm", 30.0))))
	var data: Dictionary = L.data
	var src := "%s. Lente: %s; resistencia, %s; la ventana, %s. Rayar: el motor del banco con r ≥ 1,25 (Richardson 1968; Pintaude) y el grado de penetración de Hokkirigawa y Kato. La fuerza de cada garra: %s. Rajarse: %s" % [
		String(L.name), String(data.hv.source), String(data.strength.source), String(data.window.source), f_src, SRC_ROARK]
	var out := {
		"lens": String(L.id), "lensName": String(L.name), "kind": kind, "claw": claw_id, "animal": animal, "outcome": worst,
		"marks": marks, "scratches": scratches, "spacingMm": span / float(maxi(fingers.size(), 1)), "spacingQuality": "dibujo",
		"claws": claws, "cracked": cracked, "crackFinger": impact if cracked else "", "peakN": peak, "crackN": float(pb.F),
		"strikeN": strike_n, "intensity": intensity, "forceN": per_claw * intensity, "forceQuality": f_q,
		"reason": "", "source": src, "quality": _weakest(["estimate", f_q]),
	}
	out["reason"] = _reason(out, L, claw)
	return out


## Una garra contra la lente: el motor del banco rayando la lente con ella (Physics.compute, modelo 2.0, de punta: 90°).
static func _claw_on_lens(fid: String, claw: Dictionary, inlay_id: String, tip_um: float, f_n: float, target: Dictionary, L: Dictionary) -> Dictionary:
	var inl: Variant = material_entry(inlay_id)
	var reforged := String((inl as Dictionary).id) != "none"
	var mat_hv := float((inl as Dictionary).hv) if reforged else float(claw.hv)
	var ratio := mat_hv / float(L.hv)
	var out := { "finger": fid, "outcome": "nada", "widthUm": 0.0, "depthUm": 0.0, "lengthMm": 0.0, "chips": false,
		"material": String((inl as Dictionary).id), "forceN": f_n, "tipUm": tip_um, "ratio": ratio, "mode": "", "transfer": "",
		"scratched": false, "scratch": "" }
	if f_n <= 0.0:
		return out
	out["outcome"] = "mancha"
	# un metal más blando que la lente que resbala por ella deja su trazo (como los cubiertos en la loza): dibujo
	if reforged and ratio < R_SCRATCH and String((inl as Dictionary).id) in ClawFracture.DUCTILE:
		out["transfer"] = String((inl as Dictionary).id)
	var c := claw.duplicate(true)
	c["area"] = ClawSharpness.area_of_radius_um(tip_um)
	var p := {
		"claw": c, "inlay": inl, "target": target, "force": f_n, "length": SWIPE_MM, "type": Data.TYPES[1], "tear": false,
		"method": "rayado", "strike": false, "passes": 1.0, "wet": false, "model": Physics.MODEL_V2, "attack_deg": 90.0,
		"base": Data.BASES[0], "geom": Data.GEOMS[0],
	}
	var r := Physics.compute(p)
	var brittle := bool(L.brittle)
	var depth := float(r.depthUm) if brittle else float(r.residualDepthUm)
	var width := float(r.get("grooveWidthUm", 0.0))
	# la garra frágil puede desconcharse con la fuerza lateral μ·F, cargada en el centro de lo que entra en la lente
	var tip := Contact.tip_geometry(float(c.area), float(c.alpha), float(Physics.MODEL.clawBase) * float(c.reach))
	var cf: Variant = ClawFracture.evaluate(inl, tip, float(c.reach), f_n, float(L.mu), 0.5 * float(r.depthUm) / 1000.0) if reforged else null
	out["chips"] = cf != null and bool((cf as Dictionary).get("breaks", false))
	if ratio < R_SCRATCH or depth < MARK_UM:
		return out
	var mode := String(r.absMode) if r.absMode != null else "arado"
	out["mode"] = mode
	out["scratched"] = true
	out["depthUm"] = depth
	out["widthUm"] = width
	match mode:
		"corte":
			out["outcome"] = "desgarro" if bool(L.polymer) else "rayon_hondo"
		"cuña":
			out["outcome"] = "rayon_hondo"
		_:
			out["outcome"] = "rayon"
	# atraviesa la ventana: en el plástico, un desgarro
	if bool(L.polymer) and depth >= float(L.pane.t) * 1000.0:
		out["outcome"] = "desgarro"
	out["scratch"] = out.outcome
	# el largo del rayón: la parte del zarpazo en que la garra aprieta más de lo que pide marcar la lente (la carga sube y
	# baja como medio seno; por debajo de la cesión de Hertz, Johnson 1985, el contacto es elástico y no deja surco)
	var f_on := ClawSharpness.yield_onset_n(tip_um, float((inl as Dictionary).E) if reforged else float(claw.E), float(L.E), float(L.hv) * Contact.HV_MPA)
	var x := clampf(f_on / f_n, 0.0, 1.0)
	out["lengthMm"] = SWIPE_MM * (1.0 - 2.0 / PI * V8.js_atan2(x, sqrt(maxf(1.0 - x * x, 0.0))))
	return out


## Los materiales femeninos (el artículo de los textos: «la queratina», «el acero»).
const FEMININE := ["none", "hematites", "circonita", "moissanita", "alumina"]


## «la queratina», «el acero», «el strass (vidrio)»: el material id con su artículo (solo texto).
static func material_phrase(id: String) -> String:
	if id == "none":
		return "la queratina"
	var nm := String(ClawFracture.NOUNS.get(id, String(material_entry(id).get("name", id)).to_lower()))
	return ("la " if id in FEMININE else "el ") + nm


## El material de una garra con la forma de Data.INLAYS (hv, E…): los del banco (Catalog.INLAYS), el acrílico de la prótesis
## de verdad (ForgeData.PROSTHESIS) o la resina compuesta (CareData.RESIN); lo que no se conoce, la queratina («none»).
static func material_entry(id: String) -> Dictionary:
	var e: Variant = Catalog.find_by_id(Catalog.INLAYS, id)
	if e == null:
		e = ForgeData.prosthesis_entry(id)
	if e == null and id == String(CareData.RESIN.id):
		e = CareData.RESIN
	return (e if e is Dictionary else Catalog.INLAYS[0]) as Dictionary


## La explicación del resultado, con los números del motor: si raya o solo mancha (y por qué), si se raja, si se desconcha
## la garra y el trazo de un metal.
static func _reason(o: Dictionary, L: Dictionary, claw: Dictionary) -> String:
	var claws: Array = o.claws
	var touching := claws.filter(func(c: Dictionary) -> bool: return String(c.outcome) != "nada")
	if touching.is_empty():
		return "El zarpazo no llega a la lente."
	var first: Dictionary = touching[0]
	var mat_id := String(first.get("material", "none"))
	var mat_hv := float(material_entry(mat_id).hv) if mat_id != "none" else float(claw.hv)
	var mat := material_phrase(mat_id)
	var lens_name := String(L.short).to_lower()
	var parts: Array = []
	if int(o.scratches) == 0:
		parts.append("%s, a ~%s HV, no raya una lente de %s de ~%s HV: rayar pide una garra al menos 1,25 veces más dura que la lente. Solo deja una mancha de grasa o polvo, que se limpia con el paño." % [
			mat.substr(0, 1).to_upper() + mat.substr(1), Js.to_fixed(mat_hv, 0), lens_name, Js.to_fixed(float(L.hv), 0)])
	else:
		var deepest := {}
		var n := 0
		for c: Dictionary in claws:
			if bool(c.scratched):
				n += 1
				if deepest.is_empty() or float(c.depthUm) > float(deepest.depthUm):
					deepest = c
		parts.append("Con %s (~%s HV), las garras rayan la lente de %s (~%s HV): %d %s, el más hondo de %s y %s de ancho." % [
			mat, Js.to_fixed(mat_hv, 0), lens_name, Js.to_fixed(float(L.hv), 0), n, "rayón" if n == 1 else "rayones",
			Format.fmt_depth(float(deepest.get("depthUm", 0.0))), Format.fmt_depth(float(deepest.get("widthUm", 0.0)))])
		if claws.any(func(c: Dictionary) -> bool: return String(c.outcome) == "desgarro"):
			parts.append("Con la punta afilada cortan el plástico (el grado de penetración pasa de 0,2): lo desgarran.")
	if bool(o.cracked):
		parts.append("El golpe da un pico de ~%s y la ventana de %s mm se raja desde ~%s (flexión de una placa apoyada, Roark)." % [
			force_text(float(o.peakN)), Js.js_num_str(float(L.pane.t)), force_text(float(o.crackN))])
	var chipped := claws.filter(func(c: Dictionary) -> bool: return bool(c.chips))
	if not chipped.is_empty():
		parts.append("La garra de %s se ha desconchado contra la lente." % String(ClawFracture.NOUNS.get(String(chipped[0].material), String(chipped[0].material))))
	var metal := claws.filter(func(c: Dictionary) -> bool: return String(c.transfer) != "")
	if not metal.is_empty() and int(o.scratches) == 0:
		parts.append("%s, más blando, deja en ella un trazo de sí mismo." % (material_phrase(String(metal[0].transfer)).substr(0, 1).to_upper() + material_phrase(String(metal[0].transfer)).substr(1)))
	return " ".join(parts)


## La calidad más floja de una lista (primary > secondary > estimate).
static func _weakest(qs: Array) -> String:
	var order := ["primary", "secondary", "estimate"]
	var worst := "primary"
	for q: Variant in qs:
		if order.find(String(q)) > order.find(worst):
			worst = String(q)
	return worst


## Una fuerza legible para los textos de la lente: «540 N» o, desde 1000 N, «2.2 kN» (como el cortaúñas).
static func force_text(f: float) -> String:
	return ("%s kN" % Js.to_fixed(f / 1000.0, 1)) if f >= 1000.0 else ("%s N" % Format.fmt_f(f))
