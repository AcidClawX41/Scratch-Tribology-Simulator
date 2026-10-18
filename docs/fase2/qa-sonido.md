# Repaso de sonido y 3D de la Tribología biológica antes de la 2.0.0 (calle H)

- **Base:** `main` a2f175f; unido `main` 8e4c4ec (los tres primeros commits de esta calle) antes de la parte del 3D y
  `main` 9778db0 (con la 4w y el arreglo del catálogo) antes de la batería final.
- **Fecha:** 18-10-2026.
- **Alcance:** lo que se oye y lo que se ve en 3D en la sección «Tribología biológica»: el banco de ensayo, el coche en
  marcha, la cetrería (limas, cortaúñas, torno, amoladora, reacción del animal y lente) y el laboratorio de la reforja.
  No cambia ningún número de la física ni ningún veredicto.

## 1. Cómo se mide

- **Grabación.** Movie Maker (`godot.mjs capture`, OpenGL bajo Xvfb) graba la salida del bus «Master» **después de su
  limitador** (48 kHz, estéreo, 32 bits). Dos tipos de captura:
  - *sonido a sonido:* una escena de medida (no versionada) que toca cada efecto con **los mismos reproductores, buses y
    volúmenes que el programa** (SfxPlayer en «Lab» o «Master», o un AudioStreamPlayer en «Lab» para los bucles), uno
    detrás de otro, con silencio entre medias;
  - *en su sitio:* las demos guionizadas de la sección (`demo_lab`, `demo_cetreria -- --caso=9`, `demo_reforja --
    --caso=9`, `demo_reaccion -- --caso=9`, `demo_coche -- --caso=5`).
- **Medida** (un guion de Node fuera del repositorio): **sonoridad** como LUFS momentáneos máximos (ventana de 400 ms,
  ponderación K de ITU-R BS.1770-4, sobre un canal: los efectos son mono repetidos en los dos), **pico** de muestra y
  muestras ≥ 0,98. El RMS a secas engaña (un pitido de 2700 Hz suena más fuerte que un golpe grave del mismo RMS), por eso
  se usa la ponderación K. La misma medida sobre el WAV a 22 050 Hz da lo mismo ± 0,5 dB, y es la que vigila
  `tests/lab/test_sfx_mezcla.gd`.

## 2. Objetivos por clase

Cada efecto de `assets/sfx/lab/` tiene una clase (`Sfx.KIND`, `core/lab/sfx.gd`) y cada clase, una banda de sonoridad al
volumen con que lo pide el programa:

| Clase | Qué es | Banda (LUFS-M máx.) |
|---|---|---|
| ui | clics, interruptores, pitido de la lámpara | −30 … −26 |
| logro | la fanfarria de un logro | −24 … −20 |
| resultado | lo que suena al acabar un ensayo o una pasada (rayar, punzar, la piel, el aguijón) | −21 … −17 |
| impacto | golpes cortos y roturas, voces del animal, golpes en la lente, colada y temple | −21 … −17 |
| herramienta | bucles de motores, máquinas y roces; arranque y parada; el paño | −26 … −22 |
| ambiente | el zumbido del insecto | −30 … −26 |

Y ningún efecto suelto pasa de **0,70 de pico** (−3 dBFS), para que la suma de dos no llegue al limitador (techo −0,3 dBFS
= 0,966). El limitador queda como red: en las capturas de después no actúa en ningún momento.

## 3. Lo que se ha encontrado y arreglado

1. **Chasquido en cada vuelta de los bucles** (los 14: torno, lima, amoladora, horno, llama, inducción, prensa y muela de
   la reforja, y los seis zumbidos). Godot 4.7.2 interpola leyendo pasado `edit/loop_end` y cada vuelta (cada 2 s) daba
   un pico de hasta el doble del bucle: 0,93 en la prensa a volumen 1, 0,90 en la llama, 0,85 en el torno, 0,62 en el
   zumbido (el archivo, 0,37). Probado con cinco variantes del mismo bucle: sin chasquido con `loop_end` = N − 1 (pierde
   una muestra por vuelta) o con **el bucle seguido de unas muestras de su principio** y `loop_end` = N; se ha elegido lo
   segundo. Los bucles se hornean con una cola de 32 muestras (`Sfx.with_loop_tail`, `tools/bake_lab_extra.gd`) y los
   tests comprueban que la cola repite el principio. El pico medido vuelve al del archivo.
   *Para el taller:* `tools/bake_sounds.gd` hornea sus bucles con el mismo `loop_end` = N; seguramente tiene el mismo
   chasquido (no medido: fuera del alcance de esta calle).
