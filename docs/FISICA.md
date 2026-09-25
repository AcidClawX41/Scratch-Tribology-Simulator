# Modelo físico y fuentes (v2.4)

Todo lo que calcula `packages/core/src/physics.js`, en qué se basa y qué es estimación.
Es un modelo **educativo**: captura bien las tendencias y los órdenes de magnitud, no sustituye
a un ensayo de laboratorio.

Unidades internas del motor: fuerza en N · longitudes en mm (se muestran en µm) · presión y
dureza en MPa (= N/mm²; 1 HV = 9,807 MPa) · energía en mJ (= N·mm; se muestra en J).

## Qué cambió respecto a v1 (y por qué)

La auditoría de v1 (barrido de 478.800 combinaciones herramienta × material × método × fuerza)
encontró que:

- **90.286 resultados mostraban una presión de contacto mayor que la dureza de la propia punta**
  (p. ej. 10.000 MPa con una garra de queratina de ~300 MPa). Es imposible: la punta se aplasta
  antes. v2 distingue presión **nominal** (F/A, lo que la punta "pide") y presión **real**.
- La profundidad dependía de factores ad hoc (`cShape ∝ área`, `bluntF`, `pen`, `softK = 9`,
  impacto `×4`). De ahí salía la "paradoja del oso": a 300 N su garra se quedaba en el barniz.
  Con mecánica de contacto real, 300 N atraviesan los ~110 µm de pintura; la lección de la
  presión se mantiene **a igual fuerza** (test: la daga del casuario llega más hondo que la uña
  roma del avestruz).
- El alcance era 9 mm para todas las garras sin dato (el pájaro "perforaba" más que su uña; el
  tigre y el oso se quedaban cortos) y la masa de los animales no se usaba.
- El colmillo "cedía a ~4 N" solo en el texto; el motor dejaba empujarlo a 2000 N.
- La barra de severidad bajaba al pasar de la laca a la madera (102 casos no monótonos).

## 1. Geometría de la punta (esfero-cónica)

Cada punta es un cono de semiángulo **α** rematado por una esfera de radio **R**, el modelo
estándar de indentadores reales (p. ej. el Rockwell C es un cono de 120° con punta de 0,2 mm).

- `R = √(A/π)`, con `A` el "afilado" del catálogo (área de la punta, mm²).
- Tangencia esfera-cono: `a_t = R·cos α`, `h_t = R·(1 − sin α)`.
- Radio del contacto a profundidad h: `a = √(2Rh − h²)` si `h ≤ h_t`; si no, `a = a_t + (h − h_t)·tan α`.

Una punta roma trabaja en la zona esférica (h ∝ F); una afilada entra enseguida en la cónica
(h ∝ √F). Por eso **la geometría manda sobre la fuerza**.

## 2. Presión nominal y presión real

- **Nominal**: `P = N/A` (N incluye la adhesión JKR, casi siempre despreciable).
- **Real**: `min(P, H_punta, H_objetivo)`. En contacto plástico la presión media es la dureza del
  material que cede (Tabor): nunca más. La UI muestra ambas.

## 3. ¿Plastifica? Contacto elástico de Hertz

Antes de dejar huella, el contacto es elástico. Para la esfera de la punta:

- `1/E* = (1 − ν²)·(1/E_punta + 1/E_objetivo)` con ν = 0,3.
- `a_H = (3FR / 4E*)^(1/3)` y `p0 = 3F / (2π·a_H²)`.
- Empieza a plastificar cuando `p0 = 1,6·Y` (Johnson, *Contact Mechanics*, 1985), con
  `Y = H/2,8` (Tabor). Al rayar, la fricción adelanta la plastificación: se multiplica `p0` por el
  factor de von Mises `√(1 + 3μ²)`.
- Fracción plástica `φ = smoothstep(1, 2,625; q)` con `q = p0·√(1+3μ²)/(1,6·Y)`; `φ = 1` cuando la
  presión media alcanza H. En impacto se toma φ = 1 (la carga dinámica plastifica).

Resultado: una uña cuadrada a 4 N sobre el barniz queda en "remolino" (contacto casi elástico),
y una stiletto a la misma fuerza ya raya.

## 4. Quién cede: relación de durezas

- `r = HV_punta / HV_objetivo`. Con **r < 0,8 no raya: cede la punta** (se desgasta). Una punta
  raya un metal si su dureza de indentación es al menos ~1,2 veces la de la superficie (Tabor 1954,
  el criterio que recoge Pintaude 2021), y el desgaste se vuelve suave cuando la superficie supera
  ~0,8 veces la dureza del abrasivo (Richardson 1968), es decir, con r < 1,25.
- Entre 0,8 y ~2 la punta también se deforma y el surco es menos hondo. Se modela como dureza
  efectiva `H/η(r)` con `η = smoothstep(0,8; 2,0; r)`. El punto de saturación r ≈ 2 es una
  **hipótesis del modelo**.
- El embotamiento es irreversible: `η` lo marca el material más duro que la punta ha atravesado.
- Veredicto "MARCA TENUE" (pulido mutuo) si r < 1,25.

## 5. Profundidad del surco o del pozo

Contacto plástico: la carga la soporta `H·π·a²` (punción) o `H·π·a²/2` al rayar (solo trabaja el
frente del surco, definición de dureza al rayado de ASTM G171). Se resuelve la profundidad h en
la que la resistencia `F_res(h) = (H/η)·k·π·a(h)²` iguala la fuerza (bisección; `F_res` es
monótona, así que **la profundidad nunca salta**).

Multiplicadores (heurísticos, aplicados sobre la geometría para respetar las capas):
- Fracción plástica φ (apartado 3).
- Tipo de arañazo: roce 0,55 · arañazo 1 · surco profundo 1,7 (cómo se presenta la punta).
- Pasadas repetidas: `n^0,4` (sublineal: cada pasada arranca menos porque el surco se ensancha).
  Si la herramienta no marca en 1 pasada, no marca en 100.
- Desgarro (solo garras): el gancho curvo multiplica la fuerza en la punta por `1 + 1,3·curva`
  (ventaja mecánica estimada).

La profundidad mostrada es **bajo carga**: los polímeros recuperan parte al retirar la punta
(no se modela).

## 6. Sistemas multicapa

