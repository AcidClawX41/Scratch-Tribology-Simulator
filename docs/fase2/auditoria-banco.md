# Auditoría del banco de ensayo: paridad con la 1.x y lo nuevo de la 2.0 en la interfaz (unidad 4n)

- **Unidad:** 4n · Banco de ensayo (ingeniero de software del laboratorio). Encargo en
  [`encargos/4n-banco-interfaz.md`](encargos/4n-banco-interfaz.md).
- **Base:** `main` 9572784 (con la 4l), con `main` 47c2dc7 (la 4j: fuentes legibles del coche en marcha) unido antes de
  tocar nada y `main` 064db29 (la 5b, el arreglo del calor de la cetrería y la 4m) unido al final para pasar la batería
  sobre lo integrado.
- **Fecha:** 03-10-2026.
- **Cómo se ha hecho:**
  - lectura control a control de la 1.x de escritorio (`apps/desktop/src/App.jsx`, `cards/*.jsx`, `components/*`,
    `packages/core/src/lab.js` y `labState.js`) y de la móvil (`apps/mobile/src/cards/*`, `components/ui.js`) frente al banco
    de Godot (`godot/app/lab/` y `core/lab/lab_state.gd`);
  - una sonda con `LabState` y el modelo 2.0 sobre 29 ensayos representativos (uñas, garras, colmillos, aguijones, los dos
    velocirraptores, el casuario, los vidrios, las zonas del cuerpo y el afilado), que imprime lo que pinta la tarjeta del
    resultado (`ResultCard.metric_rows`), el informe de daños, la comparativa y, al final, «Fuentes y estimaciones»;
  - el vigilante de los textos visibles del banco (`tests/lab/test_banco_textos.gd`: más de 2400 ensayos y 50 000 textos);
  - capturas de `demo_lab` antes y después, en escritorio (1240 × 880) y en el teléfono (390 × 844) (§8).

## 1. Paridad 1.x ↔ 2.0, control a control

Leyenda del estado: **igual** (lo hace igual o mejor), **más** (la 2.0 añade algo), **distinto** (lo hace de otra manera o
peor), **arreglado** (era distinto y lo arregla esta unidad) y **pedido** (el arreglo está en un archivo de otra unidad: se
deja hecho lo que hay que llamar y se pide el cambio, §4).

