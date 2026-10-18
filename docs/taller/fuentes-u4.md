# Unidad 4 · Control compatible con el Fagor 8055 T · fuentes

El taller lee programas del CNC **Fagor 8055 T / 8055i T**, el control de la FP de Diseño en Fabricación
Mecánica, y los convierte en la trayectoria (IR) que consume el torno (`godot/CONTRATOS.md`).

| Archivo | Qué hay |
|---|---|
| `godot/core/taller/gcode.gd` | Lector de bloques (`parse_program`) e intérprete (`interpret_program`, `summarize`, `arc_center`) |
| `godot/core/taller/gcode_cycles.gd` | Ciclos G68, G69, G81 y G82 expandidos a movimientos |
| `godot/core/taller/gcode_dialects.gd` | `DIALECTS.fagor8055t` (semántica y página de cada código) y `DIALECTS.fanucT` (contraste, no ejecutable) |
| `godot/core/taller/gcode_programs.gd` | `EXAMPLE_PROGRAMS`: piezas A y B y un programa con 3 errores didácticos |
| `godot/tests/taller/test_gcode.gd` | 19 tests |

**API.**
- `parse_program(text, dialect = "fagor8055t")` devuelve `{ blocks: [{ n, line, words, comment, … }], errors, warnings }`.
- `interpret_program(text, { dialect, tools, machine, start })` devuelve `{ moves, errors, warnings, summary }`.
  - `moves` es el IR de CONTRATOS.md.
  - `summary` es `{ rapid_mm, feed_mm, time_s }`.
- Errores y avisos: `{ line, n, code, message }`. El mensaje está en español y empieza por «Línea L (Nn):».
- Lo que no hace el MVP da el error «no soportado en este simulador (fase 2)». Un bloque con errores no se
  ejecuta, pero el programa sigue.

## Fuentes

