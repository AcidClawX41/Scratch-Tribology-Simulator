# Taller · la radial en tus manos (fase 2, unidad 2c)

Petición de Eric: «que la radial no esté iniciada solo al cambiar a su pestaña, que pueda el usuario también usarla con
controles de forma manual, apartarla y acercarla, o cambiar de giro con el ratón».

Al abrir la pestaña de la radial **no arranca nada**: la amoladora está apagada, parada y apartada 30 mm por encima de
la chapa, sobre el principio de la línea de corte. Se enciende con el gatillo y se maneja con el ratón sobre la vista
3D, con el teclado o con los botones grandes de la tarjeta «La radial en tus manos» (teléfono y quien no use ratón).
El corte automático de antes sigue ahí, detrás del botón **«Ver demostración»**; **«Reiniciar chapa»** pone una chapa
sin cortar.

Simulador educativo: nada de esto es un procedimiento de taller ni de rescate. Los avisos de seguridad llevan su
fuente.

- Física: `godot/core/taller/radial_manual.gd` (la sesión con la radial, paso a paso, sin nodos) y
  `godot/core/taller/radial.gd` (`cut_step`, `cut_capacity`: el modelo de `cut_panel` en el instante presente).
- Interfaz: `godot/app/taller/ui/radial_page.gd` (página), `godot/app/taller/radial_3d.gd` y
  `godot/app/taller/radial3d/` (escena: `hand_input.gd`, `cut_map_view.gd`, `corte_manual.gdshader`, `hazards.gd`).
- Demo guionizada: `godot/app/taller/demo_radial_manual.tscn` (entrada de ratón y teclado simulada con eventos).
- Tests: `godot/tests/taller/test_radial_manual.gd` y `godot/tests/app/test_radial_ui.gd`.

## 1. Controles

### Ratón, sobre la vista 3D

| Gesto | Qué hace |
|---|---|
| Botón izquierdo y arrastrar ← → | Lleva la radial a lo largo de la línea de corte. Los píxeles se pasan a milímetros con la escala de la vista junto al disco (`input_geometry()` de la escena): **la velocidad del ratón es el avance** en mm/s. |
| Botón izquierdo y arrastrar ↑ ↓ | La aparta o la acerca; al acercarla a menos de 2 mm de la chapa o con el disco dentro, 5 veces más fino. |
| Mayús + izquierdo, ← → | Gira la radial alrededor de la normal de la chapa (0,25 °/px en el aire; 0,03 °/px con el disco dentro). |
| Mayús + izquierdo, ↑ ↓ | Inclina el disco sobre la línea de corte (0,15 °/px, de −45° a 45°). |
| Rueda | La acerca o la aparta: el 20 % de la distancia a la chapa por muesca (de 0,2 a 5 mm) y 0,1 mm por muesca cerca de ella o dentro. |
| Mayús + rueda | Inclina 1° por muesca. |
| Alt + rueda | Rueda de velocidad: una posición por muesca. |
| Botón derecho y arrastrar | Gira la cámara (no toca la radial). Mayús + derecho o el botón central la desplazan. |
| Ctrl + rueda (o pellizco en el panel táctil) | Zoom. |

### Teclado

| Tecla | Qué hace |
|---|---|
| Espacio | Gatillo (enciende o apaga). |
| ← → | A lo largo del corte (al avance pedido de la tarjeta «Chapa y corte»; con «máximo», un 95 % de lo que corta el disco). |
| ↑ ↓ | Apartar o acercar (15 mm/s lejos; 1 mm/s cerca, sin pasar del 90 % de lo que el disco puede entrar). |
| Q E | Inclinar el disco (10 °/s). |
| Z X | Girar la radial (30 °/s). |
| V | Dar la vuelta (180°): el disco gira al revés respecto al corte y las chispas salen hacia el otro lado. |
| + − | Rueda de velocidad, una posición. |

### Pantalla (teléfono o sin ratón)

- **Encender / Apagar** (el gatillo), **◀ Atrás**, **Adelante ▶**, **▼ Acercar** y **▲ Apartar**, que actúan mientras se
  mantienen pulsados (52 px de alto en el teléfono), el deslizador **Giro de la radial** y **Dar la vuelta (180°)**.