2. **Sonoridades dispares.** Antes, 21 dB entre el más flojo y el más fuerte de la misma familia (el clic −33 LUFS, rayar
   metal −11,8; la voz del águila −12,8 y la del búho −24,1), porque los WAV salen normalizados al pico y no a la
   sonoridad. `Sfx.TRIM_DB` lleva a cada uno a su banda (de −7,5 dB en los interruptores a +6,5 dB en el golpe en la lente
   de plástico; en pasos de 0,5 dB y sin pasar el pico de 0,70 al subir) y lo aplican todos los reproductores de la
   sección: `SfxPlayer`, los bucles y los de una vez de la cetrería (`care_page.gd`, tres líneas), el bucle de la reforja
   (`forge_page.gd`, una línea), el zumbido del banco (`lab_section.gd`) y la demo de la reacción. Los 22 WAV de la 1.x
   no se tocan (son los de la app móvil).
3. **La amoladora llevaba la mezcla al limitador.** Con la amoladora sobre la garra, la cetrería sonaba a 0,25 de RMS y
   el limitador recortaba a 0,966 durante segundos: el roce de cada pasada (un efecto de 1 s) llegaba cada 0,3 s y se
   apilaba hasta cuatro veces sobre el motor y la lima. `SfxPlayer` baja ahora **6 dB cada copia** de un efecto que aún
   suena (y coge una voz libre antes de robar una que suena).
4. **`GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT`** en las demos de la cetrería y la reforja: era nuestro. Al abrir la cetrería
   en escritorio, la página se maquetaba primero en una columna (≈ 28 000 px) y, al pasar a dos, la vista 3D heredaba esa
   altura un instante: un SubViewport de 765 × 27 856 px, más que el tope de las texturas. Arreglado en
   `care_page._layout` (al pasar a dos columnas, la página toma ya su altura). Comprobado con un vigía de los SubViewport
   en las siete escenas 3D de la sección, en escritorio y en el teléfono: ningún aviso del motor.

## 4. Antes y después, sonido a sonido

Al volumen con que lo pide el programa (columna «vol»; los bucles de la reforja, al máximo de la temperatura), medido con
Movie Maker después del limitador. Gráfico: el PNG de progreso `qa_sonido_tabla.png`.

