# Unidad 13 · Controlador e interfaz del Taller industrial

La sección **Taller industrial** del programa: el torno (CNC Fagor 8055 T y torno paralelo), la radial contra chapa
de coche, la afiladora y las calculadoras de corte, con el mismo lenguaje visual que el laboratorio (tarjetas,
paleta glam-lab, Syne y Space Mono). Es educativa, no un videojuego: vistas de detalle de la herramienta, la pieza y
el material, y los parámetros de cada máquina ajustables.

**La interfaz no calcula física.** Todo lo que enseña sale de `core/taller` a través de un solo estado,
`WorkshopState`; las páginas pintan y le mandan los cambios. Esta unidad no añade datos ni fórmulas: los números,
las fuentes y las estimaciones son los de las unidades 3 a 9 y 14 (sus `fuentes-u*.md`).

## Archivos

| Archivo | Qué hace |
|---|---|
| `godot/core/taller/workshop_state.gd` | Controlador del taller (el gemelo de `core/lab/lab_state.gd`): `RefCounted`, sin nodos, determinista, con la señal `changed`. Máquina activa; torno (programa, reproducción, manual, lecturas, informe, sonido); radial; afiladora; calculadoras; fundamentos para la barra |
| `godot/app/taller/taller_section.tscn` + `.gd` | Raíz de la sección (contrato con `app/main.gd`): pestañas de máquina, aviso de valores orientativos, páginas, sonido; `headline()`, `fundamentos()` y `fundamentos_note()` |
| `godot/app/taller/ui/lathe_page.gd` | Torno: escena 3D, media sección con cotas, pieza y control, reproducción, mando manual, lecturas, informe, alarmas y programa editable |
| `godot/app/taller/ui/profile_view.gd` | Vista 2D de media sección, como la gráfica del Fagor |
| `godot/app/taller/ui/radial_page.gd` | Radial: escena 3D, disco y radial, chapa y corte, resultado, avisos con fuente |
| `godot/app/taller/ui/sharpener_page.gd` + `sharpen_view.gd` | Afiladora: esquema de la muela y el filo, herramienta, máquina y muela, afilado recomendado, avisos |
| `godot/app/taller/ui/calc_page.gd` | Calculadoras de torneado, fresado y taladrado |
| `godot/app/taller/ui/style.gd` | Todos los estilos del taller en un solo archivo (tema local de la sección) |
| `godot/app/taller/ui/fmt.gd` | Números en pantalla: `js.gd` (`to_fixed`), coma decimal y punto de miles |
| `godot/app/taller/ui/card.gd`, `two_pane.gd`, `view3d.gd` | Tarjeta, reparto en una o dos columnas y vista 3D en su SubViewport |
| `godot/app/taller/ui/demo_taller.tscn` + `.gd` | Demo guionizada para las capturas |
| `godot/tests/taller/test_workshop_state.gd` | 11 tests del controlador |
| `godot/tests/app/test_taller_ui.gd` | 11 tests de la interfaz sin ventana |

Cambios en archivos de otras unidades (permitidos por el encargo):
- `app/taller/radial_3d.gd` y `app/taller/radial3d/looks.gd` (petición del coordinador): la pintura sale de
  `Panels.get_panel(id).paint_um`. Las piezas de rescate (`boro-22mnb5`, `dp800`) tienen 0 µm: la escena ya no les
  pone las capas de pintura, ni el color de coche, ni la cataforesis interior; la cara de fuera es el acero
  (`metal`/`metal_lo`), y los rótulos del canto y de la vista cenital no hablan de pintura. Las carrocerías pintadas
  quedan igual (110 µm, las mismas capas).
- `app/taller/radial_3d.gd`: los números de los rótulos de las vistas a escala («surco 1,40 mm») con coma decimal,
  como el resto de la interfaz (`_es`, con `Js.to_fixed`).
- `app/taller/lathe_3d.gd`: sin cambios.

## Decisiones

