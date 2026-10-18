## Tribología biológica · cetrería y cuidado de garras: el tutorial paso a paso de cada proceso (unidad 5a). Sin estado.
##
## Cada proceso es una lista de pasos { id, title, text, check, source }:
##   - text: qué hacer y por qué, en español, con los números del modelo o de la fuente;
##   - check: la condición que ClawCare.tutorial() comprueba en el ensayo («» si el paso es solo informativo y la escena
##     lo da por hecho con un botón); las condiciones están en ClawCare.check();
##   - source: la fuente del paso.
## Los pasos cambian con el animal (sujeción o anestesia, carne viva visible o no, tenazas para garras grandes, crema en las
## rapaces) y con el material (una garra reforjada no tiene carne viva y pide la lima adecuada a su dureza).
## Uso: const Tutorial = preload("res://core/lab/claw_care_tutorial.gd"); Tutorial.steps("rapaz", "limar").
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

const PROCESS_IDS := ["preparar", "inspeccionar", "recortar", "limar", "afilar", "torno", "sangrado", "terminar", "reconstruir", "reforjada"]
const PROCESS_NAMES := {
	"preparar": "Preparar al animal", "inspeccionar": "Buscar la carne viva", "recortar": "Recortar el sobrante",
	"limar": "Limar", "afilar": "Dar la punta", "torno": "Torno o amoladora", "sangrado": "Si sangra",
	"terminar": "Desinfectar y terminar", "reconstruir": "Garra rota", "reforjada": "Garra reforjada",
	"colocar": "Colocar la pieza de la reforja", "calmar": "Tras un ataque",
}
## El proceso que entra en el tutorial con el primer ataque del animal (petición de Eric del 17-10): parar, calmarlo, curar,
## revisar la sujeción o subir la sedación, y mirar la lente; después se vuelve a donde se estaba.
const ATTACK_PROCESS := "calmar"
## El proceso de colocar a mano la pieza de la reforja (unidad 5o): entra en el tutorial cuando llega una pieza; sus
## condiciones son las de la colocación (ClawCareBond.check), no las de ClawCare.
const BOND_PROCESS := "colocar"
## Las condiciones que comprueba el estado de la página (ClawCareState.STATE_CHECKS: lo que se tiene en la mano), no ClawCare.
const STATE_CHECKS := ["mano_hemostatico", "mano_tenaza", "mano_guillotina", "mano_desbastar", "mano_afinar"]
## Las condiciones de «Colocar la pieza» que comprueba ClawCareBond.check (las demás, ClawCare.check).
const BOND_CHECKS := ["limpia", "seca", "lijada", "purgada", "aplicado", "colocada", "fijada", "sin_venda", "mezclado", "en_masa",
	"construida", "fraguada", "curada", "ojos", "sin_rebaba", "sin_escalon", "probada"]