| Sonido | Clase | vol | Antes LUFS | Antes pico | Después LUFS | Después pico |
|---|---|---|---|---|---|---|
| UI on (Master) | ui | 0,6 | −19,3 | 0,31 | −26,8 | 0,13 |
| UI off (Master) | ui | 0,6 | −19,5 | 0,31 | −27,0 | 0,13 |
| UI tap | ui | 0,7 | −33,3 | 0,22 | −29,8 | 0,32 |
| UI drip (interruptor) | ui | 0,7 | −22,8 | 0,41 | −25,8 | 0,29 |
| Logro badge | logro | 0,5 | −16,5 | 0,38 | −20,0 | 0,26 |
| Banco slide | resultado | 0,7 | −16,7 | 0,34 | −17,2 | 0,32 |
| Banco squeak | resultado | 0,7 | −13,6 | 0,44 | −17,1 | 0,29 |
| Banco scratch-soft | resultado | 0,7 | −13,5 | 0,66 | −17,0 | 0,44 |
| Banco scratch-deep | resultado | 0,7 | −14,8 | 0,62 | −16,8 | 0,49 |
| Banco scratch-wood | resultado | 0,7 | −16,8 | 0,64 | −16,8 | 0,64 |
| Banco scratch-metal | resultado | 0,7 | −11,8 | 0,65 | −16,8 | 0,36 |
| Banco scratch-glass | resultado | 0,7 | −12,1 | 0,64 | −17,1 | 0,36 |
| Banco skin-rub | resultado | 0,7 | −20,0 | 0,44 | −20,0 | 0,44 |
| Banco skin-cut | resultado | 0,7 | −16,1 | 0,64 | −17,1 | 0,57 |
| Banco press | resultado | 0,7 | −22,4 | 0,54 | −20,9 | 0,65 |
| Banco pierce | resultado | 0,7 | −20,7 | 0,61 | −20,7 | 0,61 |
| Banco inject | resultado | 0,7 | −14,7 | 0,62 | −17,2 | 0,47 |
| Banco pierce-solid | resultado | 0,7 | −22,4 | 0,63 | −21,4 | 0,70 |
| Banco pierce-brittle | resultado | 0,7 | −24,3 | 0,37 | −20,8 | 0,55 |
| Banco breakthrough | resultado | 0,7 | −18,1 | 0,61 | −18,1 | 0,61 |
| Banco shatter | impacto | 0,7 | −21,9 | 0,46 | −20,9 | 0,51 |
| Banco snap | impacto | 0,7 | −25,2 | 0,41 | −21,7 | 0,62 |
| Aguijón picotazo | resultado | 0,7 | −25,9 | 0,61 | −24,9 | 0,69 |
| Aguijón desgarro | resultado | 0,7 | −16,0 | 0,58 | −17,0 | 0,52 |
| Aguijón pandeo | resultado | 0,7 | −14,3 | 0,57 | −16,8 | 0,43 |
| Zumbido abeja (bucle) | ambiente | 0,5 | −23,5 | 0,18 | −26,0 | 0,14 |
| Cetrería torno (bucle) | herramienta | 0,5 | −21,6 | 0,27 | −22,1 | 0,26 |
| Cetrería amoladora (bucle) | herramienta | 0,5 | −21,3 | 0,47 | −21,8 | 0,31 |
| Cetrería lima (bucle) | herramienta | 0,55 | −24,1 | 0,36 | −24,1 | 0,36 |
| Cetrería arranque | herramienta | 0,6 | −20,7 | 0,36 | −22,2 | 0,30 |
| Cetrería parada | herramienta | 0,6 | −26,6 | 0,30 | −26,1 | 0,32 |
| Cetrería pitido lámpara | ui | 0,7 | −23,8 | 0,12 | −25,8 | 0,09 |
| Reacción rapaz | impacto | 0,6 | −12,8 | 0,38 | −16,8 | 0,24 |
| Reacción búho | impacto | 0,6 | −24,1 | 0,36 | −21,1 | 0,52 |
| Reacción tigre | impacto | 0,6 | −21,7 | 0,37 | −21,2 | 0,39 |
| Reacción oso | impacto | 0,6 | −23,3 | 0,38 | −20,8 | 0,50 |
| Reacción raptor | impacto | 0,6 | −18,9 | 0,40 | −18,9 | 0,40 |
| Lente plástico | impacto | 0,6 | −28,6 | 0,33 | −22,1 | 0,69 |
| Lente vidrio | impacto | 0,6 | −20,3 | 0,33 | −20,3 | 0,33 |
| Lente grieta | impacto | 0,6 | −24,2 | 0,39 | −21,2 | 0,55 |
| Lente rasguño | impacto | 0,6 | −19,9 | 0,36 | −19,9 | 0,36 |
| Lente paño | herramienta | 0,7 | −18,5 | 0,32 | −22,0 | 0,22 |
| Reforja horno (bucle, máx.) | herramienta | 0,8 | −22,1 | 0,35 | −22,1 | 0,29 |
| Reforja llama (bucle, máx.) | herramienta | 0,8 | −18,1 | 0,50 | −22,1 | 0,32 |
| Reforja inducción (bucle, máx.) | herramienta | 0,8 | −19,9 | 0,26 | −21,9 | 0,20 |
| Reforja prensa (bucle, máx.) | herramienta | 0,8 | −20,5 | 0,71 | −22,1 | 0,29 |
| Reforja muela (bucle) | herramienta | 0,6 | −19,7 | 0,35 | −22,2 | 0,27 |
| Reforja colada | impacto | 0,7 | −13,0 | 0,56 | −17,0 | 0,36 |
| Reforja temple | impacto | 0,7 | −13,1 | 0,64 | −17,1 | 0,40 |
| Reforja pulso del láser (5r) | herramienta | 0,7 | −31,3 | 0,41 | −26,8 | 0,68 |
| Reforja pulso del micro-TIG (5r) | herramienta | 0,7 | −31,2 | 0,43 | −27,2 | 0,69 |

