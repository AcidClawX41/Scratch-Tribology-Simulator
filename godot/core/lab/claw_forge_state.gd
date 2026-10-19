## Tribología biológica · reforja experimental: el estado del «Laboratorio experimental (reforja)» de la cetrería
## (unidad 5f), sin nodos y determinista, de la misma familia que ClawCareState.
##
## Guarda el proceso (lo que se fabrica: una de las 10 recetas del horno, una piedra comprada, el acrílico dental de la
## prótesis de verdad de una garra rota o, en la ficción, recubrir la garra viva), la forma de la funda (petición 35: capuchón, funda, funda larga o prótesis entera, y la pared), la balanza
## (los gramos de cada polvo en su plato), los mandos del horno (los ocho de ClawForge.controls(), con sus pasos), la
## marcha del horno (una animación a cámara rápida de lo que el motor ya ha decidido), los ajustes del taller (la muela, la
## barrera, el recubrimiento, el adhesivo, el pulido y la carga), el tutorial (el general del horno o el de cada proceso,
## de claw_forge_tutorial.gd) y el error que hay que explicar. Convierte cada gesto de la escena 3D y de la página en la
## llamada de ClawForge que le toca y da todos los textos con números (con Js y Format): la escena y la interfaz solo
## pintan (CONTRATOS.md: la física, en core/). La física es la de ClawForge; aquí solo se reparten el tiempo de las
## animaciones y los textos. El color de lo caliente sale de incandescence.gd (cuerpo negro), no de la escena.
##
## Gestos (los manda la escena o la página; ver forge_runner.gd):
##   pick_jar(id) · set_pouring(on, fine) · add_powder(id, g) · clear_pan() · load_crucible()    la balanza y el crisol
##   insert_charge()                                                                              meter la carga en su máquina
##   turn_control(id, pasos, fine) · set_control(id, valor) · select_control(id)                  los mandos del horno
##   set_speed(i) · cycle_speed(k)                                                                la velocidad (×60…×36 000)
##   start() · skip() · cool_piece() · choose_stone(id)                                          el horno
##   make_wax() · invest() · divest() · set_compensate(on)                                       la cera perdida
##   set_carve_tool(id) · cycle_carve_tool(k) · carve_pass(suave)                                 el tallado por pasadas
##   protect() · coat() · polish() · fit_test()                                                  el taller
##   tick(dt)                                                                                     el tiempo (animaciones)
## La marcha del horno (5m): start() solo arranca con la carga metida en la máquina del modo (si no, dice por qué); llama a
## fire() (o a heat(), con el modo «calentar» y una pieza dentro, o a burnout(), con el molde de la cera perdida dentro) una
## vez, y el resultado ya está decidido. La marcha dura el tiempo de verdad (el del dial, o el del ciclo del quemado) entre la
## velocidad elegida, con topes de unos segundos y unos minutos, y el reloj enseña lo que lleva y lo que falta de verdad:
## primero sube la temperatura (la rampa es dibujo: el motor no modela la cinética), luego el tiempo del proceso corre de 0 a
## time_s y lo que crece se lee con el ritmo de la receta (growth: mm/h, mg/h o µm/h), el mismo cálculo que evaluate_fire. La
## velocidad se puede cambiar con la marcha en curso: lo que sale no cambia.
## Desde la 5m (petición 43) el laboratorio acaba en la funda terminada y sin pegar, con la prueba del ajuste: pegarla y
## probarla con la carga son de la cetrería (bond() y check() siguen aquí para ella y para los tests).
## Uso: var st := ClawForgeState.new({ "animal": "rapaz", "claw": "aguila" }); st.set_process("zafiro"); st.add_powder(…)
##      var v := st.view()   # todo lo que pintan la escena y la página
extends RefCounted

