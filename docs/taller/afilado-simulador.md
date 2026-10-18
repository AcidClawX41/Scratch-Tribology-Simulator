# Simulador de afilado · máquinas, física del amolado y temperatura del filo

Especificación física del simulador de afilado de cuchillos, brocas y fresas del **Taller industrial** (V2 en Godot,
fase 2, oleada 1). Es el contrato que tienen que cumplir la oleada 2 (`core/taller/sharpening_sim.gd` y su interfaz)
y la oleada 3 (escena 3D y sonido).

Lo que pidió Eric: un simulador educativo que empiece con máquinas de consumo (Einhell, VEVOR, afiladoras baratas de
brocas y fresas) y se base en físicas reales, para que la gente aprenda a usarlas:

- con el ángulo correcto;
- a las rpm correctas;
- con el abrasivo que conviene a cada material;
- sin pasarse de temperatura;

y así conseguir el mejor resultado posible.

> **Valores orientativos.** Es un simulador educativo: enseña tendencias y órdenes de magnitud con datos publicados
> y dice cuánto se puede equivocar. No sustituye al manual de la máquina.
>
> **Nunca se supera la velocidad máxima marcada en una muela o un disco.** El simulador avisa (`exceso_velocidad`) y
> ningún consejo de este documento lo propone.

## 1. Archivos

| Archivo (`godot/`) | Qué hace |
|---|---|
| `core/taller/sharpening_machines.gd` | Catálogo de 11 máquinas reales: muelas, giro, potencia, disposición para la vista 3D, para qué sirve cada una. `view()` da el diccionario de la escena 3D |
| `core/taller/grinding.gd` | Física del amolado a mano, en funciones puras: velocidad, fuerzas, potencia, motor, reparto del calor, energía específica, metal arrancado, chispas, sonido, errores de afilado de brocas y fresas |
| `core/taller/edge_thermal.gd` | Temperatura transitoria del filo (aleta 1D de sección variable), enfriamiento, revenido acumulado, color y pérdida de dureza. Una instancia por sección de la hoja |
| `core/taller/sharpening_heat.gd` | Añadidos compatibles: curvas de revenido por acero, revenido acumulado (`accumulate_temper`), dureza tras el revenido (`curve_hardness`, `temper_loss`, `loss_ranges`). No cambia ningún resultado anterior |
| `tests/taller/test_sharpening_machines.gd`, `test_grinding.gd`, `test_edge_thermal.gd` | 11 + 18 + 21 tests |
| `tests/fixtures/spec/afilado.json` + `tests/taller/spec_afilado.gd` | 65 casos de referencia y su ejecutor |

`sharpening.gd` (ángulos, granos, `recommend_sharpening`) no se ha tocado: el simulador lo reutiliza.

## 2. Máquinas

### 2.1 Tabla

Calidad de cada dato: **P** = `primary` (manual o ficha del fabricante), **S** = `secondary` (distribuidor, anuncio
o buscador), **E** = `estimate`. La velocidad periférica es v = π·D·n/60 000; «decl.» es la que declara el fabricante.

| Máquina (`id`) | Tipo · red | Motor | Giro en vacío | Muelas de serie (Ø × ancho × agujero, grano, abrasivo) | v (m/s) | Máx. marcada | Calidad |
|---|---|---|---|---|---|---|---|
| Einhell TC-BG 150 (`einhell_tc_bg_150`) | banco · 230 V 50 Hz | inducción, S1 110 W / S2 30 min 150 W | 2980 | 150 × 16 × 32, K36 y K60, corindón | 23,4 (decl.) | 4456 rpm = 35,0 m/s | P; abrasivo E |
| Einhell TC-WD 200/150 (`einhell_tc_wd_200_150`) | combinada · 50 Hz | inducción, S1 170 W / S2 250 W | 2980 (seca) / 134 (húmeda) | seca 150 × 20 × 32 K36; húmeda 200 × 40 × 20 K200 | 23,4 / 1,4 (decl.) | seca 4456 rpm | P; abrasivos E (sin dato) |
| Einhell TC-WG 200 (`einhell_tc_wg_200`) | lenta en agua · 50 Hz | 125 W | 110 | 200 × 40 × 32 K220, corindón noble; cuero 180 × 30 | 1,15 / 1,04 (decl.) | — | P |
| VEVOR MD150G-450 (`vevor_md150g_450`) | banco · 120 V 60 Hz (EE. UU.) | inducción, 450 W | 3450 | 150 × 16 × 12,7, 36 y 60, corindón marrón | 27,1 | muelas ANSI B7.1 de más de 3450 rpm | P |
| VEVOR MD150-4 (`vevor_md150_4`) | banco lenta · 120 V 60 Hz | inducción, 250 W | 1750 | 150 × ? × 12,7, 36 y 60, corindón marrón | 13,7 | — | P; ancho sin dato |
| VEVOR SCM8082 (`vevor_scm8082`) | lenta en agua · 110 V 60 Hz | S2 30 min 150 W | 155 | 200 × 40 × 12, grano 220; cuero 200 × 30 × 12,5 | 1,62 | — | P; abrasivo E (sin dato) |
| Einhell TE-AG 125 CE (`einhell_te_ag_125_ce`) | amoladora · 50 Hz | universal con electrónica constante, 1100 W | 3000–12 000 en 6 posiciones | disco de láminas 125 P60 o de desbaste 125 × 7,2 (accesorios) | 19,6–78,5 | discos ≥ 12 000 rpm y 80 m/s (12 200 marcadas) | P |
| Einhell TC-AG 125/850 (`einhell_tc_ag_125_850`) | amoladora · 50 Hz | universal, 850 W | 12 000 fijas | disco de láminas 125 P60 (accesorio) | 78,5 | 12 200 rpm | P |
| MRCM MR-13A (`mrcm_mr_13a`) | afiladora de brocas · 220 V | universal, 120 W | 4400 (VEVOR dice 4500) | CBN (HSS) o SDC (metal duro) 78 × 10 × 12,7, grano 230 | 18,0 | — | P; muelas S |
| MRCM MR-X3 (`mrcm_mr_x3`) | afiladora de fresas · 220 V | universal, 160 W | 4400 | SDC de serie, CBN opcional, 78 × 10 × 12,7, grano 230 | 18,0 | — | P; muelas S; «0–5°» E |
| Tormek T-8 (`tormek_t8`) | lenta en agua, referencia · 230 V | inducción, 200 W | 90–100 | SG-250 250 × 50, óxido de aluminio (220–≈1000); cuero LA-220 220 × 31 | 1,31 / 1,15 | — | P |

Otros datos del catálogo, cada uno con su fuente:
- distancia máxima del apoyo (Einhell: 2 mm; VEVOR: 1/8″ = 3,2 mm);
- ruido (Einhell: LpA y LwA);
- masa y accesorios;
- para las afiladoras MRCM, el ángulo de punta (95–135°) y el intervalo de diámetros (3–13 y 4–14 mm).

### 2.2 Qué se ha comprobado y qué no

- **Einhell:** los cuatro manuales originales (datos técnicos, fig. 1 y modo de empleo) y las fichas de las muelas de
  recambio (4456 min⁻¹ = 35,0 m/s en 150 mm).
  - Einhell no dice de qué abrasivo son la TC-BG 150 ni la muela seca de la TC-WD: se toma corindón, con
    `abrasive_quality: "estimate"`.
  - «K» es la *Körnung* (grano) de Einhell. K36, K60 y K220 coinciden con grados FEPA F. K200 no existe en FEPA F:
    su `grit_system` se deja vacío.
- **VEVOR:** solo se han podido comprobar las versiones de EE. UU. (120 V, 60 Hz): el manual de la MD150G-450 y las
  fichas de la MD150-4 y la SCM8082.
  - No se inventa el giro a 50 Hz. Una esmeriladora de 2 polos a 50 Hz iría a ≈2900–2980 rpm, como las de Einhell.
  - No se ha encontrado en la tienda de VEVOR ninguna afiladora en húmedo de 10″. Se usan la SCM8082 (8″, EE. UU.)
    y, para Europa, la Einhell TC-WG 200.
- **Afiladoras MRCM:** la ficha del fabricante da 4400 rpm para la MR-13A y VEVOR la vende con 4500.
  - `rpm_no_load` lleva 4400 con el intervalo 4400–4500.
  - Las muelas de recambio (Ø78 × 10 × 12,7, grano 230, CBN o SDC) salen de anuncios de distribuidores: `secondary`.
  - El «ángulo de 0–5°» de la MR-X3 lo interpretamos como la inclinación del filo frontal (*dish*): `estimate`.
- **Tormek T-8:** ficha del fabricante, coherente con `sharpening.gd` (lo comprueba un test).
- **Amoladoras:** se venden sin disco. El disco de láminas y el de desbaste son los de PFERD de `abrasives.gd`
  (12 200 rpm en 125 mm, 80 m/s).

### 2.3 Disposición de las muelas y vista 3D

Cada muela lleva:
- `position`: `"izquierda"`, `"derecha"`, `"piedra"`, `"cuero"` o `"disco"`, los valores de la vista 3D de
  CONTRATOS.md;
- `mounted`: `false` en los recambios, que se montan en lugar de la muela de serie (SDC y CBN de las MRCM; disco de
  desbaste de la TE-AG).

Cada máquina lleva además:
- `layout { source, quality }`: de dónde sale esa disposición;
- `water_trough`: la muela gira en agua;
- `quench_pot`: baño para enfriar la pieza.

De dónde sale la disposición:
- TC-BG 150: fig. 1 del manual, gruesa a la izquierda y fina a la derecha (P).
- TC-WD: fig. 1, húmeda con su depósito a la izquierda y seca a la derecha (P).
- VEVOR: el manual no lo dice; la gruesa a la izquierda es una convención de dibujo (E).

`Machines.view(id, muela, diámetro)` devuelve el diccionario de `set_machine(view)`:
- `kind`: `banco`, `humeda_lenta`, `amoladora`, `afilabrocas` o `afilafresas`; la combinada se dibuja como de banco
  con una `piedra`;
- `rpm` y `wet`: los de la muela en uso;
- `wheels [{ position, d_mm, width_mm, abrasive_id, grit, … }]`.

Además trae el `rpm` de cada muela, porque la combinada tiene dos giros. `width_mm` es `null` cuando el fabricante no
lo da (MD150-4 y discos de láminas): la escena dibuja el suyo.

## 3. Modelos y ecuaciones

### 3.1 Cadena de un paso de afilado

```
máquina + muela + giro ──► v = π·D·n/60 000 (con el giro que deja el motor bajo carga)
fuerza de la mano Fn ────► Ft = μ·Fn ──► P = Ft·v ──► par Ft·D/2 frente al del motor: gira, se frena o se cala
                                          │
                                          ├─► calor en la herramienta ε·P ──► q = ε·P/A (W/m²) ──► edge_thermal
                                          └─► metal arrancado Q = P/u (mm³/s) ──► retroceso del bisel, chispas
```

`grind(p)` hace un paso completo. Es una función pura: sin estado ni variables estáticas, se puede llamar desde
cualquier hilo.