### Controlador (`WorkshopState`)
1. **Un solo lector del perfil del torno.** `Lathe.profile()` consume el rango `dirty`. El estado lo lee una vez por
   avance y acumula el rango para la escena 3D, que usa el estado como fuente (`profile()` y `tool_pose()`, el
   contrato de `set_profile_source`); la vista 2D y la inspección usan `peek_profile()`, que no lo consume. Un bruto
   nuevo con la misma rejilla (reinicio) marca todos los anillos: si no, la malla 3D no se reconstruye
   (`LatheMesh.matches` solo mira la rejilla) y se quedaría con la pieza vieja.
2. **Reproducción.** `advance(dt)` avanza `dt × velocidad` en subpasos de 0,05 s (el paso del test de integración),
   con un tope de 4 s simulados por llamada. Como el torno cuenta ticks enteros de 1 ms, el reparto del tiempo no
   cambia la pieza: la pieza A a ×50 con fotogramas de 1/30 s da **el mismo informe** que
   `tests/integration/test_taller_pipeline.gd` (mismas medidas, bit a bit; nota 9,6).
3. **Bloque a bloque** ejecuta hasta que empieza el siguiente bloque N (subpasos de 10 ms): un ciclo fijo (G81, G82,
   G68) es un solo bloque, como en el control.
4. **Un programa con errores no arranca** y lo dice: el intérprete ya salta los bloques erróneos, pero ejecutar el
   resto rompería la plaquita en el bruto (el programa con 3 errores, corregido, acaba en `AP_EXCEEDED`).
   El editor marca en coral las líneas de los errores y en verde menta la que se ejecuta.
5. **RESET** borra la alarma y cancela el programa (la pieza se queda como está); **Reiniciar** pone un bruto nuevo.
6. **Pausa = retención de avance:** el cabezal sigue girando, los ejes no avanzan y no hay corte (sin Pc en el sonido
   ni virutas).
7. **Manual = torno paralelo** (`Lathe.MACHINES.manual`, otra máquina: bruto nuevo al cambiar de modo). Caja de 12
   velocidades, avance longitudinal de la ficha (0,05–0,75 mm/vuelta) y transversal a su relación (0,025–0,375;
   lo da `manual_feed_x()`, la interfaz no lo calcula),
   manivelas de 0,001/0,01/0,1 mm (X en diámetro, como el visualizador), herramienta del catálogo de `lathe_tools`,
   material del bruto (cualquiera de `work_materials`: sin kc, el torno corta la geometría y la tarjeta enseña
   `cut_reason`), taladrina y «Medir la pieza» contra su plano.
8. **Lecturas.** Las de `state()` del torno, más vc en la punta con el cabezal girando sin cortar
   (`Cutting.vc_from_rpm`) y el Ra del anillo recién mecanizado 0,5 mm por detrás del contacto (`ring_ra`; «—» si no
   está mecanizado).
9. **Sonido ya convertido.** `lathe_sound_input()` pasa `tool_pos` de mm y coordenadas de la pieza a metros en el
   sistema del nodo de sonido: origen en Z0 sobre el eje, x hacia el contrapunto, z hacia el operario (el marco de
   `lathe_3d.gd`). El CNC regula el giro con variador (`speed_droop = 0`). La radial pasa la potencia del corte solo
   mientras el disco está dentro de la chapa; la afiladora, la potencia de la operación nominal del modelo térmico.
10. **Radial.** Solo se ofrecen los diámetros que el fabricante hace de cada disco (`rpm_by_diameter`); al cambiar
    de diámetro, la radial es la de ese tamaño y gira a sus rpm nominales (`Radial.grinder_for`). Discos y chapas: los
    4 discos y las 6 chapas del contrato (las 4 carrocerías del laboratorio y las 2 piezas de rescate); los demás
    discos de `abrasives.gd` no tienen aspecto en la escena 3D (pendiente).
11. **Calculadoras.** El torneado lleva la máquina del torno CNC (7,5 kW, 3000 rpm, η 0,8) para el aviso de
    sobrecarga; la fresadora y el taladro no tienen ficha en el taller: sin máquina, sin ese aviso.
12. **Fundamentos** (`WorkshopState.FUNDAMENTOS`): ocho resúmenes de los modelos de core/taller con su fuente, para
    la hoja «Fundamentos» de la barra.

