# Cetrería y cuidado de garras · anatomía, física del limado y protocolo veterinario (laboratorio 2.0, unidad 5a)

> **Unidad 5a cerrada.** Esta guía documenta el modelo puro, sus datos con fuente y la API que consume la escena 3D de la unidad 5b.

Petición de Eric: «En el banco de Tribología biológica, añade una simulación 3D completa en Godot, como la que hicimos en
el Workshop industrial de la afiladora, pero para un simulador de Cetrería, que consistirá en aprender a afilar
correctamente las garras de un ave rapaz, velociraptor dormido, Oso pardo u tigre, de forma correcta y con cuidados
veterinarios, con una lima u aparato similar de uso en 3D e interactivo con el ratón y teclas del teclado del usuario,
depende del resultado, puede la garra quebrarse, reforjarse, o quedar perfectísima y afilada como una daga, será
educativo, y tiene que haber un Tutorial infame depende cada proceso y como hay que hacerlo».

Esta unidad (5a) es la física, la anatomía y el protocolo: un modelo puro, sin nodos, con sus tests, y la guía para la
escena 3D interactiva de la unidad 5b.

## 1. Resumen

La unidad modela una garra como un estuche de queratina con perfil discretizado, carne viva, punta y daños. `ClawCare` es determinista y no crea nodos: cada acción devuelve un resultado y deja disponible una instantánea para la escena. El limado aplica Archard por diente o grano; el cortaúñas calcula la grieta; la dirección contraria a las capas puede deshojar; el torno resuelve conducción, convección, dolor y lesión; y el informe puntúa seguridad, forma, sangre, calor, grietas y reconstrucción. La simulación educativa no sustituye la intervención veterinaria.

## 2. Anatomía de la garra

### 2.1 Rapaces

- **Estuche de queratina sobre la falange ungueal.** «Most raptors have long, curved talons integrated with a hard,
  highly keratinized casing covering the dorsal and lateral aspects, and a ventral, much softer plate» (Samour 2006,
  cap. 40, p. 925). Cada garra es un hueso cubierto por un estuche de láminas de queratina (Arent & Pollock, LafeberVet).
- **Dónde acaba la carne viva.** En 580 garras radiografiadas de 145 especies de aves, el núcleo óseo mide 0,693-0,705
  veces el estuche (IC 95 %), ~0,70 en las rapaces (Hedrick et al. 2019); Manning et al. (2006), en 10 rapaces: el
  estuche sobresale del hueso como mucho un 15 % de la longitud total. La dermis con vasos y nervios cubre el hueso, así
  que la carne viva acaba hacia la punta del hueso: el último ~30 % de la garra (15 % con Manning) es queratina muerta.
  Las aves tienen «una carne viva muy larga»; en las garras claras se ve como la zona rosada (Sakas, Niles Animal
  Hospital; MSD Veterinary Manual). En las oscuras no se ve: al acercarse, el corte muestra un punto más oscuro en el
  centro (Dremel, guía de corte de uñas de perro).
- **Regeneración.** Una garra arrancada vuelve a crecer, «a slow process sometimes requiring up to 2 to 3 months»
  (Samour 2006, p. 925); mientras, apósito hidrocoloide y vendaje, cambiados cada 5-7 días.
- **Crecimiento.** Sin medición en rapaces. Caso medido más parecido: las uñas de cinco paseriformes europeos crecen
  ~0,04 mm al día (Bearhop et al. 2003, citado por Mazerolle & Hobson 2005).
- **Por qué crecen de más en cautividad:** perchas blandas o inadecuadas y falta de una dieta natural que las desgaste
  (Samour 2006); un estuche demasiado largo pincha la almohadilla del metatarso o los dedos y reparte mal el peso en la
  planta (Arent & Pollock, LafeberVet).
- **Coping** (palabra medieval: recortar y dar forma al pico y a las garras): las garras crecidas se recortan con un
  cortaúñas de guillotina y se les da forma con una cuchilla y limas; recortar de más hace sangrar; el termocauterio o
  el lápiz de nitrato de plata bastan para parar la hemorragia; después, crema de lanolina o parafina; a las aves de
  cetrería se les recortan antes de la muda (Samour 2006, p. 927).

### 2.2 Tigre y oso pardo

- **Felinos (garra retráctil, estuche por capas que se mudan).** En el gato doméstico el estuche córneo lo forman conos
  anidados de queratina dura (el «apical cone horn» hace la punta endurecida), láminas laterales («blade horn»), una
  suela blanda y una queratina blanda terminal que cubre el lecho dérmico en la punta del proceso ungueal. Las capas
  externas se desprenden en «capuchones» gracias a microgrietas tangenciales que no dañan el tejido vivo: así la punta se
  mantiene afilada (Homberger et al. 2009).
- **Crecimiento (caso medido más parecido: el gato).** Uñas de las manos: 0,13 mm/día de mediana (0,01-0,27); de las
  patas, 0,08 mm/día (17 gatos adultos de interior; Contreras et al. 2025). El «1,9 mm por semana» que circula viene de
  perros, no de gatos (los mismos autores).
- **Oso (garra no retráctil, crece sin parar).** Sin medición de su ritmo de crecimiento. Caso medido más parecido, otro
  carnívoro excavador: el tejón americano, 0,26-0,28 mm/día, con la garra entera renovada en 130-140 días (Ethier et al.
  2010, citado por Fokidis et al. 2023).
- **Práctica real:** a un tigre se le recorta una garra sedado o anestesiado (un tigre blanco con una garra clavada en la
  almohadilla: sedación, tenazas de herrador y un torno sin cable; la almohadilla curó en unos días; Cat Tales 2024). A
  los osos rescatados se les recortan las garras crecidas y clavadas durante la revisión con anestesia (Animals Asia).
  Hay zoológicos que entrenan a los animales con refuerzo positivo para cooperar en procedimientos que antes pedían
  sujeción o sedación (BIAZA 2019: un oso polar presenta la pata para una radiografía), pero limar una garra de tigre o
  de oso se hace con el animal anestesiado.

### 2.3 Velocirraptor (reconstrucción, anestesiado)

- Garra falciforme del dedo II: hueso de 64,8 mm y estuche de 92,7 mm (76,2-95,7) por la curva exterior
  (`godot/core/lab/velociraptor.gd`, unidad 4e: Norell & Makovicky 1999; Hedrick et al. 2019).
- La carne viva se estima como en las aves, sus parientes vivos: hasta la punta del hueso, a 64,8 mm de la base.
  «Dormido» es anestesiado: es un experimento mental y así se dice.

## 3. La queratina al limarla

- **Humedad (garra de avestruz, Taylor, Bonser & Farrent 2004, recogido por McKittrick et al. 2012, tabla II):**

  | HR | E (GPa) | Resistencia (MPa) | Deformación de rotura |
  |---|---|---|---|
  | 0 % | 2,7 | 90 | 5,7 % |
  | 50 % | 2,0 | 69 | 6,7 % |
  | 100 % | 0,1 | 14 | 50,5 % |

  Seca es más rígida y resistente pero se rompe con muy poca deformación; mojada es blanda y se estira mucho.
- **Anisotropía:** en la garra de avestruz, E = 1,8 GPa a lo largo y 1,33 GPa de través (Bonser 2000, en McKittrick
  2012).
- **Tenacidad de la uña humana** (el caso medido más parecido de una placa de queratina por capas):
  - las grietas se desvían siempre de través, paralelas al borde libre: ~3 kJ/m² de través frente a ~6 kJ/m² a lo
    largo; la capa intermedia, de células alargadas de través, pide un cuarto de energía de través (Farren, Shayler &
    Ennos 2004);
  - con cortaúñas, el trabajo de rotura es máximo a 55 % HR (18-22 kJ/m² hacia la raíz, ~11 de lado); a 33 % HR,
    11-12 y 8-9; a 100 % HR, ~13 y 8-9; sumergida, 8,35 ± 1,95 (hacia la raíz). A 0 % HR «se rompe en polvo»: frágil.
    «Brittle when fully dry and fracture and split when wet»; las capas «tend to peel apart at their boundaries,
    particularly when wet». Agua: 6 % a 0 % HR, ~15 % a 55 % y 64 % a 100 % (Farran, Ennos & Eichhorn 2008).
- **Casco y cuerno** (queratina con túbulos): la tenacidad es máxima a 75 % HR (22,8 kJ/m², Bertram & Gosline 1987); el
  cuerno seco rompe frágil y el mojado, dúctil; en compresión falla por microabombamiento y **deslaminación** (Trim et
  al. 2011; Tombolato et al. 2010; en McKittrick 2012).
- **Consejos de dermatología (uña humana):** «Always file the nail in the same direction, as filing back and forth can
  weaken your nails»; remojar las uñas en agua tibia unos minutos antes de cortarlas las ablanda (American Academy of
  Dermatology, «How to trim your nails»).
- **Calor:**
  - difusividad térmica de la uña humana: ~10 × 10⁻⁴ cm²/s (mínimo, hacia los 20 años) a ~18 × 10⁻⁴ cm²/s (más de 50
    años), por fotoacústica (Dias et al. 2007); densidad de la queratina α, 1,283-1,335 g/cm³ (Mason 1963, en el banco);
  - umbral del dolor por calor: ~40-45 °C (Dubin & Patapoutian 2010); medido con QST desde 32 °C y rampa de 1 °C/s,
    40,8 ± 3,7 °C en el antebrazo y 42,6 ± 3,4 °C en la frente (130 adultos; Pan et al. 2024). El receptor del calor
    nocivo de las aves (TRPV1 del pollo) también se activa con el calor, como el de los mamíferos (Jordt & Julius 2002);
  - lesión térmica (Moritz & Henriques 1947, recogido por Milner 2024): 44 °C durante 6 h, 45 °C 3 h, 50 °C 5 min,
    55 °C 30 s, 60 °C 5 s, 65 °C 2 s y 70 °C 1 s;
  - el fabricante del torno de uñas de mascota: «grinding creates friction and friction creates heat… limit the
    grinding action to a few seconds at a time, with short breaks in between» (Dremel).

## 4. Herramientas

- **Material de coping** (Samour 2006, tabla 40.13): cortaúñas de guillotina, cortaúñas grande de tipo humano, lima de
  uñas fina, pegamento de metacrilato, bicarbonato en polvo fino, cuchilla y lápiz de nitrato de plata.
- **Limas de mano (DIN 8349, catálogo de PFERD):** dientes por centímetro según el largo y el picado (1 = bastardo,
  grueso; 2 = entrefino; 3 = fino): 100 mm, 17/22/28; 150 mm, 13/18/22; 200 mm, 10/14/18; 250 mm, 9/12/16. PFERD
  recomienda para el cuerno (material blando) limas y escofinas de madera y escofinas de casco.
  - Limas de taller de acero al cromo de 60-62 HRC (FWT GmbH), unos 700 HV (DIN EN ISO 18265, como en
    `core/taller/radial.gd`). Una lima solo muerde lo que es más blando que ella (prueba de dureza con limas de 40-65
    HRC, HolzWerken 2024). Las limas de metal duro de PFERD son para aceros de más de 54 HRC.
  - La lima corta al empujar: en el retroceso se levanta de la pieza; arrastrarla hacia atrás desafila los dientes
    (Crescent Nicholson, «Guide to files and filing»). La de picado sencillo deja mejor acabado; la de picado doble
    arranca más (Nicholson; NMRA).
- **Limas de diamante (DMT):** extragruesa 60 µm (malla 220), gruesa 45 µm (325), fina 25 µm (600), extrafina 9 µm
  (1200); en seco o con agua.
- **Lija (lima de cartón o esmeril):** tamaño medio de grano FEPA P (Klingspor): P80 ≈ 195 µm, P120 ≈ 126 µm, P180 ≈
  77 µm, P240 ≈ 58 µm, P400 ≈ 35 µm.
- **Tamaño de grano y arranque:** el desgaste crece proporcionalmente al tamaño del abrasivo hasta un tamaño crítico
  (~82 µm en los aceros ensayados por Kalácska et al. 2021) y después deja de crecer.
- **Torno de uñas de mascota:** Dremel 7300-PT, dos velocidades, 6500 y 13 000 rpm (en la tabla de su ficha; el texto
  dice 15 000), con tambor de lija de grano 60. Guía de Dremel: sujetar la herramienta a 45° para seguir la forma y la
  curva natural de la uña; unos segundos cada vez, con pausas; si sangra, un pellizco de polvo hemostático y presión
  moderada hasta que pare.
- **Amoladora de uñas con protector (unidad 5c):** Dremel 7760-PGK PawControl, inalámbrica (4 V, 2 Ah de ion-litio):
  interruptor deslizante con 4 velocidades de 8000 a 25 000 rpm (ficha del 7760-PGK); las cuatro posiciones, 8000,
  14 000, 21 000 y 25 000 rpm, y arranca a 8000 rpm (manual original de la Dremel Lite 7760, la misma herramienta);
  protector de uñas con una guía de 45° para el ángulo y para recoger el polvo; banda de lija de 1/2″ (12,7 mm) de grano
  60 (407 y 408); 7,5 × 1,5 × 1,75 in. En el modelo es el torno de siempre (`ClawCare.file()` con `dwell_s` y `rpm`, el
  tipo «torno»): sin física nueva. A 25 000 rpm la banda corre a 16,6 m/s, 3,1 veces más que a 8000, y con la misma
  fuerza mete 3,1 veces más calor (P = ε·μ·F·v).
- **Hemostáticos:** en aves, subsulfato férrico, nitrato de plata o radiocirugía bipolar (MSD Veterinary Manual,
  «Management of Pet Birds»); en rapaces, termocauterio o lápiz de nitrato de plata (Samour 2006). En piel humana, el
  nitrato de plata duele más que el subsulfato férrico (mediana de 6 frente a 1,5 en una escala de dolor; Coakley et al.
  2020). En el perro, si una uña no deja de sangrar en 5-10 minutos, lápiz hemostático, nitrato de plata o polvo
  cauterizante (VCA, Weir, Williams & Buzhardt).
- **Antiséptico:** clorhexidina diluida al 0,05 %: mató el 100 % de las bacterias sin retrasar la cicatrización de
  heridas en perros (Lozier, Pope & Berg 1992).

## 5. Protocolo veterinario

