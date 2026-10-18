# Taller industrial · modelos, fuentes y verificación

Guía de la sección **Taller industrial** de la V2 en Godot. Es el equivalente de `docs/FISICA.md` para el
mecanizado, el torno, la radial y la afiladora.

- El detalle de cada modelo, con todas sus fuentes y estimaciones, está en `docs/taller/fuentes-u<n>.md`.
- Los contratos entre módulos están en `godot/CONTRATOS.md`.

> **Valores orientativos.** El taller es un simulador educativo: enseña tendencias y órdenes de magnitud con datos
> publicados, no sustituye al catálogo del fabricante ni a la ficha de la máquina. La radial contra chapa de coche
> no es un procedimiento de rescate.

## 1. Mapa de módulos

| Módulo (`godot/`) | Qué hace | Detalle |
|---|---|---|
| `core/taller/cutting.gd`, `work_materials.gd`, `tool_materials.gd` | Fuerza y potencia de corte (Kienzle), torneado, fresado y taladrado; catálogos de pieza, herramienta, recubrimientos y grupos ISO 513 | [fuentes-u5](taller/fuentes-u5.md) |
| `core/taller/lathe.gd`, `lathe_tools.gd` | Núcleo del torno: perfil r(z), estampado de la punta, alarmas, mando manual, rugosidad medida | [fuentes-u3](taller/fuentes-u3.md) |
| `core/taller/gcode*.gd` | Control compatible con el Fagor 8055 T: lector, intérprete, ciclos G68/G69/G81/G82 y programas de ejemplo | [fuentes-u4](taller/fuentes-u4.md) |
| `core/taller/drawing.gd`, `inspection.gd` | Planos A y B (ISO 286, ISO 2768) e inspección de la pieza torneada con nota | [fuentes-u5](taller/fuentes-u5.md) |
| `core/taller/abrasives.gd`, `panels.gd`, `radial.gd` | Abrasivos, granos, discos (EN 12413), paneles de coche y de rescate, corte de chapa con la radial | [fuentes-u6](taller/fuentes-u6.md) |
| `core/taller/sharpening.gd`, `sharpening_heat.gd` | Afiladora: ángulos, muelas, granos, velocidad periférica y riesgo térmico | [fuentes-u7](taller/fuentes-u7.md) |
| `core/taller/sharpening_machines.gd`, `grinding.gd`, `edge_thermal.gd` | Simulador de afilado: máquinas reales (Einhell, VEVOR, MRCM, Tormek), física del amolado a mano y temperatura transitoria del filo con revenido | [afilado-simulador](taller/afilado-simulador.md) |
| `core/taller/machine_sound.gd`, `tools/bake_sounds.gd` | Sonido de máquina: marco de parámetros y bucles horneados | [fuentes-u8](taller/fuentes-u8.md) |
| `core/taller/lathe_mesh.gd`, `chips.gd`, `app/taller/lathe_3d.*` | Torno 3D: malla de revolución por anillos, acabado según Ra, virutas | [fuentes-u9](taller/fuentes-u9.md) |
| `core/taller/sparks.gd`, `app/taller/radial_3d.*` | Radial contra chapa en 3D: chispas del ensayo de chispas, surco, rebaba, revenido | [fuentes-u14](taller/fuentes-u14.md) |
| `core/taller/workshop_state.gd`, `app/taller/taller_section.*`, `app/taller/ui/*` | Controlador e interfaz del taller | [fuentes-u13](taller/fuentes-u13.md) |

**Capa compartida con el laboratorio** (`core/shared/`):
- El grano abrasivo de la radial usa el mismo contacto que la punta de una uña contra la pintura de un coche:
  punta esfero-cónica, ratio de dureza, Hertz y modo de abrasión de Hokkirigawa–Kato.
- La rebaba de la afiladora sale de Archard.
- Números, azar y paleta son también los del laboratorio.

## 2. Modelos y fuentes (resumen)

### Corte
- **Fuerza específica.** Kienzle, kc = kc1.1·h^(−mc)·Kγ·Kvc·Kver·Ksp, con las tablas del *Tabellenbuch Zerspantechnik*.
  - Cada material sale de una sola familia de datos. La dispersión entre fuentes se enseña como banda.
- **Casos publicados reproducidos:**
  - kc del 42CrMo4: 4011,8 N/mm² (publicado 4011);
  - Pc = 8,4 kW con Fc = 2800 N a 180 m/min;
  - planeado de Sandvik: 27,0 kW en el motor y 21,3 kW con +21° de desprendimiento. Los 27,0 kW incluyen un
    rendimiento de 0,8: en el filo son 21,6 kW.
- **Discrepancias documentadas sin ajustar números:**
  - el fresado con el *Tabellenbuch* da un 27–53 % más que Sandvik;
  - hay una errata en el ejemplo de la pág. 205 del *Tabellenbuch*;
  - el color del grupo S de ISO 513 es el marrón, no el naranja.

