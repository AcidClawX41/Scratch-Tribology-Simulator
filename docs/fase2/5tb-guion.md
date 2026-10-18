# 5t-B · Guion del ataque del animal y de la lente rayada

Guion de fotogramas clave de las cinco reacciones (rapaz diurna, rapaz nocturna, tigre, oso y velocirraptor), escrito antes
de programarlas, como pide el encargo (`encargos/5t-cetreria-bienestar-del-animal.md`, anexo «Diseño detallado de la
reacción y de la lente», el añadido del 12-10 y el del 13-10: la lente es parte del juego). Lo que aquí es **dibujo** no se
presenta como dato; lo que sale del motor o del catálogo lleva su fuente.

## 1. Lo común a las cinco

### 1.1 Cuándo y cuánto

- La reacción la decide el motor (calle C, `ClawCarePatient.view().reaction`: `seq`, `warning`, `kind`, `intensity`,
  `lens`). La escena **no decide** si el animal ataca: solo lo pinta. Con la sedación adecuada el motor no la lanza; si
  llegara un evento con `intensity` < 0,15 (el animal casi no puede moverse), solo se pinta **un tirón de la pata
  dormida** (0,35 s, sin golpe ni lente).
- **Aviso** (`warning: true`): la postura de amenaza de su especie, en bucle y sin golpe, con su sonido de aviso (gruñido,
  bufido, chasquido del pico). Sin cambiar de cámara: la pata que se trabaja se tensa (se ve también en la vista de la
  garra) y, en el tigre, las uñas asoman un poco de la vaina. Si el aviso se va sin reacción, todo vuelve a reposo en 0,8 s.
- **Reacción** (`seq` sube): el plano del zarpazo, en cuatro tiempos (abajo). Una a la vez: si llega otra mientras dura,
  se encola una sola. El motor ya separa las reacciones (~20 s); la escena, además, no lanza dos en menos de 4 s.

### 1.2 Los tiempos (en pantalla)

| Tiempo | Duración | Qué pasa | Curva |
|---|---|---|---|
| 0 · Corte | 0,2 s | Corte seco al plano del zarpazo; el animal ya en postura de amenaza (la del aviso), mirando a la cámara | — |
| A · Anticipación | 0,3-0,6 s (por especie y variante) | El cuerpo se carga: el miembro se recoge hacia atrás (lo contrario del golpe), la exhibición de la especie llega a su máximo al 70 % y se sostiene un instante (*moving hold* de 0,06 s) | entrada y salida suaves (seno); la exhibición con un rebote pequeño (sobreimpulso ≤ 8 %) |
| S · Golpe | 0,10-0,20 s en pantalla | El miembro sale hacia la cámara por un arco (curva de Bézier con su punto de control fuera de la recta): acelera todo el camino | posición s(t) = d·(t/T)², la de una fuerza constante desde el reposo (física, abajo) |
| C · Contacto | 0,03-0,20 s | Según el resultado del motor, garra a garra: **rebota** si no raya; **arrastra** por el arco del zarpazo si raya (los rayones se dibujan mientras arrastra); **se frena y se queda** 0,12 s si desgarra o raja | rebote: restitución 0,3; arrastre: salida suave; frenazo: parada en 2 fotogramas |
| R · Recuperación | 0,6-1,0 s | El miembro vuelve con sobreimpulso y se asienta; la exhibición se recoge con retraso (solapamiento); la cámara se queda 0,3 s y vuelve a la vista del jugador en 0,5 s | salida suave + rebote amortiguado |

**La velocidad del golpe sale de la física** (core: `core/lab/care_strike.gd`): el miembro parte del reposo empujado por la
fuerza de la garra `F` (el «máximo esfuerzo» del catálogo) con la masa del golpe `m` (`strike.m` del catálogo), a lo largo
del recorrido `d` hasta la lente (la geometría del plano, dibujo). Con fuerza constante: `t = √(2·d·m/F)` y `v = √(2·F·d/m)`.