- **Sujeción de una rapaz** (Samour 2006): las rapaces adiestradas van encapuchadas; las medianas y pequeñas se cogen a
  mano y se envuelven en una toalla suave; las grandes (águilas, buitres), siempre entre dos personas: una rodea las
  alas y sujeta el ave contra el cuerpo, la otra sujeta las patas con un dedo entre los tarsos. El coping del pico puede
  hacerse sin anestesia general en algunas aves, pero hace falta en las que se estresan mucho (Arent & Pollock). Las
  rapaces toleran muy bien la anestesia con isoflurano (Samour 2006).
- **Coping:** las garras crecidas se recortan con un cortaúñas de guillotina y se les da forma con una cuchilla y limas;
  recortar de más hace sangrar sin remedio; el termocauterio o el nitrato de plata bastan para parar la hemorragia;
  después, crema de lanolina o parafina (Samour 2006).
- **Reconstrucción:** en el pico, los defectos se rellenan con pegamento de metacrilato y bicarbonato o con kits
  comerciales de reparación, y hay que rehacerlo cada 8-12 semanas porque la queratina crece (Samour 2006). Las grietas
  del pico se recortan cuanto antes para que no acaben en fracturas.
- **Tigre y oso:** anestesia general (§2.2).

**Pasos para el tutorial:** preparar la sujeción o anestesia; observar la carne viva; remojar antes de cortar si procede; escoger una herramienta más dura que la garra; recortar poco a poco; seguir la curva con pasadas de base a punta; comprobar radio, grietas, calor y margen; parar la sangre con presión y hemostático; desinfectar; proteger o reconstruir la garra rota; aplicar crema a la rapaz y vigilar la recuperación. Los pasos y sus fuentes están en `claw_care_tutorial.gd`. El informe puntúa cada desviación con una rúbrica **pedagógica** (`CareData.RUBRIC`), no clínica.

## 6. El modelo

El estado en `claw_care.gd` guarda estaciones del estuche y la carne viva cada 0,05 mm, punta y faceta, daños, humedad, calor, sangre, estrés y protocolo. `file()` calcula el volumen con Archard: ΔV = η·K·F·L/H. El factor η es la eficiencia de dureza del motor; K procede de la penetración y del modo de abrasión de cada diente o grano (`core/shared/abrasion.gd`); el tamaño de grano se escala hasta el valor crítico medido en acero, extrapolado a queratina. Limar de frente acorta y aplana; en ángulo talla la faceta. Limar en contra de las capas levanta una escama si μ·F/ancho supera la tenacidad entre capas. `clip()` abre una grieta con la cuña según a = (3·E·h³·Δ²/(16·J))^(1/4). La carga lateral que aguanta la punta se calcula con `claw_sharpness.gd` y crece como R².

El torno deposita P = ε·μ·F·v; la conducción unidimensional se integra implícitamente con convección y una frontera viva a temperatura de partida. Ningún nodo pasa de la temperatura a la que la queratina se desnaturaliza y se quema (`THERMAL.char_c`, 230 °C, banda 215-255 °C): por encima, lo que sobra la quema en lugar de calentarla más, y se avisa con el suceso «quema». Donde ya no queda garra bajo el torno, la herramienta no toca nada y no calienta. Sin ese tope, el torno apretado en el mismo sitio sobre la carne viva, sin material que arrancar, subía a decenas de miles de grados (visto por la unidad 5b; tests en `test_claw_care.gd`). La lesión suma fracciones del tiempo de Moritz y Henriques a cada temperatura. `advance()` enfría y avanza sangre y estrés sin tocar la geometría. La semilla de la carne viva oculta pasa por `core/shared/rng.gd`; exponenciales y logaritmos usan `core/shared/v8_math.gd`. El informe contiene veredicto, nota, criterios, consejos y días de rebrote. Los casos de `tests/fixtures/spec/cetreria.json` recogen los cálculos independientes con tolerancias explícitas.

## 7. Tabla valor → fuente → tipo

| Valor usado | Fuente o caso medido más parecido | Calidad |
|---|---|---|
| Relación hueso/estuche 0,699 (banda 0,693-0,85) | Hedrick et al. 2019 (aves), Manning et al. 2006 (extremo alto) | secondary en aves; estimate en mamíferos y fósil |
| Crecimiento 0,04 / 0,13 / 0,27 mm/día (rapaz/tigre/oso) | Paseriformes: Bearhop et al. 2003 vía Mazerolle y Hobson 2005; gato: Contreras et al. 2025; tejón: Ethier et al. 2010 vía Fokidis et al. 2023 | estimate |
| Las garras de las patas traseras del tigre crecen 0,08/0,13 de lo de las manos (a 90 días, 7,2 frente a 11,7 mm de más); las demás garras, todas lo de su animal (unidad 5s) | Gato doméstico, medianas de patas y manos: Contreras et al. 2025; sin medición dedo a dedo ni pata a pata en los demás | estimate |
| La punta al empezar (unidad 5s, petición de Eric): roma ×6 el radio natural (la natural gastada: esfera tangente al mismo cono, más corta); afilada ×0,75 con el semiángulo ×0,9 en el 10 % del largo; aguja ×0,1 (el radio de los dientes de la lima) con el semiángulo ×0,6 en el 15 % del largo; natural, la de la ficha | Las bandas del medidor (rúbrica: ×0,5-×2; la aguja, por debajo de ¼ del aguante de lado, Pattrick et al. 2018); que el suelo y las posaderas embotan las garras: LDWF, «Raptor Housing Information» | estimate (la natural, la de la ficha) |
| Queratina seca/natural/húmeda: E 2,24/2,0/0,1 GPa; σ 76,1/69/14 MPa | Garra de avestruz, Taylor et al. 2004; seca interpolada | estimate / secondary |
| Trabajo de rotura 11-22 kJ/m²; tenacidad entre capas ×0,25 | Uña humana, Farran et al. 2008; capa intermedia, Farren et al. 2004 | secondary / estimate |
| Difusividad 10⁻⁷ m²/s, calor específico 1530 J/(kg·K), reparto ε=0,5 | Uña humana, Dias et al. 2007; cuerno, Picard et al. 1999 (resumen); amolado, Malkin y Guo 2007 (extrapolación) | secondary / estimate / estimate |
| Dolor 43 °C; lesión 44 °C/6 h a 70 °C/1 s | Dubin y Patapoutian 2010, Pan et al. 2024 (humanos); Moritz y Henriques 1947 vía Milner 2024 | secondary |
| La queratina se quema a ~230 °C (215-255 °C): tope del modelo térmico | Pezuña de vaca, Kakkar et al. 2014 (215 °C); queratinas α, Wortmann et al. 2012 (230-255 °C); la β de las aves no está medida | secondary; el tope es una suposición del modelo |
| Limas 13/18/22 dientes/cm, acero ~700 HV; diamante 45/25 µm; P180/P240 77,2/57,9 µm | DIN 8349/PFERD; FWT/DIN EN ISO 18265; DMT; Klingspor | secondary |
| Torno 6500/13 000 rpm, grano 60; diámetro 12,7 mm | Dremel 7300-PT; diámetro habitual de tambor, no medido en esta herramienta | secondary / estimate |
| Amoladora 8000/14 000/21 000/25 000 rpm, banda de 12,7 mm de grano 60, protector a 45° (unidad 5c) | Ficha del Dremel 7760-PGK; manual de la Dremel Lite 7760; grano P60 de Klingspor | secondary (el corindón de 2000 HV, estimate) |
| Hemostasia 30 s con agente; 300 s solo presión; 600 s sin tratar | Dremel (segundos con agente), VCA (5-10 min) | estimate / secondary |
| Puntuación, umbrales de faceta y grosor, estrés | Rúbrica educativa de `claw_care_data.gd`, §6 | estimate (no medición clínica) |
| Rubí 3980 kg/m³, 760 MPa, 2,4 MPa·√m; alúmina 3900 kg/m³, 379 MPa, 4,5 MPa·√m (unidad 5g) | Corindón (Handbook of Mineralogy) y las hojas del zafiro; CoorsTek AD-995 | secondary |
| Prueba de la punta: toque de 0,5 N con μ = 0,3 contra la uña del banco; K_c = √(E·J) de la queratina (~4,7 MPa·√m natural) (unidad 5g) | Elección del ensayo; Johnson 1985, Pattrick et al. 2018, Taylor 2007; garra de avestruz (Taylor et al. 2004) y uña (Farran et al. 2008) | estimate |
| La garra de cada dedo de las rapaces: largo, alto de la base y arco (unidad 5g) | Fowler et al. 2009, tabla S1 (un ejemplar de cada especie o la más parecida); el arco del dedo III, la media de lo medido (Birn-Jeffery et al. 2012, Pike y Maitland 2004) | primary (águila, halcón) / secondary |
| Arco del tigre 98,4°; garras de los dedos del tigre y del oso como la del banco; sus patas traseras como las de la mano (unidad 5g) | 43 garras de tigre (AIWC 2023); sin medición dedo a dedo | secondary / estimate |
| Arcos del casuario 41°, guacamayo 136°, gorrión 105,3°; emú, avestruz, gato y espolón, con el caso más parecido (unidad 5g) | Pike y Maitland 2004; Birn-Jeffery et al. 2012 | secondary / estimate |
| Sección alto/ancho: velocirraptor 2,6; tigre 1,8; oso 1,3; rapaces redondas con la cara de abajo plana (unidad 5g) | Norell y Makovicky 1999 (núcleo óseo); el resto, sin medición | primary / estimate |
| Rugosidad de cada pasada: Ra = h/4 con la hondura del surco de cada grano o diente suelto; los surcos de antes se borran al quitar 4·Ra (unidad 5g) | La definición de Ra sobre una onda triangular; del orden del acero lijado (Whitby Abrasives) | estimate |
| Rugosidad de partida: natural 0,31 µm; reforjada pulida 0,05 µm; bloque en bruto 3,2 µm (unidad 5g) | Uña humana, Laubé et al. 2019; lapeado y fundición a la cera perdida, Machinery's Handbook (ANSI/ASME B46.1) | secondary / estimate |
| Quemado de la superficie: de 215 a 230 °C; se va al quitar 0,1 mm (unidad 5g) | Kakkar et al. 2014 y el tope del modelo térmico; un nodo del modelo | secondary / estimate |
| Bloque en bruto de la garra rota: la pared de la funda de sobra (1 mm) (unidad 5g) | La funda de la reforja (`ForgeData.SHEATH`, elección del ensayo) | estimate |
| El calor de limar el bloque: la conducción, la densidad y el calor específico de su material, en serie con la queratina; el largo equivalente L·√(α_queratina/α_bloque); el tope de cada material (unidad 5j) | Las fichas de la reforja (`docs/fisica/reforja.md`, §10 y §15.2) | secondary (los materiales) / estimate (el modelo) |
| El acrílico dental de la prótesis de verdad: ~20 HV, 2,6 GPa, 84,4 MPa, 1,63 MPa·√m, 1,18 g/cm³; se ablanda a 125 °C (unidad 5j) | PMMA de las prótesis dentales: Zafar 2020; Barbosa et al. en Alqutaibi et al. 2023 | secondary (la dureza, estimate) |
| La prótesis de acrílico en una garra: la técnica del pico (rellenar, fraguar en frío, limar; rehacer cada 8-12 semanas) (unidad 5j) | Samour 2006, pp. 927-928; Matta et al. 2022 | estimate (caso parecido: el pico) |
| Desgaste de la herramienta: K suave 4,5·10⁻⁵ y severo 1,5·10⁻² (unidad 5l) | Pintaude et al. 2009 (vidrio sobre aceros; el suave, en uno de 706 HV), recogido en Pintaude 2021 | secondary |
| Del suave al severo entre ρ = 0,8 y 2; nada por debajo de ρ ≈ 0,38 (unidad 5l) | Richardson 1968 (0,8) y la curva del banco; la cesión de Johnson con H = 2,8·Y y el pico de Hertz | secondary / estimate |
| El desgaste se reparte por la tira de la cara que recorre el contacto (150 mm la lima de acero; 110 mm la de diamante; 180 mm la de cartón; la vuelta del tambor, π·12,7 mm, y su banda de 12,7 mm) (unidad 5l) | DIN 8349 (la lima); las de diamante y de cartón, las de la bandeja; las bandas 407 y 408 de Dremel | secondary / estimate |
| Embotada o vidriada con el doble de radio de los filos (unidad 5l) | Elección del aviso (Hokkirigawa y Kato: con más radio, el filo pasa de cortar a arar) | estimate |
| Rozamiento sin morder: con el diamante 0,1; corindón sobre cerámica dura 0,2; acero sobre gema 0,5 (unidad 5l) | Tablas de los manuales (RoyMech, Engineers Edge); Barrett 1990 (NASA RP-1228): carburo sobre carburo 0,2 | secondary / estimate |
| Fuerza de la mano 538 N (313 N las mujeres); palancas de los cortaúñas ×4, ×3,5 y ×10 (unidad 5l) | Mathiowetz et al. 1985; geometría estimada de uno de cada tipo | secondary / estimate |
| Cortar la sección pide τ·A: τ = σ/√3 en los dúctiles y τ = σ en los frágiles (unidad 5l) | von Mises y la tensión principal; la tensión de flujo de Tabor (H/2,8) y la resistencia de la queratina de Taylor et al. 2004 | estimate (cota alta) |
| Régimen frágil: el surco entero por encima de d_c de Bifano (unidad 5l) | Bifano et al. 1991; sin las grietas laterales de Evans y Marshall 1981 | estimate (cota baja) |
| El color de lo que sale: la raya de los minerales (unidad 5l) | Handbook of Mineralogy (corindón y cuarzo, blanca; hematites, pardo rojiza; moissanita, gris verdosa); lo demás, dibujo | secondary / dibujo |
| Cómo cae lo que sale: v = ρ·g·d²/(18·μ), con μ del aire 1,81·10⁻⁵ Pa·s (unidad 5l) | Stokes 1851; Incropera et al. 2007, tabla A.4 (interpolando a 20 °C) | secondary (en la escena, el polvo fino con un rozamiento tope de 60/s: dibujo) |
| Chispas del metal duro (51 mm, naranja claro, sin estallidos) y del titanio (blanco, como el hierro); el oro, ninguna (unidad 5l) | TC 9-237, tabla 7-5, fila 13; Kelley y Blickensderfer 1974 (RI 7902); el oro, como el cobre (fila 15) | secondary / estimate |
| Volumen de sangre: aves 10 % del peso; tigre 5 % (el gato, 40-60 mL/kg); oso 8,5 % (el perro, 80-90 mL/kg); velocirraptor como las aves (unidad 5o) | LafeberVet (Pollock y Powers 2015); MSD (Blois 2024) | secondary (aves) / estimate (los demás) |
| Sangre que se puede perder sin peligro, 10 %; aviso al 20 % y la sesión se para al 30 % (el 40 % es irreversible) (unidad 5o) | LafeberVet; Rudloff 2002 | secondary / estimate (márgenes) |
| Una garra cortada hasta la carne viva sangra ~0,05 mL/s (una gota por segundo) (unidad 5o) | sin medición; la gota de un gotero (20 por mL) | estimate |
| Los límites del estrés (0,4 / 0,7 / 0,9), 3 movimientos de dolor, el segundo toque a un animal grande sin sedar (unidad 5o) | rúbrica pedagógica; Samour 2006, Cat Tales 2024, Animals Asia (lo que se hace de verdad) | estimate |
| Un toque del torno, 3 s (unidad 5o) | Dremel («a few seconds at a time, with short breaks») | estimate |

