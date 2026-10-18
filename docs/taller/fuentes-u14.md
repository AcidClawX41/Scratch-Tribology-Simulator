# Unidad 14 · Radial contra chapa de coche: escena 3D educativa

Escena de Godot sin entorno de juego: una amoladora angular procedural contra un trozo de chapa de puerta curvada
con su pintura de fábrica, para ver de cerca cómo corta cada disco según su material, las rpm y el ángulo. La
escena **no calcula física**: dibuja la salida del modelo de corte de la unidad 6 (`core/taller/radial.gd` →
`cut_panel`). Mientras ese modelo no está, usa una tabla **sustituta** de resultados de prueba, marcada como tal.

## Archivos

| Archivo | Qué hace |
|---|---|
| `godot/core/taller/sparks.gd` | Emisor de chispas (núcleo, sin nodos, determinista con `core/shared/rng.gd`): del haz que da el modelo y de la pose del disco a partículas con estela, estallidos y color por temperatura, en el formato del búfer de un `MultiMesh` |
| `godot/app/taller/radial_3d.tscn` + `.gd` | La escena y su API para la interfaz |
| `godot/app/taller/corte_chapa.gdshader` | Chapa pintada cortada: capas, pintura quemada, revenido, incandescencia del frente, rebaba, hilos |
| `godot/app/taller/radial3d/` | Auxiliares: `looks.gd` (aspecto), `stub_results.gd` (**sustituto**), `panel_builder.gd` (chapa, paredes del surco, rebabas, hilos), `grinder_builder.gd` (amoladora y discos), `smoke.gd` (humo), shaders del disco, las chispas y el humo |
| `godot/app/taller/demo_radial.tscn` + `.gd` | Guion determinista de 12 s con los cinco casos |
| `godot/tests/taller/test_sparks.gd` | 10 tests: determinismo, materiales sin chispas, efecto de vs, colores y estallidos por material, estallidos dentro de un fotograma, búfer, contrato del sustituto y carga de las escenas sin ventana |

## API de la escena (`radial_3d.gd`)

- `set_params(params)`: entrada del contrato `{ disc_id, diameter_mm, rpm, angle_deg, feed_mm_s, panel_id, cut_length_mm }`.
- `set_result(result)`: salida del contrato (`cut_panel`).
- `start_cut(from_mm = 0, prewarm_s = 0)`: empieza el corte en el canto (u = 0) o con `from_mm` ya cortados; `prewarm_s` simula de golpe el haz de chispas y el humo.
- `set_view(name)`: `detalle` (del corte), `general`, `canto` (sección a escala, ortográfica) o `cenital` (el surco desde arriba, a escala). Acepta también «detalle del corte», «vista general», «canto del corte»…
- `set_rpm(rpm)`: cambia al momento el giro que se ve y la velocidad de salida de las chispas; la interfaz debe pedir después otro `cut_panel` y llamar a `set_result`.
- `set_angle(deg)`: inclina disco y amoladora sobre la línea de corte (0 = perpendicular a la chapa): el surco se ladea y la rebaba crece en un lado.
- `set_inset(on)`: dos recuadros a escala (sección y vista cenital) con barra de escala; `inset_side` elige el lado.
- `info()`: vs, rpm máxima del disco, frecuencia del estroboscopio, avance real, progreso y estadística de las chispas.
- Señal `cut_finished`.

La demo acepta, para revisar: `-- --caso=1..5 --vista=detalle|general|canto|cenital --rpm=6000 --angulo=20`.

## Fuentes

