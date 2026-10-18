## Tribología biológica · cetrería: el estado de la página «Cetrería» (unidad 5b), sin nodos y determinista.
##
## Guarda el ensayo (una ClawCare de la unidad 5a por garra: las dos patas del animal y cada garra de cada una, unidad
## 5c), la bandeja (qué herramienta se tiene en la mano, el interruptor y
## las rpm del torno), la mano (presión y ángulo), el reloj, el tutorial (proceso y paso, de claw_care_tutorial.gd) y el
## final con su informe. Convierte cada gesto de la escena 3D en la llamada de ClawCare que le toca y da todos los textos
## con números: la escena y la interfaz solo pintan (CONTRATOS.md: la física, en core/). No calcula física: la de la
## garra es la de ClawCare; aquí solo se reparten el tiempo y los tramos de cada gesto.
##
## Gestos (la escena los manda con lo que ve el rayo del ratón; mm y s):
##   press_on(s_mm)                       aprieta la herramienta contra la garra en s (mm desde la base)
##   drag(along_mm, travel_mm, s_mm, dt)  la mueve apretando: along_mm, a lo largo de la garra (+ hacia la punta);
##                                        travel_mm, lo que desliza; s_mm, dónde toca ahora (−1: fuera de la garra)
##   release()                            la levanta (lo que quede de la pasada se lima)
##   tick(dt)                             pasa el tiempo (el reloj del ensayo; en pausa, no)
## Cada herramienta tiene su gesto (TRAY): «lima» (pasadas de hasta FILE_LENGTH_MM: file() a tramos), «torno» (con el
## motor en marcha, el contacto es file() a trozos de tiempo), «corte» (manteniendo pulsado se cierra el cortaúñas y al
## cerrarse, clip()), «presion» (hemostasis() mientras aprieta), «aplicar» (apply() de un toque) y «remojar»
## (set_humidity). Los botones y las teclas no fuerzan nada: la física decide (no cabe, no muerde, sangra…).
##
## El reloj: cada llamada de ClawCare avanza su propio tiempo (lo que dura la pasada, el toque, la presión); tick() suma
## el tiempo real y, sin gesto en marcha, lo que falta se pasa con advance() en pasos enteros de ClawCare.DT. El tiempo
## que ya ha gastado una llamada se descuenta con ClawCare.time_s(): los dos relojes no se separan.
##
## Tutorial: los pasos de ClawCare.tutorial(proceso), con su texto, su fuente y su condición. Un paso con condición se
## da por hecho cuando esa condición pasa de falsa a verdadera mientras se está en él, y el tutorial sigue solo; los
## informativos (y los que ya se cumplían) siguen con «Siguiente». Si la garra empieza a sangrar, salta a «Si sangra»
## (y, si se ha roto, a «Garra rota») y después vuelve donde estaba. Cada paso lleva la zona que la escena resalta y la
## herramienta que se sugiere (STEP_HINTS, STEP_TOOLS: presentación, no pasos nuevos).
##
## La carne viva de una garra oscura no se revela antes de terminar (docs/fisica/cetreria.md §10): mientras no se ve, la
## vista no lleva ni su posición ni su perfil; se enseña la banda de la población (el núcleo mide de min a max veces el
## estuche, CareData.ANIMALS[…].core_ratio) y la señal del corte (claw.sign).
## Las dos patas (unidad 5c): cada garra de cada pata es su propia ClawCare (su carne viva, con su propia semilla, en la
## banda de su animal); `care` y `calls` son los de la garra elegida (select_claw, set_paw, set_digit, cycle_paw,
## cycle_digit). El animal es uno (unidad 5g): sus garras comparten un ClawCarePatient (patient), con la sujeción, el dolor,
## los movimientos y el estrés, así que trabajar otra garra no los borra y el reloj de la sujeción cuenta una sola vez; la
## humedad y las herramientas son de la garra que se trabaja. Al cambiar de garra, la nueva se pone al día con el reloj de
## la que se deja (advance: lo que pasa sin tocarla); una que sangra sigue su reloj aunque no se vea. Todas las llamadas
## del ensayo quedan en history, en orden y con su garra, para repetirlo entero.
## Uso: var st := ClawCareState.new(); st.pick("lima_bastarda"); st.press_on(30.0); st.drag(8.0, 8.0, 31.0, 0.1)…
##      var v := st.view()   # instantánea, informe, bandeja, mano, tutorial, textos, pistas y efectos
extends RefCounted

