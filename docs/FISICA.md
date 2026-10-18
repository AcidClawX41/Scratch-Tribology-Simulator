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

## Cambios de la 2.0 (programa en Godot)

El laboratorio de la 2.0 (`godot/core/lab/physics.gd`) tiene dos versiones de la física, que se eligen con
`p.model` en `Physics.compute(p)`:

- **`"1.x"`**: este documento tal cual (modelo v2.4 del motor 1.x), al bit. Lo usan los tests del oráculo.
- **`"2.0"`**: la física de la aplicación: la 1.x más los cambios de esta lista, cada uno en una rama localizada
  (`if c.v2:`) con su fuente y su test.

Sus salidas en los 40 escenarios del golden (y en los escenarios nuevos de la 2.0) están en
`godot/tests/fixtures/lab-golden-v2.json`, que se regenera solo a propósito con `npm run godot:golden`: cada escenario
que cambie respecto a la 1.x se explica aquí.

| Cambio | Qué ensayos cambia y en qué sentido | Fuente | Test |
|---|---|---|---|
| Aguijones de insectos (grupo «Insectos», 8 especies) y la cutícula de insecto como material (apartado 16) | Solo ensayos nuevos: con un aguijón, `compute()` va a `core/lab/sting_lab.gd` (perforación por fractura, pandeo, lancetas, púas, autotomía, veneno). Los 40 escenarios de la 1.x no cambian; el golden 2.0 añade 8 (abeja, avispa y avispón en la piel; abeja natural y de acero en el pino; abeja de diamante contra el vidrio; abeja natural y de acero contra la cutícula) | Shergold & Fleck 2005; Das et al. 2018; Ramirez-Esquivel & Ravi 2023; Bissessarsingh & Starr 2021 y el resto de `docs/fisica/aguijones.md` | `test_spec_aguijones.gd` (24 casos de referencia), `test_sting_lab.gd`, `test_sting.gd` |
| **Materiales · la uña cede** (`bending.gd`; `docs/fisica/pulido-materiales.md`, tema 2): el borde libre es un voladizo en «C» que se dobla (natural, acero, titanio) o se parte (gel, acrílico, zafiro) con F⊥ = σ·Z/L; a la punta solo llega esa carga (en un golpe, como la rotura del colmillo) | Toda uña por encima de su carga de cesión: la profundidad se queda en la de esa carga. Con daño, el veredicto es «SE DOBLA LA UÑA» o «SE PARTE LA UÑA» (el daño hecho se conserva); sin daño, el de siempre con la cesión en el subtítulo. Golden: cambian de veredicto «uña stiletto 30N sobre piel» (882 → 75 µm), «uña cuadrada 30N sobre piel» (18 µm), «uña + diamante 30N sobre zafiro» (4,4 → 2,9 µm), «uña + cuarzo 30N sobre pantalla móvil» (7,2 → 3,6 µm), «uña almendra 30N ×20 sobre piel» (75 µm) y la stiletto de acero golpeando los coches moderno y clásico (perforaba: 6,1 y 5,3 mm → 274 y 304 µm); subtítulo en «uña natural sobre vidrio», «sobre acero 100 pasadas» y «húmeda 30N sobre pintura». Ninguna uña natural perfora la piel ni de un golpe (no aguanta la fuerza de Davis). Una hoja de vidrio que la uña puede partir cede antes que ella: empujando, el ensayo es el de la 1.x («ROMPE EL VIDRIO»); el laminado se agrieta y sigue sujeto, y la uña cede después | Baraldi et al. 2015 (espesor y resistencia); Jung et al. 2015 (curvatura); Boike et al. 2025 (anchura); Farran et al. 2009 y Farren, Shayler & Ennos 2004 (humedad y fractura); ISO 20795-1 y Casucci et al. 2023 (gel y acrílico); DIN EN ISO 18265 y EN 10088-2 (acero), ASTM B265 (titanio); hojas técnicas del zafiro | `test_bending.gd`, `test_materiales_v2.gd`, `test_model.gd`, `test_invariants.gd` |
| **Materiales · fractura de los frágiles** (`fracture.gd`, tema 1): grietas de Hertz de una punta roma y dura (ley de Auerbach; al deslizar, (1 + k·μ)³ veces antes) y astillado de una afilada (umbral de Lawn-Evans, grieta de Anstis) | Una punta roma más dura que el frágil y que siga elástica: «GRIETAS DE HERTZ» al rayar o «CONO DE HERTZ» al apretar, sin surco (la cuadrada de zafiro agrieta el vidrio desde 0,8 N sin rayarlo). Con surco, el veredicto de siempre con el subtítulo del astillado. Ningún escenario del golden 1.x cambia: ninguno tiene una punta roma y dura sobre un frágil | Rhee et al. 2001; Ren & Zhang 2014; Hamilton & Goodman 1966; Lawn & Evans 1977; Mikowski et al. 2006; Anstis et al. 1981; Lawn, Evans & Marshall 1980; Corning 2012; Iwasa et al. 1981; Salem 2006; Field & Freeman 1981 | `test_fracture.gd`, `test_materiales_v2.gd` |
| **Materiales · recuperación elástica** (`recovery.gd`, tema 3): la profundidad del ensayo es bajo carga; al levantar la punta el material devuelve m·π·a·H/(2E') | Los no frágiles (salvo piel, madera y lo perforado) se clasifican con la huella residual (`residualDepthUm`): el barniz y el ABS recuperan mucho y una punta roma se queda en marca pulible. Golden: «uña almendra 4N sobre pintura» pasa de «ARAÑAZO EN BARNIZ» a «ROZA / REMOLINO» (3,5 µm bajo carga, 0 residual); subtítulo en «uña almendra 20 pasadas» (queda 3,1 µm) y en «oso de diamante 300N» (surco residual de 275 µm en la chapa en vez de 279) | Oliver & Pharr 1992; Stilwell & Tabor 1961 | `test_recovery.gd`, `test_materiales_v2.gd` |
| **Materiales · abolladura de la chapa** (`dent.gd`, tema 5): colapso rígido-plástico π·C·σ·t²/2 y membrana; en un golpe, la energía que no se queda la punta se reparte entre la chapa y la pata | Al punzar o golpear una chapa metálica sin perforarla, con abolladura visible (≥ 0,1 mm), «ABOLLA LA CHAPA» o «ABOLLA LA PUERTA»; rayando, el veredicto de la pintura y la abolladura en el subtítulo; etapa de daño 2 en el modo dual. Golden: subtítulo en «oso 300N sobre pintura» (0,32 mm), «oso 300N desgarro» (0,81), «casuario 500N» (0,77), «avestruz 900N» (1,7) y «oso de diamante 300N» (0,32) | Jones 1989; Hopkins & Prager 1953; Nippon Steel 2013 (calibración); criterio de 0,1 mm de la industria (US 7 158 922 B2) | `test_dent.gd`, `test_materiales_v2.gd` |
| **Materiales · vidrios de coche** (`glazing.gd`, tema 6): la ventanilla templada y el parabrisas laminado como materiales nuevos del catálogo | Solo ensayos nuevos. La templada «ESTALLA LA VENTANILLA» en trocitos romos si la flexión llega a 120 MPa o si una punta dura abre una grieta que atraviesa su capa comprimida (el martillo de emergencia); el laminado «SE AGRIETA (NO CAE)» y, con más de los 88,7 J de la homologación, «podría atravesarlo». El golden 2.0 añade el oso contra los dos y el tigre de diamante contra la ventanilla | Nielsen, Schneider & Kraus 2022; EN 12150-1; CEPE R43 y JIS R 3212; Achintha 2020 (compresión medida); Galić et al. 2022 (acoplamiento del PVB); Pilkington (construcción 2,1/0,76/2,1) | `test_glazing.gd`, `test_materiales_v2.gd` |
| **Materiales · mellado de las garras frágiles** (`fracture.gd`, tema 4, informativo): la punta de zafiro o de cuarzo como voladizo frente a la fricción al arrastrar | Solo una línea en el subtítulo (`tipChip`): la profundidad y el veredicto no cambian. Ningún escenario del golden 1.x cambia (el águila de zafiro golpea de frente: sin fuerza lateral) | Hojas técnicas del zafiro (760 MPa); sílice fundida como cota baja del cuarzo | `test_fracture.gd`, `test_materiales_v2.gd` |
| **Biología · zonas del cuerpo** (`zones.gd`; `docs/fisica/pulido-biologia.md` §2 y §4): con la piel, las capas de cinco zonas (el brazo de la 1.x por defecto, la palma, el dorso de la mano, el pómulo y el abdomen) con el hueso o la cavidad abdominal de debajo; la fuerza para perforar (`Sting.puncture_force`, la de la 1.x con uñas, garras y colmillos), la severidad y los umbrales de la abrasión, los de cada zona | Solo con otra zona (parámetro `zone`; el selector de la tarjeta del material): en la palma el callo (173 µm) se pule sin sangrar («CALLO PULIDO»); en el dorso de la mano la epidermis (86 µm) pide más pasadas para sangrar; una herida igual acaba en otra capa y con otra severidad; un aguijón deja el veneno en otra capa (la abeja, en la grasa de la palma). En el brazo, los rayados de la 1.x no cambian: ninguno de los 40 escenarios del golden cambia por la zona. El golden 2.0 añade el pájaro en la palma, el tigre en el dorso de la mano, la víbora en el pómulo y en el dorso de la mano, el Gabón en el abdomen y la abeja en la palma | Sandby-Møller et al. 2003; Egawa et al. 2007; Robertson & Rees 2010; Baumann et al. 2024; Lee & Hwang 2002; Gibney et al. 2010; Homer et al. 2025; Çetiner Şeker & Bayrak 2026; Hung et al. 2022; Wang et al. 2022; Meng et al. 2022; De Greef et al. 2006; Lee & Kim 2025; Kim et al. 2012; Stecco et al. 2009 | `test_zones.gd`, `test_biologia_v2.gd`, `test_pulido_biologia.gd` |
| **Biología · punción por capas y hueso** (`penetration.gd`, §3): la grieta que la punta abre en todas las capas que atraviesa, el roce en sus flancos (ξ = 0,05) y el hueso: la punta lo marca si es 1,25 veces más dura (el esmalte de un colmillo, una garra reforjada), topa con él si no (la queratina) y puede atravesar la cortical hasta la médula; un colmillo que golpea el hueso se rompe (30 N) y una uña que golpea cede con su carga de flexión; al rayar, el corte se para en el hueso | Punciones de la piel: nunca más hondo que en la 1.x, porque la grieta y el roce solo frenan (el gato que empuja 3,2 N se queda en la grasa, a 3,4 mm, en vez de meter sus 10 mm). Veredictos nuevos: «PUNCIÓN HASTA EL HUESO», «SE CLAVA EN EL HUESO», «ATRAVIESA EL HUESO», «SE ROMPE EL COLMILLO», «HERIDA PENETRANTE» y, al rayar, «LACERACIÓN/DESGARRO HASTA EL HUESO». La punción de la piel da `workJ` y `toolBroken`. Golden: «gabón 30N impacto sobre piel» (50 mm en el músculo → el colmillo se rompe contra el húmero a 41,4 mm; suena «snap» y el logro del colmillo roto llega en ese escenario); «casuario 500N impacto sobre piel» (110 mm → topa con el húmero a 41,4 mm sin marcarlo: queratina de 32 HV frente a 47,25); «víbora 4N sobre piel (punción)» y «pájaro 1.5N punción sobre piel» solo ganan `workJ` y `toolBroken` (18 mm y sin perforar, como en la 1.x) | Shergold & Fleck 2005; Fregonese & Bacca 2022; Shergold et al. 2006; Li et al. 2021; Tingart et al. 2003; Reilly & Burstein 1975; Koester et al. 2008; Richardson 1968; Estrada et al. 2026 | `test_penetration.gd`, `test_biologia_v2.gd`, `test_model.gd` |
| **Biología · ángulo de ataque** (`attack.gd`, §5): un solo ángulo por ensayo, el de `Physics.attack_deg` (el del usuario, 10-170°, o el de su tipo: 45° las uñas, estimación; 90° garras y colmillos, la 1.x). Gira la cara que avanza (θ = ataque − α) y con el Dp efectivo decide arado, cuña o corte, la fracción arrancada, la fricción de arado y el desgaste; el mismo ángulo flexa la uña (de gancho, con el valor absoluto de cos β + μ·sen β) | La profundidad del surco no cambia. Las uñas que rayan un sólido lo hacen a 45° (el ángulo con que la 4a ya las flexaba): si el surco pasa del casquete esférico al cono, la cara que avanza se tumba y el modo baja hacia el arado; garras y colmillos van de punta, como en la 1.x. Golden: ninguno de los 40 escenarios cambia por el ángulo (en sus uñas el surco se queda en el casquete esférico, que no gira); el golden 2.0 añade la stiletto tumbada a 20° (ara en vez de cortar), la cuadrada de gancho a 150° (aguanta los 30 N y corta: de gancho se dobla menos que a 45°) y la garra de gato a 20° sobre el ABS (cuña en vez de corte) | Hokkirigawa & Kato 1988; Challen & Oxley 1979; Sedriks & Mulhearn 1963; Holz & Baudisch 2010 (el 45° de las uñas, estimación) | `test_attack.gd`, `test_biologia_v2.gd`, `test_materiales_v2.gd` |
| **Biología · esmalte de los colmillos** (`fang_enamel.gd`, §6): la punta de un colmillo natural es un casquete de esmalte (321,2 HV, el del cocodrilo; 10 µm, estimación) sobre la dentina, H(a) = H_dentina + (H_esmalte − H_dentina)·e^(−a/t); en los sólidos, la resistencia con la dureza de la punta en cada contacto y, con el contacto final, `tipHv`, `ratio`, `eta`, `toolWorn` y la presión | Solo colmillos sin incrustación contra sólidos: cuanto más pequeño el contacto, más dura la punta, y rayan lo que la dentina no podía. Golden: «víbora 40N punción sobre vidrio (rompe)» (presión 490 → 3150 MPa, la del esmalte; área de contacto 0,082 → 0,013 mm² y desgaste 320 → 50 u.a.; el veredicto no cambia) y «víbora 4N sobre puerta madera (punción)» (`ratio` en la séptima cifra: el contacto final, de 160 µm de radio, ya es de dentina). El golden 2.0 añade el colmillo de víbora rayando el cobre: de «NO RAYA» a «MARCA TENUE» de 3,3 µm | Estrada et al. 2026; Enax et al. 2013; Dumont et al. 2023 | `test_fang_enamel.gd`, `test_biologia_v2.gd`, `test_invariants.gd` |
| **Uña con gema mojada** (unidad 4b): la gema no se ablanda (la dureza y el módulo del contacto siguen siendo los suyos, como en la 1.x), pero la placa de queratina que la lleva sí: se dobla con la resistencia de la queratina mojada (×0,2) | Solo uñas naturales con incrustación y mojadas: ceden con la quinta parte de la carga (la almendra con diamante sobre el vidrio, a ~3,4 N en vez de ~17). Ningún escenario de la 1.x cambia; el golden 2.0 añade la uña con diamante mojada a 10 N sobre el vidrio (en seco raya; mojada, «SE DOBLA LA UÑA») | Farran et al. 2009; Bonser, en McKittrick et al. 2012 | `test_biologia_v2.gd` |
| **Garras de la 2.0 en el catálogo** (`claws_v2.gd`, unidad 1k, aplicado en `catalog.gd` en la 4b): el agarre de las rapaces escalado de Sustaita & Hertel (2010) (águila 100,9 N, 65-299; arpía 178,5, 104-529; halcón 15,8, 12-47) con sus fichas y `sources2`, y la ficha del casuario (corre a unos 50 km/h; su patada es un salto a unos 17 km/h, la del coche en marcha) | La fuerza que propone el botón de fuerza máxima con esas rapaces y los textos de sus fichas. `compute()` usa la fuerza del deslizador y el golpe (v, m) de la 1.x, así que por estas fichas ningún escenario del golden cambia (el golpe del casuario sí cambia desde la unidad 4i: fila «Patada del casuario en el banco») | Sustaita & Hertel 2010; Ward et al. 2002; Alerstam 1987; Tucker et al. 1998; Healy 2022; Henry et al. 2005; Hutchinson et al. 2015 | `test_claws_v2.gd`, `test_catalog.gd` |
| **Sonidos del hueso** (unidad 4f; `sfx_insects.gd` → `bone_sfx`; `docs/fisica/pulido-biologia.md` §9.11): cuando la punta llega al hueso suena como en un sólido. Si lo atraviesa o se clava, «pierce-solid»; si topa sin marcarlo, «press». Son sonidos que ya estaban horneados | Solo el efecto de sonido de 3 escenarios del golden 2.0: «casuario 500N impacto sobre piel», pierce → press (la daga topa con el húmero sin marcarlo); «Víbora punzando el pómulo», inject → pierce-solid (se clava en el hueso cigomático); «Casuario de tungsteno… atraviesa el húmero», pierce → pierce-solid. Ni un número cambia | Los resultados de `penetration.gd` (§3) que ya usa el golden | `test_sfx_insects.gd`, `test_golden_v2.gd` |
| **Velocirraptor (reconstrucción) en el catálogo** (`velociraptor.gd`, unidad 4e; en `catalog.gd`, unidad 4i; `docs/fisica/velociraptor.md`): grupo «Dinosaurios (reconstrucción)», solo en el modelo 2.0 (`Catalog.V2_CLAWS`). La ficha dice «reconstrucción» y da la banda de la masa (19,7 kg, 14,1-24,6), la garra (hueso fósil de 64,8 mm y estuche de 92,7 mm, 76,2-95,7) y la punta como pregunta abierta (la de la arpía: 138 µm y 15°). Fuerza máxima: el agarre de un pie, 381,5 N (193-1130); en la nota, la garra sola (~10 N) y la réplica (483 N). Golpe de la ficha: cae con los dos pies a la velocidad del salto, 4,84 m/s, con la mitad de la masa por pie (9,85 kg): 115 J | Solo ensayos nuevos: el catálogo de la 1.x y el oráculo no cambian (hay un test), ni ninguno de los 40 escenarios. El golden 2.0 añade el golpe en el brazo (topa con el húmero a 41,4 mm sin marcarlo: queratina de 32 HV frente a 47,25), el coche moderno rayado con el agarre de un pie («HASTA EL METAL», 110 µm: la queratina no corta el acero, r = 0,32) y la garra de diamante afilada (fila siguiente). Con su golpe y su fuerza de ficha no atraviesa la puerta de roble (31,2 de 35 mm) | Norell & Makovicky 1999; Campione et al. 2014; Campione & Evans 2012 y 2020; Hedrick et al. 2019; Manning et al. 2006; Fowler et al. 2011; Sustaita & Hertel 2010; Bishop 2019; Henry et al. 2005; Hutchinson et al. 2015; McKittrick et al. 2012 | `test_velociraptor.gd`, `test_velociraptor_banco.gd`, `test_velociraptor_spec.gd` (22 casos), `test_catalog.gd` |
| **Afilado de las garras reforjadas** (`claw_sharpness.gd`, unidad 4e; en `physics.gd`, unidad 4i; velociraptor.md §3): parámetro `sharpness` (0-1) de una garra o un colmillo con incrustación (no los aguijones: su punta está medida). R(s) = R0·(0,04 µm/R0)^s, en escala logarítmica de la punta de la ficha al filo más fino medido; `resolve_tool` usa el área y el radio afilados. El resultado lleva `sharpness` (null en la 1.x y sin incrustación): la presión de pico, la hondura y la carga lateral que aguanta la punta (la viga en voladizo, F = σ·(27π/16)·R²·sen α·(1 − sen α)²/cos³α) frente a la natural, con la resistencia del material (`ClawFracture`, unidad 4d) y μ·F de lado al rayar (0 al punzar) | Con s = 0 el ensayo es el de siempre, al bit (tests contra el golden 2.0 y en una rejilla). Afilada: más hondura con la misma fuerza (nunca menos; test) y menos carga lateral (una punta frágil más afilada nunca aguanta más; test). Golden: los 74 escenarios ganan la clave `sharpness`; lleva valor en los 8 con garra reforjada (con s = 0: la punta natural, informativo; el talón de águila de zafiro arrastrado sobre el coche se mella: le llegan 55 N de lado y aguanta 8,1) y en el nuevo «velocirraptor de diamante afilado a media escala rayando el acero»: R 2,35 µm, surco de 1,31 mm (0,92 con la punta natural), presión de pico ×15,1 y se mella (aguanta 12,9 mN; le llegan 190,75 N) | Roscioli et al. 2020; Verhoeven 2004; Ling et al. 2017; Davis et al. 2004; ISO 6508-2; Johnson 1985; Tabor 1951; Pattrick et al. 2018; Taylor 2007; las resistencias de `claw_fracture.gd` (unidad 4d) | `test_claw_sharpness.gd`, `test_afilado_banco.gd`, `test_afilado_ui.gd` |
| **Patada del casuario en el banco** (`claws_v2.gd`, unidad 4i: `ClawsV2.kick_strike`, con las funciones de `moving_car.gd`, unidad 4d): en la 2.0 el golpe de la ficha del casuario sale de la patada del coche en marcha, sin copiar sus números: v = √(4·w·f) = 4,84 m/s (el salto: w = 45 J por kg de músculo, f = 8,498/65,3 de la masa en los músculos de una pata) y m = f·M = 7,81 kg (los músculos de la pata que patea, con los 60 kg de la ficha): ½·m·v² = 91,45 J. Banda alta: todo el trabajo de esa pata, w·f·M = 351,4 J (m = M/2, el pie con la mitad del impulso del salto, como el velocirraptor). El coche golpea con el animal entero y un tope de fuerza en la pata (5,1 pesos; coche-en-marcha.md §10.3); el banco no tiene ese tope, y por eso su masa eficaz es la de la pata | Solo el casuario con golpe y en el modelo 2.0 (la 1.x sigue con 8 m/s y 5 kg: 160 J). Golden: «casuario 500N impacto sobre piel» (topa con el húmero a 41,4 mm igual, pero le sobran 112 J en vez de 180); «casuario 500N impacto puerta madera» (de «ATRAVIESA LA PUERTA», 36,6 mm, a «CLAVADA EN LA MADERA», 30,8 de 35 mm; suena «pierce-solid» en vez de «breakthrough»); «Casuario de tungsteno, golpe en el brazo» (atraviesa la cortical del húmero igual, pero acaba a 60,6 mm en vez de 65,1). Como ese ensayo ya no atraviesa la puerta, el logro «¡Aquí está Johnny!» no llega en el golden y sale de `badgesAfter` de ahí en adelante. Sigue al alcance: con el deslizador a 2000 N la daga del casuario (35,5 mm) o la del velocirraptor (35,4) atraviesan la puerta. Desde la unidad 4i-B2 el casuario pesa 58 kg (fila «Coherencia banco ↔ coche»): 88,41 J (banda alta 339,7 J) y las cifras de esta fila se mueven un poco | Henry et al. 2005; Hutchinson et al. 2015 (tabla 2); el salto de `MovingCar.kick_leap_ms` (unidad 4d; `docs/fisica/coche-en-marcha.md`) | `test_claws_v2.gd`, `test_catalog.gd`, `test_velociraptor_spec.gd`, `test_pulido_biologia.gd`, `test_biologia_v2.gd` |
| **Velocirraptor de cine, FICCIÓN** (`velociraptor_film.gd`, unidad 4i-B2; `docs/fisica/velociraptor.md` §11): un segundo velocirraptor, en su propio grupo «Dinosaurios de película (ficción)». Lo que puede ser real lo es, con su fuente y su calidad: el tamaño de *Deinonychus*, en el que se basaron la novela y la película (3,4 m y 0,87 m de cadera), su masa por el fémur con el mismo escalado que la reconstrucción (99,8 kg; 44,3-124,8), la garra de Ostrom (120 mm), el agarre escalado de los gavilanes (1841 N; 696-5452), la garra sola de Bishop (30 N) y la carrera y el salto de la reconstrucción. Lo de película lleva la calidad nueva `ficcion` («ficción (película)»), nunca la de un dato: su garra raja la chapa porque aquí es tan dura como la tachuela de acero del banco (200 HV, 200 GPa), el doble que el acero de la carrocería; la de verdad, de queratina (32 HV), no lo corta | Solo ensayos nuevos (el catálogo 1.x, el oráculo y los 74 escenarios anteriores no cambian). El golden 2.0 añade dos, marcados como ficción: «Velocirraptor de cine rayando el coche moderno» (con el agarre de un pie, 1841 N: «RAJA LA CHAPA», la garra entera de 120 mm al otro lado; r = 200/20 = 10 con la pintura) y «Velocirraptor de cine, golpe contra el coche moderno» (½ × 49,9 × 4,84² = 584,5 J: «ATRAVIESA LA CHAPA», agujero de ~36 mm) | FICCIÓN: Jurassic Park (1993). Datos: Campione et al. 2014 y Campione & Evans 2020 (masa); Ostrom 1969 (garra); Paul 2016 (tamaño); Crichton 1990 y Paul 1988 (por qué *Deinonychus*); Sustaita & Hertel 2010; Bishop 2019; Manning et al. 2006; Sellers & Manning 2007; Henry et al. 2005; Hutchinson et al. 2015 | `test_velociraptor_cine.gd`, `test_golden_v2.gd`, `test_catalog.gd` |
| **Coherencia banco ↔ coche** (unidad 4i-B2): el casuario del catálogo 2.0 pesa lo que la hembra del coche en marcha (`ClawsV2.casuario_mass`: 58 kg, Grzimek 2003; hasta 76 kg, Latch 2007), no los 60 kg sin fuente de la 1.x, y patea con esa masa: m = f·M = 7,55 kg, ½·m·v² = 88,41 J (banda alta w·f·M = 339,7 J). El mellado del cuarzo de la 1f (`Fracture.TOOL_STRENGTH`) lee la resistencia de `claw_fracture.gd` (52,4 MPa: la sílice fundida con la superficie desgastada de Corning) en lugar de los 67 MPa de MakeItFrom: una sola, la del fabricante y la de una superficie que roza. La patada del banco sigue sin el tope de 5,1 pesos del coche: son dos estimaciones de la misma patada en dos rigideces (en el coche, la pata entera es el muelle contra un panel blando; en el banco, una punta contra una muestra pequeña y dura, donde manda la inercia de la masa que golpea); detalle en `docs/fisica/coche-en-marcha.md` §14.6 | Cambian tres escenarios del golden 2.0, sin cambiar ningún veredicto: «casuario 500N impacto sobre piel» (88,41 J; topa con el húmero igual y le sobran 108,8 J en vez de 111,9), «casuario 500N impacto puerta madera» (se queda a 30,5 mm en vez de 30,8: 88 J de 88) y «Casuario de tungsteno, golpe en el brazo» (atraviesa la cortical igual y acaba a 60,4 mm en vez de 60,6). Con el deslizador a 2000 N la daga del casuario sigue atravesando la puerta (35,2 mm). El cuarzo no cambia ningún escenario (ninguno lleva una garra de cuarzo) | Grzimek 2003; Latch 2007; Corning HPFS 7980 (ficha técnica); Portugal et al. 2016 (el tope del coche) | `test_claws_v2.gd`, `test_velociraptor_banco.gd`, `test_velociraptor_spec.gd`, `test_biologia_v2.gd`, `test_fracture.gd`, `test_golden_v2.gd` |
| **Coche en marcha · la ventanilla templada en el golpe** (unidad 4m; `moving_car.gd`; `docs/fisica/coche-en-marcha.md` §15): una zona del golpe nueva, la ventanilla (`luna`, de lado), con la hoja del banco (`Glazing.SIDE_WINDOW`) y la fuerza de pico del parabrisas, F = v_n·√(m_apoyo·k) (apartado 15). Estalla entera al flexar (120 MPa) o por una grieta que atraviesa la capa comprimida si la punta es al menos tan dura como el vidrio (`Glazing.tempered_result`: la queratina y la garra de película, nunca); si no, aguanta entera. Llega quien la alcanza: las rapaces (vuelan), los velocirraptores (saltando, los pies a ~1,19 m) y el oso (cruz de ~1,20 m); el tigre (cruz de ~0,90 m) golpea la puerta y el casuario patea abajo. El balance de energía cuenta lo que se queda la hoja hasta estallar (U = F²/2k) y sigue sumando el total. En la banda del golpe (la de la 4j) se mueve la compresión de las caras, de 150 MPa a favor del coche a 80 en contra (Achintha 2020), con el mismo cálculo en los dos extremos; la hoja y la pata no tienen banda. El salto de un velocirraptor hasta la ventanilla golpea en lo alto: vuela lo que tarda en subir (~0,49 s) y no cae nada | Solo golpes nuevos del coche en marcha: no cambia `compute()` ni ningún escenario del golden 2.0 (`physics.gd` y `glazing.gd` no se tocan), ni ningún caso de referencia de antes. Se añaden 4 casos: el águila que cruza a 20 km/h con garras de diamante la revienta por una grieta con ~407 N por garra (bastan ~231 N), sin fuerza para partirla al flexar (~814 N por apoyo contra ~1121); con sus talones aguanta; el oso a 10 km/h la revienta al flexar (~2863 N contra ~1521) y el velocirraptor de cine salta para llegar y la revienta | Nielsen, Schneider & Kraus 2022; EN 12150-1; Achintha 2020; CEPE R43; Anstis et al. 1981; Young & Budynas 2002 (Roark); Cui et al. 2025 (la cintura, estimación); Hunter 2011 y Mazák 1981 (la cruz del tigre); Animal Diversity Web (la del oso); Naish 2007 (el casuario, pregunta abierta) | `test_moving_car_window.gd`, `test_moving_car_window_draw.gd`, `test_moving_car.gd` (casos de referencia), `test_moving_car_banda.gd` |
| **Reforja experimental de garras** (unidad 5d; `claw_forge.gd`, `claw_forge_data.gd` y `claw_forge_tutorial.gd`; `docs/fisica/reforja.md`): la garra viva no aguanta el calor (la queratina se quema a ~230 °C), así que la garra reforjada es una **funda** hecha aparte y **pegada en frío**, como una corona dental. El proceso por etapas: material (recetas del horno —zafiro y rubí de Verneuil, metal duro y alúmina sinterizados, acero por inducción, oro, titanio y vidrio colados, diamante HPHT y CVD— o una piedra comprada), horno (modo, temperatura, tiempo, atmósfera, presión, molde y metano frente a la receta y a los datos del material: fusión, oxidación, línea de Kennedy, ritmo de crecimiento), enfriar (Kingery con el factor de Manson; el agua calibrada con la alúmina), tallar (Archard, Bifano y el desconchado de Chai y Lawn), proteger la carne viva y recubrir (en la funda, real; en la garra viva, **ficción**, con el calor por dos vías), unir (el adhesivo o la queratina, el que aguante menos), pulir y comprobar con la fuerza del animal. Lo que no se hace de verdad va con `quality: "ficcion"`: el horno que lo junta todo, recubrir la garra en el animal y verter un material fundido encima. Dos materiales nuevos de la 2.0, `rubi` (corindón: la mecánica del zafiro) y `alumina` (sinterizada), con la forma de `Data.INLAYS` (en el catálogo 2.0 desde la unidad 5g: fila siguiente) | Ninguno: es un módulo nuevo; ni el banco ni el golden cambian. La garra resultante (`result_claw`) lleva material, dureza, módulo, resistencia, masa, afilado y acabado para el banco, el coche en marcha y la cetrería (`care_setup`) | Kennedy y Kennedy 1976; Sumiya et al. 2002; Balmer et al. 2009; Coble (US 3.026.210); Scheel 2000; Kingery 1955; Manson 1966 (Lu y Fleck 1998); Chai y Lawn 2007; Bifano et al. 1991; Groner et al. 2004; Schneider et al. 1997; Henkel (LOCTITE); Ferreira et al. 2024 y el resto de `docs/fisica/reforja.md` §15 | `test_claw_forge_spec.gd` (23 casos de referencia), `test_claw_forge.gd`, `test_claw_forge_recipes.gd` |
| **Cetrería · pasada de física** (unidad 5g; `claw_care.gd`, `claw_care_data.gd`, `claw_care_state.gd`, `claw_care_patient.gd` y `catalog.gd`; `docs/fisica/cetreria.md` §11): el rubí y la alúmina de la reforja en el catálogo 2.0 (`Catalog.V2_INLAYS`), con su densidad, su resistencia, su tenacidad y su afilado (`ClawMass`, `ClawFracture`, `ClawSharpness`). En la cetrería: probar la punta (el vértice contra la uña: Hertz, la carga que aguanta con R² y la distancia crítica de Taylor), dónde está el calor, la forma de cada garra dedo a dedo (`CareData.CLAW_SHAPES`), una sola fuente del arco de cada garra del banco para todos los dibujos (`CareData.claw_arc`), el animal compartido entre sus garras, el consejo del calor según la herramienta, la forma en directo, la rotura con su sitio, la garra rota que vuelve de la reforja como un bloque en bruto (ficción marcada) y la superficie de cada pasada (rugosidad, quemado y desconchones) | En el banco, solo ensayos nuevos: el rubí y la alúmina como incrustación (el rubí da lo que el zafiro; test). Los escenarios del golden 1.x y del golden 2.0 no cambian | Fowler et al. 2009; Pike y Maitland 2004; Birn-Jeffery et al. 2012; AIWC 2023; Laubé et al. 2019; Johnson 1985; Pattrick et al. 2018; Taylor 2007; Bifano et al. 1991; CoorsTek AD-995; Machinery's Handbook; el resto en `docs/fisica/cetreria.md` §12 | `test_claw_care_materiales.gd`, `test_claw_care_pulido.gd`, `test_claw_care_dedos.gd`, `test_claw_care_bloque.gd`, `test_care_page_probar.gd` |
| **Cetrería · el limado según la dureza y la abrasión** (unidad 5l; `claw_care.gd`, `claw_care_kit.gd`, `claw_care_data.gd`, `claw_care_state.gd` y `sparks.gd`; `docs/fisica/cetreria.md` §11.12): el desgaste de las herramientas (Archard con la razón de durezas al revés), el roce sin morder con el μ de cada pareja, la fuerza de los cortaúñas frente a la de la mano, el arranque frágil por encima de la hondura crítica, lo que sale de cada pasada y las chispas de cada metal | Solo la cetrería; los goldens 1.x y 2.0 no cambian | Pintaude et al. 2009; Richardson 1968; Barrett 1990; Mathiowetz et al. 1985; Bifano et al. 1991; Stokes 1851; TC 9-237; Kelley y Blickensderfer 1974 (RI 7902) | `test_claw_care_limado.gd` |
| **El pico de Hertz en el resultado** (unidad 4p; `physics.gd` → `_hertz`, y los textos en `bench_texts.gd`): con un contacto elástico, la presión del resultado es F/A, la fuerza repartida por toda la punta como si tocara entera, pero la punta solo toca en el círculo de Hertz. El resultado gana `p0MPa` (el pico, p0 = 3F/(2π·a²), 1,5 veces la media del círculo), `hertzRadiusUm` (a = (3FR/4E*)^(1/3)) y `hertzYield`: quién pasa ya de su límite elástico (p0·√(1+3μ²) > 1,6·Y, con Y = H/2,8; «punta», «objetivo», «las dos» o null si todo es elástico). Son los mismos p0 y a que el motor ya calculaba para decidir φ, con la misma carga. Solo con un sólido homogéneo, sin golpe, sin la herramienta rota, con el círculo dentro de la esfera de la punta y φ < 1 (el material no plastifica del todo); null en la piel, con pintura o laca (una capa más fina que el contacto), en un golpe (la carga dinámica plastifica) y en la 1.x. Si alguien cede, el pico es una cota alta: el de verdad es menor y la presión media no pasa de la dureza de quien cede | Ningún número ni veredicto de antes: los 76 escenarios del golden 2.0 ganan las tres claves, con valor en 5. «uña natural sobre vidrio» (la uña cede a 17,2 N: 19,1 MPa de media F/A y 477,6 MPa de pico en un círculo de 131 µm; cede la uña); «uña natural sobre acero 100 pasadas» (819 MPa en 89,5 µm; cede la uña); «uña + cuarzo 30N sobre pantalla móvil» (6089 MPa en 37,9 µm; ceden el cuarzo y la pantalla); «Uña cuadrada de zafiro rayando el vidrio: grietas de Hertz» (2089 MPa en 82,8 µm, elástico) y «Uña cuadrada de diamante apretando la encimera: cono de Hertz» (4931 MPa en 170 µm, elástico): los dos ensayos de las grietas de Hertz son justo los de contacto elástico. En la tarjeta del resultado, con un contacto elástico, la «Presión media» F/A y el «Pico de Hertz» con su círculo (en oro y «cota alta» si alguien cede), la frase que dice cuál es cuál (y, si un frágil se agrieta sin que nada ceda, que las grietas de Hertz no son huella: las abre la tracción en el borde del círculo) y la fila «Contacto elástico (Hertz)» de las fuentes del ensayo: la uña almendra a 4 N sobre el vidrio reparte 4,44 MPa por toda la punta, pero toca en un círculo de 80,6 µm con 293,8 MPa en el centro, más de lo que aguanta la queratina sin ceder. Lo que no cambia: con un contacto plástico y F/A por debajo de la dureza, la «Presión real» sigue siendo la de la 1.x (F/A), aunque el contacto de verdad sea más pequeño y su presión media, la dureza de quien cede | Johnson 1985 (cap. 4 y 6); Tabor 1951 | `test_hertz_v2.gd`, `test_lab_ui.gd`, `test_golden_v2.gd` |
| **Logros de lo nuevo de la 2.0** (unidad 4p; `lab.gd` → `BADGES_V2`, `earn_badges_model` y `earn_car_badges`): once logros aparte de los 15 de la 1.x (que no cambian: los compara el oráculo), con su propio contador en la tarjeta de los logros. En el banco: «🐝 Kamikaze» (un aguijón se queda clavado y el insecto se desgarra al irse), «Raptor de verdad» (el velocirraptor reconstruido deja su marca), «Solo en el cine» (la garra de película raja o atraviesa la chapa de un coche, lo que la de queratina no puede), «Callo de serie» (el callo de la palma se pule sin sangrar), «Herida penetrante» (la punta entra en la cavidad del abdomen), «Hasta el hueso», «🪝 De gancho» (corta con un ataque de más de 90°), «💅 Uña rota» (la uña se parte) y «Martillo de emergencia» (la ventanilla templada estalla por una grieta, no por flexión). En la página del coche en marcha: «🐾 Polizón» (quieto encima, aguanta a 100 km/h o más) y «Abollado en marcha» (un golpe que deja una abolladura visible). Solo con la física 2.0; sus emoji ya estaban en el subconjunto de la fuente | Ni un número ni un veredicto: solo `badgesAfter` del golden 2.0, que desde «gabón 30N impacto sobre piel» suma «hueso» (el colmillo llega al húmero) y, en los escenarios nuevos, «kamikaze» (la abeja en la piel), «unarota» (la stiletto XL de acrílico), «martillo» (el tigre de diamante contra la ventanilla), «callo» (el pájaro en la palma), «penetrante» (el Gabón en el abdomen), «gancho» (la cuadrada a 150°), «raptor» (el velocirraptor en el brazo) y «cine» (el de cine rayando el coche): los nueve del banco salen en la serie | — (no es física: lo que enseña cada ensayo, con los campos de su resultado) | `test_badges_v2.gd`, `test_lab_progress.gd`, `test_moving_car_ui.gd`, `test_golden_v2.gd` |
| **Coche en marcha · garras clavadas y hueco compartido** (unidad 4p; `moving_car.gd` → `claws_hold_n`, `sheet_bearing_n`, `shared_room_um` y `_share_gap`, y `claw_fracture.gd` → `shear_limit_n`; `docs/fisica/coche-en-marcha.md` §17): lo que aguantan de lado unas garras reforjadas clavadas en la chapa es el menor de tres límites: la flexión de la garra (la de siempre), su cortante (τ = 4V/3A en la sección de la cara de fuera del metal; un frágil se rompe con su resistencia a flexión y un dúctil fluye a σ/√3) y la chapa que se aplasta alrededor del agujero, como contra un tornillo (2,5·k_t·f_u·d·t, con la f_u de cada carrocería; banda favorable, 3·f_u·d·t). Antes solo se miraba la flexión, que con las garras hundidas hasta la base tiene un brazo de 0,46 mm y daba «3.0 MN» a cuatro talones de carburo de tungsteno en el techo. Y la punta de unas garras que atraviesan el panel comparte el hueco de debajo con la abolladura del mismo apoyo (se resuelven a la vez) | Ningún escenario del golden 2.0 (no toca `physics.gd`). En el coche: el águila con talones de carburo clavados aguanta de lado 20,6 kN y manda la chapa (5148 N por garra; la garra sola, ~199 kN); con vidrio o strass manda el cortante (11,7 kN). El anclaje quieto encima no cambia (manda el agarre: ~202 N), salvo en la banda desfavorable del velocirraptor de cine con carburo (de 696 a 669 N), y ningún veredicto. En el golpe del velocirraptor de cine contra el capó, la punta entra 35,0 mm en vez de 80,8 y la abolladura es de 45,8 mm en vez de 43,5 (las garras se quedan 64,5 J en vez de 157,1); cambian tres casos de referencia del coche (`velocirraptor-cine-capo`, `velocirraptor-cine-puerta` y `tigre-zafiro-puerta`) | EN 1993-1-3 (tabla 8.4) y EN 1993-1-8 (tabla 3.4); AISC 360-16 (J3.10); Timoshenko y Gere 1997; Budynas y Nisbett 2015; la f_u de las chapas del apartado 14 (Nippon Steel 2013, voestalpine 2022, ArcelorMittal B10, Prillhofer et al. 2014) | `test_moving_car_clavadas.gd`, `test_moving_car_hondura.gd`, `test_moving_car.gd`, `test_moving_car_velociraptor.gd` |
| **Coche en marcha · el deportivo** (unidad 4r; `sports_car.gd`, `moving_car.gd` → `slider_max_kmh` y `car_cda`, `moving_car_state.gd`; `docs/fisica/coche-en-marcha.md` §19): un segundo coche, el Porsche 911 Carrera (992), con su velocidad máxima como tope del deslizador y de la gráfica (293 km/h; el turismo y los demás coches siguen en 230) y su Cd·A para la resistencia del coche (`carDragN`). Chapa y pintura, las del coche de aluminio (caso medido más parecido); Cp por zona, el del turismo (estimación); área frontal, estimación con sus medidas | Solo ensayos nuevos del coche en marcha con el deportivo: el despegue de un animal sale igual que en el turismo (el mismo aire), pero el veredicto deja de ser «aguanta a 230 km/h» cuando se suelta entre 230 y 293 (la arpía en el capó, ~254; el oso de pie en el techo, ~289). Los coches de antes no cambian (mismo despegue, misma resistencia y misma gráfica) y el golden 2.0 del banco tampoco | Porsche AG (2019), ficha del 911 Carrera (992): 293 km/h, 1505 kg, Cd 0,29, 4519 × 1852 × 1300 mm; Porsche AG (2018): piel de aluminio; Varney et al. (2020), DrivAer | `test_deportivo.gd` |
| **Coche en marcha · el coche en curva** (unidad 4t; `car_curve.gd`, `moving_car_state.gd`; `docs/fisica/coche-en-marcha.md` §20): la aceleración lateral de una curva, a = v²/R (exacta), sustituye a la de la maniobra en la componente lateral del equilibrio de siempre (se suma como vector al viento y al peso), sin pasar del tope de agarre lateral del coche (0,85 g el turismo, 1,0 g el deportivo: si la curva pide más, el coche derrapa y el animal no siente más). Radios mínimos de la norma 3.1-IC (tabla 4.4) y una glorieta urbana de 15 m; la curva en S con las clotoides de la norma para su J a la velocidad de proyecto (4.4.3.1 y tabla 4.6, sin peralte), con el tirón J·(v/v_p)³. Las garras del lado de fuera cargan más (ΔN = F_lat·h/2b, con h/b ≈ 1, estimación); el veredicto no depende de ese reparto. En el golpe en curva solo cambia el camino del animal visto desde el coche que gira | Solo ensayos nuevos del coche en marcha con la carretera en curva: en recta todo sale al bit como antes (`compute()`, el golden 2.0 y los casos de referencia del coche no cambian), y el golpe en curva da el mismo `impact()`. Ejemplos: el tigre tumbado en el techo en la curva de 130 m aguanta hasta que el coche derrapa (~119 km/h); la lechuza en el techo en la de 50 m resbala hacia fuera a ~67 km/h (el coche derraparía a ~74); en la S de 130 m a 95 km/h tira 0,55 g de cada lado y cambia de lado con un tirón de ~2 m/s³ (4 veces la J de la norma a 60 km/h) | Ministerio de Fomento (2016), Norma 3.1-IC Trazado (Orden FOM/273/2016), tablas 4.3, 4.4 y 4.6, apartados 4.4.3.1 y 10.6; Wong (2008); Car and Driver (2021) vía Stuttcars (2022), el 911 GT3 (992), como caso parecido | `test_car_curve.gd`, `test_car_curve_ui.gd` |

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
  estimados) atraviesa los 35 mm de roble (test). En la 2.0 la patada sale del salto medido en aves (~88 J con la hembra
  de 58 kg) y, con la fuerza de su ficha, se queda a ~31 mm («Cambios de la 2.0», filas «Patada del casuario en el banco» y
  «Coherencia banco ↔ coche»).

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
la chapa. El motor 1.x no modela la abolladura; la 2.0 sí (`dent.gd`, en «Cambios de la 2.0»).

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