### 3.2 Velocidad periférica

- **Fórmula:** v = π·D·n/60 000 (m/s, con D en mm y n en rpm), la misma de `sharpening.gd`.
- **Muela gastada:** `diameter_mm` la hace más pequeña con el mismo giro, así que va más lenta.
  - Por debajo del diámetro mínimo del fabricante, aviso `muela_gastada`.
  - Una muela mayor que la de serie no se monta: aviso `diametro`.
- **Giro regulable:** solo la TE-AG. `rpm` se lleva a la posición más cercana de su rueda.
  - En las demás, un giro distinto del de serie da el aviso `giro_fijo`.

### 3.3 Contacto del bisel

- **Cara del bisel:**
  - con un bisel simétrico de β por lado, w = (t/2)/sen β (t: espesor donde acaba el bisel);
  - con caras de ángulos a y b, w = t/(tan a + tan b)/cos a.
- **Área de contacto:** A = w × largo del filo apoyado. En una muela de banco, el largo es el ancho de la muela.
- **Vaciado cóncavo:** la periferia deja una flecha r − √(r² − (w/2)²). Con una muela de 150 mm y un cuchillo de
  0,6 mm a 17,5° son 1,7 µm.

### 3.4 Fuerzas y potencia

- **Relación de fuerzas de amolado:** μ = Ft/Fn = 0,25–0,40 en la mayoría de aceros; se toma 0,325 [BIRO]. Es la de
  `sharpening.gd` (`NOMINAL_OPERATION`).
- **Potencia:** P = Ft·v, con banda P_min–P_max por μ en sus extremos.
- **Fuerza de la mano:** no hay medida publicada de la fuerza al afilar a mano. `HAND_FORCE` da una escala con
  nombre, toda `estimate`: 5 N «muy ligera», 10 N «ligera», 20 N «moderada», 40 N «fuerte» (0,5–4 kgf).

### 3.5 Motor

Solo se publica la potencia de entrada. El modelo (`MOTORS`, todo `estimate`) compara el par que pide la muela,
Ft·D/2, con el nominal, η·P_entrada/ω_nominal.

| Motor | η | Caída del giro a par nominal | Par máximo / nominal | Máquinas |
|---|---|---|---|---|
| `induccion` | 0,5 | 5 % | 2,0 | esmeriladoras, lentas en agua (con reductora) |
| `universal` | 0,55 | 30 % | 2,5 | TC-AG, MRCM |
| `universal_constante` | 0,55 | 0 hasta el nominal; luego como universal | 1,6 | TE-AG 125 CE («rendimiento constante también con carga») |

Por encima del par máximo, la muela se cala: rpm = 0, P = 0 y aviso `se_cala`, con el consejo del manual de Einhell
(«retira la pieza, espera a que recupere el giro y apoya con menos fuerza»). Por encima del nominal, aviso
`se_frena`.

**Comprobación de coherencia (test).** El giro en vacío de las de banco queda justo por debajo del de sincronismo
120·f/p:
- 2980 frente a 3000 rpm (2 polos a 50 Hz);
- 3450 frente a 3600 rpm (2 polos a 60 Hz);
- 1750 frente a 1800 rpm (4 polos a 60 Hz).

Deslizamientos del 0,7 al 4,2 %.

Con 10 N, la TC-BG 150 (110 W en S1) ya va casi a plena carga (2836 rpm); con 20 N se frena y con 40 N se cala. Las
lentas con reductora no se paran ni con 100 N.

### 3.6 Reparto del calor

Parte de la potencia de amolado que entra en la herramienta (ε):

| Abrasivo | ε central | Intervalo | Fuente |
|---|---|---|---|
| Corindón (Al₂O₃) y muelas sin grano declarado | 0,725 | 0,60–0,85 | [MALKIN]: 60–85 % con muelas convencionales |
| CBN | 0,20 | 0,15–0,50 | [MALKIN]: ≈20 %; [ROWE]: hasta 0,5 (cota alta) |
| Diamante (solo metal duro) | 0,20 | 0,15–0,50 | como el CBN: `estimate` |

- **En húmedo**, ×0,42 (`WET_FACTOR` de `sharpening_heat.gd`, `estimate`) mientras la cara del contacto no pase de
  ≈130 °C.
  - Por encima, el agua hierve en película y deja de enfriar: el reparto vuelve al de seco y sale el aviso
    `agua_hierve`.
  - La temperatura de la cara la da `edge_thermal.gd` (`contact_surface_c()`).
- **Flujo de calor:** q = ε·P/A (W/m²), con banda q_min–q_max (μ y ε en sus extremos). La banda va de ×0,64 a ×1,44
  del valor central.

### 3.7 Energía específica y metal arrancado

- **Metal arrancado:** Q = P/u (mm³/s) [ROWE].
- **Energía específica u:**
  - 25 J/mm³ típicos;
  - en acero de 60–62 HRC con muela A46 a 30 m/s, de ≈90 J/mm³ con el menor espesor de viruta a ≈62 con el mayor
    (efecto tamaño);
  - hasta 200 J/mm³ con grano fino en materiales difíciles.
- **Al afilar a mano** el espesor de viruta es aún menor. Se toman estos valores (`estimate`):
  - acero templado (≥ 50 HRC): 90 J/mm³, intervalo 62–200;
  - acero blando (cuchillas de cortacésped): 40 J/mm³, intervalo 25–90.
- **Retroceso de la cara del bisel:** Q/A (µm/s, `bevel_recession_um_s`). En la TC-BG 150 con 10 N son 0,80 mm³/s en
  16 mm²: 50 µm/s.

### 3.8 Temperatura del filo (`edge_thermal.gd`)

**Por qué este modelo.** El modelo de `sharpening_heat.gd` es el de Malkin y Guo para un cuerpo grueso: sólido
semiinfinito con una fuente que se mueve. Un filo no cumple esa hipótesis: el calor no tiene dónde ir y se concentra
en la cuña.

En estado estacionario, una cuña perfecta calentada por una cara sube ΔT = q·L/(2k·sen β): el gradiente es constante
hasta el vértice. Las escalas de tiempo deciden el modelo:
- el calor cruza el espesor del bisel en t²/α: de 1 ms junto al vértice a ≈40 ms en el hombro de un cuchillo de
  0,6 mm;
- a lo largo del bisel tarda w²/α ≈ 0,1–0,3 s, lo mismo que una pasada.

Por eso basta una **aleta 1D de sección variable**: en cada distancia x al vértice, una sola temperatura (la media en
el espesor).

Un modelo 2D o 3D por elementos finitos sería más preciso cerca del vértice, pero no cabe en tiempo real en GDScript.
La aleta conserva lo esencial: la concentración del calor en la cuña, el enfriamiento por las caras y la conducción
hacia el lomo.

**Ecuación.**

    ρ·c·A(x)·∂T/∂t = ∂/∂x(k·A(x)·∂T/∂x) + q·P_q(x) − h·P_h(x)·(T − T∞)

- A es el área de la sección (en un cuchillo, el espesor por metro de filo);
- P_q es el borde calentado, la cara del bisel que toca la muela;
- P_h son las dos caras que se enfrían.

**Perfiles** (todas las medidas en mm, µm y grados):
- `knife_profile()` y `edge_profile()`: cuña de dos caras (o de una, `side_b_deg: 0`) con vértice de 1 µm por
  defecto, cuerpo hasta el lomo y malla geométrica. El vértice no es una arista: [VERHOEVEN] midió anchos de filo de
  0,3–4 µm.
- `drill_profile()`: cono de la punta de una broca.
  - La sección llena es el 55 % del círculo (quitadas las ranuras), el alma el 15 % del diámetro y la parte que toca
    la muela 1/4 de la vuelta. Las tres son estimaciones.
  - El radio hace de espesor: en una broca gruesa el modelo es solo una tendencia (ver §5).
- `bar_profile()`: barra de espesor constante, para validar.

**Discretización.**
- Volúmenes finitos en una malla geométrica:
  - 32 celdas en el bisel y 16 en el cuerpo;
  - la primera, de 5 µm, en el vértice.
- Conductancias exactas para un espesor lineal por tramos, ∫dx/(k·A).
- Euler implícito: un sistema tridiagonal por paso, resuelto con el algoritmo de Thomas.
  - Es incondicionalmente estable y L-estable: no oscila con los pulsos de calor. Crank–Nicolson oscila en las
    celdas de micras del vértice.
  - El paso lo fija la precisión (2–5 ms), no la celda más pequeña. Un esquema explícito pediría pasos de ≈10⁻⁷ s.
- **Balance de energía:** con la misma ponderación que el esquema, cuadra al error de redondeo.

**Enfriamiento** (`COOLING`, h en W/(m²·K), todo `estimate` dentro de los intervalos de los libros):

| Medio | h | Fuente |
|---|---|---|
| `aire` | 15 (2–25) | [INCROPERA], tabla 1.1: convección natural en gases |
| `pelicula_agua` (muela húmeda, goteo) | 500 frío; 10 000 en ebullición nucleada entre 100 y 130 °C; por encima, seco: como el aire | [INCROPERA] (líquidos 50–1000; ebullición 2500–100 000); [MALKIN] (130 °C) |
| `inmersion` (meter la hoja en agua) | 500; 10 000 hasta 130 °C; interpolación logarítmica hasta 250 a 300 °C (película de vapor) | [INCROPERA], [NUCLEAR-POWER], [CUKROV]: h ≈ 200–300 en la etapa de película del temple en agua |

`step()` acepta también un medio a medida `{ h }`.

**Cara calentada.** La cara que toca la muela está más caliente que la media de la sección: q·t/(3k), en una placa
calentada por una cara con perfil parabólico. En el hombro de un cuchillo de 0,6 mm con 3,3 MW/m² son ≈22 K; junto
al vértice, nada.

Ese exceso se suma al pico de la cara para el color (`surface_peaks()`) y para decidir si el agua hierve
(`contact_surface_c()`).

**Secciones de la hoja e hilos.** Cada instancia de `EdgeThermal` es una sección de la hoja, con su propio estado (un
`RefCounted`, sin variables estáticas).
- Se desprecia la conducción a lo largo del filo, así que las secciones son independientes.
- Se pueden avanzar en paralelo y combinar en orden fijo con `combine()`: el resultado es idéntico, al bit, con uno
  o con N hilos (lo comprueba un test con `WorkerThreadPool`).
- `sweep_coverage()` da la parte de cada paso en que una sección está bajo la muela cuando la hoja se barre.

### 3.9 Revenido y dureza

- **Parámetro de Hollomon–Jaffe** [HJ]: P = T·(C + log10 t), con T en K y t en horas.
  - C = 15, salvo el 1095: su curva maestra es la del acero W de 0,89 % C, con c = 12,2 y t en segundos, que con t
    en horas es C = 15,756 [THOMAS].
  - Cada celda empieza con el P de su revenido de fábrica (`STEELS.temper`).
- **Revenido acumulado:** regla del tiempo equivalente, exacta por tramos isotermos (`accumulate_temper`).
  - Lo ya revenido se pasa a su tiempo equivalente a la temperatura actual, t_eq = 10^(P/T − C), y se le suma dt.
  - P nunca baja.
  - Si dt no llega a 10⁻⁷ de t_eq, no cambia nada y no se calcula (así las celdas frías no cuestan).
