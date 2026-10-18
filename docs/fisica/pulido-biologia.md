# Pulido del laboratorio (biología) · zonas del cuerpo, hueso, roce, ángulo de ataque y esmalte (modelo 2.0)

Especificación del modelo 2.0 de la tribología biológica en cuatro temas: la piel de **cinco zonas del cuerpo** (brazo,
palma, dorso de la mano, cara y abdomen), el **hueso** que hay debajo y el **roce en los flancos** de una punta que entra
hondo, el **ángulo de ataque** explícito al rayar y el **esmalte** de la punta de los colmillos. Sin zona ni ángulo, el
banco hace lo de la 1.x salvo donde el hueso o el esmalte cambian el resultado (§9.4).

- Datos: `godot/core/lab/zones.gd` (zonas, capas con fuente y calidad, huesos, médula, umbrales por zona).
- Física: `godot/core/lab/penetration.gd` (grieta por capas, roce, hueso, resolvedor e informe de piel),
  `godot/core/lab/attack.gd` (ángulo de ataque) y `godot/core/lab/fang_enamel.gd` (esmalte).
- Tests: `godot/tests/lab/test_zones.gd`, `test_penetration.gd`, `test_attack.gd`, `test_fang_enamel.gd` y
  `test_pulido_biologia.gd` (los casos de referencia).
- Casos de referencia de la integración: `godot/tests/fixtures/spec/pulido-biologia.json`.

> **Integrado en la 2.0 (unidad 4b).** `Physics.compute()` usa estos módulos con `model = "2.0"` (la 1.x no cambia, al
> bit): la zona del cuerpo (`p.zone`), la punción por capas con el roce y el hueso, el ángulo de ataque
> (`p.attack_deg`, uno por ensayo: flexa la uña y decide el modo de abrasión) y el esmalte de los colmillos. Los 47
> casos de referencia se cumplen con el `compute()` de la aplicación (`test_biologia_v2.gd`, que prueba además el
> contrato de los campos y las invariantes); cinco se recalcularon con la 2.0 entera y guardan lo de la 1g en
> `expect1g`. En la interfaz: el selector de zona (tarjeta del material), el deslizador del ángulo de ataque, las filas
> nuevas del resultado y la tabla de la piel de cada zona; en la demo, los casos 16-22. Las decisiones de la
> integración y lo que difiere de esta guía, en §9.10.

> **Educativo.** Como el resto del banco, el modelo busca tendencias y órdenes de magnitud con datos publicados. Los
> espesores salen de ecografías, biopsias y tomografías de adultos sanos; donde no hay medición de la zona se dice y se
> marca como estimación. Las propiedades mecánicas de los tejidos (tenacidades, módulos) son las de la 1.x
> (FISICA.md §7), las mismas en todas las zonas.

## 1. Resumen

| Zona | Capa córnea | Epidermis viva | Dermis | Grasa | Fascia | Músculo | Debajo |
|---|---|---|---|---|---|---|---|
| **Brazo** (cara posterior; la de la 1.x) | 18 µm | 57 µm | 2,1 mm | 10,8 mm | 0,3 mm | 28,1 mm | húmero a **41,4 mm** (cortical 4,4 mm, 47,25 HV) |
| **Palma** (eminencia tenar) | **173 µm** | 92 µm | 0,8 mm | 2,5 mm (est.) | 0,3 mm (est.) | 13,9 mm | 1.er metacarpiano a **17,8 mm** (43 HV) |
| **Dorso de la mano** | 29 µm | 57 µm | 0,9 mm (est.) | 4,3 mm | 0,3 mm (est.) | — | 3.er metacarpiano a **5,6 mm** (43 HV) |
| **Cara** (pómulo) | 17 µm | 57 µm | 1,0 mm | 5,8 mm (est.) | 0,3 mm (SMAS, est.) | 1,6 mm | cigomático a **8,7 mm** (40 HV) |
| **Abdomen** (junto al ombligo) | 18 µm | 57 µm | 2,1 mm | 13,9 mm | 0,3 mm (est.) | 10,3 mm | **cavidad abdominal** a 26,7 mm |

El mismo ensayo en cada zona (modelo 2.0; «sangra» cuando la herida pasa la epidermis):

| Ensayo | Brazo | Palma | Dorso de la mano | Cara | Abdomen |
|---|---|---|---|---|---|
| Mimo de gato (3 N, rayado) | 138 µm, dermis, sangra | 138 µm, **en el callo, no sangra** | 138 µm, sangra | 138 µm, sangra | 138 µm, sangra |
| Uña almendra 30 N ×20 | 75 µm, sangra | 131 µm, **callo pulido, no sangra** | 86 µm, sangra | 74 µm, sangra | 75 µm, sangra |
| Tigre 260 N (rayado) | 40 mm (toda la garra) | 17,8 mm, **topa con el hueso** | 5,6 mm, topa con el hueso | 8,7 mm, topa con el hueso | 40 mm, **cavidad abdominal** |
| Víbora 4 N (punción) | 18 mm (entera), músculo | marca el hueso a 17,8 mm | marca el hueso a 5,65 mm | marca el hueso a 8,7 mm | 18 mm, músculo |
| Víbora (golpe) | 18 mm, músculo | **se rompe** en el hueso | **se rompe** en el hueso | **se rompe** en el hueso | 18 mm, músculo |
| Gabón (golpe) | **se rompe** en el húmero (41,4 mm) | se rompe | se rompe | se rompe | 50 mm, cavidad abdominal |
| Casuario (golpe) | se para en el húmero (41,4 mm) | 17,8 mm (hueso) | 5,6 mm (hueso) | 8,7 mm (hueso) | 110 mm, herida penetrante |

Lo nuevo, en una línea por tema:

1. **Zonas:** cinco pilas de capas con el esquema de `SKIN_LAYERS`, espesores con fuente y calidad, y el hueso o la
   cavidad debajo (§2).
2. **Hueso y roce:** la grieta se abre en todas las capas que atraviesa la herramienta, los flancos rozan (Shergold &
   Fleck 2005; Fregonese & Bacca 2022) y la punta que llega al hueso tiene que indentar su cortical (§3).
3. **Ángulo de ataque:** inclinar la herramienta gira la cara que avanza y cambia el modo de abrasión (arado, cuña o
   corte) sin cambiar la profundidad del surco (§5).
4. **Esmalte:** la punta de los colmillos es un casquete de esmalte (321 HV) sobre dentina (50 HV): raya lo que la
   dentina sola no raya, hasta que el contacto crece (§6).

## 2. Zonas del cuerpo

### 2.1 Esquema

`Zones.stack(id)` devuelve la pila de capas blandas de la zona con **el mismo esquema que `Data.SKIN_LAYERS`**
(`id, name, short, from, to, jT, jC, E, col, note`, profundidades acumuladas en µm), más `source` y `quality` del
**espesor**. Las funciones de piel de `physics.gd` (`skin_layer_at`, `skin_tear_depth`) y de los aguijones
(`Sting.puncture_force`, `Sting.skin_sting`) la aceptan tal cual (hay test). Las propiedades de cada tejido (`jT`, `jC`,
`E`, color, nota) son las de la 1.x; una zona solo cambia los espesores y, si hace falta, la nota.

- `Zones.bone(id)`: el hueso de debajo (`fromUm`, `toUm`, `corticalUm`, `hv`, `E`, tenacidades, fuente y calidad) o
  `null` en el abdomen.
- `Zones.MARROW`: la médula que hay pasada la cortical (se le dan la tenacidad y el módulo de la grasa).
- Tejido nuevo `cavidad` (abdomen): peritoneo y vísceras, con las tenacidades del músculo (estimación: sin medición;
  así la punta nunca «acelera» al entrar). Es la última capa y no acaba.
- La zona por defecto es el **brazo**: sus capas son exactamente las de `SKIN_LAYERS` salvo que el músculo acaba en el
  húmero (41,4 mm) en vez de en los 60 mm simbólicos de la 1.x, que las funciones de piel ya trataban como «no acaba».
- Una zona desconocida o `null` resuelve al brazo.

### 2.2 Espesores por zona

Calidad: **P** primaria (medición en la zona), **S** secundaria (derivada, de otra zona equivalente o de una revisión),
**E** estimación.

