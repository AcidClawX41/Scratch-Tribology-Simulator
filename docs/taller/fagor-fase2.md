# Taller · control Fagor 8055 T, fase 2

Compensación del radio de la punta (G40, G41, G42), roscado (G33 y el ciclo G86), subrutinas y repeticiones, y la
pieza C con rosca. Es la continuación del intérprete de la unidad 4 (`docs/taller/fuentes-u4.md`): el mismo contrato
(el intérprete emite la punta teórica en el IR y el torno la sigue) y las mismas reglas (sintaxis citada del manual,
lo que no se puede confirmar queda pendiente, errores en español con la línea y el bloque N).

Código: `godot/core/taller/gcode.gd` (intérprete), `gcode_comp.gd` (compensación), `gcode_cycles.gd` (G86),
`gcode_programs.gd` (programas), `lathe_tools.gd` (herramienta de roscar), `lathe.gd` (roscado en el torno),
`drawing.gd` e `inspection.gd` (plano e inspección de la pieza C). Tests: `godot/tests/taller/test_gcode_fase2.gd`,
`test_drawing.gd` y `godot/tests/integration/test_taller_pipeline.gd`.

## Fuentes

| Fuente | Qué se ha sacado |
|---|---|
| Fagor Automation, *CNC 8055 ·T· Programming manual*, Ref. 1110, Soft V01.3x (2011). Páginas numeradas de corrido. | G33 (6.12, p. 92), compensación (8.2, p. 128-146), G86 y G87 (9.9 y 9.10, p. 187-193), bloque y repeticiones (2.1.3, p. 34), instrucciones de control (12.4 y 12.5, p. 287-294). |
| Fagor Automation, *Manual de programación FAGOR CNC 8055 T*, Ref. 9806 (cas) (1998). | Ejemplo de mecanizado en diámetros con compensación (cap. 8, p. 14), usado como test. |
| Fagor Automation, *CNC 8055 ·T· Installation manual*, Ref. 1006. | COMPTYPE (P74, p. 119-121) y COMPMODE (P175, p. 154-155). |
| FANUC, *Series 0i-MODEL F, For Lathe System, Operator's manual* B-64604EN-1/01. | Tabla 2(a) de códigos G (p. 13-15), G32 (3.2, p. 24), G92 (4.1.2, p. 37), G76 (4.2.7, p. 82) y la punta imaginaria (5.2.2, p. 155), solo para el contraste. |
| ISO 68-1 (perfil básico de la rosca métrica ISO) e ISO 965-1 (tolerancias, clase 6g); límites de M20×2,5-6g de ASME B1.13M vía AmesWeb. | H = 0,866·P, h3 = 0,6134·P, radio de fondo H/6; d 19,958/19,623, d2 18,334/18,164, d3 16,891/16,624. |
| Sandvik Coromant, CoroThread 266, tabla «Metric 60° Full form» (plaquitas exteriores a derechas). | 266RG-16MM01A250M: TP 2,5, HA 1,87, HB 0,36, ISO 965-1998 clase 6. |
| Fichas de distribuidores del portaherramientas Sandvik 266RFG-2525-16. | Mango 25 × 25, 150 mm, cabeza de 22,2 mm, 32 mm de la cara trasera del mango al filo (calidad secundaria). |

## 1. Compensación del radio de la punta (G40, G41, G42)

**Qué hace el 8055 T** (p. 128-146). El programa se escribe con la punta teórica P (la esquina de los dos lados con
los que se midió la herramienta). Sin compensación, P recorre el contorno y el redondeo de la punta deja el error en
los chaflanes, conos y arcos (p. 132). Con G41 (herramienta a la izquierda de la pieza según el sentido del mecanizado)
o G42 (a la derecha), el CNC toma el radio R y el código de forma F del corrector activo (8.2.3, p. 133) y lleva el
centro de la punta a R del contorno. En el plano del dibujo (Z a la derecha, X hacia arriba), cilindrar por fuera hacia
el plato es G42.

**Contrato.** El IR sigue siendo la punta teórica: `P = centro − v(F)`, con `v` el vector de la punta teórica al
centro en unidades de R. Cada movimiento compensado lleva `comp: { side: "G42", r, f, vz, vr }` para que la vista 2D
pinte el centro (`punta + (vz, vr)`). El torno no cambia: estampa con el centro de la punta de la herramienta montada.

**Códigos de forma** (8.2.1, p. 129-130), con X hacia arriba y Z a la derecha. `v` = centro − punta teórica:

