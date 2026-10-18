# Velociraptor, afilado y densidad de las garras experimentales · modelo, datos y guía (laboratorio 2.0, unidad 4e)

Petición de Eric: «añadir un hipotético nuevo animal al banco de tribología y a la prueba del coche en funcionamiento: el
dinosaurio Velociraptor, con su física, cuerpo y garras teóricas y aproximadas, por los propios físicos, más la parte de
garras experimentales de varios materiales y densidades y afiladez».

Es un animal extinguido: no se puede medir vivo. Aquí cada número sale de una medición publicada (el fósil, un escalado
medido en animales actuales, un ensayo con una réplica o un modelo publicado) y se dice de cuál. Lo que nadie ha medido
no se presenta como dato: se enseña como pregunta abierta.

- Datos y funciones del animal: `godot/core/lab/velociraptor.gd` (`ENTRY`, con las claves de una garra y el bloque `dino`).
- Afilado: `godot/core/lab/claw_sharpness.gd` (puro). Densidad y masa de las garras: `godot/core/lab/claw_mass.gd` (puro).
- Tests: `godot/tests/lab/test_velociraptor.gd`, `test_claw_sharpness.gd`, `test_claw_mass.gd` y
  `test_velociraptor_spec.gd` (casos de referencia de `godot/tests/fixtures/spec/velociraptor.json`).
- Fase B, tramo del banco (unidad 4i, §10): el velocirraptor en el catálogo 2.0 (`catalog.gd`), el afilado en `compute()`
  (`physics.gd`), los textos de la ficha y del deslizador (`dino_lab.gd`), el dibujo de la garra (`art_dino.gd`) y la
  patada del casuario en el banco (`claws_v2.gd`). Tests: `test_velociraptor_banco.gd`, `test_afilado_banco.gd` y
  `godot/tests/app/test_afilado_ui.gd`.
- Fase B, tramo del coche en marcha (unidad 4i-B2, §10.7 y `docs/fisica/coche-en-marcha.md` §14): el velocirraptor en
  `moving_car.gd` (cuerpo, salto, agarre y garras reforjadas con su masa y su afilado) y en la tarjeta (`moving_car_state.gd`).
  Tests: `test_moving_car_velociraptor.gd` y los casos de `coche-en-marcha.json`.
- El velocirraptor de cine (FICCIÓN, unidad 4i-B2, §11): `godot/core/lab/velociraptor_film.gd`, en su propio grupo del
  catálogo. Tests: `test_velociraptor_cine.gd`.

> **Educativo.** Como el resto del banco, el modelo da tendencias y órdenes de magnitud con datos publicados. Un
> velocirraptor es una **reconstrucción**: la ficha lo dice, y cada dato lleva su fuente y su tipo (§5).

## 1. Resumen

| | Valor | Banda | Tipo |
|---|---|---|---|
| Masa | 19,7 kg | 14,1-24,6 kg | escalado de actuales (el fémur) |
| Largo · cadera | 2,07 m · 0,5 m | 1,5-2,07 m | recopilado (Paul 1988; Turner et al. 2007) |
| Garra del dedo II, hueso | 64,8 mm por la curva exterior; base de 18,7 × 7,1 mm | 64,8-66,3 mm | medido en fósil |
| Garra de queratina | 92,7 mm | 76,2-95,7 mm | escalado de actuales (aves) |
| Punta de la garra | 138 µm, semiángulo 15° | — | **sin medición** (la de la arpía del banco) |
| Agarre de un pie | 382 N | 193-1130 N | escalado de actuales (gavilanes) |
| La garra sola, con sus músculos | 10 N | 10-19 N | modelo publicado (Bishop 2019), escalado |
| Carga de la réplica, con su masa | 483 N (2,5 pesos) | — | ensayo con réplica (Manning et al. 2006) |
| Carrera | 10,8 m/s (39 km/h) | 10,8-13,7 m/s | modelo publicado (Sellers & Manning 2007) |
| Salto | 4,84 m/s (17 km/h); sube 1,2 m | 4,84-5,93 m/s | escalado de actuales (aves) |

- **La garra no raja: pincha y sujeta.** Una réplica robótica de la garra de un dromeosáurido solo hizo punciones
  redondas de 3-4 cm en un cerdo, nunca un tajo (Manning et al. 2006). El animal saltaba sobre la presa, la sujetaba con
  la garra como un gavilán gigante y la inmovilizaba con su peso (Fowler et al. 2011). La garra, movida solo por sus
  músculos, apenas aprieta ~10 N (Bishop 2019): la fuerza grande la pone el peso.
- **Afilar da más presión y más hondura con la misma fuerza, pero la punta frágil se rompe antes.** La carga lateral que
  aguanta una punta crece con el cuadrado de su radio. Una garra de diamante con la punta natural aguanta ~45 N de lado;
  afilada a 1 µm, 2,3 mN. Y a partir de ~1 µm afilar más casi no mete más la punta (manda el cono): solo la hace más frágil.
- **La densidad del material apenas cambia el golpe.** Con el mismo trabajo muscular una garra más pesada no lleva más
  energía: va algo más lenta. En el velocirraptor, las dos garras de oro pesan el 3,4 % del animal (con el volumen
  generoso del motor): apenas cambia. En la daga de oro del casuario, un 11 % de la masa del golpe: ahí se nota algo.

## 2. El animal

### 2.1 Masa: dos métodos, una banda

| Método | kg | Fuente |
|---|---|---|
| Escalado del fémur (cQE): circunferencia de 64 mm, α² = 2,008, recta de los cuadrúpedos actuales | **19,7** (±25 %: 14,8-24,6) | Campione et al. 2014; Campione & Evans 2012 (PGLS: log10 M[g] = 2,754·log10 C − 1,097); datos de MASSTIMATE |
| Reconstrucciones volumétricas (tres escaneos y un modelo físico) | 9,9 · 14,1 · 15,0 · 18,3 | recopiladas por Campione & Evans 2020 |
| Modelos biomecánicos | 20 | Sellers & Manning 2007; la réplica de Manning et al. 2006 imitaba «un velocirraptor de 20 kg» (según la prensa) |

- **Valor: 19,7 kg**, el del escalado del fémur, por tres razones: es un escalado medido en animales actuales; Campione &
  Evans (2020) vieron que en los dinosaurios pequeños los modelos volumétricos se suelen quedar cortos; y el modelo de
  carrera usó 20 kg (la réplica de la garra, según la prensa, también; el artículo calcula su fuerza con 40 kg, §7).
- **Banda: 14,1-24,6 kg**: la reconstrucción volumétrica de 14,1 kg (el extremo bajo de la horquilla que se cita) y el
  escalado más su error. El escaneo de 9,9 kg queda muy por debajo de los demás; Paul (2024) da hasta 28 kg para los mayores.
- El fémur medido más largo es de 238 mm (IGM 100/986), con una tibia de 255 mm (Norell & Makovicky 1999, tabla 2).

### 2.2 Cuerpo y plumas

- **Tamaño:** adultos de 1,5 a 2,07 m y ~0,5 m de cadera (Paul 1988; Turner et al. 2007: citados, sin poder leer los
  originales). Cuadra con los huesos: fémur, tibia y metatarso de IGM 100/986 suman 0,59 m, y de pie las articulaciones van
  dobladas. Para el dibujo se usa el extremo mayor, 2,07 m (solo dibujo: no entra en la física).
- **Pie didáctilo:** el animal apoyaba en los dedos III y IV y llevaba la garra del dedo II levantada (rastros de
  deinonicosaurios, Li et al. 2008).
- **Plumas:** papilas de las plumas secundarias en el cúbito de IGM 100/981, un animal de ~1,5 m y ~15 kg: 6
  conservadas y, por su separación, ~14 en total (Turner, Makovicky & Norell 2007). El ejemplar se ha renumerado
  (IGM 100/3503) y su atribución a *Velociraptor* está por revisar (Napoli et al. 2021); sus parientes dromeosáuridos con
  plumas conservadas lo respaldan.
- **Superficie de las «alas»: sin medición.** Las plumas no fosilizaron y el estudio de la carga alar de los paravianos
  (Pei et al. 2020) no incluye a *V. mongoliensis*. No entra en la aerodinámica: en el coche en marcha no hay postura de
  brazos abiertos (sería un número inventado). Pregunta abierta.

### 2.3 La garra falciforme del dedo II

- **Hueso (medido):** la falange ungueal II-3 mide 64,8 mm por la curva exterior (IGM 100/985; ~66,3 mm en IGM 100/982,
  aproximada), con una base de 18,3-23,4 mm de alto y 6,1-9,9 mm de ancho (Norell & Makovicky 1999, tabla 3). Es una
  hoja estrecha: 2,6 veces más alta que ancha.