## 16. Aguijones de insectos (2.0)

Solo en la física 2.0 (`p.model = "2.0"`): el motor 1.x no tiene aguijones. El modelo completo, los datos de cada
especie con su calidad, las estimaciones, las discrepancias entre fuentes y lo que no predice están en
[`docs/fisica/aguijones.md`](fisica/aguijones.md). La física es `godot/core/lab/sting.gd` y su integración en el banco,
`godot/core/lab/sting_lab.gd`. Catálogo: ocho aguijones en el grupo «Insectos» (abeja melífera, avispa común, avispa
papelera, avispón europeo, avispa asiática, abejorro, hormiga bala y avispa halcón) y un material nuevo, la cutícula de
insecto (~43 HV, 3 GPa).

- **Perforar la piel.** Una punta de 1–5 µm no aplasta la piel: abre una grieta. `F_p = 2·J·R` con la tenacidad al corte
  de la capa de arriba (Shergold & Fleck 2005); el ajuste de Davis (apartado 8) solo vale en su rango, y para las
  herramientas de la 1.x da lo mismo que antes. La abeja perfora con ~4,3 mN y empuja ~5,75 mN (medido en la abeja
  asiática, *A. cerana*: de 1,34 a 5,75 mN según la piel).
- **Entrar.** Pasado ese umbral, las lancetas llevan el aguijón por turnos hasta su longitud útil (la abeja, 1,32 mm:
  deja el veneno en la dermis); la fuerza ya no cuenta. La animación usa la duración medida (1,5 s la abeja, ~0,5 s las
  avispas) y el giro helicoidal de −8,4° de la abeja (Wu et al. 2014).
