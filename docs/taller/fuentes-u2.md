# Unidad 2 · Ilustraciones y sonidos del laboratorio

Port a GDScript de los dibujos (`packages/core/src/art.js`) y de la elección de sonido (`sfxForResult` de
`packages/core/src/sfx.js`) del motor 1.x, que sigue siendo el oráculo. **No hay datos físicos nuevos**: las tablas
de aspecto se copian tal cual de art.js y las de data.js que usa el dibujo se comprueban contra el oráculo.

## Qué hay

| Archivo | Qué hace |
|---|---|
| `godot/core/lab/art.gd` | Todas las funciones de art.js (`surface_art`, `groove_art`, `puncture_art`, `pane_fracture_art`, `car_section_art`, `skin_section_art`, `gem_art`, `nail_swatch`, `nail_art`, `nail_side_art`, `claw_art`, `h`, `mix`, `lighten`, `darken`, `rgba`, `sparkle` y lo interno). Devuelven el mismo grafo `{ tag, attrs, children }` y los mismos datos (`tip`, `tipAngle`, `labels`, `length`). Incluye `Math.sin`, `cos`, `tan`, `atan2` y `pow` de V8 al bit (`js_sin`…). |
| `godot/core/lab/svg.gd` | Serializador canónico `nodes_to_svg` y `scene_to_svg`, idéntico a `scene-svg.mjs`. |
| `godot/core/lab/looks.gd` | Tablas de art.js (`MATERIAL_LOOK`, `SKIN_LAYER_LOOK`, `PAINT_LAYER_LOOK`, `BODY_LOOK`, `NAIL_LOOK`, `CLAW_ART`, `SKIN_BAND`, `CAR_SECTION`, `SKIN_SECTION`…) y una copia de lo que el dibujo toma de data.js y theme.js (`PAINT_LAYERS`, `SKIN_LAYERS`, carrocerías, paleta `C`). |
| `godot/core/lab/sfx.gd` | `SFX_IDS`, `SFX_RATE`, `sfx_for_result(res, target)` y la ruta de cada WAV. |
| `godot/app/common/svg_texture.gd` | SVG → `ImageTexture` con ThorVG, escala de pantalla (HiDPI), caché LRU por instancia y los arreglos para ThorVG (`thorvg_compat`). |
| `godot/tests/lab/test_art.gd` · `test_sfx.gd` | Comparación con el oráculo, ThorVG, arreglos, caché y matemáticas de V8. |

**Resultado:** 372/372 dibujos de `art-svg.json` con el SVG idéntico byte a byte y los mismos datos; ThorVG los
rasteriza todos; el sonido coincide en los 40 escenarios del golden y en los 19 249 ensayos de la muestra; los 22
WAV tienen el sha256 del oráculo.

## Cómo sale idéntico al bit

- **Números como JavaScript:** `Js.js_num_str`, `Js.js_round`, `Js.to_fixed` y `Js.hex2` (core/shared/js.gd).
- **Mismo orden de operaciones y de llamadas al aleatorio** (`core/shared/rng.gd`). Cada `R()` de un literal de
  JavaScript se saca a una variable en el mismo orden; los puntos son listas `[x, y]` de 64 bits (Vector2 es de 32).
- **Matemáticas de V8.** La libm de Linux (glibc 2.39) difiere de V8 en el último bit en 200 000 argumentos del
  rango de los dibujos: sin 3,4 %, cos 3,3 %, pow 9,5 % y atan2 18 %. Como clawArt escribe coordenadas sin
  redondear que dependen de ellas, se portaron las de V8: fdlibm 5.3 para sin, cos, tan y atan2, y el pow de V8, que
  **no** es exactamente el de fdlibm (divide `z·t1` entre `(t1 − 2) − (w + z·w)`; fdlibm resta fuera de la división).
  El algoritmo se comprobó primero en Python (0 diferencias con V8 en esos 200 000 casos) y el port en GDScript,
  con vectores de Node para sin, cos, tan, pow y atan2, con los de `js-semantics.json` y con los 372 dibujos.
- **Constantes desde sus bits.** El lector de literales de GDScript tampoco redondea bien los decimales largos
  (`6.36619772367581382433e-01` sale 1 ulp desviado y `0.9999999999999999` se lee como 1), así que las constantes de
  fdlibm se construyen desde su patrón de bits.

## Fuentes

- V8 12.4.254 (Node 22), `src/base/ieee754.cc`: sin, cos, tan, atan2 y pow; derivado de FreeBSD msun y fdlibm 5.3
  (Sun Microsystems, 1993).
