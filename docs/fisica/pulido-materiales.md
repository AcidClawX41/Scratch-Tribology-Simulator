# Pulido del laboratorio: materiales y fractura (modelo 2.0 · unidad 1f)

Especificación de la física nueva del banco de tribología para el **modelo 2.0**: grietas en los frágiles, uñas que se
doblan o se parten, recuperación elástica, garras frágiles que se mellan, chapa que se abolla y los vidrios de coche
(templado y laminado). La física vive en módulos puros de `godot/core/lab/`; la integración en `compute()` (rama
`if v2:`), los dibujos y la interfaz los hace la oleada siguiente siguiendo la guía del apartado 7. El camino 1.x no
se toca.

**Estado (unidad 4a):** integrado en `Physics.compute()` (modelo 2.0) con los veredictos, los textos, los objetivos
nuevos del catálogo, las filas de la tarjeta del resultado y el golden 2.0; los 37 casos de referencia pasan a través de
`compute()` (`tests/lab/test_materiales_v2.gd`). Lo que queda son los dibujos y las animaciones del §7.6. Detalle de la
integración, decisiones y cambios de datos en el §7.11.

| Tema | Estado | Módulo | Datos | ¿Cambia veredictos? |
|---|---|---|---|---|
| 1. Fractura de frágiles (Hertz, Auerbach, Lawn-Evans) | modelo completo | `fracture.gd` | medidos (vidrio, pantalla, zafiro) y estimados (encimera, ν del diamante) | sí: «GRIETAS DE HERTZ», «CONO DE HERTZ» |
| 2. Flexión y rotura de la uña | modelo completo | `bending.gd` | uña natural medida; gel, acrílico y uñas macizas estimados | sí: «SE DOBLA LA UÑA», «SE PARTE LA UÑA» |
| 3. Recuperación elástica | modelo completo | `recovery.gd` | Oliver & Pharr (1992) con los H y E del catálogo | sí: los no frágiles se clasifican con la huella residual |
| 4. Garras reforjadas frágiles | modelo **informativo** | `fracture.gd` (`tip_chip`) | zafiro de hoja técnica; cuarzo estimado; diamante sin dato | no |
| 5. Abolladura de chapa | modelo completo | `dent.gd` | calibrado con una medición (Nippon Steel 2013) | sí: «ABOLLA LA CHAPA» al punzar o golpear |
| 6. Ventanilla templada y parabrisas laminado | objetivos nuevos | `glazing.gd` | mixtos (normas, Nielsen et al. 2022, estimaciones) | objetivos nuevos: «ESTALLA LA VENTANILLA», «SE AGRIETA (NO CAE)» |

Unidades como en todo el banco: fuerza N · longitudes mm (profundidades y grietas en µm) · presión, dureza y tensión
MPa (dureza en HV como etiqueta; 1 HV = 9,807 MPa) · módulos GPa · tenacidad K_c en **MPa·√m** · energía J.
Cada dato lleva `source` y `quality` (`primary` medido y publicado · `secondary` hoja técnica, norma o revisión ·
`estimate` sin medición).

Casos de referencia: `godot/tests/fixtures/spec/pulido-materiales.json` (37). Tests: `godot/tests/lab/test_fracture.gd`,
`test_glazing.gd`, `test_recovery.gd`, `test_bending.gd`, `test_dent.gd` y `test_pulido_spec.gd` (este último
reconstruye con los módulos y el motor de siempre todos los campos nuevos de los casos: así no pueden ser erratas).

---

## 1. Fractura de materiales frágiles

### 1.1 Qué pasa de verdad

Un vidrio no se raya como un metal. Con una punta **roma** y dura el contacto es elástico (Hertz) hasta que, justo
fuera del círculo de contacto, la tracción abre una **grieta de anillo** que salta a un **cono** (el «cono de Hertz»).
La carga crítica crece con el radio de la esfera (**ley de Auerbach**, 1891) y no depende de los defectos de la
superficie (Lawn & Marshall 1984). Si la punta además **desliza**, la fricción suma tracción en el borde trasero del
contacto y la carga crítica se desploma: el rastro son conos parciales en herradura (Lawn & Marshall 1984, fig. 3). Con
una punta **afilada** manda la plasticidad: primero un surco o una huella, y por encima de un tamaño crítico, grietas
radiales y laterales que astillan el borde (umbral de Lawn & Evans 1977).

En el 1.x, la uña maciza de zafiro cuadrada (R ≈ 1,7 mm) sobre el vidrio a 30 N «roza sin marcar» porque el contacto
es elástico. En la 2.0, al deslizar, **abre grietas desde 0,8 N**.

### 1.2 Modelo

**Punta roma: grietas de Hertz** (`hertz_threshold`, `evaluate`).

- Carga crítica sin fricción (Auerbach), con K_c en MPa·√m, R en mm y E* en GPa (las potencias de diez se cancelan):
  `P0 = A·K_c²·R/E*`, `A = 8,63·10³` (Rhee, Kim, Deng & Lawn 2001; la usan sin ajuste Ren & Zhang 2014),
  `1/E* = (1−ν_punta²)/E_punta + (1−ν²)/E` (Ren & Zhang 2014, ec. 7; ν_punta = 0,3, la común del motor).
- Deslizando con fricción μ (Ren & Zhang 2014, ec. 4-5, a partir de la tracción de Hamilton & Goodman 1966):
  `P_c = P0 / (1 + k·μ)³`, `k = 3π(4+ν)/[8(1−2ν)]`. Validez declarada: **μ < 0,5 y R < 5 mm**; μ se limita a 0,5.
  Con el vidrio (ν = 0,22) k = 8,88.
- Compresión superficial σS (pantalla reforzada, templado): la tracción de Hertz en el borde,
  `σ_m = (1−2ν)·P/(2π·a²)` (Ren & Zhang 2014, ec. 1), crece como P^(1/3) a radio fijo; para agrietar hay que vencer
  σ_m0 + σS, así que la carga se multiplica por `(1 + σS/σ_m0)³`, con σ_m0 la del borde en P0.
- **Hipótesis del modelo** (no hay medición que la contradiga, y sin ella la queratina «agrietaría» el vidrio):
  1. la punta tiene que ser al menos tan dura como el material (r ≥ 1);
  2. la punta tiene que seguir elástica hasta la carga crítica: su presión de Hertz `p0 = 3P/(2πa²)` no llega a
     `1,6·H_punta/2,8` (la misma plastificación de Johnson y la misma Y = H/2,8 de Tabor que usa el motor).
- Sin surco (profundidad < 0,05 µm, el mismo límite del veredicto «ROZA SIN MARCAR» del 1.x), el daño son solo las
  grietas: herradura al rayar, cono al apretar.

**Punta afilada: grietas radiales y laterales.**

- Umbral de Lawn & Evans (1977): `P* ∝ K_c⁴/H³`, equivalente a un tamaño crítico de la huella `a* ∝ (K_c/H)²` (la
  longitud de fragilidad de Lawn & Marshall 1979). La constante del modelo depende de la zona plástica y de los
  defectos que nuclean la grieta, mal conocidos, así que se calibra con el umbral **medido** en el vidrio sodocálcico
  con un Vickers: **0,18 N** (Mikowski et al. 2006, Weibull de tres parámetros: por debajo no nuclea ninguna grieta
  radial). Para los demás frágiles: `P* = 0,18 N·(K_c/0,75)⁴·(550/HV)³`,
  salvo la pantalla, que tiene dato propio (abajo).
- En `compute()` se compara el radio del contacto bajo carga con `a* = √(P*/((4/1,8544)·HV))` (semidiagonal del
  Vickers en el umbral; es una propiedad del material, independiente de la forma de la punta a primer orden).
- Longitud de la grieta para el dibujo (Anstis et al. 1981): `c = (χ·P/K_c)^(2/3)`,
  `χ = 0,016·√(E/H)·(cot ψ / cot 68°)^(2/3)`; el último factor es el afilado de la punta respecto al Vickers
  (Lawn, Evans & Marshall 1980): 1,6 con una gema de 50°, 3,3 con la stiletto (22°), 4,4 con una garra de 15°.
