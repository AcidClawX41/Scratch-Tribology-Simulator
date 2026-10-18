# Contratos del proyecto Godot (V2 · prototipo)

Tribology Simulator & Industrial Workshop 2.0 (antes Scratch Tribology Simulator; `core/shared/app_info.gd`) es **un
solo programa** con dos secciones: **Tribología biológica** (uñas,
garras y colmillos, el laboratorio de la 1.x) y **Taller industrial** (mecanizado, torno, radial y afiladora).
Las dos comparten la capa física de `core/shared/`; cada sección añade sus propios modelos. Este documento
fija lo que las unidades de trabajo se prometen entre sí, para que cada una pueda hacerse sin esperar a las
demás.

## Estructura y reglas

```text
godot/
├── core/            física, datos y dibujo · sin nodos de escena · determinista · probado sin ventana
│   ├── shared/      capa compartida por las dos secciones: js.gd, rng.gd, contact.gd, abrasion.gd (y formatos)
│   ├── lab/         Tribología biológica: port 1:1 del motor 1.x (packages/core)
│   └── taller/      Taller industrial: corte, torno, Fagor, plano, abrasivos, radial, afiladora, malla, sonido
├── app/             escenas e interfaz (Control, Node3D): tema, selector de sección, laboratorio, taller
├── assets/          fuentes (OFL), sonidos del laboratorio (22 WAV de la 1.x), bucles del taller, icono
├── tests/           ejecutor propio (run_tests.gd + case.gd) · tests/<área>/test_*.gd · fixtures/ (oráculo)
└── tools/           godot.mjs (import · test · capture · run), horneado de sonidos
```

- **Idioma:** textos visibles y documentación en español de España; nombres de variables y funciones en inglés.
- **GDScript tipado.** En `core/` no hay `class_name`: los módulos se importan con
  `const X = preload("res://core/…/x.gd")` y exponen funciones `static` o clases `RefCounted`. Así no chocan
  nombres globales entre unidades.
- **Determinismo en `core/`:** nada de `randf()`, `randi()`, `Time` ni `OS` en los cálculos. El azar sale de
  `core/shared/rng.gd` (mulberry32 con semilla, el mismo de art.js).
- **Números como JavaScript:** textos y SVG usan `core/shared/js.gd` (`to_fixed`, `js_round`, `js_num_str`),
  nunca `str()`, `round()` ni `"%.1f" % x`. El lector de números de Godot (`String.to_float`, `JSON.parse`) no
  redondea bien los decimales largos; los literales cortos del código sí son exactos.
- **Datos con fuente:** cada entrada de catálogo lleva `source` (texto de la cita) y
  `quality: "primary" | "secondary" | "estimate"`. Sin medición publicada no se inventa: se marca `estimate`.
  - **Ficción (desde la 4i-B2):** lo que es de película, y solo eso, lleva `quality: "ficcion"`, que se lee
    «ficción (película)». Nunca se presenta como dato. Su `source` dice qué haría el animal de verdad, y la interfaz lo
    pinta aparte. Hoy solo la usa el velocirraptor de cine (`core/lab/velociraptor_film.gd`), en su propio grupo del
    catálogo: una reconstrucción no lleva ficción dentro.
- **Catálogos: se comparan por valor o por id, nunca con `is_same()`.** GDScript pliega `Data.GEOMS[3]` en una
  copia al compilar otro script: el valor es igual, pero no es el mismo objeto.
- **Unidades:** fuerza N · presión y dureza MPa (HV como etiqueta; 1 HV = 9,807 MPa) · longitud mm · profundidad
  µm · velocidad de corte m/min · velocidad periférica m/s · giro rpm · avance mm/rev o mm/min · potencia kW ·
  par N·m · temperatura °C · tiempo s (vida de herramienta en min) · masa kg · densidad kg/m³.
- **Sin red en tiempo de ejecución.** Sin telemetría. Fuentes y sonidos empaquetados.

## Capa física compartida (ya hecha y probada contra el motor 1.x)

| Módulo | Qué ofrece |
|---|---|
| `core/shared/js.gd` | `to_fixed`, `js_round`, `js_num_str`, `log10`, `log1p`, `cbrt`, `imul32`, `u32`, `ushr`, `hex2`: los números como JavaScript, al bit · `truthy` (`!!v`), `is_true` (`v === true`), `template_str` (`${v}`) |
| `core/shared/theme.gd` | `C`: la paleta glam-lab (theme.js), la única del programa. La interfaz la convierte en `Color` con `app/theme/palette.gd` |
| `core/shared/rng.gd` | mulberry32 y `seed_of` de art.js: `Rng.new(Rng.seed_of("texto"))`, luego `.next()`; o `Rng.from_text("texto")` |
| `core/shared/contact.gd` | `HV_MPA`, `CONTACT` (rOff, rFull, tabor, yieldOnset, nu), `clamp_js`, `smoothstep`, `tip_geometry`, `contact_radius`, `hole_radius`, `depth_for_radius`, `hardness_efficiency`, `plastic_fraction`, `solve_static`, `solve_layered`, `work_between`, `absorbed_work`, `solve_energy`, `H_MAX` |
| `core/shared/abrasion.gd` | `abrasion_mode(Dp)` → `{ absMode, fab, muPlough }` (Hokkirigawa–Kato, idéntico al de solidResult), `archard_wear(F, L, H, k)`, `DP_WEDGE`, `DP_CUT` |

- El laboratorio (port de physics.js) y el taller (grano abrasivo de la radial y de la afiladora, desgaste) **usan
  estos módulos**: no se copian sus fórmulas.
- Lo que sea propio de cada sección vive en `core/lab/` o `core/taller/`.

## El motor 1.x es el oráculo

`packages/core` (JavaScript) queda congelado. `npm run godot:fixtures` exporta a `tests/fixtures/`:

| Archivo | Contenido | Números |
|---|---|---|
| `lab-data.json` | catálogos de data.js, lab.js, art.js y sfx.js, y derivados (`carLayers`, `targetSub`, `clawTitle`, `maxForceHint`, `nailSwatch`) | decimales |
| `lab-golden.json` | los 40 escenarios del golden: parámetros (ids), `result` completo de `compute()`, `sfx`, `toolLabel`, `damage`, `damageStage`, `badgesAfter` | decimales |
| `generated/lab-sample.json` | ~20.000 ensayos del barrido de `audit.js` (uno de cada 31), `clawSpecs`, `resolved` (resolveTool) y `duels` | decimales |
| `generated/art-svg.json` | 372 dibujos: `fn`, `args` (ids y, si hace falta, el `res`), `viewBox`, `svg` canónico y `data` (tip, labels…) | **exactos** |
| `js-semantics.json`, `rng.json`, `shared.json` | toFixed, Math.round, String(n), log10…, mulberry32, seedOf; vectores de la capa compartida | **exactos** |
| `sfx.json` | ids de los 22 efectos y sha256 de sus WAV | — |

**El oráculo está versionado entero** (también `generated/` y su sello `.stamp`), tal como lo da el motor 1.x con
**Node 22**: su V8 12.4 es el que porta `core/shared/v8_math.gd` al bit. Así los tests dan lo mismo con cualquier Node
instalado (en GitHub, el de `.nvmrc`). Con el V8 de Node 24, cuatro `pow()` difieren en el último bit (y algún último
decimal de otros archivos): por eso `godot-ci` no había pasado nunca, mientras el oráculo se regeneraba en cada máquina.
`godot.mjs` solo lo regenera si cambia `packages/core/src` o el exportador, y entonces exige Node 22.

- Los números **exactos** van como `{ "$f64": "<8 bytes little-endian en hex>" }`. `case.gd` → `decode()` los
  convierte al double exacto.
- Los números no finitos van como `{ "$num": "NaN" | "Infinity" | "-Infinity" }`.
- `undefined` en JS equivale a una clave ausente o a `null` en GDScript.
- **Política de comparación** (`case.gd` → `oracle_diff`): textos y booleanos idénticos, números con error
  relativo ≤ 1e-9, 0 discrepancias de veredicto, capa y sonido.
- **SVG canónico** (`packages/core/scripts/lib/scene-svg.mjs`):
  - `<svg xmlns="http://www.w3.org/2000/svg" width="W" height="H" viewBox="…">`, luego `<defs>…</defs>` si hay
    defs, y después body, lines y extras, en ese orden;
  - atributos en orden de inserción, sin `key` ni valores null o false;
  - estos pasan a kebab-case: clipPath, clipRule, dominantBaseline, fillOpacity, fillRule, fontFamily, fontSize,
    fontWeight, letterSpacing, stopColor, stopOpacity, strokeDasharray, strokeDashoffset, strokeLinecap,
    strokeLinejoin, strokeMiterlimit, strokeOpacity, strokeWidth, textAnchor;
  - valores con `String(n)` de JS; texto escapado `& < > "`;
  - nodos sin hijos como `<tag …/>`.
- **Catálogos de datos del laboratorio.** Son diccionarios con **las mismas claves y valores** que los objetos de
  data.js; las funciones de art y physics los reciben así.

## Taller: contratos entre unidades

- **Coordenadas del torno.**
  - Los programas usan X en **diámetro**; dentro, `r = X/2`.
  - `Z+` va hacia el contrapunto, con `Z = 0` en la cara acabada: la pieza está en `Z < 0`, hacia el plato.
  - El centro del radio de punta es la punta teórica más `(rε, rε)` en la herramienta exterior estándar; otras
    orientaciones, en la fase 2.
- **Perfil de la pieza** (lo publica el torno, lo leen la malla 3D, la vista 2D y la inspección):
  ```gdscript
  { "z0": float,                     # z del primer anillo (mm)
    "dz": float,                     # paso de la rejilla (mm), 0.02 por defecto
    "r": PackedFloat64Array,         # radio exterior de cada anillo (mm)
    "ring_ra": PackedFloat32Array,   # Ra real de cada anillo (µm), medido en las crestas simuladas
    "ring_pass": PackedByteArray,    # 0 bruto · 1 desbaste · 2 acabado · 3 pulido
    "dirty": Vector2i }              # [primero, último] anillos cambiados desde la última lectura (−1 si ninguno)
  ```
- **Movimiento (IR):** lo produce el intérprete Fagor y lo consume el torno.
  ```gdscript
  { "n": int, "line": int,
    "type": "rapid" | "feed" | "arc" | "dwell" | "tool" | "spindle" | "coolant" | "end",
    "from": { "r": float, "z": float }, "to": { "r": float, "z": float },
    "arc": { "cw": bool, "center": { "r": float, "z": float } },            # solo en arc
    "feed": { "mode": "mmrev" | "mmmin", "value": float },                  # feed y arc
    "spindle": { "dir": "cw" | "ccw" | "stop", "rpm": float, "css": { "vc": float, "rpm_max": float } },
    "tool": { "id": String, "offset": int }, "coolant": bool, "dwell_s": float }
  ```
  Coordenadas absolutas en mm, con r en radio; `n` es el número de bloque que citan las alarmas.
  - `tool.id` es «T» más el número (`"T1"`); `offset` es el corrector D, o el número de herramienta si no hay
    tabla de herramientas.
  - Con G96, `spindle.rpm` es el giro en el punto donde se emite el movimiento: el torno lo recalcula en cada paso
    con `css` (n = 1000·vc/(π·D), limitado por `rpm_max`, el G92 S).
  - Opcional: `"pass": int` con los códigos de `ring_pass` (1 desbaste · 2 acabado) en los movimientos de los
    ciclos. Si falta, el torno deduce la pasada del avance y de la herramienta.
- **Dialecto Fagor 8055 T** (`core/taller/gcode*.gd`, manual de programación Ref. 1110):
  - G68/G69 (desbaste en X y en Z) llevan **letras**: `G68 X Z C D L M K F H S E Q`, con el perfil entre los
    bloques S y E. La forma con parámetros `P0…P14` es del Fagor 8025/8030; en el 8055 T da un error que lo
    explica.
  - G70/G71 son pulgadas/milímetros (no ciclos, como en Fanuc); G92 S limita las rpm con G96.
- **Modelo de corte inyectado** en el torno:
  `Callable(work_id: String, tool_id: String, h_mm: float, b_mm: float, vc: float) -> { "kc": float, "fc_n": float, "ok": bool, "reason"?: String }`.
  - Lo implementa la unidad de corte: `Cutting.model_callable()` (`core/taller/cutting.gd`).
  - `work_id` es el id del catálogo de materiales (`work_materials.gd`: `c45e`, `al6082_t6`…) y `tool_id` el material
    de la herramienta (`tool_materials.gd`: `hm_coated`…). Cada plaquita del torno lleva su `tool_material`; el
    torno lo pasa al modelo.
  - Sin datos de fuerza (madera, plásticos, vidrio…) el modelo devuelve `ok = false` y `reason`: el torno corta la
    geometría, pero `state()` lo dice en `cut_ok` y `cut_reason` y la interfaz lo enseña en vez de dar una potencia
    falsa.
  - En los tests del torno basta con Kienzle y una tabla pequeña.
  - La potencia del torno es **Pc = kc·ΔV/Δt**, con el volumen realmente arrancado en cada paso.
- **Arcos:** `arc.cw` es horario visto con Z hacia la derecha y X hacia arriba (la vista del plano, torreta trasera):
  en G02 el ángulo baja. Un R cóncavo en un hombro hacia el plato es G02.
- **Perfil en rejilla:** el anillo i está en `z = z0 + i·dz` (muestra puntual). Los anillos con `r = 0` son material
  quitado: la vista 2D no los dibuja.
- **Profundidad de pasada:** la `ap_max` de la plaquita es para un corte sostenido. Dos vueltas seguidas por encima
  rompen la plaquita (`AP_EXCEEDED`, detiene); una sola vuelta es la llegada a un hombro con su creces (`AP_PEAK`,
  aviso). Solo cuentan las vueltas completas.
- **Torreta de cada programa:** `EXAMPLE_PROGRAMS[id].turret` (`{ "1": id de lathe_tools.gd, … }`) se carga con
  `Lathe.set_tool_table()`.
- **Pose de la herramienta para la escena 3D:** el torno da `state().tip` (`{ r, z }` de la punta teórica, en mm) y
  `re_mm`; la escena la lee con `set_tool_pose(r, z)` o con `set_profile_source(obj)` si `obj` tiene `tool_pose()`.
- **Banda del plano para la capa de desviación:** `Drawing.tolerance_band(plano, z0, dz, n)` →
  `{ z0, dz, r_min, r_max }` (ISO 286 en los cilindros acotados, ISO 2768 en el resto, `NO_PLAN` = −1 fuera de la pieza).
- **Alarma:** `{ "code": String, "n": int, "message": String (en español) }`.
- **Material de pieza:**
  `{ id, name, iso: "P"|"M"|"K"|"N"|"S"|"H"|"O", kind, density, hv, rm, kc: { kc11, mc, gamma0, family } | null, source, quality }`.
  - `kind`: acero · inox · fundicion · aluminio · laton · titanio · niquel · madera · plastico · piedra · vidrio.
- **Entrada de sonido de máquina:**
  `{ process: "lathe"|"mill"|"drill"|"grinder"|"sharpener", rpm, teeth, jaws, pc_kw, pmax_kw, work_kind, chatter: { risk, mode_hz } | null, coolant, tool_pos: Vector3 }`.
  - `Lathe.sound_input().tool_pos` va en mm y en coordenadas de la pieza (`Vector3(z, r, 0)`); `MachineSound.frame()`
    la quiere en metros y en el sistema del nodo de sonido: quien los une la convierte (÷1000 y a los ejes de la escena).
- **Claves de unión** (constantes que todas las unidades usan igual):
  - abrasivos: `al2o3 · sic · cbn · diamante`;
  - grupos ISO 513: `P M K N S H`;
  - aceros de afilado: `vg10 · x50crmov15` (1.4116) `· 14c28n · m2 · 1095`.

## Radial contra chapa de coche (corte de rescate)

Petición de Eric: probar las radiales contra la chapa y la carrocería de los coches, como en los rescates de
bomberos, y ver qué corte sale más limpio o más sucio según el material del disco, las rpm y el ángulo.
- **Paneles** (`core/taller/panels.gd`):
  - los cuatro coches del laboratorio, con los mismos ids, espesores y capas de pintura que data.js: `acero-dulce`,
    `acero-bh`, `aluminio` y `plastico-carroceria`;
  - piezas de rescate: `boro-22mnb5` (pilar B estampado en caliente) y `dp800`.
- **Entrada de `cut_panel`** (`core/taller/radial.gd`):
  `{ disc_id: "fino_1mm"|"grueso_3mm"|"diamante"|"laminas", diameter_mm, rpm, angle_deg (0 = perpendicular a la chapa), feed_mm_s, panel_id, cut_length_mm }`.
- **Salida:**
  `{ vs_ms, over_speed, time_s, kerf_mm, burr_um, haz_mm, heat_tint: { temp_c, color }, paint_burn_mm, sparks: { rate, color, length_mm, bursts }, disc_wear_mm3, disc_loading, deformation, cleanliness (0 limpio … 10 sucio), warnings, quality, sources }`.
- **Escena** (`app/taller/radial_3d.tscn`): consume esa salida con `set_params`, `set_result`, `start_cut`, `set_view`,
  `set_rpm` y `set_angle`. Las chispas salen de `core/taller/sparks.gd`.
- **Añadidos de la unidad 1h** (`docs/taller/pulido-taller.md`):
  - En la salida:
    - `kerf_band_mm`: banda medida del surco, [espesor + 0,3; espesor + 0,8] mm;
    - `specific_energy_band_j_mm3`: la banda de Awan et al. 2022, que no sustituye al modelo;
    - `sparks.class` es ahora la familia de chispas de `sparks.gd`.
  - Una sola fuente para las chispas: `Sparks.stream_for(material_id, vs)` (TC 9-237), la usan `cut_panel` y la escena.
  - Discos nuevos:
    - `metal_duro`;
    - `cbn_1mm`: es para tronzadora fija y siempre da el aviso `disco_fijo`.
  - Desgaste de herramienta (`core/taller/wear.gd`):
    - VB(t) según Equeter 2020 y fin de vida en VB = 0,3 mm (ISO 3685);
    - la vida consumida se acumula;
    - Kver y Ra crecen con VB;
    - para el torno: `Cutting.cutting_model_worn` y `model_callable_worn`.
  - Viruta: `Chips.chip_breaking`, `form_for_cut` y `bue_risk` (filo recrecido).
  - Hilos: la caché de `cutting.gd` pasa a ser una tabla de solo lectura calculada al cargar.
- Es un simulador **educativo, no un procedimiento de rescate**. Avisos con fuente:
  - chispas cerca del combustible y de los generadores de gas de los airbags;
  - pilares de acero al boro;
  - cables naranjas de alta tensión (fichas de rescate ISO 17840).

### Modo manual de la radial (2c, unida)

- **Al abrir la pestaña, la radial está apagada, parada y apartada** 30 mm de la chapa (`on_shown()` → `manual.park()`).
  El corte automático de antes sigue detrás de «Ver demostración» (`set_demo(true)`).
- **Física en core:**
  - `core/taller/radial_manual.gd` (`RadialManual`): la sesión con la amoladora, sin nodos y determinista. Da un
    `frame` por paso: `push_n`, `push_limit_n`, `plunge_cap_mm_s`, `saturated`, `overload`, `power_deficit_kw`, las
    rpm reales y la entrada de sonido `grinder`.
  - `Radial.cut_step(p)`: el modelo de `cut_panel` en el instante presente, con la profundidad a la que entra el disco;
    a profundidad completa da lo mismo que `cut_panel`, al bit. `Radial.cut_capacity(p)`: lo que el disco puede
    arrancar ahora, con `q_power_mm3_s`, `q_push_mm3_s` y `push_power_kw`.
  - El motor sigue el balance de energía del rotor, J·ω·dω/dt = P_disponible − P_pedida, con los datos de la Bosch
    GWS 12-125 CIE. La desconexión por rebote sigue la patente de Bosch. Tabla valor → fuente → tipo en
    `docs/taller/radial-manual.md`.
- **Escena** (`radial_3d.gd`): `set_mode`, `show_frame`, `stats`, `input_geometry`, las señales `gesture_finished` y
  `dial_step_requested`, y `auto_start = false`. Solo pinta el `frame`.