1. **Ensayo de chispas.** Headquarters, Department of the Army (1993). *TC 9-237 Operator's Circular: Welding
   Theory and Application*. §7-3 «Spark test» (pp. 7-11 a 7-12, 7-25) y **tabla 7-5 «Summary of spark test»**
   (p. 7-13): volumen del haz, longitud relativa (muela de 12 in en banco), color junto a la muela y al final,
   cantidad y forma de los estallidos de 15 metales. Del texto: muela a ≥ 1525 m/min; el acero de 0,15 % C da
   estelas largas que tienden a estallar; el de herramientas estalla mucho; el Mn aumenta el volumen del haz y la
   fuerza de los estallidos (con Mn alto chispea como un acero de más carbono); el Cr acorta el haz a la mitad; el
   18-8 chispea como el hierro pero con la mitad de longitud; cobre, aluminio y aleaciones de níquel no dan haz; más
   presión calienta el haz y parece más carbono. `armypubs.army.mil/epubs/DR_pubs/DR_a/pdf/web/tc9_237.pdf`
   (dominio público).
2. **Colores de revenido y de calor.** Headquarters, Department of the Army (1967). *TM 9-237 Welding Theory and
   Application*, apéndice, **tabla IV «Temper and heat colors»** (paja clara 400 °F = 204 °C, paja 440 °F = 227 °C,
   paja oscura 238 °C, paja muy oscura 249 °C, marrón amarillento 260 °C, bronce 271 °C, púrpura pleno 282 °C,
   púrpura azulado 288 °C, **azul 570 °F = 299 °C**, azul pleno 310 °C, azul muy oscuro 316 °C, azul claro 338 °C) y
   **tabla V «Heat colors with approximate temperature»** (rojo tenue visible en la oscuridad 399 °C … cereza 746 °C
   … naranja 941 °C, limón 996 °C, amarillo claro 1079 °C, blanco 1204 °C). Texto completo en
   `archive.org/details/TM9-237`.
3. **Por qué estallan las chispas.** Guillen, A.; Goh, F.; Andre, J.; Barral, A.; Brochet, C.; Louis, Q.;
   Guillet, T. (2019). «From the microstructure of steels to the explosion of sparks». *Emergent Scientist* 3, 2.
   doi:10.1051/emsci/2019001. La gota que arde se parte en vuelo porque el Fe₃C se oxida dentro y forma bolsas de gas;
   miden la distancia recorrida antes de partirse.
4. **Inoxidable.** Davis, J. R. (ed.) (1994). *ASM Specialty Handbook: Stainless Steels*. ASM International,
   pp. 126-127: la serie 300 da chispas de naranja a paja (citado en «Spark testing», Wikipedia).
5. **Franjas de velocidad de los discos.** EN 12413 (aglomerados), EN 13743 (abrasivo aplicado, discos de láminas)
   y EN 13236 (diamante y CBN): 50 m/s azul · 63 amarillo · 80 rojo · 100 verde. Klingspor, «Maximum operating
   speed» (`klingspor.de/en/lowdown-on-grinding/maximum-operating-speed`).
6. **22MnB5.** EN 10083-3 (aceros al boro para temple y revenido): C 0,19-0,25 %, Mn 1,10-1,40 %,
   B 0,0008-0,005 %.
7. **Pintura y carrocerías.** Las del laboratorio de la 1.x: `packages/core/src/data.js` (`PAINT_LAYERS`,
   `CAR_BODIES`, con sus fuentes en `docs/FISICA.md` §14) y los colores de `packages/core/src/art.js`
   (`MATERIAL_LOOK`, `BODY_LOOK`, `PAINT_LAYER_LOOK`).

## Estimaciones (sin medición publicada)