| Animal | F (N) | m (kg) | d (m, dibujo) | t real (s) | v (m/s) | Cámara lenta (dibujo) | En pantalla (s) |
|---|---|---|---|---|---|---|---|
| Águila | 110 | 1,0 | 0,14 | 0,050 | 5,5 | ×0,25 | 0,20 |
| Halcón | 15 | 0,25 | 0,10 | 0,058 | 3,5 | ×0,29 | 0,20 |
| Arpía | 200 | 1,8 | 0,15 | 0,052 | 5,8 | ×0,26 | 0,20 |
| Buitre | 60 | 1,0 | 0,15 | 0,071 | 4,2 | ×0,36 | 0,20 |
| Búho real | 45 | 0,5 | 0,12 | 0,052 | 4,6 | ×0,26 | 0,20 |
| Lechuza | 8 | 0,08 | 0,08 | 0,040 | 4,0 | ×0,25 (tope) | 0,16 |
| Tigre | 260 | 3,0 | 0,28 | 0,080 | 7,0 | ×0,40 | 0,20 |
| Oso pardo | 300 | 4,0 | 0,32 | 0,092 | 6,9 | ×0,46 | 0,20 |
| Velocirraptor | 381,5 | 9,85 | 0,30 | 0,125 | 4,8 | ×0,63 | 0,20 |

- `F` y `m`: las de `core/lab/data.gd` y `velociraptor.gd` (estimaciones del catálogo, con su texto). El tigre y el oso dan
  ~7 m/s, como el `strike.v` del catálogo (8 y 7 m/s); las rapaces, ~4-6 m/s: tumbadas en la mesa extienden la pata, no
  golpean en vuelo (el `strike.v` de 12 o 40 m/s del catálogo es el de la caza en vuelo y no vale aquí).
- **Un golpe real dura 0,04-0,12 s: 2-7 fotogramas.** Para que se vea, el golpe se enseña a **cámara lenta** (el factor
  que lo lleva a 0,20 s en pantalla, con un tope de ×0,25; dibujo) y el rótulo lo dice: «Cámara lenta ×0,25 · el golpe real dura 0,05 s».
- **La garra reforjada que pesa más** (`ClawMass`): cambia `m` en lo que pesa de más la garra. Con una garra de oro o de
  carburo de tungsteno, unas decenas de gramos frente a 1-4 kg del miembro: el tiempo cambia menos de un 2 %, menos de un
  fotograma a 60 fps. `care_strike.gd` lo dice (`appreciable: false`) y la animación no cambia. Solo se animaría la
  diferencia si pasara de un fotograma (16,7 ms).

### 1.3 La cámara

- **Corte** al plano del zarpazo: desde fuera de la mesa (+X), a la altura del costado de arriba del animal, mirando al
  miembro que golpea (delante) con la cabeza detrás (fondo). Campo 50° (el teléfono, 58°: pantalla estrecha). Por especie:

  | Animal | Distancia a la pata (m) | Alto sobre la mesa (m) | Hacia la cabeza (fracción) | Lente a (m, dibujo) |
  |---|---|---|---|---|
  | Rapaces | 0,30 | 0,16 | 0,45 | 0,14 |
  | Búho y lechuza | 0,28 | 0,15 | 0,45 | 0,12 |
  | Tigre | 0,55 | 0,40 | 0,40 | 0,24 |
  | Oso | 0,62 | 0,46 | 0,40 | 0,28 |
  | Velocirraptor | 0,50 | 0,30 | 0,40 | 0,22 |

- **La lente** es un plano a esa distancia delante de la cámara (el protector de la carcasa, a escala de pantalla: dibujo).
  Las garras la tocan ahí: la separación de los rayones es la de los dedos de ese animal vista a esa distancia (la del
  dibujo, «a escala de la pantalla»).
- **Temblor** en el impacto: hasta 6 px y 0,6° según `intensity`, que se apaga en 0,25 s (ruido con semilla, determinista).
  Se quita en los ajustes.
- **Destello**: un fotograma al 25 % de blanco que se apaga en 0,08 s, centrado en el impacto (también se quita con el
  efecto de la lente).
- **Vuelta**: 0,3 s quieta tras el contacto y 0,5 s de vuelta suave a la vista que tenía el jugador. Con una garra
  desconchada, antes de volver, se acerca 0,4 s a la pata para que se vea el muñón.

### 1.4 Los rayones: de qué garra sale cada uno

