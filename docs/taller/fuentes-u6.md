# Unidad 6 · Abrasivos, radial y corte de carrocería

Fuentes, modelo y estimaciones de la radial (amoladora angular) del **Taller industrial**. Código en
`godot/core/taller/` (`abrasives.gd`, `radial.gd`, `panels.gd`) y tests en `godot/tests/taller/`
(`test_radial.gd`, `test_cut_panel.gd`). Es un simulador educativo: nada de esto es un procedimiento de taller ni
de rescate.

## Qué comparte con el laboratorio

El grano abrasivo de un disco es, para el motor, lo mismo que la punta de una uña: `grain_contact()` usa
`Contact.tip_geometry`, `Contact.hardness_efficiency` (ratio de dureza grano/pieza), `Contact.plastic_fraction`
(Hertz), `Contact.solve_static` y `Abrasion.abrasion_mode(Dp)` (Hokkirigawa-Kato), con la misma cuenta que un
«arañazo» de una pasada del laboratorio (media carga en el frente del contacto, factor de von Mises con la fricción
de la pieza) y el mismo umbral de surco (0,5 µm; por debajo, sin modo, como en `solidResult`). Lo que el disco
arranca con el empuje del operario sale de `Abrasion.archard_wear` (Archard 1953), y la misma eficiencia por ratio
de dureza decide que un grano más blando que la pieza no la corta. No se copia ninguna fórmula de `core/shared/`.
El test comprueba que el modo cambia en Dp = 0,1 y 0,2 y que, en los escenarios del golden del motor 1.x con surco,
la función compartida da el mismo modo y la misma fracción que calculó `physics.js`.

## API

`const Abrasives = preload("res://core/taller/abrasives.gd")`

