# Unidades que vienen después (todavía sin encargo escrito)

Resumen de lo acordado con Eric para las unidades que empiezan cuando se unan las que están en marcha. El encargo
completo se escribe al lanzarlas, con lo que dejen hecho las anteriores. Las peticiones de Eric están en
[`docs/V2-FASE2.md`](../../V2-FASE2.md), en «Qué pidió Eric en la fase 2».

## Unidas o en marcha

La 4i-B2, la 4j, la 4k, la 4l, la 5b, la 4m, la 4n, la 5c, la 5d, la 4o, la 5e, la 5g, la 5f, la 5h, la 5j y la 5i están
unidas, y la 5l, la 4p y la 5n también. La 5m, la 5o y la 5p están en marcha, y la 4q se lanza ahora. Cada encargo está en su archivo de esta carpeta, con su estado en [README.md](README.md).

## Para la próxima pasada de física del coche en marcha

Visto al unir la 4j y la 4i-B2. La 4o (encargo [4o](4o-coche-fisica-pulido.md)) ya hizo los dos primeros puntos.

Queda, visto al unir la 4o:
- ~~**Lo que aguantan de lado unas garras de tungsteno clavadas** («Garras clavadas: aguantan de lado 3.0 MN»)~~: resuelto por la 4p (20,6 kN, manda la chapa). Sale de la
  flexión con un brazo casi nulo, sin comprobar el cortante, y la chapa de 0,7 mm cedería mucho antes alrededor del
  agujero. No limita, porque manda el agarre (244 N), pero el número no es fiable. Está en `claws_hold_n` y
  `claw_fracture.gd`.
- **La punta y la abolladura** se limitan cada una por separado con el mismo hueco (guía del coche, §16.7).

Lo que ya estaba:
- **La hondura de las marcas de una garra que atraviesa la chapa.** En el velocirraptor de cine, `marks.depthUm` sale
  como el largo entero de la garra (120 mm), y la banda lo enseña como «marcas de 120 mm de hondo», pero bajo el capó
  solo hay ~80 mm de hueco (`IMPACT_ZONES.capo.clearance_mm`). Decidir si la hondura de una marca que atraviesa se
  enseña como «atraviesa la chapa» o se limita al hueco.
- **Bandas que faltan:** la rigidez de la pata (10 N/mm), su recorrido y el hueco bajo el panel no tienen banda
  numérica, así que la banda del golpe no los mueve.
- **Fuentes con nombres internos en el banco:** hecho por la 4n (las fuentes del banco ya no llevan rutas ni nombres de
  código, y lo vigila `test_banco_textos.gd`).

## Beta 2

- **Cuándo:** después de unir la 4g, la 4i y la 4h, y lo que haya de la 5a y la 5b.
- **Qué lleva:**
  - la exportación de Linux, el proyecto y el LEEME;
  - repartidos en dos partes de menos de 30 MB;
  - comprobado en una carpeta limpia (arranca, `npm test` y `npm run godot:test`).
- **Novedades desde la Beta 1 para el LEEME:**
  - el coche en marcha en su propia página;
  - el deslizador de 0 a 230 km/h y el selector de animal;
  - las lupas y los sonidos del hueso;
  - lo que aporten las unidades en marcha: el Velociraptor y el afilado en el banco, la aleta de plástico rajada y el
    coche y los animales en 2.5D.

## Más adelante

Está en «Lo que queda» de `docs/V2-FASE2.md`:
- el resto de la reorganización del laboratorio, con el modo dual y la comparativa en páginas propias, cuando Eric lo
  pida;
- el torno manual (2d) y el diseño 3D de las máquinas (3a);
- la auditoría de las 383 estimaciones;
- el pulido de la interfaz y la revisión del 3D y del sonido;
- la optimización y la release.

## Para la próxima pasada de física de la cetrería

La 5g (encargo [5g](5g-cetreria-fisica-pulido.md); `docs/fisica/cetreria.md` §11) hizo lo que pidieron la 5b, la 5c y
la 5d y las peticiones 35 a 37: probar la punta; dónde está el calor; la forma de cada garra dedo a dedo (las rapaces,
medidas) y una sola fuente del arco de cada garra del banco (`CareData.claw_arc`); el animal compartido entre sus garras;
el consejo del calor según la herramienta; el rubí y la alúmina en el catálogo 2.0 y en la cetrería; la forma en directo,
la rotura con su sitio y la garra rota que vuelve de la reforja como un bloque en bruto; y la superficie de cada pasada.