| Elemento | 1.x | 2.0 (banco en Godot) | Estado |
|---|---|---|---|
| Barra superior | Garra de logo, «Scratch Tribology Simulator», «¿Qué raya a qué?», Fundamentos y Sonido | `main.gd`: nombre de la 2.0, selector de sección, titular de cada página («¿Qué raya a qué?»), Fundamentos y Sonido | igual (más) |
| Sonido on/off | Interruptor con un «on»/«off» audible; se recuerda | El mismo, con el «off» antes de silenciar; se recuerda en `ajustes.cfg` | igual |
| Fundamentos | 16 entradas en dos columnas y la nota | Las 16, las 6 de la 2.0 (frágiles, uñas que ceden, recuperación, abolladura y vidrios, afilado y patada del casuario) y la de los aguijones, en una hoja. Faltaban la biología y el velocirraptor; «Impacto» de la 1.x («El casuario es el único que atraviesa la puerta de roble») contradecía «Patada del casuario» de la 2.0; la nota decía «docs/FISICA.md» | pedido: hecho en `Lab.fundamentos()` y `Lab.FUNDAMENTOS_NOTE_V2`; falta que `lab_section.gd` los use (§4.3) |
| Pie | Nota del modelo («… Detalle y fuentes en docs/FISICA.md») y licencia | La misma nota (`lab_section.gd`) y la licencia (`main.gd`): la ruta interna se veía | pedido: `Lab.model_note(model)` (§4.3) |
| Herramienta · tipo | Uñas / Garras y colmillos | Más «Insectos»; en el teléfono, «🐾 Garras» para que quepa | igual (más) |
| Herramienta · garra | Dibujo, título, descripción, 7 datos (material y dureza, punta, curvatura, longitud, peso, fuerza, golpe) | Igual; los aguijones y los velocirraptores con su ficha, sus bandas y su línea de fuentes (la del velocirraptor de cine, ahora en el color de la ficción) | igual (más) |
| Herramienta · uña | De frente y de perfil, título, dureza, punta y uña libre; formas con su área; materiales con su muestra; nota 🧪 | Igual, con ayudas emergentes | igual |
| Incrustación / reforjado | Píldoras con la gema y su Mohs; nota de la garra o el colmillo reforjados | Igual | igual |
| Queratina | Seca / húmeda con su nota (gota al mojarla) | Igual | igual |
| Afilado | — | Deslizador con marcas, dos barras y nota (2.0) | más |
| Material | Fichas con su textura y subtítulo | Igual, más la ventanilla templada, el parabrisas laminado y la cutícula; con la piel, la zona del cuerpo y su ficha | igual (más) |
| Fuerza | Deslizador logarítmico, marcas y botón de fuerza MÁX. con su nota | Igual; en mN con los aguijones, con sus marcas de perforar y pandear | igual (más) |
| Método, golpe, longitud, pasadas, tipo, modo de garra | Selectores y deslizadores con sus notas | Igual; la nota del golpe dice además de dónde salen la velocidad y la masa | igual (más) |
| Ángulo de ataque | — | Deslizador con su nota (2.0); la nota decía «estimación» sin más | más; arreglado: cita el caso medido más parecido (Holz y Baudisch 2010) o la pregunta abierta, y los modelos del régimen (Hokkirigawa y Kato 1988; Challen y Oxley 1979; Sedriks y Mulhearn 1963) |
| ARAÑAR y atajo | Botón con el atajo Ctrl/⌘ + Intro | Igual (en Tauri además se bloqueaban F5, Ctrl+R y Ctrl+P, que no aplican) | igual |
| Banco animado | Losa, herramienta y marca; rayado y punción | Igual, más todo lo de la 2.0 (§2 y §5) | igual (más) |
| Resultado | Veredicto con DESGARRO y HÚMEDA, barras de dureza, ~20 métricas, corte (piel, coche, puerta o perfil), tabla de la piel, ficha del material y nota de la adhesión | Igual, con las filas de la 2.0 y los cortes por zona y del aguijón. Con una punta afilada la presión nominal y χ daban cifras sin sentido; con una uña que punza la piel sin perforarla el corte salía en blanco por un error de ejecución | igual (más); arreglado (§3 y §6) |
| Métricas en el teléfono | La 1.x móvil las pone de dos en dos (`width: 48.5%`) | Una por fila a 390 px (la rejilla pide 158 px por columna, como la de escritorio): el doble de largo | arreglado: dos columnas por debajo de dos de 158 px |
| Fricción Coulomb | «0.50 · 15 N» con un espacio duro antes de la unidad | Igual, con su espacio duro (en la sonda parecía un espacio normal: se ha comprobado en el código) | igual |
| Modo dual | Dos coches, sus bancos, veredicto, informe de daños y la tabla de las cuatro maneras de atacar | Igual; con poco ancho, apilado | igual |
| Comparativa | Filas por presión nominal: «… MPa nom.»; en serie | Igual, en hilos. Con puntas afiladas daba «230 125 MPa nom.» o «60 160 941 MPa nom.», presiones que no existen; y la tarea de los hilos retenía el estado del banco, que podía morir en un hilo de trabajo y cerrar el programa (signal 11) | arreglado (§3 y §6.1) |
| Logros | 15 | Los mismos 15, recordados entre sesiones, con «Reiniciar» y la vibración del teléfono | igual (más); los de lo nuevo de la 2.0 siguen pendientes (§2.2, §7) |
| Cuaderno | Las 6 últimas, herramienta → material y veredicto | Igual, con la zona del cuerpo («Piel humana · Palma») y recordado | igual (más) |
| Sonidos | 22 efectos (rayados, piel, punciones, vidrio, punta rota, clic, gota, on/off, fanfarria) | Los 22, más los de la 2.0: zumbido de cada insecto, picotazo, desgarro y pandeo del aguijón, la uña que se dobla, el hueso y los vidrios de coche | igual (más) |
| Textos | Los del motor | Idénticos a la 1.x (los compara el oráculo) y los de la 2.0 | igual |