- ECMAScript, `Number::toString` (el decimal más corto que se relee igual): lo implementa `core/shared/js.gd`.
- SVG 1.1 (2.ª edición, W3C 2011): máscaras de luminancia (*Masking*), unidades de caja de objeto (*Object bounding
  box units*: la caja más ajustada de la geometría, no de los puntos de control) y `clipPath`.
- ThorVG, en la versión que trae Godot 4.7.2 (`Image.load_svg_from_string`): comportamiento medido con casos mínimos,
  no documentado.
- Chromium de Playwright (compilación 1194) para la comparación visual.
- **Sonidos:** los 22 WAV se sintetizaron en la 1.x con las recetas y semillas de sfx.js (22 050 Hz, PCM de 16 bits,
  mono). No hay muestras de terceros: licencia MIT del proyecto, nada que añadir a `THIRD-PARTY-NOTICES.md`.

## Hoja de contacto: Chromium frente a ThorVG

25 dibujos variados (7 materiales, 3 uñas de frente, 2 de perfil, 5 garras y colmillos, 3 surcos, 2 punciones, los
cortes de coche y de piel y el vidrio partido), a ×2. Columnas: el SVG del oráculo en Chromium, el mismo SVG en ThorVG
tal cual, ThorVG como lo pinta la app (con `thorvg_compat`) y la diferencia |Chromium − app| ×4. Está fuera del
repositorio, en la carpeta de salida de la sesión (`…/scratchpad/u2/hoja-de-contacto.png`, con los recortes en
`sheet/detalle-*.png` y un zoom píxel a píxel en `sheet/zoom.png`); los scripts que la generan también están ahí.

Δ = diferencia por píxel sobre 255, con el color premultiplicado por la opacidad, sobre los píxeles pintados:

| Dibujo | Id | Δ media | Δ > 8 | Δ > 32 | Δ máx. |
|---|---|---|---|---|---|
| Madera de pino (textura) | `surfaceArt#3` | 1,19 | 0,2 % | 0,00 % | 18 |
| Puerta de madera lacada | `surfaceArt#6` | 1,60 | 1,2 % | 0,00 % | 26 |
| Pintura de coche metalizada | `surfaceArt#18` | 1,37 | 1,5 % | 0,00 % | 26 |
| Moneda de cobre | `surfaceArt#30` | 1,34 | 0,0 % | 0,00 % | 10 |
| Vidrio de ventana | `surfaceArt#33` | 1,77 | 0,7 % | 0,00 % | 10 |
| Encimera de cuarzo | `surfaceArt#42` | 1,24 | 0,8 % | 0,00 % | 27 |
| Diamante | `surfaceArt#48` | 0,72 | 0,0 % | 0,00 % | 7 |
| Uña natural cuadrada | `nailArt#99` | 1,01 | 0,9 % | 0,02 % | 52 |
| Uña de metal con gema y mojada | `nailArt#143` | 1,89 | 5,4 % | 0,03 % | 45 |
| Uña de diamante con gema | `nailArt#146` | 0,93 | 1,0 % | 0,02 % | 42 |
| Uña de perfil (máscara con degradado) | `nailSideArt#147` | 2,93 | 3,5 % | 0,14 % | 62 |
| Uña de perfil stiletto de zafiro | `nailSideArt#153` | 2,96 | 3,6 % | 0,06 % | 70 |
| Garra de tigre (pelo, rayas, máscara) | `clawArt#185` | 4,64 | 10,1 % | 2,41 % | 107 |
| Garra de oso de acero, colgando | `clawArt#195` | 2,51 | 6,6 % | 0,35 % | 70 |
| Garra de águila de diamante | `clawArt#199` | 1,48 | 2,5 % | 0,12 % | 53 |
| Garra de búho (plumas) | `clawArt#215` | 4,84 | 12,7 % | 2,96 % | 114 |
| Colmillo de víbora (cabeza con máscara) | `clawArt#272` | 2,68 | 3,2 % | 0,12 % | 49 |
| Surco en la piel: laceración que sangra | `grooveArt#283` | 2,90 | 12,4 % | 0,01 % | 34 |
| Surco en el vidrio: se parte | `grooveArt#346` | 3,99 | 18,2 % | 0,10 % | 81 |
| Surco en el coche hasta el metal | `grooveArt#311` | 4,00 | 15,1 % | 0,00 % | 27 |
| Punción que atraviesa el plástico (pétalos) | `punctureArt#339` | 2,94 | 7,0 % | 1,12 % | 58 |
| Punción que atraviesa la puerta de madera | `punctureArt#296` | 4,29 | 16,0 % | 0,00 % | 25 |
| Corte del coche: punción (casuario, 500 N) | `carSectionArt#316` | 1,49 | 1,2 % | 0,64 % | 98 |
| Corte de la piel: laceración | `skinSectionArt#284` | 1,17 | 0,3 % | 0,01 % | 42 |
| Vidrio partido de canto | `paneFractureArt#369` | 2,06 | 1,7 % | 0,00 % | 17 |