Lo que queda:
- las garras dedo a dedo del tigre y del oso y las de sus patas traseras: sin medición publicada que se haya podido leer
  (hoy, todos los dedos con la garra del banco y las traseras como las de la mano, como estimación);
- el alto y el ancho de la base de las garras (la sección), salvo la del velocirraptor, que está medida;
- la rugosidad de una garra limada (hoy, del orden del acero lijado, con la natural de la uña humana);
- ~~el calor de limar un bloque reforjado de metal o de cerámica con la conducción de cada material~~ y ~~una prótesis
  de acrílico real en la cetrería~~: hechos por la 5j;
- si se quiere que la bajada del tono de la amoladora al apretar sea física, una medición de par y rpm de la Dremel 7760.

Pedido por la 5h al unirla (la cetrería en alta definición):
- **la base del velocirraptor sale muy gruesa:** su radio es la estimación genérica (0,15 × el alcance, 13,9 mm); con la
  sección comprimida (k = 2,63) y el área conservada, la hoz se dibuja con 45 × 17 mm de base, frente a los 18,7 × 7,1 mm
  del núcleo medido (Norell y Makovicky 1999). O se toma la base del núcleo medido más el estuche, o el dibujo conserva el
  alto en vez del área;
- que `slots_view()` dé la forma de cada dedo (`arcDeg`, `sectionRatio`, `naturalMm` y `baseRadiusMm`): hoy las demás
  garras trabajadas se dibujan con la forma de la elegida;
- un contador `surface.serial`, para no calcular la huella de la superficie;
- que `lastBreak` puede ser una grieta que no cae justo después de un corte que sí cae (la escena ya recorre
  `damage.breaks`);
- el águila pescadora no está en el catálogo, así que no hay espículas;
- los añadidos de la 5c en `sleep3d.gd` y `Animal3D` ya no los usa la cetrería (se pueden quitar con cuidado del coche).

Visto al unir la 5i (los cuerpos enteros; lo hace la 5n):
- las cabezas del tigre y del oso son simplificadas (de cerca, la del oso parece una masa de pelo) y la del velocirraptor de
  la reconstrucción, un hocico largo sin apenas forma;
- las escamas del cuerpo del velocirraptor de película se pierden de lejos;
- el disco facial del búho real podría marcarse más;
- en el tigre y el oso, la manga del cuerpo tapa casi todo el antebrazo de la pata de la 5h (a propósito, para que no se
  vea la costura).

Pedido por la 5f al unirla (la reforja en 3D): hecho por la 5j (la vista publica `reforge_request`, el sonido sigue a la
máquina del modo del horno, la prótesis usa `stump_mm`, la pieza lleva su superficie y el deslizador del teléfono ya no
tapa el panel).

Pedido por la 5j al unirla (la pasada de pulido de la reforja):
- que la página de la cetrería tome `from_care` de `view().reforge_request` (hoy `_lab_setup()` de `care_page.gd` lo
  rehace; un test comprueba que los dos coinciden);
- los datos ópticos del acrílico en `ClawOptics` (la biblioteca de la 5e), con su fuente: hoy la reforja y la cetrería lo
  pintan como la queratina con su color de dibujo.

Pedido por la 5g a otras unidades (en su informe):
- que los dibujos de las garras lean `CareData.claw_arc` (la cetrería, `claw_mesh.gd` de la 5h; el coche y la galería,
  `ClawGeo` de la biblioteca de la 5e) y la sección de `CareData.claw_shape`: es la fuente única del arco que pidió la 5e
  (la daga del casuario, medida: 41°);
- que `MovingCar.inlay_of` busque en `Catalog.INLAYS` (4o) y que la reforja lea el rubí y la alúmina del catálogo 2.0
  (`ForgeData.in_bench` y los datos de `NEW_MATERIALS.alumina` desde `ClawMass` y `ClawFracture`; 5f);
- que la página enchufe el flujo de la garra rota con `ClawCareState.reforge_request()` y `reforge_with()` (5f).

Pedido por la 5e al unirla (además del arco, que ya da la 5g):
- el fuego de las gemas se ve poco con el entorno de ahora;
- con el techo oscuro de la nave, un metal pulido refleja casi negro en la cetrería (se lo pide a la 5h).