### Interfaz
1. **Escenas 3D en su SubViewport** (`view3d.gd`) con `own_world_3d`: el torno y la radial no se ven entre sí. Se
   crean la primera vez que se enseña su página y solo dentro del árbol (los tests no las crean). La página oculta
   pasa a `PROCESS_MODE_DISABLED` (su escena 3D se para) y su SubViewport no se dibuja (`UPDATE_WHEN_VISIBLE`).
2. **El sonido** es un `MachineSoundPlayer` hijo de la sección con `use_3d = false` (en la raíz no hay cámara: voces
   no posicionales, paneo desde `tool_pos.x`). Suena una máquina a la vez, la de la pestaña; el interruptor general
   es el de la barra de `main.gd` (bus Master).
3. **Teléfono.** Por debajo de 820 px de ancho cada página pasa a una columna desplazable (`two_pane.gd`), con la
   vista arriba; la malla de la pieza baja a 32 lados y 800 anillos (`configure_lod`, lo que pide la unidad 9).
4. **Tema local.** `style.gd` construye un tema que la sección aplica a su raíz, con variantes por nombre
   (`TallerTitulo`, `TallerTarjetaPanel`, `TallerFicha`…). La unidad 12 hizo el tema global a la vez
   (`app/theme/app_theme.gd`); dentro del programa, el del taller manda en su rama. Unificarlos es trabajo de
   integración (ver «Para el coordinador»).
5. **Fuente de respaldo.** El subconjunto latino de Space Mono y Syne no trae →, ≈, ₂, π, ε, κ o γ, que salen en los
   textos del core; las fuentes del taller llevan de respaldo la de Godot (`ThemeDB.fallback_font`, empaquetada con
   el motor): en las capturas se ven bien.
6. **Números.** Todo lo que se ve pasa por `fmt.gd` → `Js.to_fixed` (coma decimal, punto de miles, «—» sin valor).
   Número y unidad van con espacio de no separación (` `): en teléfono la unidad no se queda sola en otra línea.
7. **Recuadros a escala de la radial** apagados de entrada: en una columna de ~700 px taparían media vista; las
   vistas «Canto a escala» y «Surco a escala» dan lo mismo a pantalla completa.
8. Los recorridos de los deslizadores (rpm de la radial hasta 1,3 veces el límite, para ver el aviso de exceso;
   rpm y diámetro de muela por máquina; entradas de las calculadoras) son de interfaz, no datos: fuera de lo
   publicado, el core avisa.

## Verificación

- `npm run godot:test`: 336 tests, 0 fallidos (22 de esta unidad), sin «SCRIPT ERROR». `npm test`: 115 en verde.
  Oráculo intacto: `git diff --exit-code 9e40135 -- packages/core/src packages/core/test` vacío.
- Tests del controlador: la pieza A a ×50 da el mismo informe que la integración; pausa, bloque a bloque, velocidad
  y reinicio; los tres errores didácticos con su línea y su N, el editor que los corrige y B con su aviso de
  G41/G42; alarma, RESET y reinicio; mando manual (cabezal, manivelas, avance automático, herramienta, taladrina,
  medir, otro material); el rango sucio acumulado para la escena 3D; la entrada de sonido en metros; radial,
  afiladora y calculadoras iguales a lo que devuelve el core.
- Tests de la interfaz, sin ventana: la sección carga, cambia de máquina (y la oculta no procesa), reproducir
  avanza el torno, el informe aparece al terminar con su tabla y la capa de desviación, el editor marca los errores
  y los corrige, el mando manual, los controles de la radial cambian el resultado (surco, limpieza, aviso de
  exceso de velocidad, avisos de rescate con su fuente, diámetros del fabricante, «sin pintura» en el pilar),
  afiladora y calculadoras, contrato con la barra (titular y fundamentos) y el modo teléfono.
- Hallazgo de Godot 4.7.2: fuera del árbol, cambiar `value` de un `Range` no emite `value_changed`. Los tests
  emiten la señal a mano al «arrastrar» un deslizador (`_drag`).
- Dentro del árbol (script aparte, fuera del repositorio): la sección a 1240 px con el torno cortando, a 390 px
  (una columna, con la escena 3D ya creada: las columnas se mueven, no se rehacen), la radial y otra vez a 1240 px,
  sin errores y con la escena del torno en su sitio. Ancho mínimo de cada columna a 390 px (hay 362): torno en
  manual 287 px, radial 314, afiladora 306, calculadoras 285.
