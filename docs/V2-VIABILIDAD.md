# Scratch Tribology Simulator 2.0 · Estudio de viabilidad

> Desde la fase 2 el programa se llama **Tribology Simulator & Industrial Workshop**. Este estudio conserva el nombre con
> el que se escribió; el estado actual está en el [README](../README.md) y en [`ROADMAP.md`](ROADMAP.md).

Estudio de la **V2.0.0**: un solo programa, hecho en **Godot**, con dos secciones:
- **Tribología biológica**: el laboratorio actual de uñas, garras y colmillos, sin cambiar ningún resultado.
- **Taller industrial**: fresas, brocas, torno manual y CNC con el dialecto Fagor 8055 T, radiales y afiladora, con
  un simulador de torno 3D con animación constante y sonido.

Acompaña al prototipo entregado en el ZIP (carpeta `godot/`).

> **Veredicto: viable.** Las dos secciones funcionan en un solo programa Godot, la tribología da los mismos resultados
> que la 1.x (comprobado contra su motor, dibujo a dibujo y sonido a sonido) y el taller tiene su física con fuentes,
> un torno 3D que se mecaniza pasada a pasada con sonido, la radial contra chapa de coche y la afiladora. Lo que falta
> para la 2.0 está en el apartado 6.

## 1. Qué se pidió

- Una **sección independiente de cálculo y simulación industrial**:
  - fresas, taladros de brocas, tornos y radiales;
  - herramientas de HSS, metal duro con y sin recubrimiento (Ti…), cerámica, tungsteno y diamante;
  - granos abrasivos (grits), contra distintas superficies y materiales.
- Un **simulador de torno realista** con animación y sonido, como el de la FP Superior de Diseño en Fabricación
  Mecánica:
  - manual y CNC, con el control **Fagor**;
  - que se vea arrancar material poco a poco, pulirse la pieza y tomar la forma del **plano**.
- Una **afiladora** de cuchillos, brocas y fresas: rpm adecuadas para cada herramienta y material, y ángulo de
  afilado correcto, con estudios y ensayos actuales.
- **Audio que no dependa de componentes que falten** en ningún sistema, empaquetado en la propia app, también en
  móvil.
- **Todo en un mismo programa**, con las dos secciones, compartiendo modelos y fórmulas de física reutilizables.
- **Sin tocar ningún resultado** de uñas, garras y colmillos.
- Motor elegido: **rehacer toda la app en Godot**.

## 2. Decisión de motor: Godot 4.7

| Opción | Ventaja | Inconveniente |
|---|---|---|
| Seguir en JS (three.js dentro de la app actual) | Reutiliza todo; +150 KB | 3D en móvil problemático (expo-gl con las SDK recientes), dos interfaces (React DOM y React Native) |
| Godot dentro de la app actual | 3D del motor | En web: solo WebGL2, ~40 MB de WASM y sin audio procedural en el modo de un hilo; dos cadenas de herramientas |
| **Rehacer todo en Godot** (elegida) | Una sola app e interfaz para las 5 plataformas; 3D y audio nativos también en móvil; editor visual; MIT | Reescribir el laboratorio, la física, los tests y la CI |

**Cómo se garantiza que la tribología no cambia:**
- El motor JavaScript 1.x queda congelado como **oráculo**.
- El port a GDScript tiene que reproducirlo, y se verifica con datos exportados del propio motor:
  - los 40 escenarios del golden;
  - una muestra de ~20.000 ensayos del barrido;
  - 372 dibujos en SVG canónico.

## 3. Arquitectura

```text
godot/                          ← Godot 4.7.2 · GDScript tipado
├── core/                       ← física, datos y dibujo · sin nodos · determinista · probado sin ventana
│   ├── shared/                 ← capa compartida: números como JS, aleatorio, contacto (Hertz, dureza),
│   │                             solvers, abrasión (Hokkirigawa–Kato), Archard, DSP
│   ├── lab/                    ← Tribología biológica (port del motor 1.x)
│   └── taller/                 ← corte, torno, Fagor, plano e inspección, abrasivos, radial, afiladora,
│                                 malla 3D, virutas, sonido
├── app/                        ← interfaz y escenas (selector de sección, laboratorio, taller, torno 3D)
├── assets/                     ← fuentes OFL, sonidos del laboratorio, bucles del taller, icono
├── tests/                      ← ejecutor propio, tests y datos del oráculo
└── tools/                      ← godot.mjs (import · test · capture), horneado de sonidos
packages/core/                  ← motor JS 1.x congelado (oráculo)
apps/desktop, apps/mobile       ← 1.x: solo arreglos (1.0.1) hasta que la 2.0 los sustituya
```