| Zona · capa | Espesor | Cal. | Fuente y razonamiento |
|---|---|---|---|
| Brazo · capa córnea | 18 µm | P | Sandby-Møller 2003: 18,3 ± 4,9 µm (biopsias del dorso del antebrazo, 71 adultos) |
| Brazo · epidermis viva | 57 µm | P | Sandby-Møller 2003: 56,6 ± 11,5 µm |
| Brazo · dermis | 2125 µm | P | Gibney 2010: piel del brazo 2,2 mm (ecografía, 388 adultos) |
| Brazo · grasa | 10,8 mm | P | Gibney 2010 |
| Brazo · fascia | 300 µm | S | Stecco 2009: fascia pectoral de 297 µm (la referencia de la 1.x) |
| Brazo · músculo | 28,1 mm | S | Homer 2025: cara posterior del brazo, de la grasa al húmero 2,84 ± 0,87 cm (18 adultos jóvenes); incluye la fascia |
| Palma · capa córnea | 173 µm | P | Egawa 2007: eminencia tenar 173,0 ± 37,0 µm (Raman) |
| Palma · epidermis viva | 92 µm | S | Baumann 2024: epidermis entera de la eminencia tenar 265,1 ± 50,9 µm (OCT, 33 adultos) menos la capa córnea de Egawa |
| Palma · dermis | 800 µm | S | Lee & Hwang 2002: en la palma la epidermis es el 40,6-44,6 % de la piel (601-637 µm) → dermis ~0,8 mm |
| Palma · grasa | 2,5 mm | E | sin medición localizada; del orden de la grasa del dorso (Hung 2022) |
| Palma · fascia | 300 µm | E | fascia tenar, como la de referencia (Stecco 2009) |
| Palma · músculo | 13,89 mm | P | Çetiner Şeker 2026: de la superficie del abductor corto del pulgar a la cortical del 1.er metacarpiano, 13,89 ± 1,60 mm (162 muñecas control) |
| Dorso de la mano · capa córnea | 29 µm | P | Egawa 2007: 29,3 ± 6,8 µm |
| Dorso de la mano · epidermis viva | 57 µm | S | Robertson & Rees 2010: la epidermis apenas cambia entre zonas (55,6-62,5 µm); se toma la del brazo |
| Dorso de la mano · dermis | 914 µm | E | piel de ~1 mm, como la del antebrazo por ecografía (Wang 2022) |
| Dorso de la mano · grasa | 4,34 mm | S | Hung 2022: las tres láminas grasas del dorso a los 20 años (0,70 + 2,16 + 1,48 mm, reconstruidas con la pérdida medida hasta los 60) |
| Dorso de la mano · fascia | 300 µm | E | fascia dorsal profunda, como la de referencia; los tendones extensores van en la grasa |
| Cara · capa córnea | 17 µm | P | Egawa 2007: mejilla 16,8 ± 2,8 µm |
| Cara · epidermis viva | 57 µm | S | Robertson & Rees 2010; se toma la del brazo |
| Cara · dermis | 1000 µm | S | Meng 2022: dermis sobre el cigoma 1,14 mm (hombres) y 0,87 (mujeres) |
| Cara · grasa | 5,77 mm | E | lo que queda de los 8,7 mm hasta el hueso (De Greef 2006) tras la piel, el SMAS y el músculo |
| Cara · fascia (SMAS) | 300 µm | E | sistema musculoaponeurótico superficial, como la fascia de referencia |
| Cara · músculo | 1,56 mm | S | Lee & Kim 2025: orbicular de los ojos, 1,56 ± 0,45 mm alrededor de la órbita |
| Abdomen · capa córnea y epidermis | 18 + 57 µm | S | Robertson & Rees 2010: el abdomen (61,3 µm) como el brazo; se toman las del brazo |
| Abdomen · dermis | 2125 µm | P | Gibney 2010: piel del abdomen 2,2 mm |
| Abdomen · grasa | 13,9 mm | P | Gibney 2010 |
| Abdomen · fascia | 300 µm | E | vaina anterior del recto, como la fascia de referencia |
| Abdomen · músculo | 10,26 mm | P | Kim 2012: recto del abdomen a la altura del ombligo (TC, 545 mujeres) |
| Abdomen · cavidad | no acaba | E | la cavidad abdominal no acaba en el modelo |

### 2.3 Hueso

| Hueso (zona) | Empieza a | Cortical | Dureza | E | Cal. | Fuente |
|---|---|---|---|---|---|---|
| Húmero (brazo) | 41,4 mm | 4,4 mm | 47,25 HV | 17,4 GPa | P | Li 2021 (Vickers del húmero); Tingart 2003 (cortical de la diáfisis proximal 4,4 ± 1,0 mm); Reilly & Burstein 1975 (E) |
| 1.er metacarpiano (palma) | 17,8 mm | 2,5 mm | 43 HV | 17,4 GPa | S | Li 2021 midió los metacarpianos, pero su texto no da el valor: el del radio y el cúbito (42,5-43,3 HV); la medición publicada más cercana en la mano, las diáfisis de las falanges, da 38,52 ± 6,67 HV (Yin 2019; §9.10); cortical estimada con el índice cortical del 2.º metacarpiano (~62 %, Schneider & Gilmour 2025) y ~8 mm de anchura |
| 3.er metacarpiano (dorso) | 5,6 mm | 2,5 mm | 43 HV | 17,4 GPa | S | ídem |
| Cigomático (cara) | 8,7 mm | 1,5 mm | 40 HV | 17,4 GPa | S | De Greef 2006 (profundidad: 7,4 y 10,0 mm en hombres y mujeres de 18-29 años, media 8,7); Li 2021 (cráneo > 40 HV); Costa 2021 (cortical de 1-2 mm) |

Tenacidades del hueso cortical (Koester 2008, guardadas para la rotura, que no se modela: §8): la grieta arranca con
~1 MPa·m^½ (`kInit`), al abrirse a lo largo llega a J ≈ 1,2 kJ/m² (`jSplit`) y al romperse de través a J ≈ 31 kJ/m²
(`jBreak`).

Toda la queratina del banco (26-33 HV) es más blanda que cualquier cortical (40-47 HV): r = 0,55-0,83. Ninguna garra
natural marca el hueso (§3.3).

### 2.4 Los umbrales de la 1.x en cada zona

La abrasión sin romper la piel es una heurística calibrada en el brazo (FISICA.md §7): el **rasguño blanco** levanta la
capa córnea (18 µm), la **excoriación** arranca la epidermis (75 µm) y con **5 pasadas** llega a las papilas y sangra.
En cada zona se conservan las profundidades absolutas, acotadas por sus capas (`Zones.abrasion_limits`):

- `whiteUm = min(18, capa córnea)` · `excoriateUm = min(75, fin de la epidermis)`.
- Las pasadas ahondan con la ley de la 1.x (profundidad ∝ n^0,4, FISICA.md §5):
  `excoriación(n) = min(epi, max(excoriateUm, 75·(n/5)^0,4))` (`Zones.excoriation_depth_um`), y sangra cuando llega al
  final de la epidermis: `n ≥ bleedPasses = 5·(epi/75)^(1/0,4)`. En el brazo da siempre 75 µm y 5 pasadas (la 1.x).

| Zona | Rasguño blanco | 1.ª excoriación | Fin de la epidermis | Pasadas para sangrar |
|---|---|---|---|---|
| Brazo | 18 µm | 75 µm | 75 µm | 5 |
| Palma | 18 µm (en el callo) | 75 µm (en el callo) | 265 µm | **117** |
| Dorso de la mano | 18 µm | 75 µm | 86 µm | 7,0 |
| Cara | 17 µm | 74 µm | 74 µm | 4,8 |
| Abdomen | 18 µm | 75 µm | 75 µm | 5 |

La **severidad** (0-1) usa los hitos de la 1.x (`SKIN_SEV`) movidos a las fronteras de cada zona: fin de la epidermis
0,3 · dermis papilar (+300 µm) 0,45 · fin de la dermis 0,62 · de la grasa 0,8 · de la fascia 0,86 · y 0,97 en el
hueso, la cavidad o a 40 mm, lo que llegue antes (`Zones.severity_anchors`, `Zones.severity`: en el brazo, bit a bit
la de la 1.x). La misma herida es más grave donde el hueso está cerca: 5 mm son 0,70 en el brazo, 0,79 en el dorso de
la mano y 0,88 en la palma.

### 2.5 Lo que no cambia con la zona

- **Romper la superficie:** `Sting.puncture_force(área, pila)` (unidad 1a) usa la tenacidad de la capa de arriba, que
  es la misma en todas las zonas: la fuerza para perforar no cambia. Davis et al. (2004) la midieron en el dorso de la
  mano (junto a la base de un nudillo); una palma con 173 µm de callo probablemente pida más, pero no hay medición.
- **Esfuerzo y fuerza de desgarro** (`stress`, `tearForce`, `ruptures`): dependen de la herramienta y del contacto, no
  de los espesores.

## 3. Penetración profunda (punción)

### 3.1 La grieta en todas las capas

En la 1.x la punta avanza abriendo una grieta plana en modo I (Shergold & Fleck 2005) con la tenacidad de la capa en la
que está la punta: `F = 2·jC·a(h)`. Al salir de la dermis la resistencia cae de golpe, aunque el cono siga dentro de
ella ensanchando la grieta. En la 2.0 la energía de la grieta es la integral en profundidad de `2·J(z)·ρ(h − z)` y su
derivada es la fuerza:

