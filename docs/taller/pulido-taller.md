# Taller · pulido de la física (fase 2, unidad 1h)

Especificación del pulido de la física del **Taller industrial**: la radial, el desgaste de la herramienta, la viruta,
el fresado y el taladrado, y la seguridad entre hilos del motor. Recoge los modelos, las ecuaciones, los datos con
su fuente, lo que se ha validado, lo que **no** predicen y la guía de integración para las unidades que los usan (el
torno, las páginas de fresado y taladrado, y la radial).

- Código: `godot/core/taller/{radial,sparks,abrasives,cutting,chips,wear}.gd`.
- Tests: `godot/tests/taller/{test_radial,test_cut_panel,test_sparks,test_cutting,test_chips,test_wear,test_pulido_taller_spec}.gd`.
- Casos de referencia para la integración: `godot/tests/fixtures/spec/pulido-taller.json` (38 casos, apartado 7).
- Reglas de siempre: cada dato lleva `source` y `quality` (`primary` · `secondary` · `estimate`); lo que no tiene
  medición publicada es **estimación**; si un caso publicado no sale, se documenta la discrepancia y no se ajusta
  ningún número. Simulador educativo: nada de esto es un procedimiento de taller ni de rescate.

## 1. Resumen

| Tema | Qué hay ahora | Resultados existentes que cambian |
|---|---|---|
| Radial · chispas | Una sola fuente: `Sparks.stream_for()` (TC 9-237, tabla 7-5) da volumen, longitud, color y estallidos al modelo (`cut_panel`) y al emisor de la escena | Sí, a propósito (apartado 2.1) |
| Radial · acero al carbono | Awan et al. (2021) verificado; no sustituye al SS201 como valor único; da la banda `specific_energy_band_j_mm3` | No (campo nuevo) |
| Radial · surco | Banda medida `kerf_band_mm` (1 mm de disco → 1,3-1,8 mm); el disco de láminas no tronza: no tiene ancho de corte | No (campo nuevo) |
| Radial · discos nuevos | `metal_duro` (PFERD DS Multi Power Carbide) y `cbn_1mm` (Tyrolit 1A1R, de tronzadora fija) | No (discos nuevos) |
| Desgaste | `wear.gd`: VB con el tiempo (curva publicada), Kver del TZ, rugosidad, fin de vida de ISO 3685 | No (módulo nuevo) |
| Viruta | `chips.gd`: rotura según el Spanformdiagramm del TZ, Spanraumzahl y aviso de filo recrecido | No (funciones nuevas) |
| Fresado y taladrado | Validados contra los ejemplos resueltos de Sandvik; campos de la interfaz comprobados | No |
| Multinúcleo | `cutting.gd` sin caché mutable (tabla de solo lectura); tests de 1 hilo = N hilos | No (mismos números al bit) |

## 2. Radial

### 2.1 Una sola fuente para la longitud y el color de las chispas

Antes había dos: `radial.gd` usaba la tabla de *Spark Testing for Mystery Metals* (Steel Elements, 2000) de
`panels.gd` (`SPARK_CLASSES`) con la longitud × √(vs/25,4 m/s), y el emisor `sparks.gd` la tabla 7-5 del TC 9-237
con arrastre cuadrático. Ahora **`Sparks.stream_for(material_id, vs_ms)`** es la única: devuelve
`{ family, known, volume, length_mm, color, color_name, color_end, color_end_name, bursts, bursts_name, burst_kind,
quality, source, cite }` y `cut_panel` la copia en `sparks` (solo pone `rate`, las chispas visibles por segundo, con
su caudal: `rate = 100 · volume · Q`).

- **Longitud** (la de siempre del emisor): la chispa arde el mismo tiempo t_ref que en el ensayo; si sale más deprisa,
  llega más lejos con arrastre cuadrático, `L(vs) = Lf·ln(1 + vs·t_ref/Lf)`, con `t_ref = (Lf/v_ref)·(e^(L_tabla/Lf) − 1)`,
  `Lf = 0,8 m` y `v_ref = 35 m/s` (estimaciones de la unidad 14). A 35 m/s da la longitud de la tabla.
- **Color:** la palabra de la tabla 7-5 junto a la muela y al final del haz → temperatura por la tabla V del TM 9-237
  → color de incandescencia (`heat_color`), en `#RRGGBB`. Nombres en español: rojo, naranja, naranja claro, amarillo
  anaranjado, paja, blanco.
- **Estallidos:** la escala de palabras de la tabla 7-5 (ninguna 0 · extremadamente pocas 0,03 · muy pocas 0,08 ·
  pocas 0,15 · moderadas 0,35 · muchas 0,7 · muchísimas 1,2, estimación de la unidad 14) y su forma (en horquilla o
  repetidas en estrella).

**Cambios de resultado, a propósito** (test `test_chispas_segun_el_material` actualizado):

| Chapa (Ø125 a 11.000 rpm, 72 m/s) | Antes (Steel Elements) | Ahora (TC 9-237) |
|---|---|---|
| Acero dulce y BH | 65 in (hierro dulce), 2.780 mm, «amarillo paja → blanco», muy pocas | fila AISI 1020, 70 in, **2.309 mm**, «amarillo anaranjado → blanco» (§7-3: estelas amarillo-naranja con horquillas blancas), pocas, en horquilla |
| DP800 | 65 in, volumen 1 | familia `acero_mn` (estimación de la unidad 14), 2.226 mm, moderadas |
| Pilar 22MnB5 | 60 in, volumen 0,9 | familia `acero_mn_b`, 2.119 mm, «paja → blanco», muchas, repetidas en estrella |
| Aluminio, plástico, perfil de aluminio | sin chispas | sin chispas (fila 15) |

`sparks.class` pasa a ser la familia de `sparks.gd` (`acero_bajo_c`…) y `sources` cita «TC 9-237 (1993), tabla 7-5
(ensayo de chispas)» en vez de Steel Elements. `Panels.SPARK_CLASSES` deja de usarse en el modelo (sigue en
`panels.gd`, que no es de esta unidad: ver apartado 12).

### 2.2 Energía del acero al carbono: Awan et al. (2021) verificado

**Ficha comprobada** (copia abierta en UPCommons; Crossref):