- **Curvas de revenido** (HRC frente a temperatura en un tiempo dado, o frente a P), leídas de las figuras de cada
  ficha (±0,5 HRC, ±5 °C):

| Acero | Curva | Calidad |
|---|---|---|
| X50CrMoV15 (1.4116) | SIJ SINOXX 4116, revenido de 1 h, línea media de la banda [SIJ] | P |
| 14C28N | Alleima, 30 min [ALLEIMA] | P |
| VG-10 | la forma de la del 14C28N: Takefu no publica la curva [TAKEFU] | E |
| M2 | Böhler S600, 3 × 2 h, temple a 1180 °C, 400–625 °C [BOHLER] | P |
| 1095 | curva maestra de Hollomon y Jaffe del acero W, dibujada por [THOMAS]; coincide con [NJSB] dentro de 1,5 HRC | S |

- **Pérdida de dureza:** `temper_loss(acero, P)` compara con el P del revenido de fábrica.
  - La pérdida nunca es negativa: el endurecimiento secundario del M2 no «mejora» un filo recalentado.
  - `beyond` dice que P está más allá del final de la curva y que la pérdida es un mínimo.
- **Resultados de la hoja:**
  - `t_over_temper_s`: cuándo el vértice pasa el revenido (su P supera en un 1 % el de fábrica);
  - `t_loss_1hrc_s`: cuándo pierde 1 HRC;
  - `softened_width_mm`: hasta dónde pierde ≥ 1 HRC;
  - `burned`: si llega a 723 °C, el eutectoide, donde empieza la austenización.

### 3.10 Color de revenido

- **Tablas de `panels.gd`:**
  - acero al carbono de 216 a 316 °C (Engineering ToolBox), para el 1095 y, por aproximación, el M2;
  - inox en aire de 290 a 600 °C (BSSA), para los martensíticos (X50CrMoV15, 14C28N, VG-10). Está medida en
    1.4301: `estimate` para ellos.
- **Qué temperatura se usa:** el pico de la cara calentada (`tint()`, `surface_peaks()`, `tint_width_mm`).
- **El color depende también del tiempo** [NATURE1922]: a 275 °C durante 30 min sale el azul que a 300 °C sale al
  momento. Con exposiciones de décimas de segundo, el color real aparece a algo más de temperatura de la que dice la
  tabla. Por eso **el color es una pista, no la medida**: el acero puede perder dureza antes de tomar color. Es lo que
  enseña [KSN].

### 3.11 Brocas

- **Labios desiguales:**
  - con una diferencia de altura de los labios Δh (en el eje) y semiángulo de punta p, la punta se descentra
    e = Δh·tan p/2 = ΔL·sen p/2;
  - si la broca gira sobre su punta, el agujero sale D + 2e. Es una cota geométrica: la guía de las faldillas y la
    rigidez la reducen [TC9524-4];
  - en una broca de 10 mm a 118° con 0,1 mm de diferencia, el agujero sale 0,17 mm mayor.
- **Tolerancia comercial de Δh** [US4031672]:
  - 0,076 mm hasta 1/4″;
  - 0,10 mm de 1/4″ a 1/2″;
  - `null` por encima (sin dato).
- **Incidencia efectiva:** el labio avanza por una hélice de ángulo atan(f/(2π·r)), que crece hacia el centro. La
  incidencia afilada tiene que ser mayor en cada punto [US4561813].
  - `drill_check` la calcula en la periferia y a 0,1·D del eje.
  - Si junto al centro es ≤ 0, avisa `poca_incidencia` aunque la afilada parezca buena. Ejemplo: 8° con 0,3 mm/v en
    una broca de 3 mm.
- **Arista transversal** [MAZOFF]: 110° ≈ 5° de incidencia, 120° ≈ 8° y 130° ≈ 11°. Sirve para comprobar la
  incidencia mirando la punta (`chisel_angle_deg` y su inversa).
- **Cuña del labio:** 90° − incidencia − desprendimiento, con 30° de desprendimiento en la periferia. Más incidencia,
  cuña más débil.
- **Revisión** (`drill_check`), contra `sharpening.gd` (`drill_angles`) y TC 9-524:
  - `punta_plana` o `punta_aguda` a más de 5° de lo recomendado;
  - `poca_incidencia` por debajo de 7° o con incidencia efectiva ≤ 0 junto al centro;
  - `mucha_incidencia` por encima de 15°;
  - `incidencia_fuera` fuera de 8–12°;
  - `labios_desiguales` por encima de la tolerancia;
  - `bien` si no hay nada.
- **Calentamiento de brocas pequeñas.** La punta es un cono y su sección crece con r²: una broca de 3 mm se quema en
  la esmeriladora en menos de un segundo con 5 N, mientras que una de 10 mm se queda en ≈130 °C (casos de
  referencia).
- **HSS M2 frente a acero al carbono:**
  - el M2 conduce peor (k = 21,8 frente a 49 W/(m·K)) y se calienta más: una broca de 8 mm, 2 s con 10 N, llega a
    441 °C frente a 282 °C;
  - pero el M2 viene revenido a 550–570 °C y no pierde dureza, mientras que el 1095 (revenido a 204 °C) ya está donde
    empieza a ablandarse.

### 3.12 Fresas

- **Revisión** (`mill_check`), contra `sharpening.gd` (`mill_angles`):
  - incidencia primaria de 5–9° y secundaria de 14–17° [NACHI-EM];
  - `poca_incidencia` más de 1° por debajo del mínimo;
  - `mucha_incidencia` más de 2° por encima del máximo;
  - `secundaria` si la secundaria no es mayor que la primaria (el talón roza).
- **Desplazamiento del dedo de apoyo** en una afiladora universal: 0,0088 × ángulo × D [TC9524-5]. D es el diámetro
  de la fresa con muela de copa y el de la muela con muela recta. Ejemplo: 0,264″ para 5° y 6″.
- **Afiladora de fresas MR-X3:** SDC (diamante) para metal duro y CBN para HSS. `abrasive_suits` y `grind()` avisan
  si se usa diamante con acero (`diamante_acero`) o CBN con metal duro (`abrasivo_metal_duro`).

### 3.13 Chispas y sonido

- **Chispas** (`spark_input`): entrada de `sparks.gd`.
  - Ritmo: el metal arrancado por la escala de chispas de la radial (100 por mm³ con un chorro de tamaño 1,
    `radial.gd`, estimación) por el tamaño del chorro del acero en el ensayo de chispas.
  - Sin chispas en húmedo ni por debajo de 5 m/s (`SPARK_MIN_MS`, estimación). El ensayo de chispas pide ≥ 25 m/s.
- **Sonido** (`sound_input`): entrada de `machine_sound.gd`.
  - La esmeriladora y las afiladoras suenan como `sharpener`; la amoladora, como `grinder` con su disco.
  - `rpm` es el giro sin carga: la caída la aplica `machine_sound.gd` con `pc_kw/pmax_kw` y `speed_droop`, que son
    los de este modelo de motor. El giro que suena es el que da `grind()` (lo comprueba un test).
  - En las lentas con reductora es el giro de la muela: el del motor no se publica.

## 4. Validación

### 4.1 Soluciones exactas (`test_edge_thermal.gd`)

| Prueba | Solución exacta | Error del modelo |
|---|---|---|
| Barra calentada por el extremo, caras sin pérdidas, 0,5 s (q = 1 MW/m²) | sólido semiinfinito: 2q·√(αt/π)/k = 77,40 K [CARSLAW] | 0,005 % (test: < 0,05 %) |
| La misma con aire en las caras | — | 0,14 % por debajo: lo que se lleva el aire (test: 0–0,5 %) |
| Cuña de 17,5° con 1 µm de vértice, calentada por una cara, hombro a temperatura fija, estacionaria | q/(k·cos β)·[(L − x)/b − (a/b²)·ln((a + bL)/(a + bx))] | 0,022 % con 40 celdas (−0,12 % con 20, +0,05 % con 80; test: < 0,05 %) |
| Vértice de 1 µm frente a la cuña perfecta, q·L/(2k·sen β) | — | 1,2 % por debajo (el término logarítmico) |
| Aleta de 0,5 mm con h = 200 W/(m²·K), base fija, punta adiabática | cosh(m·x)/cosh(m·L) | 0,001 % (test: < 0,05 %) |
| Placa a 300 °C enfriándose en aire | exponencial con τ = ρc·t/(2h) | igual a la solución discreta de Euler implícito (10⁻⁹); 0,0013 % del salto con dt = 10 ms; el error baja con dt |

### 4.2 Conservación, convergencia, determinismo

- **Energía:** lo que entra es igual a lo almacenado más lo perdido por las caras y por el extremo, con error
  relativo < 10⁻⁹ en los tres medios (medido: ≈10⁻¹⁵).
- **Paso de tiempo:** cuchillo quieto 3 s en la TC-BG 150 con 10 N.
  - Con dt de 0,5, 2 y 5 ms, el pico es 1030,8, 1030,7 y 1030,6 °C (±0,02 %).
  - `t_over_temper_s` es 0,169, 0,168 y 0,170 s.
- **Malla:** la malla por defecto queda a 0,35 % de una cuatro veces más fina (1030,7 frente a 1027,2 °C). La gruesa
  (16 + 8 celdas) se va al +1,9 %.
- **Determinismo:** las mismas entradas dan las mismas temperaturas y el mismo revenido, al bit.
- **Paralelismo:** 8 secciones avanzadas con `WorkerThreadPool` dan lo mismo que en serie, al bit, y `combine()`
  también.

### 4.3 Rendimiento

Medido sin ventana, en la nube, con 4 núcleos compartidos con otros procesos.

- **Una sección (48 celdas):** 37 µs por paso en frío y 57–71 µs mientras se calienta (entonces se calcula el
  revenido).
- **Hoja de 8 secciones:** 315–382 µs por paso en serie. Un segundo de proceso con dt = 5 ms cuesta 63–76 ms.
- **Fotograma de 4 subpasos de 5 ms con `WorkerThreadPool.add_group_task(f, n, -1, true)`**, una tarea por sección y
  fotograma:

| Secciones | En serie | En paralelo | Aceleración |
|---|---|---|---|
| 8 | 1,3 ms | 0,50 ms | ×2,6 |
| 16 | 3,0 ms | 0,93 ms | ×3,3 |
| 32 | 6,1 ms | 1,76 ms | ×3,5 |

  Los resultados son iguales al bit.
  - Esas cifras son con la máquina libre (carga media 0,5). Con los núcleos ocupados por otros procesos (carga 4,8)
    la aceleración baja a ×1,5 (8 secciones), ×1,8 (16) y ×2,5 (32).
- **Prioridad baja (la de por defecto):** no acelera (×0,7–0,9), porque solo usa una parte de los hilos
  (`threading/worker_pool/low_priority_thread_ratio`). En el Ryzen 9 7900 de Eric (12 núcleos) se espera más
  aceleración con 16–32 secciones.