Cada rayón es el trazo de la **punta de una garra concreta del modelo 3D** proyectada sobre la lente mientras la toca:
la escena mide la punta en cada fotograma del contacto (`Camera3D.unproject_position`), en coordenadas normalizadas de la
pantalla (0-1), y le pasa el trazo al motor (que guarda el daño de la lente). Las garras que no llegan (`outcome: "nada"`)
no dejan nada. El trazo sigue el arco del zarpazo; las garras se flexionan al agarrar (la última falange gira en su base:
así las del dedo I van contra las demás).

| Animal | Patrón (lo que sale de la geometría y del cierre de los dedos) |
|---|---|
| Rapaces diurnas | Tres arcos cortos y hondos (II, III y IV, que bajan al cerrar) y el del dedo I, opuesto (sube) |
| Búho y lechuza | Dos pares opuestos: II y III bajan; I y IV suben (el dedo IV se gira hacia atrás al agarrar: zigodáctilos) |
| Tigre | Cuatro rayas paralelas y curvas (II, III, IV y V); el dedo I (el espolón) no toca |
| Oso | Cinco rayas largas, rectas y anchas (I a V): el barrido lateral es ancho |
| Velocirraptor | Un tajo hondo de la hoz (II) y dos arañazos menores (III y IV) si el motor dice que llegan |

### 1.5 Lo que se queda en la lente

- **Rayón fino** (`rayon`): casi transparente, refracta poco, con un brillo fino que se mueve un poco con la cámara.
- **Rayón hondo** (`rayon_hondo`): más ancho, con el borde blanquecino de material levantado (plástico) o astillado
  (vidrio) y polvo fino.
- **Desgarro** (`desgarro`, plástico): el surco abierto, con el labio levantado a los dos lados y la zona lechosa.
- **Grieta** (`grieta`, vidrio): estrella desde el punto de impacto con su zona lechosa; no crece sola.
- **Mancha** (`mancha`): huella grasienta de las almohadillas o polvo; es lo único que quita el paño («Limpiar la
  lente», un paño que pasa en 0,7 s).
- Los rayones se acumulan en la lente puesta y no se borran: con el índice `obscuration` del motor (0-1, índice de juego)
  la imagen pierde contraste y nitidez donde están. Otra lente (la tienda de la 5u) llega con su propio daño guardado.
- **Calidad de cada lente** (dibujo, se puede quitar): la de plástico, un poco menos nítida y con algo de viñeta; las de
  vidrio y zafiro, limpias.

### 1.6 Sonido (sincronizado al fotograma)

- Voz de la especie al empezar la anticipación (o en el aviso, más baja): chillido de rapaz, bufido y chasquidos del búho,
  gruñido del tigre, resoplidos del oso, siseo del velocirraptor.
- Roce de plumas o de pelo con el movimiento grande (anticipación y golpe).
- Impacto en T_i según el resultado: chasquido de plástico (raya o rebota en plástico), tintineo de vidrio (rebota en
  vidrio), crujido (grieta), rasguño (arrastre; dura lo que dura el contacto), y el chasquido de la garra que se desconcha.
- Todo por el bus «Lab» (el botón de sonido lo silencia). Sintetizado (`core/lab/sfx_reaction.gd`): es diseño de sonido.

### 1.7 Variantes

Dos o tres por especie, elegidas con `rng.gd` y la semilla `reaccion|<animal>|<seq>`: cambian el punto de la pantalla
donde llega el zarpazo (±0,15 de ancho, ±0,12 de alto), la dirección del arco y el reparto de tiempos (dentro de los
márgenes de la tabla 1.2). Las mismas semillas dan siempre la misma reacción (capturas y tests).

### 1.8 Teléfono

La misma animación, sin los huesos secundarios caros (sin el pelo que sigue con retraso ni el músculo del hombro; las
plumas que se erizan, sí), a 30 fps, y la lente en su versión sencilla: sin refracción ni desenfoque (rayones, grieta y
manchas dibujados encima, con la pérdida de contraste como una veladura).

## 2. Rapaz diurna (águila, halcón, arpía, buitre)

Tumbada de lado sobre el banco (sin capucha ni toalla: si no, no reacciona). Golpea la **pata de arriba** (la derecha).