**Reutilización entre secciones.** El grano abrasivo de una radial o de una afiladora usa el mismo modelo que la
punta de una uña contra la pintura de un coche:
- la geometría esfero-cónica;
- el ratio de dureza (Pintaude);
- Hertz;
- el modo de abrasión de Hokkirigawa–Kato;
- Archard.

## 4. Viabilidad física del taller

**Veredicto: viable y honesto**, con una condición: cada dato con su fuente, y lo que no tiene medición publicada
marcado como **estimación**. El resumen está en `docs/TALLER.md` y el detalle, con todas las fuentes, en
`docs/taller/fuentes-u*.md`.

- **Corte.** Kienzle con las tablas del *Tabellenbuch Zerspantechnik* y los datos de Sandvik.
  - Los tres casos publicados del plan se reproducen:
    - kc = 4011,8 N/mm² en el 42CrMo4 (publicado 4011);
    - Pc = 8,4 kW;
    - planeado de 27,0 → 21,3 kW.
  - La investigación encontró y documentó, sin ajustar números:
    - que los 27,0 kW de Sandvik son potencia en el motor (η = 0,8);
    - una errata del *Tabellenbuch*;
    - la dispersión del fresado entre fuentes (+27 a +53 %);
    - que el color del grupo S de ISO 513 es el marrón.
- **Torno.** Las crestas simuladas miden lo que dice la teoría:
  - Rt 3,07 µm frente a 3,13;
  - Ra 0,791 µm frente a 0,781.
  El volumen arrancado cuadra con el analítico con un error del −0,067 %.
- **Control Fagor 8055 T.** Sintaxis citada página a página del manual de programación (Ref. 1110), con 29 de 31
  códigos confirmados. Hallazgo: en el 8055 T los ciclos **G68/G69 llevan letras**, no los parámetros P del 8025/8030.
- **Radial.** Velocidades y franjas de color de EN 12413 comprobadas con Klingspor y con la tabla de la norma. Las
  chispas salen del ensayo de chispas (TC 9-237). Las piezas de rescate tienen ficha de fabricante:
  - pilar B de 22MnB5, de ArcelorMittal;
  - refuerzo DP800, de SSAB.
- **Afiladora.** Ángulos de los fabricantes y de Verhoeven, velocidad periférica con aviso, abrasivo por material y
  riesgo térmico relativo (Malkin–Guo, Hollomon–Jaffe). La investigación corrigió tres datos del plan:
  - arista transversal de la broca: 120–135°;
  - hacha: 25–30°;
  - esmeriladora: 2980–3450 rpm.
- **Qué no predice** (se dice en la app y en la documentación):
  - la vida absoluta de la herramienta;
  - la forma de la viruta y el filo recrecido;
  - el chatter sin la respuesta en frecuencia medida;
  - los campos de temperatura y la temperatura absoluta del filo;
  - la integridad superficial;
  - la rotura de vidrio o piedra.
  Las fuerzas tienen una incertidumbre de ±30–45 %.

## 5. Resultado del prototipo

Todo el trabajo quedó en commits locales; no se subió nada a GitHub. Cada unidad se verificó con tests sin ventana
y, cuando tenía imagen o sonido, con capturas de Movie Maker revisadas.