```
F_grieta(h) = 2·Σ_i J_i·[ρ(h − z_i,arriba) − ρ(h − z_i,abajo)]
```

con `ρ(s)` el radio de la herramienta a una distancia `s` por detrás del ápice (esfera, cono y, si tiene base, cilindro:
`Contact.hole_radius`) y `J_i` la `jC` de cada capa. Con una sola capa y una punta sin base es exactamente la 1.x
(`2·J·a(h)`, hay test); es continua entre capas; y nunca pasa de `2·J_max·ρ_max`, porque la grieta no puede ser más
ancha que la herramienta.

### 3.2 Roce en los flancos

Shergold & Fleck (2005) observan en la piel que, pasada la perforación, la carga sigue subiendo con la profundidad por
el roce de los flancos. La grieta acuñada aprieta la herramienta con la presión media que calculan Fregonese & Bacca
(2022) para un sólido hiperelástico de Ogden; con α = 9, el de la piel humana (Shergold, Fleck & Radford 2006):

```
⟨p⟩ = μ·[0,8613 + 1,434·(J/(μ·ρ))^0,844]        μ = E/3 (incompresible)
τ = ξ·⟨p⟩                                        (Coulomb)
F_roce(h) = ∫₀ʰ ξ·⟨p⟩(z)·2π·ρ(h − z) dz
```

Por capas queda `dF/ds = k1·ρ + k2·ρ^q` con `q = 1 − 0,844`, así que basta tabular `∫ρ` y `∫ρ^q` una vez por ensayo
(`make_profile`: tramos exactos de esfera, cono y base, rejilla geométrica de 360 puntos). Las capas sin módulo medido
(capa córnea, epidermis, fascia) usan el de la dermis (estimación).

- **ξ = 0,05** es el dato más incierto: Fregonese & Bacca ajustan 0,02-0,06 en sólidos blandos; no hay medida en piel.
  Sensibilidad (brazo, empujando):

| ξ | Víbora 4 N | Víbora 3 N | Gato 3,2 N |
|---|---|---|---|
| 0,02 | 18 mm (entera) | 18 mm | 10 mm (entera) |
| **0,05** | **18 mm (entera)** | 2,0 mm (dermis) | 3,4 mm (grasa) |
| 0,1 | 2,1 mm (dermis) | 1,6 mm | 1,9 mm (dermis) |

  Con 0,1 un colmillo de víbora empujado con 4 N no pasaría de la dermis, lo que contradice el veneno intramuscular de
  la 1.x (y la mordedura real); con 0,08 todavía llega entero. 0,05 queda dentro de la horquilla medida y con margen.

### 3.3 Hueso

La punta que llega a la cortical tiene que indentarla, como un sólido (FISICA.md §4-5):

```
F_hueso(δ) = (H/η)·π·[ρ(δ)² − ρ(δ − t)²]          η = Contact.hardness_efficiency(HV_punta/HV_hueso)
```

con `δ` lo que ha entrado en el hueso y `t` la cortical (pasada la cortical, el anillo de hueso ya no crece: la punta
está en la médula, que resiste como la grasa, estimación).

- **Umbral:** por debajo de `r = 1,25` el hueso es una **pared** (`MODEL.boneMinRatio`): el mismo umbral de la «marca
  tenue» de la 1.x (Richardson 1968: la superficie resiste a un abrasivo que no la supera en un 25 %). Con eso ninguna
  queratina (r ≤ 0,83) entra en el hueso, ni con la patada de un casuario. Sin el umbral, la arpía (33 HV) contra el
  pómulo (40 HV; r = 0,825, η = 0,0013) entraba 1,1 mm con 151 kN de resistencia: una rareza numérica, no física.
- La **dentina** de los colmillos (50 HV) no llega a 1,25 veces el húmero (47,25) ni los metacarpianos (43): solo el
  esmalte de la punta los marca, unas micras, hasta que el contacto sale del esmalte (§6). Contra el cigomático (40 HV)
  la dentina sí marca (r = 1,25).
- **Rotura del colmillo** (`fBreak` = 30 N, Estrada 2026): la carga en la punta es el empuje o, en un golpe, el pico de
  resistencia del camino (contra una pared, infinito): el colmillo se rompe al llegar al hueso y la profundidad se queda
  donde la resistencia alcanzó 30 N.
- Contra una pared, lo que empuja el hueso (`boneN`) es el resto del empuje; en un golpe depende de cómo frene la pata,
  que no se modela, y queda en `null`.

### 3.4 El resolvedor

La resistencia total es `F_grieta + F_roce + F_hueso`. Puede **bajar** al pasar a una capa más blanda, así que se
recorre en orden (rejilla geométrica desde 0,1 µm con las fronteras de capa y del hueso) y la punta se para en la
primera profundidad en que:

- **empujando:** la resistencia alcanza la fuerza (`Neff`, con la adhesión);
- **golpeando:** el trabajo de penetración `∫F_res dh` (trapecios) iguala la energía `½·m·v²` más el trabajo del empuje
  `F·h`, como `Contact.solve_energy`;
- o al llegar a una pared, al alcance de la herramienta (`reach`) o a la fuerza de rotura.

El último tramo se afina por bisección (60 pasos). `Penetration.puncture` devuelve el porqué (`stoppedBy`: «sin
perforar», «fuerza», «energia», «alcance», «hueso» o «rotura»), las tres fuerzas en el punto final, el trabajo y la
energía que sobra.

### 3.5 Resultados en el brazo: 1.x frente a 2.0

| Ensayo | 1.x | 2.0 | Grieta · roce en el punto final |
|---|---|---|---|
| Víbora 4 N | 18 mm (entera), músculo | 18 mm (entera), músculo | 0,12 N · 1,86 N |
| Gato 3,2 N | 10 mm (entera), grasa | **3,4 mm**, grasa: la frenan la grieta de la dermis y el roce | 2,16 N · 1,04 N |
| Gato 15 N · stiletto 30 N · águila 110 N | enteras | enteras | — |
| Gabón, golpe | 50 mm, músculo | **41,4 mm**: el colmillo se rompe contra el húmero | 0,33 N · 3,21 N |
| Casuario, golpe | 110 mm, músculo | **41,4 mm**: se para en el húmero y sobran ~180 J | 5,30 N · 4,47 N |
| Casuario con daga de tungsteno, golpe | 110 mm | 65 mm: atraviesa la cortical y acaba en la médula | — |

## 4. Rayado por zonas

`Penetration.tear(Ft, zona, alcance)`: el corte de la 1.x (`Physics.skin_tear_depth` con las capas de la zona:
`F_t = ∫₀ʰ jT dz`) acotado por el hueso (una garra no rasga hueso) y por el alcance. La abrasión sin romper, con los
umbrales de §2.4. `Penetration.skin_report` junta las dos cosas con lo que la 1.x ya calcula (esfuerzo, fuerza de
desgarro, si rompe) y es la referencia de la integración (§9).

- Con las mismas fuerzas, **el corte mide lo mismo en µm en todas las zonas** mientras no pase la dermis más fina:
  cambia la capa en la que acaba. El mimo del gato (138 µm) sangra en el brazo y se queda en el callo de la palma.
- Donde la dermis es fina (palma 0,8 mm, dorso 0,9, cara 1,0) un desgarro fuerte llega antes a la grasa: el gato que
  desgarra con 15 N abre 1,8 mm en el brazo y 4-6 mm en la mano o la cara (ver §8: en la palma se sobrestima).
- En el brazo, el oso que desgarra con 300 N se para en el húmero (41,4 mm); la 1.x lo dejaba en sus 60 mm de garra.

## 5. Ángulo de ataque

En la 1.x la punta esfero-cónica se presenta con el eje perpendicular a la superficie y el modo de abrasión sale del
grado de penetración `Dp = h/a` (Hokkirigawa & Kato 1988). `h/a` es la pendiente media del frente del contacto: en la
parte cónica, la de la cara que avanza, cuyo ángulo con la superficie (θ = 90° − α) es el «ángulo de ataque» de la
literatura de abrasión (Challen & Oxley 1979; Sedriks & Mulhearn 1963): cuanto más empinada la cara, antes pasa el surco
del arado al corte.

El parámetro `attack_deg` es el ángulo que forma el **eje** de la herramienta con la superficie, medido hacia donde
avanza: 90° de punta (la 1.x), menos de 90° tumbada y arrastrando, más de 90° «de gancho», clavando. Inclinarla gira la
cara que avanza:

```
θ = ataque − α                         (acotado a [1°, 90°])
Dp_ef = profundidad / [a_t + (h_g − h_t)·cot θ]      si h_g > h_t (contacto en el cono)
```