**Pintura de coche (OEM):** barniz 0–45 µm · color 45–60 · imprimación 60–85 · anticorrosivo
(e-coat) 85–110 · carrocería. Espesores según especificaciones de fabricante (Ford), total
100–150 µm. Hasta 110 µm manda el polímero (20 HV); después, la carrocería de cada coche
(apartado 14): acero de horno de 0,7 mm (101 HV), acero dulce de ~0,9 mm (92 HV), aluminio de
1,0 mm (71 HV) o termoplástico de ~2,5 mm (13 HV). Una punta de queratina (r ≈ 0,25–0,35 frente al
metal) **no puede cortar la chapa**: la profundidad se queda en 110 µm ("HASTA EL METAL"). El
plástico es más blando que el barniz: una garra sí entra en él. Una gema dura entra en todos.

**Puerta de madera barnizada:** laca de ~30 µm (18 HV) sobre roble macizo de 35 mm (~5 HV). Es el
caso inverso: capa dura sobre sustrato blando. La laca se hunde con la madera (efecto cáscara de
huevo) y su aporte decae con el **tamaño del contacto** (modelo de dureza compuesta tipo
Jönsson-Hogmark 1984, simplificado a un decaimiento exponencial): `H = H_madera + (H_laca − H_madera)·e^(−a/t)`. Con esta forma `H·π·a²` crece
siempre con `a`, así que romper la laca no produce saltos (un test lo vigila).

## 7. Piel por capas

La piel se modela como el tejido real, por capas, en la cara posterior del **brazo de un adulto**
(zona típica de un arañazo o una mordedura). En tejido blando no existe dureza Vickers: cada capa se
describe con su espesor, su rigidez `E` y su **tenacidad** `J`, la energía por unidad de área para
abrir una grieta. Hay dos: al **desgarro** (`jT`, ensayo de "pantalón": lo que gasta una garra que
rasga) y al **corte** (`jC`, lo que gasta una punta que entra de frente).

| Capa | Profundidad | E | jT (desgarro) | jC (corte) | Fuente |
|---|---|---|---|---|---|
| Capa córnea | 0–18 µm | — | (como la dermis) | 1,7 | 18,3 ± 4,9 µm en el antebrazo (Sandby-Møller 2003, biopsias); 22,6 µm (Egawa 2007, Raman). Se despega con 1–8 J/m² (Wu 2006) |
| Epidermis viva | 18–75 µm | — | (como la dermis) | 1,7 | 56,6 ± 11,5 µm en el antebrazo (Sandby-Møller 2003). Sin vasos |
| Dermis | 0,075–2,2 mm | 210 kPa | 17 kJ/m² | 1,7 kJ/m² | piel del brazo 2,2 mm (Gibney 2010, ecografía, 388 adultos); E in vivo (Iivarinen 2011); jT dermis porcina (Comley & Fleck 2010); jC corte con tijera (Pereira 1997); resistencia 21,6 MPa (Ní Annaidh 2012, piel de cadáver) |
| Hipodermis (grasa) | 2,2–13,0 mm | 1,9 kPa | 4,1 kJ/m² | 0,41 | grasa del brazo 10,8 mm (Gibney 2010); E (Iivarinen 2011); jT (Comley & Fleck 2010) |
| Fascia profunda | 13,0–13,3 mm | — | 2,1 kJ/m² | 0,21 | 297 µm la fascia pectoral (Stecco 2009, disección); jT fascia humana de cadáver 2,1 kJ/m² (Kim 2001) |
| Músculo | > 13,3 mm | ≈ 53 kPa | 0,84 kJ/m² | 0,084 | μ = 17,6 kPa relajado (Šarabon 2019, elastografía) → E ≈ 3μ; jT músculo porcino (Aryeetey 2022) |

Los `jC` de grasa, fascia y músculo son una **estimación**: el corte de la dermis (1,7) escalado
por el cociente de sus tenacidades al desgarro. Así se respeta la observación clásica de los ensayos
con cadáveres antes de la autopsia: la piel es con mucho el tejido que más resiste y, una vez
atravesada, lo de debajo cede con poca fuerza salvo el hueso (Knight 1975; ver la revisión de
Ankersen 1999). O'Callaghan et al. (1999), también con tejidos de cadáver, matizan que grasa y
músculo sí exigen algo de fuerza: aquí la exigen, pero mucho menos que la dermis. Ojo con los datos
de cadáver: el músculo pierde ~61 % de resistencia tras la muerte (Van Ee 2000), y las tenacidades
de tejidos blandos son difíciles de medir bien (Taylor 2012).

**1 · Romper la superficie** (in vivo, piel humana):
- Fuerza para perforar: `F_p = 190 N/mm² · A − 0,66 N` (mínimo 0,08 N), el ajuste lineal de
  Davis et al. 2004 (microagujas de 30–80 µm de radio de punta, en voluntarios). Fuera de ese rango
  es una extrapolación: una uña roma necesitaría ~170 N.
- En impacto también perfora si la energía supera `G_p·A`, con `G_p = 30,1 kJ/m²` (Davis 2004).
- Al **arrastrar**, la cizalla y la piel tensa por delante ayudan (la piel tensa se perfora con la
  mitad de fuerza: Knight 1975 y Green 1978, revisados por Ankersen 1999): `F_ef = N·√(1+3μ²)·enganche·palanca`. Por eso, si una
  punta perfora empujando, arrastrándola también rompe la piel (hay un test).

**2 · Entrar de frente** (punción): una punta afilada penetra acuñando una grieta plana en modo I
(Shergold & Fleck 2005, piel humana in vivo): `F = 2·jC·a(h)`, con el `jC` de la capa en la que
está la punta. Tras la dermis la resistencia **cae**; el resolvedor busca la primera capa que frena
la punta (`solveLayered`) y, en impacto, el balance de energía. Un colmillo de víbora empujado con
4 N atraviesa piel y grasa y queda en el músculo: veneno intramuscular.

**3 · Arrastrar** (rayado):
- Si la punta **rompe** la piel, rasga un corte de profundidad `h`. La energía por unidad de
  longitud es la tenacidad al desgarro integrada en las capas: `F_t = ∫₀ʰ jT dz`. La fuerza que
  abre el corte es la fricción al arrastrar, `F_t = μ·F·enganche`, o el tirón entero de la garra
  enganchada al desgarrar, `F_t = F·palanca`; ambas por el tipo de rayado y `n^0,4` pasadas.
  Las puntas romas desgarran en vez de cortar (Ankersen 1999), así que se usa `jT`, no `jC`.
