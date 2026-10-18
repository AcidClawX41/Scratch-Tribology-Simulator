# Unidad 7 · Afiladora de cuchillos, brocas y fresas

Fuentes, modelos y estimaciones de `godot/core/taller/sharpening.gd` y `godot/core/taller/sharpening_heat.gd`
(tests en `godot/tests/taller/test_sharpening.gd`). La afiladora dice, para cada herramienta y material, **el
ángulo de afilado, el abrasivo, la progresión de granos, la velocidad de la muela (en m/s y en rpm) y el riesgo
térmico**, y cada dato lleva `source` y `quality` (`primary`, `secondary` o `estimate`).

## Qué calcula

| Función | Qué hace |
|---|---|
| `recommend_sharpening({tool, machine_id, wheel_diameter_mm, rpm, wheel_abrasive_id?, wet?, operation?})` | Recomendación completa: `angles`, `abrasive_id`, `abrasive_reason`, `grits`, `speed_ms`, `speed_range_ms`, `rpm_range`, `over_speed`, `max_speed_ms`, `edge_width_um`, `edge_finish`, `heat`, `warnings`, `sources`, `quality`. `wheel_abrasive_id` es la muela montada, si no es la de serie |
| `knife_angles`, `drill_angles`, `mill_angles` | Los ángulos por separado |
| `choose_abrasive(material_id, hrc)` | Abrasivo y motivo, con la alternativa |
| `grit_progression(kind, machine_id, abrasive_id)` | Pasos de grano (`amolado` o `asentado`) y el filo final esperado |
| `peripheral_speed(d_mm, rpm)` · `rpm_for_speed(v_ms, d_mm)` | v = π·D·n / 60 000 (m/s, con D en mm y n en rpm) |
| `bevel_width(t_mm, β)` | Anchura del bisel: w = (t/2)/sen β |
| `cutter_grinder_offset(α, D)` | Desplazamiento del dedo de apoyo: 0,0088 × α × D (TC 9-524) |
| `cutter_grinder_offset_exact(α, D)` | El mismo sin aproximar: (D/2)·sen α |
| `burr_removal({...})` | Pasadas para arrancar la rebaba con la ley de Archard (`core/shared/abrasion.gd`) |
| `iso8442_verdict(icp_mm, tcc_mm, serrated)` | Aprueba o suspende el ensayo de ISO 8442-5 |
| `sharpening_heat.gd`: `heat_risk({...})`, `hollomon_jaffe`, `hj_temperature`, `hj_time`, `equivalent_temperature`, `equivalent_time`, `temper_equivalent_c`, `temper_threshold_c` | Riesgo térmico relativo y equivalencias tiempo ↔ temperatura del revenido |
| `input_num`, `input_flag` (en `sharpening_heat.gd`) | Leen la entrada sin romper: un número que no lo es o no es finito toma el valor por defecto; `wet` admite bool, 0/1 o «true»/«sí» |

Tablas: `SHARPENING_ANGLES`, `SHARPENING_MACHINES`, `VITRIFIED_MAX_SPEED`, `SPEED_RANGES`, `GRIT_STEPS`,
`EDGE_FINISH`, `ISO_8442_5`, `NOMINAL_OPERATION`, `BURR_WEAR_K`, `TOOL_MATERIALS` y `STEELS`. `STEELS` vive en
`sharpening_heat.gd` y `sharpening.gd` la reexporta. `TOOL_MATERIALS` dice con qué se amola cada herramienta que
no es de acero y por qué no lleva riesgo de revenido.

## Modelos

### Ángulos

- **Cuchillos.** El ángulo total sale del **uso**. En cocina, fileteo y carnicero se cruza además con el intervalo
  por lado de los **fabricantes** del estilo (japonés u occidental). Se recomienda el centro del intervalo,
  redondeado a 0,5°. **El ángulo no se ajusta con la dureza**: no hay una fórmula publicada que relacione el
  ángulo con los HRC, y un test lo vigila.
