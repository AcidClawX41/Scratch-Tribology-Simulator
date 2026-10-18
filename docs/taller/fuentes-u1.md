# Unidad 1 · Física del laboratorio en GDScript

Port 1:1 del motor 1.x (`packages/core`, JavaScript) a Godot 4.7.2 para la sección **Tribología biológica** de la
V2. El motor JavaScript es el oráculo y queda congelado: este port no cambia ningún resultado de uñas, garras ni
colmillos.

| Archivo | Port de | Qué contiene |
|---|---|---|
| `godot/core/lab/data.gd` | `data.js` y `theme.js` | catálogos (`GEOMS`, `BASES`, `INLAYS`, `CLAWS`, `TARGETS`, `SKIN_LAYERS`…), la paleta `C`, `car_layers`, `claw_title` |
| `godot/core/shared/format.gd` | formatos de `physics.js` y `fmtLen` de `lab.js` | `fmt_f`, `fmt_j`, `fmt_p`, `fmt_depth`, `fmt_len`, `hv_bar`, `f_to_t`, `t_to_f`, `FMIN`, `FMAX` |
| `godot/core/lab/physics.gd` | `physics.js` | `MODEL`, `resolve_tool`, `compute`, piel, sólidos, chapa en pétalos, vidrio y veredictos |
| `godot/core/lab/lab.gd` | `lab.js` | logros, fichas, etiqueta del cuaderno, fundamentos, licencia, fuerza máxima y modo dual |
| `godot/core/lab/lab_state.gd` | `labState.js` | estado del banco sin React, con temporizadores deterministas (`advance(ms)`) |
| `godot/tests/lab/test_*.gd` | tests del motor 1.x | oráculo, catálogos, invariantes y estado del banco |

## Fuentes

**No hay valores nuevos.** Cada número de `data.gd` y de `MODEL` es el de `data.js` y `physics.js`, y su fuente es la
de [`docs/FISICA.md`](../FISICA.md): apartados 1 a 15, «Datos de materiales y seres vivos», «Estimaciones» y
«Fuentes». Los comentarios de los catálogos y del modelo se han copiado con sus citas.

| Parte del modelo | Fuentes (detalle en FISICA.md) |
|---|---|
| Punta esfero-cónica, Hertz y dureza (contacto compartido) | Johnson 1985; Tabor 1951 y 1954; Pintaude 2021; Richardson 1968; ASTM G171 |
| Multicapa (pintura sobre carrocería, laca sobre madera) | Jönsson y Hogmark 1984; barniz de coche: Vodnick 2006 |
| Piel por capas: punción, corte y desgarro | Davis 2004; Pereira 1997; Shergold y Fleck 2005; Knight 1975; Ankersen 1999; O'Callaghan 1999; Comley y Fleck 2010; Kim 2001; Aryeetey 2022; Van Ee 2000; Taylor 2012 |
| Espesor y rigidez de las capas de la piel | Sandby-Møller 2003; Egawa 2007; Gibney 2010; Stecco 2009; Iivarinen 2011; Šarabon 2019; Ní Annaidh 2012 |
| Uña y queratina (seca y húmeda) | Tohmyoh 2023; Farran 2008 y 2009; McKittrick 2012 (Bonser) |
| Colmillos (dentina, rotura a ~30 N, golpe) | Estrada 2026; Crofts 2019; Penning 2016 |
| Agarre de rapaces | Sustaita y Hertel 2010; Tsang 2019 |
| Abrasión, fricción y desgaste | Hokkirigawa y Kato 1988; Bowden y Tabor 1950; Archard 1953 |
| Adhesión | Johnson, Kendall y Roberts 1971 |
| Carrocerías y chapa en pétalos | Wierzbicki 1999; Atkins 1998; Hollomon 1945; Nippon Steel 2013; I-CAR 2012; voestalpine 2022; ArcelorMittal (EN 10130); Prillhofer 2014; Hirsch 2011; SABIC (Noryl GTX964W); GE Plastics 2007 |
| Vidrio de ventana | Young y Budynas 2002 (Roark); EN 572-1 (Saint-Gobain 2018) |
| Maderas | The Wood Database (dureza Janka) |