const ClawForge = preload("res://core/lab/claw_forge.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ForgeTutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const CareState = preload("res://core/lab/claw_care_state.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Data = preload("res://core/lab/data.gd")
const Incandescence = preload("res://core/lab/incandescence.gd")
const ClawOptics = preload("res://core/lab/claw_optics.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")

const GENERAL := ForgeTutorial.GENERAL
const STONE := ForgeTutorial.STONE
const LIVE := ForgeTutorial.LIVE
## La prótesis de verdad de una garra rota (unidad 5j): el acrílico dental, que se mezcla aquí y se lima en la cetrería.
const ACRYLIC := ForgeTutorial.ACRYLIC
## Soldar piezas de metal de la funda en la mesa de soldar (unidad 5r; petición 44): un tutorial sobre la pieza de ahora.
const WELD := ForgeTutorial.WELD
## Lo que se puede fabricar: las recetas del horno, una piedra comprada y (ficción) recubrir la garra viva.
const PROCESSES := ["zafiro", "rubi", "metal_duro", "alumina", "acero", "oro", "titanio", "vidrio", "diamante_hpht", "diamante_cvd", ACRYLIC, STONE, LIVE]
## Los tutoriales, en el orden del selector: el general del horno y uno por proceso.
const TUTORIALS := [GENERAL, "zafiro", "rubi", "metal_duro", "alumina", "acero", "oro", "titanio", "vidrio", "diamante_hpht", "diamante_cvd", ACRYLIC, STONE, LIVE, WELD]
## Las piedras que se compran (las del tutorial de la piedra comprada).
const STONES := ["cuarzo", "circonita", "moissanita", "hematites", "swarovski"]
## La forma de la funda o de la prótesis (petición 35: «garras y formas nuevas»): cuánto de la garra cubre desde la punta
## (fracción de su largo) y lo que hace cada una. Son elecciones del ensayo, no datos: con ellas el motor calcula la funda
## (sheath_geometry), lo que hay que crecer o tallar, su masa y si cabe en el cristal del método.
const SHAPES := [
	{ "id": "capuchon", "name": "Capuchón de la punta", "cover_frac": 0.2, "what": "Solo la punta: el más ligero y el que menos superficie tiene para pegarse." },
	{ "id": "funda", "name": "Funda", "cover_frac": 0.4, "what": "La de serie: el 40 % de la garra desde la punta, como una corona dental." },
	{ "id": "funda_larga", "name": "Funda larga", "cover_frac": 0.7, "what": "Casi toda la garra: más superficie pegada, pero el cristal del que sale es más grande." },
	{ "id": "protesis", "name": "Prótesis entera", "cover_frac": 1.0, "what": "Toda la garra: la que se hace cuando la garra se ha roto, pegada en frío sobre lo que queda." },
]
## El espesor de la pared de la funda (mm): elección del ensayo.
const WALLS := [
	{ "id": "fina", "name": "Pared fina", "mm": 0.5, "what": "Más ligera, pero un borde fino se desconcha antes al tallarlo (la fuerza crece con la pared elevada a 1,5)." },
	{ "id": "normal", "name": "Pared normal", "mm": 1.0, "what": "La de serie: 1 mm, como una corona dental." },
	{ "id": "gruesa", "name": "Pared gruesa", "mm": 2.0, "what": "Aguanta más al tallarla, pero pesa más y pide un cristal más gordo." },
]
## Pasos de los mandos (elección de la interfaz): la temperatura de 25 en 25 °C (de 5 en 5 con Mayús), el tiempo y la
## presión en valores redondos (de 0 a 1000 h y de 0 a 6 GPa) y el metano de 0,5 en 0,5 % (de 0,1 en 0,1 con Mayús).
const TEMP_STEP := 25.0
const TEMP_FINE := 5.0
const TIME_STEPS := [0.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1200.0, 1800.0, 2700.0, 3600.0, 5400.0, 7200.0, 10800.0, 14400.0, 21600.0, 28800.0, 36000.0, 43200.0, 57600.0, 72000.0, 86400.0, 129600.0, 172800.0, 259200.0, 345600.0, 432000.0, 604800.0, 864000.0, 1209600.0, 1728000.0, 2160000.0, 2592000.0, 3600000.0]
const PRESSURE_STEPS := [0.0, 0.001, 0.01, 0.02, 0.05, 0.101, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0, 500.0, 1000.0, 2000.0, 3000.0, 4000.0, 4500.0, 5000.0, 5250.0, 5500.0, 5750.0, 6000.0]
const METHANE_STEP := 0.5
const METHANE_FINE := 0.1
## Los mandos en el orden del panel (A/D los recorren).
const CONTROL_IDS := ["modo", "temp_c", "time_s", "pressure_mpa", "atmosphere", "methane", "mold", "cool"]
## Cómo se ven en el panel: diales (de valor), selectores (de opciones).
const DIALS := ["temp_c", "time_s", "pressure_mpa", "methane"]
## Los mandos al encender la página: el horno frío.
const DIAL_DEFAULTS := { "modo": "calentar", "temp_c": 20.0, "time_s": 0.0, "pressure_mpa": 0.101, "atmosphere": "aire", "methane": 0.0, "mold": "yeso", "cool": "aire" }
## Lo que vierte en la balanza un tarro que no va en la receta (g/s) y las dosis de los botones sin objetivo (g). Elección de la
## interfaz.
const POUR_G_S := 4.0
const DOSES := [10.0, 1.0, 0.1]
## Las potencias de diez de las dosis de un polvo con objetivo (g), de la mayor a la menor (5w).
const DOSE_TENS := [100.0, 10.0, 1.0, 0.1, 0.01, 0.001, 0.0001]
## 5w · un tarro de la receta vierte a un ritmo que llena su objetivo en POUR_FILL_S (lo que pide una funda va de miligramos a
## decenas de gramos: a 4 g/s no se podían pesar los miligramos de MgO); gota a gota, POUR_FINE_DIV veces más despacio. Los
## botones de dosis de cada polvo van con su objetivo: la potencia de diez que cabe en él, una décima y una centésima (nunca
## menos de lo que distingue la balanza). Elecciones de la interfaz.
const POUR_FILL_S := 2.0
const POUR_FINE_DIV := 40.0
## Lo que cabe en el plato de la balanza (g): una balanza de laboratorio de 200 g (elección de la interfaz).
const PAN_MAX_G := 200.0
## 5m · el tiempo de verdad a la velocidad elegida: la marcha dura el tiempo de verdad entre la velocidad (×60, ×600, ×3600,
## ×36 000; 0 es «lo más rápido»), con topes de unos segundos y unos minutos (s reales); lo mismo las pasadas del tallado y los
## pasos con su tiempo de verdad (el fraguado, el enfriado, desmoldar). Elección de la interfaz, no datos.
const SPEEDS := [60.0, 600.0, 3600.0, 36000.0, 0.0]
const SPEED_NAMES := ["×60", "×600", "×3600", "×36 000", "Lo más rápido"]
const DEFAULT_SPEED := 2
const RUN_MIN_S := 3.0
const RUN_MAX_S := 150.0
const ACT_MIN_S := 0.8
const ACT_MAX_S := 20.0
## La rampa de subida de la marcha (fracción de lo que dura la marcha). Dibujo.
const RAMP_FRAC := 0.18
## Lo que dura la colada al final de una marcha de fundir (s), meter la carga en su máquina y cerrarla (s) y el resto de
## animaciones del taller (s). Dibujo.
const POUR_S := 1.2
const INSERT_S := 1.4
const ACT_S := { "cool_agua": 1.6, "cool_aceite": 1.8, "cool_aire": 4.0, "cool_horno": 5.0, "carve": 3.0, "protect": 1.0, "coat": 2.5, "bond": 1.6, "polish": 2.4, "check": 1.6, "choose": 0.8, "insert": INSERT_S, "wax": 1.6, "invest": 2.0, "divest": 1.8, "pass": 2.0, "fit": 1.4 }
## Las herramientas del tallado por pasadas, en el orden del selector (la pulidora pule: polish()).
const CARVE_TOOLS := ForgeData.CARVE_TOOL_IDS
## Qué corre en el reloj (5m), en palabras: la marcha de cada máquina y las animaciones del taller con su tiempo de verdad.
const RUN_WORDS := {
	"verneuil": "El soplete de Verneuil", "hpht": "La prensa", "cvd": "El reactor de plasma", "sinterizado": "El sinterizado",
	"induccion": "La bobina de inducción", "colada": "Fundir y colar", "calentar": "Calentar", "quemado": "El quemado de la cera",
}
const ACT_WORDS := { "cool": "Enfriar", "invest": "El fraguado del revestimiento", "divest": "Esperar para desmoldar", "pass": "La pasada", "coat": "Recubrir" }
## Dónde se trabaja la pieza con cada herramienta del tallado (para la escena): la sierra, la máquina de muelas o el eje flexible.
const TOOL_AT := { "sierra": "sierra", "muela_gruesa": "muela", "muela_fina": "muela", "fresa": "fresa", "pulidora": "pulidora" }
## 5r · la mesa de soldar: al colocar las piezas a ojo quedan desalineadas esto (elección del juego: más que lo que admite la
## junta, para que haya que alinearlas); lo que mueve cada paso de «Alinear» con el teclado; el tope de la desalineación.
const WELD_PLACE_MM := 0.3
const WELD_NUDGE_MM := 0.05
const WELD_OFFSET_MAX_MM := 0.6
## Los mandos de la mesa de soldar que se ven (el id, el nombre, la unidad y los decimales), por método.
const WELD_CONTROLS := {
	"laser": [["energy_j", "Energía por pulso", "J", 0], ["pulse_ms", "Duración del pulso", "ms", 1], ["spot_mm", "Diámetro del punto", "mm", 1]],
	"tig": [["current_a", "Corriente", "A", 0], ["tig_ms", "Duración del pulso", "ms", 1]],
	"braze": [["temp_c", "Temperatura del soplete", "°C", 0], ["gap_mm", "Holgura de la junta", "mm", 3]],
}
## La segunda pieza que se suelda a la funda (la punta): los metales y el metal duro de la reforja.
const WELD_TIP_IDS := ["acero", "oro", "titanio", "tungsteno"]
## Temperatura del taller (°C).
const ROOM_C := ClawForge.ROOM_C
## Efectos que se guardan para la escena (los últimos) y sucesos que se enseñan.
const FX_LOG := 24
const EVENTS_SHOWN := 6
## Las etapas del proceso, con su nombre (ClawForge.STAGES).
const STAGE_NAMES := {
	"material": "Elegir el material", "horno": "El horno", "enfriar": "Enfriar", "tallar": "Tallar la funda",
	"proteger": "Proteger la carne viva", "recubrir": "Recubrir", "unir": "Pegar en frío", "pulir": "Pulir",
	"comprobar": "Probar con la carga", "hecho": "Terminada",
}
## Qué se ilumina en la escena y en la página en cada paso del tutorial (por el id del paso de claw_forge_tutorial.gd).
const STEP_HIGHLIGHT := {
	"horno": "horno", "mando_modo": "modo", "mando_temp_c": "temp_c", "mando_time_s": "time_s", "mando_atmosphere": "atmosphere",
	"mando_pressure_mpa": "pressure_mpa", "mando_methane": "methane", "mando_mold": "mold", "mando_cool": "cool", "regla": "garra",
	"pesar": "balanza", "cargar": "crisol", "modo": "modo", "parametros": "arrancar", "vigilar": "ventana", "enfriar": "sacar",
	"comprobar_pieza": "pieza", "tallar": "muela", "proteger": "barrera", "recubrir": "pistola", "unir": "adhesivo",
	"pulir": "pulidora", "probar": "carga", "elegir": "tienda", "no_calentar": "horno", "ficcion": "garra", "frio": "pistola",
	"poco": "garra", "real": "garra", "sangre": "garra", "mezclar": "acrilico", "pasar": "garra", "rehacer": "garra",
	"meter": "puerta", "maquinas": "puerta", "reloj": "horno", "cera": "cera", "revestir": "cera", "quemar": "puerta",
	"romper": "pieza", "tocho": "sierra", "cortar_bebedero": "sierra", "desbastar": "muela", "vaciar": "fresa", "forma": "muela",
	"limar": "muela", "repasar": "muela", "ajuste": "garra",
	"ojos": "soldadura", "preparar": "soldadura", "alinear": "soldadura", "soldar": "soldadura", "limar_costura": "muela", "pulir_soldada": "pulidora",
}
## Qué mando se usa en cada paso (el ratón, el dedo o las teclas): presentación, no pasos nuevos.
const STEP_CONTROLS := {
	"horno": "Vista «Horno» (tecla V): el panel de mandos está debajo de la puerta con su ventanilla (vista «Dentro»: lo que pasa dentro).",
	"mando_modo": "Arrastra el selector del modo (o clic para pasar de uno a otro); teclado: A/D hasta el modo y W/S para girarlo.",
	"mando_temp_c": "Arrastra el dial de la temperatura arriba o abajo (la franja verde es el margen de la receta); W/S de 25 en 25 °C, con Mayús de 5 en 5.",
	"mando_time_s": "Arrastra el dial del tiempo; W/S salta de un valor redondo al siguiente (de minutos a días).",
	"mando_atmosphere": "Clic en el selector de la atmósfera para pasar de una a otra (aire, argón, vacío, hidrógeno con metano).",
	"mando_pressure_mpa": "Arrastra el dial de la presión; W/S de un valor redondo al siguiente (de 0 a 6 GPa).",
	"mando_methane": "Arrastra el dial del metano (solo cuenta en la CVD); W/S de 0,5 en 0,5 %.",
	"mando_mold": "Clic en el selector del molde (solo cuenta al fundir y colar).",
	"mando_cool": "Clic en el selector de cómo se enfría; luego el botón «Sacar y enfriar» (tecla E). El reloj enseña lo que tarda de verdad en poder cogerse.",
	"regla": "Vista «Taller» (tecla V): la garra en su soporte, con la carne viva marcada.",
	"pesar": "Clic en un tarro para cogerlo y mantén pulsado sobre el plato para verter (Mayús: gota a gota), o los botones de dosis de cada polvo en «La balanza y el crisol»; Z pone la pantalla a cero (tara) para pesar el siguiente desde cero. Cuando la balanza diga «Listo», «Cargar el crisol» (tecla L) o un clic en el crisol.",
	"cargar": "Clic en el crisol, junto a la balanza, o «Cargar el crisol» (tecla L).",
	"modo": "En la tarjeta «El horno», la opción de la receta en «Modo»; o, en la vista, clic en el selector del modo hasta ella (teclado: A/D hasta «Modo» y W/S). Está hecho en cuanto el selector la marca.",
	"parametros": "Arrastra cada dial (o A/D para elegirlo y W/S para girarlo; Mayús, el paso fino) hasta que quede en su franja verde (el del tiempo, en la marca que dice el paso), elige la velocidad junto al reloj (tecla X) y pulsa el botón rojo «Arrancar» (tecla Intro).",
	"vigilar": "Vista «Horno» o «Dentro» (tecla V); el reloj dice lo que lleva y lo que falta de verdad; X cambia la velocidad y Espacio pasa al final de la marcha.",
	"enfriar": "El selector «Enfriar» y el botón «Sacar y enfriar» (tecla E).",
	"comprobar_pieza": "Vista «La pieza» (tecla V): el acabado y el color; las lecturas dicen qué ha salido. Luego «Siguiente» (tecla N).",
	"tallar": "Elige la muela en «Taller» y clic en la muela de la mesa (tecla T). Siempre con agua.",
	"proteger": "Elige la barrera y clic sobre la mitad de la garra con carne viva (tecla B).",
	"recubrir": "Elige el recubrimiento en «Taller» y clic en la pistola (tecla R).",
	"unir": "Elige el adhesivo y la holgura y clic en la jeringa (tecla U).",
	"pulir": "Elige el abrasivo y el grano y clic en la pulidora (tecla O, o la herramienta «Pulidora» y T).",
	"probar": "Clic en la pesa, junto a la garra (tecla K).",
	"elegir": "Elige la piedra en «Qué quieres hacer» y clic en la caja de las piedras (tecla L).",
	"no_calentar": "Para verlo: el selector del modo en «Calentar», la piedra dentro (tecla M) y «Arrancar» (Intro).",
	"ficcion": "Vista «Taller» (tecla V): la garra del animal, con la carne viva marcada.",
	"frio": "En «Taller», el recubrimiento «Alúmina por proyección de plasma».",
	"poco": "En «Taller», el tiempo y cuánto de la garra se cubre desde la punta.",
	"real": "Vista «Taller» (tecla V): la garra rota, con lo que queda de ella.",
	"sangre": "Botón «Trabajo veterinario», arriba: en la cetrería, el hemostático y presión sobre la herida; luego vuelve aquí.",
	"mezclar": "Clic en el estuche del acrílico, en la mesa de la balanza, o «Mezclar el acrílico» (tecla L).",
	"pasar": "El botón «Pasar a la cetrería», en la ficha de la garra.",
	"rehacer": "En la cetrería, el reloj del animal: la garra crece por debajo de la prótesis.",
	"meter": "Arrastra el crisol (o el molde, o la pieza) hasta la puerta del horno, o un clic en la puerta; tecla M. La puerta se cierra sola.",
	"maquinas": "Vista «Dentro» (tecla V): cada máquina con su sitio para la carga.",
	"reloj": "El selector de la velocidad junto al reloj (tecla X): se puede cambiar con la marcha en curso.",
	"cera": "Primero el selector «Molde» del horno (clic en él, o en la tarjeta «El horno»); luego, en «La cera perdida», el botón «Modelo de cera» (tecla C), con «Cera a la medida» encendido: compensa la contracción.",
	"revestir": "Con el selector «Molde» en el de la receta, el botón «Revestir» de «La cera perdida» (tecla C, otra vez).",
	"quemar": "El modo «Calentar», el molde dentro (M), la temperatura y el tiempo de arriba, y «Arrancar» (Intro).",
	"romper": "El botón «Romper el molde» (tecla C, otra vez, con el molde frío).",
	"tocho": "La herramienta «Sierra» (tecla G) y una pasada (T) por cada corte, o un clic en la sierra por corte.",
	"cortar_bebedero": "La herramienta «Sierra» (tecla G) y una pasada (T), o un clic en la sierra.",
	"desbastar": "La herramienta «Muela gruesa» (tecla G) y pasadas (T; Mayús + T, una suave), o un clic en la máquina de muelas.",
	"vaciar": "La herramienta «Fresa» (tecla G) y pasadas (T), o un clic en el eje flexible.",
	"forma": "La herramienta «Muela fina» (tecla G) y pasadas (T; Mayús + T, una suave) hasta la silueta: mira el indicador de la forma.",
	"limar": "La herramienta «Muela fina» (tecla G) y pasadas (T; Mayús + T, una suave) hasta la silueta.",
	"repasar": "La herramienta «Muela fina» (tecla G) y una pasada (T).",
	"ajuste": "El botón «Probar el ajuste» (tecla U), con la holgura del adhesivo que se usará.",
	"ojos": "Vista «Soldar» (tecla V): la mesa de soldar, con el microscopio y su filtro; la pantalla está junto al aparato.",
	"preparar": "En «La mesa de soldar»: el método (tecla F pasa al siguiente), la pieza que se suelda, sus mandos y el gas; luego «Colocar en la mesa» (tecla Q) o un clic en el aparato.",
	"alinear": "Arrastra la punta a los lados en la vista hasta que la junta quede dentro, o el botón «Alinear» (tecla I).",
	"soldar": "Aprieta sobre la costura y recorre la vuelta con el ratón (o el dedo); la barra dice cuántos puntos lleva. Teclado: J da un punto en el primer tramo sin soldar (mantenla pulsada para seguir).",
	"limar_costura": "La herramienta «Muela fina» (tecla G) y pasadas (T; Mayús + T, una suave) hasta la silueta.",
	"pulir_soldada": "Elige el abrasivo y el grano y clic en la pulidora (tecla O).",
}
## Qué paso del tutorial arregla cada acción que sale mal (acción del motor → id del paso del proceso).
const MISTAKE_STEP := {
	"mix": "pesar", "fire": "parametros", "heat": "no_calentar", "cool": "enfriar", "carve": "tallar", "protect": "proteger",
	"coat": "recubrir", "bond": "unir", "polish": "pulir", "check_load": "probar", "choose": "elegir",
	"load_machine": "meter", "arrancar": "meter", "wax": "cera", "invest": "revestir", "burnout": "quemar", "divest": "romper",
	"fit": "ajuste", "carve_pass": "forma",
	"weld_setup": "preparar", "weld_align": "alinear", "weld_pulse": "soldar", "weld_finish": "soldar",
}
## El paso que arregla una pasada que sale mal, por herramienta (y lo colado o lo sinterizado, por el suyo).
const PASS_STEP := { "sierra": "tocho", "muela_gruesa": "desbastar", "fresa": "vaciar", "muela_fina": "forma" }
## Qué comprueba cada condición del tutorial, en palabras.
const CHECK_WORDS := {
	"mezcla_ok": "la mezcla del crisol es la de la receta",
	"modo_ok": "el selector del modo está en el de la receta",
	"parametros_ok": "la marcha ha arrancado con cada mando en su margen",
	"pieza_ok": "hay una pieza buena",
	"enfriada": "la pieza se ha enfriado sin grietas",
	"tallada": "la funda está tallada",
	"muela_adecuada": "la muela muerde la pieza",
	"protegida": "la carne viva está tapada con una barrera",
	"recubierta": "el recubrimiento ha agarrado",
	"unida": "la funda está pegada",
	"pulida": "la superficie está pulida",
	"comprobada": "la unión aguanta la carga del animal",
	"sin_quemar": "la garra no se ha quemado",
	"dentro": "la carga está dentro de la máquina del modo de la receta",
	"cera": "el modelo de cera de la garra está hecho",
	"revestido": "la cera está revestida",
	"quemada": "la cera se ha quemado del todo",
	"desmoldada": "la pieza está fuera del molde",
	"tocho": "la sierra ha hecho sus cortes",
	"desbastada": "lo que sobra ya es para la muela fina",
	"vaciada": "la funda está hueca por dentro",
	"ajuste": "la funda entra en la garra con la holgura de un adhesivo",
	"soldadura_lista": "las piezas están en la mesa con un método que las une",
	"alineada": "las piezas están alineadas dentro de lo que admite la junta",
	"soldada": "la costura está entera y la unión ha salido",
	"costura_limada": "el cordón de la soldadura está limado hasta la silueta",
}
## Calidad de un dato, en palabras (las de la cetrería y la ficción).
const QUALITY_TEXT := { "primary": "dato medido", "secondary": "dato de un caso parecido", "estimate": "estimación", "ficcion": "ficción (película)", "dibujo": "dibujo" }
## Nombres cortos de las fuentes de la reforja y del color del calor (el texto completo va en la ayuda): [cita, nombre].
const SOURCE_NAMES := [
	# 5r · las fuentes de la mesa de soldar (las más largas primero: el ordenamiento de _init lo garantiza)
	[ClawWeld.SRC_BRAZE_WC, "las plaquitas de metal duro (AMS 4763, General Carbide y Amada 2016)"],
	[ClawWeld.SRC_NO_WELD, "lo que no se suelda (Kakkar et al. y las fichas de las gemas)"],
	[ClawWeld.SRC_GAS_FACTORS, "lo que aguanta la unión (Watanabe y Topham 2006; Li et al. 2005; Amada 2016; estimaciones)"],
	[ClawWeld.SRC_COUPLING, "lo que funde del pulso (estimación calibrada con la W150G y Baba y Watanabe 2005)"],
	[ClawWeld.SRC_AMADA, "Amada 2016, Laser Welding Fundamentals"],
	[ClawWeld.SRC_BABA, "Baba y Watanabe 2005"],
	[ClawWeld.SRC_WATANABE, "Watanabe y Topham 2006"],
	[ClawWeld.SRC_LI, "Li et al. 2005"],
	[ClawWeld.SRC_W150G, "ficha de la W150G (Han's Laser)"],
	[ClawWeld.SRC_PUK, "ficha del PUK 6 (Lampert)"],
	[ClawWeld.SRC_DUPONT, "DuPont y Marder 1995"],
	[ClawWeld.SRC_CRC_FUSION, "CRC Handbook (2014), entalpías de fusión"],
	[ClawWeld.SRC_ABSORB, "absorción del 1064 nm (estimación)"],
	[ClawWeld.SRC_HAZ, "la zona afectada por el calor (Incropera; estimación)"],
	[ClawWeld.SRC_PERFORATION, "la pared perforada (regla del modelo)"],
	[ClawWeld.SRC_POROSITY, "los poros del ojo de cerradura (Amada 2016; estimación)"],
	[ClawWeld.SRC_TIG_SPOT, "el punto del micro-TIG (Lampert; DuPont y Marder 1995)"],
	[ClawWeld.SRC_BRAZE_GAP, "la holgura de la plata (AWS y Lucas-Milhaupt; estimación)"],
	[ClawWeld.SRC_BRAZE_TAU, "lo que aguanta la plata (estimación)"],
	[ClawWeld.SRC_PACE, "lo que tarda cada punto (Lampert; elección del juego)"],
	[ForgeData.SRC_ITS90, "ITS-90"],
	[ForgeData.SRC_CRC, "CRC Handbook (2014)"],
	[ForgeData.SRC_AK304, "AK Steel, ficha del acero 304"],
	[ForgeData.SRC_TI_CAST, "colada del titanio (Chan et al. 2008)"],
	[ForgeData.SRC_ALPHA_CASE, "Chan et al. 2008 (capa alfa del titanio)"],
	[ForgeData.SRC_GC_GUIDE, "General Carbide, guía del metal duro"],
	[ForgeData.SRC_GOODFELLOW_WC, "Goodfellow (WC-Co)"],
	[ForgeData.SRC_WC_SINTER, "Fernandes y Senos 2011"],
	[ForgeData.SRC_ABRISA, "Abrisa (vidrio sodocálcico)"],
	[ForgeData.SRC_EN572, "EN 572-1"],
	[ForgeData.SRC_BULLSEYE, "Bullseye Glass, Tip Sheet 8"],
	[ForgeData.SRC_QUARTZ_INV, "Johnson et al. 2021 (inversión del cuarzo)"],
	[ForgeData.SRC_TYDEX_QUARTZ, "Tydex (cuarzo)"],
	[ForgeData.SRC_CORNING_7980, "Corning HPFS 7980"],
	[ForgeData.SRC_NASSAU_CZ, "Nassau 1981 (circonita)"],
	[ForgeData.SRC_YSZ, "Hayashi et al. 2005 (circonia)"],
	[ForgeData.SRC_SG_SAPPHIRE, "Saint-Gobain (zafiro)"],
	[ForgeData.SRC_HEXOLOY, "Saint-Gobain, Hexoloy SA"],
	[ForgeData.SRC_SIC_PVT, "JXT Semi; Nassau et al. 1997 (moissanita)"],
	[ForgeData.SRC_SIC_DISSOC, "GRAYSTAR (carburo de silicio)"],
	[ForgeData.SRC_DIAMOND_OX, "KAPP 2006; Glass Phys. Chem. 2024"],
	[ForgeData.SRC_DIAMOND_VACUUM, "Khmelnitsky y Gippius 2014"],
	[ForgeData.SRC_KAPP, "KAPP 2006 (diamante o CBN)"],
	[ForgeData.SRC_BALMER, "Balmer et al. 2009"],
	[ForgeData.SRC_KENNEDY, "Kennedy y Kennedy 1976"],
	[ForgeData.SRC_SUMIYA, "Sumiya et al. 2002"],
	[ForgeData.SRC_YAN, "Yan et al. 2002"],
	[ForgeData.SRC_COBLE, "Coble, patente US 3.026.210"],
	[ForgeData.SRC_COORSTEK, "CoorsTek AD-995"],
	[ForgeData.SRC_VERNEUIL, "Scheel 2000; The Gemology Project; Nassau 1980 (Verneuil)"],
	[ForgeData.SRC_RUBY_CR, "Roditi; How Products Are Made (rubí)"],
	[ForgeData.SRC_GANOKSIN, "Ganoksin (colada del oro)"],
	[ForgeData.SRC_GYPSUM, "Ganoksin (revestimiento de yeso)"],
	[ForgeData.SRC_STEEL_POUR, "CastingQuality (colada del CF8)"],
	[ForgeData.SRC_ENAMEL, "Andrews 1961 (esmalte vítreo)"],
	[ForgeData.SRC_GRONER, "Groner et al. 2004 (ALD)"],
	[ForgeData.SRC_BALINIT_A, "Oerlikon Balzers, BALINIT A"],
	[ForgeData.SRC_ISO14577, "ISO 14577"],
	[ForgeData.SRC_APS, "Mater. Charact. 2010; Mater. Des. 2004 (plasma)"],
	[ForgeData.SRC_SCHNEIDER, "Schneider et al. 1997"],
	[ForgeData.SRC_AMORPHOUS_AL2O3, "Surf. Coat. Technol. 2001 (alúmina amorfa)"],
	[ForgeData.SRC_MORGAN, "Morgan Technical Ceramics"],
	[ForgeData.SRC_GROSSMANN, "Grossmann (severidad del temple)"],
	[ForgeData.SRC_HARD_CHROME, "NEWMOA 2003; U.S. Chrome (cromo duro)"],
	[ForgeData.SRC_ELECTROFORMING, "Gateros Plating"],
	[ForgeData.SRC_BRAZING, "SAE AMS 4763"],
	[ForgeData.SRC_INCROPERA, "Incropera et al. 2007"],
	[ForgeData.SRC_KINGERY, "Kingery 1955"],
	[ForgeData.SRC_MANSON, "Manson 1966 (Lu y Fleck 1998)"],
	[ForgeData.SRC_CHAI_LAWN, "Chai y Lawn 2007"],
	[ForgeData.SRC_BIFANO, "Bifano et al. 1991"],
	[ForgeData.SRC_LOCTITE_401, "Henkel, LOCTITE 401"],
	[ForgeData.SRC_LOCTITE_GUIDE, "Henkel, guías de LOCTITE"],
	[ForgeData.SRC_FERREIRA, "Ferreira et al. 2024 (herraduras pegadas)"],
	[ForgeData.SRC_SHINETSU, "Shin-Etsu; AZoM (silicona)"],
	[ForgeData.SRC_PYROGEL, "Aspen Aerogels, Pyrogel XTE"],
	[ForgeData.SRC_WATER, "Incropera et al. 2007 (agua)"],
	[ForgeData.SRC_IRON_REACTIVE, "KAPP 2006; Komanduri y Shaw 1975; US 4.505.720"],
	[ForgeData.SRC_ABRASIVES, "durezas de los abrasivos del taller"],
	[ForgeData.SRC_DMT, "DMT (diamante)"],
	[ForgeData.SRC_FILE_TEST, "HolzWerken 2024 (prueba de la lima)"],
	[ForgeData.SRC_LAPIDARY, "práctica de lapidario (regla del modelo)"],
	[ForgeData.SRC_SAMOUR_REPAIR, "Samour 2006 (las reparaciones del pico)"],
	[ForgeData.SRC_MATTA, "Matta et al. 2022 (prótesis de acrílico del pico)"],
	[ForgeData.SRC_ZAFAR_PMMA, "Zafar 2020 (el PMMA de las prótesis)"],
	[ForgeData.SRC_ALQUTAIBI, "Alqutaibi et al. 2023"],
	[ForgeData.SRC_ISO20795, "ISO 20795-1"],
	[ForgeData.SRC_ASSAEL_PMMA, "Assael et al. 2005"],
	[ForgeData.SRC_NIST_PMMA, "NIST WebBook (PMMA)"],
	[ForgeData.SRC_NIST_DIAMOND, "NIST WebBook (diamante)"],
	[ForgeData.SRC_JANAF, "NIST-JANAF (Chase 1998)"],
	[ForgeData.SRC_CRC_CP, "CRC Handbook (2014)"],
	[ForgeData.SRC_ASM_TI2, "ASM, titanio de grado 2"],
	[ForgeData.SRC_HYPERION_WC, "Hyperion (metal duro)"],
	[ForgeData.SRC_KERR, "Kerr 2011 (la cera perdida)"],
	[ForgeData.SRC_SHOR, "Shor (revestimiento de fosfato)"],
	[ForgeData.SRC_SRS, "SRS-Goodwin (temperaturas de colada)"],
	[ForgeData.SRC_BULLSEYE_TS8, "Bullseye Glass, TipSheet 8 (el vidrio a la cera perdida)"],
	[ForgeData.SRC_HOLLENBACK, "Hollenback y Skinner 1946 (lo que encoge el oro)"],
	[ForgeData.SRC_FERREIRA_TI, "Ferreira et al. 2007 (lo que encoge el titanio)"],
	[ForgeData.SRC_HSU, "Hsu et al. 2007 (revestimiento de fosfato)"],
	[ForgeData.SRC_EARNSHAW, "Earnshaw 1988 (revestimiento de yeso)"],
	[ForgeData.SRC_CAMPBELL, "Campbell y Harding 1994 (el bebedero)"],
	[ForgeData.SRC_SABAU, "Sabau y Cannell 2005 (la cera a la medida)"],
	[ForgeData.SRC_GENIE, "Diamond Pacific, Genie (las muelas)"],
	[ForgeData.SRC_HITECH_SAW, "Hi-Tech Diamond (la sierra)"],
	[ForgeData.SRC_FOREDOM, "Foredom (el eje flexible)"],
	[ForgeData.SRC_HAEFELI, "Haefeli (los granos del diamante)"],
	[ForgeData.SRC_DOP, "guías de lapidario (el palo y su cera)"],
	[ForgeData.SRC_FUSED_CAST, "US 4.943.398 (alúmina electrofundida)"],
	[ForgeData.FURNACE.source, "FICCIÓN: el horno que lo junta todo (cada modo es una máquina real)"],
	[Incandescence.SRC_PLANCK, "Planck (CODATA 2018)"],
	[Incandescence.SRC_CIE, "CIE 1931 (Wyman et al. 2013)"],
	[Incandescence.SRC_SRGB, "IEC 61966-2-1 (sRGB)"],
	[Incandescence.SRC_TM9237, "TM 9-237, tabla V"],
	[Incandescence.SRC_DRAPER, "Draper 1847"],
]

var forge: ClawForge
## Ajustes: animal, claw, paw, digit (de qué pata y garra viene, para volver), broken (viene rota), humidity.
var setup: Dictionary = {}
var process := "zafiro"
var stone := "moissanita"
var shape := "funda"
var wall := "normal"
## La balanza: gramos de cada polvo en el plato; lo cargado en el crisol (la última mezcla); el tarro en la mano.
var pan: Dictionary = {}
## 5w · la tara: lo que había en el plato al poner la balanza a cero (la pantalla enseña lo de encima).
var tare_g := 0.0
var loaded: Dictionary = {}
var held_jar := ""
var pouring := false
var pour_fine := false
## Los mandos del horno (el metano en %, como en el dial; el motor lo recibe en fracción).
var dial: Dictionary = {}
var selected_control := "modo"
## La marcha del horno (vacío si no ha arrancado): { kind, t, dur, temp_c, time_s, ok, defect, visual, loop, heat, poured }.
var run: Dictionary = {}
## La animación del taller o del enfriado que corre ahora: { kind, t, dur, medium, ok, defect }.
var act: Dictionary = {}
## Ajustes del taller (los argumentos de cada llamada).
var carve_p := { "abrasive": "diamante", "grain_um": 45.0, "force_n": 10.0, "speed_ms": 20.0, "coolant": true }
var barrier_p := { "barrier": "aerogel", "thickness_mm": 3.0 }
var coat_p := { "method": "plasma_alumina", "target": "funda", "time_s": 30.0, "cycles": 300.0, "cover_mm": -1.0 }
var bond_p := { "adhesive": "epoxi", "gap_mm": 0.15 }
var polish_p := { "abrasive": "diamante", "grain_um": 9.0, "sharpen": false }
var load_n := -1.0
## 5r · la mesa de soldar: el método y sus mandos (los de ClawWeld.METHODS.controls, con tig_ms para el micro-TIG), la
## segunda pieza, el gas y el solape; lo que están desalineadas las piezas (la persona lo corrige); el pedal (el ratón o
## el dedo apretados sobre la costura) y dónde apunta el haz (0-1 a lo largo de la costura; −1, fuera); el reloj del pedal.
var weld_p := { "method": "laser", "part": "punta", "material": "", "energy_j": 12.0, "pulse_ms": 4.0, "spot_mm": 0.6, "current_a": 150.0, "tig_ms": 8.0, "gas": "argon", "overlap": "resistencia", "temp_c": 700.0, "gap_mm": 0.04 }
var weld_offset_mm := 0.0
var weld_hold := false
var weld_u := -1.0
var _weld_since := 1.0e9
var _weld_bench := false
## La receta que espera el segundo clic de choose_process («» ninguna).
var _confirm_process := ""
var _weld_last: Dictionary = {}
## 5m · la velocidad de la marcha (índice de SPEEDS), la herramienta del tallado por pasadas, la cera a la medida de la
## contracción (la casilla «Cera a la medida») y el aviso de lo último que no se ha podido hacer (arrancar sin la carga dentro).
var speed_i := DEFAULT_SPEED
var carve_tool := "sierra"
var compensate := true
var notice := ""
## Tutorial: el que se sigue (GENERAL o un proceso) y su paso.
var tutorial_on := true
var tut_id := GENERAL
var tut_step := 0
## 5w · los pasos que se han saltado solos al llegar a ellos porque ya se cumplían (en palabras; «» si ninguno).
var tut_skipped := ""
## Llamadas a ClawForge desde el último reinicio de la pieza: [método, argumentos]. Con ellas, otra ClawForge llega a la
## misma pieza (los tests lo comprueban: el estado no hace física por su cuenta).
var calls: Array = []
## El último resultado de cada acción (para los textos).
var last: Dictionary = {}
var last_action := ""

var _serial := 0
var _fx: Array = []
var _fx_n := 0
var _mistake: Dictionary = {}
var _prev_check := {}
var _done := {}
var _names: Array = []
var _ramp: Array = []
var _start_claw: Dictionary = {}
var _steps_cache: Array = []
var _steps_key := ""
var _card_cache: Dictionary = {}
var _sn: Dictionary = {}
var _sn_key := ""
var _plan_cache: Dictionary = {}
var _plan_key := ""
var _feas: Dictionary = {}
var _feas_key := ""
var _live: Dictionary = {}
var _profile: Dictionary = {}
var _short_cache := {}
var _readable_cache := {}
## La garra con la que se abrió el laboratorio (open): si se vuelve a abrir con la misma, sigue la pieza que había.
var _open_key := ""
## «Valores y fuentes» de la pieza de ahora (values_table), rehecha solo cuando cambia lo que enseña.
var _values: Array = []
var _values_key := ""
## Lo que enseña el reloj (5m): «run» (la marcha) o «act» (la animación del taller con su tiempo de verdad); «» al empezar.
var _clock := ""
## La última llamada del tallado por pasadas («carve_pass» o «carve_to»), para sus textos.
var _pass_method := ""


func _init(p: Dictionary = {}) -> void:
	_names = SOURCE_NAMES.duplicate()
	_names.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	dial = DIAL_DEFAULTS.duplicate(true)
	open(p)


# ════════════════════════════════ Ajustes ════════════════════════════════

## Abre el laboratorio con una garra: { animal, claw, paw, digit, broken, humidity, process, shape, profile, from_care }.
## Una garra rota llega con la forma «Prótesis entera» y from_care (los ajustes de su ClawCare con stump_mm, lo que queda
## de ella: ClawCareState.reforge_request), y vuelve a la cetrería como un bloque en bruto (ClawForge.care_setup(from_care),
## petición 35).
func open(p: Dictionary = {}) -> void:
	var s := setup.duplicate(true)
	# otra garra sin perfil propio ni garra rota: no se queda con los de la garra rota de antes
	if p.has("claw") or p.has("animal"):
		for key: String in ["profile", "from_care"]:
			if not p.has(key):
				s.erase(key)
	s.merge(p, true)
	var aid := String(s.get("animal", "rapaz"))
	if not CareData.ANIMALS.has(aid):
		aid = "rapaz"
	var a: Dictionary = CareData.ANIMALS[aid]
	if not (a.claws as Array).has(String(s.get("claw", ""))):
		s["claw"] = String(a.claw)
	s["animal"] = aid
	s["broken"] = bool(s.get("broken", false))
	var hum := String(s.get("humidity", "natural"))
	s["humidity"] = hum if CareData.KERATIN.has(hum) else "natural"
	setup = s
	# la misma garra otra vez (se vuelve a la cetrería a parar la sangre y se regresa): sigue la pieza que había, con la
	# receta y la forma que se eligieron
	var fc: Dictionary = s.get("from_care", {})
	var key := "%s|%s|%s|%s|%s|%s|%s" % [aid, String(s.claw), String(s.get("paw", "")), String(s.get("digit", "")), str(bool(s.broken)),
		var_to_str(fc.get("stump_mm", -1.0)), String(s.humidity)]
	var same := forge != null and key == _open_key
	_open_key = key
	if p.has("process") and PROCESSES.has(String(p.process)):
		process = String(p.process)
	if p.has("shape") and _find(SHAPES, String(p.shape)) != null:
		shape = String(p.shape)
	elif bool(s.broken) and p.has("broken") and not same:
		shape = "protesis"
	if same and not p.has("process") and not p.has("shape"):
		_touch()
		return
	_rebuild()


## Lo que se fabrica: una receta, «piedra» o «garra_viva». Empieza una pieza nueva y pone su tutorial.
func set_process(id: String) -> void:
	if not PROCESSES.has(id) or id == process:
		return
	process = id
	_rebuild()
	tut_id = id
	_reset_tutorial()


## Elegir otra receta desde «Qué quieres hacer»: con una pieza empezada (ya sacada del horno, con el horno en marcha o con una
## costura a medias en la mesa de soldar), el primer clic solo avisa de que la pieza de ahora se pierde y el segundo en la misma receta
## la cambia; sin nada empezado, la cambia a la primera. set_process sigue cambiándola sin preguntar (tutoriales, encargos).
func choose_process(id: String) -> void:
	if not PROCESSES.has(id) or id == process:
		_confirm_process = ""
		return
	var busy := String(snap().piece.get("material", "")) != "" or running() or weld_in_progress()
	if busy and _confirm_process != id:
		_confirm_process = id
		notice = "Pulsa otra vez «%s» para empezar esa pieza: la de ahora (%s, %s) se pierde." % [String(ForgeTutorial.PROCESS_NAMES.get(id, id)), String(ForgeTutorial.PROCESS_NAMES.get(process, process)), String(STAGE_NAMES.get(forge.stage(), forge.stage())).to_lower()]
		_touch()
		return
	_confirm_process = ""
	notice = ""
	set_process(id)


## La forma de la funda (SHAPES) o el espesor de su pared (WALLS): otra funda, una pieza nueva.
func set_shape(id: String) -> void:
	if _find(SHAPES, id) == null or id == shape:
		return
	shape = id
	_rebuild()


func set_wall(id: String) -> void:
	if _find(WALLS, id) == null or id == wall:
		return
	wall = id
	_rebuild()


## La piedra que se compra (STONES).
func set_stone(id: String) -> void:
	if STONES.has(id) and id != stone:
		stone = id
		_touch()


## Empieza otra pieza igual (los mandos se quedan como estaban).
func restart() -> void:
	_rebuild()


## Una ClawForge nueva con el proceso, la forma y la garra de ahora: la de su dedo y su pata y, si llega rota, lo que queda
## de ella (stump_mm de from_care: la prótesis es maciza en lo que falta y se pega sobre el muñón; unidad 5j).
func _rebuild() -> void:
	var cfg := { "animal": String(setup.animal), "claw": String(setup.claw), "humidity": String(setup.humidity),
		"recipe": process if ForgeData.RECIPES.has(process) else "", "wall_mm": wall_mm(),
		"cover_frac": float(_find(SHAPES, shape).cover_frac), "digit": String(setup.get("digit", "")), "paw": String(setup.get("paw", "")) }
	var fc: Dictionary = setup.get("from_care", {})
	if fc.has("stump_mm"):
		cfg["stump_mm"] = float(fc.stump_mm)
	forge = ClawForge.new(cfg)
	calls = []
	last = {}
	last_action = ""
	run = {}
	act = {}
	# 5w · lo pesado ya se cargó en el crisol de la pieza de antes: la nueva empieza con el plato vacío (con otra forma, aquellos
	# gramos ya no eran los de esta funda y la balanza pedía quitarlos)
	if not loaded.is_empty():
		pan = {}
		tare_g = 0.0
	loaded = {}
	_mistake = {}
	notice = ""
	_clock = ""
	_pass_method = ""
	weld_hold = false
	weld_u = -1.0
	_weld_bench = false
	_weld_last = {}
	_start_claw = forge.result_claw()
	_live = forge.live_paths()
	_profile = _claw_profile()
	if process == LIVE:
		coat_p["target"] = "garra_viva"
	elif String(coat_p.target) == "garra_viva":
		coat_p["target"] = "funda"
	_steps_key = ""
	# 5w · una pieza nueva («Otra pieza», otra forma, otra pared u otra garra) empieza su tutorial por el primer paso: antes se
	# quedaba en el paso de la pieza de antes («Enfriar», «Desbastar»…), que con la pieza nueva, sin pesar, no se cumplía nunca.
	# La soldadura pide una pieza hecha: vuelve al tutorial de la receta.
	if tut_id == process or tut_id == WELD:
		var was := tut_step
		tut_id = process
		_reset_tutorial()
		if was > 0:
			notice = "Pieza nueva: el tutorial vuelve a su primer paso."
	_seed_checks()
	_touch()


## La forma de la garra para dibujarla, la de la cetrería (el perfil de ClawCare de la garra sana de su dedo y su pata, con
## su curva y su carne viva) o, si la garra llega rota de la cetrería, el perfil que trae (solo dibujo: la funda la calcula
## el motor, con lo que queda de ella). nat_s y nat_r: el perfil de la garra sana, el que sigue la funda o la prótesis (que
## rehace lo que falta). { s, r, core, nat_s, nat_r, natural_mm, curve, base_r_mm, quick_mm, quick_cover_mm, color, broken }.
func _claw_profile() -> Dictionary:
	var care := ClawCare.new({ "animal": String(setup.animal), "claw": String(setup.claw), "digit": String(setup.get("digit", "")),
		"paw": String(setup.get("paw", "")), "overgrowth_days": 0.0 })
	var sn := care.snapshot()
	var prof: Dictionary = sn.profile
	var out := { "s": prof.s, "r": prof.r, "core": prof.core, "nat_s": prof.s, "nat_r": prof.r, "natural_mm": float(sn.claw.naturalMm),
		"curve": float(sn.claw.curve), "base_r_mm": float(sn.claw.baseRadiusMm), "quick_mm": sn.claw.quickMm,
		"quick_cover_mm": sn.claw.quickCoverMm, "color": String(sn.claw.color), "broken": false }
	var given: Dictionary = setup.get("profile", {})
	if given.has("s") and given.has("r") and (given.s as PackedFloat64Array).size() >= 2:
		out["s"] = given.s
		out["r"] = given.r
		if given.has("core"):
			out["core"] = given.core
		out["broken"] = bool(setup.get("broken", false))
	return out


## La forma de la garra para la escena (claw_profile) y las dos vías del calor hasta la carne viva (ClawForge.live_paths):
## se calculan al empezar cada pieza.
func claw_profile() -> Dictionary:
	return _profile


## Espesor de la pared elegida (mm).
func wall_mm() -> float:
	return float(_find(WALLS, wall).mm)


## La instantánea de ClawForge, una sola vez por cambio de la pieza (la escena y la página la leen muchas veces por vista;
## no se modifica).
func snap() -> Dictionary:
	var key := "%d|%d" % [forge.get_instance_id(), forge.serial()]
	if key != _sn_key:
		_sn_key = key
		_sn = forge.snapshot()
	return _sn


static func _find(list: Array, id: String) -> Variant:
	for e: Dictionary in list:
		if String(e.id) == id:
			return e
	return null


func _call(method: String, args: Variant) -> Variant:
	calls.append([method, args.duplicate(true) if args is Dictionary else args])
	var r: Variant = forge.callv(method, [args])
	last[method] = r
	last_action = method
	return r


# ════════════════════════════════ La balanza y el crisol ════════════════════════════════

## Coge un tarro (o lo deja, si ya estaba en la mano).
func pick_jar(id: String) -> void:
	if not ForgeData.POWDERS.has(id):
		return
	held_jar = "" if held_jar == id else id
	pouring = false
	_touch()


func drop_jar() -> void:
	if held_jar != "" or pouring:
		held_jar = ""
		pouring = false
		_touch()


## Verter el tarro de la mano en el plato (mientras se mantiene sobre la balanza): fine, gota a gota.
func set_pouring(on: bool, fine := false) -> void:
	var p := on and held_jar != ""
	if p != pouring or fine != pour_fine:
		pouring = p
		pour_fine = fine
		_touch()


## Añade (o quita, con g < 0) gramos de un polvo al plato; nunca menos de 0 ni más de lo que cabe. Quitar solo se puede con
## ese polvo solo en el plato (vuelve al tarro con la espátula): con otros, ya están mezclados y no se separan (5w).
func add_powder(id: String, grams: float) -> void:
	if not ForgeData.POWDERS.has(id):
		return
	if grams < 0.0 and _mixed_with_others(id):
		notice = "Ya está mezclado con otros polvos en el plato y no se separa: compensa con los otros o vacía el plato (Retroceso)."
		_touch()
		return
	var now := float(pan.get(id, 0.0))
	var room := PAN_MAX_G - pan_total() + now
	var g := clampf(now + grams, 0.0, maxf(room, 0.0))
	if g <= 1e-9:
		pan.erase(id)
	else:
		pan[id] = g
	if tare_g > pan_total():
		tare_g = 0.0
	_touch()


func _mixed_with_others(id: String) -> bool:
	for k: String in pan:
		if k != id and float(pan[k]) > 0.0:
			return true
	return false


func clear_pan() -> void:
	if not pan.is_empty() or tare_g > 0.0:
		pan = {}
		tare_g = 0.0
		pouring = false
		_touch()


## Z · la tara: pone la pantalla de la balanza a cero con lo que hay en el plato, para pesar el polvo siguiente desde cero.
func tare() -> void:
	tare_g = pan_total()
	_touch()


func pan_total() -> float:
	var t := 0.0
	for k: String in pan:
		t += float(pan[k])
	return t


## Lo que vierte un tarro por segundo (5w): el de la receta llena su objetivo en POUR_FILL_S; los demás, POUR_G_S.
func pour_rate(id: String, fine := false) -> float:
	var tg := 0.0
	for p: Dictionary in _plan().get("powders", []):
		if String(p.id) == id:
			tg = float(p.targetG)
	var rate := clampf(tg / POUR_FILL_S, float(ForgeData.MIX_PLAN.readability_g.value), POUR_G_S) if tg > 0.0 else POUR_G_S
	return rate / POUR_FINE_DIV if fine else rate


## Las dosis de los botones de un polvo (g): la potencia de diez que cabe en su objetivo, una décima y una centésima, sin bajar
## de lo que distingue la balanza; sin objetivo, las de siempre.
func doses_for(id: String) -> Array:
	var tg := 0.0
	for p: Dictionary in _plan().get("powders", []):
		if String(p.id) == id:
			tg = float(p.targetG)
	if tg <= 0.0:
		return DOSES.duplicate()
	var rd := float(ForgeData.MIX_PLAN.readability_g.value)
	# 5w · las potencias de diez escritas (sin pow ni log de la libm, que no dan lo mismo en todas las plataformas)
	var i := 0
	while i < DOSE_TENS.size() - 1 and float(DOSE_TENS[i]) > tg * (1.0 + 1e-9):
		i += 1
	var out: Array = []
	for k in 3:
		out.append(maxf(float(DOSE_TENS[mini(i + k, DOSE_TENS.size() - 1)]), rd))
	return out


## Lo que pide la pieza de ahora (ClawForge.mix_plan), una vez por cambio de la pieza.
func _plan() -> Dictionary:
	var key := "%d|%d" % [forge.get_instance_id(), forge.serial()]
	if key != _plan_key:
		_plan_key = key
		_plan_cache = forge.mix_plan() if ForgeData.RECIPES.has(process) else {}
	return _plan_cache


## 5w · ¿Sale esta receta con esta garra y esta forma? Con lo que recomienda la receta, el motor (evaluate_fire) dice si el
## cristal no cabe en la máquina (la bola de Verneuil, el cristal HPHT); además, la carga tiene que caber en la balanza y el tiempo
## que pide la funda, en el dial. { ok, text (por qué no y qué probar; «» si sale) }. Antes se descubría al final de la marcha,
## sin salida: el tiempo al máximo del dial seguía dando «no ha dado tiempo».
func feasibility() -> Dictionary:
	if not ForgeData.RECIPES.has(process):
		return { "ok": true, "text": "" }
	var key := "%d|%d" % [forge.get_instance_id(), forge.serial()]
	if key == _feas_key:
		return _feas
	_feas_key = key
	var plan := _plan()
	var rec := ForgeData.recipe(process)
	var why := ""
	if float(plan.get("minG", 0.0)) > PAN_MAX_G:
		why = "La carga pesa al menos %s y en la balanza caben %s." % [fmt_g(float(plan.minG)), fmt_g(PAN_MAX_G)]
	else:
		var r := forge.recommended()
		var fp: Dictionary = r.fire
		var probe := ClawForge.evaluate_fire(rec, ClawForge.evaluate_mix(rec, r.mix, plan), fp, snap().sheath)
		for q: Dictionary in probe.problems:
			if String(q.code) == "tamano":
				why = String(q.text)
		var tmax := float(TIME_STEPS[TIME_STEPS.size() - 1])
		if why == "" and float(fp.time_s) > tmax:
			why = "El cristal tardaría %s de verdad en crecer y el dial del tiempo no pasa de %s." % [fmt_time(float(fp.time_s)), fmt_time(tmax)]
	_feas = { "ok": why == "", "text": "" if why == "" else "Con esta garra y esta forma no sale: %s Prueba con una funda más pequeña («Capuchón de la punta»), otra garra u otra receta." % why }
	return _feas


## Carga lo pesado en el crisol (o en el alimentador del soplete): mix() con los gramos del plato. Desde la 5w, solo si la mezcla
## está en la receta y en lo que pide la pieza (ClawForge.mix_status); si no, no carga y dice cómo se arregla.
func load_crucible() -> void:
	if process == STONE:
		choose_stone(stone)
		return
	if process == ACRYLIC:
		choose_stone(ACRYLIC)
		return
	if process == LIVE:
		return
	var ms := forge.mix_status(pan)
	if not bool(ms.ok):
		var ev: Dictionary = ms.eval
		var fix := String(ms.fix.text)
		notice = "No se carga. %s" % fix
		var pid := ""
		if not (ev.problems as Array).is_empty():
			pid = String(ev.problems[0].get("powder", ""))
		_mistake = { "action": "mix", "code": String(ev.get("defect", "mezcla")), "what": String(ev.text) if String(ev.text) != "" else fix,
			"source": String(ForgeData.POWDERS[pid].source) if ForgeData.POWDERS.has(pid) else String(ms.plan.get("source", "")), "tool": "" }
		_push_fx({ "kind": "sfx", "id": "slide" })
		_touch()
		return
	notice = ""
	var r: Dictionary = _call("mix", pan.duplicate())
	loaded = pan.duplicate()
	_after("mix", r)


## Una piedra comprada (choose): el bloque del que se talla la funda. Con «acrilico», el acrílico dental de la prótesis de
## verdad: se mezcla y queda un bloque que se lima en la cetrería (unidad 5j).
func choose_stone(id: String = "") -> void:
	if id != "" and STONES.has(id):
		stone = id
	var mid := ACRYLIC if id == ACRYLIC else stone
	var r: Dictionary = _call("choose", mid)
	_start_act("choose", {})
	_after("choose", r)


# ════════════════════════════════ Los mandos del horno ════════════════════════════════

## El mando (ForgeData.CONTROLS) por id.
static func control_data(id: String) -> Dictionary:
	for c: Dictionary in ForgeData.CONTROLS:
		if String(c.id) == id:
			return c
	return {}


## Elige el mando que mueven W/S (y el que se resalta en el panel).
func select_control(id: String) -> void:
	if CONTROL_IDS.has(id) and id != selected_control:
		selected_control = id
		_touch()


## A/D: el mando anterior o el siguiente del panel.
func cycle_control(k: int) -> void:
	var i := CONTROL_IDS.find(selected_control)
	select_control(String(CONTROL_IDS[posmod(i + k, CONTROL_IDS.size())]))


## Gira un mando k pasos (fine: el paso pequeño). Los selectores pasan de una opción a la siguiente.
func turn_control(id: String, k: int, fine := false) -> void:
	if not CONTROL_IDS.has(id) or k == 0 or running():
		return
	selected_control = id
	var c := control_data(id)
	match id:
		"temp_c":
			var st := TEMP_FINE if fine else TEMP_STEP
			var v := float(dial.temp_c)
			# a la rejilla del paso y después k pasos
			var base := floorf(v / st + 1e-9) * st if k > 0 else ceilf(v / st - 1e-9) * st
			dial["temp_c"] = clampf(base + st * float(k), float(c.min), float(c.max))
		"time_s":
			dial["time_s"] = _step_in(TIME_STEPS, float(dial.time_s), k)
		"pressure_mpa":
			dial["pressure_mpa"] = _step_in(PRESSURE_STEPS, float(dial.pressure_mpa), k)
		"methane":
			var st2 := METHANE_FINE if fine else METHANE_STEP
			var v2 := float(dial.methane)
			var b2 := floorf(v2 / st2 + 1e-9) * st2 if k > 0 else ceilf(v2 / st2 - 1e-9) * st2
			dial["methane"] = float(Js.to_fixed(clampf(b2 + st2 * float(k), float(c.min), float(c.max)), 1))
		_:
			var opts: Array = c.options
			var i := opts.find(String(dial[id]))
			dial[id] = String(opts[posmod(i + k, opts.size())])
	_after_dial()


## Pone un mando a un valor (los deslizadores de la página y lo recomendado): se ajusta a su rango y a sus opciones.
func set_control(id: String, value: Variant) -> void:
	if not CONTROL_IDS.has(id) or running():
		return
	var c := control_data(id)
	if c.has("options"):
		if not (c.options as Array).has(String(value)):
			return
		dial[id] = String(value)
	else:
		dial[id] = clampf(float(value), float(c.min), float(c.max))
	selected_control = id
	_after_dial()


## La posición 0-1 de un deslizador de un dial (el tiempo y la presión, por sus valores redondos) y su inversa.
func control_t(id: String) -> float:
	var c := control_data(id)
	match id:
		"time_s":
			return _index_t(TIME_STEPS, float(dial.time_s))
		"pressure_mpa":
			return _index_t(PRESSURE_STEPS, float(dial.pressure_mpa))
	if c.has("min"):
		return (float(dial[id]) - float(c.min)) / (float(c.max) - float(c.min))
	var opts: Array = c.options
	return float(opts.find(String(dial[id]))) / float(maxi(opts.size() - 1, 1))


## El valor de un mando para la posición t (0-1) de su deslizador.
static func control_value_at(id: String, t: float) -> Variant:
	var c := control_data(id)
	var u := clampf(t, 0.0, 1.0)
	match id:
		"time_s":
			return float(TIME_STEPS[int(round(u * float(TIME_STEPS.size() - 1)))])
		"pressure_mpa":
			return float(PRESSURE_STEPS[int(round(u * float(PRESSURE_STEPS.size() - 1)))])
		"temp_c":
			return float(c.min) + roundf(u * (float(c.max) - float(c.min)) / TEMP_FINE) * TEMP_FINE
		"methane":
			return float(Js.to_fixed(float(c.min) + u * (float(c.max) - float(c.min)), 1))
	var opts: Array = c.options
	return String(opts[int(round(u * float(opts.size() - 1)))])


## El valor siguiente de una lista redonda (k pasos desde el más cercano por debajo o por encima).
static func _step_in(list: Array, v: float, k: int) -> float:
	var i := 0
	if k > 0:
		for j in list.size():
			if float(list[j]) <= v + 1e-9:
				i = j
	else:
		i = list.size() - 1
		for j in range(list.size() - 1, -1, -1):
			if float(list[j]) >= v - 1e-9:
				i = j
	return float(list[clampi(i + k, 0, list.size() - 1)])


static func _index_t(list: Array, v: float) -> float:
	var best := 0
	for j in list.size():
		if absf(float(list[j]) - v) < absf(float(list[best]) - v):
			best = j
	return float(best) / float(list.size() - 1)


func _after_dial() -> void:
	_update_tutorial()
	_touch()


## Los argumentos de fire() con los mandos de ahora (el metano, en fracción).
func fire_params() -> Dictionary:
	return {
		"mode": String(dial.modo), "temp_c": float(dial.temp_c), "time_s": float(dial.time_s), "atmosphere": String(dial.atmosphere),
		"pressure_mpa": float(dial.pressure_mpa), "mold": String(dial.mold), "methane": float(dial.methane) / 100.0,
	}


# ════════════════════════════════ El horno ════════════════════════════════

func running() -> bool:
	return not run.is_empty() and float(run.t) < float(run.dur)


## «Arrancar» (5m): solo con la carga dentro de la máquina del modo (si no, dice por qué y no arranca). Con el molde de la cera
## perdida en el horno de calentar, burnout() (el ciclo del quemado, con la temperatura y el mantenimiento de arriba de los
## diales); con una pieza en el horno de calentar, heat() (qué le hace el calor); si no, fire() con los mandos. El motor decide
## ya el resultado; la marcha lo enseña en lo que dura el tiempo de verdad a la velocidad elegida (play_s).
func start() -> void:
	if running() or process == LIVE:
		return
	var mach := _run_kind()
	var inside := charge_inside()
	if inside == "":
		var md: Dictionary = ForgeData.MACHINES.get(mach, {})
		var where := String(forge.loaded().machine)
		var txt := "No arranca: %s está vacío. Mete la carga (tecla M) antes de arrancar." % _machine_words(mach)
		if where != "" and where != mach:
			txt = "No arranca: la carga está en %s y el modo es el de %s. Mete la carga en esta máquina (tecla M) o vuelve al modo de la otra." % [_machine_words(where), _machine_words(mach)]
		notice = txt
		_mistake = { "action": "arrancar", "code": "vacio", "what": txt, "source": String(md.get("source", "")) }
		_push_fx({ "kind": "sfx", "id": "slide" })
		_touch()
		return
	notice = ""
	var action := "fire"
	var kind := mach
	var r: Dictionary
	var real := float(dial.time_s)
	if inside == "molde":
		action = "burnout"
		kind = "quemado"
		r = _call("burnout", { "temp_c": float(dial.temp_c), "time_s": float(dial.time_s) })
		if float(r.get("realS", 0.0)) > 0.0:
			real = float(r.realS)
	elif mach == "calentar" and inside == "pieza":
		action = "heat"
		kind = "calentar"
		r = _call("heat", { "temp_c": float(dial.temp_c), "atmosphere": String(dial.atmosphere) })
	else:
		r = _call("fire", fire_params())
	var hold := play_s(real, RUN_MIN_S, RUN_MAX_S)
	var poured := kind in ["colada", "induccion"] and bool(r.get("ok", false))
	var plan: Dictionary = r.get("plan", {}) if action == "burnout" else {}
	run = {
		"kind": kind, "t": 0.0, "dur": hold + (POUR_S if poured else 0.0), "hold": hold, "real_s": real, "temp_c": float(dial.temp_c),
		"time_s": float(dial.time_s), "ok": bool(r.get("ok", false)), "defect": String(r.get("defect", "")),
		"visual": _visual(kind, r), "loop": forge.sfx_for("heat" if action != "fire" else "fire", r), "heat": action == "heat",
		"burnout": action == "burnout", "plan": plan, "poured": poured, "pour_fx": false, "mode": String(dial.modo),
	}
	act = {}
	_clock = "run"
	_after(action, r)


## El bucle de la máquina que trabaja (la del modo del dial, aunque no sea el de la receta): la llama de Verneuil, la
## prensa del HPHT, la bobina de inducción o el horno eléctrico. Es el de ClawForge.machine_sfx, el mismo que da
## ClawForge.sfx_for("fire") con la marcha (la marcha lo toma de ahí).
static func loop_for(kind: String) -> String:
	return ClawForge.machine_sfx(kind)


## Espacio: acaba ya la marcha (o la animación del taller).
func skip() -> void:
	if running():
		tick(float(run.dur) - float(run.t) + 1e-6)
	elif not act.is_empty() and float(act.t) < float(act.dur):
		act["t"] = float(act.dur)
		_touch()


## La máquina del modo del dial (ClawForge.machine_for): verneuil, hpht, cvd, sinterizado, induccion, colada o calentar.
func _run_kind() -> String:
	return ClawForge.machine_for(String(dial.modo), ForgeData.RECIPES.get(process, {}))


# ════════════════════════════════ La carga dentro de su máquina (5m) ════════════════════════════════

## El nombre de una máquina en medio de una frase: «soplete de Verneuil», «prensa de alta presión (HPHT)».
static func _machine_words(mid: String) -> String:
	return lower_first(String((ForgeData.MACHINES.get(mid, {}) as Dictionary).get("name", mid)))


## Un nombre en medio de una frase: solo la inicial en minúscula, para no estropear las siglas ni los nombres propios
## («circonita (CZ)», «zafiro (Verneuil)», «metal duro (WC-Co sinterizado)»; con to_lower salían «(cz)» y «(verneuil)»).
static func lower_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)