**Lo que la 2.0 había perdido o hacía peor:** nada de lo que hacía la 1.x falta. Lo que estaba mal, y cómo queda:

1. el programa se cerraba de vez en cuando (signal 11) en un hilo de la comparativa: arreglado de raíz (§6.1);
2. el corte de la piel en blanco (y un error de ejecución) con una punción que no perfora: arreglado (`ArtZones.layer_id`);
3. la presión nominal y χ sin sentido con las puntas afiladas: arreglado (§3);
4. las métricas de una en una en el teléfono, cuando la 1.x móvil las pone de dos en dos: arreglado;
5. la contradicción de los fundamentos («Impacto» frente a «Patada del casuario»), las entradas que faltaban y las dos
   rutas internas a la vista (`docs/FISICA.md` en la nota de los fundamentos y en el pie): están en `lab_section.gd`, que
   toca la 5b; los textos y las funciones están hechos y probados en `lab.gd`, y se pide el cambio (§4.3).

## 2. Lo nuevo de la 2.0 en la interfaz, campo a campo

`Physics.V2_FIELDS`: `fracture`, `nail`, `recovery`, `residualDepthUm`, `dent`, `glazing`, `tipChip`, `zone`, `pen`, `tipHv`,
`DpEff`, `faceDeg`, `attackDeg` y `sharpness`; además, `result.sting` de los aguijones.