Visto en las capturas al unir la 5c (lo hizo la 5h, salvo los cuerpos enteros, que hará la 5i):
- la toalla de la rapaz es un óvalo blanco liso que parece un huevo;
- el pelo del lomo del oso se ve como púas oscuras sueltas;
- de cerca, con la amoladora sobre la garra, cuesta ver la garra y lo que se lima;
- los miles se escriben de dos maneras en la misma pantalla («25000 rpm» en las lecturas y «25 000 rpm» en el botón).

## El botón de donaciones (petición 39): hecho el 04-10-2026

Se adelantó cuando Eric dio sus enlaces (pidió hacerlo «cuando hayas acabado todo»). Cómo quedó:
- **Dónde:** un botón discreto en la barra superior, en las dos secciones (Tribología biológica y Taller industrial), que
  se vea bien también en el teléfono: «☕ Dona o invítame».
- **Qué abre:** un panel con el texto de Eric y tres botones: GitHub Sponsors, PayPal y Ko-fi.
- **Los enlaces y el texto,** en un solo sitio que Eric edita: `core/shared/app_info.gd`, junto al nombre y el autor.
  - Los enlaces que estén vacíos no salen; sin ninguno, el panel enseña solo el texto.
  - Cada enlace se abre en el navegador con `OS.shell_open` al pulsarlo: la aplicación no hace ninguna llamada a la red
    (CLAUDE.md, regla 6).
- **En GitHub,** cuando Eric dé sus usuarios: `.github/FUNDING.yml`, para el botón «Sponsor» del repositorio.
- **El texto** (primera persona; revisado por Eric el 04-10-2026: el ciclo de informática, sobre todo sistemas; que lo
  ha codiseñado con Claude Code, revisando él parte de los diseños 3D en Godot y del código; y que espera que anime a
  estudiantes de FP y de carrera a hacer cálculos y experimentar con la física):

  > Hola, soy Eric Valls Gramunt y tengo {edad} años. Este programa lo he hecho poco a poco y en mi tiempo libre.
  >
  > Nació de una pregunta sencilla: ¿qué raya, qué corta y qué perfora a qué? Empezó con uñas, garras y colmillos, y ha
  > crecido hasta un laboratorio de tribología biológica (con el coche en marcha, la cetrería veterinaria y la reforja
  > de garras) y un taller industrial con torno manual y CNC, fresadora, taladro, radial y afiladora. Todo con física de
  > verdad: cada número lleva su fuente, y lo que no está medido se marca como estimación.
  >
  > Lo he codiseñado junto con Claude Code, revisando yo mismo buena parte de los diseños en 3D en Godot y del código.
  >
  > He pasado por dos ciclos de FP Superior: Diseño en Fabricación Mecánica, donde trabajé con simuladores de torno como
  > el que inspiró el taller de este programa, e Informática, donde estudié sobre todo sistemas. Este proyecto junta lo
  > que más me gusta: la mecánica, la ciencia de los materiales y el software. Fuera de aquí, me apasionan la
  > inteligencia artificial, el hardware y los videojuegos.
  >
  > También soy un apasionado de los animales, sobre todo de las aves y de los felinos: en mi tiempo libre disfruto
  > yendo de vez en cuando a cursos de cetrería (jeje, de ahí la cetrería de este programa) y haciendo excursiones por
  > la montaña con mis amigos, cuando las condiciones lo permiten.
  >
  > Espero que ayude a algunos futuros estudiantes de FP y de carrera a animarse a hacer cálculos y a experimentar con
  > la física.
  >
  > El programa es gratuito, sin anuncios y no recoge ningún dato. Si te ha gustado o te ha resultado útil, puedes
  > invitarme a un café o apoyar el proyecto. Cualquier ayuda me anima a seguir mejorándolo. ¡Gracias!
- **{edad}** es la edad de Eric el día que se abre (petición 41): `AppInfo.age_on` con su fecha de nacimiento, el
  13-05-1994, y la fecha del sistema.
- **La mención a Claude Code** va en este texto a petición de Eric. Es la excepción a la regla de no mencionar a Claude
  en lo versionado, que sigue valiendo para los commits, los comentarios y los demás archivos.

## Para el banco de ensayo (pedido por la 4n al unirla)

- **El pico de Hertz en el resultado 2.0:** `p0MPa` y `hertzRadiusUm`, para enseñar la presión de pico de los contactos
  elásticos. Hoy la uña almendra a 4 N sobre el vidrio da 4,44 MPa de presión media, y el pico de Hertz real ronda los
  294 MPa. Es física del motor: va con su fuente (Johnson 1985), su test y el golden 2.0 explicado.