- Con surco y cualquiera de los dos criterios: surco con grietas, `pattern` «astillado» al rayar y «radiales» al
  apretar (la grieta de Hertz también está, pero lo que se ve es el astillado).

### 1.3 Datos

| Material (id) | K_c (MPa·√m) | ν | σS (MPa) | Umbral Vickers P* | a* | Calidad y fuentes |
|---|---|---|---|---|---|---|
| Vidrio de ventana (`vidrio`) | 0,75 | 0,22 | 0 | 0,18 N (medido) | 3,9 µm | secundaria: valor de referencia del sodocálcico (Wiederhorn 1969 mide 3-5 J/m² → 0,65-0,85); P* de Mikowski et al. 2006 |
| Pantalla de móvil (`movil`) | 0,68 | 0,21 | 1000 (a 40 µm) | 4,5 N (estimado) | 18,1 µm | Corning Gorilla Glass 2 (2012): K_c, ν, E 71,5 GPa, 649 HV, compresión 1000 MPa a 40 µm (capacidad). **P* estimado**: 0,18 N × 25, el cociente Gorilla con intercambio iónico / sodocálcico sin él de la gráfica de Corning |
| Encimera de cuarzo (`cuarzo`) | 1,0 | 0,2 | 0 | 0,071 N (escala) | 1,7 µm | **estimación**: cuarzo aglomerado sin medición; K_c del cuarzo monocristalino 0,85-1,15 según el plano (Iwasa, Ueno & Bradt 1981) |
| Cristal de zafiro (`zafiro`) | 2,4 | 0,29 | 0 | 0,39 N (escala) | 3,0 µm | K_c 2,38-2,43 en los planos de exfoliación fácil (Iwasa et al. 1981) y 2,31-2,47 en nitrógeno seco (Salem 2006); ν de manual (estimación) |
| Diamante (`diamante`) | 3,4 | 0,07 | 0 | 0,013 N (escala) | 0,24 µm | K_c 3,4 ± 0,5 por indentación (Field & Freeman 1981, citado en revisiones); ν estimado |

La fricción es la `mu` del catálogo (limitada a 0,5). Es la variable más sensible: con el vidrio, (1 + 8,88·μ)³ vale 7
con μ = 0,1, 49 con 0,3 y 161 con 0,5. Con bolas cerámicas en seco sobre vidrio sodocálcico se miden 0,3-0,4 (dato de
He et al. 2015, visto en resumen): en todos los casos de referencia a 30 N el veredicto no cambia con μ entre 0,1 y 0,5.

### 1.4 Valores de referencia (punta cuadrada, R = 1,69 mm)

| Punta → material | Apretando (N) | Deslizando (N) | μ |
|---|---|---|---|
| zafiro → vidrio | 127 | **0,79** | 0,5 (0,6 limitado) |
| zafiro → pantalla reforzada | 2015 | 13,7 | 0,5 |
| zafiro → zafiro | 384 | 1,96 | 0,4 |
| zafiro → encimera | 220 | 1,64 | 0,5 |
| diamante → encimera | 200 | 1,48 | 0,5 |
| diamante → zafiro | 266 | 1,35 | 0,4 |
| diamante → diamante | 306 | 81 | 0,1 |

Con la almendra de zafiro sobre el vidrio (R = 0,54 mm): 40 N apretando, 0,25 N deslizando; con la stiletto
(R = 0,22 mm): 16 N y 0,10 N. Una punta roma aguanta más que una afilada: Auerbach.

### 1.5 Exactitud y sesgo conocido

- La fórmula de Auerbach con A = 8,63·10³ **sobrestima** las cargas medidas sin fricción entre 1,7 y 2,6 veces: 80 N
  medidos en porcelana LAVA en agua frente a 210 N del modelo (Ren & Zhang 2014, tabla 1) y 210 N (superficie tal cual)
  o 300 N (abrasionada) en Pyrex con bola de acero de 5 mm (Conrad et al. 1979, leído en Marulli et al. 2023) frente a
  500 N. Apretando, el vidrio real se agrieta antes que en el modelo. El test lo deja escrito.
- Deslizando, Ren & Zhang (2014) comparan el mismo modelo con sus ensayos y concluyen que «ambos modelos coinciden
  razonablemente con los datos, sin parámetros ajustables».
- El umbral radial de la pantalla es una estimación con dos fuentes primarias y definiciones distintas.

### 1.6 Qué no predice

- La propagación del cono de Hertz (su profundidad): el radio del cono del dibujo sale del anillo y crece como P^(2/3)
  (ley de propagación P/c^(3/2) = cte, Lawn & Marshall 1984, ec. 1). Es una **estimación de dibujo**.
- La fatiga por humedad (el agua baja los umbrales hasta dos órdenes de magnitud, Lawn & Marshall 1984), el
  crecimiento subcrítico y la dispersión estadística (Weibull).
- La anisotropía de los cristales (zafiro, cuarzo, diamante): se usa el plano de exfoliación más débil.
- La dependencia del umbral radial con el ángulo de la punta (las puntas más finas nuclean antes).
- Que la gema incrustada se suelte de la uña.

---

## 2. Flexión y rotura de la uña

### 2.1 Modelo

El borde libre es un voladizo de longitud L (la uña libre: el `reach` de `GEOMS`) con la carga en la punta, M(x) = F·x.
Si la anchura decrece linealmente hacia la punta (de la cuadrada a la stiletto) la tensión máxima está siempre en la
raíz (el test lo comprueba con el perfil), así que la carga que la dobla o la parte es

`F⊥ = σ_f·Z/L`

y la forma en planta no importa: importa la longitud. La sección de la raíz es un **arco**: la uña tiene curvatura
transversal, de radio 7,4 ± 0,7 mm en el índice de las mujeres (Jung et al. 2015, galgas de radio en 300 voluntarios;
8,9 mm en hombres; Murdan 2011 mide lo mismo en otra muestra). Arco de pared delgada, cuerda b, espesor t, radio ρ y
semiángulo θ0 = asin(b/2ρ):

`I = t·ρ³·(θ0 + sin θ0·cos θ0 − 2·sin²θ0/θ0) + b·t³/12`, fibra más lejana en los bordes laterales (en tracción cuando
la punta se dobla hacia arriba). Con 11 mm de anchura la «C» es ~4 veces más resistente que la placa plana. Es una
**cota alta**: con carga grande la «C» se aplana (efecto Brazier, no modelado) y cede antes; la placa plana es la cota
baja y se devuelve también (`flatBreakN`).

A la placa llega la componente perpendicular de la fuerza del deslizador (la normal al material N): con la uña
inclinada un ángulo β sobre la superficie, `F⊥ = N·(cos β + μ·sin β)` al rayar tirando (la fricción empuja la punta
hacia arriba) y `N·cos β` al apretar. β es el ángulo de ataque, que define la unidad 1g; mientras tanto, **45°
(estimación)**: no hay medición del ángulo de la uña al rayar; el caso medido más parecido es la inclinación del dedo en
una pantalla táctil, de 15° a 65° (Holz & Baudisch 2010), y 45° es su centro.

### 2.2 Datos