- **Sonido:** la sección pide `pages["radial"].sound_input()`: con la radial apagada, silencio; en la demostración,
  la entrada del estado.
- Los botones y las teclas no fuerzan la radial (`push_limit_n`, `plunge_cap_mm_s`); el ratón sí puede.
- **Pendiente para la física:** a muy poco avance, la fórmula de Adams de fuente móvil da unos 37 mm de pintura quemada
  durante un instante. Falta el tope de fuente fija. Y en la parada por inercia, el zumbido del motor de
  `machine_sound` sigue a las rpm aunque no haya corriente.

## Programa y secciones (`app/main.gd`)

- **Escenas.**
  - Laboratorio: `res://app/lab/lab_section.tscn`.
  - Taller: `res://app/taller/taller_section.tscn`, si existe; si no, un aviso «en construcción».
  - Cada sección se instancia la primera vez que se muestra y ya no se destruye.
- **Raíz.** Un `Control`, a pantalla completa entre la barra superior y el pie.
- **Proceso.** La sección oculta pasa a `PROCESS_MODE_DISABLED`, lo que para su `_process`, su entrada, sus
  animaciones y su sonido; la visible pasa a `PROCESS_MODE_INHERIT`.
- **Opcionales en la raíz** (se llaman si existen):
  - `headline() -> String`: el titular de la barra;
  - `fundamentos() -> Array`, con pares `[título, texto]`, y `fundamentos_note() -> String`, para la hoja
    «Fundamentos». Sin `fundamentos()`, el botón se oculta.
- **Sonido.** El laboratorio suena por el bus «Lab» y el taller por «Maquina» y «MaquinaCorte». El interruptor
  general silencia «Master».
- **Ajustes.** En `user://ajustes.cfg`, sección `[app]`: `section` (`bio` o `taller`) y `sound`. Cada sección guarda
  lo suyo en otras secciones del mismo archivo.
