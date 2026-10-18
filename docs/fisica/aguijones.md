# Aguijones de insectos · modelo físico, datos y guía de integración (laboratorio 2.0)

Especificación de los aguijones del banco de tribología: qué pasa cuando una abeja, una avispa o una hormiga bala
pican la piel, por qué algunos aguijones se quedan clavados y por qué ninguno raya el vidrio, y qué predice la física
cuando el aguijón se «reforja» en acero, zafiro o diamante.

- Datos: `godot/core/lab/insects.gd` (catálogo `STINGERS`, `GROUP := "Insectos"`).
- Física: `godot/core/lab/sting.gd` (funciones puras; `Sting.sting_report(p)` es la referencia de la integración).
- Tests: `godot/tests/lab/test_sting.gd` y `godot/tests/lab/test_insects_data.gd`.
- Casos de referencia de la integración: `godot/tests/fixtures/spec/aguijones.json`.

> **Educativo.** Como el resto del banco, el modelo captura tendencias y órdenes de magnitud con datos publicados.
> Muchas fuerzas de insectos están medidas en una sola especie (la abeja asiática, *Apis cerana*) y casi todo lo de
> los avispones, el abejorro y la hormiga bala es un escalado geométrico: cada dato dice de dónde sale.

## 1. Resumen

| Aguijón | Perfora con (modelo) | Pandea a | Empuje típico | Entra | Capa (brazo) | ¿Se queda? | Schmidt | Aleteo |
|---|---|---|---|---|---|---|---|---|
| Abeja melífera | 4,3 mN (medido 1,3-5,8) | 8,6 mN (medido 6,7 en *A. cerana*) | 5,75 mN (medido) | 1,32 mm | dermis | casi siempre: autotomía | 2 | 231 Hz |
| Avispa común | 7,1 mN (estimado) | 52 mN | 9,9 mN (est.) | 1,55 mm | dermis | a veces | 2 | 166 Hz |
| Avispa papelera | 5,8 mN (medido 6-8) | 17 mN | 8 mN (medido) | 1,82 mm (est.) | dermis | nunca | — | 109 Hz |
| Avispón europeo | 10 mN (est.) | 68 mN | 14 mN (est.) | 2,77 mm (est.) | grasa | nunca | — | 115 Hz |
| Avispa asiática | 10 mN (est.) | 82 mN | 14 mN (est.) | 2,46 mm (est.) | grasa | nunca | — | 111 Hz |
| Abejorro | 6,7 mN (est.) | 21 mN | 9,3 mN (est.) | 2,07 mm (est.) | dermis | nunca | 2 | 169 Hz |
| Hormiga bala | 8,7 mN (est.) | 36 mN | 12 mN (est.) | 2,71 mm (est.) | grasa | nunca | 4 | sin alas |
| Avispa halcón (*Pepsis*) | 16 mN (est.) | 126 mN | 23 mN (est.) | 5,38 mm (est.) | grasa | nunca (sin púas) | 4 | — |

«Pandea a» es la carga de pandeo con la punta libre sobre la piel (§2.3). «Entra» es la longitud útil: las lancetas
llevan el aguijón hasta el bulbo, que nunca entra (§2.2). La capa es la de la cara posterior del brazo de un adulto
(`SKIN_LAYERS`: dermis hasta 2,2 mm; FISICA.md §7).

## 2. Modelo físico

### 2.1 Perforar la piel: por qué Davis no sirve y qué lo sustituye

El banco 1.x perfora la piel con el ajuste de Davis et al. (2004), `F_p = 190 N/mm²·A − 0,66 N` con un mínimo de
0,08 N. Se midió con microagujas de 30-80 µm de radio de punta. La punta de una abeja mide 1-1,5 µm (Ling et al.
2017): su área (5·10⁻⁶ mm²) da un valor negativo y el mínimo deja la fuerza en **80 mN**, entre 14 y 60 veces lo
medido (1,34 mN, Ling et al. 2016; 2-3 mN en piel de cerdo, Zhao et al. 2015; 5,75 mN en piel de conejo, Ling et al.
2017). El ajuste lineal no extrapola a puntas decenas de veces más finas que las que se midieron.

**Mecanismo.** Una punta afilada no aplasta la piel: abre una grieta plana en modo I que avanza con ella y que el
fuste acuña después (Shergold & Fleck 2005, en piel humana in vivo). La energía por unidad de avance es la tenacidad
al corte por la anchura de la grieta, `F = 2·J·a`: es la misma relación que ya usa `physics.gd` para seguir entrando en
cada capa. Al empezar, la grieta tiene la anchura de la punta:

```
F_p = máx( 2·J_córnea·R_punta ,  F_Davis(A) si A está en el rango de Davis )
```

- `J_córnea = 1,7 kJ/m²` = 1,7 N/mm (tenacidad al corte de la piel, Pereira et al. 1997; `SKIN_LAYERS[0].jC`).
- `R_punta = √(A/π)`, la misma esfera de la punta que el resto del banco (FISICA.md §1).
- Davis solo cuenta donde su ajuste pasa de su mínimo medido (A > 0,0039 mm², R > 35 µm).

**Validación, sin calibrar nada.** Abeja (R = 1,25 µm): 2·1,7·0,00125 = **4,25 mN**, dentro de lo medido (1,34-5,75).
Avispa papelera, con la punta escalada desde la abeja (§3): **5,8 mN** frente a 6-8 mN medidos. Microaguja de 30 µm
(el borde de Davis): 0,10 N frente a los 0,08 N de su punta más fina.

**Nada cambia en el banco.** Para todas las uñas, gemas, garras y colmillos del catálogo manda Davis (la garra más
fina, la víbora, tiene R = 50 µm): `Sting.puncture_force` da exactamente lo mismo que `Physics.skin_puncture_force`
(hay un test). La ley es continua y creciente con el área (otro test).

### 2.2 Entrar: las lancetas y la profundidad

Un aguijón no se clava empujando. Las dos lancetas se deslizan sobre los raíles del estilete y avanzan por turnos:
cada una se ancla con sus púas mientras la otra corta (Ramirez-Esquivel & Ravi 2023). El aguijón arrancado de una abeja
sigue entrando solo. El empuje del insecto solo tiene que romper la superficie; después el mecanismo lo lleva hasta el
bulbo, que no entró en ninguno de 24 ensayos (Ramirez-Esquivel & Ravi 2023).

- **Profundidad:** `depthUm = reach·1000` si perfora; 0 si no. Monótona con la fuerza (hay un test).
- **Capa:** `Physics.skin_layer_at(depth)`. La abeja (1,32 mm) deja el veneno en la dermis y no llega al subcutáneo,
  como dicen Ramirez-Esquivel & Ravi (2023); los avispones y *Pepsis* pasan los 2,2 mm de piel del brazo y llegan a la
  grasa.
- **Por qué no se calcula con la fuerza.** Seguir entrando con el fuste entero pediría `2·J·a` con a = 43 µm, unos
  146 mN, 17 veces lo que la abeja puede empujar antes de pandear. Cada lanceta corta una grieta de su propia anchura
  (~40 µm → ~68 mN por golpe) y se apoya en las púas de la otra, que aguantan ~60 mN cada una (§2.4): el orden de
  magnitud cuadra, pero no hay medidas de la fuerza de cada golpe, así que el modelo no la calcula.