| Base | t (mm) | σ_f (MPa) | Modo | Calidad y fuentes |
|---|---|---|---|---|
| Uña natural | 0,49 | 63,7 | se dobla (dúctil a humedad normal) | primaria: uña sana, 0,49 ± 0,15 mm, 63,7 ± 13,4 MPa de resistencia a tracción (Baraldi et al. 2015); dúctil a humedad normal: E de 4,34 GPa seca a 0,47 GPa al 100 % HR (Farran et al. 2009); se agrieta en la dirección transversal, paralela al borde libre (~3 kJ/m² frente a ~6 kJ/m² longitudinal; Farren, Shayler & Ennos 2004) |
| Natural mojada | 0,49 | 12,7 (×0,2) | se dobla | la queratina de garra baja de 69 a 14 MPa empapada (Bonser, en McKittrick et al. 2012), como el módulo de la uña (Farran et al. 2009): el ×0,2 del motor |
| Gel y acrílico | 0,8 | 60 | se parte | **estimación** (sin ensayo publicado de uñas): mínimo de la ISO 20795-1 para metacrilatos autopolimerizables (tipo 2: ≥ 60 MPa, módulo ≥ 1500 MPa), dentro de lo medido en PMMA autopolimerizable (42-86 MPa; Casucci et al. 2023, 75-86); espesor de 0,8 mm en la raíz del borde libre (la guía del salón: una tarjeta, 0,76 mm, en el borde libre y el doble en el ápice) |
| Acero macizo | 0,49 | 640 | se dobla | resistencia a tracción de un acero de 200 HV (la dureza del catálogo): 640 MPa en la tabla de la DIN EN ISO 18265, dentro de los 540-750 MPa de la EN 10088-2 para el inoxidable 1.4301; espesor de la natural (**estimación**). *Unidad 4a: sustituye a la estimación por Tabor (σ ≈ H/2,8 = 700 MPa)* |
| Titanio macizo | 0,49 | 483 | se dobla | resistencia a tracción típica del titanio comercial de grado 2 (~150 HV, la del catálogo): 70 ksi = 483 MPa a 20 °C (ficha de Rolled Alloys; mínimo de la ASTM B265, 345 MPa); espesor de la natural (**estimación**). *Unidad 4a: antes, 525 MPa por Tabor* |
| Zafiro macizo | 0,49 | 760 | se parte | hojas técnicas (760 MPa perpendicular al eje c, 1035 paralelo; McDanel, UQG Optics) |
| Diamante macizo | — | — | no se calcula | sin dato: `nail` = null |

En las uñas dúctiles se usa la resistencia a tracción medida, como en la natural: la rótula plástica de una placa pide
σ_flujo·Z_p ≈ 1,3-1,5·σ_flujo·Z, del orden de Rm·Z (**estimación** del modelo). En los frágiles, la resistencia a flexión.

Anchura en la raíz: 11,0 ± 1,0 mm (índice de mujeres; 13,0 en hombres; Boike et al. 2025). Todas las uñas siguen la
curvatura de la natural (estimación para las artificiales y las macizas).

### 2.3 Cargas con las que cede (rayando, μ = 0,5, ataque 45°)

| Forma (uña libre) | Natural | Mojada | Gel/acrílico | Acero | Titanio | Zafiro |
|---|---|---|---|---|---|---|
| Cuadrada y redonda (4 mm) | 27,5 N | 5,5 | 41 | 276 | 209 | 328 |
| Ataúd y almendra (6 mm) | 18,3 | 3,7 | 27 | 184 | 139 | 219 |
| Stiletto (8 mm) | **13,8** | 2,8 | 20,5 | 138 | 104 | 164 |
| Stiletto XL (12 mm) | 9,2 | 1,8 | 13,7 | 92 | 70 | 109 |

(Acero y titanio con las resistencias medidas de la unidad 4a; con Tabor eran 302/202/151/101 y 227/151/113/76 N.)

Apretando (sin fricción) son un 50 % más. La afirmación de FISICA.md («una stiletto real se partiría mucho antes de
30 N») se cumple: la natural cede a ~14 N y el gel o el acrílico a 13-28 N según la fricción.

### 2.4 Qué no predice

El aplastamiento de la «C» con la carga, la fatiga, el despegue del gel o del acrílico de la uña natural, la rotura
por el pliegue de la uña (onicosquisis) ni la pérdida de fuerza de la mano al doler. Las garras no son uñas: son
gruesas y cónicas y no se doblan en el banco (sus roturas, tema 4).

---

## 3. Recuperación elástica

### 3.1 Modelo

`compute()` da la profundidad **bajo carga**. Al retirar la punta el material devuelve su parte elástica (Oliver &
Pharr 1992): la descarga sigue `P = α·(h − h_f)^m`, la rigidez del contacto es `S = 2E'·a` (Sneddon) y, con el
contacto plástico `P = H·π·a²`,

`h_max − h_f = m·P/S = m·π·a·H/(2E')`, `E' = E/(1−ν²)`, `m = 1,5`