- **Brocas.** Ángulo de punta por material de la pieza e incidencia por diámetro (Nachi), dentro de los 8–12° de
  TC 9-524. Además se da la arista transversal como comprobación, la forma de DIN 1412 y el tipo de hélice (N, H o W).
- **Fresas.** Incidencia primaria de TC 9-524 según el material (duro o blando) y el tamaño (menos de 3″), y si no
  hay dato, el intervalo general de Nachi (5–9°). Secundaria de Nachi (14–17°), hélice por material (Travers) y
  desplazamiento del dedo de apoyo. Con muela de copa, el diámetro es el de la fresa; con muela recta, el de la
  muela (TC 9-524). La regla 0,0088·α·D es la aproximación de ángulo pequeño de (D/2)·sen α (π/360 = 0,00873,
  redondeado por arriba): con 7° y 25,4 mm da 1,565 mm, frente a 1,548 mm sin aproximar.

### Abrasivo

1. Metal duro → diamante (alternativa: SiC verde).
2. Acero rápido (M2) → CBN (alternativa: Al₂O₃ blanco, WA).
3. Acero de más de 58 HRC → CBN (Kraus & Winter).
4. El resto del acero → Al₂O₃.

**Nunca se recomienda diamante para amolar hierro o acero**, y un test lo recorre con todos los aceros, durezas,
herramientas y máquinas. Se entiende por amolar todo paso que arranca metal con una muela. El asentado en cuero
no cuenta como amolado: casi no arranca metal y se hace a mano o a 1,2 m/s.

### Velocidad de la muela

- v = π·D·n/60 000. `over_speed` compara con la velocidad máxima de una **muela vitrificada** (35 m/s, un
  escalón de EN 12413). Se mira la muela **montada**: la de serie o la que diga `wheel_abrasive_id`. Si la máquina
  no trae ninguna, se mira la convencional que se recomienda. Con 200 mm a 3450 rpm salen 36,1 m/s y hay aviso,
  aunque se recomiende CBN, porque la muela de serie sigue siendo vitrificada. Con CBN o diamante manda la
  velocidad marcada en la muela, y un aviso pide comprobarla.
- La velocidad **recomendada** depende del abrasivo y de si se trabaja en seco o en húmedo (Kraus & Winter para
  CBN y diamante; Nachi para WA y GC). En el Tormek es la de serie de la máquina, 90–100 rpm, con el diámetro
  real de la muela: 1,18–1,31 m/s con 250 mm. Si la muela está gastada, las rpm no cambian y la velocidad baja.
- En la afiladora universal (de velocidad variable) se eligen unas rpm en el centro del intervalo recomendado para
  el diámetro de la muela.

### Riesgo térmico (`sharpening_heat.gd`)

Da un **índice relativo**, no una temperatura. Se basa en Malkin y Guo (2007):

- q = ε·P/A: la fracción ε de la potencia de amolado que entra en la herramienta. ε vale 0,60–0,85 con muelas
  convencionales y ≈0,20 con CBN. P = μ·F·Vs, con μ = Ft/Fn.
- Si la herramienta se barre a la velocidad V, se usa la banda móvil (ec. 2): θmax = 1,595·q·√(α·l)/(k·√V).
  **V es la velocidad del contacto respecto de la herramienta, no la de la muela.** En Malkin y Guo es la de la
  pieza; la de la muela ya entra en P.
- Si la herramienta está quieta, se usa la fuente circular fija sobre un sólido semiinfinito:
  θ = (2q√(αt)/k)·[1/√π − ierfc(a/(2√(αt)))], con a = √(A/π). Crece con √t y tiende a q·a/k. La fórmula está
  comprobada integrando la solución de la fuente puntual instantánea (Carslaw y Jaeger 1959). Barrer nunca
  calienta más que estar quieto, así que se toma el menor de los dos.