| Campo | Qué enseña la tarjeta (texto) | Dibujo | Animación | Fuente legible antes | Tras la 4n |
|---|---|---|---|---|---|
| `zone` | «Zona: Palma (eminencia tenar)»; selector de zona con su ficha; tabla de la piel con las capas de la zona y su hueso | Corte de la piel por zona (`art_zones.gd`) | — | No | Cada capa de la zona con su espesor, su calidad y su cita en «Fuentes y estimaciones» (Egawa 2007, Robertson 2010, Meng 2022…) |
| `pen` · hueso | «Hueso: Húmero a 41.4 mm: topa con él / entra ≈ 15 µm / atraviesa la cortical» | Lupa del hueso o de la cavidad, a escala | La punta entra, topa, marca, atraviesa o se rompe (`bench_biology.gd`) | No | El hueso de la zona (profundidad, cortical, dureza) con su cita (De Greef 2006…) |
| `pen` · frenos | «Frenan la punta [grieta + roce] ≈ 0.2 N + 0.9 N» | — | En la lupa del hueso | No | «Punción por capas» (Shergold y Fleck 2005; Fregonese y Bacca 2022), con el roce como estimación |
| `attackDeg`, `faceDeg` | «Ángulo de ataque [θ = ataque − α] 45° · cara a 5°»; deslizador con su nota | La herramienta inclinada; lupa del ataque si no es el de la herramienta | Se inclina en 220 ms al empezar | «estimación», sin cita | La nota del deslizador y las fuentes citan el caso medido más parecido (Holz y Baudisch 2010) o el modelo (Hokkirigawa y Kato 1988; Challen y Oxley 1979) |
| `DpEff` | No se enseña: decide el modo de abrasión, que sí se ve (la 1.x tampoco enseñaba Dp) | — | — | — | Sin cambio |
| `tipHv` | «Punta de esmalte [H(a)] ≈ 94.6 HV en el contacto (dentina 50.0 HV)» | Lupa del esmalte | Quieta | No | «Esmalte de la punta» (Enax 2013; Estrada 2026) |
| `recovery`, `residualDepthUm` | «Queda al levantar la punta [Oliver-Pharr]»; subtítulo; informe de daños | Lupa de la huella | La huella sube al levantar la punta | «Oliver-Pharr», sin año | «Huella al levantar la punta» (Oliver y Pharr 1992; Stilwell y Tabor 1961), calidad «modelo» |
| `dent` | «Abolladura [Jones · Nippon Steel]»; informe de daños; etapa de daño 2 | Hoyuelo al punzar, artesa al rayar | Se hunde al golpear | Nombres, sin año | «Abolladura de la chapa» (Jones 1989; Nippon Steel 2013; US 7 158 922 B2), calidad «modelo» |
| `glazing` | «Estalla por una grieta con», «Trozos al estallar», «Atravesarlo»; veredictos | Panal de la ventanilla, estrella del parabrisas, aspecto de vidrio | Destello, trozos que caen | No | La ficha del vidrio (EN 12150-1, CEPE R43, Nielsen 2022…) y su fractura |
| `nail` | «La uña cede a [σ·Z/L] ≈ 14 N (se dobla)» | La uña de perfil partida en el borde libre | Se dobla o se parte y cae | No | «Uña: cede por flexión» (Baraldi 2015, Farran 2009… o la estimación de cada material) |
| `fracture` | «Grietas [Hertz · Lawn-Evans]: herraduras desde ≈ 0.8 N / astillado ≈ 97 µm…» | Cono, herraduras, astillado y radiales; lupas | Crecen con la carga | No | «Fractura · <material>» con su K_c y su cita |
| `tipChip` | «La punta se mella con [de lado] ≈ 13 N (lleva ≈ 130 N)» | Esquirla | Cae | No | «Resistencia de la punta de …» con su cita |
| `sharpness` | Deslizador «Afilado» con marcas y dos barras; fila «Punta afilada [carga ∝ R²]»; la comparativa da el radio | La herramienta del banco no cambia | — | La nota del deslizador cita a Pattrick et al. 2018 | **Lupa del afilado** (§5); «Afilado de la punta» (Pattrick 2018; Johnson 1985) y «Resistencia de la garra de …» con la cita de su material en las fuentes |
| `sting` (aguijones) | Ficha con masa en mg, púas, Schmidt, aleteo y fuentes cortas; marcas de perforar y pandear; ~14 métricas en mN; moraleja | Insecto, aguijón, aparato y saco; corte de la piel con el aguijón | Llega volando, pica con el giro, se desgarra, el saco bombea; zumbido | Sí (fuentes cortas y la cita entera en la ayuda) | La especie y su calidad también en las fuentes del ensayo |
| Velocirraptor (reconstrucción) | Ficha con «reconstrucción», bandas de la masa y la garra, la punta sin medir, el agarre de un pie y el golpe; fuerza máxima con la garra sola y la réplica | Garra falciforme con el hueso fósil y el estuche, a escala; colgando en el banco | — | Sí (línea de fuentes) | Además, en las fuentes del ensayo: masa, agarre, punta y salto, cada uno con su banda y su calidad |
| Velocirraptor de cine | Ficha «ficción (película)» con la línea de fuentes | Su garra | — | Sí en la ficha, **pero el resultado no decía que era ficción**: «RAJA LA CHAPA» se leía como un dato | Etiqueta FICCIÓN en el veredicto y la nota con lo que haría la garra de verdad; «Garra de película» con calidad «ficción» en las fuentes; la línea de la ficha, en el color de la ficción |
| Patada del casuario | «golpe ~88 J» en la ficha y la nota del golpe (4.84 m/s, 7.55 kg); los fundamentos | La garra del casuario | — | No | «Patada» (Henry 2005; Hutchinson 2015) y «Masa» (la hembra de 58 kg del coche en marcha) en las fuentes; la nota del golpe dice de dónde salen la velocidad y la masa |
| Rapaces corregidas (`ClawsV2`) | La fuerza de la 2.0 en la ficha y en el botón de fuerza máxima | — | — | Solo en la descripción | «Agarre de un pie» con su banda y su cita (Sustaita y Hertel 2010) |

### 2.1 Las fuentes, con nombre legible

Antes de esta unidad la tarjeta del resultado no enseñaba ninguna fuente de la 2.0: solo nombres de método en el símbolo
de algunas métricas («Oliver-Pharr», «Jones · Nippon Steel», «Hertz · Lawn-Evans»), sin año. Las fichas de los aguijones y
de los velocirraptores sí traían su línea de fuentes. Ahora la tarjeta lleva «Fuentes y estimaciones de este ensayo»,
plegada y con su resumen («8 datos · 1 medido · 4 de casos parecidos · 3 estimaciones»), como la del coche en marcha, con
cada dato de la 2.0 que ha usado el ensayo: su valor, su calidad (del color de la calidad) y su cita
(`LabState.trial_sources()` → `BenchTexts.sources`). La calidad es la de los datos (medido, caso parecido, estimación,
ficción) y, para lo que no es un dato sino un modelo publicado (la abolladura, la recuperación, el afilado, el ángulo del
deslizador), «modelo».