Fuera de banda solo quedan el **picotazo** (−24,9) y el **pulso del micro-TIG** de la mesa de soldar (−27,2, medido sobre el
WAV: la 5r los añadió después): son chasquidos secos y subirlos más pasaría el pico de 0,70. Ninguna
muestra ≥ 0,98 antes ni después en esta medida (cada sonido suelto); el problema estaba en las sumas (§5).

## 5. Antes y después, en su sitio

| Escena (demo) | LUFS-M máx. antes → después | RMS de 1 s máx. | Pico |
|---|---|---|---|
| Banco de ensayo (`demo_lab`, primeros 20 s: uña contra vidrio, garra contra coche…) | −11,8 → −16,8 | 0,167 → 0,095 | 0,65 → 0,47 |
| Cetrería, amoladora en marcha sin tocar (`demo_cetreria`, caso 9) | −20,3 → −21,3 | 0,087 → 0,080 | 0,38 → 0,33 |
| Cetrería, amoladora trabajando la garra (caso 9) | **−9,4 → −14,7** | **0,255 → 0,139** | **0,966 (limitador) → 0,69** |
| Reforja, las máquinas de cada modo (`demo_reforja`, caso 9, 28 s) | −12,6 → −16,0 | 0,144 → 0,111 | 0,77 (chasquido) → 0,51 |
| Coche en marcha, el tigre contra la puerta (`demo_coche`, caso 5; solo después) | −16,8 | 0,095 | 0,39 |
| Cetrería, la reacción del tigre y del águila contra la lente (`demo_reaccion`, caso 9; solo después) | −16,8 | 0,092 | 0,69 |

Lo más fuerte de la sección es ahora un instante de trabajo con la amoladora (−14,7), unos 2 dB por encima de un
resultado del banco: se oye que es una máquina, sin tapar lo demás ni tocar el limitador.

## 6. Limpieza del 3D

Capturas con Movie Maker (OpenGL por software bajo Xvfb; el Forward+ real lo prueba la CI) en escritorio (1240 × 880) y
teléfono (390 × 844, `--phone`): `demo_coche` (caso 5), `demo_curvas` (caso 7), `demo_animales` (páginas 1 y 14),
`demo_materiales`, `demo_cetreria` (casos 7 y 9), `demo_reforja` (caso 9) y `demo_reaccion` (caso 9). Además, un vigía
sin Movie Maker (no versionado) que carga cada una de las siete escenas en los dos tamaños y avisa de cada SubViewport
nuevo o que cambia de tamaño, de cada aviso del motor y del número de nodos y objetos cada 60 fotogramas.