- Un dedo sobre la vista mueve la radial; dos dedos giran la cámara y hacen zoom.
- Todos los controles llevan nombre y descripción para los lectores de pantalla (`accessibility_name` y
  `accessibility_description`); el estado de la radial y las lecturas de giro y de corte se anuncian solos
  (`accessibility_live`), y el aviso más grave, de inmediato.

### Cómo se traduce la mano (interfaz, no datos)

- **Lo que la mano va por delante del disco es cuánto empuja**, como un muelle entre la mano y la radial: de 0 a
  `Radial.PUSH_N` (30 N, el empuje típico del operario del modelo de corte, ESTIMACIÓN de la unidad 1h) al llegar a
  3 mm a lo largo o a 1 mm hacia dentro. Más allá la mano no puede adelantarse: lo que el ratón se mueve de más se
  pierde, como cuando la radial no deja empujar más. Por debajo de una micra, la mano ya no empuja (guarda numérica).
- **Los botones y las teclas son la mano de quien no fuerza la radial**: a lo largo van al avance pedido, pero si ya
  empujan casi lo que el motor aguanta sin perder vueltas (el 95 % de `push_limit_n`), no se adelantan más y van a lo
  que corta el disco; hacia dentro no pasan del 90 % de lo que el disco puede entrar (`plunge_cap_mm_s`).
- **El ratón es la mano sin filtro**: si se arrastra más deprisa de lo que corta el disco empujando a fondo, sale
  «demasiado avance» y, si lo que limita es la potencia, el motor pierde vueltas y puede desconectarse.

## 2. Lecturas: qué calcula cada una

Todas salen del `frame` de `RadialManual.step()` (la página y la escena no calculan física) y se escriben con
`Fmt` (coma decimal).

| Lectura (bajo la vista) | Campo | Qué es |
|---|---|---|
| Giro | `rpm` (y `rpm_set`) | Giro real del disco. Entre paréntesis, el fijado por la rueda si todavía no ha llegado (arranque, pérdida de vueltas). |
| Periférica | `vs_ms` | Velocidad del borde, π·D·n/60 000 (m/s). |
| Avance | `feed_mm_s`, `feed_want_mm_s`, `feed_cap_mm_s` | Avance real del disco a lo largo del corte (media móvil de 0,2 s), lo que pide la mano y lo que puede cortar empujando a fondo (el menor de los límites de potencia y de empuje de `Radial.cut_capacity`, dividido por surco × espesor). |
| Profundidad | `depth_mm`, `total_mm` | Punto más bajo del disco bajo la cara pintada (apartada, si es negativa); «atraviesa» cuando pasa del espesor total con la pintura. |
| Ángulo | `tilt_deg` | Inclinación del disco sobre la línea de corte (0° = perpendicular a la chapa). |
| Giro de la radial | `yaw_deg` | Alrededor de la normal de la chapa; 0° o 180° = alineada con la línea. |
| Cortado | `cut_length_mm`, `groove_length_mm` | Longitud atravesada de lado a lado (muestras del mapa cada 0,25 mm) y, si es mayor, la del surco sin atravesar. |
| Calidad del corte | `cleanliness` | Media de la limpieza de `Radial.cut_step` (0 limpio · 10 sucio) en lo atravesado: rebaba, calor a la vista, embotamiento, inclinación y fundido, con las escalas y pesos de `cut_panel` (ESTIMACIÓN de la unidad 6). |

La escena pinta además, desde el mismo `frame` y el mapa del surco (`texture_data()`): el surco con su anchura e
inclinación, la rebaba a cada lado donde atraviesa, la pintura quemada, la zona de más de 200 °C, el plástico fundido,
el brillo del frente a `front_temp_c`, las chispas (`sparks`: caudal, color, longitud y estallidos de
`Sparks.stream_for`) saliendo por `spark_exit`, el humo (`smoke`) y el embotamiento del disco (`disc_loading`). El
sonido es `MachineSound.frame()` con el proceso `grinder`, las rpm reales y la potencia de corte (`sound`): en vacío
suena el motor y cortando sube el ruido del corte.

## 3. El modelo, paso a paso (`RadialManual.step`)

1. **La mano.** Los botones y las teclas dan velocidades continuas; el ratón mueve la mano a saltos. El adelanto de la
   mano sobre el disco da el empuje (apartado 1).