- Al cerrar el programa con una máquina sonando, Godot avisa de reproducciones de audio vivas: es el caso que ya
  documenta `machine_sound_player.gd` (`stop_now`: el servidor de audio las suelta en la mezcla siguiente, que ya
  no llega); no pasa durante la sesión.

## Medidas (nube: 4 núcleos compartidos, OpenGL por software)

Coste por fotograma de la sección sin ventana (simulación del torno y actualización de la interfaz, sin dibujar), la
pieza A con fotogramas de 1/60 s:

| Velocidad | Mediana | p95 | Máximo |
|---|---|---|---|
| ×1 | 0,16 ms | 0,56 ms | 2,0 ms |
| ×5 | 2,05 ms | 3,1 ms | 6,4 ms |
| ×50 | 8,1 ms | 11,3 ms | 48 ms (el fotograma del informe: inspección y tabla) |

Con ventana (Xvfb, `--rendering-driver opengl3`, 1240 × 880, sin Movie Maker), tiempo real entre fotogramas:

| Página | Mediana | p95 | Fotogramas por segundo |
|---|---|---|---|
| Calculadoras (solo 2D) | 20 ms | 29 ms | ≈ 50 |
| Radial (escena 3D) | 89 ms | 398 ms | ≈ 11 |
| Torno (escena 3D de la unidad 9, MSAA 4× y sombras) | 536 ms | 913 ms | ≈ 1,9 |

El torno lo limita el dibujo por software de su escena (la unidad 9 medía 0,2-0,9 s por fotograma en 3D); la
interfaz y la simulación caben de sobra en 16,7 ms incluso a ×50. En un equipo con GPU no se ha podido medir.

Captura de la demo (Movie Maker, 500 fotogramas a 30 fps): escritorio en 3 min 12 s; teléfono en 1 min 47 s.

## Capturas revisadas (fuera del repositorio)

Demo `app/taller/ui/demo_taller.tscn`, en escritorio (1240 × 880) y en teléfono (390 × 844 dentro del fotograma,
como la demo del laboratorio: Movie Maker graba siempre al tamaño del proyecto):
- **Torno:** vista frontal y de detalle cortando a ×5 (virutas, taladrina, la plaquita en la pieza), media sección
  con cotas y la herramienta del catálogo, lecturas en vivo (1.162 rpm con G96, 180 m/min, 0,25 mm/vuelta, Pc
  0,72 kW, Ra 2,12 µm…), a ×50 hasta el final e **informe de inspección** (9,6/10; el chaflán 0,76 fuera, en coral;
  diámetros y longitudes dentro; Ra 0,78 µm en las tres zonas) con la **capa de desviación** en 3D (verde en
  tolerancia, ámbar en el chaflán).
- **Radial:** disco fino y disco grueso en acero dulce (chispas, humo, surco), y el **pilar B de boro en el canto a
  escala**: acero desnudo, sin capas de pintura ni rótulo de pintura («acero al boro 1,50 mm», «surco 1,40 mm»,
  «rebaba 79 µm»).
- **Afiladora:** cuchillo en el Tormek (muela en su bandeja de agua, 17,5° por lado · 35° incluido) y broca en la
  esmeriladora (punta de 118°, incidencia de 10°, hélice N; 31,21 m/s frente a 35 de máximo).
- **Calculadoras:** torneado y fresado con kc, su banda y su desglose, fuerzas, potencias, par, caudal, Ra ideal y
  vida.
- **Teléfono:** una columna; tras los arreglos, nada se sale de los 390 px (la tabla del informe, las fichas de
  discos y chapas, los títulos de los deslizadores, el valor del avance del mando manual y algunas etiquetas largas
  lo hacían; ahora ninguna columna pide más de 314 px de los 362 que tiene).
- **Torno paralelo** (`--parte=manual`, escritorio y teléfono): 745 rpm, la punta junto a la cara y el avance
  automático cilindrando a 0,20 mm/vuelta (transversal 0,100); el tramo cilindrado se ve en la media sección, y en
  teléfono el mando manual entero (cabezal, avance, manivelas, herramienta, material, taladrina y medir).