| F | v (dz, dr) | Punta teórica respecto al centro | Punta imaginaria Fanuc equivalente |
|---|---|---|---|
| F0, F9 | (0, 0) | en el centro | 0 y 9 |
| F1 | (−1, +1) | abajo a la derecha | 4 |
| F2 | (0, +1) | abajo | 8 |
| **F3** | (+1, +1) | abajo a la izquierda (torneado exterior estándar: centro en (rε, rε)) | **3** |
| F4 | (+1, 0) | a la izquierda | 7 |
| F5 | (+1, −1) | arriba a la izquierda | 2 |
| **F6** | (0, −1) | arriba | **6** |
| F7 | (−1, −1) | arriba a la derecha | 1 |
| F8 | (−1, 0) | a la derecha | 5 |
| **F62**, F64, F66, F68 | (0, +1), (+1, 0), (0, −1), (−1, 0) | roscar: la punta en el eje de la V | — |

Solo F3 y F6 coinciden con la numeración de Fanuc (fig. 5.2.2 (a), p. 155): un corrector copiado de un Fanuc a un
Fagor con el mismo número compensa hacia otro lado. Las familias de ranurar (F21-F39), las plaquitas redondas
(F40-F59) y las brocas no están en el simulador: dan «no soportado en este simulador (fase 2)».

**Inicio y final** según COMPTYPE (P74, manual de instalación p. 119-121; por defecto 0): con una esquina convexa entre
el bloque de entrada y el primer tramo, con 0 la herramienta llega a la perpendicular de la entrada y bordea la
esquina; con 1 va directa a la perpendicular del primer tramo en su punto inicial. En una esquina cóncava las dos
formas coinciden (p. 135). La salida con G40 es simétrica (p. 138-140). G41/G42 en un bloque sin movimiento: el
primer tramo se compensa desde su punto inicial (p. 134).

**Esquinas** (8.2.5, p. 137) según COMPMODE (P175, p. 154-155; por defecto 0): las cóncavas, en la intersección de las
trayectorias desplazadas; las convexas, con 0, tramos rectos hasta 300° entre trayectorias (120° de giro) y arco por
encima; con 1, siempre arco alrededor del vértice; con 2, la intersección hasta 300°.

**G00** anula la compensación temporalmente (8.2.7, p. 142): lo pendiente acaba en la perpendicular de su final, el
rápido va sin compensar y el G01 siguiente es otra entrada. **G04 sin K, M30/M02 y los ciclos G68/G69/G86** la
anulan con un aviso (p. 133 y 192). **RPT** no la anula (p. 289): la pieza B con G42 repite el perfil con
`(RPT N200, N260)` y la compensación sigue.

**Errores** con la línea y el N: G41/G42/G40 con G02/G03 en el bloque (p. 134 y 138); un tramo más corto de lo que
exige el radio (se recorrería al revés: el 8055 real lo resuelve con la detección de colisiones G41 N, 8.3, p. 146);
el radio de la punta mayor que un arco cóncavo; trayectorias desplazadas que no se cortan.

**Decisiones del simulador** (lectura de las figuras de las p. 135-139, no texto literal del manual):
- Los «tramos rectos» de COMPMODE 0 prolongan cada trayectoria desplazada hasta la intersección, como mucho R (con 90°
  es la esquina en escuadra de la figura de la p. 137), y las unen con una cuerda si no se cortan antes.
- Una vuelta atrás completa (180°) se trata como esquina convexa (la herramienta rodea el vértice).
- Sin tabla de correctores (o con D0), la compensación toma R0 F0 y no desplaza nada (p. 133), con un aviso.

**Fase 2 pendiente** («no soportado»): cambiar de G41 a G42 sin G40 (8.2.8, p. 144), cambiar de herramienta o de
corrector con la compensación activa, la detección de colisiones G41 N/G42 N (8.3), la compensación dentro de G68/G69
(el acabado H del ciclo sigue sin compensar: el intérprete lo avisa y sugiere acabar aparte con G42) y G81/G82 con la
compensación activa.

### Resultado en las piezas A y B

Del programa al plano con el modelo de corte de verdad (`test_taller_pipeline.gd`):

| Pieza | Sin compensación (pieza_a, pieza_b) | Con G42 (pieza_a_g42, pieza_b_g42) |
|---|---|---|
| A · chaflán 1×45° | 0,759 mm · nota 9,6 | 0,993 mm (resolución de la rejilla, 0,02 mm) · nota 10 |
| B · R2 cóncavo | 2,821 mm (R + rε) | 2,021 mm |
| B · inicio del cono (35) | 34,369 mm | 34,990 mm |
| B · nota | 8 | 10 |

La pieza B con G42 desbasta con G68 sin H y acaba repitiendo el perfil con `(RPT N200, N260)` y G42; la A con G42
refrenta con G82 hasta Q-1.6 (X−2·rε) para no dejar pezón.

## 2. Roscado

### G33, roscado electrónico (6.12, p. 92)