- Si **no** la rompe, solo hay abrasión (heurística calibrada, la de v2): sin marca < 1 MPa ·
  marca roja < 4 MPa · **rasguño blanco** (levanta la capa córnea, 18 µm) < 16 MPa · **rasguños**
  (excoria la epidermis, 75 µm: escuece, no sangra). Con ≥ 5 pasadas la excoriación llega a las
  papilas: **rasguños que sangran**. El esfuerzo es `σ = P·k_tipo·√(1+3μ²)·enganche·palanca`.
- Veredictos por capa alcanzada: arañazo superficial (epidermis) · arañazo que sangra (dermis
  papilar, primeros ~0,3 mm, **estimación**) · arañazo profundo (dermis reticular) · laceración
  (grasa) · laceración profunda (fascia y músculo). Con desgarro: desgarro, desgarro profundo,
  desgarro abierto, desgarro muscular.
- Una herida **sangra** solo si pasa la epidermis, que no tiene vasos.
- La dureza de la herramienta no interviene: cualquier punta es mucho más dura que la piel.

## 8. Punción e impacto

- **Empuje estático:** equilibrio de fuerzas `F = F_res(h)`.
- **Golpe:** balance de energía `½·m·v² + F·h = ∫₀ʰ F_res dh`, con velocidad `v` y masa efectiva
  `m` por animal (el reparto por garra de la energía del miembro). Sustituye al `×4` de v1.
- **Espesor:** si la profundidad alcanza el espesor de la puerta de roble, "atraviesa". En una
  chapa fina (coches, puerta de aluminio) hay dos etapas: perforarla y que la herramienta entera
  pase al otro lado (apartado 14). Un vidrio de ventana se parte por flexión (apartado 15).
- Resultado emblemático: de todo el catálogo, solo la patada del casuario (daga de 11 cm, ~160 J
  estimados) atraviesa los 35 mm de roble (test).

## 9. Límites de la herramienta

- **Alcance (`reach`)**: la punta no puede hundirse más que su longitud útil (la garra, el colmillo o
  la uña libre), ni al punzar ni al rayar: con toda la garra dentro, la pata o el dedo tocan la
  superficie. La app lo indica con «(tope)». Hasta la v2.3, el rayado de sólidos blandos no tenía este
  límite y una garra de pájaro de 4 mm abría surcos de 9,5 mm en pino a 300 N (hay un test).
- **Rotura (`fBreak`)**: colmillos de víbora hidratados resisten ~30 N en compresión antes de
  romperse cerca de la punta (Estrada et al. 2026). Si la carga en la punta supera ese valor, el
  veredicto es "SE ROMPE LA PUNTA" y la profundidad se queda donde la resistencia alcanzó 30 N.
  Si la punta ya está enterrada hasta la base, la carga es la resistencia a esa profundidad. En
  una chapa cuenta el **máximo del camino**: el pico llega al romperla, y después los pétalos ceden
  con menos fuerza (un colmillo no perfora 2,5 mm de plástico aunque luego fuera fácil seguir).
- **Anchura (`baseR`)**: una garra no es un cono infinito. El agujero que abre en una chapa nunca
  es más ancho que su sección en la base: 0,15 × alcance en garras y 0,04 × alcance en colmillos
  (estimaciones). En sólidos gruesos no se aplica: el fuste enterrado sigue rozando (sin ese roce,
  un cilindro se deslizaría hasta la base de golpe).

## 10. Queratina húmeda

La queratina absorbe agua: la uña pasa del 6 % de humedad (0 % HR) al 64 % sumergida (Farran
2008). Su módulo cae de 2,34 GPa (55 % HR) a 0,47 GPa (100 % HR) (Farran 2009), y la resistencia
de la queratina de garra de 69 a 14 MPa (Bonser, en McKittrick 2012). El interruptor "húmeda"
multiplica por **0,2** la dureza y el módulo de la uña natural y de las garras, no del gel, el
acrílico, las gemas ni la dentina. Que la dureza caiga como la resistencia es una **estimación**:
la nanodureza de la uña apenas cambia con la humedad (Farran 2009, JMR), pero la microdureza, que es
la escala del rayado, sí.

## 11. Abrasión, fricción y desgaste

- **Modo de abrasión (Hokkirigawa & Kato 1988):** grado de penetración `Dp = h/a`: **arado**
  (< 0,1, desplaza), **cuña** (0,1–0,2) y **corte** (> 0,2, arranca viruta). Con la geometría real,
  las puntas cónicas afiladas cortan (`Dp ≈ 1/tan α`) y las romas aran.
- **Fricción de rayado:** `μ = μ_adhesión + μ_arado`, con `μ_arado ≈ 0,9·Dp`, del orden de la
  expresión de Bowden-Tabor (1950) para una esfera (`≈ 0,85·h/a`).
- **Archard (1953):** volumen ∝ F·L/H del más blando, multiplicado por la fracción realmente
  arrancada `f_ab` (2 % cuando no hay surco: pulido). Índice en unidades arbitrarias.

## 12. Adhesión (Van der Waals, JKR 1971)

`F_adh = 1,5·π·R·W`. Se muestra para enseñar que a escala macro es despreciable. Solo domina en
micro/nano o en superficies muy lisas a carga casi nula (gecko, stiction).

## 13. Uñas macizas (experimentos) y Stiletto XL

En "Material · experimentos" la uña **entera** es de otro material (acero inoxidable, titanio,
zafiro o diamante), no solo una gema en la punta. El motor usa la dureza y el módulo de ese
material con la geometría de la forma elegida, igual que con el gel o el acrílico. Por eso:

- El **acero** (200 HV) raya plástico, madera y cobre, empata con el acero inoxidable (marca tenue)
  y nunca raya el vidrio (550 HV). El **titanio** comercialmente puro (≈150 HV) es más blando que
  el acero, aunque su Mohs sea alto: ya no marca el acero inoxidable.
