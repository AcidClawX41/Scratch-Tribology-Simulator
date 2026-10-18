# Unidad 12 · Estructura del programa e interfaz del laboratorio

El programa de la V2 (un solo programa con dos secciones) y la sección **Tribología biológica**: el port a Godot
4.7.2 de la interfaz 2D de la 1.x (`apps/desktop/src`: App.jsx, las siete tarjetas, Bench, Scene, sections y
styles.css), con las mismas tarjetas, los mismos textos y las mismas ilustraciones. **No hay física nueva ni datos
nuevos**: la interfaz pinta lo que devuelve el core (`Physics.compute`, `Lab.*`, `Art.*`, `Sfx.*`) y nunca lo
recalcula.

## Qué hay

| Archivo | Qué hace |
|---|---|
| `godot/app/main.gd` · `main.tscn` | El programa: barra superior (nombre, titular de la sección, selector «Tribología biológica · Taller industrial», Fundamentos, sonido), las secciones, el pie (versión y `Lab.license_note`) y la ventana de créditos. Ajustes y escala |
| `godot/app/theme/app_theme.gd` | Tema de Godot construido en código con la paleta única (`palette.gd` → `core/shared/theme.gd`) y las fuentes Syne y Space Mono: tarjetas, píldoras, selectores, fichas, deslizadores, barras de desplazamiento, ayudas y foco visible |
| `godot/app/common/` (nuevos) | Piezas reutilizables, también para el taller: `card`, `segmented`, `pill`, `content_button` (botón con ilustración y textos), `value_slider`, `metric`, `bar`, `tile_grid` (auto-fill/minmax), `wrap_box` (fila que se parte), `overlay` (hoja superpuesta), `sfx_player`, `ui` (textos, cubic-bezier, ayuda emergente), `art_cache` (SVG → textura en hilos) y `art_view` (dibujo con sus rótulos) |
| `godot/app/lab/lab_section.gd` · `.tscn` | La sección: dos columnas o una, estado (`LabState`), caché de dibujos, sonido, atajo y refresco |
| `godot/app/lab/*_card.gd` | Herramienta, Material, Parámetros, Banco de ensayo (resultado), Modo dual, Comparativa y Logros con el cuaderno |
| `godot/app/lab/bench.gd` | El banco animado |
| `godot/app/lab/lab_art.gd` | Los dibujos que la 1.x componía en la interfaz: la losa del banco, el surco en dos partes, el corte de la puerta y el perfil de la huella (con el grafo de `art.gd` y números de `js.gd`) |
| `godot/app/lab/skin_table.gd` · `lab_ui.gd` · `run_button.gd` | Tabla de la piel, fichas y claves de dibujo, botón ARAÑAR |
| `godot/app/lab/demo_lab.gd` · `.tscn` | Demo guionizada de seis ensayos (escritorio y teléfono) |
| `godot/tests/app/test_*.gd` | 17 tests: interfaz contra el core, programa, piezas comunes y tiempos |

## Contrato de las secciones (para la unidad 13 y la integración)

- **Escenas.** bio: `res://app/lab/lab_section.tscn`; taller: `res://app/taller/taller_section.tscn` si
  `ResourceLoader.exists(...)`; si no, un aviso «en construcción». Cada sección se instancia la primera vez que se
  muestra y ya no se destruye.
- **Raíz.** Un `Control`; `main.gd` lo pone a pantalla completa dentro de su hueco (entre la barra y el pie). Si la raíz
  no es un `Control`, se avisa y se muestra el aviso.
- **Proceso.** Al cambiar de sección, la oculta pasa a `PROCESS_MODE_DISABLED` (se paran su `_process`, su entrada, sus
  animaciones y los sonidos pendientes) y la visible, a `PROCESS_MODE_INHERIT`.
- **Opcionales en la raíz** (se llaman si existen): `headline() -> String`, el titular grande de la barra (el
  laboratorio: «¿Qué raya a qué?»; sin él, el nombre de la sección); `fundamentos() -> Array` de `[título, texto]` y
  `fundamentos_note() -> String` para la hoja «Fundamentos»: sin `fundamentos()`, el botón se oculta.