- **Otras llamadas:**
  - `grind()`: ≈51 µs por llamada;
  - `view()`: ≈16 µs;
  - `summary()`: 35–50 µs por sección. Los cortes de pérdida de dureza (`Heat.loss_ranges`) se calculan al crear la
    sección; antes, con el filo revenido, eran 550 µs.

### 4.4 Casos de referencia (`tests/fixtures/spec/afilado.json`)

**Formato.** 65 casos:

    { id, kind, input, expect: { campo: { value, tol } | { min } | { max } | { min, max } }, source }

- `tol` es absoluta, en las unidades del campo; `min` y `max` son inclusivos.
- Los campos con punto van dentro de diccionarios (`hardness.loss_hrc`).
- `aviso_<código>` es true si la salida trae ese aviso.
- `band` (informativo, no se comprueba) es el intervalo con μ y ε en sus extremos.
- Los ejecuta `tests/taller/spec_afilado.gd` y los comprueba `test_edge_thermal.gd`.

**Tipos (`kind`):**
- `velocidad`, `amolado`;
- `termico`: integra con `dt_s` ≤ 5 ms y pulsos `{ on_s, off_s, count }`. El calor de cada paso sale de `grind()`
  con la temperatura de la cara del paso anterior;
- `broca_labios`, `broca_incidencia`, `broca_revision`;
- `fresa_desplazamiento`;
- `revenido`, `color`.

**Grupos:**
- **Velocidades (17):** todas las muelas del catálogo, con la declarada y la máxima marcada.
- **Motor y amolado (15):**
  - la TC-BG 150 con 5, 20 y 40 N (gira, se frena, se cala);
  - la Tormek con 100 N (no se para);
  - la potencia con 10 N: 72,4 W, 3,28 MW/m², 0,80 mm³/s;
  - repartos en húmedo, con agua hirviendo y con CBN;
  - diamante con acero (avisa) y con metal duro (no avisa); CBN con metal duro (avisa);
  - chispas en húmedo (ninguna) y en seco;
  - la TE-AG a 3100 rpm va a la posición de 3000.
- **Térmicos (18),** cuchillo de X50CrMoV15 de 17,5° por lado y 0,6 mm tras el bisel salvo que se diga otra cosa:

| Caso | Resultado | Lectura |
|---|---|---|
| TC-BG 150, quieto 3 s con 10 N | pasa el revenido a los 0,17 s, pierde 1 HRC a los 0,28 s y se quema | banda por μ y ε: 0,08–0,43 s |
| TC-BG 150, 1 s con 5 N | pico de 352 °C, pasa el revenido a los 0,68 s, pierde 0,7 HRC | aun con presión muy ligera |
| Tormek, TC-WG 200, SCM8082, TC-WD húmeda: 60 s con 10 N | 26–29 °C, 0 HRC | ni se entera |
| Tormek, 60 s con 40 N | 43 °C, 0 HRC | apretar no la calienta |
| TC-BG 150, 5 pasadas barriendo (0,16 s sí, 1,84 s no) | pico de 396 °C, pierde 1,1 HRC | lo normal de una esmeriladora seca |
| Lo mismo en M2 | pico de 478 °C, 0 HRC | el acero rápido aguanta |
| Lo mismo con agua entre pasadas | pico de 339 °C, pierde 0,45 HRC | baja lo acumulado, no el pico de la pasada [KSN] |
| VEVOR MD150-4 (1750 rpm), 5 pasadas | pico de 248 °C, ≈0 HRC | la mitad de calor |
| Amoladora a 12 000 rpm, 1 s | pasa el revenido antes de 0,05 s y se quema | nunca para un cuchillo |
| Amoladora a 3000 rpm, cuchilla de cortacésped (bisel de 30° de un lado, 3 mm) | pico de 111 °C | aguanta |
| Broca de M2 de 3 mm, esmeriladora, 1 s con 5 N | se quema | la broca pequeña, poco a poco |
| Broca de M2 de 10 mm, lo mismo | pico de 128 °C | |
| Broca de 8 mm, 2 s con 10 N: M2 / 1095 / MR-13A con CBN | 441 °C y 0 HRC / 282 °C y ≈0 HRC / 96 °C | el CBN mete el 20 % del calor |

- **Geometría (9):**
  - labios desiguales: 0,166 mm de más en 10 mm, dentro de la tolerancia; en 5 mm, fuera;
  - incidencia efectiva: 4,36° a 0,5 mm del eje con 8° y 0,2 mm/v;
  - arista de 120° y cuña de 52° con 8°;
  - revisiones de broca: bien, poca y mucha incidencia, labios;
  - desplazamiento de TC 9-524.
- **Revenido (3):**
  - X50CrMoV15, 1 h a 400 °C: −2,35 HRC;
  - M2, 2 h a 560 °C: 0;
  - 1095, 1 h a 300 °C: −5,5 HRC.
- **Color (3):**
  - X50CrMoV15 a 300 °C: «amarillo pálido»;
  - 1095 a 300 °C: «azul oscuro»;
  - 1095 a 230 °C: «paja».

La `tol` de los térmicos (±10 % en el pico, ±20 % en los tiempos) es de regresión, no la incertidumbre física (ver
§5).

### 4.5 Cada máquina con el mismo cuchillo

Condiciones: 10 N, cuchillo de X50CrMoV15 (17,5° por lado, 0,6 mm) apoyado 16 mm, 1 s quieto contra la muela en
uso. Es un caso de abuso para comparar máquinas; lo realista es barrer (casos de arriba).

| Máquina | v bajo carga (m/s) | rpm | P (W) [banda] | q (MW/m²) | Q (mm³/s) | En 1 s |
|---|---|---|---|---|---|---|
| TC-BG 150 | 22,3 | 2836 | 72 [56–89] | 3,3 | 0,80 | 668 °C; pasa el revenido a 0,17 s; −2,4 HRC |
| TC-WD, seca | 22,7 | 2894 | 74 | 3,4 | 0,82 | 681 °C; 0,16 s; −2,4 HRC |
| VEVOR MD150G-450 | 26,6 | 3386 | 86 | 3,9 | 0,96 | quemado; 0,12 s |
| VEVOR MD150-4 | 13,5 | 1720 | 44 | 2,0 | 0,49 | 413 °C; 0,48 s; −1,6 HRC |
| TE-AG 125 CE a 12 000 | 78,5 | 12 000 | 255 | 11,6 | 2,84 | quemado en centésimas |
| TC-AG 125/850 | 69,5 | 10 624 | 226 | 10,3 | 2,51 | quemado en centésimas |
| TC-WD, húmeda | 1,40 | 134 | 4,6 | 0,09 | 0,05 | 34 °C |
| TC-WG 200 | 1,15 | 110 | 3,7 | 0,07 | 0,04 | 31 °C |
| SCM8082 | 1,62 | 154 | 5,3 | 0,10 | 0,06 | 36 °C |
| Tormek T-8 | 1,31 | 100 | 4,2 | 0,08 | 0,05 | 33 °C |

Las lentas en agua arrancan 15–20 veces menos metal: son para afilar, no para reperfilar.

## 5. Incertidumbre y lo que no predice

**Incertidumbre.**
- **Calor:** el flujo de calor tiene una banda de ×0,64 a ×1,44 (μ de 0,25 a 0,40 y ε de 0,60 a 0,85). Como la
  subida de temperatura es casi proporcional a q, **las temperaturas del filo llevan ±40 %** y los tiempos hasta el
  revenido, más. Con CBN, ε va de 0,15 a 0,50.
- **Mano:** la fuerza de la mano es una escala con nombre, no una medida.
- **Estimaciones:** el modelo de motor, el factor del agua (0,42) y los h de enfriamiento son estimaciones dentro de
  intervalos publicados.
- **Tendencias fiables:**
  - lenta en agua ≪ banco lenta < banco < amoladora;
  - más fuerza o más rpm, más calor;
  - broca pequeña ≫ broca grande;
  - M2 aguanta y el inox de cocina no.

**Lo que no predice.**
- **Por encima de 723 °C** la cifra no vale: no hay cambio de fase, austenización, retemple ni capa blanca, fusión ni
  oxidación. La interfaz enseña «quemado» (`burned`), no el número.
- **El arranque de material en el modelo térmico:** el perfil no cambia mientras se amuela. El retroceso del bisel sí
  se calcula aparte (`bevel_recession_um_s`).
- **La conducción a lo largo del filo** entre secciones. Es conservador: una sección caliente no reparte calor con
  sus vecinas.
- **El enfriamiento bajo la muela:** la convección actúa en las dos caras también en la franja que toca la muela. El
  efecto es pequeño: en la Tormek, ≈6 % del calor que entra en esa franja.
- **El gradiente en el espesor de secciones gruesas:** en una broca gruesa o en el cuerpo de un hacha, la media de la
  sección subestima la cara calentada.
  - `validity.through_thickness_ms` lo dice: si es comparable a la duración del contacto, el resultado es una
    tendencia.
  - En una broca de 10 mm son segundos.
- **El color de revenido exacto:** depende del tiempo y de la atmósfera (ver §3.10).
- **La muela:** su embotamiento, su vidriado y su desgaste real, el reavivado, la rebaba y el vaciado real de la
  periferia más allá de la flecha geométrica.
- **La fisuración** por calor del metal duro, o de una broca muy caliente metida en agua. Se avisa en el texto (TC
  9-524, NPS), pero no se calcula.
- **Máquinas no comprobadas:** las versiones europeas (50 Hz) de las VEVOR y una VEVOR de 10″ en húmedo (no
  encontrada).

## 6. Consejos de uso, con fuentes

### Seguridad, en todas las máquinas

- **Muelas y discos:** solo los marcados para más giro del que da la máquina. La TE-AG pide discos de ≥ 12 000 rpm y
  80 m/s; VEVOR, muelas ANSI B7.1 de más de 3450 rpm [EIN-AG, VEV-450, NPS].
  - Nunca una muela mayor que la prevista [EIN-AG].
  - Una muela con grietas se cambia [VEV-450]. Una muela nueva, prueba de sonido e inspección [NPS].
- **Distancias:**
  - el apoyo a ≤ 2 mm de la muela en la Einhell y a ≤ 1/8″ (3,2 mm) en VEVOR y ANSI;
  - se reajustan al gastarse la muela;
  - el protector superior, a ≤ 1/4″ [EIN-BG, VEV-450, NPS, OSHA].
- **Al arrancar:** a un lado, nunca delante; una muela defectuosa suele romper al arrancar. Esperar a que llegue a su
  velocidad antes de apoyar [NPS, VEV-450, EIN-BG].
- **Al apoyar:** despacio y con poca presión al empezar; un golpe o mucha presión con la muela fría puede romperla
  [VEV-450].
- **Protección:** gafas o pantalla siempre y protección auditiva [NPS, VEV-450]. La TC-BG 150 da 82,3 dB(A) de
  presión sonora [EIN-BG].
- **El costado:** no se amuela con el costado de una muela recta, salvo con presión muy ligera [NPS, NORTON-B71]. El
  simulador avisa (`costado_muela`).