const ClawCare = preload("res://core/lab/claw_care.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const Kit = preload("res://core/lab/claw_care_kit.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const SharpenHelp = preload("res://core/lab/claw_care_sharpen_help.gd")
const Velociraptor = preload("res://core/lab/velociraptor.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Format = preload("res://core/shared/format.gd")
const SfxCare = preload("res://core/lab/sfx_care.gd")
const Bond = preload("res://core/lab/claw_care_bond.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const CareAnatomy = preload("res://core/lab/care_anatomy.gd")
## La reacción del animal estresado y la lente de la cámara (unidad 5t-A).
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const Lens = preload("res://core/lab/claw_care_lens.gd")

## La bandeja: cada herramienta con su gesto, su nombre corto y su tecla (1-5: lima gruesa, lima fina, torno, cortaúñas
## y amoladora; 0 sin tecla). Las de gesto «torno» (el torno y la amoladora) son giratorias: interruptor y velocidades. Los datos de cada una están en CareData.TOOLS; «presion» es apretar con una gasa, sin
## hemostático (ClawCare.hemostasis con tool «»), y «agua», remojar la garra (set_humidity «humeda»).
const TRAY := [
	{ "id": "lima_bastarda", "gesture": "lima", "short": "Lima gruesa", "key": 1 },
	{ "id": "lima_fina", "gesture": "lima", "short": "Lima fina", "key": 2 },
	{ "id": "torno", "gesture": "torno", "short": "Torno", "key": 3 },
	{ "id": "guillotina", "gesture": "corte", "short": "Cortaúñas", "key": 4 },
	{ "id": "amoladora", "gesture": "torno", "short": "Amoladora", "key": 5 },
	{ "id": "lima_entrefina", "gesture": "lima", "short": "Lima entrefina", "key": 0 },
	{ "id": "lima_diamante_gruesa", "gesture": "lima", "short": "Diamante gruesa", "key": 0 },
	{ "id": "lima_diamante_fina", "gesture": "lima", "short": "Diamante fina", "key": 0 },
	{ "id": "lija_p180", "gesture": "lima", "short": "Lija P180", "key": 0 },
	{ "id": "lija_p240", "gesture": "lima", "short": "Lija P240", "key": 0 },
	{ "id": "tijera", "gesture": "corte", "short": "Cortaúñas de tijera", "key": 0 },
	{ "id": "tenaza", "gesture": "corte", "short": "Tenazas", "key": 0 },
	{ "id": "agua", "gesture": "remojar", "short": "Agua tibia", "key": 0 },
	{ "id": "presion", "gesture": "presion", "short": "Gasa", "key": 0 },
	{ "id": "hemostatico", "gesture": "presion", "short": "Hemostático", "key": 0 },
	{ "id": "nitrato_plata", "gesture": "presion", "short": "Nitrato de plata", "key": 0 },
	{ "id": "clorhexidina", "gesture": "aplicar", "short": "Clorhexidina", "key": 0 },
	{ "id": "crema", "gesture": "aplicar", "short": "Crema", "key": 0 },
	{ "id": "metacrilato", "gesture": "aplicar", "short": "Metacrilato", "key": 0 },
	# unidad 5o: colocar a mano la pieza de la reforja (limpiar con alcohol; la espátula del acrílico, de la resina y de lo
	# que rebosa en fresco)
	{ "id": "alcohol", "gesture": "aplicar", "short": "Alcohol", "key": 0 },
	{ "id": "espatula", "gesture": "aplicar", "short": "Espátula", "key": 0 },
]
## Las dos herramientas de la bandeja que no están en CareData.TOOLS.
const EXTRA_TOOLS := {
	"agua": { "id": "agua", "name": "Agua tibia para remojar la garra", "kind": "agua", "source": CareData.SRC_AAD },
	"presion": { "id": "presion", "name": "Gasa: solo presión", "kind": "presion", "source": CareData.SRC_VCA },
	"alcohol": { "id": "alcohol", "name": "Alcohol isopropílico para limpiar y desengrasar", "kind": "limpiar", "source": CareData.SRC_LOCTITE_GUIDE_T7 },
	"espatula": { "id": "espatula", "name": "Espátula: el acrílico, la resina y lo que rebosa en fresco", "kind": "espatula", "source": CareData.SRC_VERACRIL },
}

## La mano (elección de la interfaz, no datos): la presión va de FORCE_MIN a FORCE_MAX N, en pasos de ×FORCE_STEP (W/S)
## o ×FORCE_WHEEL (Mayús + rueda), y empieza en la de ClawCare.file() por defecto; el ángulo de la pasada (semiángulo de
## la faceta con el eje de la garra), de 1° a 90° (≥ ClawCare.TRUNCATE_DEG: de frente), empieza a 45°, el de la guía de
## Dremel para sujetar el torno.
const FORCE_MIN := 0.2
const FORCE_MAX := 10.0
const FORCE_DEFAULT := 3.0
const FORCE_STEP := 1.25
const FORCE_WHEEL := 1.1
const ANGLE_MIN := 1.0
const ANGLE_MAX := 90.0
const ANGLE_DEFAULT := 45.0
## Una pasada de lima se lima a tramos: cada STROKE_CHUNK_MM de recorrido o cada STROKE_CHUNK_S (lo que llegue antes).
const STROKE_CHUNK_MM := 4.0
const STROKE_CHUNK_S := 0.12
## La pasada más larga (mm): el largo de la lima de 150 mm de DIN 8349 (la de 13, 18 y 22 dientes por cm). Pasado ese
## recorrido la lima ya no toca: hay que levantarla y volver a empezar.
const FILE_LENGTH_MM := 150.0
## Velocidad de la pasada (mm/s): la del arrastre, entre estos topes (elección de la interfaz).
const SPEED_MIN := 5.0
const SPEED_MAX := 500.0
## Zona de la punta: a menos de TIP_ZONE_FRACTION del largo natural del vértice (y al menos TIP_ZONE_MIN_MM) se lima la
## punta (faceta o de frente); más atrás, el flanco (elección de la interfaz).
const TIP_ZONE_FRACTION := 0.15
const TIP_ZONE_MIN_MM := 2.0
## Largo del contacto de la lima en el flanco (mm): el de ClawCare.file() por defecto.
const FLANK_CONTACT_MM := 3.0
## Manteniendo pulsado, el cortaúñas se cierra en CLIP_CLOSE_S (dibujo del gesto).
const CLIP_CLOSE_S := 0.45
## La presión con el hemostático o la gasa se pasa a hemostasis() cada PRESS_CHUNK_S.
const PRESS_CHUNK_S := 0.25
## El contacto del torno se pasa a file() cada ROTARY_CHUNK_S (el trozo de ClawCare).
const ROTARY_CHUNK_S := ClawCare.ROTARY_CHUNK_S
## Un mismo efecto de sonido de las pasadas no se repite antes de SFX_GAP_S (s del ensayo): una pasada suena una vez.
const SFX_GAP_S := 0.3
## Efectos que se guardan para la escena (sonidos, polvo, sangre…): los últimos FX_LOG.
const FX_LOG := 24
## Sucesos que se enseñan: los últimos EVENTS_SHOWN.
const EVENTS_SHOWN := 6

## Procesos del tutorial en el orden en que se hacen. «sangrado» y «reconstruir» entran solo si hace falta; «reforjada»
## sustituye a «recortar» en una garra reforjada, y «torno» es solo para la queratina (el calor llega a la carne viva).
const FLOW_KERATIN := ["preparar", "inspeccionar", "recortar", "limar", "afilar", "torno", "terminar"]
const FLOW_REFORGED := ["preparar", "inspeccionar", "reforjada", "limar", "afilar", "terminar"]
## Zona que la escena resalta en cada paso del tutorial (por el id del paso de claw_care_tutorial.gd):
##   «sobrante» (el crecimiento de más), «banda» (donde acaba la carne viva según la población), «carne_viva» (la que se
##   ve a trasluz), «punta», «angulo» (la guía del ángulo bueno de la faceta), «base» (donde la pared es fina),
##   «herida», «pasada» (la flecha de la base a la punta), «garra» (toda) y «bandeja».
const STEP_HINTS := {
	"material": "bandeja", "trasluz": "carne_viva", "oscura": "banda", "mancha": "punta", "revisar": "garra",
	"sin_carne": "garra", "remojar": "garra", "tenaza": "sobrante", "guillotina": "sobrante", "poco": "sobrante",
	"cara": "punta", "a_favor": "pasada", "grueso_fino": "sobrante", "curva": "angulo", "humedad": "garra",
	"largo": "sobrante", "faceta": "angulo", "no_aguja": "punta", "lima_fina": "punta", "lupa": "punta",
	"lento": "punta", "toques": "punta", "angulo": "angulo", "flanco": "base", "hemostatico": "herida",
	"nitrato": "herida", "coger": "herida", "desinfectar": "herida", "crema": "garra", "parar": "herida", "proteger": "herida",
	"metacrilato": "herida", "dureza": "garra", "fragil": "punta", "protector": "angulo", "velocidades": "punta",
	"probar": "punta",
}
## Herramienta que se sugiere en cada paso (se resalta en la bandeja). «cortaunas»: la del paso anterior del proceso
## (tenazas en los animales grandes; guillotina en la rapaz).
const STEP_TOOLS := {
	"remojar": "agua", "tenaza": "tenaza", "guillotina": "guillotina", "poco": "cortaunas", "cara": "lima_bastarda",
	"a_favor": "lima_bastarda", "grueso_fino": "lima_bastarda", "largo": "lima_bastarda", "curva": "lima_bastarda",
	"faceta": "lima_fina", "no_aguja": "lima_fina", "lima_fina": "lima_fina", "lupa": "lima_fina", "lento": "torno",
	"toques": "torno", "angulo": "torno", "flanco": "torno", "hemostatico": "hemostatico", "nitrato": "nitrato_plata", "coger": "hemostatico",
	"desinfectar": "clorhexidina", "crema": "crema", "parar": "hemostatico", "metacrilato": "metacrilato",
	"dureza": "lima_diamante_fina", "fragil": "lima_diamante_fina", "protector": "amoladora", "velocidades": "amoladora",
	# colocar la pieza de la reforja (unidad 5o)
	"limpiar": "alcohol", "secar": "presion", "lijar": "lija_p240", "capas": "espatula", "capa_fina": "espatula",
	"rebaba": "espatula", "escalon": "lima_bastarda",
}

## Qué control se usa en cada paso del tutorial (el ratón, el dedo o las teclas de la página): presentación, no pasos
## nuevos. Los colores son los de las zonas que resalta la escena (STEP_HINTS).
const STEP_CONTROLS := {
	"capucha": "En «Preparar al animal», elige «Capucha y toalla».",
	"toalla": "En «Preparar al animal», elige «Capucha y toalla».",
	"isoflurano": "Si hiciera falta: «Anestesia» en «Preparar al animal».",
	"anestesia": "En «Preparar al animal», elige «Anestesia».",
	"material": "Vista «General» (tecla V): la bandeja de las herramientas y la batea de las curas, en el carro.",
	"trasluz": "Vista «La garra» (tecla V). Botón derecho: girar la cámara; rueda: acercar (en el teléfono, dos dedos).",
	"oscura": "Vista «Sección» (tecla V): el corte a lo largo de la garra, con la franja rosa de la población.",
	"mancha": "Vista «La garra»: mira la punta (en azul) después de cada corte.",
	"revisar": "Vista «La garra» (tecla V); gira la cámara con el botón derecho para verla por todos los lados.",
	"sin_carne": "Vista «Sección» (tecla V): una pieza entera de su material.",
	"remojar": "Clic en el agua tibia de la batea y otro clic sobre la garra.",
	"tenaza": "Clic en las tenazas de la bandeja.",
	"guillotina": "Tecla 4 o clic en el cortaúñas de guillotina de la bandeja.",
	"poco": "Mantén pulsado el botón izquierdo (o el dedo) sobre la garra donde quieras cortar: el cortaúñas se cierra solo.",
	"cara": "Tecla 1 (lima gruesa); D hasta «de frente» y arrastra sobre la punta. W/S o Mayús + rueda: la presión.",
	"a_favor": "Arrastra a lo largo de la garra, de la base hacia la punta (la flecha verde); suelta y vuelve a empezar.",
	"grueso_fino": "Tecla 1: la lima gruesa; tecla 2: la fina.",
	"curva": "A/D o Mayús + arrastrar sobre la garra hasta el ángulo de la guía dorada.",
	"humedad": "En «Preparar al animal», la humedad: «Natural» para limar.",
	"largo": "Sigue limando de la base a la punta hasta que desaparezca la franja dorada del sobrante.",
	"faceta": "Tecla 2 (lima fina), A/D hasta la guía dorada y pasadas cortas sobre la punta.",
	"no_aguja": "Mira «Punta» y «Aguanta de lado» en las lecturas después de cada pasada.",
	"lima_fina": "Tecla 2: la lima fina (o la de diamante de la bandeja).",
	"lupa": "Pasadas cortas con la lima fina sobre la punta; para cuando «Punta» quede como la natural o algo más fina.",
	"probar": "Botón «Probar la punta» (o tecla T): apoya el vértice en una uña con un toque ligero.",
	"lento": "Tecla 3 (torno), E para encenderlo y Q para cambiar de velocidad.",
	"toques": "Mantén pulsado unos segundos y suelta; Espacio para el reloj.",
	"angulo": "A/D o Mayús + arrastrar hasta 45°.",
	"protector": "Tecla 5 o clic en la amoladora del carro: su protector la apoya a 45°. E (o un clic en el aire, fuera de la garra) la enciende.",
	"velocidades": "Q cambia de velocidad: 8000, 14 000, 21 000 y 25 000 rpm. Mayús + rueda (o el deslizador): cuánto aprietas.",
	"flanco": "Toca solo la punta (en azul), lejos de la base.",
	"vibracion": "Mejor las limas: teclas 1 y 2.",
	"hemostatico": "Coge el polvo hemostático (su bote de la batea o «Hemostático») y mantén pulsado sobre la garra que sangra unos 30 s, o 3 s con el reloj ×10. El texto de arriba dice cuánto falta.",
	"nitrato": "Clic en el lápiz de nitrato de plata y otro sobre la herida.",
	"coger": "Clic en el bote del polvo hemostático de la batea (o «Hemostático» en «Curas»).",
	"desinfectar": "Clic en la clorhexidina de la batea y otro sobre la garra.",
	"crema": "Clic en la crema de la batea y otro sobre la garra.",
	"percha": "Pulsa «Terminar y ver el informe».",
	"despertar": "Pulsa «Terminar y ver el informe».",
	"parar": "Polvo hemostático de la batea y presión sobre la herida (como en «Si sangra»).",
	"proteger": "Sigue con «Siguiente».",
	"metacrilato": "Clic en el metacrilato de la batea y otro sobre la garra rota.",
	"crecer": "Pulsa «Terminar y ver el informe».",
	"dureza": "Coge una lima más dura que el material: las de diamante, en la bandeja.",
	"fragil": "Pasadas suaves con la lima de diamante fina; mira «Aguanta de lado» en las lecturas.",
	"sin_calor_ref": "Sigue con «Siguiente».",
	# colocar la pieza de la reforja (unidad 5o)
	"pieza": "Tarjeta «Colocar la pieza de la reforja»: la pieza espera en la bandeja de la colocación, junto al carro.",
	"limpiar": "Botón «Limpiar con alcohol» (o el alcohol de la bandeja y un clic sobre la garra).",
	"secar": "El alcohol se evapora solo; la clorhexidina, con la gasa apretada sobre la garra unos segundos.",
	"lijar": "«Coger la lija P240» y una pasada suave sobre donde va a pegar, de la base a la punta.",
	"elegir": "Elige el adhesivo en la tarjeta: los que no llenan la holgura lo dicen.",
	"purgar": "Botón «Purgar la cánula».",
	"aplicar": "Botón «Poner el adhesivo».",
	"colocar": "«Coger la pieza» (o un clic sobre ella en la bandeja), llévala al muñón con el ratón o el dedo y gírala con A/D hasta el eje.",
	"sujetar": "Mantén pulsado el botón izquierdo (o el dedo, o la tecla K, o «Apretar y sujetar») sin moverlo hasta que fije; las colas lentas, «Vendar».",
	# tras un ataque (petición de Eric del 17-10)
	"calma_pausa": "Botón «Pausa para calmarlo», arriba de la vista: suelta la herramienta y aparta las manos.",
	"calma_capucha": "«Capucha y toalla» en «Preparar al animal»; si sigue muy estresada, «Sedación» o «Anestesia».",
	"calma_espera": "No toques nada: mira cómo baja la barra de estrés (Espacio acelera el reloj).",
	"calma_sedar": "«Sedación» o, mejor, «Anestesia» en «Preparar al animal».",
	"calma_distancia": "No toques nada: mira cómo baja la barra de estrés (Espacio acelera el reloj).",
	"calma_curar": "Si sangra: el polvo hemostático de la batea, apretando, y después la clorhexidina.",
	"calma_lente": "«Tu consulta de veterinario» dice lo rayada que está la lente; la tienda tiene su botón arriba de la vista.",
	"calma_seguir": "Pulsa «Seguir trabajando» y vuelve al paso en que estabas.",
	"venda": "Botón «Quitar la venda».",
	"mezclar": "Elige la proporción y pulsa «Mezclar en el vaso».",
	"masa": "Espera con el reloj (×10 o ×60) hasta que la tarjeta diga «en masa».",
	"capas": "La espátula de la bandeja y un clic sobre el muñón (o «Aplicar la capa»); fina o gruesa, en la tarjeta.",
	"calor": "Mira «carne viva a … °C» en la tarjeta mientras fragua.",
	"fraguar": "Espera con el reloj ×60.",
	"lampara": "Elige la lámpara, la distancia y el tiempo en la tarjeta.",
	"ojos": "Botón «Tapar los ojos y el filtro».",
	"capa_fina": "«Capa fina (1 mm)» en la tarjeta.",
	"curar": "Botón «Encender la lámpara» (o la tecla L).",
	"rebaba": "En fresco, la espátula sobre la unión; ya duro, la lima sobre la unión.",
	"escalon": "La lima sobre la unión, pasadas suaves, hasta que la tarjeta diga que no se nota.",
	"forma": "La silueta de la forma sana (F) y el indicador de la forma; la lima que muerda ese material.",
	"probar_union": "Botón «Probar la unión».",
}
## El objetivo de cada paso del tutorial, en pocas palabras (petición 51: «un objetivo claro por paso»). Presentación.
const STEP_GOALS := {
	"capucha": "Encapucha al ave", "toalla": "Envuélvela en la toalla", "isoflurano": "Si se estresa mucho: anestesia",
	"anestesia": "Anestesia al animal", "material": "Ten el material a mano", "sin_carne": "Sin carne viva: manda la dureza",
	"trasluz": "Mira la carne viva a trasluz", "oscura": "La carne viva no se ve: calcúlala", "mancha": "Para si el corte se oscurece",
	"revisar": "Busca grietas y escamas", "remojar": "Remoja la garra con agua tibia", "tenaza": "Coge las tenazas",
	"guillotina": "Coge el cortaúñas de guillotina", "poco": "Corta un trozo pequeño", "cara": "Lima la cara del corte, de frente",
	"a_favor": "Lima de la base a la punta", "grueso_fino": "Primero la lima gruesa", "curva": "Sigue la curva de la garra",
	"humedad": "Ni seca ni empapada", "largo": "Lima hasta su largo natural", "faceta": "Lima una faceta en la punta",
	"no_aguja": "Ni aguja ni roma", "lima_fina": "Coge la lima fina", "lupa": "Para a tiempo", "probar": "Prueba la punta en una uña",
	"lento": "Empieza a la velocidad baja", "toques": "Toques cortos con el torno", "protector": "La amoladora, con su protector",
	"velocidades": "Empieza en 8000 rpm", "angulo": "Sujétala a 45°", "flanco": "Solo la punta, lejos de la base",
	"vibracion": "En aves pequeñas, mejor la lima", "coger": "Coge el polvo hemostático", "hemostatico": "Aprieta sobre la herida",
	"desinfectar": "Desinfecta con clorhexidina", "crema": "Pon crema en las garras", "percha": "Termina y mira el informe",
	"despertar": "Termina y mira el informe", "parar": "Para la sangre", "proteger": "Protege la herida",
	"metacrilato": "Reconstrúyela con metacrilato", "crecer": "Crecerá en 2-3 meses", "dureza": "Coge una lima más dura que ella",
	"fragil": "Cuidado: las frágiles se mellan", "sin_calor_ref": "Sin carne viva que cuidar",
	# tras un ataque
	"calma_pausa": "Para y aparta las manos", "calma_capucha": "Encapúchala o sube la sujeción", "calma_espera": "Espera a que se calme",
	"calma_sedar": "Sube la sedación", "calma_distancia": "Espera a que se calme", "calma_curar": "Cura lo que sangre",
	"calma_lente": "Mira la lente de la cámara", "calma_seguir": "Sigue con calma",
	# colocar la pieza de la reforja (unidad 5o)
	"pieza": "La pieza espera en la bandeja", "limpiar": "Limpia donde va a pegar", "secar": "Déjala seca", "lijar": "Lija un poco donde pega",
	"elegir": "Elige el adhesivo", "purgar": "Purga la cánula", "aplicar": "Pon el adhesivo en la pieza", "colocar": "Coloca la pieza alineada",
	"sujetar": "Sujétala hasta que fije", "venda": "Quita la venda", "mezclar": "Mezcla el polvo y el líquido", "masa": "Espera a la masa",
	"capas": "Aplica las capas con la espátula", "calor": "Vigila el calor del fraguado", "fraguar": "Deja que fragüe",
	"lampara": "La lámpara azul, la buena", "ojos": "Tapa los ojos del animal", "capa_fina": "Capas finas", "curar": "Cura cada capa con la lámpara",
	"rebaba": "Quita lo que rebosa", "escalon": "Lima el escalón de la unión", "forma": "La forma y la punta, a mano", "probar_union": "Prueba la unión",
}
## El mando de la página que hay que pulsar en cada paso (petición 51: «el botón resaltado en la interfaz»): «sedacion:id»,
## «humedad:id», «vista:id», «reloj:×», «boton:id» (probar, terminar) o «pieza:id» (la tarjeta de la colocación). Presentación.
const STEP_UI := {
	"capucha": "sedacion:sujecion", "toalla": "sedacion:sujecion", "isoflurano": "sedacion:anestesia", "anestesia": "sedacion:anestesia",
	"material": "vista:general", "trasluz": "vista:garra", "oscura": "vista:seccion", "revisar": "vista:garra", "sin_carne": "vista:seccion",
	"humedad": "humedad:natural", "probar": "boton:probar", "hemostatico": "reloj:10", "percha": "boton:terminar", "despertar": "boton:terminar",
	"limpiar": "pieza:alcohol", "secar": "pieza:gasa", "lijar": "pieza:lija", "purgar": "pieza:purgar", "aplicar": "pieza:aplicar",
	"colocar": "pieza:coger", "sujetar": "pieza:sujetar", "venda": "pieza:quitar_venda", "mezclar": "pieza:mezclar", "masa": "reloj:60",
	"capas": "pieza:capa", "fraguar": "reloj:60", "ojos": "pieza:ojos", "curar": "pieza:lampara", "rebaba": "pieza:espatula",
	"escalon": "pieza:lima", "probar_union": "pieza:probar",
	"calma_capucha": "sedacion:sujecion", "calma_sedar": "sedacion:anestesia",
}
## Los pasos cuya condición ya se cumple sin hacer nada (no sangrar, no calentar, sin grieta, la faceta que sigue la curva): se
## dan por hechos cuando, además, se ha hecho lo suyo desde que se llegó a ellos: [qué, cuántas veces] («corte», «pasada»,
## «faceta», «toque» del torno o «prueba» de la punta).
const STEP_ACTION := {
	"poco": ["corte", 1], "cara": ["pasada", 1], "curva": ["faceta", 1], "toques": ["toque", 2], "velocidades": ["toque", 1],
	"flanco": ["toque", 1], "probar": ["prueba", 1],
}
## Los pasos informativos siguen solos cuando ha dado tiempo a leerlos: READ_S_PER_WORD por palabra, entre READ_MIN_S y
## READ_MAX_S (s reales; elección de la interfaz). «Siguiente» sigue estando para quien ya lo sabe.
const READ_S_PER_WORD := 0.22
const READ_MIN_S := 3.5
const READ_MAX_S := 9.0
## Para qué sirve cada herramienta de limar y en qué orden (petición 51, «las limas, claras»): [papel, orden, para qué]. De grueso
## a fino, como dice el tutorial (DIN 8349: el picado bastardo arranca más y el fino deja la superficie lisa; las de diamante, para
## lo que es más duro que el acero). Presentación con los datos de cada una (CareData.TOOLS).
const TOOL_GUIDE := {
	"lima_bastarda": ["desbastar", 1, "quita mucho en cada pasada: el sobrante y la forma"],
	"lima_entrefina": ["afinar", 2, "entre la gruesa y la fina: quita las rayas gruesas"],
	"lima_fina": ["afinar", 2, "deja la superficie lisa y da la punta"],
	"lima_diamante_gruesa": ["desbastar", 1, "para lo duro (gemas, cerámicas, metal duro): muerde donde el acero resbala"],
	"lima_diamante_fina": ["pulir", 3, "para lo duro: afina, pule y da la punta"],
	"lija_p180": ["afinar", 2, "alisa las rayas de la lima"],
	"lija_p240": ["pulir", 3, "pule: la superficie más fina de las de mano"],
	"torno": ["desbastar", 1, "quita deprisa, pero calienta: toques de unos segundos"],
	"amoladora": ["desbastar", 1, "como el torno, apoyada en su protector a 45°: toques de unos segundos"],
}
const ROLE_NAMES := { "desbastar": "desbastar, 1.º", "afinar": "afinar, 2.º", "pulir": "pulir, 3.º" }
## Las condiciones que comprueba el estado (no ClawCare): «mano_hemostatico», «mano_desbastar», «mano_afinar», «mano_tenaza»,
## «mano_guillotina» (lo que se tiene en la mano) y «accion» (lo de STEP_ACTION).
const STATE_CHECKS := {
	"mano_hemostatico": ["hemostatico", "nitrato_plata"], "mano_tenaza": ["tenaza"], "mano_guillotina": ["guillotina"],
	"mano_desbastar": ["lima_bastarda", "lima_diamante_gruesa", "torno", "amoladora"],
	"mano_afinar": ["lima_fina", "lima_entrefina", "lima_diamante_fina", "lija_p180", "lija_p240"],
}
## Qué paso del tutorial arregla cada error que avisa el motor (código del suceso → [proceso, paso]): el texto y la
## fuente del arreglo son los del paso (claw_care_tutorial.gd).
const MISTAKE_FIX := {
	"carne_viva": ["sangrado", "hemostatico"], "pared": ["sangrado", "hemostatico"], "raja": ["reconstruir", "metacrilato"],
	"grieta": ["recortar", "cara"], "deshoja": ["limar", "a_favor"], "mella": ["afilar", "no_aguja"],
	"aplasta": ["recortar", "guillotina"], "aplasta_punta": ["recortar", "poco"], "calor": ["torno", "toques"],
	"quemadura": ["torno", "flanco"], "no_muerde": ["reforjada", "dureza"], "no_cabe": ["recortar", "tenaza"],
	"no_corta": ["reforjada", "dureza"], "se_mueve": ["preparar", "toalla"],
}
## Qué error se explica primero cuando un gesto da varios: la sangre, luego la garra rota o quemada, y el resto.
const MISTAKE_RANK := { "carne_viva": 3, "pared": 3, "raja": 2, "quemadura": 2 }
## Calidad de un dato, en palabras (como en «Fuentes y estimaciones» del coche en marcha).
const QUALITY_TEXT := { "primary": "dato medido", "secondary": "dato de un caso parecido", "estimate": "estimación" }
## Restos de rutas y de nombres internos que no se enseñan en las fuentes: rutas de la documentación y del código,
## apartados (§), fichas y constantes del motor y unidades de trabajo.
const INTERNAL_RE := "docs/[A-Za-z0-9_./-]+|(?:core|app|tests|tools)/[A-Za-z0-9_./-]+|\\b[A-Za-z0-9_]+\\.gd\\b|,?\\s*§\\s*[0-9.]*[0-9]|\\b(?:Data|Physics|CareData|ClawCare|ClawSharpness|ClawsV2|ClawMass|ClawFracture|MovingCar|Velociraptor|Contact)\\.[A-Za-z_][A-Za-z0-9_.]*|,?\\s*\\bunidad\\s+[0-9]+[a-z]?(?:-[A-Z0-9]+)?|\\([A-Z]+_[A-Z_]+\\)"
## Lo que se queda colgando al quitar una ruta («el mismo dato de …», «como en …»).
const DANGLING_RE := "\\(\\s*(?:el mismo dato (?:de|del|que)|el dato de|la misma conversión que|como en|la de|lo de)\\s*\\)|,?\\s*(?:el mismo dato (?:de|del|que)|el dato de|la misma conversión que|como en|la de)\\s*(?=[;)]|$)"

## Nombres legibles de las fuentes (el texto completo va en la ayuda): [cita completa, nombre corto]. Se sustituyen de
## la más larga a la más corta.
const SOURCE_NAMES := [
	[CareData.SRC_SAMOUR, "Samour 2006 (Clinical Avian Medicine)"],
	[CareData.SRC_ARENT, "Arent y Pollock, LafeberVet"],
	[CareData.SRC_MSD, "Manual Veterinario MSD"],
	[CareData.SRC_SAKAS, "Sakas, Niles Animal Hospital"],
	[CareData.SRC_HEDRICK, "Hedrick et al. 2019"],
	[Velociraptor.SRC_HEDRICK_2019, "Hedrick et al. 2019"],
	[CareData.SRC_MANNING, "Manning et al. 2006"],
	[Velociraptor.SRC_MANNING_2006, "Manning et al. 2006"],
	[CareData.SRC_HOMBERGER, "Homberger et al. 2009"],
	[CareData.SRC_CONTRERAS, "Contreras et al. 2025"],
	[CareData.SRC_ETHIER, "Ethier et al. 2010"],
	[CareData.SRC_BEARHOP, "Bearhop et al. 2003"],
	[CareData.SRC_TAYLOR, "Taylor, Bonser y Farrent 2004"],
	[CareData.SRC_FARRAN, "Farran, Ennos y Eichhorn 2008"],
	[CareData.SRC_FARREN, "Farren, Shayler y Ennos 2004"],
	[CareData.SRC_AAD, "Academia Americana de Dermatología"],
	[CareData.SRC_DIAS, "Dias et al. 2007"],
	[CareData.SRC_PICARD, "Picard et al. 1999"],
	[CareData.SRC_DUBIN, "Dubin y Patapoutian 2010"],
	[CareData.SRC_PAN, "Pan et al. 2024"],
	[CareData.SRC_JORDT, "Jordt y Julius 2002"],
	[CareData.SRC_MORITZ, "Moritz y Henriques 1947"],
	[CareData.SRC_DREMEL_7300, "ficha del Dremel 7300-PT"],
	[CareData.SRC_DREMEL_7760, "ficha del Dremel 7760-PGK PawControl"],
	[CareData.SRC_DREMEL_LITE, "manual de la Dremel Lite 7760"],
	[CareData.SRC_DREMEL_GUIDE, "guía de Dremel para cortar las uñas del perro"],
	[CareData.SRC_DIN8349, "DIN 8349 (catálogo de limas de PFERD)"],
	[CareData.SRC_FWT, "limas de taller de FWT"],
	[CareData.SRC_FILE_TEST, "HolzWerken 2024 (prueba de dureza con limas)"],
	[CareData.SRC_NICHOLSON, "guía de limas de Nicholson"],
	[CareData.SRC_DMT, "DMT (limas de diamante)"],
	[CareData.SRC_KLINGSPOR, "Klingspor (granos FEPA P)"],
	[CareData.SRC_KALACSKA, "Kalácska et al. 2021"],
	[CareData.SRC_VCA, "VCA Animal Hospitals"],
	[CareData.SRC_COAKLEY, "Coakley et al. 2020"],
	[CareData.SRC_LOZIER, "Lozier, Pope y Berg 1992"],
	[CareData.SRC_CATTALES, "Cat Tales Wildlife Center 2024"],
	[CareData.SRC_ANIMALS_ASIA, "Animals Asia"],
	[CareData.SRC_BIAZA, "BIAZA 2019"],
	[CareData.SRC_MALKIN, "Malkin y Guo 2007"],
	[CareData.SRC_BIRO, "relación de fuerzas del amolado del taller"],
	[CareData.SRC_INCROPERA, "Incropera et al. 2007"],
	[CareData.SRC_C100S, "ficha del acero C100S"],
	[CareData.SRC_CARSLAW, "Carslaw y Jaeger 1959"],
	[CareData.SRC_ENGINE_KERATIN, "ficha de la garra del banco de ensayo (queratina: McKittrick et al. 2012)"],
	[CareData.SRC_ENGINE_GEOMETRY, "ficha de la garra del banco de ensayo (área y semiángulo de la punta: estimaciones)"],
	[CareData.SRC_RUBRIC, "rúbrica pedagógica del simulador"],
	[ClawSharpness.SRC_PATTRICK, "Pattrick, Labonte y Federle 2018"],
	[ClawSharpness.SRC_DAVIS, "Davis et al. 2004"],
	[ClawsV2.SRC_MCKITTRICK, "McKittrick et al. 2012"],
]

## Valores de sedación en el orden del selector.
const SEDATION_IDS := ["libre", "sujecion", "sedacion", "anestesia"]
## Velocidades del reloj del ensayo, como las del simulador de la afiladora del taller: dejan esperar la hemostasia (30 s
## con hemostático, de 5 a 10 minutos sin él) o el enfriamiento sin cambiar la física: el ensayo avanza time_scale veces
## más deprisa que el tiempo real (los gestos también: una pasada dura time_scale veces más en el ensayo).
const TIME_SCALES := [1.0, 2.0, 5.0, 10.0, 60.0, 600.0, 3600.0]
## Tono del roce de la lima: dientes por segundo de referencia (13 dientes por cm a 10 cm/s; diseño de sonido).
const RASP_REF_TPS := 130.0
## El roce suena hasta RASP_HOLD_S (s del ensayo) después del último tramo de lima o de torno.
const RASP_HOLD_S := 0.2
## El chirrido de una herramienta que roza sin morder (unidad 5l): el roce, tantas veces más agudo (diseño de sonido).
const RASP_SQUEAL := 1.6
## Cuánto baja el zumbido del motor al apretar contra la garra (diseño de sonido, no física: un motor pequeño de
## corriente continua pierde vueltas con la carga, pero su curva no está en las fichas): el tono baja hasta un
## MOTOR_LOAD_DROP con la presión de la mano, la mitad con MOTOR_LOAD_HALF_N.
const MOTOR_LOAD_DROP := 0.2
const MOTOR_LOAD_HALF_N := 3.0
## Los dibujos del velocirraptor que se pueden elegir (el de cine es ficción: solo el dibujo).
const MODELS := ["reconstruccion", "pelicula"]
## Las patas de cada animal (petición 31 de Eric): la rapaz y el velocirraptor, sus dos patas; el tigre y el oso, las
## cuatro. La primera es la de partida.
const PAWS_BY_KIND := {
	"dos": ["derecha", "izquierda"],
	"cuatro": ["delantera_derecha", "delantera_izquierda", "trasera_derecha", "trasera_izquierda"],
}
const PAW_NAMES := {
	"derecha": "Pata derecha", "izquierda": "Pata izquierda", "delantera_derecha": "Pata delantera derecha",
	"delantera_izquierda": "Pata delantera izquierda", "trasera_derecha": "Pata trasera derecha",
	"trasera_izquierda": "Pata trasera izquierda",
}
## Las garras de cada pata que se pueden trabajar, por animal: [id, nombre]. La primera es la de partida. La rapaz, los
## cuatro dedos (el I, el pulgar, detrás); el tigre, los cuatro de la mano que apoyan (el espolón, el I, va alto y no se
## dibuja); el oso, los cinco; el velocirraptor, la garra en hoz del dedo II (los dedos III y IV, con garras pequeñas,
## no tienen ficha en el banco). Anatomía: Samour 2006 (rapaces); Homberger et al. 2009 (felinos); Norell y Makovicky
## 1999 (velocirraptor, la de la ficha de la 4e). La forma de la garra de cada dedo (largo, base, arco y sección), en
## CareData.CLAW_SHAPES (petición 36): care_setup() le pasa a ClawCare el dedo y la pata.
const DIGITS := {
	"rapaz": [["III", "dedo III, el del medio"], ["II", "dedo II, el de dentro"], ["IV", "dedo IV, el de fuera"], ["I", "dedo I, el pulgar"]],
	"tigre": [["III", "dedo III"], ["II", "dedo II"], ["IV", "dedo IV"], ["V", "dedo V"]],
	"oso": [["III", "dedo III"], ["II", "dedo II"], ["IV", "dedo IV"], ["I", "dedo I"], ["V", "dedo V"]],
	"velociraptor": [["II", "dedo II, la garra en hoz"]],
}

var care: ClawCare
## Ajustes del ensayo: animal, claw, inlay, quick, seed, overgrowth_days (y la sujeción y la humedad de partida).
var setup: Dictionary = {}
## Herramienta en la mano («» en la bandeja).
var tool := ""
var force_n := FORCE_DEFAULT
var angle_deg := ANGLE_DEFAULT
var rotary_on := false
var rpm_index := 0
var paused := false
var time_scale := 1.0
## Terminado: se enseña el informe y se revela la carne viva.
var finished := false
var tutorial_on := true
## Número de ensayos empezados (la semilla de la carne viva oculta de cada uno).
var trials := 0
## El dibujo del velocirraptor: «reconstruccion» (con plumas) o «pelicula» (el de cine). Solo cambia el dibujo: la garra
## y su física son las de la reconstrucción.
var model := "reconstruccion"
## La pata y la garra que se trabajan (paws_of y los ids de DIGITS de su animal).
var paw := "derecha"
var digit := "III"

var _serial := 0
var _debt := 0.0
var _gesture: Dictionary = {}
var _last_action: Dictionary = {}
var _fx: Array = []
var _fx_n := 0
var _sfx_at := {}
var _notice := ""
## El texto de la punta al empezar, hecho una vez por ensayo y garra.
var _tip_text := {}
## Lo que ha crecido de más cada garra (_overgrowth_of), por animal, garra, dedo, pata y días.
var _growth_memo := {}
var _flow: Array = []
var _proc := 0
var _step := 0
var _prev_check := {}
var _done := {}
var _return_to: Array = []
var _was_bleeding := false
var _was_broken := false
var _initial_profile: Dictionary = {}
var _rasp_until := -1.0
var _rasp_pitch := 1.0
var _rasp_squeal := false
var _start_snap: Dictionary = {}
var _ev_seen := 0
var _mistake: Dictionary = {}
## Llamadas a ClawCare de la garra elegida desde el último configure(): [método, parámetros]. Con ellas, otra ClawCare nueva
## llega a la misma garra (los tests lo comprueban: la página no hace física por su cuenta).
var calls: Array = []
## El animal que comparten todas sus garras (claw_care_patient.gd, unidad 5g): su sujeción, su dolor, sus movimientos y su
## estrés. Trabajar otra garra no lo borra, y el reloj de la sujeción cuenta una sola vez.
var patient: Patient
## Las herramientas del ensayo y lo que se han gastado (unidad 5l): una para todas las garras del animal, como el animal
## (ClawCare.new con el kit); cambia con cada ensayo nuevo.
var kit: Kit
## Todas las llamadas a ClawCare del ensayo, de todas las garras y en orden: [clave de la garra, método, parámetros]. Con
## ellas, unas ClawCare nuevas que comparten un animal nuevo llegan al mismo animal y a las mismas garras (los tests lo
## comprueban).
var history: Array = []
## Las demás garras del animal: "pata|dedo" → { care, calls, start_snap, initial_profile, ev_seen, profile, key, busy,
## worked } (la elegida se guarda aquí al dejarla).
var _slots := {}
## La última herramienta giratoria que se ha cogido (al coger otra, su velocidad empieza en la primera).
var _last_rotary := ""
## Las garras que han vuelto de la reforja con un bloque en bruto sobre el muñón (petición 35): "pata|dedo" → el bloque de
## ClawForge.care_setup(...) ({ material, stump_mm, wall_mm, fiction, note, source }). care_setup() se lo pasa a ClawCare.
var _blocks := {}
## Las piezas de la reforja que se colocan a mano (unidad 5o, petición 43): "pata|dedo" → ClawCareBond (la pieza, la
## preparación, el adhesivo, el acrílico o la resina, la sujeción, lo que rebosa y la prueba). Hasta que se une, la garra
## sigue como estaba.
var _bonds := {}
## Las fundas ya unidas (unidad 5o): "pata|dedo" → el material de la funda (la garra pasa a ser de ese material, como la
## funda entera de la reforja). care_setup() se lo pasa a ClawCare.
var _sheaths := {}
## Las garras cuya ClawCare ya lleva puesta su pieza ("pata|dedo" → true).
var _attached := {}
## El alto de la capa que pone la espátula (CareData.LAYER_MM: «fina» o «gruesa»).
var layer_kind := "fina"
## La gasa apretada seguida sobre la garra mojada (s), para secarla; los pitidos de la lámpara ya sonados.
var _gauze_s := 0.0
var _beeps := 0
## La forma de cada dedo (ClawCare.shape_dims), una vez por garra y dedo.
var _dims := {}
## La sesión parada por el estado del animal (unidad 5o, petición 51: se suelta, ataca o ha perdido demasiada sangre): {} o
## { code, title, text, todo, source }. Parada, no se sigue: se empieza de nuevo (R o «Empezar de nuevo»).
var halted: Dictionary = {}
## Las veces que la rapaz se ha soltado y se ha vuelto a recoger con la toalla (recapture): van al informe.
var escapes := 0
## Los avisos del estado del animal ya dados (no se repiten).
var _warned := {}
## Las veces que se han tocado las garras de un animal grande sin sedar ni anestesiar (el primer toque avisa; el segundo, ataca).
var _unsafe_touches := 0
## Lo que sangraron las garras cuya ClawCare se ha rehecho al pegar o quitar una pieza (s sangrando): la sangre que perdió el animal.
var _blood_carry_s := 0.0
## Lo que se soltó antes de tiempo («Has soltado antes de tiempo: faltaban 12 s»): { text } o {}; se borra con la acción siguiente.
var _early: Dictionary = {}
## Lo que se ha hecho desde que se llegó al paso del tutorial (STEP_ACTION): { corte, pasada, toque, prueba }.
var _step_acts := {}
## Cuántos pasos tiene cada proceso del tutorial (_step_count), por proceso, animal, material y pieza.
var _step_counts := {}
## Las guías de las herramientas de la bandeja (tray_view) y el «cómo» de las limas con el que se hicieron.
var _guides := {}
var _guide_how := ""
## Las fuentes de los límites de la barra del animal, por animal (_risk_sources).
var _risk_src := {}
## La última barra del animal y la última bandeja, con lo que las hizo (animal_view y tray_view las rehacen solo si cambia).
var _animal_key: Array = []
var _animal_cache: Array = []
var _tray_key: Array = []
var _tray_cache: Array = []
## El tiempo de lectura del paso informativo del tutorial (s reales).
var _read_t := 0.0
## Las pasadas de lima (o los toques del torno) de la garra elegida, la última primero: [{ tool, mm3, raUm, apexBefore, apexAfter,
## leftAfter, ratioBefore, ratioAfter, noBite, s }] (para «2 de ~6 pasadas para la forma»). La que está en marcha, _pass.
var _passes: Array = []
var _pass: Dictionary = {}
## La vista de la cámara que dice la página (note_view): la usan los textos de los mandos.
var _view_id := "garra"
## La lente de la cámara (unidad 5t-A, petición 62): la puesta, con sus rayones acumulados (claw_care_lens.gd). Es de la
## cámara, no del ensayo: empezar de nuevo o cambiar de animal no la cambia (lens_mount, lens_load).
var lens: Lens = Lens.new("plastico")
## La última reacción cuya lente ya se ha calculado (patient.reaction_seq) y si la amenaza de ahora ya se ha avisado.
var _lens_seq := 0
## Lo peligroso que es para las lentes la pata que se trabaja, con su material y sus puntas de ahora (danger_now), y su clave.
var _danger_now: Dictionary = {}
var _danger_key := ""
var _warning_said := false


func _init(p: Dictionary = {}) -> void:
	configure(p)


# ════════════════════════════════ Ensayo ════════════════════════════════

## Empieza un ensayo nuevo con estos ajustes (se mezclan con los de ahora): { animal, claw, inlay, overgrowth_days,
## sedation, humidity, seed }. La carne viva de cada ensayo va oculta en la banda de su animal, con una semilla nueva.
func configure(p: Dictionary = {}) -> void:
	var s := setup.duplicate(true)
	s.merge(p, true)
	var aid := String(s.get("animal", "rapaz"))
	if not CareData.ANIMALS.has(aid):
		aid = "rapaz"
	var a: Dictionary = CareData.ANIMALS[aid]
	if not (a.claws as Array).has(String(s.get("claw", ""))):
		s["claw"] = String(a.claw)
	s["animal"] = aid
	if not s.has("inlay") or Catalog.find_by_id(Catalog.INLAYS, String(s.inlay)) == null:
		s["inlay"] = "none"
	if not s.has("overgrowth_days"):
		s["overgrowth_days"] = CareData.DEFAULT_OVERGROWTH_DAYS
	if not s.has("sedation") or not CareData.SEDATION.has(String(s.sedation)):
		s["sedation"] = "libre"
	if not s.has("humidity") or not CareData.KERATIN.has(String(s.humidity)):
		s["humidity"] = "natural"
	if not CareData.TIP_STARTS.has(String(s.get("tip_start", "natural"))):
		s["tip_start"] = "natural"
	# la garra rota de serie (unidad 5v): { paw, digit, kind } (CareData.BROKEN_STARTS) o nada
	var bs: Variant = s.get("broken_start", {})
	if not (bs is Dictionary) or not CareData.BROKEN_STARTS.has(String((bs as Dictionary).get("kind", ""))):
		s.erase("broken_start")
	if not p.has("seed"):
		trials += 1
		s["seed"] = "cetreria-%d" % trials
	s["quick"] = "oculta"
	# la pata y la garra se conservan con el mismo animal (empezar de nuevo, otra rapaz, otro material); con otro, las de
	# partida
	var same_animal := String(setup.get("animal", "")) == aid
	setup = s
	if not same_animal or not paws_of(aid).has(paw) or not digit_ids(aid).has(digit):
		paw = String(paws_of(aid)[0])
		digit = String(digit_ids(aid)[0])
	# (unidad 5v) con una garra rota de serie, el ensayo empieza en ella
	var bsd: Dictionary = s.get("broken_start", {})
	if not bsd.is_empty() and paws_of(aid).has(String(bsd.get("paw", ""))) and digit_ids(aid).has(String(bsd.get("digit", ""))):
		paw = String(bsd.paw)
		digit = String(bsd.digit)
	_slots = {}
	_blocks = {}
	_bonds = {}
	_sheaths = {}
	_attached = {}
	_gauze_s = 0.0
	_beeps = 0
	halted = {}
	escapes = 0
	_warned = {}
	_unsafe_touches = 0
	_blood_carry_s = 0.0
	_early = {}
	_step_acts = {}
	_read_t = 0.0
	_passes = []
	_pass = {}
	# un ensayo nuevo: la garra de partida (o la que se conserva) empieza con la sujeción de los ajustes, no con la del
	# ensayo anterior
	care = null
	patient = Patient.new(aid, String(s.sedation), String(s.claw))
	_lens_seq = 0
	_warning_said = false
	kit = Kit.new()
	history = []
	care = ClawCare.new(care_setup(paw, digit), patient, kit)
	_start_snap = care.snapshot()
	var prof: Dictionary = _start_snap.profile
	_initial_profile = { "s": prof.s, "r": prof.r }
	_ev_seen = (_start_snap.events as Array).size()
	_mistake = {}
	calls = []
	_gesture = {}
	_last_action = {}
	_debt = 0.0
	_notice = ""
	_sfx_at = {}
	finished = false
	# (unidad 5v) la garra que llega rota ya sangra o ya está rota: no es algo que pase en el ensayo
	_was_bleeding = bool(_start_snap.bleeding.active)
	_was_broken = bool(_start_snap.damage.broken)
	_reset_tutorial()
	_touch()


## Empieza de nuevo con los mismos ajustes (la tecla R): otra garra igual, con la carne viva en otro sitio de la banda.
func restart() -> void:
	var s := setup.duplicate(true)
	s.erase("seed")
	s["sedation"] = "libre"
	s["humidity"] = "natural"
	setup = s
	configure({})


func set_animal(id: String) -> void:
	if id == String(setup.get("animal", "")) or not CareData.ANIMALS.has(id):
		return
	configure({ "animal": id, "claw": String(CareData.ANIMALS[id].claw), "sedation": "libre", "humidity": "natural" })


## Rapaz: cuál de las seis del banco.
func set_claw(id: String) -> void:
	var a: Dictionary = CareData.ANIMALS[String(setup.animal)]
	if id == String(setup.get("claw", "")) or not (a.claws as Array).has(id):
		return
	configure({ "claw": id, "sedation": "libre", "humidity": "natural" })


## Material de la garra: «none» (queratina) o uno de Catalog.INLAYS (reforjada: un ensayo nuevo), los de la 1.x y los nuevos
## de la 2.0 (el rubí y la alúmina de la reforja).
func set_inlay(id: String) -> void:
	if id == String(setup.get("inlay", "none")) or Catalog.find_by_id(Catalog.INLAYS, id) == null:
		return
	configure({ "inlay": id, "sedation": "libre", "humidity": "natural" })


## Texto de por qué una garra reforjada no tiene crecimiento de más (el material es inerte).
const INERT_TEXT := "la garra reforjada no crece: el material es inerte; lo que crece es la queratina del muñón, desde la base, y la pieza no se alarga"


## Días sin desgaste (crecimiento de más): un ensayo nuevo. Con una garra reforjada no cambia nada (no crece).
func set_overgrowth_days(days: float) -> void:
	if String(setup.get("inlay", "none")) != "none":
		return
	var d := clampf(days, 0.0, 365.0)
	if is_equal_approx(d, float(setup.get("overgrowth_days", -1.0))):
		return
	configure({ "overgrowth_days": d, "sedation": "libre", "humidity": "natural" })
	_notice = "Garra nueva: %s días sin desgaste. Cambiar los días empieza otro ensayo con otra garra." % Js.to_fixed(d, 0)
	_touch()


## La punta con la que empiezan las garras (petición de Eric en la 5s): «roma», «natural», «afilada» o «aguja»
## (CareData.TIP_STARTS). Un ensayo nuevo; el aviso dice lo que cambia en la física (pinchar y aguantar de lado).
func set_tip_start(id: String) -> void:
	if not CareData.TIP_STARTS.has(id) or id == String(setup.get("tip_start", "natural")):
		return
	configure({ "tip_start": id, "sedation": "libre", "humidity": "natural" })
	_notice = "Garra nueva. " + tip_start_text()
	_touch()


## Lo que cambia la punta al empezar, con los números del motor: el radio frente al natural, la fuerza para pinchar (el umbral
## crece con R²: Johnson 1985) y lo que aguanta de lado (crece con R²: Pattrick et al. 2018).
func tip_start_text() -> String:
	var t := String(setup.get("tip_start", "natural"))
	var e: Dictionary = CareData.TIP_STARTS[t]
	# la de partida de la garra elegida (no la de ahora, que cambia al limar): una vez por ensayo y garra
	var ck := "%s|%s|%s|%s|%s" % [String(setup.get("seed", "")), paw, digit, t, String(setup.get("inlay", "none"))]
	if String(_tip_text.get("key", "")) == ck:
		return String(_tip_text.text)
	var c0 := ClawCare.new(care_setup(paw, digit))
	var ts := c0.tip_state()
	# según su material (cierre de la 5s): de lado se mella, se dobla o se parte; al pinchar corta, entra en cuña o ara
	var ch := " " + String(SharpenHelp.tip_character(c0).text)
	var r := float(ts.tipRadiusUm)
	var r0 := float(ts.naturalUm)
	if t == "natural":
		_tip_text = { "key": ck, "text": "Punta al empezar: natural, %s µm (la de su ficha).%s" % [Js.to_fixed(r, 0), ch] }
		return String(_tip_text.text)
	var push := ClawSharpness.yield_onset_n(r, 1.0, 1.0, 1.0) / ClawSharpness.yield_onset_n(r0, 1.0, 1.0, 1.0)
	var side: Variant = ts.strengthRatio
	var side_txt := ("aguanta de lado %s %% de la natural" % _pct_text(float(side))) if side != null else ""
	var tail := ""
	match t:
		"roma":
			tail = "Para pinchar hace falta %s veces más fuerza (el umbral crece con R²); %s." % [_x_text(push), side_txt]
		"afilada":
			tail = "Pincha con %s %% de la fuerza; %s." % [_pct_text(push), side_txt]
		"aguja":
			tail = "Pincha con %s %% de la fuerza, pero %s: se mella con un toque de lado." % [_pct_text(push), side_txt]
	_tip_text = { "key": ck, "text": "Punta al empezar: %s, %s µm (×%s la natural). %s%s Estimación del banco: %s." % [String(e.name).to_lower(), um_text(r),
		Js.to_fixed(float(ts.ratio), 2), tail, ch, short_source(String(e.source))] }
	return String(_tip_text.text)


static func _pct_text(f: float) -> String:
	var p := f * 100.0
	return Js.to_fixed(p, 0) if p >= 10.0 else (Js.to_fixed(p, 1) if p >= 1.0 else Js.to_fixed(p, 2))


static func _x_text(f: float) -> String:
	return Js.to_fixed(f, 0) if f >= 10.0 else Js.to_fixed(f, 1)


static func um_text(r_um: float) -> String:
	return Js.to_fixed(r_um, 1) if r_um < 10.0 else Js.to_fixed(r_um, 0)


## Sujeción, sedación o anestesia (en el mismo ensayo: lo apunta ClawCare). Es del animal: todas sus garras la comparten
## (claw_care_patient.gd), así que se cambia una vez.
func set_sedation(id: String) -> void:
	if not CareData.SEDATION.has(id) or id == patient.sedation:
		return
	care.set_sedation(id)
	_record("set_sedation", id)
	_after()


## La pausa para calmarlo (los métodos de relajación, ClawCareReaction.CALM): se apartan las manos, el animal no se revuelve
## y su estrés baja; coger una herramienta o tocarle las garras la acaba. Es del animal (claw_care_patient.gd).
func rest(on: bool = true) -> void:
	if on == patient.resting:
		return
	if on:
		drop()
	patient.rest(on)
	_notice = "Pausa: le dejas tranquilo y se va calmando. Sigue cuando la barra de estrés baje de «inquieto»." if on else "Sigues con la consulta."
	_after()


## Humedad de la queratina (remojar o dejar orear).
func set_humidity(id: String) -> void:
	if not CareData.KERATIN.has(id) or id == String(care.setup().humidity):
		return
	care.set_humidity(id)
	_record("set_humidity", id)
	_after()


# ════════════════════════════════ Las dos patas ════════════════════════════════

## Las patas de un animal (PAWS_BY_KIND): cuatro el tigre y el oso, dos los demás.
static func paws_of(animal: String) -> Array:
	return PAWS_BY_KIND["cuatro" if animal in ["tigre", "oso"] else "dos"]


## ¿Es una pata trasera del tigre o del oso? (su forma, la de las patas traseras de CareData.CLAW_SHAPES: de momento, la de
## la mano, como estimación)
static func is_hind(p: String) -> bool:
	return p.begins_with("trasera")


## Los ids de las garras que se trabajan en una pata de este animal (DIGITS).
static func digit_ids(animal: String) -> Array:
	return (DIGITS.get(animal, DIGITS["rapaz"]) as Array).map(func(d: Array) -> String: return String(d[0]))


## Nombre de una garra («dedo III, el del medio»).
static func digit_name(animal: String, d: String) -> String:
	for e: Array in DIGITS.get(animal, DIGITS["rapaz"]):
		if String(e[0]) == d:
			return String(e[1])
	return "dedo " + d


## Nombre de una pata («Pata delantera derecha»).
static func paw_name(_animal: String, p: String) -> String:
	return String(PAW_NAMES.get(p, p))


## «Pata derecha · dedo III, el del medio»: de qué pata y de qué garra es.
static func claw_label(animal: String, p: String, d: String) -> String:
	return "%s · %s" % [paw_name(animal, p), digit_name(animal, d)]


## Los ajustes de la ClawCare de una garra: los del ensayo, con su propia semilla (la de partida, la del ensayo) y la
## sujeción que tiene ahora el animal (la de su ClawCarePatient, que es la que manda).
func care_setup(p: String, d: String) -> Dictionary:
	var s := setup
	var first := p == String(paws_of(String(s.animal))[0]) and d == String(digit_ids(String(s.animal))[0])
	var sed := String(s.sedation)
	if patient != null:
		sed = patient.sedation
	return {
		"animal": String(s.animal), "claw": String(s.claw), "inlay": String(s.inlay), "quick": "oculta",
		"seed": String(s.seed) if first else "%s|%s-%s" % [String(s.seed), p, d],
		"overgrowth_days": float(s.overgrowth_days), "sedation": sed, "humidity": String(s.humidity),
		# la garra de este dedo y de esta pata (petición 36: CareData.CLAW_SHAPES)
		"digit": d, "paw": p,
	}.merged(_overgrowth_of(p, d)).merged(_tip_start_of()).merged(_broken_start_of(p, d)).merged({ "block": (_blocks[slot_key(p, d)] as Dictionary).duplicate(true) } if _blocks.has(slot_key(p, d)) else {}).merged(
		# la funda unida a mano (unidad 5o): la garra, del material de la funda
		{ "inlay": String(_sheaths[slot_key(p, d)]) } if _sheaths.has(slot_key(p, d)) else {}, true)


## (última vuelta de la 5s) Lo que ha crecido de más esta garra: los días de la ficha por lo que crece su animal y por lo
## que crece ella frente a las demás (CareData.claw_shape: growthRatio; las patas del tigre, como las del gato). Solo si es
## distinto: con growthRatio 1 la garra sale con overgrowth_days, igual que antes (al bit). → {} o { overgrowth_mm }.
## Se calcula una vez por animal, garra, dedo, pata y días (_growth_memo): la escena pide care_setup de cada garra en cada
## vista publicada y CareData.claw_shape arma su ficha entera (con las fuentes) cada vez.
func _overgrowth_of(p: String, d: String) -> Dictionary:
	var hind := p.begins_with("trasera")
	var mk := "%s|%s|%s|%s|%s" % [String(setup.animal), String(setup.claw), d, str(hind), var_to_str(float(setup.overgrowth_days))]
	if _growth_memo.has(mk):
		return _growth_memo[mk]
	var out := {}
	var sh := CareData.claw_shape(String(setup.claw), d, hind)
	var ratio := float(sh.get("growthRatio", 1.0))
	if ratio != 1.0:
		var growth := float((CareData.animal(String(setup.animal)).growth_mm_day as Dictionary).value)
		out = { "overgrowth_mm": maxf(float(setup.overgrowth_days), 0.0) * growth * ratio }
	if _growth_memo.size() > 256:
		_growth_memo.clear()
	_growth_memo[mk] = out
	return out


## La punta al empezar de todas las garras del ensayo (CareData.TIP_STARTS): solo si no es la natural (la natural, igual que
## antes, al bit). → {} o { tip_start }.
func _tip_start_of() -> Dictionary:
	var t := String(setup.get("tip_start", "natural"))
	return {} if t == "natural" else { "tip_start": t }


## La garra que llega rota de serie (unidad 5v; setup.broken_start = { paw, digit, kind }): solo la suya. → {} o { broken_start }.
func _broken_start_of(p: String, d: String) -> Dictionary:
	var bs: Dictionary = setup.get("broken_start", {})
	if bs.is_empty() or String(bs.get("paw", "")) != p or String(bs.get("digit", "")) != d:
		return {}
	return { "broken_start": String(bs.kind) }


## Clave de una garra en _slots.
static func slot_key(p: String, d: String) -> String:
	return "%s|%s" % [p, d]


## Trabaja otra garra: la pata p (PAWS) y la garra d (DIGITS de su animal). La que se deja guarda su estado; la nueva se
## pone al día con el reloj (lo que ha pasado sin tocarla).
func select_claw(p: String, d: String) -> void:
	if not paws_of(String(setup.animal)).has(p) or not digit_ids(String(setup.animal)).has(d) or (p == paw and d == digit):
		return
	_end_gesture()
	var t_now := care.time_s()
	_save_slot()
	paw = p
	digit = d
	var key := slot_key(p, d)
	if _slots.has(key):
		var e: Dictionary = _slots[key]
		_slots.erase(key)
		care = e.care
		calls = e.calls
		_start_snap = e.start_snap
		_initial_profile = e.initial_profile
		_ev_seen = int(e.ev_seen)
	else:
		care = ClawCare.new(care_setup(p, d), patient, kit)
		calls = []
		_start_snap = care.snapshot()
		var prof: Dictionary = _start_snap.profile
		_initial_profile = { "s": prof.s, "r": prof.r }
		_ev_seen = (_start_snap.events as Array).size()
	_catch_up(key, care, calls, t_now)
	var sn := care.snapshot()
	_was_bleeding = bool(sn.bleeding.active)
	_was_broken = bool(sn.damage.broken)
	_ev_seen = (sn.events as Array).size()
	_mistake = {}
	_notice = ""
	_touch()


## Vuelve de la reforja (petición 35): la garra elegida, rota, pasa a ser su muñón de queratina con el bloque en bruto
## del material reforjado (fs = ClawForge.care_setup(ajustes de la garra con stump_mm)), que hay que limar hasta darle la
## forma de la natural. Es una ClawCare nueva del mismo animal, al día con el reloj (el reloj del animal no cuenta dos
## veces), y sus llamadas empiezan aquí; history lo apunta como «reforge». false si fs no trae bloque, si la cetrería no
## conoce el material o si la garra aún sangra (como la reconstrucción con metacrilato: primero, parar la sangre).
func reforge_with(fs: Dictionary) -> bool:
	var blk: Variant = fs.get("block", null)
	if not bool(fs.get("careSupported", false)) or not (blk is Dictionary):
		return false
	if bool(care.snapshot().bleeding.active):
		_notice = "Primero hay que parar la sangre: el bloque se pega sobre un muñón limpio y seco."
		_touch()
		return false
	_end_gesture()
	var key := slot_key(paw, digit)
	_blocks[key] = (blk as Dictionary).duplicate(true)
	history.append([key, "reforge", (blk as Dictionary).duplicate(true)])
	var sn := _renew_care()
	# el aviso: el bloque y, si lo es, lo que en la realidad no se hace (la ficción)
	var evs: Array = sn.events
	_notice = String(evs[0].message) if not evs.is_empty() and String(evs[0].code) == "bloque" else ""
	_touch()
	return true


## La garra elegida empieza de nuevo con sus ajustes de ahora (care_setup: con su bloque o su funda), al día con el reloj:
## una ClawCare nueva del mismo animal, con sus llamadas desde aquí. Devuelve su instantánea.
func _renew_care() -> Dictionary:
	var t_now := care.time_s()
	var key := slot_key(paw, digit)
	# lo que ha sangrado la garra de antes no se olvida: es sangre que ha perdido el animal (unidad 5o)
	_blood_carry_s += care.bleed_total_s()
	care = ClawCare.new(care_setup(paw, digit), patient, kit)
	calls = []
	_start_snap = care.snapshot()
	var prof: Dictionary = _start_snap.profile
	_initial_profile = { "s": prof.s, "r": prof.r }
	_catch_up(key, care, calls, t_now)
	var sn := care.snapshot()
	_was_bleeding = bool(sn.bleeding.active)
	_was_broken = bool(sn.damage.broken)
	_ev_seen = (sn.events as Array).size()
	_mistake = {}
	return sn


## Ajustes de la garra elegida para ClawForge.care_setup() cuando se rompe (petición 35): los de su ClawCare con stump_mm,
## lo que queda de ella (su punta de ahora, mm desde la base).
func reforge_request() -> Dictionary:
	var s := care.setup()
	s["stump_mm"] = care.apex_mm()
	return s


## Lo que la vista publica para la reforja (lo pidió la 5f; unidad 5j): reforge_request() si la garra elegida está rota y sin
## reconstruir, y {} si no. La página la lee de aquí, sin rehacerla con los ajustes y el largo de la instantánea.
func _reforge_view(sn: Dictionary) -> Dictionary:
	var dmg: Dictionary = sn.get("damage", {})
	if not bool(dmg.get("broken", false)) or bool(dmg.get("repaired", false)):
		return {}
	return reforge_request()


## El dibujo del velocirraptor (MODELS): no empieza otro ensayo.
func set_model(id: String) -> void:
	if id in MODELS and id != model:
		model = id
		_touch()


func set_paw(p: String) -> void:
	select_claw(p, digit)


func set_digit(d: String) -> void:
	select_claw(paw, d)


## P: la pata siguiente (la misma garra).
func cycle_paw() -> void:
	var ps := paws_of(String(setup.animal))
	select_claw(String(ps[(ps.find(paw) + 1) % ps.size()]), digit)


## G: la garra siguiente de la misma pata.
func cycle_digit() -> void:
	var ids := digit_ids(String(setup.animal))
	select_claw(paw, String(ids[(ids.find(digit) + 1) % ids.size()]))


## Guarda la garra elegida en _slots (con lo que hace falta para dibujarla sin preguntar al motor en cada fotograma).
func _save_slot() -> void:
	var sn := care.snapshot()
	_slots[slot_key(paw, digit)] = {
		"care": care, "calls": calls, "start_snap": _start_snap, "initial_profile": _initial_profile, "ev_seen": _ev_seen,
		"profile": { "s": sn.profile.s, "r": sn.profile.r }, "lengthMm": float(sn.claw.lengthMm),
		"key": "%s|%s|%s" % [var_to_str(float(sn.claw.lengthMm)), var_to_str(float(sn.claw.removedMm3)), var_to_str(float(sn.tip.flatMm))],
		"busy": bool(sn.bleeding.active), "bleeding": bool(sn.bleeding.active), "broken": bool(sn.damage.broken),
		"worked": _worked(calls),
	}


## ¿Se ha hecho algo en esta garra (más allá de dejar pasar el tiempo o de la sujeción)?
static func _worked(cs: Array) -> bool:
	for c: Array in cs:
		if not (String(c[0]) in ["advance", "advance_held", "set_sedation"]):
			return true
	return false


## Lleva la garra key hasta el tiempo t_s del ensayo en pasos enteros de ClawCare.DT (lo que pasa sin tocarla).
func _catch_up(key: String, c: ClawCare, cs: Array, t_s: float) -> void:
	var steps := int(floor((t_s - c.time_s()) / ClawCare.DT + 1e-9))
	if steps <= 0:
		return
	c.advance(float(steps) * ClawCare.DT)
	_record_advance(key, cs, float(steps) * ClawCare.DT)


## Apunta una llamada a la ClawCare de la garra elegida: en sus llamadas y en las del ensayo (history).
func _record(method: String, args: Variant) -> void:
	calls.append([method, args])
	history.append([slot_key(paw, digit), method, args])


## Apunta un avance del reloj de la garra key (en sus llamadas cs y en las del ensayo). El tiempo seguido va en una sola
## entrada: ClawCare da lo mismo a trozos que de una vez, y el animal cuenta cada paso una sola vez.
func _record_advance(key: String, cs: Array, secs: float) -> void:
	# con la garra cogida (un gesto en marcha), ClawCare.advance_held: ese tiempo estresa al animal
	var m := "advance_held" if patient.gripped else "advance"
	if not cs.is_empty() and String(cs[cs.size() - 1][0]) == m:
		cs[cs.size() - 1][1] = float(cs[cs.size() - 1][1]) + secs
	else:
		cs.append([m, secs])
	var n := history.size()
	if n > 0 and String(history[n - 1][0]) == key and String(history[n - 1][1]) == m:
		history[n - 1][2] = float(history[n - 1][2]) + secs
	else:
		history.append([key, m, secs])


## Las garras que no se ven pero siguen sangrando, al día con el reloj de la elegida.
func _tick_others() -> void:
	for key: String in _slots:
		var e: Dictionary = _slots[key]
		if not bool(e.busy):
			continue
		_catch_up(key, e.care, e.calls, care.time_s())
		var sn: Dictionary = (e.care as ClawCare).snapshot()
		e["busy"] = bool(sn.bleeding.active)
		e["bleeding"] = bool(sn.bleeding.active)


## Las garras del animal para la escena y la interfaz: [{ key, paw, digit, label, selected, worked, bleeding, broken,
## profile ({ s, r } de la forma de ahora; vacío si no se ha tocado o es la elegida), key_geom }].
func slots_view() -> Array:
	var out: Array = []
	var aid := String(setup.animal)
	for p: String in paws_of(aid):
		for d: String in digit_ids(aid):
			var key := slot_key(p, d)
			var sel := p == paw and d == digit
			var e: Dictionary = _slots.get(key, {})
			# la forma de la garra de ese dedo (lo pidió la 5k; unidad 5o): la escena dibuja cada una con la suya
			var dk := "%s|%s|%s" % [String(setup.claw), d, str(is_hind(p))]
			if not _dims.has(dk):
				_dims[dk] = ClawCare.shape_dims(String(setup.claw), d, is_hind(p))
			var dims: Dictionary = _dims[dk]
			out.append({ "key": key, "paw": p, "digit": d, "label": claw_label(aid, p, d), "selected": sel,
				"arcDeg": float(dims.arcDeg), "sectionRatio": float(dims.sectionRatio), "naturalMm": float(dims.naturalMm),
				"baseRadiusMm": float(dims.baseRadiusMm), "curve": float(dims.curve), "ventralFlat": bool(dims.ventralFlat),
				"worked": _worked(calls) if sel else bool(e.get("worked", false)),
				"bleeding": bool(e.get("bleeding", false)), "broken": bool(e.get("broken", false)),
				"profile": e.get("profile", {}) if not sel and bool(e.get("worked", false)) else {},
				"key_geom": String(e.get("key", "")) })
	return out


func is_reforged() -> bool:
	return String(setup.get("inlay", "none")) != "none" or _sheaths.has(slot_key(paw, digit))


# ════════════════════════════════ Colocar a mano la pieza de la reforja (unidad 5o) ════════════════════════════════
## La pieza llega sin pegar (receive_piece) y la coloca el usuario: cada paso es una orden (bond_*) o un gesto con su
## herramienta (el alcohol y la clorhexidina limpian, la gasa seca, la lija lija donde va a pegar, la espátula pone el
## acrílico o la resina y quita lo que rebosa en fresco, la lima lo quita ya duro y baja el escalón). La física de la unión,
## en ClawCareBond; la de la garra (el calor del fraguado, las capas del bloque, el limado), en ClawCare, con sus llamadas
## apuntadas en calls y en history como las demás.

## La pieza de la garra elegida (ClawCareBond) o null.
func bond() -> Bond:
	var b: Variant = _bonds.get(slot_key(paw, digit))
	return b as Bond


## Llega una pieza de la reforja (fs = ClawForge.care_setup; con paw y digit, la garra de la que vino): queda en la bandeja,
## sin pegar, y la garra sigue como estaba. La funda entera de otro animal o de otra garra empieza antes un ensayo con ese
## animal y esa garra (sin la funda). Entra en el tutorial «Colocar la pieza de la reforja». false si no hay pieza.
func receive_piece(fs: Dictionary) -> bool:
	var has_block: bool = fs.get("block", null) is Dictionary
	if not bool(fs.get("careSupported", true)) or (not has_block and String(fs.get("inlay", "none")) == "none"):
		_notice = String(fs.get("reason", "")) if String(fs.get("reason", "")) != "" else "La reforja aún no ha dado una pieza que colocar."
		_touch()
		return false
	_end_gesture()
	var aid := String(fs.get("animal", setup.animal))
	var cid := String(fs.get("claw", setup.claw))
	if not has_block and (aid != String(setup.animal) or cid != String(setup.claw) or String(setup.get("inlay", "none")) != "none"):
		configure({ "animal": aid, "claw": cid, "inlay": "none" })
	var p := String(fs.get("paw", paw))
	var d := String(fs.get("digit", digit))
	if paws_of(String(setup.animal)).has(p) and digit_ids(String(setup.animal)).has(d):
		select_claw(p, d)
	var key := slot_key(paw, digit)
	if _attached.has(key):
		_detach(key)
	var stump := float((fs.block as Dictionary).get("stump_mm", care.apex_mm())) if has_block else 0.0
	var claw := CareData.claw_entry(String(setup.claw))
	var shape := CareData.claw_shape(String(setup.claw), digit, is_hind(paw))
	var r_stump := care.radius_at(minf(stump, care.apex_mm()) - 0.5 * ClawCare.STATION_MM) if has_block else 0.0
	var b := Bond.new(Bond.piece_from(fs, claw, shape, r_stump))
	_bonds[key] = b
	_insert_bond_process()
	_notice = "La pieza ha llegado a la bandeja sin pegar: %s. Prepara la garra y colócala tú." % String(b.piece.name).to_lower()
	_touch()
	return true


## La garra elegida ya no lleva su pieza (se ha despegado o se quita): vuelve a como estaba antes de unirla.
func _detach(key: String) -> void:
	_blocks.erase(key)
	_sheaths.erase(key)
	_attached.erase(key)
	history.append([key, "detach", {}])
	_renew_care()


## Mete «Tras un ataque» en el tutorial, aquí (y salta a él), como «Si sangra»: al acabarlo se vuelve al paso de antes.
func _insert_attack_process() -> void:
	var pid := process_id()
	if pid == Tutorial.ATTACK_PROCESS:
		return
	_return_to.append([pid, _step])
	var i := _flow.find(Tutorial.ATTACK_PROCESS)
	if i < 0:
		i = mini(_proc, _flow.size())
		_flow.insert(i, Tutorial.ATTACK_PROCESS)
	_proc = i
	_step = 0
	_seed_checks()
	_advance_done()


## Mete «Colocar la pieza» en el tutorial, aquí (y salta a él).
func _insert_bond_process() -> void:
	var i := _flow.find(Tutorial.BOND_PROCESS)
	if i < 0:
		i = mini(_proc, _flow.size())
		_flow.insert(i, Tutorial.BOND_PROCESS)
	_proc = i
	_step = 0
	_seed_checks()


## Une la pieza a la garra cuando la colocación lo dice (ClawCareBond.attached): la funda, la garra de su material; el
## bloque, sobre el muñón; el acrílico y la resina, la primera capa (y cada capa nueva, ClawCare.grow_block).
func _sync_bond() -> void:
	var b := bond()
	if b == null:
		return
	var key := slot_key(paw, digit)
	if b.attached() and not _attached.has(key):
		var pc: Dictionary = b.piece
		if String(pc.kind) == "funda":
			_sheaths[key] = String(pc.material)
			history.append([key, "sheath", String(pc.material)])
		else:
			var blk: Dictionary = ((pc.fs as Dictionary).get("block", {}) as Dictionary).duplicate(true)
			if b.method != "adhesivo":
				var mat := "resina" if b.method == "resina" else String(blk.get("material", "acrilico"))
				blk["material"] = mat
				blk["fiction"] = false
				blk["built_mm"] = float((b.layers[0] if b.method == "acrilico" else b.resin[0]).h)
				if mat == "resina":
					blk["note"] = String(CareData.RESIN.use)
					blk["source"] = String(CareData.RESIN.source)
			_blocks[key] = blk
			history.append([key, "reforge", blk.duplicate(true)])
		_attached[key] = { "layers": 1 }
		_renew_care()
		_after()
	elif _attached.has(key) and b.method != "adhesivo":
		# las capas que faltan en la ClawCare
		var have := int((_attached[key] as Dictionary).layers)
		var ls: Array = b.layers if b.method == "acrilico" else b.resin.filter(func(l: Dictionary) -> bool: return float(l.dose) > 0.0)
		while have < ls.size():
			var pg := { "h_mm": float(ls[have].h) }
			care.grow_block(pg)
			_record("grow_block", pg)
			have += 1
		_attached[key] = { "layers": have }


## El escalón de la unión que queda a la vista (mm): el de la funda (ClawCareBond.step_mm) o, con el bloque, lo que sobresale
## el bloque del muñón (ClawCare.radius_at a cada lado de la unión). 0 sin pieza unida.
func joint_step_mm() -> float:
	var b := bond()
	if b == null or not b.attached():
		return 0.0
	if String(b.piece.kind) == "funda":
		return b.step_mm
	var j := float(b.piece.jointMm)
	if care.apex_mm() <= j + ClawCare.STATION_MM:
		return 0.0
	return maxf(care.radius_at(j + 0.5 * ClawCare.STATION_MM) - care.radius_at(j - 0.5 * ClawCare.STATION_MM), 0.0)


func _bond_now() -> float:
	return care.time_s()


## Después de una orden de la colocación: une lo que toque y repinta.
func _bond_after(ok: bool = true) -> void:
	var b := bond()
	if b != null:
		b.update(_bond_now())
		if not b.notice.is_empty():
			_notice = b.notice
	_sync_bond()
	_after()
	if ok:
		_touch()


func bond_method(m: String) -> void:
	var b := bond()
	if b != null and b.set_method(m):
		_bond_after()


func bond_adhesive(id: String) -> void:
	var b := bond()
	if b != null and b.set_adhesive(id):
		_bond_after()


## Limpiar con alcohol o con clorhexidina (también con la herramienta de la bandeja sobre la garra). No sobre una herida
## que sangra.
func bond_clean(with: String) -> void:
	var b := bond()
	if b == null or paused or finished:
		return
	if bool(care.snapshot().bleeding.active):
		_notice = "Primero hay que parar la sangre: sobre una herida que sangra no pega nada."
		_touch()
		return
	if b.clean(with, _bond_now()):
		_gauze_s = 0.0
		_note_touch()
		_bond_after()


func bond_purge() -> void:
	var b := bond()
	if b != null and b.purge():
		_bond_after()


func bond_apply() -> void:
	var b := bond()
	if b != null and not paused and not finished and b.apply_adhesive(_bond_now()):
		_push_fx({ "kind": "sfx", "id": "inject" })
		_bond_after()


## Coge la pieza de la bandeja (on) o la deja.
func bond_grab(on: bool = true) -> void:
	var b := bond()
	if b != null and b.grab(on):
		_bond_after()


## Gira la pieza en la mano (grados) y apunta (mm del centro del muñón; lo mide la escena con el ratón o el dedo).
func bond_turn(d_deg: float) -> void:
	var b := bond()
	if b != null:
		b.turn(d_deg)
		_touch()


## docked: si la pieza está sobre el muñón (la escena); lejos, apretar no la coloca.
func bond_aim(offset_mm: float, docked: bool = true) -> void:
	var b := bond()
	if b != null:
		b.aim(offset_mm, docked)
		_touch()


## Apretar y sujetar (on: el botón, la tecla o el dedo pulsados): con la pieza en la mano, la coloca donde apunta y la empieza
## a sujetar; al soltar (off), la suelta (ClawCareBond.let_go: antes de fijar, se suelta o se tuerce).
func bond_hold(on: bool, offset_mm: float = -1.0) -> void:
	var b := bond()
	if b == null or finished:
		return
	var now := _bond_now()
	if on:
		_early = {}
		if b.held and b.place(now, offset_mm):
			_note_touch()
			_push_fx({ "kind": "bond_place" })
	else:
		var early := b.holding and b.fixed_t < 0.0 and not b.wrapped and b.failure.is_empty() and not b.placed.is_empty()
		var left := float(Bond.adhesive_times(b.adhesive).fix_s) - (now - float(b.placed.get("t", now)))
		b.let_go(now)
		if early and not b.failure.is_empty():
			_early = { "text": "Has soltado la pieza antes de que fije: faltaban %s. Quítala, limpia y vuelve a empezar." % Bond.dur(maxf(left, 0.0)) }
	_bond_after()


## Lo que se mueve la mano mientras sujeta (mm).
func bond_move(mm: float) -> void:
	var b := bond()
	if b != null and b.holding:
		b.move(mm, _bond_now())
		_bond_after()


func bond_wrap() -> void:
	var b := bond()
	if b != null and b.wrap(_bond_now()):
		_bond_after()


func bond_unwrap() -> void:
	var b := bond()
	if b != null and b.unwrap(_bond_now()):
		_bond_after()


## Quita la pieza (despegada, torcida o para empezar de nuevo): vuelve a la bandeja y la garra, a como estaba.
func bond_remove() -> void:
	var b := bond()
	if b == null:
		return
	var key := slot_key(paw, digit)
	if _attached.has(key):
		_detach(key)
	var keep: Dictionary = b.piece
	_bonds[key] = Bond.new(keep)
	(_bonds[key] as Bond).notice = "Quitada: la pieza vuelve a la bandeja. Limpia los restos y vuelve a preparar la garra."
	_bond_after()


func bond_mix(ratio: float) -> void:
	var b := bond()
	if b != null and not paused and not finished and b.mix_acrylic(ratio, _bond_now()):
		_bond_after()


func set_layer_kind(kind: String) -> void:
	if CareData.LAYER_MM.has(kind) and kind in ["fina", "gruesa"]:
		layer_kind = kind
		_touch()


## Una capa con la espátula: del vaso (el acrílico en masa) o de resina (sin curar).
func bond_layer() -> void:
	var b := bond()
	if b == null or paused or finished:
		return
	var h := 0.0
	if b.method == "acrilico":
		h = b.apply_layer(layer_kind, _bond_now())
	elif b.method == "resina":
		h = b.apply_resin(layer_kind)
	if h > 0.0:
		_note_touch()
		_push_fx({ "kind": "bond_layer", "h": h })
	_bond_after()


func bond_lamp(id: String, d_mm: float, secs: float) -> void:
	var b := bond()
	if b != null:
		b.set_lamp(id, d_mm, secs)
		_touch()


func bond_eyes(on: bool) -> void:
	var b := bond()
	if b != null:
		b.cover_eyes(on)
		_bond_after()


func bond_lamp_on() -> void:
	var b := bond()
	if b != null and not paused and not finished and b.lamp_start(_bond_now()):
		_beeps = 0
		_push_fx({ "kind": "sfx", "id": "on" })
	_bond_after()


func bond_scrape() -> void:
	var b := bond()
	if b != null and not paused and not finished and b.scrape(_bond_now()):
		_push_fx({ "kind": "bond_scrape" })
	_bond_after()


## La prueba de la unión: un tirón suave de lado con la mitad del agarre de la garra (CareData.BOND_TEST). Si no aguanta, se
## despega: la garra vuelve a como estaba y la pieza, a la bandeja (hay que quitarla y empezar de nuevo).
func bond_test() -> void:
	var b := bond()
	if b == null or paused or finished:
		return
	if b.wrapped:
		_notice = "Primero quita la venda."
		_touch()
		return
	var f := float(CareData.BOND_TEST.force_frac) * float(CareData.claw_entry(String(setup.claw)).get("force", 0.0))
	var r := b.pull_test(_bond_now(), String(care.snapshot().claw.humidity), f)
	var key := slot_key(paw, digit)
	if not bool(r.ok) and _attached.has(key):
		_detach(key)
	_push_fx({ "kind": "sfx", "id": "snap" if not bool(r.ok) else "on" })
	_bond_after()


## Soldar con TIG sobre la garra (petición 44): no se hace; la explicación con sus números (ClawCareBond.weld_report), con
## la carne viva de la población si no se ve.
func bond_weld() -> void:
	var b := bond()
	if b == null:
		return
	var L := care.natural_mm()
	var q := float(CareData.ANIMALS[String(setup.animal)].core_ratio.value) * L
	var j := float(b.piece.get("jointMm", L))
	var r := Bond.weld_report(String(b.piece.material), maxf(j - q, 0.0))
	_notice = String(r.text)
	b.notice = String(r.text)
	_touch()


## El calor del fraguado se pasa a ClawCare.exotherm a trozos de EXO_CHUNK_S (s): el triángulo del calor (unos 10 min) queda
## bien dibujado.
const EXO_CHUNK_S := 1.0


## El tiempo de la colocación con el reloj del ensayo: el calor del acrílico que fragua (ClawCare.exotherm, a trozos de
## EXO_CHUNK_S) y, sin él, advance. Devuelve los segundos pasados.
func _bond_advance(secs: float) -> void:
	var b := bond()
	var key := slot_key(paw, digit)
	if b == null or b.method != "acrilico" or not _attached.has(key):
		care.advance(secs)
		_record_advance(key, calls, secs)
		return
	var left := secs
	while left > 1e-9:
		var t0 := care.time_s()
		var n := maxi(int(floor(minf(left, EXO_CHUNK_S) / ClawCare.DT + 1e-9)), 1)
		var dt := float(n) * ClawCare.DT
		var span := b.reacting_span(t0)
		var e := b.heat_between(t0, t0 + dt)
		if e <= 0.0 or float(span[0]) <= 0.0:
			care.advance(left)
			_record_advance(key, calls, left)
			return
		var p := { "w": e / dt, "secs": dt, "len_mm": float(span[0]) }
		care.exotherm(p)
		_record("exotherm", p)
		left -= dt


## Lo que pasa con la colocación en cada tic: la fijación, la lámpara y sus pitidos.
func _bond_tick() -> void:
	var b := bond()
	if b == null:
		return
	var now := _bond_now()
	var was_on := b.lamp_on
	var serial0 := b.serial
	b.update(now)
	if b.lamp_on or was_on:
		var n := b.lamp_beeps(now)
		while _beeps < n:
			_beeps += 1
			_push_fx({ "kind": "sfx", "id": SfxCare.BEEP })
	if was_on and not b.lamp_on:
		_push_fx({ "kind": "sfx", "id": "off" })
		_notice = b.notice
	elif b.serial != serial0 and b.notice != "":
		# lo que ha pasado solo con el tiempo (ha fijado, ha fraguado): el aviso, en la página
		_notice = b.notice
	_sync_bond()


## Una pasada de lima o de lija (r: la de ClawCare.file) con la pieza en la bandeja o puesta: sin unir, lija donde va a
## pegar; unida, quita lo que rebosa (ya duro) y baja el escalón de la funda cerca de la unión.
func _bond_file(p: Dictionary, r: Dictionary) -> void:
	var b := bond()
	if b == null:
		return
	var s := care.apex_mm() - float(p.at_mm)
	var j := float(b.piece.jointMm)
	var near := absf(s - j) <= Bond.JOINT_ZONE_MM or (String(b.piece.kind) != "funda" and String(p.zone) == "punta" and not b.attached())
	if not b.attached():
		if near or String(b.piece.kind) == "funda" and s >= j - Bond.JOINT_ZONE_MM:
			b.sand(float(r.get("raUm", 0.0)))
			_notice = b.notice
			if not b.sanded() and not b.started() and float(r.get("removedMm3", 0.0)) > 0.0:
				# la pasada ha pulido en vez de rayar: por qué y qué hacer
				var want := Bond.SANDED_RA * float(CareData.SURFACE.natural_ra_um.value)
				_notice = "Aún sin lijar: la pasada deja Ra %s µm y para pegar hace falta más de %s µm (más rugosa que la natural). Aprieta más (en la cara ancha de una rotura la fuerza se reparte y la lija pule) o usa la lija P180." % [
					Js.to_fixed(float(r.get("raUm", 0.0)), 2), Js.to_fixed(want, 2)]
		return
	if not near or b.fresh(_bond_now()):
		return
	var td := tool_data(String(p.tool))
	var trav := float(p.get("travel_mm", 0.0))
	if p.has("dwell_s"):
		trav = ClawCare.surface_speed_ms(float(td.get("drum_mm", 0.0)), float(p.get("rpm", 0.0))) * 1000.0 * float(p.dwell_s)
	var hv := float(ForgeData.PROSTHESIS[String(CareData.BOND_JOINT.polymer)].hv)
	var mm3 := ClawCare.removal_mm3(td, float(p.force_n), trav, float(CareData.BOND_JOINT.flash_w_mm), FLANK_CONTACT_MM, hv, ClawCare.hardness_mpa(hv, "natural", true))
	b.file_flash(mm3)
	if String(b.piece.kind) == "funda":
		# el escalón del borde, relleno del adhesivo curado: lo que arranca la pasada sobre la tira que toca
		b.file_step(mm3 / (float(CareData.BOND_JOINT.flash_w_mm) * FLANK_CONTACT_MM))


# ════════════════════════════════ Bandeja y mano ════════════════════════════════

## Entrada de la bandeja (copia) o {}.
static func tray_entry(id: String) -> Dictionary:
	for t: Dictionary in TRAY:
		if String(t.id) == id:
			return t.duplicate()
	return {}


## Datos de una herramienta: CareData.TOOLS o las dos de la bandeja que no están ahí.
static func tool_data(id: String) -> Dictionary:
	if EXTRA_TOOLS.has(id):
		return (EXTRA_TOOLS[id] as Dictionary).duplicate(true)
	return CareData.tool(id)


## Id de la herramienta de una tecla (1-5) o «».
static func tool_for_key(k: int) -> String:
	for t: Dictionary in TRAY:
		if int(t.key) == k:
			return String(t.id)
	return ""


## Coge una herramienta de la bandeja (la que se tenía vuelve a ella). Con el torno en la mano, el motor sigue como
## estaba; al dejarlo, se apaga.
func pick(id: String) -> void:
	if tray_entry(id).is_empty() or id == tool:
		return
	_end_gesture()
	if is_rotary(tool):
		rotary_on = false
	tool = id
	if is_rotary(id):
		# otra herramienta giratoria: empieza en su primera velocidad (la amoladora arranca a 8000 rpm, su manual)
		if id != _last_rotary:
			rpm_index = 0
		_last_rotary = id
	# la que lleva protector se apoya en él: el ángulo de su guía (45° en la amoladora)
	var guard: Variant = tool_data(id).get("guard_deg")
	if guard != null:
		angle_deg = clampf(float(guard), ANGLE_MIN, ANGLE_MAX)
	_notice = ""
	# los pasos que se cumplen al coger la herramienta (petición 51)
	_update_tutorial(care.snapshot(), false, false)
	_touch()


## Deja la herramienta en la bandeja.
func drop() -> void:
	if tool == "":
		return
	_end_gesture()
	if is_rotary(tool):
		rotary_on = false
	tool = ""
	_touch()


## Una nueva de la bandeja (unidad 5l; la tecla N): la herramienta id (por defecto, la de la mano) vuelve a cortar como el
## primer día. Solo las de limar se gastan; history lo apunta («renew_tool»).
func renew_tool(id: String = "") -> void:
	var tid := id if id != "" else tool
	if tid == "" or paused or finished:
		return
	_end_gesture()
	if not care.renew_tool(tid):
		return
	_record("renew_tool", tid)
	_notice = "%s nueva: corta como el primer día." % String(tool_data(tid).get("name", tid))
	_push_fx({ "kind": "renew", "tool": tid })
	_after()


func gesture() -> String:
	return String(tray_entry(tool).get("gesture", "")) if tool != "" else ""


## Posición 0-1 del deslizador de la presión (escala logarítmica de FORCE_MIN a FORCE_MAX) y su inversa.
static func force_to_t(f: float) -> float:
	return Format.f_to_t_in(f, FORCE_MIN, FORCE_MAX)


static func force_from_t(t: float) -> float:
	return Format.t_to_f_in(clampf(t, 0.0, 1.0), FORCE_MIN, FORCE_MAX)


func set_force(n: float) -> void:
	var v := clampf(n, FORCE_MIN, FORCE_MAX)
	if v != force_n:
		force_n = v
		_touch()


## W/S: k pasos de ×FORCE_STEP (negativo: menos).
func nudge_force(k: int) -> void:
	set_force(force_n * V8.js_pow(FORCE_STEP, float(k)))


## Mayús + rueda: k muescas de ×FORCE_WHEEL.
func wheel_force(k: int) -> void:
	set_force(force_n * V8.js_pow(FORCE_WHEEL, float(k)))


func set_angle(deg: float) -> void:
	var v := clampf(deg, ANGLE_MIN, ANGLE_MAX)
	if v != angle_deg:
		angle_deg = v
		_touch()


func nudge_angle(d: float) -> void:
	set_angle(angle_deg + d)


## ¿Es giratoria (el torno o la amoladora: gesto «torno», con interruptor y velocidades)?
static func is_rotary(id: String) -> bool:
	return id != "" and String(tray_entry(id).get("gesture", "")) == "torno"


## La herramienta giratoria de la que se habla: la de la mano o, si no se tiene ninguna, el torno.
func rotary_tool() -> String:
	return tool if is_rotary(tool) else "torno"


## Las velocidades de una herramienta giratoria (rpm, las de su ficha).
static func rpm_steps_of(id: String) -> Array:
	return CareData.TOOLS[id if CareData.TOOLS.has(id) and CareData.TOOLS[id].has("rpm_steps") else "torno"].rpm_steps


## El interruptor de la herramienta giratoria (solo con ella en la mano).
func set_rotary(on: bool) -> void:
	if not is_rotary(tool):
		on = false
	if on != rotary_on:
		rotary_on = on
		if not on:
			_end_gesture()
		_touch()


func toggle_rotary() -> void:
	set_rotary(not rotary_on)


## Velocidad de la herramienta giratoria: la posición i de sus rpm_steps (6500 y 13 000 rpm en el torno, el Dremel
## 7300-PT; 8000, 14 000, 21 000 y 25 000 rpm en la amoladora).
func set_rpm_index(i: int) -> void:
	var steps := rpm_steps_of(rotary_tool())
	var v := clampi(i, 0, steps.size() - 1)
	if v != rpm_index:
		rpm_index = v
		_touch()


func cycle_rpm() -> void:
	var steps := rpm_steps_of(rotary_tool())
	set_rpm_index((rpm_index + 1) % steps.size())


func rpm() -> float:
	var steps := rpm_steps_of(rotary_tool())
	return float(steps[mini(rpm_index, steps.size() - 1)])


## La sujeción para el selector, en corto (el nombre entero y la fuente van en la ayuda): [{ id, label, title }]. La
## sujeción de una rapaz es la capucha y la toalla; la de los demás, solo de nombre (a ellos se les anestesia).
static func sedation_options(animal: String) -> Array:
	var short := { "libre": "Libre", "sujecion": "Capucha y toalla" if animal == "rapaz" else "Sujeción", "sedacion": "Sedación", "anestesia": "Anestesia" }
	var out: Array = []
	for id: String in SEDATION_IDS:
		var e: Dictionary = CareData.SEDATION[id]
		out.append({ "id": id, "label": String(short[id]), "title": "%s. Fuente: %s" % [String(e.name), short_source(String(e.source))] })
	return out


## Las velocidades de una herramienta giratoria para el selector: [{ id (índice), label, title }] (las de CareData, con
## su fuente).
static func rpm_options(id: String = "torno") -> Array:
	var out: Array = []
	var steps := rpm_steps_of(id)
	var src := CareData.SRC_DREMEL_LITE if id == "amoladora" else CareData.SRC_DREMEL_7300
	for i in steps.size():
		var what := "Velocidad %d de %d" % [i + 1, steps.size()]
		if steps.size() == 2:
			what = "Velocidad baja" if i == 0 else "Velocidad alta"
		out.append({ "id": str(i), "label": "%s rpm" % grouped(float(steps[i])), "title": "%s · %s" % [what, short_source(src)] })
	return out


## La nota de la humedad (tarjeta de la preparación): los pasos «Ablandar antes de cortar» y «Ni seca ni empapada» del
## tutorial del motor, con sus fuentes.
static func humidity_note() -> String:
	var parts: Array = []
	for pair: Array in [["recortar", "remojar"], ["limar", "humedad"]]:
		for st: Dictionary in Tutorial.steps("rapaz", String(pair[0])):
			if String(st.id) == String(pair[1]):
				parts.append("%s (%s)" % [String(st.text), short_source(String(st.source))])
	return " ".join(parts)


## Un entero con los miles separados por un espacio duro a partir de cinco cifras («13 000»; «6500» sin separar): el de
## ClawCare (los textos del motor y los de la página, igual).
## Lo que aguanta de lado frente a la natural, en palabras (lo pidió la 5k; unidad 5o): en tanto por ciento hasta 10 veces y,
## desde ahí, «×1883» (un bloque romo recién pegado aguanta miles de veces más que una punta fina: «188327 %» no se lee).
## short: sin «de la natural».
static func strength_words(sr: float, short: bool = false) -> String:
	if sr >= 10.0:
		return ("×%s" if short else "×%s la natural") % grouped(Js.js_round(sr))
	return ("%s %%" if short else "%s %% de la natural") % Js.to_fixed(sr * 100.0, 0)


static func grouped(x: float) -> String:
	return ClawCare.grouped(x)


## Desde qué ángulo la lima va de frente (texto de la ayuda): el de ClawCare.
static func frontal_text() -> String:
	return "a partir de %s°, de frente" % Js.to_fixed(ClawCare.TRUNCATE_DEG, 0)


## Velocidad de la superficie del tambor de la herramienta giratoria (m/s), la de ClawCare.
func drum_speed_ms() -> float:
	return ClawCare.surface_speed_ms(float(CareData.TOOLS[rotary_tool()].drum_mm), rpm())


func set_paused(on: bool) -> void:
	if on != paused:
		paused = on
		if on:
			_end_gesture()
		_touch()


func toggle_pause() -> void:
	set_paused(not paused)


## Velocidad del reloj (una de TIME_SCALES).
func set_time_scale(x: float) -> void:
	var v := float(TIME_SCALES[0])
	for t: float in TIME_SCALES:
		if absf(t - x) < absf(v - x):
			v = t
	if v != time_scale:
		time_scale = v
		_touch()


# ════════════════════════════════ Gestos ════════════════════════════════

## Zona («punta» o «flanco») y distancia a la punta (mm) de un contacto en s (mm desde la base).
func zone_at(s_mm: float) -> Dictionary:
	var apex := care.apex_mm()
	var tip_zone := tip_zone_mm()
	var at := maxf(apex - s_mm, 0.0)
	return { "zone": "punta" if at <= tip_zone else "flanco", "at_mm": at, "tip_zone_mm": tip_zone }


## Largo de la zona de la punta (mm): TIP_ZONE_FRACTION del largo natural de la garra de este dedo, con TIP_ZONE_MIN_MM
## como mínimo.
func tip_zone_mm() -> float:
	var nat := care.natural_mm() if care != null else float(CareData.claw_entry(String(setup.claw)).reach)
	return maxf(TIP_ZONE_FRACTION * nat, TIP_ZONE_MIN_MM)


## Aprieta la herramienta de la mano contra la garra en s_mm (mm desde la base; fuera de la garra, nada).
func press_on(s_mm: float) -> void:
	if tool == "" or paused or finished or s_mm < 0.0 or s_mm > care.apex_mm() + 0.5:
		return
	_end_gesture()
	var g := gesture()
	# la pieza puesta (unidad 5o): no se lima en fresco ni con la venda puesta
	var bd := bond()
	if bd != null and g in ["lima", "torno"] and bd.attached() and s_mm >= float(bd.piece.jointMm) - Bond.JOINT_ZONE_MM:
		if bd.wrapped:
			_notice = "Primero quita la venda: debajo está la unión."
			_touch()
			return
		if not bd.set_all(care.time_s()):
			_notice = "Aún no ha fraguado: en fresco se embadurna. Lo que rebosa, con la espátula; se lima ya duro." if bd.method != "adhesivo" else "Aún no ha fijado: no la toques hasta que fije."
			_touch()
			return
	var z := zone_at(s_mm)
	_gesture = { "kind": g, "tool": tool, "s": s_mm, "zone": z.zone, "at_mm": z.at_mm, "acc_mm": 0.0,
		"acc_along": 0.0, "acc_t": 0.0, "total_mm": 0.0, "signs": 0, "closing": 0.0, "contact": true, "touch_t": 0.0, "held_t": 0.0 }
	_notice = ""
	_early = {}
	_note_touch()
	if finished:
		# el animal se ha revuelto: la sesión se ha parado
		_gesture = {}
		_touch()
		return
	if g in ["lima", "torno"]:
		# la pasada (o el toque) que empieza: lo que deja se cuenta al levantar la herramienta (petición 51, «las limas, claras»)
		_pass = { "tool": tool, "mm3": 0.0, "raUm": -1.0, "apexBefore": care.apex_mm(), "ratioBefore": float(care.tip_state().ratio),
			"noBite": true, "chunks": 0, "s": s_mm, "heatW": 0.0 }
	match g:
		"aplicar":
			_gesture = {}
			_apply_tool()
		"remojar":
			_gesture = {}
			care.set_humidity("humeda")
			_record("set_humidity", "humeda")
			_log_action({ "kind": "remojar" })
			_after()
		"torno":
			if not rotary_on:
				_notice = ("La amoladora está apagada: enciéndela con su interruptor (tecla E o un clic en el aire)." if tool == "amoladora"
					else "El torno está apagado: enciéndelo con su interruptor (tecla E).")
	_touch()


## Mueve la herramienta apretando: along_mm (a lo largo de la garra, + hacia la punta), travel_mm (lo que desliza),
## s_mm (dónde toca ahora; −1 si se ha salido de la garra) y dt (s; el tiempo lo lleva tick()).
func drag(along_mm: float, travel_mm: float, s_mm: float, _dt: float = 0.0) -> void:
	if _gesture.is_empty() or paused or finished:
		return
	var trav := maxf(absf(travel_mm), absf(along_mm))
	match String(_gesture.kind):
		"lima":
			# la lima desliza apoyada donde se apretó: cuenta lo que recorre, no dónde queda el ratón
			_gesture["acc_mm"] = float(_gesture.acc_mm) + trav
			_gesture["acc_along"] = float(_gesture.acc_along) + along_mm
			if float(_gesture.acc_mm) >= STROKE_CHUNK_MM:
				_file_chunk()
			if not _gesture.is_empty() and float(_gesture.total_mm) >= FILE_LENGTH_MM:
				_end_gesture()
				_notice = "Fin de la pasada: la lima mide %s mm. Levántala y vuelve a empezar." % Js.to_fixed(FILE_LENGTH_MM, 0)
		"torno", "presion", "corte":
			# el tambor, la gasa o el cortaúñas van donde toca el ratón
			if s_mm >= 0.0 and s_mm <= care.apex_mm() + 0.5:
				var z := zone_at(s_mm)
				_gesture["s"] = s_mm
				_gesture["zone"] = z.zone
				_gesture["at_mm"] = z.at_mm
				_gesture["contact"] = true
			elif String(_gesture.kind) != "presion":
				# la gasa o el hemostático se quedan apretados donde estaban hasta soltar el botón: una punta recién cortada
				# se ve muy fina, y un temblor del ratón fuera de su silueta paraba el tiempo sin avisar (fallo de Eric)
				_gesture["contact"] = false
			_gesture["acc_along"] = float(_gesture.acc_along) + along_mm
	_touch()


## Levanta la herramienta: lo que quede de la pasada se lima; un cortaúñas a medio cerrar se vuelve a abrir.
func release() -> void:
	_end_gesture()


## Pasa dt segundos: los gestos que duran (pasada, torno, presión, cortaúñas) trabajan y el resto del tiempo pasa en el
## ensayo sin tocar la garra (advance).
func tick(dt: float) -> void:
	if paused or finished or not (dt > 0.0) or not is_finite(dt):
		return
	_tick_reading(dt)
	dt *= time_scale
	_debt += dt
	# con un gesto en marcha se le está cogiendo la garra: sin sujetar, ese tiempo sí le estresa (claw_care_patient.gd)
	patient.gripped = not _gesture.is_empty()
	var reserve := 0.0
	if not _gesture.is_empty():
		match String(_gesture.kind):
			"lima":
				_gesture["acc_t"] = float(_gesture.acc_t) + dt
				if float(_gesture.acc_t) >= STROKE_CHUNK_S:
					_file_chunk()
				reserve = float(_gesture.get("acc_t", 0.0))
			"torno":
				if rotary_on and bool(_gesture.contact):
					_gesture["acc_t"] = float(_gesture.acc_t) + dt
					# lo que lleva tocando seguido (para «toques de unos segundos»)
					_gesture["touch_t"] = float(_gesture.get("touch_t", 0.0)) + dt
					if float(_gesture.acc_t) >= ROTARY_CHUNK_S:
						_rotary_chunk()
				elif float(_gesture.acc_t) > 0.0:
					_rotary_chunk()
				reserve = float(_gesture.get("acc_t", 0.0))
			"presion":
				if bool(_gesture.contact):
					_gesture["acc_t"] = float(_gesture.acc_t) + dt
					_gesture["held_t"] = float(_gesture.get("held_t", 0.0)) + dt
					if float(_gesture.acc_t) >= PRESS_CHUNK_S:
						_press_chunk()
				elif float(_gesture.acc_t) > 0.0:
					_press_chunk()
				reserve = float(_gesture.get("acc_t", 0.0))
			"corte":
				_gesture["closing"] = float(_gesture.closing) + dt
				if float(_gesture.closing) >= CLIP_CLOSE_S:
					_clip_now()
	_idle(reserve)
	if not _slots.is_empty():
		_tick_others()
	if _gesture.is_empty() and _gauze_s > 0.0:
		_gauze_s = 0.0
	_touch()


## Pasa en el ensayo el tiempo que debe el reloj, menos el que va a gastar el gesto en marcha (reserve), en pasos
## enteros de ClawCare.DT.
func _idle(reserve: float = 0.0) -> void:
	var steps := int(floor((_debt - reserve) / ClawCare.DT + 1e-9))
	if steps <= 0:
		return
	var t0 := care.time_s()
	_bond_advance(float(steps) * ClawCare.DT)
	_debt -= care.time_s() - t0
	_bond_tick()
	_after()


## Tiempo del ensayo (s) y lo que debe el reloj (para los tests: la suma es el tiempo real pasado con tick()).
func clock() -> Dictionary:
	return { "t_s": care.time_s(), "debt_s": _debt }


## Cierra el gesto en marcha: la lima lima lo que le quede; el torno y la presión, su último trozo. Lo que lleva tiempo y se
## suelta antes de acabar lo dice (_early: «Has soltado antes de tiempo: faltaban 12 s»); la pasada o el toque se apunta.
func _end_gesture() -> void:
	if _gesture.is_empty():
		return
	var kind := String(_gesture.kind)
	match kind:
		"lima":
			if float(_gesture.acc_mm) > 0.0:
				_file_chunk()
		"torno":
			if float(_gesture.acc_t) > 0.0 and rotary_on:
				_rotary_chunk()
		"presion":
			if float(_gesture.acc_t) > 0.0:
				_press_chunk()
	match kind:
		"presion":
			var bl: Dictionary = care.snapshot().bleeding
			if bool(bl.active) and float(_gesture.get("held_t", 0.0)) > 0.0:
				_early = { "text": "Has soltado antes de tiempo: faltaban %s s de presión. Vuelve a apretar sobre la herida y mantén pulsado." % Js.to_fixed(ceilf(float(bl.needS)), 0) }
		"corte":
			if float(_gesture.closing) < CLIP_CLOSE_S:
				_early = { "text": "Has soltado antes de que se cierre: el cortaúñas se abre sin cortar. Mantén pulsado sobre la garra hasta que corte (%s s)." % Js.to_fixed(CLIP_CLOSE_S, 2) }
		"lima", "torno":
			_close_pass(kind)
	_gesture = {}
	_touch()


## Suma a la pasada (o al toque) en marcha lo que ha hecho un tramo de file().
func _pass_add(r: Dictionary) -> void:
	if _pass.is_empty():
		return
	_pass["mm3"] = float(_pass.mm3) + float(r.get("removedMm3", 0.0))
	_pass["chunks"] = int(_pass.chunks) + 1
	if float(r.get("removedMm3", 0.0)) > 0.0 or float(_pass.raUm) < 0.0:
		_pass["raUm"] = float(r.get("raUm", 0.0))
	_pass["noBite"] = bool(_pass.noBite) and bool(r.get("noBite", false))
	_pass["heatW"] = maxf(float(_pass.heatW), float(r.get("heatW", 0.0)))


## Apunta la pasada (o el toque) que acaba: lo que ha quitado, la superficie que deja y la forma que queda. Las últimas 8.
func _close_pass(kind: String) -> void:
	if _pass.is_empty():
		return
	if int(_pass.chunks) > 0:
		var rec := _pass.duplicate()
		rec["apexAfter"] = care.apex_mm()
		rec["leftAfter"] = care.overgrowth_left_mm()
		rec["ratioAfter"] = float(care.tip_state().ratio)
		rec["touchS"] = float(_gesture.get("touch_t", 0.0))
		_passes.push_front(rec)
		if _passes.size() > 8:
			_passes.pop_back()
		var act := "toque" if kind == "torno" else "pasada"
		_step_acts[act] = int(_step_acts.get(act, 0)) + 1
	_pass = {}


## Se tocan las garras: a un animal grande sin sedar ni anestesiar, cada toque cuenta (el primero avisa; el segundo, ataca).
func _note_touch() -> void:
	if String(setup.animal) != "rapaz" and not patient.restrained():
		_unsafe_touches += 1
		_check_animal()


## Un tramo cuenta como ida o vuelta si se mueve al menos DIRECTION_MM a lo largo de la garra (el pulso no la cambia).
const DIRECTION_MM := 0.5


## Dirección de un tramo: a favor (de la base a la punta), en contra, o en vaivén si la misma pasada ha ido y vuelto.
func _chunk_direction(along: float) -> String:
	if absf(along) >= DIRECTION_MM:
		_gesture["signs"] = int(_gesture.signs) | (1 if along > 0.0 else 2)
	var signs := int(_gesture.signs)
	if signs == 3:
		return "vaiven"
	if signs == 2:
		return "en_contra"
	return "a_favor"


## Un tramo de la pasada de lima: file() con lo recorrido desde el tramo anterior (a la velocidad del arrastre).
func _file_chunk() -> void:
	var trav := float(_gesture.acc_mm)
	var el := float(_gesture.acc_t)
	var along := float(_gesture.acc_along)
	_gesture["acc_mm"] = 0.0
	_gesture["acc_t"] = 0.0
	_gesture["acc_along"] = 0.0
	if trav <= 0.0:
		return
	_gesture["total_mm"] = float(_gesture.total_mm) + trav
	var speed := clampf(trav / el if el > 0.0 else SPEED_MAX, SPEED_MIN, SPEED_MAX)
	var p := {
		"tool": String(_gesture.tool), "zone": String(_gesture.zone), "angle_deg": angle_deg, "at_mm": float(_gesture.at_mm),
		"length_mm": FLANK_CONTACT_MM, "force_n": force_n, "travel_mm": trav, "speed_mm_s": speed,
		"direction": _chunk_direction(along),
	}
	var t0 := care.time_s()
	var r := care.file(p)
	_record("file", p.duplicate())
	_debt -= care.time_s() - t0
	_bond_file(p, r)
	_pass_add(r)
	_log_action({ "kind": "file", "params": p, "result": r })
	_sfx("file", r)
	_rasp(String(p.tool), speed, bool(r.get("rubbing", false)))
	_after()


## Tono y duración del roce de la lima o del tambor (diseño de sonido): con dientes, los dientes que pasan por segundo
## frente a RASP_REF_TPS; con grano, la velocidad frente a 100 mm/s, algo más agudo; el torno, más agudo todavía. Si roza
## sin morder (unidad 5l), un chirrido: el mismo roce, RASP_SQUEAL veces más agudo.
func _rasp(tool_id: String, speed_mm_s: float, squeal: bool = false) -> void:
	var d := tool_data(tool_id)
	var pitch := 1.0
	if String(d.get("kind", "")) == "torno":
		pitch = 1.6
	elif String(d.get("element", "")) == "diente":
		pitch = float(d.teeth_cm) * speed_mm_s / 10.0 / RASP_REF_TPS
	else:
		pitch = 1.25 * speed_mm_s / 100.0
	_rasp_pitch = clampf(pitch, 0.6, 1.8) * (RASP_SQUEAL if squeal else 1.0)
	_rasp_squeal = squeal
	_rasp_until = care.time_s() + RASP_HOLD_S * time_scale


## Un trozo de contacto del torno encendido: file() con el tiempo de contacto y las rpm.
func _rotary_chunk() -> void:
	var dwell := float(_gesture.acc_t)
	var along := float(_gesture.acc_along)
	var steps := int(floor(dwell / ClawCare.DT + 1e-9))
	if steps <= 0 or not rotary_on:
		return
	_gesture["acc_t"] = dwell - float(steps) * ClawCare.DT
	_gesture["acc_along"] = 0.0
	var p := {
		"tool": String(_gesture.tool), "zone": String(_gesture.zone), "angle_deg": angle_deg, "at_mm": float(_gesture.at_mm),
		"length_mm": FLANK_CONTACT_MM, "force_n": force_n, "dwell_s": float(steps) * ClawCare.DT, "rpm": rpm(),
		"direction": _chunk_direction(along),
	}
	var t0 := care.time_s()
	var r := care.file(p)
	_record("file", p.duplicate())
	_debt -= care.time_s() - t0
	_bond_file(p, r)
	_pass_add(r)
	_log_action({ "kind": "file", "params": p, "result": r })
	_sfx("file", r)
	_rasp(String(p.tool), 0.0, bool(r.get("rubbing", false)))
	_after()


## Un trozo de presión con el hemostático, el nitrato de plata o la gasa.
func _press_chunk() -> void:
	var secs := float(_gesture.acc_t)
	var steps := int(floor(secs / ClawCare.DT + 1e-9))
	if steps <= 0:
		return
	_gesture["acc_t"] = secs - float(steps) * ClawCare.DT
	var tid := String(_gesture.tool)
	var p := { "tool": "" if tid == "presion" else tid, "pressure_s": float(steps) * ClawCare.DT }
	var t0 := care.time_s()
	var r := care.hemostasis(p)
	_record("hemostasis", p.duplicate())
	_debt -= care.time_s() - t0
	# la gasa seca la garra mojada para pegar (unidad 5o)
	var bd := bond()
	if bd != null and tid == "presion":
		_gauze_s += float(p.pressure_s)
		bd.dry(_gauze_s, care.time_s())
		if not bd.notice.is_empty():
			_notice = bd.notice
	_log_action({ "kind": "hemostasis", "params": p, "result": r })
	_sfx("hemostasis", r)
	_after()


## El cortaúñas se ha cerrado: clip() donde toca, quitando lo que hay de ahí a la punta.
func _clip_now() -> void:
	var s := float(_gesture.s)
	var p := { "tool": String(_gesture.tool), "remove_mm": maxf(care.apex_mm() - s, 0.0) }
	_gesture = {}
	var t0 := care.time_s()
	var r := care.clip(p)
	_record("clip", p.duplicate())
	_debt -= care.time_s() - t0
	_log_action({ "kind": "clip", "params": p, "result": r, "s": s })
	_sfx("clip", r)
	if bool(r.cut):
		_step_acts["corte"] = int(_step_acts.get("corte", 0)) + 1
	if not bool(r.cut) and String(r.reason) != "":
		_notice = "No corta: %s." % String(r.reason)
	_after()


## Probar la punta (unidad 5g; lo pidió la 5b): el vértice contra una uña con un toque ligero (ClawCare.probe_tip). No hace
## falta tener una herramienta en la mano; deja la que se tenga como está.
func probe_tip() -> void:
	if paused or finished:
		return
	_end_gesture()
	_note_touch()
	_early = {}
	_step_acts["prueba"] = int(_step_acts.get("prueba", 0)) + 1
	var t0 := care.time_s()
	var r := care.probe_tip({})
	_record("probe_tip", {})
	_debt -= care.time_s() - t0
	# el texto de la acción ya lo dice (texts.action): sin repetirlo en el aviso
	_log_action({ "kind": "probe", "result": r })
	_sfx("probe", r)
	_after()


## Un toque con la clorhexidina, la crema o el metacrilato.
func _apply_tool() -> void:
	# la colocación (unidad 5o): el alcohol limpia, la espátula pone una capa o quita lo que rebosa en fresco, y la
	# clorhexidina, además de desinfectar, limpia donde va a pegar
	var bd := bond()
	if tool == "alcohol":
		if bd == null:
			_notice = "El alcohol es para limpiar donde va a pegar una pieza de la reforja."
		else:
			bond_clean("alcohol")
		_touch()
		return
	if tool == "espatula":
		if bd == null:
			_notice = "La espátula es para el acrílico, la resina y lo que rebosa de una pieza de la reforja."
		elif (bd.method == "acrilico" and not bd.mix.is_empty()) or (bd.method == "resina" and not bd.done_building() and (bd.resin.is_empty() or float(bd.resin.back().dose) > 0.0)):
			bond_layer()
		else:
			bond_scrape()
		_touch()
		return
	if tool == "clorhexidina" and bd != null and not bd.started():
		bond_clean("clorhexidina")
	var p := { "tool": tool }
	var r := care.apply(p)
	_record("apply", p.duplicate())
	_log_action({ "kind": "apply", "params": p, "result": r })
	if not bool(r.get("ok", false)):
		_notice = "Aún no: %s." % String(r.get("reason", "no se puede"))
	else:
		_push_fx({ "kind": "apply", "tool": tool })
		_sfx("apply", r)
	_after()


func _log_action(a: Dictionary) -> void:
	a["t_s"] = care.time_s()
	_last_action = a
	var r: Dictionary = a.get("result", {})
	match String(a.kind):
		"file":
			var mm3 := float(r.get("removedMm3", 0.0))
			if mm3 > 0.0 or bool(r.get("noBite", false)):
				# lo que sale (unidad 5l): polvo, limaduras o virutas del color del material (ClawCare.debris_for); sin morder,
				# nada (resbala o roza)
				_push_fx({ "kind": "dust", "mm3": mm3, "tool": String(r.get("tool", "")), "noBite": bool(r.get("noBite", false)),
					"zone": String(a.params.zone), "at_mm": float(a.params.at_mm), "debris": (r.get("debris", {}) as Dictionary).duplicate(),
					"rubbing": bool(r.get("rubbing", false)), "heatW": float(r.get("heatW", 0.0)) })
			if bool(r.get("chipped", false)):
				_push_fx({ "kind": "chip" })
			if bool(r.get("peeled", false)):
				_push_fx({ "kind": "peel" })
		"clip":
			if bool(r.get("cut", false)):
				_push_fx({ "kind": "clip", "splitMm": float(r.get("splitMm", 0.0)), "s": float(a.get("s", 0.0)) })
		"probe":
			# la prueba de la uña (la escena puede dibujar la uña y, si se mella, el trozo que salta)
			_push_fx({ "kind": "probe", "verdict": String(r.get("verdict", "")) })
			if bool(r.get("chipped", false)):
				_push_fx({ "kind": "chip" })


## Efecto de sonido de una acción (el id de ClawCare.sfx_for): el de las pasadas no se repite antes de SFX_GAP_S.
func _sfx(action: String, r: Dictionary) -> void:
	var id := care.sfx_for(action, r)
	if id == "":
		return
	var now := care.time_s()
	var repeat := id.begins_with("scratch") or id == "slide"
	if repeat and _sfx_at.has(id) and now - float(_sfx_at[id]) < SFX_GAP_S:
		return
	_sfx_at[id] = now
	_push_fx({ "kind": "sfx", "id": id })


func _push_fx(e: Dictionary) -> void:
	_fx_n += 1
	e["n"] = _fx_n
	_fx.append(e)
	if _fx.size() > FX_LOG:
		_fx.pop_front()


## Después de cada cambio de la garra: sangre que empieza (sonido y tutorial) y el tutorial.
func _after() -> void:
	var sn := care.snapshot()
	var bleeding := bool(sn.bleeding.active)
	var broken := bool(sn.damage.broken)
	if bleeding and not _was_bleeding:
		_push_fx({ "kind": "bleed" })
	_update_tutorial(sn, bleeding and not _was_bleeding, broken and not _was_broken)
	_check_mistakes(sn)
	_was_bleeding = bleeding
	_was_broken = broken
	var n0 := _notice
	_check_animal()
	_sync_reaction(_notice != n0)
	_touch()


## Los errores nuevos que avisa el motor (sus sucesos): de los de un mismo gesto, el más urgente (la sangre, luego la
## garra rota o quemada) queda como el error que hay que explicar.
func _check_mistakes(sn: Dictionary) -> void:
	var ev: Array = sn.events
	var best := -1
	for i in range(_ev_seen, ev.size()):
		var code := String(ev[i].code)
		if not MISTAKE_FIX.has(code):
			continue
		var rank := int(MISTAKE_RANK.get(code, 1))
		if rank >= best:
			best = rank
			_mistake = { "code": code, "message": String(ev[i].message), "source": String(ev[i].source) }
	_ev_seen = ev.size()
	# arreglado (se cumple la condición del paso que lo arregla: la grieta limada, la sangre parada…), deja de explicarse
	if not _mistake.is_empty():
		var chk := String(_fix_step().get("step", {}).get("check", ""))
		if chk != "" and care.check(chk):
			_mistake = {}


## El paso del tutorial que arregla el error de ahora: { pid, sid, step } (step: {} si el tutorial no lo tiene).
func _fix_step() -> Dictionary:
	var code := String(_mistake.code)
	var fix: Array = MISTAKE_FIX[code]
	var pid := String(fix[0])
	var sid := String(fix[1])
	if code == "no_cabe" and String(setup.animal) == "rapaz":
		sid = "guillotina"
	if code == "mella" and is_reforged():
		pid = "reforjada"
		sid = "fragil"
	if code == "se_mueve" and String(setup.animal) != "rapaz":
		sid = "anestesia"
	var step := {}
	for st: Dictionary in Tutorial.steps(String(setup.animal), pid, String(setup.inlay)):
		if String(st.id) == sid:
			step = st
	return { "pid": pid, "sid": sid, "step": step }


## El error que hay que explicar (el último): { code, what, what_source, fix_title, fix_text, fix_source, control } o {}:
## qué ha pasado (el aviso del motor) y cómo se arregla (el paso del tutorial que lo arregla, con su fuente y su mando).
func mistake_view() -> Dictionary:
	if _mistake.is_empty():
		return {}
	var code := String(_mistake.code)
	var fs := _fix_step()
	var pid := String(fs.pid)
	var sid := String(fs.sid)
	var step: Dictionary = fs.step
	var out := { "code": code, "what": String(_mistake.message), "what_source": short_source(String(_mistake.source)),
		"fix_title": "", "fix_text": "", "fix_source": "", "control": String(STEP_CONTROLS.get(sid, "")) }
	if not step.is_empty():
		out["fix_title"] = "%s · %s" % [String(Tutorial.PROCESS_NAMES.get(pid, pid)), String(step.title)]
		out["fix_text"] = String(step.text)
		out["fix_source"] = short_source(String(step.source))
	return out


## Entendido: el error explicado deja de enseñarse (hasta el siguiente).
func dismiss_mistake() -> void:
	if not _mistake.is_empty():
		_mistake = {}
		_touch()


func _touch() -> void:
	_serial += 1


func serial() -> int:
	return _serial


# ════════════════════════════════ Final ════════════════════════════════

## Termina: se para el reloj, se enseña el informe y se revela la carne viva.
func finish() -> void:
	if finished:
		return
	_end_gesture()
	rotary_on = false
	finished = true
	_touch()


## La rapaz que se ha soltado se recoge con una toalla, se encapucha y se deja calmar (Samour 2006, pp. 916-917): la
## sesión sigue con la misma garra y lo hecho, sujeta con capucha y toalla y en la pausa; el informe cuenta las veces que
## se soltó. Solo tras «se_suelta» (halted.recoverable): un tigre o un oso que ataca, o la sangre, no se arreglan así.
func recapture() -> void:
	if halted.is_empty() or not bool(halted.get("recoverable", false)):
		return
	escapes += 1
	halted = {}
	finished = false
	_warned.erase("rapaz_suelta")
	# al cogerla, aún suelta, puede clavar las garras: un zarpazo contra la lente puesta (ClawCareReaction.RECAPTURE)
	var struck := patient.recapture_roll()
	var hit_text := ""
	if struck:
		_sync_reaction()
		hit_text = " Al cogerla te ha soltado un zarpazo: %s" % String(patient.reaction_lens.get("reason", ""))
	care.set_sedation("sujecion")
	_record("set_sedation", "sujecion")
	patient.rest(true)
	_notice = "La recoges con la toalla y la encapuchas: a oscuras se queda quieta y se va calmando. Sigue cuando la barra de estrés baje de «inquieto».%s" % hit_text
	_after()


## Vuelve al ensayo después de ver el informe (sin empezar otro). Con la sesión parada por el animal, no: se empieza de nuevo
## (salvo la rapaz que se ha soltado, que se recoge: recapture).
func resume() -> void:
	if finished and halted.is_empty():
		finished = false
		_touch()


# ════════════════════════════════ Tutorial ════════════════════════════════

func _reset_tutorial() -> void:
	_flow = (FLOW_REFORGED if is_reforged() else FLOW_KERATIN).duplicate()
	# (unidad 5v) la garra que llega rota: después de preparar al animal, parar la sangre (si sangra) y la garra rota
	if care != null and String(care.snapshot().damage.get("brokenStart", "")) != "":
		var at := mini(1, _flow.size())
		_flow.insert(at, "reconstruir")
		if bool(care.snapshot().bleeding.active):
			_flow.insert(at, "sangrado")
	_proc = 0
	_step = 0
	_prev_check = {}
	_done = {}
	_return_to = []
	_seed_checks()


func set_tutorial(on: bool) -> void:
	if on != tutorial_on:
		tutorial_on = on
		_touch()


## Procesos del tutorial ahora (con «sangrado» y «reconstruir» si han entrado).
func flow() -> Array:
	return _flow.duplicate()


func process_id() -> String:
	return String(_flow[_proc]) if _proc < _flow.size() else ""


## Cuántos pasos tiene un proceso, sin mirar sus condiciones (para el progreso del total; guardado por animal, material y
## pieza: la vista lo pide en cada fotograma).
func _step_count(pid: String) -> int:
	var b := bond()
	var key := "%s|%s" % [pid, care.tutorial_key()]
	if pid == Tutorial.BOND_PROCESS:
		if b == null:
			return 0
		key += "|%s|%s|%s|%s" % [b.method, String(b.piece.kind), b.adhesive, str(bool(b.piece.get("broken", String(b.piece.kind) != "funda")))]
	if not _step_counts.has(key):
		if pid == Tutorial.BOND_PROCESS:
			_step_counts[key] = Tutorial.bond_steps(String(setup.animal), b.method, String(b.piece.kind), b.adhesive, bool(b.piece.get("broken", String(b.piece.kind) != "funda"))).size()
		else:
			_step_counts[key] = care.tutorial(pid).size() if pid != "" else 0
	return int(_step_counts[key])


func _steps_of(pid: String) -> Array:
	var steps: Array = []
	if pid == Tutorial.BOND_PROCESS:
		steps = _bond_steps()
	elif pid != "":
		steps = care.tutorial(pid)
	var cur := pid == process_id()
	for i in steps.size():
		var st: Dictionary = steps[i]
		var chk := String(st.check)
		# lo que se tiene en la mano (petición 51: pasos que se cumplen al coger la herramienta)
		if STATE_CHECKS.has(chk):
			st["done"] = (STATE_CHECKS[chk] as Array).has(tool)
		# lo que pide hacer, contado desde que se llegó al paso (solo el de ahora; los demás, por hacer)
		var act: Array = STEP_ACTION.get(String(st.id), [])
		if not act.is_empty():
			var base := chk == "" or bool(st.done)
			st["base_check"] = chk
			st["check"] = "accion"
			st["done"] = base and cur and i == _step and _act_count(String(act[0])) >= int(act[1])
		st["goal"] = String(STEP_GOALS.get(String(st.id), String(st.title)))
	return steps


## Lo que se ha hecho desde que se llegó al paso de ahora: cortes, pasadas, toques del torno, pruebas de la punta, o si ya hay
## faceta.
func _act_count(kind: String) -> int:
	if kind == "faceta":
		return 1 if float(care.tip_state().get("facetDeg", 0.0)) > 0.0 else 0
	return int(_step_acts.get(kind, 0))


## Sigue mientras el paso al que se llega ya se cumple (hecho antes de llegar a él): sin «Siguiente» (petición 51).
func _advance_done() -> void:
	for guard in 32:
		var st := current_step()
		if st.is_empty() or String(st.check) == "" or not bool(st.done):
			return
		_done[_key(process_id(), String(st.id))] = true
		var steps := _steps_of(process_id())
		if _step + 1 < steps.size():
			_step += 1
		else:
			_next_process()
		_seed_checks()


## El tiempo de leer un paso informativo (s reales): READ_S_PER_WORD por palabra, entre READ_MIN_S y READ_MAX_S.
static func read_s(st: Dictionary) -> float:
	var words := (String(st.get("title", "")) + " " + String(st.get("text", ""))).split(" ", false).size()
	return clampf(float(words) * READ_S_PER_WORD, READ_MIN_S, READ_MAX_S)


## Pasa el tiempo de lectura de un paso informativo: leído, sigue solo.
func _tick_reading(dt: float) -> void:
	if not tutorial_on or tutorial_done() or finished:
		return
	var st := current_step()
	if st.is_empty() or String(st.check) != "":
		return
	_read_t += dt
	if _read_t >= read_s(st):
		tutorial_next()


## Los pasos de «Colocar la pieza de la reforja» (unidad 5o) con lo hecho: las condiciones de la colocación las comprueba
## ClawCareBond.check y las demás (la sangre), ClawCare.check. Sin pieza, ninguno.
func _bond_steps() -> Array:
	var b := bond()
	if b == null:
		return []
	var pc: Dictionary = b.piece
	var steps := Tutorial.bond_steps(String(setup.animal), b.method, String(pc.kind), b.adhesive, bool(pc.get("broken", String(pc.kind) != "funda")))
	var now := care.time_s()
	var stp := joint_step_mm()
	for st: Dictionary in steps:
		var chk := String(st.check)
		if chk == "":
			st["done"] = null
		elif Tutorial.BOND_CHECKS.has(chk):
			st["done"] = b.check(chk, now, stp)
		else:
			st["done"] = care.check(chk)
	return steps


func _key(pid: String, sid: String) -> String:
	return "%s/%s" % [pid, sid]


## Guarda el valor de la condición del paso actual (para ver cuándo pasa de falsa a verdadera). Al llegar a un paso, lo que
## se ha hecho en él y su tiempo de lectura empiezan de cero.
func _seed_checks() -> void:
	_step_acts = {}
	_read_t = 0.0
	var st := current_step()
	if not st.is_empty() and String(st.check) != "":
		_prev_check[_key(process_id(), String(st.id))] = bool(st.done)


## Paso actual (con done) o {} si el tutorial ha terminado.
func current_step() -> Dictionary:
	var steps := _steps_of(process_id())
	if _step < 0 or _step >= steps.size():
		return {}
	return steps[_step]


## Siguiente paso (o el primero del proceso siguiente). Al acabar «sangrado» o «reconstruir», vuelve donde estaba.
func tutorial_next() -> void:
	var st := current_step()
	if not st.is_empty():
		_done[_key(process_id(), String(st.id))] = true
	var steps := _steps_of(process_id())
	if _step + 1 < steps.size():
		_step += 1
	else:
		_next_process()
	_seed_checks()
	_advance_done()
	_touch()


func tutorial_prev() -> void:
	if _step > 0:
		_step -= 1
	elif _proc > 0:
		_proc -= 1
		_step = maxi(_steps_of(process_id()).size() - 1, 0)
	_seed_checks()
	_touch()


## Salta a un proceso (el selector de procesos del panel).
func tutorial_goto(pid: String) -> void:
	var i := _flow.find(pid)
	if i < 0:
		return
	_proc = i
	_step = 0
	_seed_checks()
	_touch()


func _next_process() -> void:
	var pid := process_id()
	if pid in ["sangrado", "reconstruir", Tutorial.ATTACK_PROCESS]:
		var broken := bool(care.snapshot().damage.broken)
		var repaired := bool(care.snapshot().damage.repaired)
		if pid == "sangrado" and broken and not repaired and not _flow.has("reconstruir"):
			_flow.insert(_proc + 1, "reconstruir")
			_proc += 1
			_step = 0
			return
		if not _return_to.is_empty():
			var back: Array = _return_to.pop_back()
			var i := _flow.find(String(back[0])) if String(back[0]) != "" else _flow.size()
			_proc = i if i >= 0 else mini(_proc + 1, _flow.size())
			_step = int(back[1])
			return
	_proc += 1
	_step = 0


## ¿Ha acabado el tutorial (pasado el último paso)?
func tutorial_done() -> bool:
	return _proc >= _flow.size()


func _update_tutorial(sn: Dictionary, bled_now: bool, broke_now: bool) -> void:
	var pid := process_id()
	if (bled_now or broke_now) and not (pid in ["sangrado", "reconstruir"]):
		# la sangre manda: «Si sangra» (y después, si está rota, «Garra rota»); luego se vuelve aquí (o al final)
		_return_to.append([pid, _step])
		var target := "sangrado" if bool(sn.bleeding.active) else "reconstruir"
		var i := _flow.find(target)
		if i < 0:
			i = mini(_proc, _flow.size())
			_flow.insert(i, target)
		_proc = i
		_step = 0
		_seed_checks()
		_advance_done()
		return
	var st := current_step()
	if st.is_empty() or String(st.check) == "":
		return
	var k := _key(pid, String(st.id))
	var now := bool(st.done)
	var before: Variant = _prev_check.get(k)
	_prev_check[k] = now
	if now and before == false:
		_done[k] = true
		var steps := _steps_of(pid)
		if _step + 1 < steps.size():
			_step += 1
		else:
			_next_process()
		_seed_checks()
		_advance_done()


## Nombre legible de una fuente: las citas conocidas se cambian por su nombre corto y se quitan las rutas y los nombres
## internos (readable_source).
static func short_source(src: String) -> String:
	var s := src
	for pair: Array in _names_by_length():
		s = s.replace(String(pair[0]), String(pair[1]))
	return readable_source(s)


## Una fuente sin rutas ni nombres internos (documentación, código, fichas del motor, unidades de trabajo): solo lo que
## sirve a quien la lee, autor y año, norma o ficha.
static func readable_source(src: String) -> String:
	var s := RegEx.create_from_string(INTERNAL_RE).sub(src, "", true)
	s = RegEx.create_from_string(DANGLING_RE).sub(s, "", true)
	for pass_i in 3:
		for pair: Array in [["( ;", "("], ["(;", "("], ["( ,", "("], ["(,", "("], ["( :", "("], ["(:", "("], [" ;)", ")"],
				[";)", ")"], [" ,)", ")"], [",)", ")"], ["( )", ""], ["()", ""], ["  ", " "], [" ,", ","], [" ;", ";"],
				[" )", ")"], ["( ", "("], [";;", ";"], [",,", ","], [", ;", ";"], ["; ;", ";"], [" :", ":"]]:
			s = s.replace(String(pair[0]), String(pair[1]))
	s = s.strip_edges()
	while s.ends_with(";") or s.ends_with(","):
		s = s.substr(0, s.length() - 1).strip_edges()
	return s


static func _names_by_length() -> Array:
	var out := SOURCE_NAMES.duplicate()
	out.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	return out


## El panel del tutorial: { on, done (acabado), process, process_name, processes: [{ id, name, state }], index, count,
## step: { id, title, text, source, source_short, check, done, status, status_text } | {}, hint, suggest }.
## sn: el snapshot de la garra, si ya está hecho (la vista lo pasa: hacerlo cuesta).
func tutorial_view(sn: Dictionary = {}) -> Dictionary:
	var procs: Array = []
	for i in _flow.size():
		var pid := String(_flow[i])
		procs.append({ "id": pid, "name": String(Tutorial.PROCESS_NAMES.get(pid, pid)),
			"state": "hecho" if i < _proc else ("ahora" if i == _proc else "luego") })
	var steps_now := _steps_of(process_id())
	var out := { "on": tutorial_on, "done": tutorial_done(), "process": process_id(),
		"process_name": String(Tutorial.PROCESS_NAMES.get(process_id(), "")), "processes": procs, "index": _step,
		"count": steps_now.size(), "step": {}, "hint": "", "suggest": "", "control": "", "goal": "", "ui": "",
		"progress": { "step": 0.0, "step_text": "", "process": 0.0, "total": 0.0, "total_text": "" } }
	# el paso de ahora, de los pasos ya hechos (current_step() los volvería a hacer)
	var st: Dictionary = steps_now[_step] if _step >= 0 and _step < steps_now.size() else {}
	if st.is_empty():
		out.progress = { "step": 1.0, "step_text": "", "process": 1.0, "total": 1.0 if tutorial_done() else 0.0, "total_text": "" }
		return out
	var k := _key(process_id(), String(st.id))
	var status := "info"
	if String(st.check) != "":
		status = "hecho" if bool(st.done) else "pendiente"
	var sp := _step_progress(st, sn)
	var line := "Sigue solo en %s s (o «Siguiente» si ya lo sabes)." % Js.to_fixed(ceilf(maxf(read_s(st) - _read_t, 0.0)), 0)
	if status == "hecho":
		line = "Se cumple: %s." % _check_words(String(st.check), String(st.id))
	elif status == "pendiente":
		line = "Lo que pide el paso (aún no): %s." % _check_words(String(st.check), String(st.id))
	var step := st.duplicate()
	step.merge({ "source_short": short_source(String(st.source)), "status": status, "status_text": line,
		"completed": _done.has(k) }, true)
	out["step"] = step
	out["goal"] = String(st.get("goal", st.title))
	out["ui"] = String(STEP_UI.get(String(st.id), ""))
	out["hint"] = String(STEP_HINTS.get(String(st.id), ""))
	out["control"] = String(STEP_CONTROLS.get(String(st.id), ""))
	# el progreso del paso, del proceso y del total (petición 51: «se ve el progreso de ese paso»)
	var total := 0
	var before := 0
	for i in _flow.size():
		var n := _step_count(String(_flow[i])) if i != _proc else steps_now.size()
		total += n
		if i < _proc:
			before += n
	var sf := float(sp.frac)
	out["progress"] = { "step": sf, "step_text": String(sp.text),
		"process": (float(_step) + sf) / float(maxi(steps_now.size(), 1)),
		"total": (float(before + _step) + sf) / float(maxi(total, 1)),
		"total_text": "paso %d de %d" % [before + _step + 1, total] }
	var sug := String(STEP_TOOLS.get(String(st.id), ""))
	if sug == "cortaunas":
		sug = "tenaza" if String(setup.animal) != "rapaz" else "guillotina"
	out["suggest"] = sug
	return out


## La parte hecha del paso de ahora (0-1) y su cuenta en palabras: el tiempo de lectura de un paso informativo, los segundos de la
## hemostasia, lo que falta del largo o de la punta, lo que se ha hecho de lo que pide, la fijación, las capas, la luz…
func _step_progress(st: Dictionary, snap: Dictionary = {}) -> Dictionary:
	var chk := String(st.check)
	if chk == "":
		var rs := read_s(st)
		return { "frac": clampf(_read_t / rs, 0.0, 1.0), "text": "" }
	if bool(st.done):
		return { "frac": 1.0, "text": "hecho" }
	var sn := snap if not snap.is_empty() else care.snapshot()
	match chk:
		"hemostasia":
			var bl: Dictionary = sn.bleeding
			if bool(bl.active):
				var agent := String(bl.agent) != "" or tool in ["hemostatico", "nitrato_plata"]
				var goal := float(CareData.HEMOSTASIS.agent_s.value if agent else CareData.HEMOSTASIS.pressure_s.value)
				var done := goal - float(bl.needS) if String(bl.agent) != "" or not agent else 0.0
				return { "frac": clampf(done / goal, 0.0, 1.0), "text": _of(done, goal) + " de presión" }
		"largo":
			var over := float(sn.claw.startMm) - float(sn.claw.naturalMm)
			var left := float(sn.claw.overgrowthLeftMm)
			if over > 0.0:
				return { "frac": clampf(1.0 - left / over, 0.0, 1.0), "text": "faltan %s mm" % Js.to_fixed(maxf(left, 0.0), 1) }
		"punta":
			var ratio := float(sn.tip.ratio)
			var hi := float(CareData.MARGINS.tip_ratio_hi)
			return { "frac": clampf(hi / maxf(ratio, 1e-6), 0.0, 1.0), "text": "punta ×%s (buena hasta ×%s)" % [Js.to_fixed(ratio, 1), Js.to_fixed(hi, 1)] }
		"accion":
			var act: Array = STEP_ACTION.get(String(st.id), ["", 1])
			var n := _act_count(String(act[0]))
			return { "frac": clampf(float(n) / float(act[1]), 0.0, 1.0), "text": "%d de %d" % [mini(n, int(act[1])), int(act[1])] }
	var b := bond()
	if b != null:
		var now := care.time_s()
		match chk:
			"fijada":
				if not b.placed.is_empty():
					var fix := float(Bond.adhesive_times(b.adhesive).fix_s)
					var held := now - float(b.placed.t)
					return { "frac": clampf(held / fix, 0.0, 1.0), "text": _of(held, fix) }
			"construida":
				return { "frac": clampf(b.built_mm / maxf(float(b.piece.needMm), 1e-6), 0.0, 1.0), "text": "%s de %s mm" % [Js.to_fixed(b.built_mm, 1), Js.to_fixed(float(b.piece.needMm), 1)] }
			"seca":
				if b.cleaner == "alcohol":
					var dry := float(CareData.BOND_PREP.alcohol_dry_s)
					return { "frac": clampf((now - b.clean_t) / dry, 0.0, 1.0), "text": _of(now - b.clean_t, dry) }
			"lijada":
				var want := Bond.SANDED_RA * float(CareData.SURFACE.natural_ra_um.value)
				return { "frac": clampf(b.ra_um / want, 0.0, 1.0), "text": "Ra %s de %s µm" % [Js.to_fixed(b.ra_um, 2), Js.to_fixed(want, 2)] }
	return { "frac": 0.0, "text": "" }


## Qué comprueba cada condición, en palabras (sid: el paso, para las de «accion»).
static func _check_words(check: String, sid: String = "") -> String:
	if check == "accion":
		return String({
			"poco": "has cortado un trozo sin hacerla sangrar", "cara": "has limado la cara del corte sin dejar grieta",
			"curva": "la faceta sigue la curva de la garra (±10°)", "toques": "has dado dos toques cortos sin calentar la carne viva",
			"velocidades": "has usado la amoladora sin calentar la carne viva", "flanco": "has trabajado la punta sin llegar a la carne viva",
			"probar": "has probado la punta en una uña (T)",
		}.get(sid, "lo que pide el paso"))
	return String({
		"mano_hemostatico": "tienes en la mano el polvo hemostático (o el nitrato de plata)",
		"mano_tenaza": "tienes en la mano las tenazas", "mano_guillotina": "tienes en la mano el cortaúñas de guillotina",
		"mano_desbastar": "tienes en la mano una herramienta de desbastar (la lima gruesa, la de diamante gruesa, el torno o la amoladora)",
		"mano_afinar": "tienes en la mano una de afinar (la lima fina, la de diamante fina o la lija)",
		"sujecion": "el animal está sujeto o anestesiado como toca",
		"remojada": "la garra está remojada",
		"sin_sangre": "no ha sangrado",
		"sin_grieta": "no queda ninguna grieta",
		"a_favor": "todas las pasadas, de la base a la punta",
		"curva": "la faceta sigue el ángulo de la garra (±10°)",
		"largo": "el sobrante está quitado",
		"punta": "la punta, ni aguja ni roma",
		"sin_calor": "la carne viva no ha pasado del umbral del dolor",
		"hemostasia": "no sangra",
		"desinfectada": "la herida está desinfectada",
		"crema": "la crema está puesta",
		"reconstruida": "la garra rota está reconstruida",
		"lima_adecuada": "se ha usado una lima que muerde este material",
		# colocar la pieza de la reforja (unidad 5o)
		"limpia": "la garra está limpia y desengrasada",
		"seca": "la garra está seca",
		"lijada": "la queratina está lijada donde va a pegar",
		"purgada": "la cánula está purgada",
		"aplicado": "el adhesivo está puesto",
		"colocada": "la pieza está colocada y alineada",
		"fijada": "ha fijado sin moverse",
		"sin_venda": "la venda está quitada",
		"mezclado": "el acrílico está mezclado",
		"en_masa": "la mezcla está en la fase de masa",
		"construida": "las capas llegan al largo de la garra",
		"fraguada": "todo ha fraguado",
		"curada": "todas las capas están curadas",
		"ojos": "los ojos están tapados y el filtro puesto",
		"sin_rebaba": "no queda nada de lo que rebosa",
		"sin_escalon": "no se nota el escalón de la unión",
		"probada": "la unión aguanta el tirón",
	}.get(check, check))


# ════════════════════════════════ El estado del animal (petición 51) ════════════════════════════════
## Eric: «un medidor de estrés o peligro del animal, que tiene que estar correctamente encapuchado, sedado o anestesiado según el
## caso […] si sangra demasiado, puede perder la vida o infectarse la herida. No quiero algo hardcore, solo algo que sea
## educativo». La barra de arriba de la vista lee el estrés del animal (claw_care_patient.gd), la sangre que ha perdido (todo el
## tiempo que han sangrado sus garras: CareData.BLOOD) y el calor de la carne viva; los límites, en CareData.ANIMAL_RISK y BLOOD.

## La masa del animal (kg): la de su ficha (care_anatomy.gd), por la garra del ensayo.
func animal_mass_kg() -> float:
	var e: Dictionary = CareAnatomy.of(String(setup.claw))
	var m: Variant = e.get("mass_kg")
	if m is Dictionary and (m as Dictionary).get("value") != null:
		return float((m as Dictionary).value)
	if m is float or m is int:
		return float(m)
	return float(CareData.claw_entry(String(setup.claw)).get("mass", 5.0))


## La sangre del animal: { volumeMl (la masa por la fracción de su especie; 1 g ≈ 1 mL, como en LafeberVet), lostMl (todo el
## tiempo que han sangrado sus garras por lo que sale de una garra cortada), frac (lo perdido frente al volumen), safeFrac,
## dangerFrac, stopFrac, massKg, quality, source }.
func blood_state() -> Dictionary:
	var B: Dictionary = CareData.BLOOD
	var vf: Dictionary = (B.volume_frac as Dictionary).get(String(setup.animal), B.volume_frac.rapaz)
	var mass := animal_mass_kg()
	var vol := mass * 1000.0 * float(vf.value)
	var secs := _blood_carry_s + care.bleed_total_s()
	for key: String in _slots:
		secs += (_slots[key].care as ClawCare).bleed_total_s()
	var lost := secs * float(B.bleed_ml_s)
	return { "volumeMl": vol, "lostMl": lost, "frac": lost / vol if vol > 0.0 else 0.0, "safeFrac": float(B.safe_frac),
		"dangerFrac": float(B.danger_frac), "stopFrac": float(B.stop_frac), "massKg": mass, "bleedingS": secs,
		"quality": String(vf.quality), "source": String(vf.source) }


## Las palabras del estrés: calma, inquieto, estresado o peligro (CareData.ANIMAL_RISK).
static func stress_word(x: float) -> String:
	var R: Dictionary = CareData.ANIMAL_RISK
	if x >= float(R.danger):
		return "peligro"
	if x >= float(R.stressed):
		return "estresado"
	if x >= float(R.restless):
		return "inquieto"
	return "calma"


## Qué hacer para calmarlo, según el animal y cómo está sujeto.
func _calm_todo() -> String:
	var aid := String(setup.animal)
	if aid == "rapaz":
		if not patient.restrained():
			return "Encapúchala y envuélvela en la toalla («Capucha y toalla» en «Preparar al animal»): a oscuras se calma."
		return "Encapuchada y envuelta, el estrés sube despacio con el tiempo que pasa sujeta. Si se estresa, «Pausa para calmarlo»: sin tocarla, a oscuras se calma; para lo largo (una cola de horas), la venda y a su percha, o anestesia."
	var nm := String(CareData.ANIMALS[aid].name).to_lower()
	if not patient.restrained():
		return "A un %s solo se le tocan las garras sedado a fondo o anestesiado: «Sedación» o «Anestesia» en «Preparar al animal»." % nm
	if patient.sedation == "sedacion":
		return "Sedado, un dolor fuerte aún le hace moverse: no cortes cerca de la carne viva ni calientes con el torno, o anestésialo."
	return "Anestesiado: no siente ni se mueve. Vigila la sangre y el calor."


## La barra del estado del animal, de lado a lado sobre la vista («como una barra de vida»): [{ id, label, value (0-1 de la
## barra), limit (la marca de lo permitido, 0-1), text, tone («bien» | «aviso» | «mal» | «»), tip (por qué y qué hacer) }].
func animal_view(sn: Dictionary = {}) -> Array:
	var s := sn if not sn.is_empty() else care.snapshot()
	var R: Dictionary = CareData.ANIMAL_RISK
	var aid := String(setup.animal)
	# la vista la pide en cada fotograma: solo se rehace si cambia algo de lo que enseña
	var bl0 := blood_state()
	var th0: Dictionary = s.thermal
	var mk := [aid, patient.stress, patient.sedation, patient.moved, patient.restrained(), _unsafe_touches, float(bl0.lostMl),
		bool(s.bleeding.active), float(th0.quickC), float(th0.peakQuickC), float(th0.painC), float(th0.get("faceC", 0.0)), is_reforged(), s.claw.get("block") != null]
	if mk == _animal_key:
		return _animal_cache
	var out: Array = []
	var src := _risk_sources(aid)
	var big := aid != "rapaz"
	# el estrés (y lo que se ha movido)
	var x := patient.stress
	var tone := "bien" if x < float(R.restless) else ("aviso" if x < float(R.stressed) else "mal")
	var word := stress_word(x)
	if big and not patient.restrained():
		word = "despierto: peligro" if _unsafe_touches > 0 else "sin sedar"
		tone = "mal" if _unsafe_touches > 0 else "aviso"
	elif aid == "rapaz" and not patient.restrained():
		word = "%s · sin sujetar" % word
		tone = "aviso" if tone == "bien" else tone
	var moved := ""
	if patient.moved > 0:
		moved = " Se ha movido %d de %d veces por el dolor (a la %d.ª, se suelta)." % [patient.moved, int(R.move_stop), int(R.move_stop)]
	# el texto corto, el del teléfono (caben unos 15 caracteres por medida): la rapaz sin sujetar, «suelta»
	var short_word := word
	if aid == "rapaz" and not patient.restrained():
		short_word = "suelta"
	elif big and not patient.restrained():
		short_word = "peligro" if _unsafe_touches > 0 else "sin sedar"
	out.append({ "id": "estres", "label": "Estrés", "value": x, "limit": float(R.stressed), "text": "%s %% · %s" % [Js.to_fixed(x * 100.0, 0), word],
		"short": "%s %% · %s" % [Js.to_fixed(x * 100.0, 0), short_word],
		"tone": tone, "source": src.estres[0], "quality_text": src.estres[1], "tip": "Estrés del animal (índice pedagógico, %s): %s.%s %s" % [String(CareData.SEDATION[patient.sedation].name).to_lower(), word, moved, _calm_todo()] })
	# la sangre perdida
	var bl := bl0
	var f := float(bl.frac)
	var stop := float(bl.stopFrac)
	var btone := "bien" if f < float(bl.safeFrac) else ("aviso" if f < float(bl.dangerFrac) else "mal")
	var bleeding := bool(s.bleeding.active)
	var btext := "%s de %s mL" % [Js.to_fixed(float(bl.lostMl), 1), Js.to_fixed(float(bl.volumeMl), 0)]
	var bshort := "%s mL" % Js.to_fixed(float(bl.lostMl), 1)
	if bleeding:
		btext += " · sangra"
		bshort += " · sangra"
		if btone == "bien":
			btone = "aviso"
	out.append({ "id": "sangre", "label": "Sangre", "value": clampf(f / stop, 0.0, 1.0), "limit": float(bl.safeFrac) / stop, "text": btext, "short": bshort,
		"tone": btone, "source": src.sangre[0], "quality_text": src.sangre[1], "tip": "Un %s de %s kg tiene unos %s mL de sangre; sin peligro puede perder ~%s mL (el %s %%); al %s %% la sesión se para. Ha perdido %s mL (%s %%). %s" % [
			String(CareData.ANIMALS[aid].name).to_lower(), Js.to_fixed(float(bl.massKg), 1), Js.to_fixed(float(bl.volumeMl), 0),
			Js.to_fixed(float(bl.volumeMl) * float(bl.safeFrac), 0), Js.to_fixed(float(bl.safeFrac) * 100.0, 0), Js.to_fixed(stop * 100.0, 0),
			Js.to_fixed(float(bl.lostMl), 1), Js.to_fixed(f * 100.0, 1),
			"Para la sangre ya: polvo hemostático y presión sobre la herida." if bleeding else "No sangra."] })
	# el calor de la carne viva (sin ella, la garra reforjada entera: nada que calentar)
	if is_reforged() and not bool(s.claw.get("block") != null):
		out.append({ "id": "calor", "label": "Calor", "value": 0.0, "limit": 0.5, "text": "sin carne viva", "short": "sin carne", "tone": "",
			"tip": "Una garra reforjada entera es una pieza de su material: no tiene carne viva que calentar." })
	else:
		var th: Dictionary = s.thermal
		var bed: float = CareData.THERMAL.bed_c.value
		var pain := float(th.painC)
		var top := pain + 12.0
		var q := float(th.quickC)
		var ctone := "bien" if q < pain - 2.0 else ("aviso" if q < pain else "mal")
		# la cara que se ha trabajado aún está más caliente que la carne viva: el calor sigue llegando por la queratina
		# (va con retraso, la difusión del modelo térmico de ClawCare), aunque la herramienta ya esté parada
		var face := float(th.get("faceC", q))
		var arriving := face > q + 1.0
		var lag := (" · sigue llegando el calor de la punta (%s °C): sube un rato aunque pares, porque tarda en atravesar la queratina." % Js.to_fixed(face, 0)) if arriving else ""
		out.append({ "id": "calor", "label": "Calor", "value": clampf((q - bed) / (top - bed), 0.0, 1.0), "limit": (pain - bed) / (top - bed),
			"text": "%s °C%s" % [Js.to_fixed(q, 1), " ↑" if arriving else ""], "short": "%s °C%s" % [Js.to_fixed(q, 1), " ↑" if arriving else ""],
			"tone": ctone, "source": src.calor[0], "quality_text": src.calor[1],
			"tip": "La carne viva está a %s °C; duele desde ~%s °C (pico de este ensayo: %s °C)%s El roce del torno o de la amoladora calienta: toques de unos segundos, con pausas." % [
				Js.to_fixed(q, 1), Js.to_fixed(pain, 0), Js.to_fixed(float(th.peakQuickC), 1), lag if arriving else "."] })
	_animal_key = mk
	_animal_cache = out
	return out


## El animal para la escena y la barra (unidad 5t-A): la vista del paciente (ClawCarePatient.view: estrés, sujeción,
## dolor… y reaction, el contrato con la 5t-B: { seq, warning, kind, intensity, lens }) con la barra (meters: animal_view).
func animal_dict(sn: Dictionary = {}) -> Dictionary:
	var out := patient.view()
	out["meters"] = animal_view(sn)
	return out


## Las fuentes de los límites de la barra del animal, legibles y con su calidad (hechas una vez por animal: la vista las pide en
## cada fotograma): { estres, sangre, calor } → [fuente, calidad].
func _risk_sources(aid: String) -> Dictionary:
	if _risk_src.has(aid):
		return _risk_src[aid]
	var R: Dictionary = CareData.ANIMAL_RISK
	var B: Dictionary = CareData.BLOOD
	var vol: Dictionary = (B.volume_frac as Dictionary).get(aid, {}) if B.has("volume_frac") else {}
	var P: Dictionary = CareData.THERMAL.pain_c
	var blood_src := "%s; %s%s" % [String(B.safe_source), String(B.stop_source), ("; " + String(vol.source)) if vol.has("source") else ""]
	var out := {
		"estres": [short_source(String(R.source)), String(QUALITY_TEXT.get(String(R.quality), ""))],
		"sangre": [short_source(blood_src), String(QUALITY_TEXT.get(String(B.stop_quality), ""))],
		"calor": [short_source(String(P.source)), String(QUALITY_TEXT.get(String(P.quality), ""))],
	}
	_risk_src[aid] = out
	return out


## Avisa una sola vez (el aviso se queda en la página hasta el siguiente).
func _warn(code: String, text: String) -> void:
	if _warned.has(code):
		return
	_warned[code] = true
	_notice = text
	_push_fx({ "kind": "warn", "code": code })


## Para la sesión: el animal se suelta, ataca o ha perdido demasiada sangre. Se enseña el informe con la explicación y se empieza
## de nuevo (R).
func _halt(code: String, title: String, text: String, todo: String, source: String) -> void:
	if not halted.is_empty():
		return
	halted = { "code": code, "title": title, "text": text, "todo": todo, "source": short_source(source) }
	_notice = "%s %s" % [title, todo]
	_push_fx({ "kind": "halt", "code": code })
	finish()


## Después de cada cambio: los avisos del animal y, si se pasa de los límites, la sesión se para (CareData.ANIMAL_RISK, BLOOD).
func _check_animal() -> void:
	if not halted.is_empty() or finished:
		return
	var R: Dictionary = CareData.ANIMAL_RISK
	var aid := String(setup.animal)
	var nm := String(CareData.ANIMALS[aid].name).to_lower()
	var src := String(R.source)
	# un animal grande sin sedar: el primer toque avisa, el segundo ataca
	if aid != "rapaz" and not patient.restrained() and _unsafe_touches >= int(R.big_touch_stop):
		_halt("ataca", "Sesión parada: el %s se ha revuelto y ha intentado atacar." % nm,
			"No estaba sedado ni anestesiado y se le han vuelto a tocar las garras después del aviso. Un %s despierto no se deja: en un zoológico, para recortarle las garras se le duerme." % nm,
			"Empieza de nuevo (R) y elige «Anestesia» (o «Sedación» a fondo) en «Preparar al animal» antes de tocarlo.", src)
		return
	if aid != "rapaz" and not patient.restrained() and _unsafe_touches >= 1:
		_warn("despierto", "¡Cuidado! El %s no está sedado: se ha despertado al tocarle la garra. Sédalo a fondo o anestésialo ya; si se le vuelven a tocar las garras así, atacará." % nm)
	# se mueve de dolor demasiadas veces
	if patient.moved >= int(R.move_stop):
		_halt("dolor", "Sesión parada: el animal se ha soltado por el dolor.",
			"Se ha movido %d veces por el dolor (el corte cerca de la carne viva, el calor del torno o la presión): a la %d.ª se suelta. Con dolor, cualquier animal se defiende." % [patient.moved, int(R.move_stop)],
			"Empieza de nuevo (R): corta poco a poco lejos de la carne viva, toques cortos con el torno y, si hace falta, más sedación o anestesia.", src + "; " + String(CareData.SEDATION[patient.sedation].source))
		return
	if patient.moved == int(R.move_stop) - 1:
		_warn("casi_suelta", "Se ha movido %d veces por el dolor: a la siguiente, se soltará. Para lo que le duele (la carne viva, el calor) o sédalo más." % patient.moved)
	# una rapaz sin sujetar que llega al estrés máximo
	if aid == "rapaz" and not patient.restrained() and patient.handled:
		if patient.stress >= 1.0 - 1e-9:
			_halt("se_suelta", "Sesión parada: la rapaz se ha soltado.",
				"Sin capucha ni toalla, se ha estresado al máximo mientras se le tocaban las garras y se ha soltado: una rapaz sin sujetar puede clavar las garras al que la maneja.",
				"Recógela con la toalla y encapúchala («Recogerla y encapucharla») para seguir con esta garra, o empieza de nuevo (R) con «Capucha y toalla» elegida antes de tocarla.", src)
			halted["recoverable"] = true
			return
		if patient.stress >= float(R.stressed):
			_warn("rapaz_suelta", "¡La rapaz está muy estresada! Sin capucha ni toalla puede soltarse y clavarte las garras: encapúchala y envuélvela ya.")
	# el estrés, con la sujeción que pide su especie: solo avisa (en la pausa para calmarlo, no: ya está bajando)
	if patient.restrained() and not patient.resting:
		if patient.stress >= float(R.danger):
			_warn("estres_peligro", "Estrés del animal al %s %%: lleva demasiado tiempo sujeto. Termina cuanto antes; para lo largo, la venda y a su percha, o anestesia." % Js.to_fixed(patient.stress * 100.0, 0))
		elif patient.stress >= float(R.stressed):
			_warn("estres_alto", "El animal se está estresando (%s %%): haz una «Pausa para calmarlo» o termina pronto." % Js.to_fixed(patient.stress * 100.0, 0))
	# la sangre
	var bl := blood_state()
	var f := float(bl.frac)
	if f >= float(bl.stopFrac):
		_halt("sangre", "Sesión parada: el animal ha perdido demasiada sangre.",
			"Ha perdido %s mL, el %s %% de su sangre (~%s mL). Con el 40 %% el daño ya es irreversible; por eso la sesión se para antes. Una hemorragia se para enseguida: polvo hemostático y presión." % [Js.to_fixed(float(bl.lostMl), 0), Js.to_fixed(f * 100.0, 0), Js.to_fixed(float(bl.volumeMl), 0)],
			"Empieza de nuevo (R). Si sangra: coge el polvo hemostático y aprieta sobre la herida hasta que pare.", String(CareData.BLOOD.stop_source))
		return
	if f >= float(bl.dangerFrac):
		_warn("sangre_peligro", "¡Peligro! Ha perdido el %s %% de su sangre (%s mL): para la hemorragia ya, polvo hemostático y presión." % [Js.to_fixed(f * 100.0, 0), Js.to_fixed(float(bl.lostMl), 0)])
	elif f >= float(bl.safeFrac):
		_warn("sangre_aviso", "Ha perdido el %s %% de su sangre (%s de ~%s mL): más de lo que se puede perder sin peligro. Para la hemorragia." % [Js.to_fixed(f * 100.0, 0), Js.to_fixed(float(bl.lostMl), 0), Js.to_fixed(float(bl.volumeMl), 0)])


# ════════════════════════════════ La reacción y la lente (unidad 5t-A) ════════════════════════════════
## Eric (12 y 13-10-2026): si el animal se estresa mucho, se revuelve y lanza la pata hacia la cámara, y araña la lente. El
## paciente decide cuándo (claw_care_patient.gd: el umbral, la amenaza un poco antes y como mucho uno cada 20 s, solo con
## una sujeción que no basta para su especie); aquí se calcula lo que le hace a la lente puesta, garra a garra
## (ClawCareReaction.lens_hit, con el material y la punta de ahora de cada garra de la pata que se trabaja), y la escena lo
## dibuja y apunta los trazos (lens_record).

## Después de cada cambio: la amenaza lo avisa (una vez por amenaza; si el estado del animal acaba de avisar, fresh, se
## queda su aviso, que es más concreto) y un zarpazo nuevo trae su lente.
func _sync_reaction(fresh: bool = false) -> void:
	if patient.reaction_warning and not _warning_said:
		_warning_said = true
		if not fresh:
			_notice = "¡Se está estresando! Está a punto de revolverse: para y cálmalo (capucha, penumbra, una pausa) o revisa la sedación."
	elif not patient.reaction_warning:
		_warning_said = false
	if not patient.lens_pending or patient.reaction_seq == _lens_seq:
		return
	_lens_seq = patient.reaction_seq
	patient.lens_pending = false
	var hit := lens_hit_now()
	hit["seq"] = patient.reaction_seq
	patient.reaction_lens = hit
	patient.serial += 1
	_push_fx({ "kind": "reaction", "seq": patient.reaction_seq, "outcome": String(hit.outcome) })
	_notice = "El animal está demasiado estresado y se ha revuelto: %s Para, cálmalo (capucha, penumbra, una pausa) o revisa la sedación." % String(hit.reason)
	# el primer ataque: el tutorial enseña a calmarlo, curar y subir la sedación (y después vuelve a donde estaba)
	if patient.reaction_seq == 1:
		_insert_attack_process()


## Lo que le haría a la lente lens_id (la puesta, si no se dice) un zarpazo de la pata que se trabaja ahora, con la
## intensidad de la última reacción (o la de ahora): ClawCareReaction.lens_hit con cada garra de esa pata, su material y su
## punta de ahora (las que no se han trabajado, la natural y el material del animal).
func lens_hit_now(lens_id: String = "") -> Dictionary:
	var aid := String(setup.animal)
	var kind := Reaction.kind_of(aid, String(setup.claw))
	var fingers: Array = []
	for fid: String in Reaction.FINGERS[kind]:
		var c := _care_of(paw, fid)
		if c != null:
			fingers.append({ "finger": fid, "inlay": c.tip_material_id(), "tip_um": c.tip_radius_um() })
	# la de la última reacción; sin ninguna (la tienda, una prueba), la de un animal suelto en el umbral
	var inten := patient.reaction_intensity
	if inten <= 0.0:
		inten = Reaction.intensity_of(1.0, maxf(patient.stress, float(Reaction.REACTION.threshold)))
	var hit := Reaction.lens_hit(lens_id if lens_id != "" else lens.lens_id, {
		"animal": aid, "claw": String(setup.claw), "inlay": String(setup.get("inlay", "none")), "intensity": inten, "fingers": fingers,
	})
	hit["paw"] = paw
	return hit


## Lo peligroso que es para cada lente un zarpazo con toda su fuerza de la pata que se trabaja, con cada garra con su
## material y el radio de su punta de ahora (ClawCareReaction.danger_of con sus garras; petición de Eric del 18-10: «cuanto
## más afilada esté una garra, más peligrosa puede ser para la lente»). Se recalcula solo cuando cambian el animal, la
## garra, el material o alguna punta (al micrómetro).
func danger_now() -> Dictionary:
	var aid := String(setup.animal)
	var kind := Reaction.kind_of(aid, String(setup.claw))
	var fingers: Array = []
	var key := "%s|%s|%s|%s" % [aid, String(setup.claw), String(setup.get("inlay", "none")), paw]
	for fid: String in Reaction.FINGERS[kind]:
		var c := _care_of(paw, fid)
		if c != null:
			var mat := c.tip_material_id()
			var tip := c.tip_radius_um()
			fingers.append({ "finger": fid, "inlay": mat, "tip_um": tip })
			# la punta, en pasos de ~5 % (no se recalcula en cada pasada de lima)
			key += "|%s:%s:%d" % [fid, mat, roundi(V8.js_log(maxf(tip, 0.01)) * 20.0)]
	if key != _danger_key:
		_danger_key = key
		_danger_now = Reaction.danger_of(aid, String(setup.claw), String(setup.get("inlay", "none")), fingers)
	return _danger_now


## La ClawCare de la garra paw|digit si ya existe (la elegida o una trabajada), o null.
func _care_of(p: String, d: String) -> ClawCare:
	if p == paw and d == digit:
		return care
	var key := "%s|%s" % [p, d]
	if _slots.has(key):
		return _slots[key].care as ClawCare
	return null


## La escena apunta los rayones del zarpazo seq en la lente, con el trazo de cada garra en coordenadas normalizadas de la
## pantalla ({ dedo: [Vector2 | [x, y], …] }; claw_care_lens.gd). Solo el de la última reacción. Devuelve los ids nuevos.
func lens_record(seq: int, traces: Dictionary) -> Array:
	if seq != patient.reaction_seq or patient.reaction_lens.is_empty():
		return []
	var ids := lens.record(patient.reaction_lens, traces)
	_touch()
	return ids


## El paño: quita las manchas de la lente (los rayones se quedan). Cuántas ha quitado.
func lens_clean() -> int:
	var n := lens.clean()
	_notice = ("Lente limpia: %d %s fuera. Los rayones se quedan: una lente rayada se cambia en la tienda." % [n, "mancha" if n == 1 else "manchas"]) if n > 0 else "No hay manchas que limpiar; los rayones no se van con el paño."
	_touch()
	return n


## Pone una lente nueva de ese tipo (ClawCareReaction.LENS_IDS), sin rayones.
func lens_mount(id: String) -> void:
	lens = Lens.new(id)
	_touch()


## Pone una lente guardada (Lens.to_dict(); la 5u guarda las compradas). false si no se entiende (queda una de plástico nueva).
func lens_load(d: Variant) -> bool:
	var l := Lens.new()
	var ok := l.from_dict(d)
	lens = l
	_touch()
	return ok


# ════════════════════════════════ Qué estás haciendo (petición 51) ════════════════════════════════
## Eric: «no sabes muy bien qué estás haciendo y cuánto tiempo y segundos tienes que hacer tal cosa». Una línea con lo que se
## está haciendo, cuánto lleva, cuánto hace falta y cuánto tardaría en la vida real con el reloj acelerado, con la parte hecha
## (frac: 0-1, −1 sin barra) que llega a 1 justo al acabar, y lo que hay que mantener pulsado.

## «12 de 30 s»: con unidades de tiempo legibles (Bond.dur) y el mismo formato para lo hecho y lo que hace falta.
static func _of(done: float, goal: float) -> String:
	if goal < 90.0:
		return "%s de %s s" % [Js.to_fixed(floorf(minf(done, goal)), 0), Js.to_fixed(goal, 0)]
	return "%s de %s" % [Bond.dur(minf(done, goal)), Bond.dur(goal)]


## Lo que se está haciendo ahora: { id, text, frac, hold (hay que mantener pulsado), ready (listo: se puede soltar), real (en la
## vida real…), tone }.
func activity_view(sn: Dictionary = {}) -> Dictionary:
	var s := sn if not sn.is_empty() else care.snapshot()
	var out := { "id": "", "text": "", "frac": -1.0, "hold": false, "ready": false, "real": "", "tone": "" }
	if not halted.is_empty():
		return out.merged({ "id": "parada", "text": String(halted.title), "tone": "mal" }, true)
	if finished:
		return out.merged({ "id": "terminado", "text": "Terminado: mira el informe (y dónde estaba la carne viva)." }, true)
	if paused:
		return out.merged({ "id": "pausa", "text": "En pausa: Espacio para seguir." }, true)
	var bl: Dictionary = s.bleeding
	var g := String(_gesture.get("kind", ""))
	match g:
		"presion":
			var agent := tool in ["hemostatico", "nitrato_plata"]
			if bool(bl.active):
				var goal := float(CareData.HEMOSTASIS.agent_s.value if agent else CareData.HEMOSTASIS.pressure_s.value)
				var done := goal - float(bl.needS) if (String(bl.agent) != "" or not agent) else 0.0
				var what := "el polvo hemostático" if tool == "hemostatico" else ("el nitrato de plata" if tool == "nitrato_plata" else "la gasa")
				return out.merged({ "id": "hemostasia", "text": "Apretando %s sobre la herida: %s. Mantén pulsado." % [what, _of(done, goal)],
					"frac": clampf(done / goal, 0.0, 1.0), "hold": true, "real": _real_if_fast(goal - done), "tone": "aviso" }, true)
			var b := bond()
			if b != null and b.wet and tool == "presion":
				var need := float(CareData.BOND_PREP.gauze_dry_s)
				return out.merged({ "id": "secar", "text": "Secando con la gasa: %s. Mantén pulsado." % _of(_gauze_s, need), "frac": clampf(_gauze_s / need, 0.0, 1.0), "hold": true }, true)
			if bool(bl.bled):
				return out.merged({ "id": "hemostasia", "text": "Listo: ha dejado de sangrar. Ya puedes soltar.", "frac": 1.0, "ready": true, "tone": "bien" }, true)
			return out.merged({ "id": "presion", "text": "Apretando sobre la garra: no sangra, no hace falta." }, true)
		"corte":
			var c := float(_gesture.get("closing", 0.0))
			return out.merged({ "id": "corte", "text": "Cerrando el cortaúñas: mantén pulsado hasta que corte (%s de %s s)." % [Js.to_fixed(minf(c, CLIP_CLOSE_S), 2), Js.to_fixed(CLIP_CLOSE_S, 2)],
				"frac": clampf(c / CLIP_CLOSE_S, 0.0, 1.0), "hold": true }, true)
		"torno":
			var nm := "la amoladora" if tool == "amoladora" else "el torno"
			if not rotary_on:
				return out.merged({ "id": "torno", "text": "%s está apagad%s: enciéndel%s (E o un clic en el aire)." % [cap(nm), "a" if tool == "amoladora" else "o", "a" if tool == "amoladora" else "o"], "tone": "aviso" }, true)
			var t := float(_gesture.get("touch_t", 0.0))
			var lim := float(CareData.ROTARY_TOUCH.value)
			if t >= lim:
				return out.merged({ "id": "toque", "text": "Suelta ya: llevas %s s seguidos con %s y el roce calienta. Deja que se enfríe y vuelve a tocar." % [Js.to_fixed(t, 0), nm],
					"frac": 1.0, "tone": "mal" }, true)
			return out.merged({ "id": "toque", "text": "%s tocando la garra: %s s de ~%s s por toque; luego suelta y deja que se enfríe." % [cap(nm), Js.to_fixed(t, 1), Js.to_fixed(lim, 0)],
				"frac": clampf(t / lim, 0.0, 1.0), "hold": true }, true)
		"lima":
			var mm := float(_gesture.get("total_mm", 0.0)) + float(_gesture.get("acc_mm", 0.0))
			return out.merged({ "id": "pasada", "text": "Limando con %s: pasada de %s mm. Arrastra de la base a la punta y suelta al acabar." % [_tool_short(tool), Js.to_fixed(mm, 0)] }, true)
	if not _early.is_empty():
		return out.merged({ "id": "pronto", "text": String(_early.text), "tone": "mal" }, true)
	# la pieza de la reforja (unidad 5o): lo que lleva tiempo
	var bw := _bond_activity()
	if not bw.is_empty():
		return out.merged(bw, true)
	# si sangra y no se aprieta
	if bool(bl.active):
		return out.merged({ "id": "sangra", "text": "¡Sangra! Coge el polvo hemostático y aprieta sobre la herida: unos %s s sin soltar." % Js.to_fixed(float(CareData.HEMOSTASIS.agent_s.value), 0), "tone": "mal" }, true)
	# la última pasada, en una línea
	if not _passes.is_empty():
		return out.merged({ "id": "resumen", "text": pass_summary(_passes[0]) }, true)
	return out


## Lo que lleva tiempo en la colocación de la pieza: sujetarla hasta que fije, la venda, la masa y el fraguado del acrílico, la
## lámpara y lo que cura. {} si no hay nada en marcha.
func _bond_activity() -> Dictionary:
	var b := bond()
	if b == null:
		return {}
	var now := care.time_s()
	var tm := Bond.adhesive_times(b.adhesive)
	if b.method == "adhesivo" and not b.placed.is_empty() and b.failure.is_empty():
		var held := now - float(b.placed.t)
		var fix := float(tm.fix_s)
		if b.fixed_t < 0.0:
			if b.wrapped:
				return { "id": "venda", "text": "La venda la sujeta mientras fija: %s." % _of(held, fix), "frac": clampf(held / fix, 0.0, 1.0), "real": _real_if_fast(fix - held) }
			return { "id": "sujetar", "text": "Sujetando la pieza: %s hasta que fije. Mantén pulsado sin moverla." % _of(held, fix), "frac": clampf(held / fix, 0.0, 1.0),
				"hold": true, "real": _real_if_fast(fix - held), "tone": "aviso" }
		if b.holding:
			return { "id": "sujetar", "text": "Listo: ha fijado. Ya puedes soltar.", "frac": 1.0, "ready": true, "tone": "bien" }
		if b.wrapped:
			return { "id": "venda", "text": "Ha fijado: quita la venda.", "frac": 1.0, "ready": true, "tone": "bien" }
	if b.method == "adhesivo" and b.applied_t >= 0.0 and b.placed.is_empty() and b.failure.is_empty():
		var work := float(tm.work_s)
		var used := now - b.applied_t
		return { "id": "trabajo", "text": "El adhesivo está puesto: quedan %s para colocar la pieza." % Bond.dur(maxf(work - used, 0.0)), "frac": clampf(used / work, 0.0, 1.0), "tone": "aviso" }
	if b.method == "acrilico":
		var ph := b.mix_phase(now)
		var m: Dictionary = CareData.ACRYLIC_MIX
		if ph == "liquida":
			var t := now - float(b.mix.t)
			return { "id": "masa", "text": "Esperando a la masa: %s (aún chorrea)." % _of(t, float(m.dough_s)), "frac": clampf(t / float(m.dough_s), 0.0, 1.0), "real": _real_if_fast(float(m.dough_s) - t) }
		if ph == "masa":
			var t2 := now - float(b.mix.t)
			return { "id": "en_masa", "text": "En masa: aplica la capa con la espátula (quedan %s para que deje de pegar)." % Bond.dur(maxf(float(m.work_s) - t2, 0.0)), "frac": 1.0, "ready": true, "tone": "bien" }
		if not b.layers.is_empty() and not b.set_all(now):
			var last: Dictionary = b.layers.back()
			var t3 := now - float(last.t_mix)
			return { "id": "fraguar", "text": "Fraguando: %s. No se lima en fresco." % _of(t3, float(m.set_s)), "frac": clampf(t3 / float(m.set_s), 0.0, 1.0), "real": _real_if_fast(float(m.set_s) - t3) }
	if b.method == "resina" and b.lamp_on:
		var lt := now - b.lamp_t
		return { "id": "lampara", "text": "Curando la resina con la lámpara: %s." % _of(lt, b.lamp_s), "frac": clampf(lt / b.lamp_s, 0.0, 1.0), "real": _real_if_fast(b.lamp_s - lt) }
	return {}


## «En la vida real, 3 h; con el reloj a ×3600, 3 s» si el reloj va acelerado (y queda algo); «» si no.
func _real_if_fast(left: float) -> String:
	if time_scale <= 1.0 or left <= 0.0:
		return ""
	return "En la vida real faltarían %s; con el reloj a ×%s, %s." % [Bond.dur(left), Js.to_fixed(time_scale, 0), Bond.dur(left / time_scale)]


## El nombre corto de una herramienta, con su artículo («la lima gruesa», «el torno»).
const TOOL_NAMES := {
	"torno": "el torno", "amoladora": "la amoladora", "guillotina": "el cortaúñas de guillotina", "tijera": "el cortaúñas de tijera",
	"tenaza": "las tenazas", "presion": "la gasa", "hemostatico": "el polvo hemostático", "nitrato_plata": "el lápiz de nitrato de plata",
	"lija_p180": "la lija P180", "lija_p240": "la lija P240", "lima_diamante_gruesa": "la lima de diamante gruesa",
	"lima_diamante_fina": "la lima de diamante fina", "agua": "el agua tibia", "espatula": "la espátula", "alcohol": "el alcohol",
}


func _tool_short(id: String) -> String:
	if TOOL_NAMES.has(id):
		return String(TOOL_NAMES[id])
	var e := tray_entry(id)
	return "la %s" % String(e.get("short", id)).to_lower() if not e.is_empty() else id


## La primera letra en mayúscula (String.capitalize pone en mayúscula cada palabra).
static func cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


## La rugosidad en palabras (µm).
static func ra_words(ra: float) -> String:
	if ra < 0.1:
		return "pulida"
	if ra < 0.5:
		return "lisa"
	if ra < 2.0:
		return "con rayas finas"
	return "rayada"


## Una pasada (o un toque) en una línea (petición 51, «qué ha hecho cada pasada»): lo que ha quitado, cómo ha quedado la
## superficie y cuánto falta para la forma o la punta (las pasadas, con lo que han quitado las de antes); si no ha mordido, por
## qué y qué coger.
func pass_summary(rec: Dictionary) -> String:
	if bool(rec.get("noBite", false)):
		return no_bite_text(String(rec.tool), float(rec.get("s", care.apex_mm())), float(rec.get("heatW", 0.0)))
	var parts: Array = ["%s: %s fuera" % [cap(_tool_short(String(rec.tool))), fmt_vol(float(rec.mm3))]]
	if float(rec.get("raUm", -1.0)) >= 0.0:
		parts.append("superficie %s (Ra %s µm)" % [ra_words(float(rec.raUm)), Js.to_fixed(float(rec.raUm), 2)])
	var left := float(rec.get("leftAfter", 0.0))
	var hi := float(CareData.MARGINS.tip_ratio_hi)
	var ratio := float(rec.get("ratioAfter", 1.0))
	if left > 0.05:
		var per := _mean_drop("apexBefore", "apexAfter")
		var n_more := int(ceilf(left / per)) if per > 1e-4 else 0
		var pace := ""
		if n_more > 0 and n_more <= 20:
			pace = " (~%d pasadas así)" % n_more
		elif per > 0.0:
			pace = " (así va despacio: %s, de frente, acorta más)" % _tool_short(_rough_tool_for(float(rec.get("s", care.apex_mm()))))
		parts.append("faltan %s mm para su largo%s" % [Js.to_fixed(left, 1), pace])
	elif ratio > hi:
		var per_r := _mean_drop("ratioBefore", "ratioAfter")
		var n_tip := int(ceilf((ratio - hi) / per_r)) if per_r > 1e-4 else 0
		parts.append("punta ×%s de la natural, buena hasta ×%s%s" % [Js.to_fixed(ratio, 1), Js.to_fixed(hi, 1), (" (~%d pasadas en la punta)" % n_tip) if n_tip > 0 and n_tip <= 20 else (" (en faceta, con la lima fina)" if n_tip > 20 else "")])
	else:
		parts.append("largo y punta, como la natural")
	return " · ".join(parts)


## Lo que han bajado de media las últimas pasadas (hasta 3) que han quitado algo: el largo (apex) o el radio de la punta (ratio).
func _mean_drop(before: String, after: String) -> float:
	var n := 0
	var sum := 0.0
	for rec: Dictionary in _passes:
		var d := float(rec.get(before, 0.0)) - float(rec.get(after, 0.0))
		if d > 0.0:
			sum += d
			n += 1
		if n >= 3:
			break
	return sum / float(n) if n > 0 else 0.0


## La herramienta de desbastar de la bandeja que muerde el material en s (la lima gruesa en la queratina; la de diamante gruesa
## en lo duro); si ninguna muerde bien, la de diamante gruesa.
func _rough_tool_for(s_mm: float) -> String:
	for id: String in ["lima_bastarda", "lima_diamante_gruesa"]:
		if care.bites_at(id, s_mm) >= 0.5:
			return id
	return "lima_diamante_gruesa"


## Por qué no muerde una herramienta (petición 51): las durezas (la de la herramienta y la del material donde toca) y la de la
## bandeja que sí muerde, en su lugar.
func no_bite_text(tool_id: String, s_mm: float, heat_w: float = 0.0) -> String:
	var td := tool_data(tool_id)
	var m := care.material_at(clampf(s_mm, 0.0, care.apex_mm()))
	var better := ""
	for t: Dictionary in TRAY:
		var id := String(t.id)
		var d := CareData.tool(id)
		if String(d.get("kind", "")) in ["lima", "torno"] and care.bites_at(id, s_mm) >= 0.5:
			if better == "" or (TOOL_GUIDE.has(id) and String(TOOL_GUIDE[id][0]) == "desbastar"):
				better = id
				if TOOL_GUIDE.has(id) and String(TOOL_GUIDE[id][0]) == "desbastar":
					break
	var txt := "%s (~%s HV) no muerde: %s (%s HV) es igual de dura o más; una lima solo muerde lo que es más blando que ella." % [
		cap(_tool_short(tool_id)), Js.to_fixed(float(td.get("tool_hv", 0.0)), 0), "el " + String(m.name) if bool(m.reforged) else "la queratina", Js.to_fixed(float(m.hv), 0)]
	if heat_w > 0.0:
		txt += " Gira y roza: calienta (%s W) y se gasta." % Js.to_fixed(heat_w, 2)
	if better != "":
		txt += " Coge %s (~%s HV)." % [_tool_short(better), Js.to_fixed(float(CareData.tool(better).get("tool_hv", 0.0)), 0)]
	else:
		txt += " Ninguna de la bandeja la muerde bien."
	return txt


## Para qué sirve una herramienta de limar y cómo se usa (petición 51): «Desbastar, 1.º: quita mucho… Arrastra a lo largo de la
## garra…». «» si no es de limar.
## file_how: el «cómo» de las limas ya hecho (tray_view lo hace una vez para toda la bandeja); «» lo hace aquí.
func tool_guide_text(id: String, file_how: String = "") -> String:
	if not TOOL_GUIDE.has(id):
		return ""
	var gd: Array = TOOL_GUIDE[id]
	var how := file_how if file_how != "" else _file_how()
	if is_rotary(id):
		how = "Enciéndela (E), toca la garra unos segundos y suelta para que se enfríe; Q, la velocidad; W/S, la presión; A/D, el ángulo."
	return "%s (%s): %s. %s" % [String(tray_entry(id).get("short", id)), String(ROLE_NAMES[String(gd[0])]), String(gd[2]), how]


## Cómo se usa una lima, con la presión y el ángulo de ahora.
func _file_how() -> String:
	return "Arrastra a lo largo de la garra, de la base a la punta, y suelta al acabar la pasada; W/S, la presión (%s N); A/D, el ángulo (%s°, %s)." % [
		Format.fmt_f(force_n), Js.to_fixed(angle_deg, 0), "de frente: acorta" if angle_deg >= ClawCare.TRUNCATE_DEG else "en faceta: da la punta"]


## La vista de la cámara que se ve (la página la dice al cambiarla).
func note_view(id: String) -> void:
	if id != _view_id:
		_view_id = id
		_touch()


# ════════════════════════════════ Vista ════════════════════════════════

## ¿Se ve la carne viva? En las garras claras siempre (a trasluz); en las oscuras, al terminar. Una reforjada no tiene.
func quick_revealed(sn: Dictionary = {}) -> bool:
	if is_reforged():
		return false
	var s := sn if not sn.is_empty() else care.snapshot()
	return bool(s.claw.quickVisible) or finished


## La banda de la población donde acaba la carne viva (mm desde la base): core_ratio.min y max × el largo natural.
func quick_band_mm() -> Array:
	if is_reforged():
		return []
	var a: Dictionary = CareData.ANIMALS[String(setup.animal)]
	var band: Dictionary = a.core_ratio
	var L := float(care.snapshot().claw.naturalMm)
	return [float(band.min) * L, float(band.max) * L]


## Todo lo que pintan la escena y la interfaz (un diccionario nuevo; sin la carne viva oculta).
func view() -> Dictionary:
	var sn := care.snapshot()
	var rep := care.report()
	var revealed := quick_revealed(sn)
	if not revealed:
		# la carne viva oculta no sale de aquí: ni su posición ni su perfil
		sn.claw["quickMm"] = null
		sn.claw["quickCoverMm"] = null
		var zeros := PackedFloat64Array()
		zeros.resize((sn.profile.core as PackedFloat64Array).size())
		sn.profile["core"] = zeros
		sn.thermal["quickCell"] = -1
		rep = _hide_quick(rep)
	var tut := tutorial_view(sn)
	var hints := {
		"highlight": String(tut.hint) if tutorial_on else "",
		"overgrowth": [float(sn.claw.naturalMm), float(sn.claw.lengthMm)] if float(sn.claw.lengthMm) > float(sn.claw.naturalMm) else [],
		"quick_band": quick_band_mm(),
		"good_angle": [float(sn.tip.naturalAlphaDeg), float(sn.tip.naturalAlphaDeg) + float(CareData.MARGINS.facet_deg)],
		"tip_zone_mm": maxf(TIP_ZONE_FRACTION * float(sn.claw.naturalMm), TIP_ZONE_MIN_MM),
		"revealed": revealed,
	}
	return {
		"serial": _serial, "setup": setup.duplicate(true), "snap": sn, "report": rep, "finished": finished,
		"paused": paused, "reforged": is_reforged(), "initial_profile": _initial_profile.duplicate(true),
		"hand": hand_view(), "tray": tray_view(String(tut.suggest)), "tutorial": tut, "hints": hints,
		"readouts": readouts(sn, revealed), "events": events_view(sn), "notice": _notice,
		"last_action": _last_action.duplicate(true), "fx": _fx.duplicate(true), "fx_n": _fx_n,
		"texts": texts(sn, rep, revealed), "time_scale": time_scale, "sound": sound_view(), "mistake": mistake_view(),
		"sheet": result_sheet() if finished else {}, "bench": bench_setup() if finished else {},
		"paw": paw, "digit": digit, "paws": paws_of(String(setup.animal)), "digits": DIGITS.get(String(setup.animal), []),
		"paw_label": paw_name(String(setup.animal), paw), "claw_label": claw_label(String(setup.animal), paw, digit),
		"slots": slots_view(), "model": model if String(setup.animal) == "velociraptor" else "",
		"reforge_request": _reforge_view(sn),
		# cómo van las herramientas de limar del ensayo (unidad 5l: ClawCareKit.state de cada una) y su número de cambios
		"tools": care.tools(), "tools_serial": kit.serial,
		# la pieza de la reforja que se coloca a mano (unidad 5o)
		"bond": bond_view(sn),
		# petición 51: el estado del animal (la barra de arriba: meters), lo que se está haciendo con su cuenta y la sesión
		# parada; unidad 5t-A: el animal es la vista del paciente (claw_care_patient.gd), con su reacción (reaction) y la barra
		"animal": animal_dict(sn), "activity": activity_view(sn), "halted": halted.duplicate(true), "blood": blood_state(),
		# unidad 5t-A: la lente de la cámara con sus rayones (claw_care_lens.gd)
		"lens": lens.view(),
		# petición del 18-10: el peligro para las lentes de la pata de ahora, con su material y sus puntas
		"lens_danger": danger_now(),
	}


## La colocación de la pieza de la garra elegida para la escena y la interfaz (unidad 5o), o {} sin pieza: la pieza (con lo
## que en la realidad no se hace), el método, el adhesivo, la preparación, la sujeción, el acrílico, la resina con la
## lámpara, lo que rebosa, el escalón, lo curado, lo que aguanta, la prueba y el paso que toca, con «en la vida real
## tardaría…».
func bond_view(sn: Dictionary = {}) -> Dictionary:
	var b := bond()
	if b == null:
		return {}
	var s := sn if not sn.is_empty() else care.snapshot()
	var now := care.time_s()
	var pc: Dictionary = b.piece
	var hum := String(s.claw.humidity)
	var cap := b.capacity(now, hum)
	var force := float(CareData.BOND_TEST.force_frac) * float(CareData.claw_entry(String(setup.claw)).get("force", 0.0))
	var stp := joint_step_mm()
	var tm := Bond.adhesive_times(b.adhesive)
	var adh: Array = []
	for id: String in Bond.ADHESIVE_IDS:
		var a := Bond.adhesive_data(id)
		var t := Bond.adhesive_times(id)
		adh.append({ "id": id, "name": String(a.name), "tauMPa": float(a.tau), "gapMaxMm": float(a.gap_max),
			"fills": Bond.fills(id, float(pc.get("gapMm", 0.0))), "fixText": Bond.dur(float(t.fix_s)), "fullText": Bond.dur(float(t.full_s)),
			"mix": String(t.mix), "quality": String(a.quality), "source": short_source(String(a.source) + "; " + String(t.source)) })
	var methods: Array = []
	for m: String in pc.get("methods", []):
		methods.append({ "id": m, "name": String(Bond.METHOD_NAMES.get(m, m)) })
	var resin: Array = []
	for l: Dictionary in b.resin:
		resin.append({ "h": float(l.h), "cdMm": float(l.cd), "cured": float(l.cured), "dose": float(l.dose) })
	var hold_s := now - float(b.placed.get("t", now)) if not b.placed.is_empty() else 0.0
	var stage := _bond_stage(b, now, stp)
	var lamp_d: Dictionary = CareData.LAMPS[b.lamp]
	var irr := Bond.irradiance_at(b.lamp, b.lamp_mm)
	# lo que dice de la pieza el laboratorio (5m): el acabado, la rugosidad y la holgura de la prueba del ajuste
	var lab: Dictionary = pc.get("lab", {})
	var lab_text := ""
	if not lab.is_empty() and bool(lab.get("carved", false)):
		lab_text = "Del laboratorio: %s%s%s." % ["pulida" if bool(lab.get("polished", false)) else "tallada",
			(", Ra %s µm" % Js.to_fixed(float(lab.raUm), 2)) if float(lab.get("raUm", 0.0)) > 0.0 else "",
			(", holgura probada en la garra: %s mm" % Js.to_fixed(float(lab.gapMm), 3)) if bool(lab.get("fitTested", false)) else ", sin probar el ajuste"]
	return {
		"serial": b.serial, "kind": String(pc.kind), "label": String(pc.get("label", pc.kind)), "broken": bool(pc.get("broken", false)),
		"lab_text": lab_text, "enters": float(pc.gapMm) >= 0.0 or String(b.method) != "adhesivo",
		# con la resina, la prótesis es de resina aunque la pieza llegara como acrílico
		"material": String(pc.material), "name": String(CareData.RESIN.name) if b.method == "resina" else String(pc.name),
		"fiction": bool(pc.fiction), "note": String(pc.note), "note_source": short_source(String(pc.source)),
		"gapMm": float(pc.gapMm), "areaMm2": float(pc.areaMm2), "jointMm": float(pc.jointMm), "stumpRadiusMm": float(pc.stumpRadiusMm),
		"wallMm": float(pc.wallMm), "needMm": float(pc.needMm), "builtMm": b.built_mm,
		"methods": methods, "method": b.method, "adhesive": b.adhesive, "adhesives": adh, "started": b.started(),
		"cleaner": b.cleaner, "wet": b.is_wet(now), "sanded": b.sanded(), "raUm": b.ra_um,
		"purged": b.purged, "applied": b.applied_t >= 0.0, "twoPart": int(tm.get("parts", 1)) >= 2,
		"workLeftS": maxf(float(tm.work_s) - (now - b.applied_t), 0.0) if b.applied_t >= 0.0 and b.placed.is_empty() else 0.0,
		"held": b.held, "tiltDeg": b.tilt_deg, "aimMm": b.aim_mm, "placed": not b.placed.is_empty(), "holding": b.holding,
		"holdS": hold_s, "fixS": float(tm.fix_s), "fixed": b.fixed_t >= 0.0, "wrapped": b.wrapped, "failure": b.failure,
		"tolTiltDeg": float(CareData.BOND_ALIGN.tilt_deg), "tolOffsetMm": float(CareData.BOND_ALIGN.offset_mm),
		"placedTiltDeg": float(b.placed.get("tilt", b.tilt_deg)), "placedOffsetMm": float(b.placed.get("offset", 0.0)),
		"flashMm3": b.flash_mm3, "fresh": b.fresh(now), "stepMm": stp, "stepOkMm": float(CareData.BOND_JOINT.step_ok_mm),
		"attached": b.attached(), "set": b.set_all(now), "curePct": 100.0 * float(cap.factors.cure),
		"capN": float(cap.capN), "testN": force, "limitedBy": String(cap.limitedBy), "reasons": cap.reasons,
		"test": b.test.duplicate(true),
		"mixPhase": b.mix_phase(now), "mixAgeS": now - float(b.mix.t) if not b.mix.is_empty() else 0.0, "layers": b.layers.size(),
		"layerKind": layer_kind, "ratios": CareData.ACRYLIC_MIX.ratios, "ratio": float(CareData.ACRYLIC_MIX.ratio_w),
		"lamp": b.lamp, "lampName": String(lamp_d.name), "lampMm": b.lamp_mm, "lampS": b.lamp_s, "eyes": b.eyes_covered,
		"lampOn": b.lamp_on, "lampLeftS": maxf(b.lamp_end - now, 0.0) if b.lamp_on else 0.0,
		"irradiance": irr, "cureDepthMm": Bond.cure_depth_mm(irr * b.lamp_s / 1000.0),
		"resin": resin, "lamps": CareData.LAMPS.keys(), "times": CareData.CURE_DEPTH.times, "distances": CareData.CURE_DEPTH.distances,
		"quickC": float(s.thermal.quickC), "peakQuickC": float(s.thermal.peakQuickC), "painC": float(s.thermal.painC),
		"stage": String(stage.id), "stage_text": String(stage.text), "real_time": String(stage.get("real", "")),
		"notice": b.notice, "done": b.finished(now, stp),
	}


## En la vida real tardaría secs; con el reloj de ahora, secs / time_scale.
func _real_time(secs: float) -> String:
	return "En la vida real, %s; con el reloj a ×%s, %s." % [Bond.dur(secs), Js.to_fixed(time_scale, 0), Bond.dur(secs / time_scale)]


## El paso que toca en la colocación: { id, text, real (en la vida real tardaría…) }.
func _bond_stage(b: Bond, now: float, stp: float) -> Dictionary:
	var tm := Bond.adhesive_times(b.adhesive)
	if not b.failure.is_empty():
		return { "id": "quitar", "text": "Quítala y empieza de nuevo: %s." % String(Bond.REASON_WORDS.get(b.failure, "se ha despegado" if b.failure == "despegada" else b.failure)) }
	if not b.attached() and not b.started():
		if b.cleaner == "":
			return { "id": "limpiar", "text": "Limpia y desengrasa donde va a pegar: alcohol o clorhexidina (bandeja de las curas)." }
		if b.is_wet(now):
			return { "id": "secar", "text": "Seca: el alcohol se evapora solo en unos segundos." if b.cleaner == "alcohol" else "Seca la clorhexidina apretando la gasa sobre la garra." }
		if not b.sanded():
			return { "id": "lijar", "text": "Lija un poco la queratina donde va a pegar (la lija P180 o P240, una pasada suave)." }
	match b.method:
		"adhesivo":
			if b.applied_t < 0.0:
				if int(tm.get("parts", 1)) >= 2 and not b.purged:
					return { "id": "purgar", "text": "Purga la cánula de la jeringa doble (lo primero que sale va mal mezclado)." }
				return { "id": "aplicar", "text": "Pon el adhesivo en la pieza: desde ahí corre su tiempo de trabajo (%s)." % Bond.dur(float(tm.work_s)) }
			if b.placed.is_empty():
				return { "id": "colocar", "text": "Coge la pieza y apriétala sobre el muñón, alineada con la silueta de la forma sana (gírala con A/D)." }
			if b.fixed_t < 0.0:
				var left := float(tm.fix_s) - (now - float(b.placed.t))
				return { "id": "sujetar", "text": "Sujétala quieta hasta que fije (quedan %s)%s." % [Bond.dur(maxf(left, 0.0)), "" if b.wrapped or float(tm.fix_s) < 120.0 else "; una cola lenta se sujeta con la venda"], "real": _real_time(float(tm.fix_s)) }
			if b.wrapped:
				return { "id": "venda", "text": "Ha fijado: quita la venda." }
		"acrilico":
			if not b.done_building():
				var ph := b.mix_phase(now)
				if ph == "":
					return { "id": "mezclar", "text": "Mezcla el polvo y el líquido en el vaso (2:1 en peso) para la próxima capa." }
				if ph == "liquida":
					return { "id": "masa", "text": "Espera a la fase de masa: aún chorrea.", "real": _real_time(float(CareData.ACRYLIC_MIX.dough_s)) }
				if ph == "masa":
					return { "id": "capa", "text": "Aplica la capa con la espátula sobre el muñón (%s mm de %s)." % [Js.to_fixed(b.built_mm, 1), Js.to_fixed(float(b.piece.needMm), 1)] }
				return { "id": "mezclar", "text": "Ya no se modela: mezcla otra." }
			if not b.set_all(now):
				return { "id": "fraguar", "text": "Deja que fragüe: no se lima en fresco.", "real": _real_time(float(CareData.ACRYLIC_MIX.set_s)) }
		"resina":
			if not b.eyes_covered:
				return { "id": "ojos", "text": "Tapa los ojos del animal y pon el filtro naranja antes de encender la lámpara." }
			if b.lamp_on:
				return { "id": "curar", "text": "La lámpara cura la capa: %s." % Bond.dur(maxf(b.lamp_end - now, 0.0)) }
			if not b.resin.is_empty() and float(b.resin.back().cured) < 1.0:
				return { "id": "curar", "text": "Cura la capa con la lámpara (casi tocando, %s)." % Bond.dur(b.lamp_s) }
			if not b.done_building():
				return { "id": "capa", "text": "Pon una capa fina de resina con la espátula (%s mm de %s)." % [Js.to_fixed(b.built_mm, 1), Js.to_fixed(float(b.piece.needMm), 1)] }
	if b.flash_mm3 > 0.0:
		return { "id": "rebaba", "text": ("Quita lo que rebosa con la espátula, ahora que está fresco." if b.fresh(now) else "Quita lo que rebosa con la lima (ya está duro).") }
	if stp > float(CareData.BOND_JOINT.step_ok_mm):
		return { "id": "escalon", "text": "Lima el escalón de la unión hasta que no se note (%s mm)." % Js.to_fixed(stp, 2) }
	if not bool(b.test.get("ok", false)):
		return { "id": "probar", "text": "Dale la forma y la punta, y prueba la unión con un tirón suave de lado." }
	return { "id": "lista", "text": "Unida, sin rebabas ni escalón y probada: lista para el banco." }


## El sonido continuo: el motor de la herramienta giratoria encendida (su bucle, motor_id, y su tono: las rpm frente a
## las del bucle horneado, que baja con la carga mientras aprieta contra la garra: motor_load, diseño de sonido) y el
## roce de la lima o del tambor mientras trabaja.
func sound_view() -> Dictionary:
	var motor := rotary_on and is_rotary(tool) and not paused and not finished
	var mid := SfxCare.motor_of(rotary_tool())
	var load := 0.0
	if motor and not _gesture.is_empty() and bool(_gesture.get("contact", false)):
		load = force_n / (force_n + MOTOR_LOAD_HALF_N)
	return {
		"motor": motor, "motor_id": mid, "motor_rpm": rpm(), "motor_load": load,
		"motor_pitch": rpm() / SfxCare.base_rpm(mid) * (1.0 - MOTOR_LOAD_DROP * load),
		"rasp": not paused and not finished and care.time_s() <= _rasp_until, "rasp_pitch": _rasp_pitch,
		# roza sin morder (unidad 5l): el roce suena a chirrido
		"rasp_squeal": _rasp_squeal,
	}


## Sin la carne viva oculta: los datos del informe que dirían dónde está (se revelan al terminar).
func _hide_quick(rep: Dictionary) -> Dictionary:
	var r := rep.duplicate(true)
	if r.has("facts"):
		r.facts["quickCoverMm"] = null
		r.facts["safeMarginMm"] = null
	return r


# ════════════════════════════════ Ficha final y fuentes ════════════════════════════════

## La ficha de la garra al terminar, antes → después, con los números del motor (snapshot, report y tip_geometry):
## { rows: [{ id, label, before, after, tone }], verdict, verdict_text, grade_text, criteria: [{ title, text, source }],
##   advice: [{ title, text, source }], regrow }. Solo al terminar ({} antes: la carne viva de una garra oscura no se
## revela hasta entonces).
func result_sheet() -> Dictionary:
	if not finished or _start_snap.is_empty():
		return {}
	var a: Dictionary = _start_snap
	var b := care.snapshot()
	var rep := care.report()
	var ta: Dictionary = a.tip
	var tb: Dictionary = b.tip
	var geo := care.tip_geometry()
	var nat := float(b.claw.naturalMm)
	var rows: Array = []
	rows.append(_sheet_row("largo", "Largo", "%s mm" % Js.to_fixed(float(a.claw.lengthMm), 1), "%s mm" % Js.to_fixed(float(b.claw.lengthMm), 1), "", "natural %s mm" % Js.to_fixed(nat, 1)))
	var left := float(b.claw.overgrowthLeftMm)
	var over0 := float(a.claw.overgrowthLeftMm)
	rows.append(_sheet_row("sobrante", "Sobrante", _over_text(over0), _over_text(left), "aviso" if left > float(CareData.MARGINS.overgrowth_left) * maxf(over0, 0.0) else "bien", ""))
	rows.append(_sheet_row("punta", "Radio de la punta", "%s µm (×%s)" % [Js.to_fixed(float(ta.tipRadiusUm), 0), Js.to_fixed(float(ta.ratio), 2)],
		"%s µm (×%s)" % [Js.to_fixed(float(geo.R) * 1000.0, 0), Js.to_fixed(float(tb.ratio), 2)],
		"aviso" if float(tb.ratio) > float(CareData.MARGINS.tip_ratio_hi) or float(tb.ratio) < float(CareData.MARGINS.tip_ratio_lo) else "bien",
		"la natural: %s µm" % Js.to_fixed(float(tb.naturalUm), 0)))
	var facet := float(tb.facetDeg)
	var face_after := "faceta de %s°" % Js.to_fixed(facet, 0) if facet > 0.0 else "sin faceta"
	if float(tb.flatMm) > 0.0:
		face_after += " · cara plana de %s µm" % Js.to_fixed(float(tb.flatMm) * 1000.0, 0)
	rows.append(_sheet_row("faceta", "Faceta", "la natural, %s°" % Js.to_fixed(float(ta.naturalAlphaDeg), 0), face_after,
		"bien" if facet <= 0.0 or absf(facet - float(tb.naturalAlphaDeg)) <= float(CareData.MARGINS.facet_deg) else "aviso", ""))
	if tb.strengthRatio != null and ta.strengthRatio != null:
		rows.append(_sheet_row("aguante", "Aguanta de lado", "%s (%s)" % [Format.fmt_small_force(float(ta.lateralN)), strength_words(float(ta.strengthRatio), true)],
			"%s (%s)" % [Format.fmt_small_force(float(tb.lateralN)), strength_words(float(tb.strengthRatio), true)],
			"mal" if float(tb.strengthRatio) < 0.25 else "bien", "en el vértice, frente a la natural"))
	if is_reforged():
		rows.append(_sheet_row("carne", "Carne viva", "no tiene", "no tiene", "", "garra reforjada"))
	else:
		var c0 := float(a.claw.quickCoverMm)
		var c1 := float(b.claw.quickCoverMm)
		rows.append(_sheet_row("carne", "Distancia a la carne viva", "%s mm" % Js.to_fixed(c0, 1), "%s mm" % Js.to_fixed(c1, 1) if c1 > 0.0 else "cortada",
			"mal" if c1 <= 0.0 else ("aviso" if rep.facts.safeMarginMm != null and c1 < float(rep.facts.safeMarginMm) else "bien"), "queratina delante de la carne viva"))
	var dmg: Dictionary = b.damage
	var cracks: Array = []
	if not (dmg.splits as Array).is_empty():
		var total := 0.0
		for sp: Dictionary in dmg.splits:
			total += maxf(float(sp.to_s) - float(sp.from_s), 0.0)
		cracks.append("%d grieta(s), %s mm" % [(dmg.splits as Array).size(), Js.to_fixed(total, 1)])
	if not (dmg.peels as Array).is_empty():
		cracks.append("deshojada")
	if int(dmg.chips) > 0:
		cracks.append("mellada %d vez/veces" % int(dmg.chips))
	if bool(dmg.broken):
		cracks.append("rota" + (" y reconstruida" if bool(dmg.repaired) else ""))
	rows.append(_sheet_row("grietas", "Grietas y roturas", "ninguna", ", ".join(cracks) if not cracks.is_empty() else "ninguna", "mal" if not cracks.is_empty() else "bien", ""))
	if not is_reforged():
		var th: Dictionary = b.thermal
		rows.append(_sheet_row("calor", "Calor en la carne viva", "%s °C" % Js.to_fixed(float(a.thermal.quickC), 0), "pico de %s °C%s" % [Js.to_fixed(float(th.peakQuickC), 1), " · lesión" if bool(th.injured) else ""],
			"mal" if bool(th.injured) or float(th.peakQuickC) >= float(th.painC) else "bien", "dolor desde %s °C" % Js.to_fixed(float(th.painC), 0)))
		var bl: Dictionary = b.bleeding
		var btxt := "no ha sangrado"
		if bool(bl.bled):
			btxt = ("sigue sangrando" if bool(bl.active) else "paró a los %s" % _clock(float(bl.elapsedS)))
			if String(bl.agent) != "":
				btxt += " · con %s" % String(tool_data(String(bl.agent)).get("name", "")).to_lower()
		rows.append(_sheet_row("sangre", "Sangre", "no", btxt, "mal" if bool(bl.active) else ("aviso" if bool(bl.bled) else "bien"), ""))
	var mat := material_text()
	rows.append(_sheet_row("material", "Material y dureza", mat, mat, "", String(b.claw.humidityName).to_lower() if not is_reforged() else ""))
	rows.append(_sheet_row("arrancado", "Arrancado", "—", "%s mm³" % Js.to_fixed(float(b.claw.removedMm3), 2), "", ""))
	var crit: Array = []
	for c: Dictionary in rep.criteria:
		crit.append({ "title": String(c.title), "text": String(c.text), "source": short_source(String(c.source)) })
	var adv: Array = []
	# el consejo del calor ya habla de la herramienta giratoria que se ha usado (ClawCare, unidad 5g)
	for ad: Dictionary in rep.advice:
		adv.append({ "id": String(ad.get("id", "")), "title": String(ad.title), "text": String(ad.text), "source": short_source(String(ad.source)) })
	if escapes > 0:
		adv.append({ "id": "se_solto", "title": "Se ha soltado",
			"text": "La rapaz se soltó %s y hubo que recogerla con la toalla. Encapúchala y envuélvela antes de tocarle las garras: así no se estresa hasta soltarse." % ("una vez" if escapes == 1 else "%d veces" % escapes),
			"source": short_source(String(CareData.ANIMAL_RISK.source)) })
	var rg: Variant = rep.regrow
	# las demás garras que se han trabajado, con su veredicto y su nota (cada una tiene su propio informe)
	var others: Array = []
	for key: String in _slots:
		var e: Dictionary = _slots[key]
		if not bool(e.worked):
			continue
		var orep: Dictionary = (e.care as ClawCare).report()
		var parts := key.split("|")
		others.append({ "label": claw_label(String(setup.animal), parts[0], parts[1]), "verdict_text": String(orep.verdictText),
			"grade_text": String(orep.gradeText), "verdict": String(orep.verdict) })
	return {
		"claw_label": claw_label(String(setup.animal), paw, digit), "others": others,
		"rows": rows, "verdict": String(rep.verdict), "verdict_text": String(rep.verdictText), "grade_text": String(rep.gradeText),
		"criteria": crit, "advice": adv, "rubric_source": short_source(String(rep.rubricSource)),
		"regrow": ("%s (%s)" % [String(rg.text), short_source(String(rg.source))]) if rg is Dictionary else "",
	}


## Lo que se lleva al «Banco de ensayo» al terminar, sin física nueva: la garra del banco de este animal, su material y
## el afilado s del deslizador del banco que deja la punta de ahora (ClawSharpness.sharpness_for, la inversa de su
## radius_at, desde la punta natural de la garra del banco): { claw, inlay, sharpness, tip_um, natural_um, note }. El
## banco no embota (una punta más roma que la natural va como la natural) ni talla el semiángulo (la faceta no pasa).
func bench_setup() -> Dictionary:
	var ce := CareData.claw_entry(String(setup.claw))
	if ce.is_empty() or not ce.has("area"):
		return {}
	var ts := care.tip_state()
	var r0 := ClawSharpness.radius_um_of_area(float(ce.area))
	var r := float(ts.tipRadiusUm)
	var s := ClawSharpness.sharpness_for(r0, r)
	var notes: Array = []
	if r > r0:
		notes.append("la punta ha quedado más roma que la natural y el banco no embota: va como la natural")
	if float(ts.facetDeg) > 0.0 and absf(float(ts.facetDeg) - float(ts.naturalAlphaDeg)) > 0.5:
		notes.append("el banco conserva el semiángulo de la garra (%s°), no el de la faceta (%s°)" % [Js.to_fixed(float(ts.naturalAlphaDeg), 0), Js.to_fixed(float(ts.facetDeg), 0)])
	return { "claw": String(ce.id), "inlay": String(setup.inlay), "sharpness": s, "tip_um": r, "natural_um": r0,
		"note": "; ".join(notes) }


static func _sheet_row(id: String, label: String, before: String, after: String, tone: String, note: String) -> Dictionary:
	return { "id": id, "label": label, "before": before, "after": after, "tone": tone, "note": note }


static func _over_text(left: float) -> String:
	if left > 0.05:
		return "%s mm de más" % Js.to_fixed(left, 1)
	if left > -0.05:
		return "a su largo"
	return "%s mm más corta" % Js.to_fixed(-left, 1)


## El material de la garra y su dureza (la del banco: Data.CLAWS para la queratina, Catalog.INLAYS para las reforjadas).
func material_text() -> String:
	return material_for(setup)


static func material_for(s: Dictionary) -> String:
	if String(s.get("inlay", "none")) != "none":
		var inl: Dictionary = Catalog.find_by_id(Catalog.INLAYS, String(s.inlay))
		return "%s, %s HV" % [String(inl.name), grouped(float(inl.hv))]
	var ce: Dictionary = CareData.claw_entry(String(s.get("claw", "aguila")))
	return "queratina, %s HV" % grouped(float(ce.get("hv", 0.0)))


## Los materiales que se pueden elegir para la garra, a la vista: [{ id, label, title }] (queratina y Catalog.INLAYS, con su
## dureza: los de la 1.x y, detrás, los nuevos de la 2.0, el rubí y la alúmina).
static func inlay_options() -> Array:
	var out: Array = []
	for inl: Dictionary in Catalog.INLAYS:
		var id := String(inl.id)
		if id == "none":
			out.append({ "id": id, "label": "Queratina", "title": "La garra de siempre, de queratina: crece, tiene carne viva y sangra" })
		else:
			out.append({ "id": id, "label": String(inl.short), "title": "Garra reforjada: %s, %s HV" % [String(inl.name), grouped(float(inl.hv))] })
	return out


## Los datos del ensayo que se ve, con su valor, su calidad y su fuente legible: [{ label, value, quality, quality_text,
## source }]. Salen de CareData (y del banco para la dureza y el material): la interfaz los enseña todos.
func values_table() -> Array:
	var s := setup.duplicate()
	s["paw"] = paw
	s["digit"] = digit
	return values_for(s)


## values_table() para unos ajustes (animal, claw, inlay, humidity, overgrowth_days, paw, digit): la página la llama al
## cambiarlos.
static func values_for(setup: Dictionary) -> Array:
	var out: Array = []
	var reforged := String(setup.get("inlay", "none")) != "none"
	var an: Dictionary = CareData.animal(String(setup.get("animal", "rapaz")))
	var g: Dictionary = an.growth_mm_day
	if reforged:
		out.append(_val("Crecimiento de la garra", "0 mm al día (no crece)", "primary", "%s; la queratina del muñón crece %s mm al día (%s)" % [INERT_TEXT, Js.to_fixed(float(g.value), 2), short_source(String(g.source))]))
	else:
		out.append(_val("Crecimiento de la garra", "%s mm al día%s" % [Js.to_fixed(float(g.value), 2), _band(g, 2)], String(g.quality), String(g.source)))
		out.append(_val("Días sin desgaste", Js.to_fixed(float(setup.get("overgrowth_days", CareData.DEFAULT_OVERGROWTH_DAYS)), 0), "estimate", "elección del ensayo: una temporada en cautividad con perchas o suelos blandos, sin desgaste (sin medición)"))
	if not reforged:
		var cr: Dictionary = an.core_ratio
		out.append(_val("Dónde acaba la carne viva", "a ×%s del estuche desde la base%s" % [Js.to_fixed(float(cr.value), 3), _band(cr, 3)], String(cr.quality), String(cr.source)))
	out.append(_val("Material y dureza", material_for(setup), "secondary", CareData.SRC_ENGINE_KERATIN if not reforged else "catálogo de materiales del banco de ensayo"))
	var cid := String(setup.get("claw", "aguila"))
	var hind := is_hind(String(setup.get("paw", "")))
	if String(setup.get("animal", "rapaz")) in ["tigre", "oso"]:
		var hs: Dictionary = (CareData.CLAW_SHAPES.get(cid, {}) as Dictionary).get("hind", {})
		out.append(_val("Garras de las patas traseras", "como las de la mano (sin medición propia)" + (": la pata elegida es trasera" if hind else ""), String(hs.get("quality", "estimate")),
			String(hs.get("source", "las garras de los pies no tienen datos propios y llevan los de la mano: estimación"))))
	# la garra de este dedo (petición 36): su largo, su arco y su sección, de CareData.CLAW_SHAPES
	var sh := CareData.claw_shape(cid, String(setup.get("digit", "")), hind)
	var nat := float(CareData.claw_entry(cid).get("reach", 0.0)) * float(sh.lengthRatio)
	out.append(_val("La garra del dedo %s" % String(sh.digit), "%s mm de largo natural (×%s la del dedo %s), arco de %s°" % [Js.to_fixed(nat, 1), Js.to_fixed(float(sh.lengthRatio), 2), String(sh.refDigit), Js.to_fixed(float(sh.arcDeg), 0)],
		String(sh.quality), String(sh.source)))
	var sec := float(sh.sectionRatio)
	out.append(_val("Sección de la garra", ("redonda" if sec <= 1.0 else "%s veces más alta que ancha" % Js.to_fixed(sec, 1)) + (", con la cara de abajo plana" if bool(sh.ventralFlat) else ""),
		String(sh.sectionQuality), String(sh.sectionSource)))
	if reforged:
		var st: Variant = ClawSharpness.strength_of(String(setup.inlay))
		if st != null:
			out.append(_val("Resistencia del material", "%s MPa%s" % [Js.to_fixed(float(st.value), 0), (" (de %s a %s)" % [Js.to_fixed(float(st.min), 0), Js.to_fixed(float(st.max), 0)]) if float(st.min) != float(st.max) else ""], String(st.quality), String(st.source)))
	else:
		var k: Dictionary = CareData.keratin(String(setup.get("humidity", "natural")))
		out.append(_val("Queratina %s" % String(k.name).to_lower(), "E %s GPa · %s MPa · rotura %s kJ/m² a lo largo" % [Js.to_fixed(float(k.e_gpa), 2), Js.to_fixed(float(k.sigma_mpa), 0), Js.to_fixed(float(k.j_long), 1)], String(k.quality), String(k.source)))
	for id: String in CareData.TOOL_IDS:
		var t: Dictionary = CareData.TOOLS[id]
		match String(t.kind):
			"lima":
				var el := "%s dientes por cm" % Js.to_fixed(float(t.teeth_cm), 0) if String(t.element) == "diente" else "grano de %s µm" % Js.to_fixed(float(t.grain_um), 0)
				out.append(_val(String(t.name), "%s · %s HV" % [el, grouped(float(t.tool_hv))], String(t.quality), String(t.source)))
			"torno":
				var steps: Array = t.rpm_steps
				var speeds: Array = steps.map(func(r: float) -> String: return "%s rpm → %s m/s" % [grouped(r), Js.to_fixed(ClawCare.surface_speed_ms(float(t.drum_mm), r), 1)])
				out.append(_val(String(t.name), "tambor de %s mm · %s · grano de %s µm" % [Js.to_fixed(float(t.drum_mm), 1), " · ".join(speeds), Js.to_fixed(float(t.grain_um), 0)], String(t.quality), String(t.source)))
			"cortaunas":
				out.append(_val(String(t.name), "cabe una garra de hasta %s mm · cuña de %s mm" % [Js.to_fixed(float(t.jaw_mm), 1), Js.to_fixed(float(t.wedge_mm), 1)], String(t.quality), String(t.source)))
	var th: Dictionary = CareData.THERMAL
	out.append(_val("Umbral del dolor por calor", "%s °C%s" % [Js.to_fixed(float(th.pain_c.value), 0), _band(th.pain_c, 0)], String(th.pain_c.quality), String(th.pain_c.source)))
	out.append(_val("La carne viva, al empezar", "%s °C" % Js.to_fixed(float(th.bed_c.value), 0), String(th.bed_c.quality), String(th.bed_c.source)))
	out.append(_val("Lesión por calor", "a 50 °C en %s s · a 60 °C en %s s" % [_injury_s(50.0), _injury_s(60.0)], "secondary", CareData.SRC_MORITZ))
	out.append(_val("Calor del roce que entra en la garra", "%s%s" % [Js.to_fixed(float(th.partition.value), 2), _band(th.partition, 2)], String(th.partition.quality), String(th.partition.source)))
	out.append(_val("Fricción del tambor", "μ = %s%s" % [Js.to_fixed(float(th.friction.value), 3), _band(th.friction, 2)], String(th.friction.quality), String(th.friction.source)))
	out.append(_val("Difusividad de la queratina", "%s mm²/s%s" % [Js.to_fixed(float(th.diffusivity_m2_s.value) * 1.0e6, 2), _band_scaled(th.diffusivity_m2_s, 1.0e6, 2)], String(th.diffusivity_m2_s.quality), String(th.diffusivity_m2_s.source)))
	var hm: Dictionary = CareData.HEMOSTASIS
	out.append(_val("Hemostasia con polvo y presión", "%s s" % Js.to_fixed(float(hm.agent_s.value), 0), String(hm.agent_s.quality), String(hm.agent_s.source)))
	out.append(_val("Hemostasia solo con presión", "%s s%s" % [Js.to_fixed(float(hm.pressure_s.value), 0), _band(hm.pressure_s, 0)], String(hm.pressure_s.quality), String(hm.pressure_s.source)))
	out.append(_val("Sin hemostasia", "%s s" % Js.to_fixed(float(hm.none_s.value), 0), String(hm.none_s.quality), String(hm.none_s.source)))
	var mg: Dictionary = CareData.MARGINS
	out.append(_val("Márgenes del informe", "punta de ×%s a ×%s la natural · faceta a ±%s° · queda un %s %% del sobrante" % [Js.to_fixed(float(mg.tip_ratio_lo), 1), Js.to_fixed(float(mg.tip_ratio_hi), 1), Js.to_fixed(float(mg.facet_deg), 0), Js.to_fixed(float(mg.overgrowth_left) * 100.0, 0)], "estimate", String(mg.source)))
	return out


static func _val(label: String, value: String, quality: String, source: String) -> Dictionary:
	return { "label": label, "value": value, "quality": quality, "quality_text": String(QUALITY_TEXT.get(quality, "")), "source": short_source(source) }


static func _band(e: Dictionary, digits: int) -> String:
	if e.has("min") and e.has("max") and float(e.min) != float(e.max):
		return " (de %s a %s)" % [Js.to_fixed(float(e.min), digits), Js.to_fixed(float(e.max), digits)]
	return ""


static func _band_scaled(e: Dictionary, k: float, digits: int) -> String:
	if e.has("min") and e.has("max") and float(e.min) != float(e.max):
		return " (de %s a %s)" % [Js.to_fixed(float(e.min) * k, digits), Js.to_fixed(float(e.max) * k, digits)]
	return ""


## Segundos hasta la lesión a una temperatura de la tabla (Moritz y Henriques 1947).
static func _injury_s(c: float) -> String:
	for row: Array in CareData.INJURY_TABLE:
		if float(row[0]) == c:
			return Js.to_fixed(float(row[1]), 0)
	return "—"


## La mano: { tool, gesture, name, force_n, angle_deg, mode («de frente» o faceta), rotary_on, rpm, drum_ms, active,
## closing (0-1 del cortaúñas), contact }.
func hand_view() -> Dictionary:
	var g := gesture()
	var closing := 0.0
	if not _gesture.is_empty() and String(_gesture.kind) == "corte":
		closing = clampf(float(_gesture.closing) / CLIP_CLOSE_S, 0.0, 1.0)
	return {
		"tool": tool, "gesture": g, "name": String(tool_data(tool).get("name", "")) if tool != "" else "",
		"force_n": force_n, "angle_deg": angle_deg, "frontal": angle_deg >= ClawCare.TRUNCATE_DEG,
		"force_t": force_to_t(force_n), "force_text": "%s N" % Format.fmt_f(force_n),
		"angle_text": "%s°" % Js.to_fixed(angle_deg, 0) + (" (de frente)" if angle_deg >= ClawCare.TRUNCATE_DEG else ""),
		"rpm_text": "%s rpm" % grouped(rpm()), "drum_text": "%s m/s" % Js.to_fixed(drum_speed_ms(), 1),
		"rotary_on": rotary_on and is_rotary(tool), "rotary": is_rotary(tool), "rotary_tool": rotary_tool(), "rpm": rpm(),
		"rpm_index": rpm_index, "rpm_count": rpm_steps_of(rotary_tool()).size(), "drum_ms": drum_speed_ms(),
		"active": not _gesture.is_empty(), "closing": closing, "contact_s": float(_gesture.get("s", -1.0)),
		"zone": String(_gesture.get("zone", "")),
		# cómo va la herramienta de la mano (unidad 5l): {} si no es de limar; worn, si conviene cambiarla por una nueva
		"wear": _wear_of(tool), "worn": String(_wear_of(tool).get("state", "")) == "gastada",
	}


## Cómo va una herramienta del ensayo (ClawCareKit.state) o {} si no se gasta.
func _wear_of(id: String) -> Dictionary:
	var t := CareData.tool(id)
	return kit.state(t) if Kit.wears(t) else {}


## La bandeja: [{ id, short, name, gesture, key, held, suggested, wear (cómo va, si se gasta), state }].
func tray_view(suggest: String = "") -> Array:
	var how := _file_how()
	# la vista la pide en cada fotograma: solo se rehace si cambia la mano, la sugerida, el desgaste o el «cómo»
	var mk := [tool, suggest, kit.serial, how]
	if mk == _tray_key:
		return _tray_cache
	var out: Array = []
	# las guías de la bandeja solo cambian con la presión y el ángulo (el «cómo» de las limas): hechas una vez por «cómo»
	if how != _guide_how:
		_guide_how = how
		_guides = {}
		for t: Dictionary in TRAY:
			_guides[String(t.id)] = tool_guide_text(String(t.id), how)
	for t: Dictionary in TRAY:
		var id := String(t.id)
		var w := _wear_of(id)
		out.append({ "id": id, "short": String(t.short), "name": String(tool_data(id).get("name", t.short)),
			"gesture": String(t.gesture), "key": int(t.key), "held": id == tool, "suggested": id == suggest,
			"wear": w, "state": String(w.get("state", "")),
			# para qué sirve y en qué orden (petición 51, «las limas, claras»)
			"role": String(TOOL_GUIDE[id][0]) if TOOL_GUIDE.has(id) else "", "order": int(TOOL_GUIDE[id][1]) if TOOL_GUIDE.has(id) else 0,
			"guide": String(_guides[id]) })
	_tray_key = mk
	_tray_cache = out
	return out


## Los últimos sucesos del ensayo, con la fuente legible.
func events_view(sn: Dictionary) -> Array:
	var ev: Array = sn.events
	var out: Array = []
	for i in range(maxi(ev.size() - EVENTS_SHOWN, 0), ev.size()):
		var e: Dictionary = ev[i]
		out.append({ "code": String(e.code), "message": String(e.message), "source": String(e.source),
			"source_short": short_source(String(e.source)), "time": _clock(float(e.t_s)) })
	out.reverse()
	return out


## Lecturas: [{ id, label, value, note, tone («bien» | «aviso» | «mal» | «») }].
func readouts(sn: Dictionary, revealed: bool) -> Array:
	var out: Array = []
	var c: Dictionary = sn.claw
	var tip: Dictionary = sn.tip
	var th: Dictionary = sn.thermal
	var bl: Dictionary = sn.bleeding
	var an: Dictionary = sn.animal
	var L := float(c.lengthMm)
	var nat := float(c.naturalMm)
	out.append(_row("largo", "Largo", "%s mm" % Js.to_fixed(L, 1), "natural %s mm" % Js.to_fixed(nat, 1), ""))
	var left := float(c.overgrowthLeftMm)
	var left_txt := "%s mm de más" % Js.to_fixed(left, 1) if left > 0.05 else ("a su largo" if left > -0.05 else "%s mm más corta" % Js.to_fixed(-left, 1))
	out.append(_row("sobrante", "Sobrante", left_txt, "empezó con %s mm de más" % Js.to_fixed(float(c.startMm) - nat, 1), "aviso" if left > 0.1 * maxf(float(c.startMm) - nat, 0.0) else "bien"))
	if is_reforged():
		out.append(_row("carne", "Carne viva", "no tiene", "garra reforjada de %s" % String(Catalog.find_by_id(Catalog.INLAYS, String(setup.inlay)).name).to_lower(), ""))
	elif revealed:
		var cover := float(sn.claw.quickCoverMm)
		out.append(_row("carne", "Carne viva", "a %s mm de la punta" % Js.to_fixed(cover, 1), "se ve a trasluz" if bool(c.quickVisible) else "revelada al terminar", "mal" if cover <= 0.0 else ("aviso" if cover < 1.0 else "bien")))
	else:
		var band := quick_band_mm()
		var sign := "¡el centro del corte se oscurece: para!" if bool(c.sign) else "garra oscura: no se ve"
		out.append(_row("carne", "Carne viva", sign, "en la población acaba entre %s y %s mm desde la base" % [Js.to_fixed(float(band[0]), 1), Js.to_fixed(float(band[1]), 1)], "aviso" if bool(c.sign) else ""))
	var ratio := float(tip.ratio)
	out.append(_row("punta", "Punta", "%s µm" % Js.to_fixed(float(tip.tipRadiusUm), 0), "natural %s µm · ×%s" % [Js.to_fixed(float(tip.naturalUm), 0), Js.to_fixed(ratio, 2)], "aviso" if ratio > float(CareData.MARGINS.tip_ratio_hi) or ratio < float(CareData.MARGINS.tip_ratio_lo) else "bien"))
	var facet := float(tip.facetDeg)
	out.append(_row("faceta", "Faceta", "%s°" % Js.to_fixed(facet, 0) if facet > 0.0 else "sin faceta", "la garra: %s°" % Js.to_fixed(float(tip.naturalAlphaDeg), 0), "bien" if facet <= 0.0 or absf(facet - float(tip.naturalAlphaDeg)) <= float(CareData.MARGINS.facet_deg) else "aviso"))
	if tip.strengthRatio != null:
		var sr := float(tip.strengthRatio)
		out.append(_row("aguante", "Aguanta de lado", strength_words(sr), Format.fmt_small_force(float(tip.lateralN)) + " en el vértice", "mal" if sr < 0.25 else "bien"))
	if not is_reforged():
		var qc := float(th.quickC)
		var painc := float(th.painC)
		var q_note := "dolor desde %s °C" % Js.to_fixed(painc, 0)
		if bool(th.injured):
			q_note = "¡lesión por calor!"
		out.append(_row("calor", "Calor en la carne viva", "%s °C" % Js.to_fixed(qc, 1), q_note, "mal" if qc >= painc or bool(th.injured) else "bien"))
		var btxt := "no"
		var bnote := ""
		var btone := "bien"
		if bool(bl.active):
			btxt = "sangra"
			btone = "mal"
			bnote = "faltan %s s de presión" % Js.to_fixed(float(bl.needS), 0)
			if String(bl.agent) != "":
				bnote += " con %s" % String(tool_data(String(bl.agent)).get("name", "")).to_lower()
		elif bool(bl.bled):
			btxt = "ha parado"
			btone = "aviso"
		out.append(_row("sangre", "Sangre", btxt, bnote, btone))
	out.append(_row("humedad", "Humedad", String(c.humidityName), "", ""))
	out.append(_row("sujecion", "Sujeción", String(an.sedationName), "", "mal" if String(an.sedation) == "libre" or (String(sn.animal_id) != "rapaz" and not (String(an.sedation) in ["sedacion", "anestesia"])) else "bien"))
	out.append(_row("dolor", "Dolor · estrés", "%s %% · %s %%" % [Js.to_fixed(float(an.pain) * 100.0, 0), Js.to_fixed(float(an.stress) * 100.0, 0)], "índices pedagógicos · se ha movido %d veces" % int(an.moved), "mal" if float(an.pain) > 0.0 else ""))
	out.append(_row("arrancado", "Arrancado", "%s mm³" % Js.to_fixed(float(c.removedMm3), 2), "", ""))
	out.append(_row("tiempo", "Tiempo", _clock(float(sn.t_s)), "en pausa" if paused else "", ""))
	return out


static func _row(id: String, label: String, value: String, note: String, tone: String) -> Dictionary:
	return { "id": id, "label": label, "value": value, "note": note, "tone": tone }


## m:ss o s.
static func _clock(t: float) -> String:
	var s := int(floor(t))
	if s < 60:
		return "%s s" % Js.to_fixed(t, 1)
	return "%d:%02d" % [s / 60, s % 60]


## Textos de una línea: la herramienta, la mano, lo último que ha hecho y el estado.
func texts(sn: Dictionary, rep: Dictionary, revealed: bool) -> Dictionary:
	var days := float(setup.get("overgrowth_days", CareData.DEFAULT_OVERGROWTH_DAYS))
	var growth: Dictionary = CareData.ANIMALS[String(setup.animal)].growth_mm_day
	var reforged := String(setup.get("inlay", "none")) != "none"
	return {
		"tool": tool_text(), "hand": hand_text(), "action": action_text(), "status": status_text(sn),
		"overgrowth": ("Sin crecimiento de más: " + INERT_TEXT + ".") if reforged else "%s días sin desgaste: %s mm de más, a %s mm al día (%s)" % [Js.to_fixed(days, 0), Js.to_fixed(float(sn.claw.startMm) - float(sn.claw.naturalMm), 1), Js.to_fixed(float(growth.value), 2), short_source(String(growth.source))],
		"overgrowth_days": "no crece" if reforged else "%s días" % Js.to_fixed(days, 0),
		"tip_start": tip_start_text(),
		"verdict": String(rep.verdictText), "grade": String(rep.gradeText),
		"quick": ("La carne viva acaba a %s mm de la base: %s mm por detrás de la punta." % [Js.to_fixed(float(sn.claw.quickMm), 1), Js.to_fixed(float(sn.claw.quickCoverMm), 1)]) if revealed and sn.claw.quickMm != null else "",
	}


func tool_text() -> String:
	if tool == "":
		return "Sin herramienta: coge una de la bandeja (clic o teclas 1-5)."
	var d := tool_data(tool)
	var nm := String(d.get("name", tool))
	# cómo va (unidad 5l): usada o gastada, con el radio de sus filos
	var wear := _wear_text(tool)
	match String(d.get("kind", "")):
		"lima":
			# para qué sirve, en qué orden y cómo se usa (petición 51)
			var role := (" · %s" % String(ROLE_NAMES[String(TOOL_GUIDE[tool][0])])) if TOOL_GUIDE.has(tool) else ""
			if String(d.get("element", "")) == "diente":
				return "%s%s: %s dientes por cm, acero de ~%s HV. Arrastra a lo largo de la garra, de la base a la punta.%s" % [nm, role, Js.to_fixed(float(d.teeth_cm), 0), Js.to_fixed(float(d.tool_hv), 0), wear]
			return "%s%s: grano de %s µm, de ~%s HV. Arrastra a lo largo de la garra, de la base a la punta.%s" % [nm, role, Js.to_fixed(float(d.grain_um), 0), Js.to_fixed(float(d.tool_hv), 0), wear]
		"torno":
			var on_txt := ("encendida" if rotary_on else "apagada") if tool == "amoladora" else ("encendido" if rotary_on else "apagado")
			var guard := " · protector a %s°" % Js.to_fixed(float(d.guard_deg), 0) if d.has("guard_deg") else ""
			return "%s: %s · %s rpm, tambor de Ø%s mm a %s m/s%s.%s" % [nm, on_txt, Js.to_fixed(rpm(), 0), Js.to_fixed(float(d.drum_mm), 1), Js.to_fixed(drum_speed_ms(), 1), guard, wear]
		"cortaunas":
			return "%s: cabe una garra de hasta %s mm. Mantén pulsado para cerrarlo." % [nm, Js.to_fixed(float(d.jaw_mm), 0)]
		"hemostatico":
			return "%s: aprieta sobre la herida." % nm
		"presion":
			return "%s: aprieta sobre la herida (sin hemostático, de 5 a 10 minutos)." % nm
		"agua":
			return "%s: toca la garra para remojarla." % nm
	return "%s: toca la garra para ponerlo." % nm


## Cómo va una herramienta de limar, en una frase que se añade a su texto («» nueva): usada, con el radio de sus filos, o
## gastada (embotada la lima, vidriado el grano), con la tecla para cambiarla por una nueva.
func _wear_text(id: String) -> String:
	var w := _wear_of(id)
	match String(w.get("state", "")):
		"usada":
			return " Usada: filos de %s µm (nueva, %s)." % [Js.to_fixed(float(w.edgeUm), 1), Js.to_fixed(float(w.edgeNewUm), 0)]
		"gastada":
			return " %s: filos de %s µm; corta mucho menos. Una nueva: tecla N." % [String(w.word).capitalize(), Js.to_fixed(float(w.edgeUm), 1)]
	return ""


## Un volumen arrancado en una pasada (mm³), para leer: con tres decimales y, si no llega a una milésima pero no es cero,
## con dos cifras significativas (la lima de diamante arranca ~0,0006 mm³ del zafiro: «0.000» parecería que nada).
static func fmt_mm3(v: float) -> String:
	if not (v > 0.0) or v >= 0.001:
		return Js.to_fixed(maxf(v, 0.0), 3)
	return Js.to_fixed(v, clampi(int(ceil(-V8.js_log10(v))) + 1, 4, 8))


## Un volumen arrancado con su unidad: en mm³ (fmt_mm3) y, por debajo de una diezmilésima, en µm³ enteros (la lima de diamante
## fina arranca ~0,000008 mm³ del zafiro en una pasada: «8300 µm³» se lee; «0.0000083 mm³», no).
static func fmt_vol(v: float) -> String:
	if v > 0.0 and v < 1e-4:
		return "%s µm³" % Js.to_fixed(v * 1e9, 0)
	return "%s mm³" % fmt_mm3(v)


func hand_text() -> String:
	var mode := "de frente" if angle_deg >= ClawCare.TRUNCATE_DEG else "faceta de %s°" % Js.to_fixed(angle_deg, 0)
	return "Presión %s N · ángulo %s° (%s)" % [Format.fmt_f(force_n), Js.to_fixed(angle_deg, 0), mode]


## Lo último que se ha hecho, en palabras (con la zona y la dirección de la pasada).
func action_text() -> String:
	if _last_action.is_empty():
		return ""
	var a := _last_action
	var r: Dictionary = a.get("result", {})
	var p: Dictionary = a.get("params", {})
	match String(a.kind):
		"file":
			# levantada la herramienta, la pasada entera en una línea (petición 51): lo que ha quitado, la superficie y lo que falta
			if _gesture.is_empty() and not _passes.is_empty():
				return pass_summary(_passes[0])
			var where := "la punta" if String(p.zone) == "punta" else "el flanco a %s mm de la punta" % Js.to_fixed(float(p.at_mm), 1)
			var dir := String({ "a_favor": "de la base a la punta", "en_contra": "en contra de las capas", "vaiven": "en vaivén" }.get(String(p.get("direction", "a_favor")), ""))
			if bool(r.get("noBite", false)):
				# por qué no muerde y qué coger en su lugar (petición 51), con la potencia si gira y roza (unidad 5l)
				return no_bite_text(String(p.tool), care.apex_mm() - float(p.get("at_mm", 0.0)), float(r.get("heatW", 0.0)))
			var verb := String({ "torno": "Torno en", "amoladora": "Amoladora en" }.get(String(p.tool), "Limando"))
			return "%s %s, %s: %s fuera." % [verb, where, dir, fmt_vol(float(r.get("removedMm3", 0.0)))]
		"clip":
			if not bool(r.get("cut", false)):
				return "No corta: %s." % String(r.get("reason", ""))
			return "Corte de %s mm%s." % [Js.to_fixed(float(p.remove_mm), 1), "; grieta de %s mm" % Js.to_fixed(float(r.splitMm), 1) if float(r.get("splitMm", 0.0)) > 0.0 else ""]
		"hemostasis":
			if bool(r.get("stopped", false)):
				return "Ha dejado de sangrar."
			return "Presión %s: %s de %s s. Sigue apretando sobre la herida (con el reloj ×10, diez veces antes)." % [
				"con el polvo" if bool(r.get("agent", false)) else "con la gasa", Js.to_fixed(float(r.get("doneS", 0.0)), 0),
				Js.to_fixed(float(r.get("goalS", 0.0)), 0)]
		"apply":
			return "%s puesto." % String(tool_data(String(p.tool)).get("name", ""))
		"remojar":
			return "Garra remojada."
		"probe":
			return String(r.get("text", ""))
	return ""


func status_text(sn: Dictionary) -> String:
	if finished:
		return "Terminado: informe y carne viva a la vista."
	if paused:
		return "En pausa (Espacio para seguir)."
	if bool(sn.bleeding.active):
		return "¡Sangra! Hemostático y presión."
	return ""