## ¿Va con «la»? Los nombres de los materiales cuya primera palabra acaba en a (moissanita, circonita, alúmina) y la
## hematites; los demás, con «el» (zafiro, diamante, rubí, metal duro, cuarzo, strass).
static func _feminine(nm: String) -> bool:
	var first := nm.get_slice(" ", 0)
	return first.ends_with("a") or first == "hematites"


## Lo que hay dentro de la máquina del modo del dial («» si nada): lo que se metió en ella o, en el horno de calentar, el molde
## de la cera perdida (que se queda dentro del quemado a la colada).
func charge_inside() -> String:
	var ld := forge.loaded()
	var mach := _run_kind()
	if String(ld.machine) == mach and String(ld.what) != "":
		return String(ld.what)
	if bool(ld.moldIn) and mach == "calentar" and not bool(snap().piece.get("sprue", false)):
		return "molde"
	return ""


## Lo que entraría ahora con M en la máquina del modo: en el horno de calentar, el molde revestido (con la cera sin quemar) o la
## pieza buena; si no, la carga de esa máquina (la de la tolva, la cápsula, el sustrato, la pastilla o el crisol), si se ha
## cargado lo pesado. «» si no hay nada que meter.
func charge_to_insert() -> String:
	var mach := _run_kind()
	var sn := snap()
	var piece: Dictionary = sn.piece
	var inv: Dictionary = sn.invest
	if mach == "calentar":
		if bool(inv.get("ok", false)) and not bool(inv.get("machined", false)) and not bool((sn.loaded as Dictionary).moldIn) and not bool(piece.get("sprue", false)):
			return "molde"
		if bool(piece.get("ok", false)):
			return "pieza"
	if loaded.is_empty():
		return ""
	return "crisol" if mach == "calentar" else ClawForge.charge_for(mach)


## M (o un clic en la puerta del horno): mete en la máquina del modo lo que le toca (load_machine) y la cierra. Si ya hay algo
## dentro, lo dice; si no hay nada que meter, lo dice el motor (el crisol vacío, ninguna pieza buena).
func insert_charge() -> void:
	if running() or process == LIVE:
		return
	var mach := _run_kind()
	var inside := charge_inside()
	if inside != "":
		notice = "Ya está dentro de su máquina (%s): %s." % [_machine_words(mach), String(ForgeData.CHARGE_NAMES.get(inside, inside))]
		_touch()
		return
	var what := charge_to_insert()
	if what == "":
		what = ClawForge.charge_for(mach)
	var r: Dictionary = _call("load_machine", { "machine": mach, "what": what })
	notice = "" if bool(r.get("ok", false)) else String(r.get("text", ""))
	if bool(r.get("ok", false)):
		_start_act("insert", { "machine": mach, "what": what })
	_after("load_machine", r)


## La máquina del modo y lo que hay dentro, para la escena y la página: { machine, name, inside (lo que hay: «» si nada),
## inside_name, next (lo que entraría con M), next_name, mold_in, where, source, quality }.
func inside_view() -> Dictionary:
	var mach := _run_kind()
	var md: Dictionary = ForgeData.MACHINES.get(mach, {})
	var ins := charge_inside()
	var nx := "" if ins != "" else charge_to_insert()
	return {
		"machine": mach, "name": String(md.get("name", "")), "inside": ins, "inside_name": String(ForgeData.CHARGE_NAMES.get(ins, "")),
		"next": nx, "next_name": String(ForgeData.CHARGE_NAMES.get(nx, "")), "mold_in": bool(forge.loaded().moldIn),
		"where": String(md.get("where", "")), "source": short_source(String(md.get("source", ""))), "quality": String(md.get("quality", "")),
	}


# ════════════════════════════════ La velocidad y el reloj (5m) ════════════════════════════════

## La velocidad de la marcha: SPEEDS[i] (0: lo más rápido). Se puede cambiar con la marcha en curso: lo que sale no cambia; la
## marcha y la animación del taller siguen por la misma fracción, con lo que duran ahora.
func set_speed(i: int) -> void:
	var j := clampi(i, 0, SPEEDS.size() - 1)
	if j == speed_i:
		return
	speed_i = j
	_rescale()
	_touch()


## X: la velocidad siguiente (k = 1) o la anterior (k = −1), en ciclo.
func cycle_speed(k: int) -> void:
	set_speed(posmod(speed_i + k, SPEEDS.size()))


## Lo que dura en la pantalla (s reales) algo que tarda real_s de verdad, a la velocidad de ahora, con los topes lo y hi (lo
## más rápido y lo que no tiene tiempo de verdad duran lo).
func play_s(real_s: float, lo: float, hi: float) -> float:
	var sp := float(SPEEDS[speed_i])
	if not is_finite(real_s):
		return hi
	if sp <= 0.0 or real_s <= 0.0:
		return lo
	return clampf(real_s / sp, lo, hi)


## La marcha y la animación del taller con la velocidad nueva: la misma fracción de lo hecho.
func _rescale() -> void:
	if not run.is_empty():
		var hold := float(run.hold)
		var nh := play_s(float(run.real_s), RUN_MIN_S, RUN_MAX_S)
		var t := float(run.t)
		var tail := float(run.dur) - hold
		run["t"] = t * nh / maxf(hold, 1e-9) if t <= hold else nh + (t - hold)
		run["hold"] = nh
		run["dur"] = nh + tail
	if not act.is_empty() and float(act.get("real_s", 0.0)) > 0.0:
		var nd := play_s(float(act.real_s), ACT_MIN_S, ACT_MAX_S)
		act["t"] = float(act.t) * nd / maxf(float(act.dur), 1e-9)
		act["dur"] = nd


## Lo que dura algo en la pantalla: «2.5 s» · «45 s» · «2 min 30 s».
static func fmt_play(s: float) -> String:
	if s < 10.0:
		return "%s s" % Js.to_fixed(s, 1).trim_suffix(".0")
	if s < 60.0:
		return "%s s" % Js.to_fixed(s, 0)
	var m := int(floor(s / 60.0))
	var r := int(round(s - 60.0 * float(m)))
	if r == 60:
		m += 1
		r = 0
	return "%d min" % m if r == 0 else "%d min %d s" % [m, r]


## El reloj (5m): lo que lleva y lo que tarda de verdad lo que corre (la marcha, o la animación del taller con su tiempo de
## verdad: enfriar, el fraguado del revestimiento, la espera para desmoldar, una pasada) y lo que tardaría en la vida real.
## { on, active, what, done_s, total_s, text («1 h 40 min de 3 h 20 min»), life («En la vida real tardaría…»), play_s (lo que
## dura aquí, s), speed, speed_name, speed_names, capped (manda el tope de la pantalla), phase }.
func clock_view() -> Dictionary:
	var out := { "on": false, "active": false, "what": "", "done_s": 0.0, "total_s": 0.0, "text": "", "life": "", "play_s": 0.0,
		"speed": speed_i, "speed_name": String(SPEED_NAMES[speed_i]), "speed_names": SPEED_NAMES, "capped": false, "phase": "" }
	var total := 0.0
	var done := 0.0
	var play := 0.0
	var lo := RUN_MIN_S
	var hi := RUN_MAX_S
	if _clock == "run" and not run.is_empty():
		var rv := run_view()
		total = float(run.real_s)
		done = float(rv.proc_s)
		play = float(run.hold)
		out["active"] = running()
		out["phase"] = String(rv.phase)
		out["what"] = String(RUN_WORDS.get(String(run.kind), "La marcha"))
	elif _clock == "act" and not act.is_empty() and float(act.get("real_s", 0.0)) > 0.0:
		total = float(act.real_s)
		done = total * clampf(float(act.t) / maxf(float(act.dur), 1e-9), 0.0, 1.0)
		play = float(act.dur)
		lo = ACT_MIN_S
		hi = ACT_MAX_S
		out["active"] = float(act.t) < float(act.dur)
		var ak := String(act.kind)
		out["what"] = String(ACT_WORDS.get("cool" if ak.begins_with("cool_") else ak, "El taller"))
	else:
		return out
	var sp := float(SPEEDS[speed_i])
	var want := total / sp if sp > 0.0 else lo
	var life := "En la vida real tardaría %s; aquí, %s a %s." % [fmt_time(total), fmt_play(play), String(SPEED_NAMES[speed_i])]
	if sp <= 0.0:
		life = "En la vida real tardaría %s; aquí, %s (lo más rápido)." % [fmt_time(total), fmt_play(play)]
	elif want > hi + 1e-9:
		life = "En la vida real tardaría %s; a %s serían %s, así que aquí dura %s (el tope de la pantalla)." % [fmt_time(total), String(SPEED_NAMES[speed_i]), fmt_play(want), fmt_play(play)]
	elif want < lo - 1e-9:
		life = "En la vida real tardaría %s; aquí dura %s (lo menos, para que se vea)." % [fmt_time(total), fmt_play(play)]
	out.merge({ "on": true, "done_s": done, "total_s": total, "play_s": play, "capped": sp > 0.0 and (want > hi + 1e-9 or want < lo - 1e-9),
		"text": "%s de %s" % [fmt_time(done), fmt_time(total)], "life": life }, true)
	return out


## Lo que se ve en la marcha según lo que ha salido: «crece» (bien, o corto: crece menos), «costra» (no funde: se queda
## una costra porosa), «gotea» (demasiado caliente en la llama), «sin_llama» (sin aire no hay llama), «hollin» (metano de
## más o en la llama), «grafito» (fuera de la línea de Kennedy), «quemado» (se oxida o se quema), «poroso» (sinterizado a
## medias), «sin_fundir» (la carga no funde), «molde» (el molde falla), «funde» y «nada» (calentar), «defecto»; en el quemado
## de la cera (5m), «quema» (bien), «humo» (la cera no se quema del todo) o «molde» (el molde se pasa de temperatura).
func _visual(kind: String, r: Dictionary) -> String:
	if kind == "quemado":
		if bool(r.get("ok", false)):
			return "quema"
		return "molde" if String(r.get("defect", "")) == "molde_quemado" else "humo"
	if kind == "calentar":
		match String(r.get("defect", "")):
			"funde", "reblandece":
				return "funde"
			"quemado", "grafitiza":
				return "quemado"
			"cascarilla":
				return "oxidado"
		return "nada"
	if bool(r.get("ok", false)):
		return "crece"
	var d := String(r.get("defect", ""))
	var fin := String((r.get("piece", {}) as Dictionary).get("finish", ""))
	match d:
		"corto":
			return "crece" if kind in ["verneuil", "hpht", "cvd"] else ("poroso" if fin == "poroso" else "sin_fundir")
		"frio":
			return "costra" if kind == "verneuil" else ("poroso" if kind == "sinterizado" else ("nada" if kind == "cvd" else "sin_fundir"))
		"caliente":
			return "gotea" if kind == "verneuil" else ("grafito" if kind == "hpht" else "defecto")
		"presion":
			return "grafito" if kind == "hpht" else ("sin_llama" if kind == "verneuil" else "nada")
		"atmosfera":
			if fin == "quemado":
				return "quemado"
			if kind == "verneuil":
				return "hollin" if String(dial.atmosphere) == "h2_ch4" else "sin_llama"
			return "poroso" if fin == "poroso" else "defecto"
		"mezcla":
			if kind == "cvd" and float(dial.methane) / 100.0 > float(ForgeData.RECIPES.diamante_cvd.methane.max):
				return "hollin"
			return "poroso" if fin == "poroso" else "defecto"
		"molde":
			return "molde"
		"tamano":
			return "crece"
	return "defecto"