- Awan M.R., González Rojas H.A., Perat Benavides J.I., Hameed S. «Experimental technique to analyze the influence of
  cutting conditions on specific energy consumption during abrasive metal cutting with thin discs». *Advances in
  Manufacturing* 10(2):260-271, 2022 (en línea el 9-8-2021). doi:10.1007/s40436-021-00361-2.
- **Qué midieron:** tronzado con un disco fino de corindón (41 99A 46 S7 BF: Ø115 × 1 mm, grano 46, resina BF) en una
  radial Ryobi de 600 W montada en un carro con avance de motor paso a paso, a 0,539, 0,613, 0,899 y 1,488 mm/s, cuatro
  repeticiones; potencia mecánica deducida de la eléctrica con un dinamómetro de histéresis (Pm = 2,4·Ee − 742,61);
  potencia de deslizamiento medida parando el avance. Probetas: S235JR (80,05 HRB) de **3 mm** de ancho, C45K normal
  (100,20 HRB), templado (120,60) y templado y revenido (85,85) de 10 mm, e intermetálico Fe-Al40 (4,6 mm). Surco medido
  de **1,8 mm** con el disco de 1 mm (flexión y vibración con avances altos para ese disco).
- **Modelo y tabla 3:** `SEC = SCE + (Psl + Ppl)/Q` (J/mm³; Q en mm³/s).

| Acero | Psl (W) | Ppl (W) | SCE (J/mm³) | R² |
|---|---|---|---|---|
| S235JR | 29,16 | 163,69 | 37,50 | 0,956 |
| C45K | 127,36 | 152,18 | 4,16 | 0,872 |
| C45K templado | 99,36 | 228,04 | 7,82 | 0,912 |
| C45K templado y revenido | 117,36 | 216,21 | 4,93 | 0,923 |

**Por qué no sustituye a la fila del SS201** (Awan et al. 2022, *J. Mater. Res. Technol.* 18:3302,
doi:10.1016/j.jmrt.2022.03.185, disco Cubitron), que sigue siendo la energía del acero del modelo:

1. El S235JR —el acero al carbono que más se parece a la chapa de coche— se midió en **barras de 3 mm**. La tesis del
   propio autor (Awan M.R., *Specific energy consumption of metal cutting with thin abrasive discs*, UPC, 2021, anexo
   II.4) explica que con 3 mm de material la SEC sale «muy alta», la curva deja de ser asintótica y la SCE no es fiable
   (en Al 1100, al pasar de 3 a 9 mm la SCE baja a 9,7 J/mm³).
2. La SCE del C45K es **4,16 J/mm³** en el artículo y **12,3** en la tabla 6 de la tesis (y el S235JR, 37,5 frente a
   25,0), sin explicación de la diferencia.
3. A un mismo caudal las cuatro filas se dispersan un factor ~2,7 y **encierran** al SS201: con Q = 21 mm³/s (acero
   de 3 mm a 5 mm/s con el disco fino) el C45K da 17,5 J/mm³, el S235JR 46,7 y el modelo (SS201) 24,4, cerca de los
   ~25 J/mm³ típicos de Rowe et al. (2003).

Por eso las medidas de 2021 se usan como **banda de incertidumbre**, igual que la banda de kc del corte:
`specific_energy_band_j_mm3 = [mín, máx]` sobre la energía del modelo y las cuatro filas, evaluadas al caudal del
corte y con el mismo factor de embotamiento. Se evalúan sin escalar con la velocidad (Awan no publica las rpm de su
radial). Aluminio: la banda va del 1100 al 7075 (2022). Inox y níquel: una sola medida (banda de anchura cero). Sin
corte, `[0, 0]`.

### 2.3 Ancho de corte

- **Discos aglomerados:** el surco sigue siendo espesor + 0,4 mm (1,4 mm con el disco de 1 mm). Nueva banda medida
  `kerf_band_mm = [espesor + 0,3, espesor + 0,8]`: 1,3-1,5 mm (Awan et al. 2022, *Sensors* 22:7152) y 1,8 mm (Awan et
  al. 2021). Suponer la misma holgura en otros espesores es una estimación.
- **Disco de láminas (`laminas`):** **no hay ancho de corte que verificar**, porque no es un disco de tronzar. PFERD
  (Tool Manual 26, catálogo 6, p. 23) da el ángulo de trabajo del plano PFF, de **0 a 15°** (el cónico PFC, de 10 a
  25°), y ninguna anchura de borde; EN 62841-2-3 manda usar cada disco solo para lo que indica el fabricante. Se deja
  como estaba (no corta, aviso `disco_no_corta`) y se añade `work_angle_deg: [0, 15]` al disco. Si la escena quiere
  enseñar el disco de láminas, que sea desbastando una superficie con ese ángulo, no abriendo una zanja.

### 2.4 Discos de metal duro y de CBN

| id | Disco | Datos | Calidad |
|---|---|---|---|
| `metal_duro` | PFERD DS Multi Power Carbide (novedad) | Ø125 (5 in), cuerpo de acero T = 1,14 mm, borde de grano X = **1,905 mm** (el que corta; surco 2,3 mm con la holgura), 12.200 rpm (80 m/s); grano de carburo de tungsteno soldado; para madera con clavos, plásticos, no férricos y construcción en seco; «diámetro constante», vida larga | primary (catálogo 5, p. 23) |
| `cbn_1mm` | Tyrolit, forma 1A1R, 125 × 1 × 20, 51B 126 C75 B 53 ST | grano CBN B126 con resina, **50 m/s**, **en húmedo y en tronzadora fija**, para acero rápido; agujero de 20 mm (no entra en una radial) | secondary (fichas de los distribuidores SKS, art. 788700, y Hoffmann Group, art. 364801) |

- Grano nuevo `carburo_w` en `ABRASIVES`: HV 2000 y E 620 GPa, los del carburo de tungsteno del laboratorio 1.x
  (`data.js`, INLAYS); Hyperion da de ~700 a 2.200 HV30 para los metales duros. **Sin Knoop publicada: `hk = null`**
  (el test de dureza de los abrasivos se ha ajustado para admitirlo, en vez de inventar un valor). Fuera de
  `RECOMMEND`: es un disco de construcción y bricolaje, no un grano de muela.