## Los pasos de un proceso para un animal (y un material: «none» es la queratina).
static func steps(animal_id: String, process: String, inlay: String = "none") -> Array:
	var big := animal_id in ["tigre", "oso", "velociraptor"]
	var bird := animal_id == "rapaz"
	var a: Dictionary = CareData.animal(animal_id)
	var visible := bool(a.get("quick_visible", false))
	var reforged := inlay != "none"
	var out: Array = []
	match process:
		"preparar":
			if bird:
				out.append(_s("capucha", "Encapuchar", "Una rapaz adiestrada va encapuchada: a oscuras se calma. Cógela en el puño o en la percha y ponle la capucha («Capucha y toalla»).", "sujecion", CareData.SRC_SAMOUR + ", p. 916"))
				out.append(_s("toalla", "Envolver en una toalla", "Envuélvela en una toalla suave para que no se dañen las plumas; una persona rodea las alas y sujeta el ave contra el cuerpo, la otra sujeta las patas con un dedo entre los tarsos. Con un águila, una arpía o un buitre, siempre entre dos.", "sujecion", CareData.SRC_SAMOUR + ", pp. 916-917"))
				out.append(_s("isoflurano", "Si se estresa mucho", "Si el ave se estresa mucho, el veterinario la duerme con isoflurano (las rapaces lo toleran muy bien).", "", CareData.SRC_ARENT + "; " + CareData.SRC_SAMOUR))
			elif animal_id == "velociraptor":
				out.append(_s("anestesia", "Anestesia general", "«Dormido» es anestesiado: es un experimento mental. Se trata como un gran carnívoro: nadie se acerca a sus garras despierto.", "sujecion", CareData.SRC_CATTALES))
			else:
				out.append(_s("anestesia", "Sedado o anestesiado", "A un %s solo se le tocan las garras sedado a fondo o anestesiado por un veterinario de fauna (con sedación, un dolor fuerte aún le hace moverse). Hay zoológicos que le enseñan a presentar la pata, pero para recortar y limar una garra se le duerme." % String(a.name).to_lower(), "sujecion", CareData.SRC_CATTALES + "; " + CareData.SRC_ANIMALS_ASIA + "; " + CareData.SRC_BIAZA))
			out.append(_s("material", "Tener el material a mano", "Antes de empezar: cortaúñas, limas (gruesa y fina), polvo hemostático, clorhexidina diluida y buena luz.", "", CareData.SRC_SAMOUR + ", tabla 40.13; " + CareData.SRC_DREMEL_GUIDE))
		"inspeccionar":
			if reforged:
				out.append(_s("sin_carne", "Sin carne viva", "Una garra reforjada es una pieza entera de su material: no tiene carne viva ni sangra. Aquí lo que manda es la dureza.", "", CareData.SRC_FILE_TEST))
			elif visible:
				out.append(_s("trasluz", "Mirar a trasluz", "La garra es clara: a trasluz se ve la carne viva, rosada. Se corta siempre por delante de ella.", "", CareData.SRC_SAKAS + "; " + CareData.SRC_VCA))
			else:
				out.append(_s("oscura", "Garra oscura", "La carne viva no se ve. Acaba hacia la punta del hueso: en las aves, el hueso mide ~0,70 veces el estuche; o sea, el último ~30 % de la garra (~15 % según otros datos) es queratina muerta. Con el crecimiento de más, algo más.", "", CareData.SRC_HEDRICK + "; " + CareData.SRC_MANNING))
				out.append(_s("mancha", "La señal del corte", "Al acercarse, el centro del corte se ve más oscuro: para ahí.", "", CareData.SRC_DREMEL_GUIDE))
			out.append(_s("revisar", "Revisar", "Busca grietas, escamas y si la punta se clava en la almohadilla o reparte mal el peso: una garra demasiado larga hace heridas.", "", CareData.SRC_ARENT + "; " + CareData.SRC_CATTALES))
		"recortar":
			out.append(_s("remojar", "Ablandar antes de cortar", "Una garra seca es frágil: el cortaúñas la raja. Mojada o remojada unos minutos se corta limpia (y luego se deja orear para limar).", "remojada", CareData.SRC_AAD + "; " + CareData.SRC_FARRAN))
			if big:
				out.append(_s("tenaza", "Herramienta grande", "Estas garras no caben en un cortaúñas: se cortan con unas tenazas de herrador. Cógelas de la bandeja.", "mano_tenaza", CareData.SRC_CATTALES))
			else:
				out.append(_s("guillotina", "Cortaúñas de guillotina", "Las garras crecidas se cortan mejor con uno de guillotina: una hoja contra un anillo. El de tijera aprieta por los dos lados y aplasta más. Cógelo de la bandeja.", "mano_guillotina", CareData.SRC_SAMOUR + ", p. 927"))
			out.append(_s("poco", "Poco a poco", "Corta trozos pequeños y mira el corte cada vez. Recortar de más hace sangrar; cerca de la carne viva la hoja la aprieta y duele.", "sin_sangre", CareData.SRC_SAMOUR + "; " + CareData.SRC_DREMEL_GUIDE))
			out.append(_s("cara", "Limar la cara del corte", "La hoja entra como una cuña y raja la garra a lo largo por delante del corte (~1 mm en una garra seca, menos remojada). Lima la cara del corte de frente, a 90°, hasta que la grieta desaparezca; luego vuelve a darle la punta.", "sin_grieta", CareData.SRC_FARRAN + "; " + CareData.SRC_SAMOUR))
		"limar":
			out.append(_s("a_favor", "De la base a la punta", "Lima siempre en la misma dirección, de la base a la punta: en contra, los dientes levantan el borde de las láminas y la garra se deshoja. El vaivén la debilita y desafila la lima, que solo corta al empujar.", "a_favor", CareData.SRC_AAD + "; " + CareData.SRC_NICHOLSON + "; " + CareData.SRC_FARRAN))
			out.append(_s("grueso_fino", "De grueso a fino", "Primero la lima gruesa (picado bastardo) para quitar, luego la fina para dejarla lisa. Un grano más grueso arranca más en cada pasada. Coge la gruesa.", "mano_desbastar", CareData.SRC_DIN8349 + "; " + CareData.SRC_KALACSKA))
			out.append(_s("curva", "Seguir la curva", "Sigue la curva natural de la garra: no la dejes recta ni con escalones.", "curva", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_SAMOUR))
			out.append(_s("humedad", "Ni seca ni empapada", "La queratina aguanta más a la humedad natural (~55 %): seca se astilla y empapada se deshoja por las capas.", "", CareData.SRC_FARRAN + "; " + CareData.SRC_TAYLOR))
			out.append(_s("largo", "Hasta su largo", "Quita el crecimiento de más hasta la forma natural, sin acercarte a la carne viva.", "largo", CareData.SRC_SAMOUR))
		"afilar":
			out.append(_s("faceta", "Una faceta limpia", "Para dar la punta, lima una faceta alrededor del vértice con un ángulo algo más abierto que el de la garra: afila sin dejarla como una aguja.", "punta", _pattrick()))
			out.append(_s("no_aguja", "Ni aguja ni roma", "Una punta el doble de fina aguanta la cuarta parte de lado: se mella. Una el doble de roma pide ~4 veces más fuerza para pinchar.", "punta", CareData.MARGINS.source))
			out.append(_s("lima_fina", "Con la lima fina", "La punta más fina que deja una herramienta es la de su arista o su grano: la lima fina o la de diamante la dejan limpia. Coge una de las dos.", "mano_afinar", CareData.TOOTH_GEOMETRY.source + "; " + CareData.GRAIN_GEOMETRY.source))
			out.append(_s("lupa", "Parar a tiempo", "Mira la punta con la lupa mientras la faceta cierra la cara plana: para cuando quede como la natural o algo más fina. Si ha quedado como una aguja, un toque muy ligero de frente le deja una cara diminuta.", "punta", _pattrick()))
			out.append(_s("probar", "Probar la punta", "Pásala de lado por una uña con un toque ligero: una punta afilada prende y la marca, una roma resbala y una aguja se mella, porque lo que aguanta de lado crece con el cuadrado del radio.", "", _pattrick() + "; " + ClawSharpness.SRC_JOHNSON))
		"torno":
			out.append(_s("lento", "Velocidad baja", "Empieza a 6500 rpm: a 13 000 el tambor corre el doble y calienta el doble con la misma fuerza.", "", CareData.SRC_DREMEL_7300))
			out.append(_s("toques", "Toques cortos", "El roce calienta: toca unos segundos cada vez, con pausas, y sin apretar. Cuanto más cerca de la carne viva, antes llega el calor (a 1 mm, en unos 10 s).", "sin_calor", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_DIAS))
			out.append(_s("protector", "La amoladora con su protector", "La amoladora de uñas lleva un protector: la uña entra por su guía a 45°, solo asoma la punta y el polvo se queda dentro. Igual que el torno: unos segundos cada vez.", "", CareData.SRC_DREMEL_7760 + "; " + CareData.SRC_DREMEL_GUIDE))
			out.append(_s("velocidades", "Cuatro velocidades", "Sus cuatro velocidades van de 8000 a 25 000 rpm y arranca en la más baja: empieza ahí. A 25 000 rpm la banda corre tres veces más deprisa que a 8000 y calienta tres veces más con la misma fuerza (el calor es μ·F·v).", "sin_calor", CareData.SRC_DREMEL_LITE + "; " + CareData.SRC_DREMEL_GUIDE))
			out.append(_s("angulo", "A 45°", "Sujeta el torno a unos 45° para seguir la forma y la curva natural de la garra.", "", CareData.SRC_DREMEL_GUIDE))
			out.append(_s("flanco", "Solo la punta", "Cerca de la base la pared del estuche es fina: allí el torno calienta la carne viva en pocos segundos y, si insiste, la atraviesa.", "sin_sangre", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_MSD))
			if bird:
				out.append(_s("vibracion", "Cuidado en aves pequeñas", "En aves pequeñas la vibración del torno molesta: con ellas, mejor la lima.", "", CareData.SRC_MSD))
		"sangrado":
			# en el orden en que se hace (petición 51): coger el polvo, apretar hasta que pare y desinfectar
			out.append(_s("coger", "1 · Coge el polvo hemostático", "Sangra la carne viva: deja la herramienta y coge el polvo hemostático (subsulfato férrico) de la batea. El lápiz de nitrato de plata también la para, pero escuece más.", "mano_hemostatico", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_SAMOUR + "; " + CareData.SRC_COAKLEY))
			out.append(_s("hemostatico", "2 · Aprieta sobre la herida", "Un pellizco de polvo y presión moderada sobre la herida, sin soltar, hasta que pare: con el polvo, unos %s s (con el reloj ×10, %s s). Sin nada, puede tardar 5-10 minutos." % [str(int(CareData.HEMOSTASIS.agent_s.value)), str(int(CareData.HEMOSTASIS.agent_s.value / 10.0))], "hemostasia", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_MSD + "; " + CareData.SRC_VCA))
			out.append(_s("desinfectar", "3 · Desinfecta", "Parada la sangre, limpia la herida con clorhexidina diluida al 0,05 %: mata las bacterias sin retrasar la cicatrización. Sin limpiar, se puede infectar.", "desinfectada", CareData.SRC_LOZIER))
		"terminar":
			out.append(_s("desinfectar", "Desinfectar", "Si ha sangrado, limpia con clorhexidina diluida al 0,05 %: mata las bacterias sin retrasar la cicatrización.", "desinfectada", CareData.SRC_LOZIER))
			if bird:
				out.append(_s("crema", "Crema en las garras", "Después de recortar y dar forma, un poco de crema de lanolina o parafina.", "crema", CareData.SRC_SAMOUR + ", p. 927"))
				out.append(_s("percha", "Volver a su percha", "Devuélvela a su percha en un sitio tranquilo y en penumbra; revisa las perchas: las blandas no desgastan las garras.", "", CareData.SRC_SAMOUR))
			else:
				out.append(_s("despertar", "Vigilar el despertar", "Vigila la recuperación de la anestesia en un recinto tranquilo hasta que se tenga en pie.", "", CareData.SRC_CATTALES))
		"reconstruir":
			out.append(_s("parar", "Parar la sangre y limpiar", "Una garra rota deja la carne viva al aire: primero hemostasia y limpieza.", "hemostasia", CareData.SRC_SAMOUR + "; " + CareData.SRC_LOZIER))
			out.append(_s("proteger", "Proteger", "Apósito hidrocoloide y vendaje, cambiados cada 5-7 días, para que no se dañe el tejido que la hace crecer.", "", CareData.SRC_SAMOUR + ", p. 925"))
			out.append(_s("metacrilato", "Reconstrucción provisional", "Como en el pico: metacrilato con bicarbonato, que forma una capa dura como el cemento; hay que rehacerla cada 8-12 semanas porque la queratina crece.", "reconstruida", CareData.TOOLS.metacrilato.source))
			out.append(_s("crecer", "Esperar a que crezca", "Una garra arrancada tarda en rehacerse de 2 a 3 meses en una rapaz; lo que falta crece al ritmo de su especie.", "", CareData.SRC_SAMOUR + "; " + String(a.get("growth_mm_day", {}).get("source", ""))))
		"calmar":
			out.append(_s("calma_pausa", "Para y aparta las manos", "Se ha revuelto porque está demasiado estresado: suelta la herramienta y pulsa «Pausa para calmarlo». Mientras descansa no se revuelve, porque nadie le toca las garras.", "pausa", CareData.SRC_SAMOUR + ", pp. 916-917"))
			if bird:
				out.append(_s("calma_capucha", "Encapúchala o sube la sujeción", "Capucha y toalla (con un águila, una arpía o un buitre, entre dos personas): a oscuras se calma mucho antes. Si aun así se estresa mucho, el veterinario la seda o la duerme con isoflurano: con más sedación cuesta más que se revuelva, y anestesiada casi nunca.", "sujecion", CareData.SRC_SAMOUR + ", pp. 916-917; " + CareData.SRC_ARENT))
				out.append(_s("calma_espera", "Espera en penumbra", "Encapuchada y sin tocarla, espera a que la barra de estrés baje de «inquieta» antes de seguir.", "calmado", CareData.SRC_SAMOUR + ", p. 916"))
			else:
				out.append(_s("calma_sedar", "Sube la sedación o anestesia", "A un %s solo se le tocan las garras sedado a fondo o anestesiado: sube la dosis. Sedado, un dolor fuerte aún le despierta; anestesiado, casi nunca se revuelve." % String(a.name).to_lower(), "sujecion", CareData.SRC_CATTALES + "; " + CareData.SRC_ANIMALS_ASIA))
				out.append(_s("calma_distancia", "Distancia, silencio y tiempo", "Aléjate, sin ruido ni movimientos bruscos, y espera a que la barra de estrés baje de «inquieto».", "calmado", CareData.SRC_CATTALES))
			out.append(_s("calma_curar", "Cura lo que haya sangrado", "Si en el forcejeo ha sangrado alguna garra: polvo hemostático apretando hasta que pare y después clorhexidina diluida al 0,05 %.", "desinfectada", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_LOZIER))
			out.append(_s("calma_lente", "Mira la lente de la cámara", "El zarpazo puede haber rayado o rajado la lente: el paño quita las manchas, no los rayones. Con unos pocos rayones se sigue trabajando; si ya no deja ver, cámbiala en la tienda de lentes.", "", "regla del juego (la lente de la cámara)"))
			out.append(_s("calma_seguir", "Seguir con calma", "Trabaja con más cuidado: cada dolor sube su estrés y, cuanto más estresado, más probable es que se vuelva a revolver.", "", CareData.SRC_SAMOUR))
		"reforjada":
			out.append(_s("dureza", "La lima tiene que ser más dura", "Una lima solo muerde lo que es más blando que ella. La de acero (~700 HV) lima el oro, el acero y el titanio, y el vidrio y el cristal (550-600 HV) apenas; para la hematites, el cuarzo, la circonita, la alúmina, el zafiro, el rubí, la moissanita o el carburo de tungsteno hace falta diamante. Un diamante solo lo marca otro diamante, y apenas.", "lima_adecuada", CareData.SRC_FILE_TEST + "; " + CareData.SRC_FWT))
			out.append(_s("fragil", "Las frágiles se mellan", "El vidrio, el cuarzo, la alúmina, el zafiro, el rubí o el diamante no se doblan: una punta demasiado fina se mella con poca carga de lado.", "punta", _pattrick()))
			out.append(_s("sin_calor_ref", "Sin carne viva", "No hay carne viva que cuidar: la garra reforjada no sangra ni duele.", "", CareData.SRC_FILE_TEST))
	return out