- **Estuche de queratina (escalado):** no fosiliza. En 580 garras radiografiadas de 145 especies de aves, el núcleo óseo
  mide 0,693-0,705 veces el estuche (IC 95 %), sin diferencias entre grupos y ~0,70 en las rapaces (Hedrick et al.
  2019). Con 0,699: **92,7 mm**. Manning et al. (2006) midieron en 10 rapaces que el estuche sobresale como mucho un 15 %
  de la longitud total: 76,2 mm, la banda baja (§7). Sin estuche la garra es más corta y menos curva (Birn-Jeffery et al.
  2012).
- **Curvatura:** no hemos encontrado el arco de la garra del dedo II de *Velociraptor*. El caso medido más parecido es el
  de *Deinonychus*: 160° de arco interior, en lo alto de las aves trepadoras (129,5-161,6°; Manning et al. 2006). Se usa
  para el dibujo y para el `curve` del motor (0,9, el de las garras más curvas del banco: la arpía).
- **Punta: sin medición (pregunta abierta).** La queratina no fosiliza y no hemos encontrado radios de punta medidos en
  garras de vertebrados. Se ensaya con la punta del talón de la arpía del banco (0,06 mm², 138 µm de radio, semiángulo
  15°: estimación de la 1.x), su análogo funcional: la garra del dedo II de los dromeosáuridos equivale al talón agrandado
  del dedo II de las accipítridas (Fowler et al. 2011). El deslizador de afilado (§3) enseña cuánto importa.
- **Material:** la queratina de las garras del banco, 32 HV y 2,0 GPa (McKittrick et al. 2012). Nunca corta el acero de
  un coche (r = 32/101 < 0,8).

### 2.4 Qué hacía con la garra

- **Réplica robótica** (Manning et al. 2006): una pata hidráulica con la garra del dedo II de *Deinonychus* y un estuche
  de Kevlar y fibra de carbono, a 2 y 11 m/s contra un cerdo: solo punciones redondas de 30-40 mm, nunca un tajo. Contra
  la piel de cocodrilo rebotó, y en una prueba se le partió la punta.
- **Elementos finitos** (Manning et al. 2009): la garra de la mano de *Velociraptor*, con la queratina del búho real,
  aguanta bien la carga a lo largo de su eje y mal la tangencial. La punta pincha y agarra.
- **Modelo de sujeción de las rapaces** (Fowler et al. 2011): la garra del dedo II sujeta como el talón de un gavilán; el
  peso del animal inmoviliza a la presa; los metatarsos cortos y robustos dan agarre a costa de velocidad.
- **Modelo musculoesquelético** (Bishop 2019): en un *Deinonychus* de 490 N, los músculos del dedo dan como mucho 18,9 N en
  la punta ósea de la garra (a 76 mm de la articulación): el 3,9 % del peso. Apoya la función de agarre de presas más
  pequeñas que él.

### 2.5 Fuerzas

- **Agarre de un pie (`force` de la ficha): 382 N (193-1130).** El escalado de las rapaces de `claws_v2.gd`: el gavilán
  de Cooper hembra (9,77 N con 450 g) con la pendiente de los accipítridos, 0,97 (abajo 0,79; arriba ×2,96, la
  dispersión entre técnicas; Sustaita & Hertel 2010). Suposición: el pie agarraba como el de un gavilán (Fowler et al.
  2011). Es una extrapolación de ×44 en masa: por eso la banda es ancha.
- **Carga de la réplica: 483 N.** Manning et al. (2006) cargaron su réplica con 2,5 pesos (981 N con 40 kg); con la masa de
  *Velociraptor*, 2,5 × 19,7 × 9,807 N.
- **La garra sola: 10 N (hasta 19).** Los 18,9 N de Bishop (2019) escalados a 19,7 kg con la semejanza geométrica (la
  fuerza muscular crece con m^(2/3) y los brazos con m^(1/3)): 10,2 N, el ~5 % del peso; 19,3 N con el doble de músculo.
  Con el estuche, aún menos: la punta queda más lejos de la articulación.
- Lo que enseñan juntas: la garra sola aprieta poco; el pie entero y, sobre todo, el peso del animal cayendo encima son
  los que la clavan.

### 2.6 Carrera y salto

- **Carrera: 10,8 m/s (39 km/h).** Modelo musculoesquelético de 20 kg optimizado con robótica evolutiva (Sellers &
  Manning 2007). El mismo modelo subestima a las especies actuales (emú 13,3 frente a 14 m/s, avestruz 15,4 frente a 17,
  persona 7,9 frente a 10): banda alta de 13,7 m/s (49 km/h), la de la mayor subestimación.
- **Salto: 4,84 m/s (17 km/h), hasta 5,93.** El trabajo de los músculos de las dos patas se convierte en energía
  cinética: ½·m·v² = w·(2·f·m), v = √(4·w·f), con w = 45 J por kg de músculo, medido en el salto máximo de la gallina de
  Guinea (Henry et al. 2005; 67,5 J/kg, el máximo esperable del músculo esquelético, es la banda alta), y f = 13,0 % de la
  masa en los músculos de cada pata, disecados en un avestruz (8,498 kg en una pata de 65,3 kg; Hutchinson et al. 2015,
  tabla 2). El salto no depende de la masa (Hill 1950). Con el 15 % por pata que usan Sellers & Manning (2007), 5,20 m/s:
  dentro de la banda. Es el mismo modelo que el salto del casuario de la unidad 4d.
- **Altura:** con 4,84 m/s el centro de masas sube 1,19 m (hasta 1,79) en un salto vertical. En el coche en marcha llega al
  capó (0,80 m) y al parabrisas (1,12 m), pero no al techo (1,475 m): §10.7.
- **Golpe de la ficha (`strike`):** cae con los dos pies por delante a la velocidad del salto, y cada pie lleva la mitad
  del impulso: v = 4,84 m/s, m = 9,85 kg (115 J por garra). Estimación: el reparto entre las dos patas no está medido.

### 2.7 En el coche en marcha (datos para la fase B)

- **Área frontal:** la del cuerpo de un ave, S_b = 0,00813·m^0,666 = 0,059 m² con 19,7 kg (Pennycuick et al. 1988),
  extrapolada desde las aves grandes medidas: es un cuerpo emplumado. Suposición: un terópodo emplumado agazapado frena
  como un ave grande posada, con los mismos factores de postura y los mismos Cd de `MovingCar.BIRD_AERO`.
- **Sin alas:** solo la postura agazapada (§2.2).
- **Apoyos:** 4 garras en el panel (dedos III y IV de los dos pies; Li et al. 2008) y un radio de apoyo de ~30 mm, del
  orden de las dos primeras falanges del dedo III (estimación, como el del águila).
- **Anclaje:** agarra con los pies como una rapaz («el pie se cierra en un puño», Fowler et al. 2011): el agarre de
  `FORCES.grip` y su banda, como las aves de `MovingCar`.

## 3. Afilado de las garras experimentales

Una garra «reforjada» en otro material (`Data.INLAYS`) conserva la forma de la garra: el material cambia la dureza y el
módulo, no la geometría (`Physics.resolve_tool`). El afilado sí cambia la geometría: el radio R de la esfera del ápice de
la punta esfero-cónica del motor. El semiángulo α es el de la garra.

### 3.1 Límites medidos

El afilado s ∈ [0, 1] va de la punta de la garra (s = 0: la de su ficha) al filo más fino medido en acero (s = 1), en
escala logarítmica: R(s) = R0·(R_min/R0)^s. Con s = 0 la garra es la de siempre, al bit.

| Marca | Radio | Fuente | Tipo |
|---|---|---|---|
| Hoja de afeitar (cuña de 17°) | **40 nm** (el extremo) | Roscioli et al. 2020 (citando a McCarthy et al. 2007) | medido (citado) |
| Cuchillo pulido con diamante de 1 µm en cuero | 0,12-0,20 µm | Verhoeven 2004, tabla 6: filo de 0,23-0,40 µm de anchura | medido; radio = anchura/2 (suposición) |
| Cuchillo afilado con grano 1000 | 0,5-0,75 µm | Verhoeven 2004: filo de 1-1,5 µm | medido; radio = anchura/2 |
| Aguijón de abeja | 1-1,5 µm | Ling et al. 2017 (microscopio electrónico) | medido en la especie hermana |
| Microagujas | 30-80 µm | Davis et al. 2004 | medido |
| Cono de diamante del Rockwell | 200 µm | ISO 6508-2 | norma |
| Punta de las garras del banco | 69-399 µm | catálogo 1.x | estimación de la 1.x |