- **Dentro del programa** (`app/main.tscn` de la unidad 12 con `--section=taller`): el titular «¿Cómo se corta el
  metal?» y el botón Fundamentos en la barra, y el fondo de `main.gd` detrás de la sección.
- **Sonido** (`f.wav` frente al registro por fotograma de la demo): torno cortando −22,1 dBFS frente a girando en
  vacío −25,2 dBFS (**+3,1 dB**; en el tramo a ×5, +2,3 dB: el vacío es a ~1.900 rpm con G96 y el paso de garras
  crece con el giro); torno parado −50 dBFS; radial −13,0 dBFS; afiladora −26,1 dBFS; pico 0,966 (sin saturar).

## Pendientes

- **Tema común.** Unificar `style.gd` con `app/theme/app_theme.gd` y las piezas de `app/common/` (ver «Para el
  coordinador»).
- **Torreta editable.** Un programa editado usa la torreta del ejemplo del que parte. Una T que no está en ella deja
  montada la herramienta anterior (el torno solo lo avisa en la consola, ver abajo).
- **Correctores de avance y de giro** (los % del panel del Fagor): el torno no los tiene todavía.
- **Otros discos de radial** (`corte_alu`, `corte_sic`, `corte_ceramico`, `diamante_turbo`…): hay datos en
  `abrasives.gd` pero no aspecto en la escena 3D.
- **Fresadora y taladro** sin ficha de máquina: las calculadoras no avisan de sobrecarga en ellos.
- **La plaquita de la escena 3D** es siempre la CNMG 120408 (la vista 2D sí dibuja la del catálogo).
- **Guardar la máquina elegida** en `user://ajustes.cfg` (sección `[taller]`), como hace el programa con la sección.
- **Colores de revenido en la cara del acero desnudo** de las piezas de rescate: el shader de la chapa solo los
  pinta donde la pintura se ha quemado (no se ha tocado `corte_chapa.gdshader`, de la unidad 14).
- **Rendimiento del torno 3D en teléfono:** apagar el MSAA 4× y las sombras de la escena en móvil.

## Para el coordinador

1. **Tema.** La sección aplica un tema local (`style.gd`, variantes `Taller*`) y dentro del programa manda sobre el
   global. Para unificar: definir en `app_theme.gd` las variantes equivalentes (TallerTitulo → H1, TallerTarjeta →
   CardTitle, TallerTarjetaPanel → Card, TallerFicha → la ficha de `app/common/`…) y quitar `theme = Style.theme()`
   de `taller_section.gd`. No lo he hecho porque la unidad 12 llegó con mis controles ya hechos.
2. **Fondo.** La sección no pinta fondo propio: dentro de `main.gd` se ve el suyo, como en el laboratorio.
3. **Sonido.** El interruptor general es el de la barra (bus Master); la sección no tiene otro.
4. **Herramienta desconocida en el torno** (`core/taller/lathe.gd`, `_resolve_tool` y el cambio de herramienta): si
   el programa pide una T que no está en la torreta, `set_tool` falla, sale un `push_warning` en la consola y sigue la
   herramienta montada, sin alarma. Caso: en la pieza A, cambiar `N130 T3 D3` por `N130 T5 D5`; el acabado se hace con la
   plaquita de desbaste (CNMG 120408) y la interfaz no puede avisar. Propongo una alarma que no detenga
   (`TOOL_UNKNOWN`) en `Lathe.ALARMS`.
5. **Rango de un `Range` fuera del árbol.** En Godot 4.7.2 cambiar `value` sin estar en el árbol no emite
   `value_changed`; los tests de interfaz de otras unidades que arrastren deslizadores tienen que emitirla a mano.
6. **No he vuelto a fusionar** la rama del coordinador después de `bfbb57f`: lo siguiente (1.x 1.0.1) cambia
   `packages/core/src/lab.js` y el oráculo, y el encargo pide el oráculo de la base intacto.
7. **Rótulos de la radial con coma decimal.** He cambiado a coma los números de los rótulos de las vistas a escala de
   `radial_3d.gd` (`_es`), como el resto de la interfaz; los del disco (su marcado) siguen como el fabricante.