**Estimaciones** (las mismas de la tabla «Estimaciones» de FISICA.md; no son mediciones): fuerzas y golpes
(velocidad y masa) de los mamíferos, las ratites, las rapaces y la mano humana; semiángulos de las puntas; alcance
de garras y uñas; anchura de la garra en la base (0,15 × alcance; colmillos 0,04 ×); rigidez del tejido que golpea
(10 N/mm); umbrales de abrasión de la piel (1, 4 y 16 MPa; 5 pasadas para sangrar); dermis papilar (0,3 mm);
enganche de la garra (×(1 + 0,7·curvatura)); exponente de las pasadas (n^0,4); queratina húmeda (×0,2);
saturación de la eficiencia (r ≈ 2); chapa del coche clásico (0,9 mm); aleta de plástico (2,5 mm); σ0 de la
puerta de aluminio (157 MPa); ventana de 60 cm apoyada; Stiletto XL; gel UV, ABS y encimera de cuarzo.

`CONTRATOS.md` pide `source` y `quality` en cada entrada de catálogo, pero también que los del laboratorio tengan
**las mismas claves** que `data.js`, que es lo que comparan los tests del oráculo. Aquí manda lo segundo: las citas
siguen en FISICA.md. Si la V2 quiere enseñarlas en la ficha, la propuesta está en «Para el coordinador».

## Decisiones del port (semántica de JavaScript)

- **Números como double.** Todos los números de los catálogos van como float (`25.0`): en JavaScript todo número
  es un double, y así ninguna división se vuelve entera por accidente. Los 160 literales del catálogo y del modelo
  se han comprobado al bit contra V8.
- **Mismo orden de operaciones que el JS**, expresión a expresión: `1.5 * PI * R * 1e-3 * W` se evalúa de izquierda a
  derecha en los dos lenguajes. `x ** 2` se escribe `x * x`, que es exactamente lo que devuelve el `pow` de V8
  (fdlibm) con exponente 2; `t ** 3` sigue siendo `pow(t, 3.0)` (con t = 4 es exacto en cualquier libm).
- **Textos** con `core/shared/js.gd`: `toFixed` → `Js.to_fixed`, `${x}` y `String(x)` → `Js.js_num_str`,
  `Math.round` → `Js.js_round`, `Math.log1p` → `Js.log1p`. `Math.log(1 + x)` de `skinSeverity` sigue siendo `log(1 + x)`.
- **`undefined` ↔ null o clave ausente.** `pierces` vale null al rayar un sólido, `toolBroken` no existe en la piel y
  `fBreak` es null en las garras que no se rompen, igual que en el JS.
- **Verdad de JavaScript.** `truthy(v)` reproduce `!!v`, `||` y `&&` sobre valores falsos (0, "", null, NaN) e
  `is_true(v)` reproduce `v === true` (`scratched` vale true, false o "faint", y GDScript da error al comparar un
  texto con un booleano). `template_str(v)` es `${v}`: «undefined» para lo que falta.
- **Un caso donde el JS escribe «undefined».** Una hoja de vidrio que se rompe con una punta que la atraviesa llega
  a la rama «ATRAVIESA LA PUERTA» de `genericVerdict`, que interpola `target.thickness` (el vidrio no tiene):
  «de lado a lado (undefined mm de metal perforados)». Después, el veredicto «ROMPE EL VIDRIO» tapa ese texto, así
  que nunca se ve. El port escribe lo mismo con `template_str` en vez de dar un error de ejecución.