Las entradas completas, bandas y citas están en `claw_care_data.gd`; las geometrías del banco provienen de `data.gd` y de la reconstrucción de `velociraptor.gd`. Los umbrales de lesión y el radio de punta no son mediciones en rapaces.

## 8. Estimaciones y preguntas abiertas

**Las patas (unidad 5c):** cada garra de cada pata es su propia `ClawCare` (dos patas la rapaz y el velocirraptor, cuatro
el tigre y el oso), con su propia carne viva oculta en la banda de su animal. Desde la unidad 5g, cada dedo tiene su forma
(`CareData.CLAW_SHAPES`, §11.4): las rapaces, medidas dedo a dedo (Fowler et al. 2009); el tigre y el oso, sin medición dedo
a dedo, con la garra del banco en todos sus dedos, y sus patas traseras como las de la mano (estimación: así lo dice
«Valores y fuentes»). En el velocirraptor solo se trabaja la garra en hoz del dedo II de cada pie (los dedos III y IV no
tienen ficha).

**El limado según la dureza (unidad 5l):** el desgaste de la herramienta contra algo mucho más blando (por debajo de ρ ≈ 0,38
se toma nulo), cómo se reparte entre los granos que tocan (el 10 %), el embotamiento por lo que se pega a la herramienta, el
rozamiento del corindón contra el zafiro o la moissanita (se toma el del carburo sobre carburo), la palanca de cada cortaúñas y
las grietas laterales de los frágiles no están medidos: son estimaciones con el caso medido más parecido o preguntas abiertas
(§11.12.9).

No se ha medido la posición de la carne viva respecto al hueso ni el crecimiento de estas especies en cautividad. Tampoco se dispone del radio de punta, geometría de cada diente o grano, tenacidad entre capas, calor específico de la garra, fracción del calor que entra en la garra, coeficiente de fricción contra queratina ni respuesta térmica del lecho ungueal. Se usan análogos identificados en la tabla: ave, gato, tejón, uña humana, cuerno y acero. ¿Cuál es la variabilidad entre especies y edades, y cómo cambia tras remojo o desgaste real? Son preguntas abiertas, no mediciones implícitas. El velocirraptor anestesiado es una reconstrucción hipotética.

## 9. Qué no predice

No predice la práctica segura de un procedimiento veterinario, dosis anestésicas, infección, vascularización individual ni curación. El perfil axisimétrico no resuelve la curvatura tridimensional, capas reales o desprendimiento de cada lámina. La grieta, el desgaste y el calor son estimaciones simplificadas, no una calibración in vivo; los índices de dolor y estrés y la nota no son magnitudes clínicas. Las garras reforjadas son materiales experimentales del banco, no tratamientos veterinarios.

## 10. Guía de integración (unidad 5b)

Crear `ClawCare.new({ "animal": "rapaz", "claw": "aguila", "inlay": "none", "quick": "oculta", "seed": "..." })`; animales: `rapaz`, `tigre`, `oso`, `velociraptor`. La escena debe mantener una instancia por ensayo y no modificar sus diccionarios internos. Llamar a `file({tool, zone, angle_deg, at_mm, length_mm, force_n, travel_mm, speed_mm_s, direction})`, o para `torno`, `dwell_s` y `rpm`; `clip({tool, remove_mm})`; `hemostasis({tool, pressure_s})`; `apply({tool})`; `set_humidity()`, `set_sedation()` y `advance(seconds)`. Las unidades son mm, N, rpm, s y grados. `setup()` y `serial()` permiten reiniciar y repintar solo al cambiar; `snapshot()` devuelve copias de `profile.s/r/core`, `claw`, `tip`, `thermal.cells`, `bleeding`, `damage`, `animal` y `events`; `report()` devuelve nota, veredicto y consejos. `sfx_for(action, result)` devuelve un id de los sonidos existentes del laboratorio (el zumbido continuo del torno lo pone la escena).

Desde la unidad 5c, la página lleva una `ClawCare` por garra de cada pata (`ClawCareState`: `paws_of`, `DIGITS`,
`select_claw`, `set_paw`, `set_digit`; `care` y `calls` son los de la garra elegida, y la nueva se pone al día con
`advance()`); la sujeción es del animal y pasa a todas sus garras. La amoladora es otra herramienta de tipo «torno»
(`CareData.TOOLS.amoladora`).

Desde la unidad 5g (§11): `probe_tip()` (probar la punta); `ClawCare.new(setup, patient)` con el animal compartido
(`ClawCarePatient`) y `setup.digit`, `setup.paw` y `setup.block` (la garra de cada dedo y el bloque en bruto de la garra rota);
`natural_mm()`; en la instantánea, `thermal.zone`, `sZone`, `dxMm`, `axis` y `spanMm`, `claw.digit`, `hind`, `arcDeg`,
`arcInnerDeg`, `arcMethod`, `sectionRatio`, `ventralFlat`, `shapeQuality`, `shapeSource`, `claw.block`, `shape` (la forma en
directo), `damage.breaks` y `lastBreak` (la rotura con su sitio) y `surface` (la superficie por estación); `file()` devuelve
`raUm`. En `ClawCareState`: `patient`, `history`, `probe_tip()`, `reforge_request()` y `reforge_with(fs)`. El arco de
cualquier garra del banco, para dibujarla: `CareData.claw_arc(claw_id, digit, hind)`.

Desde la unidad 5j (§11.11): `ClawCare.supports_block(id)` (los materiales que la cetrería lima como bloque: los del banco y
el acrílico dental) y `ClawCare.block_thermal(id)` (cómo conduce el calor el bloque); en la instantánea, `claw.block.thermal`
(o null, si se cuenta como la queratina) y `thermal.blockHot`; en `ClawCareState.view()`, `reforge_request` (los ajustes de
la garra rota sin reconstruir para la reforja, o `{}`).

Pintar estuche y núcleo con el perfil, faceta y cara plana con `tip`, grietas y escamas con `damage`, termómetro con `thermal`, y mostrar la carne viva a trasluz solo donde `quickVisible`; no revelar el valor de `quick` oculto antes de la comprobación. `tutorial(process)` devuelve pasos con `title`, `text`, `source`, `check` y `done`; procesos definidos en `claw_care_tutorial.gd`, incluida preparación, limado, reparación y cuidado posterior. Los efectos cortos vienen de `sfx_for`; los avisos de sangre, deshojado, calor, mella y movimiento aparecen en `events`. Probar la escena contra `test_claw_care.gd` y `test_claw_care_spec.gd`; no editar a mano los golden del banco.

## 11. La pasada de física de la unidad 5g (peticiones 35 a 37)

Lo que pidieron la 5b, la 5c y la 5d, y después Eric en las peticiones 35, 36 y 37. Los datos van con su fuente y su calidad
en `claw_care_data.gd`; las tablas de §7 y §8 tienen las filas nuevas. Los tests, en `test_claw_care_materiales.gd`,
`test_claw_care_pulido.gd`, `test_claw_care_dedos.gd`, `test_claw_care_bloque.gd` y `test_care_page_probar.gd`.

### 11.1 El rubí y la alúmina de la reforja, en el banco y en la cetrería

Los dos materiales nuevos de la 2.0 (`ForgeData.NEW_MATERIALS`) entran en el catálogo 2.0 (`Catalog.V2_INLAYS`) con su
nombre y su color, sin tocar el oráculo 1.x (`Data.INLAYS`). `ClawMass` (densidad), `ClawFracture` (resistencia, tenacidad
y forma de romper) y `ClawSharpness` leen sus datos: el rubí es corindón, con la mecánica del zafiro salvo el color (un test
compara la misma sesión con los dos); la alúmina, la sinterizada de 99,5 % (CoorsTek AD-995: 3,90 g/cm³, 379 MPa, 4,5 MPa·√m).
La cetrería los lima con su id (`ClawCare.supports_inlay`), `ClawForge.care_setup()` los pasa con su id y no «como zafiro»,
y la página los deja elegir (`ClawCareState` valida contra `Catalog`). El golden 2.0 no cambia: solo se añaden materiales.

### 11.2 Probar la punta

`ClawCare.probe_tip()` (en la página, el botón «Probar la punta» y la tecla T) apoya el **vértice** en la uña del banco
(25 HV, 2,9 GPa, μ = 0,3) y lo pasa de lado con un toque de 0,5 N, como se prueba un filo en la uña. Al limar, la carga va a
mitad de la faceta; aquí va al vértice (x0 = 0), así que una punta de aguja de queratina se puede mellar.

- **¿Prende?** La uña cede bajo la punta cuando la presión de Hertz pasa de 1,6·H/2,8 (Johnson 1985): esa fuerza crece con
  R². La punta natural del águila marca la uña desde ~107 mN: con el toque, prende.
- **¿Aguanta?** La carga de lado μ·F en el vértice contra lo que aguanta la punta (la viga en voladizo de
  `claw_sharpness.gd`, que crece con R²; Pattrick et al. 2018): ~735 mN la natural del águila. Frágil, se mella
  (`ClawFracture.broken_length_mm`); mojada y dúctil, se dobla.
- **La distancia crítica de Taylor** (2007), L = (K_c/σ)²/π, con K_c = √(E·J) de la queratina (el módulo de la garra de
  avestruz y el trabajo de rotura de lado de la uña: estimación), da ~1-1,5 mm: más que la sección más cargada de una punta.
  El modelo se queda del lado seguro y lo dice (`sizeEffect`).
- Invariante: una punta más afilada nunca aguanta más la prueba.

### 11.3 Dónde está el calor

`snapshot().thermal` dice `zone` («punta» o «flanco»), `sZone` (dónde entra el calor, mm desde la base), `dxMm` (el paso de
los nodos), `axis` y `spanMm` (el tramo de garra que cubre cada nodo). La escena ya no lo deduce de la última acción.

### 11.4 La forma de cada garra, dedo a dedo, y el arco de cada garra del banco

`CareData.CLAW_SHAPES`: por garra del banco, cada dedo con `length_ratio` (el largo, el arco medio, frente al dedo de
referencia), `base_ratio` (el alto de la base), `arc_deg` (el ángulo del arco de la curva exterior, método de Pike y
Maitland 2004) y `arc_inner_deg`; la garra, con `section_ratio` (alto/ancho de la base) y `ventral_flat`; el tigre y el oso,
con `hind` (las patas traseras). El dedo de referencia es la garra de la ficha del banco: sin dedo, nada cambia.

| Garra | Dedos (largo frente al III · arco exterior) | Fuente | Calidad |
|---|---|---|---|
| Águila | I ×1,63 · 134° (el talón, la mayor) · II ×1,39 · 130° · III 124,5° · IV ×0,77 · 127° | águila real MSU ECO-4666 (Fowler et al. 2009, tabla S1); el arco del III, la media de 4 garras (116-133°) | primary |
| Arpía | I ×2,06 · II ×1,54 · III 114,6° · IV ×0,80 | núcleos óseos de AMNH-1383 (Fowler); el arco, 5 garras con estuche (Birn-Jeffery et al. 2012) | secondary |
| Halcón | I ×1,15 · II ×0,99 · III 122,1° · IV ×0,89 | peregrino MOR OST-1265 (Fowler); 7 garras (104-136°) | primary |
| Búho | I ×0,86 · II ×1,01 · III 115,5° · IV ×0,84 | búho americano (Fowler); el arco, el búho real (4 garras) | secondary |
| Lechuza | I ×0,90 · II ×0,93 · III 103,2° · IV ×0,83 | lechuza campestre (Fowler); el arco, la lechuza común (6 garras) | secondary |
| Buitre | I ×0,57 · II ×1,00 · III 81° · IV ×0,80 | aura gallipavo (Fowler); el arco, el buitre dorsiblanco africano, de su género (2 garras) | secondary |
| Tigre | II-V del banco · 98,4° | sin medición dedo a dedo; el arco, la media de 43 garras de tigre (AIWC 2023) | estimate; el arco, secondary |
| Oso | I-V del banco · 98° (el del dibujo) | sin medición; «slightly curved», 51-102 mm (NPS) | estimate |
| Velocirraptor | II, la hoz · 160° (el de dentro) | `velociraptor.gd`: el arco interior de *Deinonychus* (Manning et al. 2006) | estimate |

La sección: la hoja del velocirraptor, medida en su núcleo óseo (18,7 × 7,1 mm: 2,6; Norell y Makovicky 1999); el tigre,
1,8 y el oso, 1,3 (estimaciones entre la rapaz y la hoja medida); las rapaces, redondas con la cara de abajo plana (la
placa ventral; Samour 2006). La física es redonda con el radio del perfil; el dibujo la aplasta sin cambiar el área
(alto = 2·r·√k, ancho = 2·r/√k).