- **Vulkan en la nube (petición 50).** Con `mesa-vulkan-drivers` (lavapipe, Vulkan por software) se compila y se captura
  en Vulkan · Forward+ (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json` y `--rendering-driver vulkan
  --rendering-method forward_plus`). `tools/shader_check.gd` compila todos los sombreadores de `app/` uno a uno: un
  sombreador que no compila en Vulkan no da error en pantalla, Godot pinta el material por defecto (blanco). Pasarlo
  antes de unir cualquier cambio de sombreadores.
- **Nombres en los sombreadores con `#include`.** Una variable local de un `.gdshaderinc` no puede llamarse como un
  uniform de un sombreador que lo incluye: en Vulkan, Godot la traduce como el uniform y el sombreador no compila (en
  OpenGL sí). Fue `cracks` en `claw_material.gdshaderinc` frente a `uniform vec4 cracks[4]` de `keratin.gdshader`.
- **Gráficos (petición 50, solo en escritorio).** El botón «Gráficos» del pie elige el renderizador
  (`app/common/renderer_choice.gd`): se escribe en `user://graficos.cfg`, que `project.godot` lee al arrancar
  (`application/config/project_settings_override`), y el programa se reinicia sin los argumentos que fuerzan otro
  renderizador. Los tests usan su propia ruta y nunca escriben ese archivo.
- **Donaciones (petición 39).**
  - El botón «Dona o invítame», con la taza de `AppTheme.cup_icon()`, va con Fundamentos y Sonido, así que se ve en las
    dos secciones; en el teléfono, en el pie, como «Invítame». Allí la versión y la licencia quedan en «Créditos».
  - Abre la hoja «Dona o invítame a un café» (`show_donate()`, `fill_donate(links)`): la entradilla (la taza y el
    saludo), las secciones de `AppInfo.DONATE_SECTIONS` (la de apoyar primero, con las tarjetas) y una tarjeta por enlace
    (`app/common/donate_card.gd`: el color y el icono propio de cada plataforma; al pasar el ratón o con el foco, se
    ilumina, brilla y crece un poco).
  - Los enlaces y el texto están en `core/shared/app_info.gd` (`DONATE_LINKS` con `detail`, `DONATE_TEXT`,
    `DONATE_SECTIONS`, `DONATE_*`); los que tengan la url vacía no salen (`donate_links()`).
  - La edad de Eric (petición 41) sale de `AUTHOR_BIRTH` y de la fecha del sistema: `AppInfo.age_on(today)` y
    `donate_text(today)`. La fecha la pone la interfaz (`Time.get_date_dict_from_system()`, o `today_override` en los
    tests): `core` no lee el reloj.
- **Secciones en desarrollo (petición 40):** `AppInfo.WIP_SECTIONS` (hoy, el taller) llevan «· WIP» en el selector
  (`_label_sections`; en el teléfono, con el nombre corto) y `AppInfo.WIP_NOTE` en la ayuda emergente y dentro de la
  sección.
  - Cada enlace se abre en el navegador del sistema al pulsarlo (`link_opener`, que por defecto llama a
    `OS.shell_open`; los tests lo cambian). El programa no hace ninguna llamada a la red.
  - Los mismos enlaces dan el botón «Sponsor» del repositorio en GitHub: `.github/FUNDING.yml`.
- **Tema y piezas comunes:**
  - `app/theme/app_theme.gd` es el tema global (paleta única, Syne y Space Mono, foco visible);
  - `app/common/` son las piezas reutilizables por las dos secciones: tarjeta, selector segmentado, píldora, ficha,
    deslizador, métrica, rejillas adaptables, hoja, reproductor de efectos y caché de dibujos.
- **Escala.** `main.gd` fija el tamaño lógico de la ventana al de la pantalla, para que un teléfono no vea el
  escritorio en miniatura.

## Interfaz (oleada 2)

- **Laboratorio.** Reutiliza la interfaz 2D de la 1.x: las mismas tarjetas (herramienta, objetivo, parámetros,
  resultado, modo dual, comparativa, logros y cuaderno), las mismas ilustraciones (el mismo SVG, rasterizado con
  ThorVG), la misma paleta y las mismas fuentes. Se permiten mejoras que no cambien resultados: un diseño adaptable
  y transiciones.
- **Taller.** El mismo lenguaje visual: tarjetas, paleta y tipografías.
- **Enfoque.** Educativo, no un videojuego: vistas de detalle de la herramienta, la pieza y el material, y
  **parámetros de la máquina ajustables** con deslizadores y selectores:
  - torno: rpm o vc, avance, profundidad, herramienta, material y refrigerante;
  - radial: disco, diámetro, rpm, ángulo, avance y chapa;
  - afiladora: ángulo, rpm, abrasivo y húmedo o seco.

## Piezas de ejemplo (programas Fagor ↔ planos)

La **cara del bruto** está en Z+1: los programas refrentan 1 mm hasta Z0. El bruto va de Z+1 hacia el plato, y
la cara de las garras queda en Z+1 − (largo − dentro del plato): Z−59 en A y Z−49 en B.

**A · Eje escalonado.** C45E, bruto Ø50 × 85, con 25 mm dentro del plato.
- Chaflán 1×45° en la cara.
- Ø30 h9 de Z0 a Z−20; Ø40 h9 de Z−20 a Z−40; Ø46 ±0,1 de Z−40 a Z−55.
- Ra 3,2 en general y Ra 1,6 en el Ø40.

**B · Bulón.** Aluminio EN AW-6082 T6, bruto Ø40 × 70, con 20 mm dentro del plato.
- Chaflán 0,5×45°.
- Ø24 h8 de Z0 a Z−15, con un radio R2 cóncavo en el hombro.
- Ø36 js9 de Z−15 a Z−35; cono de Ø36 a Ø38 de Z−35 a Z−45.
- Ra 1,6 en el Ø24.

Tolerancias ISO 286 que usan (tabla IT):

| Cota | Tolerancia |
|---|---|
| h9, de 18 a 30 mm | 0 / −52 µm |
| h9, de 30 a 50 mm | 0 / −62 µm |
| h8, de 18 a 30 mm | 0 / −33 µm |
| js9, de 30 a 50 mm | ±31 µm |

## Fase 2 · Equipo y reglas

Petición de Eric (fase 2): terminar la hoja de ruta, pulir la física del banco de tribología y del taller, añadir
los **aguijones de insectos** (abejas, avispas…, algunos se quedan clavados en la piel) y **aguijones
experimentales** de otros materiales duros para poner a prueba la propia física, buenas animaciones y un
**simulador de afilado** de cuchillos, brocas y fresas con máquinas reales de consumo (Vevor, esmeriladora y
amoladora Einhell…). Educativo y basado en física real: ángulo, rpm, abrasivo adecuado a cada caso, uso y
temperatura para conseguir el mejor resultado.

- **Equipo:** un coordinador y **como mucho 6 agentes a la vez** (Eric, 18-10-2026: «puedes ahora lanzar hasta 6 agentes
  para ir avanzando más rápido el trabajo acumulado»; antes, 4: «más lento, pero más constante»):
  - ingeniero/a físico/a: investiga, fija los datos con fuente, escribe los modelos físicos puros con sus tests y
    los casos de referencia, y revisa la física de los demás;
  - dos ingenieros de software (laboratorio y taller): integran los modelos en el motor, la interfaz, las
    animaciones y el sonido.
- Cada agente trabaja en su rama local `v2/f2-<oleada><letra>-<nombre>`, desde la base que le da el coordinador.
  **No lanza subagentes** (tampoco la skill `code-review`, que lanza varios): hace él mismo una revisión adversarial
  de su diff.
- **Unidades pequeñas, «despacio y con buena letra»** (Eric). Antes de unir cada unidad, el coordinador revisa el
  código, la interfaz (capturas de escritorio y de teléfono) y la física (fuentes, invariantes y casos a mano por
  material), y corrige o anota lo que falle.
- **Física contrastable** (Eric: «realista y contrastable por libros y hechos empíricos, no datos inventados u
  aproximados»):
  - todo número de la física sale de una medición publicada (libro, artículo, norma o ficha técnica) y lleva su
    `source`;
  - si el caso exacto nunca se ha medido (un tigre sobre el techo de un coche), `quality: "estimate"` solo vale con la
    fuente del **caso medido más parecido** y la suposición escrita al lado; si ni eso existe, no se presenta como
    dato: se quita o se enseña como pregunta abierta;
  - lo que es solo dibujo o sonido (grosor de una línea, timbre) se marca «dibujo» y nunca se muestra como física;
  - cada unidad entrega una tabla valor → fuente → tipo (medido, norma, ficha o caso parecido medido).
- **Cerrar, no abrir** (Eric, petición 46: «hay que empezar a acabar el trabajo y darse prisa en tenerlo todo listo;
  menos investigar y más diseñar y picar código»):
  - se usan las fuentes que ya están en el repositorio (`docs/FISICA.md`, `docs/fisica/*.md` y los `source` del código);
  - como mucho, una fuente nueva por dato que falte. Si no aparece enseguida, estimación con el caso medido más parecido
    (la regla de arriba) y se sigue;
  - cada encargo trae su orden de prioridad: lo de abajo que no dé tiempo va a «Pendiente» del informe, sin alargar la
    unidad;
  - un commit cada vez que algo funcione, y el informe en cuanto lo prioritario esté con la batería en verde.
- **Catálogo de máquinas cerrado** (Eric): no se añaden tipos de máquinas ni simuladores nuevos. Se termina lo ya
  propuesto en la hoja de ruta, lo más antiguo primero y por etapas, y se pule lo que existe:
  - control manual de las máquinas, como a mano en un taller;
  - diseños y física fieles a la realidad;
  - catálogos amplios de materiales de corte y de pieza, con fuente.
  Si una unidad necesita algo que no está propuesto, lo sugiere en el informe y no lo hace.
- `CONTRATOS.md` lo edita solo el coordinador; los cambios se piden en el informe final.

### Oleada 1 ampliada: quién toca qué

Eric permitió más agentes y subagentes mientras se renuevan sus límites de uso. Cada archivo tiene un solo dueño
por oleada. Lo que no está en tu fila se lee, pero no se toca; si necesitas un cambio, pídelo en el informe.

| Unidad | Archivos propios (en `godot/` salvo indicación) |
|---|---|
| 1a · Física de aguijones | `core/lab/insects.gd`, `core/lab/sting.gd`, `tests/lab/test_sting.gd`, `tests/lab/test_insects_data.gd`, `tests/fixtures/spec/aguijones.json`, `docs/fisica/aguijones.md` |
| 1b · Física del afilado | `core/taller/{sharpening_machines,grinding,edge_thermal}.gd` y añadidos compatibles en `sharpening_heat.gd`, sus tests, `tests/fixtures/spec/afilado.json`, `docs/taller/afilado-simulador.md` |
| 1c · Infraestructura del laboratorio | `core/lab/{physics,catalog,lab,lab_state}.gd`, `core/shared/*`, `app/lab/*`, `app/common/*`, `app/theme/*`, `app/main.gd`, `tests/case.gd`, `tests/run_tests.gd`, los tests de `tests/lab/` y `tests/app/` que ya existían, `tools/godot.mjs`, `tools/golden_v2.gd`, `package.json`, `godot/README.md`, `THIRD-PARTY-NOTICES.md`, `assets/fonts/` |
| 1d · Fagor fase 2 | `core/taller/{gcode,gcode_cycles,gcode_dialects,gcode_programs,lathe,lathe_tools,drawing,inspection,lathe_mesh,workshop_state}.gd`, `app/taller/ui/{lathe_page,profile_view}.gd`, `app/taller/lathe_3d.*`, `app/taller/lathe3d/*`, `app/taller/acabado.gdshader`, sus tests (incluidos `tests/integration/test_taller_pipeline.gd` y `tests/app/test_taller_ui.gd`), `docs/taller/fagor-fase2.md` |
| 1e · Fresadora y taladro en la interfaz | `app/taller/ui/{mill_page,drill_page}.gd` (nuevos), `app/taller/mill3d/*` (nuevo), `app/taller/taller_section.*`, `core/taller/mill_drill_state.gd` (nuevo, si hace falta), `tests/app/test_mill_drill_ui.gd`, `tests/taller/test_mill_drill_state.gd`, `docs/taller/fresado-taladro.md` |
| 1f · Física: pulido del laboratorio (materiales y fractura) | módulos nuevos en `core/lab/` (p. ej. `fracture.gd`, `bending.gd`, `recovery.gd`, `dent.gd`), sus tests, `tests/fixtures/spec/pulido-materiales.json`, `docs/fisica/pulido-materiales.md` |
| 1g · Física: pulido del laboratorio (biología) | módulos nuevos en `core/lab/` (p. ej. `zones.gd`, `penetration.gd`), sus tests, `tests/fixtures/spec/pulido-biologia.json`, `docs/fisica/pulido-biologia.md` |
| 1h · Física: pulido del taller | `core/taller/{radial,sparks,abrasives,cutting,chips}.gd`, módulos nuevos (p. ej. `wear.gd`), sus tests, `tests/fixtures/spec/pulido-taller.json`, `docs/taller/pulido-taller.md` |
| 1i · Afiladora 3D y sonido | `app/taller/sharpen3d/*` (nuevo), `app/taller/demo_afilado3d.*` (nuevo), `core/taller/machine_sound.gd`, `tools/bake_sounds.gd`, `assets/sfx/taller/*`, `app/taller/machine_sound_player.gd`, `tests/taller/test_machine_sound.gd`, `tests/app/test_sharpen3d.gd` |
| 1j · Mantenimiento de la 1.x | `.github/workflows/release.yml`, `apps/desktop/src-tauri/*`, `apps/desktop/package.json`, `package-lock.json`, `apps/desktop/README.md`, `docs/AUDIO-NATIVO.md` |
| 1k · Física: coche en marcha (aerodinámica, agarre y daño) y revisión de las rapaces | `core/lab/moving_car.gd` y `core/lab/claws_v2.gd` (nuevos), sus tests, `tests/fixtures/spec/coche-en-marcha.json`, `docs/fisica/coche-en-marcha.md` |

- **Correcciones de datos de la 2.0** para garras que ya existen (`claws_v2.gd`): `OVERRIDES` por id de garra, cada
  campo con `{ value, source, quality }`. `Catalog` las aplica solo en el modelo 2.0, y `data.gd` no cambia (el
  oráculo 1.x sigue igual).

- `godot/CONTRATOS.md`, `docs/FISICA.md`, `docs/TALLER.md`, `docs/ROADMAP.md` y `godot/project.godot`: solo el
  coordinador.
- `godot/default_bus_layout.tres`: Godot le añade un `uid` al importar. No lo subas; si aparece en tu `git status`,
  restáuralo con `git checkout`.

### Vista 3D de la afiladora (1i ↔ oleada 2)

La escena 3D (`app/taller/sharpen3d/`) no lee el catálogo directamente: recibe diccionarios de vista. La oleada 2
los construye desde `sharpening_machines.gd` y `sharpening_sim.gd`.

- **`set_machine(view)`:**
  - `kind`: `"banco" | "humeda_lenta" | "amoladora" | "afilabrocas" | "afilafresas"`;
  - `rpm`;
  - `wheels`: `[{ "position": "izquierda" | "derecha" | "piedra" | "cuero" | "disco", "d_mm", "width_mm", "abrasive_id", "grit" }]`;
  - `wet`: bool.
  - `width_mm` puede ser `null`: la escena lee entonces el ancho de cada muela.
- **`set_tool(view)`:**
  - `kind`: `"cuchillo" | "hacha" | "cortacesped" | "broca" | "fresa"`;
  - `length_mm`, `width_mm` o `diameter_mm`, `spine_mm`, `flutes` (opcional);
  - `steel_id`;
  - `quench_pot`: bool, dibuja el baño de enfriamiento.
  - Una herramienta que no va en esa máquina se queda en la mesa, e `info().compatible` vale `false`.
- **`set_state(view)`**, en cada fotograma (se aplica en `advance(delta)`):
  - `angle_deg`: por lado en el cuchillo y el hacha, total en el cortacésped, de punta en la broca e incidencia
    primaria en la fresa;
  - `force_n`, `contact`: bool, `contact_pos` (0–1 a lo largo del filo), `wheel` (qué muela toca);
  - `edge_temp_c`: `PackedFloat32Array` a lo largo del filo, `max_temp_c` y `edge_peak_c` (el pico alcanzado, que
    fija el color de revenido);
  - opcionales: `temp_field` (`{ u_count, d_mm, temps, peaks }`, el campo de temperatura del filo hacia el lomo) y
    `tint_depth_mm`;
  - `sparks`: `{ rate, color, length_mm }` (de `sparks.gd`; solo en seco);
  - `water`: bool, `rpm_actual`, `burr`: 0–1.
- **Vistas:** `set_view("general" | "filo" | "seccion", instant := false)`. La sección va a escala, con el ángulo y
  el ancho del bisel.
- **Otras funciones:**
  - `set_temper_ramp(rows)`: la tabla de colores de revenido del core (`Panels.TEMPER_COLORS`);
  - `set_quality("escritorio" | "movil")`;
  - `info()`: estado de la escena, con `compatible` y `contact`;
  - `contact_point()`: el punto de contacto en 3D, que es el `tool_pos` del sonido.
- **Colores de revenido:** los calcula el core (`edge_thermal.gd`); la escena solo los pinta.
- **Sonido de la afiladora** (`MachineSound.frame()` con `process: "sharpener"`):
  - `machine_kind`: `"banco" | "humeda_lenta" | "afilabrocas" | "afilafresas"`, más `stone_rpm` y `grind_kind`
    cuando la combinada trabaja en su piedra húmeda; en la piedra hay que pasar `vc`;
  - con la amoladora (`process: "grinder"`), `sheet_mm = 0` significa pieza maciza (disco de láminas `"laminas"`);
  - el marco devuelve `machine_kind` y `rub`, y el reproductor tiene la voz `rub` (roce de la piedra). No hace falta
    ningún bus nuevo.
- `app/taller/sharpen3d/demo_sim.gd` es **solo de prueba**: sus temperaturas, rebaba, chispas por segundo y
  profundidad del calor son inventadas. La página del simulador (2b) usa `sharpening_sim.gd`.

### Fresadora y taladro en la interfaz (1e)

- **Estado:** `core/taller/mill_drill_state.gd` (`MillDrillState`, `RefCounted`, sin nodos), el gemelo de
  `WorkshopState` para estas dos máquinas. Todos los números salen de `cutting.gd`; las páginas solo pintan, y los
  tests comparan cada texto con `Cutting`, al bit.
  - Entradas: `set_mill(key, value)`, `set_drill(key, value)`, `set_machine_param(kind, key, value)`,
    `reset_machine(kind)`, `set_running(kind, on)`, `set_anim_speed(kind, x)`, `advance(kind, dt)`.
  - Salidas: `mill_result`, `drill_result`, `mill_engagement()`, `drill_geometry()`, `machine_notes(kind)`,
    `mill_block()` y las señales `changed` y `sweep_ready(kind)`.
  - Barridos en `WorkerThreadPool`: 1 hilo da lo mismo que N, y el barrido se alarga hasta el ensayo actual.
  - Máquinas de ficha: Lagun FTV 2 (fresadora) y ERLO TSAR-32 (taladro de columna), ajustables.
- **Vistas 3D:** `mill_3d_view()` y `drill_3d_view()` alimentan `app/taller/mill3d/`, que reutiliza sin tocarlos
  varios archivos de `lathe3d/`.
- **Sonido:** `mill_sound_input(load)` y `drill_sound_input(load)` dan la entrada de `MachineSound.frame()` con
  `teeth`, `vc` y `diameter_mm` (paso de dientes z·n/60).
- **Interfaz:** las páginas están en `taller_section.gd` → `md_pages` (`"fresadora"`, `"taladro"`), aparte de `pages`,
  porque `WorkshopState.MACHINES` no tiene estas dos máquinas. Solo avanza y suena la máquina visible.
- **Pendiente:**
  - `Cutting.milling` debería dar `phi_in`/`phi_out` (hoy salen de zc: Δφ = 2π·zc/z);
  - `Cutting.drilling` debería dar `b_mm` y `tip_mm`;
  - el desgaste (`wear.gd`) y el filo recrecido (`Chips.bue_risk`) de 1h aún no se usan aquí.

## Laboratorio 2.0: física con versión

- **`Physics.compute(p)`** acepta `p.model`: `"2.0"` (por defecto) o `"1.x"`.
  - `"1.x"` reproduce el motor 1.x al bit. Lo usan los tests del oráculo: `test_oracle`, `test_art`, `test_sfx`,
    `test_lab_state` e `integration/test_lab_pipeline`.
  - `"2.0"` es la física de la aplicación: igual que la 1.x salvo los cambios de «Cambios de la 2.0» en
    `docs/FISICA.md`, cada uno con su fuente y su test.
  - Los cambios de la 2.0 van en ramas localizadas (`if v2:`). El camino 1.x no se toca.
- **Estado.** `LabState.model := "2.0"`. Toda llamada de la aplicación a `compute()`, `Lab.duel()` o la comparativa
  usa ese modelo.
- **Golden 2.0.** `tests/fixtures/lab-golden-v2.json` guarda las salidas del modelo 2.0 para los 40 escenarios del
  golden 1.x y para los escenarios nuevos.
  - Se regenera solo a propósito, con `npm run godot:golden`.
  - Cada diferencia con la 1.x se explica en FISICA.md.
- **Catálogo 2.0.** `core/lab/catalog.gd` junta los catálogos 1.x de `data.gd` con los añadidos de la 2.0
  (aguijones, zonas del cuerpo, objetivos nuevos…).
  - La interfaz y `LabState` leen `Catalog`, no `Data`.
  - `data.gd` sigue siendo el port exacto de data.js, porque lo comparan los tests del oráculo.
- **Escala de fuerza por herramienta.** `Lab.force_range(tool, inlay = null) -> { min, max, default, unit: "N" | "mN", log: true }`.
  - Siempre en N; `unit` solo decide cómo se muestra.
  - 1.x: de 0,5 a 2000 N. Aguijones: en mN.
- **API hecha en la unidad 1c.**
  - Física:
    - `Physics.model_of(p)` y `Physics.is_v2(p)`;
    - dentro, las ramas son `if c.v2:`.
  - La interfaz calcula **solo a través de `LabState`**, y un test lo vigila: `lab.compute()`, `lab.duel()`,
    `lab.tool()`, `pass_factor` y `tear_lever`.
  - Catálogo:
    - `Catalog.PARTS`, `find_by_id`, `list` e `is_v2`;
    - las listas `V2_*` (`V2_CLAWS`, `V2_CLAW_GROUPS`…) reciben los añadidos de la 2.0.
  - Fuerza:
    - `LabState.force_range()`;
    - `Format.f_to_t_in` y `t_to_f_in`, con el rango como parámetro;
    - `Format.fmt_mn` y `fmt_force`.
  - Ajustes: en `[lab]` se guardan `badges`, `notebook`, `count` y `haptics`. `main.gd` fija `settings_path` antes de
    mostrar la sección.
  - Reglas:
    - `core/lab` y `core/shared` no tienen `static var` mutables (lo vigila `tests/lab/test_threads.gd`);
    - `v8_math.gd` incluye también `exp`, y la física no llama a la libm (hay un test).
  - Trampa de GDScript: una propiedad de una constante de otro script (p. ej. `AppTheme.MONO.fallbacks`) se pliega al
    compilar y se lee vieja; hay que leerla a través de una variable.
- **Materiales de la 2.0 (4a, unida):** grietas de Hertz, rotura de uñas por flexión, recuperación elástica,
  abolladura, ventanilla templada y parabrisas laminado. Guía y datos en `docs/fisica/pulido-materiales.md` §7.
  - `Physics.V2_FIELDS` (`fracture`, `nail`, `recovery`, `residualDepthUm`, `dent`, `glazing`, `tipChip`) existe en
    todo resultado: `null` en la 1.x (también en los de `StingLab`); en la 2.0, `residualDepthUm` nunca es `null`.
  - `Physics.attack_deg(p)` es la única fuente del ángulo de ataque (45° por defecto). La física 2.0 de biología lo
    conecta con `attack.gd`.
  - `Physics.materials_fields` y `Physics.fmt_mm` son la API que usan los demás módulos.
  - `toolBroken` es verdadero si y solo si el veredicto es de la uña («SE DOBLA LA UÑA»…).
  - `Catalog.V2_TARGETS` añade `ventanilla` (templada) y `parabrisas` (laminado).
  - `Lab.FUNDAMENTOS_V2`; `damage_stage` pone la abolladura visible en la etapa 2; `damage_report` gana trozos,
    telaraña, abolladura, huella residual y reparto de la energía.
  - El sonido de un resultado lo decide `SfxInsects.sfx_for_result`: la uña que se dobla suena a pandeo y los
    vidrios de coche, a vidrio.
  - `test_model` compara «igual salvo mecanismo de la 2.0» con `GOLDEN_CHANGED`: de los 19 249 ensayos de la muestra
    cambian 5858, todos explicados. El golden 2.0 tiene 58 escenarios, y 17 de los de la 1.x cambian (8 de veredicto
    o profundidad y 9 solo de subtítulo).
  - Pendiente, de la parte de dibujos: Hertz, astillado, trozos del templado, telaraña del laminado, hoyuelo de la
    abolladura, uña que se dobla en el banco y surco residual; aspecto de vidrio para los vidrios de coche; logros 🔨
    y 💅 (subconjunto de emoji).
- **Biología de la 2.0 (4b, unida):** cinco zonas del cuerpo, hueso, roce en los flancos, ángulo de ataque y esmalte
  del colmillo. Guía y datos en `docs/fisica/pulido-biologia.md` §9 (con §9.10, las decisiones).
  - Parámetros: `p.zone` (brazo por defecto, palma, dorso de la mano, pómulo, abdomen) y `p.attack_deg` (10-170°;
    sin él, el de su tipo: uñas 45°, garras y colmillos 90°). `Physics.attack_deg(p)` sigue siendo la única fuente
    del ángulo.
  - `V2_FIELDS` gana `zone`, `pen`, `tipHv`, `DpEff`, `faceDeg` y `attackDeg` (null en la 1.x). Las punciones de la
    piel dan además `workJ` y `toolBroken`.
  - `Penetration.puncture`: `yieldN`, `yielded`, `demandN` y `stoppedBy` («cede» cuando la uña cede al golpear).
  - `Catalog.CLAWS` es una `static var` (aplica `ClawsV2.apply` en la 2.0): se compara por id, nunca por identidad.
    Las tablas de las zonas son de solo lectura; sus funciones públicas devuelven copias.
  - `LabState`: `zone`, `attack_deg`, `set_zone`, `set_attack_deg`, `attack()`, `attack_default()` y `zone_info()`.
    `SkinTable.set_zone`.
  - La uña con gema mojada: la placa de queratina flexa con ×0,2 (Farran 2009) y la gema no se ablanda.
  - Invariante corregida: tumbar la uña (de 90° hasta unos 27°, atan μ) la dobla antes; lo que nunca pasa es que,
    tumbada, aguante más carga, hunda más o corte más con la misma carga.
  - Pendiente, de la parte de dibujos: el corte de la piel por zona (`Zones.section_layers(res.zone)`, con el brazo
    de la 1.x idéntico), la herramienta inclinada según `attackDeg`/`faceDeg`, el casquete de esmalte, la punta que
    topa con el hueso y los logros de §9.7.

- **Velocirraptor, afilado y patada del casuario (4i, unida):** el tramo del banco de la fase B. Guía en
  `docs/fisica/velociraptor.md` §10.
  - **Catálogo:**
    - `Catalog.V2_CLAWS` lleva los aguijones y el velocirraptor (`Velociraptor.ENTRY`);
    - `V2_CLAW_GROUPS` lleva el grupo «Dinosaurios (reconstrucción)»;
    - los añadidos de la 2.0 a `CLAWS` ya no son solo aguijones: el velocirraptor va en N, como las garras.
  - **Ficha:** `core/lab/dino_lab.gd` (`DinoLab.spec_rows`). `Lab.max_force_hint` da el agarre de un pie (381,5 N) y, en
    la nota, la garra sola (~10 N) y la réplica (483 N).
  - **Afilado:**
    - parámetro `p.sharpness` (0-1), solo con una garra o un colmillo reforjados (`Physics.sharpenable`);
    - funciones `Physics.sharpness_of` y `sharpness_report`;
    - `V2_FIELDS` gana `sharpness` (null en la 1.x y sin incrustación). Con s = 0, el ensayo es el de siempre, al bit;
    - `LabState` gana `sharpness`, `set_sharpness`, `sharpenable()`, `sharpness_report()` y `sharpness_view()`, más el
      espía `_core_sharpness` de los tests.
  - **Dibujo:** `core/lab/art_dino.gd` y `app/lab/dino_views.gd`. En `core/shared`, `Format.fmt_small_force` escribe en
    mN o µN las fuerzas de una punta afilada.
  - **Patada del casuario:**
    - `ClawsV2.OVERRIDES` es una `static var` de solo lectura, calculada al cargar (`_FIXED` y `kick_override`);
    - la precarga `ClawsV2` ↔ `MovingCar` es cíclica a propósito y funciona en 4.7.2;
    - el golpe sale de `MovingCar.kick_leap_ms()` con la masa de la pata: 91,45 J, banda 351,4 J.
  - **Golden 2.0:** 74 escenarios, y cambian 24 de los de la 1.x. En la 2.0, el logro «¡Aquí está Johnny!»
    (`resplandor`) solo llega con fuerza alta: con la de su ficha, el casuario ya no atraviesa la puerta de roble.
  - **Demo:** los casos 23 y 24 de `demo_lab.gd` usan `lab.tool_card` y `lab.scroll_to`. Tenlo en cuenta al separar el
    laboratorio en páginas.
  - **Lo que quedó abierto para la 4i-B2:**
    - resuelto: la masa del casuario (58 kg en los dos), la resistencia del cuarzo (un solo valor) y el coche en marcha
      ya lee `sharpness`;
    - sigue abierto: el banco patea con la masa de la pata y sin tope, y el coche con el animal entero y un tope de
      5,1 pesos (ver la 4i-B2).

- **Velocirraptor de cine y coherencia banco ↔ coche (4i-B2, unida).** Guía en `docs/fisica/velociraptor.md` §10.7 y
  §11.
  - **El de cine (FICCIÓN):** `core/lab/velociraptor_film.gd` (`VelociraptorFilm`).
    - Entrada `ENTRY` (id `velociraptor_pelicula`, nombre visible «Velocirraptor de cine»: los nombres del catálogo no
      pasan de 18 letras por la comparativa del teléfono) en el grupo `GROUP`, «Dinosaurios de película (ficción)»;
      `Catalog.V2_CLAWS` y `V2_CLAW_GROUPS` la llevan detrás de la reconstrucción.
    - Lo que puede ser real es de *Deinonychus*, en el que se basó la película: tamaño, masa por el fémur (99,8 kg), la
      garra de Ostrom (120 mm), el agarre, la carrera y el salto, cada uno con su calidad.
    - Solo es ficción la garra (`quality: "ficcion"`): corta como la tachuela de acero del banco (200 HV, 200 GPa).
    - Funciones: `is_film(tool)`, `entries()` y `femur_mass_kg()`. `DinoLab` lo pinta aparte (`is_film`, su ficha y su
      línea de fuentes).
  - **Coherencia banco ↔ coche:**
    - el casuario pesa 58 kg en los dos: `ClawsV2.casuario_mass()` lee la hembra de `MovingCar.BODIES` (Grzimek 2003)
      y `OVERRIDES.casuario` gana `mass`; `data.gd` no cambia;
    - el cuarzo tiene una sola resistencia: `Fracture.TOOL_STRENGTH.cuarzo` lee `ClawFracture.BRITTLE.cuarzo`
      (52,4 MPa, Corning HPFS 7980);
    - `Velociraptor.leap_speed_ms` y sus constantes del salto leen `MovingCar.KICK` (no se copian). `velociraptor.gd`
      precarga `moving_car.gd`; `moving_car.gd` no precarga ninguno de los dos velocirraptores.
  - **En `core/shared`:** `Format.fmt_tip_um` (el radio de una punta, de µm a nm; `DinoLab.fmt_tip_um` lo llama).
    `ClawFracture._fmt_n` escribe mN por debajo de 0,05 N, en vez de «0.0 N».
  - **Golden 2.0:** 76 escenarios. Dos nuevos de ficción; tres del casuario cambian por los 58 kg, sin cambiar ningún
    veredicto.
  - **Sigue abierto:** el tope de la patada en el banco. Son dos estimaciones de la misma patada con rigideces
    distintas, y aplicar los 5,1 pesos haría que la daga de tungsteno ya no atravesara el húmero.

## Aguijones (insectos)

- **`core/lab/insects.gd`:** `GROUP := "Insectos"` y `STINGERS := [...]`. Cada entrada lleva:
  - todas las claves de una garra de `Data.CLAWS` (`id`, `group`, `name`, `hv`, `mohs`, `E`, `area`, `alpha`, `reach`,
    `curve`, `mass`, `force`, `strike { v, m }`, `col`, `desc`…), para que `resolve_tool`, el banco y la interfaz la
    traten como una garra;
  - `stinger`: los datos propios, cada uno con su fuente o marcado como estimación:
    - longitud, diámetro de la base y radio de la punta;
    - púas;
    - autotomía;
    - gradiente de dureza de la punta;
    - ángulo de inserción;
    - índice de Schmidt;
    - veneno y bombeo;
    - frecuencia del aleteo, para el zumbido;
  - `source` y `quality`.
- **Aguijones experimentales.** Se «reforjan» con el mismo mecanismo que las garras (`inlay`): el material cambia la
  dureza y el módulo, no la geometría. Lo nuevo es la física que lo pone a prueba: pandeo (Euler), embotamiento de la
  punta y anclaje de las púas.
- **`core/lab/sting.gd`:** las funciones físicas puras de los aguijones: inserción en mN, anclaje de las púas y
  fuerza de extracción, autotomía, pandeo y giro helicoidal. Las usa `physics.gd` en el modelo 2.0.
- **Unidades.** Fuerza en N por dentro (la abeja, ~0,004 N); la interfaz la muestra en mN, y la masa en mg.
- **Aclaraciones de la unidad 1a** (terminada; especificación en `docs/fisica/aguijones.md`):
  - `fBreak` de un aguijón es su **carga de pandeo**, no de rotura. Se recalcula también cuando está reforjado.
  - Cada dato de `stinger` es `{ value, source, quality }`; `Sting.sval(st, clave)` lee el valor.
  - `result.sting` (modelo 2.0) lleva los campos de la tabla §7.3 de la especificación. `Sting.sting_report(p)` es
    la referencia que tiene que reproducir la integración.
  - Los sólidos se resuelven con `Sting.solid_params(p)` y el camino de siempre: la dureza a la escala de la punta;
    en la madera, la de la pared celular.
  - `Sting.puncture_force(area_mm2, capas)` es la **ley de perforación de la piel del modelo 2.0 para todas las
    herramientas**. Para uñas, garras y colmillos da lo mismo que la 1.x.
  - En `resolve_tool`, un aguijón:
    - no es queratina: «húmeda» no lo ablanda;
    - su radio de base es su diámetro / 2 (no la regla de las garras);
    - inyecta, pero sin el texto de las dos punciones de los colmillos.
  - Interfaz: sin rayado ni desgarro para los insectos. «Se dobla el aguijón» con la carga en mN, en lugar de «se
    rompe la punta».
  - Escala de fuerza: de 0,01 a 1000 mN para un aguijón natural y hasta 5000 mN para uno reforjado (la abeja de
    diamante pandea a 3,8 N).
  - Objetivo opcional «Cutícula de insecto» (`Sting.CUTICLE`): enseña que la abeja no se queda clavada en otro
    insecto.
- **Integración en el banco (unidad 2a, unida):**
  - `core/lab/sting_lab.gd` (`StingLab`): con un aguijón y el modelo 2.0, `Physics.compute()` le pasa el ensayo; el
    resultado lleva todas las claves de siempre más `result.sting`. Funciones: `claw_of`, `marks`, `timeline`,
    `venom_state`, `max_force_hint`, `adjust_tool` (radio real y carga de pandeo, también reforjado). La precarga
    `Physics` ↔ `StingLab` es cíclica a propósito.
  - `LabState.compute(p, bench_model)` se puede llamar desde hilos (la comparativa por familias usa
    `add_group_task(f, n, -1, true)`).
  - Dibujos en `core/lab/art_insects.gd`; animación en `app/lab/bench_insect.gd` y `Bench.buzz_state()` (zumbido
    por especie en el bus «Lab»); sonidos horneados por `tools/bake_lab_extra.gd`.
  - La cutícula de insecto está en `Catalog.V2_TARGETS`. El emoji de la abeja va en el subconjunto de Noto (si otra
    unidad añade emoji: `emoji.mjs --build`).
  - Limitación conocida: contra un sólido se usa la base de las garras (0,15 × alcance) y no el radio real del
    aguijón; no cambia ningún resultado, porque un aguijón pandea mucho antes de romper una chapa.

## Coche en marcha (1k, unida)

- **Motor:** `core/lab/moving_car.gd` (`MovingCar`): estático, determinista, sin nodos y seguro para hilos. Guía
  completa en `docs/fisica/coche-en-marcha.md` §9 (parámetros, llamadas, coste y campos). Animales con datos: las seis
  rapaces, el tigre y el oso (`MovingCar.supports(claw)`); para el resto, `{ ok: false, reason }`.
- **Parámetros** (`MovingCar.PARAMS`): `v_kmh` (0-230: `SLIDER_MAX_KMH`, la velocidad máxima de un turismo de serie), viento de frente y lateral, `accel_g`, `lateral_g`,
  `animal_kmh`, `angle_deg`, `drop_m`, `car_mass_kg`, `temp_c` (−20-45 °C) y `altitude_m` (0-3000 m), más `zone`,
  `posture`, `embedded` y las maniobras de `MANEUVERS`.
- **Llamadas:**
  - `setup(p)` al cambiar animal, coche, zona, postura, viento o maniobra (~0,4 ms);
  - `at_speed(scen, v_kmh)` y `with_air(scen, temp_c, altitude_m)` en cada fotograma de un deslizador (~20 µs);
  - `detach`, `detach_verdict` y `curve` con `setup`;
  - `hold_report(p)` e `impact(p)` al soltar el deslizador (1-5 ms: fuera del fotograma si hace falta).
- **Aguantar puede ser una ventana** (`detach`: `holdFromKmh`, `holdToKmh`, `holdToMode`). Con una frenada fuerte, un
  viento de cola o un panel inclinado, parado no aguanta y más deprisa sí. Ejemplo: el oso de pie en el techo con 0,9 g
  aguanta desde ~62 km/h. `atRest` sigue siendo «aguanta parado» y `kmh` sigue siendo 0 en ese caso. Quien pinte el
  despegue mira primero `holdFromKmh != null`. Los textos salen de `MovingCar.detach_verdict`, `window_saver` y
  `window_end`, y de `MovingCarState.det_words`. Por debajo de `REST_KMH` (0,5 km/h) el coche se da por parado: ningún
  texto dice «~0 km/h».
- **Género de los textos:** `MovingCar.GRAMMAR` (el águila, la arpía y la lechuza son femeninos) lo usan los veredictos
  del motor y `MovingCarState` («sale despedida», «bien agarrada… con ella», «ya la sostienen»).
- **La interfaz enseña siempre la banda** (`minKmh`–`maxKmh`, `holdsLo`/`holdsHi`, `needMaxN`/`availMinN`…), no solo el
  valor central: el agarre de las aves y toda la aerodinámica del tigre y el oso son estimaciones, y la banda es
  ancha (águila con las alas plegadas en el capó: 230 km/h, de 105 a 334).
- **Rapaces corregidas:** `core/lab/claws_v2.gd` → `OVERRIDES` (agarre de Sustaita & Hertel 2010, sin los mitos de
  los «psi», halcón en picado medido). `MovingCar` las aplica dentro. **Pendiente:** que `Catalog` aplique
  `ClawsV2.apply` en el modelo 2.0 para el resto del banco (va con la física 2.0 de biología, que regenera el golden).
- **Balance de energía del golpe** (`impact(p)`): los términos (garras, chapa o vidrio, animal, empujón al coche,
  calor del rozamiento y lo que se lleva el animal) suman exactamente el total; un test lo comprueba en 360 golpes.
- **Casuario, garras experimentales y modo defensa (4d, unida).** API aditiva: sin material ni defensa, el
  resultado es idéntico al bit al de la 1k (3780 casos comprobados). Guía en `docs/fisica/coche-en-marcha.md`
  §9.3/§9.10, §10-§12.
  - Parámetros nuevos:
    - `inlay` (id de `Data.INLAYS`; `"none"` por defecto);
    - `sex` (casuario);
    - `defense` (animal asustado);
    - `embed_mm`.
  - Casuario:
    - `supports_impact` / `supports_hold`: el casuario solo patea; «Encima del coche» devuelve
      `{ ok: false, reason: HOLD_NO_REASON }`;
    - `impact_zones_for` (capó, puerta y aleta), `sexes_of`, `sex_of` y `mass_of`.
  - Campos:
    - `setup.inlay`, `clawHoldN` y `defense` (`forceN` con banda, `tipPressureMPa`, `verdict`, `vsub`, `rakeN`,
      `anchorN`, `restAnchorN`);
    - `impact.kick`, `impact.clawFracture`, `impact.defense`, `attack`, `sex` e `inlay`;
    - `dent.capped`.
  - `core/lab/claw_fracture.gd` (`ClawFracture`): la garra reforjada es una viga en voladizo, con la carga donde la
    empuja la chapa. Las frágiles se mellan o se parten, las dúctiles se doblan (Tabor, H/2,8) y la hematites queda
    «sin datos». Aún no se usa en `Physics.compute` (pendiente en la hoja de ruta).
  - En defensa, la fricción sigue siendo la del peso. El arado de las garras hundidas (Bowden & Tabor 1950, `rakeN`)
    se suma solo a lo que no araban ya en reposo, y su banda baja es 0.
- **Garras trabadas en el plástico, viento de cola y fuentes (4g, unida).** API aditiva: sin plástico atravesado en un
  costado ni viento de cola con las alas abiertas, el resultado no cambia. Guía en `docs/fisica/coche-en-marcha.md` §13.
  - **Desgarro:** en un costado de plástico (aleta o puerta), unas garras que lo atraviesan quedan trabadas. Si el
    animal aguanta lo que pide rajarlo (su anclaje con las garras clavadas), lo raja a lo largo hasta pararse respecto
    al coche o llegar al final del panel. Si no, se le sueltan.
    - Campo `impact.tear` (`null` si ninguna garra lo atraviesa):
      - `applies`, `holds` y `claws`;
      - `lengthMm` con su banda (`minMm`, `maxMm`);
      - `timeS`, `energyJ`, `perClawN` y `forceN`;
      - `anchorN`, `toughnessKJm2` y `thicknessMm`;
      - `stopped`, `reachesEnd` y `vExitKmh`;
      - `quality` y `source`.
    - Funciones: `tear_run` (pura) y `tear_txt` (la fila «Desgarro» del informe).
    - Datos: `PLASTIC_TEAR`, R = 45 kJ/m² (banda 20-50), la resiliencia con entalla de la ficha de SABIC del Noryl
      GTX964; es una estimación con el caso medido más parecido.
    - Solo en costados: arriba, la fricción del peso ya cuenta las garras que cortan el plástico. El casuario tampoco
      lo tiene.
  - **Balance:**
    - `energy.punctureJ` y `energy.tearJ`, con `clawsJ = punctureJ + tearJ`;
    - el término de las garras pasa a llamarse «Garras (punción y desgarro del plástico)»;
    - siguen siendo 6 términos que suman el total;
    - la energía normal que se disipa es `punctureJ + panelJ + animalJ`.
  - **Viento de cola:** con el aire por detrás (v_x < 0), el ala abierta usa `BIRD_AERO.wing.<estado>.cl_rev`
    (Sheldahl & Klimas 1981, NACA 0012 de 0 a 180°) y nunca sustenta más que de cara. `_case` lleva `clsr` y `klr`.
  - **Fuentes campo a campo:**
    - `sources` en `BODIES`, `ZONES` e `IMPACT_ZONES`;
    - `height_m`, `length_m` y `draw` tienen calidad «dibujo» y nunca se enseñan como física;
    - `LIMB_STIFFNESS` guarda la fuente de la rigidez de la pata del motor.
  - **En la interfaz:** hecho.
    - La tarjeta (4j): el largo del desgarro con su banda y si se sueltan las garras, los ~113 N por garra en «¿Sabías
      que…?», y las fuentes nuevas y el CL al revés en «Fuentes y estimaciones».
    - El dibujo (4k): las ranuras.
- **Los velocirraptores en el coche, el salto, la masa de las garras y el afilado (4i-B2, unida).** API aditiva: los
  animales de antes dan lo mismo, salvo los golpes con garras reforjadas, que ahora llevan la masa de sus garras. Guía en
  `docs/fisica/coche-en-marcha.md` §14.
  - **Tipo nuevo `kind` «teropodo»** (`velociraptor_pelicula` y `velociraptor` en `BODIES`):
    - cuerpo de ave sin alas, solo agazapado (`POSTURES.teropodo`);
    - agarra con el pie donde agarran las rapaces (limpiaparabrisas, barras y borde de la ventanilla) con el agarre de
      su ficha: `grip_band(claw)` y `grip_source(claw)` leen `dino.forces.grip` y, si no hay, `ClawsV2`;
    - ataca saltando (`attack: "salto"`, `is_leaper(body)`).
  - **Campos nuevos de `BODIES`:**
    - `strike_claws` (las garras que golpean; `strike_claws_of(body)`, por defecto `contact`);
    - `contact_mm`, `frontal` (el área frontal de un ave con su masa: `THEROPOD_FRONTAL`) y `run_kmh` (con banda);
    - `variant` («pelicula» o «reconstruccion»), que solo sirve para el dibujo, como `height_m` y `length_m`.
  - **El salto** (`leap_block`, `leap_flight`, `leap_reach_m`, `leap_reaches`, `panel_height_m` y `leap_txt`):
    - despega con la carrera de su ficha (como mucho la central) y el salto de `KICK` (los mismos w y f que la patada
      del casuario);
    - el vuelo se integra con RK4 y la resistencia del aire, y cae en la mitad del panel, según la berlina de Cui et al.
      2025 (`HOOD_EDGE_M`, `ROOF_M`);
    - llega al capó y al parabrisas, no al techo: `impact_zones_for` no lo ofrece y, si se pide, `impact()` dice por
      qué (`LEAP_ZONE_REASON`). Contra un costado golpea con la carrera.
  - **El de cine:** `is_film(claw)`. `can_cut_body(inlay, target, claw = null)` mira, sin material, la dureza de la
    propia garra (la queratina nunca corta la chapa; la garra de película, sí). `film_verdict` y `film_claw_txt` solo
    cambian las palabras y siempre añaden el contraste con el animal de verdad.
  - **Masa de las garras reforjadas** (`claw_mass_block`, `claw_mass_txt`; módulo `ClawMass`): entra en todos los
    golpes. Como la velocidad la impone el coche, la masa de más suma ½·Δm·v². El tope de la patada sigue con la masa
    del animal.
  - **Afilado:** `PARAMS.sharpness` (0-1, el de `Physics.sharpness_of`), solo con garras reforjadas. Con s = 0 da lo de
    siempre, al bit. Funciones `sharpness_report(p)` y `sharp_tip_txt(info)`.
  - **Campos nuevos:**
    - en `impact()`: `leap`, `clawMass` (con `extraJ`), `sharpness`, `cutsBody`, `film` y `attack: "salto"`;
    - en `setup()`: `sharpness`, `film` y `draw.variant`;
    - filas nuevas del informe: «Salto», «Garras de película», «Masa de las garras» y «Punta afilada».
  - **Estado (`MovingCarState`):**
    - un solo «Velocirraptor» en el selector (`VARIANTS`, `supported_animals()`, `animal_entry_id(id)`), el de cine por
      defecto, y la reconstrucción con `variants()` y `set_variant(id)`;
    - `film()`, `is_leaper()`, `sharpness`, `set_sharpness(s)`, `sharpenable()` y `sharpness_view()`;
    - `QUALITY_TEXT` y `QUALITY_RANK` aceptan «ficcion»;
    - dos experimentos de un clic: `velocirraptor_pelicula` y `velocirraptor_real`;
    - `arrival()` da las componentes del salto.
  - **Demo:** `demo_coche --caso=13` (el de cine salta sobre el capó y lo raja) y `--caso=14` (el de verdad, en el
    mismo salto).
  - **En la interfaz:** hecho. La tarjeta (4j) lleva el selector de variante, el color de «ficcion», el deslizador de
    afilado y esconde la caída con `is_leaper()`. La vista (4k y 4l) dibuja los dos velocirraptores con su variante y su
    tamaño.

- **Banda del golpe, velocidades, formatos únicos y fuentes legibles (4j, unida).** Guía en
  `docs/fisica/coche-en-marcha.md` §9.11.
  - **Formatos en un solo sitio:** `core/lab/car_format.gd` (`CarFormat`). Los nombres de antes (`MovingCar.fmt_long`,
    `fmt_energy`, `MovingCarState.fmt_n`…) siguen existiendo y lo llaman. Ningún texto cambia.
    - Añadidos de la 4o: `fmt_panel` (el espesor de un panel con su pintura, «0.81 mm») y `fmt_g_max` (la frenada máxima
      que aguanta, redondeada hacia abajo). `fmt_n` escribe MN desde 1 MN («3.0 MN» y no «3032.0 kN»): ese texto sí
      cambia.
  - **Velocidades y vuelo:** `impact().kinematics`, que es `MovingCar.kinematics(p, leap)` y también funciona sin golpe.
    - La velocidad respecto al coche en sus tres ejes (`relKmh` x/y/z), con las componentes normal y tangencial.
    - El vuelo: `flightS` = √(2h/g), con `dropM`, `fallKmh` y `carFlightM`. En los velocirraptores usa `leap.ux/uy/uz`
      y `leap.timeS`, sin recalcularlos.
    - `MovingCarState.arrival()` sale de aquí.
  - **Banda del golpe:** `impact().band` (`MovingCar.impact_band`), con todo a favor del coche (`lo`) y todo en contra
    (`hi`).
    - Rangos `{ value, min, max }` de `marksDepthUm`, `marksLengthMm`, `dentMm`, `normalJ`, `tearMm` y `slideM`, más
      `through`, `marksThrough`, `marksBelowMm` (4o), `varies`, `fixed`, `quality` y `source`.
    - Se mueven la fricción, el barniz (solo en las marcas), la tenacidad del plástico y el anclaje, la fuerza de defensa,
      la patada del casuario (masa, salto y fuerza), el salto y la carrera de los velocirraptores (`leap_block(…, hi)`)
      y el hueco bajo el capó, de 20 a 100 mm (`CLEARANCE_BAND`, 4o).
    - Sin banda, y lo dice la fuente: la rigidez y el recorrido de la pata, el hueco bajo el techo, la puerta y la aleta
      (`CLEARANCE_FIXED`) y la hoja de vidrio.
    - El caso central reproduce `impact()` exacto. Cuesta de ×1,1 a ×2,9 en el hilo del estado; el fotograma sigue en
      ~1,3-1,8 ms.
  - **Fuentes legibles:** ningún texto visible del coche en marcha lleva rutas internas ni nombres de código.
    - Lo vigila `tests/lab/test_moving_car_textos.gd`: 239 ensayos y 35 351 textos.
    - Fuentes nuevas con nombre: `SRC_DENT`, `SRC_GLASS_FLEX` y `SRC_PUNCTURE`.
  - **Estado:** `impact_band_text()` y `sources_summary()`. Lecturas nuevas «Respecto al coche», «Vuelo», «Marcas
    (profundidad)» y «Raja», y «Contacto» dice «el desgarro» cuando lo hay. Desde la 4o, «Contacto» no sale cuando no hay
    tiempo de contacto, y si no resbala dice «Resbala: nada».
  - **Tarjeta:**
    - la banda en el cuadro del veredicto del golpe;
    - las fuentes plegadas, con su resumen;
    - el selector de variante del velocirraptor;
    - el deslizador «Afilado», solo con garras reforjadas;
    - la calidad «ficcion», en rosa;
    - la caída escondida en los que saltan.

- **La ventanilla templada en el golpe (4m, unida).** Guía en `docs/fisica/coche-en-marcha.md` §15.
  - **Zona `luna`** en `IMPACT_ZONES`, con el nombre visible «Ventanilla»: costado, vidrio templado (`Glazing.SIDE_WINDOW`,
    el del banco) y su punto del dibujo (`draw`). No se llama «ventanilla» porque en `ZONES` ese id es el borde, donde
    se agarran las rapaces.
  - **Quién llega** (`window_reach`, con `WITHERS_M`): el centro del apoyo que golpea tiene que pasar de la cintura de la
    puerta (~0,89 m).
    - Llegan las rapaces volando, los velocirraptores saltando (golpean en lo alto del salto: `kinematics.apex`) y el oso
      por su cruz (0,90-1,50 m).
    - El tigre no llega (su cruz, 0,80-1,00 m) y el casuario patea más abajo.
    - A quien no llega no se le ofrece la zona; si la pide, `impact()` dice por qué.
  - **`impact().sideWindow`** (null fuera de la luna): `shattered`, `cause` («flexión» o «grieta»), `fragmentMm`,
    `fragments25`, `bendN`, `pierceN`, `peakN`, `pane` («front»), `sigmaS`, `quality` y `source`.
    - Estalla al flexar o por una grieta, si la punta es al menos tan dura como el vidrio. La queratina y la garra de
      película nunca la revientan por una grieta.
    - En el balance, «Ventanilla (hasta estallar)», U = F²/2k; los ~17 J del temple van aparte (`temperJ`), porque no
      salen del animal. Si aguanta, el término es «Ventanilla (aguanta: lo devuelve)» (4o).
  - **Banda:** se mueve la compresión del templado, 80-150 MPa (`TEMPER_SIGMA_MPA`, Achintha 2020); la hoja va en
    `fixed`. Campos `band.sideWindow` y `band.lo/hi.sideWindow`.
  - **Textos y sonido:**
    - veredictos «ESTALLA LA VENTANILLA» y «LA VENTANILLA AGUANTA», con sus versiones de película;
    - sonido «shatter» si estalla y «press» si aguanta;
    - experimentos `ventanilla_diamante` y `ventanilla_queratina`;
    - demo `demo_coche`, casos 15 a 17.
  - **Vista:** `MovingCarView.zone_draw` usa `IMPACT_ZONES[zona].draw` cuando existe, `CarDamage.side_zone("luna")` es un
    costado y `CarShape.PANELS.luna` es el tramo de la ventanilla delantera.

- **La hondura de las marcas y la pasada de física (4o, unida).** Guía en `docs/fisica/coche-en-marcha.md` §16 (las
  fuentes, desde la 4p, en §18).
  - **Una marca que atraviesa el panel tiene la hondura del panel:** 0,81 mm en el acero con su pintura y 2,61 mm en la
    aleta de plástico, la misma regla que ya seguía la 4g y la que lee la vista.
    - La punta va aparte y con tope: `marks.tipUm`, `marks.belowMm`, `marks.bottoms` y `marks.clearanceMm`. No pasa del
      hueco bajo el panel ni del largo de la garra.
    - La punción se para en el mismo tope (`puncture.depthUm`), y los desgarros del animal asustado también
      (`defense.tear`).
    - Antes, 84 de 656 golpes daban marcas o punciones más hondas que el panel más su hueco; ahora, ninguno. Lo vigila
      `tests/lab/test_moving_car_hondura.gd`, en todos los animales, coches, zonas y materiales, con miedo y quieto
      encima.
  - **Datos:** `HOLD_PANEL`, `PANEL_GAP_TXT`, `CLEARANCE_BAND` (el hueco bajo el capó, de 20 a 100 mm, Fredriksson et al.
    2007 vía Lindgren et al. 2025, estimación) y `CLEARANCE_FIXED` (los demás huecos, sin banda y con el porqué).
  - **Arreglos de cálculo:**
    - las bandas de las fuerzas de `at_speed` salen de los casos de los dos lados (con una frenada salía «de 2539 N a
      2539 N»);
    - la frenada máxima que aguanta se redondea hacia abajo (`CarFormat.fmt_g_max`);
    - el plástico tiene su término en la energía: «Plástico (no se abolla)».
  - **Caso de referencia:** `velocirraptor-cine-capo` suma `marks.through`, `marks.depthUm` = 810, `marks.tipUm` =
    80 810, `marks.bottoms`, `puncture.depthUm` = 80 810 (antes, 120 000) y `puncture.holeUm` = 36 000. Desde la 4p (el
    hueco compartido con la abolladura), `puncture.depthUm` = 34 987,234 y `holeUm` = 18 961,688.
  - ~~Queda abierto: lo que aguantan de lado unas garras de tungsteno clavadas («3.0 MN»)~~: resuelto por la 4p (abajo).
- **El pico de Hertz, las garras clavadas, el hueco compartido y los logros de la 2.0 (4p, unida).** Guía en
  `docs/fisica/coche-en-marcha.md` §17 y fila en «Cambios de la 2.0» de `docs/FISICA.md`.
  - **Pico de Hertz** (modelo 2.0, `physics.gd` → `_hertz`): `p0MPa`, `hertzRadiusUm` y `hertzYield` («punta», «objetivo»,
    «las dos» o null), solo con un sólido homogéneo, sin golpe, sin la herramienta rota, con el círculo dentro de la
    esfera de la punta y φ < 1; null en lo demás y en la 1.x. La tarjeta del resultado enseña «Presión media» (F/A) y
    «Pico de Hertz», con la frase de `BenchTexts.hertz_note` / `ResultCard.hertz_note`. Johnson 1985 y Tabor 1951.
  - **Garras clavadas** (`claws_hold_n`): el menor de la flexión de la garra, su cortante (`ClawFracture.shear_limit_n`) y
    el aplastamiento de la chapa alrededor del agujero (`sheet_bearing_n`, con `bearing_kt`, `SHEET_FU` y `SHEET_BEARING`:
    EN 1993-1-3, EN 1993-1-8 y AISC 360-16), con `governs`, `perClaw`, `clawN`, `sheetN` y la lectura `claws_hold_txt`
    («manda la chapa…»). El águila con carburo: de 3,0 MN a 20,6 kN.
  - **Hueco compartido** (`shared_room_um`, `_share_gap`, `shared_gap_txt`, `SHARED_GAP_STEPS` y `SHARED_GAP_TOL_UM`): la
    punta de la punción y la abolladura se resuelven a la vez con el hueco de debajo. Caso 13: punta 35,0 mm y abolladura
    45,8 mm.
  - **Logros de la 2.0:** `Lab.BADGES_V2` (11, aparte de los 15 de la 1.x), `earn_badges_model`, `earn_car_badges`,
    `POLIZON_KMH` y `LabState.earn_car_badges`. Golden 2.0 regenerado: solo las claves nuevas y `badgesAfter`.
  - **Pendiente:** la rotura de la garra en el golpe sigue mirando solo la flexión; el hueco compartido es el del estado
    final (con la abolladura que llena el hueco, la rotura se evalúa con un 10 % menos de carga); con chapas de más de
    1,3 mm, más chapa puede aguantar menos (manda la flexión en la base: es física y está escrito).

## Dibujos y animaciones del banco 2.0 (4f, unida)

- **Módulos de dibujo (core, sin nodos: grafos de escena SVG como `art.gd`):**
  - `core/lab/art_materials.gd`: grietas de Hertz, astillado y mellado, ventanilla templada que estalla, parabrisas en
    estrella con PVB, hoyuelo de la abolladura, uña que se dobla o se parte, huella bajo carga frente a la que queda, y
    las lupas (`lupa_art`, `lupa_frame`, `LUPA_R`);
  - `core/lab/art_zones.gd`: el corte de la piel por zona del cuerpo, con cortical, cavidad y médula;
    `Art.skin_section_art` lo usa con resultados 2.0 de otra zona o que llegan al hueso;
  - `core/lab/art_biology.gd`: las lupas de la biología (hueso, esmalte, ataque, callo, laceración).
- **Animación (app):** `app/lab/bench_materials.gd` y `app/lab/bench_biology.gd`, llamados desde `bench.gd`. Todo se
  construye en los hilos de `ArtCache`; nada se crea por fotograma y el banco quieto no se redibuja.
- **La 1.x no cambia:** `test_art` compara 372/372 SVG con el oráculo byte a byte. La herramienta se inclina con el
  ángulo de ataque de la 2.0 (`BenchBiology.tool_xform`): la uña por defecto (45°) va arrastrada, como dice `attack.gd`,
  y el dibujo de la 1.x equivale a 145°.
- **Sonidos del hueso:** `SfxInsects.bone_sfx` (en FISICA.md, «Cambios de la 2.0»).

## Banco de ensayo: textos de la 2.0, fuentes visibles y paridad con la 1.x (4n, unida)

- **`core/lab/bench_texts.gd` (`BenchTexts`, sin nodos ni física).** Escribe lo nuevo de la 2.0 con lo que trae el
  resultado de `compute()` y los catálogos con sus fuentes:
  - la presión real del contacto y quién le pone el tope (`pressure_cap`, `pressure_rows`, `compare_pressure`). La
    nominal F/A solo se enseña cuando es la real (con un margen del 1 %); si pasa de una dureza, la comparativa dice
    «(tope)»;
  - `chi_text`: χ = P/H pasa a «> 1000» por encima de mil (una punta afilada a decenas de nanómetros da millones);
  - `fiction`: la etiqueta FICCIÓN del velocirraptor de cine y lo que haría la garra de verdad;
  - `sources` y `sources_summary`: cada dato de la 2.0 del ensayo, con su valor, su calidad (`QUALITY_TEXT`; «model»
    para los modelos publicados) y su fuente legible.
- **`LabState.trial_sources()`** devuelve `BenchTexts.sources(res, { claw, inlay, target })`, o nada sin ensayo o con un
  resultado de la 1.x. La tarjeta del resultado lo pinta en «Fuentes y estimaciones de este ensayo», plegada y con
  «Citas completas».
- **Fundamentos y pie del banco.**
  - `Lab.fundamentos()`: los de la 1.x, con «Impacto» para las dos físicas, más `FUNDAMENTOS_V2`, `FUNDAMENTOS_BIO_V2`
    y los de los aguijones.
  - `Lab.FUNDAMENTOS_NOTE_V2` y `Lab.model_note(model)` (`MODEL_NOTE_V1` o `MODEL_NOTE_V2`, según la física elegida).
  - Los usa la sección del laboratorio. `Lab.FUNDAMENTOS` y `Lab.FUNDAMENTOS_NOTE` siguen siendo el port exacto de la
    1.x, porque los compara el oráculo.
- **Fuentes visibles, sin rutas ni código.** Ningún texto que se ve lleva rutas del proyecto (`docs/…`, `res://…`) ni
  nombres de código (clases, constantes o funciones): solo la cita (autor y año, norma o ficha). Lo vigila
  `tests/lab/test_banco_textos.gd` (más de 2000 ensayos y 50 000 textos), que además exige fuente y calidad en cada dato
  de la lista.
- **Auditoría:** `docs/fase2/auditoria-banco.md`, con la paridad control a control con la 1.x y los campos de la 2.0 uno
  a uno.
- **Pendiente:** los logros de lo nuevo de la 2.0 y el pico de Hertz en el resultado 2.0 (en
  `docs/fase2/encargos/pendientes.md`).

## Tarjeta del coche en marcha (4c, unida)

- **Página propia** (fallo de Eric: el banco y el coche en marcha iban en la misma página y se amontonaban tarjetas y
  sonidos):
  - la sección de la tribología biológica tiene una barra de páginas fija arriba (`LabSection.PAGES`: «Banco de
    ensayo», «Coche en marcha» y, desde la 5b, «Cetrería»);
  - la página que no se ve no calcula ni suena (`step` y `_refresh` solo trabajan en la visible, y ARAÑAR y su atajo
    solo ensayan en el banco);
  - el titular de la barra del programa sigue a la página (señal `headline_changed`);
  - la página se recuerda en `[lab] page`;
  - la tarjeta lleva su propio selector de animal siempre a la vista (`animal_box`).

- **Estado sin nodos:** `core/lab/moving_car_state.gd` (`MovingCarState`, RefCounted) guarda lo elegido y pide los
  números a `MovingCar`; la tarjeta (`app/lab/moving_car_card.gd`), su dibujo (`moving_car_view.gd`) y su gráfica
  (`moving_car_chart.gd`) solo pintan. Todo texto con números sale del estado (`why_text`, `facts`, `moral`, `band`,
  `now_text`, `det_words`…); la interfaz no compone frases con números.
- **Cuándo se calcula:**
  - `setup` y `curve` (con `detach` y su veredicto) al cambiar de animal, coche, zona, postura, viento o maniobra;
  - `with_air` al mover la temperatura o la altitud;
  - `at_speed` en cada fotograma del deslizador de velocidad;
  - `hold_report` e `impact`, en un hilo (`WorkerThreadPool`) al soltar el deslizador (y en el golpe, como mucho cada
    `DRAG_HEAVY_MS`); `step(ms)` los lanza y recoge, `finish()` los espera.
- **Hilos: gana el último.** Un resultado de otro ensayo se descarta. Uno del mismo ensayo con otros deslizadores se
  enseña mientras llega el bueno (`heavy_fresh()`): «mismo ensayo» lo deciden `_TRIAL_KEYS` (animal, coche, modo, zona,
  material, miedo, sexo…). Con `threaded = false` todo va en el acto y da lo mismo.
- **Señal `changed`** y tres contadores (`setup_version`, `live_version`, `heavy_version`): la interfaz repinta solo lo
  que ha cambiado.
- **Deslizadores:** su recorrido y su valor se ponen con las señales bloqueadas (`MovingCarCard.set_slider`, como
  `MillPage.set_slider`), por la trampa del recorte de Godot dentro del árbol.
- **Experimentos de un clic:** `MovingCarState.EXPERIMENTS`, ids estables (`aguila_120`, `aguila_alas`, `oso_frenada`,
  `lechuza_asustada`, `aguila_tungsteno`, `tigre_puerta`, `tigre_zafiro`, `casuario_puerta` y `aire`, que se suma a
  cualquiera). Un experimento es un solo `setup`.
- **Sonido:** el golpe suena con los efectos del banco por el bus «Lab» (`play_sfx`, el `Callable` que da la sección; el
  id sale de `impact_sfx()`).
- **Letra de los titulares (Syne):** la virgulilla sale como un guion o un punto. El veredicto pasa por
  `MovingCarCard.headline()` («~» → «UNOS »), y los textos de párrafo, por `nb()`, que no parte las unidades («km/h») ni
  separa el número de su unidad.

## Garras y marcas del coche de cerca (4s, unida)

Peticiones de Eric del 13-10 (las garras y las marcas en 3D, en alta calidad) y del 17-10 (las capas que atraviesa y si raja
o abre la puerta o el techo). Guía en `docs/fisica/coche-en-marcha.md` §21-§23.

- **Motor:** `core/lab/car_tear.gd`, funciones puras sobre las marcas que ya da el motor (no calcula marcas propias):
  `assess(o)` decide el escalón «marca» → «perfora» → «raja X cm» → «abre la puerta» (solo si la raja llega al canto de la
  cerradura; FMVSS 206) y explica por qué el techo nunca se abre (`roof_txt`); `cutaway(target, depth_um, through)` y
  `layers_txt` dan las capas que corta (barniz, color, imprimación, anticorrosivo y chapa); `tear_toughness(target)` es la
  R de la chapa (≈ σ0·t, estimación con banda, Cotterell y Reddel 1977; Atkins y Mai 1985) o la del plástico (`PLASTIC_TEAR`).
- **Vista 3D:** la capa de las garras `CarScene.CLAW_LAYER` = 8 (la ve la cámara del primer plano, que sigue a las garras que
  marcan); la ventana del primer plano dentro de la vista y, en la tarjeta, `zoom_seg` («Cámara: Coche entero · Garras de
  cerca»), que convive con el `view_seg` de la 4t (persecución o de lado). Las posturas de agarre y `claw_tags()` en
  `hd3d.gd` (qué malla es garra, para la capa y el material); las muestras de material de `claw_swatch.gd`.
- **Tarjeta:** la ficha «Hasta dónde llega» y el corte de la chapa con el surco hasta donde llega (también, en pequeño, en el
  primer plano).
- **Tests:** `tests/lab/test_car_tear.gd` (más velocidad o una garra más dura nunca dan un escalón más bajo; la queratina no
  perfora el acero; el techo nunca se abre) y `tests/app/test_coche_primer_plano.gd`.
- **Cámara del coche (`zoom_seg`):** tres botones: «coche» (el coche entero con la ventana de las garras), «garras» (las
  garras de cerca en toda la vista) y «marca» (el surco de una garra a unos milímetros: 25 veces su ancho, entre 3 mm y 3 cm,
  desde 40° sobre el panel, sin el cuerpo del animal, que tampoco hace sombra, y con la luz de relleno del primer plano). La
  vista: `set_closeup_full(on, marks)`.
- **Pelo de cerca (`hd3d.set_near_fur(on)`):** con el primer plano en toda la vista, mechones a `NEAR_STRAND` (0,4) de su
  grosor; si no, el de lejos (`_far_fur`). Solo parámetros de los materiales de la caché de la vista.
- **Dibujo, sin física nueva:** la cara de la rotura (`hd3d._chip_face`, un disco claro en el corte de la garra mellada);
  `GEM_ENV_ROAD` (2,5, en `hd3d.gd` y `animal3d.gd`: el entorno de las gemas y los vidrios en la carretera; los metales, ×4,
  `METAL_ENV_ROAD`); `DENT_SHADE` (0,55 en `car_paint.gdshader`: la normal de la abolladura se inclina un 55 % de su
  pendiente; la hondura de la malla es la de la física); los labios del primer plano (`CarModel.set_lip_boost(k)`, uniforme
  `lip_boost` de `car_damage.gdshaderinc`: ×4 de alto y ×1,7 de ancho con la marca de cerca; el surco, el de la física).

## Coche en curva (4t, unida)

Petición 63 de Eric: «añadir un coche que gira en curvas, y cambia radicalmente el lado de la fuerza G». Guía en
`docs/fisica/coche-en-marcha.md` §20.

- **Motor:** `core/lab/car_curve.gd` (`CarCurve`), funciones puras, estáticas y deterministas, sin nodos. No toca
  `moving_car.gd`: usa su equilibrio de siempre (`MovingCar._eval`, `_margin`, `_mode_of`, `_window`, `_no_window`,
  `_band_txt`, `_ending`) con la aceleración lateral de la curva.
  - Cinemática: `lateral_ms2(v, R)` (a = v²/R, exacta), `demand_g`, `skid_kmh(R, μ)`, `felt_ms2` (sin pasar del tope del
    coche), `yaw_rate` (ω = a/v) y `at_lateral_kin`.
  - La carretera: `road(R, target)` (velocidad de proyecto, J de la norma, clotoides, tramos de la S y tope del coche),
    `design_kmh`, `jerk_norm`, `grip_of`, `radius_at(u)` y `slider_u(R)` (el deslizador logarítmico, con radios redondos y
    los valores marcados), `path` (el plano visto desde arriba).
  - La S: `s_kappa`, `s_dkappa`, `s_at(rd, v, t)`, `s_profile`, `s_duration` y `s_jerk_ms3`.
  - El animal: `at_speed(scen, v, R, grip, side)` y `at_lateral` (las de `MovingCar.at_speed` más el campo `curve`: `rM`,
    `side`, `demandMs2`, `demandG`, `latMs2`, `latG`, `skids`, `gripG`, `skidKmh`, `tyN`, `ttN`, `shares`, `markDeg` y
    `meter`), `side_shares` y `mark_deg`.
  - El despegue: `detach(scen, R, grip, side)` y `detach_s` (lo de `MovingCar.detach` más `rM`, `side`, `gripG`, `skidKmh`,
    `skidMinKmh`, `skidMaxKmh` y `skidsFirst`), `chart` y `verdict` («EL COCHE DERRAPA ANTES», «RESBALA HACIA FUERA» o el de
    siempre).
  - El golpe en curva: `approach_offsets` (el camino del animal visto desde el coche que gira; la fuerza del golpe no
    cambia).
  - Textos: `now_txt`, `why_txt`, `side_txt`, `side_name`, `g_ms2_txt` y `r_txt`.
  - Datos con `source` y `quality`: `NORM_RADII` (3.1-IC, tabla 4.4), `PRESETS`, `RING_R` (glorieta, estimación),
    `CAR_GRIP` (turismo y deportivo, estimación), `LOAD_TRANSFER` (h/b, estimación) y `DRAW_ONLY`.
- **Estado** (`MovingCarState`, bloque «Curvas (unidad 4t)» al final y unos pocos enganches):
  - `road` (`CarCurve.ROADS`: «recta», «curva», «s») y `radius_m`; `set_road` y `set_radius` (sin setup: `_recurve`);
  - `curve_on`, `curve_road`, `curve_grip`, `curve_side`, `curve_now`, `curve_sides` (la S, los dos lados);
  - textos: `curve_text`, `s_text`, `meter_note(c, loop_s, short)`, `road_note(short)`, `radius_text`, el porqué cuando el
    coche derrapa antes (`_curve_skid_why`), lecturas, fuentes y «¿sabías que…?» de la curva;
  - la S en la vista: `s_frame(t)` y `s_duration`; el medidor: `meter`;
  - el golpe en curva: `impact_curve_on`, `impact_lat_g`, `impact_approach(dist, n)` e `impact_curve_text`;
  - **en recta no se llama a nada de la curva** (`_at_speed` y `_derive` van por el camino de siempre): todo sale al bit
    como antes (lo vigila `test_car_curve.gd`). Maniobra con curva y carretera en curva no se suman; los experimentos van
    en recta.
- **Vista 3D** (`app/lab/car3d/`, archivos nuevos):
  - `road_curve.gd` y `road_curve.gdshader`: la tira de la carretera llevada a lo largo del eje de la curva con su rumbo
    (`path_p`, `path_h`: 64 puntos), con líneas, bordillos rojos y blancos y el arcén de tierra y hierba seca; la corta de la
    vista de lado (la curva 6 veces más cerrada, dibujo) y la larga de la persecución (de −40 a +260 m, al radio de verdad).
    También el balanceo (5°/g), la inclinación del animal (14°/g), el giro de las ruedas (Ackermann × 3) y la cámara de
    persecución (`chase_pose`, más cerca en el teléfono). Todo dibujo;
  - `g_meter.gd`: el medidor de fuerza G (la flecha por unidad de peso, el círculo de las garras, el tope del coche, la
    estela de la S y el anillo del cambio de lado);
  - `road_map.gd`: el plano de la carretera vista desde arriba con el coche.
- **Vista de persecución** (por defecto en curva; «De lado» en la tarjeta, para las garras): cámara detrás del coche sobre la
  propia carretera; la lupa no sale y el horizonte del paisaje sigue a la cámara. En la S, al cruzar la fuerza el cero en la
  clotoide de cambio, el rótulo «¡Cambia de lado!» y el anillo del medidor (~1 s).
- **Bloques al final de los archivos del coche** (cada calle cambia solo su bloque):
  - `car_model.gd`: «Curvas (unidad 4t)», las ruedas del otro lado (`ensure_far_wheels`) y la dirección (`set_steer`,
    `_wheel_rot`); `set_wheels` llama a `_wheel_rot` (con la dirección a 0 es la misma transformación de antes);
  - `car_scene.gd`: «Curvas (unidad 4t)», `set_curved`, `set_roll`, `set_chase`, `update_chase`, la carretera larga y la
    cámara; `_road()` guarda los nodos de la recta en `_flat` y `set_road` mueve también la curva;
  - `moving_car_view.gd`: «Curvas (unidad 4t)», `_sync_curve`, `_s_show`, `_s_tick`, `_apply_curve`, `chasing`,
    `set_chase_pref`, `_chase_horizon`, `_layout_meter`, `_twist_hold_marks` (los desgarros torcidos hacia fuera),
    `_draw_flash` y `_approach_at` (el golpe en curva); enganches de una línea en `sync`, `step`, `_draw`, `_draw_overlay`,
    `_place_animal`, `_draw_hold_animal` y `_draw_impact`;
  - `moving_car_card.gd`: «Curvas (unidad 4t)», `_build_road`, `_connect_road` y `_paint_road` (el selector, la vista, el
    radio con los valores de la norma y la frase).
- **Demo:** `app/lab/demo_curvas.tscn` (7 casos: recta, curva hasta derrapar, la S, la lechuza que resbala, el oso en el
  deportivo, la S de lado y el golpe en curva).
- **Tests:** `tests/lab/test_car_curve.gd` y `tests/app/test_car_curve_ui.gd`.
- **Pendiente:** el peralte (la curva va plana); la dinámica del animal en la S (cuasiestático); la referencia del aire en
  curva; la luneta gris al balancear en la vista de lado (`car_glass.gdshader`, de la calle A).

## Cetrería: cuidado de garras (5a y 5b, unidas)

- **Motor (5a)** (`core/lab/claw_care.gd`, `ClawCare`): determinista y sin nodos, una instancia por garra. Guía completa
  en `docs/fisica/cetreria.md` (§10, la guía de integración).
  - **Crear:** `ClawCare.new({ animal: "rapaz" | "tigre" | "oso" | "velociraptor", claw, inlay, quick: "valor" |
    "oculta", seed, overgrowth_days, sedation, humidity })`.
  - **Acciones:**
    - `file({ tool, zone, angle_deg, at_mm, length_mm, force_n, travel_mm, speed_mm_s, direction })`; con el torno,
      `dwell_s` y `rpm`;
    - `clip({ tool, remove_mm })`, `hemostasis({ tool, pressure_s })` y `apply({ tool })`;
    - `set_humidity()`, `set_sedation()` y `advance(seconds)`.
  - **Lecturas:** `snapshot()` (perfil, `claw`, `tip`, `thermal`, `bleeding`, `damage`, `animal` y `events`),
    `report()` (veredicto, nota y consejos con su fuente), `tip_geometry()`, `radius_at(s)`, `core_at(s)` y
    `quick_cover_mm()`.
  - **Tutorial:** `ClawCareTutorial.steps(animal, proceso, material)`, con su fuente y su condición (`check`).
  - **Sonidos:** `sfx_for(action, result)`, con los ids del laboratorio.
  - **Datos:** `core/lab/claw_care_data.gd`, cada uno con `source` y `quality`.
  - **Arreglos de la revisión:**
    - del 30-09: cada herida con su hemostasia, el enfriamiento invariante a trozos y la anestesia contada desde la
      primera acción;
    - del 03-10: el modelo térmico no pasa de la temperatura a la que se quema la queratina (`THERMAL.char_c`, ~230 °C;
      `thermal.charred` y el suceso «quema»); donde ya no queda garra bajo el torno, no hay calor; y el aviso de
      aplastar no da la distancia a la carne viva en una garra oscura.
- **Página y escena 3D (5b)** (`app/lab/cetreria/`; estado sin nodos en `core/lab/claw_care_state.gd`, `ClawCareState`):
  - **La página «cetreria»** es la tercera de la sección. En escritorio, la vista 3D arriba y las tarjetas en su columna;
    en el teléfono, una columna. El tutorial de la primera vez se recuerda en `[lab] care_intro`.
  - **Estado** (`ClawCareState`): convierte cada gesto en la llamada de `ClawCare` que toca (`press_on`, `drag`,
    `release` y `tick`) y da todos los textos con números.
    - La vista: `hand`, `tray`, `tutorial.control`, `hints`, `readouts`, `mistake`, `sheet`, `bench` y `sound`.
    - También `values_for`, `inlay_options`, `sedation_options`, `rpm_options`, `readable_source` y `result_sheet()` (la
      ficha antes → después).
  - **Página** (`care_page.gd`): `set_fit_height`, `set_intro_seen` y las señales `intro_done` y `try_on_bench`.
    - «Probar en el banco» lleva la garra, el material y el afilado (`ClawSharpness.sharpness_for`) a la página del banco.
  - **Escena** (`care_3d`): `show_view`, `set_view`, `info`, `hit_at`, `claw_screen_point`, `tray_screen_point`,
    `handle_pointer` y `advance`. El estado y las mallas van en su hilo (`care_runner.gd`), fuera del fotograma: 1,8 ms
    de media por fotograma limando.
  - **Controles:**
    - Ratón: arrastrar sobre la garra lima, Mayús + arrastrar gira la herramienta, Mayús + rueda cambia la presión, el
      botón derecho gira la cámara y la rueda acerca.
    - Teclado: 1-5 herramienta (la 5, la amoladora de la 5c), A/D ángulo, W/S presión, E torno, Q rpm, Espacio pausa, V vista, H ayuda, R empezar de
      nuevo y Esc dejar la herramienta.
    - Teléfono: con un dedo se lima y con dos se mueve la cámara.
  - **Sonido:** bucles del torno y de la lima (`core/lab/sfx_care.gd`, horneados con `tools/bake_lab_extra.gd --ids`)
    por el bus «Lab».
  - **Fuentes legibles:** dos tests vigilan que ningún texto visible de la página ni del motor lleve rutas internas ni
    nombres de código.
- **Escenario, animal entero, patas y amoladora (5c, unida).**
  - **El sitio** (`care_room.gd`, solo dibujo): «cetreria» para la rapaz (banco de madera de un centro de cetrería) y
    «clinica» para el tigre, el oso y el velocirraptor (mesa de quirófano). El tablero está en y = 0 y acaba en
    `edge_x`, el borde por el que cuelgan las garras. Se construye una vez por sitio, tamaño y calidad, con las texturas
    pintadas una sola vez; el preset del teléfono quita los objetos pequeños y la lámpara, y usa texturas de 64 px.
  - **El animal entero** (`care_animal.gd`): `build(parent, animal, claw_id, opts)` con el modelo de la 4l de cada
    especie, tumbado en la postura «dormido» (`animals/sleep3d.gd`, sin tocar las posturas del coche); `set_sedation` y
    `animate` (ojos cerrados, respiración lenta y el respingo con dolor). El velocirraptor de película es otro dibujo; su
    física es la de la reconstrucción.
  - **Lo añadido a `Animal3D`** (solo añadidos; los tests del coche siguen igual): `claw_index`, `claw_base`,
    `show_claw_mesh`, `bone_point`, `bone_box`, `posed_aabb` y `pose.asleep`. Cada garra del rig guarda además `name`,
    `base`, `d0` y `up`, el marco de su base.
  - **Patas y garras** (`ClawCareState`): `paws_of(animal)` (dos patas la rapaz y el velocirraptor; cuatro el tigre y el
    oso), `DIGITS` (los dedos de cada animal), `select_claw(paw, digit)`, `set_paw`, `set_digit`, `cycle_paw`,
    `cycle_digit`, `slots_view()` y `set_model(id)`.
    - Hay una `ClawCare` por garra, con su semilla y su carne viva. La sujeción es del animal y pasa a todas.
    - Una garra que sangra sigue su reloj aunque se trabaje otra.
    - Las garras de las patas traseras del tigre y del oso llevan los datos de las de la mano, marcados como estimación
      (`is_hind`).
  - **El aspecto de cada material de garra, en un solo sitio** (`claw_look.gd`): `params(material, color, finish)`,
    `apply(mat, p)` y `apply_model(a3d, p)`. Desde la 5e es un adaptador sobre la biblioteca de materiales, con la misma
    API; `finish` acepta además `surface` y `quality`. La forma de la garra sigue saliendo del perfil de `ClawCare`.
  - **La amoladora de uñas con protector** (`TOOLS.amoladora`, Dremel 7760: cuatro velocidades de 8000 a 25 000 rpm y
    guía de 45°): es otra herramienta giratoria, con el mismo modelo que el torno (`is_rotary`, `rotary_tool`,
    `rpm_steps_of`, `rpm_options(id)`).
    - Sonido (`SfxCare`): `GRINDER`, `SPIN_UP`, `SPIN_DOWN`, `motor_of` y `base_rpm`, horneados con
      `bake_lab_extra.gd`. El tono sigue a las rpm; su bajada al apretar es diseño de sonido, no un dato.
  - **Controles nuevos:** la vista «animal»; P cambia de pata, G de garra y un clic sobre otra garra la elige; 5 es la
    amoladora; con el teléfono, tocar en el aire la enciende y hay un deslizador de presión.
  - **La reforja se enchufa** con `care_page.plug_reforge_lab()` (el laboratorio experimental, de la 5f); el panel de
    entrada, junto al material, con `plug_reforge(panel)`.
  - **Coste:** 2,05 ms de media por fotograma con el oso entero y la amoladora tocando la garra (2,04 ms en el teléfono).
    Construir el animal y el sitio cuesta 60-170 ms la primera vez y ~10 ms desde la caché. Los tests vigilan que en
    cada fotograma no se cree ningún nodo.
- **Pasada de física (5g, unida).** Guía en `docs/fisica/cetreria.md` §11.
  - **Crear:** `ClawCare.new(setup, patient)`, con `setup.digit`, `setup.paw` y `setup.block` (el bloque reforjado en
    bruto). El paciente es `ClawCarePatient` (`claw_care_patient.gd`): un animal para todas sus garras, con el estrés, el
    dolor y el reloj de la sujeción contados una sola vez.
  - **Acciones y lecturas nuevas:** `probe_tip()` (apoya el vértice con un toque de 0,5 N: prende, resbala o se mella),
    `natural_mm()`, `shape()` (la forma en directo: correcta, demasiado fina, roma, facetada o pasada de la carne viva),
    `surface_stations()` (la superficie en la forma que lee `ClawMaterial.surface_image`) y `file().raUm`.
  - **En el `snapshot()`:** `thermal.zone`, `sZone`, `dxMm`, `axis` y `spanMm` (dónde está el calor); en `claw`, la forma
    de su dedo (`digit`, `hind`, `arcDeg`, `arcInnerDeg`, `arcMethod`, `sectionRatio`, `ventralFlat`, `shapeQuality`,
    `shapeSource`, `naturalMm`, `baseRadiusMm` y `curve`) y `block`; `shape`; `damage.breaks` y `lastBreak` (`sMm`, el
    trozo con su perfil y el tipo de rotura); y `surface` (`ra_um`, `burn`, `chip` y `scratch_deg` por estación).
  - **En `ClawCareState`:** `patient`, `history` (todas las llamadas del ensayo), `probe_tip()`, `reforge_request()` y
    `reforge_with()` (solo si la garra ya no sangra; va marcado como FICCIÓN, con lo que se hace de verdad, salvo el
    acrílico de la prótesis de verdad desde la 5j). Valida el material contra `Catalog.INLAYS`: el rubí y la alúmina se
    eligen en la cetrería.
  - **En `CareData`:** `CLAW_SHAPES` y `claw_shape(claw, digit, hind)` (largo, alto de la base, arcos y sección de cada
    dedo; las rapaces, dedo a dedo, de Fowler et al. 2009), `CLAW_ARCS` y `claw_arc(claw, digit, hind)` (una sola fuente
    del arco de todas las garras, también para la galería y el coche) y `SURFACE`.
  - **En `ClawForge`:** `care_setup(from_care)` pasa el rubí y la alúmina con su id y, con `stump_mm`, el muñón con el
    bloque en bruto.
  - **El consejo del calor** habla de la herramienta giratoria usada (el torno o la amoladora).
  - **Página:** el botón «Probar la punta» y la tecla T.
  - **Queda:** los dedos del tigre y del oso dedo a dedo y sus patas traseras, la sección medida de las garras (salvo la
    del velocirraptor) y la rugosidad medida de una garra limada.
- **La garra rota que vuelve de la reforja (5j, unida).** Guía en `docs/fisica/cetreria.md` §7 y §11.11.
  - `ClawCare.supports_block(id)`: los materiales del banco y el acrílico de la prótesis de verdad
    (`ForgeData.PROSTHESIS`). `setup.block.material` acepta los dos; la punta del acrílico aguanta con su resistencia.
  - **El calor de limar el bloque:** `ClawCare.block_thermal(material)` da su conducción, ρ·c, la difusividad, su tope
    (se funde, se ablanda o se oxida al aire) y la fuente; `{}` si su ficha no trae la conducción (la hematites), y
    entonces se cuenta como la queratina.
    - Cada nodo del modelo térmico lleva el material de su sitio; entre dos materiales, en serie; hasta dónde llega el
      calor, con el largo equivalente L·√(α_queratina/α_bloque); cada nodo con el tope de su material (suceso
      `bloque_calor`).
    - Sin bloque, el modelo da exactamente lo mismo que antes. El reparto del calor (ε) y la fricción siguen siendo los
      de la queratina (dicho en la guía).
  - **En el `snapshot()`:** `claw.block.thermal` y `thermal.blockHot`.
  - **En `ClawCareState.view()`:** `reforge_request`, el de `reforge_request()` si la garra elegida está rota y sin
    reconstruir, y `{}` si no.

### El limado según la dureza y la abrasión (5l, unida; petición 38)

- **Motor (`ClawCare`):**
  - `ClawCare.new(setup, patient, kit)`: `kit` es el `ClawCareKit` del animal (`core/lab/claw_care_kit.gd`), que comparten
    todas sus garras y el historial. `kit()`, `tools()` y `renew_tool(id)` (una nueva de la bandeja).
  - `file()` da además `rubbing`, `mu`, `regime` (`ductil` o `fragil`), `toolEdgeUm`, `toolWearMm3`, `toolState` y
    `debris` (lo que sale: polvo, limaduras o virutas, con su color, su tamaño y cómo cae). `heatW` ya no es 0 cuando una
    giratoria roza sin morder (P = ε·μ·F·v con el μ de la pareja), y `raUm` es la rugosidad que queda.
  - `clip()` da además `forceN` y `capacityN`: el cortaúñas corta si la mano por su palanca llega a la fuerza de cizallar
    la sección (dúctiles τ = σ/√3; frágiles τ = σ).
  - Sucesos nuevos: `roce`, `herramienta_gastada`, `herramienta_nueva` y `no_corta_fuerza`.
- **Desgaste de las herramientas:** Archard con la razón de durezas al revés (ρ = H_garra/H_herramienta), K(ρ) de 0
  (ρ < 0,381) al suave y al severo de Pintaude 2009; el volumen gastado redondea los filos y ese radio entra en el arranque.
  Con el doble de radio, embotada o vidriada.
- **Datos (`CareData`):** en `TOOLS`, `face_mm`, `face_source`, `band_mm` y `lever`; nuevos `TOOL_WEAR`, `RUB_FRICTION`,
  `CLIP_FORCE`, `DEBRIS_KIND`, `DEBRIS_COLOR`, `SPARK_MATERIAL`, `AIR_VISCOSITY` y `SRC_STOKES`.
- **Estado (`ClawCareState`):** `kit`, `renew_tool` y `fmt_mm3`; `view().tools` y `tools_serial`; `hand.wear` y
  `hand.worn`; `tray[].wear` y `tray[].state`; el efecto `dust` lleva `debris`, `rubbing` y `heatW`; el efecto `renew`; y
  `sound.rasp_squeal` (el chirrido de lo que roza sin morder).
- **Fuera de la cetrería:** `core/taller/sparks.gd` tiene las familias `metal_duro` y `titanio_cp` y los materiales
  `titanio-cp`, `metal-duro` y `oro` (sin chispas); las firmas de antes no cambian. `care_runner.gd` lleva la orden
  `renew_tool`, y `CareFx.spawn` el rozamiento de cada partícula (`drag_k`).
- **La escena:** el polvo de los frágiles como una nube que baja despacio, las limaduras de su color, la lima embotada que
  brilla y el grano vidriado en la tira que ha trabajado (`abrasive.gdshader`); el botón «Una nueva (N)».
- **Demo:** `demo_cetreria.tscn -- --caso=11` (el limado según la dureza sobre el zafiro) y `--caso=12` (las chispas de
  cada metal). Tests en `tests/lab/test_claw_care_limado.gd`.
- **Pendiente:** las grietas laterales de los frágiles (sin constante medida: el arranque frágil es una cota baja), el
  embotamiento por material pegado, el calor de una garra reforjada entera, las palancas de los cortaúñas medidas, el número
  de chispas según lo arrancado, y el coste en el teléfono de `test_care3d`, que roza los 4 ms con la máquina cargada.

### La cetrería en alta definición y la superficie de la garra (peticiones 35 a 37, en marcha)

- **Modelos propios de la cetrería.** La cetrería deja de usar los modelos del coche en marcha (`app/lab/animals/`, 4l)
  y tiene los suyos, hechos desde cero y en alta definición, para verse de cerca (petición 37):
  - las patas, los dedos y las garras de cada animal (5h), lo que se ve en primer plano;
  - los cuerpos enteros (5i, después de la 5h), enganchados a las patas por los anclajes que fije la 5h.
  - El coche en marcha sigue con los suyos: nada de la cetrería cambia el coche.
- **La superficie de la garra cambia con cada pasada** (petición 37): se degrada o se pule según la herramienta. Es un
  contrato entre tres partes:
  - **El motor (5g):** `ClawCare.snapshot().surface`, por estación de `STATION_MM` a lo largo de la garra:
    - `ra_um`: la rugosidad media (Ra, µm) que deja la última herramienta en cada estación, con su fuente o como
      estimación;
    - `burn` (0-1): el quemado, de la temperatura máxima frente a `THERMAL.char_c`;
    - `chip` (0 o 1): un desconchón o una grieta;
    - `scratch_deg`: la dirección del rayado de la última pasada (0-180°, respecto al eje de la garra).
    - La regla: una herramienta más fina pule hacia su propia Ra a medida que quita material; una más gruesa la vuelve a
      rayar enseguida; el calor quema y la herramienta equivocada desconcha.
  - **La escena (5h):** pasa `surface` a la malla de la garra como una textura 1D a lo largo de `s`, como `heat_tex`.
    - Uniforme `surface_tex` (RGBA8, una columna por estación) y `surface_range` = (0, largo en mm).
    - R = log₁₀(`ra_um`/0,01 µm)/log₁₀(5000), recortado a [0, 1] (`ClawMaterial.surface_r` y su inversa `surface_ra`: en
      8 bits se distinguen los pulidos finos), G = `burn`, B = `chip`, A = `scratch_deg` / 180.
    - La textura la hace siempre `ClawMaterial.surface_image(estaciones)` y se pone con `set_surface(mat, textura,
      largo)`; `surface_range` = (0, 0) es «sin superficie» (la del acabado).
    - Se actualiza cuando cambia el `snapshot`, no en cada fotograma.
  - **El material (5e):** lee `surface_tex` en la queratina y en cada material reforjado.
    - R da la rugosidad (de pulido espejo a mate) y la fuerza del rayado en la dirección de A.
    - G oscurece y apaga el brillo (quemado). B rompe la normal (facetas del desconchón).
  - Si una unidad necesita cambiar este reparto, lo pide en su informe y el coordinador lo cambia aquí.

## Materiales de las garras (5e, unida)

- **Datos ópticos** (`core/lab/claw_optics.gd`, `ClawOptics`), cada uno con `source` y `quality`. Guía en
  `docs/fisica/materiales-garras.md`.
  - Metales: el F0 de cada uno desde su índice complejo medido, con integración espectral (CIE).
  - Gemas y vidrios: el índice por canal y por rayo, el fuego (B-G), la birrefringencia, el ángulo crítico y la absorción
    (Beer-Lambert) del rubí, el zafiro y el vidrio.
  - Acabados con su σ: `finish_from_forge`, `finish_from_care` y `forge_surface`.
  - `KERATIN_COLORS` y `keratin_color(id)`: la única fuente del color de la queratina de cada especie, para la cetrería,
    el coche y la galería.
- **La biblioteca** (`app/common/claw_material.gd`, con `claw_material.gdshaderinc`, `claw_solid.gdshader`,
  `claw_gem.gdshader` y `claw_geo.gd`):
  - `ClawMaterial.material(id, acabado, opts)` construye cada material una vez por clave (material, acabado, calidad,
    entorno, color y superficie) y lo reutiliza; en cada fotograma no se crea nada (con su test).
  - También: `params` y `apply`, `for_forge(result_claw)` (el material y el acabado de una garra de la reforja con una sola
    llamada), y `surface_image`, `set_surface` y `clear_surface` para la superficie de la cetrería.
  - Funciona en Forward+, Mobile y Compatibility. La calidad «movil» usa el sombreador opaco, sin leer la pantalla.
  - **Convención de malla:** UV.x = s en mm, UV.y = la vuelta (0 arriba), UV2.x = radio en mm y UV2.y = largo de la garra
    en mm. Para otra malla, `uv_mode` = 1.
  - **Prohibido usar `instance uniform`** en las garras: en Compatibility cada malla que los usa reserva 16 huecos de un
    búfer de 4096. `claw_fade` es un uniforme del material: quien desvanece usa su propia copia.
- **En el coche en marcha:** `Animal3D.set_claws(natural, material, color, env := "")`, con la malla de
  `ClawGeo.model_claw`.
- **Galería:** `app/lab/demo_materiales.tscn` (10 páginas: todos los materiales, gemas y metales de cerca, los tres estados
  de la superficie, los acabados de la reforja, la garra de cada animal y la lupa del coche).
- **Coste:** 0 µs de CPU por fotograma en la biblioteca; el aspecto se pone solo al cambiar de garra o de material.
- **Pendiente:**
  - el arco de cada garra ya tiene una sola fuente (`CareData.claw_arc`, 5g) y la galería la usa (`ClawGeo.spec_of`); las
    mallas del coche en marcha (las especies de `app/lab/animals/`) todavía usan su fórmula (180°·curva^1,6);
  - con el techo oscuro de la nave de la cetrería, un metal pulido refleja casi negro (lo arregla la 5h con una sonda de
    reflexión o un techo más claro);
  - el fuego de las gemas se ve poco con el entorno de ahora.

### La garra en primer plano y las patas en alta definición (5h, unida)

- **Por qué se veía mal en la Beta 3:** la vista de partida era «General»; se usaban los modelos del coche (hechos para
  verse de lejos); la página creaba la escena con la calidad del teléfono (medía 301 px de ancho antes de colocarse); y
  la luz era plana, con el techo del cielo oscuro (los metales pulidos reflejaban negro).
- **Cámara:** la vista de partida es «La garra» (de cerca, en tres cuartos y algo desde arriba), con una transición suave al
  cambiar de pata o de dedo; la rueda llega hasta ~8 mm de la punta. El animal entero es una vista aparte. La página elige
  la calidad de la escena por el ancho de la ventana (`_scene_quality()`) y la sigue al cambiar de tamaño.
- **Luz y efectos** (`care_stage.gd`, con su test): luz de tres puntos para la garra, la pata y las herramientas; en
  Forward+, SSAO, SSIL, desenfoque del fondo, brillo y sombras suaves; en Mobile y Compatibility, sus sustitutos (niebla
  que oscurece el fondo, viñeteado y la oclusión horneada en los vértices); una sonda de reflexión centrada en la pata
  (salvo en Compatibility y en el teléfono).
- **Patas hechas desde cero** (`care_paw.gd`, `care_kit.gd`, `paw_skin`, `paw_fur` y `care_cloth`): las rapaces con
  escamas, almohadillas con papilas, el tarso emplumado y el color de cada especie; el tigre con pelo en capas, rayas,
  almohadillas negras, la vaina y el espolón; el oso con pelo en capas y almohadillas negras; el velocirraptor con el dedo
  II levantado, escamas y plumas (el de película, sin plumas). Dos niveles de detalle (el de primer plano hasta 0,75 m) y
  una caché por especie, lado y calidad. Los cuerpos enteros, desde la 5i, en alta definición (abajo).
- **La forma de cada garra** (`claw_mesh.gd`): sección de superelipse con normales analíticas (40 segmentos; 20 en el
  teléfono), con el arco y la sección del motor (`arcDeg`, `sectionRatio`, `ventralFlat`). **Convención de la sección:**
  alto = 2·r·√k y ancho = 2·r/√k (conserva el área de la física), con la cara de abajo en proporción. El bloque
  reforjado en bruto (`claw.block`) se pinta con su propio material. API: `claw_curvature`, `section_of` (con `h`),
  `section_reach`, `split_profile` y la malla `block`.
- **La forma que cambia con cada pasada:** la malla sale del perfil de `ClawCare` cada vez que cambia; la silueta de la
  forma sana va a trazos (tecla F); el indicador de la forma (`care_gauge.gd`) lleva las lecturas y el veredicto de
  `snapshot().shape`; el trozo que se corta se separa y cae (de `damage.breaks`), y las grietas y la sangre se ven.
- **Escena** (`care_3d`): `set_ghost`, `toggle_ghost`, `stage_info`, `render_method`; en `info()`, `ghost`, `pieces`,
  `piece_falling`, `piece_span`, `block` y `surface_px`. La capa de enfoque es la 4. El estado (`care_runner`) da
  `v.surface_img`, hecha en el hilo y solo cuando cambia la superficie.
- **Anclajes de las patas, para los cuerpos (5i):** `CareAnimal.build(...)` devuelve `rig.anchors`, `{ pata: Transform3D }`
  en el marco de la raíz del animal, con los nombres de `ClawCareState.paws_of(animal)`.
  - La raíz está en la mesa (y = 0), con las patas hacia +X (el borde de la mesa), la cabeza hacia −Z y el lado derecho
    del animal arriba.
  - El anclaje está en el talón (rapaz y velocirraptor: el tarso es de la pata) o en el codo o la rodilla (tigre y oso:
    el antebrazo y la pierna son de la pata).
  - El +X de cada anclaje va del cuerpo hacia la pata; el miembro del cuerpo llega al anclaje por −X.
  - También trae `rig.paws` (el centro de cada pata), `rig.box` y `rig.slots`. La 5i sustituye a
    `CareBody.build(parent, animal, art, anchors, opts)`.
- **Coste:** 1,3-2,1 ms de media por fotograma en escritorio limando (máximo 5,8 ms al rehacer la malla); construir el
  animal la primera vez, ~370 ms en escritorio, y desde la caché, 8-9 ms.
- **Pendiente** (en `docs/fase2/encargos/pendientes.md`): la base del velocirraptor sale muy gruesa (la estimación
  genérica del radio con la sección comprimida); `slots_view()` sin la forma de cada dedo; un contador `surface.serial`;
  el águila pescadora no está en el catálogo (sin espículas); y los añadidos de la 5c en `sleep3d.gd` y `Animal3D` ya no
  los usa la cetrería.

### Los cuerpos enteros en alta definición (5i, unida)

- **Diez cuerpos hechos desde cero** (petición 37), independientes de los del coche en marcha: las seis rapaces
  (`body_bird.gd`), el tigre y el oso (`body_mammal.gd`) y los dos velocirraptores (`body_dino.gd`), con `body_kit.gd`
  (el taller de mallas) y `body_props.gd` (la toalla con pliegues, la capucha de cuero con su penacho, la mascarilla y la
  pinza del pulsioxímetro). Sombreadores propios: `body_fur`, `body_feather`, `body_plumage`, `body_skin`, `body_eye` y
  `body_leather`.
- **API:** `CareBody.build(parent, animal, art, anchors, { mobile, cache, claw })` devuelve `root`, `head`, `kind`, `box`,
  `fresh`, `lids`, `eye_mat`, `breath_mats`, `head_size`, `props` y `under`. `set_sedation(body, sed)` y
  `animate(body, t, sed, flinch)` (la respiración lenta, los párpados y la pupila según la sedación, el respingo con el
  dolor) no crean nada en cada fotograma. Cada parte admite la opción `shell_mat`.
- **Medidas** (`core/lab/care_anatomy.gd`, con `source` y `quality`): el largo, la envergadura o el alto a la cruz y la masa
  de cada especie; el cráneo, el ojo y el pelo del tigre (Mazák 1981); el oso, con los machos de Yellowstone escalados a
  300 kg (estimación) y su pelo (Pasitschniak-Arts 1993); los velocirraptores, leídos de su ficha. Lo que es solo dibujo
  (las proporciones de la cabeza o del cuello) lleva `quality: "dibujo"` y no sale como dato. `care_animal.gd` ya no
  depende del coche en marcha (`MovingCar`).
- **El enganche con las patas de la 5h:** cada miembro llega al anclaje por −X y sigue como una manga que acaba con el
  grosor de la pata, sin juntura. Si cambia la geometría de las patas de la 5h, hay que ajustar `body_mammal._limb`,
  `body_dino._leg` y los muslos de `body_bird`.
- **Trampa de Compatibility:** el MultiMesh de las capas de pelo necesita `use_colors = true` con el color de instancia en
  blanco; si no, no se ve nada.
- **Coste:** 1,1-1,9 ms de media por fotograma limando en escritorio (como mucho 4,1) y 1,2-1,8 en el teléfono; construir
  un animal, 115-426 ms una vez por animal y calidad (1 ms desde la caché); 21 000-42 000 vértices en escritorio y
  8 400-12 300 en el teléfono. El coste de la GPU de las capas de pelo no se puede medir en la nube.
- **Demo:** `demo_cetreria.tscn -- --caso=10`, cada animal de lejos y de cerca. Tests en `tests/app/test_care_bodies.gd`.
- **Las cabezas (5n, unida; petición 48: cerrada antes de tiempo, porque lo importante son el cuerpo, las garras, los
  materiales y la reforja):** el oso, el velocirraptor de la reconstrucción y el tigre, con el cráneo medido de cada uno
  (`care_anatomy.gd`: el oso de Kodiak de Hall 1984, GIN 100/25 de Barsbold y Osmólska 1999 en `VELOCIRAPTOR_SKULL`, y
  Mazák 1981); los labios del velocirraptor tapan los dientes (Cullen et al. 2023); las rayas de la cara del tigre siguen
  la forma (`face_at` en `body_fur.gdshader`); la mascarilla en copa sale de la cabeza (`layout.mask`, `nose` y `face_q`).
  - **API nuevas:** en `BodyKit`, `profile_smooth`, `sample_smooth`, `warp` en `loft()`, `angle_at_y`, `angle_at_z` y
    `lip_line`; en `care_anatomy`, `head_draw()` (proporciones de dibujo en `HEAD_DRAW`, `quality: "dibujo"`) y las
    entradas descriptivas, que no salen en `rows()`.
  - **Demo:** `demo_cuerpos.tscn` (cada animal sin la página: `--animales`, `--planos=lejos,cabeza,perfil,frente,atrezo,
    mascarilla`, `--fotogramas` y `--registro`).
  - **Coste:** +1,6-2,1 % de vértices; construir el oso, 434 ms (8 ms por encima del tope de la 5i, dentro de la variación
    con la máquina cargada).
- **Pendiente:** el disco facial del búho real y de la lechuza (la 5i lo pinta de lado y los ojos quedan detrás: hace
  falta un disco de frente; los datos ya están en `care_anatomy.gd`), las escamas del velocirraptor de película de lejos,
  la manga del tigre y del oso, y del tigre, el blanco de dentro de la oreja visto desde arriba y la trufa algo redonda.

## Reforja experimental de garras (5d, unida)

- **La regla de oro.** La garra viva no aguanta el calor: la queratina se quema a ~230 °C (`CareData.THERMAL.char_c`).
  Todo lo caliente se hace aparte, como una funda, y se pega en frío, como una corona dental o la prótesis del pico de
  una rapaz. Lo que en la realidad no se hace va con `quality: "ficcion"` y dice qué pasaría de verdad:
  - el horno que lo junta todo (cada modo es una máquina real, pero ninguna las reúne);
  - recubrir la garra en el animal, con cualquier método;
  - verter un material fundido encima, que siempre quema la queratina.
- **Motor** (`core/lab/claw_forge.gd`, `ClawForge`): determinista, sin nodos y de la misma familia que `ClawCare`. La guía
  está en `docs/fisica/reforja.md` (§14, guía de integración).
  - **Crear:** `ClawForge.new({ animal, claw, recipe, cover_mm, wall_mm, humidity })`; desde la 5j, también `digit` y
    `paw` (la garra de ese dedo: `CareData.claw_shape`), `cover_frac` (en vez de `cover_mm`) y `stump_mm` (la garra rota:
    lo que queda de ella). `natural_mm()` da el largo natural de la garra de su dedo.
  - **Acciones, por etapas:**
    - `mix(gramos)`, `fire({ mode, temp_c, time_s, atmosphere, pressure_mpa, mold, methane })`, `choose(material)` y
      `heat({ temp_c, atmosphere })`;
    - `cool(medio)` y `carve({ abrasive, grain_um, force_n, speed_ms, coolant })`;
    - `protect({ barrier, thickness_mm })` y `coat({ method, target, time_s, cycles, material, cover_mm })`;
    - `bond({ adhesive, gap_mm })`, `polish({ abrasive, grain_um, sharpen })` y `check_load({ load_n })`.
  - **Lecturas:** `snapshot()`, `report()`, `result_claw()`, `care_setup()`, `stage()`, `events()`, `serial()` y
    `surface()` (5j: la superficie de la pieza tallada o pulida, la Ra de la última muela o del último grano con la regla
    de la cetrería, Ra = h/4, en `stations` para `ClawMaterial.surface_image`; `ok = false` en bruto, rota o con una capa
    sin pulir). `evaluate_carve` da `raUm` y `chip`; `polish_surface(...)`, la del pulido, con `ForgeData.PIECE_SURFACE`
    (estimación).
  - **Recetas, mandos y tutoriales:** `ClawForge.recipes()`, `ClawForge.controls()`, `tutorial(id)` (`horno`, una de las
    10 recetas, `acrilico`, `piedra` o `garra_viva`), `recommended(id)` y `do_step(paso)`. Cada paso lleva `title`, `text`,
    `source`, `check`, `done`, `action`, `args` y `mistake`.
  - **Datos** (`claw_forge_data.gd`): la ficha térmica de 14 materiales (con el calor específico `cp` en todos los que
    traen la conducción, 5j), el horno y sus 8 mandos, los polvos, las 10 recetas con sus márgenes y sus defectos, el
    enfriamiento, los abrasivos, las barreras, los recubrimientos y los adhesivos. Cada dato con `source` y `quality`.
  - **La funda de una garra rota** (5j): `sheath_geometry(claw, cover_mm, wall_mm, gone_mm, shape)` rehace maciza y sin
    pegar lo que falta y pega una funda hueca sobre lo que queda; da además `naturalMm`, `goneMm`, `stumpCoverMm` y
    `solidVolumeMm3`. Si la funda no llega a lo que queda, `bond()` da el defecto `sin_superficie`.
  - **La prótesis de verdad** (5j): `ForgeData.PROSTHESIS.acrilico` (el acrílico dental autopolimerizable, con la forma
    de `Data.INLAYS`, su resistencia y su tenacidad) y `prosthesis_entry(id)`; su ficha térmica, `MATERIALS.acrilico`
    (familia `polimero`, `route: "frio"`: no va al horno). `choose("acrilico")` lo mezcla; `care_setup()` lo devuelve como
    bloque sin ficción, con su `quality` y su nota.
- **La garra resultante** (`result_claw()`): `inlay`, `inBench`, `benchTwin`, `hv`, `E`, `densityKgM3`, `strengthMPa`,
  `kic`, `sheathMassKg`, `clawMassKg`, `finish`, `coating`, `bond`, `tipRadiusUm`, `sharpness`, `quality` y `fiction`.
  - **Materiales nuevos de la 2.0** (`ForgeData.NEW_MATERIALS`, con la forma de `Data.INLAYS`): `rubi` (corindón con
    cromo: la mecánica del zafiro) y `alumina` (CoorsTek AD-995).
  - **Acabados** (`ForgeData.FINISH_IDS`): `bruto`, `tallado`, `pulido`, `poroso`, `agrietado`, `astillado`, `quemado`,
    `oxidado` y `defectuoso`. Los lee la biblioteca de materiales (5e).
  - `care_setup()` pasa la garra a la cetrería: el rubí va como zafiro, su gemelo.
- **Sonidos:** `sfx_for(acción, resultado)` elige el id. Hay 7 nuevos por sintetizar y hornear (`ClawForge.SFX_FORGE`:
  `forja-muela`, `forja-horno`, `forja-llama`, `forja-induccion`, `forja-prensa`, `forja-colada` y `forja-temple`); los
  demás son los del laboratorio.
- **Rendimiento:** `coat()` sobre la garra viva integra hasta 4000 pasos por vía. Es una llamada por acción, nunca por
  fotograma.
- **Tests:** `test_claw_forge.gd` (invariantes y determinismo), `test_claw_forge_recipes.gd` (cada receta con su
  tutorial da el material, y fuera de margen sale su defecto) y `test_claw_forge_spec.gd` (los 23 casos de
  `tests/fixtures/spec/reforja.json`, con el cálculo a mano).
- **Pendiente** (en `docs/fase2/encargos/pendientes.md`):
  - ~~`rubi` y `alumina` en el catálogo 2.0, en `ClawMass`, `ClawFracture`, `ClawSharpness` y `ClawCare`~~: hecho por la
    5g. En el coche en marcha llegan enteros desde el estado (`MovingCarState.inlay_param`), porque `MovingCar` no puede
    precargar el catálogo;
  - ~~la escena 3D del horno y la reforja~~: hecha por la 5f.

## Reforja en 3D: el laboratorio experimental de la cetrería (5f, unida)

- **Dónde está:** dentro de la página de la cetrería, con el interruptor «Trabajo veterinario | Laboratorio experimental
  (reforja)». La invitación de la primera vez se recuerda con `[lab] forge_intro`.
- **Estado sin nodos** (`core/lab/claw_forge_state.gd`, `ClawForgeState`): cada gesto es una llamada de `ClawForge` (un
  test lo comprueba repitiéndolas en otra `ClawForge`).
  - La balanza vierte a 4 g/s, o gota a gota a 0,1 g/s. Los mandos tienen pasos y topes y no se mueven con el horno en
    marcha; la marcha va a cámara rápida y enseña lo que el motor ya ha decidido.
  - La vista (`view()`) da los textos con números (con `Js` y `Format`), el error con su explicación y el paso del
    tutorial que lo arregla, la ficha antes → después, `labels`, `values`, `piece.look` y `care` (con el bloque).
- **Color de lo caliente** (`core/lab/incandescence.gd`, `Incandescence`): cuerpo negro de Planck con el observador CIE
  1931 (ajuste de Wyman 2013), en sRGB; las palabras del color, de TM 9-237. El color es `primary`; la compresión del
  brillo, dibujo.
- **Hilo** (`forge_runner.gd`, con doble búfer como `care_runner`): la vista, recubrir la garra viva (~20 ms) y las mallas
  de la garra (la de la cetrería, `claw_mesh.gd`) y de la funda.
- **Escena** (`app/lab/cetreria/forge_3d.gd`): `show_view`, `set_view`, `advance`, `handle_pointer`, `hit_at`,
  `target_screen_point`, `info` y la señal `gesture`. Seis vistas: General, La balanza, Horno, Dentro, Taller y La pieza.
  - El horno, marcado como FICCIÓN en conjunto, con sus 8 mandos y el margen de la receta en verde; cada máquina en marcha
    (la llama de Verneuil y la bola, la bobina y el crisol, la prensa HPHT, el plasma de la CVD, el sinterizado y el
    temple); el taller (la muela, la pulidora, la barrera, la pistola, la campana de vacío, el baño de cromo, la jeringa
    y la pesa) y el termómetro de la carne viva, con su rótulo FICCIÓN y el color que da el motor.
  - Las piezas usan la biblioteca común (`ClawMaterial.material` y `for_forge`); al rojo, la variante opaca con una capa
    aditiva del calor. En cada fotograma no se crea nada (con su test).
- **Página** (`forge_page.gd`): `setup`, `open_with`, `step`, `inset_right()` y las señales `back_requested`, `to_care`,
  `to_bench` e `intro_done`. 14 tutoriales (el horno, las 10 recetas, el acrílico dental, la piedra comprada y la garra
  viva, ficción), las tarjetas de las recetas (con la forma de la funda: capuchón, funda, funda larga o prótesis entera, y
  su pared; la tarjeta puede traer `tag`), la balanza, el horno, el taller, las lecturas, la ficha, «Valores y fuentes» y
  los sucesos.
  - En el teléfono, la escena encuadra cada vista a la izquierda del deslizador grande (`Forge3D.set_inset_right(f)`, con
    la fracción que da `inset_right()`): el panel del horno se ve entero (5j).
  - `look_view` lleva también `surface` (la de `ClawForge.surface()`, que la escena codifica con
    `ClawMaterial.surface_image` y `set_surface`, una textura por superficie) y `tint` (el color de dibujo de un material
    que la biblioteca aún no tiene, como el acrílico: se pinta como la queratina con ese color).
- **La garra rota:** «Reforjar con material» lleva la garra rota al laboratorio (sale con la forma «Prótesis entera»);
  hecha y enfriada la pieza, «Pasar a la cetrería» llama a `reforge_with(ClawForge.care_setup(from_care))` y vuelve como
  bloque en bruto. Si aún sangra, la cetrería pide parar la sangre primero.
  - **La vía real (5j):** con la garra rota (y solo entonces), «Qué quieres hacer» y el tutorial ofrecen el acrílico
    dental, la prótesis de verdad, junto a las recetas de fantasía. Se mezcla sin horno (`choose("acrilico")`, la tecla L o
    el estuche de la mesa de la balanza, sitio `acrilico`, gesto `choose_stone(["acrilico"])`) y vuelve como bloque sin
    ficción (`block.fiction = false`, `quality: "estimate"`: la técnica es la del pico de las aves). Los demás bloques
    siguen como FICCIÓN (`quality: "ficcion"`) y su nota remite a la vía real.
  - La prótesis se hace con lo que queda de la garra (`from_care.stump_mm`) y para la garra de su dedo y su pata: la
    escena la dibuja hasta la punta natural.
- **Mandos:** ratón (coger un tarro y verter, arrastrar los diales, clic en los botones y en el taller), teclado (A/D el
  mando, W/S girarlo, Intro arrancar, Espacio acabar la marcha, E enfriar, L cargar, T/B/R/U/O/K el taller, P lo
  recomendado, N el paso siguiente, V la vista, H la ayuda) y teléfono (tocar, botones de la balanza y un deslizador
  grande).
- **Sonidos** (`core/lab/sfx_forge.gd`, horneados con `bake_lab_extra.gd`, módulo «reforja»): `forja-muela`,
  `forja-horno`, `forja-llama`, `forja-induccion`, `forja-prensa`, `forja-colada` y `forja-temple`, por el bus «Lab». Es
  diseño de sonido, no datos. Lo que suena en la marcha sale de la máquina del modo del dial, no de la receta:
  `ClawForge.machine_for(modo, receta)` y `machine_sfx(máquina)` (5j); de ahí salen `sfx_for("fire")`, el bucle de la
  marcha y `ClawForgeState.loop_for`. `sfx_for("heat")` da el horno.
- **Coste:** 0,08-0,09 ms de media por fotograma en la escena; ~78 ms la primera vez que se abre el laboratorio.
- **Pendiente** (en `docs/fase2/encargos/pendientes.md`): que la página de la cetrería tome `from_care` de
  `view().reforge_request` (hoy lo rehace `_lab_setup()`), y los datos ópticos del acrílico en `ClawOptics` (hoy se
  pinta como la queratina con su color).

## Vista 3D del coche en marcha (4h, 4k y 4l, unidas)

- **Escena** (`app/lab/car3d/`; la monta `app/lab/moving_car_view.gd`): la luz, el cielo y los materiales físicos de la
  familia del taller. Lleva el preset de teléfono: menos segmentos, sin sombras y 120 partículas de aire en lugar de 320.
  Guía en `docs/fisica/coche-en-marcha.md` §9.6.
- **Coche** (`car_model.gd`, `car_shape.gd`, `mesh_kit.gd`, `curve_kit.gd` y sus shaders): una berlina tipo DrivAer hecha
  en código, con el aspecto de las cuatro carrocerías del catálogo. Se construye una vez (escritorio: ~130 ms y 23 164
  triángulos; teléfono: ~70 ms y 12 328). Los puntos de la física no se mueven (`ZONES.draw`, `TOP`, `PANELS` y
  `DOOR_DRAW`; lo vigila un test).
- **Viento** (`air_flow.gd`, `air_streak.gdshader`):
  - partículas por líneas de corriente y una estela con remolinos;
  - junto a la chapa van a v·√(1 − Cp) de cada zona: `MovingCarState.air_flow()` devuelve
    `{ alongKmh, crossKmh, airKmh, zones: [{ id, x, y, cp, factor, quality, source }] }`, sin nada nuevo que calcular;
  - es una ilustración, y el rótulo de la vista lo dice;
  - a 0 km/h o con movimiento reducido no se ve ninguna partícula.
- **Daños** (`car_damage.gd`, funciones puras, y `car_damage.gdshaderinc`): van en los propios shaders, no con `Decal`,
  porque el renderizador Compatibility no pinta los Decal.
  - Todo sale de `impact()` y `hold_report()`, a escala real: surcos del color de la capa más honda que cortan, ranuras
    del plástico, tajos, agujeros con pétalos, la abolladura que hunde la malla, las estrellas del parabrisas laminado y
    `defense.tear`.
  - Se acumulan hasta 3 golpes dentro del ensayo y se borran al cambiar de ensayo.
  - La ventanilla templada que estalla lee `impact().sideWindow` (la física, de la 4m).
- **Lupa:** una segunda cámara enseña de cerca el daño más fino del último golpe, con su aumento y su barra de escala.
  Sale cuando el animal toca el panel y va en la esquina de arriba del lado contrario al golpe.
- **Animales:** la vista llama a `Animal3D.build(id, posture, size_m, opts)` y usa `root`, `fit_box`, `anchors`,
  `pose(p)` y `set_claws(...)`.
  - **Opciones:** `sex`, `quality`, `cache`, `pitch_deg` y `variant` (la de `draw_size().variant`). Al cambiar de variante
    se rehace el animal.
  - **Pose:** lleva `wind_local_ms` (m/s reales junto al animal), `slowmo` (0,1) y `kick` (0–1), este también en el
    salto de los velocirraptores.
  - **La raíz del animal es de la vista:** la coloca, la gira y le suma lo que la pose ponga en `root.position.y` o
    `root.rotation.z`. Los nodos visibles van en la capa `ANIMAL_LAYER` (2).
  - **`art_id(id)`:** mientras una especie no tenga dibujo propio, la vista usa el de otra con su variante. Desde la 4l,
    las once especies tienen el suyo.
  - **`leap_arc(leap, car_kmh, feet_y)`:** los que saltan llegan a un panel de arriba con el final de su salto, la
    parábola de `leap.ux − v` y `leap.uz`; contra un costado, con la carrera.
- **Animales en 3D de verdad (4l)** (`app/lab/animals/`; guía en `docs/fisica/coche-en-marcha.md` §9.6.1 y §9.6.3):
  - **Mallas** (`loft.gd`): secciones de la anatomía en cm barridas a lo largo de cada pieza, con normales suaves y
    casquetes en las uniones. Garras, picos y dientes son conos curvos de queratina.
  - **Esqueleto** (`rig3d.gd`): un nodo por hueso, no `Skeleton3D`. Las posturas son giros de los huesos, con cinemática
    inversa de dos huesos en las patas.
  - **Materiales** (`mats3d.gd`, `tex3d.gd` y los shaders `animal_*`), todos hechos en código: plumas, pelo con capas en
    el contorno, escamas, queratina, ojos y los patrones de cada especie. Desde la 5e, las garras usan la biblioteca de
    materiales (la queratina de cada especie o el material reforjado, con su luz real) y su malla sale de
    `ClawGeo.model_claw` (en mm, con el largo del catálogo y la curva y la sección de cada especie); melladas, partidas o
    dobladas, con trozos.
  - **Especies:** `birds3d.gd` (las seis rapaces), `mammals3d.gd` (tigre y oso), `cassowary3d.gd` y `theropod3d.gd` (los
    dos velocirraptores; el de cine, con un diseño original).
  - **`AnimalArt` se queda con** `KINDS`, `POSTURES`, `has_art`, `kind_of`, `postures_of`, `fit_scale` y
    `Theropod.variant_of(opts, id)`.
    - Se han borrado `animal_flat`, `animal_rig`, `raptors`, `mammals`, `cassowary`, `theropod` y `brush`, y las funciones
      `build`, `spec`, `fit_box` y `lod_for` de `AnimalArt`.
  - **Cajas:** en los velocirraptores, `fit_box` llega hasta la cadera, como en la 4h, y `full_box` abarca el animal
    entero. `claw_points()` da dónde están ahora las puntas de las garras.
  - **La pose no toca la raíz:** todo lo que se mueve son nodos interiores, creados en `build` y ya en `ANIMAL_LAYER`.
    Usa `kick` también en el salto, y `slowmo` para el ritmo del aleteo y del aire.
  - **Caché:** el modelo se hace una vez por especie, sexo, variante y calidad.
    - Construcción: 40-170 ms la primera vez y 4-11 ms con la caché.
    - Pose: 40-90 µs por fotograma.
    - Vértices: 9 600-16 600 en escritorio y 4 700-7 900 en el teléfono.
    - En cada fotograma no se crea nada (lo vigila `tests/app/test_animal3d.gd`).
- **Rendimiento:**
  - arrastrando la velocidad, ~2 ms de media en el hilo principal (el dibujo, ~0,3 ms);
  - los daños de un golpe se construyen en ~0,6 ms;
  - la escena quieta no se vuelve a renderizar;
  - en cada fotograma no se crea nada (lo vigila un test, `tests/app/test_car3d.gd`).

## La punta al empezar y la punta según su material (5s, unida)

- `ClawCare.configure`: `setup.tip_start` ∈ {"roma","natural","afilada","aguja"} (`CareData.TIP_STARTS`, `TIP_START_IDS`).
  "natural" o ausente es la garra de siempre, al bit. Cambia el perfil, el vértice, el radio de la punta (ratio × natural)
  y su semiángulo (`alpha_k`), sin bloque.
- `ClawCare.snapshot().claw.tipStart`: la punta con la que empezó la garra.
- `ClawCare.tip_material()` → `{ reforged, id, name, behavior («queratina» | «ductil» | «fragil» | «sin_datos»), strength, hv }`.
- `ClawCareState.set_tip_start(id)`: ensayo nuevo con esa punta en todas las garras (`care_setup` añade `tip_start` solo si
  no es la natural); op del hilo: `"set_tip_start"`.
- `ClawCareState.texts().tip_start` / `tip_start_text()`: la nota de la punta al empezar (radio, fuerza para pinchar ∝ R²,
  aguante de lado, comportamiento del material, Dp).
- `CareData.claw_shape(...).growthRatio` / `growthQuality` / `growthSource`: lo que crece esa garra frente a la ficha del
  animal (patas traseras del tigre 0,08/0,13; el resto 1). `care_setup` añade `overgrowth_mm` solo si `growthRatio` ≠ 1.
  Se memoriza por animal, garra, dedo, pata y días: `care_setup` se pide por cada garra en cada vista.
- `SharpenHelp.tip_character(care)` → `{ behavior, verb, materialName, lateralN, strengthRatio, strengthMPa, kind, dp, mode,
  modeText, text }`; `SharpenHelp.meter(...).character`.
- **Rendimiento:** las mallas de las garras que no se trabajan se reutilizan de una vista a otra mientras no cambian
  (ensayo, forma, trabajada o rota).

## Las garras en los cristales (4v, unida)

Petición de Eric del 18-10. Guía en `docs/fisica/coche-en-marcha.md` §24.

- **Motor:** `core/lab/car_glass.gd` (`CarGlass`).
  - `scratches`, `trace_kind` y `glass_scratch`: rayar pide r ≥ 1,25 (`R_SCRATCH`, el de la lente de la cetrería); por
    debajo, «mancha» o «trazo» del metal.
  - `rear_window` y `tempered_hold`: la luneta, entera o estallada; `view_loss`: lo que tapa la grieta (estimación).
  - `cutaway` y `glass_cut`: el corte del vidrio; textos `rear_verdict`, `rear_row`, `view_txt` y `trace_txt`.
- **Zona `ZONES.luneta`** (vidrio templado). `setup()` añade `rearWindow` (si estalla, `mu`, el anclaje y la fricción valen
  0), `windshield.viewLoss` (también en `impact()`) y `scratch.trace` / `scratch.ratio` en el vidrio; `detach_verdict` dice
  «ESTALLA LA LUNETA…».
- **`CarSpeedMarks`:** `rear_cumulative` (la luneta no se recompone y solo estalla con el animal encima), el hito «estalla»,
  `rearAt` y, en `at()`, `rearWindow` y `rearShattered`.
- **Estado:** bloque «Cristales (unidad 4v)»: `on_glass`, `rear_now`, `glass_view_note(short)`, `glass_cut` y `glass_why`;
  `tear_now()` devuelve el corte del vidrio en un cristal; el primer plano lleva el veredicto de `CarTear`.
- **Vista** (bloques «Cristales (unidad 4v)»): `CarShape.LUNETA_PANEL` y `hold_panel`; `CarDamage.hold_cracks`, `hold_glass`
  y `shatter.luneta`; `car_glass.gdshader` con `shatter_luneta` y `tempered_craze`; `CarModel.set_luneta_shatter`,
  `luneta_shards_start` y `shard_floor`; `MovingCarView.glass_zone`, `exit_mode` «dentro» y `_luneta_aim`;
  `LayerCut.GLASS_TITLES`.
- **Demo:** `demo_curvas`, casos 9 a 12. **Tests:** `tests/lab/test_car_glass.gd` y `tests/app/test_car_glass_view.gd`.
- **Pendiente:** quedarse agarrado a una ventanilla lateral (hoy solo se llega en un golpe); en el corte del golpe, las
  garras de metal en el vidrio dicen «mancha» en lugar de «trazo»; comprobar el año y la revista de la fuente de lo que
  tapa la grieta.

## Encargos de veterinario y minijuegos (5v, unida)

- **`ClawCare.configure`:** `setup.broken_start` ∈ {"fresca","muñon"} (`CareData.BROKEN_STARTS`): «fresca», partida por
  dentro de la carne viva y sangrando; «muñon», por delante de ella. Sin la clave, la garra de siempre; una garra reforjada
  o con bloque no llega rota. `snapshot().damage.brokenStart`, `snapshot().bleeding.disinfected`, `broken_state()` →
  `{ broken, repaired }` y `shape().verdict` «reconstruida».
- **`ClawCareState`:** `setup.broken_start = { paw, digit, kind }` (el ensayo empieza en esa garra y el tutorial mete
  «sangrado» y «reconstruir»); `care_setup(p, d)` da `broken_start` solo a esa garra.
- **`VetProgress`:** `INITIATION` (en cadena, con `after` y `tutorial`) y `JOBS_5V` (`minigame` ∈ pulir | transformar |
  reparar | reforjar; `tip_start`, `broken_start`, `materials`, `ra_max_um`, `band`); `all_jobs()`; peticiones nuevas
  tutorial, largo, pulida, banda, reparada y pieza_material; `broke_here(j, s)`: la garra que se rompe en un encargo que no
  era repararla lo cambia a «reparada» y paga `REPAIR_PAY.frac` = 0,5 (juego).
- **`VetMinigames`:** `view(job, care_view)` → `{ kind, title, goal, progress, text, ok, warn }`; `tip_surface`, `in_band`
  y `BANDS` (ningún encargo pide «afilada»: no se alcanza con la resolución del motor).
- **Interfaz:** `care_page._bring_job` (aceptar un encargo lo trae a la mesa y abre su tutorial si es de iniciación);
  `CareProgressCard.paint_minigame` y `card_line`.

## Simulador de afilado (taller)

- **`core/taller/sharpening_machines.gd`:** máquinas reales de consumo (Vevor, Einhell…) y la de referencia
  (Tormek T-8), con `source` y `quality`. Cada una lleva:
  - su muela o disco montado de serie: abrasivo, grano, Ø, ancho y velocidad máxima marcada;
  - rpm en vacío y potencia;
  - húmeda o seca;
  - accesorios.
- **`core/taller/grinding.gd`:** física del amolado: fuerzas normal y tangencial, potencia, energía específica,
  caudal arrancado y reparto del calor entre la pieza, la muela, la viruta y el refrigerante.
- **`core/taller/edge_thermal.gd`:** temperatura transitoria del filo. Incluye:
  - conducción en la sección de la hoja o de la broca;
  - calor que entra por el contacto;
  - enfriamiento por aire o agua;
  - color de revenido y pérdida de dureza (Hollomon–Jaffe, con `sharpening_heat.gd`).
- **`core/taller/sharpening_sim.gd`** (oleada 2): el ensayo paso a paso para la interfaz, la escena 3D y el sonido
  (bisel que avanza, rebaba, temperatura, revenido, filo final y nota).
- `sharpening.gd` (recomendaciones) y `sharpening_heat.gd` (Hollomon–Jaffe) se mantienen y se reutilizan.
- **Hecho en la unidad 1b** (especificación en `docs/taller/afilado-simulador.md`, casos en `tests/fixtures/spec/afilado.json`):
  - `SharpeningMachines.view(id)` devuelve ya el diccionario de `set_machine`. Cada muela lleva su propio `rpm`, porque
    la combinada tiene dos giros, y `width_mm: null` si no hay dato.
  - `Grinding.grind(...)` devuelve fuerzas, potencia, calor a la herramienta, caudal, chispas y sonido, con 13 códigos
    de aviso.
  - `EdgeThermal`:
    - una instancia por sección de la hoja, paso ≤ 5 ms;
    - `combine()` junta las secciones en orden fijo;
    - en paralelo, `WorkerThreadPool.add_group_task(f, n, -1, true)`: con la prioridad baja por defecto no acelera.
  - Por encima de 723 °C la temperatura no vale: la interfaz dice «quemado». Las temperaturas llevan ±40 %.
  - Tipos de herramienta nuevos para la escena 3D: `hacha` y `cortacesped`; material de herramienta `metal_duro`.

## Rendimiento y multinúcleo

Petición de Eric: el programa y el motor físico bien optimizados, aprovechando la CPU multinúcleo (su equipo es un
Ryzen 9 7900 de 12 núcleos y 24 hilos) para que todo vaya fluido y sea fiable; y, al final, una revisión de
optimización para que los móviles de gama media-alta vayan fluidos.

- **`core/` es seguro para hilos.**
  - Funciones puras u objetos `RefCounted` con su propio estado.
  - Sin `static var` mutables. Una caché estática va protegida con `Mutex` o pasa a ser por objeto.
  - Nunca se accede al árbol de escena.
- **Paralelismo determinista.**
  - El trabajo pesado se reparte en bloques independientes con `WorkerThreadPool.add_group_task`: barridos, secciones
    de la hoja que se afila, rangos de anillos del torno, rasterizado de dibujos, horneado de sonidos…
  - Los resultados se combinan en un orden fijo. El resultado **no depende del número de hilos**, y hay un test que lo
    comprueba (1 hilo = N hilos, al bit).
- **La interfaz no se bloquea.**
  - La simulación rápida (×50) y los barridos corren fuera del hilo principal, con doble búfer.
  - La interfaz lee instantáneas y vuelve al hilo principal con `call_deferred` o una cola.
  - Desde un hilo de trabajo nunca se crean ni se tocan nodos.
- **Una tarea de `WorkerThreadPool` no retiene nada con estado.** Godot suelta cada tarea en el hilo que la ha corrido,
  y después de despertar a quien la espera: lo que retenga (un estado con señales conectadas a la interfaz) puede
  destruirse en ese hilo mientras el principal libera la interfaz. Así se cerraba la comparativa del banco (4n).
  - A la tarea se le pasa un Callable de método (una referencia débil) o una lambda que solo capture datos.
  - El objeto con estado lo guarda el hilo principal y lo suelta después de esperar la tarea (`RowsJob` de
    `compare_card.gd`; lo vigila `tests/app/test_compare_threads.gd`).
- **Presupuestos.**
  - Escritorio: 60 fps (16,7 ms por fotograma) con el torno a ×50 y la afiladora en marcha.
  - Teléfono de gama media-alta: 60 fps en las pantallas 2D y 30–60 fps en 3D con el preset móvil.
  - Pantallas quietas: sin gastar CPU (modo de bajo consumo del procesador cuando no hay nada animándose).
- **Medir antes de optimizar.** `godot/tools/bench.gd` (`npm run godot:bench`) mide las tareas calientes con 1 hilo
  y con N hilos. Guarda en JSON la CPU, el número de hilos, la versión de Godot, los tiempos por tarea y la
  aceleración, para que las mediciones se puedan repetir y comparar entre equipos.
- **Última oleada:** un ingeniero/a de rendimiento para el escritorio multinúcleo y otro para los móviles
  (compatibilidad con la gama media-alta, presets de calidad, batería y temperatura).

## Especificaciones y casos de referencia (los escribe el ingeniero físico)

- `docs/fisica/*.md` (laboratorio) y `docs/taller/*.md` (taller). Cada una recoge:
  - el modelo, las ecuaciones y los datos con fuente;
  - qué no predice;
  - la guía de integración para el ingeniero de software.
- `tests/fixtures/spec/*.json`: los casos de referencia que la integración tiene que cumplir.
  - Formato: `{ "id", "input", "expect": { campo: { "value" | "min" | "max", "tol" } }, "source" }`.
  - Los lee un test del ingeniero de software. Un caso que no se cumple se discute con el ingeniero físico: nunca se
    ajusta un número para que pase.

## Verificación

- `npm run godot:test`: datos del oráculo, importación y todos los tests. Falla si hay un fallo o si la salida
  contiene «SCRIPT ERROR» o «Parse Error».
- `npm run godot:capture -- res://ruta/escena.tscn --frames=120 --out=/tmp/x`: PNG + WAV con Movie Maker, bajo
  Xvfb si no hay pantalla. Se miran las imágenes y se analiza el WAV.
- La 1.x sigue en verde: `npm test` (121: 115 del motor y 6 del empaquetado) y `npm run audit` (603.228 ensayos,
  0 problemas).