- El agua solo enfría por debajo de ≈130 °C: por encima hierve en película. Entonces ε vuelve a su valor en seco.
- Niveles: **bajo** (< 130 °C), **medio** (entre 130 °C y el revenido), **alto** (entre el revenido y 723 °C) y
  **quemado** (≥ 723 °C). El revenido es la temperatura que iguala, en el tiempo de exposición, el parámetro de
  Hollomon–Jaffe del revenido de referencia del acero: P = T·(C + log10 t), con T en K, t en horas y C = 15.
- `index` = subida / (umbral de revenido − 20 °C). Vale 1 al llegar al revenido de ese acero en ese tiempo.
- **Por qué no se da la temperatura del filo.** El modelo es de cuerpo grueso y un filo fino no lo es: se calienta
  más. El campo `note` lo dice. Sirve para comparar máquinas, abrasivos, presión y tiempo.

La recomendación calcula el riesgo con una **operación nominal** (`NOMINAL_OPERATION`), que se puede cambiar con
`operation`. Si la muela de serie de la máquina no es la recomendada, un aviso dice qué nivel tendría con ella.
Por ejemplo, el 14C28N en esmeriladora pasa de «bajo» con CBN a «alto» con Al₂O₃.

## Fuentes verificadas

Todas se consultaron el 25-9-2026. «Leída» quiere decir que se abrió el documento y se comprobó el dato en él.
«Vía buscador» quiere decir que el dato viene de la ficha del fabricante tal como la muestra el buscador, porque
la página devolvía 403.