### 2.3 Pandeo

Antes de perforar, el aguijón es una columna hueca: empotrada en el bulbo y con la punta apoyada en la piel, libre para
resbalar de lado (voladizo, longitud efectiva `K·L` con K = 2). Una vez clavada la punta, el tejido lo sujeta.

- **Sección:** tubo de diámetro D (estilete, ~86 µm en la abeja, Zhao et al. 2015) con el canal del veneno dentro
  (39 µm, Ramirez-Esquivel & Ravi 2023): `I = π(D⁴ − Di⁴)/64`, `A = π(D² − Di²)/4`.
- **Euler:** `F = π²·E·I/(K·L)²`, con L la longitud útil.
- **Johnson** si la columna es corta para su límite elástico: esbeltez `λ = K·L/r_g`, transición `λc = π·√(2E/Y)`;
  si λ < λc, `σ = Y·(1 − λ²/2λc²)` y `F = σ·A`. El límite elástico sale de la dureza, `Y = H/2,8` (Tabor), la misma
  relación que usa `contact.gd` para la plastificación de Hertz.
- **Gradiente.** El módulo del aguijón baja de la base a la punta: 3,08 → 1,42 → 0,42 GPa en la abeja y 3,45 → 1,32 →
  0,47 en la avispa común (Das et al. 2018, nanoindentación por tercios). Se pondera con el modo de pandeo del
  voladizo, `y = 1 − cos(πx/2L)` (cociente de Rayleigh): `E_ef = 0,609·E_base + 0,333·E_medio + 0,058·E_punta`.
  Manda la base, que es donde se dobla: la punta blanda apenas cuenta.

**Validación.** Ling et al. (2016) midieron el pandeo en el plano de aguijones de *A. cerana*: **6,72 mN**. Con su
longitud (1,62 mm, Das et al. 2018) el modelo da **5,7 mN** (−15 %), sin ajustar nada. Con los 1,32 mm de *A. mellifera*,
8,6 mN. La abeja empuja con ~5,75 mN y perfora con 4,25: trabaja cerca del pandeo, por eso corrige el ángulo mientras
pica (Zhao et al. 2015; Das et al. 2018).

**En la piel el aguijón no pandea** mientras la piel ceda antes: `buckled = F ≥ F_cr y F_cr < F_p`. Con cualquier
empuje, la piel del brazo se rompe a 4,25 mN antes de que la abeja llegue a 8,6 mN. Una piel tres veces más tenaz
(12,8 mN) doblaría el aguijón de quitina y no el de acero (hay un test).

**En un sólido** la carga de pandeo es el límite de la herramienta: el `fBreak` que el motor 1.x ya usa con los
colmillos. La profundidad se congela donde la resistencia llega a esa carga (nunca baja al empujar más).

### 2.4 Anclaje de las púas: la piel se cierra detrás, la cutícula no

Una púa de altura b obliga al agujero de diámetro D a estirarse para dejarla pasar:

```
ε_púa = 2·b / (π·D)
```

- **Piel:** recupera hasta su deformación de rotura, **54 %** (Ní Annaidh et al. 2012). La abeja (b = 12 µm, la
  profundidad media Σb/n de Bissessarsingh & Starr 2021; D = 86 µm) pide un **8,9 %**: la piel se cierra detrás de cada
  púa y la engancha.
- **Cutícula de insecto:** recupera `Y/E ≈ (0,42 GPa/2,8)/3,05 GPa ≈ 4,9 %` (dureza de la base del aguijón, Das et al.
  2018; módulo de la cutícula fresca, Dirks & Taylor 2012). La púa talla un surco que no se cierra y el aguijón sale
  por él. Es lo que se observa: una abeja saca el aguijón cuando pica a otro artrópodo (Tautz 2008, citado por
  Bissessarsingh & Starr 2021); además, su punta (~7 HV) no atraviesa un esclerito (~43 HV), así que pica por las
  membranas blandas.
- **Sólidos del banco:** `Y/E` de su superficie: 0,3-3 % (metales, pintura, ABS, madera). Los frágiles (vidrio, cuarzo…)
  no recuperan nada: se agrietan. Ninguno engancha una púa.

**Fuerza para arrancarlo** (si las púas quedan expuestas): `F_anclaje = J_anclaje·Σb`, con Σb la suma de las
profundidades de las púas de las dos lancetas. `J_anclaje = 0,61 kJ/m²` se **calibra** con la abeja: 113,5 mN (Ling et
al. 2017) y 136,0 mN (Ling et al. 2016) sobre 2 × 102 µm (Bissessarsingh & Starr 2021). Es algo más de un tercio de la
tenacidad al corte de la piel. Para la abeja da 124 mN: **181 veces su peso** (0,69 mN).

### 2.5 ¿Se queda clavado? Autotomía

- **Regla de 51 especies** (Bissessarsingh & Starr 2021): la autotomía es probable con un índice de serrado
  `Sr = Σb/anchura de la lanceta ≥ 1` o con 8 púas o más por lanceta; improbable por debajo.
- **Enfundado** (Mulfinger et al. 1992): en los véspidos, el estilete liso es más ancho que las lancetas y enfunda las
  púas al retraerlas; en la abeja es demasiado estrecho y las púas quedan siempre fuera.
- **Resultado:** `stuck = engaged y riesgo "casi siempre"`. Riesgo: «casi siempre» (Sr ≥ 1 u 8 púas, sin enfundar:
  la abeja), «a veces» (las enfunda: *Vespula*, que a veces lo deja si se la aparta a la fuerza, Greene et al. 2012) o
  «nunca». La regla reproduce la tabla de autotomía de las seis especies con datos de púas (hay un test).
- **Autotomía:** la abeja no puede tirar 181 veces su peso; lo que cede es el aparato del aguijón, sujeto por músculos
  atrofiados (Hermann 1971). Se lleva el saco del veneno, el ganglio terminal, los músculos y a veces parte del
  intestino; la abeja muere entre 18 y 114 h después (Ramirez-Esquivel & Ravi 2023).
- **Reforjar no cambia nada de esto:** el anclaje es de la geometría y del tejido, y la autotomía, del abdomen.

### 2.6 Durezas: por qué ningún aguijón natural raya nada

Se aplica el criterio de siempre (FISICA.md §4: la punta cede con `r = HV_punta/HV_objetivo < 0,8`; marca tenue hasta
1,25), con la dureza de la **punta** (Das et al. 2018): 0,07 GPa = 7,1 HV en la abeja y 0,09 GPa = 9,2 HV en la avispa,
~6 veces más blanda que la base.

- Contra el vidrio (550 HV), el acero (200), el cobre (90), la uña (25), la pintura (20) o el ABS (16), r < 0,5: la
  punta se aplasta.
- **La madera, a la escala de la punta.** El pino es blando en bloque (Janka: 2,5 HV), así que el motor 1.x dejaría que
  la punta de 7 HV de una abeja se hundiera ~26 µm con 5,75 mN. Pero una punta de 1-3 µm es del tamaño del espesor de una pared celular, y las
  paredes de las traqueidas tienen **0,45 GPa = 45,9 HV** (Konnerth et al. 2009, nanoindentación en abeto): r = 0,16.
  `Sting.micro_hv(target)` devuelve esa dureza para la madera (`CELL_WALL`); la puerta de roble ya tiene su laca de
  18 HV encima.