En el teléfono las citas enteras de una docena de datos son un muro de texto. Se probó a abreviarlas con el primer autor y
el año (`StingLab.short_sources`, que va bien con las listas de artículos de los aguijones), pero muchas fuentes de la 2.0
son frases con números y decimales con coma («Agarre de un pie de 99,8 kg escalado desde…») y la abreviatura las partía
(«Agarre de un pie de 99 · ×2 2010»). Así que la lista enseña de entrada cada dato con su valor y su calidad, sin la cita;
«Citas completas» las despliega todas, y en escritorio la cita entera sale también en la ayuda emergente de cada dato.

Algunas fuentes de los motores nombraban código o documentos internos; se reescribe **solo el texto** (encargo del
coordinador): la patada y la masa del casuario (`claws_v2.gd`: «MovingCar.BODIES», «docs/…§10.3», «MovingCar.kick_leap_ms»),
Tabor y Hertz en el afilado (`claw_sharpness.gd`: «Contact.CONTACT…»; y «§2» de Verhoeven, que pasa a «apartado 2»), las
densidades del tungsteno y del vidrio (`claw_mass.gd`: «claw_fracture.gd»), los vidrios de coche (`glazing.gd`:
«fracture.gd») y el ángulo de ataque por defecto (`attack.gd`: «docs/fisica/pulido-materiales.md §2.1»). El golden 2.0 se
regenera y solo cambia el texto de la fuente de la fractura en tres escenarios de los vidrios (54, 55 y 56). El vigilante
(`test_banco_textos.gd`) recorre los textos del banco y falla si aparece `docs/`, `.gd`, `§`, `res://`, un nombre de clase
o una unidad del equipo.

### 2.2 Logros de lo nuevo

La 1.x tiene un logro por cada cosa nueva que enseña; la 2.0 no tiene ninguno de lo suyo. Pendientes desde la 4a y la 4b
(`pulido-materiales.md` §7.7 y `pulido-biologia.md` §9.7): «🔨 Martillo de emergencia», «💅 Uña rota», «🦴 Hasta el
hueso», «🩸 Herida penetrante», «🧤 Callo de serie» y «📐 De gancho». No se han hecho: esos seis emojis no están en el
subconjunto de Noto Color Emoji del programa (hay que rehacerlo con fontTools, que no está en la nube) y `Lab.BADGES` lo
compara el oráculo, así que irían aparte (`Lab.BADGES_V2`) con su propio contador (§7).

## 3. La presión nominal

La comparativa ordena y enseña la presión nominal, P = F/A con el área de la punta de la ficha. La presión media real nunca
supera la dureza de quien cede (Tabor), y el motor ya la da: `res.pressure` = min(F/A, H de la punta, H del objetivo). Con
una punta afilada la nominal se dispara y no significa nada:

| Ensayo | Nominal F/A | Real (motor) | χ = P/H |
|---|---|---|---|
| Garra de tigre contra el coche, 260 N | 4333 MPa | 196 MPa (la chapa) | 22,1 |
| Velocirraptor de cine contra el coche, 1841 N (comparativa: colmillo de víbora) | 230 125 MPa | 196 MPa | — |
| Velocirraptor de diamante afilado a media escala contra el acero, 382 N | 21 967 670 MPa | 1961 MPa (el acero) | 11 200 |
| Velocirraptor de acero afilado al máximo contra el acero, 382 N | 75 897 013 488 MPa | 1961 MPa | 38 695 327 |

**Hecho en la interfaz, sin tocar la física:**

- la **comparativa** enseña la presión real del motor, con «(tope)» cuando la limita una dureza («R 1.42 µm · α 17° · 1961
  MPa (tope) · 1.1 mm» en lugar de «… 60 160 941 MPa nom. …»), y una nota al pie: «MPa = presión real del contacto: la
  nominal F/A hasta la dureza de quien cede; por encima no tiene sentido (tope)». El orden sigue siendo el de la 1.x (de la
  nominal mayor a la menor: de la punta más afilada a la más roma);