- En las chapas: el de metal duro corta aluminio y plástico sin embotarse (resistencia al embotamiento 0,8,
  estimación) y en acero avisa de `disco_inadecuado` (el fabricante no lo vende para acero). Relación G supuesta de 20
  (estimación: el grano soldado no mengua).
- El de CBN no se fabrica para radial (PFERD los hace solo por encargo, catálogo 5): el modelo lo **enseña** con su
  límite real. Solo marca la velocidad (`rpm_marked: false`): manda la fórmula, 7.639 rpm en Ø125; a 11.000 rpm va a
  72 m/s (`exceso_velocidad`). Siempre avisa `disco_fijo` («para tronzadoras fijas y en húmedo… su agujero de 20 mm ni
  siquiera entra en la brida de 22,23 mm»). Por debajo de 50 m/s, en el pilar de boro apenas se gasta (G = 100) y
  calienta menos la chapa (R_ws = 0,5, Rowe et al. 2003).
- `disc_check`: la tabla de marcado de EN 12413 ya solo se aplica a discos de EN 12413; un disco de otra norma sin rpm
  propias en ese diámetro usa la fórmula (y el aviso dice «máximas», no «marcadas»).

### 2.5 Qué no predice la radial (además de lo de `fuentes-u6.md`)

- La energía del acero al carbono con más precisión que su banda (factor ~2,7 entre medidas).
- El surco de discos de otros espesores (holgura supuesta igual) y el de discos de cuerpo de acero.
- El rendimiento real del disco de metal duro y del de CBN (relación G y embotamiento: estimaciones).
- Chispas: el número real de partículas, su tamaño (arrastre supuesto de una gota de ~100 µm) y la velocidad de la
  muela del ensayo (35 m/s supuestos; el TC 9-237 pide al menos 25 m/s).

## 3. Desgaste de la herramienta (`core/taller/wear.gd`)

### 3.1 Modelo

1. **Vida T** (min, hasta VB_B = 0,3 mm): Taylor `vc·T^n = C` con n del TZ (p. 215: k = −7 HSS, −4 metal duro y −2
   cerámica en acero; −3,5 en fundición y −2,5 en aluminio) y C de `tool_materials.gd` (vcT15 = centro del intervalo
   de vc: **estimación**). `Wear.life(tool_id, work_id, vc)`.
2. **Fin de vida:** ISO 3685:1993, **VB_B = 0,3 mm** (desgaste regular) o **VB_Bmax = 0,6 mm** (irregular), los
   criterios «más usados» con metal duro (citados por Equeter et al. 2020). El TZ (p. 214) da un VB admisible de 0,2 a
   0,8 mm y traza su recta de vida «p. ej. para VB = 0,4 mm»: el modelo sigue a la norma.
3. **Forma de VB(t):** la curva medida por Equeter et al. (2020) (AISI 1045 recocido de 154 HV30, Seco
   CNMG120408-MF5 TP2500 P10 recubierto, vc 365 m/min, f 0,4, ap 0,7, en seco; fin de vida a los 25,35 min). La figura
   8 se ha digitalizado a mano (±0,01 mm) y hecho monótona (el desgaste no retrocede: las bajadas 0,186 → 0,179 y
   0,200 → 0,192 son dispersión de medida y se sustituyen por su media). El tiempo se escala con la vida,
   `τ = t/T`; la curva cruza 0,3 mm en τ = 1 (25,378 min en la digitalización). Con otros pares herramienta-material se
   supone la **misma forma** (estimación): rodaje rápido, tramo estable y desgaste acelerado, la evolución de siempre
   (Equeter, fig. 3, de Altintas 2012).

| t (min) | 0 | 0,95 | 1,95 | 2,81 | 4,18 | 5,01 | 7,02 | 8,94 | 10,89 | 12,89 | 14,87 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VB_B (mm) | 0 | 0,075 | 0,085 | 0,100 | 0,106 | 0,121 | 0,130 | 0,139 | 0,166 | 0,1825 | 0,1825 |

| t (min) | 16,85 | 18,71 | 20,63 | 22,58 | 24,53 | 25,59 | 26,50 | 27,48 | 28,42 | 29,37 | 30,34 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VB_B (mm) | 0,196 | 0,196 | 0,201 | 0,210 | 0,252 | 0,312 | 0,319 | 0,425 | 0,467 | 0,635 | 0,684 |

   Etapas (`Wear.stage`): «rodaje» hasta τ = 0,197 (5,01 min, VB 0,12 mm), «estable» hasta τ = 0,890 (22,58 min,
   VB 0,21 mm) y «acelerado» después. Más allá de la curva medida (τ ≈ 1,2) no se extrapola: VB se queda en su último
   valor, 0,684 mm (la herramienta está muerta desde τ = 1 y en la realidad acabaría rompiéndose, que no se modela).
4. **Condiciones variables** (G96, cambios de vc, varias pasadas): fracción de vida consumida `D = Σ Δt/T(vc)`
   (acumulación lineal, **estimación**) y `VB = curva(D)`.
5. **Fuerzas:** el TZ da **Kver = 1,2 a 1,5** (p. 208; su ejemplo usa 1,2 con «desgaste ligero») sin unirlo a un VB.
   Se reparte sobre su VB admisible (0,2-0,8 mm, p. 214), extremo con extremo (**estimación**):
   `Kver = 1 + VB` hasta 0,2 mm, `1,2 + 0,5·(VB − 0,2)` hasta 0,8 mm y 1,5 por encima. En el fin de vida de ISO 3685
   (0,3 mm) da **1,25**. Kver multiplica kc (y Fc), como en el TZ.
6. **Rugosidad:** `Ra(VB)/Ra(filo nuevo) = 1 + (2,674/2,716)·VB`, la recta de mínimos cuadrados de la figura 10 de
   Equeter et al. (2020) (16 puntos digitalizados; r = 0,95, **el mismo coeficiente de Pearson que publica el
   artículo**). Se aplica a la Ra teórica del filo nuevo: en el fin de vida, **+30 %**.

### 3.2 Discrepancia documentada: Kver del TZ frente al caso medido