**El arco de cada garra del banco** (lo pidió la 5e: hasta ahora había tres fórmulas de dibujo, 35° + 115°·curva en la
cetrería y la galería, y 180°·curva^1,6 en el coche): `CareData.claw_arc(claw_id, digit, hind)` da `arcDeg`,
`arcInnerDeg`, `method`, `lengthMm`, `radiusMm` (= largo / ángulo), `quality` y `source`. Las de la cetrería, de
`CLAW_SHAPES`; las demás garras de animales, de `CLAW_ARCS`: el casuario (41°, la garra del dedo III; la daga del dedo II,
«recta», no está medida), el guacamayo macao (136°) y el gorrión (105,3°, 7 garras), medidos (Pike y Maitland 2004 y
Birn-Jeffery et al. 2012); el emú (el del casuario), el avestruz (el del ñandú, 31°), el gato (el del tigre) y el espolón del
gallo, estimados. Lo que no es la garra de un animal (uñas de salón, garras de experimento, colmillos, aguijones) conserva
el arco de su dibujo, marcado «dibujo». Un solo ejemplar varía ±15°: por eso el arco del dedo III es la media de lo medido.

`ClawCareState` pasa a cada `ClawCare` su dedo y su pata; la instantánea dice `claw.digit`, `hind`, `arcDeg`,
`arcInnerDeg`, `arcMethod`, `sectionRatio`, `ventralFlat`, `shapeQuality`, `shapeSource` y `curve` (la del dibujo, que da
el arco medido); «Valores y fuentes» enseña la garra del dedo y su sección.

### 11.5 Un animal para todas sus garras

`claw_care_patient.gd` (`ClawCarePatient`, sin nodos): la sujeción, el dolor, los movimientos y el estrés del animal, que
comparten todas sus `ClawCare` y guarda `ClawCareState` (`patient`). Trabajar otra garra no borra el estrés, y el reloj de
la sujeción cuenta cada paso una sola vez (`count_step` solo cuenta los pasos nuevos del reloj). `history` guarda todas las
llamadas del ensayo, de todas las garras y en orden: unas `ClawCare` nuevas con un animal nuevo llegan a lo mismo (test).

### 11.6 El consejo del calor

Habla de la herramienta giratoria que se haya usado (el torno, la amoladora o las dos) y de su velocidad más baja, la de su
ficha (6500 rpm el torno, Dremel 7300-PT; 8000 la amoladora, Dremel Lite 7760). Si se ha usado más deprisa, dice cuánto más
calienta con la misma fuerza (P = ε·μ·F·v, v = π·D·n). `ClawCareState` ya no lo arregla por su cuenta.

### 11.7 La forma en directo y la rotura con su sitio (petición 35)

`shape()` (en la instantánea, `shape`): después de cada pasada, un veredicto con lo que ya calcula el motor y los márgenes
del informe: rota, pasada de la carne viva, demasiado fina (aguanta de lado menos de la cuarta parte que la natural), al
borde de la carne viva, roma (más del doble de radio), facetada (la faceta se aparta más de 10° de la garra), aún larga,
correcta o afilada. Invariante: quitar más material de la punta nunca la hace más resistente.

`damage.breaks` y `damage.lastBreak`: cada rotura con su sitio (`sMm`, mm desde la base), el trozo que se va (`fromS`,
`toS`, `pieceMm` y su perfil, para que la escena lo separe y lo deje caer), el tipo (corte, raja, mella, pared…), si llega a
la carne viva, cuándo y con qué herramienta.

### 11.8 La garra rota que vuelve de la reforja como un bloque en bruto (petición 35)

`ClawForge.care_setup(ajustes con stump_mm)`: en cuanto la pieza del horno (o la comprada) sale bien y se enfría, sin tallar,
la garra rota vuelve a la cetrería como el muñón de queratina (hasta `stump_mm`, con su carne viva) y un bloque en bruto del
material pegado encima: un cilindro con la pared de la funda de sobra alrededor y delante del largo natural, de cara plana y
con la rugosidad de una pieza sin tallar (como el bloque del que la reforja talla la funda: `ClawForge.sheath_geometry`).

- Cada sitio se lima con su material (`ClawCare._mat_at`): la lima de acero resbala sobre el zafiro y muerde la queratina del
  muñón; la de diamante talla el zafiro; el diamante solo lo talla el diamante, y despacio.
- La carne viva se queda en el muñón; la forma final se juzga como la de la garra natural (el largo y la punta de su ficha).
- El calor de limar el bloque va por la conducción de su material (unidad 5j, §11.11); hasta la 5j se contaba con la de la
  queratina, que solo vale para el acrílico.
- **FICCIÓN** (`block.fiction`, con la nota): en la realidad la funda o la prótesis se talla aparte (muelas y discos de
  diamante con agua; horas en las gemas) y se pega en frío ya terminada; en el animal solo se pega y se lima una prótesis de
  acrílico (metacrilato, como en las prótesis de pico; Samour 2006). Desde la unidad 5j esa vía real está en el laboratorio:
  el bloque de acrílico dental no lleva la marca (§11.11).
- `ClawCareState.reforge_request()` da los ajustes de la garra rota y `reforge_with(fs)` la cambia por la del bloque, del
  mismo animal y al día con el reloj, solo si ya no sangra; `history` lo apunta como «reforge».

### 11.9 La superficie de la garra (petición 37)

`snapshot().surface`, por estación de `STATION_MM` de la base a la punta, según «La cetrería en alta definición y la
superficie de la garra» de CONTRATOS: `ra_um`, `burn` (0-1), `chip` (0 o 1) y `scratch_deg` (0-180°, respecto al eje).

- **La rugosidad que deja cada pasada:** Ra = h/4, la de un perfil de surcos en V de hondura h (la media de |z| de una onda
  triangular), con la hondura del surco de cada grano (la misma de `element_cut`, que da el arranque) o de cada diente suelto
  de una lima de picado doble (~(dientes/cm)² por cm², cada uno como un grano de su geometría; `groove_um`). A 4 N en el
  flanco del tigre: la bastarda 3,2 µm, la entrefina 2,0, la fina 1,5, la lija P180 0,6, la P240 0,4, la de diamante gruesa
  0,26, la fina 0,08 y el tambor de grano 60 del torno 2,5. Del orden de lo medido, quizá por lo bajo: el acero lijado queda
  en ~0,8-1,5 µm con P150-P240 y en ~3-5 µm con P40-P60 (Whitby Abrasives, bandas orientativas).
- **La regla** (`next_ra`): una herramienta más gruesa la deja con la suya enseguida; una más fina la pule hacia la suya a
  medida que quita, y los surcos de antes se van cuando ha quitado su hondura (4·Ra); sin quitar nada, no cambia.
  Invariantes con test: más fina nunca deja más rugosidad, y sin quitar material la rugosidad no cambia.
- **De partida:** la garra natural, 0,31 µm (la uña humana medida con perfilómetro: 308 ± 52 nm, Laubé et al. 2019); una
  reforjada, pulida (0,05 µm, el lapeado); el bloque en bruto, 3,2 µm (la fundición a la cera perdida; Machinery's
  Handbook).
- **El quemado:** de 0 a 1 entre la desnaturalización de la queratina (215 °C) y el tope del modelo (230 °C), donde entra el
  calor y mientras entra; se va al limar su capa (0,1 mm, un nodo del modelo térmico).
- **Los desconchones:** en un material frágil reforjado, una pasada más honda que la del régimen dúctil de Bifano
  (d_c = 0,15·(E/H)·(K_c/H)², la misma fórmula que la reforja) desconcha; puliendo en régimen dúctil se van. La queratina
  limada en contra de las capas se deshoja (las escamas) y las grietas abiertas también se ven como desconchón.
- `file()` devuelve `raUm`, la rugosidad que deja la pasada donde quita; `surface_stations()` da la misma superficie como
  lista de estaciones, la forma que lee `ClawMaterial.surface_image` (5e).

### 11.10 Lo que queda

- Las garras dedo a dedo del tigre y del oso, y las de sus patas traseras: sin medición publicada que hayamos podido leer.
- El alto y el ancho de la base de las garras de las rapaces, los felinos y los osos (la sección es una estimación salvo en
  el velocirraptor).
- La rugosidad de una garra limada (la natural es la de la uña humana).
- Hechos en la unidad 5j (§11.11): el calor de limar un bloque de metal o de cerámica, con la conducción de cada material, y
  la prótesis de acrílico de verdad, por «Reforjar con material». El metacrilato de la bandeja sigue marcando la garra como
  reconstruida sin cambiar su forma.

### 11.11 La pasada de pulido de la reforja (unidad 5j)

Lo que dejaron la 5f y la 5g. Tests en `test_claw_care_bloque.gd` (y los de la reforja, `docs/fisica/reforja.md` §15).

- **La prótesis de verdad.** Con la garra rota, «Reforjar con material» ofrece el acrílico dental junto a las recetas de
  fantasía. Se mezcla en el laboratorio y vuelve aquí como un bloque con la pared de sobra sobre lo que queda de la garra,
  **sin ficción**: así se rellena el pico de las aves («methacrylate glue and baking soda or commercially available beak
  repair kits», rehecho cada 8-12 semanas porque crece: Samour 2006, pp. 927-928). El acrílico dental fragua en frío y ya
  fraguado se le da forma con una amoladora; una prótesis sin anclar se cae cuando se renueva la queratina (Matta et al.
  2022). En una garra, la misma técnica: estimación (`block.quality = "estimate"`).
  - `ClawCare.supports_block("acrilico")` y el bloque, de `ForgeData.PROSTHESIS` (el PMMA de las prótesis dentales).
  - Es más blando que la garra (~20 HV frente a 28-33 HV de las rapaces): la lima de acero lo muerde y se gasta antes.
  - Su punta aguanta con su resistencia (84,4 MPa y 1,63 MPa·√m); antes, sin datos, no se predecía.
  - El aviso del bloque dice que así se hace de verdad, sin «FICCIÓN».
- **El calor de limar el bloque** (`ClawCare.block_thermal`): cada nodo del modelo térmico lleva el material de su sitio.
  - La queratina del muñón y de la carne viva, o el bloque con su conducción, su densidad y su calor específico (la ficha de
    la reforja).
  - Entre dos materiales, las dos mitades en serie.
  - El bloque va del lado de la cara: hasta dónde llega el calor se cuenta con el largo equivalente de queratina,
    L·√(α_queratina/α_bloque), contra los 12 mm de `max_depth_mm`.
  - Cada nodo con el tope de su material: la queratina se quema a ~230 °C; el bloque se funde, se ablanda (el acrílico a
    125 °C) o se oxida al aire (el diamante a 600 °C), con el suceso «bloque_calor». La superficie del bloque se marca como
    quemada en los 15 °C antes de su tope.
  - Sin datos de conducción (la hematites), como la queratina; sin bloque, el modelo no cambia (al bit).
  - Con 0,5 W en la punta, 20 s, sobre el muñón de 20 mm del águila: el acrílico deja la cara a 74,8 °C y la carne viva
    a 32,00 °C; el oro, la cara a 35,0 °C y la carne viva a 34,8 °C. El metal reparte el calor, pero lo lleva antes a la
    carne viva.
  - Invariantes con test: con el mismo calor, un bloque que conduce y difunde más nunca deja la carne viva más fría ni la
    cara más caliente; en régimen, el calor cruza el bloque y la queratina en serie; el acrílico calienta como la queratina.
  - El reparto del calor del roce (ε = 0,5) y la fricción de la lija siguen siendo los de la queratina: con una muela
    convencional, el acero se queda con el 60-85 % (Malkin y Guo 2007). En un bloque de metal llegaría algo más.
- **La vista para la reforja:** `ClawCareState.view().reforge_request` publica `reforge_request()` con la garra elegida rota y
  sin reconstruir (`{}` si no). La página de la cetrería debe leerlo de ahí en vez de rehacerlo con los ajustes y el largo de
  la instantánea: es de la 5h (`care_page.gd`), y queda pedido.

### 11.12 El limado según la dureza y la abrasión (unidad 5l, petición 38)

Eric: «mira que el limado de las garras con los diferentes materiales sea el correcto físicamente, y en diseño y modelaje,
que las herramientas funcionen bien, según el nivel de dureza y abrasión». La auditoría del coordinador (las 9 herramientas
de limar y los 3 cortaúñas contra los 15 materiales de la garra) dio por buenos qué muerde (la eficacia de
`Contact.hardness_efficiency`, Pintaude), cuánto quita (Archard, al revés que la dureza) y la rugosidad, y encontró seis
huecos: sin morder no había calor, las herramientas no se gastaban, los cortaúñas cortaban garras macizas de metal solo por
ser más duras, los frágiles se limaban como los dúctiles, el Ra de una pasada que no muerde confundía y solo el acero echaba
chispas. Datos con su fuente en `claw_care_data.gd` (`TOOL_WEAR`, `RUB_FRICTION`, `CLIP_FORCE`, `DEBRIS_COLOR`,
`SPARK_MATERIAL`); el estado de las herramientas, en `claw_care_kit.gd`; tests en `test_claw_care_limado.gd`.
`Contact.hardness_efficiency` y `core/shared` no cambian: lo que la cetrería necesita de más va en su código.

**La matriz herramienta × material** (la garra del águila, 3 N, de frente a la punta: 30 mm a mano o 2 s con el torno y la
amoladora; mm³ arrancados en la pasada, con la η de la dureza si no es 1; F: régimen frágil, §11.12.4). La de antes era igual
salvo donde se dice:

| Material (HV) | Lima de acero bastarda / fina (700 HV) | Diamante gruesa / fina (10 000 HV) | Cartón P180 (corindón, 2000 HV) | Torno / amoladora (corindón) |
|---|---|---|---|---|
| Queratina (32) | 0,287 / 0,287 | 0,058 / 0,032 | 0,099 | 30,4 / 37,4 |
| Oro (30) | 0,306 / 0,306 | 0,062 / 0,034 | 0,106 | 32,4 / 39,9 |
| Acero (200) | 0,039 / 0,033 | 0,0093 / 0,0047 | 0,016 | 4,86 / 5,98 |
| Titanio (150) | 0,059 / 0,049 | 0,012 / 0,0066 | 0,021 | 6,48 / 7,98 |
| Vidrio (550) | 0,0057 F (η 0,34; antes 0,0034 / 0,0024) | 0,0032 F / 0,0012 F | 0,0058 F | 1,77 F / 2,17 F |
| Hematites (1000) | no muerde | 0,0015 / 0,0004 | 0,0032 | 0,86 / 1,02 (antes 0,97 / 1,20: se embota en la pasada) |
| Cuarzo (1100) | no muerde | 0,0013 F / 0,0004 F | 0,0027 F (η 0,94) | 0,68 F / 0,79 F (antes 0,83 / 1,02) |
| Circonita (1300) | no muerde | 0,0010 F / 0,0003 F | 0,0016 F (η 0,67) | 0,36 F / 0,42 F (antes 0,50 / 0,62) |
| Alúmina (1438) | no muerde | 0,0009 F / 0,0002 | 0,0010 F (η 0,49) | 0,23 F / 0,26 F (antes 0,33 / 0,41) |
| Zafiro y rubí (2000) | no muerde | 0,0006 F / 0,0001 F | 0,0001 F (η 0,07) | 0,009 F / 0,011 F (antes 0,036 / 0,044: se vidria en la pasada) |
| Carburo de tungsteno (2000) | no muerde | 0,0006 / 0,0001 | 0,0001 F (η 0,07) | 0,008 / 0,009 (antes 0,036 / 0,044) |
| Moissanita (2800) | no muerde | 0,0003 F / 0,0001 F | no muerde | no muerde: roza y calienta 1,30 / 1,60 W (antes 0 W) |
| Diamante (10 000) | no muerde | ~0 (η 0,07) | no muerde | no muerde: roza y calienta 0,65 / 0,80 W (antes 0 W) |
| Acrílico dental, bloque (~20) | 0,042 / 0,033 | 0,020 / 0,0048 | 0,095 | 48,6 / 59,8 |

Lo que muerde y lo que no sale igual que antes (la η de Pintaude del banco). Lo nuevo es lo que pasa además: la herramienta
que no muerde (o casi) se gasta y, si gira, calienta; el tambor de corindón se vidria contra lo que es tan duro como él
dentro de la misma pasada de 2 s, y por eso arranca menos que antes del zafiro, el rubí, el carburo, la alúmina, la circonita
o el cuarzo; el vidrio y el cristal, frágiles, se arrancan algo más con la lima de acero (el surco entero).

#### 11.12.1 Lo que se gasta cada herramienta

- **Archard con la razón de durezas al revés:** la garra «raya» a la herramienta con ρ = H_garra/H_herramienta, y la
  herramienta pierde ΔV = K(ρ)·F·L/H_herramienta (`ClawCare.tool_wear_mm3`), con L todo lo que desliza apretada (también la
  vuelta de una lima en vaivén y lo que roza sin morder).
- **K(ρ)** (`ClawCare.tool_wear_k`; `CareData.TOOL_WEAR`):
  - el suave, K = 4,5·10⁻⁵, y el severo, K ≈ 1,5·10⁻², unas 330 veces más, medidos por Pintaude et al. (2009) con partículas
    de vidrio sobre aceros y fundiciones de distinta dureza (el suave, en el más duro, de 706 HV: el caso de la lima de acero
    contra el vidrio, ρ ≈ 0,8);
  - del suave al severo, con la curva del banco entre ρ = 0,8 (Richardson 1968: por debajo de ~0,8 veces la dureza del
    abrasivo el desgaste cae mucho) y ρ = 2 (Contact.hardness_efficiency);
  - por debajo de ρ ≈ 0,38, nada: la garra cede antes de deformar los filos (su presión no pasa de su dureza, el pico de
    Hertz es 1,5 veces la media y los filos empiezan a ceder a 1,6·H/2,8, las constantes del banco); de 0,38 a 0,8 sube
    hasta el suave. Estimación: sin medición del desgaste de una herramienta contra algo mucho más blando.
- **Dónde se gasta:** el volumen se reparte por los filos de la tira de la cara que recorre el contacto (el ancho del contacto
  por el largo de la cara: la lima de 150 mm de DIN 8349, la de diamante y la de cartón de la bandeja, la vuelta del tambor);
  en un diente de semiángulo θ, δ²·tan θ por mm de arista; en un grano de los que tocan (el 10 %), (π/3)·tan²θ·δ³. Queda una
  plataforma de semiancho δ·tan θ (sin pasar del medio ancho del propio grano o del medio paso del picado) que corta como una
  punta redonda de radio δ·tan θ/cos θ, combinada con la de nueva: R = √(R0² + R²) (`ClawCareKit`).
- **Lo que cambia al cortar:** ese radio entra en el arranque (`element_cut`, con el `tip_um` de `ClawCareKit.worn_tool`): con
  la punta más redonda, cada filo penetra menos, el grado de penetración baja y pasa de cortar a arar (Hokkirigawa y Kato). Y
  la punta que deja en la garra es la de su filo gastado. Una nueva de la bandeja (`renew_tool`; en la página, la tecla N y el
  botón «Una nueva») vuelve a cortar como el primer día.
- **Lo que sale** (40 pasadas seguidas como las de la matriz; `test_claw_care_limado.gd`):
  - la queratina, el oro, el acero, el titanio y el acrílico no gastan ninguna herramienta en un ensayo (ρ < 0,38);
  - la lima de acero contra el vidrio: el régimen suave, se gasta algo pero no se embota (60 pasadas: filos de 10,01 µm); la
    coordinación esperaba que se embotara: con los datos de Pintaude, medidos justo con vidrio sobre un acero de 706 HV, no
    en un ensayo;
  - la lima de acero contra lo que es más duro que ella (hematites, cuarzo, circonita, alúmina, zafiro, rubí, carburo,
    moissanita, diamante) se embota mientras resbala: 40 pasadas la dejan usada (filos de 12-15 µm) y contra el zafiro, en
    ~180 pasadas, embotada (el doble de radio, `dull_ratio`; se avisa una vez);
  - el corindón (lija P180 y P240, torno y amoladora) se vidria contra el zafiro, el rubí, el carburo, la moissanita y el
    diamante (tan duros o más que él): el tambor, en 1-2 s; la lija, en ~40 pasadas; contra la hematites, el cuarzo, la
    circonita y la alúmina se gasta despacio, y el tambor, que concentra el roce en pocos granos, se vidria en ~1 min y
    arranca la décima parte (por eso las cerámicas se rectifican con diamante: el manual técnico de Haefeli, el mismo dato
    de `core/taller/sharpening.gd`);
  - el diamante solo se gasta contra el diamante (100 pasadas: usada).
- **Invariantes con test:** K no baja al subir ρ; lo blando no gasta la herramienta; una gastada nunca quita más que una
  nueva, y una nueva vuelve a quitar lo de la primera vez; el kit es del ensayo (lo que se gasta en una garra cuenta en las
  demás del animal) y `history` lo repite con un kit compartido (`renew_tool`).

#### 11.12.2 El roce sin morder calienta

- P = ε·μ·F·v con el μ del rozamiento: el del amolado mientras la herramienta muerde (THERMAL.friction, 0,325) y, si no muerde,
  el de la pareja (`ClawCare.rub_mu`; `CareData.RUB_FRICTION`): con el diamante (de herramienta o de garra), 0,1 (diamante
  sobre diamante y sobre metal, de las tablas de los manuales); el corindón sobre otra cerámica dura (el zafiro, el rubí, la
  alúmina, el carburo, la moissanita), 0,2 (el par medido más parecido, carburo de tungsteno sobre carburo: Barrett 1990,
  NASA RP-1228); la lima de acero sobre una gema, 0,5 (el carburo y el vidrio sobre acero, de las mismas tablas). Entre
  morder y no morder, η·μ_amolado + (1 − η)·μ_pareja (suposición del modelo: la carga que llevan los filos que cortan).
- En la queratina, que todo lo muerde, el calor es exactamente el de antes (test).
- Una giratoria que roza sin morder no arranca nada, pero calienta: la moissanita con el torno a 6500 rpm y 3 N, 1,30 W; el
  diamante, 0,65 W. Se avisa una vez («roce») y suena a chirrido (el roce, 1,6 veces más agudo: diseño de sonido). En un bloque
  sobre el muñón (el modelo térmico de la 5j) ese calor llega a la cara y, por conducción, a la carne viva; en una garra
  reforjada entera no hay modelo térmico (la de la 5a: no tiene carne viva) y solo se dice la potencia.

#### 11.12.3 La fuerza de los cortaúñas

- Cortar la sección entera donde se corta pide τ·A (`ClawCare.clip_force_n`), como cizallar una barra: en un dúctil,
  τ = σ/√3 (von Mises), con la tensión de flujo de un metal (H/2,8, Tabor, con la dureza del banco: el acero, 404 MPa; el
  titanio, 303; el oro, 61) o la resistencia de la queratina a su humedad (natural, 40 MPa; húmeda, 8); en un frágil, τ = σ, su
  resistencia a flexión. Es una cota alta: una hoja afilada que entra poco a poco pide algo menos.
- El cortaúñas da la fuerza de la mano por su palanca (`ClawCare.clip_capacity_n`): 538 N, la mayor de apretar de media
  (Mathiowetz et al. 1985: 121 lb, hombres de 20 a 24 años; las mujeres, 313 N), por ×4 la guillotina (2153 N), ×3,5 la de
  tijera (1884 N) y ×10 las tenazas de herrador (5382 N). Las palancas son geometría estimada de uno de cada tipo.
- Si no llega, no corta y lo dice («no_corta_fuerza»): «hace falta una cizalla, o limarla». Una garra maciza de acero se
  corta en la punta (1 mm: 160 N) y aún a 4 mm (2,3 mm de grueso: 1,7 kN), pero no a 8 mm; el titanio, tampoco a 9 mm; el oro,
  blando, sí. La queratina cabe siempre en lo que dan (la guillotina, con su boca de 7 mm, pide como mucho 1,5 kN natural),
  salvo las garras de ~18 mm del oso y del velocirraptor donde acaba la carne viva: secas piden ~10 kN y ni las tenazas
  llegan; remojadas, ~2 kN, sí (así se ablandan antes de cortarlas: AAD, Farran et al. 2008). Dos tests de la 5a (cortar hasta
  la carne viva del oso y del velocirraptor con las tenazas) remojan la garra cuando seca no llega.
- Invariante con test: un cortaúñas nunca corta lo que pide más fuerza de la que da.

#### 11.12.4 Los frágiles por encima de la hondura crítica

- En un material frágil (el vidrio, el cristal, el cuarzo, la circonita, el zafiro, el rubí, la alúmina, la moissanita, el
  diamante y el carburo), con el surco de cada filo más hondo que la hondura crítica de Bifano et al. (1991),
  d_c = 0,15·(E/H)·(K_c/H)² (la misma que ya desconchaba la superficie, §11.9), lo que se desplaza se rompe y se va: el surco se
  arranca entero en vez del arado de Hokkirigawa y Kato (`removal_mm3` con `brittle`; `regime` = «frágil» en el resultado).
  Del grano, con la sección de su punta (`groove_area_ratio`): uno gastado, más redondo, arranca menos; nunca menos que
  cortando.
- Es una cota baja: las grietas laterales arrancan más (Evans y Marshall 1981), pero la constante de su ley
  (V ∝ P^9/8·(E/H)^4/5/(K_c^1/2·H^5/8)) no está medida para estos materiales y no se ha puesto.
- Con la lima de acero el vidrio pasa de 0,0034 a 0,0057 mm³ por pasada; con la de diamante, el surco ya se arrancaba casi
  entero (corte) y cambia poco.

#### 11.12.5 La rugosidad de una pasada que no muerde

`file().raUm` es la rugosidad que queda donde ha pasado: si no ha quitado nada, la de antes (la superficie no cambia: el zafiro
pulido sigue en 0,05 µm). Antes salía la que dejaría la herramienta si cortase. Y lo poco que arranca una pasada se lee: por
debajo de una milésima de mm³, con dos cifras significativas (`ClawCareState.fmt_mm3`: la lima de diamante en el zafiro,
«0.00057 mm³ fuera»), no «0.000», que parecería que no muerde.

#### 11.12.6 Lo que sale de cada pasada

`file().debris` (`ClawCare.debris_for`): `kind` según cómo rompe el material (`ClawFracture.behavior`): la queratina, polvo;
los metales dúctiles (oro, acero, titanio), limaduras; los frágiles, polvo; el acrílico, virutas. `sizeUm`, el grueso de la
viruta (la hondura del surco de cada filo); `mm3`, lo arrancado; `color` (dibujo): el de la garra para la queratina, el del
metal para las limaduras y, en los minerales, el de su raya, el color del mineral en polvo (Handbook of Mineralogy): blanca
el corindón (el zafiro y el rubí) y el cuarzo, de pardo rojiza a rojo cereza la hematites, gris verdosa la moissanita. Sin
arrancar nada, nada: la herramienta resbala. `settleMs` y `dragPerS`: cómo cae en el aire una partícula del grueso de la
viruta (la ley de Stokes, con la densidad del material y la viscosidad del aire a 20 °C de Incropera et al. 2007): el polvo de
los frágiles es de micras y flota (el del zafiro con la lima de diamante, de 0,4 µm, cae a 0,02 mm/s; el del cuarzo con la
lija, a 0,3 mm/s), y el de queratina de la lima fina, de 46 µm, a 83 mm/s. Las limaduras son láminas unas 5 veces más largas
que gruesas y caen ~10 veces antes que la esfera de su grueso (la resistencia de una lámina va con su largo; el peso, con
largo² por grueso): las de oro del torno, de ~10 µm, a ~0,5 m/s. En la escena, el polvo de los frágiles se dibuja con un
rozamiento tope de 60/s (baja a 0,16 m/s: una nube que se ve caer junto a la punta; el de Stokes flotaría casi quieto) y las
limaduras con el de Stokes entre 10 (dibujo); las virutas del acrílico, como el polvo de queratina.

#### 11.12.7 Las chispas de cada metal

`debris.sparks` da la firma de `core/taller/sparks.gd` de lo que chispea si lo arranca una herramienta giratoria
(`CareData.SPARK_MATERIAL`):
- el acero, la de siempre (el acero de bajo carbono de la tabla 7-5 del TC 9-237);
- el metal duro, `metal_duro`: la fila 13 de la misma tabla (cemented tungsten carbide: volumen «extremely small», 2 in,
  naranja claro, sin estallidos); y Kelley y Blickensderfer (1974, U.S. Bureau of Mines RI 7902), 30 µW/sr·cm² de radiancia
  del haz frente a los 787 del hierro;