- **Si la muela se frena o se bloquea:** retirar la pieza, esperar a que recupere el giro y apoyar con menos fuerza
  [EIN-BG, EIN-WG].

### Cuchillos

- **La máquina:** la mejor es una lenta en agua (Tormek, TC-WG 200, SCM8082 o la húmeda de la TC-WD).
  - A 1–1,6 m/s y en agua el filo no pasa de ≈40 °C ni apretando (casos de referencia).
  - Lenta y en agua, el acero «nunca pierde el temple» [TOR-WAY].
- **La presión:** cuanta menos, más afilado; cuanta más, más arranque [EIN-WG]. En la TC-WD, desbastar solo si hace
  falta en la seca y afinar en la húmeda con poca presión [EIN-WD].
- **El ángulo:**
  - `sharpening.gd` da los de cada fabricante;
  - Tormek da ángulos totales de 20–25° en talla, 25–30° en fileteo, 30–40° en cocina (25–30° en cuchillos
    japoneses) [TOR-KNIFE];
  - pintar el bisel con rotulador sirve para encontrar y repetir el ángulo que tenía [TOR-WAY].
- **La dirección:**
  - en la piedra, con el filo hacia la muela («contra el filo»): da menos rebaba [VERHOEVEN] y más control
    [TOR-KNIFE];
  - en el cuero, siempre con la rueda alejándose del filo: si no, el filo corta el cuero [TOR-WAY, EIN-WG,
    VERHOEVEN].
- **La rebaba:**
  - se quita en la rueda de cuero con pasta, por las dos caras [EIN-WG];
  - con pasta de diamante de 1 µm u óxido de cromo el filo queda de 0,3–0,4 µm [VERHOEVEN];
  - el cuero sin pasta no quita la rebaba [VERHOEVEN].
- **En una esmeriladora seca:** solo para reperfilar, con presión muy ligera, pasadas rápidas y sin quedarse quieto.
  - Aun así el vértice pasa el revenido en décimas de segundo.
  - Enfriar en agua entre pasadas no basta: el filo se calienta en la propia pasada [KSN].
  - CATRA encontró ablandamiento del filo en más del 75 % de los cuchillos ensayados [KSN].
- **Nunca con la amoladora:** a 78 m/s, sin apoyo, con grano P40–P120, el filo se quema en centésimas y el disco puede
  enganchar la hoja.

### Hachas

- **Máquina y herramientas:** muela húmeda o piedra gruesa; lima para las mellas grandes; piedras y cuero para la
  rebaba [GRANSFORS].
- **Ángulo:** filo de 25–30° [GRANSFORS].
- **Calor:** no calentar el acero o perderá el temple; enfriar a menudo [GRANSFORS].
- **En la esmeriladora seca:** aguanta más que un cuchillo por su sección, pero hay que ir con cuidado.
- **La amoladora:** solo para una mella grande, en la posición más lenta.

### Cuchillas de cortacésped

- **Ángulo:** mantener el original, amolando solo la cara de arriba. Suelen ser 30°, y 35–45° en algunas marcas
  [TORO, AAS].
- **Equilibrado:** quitar lo mismo de los dos extremos y equilibrarla después [TORO, VEV-450].
- **Calor:** son de acero dulce y se estropean si se calientan; con herramienta eléctrica, dejar enfriar entre
  pasadas [HONDA].
- **Máquina:** una esmeriladora de banco va bien. La amoladora también, con disco de láminas, en la posición más
  lenta y con pasadas cortas.
  - A 3000 rpm, en 1 s la cuchilla no pasa de ≈110 °C (caso de referencia).
  - Para desbastar, el disco a 30–40° de la superficie, moviéndolo de un lado a otro [EIN-AG].

### Brocas

- **En la esmeriladora, a pulso:**
  - galga de 59° (punta de 118°) e incidencia de 8–12°;
  - labios de igual ángulo y longitud [TC9524-4].
- **Lo que pasa si no:**
  - labios desiguales: agujero mayor (0,17 mm en 10 mm con 0,1 mm de diferencia);
  - poca incidencia: el talón roza, la broca no corta y se rompe si se empuja;
  - mucha incidencia: el labio se mella [TC9524-4, MAZOFF].
- **Comprobar la incidencia:** mirar la arista transversal: 120° ≈ 8°, 130° ≈ 11° [MAZOFF].
- **Brocas pequeñas:** no dejar que se calienten; el azul indica que se ha perdido el temple [TC9524-4].
  - Una broca pequeña se calienta mucho antes que una grande.
  - Una broca muy caliente no se mete en agua fría: puede agrietarse [TC9524-4, NPS].
- **HSS M2:** aguanta el calor que ablanda al acero al carbono, pero sigue sin gustarle el azul.
- **Con la MR-13A:**
  - muela de CBN para HSS; con CBN solo entra ≈20 % del calor [MALKIN];
  - SDC (diamante) solo para metal duro, nunca para acero [MRCM-13A];
  - la pinza fija la broca: labios iguales y la incidencia de la máquina.

### Fresas

- **La máquina:** una afiladora universal de herramientas o una de fresas. A pulso en la esmeriladora no se puede
  [TC9524-5].
- **Ángulos:** incidencia primaria de 5–9° y secundaria de 14–17° [NACHI-EM].
- **Desplazamiento del dedo de apoyo:** 0,0088 × ángulo × diámetro [TC9524-5].
- **La MR-X3:**
  - SDC de serie para metal duro; CBN (opcional) para HSS;
  - diamante con acero nunca: se oxida por encima de 600 °C y reacciona con el hierro [MRCM-X3, `sharpening.gd`].

### Por máquina

- **Einhell TC-BG 150:**
  - muela gruesa para desbastar y fina para acabar;
  - apoyar la pieza en el apoyo y acercarla despacio al ángulo deseado;
  - moverla un poco de un lado a otro, para que la muela se gaste igual;
  - dejar enfriar la pieza de vez en cuando [EIN-BG];
  - S2 de 30 min: después, dejar enfriar el motor [EIN-BG].
- **Einhell TC-WD 200/150:** el desbaste siempre en la seca; el afinado en la húmeda, con poca presión y la muela
  1/3 en agua [EIN-WD].
- **Einhell TC-WG 200:**
  - llenar el depósito y dejar que la muela se empape;
  - la piedra de reavivar gruesa da más arranque y la fina, más filo;
  - galga de ángulos y soporte;
  - nunca usar el cuero en seco ni contra su giro [EIN-WG].
- **VEVOR MD150G-450:**
  - la pieza, algo por encima del centro de la muela;
  - reavivar la muela cuando se vidria;
  - no encender con la pieza tocando;
  - baño para enfriar las piezas gruesas [VEV-450].
- **VEVOR MD150-4:** la mitad de velocidad que la de 3450 rpm y la mitad de calor con la misma fuerza [VEV-1750].
- **VEVOR SCM8082:** guía de ángulo, plantilla recta y cubeta de agua; cuero para la rebaba [VEV-SCM].
- **Einhell TE-AG 125 CE:**
  - discos de ≥ 12 000 rpm y 80 m/s;
  - nunca un disco de corte para desbastar;
  - protector de desbaste;
  - posiciones de 3000 a 12 000 rpm: para lo que se destempla, la más lenta [EIN-AG].
- **Einhell TC-AG 125/850:** 12 000 rpm fijas, sin regulación: calienta más que la regulable [EIN-TCAG].
- **MRCM MR-13A y MR-X3:** muela según el material (CBN para HSS, SDC para metal duro) y pinza del diámetro justo
  [MRCM-13A, MRCM-X3].
- **Tormek T-8:**
  - lenta y en agua: sin riesgo para el temple;
  - rueda de cuero LA-220 con pasta, siempre girando alejándose del filo [TOR-T8, TOR-WAY].

## 7. Guía de integración para la oleada 2

### 7.1 Estado

`sharpening_sim.gd`: un `RefCounted` por simulación, sin variables estáticas. Guarda:

- **Selección:** `machine_id`, `wheel` (id), `rpm` (solo la TE-AG), `diameter_mm` (muela gastada).
- **Herramienta:** `kind` (`cuchillo`, `broca`, `fresa`, `hacha`, `cortacesped`), `steel_id` y su geometría.
  - Cuchillo: `per_side_deg`, `thickness_mm`, `spine_mm`, `height_mm`, largo del filo.
  - Broca: `diameter_mm`, `point_deg`, `clearance_deg`, `lip_height_diff_mm`.
  - Fresa: `diameter_mm`, `primary_deg`, `secondary_deg`.
- **Perfil térmico**, una vez al elegir la herramienta: `ET.knife_profile()`, `ET.edge_profile()` (hacha y
  cortacésped) o `ET.drill_profile()`.
- **Secciones:** `sections: Array` de `EdgeThermal`, 8–16 a lo largo del filo en un cuchillo y 1–2 en una broca (una
  por labio). Todas con el mismo perfil, que solo se lee.
- **Contacto:** `contact = G.knife_contact(...)` o `G.edge_contact(...)`. En una broca, `drill_profile()` ya trae
  `heated_area_mm2`.
- **Estado de la mano:** fuerza, ángulo, posición a lo largo del filo, velocidad de barrido, si toca la muela, si
  está en el agua.
- **Tiempos y contadores:** tiempo, pasadas, rebaba (de `sharpening.gd`, `burr_removal`).

### 7.2 Bucle

Subpasos de dt ≤ 5 ms; 4 por fotograma a 60 fps.

```gdscript
const Machines = preload("res://core/taller/sharpening_machines.gd")
const G = preload("res://core/taller/grinding.gd")
const ET = preload("res://core/taller/edge_thermal.gd")

# Una vez por fotograma (o cuando cambie algo): dos llamadas a grind(), ≈0,1 ms
var base := { "machine_id": machine_id, "wheel": wheel_id, "rpm": rpm, "diameter_mm": d_mm, "force_n": force_n,
		"contact_area_mm2": float(contact["area_mm2"]), "steel_id": steel_id, "mode": mode }
var cold := G.grind(base)                                    # el agua todavía enfría
var hot := G.grind(base.merged({ "surface_c": 131.0 }))      # el agua ya hierve en película
# Cada subpaso, cada sección (en serie o en una tarea por sección con prioridad alta)
for i in sections.size():
	var sec: RefCounted = sections[i]
	var cov := ET.sweep_coverage(z_mm[i], c0_mm, float(contact["contact_len_mm"]), v_sweep_mm_s, dt) if touching else 0.0
	var g: Dictionary = cold if sec.call("contact_surface_c") < 130.0 else hot
	var cooling := "pelicula_agua" if bool(g["wet"]) and cov > 0.0 else ("inmersion" if dipped else "aire")
	sec.call("step", dt, float(g["heat_flux_w_m2"]), cov, cooling, water_c)
# Al final del fotograma
var blade := ET.combine(sections)          # peor sección, media del vértice, pérdida máxima, quemado
```

- **Calada** (`stalled`): `heat_flux_w_m2` ya es 0 y el sonido va con giro 0.
- **`wet` de `grind()`** es agua en el contacto (la muela gira en agua). Por defecto es el de la muela; no se pone a
  true en una muela seca. Meter la hoja en agua entre pasadas es otra cosa: el medio `inmersion` de `step()` mientras
  no toca la muela.