No hemos encontrado una medición publicada que hayamos podido leer del radio del filo de un bisturí, ni del radio de la
punta de una garra de vertebrado: no se usan.

### 3.2 Más presión y más hondura con la misma fuerza

- **Elástico (Hertz, el contacto del motor):** p0 = (6·F·E*²/(π³·R²))^(1/3) ∝ R^(−2/3). La fuerza con la que el material
  empieza a ceder (p0 = 1,6·Y, Johnson; Y = H/2,8, Tabor) es F = π³·R²·p0³/(6·E*²): baja con R².
- **Plástico:** la presión media no pasa de la dureza H del material. Lo que gana la punta afilada es hondura: la huella de
  radio a = √(F/(π·H)) cabe más honda. En la esfera, h ≈ a²/(2R): crece como 1/R; en el cono, h = a/tan α − R·(1 − sen α)/sen α:
  el afilado ya casi no cuenta.

Diamante contra acero inoxidable (200 HV), semiángulo 15°:

| Radio de la punta | Presión elástica con 1 N | Empieza a marcar con | Hondura con 1 N | Hondura con 381,5 N (agarre) |
|---|---|---|---|---|
| 138 µm (natural) | 6,9 GPa | 4,3 mN | 0,59 µm | 533 µm |
| 10 µm | 40 GPa | 23 µN | 19 µm | 900 µm |
| 1 µm | 184 GPa | 0,23 µN | 45 µm | 926 µm |
| 0,155 µm (cuchillo pulido) | 637 GPa | 5,5 nN | 47 µm | 928 µm |
| 40 nm (hoja de afeitar) | 1,6 TPa | 0,36 nN | 47 µm | 929 µm |

Las presiones elásticas por encima de la dureza no llegan a darse (el material cede antes): muestran por qué una punta fina
marca con casi nada de fuerza. Con poca fuerza, afilar lo cambia todo (×76 de hondura); con mucha, o por debajo de ~1 µm,
casi nada.

### 3.3 Pero la punta afilada se rompe antes

- **De frente no se rompe:** una punta más dura que lo que pincha está en compresión triaxial (unidad 4d: el cono del
  Rockwell aguanta 1471 N contra acero templado). Además, de frente afilar ayuda: con menos fuerza se perfora, y en las
  microagujas el margen entre romperse y perforar la piel crece al afilar la punta (Davis et al. 2004).
- **La rompe la carga lateral:** la fricción μ·F mientras raya. La punta, una viga en voladizo con la carga a x0 del
  vértice (el mellado de la unidad 1f, `Fracture.tip_chip_load`, y la rotura de la 4d, `claw_fracture.gd`):
  σ(x) = 4·F·(x − x0)/(π·r(x)³). En el cono, r = tan α·(x + d) con d = R·(1 − sen α)/sen α, y la sección más cargada está en
  x* = d/2 + 1,5·x0 (nunca dentro de la esfera: el contacto reparte la carga). Con la carga en el vértice y α ≤ 30°:

  F_mella = σ·(27π/16)·R²·sen α·(1 − sen α)²/cos³α

  (0,836·σ·R² con α = 15°). Un test comprueba que da lo mismo que el muestreo de la unidad 1f (±0,2 %).
- **Crece con R²:** afilada a la mitad, aguanta la cuarta parte. Es la misma ley que usan Pattrick et al. (2018) en las
  garras de los insectos: para no romperse, el diámetro de la punta tiene que crecer con la raíz de la carga.
- **Frágiles** (metal duro, diamante, zafiro, moissanita, circonita, cuarzo, vidrio): se mellan con su resistencia a
  flexión medida. **Dúctiles** (acero, titanio, oro): se doblan con su tensión de flujo, H/2,8 (Tabor). **Sin datos**
  (hematites): no se predice. Resistencias y tenacidades: las de `claw_fracture.gd` (unidad 4d, coche-en-marcha.md §11.3).

Carga lateral en el vértice que aguanta la punta de 15° del velocirraptor, según su radio:

| Material | σ (MPa) | L (µm) | Natural (138 µm) | 10 µm | 1 µm | 40 nm | Punta mínima con 10 N de lado | A 1 µm, ¿efecto de escala? |
|---|---|---|---|---|---|---|---|---|
| Carburo de tungsteno | 3068 | 2,4 | 49 N | 257 mN | 2,6 mN | 4,1 µN | 62 µm | sí |
| Diamante | 2790 | 0,47 | 45 N | 233 mN | 2,3 mN | 3,7 µN | 65 µm | no |
| Zafiro | 760 | 3,2 | 12 N | 64 mN | 0,64 mN | 1,0 µN | 125 µm | sí |
| Moissanita | 380 | 7,1 | 6,1 N | 32 mN | 0,32 mN | 0,51 µN | 177 µm | sí |
| Circonita | 300 | 13 | 4,8 N | 25 mN | 0,25 mN | 0,40 µN | 200 µm | sí |
| Cuarzo | 52,4 | 116 | 0,84 N | 4,4 mN | 44 µN | 0,07 µN | 478 µm | sí |
| Strass y Swarovski | 45 | 88 | 0,72 N | 3,8 mN | 38 µN | 0,06 µN | 515 µm | sí |
| Acero (se dobla) | 700 | — | 11 N | 59 mN | 0,59 mN | 0,94 µN | 131 µm | — |
| Titanio (se dobla) | 525 | — | 8,4 N | 44 mN | 0,44 mN | 0,70 µN | 151 µm | — |
| Oro (se dobla) | 105 | — | 1,7 N | 8,8 mN | 88 µN | 0,14 µN | 337 µm | — |

«Punta mínima»: el radio por debajo del cual se mella o se dobla con 10 N de lado, R = √(F/(0,836·σ)) (`sharpest_surviving_um`).
La punta natural del velocirraptor (138 µm) aguanta 10 N de lado en metal duro, diamante, zafiro y acero; en vidrio o
cuarzo, ni la natural.

**Un ejemplo completo** (caso `compromiso-velocirraptor-diamante`): garra de diamante apretando acero con el agarre de un
pie (381,5 N) y μ = 0,1: 38 N de lado. Sin afilar aguanta 45 N: resiste. Afilada a media escala (2,35 µm) entra un 73 % más
(922 µm frente a 533) pero se mella con 13 mN. Con ese agarre no se puede afilar por debajo de ~128 µm.

Y una comprobación del mundo real: una hoja de afeitar, 50 veces más dura que el pelo, se mella al cortarlo cuando el pelo
se dobla y empuja de lado el filo (Roscioli et al. 2020).

### 3.4 La tenacidad: cuándo vale la resistencia medida

La resistencia a flexión se mide en probetas de milímetros y la fijan sus defectos. La distancia crítica
L = (K_Ic/σ_f)²/π (Taylor 2007) es el orden de esos defectos. Si la sección más cargada de la punta (r*, 1,15 R con 15°)
es más pequeña que L, la punta no puede contener ese defecto y aguanta más de lo que dice σ_f: es el **efecto de escala**,
y el modelo se queda del lado seguro (`sizeEffect`). Si r* es mucho mayor que L, σ_f manda.

- **Diamante** (L = 0,47 µm): afilado a 1 µm (r* = 1,15 µm) la resistencia medida manda: se mella de verdad.
- **Vidrio** (L = 88 µm): la resistencia de una hoja de ventana (45 MPa) la fijan arañazos de ese tamaño. Una punta de
  vidrio de 1 µm aguantaría bastante más de lo que dice el modelo. No se calcula cuánto: haría falta la distribución de
  defectos (Weibull), que no está medida para puntas.

### 3.5 Qué hace falta para usarlo

`ClawSharpness.tradeoff(r0_um, alpha_deg, s, e_tool_gpa, strength, force_n, mu, e_target_gpa, h_target_mpa)` devuelve
el compromiso completo: radio, ganancia de presión, presión de pico, fuerza para empezar a marcar, hondura plástica (todo
comparado con la punta natural), carga lateral, carga de mellado, punta mínima que aguanta y el resultado de `evaluate`.
`strength` es el diccionario de `ClawFracture.strength()` (unidad 4d, ya unida): `{ value, min, max, kind («flexion» |
«fluencia»), kic, quality, source }`; `ClawSharpness.strength_of(inlay)` lo da por material y `evaluate_inlay(tip, inlay,
lateral_n)` evalúa con él. Con null (queratina, hematites), `mode` = «sin_datos». Un test comprueba que la carga de
mellado es la de `ClawFracture.lateral_limit_n` cuando la sección más cargada cae en el cono, y otro, que los casos de
referencia usan las resistencias de la 4d.