| Dato | Valor en el código | Fuente | Calidad | Comprobación |
|---|---|---|---|---|
| Ángulos por lado de los fabricantes | Wüsthof 14° y asiáticos 10°; Zwilling ≈15° y santoku, Miyabi y Kramer 9–12°; Global y MAC 10–15°; Shun y Kai 16°; Victorinox 15–20°; Messermeister 15°; Fischer-Bargoin 15–20° | [Tormek, *Knife sharpening angles. Manufacturer's recommendations*](https://tormek.com/download/18.73cc6d0e182e93109963f09/1662026307305/tormek-knife-sharpening-angles-manufacturer-s-recommendations.pdf) | secondary (recopilación) | leída |
| Ángulo total por uso | cocina occidental y carnicero 30–40°; cocina japonesa 25–30°; fileteo, loncheado y pelado 25–30°; caza y deportivos 30–40°; talla 20–25° | [Tormek, *Knife sharpening*](https://tormek.com/en/knowledge/how-to-sharpen-your-tools/knife-sharpening) | primary | leída |
| Ángulos medidos | navajas de afeitar 15–19°; cocina y fileteo 20–30°; cúter 30°; picar 30–60° (cita a Leonard) | [Verhoeven 2004, *Experiments on knife sharpening*, tabla 1](https://northarmknives.com/wp-content/uploads/2016/01/knifeshexps.pdf) | primary (picar: secondary) | leída |
| Bisturí | ≈26° en total | [Patente US 6330750 B1](https://patents.google.com/patent/US6330750B1/en) | secondary | leída |
| Hacha | 25–30° | [Gränsfors Bruk, *The Axe Book*](https://snakeroot.net/MTCA/wp-content/uploads/TheAxeBook.pdf) y [su guía de afilado](https://www.gransforsbruk.com/en/the-axe-guide/axe-care/resharpening) | primary | leída |
| Punta de broca | 118° de uso general; incidencia 8–12°; arista transversal a ≈45° de la línea de los filos | [US Army TC 9-524, cap. 4](https://uhv.cheme.cmu.edu/procedures/machining/ch4.pdf) | primary | leída |
| Punta por material | 118° la mayoría; 130° blandos y tenaces; 140° ligeros de viruta larga; 90° plásticos duros que desgastan | [CERATIZIT, *Drill geometry*](https://cuttingtools.ceratizit.com/us/en/machining-know-how/holemaking-and-boring/application-and-technical-info/drill-geometry.html) | primary | leída |
| Inoxidable | 135° (metal duro o HSS de tipo H) | [Gühring, *Welche Bohrer für Edelstahl?*](https://guehring.com/faq/bohrer-welche-bohrer-fuer-edelstahl/) | primary | leída |
| Inoxidable | 140° | [Modern Machine Shop, *Choosing the best drill point geometry*](https://www.mmsonline.com/articles/choose-the-best-drill-point-geometry) | secondary | leída |
| Broca: duros e incidencia por diámetro | 118° general y 135° en duros o corte rápido; incidencia 12°, 10° y 8° para Ø 2–5, 5,1–13 y 13,1–20 mm; secundaria 20°; bolsillo del adelgazado 105–110° | [Nachi, datos técnicos](https://www.bmwsb.com.my/image/data/nachi.pdf) | primary | leída |
| Arista transversal | 120–135° | [Patente US 4023552 A](https://patents.google.com/patent/US4023552A/en) | primary | leída |
| 135° con afilado en cruz; hélices | H 10–19° (latón), N 19–27° (acero), W 27–45° (aluminio, cobre) | [GSR, *Handbuch Bohren*](https://www.gewindewerkzeuge.com/mf_GSR/CustomUpload/374O357O340O370O356O369O350O326O372O370O371O352O373O338O371O372O369O370O353O356O369O358O326O364O353O327O/gsr-handbuch-bohren.pdf) | primary | leída |
| Formas de DIN 1412 | normal, A, B, C (en cruz), D (fundición) y E (centrar) | [RUKO](https://ruko.de/de/blog/spitzenanschliffe-und-ausspitzungen); [Wikipedia (de), *Spiralbohrer*](https://de.wikipedia.org/wiki/Spiralbohrer) (ψ ≈ 55°) | secondary | leída |
| Fresas: incidencia y hélice | primaria 5–9°, secundaria 14–17°; hélice baja 10–20° (≥35 HRC), normal 28–30°, alta ≥40° | [Nachi America, *End mill training*](https://www.nachiamerica.com/content/training/End%20Mill%20Basic%20Training.pdf) | primary | leída |
| Fresas: TC 9-524 | primaria 3–5° en duros y ≈10° en blandos (7° y 12° por debajo de 3″); secundaria 20–30°; desplazamiento 0,0088 × α × D (ejemplo: 0,0088 × 5 × 6 = 0,264″) | [US Army TC 9-524, cap. 5](https://uhv.cheme.cmu.edu/procedures/machining/ch5.pdf) | primary | leída |
| Hélice por material | 0° latón, cobre, bronce y plásticos abrasivos; 30° aceros y fundición; 35–40° inoxidables; 37–45° aluminio, cobre y plásticos | [Travers Tool](https://solutions.travers.com/metalworking-machining/milling/the-pros-cons-of-high-and-low-helix-angles) | secondary | leída |
| Tormek T-8 | SG-250 de 250 × 50 mm a 100 rpm, 200 W | [Tormek T-8 Original](https://tormek.com/en/products/sharpening-machines/tormek-t-8-original) | primary | leída |
| Tormek a 90 rpm | T-8 anterior y el de Verhoeven | [Verhoeven 2004, § 5](https://northarmknives.com/wp-content/uploads/2016/01/knifeshexps.pdf); [Woodworking Shop](https://www.woodworkingshop.com/product/TM88888/) | primary | leída / vía buscador |
| Muelas Tormek | SG-250 de Al₂O₃, de grano 220 a ≈1000 con el SP-650; SJ-250 de grano 4000 | [Tormek SG-250](https://tormek.com/en/products/grinding-wheels/original-grindstones/sg-250-original-grindstone); Verhoeven 2004 (SJ de 4000) | primary | leída |
| Esmeriladoras | 150 y 200 mm a 2980 rpm en vacío (50 Hz) | [Metabo DS 200 Plus](https://www.metabo.com/com/en/tools/cutting-sanding-milling/metal-processing/bench-grinders/ds-200-plus-bench-grinder/604200000); Metabo DS 150 M | primary | leída / vía buscador |
| Esmeriladoras a 60 Hz | 3450 rpm; muela de 7″ ≈ 6300 SFPM; vitrificadas hasta 6500 SFPM (33 m/s); una muela gruesa y otra fina | [US Army TC 9-524, cap. 5](https://uhv.cheme.cmu.edu/procedures/machining/ch5.pdf) | primary | leída |
| Máximo de una muela vitrificada | 200 mm: 35 m/s y 3350 rpm | [WMW Niles (pwwu24)](https://www.pwwu24.de/schleifscheibe-200-x-25-x-32-fuer-schleifbock); escalones de EN 12413 ([Klingspor](https://www.klingspor.de/en/lowdown-on-grinding/maximum-operating-speed)) | primary | leída / vía buscador |
| Norton de 8″ | 3600 rpm como máximo (≈38 m/s) | Norton 38A (fichas de distribuidor) | secondary | vía buscador |
| CBN y diamante | CBN en aceros aleados de más de 58 HRC; afilado de herramientas con resina: CBN 25–35 m/s en húmedo y 16–28 en seco; diamante 25–30 en húmedo y 16–22 en seco; copas 11V9 de 75, 100 y 125 mm | [Kraus & Winter, catálogo 2018](https://www.kraus-und-winter.de/media/products/0992847001541601996.2018.pdf) | primary | leída |
| CBN y diamante | diamante para metal duro, cerámica, vidrio y cermet; CBN para HSS, aceros de herramientas y templados; resina 15–35 m/s (óptimo 25–28); tabla FEPA de granos | [Haefeli, manual técnico](https://www.haefeli.swiss/images/PDF/haefeli1d.pdf) | primary | leída |
| Muelas para reafilar fresas | HSS al Co: WA60 J/K a 3800–5000 SFPM (19,3–25,4 m/s); HSS al Co-V: CBN 120–220; metal duro: diamante D100 (desbaste) y D150–180 (acabado) o GC, a 2600–3300 SFPM (13,2–16,8 m/s) | [Nachi, datos técnicos](https://www.bmwsb.com.my/image/data/nachi.pdf) | primary | leída |
| Al₂O₃ y SiC | 38A para aceros rápidos y de herramientas templados y para afilar brocas; 37C para fundición, metal duro y no férricos; 39C para no férricos y metal duro | Norton (fichas de 38A, 37C y 39C) | primary | vía buscador |
| Reparto de energía y umbrales | ε = 60–85 % con muelas convencionales y ≈20 % con CBN; ec. 2 de la banda móvil; ebullición en película a ≈130 °C (acuoso) y 300–350 °C (aceite); quemado ≈ eutectoide de 723 °C; ejemplo de grano único con CBN (36,5 % → 15,5 %) | [Malkin y Guo 2007, CIRP Annals 56/2](http://static-content.springer.com/esm/art:10.1007%2Fs00170-011-3706-7/MediaObjects/170_2011_3706_MOESM38_ESM.pdf) | primary | leída |
| Reparto con Al₂O₃ y CBN | 60–75 % con Al₂O₃ y ≈20 % con CBN | [Kohli, Guo y Malkin 1995, J. Manuf. Sci. Eng. 117](https://asmedigitalcollection.asme.org/manufacturingscience/article-abstract/117/2/160/392634/) | secondary | vía buscador (resumen) |
| Diamante y hierro | se oxida por encima de 600 °C y reacciona con el hierro por encima de 700 °C | [Brazda (KAPP), *Hard choices: diamond or CBN?*, Gear Solutions, 1-2-2006](https://gearsolutions.com/features/hard-choices-diamond-or-cbn/) | secondary | leída |
| Diamante y hierro | la grafitización en contacto con hierro empieza hacia 400 °C | [Zenkin et al. 2018, Materials](https://pmc.ncbi.nlm.nih.gov/articles/PMC6316921/) | primary | leída |
| VG-10 | 61 HRC; revenido a 150–250 °C, mínimo 120 min a 150 °C | [Takefu, ficha de VG10](https://www.barmondsheffield.com/wp-content/uploads/2022/07/%E7%86%B1%E5%87%A6%E7%90%86VG10.pdf) | primary | leída |
| 1.4116 | 56 HRC; 30,0 W/(m·K), 7,7 g/cm³ y 0,46 J/(g·K); diagrama de revenido de 1 h | [SIJ Metal Ravne, SINOXX 4116](https://steelselector.sij.si/data/pdf/PK5.pdf) | primary | leída (diagrama leído en la imagen) |
| 14C28N | revenido de 30 min: 61 → 55,5 HRC; 7,7 g/cm³ | [Alleima, ficha de 14C28N](https://www.alleima.com/contentassets/7a282aed5b6c477596d85f22176b2078/datasheet-alleima-14c28n-en-v2024-01-11-1029-version-1.pdf/download) | primary | leída |
| 14C28N | revenido de 2 h: 175 °C → 59 HRC; 225 °C → 57; 350 °C → 55 | [Alleima, guía de temple](https://www.alleima.com/en/products/strip-steel/knife-steel/hardening-guide/hardening-programs/alleima-14c28n-piece-hardening/) | primary | leída |
| M2 | revenido a 550–570 °C, ≥ 2 h, 3 ciclos; mínimo 62 HRC (64–67 en el diagrama); 8,07 kg/dm³, 21,8 W/(m·K) y 0,433 kJ/(kg·K) | [Böhler S600](https://www.us.bohler.com/app/uploads/sites/248/productdb/api/s600_en_us.pdf) | primary | leída |
| 1095 | 2 × 2 h: 177 °C → 63–64 HRC; 204 °C → 60–61; 232 °C → 57–58 | [New Jersey Steel Baron](https://cdn.newjerseysteelbaron.com/wp-content/uploads/2020/07/1095-Heat-Treat-7-20.pdf) (basada en ASM y Crucible); [Knife Steel Nerds](https://knifesteelnerds.com/2020/02/17/ranking-toughness-of-forging-knife-steels/) | secondary | leída |
| 1095 (1.1274) | 49 W/(m·K) a 20 °C, 7,9 g/cm³ y 460 J/(kg·K) | [HS-Folien, ficha técnica](https://hs-folien.shop/en/Technical-information/Technical-information-sheets/1.1274-C100S/) | secondary | leída |
| Hollomon–Jaffe | P = T·(C + log t); c = 12,2 con t en s (≈15,8 en h) en el acero W de 0,89 % C; c varía con la dureza | [Thomas, Speer, Matlock, Krauss y Hackenberg, ICOMAT-08 (TMS 2009)](https://wpfiles.mines.edu/wp-content/uploads/aspprc/ResearchMaterials/Publications/445-Thomas.pdf) | secondary (C = 15: estimate) | leída |
| ISO 8442-5 | 50 N, carrera de 40 mm, 50 mm/s, cartulina con 5 % de sílice | [CATRA, *Automatic Edge Tester*](https://www.catra.org/testing-equipment/knife-edges/aet/) | secondary | leída |
| ISO 8442-5 | 60 ciclos; ICP (3 primeros) ≥ 50 mm; TCC ≥ 150 mm en filo liso; dentado: 200 ciclos y 1500 mm | [Arcos, *Ensayos de corte*](https://blog.arcos.com/en/arcos-cutting-tests-how-to-know-if-a-knife-really-cuts-well-and-lasts/) | secondary | leída |
| Filo final | diamante de 1 µm en cuero 0,31 ± 0,06 µm; piedra de agua del Tormek y cuero con óxido de cromo ≈0,35; piedra de 6000 y cuero 0,4–0,5; piedras de 6000–8000 ≈0,5; grano 220 y cuero ≈0,8; grano 1000 1–1,5; chaira tras 600 1,5–2; grano 600 2–3; grano 200 2–4; hoja Gillette 0,35–0,45 | [Verhoeven 2004](https://northarmknives.com/wp-content/uploads/2016/01/knifeshexps.pdf) | primary | leída |
| Fuerzas de amolado | μ = Ft/Fn de 0,25 a 0,40 en la mayoría de aceros; P = Ft·Vs | [Biro, Hagan y Gustafson (Saint-Gobain), SME 2019](https://www.sme.org/globalassets/sme.org/technologies/articles/2019/02---february/understanding-forces-in-creepfeed-grinding.pdf) | secondary | leída |
| Muelas de CBN para el T-8 | 250 mm, granos de 80 a 1000, en agua | [Forever Superabrasives](https://biz.forever-superabrasives.com/products/cbn-wheel-for-tormek-250mm-12mm-arbor-grit-400-1000) y otros | secondary | vía buscador |

## Datos del encargo que no se confirmaron

| Dato del encargo | Qué dicen las fuentes | Qué hace el código |
|---|---|---|
| Arista transversal ≈110° | 120–135° (US 4023552 A); TC 9-524: ≈45° desde la línea de los filos, es decir, 135°; en DIN, ψ ≈ 55° (125°). El 105–110° es el bolsillo del adelgazado (Nachi) | 120–135° (125° recomendado) y el bolsillo aparte |
| Hacha 25–40° | Gränsfors: 25–30° | 25–30° |
| Carnicero 30–60° | Tormek pone los de carnicero con los occidentales de cocina (30–40°). El 30–60° es de los cuchillos de picar en Verhoeven (cita a Leonard) | «carnicero» 30–40° y «cuchilla» (picar) 30–60° |
| Esmeriladora a 2850 rpm | Metabo: 2980 rpm en vacío a 50 Hz; TC 9-524: 3450 rpm a 60 Hz. No encontré una ficha con 2850 rpm | 2980–3450 rpm |
| 1.4116 estable hasta ≈190 °C y ≈55 HRC a 225 °C (Ugitech) | La ficha de Ugitech no se pudo abrir (redirige al centro de descargas de Swiss Steel). En el diagrama de SIJ (1 h), la dureza baja de forma continua desde ≈100 °C, y a 225 °C está en la banda de ≈52–57 HRC | revenido de referencia de 150 °C × 1 h, marcado como estimación |
| «Brazda 2006» | Es Pavel Brazda (KAPP Technologies), *Hard choices: diamond or CBN?*, Gear Solutions, 1-2-2006 | citado así |

## Estimaciones (`quality: "estimate"`)

| Dato | Valor | Por qué |
|---|---|---|
| Fuerza de la mano al afilar | 10 N | No hay medición publicada: es una presión ligera (≈1 kgf) |
| Área de contacto | 10 mm² | ≈1 mm de bisel por 10 mm de filo |
| Velocidad de barrido | 0,025 m/s | Verhoeven pasaba la hoja a ≈1″/s por la rueda del Tormek |
| Tiempo seguido sobre la muela | 5 s | Supuesto de operación |
| Temperatura inicial | 20 °C | Supuesto del modelo |
| Factor del agua sobre ε | 0,42 | Sale del ejemplo de grano único de Malkin y Guo con CBN (36,5 % → 15,5 %) |
| ε con SiC y con diamante | 0,725 y 0,20 | Sin medición propia: como las muelas convencionales y como el CBN |
| C de Hollomon–Jaffe | 15 (t en horas) | c = 12,2 en segundos (≈15,8 en horas) para 0,89 % C; c varía con la dureza |
| Propiedades térmicas de VG-10 y 14C28N | las del 1.4116 (30 W/(m·K); 7700 kg/m³; 460 J/(kg·K)) | Takefu y Alleima no publican k ni cp |
| Revenido de referencia del 1.4116 | 150 °C × 1 h | No hay temperatura de revenido de fábrica para cuchillos |
| Grano de la muela fina de esmeriladora | 80–120 | TC 9-524 dice «muela fina» sin número |
| k de Archard de la rebaba | 1·10⁻³ | No hay medición para rebabas de afilado |

## Límites

- El índice térmico es **relativo**. No da la temperatura del filo, y tampoco cuenta el calentamiento de toda la
  hoja tras muchas pasadas.
- La ecuación 2 de Malkin y Guo es para una banda infinita y vale con Péclet > 1. Con barridos lentos manda la
  fuente quieta.
- Hollomon–Jaffe es una aproximación: c cambia con la dureza (Thomas et al.). En los aceros rápidos, el umbral
  sale por encima de 723 °C y el tope es el quemado.
- El metal duro no se reviene. Su riesgo es la fisuración por calor, que no se calcula (`heat = null` y un aviso).
- El número de pasadas de `burr_removal` es una cota superior: la rebaba también se dobla y se rompe, no solo se
  desgasta.

## Para el coordinador

1. **`heat_risk.speed_ms` es la velocidad de barrido** del contacto sobre la herramienta (la V de Malkin y Guo).
   No es la periférica de la muela: esa entra en la potencia, P = μ·F·Vs. Si alguna unidad pensaba pasar la
   velocidad de la muela, tiene que pasar la potencia y la de barrido.
2. **`STEELS` vive en `sharpening_heat.gd`** y `sharpening.gd` la reexporta (`const STEELS := Heat.STEELS`).
   Así no hay precargas circulares.
3. **Material de la herramienta.** `tool.steel_id` admite, además de los cinco aceros, `"metal_duro"`
   (`TOOL_MATERIALS`). Propongo añadirlo a las claves de unión de CONTRATOS.md como material de herramienta.
   Con metal duro en el Tormek, los granos son los de la afiladora universal (no hay muelas de diamante con
   fuente para la máquina lenta) y no se da anchura de filo, porque Verhoeven midió filos de acero.
4. **Dureza en HRC.** CONTRATOS.md pide la dureza en MPa (HV como etiqueta). Aquí la dureza de los aceros se guarda
   y se recibe en HRC, que es como la publican los fabricantes y como está la regla de Kraus & Winter (CBN por
   encima de 58 HRC); no entra en ningún cálculo físico. Pasarla a HV o MPa exige la tabla de conversión de
   ASTM E140, que no he verificado en esta unidad. `burr_removal` pide la dureza en MPa. Si hace falta, propongo
   poner la conversión ASTM E140 (HRC → HV) en `core/shared` y añadir `hardness_mpa` a `STEELS`.
5. **Materiales de la pieza.** Se usan las claves de CONTRATOS.md (acero, inox, fundicion, aluminio, laton,
   plastico…) y dos más: `acero_duro` (135° de punta; 7° en fresa) y `blando_tenaz` (130°, CERATIZIT). Si el
   catálogo de materiales de la unidad de corte da la dureza, `acero_duro` se podría deducir de ella.
6. **Unidad 6 (abrasivos).** Solo se usan los ids. El reparto ε de cada abrasivo (`ENERGY_PARTITION`) y los
   intervalos de velocidad (`SPEED_RANGES`) podrían ir en su catálogo; si allí hay otros valores, conviene
   unificarlos.
7. **Sonido.** La recomendación devuelve `machine.rpm` y `machine.wet` para la entrada de sonido
   `process: "sharpener"`.
8. Godot generó `.uid` para los tres scripts nuevos y se versionan, como los de `core/shared`.
9. gdlint (orientativo): además de las líneas de más de 100 caracteres (lo mismo pasa en `core/shared`), marca que
   `sharpening.gd` supera las 1000 líneas, casi todo tablas con fuente, y que el test tiene más de 20 métodos
   públicos.