- **Pandear.** Antes de perforar, el aguijón es una columna con la punta libre (Euler con K = 2; Johnson si es corta
  para su material): la abeja pandea a ~8,6 mN. Reforjado en otro material, pandea con el módulo y el límite elástico de
  ese material (la abeja de acero, a ~728 mN; la de diamante, a ~3,8 N). La interfaz dice «SE DOBLA EL AGUIJÓN», con la
  carga en mN, donde una garra diría «SE ROMPE LA PUNTA».
- **Quedarse clavado.** Una púa estira el agujero `ε = 2b/(πD)` (8,9 % en la abeja). La piel recupera hasta un 54 % y
  se cierra detrás de las púas; la cutícula de un insecto, un 4,9 %, y un sólido, su Y/E: no se cierran. La abeja, con
  púas que no se enfundan, pierde el aparato del aguijón (autotomía; arrancarlo pediría 181 veces su peso) y el saco
  sigue bombeando: el 90 % del veneno en 20 s y todo en 1 min (Schumacher et al. 1994; el banco lo enseña ×10). Los
  véspidos enfundan las púas y pueden repetir.
- **Sólidos.** La punta de un aguijón natural es blanda (7–9 HV; la base es ~6 veces más dura, Das et al. 2018) y se
  aplasta contra todo el banco. Contra la madera cuenta la pared celular (46 HV, Konnerth et al. 2009), no la dureza
  Janka. Reforjado, se resuelve con el motor de siempre, con la dureza a la escala de la punta y el pandeo como límite de
  la herramienta.