2. **El disco.** Sigue a la mano. En el aire llega sin más; en la chapa solo avanza lo que puede arrancar en ese paso
   con ese empuje: `Radial.cut_capacity` da el menor de dos límites, la potencia útil a ese giro (resolviendo
   SEC(Q)·Q = P con la energía específica medida por Awan et al. 2022) y el empuje por Archard. Una bisección guiada
   por la secante busca hasta dónde llega con ese volumen. Un disco que no corta (láminas) o torcido más de 6° no
   entra: toca la chapa.
3. **El corte.** Lo que arranca va a `Radial.cut_step` (el modelo de `cut_panel` con las rpm, la profundidad, el
   ángulo y el avance de ese instante; a profundidad completa da lo mismo que `cut_panel`, al bit) y se apunta en el
   mapa del surco: profundidad, semiancho, tan(inclinación), rebaba a cada lado, pintura quemada, zona caliente y
   fundido, cada 0,25 mm, con un semicírculo de pintura quemada y de zona caliente alrededor de los extremos. El
   desgaste del disco es lo arrancado / G (`wear_mm3_per_mm3`).
4. **El motor.**
   - *Arranque:* con la corriente de arranque limitada, el giro sube hacia el fijado con τ = 0,5 s (el 95 % en 1,5 s).
   - *Rueda de velocidad:* 6 posiciones de la GWS 12-125 CIE (2.800 · 4.500 · 6.300 · 8.200 · 9.800 · 11.500 rpm) y
     nunca por encima de las rpm marcadas en el disco (`Radial.disc_check`, EN 12413): si se pide más, la radial se
     queda en el límite y sale el aviso.
   - *Con carga:* la electrónica de giro constante sostiene el giro mientras la potencia alcanza (Bosch). La radial de
     230 mm, sin esa electrónica, cae hasta un 30 % a plena carga. Hacia un giro fijado mayor sube como en el arranque;
     hacia uno menor (se baja la rueda) baja como en la parada por inercia, porque la electrónica no frena (supuesto).
   - *Potencia útil:* la nominal mientras tiene corriente, a cualquier giro, la misma que usa `cut_panel` (supuesto: un
     motor universal no pierde potencia al bajar de vueltas, porque su par sube: Chapman 2012).
   - *Falta de potencia:* si la mano empuja y el disco no llega porque lo limita la potencia, ese empuje pide la
     potencia que costaría arrancar lo que da por Archard; la diferencia frena el rotor por balance de energía,
     J·ω·dω/dt = P_disponible − P_pedida, con la inercia J deducida del arranque (J = P·τ/ω², 2,2·10⁻⁴ kg·m² en la de
     125 mm). Como lo que arranca el empuje baja con el giro, el motor pierde vueltas hasta que se equilibran y sigue
     cortando (en acero dulce, empujando a fondo con el disco fino, un 10-15 %); cuando se afloja, la electrónica
     recupera el giro.
   - *Desconexión por rebote* (GWS 12-125 CIE): salta si el giro cae más de un 2 % en 15 ms (un empujón que pide mucha
     más potencia de la que hay, como empujar a fondo en el plástico, o el disco pellizcado); hay que soltar el gatillo
     para volver a arrancar (protección contra el rearranque).
   - *Motor calado* (la de 230 mm, sin desconexión): si el disco se bloquea o se para dentro del corte; se recupera al
     sacarlo.
   - *Parada al soltar el gatillo:* sin freno, cae exponencialmente hasta pararse (por debajo de 30 rpm) en 5,9 s desde
     el giro máximo; tras un bloqueo, casi en seco (τ = 50 ms).
5. **El pellizco.** Si el disco está girado respecto al surco que tiene debajo (los extremos del arco de contacto se
   desplazan ½·contacto·sen δ) o inclinado distinto (el fondo se desplaza profundidad·tan Δθ) más que la mitad de la
   holgura del surco (0,4 mm, Awan et al. 2022), roza las paredes y sale el aviso; si se desplaza más que su propio
   espesor, se bloquea: tendría que cortar de lado. Ese umbral es un supuesto geométrico.