- el titanio, `titanio_cp`: no está en la tabla 7-5; Kelley y Blickensderfer midieron 743 µW/sr·cm² (como el hierro) y sus
  chispas «much higher» de temperatura que las del acero: haz blanco; el volumen y la longitud, los del hierro de radiancia
  parecida (estimación);
- el oro, sin chispas: no está medido; el metal noble más parecido, el cobre, no da (tabla 7-5, fila 15; RI 7902, 0).
- La firma «titanio» del taller sigue sin firma (solo se añade: la de las garras es «titanio-cp»).

#### 11.12.8 Lo que se ve y se oye

- **La escena** (`care_3d.gd`): lo que sale de cada pasada, del color de su material (el polvo, algo más claro, y el de los
  frágiles, una nube que baja despacio, §11.12.6; las limaduras, astillas metálicas que brillan; las virutas, más grandes),
  más cuanto más arranca en escala logarítmica (dibujo: así se ve también lo poco que la lima de diamante arranca del
  zafiro); sin morder, nada. Las chispas, las de la firma del motor, solo
  mientras la giratoria arranca de un metal que las da. Las herramientas gastadas se ven gastadas
  (`abrasive.gdshader`: `glaze` y `glaze_width`): en la tira que ha trabajado, la lima embotada (las crestas de los dientes
  aplanadas y pulidas, que brillan) y la banda vidriada (las puntas del grano planas y brillantes), del todo cuando ya está
  «gastada». En el tambor, el lado del `CylinderMesh` solo usa la mitad de la textura (`v_scale`): antes el grano salía
  estirado y la banda gastada habría quedado en un extremo en vez de en medio, donde toca la garra.
- **La página:** el texto de la herramienta dice si está usada o embotada (o vidriada), con el radio de sus filos; el botón
  «Una nueva (N)» aparece con la de la mano gastada; los avisos del motor («roce», «herramienta_gastada», «no_corta_fuerza»)
  van a los sucesos.

#### 11.12.9 Lo que queda

- El embotamiento por lo que se pega a la herramienta (la queratina que llena los poros de la lija, el acrílico que se funde
  en la banda): sin datos de garras; solo se gasta el filo.
- Arrastrar la lima hacia atrás desafila los dientes (Nicholson): el filo se dobla, no se desgasta; no está en el modelo
  (la vuelta solo desgasta lo que dice Archard).
- Las grietas laterales de los frágiles (Evans y Marshall 1981), sin su constante medida.
- El calor de una garra reforjada entera (sin modelo térmico desde la 5a): el roce da su potencia, pero no calienta nada.
- La palanca de cada cortaúñas, medida.
- Cuántas chispas: las de la firma del ensayo (una muela que muerde bien); no siguen a lo que se arranca. El metal duro, que
  el corindón apenas muerde, da a la vez como mucho una chispa en la demo 12 (y daría aún menos si siguieran a lo arrancado);
  el titanio, hasta 58, y el acero, hasta 36.

### 11.13 Colocar a mano la pieza de la reforja (unidad 5o, peticiones 43, 44, 47 y 48)

Eric (petición 43): «El material que se obtenga del banco reforjado deberá engancharse con pegamento especial o, si es
acrílico, con UV LED, o por cualquier otro método realista […]. Todo ello lo tiene que hacer el propio usuario, no la
máquina de forma automática por arte de magia». Desde la 5o, lo que sale de la reforja llega a la cetrería **sin pegar**
(`ClawCareState.receive_piece`) y la garra sigue como estaba (rota o natural) hasta que el usuario la coloca. La física de la
unión está en `core/lab/claw_care_bond.gd` (`ClawCareBond`, una por pieza); los cortantes, las holguras y la queratina que
rompe antes que el adhesivo son los de la reforja (`ClawForge.bond_capacity`, sin cambiarla).

#### 11.13.1 La pieza

- **La funda** (sin `block`): la de la reforja, que cubre el 40 % de la garra desde la punta con 1 mm de pared
  (`ForgeData.SHEATH`); su área pegada, la de `ClawForge.sheath_geometry` con la forma del dedo. Marcada como FICCIÓN: una
  funda de metal o de gema en la garra de una rapaz no se hace de verdad; lo real que se le parece son las fundas de vinilo
  pegadas a las uñas de los gatos y las herraduras pegadas al casco (Ferreira et al. 2024: la unión rompe en el casco).
- **El bloque** de una garra rota (con `block`, FICCIÓN fuera del acrílico): se pega por la cara de la rotura, como lo dibuja
  `ClawCare` (un cilindro en bruto desde el muñón): área π·r² con el radio del muñón donde se rompió.
- **La prótesis de verdad** (el acrílico de la 5j): no es una pieza hecha, se construye sobre el muñón: con el acrílico
  dental o con la resina fotopolimerizable y la lámpara (el usuario elige).
- **La holgura**: la que traiga la reforja (`gap_mm`); si no la trae, la ideal del epoxi de la reforja (0,15 mm).
- **La pieza terminada del laboratorio** (la 5m, unida): `ClawForge.care_setup().piece` trae la forma elegida (lo que cubre,
  `coverMm`: el capuchón el 20 %, la funda el 40 %, la funda larga el 70 % y la prótesis entera toda la garra), la pared que
  le queda después de tallarla (`wallLeftMm`), la superficie que se pega (`bondAreaMm2`, la de `sheath_geometry` con la forma
  del dedo) y la holgura de su prueba del ajuste (`gapMm`: la de diseño más lo que cambió una colada sin compensar). La
  cetrería usa esos números tal cual: una colada que encogió sin compensar (holgura negativa) no entra en la garra y lo dice
  (se arregla en el laboratorio). Una prótesis rígida ya tallada y pulida para una garra rota se pega como una funda sobre lo
  que queda (rehace macizo lo que falta), también FICCIÓN; el bloque en bruto, sin tallar, se pega por la cara de la rotura.

#### 11.13.2 Preparar la garra

| Paso | Qué cambia | Dato | Fuente | Tipo |
|---|---|---|---|---|
| Limpiar y desengrasar (alcohol o clorhexidina) | sin limpiar, el adhesivo aguanta ×0,5 (el metacrilato, ×0,8) | `BOND_PREP.dirty` | fichas de LOCTITE 401 y E-20HP («clean and free from grease»); la guía de Henkel ensaya tras limpiar con isopropanol; el metacrilato «bonds to moderately contaminated surfaces» | estimación |
| Secar | la clorhexidina es agua: mojada, la queratina de la unión es la «húmeda» de `CareData.KERATIN` y el cianoacrilato conserva el 75 % | `ForgeData.ADHESIVES.wet`, `keratin_shear_mpa` | LOCTITE 401 (1000 h en agua) | ficha |
| — | el alcohol se evapora en 30 s; la gasa seca la clorhexidina con 4 s apretada | `BOND_PREP.alcohol_dry_s`, `gauze_dry_s` | — | estimación |
| Lijar un poco | lo que conserva cada adhesivo sobre liso frente a rugoso, interpolado en el logaritmo de Ra entre 0,229 y 1,73 µm | `BOND_PREP.smooth` | Henkel, Design Guide vol. 6, tabla 7 (cianoacrilato en gel 366/1921 psi; epoxi 1670/2160; metacrilato 2630/2820) | ficha (en la queratina, estimación) |

La Ra la deja la lija de verdad: una pasada de la P180 sobre la queratina deja Ra ≈ 0,42 µm (`ClawCare.file().raUm`, §11.9).
Sin preparar (sucia), un cianoacrilato sobre la funda del águila aguanta ~94 N; mojada, 53 (manda la queratina mojada);
limpia y seca, 187; lijada, 259 (manda la queratina). Lo dice `test_claw_care_colocar.gd`.

#### 11.13.3 Pegar una pieza rígida con adhesivo

- **Tiempos** (`CareData.BOND_TIMES`, `PUTTY_TIMES`): el de trabajo (montar antes de que empiece a curar), la fijación (el
  tiempo hasta 0,1 N/mm²) y la plena resistencia, de la ficha de cada uno: cianoacrilato LOCTITE 401 (fija en la queratina
  como en el cuero, 15-30 s: estimación con el sustrato natural de la ficha; plena a las 24 h); epoxi E-20HP (2:1, vida de
  mezcla 20 min, fija hacia las 3 h y casi plena a las 6 h, leídas de su gráfica); metacrilato H8000 (10:1, trabajo 30 min,
  fija en 25-30 min, plena en un día); la masilla de epoxi con acero (J-B Weld Original: 1:1, fragua en 4-6 h, cura en 15-24
  h, 1040 psi = 7,2 MPa de cortante en acero; la holgura y el tiempo de trabajo, los del epoxi: estimación).
- **Lo curado** (`ClawCareBond.cure_fraction`): lineal hasta la fijación (0,1 N/mm²) y lineal en el logaritmo del tiempo de
  ahí a la plena (como se dibujan las gráficas de las fichas: suposición del modelo). Nunca baja.
- **Purgar** las jeringas dobles (la ficha del E-20HP: tirar 25-50 mm): sin purgar, ×0,5 (`BOND_PURGE`, estimación).
- **Colocar y sujetar**: la pieza se coge de la bandeja, se gira al eje de la garra (empieza 14° torcida; se toleran 5° y
  0,5 mm del centro: `BOND_ALIGN`, elecciones del ensayo) y se aprieta mientras se mantiene el botón, la tecla K o el dedo.
  Con el dedo (y con el ratón), se aprieta sobre la pieza de la bandeja y se arrastra sin soltar hasta el muñón: quieta ahí un
  momento (0,35 s), se coloca y queda sujeta mientras siga pulsado. A menos de 14 px del centro del muñón (30 con el dedo) la
  pieza se centra sola (el imán, interfaz: en la vista general un píxel son ~0,7 mm de garra), y lo que se aparta cuenta desde
  ahí; lejos del muñón, apretar no la coloca y lo dice.
  Si se suelta antes de la fijación (sin venda), queda suelta (antes de la mitad de la fijación más corta) o torcida; si se
  mueve más de 0,3 mm (`BOND_HOLD_TOL_MM`), despegada por dentro; si se coloca pasado el tiempo de trabajo, el adhesivo ya
  no pega. Hay que quitarla y empezar de nuevo (limpiar y preparar otra vez). Las colas lentas se sujetan con una venda
  («Bonds should be held fixed or clamped until adhesive has fixtured»).
- El reloj de la cetrería llega ahora a ×60, ×600 y ×3600 para esperar la fijación del epoxi (3 h) o la masilla (5 h), con
  «en la vida real, 3 h; con el reloj a ×3600, 3 s». Sin calor, sin sangre y con la garra fría, el reloj pasa de una vez
  (`ClawCare._fast_count`: da exactamente lo mismo que paso a paso).

#### 11.13.4 El acrílico dental autopolimerizable

- Polvo y líquido 2:1 en peso (3:1 en volumen), 30 s de mezcla, tiempo de trabajo de 3 a 5 min a 23 °C y fraguado en ~10
  min (instrucciones de Veracril); la fase de masa, hacia el minuto y medio (la ficha no da cifra: estimación). Líquida,
  chorrea; pasado el tiempo de trabajo, ya no se pega y hay que mezclar otra. Fuera de la proporción, ×0,8 por cada media parte
  (`ACRYLIC_RATIO`, estimación).
- **Capas** con la espátula, de 1 o 3 mm (`LAYER_MM`), hasta pasar del largo natural con la pared de sobra; cada capa hace
  crecer el bloque de la garra (`ClawCare.grow_block`; el bloque a capas lleva `built_mm`).
- **El calor del fraguado**: −ΔH = 56 kJ/mol del metacrilato de metilo (Odian, tabla 3-14), 100,12 g/mol; el monómero es
  1/(1 + proporción) de la masa y reacciona menos el 4 % que queda (Alqutaibi et al. 2023). Q = ρ·π·r²·h·w·ΔH/M·(1 − 0,04):
  ~5,3 J por mm de capa sobre 3 mm de radio. Sale como un triángulo desde la mezcla hasta el fraguado, con el pico al 80 %
  (la autoaceleración: estimación con las curvas de temperatura del cemento óseo, ISO 5833); lo que salió en el vaso antes de
  aplicarla no entra en la garra. Entra en el modelo térmico de la garra por la cara de arriba del bloque
  (`ClawCare.exotherm`, a trozos de 1 s), con la conducción del acrílico (§11.11): una capa fina sobre el muñón del águila
  lleva la carne viva a ~34,7 °C; una gruesa, a ~37,7 °C. Más gruesa nunca calienta menos (test).
- Hasta que fragua no se lima (en fresco se embadurna); lo que rebosa, con la espátula.

#### 11.13.5 La resina fotopolimerizable con la lámpara

- **La lámpara realista** es la azul de dentista (430-480 nm, 1200 mW/cm²: Elipar S10), donde absorbe la canforquinona, el
  fotoiniciador de casi todos los composites (pico en 468 nm: Rueggeberg 2011). La UV de los geles de uñas (365-405 nm, del
  orden de 10 mW/cm² de UVA: Shipp et al. 2014) apenas la cura: se toma el 10 % de su luz (estimación) y la capa queda blanda.
- **La dosis** es la irradiancia por el tiempo (Price et al. 2015). La irradiancia cae con la distancia como (R/(R + d·tan θ))²,
  R = 5 mm, θ = 12° (estimación). **La profundidad de curado**, Cd = Dp·ln(E/Ec) (la ley de Jacobs), anclada en la ficha del
  Filtek Z250 (capas de menos de 2,5 mm, 20 s) con 400 mW/cm² (8 J/cm²; Rueggeberg et al. 1994) y Dp = 1 mm (estimación):
  la azul a 1 mm y 20 s cura ~3,5 mm; la norma ISO 4049 pide al menos 1,5. Si Cd no llega al alto de la capa, queda blanda
  por dentro (`cured` < 1) y la unión aguanta esa fracción; otra exposición suma dosis. Menos luz nunca cura más (test).
- La lámpara se apaga sola al acabar su intervalo (5-40 s) y pita cada 10 s (`SfxCare.BEEP`, diseño de sonido). No se
  enciende sin los ojos del animal tapados (la capucha) y el filtro naranja: la luz azul intensa daña la retina (Price 2015).
- La resina es el material del bloque (`CareData.RESIN`: 155 MPa a flexión y 11 GPa de la ficha del Z250; dureza ~80 HV,
  ~2 g/cm³ y ~1,3 MPa·√m, estimaciones). Une a la queratina como el metacrilato de la reforja (estimación).