### Torno
- **Pieza:** perfil axisimétrico en una rejilla de 0,02 mm.
- **Corte:**
  - en avance, la punta se estampa una vez por vuelta, lo que deja las crestas reales;
  - en rápido se comprueba la cápsula entera;
  - la potencia es Pc = kc·ΔV/Δt, con el volumen realmente arrancado.
- **Rugosidad medida en las crestas simuladas:** Rt 3,07 µm frente a los 3,13 µm teóricos de f²/8rε, y Ra 0,791 µm
  frente a 0,781.
- **Alarmas:** rápido contra material, choques con plato, contrapunto y portaherramientas, herramienta que no está en la torreta, X negativa, avance con el
  cabezal parado, sobrecarga, «talonar» y límite de rpm. Cada una lleva el N del bloque.
- **Profundidad de pasada:**
  - «se rompe» (`AP_EXCEEDED`) exige dos vueltas seguidas por encima de la ap máxima de la plaquita;
  - una sola vuelta es la llegada a un hombro con su creces (`AP_PEAK`, aviso).
- **Límite conocido:** sin compensación del radio de la punta (G41/G42, fase 2), chaflanes, conos y radios salen
  con el error de la punta. Se enseña en la inspección y en la capa de desviación.

### Control Fagor 8055 T
- Sintaxis citada del manual de programación del 8055 T (Ref. 1110), página a página.
- **G68/G69 llevan letras** (`X Z C D L M K F H S E Q`). La forma con parámetros P es del 8025/8030: en el 8055 T da
  un error que lo explica.
- Hay 29 de 31 códigos confirmados; M08/M09 quedan pendientes.
- Programas de ejemplo comentados como en la FP, cada uno con su torreta.

### Plano e inspección
- **Tolerancias:** ISO 286 (h9, h8, js9) y generales ISO 2768-m.
- **Diámetros:**
  - Se miden con un «palpador» de 1 mm que se apoya en las crestas.
  - Junto a un hombro no se mide el acuerdo que deja el radio de la punta: es una esquina, no un error de diámetro.
- **Cara:** es el plano refrentado. Si queda un pezón en el centro (refrentar hasta X0), se informa aparte.
- **Ra:** regla del 16 % de ISO 4288.
- **Nota** de 0 a 10, como en un examen de la FP.

### Radial contra chapa de coche
- **Velocidad del disco.** Mandan, por este orden:
  1. las rpm marcadas en el propio disco;
  2. la tabla de EN 12413;
  3. la fórmula n = 60 000·v/(π·D).
  Un disco de 125 mm a 80 m/s va a ≤ 12 200 rpm.
- **Paneles:** los cuatro coches del laboratorio (mismos espesores y pintura que la 1.x) y dos piezas de rescate.
  - Pilar B de 22MnB5 (Usibor 1500): 1,5 mm, 464 HV.
  - Refuerzo DP800: 1,2 mm, 273 HV.
- **Salida de `cut_panel`:** tiempo, surco, rebaba por lado, zona afectada por el calor, color de revenido, pintura
  quemada, chispas, desgaste y embotamiento del disco, deformación, humo, fundido y limpieza del corte (0 limpio …
  10 sucio), con avisos y sus fuentes.
- **Chispas:** del ensayo de chispas (US Army TC 9-237). El aluminio, el cobre, el latón y el plástico no chispean.
- **Modo manual (fase 2):**
  - al abrir la pestaña, la radial está apagada y apartada;
  - se maneja con el ratón, el teclado o la pantalla;
  - el corte se calcula en cada instante con `Radial.cut_step`, el mismo modelo de `cut_panel`;
  - el motor sigue el balance de energía del rotor con los datos de la Bosch GWS 12-125 CIE: si el empuje pide más
    potencia de la que hay, pierde vueltas y se equilibra, o se desconecta si el giro cae de golpe;
  - detalle, controles y tabla valor → fuente → tipo en [radial-manual](taller/radial-manual.md).

### Afiladora
- **Ángulos por herramienta y uso:** tablas de fabricantes (Tormek, Wüsthof, Zwilling…), Verhoeven, CERATIZIT y
  TC 9-524.
- **Datos del plan corregidos con fuentes:**
  - arista transversal de la broca: 120–135°, no ≈110°;
  - hacha: 25–30°;
  - esmeriladora: 2980–3450 rpm.
- **Velocidad periférica** con aviso de exceso: un disco de 200 mm a 3450 rpm va a 36,1 m/s, por encima de 35.
- **Abrasivo:** nunca diamante para amolar hierro, y CBN por encima de 58 HRC.
- **Riesgo térmico:** en `sharpening_heat.gd`, solo relativo (Malkin–Guo) y revenido equivalente (Hollomon–Jaffe).
- **Simulador de afilado (fase 2):** 11 máquinas reales; temperatura transitoria del filo con una aleta 1D de sección
  variable validada con soluciones exactas; revenido acumulado y pérdida de HRC por acero. Detalle en
  [afilado-simulador](taller/afilado-simulador.md).