6. **Las chispas.** Salen por donde el borde del disco deja el material, en su sentido de giro: avanzando a favor del
   giro (o bajando), por la cara pintada, hacia delante y arriba; en contra y atravesando la chapa, por la cara de
   abajo, hacia dentro del coche. Llegan a una zona si está a su alcance (la longitud de `Sparks.stream_for`) y dentro
   del abanico del haz (±9°, `Sparks.SPREAD_IN_PLANE_DEG`) más lo que abarca la zona.
7. **Los avisos en directo**, del más grave al menos, con su fuente (apartado 5).

## 4. Valores, fuentes y tipo

Tipo: **primaria** (medida o dato del fabricante o de la norma), **estimación** (con el caso medido más parecido y el
supuesto escrito), **supuesto** (hipótesis del modelo, sin número medido) o **interfaz / dibujo** (no es un dato).

| Valor | Dónde | Fuente | Tipo |
|---|---|---|---|
| GWS 12-125 CIE: 1.200 W de entrada, 640 W útiles, 11.500 rpm en vacío, rueda de 2.800 a 11.500 rpm en 6 posiciones, electrónica de giro constante, limitación de la corriente de arranque, protección contra el rearranque y desconexión por rebote; sin freno en sus datos | `MACHINE_125` | Bosch, instrucciones 1 609 92A 5RE (16-2-2022), datos técnicos y tabla de la rueda («valores orientativos») | primaria |
| Radial de 230 mm: GWS 22-230 P, 2.200 W, 6.500 rpm, 1.265 W útiles | `Radial.GRINDERS` | ficha de Bosch; la potencia útil, con el rendimiento de la de 125 mm (unidad 6/1h) | primaria y estimación (previas) |
| Arranque: el 95 % del giro en 1,5 s (τ = 0,5 s) | `SPINUP_S` | Caso más parecido: módulo de arranque suave para herramientas de escobillas, «gana la velocidad plena en ca. 1-2 segundos» (ULFATEC, descripción del fabricante). Supuesto: la limitación de Bosch arranca como él; se toma el centro | estimación |
| Parada sin freno en 5,9 s desde el giro máximo (τ = 0,99 s en la de 125 mm) | `COAST_STOP_S` | Project Farm (23-2-2023): 11 radiales de cable para disco de 115 mm, de 3,4 a 7,3 s, mediana 5,9 s. Supuesto: la GWS 12-125 CIE, como la mediana, con caída exponencial hasta 30 rpm | estimación |
| Con freno, 2 s como mucho (solo para comparar; el modelo no tiene freno) | texto | Hilsenbeck (Metabo), jornada de la DGUV, 20-6-2024: «Alle Winkelschleifer mit Bremse stoppen die Scheibe … innerhalb von 2 Sekunden» | primaria |
| Parada tras un bloqueo: τ = 50 ms | `JAM_TAU_S` | Caso medido más parecido: velocidad de la hoja de una sierra de mesa en un rebote (Bosch, US 11 571 831 B2, fig. 4, 1 muestra/ms): caída rápida de unos 150 ms. Supuesto: el disco bloqueado se para igual | estimación |
| La desconexión por rebote salta si el giro cae más de un 2 % en 15 ms | `KICKBACK_DROP`, `KICKBACK_WINDOW_S` | El umbral publicado más parecido, el de la misma patente de Bosch: velocidad por debajo del 98 % de la media en 10 de las 15 últimas muestras de 1 ms. El de la radial no está publicado | estimación |
| Caída del giro a plena carga sin electrónica: 30 % | `DROOP_FULL_LOAD` | La de `machine_sound.gd` (motor universal, Chapman 2012) | estimación (previa) |
| Potencia útil constante mientras tiene corriente (la nominal, a cualquier giro) | `step` | La de `cut_panel`; un motor universal (serie) no pierde potencia al bajar de vueltas porque su par sube (Chapman 2012). La electrónica real puede limitar la corriente | supuesto |
| Inercia del rotor y el disco, J = P·τ/ω² (2,2·10⁻⁴ kg·m² en la de 125 mm) | `_inertia` | Deducida del arranque; supuesto: arranca con su par nominal. Nadie publica la inercia de una radial | estimación |
| Empuje máximo de la mano, 30 N | `Radial.PUSH_N` | radial.gd (unidad 1h) | estimación (previa) |
| Energía específica, límite de potencia y de empuje, surco, calor, rebaba, limpieza, chispas, desgaste | `Radial.cut_step`, `cut_capacity` | Los de `cut_panel` (docs/taller/fuentes-u6.md y pulido-taller.md): Awan et al. 2021 y 2022, Archard 1953, Adams 1958, Rowe et al. 2003, TC 9-237 | los de su fuente |
| Holgura del surco, 0,4 mm | `Radial.KERF_EXTRA_MM` | Awan et al. 2022, Sensors 22:7152 | primaria (previa) |
| El pellizco bloquea si el disco se desplaza de lado más que su espesor | `_pinch`, `_jam` | EN 62841-2-3 (un disco de corte no corta de lado; pellizcado, rebota) | supuesto |
| Abanico del haz de chispas, ±9° | `Sparks.SPREAD_IN_PLANE_DEG` | sparks.gd (unidad 14): a partir de fotografías de cortes | estimación (previa) |
| Límite de rpm del disco | `Radial.disc_check` | Lo marcado en el disco, la tabla de EN 12413:2019 o la fórmula | primaria (previa) |
| Generador de gas del airbag (u = 380 mm, n = 70 mm, zona de 40 mm) y charco de combustible | `HAZARD_AIRBAG`, `hazards.gd` | Ejemplo de dibujo; cada coche tiene su hoja de rescate ISO 17840 | dibujo |
| Adelanto de la mano (3 mm y 1 mm), guarda de 1 µm, medias móviles (0,12 s y 0,2 s), paso máximo 0,1 s, mapa cada 0,25 mm, alineación automática (6°), recorridos (±45°, −80 a +6 mm, 80 mm por los cantos), reposo (30 mm arriba), surco mínimo del pellizco (0,2 mm), umbrales de los avisos (95 % y 90 % del giro; 4 s del aviso de arranque en el corte) | constantes de `radial_manual.gd` | Elección de la interfaz o guarda numérica | interfaz |
| Botones y teclas: 15 mm/s lejos y 1 mm/s cerca (≤ 90 % de lo que entra), «máximo» = 95 % de lo que corta, sin pasar del 95 % del empuje que aguanta el motor; Q E 10 °/s, Z X 30 °/s | `radial_page.gd` | Elección de la interfaz | interfaz |
| Ratón: 0,25 °/px (0,03 °/px dentro), 0,15 °/px, 1° por muesca con Mayús, rueda al 20 % de la distancia (0,2-5 mm) y 0,1 mm cerca | `hand_input.gd` | Elección de la interfaz | interfaz |
| Brillo del frente que se apaga a 3.000 °C/s; cámara que sigue al disco (τ = 0,25 s); en el teléfono, 40 % de chispas y 50 % de humo | `radial_3d.gd` | Dibujo y rendimiento (la física no cambia) | dibujo |