## Sacar y enfriar en el medio del selector «Enfriar» (cool()). La animación dura lo que tarda de verdad en poder cogerse (el
## motor: realS), a la velocidad elegida.
func cool_piece() -> void:
	if running() or process == LIVE:
		return
	var medium := String(dial.cool)
	var r: Dictionary = _call("cool", medium)
	if bool(r.get("ok", false)) or String(r.get("defect", "")) in ["choque", "sin_recocer", "inversion"]:
		_start_act("cool_" + medium, { "medium": medium, "from_c": float(r.get("fromC", ROOM_C)), "real_s": float(r.get("realS", 0.0)) })
	_after("cool", r)


# ════════════════════════════════ La cera perdida (5m) ════════════════════════════════

## El modelo de cera de la funda de la garra (wax), para el molde del selector «Molde»; a la medida de la contracción si está
## marcada «Cera a la medida» (compensate).
func make_wax() -> void:
	if running():
		return
	var r: Dictionary = _call("wax", { "compensate": compensate, "mold": String(dial.mold) })
	if bool(r.get("ok", false)):
		_start_act("wax", {})
	_after("wax", r)


func set_compensate(on: bool) -> void:
	if on != compensate:
		compensate = on
		_touch()


## Reviste la cera con el molde del selector «Molde» (invest); la animación dura lo que fragua de verdad, a la velocidad elegida.
func invest() -> void:
	if running():
		return
	var r: Dictionary = _call("invest", { "mold": String(dial.mold) })
	if bool(r.get("ok", false)):
		_start_act("invest", { "real_s": float(r.get("setS", 0.0)), "mold": String(dial.mold) })
	_after("invest", r)


## Rompe el molde y saca la pieza con su bebedero (divest); el vidrio espera un día de verdad antes.
func divest() -> void:
	if running():
		return
	var r: Dictionary = _call("divest", {})
	if bool(r.get("ok", false)):
		_start_act("divest", { "real_s": float(r.get("realS", 0.0)) })
	_after("divest", r)


## C: el paso de la cera perdida que toca ahora con un botón (el modelo de cera, revestirlo o romper el molde); los demás (quemar
## la cera, colar, enfriar) se hacen en el horno, y lo dice.
func lost_wax_next() -> void:
	var lw := lost_wax_view()
	match String(lw.next):
		"cera":
			make_wax()
		"revestir":
			invest()
		"romper":
			divest()
		_:
			notice = String(lw.next_text)
			_touch()


## La cera perdida para la página y la escena (5m): { on (la receta se cuela), why_not (por qué no, con los minerales duros),
## next («cera», «revestir», «quemar», «colar», «enfriar», «romper», «hecho» o «»), next_text, compensate, mold, wax, invest,
## burnout, divest (lo que dio el motor), mold_in, cast (la colada: escala, bebedero, lo que llenó), steps [{ id, label, done }] }.
func lost_wax_view() -> Dictionary:
	var sn := snap()
	var c: Dictionary = sn.castable
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	var on := bool(c.get("ok", false)) and String(rec.get("form", "")) == "colada"
	var wax: Dictionary = sn.wax
	var inv: Dictionary = sn.invest
	var bo: Dictionary = sn.burnout
	var piece: Dictionary = sn.piece
	var nx := ""
	var nt := ""
	if on:
		if not bool(wax.get("ok", false)):
			nx = "cera"
		elif not bool(inv.get("ok", false)):
			nx = "revestir"
		elif not bool(inv.get("machined", false)) and not bool(bo.get("ok", false)):
			nx = "quemar"
			nt = "Ahora se quema la cera en el horno: el modo «Calentar», el molde dentro (tecla M), la temperatura y el tiempo de arriba del ciclo y «Arrancar»."
		elif not bool(piece.get("sprue", false)):
			nx = "colar"
			nt = "El molde está listo: pesa el metal, el modo «Fundir y colar», el crisol dentro (tecla M) y «Arrancar»."
		elif not bool((sn.cooled as Dictionary).get("ok", false)):
			nx = "enfriar"
			nt = "Colado: saca el molde y deja que se enfríe (tecla E) antes de romperlo."
		elif not bool(piece.get("divested", false)):
			nx = "romper"
		else:
			nx = "hecho"
			nt = "La pieza ya está fuera del molde: ahora se corta el bebedero con la sierra y se lima."
	var steps: Array = []
	for e: Array in [["cera", "Modelo de cera", bool(wax.get("ok", false))], ["revestir", "Revestir", bool(inv.get("ok", false))],
			["quemar", "Quemar la cera", bool(bo.get("ok", false)) or bool(inv.get("machined", false))], ["colar", "Colar", bool(piece.get("sprue", false))],
			["romper", "Romper el molde", bool(piece.get("divested", false))]]:
		steps.append({ "id": e[0], "label": e[1], "done": e[2] })
	return {
		"on": on, "why_not": String(c.get("text", "")) if not on else "", "next": nx, "next_text": nt, "compensate": compensate,
		"mold": String(dial.mold), "wax": wax, "invest": inv, "burnout": bo, "divest": sn.divest, "mold_in": bool((sn.loaded as Dictionary).moldIn),
		"cast": piece.get("cast", {}), "steps": steps,
	}


# ════════════════════════════════ El tallado por pasadas (5m) ════════════════════════════════

## La herramienta del tallado (CARVE_TOOLS): la sierra, la muela gruesa, la fresa, la muela fina o la pulidora.
func set_carve_tool(id: String) -> void:
	if CARVE_TOOLS.has(id) and id != carve_tool:
		carve_tool = id
		_touch()


## G: la herramienta siguiente (k = 1) o la anterior (k = −1).
func cycle_carve_tool(k: int) -> void:
	set_carve_tool(String(CARVE_TOOLS[posmod(CARVE_TOOLS.find(carve_tool) + k, CARVE_TOOLS.size())]))


## T: una pasada con la herramienta elegida (suave: Mayús + T, la cuarta parte), con el abrasivo, la fuerza y el agua del taller
## (carve_pass del motor). La pulidora pule (polish). La animación dura lo que tarda la pasada de verdad, a la velocidad elegida.
func carve_pass(light := false) -> void:
	if running():
		return
	if carve_tool == "pulidora":
		polish()
		return
	var p := { "tool": carve_tool, "abrasive": String(carve_p.abrasive), "force_n": float(carve_p.force_n), "coolant": bool(carve_p.coolant), "light": light }
	var r: Dictionary = _call("carve_pass", p)
	_pass_method = "carve_pass"
	if bool(r.get("ok", false)) or bool(r.get("ruins", false)) or String(r.get("defect", "")) == "no_muerde":
		_start_act("pass", { "tool": carve_tool, "real_s": _finite(float(r.get("timeS", 0.0))), "light": light, "bites": bool(r.get("bites", false)) })
	_after("carve_pass", r)


## Las pasadas de un paso del tutorial con una herramienta hasta su meta (carve_to del motor), con el abrasivo, la fuerza y el agua
## que pide.
func carve_to(p: Dictionary) -> void:
	if running():
		return
	var tool := String(p.get("tool", carve_tool))
	if CARVE_TOOLS.has(tool):
		carve_tool = tool
	for k: String in ["abrasive", "force_n", "coolant"]:
		if p.has(k):
			carve_p[k] = p[k]
	var r: Dictionary = _call("carve_to", p.duplicate())
	_pass_method = "carve_to"
	_start_act("pass", { "tool": tool, "real_s": _finite(float(r.get("timeS", 0.0))), "light": false, "bites": bool(r.get("bites", true)) })
	_after("carve_pass", r)


static func _finite(x: float) -> float:
	return x if is_finite(x) else 0.0


## El tallado para la página y la escena: { tool, tools [{ id, label, title, role }], state (ClawForge.carve_state: el
## veredicto de la forma y la silueta contra la de la funda), last (la última pasada: texto, tiempo, si mordió), light_frac }.
func carving_view() -> Dictionary:
	var tools: Array = []
	for id: String in CARVE_TOOLS:
		var t: Dictionary = ForgeData.CARVE_TOOLS[id]
		tools.append({ "id": id, "label": String(t.short), "title": "%s · %s" % [String(t.name), String(t.machine)], "role": String(t.role) })
	var lp: Dictionary = last.get(_pass_method, {}) if _pass_method != "" else {}
	return {
		"tool": carve_tool, "tool_name": String(ForgeData.CARVE_TOOLS[carve_tool].name), "tools": tools, "state": snap().cut,
		"last": { "text": String(lp.get("text", "")), "ok": bool(lp.get("ok", true)), "time_s": _finite(float(lp.get("timeS", 0.0))) },
		"light_frac": float(ForgeData.CARVE_LIGHT.value),
	}


# ════════════════════════════════ La prueba del ajuste (5m) ════════════════════════════════

## U: prueba el ajuste de la funda en la garra, sin pegarla (fit), con la holgura del adhesivo elegido (petición 43: pegarla es
## de la cetrería).
func fit_test() -> void:
	if running():
		return
	var r: Dictionary = _call("fit", { "gap_mm": float(bond_p.gap_mm) })
	_start_act("fit", {})
	_after("fit", r)


# ════════════════════════════════ La mesa de soldar (5r; petición 44) ════════════════════════════════

## El material de la segunda pieza de serie: el de la pieza de ahora (el mismo metal se funde en un solo baño).
func _weld_material() -> String:
	var m := String(weld_p.material)
	if m != "":
		return m
	return String(snap().piece.get("material", "acero"))


## Los argumentos de ClawForge.weld_setup con los mandos de ahora y la desalineación de la mesa.
func weld_params() -> Dictionary:
	var ov := 0.65
	for o: Dictionary in ClawWeld.OVERLAPS:
		if String(o.id) == String(weld_p.overlap):
			ov = float(o.value)
	return { "method": String(weld_p.method), "part": String(weld_p.part), "material": _weld_material(), "energy_j": float(weld_p.energy_j),
		"pulse_ms": float(weld_p.pulse_ms) if String(weld_p.method) == "laser" else float(weld_p.tig_ms), "spot_mm": float(weld_p.spot_mm),
		"current_a": float(weld_p.current_a), "gas": String(weld_p.gas), "overlap": ov, "temp_c": float(weld_p.temp_c), "gap_mm": float(weld_p.gap_mm),
		"align_mm": absf(weld_offset_mm) }


## ¿Hay una costura empezada y sin acabar? (Entonces los mandos no se tocan: se termina o se vuelve a colocar.)
func weld_in_progress() -> bool:
	var ws := forge.weld_state()
	return not ws.is_empty() and bool(ws.ready) and int(ws.pulses) > 0 and not bool(ws.done)


## Un mando de la mesa de soldar: key («method», «part», «material», «gas», «overlap» o un mando numérico de
## ClawWeld.METHODS.controls, con «tig_ms» para el tiempo del micro-TIG). Con las piezas ya en la mesa, se vuelve a evaluar
## (sin perder la alineación); con la costura empezada, no se mueve.
func set_weld(key: String, value: Variant) -> void:
	if running() or not weld_p.has(key):
		return
	if weld_in_progress():
		notice = "Con la costura empezada, los mandos no se tocan: termina la vuelta o vuelve a colocar las piezas."
		_touch()
		return
	match key:
		"method":
			if not ClawWeld.METHODS.has(String(value)):
				return
			weld_p[key] = String(value)
		"gas":
			if not ClawWeld.GAS_IDS.has(String(value)):
				return
			weld_p[key] = String(value)
		"part":
			if not ClawForge.WELD_PARTS.has(String(value)):
				return
			weld_p[key] = String(value)
		"material":
			if String(value) != "" and not WELD_TIP_IDS.has(String(value)):
				return
			weld_p[key] = String(value)
		"overlap":
			if _find(ClawWeld.OVERLAPS, String(value)) == null:
				return
			weld_p[key] = String(value)
		_:
			var cd := weld_control_data(key)
			if cd.is_empty():
				return
			var v := clampf(float(value), float(cd.min), float(cd.max))
			# al paso del mando (Math.round de JS, como el resto del core: nada de snappedf)
			var st := float(cd.step)
			weld_p[key] = Js.js_round(v / st) * st if st > 0.0 else v
	if _weld_bench and not forge.weld_state().is_empty():
		_weld_eval()
	else:
		_touch()


## Varios mandos de golpe (los del tutorial: los argumentos de ClawForge.weld_recommended).
func set_weld_params(p: Dictionary) -> void:
	for k: String in p:
		var key := k
		if k == "pulse_ms" and String(p.get("method", weld_p.method)) == "tig":
			key = "tig_ms"
		if k == "overlap" and p[k] is float:
			var best := "resistencia"
			for o: Dictionary in ClawWeld.OVERLAPS:
				if absf(float(o.value) - float(p[k])) < 0.05:
					best = String(o.id)
			weld_p["overlap"] = best
			continue
		if weld_p.has(key):
			weld_p[key] = p[k]
	_touch()


## El método siguiente (F) o el anterior.
func cycle_weld_method(k: int) -> void:
	var ids: Array = ClawWeld.METHOD_IDS
	var i := ids.find(String(weld_p.method))
	set_weld("method", String(ids[posmod(i + k, ids.size())]))


## Los datos de un mando numérico de la mesa (min, max, step, value de serie) o {}.
static func weld_control_data(key: String) -> Dictionary:
	var k := "pulse_ms" if key == "tig_ms" else key
	for mid: String in ClawWeld.METHOD_IDS:
		var cs: Dictionary = ClawWeld.METHODS[mid].controls
		if cs.has(k) and (key != "tig_ms" or mid == "tig") and (key != "pulse_ms" or mid == "laser"):
			return cs[k]
	return {}


## Coloca las piezas en la mesa de soldar (Q, o un clic en el aparato): la funda y la punta, a ojo (desalineadas
## WELD_PLACE_MM), y evalúa el punto y la costura con los mandos de ahora. Con una costura acabada, empieza otra.
func weld_prepare() -> void:
	if running():
		return
	var ws := forge.weld_state()
	if ws.is_empty() or bool(ws.done) or not bool(ws.ready) or int(ws.pulses) == 0:
		weld_offset_mm = WELD_PLACE_MM
	_weld_bench = true
	weld_hold = false
	weld_u = -1.0
	_weld_since = 1.0e9
	_weld_last = {}
	_weld_eval()


func _weld_eval() -> void:
	var r: Dictionary = _call("weld_setup", weld_params())
	if bool(r.get("ok", false)):
		notice = ""
	_after("weld_setup", r)


## Alinea las piezas del todo (I, o el botón): como con el útil de alinear bajo el microscopio.
func weld_align_pieces() -> void:
	weld_offset_mm = 0.0
	_weld_apply_offset()


## Mueve la punta mm a un lado (arrastrarla en la vista, o un paso del teclado): la desalineación es lo que queda.
func weld_nudge(mm: float) -> void:
	weld_offset_mm = clampf(weld_offset_mm + mm, -WELD_OFFSET_MAX_MM, WELD_OFFSET_MAX_MM)
	_weld_apply_offset()


func _weld_apply_offset() -> void:
	if running() or forge.weld_state().is_empty():
		_touch()
		return
	if weld_in_progress():
		notice = "Con la costura empezada, las piezas ya no se mueven: el baño las tiene cogidas."
		_touch()
		return
	var r: Dictionary = _call("weld_align", absf(weld_offset_mm))
	_after("weld_align", r)


## El periodo entre pulsos del método (s de pantalla): el láser y el micro-TIG, el de verdad; el soplete, lo que tarda cada
## tramo a la velocidad elegida.
func weld_period_s() -> float:
	var real := ClawWeld.pulse_period_s(String(weld_p.method))
	if String(weld_p.method) == "braze":
		return play_s(real, ACT_MIN_S, ACT_MAX_S)
	return real


## Dónde apunta el haz: u (0-1) a lo largo de la costura, o −1 fuera de ella (el ratón o el dedo sobre la vista).
func weld_aim(u: float) -> void:
	weld_u = clampf(u, 0.0, 1.0) if u >= 0.0 else -1.0
	# con el pedal apretado, el primer pulso al llegar a la costura sale ya (no espera al periodo)
	if weld_hold and weld_u >= 0.0 and _weld_can_fire() and _weld_since >= weld_period_s():
		_weld_fire(weld_u)
	_touch()


## El pedal: apretar (el ratón o el dedo sobre la costura) o soltar.
func weld_set_hold(on: bool) -> void:
	if on == weld_hold:
		return
	weld_hold = on
	if on and weld_u >= 0.0 and (_weld_can_fire() and _weld_since >= weld_period_s() or not _weld_can_fire()):
		# puede: el primer pulso ya; no puede (sin alinear, sin piezas, hecha): un pulso que no cuenta y se explica
		_weld_fire(weld_u)
	_touch()


## Un pulso en el primer tramo sin soldar (J): para el teclado y el tutorial.
func weld_pulse_next() -> void:
	var ws := forge.weld_state()
	if ws.is_empty():
		notice = "Primero coloca las piezas en la mesa de soldar."
		_touch()
		return
	if _weld_since < weld_period_s():
		return
	var segs: Array = ws.segments
	var n := segs.size()
	var i := 0
	while i < n and int(segs[i]) > 0:
		i += 1
	if i >= n:
		i = 0
	_weld_fire((float(i) + 0.5) / float(maxi(n, 1)))
	_touch()


## La vuelta entera de golpe («Hazlo como dice el paso»): un pulso por tramo que falte.
func weld_all() -> void:
	var ws := forge.weld_state()
	if ws.is_empty():
		weld_prepare()
		ws = forge.weld_state()
	if ws.is_empty() or not bool(ws.ready):
		return
	if not bool(ws.aligned):
		weld_align_pieces()
	var n := int(ws.pulsesNeed)
	for i in n:
		_weld_since = 1.0e9
		if bool(forge.weld_state().done):
			break
		_weld_fire((float(i) + 0.5) / float(maxi(n, 1)))
	_touch()


## ¿Puede salir un pulso que cuente? (Piezas en la mesa con un método que las une, alineadas y la costura sin acabar.)
func _weld_can_fire() -> bool:
	var ws := forge.weld_state()
	return not ws.is_empty() and bool(ws.ready) and bool(ws.aligned) and not bool(ws.done)


## Un pulso en u: cuenta si el motor lo cuenta (con las piezas alineadas y la costura sin acabar). Devuelve si ha habido pulso.
func _weld_fire(u: float) -> bool:
	if running():
		return false
	var r: Dictionary = _call("weld_pulse", { "u": u })
	_weld_last = r
	if bool(r.get("ok", false)):
		_weld_since = 0.0
		_push_fx({ "kind": "pulso", "u": u, "segment": int(r.segment), "method": String(weld_p.method), "remelt": bool(r.remelt) })
	if bool(r.get("done", false)):
		weld_hold = false
		var j: Dictionary = forge.weld_state().joint
		notice = ("Costura entera: %s" % String(j.text)) if bool(j.ok) else ""
		# la unión que falla se explica como un error (con el paso que lo arregla)
		_after("weld_finish", j if not bool(j.ok) else { "ok": true })
		return true
	if not bool(r.get("ok", false)):
		# sin alinear, sin preparar o ya hecha: se explica (una vez: el pedal no insiste mientras no se pueda)
		_check_mistake("weld_pulse", r)
		_touch()
		return false
	_check_mistake("weld_pulse", r)
	_sfx("weld_pulse", r)
	_update_tutorial()
	_touch()
	return true


## La mesa de soldar para la página y la escena: { on, ready, done, method, method_name, methods [{ id, label, title }], part,
## parts, material, materials, controls [{ id, name, value, text, t, min, max }], gas, gases, overlap, overlaps, text, defect,
## pulses, pulses_need, covered, progress, bar_text, what (lo que se está haciendo), next (qué toca: «colocar», «alinear»,
## «soldar», «limar», «pulir» o «hecho»), aligned, offset_mm, align_max_mm, align_text, hold, u, period_s, segments, spot,
## joint, verdict, verdict_tone, color, safety, geometry, can (lo que se puede unir: { ok, text }) }.
func weld_view(sn: Dictionary) -> Dictionary:
	var ws: Dictionary = sn.weld
	var method := String(weld_p.method)
	var md: Dictionary = ClawWeld.METHODS[method]
	var methods: Array = []
	for id: String in ClawWeld.METHOD_IDS:
		methods.append({ "id": id, "label": String(ClawWeld.METHODS[id].short), "title": String(ClawWeld.METHODS[id].name) })
	var parts: Array = []
	for id: String in ClawForge.WELD_PARTS:
		parts.append({ "id": id, "label": String(ClawForge.WELD_PARTS[id]).split(" (")[0], "title": String(ClawForge.WELD_PARTS[id]) })
	var mats: Array = []
	for id: String in WELD_TIP_IDS:
		var e: Variant = ForgeData.inlay_entry(id)
		mats.append({ "id": id, "label": String(e.short) if e != null else id, "title": String(e.name) if e != null else id })
	var controls: Array = []
	for c: Array in WELD_CONTROLS[method]:
		var key := String(c[0])
		var cd := weld_control_data(key)
		var v := float(weld_p[key])
		controls.append({ "id": key, "name": String(c[1]), "value": v, "text": "%s %s" % [Js.to_fixed(v, int(c[3])), String(c[2])],
			"t": (v - float(cd.min)) / maxf(float(cd.max) - float(cd.min), 1e-9), "min": float(cd.min), "max": float(cd.max), "step": float(cd.step), "unit": String(c[2]), "decimals": int(c[3]) })
	var gases: Array = []
	for id: String in ClawWeld.GAS_IDS:
		gases.append({ "id": id, "label": String(ClawWeld.GAS_NAMES[id]), "title": String(ClawWeld.GAS_NAMES[id]) })
	var overlaps: Array = []
	for o: Dictionary in ClawWeld.OVERLAPS:
		overlaps.append({ "id": String(o.id), "label": String(o.name), "title": "Solape entre puntos del %s %%" % Js.to_fixed(float(o.value) * 100.0, 0) })
	var a := String(sn.piece.get("material", ""))
	var b := _weld_material()
	var can := ClawWeld.can_join(a, b, method) if a != "" else { "ok": false, "text": "Primero hay que hacer la pieza de metal (o de metal duro) y dejar que se enfríe." }
	var on := bool(ws.get("on", false))
	var ready := on and bool(ws.ready)
	var done := on and bool(ws.done)
	var j: Dictionary = ws.get("joint", {}) if on else {}
	var n := int(ws.get("pulsesNeed", 0))
	var cov := int(ws.get("covered", 0))
	var unit := "tramos" if method == "braze" else "puntos"
	var next := "colocar"
	var what := "Sin piezas en la mesa: elige el método y «Colocar en la mesa»."
	var bar := ""
	if on and not ready:
		next = "colocar"
		what = String(ws.text)
	elif ready and not bool(ws.aligned):
		next = "alinear"
		what = "Piezas en la mesa, desalineadas %s mm (la junta admite %s mm): alinéalas." % [Js.to_fixed(float(ws.alignMm), 2), Js.to_fixed(float(ws.alignMaxMm), 2)]
	elif ready and not done:
		next = "soldar"
		bar = "%s: %d de %d a lo largo de la costura" % [unit.substr(0, 1).to_upper() + unit.substr(1), cov, n]
		what = ("Soldando: %s." % bar.to_lower()) if cov > 0 else ("Alineadas. Aprieta sobre la costura y recorre la vuelta: hacen falta %d %s." % [n, unit])
		if weld_hold and weld_u < 0.0:
			what += " El haz no está sobre la costura."
	elif done and bool(j.get("ok", false)):
		var cs: Dictionary = sn.cut
		if float(cs.get("seamMm", 0.0)) > 0.0 or bool(forge.check("soldada")) and not bool(forge.check("costura_limada")):
			next = "limar"
			what = "Costura entera y unión buena: queda el cordón, que se lima con la muela fina."
		elif (sn.polish as Dictionary).is_empty():
			next = "pulir"
			what = "Cordón limado: pule la funda otra vez."
		else:
			next = "hecho"
			what = "Soldada, limada y pulida: lista para la cetrería."
		bar = "%s: %d de %d" % [unit.substr(0, 1).to_upper() + unit.substr(1), cov, n]
	elif done:
		next = "colocar"
		what = "La soldadura ha fallado: %s" % String(j.get("text", ""))
		bar = "%s: %d de %d" % [unit.substr(0, 1).to_upper() + unit.substr(1), cov, n]
	var tone := ""
	if done:
		tone = "bien" if bool(j.get("ok", false)) else "mal"
	elif on and not ready:
		tone = "mal"
	elif ready and not bool(ws.aligned):
		tone = "aviso"
	var color: Dictionary = j.get("color", {}) if done else (ws.get("spot", {}) as Dictionary).get("color", {}) if on else {}
	return {
		"on": on, "ready": ready, "done": done, "method": method, "method_name": String(md.name), "machine": String(md.machine), "methods": methods,
		"part": String(weld_p.part), "parts": parts, "material": b, "materials": mats, "controls": controls, "gas": String(weld_p.gas), "gases": gases,
		"has_gas": bool(md.gas), "overlap": String(weld_p.overlap), "overlaps": overlaps, "text": String(ws.get("text", "")) if on else String(can.text),
		"defect": String(ws.get("defect", "")) if on else "", "pulses": int(ws.get("pulses", 0)), "pulses_need": n, "covered": cov,
		"progress": float(cov) / float(maxi(n, 1)), "bar_text": bar, "what": what, "next": next, "aligned": bool(ws.get("aligned", false)),
		"offset_mm": weld_offset_mm, "align_max_mm": float(ws.get("alignMaxMm", 0.1 * wall_mm())),
		"align_text": ("Junta de %s mm (admite %s mm)" % [Js.to_fixed(absf(weld_offset_mm), 2), Js.to_fixed(float(ws.get("alignMaxMm", 0.1 * wall_mm())), 2)]) if on else "",
		"hold": weld_hold, "u": weld_u, "period_s": weld_period_s(), "segments": ws.get("segments", []), "spot": ws.get("spot", {}),
		"joint": j, "verdict": String(j.get("text", "")) if done else "", "verdict_tone": tone, "color": color, "safety": String(md.safety),
		"geometry": ws.get("geometry", {}), "can": { "ok": bool(can.ok), "text": String(can.text) }, "at_bench": _weld_bench and on,
		"in_progress": weld_in_progress(), "last": _weld_last.duplicate(true), "braze": ws.get("braze", {}), "unit": unit,
		"source": short_source(String(md.source)),
	}


