# Taller · unidad 5: corte, catálogos, plano e inspección

Fuentes, modelos y estimaciones de `godot/core/taller/{work_materials, tool_materials, cutting, drawing,
inspection}.gd`. Tests: `godot/tests/taller/test_cutting.gd` y `test_drawing.gd` (38 tests).

Reglas de siempre: cada dato lleva `source` y `quality` (`primary` · `secondary` · `estimate`); lo que no tiene
medición publicada es **estimación**, en el dato y en la tabla de estimaciones de abajo. Si un caso publicado no
sale con la fuente principal, se documenta la discrepancia; no se ajustan números.

- **primary:** el valor exacto de ese material, herramienta o norma en la fuente de referencia (Tabellenbuch, la
  propia norma, la ficha del fabricante de ese producto).
- **secondary:** otra fuente seria o un valor que no es específico del objeto (valor de grupo, aleación vecina,
  norma leída a través de una ficha de distribuidor).
- **estimate:** derivado o supuesto por nosotros (conversiones de dureza, interpolaciones, valores típicos sin
  ficha consultada).

## 1. Fuentes y qué sale de cada una

| Fuente | Qué datos | Acceso |
|---|---|---|
| **Tabellenbuch Zerspantechnik**, 1.ª ed., Europa-Lehrmittel, 2015 (ISBN 978-3-8085-1473-3) — **TZ** | kc1.1 y mc (pp. 207, 209, 210); kf1.1, mf, kp1.1, mp y la regla kf1.1 ≈ kc1.1/5, kp1.1 ≈ kc1.1/6 (p. 211); Kγ, γ0, Kvc, Kver, Ksp y el ejemplo de 4011 N/mm² (p. 208); h = f·sen κ, b = ap/sen κ (p. 202); Qw = ap·f·vc (p. 203); Pc = Fc·vc, el ejemplo de 8,4 kW, η = 0,7-0,85 y las tablas de potencia orientativas (p. 212); pendientes de Taylor y vcT15 (p. 215) | [extracto oficial pp. 199-215](https://beckassets.blob.core.windows.net/product/readingsample/15052006/9783808514733_excerpt_004.pdf) |
| Sandvik Coromant, *Metalcutting Technical Guide (D) Milling*, 2005 | hm, Pc, Mγ = 1 − γ/100 (pp. D23-D25); el caso publicado de 27,0 → 21,3 kW (p. D25); tabla de la constante K por grupo CMC, calculada con ηmt = 0,8 (p. D26) | [PDF](https://dcngli4g50fhp.cloudfront.net/userfiles/ad/sandvik/documents/sandvik_5747275_catalog.pdf) |
| Sandvik Coromant, fórmulas de taladrado | Pc = fn·vc·Dc·kc/240 000; Mc = Pc·30 000/(π·n); Ff ≈ 0,5·kc·(Dc/2)·fn·sen κr | [web](https://www.sandvik.coromant.com/en-gb/knowledge/machining-formulas-definitions/drilling-formulas-definitions) |
| Sandvik Coromant, *Hard part turning 2019* (C-2900-24) | vc de los CBN CB7105-CB7135 en acero templado (80-250 m/min) | [PDF](https://coromantstrgprod.blob.core.windows.net/files/sitecollectiondocuments/downloads/global/catalogues/en-us/c-2900-24.pdf) |
| ISO 286-2:2010 (tabla 1, tomada de ISO 286-1:2010; figura 2) | IT6-IT11 hasta 120 mm; desviaciones h (es = 0, ei = −IT) y js (±IT/2) | [vista previa oficial](https://cdn.standards.iteh.ai/samples/54915/7d6147c29fed4e31af36b60561e88752/ISO-286-2-2010.pdf) |
| ISO 513:2012 (tablas 1-5) | grupos P M K N S H, sus colores y los códigos HW, HC, HT, CA, CN, BH, DP | [vista previa oficial](https://cdn.standards.iteh.ai/samples/59932/d271ad516f744c8ca6782f6b4772bf87/ISO-513-2012.pdf) |
| ISO 2768-1:1989 (tablas 1 y 2), vía AmesWeb | tolerancias generales de longitudes, radios y chaflanes (clases f, m, c, v) | [AmesWeb](https://amesweb.info/fits-tolerances/iso-2768-linear-dimensions-tolerances.aspx) |
| EN 10083-2:2006 (tabla 9) y EN 10083-3:2006 (tabla 8) | Rm de C45E +N y de 42CrMo4 +QT según el diámetro | norma consultada |
| thyssenkrupp Steel, información de producto S235JR | Rm 360-510 MPa, ReH ≥ 235 MPa (JR de EN 10025-2) | [PDF](https://www.thyssenkrupp-steel.com/media/content_1/publikationen/precision_steel/produktinformationen_1/baustahl/thyssenkrupp_s235jr_product_information_precision_steel_en.pdf) |
| SteelNumber (EN 10084:2008) | dureza de 16MnCr5 +FP: 140-187 HBW | [web](http://www.steelnumber.com/en/steel_composition_eu.php?name_id=229) |
| Deutsche Edelstahlwerke, ficha 1.4301 (2007) | X5CrNi18-10: 7,90 kg/dm³, Rm 500-700 (típ. 660), ≤ 215 HB (típ. 195); vc con metal duro recubierto 120/150/200 m/min | [PDF](https://swisssteel-group.com/content-media/documents/Data-Sheets/Stainless-Steel/Datenblatt_4301_UK.pdf) |
| NovaCast, ficha EN-GJL-250 | Rm 250-350 MPa | [PDF](https://www.novacast.co.uk/wp-content/uploads/2016/08/Cast-Iron-EN-GJL-250.pdf) |
| Aalco, ficha 6082-T6 (EN 755-2:2008) | barra de 20 a 150 mm: Rp0,2 ≥ 260, Rm ≥ 310 MPa, 95 HB; 2,70 g/cm³ | [web](https://www.aalco.co.uk/datasheets/Aluminium-Alloy-6082-T6-Extrusions_338.ashx) |
| Deutsches Kupferinstitut, ficha CuZn39Pb3 (2005) | 8,47 g/cm³; varilla R430 (Ø 2-40, EN 12164): Rm ≥ 430 MPa, ≈ 120 HB/HV | [PDF](https://kupfer.de/wp-content/uploads/2019/11/CuZn39Pb3-1.pdf) |
| ATI, ficha Ti-6Al-4V grado 5 (2012) | 0,160 lb/in³ (= 4,43 g/cm³) y 30-34 HRC recocido | [PDF](https://www.atimaterials.com/Products/Documents/datasheets/titanium/alloyed/ati_6-4_tds_en_v1.pdf) |
| United Performance Metals, ficha aleación 718 | envejecido: 8,22 g/cm³, Rm ≥ 1240 MPa | [PDF](https://www.upmet.com/sites/default/files/datasheets/718.pdf) |
| The Wood Database, *Scots pine* | 550 kg/m³, Janka 2420 N, MOR 83,3 MPa (la misma fuente que el laboratorio) | [web](https://www.wood-database.com/scots-pine/) |
| voestalpine BÖHLER, fichas S600 y S500 | curvas de revenido: M2 64-66 HRC, M42 ≈ 68-69 HRC; revenido a 550-570 °C | [S600](https://www.bohler-edelstahl.com/app/uploads/sites/248/productdb/api/s600_en_gb.pdf) · [S500](https://www.bohler-edelstahl.com/app/uploads/sites/248/productdb/api/s500_en_gb.pdf) |
| ASTM E140 (tabla 1) | conversión HRC → HV (65 HRC = 832 HV; 68 HRC = 940 HV) | norma |
| Oerlikon Balzers, folleto corporativo 2007 | TiN, TiCN, TiAlN, AlCrN y DLC: HV 0,05, T máx. de servicio, color, μ; diamante CVD: 600 °C | folleto del fabricante |
| Speiser E., «Understanding hardness», *Cutting Tool Engineering* 77(5), 2025 | metal duro 1300-2000 HV; cerámica 2100-2500 HV; CBN ≈ 4500 HV; PCD hasta 6000 HV | [web](https://ctemag.com/articles/understanding-hardness/) |
| EN 1993-1-1, 3.2.6 | densidad de cálculo del acero, 7850 kg/m³ | norma |
| ISO 4288:1996, 5.2 | regla del 16 % para los límites de rugosidad | norma |

## 2. Modelo de corte (`cutting.gd`)

**Fuerza específica** (TZ, pp. 206-208):

`kc = kc1.1 / h^mc · Kγ · Kvc · Kver · Ksp`

| Factor | Valor | Fuente |
|---|---|---|
| h | torneado `f·sen κ`; fresado `hm` (espesor medio); taladrado `(f/2)·sen(σ/2)` | TZ p. 202; Sandvik |
| Kγ | `1 − (γ − γ0)/100`; γ0 = +6° acero (y demás metales, supuesto), +2° fundición | TZ p. 208 |
| Kvc | HSS 1,2 · metal duro y cermet 1,0 · cerámica, CBN y PCD 0,85 | TZ p. 208 (cermet, CBN y PCD: estimación) |
| Kver | nuevo 1,0 · ligero 1,2 · medio 1,35 · fuerte 1,5 | TZ p. 208 (1,2-1,5); «medio» interpolado |
| Ksp | exterior 1,0 · cepillado/brochado 1,1 · taladrado, fresado, interior 1,2 · tronzado, ranurado 1,3 | TZ p. 208 |

- Por defecto γ = γ0 del material (Kγ = 1), κ = 90°, rε = 0,8 mm, filo nuevo y η = 0,8.
- Las tablas del TZ van de h = 0,06 a 1,6 mm: fuera, kc se extrapola y se avisa. Por debajo de h = 0,01 mm se
  calcula kc con 0,01 (la ley de potencias se dispara); la fuerza sigue siendo kc·b·h y tiende a 0.
- **Banda de incertidumbre:** kc con todas las familias del material a la vez (la principal, las alternativas del
  propio TZ y una familia derivada de Sandvik), con las mismas correcciones. La familia de Sandvik sale de su
  tabla de K: `kc = 600·η·K` con η = 0,8 (nota de la tabla) y `hm` de una fresa centrada de κ = 45° con
  ae/Dc = 0,8 (supuesto: la fresa del ejemplo de la guía), ajustando `kc = kc1·hm^−mc` en log-log. Es solo para
  la banda: **una sola familia de kc por material** (la del TZ) alimenta el cálculo.
- **Ff y Fp:** `Ff = A·kf1.1/h^mf`, `Fp = A·kp1.1/h^mp` con la tabla del TZ (p. 211) cuando da ese material o uno
  vecino (marcado `secondary`). Si no, la regla del TZ «en aceros de resistencia media kf1.1 ≈ kc1.1/5 y
  kp1.1 ≈ kc1.1/6» con los exponentes medianos de esa tabla (mf = 0,70, mp = 0,48): estimación. Sin corregir por
  γ, vc ni desgaste (el TZ no da correcciones para ellas).
- **Potencia y par:** `Pc = Fc·vc/60 000` (kW), motor `Pc/η`; par `Fc·d/2000` (N·m); caudal `Qw = ap·f·vc` (cm³/min).
- **Fresado:** `hm = fz·sen κ·(cos φ1 − cos φ2)/(φ2 − φ1)` con los ángulos de contacto exactos; para la fresa
  centrada es la fórmula de Sandvik `fz·sen κ·(ae/Dc)/asen(ae/Dc)`; en fresado lateral desde un borde se usa
  `φ2 = acos(1 − 2·ae/Dc)`. `Pc = ap·ae·vf·kc/(60·10⁶)`, `Mc = Pc·30 000/(π·n)`, frecuencia de diente `z·n/60`.
- **Taladrado:** broca de dos filos, cada uno con `A = D·f/4` a D/4 del eje: `Pc = fn·vc·D·kc/240 000` y
  `Mc = Pc·30 000/(π·n)` (Sandvik), empuje `Ff ≈ 0,5·kc·(D/2)·f·sen κr` (Sandvik). σ = 118° (TZ, p. 212).
- **Rugosidad teórica** (cota ideal, solo la huella del radio de punta): `Rt = f²/(8·rε)` y
  `Ra = f²/(18·√3·rε)`, la media exacta del perfil parabólico, que la bibliografía redondea a `f²/(32·rε)`
  (diferencia del 2,6 %). Deja de valer si f > rε (se avisa).
- **Vida (Taylor, estimación):** `vc·T^n = C`, `T = (C/vc)^(1/n)`. n = −1/k con la pendiente k del TZ (p. 215):
  HSS en acero 1/7; metal duro en acero 0,25, en fundición 1/3,5, en aluminio 0,4; cerámica en acero 0,5. C no es
  una propiedad del material de corte: se toma el centro del intervalo de vc como vcT15 y `C = vcT15·15^n`.
- **Modelo inyectable en el torno:** `cutting_model(work_id, tool_id, h_mm, b_mm, vc) -> { kc, fc_n, ff_n,
  fp_n, ok, vc_ok, quality }` con filo nuevo, γ0 y torneado exterior. `model_callable()` devuelve el `Callable`.
  Guarda en memoria los datos de cada pareja material-herramienta (los catálogos son constantes). Sin kc
  (madera, plásticos, vidrio, piedra) devuelve fuerzas **0 finitas** con `ok = false` y `reason`: nada de NaN
  que se cuele en las potencias del torno o en el sonido.
- **Calidad del resultado:** la peor entre la de kc1.1 y mc, la de Kvc, la de Kver («medio» es una
  interpolación: estimación) y la de γ0 cuando γ ≠ γ0 en materiales que no son acero ni fundición (el TZ solo
  da γ0 para esos dos: en el resto es un supuesto).
- **Entradas raras:** `machine = null` equivale a no dar máquina; los nombres de desgaste y de proceso no
  distinguen mayúsculas y, si no se conocen, avisan y usan el filo nuevo o el proceso por defecto; sin velocidad
  (o con giro ≤ 0) no se calculan fuerzas ni potencias y se avisa.

## 3. Casos publicados

| Caso | Fuente | Resultado | |
|---|---|---|---|
| kc del 42CrMo4 con h = 0,2, γ = 18°, metal duro y desgaste ligero | TZ, p. 208 | `2500/0,2^0,26 = 3799` (valor de tabla) · Kγ 0,88 · Kvc 1,0 · Kver 1,2 · Ksp 1,0 = **4011,8 N/mm²** (publicado 4011) | **OK** |
| Pc con Fc = 2800 N y vc = 180 m/min | TZ, p. 212 | 2800 · 180 / 60 = **8400 W = 8,4 kW** | **OK** |
| Planeado a 45° de acero CMC 01.3: Dc 125, ap 5, ae 100, fz 0,2, vf 1000; +21° de desprendimiento | Sandvik 2005, p. D25 | `Pc = ap·ae·vf·K/100 000` con K = 5,4 → **27,0 kW**; ×Mγ 0,79 → **21,3 kW** | **OK** |

Además, cada fila de las tablas del TZ que usa el catálogo se reproduce a h = 0,2 (y la fila completa del
42CrMo4 de h = 0,06 a 1,6 mm) con un error menor que el redondeo del libro.

**El 27,0 kW de Sandvik es potencia en el motor.** La tabla de K lleva la nota «calculated with an efficiency
ηmt = 0.8», así que el kc neto del caso es 600 · 0,8 · 5,4 = **2592 N/mm²** y la potencia neta en el filo, 21,6 kW.
El test lo comprueba así (η = 0,8, `pmotor_kw` = 27,0 y 21,3; `pc_kw` = 21,6).

## 4. Discrepancias encontradas (documentadas, sin ajustar números)

1. **Fresado: Tabellenbuch frente a Sandvik.** El mismo caso de la p. D25 con la familia del TZ (C60E, el acero de
   la tabla con C 0,55-0,80 %, 2130/0,18; hm = 0,1220 mm; γ = 0°) da kc = 3297 N/mm² sin Ksp y 3957 con el
   Ksp = 1,2 que el TZ manda para el fresado: 27,5 y 33,0 kW netos (34,3 y 41,2 kW en el motor), un **+27 % y un
   +53 %** sobre Sandvik (21,6 kW netos). Es la dispersión entre fuentes que ya advertía el encargo (~45 %); la
   banda de kc del modelo la enseña. El modelo sigue al TZ (fuente principal); el caso publicado se reproduce con
   el kc de Sandvik.
2. **C45E tiene dos filas en el TZ:** 1850/0,14 (tabla 1, p. 209) y 2200/0,14 (p. 211, con kf y kp; la misma del
   ejemplo resuelto de la p. 205). Se usa la segunda porque es la familia completa; la primera va a la banda.
3. **Errata en el ejemplo de la p. 205 del TZ:** imprime `Fc = A·kc = 2756 N`, pero 2756 es kc (N/mm²); con
   A = 0,84 mm², Fc = 2315 N (y Fp = 520 N, Ff = 1006 N, no 619 y 1198). El modelo no usa ese ejemplo.
4. **«Ff ≈ kc/5 y Fp ≈ kc/6».** El TZ lo dice de los valores principales (kf1.1 y kp1.1 a h = 1 mm) y solo para
   aceros de resistencia media. A h = 0,2 mm sus propias tablas dan Ff/Fc = 0,26 (42CrMo4) a 0,43 (C45E), no 0,2;
   para el aluminio kf1.1 es 20 N/mm², no kc1.1/5 ≈ 97. Por eso se usan las tablas donde existen.
5. **Color de S en ISO 513.** El encargo decía «S naranja»; la tabla 5 de ISO 513:2012 dice **marrón** (brown).
   Se sigue la norma (`color_name: "marrón"`) y se anota que varios fabricantes, como Sandvik, lo pintan naranja.
6. **hm de Sandvik:** su fórmula con asen(ae/Dc) es exacta para la fresa centrada; en fresado lateral desde un
   borde el espesor medio real es menor (con ae/Dc = 0,25, la mitad). Se usa la geometría exacta en los dos casos.
7. **S235JR:** thyssenkrupp da Rm 360-510 MPa para la variante JR (≥ 3 mm); la transcripción de WinSteel da
   350-510. Se usa 360 (fuente del fabricante).
8. **Densidad del Ti-6Al-4V:** la ficha de ATI imprime 4,47 g/cm³ junto a 0,160 lb/in³, que son 4,43 g/cm³. Se usa
   4,43 (coincide con el valor habitual).
9. **Ff del 6082:** su fila vecina del TZ (AlMg4SiMn, p. 211) trae mf = 1,08 > 1, así que Ff = b·kf1.1·h^(1−mf)
   casi no depende del avance (hasta baja un poco: de 51 N a f = 0,05 a 41 N a f = 0,8 con ap 2). Es el dato
   impreso; con el aluminio la fuerza de avance la domina el filo, no el espesor de viruta. No se ajusta: el test
   de «Ff y Fp crecen con f» cubre los materiales con exponente menor que 1.
10. **Comprobaciones de orden de magnitud con la tabla de potencias del TZ (p. 212)**, «acero de resistencia
   media»: torneado d 50, f 0,3, ap 3, κ 45°, γ 18°, vc 220 → TZ 1800 N y 6,6 kW; el modelo da 1835 N y 6,73 kW con
   S235JR y 2165 N y 7,94 kW con C45E. Taladrado Ø10, f 0,2, vc 80 → TZ 2160 N por filo y 2,9 kW; el modelo da
   1862 N y 2,48 kW (C45E) y 2841 N y 3,79 kW (42CrMo4). Mismo orden, dentro de la dispersión esperable.

## 5. Materiales de pieza (`work_materials.gd`)

Contrato de CONTRATOS.md más `designation`, `rm_max`, `props_quality`, `rm_note`, `kc_reason` y, dentro de `kc`:
`source`, `quality`, `kf11`, `mf`, `kp11`, `mp` (con `kfp_source` y `kfp_quality`), `alt` y `sandvik`. `rm` es el
**mínimo** que garantiza la norma para ese estado y tamaño.

| id | Material (estado) | ISO | kc1.1 · mc · γ0 | kc de… (calidad) | kf, kp | ρ kg/m³ · HV · Rm MPa |
|---|---|---|---|---|---|---|
| `s235jr` | S235JR (1.0038), laminado | P | 1780 · 0,17 · 6° | TZ p. 209 (primary) | regla (estimación) | 7850 · 112 · 360-510 |
| `c45e` | C45E +N (1.1191) | P | 2200 · 0,14 · 6° | TZ pp. 211 y 205 (primary) | TZ p. 211 (primary) | 7850 · 181 · ≥ 580 |
| `c16mncr5` | 16MnCr5 +FP (1.7131) | P | 2100 · 0,26 · 6° | TZ pp. 209 y 211 (primary) | TZ p. 211 (primary) | 7850 · 172 · ≈ 550 |
| `c42crmo4` | 42CrMo4 +QT (1.7225), 40-100 mm | P | 2500 · 0,26 · 6° | TZ pp. 208-211 (primary) | TZ p. 211 (primary) | 7850 · 280 · 900-1100 |
| `x5crni18_10` | X5CrNi18-10 +AT (1.4301) | M | 2350 · 0,21 · 6° | TZ p. 210 (primary) | X10CrNiMo18-10 (secondary) | 7900 · 205 · 500-700 |
| `gjl250` | EN-GJL-250 | K | 1160 · 0,26 · 2° | TZ pp. 210 y 211 (primary) | TZ p. 211 (primary) | 7200 · 210 · 250-350 |
| `al6082_t6` | EN AW-6082 T6 | N | 470 · 0,27 · 6° | TZ p. 207, grupo N (secondary) | AlMg4SiMn (secondary) | 2700 · 100 · ≥ 310 |
| `cuzn39pb3` | CuZn39Pb3 R430 (CW614N) | N | 780 · 0,18 · 6° | CuZn39Pb2, TZ p. 210 (secondary) | regla (estimación) | 8470 · 120 · ≥ 430 |
| `ti6al4v` | Ti-6Al-4V grado 5, recocido | S | 1370 · 0,21 · 6° | TZ p. 210 (primary) | regla (estimación) | 4430 · 318 · ≥ 895 |
| `inconel718` | Inconel 718 (2.4668), envejecido | S | 3200 · 0,24 · 6° | TZ p. 207, grupo S > 30 HRC (secondary) | NiCr20TiAl (secondary) | 8220 · 390 · ≥ 1240 |
| `pino` | pino silvestre, seco | N | — | kc null | — | 550 · 2,5 · — |
| `pvc` | PVC-U | N | — | kc null | — | 1400 · 15 · 50 |
| `abs` | ABS | N | — | kc null | — | 1050 · 16 · 40 |
| `vidrio` | vidrio sodocálcico float | O | — | kc null | — | 2500 · 550 · — |
| `granito` | granito | O | — | kc null | — | 2650 · 900 · — |

- **Alternativas (banda):** grupos del TZ p. 207 para cada material; C45E 1850/0,14; 6082: AlCu4Mg1 510/0,28 y
  AlMg4,5Mn0,4 487/0,23; Inconel: NiCr20TiAl 2088/0,29. Y la familia de Sandvik derivada de su K (CMC 01.1, 01.2,
  02.1, 02.2, 05.21, 08.1, 30.12, 33.1, 23.21, 20.22).
- **Sin kc** (null con `kc_reason`): madera (anisótropa, otros modelos), PVC y ABS (termoplásticos: dependen de la
  temperatura) y vidrio y granito (frágiles: se cortan con abrasivo). ISO 513 mete los no metálicos en N; vidrio y
  piedra van a «O» (fuera de la norma, contrato). `turning()` da la rugosidad teórica pero no fuerzas ni potencia,
  y `cutting_model()` devuelve fuerzas 0 (finitas) con `ok = false` y el motivo.

## 6. Herramientas, recubrimientos y grupos ISO (`tool_materials.gd`)

| id | HV | T máx. °C | Grupos | vc en P (m/min) | Kvc | n | calidad |
|---|---|---|---|---|---|---|---|
| `hss_m2` | 832 (65 HRC) | 600 | P M K N S | 30-60 (TZ) | 1,2 | 1/7 | secondary |
| `hss_co_m42` | 940 (68 HRC) | 600 | P M K N S | 30-60 (TZ) | 1,2 | 1/7 | secondary |
| `hss_tin` | 832 + TiN 2300 | 600 | P M K N S | 30-60 (TZ) | 1,2 | 1/7 | secondary |
| `hm` (HW) | 1650 | 1000 (est.) | P M K N S | 60-300 (TZ) | 1,0 | 0,25 · K 1/3,5 · N 0,4 | estimate |
| `hm_coated` (HC, TiAlN) | 1650 + TiAlN 3300 | 900 | P M K S | 60-300 (TZ); M 120-200 (DEW) | 1,0 | 0,25 · K 1/3,5 | secondary |
| `cermet` (HT) | 1600 (est.) | 1000 (est.) | P M K | 100-350 (est.) | 1,0 (est.) | 0,25 (est.) | estimate |
| `ceramica_al2o3` (CA/CM) | 2300 | 1200 (est.) | P K H | 180-500 (TZ) | 0,85 | 0,5 | estimate |
| `ceramica_si3n4` (CN) | 1600 (est.) | 1200 (est.) | K S | K 180-500 (TZ, sec.) | 0,85 | 0,5 (est.) | estimate |
| `cbn` (BH/BL) | 4500 | 1300 (est.) | H K | H 80-250 (Sandvik) | 0,85 (est.) | 0,5 (est.) | estimate |
| `pcd` (DP) | 6000 | 600 | N | N 300-1500 (est.) | 0,85 (est.) | 0,4 (est.) | secondary |

- «Brocas de titanio»: son HSS con una capa de TiN, no de titanio. La capa (2300 HV, 600 °C) alarga la vida, pero
  sin un dato publicado accesible no se modela: mismas vc y n que el HSS.
- **Recubrimientos (Balzers 2007):** TiN (BALINIT A) 2300 HV, 600 °C, amarillo oro · TiCN (B) 3000 HV, 400 °C,
  gris azulado · TiAlN (FUTURA NANO) 3300 HV, 900 °C, gris violeta · AlCrN (ALCRONA) 3200 HV, 1100 °C, gris
  azulado · DLC (a-C:H) > 2000 HV, 350 °C, negro. El fabricante avisa de que dependen del ensayo.
- **Grupos ISO 513:** P azul · M amarillo · K rojo · N verde · S marrón · H gris; más «O» (fuera de la norma).
  `color` es un color de pantalla (elección de diseño); el normativo es `color_name`.
- `taylor_params(tool, grupo)` devuelve `{ n, C, vc_ref, t_ref_min, quality, n_quality, source }`.

## 7. Planos (`drawing.gd`)

- **ISO 286** (IT6-IT11 hasta 120 mm; grupos «de más de … hasta … incluido»): `it_um(grado, d)`,
  `shaft_tolerance("h9" | "js9", d)`. h9 de 18-30 = 0/−52 µm, h9 de 30-50 = 0/−62, h8 de 18-30 = 0/−33,
  js9 de 30-50 = ±31. js es ±IT/2 exacto (sin redondear los IT impares; las piezas no lo necesitan).
- **ISO 2768-1 clase m:** longitudes y radios interiores (tabla 1): ±0,1 hasta 6 mm, ±0,2 de 6 a 30, ±0,3 de 30
  a 120…; chaflanes y radios exteriores (tabla 2): ±0,2 de 0,5 a 3, ±0,5 de 3 a 6, ±1 por encima.
- **Pieza A** (C45E, bruto Ø50 × 85, 25 mm en el plato): chaflán 1×45° (±0,2), Ø30 h9 (Z0 a Z−20), Ø40 h9
  (Z−20 a Z−40), Ø46 ±0,1 (Z−40 a Z−55), longitudes desde la cara 20 (±0,2), 40 y 55 (±0,3); Ra 3,2 general y 1,6
  en el Ø40. De Z−55 al plato queda un collar de bruto Ø50.
- **Pieza B** (EN AW-6082 T6, bruto Ø40 × 70, 20 mm en el plato): chaflán 0,5×45° (±0,2), Ø24 h8 con redondeo
  cóncavo R2 en el hombro (radio interior: ±0,1, tabla 1), Ø36 js9, cono Ø36 → Ø38 de Z−35 a Z−45 (±0,3 en cada
  extremo), longitudes 15 (±0,2), 35 y 45 (±0,3); Ra 1,6 en el Ø24. **Decisión de plano:** Ra 3,2 general en el
  resto, como en la pieza A (el contrato no lo fija).
- **Acotación desde la cara** (cotas absolutas, como el programa CNC). Supuesto de diseño del plano.
- `target_profile(plano, dz)`: radio nominal por anillo con el anillo i en `z = z0 + i·dz`; por defecto
  `z0` = extremo del bruto en el plato y el último anillo en la cara del bruto (A: 4251 anillos con dz = 0,02).
  En un escalón exacto manda la cara del hombro (el radio mayor). `make_profile()` construye un perfil completo
  del contrato con la pieza al nominal (vista previa y tests).

## 8. Inspección (`inspection.gd`)

`inspect_part(perfil, plano)` mide como un inspector:

- **Diámetros:** tamaño local de cada anillo = 2·(cresta más alta) en una ventana de 1 mm centrada en él, como
  un palpador de ese ancho (se apoya en las crestas; los valles son rugosidad). Todos los tamaños locales deben
  caer dentro; `measured` es el más alejado del centro de la tolerancia. Una ranura más ancha que el palpador se
  detecta esté donde esté; una más estrecha la puentea (límite del método, como con un micrómetro).
- **Longitudes:** la cara es el último anillo con material; un escalón se sitúa donde el radio cruza la media de
  los radios **medidos** a 1,5 mm a cada lado (si no hay diferencia, no hay escalón y la cota no se puede medir);
  el inicio del cono (quiebro sin escalón), cortando las rectas ajustadas a cada lado.
- **Chaflán 45°:** `c = √(2·A)` con el área que falta respecto al cilindro medido (mediana de crestas).
  **Radio cóncavo:** `R = √(A/(1 − π/4))` con el área que añade el redondeo. **Cono:** recta ajustada a las
  crestas, diámetro en los dos extremos.
- **Ra:** regla del 16 % de ISO 4288, solo con los anillos mecanizados (`ring_pass` ≥ 1) y con material: una
  superficie de bruto no cumple ningún Ra. `measured` es el percentil 84 de sus Ra, así que `measured ≤ required`
  equivale a la regla; se compara con la holgura del float32 de `ring_ra` (3,2 se guarda como 3,2000000477).
- **deviation_map** (µm de radio; + sobra, − pasado) frente al intervalo nominal de cada anillo, para que una
  rejilla desplazada no pinte escalones falsos (test con medio anillo de desfase). **ring_state:** 0 bien, 1 sobra
  material fuera de tolerancia (se puede repasar), 2 pasado (en las zonas de diámetros y cono).
- **score 0-10:** media ponderada (diámetros ×2, resto de cotas y zonas de Ra ×1); una cota fuera vale como mucho
  0,5 y nada si se sale más que el ancho de su tolerancia. Elección de diseño, no física.

## 9. Tabla de estimaciones

| Dato | Valor | Por qué es estimación |
|---|---|---|
| HV de los aceros | 112-280 | convertidas desde Rm (o HB) con la tabla de ISO 18265 |
| Rm de 16MnCr5 +FP | ≈ 550 MPa | convertida desde 140-187 HBW |
| Densidad y HV de EN-GJL-250 | 7200 kg/m³, 210 HV | valores típicos de la fundición gris, sin ficha consultada |
| HV de Ti-6Al-4V | 318 | 32 HRC con la tabla de aceros de ASTM E140 |
| HV de Inconel 718 | 390 | ~40 HRC típico del envejecido, sin ficha consultada |
| PVC-U | 1400 kg/m³, 15 HV, 50 MPa | valores típicos sin ficha de fabricante |
| ABS | 1050 kg/m³, 40 MPa | valores típicos (16 HV es el del laboratorio) |
| Granito | 2650 kg/m³, 900 HV | típicos; HV entre feldespato y cuarzo (1100 HV) |
| Kver «medio» | 1,35 | punto medio del intervalo 1,2-1,5 del TZ |
| γ0 de los no férreos | 6° | el TZ solo da el del acero (6°) y la fundición (2°) |
| kf, kp sin fila en el TZ | kc1.1/5, kc1.1/6; mf 0,70, mp 0,48 | regla para aceros de resistencia media; medianas |
| Familia de Sandvik (banda) | derivada de K | supone fresa centrada de κ = 45° y ae/Dc = 0,8 |
| T máx. del metal duro, cerámicas y CBN | 1000, 1200, 1300 °C | valores de manual sin fuente accesible verificada |
| HV del cermet y del Si3N4 | 1600 | sin ficha accesible verificada |
| vc fuera de P (salvo CBN en H y metal duro recubierto en M) | ver `vc_quality` | órdenes de magnitud de catálogo |
| Kvc de cermet, CBN y PCD; n de cermet, Si3N4, CBN y PCD | ver tabla | el TZ no los trata |
| Vida de Taylor (toda) | C = vcT15·15^n | vcT15 = centro del intervalo de vc |

## 10. API

```gdscript
const WorkMaterials = preload("res://core/taller/work_materials.gd")
WorkMaterials.WORK_MATERIALS · get_material(id) · ids() · machinable_ids()
WorkMaterials.kc_families(material) · force_components(material) · sandvik_family(k)

const ToolMaterials = preload("res://core/taller/tool_materials.gd")
ToolMaterials.TOOL_MATERIALS · COATINGS · ISO_GROUPS · REFERENCES
ToolMaterials.get_tool(id) · ids() · get_coating(id) · recommended(tool, grupo) · surface_hv(tool)
ToolMaterials.taylor_params(tool, grupo) -> { n, C, vc_ref, t_ref_min, quality, n_quality, source }

const Cutting = preload("res://core/taller/cutting.gd")
Cutting.specific_cutting_force({ kc11, mc, h_mm, gamma_deg, gamma0_deg, tool_factor, wear_factor, process_factor })
	-> { kc, k, Kh, Kgamma, Kvc, Kver, Ksp }
Cutting.turning({ work_id, tool_id, d_mm, vc | rpm, f_mm_rev, ap_mm, kappa_deg, gamma_deg, nose_r_mm, wear,
	process, machine: { pmax_kw, rpm_max, eta } })
	-> { rpm, vc, h_mm, b_mm, a_mm2, kc, band, kc_parts, fc_n, ff_n, fp_n, pc_kw, pmotor_kw, torque_nm, q_cm3_min,
	     rt_um, ra_um, life_min, overload, rpm_limited, quality, ff_fp_quality, life_quality, sources, warnings }
Cutting.milling({ …, dc_mm, z, fz_mm | vf_mm_min, ap_mm, ae_mm, centered, kc_n_mm2?, gamma0_deg?, kc_quality? })
	-> { …, vf_mm_min, fz_mm, hm_mm, hex_mm, zc, fc_mean_n, tooth_hz }
Cutting.drilling({ …, d_mm, f_mm_rev, point_angle_deg }) -> { …, fc_edge_n, thrust_n, torque_nm }
Cutting.roughness(f, rε) -> { rt_um, ra_um, ideal, valid, source } · Cutting.taylor_life(vc, n, C)
Cutting.cutting_power_kw(fc_n, vc) · rpm_from_vc(vc, d) · vc_from_rpm(rpm, d) · wear_factor(w)
Cutting.cutting_model(work_id, tool_id, h_mm, b_mm, vc) -> { kc, fc_n, ff_n, fp_n, ok, vc_ok, quality, reason? }
Cutting.model_callable() -> Callable

const Drawing = preload("res://core/taller/drawing.gd")
Drawing.drawings() · get_drawing("A" | "B") · it_um(grado, d) · shaft_tolerance(código, d)
Drawing.general_tolerance("linear" | "edge", d, clase) · nominal_radius(plano, z) · nominal_range(plano, za, zb)
Drawing.profile_grid(plano, dz) · target_profile(plano, dz, z0?, count?) · make_profile(plano, dz, ra_um, z0?, count?)

const Inspection = preload("res://core/taller/inspection.gd")
Inspection.inspect_part(perfil, plano) -> { features: [{ id, kind, label, iso, measured, nominal, upper, lower,
	ok, deviation_um, … }], ra: [{ zone, measured, mean, required, share_over, ok, general, rule, machined_rings }],
	deviation_map: PackedFloat32Array, ring_state: PackedByteArray, face_z, passed, score }
```

## 11. Para el coordinador

1. **Rejilla del perfil:** la inspección entiende el contrato como «el anillo i está en `z = z0 + i·dz`» (muestra
   puntual) y tolera un desfase de rejilla. Conviene que el torno lo confirme en CONTRATOS.md.
2. **`cutting_model` sin kc** (madera, plásticos, vidrio, piedra): devuelve `kc` y fuerzas 0 (finitas) con
   `ok = false` y `reason`. El torno debe mirar `ok` y enseñar `reason` en vez de cortar gratis. Propongo añadirlo
   al contrato del modelo inyectado en CONTRATOS.md (ahora solo promete `{ kc, fc_n }`).
3. **Claves nuevas del material de pieza** (`designation`, `rm_max`, `props_quality`, `rm_note`, `kc_reason`, y en
   `kc`: `source`, `quality`, `kf11`…`mp`, `alt`, `sandvik`): propongo documentarlas en CONTRATOS.md. `rm` es el
   mínimo de la norma y puede ser null (madera, vidrio, piedra).
4. **Color del grupo S:** ISO 513 dice marrón; el encargo decía naranja. La interfaz puede usar `color` (pantalla)
   como quiera, pero `color_name` sigue la norma.
5. **Cara del bruto:** los planos suponen `face_allowance_mm = 0` (la cara del bruto ya está en Z0). Si los
   programas Fagor refrentan (p. ej. 1 mm), hay que poner esa creces en `stock.face_allowance_mm` para que
   `profile_grid()` y `target_profile()` cubran el refrentado. La inspección no lo necesita: mide la cara real.
6. **Máquina:** `turning`, `milling` y `drilling` reciben `machine = { pmax_kw, rpm_max, eta }`; los datos de cada
   máquina deberían venir de la unidad del torno o de la fresadora. Sin `machine` no hay aviso de sobrecarga ni tope.
7. **Integración:** este archivo es la base de la sección de corte de `docs/TALLER.md`.
8. Los archivos `.gd.uid` de los scripts nuevos los genera la importación de Godot y van en el commit, como los
   del resto del proyecto.