- **Arranque:** el metal arrancado de `cold`/`hot` (`removal_mm3_s × dt × cobertura`) hace retroceder el bisel.
  Sirve para la rebaba y para cuándo se ha «llegado al filo».
- **Hilos:**
  - una tarea por sección y fotograma: `WorkerThreadPool.add_group_task(f, n, -1, true)`, esperando antes de
    `combine()`;
  - las secciones no comparten nada que se escriba;
  - `grind()` y los perfiles son funciones puras;
  - no hace falta ningún cerrojo.

### 7.3 Controles del usuario

- **Máquina y muela:**
  - la máquina, con `Machines.machines_for(kind)` para ordenarlas por adecuación;
  - la muela: las montadas y los recambios de las MRCM y la TE-AG;
  - el giro, solo en la TE-AG (6 posiciones);
  - el diámetro de la muela gastada.
- **Herramienta:** tipo, acero (`STEELS` y `metal_duro`) y geometría (ángulo por lado, espesor; en la broca: punta,
  incidencia, diferencia de labios, avance de trabajo).
- **La mano:**
  - fuerza, con `G.HAND_FORCE` (5–40 N) como escala y un deslizador continuo;
  - ángulo de apoyo;
  - velocidad de barrido;
  - tocar o no la muela;
  - modo `periferia` o `cara` (el costado de la muela).
- **Agua:** meter la hoja en agua entre pasadas (`inmersion`); en las húmedas, el agua va con la muela.

### 7.4 Qué se enseña

- **Velocidad, fuerza y calor:** la misma fuerza a más m/s mete más calor. Las lentas en agua no calientan; la seca
  de banco pasa el revenido en décimas de segundo; la amoladora quema.
- **Poca presión:** más fuerza, más calor y más metal, y un motor pequeño se frena o se cala.
- **El agua:** enfría mientras no hierve (130 °C). Meter la hoja entre pasadas baja lo acumulado, pero no el pico de
  la pasada.
- **Color y dureza:** el color de revenido llega tarde; el acero pierde dureza antes (HRC y ancho ablandado).
- **El acero:** M2 aguanta; el inox de cocina y el 1095 no.
- **Broca pequeña frente a grande;** labios desiguales → agujero mayor; incidencia → roza o se mella; el avance se
  come la incidencia junto al centro.
- **Abrasivo:** nunca diamante para acero; CBN para HSS; diamante o SiC verde para metal duro.
- **Seguridad:**
  - la velocidad máxima marcada;
  - el apoyo a ≤ 2–3,2 mm;
  - no amolar con el costado;
  - no ponerse delante al arrancar.

### 7.5 Campos de resultado para la interfaz

Todos los números visibles, con `core/shared/js.gd` (`to_fixed`, `js_num_str`).

- **De `grind()`:**
  - velocidad y motor: `vs_ms`, `rpm`, `rpm_no_load`, `load`, `overloaded`, `stalled`;
  - potencia y calor: `power_w` [`power_min_w`, `power_max_w`], `partition`, `coolant_effective`, `heat_flux_w_m2`
    [`heat_flux_min_w_m2`, `heat_flux_max_w_m2`];
  - arranque: `specific_energy_j_mm3`, `removal_mm3_s` [`removal_min_mm3_s`, `removal_max_mm3_s`];
  - seguridad y muela: `over_speed`, `max_speed_ms`, `abrasive_id`, `wet`, `honing`;
  - para la escena: `sparks`, `sound`;
  - `warnings [{ code, message, source }]`, `sources`, `quality`.
- **De `summary()`, por sección:**
  - temperaturas: `edge_c`, `max_c`, `max_x_mm`, `peak_edge_c`, `peak_max_c`, `edge_surface_peak_c`;
  - color: `tint { temp_c, hex, name, table }` o `null`, `tint_width_mm`;
  - dureza: `hardness { loss_hrc, hrc, beyond, source, quality }` o `null`, `temper_equiv_c`, `softened_width_mm`;
  - tiempos: `t_over_temper_s` y `t_loss_1hrc_s` (−1 si no pasa);
  - quemado: `burned`, `burn_width_mm`;
  - comprobaciones: `energy`, `validity { through_thickness_ms, note }`, `quality`, `sources`.
- **De `combine()`:** `peak_edge_c`, `hottest_section`, `mean_edge_c`, `max_loss_hrc`, `tinted_sections`, `burned`.
- **De `drill_check()` y `mill_check()`:**
  - `findings [{ code, severity: ok | aviso | mal, message, source }]`, `ok`, `recommended`;
  - en la broca: `offset { offset_mm, oversize_mm, hole_mm, tolerance_mm, within_tolerance }`,
    `effective_clearance_deg { outer, inner }`, `chisel_deg`, `wedge_deg`;
  - en la fresa: `offset_mm`.

**Reglas de presentación:**
- **Quemado:** si `burned`, enseñar «quemado (> 723 °C)» y no la cifra.
- **Incertidumbre:** junto a la temperatura, la banda (q_min–q_max escala casi igual la subida de temperatura).
- **Calidad:** los datos `estimate` llevan su marca.

## 8. Datos para la oleada 3 (escena 3D y sonido)

- **`set_machine(view)`:** `Machines.view(machine_id, wheel_id, diameter_mm)` (§2.3).
- **`set_state(view)`:**
  - `edge_temp_c`: una `PackedFloat32Array` con el `edge_c()` de cada sección, en orden;
  - `max_temp_c`: `combine()["peak_edge_c"]`, o el `max_c()` más alto;
  - los colores de revenido a lo ancho del bisel: `surface_peaks()` y `x_mm()` de cada sección pasados por
    `ET.tint(steel_id, T)`, que devuelve el `hex`; la escena solo los pinta;
  - `sparks`: `grind()["sparks"]` → `sparks.gd` (`resolve_stream(material_id, sparks, vs_ms)` o `configure()`). La
    longitud y el color del chorro los pone `sparks.gd` según la velocidad;
  - `water`: `grind()["wet"]`. Si `coolant_effective` es false con la muela húmeda, el agua hierve en el contacto y
    se puede enseñar vapor;
  - `rpm_actual`: `grind()["rpm"]`.
- **Sonido:**
  - `grind()["sound"]` → `machine_sound.gd` `frame()`, con `mains_hz` (50 o 60 según la máquina), `speed_droop`,
    `diameter_mm` y, en la amoladora, `disc_id`;
  - el zumbido del motor está en 2·f (100 o 120 Hz);
  - `machine_sound.gd` tiene cachés en `static var`: hay que llamarlo desde el hilo principal.
- **Máquinas lentas:** a 100–155 rpm el giro de la muela no suena; suena el motor y, en las húmedas, el agua.

## 9. Estimaciones

| Dato | Valor | Dónde | Por qué es estimación |
|---|---|---|---|
| Fuerza de la mano | 5 / 10 / 20 / 40 N | `grinding.gd` `HAND_FORCE` | sin medida publicada al afilar a mano |
| Energía específica al afilar | 90 J/mm³ (62–200) templado; 40 (25–90) blando | `SPECIFIC_ENERGY` | medida en rectificado; a mano el espesor de viruta es menor |
| Reparto con diamante | 0,20 (0,15–0,50) | `PARTITION_BAND` | sin medida en acero (no se amola acero con diamante) |
| Modelo de motor | η, caída, par máximo | `MOTORS` | los fabricantes solo dan la potencia de entrada |
| Umbral de chispas | 5 m/s | `SPARK_MIN_MS` | el ensayo de chispas pide ≥ 25 m/s; por debajo de 5 se da por apagado |
| h de enfriamiento | aire 15; agua 500 / 10 000; película 250 | `edge_thermal.gd` `COOLING` | dentro de los intervalos de los libros; no hay medidas en una hoja al afilar |
| Punta de broca | sección llena 0,55; alma 0,15·D; contacto 1/4 de vuelta | `DRILL` | geometría genérica |
| Factor del agua | ×0,42 | `sharpening_heat.gd` `WET_FACTOR` | ya existente |
| Abrasivo de la TC-BG 150 y de la seca de la TC-WD | corindón | catálogo | el fabricante no lo dice |
| Abrasivo de las húmedas de la TC-WD y la SCM8082 | sin dato (se toma corindón) | catálogo | el fabricante no lo dice |
| Curva de revenido del VG-10 | la del 14C28N | `TEMPER_CURVES` | Takefu no la publica |
| Colores del inox para los martensíticos | tabla del 1.4301 | `panels.gd` | medida en austenítico |
| Ángulo de la MR-X3 | 0–5° = *dish* | catálogo | interpretación de la ficha |
| Lado de las muelas de VEVOR y SCM8082 | convención de dibujo | `layout` | el fabricante no lo dice |
| Cuchilla de cortacésped | propiedades térmicas del 1095 | caso de referencia | no hay ficha del acero de las cuchillas |

## 10. Para el coordinador

**Añadidos que pido para `godot/CONTRATOS.md`:**
- **Catálogo de afiladoras:**
  - el esquema de la cabecera de `sharpening_machines.gd`: `kind`, `motor`, `wheels` con `position` y `mounted`,
    `layout`, `water_trough`, `quench_pot`, `for_tools`;
  - `view()` como constructor de `set_machine(view)`, con dos campos de más: `rpm` por muela (la combinada tiene
    dos giros) y `width_mm: null` cuando no hay dato.
- **Salida de `grind(p)`:** la lista de §7.5, con los códigos de aviso:
  - `muela`, `giro_fijo`, `diametro`, `muela_gastada`, `exceso_velocidad`;
  - `se_cala`, `se_frena`;
  - `diamante_acero`, `sic_acero`, `abrasivo_metal_duro`;
  - `agua_hierve`, `costado_muela`, `sin_datos`.
- **API de `edge_thermal.gd`:**
  - una instancia por sección, `step(dt ≤ 5 ms, q, coverage, cooling, t_inf)`, `summary()`;
  - `combine()` en orden fijo;
  - seguridad para hilos y `WorkerThreadPool` con prioridad alta.
- **Formato de los casos de referencia** (`tests/fixtures/spec/afilado.json`, §4.4).
- **Tipos de herramienta** de `for_tools`: `cuchillo`, `broca`, `fresa`, `hacha`, `cortacesped`.
  - `set_tool(view)` de la vista 3D solo tiene los tres primeros. Hay que añadir hacha y cuchilla de cortacésped o
    dibujarlas como cuchillo.
- **`metal_duro`** como material de herramienta en `grind()` y `abrasive_suits()` (viene de
  `sharpening.gd`, `TOOL_MATERIALS`).

**A la unidad 1h** (dueña de `radial.gd`, `sparks.gd`, `abrasives.gd`):
- `grinding.gd` usa `Radial.SPARKS_PER_MM3`, `Sparks.signature_for()` y `Sparks.family_of()`: que no cambien de
  nombre.
- El disco de láminas de `abrasives.gd` tiene `thickness_mm: 0.0` (sin dato). La escena 3D necesitará un grosor, y
  no he encontrado fuente.