con `h_g = profundidad/m` la profundidad geométrica (m, el multiplicador de la 1.x: φ·tipo·pasadas), `h_t` y `a_t` la
tangencia esfera-cono. Con θ = 90° − α es exactamente el `Dp` de la 1.x. Un contacto que se queda en el casquete
esférico no cambia al inclinar la herramienta (la esfera es igual en todas las direcciones). Con `Dp_ef` salen el modo,
la fracción arrancada (`fab`) y la fricción de arado (`Abrasion.abrasion_mode`, sin copiar sus umbrales); el índice de
desgaste escala con `fab`. **La profundidad del surco no cambia.**

| Ensayo | Ataque | Cara θ | Dp_ef | Modo | Arranca (fab) | μ arado |
|---|---|---|---|---|---|---|
| Gato 15 N sobre ABS | 90° (1.x) | 76° | 2,94 | corte | 1 | 1,2 |
| | 45° | 31° | 0,61 | corte | 1 | 0,55 |
| | 20° | 6° | 0,114 | **cuña** | 0,21 | 0,10 |
| Stiletto 30 N sobre pino | 90° | 68° | 2,06 | corte | 1 | 1,2 |
| | 45° | 23° | 0,44 | corte | 1 | 0,39 |
| | 20° | 1° | 0,019 | **arado** | 0,03 | 0,02 |
| Uña cuadrada 30 N sobre pino | 90° | 15° | 0,20 | corte | 0,60 | 0,18 |
| | 150° (gancho) | 75° | 0,38 | corte | **0,95** | 0,34 |
| Diamante 30 N sobre acero | 90° | 40° | 0,49 | corte | 1 | 0,44 |
| | 20° | 1° | 0,036 | **arado** | 0,05 | 0,03 |
| Uña almendra 4 N sobre barniz | cualquiera | — | 0,054 | arado (casquete esférico) | 0,08 | 0,05 |

Para dibujar el frente: `Attack.mean_front_angle_deg(Dp) = atan(Dp)` (los umbrales 0,1 y 0,2 son 5,7° y 11,3°) y,
para un indentador esférico, `Attack.sphere_edge_angle_deg(Dp) = 2·atan(Dp)` (11,4° y 22,6°, los de Hokkirigawa y Kato).

## 6. Esmalte en la punta de los colmillos

Estrada et al. (2026) describen en los colmillos de tres víboras neotropicales **esmalte aprismático concentrado en la
punta** sobre un cuerpo de dentina de 0,4-0,6 GPa, con una composición «comparable a la de los dientes de cocodrilo».
No dan la dureza del esmalte. Se toma la del esmalte de cocodrilo medida con el mismo tipo de ensayo, **3,15 GPa =
321,2 HV** (Enax et al. 2013; su dentina, 0,60 GPa, es la misma que la de las víboras): calidad secundaria. El espesor en
la punta no está medido en víboras; las serpientes de presas blandas tienen un esmalte fino y solo en la punta (Dumont
et al. 2023): **10 µm**, estimación.

Modelo (la misma forma que la laca sobre la madera de la 1.x, FISICA.md §6):

```
H_punta(a) = H_dentina + (H_esmalte − H_dentina)·exp(−a/t_esmalte)
```

con `a` el radio del contacto: el esmalte manda en un contacto pequeño y la dentina en uno grande. El módulo `E` de la
punta sigue siendo el de la dentina. Un colmillo reforjado (con incrustación) es entero de su material, sin esmalte.

- **Contra el hueso** (§3.3): la dureza de la punta con el contacto de cada profundidad.
- **Contra un sólido:** la eficiencia de la punta `η(a) = Contact.hardness_efficiency(H_punta(a)/H)` en cada contacto
  (`FangEnamel.efficiency`). La resistencia sigue siendo monótona y se hace infinita cuando el contacto sale del
  esmalte (r = 0,8): la profundidad se queda donde el esmalte puede. `FangEnamel.contact_radius_for_ratio` da ese radio
  (25 µm contra el cobre, 9 µm contra el acero).

| Ensayo | 1.x (dentina) | 2.0 (esmalte en la punta) |
|---|---|---|
| Víbora 4 N raya cobre (90 HV) | NO RAYA (r = 0,56) | **MARCA TENUE** de 3,3 µm (la punta, a 94,6 HV en el contacto final: r = 1,05) |
| Víbora 4 N raya acero (200 HV) | NO RAYA (r = 0,25) | MARCA TENUE de 0,46 µm (r = 0,94) |
| Gabón 20 N punza cobre | NO PERFORA | PERFORA: pozo de 3,3 µm (r = 0,97) |
| Víbora 4 N sobre vidrio (550 HV) o pantalla (650 HV) | NO RAYA | NO RAYA (r = 0,58 y 0,49: el vidrio es más duro que el esmalte) |
| Víbora 4 N sobre ABS (16 HV) | RAYA 295 µm | igual (la dentina ya basta, r = 3,1) |
| Víbora 40 N punza vidrio | SE ROMPE LA PUNTA; presión 490 MPa | igual, pero la presión del contacto es la del esmalte: **3150 MPa** |

## 7. Estimaciones del modelo

| Magnitud | Valor | Razonamiento |
|---|---|---|
| Roce herramienta-tejido | ξ = 0,05 | centro alto de lo ajustado en sólidos blandos (0,02-0,06, Fregonese & Bacca 2022); sin medida en piel (§3.2): los ensayos de agujas en tejido dan fuerzas o tensiones de roce, no un coeficiente de Coulomb (buscado en la 4b) |
| Módulo de capa córnea, epidermis y fascia | 210 kPa | el de la dermis (FISICA.md §7): no tienen `E` en la 1.x |
| Umbral para entrar en el hueso | r ≥ 1,25 | el de la «marca tenue» de la 1.x (Richardson 1968) |
| Médula ósea | jC 0,41 kJ/m², E 1,9 kPa | médula amarilla ≈ grasa |
| Cavidad abdominal | las del músculo (jC 0,084 kJ/m², E 53 kPa); no acaba | sin medición de peritoneo ni vísceras |
| Cortical de los metacarpianos | 2,5 mm | índice cortical ~62 % (Schneider & Gilmour 2025) con ~8 mm de anchura |
| Dureza de los metacarpianos | 43 HV | la del radio y el cúbito (Li 2021); las falanges de la mano dan 38,52 ± 6,67 HV (Yin 2019), y con ellas la dentina marcaría el hueso de la mano (§9.10) |
| Dureza del cigomático | 40 HV | cráneo > 40 HV (Li 2021): el valor más bajo, el más favorable a la punta |
| Grasa de la palma | 2,5 mm | sin medición localizada |
| Dermis del dorso de la mano | 914 µm | piel de ~1 mm (Wang 2022, antebrazo) |
| Grasa malar | 5,77 mm | resto de los 8,7 mm de De Greef 2006 |
| Fascias (palma, dorso, SMAS, vaina del recto) | 300 µm | la fascia de referencia de la 1.x (Stecco 2009) |
| Excoriación con pasadas | 75·(n/5)^0,4 hasta el fin de la epidermis | la ley de pasadas de la 1.x (n^0,4) anclada en su calibración (75 µm en 5 pasadas) |
| Esmalte de la punta | 321,2 HV, 10 µm | dureza del esmalte de cocodrilo (Enax 2013); espesor sin medir (Dumont 2023) |
| Cara de la herramienta al inclinarla | θ = ataque − α, acotada a [1°, 90°] | geometría de la punta esfero-cónica; la dependencia de la fricción de la intercara (Challen & Oxley) no se modela |

## 8. Qué no predice

- **La rotura del hueso.** El hueso se indenta (dureza) pero no se fractura; las tenacidades de Koester 2008 quedan
  guardadas para cuando se modele. Tampoco se modela la cortical del otro lado.
- **La fuerza de perforación por zona:** se midió en el dorso de la mano (Davis 2004); el callo de la palma no la cambia
  en el modelo.
- **El tejido fibroso de la palma:** los tabiques y la aponeurosis palmar sujetan la piel y resisten más que la grasa y
  la fascia genéricas: el desgarro por debajo de la dermis de la palma se sobrestima (el gato que desgarra con 15 N
  llegaría a 5,8 mm).
- **Tendones, vasos y nervios** (los extensores del dorso de la mano, la arteria temporal…): van dentro de la grasa o la
  fascia, sin propiedades propias.
- **La cavidad abdominal:** no acaba, sin vísceras ni pared posterior.
- **La viscoelasticidad y la velocidad:** la piel es más rígida a alta velocidad (Shergold 2006); el golpe usa las
  mismas tenacidades que el empuje.