`G33 X Z L Q`: L es el paso (L5.5) a lo largo de Z y Q (±3.5) la posición angular del cabezal en el punto inicial. El
IR lleva `type: "thread"`, avance por vuelta sobre la trayectoria `L·longitud/|ΔZ|` (un paso por vuelta en Z) y
`thread: { pitch, start_deg, sync, pass, passes, depth, total, kind, infeed_deg }` con `pass: 4` (roscado). Solo el
primer G33 de una serie espera al cabezal (`sync`): los encadenados siguen la misma hélice. G33 exige el cabezal en
marcha y no admite la compensación.

### G86, ciclo fijo de roscado longitudinal (9.9, p. 187-192)

`G86 X Z Q R K I B E D L C J A W V M H U`. Lo que hace el simulador:

- **Pasadas** (p. 188): con B > 0, las penetraciones son B, B√2, B√3…, con un incremento de al menos E; con B < 0,
  |B| en cada pasada. La última de desbaste llega justo a I − |L| (se da una pasada con lo que falta) y detrás va el
  acabado hasta I: con L > 0 con el mismo ángulo A, con L < 0 radial y con L = 0 repitiendo la última pasada.
- **Paso** C: positivo, medido sobre el cono; negativo, sobre el eje Z (p. 188-189).
- **Salida** J (p. 189): J > 0, en diagonal desde el punto J hasta la distancia de seguridad; J < 0, hasta el final de
  la rosca (R, Q) y luego en X; J = 0, rosca ciega (sale en X). La salida va sincronizada (sigue en la hélice).
- **Penetración** A (p. 189): 30° si no se programa; 0, radial. Lectura del simulador de la figura de la p. 187: la
  pasada de profundidad d empieza desplazada −d·tan A en Z (hacia el plato), así que la herramienta baja paralela al
  flanco de detrás y corta con el filo de delante; como todas las pasadas esperan al mismo ángulo del cabezal, el
  desplazamiento mueve el surco dentro de la misma hélice.
- **Funcionamiento** (9.9.1, p. 192): G00 al punto de aproximación (Z, X + D); en cada pasada, G00 a la profundidad,
  roscado sincronizado y vuelta en G00 al punto de aproximación a la distancia D del tramo roscado. El ciclo acaba en
  el punto de aproximación y anula la compensación (p. 192).
- **Errores** con su página: I = 0 (p. 187), B = 0 (p. 188), C = 0 (p. 189), A ≥ 60°, L ≥ I, J tan larga como la rosca.
- **No soportado (fase 2)**: rosca interior (I < 0: el torno simulado no tiene barras de interior), reparación K/W y U,
  paso variable M, tipos de entrada H y zigzag (A < 0), varias entradas V (se pueden hacer con varios G86 que solo
  cambien W, p. 190) y roscar alejándose del plato. **G87** (roscado frontal, p. 193) no cabe en el modelo
  axisimétrico: la espiral de la cara no es una sección r(z).

### El roscado en el torno

`lathe.gd` estampa la herramienta una vez por vuelta del cabezal, como ve la pieza una sección angular fija. Al
roscar, el avance por vuelta es el paso, así que la sección ve un diente en V cada paso: **el perfil r(z) es la
sección axial de la rosca**. Antes de cada pasada el torno espera a que el cabezal llegue a `start_deg` (la hélice
existe en el tiempo, no en la geometría: es la limitación del modelo axisimétrico). Al final de un tramo de roscado no
se estampa el punto final (no cae en la sección). Los anillos roscados llevan `ring_pass = 4`.

La viruta del roscado no es la del cilindrado: el espesor es `h = A/b`, con `A = ΔV/(2π·r)` el área de la viruta de
esa vuelta y `b` el largo de filo que ha cortado de verdad (medido en el propio estampado), y la ap de la pasada es la
extensión radial de lo que corta la V. La ap máxima de la plaquita es su altura de perfil HA = 1,87 mm.

En la escena 3D, `acabado.gdshader` convierte los anillos roscados en la hélice adelantando cada vértice paso·θ/2π a lo
largo del eje (el paso lleva el signo del giro). El perfil se repite cada paso, así que la costura de θ = ±π no se ve
en la rosca completa; sí en la entrada y en la salida de rosca, donde el perfil no es periódico.

### La herramienta

Portaherramientas Sandvik 266RFG-2525-16 con la plaquita 266RG-16MM01A250M (perfil métrico de 60°, paso 2,5):
κr = κr' = 60° (cada flanco a 30° del radio), rε = H/6 = 0,361 mm (el radio de fondo del perfil básico de ISO 68-1,
el que copia una plaquita de perfil completo), código de forma F62 (centro de la punta en (0, rε)). El largo de filo
útil llega a la altura de perfil HA = 1,87 mm sobre la punta. Estimaciones: el polígono del portaherramientas, la
ap mínima y la recomendada, y el ic y el espesor de la plaquita (no están en la tabla consultada).