En el mismo ensayo de Equeter (diapositivas de ASM MS&T 2019), del primer al último pase (VB de ~0,075 a ~0,684 mm)
las fuerzas subieron **Fc +9 %, Ff +40 % y Fp +10 %** (RMS de cada pase). Con el reparto del TZ, a 0,684 mm Kver sería
1,44: el TZ es un **factor de diseño conservador** (para no quedarse corto de potencia), no la curva de un ensayo; y el
aumento relativo depende del avance (la franja de desgaste añade una fuerza ∝ VB·b, la viruta ∝ f·b: con f = 0,4 mm,
como en el ensayo, el aumento relativo es pequeño). El modelo sigue al TZ (la fuente principal del corte) y da la
banda: `kver_band = [1 + 0,149·VB, Kver del TZ]`, además de `ff_factor = 1 + 0,691·VB` y `fp_factor = 1 + 0,166·VB`
(el caso medido; estimaciones fuera de él).

### 3.3 API

```gdscript
const Wear = preload("res://core/taller/wear.gd")
Wear.life(tool_id, work_id, vc) -> { life_min (INF parado; null sin datos), n, C, quality, source, reason }
Wear.vb_at_fraction(tau) -> float          # VB_B (mm) con la fracción de vida τ (τ = 1 → 0,3 mm)
Wear.fraction_at_vb(vb) -> float           # inversa (INF por encima de 0,684 mm)
Wear.stage(tau) -> "rodaje" | "estable" | "acelerado"
Wear.kver_for_vb(vb) -> float              # Kver del TZ (1 … 1,5)
Wear.ra_factor_for_vb(vb) -> float         # Ra(VB)/Ra(filo nuevo)
Wear.effects(vb) -> { vb_mm, kver, kver_band, ff_factor, fp_factor, ra_factor, end_of_life, end_of_life_max,
                      quality: "estimate", sources }
Wear.new_state() -> { used: 0, cut_s: 0, vb_mm: 0, stage: "rodaje", end_of_life: false }
Wear.step(state, dt_s, vc, tool_id, work_id) -> { used, cut_s, vb_mm, stage, end_of_life, life_min, remaining_min,
                      kver, ra_factor, quality, warnings }   # estado nuevo; no toca el de entrada
Wear.after(t_min, vc, tool_id, work_id) -> lo mismo, de una vez a vc constante
Wear.minutes_to_vb(vb, vc, tool_id, work_id) -> float | null   # INF si no se alcanza; null sin datos de vida
Cutting.cutting_model_worn(work_id, tool_id, h_mm, b_mm, vc, kver = 1) -> cutting_model con kc y Fc × Kver (Kver
                      limitado a 1-1,5, el intervalo del TZ), + kver
Cutting.model_callable_worn(kver) -> Callable      # misma firma que model_callable(), con el Kver ligado
```

Sin giro o sin avance (vc ≤ 0 o dt ≤ 0) no hay desgaste. Sin datos de vida (madera, plástico, vidrio, piedra; una
herramienta sin intervalo de vc para ese grupo ISO, p. ej. PCD en acero) no se inventa desgaste: `used` no crece (el
tiempo de corte `cut_s`, sí) y hay aviso. Avisos: «Desgaste acelerado (VB = … mm)» y «Fin de vida: … (criterio de ISO 3685: 0,3 mm). Hay que girar o
cambiar la plaquita».

Ejemplo (C45E con metal duro recubierto a 180 m/min, su vcT15): T = 15 min; a los 5 min VB ≈ 0,137 mm (Kver 1,14,
Ra × 1,13); a los 15 min, 0,3 mm (Kver 1,25, Ra × 1,30, fin de vida). A 250 m/min la vida baja a ~4 min.

### 3.4 Qué no predice

- La vida absoluta (C de Taylor estimada; sin Taylor extendido con f y ap, porque el TZ solo da la pendiente en vc).
- El desgaste de cráter, el de entalla, el filo astillado o roto y la deformación plástica del filo: solo el de flanco.
- La forma de la curva en otros materiales y herramientas (una sola curva medida, escalada).
- El efecto del desgaste en Ff y Fp más allá del caso medido, y la subida de temperatura del filo.
- Fresado y taladrado: ISO 3685 es para el torneado con herramienta de un filo; en fresado y taladrado se usa el mismo
  umbral (estimación) y el tiempo que se pasa es el de corte con el husillo girando.

## 4. Viruta: rotura y filo recrecido (`core/taller/chips.gd`)

### 4.1 Rotura de la viruta (Spanformdiagramm del TZ)

No hay ábacos de rompevirutas de fabricante en abierto con los que cotejar; sí el **Spanformdiagramm** del propio
*Tabellenbuch* (p. 204): ap frente a f para el **C45 a vc = 200 m/min**, con la zona de viruta favorable del criterio
de rotura y, dentro, la del criterio de superficie. Digitalizado (±0,05 mm en ap, ±0,01 mm en f), en [ap, f] (mm):

- zona de rotura: [1, 0,200] · [3,55, 0,154] · [6, 0,241] · [6, 0,656] · [3,65, 0,709] · [1, 0,709];
- zona de superficie: [1, 0,200] · [2,09, 0,182] · [3,98, 0,265] · [4,01, 0,303] · [1, 0,633].

`Chips.chip_breaking({ work_id | kind, f_mm, ap_mm, vc })` → `{ zone, surface_ok, form, tz_form, tz_class,
chip_ratio_min, quality, source, message }`:

| zone | Cuándo | Forma (TZ, p. 203) | Se dibuja |
|---|---|---|---|
| `favorable` | dentro de la zona de rotura (el borde cuenta como dentro); `surface_ok` si además está en la de superficie | helicoidal corta, favorable, Spanraumzahl ≥ 25 | `rizada` |
| `viruta_larga` | f por debajo del borde inferior o ap < 1 mm: la viruta es demasiado fina o estrecha para romper | enredada, desfavorable, Spanraumzahl ≥ 90 | `espiral` |
| `fuera_del_diagrama` | por encima (f ≳ 0,7 mm o ap > 6 mm): el TZ no da datos | — | la de su grupo |
| `sin_datos` | material que no es acero, o sin avance | — | la de su grupo (`KINDS`, ISO 3685 anexo G) |