## 4. Densidad de los materiales experimentales

### 4.1 Densidades

| Material (`INLAYS`) | Densidad (kg/m³) | Fuente | Tipo |
|---|---|---|---|
| Queratina (garra natural) | 1310 (1283-1335) | Mason 1963: queratina α de cuernos y púas, 25 °C | caso medido parecido (estimación) |
| Pan de oro | 19 300 | Royal Society of Chemistry, del CRC Handbook (95.ª ed.) | recopilado |
| Acero (1.4301) | 7900 (7900-8000) | Outokumpu 2013 (valores EN); thyssenkrupp 8000 (ASTM A240) | ficha técnica |
| Titanio (grado 2) | 4510 | METALCOR, ficha del 3.7035 (105 GPa, ≤ 150 HB: los del banco) | ficha técnica |
| Carburo de tungsteno (GC-005) | 14 930 (14 820-15 040) | General Carbide, Grade Specifications | ficha técnica |
| Strass (vidrio) | 2530 (2530-3000) | Pilkington: 158 lb/ft³; el strass clásico es vidrio al plomo (banda alta) | caso medido parecido (estimación) |
| Cristal Swarovski | 3000 (2900-3000) | Directiva 69/493/CEE: cristal al plomo, ≥ 2,90 (PbO ≥ 24 %) y ≥ 3,00 (PbO ≥ 30 %) | norma (mínimo legal; estimación) |
| Hematites | 5260 (5255-5260) | Handbook of Mineralogy (y VHN 1000-1100, la dureza del banco) | recopilado |
| Cuarzo | 2650 | Handbook of Mineralogy | recopilado |
| Circonita (sintética) | 5800 (5600-6000) | Nassau 1981, tabla 4 (depende del estabilizante) | recopilado |
| Zafiro (corindón) | 3980 (3980-4100) | Handbook of Mineralogy (calculada: 3997) | recopilado |
| Moissanita | 3220 | Nassau et al. 1997 | medido |
| Diamante | 3515 (3511-3515) | Handbook of Mineralogy | recopilado |

### 4.2 El efecto: primer principio, sin inventar nada

- **Volumen:** el cono del motor (base de 0,15 × alcance, `Physics.MODEL.clawBase`): V = π·r_b²·L/3; o, si se midió, un
  cono de base elíptica, V = π·h·w·L/12. En el velocirraptor, con la base medida del hueso y el largo de la queratina:
  3,2 cm³; con el cono del motor, 18,8 cm³ (generoso: la garra real es una hoja estrecha). Si ni con el cono generoso la
  masa importa, la conclusión es sólida.
- **La energía la ponen los músculos:** con el mismo trabajo muscular W, ½·m·v² = W. Una garra más pesada no lleva más
  energía: va algo más lenta (v ∝ 1/√m) y con algo más de impulso (p ∝ √m). La penetración por energía del banco es la
  misma.
- **Solo si la velocidad la impone otra cosa** (el coche que se mueve contra el animal, una caída) la masa añadida suma
  energía: ½·Δm·v².
- `ClawMass.energy_effect(...)` da la masa de la garra, lo añadido, su peso frente al animal y frente a la masa eficaz del
  golpe (`strike.m`), la velocidad con el mismo trabajo y la energía con la misma velocidad. «Se nota» a partir de un 5 %
  (una elección de texto, no física).

### 4.3 Resultados

Las dos garras falciformes del velocirraptor (19,7 kg; golpe de 9,85 kg por pie):

| Material | Una garra medida (3,2 cm³) | Con el cono del motor (18,8 cm³) | Las dos, de más (cono) | Del animal | Velocidad con el mismo trabajo |
|---|---|---|---|---|---|
| Queratina | 4,2 g | 25 g | — | — | ×1 |
| Oro | 62 g | 362 g | +675 g | 3,4 % | ×0,983 |
| Carburo de tungsteno | 48 g | 280 g | +511 g | 2,6 % | ×0,987 |
| Acero | 25 g | 148 g | +247 g | 1,3 % | ×0,994 |
| Circonita | 19 g | 109 g | +169 g | 0,9 % | ×0,996 |
| Hematites | 17 g | 99 g | +148 g | 0,8 % | ×0,996 |
| Titanio | 15 g | 85 g | +120 g | 0,6 % | ×0,997 |
| Zafiro | 13 g | 75 g | +100 g | 0,5 % | ×0,997 |
| Diamante | 11 g | 66 g | +83 g | 0,4 % | ×0,998 |
| Moissanita | 10 g | 60 g | +72 g | 0,4 % | ×0,998 |
| Cristal Swarovski | 9,7 g | 56 g | +63 g | 0,3 % | ×0,998 |
| Cuarzo | 8,5 g | 50 g | +50 g | 0,3 % | ×0,999 |
| Strass | 8,2 g | 47 g | +46 g | 0,2 % | ×0,999 |

**Apenas cambia**, ni con el material más denso ni con el volumen generoso: lo que decide qué raya y qué perfora es la
dureza, la forma (y el afilado) y la energía del animal, no el peso de la garra. En cambio, la daga del casuario (110 mm,
31 cm³ con el cono del motor) de oro pesa 0,61 kg: un 11 % más de masa en su patada (5 kg). Con el mismo trabajo sale un 5 %
más lenta y con la misma energía; si la velocidad la impone otra cosa, suma 18 J. Ahí sí se nota algo.

Con la patada de la 2.0 en el banco (§10.6: m = 7,81 kg, v = 4,84 m/s) la daga de oro añade 0,564 kg (la de queratina pesa
0,041): un 7,2 % de la masa del golpe. Con el mismo trabajo sale un 3,4 % más lenta; si la velocidad la impone otra cosa,
suma 6,6 J. Se sigue notando algo (caso `masa-daga-de-oro-del-casuario-patada-2-0`).

## 5. Tabla valor → fuente → tipo

| Valor | Dato | Fuente | Tipo |
|---|---|---|---|
| Fémur | 238 mm (IGM 100/986) | Norell & Makovicky 1999, tabla 2 | medido en fósil |
| Tibia | 255 mm | Norell & Makovicky 1999, tabla 2 | medido en fósil |
| Metatarso III | 99,1 mm (IGM 100/986); 85,6-86,2 (IGM 100/985) | Norell & Makovicky 1999, tabla 3 | medido en fósil |
| Circunferencia del fémur | 64 mm (α² = 2,008) | Campione et al. 2014 (datos de MASSTIMATE) | medido en fósil |
| Masa | 19,7 kg (14,1-24,6) | Campione et al. 2014; Campione & Evans 2012 y 2020 | escalado de actuales |
| Largo y cadera | 1,5-2,07 m; 0,5 m | Paul 1988; Turner et al. 2007 (citados) | recopilado |
| Plumas | papilas de las secundarias | Turner, Makovicky & Norell 2007; Napoli et al. 2021 | medido en fósil (atribución en revisión) |
| Superficie alar | — | Pei et al. 2020 no la incluye | sin medición: pregunta abierta |
| Pie didáctilo | dedo II levantado | Li et al. 2008 (rastros) | medido en rastros fósiles |
| Garra, hueso | 64,8 mm; base 18,7 × 7,1 mm | Norell & Makovicky 1999, tabla 3 | medido en fósil |
| Núcleo/estuche | 0,699 (0,693-0,705) | Hedrick et al. 2019 | escalado de actuales |
| Estuche ≤ 15 % | banda baja | Manning et al. 2006 | medido en actuales |
| Garra de queratina | 92,7 mm (76,2-95,7) | las dos anteriores | escalado de actuales |
| Arco de la garra | 160° (*Deinonychus*) | Manning et al. 2006 | caso medido parecido |
| Punta de la garra | 138 µm, 15° | la arpía del banco (1.x); Fowler et al. 2011 (análogo) | **sin medición** |
| Queratina | 32 HV, 2,0 GPa | McKittrick et al. 2012 (catálogo del banco) | medido en actuales |
| Agarre de un pie | 382 N (193-1130) | Sustaita & Hertel 2010; Ward et al. 2002 | escalado de actuales |
| Carga de la réplica | 981 N = 2,5 pesos (40 kg) → 483 N | Manning et al. 2006 | ensayo con réplica |
| Punciones de la réplica | 30-40 mm, redondas | Manning et al. 2006 | ensayo con réplica |
| La garra sola | 18,9 N con 490 N → 10 N (10-19) | Bishop 2019 | modelo publicado, escalado |
| Carrera | 10,8 m/s (10,8-13,7) | Sellers & Manning 2007 | modelo publicado |
| Salto | 4,84 m/s (4,84-5,93) | Henry et al. 2005; Hutchinson et al. 2015 | escalado de actuales |
| Área frontal | 0,059 m² | Pennycuick et al. 1988 | escalado de actuales (aves) |
| Apoyo del pie | 30 mm | falanges del dedo III (Norell & Makovicky 1999) | estimación |
| Golpe de la ficha | 4,84 m/s y 9,85 kg | el salto y la mitad de la masa | estimación |
| Patada del casuario en el banco (2.0) | 4,84 m/s y 7,55 kg: 88,41 J (hasta 339,7) | el salto (Henry et al. 2005; Hutchinson et al. 2015) con los músculos de la pata que patea de la hembra de 58 kg (Grzimek 2003; desde la unidad 4i-B2) | estimación |
| Alturas de los paneles del coche | capó 0,80 m · parabrisas 1,12 m · techo 1,475 m | Cui et al. 2025 (berlina de base) con los paneles del modelo | estimación (el borde y el alto, secundaria) |
| Velocirraptor de cine | §11.1 | *Deinonychus* | dato y estimación; la garra, ficción |
| Filo más fino | 40 nm | Roscioli et al. 2020 | medido (citado) |
| Filos de cuchillo | 0,23-0,40 µm y 1-1,5 µm de anchura | Verhoeven 2004 | medido |
| Aguijón · microagujas · Rockwell | 1-1,5 µm · 30-80 µm · 200 µm | Ling et al. 2017 · Davis et al. 2004 · ISO 6508-2 | medido · medido · norma |
| Carga de mellado ∝ R² | viga en voladizo | unidades 1f y 4d; Pattrick et al. 2018 | modelo |
| Distancia crítica | (K/σ)²/π | Taylor 2007 | modelo |
| Resistencias y tenacidades | por material | claw_fracture.gd (unidad 4d) | ficha técnica y medido |
| Densidades | por material | §4.1 | ficha, norma y medido |