| Valor | Dónde | Estimación |
|---|---|---|
| Longitud de frenado de una chispa `L = (4/3)(ρp/ρaire)(d/Cd)` | `sparks.gd` `DRAG_LENGTH_M` | 0,8 m (gota de ~100 µm, ρp ≈ 7000 kg/m³, Cd ≈ 1) |
| Velocidad de salida de la chispa | `EJECT_MIN/MAX` | 0,55-1,0 × vs |
| Apertura del abanico | `SPREAD_IN_PLANE_DEG`, `SPREAD_OUT_PLANE_DEG` | ±9° en el plano del disco, ±2,5° fuera |
| Velocidad de la muela del ensayo | `VS_REF_MS` | 35 m/s (el TC 9-237 pide ≥ 25 m/s) |
| Chispas visibles por segundo de un haz «Large» | `RATE_REF` | 1000 /s a 35 m/s (solo si el modelo no da `rate`) |
| Palabras de color → temperatura | `COLOR_WORD_TEMP_C` | rojo 788 °C · naranja 941 · amarillo-naranja 970 · paja 996 · blanco 1204 (tabla V) |
| Volumen y estallidos por chispa | `FAMILIES` | Large 1 … None 0; Very few 0,08 · Few 0,15 · Moderate 0,35 · Many 0,7 · Very many 1,2 |
| Familias DP800 y 22MnB5 | `acero_mn`, `acero_mn_b` | entre las filas 2 y 3 de la tabla 7-5 por el efecto del Mn |
| Tamaño y vida de los trozos de un estallido | `_burst` | L × 0,05 (horquilla) o × 0,02 (estrella); 8-20 ms o 3-8 ms |
| RGB de los colores de calor y de revenido | `HEAT_COLORS`, `Looks.TEMPER_COLORS` | a ojo para pantalla; las temperaturas son de las tablas |
| Incandescencia del frente del corte en acero | `radial_3d.gd` `FRONT_GLOW_C` | 900 °C |
| Reparto de la rebaba con el disco inclinado | `radial_3d.gd` | lado de la arista aguda × (1 + 0,6·sen α), el otro × (1 − 0,6·sen α) |
| Espesor de 22MnB5 (pilar B) y DP800 | `looks.gd` | 1,8 mm y 1,2 mm (a la espera de `panels.gd`) |
| Medidas y colores de discos y amoladora | `looks.gd`, `grinder_builder.gd` | dibujo de una radial de 125 mm típica |
| Humo: flotación, tamaños, vidas | `smoke.gd` | visual |

**Todos los números de `stub_results.gd` son inventados** (cualitativamente coherentes, sin fuente) y el propio
resultado lo dice: `quality: "estimate"`, `stub: true` y la fuente «SUSTITUTO de prueba».

## Cómo lee la escena la salida del modelo

- `kerf_mm`: anchura del surco en la cara pintada medida en perpendicular al disco (en la chapa, kerf / cos α).
- `burr_um`: altura media del labio de la rebaba en la cara de salida (la interior); con plástico (`melt`), cordón
  fundido arriba y abajo.
- `haz_mm` y `heat_tint.temp_c`: perfil T(d) = 20 + (T₀ − 20)·e^(−d/λ) desde el borde del surco, con λ tal que a
  `haz_mm` la chapa llegó a ~200 °C (donde empieza el primer color de revenido). `heat_tint.color`: color del
  aluminio y del plástico calientes (el acero usa la tabla IV).
- `paint_burn_mm`: anchura quemada a cada lado: amarillea, se tuesta, se carboniza y junto al borde se va.
- `sparks`: `rate` chispas visibles por segundo; `length_mm` longitud del haz ya con el efecto de vs; `bursts`
  estallidos medios por chispa; `color` color del haz junto al disco.
- `disc_loading` (0-1): metal o plástico pegado en el borde del disco. `deformation` (mm): alabeo junto al corte.
- `time_s`: tiempo para `cut_length_mm`; la escena avanza a `cut_length_mm / time_s`.

## Decisiones de dibujo

- **Estroboscopio controlado.** Por encima de 2 vueltas/s el disco se dibuja como bajo una luz estroboscópica que
  destella 0,35 Hz por debajo de la frecuencia de giro: parece avanzar despacio y nítido, sin el «efecto
  carromato» aleatorio; `info()["strobe_hz"]` da la frecuencia para rotularla.