# ════════════════════════════════ El taller ════════════════════════════════

func carve() -> void:
	var r: Dictionary = _call("carve", carve_p.duplicate())
	_start_act("carve", {})
	_after("carve", r)


func protect() -> void:
	var r: Dictionary = _call("protect", barrier_p.duplicate())
	_start_act("protect", {})
	_after("protect", r)


## Recubre (en la funda o, en la ficción, la garra viva). En la garra viva integra hasta 4000 pasos por vía: una llamada
## por acción, en el hilo del estado, nunca en el fotograma.
func coat() -> void:
	var p := coat_p.duplicate()
	if process == LIVE:
		p["target"] = "garra_viva"
	if float(p.get("cover_mm", -1.0)) <= 0.0:
		p.erase("cover_mm")
	if String(p.method) != "ald_alumina":
		p.erase("cycles")
	var r: Dictionary = _call("coat", p)
	_start_act("coat", { "method": String(p.method), "target": String(p.target) })
	_after("coat", r)


func bond() -> void:
	var r: Dictionary = _call("bond", bond_p.duplicate())
	_start_act("bond", {})
	_after("bond", r)


func polish() -> void:
	var r: Dictionary = _call("polish", polish_p.duplicate())
	_start_act("polish", {})
	_after("polish", r)


## Prueba la garra con la carga (por defecto, la fuerza de la ficha del animal).
func check() -> void:
	var p := {} if load_n <= 0.0 else { "load_n": load_n }
	var r: Dictionary = _call("check_load", p)
	_start_act("check", {})
	_after("check_load", r)


## Los ajustes del taller (los de la página): solo las claves que conoce cada uno, con sus topes.
func set_carve(key: String, value: Variant) -> void:
	match key:
		"abrasive":
			if ForgeData.ABRASIVES.has(String(value)):
				carve_p["abrasive"] = String(value)
				carve_p["grain_um"] = float(ForgeData.ABRASIVES[String(value)].grain_um)
		"grain_um":
			carve_p["grain_um"] = clampf(float(value), 1.0, 500.0)
		"force_n":
			carve_p["force_n"] = clampf(float(value), 0.5, 2000.0)
		"speed_ms":
			carve_p["speed_ms"] = clampf(float(value), 1.0, 60.0)
		"coolant":
			carve_p["coolant"] = bool(value)
	_touch()


func set_barrier(key: String, value: Variant) -> void:
	match key:
		"barrier":
			if ForgeData.BARRIERS.has(String(value)):
				barrier_p["barrier"] = String(value)
		"thickness_mm":
			barrier_p["thickness_mm"] = clampf(float(value), 0.0, 20.0)
	_touch()


func set_coat(key: String, value: Variant) -> void:
	match key:
		"method":
			if ForgeData.COATINGS.has(String(value)):
				coat_p["method"] = String(value)
		"target":
			if String(value) in ["funda", "garra_viva"] and process != LIVE:
				coat_p["target"] = String(value)
		"time_s":
			coat_p["time_s"] = clampf(float(value), 0.0, 36000.0)
		"cycles":
			coat_p["cycles"] = clampf(roundf(float(value)), 0.0, 100000.0)
		"cover_mm":
			coat_p["cover_mm"] = float(value)
	_touch()


func set_bond(key: String, value: Variant) -> void:
	match key:
		"adhesive":
			if ForgeData.ADHESIVES.has(String(value)) or String(value) == String(ForgeData.BRAZE.id):
				bond_p["adhesive"] = String(value)
				if ForgeData.ADHESIVES.has(String(value)):
					bond_p["gap_mm"] = float(ForgeData.ADHESIVES[String(value)].gap_ideal)
		"gap_mm":
			bond_p["gap_mm"] = clampf(float(value), 0.0, 20.0)
	_touch()


func set_polish(key: String, value: Variant) -> void:
	match key:
		"abrasive":
			if ForgeData.ABRASIVES.has(String(value)):
				polish_p["abrasive"] = String(value)
		"grain_um":
			polish_p["grain_um"] = clampf(float(value), 1.0, 500.0)
		"sharpen":
			polish_p["sharpen"] = bool(value)
	_touch()


func set_load(n: float) -> void:
	load_n = n
	_touch()


# ════════════════════════════════ Lo recomendado y el tutorial ════════════════════════════════

## Pone en los mandos y en la balanza lo que recomienda la receta (ClawForge.recommended) sin hacer nada: después se pesa,
## se carga, se mete en su máquina y se arranca. Para aprender dónde va cada mando. Con el molde de la cera perdida revestido y
## sin quemar, los mandos van al quemado de la cera (el modo «Calentar» con la temperatura y el tiempo de arriba del ciclo).
func apply_recommended() -> void:
	var rec := forge.recommended(_rec_id())
	if rec.has("mix"):
		pan = {}
		for k: String in rec.mix:
			pan[k] = float(rec.mix[k])
	if rec.has("fire"):
		var fp: Dictionary = rec.fire
		dial["modo"] = String(fp.mode)
		dial["temp_c"] = float(fp.temp_c)
		dial["time_s"] = float(fp.time_s)
		dial["atmosphere"] = String(fp.atmosphere)
		dial["pressure_mpa"] = float(fp.pressure_mpa)
		if fp.has("mold"):
			dial["mold"] = String(fp.mold)
		dial["methane"] = float(fp.get("methane", 0.0)) * 100.0
	var lw := lost_wax_view()
	if rec.has("burnout") and String(lw.next) == "quemar":
		dial["modo"] = "calentar"
		dial["temp_c"] = float(rec.burnout.temp_c)
		dial["time_s"] = float(rec.burnout.time_s)
		dial["atmosphere"] = "aire"
	if rec.has("cool"):
		dial["cool"] = String(rec.cool)
	if rec.has("carve"):
		carve_p.merge(rec.carve, true)
	if rec.has("protect"):
		barrier_p.merge(rec.protect, true)
	if rec.has("coat"):
		coat_p.merge(rec.coat, true)
	if rec.has("bond"):
		bond_p.merge(rec.bond, true)
	if rec.has("polish"):
		polish_p.merge(rec.polish, true)
	_recommend_weld()
	_update_tutorial()
	_touch()


## Con una pieza de metal (o de metal duro) ya hecha, «Poner lo recomendado» pone también los mandos de la mesa de soldar
## (ClawForge.weld_recommended: el método y la energía que atraviesan la pared sin perforarla); con los de serie, la primera
## costura salía con falta de fusión en el acero, el oro y el titanio. Sin pieza, si no se puede soldar o con una costura a
## medias (no cambia los mandos a mitad de la vuelta), no toca nada; con las piezas en la mesa, vuelve a evaluar el punto.
func _recommend_weld() -> void:
	var mid := String(snap().piece.get("material", ""))
	if mid == "" or weld_in_progress():
		return
	var setup: Dictionary = forge.weld_recommended().weld_setup
	if not bool(ClawWeld.can_join(mid, mid, String(setup.method)).get("ok", false)):
		return
	set_weld_params(setup)
	if _weld_bench and not forge.weld_state().is_empty():
		_weld_eval()


## El id de la receta o del tutorial especial del proceso (para ClawForge.recommended y tutorial).
func _rec_id() -> String:
	return process


## «Hazlo como dice el tutorial»: el paso de ahora con sus argumentos recomendados, por el mismo camino que los gestos
## (los mandos y la balanza se ponen como pide y se llama a la acción: meter la carga, arrancar, la cera perdida, las pasadas…).
## Los pasos informativos solo pasan al siguiente; un paso que ya estaba hecho (su condición ya se cumplía), también.
func do_step() -> void:
	var st := current_step()
	if st.is_empty():
		return
	var at := tut_step
	var args: Variant = st.get("args")
	match String(st.get("action", "")):
		"mix":
			pan = (args as Dictionary).duplicate() if args is Dictionary else pan
			load_crucible()
		"load_machine":
			if ForgeData.RECIPES.has(process):
				dial["modo"] = String(ForgeData.RECIPES[process].mode)
			insert_charge()
		"fire":
			if args is Dictionary:
				for k: String in ["temp_c", "time_s", "pressure_mpa"]:
					dial[k] = float(args[k])
				dial["modo"] = String(args.mode)
				dial["atmosphere"] = String(args.atmosphere)
				if args.has("mold"):
					dial["mold"] = String(args.mold)
				dial["methane"] = float(args.get("methane", 0.0)) * 100.0
			if charge_inside() == "":
				insert_charge()
			start()
		"cool":
			if args != null:
				dial["cool"] = String(args)
			cool_piece()
		"wax":
			if args is Dictionary:
				compensate = bool(args.get("compensate", true))
				if args.has("mold"):
					dial["mold"] = String(args.mold)
			make_wax()
		"invest":
			if args is Dictionary and args.has("mold"):
				dial["mold"] = String(args.mold)
			invest()
		"burnout":
			dial["modo"] = "calentar"
			if args is Dictionary:
				dial["temp_c"] = float(args.temp_c)
				dial["time_s"] = float(args.time_s)
			if charge_inside() != "molde":
				insert_charge()
			start()
		"divest":
			divest()
		"carve":
			carve_p.merge(args, true)
			carve()
		"carve_to":
			carve_to(args if args is Dictionary else { "tool": carve_tool })
		"choose":
			choose_stone(String(args))
		"protect":
			barrier_p.merge(args, true)
			protect()
		"coat":
			coat_p.merge(args, true)
			coat()
		"bond":
			bond_p.merge(args, true)
			bond()
		"polish":
			polish_p.merge(args, true)
			polish()
		"fit":
			if args is Dictionary and args.has("gap_mm"):
				bond_p["gap_mm"] = float(args.gap_mm)
			fit_test()
		"check_load":
			check()
		"weld_setup":
			if args is Dictionary:
				set_weld_params(args)
			weld_prepare()
		"weld_align":
			weld_align_pieces()
		"weld_pulse":
			weld_all()
		_:
			if String(st.get("id", "")) == "modo" and ForgeData.RECIPES.has(process):
				dial["modo"] = String(ForgeData.RECIPES[process].mode)
			tutorial_next()
			return
	# hecho lo que pide (o ya lo estaba): al siguiente
	if tut_step == at:
		var now := current_step()
		if not now.is_empty() and (String(now.check) == "" or now.done == true):
			tutorial_next()
	_touch()


func set_tutorial(on: bool) -> void:
	if on != tutorial_on:
		tutorial_on = on
		_touch()


## Salta a un tutorial (TUTORIALS): el general o el de un proceso (que pasa a ser el que se fabrica).
func tutorial_goto(id: String) -> void:
	if not TUTORIALS.has(id):
		return
	if id != GENERAL and id != WELD and id != process:
		process = id
		_rebuild()
	tut_id = id
	_reset_tutorial()
	_touch()


func _reset_tutorial() -> void:
	tut_step = 0
	tut_skipped = ""
	_prev_check = {}
	_done = {}
	_steps_key = ""
	_seed_checks()


## Los pasos del tutorial que se sigue, con done y los argumentos recomendados (de ClawForge.tutorial).
func steps() -> Array:
	var key := "%s|%s|%d|%s" % [tut_id, process, forge.serial(), String(dial.modo)]
	if key != _steps_key:
		_steps_key = key
		_steps_cache = forge.tutorial(tut_id)
		for st: Dictionary in _steps_cache:
			if String(st.get("check", "")) == "modo_ok":
				# el paso del modo se cumple al girar el selector al de la receta (o si el horno ya trabajó en él)
				st["done"] = bool(st.done) or (ForgeData.RECIPES.has(process) and String(dial.modo) == String(ForgeData.RECIPES[process].mode))
			# 5w · el dial del tiempo va por marcas (TIME_STEPS): el paso dice la primera que llega a lo que tarda esta funda, y
			# «Hazlo como dice el paso» la pone (antes pedía «1 h 6 min o más», que el dial no marca)
			if String(st.id) == "parametros" and st.get("args") is Dictionary and (st.args as Dictionary).has("time_s"):
				var t := float(st.args.time_s)
				var mark := time_mark(t)
				if mark > t + 1e-9:
					var extra := " En el dial, la primera marca que llega: %s." % fmt_time(mark)
					st["text"] = String(st.text) + extra
					st["detail"] = String(st.get("detail", "")) + extra
				st.args["time_s"] = mark
			# el del quemado de la cera: el dial de la temperatura va de 5 en 5 °C (871 °C no se puede poner: 875 °C sí)
			if String(st.id) == "quemar" and st.get("args") is Dictionary and (st.args as Dictionary).has("temp_c"):
				var tc := float(st.args.temp_c)
				var tm := temp_mark(tc)
				if tm > tc + 1e-9:
					var extra2 := " En el dial, la primera marca que llega: %s °C." % Js.to_fixed(tm, 0)
					st["text"] = String(st.text) + extra2
					st["detail"] = String(st.get("detail", "")) + extra2
				st.args["temp_c"] = tm
				st.args["time_s"] = time_mark(float(st.args.get("time_s", 0.0)))
	return _steps_cache


## La primera marca del dial de la temperatura (de TEMP_FINE en TEMP_FINE °C) que llega a t °C (5w).
static func temp_mark(t: float) -> float:
	return ceilf(t / TEMP_FINE - 1e-9) * TEMP_FINE


## La primera marca del dial del tiempo (TIME_STEPS) que llega a t s; la última si ninguna llega (5w).
static func time_mark(t: float) -> float:
	for x: float in TIME_STEPS:
		if x >= t - 1e-9:
			return x
	return float(TIME_STEPS[TIME_STEPS.size() - 1])


## 5w · la pieza de ahora ya no se arregla en lo que queda del tutorial de su receta: pasado el paso de la marcha, una pieza que
## no ha salido bien (agrietada al enfriar, agujereada al tallar…) solo se rehace con «Otra pieza». Antes el paso pendiente
## («Enfriar», «Dar la forma») no se cumplía nunca y el arreglo decía «Enfría: al aire», que ya no servía. «» si no hace falta.
func restart_hint() -> String:
	if not ForgeData.RECIPES.has(process) or tut_id != process:
		return ""
	var p: Dictionary = snap().piece
	if p.is_empty() or bool(p.get("ok", false)):
		return ""
	var at := -1
	var ss := steps()
	for i in ss.size():
		if String(ss[i].id) == "parametros":
			at = i
	if at < 0 or tut_step <= at:
		return ""
	var fin := lower_first(String(ForgeData.FINISH_NAMES.get(String(p.get("finish", "")), "con defectos")))
	return "Esta pieza ya no se arregla (acabado: %s): «Otra pieza», en la ficha de la garra, empieza otra igual, con los mandos como están, y el tutorial vuelve a su primer paso." % fin


func current_step() -> Dictionary:
	var ss := steps()
	if tut_step < 0 or tut_step >= ss.size():
		return {}
	return ss[tut_step]


func tutorial_done() -> bool:
	return tut_step >= steps().size()


func tutorial_next() -> void:
	var st := current_step()
	if not st.is_empty():
		_done[_key(String(st.id))] = true
	tut_step = mini(tut_step + 1, steps().size())
	_skip_done()
	_seed_checks()
	_touch()


func tutorial_prev() -> void:
	tut_step = maxi(tut_step - 1, 0)
	tut_skipped = ""
	_seed_checks()
	_touch()


## 5w · al avanzar, un paso con condición que ya se cumple se da por hecho y se pasa al siguiente (antes se quedaba esperando
## un cambio que no iba a llegar: «Desbastar con la muela gruesa» con menos de una pasada de sobra pedía pasadas que agujereaban
## la funda de una garra pequeña, y el modo ya puesto con «Poner lo recomendado» no seguía solo). Lo dice tut_skipped.
func _skip_done() -> void:
	var names: Array = []
	for i in 64:
		var st := current_step()
		if st.is_empty() or String(st.check) == "" or st.done != true:
			break
		_done[_key(String(st.id))] = true
		names.append(String(st.title))
		tut_step = mini(tut_step + 1, steps().size())
	tut_skipped = ("Ya estaba hecho: «%s»." % "», «".join(names)) if not names.is_empty() else ""


func _key(sid: String) -> String:
	return "%s/%s" % [tut_id, sid]


func _seed_checks() -> void:
	if forge == null:
		return
	var st := current_step()
	if not st.is_empty() and String(st.check) != "":
		_prev_check[_key(String(st.id))] = bool(st.done)


## Un paso con condición se da por hecho cuando su condición pasa de falsa a verdadera mientras se está en él, y el
## tutorial sigue solo (como en la cetrería).
func _update_tutorial() -> void:
	_steps_key = ""
	var st := current_step()
	if st.is_empty() or String(st.check) == "":
		return
	var k := _key(String(st.id))
	var now := bool(st.done)
	var before: Variant = _prev_check.get(k)
	_prev_check[k] = now
	if now and before == false:
		_done[k] = true
		tut_step = mini(tut_step + 1, steps().size())
		_skip_done()
		_seed_checks()


# ════════════════════════════════ Después de cada acción ════════════════════════════════

func _after(action: String, r: Dictionary) -> void:
	_check_mistake(action, r)
	_sfx(action, r)
	_update_tutorial()
	_touch()


## El error que hay que explicar: la acción ha salido mal (el defecto o el problema que da el motor).
func _check_mistake(action: String, r: Dictionary) -> void:
	var bad := not bool(r.get("ok", true)) or String(r.get("defect", "")) != ""
	if action == "mix":
		bad = not bool(r.get("ok", false))
	# 5w · la cera o el revestimiento para un molde que no aguanta este material: se explica ya, no en la colada
	var warn := String(r.get("warning", "")) if action in ["wax", "invest"] else ""
	if warn != "":
		bad = true
	if action == "check_load":
		bad = bool(r.get("detached", false))
	if not bad:
		# lo arreglado deja de explicarse
		if not _mistake.is_empty() and String(_mistake.action) == action:
			_mistake = {}
		return
	var src := _action_source(action, r)
	_mistake = { "action": action, "code": String(r.get("defect", "")) if warn == "" else "molde", "what": String(r.get("text", "")) if warn == "" else warn, "source": src, "tool": String(r.get("tool", "")) }


## La fuente de lo que ha salido mal: la del polvo que sobra o falta (la mezcla no deja suceso) o la del suceso que acaba
## de apuntar el motor.
func _action_source(action: String, r: Dictionary) -> String:
	if action == "mix":
		var probs: Array = r.get("problems", [])
		var pid := String(probs[0].get("powder", "")) if not probs.is_empty() else ""
		if ForgeData.POWDERS.has(pid):
			return String(ForgeData.POWDERS[pid].source)
		return String(ForgeData.RECIPES.get(process, {}).get("source", ""))
	var ev := forge.events()
	if not ev.is_empty():
		return String(ev[ev.size() - 1].source)
	return String(ForgeData.RECIPES.get(process, {}).get("source", ""))


## El error explicado: { what, what_source, fix_title, fix_text, fix_source, control, mistake } o {}.
func mistake_view() -> Dictionary:
	if _mistake.is_empty():
		return {}
	var sid := String(MISTAKE_STEP.get(String(_mistake.action), ""))
	if String(_mistake.action) == "fire" and String(_mistake.code) == "modo":
		sid = "modo"
	if String(_mistake.action) == "choose" and process == ACRYLIC:
		sid = "mezclar"
	# 5m: el crisol vacío se arregla pesando; una pasada, con el paso de su herramienta
	if String(_mistake.action) == "load_machine" and String(_mistake.code) == "vacio":
		sid = "pesar"
	if String(_mistake.action) == "carve_pass":
		sid = _pass_step(String(_mistake.get("tool", "")))
	# 5r · un pulso con las piezas desalineadas se arregla alineándolas; sin piezas en la mesa, colocándolas
	if String(_mistake.action) == "weld_pulse" and String(_mistake.code) == "desalineada":
		sid = "alinear"
	elif String(_mistake.action) == "weld_pulse" and String(_mistake.code) in ["sin_soldadura", "hecha"]:
		sid = "preparar"
	var tid := WELD if String(_mistake.action).begins_with("weld") else process
	var fix := {}
	# los del tutorial que se sigue llevan además lo de esta pieza (5w: los gramos, el tiempo del dial)
	for st: Dictionary in (steps() if tid == tut_id else ForgeTutorial.steps(tid)):
		if String(st.id) == sid:
			fix = st
	var out := { "what": String(_mistake.what), "what_source": short_source(String(_mistake.source)), "fix_title": "",
		"fix_text": "", "fix_source": "", "control": String(STEP_CONTROLS.get(sid, "")), "mistake": "" }
	if not fix.is_empty():
		out["fix_title"] = "%s · %s" % [String(ForgeTutorial.PROCESS_NAMES.get(tid, tid)), String(fix.title)]
		out["fix_text"] = String(fix.text)
		out["fix_source"] = short_source(String(fix.source))
		out["mistake"] = String(fix.mistake)
	# 5w · la pieza ya no se arregla: primero «Otra pieza»; el paso, para hacerlo bien la próxima vez
	var rh := restart_hint()
	out["restart"] = rh
	if rh != "":
		out["fix_title"] = "Otra pieza"
		out["fix_text"] = rh + ((" La próxima vez, «%s»: %s" % [String(fix.title), String(fix.text)]) if not fix.is_empty() else "")
		out["control"] = "El botón «Otra pieza», en la ficha de la garra."
	return out


## El paso del tutorial del proceso que hace las pasadas de esa herramienta (el de la sierra, el desbaste, el vaciado, la forma
## o, en lo colado, cortar el bebedero y limar; en lo sinterizado, repasar).
func _pass_step(tool: String) -> String:
	for st: Dictionary in ForgeTutorial.steps(process):
		var sa: Variant = st.get("step_args")
		if sa is Dictionary and String((sa as Dictionary).get("tool", "")) == tool:
			return String(st.id)
	return String(PASS_STEP.get(tool, "forma"))


func dismiss_mistake() -> void:
	if not _mistake.is_empty():
		_mistake = {}
		_touch()


## El efecto de sonido de una acción (ClawForge.sfx_for): los bucles de la marcha y de la muela los pide sound_view.
func _sfx(action: String, r: Dictionary) -> void:
	var id := ""
	match action:
		"cool":
			id = forge.sfx_for("cool", r)
		"carve":
			var c := forge.sfx_for("carve", r)
			id = c if c != "forja-muela" else ""
		"polish":
			id = forge.sfx_for("polish", r)
		"coat":
			var k := forge.sfx_for("coat", r)
			id = k if k != "forja-horno" else ""
		"bond", "protect", "choose", "check_load", "fit", "wax", "invest":
			id = "tap" if bool(r.get("ok", false)) or action == "choose" else "slide"
		"mix", "load_machine":
			id = "tap" if bool(r.get("ok", false)) or action == "mix" else "slide"
		"divest":
			id = "snap" if bool(r.get("ok", false)) else "slide"
		"carve_pass":
			var cp := forge.sfx_for("carve", r)
			id = cp if cp != "forja-muela" else ""
		"weld_pulse":
			id = forge.sfx_for("weld_pulse", r)
		"weld_setup", "weld_align":
			id = "tap" if bool(r.get("ok", false)) else "slide"
	if id != "":
		_push_fx({ "kind": "sfx", "id": id })


func _push_fx(e: Dictionary) -> void:
	_fx_n += 1
	e["n"] = _fx_n
	_fx.append(e)
	if _fx.size() > FX_LOG:
		_fx.pop_front()


## Empieza la animación del taller: con extra.real_s (lo que tarda de verdad), dura eso a la velocidad elegida (play_s, con los
## topes de ACT_MIN_S y ACT_MAX_S) y el reloj la enseña; sin él, lo de ACT_S.
func _start_act(kind: String, extra: Dictionary) -> void:
	_weld_bench = false
	weld_hold = false
	var real := maxf(float(extra.get("real_s", 0.0)), 0.0)
	act = { "kind": kind, "t": 0.0, "dur": play_s(real, ACT_MIN_S, ACT_MAX_S) if real > 0.0 else float(ACT_S.get(kind, 1.0)) }
	act.merge(extra, true)
	act["real_s"] = real
	if real > 0.0:
		_clock = "act"


func _touch() -> void:
	_serial += 1


func serial() -> int:
	return _serial


# ════════════════════════════════ El tiempo ════════════════════════════════

## Pasa el tiempo (s reales): la marcha del horno, la colada, el enfriado y las animaciones del taller; y lo que se vierte.
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	var changed := false
	if pouring and held_jar != "":
		add_powder(held_jar, pour_rate(held_jar, pour_fine) * dt)
		changed = true
	if running():
		var t0 := float(run.t)
		run["t"] = minf(t0 + dt, float(run.dur))
		if bool(run.poured) and not bool(run.pour_fx) and float(run.t) >= float(run.hold):
			run["pour_fx"] = true
			_push_fx({ "kind": "sfx", "id": forge.sfx_for("pour", {}) })
		changed = true
	if not act.is_empty() and float(act.t) < float(act.dur):
		act["t"] = minf(float(act.t) + dt, float(act.dur))
		changed = true
	# 5r · el pedal de la mesa de soldar: con el haz sobre la costura, un pulso cada periodo del método
	_weld_since += dt
	if weld_hold and weld_u >= 0.0 and _weld_can_fire() and _weld_since >= weld_period_s():
		if _weld_fire(weld_u):
			changed = true
	if changed:
		_touch()


# ════════════════════════════════ Lecturas de la marcha ════════════════════════════════