- **Reforjado:** un aguijón de acero (200 HV) raya y perfora el pino (r = 4,4), el ABS y el cobre, y no el vidrio (r =
  0,36); uno de diamante perfora el vidrio. La profundidad la da el motor de siempre, con el pandeo como límite.

### 2.7 Veneno y giro

- **Bomba de válvulas (abeja):** el aguijón clavado sigue bombeando. Al menos el 90 % del saco sale en 20 s y todo en
  1 min (Schumacher et al. 1994): exponencial `f(t) = 1 − e^(−t·ln10/20 s)` (τ = 8,7 s). El saco de una abeja europea
  guarda 147 µg (Schumacher et al. 1990). Quitarlo a los 2 s deja pasar un 21 %: por eso cuenta la rapidez y no el
  método, rascar o pellizcar (Visscher et al. 1996).
- **Saco muscular (véspidos, pompílidos):** se exprime durante la picadura (~0,5 s, estimación); ~3 µg de proteína por
  picadura en *Vespula* (Sahiner & Durham 2019, que citan a Hoffman & Jacobson 1984) y 2-15 µg en un véspido típico
  (prospecto de los extractos alergénicos).
- **Giro helicoidal (abeja):** la fila de púas forma una hélice dextrógira de ~8,5° y el aguijón gira **−8,4°** (horario
  visto desde la base) al entrar; menos en sustratos duros; ~−8° en gel de sílice, el más parecido a la piel (Wu et al.
  2014). El reparto lineal con la profundidad (`Sting.twist_deg`) es una hipótesis para la animación.

## 3. Datos por especie

Calidad: **P** medido en la especie o su género · **S** revisión, divulgación o especie hermana · **E** estimación.

### 3.1 Abeja melífera (*Apis mellifera*, obrera)

| Dato | Valor | Calidad | Fuente |
|---|---|---|---|
| Longitud útil (hasta el bulbo) | 1,32 mm (1320 ± 61 µm) | P | Ramirez-Esquivel & Ravi 2023 |
| Eje del aguijón | 1,81 mm; ala anterior 8,6 mm | P | Bissessarsingh & Starr 2021 |
| Diámetro del estilete | ~86 µm (parte media) | S (*A. cerana*) | Zhao et al. 2015 |
| Canal del veneno | 39 ± 4,5 µm | P | Ramirez-Esquivel & Ravi 2023 |
| Radio y ángulo de la punta | 1-1,5 µm (usamos 1,25); ápice de 33° | S (*A. cerana*) | Ling et al. 2017 (dato citado del texto; no hemos podido leer el original) |
| Púas por lanceta | 10 (8-9 contando solo las agudas) | P | Ramirez-Esquivel & Ravi 2023; Bissessarsingh & Starr 2021 |
| Posición y tamaño de las púas | la 1.ª a 52,6 µm; separaciones 23,6 → 143,6 µm; alturas 12-22,4 µm | P | Ramirez-Esquivel & Ravi 2023 |
| Ángulo de las púas | 90° cerca de la base → 46° cerca de la punta; fila en hélice de 8-9° | P | Wu et al. 2014 |
| Serrado | Σb = 102 µm, Sr = 2,43; no se enfundan | P | Bissessarsingh & Starr 2021; Mulfinger et al. 1992 |
| E y H (base, medio, punta) | 3,08/0,42 · 1,42/0,22 · 0,42/0,07 GPa (secas) | S (*A. cerana*) | Das et al. 2018 |
| Fuerza de perforación | 1,34 mN; 2-3 mN (cerdo); 5,75 mN (conejo) | S (*A. cerana*) | Ling et al. 2016; Zhao et al. 2015; Ling et al. 2017 |
| Fuerza de extracción | 113,5 y 136,0 mN (solo 3,3 × F_p en piel de cerdo: §5) | S (*A. cerana*) | Ling et al. 2017, 2016; Zhao et al. 2015 |
| Pandeo en el plano | 6,72 mN | S (*A. cerana*) | Ling et al. 2016 |
| Autotomía | sí (+); muere en 18-114 h | P | Bissessarsingh & Starr 2021; Hermann 1971; Ramirez-Esquivel & Ravi 2023 |
| Ángulo de inserción | óptimo −6° (MEF); casi perpendicular, varía unos grados | S (*A. cerana*) | Das et al. 2018; Zhao et al. 2015 |
| Giro al entrar | −8,36° | P | Wu et al. 2014 |
| Duración de la inserción | ~1,5 s | S (*A. cerana*) | Zhao et al. 2015 |
| Veneno | 147 µg en el saco; ≥90 % en 20 s, todo en 1 min | P | Schumacher et al. 1990, 1994 |
| Schmidt | 2 | P | Schmidt 2016 (y 1990) |
| Aleteo | 231,5 ± 21,1 Hz (armónicos 462, 692, 925) | P | Herrera et al. 2023; ~230 Hz en Altshuler et al. 2005 |
| Masa | ~70 mg (pecoreadora vacía) | P | Glass et al. 2024 |

### 3.2 Avispa común (*Vespula vulgaris* / *V. germanica*, obrera)

| Dato | Valor | Calidad | Fuente |
|---|---|---|---|
| Longitud útil | ~1,55 mm (el aguijón entero, 2,67 ± 0,38 mm) | P (*V. vulgaris*) | Das et al. 2018 |
| Eje; ala anterior | 1,92 mm; 9,5 mm | P (*V. germanica*) | Bissessarsingh & Starr 2021 |
| Púas | 8 por lanceta, Σb 69 µm, Sr 0,99; el estilete las enfunda | P (*V. germanica*) | Bissessarsingh & Starr 2021; Mulfinger et al. 1992 |
| E y H (base, medio, punta) | 3,45/0,56 · 1,32/0,31 · 0,47/0,09 GPa (secas) | P (*V. vulgaris*) | Das et al. 2018 |
| Diámetro, canal, punta | 143 µm, 65 µm, 2,08 µm | E | escalado desde la abeja con la anchura de la lanceta (§3.9) |
| Fuerza de perforación | sin medición (los 6-8 mN de Zhao son de *Polistes*) | — | modelo: 7,1 mN |
| Autotomía | a veces (±); en ensayos clínicos, con frecuencia | P | Bissessarsingh & Starr 2021; Mulfinger et al. 1992; Greene et al. 2012 |
| Ángulo óptimo | +10° (MEF) | S | Das et al. 2018 |
| Veneno | ~3 µg de proteína por picadura | S | Sahiner & Durham 2019 |
| Schmidt | 2 (género; *V. pensylvanica*) | S | Schmidt 2016 |
| Aleteo | 165,8 ± 22,3 Hz | P (*V. germanica*) | Herrera et al. 2023 |
| Masa | 84,1 ± 19,0 mg (*V. vulgaris*); 74,1 ± 9,6 mg (*V. germanica*) | P | Kovac & Stabentheiner 2012 |

### 3.3 Avispa papelera (*Polistes dominula*)