## 6. Estimaciones y preguntas abiertas

| Dato | Valor | Por qué |
|---|---|---|
| Punta de la garra | 138 µm, 15° | La queratina no fosiliza y no hay radios de punta medidos en garras de vertebrados: la de la arpía del banco (estimación de la 1.x), su análogo funcional. **Pregunta abierta** |
| Superficie de las plumas de los brazos | — | Sin medición: no se usa. **Pregunta abierta** |
| Arco de la garra | 160° | El de *Deinonychus*: no hemos encontrado el de *Velociraptor* |
| Estuche de queratina | ×1/0,699 | Suposición: crecía como el de las aves, sus parientes vivos |
| Agarre | escalado de gavilanes | Suposición: el pie agarraba como el de un gavilán; extrapolación de ×44 en masa |
| Salto | aves | Suposición: el músculo de un dromeosáurido rinde como el de la gallina de Guinea y el avestruz |
| Golpe de la ficha | m/2 | Cada pie lleva la mitad del impulso al caer con los dos: el reparto no está medido |
| Masa eficaz de la patada del casuario en el banco | f·M (banda alta M/2) | Nadie ha medido la masa eficaz de una patada: la de los músculos de la pata que patea; arriba, todo su trabajo. El coche en marcha usa el animal entero con un tope de fuerza en la pata (§10.6; por qué el banco no lo usa: `docs/fisica/coche-en-marcha.md` §14.6) |
| Área frontal | la de un ave | Extrapolada a ~20 kg desde las aves grandes medidas |
| Apoyo del pie | 30 mm | Del orden de las falanges del dedo III |
| Radio de un filo | anchura/2 | Verhoeven mide la anchura del filo; se supone redondeado |
| Densidad de la queratina de garra | la α de cuernos y púas | No hemos encontrado la de las garras |
| Strass y Swarovski | vidrio sodocálcico; mínimo legal del cristal al plomo | Sin densidad publicada de los productos |

## 7. Discrepancias entre fuentes

1. **El estuche de queratina.** Hedrick et al. (2019), con 580 garras de 145 especies, dan un núcleo de ~0,70 veces el
   estuche (el estuche sobresale ~30 %); Manning et al. (2006), en 10 rapaces, «como mucho un 15 % de la longitud total».
   Miden distinto (Hedrick, arcos desde la articulación en radiografías). Se usa Hedrick (la muestra grande) y Manning da
   la banda baja: 76-96 mm.
2. **¿20 o 40 kg?** La prensa (ABC, 2005) dice que la réplica imitaba «un velocirraptor de 20 kg»; el artículo calcula la
   fuerza con 40 kg (un dromeosáurido de 2 m, como *Deinonychus*, cuya garra copia). Se usa el cociente publicado (2,5
   pesos), no la fuerza.
3. **Masa.** El escalado del fémur (19,7 kg) y las reconstrucciones volumétricas (9,9-18,3 kg) no coinciden: por eso la
   banda es ancha. Campione & Evans (2020) explican que en los dinosaurios pequeños los volúmenes se suelen quedar cortos.
4. **Unidades de la réplica.** Manning et al. (2006) escriben las velocidades en «m s⁻²»: por el contexto (imitar una
   patada) son m/s.
5. **El agarre frente a la garra sola.** El escalado de los gavilanes da 382 N por pie; el modelo de Bishop (2019), ~10 N
   en la punta de la garra con sus músculos. No se contradicen: el primero es el pie entero apretando; el segundo, la garra
   sola, con la punta lejos de la articulación. Por eso el modelo de sujeción carga la presa con el peso del animal.

## 8. Qué no predice

- **Lo que no fosiliza:** la punta de la queratina, las plumas y los músculos se ensayan con los casos parecidos de §6.
- **La carga real sobre la punta:** el banco da μ·F en el vértice; una garra curva que engancha carga su punta de lado
  también sin deslizar. La viga no ve la curvatura ni la sección aplanada (la garra falciforme es una hoja: débil de lado,
  como vio Manning et al. 2009).
- **El efecto de escala en números:** solo se señala (`sizeEffect`); haría falta la distribución de defectos (Weibull).
- **El desgaste:** no sigue a la punta tras mellarse, ni cómo se embota con el uso; tampoco cuánto aguanta afilada.
- **Puntas de más de 30° de semiángulo:** la sección más cargada caería dentro de la esfera, donde el contacto reparte la
  carga; el modelo se queda en el comienzo del cono.
- **El afilado del semiángulo:** se deja como el de la garra.
- **La inercia de la pata:** los segmentos de la pata de un dromeosáurido no están medidos; se usa la masa eficaz del golpe
  de la ficha.
- **El comportamiento:** si un velocirraptor habría saltado a un coche es un experimento mental.

## 9. Casos de referencia (fases A y B)

`godot/tests/fixtures/spec/velociraptor.json` (22 casos; los comprueba `test_velociraptor_spec.gd`).

- **Fase A** (15, contra los módulos puros): masa por el fémur, agarre de un pie, fuerzas de la garra, carrera y salto,
  garra falciforme, área frontal, diamante y vidrio afilados a 1 µm, la punta mínima de zafiro con 10 N, el acero afilado
  que se dobla, la presión con la misma fuerza, el compromiso completo con el diamante y la masa de las garras (tungsteno y
  oro en el velocirraptor; la daga de oro del casuario, con el golpe de la 1.x). Los valores se calcularon aparte con las
  fórmulas publicadas.
- **Fase B, banco** (7, unidad 4i): seis a través de `Physics.compute` con el catálogo 2.0 (tipo `banco`) y uno de masa:
  - `banco-velocirraptor-golpe-brazo`: ½ × 9,85 × 4,84² = 115,4 J; la queratina (32 HV) no marca el húmero (47,25 HV) y
    topa con él a 41,4 mm, con energía de sobra.
  - `banco-velocirraptor-raya-el-coche`: con el agarre de un pie raya la pintura (r = 32/20 = 1,6) hasta el metal
    (110 µm), pero no el acero de la chapa (r = 32/101 = 0,32).
  - `banco-velocirraptor-diamante-afilado-acero`: s = 0,5 da R = √(138,2 × 0,04) = 2,351 µm; al rayar, a = √(2F/(πH)) =
    0,352 mm y h = a/tan 15° − R·(1 − sen 15°)/sen 15° = 1,307 mm (0,918 con la punta natural); aguanta 0,836·σ·R² = 12,9 mN
    de lado y le llegan μ·F = 190,75 N: se mella; presión de pico ×(138,2/2,351)^(2/3) = ×15,1.
  - `banco-casuario-patada-brazo`: ½·(f·M)·v² = 2·w·f²·M = 88,41 J con la hembra de 58 kg (91,45 con los 60 kg de la 1.x,
    hasta la unidad 4i-B2); sigue topando con el húmero a 41,4 mm.
  - `banco-casuario-patada-puerta-de-roble`: con 88,41 J y 500 N se queda a 30,5 de los 35 mm (30,8 con 60 kg).
  - `banco-casuario-patada-banda-alta-puerta`: con la banda alta, w·f·M = 339,7 J (351,4 con 60 kg), sí la atraviesa: la
    incertidumbre de la masa eficaz decide el resultado.
  - `masa-daga-de-oro-del-casuario-patada-2-0`: la daga de oro con la patada de la 2.0 (§4.3), con 58 kg y 7,55 kg.