### Sonido de máquina
- **Frecuencias:**
  - giro n/60, paso de garras 3·n/60 y paso de dientes n·z/60;
  - zumbido de red de 100 Hz;
  - radial de 125 mm a 11 000 rpm: 183,3 Hz.
- **Implementación:** bucles horneados y deterministas; en tiempo real solo se mueven volumen, tono y filtros de
  bus. Nada se sintetiza muestra a muestra: funciona igual en móvil.

## 3. Integración (lo que se cambió al unir las unidades, y por qué)

| Cambio | Motivo |
|---|---|
| Cada plaquita lleva su `tool_material` (metal duro recubierto) y el torno se lo pasa al modelo de corte | El torno pasaba la designación ISO de la plaquita y el modelo no la conocía: cortaba con fuerza cero |
| El bruto B usa el id `al6082_t6` del catálogo | Los ids de material no coincidían entre el torno y el catálogo |
| `state()` del torno dice si el modelo tenía datos (`cut_ok`, `cut_reason`) | Madera, plásticos o vidrio no tienen kc publicado: no se debe mostrar una potencia falsa |
| `AP_EXCEEDED` solo con dos vueltas seguidas; `AP_PEAK` para una | El acabado de la pieza A «rompía» la plaquita al llegar a cada hombro con 0,1 mm de creces, que es la forma normal de acabar un hombro |
| La pieza B refrenta hasta X−2·rε | Refrentar hasta X0 deja un pezón (la punta es redonda) y el rápido de retirada chocaba con él: así se hace en el taller |
| Cada programa de ejemplo lleva su torreta | El programa B desbastaba 2 mm por pasada con la plaquita de acabado (máx. 1,5 mm) |
| La inspección toma la cara refrentada e ignora el acuerdo de la punta en las esquinas interiores | El pezón central desplazaba todas las longitudes 1 mm, y el acuerdo de rε sumaba ~0,23 mm a cada diámetro |
| Planos con la creces de refrentado de 1 mm y `tolerance_band()` para la capa de desviación en 3D | El contrato fija la cara del bruto en Z+1; la malla necesitaba la banda de tolerancia por anillo |
| La escena de la radial usa `Radial.cut_panel` y los espesores de `panels.gd` y `abrasives.gd` | Quitar el modelo sustituto con números de prueba y los datos físicos duplicados (el pilar de boro tenía 1,8 mm en la escena y 1,5 mm en el modelo) |

## 4. Verificación

- Los tests de cada unidad están en `godot/tests/taller/`. Se ejecutan con `npm run godot:test`.
- **`godot/tests/integration/test_taller_pipeline.gd`** (programa Fagor → torno → modelo de corte → inspección):
  - **Pieza A (C45E):** ciclo de 83 s y Pc de pico de 4,27 kW.
    - Ø30 29,978, Ø40 39,973 y Ø46 46,005, todos en tolerancia; longitudes exactas; Ra 0,78 µm.
    - Chaflán de 0,76 mm, el error teórico sin compensación: 1 − rε(√2−1)√2 = 0,766.
    - **Nota: 9,6/10.**
  - **Pieza B (6082-T6):** ciclo de 40 s.
    - Ø24, Ø36 y el cono en tolerancia.
    - El R2 mide 2,8 (= R + rε, sin compensación) y el inicio del cono sale adelantado.
    - **Nota: 8,0/10.**
  - **Malla 3D:** alimentada por el torno real, actualizando solo los anillos cambiados, da los mismos bytes que una
    malla nueva.
  - **Sonido:** a partir del estado real del torno, el corte suena más que el giro en vacío.
- **Rendimiento** (medido sin ventana en la nube, con 4 núcleos compartidos):
  - 10 000 pasos del torno en 0,5–0,8 s;
  - actualización de la malla de 2000 anillos × 64 lados en 0,13–0,19 ms por fotograma (mediana).

## 5. Lo que no predice

- La vida absoluta de la herramienta. Taylor solo da la tendencia.
- La forma real de la viruta.
- El filo recrecido.
- La aparición del chatter sin la respuesta en frecuencia medida.
- Los campos de temperatura en 2D o 3D. La temperatura del filo al afilar sí se calcula (aleta 1D,
  `edge_thermal.gd`), con ±40 % de incertidumbre y sin validez por encima de 723 °C.
- La integridad superficial.
- El embotamiento real de una muela.
- La rotura de vidrio o piedra.
- Las fuerzas y potencias tienen una incertidumbre de ±30–45 % por la dispersión entre fuentes.

## 6. Pendientes (fases siguientes)

- **Control Fagor, fase 2:** compensación del radio de la punta (G41/G42), roscado, más ciclos y subrutinas.
  Después, el dialecto Fanuc.
- **Fresadora 3D.**
- **Radial:**
  - el ancho de corte del disco de láminas (hoy no corta, sin dato verificado);
  - discos de metal duro y de CBN;
  - energía de corte del acero al carbono (Awan 2021, para sustituir al inox SS201).
- **Datos que no están en internet:** los valores del *Tabellenbuch* siguen como `secondary` hasta cotejarlos con el
  libro.