- **Sonido.** Cada sección suena por su bus: el laboratorio por «Lab», el taller por «Maquina». El interruptor general
  silencia «Master» (y antes suena su confirmación «off», como en la 1.x).
- **Ajustes.** `user://ajustes.cfg`, sección `[app]`: `section` (`bio` o `taller`) y `sound` (`true`/`false`). Las
  secciones pueden guardar lo suyo en otras secciones del mismo archivo.
- **Escala.** `main.gd` usa `content_scale_mode = DISABLED` y `content_scale_factor` = escala de la pantalla
  (`--escala=N` la fuerza): el tamaño lógico es el de la ventana entre la escala, así el diseño se adapta de verdad
  (dos columnas desde 1060 px lógicos, una por debajo; barra compacta por debajo de 700 px). Las secciones deben ser
  adaptables a partir de ~360 px de ancho.
- **Aspecto.** El mismo lenguaje visual: `app/theme/app_theme.gd` (variaciones de tipo en su cabecera) y las piezas de
  `app/common/`.

## Decisiones

- **La interfaz no calcula física.** Todo sale del core: `LabState` (estado, temporizadores, sonidos, logros y
  cuaderno), `Physics.compute` (la comparativa, como la CompareCard de la 1.x), `Lab.duel`, `duel_verdict`,
  `damage_report`, `claw_spec`, `target_sub`, `max_force_hint`, `tool_label`, `Format.*` y `Physics.pass_depth_factor` /
  `tear_leverage` para las notas. Los números visibles y los del SVG pasan por `Js.to_fixed`, `Js.js_num_str`
  (`Ui.num`) y `Format`.
- **Construir una vez, actualizar con `changed`.** Cada tarjeta se construye al principio (con reservas para las
  listas: 20 métricas, 17 filas de la comparativa, 4 del duelo, 6 del cuaderno) y `refresh()` solo cambia textos,
  colores y visibilidad. La sección refresca como mucho una vez por fotograma. La comparativa (17 ensayos) y el modo
  dual (hasta 8) se recalculan solo si cambian sus entradas (firma) y, mientras se arrastra un deslizador, como mucho
  cada 150 ms; al pulsar ARAÑAR, siempre al momento.
- **Dibujos: `ArtCache` + `ArtView`.** Construir y serializar un dibujo cuesta de 1 a ~170 ms (el cuarzo del banco es
  el peor; el 80-90 % es `Js.js_num_str`), así que se hace en hilos de `WorkerThreadPool` y la textura llega en un
  fotograma posterior. La clave de cada dibujo lleva todas sus entradas (las del `memoArt` de la 1.x), el SVG se
  guarda por clave (cambiar de escala solo repite ThorVG) y se rasteriza a la escala real de la pantalla
  (`SvgTexture.screen_scale`). Las funciones que van a los hilos son estáticas y puras, llamadas sobre su script
  (nunca sobre un nodo), y reciben copias de los resultados. Sin hilos (`threaded = false`) todo es inmediato (tests).
- **Rótulos con `Label`.** ThorVG no pinta `<text>`: los rótulos de los cortes (`labels` de `car_section_art`,
  `skin_section_art` y los de la puerta y el perfil) se escriben con `Label` encima del dibujo, con su línea base, su
  `text-anchor` y el tamaño escalado con el mismo factor.
- **Banco animado.** Mismo lienzo (360 × 170), posiciones y escalas que Bench.jsx; la animación sigue a la de la app
  móvil (Bench.js), la que dibuja el surco a la vez que avanza la punta: rayado en 1,1 s con cubic-bezier(.45,.05,.25,1)
  y el surco revelado recortando su textura a la izquierda de la punta; los extras aparecen en el último 15 %.
  Punción: baja en 0,9 s (cubic-bezier(.6,0,.9,.4)), la huella aparece desde el 78 % y la punta se retira 14,5 en
  0,5 s. En reposo la punta vuelve a su sitio con suavidad. Con «movimiento reducido» (el ajuste del sistema,
  `DisplayServer.accessibility_should_reduce_animation`, o `--movimiento-reducido`) salta al final.