- en el **resultado**, «Presión real» dice en su símbolo quién pone el tope («tope: dureza del objetivo» o «… de la
  punta»), y «Presión nominal F/A» enseña su valor solo cuando es la real; si pasa de la dureza, «sin sentido: pasa de la
  dureza», en oro, el color con que la 1.x la avisaba;
- **χ** con tres decimales, como en la 1.x, hasta 1000; por encima, «> 1000».

**Lo que se pide al motor:** el pico de Hertz. `Contact.plastic_fraction` ya calcula p0 y el radio del contacto de Hertz, y
`compute()` los tira. En un contacto elástico la presión «real» del motor es la nominal sobre toda el área de la punta: la uña
almendra a 4 N sobre el vidrio da 4,44 MPa, cuando el contacto de Hertz mide ~81 µm de radio, con una presión media de
~196 MPa y un pico de ~294 MPa. Con dos campos derivados en el resultado de la 2.0 (`p0MPa` y `hertzRadiusUm`, null si el
contacto es plástico o en la piel), la tarjeta podría enseñar el pico de Hertz en los contactos elásticos y la presión media
de verdad, sin cambiar ningún veredicto.

## 4. Peticiones

### 4.1 Al motor

- `p0MPa` y `hertzRadiusUm` en el resultado de la 2.0 (§3).

### 4.2 A CONTRATOS.md

- «Laboratorio 2.0»: `core/lab/bench_texts.gd` (`BenchTexts`) escribe los textos del banco que no son de un solo módulo (la
  presión real con su tope, χ, la ficción del velocirraptor de cine, el origen del golpe y «Fuentes y estimaciones» de un
  ensayo); `LabState` gana `trial_sources()`. `Lab` gana `fundamentos()`, `FUNDAMENTOS_BIO_V2`, `FUNDAMENTOS_NOTE_V2` y
  `model_note(model)` (§4.3).
- Regla de las fuentes visibles del banco: sin rutas, archivos ni nombres de clase; lo vigila `tests/lab/test_banco_textos.gd`.
- Regla de los hilos (la del arreglo de §6.1, que sirve para todo el programa): una tarea de `WorkerThreadPool` no retiene
  nada con estado ni conectado a la interfaz (nodos, `LabState`, objetos con señales). WorkerThreadPool suelta cada tarea en
  el hilo que la ha corrido y después de despertar a quien la espera, así que lo que retenga puede destruirse en ese hilo.
  Se le pasa un Callable de método (una referencia débil, un ObjectID) de un objeto que guarda el hilo principal y lo suelta
  después de esperar la tarea; o una lambda que solo capture datos (diccionarios, arrays, textos), como la del coche en
  marcha. Lo vigila `tests/app/test_compare_threads.gd`.

### 4.3 A `lab_section.gd` (la toca la 5b)

- `fundamentos()` → `return Lab.fundamentos()`: los de la 1.x con «Impacto» para las dos físicas (con la 1.x el casuario
  atraviesa la puerta de roble; con la 2.0 se queda a ~31 mm), los de los materiales, la biología de la 2.0 (zonas y hueso,
  punción por capas, ángulo de ataque, esmalte y velocirraptor) y el de los aguijones. `tests/app/test_main.gd` cuenta las
  entradas: pasa a `Lab.fundamentos().size()`.
- `fundamentos_note()` → `return Lab.FUNDAMENTOS_NOTE_V2`: sin la ruta; dice que cada ensayo trae sus fuentes y nombra la
  documentación por su título («Modelo físico y fuentes»).
- `MODEL_NOTE` → `Lab.model_note(lab.model)`, puesto al día al cambiar de física (el de la 1.x es el de App.jsx con la
  documentación por su nombre; el de la 2.0 dice lo que añade y que cada ensayo cita sus fuentes).

## 5. Dibujos y animaciones

Lo que faltaba de dibujo en el banco y cómo queda:

- **Afilado (nuevo):** la lupa del afilado (`ArtBiology`, tipo «afilado», detrás del esmalte y antes del ataque). La punta
  afilada de una garra o un colmillo reforjados metida en su surco, a la escala de la punta natural, con el contorno de la
  punta natural de la ficha a trazos y el mismo vértice: se ve cuánto se ha afilado. Si la carga lateral la mella (flexión)
  o la dobla (fluencia), la punta lo enseña en coral o en oro, y el rótulo lo dice: «500 µm · punta de 2,35 µm (la natural,
  138 µm) · presión ×15,1 · se mella». Es una textura quieta de la caché, como las demás lupas: no se crea nada por
  fotograma.
