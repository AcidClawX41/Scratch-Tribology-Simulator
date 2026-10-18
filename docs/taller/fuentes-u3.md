# Unidad 3 · Núcleo del torno: modelo, fuentes y estimaciones

Archivos: `godot/core/taller/lathe.gd` (el torno), `godot/core/taller/lathe_tools.gd` (plaquitas y portaherramientas),
`godot/tests/taller/test_lathe.gd` (tests) y `godot/tools/demo_torno.gd` (demostración sin ventana).

## Modelo

- **Pieza.** Perfil axisimétrico r(z) en una rejilla de dz = 0,02 mm. El anillo i es un disco de espesor dz centrado
  en `z0 + i·dz`. Z = 0 es la cara acabada y la pieza está en Z < 0. Un anillo con r = 0 ya no tiene material.
- **Corte por estampado.** En cada avance (G01, G02/G03, avance automático, manivela con el cabezal en marcha) la
  envolvente de corte se estampa **una vez por vuelta** del cabezal, a intervalos f a lo largo de la trayectoria:
  `r_nuevo = min(r_viejo, envolvente)`. La envolvente es el círculo de la punta (radio rε, centro = punta teórica +
  (rε, rε)) más los dos filos rectos tangentes, hasta su longitud útil. Es lo que ve una sección angular fija de la
  pieza, porque la herramienta pasa por ella una vez por vuelta. Por eso quedan las crestas de avance reales. Al
  terminar un movimiento se estampa también el punto final.
- **Rápidos.** Antes de moverse se comprueba la envolvente barrida entera: la cápsula del círculo de la punta y las
  envolventes convexas de la plaquita y del portaherramientas, contra el material, el plato y el contrapunto. Si toca
  algo, la herramienta se detiene en el primer contacto (bisección exacta sobre la fracción del recorrido) con la alarma,
  sea cual sea el tamaño del paso. Si la herramienta ya estaba metida al empezar (se detuvo a mitad de corte por un
  choque), ese solape inicial no cuenta y solo penetrar más allá de él es un choque. Así, tras RESET, se puede retirar.