## La marcha del horno ahora: { active, kind, progress (0-1), phase («calentar», «mantener», «quemar», «colar», «listo»), temp_c
## (la de ahora: la rampa de subida es dibujo; en el quemado de la cera, la del ciclo), proc_s (el tiempo de verdad que lleva),
## time_s (el que tarda de verdad), lapse (cuántas veces más deprisa), grown (lo crecido ahora: mm, mg o µm), grown_final, need,
## unit, shrink (fracción de contracción ahora), pour (0-1), visual, ok, defect }. {} si no ha arrancado.
func run_view() -> Dictionary:
	if run.is_empty():
		return {}
	var t := float(run.t)
	var hold := float(run.hold)
	var plan: Dictionary = run.get("plan", {})
	var burn := not plan.is_empty()
	var ramp := 0.0 if burn else RAMP_FRAC * hold
	var phase := "listo"
	var temp := float(run.temp_c)
	var u := 1.0
	if t < ramp:
		phase = "calentar"
		temp = ROOM_C + (float(run.temp_c) - ROOM_C) * (t / ramp)
		u = 0.0
	elif t < hold:
		phase = "quemar" if burn else "mantener"
		u = (t - ramp) / (hold - ramp)
	elif t < float(run.dur):
		phase = "colar"
	var real := float(run.real_s)
	var proc_s := real * u
	if burn:
		temp = _plan_temp(plan, proc_s)
	var fire: Dictionary = last.get("fire", {}) if not bool(run.heat) and not bool(run.get("burnout", false)) else {}
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	var gr: Dictionary = rec.get("growth", {}) if String(run.kind) in ["verneuil", "hpht", "cvd"] else {}
	var grows := String(run.visual) == "crece"
	var unit := ""
	var grown := 0.0
	var grown_final := 0.0
	if not gr.is_empty():
		unit = { "mm_h": "mm", "mg_h": "mg", "um_h": "µm" }[String(gr.kind)]
		grown_final = float(fire.get("grown", 0.0)) if grows else 0.0
		grown = minf(float(gr.value) * proc_s / 3600.0, grown_final) if grows else 0.0
	var shrink := 0.0
	if String(run.kind) == "sinterizado" and rec.has("shrink") and String(run.visual) == "crece":
		shrink = float(rec.shrink.value) * u
	var lapse := real / maxf(hold - ramp, 1e-6)
	return {
		"active": running(), "kind": String(run.kind), "progress": clampf(t / float(run.dur), 0.0, 1.0), "phase": phase,
		"temp_c": temp, "set_c": float(run.temp_c), "proc_s": proc_s, "time_s": real, "lapse": lapse,
		"grown": grown, "grown_final": grown_final, "need": float(fire.get("need", 0.0)), "unit": unit, "shrink": shrink,
		"pour": clampf((t - hold) / POUR_S, 0.0, 1.0) if bool(run.poured) else 0.0, "visual": String(run.visual),
		"ok": bool(run.ok), "defect": String(run.defect), "mode": String(run.mode), "heat": bool(run.heat),
		"burnout": burn, "pressure_mpa": float(dial.pressure_mpa) if String(run.kind) == "hpht" else 0.0,
	}


## La temperatura del horno en el ciclo del quemado de la cera a los e s de verdad: las subidas y bajadas, en línea recta, y los
## mantenimientos (ClawForge.burnout_plan).
static func _plan_temp(plan: Dictionary, e: float) -> float:
	var t := ROOM_C
	var left := e
	for st: Dictionary in plan.get("steps", []):
		var ramp := float(st.rampS)
		if left < ramp:
			return t + (float(st.toC) - t) * left / maxf(ramp, 1e-9)
		left -= ramp
		t = float(st.toC)
		if left < float(st.holdS):
			return t
		left -= float(st.holdS)
	return t


## La temperatura que se ve de la pieza ahora (°C): la del horno en la marcha; al enfriar, una caída hasta la del taller
## que dura lo que la animación (dibujo: el motor no da la curva de enfriado); fría después.
func piece_temp_c() -> float:
	var rv := run_view()
	var sn := snap()
	var piece: Dictionary = sn.piece
	if piece.is_empty():
		return float(rv.get("temp_c", ROOM_C)) if not rv.is_empty() else ROOM_C
	if not rv.is_empty() and bool(rv.active):
		return float(rv.temp_c)
	if not act.is_empty() and String(act.kind).begins_with("cool_"):
		var from := float(act.get("from_c", ROOM_C))
		var k := clampf(float(act.t) / maxf(float(act.dur), 1e-6), 0.0, 1.0)
		# una caída rápida al principio, como un enfriado de Newton (dibujo)
		var w := 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)
		return from + (ROOM_C - from) * w
	return float(piece.get("tempC", ROOM_C))


## El brillo de lo que está a t_c (de la rampa de core, interpolado): { temp_c, color, strength (dibujo), word, kelvin,
## text } o {} si no brilla.
func glow_view(t_c: float) -> Dictionary:
	if t_c <= Incandescence.DARK_C:
		return {}
	var g := Incandescence.glow_at(glow_ramp(), t_c)
	return { "temp_c": t_c, "color": g.color, "strength": float(g.strength), "word": Incandescence.word(t_c),
		"kelvin": t_c + Incandescence.KELVIN, "text": Incandescence.glow_text(t_c) }


## La rampa del color del calor para la escena (Incandescence.ramp): se calcula una vez por estado.
func glow_ramp() -> Array:
	if _ramp.is_empty():
		_ramp = Incandescence.ramp()
	return _ramp


# ════════════════════════════════ Textos ════════════════════════════════

## Una temperatura legible: «2100 °C».
static func fmt_c(t: float) -> String:
	return "%s °C" % Js.to_fixed(t, 0)


## Un tiempo legible: «45 s» · «12 min» · «1 h 30 min» · «10.5 h» · «25 días (609 h)».
static func fmt_time(s: float) -> String:
	if s < 60.0:
		return "%s s" % Js.to_fixed(s, 0)
	if s < 3600.0:
		return "%s min" % Js.to_fixed(s / 60.0, 0)
	if s < 36000.0:
		var h := int(floor(s / 3600.0))
		var m := int(round((s - 3600.0 * float(h)) / 60.0))
		if m == 60:
			h += 1
			m = 0
		return "%d h" % h if m == 0 else "%d h %d min" % [h, m]
	if s < 172800.0:
		return "%s h" % Js.to_fixed(s / 3600.0, 1).trim_suffix(".0")
	return "%s días (%s h)" % [Js.to_fixed(s / 86400.0, 0), Js.to_fixed(s / 3600.0, 0)]


## Una presión legible: «la del aire (0.101 MPa)» · «5.5 GPa» · «0.020 MPa».
static func fmt_mpa(p: float) -> String:
	if p <= 0.0:
		return "0 MPa (vacío o sin prensa)"
	if absf(p - 0.101) < 1e-9:
		return "0.101 MPa (la del aire)"
	if p >= 1000.0:
		return "%s GPa" % Js.to_fixed(p / 1000.0, 2).trim_suffix("0").trim_suffix(".0")
	if p >= 10.0:
		return "%s MPa" % Js.to_fixed(p, 0)
	if p >= 1.0:
		return "%s MPa" % Js.to_fixed(p, 1).trim_suffix(".0")
	return "%s MPa" % Js.to_fixed(p, 3)


## Un espesor legible: «300 µm» · «2.0 µm» · «0.033 µm (33 nm)».
static func fmt_um(um: float) -> String:
	if um >= 10.0:
		return "%s µm" % Js.to_fixed(um, 0)
	if um >= 1.0:
		return "%s µm" % Js.to_fixed(um, 1)
	return "%s µm (%s nm)" % [Js.to_fixed(um, 3), Js.to_fixed(um * 1000.0, 0)]


## El tiempo de una receta, en palabras: el ritmo de lo que crece o lo que se mantiene.
static func time_words(r: Dictionary) -> String:
	var g: Dictionary = r.get("growth", {})
	if not g.is_empty():
		match String(g.kind):
			"mm_h":
				return "lo que tarda la bola en crecer el largo de la funda, a ~%s mm/h" % Js.to_fixed(float(g.value), 0)
			"mg_h":
				return "lo que tarda el cristal en pesar lo que pide la funda, a ~%s mg/h (días)" % Js.to_fixed(float(g.value), 0)
			"um_h":
				return "lo que tarda la capa en llegar al espesor de la pared, a ~%s µm/h" % Js.to_fixed(float(g.value), 0)
	if String(r.get("id", "")) == "alumina":
		return "24 h a 1700 °C, 6-8 h a 1900 °C"
	return "al menos %s" % fmt_time(float(r.time_s.min))


## Gramos legibles: «0.25 g» · «4.0 g» · «100 g».
static func fmt_g(g: float) -> String:
	if g >= 10.0:
		return "%s g" % Js.to_fixed(g, 0) if absf(g - roundf(g)) < 0.05 else "%s g" % Js.to_fixed(g, 1)
	if g >= 1.0:
		return "%s g" % Js.to_fixed(g, 1)
	return "%s g" % Js.to_fixed(g, 2)


## Una fracción en tanto por ciento: «99.75 %» · «5.5 %» · «0.03 %».
static func fmt_pct(f: float) -> String:
	var p := f * 100.0
	if p < 1.0:
		return "%s %%" % Js.to_fixed(p, 2)
	if p < 10.0:
		return "%s %%" % Js.to_fixed(p, 1)
	if absf(p - roundf(p)) < 0.005:
		return "%s %%" % Js.to_fixed(p, 0)
	return "%s %%" % Js.to_fixed(p, 2)


## Una masa pequeña (kg) en gramos: «0.87 g».
static func fmt_kg(kg: float) -> String:
	return "%s g" % Format.fmt_f(kg * 1000.0) if kg * 1000.0 >= 10.0 else "%s g" % Js.to_fixed(kg * 1000.0, 2)


## El valor de un mando, en palabras: «2100 °C», «2 h», «Sintetizar cristal», «5.0 %».
func control_text(id: String) -> String:
	return value_text(id, dial[id])


static func value_text(id: String, v: Variant) -> String:
	var c := control_data(id)
	match id:
		"temp_c":
			return fmt_c(float(v))
		"time_s":
			return fmt_time(float(v))
		"pressure_mpa":
			return fmt_mpa(float(v))
		"methane":
			return "%s %%" % Js.to_fixed(float(v), 1)
	return String((c.get("option_names", {}) as Dictionary).get(String(v), String(v)))


## El margen bueno de la receta para un mando: { has, lo, hi, ok, text, options (los buenos) } (sin receta, has = false).
## El de la temperatura del diamante HPHT acaba en la línea de Kennedy a la presión de ahora, y el del tiempo empieza en
## lo que pide la funda con la temperatura de ahora (evaluate_fire, lo mismo que hará el motor).
func margin(id: String) -> Dictionary:
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	var out := { "has": false, "lo": 0.0, "hi": 0.0, "ok": true, "text": "", "options": [] }
	if rec.is_empty():
		return out
	match id:
		"modo":
			out.merge({ "has": true, "options": [String(rec.mode)], "ok": String(dial.modo) == String(rec.mode),
				"text": "la receta: %s" % value_text("modo", String(rec.mode)) }, true)
		"temp_c":
			var td: Dictionary = rec.temp_c
			var hi := float(td.max)
			if String(rec.method) == "hpht":
				hi = minf(hi, ClawForge.kennedy_t_max(float(dial.pressure_mpa)))
			var v := float(dial.temp_c)
			out.merge({ "has": true, "lo": float(td.min), "hi": hi, "ok": v >= float(td.min) and v <= hi,
				"text": "bien de %s a %s" % [fmt_c(float(td.min)), fmt_c(hi)] }, true)
			if String(rec.method) == "hpht":
				out["text"] = String(out.text) + " (por encima, la línea de Kennedy a esta presión)"
		"time_s":
			var ev := ClawForge.evaluate_fire(rec, snap().mix, fire_params(), snap().sheath)
			var need := float(ev.timeNeedS)
			out.merge({ "has": true, "lo": need, "hi": float(control_data("time_s").max), "ok": float(dial.time_s) + 1e-9 >= need,
				"text": "al menos %s (%s)" % [fmt_time(need), "lo que crece la funda" if rec.has("growth") else ("a esta temperatura" if String(rec.id) == "alumina" else "la receta")] }, true)
		"pressure_mpa":
			var pd: Dictionary = rec.pressure_mpa
			var lo := 0.0
			var hi2 := float(pd.max) if is_finite(float(pd.max)) else float(control_data("pressure_mpa").max)
			if String(rec.method) == "hpht":
				lo = ClawForge.kennedy_mpa(float(dial.temp_c))
			var p := float(dial.pressure_mpa)
			out.merge({ "has": true, "lo": lo, "hi": hi2, "ok": p >= lo - 1e-9 and p <= hi2 + 1e-9,
				"text": ("desde %s (la línea de Kennedy a %s) hasta %s" % [fmt_mpa(lo), fmt_c(float(dial.temp_c)), fmt_mpa(hi2)]) if String(rec.method) == "hpht" else ("hasta %s" % fmt_mpa(hi2) if is_finite(float(pd.max)) else "cualquiera: no la usa") }, true)
		"atmosphere":
			var ok_a: Array = rec.atmosphere.ok
			out.merge({ "has": true, "options": ok_a, "ok": ok_a.has(String(dial.atmosphere)),
				"text": "valen: %s" % ", ".join(ok_a.map(func(a: String) -> String: return lower_first(value_text("atmosphere", a)))) }, true)
		"methane":
			if rec.has("methane"):
				var me: Dictionary = rec.methane
				var m := float(dial.methane) / 100.0
				out.merge({ "has": true, "lo": float(me.min) * 100.0, "hi": float(me.max) * 100.0, "ok": m >= float(me.min) - 1e-12 and m <= float(me.max) + 1e-12,
					"text": "bien de %s a %s" % [fmt_pct(float(me.min)), fmt_pct(float(me.max))] }, true)
		"mold":
			if rec.has("mold"):
				var ok_m: Array = rec.mold.ok
				out.merge({ "has": true, "options": ok_m, "ok": ok_m.has(String(dial.mold)),
					"text": "valen: %s" % ", ".join(ok_m.map(func(a: String) -> String: return lower_first(value_text("mold", a)))) }, true)
		"cool":
			var ok_c: Array = rec.cool.ok
			out.merge({ "has": true, "options": ok_c, "ok": ok_c.has(String(dial.cool)),
				"text": "valen: %s" % ", ".join(ok_c.map(func(a: String) -> String: return lower_first(value_text("cool", a)))) }, true)
	return out


## Los mandos del horno para pintarlos: [{ id, name, unit, kind («dial» | «selector»), value, value_text, t (0-1),
## options [{ id, label }], margin, selected, what, why, source, source_short, quality, quality_text, used (lo usa la
## receta) }].
func controls_view() -> Array:
	var out: Array = []
	for id: String in CONTROL_IDS:
		var c := control_data(id)
		var opts: Array = []
		if c.has("options"):
			for o: String in c.options:
				opts.append({ "id": o, "label": String(c.option_names[o]) })
		var m := margin(id)
		out.append({
			"id": id, "name": String(c.name), "unit": String(c.unit), "kind": "dial" if DIALS.has(id) else "selector",
			"value": dial[id], "value_text": control_text(id), "t": control_t(id), "options": opts, "margin": m,
			"margin_t": [_t_of(id, float(m.lo)), _t_of(id, float(m.hi))] if bool(m.has) and not c.has("options") else [],
			"selected": id == selected_control, "what": String(c.what), "why": String(c.why), "source": readable(String(c.source)),
			"source_short": short_source(String(c.source)), "quality": String(c.quality), "quality_text": String(QUALITY_TEXT.get(String(c.quality), "")),
			"used": bool(m.has),
		})
	return out


## La posición 0-1 de un valor en el deslizador de un dial.
static func _t_of(id: String, v: float) -> float:
	var c := control_data(id)
	match id:
		"time_s":
			return _frac_in(TIME_STEPS, v)
		"pressure_mpa":
			return _frac_in(PRESSURE_STEPS, v)
	return clampf((v - float(c.min)) / (float(c.max) - float(c.min)), 0.0, 1.0)


## La posición 0-1 de un valor entre los de una lista redonda (interpolando entre los dos que lo rodean).
static func _frac_in(list: Array, v: float) -> float:
	if v <= float(list[0]):
		return 0.0
	for j in range(1, list.size()):
		if v <= float(list[j]):
			var a := float(list[j - 1])
			var b := float(list[j])
			return (float(j - 1) + (v - a) / maxf(b - a, 1e-12)) / float(list.size() - 1)
	return 1.0


## Nombre legible de una fuente: las citas conocidas por su nombre corto (las de la reforja y las de la cetrería) y sin
## rutas ni nombres internos.
## Se guarda por estado (las fuentes son textos fijos y limpiarlas cuesta: sustituciones y expresiones regulares).
func short_source(src: String) -> String:
	if _short_cache.has(src):
		return _short_cache[src]
	var s := src
	for pair: Array in _names:
		s = s.replace(String(pair[0]), String(pair[1]))
	s = CareState.short_source(s)
	_short_cache[src] = s
	return s


## La cita completa, sin rutas ni nombres internos (para la ayuda).
func readable(src: String) -> String:
	if _readable_cache.has(src):
		return _readable_cache[src]
	var s := CareState.readable_source(src)
	_readable_cache[src] = s
	return s


# ════════════════════════════════ La balanza en la vista ════════════════════════════════

## La balanza: { jars: [{ id, name, formula, what, grams, grams_text, in_recipe, frac, frac_text, ok, source_short, target_g,
## target_text, left_g, line (lo que lleva, lo que falta y lo que vale, 5w), state («», «falta», «bien», «sobra», «fuera»),
## doses [{ g, label }], minus { g, label } }], total, total_text, scale_text (la pantalla, con la tara), tare, held, pouring,
## fine, loaded, loaded_text, mix_ok, mix_text, ready (lo del plato se puede cargar), status_text y status_tone (el aviso: «Listo:
## carga el crisol (L)», lo que falta o cómo se arregla si se pasa), fix_kind, plan (ClawForge.mix_plan), plan_text, doses,
## pan_max }.
func bench_view() -> Dictionary:
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	var want := {}
	for p: Dictionary in rec.get("powders", []):
		want[String(p.id)] = p
	var plan := _plan()
	# 5w · lo que distingue la balanza: por debajo, lo que falta ya no se puede echar
	var read_g := float(ForgeData.MIX_PLAN.readability_g.value)
	var tgt := {}
	for p: Dictionary in plan.get("powders", []):
		tgt[String(p.id)] = p
	var ms := forge.mix_status(pan) if bool(plan.get("ok", false)) else {}
	var row_state := {}
	for rw: Dictionary in ms.get("rows", []):
		row_state[String(rw.id)] = String(rw.state)
	var total := pan_total()
	var jars: Array = []
	for id: String in ForgeData.POWDERS:
		var d: Dictionary = ForgeData.POWDERS[id]
		var g := float(pan.get(id, 0.0))
		var f := g / total if total > 0.0 else 0.0
		var w: Dictionary = want.get(id, {})
		var t: Dictionary = tgt.get(id, {})
		var ok := true
		var frac_txt := ""
		if not w.is_empty():
			ok = total > 0.0 and f >= float(w.min) - 1e-9 and f <= float(w.max) + 1e-9
			frac_txt = "%s (la receta: %s%s)" % [fmt_pct(f), fmt_pct(float(w.value)), (", de %s a %s" % [fmt_pct(float(w.min)), fmt_pct(float(w.max))]) if float(w.min) != float(w.max) else ""]
		elif g > 0.0:
			ok = false
			frac_txt = "%s: no va en esta receta" % fmt_pct(f)
		var st := String(row_state.get(id, ""))
		var line := ""
		var tg := float(t.get("targetG", 0.0))
		if not t.is_empty():
			# 5w · lo que falta, con sus decimales; menos de lo que distingue la balanza, o lo que no cambia lo que se lee del objetivo
			# («0.198 g de 0.198 g»), ya es su objetivo
			var short_of := tg - g >= read_g - 1e-12 and ClawForge.fmt_mass(g, tg) != ClawForge.fmt_mass(tg, tg)
			var lt := "faltan %s" % ClawForge.fmt_mass(tg - g) if short_of else "en su objetivo"
			if st == "bien":
				lt = ("bien; %s hasta el objetivo" % ClawForge.fmt_mass(tg - g)) if short_of else "bien"
			elif st == "sobra":
				lt = "sobra"
			line = "Llevas %s de %s%s · vale de %s a %s" % [ClawForge.fmt_mass(g, tg), ClawForge.fmt_mass(tg, tg), (" · " + lt) if lt != "" else "",
				ClawForge.fmt_mass(float(t.minG), tg), ClawForge.fmt_mass(float(t.maxG), tg) if is_finite(float(t.maxG)) else "lo que quieras"]
			if g > 0.0 and frac_txt != "":
				line += " · " + frac_txt
		elif g > 0.0:
			line = "%s · %s" % [fmt_g(g), frac_txt]
		var doses: Array = []
		for dg: float in doses_for(id):
			doses.append({ "g": dg, "label": "+" + _dose_label(dg) })
		var dmin := float(doses_for(id)[1])
		jars.append({ "id": id, "name": String(d.name), "formula": String(d.formula), "what": String(d.what), "grams": g,
			"grams_text": ClawForge.fmt_mass(g, tg) if tg > 0.0 else fmt_g(g), "in_recipe": not w.is_empty(), "frac": f, "frac_text": frac_txt, "ok": ok,
			"source_short": short_source(String(d.source)), "target_g": tg, "target_text": ClawForge.fmt_mass(tg, tg) if tg > 0.0 else "",
			"left_g": maxf(tg - g, 0.0), "line": line, "state": st, "doses": doses, "minus": { "g": -dmin, "label": "−" + _dose_label(dmin) } })
	var me: Dictionary = snap().mix
	var ready := bool(ms.get("ok", false))
	var status := ""
	var tone := ""
	var fix_kind := String((ms.get("fix", {}) as Dictionary).get("kind", ""))
	var same_as_loaded := not loaded.is_empty() and var_to_str(loaded) == var_to_str(pan)
	if bool(me.get("ok", false)) and same_as_loaded:
		status = "Cargado en el crisol: %s. Ahora el modo y meter la carga en su máquina (M)." % ClawForge.fmt_mass(_sum(loaded), float(plan.get("targetG", -1.0)))
		tone = "bien"
	elif not bool(plan.get("ok", false)):
		status = String(me.get("text", "")) if not me.is_empty() and not bool(me.get("ok", false)) else ""
		tone = "mal" if status != "" else ""
	elif total <= 0.0:
		status = "Echa cada polvo en el plato hasta su objetivo."
		tone = "aviso"
	elif ready:
		status = "Listo: carga el crisol (L)."
		tone = "bien"
	else:
		status = String(ms.fix.text)
		tone = "aviso" if fix_kind == "echar" else "mal"
	# junto a la balanza, sobre la vista, el aviso corto (el largo va en la tarjeta)
	var short := String(ms.fix.get("short", status)) if status == String((ms.get("fix", {}) as Dictionary).get("text", "")) and status != "" else status
	# lo que pide la pieza, con la misma frase que el tutorial (ClawForge.plan_sentence)
	var plan_text := ClawForge.plan_sentence(plan)
	var ref_t := float(plan.get("targetG", -1.0))
	# lo que se ve junto a la balanza, sobre la vista: una línea por polvo de la receta
	var hud: Array = []
	for j: Dictionary in jars:
		if float(j.target_g) <= 0.0:
			continue
		var tgj := float(j.target_g)
		var tail := "bien"
		if String(j.state) == "sobra":
			tail = "sobra"
		elif String(j.state) != "bien" and tgj - float(j.grams) >= read_g - 1e-12 and ClawForge.fmt_mass(float(j.grams), tgj) != ClawForge.fmt_mass(tgj, tgj):
			tail = "faltan %s" % ClawForge.fmt_mass(tgj - float(j.grams))
		hud.append("%s: %s de %s · %s" % [String(j.formula), ClawForge.fmt_mass(float(j.grams), tgj), ClawForge.fmt_mass(tgj, tgj), tail])
	return {
		"jars": jars, "total": total, "total_text": ClawForge.fmt_mass(total, ref_t) if ref_t > 0.0 else fmt_g(total), "scale_text": scale_text(),
		"tare": tare_g, "held": held_jar, "pouring": pouring, "fine": pour_fine,
		"loaded": not loaded.is_empty(), "loaded_text": fmt_g(_sum(loaded)), "mix_ok": bool(me.get("ok", false)),
		"mix_text": String(me.get("text", "")) if not me.is_empty() and not bool(me.get("ok", false)) else ("La mezcla es la de la receta." if bool(me.get("ok", false)) else ""),
		"ready": ready, "status_text": status, "status_short": short, "status_tone": tone, "fix_kind": fix_kind, "plan": plan, "plan_text": plan_text, "hud": hud,
		"target_text": ClawForge.fmt_mass(ref_t, ref_t) if ref_t > 0.0 else "",
		"doses": DOSES, "pan_max": PAN_MAX_G,
	}


## Una dosis para su botón: «1 g» · «0.1 g» · «0.001 g» (con los decimales justos).
static func _dose_label(g: float) -> String:
	for d in 5:
		if absf(Js.to_fixed(g, d).to_float() - g) < 1e-9:
			return "%s g" % Js.to_fixed(g, d)
	return "%s g" % Js.to_fixed(g, 4)


## La pantalla de la balanza: los gramos de encima de la tara con los 4 decimales de una balanza analítica (5w: distingue 0,1 mg);
## con la tara puesta, delante una «T», como en las de verdad.
func scale_text() -> String:
	return "%s%s g" % ["T " if tare_g > 0.0 else "", Js.to_fixed(maxf(pan_total() - tare_g, 0.0), 4)]


static func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k: String in d:
		t += float(d[k])
	return t


# ════════════════════════════════ La pieza y la funda ════════════════════════════════

## El color de un material (el de su ficha del banco o el de los nuevos de la 2.0): solo dibujo.
static func material_color(id: String) -> String:
	var e: Variant = ForgeData.inlay_entry(id)
	return String(e.get("col", "#C7CDD6")) if e != null else "#C7CDD6"