#### 11.13.6 Quitar lo que rebosa, el escalón y la prueba

- **Lo que rebosa** (`BOND_FLASH`): se pone algo de más (la mitad del volumen de la holgura, al menos 0,3 mm³) y rebosa al
  apretar; el acrílico y la resina, 0,3 mm³ por capa. En fresco, cada pasada de la espátula se lleva el 70 %; ya duro, la
  espátula no puede y hay que limarlo: lo que arranca la pasada es el modelo de la 5l (`ClawCare.removal_mm3`) con la dureza
  del polímero curado (~20 HV, la del acrílico de las prótesis: estimación). No se va solo (test).
- **El escalón**: con el bloque, lo que sobresale el bloque del muñón (el perfil de `ClawCare`); se lima con la forma. Mientras
  el bloque sobresale (más de `JOINT_LEVEL_MM`, 0,02 mm, tolerancia geométrica del modelo), una pasada que cruza la unión solo
  toca el bloque: la herramienta se apoya en lo alto y no llega a la queratina de debajo del escalón. Antes se repartía lo
  arrancado por igual a los dos lados, y con una pieza más dura que la queratina (la resina, 80 HV) el escalón crecía y el
  muñón se limaba hasta la carne viva (test `test_limar_la_union_no_lima_el_munon_de_debajo`). Con la
  funda, el adhesivo de la holgura más lo descentrada que quede (el borde de la funda llega afilado de la reforja: suposición),
  relleno de lo que rebosa y limado como el polímero curado; no se nota por debajo de 0,1 mm (`BOND_JOINT`, elección).
- **La forma y la punta**, como siempre (§11.7 y la 5l): el indicador, la silueta de la forma sana y «Dar la punta».
- **La prueba** (`pull_test`): un tirón suave de lado con la mitad del agarre de la garra del banco (`BOND_TEST`, elección);
  aguanta si τ·A ≥ F, con τ = min(τ_adhesivo × limpieza × rugosidad × purga × lo curado × proporción, τ_queratina) y la
  humedad de la garra. Si no, se despega (la garra vuelve a como estaba) y dice por qué: sucia, mojada, lisa, holgura de más,
  sin purgar, la proporción, movida, torcida o sin curar.

#### 11.13.7 Soldar sobre la garra (petición 44)

No se hace, y el programa lo explica con sus números sin hacérselo al animal (`ClawCareBond.weld_report`, el botón
«¿Soldar con TIG?»): el arco del TIG salta entre el electrodo y la pieza conectada a masa, y la queratina seca es un aislante
(fibras de lana secas, más de 10¹⁰ Ω·m: Hearle 1953, el caso medido más parecido); el baño está a la fusión del metal (oro
1064 °C, acero 1399-1454, titanio 1668: las de la reforja) y la queratina se quema a ~230 °C: con la cara a la temperatura del
baño, un sólido semiinfinito de queratina (Carslaw y Jaeger) se quema ~0,58 mm en 1 s con el oro; en ese segundo la carne
viva, a 5 mm, sigue a ~32 °C (T = T₀ + (T_baño − T₀)·erfc(x/(2·√(α·t))), con 2·√(α·t) = 0,63 mm: el calor aún no ha
llegado), y si el baño siguiera ahí, dolería en ~19 s; a 0,5 mm ya dolería en ese segundo. La queratina no se funde ni se mezcla con el metal. Lo real que se le parece: la
masilla de epoxi con acero («soldadura en frío», el cuarto adhesivo). Soldar metal con metal es del laboratorio (la 5m).

#### 11.13.8 El tutorial, el 3D y el sonido

- **El tutorial** «Colocar la pieza de la reforja» entra al llegar la pieza, con un camino por método
  (`ClawCareTutorial.bond_steps`): cada paso con su porqué y su fuente; las condiciones las comprueba `ClawCareBond.check`. Sin
  el tutorial se llega al mismo resultado (test).
- **La escena** (`care_bond3d.gd`): la bandeja de la colocación (la jeringa doble con su cánula en espiral, el vaso del
  acrílico con su masa —brillante líquida, mate dura—, los frascos, la jeringa de la resina, la lámpara con su guía de luz,
  la venda y el filtro naranja), la pieza en la bandeja, en la mano (sigue al puntero o al dedo y se acopla al muñón al
  acercarla) y apretada con su inclinación; el cordón de lo que rebosa, brillante en fresco y mate curado; la venda puesta;
  la lámpara sobre la capa con su luz azul mientras cura. Todo es dibujo.
- **La tarjeta** (`care_bond_card.gd`): la pieza, el paso que toca con «en la vida real tardaría…», la preparación, el
  adhesivo con su holgura («no llena» si no llega), el acrílico, la resina con la lámpara, lo que rebosa, el escalón, lo
  curado, lo que aguanta y la prueba. Teclas: A/D giran la pieza en la mano, K (mantenida) la aprieta y la sujeta, L enciende
  la lámpara.

#### 11.13.9 Los arreglos pequeños y la hoz del velocirraptor

- «Aguanta de lado» pasa a «×1883 la natural» desde 10 veces la natural (`ClawCareState.strength_words`): un bloque romo
  recién pegado aguantaba «188327 %».
- `slots_view()` da a cada garra del animal su arco, su sección, su largo natural y su base (`ClawCare.shape_dims`, de
  `CareData.claw_shape`), y las garras trabajadas que no son la elegida se dibujan con la suya.
- **La base de la hoz** (petición 48): el núcleo óseo medido en la base, 18,7 × 7,1 mm (Norell y Makovicky 1999, tabla 3),
  más el estuche, igual de grueso en proporción que de largo (núcleo/estuche = 0,699: Hedrick et al. 2019; estimación con el
  caso medido más parecido): 26,8 × 10,2 mm, un radio equivalente de 8,24 mm (antes, la genérica de 13,9 mm, 45 × 17 mm). La
  física de la cetrería (la masa, la flexión, la rotura y el calor salen del perfil de `ClawCare`) y el dibujo leen esa base
  (`CareData.VELOCIRAPTOR_BASE`, en `CLAW_SHAPES`). El banco y el coche en marcha siguen con la base genérica
  (`Physics.MODEL.clawBase`): si deberían cambiar, lo decide el coordinador.

#### 11.13.10 El estado del animal, lo que se está haciendo y el tutorial guiado (petición 51)

Eric: «un medidor de estrés o peligro del animal, que tiene que estar correctamente encapuchado, sedado o anestesiado según el
caso […] si sangra demasiado, puede perder la vida o infectarse la herida. No quiero algo hardcore, solo algo que sea educativo»;
y «no sabes muy bien qué estás haciendo y cuánto tiempo y segundos tienes que hacer tal cosa». Nada de física nueva en el
limado: lo que se añade son límites y textos sobre lo que el modelo ya calcula. Tests en `test_claw_care_guiado.gd` y
`test_care_guiado.gd`.

- **La barra del animal** (`ClawCareState.animal_view`, encima de la vista 3D y siempre visible): el estrés del paciente
  (`claw_care_patient.gd`: el índice pedagógico del tiempo sujeto y del dolor), la sangre perdida y el calor de la carne viva,
  cada uno con su límite marcado y su color. Sin sujetar, el tiempo no estresa a la rapaz hasta que se le tocan las garras
  (`patient.handled`): antes está en su percha. En el teléfono, cada medida con su texto corto (`short`: «12 % · suelta»,
  «0,6 mL · sangra», «32,0 °C») y el entero en la ayuda; la barra va fija encima del desplazamiento de la sección.
- **La sangre** (`CareData.BLOOD`): el volumen es la masa del animal (`care_anatomy.gd`) por la fracción de su especie: las aves,
  el 10 % del peso (LafeberVet: «up to 10% of blood volume (or 1% of total body weight in grams) can be safely drawn from
  healthy birds»); el velocirraptor, el de las aves (estimación); el tigre, el del gato (40-60 mL/kg) y el oso, el del perro
  (80-90 mL/kg), de MSD (estimaciones con el caso medido más parecido). Lo perdido es todo el tiempo que han sangrado sus garras
  por lo que sale de una garra cortada (una gota de ~0,05 mL por segundo: estimación, sin medición). Sin peligro, el 10 %
  (LafeberVet); el aviso de peligro, al 20 %, y la sesión se para al 30 %: con el 40 % el daño ya es irreversible (Rudloff
  2002), así que se para antes (estimaciones con margen). Un águila de 5 kg (~500 mL) aguanta una garra sin tratar hasta que
  para sola (10 min: 30 mL, el 6 %); una lechuza de 0,35 kg (~35 mL), no: la sesión se para si no se para la sangre.
- **Las fuentes de los límites**: la ayuda de cada medida de la barra termina con «Límite (calidad): fuente» (el estrés, de
  `ANIMAL_RISK`; la sangre, de `BLOOD`; el calor, del umbral del dolor `THERMAL.pain_c`).
- **Con anestesia general** el dolor no sube el estrés (no lo siente; el dolor se apunta igual para el informe), como el tiempo.
- **Los límites del estrés** (`CareData.ANIMAL_RISK`, elecciones del ensayo, generosas): inquieto desde 0,4, estresado desde
  0,7 y peligro desde 0,9; la sesión se para si el animal se mueve de dolor 3 veces, si a un tigre, un oso o un velocirraptor
  sin sedar se le tocan las garras por segunda vez después del aviso (Cat Tales 2024; Animals Asia) o si una rapaz sin sujetar
  llega al estrés máximo (Samour 2006: sin sujetar puede «clavar» al que la maneja). Con la sujeción que pide su especie, el
  estrés del tiempo solo avisa. Siempre hay un aviso antes de cada consecuencia, y la sesión parada se explica en el informe y
  se repite enseguida (R).
- **La infección**: si sangró y se termina sin desinfectar, el informe lo dice como riesgo de infección (Lozier et al. 1992:
  la clorhexidina al 0,05 % mata las bacterias sin retrasar la cicatrización).
- **Lo que se está haciendo** (`activity_view`): cada acción que lleva tiempo (la hemostasia, el cortaúñas, el toque del torno,
  la fijación del adhesivo, la venda, la masa y el fraguado del acrílico, la lámpara) dice cuánto lleva, cuánto hace falta y
  avisa al acabar («Ha fijado…», «Ha fraguado: ya está duro. Ahora se lima…», «Curada…» o «Blanda por dentro…»), y
  cuánto tardaría en la vida real con el reloj acelerado, con una barra que llega al 100 % justo al acabar; «Mantén pulsado»,
  «Listo: ya puedes soltar» y «Has soltado antes de tiempo: faltaban 12 s». Un toque del torno, 3 s (`ROTARY_TOUCH`:
  «unos segundos cada vez, con pausas», la guía de Dremel; 3 s, estimación).
- **Las limas, claras**: para qué sirve cada una y en qué orden (`TOOL_GUIDE`: desbastar, afinar, pulir, de grueso a fino,
  DIN 8349), qué ha hecho cada pasada (lo quitado, la superficie que deja y cuánto falta para el largo o la punta, con las
  pasadas que quedan a ese ritmo; lo quitado en mm³ y, por debajo de una diezmilésima, en µm³: `fmt_vol`) y por qué no muerde (las durezas de la herramienta y del material donde toca, la η de Pintaude
  de la 5l) con lo que hay que coger en su lugar.
- **El tutorial guiado**: un objetivo por paso (`STEP_GOALS`), el mando que hay que pulsar resaltado (`STEP_UI`) y la
  herramienta señalada en la bandeja 3D; los pasos que se cumplen al coger la herramienta (`STATE_CHECKS`) o al hacer lo suyo
  (`STEP_ACTION`: cortar, limar la cara, tocar con el torno, probar la punta); los informativos siguen solos al leerlos (0,22 s
  por palabra, de 3,5 a 9 s); el progreso del paso, del proceso y del total; y «Si sangra» en el orden en que se hace: coger el
  polvo, apretar hasta que pare y desinfectar.

#### 11.13.11 Lo que queda

- La unión a tope del bloque sobre la cara de la rotura: el bloque podría solapar el muñón (más área); no se modela.
- El calor de la lámpara sobre la resina (unas décimas de vatio: sin modelo) y el encogimiento del acrílico y de la resina
  al curar.
- Lo curado del adhesivo entre la fijación y la plena, lineal en el logaritmo: las curvas de las fichas son de acero y
  aluminio, no de queratina.
- La holgura de la funda es la de la reforja; con la funda de otro tamaño no se ensaya.
- La sangre: lo que sale de una garra cortada no está medido (una gota por segundo); el sangrado no afloja con el tiempo ni con
  la presión parcial, y el volumen del velocirraptor es el de las aves.
- El estrés sigue siendo un índice pedagógico: los límites de la barra son elecciones del ensayo, no mediciones de cortisol.
  No baja con la calma ni con una pausa, y no se puede devolver el ave a su percha mientras fija una cola lenta (el epoxi de la
  funda, 3 h): sujeta todo ese tiempo llega al 100 % (lo trata la 5t).
- Acabar una prótesis de resina (80 HV) lleva unas cuatro veces más toques de amoladora que una de acrílico (20 HV); con la
  lima a mano, cientos de pasadas (la punta de un bloque de ~4 mm de radio). Es lo esperable por la dureza, no un fallo.

## 12. Fuentes

- Advanced Institute for Wildlife Conservation (2023). Muhsina Thunnisa, Pavithra Rajkumar. *Delineating feline claws and
  canine teeth of tiger and leopard by morphometric methods*. Tamil Nadu Forest Department (tabla 4.7: 43 garras de tigre).
- Alqutaibi AY et al. (2023). Polymeric denture base materials: a review. *Polymers* 15:3258. doi:10.3390/polym15153258
  (recoge a Barbosa DB, Compagnoni MA, Souza RF, Pero AC, *J. Prosthodont.*: el PMMA autopolimerizable).
- American Academy of Dermatology. How to trim your nails (aad.org).
- Animals Asia. The first 100 days at sanctuary (bear care).
- Arent L, Pollock C (2012, revisado 2023). Raptor anatomy fundamentals. LafeberVet.
- Bearhop S, Furness RW, Hilton GM, Votier SC, Waldron S (2003). A forensic approach to understanding diet and habitat
  use from stable isotope analysis of (avian) claw material. *Funct. Ecol.* 17:270-275. doi:10.1046/j.1365-2435.2003.00725.x
  (su ritmo de crecimiento, citado por Mazerolle & Hobson 2005)