- **Zafiro** y **diamante** rayan el vidrio, la pantalla y el cuarzo **cuanto más fina es la
  punta**. Con una punta roma (cuadrada, R ≈ 1,7 mm) a 30 N el contacto se queda **elástico** (Hertz,
  apartado 3): un material rígido como el cuarzo reparte la carga sin llegar a plastificar. Solo el
  diamante raya de verdad el zafiro (zafiro contra zafiro: marca tenue, empate).
- El agua no les afecta (no son queratina).
- **No** se modela su rotura: un zafiro afilado se desconcharía con un golpe y una uña de acero
  fina se doblaría. Son experimentos mentales.

**Garras y colmillos reforjados.** Con una garra, el material de la lista (acero, titanio,
tungsteno, cuarzo, zafiro, diamante…) es **la garra entera**: conserva su forma (área de la punta,
semiángulo, alcance) y toma la dureza y el módulo del material, como ya pasaba con los colmillos.
Una "garra de águila de acero" es un talón de águila hecho de acero, no una tachuela en la punta.
En una uña, en cambio, la piedra va incrustada en la punta y es la que araña.

La **Stiletto XL** (uña libre de 12 mm, punta de 0,08 mm², semiángulo 16°) es la stiletto extra
larga de salón; sus números son una extrapolación de la stiletto (ver estimaciones). Tests:
"afilar nunca resta" (cuadrada ≤ stiletto ≤ stiletto XL en profundidad para todas las bases,
materiales, fuerzas y métodos) y las afirmaciones de cada ficha experimental.

## 14. Carrocerías de coche y chapa fina (v2.3)

Cuatro coches con la misma pintura (apartado 6) sobre carrocerías distintas, y la puerta de
aluminio de casa, que es una chapa fina sin pintar:

| Carrocería | Espesor | Material | Dureza | σ0 | Fuentes |
|---|---|---|---|---|---|
| Coche moderno | 0,7 mm | acero de horno (bake hardening) tipo HC180B: Rp0,2 180–230 MPa (+35 al hornear la pintura), Rm 290–360 (usamos 340), n ≥ 0,17 | 101 HV | 264 MPa | Nippon Steel 2013; voestalpine 2022 |
| Coche clásico | ~0,9 mm (**estimación**) | acero dulce de embutición, equivalente moderno DC04: Re 140–210 MPa, Rm 270–350, n ≥ 0,18 | 92 HV | 214 MPa | ArcelorMittal B10 |
| Coche de aluminio | 1,0 mm (rango 0,8–1,25) | AA6016 tras el horneado de la pintura: Rp0,2 212 MPa, Rm 273, n 0,30 (medido en T4*) | 71 HV | 211 MPa | Hirsch 2011; Prillhofer et al. 2014 |
| Aleta de plástico | ~2,5 mm (**estimación**) | termoplástico PPE/PA (Noryl GTX964W): fluencia 44–50 MPa, rotura al 50–56 %, 1,8 GPa | 13 HV | 47 MPa | SABIC; GE Plastics 2007 |
| Puerta de aluminio (casa) | 1,5 mm | aleación de perfilería 6063-T5 (valores típicos de manual) | 60 HV | 157 MPa (**estimación**) | — |

El 0,7 mm del coche moderno es el espesor de las puertas y capós de acero de hoy (Nippon Steel lo
usa como espesor convencional; I-CAR da 0,70 mm para los paneles exteriores). El clásico lleva
acero dulce más grueso: la reducción de espesores empezó tras la crisis de 1973 y los aceros de
horno llegaron después. El aluminio se usa más grueso que el acero para aguantar lo mismo
(Hirsch 2011: 0,8–1,25 mm). Aletas de PPE/PA: más de 10 millones de coches desde 2001 y hasta un
50 % menos de peso que el acero (GE Plastics 2007); con la mitad del peso de una aleta de acero de
0,7 mm (7,85 g/cm³) y 1,08 g/cm³ salen ~2,5 mm. En plástico no hay e-coat: la capa de 25 µm es un
promotor de adherencia.

**Dureza de los metales.** Se deduce de su curva de tracción con Tabor (H ≈ 2,8·σ a ε ≈ 8 %) y
el endurecimiento de Hollomon σ = K·εⁿ, con K = σu·(e/n)ⁿ (la estricción empieza a ε = n). Una
misma receta para los tres metales; en el plástico, H ≈ 2,8·σy (aproximación en polímeros).

**Tres etapas en la punción:**

1. **Pintura y chapa como un sólido.** La punta indenta pintura y metal con su dureza (apartado 5).
   La queratina (r < 0,8 frente al metal) se queda en la pintura: "HASTA EL METAL".
2. **Perforar.** Cuando la punta llega a la cara de atrás (espesor total = pintura + chapa), la
   chapa se rompe y la punta asoma por detrás: "PERFORA LA CHAPA".
3. **Atravesar.** Después el metal ya no se opone como un bloque: el agujero se abre en pétalos
   que se doblan y se rasgan. Energía para abrir un agujero de radio `l` en una chapa de espesor
   `t` (Wierzbicki 1999, ec. 57, con fractura dúctil δt/t = 1):
   `E(l) = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4]`, cuyo término principal es la ec. 58,
   `E = 3,37·σ0·t^1,6·D^1,4`, que según el autor encaja con la docena de fórmulas empíricas de
   la literatura. σ0 es la tensión de flujo media, `σ0 = √(σy·σu/(1+n))` (ec. 65). La fuerza es
   `dE/dh`: el agujero tiene el radio de la herramienta a esa profundidad (hasta su anchura
   máxima). Si la herramienta entera pasa al otro lado (su alcance), "ATRAVIESA LA CHAPA".

Consecuencias: una punta fina y dura perfora con pocos julios (una uña stiletto de metal, 5 J:
agujero de ~5 mm), pero que pase una garra entera cuesta decenas (águila de acero: 14 J en el
moderno, 17 J en el clásico, 20 J en el aluminio). El clásico es más blando (se marca algo más
hondo) pero cuesta más perforarlo y absorbe más energía (test). Al rayar con fuerza bestial, la
garra corta la chapa de lado a lado: "RAJA LA CHAPA". `workJ` es la energía que se queda el
material (∫F·dh hasta la profundidad final); lo que sobra de un golpe que no entra rebota o abolla
la chapa, y la abolladura no se modela.

## 15. Vidrio de ventana (v2.3)