Calidad: `secondary` para el C45E a 200 ± 50 m/min; `estimate` para otros aceros u otras vc. `Chips.form_for_cut(kind,
f, ap, vc)` da la forma que se dibuja; `TZ_CHIP_FORMS` recoge las diez formas del TZ con su clase y su **Spanraumzahl**
R (volumen de viruta suelta / volumen arrancado: ≥ 90 cinta y enredada, ≥ 50 helicoidal plana y larga, ≥ 25 helicoidal
corta, ≥ 8 espiral y rizos, ≥ 3 fragmentos), útil para llenar la bandeja de virutas.

### 4.2 Filo recrecido

Sandvik Coromant («Wear on cutting edges»): el filo recrecido es la viruta soldada a presión al filo, **más común en
materiales pegajosos —acero de bajo carbono, inoxidable y aluminio—**, y la **vc baja** lo favorece. El TZ (p. 213) lo
pone bajo la adhesión. No hay un umbral numérico general publicado; el aviso usa (estimación) el **mínimo del intervalo
de vc recomendado de la herramienta** en el grupo ISO del material (TZ, p. 208: HSS 30-60, metal duro 60-300 y
cerámica 180-500 m/min en acero). Lo respalda Ahmed et al. (2017, *Materials* 10:1230, doi:10.3390/ma10111230), que
**provocan** el filo recrecido en AISI 304 con metal duro sin recubrir a 60 m/min, justo ese mínimo.

`Chips.bue_risk({ work_id | kind, tool_id, vc })` → `{ risk, vc_limit, message, quality: "estimate", source }`: riesgo
si el material es pegajoso y `0 < vc ≤ vc_limit`. Fundición, latón, titanio, níquel y no metales: sin aviso (no están
en la lista de Sandvik). Herramienta sin intervalo de vc para ese grupo: no se evalúa.

### 4.3 Qué no predice

- La rotura con un rompevirutas concreto (cada geometría de plaquita tiene su ábaco f-ap del fabricante).
- La forma en otros materiales (solo hay diagrama del C45), en fresado y en taladrado.
- El tamaño del filo recrecido, su efecto cuantitativo en la rugosidad o en las cotas, y el umbral de vc en cada caso.

## 5. Fresado y taladrado (`cutting.gd`): validación para la interfaz

Los modelos no cambian. Se han comprobado contra casos publicados (tests en `test_cutting.gd` y casos en el JSON):

| Caso | Fuente | Publicado | Modelo |
|---|---|---|---|
| Planeado a 45° de acero CMC 01.3: potencia en el motor | Sandvik 2005, p. D25 | 27,0 kW; con +21°, 21,3 kW | 27,0 y 21,3 (21,6 netos) |
| Planeado R245-125Q40-12M, vc 283, fz 0,24 | Sandvik 2005, p. D26 | n ≈ 721 rpm, vf ≈ 1384 mm/min, hex 0,17 | 720,7 · 1383,7 · 0,170 |
| Selección de datos, HB 180, vc 262 | Sandvik 2005, p. D22 | n = 667, vf ≈ 1281 | 667,2 · 1281,0 |
| Ranurado R390-063Q22-17M, vc 250, fz 0,15 | Sandvik 2005, p. D27 | n ≈ 1263, vf ≈ 947, hex = fz | 1263,1 · 947,4 · 0,150 |
| Planeado lateral, ae = 5 mm, vc 318, fz = 1,82 × 0,15 | Sandvik 2005, p. D27 | n ≈ 1607, vf ≈ 2193, hex = 0,15 | 1606,7 · 2193,2 · 0,148 |
| Taladrado Dc 20, vc 200 | Sandvik, fórmulas de taladrado | n = 3184 | 3183,1 |
| kc del 42CrMo4 y Pc = 8,4 kW | TZ pp. 208 y 212 | 4011 N/mm² · 8,4 kW | 4011,8 · 8,4 |

**Discrepancias encontradas (documentadas, sin ajustar números):**

1. **Adelgazamiento de la viruta en el fresado lateral.** Sandvik sube fz con un factor k1 de tabla (1,82 con
   Dc/ae = 12,6); la geometría exacta del contacto da 1/sen(acos(1 − 2·ae/Dc)) = **1,85**: con el fz de Sandvik, hex
   sale un 1,6 % menor. El modelo usa la geometría exacta.
2. **Caudal del taladrado en el TZ.** El ejemplo de la p. 204 (broca de plaquitas de dos filos, D = 40, f = 0,16,
   vc = 100, Pc medida 8,1 kW) calcula Q = A·vc con A = D·f/2 = 3,2 mm²: 320 cm³/min. El volumen que se arranca es
   π·D²/4·f·n = D·f·vc/4 = **160 cm³/min** (el filo corta, de media, a vc/2), que es lo que da Sandvik y el modelo. El
   ejemplo no dice el material, así que su Pc no sirve para validar kc.
3. **Tablas orientativas de potencia del TZ (p. 212).** No siguen el Kienzle del propio libro: en torneado Fc = 36·d
   N (720 N con d = 20 y f = 0,1; 1800 N con d = 50 y f = 0,3), sin depender de f; en taladrado Fc/(D·f) va de 720 a
   1680 N/mm². Solo sirven como orden de magnitud contra errores de unidades: con C45E el modelo queda dentro de un
   factor 2 en las tres tablas (con S235JR, d 50 y f 0,3: 1835 N frente a 1800).
4. El fresado con kc del TZ da un 27-53 % más que Sandvik (ya documentado en `fuentes-u5.md`): es la dispersión entre
   fuentes que enseña la banda de kc.

## 6. Multinúcleo

- `cutting.gd` tenía `static var _model_cache := {}`, escrita desde cualquier hilo. Ahora es `_model_table`, calculada
  **una vez** al cargar el script para todas las parejas material-herramienta de los catálogos (que son constantes) y
  **congelada** con `make_read_only()`: se lee sin cerrojos. Una pareja desconocida se calcula en cada llamada y no se
  guarda. Mismos resultados (test: la tabla es igual a calcular cada pareja en el momento).
- Los demás módulos de esta unidad no tienen estado estático: `radial.gd`, `abrasives.gd`, `wear.gd` y las funciones
  de física de `chips.gd` y de `sparks.gd` son puras; los emisores de `chips.gd` y `sparks.gd` son objetos con su propio
  estado (uno por escena).