| Unidad | Qué se hizo | Verificado |
|---|---|---|
| 0 · Base | Proyecto Godot 4.7.2, ejecutor de tests, oráculo exportado del motor 1.x, números como JavaScript (`js.gd`), azar (`rng.gd`) y capa física compartida | Semántica de JS al bit contra V8 |
| 1 · Física del laboratorio | Port 1:1 de `data`, `physics`, `lab` y `labState` | 0 discrepancias: 40 escenarios del golden, 19 249 ensayos, fichas de garras, `resolveTool` y modo dual. `compute()` ≈ 0,7–1,1 ms |
| 2 · Dibujos y sonidos del laboratorio | Port de `art.js` al mismo grafo, serializador SVG y rasterizado con ThorVG | **372 de 372 SVG idénticos byte a byte**; sonido igual en los 19 249 ensayos; dos fallos de ThorVG arreglados (máscaras con degradado y degradados en trayectos con curvas) |
| 3 · Núcleo del torno | Perfil r(z), estampado por vuelta, cápsula en G00, Pc = kc·ΔV/Δt, alarmas con su N y mando manual | Volumen −0,067 %; Rt/Ra ±10 % de la teoría; 1 paso = 1000 pasos; 10 000 pasos en 0,5–0,8 s |
| 4 · Control Fagor 8055 T | Lector, intérprete, G68/G69/G81/G82 y piezas A y B comentadas | 35 tests; 1000 líneas aleatorias sin un fallo del programa |
| 5 · Corte, plano e inspección | Catálogos con fuente y calidad, modelo de corte, planos ISO 286/2768 e inspección con nota | Casos publicados reproducidos; tolerancias IT de la tabla |
| 6 · Abrasivos y radial | Abrasivos, granos FEPA/JIS, discos EN 12413, paneles y `cut_panel` | 12 fallos encontrados en la revisión y corregidos (entre ellos el exceso de velocidad con las rpm del propio disco) |
| 7 · Afiladora | Ángulos, muelas, granos, velocidad periférica, Archard y riesgo térmico | 22 tests que cubren todos los criterios del plan |
| 8 · Sonido de máquina | Marco de parámetros, DSP compartida (port exacto de `sfx.js`), bucles horneados y reproductor | Frecuencias por DFT (radial a 11 000 rpm → 183,3 Hz); horneado determinista |
| 9 · Torno 3D | Malla de revolución por anillos, acabado según Ra, virutas, taladrina, máquina procedural | Actualización de 2000 anillos × 64 lados en 0,13–0,19 ms |
| 10 · Exportación y CI | Presets de 5 plataformas, CI y release de la V2 | Exportación real de Linux (73,8 MB) que arranca y graba con Movie Maker; actionlint y shellcheck limpios |
| 14 · Radial contra chapa en 3D | Amoladora, 4 discos, chapa de puerta, surco, rebaba, revenido, chispas y humo | 5 casos en la demo, ya con el modelo real |
| 12 · Programa e interfaz del laboratorio | Barra con el selector de sección, sonido, fundamentos y créditos; tema global; las 7 tarjetas de la 1.x; banco animado; dos columnas o una en teléfono | 27 ensayos pulsando la interfaz, idénticos a `Physics.compute()` (~10 ms por ensayo); capturas de escritorio y teléfono |
| 13 · Controlador e interfaz del taller | `workshop_state.gd`; torno (3D, media sección con cotas, editor Fagor, lecturas, velocidad ×0,25–×50, manual, informe), radial, afiladora y calculadoras | La pieza A a ×50 da el mismo informe que el test de integración (9,6/10); 8,1 ms por fotograma a ×50 sin contar el dibujo |
| 11 · Audio de la 1.0.1 (Tauri) | AppImage con solo los plugins del Web Audio; `.deb` y `.rpm` con GStreamer; licencias; versión 1.0.1 | 121 tests; `cargo build`, actionlint y shellcheck limpios; el ZIP de la 1.0.1 pasa `npm ci`, los tests, el build y la prueba móvil |

**Integración (unidades unidas y probadas juntas):**
- **Laboratorio:** física → sonido con 0 discrepancias en 19 249 ensayos, y física → dibujo con 88 de 88 SVG
  idénticos.
  - Para llegar ahí se portaron `log`, `log1p`, `log10` y `cbrt` tal como los calcula V8 12.4. Se validaron con
    ~480 000 valores contra Node.
  - La libm de cada plataforma difiere en el último bit y cambiaba dos dibujos.
- **Taller:** programa Fagor → torno → modelo de corte → inspección.
  - La pieza A saca 9,6/10 y la B 8,0/10. Donde fallan es donde falta la compensación de radio G41/G42, como se
    esperaba.
  - La malla 3D y el sonido se alimentan del torno real.
  - La integración destapó y corrigió nueve desajustes entre unidades (ver `docs/TALLER.md`, apartado 3).

## 6. Plazos reales