## 5. Avisos en directo

| Código | Nivel | Cuándo | Fuente |
|---|---|---|---|
| `exceso_velocidad` | peligro | La rueda pide más rpm de las marcadas en el disco (la radial se queda en el límite) | EN 12413:2019; EN 62841-2-3 |
| `disco_fijo` | peligro | Disco para tronzadora fija (CBN 1A1R) montado en la radial | Tyrolit (fichas de SKS y Hoffmann); EN 62841-2-3 |
| `desconexion_rebote` | peligro | El giro ha caído de golpe y la radial ha cortado la corriente | EN 62841-2-3, instrucciones de Bosch |
| `rebote` | peligro | La radial sin desconexión se ha calado con el disco bloqueado | EN 62841-2-3 |
| `pellizco` | peligro | El disco roza las paredes del surco (girado o inclinado respecto a él) | EN 62841-2-3 |
| `chispas_combustible` | peligro | Las chispas salen por debajo de la chapa (avanzando en contra del giro y atravesando) | OSHA 4188 (2022); DHS SAVER (2022); EN 62841-2-3 |
| `chispas_airbag` | peligro | En las piezas de rescate, el haz llega al generador de gas del ejemplo | Moore, Firehouse (2005); ISO 17840-1:2022 |
| `arranque_en_corte` | peligro | Se enciende con el disco tocando la chapa o dentro del corte (4 s) | EN 62841-2-3 |
| `demasiado_avance` | aviso | La mano empuja a fondo y aun así va por delante del disco (a lo largo o hacia dentro); dice qué lo limita y si el motor pierde vueltas | Bosch y Awan et al. (potencia) o Archard (empuje); EN 62841-2-3 |
| `pierde_vueltas` | aviso | El empuje pide más potencia de la que da el motor a ese giro | Bosch; Awan et al. 2022 |
| `sin_plena_velocidad` | aviso | Corta antes de llegar al 90 % del giro fijado | EN 62841-2-3 |
| `alinear` | aviso | El disco toca la chapa girado más de 6°: no entra | — |
| los del modelo | aviso | Al tocar la chapa: `sin_corte`, `disco_no_corta`, `disco_inadecuado`, `diamante_ferrico`, `sic_ferrico`, `diamante_fundicion`, `embotamiento`, `polvo_aluminio`; cortando: `acunamiento`, `pintura_humo`, `plastico_fundido`, `pilar_boro` | las de `radial.gd` |
| `inercia` | nota | El disco sigue girando tras soltar el gatillo | EN 62841-2-3 |