"Vidrio de ventana" es una hoja de vidrio float recocido de 4 mm en una ventana de ~60 cm
(estimación), tratada como placa circular apoyada de radio a = 300 mm con la carga en el centro.
Para rayarlo hace falta dureza (apartado 4); para **romperlo**, no: basta con flexar la hoja hasta
su resistencia a flexión característica, fg,k = 45 MPa (EN 572-1; Saint-Gobain; el templado de la
EN 12150-1 aguanta 120 MPa). En la cara de atrás (Roark, placa circular apoyada):

`σ = 3F/(2π·t²)·[(1+ν)·ln(a/r0') + 1]`, con el radio equivalente de Westergaard
`r0' = √(1,6·r0² + t²) − 0,675·t` para contactos pequeños (r0 < 0,5·t), ν = 0,22.

La hoja se parte con **~200 N** en el centro, sea la punta blanda o dura. En un golpe cuenta la
**fuerza de pico**: la masa del golpe contra dos muelles en serie, la hoja
(`k = 4π·E·t³ / (3·a²·(3+ν)·(1−ν))`, ≈ 85 N/mm) y el tejido blando de la pata o del dedo
(≈ 10 N/mm, **estimación**): `F = v·√(m·k_ef)`. Así un zarpazo de gato (147 N) no rompe una
ventana y el de un oso (≈ 1300 N) o el picado de un halcón sí. Una punta dura que atraviesa la
hoja también la parte. A la hoja nunca llega más fuerza de la que aguanta la herramienta: un
colmillo (30 N) se rompe antes.

---

## Datos de materiales y seres vivos

| Dato | Valor usado | Fuente |
|---|---|---|
| Uña humana | ~25 HV · E 2,9 GPa | nanoindentación (Tohmyoh et al. 2023) |
| Uña humana y humedad | E 4,34 (20 % HR) · 2,34 (55 %) · 0,47 GPa (100 %) | Farran et al. 2009 (vía McKittrick 2012) |
| Acrílico (PMMA) | 22 HV · E 3 GPa | PMMA ~23,6 HV; E 2,4–3,3 GPa (literatura de resinas) |
| Queratina de garra | 26–33 HV · E 2,0 GPa (50 % HR) | garra de avestruz (Bonser; McKittrick 2012) |
| Colmillo de víbora | dentina 0,4–0,6 GPa (usamos 50 HV) · rotura ~30 N · 2,0–2,6 m/s · 2,5–3,0 J | Estrada et al. 2026 |
| Ataque de víbora | 2,7–3,1 m/s (serpientes de 0,27–0,63 kg) | Penning et al. 2016 |
| Ángulo de punta de colmillos | 25–69° (ángulo incluido) | Crofts et al. 2019 |
| Agarre de rapaces | cernícalo 2,6 N (112 g); gavilán de Cooper 9,77 N | Sustaita & Hertel 2010; Tsang et al. 2019 |
| Punción de piel in vivo | F = 0,00019·A[µm²] − 0,66 N · G_p 30,1 kJ/m² | Davis et al. 2004 |
| Corte de piel | 1,7 ± 0,6 kJ/m² | Pereira et al. 1997 (citado en Davis 2004) |
| Capas de la piel del brazo | córnea 18 µm · epidermis 57 µm · piel 2,2 mm · grasa 10,8 mm · fascia 0,3 mm | Sandby-Møller 2003; Gibney 2010; Stecco 2009 (apartado 7) |
| Tenacidad al desgarro | dermis 17 · grasa 4,1 · fascia 2,1 · músculo 0,84 kJ/m² | Comley & Fleck 2010; Kim 2001 (cadáver); Aryeetey 2022 |
| Rigidez del tejido | piel 210 kPa · grasa 1,9 kPa · músculo ≈ 53 kPa | Iivarinen 2011 (in vivo); Šarabon 2019 |
| Resistencia de la piel | 21,6 ± 8,4 MPa | Ní Annaidh et al. 2012 |
| Barniz de coche (PU) | 197–425 MPa · E_r 3,5–5,8 GPa (usamos 20 HV · 3,2 GPa) | Vodnick 2006 (nanoindentación) |
| Pino silvestre | Janka 2.420 N → ~24 MPa (~2,5 HV) | The Wood Database |
| Roble europeo | Janka 4.980 N → ~50 MPa (~5 HV) | The Wood Database |
| Casuario | garra interna 10–12 cm, hasta 60 kg, 50 km/h | San Diego Zoo, Discover Magazine |
| Águila arpía | talón trasero ~12–13 cm | divulgación ornitológica |
| Mohs ↔ Vickers | relación **no lineal** | Mohs es ordinal: solo etiqueta |
| Metales, vidrios y gemas | HV y E de manual | valores típicos de ingeniería |
| Uñas macizas experimentales | acero inox. 200 HV · E 200 GPa · titanio (grado 2) 150 HV · E 105 · zafiro 2000 HV · E 400 · diamante 10 000 HV · E 1050 | valores de manual, los mismos que sus incrustaciones |
| Chapa de coche moderno | acero de horno de 0,7 mm, Rm 340 MPa | Nippon Steel Technical Report 103 (2013); I-CAR (2012) |
| Acero de horno HC180B | Rp0,2 180–230 · Rm 290–360 MPa · n ≥ 0,17 · BH2 ≥ 35 MPa | voestalpine, hoja técnica de aceros bake-hardening (2022) |
| Acero dulce DC04 | Re 140–210 · Rm 270–350 MPa · n ≥ 0,18 | ArcelorMittal, catálogo B10 (EN 10130) |
| Aluminio de carrocería | AA6016/6014, 0,8–1,25 mm · tras hornear: Rp0,2 212 · Rm 273 MPa · n 0,30 | Hirsch 2011; Prillhofer et al. 2014 |
| Aleta de termoplástico | PPE/PA: fluencia 44–50 MPa, rotura 50–56 %, 1,8 GPa · −50 % de peso frente al acero | SABIC (Noryl GTX964W); GE Plastics 2007 |
| Perforación de chapa en pétalos | E = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4] · σ0 = √(σy·σu/(1+n)) | Wierzbicki 1999 |
| Vidrio float recocido | fg,k 45 MPa (templado 120) · E 70 GPa | EN 572-1 / EN 12150-1, vía Saint-Gobain 2018 |
| Placa circular con carga central | σ y flecha de Roark · radio equivalente de Westergaard | Young & Budynas 2002 (Roark) |