| Dato | Valor | Calidad | Fuente |
|---|---|---|---|
| Eje; ala anterior | 2,37 mm; 12,4 mm | P | Bissessarsingh & Starr 2021 |
| Longitud útil | 1,82 mm | E | 0,77 × eje (§3.9) |
| Púas | 5, Σb 23 µm, Sr 0,40; lancetas en espiral que esconden las púas | P | Bissessarsingh & Starr 2021; Zhao et al. 2015 |
| Fuerza de perforación | 6-8 mN en piel de cerdo; 10-18 mN en gel de sílice | S (*Polistes* sp.) | Zhao et al. 2015 |
| Extracción | cociente extracción/perforación «muy pequeño» | S | Zhao et al. 2015 |
| Ángulo | baja de 18° a 9° mientras entra; el aguijón curvo se endereza | S | Zhao et al. 2015 |
| Duración de la inserción | ~0,5 s | S | Zhao et al. 2015 |
| Autotomía | nunca (−) | P | Bissessarsingh & Starr 2021 |
| Schmidt | sin valorar (las *Polistes*, de 1,5 a 3) | S | Schmidt 2016 |
| Aleteo | 108,8 ± 13,3 Hz | P | Herrera et al. 2023 |
| Masa | 89,8 ± 15,4 mg | P | Käfer et al. 2015 |
| Material, diámetro, punta | los de *Vespula*; 118 µm; 1,71 µm | E | Das et al. 2018; §3.9 |

### 3.4 Avispón europeo (*Vespa crabro*) y avispa asiática (*Vespa velutina*)

| Dato | *V. crabro* | *V. velutina* | Calidad | Fuente |
|---|---|---|---|---|
| Eje; ala anterior | 3,60 mm; 19,1 mm | 3,20 mm; 17,3 mm | P | Bissessarsingh & Starr 2021 |
| Longitud útil | 2,77 mm | 2,46 mm | E | 0,77 × eje |
| Púas | 7, Σb 68 µm, Sr 0,68 | 7, Σb 79 µm, Sr 0,80 | P | Bissessarsingh & Starr 2021 |
| Autotomía | nunca (−): robustos, arrancan las púas | nunca (−) | P | Bissessarsingh & Starr 2021 |
| Aleteo | 115,4 ± 9,8 Hz | 110,8 ± 22,2 Hz (primera medida publicada) | P | Herrera et al. 2023 |
| Masa | 477,5 ± 59,9 mg | 0,356-0,475 g (obreras grandes) | P | Kovac & Stabentheiner 2012; Kennedy et al. 2018 |
| Veneno | 2-15 µg (véspido típico) | ídem | S | prospecto de los extractos alergénicos |
| Schmidt | sin valorar | sin valorar | — | — |
| Material, diámetro, punta | *Vespula*; 205 µm; 2,98 µm | *Vespula*; 202 µm; 2,94 µm | E | Das et al. 2018; §3.9 |

### 3.5 Abejorro (*Bombus terrestris*)

Aleteo 168,6 ± 30,1 Hz (P, Herrera et al. 2023); masa de 0,22-0,63 g por sitio, usamos 0,27 g (S, Kardum Hjort et al.
2023, obreras conservadas en etanol); Schmidt 2 (S, género); sin autotomía: entre las abejas solo se conoce en *Apis*
(S, Ramirez-Esquivel & Ravi 2023). Tiene púas pequeñas (Packer 2003, vía Bissessarsingh & Starr 2021) sin recuento que
hayamos podido verificar. **Toda la geometría es estimación:** la de la abeja escalada por (masa/masa de la abeja)^(1/3)
= 1,57.

### 3.6 Hormiga bala (*Paraponera clavata*)

Schmidt 4 («dolor puro, intenso, brillante»; 4+ en 1990) (P, Schmidt 2016). Obreras de 18-30 mm y sin alas (S, AntWiki).
Sin autotomía: entre las hormigas solo se conoce en *Pogonomyrmex* y pocos géneros (S, Ramirez-Esquivel & Ravi 2023;
Hermann 1971). **Geometría, material y masa estimados:** la abeja escalada por la longitud del cuerpo (24/11,7 = 2,05);
masa ~0,13 g por el volumen de un cuerpo de ~25 × 3,5 mm con densidad ~1,1 g/cm³.

### 3.7 Avispa halcón (*Pepsis*)

Aguijón curvo de hasta 7 mm en las hembras (S, Britannica); lancetas lisas, sin púas, como todos los pompílidos (S,
Bissessarsingh & Starr 2021); Schmidt 4 en *P. grossa* («cegador, feroz, sorprendentemente eléctrico») (P, Schmidt 2016).
Masa (~0,6 g), punta, diámetro y material estimados (escalado 7/1,81 = 3,87; material de *Vespula*).

### 3.8 Fuera del catálogo

- **Mosquito hembra (*Aedes albopictus*):** 18 µN para meter el fascículo en la piel humana (Kong & Wu 2009). Fija el
  extremo inferior del deslizador (0,01 mN). No es un aguijón sino una pieza bucal, y el modelo no lo cubre: vibra el
  fascículo y sierra con las maxilas, y su labro es «nanoafilado»; con una punta de 50 nm, `2·J·R` daría 0,17 mN, diez
  veces lo medido.
- **Hormiga de fuego (*Solenopsis invicta*):** Schmidt 1,2 (1990) o 1 (2016). Sin datos del aguijón que hayamos podido
  verificar.

### 3.9 Escalados (estimaciones)

- **Punta, diámetro y canal** de las especies sin medición: los de la abeja multiplicados por un factor de tamaño. En
  los véspidos, la anchura de la lanceta (`Σb/Sr`, Bissessarsingh & Starr 2021) frente a la de la abeja (42 µm): 1,37
  (*Polistes*), 1,66 (*Vespula*), 2,35-2,38 (*Vespa*). En el abejorro, la masa; en la hormiga bala, la longitud del
  cuerpo; en *Pepsis*, la longitud del aguijón. Se apoya en que el aguijón crece con el insecto (eje/ala anterior 0,17-0,21
  en 51 especies, Bissessarsingh & Starr 2021) y en que la forma de los aguijones es universal (Jensen et al. 2020).
- **Longitud útil = 0,77 × eje:** 1,32/1,81 en la abeja y 1,55/1,92 en *Vespula*.
- **Empuje típico = 1,4 × F_p del modelo** en las especies sin medición: la abeja (5,75 mN medidos frente a 4,25) y la
  avispa papelera (8 frente a 5,8) empujan unas 1,4 veces lo justo. En todas queda entre F_p y la carga de pandeo (hay
  un test).
- **Material** de las especies sin nanoindentación: el de *Vespula* para los véspidos y *Pepsis*, el de la abeja para el
  abejorro y la hormiga (las hormigas son las parientes más cercanas de las abejas).
- **Tiempo de inserción** de las especies sin vídeo: 0,5 s los véspidos (como *Polistes*), 1,5 s el abejorro (como la
  abeja), 1 s la hormiga.

## 4. Estimaciones del modelo