- **El ángulo de ataque** cambia el modo de abrasión, no la profundidad del surco (que se sigue calculando con la punta
  de frente), ni la fricción de adhesión, ni la piel (el modelo de piel no usa `Dp`).
- **El esmalte en golpes contra sólidos:** la referencia de los casos cubre empujes y rayados; la integración usa la
  misma resistencia en los golpes, pero no hay caso que lo fije.
- **La variabilidad entre personas:** edad, sexo, índice de masa corporal (la grasa del abdomen o del brazo cambia
  varias veces entre personas: Gibney 2010).

## 9. Guía de integración (oleada 2)

### 9.1 Parámetros nuevos

| Parámetro | Tipo | Unidad | Rango | Por defecto | Efecto |
|---|---|---|---|---|---|
| `zone` | String | — | `Zones.ids()`: `brazo`, `palma`, `dorsomano`, `cara`, `abdomen` | `"brazo"` | pila de capas y hueso de la piel; solo con `target.skin` |
| `attack_deg` | float | grados | 10-170 (`Attack.MIN_DEG`-`MAX_DEG`) | 90 (`Attack.DEFAULT_DEG`) | modo de abrasión al rayar un sólido |

Con los dos por defecto (o ausentes) el resultado es el de la 1.x salvo el hueso del brazo y el esmalte (§9.4).
Selector de zona: `Zones.ids()` y, para cada una, `name`, `short`, `site` (dónde exactamente) y `fact` (ficha).

### 9.2 compute() en el modelo 2.0

**Piel** (`target.skin`):

1. `var zone := Zones.resolve(p.get("zone")).id` y `var stack := Zones.stack(zone)` en lugar de `target.tissue` o
   `SKIN_LAYERS`; `fPuncture = Sting.puncture_force(tool.area, stack)` (unidad 1a).
2. Lo de siempre: `Neff`, el esfuerzo `stress`, la fuerza de desgarro `Ft`, `ruptures`, `energyJ`. La presión en la
   piel sigue siendo `min(pNominal, Htool)` con la dureza de la herramienta: el esmalte solo cuenta contra lo duro (el
   hueso, dentro de `Penetration`, y los sólidos).
3. `var pen := Penetration.skin_report({ tool, tip, zone, puncture, strike, Neff, energyJ, passes: passN, stress,
   tearForce: Ft, ruptures })`.
4. De `pen`: `depthUm`, `layer`, `bleeds`, `fullReach`; al punzar también `pierces`, `toolBroken`, `workJ`.
5. Severidad: `Zones.severity(zone, depthUm)` donde la 1.x usa `_skin_severity(depthUm)` (al punzar,
   `max(0,3; …)` si perfora; 0,08 si no, como la 1.x). Lo más limpio: dar a `_skin_severity` los hitos como
   parámetro.
6. `_skin_where` y `_skin_wound`: la dermis papilar acaba en `pen.epiUm + 300` (no en 75 + 300) y hay ids nuevos:
   `hueso`, `medula` y `cavidad` (§9.5).
7. `result.pen = pen` (null en los sólidos).

**Sólidos:**

1. **Esmalte:** en `_make_resistance` (también la que usa `_make_sheet_resistance`), `Htool` →
   `FangEnamel.tip_hardness_mpa(tool, a)` con el mismo `a` del contacto, es decir
   `η = FangEnamel.efficiency(tool, a, Hmax(h))`. Para cualquier herramienta que no sea un colmillo natural da
   exactamente lo de la 1.x.
2. Con el contacto final `a = a_um/1000`: `tipHv = FangEnamel.tip_hv(tool, a)` y, con él, `ratio = tipHv/tHV`,
   `eta`, `toolWorn`, `pressure = min(pNominal, tipHv·HV_MPA, Hsurf)` y la dureza blanda del índice de desgaste.
3. **Ángulo de ataque:** con `m = φ·k_tipo·pasadas` (el de la 1.x), si hay surco
   `var ab := Attack.abrasion(Dp, depthUm, m, tip, tool.alpha, p.attack_deg)` y de ahí `absMode`, `fab`, `muPlough`
   (y `muEff`, `Ffric`, `wearIdx` como siempre). `Dp` sigue siendo el de la 1.x; `DpEff`, `faceDeg` y `attackDeg`
   son nuevos (`DpEff = Dp` sin surco o con el ángulo por defecto).

### 9.3 Campos nuevos y cambiados de compute()

| Campo | Dónde | Tipo · unidad | Qué es |
|---|---|---|---|
| `zone` | piel | String | zona usada (null en sólidos) |
| `pen` | piel | Dictionary o null | el informe de `Penetration.skin_report` (tabla siguiente) |
| `toolBroken` | piel (punción) | bool | el colmillo se rompe contra el hueso (en la 1.x no existía en la piel) |
| `workJ` | piel (punción) | float · J | trabajo de penetración (en la 1.x, null en la piel) |
| `layer` | piel | String | también «Húmero», «Primer metacarpiano», «Tercer metacarpiano», «Hueso cigomático», «Médula ósea», «Cavidad abdominal» |
| `tipHv` | sólidos | float · HV | dureza de la punta en el contacto final (la de la herramienta salvo en los colmillos) |
| `ratio`, `eta`, `toolWorn`, `pressure` | sólidos | — | con `tipHv` (cambian solo en los colmillos) |
| `DpEff`, `faceDeg`, `attackDeg` | sólidos | float · —, °, ° | grado de penetración con el ataque, ángulo de la cara que avanza, ataque |
| `absMode`, `fab`, `muPlough`, `muEff`, `Ffric`, `wearIdx` | sólidos | — | con `DpEff` (cambian solo con un ataque distinto de 90°) |

`result.pen` (todas las profundidades en µm, fuerzas en N, energías en J):

| Campo | Punción | Rayado | Qué es |
|---|---|---|---|
| `zone`, `zoneName`, `method` | ✓ | ✓ | zona, su nombre, «puncion» o «rayado» |
| `depthUm`, `layerId`, `layer` | ✓ | ✓ | profundidad, id y nombre de la capa (o del hueso) |
| `bleeds`, `fullReach`, `boneHit` | ✓ | ✓ | sangra; toda la herramienta dentro; ha llegado al hueso |
| `epiUm`, `deepUm`, `boneDepthUm` | ✓ | ✓ | fin de la epidermis; hito de severidad 0,97; profundidad del hueso (null sin hueso) |
| `pierces`, `fPuncture` | ✓ | | perfora; fuerza para perforar |
| `stoppedBy` | ✓ | | «sin perforar», «fuerza», «energia», «alcance», «hueso» o «rotura» |
| `boneIndentUm`, `bonePierced` | ✓ | | lo que entra en el hueso; atraviesa la cortical |
| `toolBroken`, `toolLoadN` | ✓ | | rotura; carga en la punta (null si un golpe choca con una pared) |
| `crackN`, `frictionN`, `boneN`, `resN` | ✓ | | grieta, roce, hueso (null si es una pared en un golpe) y total en el punto final |
| `workJ`, `energyLeftJ` | ✓ | | trabajo de penetración; energía del golpe que sobra (null empujando) |
| `ruptures`, `cutUm`, `abrasionUm` | | ✓ | rompe la piel; corte; abrasión sin romper |
| `excoriation`, `excoriationBleeds`, `bleedPasses` | | ✓ | hay excoriación; sangra por pasadas; pasadas para sangrar en la zona |

### 9.4 Escenarios del golden 1.x que cambian

Con los parámetros por defecto (brazo, 90°), de los 40 escenarios de `golden.json` cambian tres (campos del golden:
`verdict`, `depthUm`, `pressureMPa`, `layer`):

| Escenario | Campo | 1.x | 2.0 | Por qué |
|---|---|---|---|---|
| gabón 30N impacto sobre piel | `depthUm` | 50000 | 41410,2 | el húmero está a 41,4 mm (Homer 2025) y el colmillo se rompe contra él |
| | `layer` | Músculo | Húmero | |
| | `verdict` | PUNCIÓN · INYECTA | el de un colmillo roto (§9.5) | `toolBroken` (Estrada 2026) |
| casuario 500N impacto sobre piel | `depthUm` | 110000 | 41400 | la queratina no marca el hueso (r = 0,68 < 1,25) |
| víbora 40N punción sobre vidrio (rompe) | `pressureMPa` | 490,4 | 3150,0 | la presión la limita el esmalte de la punta (Enax 2013), no la dentina |

Otros efectos en el banco: el sonido del Gabón pasa de «inject» a «snap» (`toolBroken`) y el logro «🦷 Colmillo roto»
se gana ya en ese escenario. En «víbora 4N sobre puerta madera (punción)» solo cambia `ratio`, en la séptima cifra: el
contacto final mide 160 µm de radio, pura dentina, y la laca y la madera ya eran blandas para ella (η = 1). Todos los
rayados de piel del golden, la víbora que punza el brazo (18 mm) y el pájaro que no perfora quedan igual.