A tamaño real no se distinguen salvo el cepillado de la uña de metal (punto 3 de la tabla siguiente). Los surcos
tienen muchos píxeles con Δ > 8 porque son pocos píxeles pintados y casi todos de borde.

### Diferencias y qué haría falta

| Qué | Qué hace ThorVG | Dónde se nota | Estado |
|---|---|---|---|
| **Máscara rellena con un degradado** | Deja transparente todo lo enmascarado (las máscaras sólidas, con luminancia u opacidad, sí funcionan). | Las 13 uñas de perfil salen en blanco; las 102 garras y colmillos, sin dedo, pata ni cabeza. | **Arreglado** en `svg_texture.gd`: el `<rect>` de la máscara se cambia por 64 franjas grises opacas (luminancia = valor de máscara), en orden de pintor. Con franjas semitransparentes apiladas el error de 8 bits se acumulaba (0,46 en vez de 0,51 a mitad de camino). |
| **Caja de objeto de un trayecto con curvas** | Calcula `objectBoundingBox` con los vértices, sin lo que abomban las curvas. | El brillo del barniz de las pinturas de coche (Δ media 4,32 → 1,37 al arreglarlo). | **Arreglado**: esos degradados pasan a coordenadas de usuario con la caja exacta (solo lineales alineados con los ejes, que son los de art.js). |
| **`clipPath`** | Compone el grupo recortado en una capa intermedia de 8 bits: los trazos casi transparentes (opacidad 0,06-0,2) pierden intensidad. Las mismas líneas dan Δ media 2,36 dentro del recorte y 1,02 fuera. | Cepillado de metales (uña de metal, acero, carrocerías), poros y fibras. Todas las superficies van dentro de un `clipPath`. | **Pendiente.** Opciones: (a) en `thorvg_compat`, sustituir los `clipPath` que son un rectángulo sin `rx` por el recorte geométrico de líneas y círculos (las ondas y polígonos que sobresalen necesitarían recorte de polilíneas); (b) comunicarlo a ThorVG y esperar a que Godot lo integre; (c) aceptarlo: es un matiz. |
| Degradados lineales y radiales (también `userSpaceOnUse` y paradas con opacidad) | Igual que Chromium. | — | Nada. |
| Opacidad (`fill-opacity`, `stroke-opacity`, `opacity` de grupo) | Igual fuera de un `clipPath`. | — | Nada. |
| Antialias de bordes y extremos redondos | Misma «tinta» en líneas finas (±1 %), extremos redondos un 5 % más gruesos y diferencias de una o dos filas en cada borde. | Pelo de garras (hasta Δ 114 en píxeles sueltos; Δ > 32 en menos del 3 % de lo pintado), grietas y bordes de surcos. | Nada: invisible a tamaño real. Hay que rasterizar a la escala de la pantalla (`SvgTexture.screen_scale`) y no reescalar la textura. |
| Geometría de `clipPath` y máscaras sólidas | Igual. | — | Nada. |
| Texto | Los SVG no llevan texto: los rótulos de los cortes salen como datos (`labels`). | — | La app los escribe con Syne y Space Mono. |
| `stroke-dasharray` | El dibujo estático sale igual. | La 1.x anima el trazo del surco con `strokeDasharray = length`. | En Godot la textura es fija: la animación del surco habrá que hacerla revelando la textura (recorte o *shader*). |

Los tests `test_arreglo_*` comprueban también que ThorVG **sin** arreglo sigue fallando: si una versión nueva de
Godot lo corrige, esos tests lo dirán y el arreglo se podrá quitar.

## Tiempos medidos

En la nube, con 4 núcleos compartidos con otros agentes (varían un ±40 % con la carga):

- **Construcción del grafo:** 0,3-8 ms por dibujo (media 2,4-3,5 ms). `js_sin` cuesta ~2 µs.
- **Serialización:** media 25-38 ms, máximo 670 ms (cuarzo 300 × 60: 8013 números sin redondear). El 90 % es
  `Js.js_num_str`: 76 µs con un double «largo» frente a 1,8 µs con tres decimales o menos.
- **ThorVG:** 1,4-3,3 ms por dibujo a ×1 (con los arreglos); 0,4-18 ms a ×2.
- **Total por dibujo** en `test_art.gd`: 29-42 ms. Sonidos: 19 249 ensayos en ~1 s.