- **Caja de la herramienta del banco medida.** En la 1.x el banco no recorta la herramienta: la garra colgando asoma
  fuera de `0 0 100 132` (de −24 a 116 en x y de −62 a 117 en y) y el dedo de la uña de perfil llega a (−149, −113).
  Se midió rasterizando todas y se rasteriza esa caja (`Bench.CLAW_VIEW`, `NAIL_VIEW`); un test comprueba que la punta
  de cada garra cae dentro.
- **Orden estable en la comparativa.** El `sort` de JavaScript es estable y hay empates de presión nominal (gato,
  halcón y pájaro tienen la misma área): se desempata por el orden del catálogo, como en la 1.x.
- **Adaptable.** Dos columnas (460-560 px la de configuración) desde 1060 px, una de hasta 640 px por debajo. Las
  rejillas de fichas y métricas son `auto-fill, minmax()` (`TileGrid`); las cabeceras, la vista previa, los dos coches
  y las filas del duelo pasan de fila a columna cuando no caben (`WrapBox`). En el teléfono la barra superior queda en
  dos filas y Fundamentos y Sonido bajan al pie, solo con su icono. El atajo Ctrl/⌘+Intro se atiende en `_input`
  (antes que el botón con el foco).
- **Mejoras que no cambian resultados.** Ayudas emergentes con la `desc` de cada garra y material de uña, la `fact` de
  cada material, la dureza de las gemas y la nota de cada capa de la piel; nombres accesibles (`accessibility_name`) y
  región viva (`accessibility_live`) en el veredicto; foco visible; transiciones de las barras; en la 1.x, pulsar la
  opción ya elegida reseteaba el banco: aquí no hace nada.
- **Emoji.** Los textos de la 1.x llevan emoji (💅, 🐾, 💧, 💥, 🪝, 🧪 y los de los logros). Se pintan con la fuente de
  emoji del sistema (Noto Color Emoji en el contenedor; Apple y Segoe en macOS y Windows; iOS y Android traen la suya).

## Verificación

| Comprobación | Resultado |
|---|---|
| `tests/app/test_lab_ui.gd`: 27 ensayos pulsando la interfaz (uñas, gemas, uña mojada, garras, desgarro, colmillos, punción con golpe, piel, coches, vidrio, puerta de roble, puerta de aluminio, diamante) | veredicto, color, subtítulo, etiquetas DESGARRO/HÚMEDA, métricas, corte, cuaderno y sonido idénticos a los de `Physics.compute()`, `Lab.tool_label()` y `Sfx.sfx_for_result()`; `lab.res` sin ninguna diferencia (`oracle_diff`) |
| Modo dual (dos pasadas, cambiando un coche) | bancos, veredictos, informe de daños y tabla idénticos a `Lab.duel`, `damage_report` y `duel_verdict` |
| Comparativa | 17 filas = `compute()` de cada garra, orden estable; pulsar una fila elige esa garra |
| `tests/app/test_main.gd` | la sección oculta queda en `PROCESS_MODE_DISABLED`; aviso del taller; ajustes `section` y `sound` guardados y leídos; Master silenciado; pie, créditos (Godot, sus componentes y sus licencias) y fundamentos |
| `tests/app/test_widgets.gd` | cubic-bezier como CSS, rejilla y caja adaptables, caché (no vuelve a rasterizar lo mismo), animación del banco y tiempos |
| `npm run godot:test` | 155 tests, 0 fallidos, sin «SCRIPT ERROR» |
| `npm test` (motor 1.x) y `git diff 9e40135 -- packages/core/src packages/core/test` | 115 en verde · oráculo intacto |

**Capturas revisadas** (Movie Maker, fuera del repositorio, en `…/scratchpad/u12/`): la demo completa en escritorio
(1240 × 880) y en teléfono (390 × 844), a 6 fps. Se han mirado el arranque (fichas llegando de los hilos), la mitad de
cada animación (garra de tigre rayando la chapa con el surco revelándose, colmillo y casuario bajando), cada
resultado (veredicto, barras, métricas y cortes), el modo dual en paralelo y apilado, la hoja de Fundamentos y el
cambio de sección. En el WAV suenan los clics, el rayado, la inyección, la punción, el «on» del modo dual y las
fanfarrias de los logros en sus instantes.