## 3. Subrutinas, repeticiones y saltos (capítulo 12)

- `(SUB n)` … `(RET)` define la subrutina n (0-9999; las OEM 10000-20000, fase 2) (p. 291). Dos con el mismo número son
  un error. En el simulador las subrutinas se escriben detrás del M30 (como el ejemplo de la p. 292); si la ejecución
  llega a una definición, error y salta hasta su (RET).
- `(CALL n)` (p. 292), `(RPT N a, N b) N veces` (p. 289: repite los bloques de la etiqueta a a la b y sigue detrás del
  RPT; N0 no repite nada) y `(GOTO N a)` (p. 289).
- 15 niveles de anidamiento compartidos por CALL y RPT (p. 292): el nivel 16 da un error en el bloque que lo pide y el
  programa sigue. Un tope de 100 000 bloques ejecutados corta los saltos sin fin.
- Una instrucción de alto nivel va sola en su bloque; detrás solo puede ir el número de repeticiones N, y el simulador
  solo lo admite en (RPT) (p. 34 y 289).
- Fase 2: PCALL, MCALL, MDOFF, IF, MSG, ERROR, EXEC, MEXEC, OPEN, WRITE, las asignaciones a parámetros y las
  expresiones: «no soportado» con lo que son.

## 4. Pieza C · tornillo M20×2,5-6g

Bruto Ø30 × 75 de C45E con 25 mm en el plato. Chaflán de entrada 1,5×45° (del Ø16,79, por debajo del fondo de la
rosca, al Ø19,79), rosca M20×2,5-6g con 20 mm de rosca completa como mínimo, cuello Ø19,79 hasta Z−32, Ø26 ±0,1 hasta
Z−45 y collar de bruto. El programa (`pieza_c`): refrentado con G82 hasta X−2·rε, desbaste con G81, acabado con G42 en
la subrutina 10 (`(CALL 10)`) y la rosca con
`G86 X19.79 Z5 Q19.79 R-24 I1.49 B0.4 E0.05 D1 L0.05 C2.5 J2.5 A30` (14 pasadas, 1000 rpm: 2500 mm/min).

La profundidad: h3 = 0,6134·P = 1,534 mm se cuenta desde el Ø nominal 20. El Ø exterior se tornea a 19,79 (centro de
19,623-19,958) y, con la V de 60° y fondo H/6, el Ø medio es `d2 = 2·(r_fondo + 0,7217)`: con I = 1,49 desde el Ø19,79
queda en 18,25, el centro de 18,164-18,334.

**Inspección** (`inspection.gd`): en la zona roscada se buscan los surcos (anillos por debajo de la cresta) y se mide
el Ø exterior sobre las crestas, el Ø de fondo en los surcos de profundidad completa, el paso por ajuste de sus
centros (a media altura, con interpolación entre anillos), el Ø medio donde el surco mide medio paso (la definición
del Ø medio simple) y la rosca completa, de la cara al último surco de profundidad completa. El error de paso no
tiene tolerancia propia en ISO 965-1 (lo absorbe Td2): el plano usa ±Td2/cot 30° = ±0,098 mm, derivado.

Resultado del programa al plano: d 19,794 · d2 18,253 · d3 16,810 · P 2,5000 · rosca completa 20,85 mm · nota 10.

## 5. Contraste con Fanuc (dialecto fanucT, solo tabla)

| Código | Fanuc T (sistema A) | Fagor 8055 T |
|---|---|---|
| G41/G42 | compensación del radio de la punta | lo mismo, pero la punta imaginaria (OFT 0-9) no se numera como el código de forma F: solo coinciden el 3 y el 6 |
| G32 | roscado de paso constante `G32 X Z F` | avance como función inversa del tiempo; el roscado es `G33 X Z L` |
| G92 | ciclo de roscado | preselección de cotas o tope de rpm (G92 S) |
| G76 | ciclo de roscado de varias pasadas | palpación; el roscado de varias pasadas es G86 |
| G70/G71 | ciclos de acabado y desbaste | pulgadas y milímetros; el desbaste es G68/G69 |

## 6. Límites del modelo

- La rosca es la sección axial de un modelo axisimétrico: la hélice solo existe en el tiempo (sincronización de las
  pasadas) y en el dibujo 3D. No hay error de avance del cabezal, ni flexión, ni rebaba en los flancos.
- La plaquita de roscar es una V de flancos rectos con la punta redonda: no forma la cresta (el Ø exterior es el del
  torneado previo), como una plaquita en V; la de perfil completo real sí la forma (la redondea a la vez que el fondo).
- La compensación se calcula en el intérprete, bloque a bloque, con el bloque siguiente (el 8055 lee más bloques por
  delante para la detección de colisiones, que aquí no hay).
- COMPMODE 0 y los tramos rectos de las esquinas convexas son una lectura de la figura de la p. 137.