- BIAZA (2019). Animal training guidelines (British and Irish Association of Zoos and Aquariums).
- Barrett RT (1990). *Fastener Design Manual*. NASA Reference Publication 1228 (tabla de coeficientes de rozamiento en seco).
- Bifano TG, Dow TA, Scattergood RO (1991). Ductile-regime grinding: a new technology for machining brittle materials.
  *J. Eng. Ind.* 113:184-189.
- Birn-Jeffery AV, Miller CE, Naish D, Rayfield EJ, Hone DWE (2012). Pedal claw curvature in birds, lizards and Mesozoic
  dinosaurs. *PLoS ONE* 7:e50555. doi:10.1371/journal.pone.0050555 (tablas S1 y S2)
- Cat Tales Wildlife Center (2024). When a tiger needs a manicure: Nalin's medical journey (9-11-2024).
- Coakley S et al. (2020). A comparison of ferric subsulfate solution, silver nitrate, and aluminum chloride for pain
  assessment, time to hemostasis, and cosmesis. *J. Clin. Aesthet. Dermatol.* (PMC7819594).
- Contreras ET, Bruner K, Hegwer C, Simpson A (2025). Claw growth rates in a subset of adult, indoor, domestic cats
  (*Felis catus*). *Vet. Dermatol.* 36:362-367. doi:10.1111/vde.13335
- Crescent Nicholson. Guide to files and filing (crescenttool.com).
- Dias DT, Steimacher A, Bento AC, Neto AM, Baesso ML (2007). Thermal characterization in vitro of human nail:
  photoacoustic study of the aging process. *Photochem. Photobiol.* 83:1144-1148. doi:10.1111/j.1751-1097.2007.00074.x
- DMT Diamond Sharpeners. FAQ (tamaños de grano).
- Dremel. 7300-PT 4.8V Pet Grooming Kit, ficha técnica; «How to avoid failures while cutting your dog's nails».
- Dremel. 7760-PGK PawControl Pet Nail Grooming Kit, ficha (4 V, 4 velocidades de 8000 a 25 000 rpm, protector con guía
  de 45°, bandas de lija 407 y 408 de 1/2″ y grano 60); Dremel Lite 7760, manual de instrucciones original (posiciones
  del interruptor: 8000, 14 000, 21 000 y 25 000 rpm).
- Dubin AE, Patapoutian A (2010). Nociceptors: the sensors of the pain pathway. *J. Clin. Invest.* 120:3760-3772.
  doi:10.1172/JCI42843
- Ethier DM, Kyle CJ, Kyser TK, Nocera JJ (2010). Variability in the growth patterns of the cornified claw sheath among
  vertebrates. *Can. J. Zool.* 88:1043-1051. doi:10.1139/z10-073 (citado por Fokidis et al. 2023)
- Farran L, Ennos AR, Eichhorn SJ (2008). The effect of humidity on the fracture properties of human fingernails.
  *J. Exp. Biol.* 211:3677-3681. doi:10.1242/jeb.023218
- Farren L, Shayler S, Ennos AR (2004). The fracture properties and mechanical design of human fingernails. *J. Exp.
  Biol.* 207:735-741. doi:10.1242/jeb.00814
- Fokidis HB, Brock T, Newman C, Macdonald DW, Buesching CD (2023). Assessing chronic stress in wild mammals using
  claw-derived cortisol: a validation using European badgers (*Meles meles*). *Conserv. Physiol.* 11:coad024.
  doi:10.1093/conphys/coad024
- Fowler DW, Freedman EA, Scannella JB (2009). Predatory functional morphology in raptors: interdigital variation in
  talon size is related to prey restraint and immobilisation technique. *PLoS ONE* 4:e7999.
  doi:10.1371/journal.pone.0007999 (tabla S1)
- FWT GmbH. Werkstattfeilen (limas de taller de 60-62 HRC).
- Anthony JW, Bideaux RA, Bladh KW, Nichols MC (eds.). *Handbook of Mineralogy*. Mineralogical Society of America (la raya:
  corindón, cuarzo, hematites y moissanita).
- Evans AG, Marshall DB (1981). Wear mechanisms in ceramics. En Rigney DA (ed.), *Fundamentals of Friction and Wear of
  Materials*, ASM, pp. 439-452 (las grietas laterales; no se usa su ley, sin la constante medida).
- Hedrick BP, Cordero SA, Zanno LE, Noto C, Dodson P (2019). Quantifying shape and ecology in avian pedal claws.
  *Ecol. Evol.* 9:11545-11556. doi:10.1002/ece3.5507
- HolzWerken (2024). Stahlhärte bestimmen: ganz einfach mit Feilen (18-9-2024).
- Homberger DG et al. (2009). The structure of the cornified claw sheath in the domesticated cat (*Felis catus*).
  *J. Anat.* 214:620-643. doi:10.1111/j.1469-7580.2009.01068.x
- Jordt SE, Julius D (2002). Molecular basis for species-specific sensitivity to «hot» chili peppers. *Cell*
  108:421-430. doi:10.1016/S0092-8674(02)00637-2
- Kelley JE, Blickensderfer R (1974). *Spark-shower radiance of metal grinding sparks*. U.S. Bureau of Mines, Report of
  Investigations 7902 (tabla 1: el hierro, 787 µW/sr·cm², y el titanio, 743; tabla 10: el carburo de tungsteno con cobalto,
  30).
- Kakkar P, Madhan B, Shanmugam G (2014). Extraction and characterization of keratin from bovine hoof: a potential material for biomedical applications. *SpringerPlus* 3:596.
- Kalácska Á et al. (2021). Abrasive sensitivity of martensitic and a multi-phase steels under different abrasive
  conditions. *Materials* 14:1343. doi:10.3390/ma14061343
- Klingspor. Grit grading systems (coated abrasives).
- Laubé F, Poupon A, Zinck P, Müller-Goymann C, Reichl S, Nardello-Rataj V (2019). Physicochemical investigations of
  native nails and synthetic models for a better understanding of surface adhesion of nail lacquers. *Eur. J. Pharm.
  Sci.* 131:208-217. doi:10.1016/j.ejps.2019.02.014
- Lozier S, Pope E, Berg J (1992). Effects of four preparations of 0.05% chlorhexidine diacetate on wound healing in
  dogs. *Vet. Surg.* 21:107-112.
- Malkin S, Guo C (2007). Thermal analysis of grinding. *CIRP Annals* 56:760-782.
- Manning PL et al. (2006). Dinosaur killer claws or climbing crampons? *Biol. Lett.* 2:110-112.
  doi:10.1098/rsbl.2005.0395
- Mason P (1963). Density and structure of alpha-keratin. *Nature* 197:179-180. doi:10.1038/197179a0
- Mathiowetz V, Kashman N, Volland G, Weber K, Dowe M, Rogers S (1985). Grip and pinch strength: normative data for adults.
  *Arch. Phys. Med. Rehabil.* 66:69-74.
- Matta T, Eshar D, Nau MR (2022). Surgical repair of a rostral maxillary beak fracture using an improvised metal implant
  scaffolding and dental acrylic prosthesis in a pet double yellow-headed Amazon parrot (*Amazona ochrocephala oratrix*).
  *Israel J. Vet. Med.* 77(4):213-221.
- Mazerolle DF, Hobson KA (2005). Estimating origins of short-distance migrant songbirds in North America. *Condor*
  107:280-288. doi:10.1093/condor/107.2.280
- McKittrick J, Chen P-Y, Bodde SG, Yang W, Novitskaya EE, Meyers MA (2012). The structure, functions, and mechanical
  properties of keratin. *JOM* 64:449-468. doi:10.1007/s11837-012-0302-8
- Milner SM (2024). Mechanism and management of scald burns. *Eplasty* 24:QA7 (recoge a Moritz & Henriques 1947,
  *Am. J. Pathol.* 23:695-720).
- MSD Veterinary Manual. Management of pet birds (exotic and laboratory animals).
- NMRA (1999). Data sheet D1m.9: Tools: files and rasps.
- Norell MA, Makovicky PJ (1999). Important features of the dromaeosaurid skeleton II: information from newly collected
  specimens of *Velociraptor mongoliensis*. *American Museum Novitates* 3282:1-45 (tabla 3).
- Oberg E et al. *Machinery's Handbook* (Industrial Press): «Surface roughness produced by common production methods»
  (de ANSI/ASME B46.1).
- Pan LH et al. (2024). The normative values of pain thresholds in healthy Taiwanese. *Brain Behav.* 14:e3485.
  doi:10.1002/brb3.3485
- Pintaude G, Bernardes FG, Santos MM, Sinatora A, Albertin E (2009). Mild and severe wear of steels and cast irons in
  sliding abrasion. *Wear* 267:19-25; recogido en Pintaude G (2021). Remarks on wear transitions related to hardness and
  size of abrasive particles. En *Tribology of Machine Elements: Fundamentals and Applications*, IntechOpen.
  doi:10.5772/intechopen.99324
- Pattrick JG, Labonte D, Federle W (2018). Scaling of claw sharpness: mechanical constraints reduce attachment
  performance in larger insects. *J. Exp. Biol.* 221:jeb188391. doi:10.1242/jeb.188391
- PFERD. Files, catálogo 1 (dientes por centímetro según DIN 8349; guía de materiales).
- Pike AVL, Maitland DP (2004). Scaling of bird claws. *J. Zool.* 262:73-81.
- Sakas PS. Grooming in pet birds (Niles Animal Hospital & Bird Medical Center).
- Richardson RCD (1968). The wear of metals by relatively soft abrasives. *Wear* 11:245-275.
  doi:10.1016/0043-1648(68)90175-0
- RoyMech y Engineers Edge, «Coefficient of friction» (tablas de los manuales: diamante, carburo de tungsteno, vidrio).
- Samour J (2006). Management of raptors. En Harrison GJ, Lightfoot TL (eds.), *Clinical Avian Medicine*, vol. II,
  cap. 40, pp. 915-956. Spix Publishing.
- Stokes GG (1851). On the effect of the internal friction of fluids on the motion of pendulums. *Trans. Cambridge Philos.
  Soc.* 9:8-106 (la velocidad de caída de una esfera lenta, ρ·g·d²/(18·μ)).
- Taylor AM, Bonser RHC, Farrent JW (2004). The influence of hydration on the tensile and compressive properties of avian
  keratinous tissues. *J. Mater. Sci.* 39:939-942. doi:10.1023/B:JMSC.0000012925.92504.08
- Taylor D (2007). *The Theory of Critical Distances*. Elsevier.
- U.S. Army (1993). TC 9-237, *Operator's Circular: Welding Theory and Application*, tabla 7-5 (el ensayo de chispas).
- U.S. National Park Service. Bear identification (nps.gov).
- VCA Animal Hospitals (Weir M, Williams K, Buzhardt L). First aid for broken nails in dogs.
- Whitby Abrasives. Grit-to-surface-finish (Ra) chart (whitbyabrasives.ca).
- Wortmann FJ, Wortmann G, Marsh J, Meinert K (2012). Thermal denaturation and structural changes of α-helical proteins in keratins. *J. Struct. Biol.* 177:553-560.
- Zafar MS (2020). Prosthodontic applications of polymethyl methacrylate (PMMA): an update. *Polymers* 12:2299.
  doi:10.3390/polym12102299
- (Unidad 5o) Henkel. Fichas técnicas de LOCTITE 401 (2012), LOCTITE EA E-20HP (2023) y LOCTITE AA H8000 (2022); *The LOCTITE
  Design Guide for Bonding Metals*, vol. 6, tabla 7.
- (Unidad 5o) J-B Weld Company. J-B Weld Original Cold-Weld Steel Reinforced Epoxy, ficha técnica.
- (Unidad 5o) Veracril (New Stetic). Resina acrílica autopolimerizable, instrucciones de uso.
- (Unidad 5o) Odian G (2004). *Principles of Polymerization*, 4.ª ed., Wiley (tabla 3-14).
- (Unidad 5o) ISO 5833:2002 (cementos de resina acrílica) e ISO 4049:2019 (materiales de restauración a base de polímeros).
- (Unidad 5o) 3M ESPE. Filtek Z250 Universal Restorative, *Technical Product Profile*; 3M, Elipar S10 LED Curing Light.
- (Unidad 5o) Rueggeberg FA, Caughman WF, Curtis JW (1994). Effect of light intensity and exposure duration on cure of resin
  composite. *Oper. Dent.* 19:26-32.
- (Unidad 5o) Rueggeberg FA (2011). State-of-the-art: dental photocuring — a review. *Dent. Mater.* 27:39-52.
  doi:10.1016/j.dental.2010.10.021
- (Unidad 5o) Price RB, Ferracane JL, Shortall AC (2015). Light-curing units: a review of what we need to know. *J. Dent. Res.*
  94:1179-1186. doi:10.1177/0022034515594786
- (Unidad 5o) Shipp LR, Warner CA, Rueggeberg FA, Davis LS (2014). Further investigation of the risk of skin cancer from nail
  lamps. *JAMA Dermatol.* 150:775-776.
- (Unidad 5o) Jacobs PF (1992). *Rapid Prototyping & Manufacturing: Fundamentals of Stereolithography*. SME.
- (Unidad 5o) Hearle JWS (1953). The electrical resistance of textile materials. *J. Text. Inst.* 44.
- (Unidad 5o) Ferreira CMC, Simões BD, Marques EAS, Carbas RJC, da Silva LFM (2024). Exploring adhesive performance in horseshoe
  bonding through advanced mechanical and numerical analysis. *Biomimetics* 10:2. doi:10.3390/biomimetics10010002
- (Unidad 5o) Pollock C, Powers L (2007, revisado en 2015). Venipuncture in birds. LafeberVet (el volumen de sangre de las aves y
  lo que se puede extraer sin peligro).
- (Unidad 5o) Blois S (2024). Blood transfusions in dogs and cats. MSD Veterinary Manual (el volumen de sangre del gato y del
  perro).
- (Unidad 5o) Rudloff E (2002). Resuscitation from hypovolemic shock. WSAVA 2002 Congress, VIN (con el 40 % del volumen
  perdido, el daño es irreversible).