**Janka → presión:** la prueba Janka hunde media bola de 11,28 mm, con un área proyectada de
100 mm². `F_Janka/100 mm²` es la presión media equivalente.

## Estimaciones (no son mediciones)

| Magnitud | Valor usado | Razonamiento |
|---|---|---|
| Fuerzas de mamíferos y ratites | gato 15 N · tigre 260 · oso 300 · casuario 500 · emú 300 · avestruz 900 | órdenes de magnitud por masa, anatomía y comportamiento |
| Agarre de rapaces | águila 110 N · arpía 200 · búho 45 · halcón 15 · lechuza 8 | escalado lineal con la masa desde el gavilán medido (~22 N/kg); los halcones agarran menos (Sustaita & Hertel) |
| Gallo, guacamayo, buitre, pájaro | 40 · 25 · 60 · 1,5 N | escalado por masa y uso de la pata |
| Golpe por garra (v, m) | gato 4 m/s·0,15 kg · tigre 8·3 · oso 7·4 · águila 12·1 · arpía 9·1,8 · halcón 40·0,25 (picado) · búho 6·0,5 · lechuza 5·0,08 · casuario 8·5 · emú 7·2,5 · avestruz 10·8 · gallo 5·0,4 | energía del miembro repartida entre sus garras |
| Golpe de víbora | víbora 2,8 m/s·0,35 kg (1,4 J) · Gabón 2,5·1 (3,1 J) | velocidades medidas; masa efectiva ajustada a los 2,5–3 J de Estrada 2026 |
| Mano humana | 30 N (arañazo decidido) · golpe 5 m/s·0,4 kg | fuerza de dedo y masa del antebrazo |
| Semiángulos de punta | garras 13–32° · uñas 22–75° · gemas 50° | forma observada; colmillos dentro del rango de Crofts 2019 |
| Alcance (longitud útil) | 4 mm (pájaro) … 110 mm (casuario) | longitud expuesta de la garra/colmillo |
| Rotura del colmillo de Gabón | 30 N | se asume como en las víboras medidas por Estrada 2026 |
| Gel UV | 30 HV · E 2,5 GPa | resinas de uretano-metacrilato |
| ABS · encimera de cuarzo | 16 HV · E 2,3 GPa · 1100 HV · E 75 GPa | valores típicos; la encimera es cuarzo aglomerado con resina |
| Queratina húmeda | ×0,2 en dureza y módulo | por la caída de módulo y resistencia medida (apartado 10) |
| Saturación de la eficiencia | r ≈ 2 | hipótesis del modelo (apartado 4) |
| Tenacidad al corte de grasa, fascia y músculo | 0,41 · 0,21 · 0,084 kJ/m² | corte de la dermis (Pereira) × cociente de tenacidades al desgarro (apartado 7) |
| Umbrales de abrasión de la piel | 1 · 4 · 16 MPa; 5 pasadas para sangrar | heurística calibrada con la experiencia (rascarse deja una raya blanca) |
| Dermis papilar | 0,3 mm | capilares en la parte alta de la dermis (0,1–0,4 mm en histología) |
| Enganche de la garra en la piel | ×(1 + 0,7·curvatura) | estimación heredada de v2 |
| Stiletto XL | 0,08 mm² · α 16° · uña libre 12 mm | extrapolación de la stiletto (0,15 mm² · 22° · 8 mm) a una uña extra larga |
| Curvatura "de pinza" (curl) | 0,1 (cuadrada) … 1,0 (Stiletto XL) | solo dibujo de la vista lateral; no entra en la física |
| Chapa del coche clásico | acero dulce de 0,9 mm | calibre 20 (0,91 mm), habitual antes de reducir espesores |
| Aleta de plástico | 2,5 mm | la misma aleta con la mitad de peso que el acero de 0,7 mm (SABIC/GE: −50 %) |
| Fluencia del acero de horno en servicio | 205 + 35 MPa | centro del rango de Rp0,2 más el BH2 mínimo del horneado de la pintura |
| Dureza de las carrocerías | 101 · 92 · 71 · 13 HV | Tabor + Hollomon desde σu y n (apartado 14); en el aluminio n es el de T4*, así que 71 HV es una cota baja |
| Puerta de aluminio de casa | σ0 157 MPa | 6063-T5 típico (σy 145, σu 186, n 0,10) |
| Anchura de la garra en la base | radio 0,15 × alcance (colmillos 0,04 ×) | proporciones de garras y colmillos; solo limita el agujero de una chapa |
| Ventana | hoja de 4 mm, 60 cm, apoyada, carga en el centro | caso típico de ventana doméstica |
| Rigidez del tejido que golpea | 10 N/mm | orden de magnitud de una pata o un dedo; decide la fuerza de pico sobre el vidrio |

Si encuentras una medición publicada, sustituye el valor, cita la fuente aquí y actualiza el golden.

## Limitaciones conocidas

- La profundidad es **bajo carga**: no se modela la recuperación elástica de los polímeros.
- Las uñas se tratan como puntas (esfero-cónicas), no como filos; no se modela su rotura por
  flexión (una stiletto real se partiría mucho antes de 30 N).
- Chapas finas (coches, puerta de aluminio): el inicio de la rotura se aproxima con la indentación
  hasta la cara de atrás (Atkins et al. 1998 lo trata con detalle); los pétalos suponen fractura
  dúctil (δt/t = 1) y no dependen de la velocidad. En el plástico se usa la misma fórmula, pensada
  para metales dúctiles. **No se modela la abolladura**: la energía que sobra de un golpe que no
  perfora (un zarpazo de oso contra el acero) abollaría la chapa. Tampoco lo que hay detrás del
  panel (refuerzos, cristal, panel interior).
- Vidrio: solo recocido y con la carga en el centro de la hoja. Las ventanillas de coche son de
  vidrio templado y el parabrisas es laminado (rompen distinto); tampoco se modelan.
- Frágiles: el surco incluye el astillado solo como etiqueta; no se calculan grietas de Hertz ni
  el umbral de Lawn-Evans. Consecuencia: con una punta roma y dura sobre vidrio o cuarzo el modelo
  puede decir "roza sin marcar" (contacto elástico) donde en la realidad podría abrirse una grieta
  de anillo o cono (ley de Auerbach), sobre todo al deslizar. Ver ROADMAP.