| Qué se busca | Resultado |
|---|---|
| Sombreadores que no compilan | `tools/shader_check.gd` en Vulkan (Forward+, lavapipe): los 42 compilan, sin errores. |
| Avisos del motor | Solo `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT` en la cetrería y la reforja: era nuestro y está arreglado (§3.4). Después, ninguno en las siete escenas y los dos tamaños. |
| Objetos creados en cada fotograma | `demo_coche` (caso 1, 420 fotogramas): 2893 nodos y 8473 objetos de principio a fin. `demo_cetreria` (caso 9, la amoladora: 600 fotogramas): 3169-3170 nodos y 9284-9296 objetos (el polvo y las chispas van y vienen; no crecen). Los tests `test_car3d.gd` (18/0) y `test_care3d.gd` pasan; `test_care_hd.gd` falla solo en el coste por fotograma con la máquina a carga 16-19 (no toca nada de esta calle). |
| Materiales negros o que faltan | Ninguno: los 17 materiales de las garras, los animales del coche y los de la cetrería se ven con su material. |
| Z-fighting y acné de sombras | No se ve en ninguna captura (mesas, baldosas, chapa, el suelo del taller). |
| Cosas que se atraviesan | El tigre contra la puerta, en recta y en curva, y los animales en la mesa de la clínica: nada que llame la atención a esta resolución. Las patas del oso cuelgan por el borde de la mesa a propósito (lo dice el guion). |
| Tests que fallaban por la carga | `test_care_colocar.gd::test_la_escena_coge_la_pieza_y_la_acopla` esperaba fotogramas fijos mientras el estado va en su hilo: ahora espera a cada condición (con 900 fotogramas de margen). `test_forge_page::test_coste_del_repintado` y `test_care_reaction::test_coste_por_fotograma` pasan en esta rama a carga 16 (0,95 ms de repintado): sus fallos eran de la carga. |
| Desbordes en el teléfono | En la reforja, con la receta «Diamante CVD (funda crecida sobre un molde)», su título no se partía y la página se iba a 417-449 px: los mandos del horno se salían por la derecha. Arreglado (el título es un párrafo) con un test que falla sin el arreglo. |

| La hoz del velocirraptor reforjada en una gema | Se veía oscura y a franjas anchas. No es la malla (40 lados por vuelta, un anillo cada 0,5 mm; la queratina y el acero se ven lisos) ni lo del entorno de la carretera que arregló la 4w: la biblioteca hace las facetas de una talla de un 20 % del largo de la garra, y en la hoz (~80 mm) salían de ~16 mm. En la cetrería, ahora como mucho de 6 mm (`ClawLook.FACET_MAX_MM`; hasta 30 mm de garra no cambia nada): se ve tallada, y el diamante, como un diamante. Y el zafiro salía azul marino casi negro: la biblioteca absorbe a lo largo de 2·r (el diámetro de la sección redonda equivalente, ~18 mm en la hoz frente a ~5 mm en el águila), y la hoz es muy comprimida de lado (18,7 × 7,1 mm: de lado, la luz atraviesa unos 7 mm). La biblioteca lleva ahora `claw_section_k` (por defecto 1, y con 1 el sombreador no toca el radio: todas las demás garras, igual al bit) y el camino es 2·r/√k; la cetrería solo lo pone en la garra que se trabaja del velocirraptor (la hoz). PNG `qa_3d_hoz_gema_facetas.png` (antes y con las facetas) y `qa_3d_hoz_zafiro_despues.png` (con las dos cosas; el águila, igual). |

Lo que queda anotado (no se ha tocado):

- `test_care3d::test_coste_por_fotograma` pasa del presupuesto de 4 ms también con la `care_3d.gd` y la `claw_look.gd` de
  `main` (5,2 ms a carga 2,7): no viene de esta calle.
- Con `main` 49d39af / 16b5305, `Catalog.CLAWS` salía sin las correcciones de la 2.0 según el orden de carga (el ciclo
  ClawsV2 → MovingCar → CarGlass → ClawCareReaction → Catalog); lo arregló el coordinador en `main` 5fe445f.

## 7. Cómo repetir la medida

1. `node godot/tools/godot.mjs capture <escena> --frames=N --fps=10 --out=<carpeta> [--phone] -- --caso=K` deja `f.wav`
   (la salida de «Master» tras el limitador) junto a los PNG; a 10 fps la demo dura lo mismo y tarda un tercio.
2. Sonoridad: ponderación K (dos biquads de BS.1770-4 a 48 kHz) y LUFS = −0,691 + 10·log10(media del cuadrado) en
   ventanas de 400 ms; el máximo de las ventanas es el «LUFS-M máx.» de las tablas.
3. `tests/lab/test_sfx_mezcla.gd` hace lo mismo sobre cada WAV con su volumen y su ajuste: si un sonido nuevo o
   rehorneado cae fuera de la banda de su clase o pasa de 0,70 de pico, falla y dice cuánto.