- **Potencia.** ΔV = Σ π(r² − r'²)·dz en cada vuelta y Pc = kc·ΔV/Δt, con Δt = 60/n y kc del modelo de corte inyectado
  `Callable(work_id, tool_id, h_mm, b_mm, vc) -> { kc, fc_n }`, con h = f·sen κr y b = ap/sen κr.
- **ap de trabajo.** Es la ap equivalente por volumen: la profundidad de un cilindrado que arrancaría el mismo ΔV en el
  recorrido desde el estampado anterior, `ap = √(r² + ΔV/(π·recorrido)) − r`. En régimen coincide con la programada,
  menos la altura media de las crestas (test). En una esquina, donde la herramienta limpia el redondeo que dejó la
  pasada anterior, no se infla: la extensión del contacto llega a 2,2 mm con 1,5 programados. Con ella, h·b = f·ap
  cuadra con el volumen arrancado. La extensión del contacto perpendicular al avance también se publica
  (`state().contact_mm`).
- **κr efectivo.** Con plaquita redonda, o cuando solo corta el arco de la punta (ap < rε·(1 − cos κr)), el ángulo es el
  del arco a esa profundidad, `acos(1 − ap/rε)`: es la misma geometría de la fórmula de Sandvik para plaquitas
  redondas, `hex = f·√(1 − ((iC − 2ap)/iC)²)`.
- **Límite del modelo por vuelta.** Con la manivela o con avance en mm/min, si el cabezal va tan despacio que el avance
  por vuelta supera el doble del máximo de catálogo de la plaquita, la manivela deja de cortar y se para al tocar, y
  un avance del programa da FEED_SPINDLE_STOPPED. Si no, entre vuelta y vuelta la herramienta atravesaría material sin
  cortarlo. Parar el cabezal a mitad de un avance hace lo mismo. Mientras el cabezal gira, aunque sea frenando, se
  corta.
- **Cabezal.** G97 (rpm fijas) o G96 (`n = 1000·vc/(π·D)` con D = 2·r en la punta, tope G92 y tope de la máquina).
  Rampa de aceleración (estimación) y espera a que el cabezal llegue a la velocidad pedida tras cada orden de cabezal.
- **Tiempo.** Ticks enteros de 1 ms. `step(dt)` acumula nanosegundos enteros y ejecuta los ticks completos, así que un
  paso de 40 s y mil de 0,04 s dan el mismo perfil (test). No hay azar ni reloj.
- **Rugosidad.** `ring_ra` es el Ra medido en el perfil simulado:
  - se reconstruyen las crestas exactas entre anillos, como intersección de las envolventes de los dos estampados, con
    fórmula cerrada entre dos arcos y bisección en los demás casos;
  - la línea media es cuadrática, por mínimos cuadrados, y se integra |y| sobre la poligonal;
  - la longitud de evaluación es un número entero de avances (al menos 4 y al menos 0,8 mm, el λc de ISO 4288) alrededor
    del anillo;
  - la ventana se corta en los escalones (salto > 0,05 mm entre anillos), en el bruto y en las aristas, donde cambia la
    pendiente media sobre un avance, que no ve las crestas. En las caras, que r(z) no puede medir, se da el Ra teórico
    de las marcas de avance.

  `measure_roughness(z1, z2)` mide Ra, Rt y Rz en un tramo, como un rugosímetro.

### Relaciones de rugosidad (validadas en los tests)

- **Crestas del arco.** Rt = rε − √(rε² − f²/4) ≈ f²/(8rε) mientras f ≤ 2·rε·sen κr'.
- **Ra.** Con crestas parabólicas, Ra = 4/(9√3)·Rt ≈ 0,2566·Rt, es decir Ra ≈ 0,0321·f²/rε = f²/(31,2·rε). La fórmula de
  catálogo f²/(32·rε) redondea el 31,2 a 32, y el arco real es algo más empinado que la parábola. Por eso lo medido
  queda entre un 1 % y un 5 % por encima de f²/(32rε).
- **Filo secundario.** Si f > 2·rε·sen κr', la cresta la forman el arco de una vuelta y el filo secundario de la
  siguiente:
  - `A = rε/cos κr' − f·tan κr'`
  - `v = cos²κr'·(−A·tan κr' + √(rε²/cos²κr' − A²))`
  - `Rt = rε − √(rε² − v²)`

  Es la construcción geométrica clásica del acabado con el filo secundario (Boothroyd y Knight, *Fundamentals of
  Machining and Machine Tools*). Con una C 80° en 95° (κr' = 5°), f = 0,3 y rε = 0,4 da 15,2 µm, frente a los 28,1 µm
  de f²/8rε. El test lo comprueba con un 3 %.

| f (mm/rev) | rε (mm) | Rt medido | f²/8rε | Ra medido | f²/32rε | ring_ra |
|---|---|---|---|---|---|---|
| 0,2 | 0,4 | 12,83 µm | 12,50 | 3,249 µm | 3,125 | 3,185 |
| 0,3 | 0,4 | 29,45 µm | 28,13 | 7,414 µm | 7,031 | 7,323 |
| 0,2 | 0,8 | 6,34 µm | 6,25 | 1,608 µm | 1,563 | 1,577 |
| 0,3 | 0,8 | 14,38 µm | 14,06 | 3,629 µm | 3,516 | 3,647 |

(Rómbica 55° en portaherramientas de 93°, κr' = 32°: el filo secundario no recorta las crestas.)

## Fuentes

| Dato | Fuente | Calidad |
|---|---|---|
| Formas ISO 1832 y ángulo de punta (C 80°, D 55°, V 35°, T 60°, W 80°, S 90°, R), letras de incidencia (N 0°, B 5°, C 7°, P 11°), códigos de radio (02/04/08/12 = 0,2/0,4/0,8/1,2 mm), IC ↔ longitud de filo | ISO 1832:2017; clave de códigos de Sandvik Coromant, *Turning tools 2015*, cap. I, págs. I14–I16 ([PDF](https://productivitysolution.co.th/wp-content/uploads/2017/Downloadfiles/Sandvik/Turning%20Tools%202015%20Chapters%20I.pdf)) | primary |
| κr (KAPR) y cotas B, H, LF, WF, OHX de los portaherramientas de mango 25 × 25 | Sandvik Coromant, *Turning tools 2015*, cap. A ([PDF](https://productivitysolution.co.th/wp-content/uploads/2017/Downloadfiles/Sandvik/Turning%20Tools%202015%20Chapters%20A.pdf)): PCLNR 95° (A148), SCLCR 95° (A346), PDJNR 93° (A153), SDJCR 93° (A351), PVJNR..HP 93° (A177), SVJBR 93° (A373), PTGNR 91° (A172), PWLNR..HP 95° (A181), PSSNR 45° (A164), PSBNR 75° (A162), PRGNR redonda (A155) | primary |
| ap y fn (mín · recomendado · máx) de cada plaquita | Ídem, tabla *Recommended depth of cut and cutting feed, metric*, págs. A567–A577 (ver tabla siguiente) | primary |
| Ángulo libre mínimo de 2° (7° recomendado) entre pieza y plaquita al copiar: rampa máxima = κr' − 2° | Sandvik Coromant, [Internal turning](https://www.sandvik.coromant.com/en-us/knowledge/general-turning/internal-turning) (torneado de perfiles) | secondary (regla primaria aplicada a κr' calculado) |
| Contra las vibraciones: ap mayor que rε, κr cercano a 90° y radio de punta menor | Sandvik Coromant, [How to achieve good component quality in turning](https://www.sandvik.coromant.com/en-us/knowledge/general-turning/how-to-achieve-good-component-quality-in-turning) | secondary |
| Plaquita negativa (0°) inclinada en el asiento para tener incidencia | Sandvik Coromant, [How to choose correct turning insert](https://www.sandvik.coromant.com/en-us/knowledge/general-turning/how-to-choose-correct-turning-insert) | secondary (el valor de 6° es estimación) |
| Pc = vc·ap·fn·kc/(60·10³); kc = kc1·hm^(−mc) | Sandvik Coromant, [General turning formulas and definitions](https://www.sandvik.coromant.com/en-us/knowledge/machining-formulas-definitions/general-turning-formulas-definitions) | primary |
| Amarre por esbeltez: solo plato si L/D < 3 (hasta 5 con parámetros reducidos), contrapunto de 3 a 6 (hasta 10), luneta de 6 a 12 | CADEM Technologies, [CNC lathe work holding – thumb rules](https://cadem.com/cnc-turning-work-holding-thumb-rules/) | secondary |
| Ra habitual por proceso: laminado en caliente 12,5–25 µm, estirado en frío 0,4–1,6 µm | Tabla de ASME B46.1 / *Machinery's Handbook*, reproducida por [ISO Finishing](https://isofinishing.com/wp-content/uploads/2025/02/ISO-Finishing-Surface-Roughness-Comparison-Chart.pdf) | secondary |
| Módulo de Young: acero 207, aluminio 69, latón 97, titanio 107 y níquel 207 GPa | Callister y Rethwisch, *Materials Science and Engineering: An Introduction*, tabla 6.1 | secondary |
| Torno CNC: 7,5 kW, 3000 rpm, rápidos de 10 m/min, plato de 3 garras Ø200, avances de 0 a 7000 mm/min | Pinacho Mustang 200 con Fagor 8055 ([Exapro](https://www.exapro.com/sp/pinacho-mustang200-8150/)); Mustang SK-200 ([Maquinaria Colás](https://www.maquinariacolas.com/maquinaria/torno-pinacho-mustang-de-ocasion/)); avances del Taurus 260 con Fagor 8055 TC ([Corzosa](https://corzosa.com/producto/torno-pinacho-cnc-taurus-260x1500/)). Según la versión, el motor va de 7,5 a 12 kW | secondary |
| Torno paralelo: 4 kW, 12 velocidades de 40 a 2200 rpm, avances de 0,05–0,75 (longitudinal) y 0,025–0,375 mm/rev (transversal) | Pinacho S90/200 ([Rastromáquinas](https://www.rastromaquinas.com/torno-paralelo-pinacho-s90200/)) | secondary |
| Rugosidad: Ra (ISO 4287) y longitud de muestreo λc = 0,8 mm para 0,1 < Ra ≤ 2 µm | ISO 4287 e ISO 4288 | primary |
| Punto del contrapunto de 60° | Norma de puntos de centrado (DIN 332 / ISO 866) | secondary |

### Datos de corte de Sandvik usados (catálogo 2015)

| Plaquita | rε | ap mín · rec · máx (mm) | fn mín · rec · máx (mm/rev) | Página |
|---|---|---|---|---|
| CCMT 09 T3 02-PF | 0,2 | 0,08 · 0,35 · 2,0 | 0,04 · 0,08 · 0,15 | A574 |
| CNMG 12 04 04-PF | 0,4 | 0,25 · 0,4 · 1,5 | 0,07 · 0,15 · 0,3 | A567 |
| CNMG 12 04 04-PM | 0,4 | 0,4 · 3,0 · 5,5 | 0,1 · 0,2 · 0,3 | A567 |
| CNMG 12 04 08-PM | 0,8 | 0,5 · 3,0 · 5,5 | 0,15 · 0,3 · 0,5 | A567 |
| CNMG 12 04 12-PR | 1,2 | 1,0 · 4,0 · 7,0 | 0,25 · 0,4 · 0,7 | A567 |
| DCMT 11 T3 02-PF | 0,2 | 0,08 · 0,35 · 2,0 | 0,04 · 0,08 · 0,15 | A575 |
| DNMG 15 04 04-PF | 0,4 | 0,25 · 0,4 · 1,5 | 0,07 · 0,15 · 0,3 | A569 |
| DNMG 15 04 08-PM | 0,8 | 0,5 · 3,0 · 6,0 | 0,15 · 0,3 · 0,5 | A569 |
| DNMG 15 04 12-PR | 1,2 | 1,0 · 4,0 · 6,0 | 0,25 · 0,4 · 0,7 | A569 |
| VBMT 16 04 02-PF | 0,2 | 0,07 · 0,32 · 1,8 | 0,04 · 0,07 · 0,14 | A577 |
| VNMG 16 04 04-PF | 0,4 | 0,25 · 0,4 · 1,5 | 0,07 · 0,15 · 0,3 | A573 |
| VNMG 16 04 08-PM | 0,8 | 0,5 · 2,0 · 4,0 | 0,15 · 0,3 · 0,5 | A573 |
| VNMG 16 04 12-PM | 1,2 | 0,8 · 2,0 · 4,0 | 0,18 · 0,35 · 0,6 | A573 |
| TNMG 16 04 04-PF | 0,4 | 0,25 · 0,4 · 1,5 | 0,07 · 0,15 · 0,3 | A571 |
| TNMG 16 04 08-PM | 0,8 | 0,5 · 3,0 · 5,0 | 0,15 · 0,3 · 0,5 | A571 |
| TNMG 16 04 12-PR | 1,2 | 1,0 · 3,0 · 6,0 | 0,25 · 0,4 · 0,65 | A571 |
| WNMG 08 04 04-PF | 0,4 | 0,25 · 0,4 · 1,5 | 0,07 · 0,15 · 0,3 | A572 |
| WNMG 08 04 08-PM | 0,8 | 0,5 · 2,5 · 4,0 | 0,15 · 0,3 · 0,5 | A573 |
| WNMG 08 04 12-PR | 1,2 | 1,0 · 4,0 · 5,0 | 0,25 · 0,4 · 0,7 | A573 |
| SNMG 12 04 04-PM | 0,4 | 0,4 · 3,0 · 6,0 | 0,1 · 0,2 · 0,3 | A570 |
| SNMG 12 04 08-PM | 0,8 | 0,5 · 3,0 · 6,0 | 0,15 · 0,3 · 0,5 | A570 |
| SNMG 12 04 12-PR | 1,2 | 1,0 · 4,0 · 7,0 | 0,25 · 0,4 · 0,7 | A570 |
| RNMG 12 04 00 | 6,35 | 1,2 · 3,0 · 4,8 | 0,073 · 0,184 · 0,368 | A570 |

Derivados:
- κr' = 180° − κr − εr. Por ejemplo, C 80° en 95°: 5°; D 55° en 93°: 32°; V 35° en 93°: 52°; T 60° en 91°: 29°.
- Rampa máxima de copiado = κr' − 2°: C 80°: 3°; D 55°: 30°; V 35°: 50°; T 60°: 27°.
- Longitud recta útil de cada filo: l − rε/tan(εr/2).

## Estimaciones (sin medición publicada: marcadas `estimate`)

| Valor | Dónde | Por qué |
|---|---|---|
| Incidencia efectiva de 6° de la plaquita negativa en su asiento | `lathe_tools.NEG_SEAT_CLEARANCE_DEG` | Sandvik explica la inclinación, pero no publica el ángulo en lo consultado. Solo es informativo |
| Forma de la cabeza del portaherramientas: 25 mm hasta el mango y cara inferior 10° más inclinada que el filo secundario; con plaquita redonda, a 40° (rampa máxima de 38°) | `HEAD_H_MM`, `HOLDER_BOTTOM_EXTRA_DEG`, `ROUND_HOLDER_RISE_DEG` | El catálogo da B, H, LF, WF y OHX, no la forma de la cabeza |
| Garras de 35 × 30 mm, aceleración del cabezal de 2000 rpm/s, cambio de herramienta de 1 s y manivela a 300 mm/min (0,28 mm/rev a 1074 rpm) | `lathe.MACHINES.cnc` | No aparecen en las fichas |
| Límite del modelo: avance por vuelta de hasta 2 veces el máximo de catálogo de la plaquita | `lathe.FEED_REV_LIMIT` | Límite de validez del modelo de una sección por vuelta, no un dato publicado |
| Velocidades intermedias del torno paralelo (serie geométrica entre 40 y 2200 rpm); rápido de 2000 mm/min, plato Ø200 y garras de 30 × 25 mm | `lathe.MACHINES.manual` | La ficha solo da el rango y el número de velocidades |
| Creces de refrentado de 1 mm en los brutos A y B | `lathe.STOCKS` | El contrato no lo fija |
| Contrapunto: punta de 60° desde Ø6,7 hasta Ø25, cuerpo hasta 45 mm y caña de Ø60 | `lathe.TAIL` | Los 60° son de norma; las medidas son típicas |
| Umbral de acabado: ap ≤ 1 mm y f ≤ 0,2 mm/rev (con la mayor ap de las vueltas del movimiento) | `FINISH_AP_MAX`, `FINISH_F_MAX` | Clasificación orientativa para `ring_pass`. Referencia: las -PF de Sandvik llegan a ap 1,5 y fn 0,3–0,4 |
| Índice de vibración: pesos 1 (L/D) y 0,3 (fuerza radial) | `lathe.chatter_risk` | Combinación propia de dos reglas publicadas. El modo de flexión sí es la viga de Euler-Bernoulli |
| E y densidad del inoxidable (193 GPa, 8000 kg/m³) y de la fundición gris (100 GPa, 7200 kg/m³) | `lathe.E_GPA`, `lathe.RHO` | Valores típicos: varían con la aleación |
| Ra del bruto: 12,5 µm laminado y 1,6 µm estirado | `lathe.RAW_RA` | Elegidos dentro de la banda habitual de la tabla por proceso |
| Ventana de Ra: salto de 0,05 mm entre anillos y arista con cambio de pendiente de 0,08 | `JUMP_MM`, `KINK_SLOPE` | Parámetros del método de medida, no de la física |
| Modelo de corte por defecto: Kienzle con kc1.1 = 1700 N/mm² y mc = 0,25 | `lathe.kienzle_model` | Es el sustituto de prueba del contrato hasta que se inyecte el de la unidad de corte. No es un dato de material |

## Validación (tests en `godot/tests/taller/test_lathe.gd`, 23 tests)

- **Pasada de Ø50 a Ø46 en 30 mm** (rε 0,4, f 0,05): arranca 9041,75 mm³ frente a π/4·(50² − 46²)·30 = 9047,79, un
  −0,067 %. En un desbaste real (rε 0,8, f 0,3) la diferencia llega al −0,4 % por el redondeo de la punta en el hombro y
  por las crestas. Otro test la cuadra con la geometría real (cilindro − redondeo de Pappus − crestas) con un 0,1 %.
- **Crestas:** tabla anterior (Rt con un 10 % de f²/8rε, Ra y ring_ra con un 10 % de f²/32rε). Con filo secundario,
  Boothroyd con un 3 %.
- **Conservación:** un paso de 40 s da el mismo perfil que mil pasos de 0,04 s (diferencia ≤ 1e-9 mm). El radio nunca
  crece. V0 − V = Σ ΔV. Todo cambio cae dentro del rango `dirty`. Dos ejecuciones son idénticas.
- **Alarmas:** un G00 que atraviesa la pieza en un solo paso de 100 s se detiene en la cara con RAPID_IN_MATERIAL, y lo
  mismo en diagonal. Cada una de las diez alarmas sale una vez con el N de su bloque y un mensaje en español que
  empieza por «N<n>». Solo detienen la máquina las graves.
- **Física:**
  - Pc = kc·ΔV/Δt coincide con la fórmula de Sandvik salvo el factor (diámetro medio)/(diámetro mecanizado).
  - La CSS respeta el tope G92 y el de la máquina (este último con aviso).
  - Refrentar hasta X0 deja pezón y hasta X−2rε no. Retirar en Z sobre el pezón es un rápido contra material.
  - Un redondeo cóncavo R2 hecho con G02 sigue el círculo desplazado rε con un error < 2 µm.
- **Mando manual:**
  - con el cabezal parado, la manivela se detiene al tocar la pieza;
  - parar el cabezal a mitad de una manivela no deja atravesar material sin cortar;
  - dos clics seguidos se suman;
  - la misma alarma manual vuelve a salir tras RESET;
  - tras chocar con las garras a mitad de pasada se puede retirar, y volver a entrar sí es un choque.
- **Rendimiento:** 10.000 pasos de 1/60 s de un programa largo (refrentado, 12 pasadas y acabado: 166,7 s simulados,
  3226 estampados, 59 182 mm³) tardan entre 0,53 y 0,81 s sin ventana en la nube (4 núcleos compartidos).
- **e2e:** `godot/tools/demo_torno.gd` escribe `perfil.svg`, `perfil.png` y `metricas.txt`. En el acabado del Ø40
  (f 0,1, rε 0,4) mide Rt 3,07 µm, con un teórico de 3,13, y Ra 0,791 µm, con un teórico de 0,781. El G00 del bloque
  N260 se detiene en X40 Z−11,67.

## API (godot/core/taller/lathe.gd)

```gdscript
const Lathe = preload("res://core/taller/lathe.gd")
Lathe.new(stock: Dictionary = {}, machine: Variant = "cnc", cut_model: Callable = Callable())
    # stock: claves de Lathe.STOCKS (d, length, clamp, face_z, work_id, work_kind, surface, tailstock) y opcionales
    # dz, raw_ra_um, kc {kc11, mc}, e_gpa, density. machine: "cnc", "manual" o un diccionario como Lathe.MACHINES.
static kienzle_model(kc11: float, mc: float) -> Callable
set_tool(t: Variant) -> bool                    # id «PORTA/PLAQUITA» de lathe_tools o un diccionario de herramienta
set_tool_table(table: Dictionary) -> void       # T del programa («1», «T1») → id del catálogo
place_tool(r: float, z: float) -> void          # coloca la punta sin simular (preparación)
load_moves(moves: Array) -> void                # IR del contrato
step(dt_s: float) -> Dictionary                 # { t_s, ticks, removed_mm3, stamps, alarms }
run_to_end(max_s := 3600.0) -> Dictionary       # { t_s (tiempo de ciclo), done, halted, alarms }
jog(axis: String, d_mm: float) -> bool          # «x» en diámetro, «z» en mm
set_spindle(rpm: float, dir: String) -> void    # «cw», «ccw» o «stop»
set_feed(axis: String, f_mm_rev: float, on: bool) -> void   # f < 0: hacia el plato o hacia el eje
set_coolant(on: bool) -> void
reset() -> void
profile() -> Dictionary                         # { z0, dz, r, ring_ra, ring_pass, dirty } del contrato
measure_roughness(z_from, z_to, form := "line") -> Dictionary   # { ra_um, rt_um, rz_um, points, crests, d_mm }
state() -> Dictionary                           # t_s, tip, x_diam, spindle, feed, pc_kw, fc_n, kc, h_mm, b_mm, ap_mm, contact_mm, vc_m_min…
alarms() -> Array[Dictionary]                   # { code, n, message }; Lathe.ALARMS[code].halt dice si detiene
sound_input() -> Dictionary                     # entrada de sonido del contrato
chatter_now() -> Dictionary
static chatter_risk(overhang_mm, diameter_mm, ap_mm, re_mm, kr_deg := 95.0, tailstock := false, e_gpa := 207.0, density := 7850.0) -> Dictionary
radius_at(z) · volume_mm3() · removed_mm3() · initial_volume_mm3() · tool() · machine() · stock() · is_halted() · is_done() · clear_alarms()
```

Y en `lathe_tools.gd`:

```gdscript
tool(id) -> Dictionary
find(shape, re_mm) -> Dictionary
make_tool(holder_id, insert_id) -> Dictionary
ids() -> Array[String]
cut_geometry(tool) -> Dictionary
env(geometry, u) -> float
kr_eff_deg(tool, ap) -> float
convex_hull(flat) -> PackedFloat64Array
# Constantes: SHAPES, INSERTS, HOLDERS, TOOLS, ROUGH, FINISH
```

## Para el coordinador

1. **Sentido de los arcos.** El torno interpreta `arc.cw` como horario visto con Z hacia la derecha y X hacia arriba,
   que es la vista del plano (torreta trasera): en G02 el ángulo baja. Hay que confirmar que el intérprete Fagor lo
   produce así, o fijarlo en CONTRATOS.md.
2. **`from` del IR** se ignora: manda la posición real de la máquina. Si el intérprete arrastra errores de redondeo,
   no se acumulan.
3. **Clave opcional `pass` en los movimientos de avance** (1 desbaste, 2 acabado). Si viene, fija `ring_pass`. Si no,
   se decide con la ap equivalente y f. Propongo añadirla al IR para los ciclos de desbaste y acabado del Fagor.
4. **Herramientas del programa:** `tool.id` del IR se busca en la tabla de `set_tool_table`, que por defecto es
   «1» desbaste C 80°, «2» acabado D 55° y «3» V 35°. El intérprete o la interfaz deberían cargar la tabla real de la
   torreta.
5. **Brutos:** la cara del bruto queda en Z+1, con 1 mm de creces de refrentado (estimación), y Z0 es la cara acabada.
   Los anillos con r = 0 son material quitado: la malla y la vista 2D no deben dibujarlos.
6. **`work_id` de los brutos** («c45e» y «en-aw-6082-t6») son provisionales: hay que alinearlos con los ids de
   material de la unidad de corte.
7. **`dirty`** incluye el margen en el que cambia `ring_ra` (media ventana de Ra, unos 0,6–1,2 mm alrededor del
   cambio), no solo los anillos cuyo radio ha cambiado.
8. **`ring_pass` = 3 (pulido)** está reservado: este núcleo no tiene todavía una operación de pulido (tela abrasiva o
   lima en el torno). Podría hacerse con la capa `abrasion.gd`.
9. **`ring_ra` cerca de una arista.** A menos de media ventana (~0,4 mm) de un chaflán o de un redondeo, se mide con
   una ventana más corta. Para inspeccionar un tramo conviene `measure_roughness` sobre el tramo sin sus extremos, o
   la mediana de `ring_ra`.
10. **ThorVG (Godot 4.7.2) no pinta `<text>` en los SVG.** Por eso la demo usa una fuente de trazos propia. Si otra
    unidad rasteriza SVG con cotas, le pasará lo mismo.
11. **`sound_input().tool_pos`** es `Vector3(z, r, 0)` en mm y en coordenadas de la pieza. La unidad de la escena 3D
    debe convertirlo a sus ejes.
12. Las alarmas llevan exactamente `{ code, n, message }`. Las de la manivela y el avance manual llevan `n = −1`. Si
    una alarma detiene la máquina lo dice `Lathe.ALARMS[code].halt`: RAPID_IN_MATERIAL, AP_EXCEEDED, las tres de choque,
    X_NEGATIVE, FEED_SPINDLE_STOPPED y OVERLOAD detienen el programa y el cabezal; FLANK_RUB y RPM_LIMIT son avisos.