| Canal | Fotogramas clave (tiempo → valor) | Curva | Qué es |
|---|---|---|---|
| `head_pull` | 0 → 0; A 0,35 → −0,25·cráneo; A 0,9 → +0,15; S fin → +0,35; R 0,6 → 0 | seno | Se encoge (mete la cabeza) y la saca hacia la cámara al golpear |
| `head_turn` | 0 → 0,35 rad (mira a la cámara desde el aviso); R fin → 0 | seno | La cabeza sigue la cámara |
| `jaw` (pico) | A 0,3 → 0; A 0,6 → 0,42 rad; S fin → 0,5; R 0,5 → 0 | seno con rebote | Abre el pico con el chillido |
| `ruffle` (cuello) | A 0 → 0; A 0,7 → 1 (ola de la nuca hacia el pecho, 0,25 s); R 0,8 → 0 | ola | Las plumas del cuello se erizan una a una |
| `wing_lift` | A 0,1 → 0; A 0,75 → 0,55 rad; R 0,9 → 0 | seno + rebote 8 % | Abre el ala de arriba a medias (*mantling*) |
| `wing_fan` | retraso 0,08 s sobre `wing_lift`; máx. 0,45 rad | igual, con retraso | Las primarias se abren con su retraso |
| `tail` | A 0,2 → 0; A 0,8 → −0,25 rad (contra la pata); R 0,7 → 0 | seno | La cola compensa |
| `coil` (pata) | A 0 → 0; A 0,85 → 1 (se recoge: rodilla atrás, tarso plegado) | seno | Anticipación del golpe |
| `strike` | S: 0 → 1 (del recogido a la lente por el arco) | s = (t/T)² | El golpe |
| `claw_flex` | S 0,7 → 0; C fin → 1 (cierran al agarrar); R 0,4 → 0 | salida suave | Las garras se flexionan: I contra II-IV |
| `eye_open` | aviso → 1,15 (muy abiertos); R fin → el de su sedación | — | |
| `nict` | 0 → barrido de 0,12 s; tras el impacto, otro | — | La membrana nictitante |

- **El dedo I primero:** en el último 30 % del golpe el pie gira 10° para que la uña del dedo I llegue antes a la lente.
- **Variantes:** directa (al centro), cruzada (de arriba a abajo, el arco hacia la cabeza) y alta (llega por arriba).

## 3. Rapaz nocturna (búho real, lechuza)

Como la diurna, con su exhibición de defensa: el cuerpo ahuecado y las alas abiertas hacia delante, como una capa.

| Canal | Fotogramas clave | Curva | Qué es |
|---|---|---|---|
| `clack` | aviso y A 0 → A 0,6: 3-4 chasquidos (el pico se abre 0,25 rad y cierra, a ~12 Hz) | pulsos | Chasquido del pico |
| `ruffle` | todo el cuerpo y la cabeza: A 0,6 → 1 | ola | Plumas erizadas (más grande, más redonda) |
| `wing_lift` | A 0,7 → 0,8 rad; `wing_fan` 0,6 rad, con retraso de 0,1 s | seno + rebote | Las alas hacia delante como una capa |
| `head_low` | A 0,5 → −0,3 rad (la cabeza baja y se balancea ±0,12 rad a 2,5 Hz) | seno | La cabeza baja |
| `disc` | A 0,5 → 1: el disco facial se contrae (−8 % de ancho, +4 % de alto: dibujo) | seno | |
| `eye_open` | 1,25 (muy abiertos) | — | |
| `nict` | barridos de 0,12 s al empezar, al golpear y en la recuperación | — | La membrana nictitante |
| `coil`, `strike`, `claw_flex` | como la diurna; el cierre en dos pares (II y III contra I y IV) | | |

- **Variantes:** directa y cruzada (dos; el búho no hace la alta).

## 4. Tigre

Tumbado de lado en la mesa de la clínica. Golpea la **mano de arriba** (la delantera derecha).