### 9.5 Veredictos y textos sugeridos

| Situación | Veredicto | Texto |
|---|---|---|
| Punción que topa con el hueso | PUNCIÓN HASTA EL HUESO | «la punta topa con el húmero a ~41.4 mm y no lo marca» |
| La punta marca el hueso | SE CLAVA EN EL HUESO | «entra ~15 µm en el hueso cigomático» |
| Atraviesa la cortical | ATRAVIESA EL HUESO | «atraviesa los 4.4 mm de cortical y acaba en la médula» |
| Colmillo roto contra el hueso | SE ROMPE EL COLMILLO | «llega al hueso a ~41.4 mm y el colmillo cede a ~30 N» |
| Abdomen, pasada la pared | HERIDA PENETRANTE | «pasa la pared del abdomen (~26.7 mm) y entra ~50 mm en la cavidad» |
| Rayado que topa con el hueso | LACERACIÓN HASTA EL HUESO / DESGARRO HASTA EL HUESO | «corta hasta el metacarpiano (~5.6 mm)» |
| Excoriación en el callo | CALLO PULIDO | «pule la capa córnea de la palma (~131 µm de 173): no sangra» |

`_skin_where` para los ids nuevos: `hueso` «clavada en el hueso», `medula` «en la médula del hueso», `cavidad` «en la
cavidad abdominal (herida penetrante)». Los números, con `Js.to_fixed` como el resto.

Frases con humor que no traicionan la física: «La palma trae callo de serie: diez veces la capa córnea del brazo.» ·
«El pómulo está a menos de un centímetro: la cara no tiene dónde esconder un colmillo.» · «El casuario topa con el
húmero; en la barriga no hay nada que lo pare.» · «El esmalte de la punta raya una moneda; la dentina de detrás, no.» ·
«Tumbar la uña convierte un corte en un arado.» · «En el dorso de la mano el hueso está a 5,6 mm: poca almohadilla
entre el nudillo y el mundo.»

### 9.6 Dibujo y animación

- **Corte de la piel por zona:** `Zones.section_layers(zona)` da las bandas (id, nombre, `from`/`to` en µm, color y
  `look`) con el hueso debajo; las capas nuevas llevan su aspecto en `Zones.SECTION_LOOK` (`tejido-hueso`,
  `tejido-medula`, `tejido-cavidad`) y su alto en `Zones.SECTION_BAND`, como `Looks.SKIN_BAND`. La médula solo se
  dibuja si la punta atraviesa la cortical. `skin_section_art` puede recorrer estas bandas en vez de `Looks.SKIN_LAYERS`.
- **Proporciones** (para una vista a escala): el hueso está a 41,4 mm en el brazo, 17,8 en la palma, 8,7 en la cara y
  5,6 en el dorso de la mano; la capa córnea de la palma es 10 veces la del brazo.
- **Animación de una punción:** la punta perfora al llegar a `fPuncture`; avanza con `crackN + frictionN`; si
  `boneHit`, se detiene con un golpe seco (o entra `boneIndentUm`); si `toolBroken`, la punta se parte en el hueso
  (sonido «snap»).
- **Ángulo de ataque:** dibujar la herramienta inclinada `attackDeg` y la cara que avanza a `faceDeg`; en arado, el
  material se aparta a los lados (rebordes); en cuña, se acumula delante; en corte, sale viruta (`fab`).
- **Esmalte:** la punta del colmillo con un casquete más claro de ~10 µm (a escala del radio de la punta, 50 µm en la
  víbora).

### 9.7 Sonido y logros sugeridos

- Sonidos: «snap» cuando `toolBroken` (ya existe); «pierce-solid» al marcar el hueso; «press» cuando una pared detiene
  la punta sin marcarla.
- Logros: «🦴 Hasta el hueso» (`pen.boneHit`), «🩸 Herida penetrante» (abdomen, `pen.layerId == "cavidad"`), «🧤 Callo
  de serie» (palma, excoriación sin sangre), «📐 De gancho» (un ataque > 90° que corta).

### 9.8 Casos de referencia

`godot/tests/fixtures/spec/pulido-biologia.json` es una lista de 47 casos `{ id, note, input, expect, source }`:

- `input`: los ids del oráculo (`geom`, `base`, `inlay`, `claw`, `target`, `type`) y `force` (N), `length`, `tear`,
  `method`, `strike`, `passes`, `wet`, `model: "2.0"`, y si hace falta `zone` y `attack_deg`.
- `expect`: `campo → { value | min | max, tol }`; el campo es una ruta con puntos dentro del resultado de `compute()`
  (`pen.stoppedBy`, `depthUm`…). `tol` es **relativa**; `value` sin `tol` exige igualdad exacta; `min` y `max` son
  inclusivos.
- Los grupos: la zona por defecto con el golden de piel (12), las zonas al rayar (11) y al punzar (10), el ángulo de
  ataque (8) y el esmalte (6).
- `test_pulido_biologia.gd` los comprueba contra la referencia: el motor 1.x con `Penetration.skin_report` en la piel y
  con `Attack.abrasion` y el esmalte en los sólidos (para el esmalte, el motor 1.x con la dureza de la punta en el
  contacto final: la misma profundidad que la resistencia 2.0, que es monótona). La integración tiene que cumplirlos
  con su `compute()`.

### 9.9 Dependencias con otras unidades

- **Aguijones (unidad 1a).** La perforación es `Sting.puncture_force` (no se duplica). `Sting.skin_sting` acepta las
  pilas de las zonas (`target.tissue = Zones.stack(zona)`): la fuerza para perforar no cambia, pero el veneno acaba en
  otra capa (el aguijón de la abeja, 1,32 mm, lo deja en la dermis del brazo y del abdomen, y en la grasa de la palma,
  del dorso de la mano y de la cara, donde la dermis es más fina).
- **Catálogo y estado del laboratorio:** el selector de zona y el deslizador de ataque viven en la interfaz y en
  `lab_state`; la física solo necesita `p.zone` y `p.attack_deg`.

### 9.10 Integración (unidad 4b): valores por defecto y decisiones

**Ángulo de ataque por defecto.** Lo decide un solo sitio, `Physics.attack_deg(p)`: `p.attack_deg` (acotado a
10-170°) o, si no lo trae, el de su tipo de herramienta (`Attack.DEFAULTS`, con su fuente y su calidad):

| Herramienta | Por defecto | Calidad | Por qué |
|---|---|---|---|
| Uñas | 45° | estimación | sin medición del ángulo de la uña al rayar; lo más parecido medido son las posturas del dedo sobre una pantalla táctil, de 15° (casi tumbado) a 90° (vertical) (Holz & Baudisch 2010), y 45° es la del medio. Es el que ya flexaba la uña en los materiales de la 4a |
| Garras, colmillos y aguijones | 90° | estimación | la punta de frente de la 1.x: no hay medición del ángulo con que una garra ataca la superficie al rayar (pregunta abierta) |

Diferencia con §9.1, que proponía 90° para todo: un ensayo tiene **un solo ángulo**, el que flexa la uña y el que
decide el modo de abrasión, así que las uñas también rayan a 45°. Con el surco en el casquete esférico nada cambia
(ninguno de los 40 escenarios del golden); si el surco llega al cono, la cara que avanza se tumba y el modo baja hacia
el arado, con menos fracción arrancada y menos fricción de arado. Con una garra en la piel el ángulo
no cambia nada (el modelo por capas no usa `Dp`): `DpEff` y `faceDeg` van a null en la piel; `attackDeg` es el del
ensayo (null con un aguijón, que solo pica). La interfaz enseña el deslizador donde cuenta: con una uña siempre y con
una garra o un colmillo al rayar un sólido.

**De gancho.** La flexión de la uña es la proyección de la reacción sobre la normal a la placa, N·(cos β + μ·sen β).
Pasados los 90° cambia de signo y la placa se dobla igual: `Bending.bend_factor` usa su valor absoluto (hasta 90°, al
bit lo de la 4a). Se anula a 90° + atan μ, donde la reacción va a lo largo de la placa (el pandeo no se modela).

**Invariante del ángulo.** Tumbar la herramienta nunca corta más con la misma carga (Dp_ef no sube al bajar el
ángulo). Con una uña, entre 90° y atan μ tumbarla la dobla **antes** (la reacción queda más perpendicular a la placa):
nunca aguanta más carga ni hunde más; por debajo de atan μ la flexión vuelve a bajar hacia N·cos β. Así que «un ángulo
más rasante nunca da más flexión» no es cierto en ese tramo: lo que se prueba es lo de arriba (`test_biologia_v2.gd`).