**Hilos.** `machine_sound.gd` guarda cachés en `static var` (`_sheet_key_hz`, `_ref_hz`). No es seguro llamarlo
desde hilos del pool: el sonido se calcula en el hilo principal.

**Interfaz actual.** Usa `SHARPENING_MACHINES` de `sharpening.gd` (tres máquinas genéricas). La oleada 2 tiene que
pasar al catálogo nuevo. `recommend_sharpening` sigue sirviendo para los ángulos y la progresión de granos.

**Documentación.** `docs/TALLER.md`: añadida la fila de los módulos nuevos y corregidas las dos frases que decían que
no se calcula la temperatura absoluta del filo.

## 11. Fuentes

**Máquinas**
- [EIN-BG] Einhell, TC-BG 150 (art. 44.126.32), manual original (I.-Nr. 11019, 2020).
  <https://d.otto.de/files/1d6cd03e-1edb-5f5b-8ca9-a67deb5588bf.pdf> · ficha:
  <https://www.einhell.de/p/4412632-tc-bg-150/>
- [EIN-MUELAS] Einhell, muelas de recambio:
  - 49507435 (K36): <https://www.einhell.de/p/49507435-schleifscheibe-o-150-x-32-x-16-mm-k36/>
  - 49507465 (K60): <https://www.einhell.de/p/49507465-schleifscheibe-k60-o-150-x-32-x-16-mm/>
  - 49507535: <https://www.einhell.de/p/49507535-schleifsch-150x12-7x20mm-g36/>
- [EIN-WD] Einhell, TC-WD 200/150 (44.172.42), manual original.
  <https://www.tooled-up.com/artwork/ProdPDF/Einhell-TC-WD-200-150-Wet-and-Dry-Bench-Grinder-User-Manual.pdf>
- [EIN-WG] Einhell, TC-WG 200 (44.180.08), manual original.
  <https://gzhls.at/blob/ldb/3/c/6/0/2daecb732aa9688403d9e7e93c4949f30200.pdf> · ficha:
  <https://www.einhell.de/p/4418008-tc-wg-200/>
- [EIN-AG] Einhell, TE-AG 125 CE (44.308.60), manual original (I.-Nr. 21074, 2025).
  <https://d2c5rvsfjg2eub.cloudfront.net/asset/208244749100/document_ufaki108c11s9dl93ehfv17k0r/4430860_21074_001_SPK4.pdf>
  · ficha: <https://www.einhell.de/p/4430860-te-ag-125-ce/>
- [EIN-TCAG] Einhell, TC-AG 125/850. <https://www.einhell.de/p/4430971-tc-ag-125-850/>
- [VEV-450] VEVOR, esmeriladora de banco MD150G-450:
  - manual: <https://images.thdstatic.com/catalog/pdfImages/88/888c6030-be54-4b7d-b903-7af3b278102a.pdf>
  - ficha: <https://www.vevor.com/bench-grinder-c_11010/vevor-bench-grinder-6-inch-bench-grinder-450w-3450rpm-high-speed-table-grinders-p_010633655751>
- [VEV-1750] VEVOR, MD150-4.
  <https://www.vevor.com/bench-grinder-c_11010/vevor-bench-grinder-6-inch-bench-grinder-250w-1750rpm-low-speed-table-grinders-p_010646764283>
- [VEV-SCM] VEVOR, SCM8082.
  <https://www.vevor.com/power-belt-sanders-c_14191/vevor-8-inch-wet-sharpening-system-water-cooled-knife-grinder-machine-with-155-rpm-grinding-speed-vertical-horizontal-two-direction-wet-stone-grinder-wet-bench-grinder-for-knife-chisel-knife-axe-p_010249592357>
- [MRCM-13A] MRCM (Zhejiang Meiri), MR-13A:
  - fabricante: <https://www.zjmrcm.com/products/drill-sharpener/267.html>
  - VEVOR: <https://www.vevor.com/end-mill-sharpener-c_10118/vevor-mr-13a-drill-bits-sharpener-3-13mm-end-mill-grinder-sharpener-11-collets-p_010251353147>
- [MRCM-X3] MRCM, MR-X3. <https://www.zjmrcm.com/products/mill-sharpener/327.html>
- [MUELAS-MR] Muelas de recambio Ø78 × 10 × 12,7, grano 230, CBN y SDC (anuncio de CPTRMCY, vía buscador).
  <https://www.amazon.com/CPTRMCY-Diamond-Grinding-Tungsten-X1-SDC230/dp/B0DKTSV53V>
- [TOR-T8] Tormek:
  - T-8 Original: <https://tormek.com/en/products/sharpening-machines/tormek-t-8-original>
  - SG-250: <https://tormek.com/en/products/grinding-wheels/original-grindstones/sg-250-original-grindstone>
- [TOR-WAY] Tormek, «The Tormek way of sharpening». <https://tormek.com/en/knowledge/the-tormek-way-of-sharpening>
- [TOR-KNIFE] Tormek, «Knife sharpening».
  <https://tormek.com/en/knowledge/how-to-sharpen-your-tools/knife-sharpening>
- [PFERD] PFERD, *Werkzeughandbuch* 23 (2019): discos POLIFAN y de desbaste (vía `abrasives.gd`).

**Amolado**
- [BIRO] Biro, Hagan y Gustafson (Saint-Gobain Abrasives), «Understanding forces in creep-feed grinding», SME, 2019.
  <https://www.sme.org/globalassets/sme.org/technologies/articles/2019/02---february/understanding-forces-in-creepfeed-grinding.pdf>
- [ROWE] Rowe, Morgan, Batako y Jin, «Energy and temperature analysis in grinding», *WIT Transactions on Engineering
  Sciences* 44 (2003). <https://www.witpress.com/Secure/elibrary/papers/LAMDAMAP03/LAMDAMAP03001FU.pdf>