Movie Maker graba siempre al tamaño del proyecto (1240 × 880), aunque la ventana sea de 390 × 844: por eso la demo,
en modo teléfono, mete el programa en un `SubViewport` del tamaño pedido, centrado y con el guion al lado.

## Tiempos medidos

Contenedor de 4 núcleos compartidos (varían ±40 % con la carga):

| Qué | Tiempo |
|---|---|
| Losa del banco (construir + serializar + ThorVG a ×2) | ~50 ms de media; peor ~165 ms (cuarzo), en un hilo |
| Ficha de garra (100 × 132) | ~11 ms |
| Volver a rasterizar a otra escala (SVG ya guardado) | ~7 ms |
| Muestra de material (120 × 34) · uña de frente · gema | ~12 ms · ~2 ms · < 1 ms |
| Corte del coche · corte de la piel | ~50 ms · ~45 ms |
| Arranque: 50 dibujos (fichas, vistas previas, banco) | ~240 ms de trabajo en hilos; la interfaz no se para |
| Un ensayo por la interfaz (clics, `compute`, fin de la animación y refresco) | ~10 ms de media; el refresco final, ~1,1 ms |
| Comparativa: 17 `compute()` | 1,5 ms (rayando piel) a 45 ms (golpes contra un coche) |
| Modo dual: `Lab.duel` (8 ensayos con golpe) | ~8 ms |

## Pendiente

- Probar en el Mac del autor la escala HiDPI (`screen_get_scale` = 2) y el tamaño inicial de la ventana (se agranda a
  1240 × 880 lógicos si cabe), y en un teléfono real las zonas seguras (muesca), el tamaño de los toques y que
  arrastrar sobre las fichas desplace la columna (en el contenedor solo se ha probado con ratón y Movie Maker).
- Precalentar en segundo plano las losas del banco de todos los materiales para que cambiar de material sea instantáneo
  (hoy la del cuarzo tarda ~170 ms en un hilo y mientras se ve la anterior).
- Hápticos del móvil 1.x (expo-haptics): sin portar.
- El recorte con `clipPath` de ThorVG (matiz en los metales cepillados), pendiente de la unidad 2.

## Para el coordinador

1. **Escala del proyecto.** `project.godot` estira un lienzo de 1240 × 880 (`canvas_items` + `expand`). Con eso, en un
   teléfono de 390 px de ancho el programa sería el de escritorio en miniatura. `main.gd` lo cambia al arrancar
   (`CONTENT_SCALE_MODE_DISABLED` + `content_scale_factor` = escala de la pantalla). Propongo dejarlo así también en
   `project.godot` (`window/stretch/mode="disabled"`) para que el editor y las escenas sueltas se comporten igual.
2. **Movie Maker graba al tamaño del proyecto**, no al de la ventana: `godot.mjs capture --size=390x844` no da un
   vídeo de teléfono. La demo lo resuelve con un `SubViewport`; si se quiere en general, `capture` podría escribir el
   tamaño en `display/window/size/viewport_*` con un `override.cfg` temporal.
3. **`Js.js_num_str`** es el 80-90 % del coste de un dibujo. La propuesta de la unidad 2 (empezar por 15 cifras y
   bisecar) lo haría 3-5 veces más rápido; con ella los hilos casi sobrarían.
4. **CONTRATOS.md**: añadir el contrato de las secciones de arriba (escenas, raíz, proceso, `headline`, `fundamentos`,
   buses, ajustes y escala) y que la interfaz del taller reutilice `app/theme/app_theme.gd` y `app/common/`.
5. **Tests con fotogramas.** El ejecutor corre en `_init()`, sin árbol de escena: los contenedores no se colocan y
   `Range` no emite `value_changed`. Los tests de interfaz lo sortean (disposición como funciones puras; el
   deslizador emite la señal a mano, como haría el motor). Un modo del ejecutor que esperase fotogramas permitiría
   probar también la disposición real.
6. **Emoji.** Dependen de la fuente del sistema. Si alguna plataforma no la trae, saldrían cuadros vacíos: la opción es
   empaquetar Noto Color Emoji (OFL, ~10 MB) y añadirla a `THIRD-PARTY-NOTICES.md`, o quitar los emoji de los textos.
7. **Sin dependencias nuevas**: nada que añadir a `THIRD-PARTY-NOTICES.md`.