| Canal | Fotogramas clave | Curva | Qué es |
|---|---|---|---|
| `ears` | aviso → 1 (orejas aplastadas hacia atrás: 1,1 rad); R fin → 0 (despacio, 0,8 s) | seno | |
| `head_low` | A 0,4 → −0,12 rad (baja la cabeza, el cuerpo bajo); S → +0,08 | seno | |
| `head_turn` | → 0,3 rad hacia la cámara | seno | |
| `jaw` | A 0,5 → 0,32 rad (abre la boca: gruñido); S → 0,4; R 0,6 → 0 | seno | Boca abierta con los colmillos |
| `whisk` | A 0,6 → 0,35 rad (bigotes hacia delante) | seno | |
| `shoulder` | la paletilla que se desliza: el bulto del músculo sigue al brazo (0 → 1 → 0) | — | Solo escritorio |
| `tail` | latigazos ±0,3 rad a 2,2 Hz desde el aviso; en S, el último | seno | La cola que azota |
| `coil` | A 0,85 → 1 (la mano se levanta y se recoge hacia el pecho, la muñeca flexionada) | seno | |
| `strike` | S: el zarpazo por un arco de arriba-atrás a delante-abajo | s = (t/T)² | |
| `claw_out` | S 0,55 → 0; S 0,9 → 1 (**las uñas salen** de la vaina en 0,05 s, antes de tocar) ; R 0,5 → 1; R 0,9 → 0 (se recogen) | salida suave | Uñas retráctiles |
| `claw_flex` | C → 0,6 (enganchan) | | |

- **Variantes:** directa, en gancho (el arco más de lado) y finta (medio zarpazo, 0,1 s de pausa y el de verdad).

## 5. Oso pardo

Golpea la mano de arriba con un **barrido lateral, ancho y pesado**; las garras, rectas y largas, siempre fuera.

| Canal | Fotogramas clave | Curva | Qué es |
|---|---|---|---|
| `roll` | A 0 → 0; A 0,8 → 0,16 rad (**se levanta un poco**: rueda hacia el pecho); R 0,3 → 0 con caída y rebote | seno; caída: aceleración + rebote | |
| `head_lift` | A 0,7 → 0,25 rad hacia la cámara | seno | |
| `jaw` | aviso: resoplidos (0,1 rad, 2-3 pulsos); A 0,6 → 0,35 rad | pulsos | Resopla y abre la boca |
| `huff` | vaho en cada resoplido (dibujo, tenue: a 20 °C no se vería) | partículas | |
| `ears` | → 0,6 rad atrás | seno | |
| `coil` | A 0,9 → 1 (el brazo se abre hacia fuera y arriba: el impulso del barrido) | seno | |
| `strike` | S: barrido de lado a lado por un arco ancho y casi plano | s = (t/T)² | |
| `lag` | el pelo y la grasa del brazo siguen con retraso (muelle de 6 Hz, amortiguado 0,35) | muelle | Solo escritorio |
| `claw_flex` | C → 0,3 | | |

- **Recupera dejándose caer:** `roll` vuelve a 0 con aceleración (cae) y un rebote del 10 %.
- **Variantes:** de izquierda a derecha, de derecha a izquierda, y alta (el barrido baja en diagonal).

## 6. Velocirraptor (el de cine, marcado como ficción; la reconstrucción, igual con sus plumas)

Golpea con la **pata de arriba**: patada con la hoz del dedo II por delante.

| Canal | Fotogramas clave | Curva | Qué es |
|---|---|---|---|
| `sickle` | aviso → +0,45 rad (levanta la hoz); S 0,6 → +0,6; S fin → −0,35 (la hoz baja y corta); R 0,6 → 0 | seno; en S, rápida | |
| `arms` | A 0,6 → 0,7 rad (abre los brazos con sus plumas); R 0,8 → 0 | seno + rebote | |
| `jaw` | A 0,5 → 0,45 rad (siseo) | seno | |
| `tail` | el cuerpo gira 4° en la cadera contra la patada: la cola rígida hace de contrapeso | seno | |
| `coil` | A 0,85 → 1 (rodilla al pecho, el metatarso plegado) | seno | |
| `strike` | S: la patada, con la rodilla que se estira (dos huesos, fémur y tibia) | s = (t/T)² | |

- **Variantes:** directa y alta (dos).
- El rótulo de la reacción dice «ficción (película)» si el dibujo es el de cine.

## 7. Sincronía con el motor (lo que cuenta en el fotograma del impacto)

1. En T_i (el último fotograma del golpe) se dispara el impacto: temblor, destello, sonido y el primer punto de cada rayón.
2. Durante el contacto, cada fotograma añade un punto a cada trazo; los rayones se dibujan a la vez que avanza la garra.
3. Al acabar el contacto, la escena entrega los trazos (`strokes`) para que el motor los guarde con su anchura y su hondura.
4. Si `clawChips` (o `chips` en una garra): esquirlas que saltan con `rng.gd` (deterministas: misma semilla, mismas
   esquirlas), del color y el material de la garra, con gravedad, y el rótulo «la garra de … se ha desconchado».