- Piel: una sola zona de referencia (brazo); en la palma la capa córnea mide ~170 µm y en el
  abdomen la grasa ~14 mm. No se modela el hueso (el casuario "atraviesa" el brazo), la fricción en
  los flancos de la punta al entrar (Shergold & Fleck) ni la elasticidad de la piel que retrocede.

## Datos investigados pendientes de integrar

- **Aguijones:** fuerza de penetración de la abeja melífera 2–3 **mN**, avispa 6–8 **mN**;
  punta ~5× más blanda que la base (gradiente de dureza que reduce la percepción inicial);
  ángulo óptimo de inserción −6° (abeja) y +10° (avispa). Ver ROADMAP.
- **Escala de Schmidt:** abeja y avispa común 2; hormiga de fuego 1,2; hormiga bala 4;
  *Pepsis* (avispa halcón) 4.
- **Esmalte en la punta del colmillo** (Estrada 2026): más duro que la dentina; falta su dureza.

## Fuentes

- Ankersen J. (1999). *Quantifying the forces in stabbing incidents*. Tesis doctoral, University of Glasgow. http://theses.gla.ac.uk/2798/
- ArcelorMittal. B10 – Steels for cold forming (DC01–DC07, EN 10130), catálogo técnico. https://ssc.arcelormittal.com/IMG/pdf/cr_cold_forming_-_b10.pdf
- Archard J.F. (1953). Contact and rubbing of flat surfaces. *J. Appl. Phys.* 24:981–988. doi:10.1063/1.1721448
- Aryeetey O.J., Frank M., Lorenz A., Pahr D.H. (2022). Fracture toughness determination of porcine muscle tissue based on AQLV model derived viscous dissipated energy. *J. Mech. Behav. Biomed. Mater.* 135:105429. doi:10.1016/j.jmbbm.2022.105429
- ASTM G171. *Standard Test Method for Scratch Hardness of Materials Using a Diamond Stylus*. ASTM International (dureza al rayado: la carga la soporta la mitad delantera del contacto).
- Atkins A.G., Afzal Khan M., Liu J.H. (1998). Necking and radial cracking around perforations in thin sheets at normal incidence. *Int. J. Impact Eng.* 21:521–539.
- Bowden F.P., Tabor D. (1950). *The Friction and Lubrication of Solids*. Clarendon Press, Oxford.
- Comley K., Fleck N.A. (2010). The toughness of adipose tissue: measurements and physical basis. *J. Biomech.* 43:1823–1826. doi:10.1016/j.jbiomech.2010.02.029
- Crofts S.B., Lai Y., Hu Y., Anderson P.S.L. (2019). How do morphological sharpness measures relate to puncture performance in viperid snake fangs? *Biol. Lett.* 15:20180905. doi:10.1098/rsbl.2018.0905
- Davis S.P., Landis B.J., Adams Z.H., Allen M.G., Prausnitz M.R. (2004). Insertion of microneedles into skin: measurement and prediction of insertion force and needle fracture force. *J. Biomech.* 37:1155–1163. doi:10.1016/j.jbiomech.2003.12.010
- Estrada S., Arredondo J.C., Pereañez J., Arola D., Ossa A. (2026). Mechanical properties, microstructure, and strike biomechanics of tubular fangs in neotropical vipers. *Acta Biomater.* 222:388–398. doi:10.1016/j.actbio.2026.07.058
- Egawa M., Hirao T., Takahashi M. (2007). In vivo estimation of stratum corneum thickness from water concentration profiles obtained with Raman spectroscopy. *Acta Derm. Venereol.* 87:4–8. doi:10.2340/00015555-0183
- Farran L., Ennos A.R., Eichhorn S.J. (2008). The effect of humidity on the fracture properties of human fingernails. *J. Exp. Biol.* 211:3677–3681.
- Farran L., Ennos A.R., Starkie M., Eichhorn S.J. (2009). Tensile and shear properties of fingernails as a function of a changing humidity environment. *J. Biomech.* 42:1230–1235. doi:10.1016/j.jbiomech.2009.03.020
- Farran L., Ennos A.R., Eichhorn S.J. (2009). Microindentation and nanoindentation of human fingernails at varying relative humidity. *J. Mater. Res.* 24:980–984. doi:10.1557/jmr.2009.0119
- Gibney M.A., Arce C.H., Byron K.J., Hirsch L.J. (2010). Skin and subcutaneous adipose layer thickness in adults with diabetes at sites used for insulin injections: implications for needle length recommendations. *Curr. Med. Res. Opin.* 26:1519–1530. doi:10.1185/03007995.2010.481203
- Hirsch J. (2011). Aluminium in innovative light-weight car design. *Mater. Trans.* 52:818–824. doi:10.2320/matertrans.L-MZ201132
- Hollomon J.H. (1945). Tensile deformation. *Trans. AIME* 162:268–290.
- Hokkirigawa K., Kato K. (1988). An experimental and theoretical investigation of ploughing, cutting and wedge formation during abrasive wear. *Tribol. Int.* 21:51–57. doi:10.1016/0301-679X(88)90128-4
- I-CAR / BodyShop Business (2012). In the thick of it (espesor de los paneles exteriores de acero: 0,70 mm). https://www.bodyshopbusiness.com/in-the-thick-of-it/
- Iivarinen J.T., Korhonen R.K., Julkunen P., Jurvelin J.S. (2011). Experimental and computational analysis of soft tissue stiffness in forearm using a manual indentation device. *Med. Eng. Phys.* 33:1245–1253. doi:10.1016/j.medengphy.2011.05.015
- GE Plastics (2007). Nota de prensa sobre Noryl GTX para paneles de carrocería (más de 10 millones de coches con aletas de Noryl GTX desde 2001). https://www.pressreleasefinder.com/GE_Plastics/GEPPR314AU/en/
- Johnson K.L. (1985). *Contact Mechanics*. Cambridge University Press.
- Johnson K.L., Kendall K., Roberts A.D. (1971). Surface energy and the contact of elastic solids. *Proc. R. Soc. Lond. A* 324:301–313. doi:10.1098/rspa.1971.0141
- Jönsson B., Hogmark S. (1984). Hardness measurements of thin films. *Thin Solid Films* 114:257–269. doi:10.1016/0040-6090(84)90123-8
- Kim H.L., LaBarbera M.C., Patel R.V., Cromie W.J., Bales G.T. (2001). Comparison of the durability of cadaveric and autologous fascia using an in vivo model. *Urology* 58:800–804. doi:10.1016/s0090-4295(01)01315-2
- Knight B. (1975). The dynamics of stab wounds. *Forensic Sci.* 6:249–255. doi:10.1016/0300-9432(75)90017-5
- McKittrick J. et al. (2012). The structure, functions, and mechanical properties of keratin. *JOM* 64:449–468. doi:10.1007/s11837-012-0302-8
- Ní Annaidh A., Bruyère K., Destrade M., Gilchrist M.D., Otténio M. (2012). Characterization of the anisotropic mechanical properties of excised human skin. *J. Mech. Behav. Biomed. Mater.* 5:139–148. doi:10.1016/j.jmbbm.2011.08.016
- Nippon Steel (2013). Yonemura S., Uenishi A., Kosugi S., Yoshida T., Hiwatashi S., Nakagawa J. Advanced technologies related to simulation and evaluation for performance of automotive exterior panels. *Nippon Steel Technical Report* 103:11–17.
- O'Callaghan P.T., Jones M.D., James D.S., Leadbeatter S., Holt C.A., Nokes L.D. (1999). Dynamics of stab wounds: force required for penetration of various cadaveric human tissues. *Forensic Sci. Int.* 104:173–178. doi:10.1016/s0379-0738(99)00115-2
- Penning D.A., Sawvel B., Moon B.R. (2016). Debunking the viper's strike: harmless snakes kill a common assumption. *Biol. Lett.* 12:20160011. doi:10.1098/rsbl.2016.0011
- Pintaude G. (2021). Remarks on wear transitions related to hardness and size of abrasive particles. En *Tribology of Machine Elements*, IntechOpen. doi:10.5772/intechopen.99324
- Prillhofer R., Rank G., Berneder J., Antrekowitsch H., Uggowitzer P.J., Pogatscher S. (2014). Property criteria for automotive Al-Mg-Si sheet alloys. *Materials* 7:5047–5068. doi:10.3390/ma7075047
- Pereira B.P., Lucas P.W., Swee-Hin T. (1997). Ranking the fracture toughness of thin mammalian soft tissues using the scissors cutting test. *J. Biomech.* 30:91–94. doi:10.1016/s0021-9290(96)00101-7
- Richardson R.C.D. (1968). The wear of metals by relatively soft abrasives. *Wear* 11:245–275. doi:10.1016/0043-1648(68)90175-0
- SABIC. NORYL GTX™ resin GTX964W, hoja técnica (Material Finder). https://materialfinder.sabic-specialties.com/material/noryl-gtx-resin-gtx964w
- Saint-Gobain Building Glass UK (2018). Glass fundamentals 1B: the strength of glass (resistencias características según EN 572-1, EN 1863-1 y EN 12150-1).
- Sandby-Møller J., Poulsen T., Wulf H.C. (2003). Epidermal thickness at different body sites: relationship to age, gender, pigmentation, blood content, skin type and smoking habits. *Acta Derm. Venereol.* 83:410–413. doi:10.1080/00015550310015419
- Šarabon N., Kozinc Ž., Podrekar N. (2019). Using shear-wave elastography in skeletal muscle: a repeatability and reproducibility study on biceps femoris muscle. *PLoS One* 14:e0222008. doi:10.1371/journal.pone.0222008
- Shergold O.A., Fleck N.A. (2005). Experimental investigation into the deep penetration of soft solids by sharp and blunt punches, with application to the piercing of skin. *J. Biomech. Eng.* 127:838–848. doi:10.1115/1.1992528
- Stecco A., Masiero S., Macchi V., Stecco C., Porzionato A., De Caro R. (2009). The pectoral fascia: anatomical and histological study. *J. Bodyw. Mov. Ther.* 13:255–261. doi:10.1016/j.jbmt.2008.04.036
- Sustaita D., Hertel F. (2010). In vivo bite and grip forces, morphology and prey-killing behavior of North American accipiters and falcons. *J. Exp. Biol.* 213:2617–2628. doi:10.1242/jeb.041731
- Tabor D. (1951). *The Hardness of Metals*. Oxford University Press.
- Tabor D. (1954). Mohs's hardness scale — a physical interpretation. *Proc. Phys. Soc. B* 67:249–257. doi:10.1088/0370-1301/67/3/310
- Taylor D., O'Mara N., Ryan E., Takaza M., Simms C. (2012). The fracture toughness of soft tissues. *J. Mech. Behav. Biomed. Mater.* 6:139–147. doi:10.1016/j.jmbbm.2011.09.018
- Tohmyoh H. et al. (2023). Nanoindentation study of human fingernail for determining its structural elasticity. *Skin Res. Technol.* 29. doi:10.1111/srt.13456
- Tsang L.R. et al. (2019). Raptor talon shape and biomechanical performance are controlled by relative prey size but not by allometry. *Sci. Rep.* 9:7076. doi:10.1038/s41598-019-43654-0
- voestalpine Stahl (2022). Bake-hardening steels, hoja técnica (HC180B, HC220B, HC260B; EN 10268).
- Van Ee C.A., Chasse A.L., Myers B.S. (2000). Quantifying skeletal muscle properties in cadaveric test specimens: effects of mechanical loading, postmortem time, and freezer storage. *J. Biomech. Eng.* 122:9–14. doi:10.1115/1.429621
- Vodnick D. (2006). Nanomechanical characterization of coatings. *PCI Magazine*, 1 de agosto de 2006.
- Wierzbicki T. (1999). Petalling of plates under explosive and impact loading. *Int. J. Impact Eng.* 22:935–954. doi:10.1016/S0734-743X(99)00028-7
- Wu K.S., van Osdol W.W., Dauskardt R.H. (2006). Mechanical properties of human stratum corneum: effects of temperature, hydration, and chemical treatment. *Biomaterials* 27:785–795. doi:10.1016/j.biomaterials.2005.06.019
- Young W.C., Budynas R.G. (2002). *Roark's Formulas for Stress and Strain*, 7.ª ed. McGraw-Hill (placas circulares con carga concentrada).
- The Wood Database: Scots pine y English oak (dureza Janka). https://www.wood-database.com