(Oliver & Pharr midieron m = 1,25-1,51 en seis materiales, también con pirámides: la huella residual no es plana).
Stilwell & Tabor (1961) ya vieron lo esencial: al sacar un cono el diámetro de la huella casi no cambia y la
profundidad sí, más cuanto mayor es H/E. Consecuencias: los polímeros (barniz, ABS, H/E' ≈ 0,05) recuperan mucho y una
punta roma más que una afilada; los metales (H/E' ≈ 0,005-0,01), casi nada.

- Se usa la capa del **fondo** de la huella. En un coche, la pintura mientras no se atraviesa y la chapa en cuanto la
  punta llega a ella; lo cortado por encima no vuelve (el residual no sube de la interfaz): si la garra llegó al
  metal, el metal queda al aire.
- No se aplica a la piel (tiene su modelo por capas), a la madera (celular y anisótropa: recupera por otras vías, con la
  humedad) ni a lo perforado (el agujero no se cierra).

### 3.2 Ejemplos

| Ensayo | Bajo carga | Residual | Recupera |
|---|---|---|---|
| Uña almendra, 4 N, barniz | 3,5 µm | 0 | todo: solo remolino |
| Ídem, 20 pasadas | 11,6 µm | 3,1 µm | 73 % |
| Garra de gato, 15 N, ABS | 682 µm | 648 µm | 5 % |
| Stiletto de zafiro, 30 N, acero | 23,6 µm | 21,4 µm | 9 % |
| Garra de gato, 15 N, coche | 110 µm | 110 µm | 0: el metal queda al aire |

### 3.3 Qué no predice

La recuperación viscoelástica de los polímeros (sigue horas después), el «reflow» del barniz con calor, el
amontonamiento en los bordes del surco (pile-up) y la recuperación de la madera con la humedad.

---

## 4. Garras reforjadas frágiles (modelo informativo)

Una punta dura que se clava de frente en un metal más blando está en compresión triaxial y no se rompe (los
indentadores Vickers de diamante o las bolas de zafiro sobreviven a cientos de newtons). Lo que la mella es la carga
**lateral**: la fricción al arrastrar o un golpe oblicuo. Modelo (estimación): la punta esfero-cónica como voladizo,
`σ(x) = 4·F·x/(π·r(x)³)` con r(x) el radio de su sección a la distancia x del vértice (`Contact.contact_radius`),
buscando el x más cargado desde el final de la esfera; se mella si la fuerza lateral μ·F pasa de
`F_mella = σ_f / máx(4x/(π·r³))`.

| Punta | σ_f | Fuerza lateral que la mella |
|---|---|---|
| Talón de águila de zafiro | 760 MPa (hoja técnica) | 8,1 N |
| Talón de águila de cuarzo | 52,4 MPa (sílice fundida con la superficie desgastada, Corning HPFS 7980: estimación; unidad 4i-B2, la misma de `claw_fracture.gd`; antes, 67 MPa de MakeItFrom) | 0,56 N |
| Garra de oso de zafiro | 760 MPa | 122 N |

**Por qué solo informativo.** Falta lo que decidiría el veredicto: la fuerza lateral real de un golpe (solo hay la
fricción al arrastrar), la resistencia del cuarzo monocristalino y la del diamante, y cómo avanza el mellado (la
punta se embota y aguanta más: con 55 N de lado el talón de zafiro acabaría con R ≈ 0,3 mm). Integrarlo en la
profundidad cambiaría tres escenarios del golden (las garras de zafiro que perforan coches) sin una sola medición
que lo respalde. Propuesta: `tipChip` en el resultado y una línea en el subtítulo; la profundidad no cambia.

---

## 5. Abolladura de la chapa

### 5.1 Modelo

Mecanismo rígido-plástico de una placa con carga concentrada (análisis límite: Hopkins & Prager 1953; Jones 1989):
la chapa no se abolla hasta la carga de colapso `2π·M0 = π·σ·t²/2` (M0 = σ·t²/4), sea cual sea el tamaño del panel;
después, el hoyuelo cónico de profundidad δ suma el trabajo de membrana σ·t·ΔA, con ΔA = π·δ²/2 (cálculo propio: el
área que gana un cono). Trabajo y fuerza:

`W(δ) = k·δ·(t + δ)`, `F(δ) = dW/dδ = k·(t + 2δ)`, `k = π·C·σ·t/2`

**Calibración** con la única medición a mano, Nippon Steel (2013, fig. 6): chapas de acero de 0,7 mm estiradas un
2 % y horneadas, bola de 25 mm, 200 N. Con σ el límite elástico del panel, C = 0,766 reproduce el acero BH (≈ 270 MPa
→ 0,09 mm) y, sin tocar nada, los otros tres: 270D (≈ 205 MPa: 0,23 frente a ~0,20 mm), 340H (≈ 245: 0,13 frente a
~0,115) y 440P (≈ 300: 0,046 frente a ~0,06) (lecturas de la figura). En el banco, σ es la σ0 de cada chapa (la de
Wierzbicki que ya usa el motor): en el coche moderno, 264 MPa, casi la de la figura.

En un **golpe**, la fuerza de pico sale como en la ventana (FISICA.md, apartado 15): la masa contra el muelle blando de
la pata (`MODEL.limbStiffness`, 10 N/mm, estimación del motor). La energía que no se ha quedado la punta
(`energyJ − workJ`) se reparte entre la abolladura y ese muelle: `W_panel(δ(F)) + F²/(2k_pata) = E`. Si la herramienta
se rompe antes (un colmillo, una uña), no transmite más de su carga de rotura.

### 5.2 Valores

| Chapa | Colapso (N) | Zarpazo de oso (98 J) | Empuje de 900 N |
|---|---|---|---|
| Coche moderno (acero BH 0,7 mm) | 156 | 2,8 mm | 1,7 mm |
| Coche clásico (acero dulce 0,9 mm) | 209 | 2,5 mm | — |
| Coche de aluminio (1,0 mm) | 254 | 2,2 mm | — |
| Puerta de aluminio (1,5 mm) | 425 | — | — |

El gato (1,2 J) se queda justo por debajo del colapso: no abolla. Abolladura visible: 0,1 mm, el criterio de resistencia
a la abolladura de la industria («la carga que deja una abolladura de 0,1 mm», US 7 158 922 B2) y el orden de las que
compara Nippon Steel. La chapa de plástico no se abolla en el modelo (el termoplástico recupera) y lo perforado no cuenta.

### 5.3 Qué no predice

Las abolladuras de décimas cerca del umbral (el modelo rígido-plástico empieza en el colapso), la curvatura del panel
(los paneles curvos aguantan más), los refuerzos de detrás, la velocidad del golpe y la recuperación del plástico. La
calibración es con una bola de 25 mm: con la punta de una garra la chapa se abollaría algo antes.

---

## 6. Ventanilla templada y parabrisas laminado (objetivos nuevos)

### 6.1 Ventanilla templada (`ventanilla`)

- **Perfil del temple** (Nielsen, Schneider & Kraus 2022): `σ(ζ) = ½·σS·(1 − 3ζ²)`, ζ = 2z/t; la compresión de la
  superficie es el doble de la tracción del centro y se anula a **0,211·t** (el 21 % del espesor). Compresión media de
  esa capa: 0,455·σS.
- **σS = 100 MPa (estimación).** La CEPE R43 exige entre 40 y 400 trozos por cuadrado de 5 × 5 cm (450 si t ≤ 3,5 mm);
  con la relación energía-trozo de Nielsen et al. eso corresponde a 81-144 MPa. Se toma 100, dentro de los 80-150 MPa
  medidos en los templados comerciales (Achintha 2020, con polariscopio de luz difusa) y por encima de los 69 MPa que
  exige la ASTM C1048 al templado completo. (Los 120 MPa de la EN 12150-1 son la resistencia a flexión característica, no
  la compresión.) Espesor: 4 mm, el de las ventanillas de Europa y Japón (5 mm en EE. UU.; just-auto).
- **Estalla** (entero, en trocitos) si:
  1. la flexión llega a 120 MPa (EN 12150-1, vía Saint-Gobain 2018): el mismo `pane_break` de Roark de la ventana,
     con fgk = 120: **~540 N** en una ventanilla de ~50 cm (radio equivalente 250 mm, estimación) frente a ~200 N del
     recocido del mismo tamaño; o
  2. una punta **dura** (r ≥ 1) abre una grieta que atraviesa la capa comprimida: la grieta de Anstis con el afilado de
     la punta tiene que vencer K_c más el cierre de la compresión media, `K_res = 1,12·(2/π)·σ̄·√(π·d0)`, a la
     profundidad d0 = 0,21·t (`pierce_load`, modelo). Con 4 mm: 1019 N con un Vickers, 345 N con la garra de oso
     (26°), 220-240 N con garras de 14-16°, 1340 N con la uña cuadrada (75°). Es el truco del martillo de emergencia:
     una garra de tigre de diamante apretada con 260 N la hace estallar sin fuerza para romperla por flexión.
- **Trozos**: energía elástica `U_D = (1−ν)·σS²/(5E)` = 21,7 kJ/m³ y tamaño `δ = 122,1 J/m² / U_D` = **5,6 mm**
  (Nielsen et al. 2022, ec. 2 y 4, R² = 0,93) en un panal hexagonal: **~91 trozos por 5 × 5 cm**.
- Datos del objetivo en `Glazing.SIDE_WINDOW` (4 mm, 550 HV, 72 GPa, μ 0,6, `pane`, `frac`, `fact`, `source`, `quality`).

### 6.2 Parabrisas laminado (`parabrisas`)

- Dos hojas de 2,1 mm de vidrio recocido y 0,76 mm de PVB (la construcción 2,1/0,76/2,1 de los fabricantes, p. ej.
  Pilkington; los parabrisas miden 5-7 mm). Flexa como una hoja de 4,2 mm (el PVB acopla las dos a la velocidad de un
  golpe: estimación, apoyada en que a corta duración y temperatura ambiente el laminado se comporta como el monolítico,
  Galić et al. 2022) con fgk = 45 MPa: **~210 N** en ~80 cm (radio equivalente 400 mm, estimación).
- **Se agrieta** (estrella y telaraña) por flexión o por grietas de contacto, pero **no cae**: la lámina sujeta los
  trozos.
- **Atravesarlo**: la homologación solo garantiza que una bola de 2260 g y 82 mm soltada desde 4 m (**88,7 J**) no
  atraviesa en 5 s una probeta de 300 × 300 mm (JIS R 3212; CEPE R43 equivalente). Con más energía el modelo solo
  puede decir que **podría** atravesarlo (`penetrationRisk`); con una punta afilada hará falta menos (sin medición).

### 6.3 Qué no predice

El comportamiento dinámico de proyectiles pequeños y duros: la chinita de cerámica que revienta una ventanilla o la
bola de 227 g de la R43 no caben en el modelo cuasiestático de la hoja (la fuerza de pico sería la de un muelle sin
masa y la placa real tiene inercia; Kozłowski et al. 2021 miden 13-49 J con una bola de 4,11 kg en templados de 5-15
mm). La curvatura del parabrisas (curvo y pegado: aguanta más que la placa plana), el desgarro del PVB con puntas y el
reparto de trozos cerca de los bordes.

---

## 7. Guía de integración (modelo 2.0)

### 7.1 Orden de cálculo en `compute()` (rama `if v2:`)

```text
tool = resolve_tool(p); tip = Contact.tip_geometry(tool.area, tool.alpha, tool.baseR)
sliding = method == "rayado"
res = (lo del 1.x con la fuerza pedida)

# 1. La uña cede (solo uñas: sin claw; base con datos)
nail = Bending.evaluate(base.id, geom.reach, tool.wet, force, target.mu, sliding[, ataque de la 1g])
si nail != null:
    si golpe (punción + strike): como fBreak: si _peak_res(...) > nail.breakN → nail.broken = true y
        h = min(h, solve(nail.breakN))           # la receta del colmillo
    si no, si nail.broken: repetir el ensayo con force = nail.breakN (la fuerza que llega a la punta)
f_tip = fuerza que llega a la punta (con la palanca del desgarro si la hay)

# 2. Fractura (materiales frágiles; props() != null)
fracture = Fracture.evaluate(tool, tip, target, f_tip, sliding, target.mu, depthUm, a_um)

# 3. Recuperación (todo menos piel, madera y lo perforado)
recovery = Recovery.evaluate(target, depthUm, a_um, through)
residualDepthUm = recovery.residualDepthUm si recovery != null, si no depthUm

# 5. Abolladura (chapas metálicas no perforadas)
dent = Dent.evaluate(target, f_tip, strike_y_punción, energyJ − workJ, MODEL.limbStiffness, through[, fBreak])

# 6. Vidrios de coche (la hoja se parte como la ventana: pane_break con su fgk)
templado:  glazing = Glazing.tempered_result(target, peakN, paneN, tool.hv/target.hv >= 1, f_tip, tip.tanA)
           shattered = glazing.shattered (la punta pasa por el hueco, como en la ventana)
laminado:  glazing = Glazing.laminated_result(target, peakN, paneN, fracture.cracks, energyJ)
           (no se rompe en pedazos: nada de shattered; la punta no pasa del vidrio si no hay penetrationRisk)

# 4. Mellado (garras reforjadas en zafiro o cuarzo)
tipChip = Fracture.tip_chip(inlay.id, tip, tool.reach, f_tip, target.mu si rayando si no 0)
```

`a_um` es el radio del contacto bajo carga que ya calcula `_solid_result` (su variable `a_um`; fuera de las chapas
coincide con `grooveWidthUm/2`, y en una chapa no, porque el agujero se recorta con la anchura de la garra).

### 7.2 Campos nuevos del resultado

Todos presentes en el modelo 2.0; `null` cuando no se calculan (el test de contrato de la 1.x lo exige).

| Campo | Tipo | Cuándo es null |
|---|---|---|
| `fracture` | `{ cracks, mode: "hertz" \| "radial" \| "none", pattern: "herradura" \| "cono" \| "astillado" \| "radiales" \| null, hertzN, hertzStaticN, hertzFreeN, toolElastic, harderTool, radialN, radialContactUm, crackUm, ringUm, coneAngleDeg, mu, k, valid, quality, source }` | el material no es frágil |
| `nail` | `{ breakN, perpN, flatBreakN, broken, mode: "dobla" \| "parte", factor, stressMPa, lengthMm, thicknessMm, curveRadiusMm, strengthMPa, quality, source }` | garras y uñas sin datos (diamante) |
| `recovery` | `{ residualDepthUm, recoveredUm, fraction, exponent }` | piel, madera, perforado |
| `residualDepthUm` | float (µm) | igual que `depthUm` cuando no hay recuperación (nunca null) |
| `dent` | `{ depthMm, peakN, panelJ, limbJ, collapseN, visible }` | no es chapa metálica o está perforada |
| `glazing` | templado `{ kind: "templado", shattered, cause: "flexión" \| "grieta" \| null, bendN, pierceN, compressionMm, fragmentMm, fragments25, energyDensity }`; laminado `{ kind: "laminado", cracked, penetrationRisk, cause, bendN, penetrationJ }` | ni templado ni laminado |
| `tipChip` | `{ chipN, lateralN, chipped, quality, source }` | no es una garra reforjada en zafiro o cuarzo |

### 7.3 Veredictos y prioridad

De más a menos prioritario (el primero que se cumple manda; el daño hecho se conserva: capa, profundidad, severidad):

1. **La herramienta cede**: «SE ROMPE LA PUNTA» (colmillo, como en el 1.x); «SE DOBLA LA UÑA» (`nail.mode` "dobla") o
   «SE PARTE LA UÑA» ("parte") **solo si hubo daño** (`scratched` verdadero). Si no lo hubo («NO RAYA», «ROZA /
   REMOLINO»…), el veredicto se queda y la flexión va en el subtítulo: así no se pierde la lección de durezas.
2. **Vidrios**: «ROMPE EL VIDRIO» (ventana, 1.x) · «ESTALLA LA VENTANILLA» (`glazing.shattered`) · «SE AGRIETA (NO
   CAE)» (`glazing.cracked`).
3. **Abolladura** al punzar o golpear sin perforar con `dent.visible`: «ABOLLA LA CHAPA» (coches) o «ABOLLA LA PUERTA»
   (puerta de aluminio). Rayando, el veredicto de la pintura se queda y la abolladura va en el subtítulo (surco abollado).
4. **Grietas de Hertz** (`fracture.mode == "hertz"`, sin surco): «GRIETAS DE HERTZ» rayando, «CONO DE HERTZ» apretando.
5. El veredicto del 1.x. En los materiales **no frágiles** se clasifica con `residualDepthUm` (lo que se ve); en los
   frágiles, con `depthUm` (lo que se ve son las grietas y el astillado). En los frágiles con `fracture.mode == "radial"`
   el veredicto sigue siendo «RAYA»/«RAYA LEVE»/«PERFORA · ASTILLA», con el subtítulo del astillado.

Colores: los del 1.x por gravedad (coral para las roturas, dorado para las grietas de Hertz y las uñas que se doblan
sin daño grave, menta cuando nada cede).

### 7.4 Textos sugeridos (subtítulos; los números con `Format`/`Js`)

- GRIETAS DE HERTZ: «no raya: la punta roma se queda en contacto elástico, pero al deslizar abre grietas en herradura
  desde ~{hertzN} N (conos de Hertz a medias)».
- CONO DE HERTZ: «la punta roma no entra, pero a ~{hertzN} N salta un anillo que baja en cono bajo la superficie».
- Surco con astillado: «surco con grietas laterales que astillan el borde (~{crackUm} de grieta)».
- SE DOBLA LA UÑA: «la uña se dobla a ~{breakN} N: el resto de la fuerza se queda en tu dedo» · con ataque 45° y la
  «C» de la uña.
- SE PARTE LA UÑA: «el {acrílico|gel|zafiro} se parte a ~{breakN} N: la uña libre de {L} mm hace de palanca».
- Sin daño y uña cedida: «(además, a ~{breakN} N la uña se dobla)».
- Recuperación: «se hunde {depthUm} bajo carga; al levantar la punta el barniz recupera y queda {residualDepthUm}».
- ABOLLA LA CHAPA: «no la perfora, pero la abolla ~{depthMm} mm: la chapa se queda {panelJ} J y el resto lo amortigua
  la pata».
- ESTALLA LA VENTANILLA (flexión): «el golpe da ~{peakN} N y el templado se parte desde ~{bendN}: estalla en ~{n}
  trocitos de ~{fragmentMm} mm por cada 5 × 5 cm, romos y sin filo».
- ESTALLA LA VENTANILLA (grieta): «la punta dura abre una grieta que atraviesa la capa comprimida (~{compressionMm} mm):
  toda la energía del temple se libera de golpe. Es el truco del martillo de emergencia».
- SE AGRIETA (NO CAE): «se agrieta en estrella y telaraña, pero la lámina de PVB sujeta los trozos» · con
  `penetrationRisk`: «con {energyJ} J supera los 88,7 J que garantiza la homologación: podría atravesarlo».
- Mellado (informativo): «la punta de {zafiro|cuarzo} se mella: aguanta ~{chipN} N de lado».

### 7.5 Objetivos nuevos del catálogo 2.0 (unidad 1c: `catalog.gd`)

`Glazing.TARGETS` (`SIDE_WINDOW` y `WINDSCREEN`) tienen las claves de un objetivo de `TARGETS` más `frac`,
`tempered`/`laminated`, `source` y `quality`. Van al catálogo tal cual. `Lab.target_sub` debería escribir «templado ·
frágil» y «laminado · frágil»; `damage_report` puede mostrar los trozos o la telaraña. Los datos de fractura de los
frágiles del 1.x están en `Fracture.BRITTLE` (por id): no hace falta tocar `data.gd`.

### 7.6 Dibujos y animaciones

- **Hertz**: anillo de radio `ringUm` (1,1-1,4 veces el contacto: Mouginot & Maugis 1985) y cono con
  `coneAngleDeg` = 22° con la superficie (estimación sobre la fig. 1b de Lawn & Marshall 1984), base de radio
  `crackUm`. Rayando: herraduras abiertas hacia delante, separadas ~2 radios de contacto (estimación sobre la fig. 3
  de Lawn & Marshall 1984), a lo largo del surco.
- **Astillado**: grietas laterales de longitud `crackUm` a los dos lados del surco, desconchones semicirculares; al
  apretar, cuatro radiales en cruz desde las esquinas (Vickers) o en estrella (cono).
- **Templado que estalla**: panal de `fragments25` celdas por cada 5 × 5 cm (tamaño `fragmentMm`), con dos trozos
  alargados en remolino junto al origen («whirl fragments», Nielsen, Olesen & Stang 2009); la grieta cruza la hoja a ~1500 m/s
  (valor típico del vidrio, estimación): en pantalla, instantáneo.
- **Laminado**: estrella de 6-12 radiales desde el impacto y anillos concéntricos cada vez más separados (estimación
  visual); la hoja se queda en su sitio y se abomba si hay `penetrationRisk`.
- **Abolladura**: hoyuelo de profundidad `depthMm` y diámetro ~20-40 veces la profundidad (estimación visual de
  abolladuras de granizo), sombreado suave.
- **Uña que se dobla**: el borde libre gira en la raíz; ángulo de dibujo ~15-25° (estimación); si se parte, la punta
  se separa en la raíz del borde libre.
- **Huella residual**: dibujar el surco con `residualDepthUm` y, durante la animación del ensayo, con `depthUm` (la
  punta dentro): al levantarla, el fondo sube.

### 7.7 Otros sitios

- `damage_stage` (lab.gd): una abolladura visible es daño de carrocería (etapa 2) aunque no pase de la pintura.
- Sonidos (`sfx.gd`): «ESTALLA LA VENTANILLA» con el de «ROMPE EL VIDRIO»; «SE PARTE LA UÑA» con el de la punta rota.
- Logros: «💥 Cristal roto» ya salta con `shattered`; sugerencias nuevas: «🔨 Martillo de emergencia» (estalla por
  grieta), «💅 Uña rota» (se parte la uña).
- Fundamentos: una tarjeta «Frágiles» nueva (Auerbach y deslizamiento) y otra «Recuperación» (Oliver-Pharr).

### 7.8 Escenarios del golden 1.x que cambian

Con estas reglas cambian **8 de los 40** escenarios (veredicto o profundidad; calculados con los módulos y el motor
1.x, como en `test_pulido_spec.gd`):

| Escenario | 1.x | 2.0 | Por qué |
|---|---|---|---|
| uña almendra 4N sobre pintura | ARAÑAZO EN BARNIZ · 3,5 µm | ROZA / REMOLINO · 3,5 µm bajo carga, 0 residual | el barniz recupera todo (tema 3) |
| uña stiletto 30N sobre piel | ARAÑAZO PROFUNDO · 882 µm | SE DOBLA LA UÑA · 75 µm | cede a 13,8 N (tema 2) |
| uña cuadrada 30N sobre piel | RASGUÑO BLANCO · 18 µm | SE DOBLA LA UÑA · 18 µm | cede a 27,5 N |
| uña + diamante 30N sobre zafiro | RAYA · 4,4 µm | SE DOBLA LA UÑA · 2,9 µm (con astillado) | cede a 19,6 N; la gema ya había astillado el zafiro |
| uña + cuarzo 30N sobre pantalla móvil | RAYA · 7,2 µm | SE DOBLA LA UÑA · 3,6 µm (con astillado) | cede a 18,3 N |
| uña almendra 30N ×20 sobre piel | RASGUÑOS QUE SANGRAN · 75 µm | SE DOBLA LA UÑA · 75 µm | cede a 18,3 N; el daño es el mismo |
| uña stiletto de metal, golpe, coche moderno | PERFORA LA CHAPA · 6,1 mm | SE DOBLA LA UÑA · 274 µm | perforar pide ~700 N en la punta y la uña de acero de 0,49 mm cede a 207 N (con Tabor eran 227 N y 303 µm) |
| uña stiletto de metal, golpe, coche clásico | PERFORA LA CHAPA · 5,3 mm | SE DOBLA LA UÑA · 304 µm | ídem (con Tabor, 335 µm) |

Con campos nuevos pero el mismo veredicto y profundidad: «uña natural sobre vidrio», «uña natural sobre acero 100
pasadas» y «uña almendra húmeda 30N sobre pintura» (la uña cede, pero no hubo daño: va en el subtítulo); «oso 300N
sobre pintura» (abolla 0,32 mm), «oso 300N desgarro» (0,81), «casuario 500N» (0,77), «avestruz 900N» (1,7), «oso de
diamante 300N» (0,32 mm; residual 385 de 389 µm) y «uña almendra 20 pasadas» (residual 3,1 µm). Ninguno de los 40
tiene una punta roma y dura sobre un frágil: las grietas de Hertz no cambian ninguno.

Dependencia de estimaciones: los seis cambios por la uña dependen del ángulo de ataque de 45° y de que el gel, el
acrílico y las uñas macizas sigan la «C» de la natural. Decisión para el coordinador: integrar la flexión en todas las
uñas (lo que se propone) o solo en las del salón.

### 7.9 Casos de referencia

`godot/tests/fixtures/spec/pulido-materiales.json`: lista de `{ id, note, input, expect, source }` con el formato de
CONTRATOS.md y las convenciones de la unidad 1a: `input` con los ids del oráculo (`trial()` de
`export-fixtures.mjs`) y `"model": "2.0"`; `expect` con rutas con puntos dentro del resultado (`fracture.hertzN`,
`nail.broken`…); `tol` **relativa** (`|x − value| ≤ tol·|value|`); `value` sin `tol` exige igualdad exacta
(booleanos, textos y null); `min` y `max` inclusivos. Los objetivos `ventanilla` y `parabrisas` son los de
`Glazing.TARGETS`. `test_pulido_spec.gd` reconstruye los campos de la 1f; los veredictos los tiene que dar la
integración. 37 casos: 11 de fractura, 7 de uñas, 5 de recuperación, 6 de abolladura, 6 de vidrios de coche y 2 de
mellado.

### 7.10 Dependencias con otras unidades

- **1g (ángulo de ataque):** `Bending.evaluate(..., attack_deg)` lo recibe; sin él, 45°. Si la 1g define el ángulo de
  cada forma de uña, se pasa aquí y los casos de las uñas se regeneran con su valor (y se avisa al físico).
- **1g (zonas del cuerpo):** no interviene (la piel no entra en estos módulos).
- **1a (aguijones):** un aguijón sobre un frágil pasa por `Fracture.evaluate` como cualquier punta (es blando: nunca
  agrieta).
- **1c (infraestructura):** `catalog.gd` (objetivos nuevos), `physics.gd` (rama 2.0), `lab.gd` y `lab_state.gd`.

### 7.11 Estado de la integración (unidad 4a)

Hecho en `physics.gd` (ramas `if c.v2:`), `catalog.gd` (`V2_TARGETS`: ventanilla y parabrisas), `lab.gd`
(`target_sub`, `damage_stage`, `damage_report`, `FUNDAMENTOS_V2`), `sting_lab.gd`, `sfx_insects.gd` y la tarjeta del
resultado (`app/lab/result_card.gd`). Los 37 casos de referencia pasan por `compute()` (`test_materiales_v2.gd`) y el
golden 2.0 cambia en los ocho escenarios del §7.8 (con las profundidades nuevas de la stiletto de acero) más nueve con
solo el subtítulo o los campos nuevos; añade diez escenarios de estos temas.

Decisiones del coordinador: la flexión en **todas** las uñas, y el ángulo de ataque de 45° definido en un solo sitio
(`Physics.attack_deg(p)`: `p.attack_deg` o `Bending.ATTACK_DEG`), para que la parte B lo conecte con `attack.gd`.

Lo que la guía dejaba abierto, cómo se ha resuelto:

- **Golpe con una uña.** Cede si la resistencia del camino menos la adhesión llega a su carga de cesión, y la punta se
  queda donde la resistencia llega a `breakN + F_adh` (la adhesión no pasa por la uña): da exactamente lo mismo que la
  receta de la referencia (el empuje con la carga de cesión). Contra una hoja que la uña sí puede partir (su carga de
  cesión pasa de la de la hoja) y que el golpe rompe, la hoja cede antes y la uña no llega a doblarse. También el
  parabrisas: el modelo supone que, agrietado, el laminado es mucho más blando y el resto del golpe no vuelve a subir la
  fuerza (suposición, sin medición con puntas; empujando es distinto, ver abajo).
- **Golpe de uña contra la piel.** Si la uña no aguanta la fuerza con la que la piel se rompe (Davis 2004), se dobla
  antes y no perfora: ninguna uña natural perfora la piel, ni de un golpe.
- **Fuerza en la punta** (la de los módulos): la pedida, ya limitada por la uña, con la palanca del desgarro; en un
  golpe, la resistencia del camino (la del modelo de penetración), sin pasar de la rotura del colmillo o de la cesión de
  la uña y, en una hoja, del pico del golpe.
- **Vidrios.** A la hoja no llega más de lo que aguanta la herramienta (la uña, como el colmillo en la 1.x). La templada
  estalla por `glazing.shattered` o si la punta la atraviesa. El laminado nunca se rompe en pedazos; sin el riesgo de la
  homologación la punta no pasa del vidrio, y con él puede pasar (`through`).
- **Empujar una hoja que la uña sí puede partir** (una uña maciza de acero, titanio o zafiro contra el vidrio de ventana,
  por encima de su carga de cesión): la hoja se parte con una carga que la uña aguanta y la punta pasa por el hueco, así
  que la uña no llega a ceder. El ensayo se repite con la fuerza pedida y es el de la 1.x (más los campos nuevos):
  «ROMPE EL VIDRIO», no «SE DOBLA LA UÑA». La resistencia de la hoja apenas crece con el radio del contacto (un 0,1 % en
  estos ensayos), así que con más fuerza se sigue partiendo. El laminado no: se agrieta, la lámina lo sujeta y se puede
  seguir empujando hasta que cede la uña («SE DOBLA LA UÑA» con el parabrisas agrietado en el subtítulo).
- **Recuperación.** Con el radio de contacto bajo carga (`a_um`). En los no frágiles el veredicto y la severidad salen de
  la huella residual; el modo de abrasión (Dp) sigue siendo el de bajo carga, y el desgaste usa el veredicto nuevo.
- **Abolladura.** La fuerza que llega a la chapa no pasa de la rotura del colmillo ni de la cesión de la uña.
- **Grietas de Hertz sin surco:** `scratched` sigue en falso (no hay surco; el daño es `fracture.cracks`). Por eso una uña
  que cede sobre un frágil sin rayarlo deja el veredicto de las grietas y la cesión en el subtítulo.
- **toolBroken** es verdadero cuando la uña es el veredicto. Sonidos (`sfx_insects.gd`): la uña que se dobla cruje como
  el aguijón que pandea; la que se parte, el chasquido de la punta rota; los vidrios de coche suenan a vidrio, y el
  parabrisas que se agrieta al punzarlo, a vidrio que cruje.
- **Uña con gema mojada:** se usa `tool.wet` (como en la 1.x, una uña con gema no se ablanda); la placa de debajo sí es
  queratina: queda como propuesta.
- **Aguijones:** sus campos salen de `Physics.materials_fields` con el ensayo 1.x de siempre (`Sting.solid_params`); el de
  quitina nunca agrieta un frágil y el veredicto sigue siendo el suyo.
- **Textos:** los del §7.4; la recuperación se cuenta a partir de un 25 % recuperado (elección de texto).

Cambios de datos (regla del coordinador: todo con la medición publicada o, si no la hay, el caso medido más parecido):
la resistencia de las uñas de acero y de titanio pasa de la estimación por Tabor (700 y 525 MPa) a la resistencia a
tracción de un metal con la dureza del catálogo (640 MPa por la DIN EN ISO 18265; 483 MPa, titanio de grado 2). Nuevas
fuentes: Farren, Shayler & Ennos 2004 y Farran et al. 2009 (la uña), Casucci et al. 2023 (PMMA autopolimerizable),
Holz & Baudisch 2010 (inclinación del dedo), Achintha 2020 y la ASTM C1048 (compresión de los templados), Galić et al.
2022 (PVB), el criterio de 0,1 mm de la industria (US 7 158 922 B2) y los espesores de los fabricantes.

Con otras unidades: los casos de `pulido-biologia.json` con uñas por encima de su cesión (p. ej. la stiletto a 30 N en
la piel) o con la uña almendra a 4 N en el coche suponen la física sin estos cambios; su referencia es ahora
explícitamente el motor 1.x, y la parte B tendrá que recalcularlos cuando junte la biología con esto.

---

## 8. Pendientes (qué falta para mejorarlo)

- **Frágiles:** un umbral de Hertz medido en vidrio sodocálcico y en la pantalla con esferas de zafiro o de metal duro
  (para cambiar el sesgo de ×2 por un dato); la fricción medida de cada par; la tenacidad de la encimera de cuarzo
  aglomerado; la dependencia del umbral radial con el ángulo de la punta.
- **Uñas:** el ángulo de ataque de cada forma (1g); el espesor y la resistencia a flexión del gel y del acrílico de
  uñas (no hay ensayo publicado a mano); una medición de la carga con la que se dobla el borde libre (validaría la «C»
  y el efecto Brazier).
- **Garras frágiles (tema 4):** la resistencia a flexión del cuarzo monocristalino y del diamante; la carga lateral de
  un zarpazo; un ensayo de mellado de puntas cónicas.
- **Abolladura:** abolladuras medidas con impactadores puntiagudos y en paneles curvos; la energía de las abolladuras
  de granizo con su profundidad (ensayos de granizo artificial) para validar la parte de membrana.
- **Vidrios de coche:** la compresión superficial medida de ventanillas reales; el comportamiento dinámico de
  proyectiles pequeños; la energía para atravesar un laminado con una punta.

## 9. Fuentes

- Achintha M. (2020). Construction of full residual stress depth profile in glass using the knowledge of surface stress. *Challenging Glass 7*, Ghent University. doi:10.7480/cgc.7.4504 (templados comerciales: 80–150 MPa de compresión superficial)
- Anstis G.R., Chantikul P., Lawn B.R., Marshall D.B. (1981). A critical evaluation of indentation techniques for measuring fracture toughness: I, direct crack measurements. *J. Am. Ceram. Soc.* 64:533–538. doi:10.1111/j.1151-2916.1981.tb10320.x
- ASTM C1048. Standard specification for heat-strengthened and fully tempered flat glass (templado completo: compresión superficial ≥ 69 MPa, 10 000 psi).
- ASTM B265 y Rolled Alloys (2025), ficha del titanio de grado 2/2H: resistencia a tracción mínima 50 ksi (345 MPa) y típica 70 ksi (483 MPa) a 20 °C.
- Baraldi A., Jones S.A., Guesné S., Traynor M.J., McAuley W.J., Brown M.B., Murdan S. (2015; en línea en 2014). Human nail plate modifications induced by onychomycosis: implications for topical therapy. *Pharm. Res.* 32:1626–1633. doi:10.1007/s11095-014-1562-5
- Casucci A., Verniani G., Barbieri A.L., et al. (2023). Flexural strength analysis of different complete denture resin-based materials obtained by conventional and digital manufacturing. *Materials* 16:6559 (PMMA autopolimerizable: 74,8 ± 7,8 y 86,1 ± 7,1 MPa)
- DIN EN ISO 18265. Metallic materials — Conversion of hardness values (aceros: 200 HV ↔ 640 N/mm²).
- EN 10088-2. Aceros inoxidables, chapa y banda (1.4301: Rm 540–750 MPa).
- Farren L., Shayler S., Ennos A.R. (2004). The fracture properties and mechanical design of human fingernails. *J. Exp. Biol.* 207:735–741. doi:10.1242/jeb.00814 (cortar la uña en transversal cuesta ~3 kJ/m², la mitad que en longitudinal)
- Galić J., Stepinac L., Bošnjak A., Zovko I. (2022). Influence of PVB interlayer mechanical properties on laminated glass elements design in dependence of real time-temperature changes. *Polymers* 14:4402 (a corta duración y temperatura ambiente, el laminado se comporta como el monolítico)
- Holz C., Baudisch P. (2010). The generalized perceived input point model and how to double touch accuracy by extracting fingerprints. *CHI 2010* (inclinaciones del dedo de 15° a 65° al tocar)
- Katie Barnes Academy. Enhancements: how to decide the right thickness (guía del salón: el grosor de una tarjeta en el borde libre y el doble en el ápice).
- Pilkington. Laminated sidelights (construcción 2,1/0,76/2,1 mm); just-auto, «Automotive glass: a window of opportunity» (ventanillas de 4 mm en Europa y Japón, 5 mm en EE. UU.).
- US 7 158 922 B2 (Ispat Inland, 2007). System and method for prediction of panel performance under localized loading conditions («a common measure of dent resistance is the load to cause a dent of depth 0.1 mm»).
- Boike S., Baker M.J., Ray L., Odenthal A., Bohn D., Van Heest A. (2025). Investigating normative measurements of the thumb and index finger to aid in reconstructive surgery. *J. Hand Surg. Glob. Online* 7:100792. doi:10.1016/j.jhsg.2025.100792
- Conrad H., Keshavan M., Sargent G. (1979). Hertzian fracture of Pyrex glass under quasi-static loading conditions. *J. Mater. Sci.* 14:1473–1494. doi:10.1007/BF00549324
- Corning (2012). Corning Gorilla Glass 2, product information sheet (Rev. B_050912).
- Farran L., Ennos A.R., Starkie M., Eichhorn S.J. (2009). Tensile and shear properties of fingernails as a function of a changing humidity environment. *J. Biomech.* 42:1230–1235. doi:10.1016/j.jbiomech.2009.03.020 (E de 4,34 GPa al 0 % HR a 0,47 GPa al 100 %)
- Field J.E., Freeman C.J. (1981). Strength and fracture properties of diamond. *Philos. Mag. A* 43:595–618. doi:10.1080/01418618108240397
- Hamilton G.M., Goodman L.E. (1966). The stress field created by a circular sliding contact. *J. Appl. Mech.* 33:371–376. doi:10.1115/1.3625051
- He H., Qian L., Pantano C.G., Kim S.H. (2015). Effects of humidity and counter-surface on tribochemical wear of soda-lime-silica glass. *Wear* 342–343:100–106. doi:10.1016/j.wear.2015.08.016 (fricción en seco 0,3–0,4, visto en resumen)
- Hopkins H.G., Prager W. (1953). The load carrying capacities of circular plates. *J. Mech. Phys. Solids* 2:1–13. doi:10.1016/0022-5096(53)90022-2
- ISO 20795-1:2013. Dentistry — Base polymers — Part 1: Denture base polymers (flexión: tipo 2 ≥ 60 MPa, módulo ≥ 1500 MPa).
- Iwasa M., Ueno T., Bradt R.C. (1981). Fracture toughness of quartz and sapphire single crystals at room temperature. *J. Soc. Mater. Sci. Japan* 30:1001–1004. doi:10.2472/jsms.30.1001
- JIS R 3212 / CEPE R43. Ensayo de la bola de 2260 g (82 mm) desde 4 m sobre vidrio laminado de 300 × 300 mm; recuento de trozos de los templados (40–400 por 5 × 5 cm). Vistos en textos que citan las normas (patentes de láminas de PVB; resúmenes de Pilkington y glassonweb).
- Jones N. (1989). *Structural Impact*. Cambridge University Press.
- Jung J.W., Kim K.S., Shin J.H., et al. (2015). Fingernail configuration. *Arch. Plast. Surg.* 42:753–760. doi:10.5999/aps.2015.42.6.753
- Kozłowski M., Zemła K., Kosmal M., Kopyłow O. (2021). Experimental and FE study on impact strength of toughened glass—retrospective approach. *Materials* 14:7658. doi:10.3390/ma14247658
- Lawn B.R., Evans A.G. (1977). A model for crack initiation in elastic/plastic indentation fields. *J. Mater. Sci.* 12:2195–2199. doi:10.1007/BF00552240
- Lawn B.R., Evans A.G., Marshall D.B. (1980). Elastic/plastic indentation damage in ceramics: the median/radial crack system. *J. Am. Ceram. Soc.* 63:574–581. doi:10.1111/j.1151-2916.1980.tb10768.x
- Lawn B.R., Marshall D.B. (1979). Hardness, toughness, and brittleness: an indentation analysis. *J. Am. Ceram. Soc.* 62:347–350. doi:10.1111/j.1151-2916.1979.tb19075.x
- Lawn B.R., Marshall D.B. (1984). Indentation fractography: a measure of brittleness. *J. Res. Natl. Bur. Stand.* 89:435–451. doi:10.6028/jres.089.024
- Marulli M.R., Bonari J., Reinoso J., Paggi M. (2023). A coupled approach to predict cone-cracks in spherical indentation tests with smooth or rough indenters. *J. Mech. Phys. Solids* 178:105345. doi:10.1016/j.jmps.2023.105345
- McKittrick J. et al. (2012). The structure, functions, and mechanical properties of keratin. *JOM* 64:449–468. doi:10.1007/s11837-012-0302-8
- Mikowski A., Serbena F.C., Foerster C.E., Lepienski C.M. (2006). Statistical analysis of threshold load for radial crack nucleation by Vickers indentation in commercial soda-lime silica glass. *J. Non-Cryst. Solids* 352:3544–3549. doi:10.1016/j.jnoncrysol.2006.02.112
- Mouginot R., Maugis D. (1985). Fracture indentation beneath flat and spherical punches. *J. Mater. Sci.* 20:4354–4376. doi:10.1007/BF00559324
- Murdan S. (2011). Transverse fingernail curvature in adults: a quantitative evaluation and the influence of gender, age, and hand size and dominance. *Int. J. Cosmet. Sci.* 33:509–513. doi:10.1111/j.1468-2494.2011.00663.x
- Nielsen J.H., Schneider J., Kraus M.A. (2022). The in-plane expansion of fractured thermally pre-stressed glass panes. *Constr. Build. Mater.* 327:126849. doi:10.1016/j.conbuildmat.2022.126849 (preimpresión: arXiv:2110.09293)
- Nielsen J.H., Olesen J.F., Stang H. (2009). The fracture process of tempered soda-lime-silica glass. *Exp. Mech.* 49:855–870. doi:10.1007/s11340-008-9200-y
- Nippon Steel (2013). Yonemura S. et al. Advanced technologies related to simulation and evaluation for performance of automotive exterior panels. *Nippon Steel Technical Report* 103:11–17.
- Oliver W.C., Pharr G.M. (1992). An improved technique for determining hardness and elastic modulus using load and displacement sensing indentation experiments. *J. Mater. Res.* 7:1564–1583. doi:10.1557/JMR.1992.1564
- Ren L., Zhang Y. (2014). Sliding contact fracture of dental ceramics: principles and validation. *Acta Biomater.* 10:3243–3253. doi:10.1016/j.actbio.2014.03.004
- Rhee Y.-W., Kim H.-W., Deng Y., Lawn B.R. (2001). Brittle fracture versus quasi plasticity in ceramics: a simple predictive index. *J. Am. Ceram. Soc.* 84:561–565. doi:10.1111/j.1151-2916.2001.tb00698.x
- Saint-Gobain Building Glass UK (2018). Glass fundamentals 1B: the strength of glass (EN 572-1, EN 12150-1).
- Salem J.A. (2006). Slow crack growth and fracture toughness of sapphire for the International Space Station Fluids and Combustion Facility. NASA/TM-2006-214023.
- Stilwell N.A., Tabor D. (1961). Elastic recovery of conical indentations. *Proc. Phys. Soc.* 78:169. doi:10.1088/0370-1328/78/2/302
- Hojas técnicas de zafiro (UQG Optics; McDanel Advanced Ceramics): flexión 760 MPa perpendicular al eje c y 1035 MPa paralelo.
- MakeItFrom: sílice fundida, flexión 67 MPa (50–120 según el acabado); desde la unidad 4i-B2 el cuarzo usa la ficha de
  Corning (HPFS 7980: 52,4 MPa con la superficie desgastada), la misma de la rotura de las garras (`claw_fracture.gd`).
- Wiederhorn S.M. (1969). Fracture surface energy of glass. *J. Am. Ceram. Soc.* 52:99–105. doi:10.1111/j.1151-2916.1969.tb13350.x