| Magnitud | Valor | Razonamiento |
|---|---|---|
| Tenacidad de la grieta de perforación | 1,7 kJ/m² (la de corte de la piel) | la misma que usa el banco para seguir entrando; sin calibrar |
| Longitud efectiva de pandeo | K = 2 (voladizo) | punta libre antes de perforar; con la punta clavada sería K ≈ 0,7 (hasta ×8 de carga) |
| Sección de la columna | tubo de diámetro D con el canal dentro | ignora que lancetas y estilete son piezas separadas (menos rigidez) y los huecos de las lancetas |
| Límite elástico | Y = H/2,8 (Tabor) | como la plastificación de Hertz del banco; en los frágiles solo decide Johnson frente a Euler |
| Tenacidad de anclaje | 0,61 kJ/m² | **calibrada** con la extracción medida en la abeja (Ling et al. 2016, 2017) |
| Deformación recuperable de la piel | 54 % | deformación de rotura media de la piel de la espalda (Ní Annaidh et al. 2012) |
| Deformación recuperable de un sólido | Y/E; 0 en los frágiles | dúctiles: límite elástico; frágiles: se agrietan antes |
| Dureza de la madera a la escala de la punta | 45,9 HV | pared celular de abeto (Konnerth et al. 2009); roble: la misma (sin medición) |
| Veneno de los véspidos | lineal durante ~0,5 s | saco muscular; sin medidas de la cinética |
| Giro helicoidal | lineal con la profundidad | Wu et al. (2014) solo midieron el giro final |
| Mohs de la punta | 1,5 (etiqueta) | ~7-9 HV, entre el talco y el yeso; Mohs es ordinal |
| Curvatura (curve) | 0 (abeja) … 0,3 (*Polistes*, *Pepsis*) | forma observada (Zhao et al. 2015; Das et al. 2018); solo entra en el rayado |

## 5. Discrepancias entre fuentes

1. **«Avispa, 6-8 mN».** FISICA.md atribuye 6-8 mN a «la avispa»: Zhao et al. (2015) lo midieron en una avispa papelera
   (*Polistes* sp. de Pekín), no en la avispa común (*Vespula*). Todas las fuerzas medidas de «abeja» son de la abeja
   asiática (*A. cerana*), cuyo aguijón es casi idéntico (Ramirez-Esquivel & Ravi 2023).
2. **Perforación de la abeja: 1,34, 2-3 y 5,75 mN** (Ling 2016; Zhao 2015; Ling 2017): pieles distintas (conejo, cerdo)
   y protocolos distintos. El modelo (4,25 mN) cae en medio; el ROADMAP pedía «2-3 mN», que es solo una de las tres.
3. **Extracción: 113-136 mN** (Ling, 20-100 veces la perforación) frente a **3,3 veces** (Zhao, piel de cerdo sin
   subcutáneo, probablemente con pocas púas dentro). Usamos Ling: el aguijón entero dentro.
4. **Ángulos.** Los −6° (abeja) y +10° (avispa) son **óptimos calculados por elementos finitos** (Das et al. 2018), no
   ángulos medidos. Das atribuye además un «ángulo medio de penetración de −8,3°» que es en realidad el giro de Wu et al.
   (2014), −8,36°. Lo medido: la abeja entra casi perpendicular (Zhao) y *Polistes* baja de 18° a 9°.
5. **Gradiente de dureza.** Das et al. (2018): la base ~6 veces más dura que la punta (FISICA.md decía ~5). Ma et al.
   (2023, *Appl. Phys. A* 129, doi:10.1007/s00339-023-06480-w) describen un módulo uniforme a partir de autofluorescencia
   (microscopía confocal), que no es una medida mecánica: nos quedamos con la nanoindentación.
6. **Muestras secas.** Das et al. midieron aguijones secos; secar la cutícula la endurece hasta ×9 y la rigidiza hasta
   ×7,4 (Klocke & Schmitz 2011). Aun así, Euler con esos módulos reproduce el pandeo medido en aguijones frescos (Ling
   2016) con un 15 % de error.
7. **Púas de la abeja:** 10 por lanceta en MEB (Ramirez-Esquivel & Ravi 2023), 8-9 contando solo las agudas
   (Bissessarsingh & Starr 2021), 10-11 en otras especies de *Apis* (Jayasvasti & Wongsiri 1993, vía Bissessarsingh).
8. **Longitud del aguijón de la abeja:** 1,32 mm útiles (Ramirez-Esquivel), 1,81 mm de eje (Bissessarsingh), ~2,5 mm el
   aparato entero (Ramirez-Esquivel), 1,62 mm en *A. cerana* (Das); los «8,5 mm» de Wu et al. (2014) incluyen el aparato.
9. **Aleteo de la abeja:** 231,5 Hz en tienda de laboratorio (Herrera et al. 2023), 251 Hz al aire libre (citado ahí) y
   ~230 Hz en Altshuler et al. (2005).
10. **Schmidt de la hormiga de fuego:** 1,2 en la tabla de 1990 y 1 en el libro de 2016.

## 6. Qué no predice

- **La mecánica de cada golpe de lanceta.** La profundidad es la longitud útil, no se calcula con fuerzas: no hay
  medidas de la fuerza de cada golpe. Tampoco se modela que el insecto se aparte antes de clavarlo entero.
- **El mosquito** (18 µN): vibración, maxilas dentadas y un labro nanoafilado; fuera del rango del modelo (§3.8).
- **La curvatura** en el pandeo: un aguijón curvo (*Polistes*, *Pepsis*) pandea antes que la columna recta del modelo;
  en gel de sílice (10-18 mN) el de *Polistes* se dobló mucho (Zhao et al. 2015).
- **La punta clavada** en un sólido: con la punta sujeta, la carga de pandeo subiría hasta ~8 veces (K = 0,7).
- **La rotura** del aguijón a tracción al arrancarlo y la flexión de las púas (Zhao et al. 2015 lo mencionan).
- **Otras zonas del cuerpo:** una sola piel, la del brazo (en la palma la capa córnea mide ~170 µm).
- **El dolor y la toxicología:** el índice de Schmidt se enseña como dato, no se calcula.
- **Picar a otro insecto:** el catálogo 1.x no tiene cutícula; `Sting.CUTICLE` sirve para el anclaje, no para la
  perforación de un esclerito ni de sus membranas blandas.
- **Materiales experimentales frágiles:** un aguijón de vidrio o zafiro se partiría por flexión antes de pandear
  (no se modela la rotura, como en las uñas macizas de FISICA.md §13).

## 7. Guía de integración (oleada 2)

### 7.1 Catálogo y herramienta

- `catalog.gd`: añadir `Insects.STINGERS` a las garras y `Insects.GROUP` («Insectos») a sus grupos. `Insects.is_stinger(claw)`
  dice si una garra es un aguijón.
- `resolve_tool` (2.0) con un aguijón:
  - `keratin = false`: la cutícula no es queratina y el modo «húmeda» no la ablanda (los datos de Das ya son de muestras
    secas, más duras que en vida);
  - `baseR = stinger.diameterUm.value / 2000` mm (el radio real; la regla de las garras, 0,15 × reach, daría un aguijón
    4,6 veces más ancho);
  - `fBreak = Sting.buckling(claw, inlay).F` también si está **reforjado** (en las garras 1.x, el material nuevo anula
    el `fBreak`; aquí el pandeo depende del material);
  - `inject = true` en la piel, pero sin el texto «2 punciones» de los colmillos.
- **Ley de perforación 2.0 para todas las herramientas:** `Sting.puncture_force(area, stack)` en vez de
  `Physics.skin_puncture_force(area)`. Para las herramientas 1.x da exactamente lo mismo (test).

### 7.2 compute() en el modelo 2.0