## La pieza: { exists, ok, material, name, color, form, form_name, finish, finish_name, defect, text, temp_c, glow (el color
## del calor de core), at (dónde está: «horno», «cubo», «banco», «muela», «garra»), carved, coated, coat_method, bonded,
## polished, size_text }.
func piece_view() -> Dictionary:
	var sn := snap()
	var p: Dictionary = sn.piece
	var out := { "exists": not p.is_empty(), "ok": bool(p.get("ok", false)), "material": String(p.get("material", "")),
		"name": "", "color": "#C7CDD6", "form": String(p.get("form", "")), "form_name": "", "finish": String(p.get("finish", "")),
		"finish_name": String(ForgeData.FINISH_NAMES.get(String(p.get("finish", "")), "")), "defect": String(p.get("defect", "")),
		"text": String(p.get("text", "")), "temp_c": piece_temp_c(), "at": "horno", "carved": bool(p.get("carved", false)),
		"coated": bool((sn.coat as Dictionary).get("ok", false)), "coat_method": String((sn.coat as Dictionary).get("method", "")),
		"coat_color": "", "bonded": bool((sn.bond as Dictionary).get("ok", false)), "polished": bool((sn.polish as Dictionary).get("ok", false)),
		"size_text": "", "bought": bool(p.get("bought", false)), "sprue": bool(p.get("sprue", false)) and int((sn.cut as Dictionary).get("cuts", 0)) < int((sn.cut as Dictionary).get("cutsNeed", 1)),
		"in_mold": bool(p.get("sprue", false)) and not bool(p.get("divested", false)), "cast_scale": float((p.get("cast", {}) as Dictionary).get("scale", 1.0)) }
	if out.exists:
		var e: Variant = ForgeData.inlay_entry(String(out.material))
		out["name"] = String(e.name) if e != null else String(out.material)
		out["color"] = material_color(String(out.material))
		out["form_name"] = String({ "bola": "bola de Verneuil", "cristal": "cristal", "capa": "funda crecida sobre el molde",
			"sinterizada": "pieza sinterizada", "colada": "funda colada con la forma de la garra", "bloque": "bloque comprado",
			"lingote": "lingote (la funda se talla de él)" }.get(String(out.form), String(out.form)))
		if bool(p.get("sprue", false)) and not bool(p.get("carved", false)):
			out["form_name"] = "funda colada con su bebedero" if bool(p.get("divested", false)) else "colada, aún en su molde"
		if ForgeData.PROSTHESIS.has(String(out.material)):
			out["form_name"] = "acrílico recién mezclado"
		if bool(out.coated):
			out["coat_color"] = material_color(String((sn.coat as Dictionary).get("material", "")))
	out["glow"] = glow_view(float(out.temp_c))
	out["at"] = _piece_at(sn, bool(out.exists))
	out["look"] = look_view(sn)
	return out


## Lo que necesita la biblioteca de materiales de las garras (ClawMaterial, app/common) para pintar las piezas: el id
## óptico de la pieza (ClawOptics.optical_id, con la variedad de la receta), su acabado de la reforja, el grano del pulido,
## el grosor de la pieza en bruto, la garra que sale (ClawForge.result_claw, para ClawMaterial.for_forge: la capa que se ve,
## si la hay), el de la bola de Verneuil del horno y la superficie de la pieza tallada o pulida (ClawForge.surface: la que
## deja la última muela o el último grano, por estación, para ClawMaterial.surface_image; unidad 5j). tint: el color de
## dibujo de un material que la biblioteca aún no tiene (el acrílico de la prótesis: se pinta como la queratina con su
## color) o «».
func look_view(sn: Dictionary) -> Dictionary:
	var p: Dictionary = sn.piece
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	var variety := String(rec.get("variety", ""))
	var mid := String(p.get("material", ACRYLIC if process == ACRYLIC else rec.get("product", stone if process == STONE else "zafiro")))
	var pol: Dictionary = sn.polish
	var sh: Dictionary = sn.sheath
	return {
		"optical": ClawOptics.optical_id(mid, variety), "finish": String(p.get("finish", "bruto")), "variety": variety,
		"grain_um": float(pol.grainUm) if bool(pol.get("ok", false)) else null,
		"thick_mm": float(sh.get("rawDiameterMm", 8.0)),
		"result": forge.result_claw(), "boule": ClawOptics.optical_id("rubi" if process == "rubi" else "zafiro", "" if process == "rubi" else "incoloro"),
		"surface": sn.get("surface", {}),
		"tint": material_color(mid) if not ClawOptics.MATERIALS.has(mid) else "",
	}


## Dónde se dibuja la pieza: «» (no hay), «horno» (en la marcha, sin enfriar o enfriándose dentro), «cubo» (templándose
## en agua o aceite), «banco» (enfriándose al aire o ya fría), «muela», «pulidora», «pistola» (recubriéndose) o «garra»
## (pegada, o la garra viva recubierta).
func _piece_at(sn: Dictionary, exists: bool) -> String:
	if process == LIVE:
		return "garra"
	if not exists:
		return ""
	var acting := not act.is_empty() and float(act.t) < float(act.dur)
	var kind := String(act.get("kind", ""))
	if running():
		return "horno"
	if acting:
		match kind:
			"cool_agua", "cool_aceite":
				return "cubo"
			"cool_horno":
				return "horno"
			"cool_aire":
				return "banco"
			"carve":
				return "muela"
			"pass":
				return String(TOOL_AT.get(String(act.get("tool", "")), "muela"))
			"fit":
				return "garra"
			"insert":
				if String(act.get("what", "")) == "pieza":
					return "horno"
			"polish":
				return "pulidora" if not bool((sn.bond as Dictionary).get("ok", false)) else "garra"
			"coat":
				return "pistola" if String(act.get("target", "funda")) == "funda" else "garra"
	if bool((sn.bond as Dictionary).get("ok", false)):
		return "garra"
	if (sn.cooled as Dictionary).is_empty() and not bool((sn.piece as Dictionary).get("bought", false)):
		return "horno"
	# 5r · en la mesa de soldar, desde que se colocan las piezas hasta la primera pasada o el pulido
	if _weld_bench and bool((sn.weld as Dictionary).get("on", false)):
		return "soldadura"
	# metida en el horno de calentar (5m), dentro hasta que se saca
	var ld: Dictionary = sn.loaded
	if String(ld.get("what", "")) == "pieza" and String(ld.get("machine", "")) == "calentar":
		return "horno"
	return "banco"


## La funda que se fabrica (de la forma elegida): { shape, wall, cover_mm, length_mm, wall_mm, area_mm2, volume_mm3,
## raw_diameter_mm, mass_text, texts } (sheath_geometry del motor).
func sheath_view() -> Dictionary:
	var sh: Dictionary = snap().sheath
	var mid := String(snap().piece.get("material", ACRYLIC if process == ACRYLIC else ForgeData.RECIPES.get(process, {}).get("product", stone)))
	var rho: Variant = ForgeData.density_of(mid)
	var mass := float(rho) * float(sh.volumeMm3) * 1.0e-9 if rho != null else -1.0
	var reach := forge.natural_mm()
	var gone := float(sh.get("goneMm", 0.0))
	var text := "%s mm de largo (cubre %s mm de los %s mm de la garra) · pared de %s mm · %s mm² para pegar" % [
		Js.to_fixed(float(sh.lengthMm), 1), Js.to_fixed(float(sh.coverMm), 1), Js.to_fixed(reach, 1), Js.to_fixed(float(sh.wallMm), 2), Js.to_fixed(float(sh.innerAreaMm2), 0)]
	if gone > 0.0:
		# la garra rota (unidad 5j): rehace lo que falta, maciza, y se pega sobre lo que queda
		text = "%s mm de largo: rehace los %s mm que faltan, maciza, y se pega sobre %s mm de lo que queda · pared de %s mm · %s mm² para pegar" % [
			Js.to_fixed(float(sh.lengthMm), 1), Js.to_fixed(minf(gone, float(sh.coverMm)), 1), Js.to_fixed(float(sh.get("stumpCoverMm", 0.0)), 1), Js.to_fixed(float(sh.wallMm), 2), Js.to_fixed(float(sh.innerAreaMm2), 0)]
	return {
		"shape": shape, "wall": wall, "cover_mm": float(sh.coverMm), "length_mm": float(sh.lengthMm), "wall_mm": float(sh.wallMm),
		"area_mm2": float(sh.innerAreaMm2), "volume_mm3": float(sh.volumeMm3), "raw_diameter_mm": float(sh.rawDiameterMm),
		"raw_volume_mm3": float(sh.rawVolumeMm3), "claw_mm": reach, "cover_frac": float(sh.coverMm) / maxf(reach, 1e-9),
		"gone_mm": gone, "stump_cover_mm": float(sh.get("stumpCoverMm", sh.coverMm)),
		"text": text,
		"raw_text": "sale de un cilindro de Ø %s mm y %s mm³ (se tallan %s mm³)" % [Js.to_fixed(float(sh.rawDiameterMm), 1), Js.to_fixed(float(sh.rawVolumeMm3), 0), Js.to_fixed(float(sh.rawVolumeMm3) - float(sh.volumeMm3), 0)],
		"mass_text": ("%s de %s" % [fmt_kg(mass), lower_first(String(ForgeData.inlay_entry(mid).name))]) if mass >= 0.0 and ForgeData.inlay_entry(mid) != null else "",
		"shapes": SHAPES.map(func(e: Dictionary) -> Dictionary: return { "id": e.id, "label": e.name, "title": e.what }),
		"walls": WALLS.map(func(e: Dictionary) -> Dictionary: return { "id": e.id, "label": "%s (%s mm)" % [String(e.name), Js.to_fixed(float(e.mm), 1)], "title": e.what }),
	}


# ════════════════════════════════ Recetas en tarjetas ════════════════════════════════

## Las tarjetas de lo que se puede fabricar (ClawForge.recipes() y las dos especiales), con todos sus textos: [{ id, name,
## product, powders [texto], temp, time, atmosphere, pressure, mold, methane, cool, growth, bench, bench_ok, quality,
## quality_text, source_short, fiction }].
func recipe_cards() -> Array:
	if not _card_cache.is_empty():
		return _card_cache.cards
	var out: Array = []
	for r: Dictionary in ClawForge.recipes():
		var pw: Array = []
		for p: Dictionary in r.powders:
			pw.append("%s (%s): %s%s" % [String(p.name), String(p.formula), fmt_pct(float(p.value)), (" (de %s a %s)" % [fmt_pct(float(p.min)), fmt_pct(float(p.max))]) if float(p.min) != float(p.max) else ""])
		if r.has("methane"):
			pw.append("metano en el hidrógeno: %s (de %s a %s)" % [fmt_pct(float(r.methane.value)), fmt_pct(float(r.methane.min)), fmt_pct(float(r.methane.max))])
		var td: Dictionary = r.temp_c
		var bench := _bench_words(String(r.product))
		out.append({
			"id": String(r.id), "name": String(r.name), "product": String(r.productName), "color": material_color(String(r.product)),
			"powders": pw, "mode": value_text("modo", String(r.mode)),
			"temp": "%s (bien de %s a %s)" % [fmt_c(float(td.value)), fmt_c(float(td.min)), fmt_c(float(td.max))],
			"time": time_words(r), "atmosphere": ", ".join((r.atmosphere.ok as Array).map(func(a: String) -> String: return lower_first(value_text("atmosphere", a)))),
			"pressure": "%s, sobre la línea de Kennedy" % fmt_mpa(float(r.pressure_mpa.value)) if String(r.method) == "hpht" else ("una fracción de la del aire" if String(r.method) == "cvd" else ("sin prensa" if String(r.atmosphere.value) == "vacio" else "la del aire")),
			"mold": value_text("mold", String(r.mold.value)) if r.has("mold") else "", "cool": ", ".join((r.cool.ok as Array).map(func(a: String) -> String: return lower_first(value_text("cool", a)))),
			"growth": _growth_words(r), "defects": _defect_words(r), "bench": String(bench.text), "bench_ok": bool(bench.ok),
			"quality": String(r.quality), "quality_text": String(QUALITY_TEXT.get(String(r.quality), "")),
			"source_short": short_source(String(r.source)), "source": readable(String(r.source)), "fiction": false,
		})
	var pe: Dictionary = ForgeData.PROSTHESIS[ACRYLIC]
	out.append({ "id": ACRYLIC, "name": "Acrílico dental (la prótesis de verdad)", "product": "un bloque de acrílico sobre lo que queda de la garra rota", "color": material_color(ACRYLIC),
		"powders": [], "mode": "sin horno", "temp": "fragua en frío", "time": "unos minutos", "atmosphere": "", "pressure": "", "mold": "", "cool": "",
		"growth": "", "defects": "Sobre una herida que sangra no agarra: primero hay que parar la sangre.",
		"bench": "Solo para una garra rota: se lima en la cetrería (el banco no lo tiene).", "bench_ok": false, "quality": String(pe.use_quality), "quality_text": String(QUALITY_TEXT.get(String(pe.use_quality), "")),
		"source_short": short_source(String(pe.use_source)), "source": readable(String(pe.use_source)), "fiction": false, "tag": "la vía real" })
	out.append({ "id": STONE, "name": "Piedra comprada", "product": "cuarzo, circonita, moissanita, hematites o cristal", "color": material_color(stone),
		"powders": [], "mode": "sin horno", "temp": "no se calienta", "time": "", "atmosphere": "", "pressure": "", "mold": "", "cool": "",
		"growth": "", "defects": "El calor la estropea: el cuarzo se agrieta al cruzar 573 °C deprisa, el diamante se quema al aire.",
		"bench": "El banco tiene todas estas piedras.", "bench_ok": true, "quality": "secondary", "quality_text": QUALITY_TEXT.secondary,
		"source_short": short_source(ForgeData.SRC_NASSAU_CZ + "; " + ForgeData.SRC_SIC_PVT), "source": readable(ForgeData.SRC_NASSAU_CZ + "; " + ForgeData.SRC_SIC_PVT), "fiction": false })
	out.append({ "id": LIVE, "name": "Recubrir la garra viva (FICCIÓN)", "product": "una capa de alúmina sobre la garra", "color": material_color("alumina"),
		"powders": [], "mode": "sin horno", "temp": "la capa a ~150 °C (proyección de plasma)", "time": "unos 30 s", "atmosphere": "", "pressure": "", "mold": "", "cool": "",
		"growth": "", "defects": "Más caliente o más tiempo: la punta se quema y la carne viva se lesiona.",
		"bench": "En el banco sigue siendo de queratina: la capa va aparte.", "bench_ok": false, "quality": "ficcion", "quality_text": QUALITY_TEXT.ficcion,
		"source_short": short_source(String(ForgeData.COATINGS.fundido.source)), "source": readable(String(ForgeData.COATINGS.fundido.source)), "fiction": true })
	_card_cache = { "cards": out }
	return out


func _growth_words(r: Dictionary) -> String:
	var g: Dictionary = r.get("growth", {})
	if g.is_empty():
		if r.has("shrink"):
			return "encoge un %s al sinterizar" % fmt_pct(float(r.shrink.value))
		return ""
	match String(g.kind):
		"mm_h":
			return "la bola crece ~%s mm/h (Ø de %s mm, hasta %s mm)" % [Js.to_fixed(float(g.value), 0), Js.to_fixed(float(g.diameter_mm), 0), Js.to_fixed(float(g.max_diameter_mm), 0)]
		"mg_h":
			return "el cristal crece %s-%s mg/h (hasta ~%s mm)" % [Js.to_fixed(float(g.min), 0), Js.to_fixed(float(g.max), 0), Js.to_fixed(float(g.max_diameter_mm), 0)]
		"um_h":
			return "la capa crece %s-%s µm/h" % [Js.to_fixed(float(g.min), 0), Js.to_fixed(float(g.max), 0)]
	return ""


## Lo que sale fuera de margen, en una frase (los defectos de la temperatura de la receta).
static func _defect_words(r: Dictionary) -> String:
	var td: Dictionary = r.temp_c
	return "Frío: %s Caliente: %s" % [String(td.low.text), String(td.high.text)]


## ¿Lo tiene ya el banco? { ok, text, inlay } (el propio material si el catálogo del banco lo tiene; si no, su gemelo).
func _bench_words(product: String) -> Dictionary:
	var e: Variant = ForgeData.inlay_entry(product)
	var nm := lower_first(String(e.name)) if e != null else product
	if Catalog.find_by_id(Catalog.INLAYS, product) != null:
		return { "ok": true, "inlay": product, "text": "El banco ya tiene %s %s." % ["la" if _feminine(nm) else "el", nm] }
	var twin := ForgeData.bench_twin(product)
	if twin != "" and Catalog.find_by_id(Catalog.INLAYS, twin) != null:
		return { "ok": true, "inlay": twin, "text": "En el banco va como %s, su gemelo (la misma mecánica)." % lower_first(String(ForgeData.inlay_entry(twin).name)) }
	return { "ok": false, "inlay": "", "text": "El banco aún no tiene la %s: se puede fabricar, pero no probar en el banco." % nm }


# ════════════════════════════════ El tutorial en la vista ════════════════════════════════

## El panel del tutorial: { on, done, id, name, tutorials [{ id, name, state }], index, count, step { id, title, text,
## source, source_short, check, done, status, status_text, mistake, action }, highlight, control }.
func tutorial_view() -> Dictionary:
	var tuts: Array = []
	for id: String in TUTORIALS:
		tuts.append({ "id": id, "name": String(ForgeTutorial.PROCESS_NAMES.get(id, id)), "state": "ahora" if id == tut_id else "luego" })
	var ss := steps()
	# 5w · al terminar, qué sigue: el del horno no hace pieza (antes decía «pásala a la cetrería» sin pieza)
	var done_text := "Ya has recorrido todos los pasos. Mira la ficha de la garra, antes y después, y pásala a la cetrería o al banco."
	if tut_id == GENERAL:
		done_text = "Ya conoces los mandos del horno. Ahora elige arriba una receta (el zafiro, el metal duro, el oro…): su tutorial te lleva paso a paso, desde pesar los polvos hasta la funda terminada."
	var out := { "on": tutorial_on, "done": tutorial_done(), "id": tut_id, "name": String(ForgeTutorial.PROCESS_NAMES.get(tut_id, tut_id)),
		"tutorials": tuts, "index": tut_step, "count": ss.size(), "step": {}, "highlight": "", "control": "", "done_text": done_text }
	var st := current_step()
	if st.is_empty():
		return out
	var status := "info"
	if String(st.check) != "":
		status = "hecho" if bool(st.done) else "pendiente"
	var line := "Paso informativo: pulsa «Siguiente» cuando lo tengas."
	if status == "hecho":
		line = "Se cumple: %s. Pulsa «Siguiente (N)»." % String(CHECK_WORDS.get(String(st.check), String(st.check)))
	elif status == "pendiente":
		line = "Pendiente: %s." % String(CHECK_WORDS.get(String(st.check), String(st.check)))
		var rh := restart_hint()
		if rh != "":
			line += " " + rh
	out["step"] = {
		"id": String(st.id), "title": String(st.title), "text": String(st.text), "source": readable(String(st.source)),
		"source_short": short_source(String(st.source)), "check": String(st.check), "done": st.done, "status": status,
		"status_text": ((tut_skipped + " ") if tut_skipped != "" else "") + line, "skipped": tut_skipped, "mistake": String(st.mistake), "action": String(st.action), "completed": _done.has(_key(String(st.id))),
	}
	out["highlight"] = String(STEP_HIGHLIGHT.get(String(st.id), ""))
	out["control"] = String(STEP_CONTROLS.get(String(st.id), ""))
	return out


# ════════════════════════════════ Lecturas, ficha y fuentes ════════════════════════════════

## Lecturas: [{ id, label, value, note, tone («bien» | «aviso» | «mal» | «») }].
func readouts() -> Array:
	var out: Array = []
	var sn := snap()
	var rv := run_view()
	var stage := forge.stage()
	out.append(_row("etapa", "Etapa", String(STAGE_NAMES.get(stage, stage)), String(ForgeTutorial.PROCESS_NAMES.get(process, process)), ""))
	# 5r · la costura de la mesa de soldar
	var ws: Dictionary = sn.weld
	if bool(ws.get("on", false)):
		var j: Dictionary = ws.joint
		var wv := "%d de %d %s" % [int(ws.covered), int(ws.pulsesNeed), "tramos" if String(ws.method) == "braze" else "puntos"]
		var wn := ""
		var wt := ""
		if bool(ws.done):
			wv = ("unión: ~%s MPa de los %s del metal" % [Js.to_fixed(float(j.jointMPa), 0), Js.to_fixed(float(j.baseMPa), 0)]) if bool(j.ok) else "ha fallado"
			wn = String(j.get("limitedBy", "")) if bool(j.ok) else String(j.get("defect", "")).replace("_", " ")
			wt = "bien" if bool(j.ok) else "mal"
		elif not bool(ws.ready):
			wv = "no se puede soldar"
			wn = String(ws.defect).replace("_", " ")
			wt = "mal"
		elif not bool(ws.aligned):
			wn = "desalineadas %s mm" % Js.to_fixed(float(ws.alignMm), 2)
			wt = "aviso"
		out.append(_row("soldadura", "Soldadura", wv, wn, wt))
	# el horno
	var furnace := "apagado"
	var fnote := "mandos: %s · %s · %s" % [control_text("modo"), control_text("temp_c"), control_text("time_s")]
	var ftone := ""
	if not rv.is_empty():
		var life := String(clock_view().life) if _clock == "run" else ""
		match String(rv.phase):
			"calentar":
				furnace = "calentando: %s de %s" % [fmt_c(float(rv.temp_c)), fmt_c(float(rv.set_c))]
				fnote = life
			"mantener":
				furnace = "a %s · %s de %s de verdad" % [fmt_c(float(rv.set_c)), fmt_time(float(rv.proc_s)), fmt_time(float(rv.time_s))]
				fnote = life
			"quemar":
				furnace = "quemando la cera a %s · %s de %s de verdad" % [fmt_c(float(rv.temp_c)), fmt_time(float(rv.proc_s)), fmt_time(float(rv.time_s))]
				fnote = life
			"colar":
				furnace = "colando en el molde"
			"listo":
				furnace = "terminado" if bool(rv.ok) else "terminado con un defecto"
				ftone = "bien" if bool(rv.ok) else "mal"
				fnote = String(last.get("burnout" if bool(rv.burnout) else ("heat" if bool(rv.heat) else "fire"), {}).get("text", ""))
	if process != LIVE:
		out.append(_row("horno", "Horno", furnace, fnote, ftone))
		# lo que hay dentro de la máquina del modo (5m)
		var iv := inside_view()
		var in_val := String(iv.inside_name) if String(iv.inside) != "" else ("vacía: mete %s (M)" % String(iv.next_name) if String(iv.next) != "" else "vacía")
		out.append(_row("dentro", "Dentro de la máquina", in_val, "%s: %s" % [String(iv.name), String(iv.where)], "bien" if String(iv.inside) != "" else ("aviso" if String(iv.next) != "" else "")))
		# el color del calor
		var tc := piece_temp_c()
		out.append(_row("brillo", "Color del calor", Incandescence.glow_text(tc), "%s · se pinta como un cuerpo negro (Planck y la CIE); la palabra es la de los herreros (TM 9-237)" % fmt_c(tc), ""))
	# lo que crece
	if not rv.is_empty() and String(rv.unit) != "":
		var g := "%s %s de %s %s que pide la funda" % [Js.to_fixed(float(rv.grown), 1 if String(rv.unit) == "mm" else 0), String(rv.unit), Js.to_fixed(float(rv.need), 1 if String(rv.unit) == "mm" else 0), String(rv.unit)]
		out.append(_row("crece", "Crece", g, _growth_words(ForgeData.RECIPES.get(process, {})), "bien" if float(rv.grown) >= float(rv.need) - 1e-9 else ""))
	elif not rv.is_empty() and float(rv.shrink) > 0.0:
		out.append(_row("crece", "Encoge", "un %s de %s" % [fmt_pct(float(rv.shrink)), fmt_pct(float(ForgeData.RECIPES[process].shrink.value))], "al cerrarse los poros", ""))
	# la pieza
	var pv := piece_view()
	if bool(pv.exists):
		out.append(_row("pieza", "La pieza", "%s · %s" % [String(pv.name), lower_first(String(pv.finish_name))], String(pv.text), "bien" if bool(pv.ok) else "mal"))
	var shv := sheath_view()
	if process != LIVE:
		out.append(_row("funda", "La funda", "%s · %s mm" % [String(_find(SHAPES, shape).name), Js.to_fixed(float(shv.length_mm), 1)], String(shv.mass_text), ""))
	# la carne viva (ficción)
	var coat: Dictionary = sn.coat
	if bool(coat.get("fiction", false)) and coat.get("thermal") != null:
		var th: Dictionary = coat.thermal
		out.append(_row("carne", "Carne viva (FICCIÓN)", "%s °C de pico" % Js.to_fixed(float(th.quickPeakC), 1),
			"la queratina a %s · dolor desde %s °C" % [fmt_c(float(th.keratinPeakC)), Js.to_fixed(float(CareData.THERMAL.pain_c.value), 0)],
			"mal" if bool(th.injured) or bool(th.charred) else ("aviso" if bool(th.pain) else "bien")))
	# la cera perdida, el tallado por pasadas y la prueba del ajuste (5m)
	var lw := lost_wax_view()
	if bool(lw.on) and not (String(lw.next) in ["", "hecho"]):
		var lw_last := String((lw.wax as Dictionary).get("text", "")) if String(lw.next) == "revestir" else (String((lw.invest as Dictionary).get("text", "")) if String(lw.next) == "quemar" else String(lw.next_text))
		out.append(_row("cera", "Cera perdida", String({ "cera": "falta el modelo de cera", "revestir": "falta revestirla", "quemar": "falta quemar la cera", "colar": "lista para colar", "enfriar": "colada: falta enfriar", "romper": "falta romper el molde" }.get(String(lw.next), "")), lw_last, ""))
	var cs: Dictionary = sn.cut
	if bool(pv.exists) and not (sn.cooled as Dictionary).is_empty() and process != ACRYLIC and process != LIVE:
		var words := { "sin_empezar": "sin empezar", "tocho": "falta el tocho", "desbaste": "desbastando", "casi": "casi", "vaciar": "falta vaciarla", "correcta": "correcta", "fina": "pasada de la silueta", "rota": "rota" }
		var cval := String(words.get(String(cs.verdict), ""))
		if int(cs.passes) > 0:
			cval += " · %d pasadas, %s de verdad" % [int(cs.passes), fmt_time(float(cs.timeS))]
		out.append(_row("forma", "La forma", cval, String(cs.text), String(cs.tone)))
	var fit: Dictionary = sn.fit
	if not fit.is_empty():
		out.append(_row("ajuste", "El ajuste", ("entra con %s mm de holgura" % Js.to_fixed(float(fit.gapMm), 3)) if bool(fit.get("enters", false)) else "no entra", String(fit.text), "bien" if bool(fit.ok) else "mal"))
	if bool((sn.bond as Dictionary).get("ok", false)):
		out.append(_row("union", "Unión", "aguanta ~%s N" % Js.to_fixed(float(sn.bond.capacityN), 0), "manda %s" % ("la queratina" if String(sn.bond.limitedBy) == "queratina" else "el adhesivo"), "bien"))
	if not (sn.check as Dictionary).is_empty():
		out.append(_row("carga", "Con la carga", "aguanta" if bool(sn.check.ok) else "se despega", String(sn.check.text), "bien" if bool(sn.check.ok) else "mal"))
	return out


static func _row(id: String, label: String, value: String, note: String, tone: String) -> Dictionary:
	return { "id": id, "label": label, "value": value, "note": note, "tone": tone }