- **Punción que no perfora (arreglado):** con una uña que punza la piel sin perforarla, el corte de la piel y la lupa leían
  la capa alcanzada de un resultado sin ella (`pen.layerId` nulo) y salían en blanco con un error de ejecución.
  `ArtZones.layer_id(pen)` la lee sin romperse.
- **Ficción:** la etiqueta FICCIÓN y su nota en el veredicto (texto, no dibujo).
- **Lo que sigue sin dibujo:** la herramienta del banco no cambia de forma al afilarla (lo enseña la lupa); `DpEff` no se
  dibuja (decide el modo, que sí se ve).

## 6. Qué se ha arreglado en la 4n

### 6.1 El cierre del programa en un hilo de la comparativa (prioridad del coordinador)

**Síntoma:** signal 11 en un hilo de la comparativa (`compare_card.gd:178`, `state.compute(jobs[k].p, model)` dentro de
`WorkerThreadPool.add_group_task`) con «caller thread can't call propagate_notification() on /root», en dos de cuatro
baterías largas de la 5b.

**Causa raíz:** el aviso no es la causa: es el manejador de fallos de Godot, que avisa al árbol (NOTIFICATION_CRASH) desde
el hilo que se ha caído. La tarea de cada fila era una lambda que capturaba el estado del banco (`LabState`, con su señal
`changed` conectada a la sección y Callables de la interfaz). En Godot 4.7.2 cada tarea de un grupo lleva una copia de ese
Callable y se libera a sí misma en el hilo de trabajo **después** de despertar a quien la espera
(`WorkerThreadPool::_process_task`: `done_semaphore.post()` y luego `task_allocator.free(p_task)`). Si el hilo principal
soltaba entonces sus referencias (se libera la sección, el banco cambia de estado), la última referencia del `LabState` se
iba con la tarea y el estado se destruía en el hilo de trabajo: desconectaba su señal de una sección que el hilo principal
estaba liberando a la vez. Una sonda lo mide: con la CPU cargada, el objeto capturado moría en un hilo de trabajo en 8 de
200 vueltas (39 de 100 con la CPU sobrecargada). Era la única tarea de hilos del programa que retenía un objeto con estado:
la del coche en marcha captura solo datos y la caché de dibujos pasa un Callable de método.

En la nube no se ha reproducido el signal 11 en sí (una batería completa de la 5b pasó limpia y las sondas con la sección
entera en el árbol no se cayeron); lo que se reproduce siempre es la condición que lo provoca. Se descartaron, con una
sonda cada uno: el cálculo en paralelo de `Physics.compute` (6480 a la vez en los hilos y en el principal, además de
`tests/lab/test_threads.gd`), ThorVG rasterizando en varios hilos a la vez, la primera carga de un script con `static var`
(Godot 4.7.2 los inicializa al cargar el script, en el hilo principal) y alguna escritura en los diccionarios compartidos de
los catálogos (no hay ninguna).

**Arreglo:** la tarea es ahora un `RowsJob` (un RefCounted con los parámetros de cada fila, el modelo leído en el hilo
principal y su hueco de salida) que guarda la tarjeta en `_tasks`; WorkerThreadPool recibe `job.run`, un Callable de método,
que es una referencia débil (un ObjectID). El hilo principal suelta la tanda (y con ella el estado) después de esperarla
(`poll`, `finish` o al liberarse la tarjeta, que ya esperaba). Los hilos siguen calculando en paralelo: no se ha quitado
ningún hilo.

**Test:** `tests/app/test_compare_threads.gd` lo reproduce como al arrancar: una comparativa nueva con su estado, sus
primeras filas en hilos y el hilo principal que suelta el estado mientras se calculan, 24 vueltas con la CPU libre y 24
con la CPU sobrecargada. Sin el arreglo, el estado moría en un hilo de trabajo en 23 o 24 de cada 24 vueltas (fallaba
siempre); con él, en ninguna, y siempre al recoger sus filas en el hilo principal.