- **Logros de lo nuevo de la 2.0:** un `Lab.BADGES_V2` aparte de los de la 1.x. Hay que rehacer el subconjunto de emojis
  de la fuente con fontTools, que no está en la nube.
- **La herramienta del banco no cambia de forma al afilarla:** de momento lo enseña solo la lupa del afilado.

## La 5k, repartida (petición 46: acabar ya)

La 5k (la pasada final de la cetrería) no se lanza. Lo necesario para publicar va a otras unidades:
- a la 5o: el indicador de la forma que decía «188327 %», la forma de cada dedo en `slots_view()` y, por la petición 48, la base de la hoz del velocirraptor;
- a la 5p: los arcos de las garras del coche desde `CareData.claw_arc`, el brillo de las gemas y la óptica del acrílico.

Para después de la 2.0:
- un contador `surface.serial` para no rehacer la textura de la superficie sin necesidad;
- qué significa `lastBreak` cuando una grieta sigue a un corte, con su test;
- quitar del coche en marcha los añadidos de la 5c que la cetrería ya no usa (`sleep3d.gd` y `Animal3D`);
- que la página de la cetrería tome `from_care` de `view().reforge_request` en lugar de rehacerlo en `_lab_setup()`.


## Los reflejos de los metales (petición 49; desde la petición 56, prioridad: encargo 5q)

Eric: «no es tampoco del todo importante; lo importante es que se muestren todos los materiales y sus propiedades físicas».
Quedaba para después de la 2.0 lo que dejó la 5p: el acero pardo y apagado en la cetrería (la ventana de la sala queda por
encima del techo y no se refleja) y el techo oscuro de la sala de la reforja. **Hecho en la 5q (coordinador, 10/11-10-2026):**
la ventana de la sala a su altura, la sonda otra vez en la garra, la reforja con cielo claro y los metales con el reflejo
analítico de su entorno (`docs/fisica/materiales-garras.md`, §5 y §9).

Queda abierto, medido y sin resolver (5q, 12-10-2026): **en Forward+ (Vulkan) la galería de materiales lava el color de los
metales** (el oro sale pajizo; en Compatibility sale dorado). Experimentos en la página 3 de la galería con lavapipe, medidos
sobre la garra de oro (media RGB; cuanto más R − B, más dorado): base 0,533/0,525/0,477; sin el reflejo analítico de la
biblioteca 0,482 de media y el mismo lavado; sin el reflejo del cielo de Godot, igual de lavado; sin glow, igual; con el sol
y el relleno a la mitad, igual (0,481/0,478/0,432). OpenGL: 0,501/0,461/0,371. Así que no es el reflejo analítico de la 5q
ni el cielo: es cómo Forward+ aplica la luz ambiente y especular a un metal (la parte sin teñir del BRDF de entorno). En la
cetrería, con la sonda de la sala, el acero sale bien en Vulkan (captura `c6-vk2`). Pendiente: comparar en la RTX de Eric
(lavapipe no es la referencia) y, si allí también, probar `ambient_light_energy` más bajo en la galería o una sonda.

## Lo que dejó anotado el repaso de interfaz (4q, 12-10-2026)

- Decimales con coma en los textos de la 1.x («pintura + acero bh 0,7 mm», `lab.gd`; «0,5 N» del deslizador) junto a puntos
  del motor 2.0 en la misma pantalla: el oráculo está congelado y no se toca; regla propuesta para CONTRATOS: los textos
  de la 1.x conservan la coma del oráculo y los nuevos de la 2.0 pasan por `Js`/`Format`/`car_format.gd`.
- Rótulos de 6-9 px en los dibujos (`lab_art` sección, `art_dino`).
- Contraste 4,34 de `Small` sobre `Row` en las comparativas (tema global) y botones táctiles de menos de 44 px en el
  teléfono (SegButton y Pill 33 px, IconButton 38, FooterLink 21): tema global, afecta también a la cetrería.
- El presupuesto de fotograma de `test_care3d` (4,0 ms) y `test_care_hd` (3,0 ms) es demasiado justo para una máquina con
  carga (fallan con 4 agentes y pasan a solas): darles margen o medir con menos varianza.
- Avisos de Godot al salir de una captura con Movie Maker (instancias filtradas, `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT` en
  OpenGL por software): solo en las capturas, no en los tests.
- «Taller · WIP» en la barra de una versión pública: decisión de Eric.