- **Piel** (con `method == "puncion"`; con «rayado» los aguijones no tienen sentido: se recomienda desactivar rayado y
  desgarro para los insectos en la interfaz):
  - `sting = Sting.sting_report(p)`;
  - campos de siempre desde `sting`: `pierces`, `depthUm`, `fPuncture = sting.fPunctureN`, `layer` (nombre de
    `skin_layer_at(depthUm)` si perfora), `bleeds = pierces y depthUm > 75 µm`, `inject = true`,
    `fullReach = pierces`, `sev` con la severidad de piel de siempre, `grooveWidthUm` = diámetro del aguijón;
  - veredicto: `Sting.skin_verdict(sting)` o una versión propia con los mismos hechos.
- **Sólidos:** `r = Physics.compute(Sting.solid_params(p))` (camino 1.x: garra con el material de la columna,
  `fBreak` = pandeo, objetivo con la dureza de la pared celular si es madera, `wet = false` y `strike = false`, porque
  un aguijón no golpea) y `r.sting =
  Sting.sting_report(p)`. Si `r.toolBroken`, cambiar «SE ROMPE LA PUNTA» por «SE DOBLA EL AGUIJÓN» con `Sting.fmt_mn`
  (el texto 1.x imprime la carga con 16 cifras: «0.7283136065038798 N»). Pendiente: en las chapas, `baseR` real (§7.1).
- `Lab.duel()` y la comparativa, igual que con las garras.

### 7.3 Campos nuevos: `result.sting` (null si la herramienta no es un aguijón)

| Campo | Tipo | Unidad | Qué es |
|---|---|---|---|
| `isStinger`, `species` | bool, String | — | siempre true; especie |
| `reforged`, `material` | bool, String | — | reforjado; id de la incrustación o «quitina» |
| `tipHv` | float | HV | dureza de la punta |
| `reachMm` | float | mm | longitud útil |
| `fPunctureN`, `punctureRegime` | float, String | N | fuerza para romper la piel; «fractura» o «davis» (null en sólidos) |
| `fBuckleN`, `bucklingMode` | float, String | N | carga de pandeo; «euler» o «johnson» |
| `buckled` | bool | — | pandea (en la piel: antes de perforar; en un sólido: la carga supera `fBuckleN`) |
| `pierces`, `depthUm`, `layerId` | bool, float, String | µm | en la piel: perfora, profundidad, id de la capa (null en sólidos) |
| `engaged`, `barbsKnown` | bool, bool | — | las púas se enganchan; hay datos de púas |
| `barbStrain`, `tissueStrain` | float | — | estiramiento que pide la púa y el que recupera el objetivo |
| `anchorN`, `pullToWeight` | float | N, — | fuerza para arrancarlo con las púas expuestas; esa fuerza entre el peso del insecto |
| `stuck`, `stuckRisk`, `autotomy` | bool, String, bool | — | se queda clavado; «casi siempre», «a veces», «nunca»; pierde el aparato |
| `twistDeg`, `angleDeg`, `insertionS` | float o null | °, °, s | giro acumulado; ángulo de inserción; duración |
| `venomUg`, `pumpT90S`, `pumpTotalS` | float o null | µg, s, s | veneno del saco o por picadura; 90 % (bomba de válvulas); total |
| `schmidt`, `wingbeatHz` | float o null | —, Hz | índice de dolor; frecuencia de aleteo |
| `hardnessRatio`, `targetMicroHv` | float o null | —, HV | en sólidos: r a la escala de la punta y dureza usada |
| `tipCrushed`, `canMark` | bool o null | — | en sólidos: la punta cede (r < 0,8); puede marcar (r ≥ 1,25) |

Funciones para la animación y el sonido: `Sting.venom_fraction(st, t)`, `Sting.venom_delivered_ug(st, t)`,
`Sting.twist_deg(st, depthUm, reachMm)`.

### 7.4 Veredictos sugeridos

| Situación | Veredicto | Texto |
|---|---|---|
| Abeja en la piel | SE QUEDA CLAVADO | «entra 1.3 mm y deja el veneno en la dermis; las púas se enganchan y la abeja se va sin su aguijón» |
| Véspido, abejorro, hormiga | PICA Y SE VA | «entra 1.5 mm, deja el veneno en la dermis y lo saca: puede repetir» |
| Poca fuerza | NO PERFORA | «la piel se hunde pero no se rompe (hace falta ~4.3 mN)» |
| Pandea antes de perforar | SE DOBLA EL AGUIJÓN | «pandea a ~8.6 mN antes de romper la piel (hace falta ~13 mN)» |
| Natural contra un sólido | LA PUNTA SE APLASTA | «la punta (7 HV) cede contra las paredes celulares del pino (46 HV)» |
| Reforjado que pandea | SE DOBLA EL AGUIJÓN | «el aguijón de acero pandea a ~728 mN tras entrar 73 µm» |

Frases con humor que no traicionan la física: «La abeja de acero muere igual: la autotomía es del abdomen, no de la
aguja.» · «Un aguijón no es un clavo: empuja 4 mN y el resto lo hacen las lancetas.» · «El pino es blando por fuera y
duro por dentro: sus paredes celulares son seis veces más duras que la punta.» · «Arrancarlo cuesta 181 veces lo que
pesa la abeja: por eso lo deja.» · «Cuanto antes lo quites, mejor; da igual cómo (Visscher 1996).»

### 7.5 Deslizador de fuerza

- `Lab.force_range(aguijón)`: unidad mN, logarítmico, **0,01-1000 mN** para los naturales (el mosquito, 0,018 mN, marca
  el extremo inferior; el pandeo natural más alto es el de *Pepsis*, 126 mN) y **0,01-5000 mN** para los reforjados (la
  abeja de diamante pandea a 3,8 N).
- Por defecto, `claw.force` (5,75 mN la abeja).
- Marcas útiles en el deslizador: `fPunctureN` y `fBuckleN`.
- Texto del botón de fuerza máxima: la masa en mg («peso ~70 mg»), no en kg.

### 7.6 Animación del banco

| Momento | Dato | Fuente |
|---|---|---|
| Aproximación | abeja: el aguijón ya fuera antes de tocar; *Polistes*: lo saca al tocar y dobla el abdomen (pica de frente o de espaldas) | Zhao et al. 2015 |
| Ángulo | abeja casi perpendicular (óptimo −6°, varía unos grados); *Polistes* de 18° a 9°; *Vespula* +10° (óptimo) | Zhao et al. 2015; Das et al. 2018 |
| Perforación | cuando la fuerza llega a `fPunctureN` | §2.1 |
| Inserción | `insertionS`: 1,5 s la abeja, ~0,5 s las avispas; las lancetas alternan (cadencia libre: sin dato) | Zhao et al. 2015; Ramirez-Esquivel & Ravi 2023 |
| Giro | abeja: −8,4° en total, horario visto desde la base | Wu et al. 2014 |
| Bombeo | abeja: el saco se vacía con `venom_fraction` (90 % en 20 s, todo en 1 min; se puede acelerar ×10 en pantalla); véspidos: durante la picadura | Schumacher et al. 1994 |
| Retirada | véspidos: sacan el aguijón (se enfunda) y pueden repetir | Mulfinger et al. 1992 |
| Autotomía | la abeja tira, se desgarra el aparato (aguijón, saco, ganglio, músculos) y se aleja sin él; el aguijón sigue bombeando | Ramirez-Esquivel & Ravi 2023 |
| Epílogo | «la abeja vivirá entre 18 y 114 h» | Ramirez-Esquivel & Ravi 2023 |