- **Fase B, coche en marcha** (unidad 4i-B2): seis casos en `godot/tests/fixtures/spec/coche-en-marcha.json` con el cálculo
  a mano (el de cine y la reconstrucción en el mismo salto al capó, el de cine contra la puerta y quieto en el techo, la
  reconstrucción agarrada a las barras y con garras de tungsteno afiladas): `docs/fisica/coche-en-marcha.md` §14.8.
- **El de cine en el banco**: dos escenarios del golden 2.0 (§11.3).

## 10. Guía de integración (fase B)

**Estado.** Tramo del banco hecho en la unidad 4i: §10.1, §10.2, el dibujo de la garra y el deslizador de §10.4, y la
patada del casuario en el banco (§10.6). Tramo del coche en marcha hecho en la unidad 4i-B2 (§10.3, en §10.7); la silueta
del coche es de la vista (unidades 4h, 4k y 4l).

### 10.1 Catálogo 2.0

- `Catalog`: grupo nuevo «Dinosaurios (reconstrucción)» (`Velociraptor.GROUP`) con `Velociraptor.entries()`, solo en el
  modelo 2.0; `data.gd` y el oráculo 1.x no cambian (hay un test).
- La ficha enseña «reconstrucción», la banda de la masa y la punta como pregunta abierta (`dino.sickle.tipRadiusUm.open`).
- `Lab.max_force_hint`: el agarre de un pie (382 N) y, en la nota, «la garra sola, ~10 N; la réplica, 483 N».

### 10.2 El afilado en `compute()`

- Parámetro 2.0 `sharpness` (0-1) de las garras **reforjadas** (`inlay` ≠ «none»): `resolve_tool` usa
  `ClawSharpness.sharpen(claw, s)` para `area` y `tipRadiusUm`; el resto del motor no cambia. Con s = 0 el ensayo es el de
  siempre, al bit (hay que comprobarlo contra el golden 2.0).
- Resultado: un campo `sharpness` con `tradeoff(...)` (con `strength` = `ClawSharpness.strength_of(inlay)` y μ la del
  motor) y el mellado en el vértice. La coincidencia con `ClawFracture.lateral_limit_n` ya tiene su test.
- Invariantes con `compute()`: más afilado nunca da menos hondura con la misma fuerza; una punta frágil más afilada nunca
  aguanta más carga lateral.

### 10.3 El velocirraptor en `MovingCar`

- Cuerpo nuevo (`dino.car`): aerodinámica de ave sin alas (solo agazapado), 4 garras de apoyo, agarre del pie como las
  rapaces y gancho de la garra falciforme en los bordes.
- Golpe al saltar: llega con la carrera (hasta 39 km/h) y el salto (4,84 m/s), con su aerodinámica. Unificar con el salto
  del casuario de la 4d (`MovingCar.KICK`): los mismos w y f.
- Masa de las garras reforjadas: `ClawMass.energy_effect` en el balance de energía del golpe (la velocidad relativa la
  impone el coche: suma ½·Δm·v²).

### 10.4 Tarjetas y dibujo

- **Garra (dibujo):** el hueso fósil (64,8 mm, arco de 160°, base de 18,7 × 7,1 mm) y el estuche que lo alarga hasta
  92,7 mm (la banda de 76 a 96 como sombra). Colores de `dino.colors` (dibujo).
- **Silueta para el coche:** 2,07 m de largo y 0,5 m de cadera, con plumas en los brazos plegados, la cola rígida (vértebras
  con prezigapófisis y cheurones alargados, Norell & Makovicky 1999) y la garra del dedo II levantada.
- **Afilado:** un deslizador «Afilado» (0-1) con las marcas de `ClawSharpness.REFERENCES`, y dos barras: presión (sube) y
  carga que aguanta de lado (baja).

### 10.5 Dependencias con otras unidades

- **4d (claw_fracture.gd, casuario):** resistencias y tenacidades de los materiales, `ClawFracture.strength(inlay)`, y el
  salto del casuario (`KICK`).
- **1k/4d (MovingCar):** el cuerpo nuevo y el golpe al saltar.
- **4c (tarjeta del coche en marcha):** la silueta y el selector del animal.

### 10.6 Hecho en el banco (unidad 4i)

- **Catálogo:** `Catalog.V2_CLAWS` y `V2_CLAW_GROUPS` llevan el velocirraptor y su grupo; `data.gd` y el oráculo no
  cambian (los SVG de la 1.x salen iguales, byte a byte).
- **Ficha** (`DinoLab.spec_rows`): material, «reconstrucción: fósil + aves actuales», la punta («R 138 µm · α 15° · sin
  medir», o «afilada»), la garra con su banda y el hueso fósil, el peso con su banda, el agarre de un pie con su banda y
  el golpe; debajo, el tipo de dato, la punta como pregunta abierta y las fuentes abreviadas. Fuerza máxima: el agarre
  de un pie (381,5 N) y, en la nota, «la garra sola, ~10 N; la réplica, 483 N».
- **Afilado en `compute()`:** `Physics.sharpenable(p)` (2.0, garra o colmillo con incrustación, no un aguijón),
  `sharpness_of(p)` (0-1) y `sharpness_report(p)`. `resolve_tool` toma de `ClawSharpness.sharpen` el área y
  `tipRadiusUm`; el campo `sharpness` del resultado (en `Physics.V2_FIELDS`: null en la 1.x) es el compromiso de
  `ClawSharpness.tradeoff` con la resistencia de `strength_of(inlay)`, la μ del ensayo al rayar (0 al punzar) y la fuerza
  que llega a la punta. En la piel, la presión de pico y la hondura de Hertz no se calculan (null): la piel no es un
  sólido de Hertz.
- **Deslizador «Afilado»** (tarjeta de la herramienta, solo con una garra o un colmillo reforjados): el valor es el radio
  de la punta; las marcas, la punta de la ficha y las referencias de `ClawSharpness.REFERENCES` que se pueden alcanzar;
  dos barras en la escala del deslizador (la presión con la misma fuerza, que sube, y la carga que aguanta de lado, que
  baja: coral si se mella, dorada si se dobla, apagada sin resistencia medida) y una nota. Todos los textos, de
  `LabState.sharpness_view()`. En el teléfono, las barras una debajo de otra. La comparativa da el radio de la punta
  afilada en vez de su área, y el resultado, la fila «Punta afilada».
- **Dibujo** (`art_dino.gd`): el hueso fósil de 64,8 mm por el lomo con su arco de 160° y la base de 18,7 × 7,1 mm (la
  sección, junto al dedo, con su rótulo), el estuche hasta 92,7 mm y la banda alta hasta 95,7 como sombra (la baja, una
  raya en el estuche), y un «?» en la punta (sin medir). Reforjada, sin hueso y con el color del material. En el banco
  cuelga con la punta hacia abajo. Colores de `dino.colors` (dibujo).
- **La patada del casuario en el banco** (`ClawsV2.kick_strike`): el golpe de la ficha del casuario en la 2.0 sale de la
  patada del coche en marcha, con las funciones de `MovingCar` (sin copiar números): la velocidad del salto, 4,84 m/s,
  con la masa de los músculos de la pata que patea, f·M = 7,81 kg: 91,45 J (la 1.x: 8 m/s y 5 kg, 160 J, sin fuente).
  Banda alta, todo el trabajo de esa pata: w·f·M = 351,4 J (m = M/2). Desde la unidad 4i-B2 el casuario de la 2.0 pesa
  58 kg, la hembra del coche en marcha: 7,55 kg, 88,41 J y 339,7 J (§10.7). Cambia tres escenarios del golden 2.0 (FISICA.md,
  «Cambios de la 2.0»): con su fuerza de ficha ya no atraviesa la puerta de roble (30,8 de 35 mm); con 2000 N, sí.
  El coche en marcha golpea con el animal entero y un tope de fuerza en la pata (5,1 pesos); el banco no tiene ese tope, y
  por eso su masa eficaz es la de la pata: son dos estimaciones distintas de la misma patada.