## Los pasos de «Colocar la pieza de la reforja» (unidad 5o) para un método («adhesivo», «acrilico» o «resina»), la pieza
## (kind: «funda», «bloque» o «protesis») y el adhesivo. broken: la garra estaba rota (primero, la sangre).
static func bond_steps(animal_id: String, method: String, kind: String, adhesive: String = "epoxi", broken: bool = false) -> Array:
	var bird := animal_id == "rapaz"
	var out: Array = []
	if kind == "funda" and broken:
		out.append(_s("pieza", "La pieza, en la bandeja", "La prótesis tallada en el laboratorio llega sin pegar: la garra rota sigue rota hasta que la colocas tú sobre lo que queda. FICCIÓN: una prótesis dura de metal o de gema no se pega de verdad a una garra; lo real es el acrílico dental o la resina sobre el muñón, como en el pico de las aves.", "", ForgeData.SRC_FERREIRA + "; " + ForgeData.SRC_SAMOUR_REPAIR))
	elif kind == "funda":
		out.append(_s("pieza", "La pieza, en la bandeja", "La funda llega sin pegar: la garra sigue como estaba hasta que la colocas tú. FICCIÓN: una funda de metal o de gema en una garra no se hace de verdad; lo real que se le parece son las fundas de vinilo que se pegan a las uñas de los gatos y las herraduras pegadas al casco.", "", ForgeData.SRC_FERREIRA))
	elif kind == "bloque":
		out.append(_s("pieza", "La pieza, en la bandeja", "El bloque llega sin pegar: la garra rota sigue rota hasta que lo colocas tú. FICCIÓN: en la realidad una prótesis rígida se talla aparte y se pega en frío ya terminada, como una corona dental; en el animal solo se pega y se lima el acrílico o la resina.", "", ForgeData.SRC_FERREIRA + "; " + ForgeData.SRC_SAMOUR_REPAIR))
	else:
		out.append(_s("pieza", "La prótesis de verdad", "Así se reparan de verdad los picos de las aves y las uñas rotas: acrílico dental o resina, en capas sobre lo que queda, que se liman ya duros. Nada está pegado aún: lo construyes tú.", "", ForgeData.SRC_SAMOUR_REPAIR + "; " + ForgeData.SRC_MATTA))
	if broken:
		out.append(_s("parar", "Parar la sangre", "Sobre una herida que sangra no pega nada: primero hemostasia, como en «Si sangra».", "hemostasia", CareData.SRC_SAMOUR + "; " + CareData.SRC_LOZIER))
	out.append(_s("limpiar", "Limpiar y desengrasar", "Con alcohol o con clorhexidina donde va a pegar: la grasa y la suciedad no dejan que el adhesivo moje la queratina. Las fichas de los adhesivos lo piden siempre (superficies limpias y sin grasa), como el herrador limpia la pared del casco antes de pegar una herradura; sin limpiar, la unión aguanta del orden de la mitad (estimación).", "limpia", CareData.SRC_LOCTITE_401_TDS + "; " + String(CareData.BOND_PREP.dirty_source)))
	out.append(_s("secar", "Secar", "El alcohol se evapora en unos segundos; la clorhexidina es agua y se seca con una gasa. Sobre queratina mojada la unión aguanta menos: la queratina mojada es más blanda y el cianoacrilato pierde una cuarta parte.", "seca", String(CareData.BOND_PREP.dry_source) + "; " + ForgeData.SRC_LOCTITE_401))
	out.append(_s("lijar", "Lijar un poco", "Una pasada suave con la lija o la lima fina donde va a pegar, de la base a la punta: lo rugoso agarra más. En la guía de Henkel, el cianoacrilato en gel aguanta cinco veces más sobre lo rugoso que sobre lo liso, y el epoxi algo más de un tercio más. Sin quitar de más: solo la superficie.", "lijada", String(CareData.BOND_PREP.smooth_source)))
	match method:
		"adhesivo":
			out.append(_s("elegir", "El adhesivo según la holgura", "Cada adhesivo llena una holgura: el cianoacrilato en gel, hasta 0,15 mm y fija en segundos; el epoxi, hasta 3,2 mm y fija en horas; el metacrilato de las prótesis de pico y de las herraduras, hasta 12,7 mm y fija en media hora; la masilla de epoxi con acero, hasta unos 3 mm y fija en 4-6 h.", "", ForgeData.SRC_LOCTITE_GUIDE + "; " + CareData.SRC_JBWELD))
			if adhesive != "cianoacrilato":
				out.append(_s("purgar", "Purgar la cánula", "La jeringa doble mezcla los dos componentes en su proporción dentro de la cánula, pero lo primero que sale va mal mezclado: se tiran 25-50 mm antes de aplicar.", "purgada", CareData.SRC_E20HP_TDS + "; " + String(CareData.BOND_PURGE.source)))
			out.append(_s("aplicar", "Poner el adhesivo", "Un cordón sobre la pieza, con algo de más para que no queden huecos. Desde ahora corre su tiempo de trabajo: hay que colocarla antes de que empiece a curar.", "aplicado", CareData.SRC_LOCTITE_401_TDS + "; " + CareData.SRC_E20HP_TDS))
			out.append(_s("colocar", "Colocar alineada", "Coge la pieza y llévala al muñón, alineada con el eje de la garra: la silueta de la forma sana te dice dónde va. Torcida, la punta queda en otro sitio y hay que quitarla.", "colocada", String(CareData.BOND_ALIGN.source)))
			out.append(_s("sujetar", "Sujetar quieta hasta que fije", "Quieta, sin moverla, el tiempo de fijación: el cianoacrilato, unos 20 s; el metacrilato, media hora; el epoxi, unas 3 horas. Las colas lentas se sujetan con una venda. Si se suelta antes o se mueve, queda despegada o torcida.", "fijada", CareData.SRC_LOCTITE_401_TDS + "; " + CareData.SRC_H8000_TDS + "; " + String(CareData.BOND_WRAP.source)))
			if adhesive != "cianoacrilato":
				out.append(_s("venda", "Quitar la venda", "Cuando ha fijado, fuera la venda: ya aguanta su peso y sigue curando.", "sin_venda", String(CareData.BOND_WRAP.source)))
		"acrilico":
			out.append(_s("mezclar", "Mezclar el polvo y el líquido", "En el vaso, 2 partes de polvo por 1 de líquido en peso (3:1 en volumen), unos 30 s. Con más líquido hay más monómero: calienta más, encoge más y queda más blando.", "mezclado", CareData.SRC_VERACRIL + "; " + String(CareData.ACRYLIC_RATIO.source)))
			out.append(_s("masa", "Esperar a la masa", "Líquido chorrea; hacia el minuto y medio se hace masa y se modela unos minutos (3-5 min a 23 °C). Pasado ese tiempo ya no se pega: se mezcla otra.", "en_masa", CareData.SRC_VERACRIL))
			out.append(_s("capas", "En capas, con la espátula", "Cada mezcla, una capa sobre el muñón o sobre la anterior, con algo de sobra, hasta pasar del largo de la garra. Fragua en unos 10 minutos.", "construida", CareData.SRC_VERACRIL + "; " + ForgeData.SRC_SAMOUR_REPAIR))
			out.append(_s("calor", "El calor del fraguado", "El acrílico se calienta al fraguar: 56 kJ por mol de monómero. Una capa gruesa tiene más masa y calienta más la carne viva que una fina; mira la temperatura en las lecturas y, si sube, capas más finas.", "", CareData.SRC_ODIAN + "; " + ForgeData.SRC_MATTA))
			out.append(_s("fraguar", "Dejar que fragüe", "Hasta que fragüe no se lima: en fresco se embadurna. El reloj ×10 deja esperar.", "fraguada", CareData.SRC_VERACRIL))
		"resina":
			out.append(_s("lampara", "La lámpara azul", "La resina de las restauraciones se cura con luz azul (430-480 nm), donde absorbe su fotoiniciador, la canforquinona (pico en 468 nm). La lámpara UV de los geles de uñas (365-405 nm) apenas la cura: queda blanda.", "", CareData.SRC_RUEGGEBERG_2011 + "; " + CareData.SRC_ELIPAR))
			out.append(_s("ojos", "Ojos tapados y sin mirar la luz", ("Con la capucha puesta y el filtro naranja delante: " if bird else "Con los ojos del animal tapados y el filtro naranja delante: ") + "la luz azul intensa daña la retina.", "ojos", CareData.SRC_PRICE_2015))
			out.append(_s("capa_fina", "Capas finas", "Capas de 1 a 2 mm: la luz se apaga al entrar en la resina y una capa gruesa queda blanda por dentro (la norma pide que cure al menos 1,5 mm).", "", CareData.SRC_RUEGGEBERG_1994 + "; " + String(CareData.CURE_DEPTH.source)))
			out.append(_s("curar", "Curar cada capa", "La punta de la lámpara casi tocando la capa y el tiempo de la ficha (20 s): la dosis es la irradiancia por el tiempo, y lejos llega mucha menos luz. Pita cada 10 s.", "curada", CareData.SRC_Z250 + "; " + CareData.SRC_PRICE_2015))
	out.append(_s("rebaba", "Quitar lo que rebosa", "En fresco, con la espátula; ya duro, con la lima: nada se va solo.", "sin_rebaba", String(CareData.BOND_FLASH.source)))
	out.append(_s("escalon", "Limar el escalón", "Lima la unión hasta que no se note el escalón entre la pieza y la garra (menos de 0,1 mm), con una herramienta que muerda el material.", "sin_escalon", String(CareData.BOND_JOINT.source) + "; " + CareData.SRC_FILE_TEST))
	out.append(_s("forma", "La forma y la punta", "Con el indicador de la forma y la silueta de la forma sana, lima hasta la forma de la natural y da la punta con una lima que muerda ese material.", "", CareData.SRC_FILE_TEST + "; " + _pattrick()))
	out.append(_s("probar_union", "Probar la unión", "Un tirón suave de lado: si aguanta, lista para el banco; si no, se despega y te dice por qué (sucia, mojada, holgura de más, movida o sin curar).", "probada", String(CareData.BOND_TEST.source) + "; " + ForgeData.SRC_FERREIRA))
	return out


static func _s(id: String, title: String, text: String, check: String, source: String) -> Dictionary:
	return { "id": id, "title": title, "text": text, "check": check, "source": source }


static func _pattrick() -> String:
	return ClawSharpness.SRC_PATTRICK