## 6. Qué no predice

- **La fuerza de la mano no se mide:** el empuje sale del adelanto del ratón (interfaz). El tope de 30 N es la
  estimación de la unidad 1h, no la fuerza de una persona concreta.
- **El rebote no se simula como movimiento:** ni el golpe que lanza la radial hacia el operario, ni el efecto
  giroscópico, ni la rotura del disco. El modelo solo dice cuándo se bloquea el disco y qué hace el motor.
- **Motor:** la inercia, el par de arranque, la forma de la curva de parada y el umbral de la desconexión por rebote de
  la GWS 12-125 CIE no están publicados: son estimaciones con el caso más parecido (apartado 4). Con la potencia útil
  constante, la radial no se cala por empujar despacio de más: pierde vueltas hasta equilibrarse; si la electrónica real
  limita la corriente, se pararía antes.
- **Una sola línea de corte recta:** el mapa del surco es de una dimensión (a lo largo de la línea); no hay cortes
  curvos ni en otra dirección, y el disco girado más de 6° no entra.
- **El pellizco por cierre del surco** (la chapa que se cierra sobre el disco al cortar una pieza que cuelga) no está:
  solo el que provoca la mano al girar o inclinar el disco dentro del surco.
- **El escenario de las chispas es un ejemplo:** la posición del generador del airbag y del combustible es de dibujo; la
  de un coche de verdad está en su hoja de rescate ISO 17840.
- **El sonido de la parada:** el zumbido del motor de `machine_sound.gd` sigue a las rpm reales al parar por inercia;
  sin corriente, un motor de verdad deja de zumbar y se oyen el aire y los rodamientos.
- **Calor a muy poco avance:** la pintura quemada y la zona caliente salen de la fórmula de Adams (1958) para una fuente
  que avanza, con la energía específica de Awan et al., que crece mucho a poco caudal. Al entrar despacio en la chapa o
  al empezar a cortar con el disco grueso, el modo manual pasa mucho tiempo en ese terreno y da anchuras de decenas de
  milímetros durante un instante: ahí la fórmula de fuente móvil deja de valer (el calor se queda en el sitio y se
  reparte por conducción) y lo sobrestima. Queda anotado para quien lleve el modelo de corte.
- Lo que no predice el modelo de corte (docs/taller/fuentes-u6.md y pulido-taller.md) tampoco lo predice el modo manual.

## 7. Rendimiento

Medido sin ventana (Godot 4.7.2, en la máquina de la nube, sin contar el dibujo), con la radial cortando acero dulce
a lo largo a 15-17 mm/s:

| Qué | Media | p95 |
|---|---|---|
| `RadialManual.step()` en marcha en el aire | 0,05 ms | 0,08 ms |
| `RadialManual.step()` entrando en la chapa | 0,35 ms | 0,49 ms |
| `RadialManual.step()` cortando | 0,60 ms | 1,0 ms |
| `tick` de la página (el paso del core, `show_frame` de la escena y las lecturas) | 0,90 ms | 1,1 ms |
| `_process` de la escena cortando (chispas, humo, mapa y pose; lo más caro es el emisor de chispas de la unidad 14) | 3,3 ms | 4,7 ms |
| `_process` de la escena en la demostración de antes (modo automático), para comparar | 2,9 ms | 3,9 ms |