## 8. Lo que es dibujo

Las distancias de la cámara y de la lente, los ángulos de cada pose, las curvas, el factor de cámara lenta, el temblor, el
destello, el vaho, el sonido y el aspecto de la lente. Lo que sale del motor: el resultado de cada garra (raya, raya hondo,
desgarra, raja, mancha o nada), la anchura y la hondura de cada rayón, si se desconcha y el índice `obscuration`; y del
catálogo, la fuerza y la masa del golpe.

## 9. Cada garra, su golpe y su marca (17-10, petición de Eric)

- **El dedo del golpe llega primero** (`Reaction.IMPACT_FINGER` del motor): la mano o el pie gira alrededor del centro de
  las puntas (`lead` de `reaction_keys.gd`, dibujo) hasta que esa garra es la más cercana a la lente: el I de las rapaces
  (0,35 rad: las garras por delante, el pulgar el primero), el I de las nocturnas (0,3), el III del tigre (0,15), el III
  del oso (0,08: golpea con la mano entera) y la hoz del velocirraptor (0,4). El destello y la grieta salen de esa garra.
- **Cada garra raya solo su tramo**: la parte del contacto en que aprieta más de lo que pide marcar la lente, tan larga
  como `lengthMm / SWIPE_MM` del motor (al menos el 20 % del contacto, para que se vea); la del golpe empieza un poco
  antes (centrada en el 45 % del contacto) y las demás después (55 %). Lo que se pasa al motor (`lens_record`) es ese
  tramo; la que raja la lente, desde el punto del golpe.
- **La rapaz nocturna ataca en silencio**: su voz (el chasquido del pico y el bufido) es del aviso; en el zarpazo no suena.
- **La pausa para calmarlo** (`view().animal.resting`, de la 5t-A): entra en 1,2 s y sale en 0,8 s; los ojos entornados,
  la cabeza apoyada y, en las aves, la membrana nictitante a medias; un velo oscuro (alfa 0,32 en las rapaces, la mitad en
  los demás: la penumbra que las calma, como el capirote) y la respiración a 0,55 de su ritmo. Todo, dibujo.

## 10. Segunda vuelta (17-10, control de calidad del coordinador)

- **El plano del águila**, más abierto (a 0,2 m de las garras y algo más alto): se ven la anticipación, las garras y la
  cabeza; el muslo ya no llena la vista.
- **Las marcas caben en la vista**: si el dibujo entero (de donde empiezan a donde acaba el arrastre) se sale, se mueve
  hasta dejar un margen de 0,08; el oso arrastra menos (0,35).
- **Si no raya, se dice por qué** (core/lab/care_reaction_text.gd, con las durezas de las fichas): «La queratina del oso
  pardo (26 HV) es apenas más dura que el metacrilato (22 HV): lo mancha y lo raja, pero no lo raya». La grasa de la
  almohadilla deja su rastro a lo largo del trazo.
- **El paño**: una almohadilla de microfibra desenfocada (está pegada a la lente) que cruza en arco, con pliegues, trama y
  la sombra del borde (lens_cloth.gdshaderinc).
- **El sonido, con margen**: los picos de los efectos ≤ 0,63 y la voz y el golpe a 0,6 de volumen en la escena: juntos no
  pasan de ~0,8.
- **La probabilidad de que se revuelva** (view().animal.attackChance, juego), discreta junto a la lente.
- **Las plumas se erizan** en la amenaza y el ataque (ruffle de body_feather.gdshader: cada pluma se separa del cuerpo
  por la punta, un 28 % de su largo como mucho, con azar por pluma; dibujo).
- **El tigre, con las uñas a la vista**: en el impacto la mano llega ladeada hacia la cámara (tilt −0,7 rad, dibujo) y no
  las cierra en el contacto, para que se vean fuera de la vaina.
- **La presentación** (caso 9 de demo_reaccion.tscn, ~13 s): la amenaza y el zarpazo del tigre, el del águila con garra de
  acero sobre la misma lente, el paño y la pausa para calmarlo.