## La ficha de la garra antes → después: { rows [{ id, label, before, after, tone, note }], verdict, verdict_text, quality,
## quality_text, fiction [razones], advice [{ text, source }] }.
func result_sheet() -> Dictionary:
	var rep := forge.report()
	var rc: Dictionary = rep.facts.claw
	var a := _start_claw
	var claw := CareData.claw_entry(String(setup.claw))
	var rows: Array = []
	var mat_after := "queratina"
	var hv_after := float(claw.hv)
	var e_after := float(claw.E)
	if String(rc.inlay) != "none":
		mat_after = lower_first(String(rc.name))
		hv_after = float(rc.hv)
		e_after = float(rc.E)
	elif rc.coating != null:
		mat_after = "queratina con una capa de %s (%s µm)" % [lower_first(String(ForgeData.inlay_entry(String(rc.coating.material)).name)) if ForgeData.inlay_entry(String(rc.coating.material)) != null else String(rc.coating.material), Js.to_fixed(float(rc.coating.thicknessUm), 0)]
		if rc.coating.hv != null:
			hv_after = float(rc.coating.hv)
	rows.append(_sheet_row("material", "Material", "queratina", mat_after, "aviso" if String(rc.quality) == "ficcion" else "", ""))
	rows.append(_sheet_row("dureza", "Dureza", "%s HV" % CareState.grouped(float(claw.hv)), "%s HV" % CareState.grouped(hv_after), "bien" if hv_after > float(claw.hv) else "", "la de la superficie (la de la capa, si la hay)"))
	rows.append(_sheet_row("modulo", "Módulo", "%s GPa" % Js.to_fixed(float(claw.E), 1), "%s GPa" % Js.to_fixed(e_after, 1 if e_after < 100.0 else 0), "", ""))
	rows.append(_sheet_row("masa", "Masa de la garra", fmt_kg(float(a.clawMassKg)), fmt_kg(float(rc.clawMassKg)), "", "queratina más la funda"))
	rows.append(_sheet_row("acabado", "Acabado", "natural", lower_first(String(ForgeData.FINISH_NAMES.get(String(rc.finish), "—"))) if String(rc.finish) != "" else "—", "mal" if String(rc.finish) in ["agrietado", "astillado", "quemado", "defectuoso"] else "", ""))
	var r0 := ClawSharpness.radius_um_of_area(float(claw.area))
	rows.append(_sheet_row("punta", "Radio de la punta", Format.fmt_tip_um(r0), Format.fmt_tip_um(float(rc.tipRadiusUm)) if rc.tipRadiusUm != null else Format.fmt_tip_um(r0), "", "pulir no afila; afilar la deja del grano"))
	if rc.bond != null:
		rows.append(_sheet_row("union", "Unión", "—", "%s: ~%s N" % [lower_first(String(ForgeData.ADHESIVES.get(String(rc.bond.adhesive), {}).get("name", rc.bond.adhesive))), Js.to_fixed(float(rc.bond.capacityN), 0)], "bien", "manda %s" % ("la queratina" if String(rc.bond.limitedBy) == "queratina" else "el adhesivo")))
	rows.append(_sheet_row("calidad", "Calidad", "—", String(QUALITY_TEXT.get(String(rep.quality), String(rep.quality))) if String(rep.quality) != "" else "—", "aviso" if String(rep.quality) == "ficcion" else "", ""))
	var adv: Array = []
	for ad: Dictionary in rep.advice:
		adv.append({ "text": String(ad.text), "source": short_source(String(ad.source)) })
	return { "rows": rows, "verdict": String(rep.verdict), "verdict_text": String(rep.verdictText), "quality": String(rep.quality),
		"quality_text": String(QUALITY_TEXT.get(String(rep.quality), "")), "fiction": rep.fiction, "advice": adv, "finish": String(rep.finish) }


static func _sheet_row(id: String, label: String, before: String, after: String, tone: String, note: String) -> Dictionary:
	return { "id": id, "label": label, "before": before, "after": after, "tone": tone, "note": note }


## Lo que se lleva a la cetrería (para limarla y pulirla allí): ClawForge.care_setup() con la pata y la garra de las que
## vino, y si ya se puede (el motor da un material). { ok, setup, text, reason }.
func care_view() -> Dictionary:
	var fc: Dictionary = setup.get("from_care", {})
	var block := fc.has("stump_mm")
	var cs := forge.care_setup(fc) if block else forge.care_setup()
	var ok := bool(cs.get("careSupported", true)) and (cs.has("block") if block else String(cs.get("inlay", "none")) != "none")
	var s := cs.duplicate(true)
	# el bloque va tal cual a ClawCareState.reforge_with (que mira careSupported); la funda entera, a configure()
	if not block:
		s.erase("careSupported")
	s.erase("reason")
	if setup.has("paw"):
		s["paw"] = String(setup.paw)
	if setup.has("digit"):
		s["digit"] = String(setup.digit)
	var text := ""
	if ok and block:
		var b: Dictionary = cs.block
		var be: Variant = ForgeData.inlay_entry(String(b.material))
		text = "A la cetrería como un bloque en bruto de %s pegado al muñón, con %s mm de sobra: allí se le da forma con una lima o una amoladora más dura que él. %s" % [lower_first(String(be.name)) if be != null else String(b.material), Js.to_fixed(float(b.wall_mm), 1), String(b.note)]
	elif ok:
		# la funda terminada y sin pegar (5m; petición 43): se coloca y se acaba a mano en la cetrería
		var e: Variant = ForgeData.inlay_entry(String(cs.inlay))
		var pc: Dictionary = cs.get("piece", {})
		var fit_txt := (" Entra en la garra con %s mm de holgura." % Js.to_fixed(float(pc.gapMm), 3)) if bool(pc.get("fitTested", false)) else ""
		text = "La funda de %s, terminada y sin pegar.%s En la cetrería, sobre el animal, se coloca a mano (se pega con su adhesivo) y se acaba: las rebabas, la forma y el afilado, con una herramienta más dura que ella." % [lower_first(String(e.name)) if e != null else String(cs.inlay), fit_txt]
	elif String(cs.get("reason", "")) != "":
		text = String(cs.reason)
		if block and process != ACRYLIC:
			text += " La vía real es el acrílico dental: se mezcla aquí y se lima en la cetrería."
	else:
		text = "Primero hay que terminar la funda: tallada (o colada y limada), con la carne viva protegida y pulida. La prueba del ajuste, si quieres, antes de pasarla."
	return { "ok": ok, "setup": s, "text": text, "reason": String(cs.get("reason", "")), "block": block }


## Lo que se lleva al banco de ensayo («Probar en el banco»): la garra del banco de este animal, el material (el propio si
## el banco lo tiene; si no, su gemelo con la misma mecánica, ForgeData.bench_twin) y el afilado de la punta. {} si aún no
## hay garra o el banco no tiene ese material. { claw, inlay, sharpness, note }.
func bench_setup() -> Dictionary:
	var rc := forge.result_claw()
	if not bool(rc.ok) or String(rc.inlay) == "none":
		return {}
	var b := _bench_words(String(rc.inlay))
	if not bool(b.ok):
		return {}
	return { "claw": String(setup.claw), "inlay": String(b.inlay), "sharpness": float(rc.sharpness), "note": String(b.text) }


## Los datos de lo que se fabrica, con su valor, su calidad y su fuente legible: [{ label, value, quality, quality_text,
## source }].
func values_table() -> Array:
	var out: Array = []
	var f := ForgeData.FURNACE
	out.append(_val("El horno que lo junta todo", "ficción en conjunto: cada modo es una máquina real", String(f.quality), String(f.source)))
	var rec: Dictionary = ForgeData.RECIPES.get(process, {})
	if not rec.is_empty():
		var td: Dictionary = rec.temp_c
		out.append(_val("Temperatura de la receta", "%s (de %s a %s)" % [fmt_c(float(td.value)), fmt_c(float(td.min)), fmt_c(float(td.max))], String(td.quality), String(td.source)))
		var tm: Dictionary = rec.time_s
		out.append(_val("Tiempo", time_words(rec), String(tm.quality), String(tm.source)))
		if rec.has("growth"):
			out.append(_val("Ritmo de crecimiento", _growth_words(rec), String(rec.growth.quality), String(rec.growth.source)))
		out.append(_val("Presión", fmt_mpa(float(rec.pressure_mpa.value)), String(rec.pressure_mpa.quality), String(rec.pressure_mpa.source)))
		out.append(_val("Atmósfera", ", ".join((rec.atmosphere.ok as Array).map(func(a: String) -> String: return lower_first(value_text("atmosphere", a)))), "secondary", String(rec.atmosphere.source)))
		if rec.has("mold"):
			out.append(_val("Molde", value_text("mold", String(rec.mold.value)), "secondary", String(rec.mold.source)))
		out.append(_val("Enfriar", ", ".join((rec.cool.ok as Array).map(func(a: String) -> String: return lower_first(value_text("cool", a)))), "secondary", String(rec.cool.source)))
		for p: Dictionary in rec.powders:
			var d: Dictionary = ForgeData.POWDERS[p.id]
			out.append(_val(String(d.name), "%s (de %s a %s)" % [fmt_pct(float(p.value)), fmt_pct(float(p.min)), fmt_pct(float(p.max))], String(rec.quality), String(d.source)))
	var mid := ACRYLIC if process == ACRYLIC else String(ForgeData.RECIPES.get(process, {}).get("product", stone if process == STONE else "alumina"))
	var m := ForgeData.material(mid)
	if process == ACRYLIC:
		var pe: Dictionary = ForgeData.PROSTHESIS[ACRYLIC]
		out.append(_val(String(pe.name), "~%s HV · %s GPa · %s MPa a flexión · %s g/cm³" % [Js.to_fixed(float(pe.hv), 0), Js.to_fixed(float(pe.E), 1), Js.to_fixed(float(pe.strength_mpa), 1), Js.to_fixed(float(pe.density) / 1000.0, 2)], String(pe.quality), String(pe.source)))
		out.append(_val("Conduce el calor", "%s W/(m·K) · %s J/(kg·K)" % [Js.to_fixed(float(m.k.value), 2), CareState.grouped(float(m.cp.value))], String(m.k.quality), String(m.k.source) + "; " + String(m.cp.source)))
		out.append(_val("La prótesis en una garra", "la técnica del pico de las aves", String(pe.use_quality), String(pe.use_source)))
	for key: String in ["melt_c", "soften_c", "air_c", "inert_c", "inversion_c"]:
		if m.get(key) != null:
			var lab := String({ "melt_c": "Funde a", "soften_c": "Se reblandece a", "air_c": "Al aire se degrada desde", "inert_c": "Sin aire se degrada desde", "inversion_c": "Cambia de fase a" }[key])
			out.append(_val("%s (%s)" % [lab, lower_first(String(ForgeData.inlay_entry(mid).name))], fmt_c(float(m[key].value)), String(m[key].quality), String(m[key].source)))
	var sh := ForgeData.SHEATH
	out.append(_val("La funda de serie", "el 40 % de la garra desde la punta, con 1 mm de pared", String(sh.quality), String(sh.source)))
	out.append(_val("La forma elegida", "%s · %s" % [String(_find(SHAPES, shape).name), lower_first(String(_find(WALLS, wall).name))], "estimate", "elección del ensayo: el motor calcula la funda con ella"))
	var ab: Dictionary = ForgeData.ABRASIVES[String(carve_p.abrasive)]
	out.append(_val(String(ab.name), "%s HV" % CareState.grouped(float(ab.hv)), String(ab.quality), String(ab.source)))
	var cd := ForgeData.CARVE_DEFAULTS
	out.append(_val("La muela de serie", "%s N, %s m/s, contacto de %s × %s mm" % [Js.to_fixed(float(cd.force_n), 0), Js.to_fixed(float(cd.speed_ms), 0), Js.to_fixed(float(cd.contact_mm), 0), Js.to_fixed(float(cd.contact_mm), 0)], String(cd.quality), String(cd.source)))
	var b: Dictionary = ForgeData.BARRIERS[String(barrier_p.barrier)]
	out.append(_val(String(b.name), "%s W/(m·K), aguanta %s" % [Js.to_fixed(float(b.k), 3), fmt_c(float(b.max_c)) if is_finite(float(b.max_c)) else "100 °C mientras le queda agua"], String(b.quality), String(b.source)))
	var c: Dictionary = ForgeData.COATINGS[String(coat_p.method)]
	out.append(_val(String(c.name), "la pieza a %s · %s de capa" % [fmt_c(float(c.t_c)), fmt_um(float(c.thick_um))] if String(coat_p.method) != "fundido" else "su fusión", String(c.quality), String(c.source)))
	var ad: Dictionary = ForgeData.ADHESIVES.get(String(bond_p.adhesive), {})
	if not ad.is_empty():
		out.append(_val(String(ad.name), "%s MPa · holgura de hasta %s mm" % [Js.to_fixed(float(ad.tau), 1), Js.to_fixed(float(ad.gap_max), 2)], String(ad.quality), String(ad.source)))
	# 5r · la mesa de soldar: el método elegido y lo que decide la unión
	var wm: Dictionary = ClawWeld.METHODS[String(weld_p.method)]
	out.append(_val(String(wm.name), String(wm.machine), String(wm.quality), String(wm.source)))
	match String(weld_p.method):
		"laser":
			out.append(_val("Los modos del láser", "conducción por debajo de %s MW/cm², ojo de cerradura por encima de %s" % [Js.to_fixed(float(ClawWeld.DENSITY.conduction), 1), Js.to_fixed(float(ClawWeld.DENSITY.keyhole), 1)], String(ClawWeld.DENSITY.quality), String(ClawWeld.DENSITY.source)))
			out.append(_val("Lo que funde del pulso", "en conducción, la absorción por %s; en ojo de cerradura, %s" % [Js.to_fixed(float(ClawWeld.MELT_EFF_CONDUCTION.value), 1), Js.to_fixed(float(ClawWeld.KEYHOLE_COUPLING.value), 3)], String(ClawWeld.KEYHOLE_COUPLING.quality), String(ClawWeld.KEYHOLE_COUPLING.source)))
		"tig":
			out.append(_val("El arco del micro-TIG", "%s V, rendimiento %s, fuente de %s mm" % [Js.to_fixed(float(ClawWeld.ARC.volts), 0), Js.to_fixed(float(ClawWeld.ARC.efficiency), 2), Js.to_fixed(float(ClawWeld.ARC.spot_mm), 0)], String(ClawWeld.ARC.quality), String(ClawWeld.ARC.source)))
		_:
			out.append(_val("La plata y su fundente", "sólido-líquido %s-%s °C, el fundente hasta ~%s °C, holgura de %s a %s mm" % [Js.to_fixed(float(ForgeData.BRAZE.t_min), 0), Js.to_fixed(float(ForgeData.BRAZE.t_max), 0), Js.to_fixed(float(ClawWeld.BRAZE.flux_max_c), 0), Js.to_fixed(float(ClawWeld.BRAZE.gap_min_mm), 3), Js.to_fixed(float(ClawWeld.BRAZE.gap_max_mm), 3)], String(ClawWeld.BRAZE.quality), String(ClawWeld.BRAZE.source)))
	var jf_id := "titanio_" + String(weld_p.gas) if String(weld_p.material) == "titanio" and String(weld_p.gas) != "argon" else String(weld_p.material)
	var jf: Dictionary = ClawWeld.JOINT_FACTOR.get(jf_id, ClawWeld.JOINT_FACTOR.get("acero"))
	out.append(_val("Lo que aguanta la unión frente al metal base", "como mucho el %s %%; nunca más que el metal base" % Js.to_fixed(float(jf.value) * 100.0, 0), String(jf.quality), String(jf.source)))
	if String(weld_p.material) == "titanio":
		out.append(_val("El color de la zona soldada del titanio", "plateado o pajizo con argón, azul o gris sin él", "secondary", ClawWeld.COLOR_SOURCE))
	# 5m · la máquina del modo, la cera perdida y el tallado por pasadas
	var mach: Dictionary = ForgeData.MACHINES.get(_run_kind(), {})
	if not mach.is_empty():
		out.append(_val("La máquina del modo", "%s: %s" % [String(mach.name), String(mach.where)], String(mach.quality), String(mach.source)))
	if not rec.is_empty() and String(rec.get("form", "")) == "colada" and ForgeData.CAST.has(String(rec.product)):
		var cast: Dictionary = ForgeData.CAST[String(rec.product)]
		out.append(_val("Lo que encoge al colarse", "%s lineal" % fmt_pct(float(cast.shrink.value)), String(cast.shrink.quality), String(cast.shrink.source)))
		var inv := ClawForge.investment_of(String(dial.mold), String(rec.product))
		out.append(_val(String(inv.name), "se dilata un %s · fragua %s" % [fmt_pct(float(inv.expansion.value)), fmt_time(float(inv.set_s.value))], String(inv.expansion.quality), String(inv.expansion.source) + "; " + String(inv.set_s.source)))
		var plan := ClawForge.burnout_plan(String(dial.mold), String(rec.product), float(ForgeData.BURNOUT.get("vidrio" if String(rec.product) == "vidrio" and String(dial.mold) == "yeso" else String(dial.mold), {}).get("top_c", 0.0)), float(ForgeData.BURNOUT.get("vidrio" if String(rec.product) == "vidrio" and String(dial.mold) == "yeso" else String(dial.mold), {}).get("top_hold_s", 0.0)))
		if not plan.is_empty():
			out.append(_val("El quemado de la cera", "%s arriba durante %s; el ciclo entero, %s de verdad" % [fmt_c(float(plan.topC)), fmt_time(float(plan.topHoldS)), fmt_time(float(plan.realS))], String(plan.quality), String(plan.source)))
		var sp: Dictionary = ForgeData.SPRUE
		out.append(_val("El bebedero", "su módulo, %s veces el de lo más grueso de la pieza" % Js.to_fixed(float(sp.modulus_factor.value), 1), String(sp.modulus_factor.quality), String(sp.modulus_factor.source)))
	elif not rec.is_empty() or process == STONE:
		var nc := ClawForge.castable(rec, stone if process == STONE else "")
		if not bool(nc.ok):
			out.append(_val("¿Se cuela en un molde?", String(nc.text), "secondary", String(nc.source)))
	var tl: Dictionary = ForgeData.CARVE_TOOLS[carve_tool]
	out.append(_val(String(tl.name), String(tl.machine), String(tl.quality), String(tl.source)))
	out.append(_val("Una pasada suave", "la cuarta parte de una normal", String(ForgeData.CARVE_LIGHT.quality), String(ForgeData.CARVE_LIGHT.source)))
	out.append(_val("La forma, a ojo", "lo que sobra o falta, como mucho %s mm" % Js.to_fixed(float(ForgeData.SHAPE_TOL.value), 2), String(ForgeData.SHAPE_TOL.quality), String(ForgeData.SHAPE_TOL.source)))
	out.append(_val("La pieza en su palo", "pegada con cera de lapidario para tallarla", "secondary", ForgeData.SRC_DOP))
	out.append(_val("Enfriarse hasta cogerla", "hasta %s, con la capacidad concentrada" % fmt_c(float(ForgeData.COOL_HANDLE_C.value)), String(ForgeData.COOL_HANDLE_C.quality), String(ForgeData.COOL_HANDLE_C.source) + "; " + ForgeData.SRC_INCROPERA))
	var ks := ForgeData.KERATIN_SHEAR
	out.append(_val("La queratina bajo la unión", "%s MPa de cortante" % Js.to_fixed(ClawForge.keratin_shear_mpa(String(setup.humidity)), 2), String(ks.quality), String(ks.source)))
	out.append(_val("El color del calor", "cuerpo negro de Planck con el observador de la CIE, en sRGB", Incandescence.QUALITY, Incandescence.SOURCE))
	out.append(_val("Las palabras del color", "las de los colores de calor del acero en la forja", "secondary", Incandescence.SRC_TM9237))
	return out


## values_table() una vez por cambio de lo que enseña (el proceso, la piedra, la forma, los ajustes del taller y la
## humedad); el array publicado no se vuelve a tocar.
func values_cached() -> Array:
	var key := var_to_str([process, stone, shape, wall, carve_p.abrasive, barrier_p.barrier, coat_p.method, bond_p.adhesive, setup.humidity, carve_tool, dial.modo, dial.mold, weld_p.method, weld_p.material, weld_p.gas])
	if key != _values_key:
		_values_key = key
		_values = values_table()
	return _values


func _val(label: String, value: String, quality: String, source: String) -> Dictionary:
	return { "label": label, "value": value, "quality": quality, "quality_text": String(QUALITY_TEXT.get(quality, "")), "source": short_source(source), "source_full": readable(source) }


## Los últimos sucesos de la pieza, con la fuente legible (el más nuevo primero).
func events_view() -> Array:
	var ev := forge.events()
	var out: Array = []
	for i in range(maxi(ev.size() - EVENTS_SHOWN, 0), ev.size()):
		var e: Dictionary = ev[i]
		out.append({ "code": String(e.code), "message": String(e.message), "source": readable(String(e.source)), "source_short": short_source(String(e.source)) })
	out.reverse()
	return out


## El sonido que pide el estado ahora (bus «Lab»): { loop (un id de SFX_FORGE o «»), volume, pitch }. Diseño de sonido:
## el bucle de la máquina mientras trabaja (el horno, la llama, la bobina o la prensa) y el de la muela mientras talla, con
## su tono a la velocidad de la muela (pitch = v / la de serie); al subir la temperatura, el horno suena algo más fuerte.
func sound_view() -> Dictionary:
	if running():
		var rv := run_view()
		var vol := 0.55 + 0.25 * clampf(float(rv.temp_c) / maxf(float(rv.set_c), 1.0), 0.0, 1.0)
		return { "loop": String(run.loop), "volume": vol, "pitch": 1.0 }
	if weld_hold and weld_u >= 0.0 and String(weld_p.method) == "braze" and _weld_bench:
		# 5r · el soplete de la soldadura fuerte sobre la costura: la llama
		return { "loop": "forja-llama", "volume": 0.45, "pitch": 1.0 }
	if not act.is_empty() and float(act.t) < float(act.dur):
		if String(act.kind) == "carve" and bool(last.get("carve", {}).get("bites", false)):
			return { "loop": "forja-muela", "volume": 0.6, "pitch": clampf(float(carve_p.speed_ms) / float(ForgeData.CARVE_DEFAULTS.speed_ms), 0.5, 2.0) }
		if String(act.kind) == "pass" and bool(act.get("bites", false)):
			# la pasada: la máquina de su herramienta, con el tono a la velocidad del borde frente a la de la muela de serie
			var tl: Dictionary = ForgeData.CARVE_TOOLS.get(String(act.get("tool", "")), {})
			return { "loop": "forja-muela", "volume": 0.6, "pitch": clampf(float(tl.get("speed_ms", ForgeData.CARVE_DEFAULTS.speed_ms)) / float(ForgeData.CARVE_DEFAULTS.speed_ms), 0.5, 2.0) }
		if String(act.kind) == "coat" and String(last.get("coat", {}).get("defect", "")) != "garra_quemada":
			return { "loop": "forja-horno", "volume": 0.4, "pitch": 1.0 }
	return { "loop": "", "volume": 0.0, "pitch": 1.0 }


## Los rótulos con números que se ven en la escena 3D: la pantalla de la balanza (en gramos con cuatro decimales, como una
## analítica de laboratorio, 5w), el manómetro de la prensa, el termómetro de la carne viva (ficción) y la pesa de la prueba.
func labels_view(sn: Dictionary) -> Dictionary:
	var rv := run_view()
	var gauge := fmt_mpa(float(dial.pressure_mpa))
	if not rv.is_empty() and String(rv.kind) == "hpht":
		gauge = "%s · %s" % [fmt_mpa(float(rv.pressure_mpa)), fmt_c(float(rv.temp_c))]
	var q: float = CareData.THERMAL.bed_c.value
	var coat: Dictionary = sn.coat
	# el tono del termómetro, el del motor: «bien» sin dolor, «aviso» si duele (pain_c), «mal» si se lesiona (la dosis)
	var tone := "bien"
	if coat.get("thermal") != null:
		q = float(coat.thermal.quickPeakC)
		tone = "mal" if bool(coat.thermal.get("injured", false)) else ("aviso" if bool(coat.thermal.get("pain", false)) else "bien")
	var chk: Dictionary = sn.check
	return {
		"scale": scale_text(), "gauge": gauge, "thermo": "Carne viva\n%s °C" % Js.to_fixed(q, 1),
		"thermo_c": q, "thermo_tone": tone, "weight": ("%s N · %s" % [Js.to_fixed(float(chk.loadN), 0), "aguanta" if bool(chk.ok) else "se despega"]) if not chk.is_empty() else "",
	}


## Todo lo que pintan la escena y la página (un diccionario nuevo).
func view() -> Dictionary:
	var sn := snap()
	var claw := CareData.claw_entry(String(setup.claw))
	return {
		"serial": _serial, "setup": setup.duplicate(true), "process": process, "process_name": String(ForgeTutorial.PROCESS_NAMES.get(process, process)),
		"stone": stone, "stones": STONES.map(func(id: String) -> Dictionary: return { "id": id, "label": String(ForgeData.inlay_entry(id).short), "title": "%s, %s HV" % [String(ForgeData.inlay_entry(id).name), CareState.grouped(float(ForgeData.inlay_entry(id).hv))] }),
		"stage": forge.stage(), "stage_name": String(STAGE_NAMES.get(forge.stage(), "")), "snap": sn,
		"claw": { "id": String(claw.id), "name": String(claw.name), "reach": forge.natural_mm(), "color": String(claw.get("col", "#6B5A45")), "label": String(setup.get("claw_label", "")) },
		"bench": bench_view(), "controls": controls_view(), "selected_control": selected_control, "run": run_view(),
		"act": act.duplicate(true), "piece": piece_view(), "sheath": sheath_view(), "shape": shape, "wall": wall,
		"tutorial": tutorial_view(), "mistake": mistake_view(), "readouts": readouts(), "events": events_view(),
		"sheet": result_sheet(), "care": care_view(), "bench_setup": bench_setup(), "sound": sound_view(),
		"fx": _fx.duplicate(true), "fx_n": _fx_n, "glow_ramp": glow_ramp(), "live": _live, "profile": _profile,
		"workshop": { "carve": carve_p.duplicate(), "protect": barrier_p.duplicate(), "coat": coat_p.duplicate(), "bond": bond_p.duplicate(), "polish": polish_p.duplicate(), "load_n": load_n },
		"labels": labels_view(sn), "values": values_cached(), "last_action": last_action, "running": running(), "fiction": process == LIVE or bool((sn.coat as Dictionary).get("fiction", false)),
		"furnace_fiction": short_source(String(ForgeData.FURNACE.source)),
		"speed": speed_i, "clock": clock_view(), "notice": notice, "inside": inside_view(), "lost_wax": lost_wax_view(),
		"carving": carving_view(), "fit": (sn.fit as Dictionary).duplicate(true), "tool": carve_tool, "compensate": compensate,
		"weld": weld_view(sn), "feasible": feasibility(),
	}