### 10.7 Hecho en el coche en marcha (unidad 4i-B2)

Detalle, resultados, tabla valor → fuente → tipo y casos en `docs/fisica/coche-en-marcha.md` §14. En resumen:

- **Cuerpo** (`MovingCar.BODIES`, `kind` «teropodo»): un ave sin alas, solo agazapada, con el área frontal de Pennycuick
  con su masa y los factores y los Cd de `BIRD_AERO` (§2.7, estimación); 4 garras de apoyo y 2 que golpean (las
  falciformes); el agarre de su ficha (`grip_band`, `FORCES.grip` con su banda) en el limpiaparabrisas, las barras y el
  borde de la ventanilla, como las rapaces (el gancho de la garra en los bordes es ese agarre: Fowler et al. 2011). La
  defensa y las garras reforjadas, como las rapaces. Tamaños de dibujo y `variant` para la vista.
- **El golpe, saltando** (`leap_block`): la carrera de su ficha (como mucho 38,88 km/h) y el salto de la patada del
  casuario (`kick_leap_ms`: los mismos w y f, sin copiar números; `Velociraptor.leap_speed_ms` lo lee de ahí), con el
  vuelo frenado por el aire (`leap_flight`, RK4) hasta la mitad del panel (Cui et al. 2025): llega al capó y al
  parabrisas; al techo, no. De costado golpea con la carrera.
- **La garra:** pincha y sujeta; su queratina no corta la chapa (r = 0,32): «ABOLLA Y RAYA».
- **Garras reforjadas:** su masa va al golpe (`ClawMass`, ½·Δm·v², sin romper la suma del balance) y se pueden afilar
  (`p.sharpness`, el de `Physics`; con s = 0, todo igual al bit).
- **Tarjeta:** un solo «Velocirraptor» con dos variantes (el de cine por defecto), dos experimentos de un clic, los textos
  (porqué, «¿sabías que…?», fuentes y moraleja) y el afilado (`sharpenable`, `set_sharpness`, `sharpness_view`).
- **Coherencia banco ↔ coche:** el casuario de la 2.0 pesa 58 kg en los dos; el cuarzo, 52,4 MPa en los dos; la patada
  del banco sigue sin el tope del coche (dos estimaciones en dos rigideces: `docs/fisica/coche-en-marcha.md` §14.6).

## 11. El velocirraptor de cine (FICCIÓN, unidad 4i-B2)

Petición de Eric: «Quiero a ese Velociraptor con una física algo más similar a Jurassic Park, ya que no es un animal que
exista como tal hoy en día, añádele un poco de chispa y fantasía, que sus garras en forma falciforme puedan desgarrar algo
el chasis y ciertas cosas, algo más divertido». Son **dos velocirraptores, no uno cambiado**: la reconstrucción de §2-§10
sigue igual, como dato, y este es el de la película, en su propio grupo del catálogo 2.0 («Dinosaurios de película
(ficción)»: una reconstrucción no lleva ficción dentro) y en el coche en marcha, donde sale por defecto al elegir
«Velocirraptor» (`godot/core/lab/velociraptor_film.gd`).

### 11.1 Lo que es real, lo es

Los raptores de la película de 1993 tienen el tamaño de *Deinonychus*: Michael Crichton basó en él los de la novela
(1990), siguiendo a Gregory Paul (1988), que lo metía en *Velociraptor*, y los de la película se diseñaron casi enteramente
con *Deinonychus*. Así que lo que no es la garra son datos de *Deinonychus*, con su calidad:

| Valor | Dato | Fuente | Tipo |
|---|---|---|---|
| Modelo | *Deinonychus antirrhopus* | Crichton 1990; Paul 1988 (recopilado) | secundaria |
| Largo y cadera | 3,3-3,4 m · 0,87 m | Paul 2016 (recopilado) | dibujo |
| Masa | 99,8 kg (44,3-124,8) | el fémur (116 mm, α² = 1,987) con el mismo escalado que la reconstrucción (Campione et al. 2014; MASSTIMATE); banda: la volumétrica más ligera (Campione & Evans 2020) y el escalado + 25 %. Las cuatro volumétricas (44,3-73 kg) quedan por debajo; Paul da 60-73 kg | estimación |
| Garra del dedo II con su estuche | 120 mm | Ostrom 1969 (más de 120 mm) | secundaria |
| Arco de la garra | 160° | Manning et al. 2006 | secundaria |
| Punta de la garra | 138 µm, 15° | la de la reconstrucción | **sin medición** |
| Agarre de un pie | 1841 N (696-5452) | los gavilanes de Sustaita & Hertel 2010 escalados ×222 en masa, como la reconstrucción | estimación |
| La garra sola, con sus músculos | 30 N (hasta 57) | Bishop 2019 modeló un *Deinonychus* de 490 N; escalado con m^(2/3) | estimación |
| Carga de la réplica | 2446,8 N (2,5 pesos) | Manning et al. 2006, con su masa | secundaria |
| Carrera · salto | 10,8 m/s · 4,84 m/s | los de la reconstrucción (§2.6): la carrera de *Deinonychus* no está modelada en las fuentes usadas | estimación |
| Apoyo del pie en el coche | 50 mm | el de la reconstrucción escalado con la cadera (0,87/0,5) | estimación |

### 11.2 Lo que es de película

- **Una calidad nueva, `ficcion`,** que la interfaz lee «ficción (película)» (en la ficha, en la tarjeta del coche y en sus
  fuentes; la tarjeta debe darle otro color). Nunca se presenta como un dato ni como una estimación.
- **Su garra raja la chapa:** 200 HV, 200 GPa y Mohs 5,5, los de la tachuela de acero del banco (`Data.INLAYS` «acero»), el
  doble que el acero de la carrocería (101 HV). Con eso el motor de siempre la raja o la perfora: no hay física nueva.
- **Cada fuente dice qué es de película y qué haría la garra de verdad:** es de queratina, ~32 HV, y frente a los 101 HV de
  la chapa (r = 0,32 < 0,8) cede la punta y no la corta; una réplica robótica solo hizo punciones redondas de 3-4 cm en un
  cerdo, nunca un tajo (Manning et al. 2006), y el animal sujetaba a la presa con su peso (Fowler et al. 2011).
- **El nombre corto,** «Velocirraptor de cine» (21 letras: los nombres del catálogo no pasan de 18 y la comparativa del
  teléfono no da para más); el título de la ficha es «Garra de velocirraptor de película (ficción)».

### 11.3 En el banco

- **Ficha** (`DinoLab.spec_rows` → `_film_rows`): «garra de película · 200 HV · ficción», «ficción (película) · tamaño de
  Deinonychus», la punta, la garra de 120 mm, el peso con su banda, el agarre de un pie con su banda y el golpe (cae con
  los dos pies a 4,84 m/s con la mitad de su masa: ½ × 49,9 × 4,84² = 584,5 J). La línea de fuentes empieza por
  «Ficción (película)» y abrevia sus referencias (Jurassic Park 1993 · Crichton 1990 · Paul 1988 · Campione 2014).
- **Golden 2.0:** dos escenarios, marcados como ficción en `docs/FISICA.md` («Cambios de la 2.0»): con el agarre de un pie
  (1841 N) raya el coche moderno y «RAJA LA CHAPA» (r = 200/20 = 10 con la pintura; la garra entera, 120 mm, al otro
  lado); de un golpe, «ATRAVIESA LA CHAPA» (584,5 J, agujero de ~36 mm). La reconstrucción, con la misma fuerza, se queda en
  el metal (test).
- Reforjada en otro material, es una garra reforjada más (con su afilado).

### 11.4 En el coche en marcha

`docs/fisica/coche-en-marcha.md` §14: el mismo cuerpo y el mismo salto que la reconstrucción con la masa de *Deinonychus*;
la garra de película corta la chapa (`can_cut_body` con la dureza de la propia garra) y los veredictos lo dicen con chispa
(«SALTA SOBRE EL CAPÓ Y LO RAJA», «SE ABALANZA Y RAJA LA PUERTA»), siempre con el contraste del de verdad. Un experimento
de un clic para cada uno, en el mismo salto, para compararlos.

## 12. Fuentes

- Birn-Jeffery AV, Miller CE, Naish D, Rayfield EJ, Hone DWE (2012). Pedal claw curvature in birds, lizards and Mesozoic
  dinosaurs. PLoS ONE 7:e50555. doi:10.1371/journal.pone.0050555