Unidades: en la interfaz, las fuerzas de los aguijones van en mN (en N a partir de 1 N) y su masa en mg; dentro del
motor, N y kg, como siempre. Limitación de la integración: contra un sólido, el ensayo usa la base de las garras
(0,15 × alcance) y no el radio real del aguijón. Solo cambiaría el agujero de una chapa, y un aguijón pandea (≤ 3,8 N)
mucho antes de romper una (~180 N).

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
| Salto de las aves (patada del casuario y del velocirraptor, 2.0) | 45 J por kg de músculo (67,5 como máximo del músculo esquelético) · 13,0 % de la masa en los músculos de una pata (8,498 kg de 65,3) | Henry et al. 2005 (gallina de Guinea, medido); Hutchinson et al. 2015, tabla 2 (avestruz disecado) |
| Velocirraptor (reconstrucción, 2.0) | fémur 238 mm · garra ósea 64,8 mm con base de 18,7 × 7,1 mm · masa 19,7 kg (14,1–24,6) · estuche 92,7 mm (76,2–95,7) · agarre de un pie 382 N (193–1130) · réplica 483 N · la garra sola ~10 N | Norell & Makovicky 1999 (fósil); Campione et al. 2014; Hedrick et al. 2019; Manning et al. 2006; Sustaita & Hertel 2010; Bishop 2019 (tipos en `docs/fisica/velociraptor.md` §5) |
| Radios de filos y puntas (afilado, 2.0) | hoja de afeitar 40 nm · cuchillo pulido 0,12–0,20 µm · grano 1000 0,5–0,75 µm · aguijón de abeja 1–1,5 µm · microagujas 30–80 µm · cono Rockwell 200 µm | Roscioli et al. 2020; Verhoeven 2004; Ling et al. 2017; Davis et al. 2004; ISO 6508-2 |
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
| Agarre de rapaces | águila 110 N · arpía 200 · búho 45 · halcón 15 · lechuza 8 | escalado lineal con la masa desde el gavilán medido (~22 N/kg); los halcones agarran menos (Sustaita & Hertel). En la 2.0, el escalado medido de Sustaita & Hertel con su banda (`claws_v2.gd`; «Cambios de la 2.0») |
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
| Rigidez del tejido que golpea | 10 N/mm | orden de magnitud de una pata o un dedo; decide la fuerza de pico sobre el vidrio. Caso medido más parecido: la rigidez de la pata al correr, que crece como M^0,67 en animales de 0,1 a 140 kg (Farley et al. 1993): para un tigre o un oso es una cota baja (coche en marcha, `LIMB_STIFFNESS`) |
| Coche en marcha: tenacidad de la aleta al rajarla (2.0, unidad 4g) | 45 kJ/m² (20-50) | la resiliencia con entalla del mismo plástico (SABIC 2024, NORYL GTX964: Charpy 45 kJ/m² e Izod 50 a 23 °C, 20 a −30 °C); una grieta de todo el espesor por garra, sin el doblado de los labios del desgarro ni la pintura: cota baja de la energía (`docs/fisica/coche-en-marcha.md` §13.1) |
| Coche en marcha: ala con el aire por detrás (2.0, unidad 4g) | CL 0,85 («sustenta»), 1,0 («frena»), 0 («suave») | el perfil NACA 0012 al revés, medido en túnel de 0 a 180° (Sheldahl & Klimas 1981: el CL más alto en valor absoluto a 10° de los 180°); de envergadura infinita, así que es una cota alta para un ala; la actitud del ala con el aire por detrás no se conoce: se toma la que más sube (§13.2) |
| Coche en marcha: geometría y huecos de los paneles (2.0, unidad 4g) | capó 1,1 m, 10° y 80 mm; techo 1,6 m y 100 mm; parabrisas 0,9 m y 30°; puerta 1,0 m y 150 mm; aleta 0,8 m y 60 mm | el capó, en los 452 frontales medidos por Cui et al. (2025) y en los 20-100 mm ensayados bajo un capó (Fredriksson et al. 2007); los huecos del techo y la puerta, del orden de los 127 y 152 mm de las normas FMVSS 216 y 214; el resto, una berlina media como el DrivAer, sin medición panel a panel; el hueco de la aleta, sin caso medido (§4 y §13.3) |
| Coche en marcha: patas del tigre y del oso (2.0, unidad 4g) | almohadilla de la mano de 100 y 130 mm; 8 y 10 garras que se clavan | huellas medidas: el tigre, más de 9,7 cm y cuatro dedos (McDougal 1999, en Sharma et al. 2003); el oso, 12,5-14,5 cm en las hembras y más de 14,5 en los machos, y cinco dedos (Mattson 2003): la del oso es una cota baja para 300 kg |
| Ángulo de ataque de la uña (2.0) | 45° | sin medición del ángulo de la uña al rayar (buscada en la 4b); lo más parecido medido son las posturas del dedo sobre una pantalla táctil, de 15° (casi tumbado) a 90° (vertical) (Holz & Baudisch 2010), y 45° es la del medio. El mismo ángulo decide la parte de la carga que flexa la uña (el valor absoluto de cos β + μ·sen β) y el modo de abrasión (`attack.gd`) |
| Ángulo de ataque de garras, colmillos y aguijones (2.0) | 90° (de punta) | la geometría de la 1.x: no hay medición del ángulo con que una garra ataca la superficie al rayar (buscada en la 4b; pregunta abierta) |
| Cara de la herramienta al inclinarla (2.0) | θ = ataque − α, acotada a [1°, 90°] | geometría de la punta esfero-cónica; la fricción de la intercara (Challen & Oxley 1979) no se modela |
| Roce en los flancos de una punta en la piel (2.0) | ξ = 0,05 | centro alto de lo ajustado en sólidos blandos (0,02-0,06; Fregonese & Bacca 2022); los ensayos de agujas en tejido miden fuerzas o tensiones de roce, no un coeficiente de Coulomb de la piel (buscado en la 4b) |
| Módulo de la capa córnea, la epidermis y la fascia en la punción (2.0) | 210 kPa | el de la dermis (apartado 7): la 1.x no les da módulo |
| Umbral para entrar en el hueso (2.0) | r ≥ 1,25 | el de la marca de verdad de la 1.x (Richardson 1968, apartado 4) |
| Médula ósea y cavidad abdominal (2.0) | médula: jC 0,41 kJ/m², E 1,9 kPa · cavidad: las del músculo, sin fondo | la médula amarilla es casi toda grasa; sin medición de la tenacidad del peritoneo ni de las vísceras |
| Huesos de la mano y de la cara (2.0) | metacarpianos 43 HV y cortical de 2,5 mm · cigomático 40 HV | Li et al. 2021: radio y cúbito 42,5-43,3 HV (midió los metacarpianos, pero su texto no da el valor) y cráneo por encima de 40 HV (el valor más bajo, el más favorable a la punta); la medición más cercana en la mano son las diáfisis de las falanges, 38,52 ± 6,67 HV (Yin et al. 2019). La cortical, con el índice cortical del 2.º metacarpiano (~62 %, Schneider & Gilmour 2025) y ~8 mm de anchura |
| Espesores sin medición localizada (2.0) | grasa de la palma 2,5 mm · dermis del dorso de la mano 914 µm · grasa malar 5,77 mm · fascias de la palma, del dorso, el SMAS y la vaina del recto 300 µm | del orden de lo medido al lado: la grasa del dorso de la mano (Hung et al. 2022), la piel del antebrazo (Wang et al. 2022), lo que queda de los 8,7 mm hasta el pómulo (De Greef et al. 2006) y la fascia de la 1.x (Stecco et al. 2009) |
| Excoriación con pasadas en cada zona (2.0) | 75·(n/5)^0,4 µm hasta el fin de la epidermis | la ley de pasadas de la 1.x (n^0,4) anclada en su calibración: 75 µm en 5 pasadas |
| Espesor del esmalte de la punta del colmillo (2.0) | 10 µm | sin medir en víboras: fino y solo en la punta en las serpientes de presas blandas (Dumont et al. 2023). La dureza (321,2 HV) es la del esmalte de cocodrilo (Enax et al. 2013), de calidad secundaria |
| «C» de las uñas artificiales y macizas (2.0) | radio de 7,4 mm | la del índice natural medida (Jung et al. 2015): el gel y el acrílico se construyen sobre ella; en las macizas es un supuesto. Es una cota alta: con carga la «C» se aplana (efecto Brazier) |
| Espesor del gel y del acrílico (2.0) | 0,8 mm en la raíz del borde libre | la guía del salón pide el grosor de una tarjeta (0,76 mm) en el borde libre y el doble en el ápice |
| Resistencia a flexión del gel y del acrílico (2.0) | 60 MPa | sin ensayo publicado de uñas: el mínimo de la ISO 20795-1 para las resinas autopolimerizables (tipo 2), dentro de lo medido en PMMA autopolimerizable (42–86 MPa; Casucci et al. 2023, 75–86) |
| Espesor de las uñas macizas (2.0) | 0,49 mm | el de la uña natural (Baraldi et al. 2015) |
| Resistencia de las uñas de acero y de titanio (2.0) | 640 · 483 MPa | la resistencia a tracción medida de un metal con la dureza del catálogo: el acero de 200 HV por la tabla de la DIN EN ISO 18265 (en los 540–750 MPa de la EN 10088-2 para el 1.4301) y el titanio de grado 2 (~150 HV), ficha técnica. Que la uña dúctil ceda con Rm·Z (del orden de la rótula plástica) es del modelo |
| Tenacidad y Poisson de los frágiles sin dato (2.0) | encimera K_c 1,0 MPa·√m · ν del zafiro 0,29 y del diamante 0,07 | la encimera, el cuarzo monocristalino (0,85–1,15; Iwasa et al. 1981); los Poisson, de manual |
| Umbral de grietas radiales de la pantalla (2.0) | 4,5 N | 0,18 N del vidrio (Mikowski et al. 2006) × 25, el cociente de la gráfica de Corning (2012) |
| Constante de Auerbach (2.0) | A = 8,63·10³ | constante publicada del modelo (Rhee et al. 2001), sin ajuste; sobrestima entre 1,7 y 2,6 veces las cargas medidas sin fricción (Conrad et al. 1979; Ren & Zhang 2014): apretando, el vidrio real se agrieta antes |
| Compresión superficial de la ventanilla (2.0) | 100 MPa | dentro de los 80–150 MPa medidos en templados comerciales (Achintha 2020), por encima de los 69 MPa de la ASTM C1048, y en los 81–144 MPa que dan los 40–400 trozos de la CEPE R43 con la relación de Nielsen et al. (2022) |
| Hojas de los vidrios de coche (2.0) | ventanilla de 4 mm y ~50 cm (radio 250 mm) · parabrisas de 2,1 + 0,76 + 2,1 mm y ~80 cm (radio 400 mm) | los espesores, de los fabricantes (4 mm en Europa y Japón, 5 mm en EE. UU.; la construcción 2,1/0,76/2,1 de Pilkington); los radios solo entran en el logaritmo de Roark (un radio un 50 % mayor o menor cambia la carga de rotura de la ventanilla un −6 % o un +13 %) |
| Acoplamiento del PVB en un golpe (2.0) | el parabrisas flexa como una hoja de 4,2 mm | a corta duración y a temperatura ambiente el laminado se comporta como el monolítico (Galić et al. 2022) |
| Abolladura visible (2.0) | 0,1 mm | el criterio de resistencia a la abolladura de la industria: la carga que deja una abolladura de 0,1 mm (US 7 158 922 B2) |
| Resistencia del cuarzo en el mellado y en la rotura de las garras (2.0) | 52,4 MPa | la sílice fundida, de la misma composición, con la superficie desgastada (Corning HPFS 7980, ficha técnica): sin medición a flexión del cuarzo monocristalino. Una sola para la 1f y la 4d desde la unidad 4i-B2 (antes, 67 MPa de MakeItFrom en el mellado); en el banco, solo informativo |
| Cono de Hertz y anillo en el dibujo (2.0) | 22° con la superficie · anillo de 1,25 veces el contacto | sobre la fig. 1b de Lawn & Marshall 1984 y el 1,1–1,4 de Mouginot & Maugis 1985; solo dibujo |
| Punta de la garra del velocirraptor (2.0) | 138 µm · semiángulo 15° | la queratina no fosiliza y no hay radios de punta medidos en garras de vertebrados: la del talón de la arpía (estimación de la 1.x), su análogo funcional (Fowler et al. 2011). **Pregunta abierta**: la ficha lo dice |
| Resto de la reconstrucción del velocirraptor (2.0) | arco de 160° · estuche ×1/0,699 · agarre escalado de los gavilanes · golpe de 4,84 m/s y 9,85 kg por pie | el caso medido más parecido: el arco de *Deinonychus* (Manning et al. 2006), el estuche de las aves (Hedrick et al. 2019), el pie de un gavilán (Sustaita & Hertel 2010; extrapolación de ×44 en masa) y el salto de las aves con la mitad de la masa en cada pie (el reparto no está medido). Detalle en `docs/fisica/velociraptor.md` §6 |
| Masa eficaz de la patada del casuario en el banco (2.0) | m = f·M = 7,81 kg (banda alta M/2: 351 J) | la masa eficaz de la patada no está medida: la de los músculos de la pata que patea (Hutchinson et al. 2015, avestruz), con la velocidad del salto (Henry et al. 2005); arriba, todo el trabajo de esa pata (con el máximo del músculo, 67,5 J/kg, sería 1,5 veces más). Desde la unidad 4i-B2, con la hembra de 58 kg del coche en marcha: 7,55 kg y 88 J (banda alta 340 J) |
| Garra del velocirraptor de cine (2.0) | 200 HV · 200 GPa | **no es una estimación: es FICCIÓN** (calidad `ficcion`, «ficción (película)»), la tachuela de acero del banco para que raje la chapa como en el cine. La de verdad es de queratina (32 HV) y no corta el acero (`docs/fisica/velociraptor.md` §11) |
| Resto del velocirraptor de cine (2.0) | masa de 99,8 kg (44,3-124,8) · agarre de 1841 N · apoyo de 50 mm | lo de *Deinonychus*: el escalado del fémur (Campione et al. 2014) con su error de predicción y la volumétrica más ligera (Campione & Evans 2020); el agarre de los gavilanes, extrapolado ×222 en masa (Sustaita & Hertel 2010); el apoyo de la reconstrucción escalado con la cadera |
| Velocirraptores en el coche en marcha (2.0) | área frontal de un ave · alturas de los paneles · carrera de *Velociraptor* para *Deinonychus* | el cuerpo de un ave con su masa (Pennycuick et al. 1988), extrapolado; el borde del capó y el alto de la berlina de base de Cui et al. (2025), con el largo y la inclinación de los paneles del modelo; sin modelo de la carrera de *Deinonychus*, la de su pariente (Sellers & Manning 2007). Detalle en `docs/fisica/coche-en-marcha.md` §14.7 |
| Coche en marcha: altura de la ventanilla (2.0, unidad 4m) | de 0,891 m (0,86-1,10) a 1,475 m | la cintura, al pie del parabrisas: el borde del capó de la berlina de base de Cui et al. (2025) más el capó del modelo (1,1 m a 10°); arriba, el alto de esa berlina. Sin medición publicada de la cintura de los turismos (`docs/fisica/coche-en-marcha.md` §15.1) |
| Coche en marcha: cruz del tigre y del oso (2.0, unidad 4m) | 0,90 m (0,80-1,00) · 1,20 m (0,90-1,50) | el centro de los intervalos publicados: el tigre, 80-100 cm en machos y hembras (Hunter 2011 y Mazák 1981, vía la San Diego Zoo Wildlife Alliance); el oso, 90-150 cm (Animal Diversity Web), y uno de 300 kg es un macho grande. Llega a la ventanilla si el centro de su apoyo pasa de la cintura (suposición del modelo): el oso sí; el tigre no (con los datos más favorables, sí) |
| Coche en marcha: qué ventanilla golpea (2.0, unidad 4m) | la de delante | sin criterio físico: dónde cae el golpe a lo largo del coche lo decide cuándo se cruzan; la de la misma puerta que el golpe en la puerta (dibujo) |
| Coche en marcha: energía del temple que se libera (2.0, unidad 4m) | ~17 J | U_D·V con U_D = (1 − ν)·σS²/(5E) (Nielsen et al. 2022) y la hoja de 250 mm de radio de la unidad 1f (estimación). No sale del animal: no es un término del balance |
| Coche en marcha: lo que aguanta la chapa alrededor de una garra clavada (2.0, unidad 4p) | 2,5·k_t·f_u·d·t (~5148 N por talón de águila en el coche moderno); banda favorable, 3·f_u·d·t | caso medido más parecido: un tornillo que aplasta una chapa fina lejos de sus bordes, sin coeficiente de seguridad (EN 1993-1-3, tabla 8.4, de 0,75 a 3 mm; la chapa de 0,7 mm del coche moderno, con la misma recta) y, sin límite de deformación del agujero, AISC 360-16 (J3.10). La garra es un pasador cónico, no un tornillo, y los pétalos doblados ni suman ni restan (`docs/fisica/coche-en-marcha.md` §17.2) |
| Coche en marcha: tope de agarre lateral del turismo (2.0, unidad 4t) | 0,85 g (0,8-0,9) | la adherencia de pico del neumático en asfalto seco de Wong (2008), 0,8-0,9, tomada también de lado para un turismo de serie; pasado el tope, el coche derrapa y el animal no siente más (`docs/fisica/coche-en-marcha.md` §20.3) |
| Coche en marcha: tope de agarre lateral del deportivo (2.0, unidad 4t) | 1,0 g (0,9-1,1) | sin prueba de patinaje publicada del 911 Carrera (992): el caso medido más parecido es su versión de circuito, el GT3, 1,16 g en la pista circular de 300 pies de Car and Driver (2021) con neumáticos semislick; el de calle, por debajo (§20.3) |
| Coche en marcha: reparto de la carga entre las garras de cada lado (2.0, unidad 4t) | h/b ≈ 1 (0,5-1,5) | estática de un sólido sobre dos apoyos, ΔN = F_lat·h/2b, con el centro de masas a la altura de media base de apoyo (agazapado): una suposición sin medición publicada de un animal agarrado a un coche en curva; el veredicto de agarre no depende de él mientras las garras de dentro apoyen (§20.5) |
| Coche en marcha: radio de una glorieta urbana (2.0, unidad 4t) | 15 m (12-18) | 3.1-IC, 10.6: diámetro exterior de 30 a 40 m en una glorieta urbana de un carril; el coche va por el centro del carril, 2-3 m por dentro del borde (§20.2) |
| Radio de un filo (afilado, 2.0) | anchura/2 | Verhoeven 2004 mide la anchura del filo (0,23–0,40 µm y 1–1,5 µm); se supone redondeado |
| Carga lateral en la punta afilada (2.0) | μ·F en el vértice al rayar; 0 al punzar | la viga en voladizo de las unidades 1f y 4d (Pattrick et al. 2018: la carga que aguanta crece con R²); una garra curva que engancha también carga su punta de lado sin deslizar, y eso no se modela |
| Reforja: convección del temple (2.0, unidad 5d) | agua 8·10⁴ W/(m²·K) · aceite 2,3·10⁴ · aire 15 | el agua, calibrada: con el factor de Manson, una probeta de alúmina de 3 mm templada en agua aguanta 201 °C (medido: 170-300 °C, Morgan Technical Ceramics); el aceite, por la relación de severidades de Grossmann (0,275/0,95); el aire, el de la cetrería (Incropera) |
| Reforja: cortante de la queratina bajo una unión (2.0, unidad 5d) | σ/2 × 0,25: 8,6 MPa natural, 1,75 MPa empapada | Tresca y la relación entre capas de la uña (Farren et al. 2004); en las herraduras pegadas rompe el casco, no el adhesivo (Ferreira et al. 2024). Sin medición en garras |
| Reforja: la funda, la muela y la comprobación (2.0, unidad 5d) | funda del 40 % de la garra con 1 mm de pared · muela de 10 N a 20 m/s con 3 × 3 mm de contacto · piel de 0,1 mm · en seco se agrieta lo frágil con k < 10 W/(m·K) · toda la fuerza de la ficha como cortante sobre la unión | elecciones del ensayo y reglas del modelo, como una corona dental y el tallado de lapidario (siempre con agua) |
| Reforja: recubrimientos y hornos sin cifra publicada (2.0, unidad 5d) | proyección de plasma con la pieza a 150 °C · pulverización catódica de 2 µm a 100 °C · esmalte de ~550 HV · diamante grafitizado en vacío desde 1500 °C · alúmina HV ≈ HK · titanio colado 30-100 °C por encima del líquido · cargas fundidas en 2-10 min · CVD a una fracción de la presión del aire | dentro de lo publicado para cada método (`docs/fisica/reforja.md` §10): ≤ 250 °C en la pulverización, 1-4 µm en las capas de PVD, el strass del banco, < 1700 °C a baja presión (Khmelnitsky y Gippius 2014), el oro de Ganoksin |
| Cetrería: rugosidad de cada pasada (2.0, unidad 5g) | Ra = h/4 con la hondura del surco de cada grano o de cada diente suelto (~(dientes/cm)² por cm²) · los surcos de antes se borran al quitar 4·Ra | la definición de Ra sobre una onda triangular; sale del orden del acero lijado (0,8-1,5 µm con P150-P240, 3-5 µm con P40-P60; Whitby Abrasives, bandas orientativas), quizá por lo bajo. Sin medición de garras limadas |
| Cetrería: rugosidad de partida (2.0, unidad 5g) | natural 0,31 µm · reforjada pulida 0,05 µm · bloque en bruto 3,2 µm | la natural, la uña humana medida (308 ± 52 nm, Laubé et al. 2019): sin medición en garras; la pulida, el lapeado, y el bruto, la fundición a la cera perdida (Machinery's Handbook, de ANSI/ASME B46.1) |
| Cetrería: quemado de la superficie (2.0, unidad 5g) | de 215 a 230 °C · se va al quitar 0,1 mm | la desnaturalización de la queratina (Kakkar et al. 2014) hasta el tope del modelo térmico; lo que se quita, un nodo del modelo |
| Cetrería: garras dedo a dedo del tigre y del oso (2.0, unidad 5g) | todos los dedos como la garra del banco · las patas traseras como las de la mano · sección alto/ancho 1,8 (tigre) y 1,3 (oso) | sin medición dedo a dedo ni de la sección que hayamos podido leer; la sección, entre la rapaz (redonda) y la hoja medida del velocirraptor (2,6; Norell y Makovicky 1999) |
| Cetrería: arcos sin medición propia (2.0, unidad 5g) | emú 41° · avestruz 31° · gato 98,4° · espolón del gallo 75° · oso 98° | el caso medido más parecido: el casuario y el ñandú (Pike y Maitland 2004), el tigre (AIWC 2023); el espolón y el oso, el arco de su dibujo, dentro de lo medido en garras parecidas |
| Cetrería: probar la punta (2.0, unidad 5g) | toque de 0,5 N · K_c = √(E·J) ≈ 4,7 MPa·√m en la queratina natural | el toque, elección del ensayo; K_c, con el módulo de la garra de avestruz (Taylor et al. 2004) y el trabajo de rotura de lado de la uña (Farran et al. 2008) |
| Cetrería: el bloque en bruto de la garra rota (2.0, unidad 5g) | 1 mm de sobra · su calor, con la conducción de la queratina | la pared de la funda de la reforja (elección del ensayo); la conducción vale para el acrílico (~0,2 W/(m·K)); en los metales y las cerámicas el calor llegaría antes a la carne viva (lo dice la nota de la ficción) |

Si encuentras una medición publicada, sustituye el valor, cita la fuente aquí y actualiza el golden.

## Limitaciones conocidas

- La profundidad es **bajo carga**: no se modela la recuperación elástica de los polímeros.
- Las uñas se tratan como puntas (esfero-cónicas), no como filos; no se modela su rotura por
  flexión (una stiletto real se partiría mucho antes de 30 N).
- Chapas finas (coches, puerta de aluminio): el inicio de la rotura se aproxima con la indentación
  hasta la cara de atrás (Atkins et al. 1998 lo trata con detalle); los pétalos suponen fractura
  dúctil (δt/t = 1) y no dependen de la velocidad. En el plástico se usa la misma fórmula, pensada
  para metales dúctiles. La abolladura solo se modela en la 2.0 (`dent.gd`: colapso rígido-plástico y
  membrana, calibrado con **una sola medición**, Nippon Steel 2013); el motor 1.x no la tiene. Lo que hay
  detrás del panel (refuerzos, cristal, panel interior) no se modela en ninguno de los dos.
- Vidrio: en el motor 1.x, solo recocido y con la carga en el centro de la hoja. La 2.0 añade la ventanilla
  templada y el parabrisas laminado (`glazing.gd`: EN 12150-1, CEPE R43, JIS R 3212), con los radios de las
  hojas estimados por geometría.
- Frágiles: en el motor 1.x el astillado es solo una etiqueta. La 2.0 calcula las grietas de Hertz y el
  umbral de Lawn-Evans (`fracture.gd`), pero con la constante de Auerbach del modelo (Rhee 2001), que
  sobrestima entre 1,7 y 2,6 veces las cargas medidas: la medición del vidrio sodocálcico (Langitan & Lawn
  1969; Warren 1978) no está accesible y queda pendiente.
- Coche en marcha (2.0): unas garras trabadas en la aleta de plástico la rajan solo en un golpe de costado y con una
  grieta de todo el espesor, sin el doblado de los labios del desgarro ni el peso del animal colgado; quieto encima, lo
  que aguanta el plástico alrededor de unas garras clavadas no limita el anclaje; con el aire por detrás, la actitud del
  ala no se conoce y se toma la que más sube (`docs/fisica/coche-en-marcha.md` §7 y §13).
- Coche en marcha (2.0), la ventanilla templada (unidad 4m): si el animal entra en el coche por el hueco, no se calcula; golpea la
  ventanilla de delante sin un criterio físico; la hoja es una placa redonda apoyada con la carga en el centro (ni curva, ni sujeta en sus
  guías, ni con inercia); y el tigre y el casuario no llegan porque su salto hacia arriba no está medido en el modelo
  (`docs/fisica/coche-en-marcha.md` §15.9).
- Piel: en el motor 1.x, una sola zona de referencia (brazo), sin hueso y sin roce en los flancos. La 2.0 tiene
  cinco zonas (brazo, palma, dorso de la mano, pómulo y abdomen), el hueso bajo el músculo y el roce en los
  flancos de la punta (`zones.gd`, `penetration.gd`; Shergold & Fleck), con las estimaciones de su tabla. No se
  modela en ninguno de los dos la elasticidad de la piel que retrocede, y la dureza de los metacarpianos (43 HV)
  espera la medición del metacarpiano de Li 2021 (solo sale en una figura).

## Datos investigados pendientes de integrar

- **Aguijones: integrados en la 2.0** (apartado 16 y `docs/fisica/aguijones.md`). Correcciones de lo que se apuntó
  aquí: los 6–8 mN de «avispa» son de una avispa papelera (*Polistes*), no de la avispa común (*Vespula*), y todas las
  fuerzas medidas de «abeja» son de la abeja asiática (*A. cerana*), con un aguijón casi idéntico (1,34, 2–3 y 5,75 mN
  según la piel, no solo 2–3); la punta es ~6 veces más blanda que la base (no ~5; Das et al. 2018); y los ángulos de
  −6° (abeja) y +10° (avispa) son óptimos calculados por elementos finitos (Das et al. 2018), no ángulos medidos: la
  abeja entra casi perpendicular y *Polistes* baja de 18° a 9° (Zhao et al. 2015).
- **Escala de Schmidt:** abeja y avispa común 2; hormiga de fuego 1,2 (1990) o 1 (2016); hormiga bala 4;
  *Pepsis* (avispa halcón) 4. Las de los aguijones del catálogo ya están en sus fichas.
- **Esmalte en la punta del colmillo** (Estrada 2026): integrado en la 2.0 con la dureza del esmalte de cocodrilo
  (321,2 HV, Enax et al. 2013, secundaria) y un espesor de 10 µm estimado (Dumont et al. 2023). Falta la dureza
  medida en esmalte de víbora.

## Fuentes

- Ankersen J. (1999). *Quantifying the forces in stabbing incidents*. Tesis doctoral, University of Glasgow. http://theses.gla.ac.uk/2798/
- ArcelorMittal. B10 – Steels for cold forming (DC01–DC07, EN 10130), catálogo técnico. https://ssc.arcelormittal.com/IMG/pdf/cr_cold_forming_-_b10.pdf
- Archard J.F. (1953). Contact and rubbing of flat surfaces. *J. Appl. Phys.* 24:981–988. doi:10.1063/1.1721448
- Aryeetey O.J., Frank M., Lorenz A., Pahr D.H. (2022). Fracture toughness determination of porcine muscle tissue based on AQLV model derived viscous dissipated energy. *J. Mech. Behav. Biomed. Mater.* 135:105429. doi:10.1016/j.jmbbm.2022.105429
- ASTM G171. *Standard Test Method for Scratch Hardness of Materials Using a Diamond Stylus*. ASTM International (dureza al rayado: la carga la soporta la mitad delantera del contacto).
- Atkins A.G., Afzal Khan M., Liu J.H. (1998). Necking and radial cracking around perforations in thin sheets at normal incidence. *Int. J. Impact Eng.* 21:521–539.
- Bissessarsingh M., Starr C.K. (2021). Comparative morphology of the stinger in social wasps (Hymenoptera: Vespidae). *Insects* 12:729. doi:10.3390/insects12080729
- Bowden F.P., Tabor D. (1950). *The Friction and Lubrication of Solids*. Clarendon Press, Oxford.
- Comley K., Fleck N.A. (2010). The toughness of adipose tissue: measurements and physical basis. *J. Biomech.* 43:1823–1826. doi:10.1016/j.jbiomech.2010.02.029
- Crofts S.B., Lai Y., Hu Y., Anderson P.S.L. (2019). How do morphological sharpness measures relate to puncture performance in viperid snake fangs? *Biol. Lett.* 15:20180905. doi:10.1098/rsbl.2018.0905
- Das R., Yadav R.N., Sihota P., Uniyal P., Kumar N., Bhushan B. (2018). Biomechanical evaluation of wasp and honeybee stingers. *Sci. Rep.* 8:14945. doi:10.1038/s41598-018-33386-y
- Davis S.P., Landis B.J., Adams Z.H., Allen M.G., Prausnitz M.R. (2004). Insertion of microneedles into skin: measurement and prediction of insertion force and needle fracture force. *J. Biomech.* 37:1155–1163. doi:10.1016/j.jbiomech.2003.12.010
- Estrada S., Arredondo J.C., Pereañez J., Arola D., Ossa A. (2026). Mechanical properties, microstructure, and strike biomechanics of tubular fangs in neotropical vipers. *Acta Biomater.* 222:388–398. doi:10.1016/j.actbio.2026.07.058
- Egawa M., Hirao T., Takahashi M. (2007). In vivo estimation of stratum corneum thickness from water concentration profiles obtained with Raman spectroscopy. *Acta Derm. Venereol.* 87:4–8. doi:10.2340/00015555-0183
- Farran L., Ennos A.R., Eichhorn S.J. (2008). The effect of humidity on the fracture properties of human fingernails. *J. Exp. Biol.* 211:3677–3681.
- Farran L., Ennos A.R., Starkie M., Eichhorn S.J. (2009). Tensile and shear properties of fingernails as a function of a changing humidity environment. *J. Biomech.* 42:1230–1235. doi:10.1016/j.jbiomech.2009.03.020
- Farran L., Ennos A.R., Eichhorn S.J. (2009). Microindentation and nanoindentation of human fingernails at varying relative humidity. *J. Mater. Res.* 24:980–984. doi:10.1557/jmr.2009.0119
- Farley C.T., Glasheen J., McMahon T.A. (1993). Running springs: speed and animal size. *J. Exp. Biol.* 185:71–86 (la rigidez de la pata al correr crece como M^0,67). doi:10.1242/jeb.185.1.71
- Gibney M.A., Arce C.H., Byron K.J., Hirsch L.J. (2010). Skin and subcutaneous adipose layer thickness in adults with diabetes at sites used for insulin injections: implications for needle length recommendations. *Curr. Med. Res. Opin.* 26:1519–1530. doi:10.1185/03007995.2010.481203
- Herrera C., Williams M., Encarnação J., Roura-Pascual N., Faulhaber B., Jurado-Rivera J.A., Leza M. (2023). Automated detection of the yellow-legged hornet (*Vespa velutina*) using an optical sensor with machine learning. *Pest Manag. Sci.* 79:1225–1233 (tablas S1-S2: frecuencias de aleteo, las de los zumbidos del banco). doi:10.1002/ps.7296
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
- Konnerth J., Gierlinger N., Keckes J., Gindl W. (2009). Actual versus apparent within cell wall variability of nanoindentation results from wood cell walls related to cellulose microfibril angle. *J. Mater. Sci.* 44:4399–4406. doi:10.1007/s10853-009-3665-7
- McKittrick J. et al. (2012). The structure, functions, and mechanical properties of keratin. *JOM* 64:449–468. doi:10.1007/s11837-012-0302-8
- Ní Annaidh A., Bruyère K., Destrade M., Gilchrist M.D., Otténio M. (2012). Characterization of the anisotropic mechanical properties of excised human skin. *J. Mech. Behav. Biomed. Mater.* 5:139–148. doi:10.1016/j.jmbbm.2011.08.016
- Nippon Steel (2013). Yonemura S., Uenishi A., Kosugi S., Yoshida T., Hiwatashi S., Nakagawa J. Advanced technologies related to simulation and evaluation for performance of automotive exterior panels. *Nippon Steel Technical Report* 103:11–17.
- O'Callaghan P.T., Jones M.D., James D.S., Leadbeatter S., Holt C.A., Nokes L.D. (1999). Dynamics of stab wounds: force required for penetration of various cadaveric human tissues. *Forensic Sci. Int.* 104:173–178. doi:10.1016/s0379-0738(99)00115-2
- Penning D.A., Sawvel B., Moon B.R. (2016). Debunking the viper's strike: harmless snakes kill a common assumption. *Biol. Lett.* 12:20160011. doi:10.1098/rsbl.2016.0011
- Pintaude G. (2021). Remarks on wear transitions related to hardness and size of abrasive particles. En *Tribology of Machine Elements*, IntechOpen. doi:10.5772/intechopen.99324
- Prillhofer R., Rank G., Berneder J., Antrekowitsch H., Uggowitzer P.J., Pogatscher S. (2014). Property criteria for automotive Al-Mg-Si sheet alloys. *Materials* 7:5047–5068. doi:10.3390/ma7075047
- Pereira B.P., Lucas P.W., Swee-Hin T. (1997). Ranking the fracture toughness of thin mammalian soft tissues using the scissors cutting test. *J. Biomech.* 30:91–94. doi:10.1016/s0021-9290(96)00101-7
- Ramirez-Esquivel F., Ravi S. (2023). Functional anatomy of the worker honeybee stinger (*Apis mellifera*). *iScience* 26:107103. doi:10.1016/j.isci.2023.107103
- Richardson R.C.D. (1968). The wear of metals by relatively soft abrasives. *Wear* 11:245–275. doi:10.1016/0043-1648(68)90175-0
- SABIC. NORYL GTX™ resin GTX964W, hoja técnica (Material Finder). https://materialfinder.sabic-specialties.com/material/noryl-gtx-resin-gtx964w
- SABIC (2024). NORYL GTX™ resin GTX964, región Europa, valores típicos, revisión 20241014 (resiliencia con entalla Charpy 45 kJ/m² a 23 °C y 20 a −30 °C; Izod 50 y 20 kJ/m²). https://materialfinder.sabic-specialties.com/material/noryl-gtx-resin-gtx964
- Saint-Gobain Building Glass UK (2018). Glass fundamentals 1B: the strength of glass (resistencias características según EN 572-1, EN 1863-1 y EN 12150-1).
- Sandby-Møller J., Poulsen T., Wulf H.C. (2003). Epidermal thickness at different body sites: relationship to age, gender, pigmentation, blood content, skin type and smoking habits. *Acta Derm. Venereol.* 83:410–413. doi:10.1080/00015550310015419
- Šarabon N., Kozinc Ž., Podrekar N. (2019). Using shear-wave elastography in skeletal muscle: a repeatability and reproducibility study on biceps femoris muscle. *PLoS One* 14:e0222008. doi:10.1371/journal.pone.0222008
- Schumacher M.J., Tveten M.S., Egen N.B. (1994). Rate and quantity of delivery of venom from honeybee stings. *J. Allergy Clin. Immunol.* 93:831–835. doi:10.1016/0091-6749(94)90373-5
- Shergold O.A., Fleck N.A. (2005). Experimental investigation into the deep penetration of soft solids by sharp and blunt punches, with application to the piercing of skin. *J. Biomech. Eng.* 127:838–848. doi:10.1115/1.1992528
- Sheldahl R.E., Klimas P.C. (1981). *Aerodynamic characteristics of seven symmetrical airfoil sections through 180-degree angle of attack for use in aerodynamic analysis of vertical axis wind turbines*. SAND80-2114, Sandia National Laboratories. doi:10.2172/6548367
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
- Wu J., Yan S., Zhao J., Ye Y. (2014). Barbs facilitate the helical penetration of honeybee (*Apis mellifera ligustica*) stingers. *PLoS ONE* 9:e103823. doi:10.1371/journal.pone.0103823
- Wu K.S., van Osdol W.W., Dauskardt R.H. (2006). Mechanical properties of human stratum corneum: effects of temperature, hydration, and chemical treatment. *Biomaterials* 27:785–795. doi:10.1016/j.biomaterials.2005.06.019
- Young W.C., Budynas R.G. (2002). *Roark's Formulas for Stress and Strain*, 7.ª ed. McGraw-Hill (placas circulares con carga concentrada).
- Zhao Z.-L., Zhao H.-P., Ma G.-J., Wu C.-W., Yang K., Feng X.-Q. (2015). Structures, properties, and functions of the stings of honey bees and paper wasps: a comparative study. *Biol. Open* 4:921–928. doi:10.1242/bio.012195
- El resto de fuentes de los aguijones (apartado 16), en `docs/fisica/aguijones.md` §8.
- El resto de fuentes de la reforja de garras (unidad 5d: hornos, cristales, choque térmico, tallado, recubrimientos y adhesivos), en `docs/fisica/reforja.md` §15.
- Birn-Jeffery A.V., Miller C.E., Naish D., Rayfield E.J., Hone D.W.E. (2012). Pedal claw curvature in birds, lizards and Mesozoic dinosaurs. *PLoS ONE* 7:e50555. doi:10.1371/journal.pone.0050555
- Fowler D.W., Freedman E.A., Scannella J.B. (2009). Predatory functional morphology in raptors: interdigital variation in talon size is related to prey restraint and immobilisation technique. *PLoS ONE* 4:e7999. doi:10.1371/journal.pone.0007999
- Laubé F., Poupon A., Zinck P., Müller-Goymann C., Reichl S., Nardello-Rataj V. (2019). Physicochemical investigations of native nails and synthetic models for a better understanding of surface adhesion of nail lacquers. *Eur. J. Pharm. Sci.* 131:208–217. doi:10.1016/j.ejps.2019.02.014
- Pike A.V.L., Maitland D.P. (2004). Scaling of bird claws. *J. Zool.* 262:73–81.
- El resto de fuentes de la pasada de física de la cetrería (unidad 5g: AIWC 2023, NPS, Norell y Makovicky 1999, Machinery's Handbook, Whitby Abrasives…), en `docs/fisica/cetreria.md` §12.
- El resto de fuentes del coche en marcha (Cui et al. 2025, Fredriksson et al. 2007, FMVSS 214 y 216, Sharma et al. 2003, Mattson 2003, Ashton et al. 2024, y las de la ventanilla templada: Hunter 2011, Animal Diversity Web…, y las de las garras clavadas: EN 1993-1-3, AISC 360-16…), en `docs/fisica/coche-en-marcha.md` §18.
- The Wood Database: Scots pine y English oak (dureza Janka). https://www.wood-database.com