| Id | Documento | Dónde |
|---|---|---|
| F1 | Fagor Automation, *CNC 8055 ·T· Programming manual*, Ref. 1110, Soft V01.3x (2011). Páginas numeradas de corrido (coinciden con las del PDF). | [copia pública del PDF oficial](https://www.endo.com.tr/extras/dosya-merkezi/OTOMASYON/FAGOR/8055m/man_8055t_prg.pdf) |
| F2 | Fagor Automation, *FAGOR CNC 8055 T · Manual de programación*, Ref. 9806 (cas) (1998). Numerado por capítulos. En el PDF va detrás del manual de operación; se da también la página del PDF. | [8055torno.pdf](http://www.etitudela.com/profesores/jfcm/mipagina/downloads/8055torno.pdf) |
| F3 | Fagor Automation, *CNC 8055 M & T · Manual de instalación*, Ref. 1006, Soft V01.0x (2010) | [PDF](https://www.drivesul.com.br/template/imagens/manuais/manuais-fagor/fagor-cnc-8055/Fagor%20CNC%208055%20M_T%20Series%20-%20Installation%20Manual%20(Espanhol).pdf) |
| F4 | Fagor Automation, *FAGOR CNC 8050 T · Manual de operación y de programación*, Ref. 9701 (cas) (1997) | [man_8050t_cast.pdf](https://egela.oteitzalp.org/pluginfile.php/6268/mod_resource/content/1/man_8050t_cast.pdf) |
| F5 | Fagor Automation, *FAGOR CNC 8025/8030 modelos T, TG, TS · Manual de operación y de programación*, Ref. 9701 (cas) | [8025torno.pdf](http://www.etitudela.com/profesores/jfcm/mipagina/downloads/8025torno.pdf) |
| N1 | FANUC, *FANUC Series 0i-MODEL F For Lathe System · Operator's manual*, B-64604EN-1/01 | [PDF](https://www.drivesul.com.br/template/imagens/manuais/manuais-fanuc/fanuc-series-0i-model-f/FANUC%20Series%200i%20MODEL%20F%20-%20OPERATOR_S%20MANUAL%20-%20Lathe%20System.pdf) |

Los PDF son de Fagor Automation y de FANUC. Las copias enlazadas son de terceros y solo sirven de referencia: el
repositorio no incluye ninguno.

## Códigos del MVP y dónde los define el manual

| Código | Qué hace el simulador | F1 (2011) | F2 (1998) | Estado |
|---|---|---|---|---|
| `N` | Etiqueta al principio del bloque, N0-99999999. Las de G66, G68 y G69 son de 4 cifras. | 2.1.1, p. 32 | cap. 2, p. 2 (N0-9999), PDF 248 | confirmado |
| `;` | Comentario hasta el final del bloque. Un bloque que empieza por «;» no se ejecuta. | 2.1.3, p. 34 | cap. 2, p. 4, PDF 250 | confirmado |
| formato | Admite espacios. Se puede omitir un 0 (G = G00, X = X0) y el signo +. | cap. 2, p. 31; 6.1, p. 78 | cap. 2, p. 1 | confirmado |
| orden | Dentro del bloque: funciones G, cotas, F, S, T, D y M. La G, siempre al principio. | cap. 5, p. 59-60 | cap. 5, p. 1 y 8 | confirmado |
| `G00` | Rápido en línea recta, modal | 6.1, p. 78 | cap. 6, p. 2 | confirmado |
| `G01` | Interpolación lineal al avance F, modal | 6.2, p. 79 | cap. 6, p. 3 | confirmado |
| `G02` `G03` | Arco con I, K (en radios y respecto al inicio; si faltan valen 0) o con R (+ si es menor de 180°, − si es mayor). Con R, la circunferencia completa es error. Radios de inicio y final dentro de CIRINERR. | 6.3, p. 80-83 | cap. 6, p. 4-8 | confirmado |
| `G04` | `G04 K` espera en centésimas de segundo (K5), al comienzo del bloque. `G04` sola solo detiene la preparación de bloques. | 7.1-7.2, p. 107-110 | cap. 7, p. 1 y 3 | confirmado |
| `G70` `G71` | Pulgadas o milímetros (×25.4), modales. No son ciclos. | 3.3, p. 39 | cap. 3, p. 5 | confirmado |
| `G90` `G91` | Absolutas o incrementales. En diámetro, el incremento de X también va en diámetro. | 3.4, p. 40 | cap. 3, p. 6 | confirmado |
| `G92 S` | Tope de rpm, solo en su bloque. A partir de él no se acepta una S mayor. | 4.4.1, p. 55 | cap. 4, p. 6 | confirmado |
| `G94` `G95` | Avance en mm/min o en mm/rev | 5.2.1-5.2.2, p. 63-64 | cap. 5, p. 4-5 | confirmado |
| `G96` | S en m/min. Sin S, la última de G96; sin ninguna anterior, error. | 5.3.1, p. 66 | cap. 5, p. 7 | confirmado |
| `G97` | S en rpm. Sin S, se queda con las rpm a las que gira en ese momento. | 5.3.2, p. 67 | cap. 5, p. 7 | confirmado |
| `G151` `G152` | X en diámetros o en radios | 3.5, p. 41 | no está: en 1998 lo fijaba el parámetro DFORMAT | confirmado en F1 |
| `G68` | Desbaste en X con perfil: `G68 X Z C D L M K F H S E Q` | 9.2, p. 154-160 | cap. 9, p. 9-16, PDF 361-368 | confirmado |
| `G69` | Desbaste en Z con perfil: `G69 X Z C D L M K F H S E Q` | 9.3, p. 161-167 | cap. 9, p. 17-25, PDF 369-377 | confirmado |
| `G81` | Torneado de tramos rectos: `G81 X Z Q R C D L M F H` | 9.4, p. 168-171 | cap. 9, p. 26-29, PDF 378-381 | confirmado |
| `G82` | Refrentado de tramos rectos: `G82 X Z Q R C D L M F H` | 9.5, p. 172-175 | cap. 9, p. 30-33, PDF 382-385 | confirmado |
| `T` `D` | T4 y D4. Con T sola se usa el corrector asociado en la tabla. | 5.6, p. 70-71 | cap. 5, p. 11-12 | confirmado |
| `F` | Formato 5.5. F0, o no programar F, es el avance máximo MAXFEED. | 5.2, p. 62 | cap. 5, p. 8 | confirmado |
| `S` | Formato S5.4 | 5.3, p. 65 | cap. 5, p. 9 | confirmado |
| `M03` `M04` `M05` | Cabezal a derechas, a izquierdas o parado | 5.7.5-5.7.7, p. 73 | cap. 5, p. 16 | confirmado |
| `M30` | Fin de programa. También hace M05. El simulador admite además M02, que hace lo mismo. | 5.7.3-5.7.4, p. 73 | cap. 5, p. 16 | confirmado |
| `M08` `M09` | Refrigerante sí y no | solo aparecen entre las M con estado propio (variable MSn, 11.2.19, p. 274) | — | **pendiente** |

**Recuento:** de los 31 códigos del MVP, 29 están confirmados en el manual. Faltan M08 y M09.
- El manual de programación no define M08 ni M09.
- En el 8055, las funciones M sin significado interno las define el fabricante en la tabla de funciones M (5.7,
  p. 72).
- Que sirvan para el refrigerante es la convención ISO 6983-1, que no he podido comprobar. Por eso quedan como
  pendiente.

Diferencias entre ediciones que afectan al MVP:
- En 1998, el centro del arco (I, K) había que programarlo siempre, aunque valiera cero (cap. 6, p. 5). En 2011,
  lo que no se programa vale cero (p. 80). El simulador sigue la edición de 2011.

## G68/G69: parámetros del 8055 y el formato P0…P14 del encargo

El encargo describía G68/G69 «con sus parámetros P» (P13 y P14 como etiquetas del perfil). Esa sintaxis **no es
la del 8055**:
- Las dos ediciones del manual del 8055 T usan letras: `G68 X Z C D L M K F H S E Q` (F1, p. 154; F2, cap. 9,
  p. 9).
- El 8050 T también usa letras, todavía sin K: `G68 X Z C D L M F H S E Q` (F4, cap. 9.2, PDF 357).
- `N4 G68 P0=K P1=K P5=K P7=K P8=K P9=K P13=K P14=K` es el formato del **Fagor 8025/8030** (F5, cap. 14.2,
  p. 162-163).

El simulador ejecuta la sintaxis del 8055. Un G68 escrito con P da un error que explica esta diferencia.

| 8055 (F1, p. 154-156) | Significado en el 8055 | 8025/8030 (F5, p. 162-163) |
|---|---|---|
| X | Cota X del punto inicial del perfil: absoluta, en radio o en diámetro según el modo activo | P0 |
| Z | Cota Z del punto inicial del perfil, absoluta | P1 |
| C | Paso, positivo y en radios en G68. Todas las pasadas son de paso C salvo la última, que quita el sobrante. C0 es error. | P5, paso máximo en radios. El 8025 hace pasadas iguales de paso ≤ P5. |
| D | Distancia de seguridad. D ≠ 0: retirada a 45°. D = 0: sale por el camino de entrada. Sin D: sigue el perfil hasta la pasada anterior. | — |
| L | Demasía en X, en radios. Negativa: el acabado se hace en arista matada (G05). | P7 |
| M | Demasía en Z. Si no se programa, la demasía L es constante en todo el perfil. | P8 |
| K | Avance de penetración en los valles | — |
| F | Avance de la pasada final de desbaste. Con 0 o sin F, no hay pasada final. | P10 ≠ 0 pide pasada final; P9 = 0 la hace sin acabado |
| H | Avance de acabado. Con 0 o sin H, no hay acabado. | P9. Si es negativo, no hay ni acabado ni pasada final. |
| S | Etiqueta del primer bloque del perfil (4 cifras) | P13 |
| E | Etiqueta del último bloque del perfil (4 cifras) | P14, mayor que P13 |
| Q | Programa que contiene el perfil (fase 2) | — |

Diferencia entre ciclos: en G81 y G82 todas las pasadas son iguales, de paso ≤ C (p. 168 y 172). En G68 y G69 el
paso es C y la última pasada es la del sobrante (p. 154 y 161). En los dos casos salen ceil(profundidad / C)
pasadas.

## Decisiones de interpretación

Esto es lo que el manual no detalla y el simulador decide. Todo está en el código.

1. **Líneas en blanco.** Se saltan. El manual no admite bloques vacíos (p. 34), pero en un archivo de texto las
   líneas en blanco solo separan.
2. **Minúsculas.** El manual escribe con mayúsculas (p. 31). Las minúsculas se leen como mayúsculas y dan un aviso,
   una vez por programa.
3. **Orden de las palabras.** Si no se respeta el orden de la p. 59, es error, porque el manual dice «hay que
   mantener este orden».
   - En los ciclos, el orden es el de la «estructura básica del bloque».
   - En el bloque de un ciclo solo se admiten, además, G70/G71, G90/G91, G94/G95 y G151/G152.
4. **Momento de las funciones M.**
   - M03 y M04, al comienzo del bloque; M05, M02 y M30, al final. Es la configuración que recomienda el manual
     (p. 73).
   - M08 y M09, al comienzo, porque una M que no está en la tabla se ejecuta al principio del bloque (p. 72).
5. **Topes.**
   - Con G92 S, una S mayor en G97 es error, porque el manual dice que «no aceptará» (p. 55).
   - Por encima del máximo de la máquina (MAXGEAR), el giro se limita y hay un aviso.
   - Una F por encima de MAXFEED da un aviso.
6. **G96 y las gamas.** El manual pide seleccionar la gama M41-M44 (p. 66). El cabezal simulado tiene una sola gama y
   no la exige. M41-M44 son de fase 2.
7. **Entrada y salida de las pasadas de perfil.** Las figuras de p. 158-159 y 170 no dan los movimientos exactos de
   la pasada final de desbaste ni de la de acabado. El simulador:
   - baja en rápido por la Z de llamada, que está fuera de la pieza;
   - entra al avance de la pasada;
   - recorre el perfil;
   - sale al avance por la pared del final hasta la X de llamada;
   - vuelve en rápido.

   Así nunca entra en rápido en el material, y la salida por la pared acaba el hombro, como dibuja la figura de
   G81.
8. **Demasías.**
   - Con M programada, el perfil se traslada L en X y M en Z: demasías por ejes, como en G81 (p. 169).
   - Sin M, la demasía L es constante: desplazamiento equidistante con arcos de unión en las esquinas convexas y
     recorte en las cóncavas.
   - Si un radio cóncavo es menor que L, es error de fase 2.
9. **Alcance de G68/G69 en el MVP.** Solo mecanizado exterior de perfiles monótonos: el perfil sube hacia el plato
   en G68 y baja hacia el eje en G69. Son de fase 2:
   - los canales, que el CNC real mecaniza al final (p. 157);
   - el doble perfil de bruto y pieza (G00 dentro del perfil, p. 160);
   - el perfil en otro programa (Q);
   - G06, G08, G09, G36, G39, G53 y G93 dentro del perfil.
10. **Radio de la punta.** El 8055 hace el acabado de G68/G69 con compensación del radio de la punta (p. 159). El
    IR lleva la trayectoria de la punta teórica, sin compensar (G41/G42 son de fase 2). Cuando el perfil tiene
    chaflanes, conos o arcos, el intérprete da un aviso.
11. **Estado tras el ciclo.**
    - G81 y G82 conservan F y las funciones G anteriores (p. 170 y 174).
    - G68 y G69 dejan G00 y G90, con el último avance usado, F o H (p. 156).
12. **Punto de llamada.** Tiene que quedar fuera del perfil más las demasías (G68: p. 156; G81: p. 171; G82: p. 175).
    Si no, es error.
13. **Arcos.**
    - En el IR, `cw` es G02: sentido horario con Z a la derecha y X (radio) hacia arriba. Es como dibuja el manual
      el torno horizontal (p. 80).
    - Lo comprueba un test con el ejemplo de la p. 83: desde X40 Z60, `G03 X90 Z110 R50` tiene el centro en X90 Z60.
    - Una circunferencia completa es error de fase 2: no tiene sentido en el torno.
14. **Letra sin número.** X, Z, I, K o R sin número valen 0 (p. 31) y dan un aviso.
15. **Tiempo estimado.**
    - Rápidos a G00FEED por el eje que más recorre.
    - Avances en mm/rev integrados a lo largo del tramo con las rpm del cabezal: con G96 se recalculan con el radio
      y se limitan con G92 S o con el máximo de la máquina.
    - Esperas de G04.

## Máquina simulada

Son los valores por defecto de los parámetros máquina del 8055 (F3). Se pueden cambiar con
`interpret_program(…, { machine: {…} })`.

| Clave | Valor | Parámetro (F3) |
|---|---|---|
| `rapid_mm_min` | 10000 mm/min | G00FEED (P38), p. 173 |
| `max_feed_mm_min` | 5000 mm/min (también F0) | MAXFEED (P42), p. 173 |
| `max_rpm` | 4000 rpm | MAXGEAR4 (P5) por defecto, p. 195. El cabezal simulado no tiene gamas. |
| `cirinerr_mm` | 0.01 mm | CIRINERR (P20), p. 111 |
| `inches`, `imove`, `isystem`, `ifeed` | G71, G00, G90, G94 al encender | INCHES (P8) y IMOVE (P9), p. 108; ISYSTEM (P13) e IFEED (P14), p. 109 |
| `diameter` | X en diámetros (G151) | DFORMAT (P1), p. 162. El valor lo fija el fabricante: tomamos diámetro, como pide el encargo. |

La posición inicial por defecto es X100 Z100 (radio 50, Z 100). Es una elección del simulador.

## Programas de ejemplo

- **Pieza A (eje escalonado, C45E).**
  - G82 refrenta hasta Z0.
  - Tres G81, con D1 y creces de 0.3 en X y 0.1 en Z, desbastan Ø46, Ø40 y Ø30.
  - T3 da el acabado con G01. Programa el centro de cada tolerancia de la tabla IT de CONTRATOS.md: X29.974 para
    Ø30 h9, X39.969 para Ø40 h9 y X46 para Ø46 ±0.1.
- **Pieza B (bulón, EN AW-6082 T6).**
  - Refrentado con G01.
  - Un G68 sin D para todo el perfil: desbaste, pasada final (F0.2) y acabado (H0.1).
  - El perfil (N200-N260) va detrás de M30.
  - Centros de tolerancia: X23.9835 para Ø24 h8 y X36 para Ø36 js9. El R2 cóncavo del hombro es un G02 con R2.
- **Programa con 3 errores.** Es el acabado de la pieza A con tres fallos típicos:
  - `G50 S2500` en lugar de `G92 S2500`, costumbre de Fanuc;
  - un arco con un radio de 0.5 mm que no llega a unos extremos separados 1.41 mm;
  - `G04 X1.5` en lugar de `G04 K150`.

  La explicación de cada uno está en `EXAMPLE_PROGRAMS.errores.errors`, no en los comentarios del programa.

**Condiciones de corte: estimación.**
- Valores: Vc 180 y 220 m/min en C45E y 300 m/min en aluminio; avances de 0.1 a 0.25 mm/rev; pasadas de 1 a
  2.5 mm.
- Son valores didácticos de ejemplo, de los órdenes habituales en los catálogos de plaquitas. No son datos
  medidos ni de un catálogo concreto.
- Si son razonables lo decide el modelo de corte del taller (otra unidad).

## Fanuc T: tabla de contraste (N1)

`DIALECTS.fanucT` no se ejecuta. Sirve para explicar los choques entre dialectos, y el intérprete la usa para dar
pistas en los errores.

| Código | Fanuc T, sistema A (N1, tabla 2(a), p. 13-15) | Fagor 8055 T |
|---|---|---|
| G20 / G21 | Pulgadas / milímetros | Límites de las zonas de trabajo; las unidades son G70 / G71 |
| G70 / G71 | Ciclo de acabado / de desbaste (4.2.4, p. 74; 4.2.1, p. 52) | Pulgadas / milímetros; el desbaste es G68 |
| G50 | Sistema de coordenadas o tope de rpm | Arista matada controlada; el tope es G92 S |
| G68 / G69 | Imagen espejo de doble torreta | Ciclos de desbaste en X y en Z |
| G81 / G82 | Punteado / avellanado (formato FS10/11-T) | Torneado / refrentado de tramos rectos |
| G90 / G92 / G94 | Ciclos de torneado, roscado y refrentado | Absolutas / preselección y tope de S / mm/min |
| G98 / G99 | Avance por minuto / por vuelta | No existen; son G94 / G95 |
| U / W | Cotas incrementales (el sistema A no tiene G90/G91; nota 6, p. 13) | Otros ejes; el incremental es G91 |
| G04, comentarios | Pendiente: están en el manual común B-64604EN, que no he consultado | G04 K en centésimas; comentario con «;» |

## Pendiente (fase 2)

- M08 y M09: confirmar el significado en una fuente de Fagor (la tabla M la define el fabricante).
- Canales y rebajes en G68/G69, mecanizado interior, doble perfil (bruto y pieza) y perfil en otro programa (Q).
- Compensación del radio de la punta (G40/G41/G42) y modos de arista (G05, G07, G50).
- Arcos G06, G08 y G09; redondeos y chaflanes G36 y G39; coordenadas polares; G53-G59, G92 X Z y G93.
- Roscado (G33, G34, G86, G87), ranurado (G88, G89), taladrado (G83), ciclos curvos (G84, G85) y G66.
- Lenguaje de alto nivel: parámetros P, instrucciones entre paréntesis y saltos.
- Salto de bloque «/» y número de repeticiones al final del bloque.
- M00, M01, M06, M19, M41-M44 y M45.

## Para el coordinador

1. **Sintaxis de G68/G69.** El plan decía «parámetros P0…P14 / etiquetas P13 y P14», pero eso es del 8025/8030. El
   8055 usa `G68 X Z C D L M K F H S E Q`: conviene corregirlo en el plan o en CONTRATOS.
2. **Cara del bruto de las piezas A y B.** CONTRATOS.md no dice dónde está la cara del bruto:
   - Pieza A: 85 − 25 = 60 mm fuera del plato. ¿Coincide la cara con Z0 o deja creces de refrentado?
   - Los programas refrentan hasta Z0 desde Z+2, así que funcionan en los dos casos.
   - Propuesta: fijar «cara del bruto en Z+1».
3. **Identificador de herramienta en el IR.**
   - `tool.id` es "T" y el número ("T1", "T3").
   - `offset` es la D; con T sola, el corrector de la tabla que se pase en `tools`, o el mismo número si no se pasa.
   - Propongo fijarlo en CONTRATOS.
4. **Campo opcional `pass` en el IR.** Propongo un `pass` ("desbaste" | "repaso" | "acabado") para que el torno
   rellene `ring_pass`. Hoy solo se deduce del avance o de la herramienta. No lo he añadido para no salirme del
   contrato.
5. **rpm con G96.** Con G96, `spindle.rpm` es el giro en el punto donde se emite el movimiento. El torno debe
   recalcularlo en cada paso a partir de `css`.
6. **Archivos `.uid`.** Van en el commit con los scripts, como en el resto del repositorio.
7. **gdlint, orientativo.**
   - Quedan líneas de más de 100 columnas, sobre todo mensajes; el resto del repositorio tampoco cumple 100.
   - Hay más de 6 `return` en las funciones de validación.
   - `gcode.gd` pasa de 1000 líneas.
8. **e2e.** La trayectoria de A y B en SVG y PNG está en la carpeta de salida de la unidad 4:
   - `trayectorias_a_b.png` (y `.svg`)
   - `zoom_b.png`