**Una uña que golpea la piel.** `Penetration.puncture` acepta `yieldN`, la carga con que cede la herramienta sin
romperse (la de la uña, `breakN` más la adhesión, que no pasa por ella): si no llega a la fuerza que rompe la piel, no
perfora ni de un golpe; si el camino le pide más, la punta se queda donde la resistencia llega a ella
(`stoppedBy` «cede»). El informe lleva además `yielded` y `demandN` (lo que pedía el camino, sin topes).

**Campos.** `toolBroken` y `workJ` solo en las punciones de la piel (§9.3); al rayar la piel, `toolBroken` aparece
solo cuando cede la uña (como en la 4a). El `pen` de `compute()` es exactamente `Penetration.skin_report` con los
datos del ensayo (hay test).

**Esmalte.** En la resistencia de los sólidos (también la de la chapa fina) y, con el contacto final, en `tipHv`,
`ratio`, `eta`, `toolWorn` y la presión (§9.2). En la piel la presión sigue siendo la de la 1.x (§9.2.2).

**Aguijones por zonas.** `sting_lab.gd` pica con la pila de la zona salvo si el objetivo trae una piel hecha a mano
(`target.tissue` distinto de la de la 1.x), que manda.

**Textos.** Los de §9.5 con dos precisiones: en el abdomen la profundidad se cuenta desde la superficie («pasa la
pared del abdomen (~26.7 mm) y llega a ~50.0 mm, dentro de la cavidad»), y en el dorso de la mano, donde la epidermis
(86 µm) es más gruesa que la excoriación de la 1.x (75 µm), «arranca la capa córnea y parte de la epidermis (~75 de 86
µm)».

**Casos recalculados con la 2.0 entera.** Cinco casos chocaban con los materiales de la 4a (la uña que cede con el
ataque de 45° y la recuperación elástica): `piel-brazo-stiletto-30N`, `ataque-20-stiletto-madera-30N`,
`ataque-150-cuadrada-madera-30N`, `ataque-20-diamante-acero-30N` y `ataque-45-almendra-coche-4N`. Su `expect` es el del
`compute()` integrado y lo de la 1g queda en `expect1g` (lo comprueba `test_pulido_biologia.gd` contra la referencia),
con la explicación en su nota.

**Golden.** De los 40 escenarios de la 1.x cambian, además de los 17 de los materiales, los cuatro de §9.4 («gabón 30N
impacto sobre piel» y «casuario 500N impacto sobre piel», de veredicto y profundidad; «víbora 40N punción sobre vidrio»
en la presión y «víbora 4N sobre puerta madera» en `ratio`) y dos que solo ganan los campos de la punción de §9.3
(`workJ` y `toolBroken`): «víbora 4N sobre piel (punción)» y «pájaro 1.5N punción sobre piel». En total, 23 de 40. El
golden 2.0 añade 13 escenarios de biología (`tools/golden_v2.gd`).

**Dureza de los metacarpianos.** Se quedan los 43 HV del radio y el cúbito. Li 2021 midió también los metacarpianos,
pero su texto no da el valor; la medición publicada más cercana en la mano son las diáfisis de las falanges,
38,52 ± 6,67 HV (Yin 2019). Con ella la dentina de la víbora (50 HV, r = 1,30) ya marcaría el hueso de la mano y el
colmillo entraría ~0,19 mm antes de romperse (hoy solo lo marca el esmalte, como en la cara con sus 40 HV justos):
queda como pregunta abierta hasta tener el dato del metacarpiano.

**Rendimiento.** La punción por capas es la parte cara: en la muestra de 3000 ensayos del oráculo, `compute()` 2.0 pasa
de ~1,69 ms a ~1,79 ms por ensayo (+6 %; la 1.x no cambia); las punciones de la piel, de ~1,3 a ~2,7 ms, y los rayados
de la piel, de ~0,22 a ~0,44 ms (medido en la misma máquina, con carga). Lo sostienen las tablas de las zonas calculadas
una vez, la búsqueda binaria y la recurrencia en la malla del perfil, el bucle caliente en línea y la memoria de
resistencias de cada ensayo.

**Pendiente para la unidad de dibujos y sonidos (§9.6 y §9.7).** Hecho en la unidad 4f (§9.11), salvo los logros de
§9.7.

### 9.11 Dibujos, animación y sonidos (unidad 4f)

**Corte de la piel por zonas** (`core/lab/art_zones.gd`). `Art.skin_section_art` lo usa con un resultado de la 2.0
(`res.pen`) de otra zona **o que llega al hueso** (también en el brazo: el corte de la 1.x no tiene húmero); con
cualquier otro, el de la 1.x byte a byte (`test_art`, 372/372). Recorre `Zones.section_layers(res.zone)` con la cortical
del hueso o la cavidad, y la médula solo si la punta atraviesa la cortical. El alto de cada banda blanda es el de
`Looks.SKIN_BAND` por (espesor en la zona / espesor en el brazo)^0,35 (así se ve el callo de la palma) y el hueso o la
cavidad ocupan lo que queda (cuanto menos tejido encima, más cerca y más grande): dibujo, no escala, con el espesor de
verdad en cada rótulo y «Hueso a 8,7 mm» en el del hueso. La herida acaba en la capa del resultado (hay test) y el hueso
enseña lo que le pasa: topa sin marcarlo, la muesca de lo que entra (exagerada: «entra 15 µm»), la cortical atravesada
o la punta del colmillo rota y clavada (su tamaño es dibujo).

**Herramienta inclinada** (`app/lab/bench_biology.gd`). La garra se gira desde la vertical (90°) hasta `attackDeg` al
rayar (al punzar baja de punta). La uña de perfil de la 1.x sale de la losa a 35° con el dedo **detrás** de la punta:
con el convenio de `attack.gd` es un ataque de 145°, de gancho; por debajo de 90° (su 45° por defecto incluido) se dibuja
dada la vuelta, con el dedo por delante arrastrándola, como en la física (la fricción suma a la flexión: §9.10). Al
empezar el ensayo pasa de la inclinación de la espera a la del resultado en 220 ms. En espera usa el ángulo por defecto
de la herramienta (`Physics.attack_deg`): la tarjeta del resultado podría pasarle al banco el del deslizador (`attack` en
`bench_state()`, y el banco ya lo acepta).

**Lupas del banco** (`core/lab/art_biology.gd`, a escala verdadera y con la barra de escala en el rótulo):
- *hueso* y *cavidad*: la punción en corte con las capas de la zona, el hueso a su profundidad con su cortical y la
  herida con la forma de la punta del modelo (`Contact.tip_geometry` con `area` y `alphaDeg`: mide `grooveWidthUm`). El
  banco la anima: la punta entra al tocar la piel, cruza las capas y topa con el hueso con el sonido del resultado (a
  0,78 × `RUN_MS`); si no lo marca, rebota con una onda (golpe seco); si entra, deja la muesca; si lo atraviesa, sigue
  por la cortical, que se agrieta, hasta la médula antes de que se levante la punta; si el colmillo se rompe, la punta se
  queda clavada y el resto da un respingo; al levantarla sale y queda la herida;
- *esmalte*: la punta del colmillo de dentina con el casquete de 10 µm, metida en el surco que abre, con `tipHv` en el
  rótulo (solo si el esmalte sube la dureza de la punta: con un contacto grande manda la dentina);
- *ataque*: con un ángulo distinto del de la herramienta, el surco de lado a lado con dos rebordes que tienen el área de
  lo que no se arranca, (1 − `fab`), y virutas si se arranca algo; el rótulo dice el modo y la cara (`faceDeg`);
- *callo*: el roce que se queda en la capa córnea de la palma, sin llegar a lo vivo;
- *laceración*: al rayar, el corte de una garra que llega al hueso, de lado a lado, con las capas de la zona.

**Sonidos** (`SfxInsects.bone_sfx`, con los efectos que ya estaban horneados): la punta que marca el hueso o lo atraviesa
suena a «pierce-solid»; la que el hueso detiene sin marcarla, a «press»; el colmillo que se rompe, a «snap» (el de
siempre). El golden 2.0 cambia a propósito en el sonido de tres escenarios: «casuario 500N impacto sobre piel» (pierce →
press), «Víbora punzando el pómulo» (inject → pierce-solid) y «Casuario de tungsteno… atraviesa el húmero» (pierce →
pierce-solid). Falta contarlo en «Cambios de la 2.0» de `docs/FISICA.md`.

**El corte del aguijón** (`ArtInsects.sting_section_art`) va también por zonas fuera del brazo (las bandas de
`ArtZones.bands` en su bloque): la abeja deja el veneno en la grasa de la palma, del dorso de la mano y de la cara, como
dice §9.9.

**Pendiente.** Los logros de §9.7 (`core/lab/lab.gd`).

## 10. Fuentes