### 7.7 Dibujos (proporciones)

- Cuerpo y ala anterior (mm): `bodyMm` y `forewingMm` del bloque `stinger`.
- Aguijón: `shaftMm` (eje), `insertMm` (lo que entra), `diameterUm`; en la abeja, el bulbo mide 786 × 320 × 266 µm
  (Ramirez-Esquivel & Ravi 2023) y las púas están en `barbs.pitchUm` y `barbs.lengthUm` (10 por lanceta, la primera a
  52,6 µm de la punta, cada vez más separadas).
- Colores: `stinger.colors` (`body`, `bands`, `wings`, `sting`); `col` es el del aguijón, como en las garras.
- Escala: el eje del aguijón de la abeja mide ~1/6 de su cuerpo (1,81 de 11,7 mm); el de *Pepsis*, ~7 mm.

### 7.8 Zumbido

`stinger.wingbeat`: fundamental `hz` (± `sdHz`), armónicos `harmonicsHz` y sus niveles `powersDb` (Herrera et al. 2023,
tablas S1-S2). Los niveles son del sensor óptico (luz que cortan las alas), no presión sonora: sirven de guía para el
timbre, no como espectro acústico. La hormiga bala no tiene alas: no zumba. La frecuencia baja con el tamaño: abeja
231 Hz, abejorro 169, avispa 166, avispón 115, avispa asiática 111, papelera 109.

### 7.9 Ensayos experimentales que vale la pena enseñar

| Ensayo | Qué predice la física | Por qué |
|---|---|---|
| Abeja natural, piel, 5,75 mN | perfora (4,3 mN), entra 1,32 mm, se queda, autotomía; anclaje 124 mN | fractura en la punta; lancetas; piel que se cierra tras las púas |
| Abeja **de acero**, piel | perfora con los mismos 4,3 mN, pandearía a 728 mN (no a 8,6), se queda y la abeja muere igual | manda la geometría; la autotomía es del abdomen |
| Abeja natural, pino | la punta se aplasta (r = 0,16) | paredes celulares de 46 HV; con la dureza Janka el motor 1.x diría 26 µm |
| Abeja de acero, pino, 0,5 → 1 N | 60 µm; a 1 N pandea a 0,73 N con 73 µm | r = 4,4; Euler con E = 200 GPa |
| Abeja de acero, vidrio | no entra (r = 0,36) | el acero es más blando que el vidrio |
| Abeja de diamante, vidrio, 0,5 N | perfora con microfractura (15 µm); pandea a 3,8 N | r = 18; E = 1050 GPa |
| Abeja de oro, ABS, 0,1 → 0,4 N | perfora (44 µm a 0,1 N), pero a 0,4 N cede a 0,28 N | Johnson: el oro plastifica antes de pandear |
| Avispa de oro frente a avispa de vidrio | el oro (más rígido) cede antes que el vidrio | «más rígido no basta»: con una columna robusta manda el límite elástico |
| Piel 3 veces más tenaz | la abeja de quitina pandea antes de perforar; la de acero perfora | F_p = 12,8 mN > 8,6 mN de pandeo |
| Abeja contra cutícula de insecto | no se engancha y no se queda | la cutícula recupera un 4,9 % y la púa pide un 8,9 % |
| *Pepsis*, piel | llega a 5,4 mm (grasa) y nunca se queda | sin púas |
| Avispones, piel | pasan la dermis del brazo (2,2 mm) y dejan el veneno en la grasa | 2,5-2,8 mm útiles |

### 7.10 Casos de referencia

`godot/tests/fixtures/spec/aguijones.json` es una lista de casos `{ id, note, input, expect, source }`.

- `input`: los ids del oráculo (`geom`, `base`, `inlay`, `claw` = id del aguijón, `target`, `type`) y `force` (N),
  `length`, `tear`, `method`, `strike`, `passes`, `wet`, `model: "2.0"`.
- `expect`: `campo → { value | min | max, tol }`; el campo es una ruta con puntos dentro del resultado de `compute()`
  (`sting.stuck`, `depthUm`…). `tol` es **relativa** (`|x − value| ≤ tol·|value|`); `value` sin `tol` exige igualdad
  exacta (booleanos, textos, null y números); `min` y `max` son inclusivos.
- Las cotas de los casos con medición son las de la literatura (p. ej., la abeja 1,34-5,75 mN), no las del modelo.
- `test_sting.gd` comprueba los 24 casos contra la referencia (`Sting.sting_report` y `Sting.solid_params` con el motor
  de siempre). La integración tiene que cumplirlos con su `compute()`.

### 7.11 Dependencias con otras unidades

- **Zonas del cuerpo (unidad 1g).** `Sting.skin_sting` usa la pila de capas del objetivo (`target.tissue`, con el
  formato de `SKIN_LAYERS`) si la tiene, y si no la del brazo. Con otra zona cambian dos cosas y nada más: la tenacidad
  de la capa de arriba (`stack[0].jC`, que decide la fuerza de perforación) y la capa en la que acaba la longitud útil
  (dónde queda el veneno). Una palma con 170 µm de capa córnea no cambia la perforación si su `jC` es el mismo; si la
  unidad 1g da otro, el aguijón natural puede pandear antes de perforar (§2.3). Los casos de referencia usan el brazo.
- **Penetración genérica (unidad 1g).** La ley de perforación 2.0 (`Sting.puncture_force`: fractura en la punta y Davis
  en su rango) vale para cualquier herramienta y da lo mismo que la 1.x en todas las del banco. Si 1g escribe un módulo
  de penetración, conviene que la llame en vez de duplicarla.

## 8. Fuentes

