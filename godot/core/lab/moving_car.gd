## Tribología biológica · coche en marcha: aerodinámica, agarre y daño (modelo 2.0; no existe en el motor 1.x).
##
## Una rapaz que clava las garras en un coche en marcha, o un tigre, un oso o un casuario que se abalanza sobre él: ¿a
## qué velocidad se suelta, qué capas raya o perfora y qué daño deja? Funciones puras, estáticas y deterministas; sin
## nodos. Modelo, fuentes y guía de integración: docs/fisica/coche-en-marcha.md.
##
##   1. Aire: ρ = p/(R·T), con la presión de la atmósfera tipo (ISO 2533) a la altitud elegida y la temperatura del
##      aire (por defecto, 20 °C al nivel del mar: 1,204 kg/m³). El viento relativo es el del coche más el viento de
##      frente (y el lateral). La velocidad local en cada zona NO es la del coche: v_local = v·√(1 − Cp), con el Cp
##      medido en el túnel sobre el DrivAer (techo, ventanillas, zaga) o estimado donde no hay medición (parabrisas).
##   2. Animal: resistencia D = q·Cd·A y sustentación L = q·CL·S, con q = ½·ρ·v_local². Aves: área frontal de
##      Pennycuick (1988), Cd del cuerpo de Tucker (1990), superficie alar medida y CL máximo de Tucker & Heine (1990).
##      Tigre y oso: sin túnel; cuerpo romo (Hoerner 1965), estimación.
##   3. Equilibrio en el panel (inclinación β; D horizontal y L vertical): normal R = m·(g·cos β + a·sen β) + D·sen β −
##      L·cos β; tangencial T = D·cos β + L·sen β + m·(a·cos β − g·sen β) y lateral D_lat + m·a_lat. Aguanta si
##      |T| ≤ μ·R + A (fricción más anclaje); si R < 0, solo el anclaje A (agarre de las patas en algo que se puede
##      agarrar, o garras enganchadas en un borde) sujeta al animal.
##      μ sale del motor de siempre (Physics.compute: la garra arando el barniz), acotado por lo medido en garras y
##      almohadillas. La queratina (~30 HV) no corta el acero (~100 HV) ni el aluminio: allí solo raya la pintura.
##   4. Velocidad de despegue: la primera velocidad en que la fuerza necesaria supera a la disponible, con su banda (los
##      datos más desfavorables y los más favorables).
##   5. Golpe al abalanzarse: velocidad relativa, energía (masa reducida con el coche), marcas de las garras al deslizar
##      (longitud = lo que tarda en frenar o en salirse del panel), punción con el motor de siempre, abolladura
##      (core/lab/dent.gd) y parabrisas laminado (core/lab/glazing.gd) de la unidad 1f, la huella que queda en el
##      barniz al retirar la garra (core/lab/recovery.gd) y el balance de energía (primer principio: a dónde va la
##      energía cinética del animal respecto al coche).
##   6. Casuario (unidad 4d, apartado 10 del documento): no se agarra ni se sube (supports_hold = false); se abalanza con
##      su patada, un salto con los pies por delante (Kofron 2003). La velocidad del salto sale del trabajo muscular medido
##      en el salto de un ave (Henry et al. 2005) con la masa muscular de la pata de una ratite (Hutchinson et al. 2015), y
##      la fuerza de la pata no pasa de la medida en la patada de otra ave (5,1 pesos corporales, Portugal et al. 2016).
##   7. Garras experimentales (unidad 4d, apartado 11): p.inlay (id de Data.INLAYS, «none» por defecto) reforja las garras
##      de cualquier animal en otro material, con el motor de siempre. Si perforan la chapa, quedan clavadas (anclaje, que
##      no pasa de lo que aguantan de lado: claws_hold_n), y al resbalar por el metal pueden mellarse, partirse o doblarse
##      (core/lab/claw_fracture.gd, con la carga del instante que más las flexa: claw_load).
##   8. Defensa (unidad 4d, apartado 12): p.defense, el animal asustado aprieta con toda su fuerza (defense_force: el
##      agarre medido de las aves, los flexores de las garras del tigre y del oso, la patada del casuario). Desgarra con
##      el motor en modo desgarro, puede quedarse clavado (anclaje) y, donde hay algo que agarrar, sujeta más
##      (defense_block). En un panel liso la fricción sigue siendo la de su peso, pero si sus garras se hunden en la
##      pintura más que en reposo, para arrastrarlo el viento tiene que ararla (rake_n: el arado de Bowden & Tabor).
##   9. Garras trabadas en el plástico (unidad 4g): en un golpe de costado, unas garras que atraviesan la aleta de
##      plástico quedan trabadas en ella; si el animal sigue a lo largo del panel, la rajan de lado a lado (cada garra pide
##      R·t: la resiliencia con entalla del PPE/PA de la ficha de SABIC por el espesor) hasta que se para respecto al coche
##      o llega al final del panel, si el animal aguanta lo que pide rajarla (su anclaje); si no, se le sueltan (tear_run).
##  10. Aire por detrás (unidad 4g): con un viento de cola más fuerte que la velocidad del coche, el ala abierta recibe el
##      aire por el borde de salida y sustenta como un perfil al revés (Sheldahl & Klimas 1981): nunca más que de cara.
##  11. Velocirraptores (unidad 4i-B2; docs/fisica/coche-en-marcha.md §14 y velociraptor.md §11): kind «teropodo». La reconstrucción
##      (19,7 kg) y el de película (FICCIÓN en su garra; el tamaño, de Deinonychus). Cuerpo de ave sin alas (solo agazapado),
##      agarre del pie como las rapaces (el de su ficha, con su banda) y un golpe SALTANDO (attack «salto», leap_block): la
##      carrera de su ficha y el salto de KICK (los mismos w y f que la patada del casuario), con el aire que lo frena en el
##      vuelo (leap_flight) y la altura de los paneles (PANEL_HEIGHT: a los de arriba llega de bajada, si llega). Golpean sus
##      dos garras falciformes (strike_claws): pinchan y, si atraviesan, sujetan. La garra de película corta la chapa
##      (can_cut_body con la dureza de la garra): el motor de siempre la raja o la perfora.
##  12. El afilado (p.sharpness, el de Physics.sharpness_of) y la masa de las garras reforjadas (ClawMass: en el golpe, la
##      velocidad la impone el coche y la masa de más suma ½·Δm·v²; claw_mass_block).
## Rendimiento (medido sin ventana en un contenedor de la nube): at_speed() es O(1), sin compute() (~20 µs): vale para
## cada fotograma del deslizador. setup() (~0,4 ms), detach() (~0,2 ms) y curve() (61 puntos, ~1,3 ms) se recalculan
## al cambiar de animal, zona, postura, coche, viento o aceleración. impact() llama dos veces a Physics.compute() (tres en
## la patada; ~2-5 ms): al soltar el deslizador o unas pocas veces por segundo.
## Unidades: fuerza N · velocidad m/s por dentro y km/h en la interfaz · área m² (frontal y alar) · masa kg ·
## energía J · profundidad µm (mm y cm en los textos) · aceleración en g (9,807 m/s²).
## Uso: const MovingCar = preload("res://core/lab/moving_car.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Format = preload("res://core/shared/format.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawsV2 = preload("res://core/lab/claws_v2.gd")
const Dent = preload("res://core/lab/dent.gd")
const Glazing = preload("res://core/lab/glazing.gd")
const CarGlass = preload("res://core/lab/car_glass.gd")
const Recovery = preload("res://core/lab/recovery.gd")
const Fracture = preload("res://core/lab/fracture.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const CarFormat = preload("res://core/lab/car_format.gd")
## Unidad 4i-B2: la masa de las garras reforjadas (ClawMass) y el afilado (ClawSharpness). Los velocirraptores no se
## precargan: sus datos (agarre, carrera, ficción) van en su entrada del catálogo (dino) y en BODIES.
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")

## Aire seco de la atmósfera tipo (ISO 2533:1975): R del aire seco; al nivel del mar, p0 y T0; en la troposfera (hasta
## 11 km) la temperatura tipo baja L = 6,5 K por km y la presión sigue la fórmula barométrica
## p = p0·(1 − L·h/T0)^(g0/(R·L)). La densidad usa la temperatura del aire elegida (temp_c), no la tipo.
const R_AIR := 287.05
const ISA_P0 := 101325.0
const ISA_T0 := 288.15
const ISA_LAPSE := 0.0065
const ISA_G0 := 9.80665
const KELVIN := 273.15
## Densidad del aire de referencia (kg/m³): aire seco a 20 °C y 101 325 Pa, ρ = p/(R·T) = 1,204.
const RHO_AIR := ISA_P0 / (R_AIR * (20.0 + KELVIN))
## Gravedad (m/s²): la misma con la que 1 kgf son 9,807 N (HV_MPA) y la de sting.gd.
const G := 9.807
## km/h por m/s.
const KMH := 3.6
## Búsqueda de la velocidad de despegue: hasta 400 km/h, en pasos de 5 km/h y bisección después.
const SCAN_MAX_KMH := 400.0
const SCAN_STEP_KMH := 5.0
## Tope del deslizador de velocidad del coche: la velocidad máxima de un turismo de serie, que llega a 200-230 km/h
## (Eric; con 150 se quedaba corto). No es un dato de la física: el despegue se busca hasta SCAN_MAX_KMH. Un coche con su
## velocidad máxima en el catálogo (vmax_kmh: el deportivo de core/lab/sports_car.gd, unidad 4r) llega hasta ella
## (slider_max_kmh); el escenario la lleva en vmaxKmh.
const SLIDER_MAX_KMH := 230.0
## Por debajo de esta velocidad (km/h), el coche se da por parado en el despegue: la mitad del km/h entero con el que se
## escriben las velocidades. Así, un agarre justo en el límite con el coche parado (μ = 1 frente a una frenada de 1 g, sin
## garras clavadas) no «se suelta a ~0 km/h»: ni parado se sostiene. Y una ventana que empieza por debajo aguanta parado.
const REST_KMH := 0.5
## Tope de la búsqueda de la frenada máxima (g): ningún turismo frena tanto.
const BRAKING_TOP_G := 2.0
## Recorrido de la punta de una garra reforjada al clavarse (claw_load): puntos uniformes en log h y puntos para afinar
## entre los vecinos del mejor.
const LOAD_SCAN_STEPS := 96
const LOAD_REFINE := 32

## Tope del deslizador (km/h) con un coche del catálogo: su velocidad máxima (vmax_kmh, el deportivo) o la del turismo
## de serie (SLIDER_MAX_KMH). target: la entrada del catálogo (o null).
static func slider_max_kmh(target: Variant) -> float:
	if target is Dictionary and (target as Dictionary).has("vmax_kmh"):
		return maxf(float((target as Dictionary).vmax_kmh), SLIDER_MAX_KMH)
	return SLIDER_MAX_KMH


## Cd·A (m²) del coche del catálogo para comparar la resistencia del animal con la del coche (carDragN): la suya
## (aero: el deportivo) o la del coche de referencia (CAR_REF).
static func car_cda(target: Variant) -> float:
	if target is Dictionary and (target as Dictionary).get("aero") is Dictionary:
		var a: Dictionary = (target as Dictionary).aero
		return float(a.cd) * float(a.area_m2)
	return float(CAR_REF.cd) * float(CAR_REF.area_m2)


## Parámetros nuevos para la interfaz: rango, valor por defecto y unidad (docs/fisica/coche-en-marcha.md, §9.1).
const PARAMS := {
	"v_kmh": { "min": 0.0, "max": SLIDER_MAX_KMH, "default": 90.0, "unit": "km/h" },
	"wind_kmh": { "min": -60.0, "max": 60.0, "default": 0.0, "unit": "km/h" },  # + de frente, − de cola
	"crosswind_kmh": { "min": 0.0, "max": 60.0, "default": 0.0, "unit": "km/h" },
	"accel_g": { "min": -1.0, "max": 0.5, "default": 0.0, "unit": "g" },  # + acelera, − frena
	"lateral_g": { "min": 0.0, "max": 0.9, "default": 0.0, "unit": "g" },  # curva (hacia fuera)
	"animal_kmh": { "min": 0.0, "max": 70.0, "default": 40.0, "unit": "km/h" },
	"angle_deg": { "min": 0.0, "max": 180.0, "default": 90.0, "unit": "°" },  # 0 mismo sentido, 90 cruza, 180 de frente
	"drop_m": { "min": 0.0, "max": 3.0, "default": 0.5, "unit": "m" },  # caída sobre el panel al aterrizar
	"car_mass_kg": { "min": 800.0, "max": 2500.0, "default": 1400.0, "unit": "kg" },
	"temp_c": { "min": -20.0, "max": 45.0, "default": 20.0, "unit": "°C" },  # temperatura del aire
	"altitude_m": { "min": 0.0, "max": 3000.0, "default": 0.0, "unit": "m" },  # altitud de la carretera
	# unidad 4i-B2: el afilado de unas garras reforjadas (0: la punta de la ficha; 1: el filo más fino medido), el de Physics
	"sharpness": { "min": 0.0, "max": 1.0, "default": 0.0, "unit": "" },
}

## Maniobras típicas para los botones de la interfaz (valores de las aceleraciones con su fuente).
const MANEUVERS := [
	{ "id": "crucero", "name": "Velocidad constante", "accel_g": 0.0, "lateral_g": 0.0, "quality": "primary", "source": "sin aceleración" },
	{ "id": "frenada", "name": "Frenada normal", "accel_g": -0.35, "lateral_g": 0.0, "quality": "secondary", "source": "AASHTO (2011), A Policy on Geometric Design of Highways and Streets: 3,4 m/s² de deceleración cómoda para la distancia de parada" },
	{ "id": "emergencia", "name": "Frenada de emergencia", "accel_g": -0.9, "lateral_g": 0.0, "quality": "estimate", "source": "adherencia de pico del neumático en asfalto seco 0,8-0,9 (Wong, Theory of Ground Vehicles): un turismo moderno con ABS frena a ~0,9-1 g" },
	{ "id": "acelera", "name": "Acelerar", "accel_g": 0.3, "lateral_g": 0.0, "quality": "estimate", "source": "0-100 km/h en ~9 s (turismo medio): 3 m/s² de media" },
	{ "id": "curva", "name": "Curva", "accel_g": 0.0, "lateral_g": 0.3, "quality": "estimate", "source": "curva de carretera a velocidad de proyecto (~0,1-0,3 g)" },
	{ "id": "curva_fuerte", "name": "Curva al límite", "accel_g": 0.0, "lateral_g": 0.8, "quality": "estimate", "source": "límite de adherencia lateral en asfalto seco (~0,8 g)" },
]

# ── Fuentes ──
const SRC_DRIVAER := "Varney M, Passmore M, Wittmeier F, Kuthada T (2020). DrivAer Experimental Aerodynamic Dataset. Loughborough University, doi:10.17028/rd.lboro.12881213.v1 (DrivAer a escala 25 %, 40 m/s, suelo fijo; Cp medio de las tomas de presión de las versiones fastback, notchback y estate)"
const SRC_DRIVAER_PIV := SRC_DRIVAER + " (PIV en el plano central: velocidad a 1-4 cm de la superficie, Cp = 1 − (v/V)²)"
const SRC_MATHAI := "Mathai V, Das A, Bailey JA, Breuer K (2021). Airflows inside passenger cars and implications for airborne disease transmission. Sci. Adv. 7:eabe0166 (CFD a 22 m/s: remanso de alta presión sobre la rejilla y al pie del parabrisas; valor numérico no publicado: estimación)"
const SRC_PENNYCUICK := "Pennycuick CJ, Obrecht HH, Fuller MR (1988). Empirical estimates of body drag of large waterfowl and raptors. J. Exp. Biol. 135:253-264 (área frontal S_b = 0,00813·m^0,666, en m² con m en kg; Cd de cuerpos congelados 0,25-0,39)"
const SRC_TUCKER_1990 := "Tucker VA (1990). Body drag, feather drag and interference drag of the mounting strut in a peregrine falcon, Falco peregrinus. J. Exp. Biol. 149:449-468 (Cd del cuerpo 0,24 sobre la sección máxima)"
const SRC_TUCKER_HEINE := "Tucker VA, Heine C (1990). Aerodynamics of gliding flight in a Harris' hawk, Parabuteo unicinctus. J. Exp. Biol. 149:469-489 (CL máximo 1,6)"
const SRC_PONITZ := "Ponitz B, Schmitz A, Fischer D, Bleckmann H, Brücker C (2014). Diving-flight aerodynamics of a peregrine falcon (Falco peregrinus). PLoS ONE 9:e86506 (CL 0,045-0,087 sobre el área en planta, 3,34 veces la frontal)"
const SRC_ALERSTAM_2007 := "Alerstam T, Rosén M, Bäckman J, Ericson PGP, Hellgren O (2007). Flight speeds among bird species: allometric and phylogenetic effects. PLoS Biol. 5:e197, Protocol S1 (masa, envergadura y superficie alar medias)"
const SRC_JOHNSON_1997 := "Johnson DH (1997). Wing loading in 15 species of North American owls. USDA Forest Service Gen. Tech. Rep. NC-190:553-561, tabla 1 (alas más la caja entre ellas, como Pennycuick)"
const SRC_HAREL_2016 := "Harel R, Horvitz N, Nathan R (2016). Adult vultures outperform juveniles in challenging thermal soaring conditions. Sci. Rep. 6:27865 (buitre leonado adulto: carga alar 9 kg/m², alargamiento 7,61)"
const SRC_HOERNER := "Hoerner SF (1965). Fluid-Dynamic Drag, cap. 3 (persona de pie: Cd 1,0-1,3 sobre el área frontal; esquiador agachado; placas y cuerpos romos)"
const SRC_GARLAND := "Garland T (1983). The relation between maximal running speed and body mass in terrestrial mammals. J. Zool. 199:157-170, tabla I (tigre 56 km/h, oso pardo 48 km/h; datos «más o menos anecdóticos», dice el autor)"
const SRC_DERLER := "Derler S, Gerhardt L-C (2012). Tribology of skin: review and analysis of experimental results for the friction coefficient of human skin. Tribol. Lett. 45:1-27 (piel seca ~0,5; húmeda > 1)"
const SRC_ISA := "ISO 2533:1975, Standard Atmosphere (troposfera: T = T0 − L·h con T0 = 288,15 K y L = 6,5 K/km; p = p0·(1 − L·h/T0)^(g0/(R·L)) con p0 = 101 325 Pa, g0 = 9,80665 m/s² y R = 287,05 J/(kg·K)); ρ = p/(R·T) con la temperatura del aire elegida"
const SRC_RODERICK := "Roderick WRT, Chin DD, Cutkosky MR, Lentink D (2019). Birds land reliably on complex surfaces by adapting their foot-surface interactions upon contact. eLife 8:e46415 (en superficies lisas las uñas apenas encuentran asperezas: fricción baja e impredecible)"
# Unidad 4g: el ala con el aire por detrás, la geometría del coche y las patas
const SRC_SHELDAHL_KLIMAS := "Sheldahl RE, Klimas PC (1981). Aerodynamic characteristics of seven symmetrical airfoil sections through 180-degree angle of attack for use in aerodynamic analysis of vertical axis wind turbines. SAND80-2114, Sandia National Laboratories, doi:10.2172/6548367, tabla 2 (NACA 0012 en túnel de 0 a 180°, Re de 0,36 a 0,7 millones: con el aire entrando por el borde de salida, CL = 0 a 180°, −0,69 a 175°, −0,85 a 170° y −0,68 a 165°; en pérdida, como una placa, −0,945 a 135-140° frente a +1,085 a 45°)"
const SRC_CUI_2025 := "Cui S, Shi L, Wang G, Chen J, Liu N, Long Y, Shi Z (2025). Study on the influence of passenger car front shape on pedestrian thorax injury based on the FASS database. Transp. Saf. Environ. 7(3):tdaf040, doi:10.1093/tse/tdaf040 (452 frontales de turismos medidos: capó de 54 a 123 cm de largo, 90 cm en su modelo de base; ángulo del capó de 11 a 44°, 20° en el de base)"
const SRC_DRIVAERML := "Ashton N et al. (2024). DrivAerML: high-fidelity computational fluid dynamics dataset for road-car external aerodynamics. arXiv:2408.11969 (el DrivAer de referencia: 2,786 m de batalla y 2,17 m² de área frontal, la geometría de referencia de cada ensayo)"
const SRC_FREDRIKSSON := "Fredriksson R, Zhang L, Boström O, Yang K (2007). Influence of impact speed on head and brain injury outcome in vulnerable road user impacts to the car hood. Stapp Car Crash J. 51:155-167 (cabeza de ensayo contra un capó con una placa rígida regulable debajo: de 20 a 100 mm de hueco, el HIC baja de ~5000 a ~500), vía Lindgren N, Kleiven S, Li X (2025), arXiv:2504.15951"
const SRC_FMVSS_216 := "FMVSS 216, Roof crush resistance (49 CFR 571.216), S5: con 1,5 veces el peso del coche sobre el borde delantero del techo, la placa de ensayo no puede bajar más de 127 mm"
const SRC_FMVSS_214 := "FMVSS 214, Side impact protection (49 CFR 571.214), S7.1: la resistencia de la puerta se mide en sus primeros 152 mm de aplastamiento (resistencia inicial, al menos 10 kN) y hasta 457 mm"
const SRC_MCDOUGAL := "McDougal (1999), vía Sharma S, Jhala Y, Sawarkar VB (2003). Gender discrimination of tigers by using their pugmarks. Wildl. Soc. Bull. 31:258-264 (almohadilla de la mano del tigre: más de 9,7 cm de ancho en los machos y ~9 en las hembras; la huella marca cuatro dedos)"
const SRC_MATTSON := "Mattson DJ (2003). Foot loadings and pad and track widths of Yellowstone grizzly bears. West. N. Am. Nat. 63:72-79 (almohadilla de la mano: 12,5-14,5 cm de ancho en las hembras adultas y más de 14,5 cm en los machos adultos; la huella marca cinco dedos)"
const SRC_FARLEY := "Farley CT, Glasheen J, McMahon TA (1993). Running springs: speed and animal size. J. Exp. Biol. 185:71-86, doi:10.1242/jeb.185.1.71 (la rigidez de la pata al correr crece como M^0,67 en animales de 0,1 a 140 kg)"
# Casuario (unidad 4d)
const SRC_KOFRON_1999 := "Kofron CP (1999). Attacks to humans and domestic animals by the southern cassowary (Casuarius casuarius johnsonii) in Queensland, Australia. J. Zool. 249:375-381, doi:10.1017/S0952836999009905 (221 ataques; 150 a personas, el 75 % de aves que la gente alimentaba)"
const SRC_KOFRON_2003 := "Kofron CP (2003). Case histories of attacks by the southern cassowary in Queensland. Mem. Queensl. Mus. 49:339-342 (atacan pateando o saltando encima; «cargó, saltó y le pateó el pecho»: herida punzante de 12 cm de profundidad; la garra de un salto, herida de 1¼ cm de diámetro en el cuello)"
const SRC_KOFRON_CHAPMAN := "Kofron CP, Chapman A (2006). Causes of mortality to the endangered southern cassowary Casuarius casuarius johnsonii in Queensland, Australia. Pac. Conserv. Biol. 12:175-179, doi:10.1071/PC060175 (los coches son la primera causa de muerte: 55 % de 1986 a 2004)"
const SRC_NAISH := "Naish D (2007; reeditado en Tetrapod Zoology, Scientific American Blogs). How dangerous are cassowaries, really? («patean o picotean puertas y ventanas, y a veces rompen el cristal»; «también patean o persiguen coches», porque asocian a sus ocupantes con comida)"
const SRC_BORRELL := "Borrell B (2008). Invasion of the cassowaries. Smithsonian Magazine, octubre (en Mission Beach «persiguen coches»; carga a «hasta 30 millas por hora» y salta «más de 3 pies»: datos divulgativos)"
const SRC_GRZIMEK := "Grzimek's Animal Life Encyclopedia, 2.ª ed. (2003), vol. 8, Birds I: casuario común, hembra 58 kg y macho 29-34 kg; espolón del dedo interno de hasta 12 cm"
const SRC_LATCH := "Latch P (2007). Recovery plan for the southern cassowary Casuarius casuarius johnsonii. Environmental Protection Agency, Queensland (machos de hasta 55 kg y hembras, normalmente mayores, de hasta 76 kg: Westcott & Reid 2002 y datos del servicio de parques de Queensland)"
const SRC_WESTCOTT := "Westcott DA, Reid KE (2002). Use of medetomidine for capture and restraint of cassowaries (Casuarius casuarius). Aust. Vet. J. 80:150-153, doi:10.1111/j.1751-0813.2002.tb11380.x (11 adultos, 5 pesados y 6 estimados: 40-66 kg)"
const SRC_HEALY := "Healy TP (2022). Southern cassowary (Casuarius casuarius), Birds of the World, Cornell Lab of Ornithology («hasta 50 km/h»; recopilación, sin la medición original)"
const SRC_PORTUGAL := "Portugal SJ, Murn CP, Sparkes EL, Daley MA (2016). The fast and forceful kicking strike of the secretary bird. Curr. Biol. 26:R58-R59, doi:10.1016/j.cub.2015.12.004 (45 patadas medidas en una placa de fuerza: pico de 5,1 ± 0,9 pesos corporales y contacto de 15 ± 4,4 ms)"
const SRC_HENRY := "Henry HT, Ellerby DJ, Marsh RL (2005). Performance of guinea fowl Numida meleagris during jumping requires storage and release of elastic energy. J. Exp. Biol. 208:3293-3302, doi:10.1242/jeb.01764 (salto máximo: 5,3 pesos corporales y 45 J por kg de músculo de la pata, unos dos tercios del máximo esperable en el músculo esquelético)"
const SRC_HUTCHINSON := "Hutchinson JR et al. (2015). Musculoskeletal modelling of an ostrich (Struthio camelus) pelvic limb. PeerJ 3:e1001, doi:10.7717/peerj.1001, tabla 2 (músculos de una pata de un avestruz hembra de 65,3 kg, disecados: 8,50 kg, el 13,0 % de su masa)"
const SRC_SABER := "Saber AS, Hassanin A (2014). Some morphological studies on the wing and foot of the southern cassowary (Casuarius casuarius). J. Vet. Anat. 7(2):17-32 (tres dedos, sin dedo trasero; el segundo con la garra larga) y Naish (2007): el dedo I falta"

## Coche de referencia para comparar la resistencia: DrivAer fastback, Cd 0,309 con 0,136 m² a escala 25 % (2,18 m² a
## escala real).
const CAR_REF := { "cd": 0.309, "area_m2": 2.176, "quality": "primary", "source": SRC_DRIVAER }

## Fricción de garras y almohadillas sobre el panel: el valor central lo da el motor (la garra arando el barniz); la
## banda va de 0,3 (uñas que patinan en una superficie lisa) a 1,0 (almohadillas húmedas: la piel húmeda pasa de 1).
const FRICTION := {
	"min": 0.3, "max": 1.0, "quality": "estimate",
	"source": "mínimo: " + SRC_RODERICK + "; máximo: " + SRC_DERLER + ", acotado a 1",
}
## Agarre de un ave sobre algo que abarca con los dedos (barra, antena, retrovisor, limpiaparabrisas, borde): anclaje
## A = 2 pies × fuerza de agarre × k. k = 0,6 si la barra solo se desliza entre los dedos (2μ con μ = 0,3); 2 si los
## dedos la rodean y el tirón tiene que abrirlos. Estimación.
const GRASP_K := { "value": 1.0, "min": 0.6, "max": 2.0, "quality": "estimate", "source": "fricción en las dos caras de la barra (2μ) hasta el cierre de forma de unos dedos que la rodean" }
## Garras de un mamífero enganchadas en un borde o un hueco (barras de techo, marco de la ventanilla): cada pata
## delantera sostiene k veces el peso del animal (los felinos trepan colgados de las manos). Estimación.
const HOOK_K := { "value": 0.5, "min": 0.25, "max": 1.0, "quality": "estimate", "source": "fracción del peso que sostiene cada pata delantera enganchada (estimación)" }
## Borde de chapa (marco de la ventanilla): se dobla con un momento plástico por unidad de longitud σ0·t²/4 sobre el
## ancho de la pata y con el brazo del gancho de la garra (15 mm). El pliegue del borde puede ser doble (×2 a ×4).
const EDGE := { "lever_mm": 15.0, "factor": { "value": 2.0, "min": 1.0, "max": 4.0 }, "quality": "estimate", "source": "momento plástico de una chapa, σ0·t²/4 (Roark); borde sencillo o plegado (estimación)" }

## Aerodinámica común a las aves.
##   - Área frontal del cuerpo en vuelo: S_b = 0,00813·m^0,666 (Pennycuick 1988).
##   - Agazapada en el coche con las alas plegadas: área = crouch·S_b (piernas, cabeza alzada: ×1-2, estimación) y
##     Cd del cuerpo 0,24 (Tucker 1990, medido sin la interferencia del soporte) a 0,6 (cuerpo posado, más romo:
##     estimación); valor central 0,4, el orden de lo que midió Pennycuick (0,25-0,39).
##   - Sustentación del cuerpo: CL·S = k·S_b con k 0,15-0,30 (Ponitz 2014: CL 0,045-0,087 sobre un área en planta de
##     3,34 veces la frontal).
##   - Alas abiertas: tres estados. «sustenta»: CL máximo 1,6 (Tucker & Heine 1990) con Cd del ala 0,2 (perfil más
##     inducida, estimación); «frena»: ala en pérdida a ~45°, CL ≈ Cd ≈ 1 (placa plana inclinada, Hoerner 1965,
##     estimación); «suave»: CL 1,0 y Cd 0,1 (ala a poca incidencia, estimación).
##   - Con el aire por detrás (unidad 4g: viento de cola más fuerte que la velocidad del coche, v_x < 0), el ala recibe el
##     aire por el borde de salida: cl_rev. «sustenta», 0,85: lo más que da un perfil con el aire entrando por el borde de
##     salida, a unos 10° de los 180° (Sheldahl & Klimas 1981; el viento de cola levanta el borde de salida de las plumas,
##     la actitud que más sube); «frena», 1,0: una placa en pérdida trabaja igual por los dos lados; «suave», 0: el ala
##     plana, como el perfil a 180°. Nunca más que de cara (test). El cuerpo y los mamíferos, igual que de cara.
## Calidad por campo: medidos el área frontal y el CL máximo; lo demás, estimación apoyada en esas medidas. En cada estado
## del ala, quality es la del CL (la del Cd, cd_quality; la del CL al revés, cl_rev_quality).
const BIRD_AERO := {
	"frontal_coef": 0.00813, "frontal_exp": 0.666, "frontal_quality": "secondary",
	"crouch": { "value": 1.5, "min": 1.0, "max": 2.0, "quality": "estimate" },
	"cd_body": { "value": 0.4, "min": 0.24, "max": 0.6, "quality": "estimate" },
	"cl_body": { "value": 0.2, "min": 0.15, "max": 0.3, "quality": "estimate" },
	"wing": {
		"sustenta": {
			"cl": 1.6, "cd": 0.2, "cl_rev": 0.85, "quality": "secondary", "cd_quality": "estimate", "cl_rev_quality": "estimate",
			"source": SRC_TUCKER_HEINE + " (el CL máximo, medido en planeo); el Cd del ala, 0,2: perfil más inducida con el CL máximo, sin medición en esta postura (estimación)",
			"cl_rev_source": "Caso medido más parecido: " + SRC_SHELDAHL_KLIMAS + ". Suposición: con el aire por detrás, el ala abierta no sustenta más que un perfil con el aire entrando por su borde de salida en la actitud que más sube (el viento levanta el borde de salida de las plumas: 0,85 a unos 10° de los 180°); es un perfil de envergadura infinita, así que un ala real daría algo menos (cota alta). El Cd no cambia (el perfil da 0,14 de sección a 170°, más la inducida).",
		},
		"frena": {
			"cl": 1.0, "cd": 1.0, "cl_rev": 1.0, "quality": "estimate", "cd_quality": "estimate", "cl_rev_quality": "estimate",
			"source": SRC_HOERNER + " (placa plana inclinada ~45°: CL ≈ Cd ≈ 1; estimación)",
			"cl_rev_source": "una placa en pérdida trabaja igual con el aire por cualquiera de sus bordes (" + SRC_HOERNER + "); en el perfil NACA 0012, 0,945 a 135° frente a 1,085 a 45° (" + SRC_SHELDAHL_KLIMAS + ")",
		},
		"suave": {
			"cl": 1.0, "cd": 0.1, "cl_rev": 0.0, "quality": "estimate", "cd_quality": "estimate", "cl_rev_quality": "estimate",
			"source": "cota favorable: ala a poca incidencia (estimación)",
			"cl_rev_source": "cota favorable con el aire por detrás: el ala plana, como el perfil a 180° (CL = 0, " + SRC_SHELDAHL_KLIMAS + "); en la actitud con la que sustenta de cara, el aire de cola la apretaría contra el coche (−0,69 a 175°), y eso no se cuenta",
		},
	},
	"quality": "secondary", "source": SRC_PENNYCUICK + "; " + SRC_TUCKER_1990 + "; " + SRC_TUCKER_HEINE + "; " + SRC_PONITZ,
}

## Posturas por tipo de animal (la primera es la de por defecto). «corredora»: el casuario, que solo se ensaya en el
## golpe (la patada); su postura no cambia nada.
const POSTURES := {
	"ave": ["plegadas", "abiertas"],
	"mamifero": ["tumbado", "de_pie"],
	"corredora": ["de_pie"],
	# unidad 4i-B2: los velocirraptores, solo agazapados (la superficie de las plumas de sus brazos no está medida)
	"teropodo": ["tumbado"],
}
const POSTURE_NAMES := { "plegadas": "Alas plegadas", "abiertas": "Alas abiertas", "tumbado": "Agazapado", "de_pie": "De pie" }

## Fuentes campo a campo de BODIES que se repiten (unidad 4g). height_m y length_m son solo del dibujo: su calidad es
## «dibujo» y nunca se enseñan como física.
const DRAW_ONLY := { "quality": "dibujo", "source": "solo para el dibujo: el tamaño del animal contra el coche (~4,5 m)" }
const BIRD_TALONS := {
	"quality": "estimate",
	"source": "en cada pie se hunden a la vez el talón trasero y el delantero que aprieta contra él (la pinza cuyo agarre midieron Sustaita & Hertel 2010); los otros dedos apoyan sin clavarse: estimación",
}
const BIRD_FOOT := {
	"quality": "estimate",
	"source": "radio del apoyo del pie con los dedos abiertos, del orden de la mitad de su largo: sin medición (estimación); solo reparte el peso o el golpe sobre el parabrisas",
}
const MAMMAL_FRONTAL := {
	"quality": "estimate",
	"source": "sin túnel de viento: un cuerpo de ~1000 kg/m³ con ~1,5 m de tronco (tigre: pecho de ~0,43 m; oso: ~0,5 m) más las patas delanteras de pie; agazapado, el pecho y la cabeza (estimación desde la masa y el tamaño)",
}
const MAMMAL_CD := { "quality": "estimate", "source": SRC_HOERNER + ": cuerpo romo con patas, entre el esquiador agachado y la persona de pie (1,0-1,3); agazapado, algo menos (estimación)" }
const MAMMAL_CLS := { "quality": "estimate", "source": "una sustentación pequeña del lomo agazapado; de pie, ninguna (estimación, sin medición)" }
# Velocirraptores (unidad 4i-B2)
const SRC_LI_2008 := "Li R, Lockley MG, Makovicky PJ, Matsukawa M, Norell MA, Harris JD, Liu M (2008). Behavioral and faunal implications of Early Cretaceous deinonychosaur trackways from China. Naturwissenschaften 95:185-191, doi:10.1007/s00114-007-0310-7 (rastros de dos dedos: la garra del dedo II no tocaba el suelo)"
const SRC_MANNING_2006 := "Manning PL, Payne D, Pennicott J, Barrett PM, Ennos RA (2006). Dinosaur killer claws or climbing crampons? Biol. Lett. 2:110-112, doi:10.1098/rsbl.2005.0395 (una réplica robótica de la garra del dedo II de Deinonychus solo hizo punciones redondas de 3-4 cm en un cerdo, nunca un tajo)"
const SRC_FOWLER_2011 := "Fowler DW, Freedman EA, Scannella JB, Kambic RE (2011). The predatory ecology of Deinonychus and the origin of flapping in birds. PLoS ONE 6:e28964, doi:10.1371/journal.pone.0028964 (saltaba sobre la presa, la sujetaba con la garra del dedo II como el talón de un gavilán y la inmovilizaba con su peso)"
const SRC_SELLERS_2007 := "Sellers WI, Manning PL (2007). Estimating dinosaur maximum running speeds using evolutionary robotics. Proc. R. Soc. B 274:2711-2716, doi:10.1098/rspb.2007.0846 (Velociraptor de 20 kg: 10,8 m/s; el mismo modelo subestima a la persona un 21 %: banda alta de 13,7 m/s)"
const SRC_NORELL_1999 := "Norell MA, Makovicky PJ (1999). Important features of the dromaeosaurid skeleton II: information from newly collected specimens of Velociraptor mongoliensis. Am. Mus. Novit. 3282:1-45, tabla 3 (las dos primeras falanges del dedo III: 23,6-26,6 y 24,7-27,4 mm)"
## Área frontal de un velocirraptor: la del cuerpo de un ave (Pennycuick 1988) con su masa, agazapado, con los factores y
## los Cd de BIRD_AERO (_aero_sets): una extrapolación desde las aves grandes medidas.
const THEROPOD_FRONTAL := {
	"quality": "estimate",
	"source": "Caso medido más parecido: el área frontal del cuerpo de las aves, " + SRC_PENNYCUICK + ", extrapolada a su masa desde las aves grandes medidas. Suposición: un terópodo emplumado agazapado frena como un ave grande posada, con los mismos factores de postura (de 1 a 2 veces el área en vuelo) y el mismo Cd del cuerpo (0,24-0,6) que un ave posada. Sin alas: la superficie de las plumas de sus brazos no está medida (Pei et al. 2020 no la incluye)",
}
const THEROPOD_TOES := {
	"quality": "secondary",
	"source": "apoyan las garras de los dedos III y IV de los dos pies; la del dedo II, la falciforme, va levantada: " + SRC_LI_2008,
}
const THEROPOD_RUN := {
	"quality": "estimate",
	"source": SRC_SELLERS_2007 + ". En el golpe corre, como mucho, a la velocidad central de su ficha",
}

## Cuerpos con datos para el coche en marcha, por id de garra. wing_m2: superficie alar de las dos alas con la franja
## del cuerpo (definición de Pennycuick), escalada a la masa del catálogo con S ∝ m^(2/3) cuando se midió en aves de
## otra masa. contact: garras que tocan el panel; contact_mm: radio del apoyo (placa del parabrisas); paw_mm: ancho de
## la pata (borde de chapa); height_m y length_m: SOLO para el dibujo. sources (unidad 4g): la fuente y la calidad de
## cada campo que no las lleva dentro (los que son diccionarios con quality y source ya las llevan).
const BODIES := {
	"aguila": {
		"kind": "ave", "species": "Águila real (Aquila chrysaetos)",
		"wing_m2": { "value": 0.685, "min": 0.597, "max": 0.75, "quality": "secondary", "source": SRC_ALERSTAM_2007 + ": 0,597 m² con 4,07 kg (11 aves), escalado a 5 kg" },
		"span_m": { "value": 2.17, "quality": "secondary", "source": SRC_ALERSTAM_2007 + ": 2,03 m con 4,07 kg, escalado a 5 kg" },
		"contact": 4, "contact_mm": 30.0, "height_m": 0.8, "length_m": 0.85,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	"arpia": {
		"kind": "ave", "species": "Águila arpía (Harpia harpyja)",
		"wing_m2": { "value": 0.67, "min": 0.55, "max": 0.85, "quality": "estimate", "source": "sin medición publicada: envergadura de ~2,0 m (1,76-2,24) con un alargamiento de ~6 (alas cortas y anchas de rapaz de selva): S = b²/6" },
		"span_m": { "value": 2.0, "quality": "secondary", "source": "Encyclopaedia Britannica, «harpy eagle» (envergadura 1,76-2,24 m)" },
		"contact": 4, "contact_mm": 35.0, "height_m": 0.95, "length_m": 1.0,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	"halcon": {
		"kind": "ave", "species": "Halcón peregrino (Falco peregrinus)",
		"wing_m2": { "value": 0.147, "min": 0.126, "max": 0.16, "quality": "secondary", "source": SRC_ALERSTAM_2007 + ": 0,1257 m² con 0,789 kg (19 aves), escalado a 1 kg" },
		"span_m": { "value": 1.1, "quality": "secondary", "source": SRC_ALERSTAM_2007 + ": 1,02 m con 0,789 kg, escalado a 1 kg" },
		"contact": 4, "contact_mm": 15.0, "height_m": 0.45, "length_m": 0.45,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	"buho": {
		"kind": "ave", "species": "Búho (Bubo)",
		"wing_m2": { "value": 0.412, "min": 0.36, "max": 0.46, "quality": "secondary", "source": SRC_JOHNSON_1997 + ": búho cornudo hembra 1,345 kg, 2748 + 413 cm², escalado a 2 kg" },
		"span_m": { "value": 1.52, "quality": "secondary", "source": SRC_JOHNSON_1997 + ": 1,336 m con 1,345 kg, escalado a 2 kg" },
		"contact": 4, "contact_mm": 25.0, "height_m": 0.65, "length_m": 0.65,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	"lechuza": {
		"kind": "ave", "species": "Lechuza común (Tyto alba)",
		"wing_m2": { "value": 0.155, "min": 0.15, "max": 0.161, "quality": "secondary", "source": SRC_JOHNSON_1997 + ": hembras 0,529 kg con 1691 + 288 cm²; macho 0,38 kg con 1394 + 304 cm²; escalado a 0,35 kg" },
		"span_m": { "value": 0.99, "quality": "secondary", "source": SRC_JOHNSON_1997 + ": 1,133 m con 0,529 kg, escalado a 0,35 kg" },
		"contact": 4, "contact_mm": 15.0, "height_m": 0.35, "length_m": 0.36,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	"buitre": {
		"kind": "ave", "species": "Buitre leonado (Gyps fulvus)",
		"wing_m2": { "value": 0.889, "min": 0.87, "max": 0.91, "quality": "primary", "source": SRC_HAREL_2016 + ": 8 kg / 9 kg/m²" },
		"span_m": { "value": 2.6, "quality": "primary", "source": SRC_HAREL_2016 + ": b = √(7,61·S)" },
		"contact": 4, "contact_mm": 30.0, "height_m": 1.0, "length_m": 1.0,
		"sources": { "contact": BIRD_TALONS, "contact_mm": BIRD_FOOT, "height_m": DRAW_ONLY, "length_m": DRAW_ONLY },
	},
	# Mamíferos: sin túnel de viento. Área frontal de un cuerpo de ~1000 kg/m³ con ~1,5 m de tronco (tigre: pecho de
	# ~0,43 m; oso: ~0,5 m) más las patas delanteras, de pie; agazapado, el pecho y la cabeza. Cd de cuerpo romo con
	# patas (persona de pie 1,0-1,3, Hoerner 1965) y agazapado algo menor. Todo estimación.
	"tigre": {
		"kind": "mamifero", "species": "Tigre (Panthera tigris)",
		"frontal_m2": { "tumbado": { "value": 0.18, "min": 0.15, "max": 0.25 }, "de_pie": { "value": 0.30, "min": 0.25, "max": 0.40 } },
		"cd": { "tumbado": { "value": 0.7, "min": 0.5, "max": 0.9 }, "de_pie": { "value": 1.0, "min": 0.8, "max": 1.2 } },
		"cls_m2": { "tumbado": { "value": 0.15, "min": 0.05, "max": 0.3 }, "de_pie": { "value": 0.0, "min": 0.0, "max": 0.1 } },
		"run_kmh": { "value": 56.0, "quality": "secondary", "source": SRC_GARLAND },
		"quality": "estimate", "source": SRC_HOERNER + "; áreas estimadas desde la masa y el tamaño",
		"contact": 8, "contact_mm": 50.0, "paw_mm": 100.0, "height_m": 1.0, "length_m": 1.9,
		"sources": {
			"frontal_m2": MAMMAL_FRONTAL, "cd": MAMMAL_CD, "cls_m2": MAMMAL_CLS,
			"contact": { "quality": "estimate", "source": "las garras de las dos manos: cuatro en cada una (la huella del tigre marca cuatro dedos; el pulgar, con su espolón, no apoya: " + SRC_MCDOUGAL + "); que se agarre con las manos es la suposición" },
			"contact_mm": { "quality": "secondary", "source": "la mitad del ancho de la almohadilla de la mano, ~10 cm: " + SRC_MCDOUGAL },
			"paw_mm": { "quality": "secondary", "source": "el ancho de la almohadilla de la mano de un macho, ~10 cm: " + SRC_MCDOUGAL },
			"height_m": DRAW_ONLY, "length_m": DRAW_ONLY,
		},
	},
	"oso": {
		"kind": "mamifero", "species": "Oso pardo (Ursus arctos)",
		"frontal_m2": { "tumbado": { "value": 0.28, "min": 0.20, "max": 0.35 }, "de_pie": { "value": 0.45, "min": 0.35, "max": 0.55 } },
		"cd": { "tumbado": { "value": 0.7, "min": 0.5, "max": 0.9 }, "de_pie": { "value": 1.0, "min": 0.8, "max": 1.2 } },
		"cls_m2": { "tumbado": { "value": 0.2, "min": 0.08, "max": 0.4 }, "de_pie": { "value": 0.0, "min": 0.0, "max": 0.1 } },
		"run_kmh": { "value": 48.0, "quality": "secondary", "source": SRC_GARLAND },
		"quality": "estimate", "source": SRC_HOERNER + "; áreas estimadas desde la masa y el tamaño",
		"contact": 10, "contact_mm": 65.0, "paw_mm": 130.0, "height_m": 1.2, "length_m": 2.0,
		"sources": {
			"frontal_m2": MAMMAL_FRONTAL, "cd": MAMMAL_CD, "cls_m2": MAMMAL_CLS,
			"contact": { "quality": "estimate", "source": "las garras de las dos manos: cinco en cada una (la huella del oso marca cinco dedos: " + SRC_MATTSON + "); que se agarre con las manos es la suposición" },
			"contact_mm": { "quality": "estimate", "source": "la mitad de 130 mm, el ancho de la almohadilla de la mano: " + SRC_MATTSON + "; un oso de 300 kg es un macho, así que es una cota baja" },
			"paw_mm": { "quality": "estimate", "source": "130 mm, dentro de las hembras adultas y por debajo de los machos adultos de " + SRC_MATTSON + ": cota baja para un oso de 300 kg" },
			"height_m": DRAW_ONLY, "length_m": DRAW_ONLY,
		},
	},
	# Casuario (unidad 4d): solo el golpe, con su patada (KICK). No se agarra ni se sube: supports_hold() = false.
	# mass_kg por sexo (la hembra, más pesada, es la de por defecto); contact: la daga del dedo interno, que es la que
	# golpea; height_m y length_m: SOLO para el dibujo.
	"casuario": {
		"kind": "corredora", "species": "Casuario común (Casuarius casuarius)", "attack": "patada", "hold": false,
		"mass_kg": {
			"hembra": { "value": 58.0, "min": 58.0, "max": 76.0, "quality": "secondary", "source": SRC_GRZIMEK + "; máximo: " + SRC_LATCH },
			"macho": { "value": 31.5, "min": 29.0, "max": 55.0, "quality": "secondary", "source": SRC_GRZIMEK + " (valor central del intervalo); máximo: " + SRC_LATCH },
		},
		"run_kmh": { "value": 50.0, "quality": "secondary", "source": SRC_HEALY + "; " + SRC_BORRELL },
		"quality": "secondary", "source": SRC_KOFRON_2003 + "; " + SRC_WESTCOTT,
		"contact": 1, "height_m": 1.6, "length_m": 1.3,
		"sources": {
			"contact": { "quality": "secondary", "source": "la daga del dedo interno, la garra larga que golpea: " + SRC_SABER },
			"height_m": DRAW_ONLY, "length_m": DRAW_ONLY,
		},
	},
	# Velocirraptores (unidad 4i-B2): el de película (FICCIÓN en su garra: corta la chapa; el tamaño, la masa, la garra, el
	# agarre, la carrera y el salto, de Deinonychus, en el que se basó la película) y la reconstrucción (19,7 kg: pincha y
	# sujeta). kind «teropodo»: cuerpo de ave sin alas (solo agazapado), agarre del pie como las rapaces (el de su ficha,
	# dino.forces.grip, con su banda: grip_band) y el golpe saltando (attack «salto»: leap_block). contact: las garras que
	# apoyan quieto encima (los dedos III y IV); strike_claws: las que golpean al saltar (las dos falciformes). height_m es
	# la cadera y length_m el largo con la cola: SOLO para el dibujo, como variant (el aspecto que dibuja la vista).
	"velociraptor_pelicula": {
		"kind": "teropodo", "species": "Velocirraptor de cine (ficción, con el tamaño de Deinonychus)", "attack": "salto",
		"contact": 4, "strike_claws": 2, "contact_mm": 50.0, "frontal": THEROPOD_FRONTAL,
		"run_kmh": { "value": 10.8 * KMH, "max": 13.67 * KMH, "quality": "estimate", "source": "Sin un modelo de la carrera de Deinonychus entre las fuentes usadas: la del modelo de su pariente Velociraptor, el caso modelado más parecido. " + THEROPOD_RUN.source + ". En la película corren como un guepardo: ficción" },
		"height_m": 0.87, "length_m": 3.4, "variant": "pelicula",
		"sources": {
			"contact": THEROPOD_TOES,
			"strike_claws": { "quality": "ficcion", "source": "FICCIÓN (película): sus dos garras falciformes rajan la chapa como en el cine, con la dureza de la garra de película (la de la tachuela de acero del banco, 200 HV). Las de verdad pinchan y sujetan: " + SRC_MANNING_2006 + "; " + SRC_FOWLER_2011 },
			"contact_mm": { "quality": "estimate", "source": "radio del apoyo del pie: el de la reconstrucción (~30 mm, del orden de las dos primeras falanges del dedo III: " + SRC_NORELL_1999 + ") escalado con la cadera de Deinonychus (0,87/0,5 m); solo reparte el peso o el golpe sobre el parabrisas" },
			"height_m": DRAW_ONLY, "length_m": DRAW_ONLY, "variant": DRAW_ONLY,
		},
	},
	"velociraptor": {
		"kind": "teropodo", "species": "Velocirraptor (Velociraptor mongoliensis, reconstrucción)", "attack": "salto",
		"contact": 4, "strike_claws": 2, "contact_mm": 30.0, "frontal": THEROPOD_FRONTAL,
		"run_kmh": { "value": 10.8 * KMH, "max": 13.67 * KMH, "quality": "estimate", "source": THEROPOD_RUN.source },
		"height_m": 0.5, "length_m": 2.07, "variant": "reconstruccion",
		"sources": {
			"contact": THEROPOD_TOES,
			"strike_claws": { "quality": "secondary", "source": "en el salto golpean las dos garras falciformes, una por pie (como el golpe de su ficha: cada pie lleva la mitad del impulso). Pinchan y sujetan, no rajan: " + SRC_MANNING_2006 + "; " + SRC_FOWLER_2011 },
			"contact_mm": { "quality": "estimate", "source": "radio del apoyo del pie, del orden de las dos primeras falanges del dedo III (" + SRC_NORELL_1999 + "); como el del águila" },
			"height_m": DRAW_ONLY, "length_m": DRAW_ONLY, "variant": DRAW_ONLY,
		},
	},
}

## Sexos del casuario (el primero es el de por defecto: la hembra, más pesada).
const SEXES := ["hembra", "macho"]
const SEX_NAMES := { "hembra": "Hembra", "macho": "Macho" }

## La patada del casuario. Nadie la ha medido en un casuario: cada dato sale del caso medido más parecido, con la
## suposición escrita al lado.
##   - Ataque: salta y patea con los pies por delante (Kofron 2003: «cargó, saltó y le pateó el pecho»; «saltó encima»).
##     En la normal del panel el pie llega con la velocidad del salto; la carrera solo cuenta a lo largo del panel (el
##     casuario se para junto al coche para patear).
##   - Velocidad del salto: v = √(2·E/M), con E el trabajo de los músculos de las dos patas, w·(2·f·M): w = 45 J por kg
##     de músculo, medido en el salto máximo de la gallina de Guinea (Henry et al. 2005; hasta 67,5 J/kg, el máximo
##     esperable del músculo esquelético según los mismos autores), y f = 13,0 % de la masa en cada pata, los músculos
##     disecados de un avestruz (Hutchinson et al. 2015). v = √(4·w·f) = 4,84 m/s (hasta 5,93), la misma para cualquier
##     masa (como predijo Hill en 1950: el salto no depende del tamaño). Suposición: el músculo del casuario rinde como el
##     de esas dos aves.
##   - Fuerza de la pata: no pasa de 5,1 pesos corporales (4,2-6,0), la patada medida del secretario sobre una placa rígida
##     (Portugal et al. 2016), del orden del salto máximo de un ave (5,3, Henry et al. 2005). Suposición: la pata del
##     casuario, relativa a su peso, aguanta lo mismo; sobre una chapa que cede la fuerza no puede ser mayor que sobre una
##     placa rígida, y lo que sobra de energía se lo queda la pata (se flexiona) y el rebote.
##   - Duración del contacto medida en el secretario (15 ± 4,4 ms), solo informativa: la del casuario sale del impulso,
##     t = μ_red·v/F, porque detrás de su pie va todo su cuerpo.
const KICK := {
	"force_bw": { "value": 5.1, "min": 4.2, "max": 6.0, "quality": "estimate", "source": "caso medido más parecido: " + SRC_PORTUGAL + "; y " + SRC_HENRY },
	"contact_ms": { "value": 15.0, "min": 10.6, "max": 19.4, "quality": "estimate", "source": SRC_PORTUGAL },
	"work_j_per_kg": { "value": 45.0, "max": 67.5, "quality": "estimate", "source": "caso medido más parecido: " + SRC_HENRY },
	"muscle_fraction": { "value": 8.498 / 65.3, "quality": "estimate", "source": "caso medido más parecido: " + SRC_HUTCHINSON },
}
## Zonas que el casuario alcanza con la patada: lo que tiene a la altura de las patas.
const KICK_ZONES := ["capo", "puerta", "aleta"]
## Por qué el casuario no se ensaya quieto encima del coche.
const HOLD_NO_REASON := "El casuario no se agarra: sus pies son de corredor, con tres dedos y sin dedo trasero para abarcar nada, y sus alas son vestigiales. De pie encima del coche solo lo sujetaría la fricción de los dedos, pero con más de metro y medio de alto sobre unos pies estrechos mandaría el vuelco, que este modelo no calcula, y ni su aerodinámica ni su equilibrio se han medido. Se ensaya su patada: el modo «Se abalanza»."
const KICK_ZONE_REASON := "el casuario patea lo que tiene a la altura de las patas: el capó, una puerta o una aleta"

## El salto de los velocirraptores (unidad 4i-B2; docs/fisica/velociraptor.md §2.6 y §10.3). Despega de la carretera con la
## carrera de su ficha en horizontal (como mucho la central, run_kmh) y el salto en vertical, v = √(4·w·f) (kick_leap_ms: los
## mismos w y f que la patada del casuario); los pies suben lo mismo que el centro de masas, v²/2g (1,19 m; 1,79 con los
## datos más favorables). A un panel de arriba llega de bajada, si llega, y el aire lo frena en el vuelo (leap_flight). Contra
## un costado golpea con la carrera, como el tigre (la puerta y la aleta están a la altura de su cuerpo).
## Altura de los paneles de arriba: la berlina de base de Cui et al. (2025) (4545 × 1730 × 1475 mm, con el borde delantero
## del capó a 70 cm; de 67 a 91 cm en los 452 frontales de turismos que midieron). El capó y el parabrisas suben con el largo y
## la inclinación de sus paneles (IMPACT_ZONES), y el animal cae en la mitad del panel (panel_height_m).
const HOOD_EDGE_M := {
	"value": 0.70, "min": 0.67, "max": 0.91, "quality": "secondary",
	"source": "el borde delantero del capó de la berlina de base de " + SRC_CUI_2025 + ": 70 cm; de 67 a 91 cm en los 452 frontales medidos",
}
const ROOF_M := {
	"value": 1.475, "quality": "secondary",
	"source": "el alto de la berlina de base de " + SRC_CUI_2025 + ": 4545 × 1730 × 1475 mm",
}
const PANEL_HEIGHT_SOURCE := {
	"quality": "estimate",
	"source": "la mitad del panel: el borde del capó y el alto de la berlina de base de Cui et al. (2025), con el largo y la inclinación de los paneles del modelo (estimación: los de una berlina media)",
}
## Integración del vuelo (leap_flight): paso de RK4 (s) y pasos de la bisección del último, el que cruza la altura del panel.
const LEAP_DT := 0.01
const LEAP_BISECT := 40
## Por qué no llega a un panel de arriba (el techo): con su salto no sube tanto.
const LEAP_ZONE_REASON := "con su salto sube ~%s m (hasta ~%s m con los datos más favorables) y %s está a ~%s m: no llega saltando desde la carretera"

## Defensa (unidad 4d): el animal asustado aprieta con toda su fuerza (p.defense). La fuerza de cada pie o mano:
##   - aves: el agarre máximo medido de un pie (ClawsV2, Sustaita & Hertel 2010), que es la pinza entre el dedo trasero
##     y los delanteros: cada talón aprieta con él contra el del lado contrario;
##   - tigre y oso: la fuerza teórica de los músculos que cierran las garras de una mano, la sección fisiológica (PCSA)
##     del flexor profundo de los dedos por la tensión específica del músculo, repartida entre los cinco dedos. Es la
##     fuerza del tendón: en la punta de la garra llega menos, según la palanca de la última falange, que no está medida
##     (cota alta);
##   - casuario: su patada (KICK), toda en la daga.
const SRC_MARTENS := "Martens LL, Piersanti SJ, Berger A, Kida NA, Deutsch AR, Bertok K, Humphries L, Lassiter A, Hartstone-Rose A (2023). The effects of onychectomy (declawing) on antebrachial myology across the full body size range of exotic species of Felidae. Animals 13:2462, doi:10.3390/ani13152462, tabla 2 (músculos del antebrazo disecados en once félidos con uñas de 7 a 176 kg, con dos tigres de 93 y 143 kg; sección fisiológica del flexor profundo de los dedos: log10(√PCSA) = −1,34 + 1,34·log10(M^(1/3)), recta RMA con PCSA en cm² y la masa M en g, r² = 0,94)"
const SRC_POWELL := "Powell PL, Roy RR, Kanim P, Bello MA, Edgerton VR (1984). Predictability of skeletal muscle tension from architectural determinations in guinea pig hindlimbs. J. Appl. Physiol. 57:1715-1721, doi:10.1152/jappl.1984.57.6.1715 (tensión específica de 22,5 N/cm² en los músculos mixtos, contrastada con la tensión medida in situ; 15,4 N/cm² en el sóleo, un músculo lento)"
## Recta de Martens et al. (2023) del flexor profundo de los dedos de los félidos con uñas: log10(√PCSA) = a + b·log10(M^(1/3)).
const FELID_FDP := { "a": -1.34, "b": 1.34 }
## Tensión específica del músculo esquelético (N/cm²): 22,5 en los músculos mixtos y 15,4 en uno lento (Powell 1984).
const SPECIFIC_TENSION := { "value": 22.5, "min": 15.4, "max": 22.5 }
## Dedos con garra de la mano de un félido o de un oso: el flexor profundo de los dedos tira de los cinco.
const PAW_DIGITS := 5
const DEFENSE_SOURCES := {
	"tigre": {
		"quality": "estimate",
		"source": "Caso medido más parecido: la recta de los félidos con uñas de " + SRC_MARTENS + ", llevada a los 220 kg del catálogo (la recta llega hasta el león de 176 kg), por la tensión específica de " + SRC_POWELL + ". Suposición: toda la sección del flexor tira a la vez, con la tensión de un músculo mixto (la banda baja, con la de uno lento).",
	},
	"oso": {
		"quality": "estimate",
		"source": "Caso medido más parecido: la misma recta de los félidos (" + SRC_MARTENS + ") a los 300 kg del oso, por la tensión específica de " + SRC_POWELL + ". Suposición: un oso, que excava y trepa con las garras, tiene los flexores de los dedos al menos como los de un félido de su masa; no hay disecciones publicadas del antebrazo de un oso con su sección fisiológica.",
	},
}
## Arado de la pintura (defensa en un panel liso, rake_n): una garra hundida en su surco solo avanza arando lo que tiene
## delante, con la fuerza de Bowden & Tabor (1950), F = H·A, la dureza por la sección del surco. Es el mismo arado del
## motor (docs/FISICA.md §11: μ_arado ≈ 0,9·Dp, del orden de la expresión de Bowden-Tabor), que en reposo ya va en μ·N.
const SRC_BOWDEN_TABOR := "Bowden FP, Tabor D (1950). The Friction and Lubrication of Solids. Clarendon Press, Oxford (el término de arado: arrastrar una punta hundida pide la dureza del material por la sección del surco que tiene delante, F = H·A)"
const SRC_VODNICK := "Vodnick D (2006). Nanomechanical characterization of coatings. PCI Magazine, 1 de agosto (barniz de poliuretano de coche: 197-425 MPa por nanoindentación; el motor del banco usa 20 HV, 196 MPa, del orden del más blando)"
const PLOUGH := {
	"paint_h_max_mpa": 425.0, "quality": "estimate",
	"source": "Caso medido más parecido: el término de arado de " + SRC_BOWDEN_TABOR + ", con la dureza de la pintura del motor y, en la banda alta, la más dura medida por " + SRC_VODNICK + ". Suposición: la garra hundida no se sale de su surco (la aprieta con mucha más fuerza de la que pide arar la pintura) y la pintura se ara sin saltar a trozos; la sección es la de un surco en V, la mitad de la anchura por la profundidad (cota baja para una punta redondeada). Banda baja: 0 (la garra se sale del surco o la pintura se desconcha, y solo queda la fricción de su peso).",
}

## Geometría de los paneles (unidad 4g): no hay medición publicada panel a panel del coche de referencia; el capó sí se ha
## medido en cientos de coches (Cui et al. 2025). El resto, del orden de una berlina media como el DrivAer del túnel.
const SEDAN_GEOMETRY := {
	"quality": "estimate",
	"source": "del orden de una berlina media como el DrivAer del túnel (" + SRC_DRIVAERML + "): largos e inclinaciones de los paneles sin medición publicada panel a panel (estimación)",
}
const HOOD_LENGTH := {
	"quality": "estimate",
	"source": "1,1 m, dentro de los 54-123 cm medidos en 452 frontales de turismos, en su lado largo: una berlina baja de capó largo (" + SRC_CUI_2025 + ")",
}
const HOOD_SLOPE := {
	"quality": "estimate",
	"source": "10°, un capó de berlina baja: por debajo de los 11-44° medidos en 452 frontales de turismos de todo tipo (" + SRC_CUI_2025 + ")",
}
const ZONE_GEOM := { "slope_deg": SEDAN_GEOMETRY, "slide_m": SEDAN_GEOMETRY, "draw": DRAW_ONLY }
const HOOD_GEOM := { "slope_deg": HOOD_SLOPE, "slide_m": HOOD_LENGTH, "draw": DRAW_ONLY }

## Zonas del coche donde puede quedarse el animal (los velocirraptores, «teropodo», donde un ave o un mamífero grande salvo la
## antena y el retrovisor, en los que no cabe ni se posa un animal de 2-3,4 m; agarran con los pies donde agarran las
## rapaces, unidad 4i-B2). cp: coeficiente de presión con su banda (v_local = v·√(1 − Cp));
## slope_deg: inclinación del panel (+ sube hacia atrás); anchor: «friccion», «agarre» (el ave abarca algo con los
## dedos) o «gancho» (las garras de un mamífero en un borde o hueco), por tipo de animal; edge: el anclaje es un borde
## de chapa que se puede doblar; slide_m: panel disponible para resbalar; draw: posición para el dibujo lateral (0-1);
## sources: fuente y calidad de slope_deg, slide_m y draw (unidad 4g).
const ZONES := {
	"capo": {
		"name": "Capó", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "pintura",
		"cp": { "value": -0.35, "min": -0.49, "max": -0.25, "quality": "secondary", "source": SRC_DRIVAER_PIV + ": 1,12-1,22 veces la velocidad del coche sobre la mitad delantera del capó" },
		"slope_deg": 10.0, "slide_m": 1.1, "draw": { "x": 0.14, "y": 0.58 },
		"sources": HOOD_GEOM,
	},
	"limpiaparabrisas": {
		"name": "Limpiaparabrisas", "animals": ["ave", "mamifero", "teropodo"], "anchor": { "ave": "agarre", "mamifero": "friccion", "teropodo": "agarre" }, "surface": "pintura",
		"cp": { "value": 0.3, "min": 0.1, "max": 0.5, "quality": "estimate", "source": SRC_MATHAI },
		"slope_deg": 25.0, "slide_m": 0.3, "draw": { "x": 0.3, "y": 0.64 },
		"sources": ZONE_GEOM,
	},
	"parabrisas": {
		"name": "Parabrisas", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "vidrio",
		"cp": { "value": 0.0, "min": -0.3, "max": 0.3, "quality": "estimate", "source": "entre el remanso del pie del parabrisas y la succión del borde del techo (" + SRC_MATHAI + "): estimación" },
		"slope_deg": 30.0, "slide_m": 0.9, "draw": { "x": 0.36, "y": 0.76 },
		"sources": ZONE_GEOM,
	},
	"techo": {
		"name": "Techo", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "pintura",
		"cp": { "value": -0.45, "min": -0.64, "max": -0.30, "quality": "secondary", "source": SRC_DRIVAER + ": tomas del techo, media de las tres carrocerías (fastback −0,47, notchback −0,50, estate −0,38)" },
		"slope_deg": 0.0, "slide_m": 1.6, "draw": { "x": 0.55, "y": 0.96 },
		"sources": ZONE_GEOM,
	},
	"barras": {
		"name": "Barras de techo", "animals": ["ave", "mamifero", "teropodo"], "anchor": { "ave": "agarre", "mamifero": "gancho", "teropodo": "agarre" }, "surface": "pintura",
		"cp": { "value": -0.3, "min": -0.39, "max": -0.12, "quality": "secondary", "source": SRC_DRIVAER_PIV + ": 1,06-1,18 veces la velocidad del coche a 4-40 mm sobre el techo" },
		"slope_deg": 0.0, "slide_m": 1.6, "draw": { "x": 0.55, "y": 1.0 },
		"sources": ZONE_GEOM,
	},
	"antena": {
		"name": "Antena", "animals": ["ave"], "anchor": "agarre", "surface": "pintura",
		"cp": { "value": -0.25, "min": -0.39, "max": -0.12, "quality": "secondary", "source": SRC_DRIVAER_PIV + ": flujo sobre la parte trasera del techo" },
		"slope_deg": 0.0, "slide_m": 0.1, "draw": { "x": 0.72, "y": 1.0 },
		"sources": ZONE_GEOM,
	},
	"retrovisor": {
		"name": "Retrovisor", "animals": ["ave"], "anchor": "agarre", "surface": "pintura",
		"cp": { "value": -0.34, "min": -0.49, "max": -0.26, "quality": "secondary", "source": SRC_DRIVAER + ": tomas de las ventanillas delanteras (el retrovisor está en ese flujo lateral)" },
		"slope_deg": 0.0, "slide_m": 0.2, "draw": { "x": 0.33, "y": 0.7 },
		"sources": ZONE_GEOM,
	},
	"ventanilla": {
		"name": "Borde de la ventanilla", "animals": ["ave", "mamifero", "teropodo"], "anchor": { "ave": "agarre", "mamifero": "gancho", "teropodo": "agarre" }, "edge": true, "surface": "pintura",
		"cp": { "value": -0.34, "min": -0.49, "max": -0.26, "quality": "secondary", "source": SRC_DRIVAER + ": tomas de las ventanillas" },
		"slope_deg": 0.0, "slide_m": 0.9, "draw": { "x": 0.5, "y": 0.78 },
		"sources": ZONE_GEOM,
	},
	"maletero": {
		"name": "Maletero", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "pintura",
		"cp": { "value": -0.15, "min": -0.28, "max": 0.01, "quality": "secondary", "source": SRC_DRIVAER + ": luneta y zaga de las tres carrocerías" },
		"slope_deg": -15.0, "slide_m": 1.0, "draw": { "x": 0.88, "y": 0.7 },
		"sources": ZONE_GEOM,
	},
	"aleta": {
		"name": "Aleta", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "pintura",
		"cp": { "value": -0.35, "min": -0.49, "max": -0.25, "quality": "estimate", "source": "como la parte delantera del capó, junto a la que está (" + SRC_DRIVAER_PIV + ")" },
		"slope_deg": 5.0, "slide_m": 0.8, "draw": { "x": 0.12, "y": 0.52 },
		"sources": ZONE_GEOM,
	},
	# unidad 4v: la luneta trasera, de vidrio templado (CarGlass.rear_window): aguanta entera o estalla bajo el animal
	"luneta": {
		"name": "Luneta", "animals": ["ave", "mamifero", "teropodo"], "anchor": "friccion", "surface": "vidrio", "tempered": true,
		"cp": { "value": -0.15, "min": -0.28, "max": 0.01, "quality": "secondary", "source": SRC_DRIVAER + ": luneta y zaga de las tres carrocerías" },
		"slope_deg": -25.0, "slide_m": 0.6, "draw": { "x": 0.77, "y": 0.84 },
		"sources": {
			"slope_deg": { "quality": "estimate", "source": "una luneta de berlina que baja ~25° hacia atrás, entre la del fastback (más tumbada) y la del notchback del DrivAer (" + SRC_DRIVAERML + "): sin medición publicada (estimación)" },
			"slide_m": SEDAN_GEOMETRY, "draw": DRAW_ONLY,
		},
	},
}

## Zonas del golpe al abalanzarse: normal «arriba» (panel casi horizontal, con su inclinación) o «lado» (puerta y aleta
## por fuera). hold: zona en la que puede quedarse después (null: se cae). clearance_mm: hueco bajo el panel, el tope de
## la abolladura (ESTIMACIÓN: capó 80 mm, dentro de los 20-100 mm ensayados bajo un capó por Fredriksson et al. 2007;
## techo 100, por debajo de los 127 mm que la FMVSS 216 deja bajar el techo; puerta 150, los primeros 152 mm con los que
## la FMVSS 214 mide la puerta; aleta 60, sin medición). slide_m: panel para resbalar. sources: la fuente y la calidad de
## slope_deg, slide_m y clearance_mm (unidad 4g).
const IMPACT_ZONES := {
	"capo": {
		"name": "Capó", "normal": "arriba", "slope_deg": 10.0, "slide_m": 1.1, "clearance_mm": 80.0, "hold": "capo", "glass": false,
		"sources": {
			"slope_deg": HOOD_SLOPE, "slide_m": HOOD_LENGTH,
			"clearance_mm": { "quality": "estimate", "source": "80 mm, dentro de los 20-100 mm ensayados bajo un capó: " + SRC_FREDRIKSSON },
		},
	},
	"techo": {
		"name": "Techo", "normal": "arriba", "slope_deg": 0.0, "slide_m": 1.6, "clearance_mm": 100.0, "hold": "techo", "glass": false,
		"sources": {
			"slope_deg": SEDAN_GEOMETRY, "slide_m": SEDAN_GEOMETRY,
			"clearance_mm": { "quality": "estimate", "source": "100 mm, por debajo de los 127 mm que la norma deja bajar el techo con 1,5 veces el peso del coche (" + SRC_FMVSS_216 + "); sin medición del hueco bajo la chapa del techo" },
		},
	},
	"parabrisas": {
		"name": "Parabrisas", "normal": "arriba", "slope_deg": 30.0, "slide_m": 0.9, "clearance_mm": 0.0, "hold": "parabrisas", "glass": true,
		"sources": {
			"slope_deg": SEDAN_GEOMETRY, "slide_m": SEDAN_GEOMETRY,
			"clearance_mm": { "quality": "primary", "source": "no se usa: el parabrisas no se abolla, se agrieta (vidrio laminado que flexa como una placa, Roark)" },
		},
	},
	"puerta": {
		"name": "Puerta", "normal": "lado", "slope_deg": 90.0, "slide_m": 1.0, "clearance_mm": 150.0, "hold": null, "glass": false,
		"sources": {
			"slope_deg": { "quality": "estimate", "source": "un costado vertical (las puertas se inclinan hacia dentro unos grados: estimación)" },
			"slide_m": SEDAN_GEOMETRY,
			"clearance_mm": { "quality": "estimate", "source": "150 mm, los primeros 152 mm de aplastamiento con los que la norma mide la resistencia de la puerta (" + SRC_FMVSS_214 + "); sin medición del hueco entre la chapa de fuera y la de dentro" },
		},
	},
	"aleta": {
		"name": "Aleta", "normal": "lado", "slope_deg": 90.0, "slide_m": 0.8, "clearance_mm": 60.0, "hold": null, "glass": false,
		"sources": {
			"slope_deg": { "quality": "estimate", "source": "un costado vertical, como la puerta (estimación)" },
			"slide_m": SEDAN_GEOMETRY,
			"clearance_mm": { "quality": "estimate", "source": "60 mm, menos que en la puerta porque detrás de la aleta está el paso de rueda: sin medición (estimación)" },
		},
	},
	# unidad 4m: la ventanilla templada, la luna lateral (su id no es «ventanilla», que en ZONES es su borde, donde se agarra).
	# Un costado de vidrio templado (Glazing.SIDE_WINDOW, la hoja del banco): no se abolla; aguanta entera o estalla
	# (side_window_impact). tempered: la hoja es la del templado, no el parabrisas laminado. Llega quien alcanza la luna, de la
	# cintura del coche al techo (window_reach).
	"luna": {
		"name": "Ventanilla", "normal": "lado", "slope_deg": 90.0, "slide_m": 0.8, "clearance_mm": 0.0, "hold": null, "glass": true,
		"tempered": true, "draw": { "x": 0.425, "y": 0.78 },
		"sources": {
			"draw": { "quality": "dibujo", "source": "solo para el dibujo: el centro de la ventanilla delantera de la vista (la silueta del coche en 3D), la que golpea; 0-1 sobre la silueta lateral, como los puntos de las zonas" },
			"slope_deg": { "quality": "estimate", "source": "un costado vertical, como la puerta: la luna se inclina hacia dentro unos grados (la cabina se estrecha hacia el techo) y el golpe de lado se toma horizontal (estimación)" },
			"slide_m": { "quality": "estimate", "source": "la ventanilla de la puerta delantera de una berlina media como el DrivAer del túnel (" + SRC_DRIVAERML + "): ~0,8 m de largo, sin medición publicada (estimación); en un costado el animal no resbala por ella: cae" },
			"clearance_mm": { "quality": "primary", "source": "no se usa: la ventanilla templada no se abolla; aguanta entera o estalla en trocitos (el templado con el perfil de Nielsen, Schneider & Kraus 2022)" },
		},
	},
}

## La hondura de una marca que atraviesa el panel (unidad 4o; docs/fisica/coche-en-marcha.md §16): la del panel, la pintura y la
## chapa o el plástico (panel_um); lo que hay detrás es el hueco bajo el panel (clearance_mm de IMPACT_ZONES, el mismo tope
## de la abolladura), y la punta de la garra no entra más que ese hueco ni más que su largo (room_um). Quieto encima, el hueco
## es el de la zona del golpe con el mismo panel: las barras y la antena están en el techo. En las demás zonas en las que se
## queda (el limpiaparabrisas, el borde de la ventanilla, el maletero y el retrovisor) no hay dato del hueco: solo la limita
## su largo.
const HOLD_PANEL := { "capo": "capo", "techo": "techo", "barras": "techo", "antena": "techo", "aleta": "aleta" }
## Dónde está el hueco de cada panel del golpe, para los textos: «bajo el capó», «tras la puerta».
const PANEL_GAP_TXT := { "capo": "bajo el capó", "techo": "bajo el techo", "puerta": "tras la puerta", "aleta": "tras la aleta" }
## La banda del hueco bajo el panel (unidad 4o; la banda del golpe, impact_band): solo el capó tiene un caso medido, los 20-100
## mm de hueco que se ensayaron bajo un capó con una cabeza de ensayo y una placa rígida regulable debajo (Fredriksson et al.
## 2007; el hueco cambia de un punto a otro del capó, según lo que haya debajo: Lindgren et al. 2025). Con menos hueco, la
## abolladura y la punta de unas garras que lo atraviesan topan antes con lo que hay debajo (con todo a favor del capó: a lo de
## debajo, el modelo no le calcula el daño). Los del techo, la puerta y la aleta no tienen medición del hueco (ni del espacio
## entre la chapa y lo que hay detrás): sin banda, y lo dice CLEARANCE_FIXED.
const CLEARANCE_BAND := {
	"capo": {
		"min": 20.0, "max": 100.0, "quality": "estimate",
		"source": "de 20 a 100 mm, los huecos que se ensayaron bajo un capó con una cabeza de ensayo y una placa rígida regulable debajo (Fredriksson et al. 2007, vía Lindgren et al. 2025); suposición: el hueco de este capó, de un punto a otro, cae dentro de lo ensayado",
	},
}
## Por qué el resto de los huecos no tienen banda (la fuente de la banda del golpe): la norma solo dice cuánto puede ceder el
## panel en su ensayo, no qué hueco hay detrás.
const CLEARANCE_FIXED := {
	"techo": "sin medición del hueco bajo la chapa del techo: la norma solo dice cuánto puede bajar el techo en su ensayo (127 mm, FMVSS 216)",
	"puerta": "sin medición del hueco entre la chapa de fuera y la de dentro: la norma solo dice hasta dónde se aplasta la puerta en su ensayo (152 mm, FMVSS 214)",
	"aleta": "sin medición: detrás de la aleta está el paso de rueda",
}

## Abolladura: la de la unidad 1f (core/lab/dent.gd, calibrada con Nippon Steel 2013): colapso plástico 2π·M0 y
## trabajo de membrana, con el golpe repartido entre la chapa y el muelle de la pata (Physics.MODEL.limbStiffness).
## El golpe de un cuerpo entero se reparte entre sus apoyos (4 patas, 2 pies, o hombro y cadera de lado). Añadido de
## esta unidad: el muelle de la pata no puede comprimirse más que su recorrido; con cientos de kilos, lo que no cabe
## en ese recorrido va a la chapa. Tope de la abolladura: el hueco bajo el panel (clearance_mm de IMPACT_ZONES).
## Recorrido de las patas o del cuerpo que amortigua (mm): ESTIMACIÓN del orden de la flexión de las patas al aterrizar.
const LIMB_STROKE_MM := 150.0
const LIMB_STROKE := {
	"value": LIMB_STROKE_MM, "quality": "estimate",
	"source": "orden de la flexión de las patas de un felino o un oso al aterrizar (~15 cm); sin medición. Sin banda: nadie ha medido cuánto se doblan sus patas en un golpe así, y en la banda del golpe se queda fijo",
}
## Rigidez de la pata que golpea (N/mm, cada apoyo): la del motor del banco, Physics.MODEL.limbStiffness (el valor vive allí;
## aquí, su fuente y su calidad, unidad 4g). Nadie ha medido la pata de un tigre, un oso o un ave contra una chapa: lo más
## parecido medido es la rigidez de la pata al correr, que crece con la masa (Farley et al. 1993).
const LIMB_STIFFNESS := {
	"quality": "estimate",
	"source": "la del motor del banco (10 N/mm: el tejido blando de una pata o un dedo que golpea, estimación de la 1.x). Caso medido más parecido: " + SRC_FARLEY + ". Suposición: la misma para todos los animales; como la de las patas grandes es mayor, es una cota baja para el tigre y el oso (con la suya, la chapa se llevaría más energía y las abolladuras serían más hondas). Sin banda: la de la pata al correr es la del muelle de todo el animal en cada zancada, no la de una pata contra una chapa, y nadie ha medido esa; en la banda del golpe se queda fija",
}

## Fuentes en palabras de los modelos del banco que usa el golpe (unidad 4j: sin rutas ni nombres de código): la abolladura
## de la chapa (Dent), la flexión de la hoja de vidrio (la ventana y el parabrisas) y la punción con golpe del motor.
const SRC_DENT := "abolladura de una placa con una carga concentrada (análisis límite, Jones 1989: colapso plástico y trabajo de membrana), con la tensión de flujo de la chapa calibrada con la abolladura medida por Nippon Steel (2013, fig. 6)"
const SRC_GLASS_FLEX := "U = F²/2k de la hoja, que flexa como una placa apoyada (Roark), con la resistencia del vidrio recocido (45 MPa, EN 572-1)"
const SRC_PUNCTURE := "la punción con golpe del motor del banco: cada garra con su parte de la masa reducida y la velocidad contra el panel"

## Desgarro de la aleta de plástico (unidad 4g). En un golpe de costado, unas garras que atraviesan el termoplástico de lado
## a lado quedan trabadas en él: si el animal sigue a lo largo del panel, para arrastrarlas tiene que rajarlo. Cada garra
## abre una grieta de todo el espesor t, con la energía por unidad de área de grieta R del plástico: la frena F = R·t (R en
## kJ/m² = N/mm y t en mm), y ½·m·v² = n·R·t·L (balance de energía, tear_run). Solo si el animal aguanta esa fuerza con
## las garras clavadas (su anclaje, el mismo que quieto encima con las garras clavadas); si no, sus dedos ceden y se
## sueltan. R por id de carrocería (CAR_BODIES): value, min y max en kJ/m².
const SRC_SABIC_GTX964 := "SABIC (2024). NORYL GTX™ resin GTX964, región Europa, valores típicos (revisión 20241014): PPE+PA sin reforzar, con modificador de impacto, para paneles exteriores de coche; resiliencia con entalla Charpy en V de canto (ISO 179/1eA) de 45 kJ/m² a 23 °C y 20 kJ/m² a −30 °C, Izod con entalla (ISO 180/1A) de 50 y 20 kJ/m²; fluencia 50 MPa y rotura al 50 %"
const PLASTIC_TEAR := {
	"plastico-carroceria": {
		"value": 45.0, "min": 20.0, "max": 50.0, "quality": "estimate",
		"source": "Caso medido más parecido: la resiliencia con entalla del mismo plástico, " + SRC_SABIC_GTX964 + ". Es la energía por unidad de área de grieta al romper una barra entallada con un péndulo a unos 3 m/s (ISO 179 e ISO 180), del orden de la velocidad de una garra que lo raja (de 1,5 a 13 m/s con el coche a 40-90 km/h; más deprisa, como con más frío, un plástico tenaz se vuelve más frágil, y la banda baja, la de −30 °C, lo cubre). Valor, Charpy a 23 °C; banda, de 20 (en frío, a −30 °C) a 50 (Izod a 23 °C). Suposiciones: cada garra abre una sola grieta de todo el espesor; no se cuenta lo que cuesta doblar los labios del desgarro para dejarla pasar ni la pintura (110 µm), así que es una cota baja de la energía y alta del largo del desgarro; el plástico está a unos 20 °C.",
	},
}

## La ventanilla templada en el golpe (unidad 4m; docs/fisica/coche-en-marcha.md §15). La zona «luna» de IMPACT_ZONES, con la
## hoja del banco (Glazing.SIDE_WINDOW: sus números viven allí) y el golpe del parabrisas (la fuerza de pico de cada apoyo
## contra la hoja y la pata en serie), y Glazing.tempered_result: estalla entera si la flexión llega a su resistencia o si
## una punta al menos tan dura como el vidrio abre una grieta que atraviesa la capa comprimida.
const WINDOW_ZONE := "luna"
## Qué ventanilla golpea: la de delante. A lo largo del coche el modelo no sabe dónde cae el golpe (lo decide cuándo se cruzan,
## no la física): golpea en el centro de la ventanilla delantera del dibujo (IMPACT_ZONES.luna.draw: 0-1 sobre la silueta
## lateral, como los draw de ZONES; CarShape.side_windows(), lo comprueba tests/app/test_moving_car_window_draw.gd), la de la misma puerta que
## el golpe en la puerta. Solo dibujo: la física no usa el punto.
const WINDOW_PANE := "front"
const WINDOW_PANE_SOURCE := {
	"quality": "dibujo",
	"source": "golpea la ventanilla de delante: a lo largo del coche no hay un criterio físico que decida dónde cae el golpe (lo decide cuándo se cruzan el animal y el coche), y la de delante es la de la misma puerta que el golpe en la puerta; el punto, el centro de la ventanilla delantera del dibujo",
}
## Dónde empieza la ventanilla: la línea de cintura, que en una berlina arranca al pie del parabrisas (la luna lateral empieza a
## la altura del final del capó). Su altura es la del borde del capó de la berlina de base de Cui et al. (2025) más lo que sube
## el capó del modelo (IMPACT_ZONES.capo); el borde de arriba, el alto de esa berlina (ROOF_M). Estimación: entre las fuentes
## usadas no hay una medición publicada de la cintura de los turismos.
const WINDOW_SILL_SOURCE := {
	"quality": "estimate",
	"source": "la línea de cintura empieza al pie del parabrisas, como en una berlina: el borde delantero del capó de la berlina de base de " + SRC_CUI_2025 + ", 70 cm (de 67 a 91 cm en los 452 frontales medidos), más lo que sube el capó del modelo (1,1 m a 10°); arriba, el alto de esa berlina (1475 mm). Sin medición publicada de la cintura (estimación: caso medido más parecido, el frontal)",
}
# Lo más alto que llega un mamífero a cuatro patas (para la ventanilla): la cruz, de la literatura (nunca height_m de BODIES,
# que es del dibujo)
const SRC_SDZWA_TIGER := "San Diego Zoo Wildlife Alliance Library, ficha del tigre (Panthera tigris), características físicas, con datos de Hunter L (2011), Wild Cats of the World (Bloomsbury, Londres), y Mazák V (1981), Panthera tigris, Mammalian Species 152:1-8 (80-100 cm a la cruz, en machos y hembras)"
const SRC_ADW_BEAR := "Animal Diversity Web (Museo de Zoología de la Universidad de Michigan), ficha de Ursus arctos, con datos de Nowak & Paradiso (1983), Walker's Mammals of the World, y Wilson & Ruff (1999), The Smithsonian Book of North American Mammals (90-150 cm a la cruz; de 80 a más de 600 kg)"
## La cruz (m) del tigre y del oso: lo más alto de su cuerpo a cuatro patas, con su banda.
const WITHERS_M := {
	"tigre": {
		"value": 0.9, "min": 0.8, "max": 1.0, "quality": "secondary",
		"source": SRC_SDZWA_TIGER + "; valor: el centro del intervalo publicado",
	},
	"oso": {
		"value": 1.2, "min": 0.9, "max": 1.5, "quality": "estimate",
		"source": SRC_ADW_BEAR + "; un oso de 300 kg es un macho grande: el centro del intervalo publicado (estimación)",
	},
}
## Por qué no llega a la ventanilla (window_reach): a cuatro patas, el centro de su apoyo queda por debajo de la cintura.
const WINDOW_LOW_REASON := "a cuatro patas, su cruz está a ~%s (de %s a %s) y la ventanilla empieza a ~%s, en la cintura del coche: el centro de su apoyo (~%s mm de radio) queda por debajo y golpea la puerta%s. Para golpear la luna tendría que saltar o erguirse, y eso no está medido"
## Las fuentes de los «¿sabías que…?» de la ventanilla (moving_car_state.gd), más cortas que la de la hoja entera.
const SRC_TEMPER := "Nielsen JH, Schneider J, Kraus MA (2022): el perfil del temple (la capa comprimida, el 21 % del espesor) y la relación entre la energía que guarda y el tamaño de los trocitos; compresión de las caras ~100 MPa, una estimación dentro de los 80-150 MPa medidos en templados comerciales (Achintha 2020) y de los 40-400 trocitos por cada 5 × 5 cm que exige la CEPE R43"
const SRC_PUNCH := "la grieta radial de Anstis et al. (1981), más fácil cuanto más afilada es la punta, tiene que vencer la tenacidad del vidrio y el cierre de la capa comprimida (el templado con el perfil de Nielsen, Schneider & Kraus 2022); al flexar, una placa redonda apoyada (Roark) con 120 MPa de resistencia (EN 12150-1)"
## La compresión de las caras del templado con la banda medida (la banda del golpe, impact_band): la central es la de
## Glazing.SIDE_WINDOW (100 MPa, una estimación); los extremos, los de los templados comerciales. Con más compresión, la
## grieta que revienta la luna pide más fuerza (Glazing.pierce_load) y los trocitos salen más pequeños
## (Glazing.fragment_size_mm). La resistencia a flexión (120 MPa) es la de la norma, sin banda: no se mueve.
const TEMPER_SIGMA_MPA := {
	"min": 80.0, "max": 150.0, "quality": "secondary",
	"source": "Achintha M (2020): de 80 a 150 MPa de compresión en las caras de los templados comerciales, medidos con polariscopio",
}
## El casuario: patea lo que tiene a la altura de las patas (KICK_ZONES).
const WINDOW_KICK_REASON := "el casuario patea lo que tiene a la altura de las patas: el capó, una puerta o una aleta. Saltando llegaría a la ventanilla (sus pies suben ~%s) y a veces rompe el cristal a patadas o picotazos (Naish 2007), pero una patada hacia arriba contra una luna no está en el modelo"

## Artículo y terminación de los adjetivos de cada animal (solo gramática de los textos: «el águila» es femenino).
const GRAMMAR := {
	"aguila": ["el", "a"], "arpia": ["el", "a"], "halcon": ["el", "o"], "buho": ["el", "o"], "lechuza": ["la", "a"],
	"buitre": ["el", "o"], "tigre": ["el", "o"], "oso": ["el", "o"], "casuario": ["el", "o"],
	"velociraptor": ["el", "o"], "velociraptor_pelicula": ["el", "o"],
}
## Nota de seguridad vial para el final del ensayo.
const SAFETY_NOTE := "Experimento mental. En la carretera, si aparece un animal: frena en línea recta, sin volantazos, y avisa al 112 si queda un animal herido en la calzada."


# ════════ Datos ════════

## Cuerpo del animal para el coche en marcha (BODIES) o null si no hay datos (el resto del catálogo).
static func body_of(claw: Variant) -> Variant:
	if claw == null:
		return null
	return BODIES.get(claw.get("id") if claw is Dictionary else claw)


## ¿Se puede ensayar este animal en el coche en marcha? (en algún modo: quieto encima o al abalanzarse)
static func supports(claw: Variant) -> bool:
	return body_of(claw) != null


## ¿Se puede quedar encima del coche en marcha? (modo «Encima del coche»: setup, hold_report). El casuario, no.
static func supports_hold(claw: Variant) -> bool:
	var b: Variant = body_of(claw)
	return b != null and b.get("hold", true) != false


## ¿Se puede abalanzar sobre el coche? (modo «Se abalanza»: impact). Todos los animales con datos.
static func supports_impact(claw: Variant) -> bool:
	return body_of(claw) != null


## ¿Ataca con una patada (el casuario) en vez de con el cuerpo entero?
static func is_kicker(body: Variant) -> bool:
	return body != null and body.get("attack") == "patada"


## Zonas del golpe (IMPACT_ZONES) que alcanza este animal: el casuario, solo las de KICK_ZONES; la ventanilla (unidad 4m), quien
## llega a ella (window_reach).
static func impact_zones_for(claw: Variant) -> Array:
	var b: Variant = body_of(claw)
	if b == null:
		return []
	if is_kicker(b):
		return KICK_ZONES.duplicate()
	var zones: Array = IMPACT_ZONES.keys()
	if is_leaper(b):
		zones = zones.filter(func(z: String) -> bool: return leap_reaches(z))
	if not window_reach(claw if claw is Dictionary else { "id": String(claw) }, b).reaches:
		zones.erase(WINDOW_ZONE)
	return zones


## Sexos con datos propios del animal (el casuario) o [] si su masa no cambia con el sexo.
static func sexes_of(claw: Variant) -> Array:
	var b: Variant = body_of(claw)
	return SEXES.duplicate() if b != null and b.has("mass_kg") else []


## Sexo del ensayo: p.sex si el animal tiene masa por sexo (y es válido); si no, el primero; null si no tiene.
static func sex_of(body: Variant, p: Dictionary) -> Variant:
	if body == null or not body.has("mass_kg"):
		return null
	var s := String(p.get("sex", SEXES[0]))
	return s if body.mass_kg.has(s) else SEXES[0]


## Masa (kg) del animal en el coche en marcha: la del sexo si la tiene (casuario); si no, la del catálogo.
static func mass_of(claw: Dictionary, sex: Variant = null) -> float:
	var b: Variant = body_of(claw)
	if b != null and b.has("mass_kg"):
		var s := String(sex) if sex != null and b.mass_kg.has(String(sex)) else String(SEXES[0])
		return float(b.mass_kg[s].value)
	return float(claw.mass)


## Material de las garras del ensayo (Data.INLAYS): p.inlay es su id («none» por defecto: queratina). null si no existe.
## Un material del catálogo 2.0 que no está en Data.INLAYS (los de la reforja: el rubí y la alúmina, ForgeData.NEW_MATERIALS,
## con la forma de Data.INLAYS) llega entero en p.inlay desde el estado (MovingCarState.inlay_param): aquí no se puede
## precargar Catalog ni ForgeData, que acaban precargando este archivo.
static func inlay_of(p: Dictionary) -> Variant:
	var v: Variant = p.get("inlay", "none")
	var id := "none"
	if v is Dictionary:
		id = String(v.get("id", "none"))
	elif v != null:
		id = String(v)
	var e: Variant = Data.find_by_id(Data.INLAYS, id)
	if e == null and v is Dictionary and (v as Dictionary).has("hv"):
		return v
	return e


## Id del material pedido (para el texto del error si no existe).
static func _inlay_id(p: Dictionary) -> String:
	var v: Variant = p.get("inlay", "none")
	return String(v.get("id", "")) if v is Dictionary else String(v)


## ¿Pueden unas garras de este material cortar la chapa del coche? El criterio de siempre del motor: con
## r = HV_garra/HV_chapa por debajo de 0,8 cede la punta (Physics.MODEL.rOff). true en el plástico. Sin material (inlay
## «none»), la garra de siempre: con claw, su propia dureza (la queratina, 26-33 HV, nunca; la garra de película del
## velocirraptor de ficción, sí: unidad 4i-B2); sin claw, la queratina.
static func can_cut_body(inlay: Dictionary, target: Dictionary, claw: Variant = null) -> bool:
	var body: Variant = target.get("body")
	if body == null or not Js.truthy(body.get("metal")):
		return true
	if inlay.id == "none":
		return claw is Dictionary and float(claw.hv) / float(body.hv) >= float(Physics.MODEL.rOff)
	return float(inlay.hv) / float(body.hv) >= float(Physics.MODEL.rOff)


## Velocidad (m/s) con la que el casuario llega a la chapa al saltar y patear: v = √(4·w·f) (KICK). hi: con el trabajo
## muscular máximo esperable (banda alta).
static func kick_leap_ms(hi: bool = false) -> float:
	var w: float = KICK.work_j_per_kg.max if hi else KICK.work_j_per_kg.value
	return sqrt(4.0 * w * float(KICK.muscle_fraction.value))


## Fuerza máxima (N) de la pata que patea: force_bw pesos corporales (which: «value», «min» o «max»).
static func kick_force_n(mass_kg: float, which: String = "value") -> float:
	return float(KICK.force_bw[which]) * mass_kg * G


# ════════ Velocirraptores (unidad 4i-B2) ════════

## ¿Se abalanza saltando (los velocirraptores: attack «salto»)?
static func is_leaper(body: Variant) -> bool:
	return body != null and body.get("attack") == "salto"


## ¿Es el velocirraptor de película (FICCIÓN: su garra corta la chapa)? Lo dice su entrada del catálogo (dino.film).
static func is_film(claw: Variant) -> bool:
	return claw is Dictionary and claw.get("dino") is Dictionary and claw.dino.get("film") == true


## Garras que golpean: al saltar, las dos falciformes (strike_claws); si no, las que tocan el panel (contact).
static func strike_claws_of(body: Dictionary) -> int:
	return int(body.get("strike_claws", body.contact))


## Agarre de un pie { value, min, max } (N): el de la ficha de un dinosaurio (dino.forces.grip, con su banda); si no, el de
## ClawsV2 (las rapaces, escalado de Sustaita & Hertel 2010).
static func grip_band(claw: Dictionary) -> Dictionary:
	var g: Variant = _dino_grip(claw)
	if g != null:
		return { "value": float(g.value), "min": float(g.min), "max": float(g.max) }
	return ClawsV2.band(claw, "force")


## Calidad y fuente del agarre de un pie: { quality, source }.
static func grip_source(claw: Dictionary) -> Dictionary:
	var g: Variant = _dino_grip(claw)
	if g != null:
		return { "quality": String(g.quality), "source": String(g.source) }
	var o: Variant = ClawsV2.override_of(claw, "force")
	return {
		"quality": o.get("quality", "estimate") if o != null else "estimate",
		"source": String(o.get("source", "")) if o != null else "agarre del catálogo 1.x",
	}


static func _dino_grip(claw: Dictionary) -> Variant:
	var d: Variant = claw.get("dino")
	if not (d is Dictionary) or not (d.get("forces") is Dictionary):
		return null
	return d.forces.get("grip")


## Anclaje de unas garras clavadas: el agarre del pie (aves y velocirraptores) o las garras enganchadas (mamíferos).
static func _clasp(kind: String) -> String:
	return "agarre" if kind == "ave" or kind == "teropodo" else "gancho"


## Altura (m) sobre la carretera de la mitad de un panel de arriba (capó, parabrisas o techo), o null en un costado. which:
## «value», «min» o «max» del borde del capó (HOOD_EDGE_M).
static func panel_height_m(zone_id: String, which: String = "value") -> Variant:
	var edge := float(HOOD_EDGE_M.get(which, HOOD_EDGE_M.value))
	var hood: Dictionary = IMPACT_ZONES.capo
	var rise := float(hood.slide_m) * V8.js_sin(float(hood.slope_deg) * PI / 180.0)
	match zone_id:
		"capo":
			return edge + 0.5 * rise
		"parabrisas":
			var ws: Dictionary = IMPACT_ZONES.parabrisas
			return edge + rise + 0.5 * float(ws.slide_m) * V8.js_sin(float(ws.slope_deg) * PI / 180.0)
		"techo":
			return float(ROOF_M.value)
	return null


## Lo que suben los pies al saltar (m): lo que sube el centro de masas, v²/2g (sin aire). hi: con los datos más favorables.
static func leap_reach_m(hi: bool = false) -> float:
	var v := kick_leap_ms(hi)
	return v * v / (2.0 * G)


## ¿Llega saltando desde la carretera a esa zona del golpe? A los costados, siempre; a un panel de arriba, si está más bajo
## de lo que sube (con los datos centrales).
static func leap_reaches(zone_id: String) -> bool:
	var h: Variant = panel_height_m(zone_id)
	return h == null or float(h) <= leap_reach_m()


## El vuelo de un salto desde la carretera hasta un panel a h_m de altura: despega con (ux, uy, uz) m/s y el aire quieto lo
## frena con D = ½·ρ·CdA·|u|², en contra de su velocidad; RK4 en pasos de LEAP_DT s y bisección del paso en el que, ya de
## bajada, el centro de masas cruza la altura del panel (los pies suben lo mismo que él). { reaches (ha subido por encima
## del panel y cae sobre él), apexM, timeS, ux, uy, uz (m/s al llegar; uz < 0, bajando), lossMs (lo que le quita el aire a
## la velocidad frente al vuelo sin aire) }. Pura y determinista (solo sumas, productos y raíces).
static func leap_flight(m: float, cda: float, rho: float, ux: float, uy: float, uz: float, h_m: float) -> Dictionary:
	var k := 0.5 * rho * cda / m if m > 0.0 else 0.0
	var st := PackedFloat64Array([0.0, ux, uy, uz])
	var apex := 0.0
	var above := false
	var t := 0.0
	var landed := false
	for _i in 4000:
		var nx := _leap_rk4(st, LEAP_DT, k)
		apex = maxf(apex, nx[0])
		if nx[0] > h_m:
			above = true
		if above and nx[3] < 0.0 and nx[0] <= h_m:
			# el paso que cruza la altura del panel, de bajada: bisección del tiempo dentro del paso
			var lo := 0.0
			var hi := LEAP_DT
			for _j in LEAP_BISECT:
				var mid := 0.5 * (lo + hi)
				if _leap_rk4(st, mid, k)[0] > h_m:
					lo = mid
				else:
					hi = mid
			st = _leap_rk4(st, hi, k)
			t += hi
			landed = true
			break
		if not above and nx[3] < 0.0:
			break  # ya baja sin haber llegado a la altura del panel
		st = nx
		t += LEAP_DT
	var u2 := ux * ux + uy * uy + uz * uz
	var free := sqrt(maxf(u2 - 2.0 * G * h_m, 0.0))
	var got := sqrt(st[1] * st[1] + st[2] * st[2] + st[3] * st[3])
	return {
		"reaches": landed, "apexM": apex, "timeS": t, "ux": st[1], "uy": st[2], "uz": st[3],
		"lossMs": maxf(free - got, 0.0) if landed else 0.0,
	}


static func _leap_rk4(s: PackedFloat64Array, dt: float, k: float) -> PackedFloat64Array:
	var a := _leap_rate(s, k)
	var b := _leap_rate(_leap_add(s, a, 0.5 * dt), k)
	var c := _leap_rate(_leap_add(s, b, 0.5 * dt), k)
	var d := _leap_rate(_leap_add(s, c, dt), k)
	var out := PackedFloat64Array()
	out.resize(4)
	for i in 4:
		out[i] = s[i] + dt * (a[i] + 2.0 * b[i] + 2.0 * c[i] + d[i]) / 6.0
	return out


## d/dt de (z, ux, uy, uz): la gravedad y la resistencia del aire, −k·|u|·u.
static func _leap_rate(s: PackedFloat64Array, k: float) -> PackedFloat64Array:
	var sp := sqrt(s[1] * s[1] + s[2] * s[2] + s[3] * s[3])
	return PackedFloat64Array([s[3], -k * sp * s[1], -k * sp * s[2], -G - k * sp * s[3]])


static func _leap_add(s: PackedFloat64Array, r: PackedFloat64Array, h: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(4)
	for i in 4:
		out[i] = s[i] + h * r[i]
	return out


## El salto de un velocirraptor en el golpe (unidad 4i-B2): { runKmh (la carrera con la que despega: la pedida, como mucho la
## central de su ficha), runAskedKmh, runMaxKmh, runCapped, leapMs, leapKmh, leapMaxMs (el salto, kick_leap_ms), reachM,
## reachMaxM (lo que sube, v²/2g), side (contra un costado golpea con la carrera, sin saltar), panelM (la altura del panel
## de arriba), reaches, reason (si no llega), apexM, timeS, ux, uy, uz (m/s al llegar, respecto al suelo), airLossKmh (lo que
## le quita el aire en el vuelo), cdaM2, quality, source }. m: su masa (kg); rho: el aire del ensayo.
## hi (unidad 4j, la banda del golpe): con los datos más favorables al salto, el trabajo muscular máximo (kick_leap_ms(true)) y
## la carrera más alta de su ficha (run_kmh.max).
static func leap_block(
	claw: Dictionary, body: Dictionary, zone_id: String, va_asked: float, th: float, rho: float, m: float, hi: bool = false
) -> Dictionary:
	var run_max: float = float(body.run_kmh.get("max", body.run_kmh.value) if hi else body.run_kmh.value) / KMH
	var va := minf(va_asked, run_max)
	var v_l := kick_leap_ms(hi)
	var iz: Dictionary = IMPACT_ZONES[zone_id]
	var side: bool = iz.normal == "lado"
	var ux := va * V8.js_cos(th)
	var uy := va * V8.js_sin(th)
	var out := {
		"runKmh": va * KMH, "runAskedKmh": va_asked * KMH, "runMaxKmh": run_max * KMH, "runCapped": va_asked > run_max + 1e-9,
		"leapMs": v_l, "leapKmh": v_l * KMH, "leapMaxMs": kick_leap_ms(true), "reachM": leap_reach_m(), "reachMaxM": leap_reach_m(true),
		"side": side, "panelM": null, "reaches": true, "reason": "", "apexM": 0.0, "timeS": 0.0, "ux": ux, "uy": uy, "uz": 0.0,
		"airLossKmh": 0.0, "cdaM2": null, "quality": "estimate",
		"source": "salto: " + String(KICK.work_j_per_kg.source) + "; " + String(KICK.muscle_fraction.source) + " (los mismos w y f que la patada del casuario) · carrera: " + String(body.run_kmh.source) + " · altura de los paneles: " + String(PANEL_HEIGHT_SOURCE.source),
	}
	if side:
		return out
	var h := float(panel_height_m(zone_id))
	var aero := _aero_sets(claw, body, String(body.kind), String(POSTURES[body.kind][0]))
	var cda: float = aero.nom.cda
	var fl := leap_flight(m, cda, rho, ux, uy, v_l, h)
	out.panelM = h
	out.cdaM2 = cda
	out.apexM = fl.apexM
	out.reaches = fl.reaches
	if not fl.reaches:
		out.reason = LEAP_ZONE_REASON % [Js.to_fixed(leap_reach_m(), 2), Js.to_fixed(leap_reach_m(true), 2),
			"el " + String(iz.name).to_lower(), Js.to_fixed(h, 2)]
		return out
	out.ux = fl.ux
	out.uy = fl.uy
	out.uz = fl.uz
	out.timeS = fl.timeS
	out.airLossKmh = float(fl.lossMs) * KMH
	return out


## El salto en palabras (la fila Salto del informe): «corre a ~39 km/h y salta a 4.84 m/s: sube ~1.19 m y cae sobre el
## panel (a ~0.80 m) a ~2.7 m/s de bajada; el aire le quita ~0.2 km/h en el vuelo» o, contra un costado, «… y se abalanza
## contra el costado, a la altura de su cuerpo: no le hace falta saltar».
static func leap_txt(l: Dictionary) -> String:
	if Js.truthy(l.get("window")):
		return window_leap_txt(l)  # unidad 4m: salta para llegar a la ventanilla
	var run := "corre a ~%s" % CarFormat.fmt_kmh(float(l.runKmh))
	if Js.truthy(l.get("runCapped")) and CarFormat.kmh_txt(float(l.runAskedKmh)) != CarFormat.kmh_txt(float(l.runMaxKmh)):
		run = "corre como mucho a ~%s, lo más que corre (se pidieron %s)" % [CarFormat.fmt_kmh(float(l.runMaxKmh)),
			CarFormat.kmh_txt(float(l.runAskedKmh))]
	if Js.truthy(l.side):
		return "%s y se abalanza contra el costado, a la altura de su cuerpo: no le hace falta saltar" % run
	var air := "menos de 0.1 km/h" if float(l.airLossKmh) < 0.05 else "~" + CarFormat.fmt_kmh1(float(l.airLossKmh))
	return "%s y salta a %s: sube ~%s y cae sobre el panel (a ~%s) a ~%s de bajada; el aire le quita %s en el vuelo" % [
		run, CarFormat.fmt_mps(float(l.leapMs), 2), CarFormat.fmt_m(float(l.reachM), 2), CarFormat.fmt_m(float(l.panelM), 2),
		CarFormat.fmt_mps(-float(l.uz), 1), air]


## La masa de más de unas garras reforjadas en el golpe (ClawMass, unidad 4e; docs/fisica/velociraptor.md §4): el cono del
## motor de cada garra que golpea (cota alta: la garra real es más fina) con la densidad de su material menos la de la
## queratina. Como la velocidad relativa la impone el coche, la masa de más suma ½·Δm·v² (extraJ, con v_rel_ms). { addedKg (las
## n garras), perClawKg, clawKg, keratinKg, bodyShare (de la masa del animal), volumeMm3, claws, extraJ, quality, source } o
## null con queratina (o sin densidad medida del material).
static func claw_mass_block(claw: Dictionary, inlay: Dictionary, n_claws: int, animal_kg: float, v_rel_ms: float = 0.0) -> Variant:
	if inlay.id == "none":
		return null
	var vol := ClawMass.cone_volume_mm3(float(claw.reach))
	var e: Variant = ClawMass.energy_effect(inlay, vol, n_claws, animal_kg, animal_kg / float(maxi(n_claws, 1)), v_rel_ms)
	if e == null:
		return null
	var added: float = e.addedKg
	return {
		"addedKg": added, "perClawKg": float(e.clawKg) - float(e.keratinKg), "clawKg": e.clawKg, "keratinKg": e.keratinKg,
		"bodyShare": e.bodyShare, "volumeMm3": vol, "claws": n_claws, "extraJ": 0.5 * added * v_rel_ms * v_rel_ms,
		"quality": e.quality,
		"source": "densidad: " + String(e.source) + " · volumen: el cono del motor (base de 0,15 × el alcance), una cota alta · con la velocidad que impone el coche, la masa de más suma ½·Δm·v²",
	}


## El compromiso del afilado de unas garras reforjadas quietas encima del coche (unidad 4i-B2; el deslizador «Afilado» de
## la tarjeta, como en el banco): Physics.sharpness_report con la carga de cada garra (su parte del peso, m·g/contact)
## rayando la pintura del coche. null si no se pueden afilar (queratina, garra de película o un animal sin datos).
static func sharpness_report(p: Dictionary) -> Variant:
	var claw: Dictionary = ClawsV2.apply(p.claw)
	var body: Variant = body_of(claw)
	var inlay: Variant = inlay_of(p)
	if body == null or inlay == null or inlay.id == "none":
		return null
	var per_claw := float(claw.mass) * G / float(body.contact)
	return Physics.sharpness_report(_lab_params(claw, p.target, {
		"force": per_claw, "inlay": inlay, "model": p.get("model", "2.0"), "sharpness": p.get("sharpness", 0.0),
	}))


## La garra afilada del ensayo (unidad 4i-B2): con unas garras reforjadas y p.sharpness > 0 (Physics.sharpness_of, el mismo
## del banco), la punta de ClawSharpness.sharpen: otra área y otro radio, con el mismo semiángulo. El resto del coche en
## marcha la usa tal cual (marcas, punción, rotura, anclaje y vidrio). { claw, info: { sharpness, tipRadiusUm,
## naturalTipRadiusUm } o null sin afilar }.
static func _sharpen(claw: Dictionary, inlay: Dictionary, p: Dictionary) -> Dictionary:
	var s := Physics.sharpness_of({ "claw": claw, "inlay": inlay, "model": p.get("model", "2.0"), "sharpness": p.get("sharpness") })
	if s <= 0.0:
		return { "claw": claw, "info": null }
	var sharp := ClawSharpness.sharpen(claw, s)
	return {
		"claw": sharp,
		"info": { "sharpness": sharp.sharpness, "tipRadiusUm": sharp.tipRadiusUm, "naturalTipRadiusUm": sharp.naturalTipRadiusUm },
	}


## Sección fisiológica (cm²) del flexor profundo de los dedos de una mano de félido de masa mass_kg: la recta de
## Martens et al. (2023), log10(√PCSA) = a + b·log10(M^(1/3)), con M en gramos (FELID_FDP).
static func felid_fdp_pcsa_cm2(mass_kg: float) -> float:
	var root := V8.js_pow(10.0, float(FELID_FDP.a) + float(FELID_FDP.b) * V8.js_log10(mass_kg * 1000.0) / 3.0)
	return root * root


## Fuerza de defensa: con cuánta fuerza aprieta cada pie o mano un animal asustado (N). { value, min, max (por pie o
## mano), perClaw: { value, min, max } (en cada garra), claws (garras que la reparten), per («pie» o «mano»), kind
## («agarre», «flexores» o «patada»), quality, source } o null (sin datos). Lo explica el comentario de SRC_MARTENS.
static func defense_force(claw: Dictionary, sex: Variant = null) -> Variant:
	var c: Dictionary = ClawsV2.apply(claw)
	var b: Variant = body_of(c)
	if b == null:
		return null
	if is_kicker(b):
		var m := mass_of(c, sex)
		var kv := kick_force_n(m)
		var kmin := kick_force_n(m, "min")
		var kmax := kick_force_n(m, "max")
		return {
			"value": kv, "min": kmin, "max": kmax, "perClaw": { "value": kv, "min": kmin, "max": kmax }, "claws": 1,
			"per": "pie", "kind": "patada", "quality": KICK.force_bw.quality, "source": KICK.force_bw.source,
		}
	if b.kind == "ave" or b.kind == "teropodo":
		var g := grip_band(c)
		var gs := grip_source(c)
		# la pinza: el talón trasero aprieta con el agarre contra los delanteros, y estos con lo mismo contra él (en los
		# velocirraptores, el agarre de su ficha: unidad 4i-B2)
		return {
			"value": float(g.value), "min": float(g.min), "max": float(g.max),
			"perClaw": { "value": float(g.value), "min": float(g.min), "max": float(g.max) }, "claws": 2, "per": "pie",
			"kind": "agarre", "quality": gs.quality, "source": gs.source,
		}
	var ds: Variant = DEFENSE_SOURCES.get(String(c.id))
	if ds == null:
		return null
	var pcsa := felid_fdp_pcsa_cm2(float(c.mass))
	var st: Dictionary = SPECIFIC_TENSION
	var fv := pcsa * float(st.value)
	var fmin := pcsa * float(st.min)
	var fmax := pcsa * float(st.max)
	var n := float(PAW_DIGITS)
	return {
		"value": fv, "min": fmin, "max": fmax, "perClaw": { "value": fv / n, "min": fmin / n, "max": fmax / n },
		"claws": PAW_DIGITS, "per": "mano", "kind": "flexores", "pcsaCm2": pcsa, "quality": ds.quality, "source": ds.source,
	}


## Posturas del animal (la primera es la de por defecto).
static func postures_of(claw: Variant) -> Array:
	var b: Variant = body_of(claw)
	return POSTURES[b.kind] if b != null else []


## Zonas del coche en las que puede ponerse este animal.
static func zones_for(claw: Variant) -> Array:
	var b: Variant = body_of(claw)
	var out: Array = []
	if b == null:
		return out
	for id: String in ZONES:
		if ZONES[id].animals.has(b.kind):
			out.append(id)
	return out


## Área frontal (m²) del cuerpo de un ave de masa m (kg) en vuelo (Pennycuick 1988).
static func bird_frontal_m2(mass_kg: float) -> float:
	return BIRD_AERO.frontal_coef * V8.js_pow(mass_kg, BIRD_AERO.frontal_exp)


## Factor de velocidad local de una zona: v_local / v = √(1 − Cp).
static func local_factor(cp: float) -> float:
	return sqrt(maxf(1.0 - cp, 0.0))


## Presión del aire (Pa) a la altitud h (m) en la atmósfera tipo (ISO 2533, troposfera): p0·(1 − L·h/T0)^(g0/(R·L)).
static func air_pressure_pa(altitude_m: float) -> float:
	var h := clampf(altitude_m, -500.0, 11000.0)
	return ISA_P0 * V8.js_pow(1.0 - ISA_LAPSE * h / ISA_T0, ISA_G0 / (R_AIR * ISA_LAPSE))


## Densidad del aire seco (kg/m³) a la temperatura t (°C) y la altitud h (m): ρ = p(h)/(R·T).
static func air_density(temp_c: float = 20.0, altitude_m: float = 0.0) -> float:
	return air_pressure_pa(altitude_m) / (R_AIR * (maxf(temp_c, -100.0) + KELVIN))


## El aire de un ensayo: { tempC, altitudeM, pPa, rho, rhoRatio (ρ/ρ de referencia), speedFactor }. speedFactor =
## √(ρ_ref/ρ): sin viento, la fuerza del aire solo depende de ρ·v² y la velocidad de despegue escala exactamente así.
static func air_of(temp_c: float, altitude_m: float) -> Dictionary:
	var rho := air_density(temp_c, altitude_m)
	return {
		"tempC": temp_c, "altitudeM": altitude_m, "pPa": air_pressure_pa(altitude_m), "rho": rho,
		"rhoRatio": rho / RHO_AIR, "speedFactor": sqrt(RHO_AIR / rho), "quality": "primary", "source": SRC_ISA,
	}


## El aire en palabras: «1.146 kg/m³ a 35 °C y 0 m: un 4.9 % menos denso que a 20 °C al nivel del mar».
static func air_txt(air: Dictionary) -> String:
	var diff := (float(air.rhoRatio) - 1.0) * 100.0
	var cmp := "como a 20 °C al nivel del mar"
	if absf(diff) >= 0.05:
		cmp = "un %s %% %s denso que a 20 °C al nivel del mar" % [Js.to_fixed(absf(diff), 1), "más" if diff > 0.0 else "menos"]
	return "%s kg/m³ a %s °C y %s m: %s" % [
		Js.to_fixed(air.rho, 3), Js.js_num_str(Js.js_round(float(air.tempC))), Js.js_num_str(Js.js_round(float(air.altitudeM))), cmp]


## El mismo ensayo con otro aire (temperatura y altitud) sin volver a llamar a compute(): la fricción, el anclaje y
## las marcas no cambian; la resistencia y la sustentación, con ρ. Sirve para un deslizador de temperatura o de altitud
## en directo (una copia: el ensayo de partida no se toca).
static func with_air(scen: Dictionary, temp_c: float, altitude_m: float) -> Dictionary:
	if not Js.truthy(scen.get("ok")):
		return scen
	var air := air_of(temp_c, altitude_m)
	var rho: float = air.rho
	var cases: Dictionary = scen.cases
	var lo: Array = []
	for c: Dictionary in cases.lo:
		lo.append(_with_rho(c, rho))
	var hi: Array = []
	for c: Dictionary in cases.hi:
		hi.append(_with_rho(c, rho))
	var out := scen.duplicate()
	out.cases = { "nom": _with_rho(cases.nom, rho), "lo": lo, "hi": hi }
	out.rho = rho
	out.air = air
	return out


## Un caso con otra densidad del aire (las mismas operaciones que _case).
static func _with_rho(c: Dictionary, rho: float) -> Dictionary:
	var d := c.duplicate()
	var k := 0.5 * rho * maxf(1.0 - float(c.cp), 0.0)
	d.kd = k * float(c.cda)
	d.kl = k * float(c.cls)
	d.klr = k * float(c.clsr)
	return d


## Tipo de anclaje de una zona para un tipo de animal.
static func anchor_kind(zone: Dictionary, kind: String) -> String:
	var a: Variant = zone.anchor
	return String(a.get(kind, "friccion")) if a is Dictionary else String(a)


## ¿La carrocería del objetivo es de metal? (true para acero y aluminio; false para la aleta de plástico).
static func is_metal(target: Dictionary) -> bool:
	var body: Variant = target.get("body")
	return body != null and Js.truthy(body.get("metal"))


# ════════ Escenario: animal quieto sobre el coche ════════

## Prepara un ensayo. p: { claw, target (coche), zone, posture, wind_kmh, crosswind_kmh, accel_g, lateral_g, temp_c,
## altitude_m, embedded, inlay, embed_mm, model }. Llama una vez a Physics.compute() (la garra arando la superficie: μ y
## marcas). Devuelve los coeficientes que at_speed() usa en cada fotograma: { ok, reason?, claw, kind, zone, posture,
## anchor, mass, grip, mu, rho, air, cases, inlay, clawHoldN, … }. inlay: id de Data.INLAYS («none», queratina, por
## defecto); con unas garras que cortan el metal, embedded vale también en la chapa (las garras la han perforado), y el
## anclaje no pasa de lo que aguantan de lado (clawHoldN: claws_hold_n, con la punta a embed_mm de la superficie; por
## defecto, clavadas hasta la base).
static func setup(p: Dictionary) -> Dictionary:
	var claw: Dictionary = ClawsV2.apply(p.claw)
	var body: Variant = body_of(claw)
	if body == null:
		return { "ok": false, "reason": "sin datos aerodinámicos de %s" % Data.claw_title(claw).to_lower() }
	if not supports_hold(claw):
		return { "ok": false, "reason": HOLD_NO_REASON }
	var inlay: Variant = inlay_of(p)
	if inlay == null:
		return { "ok": false, "reason": "material de garra «%s» desconocido" % _inlay_id(p) }
	# unidad 4i-B2: la garra afilada (unas garras reforjadas con p.sharpness > 0)
	var sharp := _sharpen(claw, inlay, p)
	claw = sharp.claw
	var kind: String = body.kind
	var zone_id := String(p.get("zone", "techo"))
	var zone: Variant = ZONES.get(zone_id)
	if zone == null or not zone.animals.has(kind):
		return { "ok": false, "reason": "zona «%s» no disponible para este animal" % zone_id }
	var posture := String(p.get("posture", POSTURES[kind][0]))
	if not POSTURES[kind].has(posture):
		posture = POSTURES[kind][0]
	var target: Dictionary = p.target
	var m: float = claw.mass
	var glass: bool = zone.surface == "vidrio"
	var tempered := glass and Js.truthy(zone.get("tempered"))  # unidad 4v: la luneta templada
	var n_contact: int = body.contact
	var per_claw := m * G / n_contact
	var model: Variant = p.get("model", "2.0")
	var slide_mm: float = float(zone.slide_m) * 1000.0
	# unidad 4o: unas garras que atraviesan el panel no entran más que el hueco que hay detrás (el de la zona del golpe con el
	# mismo panel; sin dato, solo las limita su largo)
	var tip_room := room_um(target, hold_clearance_mm(zone_id))
	var marks := _marks(claw, target, glass, per_claw, slide_mm, model, inlay, false, tip_room)
	var mu: float = marks.mu
	var slope: float = zone.slope_deg
	var patch_n := m * G * V8.js_cos(slope * PI / 180.0) / float(_patches(kind))
	# defensa (p.defense): asustado aprieta con toda su fuerza; desgarra lo que su garra corta y puede quedarse clavado
	var dfn: Variant = null
	if Js.truthy(p.get("defense")):
		dfn = defense_block(claw, target, glass, inlay, per_claw, slide_mm, model, null, patch_n, float(body.contact_mm), tip_room, tempered)
	var anchor := anchor_kind(zone, kind)
	var anchor_rest := anchor
	# garras clavadas: en el plástico, como siempre; en la chapa, solo si su material corta el metal
	var embedded: bool = Js.truthy(p.get("embedded")) and zone.surface == "pintura" and can_cut_body(inlay, target, claw)
	if anchor == "friccion" and embedded:
		anchor = _clasp(kind)
		anchor_rest = anchor
	var stuck: bool = dfn != null and dfn.stuck and zone.surface == "pintura"
	if anchor == "friccion" and stuck:
		anchor = _clasp(kind)
	embedded = embedded or stuck
	var cap := _anchor_capacity(anchor, kind, claw, body, m, target, zone, dfn.forceN if dfn != null else null)
	# unas garras reforjadas clavadas en la chapa no sujetan más de lo que aguantan de lado (claws_hold_n): si ceden, se
	# rompen o se doblan y solo queda la fricción
	var claws_hold: Variant = null
	if embedded and inlay.id != "none" and is_metal(target):
		var embed_mm := float(p.get("embed_mm", INF))
		if stuck and not p.has("embed_mm"):
			embed_mm = float(dfn.tear.tipUm) / 1000.0  # donde está la punta (unidad 4o: la hondura del desgarro es la del panel)
		claws_hold = claws_hold_n(claw, inlay, target, n_contact, embed_mm, model)
		if claws_hold != null:
			cap = {
				"value": minf(float(cap.value), float(claws_hold.value)), "min": minf(float(cap.min), float(claws_hold.min)),
				"max": minf(float(cap.max), float(claws_hold.max)),
			}
	# asustado en un panel liso, con las garras hundidas en la pintura más que en reposo: para arrastrarlo, el viento tiene
	# que ararla (rake_n). En el vidrio, frágil, no hay arado que contar: la queratina no entra y una punta más dura lo raya.
	var rake: Variant = null
	if dfn != null and anchor == "friccion" and not glass:
		var pc: Dictionary = dfn.perClawBand
		var per_def := { "value": maxf(float(pc.value), per_claw), "max": maxf(float(pc.max), per_claw) }
		rake = rake_n(claw, inlay, target, marks.summary, dfn.tear, per_def, n_contact, model)
		if rake != null:
			cap = { "value": rake.value, "min": rake.min, "max": rake.max }
	if dfn != null:
		dfn["anchor"] = anchor
		dfn["anchorN"] = cap
		dfn["restAnchor"] = anchor_rest
		dfn["restAnchorN"] = _anchor_capacity(anchor_rest, kind, claw, body, m, target, zone)
		dfn["rakeN"] = rake
		if stuck:
			dfn.vsub += "; con las garras clavadas se sujeta con ~%s" % _fmt_n(float(cap.value))
		elif anchor != "friccion" and float(cap.value) > float(dfn.restAnchorN.value) + 1e-9:
			dfn.vsub += "; enganchado, sujeta ~%s en vez de ~%s" % [_fmt_n(float(cap.value)), _fmt_n(float(dfn.restAnchorN.value))]
		elif rake != null:
			var gives := "se romperían" if ClawFracture.behavior(inlay) == "fragil" else "se doblarían"
			if float(rake.value) > 0.0:
				var into := "la pintura y la chapa" if float(dfn.tear.depthUm) > float(Data.PAINT_LAYERS[-1].to) + 1.0 else "la pintura"
				dfn.vsub += "; con las garras hundidas en %s, para arrastrarlo el viento tiene que hacerlas arar: ~%s más que la fricción de su peso" % [into, _fmt_n(float(rake.value))]
				if rake.limited:
					dfn.vsub += " (con más, sus garras %s)" % gives
			elif rake.limited:
				dfn.vsub += "; sin nada que agarrar, la fricción es la de su peso: sus garras %s antes de arar más hondo" % gives
			else:
				dfn.vsub += "; sin nada que agarrar, la fricción es la de su peso: con su peso ya araba la pintura, y asustado no la ara más"
		elif anchor == "friccion" and not glass:
			dfn.vsub += "; sin nada que agarrar, la fricción es la de su peso"
	# unidad 4v: la luneta templada con el animal encima (su peso por apoyo y, asustado, lo que aprieta cada garra): entera o
	# estallada; si estalla, pierde ese apoyo (sin fricción ni anclaje: se suelta parado) y caen trocitos dentro del coche
	var rear: Variant = null
	if tempered:
		var claw_n := per_claw if dfn == null else maxf(per_claw, float(dfn.perClawN))
		rear = CarGlass.tempered_hold(CarGlass.rear_window(), patch_n, claw_n, float(body.contact_mm), claw_tip(claw, inlay, model))
		if dfn != null:
			var rv := rear_window_verdict(rear, dfn, inlay)
			dfn.verdict = rv.verdict
			dfn.vsub = rv.vsub
		if bool(rear.shattered):
			mu = 0.0
			cap = { "value": 0.0, "min": 0.0, "max": 0.0 }
	var f_min: float = 0.0 if rear != null and bool(rear.shattered) else float(FRICTION.min)
	var f_max: float = 0.0 if rear != null and bool(rear.shattered) else float(FRICTION.max)
	var aero := _aero_sets(claw, body, kind, posture)
	var air := air_of(float(p.get("temp_c", PARAMS.temp_c.default)), float(p.get("altitude_m", PARAMS.altitude_m.default)))
	var rho: float = air.rho
	var cp: Dictionary = zone.cp
	var lo: Array = []
	for a: Dictionary in aero.lo:
		lo.append(_case(m, a.cda, a.cls, f_min, cap.min, cp.min, slope, rho, a.clsr))
	var hi: Array = []
	for a: Dictionary in aero.hi:
		hi.append(_case(m, a.cda, a.cls, f_max, cap.max, cp.max, slope, rho, a.clsr))
	# un animal pesado de pie sobre el parabrisas: el peso de cada apoyo contra la fuerza que agrieta el laminado; unas
	# garras reforjadas al menos tan duras como el vidrio lo agrietan también por contacto
	var shield: Variant = null
	if glass and not tempered:
		var cracks := _glass_contact_cracks(claw, inlay, per_claw, false, marks.summary, model)
		shield = windshield_load(patch_n, float(body.contact_mm), cracks)
		if inlay.id != "none":
			shield["contactCracks"] = cracks
		# unidad 4v: lo que tapa la grieta al conductor (estimación)
		shield["viewLoss"] = CarGlass.view_loss(bool(shield.cracked), cracks and float(patch_n) < float(shield.bendN), _patches(kind), n_contact, float(zone.slide_m))
	return {
		"ok": true, "claw": claw.id, "kind": kind, "species": body.species, "zone": zone_id, "posture": posture,
		"anchor": anchor, "embedded": embedded, "target": target.id, "mass": m, "inlay": inlay.id,
		"vmaxKmh": slider_max_kmh(target), "carCdA": car_cda(target),
		"grip": ClawsV2.band(claw, "force"), "mu": mu, "anchorN": cap, "clawHoldN": claws_hold, "rho": rho, "air": air,
		"cases": { "nom": _case(m, aero.nom.cda, aero.nom.cls, mu, cap.value, cp.value, slope, rho, aero.nom.clsr), "lo": lo, "hi": hi },
		"wh": float(p.get("wind_kmh", 0.0)) / KMH, "wc": float(p.get("crosswind_kmh", 0.0)) / KMH,
		"ax": float(p.get("accel_g", 0.0)) * G, "ay": float(p.get("lateral_g", 0.0)) * G,
		"cp": cp.value, "slopeDeg": slope, "localFactor": local_factor(cp.value),
		"scratch": marks.summary, "windshield": shield, "defense": dfn, "rearWindow": rear,
		"draw": _draw_data(body, zone),
		# unidad 4i-B2: la punta afilada (null sin afilar) y si es el velocirraptor de película (ficción)
		"sharpness": sharp.info, "film": is_film(claw),
		# unidad 4s: lo que necesita marks_at_speed (la garra resuelta y afilada, el material, el panel y la fuerza de defensa
		# por garra, con su banda); para uso interno, como cases
		"holdCtx": {
			"claw": claw, "inlay": inlay, "target": target, "glass": glass, "nContact": n_contact, "perClaw0": per_claw,
			"tempered": tempered, "contactMm": float(body.contact_mm), "patches": _patches(kind),
			"slideMm": slide_mm, "tipRoom": tip_room, "model": model, "kind": kind,
			"defPerClaw": dfn.perClawBand if dfn != null else null, "embedded": embedded,
			"clawAnchored": embedded or (rake != null and float(rake.value) > 0.0),
		},
	}


# ════════ Unidad 4s: las marcas a cada velocidad ════════

## La hondura (µm) de la pintura con todas sus capas: donde empieza la carrocería (Data.PAINT_LAYERS).
const PAINT_UM: float = Data.PAINT_LAYERS[-1]["to"]

## Unidad 4s: la carga de la garra del animal agarrado a cada velocidad. Encima del coche, la garra es un gancho: la fuerza
## que el animal tiene que hacer para no soltarse (needN, a lo largo del panel) se la reparten las garras que agarran, y cada
## una la recibe en la punta, que la toma junto con lo que aprieta contra el panel (su parte de la normal R, o la fuerza de
## defensa si está asustado). La punta de un gancho trabaja a lo largo de la garra: la fuerza con la que indenta la pintura
## es la resultante de las dos, √(N² + T²) (claw hooking: la fuerza en la punta de una garra enganchada crece con la carga
## que tira de ella; el caso medido más parecido, Dai, Gorb & Schwarz 2002). Estimación con la suposición escrita.
const CLAW_HOOK := {
	"quality": "estimate",
	"source": "Caso medido más parecido: la garra como gancho, Dai Z, Gorb SN, Schwarz U (2002). Roughness-dependent friction force of the tarsal claw system in the beetle Pachnoda marginata. J. Exp. Biol. 205:2479-2488 (la fuerza de la garra enganchada crece con la carga que tira de ella y la punta la toma a lo largo de la garra). Suposición: la fuerza que el animal necesita para no soltarse a esa velocidad se reparte por igual entre las garras que agarran y cada punta recibe la resultante de su parte y de lo que aprieta contra el panel; con el coche parado y sin maniobra, es su peso: las marcas de siempre",
}


## Unidad 4s: las marcas del animal agarrado con el coche a v_kmh, con la carga de cada garra que sale de lo que tiene que
## aguantar a esa velocidad (CLAW_HOOK): el surco del motor de siempre (_marks: hondura, capas, si llega a la chapa y si la
## raja de lado a lado) y la punción estática de la punta apretando (Physics.compute, «puncion» sin golpe: hasta dónde se
## clava y si atraviesa el panel; la queratina no atraviesa el acero: su punta cede antes, penEff). which: «value» (el caso
## central), «lo» (todo en contra del coche: la fuerza necesaria máxima y la defensa máxima) o «hi» (todo a favor). Con
## v = 0 y sin maniobra ni viento da las marcas de scen.scratch (o los desgarros de la defensa). Cuesta dos compute()
## (~1,5 ms): no es para cada fotograma, sino para la curva (CarSpeedMarks.curve) que se calcula una vez por ensayo.
## { vKmh, needN, normalN, pressN (lo que aprieta cada garra), tangN (lo que tira de cada garra a lo largo del panel), tipN
##   (la resultante en la punta), claws, marks (el resumen de _scratch_summary), puncture (el bloque de _puncture_block, o
##   null en el vidrio), holds, mode, quality, source }.
static func marks_at_speed(scen: Dictionary, v_kmh: float, which: String = "value") -> Dictionary:
	var h: Dictionary = scen.holdCtx
	var s := at_speed(scen, v_kmh)
	var n := int(h.nContact)
	var need: float = s.needN
	if which == "lo":
		need = s.needMaxN
	elif which == "hi":
		need = s.needMinN
	var press := maxf(float(s.normalN), 0.0) / float(n)
	var dpc: Variant = h.defPerClaw
	if dpc != null:
		press = maxf(press, float(dpc.get("max" if which == "lo" else ("min" if which == "hi" else "value"), dpc.value)))
	var tang := maxf(need, 0.0) / float(n)
	var tip_n := sqrt(press * press + tang * tang)
	var claw: Dictionary = h.claw
	var inlay: Dictionary = h.inlay
	var target: Dictionary = h.target
	var glass: bool = h.glass
	var mk := _marks(claw, target, glass, tip_n, float(h.slideMm), h.model, inlay, dpc != null, float(h.tipRoom))
	var punct: Variant = null
	if not glass:
		var over := { "method": "puncion", "strike": false, "force": tip_n, "model": h.model }
		if inlay.id != "none":
			over["inlay"] = inlay
		var r := Physics.compute(_lab_params(claw, target, over))
		punct = _puncture_block(r, claw, inlay, target, float(h.tipRoom), h.model)
	# la presión nominal en la punta frente a la dureza de la garra (como en defense_block): si pasa, la punta se aplasta y
	# reparte (la queratina contra el acero que no corta)
	var area := float(claw.area)
	var h_claw: float = float(claw_tip(claw, inlay, h.model).hv) * Contact.HV_MPA
	var p_tip := tip_n / area if area > 0.0 else INF
	return {
		"vKmh": s.vKmh, "needN": need, "normalN": s.normalN, "pressN": press, "tangN": tang, "tipN": tip_n, "claws": n,
		"marks": mk.summary, "mu": mk.mu, "puncture": punct, "holds": s.holds, "mode": s.mode,
		"tipAreaMm2": area, "tipPressureMPa": p_tip, "clawHardnessMPa": h_claw, "tipYields": p_tip > h_claw,
		"rearWindow": _rear_at_speed(h, s, tip_n),
		"quality": CLAW_HOOK.quality, "source": CLAW_HOOK.source,
	}


## Unidad 4v: la luneta templada a esa velocidad (null si no está encima de ella): lo que aprieta cada apoyo (su parte de la
## normal) y cada garra (la carga de su punta, tip_n), con CarGlass.tempered_hold.
static func _rear_at_speed(h: Dictionary, s: Dictionary, tip_n: float) -> Variant:
	if not Js.truthy(h.get("tempered")):
		return null
	var patch := maxf(float(s.normalN), 0.0) / float(maxi(int(h.get("patches", 1)), 1))
	return CarGlass.tempered_hold(CarGlass.rear_window(), patch, tip_n, float(h.get("contactMm", 0.0)), claw_tip(h.claw, h.inlay, h.model))


## Apoyos con los que un animal toca el panel: 4 patas o 2 pies.
static func _patches(kind: String) -> int:
	return 4 if kind == "mamifero" else 2


## Marcas y fricción de las garras al resbalar por la superficie. En la pintura, el motor de siempre (la garra arando el
## barniz con su parte del peso: profundidad, capas y μ con el arado de Hokkirigawa-Kato). En el vidrio (550 HV) la
## queratina no raya (r < 0,8): μ es el del vidrio del catálogo y no hay marcas. inlay (Data.INLAYS o null): unas garras
## reforjadas rayan con el motor de siempre, también el vidrio si son más duras que él. tear: el modo desgarro del motor
## (la garra curva tira como un gancho, Physics.tear_leverage), el de un animal asustado que aprieta. { mu, summary }.
## room (unidad 4o): hasta dónde puede llegar la punta de una garra que atraviesa el panel (room_um: el panel y el hueco de
## detrás; INF sin dato): el surco que lo atraviesa es tan hondo como el panel y su punta no pasa de ahí (_scratch_summary).
static func _marks(
	claw: Dictionary, target: Dictionary, glass: bool, per_claw: float, length_mm: float, model: Variant,
	inlay: Variant = null, tear: bool = false, room: float = INF
) -> Dictionary:
	var reforged: bool = inlay != null and inlay.id != "none"
	if glass and not reforged:
		var gl := _glass()
		return {
			"mu": Contact.clamp_js(float(gl.mu), FRICTION.min, FRICTION.max),
			"summary": {
				"depthUm": 0.0, "residualUm": 0.0, "verdict": "NO RAYA", "layer": null, "scratched": false, "muEff": gl.mu,
				"widthUm": 0.0, "layers": [], "reachesBody": false, "through": false, "tipUm": 0.0, "belowMm": 0.0,
				"bottoms": false, "fab": 1.0,
				# unidad 4v: la queratina deja una mancha en el vidrio (CarGlass.trace_kind)
				"trace": "mancha", "ratio": float(claw.hv) / float(gl.hv),
			},
		}
	var surface: Dictionary = _glass() if glass else target
	var over := { "force": per_claw, "length": length_mm, "model": model }
	if reforged:
		over["inlay"] = inlay
	if tear:
		over["tear"] = true
	var r := Physics.compute(_lab_params(claw, surface, over))
	var summary := _scratch_summary(r, surface, room, claw, inlay, model)
	if glass:
		# en el vidrio no hay pintura ni carrocería debajo; si el parabrisas se agrieta lo decide Glazing (el veredicto del
		# motor sobre su hoja de ventana del catálogo no vale para el laminado): aquí solo si lo raya
		summary.layers = []
		summary.reachesBody = false
		# unidad 4v: raya solo si la punta es al menos 1,25 veces más dura que el vidrio (el criterio de la lente de la
		# cetrería); por debajo, el oro, el acero o el titanio dejan el trazo de su metal (CarGlass.glass_scratch)
		var tool_hv := float(Physics.resolve_tool(_lab_params(claw, surface, over)).hv)
		summary = CarGlass.glass_scratch(summary, String(inlay.id) if reforged else "none", tool_hv, float(surface.hv))
	return { "mu": Contact.clamp_js(float(r.muEff), FRICTION.min, FRICTION.max), "summary": summary }


## Coeficientes de un caso, ya multiplicados: at_speed() solo suma y multiplica. clsr: el CL·S con el aire por detrás
## (v_x < 0, unidad 4g); klr, ya multiplicado.
static func _case(
	m: float, cda: float, cls: float, mu: float, anchor_n: float, cp: float, slope_deg: float, rho: float, clsr: float
) -> Dictionary:
	var k := 0.5 * rho * maxf(1.0 - cp, 0.0)
	var b := slope_deg * PI / 180.0
	return {
		"m": m, "kd": k * cda, "kl": k * cls, "mu": mu, "A": anchor_n, "cb": V8.js_cos(b), "sb": V8.js_sin(b),
		"cda": cda, "cls": cls, "cp": cp, "klr": k * clsr, "clsr": clsr,
	}


## Juegos de coeficientes aerodinámicos { nom: {cda, cls, clsr}, lo: [...], hi: [...] }: lo, los más desfavorables para
## quedarse (más área y más sustentación); hi, los más favorables. Con las alas abiertas hay dos estados físicos
## desfavorables (sustenta o frena): se prueban los dos. clsr: el CL·S con el aire por detrás (BIRD_AERO, cl_rev): solo
## cambia el ala; el cuerpo y los mamíferos sustentan igual.
static func _aero_sets(claw: Dictionary, body: Dictionary, kind: String, posture: String) -> Dictionary:
	if kind == "mamifero":
		var fa: Dictionary = body.frontal_m2[posture]
		var cd: Dictionary = body.cd[posture]
		var cl: Dictionary = body.cls_m2[posture]
		return {
			"nom": { "cda": fa.value * cd.value, "cls": cl.value, "clsr": cl.value },
			"lo": [{ "cda": fa.max * cd.max, "cls": cl.max, "clsr": cl.max }],
			"hi": [{ "cda": fa.min * cd.min, "cls": cl.min, "clsr": cl.min }],
		}
	var sb := bird_frontal_m2(float(claw.mass))
	var cr: Dictionary = BIRD_AERO.crouch
	var cdb: Dictionary = BIRD_AERO.cd_body
	var clb: Dictionary = BIRD_AERO.cl_body
	var body_nom := { "cda": cdb.value * cr.value * sb, "cls": clb.value * sb, "clsr": clb.value * sb }
	var body_lo := { "cda": cdb.max * cr.max * sb, "cls": clb.max * sb, "clsr": clb.max * sb }
	var body_hi := { "cda": cdb.min * cr.min * sb, "cls": clb.min * sb, "clsr": clb.min * sb }
	if posture != "abiertas":
		return { "nom": body_nom, "lo": [body_lo], "hi": [body_hi] }
	var w: Dictionary = body.wing_m2
	var st: Dictionary = BIRD_AERO.wing
	var lo: Array = []
	for state: String in ["sustenta", "frena"]:
		lo.append(_with_wing(body_lo, st[state], w.max))
	return {
		"nom": _with_wing(body_nom, st.sustenta, w.value),
		"lo": lo,
		"hi": [_with_wing(body_hi, st.suave, w.min)],
	}


static func _with_wing(body: Dictionary, state: Dictionary, s_m2: float) -> Dictionary:
	return {
		"cda": body.cda + state.cd * s_m2, "cls": body.cls + state.cl * s_m2, "clsr": body.clsr + state.cl_rev * s_m2,
	}


## Capacidad del anclaje (N): { value, min, max }. friccion: 0. agarre (ave): 2 pies × agarre × k. gancho (mamífero):
## 2 patas × k × peso, limitado por el borde de chapa si la zona es un borde.
static func _anchor_capacity(
	anchor: String, kind: String, claw: Dictionary, body: Dictionary, m: float, target: Dictionary, zone: Dictionary,
	defense_n: Variant = null
) -> Dictionary:
	if anchor == "agarre" and (kind == "ave" or kind == "teropodo"):
		# el agarre ya es el máximo medido (Sustaita & Hertel 2010): asustada no aprieta más (los velocirraptores, el de su
		# ficha: grip_band)
		var g := grip_band(claw)
		return {
			"value": 2.0 * float(g.value) * GRASP_K.value, "min": 2.0 * float(g.min) * GRASP_K.min,
			"max": 2.0 * float(g.max) * GRASP_K.max,
		}
	if anchor == "agarre" or anchor == "gancho":
		var w := m * G
		var out := { "value": 2.0 * HOOK_K.value * w, "min": 2.0 * HOOK_K.min * w, "max": 2.0 * HOOK_K.max * w }
		if defense_n != null:
			# asustado, cada mano enganchada tira con la fuerza de sus flexores (defense_force), nunca menos que en reposo
			for key: String in ["value", "min", "max"]:
				out[key] = maxf(float(out[key]), 2.0 * float(defense_n[key]))
		if Js.truthy(zone.get("edge")) and kind == "mamifero":
			var e1 := edge_hold_n(target, float(body.paw_mm))
			var f: Dictionary = EDGE.factor
			out.value = minf(out.value, 2.0 * e1 * f.value)
			out.min = minf(out.min, 2.0 * e1 * f.min)
			out.max = minf(out.max, 2.0 * e1 * f.max)
		return out
	return { "value": 0.0, "min": 0.0, "max": 0.0 }


## Fuerza (N) con la que se dobla un borde de chapa sencillo bajo una pata enganchada: momento plástico σ0·t²/4 por
## unidad de longitud, sobre el ancho de la pata, con el brazo de la garra. σ0 y t de la carrocería del coche.
static func edge_hold_n(target: Dictionary, paw_mm: float) -> float:
	var body: Variant = target.get("body")
	if body == null:
		return INF
	var t: float = float(body.t) / 1000.0
	return float(body.sigma0) * t * t / 4.0 * paw_mm / EDGE.lever_mm


# ════════ En cada fotograma ════════

## Fuerzas con el coche a v_kmh (O(1), sin compute(): vale para cada fotograma). Devuelve el caso central y la banda:
## { vKmh, airKmh, localKmh, rho, qPa, dragN, liftN, weightN, inertiaN, lateralN, normalN, needN, availN, marginN, holds,
##   mode, loadRatio, powerW, carDragN, dragShare, needMaxN, availMinN, needMinN, availMaxN, holdsLo, holdsHi }.
## mode: "" si aguanta; «despega», «atras», «delante», «abajo» o «lado» si no (_mode_of).
static func at_speed(scen: Dictionary, v_kmh: float) -> Dictionary:
	var v := maxf(v_kmh, 0.0) / KMH
	var wh: float = scen.wh
	var wc: float = scen.wc
	var ax: float = scen.ax
	var ay: float = scen.ay
	var c: Dictionary = scen.cases.nom
	var f := _eval(c, v, wh, wc, ax, ay)
	# la banda de cada fuerza, con todos los casos de los dos lados (unidad 4o): con una frenada o un viento de cola, el
	# aire que más empuja hacia atrás (el lado desfavorable para el viento) es el que menos fuerza pide, y tomar solo un
	# lado dejaba la banda en un punto («de 2539 N a 2539 N» con 109 N de aire); si aguanta o no con todo en contra o a
	# favor sigue siendo el de cada lado
	var need_max: float = f.need
	var avail_min: float = f.avail
	var need_min: float = f.need
	var avail_max: float = f.avail
	var holds_lo := true
	for cl: Dictionary in scen.cases.lo:
		var fl := _eval(cl, v, wh, wc, ax, ay)
		need_max = maxf(need_max, fl.need)
		need_min = minf(need_min, fl.need)
		avail_min = minf(avail_min, fl.avail)
		avail_max = maxf(avail_max, fl.avail)
		holds_lo = holds_lo and fl.margin >= 0.0
	var holds_hi := false
	for ch: Dictionary in scen.cases.hi:
		var fh := _eval(ch, v, wh, wc, ax, ay)
		need_max = maxf(need_max, fh.need)
		need_min = minf(need_min, fh.need)
		avail_min = minf(avail_min, fh.avail)
		avail_max = maxf(avail_max, fh.avail)
		holds_hi = holds_hi or fh.margin >= 0.0
	var vx := v + wh
	var air := sqrt(vx * vx + wc * wc)
	var rho: float = scen.rho
	var car := 0.5 * rho * air * air * float(scen.get("carCdA", CAR_REF.cd * CAR_REF.area_m2))
	return {
		"vKmh": v * KMH, "airKmh": air * KMH, "localKmh": air * KMH * local_factor(c.cp), "rho": rho,
		"qPa": 0.5 * rho * air * air * maxf(1.0 - float(c.cp), 0.0),
		"dragN": f.drag, "liftN": f.lift, "weightN": float(c.m) * G, "inertiaN": float(c.m) * ax, "lateralN": float(c.m) * ay,
		"normalN": f.rn, "needN": f.need, "availN": f.avail, "marginN": f.margin, "holds": f.margin >= 0.0,
		"mode": "" if f.margin >= 0.0 else _mode_of(f, c, ax),
		"loadRatio": f.need / f.avail if f.avail > 0.0 else (INF if f.need > 0.0 else 0.0),
		"powerW": f.dx * v, "carDragN": car, "dragShare": f.drag / car if car > 0.0 else 0.0,
		"needMaxN": need_max, "availMinN": avail_min, "needMinN": need_min, "availMaxN": avail_max,
		"holdsLo": holds_lo, "holdsHi": holds_hi,
	}


## Fuerzas de un caso (el cálculo de at_speed; también lo usa la búsqueda).
static func _eval(c: Dictionary, v: float, wh: float, wc: float, ax: float, ay: float) -> Dictionary:
	var vx := v + wh
	var v2 := vx * vx + wc * wc
	var vm := sqrt(v2)
	var drag: float = float(c.kd) * v2
	# con el aire por detrás (v_x < 0) el ala abierta sustenta al revés (klr, unidad 4g); de cara o de lado, kl
	var lift: float = float(c.kl if vx >= 0.0 else c.klr) * v2
	var dx := drag * vx / vm if vm > 0.0 else 0.0
	var dy := drag * wc / vm if vm > 0.0 else 0.0
	var m: float = c.m
	var cb: float = c.cb
	var sb: float = c.sb
	# la resistencia es horizontal y la sustentación vertical: en un panel inclinado, cada una empuja en parte contra
	# el panel y en parte a lo largo de él
	var at := dx * cb + lift * sb
	var rn: float = m * (G * cb + ax * sb) + dx * sb - lift * cb
	var tt: float = at + m * (ax * cb - G * sb)
	var ty := dy + m * ay
	var t := sqrt(tt * tt + ty * ty)
	var need := t
	var avail: float = c.A
	if rn >= 0.0:
		avail = float(c.mu) * rn + float(c.A)
	else:
		need = sqrt(t * t + rn * rn)
	return {
		"drag": drag, "lift": lift, "dx": dx, "at": at, "rn": rn, "tt": tt, "ty": ty, "need": need, "avail": avail,
		"margin": avail - need,
	}


## Margen (N) sin crear diccionarios: el bucle de la búsqueda.
static func _margin(c: Dictionary, v: float, wh: float, wc: float, ax: float, ay: float) -> float:
	var vx := v + wh
	var v2 := vx * vx + wc * wc
	var vm := sqrt(v2)
	var drag: float = float(c.kd) * v2
	# con el aire por detrás (v_x < 0) el ala abierta sustenta al revés (klr, unidad 4g); de cara o de lado, kl
	var lift: float = float(c.kl if vx >= 0.0 else c.klr) * v2
	var dx: float = drag * vx / vm if vm > 0.0 else 0.0
	var m: float = c.m
	var cb: float = c.cb
	var sb: float = c.sb
	var rn: float = m * (G * cb + ax * sb) + dx * sb - lift * cb
	var tt: float = dx * cb + lift * sb + m * (ax * cb - G * sb)
	var ty: float = (drag * wc / vm if vm > 0.0 else 0.0) + m * ay
	var t2 := tt * tt + ty * ty
	if rn >= 0.0:
		return float(c.mu) * rn + float(c.A) - sqrt(t2)
	return float(c.A) - sqrt(t2 + rn * rn)


## Por dónde se va cuando no aguanta: «despega» (la sustentación le quita el apoyo o ya sostiene la mitad de su peso),
## «atras» (el viento de cara o la aceleración), «delante» (la frenada o el viento de cola), «abajo» (resbala cuesta
## abajo por el panel) o «lado» (curva o viento lateral).
static func _mode_of(f: Dictionary, c: Dictionary, ax: float) -> String:
	if f.rn < 0.0 or f.lift >= 0.5 * float(c.m) * G * float(c.cb):
		return "despega"
	var tt: float = f.tt
	if absf(f.ty) > absf(tt):
		return "lado"
	if tt >= 0.0:
		return "atras"
	# hacia delante: ¿lo empujan la frenada y el viento de cola, o sobre todo la cuesta del panel?
	var push := minf(float(c.m) * ax * float(c.cb), 0.0) + minf(float(f.at), 0.0)
	return "abajo" if -float(c.m) * G * float(c.sb) < push else "delante"


# ════════ Velocidad de despegue ════════

## Velocidad (km/h) del coche a la que el animal se suelta, con su banda:
## { kmh, minKmh, maxKmh, mode, atRest, beyond (no se suelta en el deslizador, 0-SLIDER_MAX_KMH), never (ni a 400),
##   holdFromKmh, holdToKmh, holdToMode }.
## kmh = 0 y atRest = false si no se sostiene ni con el coche parado (p. ej., con una frenada fuerte); mode dice entonces
## por qué. Aguantar no siempre es «de 0 a kmh»: con una frenada fuerte, parado sale despedido hacia delante y, más
## deprisa, el viento de cara compensa la inercia y lo sujeta. Entonces aguanta en una ventana: de holdFromKmh a holdToKmh
## (INF si no se suelta ni a 400), y holdToMode dice por qué se suelta arriba ("" si no se suelta). Sin ventana (aguanta
## parado, o a ninguna velocidad), holdFromKmh y holdToKmh son null. La banda (minKmh y maxKmh) es la de kmh.
static func detach(scen: Dictionary) -> Dictionary:
	var nom := _detach_case(scen.cases.nom, scen.wh, scen.wc, scen.ax, scen.ay)
	var lo := INF
	for c: Dictionary in scen.cases.lo:
		lo = minf(lo, float(_detach_case(c, scen.wh, scen.wc, scen.ax, scen.ay).kmh))
	var hi := 0.0
	for c: Dictionary in scen.cases.hi:
		hi = maxf(hi, float(_detach_case(c, scen.wh, scen.wc, scen.ax, scen.ay).kmh))
	var kmh: float = nom.kmh
	return {
		"kmh": kmh, "minKmh": minf(lo, kmh), "maxKmh": maxf(hi, kmh), "mode": nom.mode, "atRest": nom.atRest,
		"beyond": kmh > float(scen.get("vmaxKmh", SLIDER_MAX_KMH)), "never": is_inf(kmh),
		"holdFromKmh": nom.holdFromKmh, "holdToKmh": nom.holdToKmh, "holdToMode": nom.holdToMode,
	}


## El despegue de un caso: recorre las velocidades desde el coche parado en pasos de SCAN_STEP_KMH y afina cada cambio
## (de aguantar a soltarse, o al revés) por bisección. Los casos de la banda hacen la misma búsqueda (~80 µs más si no
## aguantan parados), así que su kmh se lee igual que el del caso central.
static func _detach_case(c: Dictionary, wh: float, wc: float, ax: float, ay: float) -> Dictionary:
	var step := SCAN_STEP_KMH / KMH
	var vmax := SCAN_MAX_KMH / KMH
	var rest_mode := ""
	var start := -1.0  # desde dónde aguanta (m/s); -1: aún no aguanta
	if _margin(c, 0.0, wh, wc, ax, ay) >= 0.0:
		start = 0.0
	else:
		rest_mode = _mode_of(_eval(c, 0.0, wh, wc, ax, ay), c, ax)
	var prev := 0.0
	var v := step
	while v <= vmax + 1e-9:
		var holds := _margin(c, v, wh, wc, ax, ay) >= 0.0
		if holds and start < 0.0:
			var e := _bisect(c, prev, v, wh, wc, ax, ay)
			start = 0.0 if e * KMH < REST_KMH else e
		elif not holds and start >= 0.0:
			var b := _bisect(c, prev, v, wh, wc, ax, ay)
			var mode := _mode_of(_eval(c, b, wh, wc, ax, ay), c, ax)
			if start > 0.0:
				return _window(rest_mode, start, b * KMH, mode)
			if b * KMH >= REST_KMH:
				return { "kmh": b * KMH, "atRest": true, "mode": mode, "holdFromKmh": null, "holdToKmh": null, "holdToMode": "" }
			# solo aguanta con el coche parado, justo en el límite: ni parado se sostiene
			rest_mode = mode
			start = -1.0
		prev = v
		v += step
	if start > 0.0:
		return _window(rest_mode, start, INF, "")
	if start == 0.0:
		return { "kmh": INF, "atRest": true, "mode": "", "holdFromKmh": null, "holdToKmh": null, "holdToMode": "" }
	return _no_window(rest_mode)


static func _no_window(rest_mode: String) -> Dictionary:
	return { "kmh": 0.0, "atRest": false, "mode": rest_mode, "holdFromKmh": null, "holdToKmh": null, "holdToMode": "" }


static func _window(rest_mode: String, from_ms: float, to_kmh: float, to_mode: String) -> Dictionary:
	return {
		"kmh": 0.0, "atRest": false, "mode": rest_mode, "holdFromKmh": from_ms * KMH, "holdToKmh": to_kmh, "holdToMode": to_mode,
	}


## Bisección entre a y b (m/s), que aguantan y no, o al revés: devuelve el borde del lado de b (el primer punto que
## está como b), en 40 pasos.
static func _bisect(c: Dictionary, a: float, b: float, wh: float, wc: float, ax: float, ay: float) -> float:
	var hb := _margin(c, b, wh, wc, ax, ay) >= 0.0
	for i in 40:
		var mid := 0.5 * (a + b)
		if (_margin(c, mid, wh, wc, ax, ay) >= 0.0) == hb:
			b = mid
		else:
			a = mid
	return b


## Frenada máxima (g) que aguanta con el coche a v_kmh sin salir despedido (caso central). 0 si ni sin frenar aguanta;
## BRAKING_TOP_G (2 g, más de lo que frena un coche) si aguanta cualquier frenada.
static func max_braking_g(scen: Dictionary, v_kmh: float) -> float:
	var c: Dictionary = scen.cases.nom
	var v := maxf(v_kmh, 0.0) / KMH
	if _margin(c, v, scen.wh, scen.wc, 0.0, scen.ay) < 0.0:
		return 0.0
	var lo := 0.0
	var hi := 0.0
	var ok := true
	while hi < BRAKING_TOP_G and ok:
		hi += 0.05
		ok = _margin(c, v, scen.wh, scen.wc, -hi * G, scen.ay) >= 0.0
		if ok:
			lo = hi
	if ok:
		return hi
	for i in 30:
		var mid := 0.5 * (lo + hi)
		if _margin(c, v, scen.wh, scen.wc, -mid * G, scen.ay) >= 0.0:
			lo = mid
		else:
			hi = mid
	return lo


## Gráfica en directo: fuerza necesaria frente a la disponible (N) de 0 a v_max km/h en n puntos, con las bandas.
## { vKmh, need, avail, needMax, availMin, needMin, availMax } (PackedFloat64Array) y la velocidad de despegue.
static func curve(scen: Dictionary, n: int = 61, v_max_kmh: float = -1.0) -> Dictionary:
	# sin tope: el del coche del escenario (vmaxKmh: el deportivo llega a su velocidad máxima)
	if v_max_kmh <= 0.0:
		v_max_kmh = float(scen.get("vmaxKmh", SLIDER_MAX_KMH))
	# los Packed*Array se copian por valor: se llenan aquí y se guardan al final
	var vs := PackedFloat64Array()
	var need := PackedFloat64Array()
	var avail := PackedFloat64Array()
	var need_max := PackedFloat64Array()
	var avail_min := PackedFloat64Array()
	var need_min := PackedFloat64Array()
	var avail_max := PackedFloat64Array()
	var count := maxi(n, 2)
	for i in count:
		var v := v_max_kmh * float(i) / float(count - 1)
		var s := at_speed(scen, v)
		vs.append(v)
		need.append(s.needN)
		avail.append(s.availN)
		need_max.append(s.needMaxN)
		avail_min.append(s.availMinN)
		need_min.append(s.needMinN)
		avail_max.append(s.availMaxN)
	return {
		"vKmh": vs, "need": need, "avail": avail, "needMax": need_max, "availMin": avail_min, "needMin": need_min,
		"availMax": avail_max, "detach": detach(scen),
	}


# ════════ Marcas, capas y textos ════════

## Capas del coche que ha cortado una marca de depth_um (nombres en minúscula, en orden).
static func layers_crossed(target: Dictionary, depth_um: float) -> Array:
	var out: Array = []
	var L: Variant = Data.car_layers(target)
	if L == null:
		return out
	for l: Dictionary in L:
		if depth_um > float(l.from) + 1e-6:
			var n: String = l.name
			out.append(n.substr(0, 1).to_lower() + n.substr(1))
	return out


## Espesor (µm) del panel de un coche: la pintura y la carrocería (target.thickness, en mm); 0 si el objetivo no es un
## coche (el vidrio del catálogo, por ejemplo).
static func panel_um(target: Dictionary) -> float:
	if target.get("body") == null or not Js.truthy(target.get("thickness")):
		return 0.0
	return float(target.thickness) * 1000.0


## Hasta dónde puede llegar, desde la cara de fuera, la punta de una garra que atraviesa el panel (µm): el panel y el hueco
## que hay detrás (clearance_mm, el mismo tope de la abolladura). INF si no hay dato del hueco (NAN o 0, como en el vidrio) o
## si el objetivo no es un coche: entonces solo la limita su largo (el alcance del motor).
static func room_um(target: Dictionary, clearance_mm: float) -> float:
	var t := panel_um(target)
	if t <= 0.0 or not (clearance_mm > 0.0):
		return INF
	return t + clearance_mm * 1000.0


## Unidad 4p: lo mismo con el panel abollado dent_mm donde están las garras (µm): el panel y el hueco que queda debajo de la
## chapa hundida, clearance_mm − dent_mm, nunca menos que nada. INF sin dato del hueco, como room_um.
static func shared_room_um(target: Dictionary, clearance_mm: float, dent_mm: float) -> float:
	var t := panel_um(target)
	if t <= 0.0 or not (clearance_mm > 0.0):
		return INF
	return t + maxf(clearance_mm - maxf(dent_mm, 0.0), 0.0) * 1000.0


## Unidad 4p: lo que se dice en el informe de una punción que topa en el hueco que le deja la abolladura (punct.bottoms con
## una abolladura de al menos 0,1 mm): «; donde se apoya, con la chapa hundida ~45.8 mm (4.6 cm), la punta entra ~34.2 mm
## (3.4 cm) por debajo» o, si la abolladura llena el hueco, «…, la punta no asoma por debajo». Las marcas resbalan fuera de la
## abolladura y conservan el hueco entero (su hondura dice hasta dónde llega allí la punta). "" si no hace falta.
static func shared_gap_txt(punct: Dictionary, dent: Variant, target: Dictionary) -> String:
	if not Js.truthy(punct.get("bottoms")) or dent == null or not Js.truthy(dent.get("applies")) or float(dent.depthMm) < 0.1:
		return ""
	var noun := String(target.body.noun) if target.get("body") != null else "el panel"
	var txt := "; donde se apoya, con %s %s ~%s, " % [noun, "hundida" if noun.begins_with("la") else "hundido",
		fmt_long(float(dent.depthMm) * 1000.0)]
	var below := float(punct.get("belowMm", 0.0))
	if below < 0.5:
		return txt + "la punta no asoma por debajo"
	return txt + "la punta entra ~%s por debajo" % fmt_long(below * 1000.0)


## Vueltas como mucho del hueco compartido (_share_gap) y lo que se da por igual (µm) al comparar la punta con su hueco.
const SHARED_GAP_STEPS := 60
const SHARED_GAP_TOL_UM := 1e-3


## Unidad 4p: la punción y la abolladura de un golpe comparten el hueco bajo el panel. Las garras están en el apoyo que lo
## abolla: con la chapa hundida δ, a su punta le quedan clearance − δ por debajo de la chapa hundida (shared_room_um), y no
## el hueco entero, como si la chapa no se hubiera movido. Si eso la para antes, el agujero y el trabajo son los de esa
## profundidad (_puncture_block) y, si las garras se quedan menos energía, la abolladura crece (dent_of con lo que no se
## quedan las garras): se repite hasta que la punta cabe en el hueco que le queda. La abolladura solo crece y el hueco solo
## encoge, así que la serie converge (en pocas vueltas: SHARED_GAP_STEPS como mucho). Solo con una chapa que se abolla
## (dent.applies, metal) y unas garras que la atraviesan. r: la punción del motor (Physics.compute) de la que salió punct;
## punct y dent: los de la primera pasada, con el hueco entero; through: el de dent_of. { punct, dent, workJ (el de todas las
## garras), steps (vueltas que han hecho falta) }.
static func _share_gap(
	r: Variant, claw: Dictionary, inlay: Dictionary, target: Dictionary, clearance_mm: float, e_n: float, n_claws: int,
	patches: int, f_cap: float, model: Variant, punct: Variant, dent: Variant, through: bool
) -> Dictionary:
	var work := float(punct.workJ) * n_claws if punct != null else 0.0
	var out := { "punct": punct, "dent": dent, "workJ": work, "steps": 0 }
	if r == null or punct == null or dent == null or not Js.truthy(dent.applies) or not Js.truthy(punct.through):
		return out
	for i in SHARED_GAP_STEPS:
		var room := shared_room_um(target, clearance_mm, float(dent.depthMm))
		if not (room < float(punct.depthUm) - SHARED_GAP_TOL_UM):
			break
		punct = _puncture_block(r, claw, inlay, target, room, model)
		work = float(punct.workJ) * n_claws
		dent = dent_of(target, e_n, work, patches, clearance_mm, through, f_cap)
		out.steps = i + 1
	out.punct = punct
	out.dent = dent
	out.workJ = work
	return out


## El hueco bajo el panel de una zona en la que se queda el animal (mm): el de la zona del golpe con el mismo panel
## (HOLD_PANEL); NAN si no hay dato (el limpiaparabrisas, el borde de la ventanilla, el maletero, el retrovisor y el vidrio).
static func hold_clearance_mm(zone_id: String) -> float:
	var iz: Variant = IMPACT_ZONES.get(String(HOLD_PANEL.get(zone_id, "")))
	return float(iz.clearance_mm) if iz != null and not iz.glass else NAN


## Resumen de un surco: profundidad bajo carga (la del motor) y la que queda al retirar la garra (Recovery, unidad 1f:
## el barniz recupera su parte elástica; lo cortado no vuelve), capas cortadas y μ.
## Unidad 4o: un surco que atraviesa el panel (r.through: la garra raja la chapa o el plástico de lado a lado) es tan hondo
## como el panel, la pintura y la carrocería (panel_um): lo que hay detrás es el hueco, aire hasta lo que haya debajo (la
## hondura que se enseña, como las ranuras del plástico de la 4g). La punta de la garra sí sigue: el motor la lleva hasta
## donde la chapa la frena o hasta su largo, y aquí no pasa del hueco (room, room_um). Campos de la 4o: through, tipUm (la
## punta desde la cara de fuera, que es lo que usan la carga de la garra y lo que entra clavada), belowMm (lo que asoma por
## detrás del panel) y bottoms (llega al fondo del hueco). Si el hueco la para antes que el motor, la raja es la de la garra
## a esa profundidad (Contact.hole_radius, como el motor, con m = phi: el tipo «arañazo» y una pasada de _lab_params);
## claw, inlay y model dan su punta (claw_tip), y solo se calcula entonces.
static func _scratch_summary(
	r: Dictionary, surface: Dictionary, room: float = INF, claw: Variant = null, inlay: Variant = null, model: Variant = "2.0"
) -> Dictionary:
	var depth: float = r.depthUm
	var through := Js.truthy(r.get("through"))
	var rec: Variant = Recovery.evaluate(surface, depth, float(r.grooveWidthUm) / 2.0, through)
	var out := {
		"depthUm": depth, "residualUm": rec.residualDepthUm if rec != null else depth, "verdict": r.verdict,
		"layer": r.get("layer"), "scratched": Js.truthy(r.get("scratched")), "muEff": r.muEff, "widthUm": r.grooveWidthUm,
		"layers": layers_crossed(surface, depth), "reachesBody": depth > Data.PAINT_LAYERS[-1].to - 1e-6,
		"through": false, "tipUm": depth, "belowMm": 0.0, "bottoms": false,
		# unidad 4s: la fracción del surco que el arado arranca (Hokkirigawa y Kato, abrasion_mode); el resto se aparta a los
		# lados (los labios del surco que dibuja la vista)
		"fab": float(r.get("fab", 1.0)),
	}
	var panel := panel_um(surface)
	if not through or panel <= 0.0:
		return out
	var tip_um := minf(depth, room)
	if tip_um < depth and claw is Dictionary:
		var tip := claw_tip(claw, inlay if inlay is Dictionary else Data.INLAYS[0], model)
		var h := tip_um / 1000.0 / maxf(float(r.get("phi", 1.0)), 1e-9)
		if h < Contact.depth_for_radius(tip, float(tip.amax)):  # si no, la raja ya era del ancho de la garra
			out.widthUm = 2.0 * Contact.hole_radius(tip, h) * 1000.0
	out.depthUm = panel
	out.residualUm = panel
	out.layers = layers_crossed(surface, panel)
	out.reachesBody = true
	out.through = true
	out.tipUm = tip_um
	out.belowMm = maxf(tip_um - panel, 0.0) / 1000.0
	out.bottoms = is_finite(room) and tip_um >= room - 1e-6
	return out


## La hondura de unas marcas en palabras (unidad 4o): la del surco («110 µm», con lo que queda al soltar) o, si atraviesan
## el panel, through_txt. zone_id: la zona del golpe o en la que se queda; plural: varias marcas (el verbo); tip: decir
## también dónde queda la punta de la garra.
static func marks_depth_txt(marks: Dictionary, target: Dictionary, zone_id: String = "", plural := true, tip := true) -> String:
	if not Js.truthy(marks.get("through")):
		var txt := Format.fmt_len(float(marks.depthUm))
		if float(marks.residualUm) < float(marks.depthUm) - 0.5:
			txt += " (quedan %s al soltar)" % Format.fmt_len(float(marks.residualUm))
		return txt
	return through_txt(marks, target, zone_id, plural, tip)


## Unas marcas que atraviesan el panel (unidad 4o): «atraviesan la chapa (0.81 mm con la pintura)» y, con tip, dónde queda la
## punta de la garra: «; la punta asoma ~39 mm por detrás» o, si llega al fondo del hueco bajo el panel (bottoms), «; la punta
## entra ~80 mm (8.0 cm) por detrás, hasta el fondo del hueco bajo el capó». Lo que asoma menos de medio milímetro no se dice.
static func through_txt(marks: Dictionary, target: Dictionary, zone_id: String = "", plural := true, tip := true) -> String:
	var noun := String(target.body.noun) if target.get("body") != null else "el panel"
	var txt := "%s %s (%s con la pintura)" % ["atraviesan" if plural else "atraviesa", noun, CarFormat.fmt_panel(float(marks.depthUm))]
	if not tip:
		return txt
	var below := float(marks.get("belowMm", 0.0))
	var gap := String(PANEL_GAP_TXT.get(String(HOLD_PANEL.get(zone_id, zone_id)), ""))
	if Js.truthy(marks.get("bottoms")) and gap != "":
		txt += "; la punta entra ~%s por detrás, hasta el fondo del hueco %s" % [fmt_long(below * 1000.0), gap]
	elif below >= 0.5:
		txt += "; la punta asoma ~%s por detrás" % fmt_long(below * 1000.0)
	return txt


## Veredicto sugerido de la velocidad de despegue: { verdict, vsub } (la integración puede adaptarlo).
static func detach_verdict(scen: Dictionary, det: Dictionary) -> Dictionary:
	# unidad 4v: la luneta templada que estalla bajo el animal: pierde el apoyo (CarGlass.rear_verdict)
	var rear: Variant = scen.get("rearWindow")
	if rear != null and bool(rear.shattered):
		return CarGlass.rear_verdict(rear, String(scen.inlay), _ending(scen))
	var v := _detach_verdict(scen, det)
	var shield: Variant = scen.get("windshield")
	if shield != null and shield.cracked:
		if Js.truthy(shield.get("contactCracks")):
			v.vsub += "; y sus garras agrietan el parabrisas al apoyarse (el laminado no cae)"
		else:
			v.vsub += "; y el parabrisas se agrieta bajo su peso (el laminado no cae)"
	return v


static func _detach_verdict(scen: Dictionary, det: Dictionary) -> Dictionary:
	var kmh: float = det.kmh
	var band := _band_txt(det)
	var braking: bool = float(scen.ax) < 0.0
	var o := _ending(scen)
	var pro := "la" if o == "a" else "lo"
	var vmax := float(scen.get("vmaxKmh", SLIDER_MAX_KMH))
	if not det.atRest:
		var from: Variant = det.get("holdFromKmh")
		if from != null and float(from) <= vmax:
			return _window_verdict(scen, det, band)
		var rv := _rest_verdict(scen, det)
		if from != null:
			# la ventana empieza fuera del deslizador: en todo él no aguanta, y se dice desde dónde aguantaría
			var to: float = det.holdToKmh
			rv.vsub += "; solo por encima de ~%s km/h aguantaría%s: %s" % [_kmh_txt(float(from)),
				"" if is_inf(to) else " (hasta ~%s km/h)" % _kmh_txt(to), window_saver(scen, det)]
		rv.vsub += band
		return rv
	if det.never:
		var why := "bien agarrad%s, el viento no puede con %s" % [o, "ella" if o == "a" else "él"]
		if scen.anchor == "friccion":
			var raking: bool = float(scen.get("anchorN", {}).get("value", 0.0)) > 0.0
			why = "su peso, el roce y sus garras arando la pintura pueden con el viento" if raking else "su peso y el roce pueden con el viento"
		return { "verdict": "NI A 400 km/h SE SUELTA", "vsub": why + band }
	if det.beyond:
		return { "verdict": "AGUANTA A %s km/h" % _kmh_txt(vmax), "vsub": "se soltaría hacia ~%s km/h%s" % [_kmh_txt(kmh), band] }
	match String(det.mode):
		"despega":
			if scen.kind == "ave":
				return {
					"verdict": "DESPEGA A ~%s km/h" % _kmh_txt(kmh),
					"vsub": "con las alas abiertas el viento relativo %s sostiene: no se suelta, vuela%s" % [pro, band],
				}
			return { "verdict": "LO LEVANTA EL AIRE A ~%s km/h" % _kmh_txt(kmh), "vsub": "la sustentación le quita el apoyo%s" % band }
		"delante":
			return {
				"verdict": "SALE DESPEDID%s HACIA DELANTE A ~%s km/h" % [o.to_upper(), _kmh_txt(kmh)],
				"vsub": "%s %s empuja más de lo que aguanta%s" % ["la frenada" if braking else "el viento de cola", pro, band],
			}
		"abajo":
			return {
				"verdict": "RESBALA CUESTA ABAJO A ~%s km/h" % _kmh_txt(kmh),
				"vsub": "el aire le quita apoyo y el panel inclinado hace el resto%s" % band,
			}
		"lado":
			return { "verdict": "RESBALA DE LADO A ~%s km/h" % _kmh_txt(kmh), "vsub": "la curva o el viento lateral pueden con su agarre%s" % band }
	return {
		"verdict": "SE SUELTA A ~%s km/h" % _kmh_txt(kmh),
		"vsub": "el viento puede más que su agarre y sale despedid%s hacia atrás%s" % [o, band],
	}


## Veredicto sin ventana cuando ni parado se sostiene (sin la banda): qué lo tira con el coche quieto.
static func _rest_verdict(scen: Dictionary, det: Dictionary) -> Dictionary:
	var o := _ending(scen)
	var pro := "la" if o == "a" else "lo"
	match String(det.mode):
		"delante":
			return {
				"verdict": "SALE DESPEDID%s HACIA DELANTE" % o.to_upper(),
				"vsub": "%s, ni a paso de hombre aguanta encima" % ("con esa frenada" if float(scen.ax) < 0.0 else "con ese viento de cola"),
			}
		"despega":
			var lifted := ("las alas abiertas ya %s sostienen: vuela" % pro) if scen.kind == "ave" else "el aire ya le quita el apoyo"
			var wind := "de cara"
			if float(scen.wh) < 0.0:
				# el aire le llega por detrás: el ala sustenta al revés, menos que de cara (unidad 4g), pero puede levantarla
				wind = "de cola"
				if scen.kind == "ave":
					lifted = "aunque le llega por detrás, el aire ya %s levanta con las alas abiertas" % pro
			elif float(scen.wh) == 0.0:
				wind = "lateral"
			return { "verdict": "DESPEGA CON EL COCHE PARADO", "vsub": "con ese viento %s, %s" % [wind, lifted] }
		"lado":
			return { "verdict": "RESBALA DE LADO", "vsub": "con esa curva o ese viento lateral, ni a paso de hombre aguanta encima" }
		"atras":
			var pushed := "al arrancar, la aceleración" if float(scen.ax) > 0.0 else "el viento de cara"
			return { "verdict": "NI PARADO SE SOSTIENE", "vsub": "%s %s echa hacia atrás con el coche casi quieto" % [pushed, pro] }
	return { "verdict": "NI PARADO SE SOSTIENE", "vsub": "sin nada que agarrar, resbala del panel con el coche quieto" }


## Veredicto de una ventana (detach: holdFromKmh no es null): parado no aguanta, pero sí de holdFromKmh a holdToKmh. El
## titular dice qué le pasa despacio y hasta dónde; el subtítulo, qué lo sujeta más deprisa y, si se suelta arriba, dónde y
## por qué. Con una frenada es lo que pasa al frenar hasta parar: aguanta mientras el coche va deprisa y sale despedido al
## bajar de holdFromKmh.
static func _window_verdict(scen: Dictionary, det: Dictionary, band: String) -> Dictionary:
	var from := _kmh_txt(float(det.holdFromKmh))
	var to: float = det.holdToKmh
	var o := _ending(scen)
	var verdict := "SOLO AGUANTA POR ENCIMA DE ~%s km/h" % from
	match String(det.mode):
		"delante":
			var when := "AL BAJAR DE" if float(scen.ax) < 0.0 else "POR DEBAJO DE"
			verdict = "SALE DESPEDID%s HACIA DELANTE %s ~%s km/h" % [o.to_upper(), when, from]
		"abajo":
			verdict = "RESBALA CUESTA ABAJO POR DEBAJO DE ~%s km/h" % from
		"lado":
			verdict = "RESBALA DE LADO POR DEBAJO DE ~%s km/h" % from
		"despega":
			verdict = "EL VIENTO %s LEVANTA POR DEBAJO DE ~%s km/h" % [("la" if o == "a" else "lo").to_upper(), from]
	var why := "más deprisa, " + window_saver(scen, det)
	if det.mode == "delante" and float(scen.ax) < 0.0:
		# unidad 4o: la frase entera («con esa frenada;» se quedaba cortada): despacio, qué lo suelta; más deprisa, qué lo sujeta
		why = "despacio, la frenada %s empuja más de lo que aguanta; %s" % ["la" if o == "a" else "lo", why]
	if is_finite(to):
		why += ", hasta ~%s km/h, donde %s" % [_kmh_txt(to), window_end(scen, String(det.holdToMode))]
	return { "verdict": verdict, "vsub": why + band }


## Qué lo sujeta más deprisa cuando solo aguanta en una ventana (detach: holdFromKmh), en palabras: el coche le quita el
## viento de cola (la ventana empieza antes de igualarlo), el viento de cara compensa la frenada, lo empuja panel arriba o
## lo aprieta contra un panel inclinado.
static func window_saver(scen: Dictionary, det: Dictionary) -> String:
	var pro := "la" if _ending(scen) == "a" else "lo"
	if float(scen.wh) < 0.0 and float(det.holdFromKmh) <= -float(scen.wh) * KMH:
		return "el coche le quita el viento de cola y aguanta"
	match String(det.mode):
		"delante":
			if float(scen.ax) < 0.0:
				return "el viento de cara compensa la inercia y %s sujeta" % pro
		"abajo":
			return "el viento %s empuja panel arriba y aguanta" % pro
	if float(scen.slopeDeg) > 0.0:
		return "el viento de cara %s aprieta contra el panel inclinado y aguanta" % pro
	return "el aire %s sujeta" % pro


## Por qué se suelta al final de una ventana (holdToMode), en palabras: «ya vuela», «sale despedida hacia atrás»…
static func window_end(scen: Dictionary, mode: String) -> String:
	var o := _ending(scen)
	match mode:
		"despega":
			return "ya vuela" if scen.kind == "ave" else "el aire %s levanta" % ("la" if o == "a" else "lo")
		"delante":
			return "sale despedid%s hacia delante" % o
		"abajo":
			return "resbala cuesta abajo"
		"lado":
			return "resbala de lado"
	return "sale despedid%s hacia atrás" % o


## Terminación de los adjetivos del animal del escenario («agarrada» o «agarrado»).
static func _ending(scen: Dictionary) -> String:
	return String(GRAMMAR.get(String(scen.get("claw", "")), ["el", "o"])[1])


## Velocidad en km/h sin decimales y sin la unidad; «∞» si no es finita (CarFormat.kmh_txt).
static func _kmh_txt(kmh: float) -> String:
	return CarFormat.kmh_txt(kmh)


## La banda de la velocidad de despegue en palabras: « (entre 79 y 296 km/h según los datos)», sin ceros ni infinitos.
static func _band_txt(det: Dictionary) -> String:
	var lo: float = det.minKmh
	var hi: float = det.maxKmh
	if hi <= 0.0:
		return ""
	if lo <= 0.0 and is_inf(hi):
		return " (con los datos más desfavorables ni parado se sostiene; con los más favorables no se suelta)"
	if lo <= 0.0:
		return " (según los datos, de ni parado a ~%s km/h)" % _kmh_txt(hi)
	if is_inf(lo):
		return " (ni con los datos más desfavorables)"
	if is_inf(hi):
		return " (desde ~%s km/h según los datos; con los más favorables no se suelta)" % _kmh_txt(lo)
	return " (entre %s y %s km/h según los datos)" % [_kmh_txt(lo), _kmh_txt(hi)]


## Informe completo de un animal quieto sobre el coche (la referencia de los casos de coche-en-marcha.json):
## { ok, setup (resumen), detach, detachRef (con el aire de referencia: 20 °C al nivel del mar), verdict, at (a p.v_kmh),
##   brakingG, marks, air, airTxt, safety, defense }. Con p.defense, marks son los desgarros del animal asustado
## (defense.tear) y defense, lo que hace (defense_block).
static func hold_report(p: Dictionary) -> Dictionary:
	var scen := setup(p)
	if not scen.ok:
		return scen
	var det := detach(scen)
	var v := float(p.get("v_kmh", PARAMS.v_kmh.default))
	var summary := scen.duplicate()
	summary.erase("cases")
	summary.erase("holdCtx")
	var ref := with_air(scen, PARAMS.temp_c.default, PARAMS.altitude_m.default)
	var dfn: Variant = scen.get("defense")
	return {
		"ok": true, "setup": summary, "detach": det, "detachRef": detach(ref), "verdict": detach_verdict(scen, det),
		"at": at_speed(scen, v), "brakingG": max_braking_g(scen, v), "marks": dfn.tear if dfn != null else scen.scratch,
		"air": scen.air, "airTxt": air_txt(scen.air), "safety": SAFETY_NOTE, "defense": dfn,
	}


# ════════ El golpe: un animal que se abalanza sobre el coche en marcha ════════

## El golpe. p: { claw, target, zone (IMPACT_ZONES), v_kmh (coche), animal_kmh, angle_deg (0 mismo sentido, 90 cruza,
## 180 de frente), drop_m (caída sobre un panel de arriba), car_mass_kg, inlay (id de Data.INLAYS, «none» por defecto),
## sex (el casuario), defense (asustado, aprieta con toda su fuerza), model }. Dos llamadas a Physics.compute() (marcas
## y punción; tres en la patada o en defensa) y, si se queda encima, un setup() más. Devuelve velocidades relativas,
## energías, marcas (en defensa, los desgarros), punción, abolladura y parabrisas (unidad 1f), si se queda encima o
## resbala y a qué velocidad cae, la rotura de unas garras reforjadas (claw_fracture.gd), la defensa, el veredicto y el
## informe de daños. El casuario (is_kicker) patea: KICK. En un costado de plástico, unas garras que lo atraviesan quedan
## trabadas y lo rajan mientras el animal sigue a lo largo del panel (tear, unidad 4g: tear_run).
static func impact(p: Dictionary) -> Dictionary:
	var claw: Dictionary = ClawsV2.apply(p.claw)
	var body: Variant = body_of(claw)
	if body == null:
		return { "ok": false, "reason": "sin datos de %s" % Data.claw_title(claw).to_lower() }
	var zone_id := String(p.get("zone", "techo"))
	var iz: Variant = IMPACT_ZONES.get(zone_id)
	if iz == null:
		return { "ok": false, "reason": "zona de golpe «%s» desconocida" % zone_id }
	# unidad 4m: a la ventanilla solo llega quien la alcanza (window_reach), y si no, dice por qué
	var tempered: bool = Js.truthy(iz.get("tempered"))
	if tempered:
		var wr := window_reach(claw, body)
		if not wr.reaches:
			return { "ok": false, "reason": wr.reason }
	var kick := is_kicker(body)
	if kick and not KICK_ZONES.has(zone_id):
		return { "ok": false, "reason": KICK_ZONE_REASON }
	var inlay: Variant = inlay_of(p)
	if inlay == null:
		return { "ok": false, "reason": "material de garra «%s» desconocido" % _inlay_id(p) }
	# unidad 4i-B2: la garra afilada, el salto de los velocirraptores y la masa de más de unas garras reforjadas (la velocidad
	# la impone el coche: todo el golpe se hace con la masa del animal y sus garras, y la de más suma ½·Δm·v²)
	var sharp := _sharpen(claw, inlay, p)
	claw = sharp.claw
	var leaper := is_leaper(body)
	var film := is_film(claw)
	var target: Dictionary = p.target
	var sex: Variant = sex_of(body, p)
	var m: float = mass_of(claw, sex)
	var m_body := m
	var n_claws: int = strike_claws_of(body)
	var cm: Variant = claw_mass_block(claw, inlay, n_claws, m_body)
	if cm != null:
		m += float(cm.addedKg)
	var car_m := float(p.get("car_mass_kg", PARAMS.car_mass_kg.default))
	var mu_red := m * car_m / (m + car_m)  # masa reducida: la energía que se disipa si acaban juntos
	var vc := maxf(float(p.get("v_kmh", PARAMS.v_kmh.default)), 0.0) / KMH
	var va := maxf(float(p.get("animal_kmh", PARAMS.animal_kmh.default)), 0.0) / KMH
	var th := float(p.get("angle_deg", PARAMS.angle_deg.default)) * PI / 180.0
	var side: bool = iz.normal == "lado"
	# la patada no cae sobre el panel: el pie llega con la velocidad del salto (abajo)
	var vz := 0.0 if side or kick else sqrt(2.0 * G * maxf(float(p.get("drop_m", PARAMS.drop_m.default)), 0.0))
	# velocidad del animal respecto al coche (x hacia delante, y hacia el costado, z arriba)
	var rx := va * V8.js_cos(th) - vc
	var ry := va * V8.js_sin(th)
	var rz := -vz
	# el salto de un velocirraptor (leap_block): a un panel de arriba llega de bajada desde la carretera, con la carrera y el
	# salto frenados por el aire en el vuelo (si llega); contra un costado golpea con la carrera, como el tigre
	var leap: Variant = null
	if leaper:
		var rho_air := air_density(float(p.get("temp_c", PARAMS.temp_c.default)), float(p.get("altitude_m", PARAMS.altitude_m.default)))
		leap = leap_block(claw, body, zone_id, va, th, rho_air, m)
		if not leap.reaches:
			return { "ok": false, "reason": leap.reason }
		if tempered:
			leap.merge(window_leap_fields(), true)  # unidad 4m: salta para llegar a la ventanilla
		rx = float(leap.ux) - vc
		ry = float(leap.uy)
		rz = float(leap.uz)
		vz = -rz
	var vn := 0.0
	var ux := 0.0
	var uy := 0.0
	var vt := 0.0
	var away := 0.0  # componente normal con la que se aleja del panel (no choca)
	if side:
		vn = absf(ry)
		vt = sqrt(rx * rx + rz * rz)
		ux = rx / vt if vt > 0.0 else 0.0
	else:
		var b: float = float(iz.slope_deg) * PI / 180.0
		var nx := V8.js_sin(b)
		var nz := V8.js_cos(b)
		var dot := rx * nx + rz * nz
		vn = maxf(0.0, -dot)
		away = maxf(0.0, dot)
		var tx := rx - dot * nx
		var tz := rz - dot * nz
		vt = sqrt(tx * tx + ry * ry + tz * tz)
		ux = tx / vt if vt > 0.0 else 0.0
		uy = ry / vt if vt > 0.0 else 0.0
	# la patada: en la normal, la velocidad del salto (KICK); la carrera solo cuenta a lo largo del panel
	if kick:
		vn = kick_leap_ms()
		away = 0.0
	var vrel := sqrt(vn * vn + vt * vt) if kick else sqrt(rx * rx + ry * ry + rz * rz)
	var kind: String = body.kind
	# apoyos que reciben el golpe: patas o pies en un panel de arriba; hombro y cadera en un costado; el pie que patea
	var patches := 1 if kick else (2 if side else _patches(kind))
	var per_claw := m * G / n_claws
	var glass: bool = iz.glass
	var metal := is_metal(target)
	var model: Variant = p.get("model", "2.0")
	var reforged: bool = inlay.id != "none"
	var slide_mm: float = float(iz.slide_m) * 1000.0
	# la pata que patea no pasa de KICK.force_bw pesos corporales (INF en el resto: el golpe lo reparte Dent)
	var f_cap := kick_force_n(m_body) if kick else INF
	var e_n := 0.5 * mu_red * vn * vn
	# unidad 4o: lo que puede entrar la punta de una garra que atraviesa el panel, el panel y el hueco de detrás
	var tip_room := INF if glass else room_um(target, float(iz.clearance_mm))
	var mk: Dictionary = {} if kick else _marks(claw, target, glass, per_claw, slide_mm, model, inlay, false, tip_room)
	# defensa (p.defense): asustado aprieta con toda su fuerza; sus garras desgarran al resbalar (las marcas), pero la
	# fricción que lo frena sigue siendo la de su peso (mk), como con las garras clavadas: el anclaje (clavado o arando la
	# pintura, rake_n) cuenta después, en lo que aguanta encima (hold). El casuario ya patea con toda su fuerza.
	var df: Variant = defense_force(claw, sex) if Js.truthy(p.get("defense")) else null
	var def_claw_n := maxf(float(df.perClaw.value), per_claw) if df != null else per_claw
	var mk_show: Dictionary = mk
	if df != null and not kick:
		mk_show = _marks(claw, target, glass, def_claw_n, slide_mm, model, inlay, true, tip_room)
	# punción del golpe: cada garra con su parte de la masa reducida y la velocidad normal (el motor de siempre); en la
	# patada, además, la daga no entra más de lo que la empuja la pata (la punción estática con su fuerza máxima)
	var punct: Variant = null
	var punct_raw: Variant = null  # la punción del motor, para el hueco compartido con la abolladura (unidad 4p)
	var claws_work_j := 0.0
	if not glass and vn > 0.0:
		var sc := claw.duplicate(true)
		sc.strike = { "v": vn, "m": mu_red / n_claws }
		var over := { "method": "puncion", "strike": true, "force": 0.0 if kick else per_claw, "model": model }
		if reforged:
			over["inlay"] = inlay
		var r := Physics.compute(_lab_params(sc, target, over))
		if kick:
			var over_st := { "method": "puncion", "strike": false, "force": f_cap, "model": model, "inlay": inlay }
			var r_st := Physics.compute(_lab_params(claw, target, over_st))
			if float(r_st.depthUm) < float(r.depthUm):
				r = r_st
		punct_raw = r
		punct = _puncture_block(r, claw, inlay, target, tip_room, model)
		claws_work_j = float(punct.workJ) * n_claws
	var dent: Variant = null
	var shield: Variant = null
	var crush_m := 0.0
	# unidad 4m: la ventanilla templada aguanta entera o estalla (side_window_impact), con la punta de las garras que golpean
	var side_window: Variant = null
	if tempered:
		side_window = side_window_block(side_window_impact(vn, mu_red, float(body.contact_mm), patches, n_claws,
			claw_tip(claw, inlay, model), f_cap))
	elif glass:
		shield = windshield_impact(vn, mu_red, float(body.contact_mm), patches)
		# unas garras reforjadas al menos tan duras como el vidrio lo agrietan también por contacto, con la fuerza de pico
		# de cada garra (Fracture.evaluate); la queratina, nunca
		if reforged and not shield.cracked:
			var f_claw := float(shield.peakN) * float(patches) / float(n_claws)
			if _glass_contact_cracks(claw, inlay, f_claw, vt > 1e-9, mk_show.summary, model):
				shield = windshield_impact(vn, mu_red, float(body.contact_mm), patches, true)
	else:
		# unas garras que perforan la chapa no evitan que el cuerpo (o el pie) la abolle detrás de ellas; en el plástico,
		# lo perforado no se abolla (recupera)
		var through: bool = punct != null and punct.through and not metal
		dent = dent_of(target, e_n, claws_work_j, patches, float(iz.clearance_mm), through, f_cap)
		# unidad 4p: la punta de las garras que la atraviesan y la abolladura comparten el hueco bajo el panel
		var sg := _share_gap(punct_raw, claw, inlay, target, float(iz.clearance_mm), e_n, n_claws, patches, f_cap, model, punct,
			dent, through)
		punct = sg.punct
		dent = sg.dent
		claws_work_j = sg.workJ
		crush_m = float(dent.depthMm) / 1000.0
	# fuerza de pico del golpe en el apoyo: la de la abolladura; en la patada sobre el plástico, la de la pata
	var f_patch := 0.0
	if dent != null and dent.applies:
		f_patch = float(dent.peakN)
	if kick and f_patch <= 0.0:
		f_patch = f_cap
	if kick:
		# la daga raya con la fuerza de la patada (no con el peso: el casuario no está encima)
		mk = _marks(claw, target, glass, f_patch / n_claws, slide_mm, model, inlay, false, tip_room)
		mk_show = mk
	var mu: float = mk.mu
	var sm: Dictionary = mk_show.summary
	# deslizamiento: el impulso de fricción del choque (μ·J_n, con J_n = masa reducida × v_n) frena la velocidad
	# tangencial; en un panel de arriba sigue la fricción del peso. En un costado no hay peso que apriete: se cae.
	var vt1 := maxf(vt - mu * (mu_red / m) * vn, 0.0)
	var t_crush := 2.0 * crush_m / vn if vn > 0.0 and crush_m > 0.0 else 0.0
	if kick:
		# la patada dura lo que tarda la fuerza de la pata en frenar la normal de todo el cuerpo: t = μ_red·v/F
		t_crush = mu_red * vn / f_patch if f_patch > 0.0 else 0.0
	var mark_imp := 0.5 * (vt + vt1) * t_crush
	var slide_m: float = iz.slide_m
	var a_fr := mu * G
	var stays := false
	var mark_m := minf(mark_imp, slide_m)
	var v_exit := vt1
	var t_slide := 0.0
	if not side and not kick:
		var room := maxf(slide_m - mark_imp, 0.0)
		var d := vt1 * vt1 / (2.0 * a_fr)
		stays = d <= room
		mark_m = minf(mark_imp + d, slide_m)
		v_exit = 0.0 if stays else sqrt(maxf(vt1 * vt1 - 2.0 * a_fr * room, 0.0))
		t_slide = (vt1 - v_exit) / a_fr
	# garras clavadas: en el plástico, si lo atraviesan o llegan a él; en la chapa, si la perforan; y, asustado, si su
	# desgarro entra en el plástico o raja la chapa
	var embedded: bool = punct != null and (punct.through if metal else (punct.through or punct.reachesBody))
	var stuck_in: Variant = null
	if df != null and not kick and not glass:
		stuck_in = _stuck_in(sm, target)
	embedded = embedded or stuck_in != null
	# garras trabadas en el plástico (unidad 4g): en un costado no hay peso que las apriete contra el panel, pero si lo han
	# atravesado quedan trabadas y, si el animal sigue a lo largo del panel, lo rajan de lado a lado hasta que se para
	# respecto al coche o llega al final del panel (si aguanta lo que pide rajarlo; si no, se le sueltan). En un panel de
	# arriba ya lo hace el motor: la fricción de su peso con las garras cortando el plástico (μ·N, hasta μ = 1)
	var tear: Variant = null
	var tear_j := 0.0
	if side and not kick and not glass and not metal and punct != null and punct.through:
		var tp: Variant = _tear_params(target, kind, claw, body, m, iz, df)
		if tp != null:
			var room := maxf(slide_m - mark_imp, 0.0)
			var run := tear_run(m, vt1, room, n_claws, float(tp.tMm), float(tp.r.value), float(tp.cap.value))
			tear = _tear_block(run, tp, m, vt1, room, n_claws)
			if float(run.lengthM) > 0.0:
				mark_m = minf(mark_imp + float(run.lengthM), slide_m)
				v_exit = run.vExitMs
				t_slide = run.timeS
				tear_j = run.energyJ
				sm = _tear_marks(sm, target, punct)
	# si se queda encima, ¿aguanta a esa velocidad? (la misma física del coche en marcha)
	var hold: Variant = null
	if stays and iz.hold != null:
		var hp := {
			"claw": p.claw, "target": target, "zone": iz.hold, "posture": POSTURES[kind][0], "embedded": embedded,
			"model": model, "temp_c": p.get("temp_c", PARAMS.temp_c.default),
			"altitude_m": p.get("altitude_m", PARAMS.altitude_m.default), "inlay": inlay.id,
			"embed_mm": float(punct.depthUm) / 1000.0 if punct != null else INF, "defense": df != null,
			"sharpness": p.get("sharpness", PARAMS.sharpness.default),
		}
		var scen := setup(hp)
		if scen.ok:
			var s := at_speed(scen, vc * KMH)
			var det := detach(scen)
			hold = { "holds": s.holds, "detachKmh": det.kmh, "mode": s.mode, "brakingG": max_braking_g(scen, vc * KMH) }
	# rotura de unas garras reforjadas que cortan el metal (claw_fracture.gd), con la carga del instante que más las flexa
	# (claw_load: al clavarse o al resbalar); la carga lateral es la fricción mientras resbala (μ·F): en un golpe de
	# frente, sin nada que resbalar, no hay flexión. Unas garras más blandas que la chapa no la cortan: ceden por la punta,
	# como la queratina, y no se evalúan.
	var frac: Variant = null
	if reforged and metal and not glass and can_cut_body(inlay, target):
		var slide_n := 0.0
		if mark_m > 0.0:
			slide_n = f_patch / float(n_claws) if kick else def_claw_n
		# el surco con la punta donde está (unidad 4o: si atraviesa la chapa, su hondura es la del panel; la punta, más abajo)
		var ld: Variant = claw_load(claw, inlay, target, punct, slide_n, float(sm.tipUm), model)
		if ld != null and float(ld.n) > 0.0:
			frac = claw_fracture(claw, inlay, ld.n, mu if vt > 1e-9 else 0.0, model, ld.xLoadMm)
			frac["forceBasis"] = ld.basis
			frac["depthMm"] = ld.depthMm
	var kick_info: Variant = null
	if kick:
		kick_info = {
			"massKg": m_body, "sex": sex, "leapMs": vn, "leapKmh": vn * KMH, "leapMaxMs": kick_leap_ms(true),
			"leapJ": 0.5 * m * vn * vn, "forceBw": KICK.force_bw.value, "forceCapN": f_cap,
			"forceCapMinN": kick_force_n(m_body, "min"), "forceCapMaxN": kick_force_n(m_body, "max"), "peakN": f_patch,
			"capped": f_patch >= f_cap - 1e-6, "contactS": t_crush, "quality": "estimate",
			"source": "salto: " + String(KICK.work_j_per_kg.source) + "; " + String(KICK.muscle_fraction.source) + " · fuerza: " + String(KICK.force_bw.source),
		}
	var def_info: Variant = null
	if df != null:
		var area := float(claw.area)
		var tipd := claw_tip(claw, inlay, model)
		var h_claw: float = float(tipd.hv) * Contact.HV_MPA
		var p_tip := def_claw_n / area if area > 0.0 else INF
		def_info = {
			"forceN": { "value": df.value, "min": df.min, "max": df.max }, "per": df.per, "kind": df.kind,
			"perClawN": def_claw_n, "perClawBand": df.perClaw, "tipAreaMm2": area, "tipPressureMPa": p_tip,
			"clawHardnessMPa": h_claw, "tipYields": p_tip > h_claw, "stuck": stuck_in != null, "stuckIn": stuck_in,
			"quality": df.quality, "source": df.source,
		}
	# unidad 4v: lo que tapa al conductor la grieta del parabrisas (CarGlass.view_loss, estimación): una estrella por apoyo si
	# lo parte la flexión, o una franja a lo largo de cada surco si lo agrietan las garras (como poco, un cuadrado de su ancho)
	if shield != null:
		shield["viewLoss"] = CarGlass.view_loss(bool(shield.cracked), float(shield.peakN) < float(shield.bendN), patches, n_claws,
			maxf(mark_m, CarGlass.GROOVE_BAND_M))
	var gx := vc + ux * v_exit
	var gy := uy * v_exit
	var out := {
		"ok": true, "claw": claw.id, "kind": kind, "zone": zone_id, "target": target.id, "massKg": m, "reducedMassKg": mu_red,
		"vRelKmh": vrel * KMH, "vNormalKmh": vn * KMH, "vTangKmh": vt * KMH,
		# energía del animal respecto al coche; la normal que se disipa (masa reducida) y la tangencial (el motor mantiene
		# la velocidad del coche: la del animal respecto a él)
		"energyJ": 0.5 * m * vrel * vrel, "normalJ": e_n, "tangJ": 0.5 * m * vt * vt, "mu": mu,
		"energy": energy_balance(m, mu_red, vn, vt, v_exit, away, claws_work_j, dent, shield, tear_j, side_window, metal),
		# unidad 4o: depthUm es la hondura de las marcas, la del panel si lo atraviesan (through); tipUm, belowMm y bottoms,
		# dónde queda la punta de la garra, que no pasa del hueco bajo el panel (clearanceMm) ni de su largo
		"marks": {
			"count": n_claws if Js.truthy(sm.scratched) and mark_m > 0.0 else 0, "lengthMm": mark_m * 1000.0,
			"depthUm": sm.depthUm, "residualUm": sm.residualUm, "verdict": sm.verdict, "layer": sm.layer, "widthUm": sm.widthUm,
			"layers": sm.layers, "reachesBody": sm.reachesBody, "scratched": sm.scratched, "through": sm.through,
			"tipUm": sm.tipUm, "belowMm": sm.belowMm, "bottoms": sm.bottoms, "clearanceMm": float(iz.clearance_mm),
		},
		"puncture": punct, "embedded": embedded, "dent": dent, "windshield": shield,
		"stays": stays, "slideM": mark_m, "exitKmh": v_exit * KMH, "contactS": t_crush + t_slide, "hold": hold,
		"groundKmh": 0.0 if stays else sqrt(gx * gx + gy * gy) * KMH,
		# aterriza (no choca) si contra el panel no lleva más velocidad que la de su propia caída
		"landing": vn <= vz + 1e-9,
		# añadidos de la unidad 4d: material de las garras, tipo de ataque, sexo (casuario), la patada, la rotura y la defensa
		"inlay": inlay.id, "attack": "patada" if kick else ("salto" if leaper else "golpe"), "sex": sex, "kick": kick_info,
		"clawFracture": frac, "defense": def_info,
		# unidad 4g: las garras trabadas que rajan el plástico en un costado (null si no hay garras que lo atraviesen)
		"tear": tear,
		# unidad 4i-B2: el salto de un velocirraptor, la masa de más de unas garras reforjadas (con lo que suma a la velocidad
		# del golpe), la punta afilada, si sus garras cortan la chapa y si es el velocirraptor de película (ficción)
		"leap": leap, "clawMass": _with_extra(cm, vrel), "sharpness": sharp.info,
		"cutsBody": can_cut_body(inlay, target, claw), "film": film,
		# unidad 4m: la ventanilla templada (null fuera de la zona «luna»)
		"sideWindow": side_window,
	}
	var v := impact_verdict(out, target)
	if film:
		v = film_verdict(out, target, v)
	out["verdict"] = v.verdict
	out["vsub"] = v.vsub
	out["report"] = damage_report(out, target)
	out["safety"] = SAFETY_NOTE
	# unidad 4j: las componentes de la velocidad y el tiempo de vuelo (kinematics) y la banda del golpe (impact_band)
	out["kinematics"] = kinematics(p, leap)
	out["band"] = impact_band(p, out, mk_show.summary, punct)
	return out


## Rotura de las garras reforjadas de un animal (claw_fracture.gd) con su geometría del motor (Physics.resolve_tool: área,
## semiángulo, alcance y radio de la base), la fuerza normal sobre cada garra en el instante que más la flexa (N), la
## fricción mientras resbala y dónde empuja la chapa (load_x_mm, desde el vértice: claw_load). null con garras de
## queratina.
static func claw_fracture(
	claw: Dictionary, inlay: Variant, per_claw_n: float, mu: float, model: Variant = "2.0", load_x_mm: float = 0.0
) -> Variant:
	var entry: Variant = inlay if inlay is Dictionary else Data.find_by_id(Data.INLAYS, inlay)
	if entry == null or entry.id == "none":
		return null
	var tip := claw_tip(claw, entry, model)
	return ClawFracture.evaluate(entry, tip, float(tip.reach), per_claw_n, mu, load_x_mm)


## Geometría de la garra para la rotura: Contact.tip_geometry con el radio de la base como tope (amax) y, además, su
## alcance (reach) y su dureza (hv), todo de Physics.resolve_tool (una garra reforjada conserva la forma de la garra y toma
## la dureza de su material).
static func claw_tip(claw: Dictionary, inlay: Dictionary, model: Variant = "2.0") -> Dictionary:
	var tool := Physics.resolve_tool(_lab_params(claw, _glass(), { "inlay": inlay, "model": model }))
	var tip := Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
	tip["reach"] = tool.reach
	tip["hv"] = tool.hv
	tip["E"] = tool.E
	return tip


## Resistencia (N) de la pintura y la chapa de un coche contra UNA garra con la punta a h_mm de la superficie. Es la del
## motor para una punción con golpe (Physics: «Resistencia a la penetración F_res(h)» y «Chapa fina: perforación en
## pétalos»; en un golpe el contacto plastifica y toda la fuerza es de la punta), rehecha con su API pública para recorrer
## el camino: mientras la punta indenta (hasta que sale por detrás de la chapa), la dureza de la capa en la que está por
## π·a², con la eficiencia de la punta según el ratio de durezas (Contact.hardness_efficiency); después, la derivada de la
## energía de los pétalos (Wierzbicki 1999) con el radio del agujero, que deja de crecer en la base de la garra (entonces
## desliza y la chapa ya no la frena: 0). tip: claw_tip (con hv). 0 si el objetivo no es un coche con chapa.
static func sheet_resistance_n(tip: Dictionary, target: Dictionary, h_mm: float) -> float:
	var sheet: Variant = Physics.sheet_of(target)
	if sheet == null or not Js.truthy(target.get("layers")):
		return 0.0
	return _sheet_resistance(tip, sheet, Physics.hardness_profile(target), h_mm)


static func _sheet_resistance(tip: Dictionary, sheet: Dictionary, prof: Dictionary, h_mm: float) -> float:
	if h_mm <= 0.0:
		return 0.0
	if h_mm > float(sheet.to):
		var d := 1e-4
		var t: float = sheet.t
		var s0: float = sheet.sigma0
		var e1 := Physics.petal_energy(Contact.hole_radius(tip, h_mm + d), t, s0)
		var e0 := Physics.petal_energy(Contact.hole_radius(tip, maxf(h_mm - d, 0.0)), t, s0)
		return (e1 - e0) / (2.0 * d)
	# pintura sobre chapa (Physics.hardness_profile, PROFILE_PAINT): la pintura hasta su espesor; después, el metal
	var in_film: bool = h_mm <= float(prof.t)
	var h_layer: float = prof.Hf if in_film else prof.Hs
	var h_max: float = prof.Hf if in_film else maxf(float(prof.Hf), float(prof.Hs))
	var eta := Contact.hardness_efficiency(float(tip.hv) * Physics.HV_MPA / h_max)
	if eta <= 0.0:
		return INF
	var a := Contact.contact_radius(tip, h_mm)
	return h_layer / eta * PI * a * a


## Dónde empuja la chapa a una garra con la punta a h_mm de la superficie (mm desde el vértice): el centro de la parte de
## la garra que está dentro de la capa que la frena. En la pintura, la mitad de lo que ha entrado; indentando la chapa, la
## mitad de lo que está dentro del metal (la pintura, mucho más blanda, apenas frena); cuando la ha perforado, el plano
## medio de la chapa, que es el borde del agujero.
static func load_point_mm(sheet: Dictionary, h_mm: float) -> float:
	var from: float = sheet.from
	var to: float = sheet.to
	if h_mm <= from:
		return 0.5 * maxf(h_mm, 0.0)
	if h_mm <= to:
		return 0.5 * (h_mm - from)
	return h_mm - 0.5 * (from + to)


## La carga sobre UNA garra reforjada en el instante que más la flexa: { n (N, la normal), xLoadMm (dónde empuja la chapa,
## desde el vértice), depthMm (dónde está la punta), basis } o null (sin chapa de metal o sin tocarla). Mientras resbala, la
## fricción μ·F empuja de lado en load_point_mm; lo que decide es F por la tensión que da cada newton en la sección más
## cargada con la carga ahí (ClawFracture.peak). Se recorren las dos fases del golpe:
##   - la punción: la punta entra hasta la profundidad final (punct.depthUm) contra la resistencia del motor en cada punto
##     (sheet_resistance_n): LOAD_SCAN_STEPS puntos uniformes en log h desde 1 µm, los bordes de las capas a los dos lados
##     y LOAD_REFINE puntos más entre los vecinos del mejor;
##   - el deslizamiento: la garra raya con slide_n (su parte del peso o de la patada) hundida slide_um (las marcas).
## basis: «pintura», «indentacion» (la punta indenta la chapa), «perforacion» (la chapa ya perforada empuja en el borde del
## agujero) o «marcas» (resbalando).
static func claw_load(
	claw: Dictionary, inlay: Dictionary, target: Dictionary, punct: Variant, slide_n: float = 0.0, slide_um: float = 0.0,
	model: Variant = "2.0"
) -> Variant:
	var sheet: Variant = Physics.sheet_of(target)
	if sheet == null or not is_metal(target):
		return null
	var prof := Physics.hardness_profile(target)
	var tip := claw_tip(claw, inlay, model)
	var reach: float = tip.reach
	var best := -1.0
	var out: Variant = null
	var h_end := minf(float(punct.depthUm) / 1000.0, reach) if punct != null else 0.0
	if h_end > 0.0:
		var hs: Array[float] = []
		var h_min := minf(1e-3, h_end)
		for i in LOAD_SCAN_STEPS + 1:
			hs.append(h_min * V8.js_pow(h_end / h_min, float(i) / float(LOAD_SCAN_STEPS)))
		for b: float in [float(sheet.from), float(sheet.to)]:
			for hb: float in [b - 1e-7, b + 1e-7]:
				if hb > 0.0 and hb < h_end:
					hs.append(hb)
		hs.sort()
		var i_best := 0
		for i in hs.size():
			var k := _load_key(tip, sheet, prof, reach, hs[i])
			if k > best:
				best = k
				i_best = i
		# afina entre los vecinos del mejor punto (sin saltar un borde de capa, donde la resistencia cambia de golpe)
		var h_best: float = hs[i_best]
		var lo: float = hs[maxi(i_best - 1, 0)]
		var hi: float = hs[mini(i_best + 1, hs.size() - 1)]
		for j in LOAD_REFINE:
			var h := lo + (hi - lo) * float(j + 1) / float(LOAD_REFINE + 1)
			if _layer_of(sheet, h) != _layer_of(sheet, h_best):
				continue
			var k := _load_key(tip, sheet, prof, reach, h)
			if k > best:
				best = k
				h_best = h
		out = {
			"n": _sheet_resistance(tip, sheet, prof, h_best), "xLoadMm": load_point_mm(sheet, h_best), "depthMm": h_best,
			"basis": _layer_of(sheet, h_best),
		}
	if slide_n > 0.0 and slide_um > 0.0:
		var h_sl := minf(slide_um / 1000.0, reach)
		var x_sl := load_point_mm(sheet, h_sl)
		var k_sl: float = slide_n * float(ClawFracture.peak(tip, reach, x_sl).factor)
		if k_sl > best:
			out = { "n": slide_n, "xLoadMm": x_sl, "depthMm": h_sl, "basis": "marcas" }
	return out


## F(h) por la tensión por newton de la sección más cargada con la carga en load_point_mm (MPa, para comparar instantes).
static func _load_key(tip: Dictionary, sheet: Dictionary, prof: Dictionary, reach: float, h_mm: float) -> float:
	var f := _sheet_resistance(tip, sheet, prof, h_mm)
	return f * float(ClawFracture.peak(tip, reach, load_point_mm(sheet, h_mm)).factor)


## Trabajo (J) que se queda la chapa (o el plástico) de un coche con la punta de UNA garra hasta h_mm: el de la resistencia
## del motor en la punción con golpe (sheet_resistance_n) con su mismo integrador y sus mismos tramos (Contact.absorbed_work:
## el borde de la pintura, el de la chapa y la base de la garra), que hasta la profundidad del motor es su trabajo de punción
## (un test lo comprueba). 0 si el objetivo no es un coche.
static func sheet_work_j(tip: Dictionary, target: Dictionary, h_mm: float) -> float:
	var sheet: Variant = Physics.sheet_of(target)
	if sheet == null or not Js.truthy(target.get("layers")):
		return 0.0
	var breaks := [float(sheet.from), float(sheet.to)]
	var h_cap := Contact.depth_for_radius(tip, float(tip.amax))
	if h_cap > float(sheet.to):
		breaks.append(h_cap)
	var res := func(h: float) -> float: return sheet_resistance_n(tip, target, h)
	return Contact.absorbed_work(res, h_mm, breaks)


## La punción del golpe (r: Physics.compute, punción) para impact() y la banda (unidad 4o): una garra que atraviesa el panel
## no entra más que el hueco que hay detrás (room, room_um). Si el motor la lleva más honda (hasta que la chapa ya no la
## frena o hasta su largo), su punta topa con lo que hay bajo el panel y se queda ahí: el agujero es el de la garra a esa
## profundidad (Contact.hole_radius) y el trabajo, el de la chapa hasta ella (sheet_work_j; en la punción con golpe el
## contacto plastifica y la geometría es la del motor sin factor). Lo que el golpe no gasta en las garras va a la abolladura,
## como siempre. { depthUm (la punta desde la cara de fuera), through, verdict, layer, workJ (por garra), holeUm, layers,
## reachesBody, belowMm (lo que asoma por detrás del panel), bottoms (llega al fondo del hueco) }.
static func _puncture_block(
	r: Dictionary, claw: Dictionary, inlay: Dictionary, target: Dictionary, room: float, model: Variant = "2.0"
) -> Dictionary:
	var depth := float(r.depthUm)
	var hole := float(r.grooveWidthUm)
	var wj: float = r.workJ if r.get("workJ") != null else 0.0
	var through := Js.truthy(r.get("through"))
	var panel := panel_um(target)
	var bottoms := false
	if through and panel > 0.0 and depth > room:
		var tip := claw_tip(claw, inlay, model)
		var h := room / 1000.0
		# con el agujero ya del ancho de la garra (su base), la chapa no la frena más: el agujero y el trabajo son los del
		# motor (rehacerlos con el integrador cambiaría la última cifra sin física detrás); si la punta topa antes, más estrecho
		if h < Contact.depth_for_radius(tip, float(tip.amax)):
			hole = 2.0 * Contact.hole_radius(tip, h) * 1000.0
			wj = sheet_work_j(tip, target, h)
		depth = room
		bottoms = true
	return {
		"depthUm": depth, "through": through, "verdict": r.verdict, "layer": r.get("layer"), "workJ": wj, "holeUm": hole,
		"layers": layers_crossed(target, depth), "reachesBody": depth > Data.PAINT_LAYERS[-1].to - 1e-6,
		"belowMm": maxf(depth - panel, 0.0) / 1000.0 if through and panel > 0.0 else 0.0, "bottoms": bottoms,
		"fab": float(r.get("fab", 1.0)),  # unidad 4s: lo que arranca la punta (el labio de la punzada, el resto)
	}


## Fase del camino de la punta: «pintura», «indentacion» (dentro de la chapa) o «perforacion» (ya la ha atravesado).
static func _layer_of(sheet: Dictionary, h_mm: float) -> String:
	if h_mm <= float(sheet.from):
		return "pintura"
	return "indentacion" if h_mm <= float(sheet.to) else "perforacion"


## Resistencia a tracción (f_u, MPa) de la chapa de cada carrocería metálica, para lo que aguanta alrededor del agujero de
## una garra clavada (unidad 4p): la de las fichas del catálogo del banco (docs/FISICA.md, apartado 14), por id de
## Data.CAR_BODIES. value: la que se usa (la de σ0 en el moderno y el centro de la ficha en el clásico); min y max, la banda.
const SHEET_FU := {
	"acero-bh": {
		"value": 340.0, "min": 290.0, "max": 360.0, "quality": "secondary",
		"source": "acero de horno tipo HC180B: Rm 290-360 MPa (voestalpine 2022, hoja técnica de los aceros bake-hardening, EN 10268), 340 en el de Nippon Steel (2013), el de la chapa de 0,7 mm del banco",
	},
	"acero-dulce": {
		"value": 310.0, "min": 270.0, "max": 350.0, "quality": "secondary",
		"source": "acero dulce de embutición tipo DC04: Rm 270-350 MPa (ArcelorMittal, catálogo B10, EN 10130), el centro de la ficha",
	},
	"aluminio": {
		"value": 273.0, "min": 273.0, "max": 273.0, "quality": "secondary",
		"source": "aluminio AA6016 tras el horneado de la pintura: Rm 273 MPa (Prillhofer R et al. 2014, medido en el estado T4*), sin banda: una sola medición",
	},
}
## Lo que aguanta una chapa fina alrededor de un agujero contra un pasador que tira de lado, lejos de sus bordes (α_b = 1):
## F = k·k_t·f_u·d·t, con k_t = (0,8·t + 1,5)/2,5 hasta 1,25 mm de espesor y 1 por encima (sheet_bearing_n). k_hi: la regla sin
## límite de deformación del agujero, la banda favorable.
const SHEET_BEARING := {
	"k": 2.5, "k_hi": 3.0, "kt_full_mm": 1.25, "quality": "estimate",
	"source": "caso medido más parecido: un tornillo que aplasta una chapa fina lejos de los bordes, F = 2,5·k_t·f_u·d·t con k_t = (0,8·t + 1,5)/2,5 (EN 1993-1-3, tabla 8.4, de 0,75 a 3 mm, sin coeficiente de seguridad; la de 0,7 mm del coche moderno, con la misma recta) y, sin límite de deformación del agujero, 3·f_u·d·t (AISC 360-16, J3.10), la banda favorable; d, el diámetro de la garra en el plano medio de la chapa. Suposiciones: la garra es un pasador en un agujero que ya tiene su forma, y los pétalos doblados no restan ni suman",
}


## k_t de una chapa fina de t_mm (EN 1993-1-3, tabla 8.4): (0,8·t + 1,5)/2,5 hasta 1,25 mm y 1 por encima. Por debajo de
## 0,75 mm la norma no llega (la chapa de 0,7 mm del coche moderno): se sigue la misma recta (estimación).
static func bearing_kt(t_mm: float) -> float:
	return minf((0.8 * t_mm + 1.5) / 2.5, 1.0)


## Lo que aguanta la chapa de un coche alrededor del agujero de UNA garra de diámetro d_mm que tira de lado (N; unidad 4p,
## SHEET_BEARING): F = 2,5·k_t·f_u·d·t con la f_u de which («value» o «min»; SHEET_FU) o, con «max», 3·f_u,max·d·t (sin límite
## de deformación del agujero). INF si su chapa no tiene f_u en SHEET_FU (no limita); 0 con d_mm = 0.
static func sheet_bearing_n(target: Dictionary, d_mm: float, which: String = "value") -> float:
	var body: Variant = target.get("body")
	var fu: Variant = SHEET_FU.get(String(body.id)) if body != null else null
	if fu == null:
		return INF
	if d_mm <= 0.0:
		return 0.0
	var t: float = float(body.t) / 1000.0
	var f: float = float(fu.get(which, fu.value))
	if which == "max":
		return float(SHEET_BEARING.k_hi) * f * d_mm * t
	return float(SHEET_BEARING.k) * bearing_kt(t) * f * d_mm * t


## Lo que aguantan de lado unas garras reforjadas clavadas en la chapa, todas juntas (N): { value, min, max, governs, … } o
## null (sin chapa de metal, queratina o material sin resistencia medida). El anclaje tira de cada garra en el borde del agujero
## (load_point_mm) y manda el menor de tres límites (unidad 4p; antes solo se miraba el primero):
##   - la flexión de la garra (ClawFracture.peak: la sección más cargada con la carga en el borde del agujero);
##   - el cortante de la garra (ClawFracture.shear_limit_n) en su sección de la cara de fuera del metal, por donde ya ha pasado
##     toda la carga de la chapa: clavada hasta la base, el brazo hasta los dedos es la pintura y media chapa, y la flexión no
##     llega a mandar (salían «3.0 MN»);
##   - la chapa alrededor del agujero, que se aplasta como contra un pasador (sheet_bearing_n, con el diámetro de la garra en
##     el plano medio de la chapa).
## Valor y banda favorable: con la punta a embed_mm (por defecto, clavada hasta la base) y la resistencia central o la máxima
## (en la chapa, la f_u central con la regla de la chapa fina o la más alta sin límite de deformación). Banda desfavorable: con
## la punta recién asomada por detrás de la chapa (la carga más cerca del vértice, donde la garra es más fina) y las mínimas.
## Campos: governs, governsMin y governsMax («flexion», «cortante» o «chapa»: lo que manda en el valor y en cada extremo);
## perClaw ({ bendN, shearN, bearingN }: los tres límites de una garra en el valor); clawN (lo que aguanta la garra sola) y
## sheetN (la chapa), todas juntas; kind (el de la resistencia), depthMm (dónde está la punta en el valor), atBase, dMm (el
## diámetro de la garra en la chapa), tMm, kt, fuMPa; quality y source, los del límite que manda en el valor.
static func claws_hold_n(
	claw: Dictionary, inlay: Dictionary, target: Dictionary, n_claws: int, embed_mm: float = INF, model: Variant = "2.0"
) -> Variant:
	var sheet: Variant = Physics.sheet_of(target)
	var s: Variant = ClawFracture.strength(inlay)
	if sheet == null or s == null or not is_metal(target):
		return null
	var tip := claw_tip(claw, inlay, model)
	var reach: float = tip.reach
	var to: float = sheet.to
	var half_t := 0.5 * (to - float(sheet.from))
	var h := maxf(minf(embed_mm, reach), to)
	var x_val := load_point_mm(sheet, h)
	var x_lo := load_point_mm(sheet, to)
	var kind := String(s.kind)
	var val := _hold_limits(tip, reach, x_val, x_val + half_t, float(s.value), kind, target, "value")
	var lo := _hold_limits(tip, reach, x_lo, x_lo + half_t, float(s.min), kind, target, "min")
	var hi := _hold_limits(tip, reach, x_val, x_val + half_t, float(s.max), kind, target, "max")
	var n := float(n_claws)
	var t_mm: float = float(target.body.t) / 1000.0
	var fu: Variant = SHEET_FU.get(String(target.body.id))
	var quality: String = String(SHEET_BEARING.quality)
	var source: String = "%s. Rm de la chapa: %s" % [SHEET_BEARING.source, fu.source if fu != null else "sin dato"]
	if val.governs != "chapa":
		quality = String(s.quality)
		source = "%s. Resistencia de la garra: %s" % [ClawFracture.SRC_SHEAR if val.governs == "cortante" else
			"la garra como viga en voladizo con la carga en el borde del agujero, σ = 4·F·(x − x0)/(π·r³)", s.source]
	return {
		"value": n * float(val.n), "min": n * float(lo.n), "max": n * float(hi.n),
		"governs": val.governs, "governsMin": lo.governs, "governsMax": hi.governs,
		"perClaw": { "bendN": val.bendN, "shearN": val.shearN, "bearingN": val.bearingN },
		"clawN": n * minf(float(val.bendN), float(val.shearN)), "sheetN": n * float(val.bearingN), "kind": kind,
		"depthMm": h, "atBase": h >= reach, "dMm": val.dMm, "tMm": t_mm, "kt": bearing_kt(t_mm),
		"fuMPa": fu.value if fu != null else null, "quality": quality, "source": source,
	}


## Los tres límites de lo que aguanta de lado UNA garra clavada con la carga a x_mm del vértice, el plano medio de la chapa
## (claws_hold_n): { bendN (flexión), shearN (cortante), bearingN (la chapa), n (el menor), governs, dMm }. x_shear_mm: la
## sección de la garra en la cara de fuera del metal, por donde ya ha pasado toda la carga (el cortante; con la presión
## repartida por el espesor, como en la regla de la chapa). s_mpa y kind: la resistencia del material; which: el extremo de
## la f_u de la chapa y de su regla («value», «min» o «max»).
static func _hold_limits(
	tip: Dictionary, reach: float, x_mm: float, x_shear_mm: float, s_mpa: float, kind: String, target: Dictionary, which: String
) -> Dictionary:
	var f: float = ClawFracture.peak(tip, reach, x_mm).factor
	var bend := s_mpa / f if f > 0.0 else INF
	var shear := ClawFracture.shear_limit_n(tip, minf(x_shear_mm, reach), s_mpa, kind)
	var d := 2.0 * ClawFracture.section_radius(tip, x_mm)
	var bearing := sheet_bearing_n(target, d, which)
	var gov := "chapa"
	if minf(bend, shear) < bearing:
		gov = "cortante" if shear <= bend else "flexion"
	return { "bendN": bend, "shearN": shear, "bearingN": bearing, "n": minf(bearing, minf(bend, shear)), "governs": gov, "dMm": d }


## Lo que manda en lo que aguantan de lado unas garras clavadas (claws_hold_n), en palabras: «manda la chapa: se aplasta
## alrededor del agujero con ~5.1 kN por garra (la garra aguantaría ~199 kN)», «manda la garra: se cizalla a la altura de la
## chapa…» o «manda la garra: se parte por donde más flexa…».
static func claws_hold_txt(hold: Dictionary) -> String:
	var pc: Dictionary = hold.perClaw
	var claw_n := minf(float(pc.bendN), float(pc.shearN))
	match String(hold.governs):
		"chapa":
			return "manda la chapa: se aplasta alrededor del agujero con ~%s por garra (la garra aguantaría ~%s)" % [
				_fmt_n(float(pc.bearingN)), _fmt_n(claw_n)]
		"cortante":
			return "manda la garra: %s a la altura de la chapa con ~%s por garra (la chapa aguantaría ~%s)" % [
				"se cizalla" if hold.kind == "flexion" else "fluye a cortante", _fmt_n(float(pc.shearN)), _fmt_n(float(pc.bearingN))]
	return "manda la garra: se %s por donde más flexa con ~%s por garra (la chapa aguantaría ~%s)" % [
		"parte" if hold.kind == "flexion" else "dobla", _fmt_n(float(pc.bendN)), _fmt_n(float(pc.bearingN))]


# ════════ Garras trabadas que rajan el plástico (unidad 4g) ════════

## El desgarro de unas garras trabadas en un plástico, con el balance de energía. Cada garra abre una grieta de todo el
## espesor y pide F = R·t (r_kj_m2 en kJ/m² = N/mm; t_mm en mm): las n garras frenan al animal (m, kg) con n·R·t, si él
## las aguanta (anchor_n ≥ n·R·t, su anclaje con las garras clavadas); si no, sus dedos ceden y se le sueltan sin rajarlo.
## Empieza con vt1 (m/s) a lo largo del panel y le quedan room_m (m) de panel: lo raja hasta pararse respecto al coche
## (½·m·vt1² = n·R·t·L) o hasta el final del panel, por donde sale con vExitMs (m/s). { holds, perClawN, forceN (N),
## lengthM, vExitMs, timeS, energyJ (J), stopped (se para respecto al coche antes del final) }. Pura y determinista.
static func tear_run(
	m: float, vt1: float, room_m: float, n_claws: int, t_mm: float, r_kj_m2: float, anchor_n: float
) -> Dictionary:
	var per := r_kj_m2 * t_mm
	var f := per * float(n_claws)
	var holds := f > 0.0 and anchor_n >= f
	var out := {
		"holds": holds, "perClawN": per, "forceN": f, "lengthM": 0.0, "vExitMs": vt1, "timeS": 0.0, "energyJ": 0.0,
		"stopped": holds and vt1 <= 0.0,
	}
	if not holds or vt1 <= 0.0 or room_m <= 0.0 or m <= 0.0:
		return out
	var a := f / m
	var d := vt1 * vt1 / (2.0 * a)
	var stopped := d <= room_m
	var v_exit := 0.0 if stopped else sqrt(maxf(vt1 * vt1 - 2.0 * a * room_m, 0.0))
	out.lengthM = d if stopped else room_m
	out.vExitMs = v_exit
	out.timeS = (vt1 - v_exit) / a
	out.energyJ = 0.5 * m * (vt1 * vt1 - v_exit * v_exit)
	out.stopped = stopped
	return out


## Lo que decide el desgarro de un plástico con un animal: { r (PLASTIC_TEAR del plástico: value, min, max en kJ/m²,
## quality, source), tMm (su espesor, mm), cap (su anclaje con las garras clavadas: el agarre de un ave o las manos
## enganchadas de un mamífero, con la fuerza de defensa si está asustado; { value, min, max } en N) } o null (una chapa de
## metal o un plástico sin datos de desgarro).
static func _tear_params(
	target: Dictionary, kind: String, claw: Dictionary, body: Dictionary, m: float, zone: Dictionary, defense_n: Variant
) -> Variant:
	var tb: Variant = target.get("body")
	if tb == null or is_metal(target):
		return null
	var r: Variant = PLASTIC_TEAR.get(String(tb.id))
	if r == null:
		return null
	var cap := _anchor_capacity(_clasp(kind), kind, claw, body, m, target, zone, defense_n)
	return { "r": r, "tMm": float(tb.t) / 1000.0, "cap": cap }


## El bloque tear del golpe: { applies, holds, lengthMm, minMm, maxMm (la banda), timeS, energyJ, perClawN, forceN, claws,
## anchorN, toughnessKJm2 ({ value, min, max }), thicknessMm, stopped (se para respecto al coche antes del final del
## panel: el coche se lo lleva), reachesEnd (raja hasta el final del panel), vExitKmh, quality, source }. La banda: la
## corta con la tenacidad más alta y el anclaje más bajo (con el que puede soltarse); la larga, al revés.
static func _tear_block(run: Dictionary, tp: Dictionary, m: float, vt1: float, room_m: float, n: int) -> Dictionary:
	var r: Dictionary = tp.r
	var cap: Dictionary = tp.cap
	var t_mm: float = tp.tMm
	var short := tear_run(m, vt1, room_m, n, t_mm, float(r.max), float(cap.min))
	var long := tear_run(m, vt1, room_m, n, t_mm, float(r.min), float(cap.max))
	var length: float = run.lengthM
	return {
		"applies": true, "holds": run.holds, "lengthMm": length * 1000.0,
		"minMm": minf(float(short.lengthM), length) * 1000.0, "maxMm": maxf(float(long.lengthM), length) * 1000.0,
		"timeS": run.timeS, "energyJ": run.energyJ, "perClawN": run.perClawN, "forceN": run.forceN, "claws": n,
		"anchorN": cap, "toughnessKJm2": { "value": r.value, "min": r.min, "max": r.max }, "thicknessMm": t_mm,
		"stopped": run.stopped and length > 0.0, "reachesEnd": length > 0.0 and not run.stopped,
		"vExitKmh": float(run.vExitMs) * KMH, "quality": r.quality,
		"source": String(r.source) + " Lo que aguanta el animal con las garras clavadas es su anclaje, el mismo que quieto encima con las garras clavadas: el agarre medido de un ave (Sustaita & Hertel 2010) o sus manos enganchadas (media vez su peso por mano, estimación; asustado, sus flexores).",
	}


## Las marcas de unas garras que rajan el plástico: ranuras de lado a lado por todas las capas (hondas como la pintura y el
## plástico: lo que hay más allá es aire), del ancho de la garra donde atraviesa el panel (el agujero de la punción); lo
## rajado no se recupera. sm: las marcas de siempre (el motor).
## Unidad 4o: la punta de cada garra es la de la punción (punct.depthUm, que no pasa del hueco bajo el panel).
static func _tear_marks(sm: Dictionary, target: Dictionary, punct: Dictionary) -> Dictionary:
	var depth := float(Data.PAINT_LAYERS[-1].to) + float(target.body.t)
	return {
		"depthUm": depth, "residualUm": depth, "verdict": "RAJA EL PLÁSTICO", "layer": "plástico", "scratched": true,
		"muEff": sm.get("muEff"), "widthUm": maxf(float(sm.widthUm), float(punct.holeUm)),
		"layers": layers_crossed(target, depth), "reachesBody": true, "through": true,
		"tipUm": maxf(float(punct.depthUm), depth), "belowMm": float(punct.get("belowMm", 0.0)), "bottoms": Js.truthy(punct.get("bottoms")),
	}


## El desgarro en palabras (la fila Desgarro del informe): «raja 80 cm de la aleta con 8 garras: ~113 N cada una (45 kJ/m² ×
## 2.5 mm), 720 J; llega al final del panel», o por qué no.
static func tear_txt(t: Dictionary) -> String:
	var n := int(t.claws)
	if not Js.truthy(t.holds):
		return "no: rajarlo pide ~%s (%d garras × ~%s) y solo aguanta ~%s: las garras se le sueltan" % [
			_fmt_n(float(t.forceN)), n, _fmt_n(float(t.perClawN)), _fmt_n(float(t.anchorN.value))]
	if float(t.lengthMm) <= 0.0:
		return "no: las garras quedan trabadas, pero no le queda velocidad a lo largo del panel"
	var txt := "raja %s con %d %s: ~%s cada una (%s kJ/m² × %s), %s" % [
		fmt_long(float(t.lengthMm) * 1000.0), n, "garra" if n == 1 else "garras", _fmt_n(float(t.perClawN)),
		Js.js_num_str(float(t.toughnessKJm2.value)), Format.fmt_len(float(t.thicknessMm) * 1000.0), fmt_energy(float(t.energyJ))]
	if Js.truthy(t.reachesEnd):
		txt += "; llega al final del panel"
	elif Js.truthy(t.stopped):
		txt += "; se para a su lado: el coche se lo lleva"
	return txt


# ════════ La cinemática y la banda del golpe (unidad 4j) ════════

## La cinemática del golpe dicha para la interfaz: no es un dato medido, es la cuenta de la guía (la velocidad relativa y
## la caída libre; el salto de los velocirraptores lo integra leap_block).
const SRC_KINEMATICS := "cinemática del golpe: la velocidad del animal respecto al coche es la suya (con el ángulo del salto) menos la del coche y, en los paneles de arriba, la de su caída libre desde la altura del salto, √(2·g·h), que tarda √(2·h/g) con g = 9,807 m/s² (sin el rozamiento del aire, que en unos metros de caída no cuenta); en un costado no cae; la patada del casuario llega contra el panel con la velocidad de su salto, y el salto de un velocirraptor desde la carretera se integra con el aire que lo frena en el vuelo"


## La cinemática del golpe (unidad 4j), sin compute(): las mismas cuentas que impact() (coche a v hacia delante, animal a v_a
## con el ángulo θ respecto al coche y, en los paneles de arriba, cayendo desde h; el velocirraptor, con su salto) con las
## componentes que impact() no devolvía. p: los parámetros de impact(). leap: el salto que ya ha calculado impact()
## (leap_block); sin él, se calcula aquí con los mismos datos. Ejes del coche: x hacia delante, y hacia el costado por el
## que llega el animal y z hacia arriba.
##   - relKmh { x, y, z }: la velocidad del animal respecto al coche; su módulo, relAbsKmh, es impact().vRelKmh. En la
##     patada del casuario la normal al panel es la de su salto (como en impact) y la tangencial, la de su carrera;
##   - normalKmh y tangKmh (impact().vNormalKmh y vTangKmh) y awayKmh: lo que se aleja del panel si no choca contra él;
##   - el vuelo antes de tocar el panel: flightS, el tiempo en el aire (cayendo desde h, √(2·h/g); saltando desde la
##     carretera, el de leap_block); dropM, lo que baja (h, o de lo más alto del salto al panel); fallKmh, la velocidad de
##     bajada al llegar; y carFlightM, lo que avanza el coche mientras tanto (v·t). En un costado y en la patada no vuela: 0;
##   - arrival { x, z, lateral }: la dirección de llegada para el dibujo (MovingCarState.arrival);
##   - apex (unidad 4m): el velocirraptor salta para llegar a la ventanilla y golpea en lo alto del salto, sin subir ni
##     bajar: vuela lo que tarda en subir (leap.timeS) y no cae nada (dropM y fallKmh, 0).
## { ok, side, kick, leap (salta desde la carretera), apex, carKmh, animalKmh, angleDeg, dropM, fallKmh, flightS, carFlightM,
##   relKmh, relAbsKmh, normalKmh, tangKmh, awayKmh, arrival, quality ("": es una cuenta, no un dato), source } o
##   { ok: false, reason }.
static func kinematics(p: Dictionary, leap: Variant = null) -> Dictionary:
	var k := _kin(p, leap)
	if not k.ok:
		return k
	var vc: float = k.vc
	var t: float = k.t
	return {
		"ok": true, "side": k.side, "kick": k.kick, "leap": k.leap, "apex": k.apex, "carKmh": vc * KMH, "animalKmh": float(k.va) * KMH,
		"angleDeg": float(p.get("angle_deg", PARAMS.angle_deg.default)), "dropM": k.drop, "fallKmh": float(k.vz) * KMH,
		"flightS": t, "carFlightM": vc * t,
		"relKmh": { "x": float(k.relx) * KMH, "y": float(k.rely) * KMH, "z": float(k.relz) * KMH },
		"relAbsKmh": float(k.vrel) * KMH, "normalKmh": float(k.vn) * KMH, "tangKmh": float(k.vt) * KMH,
		"awayKmh": float(k.away) * KMH, "arrival": k.arrival, "quality": "", "source": SRC_KINEMATICS,
	}


## El salto de un velocirraptor con los datos de p, como lo calcula impact() (la garra afilada, su masa con la de sus garras
## y el aire del ensayo): para kinematics() sin el golpe. hi: con los datos más favorables al salto (la banda). null si no
## salta.
static func _leap_of(p: Dictionary, hi: bool = false) -> Variant:
	var claw: Dictionary = ClawsV2.apply(p.claw)
	var body: Variant = body_of(claw)
	var inlay: Variant = inlay_of(p)
	if body == null or inlay == null or not is_leaper(body):
		return null
	claw = _sharpen(claw, inlay, p).claw
	var m := mass_of(claw, sex_of(body, p))
	var cm: Variant = claw_mass_block(claw, inlay, strike_claws_of(body), m)
	if cm != null:
		m += float(cm.addedKg)
	var va := maxf(float(p.get("animal_kmh", PARAMS.animal_kmh.default)), 0.0) / KMH
	var th := float(p.get("angle_deg", PARAMS.angle_deg.default)) * PI / 180.0
	var rho := air_density(float(p.get("temp_c", PARAMS.temp_c.default)), float(p.get("altitude_m", PARAMS.altitude_m.default)))
	var zone_id := String(p.get("zone", "techo"))
	var lp := leap_block(claw, body, zone_id, va, th, rho, m, hi)
	if lp.reaches and Js.truthy(IMPACT_ZONES[zone_id].get("tempered")):
		lp.merge(window_leap_fields(), true)  # unidad 4m: salta para llegar a la ventanilla, como en impact()
	return lp


## Las cuentas de kinematics() en m/s (las que usa también la banda del golpe): las de impact(), paso a paso. leap: el salto
## de un velocirraptor (leap_block) o null (se calcula con _leap_of).
static func _kin(p: Dictionary, leap: Variant = null) -> Dictionary:
	var body: Variant = body_of(p.get("claw"))
	if body == null:
		return { "ok": false, "reason": "sin datos de este animal para el coche en marcha" }
	var zone_id := String(p.get("zone", "techo"))
	var iz: Variant = IMPACT_ZONES.get(zone_id)
	if iz == null:
		return { "ok": false, "reason": "zona de golpe «%s» desconocida" % zone_id }
	var kick := is_kicker(body)
	var leaper := is_leaper(body)
	var vc := maxf(float(p.get("v_kmh", PARAMS.v_kmh.default)), 0.0) / KMH
	var va := maxf(float(p.get("animal_kmh", PARAMS.animal_kmh.default)), 0.0) / KMH
	var th := float(p.get("angle_deg", PARAMS.angle_deg.default)) * PI / 180.0
	var side: bool = iz.normal == "lado"
	var drop := 0.0 if side or kick else maxf(float(p.get("drop_m", PARAMS.drop_m.default)), 0.0)
	var vz := sqrt(2.0 * G * drop)
	var t := vz / G
	var rx := va * V8.js_cos(th) - vc
	var ry := va * V8.js_sin(th)
	var rz := -vz
	var jumps := false
	var apex := false
	if leaper:
		# el salto de un velocirraptor (impact: leap_block): llega con las componentes de su vuelo, respecto al suelo
		var lp: Variant = leap if leap != null else _leap_of(p)
		if lp == null or not Js.truthy(lp.reaches):
			return { "ok": false, "reason": String(lp.reason) if lp != null else "sin salto" }
		va = float(lp.runKmh) / KMH
		rx = float(lp.ux) - vc
		ry = float(lp.uy)
		rz = float(lp.uz)
		# unidad 4m: a la ventanilla salta para llegar y golpea en lo alto del salto (window_leap_fields), sin bajar nada
		apex = Js.truthy(lp.get("window"))
		jumps = not Js.truthy(lp.side) or apex
		vz = maxf(-rz, 0.0)
		t = float(lp.timeS)
		drop = maxf(float(lp.apexM) - float(lp.panelM), 0.0) if jumps else 0.0
	var vn := 0.0
	var vt := 0.0
	var away := 0.0
	var nx := 0.0
	var nz := 0.0
	var tx := rx
	var tz := rz
	if side:
		vn = absf(ry)
		vt = sqrt(rx * rx + rz * rz)
	else:
		var b: float = float(iz.slope_deg) * PI / 180.0
		nx = V8.js_sin(b)
		nz = V8.js_cos(b)
		var dot := rx * nx + rz * nz
		vn = maxf(0.0, -dot)
		away = maxf(0.0, dot)
		tx = rx - dot * nx
		tz = rz - dot * nz
		vt = sqrt(tx * tx + ry * ry + tz * tz)
	# la dirección de llegada para el dibujo (la de la 4c): la caída o el salto en los paneles de arriba; en la patada, el
	# salto del casuario contra el panel
	var ax := rx
	var ay := ry
	var az := 0.0 if side else rz
	var relx := rx
	var rely := ry
	var relz := rz
	if kick:
		# la patada: en la normal, la velocidad del salto (KICK); la carrera solo cuenta a lo largo del panel
		vn = kick_leap_ms()
		away = 0.0
		if side:
			rely = vn
			ay = vn
		else:
			relx = tx - vn * nx
			relz = tz - vn * nz
			az = -vn
	var vrel := sqrt(vn * vn + vt * vt) if kick else sqrt(rx * rx + ry * ry + rz * rz)
	var flat := sqrt(ax * ax + az * az)
	var all := sqrt(ax * ax + ay * ay + az * az)
	var arrival := { "x": 0.0, "z": -1.0, "lateral": 1.0 if all > 0.0 else 0.0 }
	if flat > 0.0:
		arrival = { "x": ax / flat, "z": az / flat, "lateral": absf(ay) / all if all > 0.0 else 0.0 }
	return {
		"ok": true, "side": side, "kick": kick, "leap": jumps, "apex": apex, "vc": vc, "va": va, "drop": drop, "vz": vz, "t": t,
		"vn": vn, "vt": vt, "away": away, "vrel": vrel, "relx": relx, "rely": rely, "relz": relz, "arrival": arrival,
	}


## La banda del golpe (unidad 4j): el mismo golpe con todos los datos a favor del coche (lo que menos daño le deja: lo) y
## con todos en contra (lo que más: hi), como la banda del despegue del animal quieto encima (detach: minKmh y maxKmh).
## Solo se mueven los datos que ya tienen banda:
##   - la fricción de garras y almohadillas, de 0,3 a 1 (FRICTION): con menos, resbala y raja más (marcas y desgarro más
##     largos); con más, menos;
##   - la dureza de la pintura, del barniz más blando medido (el del motor, 20 HV = 196 MPa) al más duro (425 MPa, Vodnick
##     2006; PLOUGH), en las marcas: con la más dura, menos hondas, y la queratina (~294 MPa) ya no llega a 0,8 veces su
##     dureza y no la raya. En la punción no: allí la pintura es una película fina sobre la chapa o el plástico golpeada con
##     toda la energía del golpe, y el criterio de quién cede al rayar no dice si la atraviesa;
##   - en el plástico, su tenacidad y lo que aguanta el animal con las garras clavadas (la banda del desgarro, _tear_block);
##   - asustado, la fuerza de cada garra (defense_force: perClaw, con su banda);
##   - el casuario: su masa (BODIES.casuario.mass_kg del sexo), su salto (hasta KICK.work_j_per_kg.max) y la fuerza de su
##     pata (KICK.force_bw);
##   - los velocirraptores: su salto (hasta KICK.work_j_per_kg.max) y su carrera (hasta run_kmh.max): leap_block con hi;
##   - la ventanilla templada (unidad 4m): la compresión de sus caras, de 150 MPa a favor del coche a 80 en contra
##     (TEMPER_SIGMA_MPA), con side_window_impact en los dos extremos (si estalla y con qué fuerza de pico);
##   - el hueco bajo el capó (unidad 4o): de 20 mm a favor del coche a 100 en contra (CLEARANCE_BAND, los huecos ensayados
##     bajo un capó): el tope de la abolladura y de la punta de unas garras que lo atraviesan.
## Sin banda (lo dice la fuente, con el porqué): la rigidez y el recorrido de la pata, el hueco bajo el techo, la puerta y la
## aleta (CLEARANCE_FIXED), la hoja del parabrisas y la de la ventanilla (su espesor, su tamaño y su resistencia a flexión).
## sm0 y punct0: las marcas (antes del desgarro) y la punción del golpe central, que los extremos reutilizan cuando sus
## datos son los mismos (null: se recalculan). Coste: las marcas con la pintura más dura (un compute más; asustado, dos; el
## casuario, que cambia de masa y de fuerza, seis; el velocirraptor, uno más por la punción de su salto más rápido; en el
## capó, las marcas y la punción que lo atraviesan, otra vez con cada hueco); lo demás, sin compute.
## { lo, hi (los dos extremos: marksDepthUm, marksCount, marksLengthMm, dentMm, dentVisible, through, punctureDepthUm,
##   normalJ, tearMm, slideM, stays, exitKmh, mu, massKg, sideWindow), marksDepthUm, marksLengthMm, dentMm, normalJ, tearMm,
##   slideM ({ value, min, max }: el valor central y los extremos; dentMm y tearMm, null si no hay abolladura o desgarro),
##   through ({ value, lo, hi }: si perfora), marksThrough ({ value, lo, hi }: si las marcas atraviesan el panel, y entonces su
##   hondura es la del panel; unidad 4o) y marksBelowMm ({ value, min, max }: lo que asoma la punta por detrás del panel, sin
##   pasar del hueco), sideWindow (la ventanilla templada, _band_window_range; null en el resto),
##   varies (los datos que se mueven: friccion, pintura, plastico, defensa, casuario, salto, templado, hueco), fixed (los que
##   no tienen banda: pata, hueco, parabrisas, ventanilla), quality, source } o null (sin golpe).
static func impact_band(p: Dictionary, r: Dictionary, sm0: Variant = null, punct0: Variant = null) -> Variant:
	if not Js.truthy(r.get("ok")):
		return null
	var ctx := _band_ctx(p, r)
	var lo := _band_case(ctx, _band_knobs(ctx, "lo"), sm0, punct0)
	var hi := _band_case(ctx, _band_knobs(ctx, "hi"), sm0, punct0)
	var mid := band_point(r)
	var varies: Array = ["friccion"]
	if not ctx.glass:
		varies.append("pintura")
	if mid.tearMm != null or lo.tearMm != null or hi.tearMm != null:
		varies.append("plastico")
	if ctx.df != null and not ctx.kick:
		varies.append("defensa")
	if ctx.kick:
		varies.append("casuario")
	if ctx.leaper:
		varies.append("salto")
	if ctx.tempered:
		varies.append("templado")  # unidad 4m: la compresión de las caras de la ventanilla
	# unidad 4o: el hueco bajo el capó tiene banda (CLEARANCE_BAND); el del resto de paneles, no
	var gap_band: bool = CLEARANCE_BAND.has(String(ctx.zone_id)) and not ctx.glass
	if gap_band:
		varies.append("hueco")
	var fixed: Array = []
	if mid.dentMm != null or lo.dentMm != null or hi.dentMm != null:
		fixed.append("pata")
		if not gap_band:
			fixed.append("hueco")
	if ctx.tempered:
		fixed.append_array(["pata", "ventanilla"])
	elif ctx.glass:
		fixed.append_array(["pata", "parabrisas"])
	var out := { "lo": lo, "hi": hi }
	for key: String in ["marksDepthUm", "marksLengthMm", "dentMm", "normalJ", "tearMm", "slideM", "marksBelowMm"]:
		out[key] = _band_range(mid, lo, hi, key)
	out["through"] = { "value": mid.through, "lo": lo.through, "hi": hi.through }
	out["marksThrough"] = { "value": mid.marksThrough, "lo": lo.marksThrough, "hi": hi.marksThrough }  # unidad 4o
	out["sideWindow"] = _band_window_range(mid.sideWindow, lo.sideWindow, hi.sideWindow) if ctx.tempered else null
	out["varies"] = varies
	out["fixed"] = fixed
	out["quality"] = "estimate"
	out["source"] = band_source(ctx, varies, fixed)
	return out


## Lo que la banda del golpe mira de un resultado de impact() (el valor central): marcas (su profundidad y su largo, 0 si
## no quedan), abolladura, punción, energía contra el panel, desgarro, resbalón y la ventanilla templada (_band_window).
static func band_point(r: Dictionary) -> Dictionary:
	var marks: Dictionary = r.marks
	var count := int(marks.count)
	var dent: Variant = r.get("dent")
	var dent_on: bool = dent != null and dent.applies
	var punct: Variant = r.get("puncture")
	var tear: Variant = r.get("tear")
	var sw: Variant = r.get("sideWindow")
	return {
		"marksDepthUm": float(marks.depthUm) if count > 0 else 0.0, "marksCount": count,
		"marksLengthMm": float(marks.lengthMm) if count > 0 else 0.0,
		# unidad 4o: si las marcas atraviesan el panel (su hondura es la del panel) y lo que asoma la punta por detrás
		"marksThrough": count > 0 and Js.truthy(marks.get("through")),
		"marksBelowMm": float(marks.get("belowMm", 0.0)) if count > 0 else 0.0,
		"dentMm": float(dent.depthMm) if dent_on else null, "dentVisible": dent_on and Js.truthy(dent.visible),
		"through": punct != null and Js.truthy(punct.through), "punctureDepthUm": float(punct.depthUm) if punct != null else null,
		"normalJ": float(r.normalJ), "tearMm": float(tear.lengthMm) if tear != null else null, "slideM": float(r.slideM),
		"stays": Js.truthy(r.stays), "exitKmh": float(r.exitKmh), "mu": float(r.mu), "massKg": float(r.massKg),
		"sideWindow": _band_window(sw) if sw != null else null,
	}


## Lo que la banda del golpe mira de la ventanilla templada (side_window_impact o impact().sideWindow): si estalla y por
## qué, la fuerza de pico de cada apoyo y de cada garra, la que abre la grieta (null con una punta más blanda que el vidrio),
## la que la parte al flexar, los trocitos y la compresión de las caras con la que se ha calculado.
static func _band_window(sw: Dictionary) -> Dictionary:
	return {
		"shattered": Js.truthy(sw.shattered), "cause": sw.cause, "peakN": float(sw.peakN), "perClawN": float(sw.perClawN),
		"pierceN": float(sw.pierceN) if sw.pierceN != null else null, "bendN": float(sw.bendN),
		"fragmentMm": float(sw.fragmentMm), "fragments25": float(sw.fragments25), "sigmaS": float(sw.sigmaS),
	}


## La ventanilla templada en la banda del golpe (unidad 4m), con el valor central y los dos extremos: shattered, cause y
## sigmaS ({ value, lo, hi }: si estalla, por qué y con qué compresión de las caras), peakN, perClawN, pierceN (null con una
## punta más blanda que el vidrio), fragmentMm y fragments25 ({ value, min, max }) y bendN (la fuerza que la parte al
## flexar: no tiene banda).
static func _band_window_range(mid: Dictionary, lo: Dictionary, hi: Dictionary) -> Dictionary:
	var out := { "bendN": mid.bendN }
	for key: String in ["shattered", "cause", "sigmaS"]:
		out[key] = { "value": mid[key], "lo": lo[key], "hi": hi[key] }
	for key: String in ["peakN", "perClawN", "pierceN", "fragmentMm", "fragments25"]:
		out[key] = _band_range(mid, lo, hi, key)
	return out


## { value, min, max } de una magnitud con el valor central y los dos extremos (min y max contienen siempre al central);
## null si ninguno la tiene (una abolladura en el plástico); si solo alguno, los que no la tienen cuentan 0.
static func _band_range(mid: Dictionary, lo: Dictionary, hi: Dictionary, key: String) -> Variant:
	if mid[key] == null and lo[key] == null and hi[key] == null:
		return null
	var v := float(mid[key]) if mid[key] != null else 0.0
	var a := float(lo[key]) if lo[key] != null else 0.0
	var b := float(hi[key]) if hi[key] != null else 0.0
	return { "value": v, "min": minf(v, minf(a, b)), "max": maxf(v, maxf(a, b)) }


## Lo que el golpe no cambia entre los extremos: el animal (con la garra afilada y su masa sin las garras), el panel, las
## garras que golpean y la cinemática del golpe central (_kin, con el salto de r) y, en los velocirraptores, la de su salto
## con los datos más favorables (kin_hi). En la ventanilla templada (unidad 4m), además, la punta de las garras que golpean
## (claw_tip, como en impact) y el radio de su apoyo.
static func _band_ctx(p: Dictionary, r: Dictionary) -> Dictionary:
	var claw: Dictionary = ClawsV2.apply(p.claw)
	var body: Dictionary = body_of(claw)
	var iz: Dictionary = IMPACT_ZONES[String(p.get("zone", "techo"))]
	var inlay: Dictionary = inlay_of(p)
	claw = _sharpen(claw, inlay, p).claw
	var target: Dictionary = p.target
	var sex: Variant = sex_of(body, p)
	var kick := is_kicker(body)
	var leaper := is_leaper(body)
	var kind: String = body.kind
	var side: bool = iz.normal == "lado"
	var kin := _kin(p, r.get("leap"))
	var kin_hi := kin
	if leaper:
		kin_hi = _kin(p, _leap_of(p, true))
	var tempered: bool = Js.truthy(iz.get("tempered"))
	var model: Variant = p.get("model", "2.0")
	return {
		"claw": claw, "body": body, "iz": iz, "inlay": inlay, "target": target, "sex": sex, "kick": kick, "leaper": leaper,
		"kind": kind, "side": side, "glass": Js.truthy(iz.glass), "metal": is_metal(target), "model": model,
		"reforged": inlay.id != "none", "n": strike_claws_of(body), "patches": 1 if kick else (2 if side else _patches(kind)),
		"slide_mm": float(iz.slide_m) * 1000.0, "m_body": mass_of(claw, sex), "kin": kin, "kin_hi": kin_hi,
		"car_m": float(p.get("car_mass_kg", PARAMS.car_mass_kg.default)),
		"df": defense_force(claw, sex) if Js.truthy(p.get("defense")) else null,
		"tempered": tempered, "tip": claw_tip(claw, inlay, model) if tempered else {},
		"contact_mm": float(body.contact_mm) if tempered else 0.0,
		# unidad 4o: la zona (para la banda del hueco, CLEARANCE_BAND)
		"zone_id": String(p.get("zone", "techo")),
	}


## Los datos de un extremo de la banda. which: «lo» (todo a favor del coche) o «hi» (todo en contra); «value», los del
## golpe central salvo la fricción, que pone quien la llama (la del motor: impact().mu), para comprobar que _band_case
## reproduce impact().
static func _band_knobs(ctx: Dictionary, which: String) -> Dictionary:
	var hi := which == "hi"
	var central := which == "value"
	var k := {
		"mu": FRICTION.min if hi else (NAN if central else FRICTION.max), "hard_paint": which == "lo", "tear": which,
		"def": "value", "m_body": float(ctx.m_body), "leap": kick_leap_ms(), "bw": "value", "kin": ctx.kin,
		"sigma_s": float(Glazing.SIDE_WINDOW.frac.sigmaS), "clearance": float(ctx.iz.clearance_mm),
	}
	if not central:
		k.def = "max" if hi else "min"
		# unidad 4m: la ventanilla templada, con menos compresión en las caras en contra del coche (la grieta pide menos)
		k.sigma_s = float(TEMPER_SIGMA_MPA.min) if hi else float(TEMPER_SIGMA_MPA.max)
		# unidad 4o: el hueco bajo el capó, del más pequeño ensayado (a favor del capó: abolladura y punta más someras) al mayor
		var cb: Variant = CLEARANCE_BAND.get(String(ctx.zone_id))
		if cb != null:
			k.clearance = float(cb.max) if hi else float(cb.min)
	if ctx.kick and not central:
		var mb: Dictionary = ctx.body.mass_kg[String(ctx.sex)]
		k.m_body = float(mb.max) if hi else float(mb.min)
		k.leap = kick_leap_ms(hi)
		k.bw = "max" if hi else "min"
	if hi:
		k.kin = ctx.kin_hi
	return k


## Pintura del coche con la dureza del barniz más duro medido (PLOUGH.paint_h_max_mpa, Vodnick 2006): una copia del
## objetivo, con la capa de pintura y la dureza de la superficie cambiadas (el resto, igual).
static func _harder_paint(target: Dictionary) -> Dictionary:
	var t: Dictionary = target.duplicate(true)
	if not Js.truthy(t.get("paint")):
		return t
	var hv: float = float(PLOUGH.paint_h_max_mpa) / Contact.HV_MPA
	t.hv = hv
	var layers: Variant = t.get("layers")
	if layers is Dictionary and layers.get("film") is Dictionary:
		layers.film.hv = hv
	return t


## Un extremo de la banda del golpe: las cuentas de impact() con los datos de k (_band_knobs) en lugar de los centrales.
## Solo lo que mira la banda (band_point): sin el veredicto, el informe, lo que aguanta encima ni la rotura de las garras.
static func _band_case(ctx: Dictionary, k: Dictionary, sm0: Variant, punct0: Variant) -> Dictionary:
	var claw: Dictionary = ctx.claw
	var kin: Dictionary = k.kin
	var kick: bool = ctx.kick
	var glass: bool = ctx.glass
	var model: Variant = ctx.model
	var inlay: Dictionary = ctx.inlay
	var n: int = ctx.n
	var slide_mm: float = ctx.slide_mm
	# la pintura más dura, solo para las marcas: al rayar decide quién cede (r < 0,8: Tabor 1954, en Pintaude 2021); en la
	# punción del golpe la pintura es una película fina sobre la chapa o el plástico, y ese criterio no dice si la atraviesa
	var target: Dictionary = ctx.target
	var paint: Dictionary = _harder_paint(target) if Js.truthy(k.hard_paint) and not glass else target
	# la masa del golpe: la del animal más la de más de unas garras reforjadas (claw_mass_block, como en impact)
	var m_body: float = k.m_body
	var m := m_body
	var cm: Variant = claw_mass_block(claw, inlay, n, m_body)
	if cm != null:
		m += float(cm.addedKg)
	var mu_red: float = m * float(ctx.car_m) / (m + float(ctx.car_m))
	var vn: float = float(k.leap) if kick else float(kin.vn)
	var vt: float = kin.vt
	var per_claw: float = m * G / n
	var f_cap := kick_force_n(m_body, String(k.bw)) if kick else INF
	var e_n := 0.5 * mu_red * vn * vn
	# unidad 4o: el hueco bajo el panel del extremo (CLEARANCE_BAND) y, con él, hasta dónde llega la punta de unas garras que
	# lo atraviesan; si cambia y algo lo atraviesa en el golpe central, las marcas y la punción se rehacen con él
	var clearance: float = k.clearance
	var tip_room := INF if glass else room_um(target, clearance)
	var same_gap := clearance == float(ctx.iz.clearance_mm)
	# con la masa y la velocidad del golpe central, la punción es la del golpe central; y las marcas también, con la pintura
	# del motor y si cada garra aprieta con la misma fuerza
	var same_punct := not kick and vn == float(ctx.kin.vn) and (same_gap or punct0 == null or not Js.truthy(punct0.through))
	var df: Variant = ctx.df
	var sm: Variant = null
	if not kick:
		var per := per_claw
		var same_marks := not Js.truthy(k.hard_paint) and (same_gap or sm0 == null or not Js.truthy(sm0.get("through")))
		if df != null:
			per = maxf(float(df.perClaw[String(k.def)]), per_claw)
			same_marks = same_marks and per == maxf(float(df.perClaw.value), per_claw)
		if same_marks and sm0 != null:
			sm = sm0
		else:
			sm = _marks(claw, paint, glass, per, slide_mm, model, inlay, df != null, tip_room).summary
	var punct: Variant = null
	var punct_raw: Variant = null  # la punción del motor del extremo (null si se reutiliza la del golpe central)
	var claws_work_j := 0.0
	if not glass and vn > 0.0:
		if same_punct and punct0 != null:
			punct = punct0
		else:
			punct_raw = _band_puncture(ctx, target, vn, mu_red, per_claw, f_cap)
			punct = _puncture_block(punct_raw, claw, inlay, target, tip_room, model)
		claws_work_j = float(punct.workJ) * n
	var dent: Variant = null
	var crush_m := 0.0
	if not glass:
		var through: bool = punct != null and punct.through and not ctx.metal
		dent = dent_of(target, e_n, claws_work_j, int(ctx.patches), clearance, through, f_cap)
		# unidad 4p: el hueco compartido, como en impact() (con la punción del golpe central ya se compartió: la misma energía y
		# el mismo hueco dan la misma abolladura)
		var sg := _share_gap(punct_raw, claw, inlay, target, clearance, e_n, n, int(ctx.patches), f_cap, model, punct, dent, through)
		punct = sg.punct
		dent = sg.dent
		claws_work_j = sg.workJ
		crush_m = float(dent.depthMm) / 1000.0
	var f_patch := 0.0
	if dent != null and dent.applies:
		f_patch = float(dent.peakN)
	if kick and f_patch <= 0.0:
		f_patch = f_cap
	if kick:
		sm = _marks(claw, paint, glass, f_patch / n, slide_mm, model, inlay, false, tip_room).summary
	# el resbalón y el desgarro, con la fricción del extremo
	var mu: float = k.mu
	var vt1 := maxf(vt - mu * (mu_red / m) * vn, 0.0)
	var t_crush := 2.0 * crush_m / vn if vn > 0.0 and crush_m > 0.0 else 0.0
	if kick:
		t_crush = mu_red * vn / f_patch if f_patch > 0.0 else 0.0
	var mark_imp := 0.5 * (vt + vt1) * t_crush
	var slide_m: float = ctx.iz.slide_m
	var a_fr := mu * G
	var stays := false
	var mark_m := minf(mark_imp, slide_m)
	var v_exit := vt1
	if not ctx.side and not kick:
		var room := maxf(slide_m - mark_imp, 0.0)
		var d := vt1 * vt1 / (2.0 * a_fr)
		stays = d <= room
		mark_m = minf(mark_imp + d, slide_m)
		v_exit = 0.0 if stays else sqrt(maxf(vt1 * vt1 - 2.0 * a_fr * room, 0.0))
	var tear_mm: Variant = null
	if ctx.side and not kick and not glass and not ctx.metal and punct != null and punct.through:
		var tp: Variant = _tear_params(target, String(ctx.kind), claw, ctx.body, m, ctx.iz, df)
		if tp != null:
			var room := maxf(slide_m - mark_imp, 0.0)
			# la tenacidad y el anclaje del extremo: a favor del coche, el plástico más tenaz y el anclaje más flojo (se
			# suelta antes); en contra, al revés (la banda de _tear_block)
			var picks := { "value": ["value", "value"], "lo": ["max", "min"], "hi": ["min", "max"] }
			var pick: Array = picks[String(k.tear)]
			var run := tear_run(m, vt1, room, n, float(tp.tMm), float(tp.r[pick[0]]), float(tp.cap[pick[1]]))
			tear_mm = float(run.lengthM) * 1000.0
			if float(run.lengthM) > 0.0:
				mark_m = minf(mark_imp + float(run.lengthM), slide_m)
				v_exit = run.vExitMs
				sm = _tear_marks(sm, target, punct)
	var count := n if Js.truthy(sm.scratched) and mark_m > 0.0 else 0
	var dent_on: bool = dent != null and dent.applies
	# unidad 4m: la ventanilla templada con la compresión de las caras del extremo (k.sigma_s), como en impact()
	var sw: Variant = null
	if ctx.tempered:
		sw = _band_window(side_window_impact(vn, mu_red, float(ctx.contact_mm), int(ctx.patches), n, ctx.tip, f_cap, float(k.sigma_s)))
	return {
		"marksDepthUm": float(sm.depthUm) if count > 0 else 0.0, "marksCount": count,
		"marksLengthMm": mark_m * 1000.0 if count > 0 else 0.0,
		"marksThrough": count > 0 and Js.truthy(sm.get("through")),
		"marksBelowMm": float(sm.get("belowMm", 0.0)) if count > 0 else 0.0,
		"dentMm": float(dent.depthMm) if dent_on else null, "dentVisible": dent_on and Js.truthy(dent.visible),
		"through": punct != null and Js.truthy(punct.through), "punctureDepthUm": float(punct.depthUm) if punct != null else null,
		"normalJ": e_n, "tearMm": tear_mm, "slideM": mark_m, "stays": stays, "exitKmh": v_exit * KMH, "mu": mu, "massKg": m,
		"sideWindow": sw,
	}


## La punción de un extremo de la banda: la del motor en impact() (cada garra con su parte de la masa reducida y la velocidad
## normal; en la patada, no más honda que la estática con la fuerza máxima de la pata) sobre el objetivo tgt. Devuelve el
## resultado de Physics.compute: quien la llama le pone el tope del hueco (_puncture_block) y lo comparte con la abolladura
## (_share_gap, unidad 4p).
static func _band_puncture(ctx: Dictionary, tgt: Dictionary, vn: float, mu_red: float, per_claw: float, f_cap: float) -> Dictionary:
	var kick: bool = ctx.kick
	var claw: Dictionary = ctx.claw
	var n: int = ctx.n
	var sc := claw.duplicate(true)
	sc.strike = { "v": vn, "m": mu_red / n }
	var over := { "method": "puncion", "strike": true, "force": 0.0 if kick else per_claw, "model": ctx.model }
	if ctx.reforged:
		over["inlay"] = ctx.inlay
	var r := Physics.compute(_lab_params(sc, tgt, over))
	if kick:
		var over_st := { "method": "puncion", "strike": false, "force": f_cap, "model": ctx.model, "inlay": ctx.inlay }
		var r_st := Physics.compute(_lab_params(claw, tgt, over_st))
		if float(r_st.depthUm) < float(r.depthUm):
			r = r_st
	return r


## De dónde sale la banda del golpe, en palabras (con los datos que se mueven y los que no tienen banda).
static func band_source(ctx: Dictionary, varies: Array, fixed: Array) -> String:
	var parts: Array = []
	if varies.has("friccion"):
		parts.append("fricción de garras y almohadillas de %s a %s (Roderick et al. 2019; Derler & Gerhardt 2012)" % [
			CarFormat.num(float(FRICTION.min)), CarFormat.num(float(FRICTION.max))])
	if varies.has("pintura"):
		parts.append("dureza del barniz, en las marcas, de %s a %s MPa: del más blando medido (el del banco) al más duro (Vodnick 2006)" % [
			Js.to_fixed(float(Data.PAINT_FILM.hv) * Contact.HV_MPA, 0), CarFormat.num(float(PLOUGH.paint_h_max_mpa))])
	if varies.has("plastico"):
		var tb: Variant = ctx.target.get("body")
		var r: Variant = PLASTIC_TEAR.get(String(tb.id)) if tb != null else null
		if r != null:
			parts.append("tenacidad del plástico de %s a %s kJ/m² (SABIC 2024, Noryl GTX964) y lo que aguanta el animal con las garras clavadas, con su banda" % [
				CarFormat.num(float(r.min)), CarFormat.num(float(r.max))])
	if varies.has("defensa"):
		parts.append("la fuerza de defensa de cada garra, con su banda")
	if varies.has("casuario"):
		var mb: Dictionary = ctx.body.mass_kg[String(ctx.sex)]
		var fb: Dictionary = KICK.force_bw
		parts.append("masa de %s a %s kg (Grzimek 2003; Latch 2007), fuerza de la pata de %s a %s veces su peso (Portugal et al. 2016) y salto de hasta %s (Henry et al. 2005)" % [
			CarFormat.num(float(mb.min)), CarFormat.num(float(mb.max)), CarFormat.num(float(fb.min)), CarFormat.num(float(fb.max)),
			CarFormat.fmt_kmh(kick_leap_ms(true) * KMH)])
	if varies.has("salto"):
		var run: Dictionary = ctx.body.run_kmh
		parts.append("salto de hasta %s (Henry et al. 2005; Hutchinson et al. 2015) y carrera de hasta %s (Sellers & Manning 2007)" % [
			CarFormat.fmt_mps(kick_leap_ms(true), 2), CarFormat.fmt_kmh(float(run.get("max", run.value)))])
	if varies.has("templado"):
		parts.append("compresión de las caras de la ventanilla templada de %s a %s MPa (Achintha 2020): con más, la grieta que la revienta pide más fuerza y los trocitos salen más pequeños" % [
			CarFormat.num(float(TEMPER_SIGMA_MPA.min)), CarFormat.num(float(TEMPER_SIGMA_MPA.max))])
	if varies.has("hueco"):
		# unidad 4o: el hueco bajo el capó, con el caso medido de los ensayos de atropello
		var cb: Dictionary = CLEARANCE_BAND[String(ctx.zone_id)]
		parts.append("hueco %s de %s a %s mm, los ensayados bajo un capó (Fredriksson et al. 2007): con menos, la abolladura y la punta de unas garras que lo atraviesan topan antes con lo que hay debajo, que se queda el resto" % [
			String(PANEL_GAP_TXT.get(String(ctx.zone_id), "bajo el panel")), CarFormat.num(float(cb.min)), CarFormat.num(float(cb.max))])
	var txt := "Todo a favor del coche y todo en contra, con los datos que tienen banda: " + "; ".join(PackedStringArray(parts)) + "."
	var none: Array = []
	if fixed.has("pata"):
		none.append("la rigidez de la pata (%s N/mm, la del motor del banco: nadie la ha medido contra una chapa, y la de la pata al correr, que crece con la masa, Farley et al. 1993, no es la de un golpe; para el tigre y el oso es una cota baja) y su recorrido (%s mm, el orden de la flexión de las patas al aterrizar, sin medición)" % [
			CarFormat.num(float(Physics.MODEL.limbStiffness)), CarFormat.num(LIMB_STROKE_MM)])
	if fixed.has("hueco"):
		var why := String(CLEARANCE_FIXED.get(String(ctx.zone_id), "sin medición"))
		none.append("el hueco %s (%s mm), %s" % [String(PANEL_GAP_TXT.get(String(ctx.zone_id), "bajo el panel")),
			CarFormat.num(float(ctx.iz.clearance_mm)), why])
	if fixed.has("parabrisas"):
		none.append("la hoja de vidrio")
	if fixed.has("ventanilla"):
		var W: Dictionary = Glazing.SIDE_WINDOW
		none.append("la hoja de la ventanilla (%s mm de espesor y ~%s cm de radio equivalente, una estimación) y su resistencia a flexión (%s MPa, la de la norma EN 12150-1)" % [
			CarFormat.num(float(W.pane.t)), CarFormat.num(float(W.pane.a) / 10.0), CarFormat.num(float(W.pane.fgk))])
	if not none.is_empty():
		txt += " Sin banda: " + "; ".join(PackedStringArray(none)) + "."
	return txt


# ════════ Defensa: el animal asustado aprieta con toda su fuerza (unidad 4d) ════════

## Lo que hace un animal asustado, en modo defensa (p.defense), con las garras en una zona del coche: aprieta con
## defense_force y, donde su garra corta la superficie, la desgarra con el motor de siempre en modo desgarro (la garra
## curva tira como un gancho: Physics.tear_leverage) con la fuerza de cada garra, nunca menos que su parte del peso, a
## lo largo del panel. Se queda clavado si el desgarro entra en el plástico o raja la chapa (unas garras reforjadas).
## En el parabrisas, la queratina no raya el vidrio (r < 0,8) ni lo agrieta por contacto (Fracture: una punta más
## blanda se aplasta antes); unas garras reforjadas al menos tan duras como el vidrio lo rayan y pueden agrietarlo
## (Fracture.evaluate con Glazing.laminated_result), y la flexión de la hoja sigue siendo la de su peso. La fricción no
## cambia: sin nada que agarrar, la fuerza normal sigue siendo su peso; lo que sí cambia en un panel liso es el arado, si
## el desgarro es más hondo que la marca de reposo (setup lo añade con rake_n, en rakeN). per_patch_n y contact_mm: el
## peso de cada apoyo y su radio (el parabrisas). { forceN: { value, min, max } (por pie o mano), per, kind, perClawN (la
## que desgarra), perClawBand, tipAreaMm2, tipPressureMPa (fuerza de una garra entre el área de su punta),
## clawHardnessMPa, tipYields (la punta cede antes: la presión real no pasa de su dureza), tear (las marcas del desgarro,
## como scratch, con lengthMm), stuck, stuckIn («plastico», «chapa» o null), windshield (en el parabrisas; si no, null),
## verdict, vsub, quality, source }; setup le añade anchor, anchorN, restAnchor, restAnchorN y rakeN. null si el animal
## no tiene datos de defensa. room (unidad 4o): hasta dónde llega la punta de un desgarro que atraviesa el panel (room_um).
static func defense_block(
	claw: Dictionary, target: Dictionary, glass: bool, inlay: Dictionary, rest_per_claw: float, length_mm: float,
	model: Variant = "2.0", sex: Variant = null, per_patch_n: float = 0.0, contact_mm: float = 0.0, room: float = INF,
	tempered: bool = false
) -> Variant:
	var df: Variant = defense_force(claw, sex)
	if df == null:
		return null
	var per: float = maxf(float(df.perClaw.value), rest_per_claw)
	var mk := _marks(claw, target, glass, per, length_mm, model, inlay, true, room)
	var tear: Dictionary = mk.summary
	tear["lengthMm"] = length_mm if Js.truthy(tear.scratched) else 0.0
	var tip := claw_tip(claw, inlay, model)
	var area := float(claw.area)
	var p_tip := per / area if area > 0.0 else INF
	var h_claw: float = float(tip.hv) * Contact.HV_MPA
	var stuck_in: Variant = null if glass else _stuck_in(tear, target)
	var shield: Variant = null
	if glass and not tempered:  # unidad 4v: la luneta templada la decide setup (rear_window_verdict)
		var cracks := _glass_contact_cracks(claw, inlay, per * Physics.tear_leverage(claw), true, tear, model)
		shield = windshield_load(per_patch_n, contact_mm, cracks)
		shield["contactCracks"] = cracks
	var out := {
		"forceN": { "value": df.value, "min": df.min, "max": df.max }, "per": df.per, "kind": df.kind, "perClawN": per,
		"pcsaCm2": df.get("pcsaCm2"), "perClawBand": df.perClaw, "tipAreaMm2": area, "tipPressureMPa": p_tip, "clawHardnessMPa": h_claw,
		"tipYields": p_tip > h_claw, "tear": tear, "stuck": stuck_in != null, "stuckIn": stuck_in, "windshield": shield,
		"quality": df.quality, "source": df.source, "verdict": "", "vsub": "",
	}
	var v := _defense_verdict(out, target, inlay, String(GRAMMAR.get(String(claw.id), ["el", "o"])[1]))
	out["verdict"] = v.verdict
	out["vsub"] = v.vsub
	return out


## Unidad 4v: el veredicto del modo defensa en la luneta templada (rear: CarGlass.tempered_hold; d: el bloque de defensa).
## Estalla (y pierde el apoyo: el animal se cae o mete la pata dentro, y caen trocitos al habitáculo), la raya (una garra al
## menos 1,25 veces más dura) o ni la raya ni la rompe. { verdict, vsub }.
static func rear_window_verdict(rear: Dictionary, d: Dictionary, inlay: Dictionary) -> Dictionary:
	var who := "cada %s aprieta con ~%s" % [String(d.per), _fmt_n(float(d.forceN.value))]
	var one: bool = inlay.id == "none"
	var noun := "la queratina" if one else "las garras de %s" % String(ClawFracture.NOUNS.get(inlay.id, inlay.id))
	var n := "" if one else "n"
	var tear: Dictionary = d.tear
	if bool(rear.shattered):
		var how := "las garras abren la grieta que atraviesa el temple" if rear.cause == "grieta" else "su peso la parte"
		return { "verdict": "ESTALLA LA LUNETA", "vsub": "%s: %s y estalla en trocitos (pierde el apoyo y caen dentro del coche)" % [who, how] }
	if float(tear.depthUm) > 0.0:
		return { "verdict": "RAYA EL VIDRIO", "vsub": "%s: %s raya%s la luneta (~%s), sin romperla: un templado aguanta entero o estalla" % [who, noun, n, Format.fmt_len(tear.depthUm)] }
	return {
		"verdict": "NO RAYA EL VIDRIO",
		"vsub": "%s, pero %s no raya%s el vidrio ni abre%s la grieta del temple: la luneta aguanta entera" % [who, noun, n, n],
	}


## La fuerza de defensa en palabras: «aprieta con ~101 N por pie (~2523 MPa en la punta, más de lo que aguanta la
## queratina: la punta se aplasta y reparte)», y si las garras se clavan.
static func defense_txt(d: Dictionary) -> String:
	var txt := "aprieta con ~%s por %s (~%s MPa en la punta" % [_fmt_n(float(d.forceN.value)), String(d.per), Format.fmt_p(float(d.tipPressureMPa))]
	if Js.truthy(d.get("tipYields")):
		txt += ", más de lo que aguanta la garra: la punta se aplasta y reparte)"
	else:
		txt += ")"
	var where: Variant = d.get("stuckIn")
	if where == "plastico":
		txt += " · las garras se clavan en el plástico"
	elif where == "chapa":
		txt += " · las garras rajan la chapa y se quedan clavadas"
	return txt


## ¿Dónde se quedan clavadas unas garras que desgarran? En el plástico, si el desgarro pasa de la pintura; en la chapa,
## si la raja (solo unas garras reforjadas que cortan el metal). null si no se clavan.
static func _stuck_in(tear: Dictionary, target: Dictionary) -> Variant:
	if target.get("body") == null:
		return null
	if not is_metal(target):
		return "plastico" if Js.truthy(tear.get("reachesBody")) else null
	return "chapa" if String(tear.get("verdict", "")).begins_with("RAJA") else null


## Fuerza (N) para arrastrar UNA garra hundida depth_um en un surco de width_um de ancho arando lo que tiene delante
## (PLOUGH: Bowden & Tabor 1950, F = H·A): la sección de un surco en V, A = w·d/2, con la dureza de cada capa del perfil
## del motor (Physics.hardness_profile: la pintura hasta su espesor y la carrocería debajo). paint_h_mpa: la dureza de la
## pintura (NAN: la del motor). 0 si el objetivo no es un coche pintado o no hay surco.
static func plough_n(target: Dictionary, depth_um: float, width_um: float, paint_h_mpa: float = NAN) -> float:
	if target.get("body") == null or not Js.truthy(target.get("layers")) or depth_um <= 0.0 or width_um <= 0.0:
		return 0.0
	var prof := Physics.hardness_profile(target)
	var hf: float = prof.Hf if is_nan(paint_h_mpa) else paint_h_mpa
	var d := depth_um / 1000.0
	var w := width_um / 1000.0
	# el surco en V se estrecha con la profundidad: a z de la superficie mide w·(1 − z/d)
	var tp := minf(float(prof.t), d)
	var a_paint := w * (tp - tp * tp / (2.0 * d))
	return hf * a_paint + float(prof.Hs) * (0.5 * w * d - a_paint)


## Lo que sujeta de más, asustado, un animal con las garras hundidas en la pintura de un panel liso (N, todas juntas):
## { value, min, max, claws (las que aran), perClawN (arado del surco del desgarro, por garra), restPerClawN (el del surco
## de reposo), limitN (lo que aguanta de lado cada garra reforjada; null sin tope), limited (ese tope manda), quality,
## source } o null (sin coche pintado). Para arrastrarlo hacia atrás, las garras que tiran hacia atrás, la mitad (el dedo
## delantero de cada pie de un ave, que aprieta contra el trasero; las de las manos de un mamífero), tienen que arar
## pintura nueva por el surco del desgarro (plough_n), cada una como mucho con su fuerza de defensa (per_claw: { value,
## max }) y, si es reforjada, con lo que aguanta de lado con la carga en el surco (ClawFracture.lateral_limit_n en
## load_point_mm); las otras resbalan por su propio surco. En reposo, todas araban su surco de reposo, y eso ya va en la
## fricción μ·N: el anclaje es la diferencia, claws·arado del desgarro − contact·arado de reposo (tear y rest, los dos del
## motor), nunca negativa (asustado puede hacer lo mismo que en reposo). Banda (PLOUGH): la baja, 0; la alta, con la
## pintura más dura medida (y nunca por debajo del valor central).
static func rake_n(
	claw: Dictionary, inlay: Dictionary, target: Dictionary, rest: Dictionary, tear: Dictionary, per_claw: Dictionary,
	n_contact: int, model: Variant = "2.0"
) -> Variant:
	if target.get("body") == null or not Js.truthy(target.get("layers")):
		return null
	var d := float(tear.depthUm)
	var w := float(tear.widthUm)
	var hx: float = PLOUGH.paint_h_max_mpa
	var def_v := plough_n(target, d, w)
	var def_x := plough_n(target, d, w, hx)
	var rest_v := plough_n(target, float(rest.depthUm), float(rest.widthUm))
	var rest_x := plough_n(target, float(rest.depthUm), float(rest.widthUm), hx)
	var lat_v := INF
	var lat_x := INF
	var s: Variant = ClawFracture.strength(inlay)
	var sheet: Variant = Physics.sheet_of(target)
	if s != null and sheet != null and d > 0.0:
		var tip := claw_tip(claw, inlay, model)
		var x0 := load_point_mm(sheet, d / 1000.0)
		lat_v = ClawFracture.lateral_limit_n(tip, float(tip.reach), float(s.value), x0)
		lat_x = ClawFracture.lateral_limit_n(tip, float(tip.reach), float(s.max), x0)
	var hooks := floori(float(n_contact) / 2.0)
	var h := float(hooks)
	var n := float(n_contact)
	var free_v := minf(def_v, float(per_claw.value))
	var val := maxf(h * minf(free_v, lat_v) - n * rest_v, 0.0)
	var top := maxf(maxf(h * minf(minf(def_x, float(per_claw.max)), lat_x) - n * rest_x, 0.0), val)
	return {
		"value": val, "min": 0.0, "max": top, "claws": hooks, "perClawN": def_v, "restPerClawN": rest_v,
		"limitN": lat_v if is_finite(lat_v) else null, "limited": lat_v < free_v,
		"quality": PLOUGH.quality, "source": PLOUGH.source,
	}


## ¿Agrietan unas garras reforjadas el parabrisas por contacto? El modelo de la unidad 1f (Fracture.evaluate) sobre
## Glazing.WINDSCREEN con la carga normal de una garra (force_n), su surco (summary: profundidad y anchura) y la fricción
## del vidrio. Solo una punta al menos tan dura como el vidrio puede (la queratina, nunca).
static func _glass_contact_cracks(
	claw: Dictionary, inlay: Dictionary, force_n: float, sliding: bool, summary: Dictionary, model: Variant = "2.0"
) -> bool:
	if inlay.id == "none" or force_n <= 0.0:
		return false
	var tip := claw_tip(claw, inlay, model)
	var tool := { "hv": tip.hv, "E": tip.E }
	var fr: Variant = Fracture.evaluate(
		tool, tip, Glazing.WINDSCREEN, force_n, sliding, float(Glazing.WINDSCREEN.mu), float(summary.get("depthUm", 0.0)),
		float(summary.get("widthUm", 0.0)) / 2.0
	)
	return fr != null and Js.truthy(fr.cracks)


## Veredicto del modo defensa: { verdict, vsub }.
## o: la terminación del animal («a» si es femenino: el águila se queda clavada).
static func _defense_verdict(d: Dictionary, target: Dictionary, inlay: Dictionary, o: String = "o") -> Dictionary:
	var who := "cada %s aprieta con ~%s" % [String(d.per), _fmt_n(float(d.forceN.value))]
	var one: bool = inlay.id == "none"  # «la queratina» o «las garras de …» (el verbo concuerda)
	var noun := "la queratina" if one else "las garras de %s" % String(ClawFracture.NOUNS.get(inlay.id, inlay.id))
	var n := "" if one else "n"
	var tear: Dictionary = d.tear
	var shield: Variant = d.windshield
	if shield != null:
		if shield.cracked:
			var how := "las garras lo agrietan al rayarlo" if Js.truthy(shield.get("contactCracks")) else "su peso lo agrieta"
			return { "verdict": "AGRIETA EL PARABRISAS", "vsub": "%s: %s (el laminado no cae)" % [who, how] }
		if float(tear.depthUm) > 0.0:
			return { "verdict": "RAYA EL VIDRIO", "vsub": "%s: %s raya%s el vidrio (~%s), sin agrietarlo" % [who, noun, n, Format.fmt_len(tear.depthUm)] }
		return {
			"verdict": "NO RAYA EL VIDRIO",
			"vsub": "%s, pero %s no raya%s el vidrio ni lo agrieta%s por contacto: el parabrisas solo nota su peso" % [who, noun, n, n],
		}
	if d.stuck:
		var where := "se clavan en el plástico" if d.stuckIn == "plastico" else "rajan la chapa"
		var deep := "~%s de hondo" % Format.fmt_len(tear.depthUm)
		if Js.truthy(tear.get("through")):
			# unidad 4o: de lado a lado, tan hondo como el panel (la punta sigue por detrás)
			where = "atraviesan el plástico" if d.stuckIn == "plastico" else "rajan la chapa de lado a lado"
			deep = "%s con la pintura" % CarFormat.fmt_panel(float(tear.depthUm))
		return {
			"verdict": "SE QUEDA CLAVAD%s" % o.to_upper(),
			"vsub": "%s: las garras %s (%s)" % [who, where, deep],
		}
	var paint_um: float = Data.PAINT_LAYERS[-1].to
	if Js.truthy(tear.reachesBody) and is_metal(target):
		if float(tear.depthUm) > paint_um + 1.0:
			return {
				"verdict": "DESGARRA EL METAL",
				"vsub": "%s: desgarra la pintura y ~%s de la chapa" % [who, Format.fmt_len(float(tear.depthUm) - paint_um)],
			}
		return {
			"verdict": "DESGARRA HASTA EL METAL",
			"vsub": "%s: desgarra la pintura hasta el metal, sin cortarlo: %s no corta%s el %s" % [who, noun, n, target.body.long],
		}
	if Js.truthy(tear.scratched):
		return { "verdict": "DESGARRA LA PINTURA", "vsub": "%s: desgarra la pintura (~%s)" % [who, Format.fmt_len(tear.depthUm)] }
	return { "verdict": "APENAS DEJA MARCA", "vsub": who }


## Balance de energía del golpe (primer principio), en J. La energía cinética del animal respecto al coche,
## ½·m·v_rel², se reparte en:
##   - garras: trabajo de punción de las garras (el motor: Physics.compute, punción con golpe);
##   - chapa: trabajo plástico de la abolladura (unidad 1f: Dent) · vidrio: lo que almacena la hoja hasta agrietarse,
##     U = F²/2k (FISICA.md §15), si se agrieta · en un panel de plástico (metal = false), que no se abolla, nada, con su
##     nombre («Plástico (no se abolla)», unidad 4o);
##   - animal: el resto de la energía normal que se disipa, ½·μ_red·v_n²: patas, cuerpo y rebote (y en el parabrisas, la
##     lámina de PVB que lo sujeta); estimación;
##   - coche: ½·(m − μ_red)·v_n², la parte de la normal que no se disipa: empuja al coche (conservación del momento);
##   - rozamiento: ½·m·(v_t² − v_salida²), el trabajo de la fricción al deslizar (las marcas), que acaba en calor;
##   - salida: ½·m·(v_salida² + v_aleja²), la que se lleva el animal al salir del panel (cae o sale volando).
## Si la abolladura llega al fondo, el resto también se lo lleva lo que hay debajo del panel (motor, barra de la puerta).
## tear_j (unidad 4g): lo que se lleva el desgarro de unas garras trabadas que rajan el plástico en un costado,
## ½·m·(v_t1² − v_salida²), del tramo tangencial: sale del rozamiento y va al término de las garras, que pasa a ser la
## punción y el desgarro (clawsJ = punctureJ + tearJ; la normal que se disipa sigue siendo punctureJ + panelJ + animalJ).
## Los términos suman el total (el test lo comprueba). { totalJ, terms: [{ id, name, short, j, share, quality, source }] }
## con un campo por término (clawsJ, panelJ, animalJ, carJ, frictionJ, exitJ) para leerlos sin recorrer la lista, más
## punctureJ y tearJ (las dos partes de clawsJ).
static func energy_balance(
	m: float, mu_red: float, vn: float, vt: float, v_exit: float, away: float, claws_work_j: float, dent: Variant,
	shield: Variant, tear_j: float = 0.0, side_window: Variant = null, metal: bool = true
) -> Dictionary:
	var e_n := 0.5 * mu_red * vn * vn
	var claws := clampf(claws_work_j, 0.0, e_n)
	var panel := 0.0
	var glass := shield != null
	if side_window != null:
		# unidad 4m: la ventanilla templada solo se queda lo que la carga hasta estallar (U = F²/2k); si aguanta, se lo devuelve
		panel = minf(float(side_window.glassJ), e_n - claws)
	elif glass:
		if shield.cracked:
			panel = minf(float(shield.glassJ), e_n - claws)
	elif dent != null and dent.applies:
		panel = minf(float(dent.panelJ), e_n - claws)
	var animal := maxf(e_n - claws - panel, 0.0)
	var bottoms: bool = dent != null and dent.applies and dent.bottomsOut
	var car := 0.5 * (m - mu_red) * vn * vn
	var fric_all := 0.5 * m * maxf(vt * vt - v_exit * v_exit, 0.0)
	var tear := clampf(tear_j, 0.0, fric_all)
	var fric := fric_all - tear
	var leave := 0.5 * m * (v_exit * v_exit + away * away)
	var total := 0.5 * m * (vn * vn + vt * vt + away * away)
	var claws_row := ["garras", "Garras (punción)", "garras", claws, "secondary", SRC_PUNCTURE]
	if tear > 0.0:
		claws_row = ["garras", "Garras (punción y desgarro del plástico)", "garras", claws + tear, "estimate",
			"punción: " + SRC_PUNCTURE + "; desgarro: R·t por garra a lo largo del plástico rajado, con R la resiliencia con entalla de la ficha de SABIC (estimación: " + SRC_SABIC_GTX964 + ")"]
	var rows := [
		claws_row,
		["vidrio" if glass else "chapa", _panel_name(glass, metal), "parabrisas" if glass else ("chapa" if metal else "plástico"),
			panel, "secondary", SRC_GLASS_FLEX if glass else SRC_DENT],
		["animal", _rest_name(glass, bottoms), "animal", animal, "estimate",
			"resto de la energía normal que se disipa: patas, cuerpo y rebote%s; sin medición" % _rest_extra(glass, bottoms)],
		["coche", "Empujón al coche", "coche", car, "secondary", "conservación del momento en un choque plástico: ½·(m − μ_red)·v_n²"],
		["rozamiento", "Rozamiento de las marcas (calor)", "calor", fric, "secondary", "trabajo de la fricción de Coulomb con la μ del motor"],
		["salida", "Se la lleva al salir", "al salir", leave, "secondary", "energía cinética del animal respecto al coche al salir del panel"],
	]
	if side_window != null:
		rows[1] = _window_energy_row(side_window, panel)
		rows[2] = _window_rest_row(side_window, animal)
	var terms: Array = []
	for row: Array in rows:
		var j: float = row[3]
		terms.append({
			"id": row[0], "name": row[1], "short": row[2], "j": j, "share": j / total if total > 0.0 else 0.0,
			"quality": row[4], "source": row[5],
		})
	return {
		"totalJ": total, "terms": terms, "clawsJ": claws + tear, "panelJ": panel, "animalJ": animal, "carJ": car,
		"frictionJ": fric, "exitJ": leave, "punctureJ": claws, "tearJ": tear,
	}


## El nombre del término del panel: el parabrisas hasta agrietarse, la abolladura de la chapa o, en un panel de plástico,
## que no se abolla (se hunde y recupera: no se queda nada), «Plástico (no se abolla)» en vez de «Chapa» (unidad 4o).
static func _panel_name(glass: bool, metal: bool) -> String:
	if glass:
		return "Parabrisas (hasta agrietarse)"
	return "Chapa (abolladura)" if metal else "Plástico (no se abolla)"


static func _rest_name(glass: bool, bottoms: bool) -> String:
	if glass:
		return "Animal y lámina del parabrisas (resto)"
	return "Animal y lo que hay bajo la chapa (resto)" if bottoms else "Animal (patas, cuerpo y rebote)"


static func _rest_extra(glass: bool, bottoms: bool) -> String:
	if glass:
		return " y la lámina de PVB"
	return " y, con la abolladura en el fondo, lo que hay debajo del panel" if bottoms else ""


## Abolladura del golpe con el modelo de la unidad 1f (Dent.strike, por apoyo). e_n_j: energía normal del golpe (J);
## claws_work_j: la que se han quedado las garras al clavarse; patches: apoyos que reparten el golpe. Cada apoyo es el
## muelle de la pata (Physics.MODEL.limbStiffness) contra la chapa; si ese muelle llegara más allá de su recorrido
## (LIMB_STROKE_MM), hace tope y lo que no cabe en él abolla la chapa. En el plástico no hay abolladura: se hunde y
## recupera (y lo perforado no cuenta: Dent.evaluate hace lo mismo). f_cap (N): fuerza máxima que transmite cada apoyo
## (la pata que patea del casuario, KICK); con tope, la pata cede a esa fuerza y no hace tope de recorrido: la chapa no pasa
## de δ(f_cap) (Dent.strike) y lo que sobra se lo queda la pata. Sin tope (INF), lo de siempre.
## { applies, depthMm, visible, bottomsOut, peakN (por apoyo), collapseN, patches, limbSaturated, panelJ, recovers,
##   capped (la fuerza llegó al tope) }.
static func dent_of(
	target: Dictionary, e_n_j: float, claws_work_j: float, patches: int, clearance_mm: float, through: bool,
	f_cap: float = INF
) -> Dictionary:
	var panel: Variant = Dent.panel_of(target)
	if panel == null or through:
		return {
			"applies": false, "depthMm": 0.0, "visible": false, "bottomsOut": false, "peakN": 0.0, "collapseN": null,
			"patches": patches, "limbSaturated": false, "panelJ": 0.0, "recovers": not is_metal(target) and not through,
			"capped": false,
		}
	var sigma: float = panel.sigma
	var t: float = panel.t
	var k: float = Physics.MODEL.limbStiffness  # N/mm, cada apoyo
	var e_mj := maxf(e_n_j - claws_work_j, 0.0) / float(patches) * 1000.0
	var r := Dent.strike(sigma, t, e_mj, k, f_cap)
	var depth: float = r.depthMm
	var peak: float = r.peakN
	var saturated := is_inf(f_cap) and peak / k > LIMB_STROKE_MM
	if saturated:
		var limb_mj := 0.5 * k * LIMB_STROKE_MM * LIMB_STROKE_MM
		depth = Dent.depth_for_energy(sigma, t, e_mj - limb_mj)
		peak = maxf(Dent.load_at(sigma, t, depth), k * LIMB_STROKE_MM)
	var shown := minf(depth, clearance_mm)
	return {
		"applies": true, "depthMm": shown, "visible": shown >= Dent.VISIBLE_MM, "bottomsOut": depth > clearance_mm,
		"peakN": peak, "collapseN": r.collapseN, "patches": patches, "limbSaturated": saturated,
		"panelJ": Dent.energy_mj(sigma, t, shown) * float(patches) / 1000.0, "recovers": false,
		"capped": is_finite(f_cap) and peak >= f_cap - 1e-6,
	}


## Parabrisas laminado con el modelo de la unidad 1f (Glazing.WINDSCREEN y Glazing.laminated_result). La hoja flexa como
## la ventana (Physics.pane_break, con el apoyo de radio contact_mm); la fuerza de pico de cada apoyo sale de la masa
## contra la hoja y la pata en serie, como en el apartado 15 de FISICA.md. energy_j: energía del golpe (0 si solo pesa).
## { peakN (por apoyo), bendN, cracked, penetrationRisk, penetrationJ, energyJ, glassJ (lo que almacena la hoja hasta
## agrietarse, U = F²/2k) }. Se agrieta, pero el PVB lo sujeta: no cae. contact_cracks: unas garras reforjadas lo
## agrietan por contacto (_glass_contact_cracks); la queratina, nunca.
static func windshield_impact(
	vn_ms: float, mass_kg: float, contact_mm: float, patches: int, contact_cracks: bool = false
) -> Dictionary:
	var W: Dictionary = Glazing.WINDSCREEN
	var pb := Physics.pane_break(W.pane, W.E, contact_mm)
	var k_patch := 1.0 / (1.0 / (float(pb.k) / float(patches)) + 1.0 / float(Physics.MODEL.limbStiffness))  # N/mm
	var per := vn_ms * sqrt(mass_kg / float(patches) * k_patch * 1000.0)
	var energy := 0.5 * mass_kg * vn_ms * vn_ms
	var lam := Glazing.laminated_result(W, per, pb.F, contact_cracks, energy)
	var glass_j := float(pb.U) / 1000.0
	if contact_cracks and per < float(pb.F):
		# agrietado por contacto antes de llegar a la flexión que lo parte: la hoja solo almacena F²/2k con su fuerza
		glass_j = per * per / (2.0 * float(pb.k)) / 1000.0
	return {
		"peakN": per, "bendN": pb.F, "cracked": lam.cracked, "penetrationRisk": lam.penetrationRisk,
		"penetrationJ": lam.penetrationJ, "energyJ": energy, "glassJ": glass_j,
	}


## El parabrisas con un animal quieto encima: el peso de cada apoyo contra la fuerza que lo agrieta (y, con
## contact_cracks, unas garras reforjadas que lo agrietan por contacto).
static func windshield_load(per_patch_n: float, contact_mm: float, contact_cracks: bool = false) -> Dictionary:
	var W: Dictionary = Glazing.WINDSCREEN
	var pb := Physics.pane_break(W.pane, W.E, contact_mm)
	var lam := Glazing.laminated_result(W, per_patch_n, pb.F, contact_cracks, 0.0)
	return { "loadN": per_patch_n, "bendN": pb.F, "cracked": lam.cracked }


# ════════ La ventanilla templada en el golpe (unidad 4m) ════════

## Altura (m) sobre la carretera de la línea de cintura, donde empieza la ventanilla: el pie del parabrisas, el borde del capó
## (HOOD_EDGE_M; which: «value», «min» o «max») más lo que sube el capó del modelo. WINDOW_SILL_SOURCE.
static func window_sill_m(which: String = "value") -> float:
	var hood: Dictionary = IMPACT_ZONES.capo
	return float(HOOD_EDGE_M.get(which, HOOD_EDGE_M.value)) + float(hood.slide_m) * V8.js_sin(float(hood.slope_deg) * PI / 180.0)


## Altura (m) del borde de arriba de la ventanilla: el techo de la berlina de base (ROOF_M), una cota alta (el marco está unos
## centímetros por debajo).
static func window_top_m() -> float:
	return float(ROOF_M.value)


## ¿Llega a la ventanilla? Su apoyo (contact_mm de BODIES) tiene que caer en la luna, con el centro por encima de la cintura
## (window_sill_m): por debajo golpearía la puerta. Lo más alto a lo que llega:
##   - un ave, volando: a cualquier altura (también llega al techo);
##   - un velocirraptor, saltando: los pies en lo alto del salto, leap_reach_m (1,19 m; con los datos más favorables, 1,79),
##     donde ya no sube ni baja y golpea con su carrera;
##   - el tigre y el oso, a cuatro patas: lo de arriba de su cuerpo, con el centro del apoyo un radio por debajo de la cruz
##     (WITHERS_M);
##   - el casuario patea lo que tiene a la altura de las patas (KICK_ZONES): no (WINDOW_KICK_REASON).
## { reaches, how («vuela», «salta», «cruz» o «patea»), hitM (el centro del apoyo; null si vuela), hitMinM, hitMaxM (con los
##   datos más desfavorables y los más favorables), sillM, topM, contactMm, reason ("" si llega), quality, source }.
static func window_reach(claw: Dictionary, body: Variant = null) -> Dictionary:
	var b: Variant = body if body != null else body_of(claw)
	var sill := window_sill_m()
	var out := {
		"reaches": false, "how": "", "hitM": null, "hitMinM": null, "hitMaxM": null, "sillM": sill, "topM": window_top_m(),
		"contactMm": float(b.get("contact_mm", 0.0)) if b != null else 0.0, "reason": "", "quality": WINDOW_SILL_SOURCE.quality,
		"source": WINDOW_SILL_SOURCE.source,
	}
	if b == null:
		out.reason = "sin datos de este animal"
		return out
	if is_kicker(b):
		out.how = "patea"
		out.reason = WINDOW_KICK_REASON % CarFormat.fmt_m(leap_reach_m(), 2)
		out.source = String(KICK.work_j_per_kg.source) + "; " + SRC_NAISH
		return out
	if b.kind == "ave":
		out.how = "vuela"
		out.reaches = true
		out.source = "vuela: llega a cualquier altura · " + String(WINDOW_SILL_SOURCE.source)
		return out
	var r_m := float(out.contactMm) / 1000.0
	if is_leaper(b):
		out.how = "salta"
		out.hitM = leap_reach_m()
		out.hitMinM = leap_reach_m()
		out.hitMaxM = leap_reach_m(true)
		out.quality = KICK.work_j_per_kg.quality
		out.source = "salto: " + String(KICK.work_j_per_kg.source) + "; " + String(KICK.muscle_fraction.source) + " · cintura: " + String(WINDOW_SILL_SOURCE.source)
	else:
		var wh: Variant = WITHERS_M.get(String(claw.id))
		if wh == null:
			out.reason = "sin la altura a la cruz de este animal"
			return out
		out.how = "cruz"
		out.hitM = float(wh.value) - r_m
		out.hitMinM = float(wh.min) - r_m
		out.hitMaxM = float(wh.max) - r_m
		out.quality = String(wh.quality)
		out.source = "cruz: " + String(wh.source) + " · cintura: " + String(WINDOW_SILL_SOURCE.source)
		if float(out.hitM) < sill:
			out.reason = WINDOW_LOW_REASON % [CarFormat.fmt_m(float(wh.value), 2), CarFormat.fmt_m(float(wh.min), 2),
				CarFormat.fmt_m(float(wh.max), 2), CarFormat.fmt_m(sill, 2), CarFormat.num(Js.js_round(float(out.contactMm))),
				" (con los datos más favorables, llegaría)" if float(out.hitMaxM) >= sill else ""]
			return out
	out.reaches = float(out.hitM) >= sill
	if not out.reaches:
		out.reason = "con su salto los pies suben ~%s y la ventanilla empieza a ~%s" % [CarFormat.fmt_m(float(out.hitM), 2), CarFormat.fmt_m(sill, 2)]
	return out


## El golpe contra la ventanilla templada: como el parabrisas del coche (windshield_impact) y como el banco (Physics.compute con
## Glazing.SIDE_WINDOW). La hoja flexa como una placa apoyada (Physics.pane_break, con el apoyo de radio contact_mm) y la fuerza
## de pico de cada apoyo sale de su masa contra la hoja y la pata en serie, F = v_n·√(m_apoyo·k) (FISICA.md §15); f_cap: el
## tope de la fuerza de un apoyo (INF: ninguno). Cada garra que golpea lleva F·apoyos/garras: si su punta es al menos tan dura
## como el vidrio (tip.hv: claw_tip), puede abrir la grieta que atraviesa la capa comprimida con menos fuerza de la que parte la
## hoja al flexar (Glazing.tempered_result, con el semiángulo de la punta, tip.tanA). Pura y determinista.
## { peakN (por apoyo), perClawN, bendN, pierceN (null si la punta es más blanda que el vidrio), shapePierceN (la carga con
##   la que una punta dura de esa forma abriría la grieta, aunque esta no lo sea), hardTip, tipHv, glassHv,
##   shattered, cause («flexión», «grieta» o null), compressionMm, fragmentMm, fragments25, glassJ (lo que se queda la hoja
##   hasta estallar, U = F²/2k; 0 si aguanta: se lo devuelve al animal), temperJ (la energía guardada en el temple, que se
##   libera al estallar: no sale del animal), energyJ (½·m·v_n² del golpe), sigmaS (la compresión de las caras, MPa) }.
## sigma_s: la compresión de las caras (MPa) en lugar de la de Glazing.SIDE_WINDOW (NAN: la suya), para la banda del golpe
## (TEMPER_SIGMA_MPA); cambia la grieta que la revienta y los trocitos, no la flexión.
static func side_window_impact(
	vn_ms: float, mass_kg: float, contact_mm: float, patches: int, n_claws: int, tip: Dictionary, f_cap: float = INF,
	sigma_s: float = NAN
) -> Dictionary:
	var W: Dictionary = Glazing.SIDE_WINDOW
	if not is_nan(sigma_s) and sigma_s != float(W.frac.sigmaS):
		W = W.duplicate(true)
		W.frac.sigmaS = sigma_s
	var pb := Physics.pane_break(W.pane, W.E, contact_mm)
	var k_plate := float(pb.k)
	var k_patch := 1.0 / (1.0 / (k_plate / float(patches)) + 1.0 / float(Physics.MODEL.limbStiffness))  # N/mm
	var per := minf(vn_ms * sqrt(mass_kg / float(patches) * k_patch * 1000.0), f_cap)
	var per_claw := per * float(patches) / float(maxi(n_claws, 1))
	var tip_hv := float(tip.hv)
	var hard := tip_hv / float(W.hv) >= 1.0
	var tr := Glazing.tempered_result(W, per, float(pb.F), hard, per_claw, float(tip.tanA))
	var glass_j := 0.0
	if tr.cause == "flexión":
		glass_j = float(pb.U) / 1000.0
	elif tr.cause == "grieta":
		# la grieta llega antes que la flexión que la parte: la hoja solo tiene lo que la cargó hasta ese instante
		var f_at := minf(per, float(tr.pierceN) * float(maxi(n_claws, 1)) / float(patches))
		glass_j = f_at * f_at / (2.0 * k_plate) / 1000.0
	var pane: Dictionary = W.pane
	var volume_m3 := PI * float(pane.a) * float(pane.a) * float(pane.t) * 1e-9
	return {
		"peakN": per, "perClawN": per_claw, "bendN": pb.F, "pierceN": tr.pierceN if hard else null,
		"shapePierceN": tr.pierceN, "hardTip": hard,
		"tipHv": tip_hv, "glassHv": float(W.hv), "shattered": tr.shattered, "cause": tr.cause,
		"compressionMm": tr.compressionMm, "fragmentMm": tr.fragmentMm, "fragments25": tr.fragments25, "glassJ": glass_j,
		"temperJ": float(tr.energyDensity) * volume_m3, "energyJ": 0.5 * mass_kg * vn_ms * vn_ms, "sigmaS": float(W.frac.sigmaS),
	}


## El bloque sideWindow del golpe: side_window_impact con la ventanilla que golpea (pane: WINDOW_PANE; la vista la cuartea y
## hace caer sus trocitos), su calidad y su fuente legible.
static func side_window_block(sw: Dictionary) -> Dictionary:
	var out := sw.duplicate()
	out["pane"] = WINDOW_PANE
	out["paneSource"] = WINDOW_PANE_SOURCE.source
	out["quality"] = "estimate"
	out["source"] = side_window_source()
	return out


## La fuente de la ventanilla en palabras (con los números de Glazing.SIDE_WINDOW, que viven allí).
static func side_window_source() -> String:
	var W: Dictionary = Glazing.SIDE_WINDOW
	var pane: Dictionary = W.pane
	var frac: Dictionary = W.frac
	return "vidrio templado de %s mm, el de las ventanillas de Europa y Japón (just-auto); resistencia a flexión %s MPa (EN 12150-1, vía Saint-Gobain 2018); compresión de las caras ~%s MPa (estimación dentro de los 80-150 MPa medidos en templados comerciales, Achintha 2020, y de los 40-400 trozos por cada 5 × 5 cm que exige la CEPE R43); capa comprimida del 21 %% del espesor y tamaño de los trozos (Nielsen, Schneider & Kraus 2022); la hoja flexa como una placa redonda apoyada (Roark), de ~%s cm de radio equivalente (estimación); la fuerza de pico, la del cuerpo contra la hoja y la pata en serie, como en el parabrisas y en el banco (la rigidez de la pata es una estimación: caso medido más parecido, Farley et al. 1993)" % [
		CarFormat.num(float(pane.t)), CarFormat.num(float(pane.fgk)), CarFormat.num(float(frac.sigmaS)), CarFormat.num(float(pane.a) / 10.0)]


## El salto de un velocirraptor hasta la ventanilla (para leap_block en el golpe contra la luna): salta para llegar y golpea en
## lo alto del salto, donde ya no sube ni baja, con la velocidad de su carrera (sin el aire, como leap_reach_m). Lo más alto
## del salto (apexM) es donde golpea (panelM): no baja nada; y tarda lo que tarda en subir, timeS = v_salto/g (lo usa
## kinematics). Con los datos centrales del salto también en la banda del golpe: saltar más no lo lleva más deprisa contra
## la luna, que está de lado (la banda mueve su carrera). { window, sillM, hitM, apexM, panelM, timeS }.
static func window_leap_fields() -> Dictionary:
	var hit := leap_reach_m()
	return {
		"window": true, "sillM": window_sill_m(), "hitM": hit, "apexM": hit, "panelM": hit, "timeS": kick_leap_ms() / G,
	}


## El salto hasta la ventanilla en palabras (la fila Salto del informe): «corre a ~39 km/h y salta para llegar a la ventanilla:
## sus pies suben ~1.19 m, por encima de la cintura (~0.89 m), y golpea en lo alto del salto con la velocidad de su carrera».
static func window_leap_txt(l: Dictionary) -> String:
	var run := "corre a ~%s" % CarFormat.fmt_kmh(float(l.runKmh))
	if Js.truthy(l.get("runCapped")) and CarFormat.kmh_txt(float(l.runAskedKmh)) != CarFormat.kmh_txt(float(l.runMaxKmh)):
		run = "corre como mucho a ~%s, lo más que corre (se pidieron %s)" % [CarFormat.fmt_kmh(float(l.runMaxKmh)),
			CarFormat.kmh_txt(float(l.runAskedKmh))]
	return "%s y salta para llegar a la ventanilla: sus pies suben ~%s, por encima de la cintura (~%s), y golpea en lo alto del salto con la velocidad de su carrera" % [
		run, CarFormat.fmt_m(float(l.hitM), 2), CarFormat.fmt_m(float(l.sillM), 2)]


## Los trocitos en palabras: «~91 trocitos de ~5.6 mm por cada 5 × 5 cm, romos y sin filo».
static func window_bits_txt(sw: Dictionary) -> String:
	return "~%s trocitos de ~%s por cada 5 × 5 cm, romos y sin filo" % [
		CarFormat.num(Js.js_round(float(sw.fragments25))), CarFormat.fmt_long(float(sw.fragmentMm) * 1000.0)]


## «las garras de diamante», «la queratina» o «las garras de película» (la punta que golpea la luna).
static func _window_tip_noun(r: Dictionary) -> String:
	var id := String(r.get("inlay", "none"))
	if id != "none":
		return "las garras de " + String(ClawFracture.NOUNS.get(id, id))
	return "las garras de película" if Js.truthy(r.get("film")) else "la queratina"


## «no la agrieta» o «no la agrietan», según _window_tip_noun (la queratina, en singular; unas garras, en plural).
static func _window_no_crack(r: Dictionary) -> String:
	return "no la agrieta" if _window_tip_noun(r) == "la queratina" else "no la agrietan"


## Veredicto del golpe contra la ventanilla: { verdict, vsub }. fate: lo que hace el animal después (_fall_txt).
static func side_window_verdict(r: Dictionary, sw: Dictionary, fate: String) -> Dictionary:
	var bits := window_bits_txt(sw)
	var open := "y deja el hueco abierto (si el animal entra en el coche, el modelo no lo calcula)"
	if Js.truthy(sw.shattered) and sw.cause == "grieta":
		return {
			"verdict": "ESTALLA LA VENTANILLA",
			"vsub": "%s abren una grieta que atraviesa la capa comprimida (~%s) con ~%s cada una (bastan ~%s), aunque el golpe (~%s por apoyo) no la partiría al flexar hasta ~%s: estalla entera en %s, %s; %s" % [
				_window_tip_noun(r), CarFormat.fmt_long(float(sw.compressionMm) * 1000.0), _fmt_n(float(sw.perClawN)), _fmt_n(float(sw.pierceN)),
				_fmt_n(float(sw.peakN)), _fmt_n(float(sw.bendN)), bits, open, fate],
		}
	if Js.truthy(sw.shattered):
		return {
			"verdict": "ESTALLA LA VENTANILLA",
			"vsub": "~%s por apoyo contra ~%s que aguanta el templado al flexar: estalla entera en %s, %s; %s" % [
				_fmt_n(float(sw.peakN)), _fmt_n(float(sw.bendN)), bits, open, fate],
		}
	var why := ""
	if not Js.truthy(sw.hardTip):
		why = "; %s (%s HV) %s: el vidrio (%s HV) es más duro" % [
			_window_tip_noun(r), CarFormat.num(float(sw.tipHv)), _window_no_crack(r), CarFormat.num(float(sw.glassHv))]
	elif sw.pierceN != null:
		why = "; %s la reventarían con ~%s cada una y llevan ~%s" % [_window_tip_noun(r), _fmt_n(float(sw.pierceN)), _fmt_n(float(sw.perClawN))]
	return {
		"verdict": "LA VENTANILLA AGUANTA",
		"vsub": "~%s por apoyo y el templado aguanta al flexar hasta ~%s%s; %s" % [_fmt_n(float(sw.peakN)), _fmt_n(float(sw.bendN)), why, fate],
	}


## El término del vidrio en el balance de energía con la ventanilla (energy_balance): lo que la hoja se queda hasta estallar,
## U = F²/2k (si aguanta, se lo devuelve al animal al rebotar: 0). [id, name, short, j, quality, source].
static func _window_energy_row(sw: Dictionary, j: float) -> Array:
	# unidad 4o: si aguanta, no se queda nada y no «hasta estallar»: lo devuelve
	var label := "Ventanilla (hasta estallar)" if Js.truthy(sw.shattered) else "Ventanilla (aguanta: lo devuelve)"
	return ["vidrio", label, "ventanilla", j, "secondary",
		"lo que se queda la hoja templada hasta estallar, U = F²/2k (placa redonda apoyada de Roark); si aguanta, lo devuelve al rebotar. La energía del temple que se libera al estallar (~%s) no sale del animal: lanza los trocitos" % CarFormat.fmt_energy(float(sw.temperJ))]


## El resto de la energía normal con la ventanilla (energy_balance): el animal y, si estalla, lo que haya tras el hueco.
static func _window_rest_row(sw: Dictionary, j: float) -> Array:
	if Js.truthy(sw.shattered):
		return ["animal", "Animal y lo que hay tras la ventanilla (resto)", "animal", j, "estimate",
			"resto de la energía normal que se disipa: patas, cuerpo y rebote y, con la luna rota, el marco, la puerta o lo que haya dentro; si el animal entra en el coche, el modelo no lo calcula (sin medición)"]
	return ["animal", "Animal (patas, cuerpo y rebote)", "animal", j, "estimate",
		"resto de la energía normal que se disipa: patas, cuerpo y rebote; sin medición"]


## La fila «Ventanilla» del informe del golpe.
static func side_window_txt(sw: Dictionary, r: Dictionary) -> String:
	if Js.truthy(sw.shattered) and sw.cause == "grieta":
		return "estalla por una grieta: ~%s por garra (bastan ~%s; partirla al flexar pide ~%s por apoyo) · %s · el hueco queda abierto" % [
			_fmt_n(float(sw.perClawN)), _fmt_n(float(sw.pierceN)), _fmt_n(float(sw.bendN)), window_bits_txt(sw)]
	if Js.truthy(sw.shattered):
		return "estalla al flexar: ~%s por apoyo contra ~%s · %s · el hueco queda abierto" % [
			_fmt_n(float(sw.peakN)), _fmt_n(float(sw.bendN)), window_bits_txt(sw)]
	var tail := "" if Js.truthy(sw.hardTip) else " · %s %s" % [_window_tip_noun(r), _window_no_crack(r)]
	return "aguanta · ~%s por apoyo (estalla desde ~%s)%s" % [_fmt_n(float(sw.peakN)), _fmt_n(float(sw.bendN)), tail]


## Veredicto sugerido del golpe: { verdict, vsub }. Con garras reforjadas, el subtítulo acaba diciendo si se mellan, se
## parten o se doblan (clawFracture).
static func impact_verdict(r: Dictionary, target: Dictionary) -> Dictionary:
	var v := _impact_verdict_core(r, target)
	var claws := _claw_clause(r)
	if claws != "":
		v.vsub += "; " + claws
	return v


static func _impact_verdict_core(r: Dictionary, target: Dictionary) -> Dictionary:
	var fate: String
	if r.stays:
		fate = "se queda encima"
		if r.hold != null and not r.hold.holds:
			fate = "se queda encima un instante, pero no aguanta a esa velocidad"
	else:
		fate = _fall_txt(r)
	var sw: Variant = r.get("sideWindow")
	if sw != null:
		return side_window_verdict(r, sw, fate)  # unidad 4m: la ventanilla templada
	var shield: Variant = r.windshield
	if shield != null:
		if shield.cracked:
			var through := ": puede atravesarlo" if shield.penetrationRisk else ""
			return {
				"verdict": "AGRIETA EL PARABRISAS",
				"vsub": "~%s por apoyo contra ~%s que aguanta; el laminado se agrieta pero no cae%s; %s" % [
					_fmt_n(shield.peakN), _fmt_n(shield.bendN), through, fate],
			}
		return { "verdict": "EL PARABRISAS AGUANTA", "vsub": "~%s por apoyo (se agrieta desde ~%s); %s" % [_fmt_n(shield.peakN), _fmt_n(shield.bendN), fate] }
	var punct: Variant = r.puncture
	var marks: Dictionary = r.marks
	if punct != null and punct.through and not is_metal(target):
		return {
			"verdict": "PERFORA EL PLÁSTICO",
			"vsub": "%s %s el %s%s; %s" % [
				_claws_noun(r), "atraviesa" if _one_claw(r) else "atraviesan", target.body.long, _tear_clause(r), fate],
		}
	var dent: Variant = r.dent
	# solo unas garras reforjadas cortan el metal: lo rajan al resbalar (el surco lo atraviesa) o lo perforan al golpear
	var dent_txt := ""
	if dent != null and dent.applies and dent.visible:
		dent_txt = " y la abolla ~%s" % Format.fmt_len(float(dent.depthMm) * 1000.0)
	var one := _one_claw(r)
	if is_metal(target) and marks.count > 0 and String(marks.verdict).begins_with("RAJA"):
		return {
			"verdict": "RAJA LA CHAPA",
			"vsub": "%s %s la chapa de %s a lo largo de ~%s%s; %s" % [
				_claws_noun(r), "raja" if one else "rajan", target.body.long, fmt_long(float(marks.lengthMm) * 1000.0),
				dent_txt, fate],
		}
	if punct != null and punct.through:
		return {
			"verdict": "PERFORA LA CHAPA",
			"vsub": "%s %s la chapa de %s%s; %s" % [_claws_noun(r), "atraviesa" if one else "atraviesan", target.body.long, dent_txt, fate],
		}
	var scratches := ""
	var paint_um: float = Data.PAINT_LAYERS[-1].to
	if marks.count > 0:
		var grooves := "un surco" if marks.count == 1 else "surcos"
		if marks.reachesBody and is_metal(target) and float(marks.depthUm) > paint_um + 1.0:
			scratches = "%s de ~%s en el metal" % [grooves, Format.fmt_len(float(marks.depthUm) - paint_um)]
		elif marks.reachesBody:
			scratches = "%s hasta el %s" % [grooves, "metal" if is_metal(target) else "plástico"]
		else:
			scratches = "un arañazo en la pintura" if marks.count == 1 else "arañazos en la pintura"
	if dent != null and dent.applies and dent.visible:
		var sub := "abolladura de ~%s" % Format.fmt_len(float(dent.depthMm) * 1000.0)
		if scratches != "":
			sub += " y " + scratches
		return { "verdict": "ABOLLA Y RAYA" if scratches != "" else "ABOLLA", "vsub": "%s; %s" % [sub, fate] }
	if marks.count > 0 and marks.reachesBody:
		if is_metal(target) and float(marks.depthUm) > paint_um + 1.0:
			return {
				"verdict": "RAYA EL METAL",
				"vsub": "%d %s de ~%s, ~%s de hondo en la chapa; %s" % [
					marks.count, "surco" if marks.count == 1 else "surcos", fmt_long(float(marks.lengthMm) * 1000.0),
					Format.fmt_len(float(marks.depthUm) - paint_um), fate],
			}
		return {
			"verdict": "RAYA HASTA EL %s" % ("METAL" if is_metal(target) else "PLÁSTICO"),
			"vsub": "%d %s de ~%s; %s" % [
				marks.count, "surco" if marks.count == 1 else "surcos", fmt_long(float(marks.lengthMm) * 1000.0), fate],
		}
	if marks.count > 0:
		return { "verdict": "ARAÑA LA PINTURA", "vsub": "marcas en %s; %s" % [String(marks.layer) if marks.layer != null else "el barniz", fate] }
	return { "verdict": "APENAS DEJA MARCA", "vsub": fate }


## Informe de daños del golpe: pares [etiqueta, valor] como el del modo dual (Lab.damage_report).
static func damage_report(r: Dictionary, target: Dictionary) -> Array:
	var out: Array = []
	out.append(["Golpe", "%s km/h relativos · %s contra el panel" % [Js.to_fixed(r.vRelKmh, 0), fmt_energy(r.normalJ)]])
	var kick: Variant = r.get("kick")
	if kick != null:
		out.append(["Patada", "salta a ~%s km/h con los pies por delante · la pata aguanta hasta ~%s (%s veces su peso)" % [
			Js.to_fixed(kick.leapKmh, 0), _fmt_n(kick.forceCapN), Js.to_fixed(kick.forceBw, 1)]])
	var dfi: Variant = r.get("defense")
	if dfi != null:
		out.append(["Defensa", defense_txt(dfi)])
	# unidad 4i-B2: el salto, la garra de película (ficción), la masa de las garras reforjadas y la punta afilada
	var lp: Variant = r.get("leap")
	if lp != null:
		out.append(["Salto", leap_txt(lp)])
	if Js.truthy(r.get("film")) and String(r.get("inlay", "none")) == "none":
		out.append(["Garras de película", film_claw_txt(r, target)])
	var cmass: Variant = r.get("clawMass")
	if cmass != null and float(cmass.addedKg) != 0.0:
		out.append(["Masa de las garras", claw_mass_txt(cmass)])
	var shp: Variant = r.get("sharpness")
	if shp != null:
		out.append(["Punta afilada", sharp_tip_txt(shp)])
	var marks: Dictionary = r.marks
	if marks.count > 0:
		out.append(["Marcas", "%d %s de %s × %s de ancho" % [
			marks.count, "surco" if marks.count == 1 else "surcos", fmt_long(float(marks.lengthMm) * 1000.0),
			Format.fmt_depth(marks.widthUm)]])
		out.append(["Profundidad", marks_depth_txt(marks, target, String(r.zone), marks.count != 1)])
		if marks.layers.size() > 0:
			out.append(["Capas", " · ".join(PackedStringArray(marks.layers))])
	var punct: Variant = r.puncture
	if punct != null:
		var paint_um: float = Data.PAINT_LAYERS[-1].to
		if punct.through:
			out.append(["Perforación", "atraviesa %s: agujeros de Ø %s%s" % [target.body.noun, Format.fmt_len(punct.holeUm),
				shared_gap_txt(punct, r.get("dent"), target)]])
		elif is_metal(target) and String(r.get("inlay", "none")) == "none" and not _cuts(r):
			out.append(["Perforación", "no: la queratina no corta el %s" % target.body.long])
		elif is_metal(target) and not _cuts(r):
			var one := _one_claw(r)
			out.append(["Perforación", "no: %s %s más %s que la chapa y no la %s: la punta cede, como la queratina" % [
				_claws_noun(r), "es" if one else "son", "blanda" if one else "blandas", "corta" if one else "cortan"]])
		elif is_metal(target) and float(punct.depthUm) > paint_um + 1.0:
			out.append(["Perforación", "se clava %s en %s, sin atravesarla" % [Format.fmt_len(float(punct.depthUm) - paint_um), target.body.noun]])
		elif is_metal(target):
			out.append(["Perforación", "no: se queda en la pintura"])
		elif float(punct.depthUm) > 0.0:
			out.append(["Perforación", "se clava %s" % Format.fmt_len(punct.depthUm)])
	var tear: Variant = r.get("tear")
	if tear != null:
		out.append(["Desgarro", tear_txt(tear)])
	var frac: Variant = r.get("clawFracture")
	if frac != null:
		out.append(["Garras", frac.vsub])
	var dent: Variant = r.dent
	if dent != null:
		if dent.applies:
			var txt := "no: la chapa aguanta (colapsa desde ~%s por apoyo)" % _fmt_n(dent.collapseN)
			if dent.visible and int(dent.patches) == 1:
				txt = "~%s bajo el pie%s" % [Format.fmt_len(float(dent.depthMm) * 1000.0), ", llega al fondo" if dent.bottomsOut else ""]
			elif dent.visible:
				txt = "~%s bajo cada uno de los %d apoyos%s" % [
					Format.fmt_len(float(dent.depthMm) * 1000.0), dent.patches, ", llega al fondo" if dent.bottomsOut else ""]
			out.append(["Abolladura", txt])
		elif dent.recovers:
			out.append(["Abolladura", "el plástico se hunde y recupera la forma"])
	var shield: Variant = r.windshield
	if shield != null:
		var txt := "se agrieta; el laminado no cae" if shield.cracked else "aguanta"
		if shield.penetrationRisk:
			# con un decimal, como el «¿sabías que…?» de la homologación (88.7 J), no «89 J» (unidad 4o)
			txt += " (y puede atravesarlo: más de %s J)" % Js.to_fixed(shield.penetrationJ, 1)
		out.append(["Parabrisas", "%s · ~%s por apoyo" % [txt, _fmt_n(shield.peakN)]])
	var swr: Variant = r.get("sideWindow")
	if swr != null:
		out.append(["Ventanilla", side_window_txt(swr, r)])  # unidad 4m
	var en: Variant = r.get("energy")
	if en != null and float(en.totalJ) > 0.0:
		var parts: Array = []
		for t: Dictionary in en.terms:
			if float(t.share) >= 0.01:
				parts.append("%s %s %%" % [t.short, Js.to_fixed(float(t.share) * 100.0, 0)])
		out.append(["Energía", "%s: %s" % [fmt_energy(en.totalJ), " · ".join(PackedStringArray(parts))]])
	out.append(["Animal", "se queda encima" if r.stays else _fall_txt(r)])
	return out


## Qué hace el animal al salirse del panel: resbala (si le da tiempo), o se desengancha si las garras se clavaron, y
## cae a la velocidad que lleva respecto al suelo. Un ave que aterriza sale volando; si ha chocado, sale despedida. El
## casuario, tras la patada, rebota.
static func _fall_txt(r: Dictionary) -> String:
	var ground := Js.to_fixed(r.groundKmh, 0)
	if r.get("attack") == "patada":
		var pre := "se desengancha, " if Js.truthy(r.get("embedded")) else ""
		if float(r.groundKmh) < 1.0:
			return "%srebota y se queda junto al coche" % pre
		return "%srebota y cae a ~%s km/h respecto al asfalto" % [pre, ground]
	var slid := "resbala %s y " % fmt_long(float(r.slideM) * 1e6) if float(r.slideM) >= 0.01 else ""
	if Js.truthy(r.get("embedded")):
		slid = "se desengancha y "
	if r.kind == "ave":
		return "%s%s (a ~%s km/h respecto al suelo)" % [slid, "sale volando" if Js.truthy(r.get("landing")) else "sale despedida", ground]
	return "%scae a ~%s km/h respecto al asfalto" % [slid, ground]


## Qué hacen unas garras trabadas en el plástico, para el subtítulo del golpe (unidad 4g): « y lo rajan ~80 cm a lo
## largo», «…, hasta que va a la velocidad del coche», «, pero rajarlo pide ~900 N y solo aguanta ~202 N» o nada.
static func _tear_clause(r: Dictionary) -> String:
	var t: Variant = r.get("tear")
	if t == null:
		return ""
	if not Js.truthy(t.holds):
		return ", pero rajarlo pide ~%s y solo aguanta ~%s" % [_fmt_n(float(t.forceN)), _fmt_n(float(t.anchorN.value))]
	if float(t.lengthMm) <= 0.0:
		return ""
	var txt := " y lo %s ~%s a lo largo" % ["raja" if _one_claw(r) else "rajan", fmt_long(float(t.lengthMm) * 1000.0)]
	if Js.truthy(t.stopped):
		txt += ", hasta que va a la velocidad del coche"
	return txt


## ¿Golpea con una sola garra? (la daga del casuario)
static func _one_claw(r: Dictionary) -> bool:
	return r.get("attack") == "patada"


## «la daga de zafiro» o «las garras de zafiro» (con el material de las garras).
static func _claws_noun(r: Dictionary) -> String:
	var mat := ""
	var frac: Variant = r.get("clawFracture")
	if frac != null:
		mat = " de " + String(frac.name)
	else:
		var id := String(r.get("inlay", "none"))
		if id != "none":
			mat = " de " + String(ClawFracture.NOUNS.get(id, id))
	return ("la daga" if _one_claw(r) else "las garras") + mat


## Qué les pasa a unas garras reforjadas al golpear el metal, en pocas palabras («» si nada o sin datos).
static func _claw_clause(r: Dictionary) -> String:
	var frac: Variant = r.get("clawFracture")
	if frac == null:
		return ""
	var one := _one_claw(r)
	var noun := _claws_noun(r)
	match String(frac.mode):
		"mella":
			return "%s %s: %s desprenden ~%s de la punta" % [
				noun, "se mella" if one else "se mellan", "se le" if one else "se les",
				Format.fmt_len(float(frac.brokenMm) * 1000.0)]
		"parte":
			return "%s %s por la base" % [noun, "se parte" if one else "se parten"]
		"dobla":
			return "%s %s" % [noun, "se dobla" if one else "se doblan"]
	return ""


# ════════ El velocirraptor de película y la masa de las garras (unidad 4i-B2) ════════

## Lo de película en los textos, siempre con el contraste: la fila del informe («Garras de película») y la coletilla del
## subtítulo del golpe (en la chapa, en el plástico y en el vidrio).
const FILM_CLAW_TXT := "ficción (película): sus garras falciformes cortan el %s como en el cine; las de verdad, de queratina, no lo cortan: pinchaban y sujetaban (Manning et al. 2006; Fowler et al. 2011)"
const FILM_CLAW_PLASTIC_TXT := "ficción (película): sus garras falciformes rajan el %s como en el cine; aquí la de verdad, de queratina, también lo atraviesa, porque pincha: lo de película es rajar el acero (Manning et al. 2006; Fowler et al. 2011)"
const FILM_CLAW_GLASS_TXT := "ficción (película): en el cine sus garras lo rajan todo, pero ni la garra de película raya el vidrio del parabrisas, más duro que ella"
const FILM_NOTE_METAL := "; ficción: en la película sus garras rajan la chapa, pero las de verdad, de queratina, no cortan el %s"
const FILM_NOTE_PLASTIC := "; ficción: en la película lo raja todo, pero este plástico también lo atravesaría la garra de verdad, de queratina, que pincha y sujeta"
const FILM_NOTE_GLASS := "; ficción: ni la garra de película raya el vidrio del parabrisas, más duro que ella"
## Unidad 4m: lo mismo en la ventanilla templada (la garra de película, 200 HV, no la agrieta: si estalla, es por el golpe).
const FILM_CLAW_WINDOW_TXT := "ficción (película): en el cine sus garras lo rajan todo, pero ni la garra de película raya el vidrio de la ventanilla, más duro que ella: si estalla, es por el golpe"
const FILM_NOTE_WINDOW := "; ficción: ni la garra de película raya el vidrio de la ventanilla, más duro que ella; si estalla, es por el golpe"


## El veredicto del golpe del velocirraptor de película (FICCIÓN): el del motor con chispa de cine («SE ABALANZA Y RAJA LA
## PUERTA», «SALTA SOBRE EL CAPÓ Y LO RAJA», «CLAVA LAS GARRAS EN LA ALETA»…) y, al final del subtítulo, el contraste con el
## de verdad. v: el veredicto del motor (impact_verdict). La física es la de siempre: solo cambian las palabras.
static func film_verdict(r: Dictionary, target: Dictionary, v: Dictionary) -> Dictionary:
	var iz: Dictionary = IMPACT_ZONES[String(r.zone)]
	var fem: bool = r.zone == "puerta" or r.zone == "aleta"
	var the := ("LA " if fem else "EL ") + String(iz.name).to_upper()
	var pro := "LA" if fem else "LO"
	var side: bool = iz.normal == "lado"
	var head := String(v.verdict)
	var t: Variant = r.get("tear")
	var torn: bool = t != null and Js.truthy(t.get("holds")) and float(t.get("lengthMm", 0.0)) > 0.0
	match head:
		"RAJA LA CHAPA":
			head = ("SE ABALANZA Y RAJA %s" % the) if side else ("SALTA SOBRE %s Y %s RAJA" % [the, pro])
		"PERFORA LA CHAPA":
			head = "CLAVA LAS GARRAS EN %s" % the
		"PERFORA EL PLÁSTICO":
			head = ("SE ABALANZA Y RAJA %s" % the) if torn else ("CLAVA LAS GARRAS EN %s" % the)
		"ABOLLA Y RAYA":
			head = ("SE ABALANZA, ABOLLA Y ARAÑA %s" % the) if side else ("SALTA SOBRE %s, %s ABOLLA Y %s ARAÑA" % [the, pro, pro])
		"RAYA EL METAL", "RAYA HASTA EL METAL":
			head = ("SE ABALANZA Y ARAÑA %s" % the) if side else ("SALTA SOBRE %s Y %s ARAÑA" % [the, pro])
		"EL PARABRISAS AGUANTA":
			head = "EL PARABRISAS LE PARA LOS PIES"
		"AGRIETA EL PARABRISAS":
			head = "SE ESTRELLA CONTRA EL PARABRISAS Y LO AGRIETA"
		# unidad 4m: la ventanilla templada
		"ESTALLA LA VENTANILLA":
			head = "SE ESTRELLA CONTRA LA VENTANILLA Y LA REVIENTA"
		"LA VENTANILLA AGUANTA":
			head = "LA VENTANILLA LE PARA LOS PIES"
	var note := FILM_NOTE_GLASS
	if r.get("sideWindow") != null:
		note = FILM_NOTE_WINDOW
	elif r.get("windshield") == null:
		note = (FILM_NOTE_METAL % String(target.body.long)) if is_metal(target) else FILM_NOTE_PLASTIC
	return { "verdict": head, "vsub": String(v.vsub) + note }


## La fila «Garras de película» del informe del golpe: lo que es de película y lo que haría la garra de verdad, según contra
## qué golpea (la chapa de metal, el plástico o el vidrio del parabrisas).
static func film_claw_txt(r: Dictionary, target: Dictionary) -> String:
	if r.get("sideWindow") != null:
		return FILM_CLAW_WINDOW_TXT  # unidad 4m
	if r.get("windshield") != null:
		return FILM_CLAW_GLASS_TXT
	return (FILM_CLAW_TXT if is_metal(target) else FILM_CLAW_PLASTIC_TXT) % String(target.body.long)


## ¿Cortan la chapa las garras del golpe? (impact: cutsBody, con el material o, sin él, la dureza de la propia garra)
static func _cuts(r: Dictionary) -> bool:
	return Js.truthy(r.get("cutsBody"))


## La punta afilada en palabras (la fila del informe, quieto encima o en el golpe): «R 2.35 µm (la de la ficha, 138 µm)».
static func sharp_tip_txt(info: Dictionary) -> String:
	return "R %s (la de la ficha, %s)" % [Format.fmt_tip_um(float(info.tipRadiusUm)), Format.fmt_tip_um(float(info.naturalTipRadiusUm))]


## El bloque de la masa de las garras (claw_mass_block) con lo que suma a la velocidad relativa del golpe (m/s): ½·Δm·v².
static func _with_extra(cm: Variant, v_rel_ms: float) -> Variant:
	if cm == null:
		return null
	var out: Dictionary = cm.duplicate()
	out.extraJ = 0.5 * float(cm.addedKg) * v_rel_ms * v_rel_ms
	return out


## La masa de las garras en palabras (la fila del informe): «+511 g (2 garras de 256 g más que las de queratina: el 2.60 % del
## animal); a la velocidad del golpe suma 81 J».
static func claw_mass_txt(cm: Dictionary) -> String:
	var n := int(cm.claws)
	return "%s%s g (%d %s de %s g %s que %s de queratina: el %s %% del animal); a la velocidad del golpe %s %s" % [
		"+" if float(cm.addedKg) >= 0.0 else "−", Format.fmt_f(absf(float(cm.addedKg)) * 1000.0), n, "garra" if n == 1 else "garras",
		Format.fmt_f(absf(float(cm.perClawKg)) * 1000.0), "más" if float(cm.perClawKg) >= 0.0 else "menos", "la" if n == 1 else "las",
		Js.to_fixed(absf(float(cm.bodyShare)) * 100.0, 2), "suma" if float(cm.addedKg) >= 0.0 else "resta",
		fmt_energy(absf(float(cm.extraJ)))]


## Fuerza legible: N hasta 10 kN; después kN con un decimal (CarFormat.fmt_n).
static func _fmt_n(f: float) -> String:
	return CarFormat.fmt_n(f)


## Longitud legible con metros a partir de 1 m: 350 µm · 6.1 mm · 35 mm (3.5 cm) · 1.6 m (CarFormat.fmt_long).
static func fmt_long(um: float) -> String:
	return CarFormat.fmt_long(um)


## Energía legible: J hasta 1000 J; después kJ con un decimal (CarFormat.fmt_energy).
static func fmt_energy(j: float) -> String:
	return CarFormat.fmt_energy(j)


# ════════ Apoyo ════════

## Parámetros de Physics.compute() con los valores por defecto del oráculo (como en los tests del motor).
static func _lab_params(claw: Dictionary, target: Dictionary, over: Dictionary) -> Dictionary:
	var p := {
		"geom": Data.GEOMS[0], "base": Data.BASES[0], "inlay": Data.INLAYS[0], "claw": claw, "target": target,
		"force": 1.0, "length": 25.0, "type": Data.TYPES[1], "tear": false, "method": "rayado", "strike": false,
		"passes": 1, "wet": false, "model": "2.0",
	}
	p.merge(over, true)
	return p


## El vidrio del catálogo: da la fricción de la queratina sobre el vidrio (y que no lo raya).
static func _glass() -> Dictionary:
	return Data.find_by_id(Data.TARGETS, "vidrio")


## Datos para el dibujo 2D: posición de la zona (0-1 sobre la silueta lateral del coche) y tamaño del animal.
static func _draw_data(body: Dictionary, zone: Dictionary) -> Dictionary:
	var out := { "x": zone.draw.x, "y": zone.draw.y, "heightM": body.height_m, "lengthM": body.length_m }
	if body.kind == "ave":
		out["spanM"] = body.span_m.value
	if body.has("variant"):
		out["variant"] = body.variant  # los velocirraptores: «pelicula» o «reconstruccion» (unidad 4i-B2; solo dibujo)
	return out