- Baumann ME, Haddad NR, Salazar A et al. (2024). Testing the reliability of optical coherence tomography to measure epidermal thickness and distinguish volar and nonvolar skin. *JID Innov.* 4:100276. doi:10.1016/j.xjidi.2024.100276
- Çetiner Şeker A, Bayrak AO (2026). Diagnostic accuracy of ultrasonography compared with nerve conduction studies in carpal tunnel syndrome. *Front. Neurol.* 17. doi:10.3389/fneur.2026.1831290
- Challen JM, Oxley PLB (1979). An explanation of the different regimes of friction and wear using asperity deformation models. *Wear* 53:229-243. doi:10.1016/0043-1648(79)90080-2
- Costa JVD, Ramos AL, Iwaki Filho L (2021). Zygomatic-maxillary cortical bone thickness in hyper, normo and hypodivergent patients. *Dental Press J. Orthod.* 26:e211965. doi:10.1590/2177-6709.26.1.e211965.oar
- Davis SP, Landis BJ, Adams ZH, Allen MG, Prausnitz MR (2004). Insertion of microneedles into skin: measurement and prediction of insertion force and needle fracture force. *J. Biomech.* 37:1155-1163. doi:10.1016/j.jbiomech.2003.12.010
- De Greef S, Claes P, Vandermeulen D, Mollemans W, Suetens P, Willems G (2006). Large-scale in-vivo Caucasian facial soft tissue thickness database for craniofacial reconstruction. *Forensic Sci. Int.* 159S:S126-S146. doi:10.1016/j.forsciint.2006.02.034
- Dumont M, Milgram J, Herrel A et al. (2023). Show me your teeth and I will tell you what you eat: differences in tooth enamel in snakes with different diets. *Integr. Comp. Biol.* 63:265-275. doi:10.1093/icb/icad028
- Egawa M, Hirao T, Takahashi M (2007). In vivo estimation of stratum corneum thickness from water concentration profiles obtained with Raman spectroscopy. *Acta Derm. Venereol.* 87:4-8. doi:10.2340/00015555-0183
- Enax J, Fabritius HO, Rack A, Prymak O, Raabe D, Epple M (2013). Characterization of crocodile teeth: correlation of composition, microstructure, and hardness. *J. Struct. Biol.* 184:155-163. doi:10.1016/j.jsb.2013.09.018
- Estrada S, Arredondo JC, Pereañez J, Arola D, Ossa A (2026). Mechanical properties, microstructure, and strike biomechanics of tubular fangs in neotropical vipers. *Acta Biomater.* 222:388-398. doi:10.1016/j.actbio.2026.07.058
- Fregonese S, Bacca M (2022). How friction and adhesion affect the mechanics of deep penetration in soft solids. *Soft Matter* 18:6882-6887. doi:10.1039/d2sm00638c (texto en arXiv:2412.02013)
- Gibney MA, Arce CH, Byron KJ, Hirsch LJ (2010). Skin and subcutaneous adipose layer thickness in adults with diabetes at sites used for insulin injections: implications for needle length recommendations. *Curr. Med. Res. Opin.* 26:1519-1530. doi:10.1185/03007995.2010.481203
- Hokkirigawa K, Kato K (1988). An experimental and theoretical investigation of ploughing, cutting and wedge formation during abrasive wear. *Tribol. Int.* 21:51-57. doi:10.1016/0301-679X(88)90128-4
- Holz C, Baudisch P (2010). The generalized perceived input point model and how to double touch accuracy by extracting fingerprints. *Proc. CHI 2010* (posturas del dedo de 15° a 90° sobre una pantalla táctil). doi:10.1145/1753326.1753413
- Homer KA, Cross MR, Jukic I (2025). The concurrent validity of a portable ultrasound probe for muscle thickness measurements. *Clin. Physiol. Funct. Imaging* 45:e12901. doi:10.1111/cpf.12901
- Hung YT, Cheng CY, Chen CB, Huang YL (2022). Ultrasound analyses of the dorsal hands for volumetric rejuvenation. *Aesthet. Surg. J.* 42:1119-1126. doi:10.1093/asj/sjac035
- Kim J, Lim H, Lee SI, Kim YJ (2012). Thickness of rectus abdominis muscle and abdominal subcutaneous fat tissue in adult women: correlation with age, pregnancy, laparotomy, and body mass index. *Arch. Plast. Surg.* 39:528-533. doi:10.5999/aps.2012.39.5.528
- Kim JS (2023). Changes in sonographic thickness with identification of nine layers, roughness, and hydration in the dorsal hand after injectables. *Plast. Reconstr. Surg.* 152:1212-1225. doi:10.1097/PRS.0000000000010372
- Koester KJ, Ager JW, Ritchie RO (2008). The true toughness of human cortical bone measured with realistically short cracks. *Nat. Mater.* 7:672-677. doi:10.1038/nmat2221
- Lee KL, Kim HJ (2025). Topographic analysis of the periorbital region including orbicularis oculi muscle based on ultrasonography interpretation. *J. Cosmet. Dermatol.* 24:e70004. doi:10.1111/jocd.70004
- Lee Y, Hwang K (2002). Skin thickness of Korean adults. *Surg. Radiol. Anat.* 24:183-189. doi:10.1007/s00276-002-0034-5
- Li S, Wang JZ, Yin B et al. (2021). Atlas of human skeleton hardness obtained using the micro-indentation technique. *Orthop. Surg.* 13:1417-1422. doi:10.1111/os.12841
- Meng Y, Feng L, Shan J, Yuan Z, Jin L (2022). Application of high-frequency ultrasound to assess facial skin thickness in association with gender, age, and BMI in healthy adults. *BMC Med. Imaging* 22:113. doi:10.1186/s12880-022-00839-w
- Reilly DT, Burstein AH (1975). The elastic and ultimate properties of compact bone tissue. *J. Biomech.* 8:393-405. doi:10.1016/0021-9290(75)90075-5
- Richardson RCD (1968). The wear of metals by relatively soft abrasives. *Wear* 11:245-275. doi:10.1016/0043-1648(68)90175-0
- Robertson K, Rees JL (2010). Variation in epidermal morphology in human skin at different body sites as measured by reflectance confocal microscopy. *Acta Derm. Venereol.* 90:368-373. doi:10.2340/00015555-0875
- Sandby-Møller J, Poulsen T, Wulf HC (2003). Epidermal thickness at different body sites: relationship to age, gender, pigmentation, blood content, skin type and smoking habits. *Acta Derm. Venereol.* 83:410-413. doi:10.1080/00015550310015419
- Schneider MA, Gilmour RJ (2025). Continued metacarpal cortical bone growth in mid to late adolescence. *Am. J. Biol. Anthropol.* 188:e70186. doi:10.1002/ajpa.70186
- Sedriks AJ, Mulhearn TO (1963). Mechanics of cutting and rubbing in simulated abrasive processes. *Wear* 6:457-466. doi:10.1016/0043-1648(63)90281-3
- Shergold OA, Fleck NA (2005). Experimental investigation into the deep penetration of soft solids by sharp and blunt punches, with application to the piercing of skin. *J. Biomech. Eng.* 127:838-848. doi:10.1115/1.1992528
- Shergold OA, Fleck NA, Radford D (2006). The uniaxial stress versus strain response of pig skin and silicone rubber at low and high strain rates. *Int. J. Impact Eng.* 32:1384-1402. doi:10.1016/j.ijimpeng.2004.11.010
- Stecco A, Masiero S, Macchi V, Stecco C, Porzionato A, De Caro R (2009). The pectoral fascia: anatomical and histological study. *J. Bodyw. Mov. Ther.* 13:255-261. doi:10.1016/j.jbmt.2008.04.036
- Tingart MJ, Apreleva M, von Stechow D, Zurakowski D, Warner JJ (2003). The cortical thickness of the proximal humeral diaphysis predicts bone mineral density of the proximal humerus. *J. Bone Joint Surg. Br.* 85:611-617. doi:10.1302/0301-620X.85B4.12843
- Wang S, Yu RX, Fan W et al. (2022). Detection of skin thickness and density in healthy Chinese people by using high-frequency ultrasound. *Skin Res. Technol.* 29:e13219. doi:10.1111/srt.13219
- Yin B, Guo JL, Wang JZ, Li S, Liu YK, Zhang YZ (2019). Bone material properties of human phalanges using Vickers indentation. *Orthop. Surg.* 11:487-492 (diáfisis de las falanges de la mano: 38,52 ± 6,67 HV). doi:10.1111/os.12455

Las propiedades de los tejidos (tenacidades, módulos) y el resto del modelo de piel son los de FISICA.md §7-9, con sus
fuentes (Pereira 1997, Comley & Fleck 2010, Kim 2001, Aryeetey 2022, Iivarinen 2011, Šarabon 2019, Knight 1975).
