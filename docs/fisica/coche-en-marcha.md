# Coche en marcha · rapaces, tigres, osos, el casuario y los velocirraptores sobre un coche en carretera (laboratorio 2.0 · unidades 1k, 4d, 4g, 4i-B2 y 4m)

Especificación del ensayo del coche en marcha del banco de tribología. Dos preguntas de Eric (unidad 1k):

1. Una rapaz que, por miedo o para defenderse, clava las garras en un coche que circula por carretera: ¿perfora la
   chapa?, ¿qué capas atraviesa?, ¿cuánto aguanta frente a la velocidad y la aerodinámica del coche antes de soltarse?
2. Un tigre o un oso que se abalanza sobre un coche en marcha: ¿desgarra o perfora la chapa?, ¿cuánto viento recibe?,
   ¿a qué velocidad cedería y qué daño deja?

Y tres más (unidad 4d), con la condición de que «la física sea realista y contrastable por libros y hechos empíricos, no
datos inventados u aproximados»:

3. «Añade también al majestuoso y peligroso Casuario a ese banco de Tribología del coche en marcha» (§10).
4. «Y una rama experimental de garras hechas con otros materiales distintos y duros» (§11): ¿perforan la chapa?, ¿se
   quedan clavadas?, ¿se rompen?
5. La fuerza teórica, en newtons, de cada animal asustado y en modo defensa, aunque no llegue a clavarse, y lo que deja
   al intentar mantenerse con el coche en marcha: desgarros en la carrocería y el vidrio, o quedarse clavado (§12).

Y tres arreglos de la revisión (unidad 4g, §13):

6. Unas garras que atraviesan la aleta de plástico en un golpe de costado no dejaban ninguna marca: ahora, trabadas en
   ella, la rajan mientras el animal sigue a lo largo del panel, con el balance de energía y la tenacidad medida del
   plástico, hasta que se para respecto al coche, llega al final del panel o sus dedos ceden.
7. Con viento de cola, el ala abierta sustentaba como si el aire le viniera de frente: ahora, con el aire por detrás,
   sustenta como un perfil al revés, medido en túnel hasta 180° (Sheldahl & Klimas 1981).
8. Datos sin fuente ni calidad (la geometría de las zonas, los cuerpos campo a campo, el ala y la rigidez de la pata): ya
   la llevan, con el caso medido más parecido cuando son estimaciones.

Y los velocirraptores (unidad 4i-B2, §14): la reconstrucción, que pincha y sujeta, y el de cine, con una garra de película
(marcada como ficción) que raja la chapa; los dos saltan sobre el coche, y las garras reforjadas suman su masa al golpe y
se pueden afilar.

Y la ventanilla templada (unidad 4m, §15), de la petición 28 de Eric («…de las punciones, arañazos y desgarros sobre los
materiales y vidrios del coche…»): las ventanillas laterales, de vidrio templado, ya están en el golpe. Estallan enteras
en trocitos romos si el golpe las flexa más de lo que aguantan o si una punta al menos tan dura como el vidrio abre una
grieta que atraviesa su capa comprimida; llega a ellas quien las alcanza (volando, saltando o con la cruz por encima de
la cintura del coche).

Y una pasada de física y fallos de lo que ya había (unidad 4o, §16): la hondura de las marcas de una garra que atraviesa
la chapa (el velocirraptor de cine en el capó decía «marcas de 120 mm de hondo» con 80 mm de hueco debajo), la banda del
hueco bajo el capó y por qué la rigidez y el recorrido de la pata y los demás huecos se quedan sin ella, y las
incoherencias de los textos de los ensayos de un clic y de los casos de la demo.

Archivos:

- Física: `godot/core/lab/moving_car.gd` (funciones puras y estáticas; `MovingCar.hold_report(p)` y
  `MovingCar.impact(p)` son la referencia de la integración).
- Rotura de las garras reforjadas (unidad 4d): `godot/core/lab/claw_fracture.gd` (módulo puro; no entra en
  `Physics.compute`).
- Revisión de las rapaces: `godot/core/lab/claws_v2.gd` (correcciones de datos por id de garra para el modelo 2.0;
  `data.gd`, el port exacto del oráculo 1.x, no se toca).
- Tests: `godot/tests/lab/test_moving_car.gd`, `godot/tests/lab/test_claw_fracture.gd`,
  `godot/tests/lab/test_claws_v2.gd`, de los velocirraptores, `godot/tests/lab/test_moving_car_velociraptor.gd`, y de la
  ventanilla templada, `godot/tests/lab/test_moving_car_window.gd` (y el punto del golpe en el dibujo,
  `godot/tests/app/test_moving_car_window_draw.gd`), y de la hondura de las marcas que atraviesan el panel (unidad 4o),
  `godot/tests/lab/test_moving_car_hondura.gd`.
- Casos de referencia de la integración: `godot/tests/fixtures/spec/coche-en-marcha.json` (54 casos: 28 de la unidad 1k,
  15 de la 4d, 1 de la 4g, 6 de la 4i-B2 y 4 de la 4m; la 4g amplía además tres de la aleta de plástico, y la 4o, el del
  velocirraptor de cine en el capó).

> **Experimento mental y educativo.** El modelo da órdenes de magnitud con datos publicados: el aire sobre un coche
> medido en túnel (DrivAer), la resistencia de rapaces medida en túnel, el agarre de rapaces medido in vivo y la física
> de la chapa, la pintura y el vidrio que ya tiene el banco. Del tigre y del oso no hay túnel de viento: su aerodinámica
> es una estimación y se dice. Tampoco se modela el comportamiento del animal (saltaría antes) ni sus heridas: los
> textos cuentan qué le pasa al coche y si el animal se queda, resbala, cae o sale volando, sin morbo, y acaban con una
> nota de seguridad vial.

## 1. Resumen

**Rapaces.** Velocidad del coche (km/h) a la que se sueltan, en el coche moderno: valor central y, entre paréntesis,
la banda con los datos más desfavorables y los más favorables. «∞»: ni a 400 km/h (el tope de la búsqueda).

| Rapaz | Capó, plegadas | Capó, abiertas | Techo, plegadas | Techo, abiertas | Retrovisor, plegadas | Retrovisor, abiertas |
|---|---|---|---|---|---|---|
| Águila real (5 kg) | 230 (105-334) | 25 (18-36) | 196 (79-296) | 24 (14-35) | ∞ (210-∞) | 60 (37-188) |
| Águila arpía (9 kg) | 254 (116-369) | 34 (22-50) | 216 (88-327) | 33 (17-49) | ∞ (220-∞) | 81 (44-259) |
| Halcón peregrino (1 kg) | 176 (81-256) | 24 (17-35) | 150 (61-226) | 23 (13-34) | 323 (155-∞) | 53 (35-162) |
| Búho (2 kg) | 198 (90-287) | 21 (14-29) | 168 (68-254) | 20 (11-28) | ∞ (220-∞) | 51 (37-155) |
| Lechuza (0,35 kg) | 137 (68-214) | 14 (10-19) | 115 (51-190) | 13 (8-18) | 325 (165-∞) | 35 (26-103) |
| Buitre leonado (8 kg) | 229 (114-362) | 28 (20-38) | 193 (86-320) | 26 (16-37) | 345 (129-∞) | 47 (24-118) |

| Rapaz | Limpiaparabrisas, plegadas | Limpiaparabrisas, abiertas | Barras de techo, plegadas | Barras de techo, abiertas |
|---|---|---|---|---|
| Águila real | ∞ (315-∞) | 83 (49-298) | ∞ (217-∞) | 61 (39-199) |
| Águila arpía | ∞ (333-∞) | 112 (59-∞) | ∞ (227-∞) | 82 (46-275) |
| Halcón peregrino | ∞ (234-∞) | 73 (46-258) | 327 (161-∞) | 53 (36-172) |
| Búho | ∞ (321-∞) | 71 (47-246) | ∞ (228-∞) | 52 (38-164) |
| Lechuza | ∞ (240-∞) | 49 (33-164) | 329 (171-∞) | 36 (27-109) |
| Buitre leonado | ∞ (225-∞) | 65 (37-187) | 350 (133-∞) | 48 (25-125) |

Lo que enseña la tabla:

- **Con las alas plegadas y sin nada que agarrar** (capó, techo) aguanta por fricción hasta 115-254 km/h: su peso y el
  roce de dedos y talones pueden con el viento durante toda la carretera. Se va hacia atrás.
- **Con las alas abiertas no se suelta: despega.** El ala sostiene al ave a 13-34 km/h de coche, justo por debajo de
  su velocidad mínima de vuelo (el aire sobre el techo va un 20 % más rápido que el coche). Un águila con las alas
  abiertas sobre un coche a 30 km/h es un águila volando.
- **Agarrada a algo** (retrovisor, limpiaparabrisas, barras) y con las alas plegadas, el valor central pasa de
  320 km/h: el agarre medido de sus dedos (§8) sobra. Con los datos más desfavorables, nunca por debajo de 129 km/h (el
  buitre, con pie de caminar, es el que menos agarra). Con las alas abiertas, su propia sustentación la arranca a
  35-112 km/h.
- **Ninguna perfora la chapa.** La queratina (~30 HV) cede contra el acero (~100 HV) y el aluminio (~70 HV): raya la
  pintura, a veces hasta el metal, y nada más. Solo la aleta de plástico se deja atravesar. (Con las garras reforjadas
  en un material duro, sí: §11.)

**Tigre y oso** (coche moderno; «tumbado» es agazapado). Despegue por el viento, frenada máxima que aguantan a 90 km/h
y resistencia aerodinámica a 100 km/h, con la del coche entero (312 N) como referencia.

| Animal y zona | Postura | Se suelta (km/h) | Frenada máx. a 90 km/h | Resistencia a 100 km/h |
|---|---|---|---|---|
| Tigre (220 kg), techo | agazapado | 341 (164-∞) | 0,99 g | 85 N (27 % del coche) |
| Tigre, techo | de pie | 327 (129-∞) | 1,08 g | 202 N (65 %) |
| Tigre, capó | agazapado | 380 (204-∞) | 0,71 g | 79 N (25 %) |
| Tigre, capó | de pie | ∞ (172-∞) | 0,77 g | 188 N (60 %) |
| Tigre, barras de techo | agazapado | ∞ (291-∞) | 1,99 g | 76 N (24 %) |
| Tigre, borde de la ventanilla | agazapado | ∞ (222-∞) | 1,39 g | 78 N (25 %) |
| Tigre, parabrisas | agazapado | ∞ (ni parado-∞) | 0,04 g | 59 N (19 %) |
| Oso pardo (300 kg), techo | agazapado | 319 (163-∞) | 0,86 g | 132 N (42 %) |
| Oso, techo | de pie | 289 (130-∞) | 0,94 g | 303 N (97 %) |
| Oso, capó | agazapado | 361 (204-∞) | 0,61 g | 123 N (39 %) |
| Oso, capó | de pie | 357 (173-∞) | 0,67 g | 282 N (90 %) |
| Oso, barras de techo | de pie | ∞ (230-∞) | 1,93 g | 272 N (87 %) |
| Oso, borde de la ventanilla | agazapado | 399 (219-∞) | 1,25 g | 122 N (39 %) |
| Oso, parabrisas | agazapado | ∞ (ni parado-∞) | 0,04 g | 91 N (29 %) |

- **Al tigre y al oso no los tira el viento: los tira la frenada.** En el deslizador (0-230 km/h) el aire no los arranca
  (valor central; con los datos más desfavorables, de pie en el techo, desde ~130 km/h); una frenada de 0,6-1 g, sí (y
  una curva fuerte). Las barras y el marco de la ventanilla dan dónde enganchar
  las garras: aguantan hasta ~2 g.
- **El oso de pie en el techo casi duplica la resistencia del coche**: 303 N más a 100 km/h, unos 8,4 kW de motor.
- **El parabrisas es una rampa lisa** (vidrio, μ = 0,6, 30°): se sostienen a duras penas, cualquier frenada los echa, y
  el oso lo agrieta con su peso (637 N por pata contra ~517 N que aguanta el laminado; el tigre, 467 contra 470 N, al
  límite).

**El golpe.** Tigre y oso que cruzan a 40 km/h y chocan con un coche a 50 km/h (1400 kg; en capó, techo y parabrisas
caen además 0,5 m):

| Zona | Tigre: energía normal | Tigre: daño | Oso: energía normal | Oso: daño |
|---|---|---|---|---|
| Techo | 0,93 kJ | abolladura de ~2,3 cm bajo cada pata, surcos hasta el metal; cae a ~33 km/h | 1,2 kJ | ~2,9 cm; cae a ~34 km/h |
| Capó | 2,9 kJ | ~5,2 cm; cae a ~33 km/h | 3,7 kJ | ~6,0 cm; cae a ~34 km/h |
| Puerta | 11,7 kJ | hasta el fondo (15 cm) bajo hombro y cadera; 8 surcos de 24,5 cm; cae a ~35 km/h | 15,3 kJ | hasta el fondo; cae a ~28 km/h |
| Aleta | 11,7 kJ | hasta el fondo (6 cm) | 15,3 kJ | hasta el fondo |
| Parabrisas | 8,9 kJ | lo agrieta (~5,1 kN por apoyo contra ~470 N) y puede atravesarlo; cae a ~39 km/h | 11,5 kJ | lo agrieta y puede atravesarlo |

En el coche clásico (acero dulce de 0,9 mm) y en el de aluminio (1 mm) las abolladuras son un 2-7 % menores; en la
aleta de plástico las garras la atraviesan y el plástico no se abolla (se hunde y recupera), pero las garras quedan
trabadas en ella y la rajan (unidad 4g, §13.1): el tigre, la aleta entera (80 cm, 720 J), y cae a ~38 km/h en vez de a
~35; a un coche a 40 km/h, solo 28 cm, hasta que va a la velocidad del coche. Las rapaces no pueden: rajarla pide más
de lo que aguanta su agarre (el águila, 450 N contra 202), y sus talones se sueltan. Una rapaz que choca de
frente contra el parabrisas a 130 km/h relativos también lo agrieta (el águila con 0,8 kJ, el halcón con 0,16 kJ; la
lechuza, con 57 J, sin llegar a los 88,7 J que garantiza la homologación).

**La ventanilla templada** (unidad 4m, §15). Contra un costado, las ventanillas no se agrietan como el parabrisas: o
aguantan enteras o estallan en ~91 trocitos de ~5,6 mm por cada 5 × 5 cm. Llegan a ellas las aves (vuelan), los
velocirraptores (saltando, sus pies suben ~1,19 m) y el oso (su cruz, ~1,20 m, pasa de la cintura del coche, ~0,89 m); el
tigre, a cuatro patas (cruz de 0,8-1,0 m), golpea la puerta, y el casuario patea a la altura de las patas. El águila que
cruza a 20 km/h con sus talones aguanta (~813 N por pata contra los ~1121 N que la parten al flexar); con garras de
diamante, el mismo golpe la revienta: cada garra aprieta ~407 N y bastan ~231 N para abrir la grieta que atraviesa la capa
comprimida (el truco del martillo de emergencia). El oso la revienta al flexar desde ~10 km/h. Si el animal entra en el
coche, el modelo no lo calcula.

**Marcas en la pintura** (el animal resbalando con su peso por el techo): la pintura de los tres coches de metal es la
misma (110 µm: barniz 0-45, color 45-60, imprimación 60-85 y anticorrosivo 85-110 µm) y la garra nunca entra en el
metal, así que las marcas son iguales en los tres.

| Animal | Coche moderno, clásico y de aluminio | Aleta de plástico (PPE/PA de 2,5 mm) |
|---|---|---|
| Águila real | hasta el metal (110 µm: las cuatro capas) | 472 µm: la pintura y 362 µm de plástico |
| Águila arpía | hasta el metal | 708 µm |
| Halcón peregrino | 58 µm: barniz y color | 58 µm |
| Búho | 92 µm: hasta el anticorrosivo | 92 µm: hasta el promotor de adherencia |
| Lechuza | 14 µm: solo el barniz | 14 µm |
| Buitre leonado | 57 µm: barniz y color | 57 µm |
| Tigre | hasta el metal | la raja entera (2,61 mm) |
| Oso pardo | hasta el metal | 1013 µm |

**El aire cambia con la temperatura y la altitud.** A 0 °C el aire es un 7 % más denso que a 20 °C; a 35 °C, un 5 %
menos; a 2000 m, un 22 % menos (atmósfera tipo ISO 2533). Sin viento, la fuerza del aire solo depende de ρ·v², así que
la velocidad de despegue escala con 1/√ρ: el águila plegada del techo se suelta hacia 189 km/h a 0 °C, 196 a 20 °C y
201 a 35 °C; con las alas abiertas, a 2000 m despega a 27 km/h en vez de 24. El oso de pie en un puerto a 2000 m y
35 °C frena al coche con 226 N en vez de 303 (y el coche también frena menos: la proporción no cambia).

**Con viento de cola, el ala trabaja al revés** (unidad 4g, §13.2). Si el viento de cola es más fuerte que la velocidad
del coche, el aire le llega al ave por detrás y entra en el ala por el borde de salida: como mucho sustenta lo que un
perfil al revés, CL 0,85 (medido en túnel hasta 180°, Sheldahl & Klimas 1981), frente al 1,6 de un ala de ave de cara.
El águila con las alas abiertas en el techo y 60 km/h de viento de cola sigue sin aguantar parada (el aire la levanta),
pero aguanta desde ~29 km/h en vez de desde ~36; asida al retrovisor, a las barras o a la antena, el búho o el buitre ya
no despegan con el coche parado.

**A dónde va la energía del golpe** (primer principio, §2.10). Del tigre que choca con la puerta (34,8 kJ respecto al
coche): el 29 % abolla la chapa, el 55 % acaba en calor al resbalar (el rozamiento de las marcas), el 5 % empuja al
coche, el 5 % se lo quedan sus patas y su cuerpo y el 6 % se lo lleva al caer. Las garras apenas se llevan nada: no
entran en el metal.

**El casuario (unidad 4d, §10).** No se sube al coche: lo patea. Salta con los pies por delante a ~17 km/h (el trabajo
muscular medido en el salto de un ave con la masa muscular de la pata de una ratite) y su pata no pasa de ~5 veces su
peso (la patada medida del secretario). Contra un coche a 50 km/h (el casuario parado junto a la carretera):

| Casuario | Fuerza máxima de la pata | Puerta o capó (acero de 0,7 mm) | Coche clásico | Coche de aluminio | La daga | Tras la patada |
|---|---|---|---|---|---|---|
| Hembra (58 kg) | 2,9 kN (2,4-3,4) | abolladura de ~6,2 mm bajo el pie | ~5,8 mm | ~5,2 mm | un surco hasta el metal a lo largo de toda la puerta (1 m); no corta el acero | rebota y cae a ~17 km/h |
| Macho (31,5 kg) | 1,6 kN (1,3-1,9) | ~3,2 mm | ~2,9 mm | ~2,6 mm | igual | igual |

La abolladura no depende de la velocidad del coche (la marca la fuerza de la pata); el surco, sí: con el coche parado
no hay surco, a 20 km/h mide ~30 cm y a 50 km/h recorre toda la puerta. En la aleta de plástico la daga la atraviesa.
De los 6,3 kJ que lleva la hembra respecto al coche a 50 km/h, la chapa solo se queda 9 J: la mitad acaba en calor al
resbalar la daga y casi el 40 % se lo lleva al salir despedida. No se agarra ni se sube: el modo «Encima del coche» le
responde con el motivo (§10.5).

**Garras experimentales (unidad 4d, §11).** Cualquier animal con las garras reforjadas en otro material del catálogo
(`inlay`): las duras perforan la chapa y se quedan clavadas; al resbalar, las frágiles se mellan o se parten y las de
metal se doblan. El oro, más blando que la chapa, cede como la queratina.

| Material (resistencia) | Tigre contra la puerta (50/40 km/h) | Águila que se posa en el techo (90/60 km/h) | Oso de frente contra el capó (50/30 km/h) |
|---|---|---|---|
| Carburo de tungsteno (3068 MPa) | raja la chapa; se mellan ~1,8 mm | la perforan; se mellan ~2,0 mm | la perforan; aguantan |
| Diamante (2790 MPa) | raja; se mellan ~1,9 mm | perfora; se mellan ~2,1 mm | perfora; se mellan ~0,9 mm |
| Zafiro (760 MPa) | raja; se mellan ~4,5 mm | perfora; se mellan ~4,8 mm | perfora; se mellan ~3,3 mm |
| Moissanita (380 MPa) | raja; se mellan ~6,7 mm | perfora; se mellan ~7,1 mm | perfora; se mellan ~5,1 mm |
| Circonita (300 MPa) | raja; se mellan ~7,6 mm | perfora; se mellan ~8,1 mm | perfora; se mellan ~5,9 mm |
| Cuarzo, strass, Swarovski (45-52 MPa) | raja; se parten por la base | perfora; se parten | perfora; se parten |
| Acero y titanio (fluyen a 700 y 525 MPa) | perforan (el acero la raja); se doblan ~5-7 mm | perforan; se doblan ~5-7 mm | perforan; se doblan ~3,5-5,7 mm |
| Hematites | raja; sin datos de rotura | perfora; sin datos | perfora; sin datos |
| Oro (30 HV) | no corta la chapa | no la corta | no la corta |

El tigre con garras de zafiro raja la puerta ~25 cm y la abolla igual hasta el fondo; el instante que decide es cuando
cada punta sale por detrás de la chapa: la chapa la empuja con ~390 N a 0,35 mm del vértice (y la fricción, de lado,
otro tanto) contra los ~48 N que aguanta ahí. El águila con talones de carburo de tungsteno clavados en el techo no se
suelta ni a 400 km/h (con los datos más desfavorables, desde ~200 km/h); sin clavarlos, hacia 196 km/h. Con talones de
vidrio clavados, la banda desfavorable baja a ~99 km/h: recién asomados, se partirían con el tirón. El casuario con la
daga de diamante atraviesa entera la puerta de un coche parado (11 cm) y la daga aguanta: de frente no hay carga lateral.

**Modo defensa (unidad 4d, §12).** El animal asustado aprieta con toda su fuerza. Por pie o mano: el agarre medido de
las rapaces (el águila, ~101 N; la lechuza, ~8 N), la fuerza teórica de los flexores de las garras del tigre (~2,8 kN por
mano) y del oso (~3,7 kN, estimación), y la patada del casuario (~2,9 kN). En la chapa lisa desgarra la pintura hasta el
metal (la lechuza, que en reposo solo araña el barniz, también). La fricción sigue siendo la de su peso, pero para
arrastrarlo el viento tiene que hacer arar la pintura a las garras hundidas (Bowden & Tabor: la dureza por la sección
del surco): quien con su peso ya la araba hasta el metal (el águila, el tigre, el oso) no gana nada, y la lechuza, que
apenas la arañaba, gana ~3 N, más que la fricción de su peso (se suelta hacia 167 km/h en vez de 115). Donde hay algo
que agarrar, el tigre y el oso sujetan más (en las barras, ~5,6 y ~7,3 kN en vez de ~2,2 y ~2,9 kN). En el plástico, las
garras se clavan y el animal se suelta mucho más tarde o nunca. La queratina no raya el parabrisas ni lo agrieta por
contacto; su peso sí puede agrietarlo (el oso).

## 2. Modelo físico

### 2.1 El aire: velocidad relativa y velocidad local

- **Densidad del aire:** ρ = p/(R·T), con R = 287,05 J/(kg·K) (aire seco), la temperatura del aire elegida y la
  presión de la atmósfera tipo a la altitud de la carretera (ISO 2533, troposfera):
  p = p0·(1 − L·h/T0)^(g0/(R·L)), con p0 = 101 325 Pa, T0 = 288,15 K, L = 6,5 K/km y g0 = 9,80665 m/s² (89 875 Pa a
  1000 m, 79 495 a 2000, 70 108 a 3000). Por defecto, 20 °C al nivel del mar: 1,204 kg/m³. A 0 °C, 1,292; a 35 °C,
  1,146; a 2000 m y 20 °C, 0,945.
- **Humedad:** no se modela. El vapor de agua hace el aire menos denso: ρ baja en la fracción (e/p)·(1 − 0,622), con
  e la presión del vapor; con el aire saturado a 35 °C (e = 56 hPa, fórmula de Alduchov & Eskridge 1996) es un 2 %, y
  a 20 °C, un 0,9 %: dentro de las bandas del resto de datos.
- **Cómo cambia la velocidad de despegue:** sin viento, todas las fuerzas del aire son proporcionales a ρ·v², así que
  la velocidad de despegue escala exactamente con √(ρ_ref/ρ) (`air.speedFactor`; un test lo comprueba en todos los
  animales, zonas y posturas). Con viento de frente, de cola o lateral, casi.
- **Viento relativo:** v_x = v + w_frente (w < 0 es viento de cola) y v_aire = √(v_x² + w_lateral²). El viento lateral
  suma al módulo; el Cp es el de guiñada nula (§7).
- **Velocidad local:** el aire no pasa por el techo a la velocidad del coche. Fuera de la capa límite, Bernoulli da
  v_local = v_aire·√(1 − Cp), con el coeficiente de presión de cada zona medido en el túnel sobre el DrivAer (Varney et
  al. 2020): en el techo, Cp = −0,45 y el aire va 1,20 veces más rápido que el coche; al pie del parabrisas, en el
  remanso, más despacio (§4). La presión dinámica que siente el animal es q = ½·ρ·v_local².
- **Coche de referencia:** DrivAer fastback, Cd = 0,309 con 0,136 m² a escala 25 % (2,18 m² a escala real): 312 N a
  100 km/h. Sirve para comparar la resistencia del animal con la del coche.

### 2.2 El animal: resistencia y sustentación

D = q·Cd·A y L = q·CL·S (A y S en m², la excepción a la regla de las áreas en mm² del banco: son áreas de cuerpos y
alas).

- **Ave con las alas plegadas**, agazapada: área frontal A = k_agazapada·S_b con S_b = 0,00813·m^0,666 (m² con m en kg;
  Pennycuick et al. 1988) y k_agazapada = 1,5 (1-2: patas y cabeza alzada; estimación). Cd = 0,4: entre el 0,24 del
  cuerpo de halcón medido sin la interferencia del soporte (Tucker 1990) y el 0,6 de un cuerpo posado más romo
  (estimación); del orden de los cuerpos congelados de Pennycuick (0,25-0,39). El cuerpo también sustenta:
  CL·S = 0,2·S_b (0,15-0,30), de Ponitz et al. (2014).
- **Alas abiertas:** se suma el ala entera (superficie alar medida, §3) en tres estados. «Sustenta»: CL = 1,6, el máximo
  medido en planeo (Tucker & Heine 1990), con Cd = 0,2 (perfil más inducida, estimación). Para la banda desfavorable
  también «frena» (ala en pérdida a ~45°: CL ≈ Cd ≈ 1, placa plana inclinada, Hoerner 1965; estimación); para la
  favorable, «suave» (CL 1,0 y Cd 0,1: poca incidencia; estimación).
- **Con el aire por detrás** (unidad 4g, §13.2): si v_x < 0 (viento de cola más fuerte que la velocidad del coche), el ala
  recibe el aire por el borde de salida y su CL es el de un perfil al revés (`cl_rev`): «sustenta», 0,85; «frena», 1,0
  (una placa en pérdida, igual por los dos lados); «suave», 0. El cuerpo, las alas plegadas y los mamíferos sustentan
  igual por los dos lados. La resistencia no cambia. Un test comprueba que el ala nunca sustenta más con el aire por
  detrás que con el mismo viento de cara.
- **Tigre y oso:** área frontal y Cd por postura (§3). Sin túnel de viento: cuerpo romo con patas, entre el esquiador
  agachado y la persona de pie (Cd 1,0-1,3, Hoerner 1965), y una sustentación pequeña del lomo agazapado. Estimación.

A 90 km/h sobre el techo: águila plegada, D = 7,8 N y L = 2,6 N frente a 49 N de peso; con las alas abiertas, D = 83 N y
L = 600 N (doce veces su peso); tigre agazapado, D = 69 N y L = 82 N frente a 2158 N; oso de pie, D = 246 N (el coche
entero, 253 N).

### 2.3 Fricción, agarre y anclaje

- **Fricción (μ):** la da el motor de siempre (`Physics.compute`: la garra arando el barniz con su parte del peso,
  adhesión más el arado de Hokkirigawa-Kato) y se acota a 0,3-1,0: abajo, uñas que patinan sobre una superficie lisa
  (Roderick et al. 2019: sin asperezas donde clavarse, fricción baja e impredecible); arriba, almohadillas húmedas (la
  piel húmeda pasa de 1, Derler & Gerhardt 2012). Resultado: 1,0 para águila, arpía, halcón, búho y tigre (el motor da
  1,18-1,35), 0,80 la lechuza, 0,79 el buitre y 0,86 el oso. En el parabrisas la queratina no raya el vidrio (r < 0,8)
  y μ es el del vidrio del catálogo, 0,6.
- **Agarre (aves):** en lo que se puede abarcar con los dedos (retrovisor, limpiaparabrisas, barras, antena, borde de la
  ventanilla), anclaje A = 2 pies × F_agarre × k, con F_agarre la de `claws_v2.gd` (§8) y k = 1 (0,6 si la barra se
  desliza entre los dedos, 2μ con μ = 0,3; 2 si los dedos la rodean y el tirón tiene que abrirlos). Estimación.
- **Gancho (tigre y oso):** en las barras y en el marco de la ventanilla, cada pata delantera enganchada sostiene
  k = 0,5 veces el peso (0,25-1; estimación). En el marco de la ventanilla manda además el borde de chapa, que se dobla
  con el momento plástico por unidad de longitud σ0·t²/4 sobre el ancho de la pata y el brazo de la garra (15 mm), por
  un factor 2 (1-4) si el borde está plegado: F_borde = 2·factor·σ0·t²/4·(w_pata/15 mm). Tigre: 862 N; oso: 1121 N.
- **Garras clavadas:** si un golpe ha atravesado el plástico, la fricción pasa a ser un anclaje (agarre o gancho). Ese
  mismo anclaje es lo que el animal aguanta con las garras trabadas mientras rajan la aleta en un golpe de costado
  (unidad 4g, §13.1).
- **Arado en defensa (unidad 4d):** asustado en un panel liso, si sus garras se hunden en la pintura más que en reposo,
  el viento tiene que hacerlas arar para arrastrarlo: un anclaje más sobre la fricción del peso (§12.2).

### 2.4 Equilibrio en el panel

Panel con inclinación β (positiva si sube hacia atrás: capó 10°, limpiaparabrisas 25°, parabrisas 30°, maletero −15°).
La resistencia es horizontal y la sustentación vertical, así que en un panel inclinado cada una se reparte entre la
normal y la tangente. Con a la aceleración del coche (positiva acelerando, negativa frenando) y a_lat la de la curva:

- normal: R = m·(g·cos β + a·sen β) + D_x·sen β − L·cos β;
- tangencial (positiva hacia atrás, cuesta arriba): T = D_x·cos β + L·sen β + m·(a·cos β − g·sen β);
- lateral: T_lat = D_lat + m·a_lat.

Aguanta si √(T² + T_lat²) ≤ μ·R + A. Si R < 0 (la sustentación le ha quitado el apoyo), solo el anclaje sujeta y hace
falta √(T² + T_lat² + R²) ≤ A. Cuando no aguanta, `mode` dice por dónde se va: «despega» (R < 0 o la sustentación ya
sostiene la mitad de su peso), «atras» (viento de cara o aceleración), «delante» (frenada o viento de cola), «abajo»
(resbala cuesta abajo por el panel) o «lado» (curva o viento lateral).

### 2.5 Velocidad de despegue y banda

La velocidad de despegue es la primera velocidad del coche en la que la fuerza necesaria supera a la disponible: barrido
de 0 a 400 km/h en pasos de 5 km/h y bisección (40 pasos). La banda repite la búsqueda con todos los datos del lado
desfavorable (más área, más Cd, más sustentación, el Cp más negativo, μ = 0,3 y el anclaje mínimo; con las alas
abiertas, los dos estados «sustenta» y «frena») y del favorable. Si ni con el coche parado se sostiene, la velocidad es
0 y `atRest = false`.

**Aguantar puede ser una ventana de velocidades.** Aguantar no siempre va «de 0 a la velocidad de despegue». Con una
frenada fuerte, parado no aguanta (la inercia lo lanza hacia delante), y más deprisa el viento de cara le devuelve lo
que le falta. Es el caso del oso pardo de pie en el techo con 0,9 g: la inercia empuja con m·a ≈ 2648 N, el roce solo da
μ·m·g ≈ 2530 N y el aire compensa la diferencia (~118 N) desde ~62 km/h. Pasa lo mismo:
- con un viento de cola, que el coche deja atrás al acelerar;
- en un panel inclinado, cuando el viento de cara lo empuja panel arriba o lo aprieta contra el panel.

Por eso la búsqueda no se para si no aguanta parado. Sigue recorriendo la rejilla hasta la primera velocidad que aguanta
(`holdFromKmh`) y hasta la siguiente que no (`holdToKmh`, INF si aguanta hasta 400 km/h, con su `holdToMode`), y afina
cada borde por bisección. Al frenar hasta parar, el coche pasa por todas las velocidades: aguanta mientras va deprisa
y sale despedido al bajar de `holdFromKmh`.

Por debajo de `REST_KMH` = 0,5 km/h (la mitad del km/h entero con el que se escriben las velocidades), el coche se da
por parado:
- un agarre que va justo en el límite con el coche parado no «se suelta a ~0 km/h»: ni parado se sostiene. Es el caso de
  μ = 1 frente a una frenada de 1 g, solo con fricción, con margen nulo;
- una ventana que empieza por debajo de esa velocidad cuenta como que aguanta parado.

En un barrido de 9728 ensayos (las 8 especies, los 4 coches, todas las zonas y posturas, y 16 maniobras y vientos: sin
nada; frenando a 0,35, 0,9 y 1 g; acelerando a 0,3 g; en curva a 0,3 y 0,8 g; con viento de −60, −40, −20, 20, 40 y
60 km/h; con viento lateral de 30 y 60 km/h, y con 60 km/h de cola y una frenada normal), 810 tienen ventana. Antes de la
unidad 4g eran 954: con el aire por detrás el ala sustenta menos (§13.2), y con viento de cola y las alas abiertas
algunas ventanas empiezan antes o desaparecen (ya aguantan parados). Ninguno aguanta en dos tramos separados de la rejilla
de 5 km/h.

### 2.6 Maniobras y frenada máxima

Las aceleraciones de la tabla `MANEUVERS` salen de fuentes de carretera: frenada normal 0,35 g (3,4 m/s² de AASHTO
2011), de emergencia 0,9 g (adherencia de pico 0,8-0,9 en asfalto seco, Wong), acelerar 0,3 g (0-100 en ~9 s), curva
0,3 g y curva al límite 0,8 g. `max_braking_g(scen, v)` busca la frenada más fuerte que aguanta a esa velocidad (tope
de la búsqueda: 2 g). A poca velocidad, en el techo plano, vale μ (un test lo comprueba); a más velocidad el viento
empuja hacia atrás y compensa parte de la frenada (águila: 1,00 g parada, 1,11 g a 90 km/h, 1,22 g a 130), hasta que
la sustentación le quita el apoyo.

### 2.7 Qué raya y qué perfora

- **La queratina no corta el metal del coche.** Dureza de la queratina de las garras, 26-33 HV, frente a 101 HV del acero de
  horno, 92 HV del acero dulce y 71 HV del aluminio (`CAR_BODIES`): r < 0,8 y la punta cede (el criterio de siempre del
  banco). Un test recorre 216 golpes (8 animales × 3 coches × 3 zonas × 3 combinaciones de velocidad y ángulo) y las marcas
  en reposo: nunca pasan de los 110 µm de pintura.
- **La pintura sí:** el surco del motor (la garra arando con su parte del peso a lo largo del panel) da la profundidad y
  las capas cortadas (`Data.car_layers`). La profundidad que queda al retirar la garra sale de la recuperación elástica
  de la unidad 1f (`Recovery`): el barniz recupera su parte elástica; lo cortado no vuelve.
- **El plástico, también:** en la aleta de PPE/PA la queratina es más dura que el plástico, y en un golpe las garras la
  atraviesan (punción del motor, con los pétalos de Wierzbicki 1999). En un golpe de costado quedan trabadas y la rajan
  si el animal sigue a lo largo del panel y aguanta lo que pide rajarla (unidad 4g, §13.1).
- **El vidrio, no:** en el parabrisas (550 HV) no hay marcas; decide la flexión de la hoja (§2.8). En la ventanilla
  templada (unidad 4m, §15), la flexión o la grieta que abre una punta al menos tan dura como el vidrio.
- **Garras reforjadas (unidad 4d):** con otro material (`inlay`), el mismo motor con la dureza y el módulo del
  material y la forma de la garra: las duras cortan el metal, lo rajan al resbalar y lo perforan al golpear; el oro, más
  blando que la chapa, no. §11.

### 2.8 El golpe al abalanzarse

- **Velocidades:** coche a v (hacia delante), animal a v_a con un ángulo θ respecto al coche (0°: persigue en el mismo
  sentido; 90°: cruza; 180°: de frente) y, en los paneles de arriba, cayendo desde h (v_z = √(2·g·h)). La velocidad
  relativa se descompone en normal al panel (v_n) y tangencial (v_t).
- **Energía:** la que se disipa si acaban moviéndose juntos en la normal, E_n = ½·μ_red·v_n², con la masa reducida
  μ_red = m·M/(m + M) (coche de 800-2500 kg).
- **Punción:** cada garra con su parte de la masa reducida y la velocidad normal, con el motor de siempre (golpe de
  punción). En el metal no entra (§2.7). Si atraviesan el panel, la punta no pasa del hueco de detrás ni de su largo
  (unidad 4o, §16).
- **Abolladura:** la de la unidad 1f (`Dent.strike`, calibrada con Nippon Steel 2013): colapso plástico y trabajo de
  membrana, con el golpe repartido entre la chapa y el muelle de la pata (`Physics.MODEL.limbStiffness`). La energía se
  reparte entre los apoyos (4 patas o 2 pies arriba; hombro y cadera en un costado) y descuenta lo que se quedan las
  garras al clavarse. Añadido de esta unidad: el muelle de la pata no se comprime más allá de su recorrido (150 mm,
  estimación); con cientos de kilos, lo que no cabe en ese recorrido va a la chapa (`Dent.depth_for_energy`). La
  abolladura se para en el hueco bajo el panel (capó 80 mm, techo 100, puerta 150, aleta 60: estimación; el capó,
  dentro de los 20-100 mm de los estudios de protección de peatones, que desde la unidad 4o son su banda: §16.3).
- **Parabrisas:** el laminado de la unidad 1f (`Glazing.WINDSCREEN`: 2,1 + 0,76 PVB + 2,1 mm; resistencia del recocido
  45 MPa, EN 572-1). La hoja flexa como la ventana (`Physics.pane_break` con el radio de apoyo de la pata); la fuerza
  de pico por apoyo es v_n·√(m_apoyo·k), con la hoja y la pata en serie (FISICA.md §15). Se agrieta si la fuerza pasa
  de la que parte la hoja, pero el PVB la sujeta: no cae. «Puede atravesarlo» si la energía supera los 88,7 J del
  ensayo de homologación (bola de 2,26 kg desde 4 m, JIS R 3212 / CEPE R43): el modelo no sabe cuánto más aguanta la
  lámina.
- **Ventanilla** (unidad 4m, §15): la hoja templada del banco (`Glazing.SIDE_WINDOW`: 4 mm, 120 MPa a flexión), con la
  misma fuerza de pico por apoyo que el parabrisas. Estalla entera si esa fuerza la parte al flexar o si cada garra, con
  F·apoyos/garras, abre con una punta al menos tan dura como el vidrio la grieta que atraviesa la capa comprimida
  (`Glazing.tempered_result`); si no, aguanta entera. Al estallar el hueco queda abierto, y el modelo no calcula si el
  animal entra en el coche.
- **Marcas y deslizamiento:** el impulso de fricción del choque (μ·J_n, con J_n = μ_red·v_n) frena la velocidad
  tangencial; mientras la chapa se hunde, las garras ya marcan. En un panel de arriba sigue la fricción del peso
  (a = μ·g): si le da tiempo a frenar antes de que se acabe el panel, se queda encima; si no, se sale a la velocidad que
  le quede. En un costado no hay peso que lo apriete contra la chapa: cae. La longitud de las marcas es lo que resbala.
  Si sus garras han atravesado la aleta de plástico en un costado, quedan trabadas y la rajan mientras sigue a lo largo
  del panel: el desgarro lo frena con n·R·t (unidad 4g, §13.1), y las marcas son las ranuras del desgarro.
- **Después:** si se queda encima, el mismo equilibrio de §2.4 dice si aguanta a esa velocidad (`hold`). Si se cae, la
  velocidad respecto al suelo es la del coche más la relativa con la que sale. Un ave que aterriza (no lleva contra el
  panel más velocidad que la de su propia caída) sale volando; si ha chocado, sale despedida. Unas garras clavadas en el
  plástico se desenganchan (en un costado, después de rajarlo, si han podido).
- **El casuario** no cae ni choca con todo el cuerpo: salta y patea. En la normal del panel llega con la velocidad del
  salto, su pata no pasa de su fuerza máxima y solo golpea lo que tiene a la altura de las patas (capó, puerta o
  aleta). §10.3.

### 2.9 Resistencia añadida al coche

`dragShare` es la resistencia del animal entre la del coche de referencia a la misma velocidad de aire, y `powerW` la
potencia de más que gasta el motor (D_x·v). Con viento de cola a poca velocidad, D_x < 0 y `powerW` sale negativa: el
animal hace de vela.

### 2.10 Balance de energía del golpe (primer principio)

La energía cinética del animal respecto al coche, E = ½·m·v_rel², acaba en seis sitios (`impact(p).energy`):

| Término | Fórmula | Fuente o calidad |
|---|---|---|
| Garras | trabajo de punción de las garras; en un costado de plástico, más el desgarro de las garras trabadas, ½·m·(v_t1² − v_salida²) = n·R·t·L (unidad 4g) | motor del banco (punción con golpe); el desgarro, con la resiliencia con entalla de la ficha de SABIC (estimación, §13.1) |
| Chapa (o vidrio) | trabajo plástico de la abolladura; en el parabrisas, lo que almacena la hoja hasta agrietarse, U = F²/2k; en la ventanilla templada (4m), lo que la carga hasta estallar (0 si aguanta: se lo devuelve al animal) | unidad 1f (`Dent`, calibrada con Nippon Steel 2013); Roark (FISICA.md §15) |
| Animal | el resto de ½·μ_red·v_n²: patas, cuerpo y rebote (en el parabrisas, también la lámina de PVB; si la abolladura llega al fondo, lo que hay debajo del panel) | estimación: es lo que queda |
| Empujón al coche | ½·(m − μ_red)·v_n² | conservación del momento en un choque plástico |
| Rozamiento (calor) | ½·m·(v_t² − v_salida²), menos lo que se lleva el desgarro | trabajo de la fricción de Coulomb con la μ del motor |
| Salida | ½·m·(v_salida² + v_aleja²) | lo que se lleva el animal al salir del panel (cae o sale volando) |

En la normal, el golpe es corto y el coche se mueve libre: solo se disipa la energía de la masa reducida
(½·μ_red·v_n²) y el resto empuja al coche. A lo largo del panel, el motor y los neumáticos mantienen la velocidad del
coche: la energía es la del animal respecto a él (½·m·v_t²), y la fricción la convierte en calor mientras resbala (y
deja las marcas). v_aleja es la componente con la que el animal se aleja del panel, si la hay. Los términos suman
exactamente el total (un test lo comprueba en 360 golpes: 8 animales × 3 coches × 5 zonas × 3 combinaciones de
velocidad y ángulo).

| Golpe | Total | Garras | Chapa o vidrio | Animal | Coche | Calor | Salida |
|---|---|---|---|---|---|---|---|
| Tigre contra la puerta (cruza a 40, coche a 50) | 34,8 kJ | ~0 | 29 % | 5 % | 5 % | 55 % | 6 % |
| Tigre que cae sobre el techo (cruza a 40, coche a 50, 0,5 m) | 35,9 kJ | ~0 | 1 % | 1 % | 0,4 % | 35 % | 62 % |
| Tigre que persigue y salta al techo (56 frente a 50) | 1,4 kJ | ~0 | 35 % | 33 % | 11 % | 22 % | 0 |
| Tigre contra el parabrisas | 35,9 kJ | — | 2 J | 25 % | 4 % | 42 % | 29 % |
| Tigre contra la aleta de plástico (4g: la raja entera) | 34,8 kJ | 2,6 % (0,5 % la punción y 2,1 % el desgarro) | 0 (recupera) | 33 % | 5 % | 55 % | 3,7 % |
| Águila que se posa en el techo (90/60, 0,2 m) | 183 J | 0 | 0,1 % | 5 % | 0 | 82 % | 12 % |
| Águila de frente contra el parabrisas (130 km/h relativos) | 3,3 kJ | — | 1,4 J | 25 % | 0,1 % | 44 % | 31 % |
| Casuario (hembra) que patea la puerta de un coche a 50 (unidad 4d) | 6,3 kJ | 0 | 0,2 % | 10 % | 0,4 % | 50 % | 39 % |
| Tigre con garras de zafiro contra la puerta (unidad 4d) | 34,8 kJ | 0,4 % | 29 % | 4 % | 5 % | 55 % | 6 % |

Con garras reforjadas y con la patada del casuario los términos también suman exactamente el total (otro test: 9
animales × 3 materiales × 3 coches × sus zonas × 3 combinaciones). En la patada, lo que no se queda la chapa se lo
queda la pata al flexionarse y rebotar (término «animal»).

Lo que más se lleva casi siempre es el rozamiento: el animal llega con mucha velocidad a lo largo de la carrocería y la
fricción la convierte en calor. La abolladura solo manda cuando el golpe es de frente contra la chapa (la puerta).

## 3. Datos por animal

Las masas son las del catálogo 1.x. Agarre de un pie (N) con su banda (§8).

| Animal | Masa | Agarre 1.x → 2.0 | μ en la pintura | Área frontal (cuerpo) | Superficie alar | Envergadura | Fuente del ala |
|---|---|---|---|---|---|---|---|
| Águila real | 5 kg | 110 → 100,9 N (65-299) | 1,0 | S_b = 0,0237 m² | 0,685 m² (0,60-0,75) | 2,17 m | Alerstam et al. 2007: 0,597 m² con 4,07 kg, escalado a 5 kg (S ∝ m^(2/3)) |
| Águila arpía | 9 kg | 200 → 178,5 N (104-529) | 1,0 | 0,0351 m² | 0,67 m² (0,55-0,85) | 2,0 m | estimación: b = 1,76-2,24 m (Britannica) con alargamiento ~6 |
| Halcón peregrino | 1 kg | 15 → 15,8 N (12,1-46,9) | 1,0 | 0,0081 m² | 0,147 m² (0,126-0,16) | 1,1 m | Alerstam et al. 2007: 0,1257 m² con 0,789 kg |
| Búho | 2 kg | 45 → 45 N (41,5-122,9) | 1,0 | 0,0129 m² | 0,412 m² (0,36-0,46) | 1,52 m | Johnson 1997: búho cornudo hembra de 1,345 kg |
| Lechuza | 0,35 kg | 8 → 8 N (7,3-22,7) | 0,80 | 0,0040 m² | 0,155 m² (0,150-0,161) | 0,99 m | Johnson 1997: hembras de 0,529 kg y macho de 0,38 kg |
| Buitre leonado | 8 kg | 60 → 60 N (20,3-159,2) | 0,79 | 0,0325 m² | 0,889 m² (0,87-0,91) | 2,6 m | Harel et al. 2016: carga alar de 9 kg/m², alargamiento 7,61 |

| Mamífero | Masa | Área frontal agazapado / de pie | Cd agazapado / de pie | CL·S agazapado / de pie | Garras | Carrera |
|---|---|---|---|---|---|---|
| Tigre | 220 kg | 0,18 m² (0,15-0,25) / 0,30 m² (0,25-0,40) | 0,7 (0,5-0,9) / 1,0 (0,8-1,2) | 0,15 m² (0,05-0,3) / 0 (0-0,1) | 8 en contacto | 56 km/h (Garland 1983) |
| Oso pardo | 300 kg | 0,28 m² (0,20-0,35) / 0,45 m² (0,35-0,55) | igual | 0,2 m² (0,08-0,4) / 0 (0-0,1) | 10 en contacto | 48 km/h (Garland 1983) |

Todo lo del tigre y el oso es estimación (§5), salvo las velocidades de carrera, que Garland (1983) califica de «más o
menos anecdóticas». Otros datos por animal en `BODIES`: `contact_mm` (radio del apoyo en el parabrisas), `paw_mm`
(ancho de la pata en el borde de chapa) y, solo para el dibujo, `height_m` y `length_m`. Desde la unidad 4g, cada campo
lleva su fuente y su calidad (`sources`):

| Campo | Aves | Tigre | Oso | Fuente y tipo |
|---|---|---|---|---|
| `contact` (garras que se clavan) | 4 | 8 | 10 | aves: en cada pie, el talón trasero y el delantero que aprieta contra él, la pinza cuyo agarre se midió (estimación); tigre: cuatro por mano, su huella marca cuatro dedos (McDougal 1999, en Sharma et al. 2003); oso: cinco por mano (Mattson 2003); que se agarre con las manos es la suposición (estimación) |
| `contact_mm` (radio del apoyo) | 15-35 mm | 50 mm | 65 mm | aves: la mitad del largo del pie, sin medición (estimación); tigre: la mitad del ancho de su almohadilla, ~10 cm en los machos (secundaria); oso: la mitad de 130 mm (estimación, cota baja) |
| `paw_mm` (ancho de la almohadilla) | — | 100 mm | 130 mm | tigre: más de 9,7 cm en los machos (McDougal 1999, en Sharma et al. 2003; secundaria); oso: 12,5-14,5 cm en las hembras adultas y más de 14,5 en los machos (Mattson 2003): un oso de 300 kg es un macho, así que 130 mm es una cota baja (estimación) |
| `frontal_m2`, `cd`, `cls_m2` | — | §3 | §3 | sin túnel de viento: cuerpo romo con patas (Hoerner 1965), estimación |
| `height_m`, `length_m` | | | | solo dibujo | Los datos del casuario (masa
por sexo, carrera, salto y fuerza de la patada) están en §10.2.

Anclaje de un ave agarrada (2 pies × agarre × k): águila 202 N (78-1195), arpía 357 N (125-2114), halcón 32 N
(15-188), búho 90 N (50-492), lechuza 16 N (9-91), buitre 120 N (24-637).

Velocidad mínima de vuelo del ala sola (CL = 1,6), en el aire libre y la del coche con el aire del techo: águila 31 y
26 km/h, arpía 42 y 35, halcón 30 y 25, búho 25 y 21, lechuza 17 y 14, buitre 35 y 29 km/h. Con las alas abiertas
despegan un poco antes (el cuerpo también sustenta), y un test lo comprueba.

## 4. Datos por zona

| Zona | Cp (banda) | v_local/v | Inclinación | Anclaje (ave / mamífero) | Fuente del Cp |
|---|---|---|---|---|---|
| Capó | −0,35 (−0,49…−0,25) | 1,16 | 10° | fricción | DrivAer, PIV en el plano central: 1,12-1,22 veces el coche sobre la mitad delantera del capó |
| Limpiaparabrisas | +0,3 (0,1…0,5) | 0,84 | 25° | agarre / fricción | remanso al pie del parabrisas (Mathai et al. 2021); valor sin publicar: estimación |
| Parabrisas | 0 (−0,3…0,3) | 1,00 | 30° | fricción (vidrio) | entre el remanso y la succión del borde del techo: estimación |
| Techo | −0,45 (−0,64…−0,30) | 1,20 | 0° | fricción | DrivAer, tomas del techo: fastback −0,47, notchback −0,50, estate −0,38 |
| Barras de techo | −0,30 (−0,39…−0,12) | 1,14 | 0° | agarre / gancho | DrivAer, PIV: 1,06-1,18 veces el coche a 4-40 mm del techo |
| Antena | −0,25 (−0,39…−0,12) | 1,12 | 0° | agarre (solo aves) | DrivAer, PIV sobre la parte trasera del techo |
| Retrovisor | −0,34 (−0,49…−0,26) | 1,16 | 0° | agarre (solo aves) | DrivAer, tomas de las ventanillas delanteras |
| Borde de la ventanilla | −0,34 (−0,49…−0,26) | 1,16 | 0° | agarre / gancho (borde de chapa) | DrivAer, tomas de las ventanillas |
| Maletero | −0,15 (−0,28…0,01) | 1,07 | −15° | fricción | DrivAer, luneta y zaga de las tres carrocerías |
| Aleta | −0,35 (−0,49…−0,25) | 1,16 | 5° | fricción | como la parte delantera del capó: estimación |

Zonas del golpe (`IMPACT_ZONES`): capó, techo y parabrisas por arriba (con su inclinación y la caída); puerta, aleta y,
desde la unidad 4m, la ventanilla templada (`luna`, §15) de lado. Panel para resbalar (`slide_m`): capó 1,1 m, techo 1,6, parabrisas 0,9, puerta 1,0 y aleta 0,8. Desde la unidad
4g cada zona lleva la fuente y la calidad de su inclinación, su panel y su hueco (`sources`):

| Zona del golpe | Inclinación | Panel | Hueco bajo el panel | Fuente (todo, estimación) |
|---|---|---|---|---|
| Capó | 10° | 1,1 m | 80 mm | largo dentro de los 54-123 cm medidos en 452 frontales de turismos, en su lado largo, y ángulo por debajo de sus 11-44°: una berlina baja (Cui et al. 2025); hueco dentro de los 20-100 mm ensayados bajo un capó con una cabeza de ensayo (Fredriksson et al. 2007) |
| Techo | 0° | 1,6 m | 100 mm | plano; largo, el de una berlina media como el DrivAer (2,786 m de batalla, Ashton et al. 2024), sin medición panel a panel; hueco por debajo de los 127 mm que la FMVSS 216 deja bajar el techo |
| Parabrisas | 30° | 0,9 m | — | 60° desde la vertical, geometría de berlina sin medición; no se abolla: se agrieta |
| Puerta | 90° | 1,0 m | 150 mm | un costado vertical (las puertas se inclinan unos grados hacia dentro); hueco: los primeros 152 mm de aplastamiento con los que la FMVSS 214 mide la puerta |
| Aleta | 90° | 0,8 m | 60 mm | como la puerta; hueco sin medición: menos que en la puerta, porque detrás está el paso de rueda |
| Ventanilla (4m) | 90° | 0,8 m | — | la ventanilla de la puerta delantera de una berlina media, sin medición; no se abolla: aguanta entera o estalla (§15). Va de la cintura (~0,89 m) al techo (1,475 m) |

Las zonas en las que se queda (`ZONES`) usan la misma geometría (el capó, la de Cui et al. 2025; el resto, la de una
berlina media, sin medición panel a panel).

**Objetivos.** Los cuatro coches del catálogo: `coche` (acero de horno HC180B de 0,7 mm), `cocheclasico` (acero dulce
de 0,9 mm), `cochealu` (aluminio AA6016 de 1 mm) y `cocheplastico`, que es una **aleta** de PPE/PA de 2,5 mm. Con la
aleta de plástico, la zona con sentido es «aleta»; en las demás zonas el modelo trata el panel como si fuera de ese
mismo plástico. La integración puede limitar las zonas de ese objetivo a la aleta.

## 5. Estimaciones del modelo

| Magnitud | Valor | Razonamiento |
|---|---|---|
| Postura agazapada del ave | área ×1,5 (1-2) | patas y cabeza alzada frente al cuerpo en vuelo de Pennycuick |
| Cd del cuerpo posado | 0,4 (0,24-0,6) | el 0,24 de Tucker (1990) es el cuerpo en vuelo sin soporte; posado, más romo |
| Sustentación del cuerpo | CL·S = 0,2·S_b (0,15-0,3) | Ponitz (2014) midió CL 0,045-0,087 sobre el área en planta (3,34 veces la frontal) en picado |
| Cd del ala que sustenta | 0,2 | perfil más inducida a CL máximo; sin medición en esta postura |
| Ala en pérdida («frena») | CL ≈ Cd ≈ 1 | placa plana inclinada ~45° (Hoerner 1965) |
| Ala a poca incidencia («suave») | CL 1,0, Cd 0,1 | cota favorable |
| Superficie alar de la arpía | 0,67 m² (0,55-0,85) | sin medición: envergadura de Britannica con alargamiento ~6 |
| Aerodinámica del tigre y el oso | §3 | sin túnel: área desde la masa y el tamaño; Cd de cuerpo romo con patas (Hoerner 1965) |
| Cp del limpiaparabrisas y del parabrisas | +0,3 y 0 | Mathai et al. (2021) describen el remanso, pero no publican el valor |
| Cp de la aleta | el del capó | junto a él, sin tomas en el DrivAer |
| Fricción | acotada a 0,3-1,0 | el motor da hasta 1,35 (arado hondo en el barniz); el tope es el de la piel húmeda de las almohadillas (Derler & Gerhardt 2012) |
| Agarre alrededor de una barra | k = 1 (0,6-2) | de deslizar entre los dedos al cierre de forma |
| Gancho del mamífero | 0,5 veces el peso por pata (0,25-1) | los felinos trepan colgados de las manos; sin medición |
| Borde de la ventanilla | brazo de 15 mm, factor 2 (1-4) | momento plástico de una chapa (Roark); borde sencillo o plegado |
| Recorrido de la pata al golpear | 150 mm | orden de la flexión de las patas al aterrizar; sin medición y sin banda (§16.3) |
| Rigidez de la pata | 10 N/mm (la del motor) | la de una pata o un dedo; caso medido más parecido (unidad 4g, `LIMB_STIFFNESS`): la rigidez de la pata al correr, que crece como M^0,67 en animales de 0,1 a 140 kg (Farley et al. 1993). La misma para todos: con la de un tigre la chapa se llevaría más energía y las abolladuras serían más hondas (cota baja). Sin banda (§16.3) |
| Hueco bajo el panel | capó 80, techo 100, puerta 150, aleta 60 mm | capó, dentro de los 20-100 mm ensayados bajo un capó con una cabeza de ensayo (Fredriksson et al. 2007); techo, por debajo de los 127 mm que la FMVSS 216 deja bajar el techo; puerta, los primeros 152 mm con los que la FMVSS 214 mide la puerta; aleta, sin medición (menos que la puerta: detrás está el paso de rueda). Banda del golpe, solo en el capó: 20-100 mm (§16.3) |
| Largo e inclinación de los paneles (4g) | capó 1,1 m y 10°; techo 1,6 m; parabrisas 0,9 m y 30°; puerta 1,0 m; aleta 0,8 m | el capó, en los 54-123 cm medidos en 452 frontales de turismos y por debajo de sus 11-44° (Cui et al. 2025): una berlina baja; el resto, una berlina media como el DrivAer (Ashton et al. 2024), sin medición panel a panel |
| Garras que se clavan y apoyo de las patas (4g) | aves 4, tigre 8, oso 10; apoyo y almohadilla en §3 | tigre: cuatro dedos por mano y almohadilla de ~10 cm (McDougal 1999, en Sharma et al. 2003); oso: cinco dedos y almohadilla de 12,5-14,5 cm en las hembras y más en los machos (Mattson 2003): los 130 mm del modelo son una cota baja; aves: la pinza del agarre medido |
| Tenacidad del plástico al rajarlo (4g) | R = 45 kJ/m² (20-50) | caso medido más parecido: la resiliencia con entalla del mismo plástico, NORYL GTX964 (SABIC 2024: Charpy 45 kJ/m² a 23 °C, Izod 50; 20 a −30 °C); una grieta de todo el espesor por garra, sin contar el doblado de los labios del desgarro ni la pintura: cota baja de la energía y alta del largo del desgarro (§13.1) |
| Lo que aguanta el animal con las garras trabadas (4g) | su anclaje con las garras clavadas | el agarre medido de un ave (2 pies × agarre, Sustaita & Hertel 2010) o las manos enganchadas de un mamífero (media vez su peso por mano, §2.3; asustado, sus flexores): si rajar pide más, sus dedos ceden y se le sueltan |
| Ala con el aire por detrás (4g) | CL 0,85 («sustenta»), 1,0 («frena»), 0 («suave») | caso medido más parecido: el perfil NACA 0012 al revés, medido en túnel hasta 180° (Sheldahl & Klimas 1981): el CL más alto en valor absoluto, 0,85, a 10° de los 180°; es un perfil de envergadura infinita, así que un ala daría algo menos (cota alta); la placa en pérdida, igual por los dos lados (§13.2) |
| Apoyos que reciben el golpe | 4 patas, 2 pies, o hombro y cadera | reparto uniforme |
| Masa efectiva de un golpe de halcón | 0,25 kg por garra | la de la ficha 1.x |
| Término «animal» del balance de energía | lo que queda de la energía normal | patas, cuerpo, rebote y lámina de PVB juntos; sin medición |
| Coche durante el golpe | libre en la normal; a velocidad constante a lo largo del panel | golpe corto frente a un coche de más de una tonelada que el motor mantiene en marcha |
| Salto del casuario (4d) | 4,84 m/s (hasta 5,93) | caso medido más parecido: el trabajo muscular del salto de la gallina de Guinea (Henry et al. 2005) con la masa muscular de la pata del avestruz (Hutchinson et al. 2015); nadie lo ha medido en un casuario (§10.3) |
| Fuerza máxima de la pata del casuario (4d) | 5,1 pesos corporales (4,2-6,0) | caso medido más parecido: la patada del secretario sobre una placa de fuerza (Portugal et al. 2016) |
| Masa central del macho de casuario (4d) | 31,5 kg | el centro de los 29-34 kg de Grzimek (2003) |
| Resistencia del strass y del cristal Swarovski (4d) | 45 MPa | caso medido más parecido: el vidrio recocido de la norma (EN 572-1) |
| Resistencia del cuarzo (4d) | 52,4 MPa | caso medido más parecido: la sílice fundida, de la misma composición (Corning HPFS 7980, superficie desgastada) |
| Resistencia de la circonita (4d) | 300 MPa (150-300) | caso medido más parecido: la circonia cúbica policristalina (Adams et al. 1997) |
| Resistencia de la moissanita (4d) | 380 MPa (149-380) | caso medido más parecido: el carburo de silicio sinterizado (Hexoloy SA); la banda baja, con la tenacidad del monocristal (Qian et al. 2005) y Griffith |
| Dónde empuja la chapa a una garra (4d) | el centro de lo que está dentro del metal; perforada, el borde del agujero | estática de la viga en voladizo; sin medición (§11.2) |
| Trozo que se desprende de una garra frágil (4d) | todo el tramo que no aguanta la carga | cota alta: si se desprendiera a trozos, con la carga cada vez en el nuevo extremo, en un cono bastaría con ~0,4 veces esa longitud |
| Garras reforjadas clavadas en la chapa (4d) | hasta la base (valor); recién asomadas (banda desfavorable) | sin medición de cuánto quedan dentro; con las del golpe, la profundidad de su punción |
| Fuerza de defensa del tigre (4d) | 2,8 kN por mano (1,9-2,8) | caso medido más parecido: la sección fisiológica del flexor profundo de los dedos de los félidos (Martens et al. 2023) llevada a 220 kg, por la tensión específica de Powell et al. (1984); fuerza del tendón (cota alta en la punta) |
| Fuerza de defensa del oso (4d) | 3,7 kN por mano (2,5-3,7) | la misma recta de los félidos a 300 kg; sin disecciones publicadas del antebrazo de un oso |
| Reparto de la defensa (4d) | aves: cada talón con todo el agarre (la pinza); mamíferos: entre los cinco dedos | el agarre medido es la fuerza entre el dedo trasero y los delanteros; el flexor profundo tira de los cinco dedos |
| Arado de las garras hundidas en defensa (4d) | F = H·(anchura × profundidad / 2) por garra que tira; banda 0 a la pintura de 425 MPa | caso medido más parecido: el término de arado de Bowden & Tabor (1950) con la dureza de la pintura medida por nanoindentación (Vodnick 2006); suposiciones: la garra no se sale de su surco, la pintura no se desconcha, aran la mitad de las garras (las que tiran hacia atrás) y el surco en V es una cota baja para una punta redondeada (§12.2) |

## 6. Discrepancias entre fuentes

1. **Agarre de las rapaces: técnica contra técnica.** Ward et al. (2002) midieron 7,7 N en cernícalos de 122 g;
   Sustaita & Hertel (2010), 2,6 N en cernícalos de 112 g: casi el triple. Los propios autores lo atribuyen a una posible
   diferencia sistemática entre las técnicas de medida. La banda alta de todos los agarres es ×2,96 por eso.
2. **«400 psi» del águila, «500 psi» del búho.** Circulan por divulgación sin medición publicada que los respalde, y una
   presión no es una fuerza (depende del área de la punta). No se usan.
3. **La velocidad del halcón en picado.** La ficha 1.x decía «>300 km/h». Lo medido en la naturaleza son máximos de
   31-39 m/s (hasta ~140 km/h) con radar (Alerstam 1987); un gerifalte adiestrado llegó a 52-58 m/s (Tucker et al.
   1998). Los 389 km/h de «Frightful» (1999) son un récord de cetrería sin publicación científica.
4. **Cp del techo:** −0,47, −0,50 y −0,38 en las tres carrocerías del DrivAer; las tomas individuales van de −0,64 a
   −0,30 según la posición. La banda las contiene todas (test).
5. **Cd de un cuerpo de ave:** 0,24 en el halcón de Tucker (1990) frente a 0,25-0,39 en los cuerpos congelados de
   Pennycuick (1988). Tucker midió y descontó la resistencia de interferencia del soporte, que infla el Cd de un cuerpo
   montado en el túnel.
6. **Velocidades de carrera del tigre y el oso** (56 y 48 km/h): Garland (1983) las recopila de fuentes que él mismo
   llama «más o menos anecdóticas».
7. **La masa del casuario** (4d). Grzimek (2003) da 58 kg para la hembra y 29-34 kg para el macho; Latch (2007), con
   datos del servicio de parques de Queensland, machos de hasta 55 kg y hembras de hasta 76 kg; Westcott & Reid (2002)
   pesaron o estimaron once adultos de 40 a 66 kg. Se usa Grzimek como valor central y Latch como banda alta; las once
   mediciones de Westcott & Reid caen dentro de las bandas (test).
8. **La velocidad del casuario** (4d). Healy (2022, Birds of the World) da «hasta 50 km/h» sin la medición original;
   Borrell (2008), «hasta 30 millas por hora» (48 km/h) en divulgación. Ninguno es una medición publicada, y en la
   patada no hace falta: la carrera solo cuenta a lo largo del panel (§10.3). La ficha 1.x dice «patada a 50 km/h», que
   mezcla la carrera con la patada; el pie llega a ~17 km/h.

## 7. Qué no predice

- **El vuelco.** El animal puede volcar hacia atrás antes de resbalar (el viento empuja por encima de las patas). Con
  el centro de presión a media altura del cuerpo agazapado (~0,2 m) y 10 cm de pie (de los dedos al dedo trasero), el
  águila plegada volcaría hacia 100-120 km/h en vez de resbalar a 196 (estimación gruesa); inclinándose contra el
  viento, como hacen las aves, aguantaría más. Sin datos de la altura del centro de presión ni de cómo se equilibra el
  animal, no se modela.
- **La capa límite y la turbulencia.** v_local es la de fuera de la capa límite; un ave pegada al techo nota algo menos
  y, a la vez, las ráfagas de la estela del parabrisas. Tampoco cambia el Cp con el viento lateral (guiñada).
- **El comportamiento.** Un animal real salta, se agacha, abre o cierra las alas; el modelo congela una postura.
- **El choque real contra fauna.** La colisión de un coche con un animal grande (el frontal, el capó que se levanta, el
  animal que entra por el parabrisas) es otra física: aquí solo el animal que cae o se abalanza sobre la carrocería.
- **Las heridas del animal y las del coche por dentro.** Se da la abolladura del panel, no la estructura, ni lo que
  cuesta repararlo, ni cómo queda el animal.
- **El desgarro de la aleta, en detalle** (unidad 4g, §13.1). Solo la grieta de todo el espesor, con la resiliencia con
  entalla del plástico: no el doblado de los labios para dejar pasar una garra de 12-18 mm de ancho (cota baja de la
  energía), ni el peso del animal colgado, que también la raja hacia abajo mientras la raja a lo largo, ni la temperatura
  del plástico (la banda llega a los 20 kJ/m² de −30 °C). Solo en un costado: en un panel de arriba ya la corta la
  fricción de su peso con las garras (el motor, con μ hasta 1), y sumarle el desgarro contaría dos veces lo mismo. No
  evalúa si unas garras reforjadas se rompen al rajar el plástico (la rotura de §11 es solo en la chapa), ni unas garras
  que se hunden en el plástico sin atravesarlo (se desenganchan, como antes).
- **Lo que aguanta el plástico quieto encima.** Con las garras clavadas en el plástico, el anclaje es el agarre o el
  gancho del animal, sin el tope de lo que aguanta el plástico al rajarse (n·R·t: el tigre, 900 N frente a sus 2158):
  pregunta abierta, porque en un panel de arriba la fricción de su peso ya incluye las garras arando el plástico.
- **La temperatura de destello** en el contacto garra–barniz al resbalar (Jaeger 1942, Archard 1959). Haría falta la
  conductividad y la difusividad térmicas de la queratina y del barniz, el reparto del calor entre los dos y la
  transición vítrea del barniz transparente, con fuentes que no hemos podido verificar; además, el motor ya dice que la
  garra corta el barniz mecánicamente, así que el calor no cambiaría el veredicto.
- **El siguiente panel.** Un animal que sale del capó a gran velocidad chocaría con el parabrisas; el modelo no encadena
  golpes.
- **La humedad del aire** (hasta un 2 % menos de densidad, §2.1).
- **La profundidad de las abolladuras grandes.** Dent está calibrado con una bola de 25 mm (unidad 1f); una pata de
  10 cm o un hombro reparten más la carga. El tope del hueco bajo el panel manda en los golpes grandes.
- **La patada real del casuario** (4d): su dirección, cuántas patadas da, si golpea con los dos pies o la ventana que a
  veces rompe (Naish 2007). Se modela una patada con los pies por delante, con la fuerza máxima medida en otra ave, y
  lo que no se queda la chapa se lo queda la pata.
- **La rotura de las garras reforjadas, más allá de la primera** (4d): el modelo da el instante más cargado y el trozo
  que no aguanta; no sigue a lo que queda de la garra, ni la fatiga, ni el efecto de escala (Weibull), ni la sección
  aplanada y curva de una garra real (§11.6).

## 8. Revisión de las rapaces (`claws_v2.gd`)

`data.gd` es el port exacto del oráculo 1.x y no se toca. `ClawsV2.OVERRIDES` guarda, por id de garra, los campos que
la 2.0 corrige o confirma, cada uno con `value`, `source`, `quality` y, si tiene incertidumbre, `min` y `max`.
`ClawsV2.apply(claw)` devuelve una copia corregida (idempotente) con `sources2` (la procedencia de cada campo); el
catálogo 2.0 debe aplicarla (§9.7).

**El agarre.** La 1.x escalaba linealmente desde el gavilán de Cooper (~22 N por kg de ave), sin fuente para el
escalado. Sustaita & Hertel (2010) midieron el agarre in vivo de accipítridos y halcones y dan su escalado con la masa:
pendiente RMA 0,97 (IC 95 % 0,79-1,15) en accipítridos, casi proporcional a la masa y por encima de la isometría (0,67:
alometría positiva, como en Ward et al. 2002), y 0,86 (0,71-1,01) en halcones. La 2.0 escala desde su tabla 1:
F = 9,77 N·(m/0,4504 kg)^0,97 (gavilán de Cooper hembra) y F = 12,7 N·(m/0,7738 kg)^0,86 (halcón peregrino hembra).
Los valores centrales apenas cambian (el águila, de 110 a 101 N); lo nuevo es la fuente, la pendiente propia de los
halcones y la banda: abajo, la pendiente baja del intervalo (en el halcón, la media menos su error); arriba, ×2,96 (la
dispersión entre técnicas, §6).

| Id | Campo | 1.x | 2.0 | Calidad | Por qué |
|---|---|---|---|---|---|
| aguila | force | 110 N | 100,9 N (65,4-298,8) | estimación | escalado de Sustaita & Hertel con pendiente 0,97; la 1.x cae dentro de la banda |
| aguila | desc | «~22 N por kg» | agarre de ~100 N (65-300); los «400 psi» no tienen medición; la queratina no corta el acero | estimación | texto con fuente |
| arpia | force | 200 N | 178,5 N (104,1-528,5) | estimación | ídem; nadie ha medido una arpía: sus patas enormes podrían ponerla arriba |
| arpia | desc | «agarre estimado (escalado por masa)» | agarre de ~180 N (100-530) sin medición en la especie; talón trasero de hasta ~13 cm, el más largo de las águilas vivas (Guinness World Records) | estimación | texto con fuente |
| halcon | force | 15 N | 15,8 N (12,1-46,9) | secundaria | medido: 12,7 ± 2,6 N en hembras de 774 g, escalado a 1 kg con 0,86; la 1.x ya encajaba |
| halcon | strike | v = 40 m/s | se confirma con fuente | secundaria | máximos de 31-39 m/s por radar; gerifalte, 52-58 m/s |
| halcon | desc | «picado a >300 km/h» | radar: hasta ~140 km/h; gerifalte adiestrado, ~200 km/h; «Frightful» sin publicación | secundaria | el dato 1.x no está medido en la naturaleza |
| buho | force | 45 N | 45 N (41,5-122,9) | estimación | sin medición verificable: abajo, lo de un gavilán de su masa (los búhos aprietan al menos como las diurnas de su tamaño, Ward et al. 2002) |
| buho | desc | «agarre estimado (escalado por masa)» | los búhos aprietan más que las diurnas de su tamaño; los «500 psi» no tienen medición; agarre estimado de 45 N (40-120) | estimación | texto con fuente |
| lechuza | force | 8 N | 8 N (7,3-22,7) | estimación | un gavilán de su masa daría 7,3-8,0 N; se mantiene |
| buitre | force | 60 N | 60 N (20,3-159,2) | estimación | pie de caminar con agarre rudimentario (Wang et al. 2024, el buitre negro); arriba, lo de un gavilán de su masa |

La dureza y el módulo de la queratina (hv, E) se confirman sin cambios: no hay medición en talones de rapaz y se quedan
los de la queratina de garra (McKittrick et al. 2012), con los que la queratina nunca raya el acero del coche.

## 9. Guía de integración (oleada 2)

Uso: `const MovingCar = preload("res://core/lab/moving_car.gd")`. Todo es estático, determinista y sin nodos; se puede
llamar desde un hilo. Los animales con datos: las seis rapaces, el tigre, el oso y el casuario
(`MovingCar.supports(claw)`); para el resto, `setup` e `impact` devuelven `{ ok: false, reason }`. Qué modos tiene cada
uno: `supports_hold(claw)` («Encima del coche»: todos menos el casuario, que responde con `HOLD_NO_REASON`) y
`supports_impact(claw)` («Se abalanza»: todos). Las zonas del golpe de cada animal, `impact_zones_for(claw)` (el
casuario, solo `KICK_ZONES`; la ventanilla, solo quien llega a ella: `window_reach`, unidad 4m).

### 9.1 Parámetros nuevos (`MovingCar.PARAMS`)

| Parámetro | Unidad | Rango | Por defecto | Qué es |
|---|---|---|---|---|
| `v_kmh` | km/h | 0-230 | 90 | velocidad del coche (el deslizador: la velocidad máxima de un turismo de serie, 200-230 km/h; `SLIDER_MAX_KMH`) |
| `wind_kmh` | km/h | −60-60 | 0 | viento de frente (+) o de cola (−) |
| `crosswind_kmh` | km/h | 0-60 | 0 | viento lateral |
| `accel_g` | g | −1-0,5 | 0 | aceleración del coche (+ acelera, − frena) |
| `lateral_g` | g | 0-0,9 | 0 | curva |
| `animal_kmh` | km/h | 0-70 | 40 | velocidad del animal al abalanzarse |
| `angle_deg` | ° | 0-180 | 90 | 0 persigue al coche, 90 cruza, 180 de frente |
| `drop_m` | m | 0-3 | 0,5 | caída sobre un panel de arriba |
| `car_mass_kg` | kg | 800-2500 | 1400 | masa del coche |
| `temp_c` | °C | −20-45 | 20 | temperatura del aire |
| `altitude_m` | m | 0-3000 | 0 | altitud de la carretera (presión de la atmósfera tipo) |

Además: `zone` (ids de `ZONES` para quedarse y de `IMPACT_ZONES` para el golpe; `zones_for(claw)` da las del animal),
`posture` (`postures_of(claw)`; nombres en `POSTURE_NAMES`), `embedded` (garras clavadas en plástico) y `model`
("2.0"). Botones de maniobra: `MANEUVERS` (id, nombre, `accel_g`, `lateral_g`, fuente). Velocidades: km/h en todos los
parámetros y resultados (por dentro, m/s).

De la unidad 4d (todos opcionales; sin ellos, el resultado es el de siempre, al bit):

| Parámetro | Valores | Por defecto | En | Qué es |
|---|---|---|---|---|
| `inlay` | id de `Data.INLAYS` | «none» (queratina) | `setup`, `hold_report`, `impact` | material de las garras de cualquier animal (§11); uno desconocido da `{ ok: false, reason }` |
| `sex` | «hembra» o «macho» (`SEXES`, `SEX_NAMES`, `sexes_of(claw)`) | «hembra» | `impact` | la masa del casuario (§10.2); el resto no tiene sexo |
| `defense` | bool | false | `setup`, `hold_report`, `impact` | asustado, aprieta con toda su fuerza (§12) |
| `embed_mm` | mm | la base de la garra | `setup` (interno) | hasta dónde han entrado unas garras reforjadas clavadas en la chapa (`impact` lo pasa al quedarse encima) |

### 9.2 Llamadas y coste

| Llamada | Cuándo | Coste medido |
|---|---|---|
| `setup(p)` | al cambiar animal, coche, zona, postura, viento o maniobra | ~0,4 ms (una llamada a `compute`) |
| `at_speed(scen, v_kmh)` | en cada fotograma del deslizador | ~20 µs, O(1) |
| `detach(scen)` y `detach_verdict(scen, det)` | con `setup` | ~0,2 ms |
| `curve(scen, n = 61, v_max = 150)` | con `setup` (la gráfica) | ~1,3 ms |
| `with_air(scen, temp_c, altitude_m)` | en cada fotograma de un deslizador de temperatura o de altitud (copia el ensayo con otra ρ, sin `compute`) | ~20 µs |
| `max_braking_g(scen, v_kmh)` | al soltar el deslizador | ~0,06 ms |
| `hold_report(p)` | informe completo del animal quieto encima | ~1-2 ms (~2,5 ms en defensa: un `compute` más) |
| `impact(p)` | al soltar el deslizador o unas pocas veces por segundo | ~2-5 ms; con garras reforjadas, ~5-8 ms (el recorrido de la punta de `claw_load`); en defensa, ~1 ms más |
| `defense_force(claw, sex)` | al elegir el animal (la ficha de la defensa) | µs, sin `compute` |

`p` lleva `claw` y `target` como diccionarios del catálogo (`ClawsV2.apply` se aplica dentro) más los parámetros de
§9.1. Si `setup` devuelve `ok = false` (animal sin datos o zona que no le corresponde), no se llama a `at_speed`,
`detach` ni `curve`: se enseña `reason`. Tiempos sin ventana en el contenedor de la nube.

### 9.3 Campos del resultado

**`setup(p)`** → `scen`: `ok`, `reason` (si no), `claw`, `kind` («ave» o «mamifero»), `species`, `zone`, `posture`,
`anchor` («friccion», «agarre» o «gancho»), `embedded`, `target`, `mass` (kg), `grip` ({value, min, max} en N),
`mu`, `anchorN` ({value, min, max} en N), `rho` (kg/m³), `air` ({tempC, altitudeM, pPa, rho, rhoRatio, speedFactor,
quality, source}), `cp`, `slopeDeg`, `localFactor` (v_local/v), `scratch` (las marcas al
resbalar con su peso: `depthUm`, `residualUm`, `verdict`, `layer`, `layers`, `reachesBody`, `widthUm`, `muEff`),
`windshield` (en el parabrisas: `loadN`, `bendN`, `cracked`; si no, null), `draw` (§9.6) y, para uso interno, `cases`,
`wh`, `wc` (m/s), `ax`, `ay` (m/s²).

**`at_speed(scen, v_kmh)`**: `vKmh`, `airKmh`, `localKmh`, `rho`, `qPa`, `dragN`, `liftN`, `weightN`, `inertiaN`, `lateralN`,
`normalN`, `needN`, `availN`, `marginN`, `holds`, `mode` (§2.4; "" si aguanta), `loadRatio` (necesaria/disponible:
1 = a punto de soltarse), `powerW`, `carDragN`, `dragShare`, y la banda: `needMaxN`, `availMinN`, `needMinN`,
`availMaxN`, `holdsLo` (aguanta con todo en contra), `holdsHi` (aguanta con todo a favor).

**`detach(scen)`**: `kmh`, `minKmh`, `maxKmh` (INF si no se suelta ni a 400 km/h), `mode`, `atRest` (false si ni parado
se sostiene), `beyond` (se suelta por encima de 230 km/h, fuera del deslizador: `SLIDER_MAX_KMH`), `never` (ni a 400). Si no aguanta
parado pero sí más deprisa (§2.5), la ventana: `holdFromKmh` (desde dónde aguanta), `holdToKmh` (hasta dónde; INF si
hasta 400 km/h) y `holdToMode` (por qué se suelta arriba; "" si no se suelta). Sin ventana, `holdFromKmh` y
`holdToKmh` son null. `kmh` y la banda siguen siendo las del despegue desde parado: 0 si parado no aguanta.

**`hold_report(p)`**: `ok`, `setup` (el `scen` sin `cases`), `detach`, `detachRef` (el despegue con el aire de
referencia, 20 °C al nivel del mar, para comparar), `verdict` ({verdict, vsub}), `at` (a `v_kmh`), `brakingG`, `marks`
(= `setup.scratch`), `air`, `airTxt` («1.146 kg/m³ a 35 °C y 0 m: un 4.9 % menos denso que a 20 °C al nivel del mar»)
y `safety`.

**`impact(p)`**: `ok`, `claw`, `kind`, `zone`, `target`, `massKg`, `reducedMassKg`, `vRelKmh`, `vNormalKmh`,
`vTangKmh`, `energyJ` (½·m·v_rel², la del animal respecto al coche), `normalJ` (la normal que se disipa,
½·μ_red·v_n²), `tangJ` (½·m·v_t²), `mu`;

- `marks`: `count` (surcos; 0 si no raya o no resbala), `lengthMm`, `depthUm`, `residualUm`, `verdict`, `layer`,
  `widthUm`, `layers`, `reachesBody`, `scratched`;
- `puncture` (null en el vidrio o sin golpe normal): `depthUm`, `through`, `verdict`, `layer`, `workJ` (por garra),
  `holeUm`, `layers`, `reachesBody`; `embedded` (garras clavadas en plástico);
- `dent` (null en el vidrio): `applies`, `depthMm` (mm: la abolladura), `visible` (≥ 0,1 mm), `bottomsOut`, `peakN`
  (por apoyo), `collapseN`, `patches`, `limbSaturated`, `panelJ`, `recovers` (el plástico recupera);
- `windshield` (solo en el parabrisas): `peakN`, `bendN`, `cracked`, `penetrationRisk`, `penetrationJ`, `energyJ`;
- `stays`, `slideM` (m), `exitKmh`, `contactS`, `hold` ({holds, detachKmh, mode, brakingG} si se queda encima),
  `groundKmh` (velocidad respecto al suelo al salir), `landing` (aterriza en vez de chocar);
- `energy` (§2.10): `totalJ`, `terms` (lista en orden fijo: `garras`, `chapa` o `vidrio`, `animal`, `coche`,
  `rozamiento`, `salida`; cada uno con `id`, `name`, `short`, `j`, `share`, `quality` y `source`) y un campo por término:
  `clawsJ`, `panelJ`, `animalJ`, `carJ`, `frictionJ`, `exitJ`;
- `verdict`, `vsub`, `report` (pares [etiqueta, valor] como `Lab.damage_report`: Golpe, Marcas, Profundidad, Capas,
  Perforación, Abolladura, Parabrisas, Energía, Animal) y `safety`. La fila Energía dice, por ejemplo, «34.8 kJ: chapa
  29 % · animal 5 % · coche 5 % · calor 55 % · al salir 6 %».

Los números visibles de los textos ya salen con `Js`/`Format` (mm con cm entre paréntesis a partir de 10 mm, m a partir
de 1 m, kN a partir de 10 kN y MN a partir de 1 MN, kJ a partir de 1000 J).

**Campos nuevos de la unidad 4d** (aditivos: null cuando no aplican):

- `setup`: `inlay` (id del material), `clawHoldN` ({value, min, max}: lo que aguantan de lado unas garras reforjadas
  clavadas en la chapa; null si no; desde la unidad 4p, el menor de la flexión, el cortante de la garra y la chapa
  alrededor del agujero, con `governs`, `governsMin`, `governsMax`, `perClaw`, `clawN`, `sheetN`, `kind`, `depthMm`,
  `atBase`, `dMm`, `tMm`, `kt`, `fuMPa`, `quality` y `source`: §17), `defense` (con `defense`, lo de `defense_block`; si no, null) y, con garras
  reforjadas en el parabrisas, `windshield.contactCracks`.
- `hold_report`: `defense` (= `setup.defense`); con `defense`, `marks` son los desgarros (`defense.tear`).
- `defense` (quieto encima): `forceN` ({value, min, max} por pie o mano), `per` («pie» o «mano»), `kind` («agarre»,
  «flexores» o «patada»), `pcsaCm2` (con «flexores», la sección de los flexores de la que sale la fuerza; si no,
  null), `perClawN` (la fuerza de cada garra que desgarra), `perClawBand`, `tipAreaMm2`,
  `tipPressureMPa` (nominal), `clawHardnessMPa`, `tipYields` (la punta se aplasta: la presión nominal pasa de la dureza
  de la garra), `tear` (como `scratch`, más `lengthMm`), `stuck`, `stuckIn` («plastico», «chapa» o null), `windshield`
  (en el parabrisas: `loadN`, `bendN`, `cracked`, `contactCracks`; si no, null), `anchor` y `anchorN` (los de ese
  ensayo), `restAnchor` y `restAnchorN` (los de sin asustarse, para comparar), `rakeN` (en un panel liso pintado, lo
  que sujeta de más el arado de las garras hundidas, §12.2: `value`, `min`, `max` en N, que son el `anchorN` de ese
  ensayo; `claws`, las garras que aran; `perClawN`, el arado del surco del desgarro por garra; `restPerClawN`, el del
  surco de reposo; `limitN`, lo que aguanta de lado cada garra reforjada, o null; `limited`, si ese tope manda;
  `quality` y `source`; null si está anclado, clavado o en el vidrio), `verdict`, `vsub`, `quality` y `source`.
- `impact`: `inlay`, `attack` («patada» o «golpe»), `sex` (el casuario; si no, null), `kick` (la patada: `massKg`,
  `sex`, `leapMs`, `leapKmh`, `leapMaxMs`, `leapJ`, `forceBw`, `forceCapN`, `forceCapMinN`, `forceCapMaxN`, `peakN`,
  `capped`, `contactS`, `quality`, `source`), `clawFracture` (la rotura de unas garras reforjadas que cortan el metal:
  `material`, `name`, `behavior` («fragil», «ductil» o «sin_datos»), `normalN`, `mu`, `lateralN`, `loadXmm` (dónde
  empuja la chapa, desde el vértice), `depthMm` (dónde estaba la punta), `forceBasis` («pintura», «indentacion»,
  «perforacion» o «marcas»), `strengthMPa`, `strengthMinMPa`, `strengthMaxMPa`, `strengthKind` («flexion» o
  «fluencia»), `kic`, `limitN`, `limitMinN`, `limitMaxN`, `stressMPa`, `peakXmm`, `breaks`, `bends`, `breaksLo`,
  `breaksHi`, `mode` («intacta», «mella», «parte», «dobla» o «sin_datos»), `brokenMm`, `atBase`, `reason`, `verdict`,
  `vsub`, `quality`, `source`), `defense` (`forceN`, `per`, `kind`, `perClawN`, `perClawBand`, `tipAreaMm2`,
  `tipPressureMPa`, `clawHardnessMPa`, `tipYields`, `stuck`, `stuckIn`, `quality`, `source`) y `dent.capped` (la
  fuerza de la pata del casuario llegó a su tope).

Funciones públicas nuevas: `supports_hold`, `supports_impact`, `impact_zones_for`, `is_kicker`, `sexes_of`, `sex_of`,
`mass_of`, `inlay_of`, `can_cut_body`, `kick_leap_ms`, `kick_force_n`, `defense_force`, `felid_fdp_pcsa_cm2`,
`defense_block`, `defense_txt`, `plough_n`, `rake_n`, `claw_fracture`, `claw_tip`, `claw_load`, `sheet_resistance_n`,
`load_point_mm` y `claws_hold_n`, y la constante `PLOUGH`; en `claw_fracture.gd` (`ClawFracture`): `evaluate`,
`strength`, `behavior`, `is_reforged`, `inlay_entry`, `peak`, `lateral_limit_n`, `broken_length_mm`, `bending_per_n`,
`section_radius`, `base_start_mm` y `verdict_of`, con las tablas `BRITTLE`, `DUCTILE`, `UNKNOWN` y `NOUNS`.

**Campos nuevos de la unidad 4g** (aditivos: sin garras trabadas en el plástico ni aire por detrás, todo da lo mismo que
antes, al bit):

- `impact`: `tear` (null si no hay garras que atraviesen el plástico en un costado; el casuario, que patea, nunca):
  `applies`, `holds` (el animal aguanta lo que pide rajarlo: si no, se le sueltan), `lengthMm` (lo rajado a lo largo del
  panel) con su banda `minMm`-`maxMm`, `timeS`, `energyJ`, `perClawN` (R·t), `forceN` (n·R·t), `claws`, `anchorN`
  ({value, min, max}: lo que aguanta con las garras clavadas), `toughnessKJm2` ({value, min, max}), `thicknessMm`,
  `stopped` (se para respecto al coche antes del final del panel: el coche se lo lleva), `reachesEnd` (lo raja hasta el
  final), `vExitKmh`, `quality` y `source`. Con desgarro, `marks` son las ranuras (`count` garras, `lengthMm` lo rajado,
  `verdict` «RAJA EL PLÁSTICO», de lado a lado y del ancho del agujero), `slideM` y `exitKmh` los del desgarro y
  `contactS` incluye su tiempo.
- `impact.energy`: `punctureJ` (la punción) y `tearJ` (el desgarro); `clawsJ` = `punctureJ` + `tearJ` es el término
  «garras», que con desgarro se llama «Garras (punción y desgarro del plástico)» y es una estimación. La normal que se
  disipa es `punctureJ + panelJ + animalJ`; lo que se queda a lo largo del panel, `frictionJ + tearJ`.
- `impact.report`: la fila Desgarro («raja 800 mm (80.0 cm) con 8 garras: ~113 N cada una (45 kJ/m² × 2.5 mm), 720 J;
  llega al final del panel», o «no: rajarlo pide ~450 N (4 garras × ~113 N) y solo aguanta ~202 N: las garras se le
  sueltan»). El subtítulo del golpe: «las garras atraviesan el termoplástico PPE/PA (Noryl GTX) y lo rajan ~800 mm
  (80.0 cm) a lo largo; …» (con «, hasta que va a la velocidad del coche» si se para) o «…, pero rajarlo pide ~450 N y
  solo aguanta ~202 N; …».
- Datos: `BIRD_AERO.wing[estado]` gana `cl_rev` (el CL con el aire por detrás), `cd_quality`, `cl_rev_quality`, `source` y
  `cl_rev_source`; cada zona de `ZONES` e `IMPACT_ZONES` y cada cuerpo de `BODIES`, `sources` (la fuente y la calidad de
  sus campos: «dibujo» en `height_m`, `length_m` y `draw`); `LIMB_STIFFNESS` (la fuente de la rigidez de la pata, cuyo
  valor sigue en el motor) y `PLASTIC_TEAR` (la tenacidad de cada plástico, por id de carrocería).
- Funciones públicas: `tear_run(m, vt1, room_m, n_claws, t_mm, r_kj_m2, anchor_n)` (el desgarro, puro) y `tear_txt`.
- En los casos (`cases` de `setup`), `clsr` y `klr`: la sustentación con el aire por detrás, que `_eval` y `_margin` usan
  cuando v_x < 0.

**Campos nuevos de la unidad 4m** (aditivos: fuera de la ventanilla, todo da lo mismo que antes; detalle en §15.6):

- `impact.sideWindow` (null fuera de la zona `luna`): `shattered`, `cause` («flexión», «grieta» o null), `fragmentMm`,
  `fragments25`, `bendN`, `pierceN` (null si la punta es más blanda que el vidrio), `shapePierceN`, `peakN` (por apoyo),
  `perClawN`, `hardTip`, `tipHv`, `glassHv`, `compressionMm`, `glassJ`, `temperJ`, `energyJ`, `pane` («front»),
  `paneSource`, `quality` y `source`.
- `impact.leap` de un velocirraptor contra la ventanilla: `window` (true), `sillM` (la cintura) y `hitM` (sus pies en lo
  alto del salto); `side` sigue siendo true (golpea con su carrera).
- `impact.energy`: con la ventanilla, el término `vidrio` se llama «Ventanilla (hasta estallar)» (si aguanta, desde la
  unidad 4o, «Ventanilla (aguanta: lo devuelve)») y el del animal, si estalla, «Animal y lo que hay tras la ventanilla
  (resto)».
- `impact.report`: la fila Ventanilla.

**Campos nuevos de la unidad 4o** (aditivos; lo que cambia de valor y por qué, en §16):

- `impact.marks`: `through` (las marcas atraviesan el panel), `tipUm` (hasta dónde llega la punta desde la cara de fuera,
  con el tope del hueco y de su largo), `belowMm` (lo que asoma por detrás del panel), `bottoms` (llega al fondo del
  hueco) y `clearanceMm` (el hueco de la zona). Si atraviesan el panel, `depthUm` y `residualUm` son el espesor del panel
  con su pintura, `layers` todas sus capas y `reachesBody` true.
- `impact.puncture`: `depthUm` con el mismo tope, `belowMm` y `bottoms`. Los desgarros del animal asustado
  (`defense.tear`) y las ranuras del plástico (4g), los mismos campos.
- `impact.band`: `marksThrough` ({ value, lo, hi }) y `marksBelowMm` ({ value, min, max }); en el capó, `varies` incluye
  «hueco» (en las demás zonas va en `fixed`).
- `at_speed`: `needMinN`, `needMaxN`, `availMinN` y `availMaxN` salen de todos los casos de los dos lados (antes, cada
  extremo de un solo lado); `holdsLo` y `holdsHi` no cambian.
- `impact.energy`: en un panel de plástico, el término `chapa` se llama «Plástico (no se abolla)».
- Constantes: `HOLD_PANEL` (el panel de cada zona en la que se queda encima: las barras y la antena, el techo),
  `PANEL_GAP_TXT`, `CLEARANCE_BAND` (la banda del hueco del capó) y `CLEARANCE_FIXED` (por qué los demás no la tienen).
  Funciones: `panel_um`, `room_um`, `hold_clearance_mm`, `marks_depth_txt`, `through_txt` y `sheet_work_j`;
  `defense_block` acepta el tope de la punta (`room`). En `CarFormat`: `fmt_panel` («0.81 mm») y `fmt_g_max` (la frenada
  máxima, redondeada hacia abajo); `fmt_n` escribe MN desde 1 MN.

### 9.4 Veredictos y textos

Animal quieto encima (`detach_verdict`):

| Situación | Veredicto | Texto (ejemplo) |
|---|---|---|
| Ni parado se sostiene | NI PARADO SE SOSTIENE | «sin nada que agarrar, resbala del panel con el coche quieto» |
| Frenada con el coche casi parado | SALE DESPEDIDO HACIA DELANTE | «con esa frenada, ni a paso de hombre aguanta encima» |
| Viento de cara y alas abiertas, parado | DESPEGA CON EL COCHE PARADO | «con ese viento de cara, las alas abiertas ya la sostienen: vuela» (con viento de cola, 4g: «con ese viento de cola, aunque le llega por detrás, el aire ya la levanta con las alas abiertas»; solo lateral: «con ese viento lateral, …») |
| Curva sin velocidad | RESBALA DE LADO | «con esa curva o ese viento lateral, ni a paso de hombre aguanta encima» |
| No se suelta | NI A 400 km/h SE SUELTA | «bien agarrado, el viento no puede con él (desde ~210 km/h según los datos; con los más favorables no se suelta)» |
| Se suelta por encima de 230 | AGUANTA A 230 km/h | «se soltaría hacia ~341 km/h (desde ~164 km/h según los datos; con los más favorables no se suelta)» (el tigre agazapado en el techo) |
| Alas abiertas | DESPEGA A ~24 km/h | «con las alas abiertas el viento relativo la sostiene: no se suelta, vuela (entre 14 y 35 km/h según los datos)» |
| Mamífero levantado | LO LEVANTA EL AIRE A ~X km/h | «la sustentación le quita el apoyo» |
| Frenada | SALE DESPEDIDO HACIA DELANTE A ~X km/h | «la frenada lo empuja más de lo que aguanta» |
| Panel inclinado | RESBALA CUESTA ABAJO A ~X km/h | «el aire le quita apoyo y el panel inclinado hace el resto» |
| Curva | RESBALA DE LADO A ~X km/h | «la curva o el viento lateral pueden con su agarre» |
| Viento | SE SUELTA A ~X km/h | «el viento puede más que su agarre y sale despedido hacia atrás» |

Si el animal agrieta el parabrisas con su peso, se añade «; y el parabrisas se agrieta bajo su peso (el laminado no
cae)»; si lo agrietan por contacto unas garras reforjadas, «; y sus garras agrietan el parabrisas al apoyarse (el
laminado no cae)». Si ni con los datos más desfavorables se suelta, la banda dice «(ni con los datos más
desfavorables)» (antes salía «desde ~∞ km/h»).

Golpe (`impact_verdict`, por prioridad): ESTALLA LA VENTANILLA / LA VENTANILLA AGUANTA (unidad 4m, §15.5), AGRIETA EL
PARABRISAS / EL PARABRISAS AGUANTA, PERFORA EL PLÁSTICO (en un
costado, con lo que rajan las garras trabadas o por qué se le sueltan: unidad 4g), RAJA LA
CHAPA y PERFORA LA CHAPA (garras reforjadas, unidad 4d), ABOLLA Y RAYA / ABOLLA, RAYA EL METAL (4d), RAYA HASTA EL METAL
(o EL PLÁSTICO), ARAÑA LA PINTURA y APENAS DEJA MARCA. El texto acaba con el destino del animal: «se queda encima», «se
queda encima un instante, pero no aguanta a esa velocidad», «resbala 245 mm (24.5 cm) y cae a ~35 km/h respecto al
asfalto», «resbala 1.6 m y sale volando (a ~79 km/h respecto al suelo)» o «sale despedida (…)»; el casuario, «rebota y
se queda junto al coche» o «rebota y cae a ~17 km/h respecto al asfalto» (con «se desengancha, » delante si la daga
quedó clavada). Con garras reforjadas, el subtítulo acaba con lo que les pasa: «las garras de zafiro se mellan: se les
desprenden ~4.5 mm de la punta», «… se parten por la base» o «… se doblan» (la daga, en singular).

Rotura de las garras (`clawFracture.verdict`): LA GARRA AGUANTA («golpe de frente, sin nada que resbalar: sin carga
lateral, una punta dura no se rompe…» o «~X de lado; la garra de Y se mellaría desde ~Z»), SE MELLA LA PUNTA, SE PARTE
LA GARRA, SE DOBLA LA GARRA y SIN DATOS DE ROTURA.

Defensa (`defense.verdict`, quieto encima): SE QUEDA CLAVADO, DESGARRA EL METAL (garras reforjadas que entran en la chapa
sin rajarla), DESGARRA HASTA EL METAL («…sin cortarlo: la queratina no corta…»), DESGARRA LA PINTURA, APENAS DEJA MARCA
y, en el parabrisas, AGRIETA EL PARABRISAS, RAYA EL VIDRIO o NO RAYA EL VIDRIO. El subtítulo empieza por «cada pie
aprieta con ~101 N» y acaba diciendo el anclaje: «; con las garras clavadas se sujeta con ~202 N», «; enganchado, sujeta
~5569 N en vez de ~2158 N», «; con las garras hundidas en la pintura, para arrastrarlo el viento tiene que hacerlas arar:
~3.0 N más que la fricción de su peso» (con garras reforjadas que cortan la chapa, «en la pintura y la chapa», y «(con
más, sus garras se doblarían)» si manda lo que aguantan de lado), «; sin nada que agarrar, la fricción es la de su
peso: con su peso ya araba la pintura, y asustado no la ara más» o «…: sus garras se romperían antes de arar más hondo».
Si el arado lo sujeta y no se suelta ni a 400 km/h, el texto del despegue es «su peso, el roce y sus garras arando la
pintura pueden con el viento».

Filas nuevas del informe de daños (`report`): Patada («salta a ~17 km/h con los pies por delante · la pata aguanta hasta
~2901 N (5.1 veces su peso)»), Garras (`clawFracture.vsub`) y Defensa (`defense_txt`: «aprieta con ~2784 N por mano
(~9282 MPa en la punta, más de lo que aguanta la garra: la punta se aplasta y reparte) · las garras se clavan en el
plástico»). En la fila Perforación, con garras reforjadas: «se clava X en la chapa, sin atravesarla», «no: se queda en la
pintura» o, con el oro, «no: las garras de oro son más blandas que la chapa y no la cortan: la punta cede, como la
queratina».

Modos que no existen (`{ ok: false, reason }`): el casuario encima del coche (`HOLD_NO_REASON`), el casuario pateando
fuera de `KICK_ZONES` (`KICK_ZONE_REASON`), un animal que no llega a la ventanilla (unidad 4m: `window_reach`, con
`WINDOW_LOW_REASON` o `WINDOW_KICK_REASON`) y un material de garra desconocido («material de garra «x» desconocido»).

Frases con humor que no traicionan la física:

- «Un águila con las alas abiertas sobre un coche a 30 km/h no está agarrada: está volando.»
- «El techo es una pista de despegue: el aire pasa un 20 % más rápido que el coche.»
- «Queratina contra acero: gana la chapa. La pintura, en cambio, pierde.»
- «Al tigre no lo tira el viento, lo tira la frenada.»
- «Un oso de pie en el techo casi duplica la resistencia del coche: no es una baca homologada.»
- «El parabrisas laminado se agrieta con facilidad, pero no cae: el PVB lo sujeta.»

Nota de seguridad vial (`SAFETY_NOTE`), al final de cada ensayo: «Experimento mental. En la carretera, si aparece un
animal: frena en línea recta, sin volantazos, y avisa al 112 si queda un animal herido en la calzada.»

### 9.5 Gráfica en directo

`curve(scen)` da 61 puntos de 0 a 230 km/h (`PackedFloat64Array`): `vKmh`, `need` y `avail` (N) y sus bandas
(`needMin`-`needMax`, `availMin`-`availMax`), más `detach`. Propuesta: eje x en km/h, eje y en N; la fuerza necesaria
(viento, inercia, cuesta) contra la disponible (fricción más anclaje); las bandas sombreadas; una línea vertical en
`detach.kmh` si cae dentro de 0-230 (con su banda `minKmh`-`maxKmh`) y, si no, la etiqueta «se soltaría hacia ~X km/h»;
y el punto de la velocidad actual con `at_speed` en cada fotograma. `loadRatio` sirve de indicador (0 = tranquilo,
1 = a punto de soltarse). La gráfica se recalcula con `setup`, no en cada fotograma; con un deslizador de temperatura
o de altitud, `with_air` y `curve` sobre la copia (sin `compute`) dejan moverla en directo, con `airTxt` como leyenda y
`detachRef` como referencia.

### 9.6 Animación y dibujo 2D

- **Posición:** `scen.draw.x` y `scen.draw.y` (0-1 sobre la silueta lateral del coche: x desde el morro, y desde el
  suelo), con el tamaño del animal en `heightM`, `lengthM` y, en las aves, `spanM` (envergadura) para escalarlo contra
  el coche (~4,5 m).
- **En marcha:** `localKmh` para la velocidad de las líneas de viento; `loadRatio` para que tiemble o se le erice el
  plumaje al acercarse a 1; `liftN` frente a `weightN` para las alas; `mode` para la salida: «despega» (sube y vuela),
  «atras» (resbala o sale despedido hacia atrás), «delante» (sale hacia el capó), «abajo» (resbala por el panel), «lado»
  (sale por el costado).
- **El golpe:** `vRelKmh` y el ángulo para la llegada; `contactS` para la duración del contacto; `dent.depthMm` para la
  abolladura; `marks.count` y `marks.lengthMm` para los surcos (con `marks.layers` para el color del fondo: el metal en
  `CAR_BODIES[...].col`); `windshield.cracked` para la estrella de grietas; `stays`, `slideM`, `groundKmh` y `landing`
  para el final (se queda, resbala, cae o sale volando).
- **La energía:** `energy.terms` como barra apilada (en su orden fijo, con `short` como etiqueta y `share` como ancho);
  el rozamiento puede pintarse como calor en las marcas.
- **La patada del casuario** (`attack` = «patada»): llega saltando con los pies por delante a `kick.leapKmh`; el pie
  toca el panel durante `kick.contactS` (~0,09 s); `dent.depthMm` bajo el pie; un surco (`marks.count` = 1) y el rebote
  a `groundKmh`. `height_m` 1,6 y `length_m` 1,3 para escalarlo.
- **Garras reforjadas:** el color del material (`Data.INLAYS[...].col`) en las garras; una garra mellada, más corta en
  `clawFracture.brokenMm` (partida: sin garra; doblada: la punta torcida); `embedded` para dibujarlas clavadas.
- **Defensa:** las garras hundidas y el cuerpo tenso; `defense.tear` para los desgarros (como `marks`) y
  `defense.stuck` para dibujarlas clavadas.

### 9.6.1 Presentación 3D y calidad móvil (unidades 4h y 4l)

La vista usa `CarScene` como una escena ortográfica de perfil: la carrocería, la carretera y cada animal son mallas 3D. Desde la unidad 4l, los animales son modelos 3D de verdad hechos en código (`app/lab/animals/`), sin descargas:

- **Mallas:** cilindros generalizados (`loft.gd`): unas pocas estaciones con el centro y los cuatro radios de la sección de su anatomía (lomo, vientre y costados, en centímetros), interpoladas con Catmull-Rom, con normales suaves y casquetes que esconden las uniones; las garras, los picos y los dientes son conos curvos de queratina.
- **Esqueleto:** un nodo por hueso con su malla rígida (`rig3d.gd`), no `Skeleton3D`: las poses son articulaciones claras (cadera, rodilla, tobillo, dedos, hombro, codo, cuello, tramos de la cola), cada pieza lleva su material, en cada fotograma solo se giran unos pocos nodos (lo mismo en Forward+, Mobile y Compatibility) y la vista puede girar la raíz entera (tres cuartos en un golpe de costado). Las posturas (de pie, agazapado, el salto, la patada) son giros de los huesos y cinemática inversa de dos huesos para las patas: el mismo animal, con los mismos centímetros.
- **Materiales físicos** (`mats3d.gd`, `tex3d.gd` y los sombreadores `animal_*.gdshader`), con la luz del coche y del taller: plumas en tejado en relieve, pelo con capas en el contorno (el tigre y el oso), escamas y escudos (tarsos, casuario, el velocirraptor de película), piel desnuda, queratina brillante, tarjetas de plumas (remeras, rectrices, el plumaje erizado, los mechones del casuario) que se agitan con el aire (`wind_local_ms` en la pose), ojos con iris, pupila y reflejo, y los patrones de cada especie en mapas de su UV (las rayas del tigre en su sitio, barras, listas y bandas). Las garras reforjadas, con el color y el brillo de su material (`Data.INLAYS`).

La presentación consume únicamente el estado ya calculado; `ZONES`, `PANELS`, `DOOR_DRAW`, `surface_y` y `scen.draw` siguen siendo la geometría de referencia y no se duplican en la vista. El tamaño es el del estado: la caja del cuerpo en su postura de referencia cabe en alto × largo tocando uno de los dos (en los mamíferos, sin la cola; en las aves, con las alas plegadas; en los terópodos, el largo con la cola y el alto a la cadera).

| Elemento | Proporción de dibujo | Fuente | Calidad |
|---|---|---|---|
| Coche sedán | ~4,5 m de largo | `MovingCar.CAR_L`; DrivAer, dato del modelo | dato del estado |
| Velocirraptor reconstruido | 2,07 m de largo; 0,5 m de cadera | Paul (1988), `velociraptor.gd`; `MovingCar.BODIES` | dibujo, reconstrucción |
| Velocirraptor de película | 3,4 m de largo; 0,87 m de cadera | Paul (2016), *Deinonychus*; `MovingCar.BODIES` (4i-B2) | dibujo, ficción marcada |
| Casuario | 1,6 m de alto; 1,3 m de largo | `MovingCar.BODIES`; guía de integración §9.6 | dato del estado |

El preset `movil` baja los segmentos alrededor (×0,55) y a lo largo (×0,5) de cada pieza, las teselas del detalle (64 px en lugar de 128), las capas de pelo (una en lugar de cuatro) y las tarjetas, con la mitad de vértices o menos; además, la vista baja el MSAA y la resolución interna (`scaling_3d_scale = 0,7`) y desactiva las sombras del sol. El modelo (mallas, texturas y la descripción de los materiales) se construye una vez por especie, sexo, variante y calidad y se guarda en la caché de la vista; cambiar de postura o de tamaño solo crea los nodos (o cambia la escala de uno) y en cada fotograma solo se giran o escalan nodos y se pasan el aire, el tiempo y el desvanecido a los materiales. Medido en la galería (escritorio, sin la caché): de 40 a 150 ms la primera vez por especie, de 4 a 11 ms con la caché y de 45 a 90 µs la pose de cada fotograma; de 9 600 a 16 600 vértices en el escritorio y de 4 700 a 7 900 en el teléfono (`test_animal3d.gd`). La galería `demo_animales.tscn` enseña todas las especies, sus posturas y estados, los primeros planos y los detalles; la variante de película es ficción y no modifica la física de la 4i-B2.

### 9.6.2 El coche, el viento y los daños en 3D (unidad 4k)

Sustituye lo que §9.6 decía de las líneas del viento y de las marcas: ya no hay dibujo 2D encima del coche.

**El coche** (`app/lab/car3d/`): una berlina de serie hecha en código desde su silueta (`car_shape.gd`), como el
DrivAer: carrocería y cabina son prismas de perfil con los cantos redondeados (el de la cintura, más vivo, y cada canto
como mucho lo que cabe en su esquina) y los costados teselados en una rejilla de 5 cm (8 cm en el teléfono), para que una
abolladura hunda la malla. Tiene las juntas de las puertas, del capó y del maletero y la tapa del depósito (en el shader
de la pintura, así siguen la abolladura), tiradores, retrovisores con su brazo, pilares A, B y C, marcos de las
ventanillas, pasos de rueda con su guardabarros interior, faldones, frontal con calandra, toma de aire, matrícula en blanco
y antinieblas, limpiaparabrisas, barras del techo y antena (las zonas «barras» y «antena»). Las lunas son de vidrio de
verdad (`car_glass.gdshader`): transparentes y tintadas, con el reflejo de Fresnel, y detrás el interior oscuro
(salpicadero, volante y asientos apenas insinuados); por las dos ventanillas se ve lo de detrás. Las ruedas llevan
neumático con flanco y dibujo, llanta de radios, disco y pinza de freno, y giran con la velocidad; cuando el giro por
fotograma pasa de 0,04 radios se emborronan, y desde 0,3 radios solo se ve un disco sin rasgos que dependan del ángulo
(sin efecto estroboscópico). Faros y pilotos con su lente y su emisión; la luz de freno sube con `accel_g < 0`. Cada
carrocería del catálogo con su aspecto (`car_model.gd`, `STYLES`): acero moderno (metalizada con barniz), clásico
(pintura sólida, cromados, tapacubos y banda blanca), aluminio (metalizada más viva, marcos de aluminio) y la aleta y los
paragolpes del coche de plástico (termoplástico pintado con otro brillo). La cámara es ortográfica con 8° de picado y 14°
de giro hacia el morro (se ven el frontal y la matrícula); `CarScene.project()` es la misma proyección, para lo 2D.
`TOP` (la `surface_y` de la vista), los `draw` de `ZONES`, `PANELS` y `DOOR_DRAW` no se mueven: lo comprueba
`tests/app/test_car3d.gd`.

**El viento** (`car3d/air_flow.gd` y `air_streak.gdshader`): una ilustración a la velocidad local del modelo, no una
simulación del flujo. Partículas por líneas de corriente sobre el coche y a lo largo de su costado, que se separan detrás
en una estela con remolinos. Junto a la chapa van a v·√(1 − Cp) con el Cp de cada zona de `ZONES` (repartido en línea
recta entre los puntos de las zonas; donde no hay zona, la del aire libre) y se alejan de ese valor hacia el del aire
libre en 0,35 m; la forma de las líneas y la estela son dibujo. Las mueve el aire respecto al coche (a cámara lenta); con un
viento de cola más rápido que el coche, van al revés; el lateral las hace derivar hacia quien mira. Más deprisa, más
partículas y estelas más largas; a 0 km/h sin viento, ninguna; con movimiento reducido, ninguna; en el teléfono, 120 en
vez de 320. Las que pasan junto al animal, en rosa. Lo da el estado, sin física nueva:

- `MovingCarState.air_flow()` → `{ alongKmh, crossKmh, airKmh, zones: [{ id, x, y, cp, factor, quality, source }] }`: el
  aire a lo largo (v más el viento de cara; en el golpe, solo v) y de lado (las componentes de `at_speed`), y de cada zona su
  punto `draw` y `MovingCar.local_factor(cp)`, con la calidad y la fuente de su Cp.
- La pose del animal lleva `wind_local_ms` (la velocidad del aire donde está, m/s de verdad: `localKmh` quieto encima; en el
  golpe, la del coche) y `slowmo` (0,1: la cámara lenta de la vista), para que mueva plumas y pelo.

**Los daños** (`car3d/car_damage.gd`, funciones puras, y `car_damage.gdshaderinc`, que leen la pintura, las piezas pegadas
a la chapa y las lunas): en el propio material, no con `Decal`, porque el renderizador Compatibility (el de los equipos sin
Vulkan, al que el proyecto cae con `fallback_to_opengl3`, y el de las capturas) no pinta los Decal; así se ven en los tres
renderizadores, se hunden con la abolladura, enseñan la capa a la que llegan con la luz de la propia chapa y no dependen de
la resolución de una textura.

| Dato del estado | Cómo se dibuja | Escala |
|---|---|---|
| `marks.count`, `lengthMm`, `widthUm` | `count` rayas desde el punto del golpe en la dirección del resbalón, sin pasar del panel dibujado | largo y ancho reales (si no llegan a un píxel, de un píxel y más tenues) |
| `marks.layers`, `reachesBody`, `depthUm` | el color de la capa más honda que cortan (`Data.PAINT_LAYERS`: barniz claro, color, imprimación, anticorrosivo o promotor) o, si llegan a la carrocería, el metal brillante; si `depthUm` pasa de la pintura y la chapa (`target.body.t`), la atraviesan: ranura en el plástico (4g) o tajo en la chapa (4d), con lo de detrás oscuro | |
| `puncture.through`, `holeUm` | un agujero donde entra cada garra, con el borde desgarrado; en la chapa, los pétalos (Wierzbicki 1999); en el plástico, el labio blanqueado | diámetro real |
| `dent.depthMm`, `dent.patches` | un hoyo por apoyo que hunde la malla y deforma el reflejo | profundidad real; el radio, dibujo |
| `windshield.cracked` | una estrella con su telaraña bajo cada apoyo y el centro machacado; el PVB lo sujeta, no cae | el radio, dibujo |
| `defense.tear` (quieto encima, asustado) | los desgarros, de sus patas al borde de atrás del panel | largo y ancho reales |
| `scen.windshield.cracked` (quieto encima) | una estrella pequeña bajo cada pata | dibujo |
| `sideWindow` (unidad 4m, §15) | la ventanilla templada se cuartea en trocitos de `fragmentMm` y caen, salvo los del marco | trozos reales |

**Los velocirraptores (4i-B2):** la vista pasa la variante de `draw_size().variant` («pelicula» o «reconstruccion») a
`Animal3D.build(…, { variant })` y rehace el animal al cambiarla; mientras `AnimalArt` no tenga el dibujo de una variante,
usa el de la otra (`MovingCarView.art_id`, por `MovingCarState.VARIANTS`), que cambia con la variante. A un panel de
arriba llegan con el final de su salto: la parábola de la velocidad con la que llegan respecto al coche (`leap.ux` menos
la del coche y `leap.uz`, de `impact()`) con la gravedad, en sus últimos 2,2 m y sin pasar del despegue desde el asfalto
(`MovingCarView.leap_arc`; el aire le quita menos de 0,1 km/h en el vuelo); contra un costado, con la carrera. Las rajas
del de cine (garras de película, ficción) y los surcos del de verdad salen del informe, como todos: una garra falciforme
por pie, con los pies a 15 cm (dibujo). La pose del animal no mueve su raíz: lo que la pose le sume (el ave que se
inclina con el aire, los saltitos del de cine asustado) se suma a donde lo pone la vista.

Los daños se acumulan en el mismo ensayo (hasta tres golpes anteriores, algo desplazados en su panel) y se borran al
cambiar de animal, coche, modo, zona, postura, material, sexo o miedo. Un golpe de un deslizador que se arrastra sustituye al
último sin acumularse. Nada se crea en cada fotograma: al llegar un golpe se rehacen las listas de los materiales
(`MovingCarView.damage()` da la última); en cada fotograma solo cambian lo que va de la abolladura y del resbalón.

**La lupa:** a su escala real un surco de 0,27 mm o un agujero de 12 mm no pasan de un píxel. Un círculo en la esquina de
arriba del lado contrario al golpe (donde no está el animal; más pequeño en el teléfono, con su rótulo al lado, en el
cielo) enseña de cerca el daño más fino del último golpe, desde que el animal toca el panel (`CarDamage.lupa`: los agujeros de una pata, los surcos de una
pata, una estrella de grietas o, si solo hay abolladuras, la última), mirando de frente a la chapa, con la misma luz y el
mismo material, su aumento y una barra de escala. Una segunda cámara (que no ve el animal ni el viento) en un SubViewport
que comparte el mundo; se renderiza solo cuando cambian los daños o mientras crecen.

**La ventanilla que estalla (unidad 4m, §15).** Era una propuesta de esta unidad a la física y ya la da: la zona del golpe
`luna` (la ventanilla templada) devuelve `impact().sideWindow = { shattered, cause, fragmentMm, pane: «front», … }`, con
`Glazing.tempered_result` y `Glazing.SIDE_WINDOW`, como hace `Physics.compute` en el banco, y la vista la cuartea y la hace
caer. Lo que le falta a la vista para esa zona (el punto del golpe, `IMPACT_ZONES.luna.draw`, y tratarla como un costado),
en §15.6.

**Valores nuevos de la 4k: valor → fuente → tipo**

| Valor | Fuente | Tipo |
|---|---|---|
| Velocidad del aire junto a la chapa: v·√(1 − Cp) de cada zona | `MovingCar.ZONES` (DrivAer, Varney et al. 2020; Mathai et al. 2021) | el de cada zona (secundario o estimación) |
| Vuelta a la velocidad del aire libre en 0,35 m; estela de 1,6 m con remolinos de 0,11 m | sin medición | dibujo |
| Reflejo de las lunas: F0 = 0,04 | Fresnel con el índice del vidrio (1,5): ((1,5 − 1)/(1,5 + 1))² | dato |
| Lunas: dejan pasar el 72 % delante y el 40 % detrás | del orden de lo que se homologa delante (CEPE R43) y de las lunas tintadas de fábrica | dibujo |
| Trozos del templado: 5,6 mm | `Glazing.fragment_size_mm` (Nielsen, Schneider & Kraus 2022), unidad 1f | dato del modelo |
| Radio de la abolladura: el fondo, el del apoyo (`contact_mm`); el borde, 2,6 veces la profundidad (como poco 2,2 veces el apoyo) | sin medición (el mecanismo de Dent es cónico y no fija el radio) | dibujo |
| Garras de una pata: a 2,8 cm (mamíferos), 2 cm (aves), 3 cm (casuario y velocirraptor); patas a 22, 9, 12 y 15 cm (12 cm en un costado) | sin medición | dibujo |
| Lo que se ve del salto del velocirraptor: sus últimos 2,2 m | — | dibujo (la parábola, de `leap` y g) |
| Pétalos de la chapa perforada: 4 | Wierzbicki (1999): la punta abre la chapa en pétalos; cuántos, depende de la punta | dibujo |
| Estrella del parabrisas: de 0,1 a 0,32 m según `peakN`/`bendN` | sin medición | dibujo |
| Neumático 225/45 R17; holgura de las juntas, 4 mm | medidas habituales de una berlina media | dibujo |
| Cámara: 8° de picado y 14° de giro | — | dibujo |

### 9.6.3 Proporciones de los animales 3D (unidad 4l)

Lo que mide el modelo y de dónde sale. Todo es dibujo: el tamaño total lo da el estado (`MovingCar.BODIES`) y el modelo se escala entero; las garras miden lo que el catálogo (`Data.CLAWS`: `reach` y `curve`, como la física); lo demás (grosores, colores, plumas) es dibujo con estas referencias.

| Animal | En el modelo | Fuente | Calidad |
|---|---|---|---|
| Casuario | tarsometatarso de ~31 cm, grueso, con escudos por delante | Saber & Hassanin (2014): ~32,5 cm | secundaria |
| Casuario | tres dedos delante, sin el I: el III, el mayor (19 cm); el IV (15,5) y el II (11,5), con almohadillas que apoyan | Saber & Hassanin (2014) (los dedos y sus falanges); los largos, dibujo | secundaria / dibujo |
| Casuario | daga del dedo II: 11 cm, casi recta (14° de arco) | `Data.CLAWS` «casuario» (110 mm); hasta 12 cm: Grzimek (2003) | catálogo |
| Casuario | tibia y tarso de 9-10 cm de grueso, con piel, tendones y escudos | el hueso solo: diáfisis distal de la tibia de *C. bennetti*, 2,2-2,5 × 1,5-1,75 cm (Miller 1962) | dibujo (estimación) |
| Casuario | plumaje negro y lacio en montículo, púas en las alas; cuello azul desnudo, nuca y carúnculas rojas, casco; la hembra, mayor y más viva | Saber & Hassanin (2014) (remeras sin barbas); Grzimek (2003) | secundaria (rasgos de campo) |
| Tigre | 1,9 m de cabeza y tronco y ~1 m a la cruz; la cola, ~0,95 m más | estado; Mazák (1981); Sunquist & Sunquist (2002) | estado / secundaria |
| Tigre | garras retráctiles de 4 cm (asoman asustado, al golpear o reforjadas); rayas del lomo al vientre, anillos en patas y cola con la punta negra, orejas negras con la mancha blanca | `Data.CLAWS` «tigre»; Mazák (1981) | catálogo / secundaria |
| Oso pardo | 2 m de cabeza y tronco y 1,2 m a la joroba; joroba de músculo, perfil cóncavo, orejas pequeñas y redondas, plantígrado | estado; Pasitschniak-Arts (1993) | estado / secundaria |
| Oso pardo | garras de la mano largas y poco curvas, siempre fuera: 6 cm | `Data.CLAWS` «oso»; 5-10 cm: Pasitschniak-Arts (1993) | catálogo |
| Rapaces | alto y largo del estado; el ala abierta se escala para dar la envergadura del estado (`spanM`) | `MovingCar.BODIES` | estado |
| Rapaces | proporciones del tarso, la cola, el ala plegada y el pico, y los rasgos de cada especie (la nuca dorada del águila, el penacho y la banda de la arpía, la capucha del halcón, los discos faciales, el cuello de plumón del buitre) | Ferguson-Lees & Christie (2001); König & Weick (2008); Xirouchakis & Poulakakis (2008) | dibujo con las proporciones de las guías |
| Rapaces | talones del largo y la curva del catálogo (el pulgar y el II, enteros; el III, ×0,8; el IV, ×0,7) | `Data.CLAWS` | catálogo (el reparto, dibujo) |
| Velocirraptor (reconstrucción) | 2,07 m y 0,5 m a la cadera de pie; fémur 23,8 cm, tibia 25,5 cm y metatarso III 9,9 cm, flexionados | Paul (1988); Norell & Makovicky (1999), IGM 100/986 | secundaria / primaria |
| Velocirraptor (reconstrucción) | cráneo largo y bajo (~27 cm con las plumas) con el hocico cóncavo; plumas de contorno, remeras en el antebrazo y la mano, abanico de rectrices en la cola rígida; los labios tapan los dientes | Norell & Makovicky (1999); Turner et al. (2007); Ostrom (1969) (la cola); Cullen et al. (2023) | secundaria; plumas y colores, dibujo |
| Velocirraptor (reconstrucción) | pie didáctilo: apoya en los dedos III y IV; la hoz del II, levantada, de 9,27 cm y ~150° de arco (160° en *Deinonychus*) | Li et al. (2008); `Data.CLAWS` «velociraptor» (núcleo de 64,8 mm entre 0,699); Manning et al. (2006) | estimación (la de su ficha) |
| Velocirraptor de película | 3,4 m y 0,87 m a la cadera; la hoz de 12 cm | `MovingCar.BODIES`; Paul (2016); Ostrom (1969) | secundaria, solo dibujo |
| Velocirraptor de película | diseño original inspirado en el cine de los 90, sin copiar ninguno: escamas pardo oliva, bandas irregulares, escudos en el espinazo, cabeza cuadrada con la ceja ósea, pupila rasgada, dientes a la vista | diseño | ficción marcada |

### 9.7 Catálogo

- En el modelo 2.0, `catalog.gd` debe aplicar `ClawsV2.apply` a las garras (cambian `force` del águila, la arpía y el
  halcón, las `desc` del águila, la arpía, el halcón y el búho, y se añade `sources2`). En el 1.x, nada.
- `MovingCar` aplica `ClawsV2.apply` por su cuenta: da lo mismo recibir la garra corregida o la del oráculo.

### 9.8 Casos de referencia

`godot/tests/fixtures/spec/coche-en-marcha.json` es una lista de 54 casos `{ id, note, input, expect, source }`: 28 de
la unidad 1k (con la ventana de velocidades), 15 de la 4d (la patada del casuario, las garras reforjadas y su rotura, y
el modo defensa), 1 de la 4g (el tigre que raja la aleta hasta pararse), 6 de la 4i-B2 (los velocirraptores, §14.8) y 4 de
la 4m (la ventanilla templada, §15.8); la 4g amplía además los tres de la aleta de plástico, con el cálculo a mano en la
nota (§13.4).

- `input`: ids del catálogo (`claw`, `target`), `zone`, `kind` («hold»: `hold_report`; «impact»: `impact`),
  `model: "2.0"` y los parámetros de §9.1 (`posture`, `v_kmh`, `crosswind_kmh`, `accel_g`, `temp_c`, `altitude_m`,
  `embedded` en «hold»; `v_kmh`, `animal_kmh`, `angle_deg`, `drop_m`, `car_mass_kg` en «impact»; y, de la 4d, `inlay`,
  `sex` y `defense`).
- `expect`: `ruta → { value, tol }`; la ruta es un camino con puntos dentro del resultado (`detach.kmh`,
  `dent.depthMm`…). `tol` es relativa; sin `tol`, `value` exige igualdad exacta (booleanos, textos, listas y números);
  el infinito va como `{ "$num": "Infinity" }`.
- Los valores son los de la referencia (`MovingCar`); las tolerancias del 2 % dejan margen a una integración que
  redondee distinto, no a otra física. `test_moving_car.gd` los comprueba.

### 9.9 Dependencias con otras unidades

- **Unidad 1f (física de materiales):** `Dent` (abolladura), `Glazing` (parabrisas laminado) y `Recovery` (huella que
  queda) se usan tal cual; el tope de recorrido de la pata es de esta unidad.
- **Unidad 1c (catálogo):** aplicar `ClawsV2` en 2.0 (§9.7). Los vidrios de coche de 1f son objetivos del catálogo 2.0;
  aquí el parabrisas es una zona del coche, no un objetivo.
- **Motor (`Physics.compute`):** fricción, marcas y punción, con `model: "2.0"`. No hay nada del coche en marcha en el
  motor 1.x: no hay oráculo que igualar. La unidad 4d usa además su modo desgarro (`tear`), `Physics.resolve_tool`,
  `Physics.sheet_of`, `Physics.petal_energy` y `Physics.hardness_profile` (también para el arado de las garras en
  defensa, `plough_n`), y de la unidad 1f, `Fracture.evaluate` (grietas de contacto en el vidrio) y
  `Glazing.laminated_result`. La rotura de las garras reforjadas (`claw_fracture.gd`) no
  entra en `Physics.compute`: solo la usa el coche en marcha.

### 9.10 La tarjeta del coche en marcha (unidad 4c): qué añadir

- **Animal:** el casuario aparece en «Se abalanza» (`supports_impact`) y no en «Encima del coche»
  (`supports_hold` = false): si se elige, mostrar `HOLD_NO_REASON` en vez de la gráfica. Sus zonas, las de
  `impact_zones_for(claw)`.
- **Sexo:** un selector «Hembra / Macho» (`sexes_of(claw)`, `SEX_NAMES`) solo para el casuario; `kick.massKg` en la ficha.
- **Material de las garras:** un selector con `Data.INLAYS` («Queratina» para «none»), en los dos modos. Con un material
  duro, `embedded` puede venir de la punción; la ficha puede enseñar `clawHoldN` y, en el golpe, `clawFracture.vsub`.
- **Modo defensa:** un interruptor «Asustado» (`defense`) en los dos modos; la ficha, con `defense.forceN` (por
  `defense.per`), `defense.tipPressureMPa`, `defense.verdict` y `defense.vsub`; en un panel liso, `defense.rakeN` (el
  arado de las garras hundidas, lo que sujeta de más, con su banda: puede ser 0); en el golpe, la fila Defensa del
  informe.
- **La patada:** las filas Patada y Abolladura del informe, `kick.leapKmh` y `kick.forceCapN`; `dent.capped` indica que
  la pata llegó a su fuerza máxima.
- **Sin nada nuevo que calcular en la interfaz:** todo sale de `MovingCar` y de `ClawFracture`; si falta un dato, se
  pide aquí, no se calcula en la tarjeta.

### 9.11 Cinemática, banda del golpe y fuentes legibles (unidad 4j)

- **`impact().kinematics`** (`MovingCar.kinematics(p, leap)`; también sin el golpe, para el dibujo): las cuentas de §2.8
  con las componentes que el golpe no devolvía.
  - `relKmh { x, y, z }`: la velocidad del animal respecto al coche en los ejes del coche (x hacia delante, y hacia el
    costado por el que llega, z hacia arriba); su módulo, `relAbsKmh`, es `vRelKmh`; `normalKmh` y `tangKmh` son
    `vNormalKmh` y `vTangKmh`, y `awayKmh`, lo que se aleja del panel si no choca contra él.
  - El vuelo antes de tocar el panel: `flightS` (cayendo desde `drop_m`, √(2·h/g); saltando desde la carretera, el
    `timeS` del salto de un velocirraptor, sin recalcularlo), `dropM`, `fallKmh` (la velocidad de bajada al llegar) y
    `carFlightM` (v·t, lo que avanza el coche mientras tanto). En un costado y en la patada del casuario no hay vuelo.
  - `arrival { x, z, lateral }`: la dirección de llegada del dibujo (`MovingCarState.arrival()`).
  - `quality` vacía (es una cuenta, no un dato) y `source` en palabras.
- **`impact().band`** (`MovingCar.impact_band`): el mismo golpe con todos los datos que tienen banda a favor del coche
  (`lo`) y en contra (`hi`), como la banda del despegue (`detach`).
  - Se mueven: la fricción de garras y almohadillas (0,3-1); la dureza del barniz, solo en las marcas (de 196 MPa, el del
    banco, a 425, el más duro de Vodnick 2006: la queratina ya no lo raya); la tenacidad del plástico y el anclaje con las
    garras clavadas (el desgarro); la fuerza de defensa de cada garra; la masa, el salto y la fuerza de la pata del
    casuario; el salto y la carrera de los velocirraptores (`leap_block(…, hi = true)`); y, desde la unidad 4o, el hueco
    bajo el capó (de 20 a 100 mm, §16.3).
  - Sin banda (lo dice la fuente): la rigidez y el recorrido de la pata, el hueco bajo el techo, la puerta y la aleta y la
    hoja de vidrio (§16.3).
  - `marksDepthUm`, `marksLengthMm`, `dentMm`, `normalJ`, `tearMm`, `slideM` y `marksBelowMm` (4o) llevan
    `{ value, min, max }`; `through` y `marksThrough` (4o), `{ value, lo, hi }`; `varies` y `fixed`, qué se mueve y qué no.
  - En orden (hay tests): la pintura más dura nunca deja marcas más hondas; con menos fricción resbala y raja más; sin
    banda de la masa ni de la velocidad, la energía contra el panel, la punción y la abolladura no cambian. La patada no
    va en orden en el largo del surco (la pata más débil empuja menos, pero dura más: t = μ_red·v/F), y la banda es el
    mínimo y el máximo de los tres casos.
  - Coste: una llamada más a `Physics.compute` (las marcas con el barniz más duro); asustado, dos; el velocirraptor, la
    punción de su salto más fuerte; el casuario, seis. Medido: de ×1,1 a ×1,3 en las aves y los mamíferos, ×1,9-2 en los
    velocirraptores y ×2,9 en el casuario, en el hilo del estado (el coste por fotograma no cambia).
- **En la tarjeta:** la banda en una frase en el cuadro del veredicto (`MovingCarState.impact_band_text()`); las lecturas
  «Respecto al coche» (las tres componentes), «Vuelo», «Marcas (profundidad)» y, con las garras trabadas en el plástico,
  «Raja» en lugar de «Resbala» (o por qué no la raja); el «¿sabías que…?» del desgarro (R·t por garra); y «Fuentes y
  estimaciones», plegada, con su resumen (`sources_summary()`) y las fuentes campo a campo de la 4g.
- **Fuentes legibles:** ningún texto visible lleva rutas, nombres de código, apartados de documentos internos ni nombres de
  unidades del equipo: autor y año, norma o ficha y, si solo es el modelo, «estimación del modelo: …» con la suposición
  (`tests/lab/test_moving_car_textos.gd` lo comprueba en todos los animales, coches y zonas).
- **Formatos:** en un solo sitio, `core/lab/car_format.gd`; los nombres de siempre (`MovingCar.fmt_long`,
  `MovingCarState.fmt_n`…) delegan en él.

## 10. El casuario (unidad 4d)

### 10.1 Qué se sabe de sus ataques

- **A las personas:** Kofron (1999) reunió 221 ataques en Queensland, 150 de ellos a personas; el 75 % eran de aves que la
  gente alimentaba. Kofron (2003) recoge los casos: atacan pateando o saltando encima («cargó, saltó y le pateó el
  pecho»), con una herida punzante de 12 cm de hondo en el pecho y, de la garra en un salto, otra de 1¼ cm de diámetro
  en el cuello.
- **A los coches:** Naish (2007) cuenta que «patean o picotean puertas y ventanas, y a veces rompen el cristal», y que
  «también patean o persiguen coches», porque asocian a sus ocupantes con comida; Borrell (2008, Smithsonian) lo describe
  en Mission Beach («persiguen coches»; carga a «hasta 30 millas por hora» y salta «más de 3 pies»: divulgación).
- **Nadie ha medido el daño** que deja en un coche: lo estima el modelo, con la física de siempre y la patada de §10.3.
- **Al revés, sí:** los coches son la primera causa de muerte del casuario del sur, el 55 % de las muertes conocidas
  entre 1986 y 2004 (Kofron & Chapman 2006).

### 10.2 Datos

| Dato | Valor | Fuente | Tipo |
|---|---|---|---|
| Masa de la hembra | 58 kg (58-76) | Grzimek (2003): 58 kg; banda alta, Latch (2007): hembras de hasta 76 kg | secundaria |
| Masa del macho | 31,5 kg (29-55) | Grzimek (2003): 29-34 kg (se usa el centro); banda alta, Latch (2007): machos de hasta 55 kg | secundaria; el valor central, estimación |
| Comprobación | 11 adultos de 40-66 kg | Westcott & Reid (2002): 5 pesados y 6 estimados; caen dentro de las bandas (test) | secundaria |
| Carrera | hasta 50 km/h | Healy (2022, Birds of the World, recopilación sin la medición original); Borrell (2008): 30 mph | secundaria |
| Velocidad del pie al saltar | 4,84 m/s = 17,4 km/h (hasta 5,93 m/s = 21,3 km/h) | v = √(4·w·f): trabajo muscular del salto máximo de la gallina de Guinea, w = 45 J/kg de músculo (hasta 67,5, el máximo esperable del músculo esquelético) (Henry et al. 2005), con f = 13,0 % de la masa en los músculos de cada pata, disecados en un avestruz (Hutchinson et al. 2015) | estimación: caso medido más parecido |
| Fuerza máxima de la pata | 5,1 pesos (4,2-6,0): 2,9 kN la hembra, 1,6 kN el macho | patada del secretario medida en una placa de fuerza (Portugal et al. 2016); del orden del salto máximo de un ave, 5,3 pesos (Henry et al. 2005) | estimación: caso medido más parecido |
| Duración del contacto | 15 ± 4,4 ms en el secretario (informativo); en el casuario, t = μ_red·v/F ≈ 93 ms | Portugal et al. (2016); impulso de todo el cuerpo | medida (secretario) y modelo |
| El pie | tres dedos, sin dedo trasero; la garra larga en el segundo | Saber & Hassanin (2014); Naish (2007) | secundaria |
| La daga | 110 mm de alcance, punta de 0,05 mm², semiángulo de 14°, base de Ø 33 mm (0,15 × alcance) | catálogo 1.x (`Data.CLAWS`, «casuario») y `Physics.resolve_tool`; encaja con el espolón «de hasta 12 cm» (Grzimek 2003) y con las heridas de Kofron (2003) | catálogo 1.x, encuadrado por fuentes |
| Queratina de la daga | 32 HV | catálogo 1.x; queratina de garra, 26-33 HV (McKittrick et al. 2012) | secundaria |

Suposiciones escritas: el músculo del casuario rinde como el de esas dos aves (el salto no depende de la masa, como
predijo Hill en 1950), y su pata, relativa a su peso, no aguanta más que la del secretario; sobre una chapa que cede la
fuerza no puede ser mayor que sobre una placa rígida.

### 10.3 El modelo de la patada

- **Solo patea lo que tiene a la altura de las patas:** capó, puerta y aleta (`KICK_ZONES`). En las demás zonas,
  `impact` responde `{ ok: false, reason: KICK_ZONE_REASON }`.
- **La normal es la del salto.** El casuario se para junto al coche y salta con los pies por delante: contra el panel
  llega a 4,84 m/s, con cualquier masa y cualquier carrera. La carrera solo cuenta a lo largo del panel (con el ángulo,
  como en el golpe de §2.8: persiguiendo al coche, la velocidad relativa es la diferencia).
- **La pata no pasa de su fuerza máxima.** La abolladura es la de la unidad 1f (`Dent.strike`) con ese tope (`f_cap`):
  no depende de la velocidad del coche. Lo que no se queda la chapa se lo queda la pata, que se flexiona y rebota
  (término «animal» del balance de energía).
- **La daga:** la punción con golpe, no más honda que la estática con la fuerza de la pata; la queratina no corta el
  acero: raya hasta el metal un solo surco, con la fuerza de la patada, mientras dura el contacto.
- **Después:** el impulso de fricción a lo largo del panel (μ·μ_red·v) lo arrastra a ~17 km/h y rebota: nunca se queda
  encima.

### 10.4 Resultados

Hembra de 58 kg parada junto a la carretera; la abolladura es la misma a cualquier velocidad del coche (6,2 mm en el
acero de horno, 5,8 en el dulce y 5,2 en el aluminio; el macho, 3,2 / 2,9 / 2,6 mm):

| Coche a | Surco de la daga en la puerta | Cae a | Energía | Chapa | Pata («animal») | Empuja al coche | Calor | Al salir |
|---|---|---|---|---|---|---|---|---|
| 0 km/h | ninguno | se queda junto al coche | 679 J | 1,4 % | 95 % | 4 % | — | — |
| 20 km/h | ~30 cm, hasta el metal | ~17 km/h | 1,6 kJ | 0,6 % | 41 % | 1,7 % | 55 % | 1,5 % |
| 50 km/h | toda la puerta (1 m) | ~17 km/h | 6,3 kJ | 0,15 % | 10 % | 0,4 % | 50 % | 39 % |
| 90 km/h | toda la puerta | ~17 km/h | 18,8 kJ | 0,05 % | 3 % | 0,14 % | 33 % | 64 % |

En el capó, lo mismo con un surco de hasta 1,1 m; en la aleta de plástico la daga la atraviesa (96 J). Persiguiendo un
coche a 30 km/h a 40 km/h, la daga resbala a 10 km/h relativos y deja un surco de ~13 cm, con la misma abolladura.

### 10.5 Encima del coche, no

`setup` y `hold_report` responden `{ ok: false, reason: HOLD_NO_REASON }` (`supports_hold(claw) = false`): el casuario
no se agarra; sus pies son de corredor, con tres dedos y sin dedo trasero para abarcar nada, y sus alas son
vestigiales. De pie encima del coche solo lo sujetaría la fricción de los dedos, pero con más de metro y medio de alto
sobre unos pies estrechos mandaría el vuelco, que este modelo no calcula (§7), y ni su aerodinámica ni su equilibrio se
han medido.

## 11. Garras experimentales y su rotura (unidad 4d)

### 11.1 Qué cambia al reforjar las garras

- **El material:** `inlay` (id de `Data.INLAYS`) reforja las garras de cualquier animal: el motor conserva su forma y
  toma la dureza y el módulo del material (`Physics.resolve_tool`). Marcas, punción, abolladura y vidrio salen del motor
  de siempre.
- **¿Corta la chapa?** El criterio de siempre del motor, r = HV_garra/HV_chapa ≥ 0,8 (`can_cut_body`): todos los
  materiales duros cortan el acero (101 y 92 HV) y el aluminio (71 HV); el oro (30 HV), no: cede por la punta como la
  queratina, no se evalúa su rotura y el informe lo dice.
- **Clavadas:** si el golpe perfora la chapa, las garras quedan clavadas y, quieto encima, el anclaje pasa a ser el
  agarre o el gancho, como con las garras clavadas en el plástico. Pero no sujetan más de lo que aguantan de lado
  (`claws_hold_n`): el tirón las empuja en el borde del agujero. El valor y la banda favorable, con la punta a `embed_mm`
  (por defecto, clavadas hasta la base: la chapa las empuja en la base y casi no las flexa); la banda desfavorable, con
  la punta recién asomada por detrás de la chapa y la resistencia mínima. Desde la unidad 4p manda el menor de la flexión,
  el cortante de la garra y la chapa que se aplasta alrededor del agujero (§17).
- **El vidrio:** unas garras al menos tan duras como el vidrio lo rayan y lo agrietan por contacto (el modelo de la
  unidad 1f, `Fracture.evaluate`, con `Glazing.laminated_result`), quietas encima con su peso y en el golpe con la
  fuerza de pico de cada garra. La queratina, nunca.

### 11.2 Por qué y dónde se rompe una garra dura

- **De frente no se rompe.** Una punta más dura que el metal en el que se clava está en compresión triaxial y el metal
  cede antes: el cono de diamante del Rockwell C (120°, radio de 0,2 mm) aguanta 1471 N contra acero templado en cada
  ensayo (ISO 6508-2), y la bola de metal duro del Brinell, 29,42 kN (ISO 6506-1).
- **La rompe la carga lateral:** la fricción μ·F mientras resbala por la chapa (con el coche parado y una patada de
  frente, no hay).
- **La garra, una viga en voladizo** con esa carga a x0 del vértice: σ(x) = 4·F·(x − x0)/(π·r(x)³) en las secciones más
  allá de la carga, con r(x) la punta esfero-cónica del motor hasta el radio de la base (0,15 × alcance). Con x0 = 0 es
  el mellado de la unidad 1f (`Fracture.tip_chip_load`; un test lo comprueba).
- **Dónde empuja la chapa** (`load_point_mm`): en el centro de la parte de la garra que está dentro del metal mientras
  lo indenta y, cuando ya lo ha perforado, en el borde del agujero (el plano medio de la chapa). Con la punta hundida
  hasta la base, el borde del agujero la empuja en la base y casi no la flexa.
- **Con qué fuerza, en qué instante** (`claw_load`): se recorre el camino de la punta hasta la profundidad final de la
  punción. En cada punto la chapa opone la resistencia del motor (dureza de la capa por π·a² mientras indenta; la
  derivada de la energía de los pétalos de Wierzbicki al perforar), rehecha con su API pública: su trabajo hasta la
  profundidad final es el de la punción del motor, con su mismo integrador (test). Cuenta el instante que más flexa la
  garra; en todos los casos calculados es el de la punta saliendo por detrás de la chapa (h = 0,81 mm, carga a 0,35 mm
  del vértice). También cuenta el deslizamiento: la fuerza de las marcas a su profundidad.
- **Frágiles:** se rompen donde σ llega a su resistencia a flexión medida: se mella la punta o, si llega a la base, se
  parte. Se da por perdido todo el tramo que no aguanta esa carga (cota alta; si se desprendiera a trozos, con la carga
  cada vez en el nuevo extremo, en un cono bastaría con ~0,4 veces esa longitud).
- **Dúctiles** (acero, titanio): no estallan; se doblan cuando σ llega a la tensión de flujo, H/2,8 (Tabor 1951).
- **Sin resistencia medida** (hematites): no se predice, y se dice.

### 11.3 Materiales

| Material | Dureza (catálogo) | Resistencia | K_IC (MPa·√m) | Fuente | Tipo |
|---|---|---|---|---|---|
| Carburo de tungsteno | 2000 HV | 3068 MPa a flexión (hasta 4000) | 8,36 | General Carbide (2018), GC-005: 445 000 psi de rotura transversal (ASTM B406 / ISO 3327); banda alta, Sandvik H6F; tenacidad, Wachowicz et al. (2023) | secundaria |
| Diamante | 10 000 HV | 2790 MPa (1740-3840) | 3,4 | Balmer et al. (2009): placas de diamante natural IIa en voladizo, 2790 ± 1050 MPa; Field (1992); Field & Freeman (1981) | secundaria |
| Zafiro | 2000 HV | 760 MPa perpendicular al eje c (1035 paralelo) | 2,4 | Saint-Gobain Crystals, Sapphire Products; Iwasa et al. (1981) | secundaria |
| Moissanita | 2800 HV | 380 MPa (149-380) | 1,8 | caso medido más parecido: SiC sinterizado Hexoloy SA (380 MPa, K_IC 4,6); banda baja con la tenacidad del monocristal (Qian et al. 2005) y Griffith: 380 × 1,8/4,6 | estimación |
| Circonita | 1300 HV | 300 MPa (150-300) | 1,9 | caso medido más parecido: circonia cúbica policristalina (Adams et al. 1997: 300 prensada en caliente, 150 sinterizada); tenacidad del monocristal, Pajares et al. (1988) | estimación |
| Cuarzo | 1100 HV | 52,4 MPa | 1,0 | caso medido más parecido: sílice fundida con la superficie desgastada (Corning HPFS 7980); tenacidad, Iwasa et al. (1981) | estimación |
| Strass y cristal Swarovski | 550 y 600 HV | 45 MPa | 0,75 | caso medido más parecido: vidrio recocido (EN 572-1, la hoja del motor) | estimación |
| Acero | 200 HV | fluye a 700 MPa | — | Tabor (1951): H/2,8 con la dureza del catálogo | secundaria |
| Titanio | 150 HV | fluye a 525 MPa | — | Tabor (1951) | secundaria |
| Oro | 30 HV | más blando que la chapa: no la corta | — | criterio del motor (r < 0,8) | — |
| Hematites | 1000 HV | sin medición publicada | — | pregunta abierta: no se predice | — |

### 11.4 Resultados

Golpes con las garras reforjadas (coche moderno; «raja»: el surco atraviesa la chapa al resbalar):

| Material | Tigre contra la puerta (coche a 50, cruza a 40) | Águila que se posa en el techo (90/60, 0,2 m) | Oso de frente contra el capó (50/30) | Casuario contra la puerta (coche a 50) |
|---|---|---|---|---|
| Carburo de tungsteno | raja; se mellan ~1,8 mm (aguantan ~195 N de lado) | perfora; ~2,0 mm (~142 N) | perfora; aguantan (1399 N contra 1292) | raja 1 m; ~2,1 mm |
| Diamante | raja; ~1,9 mm (~177 N) | perfora; ~2,1 mm (~129 N) | perfora; ~0,9 mm | raja; ~2,2 mm |
| Zafiro | raja; ~4,5 mm (~48 N) | perfora; ~4,8 mm (~35 N) | perfora; ~3,3 mm | raja; ~5,1 mm |
| Moissanita | raja; ~6,7 mm | perfora; ~7,1 mm | perfora; ~5,1 mm | raja; ~7,6 mm |
| Circonita | raja; ~7,6 mm | perfora; ~8,1 mm | perfora; ~5,9 mm | raja; ~8,7 mm |
| Cuarzo | raja; se parten por la base | perfora; se parten | perfora; se parten | raja; ~22 mm |
| Strass y Swarovski | raja; se parten | perfora; se parten | perfora; se parten | raja; ~24 mm |
| Acero | raja; se doblan ~4,7 mm | perfora; ~5,1 mm | perfora; ~3,5 mm | raja; ~5,4 mm |
| Titanio | perfora; se doblan ~7,0 mm | perfora; ~7,0 mm | perfora; ~5,7 mm | raja; ~7,7 mm |
| Hematites | raja; sin datos de rotura | perfora; sin datos | perfora; sin datos | raja; sin datos |
| Oro | no corta la chapa | no la corta | no la corta | no la corta |

En todos, la fuerza que decide es la de la chapa cuando la punta sale por detrás: ~390 N por garra en el tigre, ~350 N
en el águila, ~1,3 kN en el oso (su punta, más roma, indenta con más fuerza antes de romperla) y ~330 N en la daga del
casuario. Con el coche parado, la daga de diamante del casuario atraviesa entera la puerta (11 cm) y aguanta: de frente
no hay carga lateral. El águila con talones de carburo de tungsteno clavados en el techo no se suelta ni a 400 km/h
(desde ~200 km/h con los datos más desfavorables); con talones de circonita o moissanita recién asomados, la banda
desfavorable baja a ~135 km/h; de cuarzo, a ~102, y de vidrio, a ~99 km/h (sin clavarlos, 79-296 km/h).

### 11.5 La dureza y el módulo

«Con la misma forma y la misma fuerza, una garra más dura nunca raya menos hondo» se cumple si el módulo es el mismo
(test). Con distinto módulo, el más rígido plastifica antes el contacto (Hertz): con poca fuerza, el cuarzo (1100 HV,
95 GPa) raya algo menos que la hematites (1000 HV, 200 GPa). El test lo comprueba también con las parejas del catálogo
que son a la vez más duras y más rígidas.

### 11.6 Qué no predice

- **El efecto de escala:** una punta de décimas de milímetro aguanta más que la probeta de flexión (Weibull); el modelo
  la rompe antes de lo que se rompería (del lado seguro).
- **La forma real:** la curvatura y la sección aplanada de una garra, y la compresión axial, que alivia la tracción.
- **Lo que pasa después:** no sigue al muñón tras la primera rotura, ni la fatiga, ni cómo se embota la punta; la carga
  es la de cada instante del camino (cuasiestática), sin el golpe.
- **La hematites:** sin resistencia a flexión medida.
- **La resistencia de lo que agarra:** barras, retrovisor o limpiaparabrisas no tienen límite propio en el modelo.

## 12. Modo defensa (unidad 4d)

La petición de Eric: «Las garras naturales de los animales, aunque a veces no lleguen a clavarse del todo, hay que
medir también la fuerza teórica en newtons aplicada por cada animal asustado y en modo defensa; se puede quedar clavado,
o dejar desgarros considerables en la carrocería y el vidrio, al intentar mantenerse con el coche en marcha.»

Con `defense: true` (en `setup`, `hold_report` e `impact`), el animal asustado aprieta con toda su fuerza.

### 12.1 La fuerza de defensa

| Animal | Por pie o mano | En cada garra | Presión nominal en la punta | Fuente | Tipo |
|---|---|---|---|---|---|
| Águila real | 101 N (65-299) | 101 N (la pinza) | ~2,5 GPa | agarre máximo medido in vivo y su escalado con la masa (Sustaita & Hertel 2010; `claws_v2.gd`, §8) | estimación |
| Águila arpía | 179 N (104-529) | 179 N | ~3,0 GPa | ídem | estimación |
| Halcón peregrino | 15,8 N (12,1-46,9) | 15,8 N | ~0,8 GPa | ídem (medido en hembras de 774 g) | secundaria |
| Búho | 45 N (41,5-123) | 45 N | ~1,5 GPa | ídem | estimación |
| Lechuza | 8 N (7,3-22,7) | 8 N | ~0,5 GPa | ídem | estimación |
| Buitre leonado | 60 N (20-159) | 60 N | ~0,2 GPa | ídem | estimación |
| Tigre (220 kg) | 2,8 kN (1,9-2,8) | 557 N (entre los cinco dedos) | ~9,3 GPa | la sección fisiológica del flexor profundo de los dedos de los félidos con uñas (Martens et al. 2023, recta RMA de su tabla 2, con dos tigres de 93 y 143 kg) por la tensión específica del músculo, 22,5 N/cm² (15,4 en uno lento) (Powell et al. 1984) | estimación: caso medido más parecido |
| Oso pardo (300 kg) | 3,7 kN (2,5-3,7) | 735 N | ~1,5 GPa | la misma recta de los félidos a su masa, por la misma tensión específica | estimación: caso medido más parecido |
| Casuario | 2,9 kN (la hembra; 1,6 el macho) | toda en la daga | — | su patada (§10.2) | estimación |

- **Aves:** el agarre medido es la pinza entre el dedo trasero y los delanteros: cada talón aprieta con él contra el
  del lado contrario. Es el mismo del anclaje de §2.3: agarrada a algo, una rapaz ya apretaba con su máximo medido.
- **Tigre y oso:** la fuerza teórica de los músculos que cierran las garras de una mano,
  PCSA = (10^(−1,34 + 1,34·log10(M^(1/3))))² cm² con la masa M en gramos: 124 cm² en el tigre de 220 kg (1,3 veces su
  peso por mano) y 163 cm² en el oso de 300 kg (1,25 veces). Es la fuerza del tendón: en la punta de la garra llega
  menos, según la palanca de la última falange, que no está medida (cota alta). Suposiciones escritas: toda la sección
  tira a la vez; el tigre del catálogo, 220 kg, está algo por encima de la recta (llega hasta el león de 176 kg); un
  oso, que excava y trepa con las garras, tiene los flexores de los dedos al menos como los de un félido de su masa (no
  hay disecciones publicadas del antebrazo de un oso con su sección fisiológica).
- **Presión nominal:** la fuerza de una garra entre el área de su punta del catálogo. La queratina aguanta ~0,3 GPa: por
  encima, la punta se aplasta y reparte la carga (el motor nunca da más presión que la dureza de quien cede).

### 12.2 Qué cambia en marcha

- **Donde hay algo que agarrar** (barras, retrovisor, limpiaparabrisas, antena, borde de la ventanilla): las aves ya
  apretaban con su máximo medido, así que el anclaje no cambia; el tigre y el oso enganchados tiran con la fuerza de sus
  flexores (nunca menos que el medio peso por mano del reposo): en las barras, el anclaje del tigre pasa de ~2,2 a
  ~5,6 kN y el del oso de ~2,9 a ~7,3 kN. En el borde de la ventanilla manda el borde de chapa, que se dobla antes
  (`edge_hold_n`): no cambia.
- **En la chapa lisa** (capó, techo, maletero): las garras desgarran con el motor en modo desgarro (la garra curva tira
  como un gancho, `Physics.tear_leverage` = 1 + 1,3 × curvatura), con la fuerza de cada garra (nunca menos que su parte
  del peso) a lo largo del panel: profundidad, anchura, capas y longitud. La queratina no corta el acero ni el aluminio:
  el desgarro se para en el metal. **La fricción sigue siendo la de su peso** (sin nada de lo que tirar, la fuerza normal
  es su peso), **pero las garras hundidas aran** (`rake_n`, en `defense.rakeN`, y es el anclaje del panel liso):
  - Para arrastrarlo hacia atrás, las garras que tiran hacia atrás (la mitad: el dedo delantero de cada pie de un ave,
    que aprieta contra el trasero; las de las manos de un mamífero) tienen que abrir surco nuevo por delante; las otras
    resbalan por el suyo. Arar pide la dureza por la sección del surco, F = H·A (el término de arado de Bowden & Tabor
    1950; el motor usa el mismo arado, docs/FISICA.md §11), con la sección de un surco en V, anchura × profundidad / 2
    (cota baja para una punta redondeada), y la dureza de cada capa del motor: la pintura (20 HV, 196 MPa) y, si unas
    garras reforjadas la cortan, la chapa. La anchura y la profundidad son las del desgarro del motor.
  - En reposo, todas las garras ya araban su surco de reposo, y eso va en la fricción μ·N del motor. El anclaje es la
    diferencia, garras que tiran × arado del desgarro − garras × arado de reposo, nunca negativa (asustado puede hacer lo
    mismo que en reposo). Cada garra no ara con más fuerza que la de su defensa ni, si es reforjada, con más de la que
    aguanta de lado con la carga en el surco (`ClawFracture`, §11.2).
  - Banda: la baja es 0 (la garra se sale del surco o la pintura se desconcha delante de ella, y solo queda la fricción
    del peso); la alta, con la pintura más dura medida por nanoindentación (425 MPa, Vodnick 2006).
  - Quien con su peso ya araba la pintura hasta el metal (águila real, arpía, tigre, oso) no gana nada: asustado no la
    ara más hondo, y se suelta igual. El búho, que en reposo ya la araba 92 µm, tampoco. La lechuza, que apenas la
    arañaba (14 µm), gana mucho: sus dos garras que tiran aran ~1,7 N cada una, frente a ~0,11 N de cada una de las
    cuatro en reposo; son ~3,0 N más (0-6,5), más que la fricción de su peso (~2,8 N). El halcón gana ~0,4 N y el
    buitre ~2,3 N.
  - Unas garras reforjadas que cortan la chapa sin rajarla aran también el metal (990 MPa en el acero de horno): el búho
    con garras de acero gana ~33 N y el halcón ~8,4 N (lo que aguantan sus garras de lado antes de doblarse). Unas garras
    de vidrio se romperían antes de arar: no ganan nada.
- **Se queda clavado** si el desgarro entra en el plástico (la aleta o un panel de plástico) o si unas garras reforjadas
  rajan la chapa: entonces sujeta como unas garras clavadas (el agarre del ave o las manos del mamífero con su fuerza de
  defensa) y se suelta más tarde. Unas garras reforjadas clavadas no sujetan más de lo que aguantan de lado (§11.1).
- **El vidrio:** la queratina no raya el vidrio (r < 0,8) ni lo agrieta por contacto (una punta más blanda se aplasta
  antes: `Fracture`, y la invariante de la unidad 4a); sin nada que agarrar, el parabrisas solo nota su peso, que sí
  puede agrietarlo por flexión (el oso: ~637 N por pata contra ~517 N). Unas garras reforjadas al menos tan duras como el
  vidrio lo rayan y lo agrietan por contacto.
- **En el golpe:** las marcas son los desgarros con la fuerza de defensa, y unas garras que se clavan en el plástico
  quedan clavadas; la fricción y el balance de energía son los mismos: como con las garras clavadas, el anclaje (clavado
  o arando la pintura) cuenta después, en lo que aguanta encima (`hold`). El casuario ya patea con toda su fuerza: su
  defensa es la patada y no cambia nada más.

### 12.3 Resultados

Quieto encima a 90 km/h (coche moderno; el capó de plástico, el del objetivo `cocheplastico`), marca en reposo → en
defensa y velocidad a la que se suelta en defensa, con su banda (en el techo, el arado de más de las garras hundidas,
`rakeN`):

| Animal | Techo | Capó de plástico | Barras de techo | Parabrisas |
|---|---|---|---|---|
| Águila real | 110 → 110 µm, hasta el metal; arado de más 0; 196 km/h, igual | 472 µm → lo raja (2,6 mm) y se clava; de 230 a ∞ (221-∞) | hasta el metal; ∞, igual | no lo raya |
| Águila arpía | igual; arado de más 0; 216 km/h | 708 µm → lo raja y se clava; de 254 a ∞ | ∞, igual | no lo raya |
| Halcón peregrino | 58 → 110 µm; arado de más ~0,4 N (0-0,9); de 150 a 153 km/h (61-237) | 58 µm → 1,1 mm, se clava; de 176 a 342 (164-∞) | 327 km/h, igual | no lo raya |
| Búho | 92 → 110 µm; arado de más 0; 168 km/h, igual | 92 µm → 1,7 mm, se clava; de 198 a ∞ | ∞, igual | no lo raya |
| Lechuza | 14 → 110 µm (del barniz al metal); arado de más ~3,0 N (0-6,5); de 115 a 167 km/h (51-333) | 14 µm → 754 µm, se clava; de 137 a 330 (172-∞) | 329 km/h, igual | no lo raya |
| Buitre leonado | 57 → 110 µm; arado de más ~2,3 N (0-4,9); de 193 a 197 km/h (86-330) | 57 µm → 567 µm, se clava; de 229 a 370 (147-∞) | 350 km/h, igual | no lo raya |
| Tigre | hasta el metal; arado de más 0; 341 km/h, igual | lo raja y se clava; de 380 a ∞ (ni con los datos más desfavorables) | anclaje de 2,2 a 5,6 kN; ∞ | no lo raya |
| Oso pardo | hasta el metal; arado de más 0; 319 km/h, igual | lo raja y se clava; de 373 a ∞ | anclaje de 2,9 a 7,3 kN; ∞ | no lo raya; lo agrieta su peso |

### 12.4 Qué no predice

- **La fuerza en la punta de las garras del tigre y del oso:** la palanca de la última falange no está medida: la de la
  tabla es la del tendón (cota alta).
- **Lo que aguanta lo que agarran:** barras, retrovisor, limpiaparabrisas o antena no tienen límite propio en el modelo;
  el anclaje es el del animal.
- **El arado de las garras en la pintura:** nadie ha medido una garra arando la pintura de un coche. El arado es el de
  Bowden & Tabor con la dureza de la pintura medida por nanoindentación y la sección de un surco en V; no cuenta que el
  barniz se desconche a trozos delante de la garra (por eso la banda baja es 0), ni que el surco de reposo del motor
  (su μ de arado, ≈ 0,9·Dp) pida algo más que el de Bowden & Tabor con la misma forma (el anclaje de más puede ser algo
  menor). En el golpe no frena el deslizamiento, como tampoco lo frenan unas garras clavadas.
- **Las juntas de goma:** no hay datos en el catálogo de cuánto aguanta una junta antes de rasgarse.
- **Lo que aguanta el plástico alrededor de unas garras clavadas, quieto encima** (§7). En un golpe de costado, en cambio,
  las garras trabadas ya rajan la aleta (§13.1).
- **El comportamiento:** un animal asustado no se queda quieto encima; el modelo congela su postura y su esfuerzo.

## 13. Garras trabadas en el plástico, el ala al revés y datos con fuente (unidad 4g)

Tres fallos de la revisión del coche en marcha, con la física de siempre y datos con fuente.

### 13.1 Las garras trabadas rajan la aleta de plástico

**El fallo.** En un golpe de costado (la aleta o la puerta) no hay peso que apriete al animal contra el panel: solo
resbalaba mientras la chapa se hundía. En la aleta de plástico las garras la atraviesan, y lo atravesado no se abolla, así
que el hundimiento era 0 y no quedaba ninguna marca, aunque las garras estuvieran clavadas y el animal siguiera a
lo largo del coche.

**El modelo.** Unas garras que atraviesan el plástico de lado a lado quedan trabadas: para seguir al animal tienen que
rajarlo. Cada garra abre una grieta de todo el espesor t, con la energía por unidad de área de grieta R del plástico, así
que tira de ella F = R·t (R en kJ/m² = N/mm). Las n garras frenan al animal con n·R·t mientras lo rajan (el coche, con el
motor, mantiene su velocidad):

- tras el golpe le queda v_t1 = v_t − μ·(μ_red/m)·v_n a lo largo del panel (el impulso de fricción de siempre, §2.8);
- si el animal aguanta esa fuerza con las garras clavadas (su anclaje A, el mismo que quieto encima con las garras
  clavadas: el agarre medido de un ave o las manos enganchadas de un mamífero, con sus flexores si está asustado), la
  raja hasta pararse respecto al coche, L = m·v_t1²/(2·n·R·t), o hasta el final del panel, por donde sale con
  √(v_t1² − 2·(n·R·t/m)·L_panel); el desgarro se lleva ½·m·(v_t1² − v_salida²) = n·R·t·L (`tear_run`, pura);
- si A < n·R·t, sus dedos ceden antes que el plástico: las garras se le sueltan sin rajarlo (lo de antes).

Después se desengancha y cae, como antes, a la velocidad que lleve respecto al suelo (si se ha parado respecto al coche,
a la del coche). La tenacidad, R = 45 kJ/m² (20-50), es la resiliencia con entalla del mismo plástico: la ficha de SABIC
del NORYL GTX964 (PPE+PA para paneles exteriores de coche) da 45 kJ/m² en Charpy y 50 en Izod a 23 °C, y 20 a −30 °C.
Es la energía por unidad de área de grieta al romper una barra entallada con un péndulo a unos 3 m/s, del orden de la
velocidad de una garra que raja la aleta (de 1,5 a 13 m/s con el coche a 40-90 km/h; más deprisa, como con más frío, un
plástico tenaz se vuelve más frágil, y la banda baja, la de −30 °C, lo cubre). Suposiciones: cada garra abre una sola grieta
de todo el espesor; no se cuenta lo que cuesta doblar los labios para dejar pasar la garra (de 12 a 18 mm de ancho en el
tigre y el oso) ni la pintura (110 µm): es una cota baja de la energía y alta del largo del desgarro.

**Solo en un costado.** En un panel de arriba, el peso ya aprieta las garras contra el plástico y el motor ya las hace
cortarlo al resbalar (la fricción de su peso con el arado de las garras, μ hasta 1): sumarle el desgarro contaría dos
veces lo mismo. El casuario patea y rebota: su daga no queda colgada del plástico (su surco es el de la patada, §10.3).

**Balance de energía.** El desgarro sale del tramo a lo largo del panel y va al término de las garras, que pasa a ser
«Garras (punción y desgarro del plástico)», una estimación: `clawsJ = punctureJ + tearJ`; el rozamiento se queda con lo
del golpe, ½·m·(v_t² − v_t1²), y lo que se lleva al salir baja. Los términos siguen sumando exactamente el total (los dos
tests de 360 y más golpes lo comprueban, con la normal que se disipa como punctureJ + panelJ + animalJ).

**A mano: el tigre que cruza a 40 km/h contra la aleta de un coche a 50** (el caso `tigre-aleta-plastico`).
μ_red = 220·1400/1620 = 190,12 kg; v_n = 11,11 m/s y v_t = 13,89 m/s; con μ = 1, v_t1 = 13,89 − (190,12/220)·11,11 =
4,287 m/s. Cada garra pide 45 × 2,5 = 112,5 N y las 8, F = 900 N, menos que los 2158 N de su anclaje (2 manos × media vez
su peso): a = 900/220 = 4,091 m/s². Para pararse necesitaría 4,287²/(2·4,091) = 2,25 m, más que los 0,8 m de la aleta:
la raja entera (720 J) y sale por el final con √(4,287² − 2·4,091·0,8) = 3,44 m/s (12,4 km/h) en 0,207 s; cae a
13,89 − 3,44 = 10,45 m/s = 37,6 km/h respecto al asfalto (antes, sin desgarro, a 34,6). Con el coche a 40 km/h
(`tigre-aleta-plastico-se-para`): v_t1 = 1,509 m/s y se para a los 1,509²/8,182 = 0,278 m, en 0,369 s, con 250 J; el
coche se lo lleva y cae a 40 km/h.

**Resultados** (aleta de plástico; el animal cruza a 40 km/h con el coche a 50):

| Animal | Rajarla pide | Aguanta (banda) | Raja | Cae a (antes → ahora) |
|---|---|---|---|---|
| Tigre | 900 N (8 × 112,5) | 2158 N (1079-4315) | la aleta entera, 80 cm (720 J) | 34,6 → 37,6 km/h |
| Oso pardo | 1125 N (10 × 112,5) | 2942 N (1471-5884) | la aleta entera, 80 cm (900 J) | 32,9 → 35,4 km/h |
| Águila real | 450 N (4 × 112,5) | 202 N (78-1195) | nada: se le sueltan (banda: 0-99 mm) | 39,9, igual |
| Águila arpía | 450 N | 357 N (125-2114) | nada (0-183 mm) | 39,7, igual |
| Búho | 450 N | 90 N (50-492) | nada (0-39 mm) | 39,9, igual |
| Buitre leonado | 450 N | 120 N (24-637) | nada (0-542 mm) | 31,3, igual |
| Halcón y lechuza | 450 N | 32 y 16 N | nada, ni con los datos más favorables | igual |

A 90 km/h (cruzando a 50), el tigre y el oso también rajan la aleta entera y las rapaces siguen sin poder (con los datos
más favorables, el águila, la arpía y el buitre la rajarían entera; el búho, 62 cm).

### 13.2 El ala con el aire por detrás

**El fallo.** La sustentación era L = k_L·v², con v² sin signo: con un viento de cola más fuerte que la velocidad del coche
(v_x < 0), el ave de cara a la marcha sustentaba con el aire por detrás como si le viniera de frente, con el CL de 1,6
de un ala que planea.

**Los datos.** Sheldahl & Klimas (1981) midieron en túnel perfiles NACA simétricos de 0 a 180° (Re de 0,36 a 0,7
millones; el ala de una rapaz sobre un coche anda por 0,05-0,4 millones, de la lechuza despacio al águila deprisa). Con el aire entrando por el borde de salida, el perfil
sustenta poco: CL = 0 a 180°, 0,69 a 5° de los 180° y 0,85 a 10° (en valor absoluto; el signo lo da la actitud), y luego
entra en pérdida; como placa, a 135-140°, 0,945 frente a 1,085 a 45°.

**El modelo.** Con v_x < 0 el ala usa `cl_rev`: «sustenta», 0,85 (lo más que da un perfil al revés, en la actitud que más
sube: el viento de cola levanta el borde de salida de las plumas); «frena», 1,0 (una placa en pérdida trabaja igual por los
dos lados); «suave», 0 (el ala plana, como el perfil a 180°; en la actitud con la que sustenta de cara, el aire de cola
hasta la apretaría contra el coche, y eso no se cuenta). El cuerpo, las alas plegadas y los mamíferos sustentan igual por
los dos lados, y la resistencia no cambia. Es un perfil de envergadura infinita: un ala real daría algo menos (cota alta).
Invariante (test): con viento de cola, las alas abiertas nunca sustentan más que con el mismo viento de cara.

**Qué cambia.** Solo los ensayos con viento de cola y las alas abiertas (528 de los 9728 del barrido de §2.5; ninguno más).
El águila con las alas abiertas en el techo y 60 km/h de viento de cola sigue sin aguantar parada, pero aguanta desde
~29 km/h en vez de desde ~36; con 40 km/h de cola, desde ~9 en vez de ~16. Asidos a las barras, la antena, el retrovisor o
el borde de la ventanilla con 60 km/h de cola, el búho y el buitre ya aguantan parados (antes el aire los levantaba), y
las ventanas del barrido pasan de 954 a 810. El texto de «despega con el coche parado» dice ahora de dónde viene el aire
(«con ese viento de cola, aunque le llega por detrás, el aire ya la levanta…»).

### 13.3 Datos con fuente: tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Tenacidad del plástico al rajarlo: 45 kJ/m² (20-50) | SABIC (2024), NORYL GTX964, valores típicos, revisión 20241014: Charpy con entalla 45 kJ/m² a 23 °C y 20 a −30 °C (ISO 179/1eA); Izod 50 y 20 (ISO 180/1A) | estimación: caso medido más parecido (la ficha del mismo plástico) |
| Lo que aguanta el animal con las garras trabadas | su anclaje con las garras clavadas: agarre medido (Sustaita & Hertel 2010, `claws_v2.gd`) o media vez su peso por mano (§2.3); asustado, sus flexores (Martens et al. 2023; Powell et al. 1984) | secundaria (aves) y estimación (mamíferos), ya del modelo |
| CL del ala con el aire por detrás: 0,85 / 1,0 / 0 | Sheldahl & Klimas (1981), tabla 2 (NACA 0012 de 0 a 180°) | estimación: caso medido más parecido (perfil en túnel) |
| Cd del ala que sustenta: 0,2 | perfil más inducida con el CL máximo, sin medición en esta postura | estimación (antes figuraba como secundaria con el CL) |
| Capó: 1,1 m y 10° | Cui et al. (2025): 452 frontales de turismos, capó de 54-123 cm y 11-44° | estimación: caso medido más parecido |
| Techo 1,6 m, parabrisas 0,9 m y 30°, puerta 1,0 m, aleta 0,8 m y el resto de `ZONES` | berlina media como el DrivAer (Ashton et al. 2024: 2,786 m de batalla) | estimación (geometría sin medición panel a panel) |
| Hueco bajo el capó: 80 mm | Fredriksson et al. (2007): 20-100 mm ensayados bajo un capó | estimación: caso medido más parecido |
| Hueco bajo el techo: 100 mm | FMVSS 216: el techo no puede bajar más de 127 mm | estimación: caso normativo más parecido |
| Hueco de la puerta: 150 mm | FMVSS 214: la puerta se mide en sus primeros 152 mm de aplastamiento | estimación: caso normativo más parecido |
| Hueco de la aleta: 60 mm | sin medición: menos que la puerta, por el paso de rueda | estimación sin caso medido (pregunta abierta) |
| Garras que se clavan: tigre 8, oso 10 | huellas: el tigre marca cuatro dedos (McDougal 1999, en Sharma et al. 2003); el oso, cinco (Mattson 2003) | estimación (la anatomía, medida; que se agarre con las manos, suposición) |
| Garras que se clavan: aves 4 | la pinza del agarre medido (Sustaita & Hertel 2010) | estimación |
| Almohadilla del tigre: 100 mm (apoyo de 50 mm) | más de 9,7 cm en los machos (McDougal 1999, en Sharma et al. 2003) | secundaria |
| Almohadilla del oso: 130 mm (apoyo de 65 mm) | 12,5-14,5 cm en las hembras adultas y más de 14,5 en los machos (Mattson 2003) | estimación (cota baja para un oso de 300 kg) |
| Apoyo del pie de las aves: 15-35 mm | la mitad del largo del pie, sin medición | estimación |
| Área frontal, Cd y CL·S del tigre y el oso | cuerpo romo con patas (Hoerner 1965), sin túnel | estimación (ya del modelo, ahora campo a campo) |
| Rigidez de la pata: 10 N/mm | la del motor 1.x; caso medido más parecido, Farley et al. (1993): la de la pata al correr crece como M^0,67 | estimación (cota baja para el tigre y el oso) |
| Alto y largo de los cuerpos; posición de las zonas | — | dibujo |

### 13.4 Casos de referencia que cambian (y por qué)

- `tigre-aleta-plastico`: `energy.clawsJ` pasa de 184,9 a 904,9 J (la punción más los 720 J del desgarro, §13.1: las
  garras trabadas rajan la aleta entera). Se añaden `energy.punctureJ` (184,9 J, igual que antes), `energy.tearJ`, el
  bloque `tear`, las ranuras (`marks`), `exitKmh` (de 15,4 a 12,4 km/h) y `groundKmh` (de 34,6 a 37,6 km/h).
- `tigre-defensa-aleta`: `groundKmh` pasa de 34,6 a 37,6 km/h, por lo mismo (asustado, raja igual).
- `aguila-aleta-plastico-cruza`: nada cambia; se añade que sus talones se le sueltan (450 N contra 202).
- `tigre-aleta-plastico-se-para`: nuevo (el tigre con el coche a 40: raja 28 cm y el coche se lo lleva).
- Ningún caso de la chapa de metal, de los paneles de arriba, del parabrisas, del casuario ni de quieto encima cambia; el
  viento de cola no sale en ningún caso de referencia.

### 13.5 Qué no predice

Lo de §7 («El desgarro de la aleta, en detalle» y «Lo que aguanta el plástico quieto encima»). Del ala al revés: la
actitud real del ave con el aire por detrás (el modelo toma la que más sube), el ala de envergadura finita y las plumas
que se levantan. Con viento lateral, cuando la componente del aire a lo largo del coche pasa por cero, el CL salta del de
cola al de cara: el modelo ya toma el viento lateral como si viniera de cara (§2.1 y §7), y no hay datos de un ala con el
aire de lado.

## 14. Los velocirraptores en el coche en marcha (unidad 4i-B2)

Petición de Eric (fase B del Velociraptor): el velocirraptor en el coche en marcha y, después, «una física algo más similar
a Jurassic Park […], que sus garras en forma falciforme puedan desgarrar algo el chasis». Para no mezclar el cine con los
datos hay **dos velocirraptores**:

- **La reconstrucción** (`velociraptor`, `godot/core/lab/velociraptor.gd`): *Velociraptor mongoliensis*, 19,7 kg. Pincha y
  sujeta; con su queratina no corta el acero de un coche.
- **El de cine** (`velociraptor_pelicula`, `godot/core/lab/velociraptor_film.gd`, `docs/fisica/velociraptor.md` §11): el
  tamaño de *Deinonychus*, en el que se basaron la novela y la película (99,8 kg por su fémur). Lo único de película es
  su garra, marcada con la calidad nueva **`ficcion`** («ficción (película)», `MovingCarState.QUALITY_TEXT`; nunca se
  presenta como dato): es tan dura como la tachuela de acero del banco (200 HV) y raja la chapa.

En la tarjeta es un solo animal, «Velocirraptor», con dos variantes (`MovingCarState.VARIANTS`): «De cine (ficción)» por
defecto y «Reconstrucción (datos)» a un clic (`variants()`, `set_variant()`). Dos experimentos de un clic los comparan en
el mismo salto al capó: «El velocirraptor de cine» y «Y el de verdad, en el mismo salto».

### 14.1 El cuerpo: un tipo nuevo, «teropodo»

No es un «ave» del modelo: sin alas medidas (la superficie de las plumas de sus brazos no está publicada; Pei et al. 2020
no la incluye), no tiene las posturas de alas plegadas o abiertas ni puede «salir volando», y ataca saltando. Tampoco es
un mamífero: sus pies son los de un ave (pie didáctilo, con la garra del dedo II levantada; Li et al. 2008) y agarran como
los de una rapaz (Fowler et al. 2011). Así que `kind = "teropodo"`, con:

- **Una postura**, agazapado (`POSTURES.teropodo`), con la aerodinámica del cuerpo de un ave de su masa: el área frontal
  de Pennycuick et al. (1988), S_b = 0,00813·m^0,666 (0,059 m² con 19,7 kg; 0,174 m² con 99,8 kg), y los factores de
  postura y los Cd de `BIRD_AERO`. Es una extrapolación desde las aves grandes medidas (`THEROPOD_FRONTAL`, estimación).
- **Apoyos:** 4 garras quieto encima (los dedos III y IV de los dos pies; Li et al. 2008) y 2 garras que golpean al saltar,
  las falciformes (`strike_claws`). Radio de apoyo: 30 mm la reconstrucción (las dos primeras falanges del dedo III,
  Norell & Makovicky 1999) y 50 mm el de cine (ese radio escalado con la cadera, 0,87/0,5 m); estimaciones.
- **Agarre:** el de su ficha (`dino.forces.grip`: los gavilanes de Sustaita & Hertel 2010 escalados a su masa; 381,5 N la
  reconstrucción y 1841 N el de cine, con su banda) en las mismas zonas que las rapaces: el limpiaparabrisas, las barras de
  techo y el borde de la ventanilla. El gancho de la garra falciforme en los bordes es ese agarre: Fowler et al. (2011)
  comparan la garra del dedo II con el talón de un gavilán, que sujeta cerrando el pie; no se le suma el gancho de las
  manos de un felino (`HOOK_K`). Asustado aprieta con ese agarre máximo, como las rapaces.
- **Zonas:** las de las aves y los mamíferos, menos la antena y el retrovisor (no cabe un animal de 2 a 3,4 m).
- **Dibujo:** `height_m` (la cadera) y `length_m` (con la cola), con calidad «dibujo», y `variant` («pelicula» o
  «reconstruccion»), que llega a la vista con `MovingCarState.draw_size()`.

Quieto encima, todo lo de las rapaces funciona igual (la ventana de velocidades, la gráfica y su banda, la defensa y las
garras reforjadas). A 90 km/h en el techo la reconstrucción aguanta y se soltaría hacia ~246 km/h (de 100 a 372 según los
datos); en las barras, agarrada con 763 N, no se suelta ni a 400 km/h. El de cine, con su masa, se soltaría del techo hacia
~323 km/h, y su garra de película raja la chapa solo con su peso.

### 14.2 El golpe, saltando

Antes de golpear, corre y salta (`MovingCar.leap_block`, attack «salto»):

- **Carrera:** la pedida, como mucho la central de su ficha (10,8 m/s = 38,88 km/h; Sellers & Manning 2007). La de
  *Deinonychus* no está modelada en las fuentes usadas: el de cine corre como su pariente.
- **Salto:** v = √(4·w·f) = 4,84 m/s, con los mismos w y f que la patada del casuario (`kick_leap_ms`, `MovingCar.KICK`:
  45 J por kg de músculo, Henry et al. 2005; el 13,0 % de la masa en cada pata, Hutchinson et al. 2015). El centro de masas
  sube v²/2g = 1,19 m (1,79 m con 67,5 J/kg, la banda alta), y los pies con él.
- **Altura de los paneles** (`panel_height_m`): el borde delantero del capó de la berlina de base de Cui et al. (2025),
  0,70 m (de 0,67 a 0,91 en los 452 frontales medidos), y su alto, 1,475 m. Cae en la mitad del panel: el capó a
  0,70 + ½ × 1,1 × sen 10° = 0,80 m y el parabrisas a 0,70 + 0,19 + ½ × 0,9 × sen 30° = 1,12 m. Al techo no llega (1,19 m
  < 1,475 m): no está entre sus zonas del golpe y, si se pide, `impact` dice por qué.
- **Vuelo** (`leap_flight`): despega con la carrera en horizontal y el salto en vertical, y el aire lo frena con
  D = ½·ρ·CdA·|u|² en contra de su velocidad (el CdA de su cuerpo agazapado). Se integra con RK4 en pasos de 10 ms y una
  bisección del último, el que cruza la altura del panel de bajada. El aire apenas le quita 0,2-0,4 km/h.
- **De costado** (la puerta y la aleta están a la altura de su cuerpo): golpea con la carrera, sin saltar, como el tigre.

Desde ahí, el golpe es el de siempre (la masa reducida con el coche, la abolladura, las marcas, la punción, el desgarro del
plástico y el balance de energía), con la velocidad del vuelo respecto al coche.

| Experimento (coche a 50 km/h, animal a 39) | Velocidad relativa | Energía | Veredicto |
|---|---|---|---|
| El de cine salta al capó | 64,0 km/h (de bajada a 2,8 m/s) | 15,8 kJ | «SALTA SOBRE EL CAPÓ Y LO RAJA»: raja 1,1 m de chapa y la abolla 43,5 mm |
| La reconstrucción, en el mismo salto | 63,9 km/h | 3,1 kJ | «ABOLLA Y RAYA»: 8,2 mm de abolladura y la pintura rayada hasta el metal (110 µm) |
| El de cine contra la puerta | 63,3 km/h (38,88 de lado) | 15,4 kJ (5,4 contra la puerta) | «SE ABALANZA Y RAJA LA PUERTA», con 106 mm de abolladura |
| Los dos contra la aleta de plástico | 63,3 km/h | 15,4 kJ y 3,0 kJ | la atraviesan los dos y la rajan: en el plástico, hasta la queratina entra |

### 14.3 Las garras: pinchan y sujetan; las de película rajan (ficción)

- **La reconstrucción:** su queratina (32 HV) frente al acero de horno de la chapa (101 HV) da r = 0,32 < 0,8: cede la
  punta y no lo corta; la pintura (20 HV), sí. Es lo que se sabe de la garra: una réplica robótica solo hizo punciones
  redondas de 3-4 cm, nunca un tajo (Manning et al. 2006), y el animal sujetaba a la presa con su peso (Fowler et al.
  2011). El porqué y la moraleja lo dicen.
- **El de cine:** `can_cut_body` mira la dureza de la propia garra cuando no está reforjada: 200 HV frente a 101, r = 1,98,
  así que el motor de siempre la raja al resbalar o la perfora al golpear (las garras que cortan el metal de la unidad 4d,
  el desgarro del plástico de la 4g y la abolladura de la 1f). No hay física nueva. `film_verdict` solo cambia las palabras
  («SALTA SOBRE EL CAPÓ Y LO RAJA», «SE ABALANZA Y RAJA LA PUERTA», «CLAVA LAS GARRAS EN…»; hay un test: sin la marca de
  película, la misma garra da los mismos números) y añade siempre el contraste («ficción: en la película sus garras rajan
  la chapa, pero las de verdad, de queratina, no cortan…»). El informe lleva la fila «Garras de película». En el plástico
  dice que la de verdad también lo atravesaría (pincha), y en el parabrisas, que ni la garra de película raya el vidrio
  (550 HV).

### 14.4 Garras reforjadas: su masa y su afilado

- **Masa** (`claw_mass_block`, con `ClawMass` de la unidad 4e): el cono del motor de cada garra que golpea,
  π·(0,15·L)²·L/3, por la densidad del material menos la de la queratina (1310 kg/m³). Como la velocidad relativa la impone
  el coche, la masa de más va al golpe entero (`massKg`) y suma ½·Δm·v² (`clawMass.extraJ`); el balance sigue sumando
  exactamente el total (test con 768 golpes de los velocirraptores). La reconstrucción con garras de carburo de tungsteno
  (14 930 kg/m³): 18 769 mm³ por garra, 255,6 g más cada una, +511 g en las dos (el 2,6 % del animal); a 64 km/h, +81 J.
  Vale para todos los animales: los golpes de la 4d con garras reforjadas cambian un poco (§14.7).
- **Afilado** (`p.sharpness`, 0-1, el mismo de `Physics.sharpness_of`: solo unas garras reforjadas): la punta de
  `ClawSharpness.sharpen` (R(s) = R0·(0,04 µm/R0)^s) en las marcas, la punción, lo que aguantan clavadas, el vidrio y la
  rotura de la garra (una punta afilada se mella antes: con s = 0,5 la de tungsteno aguanta ~14 mN de lado; los textos de
  `claw_fracture.gd` dan ahora mN en vez de «0.0 N»). Con s = 0, todo igual al bit (test); más afilada, nunca entra menos
  con la misma carga (test). Para la tarjeta: `sharpenable()`, `set_sharpness()` y `sharpness_view()` (el deslizador del
  banco, `DinoLab.sharpness_view`, con la carga de cada garra quieta encima: `MovingCar.sharpness_report`).

### 14.5 Los textos

`GRAMMAR`: «el velocirraptor» («el», «o») para los dos. El porqué del golpe cuenta el salto (de dónde llega y a qué
velocidad) y termina con el contraste: «en la película sus garras rajan la chapa; el Velociraptor de verdad pesaba
~19,7 kg, del tamaño de un pavo, con plumas, y pinchaba y sujetaba a la presa con su peso (Manning 2006; Fowler 2011)».
Los «¿sabías que…?» y las fuentes llevan su calidad: dato, estimación o ficción (la garra de película, con la fuente que
dice qué es de película y qué haría la de verdad). El peso lleva la calidad de su masa (la de su ficha).

### 14.6 Coherencia banco ↔ coche

- **La patada del casuario: sin el tope en el banco.** El coche golpea con el animal entero (679 J con la hembra) y limita
  la fuerza de la pata a 5,1 pesos (`KICK.force_bw`), lo medido en las patadas del secretario contra la serpiente de goma
  de una placa de fuerza (Portugal et al. 2016: 5,1 ± 0,9 pesos en 15 ms). Contra un panel blando la pata entera trabaja
  como un muelle y ese tope manda: casi toda la energía vuelve a la pata. El banco golpea con la masa de los músculos de
  la pata que patea (f·M) una muestra pequeña y dura con una punta: ahí manda la inercia de la masa que golpea, como en
  un martillo (la fuerza de pico crece con la rigidez del contacto: en los sólidos, el banco usa F = v·√(m·k)), y lo que
  limita es la energía. Son dos estimaciones de la misma patada en dos rigideces, y ninguna está medida contra un hueso.
  Si se le pusiera el tope al banco (2,9 kN con 58 kg), la daga de tungsteno ya no atravesaría la cortical del húmero (pide
  ~13,7 kN): se quedaría en el hueso. Queda como pregunta abierta, sin una medición que decida.
- **La masa del casuario: 58 kg en los dos.** El catálogo 2.0 (`ClawsV2.casuario_mass`) toma la hembra del coche en marcha
  (Grzimek 2003; hasta 76 kg, Latch 2007) en lugar de los 60 kg sin fuente de la 1.x, y la patada del banco sale de esa
  masa: m = f·M = 7,55 kg, 88,41 J (banda alta 339,7 J). `data.gd` no cambia. Golden 2.0: `docs/FISICA.md`, «Cambios de
  la 2.0», fila «Coherencia banco ↔ coche».
- **La resistencia del cuarzo: 52,4 MPa en los dos.** El mellado de la unidad 1f (`Fracture.TOOL_STRENGTH`) lee la de la
  rotura de las garras de la 4d (`ClawFracture.BRITTLE`): la sílice fundida con la superficie desgastada, de la ficha
  técnica de Corning (HPFS 7980), en lugar de los 67 MPa de MakeItFrom. Es la del fabricante y la de una superficie que
  roza. No cambia ningún escenario.

### 14.7 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Masa: 19,7 kg (14,1-24,6) · 99,8 kg (44,3-124,8) | el escalado del fémur (Campione et al. 2014; Campione & Evans 2012) y las reconstrucciones volumétricas (Campione & Evans 2020) | estimación (escalado de actuales) |
| Carrera: 10,8 m/s (banda alta 13,7) | Sellers & Manning (2007), modelo de *Velociraptor* de 20 kg; para *Deinonychus*, la de su pariente | estimación |
| Salto: 4,84 m/s (5,93) · sube 1,19 m (1,79) | los w y f de la patada del casuario (Henry et al. 2005; Hutchinson et al. 2015) | estimación (caso medido más parecido) |
| Agarre de un pie: 381,5 N (193-1130) · 1841 N (696-5452) | Sustaita & Hertel (2010), escalado; el pie de un dromeosáurido agarraba como el de un gavilán (Fowler et al. 2011) | estimación |
| Garras que apoyan: 4 · que golpean: 2 | rastros didáctilos (Li et al. 2008) · el golpe de la ficha (una falciforme por pie) | secundaria |
| Radio de apoyo: 30 mm · 50 mm | falanges del dedo III (Norell & Makovicky 1999) · escalado con la cadera | estimación |
| Área frontal: 0,059 m² · 0,174 m² | Pennycuick et al. (1988), extrapolada; postura y Cd de `BIRD_AERO` | estimación |
| Borde del capó: 0,70 m (0,67-0,91) · alto: 1,475 m | Cui et al. (2025), berlina de base y 452 frontales | secundaria |
| Altura de la mitad de cada panel: capó 0,80 m, parabrisas 1,12 m | el borde y el alto de Cui et al. (2025) con el largo y la inclinación de los paneles del modelo | estimación |
| Vuelo: RK4, 10 ms, bisección de 40 pasos | integración numérica (no es un dato) | modelo |
| Masa de las garras reforjadas | el cono del motor (0,15·L) por la densidad (`claw_mass.gd`, unidad 4e) | cota alta (las densidades, fichas técnicas) |
| Garra del de cine: 200 HV, 200 GPa | la tachuela de acero del banco (`Data.INLAYS` «acero») | **ficción** |
| Queratina: 32 HV · acero de la chapa: 101 HV | McKittrick et al. (2012) · `docs/FISICA.md` §14 | secundaria · modelo |
| Masa del casuario en la 2.0: 58 kg | Grzimek (2003); máximo, Latch (2007) | secundaria |
| Resistencia del cuarzo: 52,4 MPa | Corning HPFS 7980, ficha técnica (sílice fundida desgastada) | estimación (caso medido más parecido) |
| Cadera y largo: 0,5 m y 2,07 m · 0,87 m y 3,4 m | Paul (1988, 2016) | dibujo |

### 14.8 Casos de referencia

Nuevos en `godot/tests/fixtures/spec/coche-en-marcha.json`, con el cálculo a mano en la nota:
`velocirraptor-cine-capo`, `velocirraptor-capo`, `velocirraptor-cine-puerta`, `velocirraptor-barras-agarre`,
`velocirraptor-cine-techo` y `velocirraptor-tungsteno-afilado-capo`.

Cambian, por la masa de las garras reforjadas (§14.4), los cuatro golpes de la 4d con garras reforjadas; ningún veredicto:

- `aguila-tungsteno-techo-se-posa`: +55 g en los cuatro talones (13,8 g cada uno, el 1,1 % del águila): la punción pasa de
  5472 a 5516 µm y la energía de las garras de 9,77 a 9,88 J (la del golpe, de 183,4 a 185,4 J).
- `tigre-zafiro-puerta`: +32 g en las ocho garras: la energía del golpe pasa de 34 799,4 a 34 804,5 J (+5,1 J).
- `oso-acero-capo`: +335 g en las diez garras: la abolladura pasa de 34,63 a 34,66 mm (la energía, de 74 074 a 74 157 J).
- `casuario-diamante-puerta-parado`: +69 g en la daga: 680,1 J en vez de 679,3; el tope de la pata, el de su cuerpo.

Los demás casos (de queratina, quieto encima y del parabrisas) no cambian.

### 14.9 Qué no predice

- Si un velocirraptor saltaría a un coche: es un experimento mental. Y lo de película, película.
- El salto real: el modelo lanza el centro de masas y los pies suben con él; ni el ángulo de despegue ni el recogido de
  las patas están medidos.
- La carrera de *Deinonychus* (no modelada en las fuentes usadas) y la superficie de las plumas de los brazos.
- El gancho de la garra en un borde como algo distinto del agarre del pie.
- La masa de las garras reforjadas quieto encima: solo se suma en el golpe (en el peso sería, como mucho, un 2,6 %).

Las fuentes de los dos animales, con sus citas completas, están también en `docs/fisica/velociraptor.md` §12.

## 15. La ventanilla templada en el golpe (unidad 4m)

La petición 28 de Eric: «…añadir efecto aerodinámico de viento, según la velocidad que vaya, y de las punciones arañazos y
desgarros sobre los materiales y vidrios del coche…». El parabrisas ya estaba en el golpe: es laminado, se agrieta en
estrella y la lámina de PVB sujeta los trozos (§2.8). Las ventanillas, de vidrio templado, no: ninguna zona del golpe
llegaba a ellas y en el coche en marcha nunca estallaban, aunque la vista ya sabía dibujarlas estallando (unidad 4k,
§9.6.2) y el banco ya las ensayaba (`Physics.compute` con `Glazing.SIDE_WINDOW`). Esta unidad añade la ventanilla como zona
del golpe, con la misma hoja del banco y la misma fuerza de pico que el parabrisas.

### 15.1 La zona y quién llega

**La zona** (`IMPACT_ZONES.luna`; el id no es «ventanilla», que en `ZONES` es su borde, donde se agarran las rapaces y
engancha el tigre): un costado de vidrio templado (normal de lado, vertical, como la puerta). No se abolla: aguanta entera
o estalla. Mide 0,8 m a lo largo (la ventanilla de la puerta delantera de una berlina media, sin medición publicada:
estimación) y va de la línea de cintura al techo:

- **La cintura**, donde empieza la ventanilla: en una berlina arranca al pie del parabrisas, así que está a la altura del
  borde delantero del capó de la berlina de base de Cui et al. (2025), 0,70 m (de 0,67 a 0,91 en los 452 frontales
  medidos), más lo que sube el capó del modelo, 1,1 m × sen 10° = 0,19 m: **0,891 m** (de 0,86 a 1,10 m). Entre las
  fuentes usadas no hay una medición publicada de la cintura de los turismos: es una estimación con el caso medido más
  parecido, el frontal (`window_sill_m`, `WINDOW_SILL_SOURCE`).
- **Arriba**, el alto de esa berlina, 1,475 m (`ROOF_M`): una cota alta, porque el marco va unos centímetros por debajo.

**Quién llega** (`window_reach`): el apoyo que golpea (`contact_mm` de `BODIES`) tiene que caer en la luna, con el centro
por encima de la cintura; por debajo, lo que carga el golpe es la puerta. Lo más alto a lo que llega cada animal sale de
datos con fuente, nunca de `height_m` ni `length_m` de `BODIES`, que son del dibujo:

| Animal | Cómo llega | Altura del centro de su apoyo | ¿Llega? |
|---|---|---|---|
| Rapaces | volando | cualquiera (también llegan al techo) | sí |
| Velocirraptores (los dos) | saltando: sus pies suben v²/2g con el salto de la 4i-B2 (4,84 m/s; §14.2), y golpea en lo alto del salto, donde ya no sube ni baja, con su carrera | 1,194 m (1,79 con los datos más favorables) | sí |
| Oso pardo | a cuatro patas: su cruz, 90-150 cm (Animal Diversity Web, con datos de Nowak & Paradiso 1983 y Wilson & Ruff 1999); un oso de 300 kg es un macho grande y se toma el centro del intervalo, 1,20 m (estimación) | 1,20 − 0,065 = 1,135 m | sí (con los datos más desfavorables, 0,835 m: no) |
| Tigre | a cuatro patas: su cruz, 80-100 cm en machos y hembras (Hunter 2011 y Mazák 1981, vía la San Diego Zoo Wildlife Alliance); el centro del intervalo, 0,90 m | 0,90 − 0,050 = 0,85 m | **no**: golpea la puerta (con los datos más favorables, 0,95 m, llegaría) |
| Casuario | patea lo que tiene a la altura de las patas (`KICK_ZONES`, §10.3) | — | **no** |

Un tigre a cuatro patas mide a la cruz lo que la cintura de una berlina: contra un costado golpea la puerta. Para golpear la
luna tendría que saltar o erguirse, y su salto no está medido entre las fuentes del modelo (que caiga sobre el techo es
un dato del ensayo, `drop_m`, no un salto calculado). El casuario es una pregunta abierta: con su salto llegaría (sus pies
suben ~1,19 m) y Naish (2007) cuenta que «patea o picotea puertas y ventanas, y a veces rompe el cristal», pero su patada
del modelo es de frente, con los pies a la altura de las patas, y una patada hacia arriba contra una luna no está en él.
A quien no llega, `impact_zones_for` no le ofrece la ventanilla y, si se pide, `impact()` dice por qué
(`WINDOW_LOW_REASON`, `WINDOW_KICK_REASON`), como el techo a los velocirraptores.

### 15.2 El golpe contra la hoja

- **La hoja** es la del banco, `Glazing.SIDE_WINDOW` (unidad 1f, `docs/fisica/pulido-materiales.md` §6.1; sus números viven
  allí): vidrio templado de 4 mm, 120 MPa a flexión (EN 12150-1), ~100 MPa de compresión en las caras (estimación dentro
  de los 80-150 MPa medidos en templados comerciales, Achintha 2020), una ventanilla de ~50 cm (placa redonda de 250 mm de
  radio equivalente: estimación).
- **Al flexar** (`Physics.pane_break`, la placa redonda apoyada de Roark, con el apoyo de radio `contact_mm`): se parte con
  907 N bajo un apoyo de 15 mm (halcón y lechuza), 1056 N con 25 mm (búho), 1121 N con 30 mm (águila, buitre y la
  reconstrucción del velocirraptor), 1183 N con 35 mm (arpía), 1357 N con 50 mm (el de cine) y 1521 N con 65 mm (oso).
- **La fuerza de pico** de cada apoyo es la del parabrisas del coche y la del banco (FISICA.md §15): la masa reducida
  contra la hoja y la pata en serie, F = v_n·√(μ_red/apoyos·k), con k = 1/(apoyos/k_hoja + 1/k_pata),
  k_hoja = 4π·E·t³/(3·a²·(3 + ν)·(1 − ν)) = 122,96 N/mm y k_pata = 10 N/mm (la del motor; estimación con el caso medido
  más parecido, Farley et al. 1993). En un costado golpean dos apoyos y v_n es la componente lateral del animal: la
  velocidad del coche no cambia el golpe contra la luna.
- **Por garra**: F·apoyos/garras (las que golpean: `strike_claws_of`). Si la punta es al menos tan dura como el vidrio
  (550 HV), puede abrir una grieta que atraviesa la capa comprimida (el 21 % del espesor, 0,845 mm): la grieta radial de
  Anstis et al. (1981), con el afilado de la punta, tiene que vencer la tenacidad del vidrio más el cierre de la compresión
  media de la capa (`Glazing.pierce_load`). Con una punta de 15° (águila, arpía, halcón, búho y los velocirraptores) basta
  con ~231 N; con la de 26° del oso, ~345 N; con la de la lechuza, ~210 N, y con la del buitre, ~365 N.
- **El resultado** es `Glazing.tempered_result`: estalla por «flexión» si F llega a la que la parte, por «grieta» si una
  punta dura llega a la de la grieta; si no, aguanta entera. No hay término medio: el templado no se queda agrietado. Al
  estallar se deshace en trocitos de ~5,6 mm, ~91 por cada 5 × 5 cm (Nielsen, Schneider & Kraus 2022), y el hueco queda
  abierto.
- **La queratina** (26-33 HV) nunca lo revienta por una grieta, ni la garra de película (200 HV): son más blandas que el
  vidrio. Solo lo parte el golpe, si lo flexa más de lo que aguanta (los textos de película lo dicen con
  `FILM_CLAW_WINDOW_TXT` y `FILM_NOTE_WINDOW`; `FILM_CLAW_GLASS_TXT`, el del parabrisas, no cambia).
- **Qué ventanilla** (`pane`): la de delante. A lo largo del coche no hay un criterio físico que decida dónde cae el golpe
  (lo decide cuándo se cruzan el animal y el coche): se toma la de la misma puerta que el golpe en la puerta, y el punto del
  dibujo, `IMPACT_ZONES.luna.draw` = (0,425; 0,78), es el centro de la ventanilla delantera de la vista
  (`CarShape.side_windows()`; lo comprueba `tests/app/test_moving_car_window_draw.gd`). Calidad «dibujo». La vista dibuja
  ahí el golpe, en el cristal y no en la puerta (§15.6).

### 15.3 La energía

El balance (§2.10) sigue sumando exactamente el total, ½·m·v_rel² (el test de siempre, ahora con los golpes que puede dar
cada animal, y otro con la ventanilla):

- **El vidrio** («Ventanilla (hasta estallar)»): lo que la hoja se queda hasta estallar, U = F²/2k con la fuerza de ese
  instante: la que la parte al flexar (3,3 J con 907 N; 5,1 J con 1121; 7,5 J con 1357; 9,4 J con 1521) o la del apoyo al
  abrirse la grieta (0,2-2,2 J). Si aguanta, 0: la hoja se lo devuelve al animal al rebotar. Es poco al lado de la energía
  del golpe, pero se cuenta.
- **La energía del temple** que se libera al estallar, U_D·V = 21,7 kJ/m³ × π × 0,25² × 0,004 m³ ≈ 17 J
  (`sideWindow.temperJ`), no sale del animal: la guardaba el vidrio desde el temple y lanza los trocitos. Por eso no está
  entre los términos (el total es la energía del animal) y se da aparte.
- **El resto de la energía normal** («Animal y lo que hay tras la ventanilla (resto)» si estalla): patas, cuerpo y rebote
  y, con la luna rota, el marco, la puerta o lo que haya dentro. El modelo sigue suponiendo que en la normal acaba
  moviéndose con el coche, como en los demás golpes; **si el animal entra en el coche, no se calcula**.

### 15.4 Resultados

Coche moderno a 50 km/h y el animal que cruza a 90° (la velocidad del coche no cambia el golpe contra la luna):

| Animal | Con su queratina | Con garras de diamante |
|---|---|---|
| Águila real | a 20 km/h aguanta (~813 N por apoyo contra 1121); a 40, estalla al flexar (~1626 N) | a 20 km/h estalla por una grieta (~407 N por garra; bastan ~231); a 10, aguanta (~203 N por garra) |
| Águila arpía | a 20 km/h aguanta (~1089 contra 1183); a 40, estalla | a 10 km/h ya estalla por una grieta (~273 N por garra) |
| Halcón peregrino | aguanta hasta 40 km/h (~728 contra 907) | a 40 km/h estalla por una grieta (~364 N por garra) |
| Búho | a 40 km/h aguanta por poco (~1030 contra 1056) | a 20 km/h estalla por una grieta (~258 N por garra) |
| Lechuza | aguanta hasta 40 km/h (~431 contra 907) | a 40 km/h estalla por una grieta (~216 N por garra; bastan ~210) |
| Buitre leonado | a 20 km/h aguanta (~1028 contra 1121); a 40, estalla | a 20 km/h estalla por una grieta (~514 N por garra; bastan ~365) |
| Oso pardo | a 5 km/h aguanta (~1432 contra 1521); a 10, estalla (~2863) | a 5 km/h aguanta (~286 N por garra; bastan ~345); a 10, estalla al flexar |
| Velocirraptor (reconstrucción) | a 10 km/h aguanta (~803 contra 1121); a 20, estalla | a 5 km/h ya estalla por una grieta (~402 N por garra) |
| Velocirraptor de cine | a 5 km/h aguanta (~879 contra 1357); a 10, estalla («SE ESTRELLA CONTRA LA VENTANILLA Y LA REVIENTA») | a 5 km/h estalla por una grieta |
| Tigre y casuario | no llegan (§15.1) | — |

Lo que enseña: el templado aguanta bastante más al flexar que el laminado del parabrisas (~1,1 kN frente a ~0,4 kN con un
apoyo de 30 mm), pero una punta dura y afilada lo revienta con ~231 N por garra: al águila con garras de diamante le basta
un golpe de ~460 N por pata, menos de la mitad de lo que lo parte al flexar. Es el truco del martillo de emergencia.

### 15.5 Textos, sonido y estado

- **Veredictos** (`side_window_verdict`): «ESTALLA LA VENTANILLA» (por flexión: «~2863 N por apoyo contra ~1521 N que aguanta
  el templado al flexar: estalla entera en ~91 trocitos de ~5.6 mm por cada 5 × 5 cm, romos y sin filo, y deja el hueco
  abierto (si el animal entra en el coche, el modelo no lo calcula); …»; por una grieta: «las garras de diamante abren una
  grieta que atraviesa la capa comprimida (~845 µm) con ~407 N cada una (bastan ~231 N), aunque el golpe (~814 N por apoyo)
  no la partiría al flexar hasta ~1121 N: …») y «LA VENTANILLA AGUANTA» («~813 N por apoyo y el templado aguanta al flexar
  hasta ~1121 N; la queratina (32 HV) no la agrieta: el vidrio (550 HV) es más duro; …»). De película (`film_verdict`):
  «SE ESTRELLA CONTRA LA VENTANILLA Y LA REVIENTA» y «LA VENTANILLA LE PARA LOS PIES», con su coletilla.
- **El informe** (`side_window_txt`): la fila Ventanilla («estalla por una grieta: ~407 N por garra (bastan ~231 N; partirla
  al flexar pide ~1121 N por apoyo) · …»). La fila Salto de un velocirraptor (`window_leap_txt`): «corre a ~39 km/h y salta
  para llegar a la ventanilla: sus pies suben ~1.19 m, por encima de la cintura (~0.89 m), y golpea en lo alto del salto con
  la velocidad de su carrera».
- **Sonido** (`MovingCarState.impact_sfx`): «shatter» al estallar (el de la ventanilla del banco); «press» si aguanta.
- **Estado** (`MovingCarState`): la zona «la ventanilla» (`ZONE_ARTICLE`), la lectura Ventanilla, el porqué
  (`_why_window`), la moraleja (`_moral_window`: «Duro gana a fuerte…», «El templado no se agrieta: estalla…», «Esta vez
  gana la ventanilla…»), los «¿sabías que…?» (los ~100 MPa del temple y sus trocitos de ~5,6 mm; el punzón duro que lo
  revienta con poca fuerza; hasta dónde llega el animal; los ~17 J del temple), las fuentes legibles (la hoja templada, la
  altura de la ventanilla y hasta dónde llega) y dos experimentos de un clic: «La garra de diamante contra la ventanilla»
  (`ventanilla_diamante`: el águila que cruza a 20 km/h la revienta con poca fuerza) e «Y con sus talones de queratina»
  (`ventanilla_queratina`: el mismo golpe la deja entera).
- **Demo** (`demo_coche`): `--caso=15` y `--caso=16` (los dos experimentos) y `--caso=17` (el oso, que la revienta al
  flexarla).

### 15.6 Guía de integración

- **Datos:** `IMPACT_ZONES.luna` (con `tempered: true`, `glass: true` y `draw`), `WINDOW_ZONE`, `WINDOW_PANE`,
  `WINDOW_PANE_SOURCE`, `WINDOW_SILL_SOURCE`, `WITHERS_M`, `SRC_TEMPER`, `SRC_PUNCH`, `TEMPER_SIGMA_MPA` (la banda de la
  compresión de las caras), `WINDOW_LOW_REASON`, `WINDOW_KICK_REASON`, `FILM_CLAW_WINDOW_TXT` y `FILM_NOTE_WINDOW`.
- **Funciones puras:** `window_sill_m(which)`, `window_top_m()`, `window_reach(claw, body)`, `side_window_impact(vn_ms,
  mass_kg, contact_mm, patches, n_claws, tip, f_cap, sigma_s)`, `side_window_block`, `side_window_source`,
  `side_window_verdict`, `side_window_txt`, `window_leap_fields`, `window_leap_txt` y `window_bits_txt`. Enganches mínimos en
  `impact()`, `impact_zones_for`, `energy_balance` (un parámetro opcional al final), `_impact_verdict_core`,
  `damage_report`, `film_verdict`, `film_claw_txt` y `leap_txt`.
- **Formatos:** los números de los textos de la ventanilla salen de `CarFormat` (la 4j): las alturas con `fmt_m` («1.19 m»),
  las velocidades con `fmt_kmh`, las fuerzas con `fmt_n`, la energía con `fmt_energy` y los largos con `fmt_long` (la capa
  comprimida, «845 µm»; los trocitos, «5.6 mm»).
- **La banda del golpe** (`impact().band`, la de la 4j, §9.11): con la ventanilla se mueve la compresión de las caras, de
  150 MPa con todo a favor del coche a 80 con todo en contra (los 80-150 MPa medidos en templados comerciales, Achintha
  2020; `TEMPER_SIGMA_MPA`), con `side_window_impact` en los dos extremos: con menos compresión, la grieta que la revienta
  pide menos fuerza y los trocitos salen más grandes (de ~2,5 mm con 150 MPa a ~8,8 mm con 80). La resistencia a flexión
  (120 MPa, la de la norma), el espesor y el tamaño de la hoja y la rigidez de la pata no tienen banda (`fixed`: «pata» y
  «ventanilla»). Lo demás, como en los otros golpes: la fricción y, en los velocirraptores, su carrera más rápida (que sí
  golpea más fuerte). `band.sideWindow` da si estalla y por qué (`shattered`, `cause` y `sigmaS`, con `value`, `lo` y `hi`),
  y la fuerza de pico de cada apoyo y de cada garra, la de la grieta y los trocitos (`peakN`, `perClawN`, `pierceN`,
  `fragmentMm` y `fragments25`, con `value`, `min` y `max`); `band.lo.sideWindow` y `band.hi.sideWindow`, los dos extremos.
  En la tarjeta, la frase de la banda dice «la ventanilla aguanta (con todo en contra, estalla): 1.3 kN de pico por apoyo»
  en lugar de «perfora», la lectura Ventanilla añade «banda: con todo a favor, aguanta; con todo en contra, estalla» cuando
  cambia, y la compresión con su banda sale en «Fuentes y estimaciones». El caso central reproduce `impact()` exacto
  (`tests/lab/test_moving_car_banda.gd`). Coste: dos `side_window_impact` más (sin `Physics.compute`).
- **Las velocidades** (`impact().kinematics`, `kinematics(p, leap)`): un velocirraptor salta para llegar a la ventanilla y
  golpea en lo alto del salto, así que el salto ya no es el de un costado: `leap` (con `window_leap_fields`) lleva
  `apexM = panelM = hitM` y `timeS = v_salto/g` (0,49 s con 4,84 m/s), y la cinemática da `leap: true`, `apex: true`,
  `flightS = leap.timeS`, `dropM = fallKmh = 0` (en lo alto no baja) y la llegada de lado, con su carrera. La lectura Vuelo
  dice «salta desde la carretera y golpea en lo más alto del salto, sin subir ni bajar · el coche avanza …». Sola o dentro
  del golpe, la misma (`_leap_of` añade lo mismo que `impact()`).
- **Coste:** un `claw_tip` y un `pane_break` más que el parabrisas en el golpe, y dos `side_window_impact` en la banda: el
  golpe contra la luna no llama más veces a `Physics.compute` que el del parabrisas.
- **La vista** (`moving_car_view.gd` y `car3d/`): toma el punto del golpe de su zona cuando lo trae
  (`MovingCarView.zone_draw`: `IMPACT_ZONES[zona].draw`, que solo lleva la ventanilla; si no, el de `ZONES` o `DOOR_DRAW`,
  como siempre), trata `luna` como un costado (`CarDamage.side_zone`) y le da su tramo, el de la ventanilla delantera:
  `CarShape.PANELS.luna` = (2,27; 2,90) m, del pilar B a su esquina de delante. Así el golpe se dibuja en el cristal y no en
  la puerta, y los demás golpes caen donde siempre (`tests/app/test_car3d.gd` y `tests/app/test_moving_car_window_draw.gd`).
  La ventanilla que estalla ya se dibujaba con `sideWindow.pane`.

### 15.7 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Hoja: templado de 4 mm, 120 MPa a flexión, ~100 MPa de compresión, radio equivalente de 250 mm, trozos de 5,6 mm | la del banco (`Glazing.SIDE_WINDOW`, unidad 1f): just-auto (4 mm en Europa y Japón); EN 12150-1, vía Saint-Gobain 2018; Achintha 2020 y la CEPE R43 (compresión); Nielsen, Schneider & Kraus 2022 (perfil y trozos) | norma (resistencia y recuento de trozos), medida (perfil y trozos) y estimación (compresión y tamaño de la hoja) |
| Flexión de la hoja: placa redonda apoyada con el radio equivalente de Westergaard | Roark (Young & Budynas 2002), FISICA.md §15 | modelo con fuente |
| Fuerza de pico: F = v_n·√(m_apoyo·k), la hoja y la pata en serie | la del parabrisas y la del banco (FISICA.md §15); la pata, 10 N/mm (caso medido más parecido: Farley et al. 1993) | modelo con fuente; la pata, estimación |
| La grieta que atraviesa la capa comprimida: ~231 N con una punta de 15°, ~345 N con una de 26° | Anstis et al. (1981) con el cierre de la compresión media de la capa (`Glazing.pierce_load`, unidad 1f; perfil de Nielsen et al. 2022) | modelo con fuente |
| Cintura: 0,891 m (0,86-1,10) | el pie del parabrisas: el borde del capó de la berlina de base de Cui et al. (2025) y el capó del modelo (1,1 m a 10°) | estimación: caso medido más parecido |
| Arriba: 1,475 m | el alto de la berlina de base de Cui et al. (2025) | secundaria (cota alta) |
| Largo de la ventanilla: 0,8 m | la de la puerta delantera de una berlina media como el DrivAer (Ashton et al. 2024), sin medición | estimación |
| Cruz del tigre: 0,90 m (0,80-1,00) | San Diego Zoo Wildlife Alliance, con datos de Hunter (2011) y Mazák (1981): 80-100 cm en machos y hembras | secundaria (el centro del intervalo) |
| Cruz del oso: 1,20 m (0,90-1,50) | Animal Diversity Web, con datos de Nowak & Paradiso (1983) y Wilson & Ruff (1999): 90-150 cm; el centro del intervalo para un oso de 300 kg | estimación (el intervalo, secundario) |
| Los pies de un velocirraptor en lo alto del salto: 1,194 m (1,79) | el salto de la 4i-B2: Henry et al. (2005) y Hutchinson et al. (2015) | estimación: caso medido más parecido |
| Llega si el centro de su apoyo pasa de la cintura | por debajo, lo que carga el golpe es la puerta | suposición del modelo |
| Golpea la ventanilla de delante; el punto, (0,425; 0,78) | sin criterio físico: la de la misma puerta que el golpe en la puerta; el centro de la ventanilla delantera de la vista | dibujo |
| Energía del temple que se libera: ~17 J | U_D·V, con U_D = (1 − ν)·σS²/(5E) (Nielsen et al. 2022) y la hoja de 250 mm de radio | estimación |
| Banda de la compresión de las caras: de 80 a 150 MPa | Achintha (2020), templados comerciales medidos con polariscopio | secundaria |
| En lo alto del salto hasta la ventanilla: 0,49 s de vuelo, sin bajar | v_salto/g con el salto de la 4i-B2, sin el aire (como lo que suben sus pies) | estimación: caso medido más parecido |
| El casuario no patea la ventanilla | `KICK_ZONES` (§10.3); Naish (2007): a veces rompe el cristal | pregunta abierta |

### 15.8 Casos de referencia

Nuevos en `godot/tests/fixtures/spec/coche-en-marcha.json`, con el cálculo a mano en la nota: `aguila-diamante-ventanilla`
(estalla por una grieta con ~407 N por garra, sin fuerza para partirla al flexar), `aguila-ventanilla-aguanta` (el mismo
golpe con queratina), `oso-ventanilla` (estalla al flexar, con 9,41 J para el vidrio) y `velocirraptor-cine-ventanilla`
(salta para llegar y la revienta: veredicto de película).

Ningún caso de antes cambia: sin la ventanilla, todo da lo mismo (API aditiva). Cambian a propósito tres comprobaciones de
los tests: el balance de energía de `test_moving_car.gd` recorre los golpes que cada animal puede dar (el tigre no llega a la
ventanilla), el tigre tiene todas las zonas del golpe menos la ventanilla, y los velocirraptores suman la ventanilla, a la
que llegan saltando (`test_moving_car_velociraptor.gd`). Con la 4j unida, dos más: en la banda se mueven siete datos (el
templado, además de los seis de la 4j: `test_moving_car_banda.gd`; ocho desde la 4o, con el hueco bajo el capó) y los paneles de la vista suman el de la ventanilla, con
los de siempre igual (`test_car3d.gd`). El golden 2.0 del banco no cambia: `physics.gd` y `glazing.gd` no se tocan.

### 15.9 Qué no predice

- **Si el animal entra en el coche** por el hueco: no se calcula. El balance supone que acaba moviéndose con el coche en la
  normal (contra el marco, la puerta o lo que haya dentro), como en los demás golpes.
- **Dónde cae el golpe a lo largo del coche:** golpea la ventanilla de delante sin un criterio físico (§15.2). Tampoco
  encadena golpes: un animal que resbala no llega a la de atrás.
- **Cuánto del cuerpo queda por encima de la cintura:** en cuanto llega, la luna recibe el golpe de un apoyo entero (la
  mitad de la masa reducida); un oso que apenas pasara de la cintura la cargaría menos.
- **La hoja de verdad:** curva, inclinada hacia dentro unos grados, sujeta en sus guías por los bordes y con la carga donde
  caiga, no en el centro de una placa redonda apoyada. Ni la inercia de la hoja en un golpe corto (Kozłowski et al. 2021
  miden 13-49 J con una bola de 4,11 kg en templados de 5-15 mm; `docs/fisica/pulido-materiales.md` §6.3).
- **El salto del tigre y del oso** (erguirse o abalanzarse con las manos por delante) y la patada del casuario hacia
  arriba: sin datos en el modelo.
- **Los trocitos:** su tamaño medio sí (Nielsen et al. 2022); su vuelo, si hieren al animal o a los ocupantes, no.

## 16. Pasada de física y fallos (unidad 4o)

Una pasada sobre lo que ya había, sin física nueva grande: la hondura de las marcas de una garra que atraviesa el panel,
las bandas que faltaban y las incoherencias de los textos de los ensayos de un clic (`EXPERIMENTS`) y de los 17 casos de
`demo_coche`. Test nuevo: `godot/tests/lab/test_moving_car_hondura.gd`.

### 16.1 El fallo: marcas de 120 mm de hondo con 80 mm de hueco

El experimento «El velocirraptor de cine» (el caso 13 de la demo) decía «marcas de 120 mm de hondo» en el capó, y el
informe, «Profundidad: 120 mm (12.0 cm)», cuando bajo el capó solo hay ~80 mm de hueco (§4).

Causa: en una chapa fina, el motor (`Physics.compute`) indenta hasta romperla y la abre en pétalos (Wierzbicki 1999);
cuando el agujero llega al ancho entero de la garra (el radio de su base, 0,15 veces su alcance), la chapa ya no le opone
resistencia y la garra entra hasta su largo entero. Su `depthUm` es, por tanto, la profundidad de la punta, contada desde
la cara de fuera; el coche la usaba tal cual como hondura de la marca, y sin el tope del hueco de detrás
(`IMPACT_ZONES.clearance_mm`), que ya paraba la abolladura. Pasaba en las marcas del golpe, en su punción y en los
desgarros del animal asustado que raja la chapa quieto encima. Con un golpe a 50 km/h de cada animal en cada zona de chapa
o de plástico, coche y material de garra, 84 de 656 golpes daban marcas o una punción más hondas que el hueco más el panel;
y quieto encima, el águila asustada con garras de zafiro rajaba el capó «1.6 mm» de hondo, el doble de su chapa de 0,81 mm.

### 16.2 Qué número se enseña y por qué

- **La hondura de una marca que atraviesa el panel es la del panel** (`panel_um`: la pintura y la chapa o el plástico,
  `target.thickness`): 0,81 mm en el acero de 0,7 mm con sus 110 µm de pintura; 2,61 mm en la aleta de plástico. Es lo que
  se ve y se mide en la carrocería: una ranura de lado a lado; por debajo no hay chapa que marcar, sino el hueco. Es la
  regla que ya seguían las ranuras del plástico de la 4g y la que lee la vista (`CarDamage.mark_layer`: de lado a lado
  cuando la hondura llega al panel), así que la capa del dibujo no cambia. Los textos: «de lado a lado», «atraviesan la
  chapa (0.81 mm con la pintura)».
- **Lo que entra la punta, aparte:** `tipUm`, desde la cara de fuera, con dos topes: el hueco de detrás (`room_um` = el
  panel más `clearance_mm`) y el largo de la garra (el alcance del motor). `belowMm` es lo que asoma por detrás y `bottoms`,
  si llega al fondo: «la punta entra ~80 mm (8.0 cm) por detrás, hasta el fondo del hueco bajo el capó»; si no llega al
  fondo y asoma al menos 0,5 mm, «la punta asoma ~1.7 mm por detrás» (el tigre con garras de zafiro en la puerta).
- **Quieto encima**, el hueco es el de la zona del golpe con el mismo panel (`HOLD_PANEL`: las barras y la antena están
  en el techo). En el limpiaparabrisas, el borde de la ventanilla, el maletero y el retrovisor no hay dato del hueco: solo
  la limita su largo.
- **La punción se para en el mismo tope** (`puncture.depthUm`; desde la unidad 4p, el hueco que le deja la abolladura:
  §17.4). El agujero y el trabajo solo se vuelven a calcular si el
  tope llega antes de que la garra tenga su ancho entero (`Contact.depth_for_radius`): a partir de ahí la chapa ya no
  opone resistencia y no cambian (recalcularlos con el integrador del trabajo, de 80 trapecios por tramo, daría 78,33 J por
  garra en vez de 78,53 J: un artefacto numérico, no física). Si topa antes (el casuario con una daga de diamante contra
  la aleta de acero, con 60 mm de hueco), el agujero es el de esa profundidad y el trabajo, el de la chapa hasta ahí
  (`sheet_work_j`): menos que en la puerta, y el balance de energía sigue sumando.
- **Lo demás no cambia:** la energía del golpe, la abolladura y el balance (en el caso 13, los mismos 43,5 mm de
  abolladura, 855 J para la chapa y 157 J para las garras), y lo que no atraviesa el panel (su punta es su marca). Desde
  la unidad 4p, la punta comparte el hueco con la abolladura y esos números cambian (§17.4).

### 16.3 Bandas que faltaban

- **El hueco bajo el capó: de 20 a 100 mm**, los huecos que se ensayaron bajo un capó con una cabeza de ensayo y una placa
  rígida regulable debajo (Fredriksson et al. 2007, vía Lindgren et al. 2025, que repasa ese ensayo para explicar por qué
  el hueco cambia de un punto a otro del capó). Calidad: estimación (caso medido más parecido), con la suposición de que
  el hueco de este capó, en el punto del golpe, cae dentro de lo ensayado. En la banda del golpe, con todo a favor del capó
  el hueco es el de 20 mm (la abolladura topa antes con lo que hay debajo; a lo de debajo el modelo no le calcula el daño)
  y con todo en contra, el de 100 mm. En el caso 13: abolladura de 20 a 62,2 mm y la punta, de 20 a 100 mm por detrás
  (desde la unidad 4p, con el hueco compartido, abolladura de 20 a 63,7 mm y la punta, de 0 a 36,3 mm por detrás: §17.4).
- **Sin banda, y la fuente dice por qué:**
  - la rigidez de la pata (10 N/mm, la del motor del banco): nadie la ha medido contra una chapa. El caso medido más
    parecido, la rigidez de la pata al correr, que crece con la masa (Farley et al. 1993), es la del muelle de todo el
    animal en cada zancada, no la de una pata en un golpe; para el tigre y el oso, 10 N/mm es una cota baja;
  - el recorrido de la pata (150 mm, el orden de la flexión de las patas al aterrizar): sin medición de cuánto se doblan
    en un golpe así;
  - el hueco bajo el techo, tras la puerta y tras la aleta (`CLEARANCE_FIXED`): las normas solo dicen cuánto puede ceder el
    panel en su ensayo (el techo, 127 mm, FMVSS 216; la puerta, los primeros 152 mm de aplastamiento, FMVSS 214), no qué
    hueco hay detrás; tras la aleta está el paso de rueda, sin medición.

En la banda se mueven ahora ocho datos (el hueco, en el capó); la frase de la fuente de la banda lo dice, y «Fuentes y
estimaciones» da el hueco del capó como «80 mm (de 20 a 100): tope de la abolladura y de la punta de las garras que lo
atraviesan».

### 16.4 Incoherencias de los textos (y su arreglo)

Revisados los textos de los ensayos de un clic y de los 17 casos de la demo (veredicto, porqué, lecturas, banda, informe,
datos y fuentes):

| Antes | Ahora | Por qué |
|---|---|---|
| «marcas de 120 mm de hondo»; «Profundidad: 120 mm (12.0 cm)» | «marcas que atraviesan la chapa (0.81 mm con la pintura)»; «la punta entra ~80 mm (8.0 cm) por detrás, hasta el fondo del hueco bajo el capó» | §16.1-16.2 |
| Fuerza necesaria del oso de pie en el techo en una frenada de emergencia, a 60 km/h y con 109 N de aire: «banda de 2539 N a 2539 N» | «banda de 2467 N a 2587 N» | fallo de cálculo: la máxima salía solo de los casos en contra y la mínima de los de a favor, y con una frenada es al revés: el aire que más empuja hacia atrás (un caso en contra) es el que menos fuerza pide (`at_speed`, con test) |
| «banda de 3119 N a 3119 N» (parado) | «igual con todos los datos» | los dos extremos se escriben igual |
| «Frente al coche entero: 0 % de los 0.0 N» | «sin aire» | parado y sin viento no hay resistencia del coche con la que comparar |
| un ave con las alas abiertas «se suelta a ~24 km/h»; «La suelta su propia sustentación» | «despega a ~24 km/h»; «La levanta su propia sustentación», como su veredicto (DESPEGA) | |
| «43 N hacia arriba frente a 49 N de peso: se queda sin apoyo» | «…: le queda muy poco apoyo y vuela» | despega cuando la sustentación sostiene la mitad de su peso: le queda algo de apoyo |
| «Con todos los datos en contra se suelta; con todos a favor se suelta» | «Con todos los datos, en contra o a favor, se suelta» | sin repetir |
| «con esa frenada; más deprisa, …» (cortada) | «despacio, la frenada lo empuja más de lo que aguanta; más deprisa, …» | la frase entera |
| «3032.0 kN» | «3.0 MN» | unidades: MN desde 1 MN (el número, el de las garras clavadas, era un fallo: desde la unidad 4p, «20.6 kN», §17) |
| «Contacto: 0 ms» (de lado, sin abolladura ni resbalón: la ventanilla, el plástico perforado si se le sueltan las garras) | la lectura no sale | el modelo no tiene un tiempo de contacto que dar |
| «Resbala: 0.0 µm» | «Resbala: nada · golpea de lado y sale a 35 km/h del panel» | |
| la banda contra el parabrisas: «no perfora» | «el parabrisas se agrieta y puede atravesarlo» | lo que dice el veredicto (las garras no perforan el vidrio) |
| el informe: «más de 89 J»; el dato: «88.7 J» | «más de 88.7 J» en los dos | el mismo número |
| «0.90 g a 60 km/h (caso central; la de emergencia es de 0.90 g)» mientras sale despedido | «0.89 g a 60 km/h …» | la frenada máxima, 0,897 g, se escribe redondeada hacia abajo (`CarFormat.fmt_g_max`): lo que aguanta seguro |
| «Detrás de la aleta hay ~60 mm de hueco: la abolladura no puede ser más honda» en la aleta de plástico | «…: la punta de unas garras que lo atraviesan no puede entrar más» | el plástico perforado no se abolla |
| el término de la energía «Chapa (abolladura)», 0 J, en la aleta de plástico | «Plástico (no se abolla)» | |
| «Ventanilla (hasta estallar)», 0 J, si aguanta | «Ventanilla (aguanta: lo devuelve)» | |
| la ventanilla que aguanta: «· trocitos de ~5.6 mm» | «· si estalla, trocitos de ~5.6 mm» | los haría si estallara |

### 16.5 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Hondura de una marca que atraviesa el panel: el panel (0,81 mm en el acero; 2,61 mm en la aleta) | el espesor del panel del catálogo (`target.thickness`: 110 µm de pintura y la chapa o el plástico) | geometría del modelo |
| Tope de la punta: el panel más el hueco de detrás | los huecos de §4 (`clearance_mm`) | estimación (§5) |
| Banda del hueco bajo el capó: 20-100 mm | Fredriksson et al. (2007), vía Lindgren et al. (2025) | estimación: caso medido más parecido |
| Hueco del techo, la puerta y la aleta: sin banda | FMVSS 216 (127 mm) y FMVSS 214 (152 mm): lo que puede ceder el panel en su ensayo; la aleta, sin medición | estimación |
| Rigidez de la pata (10 N/mm): sin banda | la del motor; caso más parecido, Farley et al. (1993), el muelle de todo el animal al correr | estimación (cota baja para el tigre y el oso) |
| Recorrido de la pata (150 mm): sin banda | el orden de la flexión de las patas al aterrizar | estimación sin medición |

### 16.6 Casos de referencia y tests

- `velocirraptor-cine-capo` (`godot/tests/fixtures/spec/coche-en-marcha.json`) suma, con la cuenta en su nota:
  `marks.through`, `marks.depthUm` 810 µm, `marks.tipUm` 80 810 µm (810 + 80 000: el hueco, no los 120 mm de la garra),
  `marks.bottoms`, `puncture.depthUm` 80 810 µm (antes, 120 000) y `puncture.holeUm` 36 000 µm (no cambia: con 15° de
  semiángulo, la garra tiene su ancho entero, 36 mm, a 66,8 mm de la punta, antes del fondo). Lo demás del caso, igual.
  Desde la unidad 4p, con el hueco compartido, 34 987 µm y 18 962 µm (§17.6).
- Ningún otro caso cambia (ninguno esperaba la hondura de una marca que atraviesa el panel), ni el golden 2.0 del banco
  (`physics.gd` no se toca).
- Invariantes (`test_moving_car_hondura.gd`): la hondura nunca pasa del hueco más el panel ni del largo de la garra; si
  atraviesa, es la del panel; y la punta (en las marcas, los desgarros y la punción) no pasa del hueco ni de su largo, en
  todos los animales, coches, zonas, materiales y con miedo, en el golpe y quieto encima. Y la banda de cada fuerza sale de
  todos los casos (`test_moving_car.gd`).
- Cambian a propósito: la abolladura del capó en la banda se mueve con su hueco y no pasa de él, y se mueven ocho datos
  (`test_moving_car_banda.gd`); y los textos de §16.4 en `test_moving_car.gd`, `test_moving_car_state.gd`,
  `test_moving_car_textos.gd`, `test_moving_car_window.gd` y `test_moving_car_ui.gd`.

### 16.7 Qué no predice

- **Lo que hay en el fondo del hueco** (el motor, la barra de la puerta): ni su daño ni si la garra se rompe o se dobla al
  topar con ello (la rotura de §11 es la de la carga de lado).
- **Los bordes de la ranura:** los pétalos doblados hacia dentro no se miden ni se dibujan; la ranura tiene el ancho del
  agujero.
- **El hueco de cada punto del capó:** la banda supone que el del punto del golpe cae en lo ensayado (20-100 mm).

## 17. Lo que aguantan de lado unas garras clavadas y el hueco compartido (unidad 4p)

Dos arreglos que dejó abiertos la 4o: lo que aguantan de lado unas garras reforjadas clavadas en la chapa
(«aguantan de lado 3.0 MN»), que solo miraba la flexión de la garra, y la punta de unas garras que atraviesan el panel,
que tenía para ella sola el hueco de debajo aunque la abolladura ya se hubiera comido una parte (§16.7). Tests nuevos:
`godot/tests/lab/test_moving_car_clavadas.gd` y, en `test_moving_car_hondura.gd`,
`test_la_punta_y_la_abolladura_comparten_el_hueco`.

### 17.1 El fallo: «aguantan de lado 3.0 MN»

El águila con talones de carburo de tungsteno clavados en el techo decía, quieta encima, «Garras clavadas: aguantan de
lado 3.0 MN»: más de 300 toneladas con cuatro garras de 10,5 mm de grueso en una chapa de 0,7 mm. `claws_hold_n` solo
miraba la flexión de la garra (§11.2), con la carga en el borde del agujero. Hundida hasta la base, ese borde la empuja en
el plano medio de la chapa, a 0,46 mm de los dedos (los 110 µm de pintura y media chapa), y con ese brazo la base casi no
flexa: σ = 4·F·0,46/(π·5,25³) llega a los 3068 MPa del carburo con ~758 kN por garra. Con un brazo tan corto ceden antes
otras dos cosas: la garra se cizalla en esa sección y, sobre todo, la chapa se aplasta y se rasga alrededor del agujero,
como la chapa de una unión atornillada cuando tira de ella el tornillo.

### 17.2 Tres límites, y manda el menor

`claws_hold_n` (`moving_car.gd`) calcula los tres para cada garra y se queda con el menor:

| Límite | Cómo se calcula | Fuente |
|---|---|---|
| Flexión de la garra (la de siempre) | la sección más cargada, con la carga en el borde del agujero: σ = 4·F·(x − x0)/(π·r³) (`ClawFracture.peak`) | §11.2 |
| Cortante de la garra (`ClawFracture.shear_limit_n`) | en la sección de la garra en la cara de fuera del metal, por donde ya ha pasado toda la carga de la chapa: τ máx = 4V/(3A) en una sección circular maciza, así que F = τ·3π·r²/4. Un frágil se rompe cuando τ llega a su resistencia a flexión (en cortante puro, la tensión principal es τ: criterio de la tensión normal máxima); un dúctil fluye cuando llega a σ/√3 (von Mises), con la tensión de flujo de Tabor (H/2,8) | Timoshenko y Gere (1997); Budynas y Nisbett (2015), cap. 5 |
| La chapa alrededor del agujero (`sheet_bearing_n`) | la garra como un tornillo que aplasta una chapa fina lejos de sus bordes: F = 2,5·k_t·f_u·d·t, con k_t = (0,8·t + 1,5)/2,5 hasta 1,25 mm y 1 por encima, sin el coeficiente de seguridad γ_M2; d, el diámetro de la garra en el plano medio de la chapa. Es la regla de la chapa gruesa (k_1·α_b·f_u·d·t, con k_1 = 2,5 y α_b = 1 lejos de los bordes) rebajada en chapa fina, que se arruga antes | EN 1993-1-3, tabla 8.4 (de 0,75 a 3 mm; la de 0,7 mm del coche moderno, con la misma recta); EN 1993-1-8, tabla 3.4 |

- **Dónde se mira el cortante:** la chapa empuja la garra a lo largo de toda la parte que tiene dentro del metal. Con la
  presión repartida por el espesor, la misma suposición que la regla de la chapa, en un cono el cortante es el mismo en
  toda esa parte, el de la sección de la cara de fuera del metal con toda la carga. Clavada hasta la base, es la base;
  recién asomada, la sección a una chapa del vértice. Con toda la carga concentrada a media chapa, donde la flexión pone su
  carga, la sección sería más fina y el cortante saldría de 2 a 2,5 veces más alto: un límite que no es el de la regla de
  la chapa.
- **La f_u de cada chapa** (`SHEET_FU`), la de las fichas de las carrocerías (docs/FISICA.md, apartado 14): el acero de
  horno del coche moderno, 340 MPa (de 290 a 360; Nippon Steel 2013, voestalpine 2022); el acero dulce del clásico,
  310 MPa (de 270 a 350; ArcelorMittal B10), y el aluminio, 273 MPa, sin banda (una sola medición; Prillhofer et al. 2014).
- **El valor**, con la punta hundida hasta la base (`embed_mm`, por defecto) y las resistencias centrales. **La banda
  favorable**, en el mismo sitio, con las máximas y, en la chapa, 3·f_u·d·t, la regla sin límite de deformación del
  agujero (AISC 360-16, J3.10). **La desfavorable**, con la punta recién asomada por detrás de la chapa (la carga a media
  chapa del vértice, donde la garra es más fina) y las mínimas.
- **Lo que devuelve:** `governs` («chapa», «cortante» o «flexion»; `governsMin` y `governsMax`, en los extremos de la
  banda), `perClaw` con los tres límites de una garra, `clawN` (la garra sola: el menor de flexión y cortante) y `sheetN`
  (la chapa), todas juntas, y `dMm`, `tMm`, `kt` y `fuMPa`. Su calidad y su fuente son las del límite que manda (la chapa:
  estimación; la garra: la de su material).
- **Lo que se lee**, quieto encima: «Garras clavadas: aguantan de lado 20.6 kN · hundidas hasta la base · manda la chapa:
  se aplasta alrededor del agujero con ~5148 N por garra (la garra aguantaría ~199.2 kN) · banda de 567 N a 31.8 kN (lo
  peor: la punta recién asomada)». Si manda la garra: «se cizalla a la altura de la chapa» («fluye a cortante», si es
  dúctil) o «se parte por donde más flexa» («se dobla»). En «Fuentes y estimaciones», una fila nueva, «Chapa alrededor
  del agujero (aplastamiento)»: «Rm 340 MPa (de 290 a 360) · 2,5·k_t·Rm·d·t con k_t 0.82 y d …: ~5148 N por garra».

Resultados en el coche moderno (chapa de 0,7 mm; apoyan cuatro garras, ocho el tigre y diez el oso):

| Garras clavadas hasta la base | Antes (solo flexión) | Ahora | Manda | Banda |
|---|---|---|---|---|
| Águila, carburo de tungsteno | 3,0 MN | 20,6 kN | la chapa: ~5148 N por garra (la garra sola, ~199 kN) | 567 N (flexión) - 31,8 kN |
| Águila, diamante | 2,8 MN | 20,6 kN | la chapa | 322 N (flexión) - 31,8 kN |
| Águila, zafiro | 751 kN | 20,6 kN | la chapa | 140 N (flexión) - 31,8 kN |
| Águila, acero | 692 kN | 20,6 kN | la chapa | 129 N (flexión) - 31,8 kN |
| Águila, cuarzo | 51,8 kN | 13,6 kN | el cortante de la garra: ~3403 N por garra | 9,7 N (flexión) - 13,6 kN |
| Águila, vidrio o strass | 44,5 kN | 11,7 kN | el cortante: ~2922 N por garra | 8,3 N (flexión) - 11,7 kN |
| Lechuza, vidrio | 3501 N | 2147 N | el cortante | 4,1 N (flexión) - 2147 N |
| Tigre, carburo de tungsteno | 9,1 MN | 47,1 kN | la chapa | 1368 N (la chapa) - 72,6 kN |
| Oso, carburo de tungsteno | 38,2 MN | 88,3 kN | la chapa | 3513 N (la chapa) - 136,1 kN |
| Oso, vidrio | 560 kN | 85,9 kN | el cortante | 205 N (flexión) - 85,9 kN |
| Velociraptor, carburo de tungsteno | 56,3 MN | 54,5 kN | la chapa | 669 N (la chapa) - 84,1 kN |

Manda la chapa con casi todos los materiales; el cortante, con las garras frágiles más flojas (vidrio, strass y cuarzo),
que se cizallan antes de que la chapa ceda, y la flexión, en la banda desfavorable, con la punta recién asomada. En el
clásico (0,9 mm y 310 MPa) y en el de aluminio (1,0 mm y 273 MPa) la chapa aguanta algo más: ~6503 y ~6593 N por garra
del águila.

La banda desfavorable, con la punta recién asomada, casi siempre es la de antes: allí la garra es fina y manda su
flexión. Solo baja con las garras más fuertes (carburo de tungsteno y diamante), donde la chapa alrededor de esa sección
fina aguanta menos que la garra. En el coche moderno: el oso, de 14,0 kN a 3513 N con carburo (de 7936 a 3513 N con
diamante); el buitre, de 4781 a 1244 N (de 2712 a 1244 N); el tigre, de 1560 a 1368 N, y la arpía y los dos
velocirraptores, de 696 a 669 N.

**Quieto encima**, el anclaje es el menor del agarre (o del gancho) y de lo que aguantan las garras, y el agarre queda muy
por debajo (el águila: ~202 N frente a 20,6 kN). Con cada animal, coche, zona y material con garras clavadas en la chapa
(2460 casos), el valor y la banda favorable del anclaje no cambian en ninguno, y la desfavorable solo en 7: el
velocirraptor de cine con carburo de tungsteno en el coche moderno, de 696 a 669 N (un 4 %, la chapa alrededor de la
punta recién asomada). A 60, 100, 140 y 200 km/h no cambia ningún veredicto, ni los del águila de §11.4.

### 17.3 Más chapa nunca aguanta menos (y dónde no se le puede pedir)

- **La chapa alrededor del agujero** aguanta más cuanto más gruesa: 2,5·k_t·f_u·d·t crece con t, y k_t también hasta
  1,25 mm (test de 0,3 a 3 mm).
- **La banda desfavorable**, con la punta recién asomada, tampoco baja nunca: con más chapa, la sección de la garra en el
  borde del agujero, a media chapa del vértice, es más gruesa (test con cada garra, material y coche, de 0,3 a 3 mm).
- **El valor, con las garras hundidas hasta la base**, tampoco baja en las chapas de carrocería (test de 0,5 a 1,25 mm;
  las del catálogo son de 0,7, 0,9 y 1,0 mm). Con más de 1,3 mm sí puede bajar, y es física: la carga actúa a media chapa,
  así que el brazo hasta los dedos crece con el espesor (la pintura y media chapa) y, si lo que manda es la flexión de la
  base de una garra pequeña o de un material flojo, la que aguanta menos es la garra, no la chapa: la lechuza con vidrio,
  desde 1,3 mm (con acero, desde 2,4); el halcón con vidrio, desde 1,6 mm; el buitre, desde 2,3 mm, y el búho, desde
  2,8 mm.
- **Con la punta a una hondura fija** (`embed_mm`), una chapa más gruesa empuja la garra más cerca del vértice, donde es
  más fina, y la flexión aguanta menos (el águila con acero clavada 5 mm: de 6,8 kN con 0,7 mm a 6,0 kN con 1,25): no es
  la misma garra igual de clavada, y el test no lo compara.
- **El límite nunca pasa del de la garra sola** (el menor de su flexión y su cortante), ni del de la chapa, ni del que daba
  antes la flexión sola; el que manda es el menor, y el texto dice cuál (test con diez animales, los tres coches, trece
  materiales y la punta hasta la base, a 1, a 5 y a 20 mm).

### 17.4 La punta y la abolladura comparten el hueco

- **El fallo (§16.7):** la punta de unas garras que atraviesan el panel tenía para ella sola el hueco de debajo
  (`room_um`: el panel y `clearance_mm`), aunque la abolladura, del mismo apoyo, ya hubiera hundido la chapa. En el caso
  13, 80,8 mm de punta y 43,5 mm de abolladura en 80 mm de hueco.
- **Ahora:** las garras están en el apoyo que abolla la chapa, así que, con la chapa hundida δ, a la punta le quedan, desde
  la cara de fuera, el panel y el hueco que queda debajo (`shared_room_um`: el panel más máx(clearance − δ, 0)). Pero la
  abolladura depende de la energía que se quedan las garras y esa energía, de lo que entra la punta: si el agujero aún no
  tiene el ancho entero de la garra, una punta más corta se lleva menos trabajo de la chapa y queda más para abollarla.
  Se resuelven a la vez (`_share_gap`): con la punta topando en lo que le deja la abolladura, se rehacen la punción
  (`_puncture_block`) y la abolladura (`dent_of`) hasta que la punta cabe. La abolladura solo crece y el hueco solo
  encoge, así que la serie converge: en los 656 golpes de la prueba (cada animal en cada zona, coche y material, a 50
  km/h), ninguna vuelta si la punta ya cabe, una si el agujero ya tenía el ancho de la garra (el trabajo no cambia) y, si
  no, de 2 a 8 casi siempre y 23 como mucho (`SHARED_GAP_STEPS`: 60). Cuesta unos 3 ms más por golpe (de 17 a 20 ms en
  la máquina de la nube, con el cálculo en su hilo).
- **Solo si la chapa se abolla y la punta la atraviesa.** El plástico perforado, que no se abolla, deja a la punta el
  hueco entero.
- **Las marcas conservan el hueco entero:** resbalan por la chapa, fuera de la abolladura del apoyo (su `tipUm`, el de la
  4o).
- **La banda, igual**, cada extremo con su hueco (bajo el capó, 20 o 100 mm).
- **Una garra más afilada**, si llega al fondo, asoma menos por debajo de la chapa hundida: se queda menos energía y la
  chapa se abolla más. Lo que no baja es hasta dónde llega contando desde donde estaba la chapa antes del golpe (la punta
  y la abolladura juntas): al fondo, el hueco entero.
- **El «¿Sabías que…?»** lo dice: «Bajo el capó hay ~80 mm de hueco: lo comparten la abolladura, que no puede ser más
  honda, y la punta de unas garras que atraviesan la chapa; donde se apoya, con la chapa hundida ~45.8 mm (4.6 cm), a la
  punta le quedan ~34.2 mm (3.4 cm) por debajo.» Y el informe, en «Perforación» (`shared_gap_txt`): «atraviesa la chapa:
  agujeros de Ø 19 mm (1.9 cm); donde se apoya, con la chapa hundida ~45.8 mm (4.6 cm), la punta entra ~34.2 mm (3.4 cm)
  por debajo» o, si la abolladura llena el hueco, «la punta no asoma por debajo». En «Profundidad» siguen las marcas, que
  resbalan fuera de la abolladura: «la punta entra ~80 mm (8.0 cm) por detrás, hasta el fondo del hueco bajo el capó».

| Caso | Antes (4o) | Ahora |
|---|---|---|
| El velocirraptor de cine en el capó (caso 13) | punta a 80,8 mm (agujero de 36 mm) y abolladura de 43,5 mm; garras 157,1 J y chapa 855,5 J | punta a 35,0 mm (agujero de 19,0 mm: aún no tiene el ancho entero de la garra) y abolladura de 45,8 mm, 80,8 mm entre las dos; garras 64,5 J y chapa 948,0 J |
| Su banda (20-100 mm de hueco) | abolladura de 20 a 62,2 mm; punta, de 20 a 100 mm por detrás | abolladura de 20 a 63,7 mm; punta, de 0 a 36,3 mm por detrás |
| El de cine contra la puerta (150 mm de hueco) | punta a 120 mm, su largo, y abolladura de 106,2 mm; garras 157,1 J | punta a 43,9 mm y abolladura de 106,9 mm; garras 88,0 J y chapa 5120 J (antes 5051) |
| El oso con garras de acero en el capó | punta a 60 mm, su largo, y abolladura de 34,7 mm | punta a 46,2 mm, y la abolladura y el trabajo de las garras, iguales: el agujero ya tenía su ancho entero (18 mm) |
| El velocirraptor con dagas de tungsteno afiladas en el capó | punta a 80,8 mm | a 78,4 mm, con su abolladura de 2,4 mm; en la banda, con 20 mm de hueco, punta a 14,4 mm y abolladura de 6,4 mm (antes, 20,8 y 3,9): con menos punta, las garras se quedan menos energía y la chapa se abolla más |
| El tigre con garras de zafiro contra la puerta | punta a 40 mm, su largo; garras 136,4 J; la garra se mella al perforar (390 N, ~4,5 mm) | la abolladura llena los 150 mm de hueco y la punta se queda en la cara de dentro (810 µm); garras 1,03 J; se mella en la indentación (352 N, ~4,2 mm) |

En los 656 golpes, la punta entra menos en 132, la abolladura es más honda en 36 (hasta 2,8 mm más) y las garras se quedan
menos energía en 90; en ninguno la punta y la abolladura juntas pasan del hueco.

### 17.5 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Resistencia a tracción de la chapa: 340 MPa (290-360) en el acero de horno del moderno | voestalpine (2022), EN 10268; Nippon Steel (2013) | secundaria |
| 310 MPa (270-350) en el acero dulce del clásico | ArcelorMittal, catálogo B10 (EN 10130) | secundaria |
| 273 MPa en el aluminio AA6016 tras hornear la pintura | Prillhofer et al. (2014) | secundaria (una sola medición) |
| Aplastamiento de la chapa: 2,5·k_t·f_u·d·t, con k_t = (0,8·t + 1,5)/2,5 | EN 1993-1-3, tabla 8.4 (y EN 1993-1-8, tabla 3.4, en chapa gruesa) | estimación: caso medido más parecido (un tornillo, no una garra cónica); la chapa de 0,7 mm, fuera del rango de la norma (desde 0,75) |
| Banda favorable de la chapa: 3·f_u,máx·d·t | AISC 360-16, J3.10 (sin límite de deformación del agujero) | estimación |
| Cortante de la garra: τ máx = 4V/(3A), en la sección de la cara de fuera del metal | Timoshenko y Gere (1997); la presión repartida por el espesor, como en la regla de la chapa | modelo |
| Rotura a cortante: τ = σ_flexión (frágil) y σ_flujo/√3 (dúctil) | Budynas y Nisbett (2015), cap. 5; la resistencia de cada material, la de §11.3 | modelo, con la calidad del material |
| La punta en el hueco que deja la abolladura: panel + máx(clearance − δ, 0) | geometría del modelo; los huecos de §4 | estimación (los huecos) |

### 17.6 Casos de referencia y tests

- `velocirraptor-cine-capo` (`godot/tests/fixtures/spec/coche-en-marcha.json`): `puncture.depthUm` 34 987,234 µm (antes,
  80 810) y `puncture.holeUm` 18 961,688 µm (antes, 36 000), con la abolladura de 45,8228 mm (antes, 43,5) y las garras
  64,5046 J (antes, 157,1), con la cuenta en su nota.
- `velocirraptor-cine-puerta`: abolladura de 106,9494 mm y la punta a 43 860,62 µm, al fondo de lo que le deja.
- `tigre-zafiro-puerta`: la punta, en la cara de dentro (810 µm, `bottoms`); la garra, con la carga de la indentación
  (`forceBasis` «indentacion», 352,1499 N, 4,2348 mm) y 1,0339 J para las garras.
- Los demás casos de referencia pasan igual (en `oso-acero-capo` y `velocirraptor-tungsteno-afilado-capo` cambia la punta,
  que su caso no mira: tabla de §17.4), y el golden 2.0 del banco no cambia por esto (`physics.gd` no se toca aquí).
- `test_moving_car_clavadas.gd`: los talones de tungsteno del águila a mano (4 × 2,5 × 0,824 × 340 × 10,5 × 0,7 =
  20 591,76 N; manda la chapa; el cortante de la garra, ~199 kN), los de vidrio (manda el cortante), el cortante en la
  sección de la cara de fuera del metal, los invariantes de §17.3 y lo que se lee.
- `test_moving_car_hondura.gd`: la punta y la abolladura juntas nunca pasan del hueco y, si la punta topa, está justo al
  fondo de lo que le deja la abolladura, en cada animal, coche, zona y material; el caso 13 con sus números, el balance de
  energía, la banda (20 y 100 mm) y el «¿Sabías que…?»; y la aleta de plástico, que no se abolla, con el hueco entero.
- Cambian a propósito: el límite de `test_moving_car.gd` (el menor de los tres) y la resistencia de la chapa que integra
  `test_la_resistencia_de_la_chapa_es_la_del_motor` hasta el largo de la garra cuando la punta topa con su ancho entero;
  y en `test_moving_car_velociraptor.gd`, «una garra reforjada más afilada nunca entra menos» cuenta la abolladura: una
  garra más afilada se queda menos energía y deja abollar más la chapa, así que, al fondo, le queda menos hueco por
  debajo; lo que no baja es hasta dónde llega desde donde estaba la chapa antes del golpe (la punta y la abolladura juntas).

### 17.7 Qué no predice

- **Los pétalos:** la chapa abierta en pétalos doblados alrededor de la garra ni suma ni resta a lo que aguanta de lado; la
  regla es la de un agujero que ya tiene la forma del pasador.
- **El reparto por el espesor:** el aplastamiento se toma uniforme en todo el espesor de la chapa, con la flexión cargada en
  su plano medio y el cortante en la cara de fuera del metal, sin el giro de la garra en el agujero.
- **Una garra cónica no es un tornillo:** la regla de la chapa es la de un pasador cilíndrico; la garra se estrecha hacia
  la punta y, al tirar de lado, puede salirse del agujero o abrirlo más (por eso la regla es una estimación).
- **El orden del golpe:** el hueco compartido es el del estado final, sin la secuencia. En la realidad la punta perfora al
  principio, con el hueco aún abierto, y luego la chapa baja con la garra dentro: si la abolladura se come todo el hueco
  (el tigre con zafiro contra la puerta), el modelo deja la punta en la cara de dentro y evalúa la rotura de la garra
  hasta ahí, con la carga de la indentación (352 N), un 10 % menos que al perforar (390 N): del lado no seguro.
- **La rotura de la garra en el golpe** sigue mirando solo la flexión (§11.2). Con el cortante mirado como aquí (la
  sección de la cara de fuera del metal cuando la punta sale por detrás), la flexión manda en todos los animales y
  materiales calculados, pero por poco en el oso con garras de acero o de titanio: 332 N de cortante frente a 320 N de
  flexión con acero, un 4 %. Con otro reparto de la carga por el espesor podría mandar el cortante: queda abierto.

## 18. Fuentes

- AASHTO (2011). *A Policy on Geometric Design of Highways and Streets* (6.ª ed.). American Association of State Highway and Transportation Officials.
- Achintha M (2020). Construction of full residual stress depth profile in glass using the knowledge of surface stress. *Challenging Glass 7*, Ghent University. doi:10.7480/cgc.7.4504 (templados comerciales: 80-150 MPa de compresión superficial).
- Adams JW, Ruh R, Mazdiyasni KS (1997). Young's modulus, flexural strength, and fracture of yttria-stabilized zirconia versus temperature. *J. Am. Ceram. Soc.* 80:903-908. doi:10.1111/j.1151-2916.1997.tb02920.x
- AISC (2016). *Specification for Structural Steel Buildings* (ANSI/AISC 360-16). American Institute of Steel Construction, Chicago (J3.10: aplastamiento en los agujeros de los tornillos, 3,0·d·t·F_u cuando la deformación del agujero no es una condición de diseño).
- Alduchov OA, Eskridge RE (1996). Improved Magnus form approximation of saturation vapor pressure. *J. Appl. Meteorol.* 35:601-609. doi:10.1175/1520-0450(1996)035<0601:IMFAOS>2.0.CO;2
- Alerstam T (1987). Radar observations of the stoop of the Peregrine Falcon *Falco peregrinus* and the Goshawk *Accipiter gentilis*. *Ibis* 129:267-273. doi:10.1111/j.1474-919X.1987.tb03207.x
- Alerstam T, Rosén M, Bäckman J, Ericson PGP, Hellgren O (2007). Flight speeds among bird species: allometric and phylogenetic effects. *PLoS Biol.* 5:e197 (Protocol S1). doi:10.1371/journal.pbio.0050197
- Animal Diversity Web (Museo de Zoología de la Universidad de Michigan). *Ursus arctos* (brown bear): 90-150 cm a la cruz y de 80 a más de 600 kg, con datos de Nowak RM, Paradiso JL (1983), *Walker's Mammals of the World* (4.ª ed.), y Wilson D, Ruff S (1999), *The Smithsonian Book of North American Mammals*. https://animaldiversity.org/accounts/Ursus_arctos/
- Anstis GR, Chantikul P, Lawn BR, Marshall DB (1981). A critical evaluation of indentation techniques for measuring fracture toughness: I, direct crack measurements. *J. Am. Ceram. Soc.* 64:533-538. doi:10.1111/j.1151-2916.1981.tb10320.x (la grieta radial bajo una punta; con el afilado de la punta, en la unidad 1f).
- ArcelorMittal. *B10 – Steels for cold forming* (DC01-DC07, EN 10130), catálogo técnico (DC04: Rm 270-350 MPa; vía docs/FISICA.md, apartado 14).
- Ashton N, Mockett C, Fuchs M et al. (2024). DrivAerML: high-fidelity computational fluid dynamics dataset for road-car external aerodynamics. arXiv:2408.11969 (el DrivAer de referencia: 2,786 m de batalla y 2,17 m² de área frontal).
- Balmer RS et al. (2009). Chemical vapour deposition synthetic diamond: materials, technology and applications. *J. Phys.: Condens. Matter* 21:364221 (tabla 2). doi:10.1088/0953-8984/21/36/364221
- Borrell B (2008). Invasion of the cassowaries. *Smithsonian Magazine*, octubre.
- Bowden FP, Tabor D (1950). *The Friction and Lubrication of Solids*. Clarendon Press, Oxford (el término de arado: arrastrar una punta hundida pide la dureza del material por la sección del surco que tiene delante).
- Budynas RG, Nisbett JK (2015). *Shigley's Mechanical Engineering Design* (10.ª ed.). McGraw-Hill, Nueva York (cap. 5: un frágil, con la tensión normal máxima; un dúctil fluye a cortante a σ/√3, von Mises).
- Campione NE, Evans DC, Brown CM, Carrano MT (2014). Body mass estimation in non-avian bipeds using a theoretical
  conversion to quadruped stylopodial proportions. Methods Ecol. Evol. 5:913-923. doi:10.1111/2041-210X.12226
- Corning Incorporated. *HPFS® Fused Silica, Standard Grade 7980*, ficha técnica (módulo de rotura con la superficie desgastada: 52,4 MPa).
- Cui S, Shi L, Wang G, Chen J, Liu N, Long Y, Shi Z (2025). Study on the influence of passenger car front shape on pedestrian thorax injury based on the FASS database. *Transp. Saf. Environ.* 7(3):tdaf040. doi:10.1093/tse/tdaf040 (452 frontales de turismos medidos: capó de 54 a 123 cm y de 11 a 44°).
- Cullen TM, Larson DW, Witton MP, Scott D, Maho T, Brink KS, Evans DC, Reisz R (2023). Theropod dinosaur facial reconstruction and the importance of soft tissues in paleobiology. *Science* 379:1348-1352. doi:10.1126/science.abo7877 (los terópodos tenían labios que tapaban los dientes)
- Derler S, Gerhardt L-C (2012). Tribology of skin: review and analysis of experimental results for the friction coefficient of human skin. *Tribol. Lett.* 45:1-27. doi:10.1007/s11249-011-9854-y
- Encyclopaedia Britannica. «Harpy eagle» (envergadura 1,76-2,24 m).
- Farley CT, Glasheen J, McMahon TA (1993). Running springs: speed and animal size. *J. Exp. Biol.* 185:71-86. doi:10.1242/jeb.185.1.71
- Ferguson-Lees J, Christie DA (2001). *Raptors of the World*. Christopher Helm, Londres (medidas y rasgos de campo de las rapaces diurnas).
- Field JE (ed.) (1992). *The Properties of Natural and Synthetic Diamond*. Academic Press, Londres.
- Field JE, Freeman CJ (1981). Strength and fracture properties of diamond. *Philos. Mag. A* 43:595-618. doi:10.1080/01418618108240397
- Fowler DW, Freedman EA, Scannella JB, Kambic RE (2011). The predatory ecology of Deinonychus and the origin of flapping
  in birds. PLoS ONE 6:e28964. doi:10.1371/journal.pone.0028964
- Fredriksson R, Zhang L, Boström O, Yang K (2007). Influence of impact speed on head and brain injury outcome in vulnerable road user impacts to the car hood. *Stapp Car Crash J.* 51:155-167 (cabeza de ensayo contra un capó con una placa rígida debajo, a 20-100 mm; vía Lindgren et al. 2025).
- Garland T (1983). The relation between maximal running speed and body mass in terrestrial mammals. *J. Zool.* 199:157-170. doi:10.1111/j.1469-7998.1983.tb02087.x
- General Carbide (2018). *Grade Specifications*: GC-005, carburo de tungsteno con 5,5 % de Co submicrónico, 93,0-94,5 HRA, rotura transversal media de 445 000 psi (ASTM B406 / ISO 3327).
- *Grzimek's Animal Life Encyclopedia* (2003), 2.ª ed., vol. 8, *Birds I*. Gale, Farmington Hills (casuario común: hembra de 58 kg, macho de 29-34 kg, espolón de hasta 12 cm).
- Guinness World Records. «Longest eagle talons» (arpía: talón trasero de hasta 13 cm). https://www.guinnessworldrecords.com/world-records/444930-longest-eagle-talons
- Harel R, Horvitz N, Nathan R (2016). Adult vultures outperform juveniles in challenging thermal soaring conditions. *Sci. Rep.* 6:27865. doi:10.1038/srep27865
- Healy TP (2022). Southern Cassowary (*Casuarius casuarius*). En *Birds of the World*. Cornell Lab of Ornithology, Ithaca («hasta 50 km/h»).
- Henry HT, Ellerby DJ, Marsh RL (2005). Performance of guinea fowl *Numida meleagris* during jumping requires storage and release of elastic energy. *J. Exp. Biol.* 208:3293-3302. doi:10.1242/jeb.01764
- Hill AV (1950). The dimensions of animals and their muscular dynamics. *Sci. Prog.* 38:209-230.
- Hoerner SF (1965). *Fluid-Dynamic Drag*. Publicado por el autor, Midland Park (NJ).
- Hunter L (2011). *Wild Cats of the World*. Bloomsbury, Londres; vía San Diego Zoo Wildlife Alliance Library, ficha del tigre (*Panthera tigris*), características físicas: 80-100 cm a la cruz en machos y hembras, con datos de Hunter (2011) y Mazák (1981). https://ielc.libguides.com/sdzg/factsheets/tiger/characteristics
- Hutchinson JR et al. (2015). Musculoskeletal modelling of an ostrich (*Struthio camelus*) pelvic limb: influence of limb orientation on muscular capacity during locomotion. *PeerJ* 3:e1001 (tabla 2). doi:10.7717/peerj.1001
- ISO 2533:1975. *Standard Atmosphere*. Organización Internacional de Normalización (presión, temperatura y densidad de la atmósfera tipo).
- Iwasa M, Ueno T, Bradt RC (1981). Fracture toughness of quartz and sapphire single crystals at room temperature. *J. Soc. Mater. Sci. Japan* 30:1001-1004. doi:10.2472/jsms.30.1001
- Johnson DH (1997). Wing loading in 15 species of North American owls. En Duncan JR, Johnson DH, Nicholls TH (eds.), *Biology and Conservation of Owls of the Northern Hemisphere*, USDA Forest Service Gen. Tech. Rep. NC-190:553-561.
- just-auto. «Automotive glass: a window of opportunity» (ventanillas templadas de 4 mm en Europa y Japón y de 5 mm en EE. UU.; vía la unidad 1f).
- Kofron CP (1999). Attacks to humans and domestic animals by the southern cassowary (*Casuarius casuarius johnsonii*) in Queensland, Australia. *J. Zool.* 249:375-381. doi:10.1017/S0952836999009905
- Kofron CP (2003). Case histories of attacks by the southern cassowary in Queensland. *Mem. Queensl. Mus.* 49:339-342.
- Kofron CP, Chapman A (2006). Causes of mortality to the endangered southern cassowary *Casuarius casuarius johnsonii* in Queensland, Australia. *Pac. Conserv. Biol.* 12:175-179. doi:10.1071/PC060175
- König C, Weick F (2008). *Owls of the World* (2.ª ed.). Christopher Helm, Londres (medidas y rasgos de campo del búho real y la lechuza común).
- Kozłowski M, Zemła K, Kosmal M, Kopyłow O (2021). Experimental and FE study on impact strength of toughened glass: retrospective approach. *Materials* 14:7658. doi:10.3390/ma14247658
- Latch P (2007). *Recovery plan for the southern cassowary* Casuarius casuarius johnsonii. Environmental Protection Agency, Queensland.
- Li R, Lockley MG, Makovicky PJ, Matsukawa M, Norell MA, Harris JD, Liu M (2008). Behavioral and faunal implications of
  Early Cretaceous deinonychosaur trackways from China. Naturwissenschaften 95:185-191. doi:10.1007/s00114-007-0310-7
- Lindgren N, Kleiven S, Li X (2025). Understanding the role of covariates in numerical reconstructions of real-world vehicle-to-pedestrian collisions. arXiv:2504.15951 (revisión: el hueco bajo el capó de Fredriksson et al. 2007).
- Manning PL, Payne D, Pennicott J, Barrett PM, Ennos RA (2006). Dinosaur killer claws or climbing crampons? Biol. Lett.
  2:110-112. doi:10.1098/rsbl.2005.0395
- Martens LL, Piersanti SJ, Berger A, Kida NA, Deutsch AR, Bertok K, Humphries L, Lassiter A, Hartstone-Rose A (2023). The effects of onychectomy (declawing) on antebrachial myology across the full body size range of exotic species of Felidae. *Animals* 13:2462 (tablas 1 y 2). doi:10.3390/ani13152462
- Mathai V, Das A, Bailey JA, Breuer K (2021). Airflows inside passenger cars and implications for airborne disease transmission. *Sci. Adv.* 7:eabe0166. doi:10.1126/sciadv.abe0166
- Mattson DJ (2003). Foot loadings and pad and track widths of Yellowstone grizzly bears. *West. N. Am. Nat.* 63:72-79 (almohadilla de la mano: 12,5-14,5 cm en las hembras adultas, más de 14,5 en los machos).
- Mazák V (1981). *Panthera tigris*. *Mammalian Species* 152:1-8. doi:10.2307/3504004
- McKittrick J, Chen P-Y, Bodde SG, Yang W, Novitskaya EE, Meyers MA (2012). The structure, functions, and mechanical properties of keratin. *JOM* 64:449-468. doi:10.1007/s11837-012-0302-8
- Miller AH (1962). The history and significance of the fossil *Casuarius lydekkeri*. *Rec. Aust. Mus.* 25(10):235-238. doi:10.3853/j.0067-1975.25.1962.662 (diámetros de la tibia de *C. bennetti*)
- Naish D (2007). How dangerous are cassowaries, really? *Tetrapod Zoology* (reeditado en Scientific American Blogs).
- Nielsen JH, Schneider J, Kraus MA (2022). The in-plane expansion of fractured thermally pre-stressed glass panes. *Constr. Build. Mater.* 327:126849. doi:10.1016/j.conbuildmat.2022.126849 (el perfil del temple, la capa comprimida del 21 % del espesor y el tamaño de los trozos; vía la unidad 1f).
- Nippon Steel (2013). Yonemura S. et al. Advanced technologies related to simulation and evaluation for performance of automotive exterior panels. *Nippon Steel Technical Report* 103:11-17 (vía la unidad 1f: `dent.gd`).
- Norell MA, Makovicky PJ (1999). Important features of the dromaeosaurid skeleton II: information from newly collected
  specimens of Velociraptor mongoliensis. Am. Mus. Novit. 3282:1-45. hdl:2246/3025
- Ostrom JH (1969). Osteology of *Deinonychus antirrhopus*, an unusual theropod from the Lower Cretaceous of Montana. *Bull. Peabody Mus. Nat. Hist.* 30:1-165.
- Pajares A, Guiberteau F, Domínguez-Rodríguez A, Heuer AH (1988). Microhardness and fracture toughness anisotropy in cubic zirconium oxide single crystals. *J. Am. Ceram. Soc.* 71:C332-C333. doi:10.1111/j.1151-2916.1988.tb05933.x
- Pasitschniak-Arts M (1993). *Ursus arctos*. *Mammalian Species* 439:1-10. doi:10.2307/3504138
- Paul GS (1988). *Predatory Dinosaurs of the World*. Simon & Schuster, Nueva York.
- Paul GS (2016). *The Princeton Field Guide to Dinosaurs* (2.ª ed.). Princeton University Press.
- Pennycuick CJ, Obrecht HH, Fuller MR (1988). Empirical estimates of body drag of large waterfowl and raptors. *J. Exp. Biol.* 135:253-264. doi:10.1242/jeb.135.1.253
- Ponitz B, Schmitz A, Fischer D, Bleckmann H, Brücker C (2014). Diving-flight aerodynamics of a peregrine falcon (*Falco peregrinus*). *PLoS ONE* 9:e86506. doi:10.1371/journal.pone.0086506
- Portugal SJ, Murn CP, Sparkes EL, Daley MA (2016). The fast and forceful kicking strike of the secretary bird. *Curr. Biol.* 26:R58-R59. doi:10.1016/j.cub.2015.12.004
- Powell PL, Roy RR, Kanim P, Bello MA, Edgerton VR (1984). Predictability of skeletal muscle tension from architectural determinations in guinea pig hindlimbs. *J. Appl. Physiol.* 57:1715-1721. doi:10.1152/jappl.1984.57.6.1715
- Porsche AG (2018). *The new Porsche 911*, nota de prensa de la presentación del 992 (Newsroom de Porsche, noviembre de 2018): la piel exterior de la carrocería, entera de aluminio salvo los paragolpes delantero y trasero.
- Porsche AG (2019). *911 Carrera* (992), ficha técnica y nota de prensa del modelo de acceso (Newsroom de Porsche, julio de 2019): velocidad máxima 293 km/h, peso en vacío DIN 1505 kg, Cd 0,29, 4519 × 1852 × 1300 mm.
- Prillhofer R, Rank G, Berneder J, Antrekowitsch H, Uggowitzer PJ, Pogatscher S (2014). Property criteria for automotive Al-Mg-Si sheet alloys. *Materials* 7:5047-5068. doi:10.3390/ma7075047 (AA6016 tras hornear la pintura: Rm 273 MPa; vía docs/FISICA.md, apartado 14).
- Qian J, Daemen LL, Zhao Y (2005). Hardness and fracture toughness of moissanite. *Diamond Relat. Mater.* 14:1669-1672. doi:10.1016/j.diamond.2005.06.007
- Roderick WRT, Chin DD, Cutkosky MR, Lentink D (2019). Birds land reliably on complex surfaces by adapting their foot-surface interactions upon contact. *eLife* 8:e46415. doi:10.7554/eLife.46415
- Saber AS, Hassanin A (2014). Some morphological studies on the wing and foot of the southern cassowary (*Casuarius casuarius*). *J. Vet. Anat.* 7(2):17-32.
- SABIC (2024). *NORYL GTX™ resin GTX964*, región Europa, valores típicos, revisión 20241014 (PPE+PA con modificador de impacto para paneles exteriores de coche: resiliencia con entalla Charpy de 45 kJ/m² a 23 °C y 20 a −30 °C, ISO 179/1eA; Izod de 50 y 20 kJ/m², ISO 180/1A; fluencia 50 MPa, rotura al 50 %).
- Saint-Gobain Building Glass UK (2018). *Glass fundamentals 1B: the strength of glass* (resistencias características según EN 572-1 y EN 12150-1).
- Saint-Gobain Ceramics. *Hexoloy® SA Silicon Carbide*, ficha técnica (380 MPa a flexión en cuatro puntos, 3900 MPa a compresión, K_IC 4,6 MPa·√m, módulo de Weibull 10).
- Saint-Gobain Crystals. *Sapphire Products*, ficha técnica (1035 MPa a flexión paralela al eje c y 760 MPa perpendicular, a 25 °C).
- Sandvik. Metal duro H6F, ficha técnica (1775 HV30, 4000 MPa a flexión según ISO 3327, 7050 MPa a compresión).
- Sellers WI, Manning PL (2007). Estimating dinosaur maximum running speeds using evolutionary robotics. Proc. R. Soc. B
  274:2711-2716. doi:10.1098/rspb.2007.0846
- Sharma S, Jhala Y, Sawarkar VB (2003). Gender discrimination of tigers by using their pugmarks. *Wildl. Soc. Bull.* 31:258-264 (con McDougal 1999: almohadilla de la mano de más de 9,7 cm en los machos y ~9 en las hembras).
- Sheldahl RE, Klimas PC (1981). *Aerodynamic characteristics of seven symmetrical airfoil sections through 180-degree angle of attack for use in aerodynamic analysis of vertical axis wind turbines*. SAND80-2114, Sandia National Laboratories. doi:10.2172/6548367 (tabla 2: NACA 0012 de 0 a 180°).
- Sunquist M, Sunquist F (2002). *Wild Cats of the World*. University of Chicago Press, Chicago.
- Sustaita D, Hertel F (2010). In vivo bite and grip forces, morphology and prey-killing behavior of North American accipiters (Accipitridae) and falcons (Falconidae). *J. Exp. Biol.* 213:2617-2628. doi:10.1242/jeb.041731
- Tabor D (1951). *The Hardness of Metals*. Clarendon Press, Oxford (H ≈ 2,8-3·σ).
- Timoshenko SP, Gere JM (1997). *Mechanics of Materials* (4.ª ed.). PWS Publishing, Boston (cortante en una viga de sección circular maciza: τ máx = 4V/(3A)).
- Tucker VA (1990). Body drag, feather drag and interference drag of the mounting strut in a peregrine falcon, *Falco peregrinus*. *J. Exp. Biol.* 149:449-468. doi:10.1242/jeb.149.1.449
- Tucker VA, Heine C (1990). Aerodynamics of gliding flight in a Harris' hawk, *Parabuteo unicinctus*. *J. Exp. Biol.* 149:469-489. doi:10.1242/jeb.149.1.469
- Tucker VA, Cade TJ, Tucker AE (1998). Diving speeds and angles of a gyrfalcon (*Falco rusticolus*). *J. Exp. Biol.* 201:2061-2070. doi:10.1242/jeb.201.13.2061
- Turner AH, Makovicky PJ, Norell MA (2007). Feather quill knobs in the dinosaur *Velociraptor*. *Science* 317:1721. doi:10.1126/science.1145076
- Varney M, Passmore M, Wittmeier F, Kuthada T (2020). DrivAer Experimental Aerodynamic Dataset. Loughborough University. doi:10.17028/rd.lboro.12881213.v1 · artículo: Experimental data for the validation of numerical methods: DrivAer model. *Fluids* 5:236. doi:10.3390/fluids5040236
- Vodnick D (2006). Nanomechanical characterization of coatings. *PCI Magazine*, 1 de agosto (barniz de coche de poliuretano: 197-425 MPa por nanoindentación; vía docs/FISICA.md).
- voestalpine Stahl (2022). *Bake-hardening steels*, hoja técnica (HC180B, HC220B y HC260B; EN 10268): HC180B, Rm 290-360 MPa (vía docs/FISICA.md, apartado 14).
- Wachowicz J, Kruzel R, Bałaga Z, Ostrowska A, Dembiczak T (2023). Application of U-FAST technology in sintering of submicron WC-Co carbides. *Materials* 16:2450. doi:10.3390/ma16062450
- Wang et al. (2024). A comparative study on grasping-related muscles in five Accipitriformes species. *Anat. Rec.* 307:3344-3354. doi:10.1002/ar.25433
- Ward AB, Weigl PD, Conroy RM (2002). Functional morphology of raptor hindlimbs: implications for resource partitioning. *Auk* 119:1052-1063. doi:10.1642/0004-8038(2002)119[1052:FMORHI]2.0.CO;2
- Westcott DA, Reid KE (2002). Use of medetomidine for capture and restraint of cassowaries (*Casuarius casuarius*). *Aust. Vet. J.* 80:150-153. doi:10.1111/j.1751-0813.2002.tb11380.x
- Wierzbicki T (1999). Petalling of plates under explosive and impact loading. *Int. J. Impact Eng.* 22:935-954. doi:10.1016/S0734-743X(99)00028-7 (vía el motor: `sheetOf` / `petalEnergy`).
- Wong JY (2008). *Theory of Ground Vehicles* (4.ª ed.). Wiley.
- Xirouchakis SM, Poulakakis N (2008). Biometrics, sexual dimorphism and gender determination of Griffon Vultures *Gyps fulvus* from Crete. *Ardea* 96:91-98. doi:10.5253/078.096.0110
- Young WC, Budynas RG (2002). *Roark's Formulas for Stress and Strain* (7.ª ed.). McGraw-Hill (placas circulares con carga concentrada; vía FISICA.md §15).
- Normas: ISO 6506-1 (Brinell: bola de metal duro, hasta 29,42 kN) e ISO 6508-2 (Rockwell: cono de diamante de 120° y radio de 0,2 mm, 1471 N en HRC); ASTM B406 e ISO 3327 (rotura transversal del metal duro); EN 572-1 (vidrio sodocálcico: resistencia a flexión del recocido) y EN 12150-1 (vidrio templado: 120 MPa); JIS R 3212 y Reglamento CEPE/ONU n.º 43 (ensayo de penetración del laminado con bola de 2,26 kg y recuento de trozos de los templados: de 40 a 400 por cada 5 × 5 cm); FMVSS 214 (49 CFR 571.214, S7.1: la puerta se mide en sus primeros 152 mm de aplastamiento) y FMVSS 216 (49 CFR 571.216, S5: el techo no puede bajar más de 127 mm); ISO 179-1 e ISO 180 (resiliencia Charpy e Izod de los plásticos); EN 1993-1-3:2006 (Eurocódigo 3, parte 1-3, perfiles y chapas conformados en frío; tabla 8.4: aplastamiento de una chapa fina contra un tornillo, 2,5·α_b·k_t·f_u·d·t/γ_M2, con k_t = (0,8·t + 1,5)/2,5 de 0,75 a 1,25 mm y 1 por encima) y EN 1993-1-8:2005 (parte 1-8, uniones; tabla 3.4: la misma forma en chapa gruesa, k_1·α_b·f_u·d·t/γ_M2, con k_1 ≤ 2,5 y α_b ≤ 1).

## 19. El deportivo y los animales de la cetrería en el coche (unidad 4r)

Petición 51 de Eric: «poner los animales ya recreados del simulador de cetrería y garras 3D en los del coche, y añadir un
modelo de coche deportivo que vaya más allá de 230 km/h». Lo primero es solo dibujo; lo segundo trae datos.

### 19.1 El deportivo: un segundo coche con su velocidad máxima

- **Qué coche:** el Porsche 911 Carrera de la generación 992 (2019), el deportivo de serie con la ficha más completa.
  Entrada `deportivo` del catálogo 2.0 (`core/lab/sports_car.gd`, en `Catalog.V2_TARGETS` y en `MovingCarState.CARS`); el
  id no está en la 1.x y `data.gd` no cambia.
- **El tope del deslizador por coche** (`MovingCar.slider_max_kmh(target)`): la velocidad máxima del coche si la trae
  (`vmax_kmh`, 293 km/h) y si no, la de un turismo de serie (`SLIDER_MAX_KMH`, 230 km/h, como siempre). El escenario la
  lleva en `vmaxKmh` y de ella salen el final de la curva de la gráfica (`curve`, 61 puntos de 0 al tope), `detach().beyond`
  y el veredicto «AGUANTA A … km/h». Al volver del deportivo al turismo, la velocidad baja a 230 si iba más deprisa.
- **La resistencia del coche** (`carDragN` de `at_speed`, solo para comparar con la del animal): ½·ρ·v²·Cd·A con el Cd·A
  del coche elegido (`MovingCar.car_cda`): el del deportivo (0,29 × 2,02 = 0,586 m²) o el del coche de referencia de
  siempre (0,309 × 2,176 = 0,672 m²). A la misma velocidad, el deportivo resiste un 13 % menos.
- **El aire sobre el animal no cambia:** el Cp por zona es el del turismo, el del DrivAer (media de las tres carrocerías). El
  deportivo es un fastback, y el fastback del mismo ensayo da −0,47 en el techo, dentro de la banda de −0,64 a −0,30 de la
  zona: se marca como estimación y no se añade otro juego de Cp. Por eso el despegue de un animal sale igual en los dos
  coches; lo que cambia es hasta dónde llega el deslizador. Con el deportivo se ve soltarse a los que en el turismo se
  quedaban en «aguanta a 230 km/h»: la arpía en el capó (~254 km/h), el velocirraptor de verdad en el techo (~246) o el oso
  de pie en el techo (~289, el caso 21 de `demo_coche`).
- **La chapa y la pintura:** las del coche de aluminio (`Data.CAR_BODIES.aluminio`, AA6016 de 1,0 mm, con la misma
  pintura), porque la piel exterior del 992 es de aluminio salvo los paragolpes (Porsche 2018). Es el caso medido más
  parecido del catálogo, no una medición de la chapa del 911, y la ficha lo dice. Las marcas, las abolladuras y el golpe
  salen por eso como en el coche de aluminio.
- **La masa** (1505 kg) es solo informativa: el golpe usa la masa del coche de la tarjeta, como con los demás.
- **El dibujo** (`car3d/`): la carrocería del turismo escalada con las medidas de la ficha (el mismo largo, un 10 % más baja
  y un 3 % más ancha: `draw_scale`), un cupé de dos puertas (`draw_doors`), en azul liso, con los marcos negros y las pinzas rojas. Los puntos de la física no
  se mueven: la vista lleva las zonas a la carrocería escalada (`MovingCarView.car_point`, `half_w` y `zone_z`). Las ruedas
  no se escalan. Es solo dibujo.

### 19.2 Los cuerpos de la cetrería en el coche

- `app/lab/animals/hd3d.gd` construye el cuerpo de alta definición de la cetrería (`care_body.gd` y `body_*.gd`, unidades
  5i y 5n) con sus patas (`care_paw.gd`, 5h), de pie o agazapado en lugar de tumbado, y con las garras de la biblioteca de
  materiales del material elegido. La misma API que `Animal3D`, así que la vista no los distingue
  (`MovingCarView.uses_hd`).
- **Quién lo usa:** los animales quietos encima del coche: el tigre y el oso, las seis rapaces con las alas plegadas y los
  dos velocirraptores. El golpe (el salto del tigre y del oso, el vuelo de las rapaces, el salto de los velocirraptores) y las
  alas abiertas siguen con los modelos de la 4l, que se mueven: los cuerpos de la cetrería son rígidos, y el tigre se
  acercaba a la puerta agazapado, resbalando, y se metía en la abolladura. El casuario no tiene cuerpo de cetrería y se
  queda con el suyo.
- **La postura** (dibujo): la pata de la cetrería se dobla por la muñeca o el tobillo (`HdAnimal.bend`) y el cuerpo se hace
  alrededor de los anclajes con la pose del coche (`pose` en `body_*.gd`: sin la mesa, el tronco entre las patas, el lomo
  a la altura de la postura). Sin pose, la cetrería se ve como siempre.
- **Sin la clínica:** ni tela, ni toalla, ni capucha, ni mascarilla, ni pulsioxímetro (`props: false` en
  `CareBody.build`), y con los ojos abiertos (la sujeción «libre»).
- **El tamaño** es el del estado (`MovingCar.BODIES`, alto y largo), como con los modelos de la 4l: el cuerpo de la
  cetrería se escala a su largo.
- **Las garras de metal reflejan la carretera:** el cielo del coche en marcha es el de un atardecer, oscuro por el cenit,
  y sin sonda de reflexión el acero salía gris y el oro apagado. La copia del material de cada animal sube el entorno
  dibujado de la biblioteca (`METAL_ENV_ROAD`, solo dibujo) en los metales; la queratina y las gemas, no.

### 19.3 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Velocidad máxima del deportivo: 293 km/h | Porsche AG (2019), ficha del 911 Carrera (992) | primaria (ficha del fabricante) |
| Peso en vacío DIN: 1505 kg (solo informativo) | Porsche AG (2019) | primaria |
| Cd: 0,29 | Porsche AG (2019) | primaria |
| Largo, ancho y alto: 4519, 1852 y 1300 mm (solo el dibujo) | Porsche AG (2019) | primaria |
| Área frontal: 2,02 m² | 1,852 × 1,300 m por el factor de relleno del DrivAer (2,176 m² sobre 1,82 × 1,42 m: 0,84) | estimación |
| Chapa: aluminio AA6016 de 1,0 mm, con la pintura de los demás coches | Porsche AG (2018) (piel de aluminio) y `Data.CAR_BODIES.aluminio` | caso medido más parecido |
| Cp por zona: el del turismo (DrivAer, media de las tres carrocerías) | Varney et al. (2020): el fastback da −0,47 en el techo, dentro de la banda | estimación |
| Tope del turismo: 230 km/h | la velocidad máxima de un turismo de serie (Eric) | no es física: el despegue se busca hasta 400 km/h |

### 19.4 Tests

- `godot/tests/lab/test_deportivo.gd`: los datos con su fuente y su calidad; el catálogo 2.0 y `CARS`; el tope del
  deslizador (230 en los cuatro coches de la 1.x, 293 en el deportivo) y que la velocidad baja al volver al turismo; la
  curva de la gráfica acaba en el tope; el veredicto «aguanta a 230» pasa a «se suelta» en el deportivo en tres casos
  (arpía, oso y velocirraptor); más velocidad nunca da menos fuerza del aire ni menos resistencia del coche; y los coches
  de antes no cambian (el mismo despegue, la misma resistencia y la misma gráfica con o sin las claves nuevas).
- `godot/tests/app/test_coche_animales_hd.gd`: cada animal con cuerpo de cetrería, en cada postura del coche, y el casuario
  con el suyo; sin lo de la clínica; las garras a la altura de la chapa, una de la biblioteca por dedo; el cuerpo, una vez
  por especie, postura y calidad (más ligero en el teléfono); y los metales con el reflejo subido y la queratina no.
- El golden 2.0 del banco no cambia (la entrada nueva no está en sus escenarios) y los escenarios de referencia del coche
  en marcha, tampoco.

### 19.5 Qué no predice

- **El aire propio del deportivo:** sin un Cp medido sobre el 911, el animal siente el mismo aire que en el turismo; un
  coche más bajo y con otra zaga movería algo el Cp del techo y del maletero.
- **La chapa del 911:** se toma la del coche de aluminio del catálogo; ni su espesor ni su aleación están medidos aquí.
- **La forma:** el deportivo del dibujo es el turismo más bajo y más ancho, sin una zaga fastback propia.

## 20. El coche en curva: la fuerza G que cambia de lado (unidad 4t)

Petición 63 de Eric (17-10-2026): «añadir un coche que gira en curvas, y cambia radicalmente el lado de la fuerza G». Hasta
ahora el coche iba en recta y el animal del techo solo tenía que aguantar el viento (hacia atrás); la maniobra «Curva» era
una aceleración lateral fija. En una curva de verdad la aceleración lateral sale de la velocidad y del radio, y en una curva
en S cambia de lado.

### 20.1 La aceleración lateral y su lado

- **a = v²/R**, hacia el centro de la curva (cinemática del movimiento circular, exacta). En el coche, el animal la siente
  como una fuerza de inercia m·a hacia fuera. A 90 km/h (25 m/s) en la curva de 130 m: 4,8 m/s², 0,49 g. A 110 km/h en
  120 m: 0,79 g.
- **El lado:** el eje lateral del modelo (el del viento lateral, +y) es la derecha del coche. La «Curva» gira a la
  izquierda y empuja hacia la derecha; la «Curva en S», primero a la izquierda (empuja a la derecha) y luego a la derecha
  (empuja a la izquierda).
- **Cómo entra en el agarre:** la aceleración lateral de la curva sustituye a la de la maniobra en la componente lateral del
  equilibrio de siempre (`MovingCar._eval`: T_lat = D_lat + m·a_lat, que se suma como vector a la tangencial a lo largo, con
  el viento hacia atrás, y contra la fricción del peso más el anclaje). No hay física nueva del agarre: el animal aguanta o
  se suelta con el mismo modelo. Con viento lateral, una curva que empuja hacia el mismo lado que el viento suma y la del
  otro lado resta: en la S el lado peor es el del viento.
- **Sin peralte:** la curva va plana, el peor caso para el animal. La norma cuenta con un peralte de hasta el 7-8 % que se
  come unos 0,07-0,08 g de la aceleración que se siente (se dice en el «¿sabías que…?»).

### 20.2 Los radios de la norma y la glorieta

- **Radios mínimos por velocidad de proyecto** (Norma 3.1-IC Trazado, Orden FOM/273/2016, tabla 4.4): 50 m a 40 km/h, 85
  a 50, 130 a 60, 190 a 70, 265 a 80, 350 a 90, 450 a 100, 550 a 110, 700 a 120, 850 a 130 y 1050 a 140. Salen de
  V² = 127·R·(f_t + p/100), con el rozamiento transversal movilizado de la tabla 4.3 (0,180 a 40 km/h … 0,069 a 140) y el
  peralte máximo (7 % en las carreteras convencionales, 8 % en autovías y autopistas). Hasta 90 km/h se toma el grupo 3
  (convencionales); de 100 a 120, el 2; 130 y 140, el 1.
- **La glorieta:** el diámetro exterior de la calzada anular de una glorieta urbana de un carril se procura de 30 a 40 m
  (3.1-IC, 10.6). El coche va por el centro del carril, unos 2-3 m por dentro del borde: R ≈ 15 m (de 12 a 18), estimación.
- **El deslizador del radio** va de 15 a 1050 m en escala logarítmica, con los radios de la norma de 40 a 120 km/h marcados
  bajo la pista y en píldoras. La velocidad de proyecto de un radio cualquiera es la mayor de la tabla cuyo radio mínimo
  cabe en él; por debajo de 50 m se extrapola con la misma expresión (f_t de 40 km/h y 7 %): ~22 km/h en la glorieta.

### 20.3 El tope del coche: derrapa, nunca un número imposible

- **Lo que dan los neumáticos de lado** antes de derrapar, en asfalto seco: 0,85 g (de 0,8 a 0,9) en un turismo, la
  adherencia de pico de Wong (2008), estimación; 1,0 g (de 0,9 a 1,1) en el deportivo, sin una prueba de patinaje publicada
  del Carrera: el caso medido más parecido es su versión de circuito, el 911 GT3 (992), 1,16 g en la pista de 300 pies de
  Car and Driver con neumáticos semislick; el de calle, por debajo (estimación).
- **Si la curva pide más:** a más de v = √(μ·g·R) el coche no gira: derrapa. El animal no siente más que ese tope (los
  neumáticos no dan más; el coche se va hacia fuera por un radio mayor), así que la aceleración lateral nunca pasa de él.
  En la curva de 130 m el turismo derrapa a ~119 km/h (118,5; de ~115 a ~122 según el agarre); en la glorieta, a ~40.
- **El veredicto** (`CarCurve.verdict`):
  - si el animal aguanta hasta que el coche derrapa: «EL COCHE DERRAPA ANTES: A ~119 km/h», con la banda del agarre del
    coche, y el porqué dice que la curva ya no puede tirar más y hasta dónde aguantaría con el coche derrapando. Pasa con los animales bien agarrados (las rapaces en el limpiaparabrisas, las barras o el retrovisor; el tigre
    tumbado en el techo; cualquiera con garras clavadas);
  - si se suelta de lado antes: «RESBALA HACIA FUERA A ~67 km/h», con cuántos g tira y hasta dónde giraría el coche (la
    lechuza en el techo en la curva de 50 m; el coche derraparía a ~74);
  - en lo demás, el veredicto de siempre con la aceleración lateral de la curva (en el parabrisas, por ejemplo, «resbala
    cuesta abajo»: el peso a lo largo del vidrio inclinado pesa más que la curva).

### 20.4 La curva en S y el tirón

- **La forma** (3.1-IC, 4.4): recta, clotoide de entrada (de la recta a 1/R), curva a la izquierda, clotoide de cambio (de
  +1/R a −1/R, el doble de larga), curva a la derecha, clotoide de salida y recta. La curvatura cambia linealmente a lo largo
  de cada clotoide.
- **La longitud de las clotoides** es la que pide la norma para la variación de la aceleración centrífuga J a la velocidad de
  proyecto (4.4.3.1 y tabla 4.6: 0,5 m/s³ por debajo de 80 km/h y 0,4 desde 80), con peralte 0: L = V³/(46,656·J·R). En la
  de 130 m (60 km/h): 71 m de entrada y 142 m de cambio.
- **El tirón** (m/s³), el ritmo de cambio de la aceleración lateral: v³·dκ/ds. A la velocidad de proyecto es el de la norma;
  a otra velocidad, J·(v/v_p)³: la S de 130 m a 95 km/h tira con 0,55 g de cada lado y cambia de lado con ~2 m/s³, cuatro
  veces lo que admite la norma a 60 km/h. Con el coche derrapando, la aceleración se queda en el tope y el tirón es cero.
- **Solo dibujo:** los tramos circulares duran 2 s y las rectas de antes y de después 1 s a la velocidad de proyecto (la
  aceleración de pico y el tirón no dependen de ellos). En la pantalla, la S se enseña en 8 s, dure lo que dure de verdad
  (la de 130 m a 95 km/h, 15 s), y la nota del medidor lo dice.

### 20.5 Las garras de cada lado y las marcas

- **Reparto de la carga** (`CarCurve.side_shares`): la fuerza lateral F_lat a la altura h del centro de masas, con los
  apoyos a ±b, pasa ΔN = F_lat·h/(2·b) del lado de dentro al de fuera (estática de un sólido sobre dos apoyos). La parte del
  lado de fuera es ½ + ½·(F_lat/R)·(h/b). La relación h/b ≈ 1 (agazapado; banda 0,5-1,5) es una **suposición**, sin
  medición publicada de un animal agarrado a un coche en curva: va marcada como estimación y se enseña como tal.
- **El veredicto no depende de ese reparto** mientras las garras de dentro sigan apoyadas: la fricción total es μ por la
  normal total. Lo que dice es qué garras cargan: en la S, el pico pasa a las del lado nuevo.
- **Las marcas se tuercen hacia fuera:** la fuerza en el contacto apunta a atan2(T_lat, T_long) desde «hacia atrás»
  (`markDeg`), y es la dirección en la que la vista tuerce los desgarros del animal asustado en los paneles de arriba (los
  de la 4s, tal como estén; en un costado la fuerza lateral empuja contra el panel o lo separa, no a lo largo).

### 20.6 En pantalla

- **Tarjeta:** bajo la velocidad, el selector «Recta · Curva · Curva en S», el deslizador del radio («130 m · proyecto
  60 km/h») con los valores de la norma marcados y en píldoras, y la frase de la curva a esa velocidad («En la curva de
  130 m a 90 km/h tira hacia fuera con 0.49 g (4.8 m/s²), hacia la derecha. Sumada al viento, para sujetarse hacen falta
  … y sus garras dan …: el tigre aguanta, y las garras de la derecha cargan el 65 % del peso (estimación).»). Las lecturas
  «Hacia fuera de la curva» y «Garras del lado de fuera», las fuentes y tres datos de «¿sabías que…?». Elegir una maniobra
  con curva vuelve a la recta, y elegir una curva quita la maniobra con curva: no se suman. Los experimentos van en recta.
- **El golpe en curva:** el selector también sale en el golpe (la curva; la S es del animal quieto encima). La fuerza del
  golpe es la de siempre: la que da la velocidad del animal respecto al coche (`impact`, en recta). Lo que cambia es el
  camino visto desde el coche, que gira a ω = a/v (`CarCurve.yaw_rate`): el animal corre en línea recta por la carretera y
  el coche sigue su círculo, así que, desde el coche, el camino de los últimos 2,2 m se tuerce (`CarCurve.approach_offsets`,
  cinemática exacta; con ω = 0, nada). En la curva de 50 m a 50 km/h, el coche gira ~16°/s. Con la cámara de persecución el
  animal llega por el costado en 3D, y su camino de los últimos 9 m se dibuja a puntos un momento, con el rótulo «camino
  visto desde el coche que gira (dibujo)»: en 2,2 m se tuerce unos centímetros, en 9 m ya se ve. Los trocitos de unas garras
  que se mellan se proyectan con la cámara que se ve.
- **Vista 3D:**
  - el medidor de fuerza G (`car3d/g_meter.gd`): visto desde arriba, con el morro arriba, la flecha de la fuerza por unidad
    de peso (de lado y a lo largo), el círculo verde de lo que aguantan las garras (si la flecha sale, se suelta) y el
    discontinuo del tope del coche; en la S, con su estela, se ve cambiar de lado;
  - el plano de la carretera (`car3d/road_map.gd`): la curva o la S desde arriba y el coche que la recorre;
  - **la vista de persecución** (por defecto en curva; la de lado queda a un clic, para las garras): una cámara detrás del
    coche, sobre la propia carretera, algo a su derecha y por encima, que sigue la curva. La carretera larga (de 40 m por
    detrás a 260 m por delante, dos carriles de 3,5 m con bordillos rojos y blancos y el arcén) va al radio de verdad, así
    que se ve curvarse delante del coche y, en la S, cambiar de sentido; el coche se ve girado respecto a la cámara (la
    cámara va 7 m por detrás en la curva) y con las ruedas delanteras giradas (Ackermann, atan(batalla/R), por 3 para que
    se vea: dibujo). El coche lleva ya las cuatro ruedas (antes solo tenía las del lado que se veía);
  - la carretera de la vista de lado (`car3d/road_curve.gd` y `road_curve.gdshader`): la tira de la carretera se lleva a lo
    largo del eje de la curva con su rumbo, así que conserva el ancho aunque dé media vuelta; de perfil, más cerrada que la
    de verdad para que se lea (dibujo);
  - el balanceo de la carrocería, 5° por g hacia fuera (dibujo: sin medición del coche del dibujo, y la física no lo usa);
    y el animal, que se inclina hacia dentro y, si se suelta, sale por el lado de fuera;
  - en el teléfono, en curva, la vista 3D crece hasta el 42 % del alto de la pantalla (~350 px en uno de 390 × 844, en lugar
    de ~150): la curva y el coche que gira llenan la imagen, con el medidor y el plano arriba, en el cielo. La cámara de
    persecución cercana (4,6 m detrás, 2,0 m arriba, 46°) queda para una vista baja y ancha; el arcén, con tierra y manchas
    de hierba seca (dibujo);
  - en la S, al cruzar la fuerza el cero en la clotoide de cambio, un destello: el rótulo «¡Cambia de lado! Ahora tira
    hacia la izquierda» y un anillo dorado en el medidor, que se apagan en ~1 s.
- **Demo:** `demo_curvas.tscn` (cinco casos: recta, la curva de 130 m acelerando hasta derrapar, la S, la lechuza que
  resbala en la de 50 m y el oso de pie en el deportivo en la S de 265 m).

### 20.7 Guía de integración

- `core/lab/car_curve.gd` (`CarCurve`), funciones puras: `lateral_ms2`, `demand_g`, `skid_kmh`, `felt_ms2`, `road(r, target)`,
  `design_kmh`, `jerk_norm`, `grip_of`, `s_kappa`, `s_at`, `s_profile`, `s_jerk_ms3`, `path`, `at_speed(scen, v, r, grip, side)`
  y `at_lateral` (las de `MovingCar.at_speed` más el campo `curve`: `rM`, `side`, `demandMs2`, `latMs2`, `latG`, `skids`,
  `gripG`, `skidKmh`, `tyN`, `ttN`, `shares`, `markDeg` y `meter`), `detach(scen, r, grip, side)` y `detach_s` (lo de
  `MovingCar.detach` más `skidKmh`, su banda y `skidsFirst`), `chart`, `verdict`, `now_txt` y `why_txt`.
- `MovingCarState`: `road`, `radius_m`, `set_road`, `set_radius`, `curve_on`, `curve_road`, `curve_grip`, `curve_now`,
  `curve_text`, `meter`, `meter_note`, `road_note`, `radius_text`, `s_frame(t)` y `s_duration`. En recta no se llama a nada de
  la curva: todo sale al bit como antes (lo vigila un test).
- **Coste** (medido en la nube con el tigre y la tarjeta en el árbol, con otras tres calles trabajando a la vez: los números
  absolutos bailan, las diferencias no tanto): `at_speed` en curva cuesta el doble que en recta (una copia del escenario y
  una evaluación más: ~150 frente a ~70 µs); el refresco de la tarjeta al arrastrar la velocidad pasa de ~1,6 ms en recta a
  ~2,1 ms en curva y ~2,3 ms en la S (la frase de la curva, que se vuelve a componer en cada fotograma, como la de «A 90 km/h»,
  y el medidor); el dibujo de la vista, de ~0,2 a ~0,3 ms. Mover el radio rehace el despegue y la gráfica sin setup
  (~1,5-2 ms, como un setup). En recta, lo de siempre: no se llama a nada de la curva.

### 20.8 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| a = v²/R | cinemática del movimiento circular | exacta |
| Radios mínimos: 50 m a 40 km/h … 1050 m a 140 km/h | Norma 3.1-IC (2016), tabla 4.4 | norma |
| f_t de 40 km/h (0,180) y peralte del grupo 3 (7 %), para extrapolar bajo 50 m | Norma 3.1-IC, tablas 4.3 y 4.4 | norma (extrapolada: estimación) |
| J = 0,5 m/s³ (< 80 km/h) y 0,4 (≥ 80); L = V³/(46,656·J·R) con p = 0 | Norma 3.1-IC, 4.4.3.1 y tabla 4.6 | norma |
| Glorieta urbana: R ≈ 15 m (12-18) | Norma 3.1-IC, 10.6 (30-40 m de diámetro exterior), menos medio carril | estimación |
| Tope lateral del turismo: 0,85 g (0,8-0,9) | Wong (2008), adherencia de pico en asfalto seco | estimación |
| Tope lateral del deportivo: 1,0 g (0,9-1,1) | caso parecido: 911 GT3 (992), 1,16 g (Car and Driver 2021, vía Stuttcars 2022) | estimación |
| Reparto entre lados: h/b ≈ 1 (0,5-1,5) | estática de un sólido sobre dos apoyos; h/b, suposición sin medición | estimación |
| Tramos circulares de 2 s y rectas de 1 s en la S; la S en 8 s en pantalla | — | dibujo |
| Balanceo 5°/g (tope 6°) y el animal 14°/g hacia dentro (tope 16°) | — | dibujo |
| Curva dibujada 6 veces más cerrada (tope 1/14 m) y la S comprimida ×6 a lo largo (vista de lado) | — | dibujo |
| Vista de persecución: la carretera al radio de verdad (tope 1/12 m), cámara 4,9 m detrás, 1,4 m a la derecha y 2,45 m arriba, mirando al techo (unidad 4u: más cerca, para ver al animal) | — | dibujo |
| Giro de las ruedas: atan(2,745 m/R) × 3, tope 30° | Ackermann con la batalla del coche del dibujo | dibujo |

### 20.9 Tests

`godot/tests/lab/test_car_curve.gd`: a = v²/R exacta (y 5 m/s² exactos a 90 km/h en 125 m); más velocidad o menos radio
nunca dan menos aceleración, ni lo sentido pasa del tope; con menos radio (o en curva frente a la recta) el margen nunca
sube y el despegue nunca es más tarde, en siete animales y zonas; con viento lateral, el lado peor es el del viento; en
recta, todo al bit (también tras pasar por la S y volver); si pide más que el coche, «derrapa» y nunca más que su tope; en la
S cambia el signo, el centro del cambio no tiene aceleración lateral y el pico de carga cae en las garras del lado nuevo
(con las marcas torcidas hacia fuera de cada curva); el tirón de la norma a la velocidad de proyecto y ocho veces al doble;
los radios de la tabla 4.4 y el deslizador del radio; cada dato con fuente y calidad; y el estado (la frase, las lecturas,
las fuentes, el medidor, que maniobra y curva no se suman y que los experimentos van en recta).
`godot/tests/app/test_car_curve_ui.gd`: la tarjeta (los controles, el radio, la frase) y la vista (el medidor, el plano, la
carretera en curva, que la recta vuelve a la carretera de siempre y que en cada fotograma de la S no se crea nada).

### 20.10 Qué no predice

- **El peralte:** la curva va plana. Con el peralte de la norma, el animal sentiría ~0,07-0,08 g menos de lado y algo más
  de normal (más fricción).
- **La dinámica del animal:** el modelo es cuasiestático, como el de la recta. El tirón de la S no añade fuerza; un animal
  real, con su inercia y sus patas, se balancearía y podría soltarse antes con un cambio brusco.
- **El coche que derrapa:** pasado el tope, se toma que los neumáticos siguen dando lo mismo de lado (el coche se va por un
  radio mayor); no se simula el trompo ni el subviraje.
- **El reparto entre las garras** depende de h/b, que no está medido; el veredicto no depende de él mientras las de dentro
  apoyen.
- **Las marcas torcidas** son las del instante que se ve (en la S, las del pico del lado peor), no las de toda la
  trayectoria: un desgarro real que dure la S entera dejaría una marca en ese.
- **El golpe en curva:** su fuerza es la de la recta. El giro del coche cambia un poco la velocidad del punto del golpe
  (ω·r, con r de unos metros: decenas de cm/s) y el camino; no se cuenta en la energía.

## 21. Las garras y las marcas de cerca (unidad 4s, petición de Eric del 13-10-2026)

Lo de esta sección es **dibujo** salvo lo que se dice: la física de las marcas y de la rotura sigue siendo la de §2.7 y la
de `car_speed_marks.gd`; aquí solo se enseña de cerca.

### 21.1 El primer plano de las garras

- `app/lab/car3d/claw_closeup.gd`: una segunda cámara, en perspectiva (28° de campo), que comparte el mundo 3D de la vista.
  Quieto encima apunta a las garras que dejan las marcas (las puntas de `contact_tips`, de la pose del animal), desde
  delante de la pata y 22° por encima del panel (las garras salen por delante de los dedos); en un costado mira más de
  frente (50°) y nunca se mete dentro de la carrocería en una abolladura. En el golpe enseña el daño (las marcas van al punto
  del golpe que da el motor) y ve las garras sin el cuerpo (capa `CarScene.CLAW_LAYER`), porque el cuerpo se le pone
  delante.
- Lo que se ve, en el lado corto: 1,9 veces el largo de la garra del catálogo (`reach`), entre 3,5 y 16 cm, con su barra de
  escala en mm reales y el aumento frente a la vista del coche.
- Dos tamaños: una ventana dentro de la vista del coche (arriba, en la esquina contraria a la lupa del daño; en curva, abajo
  a la derecha; en un teléfono en curva no cabe) y «Garras de cerca» en la tarjeta, que la pone en la vista entera.
- El texto (`MovingCarState.closeup_caption`): el material y el radio de la punta del motor (`claw_tip_um`:
  `Physics.resolve_tool`, √(área/π) de la ficha, o la punta afilada de `ClawSharpness`), y lo que hacen a la velocidad del
  deslizador (`CarSpeedMarks.marks_txt`) o en el golpe, con las garras melladas, partidas o dobladas.

### 21.2 Las marcas en alta calidad

Las del material del coche (`car_damage.gdshaderinc`, unidad 4s: la parábola del surco con su hondura y su ancho del motor,
las capas en terrazas, el labio con 1 − f_ab, la punzada en cono, los pétalos, la oclusión y el metal recién cortado que
brilla), ahora vistas de cerca: crecen con la velocidad del deslizador porque los números del motor crecen. En curva se
tuercen hacia fuera (unidad 4t, `_twist_hold_marks`, sobre las marcas de la 4s).

### 21.3 Los materiales del selector y lo que se veía mal

- Cada píldora de «Material de las garras» lleva su muestra (`claw_swatch.gd`) con el color de la biblioteca común
  (`claw_optics.gd`: F0 de cada metal, tinte de cada gema, albedo de la cerámica, la queratina de la especie). Los
  materiales son los de la cetrería y la reforja que tienen física en el coche: `Catalog.INLAYS` (los de `Data.INLAYS` más
  el rubí y la alúmina de `ForgeData.NEW_MATERIALS`).
- Quieto encima, el tigre se agarra con las garras fuera (sus marcas lo dicen); el tigre, el oso y los velocirraptores se
  agazapan y agachan la cabeza con el viento y con la carga (hasta un 12 % de su alto), se balancean un poco, y al soltarse
  agitan las patas en lugar de irse de una pieza (`hd3d.gd`); las puntas de las garras quedan sobre la chapa curva, no
  dentro, y la rapaz posada se echa hacia delante lo justo para que la cola no atraviese el techo.
- El render 3D va a los píxeles de verdad de la pantalla (×2-×3 en un teléfono, con un tope de 1,6 millones de píxeles): con
  el 0,7 de antes y la escala de la pantalla, el animal se dibujaba a una cuarta parte de su resolución en el teléfono.

### 21.4 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Radio de la punta (µm) del texto | `Physics.resolve_tool` (√(área/π) de la ficha; afilada, `ClawSharpness.sharpen`) | el del motor |
| Campo del primer plano: 1,9 × largo, 3,5-16 cm | — | dibujo |
| Ángulos de la cámara (28°, 22°, 50°, 38°) | — | dibujo |
| Lo que se agazapa (12 % del alto) y agacha la cabeza (0,35 rad) | — | dibujo |
| Inclinación de la rapaz para sacar la cola | la caja del cuerpo de la cetrería | dibujo |
| Colores de las muestras | `claw_optics.gd` (datos ópticos con fuente) | los de la biblioteca |

### 21.5 Tests

`tests/app/test_coche_primer_plano.gd`: la ventana apunta a las puntas que tocan, con la cámara fuera de la chapa; «Garras de
cerca» en la vista entera, sin el render del coche; el render a los píxeles de verdad con su tope; en cada fotograma no se
crea nada; las garras en su capa y la lupa sin ellas; ninguna punta dentro del techo y la cola de la rapaz fuera; la punta
del texto, la del motor (y más fina afilada); las muestras de cada material.

### 21.6 Qué no hace

- En el golpe, las garras del dibujo del salto no caen donde el motor pone las marcas: el primer plano enseña el daño.
- El deportivo sigue siendo el turismo escalado (la zaga del 911 está pendiente).
- Las gemas se ven oscuras de cerca cuando detrás hay un hueco oscuro (refractan lo que tienen detrás).

## 22. Qué capas atraviesa cada marca y si raja o abre el panel (unidad 4s, petición de Eric del 17-10-2026)

«Las marcas y rajadas de garras de cada animal tienen que verse visibles, ver qué capas de la chapa del coche atraviesan, y si
pueden rasgar y abrir la puerta o techo entero, dependiendo del tipo de garra que lleve cada animal, y la fuerza aplicada.»

`core/lab/car_tear.gd` (`CarTear`) no calcula marcas nuevas: toma las del motor (quieto encima, `CarSpeedMarks.at` a la
velocidad del deslizador; en el golpe, las de `impact()`) y decide el escalón, en este orden.

### 22.1 Las capas

Las de `Data.car_layers` (barniz 45 µm, color 15, imprimación 25, anticorrosivo o promotor 25 y la carrocería: acero de horno
de 0,7 mm, acero dulce de 0,9, aluminio de 1,0 o plástico de 2,5). Cada capa queda «cortada» (la marca la pasa entera),
«marcada» (llega a ella), «intacta» o «atravesada». La queratina, más blanda que el acero (§2.7), atraviesa la pintura y se
queda en la chapa sin marcarla (menos de 0,5 µm dentro).

### 22.2 Marca, perfora, raja

- **Marca:** no atraviesa el panel.
- **Perfora:** la punta asoma por detrás (la punción del motor: indentación hasta romper la chapa y pétalos de Wierzbicki
  1999), o las garras atraviesan la chapa pero la raja no corre.
- **Raja X cm:** cada garra abre una grieta de todo el espesor y pide F = R·t. En la chapa, R es su trabajo esencial de
  fractura en tensión plana, R ≈ σ0·t (con la σ0 de Wierzbicki que ya usa el motor): ~185 kJ/m² en el acero de horno de
  0,7 mm (banda ×0,5 a ×2; estimación con el caso medido más parecido: Cotterell y Reddel 1977; Atkins y Mai 1985), ~129 N
  por garra. En el plástico, la de su desgarro (`PLASTIC_TEAR`, 4g). Quieto encima, el viento tira de las garras hacia atrás
  (`needN`): si pasa de n·R·t, la raja corre hasta el borde del panel; si no, no corre (el tigre con garras de carburo de
  tungsteno a 200 km/h: el viento tira con ~339 N y sus 8 garras frenan con ~1035 N: perfora, no raja). En el golpe, el
  largo de las marcas que atraviesan (o el desgarro del plástico) del motor.

### 22.3 ¿Abre la puerta?

Solo si la raja llega al canto de la puerta (`slide_m` de la zona, el panel hasta el canto de la cerradura): ahí va
atornillada la cerradura y, suelta de la chapa, la puerta se abre (estimación). Tirar de la puerta cerrada no basta: la
cerradura aguanta como mínimo 8900 N de través y 11 000 N a lo largo (FMVSS 206, 49 CFR 571.206 S4.1.1). Los osos que abren
coches aparcados en Yosemite (NPS, «Keep Bears Wild») enganchan las garras en lo alto del marco y lo doblan con calma, en un
coche quieto: es un caso documentado (secundario), no un golpe de ~0,2 s, y no se usa para decidir.

### 22.4 ¿Abre el techo entero?

Nunca con un animal de verdad. Cortar su contorno (2 × (1,6 + 1,2) ≈ 5,6 m) pediría ~0,7 kJ con R·t (poco, si las garras
cortasen el acero), pero los zarpazos solo cortan hacia donde arrastran (tiras a lo largo) y el techo va pegado y soldado a
los largueros y a los arcos transversales: sin cortes de través, las tiras siguen sujetas por los dos extremos. Con queratina
ni eso: no corta el acero. El velocirraptor «de cine» es ficción y lo dice.

### 22.5 En pantalla

- La ficha «Hasta dónde llega» en la tarjeta (quieto encima y en el golpe) y el corte de la chapa (`layer_cut.gd`): las capas
  una debajo de otra (alto en raíz cuadrada del espesor, dibujo), el surco hasta su capa o el hueco de lado a lado con los
  labios doblados, y el porqué; pequeño, en el primer plano.
- Las marcas de las garras que agarran (MovingCar.BODIES): el tigre y el oso, las de las dos manos (4 + 4 y 5 + 5); una
  rapaz, las de un pie (3 + 1); el velocirraptor, las de los dedos III y IV de los dos pies (la falciforme va levantada,
  Li et al. 2008; la de cine golpea con ella, ficción).
- Una marca más fina que un píxel se dibuja de un píxel en la vista del coche (dibujo); su ancho de verdad, en el primer
  plano y la lupa. La raja que corre alarga los surcos hasta el borde del panel.

### 22.6 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| R de la chapa ≈ σ0·t (185 kJ/m², banda 92-370) | Cotterell y Reddel (1977); Atkins y Mai (1985); σ0 y t de `Data.CAR_BODIES` | caso parecido medido (estimación) |
| R del plástico (45 kJ/m², 20-50) | `PLASTIC_TEAR` (SABIC, Charpy/Izod) | caso parecido medido (estimación) |
| Cerradura: 8900 N de través, 11 000 N a lo largo | FMVSS 206 (49 CFR 571.206) | norma |
| Los osos que abren coches aparcados | NPS Yosemite, «Keep Bears Wild» | secundario (caso documentado, sin fuerza) |
| Ancho del techo: 1,2 m | berlina media como el DrivAer | estimación |
| Marca la chapa desde 0,5 µm dentro | el paso con el que se comparan las honduras | dibujo |

### 22.7 Tests

`tests/lab/test_car_tear.gd`: R = σ0·t con su banda y la del plástico; las capas de cada marca y sus textos; el orden
marca < perfora < raja < abre (la raja quieto encima solo corre si el viento puede con n·R·t; la puerta solo se abre si la
raja llega al canto; el techo entero, nunca); más velocidad nunca da un escalón más bajo; el carburo de tungsteno nunca
menos que la queratina, que no perfora el acero; el plástico de la aleta sí se raja; la ficha en la tarjeta. En recta y sin
golpe, lo de antes no cambia: el veredicto se añade a las lecturas y no toca la física.

### 22.8 Qué no hace

- La puerta entreabierta o doblada en 3D (cuando «abre la puerta») no se dibuja: con los animales y las garras del catálogo,
  en el deslizador, no llega a pasar.
- La solapa de chapa levantada a lo largo de una raja se dibuja con los labios doblados del surco que atraviesa, no como una
  pieza aparte.

## 23. De cerca, segunda ronda (unidad 4s, lo que pidió el coordinador el 17-10-2026)

Todo es **dibujo**: los números de las marcas, de la abolladura y de la rotura siguen siendo los del motor.

- **«Marca de cerca»** (el tercer botón de «Cámara»): el surco de la garra que se encuadra, a un tercio de su largo (o a 4 cm de
  la punta), con 25 veces su ancho en el lado corto (entre 3 mm y 3 cm), desde 40° sobre el panel y mirando a lo largo del
  surco. Sin el cuerpo del animal, que lo taparía (se ven sus garras). Se ven las capas en las paredes y en el fondo (el
  barniz claro, el anticorrosivo oscuro, el metal brillante y el hueco negro de lado a lado) y los labios.
- **La luz de cerca:** con el primer plano en toda la vista, un foco junto a la cámara (`ClawCloseup.KEY_ENERGY`, 1,1) hace
  brillar el barniz al lado del surco y deja ver el relieve; con la ventana no se enciende (iluminaría el coche entero).
- **La abolladura:** la normal se inclina un 55 % de su pendiente de verdad (`DENT_SHADE`, car_paint.gdshader); la hondura de
  la malla es la de la física. Con la pendiente entera, la chapa abollada miraba a la carretera y se leía como un agujero.
- **Las gemas y los vidrios de cerca:** el entorno dibujado sube ×2,5 en la carretera (`GEM_ENV_ROAD`), como el de los
  metales (×4): delante de un hueco oscuro se veían negras.
- **La garra mellada:** la cara de la rotura, un disco claro en el corte, de la sección de la garra (hd3d.gd).
- **El pelo de cerca:** con el primer plano en toda la vista, el de la cetrería (raíces oscuras y variación de tono) con
  mechones un 45 % más finos; con el coche entero, el de lejos.
- **El rótulo de la lupa** en un teléfono en curva va bajo el círculo (al lado están el medidor y el mapa).

## 24. Las garras en los cristales: rayar, agrietar o estallar (unidad 4v, petición de Eric del 18-10-2026)

«En el coche en movimiento, dependiendo de dónde pongan las garras los animales y del tipo de material de las garras de cada
animal, si ponen las garras sobre el vidrio o cristales del coche pueden rayarse según física calculada, o incluso romperse los
cristales, provocando otro peligro.»

Motor: `core/lab/car_glass.gd` (`CarGlass`), funciones puras sobre lo que ya calculan `MovingCar`, `Glazing` y
`Physics.compute`; los textos, en `MovingCarState` (bloque «Cristales (unidad 4v)»); el dibujo, en los bloques «Cristales
(unidad 4v)» de `app/lab/car3d/` y de la vista.

### 24.1 Dónde pone las garras

| Cristal | Vidrio | Cómo llega el animal |
|---|---|---|
| Parabrisas | laminado (2,1 + 0,76 PVB + 2,1 mm, `Glazing.WINDSCREEN`) | quieto encima (`ZONES.parabrisas`) y en el golpe (`IMPACT_ZONES.parabrisas`) |
| Luneta | templado de 4 mm (`CarGlass.rear_window`: la hoja de las ventanillas con el tamaño de la luneta) | quieto encima (`ZONES.luneta`, nueva) |
| Ventanilla | templado de 4 mm (`Glazing.SIDE_WINDOW`) | en el golpe (`IMPACT_ZONES.luna`, unidad 4m) |

La luneta es una zona más donde quedarse: todos los animales que se quedan encima pueden ponerse en ella; baja ~25° hacia
atrás (estimación, entre el fastback y el notchback del DrivAer) y tiene el Cp de la luneta y la zaga del DrivAer (medido). De
la ventanilla, quieto encima, solo se agarra el borde de chapa (`ZONES.ventanilla`): en un cristal vertical no se sostiene
nadie.

### 24.2 Rayar el vidrio

El mismo criterio que la lente de la cetrería y la marca de verdad del banco: una punta raya el vidrio solo si es al menos
**1,25 veces más dura** (r ≥ 1,25; Richardson 1968, el criterio de Pintaude). Con los 550 HV del vidrio sodocálcico, hace
falta una punta de 687,5 HV o más. La hondura y la anchura del surco las da el motor (`Physics.compute`, con la fuerza de la
garra a la velocidad del deslizador, como en la 4s). Por debajo del umbral no hay surco aunque el motor dé una hondura de
pulido mutuo: la queratina (~30 HV) deja una **mancha**; el oro, el acero y el titanio, el **trazo de su metal**, que se limpia
(`CarGlass.trace_kind`). El strass (vidrio, r = 1,0) y el Swarovski (r = 1,09) ya no rayan el parabrisas. El cuarzo, la
circonita, el zafiro, el carburo de tungsteno, la moissanita y el diamante, sí.

### 24.3 El parabrisas: se agrieta, no cae, y tapa

Se agrieta como hasta ahora (`MovingCar.windshield_load` quieto encima y `windshield_impact` en el golpe): al flexar, si cada
apoyo pasa de la fuerza que parte la hoja, o por contacto, si una garra al menos tan dura como el vidrio abre grietas al
apoyarse o al resbalar (`Fracture.evaluate`). La lámina de PVB sujeta los trozos: **nunca cae**. Lo nuevo es el otro peligro:
**cuánto le tapa al conductor** (`CarGlass.view_loss`, en `windshield.viewLoss`, quieto encima y en el golpe):

- si lo parte el peso, una estrella de grietas de ~0,2 m de radio bajo cada apoyo (4 un mamífero, 2 un ave o un
  velocirraptor);
- si lo agrietan las garras, una franja de ~2 cm a lo largo de cada surco (como poco, un cuadrado de 2 cm);
- sobre un parabrisas de ~1,1 m².

**Es una estimación** (el caso medido más parecido: las grietas radiales y en telaraña de decenas de centímetros de los ensayos
de impacto de cabeza contra parabrisas laminados) y lo dice en la ficha, en el rótulo de la vista y en las fuentes. Lo que de
verdad importa es dónde cae: la CEPE R43 marca delante del conductor su zona de visión A. Ejemplos: el oso de pie lo parte con
su peso y tapa ~46 %; el águila con garras de diamante lo agrieta al apoyarse y tapa ~7 %. El riesgo de que una garra lo
atraviese en un golpe sigue siendo el de siempre (`penetrationRisk`).

### 24.4 La luneta y la ventanilla: enteras o estalladas

Un templado aguanta entero o estalla en trocitos, nunca a medias (`Glazing.tempered_result`; Nielsen, Schneider y Kraus 2022).
Con el animal encima de la luneta (`CarGlass.tempered_hold`): estalla si el peso de cada apoyo la parte al flexar (con el radio
del apoyo, `Physics.pane_break`) o si cada garra, al menos tan dura como el vidrio, carga más de lo que pide abrir la grieta
que atraviesa la capa comprimida (`Glazing.pierce_load`; asustado, con su fuerza de defensa). Si estalla:

- **pierde ese apoyo**: sin fricción ni anclaje (`setup`), ni parado se sostiene; el veredicto lo dice («ESTALLA LA LUNETA BAJO
  SUS GARRAS» o «… BAJO SU PESO») y el porqué también: no lo tira el viento, se queda sin nada debajo y **se cae por el
  agujero**;
- **caen trocitos dentro del coche** (de ~5,6 mm, los del templado con 100 MPa de compresión);
- **no se recompone**: si estalla a una velocidad, sigue estallada a todas las de encima (el coche ha acelerado hasta ahí;
  `CarSpeedMarks.rear_cumulative`), con su hito «estalla la luneta» en la gráfica del daño y el despegue en ese punto.

Lo que sale: el tigre con garras de cuarzo o más duras la revienta ya parado (cada garra aprieta ~270 N y bastan ~242 N); el
oso con diamante, solo asustado (~735 N por garra contra ~345 N); el águila, nunca (~12 N por garra). Con la velocidad, el viento
tira de las garras enganchadas (la carga de la punta de la 4s, `CLAW_HOOK`), pero con los animales y las garras del catálogo
ninguno la revienta en marcha mientras sigue encima (comprobado con seis materiales, de la queratina al diamante, en todos los animales y posturas, con y sin miedo: 216 casos): las
rapaces con las alas abiertas despegan mucho antes (el buitre, a ~23 km/h) de la velocidad a la que la carga de sus garras la
reventaría (~139 km/h). Si pasara, el veredicto lo diría («A ~X km/h ESTALLA LA LUNETA…»: hasta ahí aguanta). Con queratina no
estalla ninguna: ni la raya ni abre la grieta, y ningún peso de los del catálogo la parte al flexar.

La ventanilla del golpe sigue siendo la de la 4m; ahora sus marcas siguen también el criterio de la raya (r ≥ 1,25).

### 24.5 En pantalla

- **3D:** los surcos de las garras duras en el vidrio (claros, en el material de las lunas), las estrellas del parabrisas del
  tamaño de la estimación (0,2 m bajo cada apoyo; 4 cm en cada garra que lo agrieta), la luneta que se cuartea en dados y cae
  (los trozos del marco se quedan), los trocitos que saltan y caen dentro, a la banqueta de atrás, y el animal que se hunde por
  el agujero (`exit_mode` «dentro»). Todo dibujo (el radio de las estrellas y el tamaño de los trozos salen de la física), con
  el azar de `rng.gd`; en cada fotograma no se crea nada.
- **Garras de cerca y Marca:** las garras sobre el vidrio con sus grietas y el surco; con la luneta estallada, el primer plano
  mira el agujero desde arriba.
- **El corte del vidrio** («Hasta dónde llega» y el primer plano): el laminado (vidrio, PVB y vidrio) o el templado (cara
  comprimida, núcleo en tracción y cara de dentro), con el surco y el escalón: «No lo raya», «Raya el vidrio», «Se agrieta (no
  cae)» o «Estalla».
- **Informe y lecturas:** la mancha o el trazo de metal en vez de «no raya», la fila «Luneta» (entera o estallada, con sus
  números), «Vista del conductor» (estimación) y sus fuentes; el rótulo de la vista («La grieta tapa ~46 % del parabrisas al
  conductor (estimación)», «Estalla la luneta: pierde el apoyo y caen trocitos dentro»).
- **El primer plano de la chapa** dice el veredicto de `CarTear` (el corte decía «perfora» y el texto «raja la chapa de lado a
  lado»).
- **Demo:** `demo_curvas --caso=9` a `12` (el águila con diamante en el parabrisas, con «Garras» y «Marca»; el oso que parte el
  parabrisas; el tigre con cuarzo en la luneta; el oso asustado con diamante en la luneta).

### 24.6 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Rayar el vidrio: r ≥ 1,25 | Richardson (1968); el criterio de Pintaude (el de la cetrería y el banco) | secundaria |
| Vidrio: 550 HV | el sodocálcico del catálogo del banco | secundaria |
| Luneta: templado de 4 mm, 120 MPa a flexión, radio equivalente ~420 mm (1,1 × 0,5 m) | EN 12150-1; just-auto (4 mm); el tamaño, sin medición publicada | norma y **estimación** |
| Luneta: ~25° de inclinación | entre el fastback y el notchback del DrivAer | **estimación** |
| Luneta: Cp −0,15 (−0,28 a 0,01) | DrivAer en túnel (luneta y zaga) | secundaria (medido) |
| Lo que tapa: estrella de 0,2 m, franja de 2 cm, parabrisas de 1,1 m² | caso medido más parecido: grietas radiales y en telaraña de los ensayos de impacto de cabeza contra parabrisas laminados | **estimación** |
| Trocitos de ~5,6 mm | Nielsen, Schneider y Kraus (2022) con la compresión de `Glazing.SIDE_WINDOW` | medido (relación) y estimación (compresión) |
| Hundirse por el agujero 0,68 m, el campo del primer plano, el salto de los trocitos, la banqueta a 0,5 m | — | dibujo |

### 24.7 Tests

`tests/lab/test_car_glass.gd`: rayar pide r ≥ 1,25 (la queratina, el oro, el acero y el titanio nunca rayan; lo duro, sí); la
queratina nunca raya ningún cristal del coche (quieto encima, asustado y en el golpe); una garra más dura nunca raya menos hondo
(parabrisas y luneta); más fuerza nunca agrieta menos; el templado entero o estallado, con el apoyo perdido y los trocitos
dentro si estalla, y el veredicto que lo dice; la luneta no se recompone con la velocidad; el laminado agrietado no cae y lo que
tapa está entre 0 y 1, marcado como estimación; lo de siempre no cambia; los textos; el primer plano dice lo mismo que el corte;
determinismo. `tests/app/test_car_glass_view.gd`: la luneta en la silueta, las estrellas del tamaño de la estimación, la luneta
que estalla en las lunas y sus trocitos (que se crean una vez y se quedan dentro), el corte del vidrio y que en cada fotograma
no se crea nada mientras estalla.

### 24.8 Qué no hace

- La ventanilla, quieto encima: en un cristal vertical no se sostiene ningún animal; sus garras solo llegan a ella en el golpe
  (4m). Los resbalones de las curvas que acaban sobre un cristal (4u) no se calculan aquí.
- La luneta que estallase en marcha (no pasa con el catálogo) cambiaría el veredicto cuando llega la gráfica del daño (se calcula
  en el hilo de lo caro); con una ventana de agarre (solo aguanta más deprisa) se quedaría el del despegue.
- Dónde caen las grietas del parabrisas respecto a los ojos del conductor: la estimación es del parabrisas entero.
- El parabrisas no estalla ni cae nunca; la luneta laminada de algunos coches de gama alta no está.

## 25. La luz del sol y los reflejos (unidad 4w, petición de Eric del 18-10-2026)

Todo es **dibujo** (calidad «dibujo»): no cambia ningún número de la física.

- **El selector «Luz»** de la tarjeta (bajo la vista, en escritorio y teléfono; en el teléfono con rótulos cortos):
  - «Como hasta ahora», por defecto: el atardecer de siempre (`road_sky.gdshader`, su sol y la luz de relleno), con los
    mismos parámetros (lo comprueba `tests/app/test_coche_luz.gd`);
  - «Sol de mediodía»: a 58° del horizonte, blanco, del lado de quien mira, sombras cortas y duras y cielo azul;
  - «Sol bajo»: a 11°, cálido, de tres cuartos por detrás del lado de quien mira, sombras largas y el horizonte anaranjado;
  - con un sol, el deslizador «Rumbo del sol» lo gira hasta 180° a cada lado para mover los reflejos por la carrocería.
- **Los reflejos de verdad del render:** el sol es un disco en el cielo de reflexión (la pintura con barniz, las lunas y los
  cromados lo devuelven como un punto) y la luz direccional tiene el tamaño angular del Sol (0,53°). En las lunas
  (`car_glass.gdshader`), el destello de su disco donde su reflejo cae hacia quien mira (con la luz de siempre, nada).
- **En curva, el sol se queda quieto en el mundo:** el rumbo del coche sube con la curvatura de verdad por lo recorrido, y el
  sol gira al revés respecto al coche; los reflejos corren por la chapa, los vidrios y las garras.
- **Las garras** (biblioteca de materiales de la 5e, entorno «carretera»): ven el cielo de la luz elegida (su sol, su color y
  sus colores), no el atardecer escrito en el sombreador. Revisión de los materiales con cada luz
  (`progreso/calle-a/4w_*`, demos 31-34 de `demo_coche`):
  - lo de abajo es lo que pisan: la pintura del coche iluminada (una garra sobre un coche rojo refleja rojo) y, lejos, el
    asfalto. **Cambia también la luz de siempre, a propósito:** los metales (acero, titanio, carburo de tungsteno,
    hematites) se veían negros sobre la chapa porque reflejaban un suelo casi negro;
  - dentro de una gema, el cielo dibujado (más morado y oscuro que uno de verdad) se acerca al blanco (`GEM_NEUTRAL`, 0,6):
    el diamante y la moissanita se veían lilas con caras negras; y el sol, con un lóbulo más ancho que su disco
    (`gem_sun` de cada luz), para que las caras que lo alcanzan, cada canal con su índice medido, den el fuego. Las caras
    que ven el asfalto siguen oscuras: es lo que reflejan;
  - las garras de cerca, con más vueltas y tramos en el escritorio (Rig3D 24 × 28, HD3D 32 × 30; el teléfono, como estaba):
    a ~50 aumentos se veían de pocos polígonos.
- **Compatibilidad:** los 42 sombreadores compilan en Compatibility (OpenGL) y en Forward+ (Vulkan, lavapipe); las capturas,
  en Compatibility. En el preset móvil, el sol no proyecta sombras (como la luz de siempre).
- **Lo que no hace:** la alúmina sinterizada se sigue viendo blanca y plana (su cuerpo difuso, sin brillo propio); no hay
  hora del día ni nubes que muevan la luz.

## 26. En curva, el animal se agarra, se recoloca y se cae (unidad 4u, petición de Eric del 18-10-2026)

«Si el coche en movimiento gira y zarandea, los animales tendrán que tener sus animaciones y movimientos, pudiendo dejar
todavía más garras y marcas en el coche, intentándose agarrar para no caerse, y si pillas una curva cerrada muy rápida, este
puede desequilibrarse y caer del coche también.» Va encima de la 4t (§20: el equilibrio cuasiestático en curva y el
despegue) y de la 4s (§21-§23: las marcas del motor capa a capa). Motor: `godot/core/lab/car_curve_grip.gd`.

### 26.1 Lo cerca del límite

No hay equilibrio nuevo: u = fuerza necesaria / fuerza que dan sus garras (`loadRatio` de `CarCurve.at_speed` o, en cada
instante de la S, de `at_lateral`). Con u ≥ 1 no aguanta y se cae; eso lo dice el mismo equilibrio que el despegue en curva
(`CarCurve.detach`): se cae a una velocidad si y solo si esa velocidad pasa de la del despegue (lo vigila un test).

### 26.2 Recolocarse deja marcas

- **Cuándo:** con u ≥ `SLIP_FROM` (0,8; de 0,7 a 0,9) las garras del lado cargado resbalan y vuelven a clavarse. En la S,
  además, al cambiar de lado se recolocan las del lado nuevo si su u pasa de `FLIP_FROM` (0,55; de 0,4 a 0,7).
- **Cuántas:** de una a todas las del lado cargado (la mitad de las que agarran, redondeando hacia arriba), según lo que u
  pasa del umbral. Nunca baja si sube u: más velocidad o menos radio nunca dejan menos resbalones.
- **Cuánto resbala cada una:** de la mitad a todo `SLIP_MM` (15 mm; de 6 a 30), según lo que pasa del umbral.
- **Con qué fuerza:** la de una garra del lado de fuera. Le toca 2·share de la normal media (el reparto entre lados de la
  4t, `side_shares`) y su parte de la fuerza necesaria a lo largo del panel (`CLAW_HOOK` de la 4s: por igual entre las que
  agarran); la punta toma la resultante. Asustado, aprieta al menos con su defensa.
- **Qué deja:** el surco del motor de siempre (`MovingCar._marks`, el de la 4s) con esa fuerza y ese largo: la hondura, el
  ancho, las capas que corta (`CarTear.layers_txt`) y si llega a la chapa o la atraviesa, según el material de la garra. La
  garra que resbala tira más que quieta en recta a la misma velocidad: su surco nunca es menos hondo (test).
- **Hacia dónde:** en la dirección de la fuerza en el contacto (`CarCurve.mark_deg`: hacia fuera de la curva).

### 26.3 Caerse

Si no aguanta, todas sus garras arañan mientras resbala hacia fuera hasta el borde del panel (`FALL_SLIDE_MM`, 300 mm; de
150 a 600: medio ancho de un techo de turismo), con la misma fuerza por garra. En el modo «lado» se cae por el lado de fuera;
si lo que puede con él es el viento (modo «atrás» o «despega»), se suelta como en recta. La caída en sí (colgar un instante
del borde, caer rodando por la carretera y quedarse atrás) es solo dibujo: no hay física de vuelo.

### 26.4 En pantalla (dibujo)

- **El miedo** (`CarCurveGrip.fear`, 0 a 1, dibujo): sale de lo cerca que está de soltarse (u, desde 0,2) y del tirón de la
  S (hasta 3 m/s³, que añade hasta un 35 % si ya está cargado). 0 tranquilo; 1 a punto de soltarse. La vista lo suaviza
  (0,3 s) con su lado: en la S pasa de un lado al otro sin saltos.
- **La pose de supervivencia** (`hd3d.gd`, con el miedo y su lado): el cuerpo se agacha y gira hacia dentro de la curva,
  con las patas en el techo, la cabeza baja y, cada especie a su manera:
  - el tigre se pega al techo, con la cola dando latigazos de contrapeso hacia dentro;
  - el oso se aplasta, abierto de patas, abrazado al techo, con la cabeza metida;
  - el velocirraptor (los dos) se agazapa y gira sobre sí mismo con la cola fuera, de contrapeso;
  - la rapaz y la lechuza bajan el cuerpo y abren las dos alas medio abiertas, inclinadas contra la fuerza, y aletean con
    mucho miedo (el ala izquierda del cuerpo de la cetrería es el espejo de la derecha, que es la que lleva entera).
- **Vida:** en curva siempre respira, corrige el equilibrio y mira a los lados; con mucho miedo (desde 0,55), tiembla y las
  patas de fuera escarban a zarpazos cortos, además del tirón de cada resbalón de verdad.
- **Los surcos** salen de las puntas de las garras del lado de fuera (las de la pose) y se acumulan: en la curva, al llegar;
  en la S, al pasar cada momento. Se ven en 3D, en el primer plano de la marca y en la lupa, y cuentan en el informe.
- **La caída:** resbala hasta el borde (0,6 s), cuelga agitando las patas (0,4 s) y en 1,5 s cada especie cae a su manera
  (`FALL_STYLE` de la vista):
  - el tigre da una vuelta en el aire y cae de pie, como un gato;
  - el oso se suelta como un saco y acaba boca arriba en la carretera;
  - el velocirraptor de la reconstrucción salta fuera del coche y cae de pie;
  - el de cine se abalanza hacia delante, por delante del coche (ficción, como su golpe);
  - la rapaz y la lechuza abren las alas y aletean: intentan despegar, pero no pueden con el viento de la marcha y se quedan
    atrás (también lo dice el texto: «se suelta e intenta despegar», en vez de «se cae»).
  En la S, una vez caído, no vuelve hasta que la S empieza otra vez.
- **La cámara de persecución,** más cerca del animal (4,9 m detrás; en el teléfono, 3,9 m), para que se vean las poses.

### 26.5 Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Se cae si u ≥ 1 | el equilibrio de siempre (`MovingCar._eval` con la curva, 4t) | modelo |
| Resbala desde u = 0,8 (0,7-0,9) | suposición de juego; caso parecido: la garra enganchada resbala de un agarre al siguiente cerca de su tope (Dai, Gorb y Schwarz 2002) | estimación |
| Al cambiar de lado, desde u = 0,55 (0,4-0,7) | suposición de juego | estimación |
| Lo que resbala cada garra: 15 mm (6-30) | suposición de juego: del orden del paso de una pata al recolocarla | estimación |
| Lo que resbala al caerse: 300 mm (150-600) | medio ancho de un techo de turismo | estimación |
| La fuerza de cada garra: 2·share de la normal y su parte de la necesaria | reparto entre lados (4t) y `CLAW_HOOK` (4s) | estimación (de la 4t y la 4s) |
| El surco: hondura, ancho y capas | el motor de siempre (`MovingCar._marks`, `CarTear`) | modelo |
| El miedo (desde u = 0,2, con el tirón de la S), las poses de cada especie, la vida, el temblor, la caída rodando o el intento de despegar | — | dibujo |

### 26.6 Tests

`godot/tests/lab/test_car_curve_grip.gd`: en recta no hay nada (ni sin aceleración lateral, ni la S parada); lejos del
límite no aparecen marcas nuevas; más velocidad o menos radio nunca dejan menos surcos (y con menos radio, nunca uno menos
hondo); la garra que resbala no tira ni raya menos que quieta; un animal con más agarre nunca se cae antes; unas garras más
duras (queratina, carburo de tungsteno, diamante) nunca dejan marcas menos hondas, y la queratina no atraviesa la chapa ni al
caerse; se cae si y solo si no aguanta, y el despegue de la curva dice a qué velocidad; la S sale igual dos veces, sus
momentos van en orden y después de caerse no hay más; los conteos y los largos nunca bajan con u; cada dato con fuente,
calidad y banda; los textos; y el estado (en recta, el informe y las fuentes al bit).
`godot/tests/app/test_car_curve_grip_ui.gd`: los surcos de las garras de fuera, hacia fuera y con las medidas del estado;
en la S aparecen a medida que pasa y se acumulan sin crear nada en cada fotograma; el oso que se cae por el lado de fuera
hasta la carretera; y que la vista no calcula física.

### 26.7 Qué no predice

- **La dinámica de verdad:** sigue siendo cuasiestático. Un animal real, con su inercia, podría soltarse antes en el tirón
  de la S, o recolocarse sin resbalar.
- **El resbalón:** cuándo, cuántas garras y cuánto son suposiciones de juego; no hay medición publicada de una garra que
  resbala por la pintura de un coche y se vuelve a clavar.
- **Cada resbalón es igual:** con la fuerza del pico de su lado; uno real dejaría un surco que se ahonda y se afila.
- **La caída:** el vuelo, el golpe contra el asfalto y lo que le pasa al animal no se calculan.

## 27. El paisaje: campo verde, árboles, montañas y una carretera sin fin (unidad 4x, petición de Eric del 18-10-2026)

Todo es **dibujo** (calidad «dibujo»): no cambia ningún número de la física ni del viento.

- **Dónde se ve:** con la cámara de persecución y «Fondo: campo» (el selector nuevo bajo la luz; por defecto, campo). Con
  «liso», o con la vista de lado, el fondo de siempre (la tarjeta detrás del coche y sus colinas dibujadas) y el entorno tal
  cual (sin cielo de fondo ni niebla): lo comprueba `tests/app/test_coche_paisaje.gd`.
- **La persecución también en la recta:** el selector de la vista sale también en la recta; allí la persecución es la
  carretera larga sin curva. Por defecto, en la recta, la vista de lado de siempre (la de las marcas y la lupa); en curva, la
  persecución, como hasta ahora. Las líneas que lo permiten van marcadas «(4x)».
- **El campo** (`scenery_ground.gdshader`): dos tiras desde el arcén hasta 180 m que siguen el trazado de la carretera larga
  (el mismo eje y lo recorrido que el asfalto, `scenery_path.gdshaderinc`), con parcelas de tres tonos y sus lindes, grano
  fino que se apaga de lejos, hileras en las segadas y un relieve que crece al alejarse del arcén (plano junto a él). Del
  lado de dentro de una curva demasiado cerrada se comprime antes del centro (si no, se doblaría sobre la carretera). Más
  allá, un suelo grande del mismo verde; la niebla del entorno (con la perspectiva aérea del cielo) funde el horizonte.
- **Los árboles** (`scenery.gd`, `scenery_tree.gdshader`): tres especies hechas a mano con volumen (conífera de tres conos,
  frondosa de tres copas y chopo), un MultiMesh por especie: 730 en el escritorio y 240 en el teléfono, con la semilla de
  `rng.gd`, más densos lejos que junto al arcén y a veces en grupos, siempre a más de 3 m del arcén. Cada uno corre con lo
  recorrido y vuelve a entrar por delante (la carretera sin fin, con los mismos nodos: no se crea nada por fotograma);
  la costura queda detrás de la cámara y a 260 m, en la niebla. Los del lado de dentro de una curva demasiado cerrada se
  esconden. Un vaivén suave en lo alto de la copa.
- **Las montañas** (`scenery_mountain.gdshader`): dos anillos de siluetas a 560 y 820 m, la cercana verdosa y la lejana
  azulada y más clara, que van donde está la cámara (sin paralaje) y giran con el rumbo del coche en la curva (como el sol
  de la 4w); el lado al sol algo más claro y algo de nieve en las cumbres más altas de la lejana.
- **Con cada luz** (§25): la neblina y la niebla toman el horizonte del cielo de la luz elegida; el sol bajo tiñe el campo
  de naranja.
- **Rendimiento** (Movie Maker en Compatibility con render por software, la ventana entera): la persecución en la recta a
  120 km/h cuesta 34,7 ms por fotograma con el campo y 32,3 con «liso» en el escritorio (+2,4 ms), y 14,1 frente a 13,7 en
  el teléfono (+0,4 ms). Los árboles no proyectan sombras.
- **Lo que no hace:** no hay paisaje en la vista de lado (allí siguen las colinas dibujadas detrás); en la curva más cerrada
  (la glorieta), los árboles del lado de dentro desaparecen.