- **Estelas como en una foto.** Cada chispa se dibuja como lo que recorrió durante 1/60 s, y lo que se apagó dentro
  de esa exposición también sale: a 30 fps los estallidos duran menos que un fotograma y, si no, no se verían.
- **Vistas a escala.** «canto» y «cenital» son ortográficas y recortadas a una loncha (sin el disco ni la amoladora
  delante), con la chapa, la pintura (110 µm), el surco, la rebaba y la pintura quemada a su tamaño real y una
  barra de escala.
- **Fuentes.** Space Mono y Syne empaquetadas; los textos visibles evitan los glifos que su subconjunto latino no
  trae (por eso «Al2O3» en pantalla y no «Al₂O₃»), para no depender de fuentes del sistema.

## Verificación

- `npm run godot:test`: 26 tests, 0 fallidos (10 de esta unidad).
- `npm run godot:capture -- res://app/taller/demo_radial.tscn --frames=360 --out=…` bajo Xvfb con OpenGL por
  software (Compatibility); fotogramas revisados a ojo.
- Oráculo intacto: `git diff --exit-code 9e40135 -- packages/core/src packages/core/test`.

## Para el coordinador

1. **Integración con la unidad 6.** Cambiar `Stub.cut_panel(p)` por `Radial.cut_panel(p)` en `radial_3d.gd`
   (`_ready`, resultado por defecto) y en `demo_radial.gd` (`_show_case`). El test
   `test_sustituto_cumple_el_contrato` enumera los campos que pinta la escena: conviene repetirlo contra el modelo
   real. El sustituto puede quedarse para los tests o borrarse.
2. **Semántica de campos a acordar con la unidad 6**, tal como la lee la escena (apartado anterior): sobre todo
   `sparks.rate` (chispas **visibles** por segundo: miles, no el número real de virutas), `sparks.length_mm` (ya con
   el efecto de vs; el emisor no lo vuelve a escalar), `haz_mm` (anchura hasta ~200 °C) y `deformation` en mm.
3. **Campos que la escena propone añadir a la salida**: `smoke` (0-1) y `melt` (0-1) (hoy los da el sustituto; si
   faltan, la escena los deduce de la pintura quemada y del tipo de chapa), `burr_um` por lado
   (`[lado −, lado +]`: hoy la escena reparte la rebaba con 0,6·sen α) y `front_temp_c` (incandescencia del frente;
   hoy 900 °C fijos para el acero).
4. **Datos duplicados provisionalmente** en `app/taller/radial3d/looks.gd`: espesores de chapa y medidas y
   velocidades máximas de los discos (deberían salir de `core/taller/panels.gd` y `abrasives.gd`), y los colores del
   laboratorio (de `core/lab/` cuando exista su port). Los colores de revenido (`Looks.TEMPER_COLORS`) podrían pasar
   a `core/taller/` junto a `Sparks.HEAT_COLORS` si otra unidad los necesita.
5. **Reutilizable por la afiladora (unidad 7):** `sparks.gd` ya tiene firmas para `vg10`, `x50crmov15`, `14c28n`
   (inoxidable martensítico, tabla 7-5 fila 9), `m2` (acero rápido, fila 7) y `1095` (acero de herramientas, fila 3),
   y para los tipos de material de pieza de CONTRATOS.md.
6. **Chispas suprimidas:** el emisor no dibuja haz en aluminio, cobre, latón, plásticos, madera, piedra ni vidrio
   aunque el modelo dé `rate > 0` (`stats()["suppressed"]` lo avisa). El titanio no tiene firma todavía (el TC 9-237
   solo dice «grandes, blanco brillante, longitud media»): hoy no da chispas.
7. **Rendimiento:** a 1240×880 con OpenGL por software, ~0,2-0,5 s por fotograma. El búfer de chispas se escribe
   en GDScript (hasta 1600 chispas); si la interfaz lo necesita más rápido, es candidato a C++/GDExtension o a un
   shader de partículas.