| Tramo | Contenido | Tiempo real |
|---|---|---|
| Sesión 1 (esta) | Paso 0, 12 unidades, integración, 2 interfaces, estudio y ZIP | Unas 11 h hasta la integración de la primera tanda, con dos paradas por el límite de uso de la sesión |
| Sesión 2 | Laboratorio completo en Godot (paridad pantalla a pantalla con la 1.x, comparativa, logros) | ≈3–5 h |
| Sesión 3 | Taller completo: fase 2 del Fagor (G41/G42, roscado), fresado y taladrado en la interfaz, tus programas de la FP | ≈4–6 h |
| Sesión 4 | Release en 5 plataformas: instaladores, APK e IPA, presets móviles, accesibilidad | ≈3–5 h, más 2–4 vueltas de CI |
| **Total V2.0** | | **≈1–2 semanas de calendario**, marcadas sobre todo por tus pruebas y revisiones |

**Lo aprendido sobre el trabajo con agentes:**
- Con 12 agentes a la vez se alcanzó dos veces el límite de uso de la sesión. No se perdió trabajo, pero el tiempo de
  espera se comió la ventaja del paralelismo.
- A partir de ahí se trabajó con **como mucho 2 agentes** para la implementación pesada. La integración, el cableado
  y la revisión los hizo el coordinador.

## 7. Riesgos

| Riesgo | Qué pasó en el prototipo | Control |
|---|---|---|
| El port cambia resultados del laboratorio | 0 discrepancias; el último bit de libm cambiaba dos dibujos | Oráculo JS congelado, funciones matemáticas de V8 portadas, test de integración física → dibujo → sonido |
| ThorVG no pinta algo del SVG | Máscaras con degradado y degradados en trayectos con curvas (arreglados); `clipPath` en 8 bits (pendiente); no pinta `<text>` | Arreglos con test que avisa si una versión nueva de Godot los hace innecesarios; rótulos como `Label` de Godot |
| Rendimiento de GDScript | `compute()` ≈ 1 ms; 10 000 pasos del torno < 1 s; malla 0,19 ms/fotograma | Medido; no hace falta GDExtension |
| Desajustes entre unidades | Nueve: ids de material, unidades (mm/m, W/kW), torreta, criterio de alarma, inspección… | Contratos ampliados en `godot/CONTRATOS.md` y tests de integración |
| Límite de uso con muchos agentes | Dos paradas con 12 agentes | Como mucho 2 agentes de implementación a la vez |
| Dialecto Fagor mal reproducido | G68 con letras (no P), confirmado en el manual | Sintaxis citada; tus programas de la FP como pruebas de aceptación |
| Dispersión de kc1.1 | Del +27 al +53 % entre fuentes en fresado | Una familia de datos por material y banda visible |
| Móvil | No probado en dispositivo en esta sesión | Presets de calidad (`configure_lod`), Compatibility como respaldo, prueba en tu iPhone |

## 8. Verificación

```bash
npm test                      # 1.x: 115 tests del motor congelado + 6 del empaquetado de la 1.0.1
npm run godot:test            # todos los tests de Godot (laboratorio contra el oráculo, taller e integración)
npm run godot:capture -- res://app/taller/demo_torno3d.tscn --frames=300 --out=/tmp/torno
```

- **1.x:** 121 de 121: 115 del motor congelado y 6 del empaquetado de la 1.0.1. `packages/core/src` es el de la
  1.0.0 salvo la versión (`APP_VERSION` = 1.0.1).
- **Godot:** 336 tests, 0 fallidos. Cubren el laboratorio contra el oráculo, el taller, la integración y las dos
  interfaces.
- **Auditoría del motor 1.x:** 603 228 ensayos, 0 problemas.
- **Capturas y vídeos de Movie Maker revisados:**
  - torno 3D: desbaste, acabado brillante, virutas e inspección en colores;
  - radial contra chapa: 5 casos con el modelo real;
  - interfaz del laboratorio: escritorio y teléfono;
  - interfaz del taller: torno a ×50 hasta el informe, radial, afiladora y calculadoras.
- **Exportación de Linux del proyecto final:** 75,7 MB; el ejecutable arranca bajo Xvfb, sin errores de script.
- **Sonido:** en el torno, el corte suena +3,1 dB por encima del giro en vacío; la radial a 11 000 rpm da su tono
  a 183,3 Hz.

**Lo que solo se puede comprobar fuera de la nube:**
- Forward+ en una GPU real (aquí solo hay OpenGL por software: el torno 3D va a ~2 fotogramas por segundo);
- móviles, macOS y Windows (los compila `godot-release.yml`);
- tu criterio de realismo con los programas de la FP.