## Para el coordinador

1. **Acelerar `Js.js_num_str` (core/shared/js.gd, que no es de esta unidad).** `_shortest` prueba de 0 a 44
   decimales; casi todos los doubles «largos» necesitan 15-17 cifras significativas. Propuesta validada fuera del
   repositorio: empezar en 15 cifras; si no bastan, subir; si bastan, bisección hacia abajo (aceptar con d decimales
   es monótono en d). Mismos resultados en los 863 casos de `js-semantics.json`, en 90 000 doubles aleatorios y en los
   372 SVG; **3-5 veces más rápido** (serialización media de ~25-35 ms a 7-10 ms por dibujo). Sustituye el bucle final
   de `_shortest`:

   ```gdscript
   	var e10 := int(floor(log(ax) / log(10.0)))  # orden de magnitud (aproximado: la búsqueda lo corrige)
   	var d0 := clampi(14 - e10, 0, 44)  # 15 cifras significativas
   	var r0 := _try_d(ax, d0)
   	if r0.size() == 1:
   		return []
   	if r0.is_empty():  # 15 cifras no bastan: 16 o 17
   		for d in range(d0 + 1, 45):
   			var r := _try_d(ax, d)
   			if r.size() == 1:
   				return []  # el entero escalado ya no cabe en 63 bits
   			if not r.is_empty():
   				return r
   		return []
   	var lo := 0
   	var hi := d0  # con hi decimales siempre vale
   	var best := r0
   	while lo < hi:
   		var mid := (lo + hi) >> 1
   		var r := _try_d(ax, mid)
   		if r.size() == 2:
   			hi = mid
   			best = r
   		else:
   			lo = mid + 1
   	return best


   ## [dígitos, d] si algún decimal con d decimales se lee como ax; [] si no; [0] si el entero escalado no cabe.
   static func _try_d(ax: float, d: int) -> Array:
   	var n := _scaled_int(ax, d)
   	if n < 0:
   		return [0]
   	var best := _pick([n, n - 1], -d, ax)
   	return [str(best), d] if best > 0 else []
   ```

2. **Matemáticas de V8 a `core/shared/js.gd`.** `Art.js_sin`, `js_cos`, `js_tan`, `js_atan2` y `js_pow` deberían ser
   `Js.sin`… La física (unidad 1) usa `Math.pow` y sus textos (`toFixed`) podrían cambiar en un último bit.
3. **Números exactos en `lab-golden.json` y `lab-sample.json`.** Hoy van en decimal y el lector JSON de Godot lee
   `110.00000000000001` (una garra que se queda justo en la chapa) como `110`: `depthUm > 110` cambia y con él el
   sonido (411 ensayos de la muestra). `test_sfx.gd` lo esquiva leyendo exactos solo los `depthUm` y `sev` que caen
   junto a un umbral. Lo limpio es exportar el `result` con el reemplazador exacto (`$f64`) como `art-svg.json`: le
   servirá también a la unidad 1 en sus umbrales de veredicto.
4. **Copias de data.js en `looks.gd`.** `PAINT_LAYERS`, `SKIN_LAYERS` (campos del corte), `CAR_BODY` y la paleta `C`
   son copias; `Art._car_layers` y `Art._fmt_depth` duplican `carLayers` y `fmtDepth`. Cuando esté `core/lab/data.gd`
   (y `physics.gd`), que apunten allí (`const PAINT_LAYERS = Data.PAINT_LAYERS`…). Mientras, `test_art.gd` comprueba que
   son iguales que las del oráculo.
5. **Paleta duplicada.** `Looks.C` y `app/theme/palette.gd` (`HEX`) son la misma tabla; core no puede depender de app.
   Propuesta: una sola en core (la de data.gd o `core/shared/palette.gd`) y que `palette.gd` la lea.
6. **App:** crear una `SvgTexture` por vista y cachear también por argumentos (material, tamaño, resultado) para no
   serializar cuando nada cambia; la caché de `SvgTexture` va por el texto del SVG.
7. Los ángulos de más de 2^19·π/2 (nunca en los dibujos) usan la libm de la plataforma: la reducción de argumentos
   grandes de fdlibm no está portada.

## Pendiente

- El `clipPath` de ThorVG (tabla de diferencias).
- La integración en escenas (banco, fichas, cortes con sus rótulos y la animación del surco): unidad 12.
- Estilo: se sigue el del código existente (líneas de hasta ~148 caracteres, nombres cortos como `R`, `H`, `N`), no
  los valores por defecto de gdlint.