### 6.2 El resto

- Fuentes de los motores sin nombres de código ni rutas (solo el texto) y golden 2.0 regenerado (§2.1).
- El corte de la piel y la lupa con una punción que no perfora (§5).
- `BenchTexts` y el vigilante de los textos visibles del banco (§2.1).
- Resultado: la presión real con su tope, la nominal solo cuando tiene sentido y χ legible (§3); la etiqueta FICCIÓN y su
  nota; «Fuentes y estimaciones de este ensayo», plegada, con su resumen y «Citas completas».
- Comparativa: la presión real de cada fila con «(tope)» y su nota (§3).
- Parámetros: el ángulo de ataque con sus fuentes legibles; la nota del golpe con el origen de la velocidad y la masa.
- Herramienta: la línea de fuentes del velocirraptor de cine en el color de la ficción.
- Fundamentos de la biología de la 2.0, «Impacto» para las dos físicas y el pie sin rutas, listos en `lab.gd` (§4.3).
- La lupa del afilado (§5).
- En el teléfono, las métricas de dos en dos, como la 1.x móvil.
- Las cotas del dibujo de la garra del velocirraptor de película, con un decimal: salían con quince
  («24.20711974418832 × 9.190938511326862»).
- `demo_lab`: el caso 25 (el velocirraptor de cine contra el coche, con FICCIÓN y sus fuentes) y los casos 24 y 25 que, tras
  el resultado, enseñan la comparativa o las fuentes.

## 7. Lo que queda

- Los logros de lo nuevo de la 2.0 (§2.2): `Lab.BADGES_V2` con su contador y el subconjunto de emojis rehecho.
- `p0MPa` y `hertzRadiusUm` en el motor (§3, §4.1), para enseñar el pico de Hertz en los contactos elásticos.
- Los cambios de `lab_section.gd` (§4.3) y las reglas de CONTRATOS.md (§4.2).
- La herramienta del banco no cambia de forma al afilarla: si se quiere, un perfil afilado de la garra en el banco
  (hoy lo enseña la lupa).

## 8. Capturas

Antes (la rama en 3816948: `main` 47c2dc7 con el caso 25 de la demo y los arreglos de texto de las fuentes, sin ningún
cambio de la interfaz) y después (la rama al final, con `main` 064db29 unido) de `demo_lab`, en escritorio (1240 × 880) y
en el teléfono (`--phone`, 390 × 844), en el directorio de trabajo de la unidad (`scratchpad/4n/antes-<caso>` y
`despues-<caso>`, con `-movil` para el teléfono): los casos 24 (velocirraptor de diamante afilado contra el acero: el afilado, la comparativa con «(tope)»), 25
(velocirraptor de cine: FICCIÓN y las fuentes), 14 (garra de tigre de diamante contra la ventanilla templada: vidrios de
coche), 17 (víbora en el pómulo: zona y hueso), 22 (esmalte del colmillo en el cobre), 7 (aguijón de la abeja) y 23
(velocirraptor, la reconstrucción: su ficha y su golpe en el brazo).

En el teléfono, después: las métricas de dos en dos (casos 24 y 17), «Fuentes y estimaciones» compacta con «Citas
completas» (caso 25) y la comparativa con la presión real y «(tope)» (casos 24 y 25). En escritorio, la lupa del afilado en
el banco (caso 24) y FICCIÓN con su nota y la línea de fuentes en rosa (caso 25); antes, el mismo caso 25 decía «RAJA LA
CHAPA» sin más y la nominal «30683 MPa», y la comparativa «230125 MPa nom.».

## 9. Verificación

- Batería completa de Godot (`node godot/tools/godot.mjs test`) sobre la rama con `main` 064db29 unido: 1209 tests y 0
  fallos, sin `SCRIPT ERROR` ni `Parse Error`.
- `npm test`: 121 de 121.
- `gdlint` sobre todo `godot/`: sin avisos.
- Golden 2.0 regenerado una vez (352d547): solo cambia el texto de la fuente de la fractura en los escenarios 54, 55 y 56.
  El oráculo de la 1.x no cambia (sus 372 dibujos siguen idénticos al bit).