- **`{ ...a, ...b }`** → `_spread(a, b)` (copia superficial y `merge` con sobrescritura), en el mismo orden.
- **Conjuntos.** El `Set` de logros es un diccionario id → true, que conserva el orden de inserción como el `Set`
  del JS. `earn_badges` comprueba las condiciones en el orden de `earnBadges` (`BADGE_ORDER`), no en el de
  `BADGES`: el oráculo guarda `badgesAfter` en ese orden.
- **Constantes de otro script.** GDScript pliega `Data.GEOMS[3]` en una copia al compilar otro script: el valor es
  igual, pero no es el mismo objeto (`is_same` da false). Las entradas se comparan por valor (`==`) o por id, y
  así lo hacen los tests. `LAB_DEFAULTS` y `DUEL_CARS` van por índice (una constante no admite búsquedas). No se
  desplazan sin avisar: `test_data.gd` fija el orden y los ids de cada catálogo a los del oráculo y comprueba que
  siguen apuntando a las mismas entradas.
- **Estado del banco.** `setTimeout` pasa a una cola que avanza con `advance(ms)`, con la semántica del reloj
  simulado de node:test: el reloj salta al final del paso y disparan en orden de hora (y de alta) los vencidos.
  Donde el JS llamaba `play(id)` sin volumen, el port llama a `play(id, 0.7)` (`DEFAULT_VOLUME`): es el valor por
  defecto de `playSfx` en las dos apps 1.x, y así la fanfarria (0,5) conserva su equilibrio con el resto. El
  cuaderno se llama `notebook` porque `log` es una función de GDScript. Cada cambio emite la señal `changed`.
  `dispose()` cancela los temporizadores y da por terminado un ensayo a medio animar (en el JS el estado
  desaparecía al desmontar; aquí el objeto puede seguir vivo). `sfx_picker` se inyecta (lo escribe la unidad 2).

## Verificación

| Comprobación | Resultado |
|---|---|
| Golden (`lab-golden.json`): 40 escenarios con `result`, `toolLabel`, `damage`, `damageStage` y `badgesAfter` | 0 discrepancias |
| Muestra (`lab-sample.json`): 19.249 ensayos (resultado, etiqueta e informe de daños) | 0 discrepancias |
| Muestra: 442 fichas de garra, 1.534 `resolveTool` y 1.088 filas del modo dual (resultados, veredicto y longitudes) | 0 discrepancias |
| Catálogos y derivados (`lab-data.json`) | idénticos |
| Barrido completo de `audit.js` contra el oráculo (verificación local, no se versiona): 596.700 ensayos, los 31 desfases de la muestra | 0 discrepancias |
| `npm run godot:test` | 90 tests, 0 fallidos, sin «SCRIPT ERROR» |

**Diferencias de último bit de libm.** `Js.log10`, `Js.log1p` y `Js.cbrt` difieren de V8 en el último bit en 471
de los valores de `js-semantics.json`, y `pow`, `exp`, `log`, `tan`, `sin` y `cos` de glibc pueden hacerlo con los
de V8 (fdlibm). En el laboratorio solo afectan a números que se comparan con tolerancia (severidad, pasadas,
pétalos, laca de la puerta, rigidez del vidrio, geometría de la punta). **Ningún caso cruza un umbral ni cambia un
texto**: ni en el golden, ni en la muestra, ni en el barrido completo. No ha hecho falta ningún arreglo.

**Tiempo de `compute()` en GDScript** (Godot 4.7.2 sin ventana, contenedor de 4 núcleos compartidos):

| Ensayo | Media |
|---|---|
| Muestra del oráculo (19.249 ensayos variados) | ~0,71 ms con la máquina tranquila (~1.400 ensayos por segundo); ~1,0 ms con carga |
| Rayado o punción empujando | ~0,28 ms |
| Punción con golpe (integra la energía en 300 pasos y 40 bisecciones) | ~1,9 ms |

Un ensayo del banco cabe de sobra en un fotograma; el modo dual (6 u 8 ensayos) tarda de 5 a 15 ms.