- Por fotograma solo cambian textos, transformaciones, parámetros de shader, partículas y una textura de 2 × 921
  píxeles RGBA de coma flotante (el mapa del surco), y solo cuando cambia (`map_version`). Las mallas del surco y de la
  rebaba se hacen una vez por chapa y el shader las deforma; ningún nodo se crea por fotograma (lo comprueba
  `test_nada_crea_nodos_en_cada_fotograma`).
- Preset del teléfono: 40 % de chispas y 50 % de humo; la física no cambia.

## 8. Pruebas

- `tests/taller/test_radial_manual.gd`: `cut_step` = `cut_panel` a profundidad completa (378 casos, al bit); surco
  parcial; `cut_capacity`; empieza apagada y apartada; arranque y parada por inercia; sin contacto no se corta; la
  longitud cortada crece con el avance; el empuje de la mano; demasiado avance y desconexión por rebote; la falta de
  potencia frena el motor (y el empuje no); la radial grande se cala; disco parado; la rueda no pasa de lo marcado;
  radial grande sin rueda; torcer el disco en el surco; hacia dónde salen las chispas; chispas hacia el airbag; el
  disco de láminas no corta; cambios sin reiniciar y chapa nueva; determinista; entrada de sonido; mapa para la escena;
  sin estado estático ni nodos.
- `tests/app/test_radial_ui.gd`: la pestaña no arranca nada; los números en pantalla son los del core; sin contacto
  no se corta; cambios de disco, chapa y diámetro; cambiar de disco no cambia las rpm elegidas; ver demostración;
  modo teléfono; la escena carga sin ventana; nada crea nodos en cada fotograma (y los botones no fuerzan la radial);
  el ratón mueve la radial y la cámara.

## 9. Fuentes

- Bosch Power Tools, *GWS Professional*, instrucciones de uso 1 609 92A 5RE (16-2-2022): datos técnicos de la
  GWS 12-125 CIE (3 601 G94 0..), «Speed preselection» (tabla de la rueda), «Constant Electronic control», «Starting
  current limitation», «Restart protection», «Kickback Control» e indicaciones de seguridad para tronzar de
  EN IEC 62841-2-3.
- Project Farm, «Best Corded Angle Grinder: 11 Grinders Tested for Cut Speed, Torque, and Vibration»,
  projectfarmreviews.com, 23-2-2023: tiempo de parada del disco de 11 radiales de cable de 115 mm (3,4-7,3 s).
- ULFATEC, «Sanftanlauf-Modul bis 20 A, Softstart-Anlaufregelung für Maschinen und Elektrowerkzeuge» (descripción
  del fabricante): «gewinnt in kurzer Zeit nach Einschalten (ca. 1-2 Sekunden) erst die volle Drehzahl».
- Hilsenbeck U. (Metabo), «Sicherheitstechnologien bei Winkelschleifern», jornada del Fachbereich Holz und Metall de
  la DGUV, 20-6-2024.
- Robert Bosch GmbH, patente US 11 571 831 B2, «System and method for kickback detection based on blade speed in a
  power tool» (prioridad 25-9-2014): registro de la velocidad de la hoja en un rebote (fig. 4) y umbral de detección.
- Otro caso medido, más antiguo: Thyssen C. y Fluhrer S., «Nachrüsten einer elektromechanischen Bremse in einen
  Winkelschleifer», Jugend forscht 1996 (una radial sin freno tardaba 20 s en parar; con el freno, 3 s). No se usa en
  el modelo: no dice qué radial era.
- Chapman S. J., *Electric Machinery Fundamentals*, 5.ª ed., McGraw-Hill, 2012 (motor universal), por
  `core/taller/machine_sound.gd`.
- Las del modelo de corte: docs/taller/fuentes-u6.md (Awan et al. 2021 y 2022, Archard 1953, Adams 1958, Rowe et al.
  2003, TC 9-237, EN 12413:2019, EN 62841-2-3, OSHA 4188, DHS SAVER, Moore 2005, ISO 17840-1:2022) y
  docs/taller/pulido-taller.md (discos de metal duro y de CBN).
