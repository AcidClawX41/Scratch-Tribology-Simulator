## Tribología biológica · cetrería: el progreso del veterinario (unidad 5u; petición 62 de Eric, 13-10-2026): la experiencia y
## el nivel, los créditos del juego, los encargos de cuidado de garras y de reforja con lo que piden y lo que dan, las lentes de
## la cámara compradas, la puesta y el daño de cada una, y cómo se guarda todo en user://cetreria.cfg (un ConfigFile, como
## user://ajustes.cfg, con la versión del formato). Sin nodos y determinista (no lee el reloj).
## - Todo número de aquí es del juego (la experiencia, los niveles, los precios, los créditos y las recompensas): lleva
##   quality «juego» y nunca se presenta como física; los créditos son honorarios ficticios, nunca dinero real. Lo que piden
##   los encargos es la práctica veterinaria de verdad (la sujeción, la anestesia, la carne viva, el calor) y lleva su fuente.
## - Los datos de las lentes (el material, la dureza, qué garras las rayan y el daño acumulado) son físicos y los pone la
##   cetrería (core/lab/claw_care_reaction.gd, 5t-A, con los ids de LENS_IDS); aquí solo su nivel de la tienda, su precio y el
##   daño guardado tal como lo da su estado (to_dict()/from_dict(), con el índice «obscuration» de 0 a 1).
## - Los encargos se comprueban con el informe que ya hacen los motores, sin recalcular nada: el de la cetrería al terminar
##   (care_summary, desde ClawCareState.view(): el veredicto, la nota, la sangre, el calor, si se ha movido y la sujeción) y el
##   de la reforja (forge_summary, desde ClawForgeState.view(): el veredicto de la pieza, su material y, con la mesa de soldar,
##   su unión).
## - Educativo, no de juego duro: nunca se pierde lo hecho; el nivel no baja (best_level); un encargo hecho no se cobra dos
##   veces; los errores cuestan (restan de la recompensa), pero se explican; y la práctica libre (cada consulta terminada sin
##   peligro) da un poco, para que nunca haya un camino cerrado.
## Uso: const VetProgress = preload("res://core/lab/vet_progress.gd")
##      var p := VetProgress.new()
##      p.load_file("user://cetreria.cfg")      # tolerante a archivos viejos o rotos (p.notice lo dice)
##      p.accept("coping_aguila")
##      var r := p.on_care_finished(VetProgress.care_summary(care_view))
##      p.save_to("user://cetreria.cfg")
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const CareState = preload("res://core/lab/claw_care_state.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const Data = preload("res://core/lab/data.gd")
const Js = preload("res://core/shared/js.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const VetMinigames = preload("res://core/lab/vet_minigames.gd")

## La versión del formato del archivo (se sube si cambia lo que se guarda; uno más nuevo que este no se toca).
const FORMAT_VERSION := 1
const DEFAULT_PATH := "user://cetreria.cfg"
## La calidad de los números del juego y de dónde salen.
const GAME := "juego"
const GAME_SOURCE := "número del juego: ni física ni dinero; se ajusta jugando"

## Los niveles del veterinario: la experiencia que pide cada uno y cuántos encargos del nivel de antes hay que tener hechos
## («subir la experiencia y completar algún encargo»). Uno por lente. Los umbrales caben en lo que dan los encargos de cada
## nivel con la nota mínima que piden (sin ningún camino cerrado; la práctica libre suma lo que falte si hubo errores).
const LEVELS := [
	{ "level": 1, "xp": 0, "jobs": 0, "title": "Veterinario en prácticas", "quality": GAME, "source": GAME_SOURCE },
	{ "level": 2, "xp": 80, "jobs": 1, "title": "Veterinario de cetrería", "quality": GAME, "source": GAME_SOURCE },
	{ "level": 3, "xp": 240, "jobs": 1, "title": "Veterinario de fauna salvaje", "quality": GAME, "source": GAME_SOURCE },
	{ "level": 4, "xp": 540, "jobs": 1, "title": "Especialista en garras", "quality": GAME, "source": GAME_SOURCE },
]
const MAX_LEVEL := 4

## Las lentes de la cámara, de la peor a la mejor (los ids de la cetrería, 5t-A). La de plástico es la de serie.
const LENS_IDS := ["plastico", "vidrio", "vidrio_templado", "zafiro"]
const START_LENS := "plastico"
## Su nombre en la tienda (el material; la ficha con la dureza y su fuente es de la cetrería).
const LENS_NAMES := {
	"plastico": "Plástico (metacrilato)", "vidrio": "Vidrio óptico (crown N-BK7)", "vidrio_templado": "Vidrio templado (aluminosilicato)",
	"zafiro": "Cristal de zafiro",
}
## La tienda: el nivel que pide cada lente, su precio y lo que cuesta reponer la misma (otra igual, sin rayones). Juego. Reponer
## es barato en las que se rajan pronto con los animales grandes (el plástico y el vidrio, 5t-A): unas pocas prácticas.
const LENS_SHOP := {
	"plastico": { "level": 1, "price": 0, "replace": 10, "quality": GAME, "source": GAME_SOURCE },
	"vidrio": { "level": 2, "price": 80, "replace": 30, "quality": GAME, "source": GAME_SOURCE },
	"vidrio_templado": { "level": 3, "price": 180, "replace": 90, "quality": GAME, "source": GAME_SOURCE },
	"zafiro": { "level": 4, "price": 380, "replace": 190, "quality": GAME, "source": GAME_SOURCE },
}

## La lente que ya no deja ver (petición de Eric del 17-10: «puedes seguir trabajando con unos pocos rayones, pero si acumulas
## muchos tendrás que cambiar de lente, o empezar el juego de nuevo»): con lo que tapa (el índice obscuration de la cetrería)
## por encima de at, la consulta no cuenta (ni encargos ni práctica) hasta cambiar de lente; warn: el aviso de antes (el de
## ClawCareLens.WARN_OBSCURATION). Juego.
const BLIND := { "at": 0.85, "warn": 0.6, "quality": GAME, "source": GAME_SOURCE }

## Lo que puede pedir un encargo: el texto (con %s, el número del encargo) y por qué se pide (su fuente). Se comprueba con el
## informe del motor (ask_ok).
const ASKS := {
	"sujecion": { "text": "Con la sujeción que pide el animal (una rapaz, encapuchada y envuelta en la toalla)", "source": CareData.SRC_SAMOUR + ", pp. 916-917" },
	"anestesia": { "text": "Con anestesia general antes de tocarlo", "source": CareData.SRC_CATTALES + "; " + CareData.SRC_ANIMALS_ASIA },
	"sin_sangre": { "text": "Sin cortar la carne viva: que no sangre", "source": CareData.SRC_SAMOUR },
	"sin_calor": { "text": "Sin que el calor de la herramienta duela en la carne viva", "source": CareData.SRC_DUBIN + "; " + CareData.SRC_DREMEL_GUIDE },
	"quieto": { "text": "Sin que el animal se mueva por el dolor", "source": String(CareData.SEDATION.sujecion.source) },
	"punta_natural": { "text": "Con la punta natural: ni roma ni de aguja", "source": CareData.SRC_RUBRIC + "; " + CareData.SRC_ARENT },
	"daga": { "text": "Afilada como una daga, más fina que la natural, pero que aún aguante de lado", "source": CareData.SRC_RUBRIC },
	"nota": { "text": "Con una nota de al menos %s", "source": CareData.SRC_RUBRIC },
	"digito": { "text": "En la garra del dedo %s", "source": CareData.SRC_MANNING },
	"pieza_colocada": { "text": "La pieza de la reforja colocada en la garra, curada, sin escalón y probada", "source": String(ForgeData.ADHESIVES.epoxi.source) },
	"gema": { "text": "De zafiro o de rubí, hecha en el laboratorio", "source": ForgeData.SRC_SG_SAPPHIRE },
	"funda_metal": { "text": "La funda de %s terminada en el laboratorio: colada con la forma de la garra, tallada y pulida", "source": ForgeData.SRC_GANOKSIN },
	"soldada": { "text": "Soldada en la mesa de soldar: la unión atraviesa la pared, sin perforarla ni contaminarla", "source": "Amada Miyachi America (2016), Laser Welding Fundamentals; Watanabe I, Topham DS (2006), J. Prosthodont. 15:102-107" },
	# (unidad 5v) los de los encargos de iniciación, de los minijuegos y de las garras rotas
	"tutorial": { "text": "Siguiendo el tutorial «%s» hasta el final", "source": "juego: aprender jugando y en orden" },
	"largo": { "text": "Hasta su largo natural, sin acercarse a la carne viva", "source": CareData.SRC_SAMOUR },
	"pulida": { "text": "La punta pulida: Ra de ≤ %s µm en sus últimos %s mm, sin quemarla", "source": "juego (el acabado de la punta, de la superficie del motor: " + String(CareData.SURFACE.ra_per_depth.source) + ")" },
	"banda": { "text": "La punta %s: entre ×%s y ×%s el radio natural", "source": CareData.SRC_RUBRIC },
	"pieza_material": { "text": "Con una pieza hecha en la reforja de %s", "source": "juego (lo que pide el cliente); la pieza, la de la reforja: " + ForgeData.SRC_FERREIRA },
	"reparada": { "text": "La garra rota reparada: la sangre parada, desinfectada y reconstruida o con la pieza de la reforja colocada", "source": CareData.SRC_SAMOUR + ", p. 925" },
}

## Los encargos, de dificultad creciente: id, kind («cetreria»: se comprueba al terminar la consulta; «reforja»: con la pieza
## del laboratorio), el nivel que piden, el animal (y la garra o el dedo), lo que piden (asks; el animal, implícito), la nota
## mínima, la recompensa (experiencia y créditos, juego) y el texto del cliente. needs_weld: solo con la mesa de soldar de la
## reforja (5r).
const JOBS := [
	{ "id": "coping_aguila", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "",
		"asks": ["sujecion", "sin_sangre", "nota"], "min_grade": 6.0, "xp": 50, "credits": 30,
		"title": "El arreglo de las garras del águila",
		"text": "Un centro de cetrería te trae un águila con las garras crecidas: recórtalas y límalas a su largo, encapuchada y en la toalla, sin hacerla sangrar.",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "punta_halcon", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "halcon", "digit": "",
		"asks": ["sujecion", "punta_natural", "sin_sangre", "nota"], "min_grade": 7.0, "xp": 60, "credits": 40,
		"title": "La punta del halcón",
		"text": "Un halconero necesita que su halcón peregrino vuelva a agarrar bien la presa: deja la garra con su punta natural, ni roma ni de aguja.",
		"quality": GAME, "source": CareData.SRC_ARENT },
	{ "id": "buho_quieto", "kind": "cetreria", "level": 2, "animal": "rapaz", "claw": "buho", "digit": "",
		"asks": ["sujecion", "quieto", "sin_calor", "nota"], "min_grade": 7.0, "xp": 80, "credits": 50,
		"title": "El búho, sin sobresaltos",
		"text": "Un búho de un centro de recuperación se asusta con nada: trabaja sin hacerle daño (que no se mueva por el dolor) y sin calentar la carne viva con el torno o la amoladora.",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "funda_oro", "kind": "reforja", "level": 2, "animal": "", "claw": "", "digit": "", "materials": ["oro"],
		"asks": ["funda_metal"], "min_grade": 0.0, "xp": 90, "credits": 60,
		"title": "Una funda de oro a la cera perdida",
		"text": "Para una exposición de garras reforjadas: una funda de oro colada con la forma de la garra, del modelo de cera a la funda pulida, en el laboratorio experimental.",
		"quality": GAME, "source": ForgeData.SRC_GANOKSIN },
	{ "id": "tigre_anestesia", "kind": "cetreria", "level": 3, "animal": "tigre", "claw": "", "digit": "",
		"asks": ["anestesia", "sin_sangre", "nota"], "min_grade": 6.0, "xp": 120, "credits": 80,
		"title": "El tigre de la clínica",
		"text": "Un tigre con una garra clavada en la almohadilla: con anestesia general, recórtala y límala sin hacerlo sangrar.",
		"quality": GAME, "source": CareData.SRC_CATTALES },
	{ "id": "oso_quieto", "kind": "cetreria", "level": 3, "animal": "oso", "claw": "", "digit": "",
		"asks": ["anestesia", "quieto", "sin_calor", "nota"], "min_grade": 7.0, "xp": 130, "credits": 90,
		"title": "El oso pardo del santuario",
		"text": "Un oso rescatado llega con las garras crecidas y clavadas: anestesiado, sin que se mueva y sin calentar la carne viva.",
		"quality": GAME, "source": CareData.SRC_ANIMALS_ASIA },
	{ "id": "daga_lechuza", "kind": "cetreria", "level": 3, "animal": "rapaz", "claw": "lechuza", "digit": "",
		"asks": ["sujecion", "daga", "sin_sangre", "nota"], "min_grade": 8.0, "xp": 110, "credits": 70,
		"title": "Afilada como una daga",
		"text": "Una lechuza de vuelo libre: la punta más fina que la natural, pero que aún aguante de lado sin mellarse.",
		"quality": GAME, "source": CareData.SRC_RUBRIC },
	{ "id": "soldar_punta", "kind": "reforja", "level": 3, "animal": "", "claw": "", "digit": "", "needs_weld": true,
		"asks": ["soldada"], "min_grade": 0.0, "xp": 120, "credits": 80,
		"title": "Soldar la punta de una funda",
		"text": "Una funda de metal con su punta soldada en la mesa de soldar del laboratorio: la unión entera, sin falta de fusión, sin perforar la pared y, en el titanio, con argón.",
		"quality": GAME, "source": "Amada Miyachi America (2016), Laser Welding Fundamentals" },
	{ "id": "velociraptor_hoz", "kind": "cetreria", "level": 4, "animal": "velociraptor", "claw": "", "digit": "II",
		"asks": ["anestesia", "digito", "punta_natural", "nota"], "min_grade": 8.0, "xp": 180, "credits": 120,
		"title": "La hoz del velocirraptor",
		"text": "La garra en hoz del dedo II del velocirraptor: con anestesia, a su largo y con su punta natural.",
		"quality": GAME, "source": CareData.SRC_MANNING },
	{ "id": "zafiro_colocada", "kind": "cetreria", "level": 4, "animal": "", "claw": "", "digit": "",
		"asks": ["gema", "pieza_colocada"], "min_grade": 0.0, "xp": 170, "credits": 110,
		"title": "Una funda de zafiro, colocada",
		"text": "Para un ensayo del banco: una funda de zafiro (o de rubí) hecha en el laboratorio y colocada a mano sobre la garra, pegada, sin rebabas ni escalón y probada.",
		"quality": GAME, "source": ForgeData.SRC_FERREIRA },
]
## Las gemas que valen para «gema».
const GEMS := ["zafiro", "rubi"]

## (unidad 5v; petición de Eric del 17-10) Los encargos de iniciación, uno por tutorial, en cadena (after: el de antes), con el
## tutorial abierto en su proceso (tutorial). Recompensas: juego.
const INITIATION := [
	{ "id": "inic_preparar", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "", "tutorial": "preparar",
		"asks": ["tutorial", "sujecion"], "min_grade": 0.0, "xp": 15, "credits": 10, "title": "Iniciación 1 · Preparar al águila",
		"text": "Tu primer día en el centro de cetrería: aprende a sujetar al águila (capucha y toalla) siguiendo el tutorial paso a paso, y termina la consulta.",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "inic_carne", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "", "tutorial": "inspeccionar",
		"after": "inic_preparar", "asks": ["tutorial", "sujecion", "sin_sangre"], "min_grade": 0.0, "xp": 15, "credits": 10,
		"title": "Iniciación 2 · Dónde está la carne viva",
		"text": "Antes de cortar, hay que saber dónde acaba la carne viva: sigue el tutorial «Buscar la carne viva» (en el águila no se ve) y termina sin hacerla sangrar.",
		"quality": GAME, "source": CareData.SRC_HEDRICK },
	{ "id": "inic_recortar", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "", "tutorial": "recortar",
		"after": "inic_carne", "asks": ["tutorial", "sujecion", "sin_sangre"], "min_grade": 0.0, "xp": 20, "credits": 15,
		"title": "Iniciación 3 · Recortar el sobrante",
		"text": "Remoja la garra y recorta el crecimiento de más con el cortaúñas de guillotina, poco a poco, siguiendo el tutorial «Recortar el sobrante».",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "inic_limar", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "", "tutorial": "limar",
		"after": "inic_recortar", "asks": ["tutorial", "sujecion", "sin_sangre", "largo"], "min_grade": 0.0, "xp": 20, "credits": 15,
		"title": "Iniciación 4 · Limar a su largo",
		"text": "De la base a la punta y de grueso a fino: lima la garra hasta su largo siguiendo el tutorial «Limar».",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "inic_punta", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "aguila", "digit": "", "tutorial": "afilar",
		"after": "inic_limar", "asks": ["tutorial", "sujecion", "punta_natural"], "min_grade": 0.0, "xp": 25, "credits": 15,
		"title": "Iniciación 5 · Darle la punta",
		"text": "Con la lima fina, una faceta limpia hasta la punta natural: ni roma ni de aguja. Sigue el tutorial «Dar la punta» y mira el medidor.",
		"quality": GAME, "source": CareData.SRC_ARENT },
]
## Los de los minijuegos (minigame: VetMinigames) y las garras rotas (broken_start: { paw, digit, kind }; tip_start: la punta
## con la que llega el animal). Recompensas: juego.
const JOBS_5V := [
	{ "id": "pulir_halcon", "kind": "cetreria", "level": 1, "animal": "rapaz", "claw": "halcon", "digit": "", "minigame": "pulir",
		"ra_max_um": 1.5, "asks": ["sujecion", "largo", "pulida", "sin_sangre"], "min_grade": 0.0, "xp": 45, "credits": 30,
		"title": "Minijuego · Pulir la garra del halcón",
		"text": "Un halcón de exhibición: a su largo y con la punta pulida, lisa al tacto. La lima gruesa quita deprisa pero raya; termina con la lija fina en la punta, sin calentarla con el torno.",
		"quality": GAME, "source": GAME_SOURCE },
	{ "id": "roma_buho", "kind": "cetreria", "level": 2, "animal": "rapaz", "claw": "buho", "digit": "", "minigame": "transformar",
		"band": "roma", "tip_start": "natural", "asks": ["sujecion", "banda", "sin_sangre"], "min_grade": 0.0, "xp": 60, "credits": 40,
		"title": "Minijuego · Una punta roma para el búho",
		"text": "Un búho de un centro de recuperación se clava sus propias garras en la almohadilla al posarse: despúntalas, redondeando la punta (roma) sin acortar de más. Objetivo de juego.",
		"quality": GAME, "source": GAME_SOURCE },
	{ "id": "afilar_aguila", "kind": "cetreria", "level": 2, "animal": "rapaz", "claw": "aguila", "digit": "", "minigame": "transformar",
		"band": "natural", "tip_start": "roma", "asks": ["sujecion", "banda", "sin_sangre"], "min_grade": 0.0, "xp": 60, "credits": 40,
		"title": "Minijuego · Devolverle la punta",
		"text": "Un águila que vuelve al campo llega con las garras gastadas y romas de las perchas: devuélveles la punta natural para cazar, sin pasar a aguja (la lima fina en ángulo y, si se pasa, un toque ligero de frente).",
		"quality": GAME, "source": CareData.SRC_LDWF_HOUSING },
	{ "id": "rota_aguila", "kind": "cetreria", "level": 2, "animal": "rapaz", "claw": "aguila", "digit": "I", "minigame": "reparar",
		"broken_start": { "paw": "derecha", "digit": "I", "kind": "fresca" }, "asks": ["sujecion", "reparada"], "min_grade": 0.0,
		"xp": 70, "credits": 45, "title": "Minijuego · El águila con la garra partida",
		"text": "Un águila llega con la garra del talón recién partida, sangrando: para la sangre, desinfecta y reconstrúyela con metacrilato (o colócale una pieza de la reforja).",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
	{ "id": "funda_titanio_aguila", "kind": "cetreria", "level": 3, "animal": "rapaz", "claw": "aguila", "digit": "II", "minigame": "reforjar",
		"broken_start": { "paw": "derecha", "digit": "II", "kind": "muñon" }, "materials": ["titanio", "acero"],
		"asks": ["sujecion", "pieza_material", "pieza_colocada"], "min_grade": 0.0, "xp": 120, "credits": 80,
		"title": "Minijuego · Reforjar la garra del águila",
		"text": "Un águila llega con un muñón en la garra del dedo II: haz en la reforja una funda de titanio (o de acero) a su medida y colócala tú, limpia, pegada, sin escalón y probada. FICCIÓN: en un animal de verdad se reconstruye con acrílico; la funda de metal es un experimento del banco.",
		"quality": GAME, "source": ForgeData.SRC_FERREIRA },
	{ "id": "rota_tigre", "kind": "cetreria", "level": 3, "animal": "tigre", "claw": "tigre", "digit": "III", "minigame": "reparar",
		"broken_start": { "paw": "delantera_derecha", "digit": "III", "kind": "muñon" }, "asks": ["anestesia", "reparada"], "min_grade": 0.0,
		"xp": 110, "credits": 75, "title": "Minijuego · El muñón del tigre",
		"text": "Un tigre llega con un muñón de una garra partida hace días: anestesiado, reconstrúyela o colócale una pieza hecha en la reforja (la funda o la prótesis, colocada a mano).",
		"quality": GAME, "source": CareData.SRC_SAMOUR },
]
## Lo que se cobra al reparar una garra que se ha roto durante la operación (el encargo cambia a «repararla»): esta fracción de
## la recompensa. Juego.
const REPAIR_PAY := { "frac": 0.5, "quality": GAME, "source": GAME_SOURCE }
const REPAIR_ASKS := ["reparada"]
## La práctica libre: cada consulta terminada sin peligro y con esta nota da un poco (no es un encargo: se cobra una vez por
## consulta, todas las que se quiera).
const PRACTICE := { "xp": 15, "credits": 5, "min_grade": 5.0, "quality": GAME, "source": GAME_SOURCE }
## La nota sube la recompensa: un 50 % de la base con un 0 y toda con un 10 (juego).
const GRADE_FLOOR := 0.5
## Lo que resta cada error que el encargo no pide evitar (fracción de la recompensa; juego), con su porqué y su fuente.
const FAULTS := {
	"sangre": { "frac": 0.25, "text": "ha sangrado", "why": "Se cortó la carne viva: duele, hay que parar la sangre y desinfectar.", "source": CareData.SRC_SAMOUR, "quality": GAME },
	"calor": { "frac": 0.2, "text": "el calor ha dolido", "why": "La herramienta giratoria calentó la carne viva por encima del umbral del dolor (~43 °C): toques cortos y pausas.", "source": CareData.SRC_DUBIN + "; " + CareData.SRC_DREMEL_GUIDE, "quality": GAME },
	"sujecion": { "frac": 0.3, "text": "sin la sujeción adecuada", "why": "Una rapaz se trabaja encapuchada y envuelta en la toalla.", "source": CareData.SRC_SAMOUR, "quality": GAME },
	"se_mueve": { "frac": 0.15, "text": "el animal se ha movido", "why": "Se movió por el dolor: más lejos de la carne viva o más sedación.", "source": String(CareData.SEDATION.sujecion.source), "quality": GAME },
	"sin_desinfectar": { "frac": 0.1, "text": "sin desinfectar la herida", "why": "Ha sangrado y no se ha limpiado: riesgo de infección (clorhexidina al 0,05 %).", "source": CareData.SRC_LOZIER, "quality": GAME },
}
## El error de cada falta que ya pide evitar un encargo (para no restarla dos veces).
const FAULT_ASK := { "sangre": "sin_sangre", "calor": "sin_calor", "sujecion": "sujecion", "se_mueve": "quieto" }

var xp := 0
var credits := 0
## El nivel más alto alcanzado: el nivel no baja aunque cambien las reglas en otra versión.
var best_level := 1
var lens_on := START_LENS
## id → { owned, damage (el to_dict() del estado del daño de la cetrería, o {}) }.
var lenses := {}
## id → { state: «en_curso» | «hecho», grade, xp, credits }.
var jobs := {}
var active_job := ""
## El resultado de la última comprobación (on_care_finished u on_forge_finished), para la interfaz.
var last_result: Dictionary = {}
## Un aviso para la interfaz (el archivo dañado, una compra que no se puede…); la interfaz lo enseña y lo borra.
var notice := ""
## Con un archivo de una versión más nueva no se guarda nada (no se pisa).
var read_only := false
## Sube con cada cambio (la interfaz repinta y guarda cuando cambia).
var serial := 0
## La última consulta comprobada (su semilla): la misma no se cobra dos veces en una sesión del programa.
var _last_session := ""


func _init() -> void:
	lenses = { START_LENS: { "owned": true, "damage": {} } }


# ════════════════════════════════ Nivel y experiencia ════════════════════════════════

## El nivel de ahora: el más alto cuya experiencia se tiene y del que se han hecho los encargos del nivel de antes; nunca
## menos que el mejor alcanzado.
func level() -> int:
	var lv := 1
	for e: Dictionary in LEVELS:
		var n := int(e.level)
		if n <= 1:
			continue
		if xp >= int(e.xp) and jobs_done_at(n - 1) >= int(e.jobs):
			lv = n
		else:
			break
	return maxi(lv, best_level)


func _level_entry(n: int) -> Dictionary:
	for e: Dictionary in LEVELS:
		if int(e.level) == n:
			return e
	return LEVELS[0]


## Cuántos encargos de ese nivel están hechos.
func jobs_done_at(n: int) -> int:
	var c := 0
	for j: Dictionary in JOBS:
		if int(j.level) == n and String((jobs.get(String(j.id), {}) as Dictionary).get("state", "")) == "hecho":
			c += 1
	return c


func jobs_done() -> int:
	var c := 0
	for id: String in jobs:
		if String((jobs[id] as Dictionary).get("state", "")) == "hecho":
			c += 1
	return c


## El nivel y la barra: { level, title, xp, next_xp, frac (0-1 hacia el siguiente), max, text, next_text, quality }.
func level_view() -> Dictionary:
	var lv := level()
	var cur := _level_entry(lv)
	var out := { "level": lv, "title": String(cur.title), "xp": xp, "next_xp": -1, "frac": 1.0, "max": lv >= MAX_LEVEL,
		"text": "Nivel %s · %s" % [_n(lv), String(cur.title)], "next_text": "", "quality": GAME }
	if lv >= MAX_LEVEL:
		out["next_text"] = "%s de experiencia: el nivel más alto." % _n(xp)
		return out
	var nxt := _level_entry(lv + 1)
	var lo := int(cur.xp)
	var hi := int(nxt.xp)
	out["next_xp"] = hi
	out["frac"] = clampf(float(xp - lo) / float(maxi(hi - lo, 1)), 0.0, 1.0)
	var need_jobs := maxi(int(nxt.jobs) - jobs_done_at(lv), 0)
	var t := "%s de %s de experiencia para el nivel %s" % [_n(xp), _n(hi), _n(lv + 1)]
	if need_jobs > 0:
		t += " y %s encargo%s de este nivel" % [_n(need_jobs), "" if need_jobs == 1 else "s"]
	elif xp >= hi:
		t = "Nivel %s alcanzado" % _n(lv + 1)
	out["next_text"] = t + "."
	return out


func credits_text() -> String:
	return "%s créditos" % _n(credits)


static func _n(v: int) -> String:
	return Js.to_fixed(float(v), 0)


func _touch() -> void:
	serial += 1


## Paga una recompensa (nunca resta: la experiencia y el nivel no bajan) y apunta el nivel alcanzado. Devuelve si sube de nivel.
func _pay(x: int, c: int) -> bool:
	var before := level()
	xp += maxi(x, 0)
	credits += maxi(c, 0)
	var now := level()
	best_level = maxi(best_level, now)
	return now > before


# ════════════════════════════════ Encargos ════════════════════════════════

## El encargo id (de JOBS) o {}.
static func job(id: String) -> Dictionary:
	for j: Dictionary in all_jobs():
		if String(j.id) == id:
			return j
	return {}


## Todos los encargos, en el orden de la lista: los de iniciación (5v), los de la 5u y los de los minijuegos (5v).
static func all_jobs() -> Array:
	return INITIATION + JOBS + JOBS_5V


## El estado de un encargo: «hecho», «en_curso», «bloqueado» (pide más nivel) o «disponible».
func job_state(id: String) -> String:
	var j := job(id)
	if j.is_empty():
		return ""
	var st := String((jobs.get(id, {}) as Dictionary).get("state", ""))
	if st == "hecho":
		return "hecho"
	if id == active_job:
		return "en_curso"
	if int(j.level) > level():
		return "bloqueado"
	# (5v) la cadena de iniciación: uno detrás de otro
	var after := String(j.get("after", ""))
	if after != "" and String((jobs.get(after, {}) as Dictionary).get("state", "")) != "hecho":
		return "bloqueado"
	return "disponible"


## Acepta un encargo (solo uno en curso: el anterior vuelve a la lista). { ok, text }.
func accept(id: String) -> Dictionary:
	var j := job(id)
	var st := job_state(id)
	if j.is_empty():
		return { "ok": false, "text": "Ese encargo no existe." }
	if st == "hecho":
		return { "ok": false, "text": "«%s» ya está hecho: no se cobra dos veces." % String(j.title) }
	if st == "bloqueado":
		if int(j.level) <= level() and String(j.get("after", "")) != "":
			return { "ok": false, "text": "«%s» va después de «%s»." % [String(j.title), String(job(String(j.after)).get("title", ""))] }
		return { "ok": false, "text": "«%s» pide el nivel %s (tienes el %s)." % [String(j.title), _n(int(j.level)), _n(level())] }
	if active_job != "" and active_job != id and jobs.has(active_job):
		jobs.erase(active_job)
	active_job = id
	jobs[id] = { "state": "en_curso" }
	last_result = {}
	_touch()
	return { "ok": true, "text": "Encargo aceptado: %s." % String(j.title) }


## Deja el encargo en curso (vuelve a la lista, sin perder nada).
func abandon() -> void:
	if active_job == "":
		return
	if String((jobs.get(active_job, {}) as Dictionary).get("state", "")) == "en_curso":
		jobs.erase(active_job)
	active_job = ""
	_touch()


## El texto de lo que pide un encargo (asks), con su fuente corta: [{ id, text, source }].
static func ask_texts(j: Dictionary) -> Array:
	var out: Array = []
	if String(j.get("animal", "")) != "":
		out.append({ "id": "animal", "text": "El animal: %s" % _animal_words(j), "source": "" })
	for a: String in j.asks:
		var d: Dictionary = ASKS.get(a, {})
		var t := String(d.get("text", a))
		match a:
			"nota":
				t = t % Js.to_fixed(float(j.min_grade), 0)
			"digito":
				t = t % String(j.digit)
			"funda_metal":
				var mats: Array = j.get("materials", [])
				t = t % " o ".join(mats.map(func(m: String) -> String: return _material_name(m)))
			"tutorial":
				t = t % String(Tutorial.PROCESS_NAMES.get(String(j.get("tutorial", "")), String(j.get("tutorial", ""))))
			"pulida":
				t = t % [Js.to_fixed(float(j.get("ra_max_um", 1.5)), 1), Js.to_fixed(VetMinigames.POLISH_ZONE_MM, 0)]
			"pieza_material":
				var pm: Array = j.get("materials", [])
				t = t % " o ".join(pm.map(func(m: String) -> String: return _material_name(m)))
			"banda":
				var bd: Dictionary = VetMinigames.BANDS.get(String(j.get("band", "natural")), VetMinigames.BANDS.natural)
				t = t % [String(bd.name), Js.to_fixed(float(bd.lo), 1), Js.to_fixed(float(bd.hi), 1)]
		out.append({ "id": a, "text": t, "source": CareState.short_source(String(d.get("source", ""))) })
	return out


static func _animal_words(j: Dictionary) -> String:
	var aid := String(j.get("animal", ""))
	var a: Dictionary = CareData.ANIMALS.get(aid, {})
	var name := String(a.get("name", aid)).to_lower()
	var cid := String(j.get("claw", ""))
	if cid != "":
		var c: Variant = Data.find_by_id(Data.CLAWS, cid)
		if c != null:
			name = String(c.name).to_lower()
	return name


static func _material_name(mid: String) -> String:
	var e: Variant = ForgeData.inlay_entry(mid)
	return String(e.name).to_lower() if e != null else mid


## Los encargos para la interfaz (con la mesa de soldar o sin ella): [{ id, title, text, kind, level, state, state_text,
## reward_text, asks [{ id, text, source }], result (el último de ese encargo, si lo hay), source }].
func jobs_view(has_weld := true) -> Array:
	var out: Array = []
	for j: Dictionary in all_jobs():
		if bool(j.get("needs_weld", false)) and not has_weld:
			continue
		var id := String(j.id)
		var st := job_state(id)
		var rec: Dictionary = jobs.get(id, {})
		var words := { "hecho": "Hecho", "en_curso": "En curso", "bloqueado": "Pide el nivel %s" % _n(int(j.level)), "disponible": "Disponible" }
		if st == "bloqueado" and int(j.level) <= level() and String(j.get("after", "")) != "":
			words["bloqueado"] = "Después de «%s»" % String(job(String(j.after)).get("title", ""))
		var reward := "+%s de experiencia y +%s créditos (según la nota)" % [_n(int(j.xp)), _n(int(j.credits))]
		if String(j.kind) == "reforja":
			reward = "+%s de experiencia y +%s créditos" % [_n(int(j.xp)), _n(int(j.credits))]
		if st == "hecho":
			reward = "Cobrado: +%s de experiencia y +%s créditos" % [_n(int(rec.get("xp", 0))), _n(int(rec.get("credits", 0)))]
		out.append({ "id": id, "title": String(j.title), "text": String(j.text), "kind": String(j.kind), "level": int(j.level),
			"state": st, "state_text": String(words.get(st, st)), "reward_text": reward, "asks": ask_texts(j),
			"where": "En el laboratorio experimental (reforja)" if String(j.kind) == "reforja" else "En la cetrería, al terminar la consulta",
			"source": CareState.short_source(String(j.source)), "quality": GAME }.merged(card_extra(j)))
	return out


## (5v) La ficha del encargo: con qué llega el animal (la punta, la garra rota), el tutorial que abre y el minijuego, y por qué
## (su fuente o «juego»). { arrives, tutorial, tutorial_name, minigame, minigame_name, why }.
static func card_extra(j: Dictionary) -> Dictionary:
	var arrives: Array = []
	var ts := String(j.get("tip_start", ""))
	if ts != "" and ts != "natural":
		arrives.append("con la punta %s" % String((CareData.TIP_STARTS.get(ts, {}) as Dictionary).get("name", ts)).to_lower())
	var bs: Dictionary = j.get("broken_start", {})
	if not bs.is_empty():
		var e: Dictionary = CareData.BROKEN_STARTS.get(String(bs.get("kind", "")), {})
		arrives.append("con la garra del dedo %s %s" % [String(bs.get("digit", "")), String(e.get("name", "rota"))])
	var src := String(j.get("source", ""))
	return {
		"arrives": ("Llega " + " y ".join(arrives) + ".") if not arrives.is_empty() else "",
		"tutorial": String(j.get("tutorial", "")),
		"tutorial_name": String(Tutorial.PROCESS_NAMES.get(String(j.get("tutorial", "")), "")),
		"minigame": String(j.get("minigame", "")), "minigame_name": String(VetMinigames.KINDS.get(String(j.get("minigame", "")), "")),
		"why": "juego" if src == GAME_SOURCE else CareState.short_source(src),
	}


# ════════════════════════════════ Lo que dicen los motores ════════════════════════════════

## Lo que hace falta de la vista de la cetrería al terminar (ClawCareState.view()): el animal, la garra, la sujeción, el
## veredicto y la nota del informe, sus criterios, la sangre, el calor, si se ha movido y la pieza colocada. Sin calcular nada.
static func care_summary(v: Dictionary) -> Dictionary:
	var s: Dictionary = v.get("setup", {})
	var sn: Dictionary = v.get("snap", {})
	var rep: Dictionary = v.get("report", {})
	var an: Dictionary = sn.get("animal", {})
	var bl: Dictionary = sn.get("bleeding", {})
	var th: Dictionary = sn.get("thermal", {})
	var crit: Array = []
	for c: Dictionary in rep.get("criteria", []):
		crit.append(String(c.get("id", "")))
	var bd: Dictionary = v.get("bond", {})
	var bond := {}
	if not bd.is_empty():
		bond = { "material": String(bd.get("material", "")), "kind": String(bd.get("kind", "")), "method": String(bd.get("method", "")),
			"attached": bool(bd.get("attached", false)), "done": bool(bd.get("done", false)),
			"tested": bool((bd.get("test", {}) as Dictionary).get("ok", false)) }
	var facts: Dictionary = rep.get("facts", {})
	return {
		"kind": "cetreria", "session": String(s.get("seed", "")), "finished": bool(v.get("finished", false)),
		"halted": not (v.get("halted", {}) as Dictionary).is_empty(), "animal": String(s.get("animal", "")),
		"claw": String(s.get("claw", "")), "digit": String(v.get("digit", "")), "sedation": String(an.get("sedation", "libre")),
		"unsafe": bool(an.get("unsafe", false)), "verdict": String(rep.get("verdict", "")), "grade": float(rep.get("grade", 0.0)),
		"grade_text": String(rep.get("gradeText", "")), "criteria": crit, "bled": bool(bl.get("bled", false)),
		"bleeding": bool(bl.get("active", false)), "peak_quick_c": float(th.get("peakQuickC", 0.0)), "pain_c": float(th.get("painC", 43.0)),
		"injured": bool(th.get("injured", false)), "moved": int(facts.get("moved", an.get("movedHere", 0))), "reforged": bool(v.get("reforged", false)),
		"bond": bond,
	}.merged(VetMinigames.summary(v))


## Lo que hace falta de la vista de la reforja (ClawForgeState.view()): el veredicto de la pieza, su material y, con la mesa
## de soldar (5r), su unión (snap.piece.weld; sin ella, null).
static func forge_summary(v: Dictionary) -> Dictionary:
	var sh: Dictionary = v.get("sheet", {})
	var sn: Dictionary = v.get("snap", {})
	var pc: Dictionary = sn.get("piece", {})
	var w: Variant = pc.get("weld", null)
	return {
		"kind": "reforja", "process": String(v.get("process", "")), "verdict": String(sh.get("verdict", "")),
		"material": String(pc.get("material", "")), "ok": bool(pc.get("ok", false)), "quality": String(sh.get("quality", "")),
		"weld": (w as Dictionary).duplicate(true) if w is Dictionary else null,
	}


## ¿Se cumple lo que pide el encargo j? { ok, why } (why: lo que ha pasado, si no se cumple).
static func ask_ok(a: String, j: Dictionary, s: Dictionary) -> Dictionary:
	var crit: Array = s.get("criteria", [])
	match a:
		"animal":
			var aid := String(j.get("animal", ""))
			var cid := String(j.get("claw", ""))
			if aid != "" and String(s.get("animal", "")) != aid:
				return { "ok": false, "why": "La consulta era de otro animal." }
			if cid != "" and String(s.get("claw", "")) != cid:
				return { "ok": false, "why": "La garra era de otra especie." }
			return { "ok": true, "why": "" }
		"sujecion":
			var ok := not crit.has("sujecion") and not crit.has("anestesia") and not bool(s.get("unsafe", false))
			return { "ok": ok, "why": "" if ok else "Se trabajó sin la sujeción que pide el animal." }
		"anestesia":
			var ok := String(s.get("sedation", "")) == "anestesia" and not bool(s.get("unsafe", false)) and not crit.has("anestesia")
			return { "ok": ok, "why": "" if ok else "No se le puso la anestesia general antes de tocarlo." }
		"sin_sangre":
			var ok := not bool(s.get("bled", false))
			return { "ok": ok, "why": "" if ok else "Se cortó la carne viva y sangró." }
		"sin_calor":
			var ok := float(s.get("peak_quick_c", 0.0)) < float(s.get("pain_c", 43.0)) and not bool(s.get("injured", false))
			return { "ok": ok, "why": "" if ok else "El calor llegó a %s °C en la carne viva (duele desde ~%s °C)." % [Js.to_fixed(float(s.get("peak_quick_c", 0.0)), 0), Js.to_fixed(float(s.get("pain_c", 43.0)), 0)] }
		"quieto":
			var ok := int(s.get("moved", 0)) == 0
			return { "ok": ok, "why": "" if ok else "Se movió por el dolor (%s vez/veces)." % _n(int(s.get("moved", 0))) }
		"punta_natural":
			var ok := String(s.get("verdict", "")) in ["perfecta", "perfecta_daga"]
			return { "ok": ok, "why": "" if ok else "La punta no quedó como la natural." }
		"daga":
			var ok := String(s.get("verdict", "")) == "perfecta_daga"
			return { "ok": ok, "why": "" if ok else "No quedó afilada como una daga que aguante." }
		"nota":
			var ok := float(s.get("grade", 0.0)) >= float(j.get("min_grade", 0.0)) - 1e-9
			return { "ok": ok, "why": "" if ok else "La nota fue %s." % String(s.get("grade_text", Js.to_fixed(float(s.get("grade", 0.0)), 1))) }
		"digito":
			var ok := String(s.get("digit", "")) == String(j.get("digit", ""))
			return { "ok": ok, "why": "" if ok else "Se trabajó la garra de otro dedo." }
		"pieza_colocada":
			var b: Dictionary = s.get("bond", {})
			var ok := bool(b.get("attached", false)) and bool(b.get("done", false)) and bool(b.get("tested", false))
			return { "ok": ok, "why": "" if ok else "La pieza no quedó colocada, curada, sin escalón y probada." }
		"gema":
			var b2: Dictionary = s.get("bond", {})
			var ok := GEMS.has(String(b2.get("material", "")))
			return { "ok": ok, "why": "" if ok else "La pieza no era de zafiro ni de rubí." }
		"funda_metal":
			var mats: Array = j.get("materials", [])
			var ok := String(s.get("verdict", "")) == "bien" and mats.has(String(s.get("material", "")))
			var why := "La funda no está terminada (hecha, tallada y pulida)." if String(s.get("verdict", "")) != "bien" else "La funda es de otro material."
			return { "ok": ok, "why": "" if ok else why }
		"soldada":
			var w: Variant = s.get("weld", null)
			var ok := w is Dictionary and bool((w as Dictionary).get("ok", false)) and String((w as Dictionary).get("defect", "")) == ""
			var why := "No hay unión soldada en la pieza." if not (w is Dictionary) else "La unión ha salido con un defecto: %s" % String((w as Dictionary).get("text", ""))
			return { "ok": ok, "why": "" if ok else why }
		"tutorial":
			var pid := String(j.get("tutorial", ""))
			var ok := (s.get("tut_done", []) as Array).has(pid)
			return { "ok": ok, "why": "" if ok else "No se llegó al final del tutorial «%s»." % String(Tutorial.PROCESS_NAMES.get(pid, pid)) }
		"largo":
			var left := float(s.get("overgrowth_left_mm", 0.0))
			var over := float(s.get("over_mm", 0.0))
			var ok := over <= 0.0 or left <= float(CareData.MARGINS.overgrowth_left) * over + 1e-9
			return { "ok": ok, "why": "" if ok else "Quedaron %s mm del crecimiento de más." % Js.to_fixed(left, 1) }
		"pulida":
			var ra := float(s.get("ra_tip_um", 0.0))
			var target := float(j.get("ra_max_um", 1.5))
			var ok := ra <= target + 1e-9 and not bool(s.get("burned_tip", false))
			var why := "La punta se quemó con el torno." if bool(s.get("burned_tip", false)) else "La punta quedó con un Ra de %s µm (pedía ≤ %s)." % [Js.to_fixed(ra, 2), Js.to_fixed(target, 1)]
			return { "ok": ok, "why": "" if ok else why }
		"banda":
			var band := String(j.get("band", "natural"))
			var ok := VetMinigames.in_band(float(s.get("tip_ratio", 1.0)), s.get("tip_strength"), band)
			return { "ok": ok, "why": "" if ok else "La punta quedó a ×%s de la natural, fuera de la banda %s." % [Js.to_fixed(float(s.get("tip_ratio", 1.0)), 2), band] }
		"pieza_material":
			var pb: Dictionary = s.get("bond", {})
			var ok := (j.get("materials", []) as Array).has(String(pb.get("material", "")))
			var why := "No hay pieza de la reforja en la garra." if pb.is_empty() else "La pieza es de otro material."
			return { "ok": ok, "why": "" if ok else why }
		"reparada":
			var bd: Dictionary = s.get("bond", {})
			var fixed := bool(s.get("repaired", false)) or (bool(bd.get("attached", false)) and bool(bd.get("done", false)))
			var ok := fixed and not bool(s.get("bleeding", false)) and not crit.has("sin_desinfectar")
			var miss: Array = []
			if bool(s.get("bleeding", false)):
				miss.append("sigue sangrando")
			if crit.has("sin_desinfectar"):
				miss.append("sin desinfectar")
			if not fixed:
				miss.append("sin reconstruir ni pieza colocada")
			return { "ok": ok, "why": "" if ok else "La garra rota: %s." % ", ".join(miss) }
	return { "ok": false, "why": "" }


## Comprueba el encargo id con el resumen de un motor, sin cambiar nada: { ok, id, title, items [{ id, text, ok, why }],
## grade, xp, credits, deductions [{ id, text, why, frac, source }], text, tone, quality }.
func evaluate(id: String, s: Dictionary) -> Dictionary:
	var j := job(id)
	var out := { "ok": false, "id": id, "title": String(j.get("title", "")), "items": [], "grade": float(s.get("grade", 0.0)), "xp": 0, "credits": 0,
		"deductions": [], "text": "", "tone": "mal", "quality": GAME, "practice": false }
	if j.is_empty():
		out["text"] = "Ese encargo no existe."
		return out
	if String(s.get("kind", "")) != String(j.kind):
		out["text"] = "Este encargo se comprueba en %s." % ("el laboratorio experimental (reforja)" if String(j.kind) == "reforja" else "la cetrería, al terminar la consulta")
		return out
	var items: Array = out.items
	var all_ok := true
	if String(j.kind) == "cetreria" and (not bool(s.get("finished", false)) or bool(s.get("halted", false))):
		all_ok = false
		items.append({ "id": "terminada", "text": "Terminar la consulta sin que se pare", "ok": false, "why": "La sesión se paró antes de acabar." if bool(s.get("halted", false)) else "La consulta no está terminada." })
	var asks: Array = ["animal"] if String(j.get("animal", "")) != "" else []
	asks.append_array(j.asks)
	var texts := ask_texts(j)
	# (5v) la garra que se rompe durante la operación: el encargo no se pierde, pasa a «repararla» (con menos recompensa)
	var repair := broke_here(j, s)
	if repair:
		var keep: Array = asks.filter(func(a: String) -> bool: return a in ["animal", "sujecion", "anestesia"])
		asks = keep + REPAIR_ASKS
		texts = ask_texts(j.merged({ "asks": keep.filter(func(a: String) -> bool: return a != "animal") + REPAIR_ASKS }, true))
		out["repair"] = true
	for a: String in asks:
		var r := ask_ok(a, j, s)
		var t := a
		for e: Dictionary in texts:
			if String(e.id) == a:
				t = String(e.text)
		items.append({ "id": a, "text": t, "ok": bool(r.ok), "why": String(r.why) })
		all_ok = all_ok and bool(r.ok)
	if not all_ok:
		var miss: Array = []
		for it: Dictionary in items:
			if not bool(it.ok) and String(it.why) != "":
				miss.append(String(it.why))
		out["text"] = "Aún no: %s" % " ".join(miss) if not miss.is_empty() else "Aún no se cumple lo que pide."
		return out
	# la recompensa: la base por la nota (en la cetrería) y menos lo que restan los errores que no pedía evitar
	var factor := 1.0
	if String(j.kind) == "cetreria":
		factor = GRADE_FLOOR + (1.0 - GRADE_FLOOR) * clampf(float(s.get("grade", 0.0)), 0.0, 10.0) / 10.0
		var lost := 0.0
		for f: Dictionary in faults(s, j):
			lost += float(f.frac)
			(out.deductions as Array).append(f)
		factor *= maxf(1.0 - lost, 0.0)
	if repair:
		factor *= float(REPAIR_PAY.frac)
	out["ok"] = true
	out["tone"] = "bien" if (out.deductions as Array).is_empty() and not repair else "aviso"
	out["xp"] = int(Js.js_round(float(j.xp) * factor))
	out["credits"] = int(Js.js_round(float(j.credits) * factor))
	out["text"] = "Encargo cumplido: %s. +%s de experiencia y +%s créditos." % [String(j.title), _n(int(out.xp)), _n(int(out.credits))]
	if repair:
		out["text"] = "Encargo cumplido, reparando: la garra se rompió durante la operación y el encargo pasó a «repararla». Se cobra el %s %%: +%s de experiencia y +%s créditos." % [
			Js.to_fixed(float(REPAIR_PAY.frac) * 100.0, 0), _n(int(out.xp)), _n(int(out.credits))]
	return out


## (5v) ¿Se ha roto la garra durante la operación (no llegaba rota de serie) en un encargo de la cetrería que no era repararla?
static func broke_here(j: Dictionary, s: Dictionary) -> bool:
	if String(j.get("kind", "")) != "cetreria" or not bool(s.get("broken", false)) or String(s.get("broken_start", "")) != "":
		return false
	return not (j.get("asks", []) as Array).has("reparada")


## Los errores de una consulta que restan de la recompensa (los que el encargo no pide evitar ya): [{ id, text, why, frac,
## source }].
static func faults(s: Dictionary, j: Dictionary = {}) -> Array:
	var out: Array = []
	var asks: Array = j.get("asks", [])
	var crit: Array = s.get("criteria", [])
	var has := {
		# (5v) la garra que llega partida y sangrando ya sangraba: no es un error de la consulta
		"sangre": bool(s.get("bled", false)) and String(s.get("broken_start", "")) != "fresca",
		"calor": float(s.get("peak_quick_c", 0.0)) >= float(s.get("pain_c", 43.0)) or bool(s.get("injured", false)),
		"sujecion": crit.has("sujecion"),
		"se_mueve": int(s.get("moved", 0)) > 0,
		"sin_desinfectar": crit.has("sin_desinfectar"),
	}
	for id: String in FAULTS:
		if not bool(has[id]):
			continue
		if FAULT_ASK.has(id) and asks.has(String(FAULT_ASK[id])):
			continue
		var f: Dictionary = FAULTS[id]
		out.append({ "id": id, "text": String(f.text), "why": String(f.why), "frac": float(f.frac),
			"source": CareState.short_source(String(f.source)) })
	return out


## La consulta de la cetrería ha terminado (el resumen de care_summary): comprueba el encargo en curso de la cetrería y lo
## cobra si se cumple (una sola vez); si no hay encargo de la cetrería en curso, o no se cumple, la práctica libre. Devuelve el
## resultado (también en last_result): el de evaluate, con practice_result y level_up. La misma consulta terminada otra vez
## (después de «Seguir con esta garra») vuelve a mirar el encargo, pero la práctica no se cobra dos veces.
func on_care_finished(s: Dictionary) -> Dictionary:
	var ses := String(s.get("session", ""))
	var again := ses != "" and ses == _last_session
	_last_session = ses
	if blind():
		var b := { "ok": false, "practice": false, "id": active_job, "title": "La lente no deja ver", "items": [], "deductions": [],
			"xp": 0, "credits": 0, "tone": "mal", "quality": GAME, "text": blind_view().text }
		last_result = b
		_touch()
		return b
	var r := {}
	var aj := job(active_job)
	if not aj.is_empty() and String(aj.kind) == "cetreria":
		r = evaluate(active_job, s)
		if bool(r.ok):
			r["level_up"] = _complete(active_job, r)
			last_result = r
			_touch()
			return r
	if again:
		if not r.is_empty():
			last_result = r
			_touch()
		return last_result
	# la práctica libre: cualquier consulta terminada sin peligro y con su nota
	var p := practice(s)
	if r.is_empty():
		r = p
	else:
		r["practice_result"] = p
	if bool(p.ok):
		r["level_up"] = _pay(int(p.xp), int(p.credits))
	last_result = r
	_touch()
	return r


## La pieza del laboratorio (el resumen de forge_summary): comprueba el encargo en curso de la reforja y lo cobra si se cumple.
## {} si no hay encargo de la reforja en curso; si no se cumple, el porqué.
func on_forge_finished(s: Dictionary) -> Dictionary:
	var aj := job(active_job)
	if aj.is_empty() or String(aj.kind) != "reforja":
		return {}
	var r := evaluate(active_job, s)
	if bool(r.ok):
		r["level_up"] = _complete(active_job, r)
	last_result = r
	_touch()
	return r


## La práctica libre de una consulta: { ok, practice, xp, credits, text, tone, deductions }.
func practice(s: Dictionary) -> Dictionary:
	var ok := String(s.get("kind", "")) == "cetreria" and bool(s.get("finished", false)) and not bool(s.get("halted", false)) \
		and not bool(s.get("unsafe", false)) and float(s.get("grade", 0.0)) >= float(PRACTICE.min_grade) - 1e-9
	var out := { "ok": ok, "practice": true, "id": "", "title": "Práctica libre", "items": [], "grade": float(s.get("grade", 0.0)),
		"xp": int(PRACTICE.xp) if ok else 0, "credits": int(PRACTICE.credits) if ok else 0, "deductions": [], "tone": "bien" if ok else "",
		"quality": GAME, "text": "" }
	if ok:
		out["text"] = "Práctica libre: +%s de experiencia y +%s créditos por la consulta." % [_n(int(PRACTICE.xp)), _n(int(PRACTICE.credits))]
	elif bool(s.get("halted", false)) or bool(s.get("unsafe", false)):
		out["text"] = "La consulta se paró por el animal: no cuenta como práctica."
	else:
		out["text"] = "La práctica libre cuenta con una nota de al menos %s." % Js.to_fixed(float(PRACTICE.min_grade), 0)
	return out


## Cobra un encargo cumplido (una sola vez) y lo apunta como hecho. Devuelve si se sube de nivel.
func _complete(id: String, r: Dictionary) -> bool:
	if String((jobs.get(id, {}) as Dictionary).get("state", "")) == "hecho":
		r["ok"] = false
		r["text"] = "Este encargo ya estaba hecho: no se cobra dos veces."
		r["xp"] = 0
		r["credits"] = 0
		return false
	jobs[id] = { "state": "hecho", "grade": float(r.get("grade", 0.0)), "xp": int(r.xp), "credits": int(r.credits) }
	if active_job == id:
		active_job = ""
	return _pay(int(r.xp), int(r.credits))


# ════════════════════════════════ Las lentes y la tienda ════════════════════════════════

func owns(id: String) -> bool:
	return bool((lenses.get(id, {}) as Dictionary).get("owned", false))


## El daño guardado de una lente (el to_dict() del estado del daño de la cetrería) o {}.
func lens_damage(id: String) -> Dictionary:
	return ((lenses.get(id, {}) as Dictionary).get("damage", {}) as Dictionary).duplicate(true)


## Guarda el daño de una lente (lo que da el estado del daño de la cetrería, to_dict()).
func set_lens_damage(id: String, d: Dictionary) -> void:
	if not owns(id):
		return
	var e: Dictionary = lenses[id]
	if var_to_str(e.get("damage", {})) == var_to_str(d):
		return
	e["damage"] = d.duplicate(true)
	_touch()


## Lo que se ve a través de la lente: el índice de la cetrería (0, limpia; 1, no se ve nada; índice del juego).
func obscuration(id: String) -> float:
	var v: Variant = lens_damage(id).get("obscuration", 0.0)
	return clampf(float(v), 0.0, 1.0) if (v is float or v is int) and is_finite(float(v)) else 0.0


## ¿Se puede comprar (o reponer) la lente id? { ok, replace, price, why }.
func can_buy(id: String) -> Dictionary:
	if not LENS_SHOP.has(id):
		return { "ok": false, "replace": false, "price": 0, "why": "Esa lente no está en la tienda." }
	var sh: Dictionary = LENS_SHOP[id]
	var rep := owns(id)
	var price := int(sh.replace) if rep else int(sh.price)
	if int(sh.level) > level():
		return { "ok": false, "replace": rep, "price": price, "why": "Pide el nivel %s (tienes el %s)." % [_n(int(sh.level)), _n(level())] }
	if credits < price:
		return { "ok": false, "replace": rep, "price": price, "why": "Cuesta %s créditos y tienes %s." % [_n(price), _n(credits)] }
	return { "ok": true, "replace": rep, "price": price, "why": "" }


## Compra la lente id (o repone la misma: otra igual, sin rayones) y se la pone. { ok, text, price }.
func buy_lens(id: String) -> Dictionary:
	var c := can_buy(id)
	if not bool(c.ok):
		notice = String(c.why)
		_touch()
		return { "ok": false, "text": String(c.why), "price": int(c.price) }
	credits -= int(c.price)
	lenses[id] = { "owned": true, "damage": {} }
	lens_on = id
	var t := ("Lente nueva puesta: %s, sin rayones (%s créditos)." if not bool(c.replace) else "Otra %s, sin rayones: puesta (%s créditos).") % [String(LENS_NAMES[id]).to_lower() if bool(c.replace) else String(LENS_NAMES[id]), _n(int(c.price))]
	notice = t
	_touch()
	return { "ok": true, "text": t, "price": int(c.price) }


## Se pone una lente que ya se tiene. { ok, text }.
func wear_lens(id: String) -> Dictionary:
	if not owns(id):
		return { "ok": false, "text": "Esa lente no es tuya: cómprala antes en la tienda." }
	if lens_on != id:
		lens_on = id
		_touch()
	return { "ok": true, "text": "Puesta: %s." % String(LENS_NAMES[id]).to_lower() }


## La lente puesta: { id, name, obscuration, text, tone }.
func lens_view() -> Dictionary:
	var o := obscuration(lens_on)
	var t := "sin rayones"
	var tone := "bien"
	if o >= float(BLIND.at) - 1e-9:
		t = "ya no deja ver (%s %% tapado): la consulta no cuenta hasta cambiarla" % Js.to_fixed(o * 100.0, 0)
		tone = "mal"
	elif o >= float(BLIND.warn):
		t = "tan rayada que casi no se ve (%s %% tapado): cámbiala en la tienda" % Js.to_fixed(o * 100.0, 0)
		tone = "mal"
	elif o > 0.0:
		t = "rayada (%s %% tapado)" % Js.to_fixed(o * 100.0, 0)
		tone = "aviso"
	return { "id": lens_on, "name": String(LENS_NAMES.get(lens_on, lens_on)), "obscuration": o, "text": t, "tone": tone }


## ¿La lente puesta ya no deja ver (BLIND.at)? Entonces la consulta no cuenta hasta cambiarla (o empezar de nuevo).
func blind() -> bool:
	return obscuration(lens_on) >= float(BLIND.at) - 1e-9


## Lo que se puede hacer con la lente que ya no deja ver: { blind, text, fixes [{ id, action, text }], restart_only }. fixes:
## las lentes que se pueden poner (las tuyas que aún dejan ver) o comprar/reponer con los créditos de ahora; sin ninguna, solo
## queda empezar de nuevo (restart_only).
func blind_view() -> Dictionary:
	if not blind():
		return { "blind": false, "text": "", "fixes": [], "restart_only": false }
	var fixes: Array = []
	for id: String in LENS_IDS:
		if owns(id) and id != lens_on and obscuration(id) < float(BLIND.at) - 1e-9:
			fixes.append({ "id": id, "action": "poner", "text": "Ponerte la de %s" % String(LENS_NAMES[id]).to_lower() })
		elif bool(can_buy(id).ok):
			var c := can_buy(id)
			fixes.append({ "id": id, "action": "reponer" if bool(c.replace) else "comprar",
				"text": ("Reponer la de %s (%s créditos)" if bool(c.replace) else "Comprar la de %s (%s créditos)") % [String(LENS_NAMES[id]).to_lower(), _n(int(c.price))] })
	var t := "La lente de %s está tan rayada que ya no ves la garra (%s %% tapado): así la consulta no cuenta. " % [String(LENS_NAMES[lens_on]).to_lower(), Js.to_fixed(obscuration(lens_on) * 100.0, 0)]
	if fixes.is_empty():
		t += "No tienes otra lente ni créditos para una nueva: tendrás que empezar el juego de nuevo."
	else:
		t += "Cámbiala en la tienda de lentes o empieza el juego de nuevo."
	return { "blind": true, "text": t, "fixes": fixes, "restart_only": fixes.is_empty() }


## Empieza el juego de nuevo: nivel 1, sin experiencia ni créditos, sin encargos y con la lente de plástico nueva, como la
## primera vez (lo que se guarda, también: el programa lo escribe al cambiar).
func restart_game() -> void:
	xp = 0
	credits = 0
	best_level = 1
	lens_on = START_LENS
	lenses = { START_LENS: { "owned": true, "damage": {} } }
	jobs = {}
	active_job = ""
	last_result = {}
	_last_session = ""
	notice = "Juego nuevo: nivel 1, con la lente de plástico de serie, sin rayones."
	_touch()


## La tienda para la interfaz: [{ id, name, level, price, replace_price, owned, on, can, why, action («comprar», «reponer»,
## «poner» o «»), action_text, obscuration, quality }].
func shop_view() -> Array:
	var out: Array = []
	for id: String in LENS_IDS:
		var sh: Dictionary = LENS_SHOP[id]
		var c := can_buy(id)
		var own := owns(id)
		var action := "reponer" if own else "comprar"
		var at := ("Reponer (%s créditos)" % _n(int(sh.replace))) if own else ("Comprar (%s créditos)" % _n(int(sh.price)))
		if int(sh.price) == 0 and not own:
			at = "Comprar (gratis)"
		if own and lens_on != id:
			action = "poner"
			at = "Ponérmela"
		out.append({ "id": id, "name": String(LENS_NAMES[id]), "level": int(sh.level), "price": int(sh.price), "replace_price": int(sh.replace),
			"owned": own, "on": lens_on == id, "can": bool(c.ok) or action == "poner", "why": String(c.why) if action != "poner" else "",
			"action": action, "action_text": at, "obscuration": obscuration(id) if own else 0.0, "quality": GAME,
			"price_text": ("de serie" if int(sh.price) == 0 else "%s créditos" % _n(int(sh.price))) + (" · reponerla: %s" % _n(int(sh.replace))),
			"level_text": "nivel %s" % _n(int(sh.level)) })
	return out


# ════════════════════════════════ Guardar y recuperar ════════════════════════════════

## Todo lo que se guarda (lo mismo que escribe save_to).
func to_dict() -> Dictionary:
	var ls := {}
	for id: String in lenses:
		ls[id] = { "owned": bool((lenses[id] as Dictionary).get("owned", false)), "damage": lens_damage(id) }
	return { "version": FORMAT_VERSION, "xp": xp, "credits": credits, "best_level": best_level, "lens_on": lens_on, "active_job": active_job,
		"lenses": ls, "jobs": jobs.duplicate(true) }


## Recupera lo guardado, dato a dato y comprobando cada uno (lo que no vale se queda como al empezar). Devuelve lo que no se
## ha podido leer, en palabras ([] si todo bien).
func from_dict(d: Dictionary) -> Array:
	var bad: Array = []
	xp = _count(d.get("xp", 0), bad, "la experiencia")
	credits = _count(d.get("credits", 0), bad, "los créditos")
	best_level = clampi(_count(d.get("best_level", 1), bad, "el nivel"), 1, MAX_LEVEL)
	lenses = { START_LENS: { "owned": true, "damage": {} } }
	var ls: Variant = d.get("lenses", {})
	if ls is Dictionary:
		for id: String in LENS_IDS:
			var e: Variant = (ls as Dictionary).get(id, null)
			if e == null:
				continue
			if not (e is Dictionary):
				bad.append("la lente %s" % String(LENS_NAMES[id]).to_lower())
				continue
			var own := bool((e as Dictionary).get("owned", false)) or id == START_LENS
			var dmg: Variant = (e as Dictionary).get("damage", {})
			if not (dmg is Dictionary):
				bad.append("los rayones de la lente %s" % String(LENS_NAMES[id]).to_lower())
				dmg = {}
			if own:
				lenses[id] = { "owned": true, "damage": (dmg as Dictionary).duplicate(true) }
	else:
		bad.append("las lentes")
	var lo: Variant = d.get("lens_on", START_LENS)
	lens_on = String(lo) if lo is String and owns(String(lo)) else START_LENS
	jobs = {}
	active_job = ""
	var js: Variant = d.get("jobs", {})
	if js is Dictionary:
		for key: Variant in (js as Dictionary).keys():
			var e2: Variant = (js as Dictionary)[key]
			if not (key is String) or job(String(key)).is_empty() or not (e2 is Dictionary):
				continue
			var id := String(key)
			var st: Variant = (e2 as Dictionary).get("state", "")
			if String(st) == "hecho":
				jobs[id] = { "state": "hecho", "grade": _number((e2 as Dictionary).get("grade", 0.0)), "xp": _count((e2 as Dictionary).get("xp", 0), bad, "un encargo"),
					"credits": _count((e2 as Dictionary).get("credits", 0), bad, "un encargo") }
			elif String(st) == "en_curso":
				jobs[id] = { "state": "en_curso" }
	else:
		bad.append("los encargos")
	var aj: Variant = d.get("active_job", "")
	if aj is String and String((jobs.get(String(aj), {}) as Dictionary).get("state", "")) == "en_curso":
		active_job = String(aj)
	for id: String in jobs.keys():
		if String((jobs[id] as Dictionary).state) == "en_curso" and id != active_job:
			jobs.erase(id)
	best_level = maxi(best_level, level())
	_touch()
	return bad


## Un número entero ≥ 0 (lo que no lo es, 0 y se apunta).
static func _count(v: Variant, bad: Array, what: String) -> int:
	if (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0:
		return int(floor(float(v)))
	if not bad.has(what):
		bad.append(what)
	return 0


static func _number(v: Variant) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else 0.0


## Guarda en path (un ConfigFile: [formato] version y [progreso] los datos). No guarda si el archivo es de una versión más
## nueva (read_only) o sin ruta. Devuelve el código de error de Godot.
func save_to(path: String) -> int:
	if path == "" or read_only:
		return ERR_UNAVAILABLE
	var d := to_dict()
	var cf := ConfigFile.new()
	cf.set_value("formato", "version", FORMAT_VERSION)
	for k: String in ["xp", "credits", "best_level", "lens_on", "active_job", "lenses", "jobs"]:
		cf.set_value("progreso", k, d[k])
	return cf.save(path)


## Recupera el progreso de path (empezando de cero), tolerante a archivos viejos o rotos: si no existe, se empieza de cero;
## si no se puede leer, también, y se avisa (notice), dejando el archivo roto aparte (path + «.roto») para no perderlo; si es
## de una versión más nueva, no se toca (read_only) y se juega sin guardar. Lo que no vale de un archivo que sí se lee empieza
## de cero y se dice.
func load_file(path: String) -> void:
	from_dict({})
	notice = ""
	read_only = false
	if path == "" or not FileAccess.file_exists(path):
		return
	var cf := ConfigFile.new()
	var err := cf.load(path)
	var ver: Variant = cf.get_value("formato", "version") if err == OK and cf.has_section_key("formato", "version") else null
	if err != OK or not (ver is int or ver is float):
		_set_broken(path)
		return
	if int(ver) > FORMAT_VERSION:
		read_only = true
		notice = "Tu progreso se guardó con una versión más nueva del programa: no se toca y esta sesión no se guarda."
		return
	var d := {}
	if cf.has_section("progreso"):
		for k: String in cf.get_section_keys("progreso"):
			d[k] = cf.get_value("progreso", k)
	var bad := from_dict(d)
	if not bad.is_empty():
		notice = "Parte de tu progreso no se ha podido leer (%s): esa parte empieza de cero." % ", ".join(bad)


## El archivo no se puede leer: se deja aparte (por si se puede recuperar) y se empieza de cero, avisando.
func _set_broken(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		var aside := path.get_file() + ".roto"
		if dir.file_exists(aside):
			dir.remove(aside)
		dir.rename(path.get_file(), aside)
	notice = "No se ha podido leer tu progreso guardado (el archivo estaba dañado): empiezas de cero. El archivo de antes se ha guardado aparte."
	_touch()