| Símbolo | Qué es |
|---|---|
| `ABRASIVES` | `al2o3 · sic · cbn · diamante` (claves de CONTRATOS.md) y `ceramico` (opcional): `{ id, name, formula, hv, hk, e_gpa, max_temp_c, iron_reactive, iron_reaction_c, best_for, source, quality }` |
| `RECOMMEND`, `abrasives_for(kind, iso = "")` | abrasivos adecuados por tipo de pieza, del mejor al peor; `iso = "H"` (ISO 513, templado) en acero o inox → CBN primero |
| `GRIT_SYSTEMS`, `grit_microns(system, grade)` | `fepa_f` (F5-F1200), `fepa_p` (P12-P2500), `jis_r6001` (#240-#8000): mediana en µm. El grado admite `1000` o el texto con el prefijo **de su sistema** (`"F1000"`, `"P1000"`, `"#1000"`); −1 si no existe o trae el prefijo de otro sistema |
| `STRIPES`, `stripe_for(v)`, `STRIPE_HEX` | franjas de EN 12413 por velocidad máxima (`["rojo"]` a 80 m/s; `[]` hasta 45 m/s) y colores de pintado |
| `MARKED_RPM`, `marked_rpm(D, v)`, `formula_rpm(D, v)` | rpm marcadas (115-230 mm a 50, 63, 80 y 100 m/s) y la fórmula n = 60000·v/(π·D); −1 si el diámetro no está |
| `DISCS`, `disc_stripe(id)`, `disc_rpm(id, D)` | discos (ids del contrato: `fino_1mm`, `grueso_3mm`, `diamante`, `laminas`; y además `corte_alu`, `corte_sic`, `corte_ceramico`, `desbaste`, `diamante_turbo`, `diamante_continuo`); su franja; las rpm que marca el fabricante en ese diámetro (−1 si no lo hace) |

`const Radial = preload("res://core/taller/radial.gd")`

| Función | Entrada → salida |
|---|---|
| `disc_check(p)` | `{ diameter_mm, rpm, max_speed_ms, nominal_diameter_mm?, disc_id? }` → `{ speed_ms, max_rpm, marked_rpm, disc_rpm, limit_rpm, over_speed, warning, stripe }`. El límite es, por este orden, lo marcado **en el propio disco** (`disc_rpm`), la tabla de EN 12413 (`marked_rpm`) o la fórmula (y entonces el aviso dice «máximas», no «marcadas»). Con `nominal_diameter_mm` detecta el disco gastado de una radial grande montado en una pequeña. `stripe` es `[]` en los discos que no son de EN 12413 |
| `cut_off(p)` | `{ disc_id, diameter_mm, rpm, work_kind, thickness_mm, depth_mm, feed_mm_s, length_mm?, work_hv?, work_iso?, power_kw?, push_n?, angle_deg? }` → `{ vs, q_mm3_s, specific_energy_j_mm3, power_kw, time_s, warnings, feed_mm_s, passes, limited_by, over_speed, kerf_mm, kerf_surface_mm, work_hv, … }`. `thickness_mm`: espesor que se atraviesa; `depth_mm`: profundidad por pasada; `feed_mm_s = 0` → el avance máximo; `work_hv`: dureza de la pieza (la de la unidad de materiales); `work_iso = "H"` sin `work_hv` → 700 HV |
| `grain_contact(p)` | `{ grit_microns, abrasive_id, work_hv, work_e_gpa, load_n, work_mu? }` → `{ depth_um, a_um, Dp, absMode, fab, phi, muPlough, eta, ratio, tip_radius_um }` (`absMode` null, `fab` 0 si no hay surco: grano más blando o menos de 0,5 µm) |
| `cut_panel(p)` | contrato de la escena 3D del corte (abajo) |

`const Panels = preload("res://core/taller/panels.gd")`: `PAINT_LAYERS` y `CAR_BODIES` (copia literal de
`data.js`), `PANELS` (`acero-dulce`, `acero-bh`, `aluminio`, `plastico-carroceria`, `boro-22mnb5`, `dp800` y, de
más, `perfil-aluminio`), `get_panel(id)`, `THERMAL`, `TEMPER_COLORS`, `SPARK_CLASSES`.

Unidades: las de CONTRATOS.md (potencia en kW, velocidad periférica en m/s, temperatura en °C, longitudes en mm,
rebaba en µm). El avance de la radial va en **mm/s** (`feed_mm_s`, como fija el contrato de `cut_panel`): es una
herramienta de mano, no una máquina con avance por vuelta o por minuto.

### Contrato de `cut_panel`

Entrada: `{ disc_id, diameter_mm, rpm, angle_deg (0 = disco perpendicular a la chapa; inclinación lateral),
feed_mm_s (0 = el máximo que permiten la radial y el empuje), panel_id, cut_length_mm, power_kw?, push_n? }`.

| Campo | Qué es |
|---|---|
| `vs_ms`, `over_speed`, `time_s` | velocidad del borde (m/s), si pasa de las rpm marcadas en el disco, tiempo del corte (s; `INF` si no corta) |
| `kerf_mm` | anchura del surco **medida en perpendicular al disco**: espesor del disco + 0,4 mm (en la chapa, `kerf_mm / cos θ` = `kerf_surface_mm`) |
| `burr_um` | altura media de la rebaba en la cara de salida (en plástico, hilos): la media de `burr_sides_um` |
| `haz_mm` | anchura, a cada lado, hasta la que la chapa pasó de **200 °C** |
| `heat_tint` | `{ temp_c (pico en el borde del surco), color (hex, el de esa temperatura: gris de óxido en acero, tostado en plástico, "" en aluminio), name, width_mm (banda con color de revenido a cada lado), bands: [{ from_mm, to_mm, color, name }] }`, del corte hacia fuera |
| `paint_burn_mm` | pintura quemada a cada lado (0 en paneles sin pintura) |
| `sparks` | `{ rate (chispas **visibles por segundo**), color, color_name, color_end, color_end_name, length_mm (chorro **ya con la vs** del corte), bursts (estallidos medios **por chispa**), bursts_name, class }` |
| `disc_wear_mm3`, `disc_loading` | disco gastado y embotamiento (0-1) |
| `deformation` | deformación térmica junto al corte, **en mm** |
| `cleanliness` | 0 limpio … 10 sucio |
| `warnings` | `[{ code, message, source }]` (códigos abajo) |
| `quality`, `sources` | `"estimate"` y citas cortas, enteras |
| propuestos por la escena | `smoke` (0-1), `melt` (0-1, plástico fundido en hilos), `burr_sides_um: { lado_menos, lado_mas }` (con θ > 0, la arista aguda y la rebaba mayor quedan en el lado −, la convención de la escena) y `front_temp_c` (frente del corte) |
| además | `kerf_surface_mm, burr_side ("ambos" \| "un_lado"), smoke_from, panel_id, disc_id, angle_deg, feed_mm_s, limited_by ("" \| "potencia" \| "empuje"), power_kw, q_mm3_s, specific_energy_j_mm3, heat_j_mm, glazing` |

Sin corte (disco parado, sin empuje, grano más blando que la chapa o disco de láminas, que no tronza) la salida
lleva todo en cero: ni calor, ni chispas, ni rebaba, ni desgaste; `time_s` es `INF` y hay aviso. Un panel o un
disco desconocidos dan la misma salida vacía (con todos los campos) y el aviso `sin_datos`.

Códigos de aviso: `exceso_velocidad`, `disco_no_corta`, `disco_inadecuado`, `diamante_ferrico`, `sic_ferrico`,
`diamante_fundicion`, `embotamiento`, `polvo_aluminio`, `acunamiento`, `potencia`, `empuje`, `sin_corte`,
`sin_datos`, `plastico_fundido`, `pintura_humo`, `pilar_boro`, `rescate_herramientas`, `rescate_airbag`,
`rescate_alta_tension`, `educativo`.

## Modelo del corte

1. **Surco.** Un disco de 1 mm abre 1,3-1,5 mm (holgura y vibración; Awan et al. 2022, *Sensors*): surco =
   espesor + 0,4 mm, medido en perpendicular al disco; en la chapa, / cos θ. El volumen arrancado por mm de corte es
   el surco en la chapa por el espesor.
2. **Energía específica** medida en tronzado con disco fino (Awan et al. 2022, *J. Mater. Res. Technol.*, tabla 1):
   `SEC = SCE + C_sl·Vc/Q + C_pl·Vc·e²/Q²` (J/mm³; Vc en mm/s, Q en mm³/s, e = anchura del surco del disco en mm).
   Con Vc ≈ 70.000 mm/s reproduce su figura 4 (SS201: 34 J/mm³ a 6 mm³/s y 25 a 16,6). En acero a caudal normal da
   ~25 J/mm³, el valor típico de Rowe et al. (2003). Por debajo del menor caudal medido (3,4 mm³/s), o del de mínima
   potencia si es mayor, la energía se deja constante en vez de extrapolar el arado hacia infinito. Si el disco se
   embota o se vidria, ×1,4 (Rowe et al. 2003: «de 25 a 35 J/mm³»).
3. **Avance.** El menor de tres: el pedido, el que da la potencia útil de la radial (resolviendo SEC(Q)·Q = P) y el
   del empuje del operario por Archard, `Q = K·F·Vc/H` (con la eficiencia por ratio de dureza del laboratorio y
   dividido por el embotamiento). Por eso el acero al boro y el templado van despacio aunque sobre potencia. Sin
   giro no hay corte, ni siquiera en piedra (donde no se aplica Archard).
4. **Calor.** Las virutas (las chispas) se llevan 8,1 J/mm³ en acero (AISI 1095 hasta 1.500 °C; Rowe et al. 2003);
   del resto, la pieza recibe R_ws = 0,9 con corindón y 0,5 con CBN (Rowe et al. 2003). Calor por mm de corte
   H = R_ws·(SEC − e_viruta)·surco·espesor. Temperatura de pico a y mm del borde en chapa fina (Adams 1958):
   `1/(Tp − T0) = √(2πe)·ρ·c·t·y/H + 1/(T_borde − T0)`. De ahí salen la zona afectada (200 °C), las bandas de color
   de revenido, la pintura quemada (250 °C) y la pared ablandada (727 °C en acero) que hace crecer la rebaba.
5. **Deformación.** Por conservación de la energía, en cada sección de la chapa ∫ρ·c·t·ΔT dy = H, así que la
   dilatación transversal que da el calor del corte es `α·H/(ρ·c·t)` (mm). Es la escala del alabeo (lo que luego se
   contrae y alabea la chapa), no un cálculo de pandeo: estimación.
6. **Rebaba, chispas, desgaste, limpieza.** Rebaba ∝ surco × tendencia del material × (0,1 + 0,9·fracción
   ablandada); inclinada, la media crece × (1 + 1,5·sen θ) y lo de más sale del lado de la arista aguda. Chispas
   visibles por segundo = 100 por mm³ × tamaño del chorro del ensayo de chispas × Q; su longitud, la del ensayo ×
   √(vs/25,4 m/s). Desgaste = volumen arrancado/G. Limpieza = suma ponderada de rebaba, calor visible,
   embotamiento, ángulo, vidriado y fundido. Son estimaciones (tabla de estimaciones).

Comportamientos que salen (y que comprueban los tests): el disco de 1 mm corta antes que el de 3,2 mm, con menos
rebaba, menos zona afectada, menos deformación y menos pintura quemada; con ángulo el surco se ensancha en la chapa
(no medido en perpendicular al disco), la rebaba crece y sale a un lado, con aviso de acuñamiento; el aluminio embota
el disco de corindón (y no el específico); el diamante en acero se vidria y se gasta, y el SiC se gasta más que el
corindón; el plástico se funde, humea y no da chispas; el pilar de boro es el corte más lento (lo frena el empuje),
el más caliente y el que más disco gasta; por encima de las rpm marcadas en el disco, `over_speed`; sin corte, nada.

## Fuentes por dato

### Abrasivos (`ABRASIVES`)

| Dato | Valor | Fuente |
|---|---|---|
| Corindón: HV y E | 2000 HV · 400 GPa | zafiro del laboratorio V1 (`data.js`, valores de manual; FISICA.md) |
| Corindón: Knoop | 2.050 (Knoop 100) · ~20.000 N/mm² | GNPGraystar, ficha *Brown Aluminum Oxide* (rev. 02/2020); Brazda (KAPP Technologies), «Hard Choices: Diamond or CBN?», *Gear Solutions*, 1-2-2006 |
| Corindón: temperatura | se ablanda ~1.750 °C, funde ~2.040 °C, inerte | Washington Mills, «Fused Mineral Properties» |
| SiC: Knoop, Mohs | 2.500 kg/mm², 9,2; no funde, se disocia | GRAYSTAR, TDS *Black Silicon Carbide* (2009); ~2.700 °C, ficha CAS 409-21-2 (ChemicalBook) |
| SiC: HV y E | 2800 HV · 440 GPa | moissanita del laboratorio V1 |
| SiC: usos y reactividad | fundición, no férricos y no metálicos; reacciona con el acero | patente US 4.505.720 (1985), antecedentes; PFERD PSF ALU+STONE; Norton 37C |
| CBN: HV, HK, E | 62 GPa (6.322) · 44 GPa (4.487) · 909 GPa | Solozhenko, Bushlya y Zhou (2019), arXiv:1905.04304, tabla (monocristal) |
| CBN: temperatura y uso | filo hasta 1.000 °C; el superabrasivo del acero | Brazda (KAPP) 2006; Benes, «All About Abrasives», *American Machinist*, 10-5-2007 |
| Diamante: HV y E | 10.000 HV · 1.050 GPa | diamante del laboratorio V1 |
| Diamante: Knoop | 70.000 N/mm² (7.138) | Brazda (KAPP) 2006 |
| Diamante y hierro | se oxida > 600 °C; reacciona con Fe, Co, Ni > 700 °C | Brazda (KAPP) 2006; mecanismo: Komanduri y Shaw (1975), *Nature* 255:211-213, y (1976), *Phil. Mag.* 34:195-204 (difusión del carbono en el hierro) |
| Corindón cerámico | sol-gel, tenaz, autoafilable, «para materiales duros» | PFERD, *Werkzeughandbuch 23* (2019); dureza, módulo y temperatura: estimación (= corindón) |

HV y HK no se convierten entre sí: para cerámicas y superabrasivos no hay conversión normalizada (ISO 18265 es
para metales) y la diferencia es grande en el diamante (~7.100 HK frente a ~10.000 HV). El modelo usa HV, como el
laboratorio. Los avisos de grano contra hierro leen `iron_reactive`, `max_temp_c` e `iron_reaction_c`: el diamante
(reacciona desde 700 °C, por debajo de la pared del surco de un acero) se vidria; el SiC (reacciona «a la
temperatura del contacto», sin cifra) se gasta.

### Recomendaciones (`RECOMMEND`)

SiC para fundición y piedra (US 4.505.720; PFERD PSF ALU+STONE: aluminio, titanio, no férricos, piedra, hormigón,
azulejo y fundición; Norton 37C); CBN para acero templado (ISO 513 H) y aleaciones de níquel (KAPP 2006; *American
Machinist* 2007); diamante primero en piedra y vidrio (PFERD, discos EN 13236 y galvánicos D 64/D 151 para vidrio,
cerámica y metal duro) y también en fundición (discos galvánicos D 852 de PFERD para fundición gris y esferoidal);
corindón y cerámico para acero e inox (PFERD). Madera: sin recomendación (no se modela). El aviso de disco
inadecuado no recomienda el grano que ya lleva el disco: si su grano es el bueno, lo dice.

### Tamaño de grano (`GRIT_SYSTEMS`)

| Sistema | Fuente | Comprobación del encargo |
|---|---|---|
| FEPA F (F5-F1200) | Universal Photonics, *Grit Size Comparison Chart* (D50; micro según FEPA 42-2:2006) | F1000 = 4,5 µm, igual en ABC SwissTech (FEPA 42GB-1984: 4,5 ± 0,8 µm) |
| FEPA P (P12-P2500) | Universal Photonics (D50, FEPA 43 / ISO 6344) | P1000 = 18,3 µm |
| JIS R6001 (#240-#8000) | Resonac, *Morundum Micrograins* (rango de ds-50; se usa el centro) | #1000 = 10,5-12,5 → 11,5 µm; igual que la columna de resistencia eléctrica de ABC SwissTech (JIS R6001-1998) |

### Franjas de color de EN 12413 (`STRIPES`): verificadas, no de memoria

- **Un color** (50 azul, 63 amarillo, 80 rojo, 100 verde): Klingspor, «Arbeitshöchstgeschwindigkeit»
  (klingspor.de, *Schleifwissen*), y Andre Abrasive Articles, «General rules for marking abrasive tools»
  («extracto de EN 12413»). Dos fabricantes.
- **Dos colores** (125 azul + amarillo, 140 azul + rojo, 160 azul + verde, 180 amarillo + rojo, 200 amarillo +
  verde, 225 rojo + verde, 250 2 × azul, 280 2 × amarillo, 320 2 × rojo; franjas de 5 a 20 mm separadas al menos
  2 mm): tabla de DIN EN 12413 reproducida por HFUK Nord, FUK Mitte y FUK Brandenburg, «Stichpunkt Sicherheit B 7:
  Verwendungsdauer von Trenn- und Schruppscheiben» (03/2020), con fuente DIN EN 12413 y Klingspor. Calidad
  `secondary`.
- La norma: EN 12413:2019, anexo D (informativo), y apartado 5.1.2 (serie de velocidades: <16, 16, 20, 25, 32, 35,
  40, 45, 50, 63, 80, 100 y 125 m/s; comprobado en la muestra pública de SIST EN 12413:2020). Klingspor indica que
  ya no son obligatorias aunque se siguen usando; oSa (*Product marking requirements for bonded abrasives*, 2020)
  las pide como marcado adicional según el anexo D.

### rpm marcadas (`MARKED_RPM` y las de cada disco)

Andre Abrasive Articles, «Speed conversion tables» (la tabla de conversión por diámetro y velocidad; según oSa las
rpm marcadas deben salir del anexo E de EN 12413). A 80 m/s coincide con la ficha de Klingspor Kronenflex A 24 R
Supra (115: 13.300 · 125: 12.250 · 150: 10.200 · 180: 8.500 · 230: 6.650 rpm). Redondea a 50 rpm (casi siempre hacia
arriba; la única hacia abajo es 150 mm a 100 m/s): siempre a menos de 50 rpm de la fórmula. PFERD marca sus discos
redondeando a la centena (125 mm: 12.200; 230 mm: 6.600; *Werkzeughandbuch 23*, columnas «Max. RPM»), y NovoAbrasive
publica 12.200 y 6.650. `disc_check` y el corte usan primero lo marcado en el propio disco (PFERD), porque la regla
de seguridad es no pasar nunca de lo marcado en el disco; la tabla, para los diámetros que el fabricante no hace.

### Discos (`DISCS`)

Todos de PFERD, *Werkzeughandbuch 23* (2019), catálogos 5 y 6, con sus rpm máximas: EHT 125-1,0 SG STEELOX
(`fino_1mm`: «cortes finos y con poca rebaba», «rapidez»; de 0,8 a 1,0 mm, «máxima rapidez y calidad en chapa»),
EH 125-3,2 SG STEELOX (`grueso_3mm`: ≥ 1,9 mm, «uso robusto»), EHT 125-1,0 SG ALU (corindón + SiC: «impide que el
disco se embadurne, incluso en aluminio blando y tenaz»), EHT 125-1,6 PSF ALU+STONE (SiC), EHT 125-1,0 CERAMIC SGP
STEEL (grano cerámico), E 125-7 PSF STEEL (desbaste, forma 27), POLIFAN PFF 125 A PSF STEELOX (`laminas`, EN 13743,
granos 40-120) y DS 125 × 2,2 PSF (`diamante`), DG 125 × 2,1 PSF y DG 125 × 1,6 FL PSF (diamante EN 13236:
segmentado para hormigón y ladrillo, turbo para granito y mármol, continuo para azulejo; se recomienda cortar en
húmedo y con poca presión). Aglomerante BF de los aglomerados: EN 12413 y PFERD. Seguridad (PFERD, instrucciones):
no pasar nunca de las rpm marcadas, guiar el disco de corte siempre recto y sin cargas laterales, no usarlo cerca de
materiales inflamables, polvo de aluminio explosivo y que no se mezcle con el de acero.

### Energía, potencia y calor

| Dato | Fuente |
|---|---|
| SEC del tronzado con disco de 1 mm: SS201, Al 1100, Al 7075, Inconel 718 | Awan, González Rojas, Perat Benavides, Hameed, Hussain y Sánchez Egea (2022), «Specific energy modeling of abrasive cut off operation based on sliding, plowing, and cutting», *J. Mater. Res. Technol.* 18:3302-3310, tabla 1 y figura 4 (acceso abierto, UPCommons) |
| Surco de 1,3-1,5 mm con disco de 1 mm; energía parecida con disco Cubitron y con uno estándar | Awan et al. (2022), «Machine Learning-Based Prediction of Specific Energy Consumption for Cut-Off Grinding», *Sensors* 22:7152, tablas 1 y A1 |
| 25 J/mm³ típico; hasta 200 J/mm³; +40 % al embotarse (25 → 35); acero templado 60-62 HRC: 62-90 J/mm³; virutas 8,1 J/mm³; R_ws 0,9 y 0,5 | Rowe, Morgan, Batako y Jin (2003), «Energy and temperature analysis in grinding», *WIT Trans. Eng. Sci.* 44 (LAMDAMAP VI) |
| Poliamida amolada con refrigerante a 3 m/s: ~60 J/mm³ | Spina, Cavalcante, Massari y Rutigliano (2021), «Forces and Specific Energy of Polyamide Grinding», *Materials* (PMC8433930) |
| Radial de 125 mm: 1,2 kW de entrada, 0,69 kW útiles, 11.000 rpm; de 230 mm: 2,2 kW, 6.500 rpm | Bosch Professional, fichas GWS 12-125 y GWS 22-230 P |
| Ley de desgaste | Archard (1953), la misma de `abrasion.gd` |
| Acero templado: 60 HRC = 700 HV | DIN EN ISO 18265:2014, tabla A.1 (reproducida por WS Stahl: 700 HV10 ↔ 60,1 HRC); 60-62 HRC es el acero templado de Rowe et al. (2003) |
| Temperatura de pico en chapa fina | Adams C.M. (1958), «Cooling rates and peak temperatures in fusion welding», *Welding Journal* 37(5):210s-215s |
| Acero: ρ 7.850 kg/m³, c ≈ 440 J/(kg·K) a 20 °C; α = 12·10⁻⁶ K⁻¹ | EN 1993-1-2:2005 (3.2.2 y 3.4.1.2); EN 1993-1-1:2005, 3.2.6 |
| Aluminio: 2,71 g/cm³, 897 J/(kg·K), α = 23,1·10⁻⁶ K⁻¹, 575-650 °C | Hydro, ficha EN AW-6082 (rev. 4, 03/2023; propiedades físicas de MNC Handbok nr 12) |
| PPE/PA: densidad 1,08, Vicat 180 °C, inyección 295-315 °C, 0,23 W/(m·K) | SABIC, NORYL GTX964W (rev. 2019-09-25) |
| 727 °C | temperatura eutectoide del diagrama hierro-carbono |

### Colores de revenido (`TEMPER_COLORS`)

Acero al carbono: Engineering ToolBox, «Steel Tempering Colors» (216 a 316 °C, con muestra de color; los nombres
describen la muestra). Inox 1.4301 en aire: BSSA, «Heat Tint (Temper) Colours on Stainless Steel Surface Heated in
Air» (290 °C amarillo pálido … 600 °C azul oscuro). La fila gris de 340 °C del acero y los hex del inox son de
pintado (estimación).

### Chispas (`SPARK_CLASSES`)

Buzzard R.W. (1933), «The utility of the spark test as applied to commercial steels», *Bureau of Standards J. Res.*
11:527 (NBS RP605): con 0,10 % C aparece la lengua bifurcada, con 0,15 % C las explosiones en serie, que crecen con el
carbono (el chorro más vistoso con 0,45 % C); el inox con mucho cromo da un chorro muy corto y el de níquel-cromo,
líneas rojo mate; la fundición, portadores oscuros. Tabla de longitudes (pulgadas, muela a ~5.000 pies/min) y
colores de *Spark Testing for Mystery Metals* (Steel Elements, currículo del estado de Ohio, 2000): hierro dulce 65
(paja → blanco, muy pocas explosiones), acero de herramientas 55 (muchísimas), inox 50, fundición gris 25 (rojo →
paja), níquel 10 (naranja), cobre, latón y aluminio sin chispas. Los estallidos por chispa usan la escala de
palabras de `core/taller/sparks.gd` de la unidad 14 (muy pocas 0,08 · moderadas 0,35 · muchas 0,7 · muchísimas 1,2),
para que el modelo y el emisor hablen el mismo idioma.

### Paneles (`PANELS`)

- **Coches** (`acero-dulce` 0,9 mm, `acero-bh` 0,7, `aluminio` 1,0, `plastico-carroceria` 2,5, con la pintura
  OEM de 110 µm en cuatro capas): copia literal de `CAR_BODIES` y `PAINT_LAYERS` de `data.js`; el test las compara
  con `tests/fixtures/lab-data.json`. Fuentes en docs/FISICA.md, apartados 6 y 14.
- **Pilar B de acero al boro** (`boro-22mnb5`: 22MnB5, Usibor 1500): ArcelorMittal, «Steels for Hot Stamping» (ficha,
  febrero de 2026): Rp0,2 1.100 MPa, Rm 1.500 MPa, A 6 %, C ≤ 0,24 %, pilares A y B, 0,8-2,4 mm; espesor de 1,5 mm del
  ejemplo de ArcelorMittal Tailored Blanks («Usibor 1500P and Ductibor 500P»). `press_hardened: true` lanza el aviso
  `pilar_boro`, con la resistencia y la dureza del propio panel.
- **Refuerzo DP800** (`dp800`): SSAB, ficha 2104 «Docol 800DP» (2017): Rp0,2 500-650, Rm 800-950 MPa, A80 ≥ 10 %,
  C ≤ 0,15 %, 0,50-2,10 mm.
- **Perfil de aluminio EN AW-6082 T6** (`perfil-aluminio`, de más): Hydro (ficha citada): Rp0,2 250, Rm 290 MPa
  (EN 755-2, pared ≤ 5 mm), HBW 95 / HV 100 típicos, E 70 GPa.
- **Dureza por resistencia** de los aceros de rescate: DIN EN ISO 18265:2014, tabla A.1 (reproducida por WS Stahl):
  Rm 1.485 → 460 HV, 1.520 → 470 HV; Rm 875 → ~273 HV.

### Rescate (avisos educativos)

| Aviso | Fuente |
|---|---|
| Se excarcela con cizallas y separadores hidráulicos; NFPA 1936 (2020) añadió una prueba opcional de corte de pilares de alta resistencia | DHS S&T SAVER, TechNote «Battery-Powered Rescue Tools for Vehicle Extrication» (octubre de 2022) |
| Amolar es trabajo en caliente que puede prender combustible o vapores | OSHA, «Fire Watch Duties during Hot Work» (OSHA 4188, 2022); EN 62841-2-3: «no utilice la herramienta cerca de materiales inflamables: las chispas pueden prenderlos» |
| Acuñamiento y rebote; discos solo para su uso; no montar discos gastados de radiales grandes | advertencias de EN 62841-2-3 para tronzado, reproducidas en el manual de la amoladora Parkside PWS 115 C3 |
| Infladores de airbag de gas (argón y helio, hasta 4.000 psi, sin válvula de alivio) | Moore R., «Pressurized Vessels on Vehicles, Part 3: Stored-gas Inflators», *Firehouse*, 1-10-2005 |
| Hoja de rescate | ISO 17840-1:2022, *Road vehicles — Information for first and second responders — Part 1: Rescue sheet for passenger cars and light commercial vehicles* |
| Cables de alta tensión en naranja | Reglamento CEPE/ONU n.º 100, 5.1.1.5.3 («… identified by having an outer covering with the colour orange») |

## Estimaciones (no son mediciones)

| Estimación | Valor | Por qué |
|---|---|---|
| Acero al carbono con los coeficientes del inox SS201 | SCE 20,82 J/mm³ | no hay medidas abiertas de acero al carbono con disco fino (el artículo de 2021 del mismo grupo con S235JR y C45K es de pago); SS201 es otro acero y reproduce los 25 J/mm³ típicos |
| Aluminio de carrocería y perfil | interpolado por dureza entre el 1100 y el 7075 | Awan et al. solo miden esos dos |
| Fundición, piedra, vidrio | SCE 20 J/mm³ | del orden del acero; sin medida |
| Plástico | SCE 10 J/mm³ | entre la energía de fundirlo (~0,45 J/mm³) y los ~60 J/mm³ de la poliamida amolada con refrigerante a 3 m/s, que no llega a fundirse (Spina et al. 2021) |
| Coeficiente de Archard del disco y empuje | K = 0,0125 · F = 30 N | K ajustado para que, en acero dulce, el empuje y la potencia de una radial de 690 W den el mismo caudal (~30 mm³/s); del orden de la abrasión a dos cuerpos |
| Acero templado sin dureza | 700 HV (60 HRC) | el templado de referencia de Rowe; cada temple da la suya (`work_hv`) |
| Grano cerámico | ×1,3 de arranque, ×2 de vida | PFERD solo dice «rendimiento inalcanzado» y «vida sobresaliente» |
| Grano que reacciona con el hierro (SiC) en acero | ×0,5 de vida | la patente solo dice que «no sirve para el acero» |
| Holgura del surco | +0,4 mm | un disco de 1 mm abre 1,3-1,5 mm (Awan et al. 2022); se supone la misma holgura en otros espesores |
| R_ws de SiC, cerámico y diamante | 0,9 · 0,9 · 0,5 | Rowe da 0,9 (alúmina) y 0,5 (CBN) |
| Pared del surco y frente del corte | 1.250 °C acero · 575 °C aluminio · 300 °C plástico | temperatura media de la viruta (Rowe et al.), sólidus (Hydro), inyección (SABIC) |
| Umbrales | 200 °C zona afectada (contrato de la escena) · 250 °C pintura (encima de su horneado a 140-180 °C) · ablandamiento de la pared 727 °C acero, 250 °C aluminio (sobreenvejecimiento del T6), 180 °C plástico (Vicat) | sin medición propia |
| Calor específico y dilatación del PPE/PA | 1.500 J/(kg·K) · 8·10⁻⁵ K⁻¹ | típicos de poliamidas; la ficha no los da |
| Energía de las virutas de aluminio y plástico | 1,35 · 0,45 J/mm³ | ρ·c·ΔT con las constantes citadas |
| Relación G | 5·(92/HV) en discos de resina (0,5-50) · diamante en acero 0,5 · en piedra 200 · CBN 100 | sin medición abierta (el artículo de *Metals* 2020 sobre desgaste de discos no es accesible) |
| Tendencia a embotar el disco | aluminio 0,8 · latón 0,5 · madera 0,5 · plástico 0,9 | ningún fabricante la cuantifica |
| Ligante y resistencia al embotamiento de los discos | diamante: metálico, 0,3 · SiC 0,5 · ALU 0,8 | el fabricante no los cuantifica |
| Chispas visibles | 100 por mm³ con un chorro de tamaño 1 | calibrado para que el disco fino en acero dulce (~30 mm³/s) dé ~3.000 por segundo, del orden de la referencia de dibujo de `sparks.gd`; no hay recuento publicado |
| Longitud de las chispas a más velocidad | × √(v/25,4 m/s) | la tabla es a ~25 m/s |
| Estallidos por chispa | escala de `sparks.gd` (0,08 … 1,2) | la tabla solo los describe con palabras |
| Rebaba, reparto por lados, limpieza, humo | fórmulas del apartado «Modelo»; humo de pintura 1 − e^(−quemada/10 mm), +0,6·fundido en plástico | ordenan los casos; no hay medidas |
| Deformación | α·H/(ρ·c·t) | la dilatación transversal es exacta por energía; tomarla como escala del alabeo es la estimación |
| Plástico fundido (`melt`) | parte del espesor que pasa del Vicat | sin medida |
| Espesores de rescate | pilar 1,5 mm · DP800 1,2 mm · perfil 3,0 mm | dentro de los rangos de fabricante |
| Clase de chispa de los aceros de carrocería y del 22MnB5 | bajo carbono · carbono medio (60 pulgadas) | por su carbono; la longitud intermedia es interpolada |
| Radial de 230 mm | 1,265 kW útiles | mismo rendimiento que la de 125 mm (57,5 %) |
| Grano como esfera de su tamaño y cono de 60° | — | como las puntas semiesféricas de Hokkirigawa y Kato; los granos reales son poliédricos |

## Discrepancias encontradas (y qué se hizo)

- **rpm marcadas de 125 y 230 mm.** El encargo pedía 12.200 y 6.650. La tabla de conversión de EN 12413 según
  Andre, y lo que marca Klingspor, es 12.250 y 6.650; PFERD marca 12.200 y 6.600; NovoAbrasive, 12.200 y 6.650. La
  fórmula da 12.223 y 6.643. La tabla es 12.250 y 6.650 y el test admite ±0,5 % frente a 12.200 y a la fórmula,
  explicando el redondeo. El 6.600 de PFERD queda un 0,65 % por debajo de la fórmula (del lado seguro). En el corte
  manda lo marcado en el disco (PFERD): un disco fino de 125 mm a 12.240 rpm ya va con exceso.
- **«Rowe 2003, *Principles of Modern Grinding Technology*».** El libro es de 2009 (2.ª ed. 2014). Los 25 J/mm³
  están en Rowe, Morgan, Batako y Jin (2003), *WIT Trans. Eng. Sci.* 44, como ejemplo típico, no como medida del
  acero; por eso la energía sale de las medidas de tronzado de Awan et al. (2022), que dan ~25 J/mm³ en acero.
- **Escalar la energía con la dureza.** Una primera versión escalaba 25 J/mm³ linealmente con la dureza (ley de
  Archard) y daba ~126 J/mm³ en el pilar de boro; la figura 2 de Rowe et al. (62-90 J/mm³ a 60-62 HRC) y las medidas
  de Awan et al. (Inconel de 340 HB: SCE 22,9 frente a 20,8 del SS201) lo contradicen. La dureza entra ahora por el
  empuje (Archard), no por la energía.
- **Aluminio.** En tronzado con disco fino gasta casi la misma energía por mm³ que el acero (Awan et al.). Con un
  disco grueso que se embota, un perfil de 3 mm tarda casi lo mismo que el pilar de boro de 1,5 mm; el test «el boro
  es el más lento» usa el disco fino y el cerámico, que es la comparación justa.
- **FEPA F micro.** Los valores de FEPA 42GB-1984 y de FEPA 42-2:2006 difieren (F600: 9,0 frente a 9,3 µm); F1000 es
  4,5 µm en las dos. Se usan los de 2006.
- **JIS #1000.** 11,5 µm por resistencia eléctrica, 15,5 µm por sedimentación (ABC SwissTech). Se usa el primero,
  el de Resonac y el del encargo.
- **Diamante en fundición.** PFERD vende discos de diamante galvánico D 852 para fundición gris y esferoidal: la
  fundición no da el aviso del acero, sino una nota.
- **Franjas de color.** Ya no son obligatorias según Klingspor, pero oSa las pide con su marca: se dejan como dato.
- **Ids y semántica del contrato.** CONTRATOS.md fija los discos `fino_1mm`, `grueso_3mm`, `diamante` y `laminas`
  y los paneles `boro-22mnb5` y `dp800`: los datos usan esos ids. La escena lee `kerf_mm` en perpendicular al disco,
  `haz_mm` hasta 200 °C, `heat_tint.temp_c` como el pico en el borde, `sparks.rate` como chispas visibles por
  segundo, `bursts` por chispa y `deformation` en mm: así se calcula ahora (antes: surco en la chapa, zona afectada
  metalúrgica, temperatura a 1 mm, chispas de 0 a 1 y deformación como diccionario).

## Revisión de código (una pasada, nivel medio)

Hallazgos corregidos: el exceso de velocidad ignoraba las rpm del propio disco (ahora mandan; el aviso dice si el
límite sale del disco, de la tabla o de la fórmula; `stripe` vacío en discos EN 13236); las citas de `sources` se
cortaban en el primer punto (ahora cada panel, familia térmica y clase de chispa lleva su `cite`); sin corte (disco
parado, sin empuje, empuje negativo, láminas) seguía habiendo calor, rebaba, desgaste o chispas, y en piedra un disco
parado cortaba (ahora todo a cero y aviso `sin_corte`); `work_iso: "H"` no cambiaba nada (ahora 700 HV, o `work_hv`);
el aviso de disco inadecuado recomendaba el grano del propio disco, escribía ids sin tildes y pasaba siglas a
minúsculas; el vidriado y el desgaste químico estaban escritos solo para el diamante (ahora salen de los datos de
`ABRASIVES`, y el SiC en acero avisa y se gasta); un tipo de pieza desconocido se llamaba «acero» y se daba por
férrico; un grado con el prefijo de otro sistema («P1000» en FEPA F) se buscaba igual; `absMode` salía con menos de
0,5 µm de surco; la tendencia a embotar no estaba marcada como estimación; potencias en kW en todo el módulo;
`_fmt(INF)` daba «In.fin.ity»; el aviso del pilar de boro dependía del id y repetía sus datos (ahora sale de
`press_hardened` y de los datos del panel).

No corregidos, con motivo: `cleanliness` es una escala de suciedad porque así la fija el contrato («0 limpio … 10
sucio»); `vs`/`vs_ms` y `feed_mm_s` son los nombres de los contratos de `cut_off` y `cut_panel`; `_fmt` y `_codes`
no se pueden mover a `core/shared/` ni a `tests/case.gd` desde esta unidad (petición abajo); un disco en un diámetro
que el fabricante no hace no es un error (se usa la tabla de EN 12413 y `disc_rpm` es null).

## Limitaciones

- Energía medida con discos Cubitron de 1 mm a ~70 m/s; se extrapola a otros espesores, velocidades y abrasivos.
- Calor por la fórmula de Adams: chapa fina sin pérdidas por convección ni radiación, a velocidad de avance alta;
  en cortes muy lentos sobrestima las bandas lejanas.
- Sin modelo del disco que se achica con el desgaste (baja la velocidad periférica), ni del corte en varias
  pasadas en `cut_panel`, ni de la humedad (discos de diamante en húmedo), ni del pandeo de la chapa.
- `heat_tint.temp_c` es el pico en el borde del surco, que el modelo fija por material: en acero siempre sale el gris
  del óxido; la gama de colores está en `bands`.

## Para el coordinador

1. Los `.uid` de mis cinco scripts van en el commit, como los de `core/shared/` (Godot los genera al importar).
2. Propongo completar en CONTRATOS.md la salida de `cut_panel` con la semántica de arriba y los campos que pidió la
   escena (`smoke`, `melt`, `burr_sides_um { lado_menos, lado_mas }`, `front_temp_c`), los avisos como
   `{ code, message, source }` y el abrasivo opcional `ceramico`. Ojo en la integración: la demo de la unidad 14
   (`demo_radial.gd`) escribe `str(warns[...])`; con el modelo real hay que escribir `w["message"]`.
3. El disco `laminas` no tronza (es de desbaste de cara): el modelo da `time_s = INF`, todo a cero y el aviso
   `disco_no_corta`. El sustituto de la unidad 14 lo hacía abrir una zanja; si se quiere esa escena, hay que decidir
   el ancho del borde del disco de láminas (no hay dato verificado).
4. La longitud y el color del chorro de chispas están en dos sitios de `core/taller/`: aquí (tabla de Steel
   Elements, × √(v/25,4 m/s)) y en `sparks.gd` de la unidad 14 (tabla 7-5, arrastre cuadrático). En la integración
   conviene que uno de los dos sea la única fuente; los estallidos ya usan la misma escala.
5. El encargo de Eric habla de «radiales de metal, cerámica, tungsteno y diamante». Metal, cerámica y diamante
   están; **discos de grano de carburo de tungsteno** no, por falta de datos verificados (queda pendiente). Tampoco
   hay discos de diamante soldado al vacío para metal ni cepillos, y los discos de CBN para radial PFERD solo los
   hace por encargo (sin datos): el CBN aparece en las recomendaciones, no en `DISCS`.
6. `cut_off()` acepta `work_hv` y `work_iso` ("H" = templado): si la unidad de materiales publica `hv` e `iso`, se
   pueden pasar tal cual.
7. Cada disco lleva sus rpm de PFERD (`rpm_by_diameter`, `Abrasives.disc_rpm`) y `MARKED_RPM` es la tabla de
   EN 12413: son dos fuentes a propósito. La interfaz debería ofrecer solo los diámetros de `rpm_by_diameter`.
8. Pido mover a la capa compartida el formato de números en español (`Radial._fmt`: coma decimal, punto de miles,
   «∞») y a `tests/case.gd` el ayudante `_codes` de los avisos, que hoy está repetido en mis dos tests.
9. Si alguien consigue el artículo de Awan et al. (2021, *Adv. Manuf.*, S235JR y C45K), conviene sustituir el SS201
   por el acero al carbono medido.
10. e2e: `scratchpad/u6/e2e_radial.gd` imprime la tabla de discos (Ø, v máx, franja, rpm marcadas, PFERD y
    fórmula), ejemplos de tronzado de acero de 3 mm con sus avisos y los cortes de carrocería (con chispas por
    segundo, deformación, fundido, humo y frente).