**Tests.** `test_oracle.gd` y `test_invariants.gd` tardan ~22 s cada uno (~33 s con la máquina cargada). Las invariantes son las de `physics.test.js`
con los mismos mensajes. Las rejillas más caras, las que calculan golpes, usan menos puntas que las 88 del banco:
- continuidad de la punción: cuatro puntas (uña, uña de metal, gema de diamante y garra de tungsteno) en empuje
  contra todos los sólidos, y el casuario al golpe contra las chapas y la puerta de roble;
- golpe frente a empuje, contrato del resultado, clásico frente a moderno y perforar frente a atravesar: un juego
  representativo de 14 puntas (uñas, gemas, garras, colmillos y garras reforjadas).

Cada test lo dice en su comentario. El barrido completo lo cubre el oráculo.

## Para el coordinador

1. **Semántica de JS en `js.gd`.** `truthy`, `is_true` y `template_str` están en `physics.gd` porque no puedo tocar
   `core/shared/js.gd`. Son semántica de JavaScript: propongo moverlas allí y dejar en `physics.gd` un alias.
2. **Paleta única.** La paleta `C` del motor vive en `core/lab/data.gd` (el motor devuelve `vcol`), y
   `app/theme/palette.gd` repite sus 15 colores en `HEX`. Propongo que `palette.gd` lea `Data.C`, o mover la paleta a
   `core/shared/`, para que no haya dos copias.
3. **Añadir a CONTRATOS.md**: «las entradas de catálogo se comparan por valor o por id, nunca con `is_same()`» (ver
   «Constantes de otro script» arriba). Afecta a art y a la interfaz.
4. **Unidad 2 (sonido).** `LabState.new(play, sfx_picker)` espera `sfx_picker.call(res, target) -> String`, la firma de
   `sfx_for_result`. El campo `sfx` del golden no lo comprueban mis tests: puede comprobarlo su test con
   `Physics.compute()` de este port.
5. **Unidad 12 (interfaz del laboratorio).** API de `lab_state.gd`:
   - selecciones: `set_geom`, `set_base`, `set_inlay`, `set_claw` (null = uña), `set_tear_mode`, `set_method`,
     `set_strike`, `set_wet`, `set_passes`, `set_target`, `set_type`;
   - deslizadores sin clic: `set_force`, `set_length`, `set_passes_slider`;
   - modo dual: `set_dual`, `set_dual_car(slot, id)`;
   - ensayo: `run()`, y `advance(delta * 1000)` desde `_process`;
   - lectura: `phase`, `res`, `notebook`, `badges`, `count`, `params()`, `tool()`, `strike_j()`, `max_f()`,
     `dual_cars()`, más la señal `changed`;
   - al cerrar el banco: `dispose()`; para pausarlo (al cambiar de sección) basta con no llamar a `advance()`.
   El pie debe llamar a `Lab.license_note(version)` con la versión de la V2 (`application/config/version`).
6. **`source` y `quality` en el laboratorio.** Si se quieren en las fichas, propongo un diccionario aparte
   (`Data.QUALITY[id] = { source, quality }`) generado desde FISICA.md, sin tocar las claves de los catálogos que
   comparan los tests del oráculo.
7. **Tiempo de los tests.** Si el conjunto completo se hace lento en CI, las rejillas de `test_invariants.gd` pueden
   reducirse más sin perder cobertura del oráculo, que es la que garantiza los resultados.
8. **Instrucciones locales del proyecto** (el archivo de «Reglas de oro» de la raíz, no versionado). Su regla 1
   («la física vive solo en `packages/core`») es de la 1.x. Con la
   V2 hay un segundo motor, `godot/core/lab/physics.gd`, que tiene que dar lo mismo que el congelado. Propongo
   añadirle un apartado V2: `godot/` se rige por `godot/CONTRATOS.md`; un cambio de física se hace en los dos motores
   y se verifica con `npm run godot:test`, que regenera el oráculo si cambia `packages/core/src`.