- Tests de «1 hilo = N hilos, al bit» con `WorkerThreadPool.add_group_task` (el patrón de `tools/bench.gd`):
  `cutting_model` (2, 4 y 8 hilos, con parejas desconocidas), `turning`/`milling`/`drilling`, `cut_panel` con todos los
  discos, chapas, rpm y ángulos (más `stream_for` y `chip_breaking`), y el desgaste.
- Otros `static var` mutables del núcleo que no son de esta unidad: `lathe_mesh.gd` (`_bias32`) y `machine_sound.gd`
  (`_sheet_key_hz`, `_ref_hz`) (apartado 12).

## 7. Casos de referencia (`godot/tests/fixtures/spec/pulido-taller.json`)

Un array de 38 casos con el formato de `CONTRATOS.md`:

```json
{ "id": "corte.fresado_sandvik_planeado_r245",
  "input": { "fn": "Cutting.milling", "args": { "work_id": "c45e", "tool_id": "hm_coated", "dc_mm": 125, … } },
  "expect": { "rpm": { "value": 721, "tol": 0.0007 }, "hex_mm": { "value": 0.17, "tol": 0.003 } },
  "source": "Sandvik Coromant, Metalcutting Technical Guide (D) Milling (2005), p. D26 …" }
```

- `input.fn` es la función del núcleo (`Cutting.*`, `Wear.*`, `Chips.*`, `Radial.*`, `Sparks.*`) y `input.args` sus
  argumentos (un diccionario, o los argumentos por nombre en las funciones que no reciben un diccionario; ver
  `run_case()` en `tests/taller/test_pulido_taller_spec.gd`). Las que devuelven un número se envuelven:
  `Cutting.cutting_power_kw` → `{ pc_kw }`, `Wear.vb_at_fraction` → `{ vb_mm }`.
- `expect`: `value` (con `tol` relativa si es un número; sin `tol`, igualdad exacta), `min` y `max`. Un campo con
  puntos entra en diccionarios y listas: `sparks.length_mm`, `kc_parts.Kgamma`, `kerf_band_mm.0`.
- Grupos: `corte.*` (14: TZ y Sandvik), `desgaste.*` (7), `viruta.*` (7), `radial.*` (9) y `chispas.*` (1).
- `test_pulido_taller_spec.gd` comprueba el formato y que el núcleo los cumple todos. Un test de integración de otra
  unidad puede usar su `run_case()` y `field()` o repetirlos con sus propios datos. Si un caso no se cumple, se discute
  con el ingeniero físico: no se ajusta el número.

## 8. Guía de integración

### 8.1 Torno (unidad 1d: `lathe.gd`, `workshop_state.gd`, página y escena del torno)

- **Desgaste por paso:** guardar un `Wear.new_state()` por plaquita (por `tool_id` de la torreta) y, en cada paso con
  la herramienta cortando, `state = Wear.step(state, dt_s, vc, plaquita.tool_material, work_id)` con la vc real de ese
  paso (con G96 cambia con el diámetro). El tiempo es el de corte, no el de rápidos ni el de espera.
- **Fuerzas y potencia:** pasar el Kver al modelo, sin cambiar el contrato: o bien llamar a
  `Cutting.cutting_model_worn(work, tool, h, b, vc, state.kver)`, o bien volver a pedir
  `Cutting.model_callable_worn(state.kver)` cuando cambie el desgaste (misma firma que `model_callable()`). La
  potencia sigue siendo `Pc = kc·ΔV/Δt`.
- **Rugosidad:** multiplicar la Ra de cada anillo recién mecanizado (`ring_ra`) por `state.ra_factor` (Rt igual, si se
  guarda). Es un factor sobre la Ra del filo nuevo; no mueve las crestas simuladas.
- **Alarma o aviso de fin de vida:** con `state.end_of_life`, un aviso (propuesta: `TOOL_WORN`, «Fin de vida de la
  plaquita T1: VB = 0,30 mm (ISO 3685)») sin detener el programa; `state.warnings` trae el texto. Al cambiar o girar la
  plaquita, `Wear.new_state()`.
- **Qué enseñar:** VB (mm, 2 decimales) con una barra hasta 0,3 mm, la etapa (rodaje, estable, acelerado), la vida que
  queda a la vc actual (`remaining_min`), Kver, y la marca de estimación (`quality`). En la vista 3D se puede ensanchar
  una franja gris en el flanco de la plaquita con `vb_mm`.
- **Virutas:** `Chips.form_for_cut(kind, f, ap, vc)` para la forma (en acero sigue al diagrama del TZ) y
  `Chips.chip_breaking(...)` para el aviso de viruta larga («viruta larga y enredada…»). `chip_ratio_min` sirve para lo
  que ocupa la viruta en la bandeja (volumen = R · Q).
- **Filo recrecido:** `Chips.bue_risk({ work_id, tool_id, vc })` con la vc real; con `risk`, aviso (`message`).

### 8.2 Fresadora y taladro (unidad 1e: `mill_page.gd`, `drill_page.gd`, `mill_drill_state.gd`)

`Cutting.milling()` y `Cutting.drilling()` bastan; sus nombres y tipos no cambian. Campos que conviene enseñar:

| Página | Campos (unidad) |
|---|---|
| Fresado | `rpm` (rpm), `vc` (m/min), `vf_mm_min` (mm/min), `fz_mm`, `hm_mm` y `hex_mm` (mm), `zc` (dientes en contacto), `kc` (N/mm²) con `band`, `fc_mean_n` (N), `pc_kw` y `pmotor_kw` (kW), `torque_nm` (N·m), `q_cm3_min` (cm³/min), `tooth_hz` (Hz), `life_min` (min, «estimación»), `overload`, `rpm_limited`, `warnings`, `sources`, `quality` |
| Taladrado | `rpm`, `vc`, `vf_mm_min`, `h_mm`, `kc` con `band`, `fc_edge_n` (N por filo), `thrust_n` (empuje, N), `torque_nm`, `pc_kw`, `pmotor_kw`, `q_cm3_min`, `life_min`, `overload`, `rpm_limited`, `warnings`, `sources`, `quality` |