- Bishop PJ (2019). Testing the function of dromaeosaurid (Dinosauria, Theropoda) «sickle claws» through musculoskeletal
  modelling and optimization. PeerJ 7:e7577. doi:10.7717/peerj.7577
- Campione NE, Evans DC (2012). A universal scaling relationship between body mass and proximal limb bone dimensions in
  quadrupedal terrestrial tetrapods. BMC Biol. 10:60. doi:10.1186/1741-7007-10-60
- Campione NE, Evans DC, Brown CM, Carrano MT (2014). Body mass estimation in non-avian bipeds using a theoretical
  conversion to quadruped stylopodial proportions. Methods Ecol. Evol. 5:913-923. doi:10.1111/2041-210X.12226
- Campione NE, Evans DC (2020). The accuracy and precision of body mass estimation in non-avian dinosaurs. Biol. Rev.
  95:1759-1797. doi:10.1111/brv.12638
- Campione NE (2020). MASSTIMATE: Body Mass Estimation Equations for Vertebrates, paquete de R 2.0-1 (CRAN).
- Crichton M (1990). Jurassic Park. Alfred A. Knopf (los velocirraptores de la novela, basados en *Deinonychus*).
- Cui S, Shi L, Wang G, Chen J, Liu N, Long Y, Shi Z (2025). Study on the influence of passenger car front shape on
  pedestrian thorax injury based on the FASS database. Transp. Saf. Environ. 7(3):tdaf040. doi:10.1093/tse/tdaf040
- Davis SP, Landis BJ, Adams ZH, Allen MG, Prausnitz MR (2004). Insertion of microneedles into skin: measurement and
  prediction of insertion force and needle fracture force. J. Biomech. 37:1155-1163. doi:10.1016/j.jbiomech.2003.12.010
- Directiva 69/493/CEE del Consejo (1969), sobre el vidrio de cristal, anexo I.
- Fowler DW, Freedman EA, Scannella JB, Kambic RE (2011). The predatory ecology of Deinonychus and the origin of flapping
  in birds. PLoS ONE 6:e28964. doi:10.1371/journal.pone.0028964
- General Carbide. Grade Specifications (GC-005).
- Grzimek's Animal Life Encyclopedia (2003), 2.ª ed., vol. 8, Birds I. Gale (casuario común: hembra de 58 kg).
- Hedrick BP, Cordero SA, Zanno LE, Noto C, Dodson P (2019). Quantifying shape and ecology in avian pedal claws: the
  relationship between the bony core and keratinous sheath. Ecol. Evol. 9:11545-11556. doi:10.1002/ece3.5507
- Henry HT, Ellerby DJ, Marsh RL (2005). Performance of guinea fowl Numida meleagris during jumping requires storage and
  release of elastic energy. J. Exp. Biol. 208:3293-3302. doi:10.1242/jeb.01764
- Hill AV (1950). The dimensions of animals and their muscular dynamics. Sci. Prog. 38:209-230 (citado, como en la
  unidad 4d: el salto no depende del tamaño).
- Hutchinson JR, Rankin JW, Rubenson J, Rosenbluth KH, Siston RA, Delp SL (2015). Musculoskeletal modelling of an ostrich
  (Struthio camelus) pelvic limb. PeerJ 3:e1001. doi:10.7717/peerj.1001
- ISO 6508-2. Rockwell hardness test, part 2 (cono de diamante de 120° y radio de 0,2 mm).
- Johnson KL (1985). Contact Mechanics. Cambridge University Press.
- Li R, Lockley MG, Makovicky PJ, Matsukawa M, Norell MA, Harris JD, Liu M (2008). Behavioral and faunal implications of
  Early Cretaceous deinonychosaur trackways from China. Naturwissenschaften 95:185-191. doi:10.1007/s00114-007-0310-7
- Ling J et al. (2017). Effect of honeybee stinger and its microstructured barbs on insertion and pull force. J. Mech.
  Behav. Biomed. Mater. 68:173-179. doi:10.1016/j.jmbbm.2017.01.040
- Anthony JW, Bideaux RA, Bladh KW, Nichols MC (eds.). Handbook of Mineralogy. Mineralogical Society of America
  (hematites, cuarzo, corindón y diamante).
- Manning PL, Payne D, Pennicott J, Barrett PM, Ennos RA (2006). Dinosaur killer claws or climbing crampons? Biol. Lett.
  2:110-112. doi:10.1098/rsbl.2005.0395
- Manning PL, Margetts L, Johnson MR, Withers PJ, Sellers WI, Falkingham PL, Mummery PM, Barrett PM, Raymont DR (2009).
  Biomechanics of dromaeosaurid dinosaur claws. Anat. Rec. 292:1397-1405. doi:10.1002/ar.20986
- Mason P (1963). Density and structure of alpha-keratin. Nature 197:179-180. doi:10.1038/197179a0
- McKittrick J et al. (2012). The structure, functions, and mechanical properties of keratin. JOM 64:449-468.
  doi:10.1007/s11837-012-0302-8
- METALCOR. Titanio de grado 2 (3.7035), ficha técnica.
- Napoli JG, Ruebenstahl AA, Bhullar B-AS, Turner AH, Norell MA (2021). A new dromaeosaurid (Dinosauria: Coelurosauria)
  from Khulsan, central Mongolia. Am. Mus. Novit. 3982:1-47. doi:10.1206/3982.1
- Nassau K (1981). Cubic zirconia: an update. Gems & Gemology 17:9-19. doi:10.5741/GEMS.17.1.9
- Nassau K, McClure SF, Elen S, Shigley JE (1997). Synthetic moissanite: a new diamond substitute. Gems & Gemology
  33:260-275.
- Norell MA, Makovicky PJ (1999). Important features of the dromaeosaurid skeleton II: information from newly collected
  specimens of Velociraptor mongoliensis. Am. Mus. Novit. 3282:1-45. hdl:2246/3025
- Ostrom JH (1969). Osteology of Deinonychus antirrhopus, an unusual theropod from the Lower Cretaceous of Montana. Bull.
  Peabody Mus. Nat. Hist. 30:1-165.
- Outokumpu (2013). Steel grades, properties and global standards.
- Pattrick JG, Labonte D, Federle W (2018). Scaling of claw sharpness: mechanical constraints reduce attachment
  performance in larger insects. J. Exp. Biol. 221:jeb188391. doi:10.1242/jeb.188391
- Paul GS (1988). Predatory Dinosaurs of the World. Simon & Schuster (citado).
- Paul GS (2016). The Princeton Field Guide to Dinosaurs, 2.ª ed. Princeton University Press (citado: tamaño de
  *Deinonychus*).
- Paul GS (2024). The Princeton Field Guide to Dinosaurs, 3.ª ed. Princeton University Press (citado).
- Pei R et al. (2020). Potential for powered flight neared by most close avialan relatives, but few crossed its
  thresholds. Curr. Biol. 30:4033-4046. doi:10.1016/j.cub.2020.06.105
- Pennycuick CJ, Obrecht HH, Fuller MR (1988). Empirical estimates of body drag of large waterfowl and raptors. J. Exp.
  Biol. 135:253-264.
- Pilkington. Product Guide Technical Data (densidad del vidrio, 158 lb/ft³).
- Roscioli G, Taheri-Mousavi SM, Tasan CC (2020). How hair deforms steel. Science 369:689-694. doi:10.1126/science.aba9490
- Royal Society of Chemistry. Tabla periódica, «Gold» (del CRC Handbook of Chemistry and Physics, 95.ª ed.).
- Sellers WI, Manning PL (2007). Estimating dinosaur maximum running speeds using evolutionary robotics. Proc. R. Soc. B
  274:2711-2716. doi:10.1098/rspb.2007.0846
- Spielberg S (dir.) (1993). Jurassic Park. Universal Pictures (la película: ficción).
- Sustaita D, Hertel F (2010). In vivo bite and grip forces, morphology and prey-killing behavior of North American
  accipiters (Accipitridae) and falcons (Falconidae). J. Exp. Biol. 213:2617-2628. doi:10.1242/jeb.041731
- Tabor D (1951). The Hardness of Metals. Oxford, Clarendon Press.
- Taylor D (2007). The Theory of Critical Distances: A New Perspective in Fracture Mechanics. Elsevier.
- Turner AH, Makovicky PJ, Norell MA (2007). Feather quill knobs in the dinosaur Velociraptor. Science 317:1721.
  doi:10.1126/science.1145076
- Verhoeven JD (2004). Experiments on knife sharpening. Iowa State University.
- Ward AB, Weigl PD, Conroy RM (2002). Functional morphology of raptor hindlimbs: implications for resource partitioning.
  Auk 119:1052-1063.