- [MALKIN] Malkin y Guo, «Thermal analysis of grinding», *CIRP Annals* 56(2):760–782 (2007).
  DOI [10.1016/j.cirp.2007.10.005](https://doi.org/10.1016/j.cirp.2007.10.005)

**Transmisión de calor**
- [CARSLAW] Carslaw y Jaeger, *Conduction of Heat in Solids*, 2.ª ed., Oxford (1959): sólido semiinfinito con flujo
  constante.
- [INCROPERA] Incropera, DeWitt, Bergman y Lavine, *Fundamentals of Heat and Mass Transfer*, 6.ª ed., Wiley (2007),
  tabla 1.1.
- [MTU] Morrison, «Typical values of the heat transfer coefficient», Michigan Tech.
  <https://pages.mtu.edu/~fmorriso/cm3120/typical_values_heat_transfer_coefficient.pdf>
- [NUCLEAR-POWER] «Pool boiling – boiling curve».
  <https://www.nuclear-power.com/nuclear-engineering/heat-transfer/boiling-and-condensation/pool-boiling-boiling-curve/>
- [CUKROV] Cukrov, Sato, Landek, Hannoschöck, Boras y Ničeno, «Determination of heat transfer coefficient in a film
  boiling phase of an immersion quenching process», *Applied Sciences* 15(3):1021 (2025).
  DOI [10.3390/app15031021](https://doi.org/10.3390/app15031021)

**Revenido y aceros**
- [HJ] Hollomon y Jaffe, «Time-temperature relations in tempering steel», *Trans. AIME* 162:223–249 (1945).
- [THOMAS] Thomas, Speer, Matlock, Krauss y Hackenberg, «Time-temperature equivalence in martensite tempering»,
  ICOMAT-08, TMS (2009), fig. 1.
  <https://wpfiles.mines.edu/wp-content/uploads/aspprc/ResearchMaterials/Publications/445-Thomas.pdf>
- [SIJ] SIJ Metal Ravne, SINOXX 4116 (1.4116). <https://steelselector.sij.si/data/pdf/PK5.pdf>
- [ALLEIMA] Alleima, ficha de 14C28N (2024).
  <https://www.alleima.com/contentassets/7a282aed5b6c477596d85f22176b2078/datasheet-alleima-14c28n-en-v2024-01-11-1029-version-1.pdf/download>
- [BOHLER] Böhler, S600 (M2). <https://www.us.bohler.com/app/uploads/sites/248/productdb/api/s600_en_us.pdf>
- [NJSB] New Jersey Steel Baron, tratamiento térmico del 1095.
  <https://cdn.newjerseysteelbaron.com/wp-content/uploads/2020/07/1095-Heat-Treat-7-20.pdf>
- [TAKEFU] Takefu Special Steel, VG10.
  <https://www.barmondsheffield.com/wp-content/uploads/2022/07/%E7%86%B1%E5%87%A6%E7%90%86VG10.pdf>
- [NATURE1922] «The colours of tempered steel», *Nature* 109:106 (1922).
  DOI [10.1038/109106a0](https://doi.org/10.1038/109106a0)
- Colores de revenido: Engineering ToolBox, «Steel tempering colors», y BSSA, «Heat tint (temper) colours on
  stainless steel surface heated in air» (vía `panels.gd`).

**Afilado, brocas y fresas**
- [VERHOEVEN] Verhoeven, «Experiments on knife sharpening», Iowa State University (2004).
  <https://northarmknives.com/wp-content/uploads/2016/01/knifeshexps.pdf>
- [KSN] Thomas (Knife Steel Nerds), «Does sharpening with a grinder ruin your edge?» (2019).
  <https://knifesteelnerds.com/2019/04/08/does-sharpening-with-a-grinder-ruin-your-edge/>
- [TC9524-4] y [TC9524-5] US Army, TC 9-524, caps. 4 y 5.
  <https://uhv.cheme.cmu.edu/procedures/machining/ch4.pdf> · <https://uhv.cheme.cmu.edu/procedures/machining/ch5.pdf>
- [NACHI-EM] Nachi America, «End mill training».
  <https://www.nachiamerica.com/content/training/End%20Mill%20Basic%20Training.pdf>
- [MAZOFF] Mazoff, «Drill point geometry» (Newman Tools). <https://www.newmantools.com/machines/drillpoint.html>
- [US4031672] Patente US 4031672 A (1977). <https://patents.google.com/patent/US4031672A/en>
- [US4561813] Patente US 4561813 A (1985). <https://patents.google.com/patent/US4561813A/en>
- [GRANSFORS] Gränsfors Bruk, reafilado. <https://www.gransforsbruk.com/en/the-axe-guide/axe-care/resharpening>
- [TORO] Toro, manual 205759. <https://manuals.toro.com/205759/index.html> · «Sharpening rotary mower blades»:
  <https://www.toro.com/en/customer-support/education-and-tech-reference/service-tips/sharpening-rotary-mower-blades>
- [HONDA] Honda Lawn Parts, «How to sharpen a lawnmower blade».
  <https://blog.hondalawnparts.com/how-to-sharpen-a-lawnmower-blade/>
- [AAS] All American Sharpener, «Blade guide». <https://www.allamericansharpener.com/blade-guide>

**Seguridad**
- [NPS] Naval Postgraduate School, «Safety Gram: pedestal / bench grinder».
  <https://nps.edu/documents/111291366/111353794/SafetyGram_grinders_Bench_Ped.pdf/509adf27-9172-4bd8-b3c7-1e97998d038f>
- [OSHA] 29 CFR 1910.215. <https://www.osha.gov/laws-regs/regulations/standardnumber/1910/1910.215>
- [NORTON-B71] Norton, «ANSI B7.1».
  <https://www.nortonabrasives.com/en-us/resources/expertise/ansi-b71-industry-standard-grinding-wheel-safety>

## Integración, oleada 2

### El simulador (`core/taller/sharpening_sim.gd`)

- **Qué es.** Un `RefCounted` por ensayo, determinista y sin nodos. Se configura con `configure({ machine_id, wheel,
  rpm, diameter_mm, tool: {…}, hand: {…} })`, se arranca con `start()` y avanza con `advance(s)` en subpasos de
  1/240 s (4 por fotograma a 60 fps). `snapshot()` devuelve un diccionario nuevo con todo lo que pintan la página, la
  escena 3D (`state3d`, `view_machine`, `view_tool`) y el sonido (`sound`, la entrada de `MachineSound.frame()` con
  el proceso de la máquina).
- **Una pasada.** La mano apoya la herramienta con su fuerza y su ángulo (con plantilla, o a pulso con una variación de
  ±N° por pasada que elige el usuario), barre el filo a su velocidad (o se queda quieta el tiempo que diga) y descansa
  entre pasadas, en el aire o metiendo la hoja en agua. Cada subpaso, `grind()` da el calor y el metal arrancado (dos
  llamadas por cambio de ajustes: con el agua enfriando y con el agua ya hirviendo en película), cada sección del filo
  avanza su `EdgeThermal` y su bisel, y se combinan en orden fijo.
- **Bisel y rebaba** (`sharpening_bevel.gd`). El filo romo es un plano de ancho `flat_um`. Las caras nuevas son
  rectas al ángulo de la mano que retroceden con el metal arrancado (`removal_mm3_s` / área de contacto). El filo está
  hecho cuando el espesor en el plano romo llega a cero. Desde entonces, cada pasada por una cara deja la rebaba en la
  otra. En el cuero con pasta, girando alejándose del filo, la quitan 12 pasadas (estimación, [VERHOEVEN]).
- **Hilos.** Las secciones no comparten nada que se escriba: un tramo de hasta 8 subpasos se reparte con
  `WorkerThreadPool.add_group_task(f, n, -1, true)` (prioridad alta), una tarea por sección. El reloj es un contador
  entero de subpasos, así que el resultado es el mismo, al bit, con 1 hilo o con N y sea cual sea el reparto del tiempo
  en llamadas (`tests/taller/test_sharpening_sim.gd`).
- **Sin programa, no avanza.** Al acabar la última pasada (con su descanso) la hoja se queda como estaba: la página
  escribe «al acabar» junto a la temperatura. El enfriamiento del cuerpo de la hoja tarda minutos (convección de
  15 W/(m²·K), estimación de `COOLING`), y no se simula fuera del programa.

### La página (`app/taller/ui/sharpener_page.gd`)

- **El simulador va en su propio hilo** (`sharpen_runner.gd`): la página manda órdenes (`configure`, `start`,
  `pause`, `stop`, `reset`) y pide tiempo de proceso cada fotograma (el del fotograma × la velocidad de simulación,
  ×0,25 a ×10). El hilo del simulador aplica las órdenes en orden, avanza y publica una instantánea nueva (doble
  búfer). La página pinta la última publicada: nunca espera a la física. Si el equipo no da abasto, el tiempo pendiente
  se recorta a 1 s: la simulación va más despacio, no se atasca. Sin ventana (tests), lo mismo en el hilo que llama.
- **Aquí no se calcula nada.** Todos los números salen del core y solo se les da formato con `fmt.gd` (que usa
  `js.gd`). Hay un test que lo vigila en el código (`tests/app/test_sharpener_ui.gd`).
- **Qué se ve:**
  - aviso educativo y de seguridad (valores orientativos; temperaturas ±40 %; nunca por encima de la velocidad máxima
    marcada; la amoladora, solo para hachas y cuchillas de cortacésped, nunca para un cuchillo de cocina);
  - máquinas del catálogo en sus grupos (Einhell, VEVOR, amoladoras, afiladoras de brocas y fresas de MRCM, Tormek de
    referencia), con la ficha: motor, giro en vacío, cada muela con su velocidad periférica frente a la máxima marcada,
    apoyo, ruido y peso, fuente y calidad; la adecuación para la herramienta (`Machines.suitability`);
  - herramienta (tipo, acero y geometría), la mano y las pasadas, y la recomendación de `sharpening.gd`;
  - lecturas en directo: velocidad periférica, giro (y si se frena o se cala), fuerza, potencia (con su banda),
    temperatura del filo (con su banda ±40 %), pico, color de revenido, dureza (HRC y pérdida), bisel, rebaba, pasada
    y metal arrancado;
  - la vista 2D (`sharpen_view.gd`): la muela a escala girando, con su agua; la herramienta, apoyada o en el aire o en
    el agua; las chispas de `sparks.gd`; la sección del filo más caliente, con el bisel de antes, las caras nuevas que
    avanzan, el plano romo o el vértice, la rebaba (en esquema) y cada celda de `edge_thermal.gd` coloreada con su
    temperatura, y el color de revenido de la cara; y el filo a lo largo, sección a sección;
  - la gráfica temperatura–tiempo (`sharpen_chart.gd`), con los ratos de contacto, el revenido de fábrica del acero,
    los 130 °C del agua y el quemado de 723 °C (por encima, «quemado»: no se da la cifra);
  - el informe al acabar: nota de 0 a 10, criterios, consejos con su fuente, y los avisos del ensayo con su fuente.
- **La escena 3D.** Si existe `app/taller/sharpen3d/sharpen_3d.tscn`, la página la carga y le pasa `set_machine`,
  `set_tool`, `set_state` y `set_view` con los diccionarios del contrato; si no, la vista 2D ocupa su sitio.
- **El sonido.** `sound_input()` devuelve la entrada de `MachineSound.frame()` de la instantánea (vacía si no hay
  programa). El reproductor la calcula en el hilo principal (`machine_sound.gd` tiene cachés estáticas).
- **Teléfono.** Por debajo de 820 px de ancho (`COMPACT_W` de la sección), una columna (`two_pane.gd`) y las lecturas
  en dos columnas.

### Qué enseña y de dónde sale cada número

| Lo que se ve | De dónde sale | Calidad |
|---|---|---|
| Velocidad periférica y máxima marcada | `Machines.wheel_speed` (π·D·n con el diámetro de la muela gastada) y la ficha de la muela o del disco | primaria (ficha) |
| Giro y frenado del motor | `grind()` → `motor_state` (`MOTORS`) | estimación (§9) |
| Fuerza y su nombre | la mano (deslizador) y `G.HAND_FORCE` | estimación |
| Potencia, calor y metal arrancado | `grind()`: fuerzas, reparto del calor, energía específica | §3.4–3.7 |
| Temperatura por sección, pico y banda | `edge_thermal.gd` con el flujo de `grind()`; banda con q_min–q_max | estimación ±40 % |
| Color de revenido | `ET.tint` (tablas de `panels.gd`) | secundaria |
| Dureza y pérdida | Hollomon–Jaffe acumulado y la curva de revenido del acero | §3.9 |
| Bisel, filo y rebaba | `sharpening_bevel.gd` con el metal arrancado | modelo geométrico |
| Recomendación (ángulos, abrasivo, granos) | `recommend_sharpening` de `sharpening.gd` | primaria/secundaria |
| Ángulo de la cuchilla de cortacésped | `MOWER_ANGLE` (30°; 35–45° en algunas marcas) [AAS], [TORO] | secundaria |
| Nota y consejos | `sharpening_report.gd` | rúbrica didáctica |

- **La nota es una rúbrica didáctica, no una medida.** Parte de 10 y resta por criterio (filo sin terminar, quemado,
  pérdida de dureza, color, ángulo fuera de lo recomendado, rebaba, máquina que no sirve, exceso de velocidad…). Cada
  consejo lleva su fuente; los pesos de la rúbrica no son datos.
- **Lo que enseña cada escenario de la demostración** (`app/taller/demo_afilado.tscn`):
  - cuchillo de cocina en la Einhell TC-BG 150 en seco, despacio y apretando: pasa el revenido y se quema
    (> 723 °C), con color y pérdida de HRC [KSN];
  - el mismo cuchillo en la TC-WG 200 (lenta y en agua): no pasa de 130 °C y conserva la dureza [TOR-WAY];
  - broca de 8 mm en la MRCM MR-13A con CBN: poco calor y punta dentro de lo recomendado [TC9524-4], [MRCM-13A];
  - hacha con amoladora y disco de láminas en la posición más lenta: se calienta mucho más que en una lenta; solo para
    reparar mellas [GRANSFORS], [EIN-AG].

### Estimaciones que añade el simulador

| Dato | Valor | Dónde | Por qué es estimación |
|---|---|---|---|
| Largo del contacto sin ancho de muela | 16 mm (MD150-4); 20 mm (disco de láminas) | `CONTACT_LEN_FALLBACK` | el fabricante no da el ancho; los de los casos de referencia |
| Pasadas por el cuero para quitar la rebaba | 12 | `HONE_PASSES` | Verhoeven da 12–15 con diamante de 1 µm |
| Acero de la cuchilla de cortacésped | propiedades térmicas del 1095, sin curva de revenido | `MOWER_THERMAL_SOURCE` | no hay ficha (Honda: acero dulce) |
| Geometría de partida (romo, largo, espesores) | por herramienta | `TOOL_DEFAULTS` | punto de partida del ensayo, a elegir |
| Pasadas, descansos y barrido de partida | por tipo de máquina | `HAND_DEFAULTS` | barrido de Verhoeven en las lentas; el resto, a elegir |
| Variación del ángulo a pulso | ±3° de partida | la mano | la elige el usuario; no hay medida |

### Rendimiento

- Medido en el contenedor de pruebas (4 núcleos compartidos, cargado): cuchillo de 16 secciones a ×1, con la
  instantánea, ≈4 ms por fotograma en serie y ≈3,5–3,8 ms repartido entre los núcleos
  (`tests/taller/test_sharpening_sim.gd` lo escribe en cada pasada). A ×10 son ≈80 subpasos por fotograma: unos
  25 ms de trabajo, en el hilo del simulador, no en el de la interfaz.
- `npm run godot:bench` tiene la tarea `taller.sharpening_sim` con 1 hilo y con todos.
- En un Ryzen 9 7900 (12 núcleos) las 16 secciones van a la vez: el coste por fotograma queda en el de una sección y
  la instantánea.

### Lo que no hace (todavía)

- **Fresas:** sin temperatura (la especificación no define el perfil térmico del diente). **Metal duro:** sin
  propiedades térmicas en `STEELS` ni curva de revenido; su riesgo es la fisuración por calor, que el modelo no calcula.
- **Rebaba de brocas y fresas:** no se modela; solo el desgaste del flanco que se quita.
- **Enfriamiento después del programa:** ver arriba.