- Altshuler DL, Dickson WB, Vance JT, Roberts SP, Dickinson MH (2005). Short-amplitude high-frequency wing strokes determine the aerodynamics of honeybee flight. *PNAS* 102:18213-18218. doi:10.1073/pnas.0506590102
- Bissessarsingh M, Starr CK (2021). Comparative morphology of the stinger in social wasps (Hymenoptera: Vespidae). *Insects* 12:729. doi:10.3390/insects12080729
- Das R, Yadav RN, Sihota P, Uniyal P, Kumar N, Bhushan B (2018). Biomechanical evaluation of wasp and honeybee stingers. *Sci. Rep.* 8:14945. doi:10.1038/s41598-018-33386-y
- Davis SP, Landis BJ, Adams ZH, Allen MG, Prausnitz MR (2004). Insertion of microneedles into skin: measurement and prediction of insertion force and needle fracture force. *J. Biomech.* 37:1155-1163. doi:10.1016/j.jbiomech.2003.12.010
- Dirks JH, Taylor D (2012). Fracture toughness of locust cuticle. *J. Exp. Biol.* 215:1502-1508. doi:10.1242/jeb.068221
- Encyclopaedia Britannica. «Tarantula hawk».
- Gibney MA, Arce CH, Byron KJ, Hirsch LJ (2010). Skin and subcutaneous adipose layer thickness in adults with diabetes at sites used for insulin injections. *Curr. Med. Res. Opin.* 26:1519-1530. doi:10.1185/03007995.2010.481203
- Glass JR, Burnett NP, Combes SA, Weisman E, Helbling A, Harrison JF (2024). Flying, nectar-loaded honey bees conserve water and improve heat tolerance by reducing wingbeat frequency and metabolic heat production. *PNAS* 121:e2311025121. doi:10.1073/pnas.2311025121
- Greene A, Breisch NL, Golden DBK, Kelly D, Douglass LW (2012). Sting embedment and avulsion in yellowjackets (Hymenoptera: Vespidae): a functional equivalent to autotomy. *Am. Entomol.* 58:50-57. doi:10.1093/ae/58.1.0050
- Hermann HR (1971). Sting autotomy, a defensive mechanism in certain social Hymenoptera. *Insectes Soc.* 18:111-120. doi:10.1007/BF02223116
- Herrera C, Williams M, Encarnação J, Roura-Pascual N, Faulhaber B, Jurado-Rivera JA, Leza M (2023). Automated detection of the yellow-legged hornet (*Vespa velutina*) using an optical sensor with machine learning. *Pest Manag. Sci.* 79:1225-1233 (tablas S1-S2). doi:10.1002/ps.7296
- Jensen KH, Knoblauch J, Christensen AH, Haaning KS, Park K (2020). Universal elastic mechanism for stinger design. *Nat. Phys.* 16:1074-1078. doi:10.1038/s41567-020-0930-9
- Käfer H, Kovac H, Oswald B, Stabentheiner A (2015). Respiration and metabolism of the resting European paper wasp (*Polistes dominulus*). *J. Comp. Physiol. B* 185:647-658. doi:10.1007/s00360-015-0915-7
- Kardum Hjort C, Smith HG, Allen AP, Dudaniec RY (2023). Morphological variation in bumblebees (*Bombus terrestris*) after three decades of an island invasion. *J. Insect Sci.* 23:10. doi:10.1093/jisesa/iead006
- Kennedy PJ, Ford SM, Poidatz J, Thiéry D, Osborne JL (2018). Searching for nests of the invasive Asian hornet (*Vespa velutina*) using radio-telemetry. *Commun. Biol.* 1:88. doi:10.1038/s42003-018-0092-9
- Klocke D, Schmitz H (2011). Water as a major modulator of the mechanical properties of insect cuticle. *Acta Biomater.* 7:2935-2942. doi:10.1016/j.actbio.2011.04.004
- Kong XQ, Wu CW (2009). Measurement and prediction of insertion force for the mosquito fascicle penetrating into human skin. *J. Bionic Eng.* 6:143-152. doi:10.1016/S1672-6529(08)60111-0
- Konnerth J, Gierlinger N, Keckes J, Gindl W (2009). Actual versus apparent within cell wall variability of nanoindentation results from wood cell walls related to cellulose microfibril angle. *J. Mater. Sci.* 44:4399-4406. doi:10.1007/s10853-009-3665-7
- Kovac H, Stabentheiner A (2012). Does size matter? Thermoregulation of 'heavyweight' and 'lightweight' wasps (*Vespa crabro* and *Vespula* sp.). *Biol. Open* 1:848-856. doi:10.1242/bio.20121156
- Ling J, Jiang L, Chen K, Pan C, Li Y, Yuan W, Liang L (2016). Insertion and pull behavior of worker honeybee stinger. *J. Bionic Eng.* 13:303-311. doi:10.1016/S1672-6529(16)60303-7
- Ling J, Song Z, Wang J, Chen K, Li J, Xu S, Ren L, Chen Z, Jin D, Jiang L (2017). Effect of honeybee stinger and its microstructured barbs on insertion and pull force. *J. Mech. Behav. Biomed. Mater.* 68:173-179. doi:10.1016/j.jmbbm.2017.01.040
- Ma Y, Zhang G, Sun Q, Gorb S (2023). Functional morphology of the honeybee stinger and its biomechanical significance. *Appl. Phys. A* 129. doi:10.1007/s00339-023-06480-w
- Mulfinger L, Yunginger J, Styer W, Guralnick M, Lintner T (1992). Sting morphology and frequency of sting autotomy among medically important vespids (Hymenoptera: Vespidae) and the honey bee (Hymenoptera: Apidae). *J. Med. Entomol.* 29:325-328. doi:10.1093/jmedent/29.2.325
- Ní Annaidh A, Bruyère K, Destrade M, Gilchrist MD, Otténio M (2012). Characterization of the anisotropic mechanical properties of excised human skin. *J. Mech. Behav. Biomed. Mater.* 5:139-148. doi:10.1016/j.jmbbm.2011.08.016
- Pereira BP, Lucas PW, Swee-Hin T (1997). Ranking the fracture toughness of thin mammalian soft tissues using the scissors cutting test. *J. Biomech.* 30:91-94. doi:10.1016/s0021-9290(96)00101-7
- Ramirez-Esquivel F, Ravi S (2023). Functional anatomy of the worker honeybee stinger (*Apis mellifera*). *iScience* 26:107103. doi:10.1016/j.isci.2023.107103
- Sahiner UM, Durham SR (2019). Hymenoptera venom allergy: how does venom immunotherapy prevent anaphylaxis from bee and wasp stings? *Front. Immunol.* 10:1959. doi:10.3389/fimmu.2019.01959
- Sahlabadi M, Hutapea P (2018). Novel design of honeybee-inspired needles for percutaneous procedure. *Bioinspir. Biomim.* 13:036013. doi:10.1088/1748-3190/aaa348 (las agujas con púas reducen la fuerza de inserción un 21-46 %)
- Schmidt JO (1990). Hymenopteran venoms: striving toward the ultimate defense against vertebrates. En Evans DL, Schmidt JO (eds.), *Insect Defenses*, SUNY Press, pp. 387-419.
- Schmidt JO (2016). *The Sting of the Wild*. Johns Hopkins University Press.
- Schumacher MJ, Schmidt JO, Egen NB, Lowry JE (1990). Quantity, analysis, and lethality of European and Africanized honey bee venoms. *Am. J. Trop. Med. Hyg.* 43:79-86. doi:10.4269/ajtmh.1990.43.79
- Schumacher MJ, Tveten MS, Egen NB (1994). Rate and quantity of delivery of venom from honeybee stings. *J. Allergy Clin. Immunol.* 93:831-835. doi:10.1016/0091-6749(94)90373-5
- Shergold OA, Fleck NA (2005). Experimental investigation into the deep penetration of soft solids by sharp and blunt punches, with application to the piercing of skin. *J. Biomech. Eng.* 127:838-848. doi:10.1115/1.1992528
- Tautz J (2008). *The Buzz about Bees*. Springer (citado por Bissessarsingh & Starr 2021).
- Visscher PK, Vetter RS, Camazine S (1996). Removing bee stings. *Lancet* 348:301-302. doi:10.1016/S0140-6736(96)01367-0
- Wu J, Yan S, Zhao J, Ye Y (2014). Barbs facilitate the helical penetration of honeybee (*Apis mellifera ligustica*) stingers. *PLoS ONE* 9:e103823. doi:10.1371/journal.pone.0103823
- Zhao Z-L, Zhao H-P, Ma G-J, Wu C-W, Yang K, Feng X-Q (2015). Structures, properties, and functions of the stings of honey bees and paper wasps: a comparative study. *Biol. Open* 4:921-928. doi:10.1242/bio.012195