- **Desgaste:** pasar `wear: Wear.kver_for_vb(vb)` (un número entre 1 y 1,5; entre 1 y 1,2 ya no avisa de «fuera del
  intervalo del TZ») y llevar el estado con `Wear.step(state, dt_s, vc, tool_id, work_id)` durante el tiempo de corte.
- **Filo recrecido:** `Chips.bue_risk` también vale para el fresado y el taladrado (usa el intervalo de vc de la
  herramienta). El diagrama de rotura de la viruta es de torneado: en fresado y taladrado no se usa.
- **Máquina:** `machine: { pmax_kw, rpm_max, eta }` para los avisos de sobrecarga y tope de giro.
- Casos para sus tests: `corte.fresado_*` y `corte.taladrado_*` del JSON.

### 8.3 Radial (página, escena `radial_3d` y `workshop_state.gd`)

- **Campos nuevos** de `cut_panel` y `cut_off`: `kerf_band_mm` y `specific_energy_band_j_mm3` (se pueden enseñar como
  «surco 1,4 mm (medido 1,3-1,8)» y «energía 24 J/mm³ (medidas 17-47)»). El resto del contrato no cambia.
- **Chispas:** la escena puede seguir pasando `result.sparks` al emisor: ahora el modelo y el emisor dan el mismo haz.
  `sparks.class` es la familia de `sparks.gd`. Para otras máquinas (afiladora), `Sparks.stream_for(acero, vs)` da el
  haz de un acero a una velocidad del borde.
- **Discos nuevos:** `metal_duro` y `cbn_1mm` en `Abrasives.DISCS` (no están en `WorkshopState.RADIAL_DISCS`). Si se
  añaden a la interfaz: `rpm_by_diameter` tiene al menos un diámetro en los dos; el CBN va siempre con el aviso
  `disco_fijo` y, a las rpm de la radial, con `exceso_velocidad` (es lo que se quiere enseñar). La escena no tiene
  aspecto propio para ellos (`radial3d/looks.gd` cae en el del disco fino, con el espesor del núcleo).
- **Disco de láminas:** sigue sin tronzar; `work_angle_deg: [0, 15]` para una escena de desbaste de superficie.
- **Código de aviso nuevo:** `disco_fijo`.

## 9. Qué no predice (resumen)

La vida absoluta de la herramienta; el desgaste que no es de flanco; la forma de la curva de desgaste fuera del caso
medido; el efecto del desgaste en Ff, Fp y la temperatura; la rotura de la viruta con un rompevirutas concreto y en
materiales que no son acero; el tamaño del filo recrecido y su umbral en cada caso; la energía del acero al carbono en
el tronzado mejor que un factor ~2,7; el surco de otros discos; el rendimiento real de los discos de metal duro y CBN;
el número y el tamaño reales de las chispas.

## 10. Fuentes

| Fuente | Qué se usa | Acceso |
|---|---|---|
| Awan M.R., González Rojas H.A., Perat Benavides J.I., Hameed S. (2022, en línea 2021), *Adv. Manuf.* 10(2):260-271, doi:10.1007/s40436-021-00361-2 | tabla 3 (S235JR y C45K), tabla 2 (HRB), disco, avances, surco de 1,8 mm | [UPCommons](https://upcommons.upc.edu/server/api/core/bitstreams/7b1ea3f2-ab41-45b3-866d-706ececca611/content) |
| Awan M.R. (2021), *Specific energy consumption of metal cutting with thin abrasive discs*, tesis doctoral, UPC | anexo II.4 (probetas de 3 mm), tabla 6 | [UPCommons](https://upcommons.upc.edu/server/api/core/bitstreams/f1d3d588-3930-4643-b336-cbc2603d49e8/content) |
| Awan M.R. et al. (2022), *J. Mater. Res. Technol.* 18:3302-3310, doi:10.1016/j.jmrt.2022.03.185 | SS201, Al 1100, Al 7075, Inconel 718 (ya en `radial.gd`) | [UPCommons](https://upcommons.upc.edu/server/api/core/bitstreams/e07aedba-d4f8-4802-a4d2-95ccf4c124dc/content) |
| Awan M.R. et al. (2022), *Sensors* 22:7152 | surco de 1,3-1,5 mm con disco de 1 mm | [PMC9570719](https://pmc.ncbi.nlm.nih.gov/articles/PMC9570719/) |
| Equeter L., Devlamincq R., Ducobu F., Dutoit C., Dehombreux P. (2020), *Materials Science Forum* 986:93-101, doi:10.4028/www.scientific.net/MSF.986.93 | curva VB(t) (fig. 8), Ra frente a VB (fig. 10, r = 0,95), ISO 3685 citada | [ORBi UMONS](https://orbi.umons.ac.be/bitstream/20.500.12907/1034/1/MSF.986.93.pdf) |
| Equeter L. (2019), «Cutting Inserts Wear Monitoring in AISI 1045 Dry Longitudinal Turning through Cutting Forces: a Case Study», ASM MS&T 2019 (diapositivas) | Fc +9 %, Ff +40 %, Fr +10 % | [ORBi UMONS](https://orbi.umons.ac.be/bitstream/20.500.12907/14644/1/preview.PDF) |
| ISO 3685:1993, *Tool-life testing with single-point turning tools* | VB_B = 0,3 mm, VB_Bmax = 0,6 mm (a través de Equeter et al. 2020) | norma |
| *Tabellenbuch Zerspantechnik*, 1.ª ed., Europa-Lehrmittel, 2015 (ISBN 978-3-8085-1473-3) | Kver 1,2-1,5 (p. 208), VBzul 0,2-0,8 mm y recta de vida (pp. 214-215), formas y Spanraumzahl (p. 203), Spanformdiagramm (p. 204), tablas de potencia (p. 212), adhesión (p. 213) | [extracto oficial pp. 199-215](https://beckassets.blob.core.windows.net/product/readingsample/15052006/9783808514733_excerpt_004.pdf) |
| Sandvik Coromant, *Metalcutting Technical Guide (D) Milling*, 2005 | ejemplos resueltos (pp. D22, D25-D28) | [PDF](https://dcngli4g50fhp.cloudfront.net/userfiles/ad/sandvik/documents/sandvik_5747275_catalog.pdf) |
| Sandvik Coromant, fórmulas de taladrado | n, vf, Q, Pc, Mc, Ff; Dc 20 a 200 m/min → 3184 rpm | [web](https://www.sandvik.coromant.com/en-gb/knowledge/machining-formulas-definitions/drilling-formulas-definitions) |
| Sandvik Coromant, «Wear on cutting edges» | filo recrecido: materiales pegajosos, vc baja | [web](https://www.sandvik.coromant.com/en-gb/knowledge/materials/wear-on-cutting-edges) |
| Ahmed Y.S., Fox-Rabinovich G., Paiva J.M., Wagg T., Veldhuis S.C. (2017), *Materials* 10(11):1230, doi:10.3390/ma10111230 | filo recrecido en AISI 304 a 60 m/min | [PMC5706177](https://pmc.ncbi.nlm.nih.gov/articles/PMC5706177/) |
| PFERD, Tool Manual 26, catálogo 5 «Diamond and CBN tools» (EE. UU.), p. 23 | DS Multi Power Carbide; CBN solo por encargo | [PDF](https://assets.pferd.com/pfd/products/pdfs/tm-26-catalogue-5-web-en-us.pdf) |
| PFERD, Tool Manual 26, catálogo 6 «Cut-off wheels, flap discs and grinding wheels» (EE. UU.), p. 23 | ángulo de trabajo de los discos de láminas | [PDF](https://assets.pferd.com/pfd/products/pdfs/tm-26-catalogue-6-web-en-us.pdf) |
| Tyrolit, disco de CBN 1A1R (fichas de SKS, art. 788700, y Hoffmann Group, art. 364801) | 125 × 1 × 20, B126, 50 m/s, en húmedo, tronzadora fija | [SKS](https://www.shop-sks.com/TYROLIT-Trennen-von-Rotierenden-Werkzeugen-DxTxH-125x1x20-Fuer-HSS-Form-1A1R-Trennscheibe-mit-durchgaengigem-Schneidrad-Art.-788700) · [Hoffmann](https://www.hoffmann-group.com/US/en/hus/p/364801-) |
| Hyperion Materials & Technologies, «Cemented carbide hardness» | 700-2.200 HV30 | [web](https://www.hyperionmt.com/en/Resources/materials/cemented-carbide/cemented-carbide-hardness/) |
| Headquarters, Department of the Army (1993), *TC 9-237*, §7-3 y tabla 7-5; (1967) *TM 9-237*, tablas IV y V | ensayo de chispas y colores de calor (ya en `sparks.gd`) | ver `fuentes-u14.md` |
| Rowe W.B., Morgan M.N., Batako A., Jin T. (2003), *WIT Trans. Eng. Sci.* 44 | ~25 J/mm³ típico; R_ws 0,9 y 0,5 (ya en `radial.gd`) | ver `fuentes-u6.md` |

## 11. Estimaciones (no son mediciones)

| Estimación | Valor | Por qué |
|---|---|---|
| Forma de VB(t) en cualquier par herramienta-material | la curva de Equeter (2020) escalada con τ = t/T | una sola curva medida publicada en abierto |
| Acumulación del desgaste con vc variable | D = Σ Δt/T(vc) | hipótesis lineal habitual; sin medida |
| Kver frente a VB | 1 + VB hasta 0,2 mm; 1,2 + 0,5·(VB − 0,2) hasta 0,8 mm | el TZ da Kver y VBzul por separado |
| Ff y Fp frente a VB | 1 + 0,691·VB y 1 + 0,166·VB | un solo ensayo (AISI 1045, f = 0,4) |
| Ra frente a VB en otros casos | × (1 + 0,98·VB) | un solo ensayo (f = 0,4, rε = 0,8) |
| Diagrama de rotura en otro acero u otra vc | el del C45 a 200 m/min | el TZ solo da ese |
| Umbral del filo recrecido | el mínimo del intervalo de vc de la herramienta | sin umbral publicado general; coincide con Ahmed (2017) en el 304 |
| Energía de los discos de metal duro y CBN | la del grano de la pieza (Awan) | sin medida con esos discos |
| Holgura del surco del disco de metal duro | +0,4 mm | como los aglomerados |
| Embotamiento del disco de metal duro | resistencia 0,8 | se vende para plásticos y no férricos |
| Relación G del disco de metal duro | 20 | grano soldado que no mengua; sin medida |
| Temperatura máxima del grano de metal duro | 1.000 °C | la del metal duro de `tool_materials.gd` |

## 12. Peticiones al coordinador

1. **CONTRATOS.md:** documentar `kerf_band_mm`, `specific_energy_band_j_mm3` y el aviso `disco_fijo` en la salida de
   `cut_panel`; `sparks.class` = familia de `sparks.gd`; y, en «Modelo de corte inyectado», `cutting_model_worn` /
   `model_callable_worn` para el desgaste.
2. **docs/TALLER.md y ROADMAP.md (Radial):** marcar como hechos la fuente única de las chispas, los discos de metal
   duro y de CBN y la verificación de Awan 2021 (con la conclusión del apartado 2.2: banda, no sustitución); el ancho
   de corte del disco de láminas queda cerrado como «no aplica» (apartado 2.3). En «Lo que no predice», el desgaste de
   la herramienta y la forma de la viruta pasan a tener modelo con límites (apartados 3.4 y 4.3).
3. **`panels.gd`** (sin dueño en esta oleada): `SPARK_CLASSES` ya no lo usa el modelo; conviene quitarlo o dejar
   solo su referencia a `sparks.gd`, y actualizar `fuentes-u6.md` (apartado «Chispas»).
4. **Unidad 1d:** integrar el desgaste en el torno (apartado 8.1) y la forma de la viruta; decidir el código de aviso
   de fin de vida (propuesta `TOOL_WORN`).
5. **Unidad 1e:** el apartado 8.2 y los casos `corte.*` del JSON para sus tests.
6. **`WorkshopState.RADIAL_DISCS`** y `radial3d/looks.gd`: añadir `metal_duro` y `cbn_1mm` si se quieren en la
   interfaz (apartado 8.3).
7. **Rendimiento:** revisar los `static var` mutables de `lathe_mesh.gd` y `machine_sound.gd` (cachés sin `Mutex`).
