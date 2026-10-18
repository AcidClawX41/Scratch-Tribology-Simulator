# Taller · fresadora y taladro en la interfaz (fase 2, unidad 1e)

Las pestañas **Fresadora** y **Taladro** del Taller industrial. El modelo de corte (`core/taller/cutting.gd`, unidad 5:
Kienzle con el *Tabellenbuch Zerspantechnik* y las fórmulas de Sandvik Coromant, con los casos publicados
reproducidos) ya calculaba el fresado y el taladrado; esta unidad los enseña, los anima y los hace sonar.

> **Valores orientativos.** Como todo el taller: tendencias y órdenes de magnitud con datos publicados, no el
> catálogo del fabricante ni la ficha de la máquina. La dispersión de kc entre fuentes es de ±30–45 % y se enseña
> como banda.

## 1. Archivos

| Archivo (`godot/`) | Qué hace |
|---|---|
| `core/taller/mill_drill_state.gd` | Estado de las dos máquinas, sin nodos y determinista: entradas, `Cutting.milling` y `Cutting.drilling` recalculados en cada cambio, máquinas de ejemplo con ficha, geometría del contacto y de la broca, animación del proceso, entrada de sonido y barridos en hilos |
| `app/taller/ui/mill_page.gd`, `drill_page.gd` | Las dos páginas (mismo lenguaje visual que el resto del taller: `TwoPane`, tarjetas, paleta, Syne y Space Mono) |
| `app/taller/mill3d/mill_view.gd` | Esquema animado del fresado visto desde arriba y curva h(φ) |
| `app/taller/mill3d/drill_view.gd` | Esquema animado del taladrado en sección y un filo de cerca |
| `app/taller/mill3d/sweep_chart.gd` | Gráfica de un barrido (y el punto del ensayo actual) |
| `app/taller/mill3d/mill_3d.tscn`, `mill_3d.gd` | La fresadora de torreta en 3D (§6) |
| `app/taller/mill3d/drill_3d.tscn`, `drill_3d.gd` | El taladro de columna en 3D, con la pieza cortada por el eje (§6) |
| `app/taller/mill3d/orbit_rig.gd` | La cámara orbital del torno con las vistas de cada escena |
| `app/taller/mill3d/demo_fresado_taladro.tscn` | Demo guionizada para las capturas con Movie Maker |
| `app/taller/taller_section.gd` | Las dos pestañas nuevas: una máquina a la vez, la visible avanza y suena |
| `tests/taller/test_mill_drill_state.gd`, `tests/app/test_mill_drill_ui.gd` | 17 + 13 tests |

## 2. Qué enseña cada página

**Fresadora.**
- *Herramienta:* fresa de planear (plato de plaquitas: metal duro recubierto o sin recubrir, cermet, cerámicas, CBN o
  PCD) o fresa de mango enteriza (HSS, HSS-Co, metal duro con o sin capa); Ø, número de dientes z y ángulo de posición
  κr (45° o 90° en la de planear, 90° en la de mango). La ficha del material de corte sale de `tool_materials.gd`
  (designación, HV, recubrimiento con su dureza, su temperatura y su color, grupos ISO recomendados, calidad).
- *Pieza:* los 15 materiales de `work_materials.gd`, con su grupo ISO 513 (y su color), su designación y la fuente de
  kc1.1 y mc. Madera, plásticos, vidrio y piedra no tienen kc: la página lo dice con el motivo del catálogo y no da
  potencias.
- *Condiciones de corte:* vc o rpm (al cambiar de modo se conserva el giro), fz, ap, ae (el deslizador llega al Ø),
  posición de la fresa (centrada, en concordancia o en oposición), desgaste del filo (Kver) y taladrina.
- *Máquina:* la ficha de la fresadora de torreta Lagun FTV 2 (3,7 kW, 50–4000 rpm), con la potencia, el tope de
  giro y el rendimiento ajustables y el botón «Volver a la ficha»; marcha y paro, repetir la pasada y la velocidad de
  la animación (×1, ×5, ×20).
- *Resultado* (lo que devuelve `Cutting.milling`): giro (y si lo recorta la máquina), vc, vf y fz, hm y hex, dientes
  en corte zc, kc con su banda de incertidumbre y su desglose (Kγ, Kvc, Kver, Ksp), fuerza de corte media, potencia en
  el filo y en el motor frente a la de la máquina (barra y «SOBRECARGA»), par, caudal de viruta, paso de dientes z·n/60
  y vida de Taylor, siempre como estimación. Calidad de los datos y todas las fuentes.
- *Avisos:* los del modelo (espesor fuera de las tablas, vc fuera del intervalo de la herramienta, herramienta no
  indicada para el grupo ISO, tope de giro, sobrecarga…) y los de la máquina que el modelo no conoce (giro por debajo
  del mínimo de la ficha).

**Taladro.** Broca helicoidal de dos filos (HSS, HSS-Co, HSS con TiN, metal duro con o sin capa), Ø, ángulo de punta σ
con el recomendado para el material y un botón para usarlo, pieza, vc o rpm, avance f (con los avances automáticos de
la máquina: 0,10, 0,20 y 0,30 mm/vuelta), profundidad, desgaste y taladrina; la ficha del taladro de columna ERLO
TSAR-32 (1,1 kW, 75–2010 rpm, Ø32 en acero). Resultado de `Cutting.drilling`: giro, vc en la esquina, vf, h, el largo
del filo b y el área por filo A, kc con su banda y su desglose, fuerza por filo, empuje, par, potencia en el filo y en
el motor, caudal, tiempo del agujero y vida de Taylor (estimación). Avisa además si la broca es más gruesa que la
capacidad de la máquina.

**Gráfica de barrido** (las dos páginas): cómo cambia una salida (potencia en el motor, par, fuerza media o empuje,
vida) al barrer una entrada (ae, fz, ap o vc en la fresadora; f, D o vc en el taladro), con el punto del ensayo actual,
la línea de la potencia de la máquina y los tramos en sobrecarga en rojo.

## 3. De dónde sale cada número

Ningún número que se ve se calcula en la interfaz: todo sale de `mill_drill_state.gd`, que a su vez llama a
`cutting.gd` o saca lo que necesita de su salida.

| Número | De dónde sale | Fuente | Calidad |
|---|---|---|---|
| rpm, vc, vf, fz, hm, hex, zc, kc, banda, Fc media, Pc, P en el motor, par, Q, paso de dientes | `Cutting.milling` | TZ pp. 206–212; Sandvik 2005, pp. D23–D25 ([fuentes-u5](fuentes-u5.md)) | la del resultado (`quality`) |
| rpm, vc, vf, h, kc, banda, Fc por filo, empuje, par, Pc, P en el motor, Q | `Cutting.drilling` | TZ; fórmulas de taladrado de Sandvik | la del resultado |
| Vida | `Cutting` → Taylor con C = vcT15·15^n | TZ p. 215 (n); vcT15 = centro del intervalo de vc | **estimación** |
| Arco de contacto Δφ | `MillDrillState.engagement_of`: Δφ = 2π·zc/z, con el zc del modelo | la geometría del modelo (centrada: cos φ ≤ ae/Dc; lateral: φ₂ = acos(1 − 2·ae/Dc)) | la del modelo |
| Entrada y salida del diente | centrada, simétrica respecto a la normal al avance; oposición, de 0 a Δφ; concordancia, de π − Δφ a π | Sandvik Coromant, «Down milling vs. up milling» | secundaria |
| h(φ) de la curva y del esquema | `MillDrillState.chip_h`: h = fz·sen κ·sen φ dentro del arco | Sandvik; su media en el arco es el hm del modelo y su máximo el hex (lo comprueba un test) | la del modelo |
| b, área por filo, largo de la punta | `drill_geometry`: b = (D/2)/sen(σ/2), A = b·h = D·f/4, punta = (D/2)/tan(σ/2) | geometría de la broca (TZ: h = (f/2)·sen(σ/2)) | — |
| Tiempo del agujero | (profundidad + punta)/vf | geometría | — |
| Ángulo de punta recomendado y hélice | `sharpening.gd` (tablas del afilado: TC 9-524, CERATIZIT, GSR, Gühring, Nachi) | [fuentes-u7](fuentes-u7.md) | la de cada tabla |
| Color de la viruta | `chips.gd` → `temper_color(kind, vc)` | colores de revenido (estimación de la temperatura de la viruta) | **estimación** |
| Potencia y giro de las máquinas | `MillDrillState.MACHINES` | ver §4 | ficha |

## 4. Máquinas de ejemplo

| Máquina | Datos | Fuente | Calidad |
|---|---|---|---|
| Fresadora de torreta **Lagun FTV 2** | 3,7 kW; 50–4000 rpm (50 Hz; 60–4200 a 60 Hz); cono ISO 40. Para la escena 3D: mesa de 1406 × 254 mm con 3 ranuras en T de 16 mm cada 63 mm, carrera vertical de 406 mm y caña cromada de Ø85,70 mm con 127 mm de carrera | Lagun Machinery, catálogo «Fresadoras convencionales» (2016), p. 16 ([PDF](https://www.lagunmachinery.com/datos/subfamilia/documento1/ftv-fu-1016_low.pdf)) | primaria |
| Taladro de columna **ERLO TSAR-32** | motor de dos velocidades de 1/1,5 HP (0,75/1,1 kW); 75–2010 rpm; avances automáticos 0,10, 0,20 y 0,30 mm/vuelta; Ø32 en acero de 70 kg/mm². Para la escena 3D: columna de Ø125 mm, husillo a 300 mm de la columna, a 1245 mm de la base y a 70–885 mm de la mesa, carrera de la caña de 180 mm, mesa de 400 × 420 mm y base de 492 × 655 mm | fichas de venta de [GMF Maquinaria](https://gmfmaquinaria.com/maquinaria-de-segunda-mano/taladro-de-columna-marca-erlo-tsar-32/) y [Rastro Máquinas](https://www.rastromaquinas.com/taladro-erlo-tsar-32/) | secundaria |

- El rendimiento de las dos es el 0,8 del modelo (TZ, p. 212: 0,7–0,85); ninguna ficha lo publica.
- Una broca más gruesa que la capacidad o un giro por debajo del mínimo de la ficha solo se avisan: el modelo no
  sabe nada de la máquina salvo su potencia, su tope de giro y su rendimiento.
- Con el modelo, el taladro de 1,1 kW va justo con su capacidad nominal: Ø32 en C45E con HSS a 15 m/min y
  0,1 mm/vuelta pide 0,98 kW en el filo y 1,23 kW en el motor (con η = 0,8), algo más de lo que da. Es coherente con
  que la capacidad de catálogo sea el límite de la máquina, con un avance o una vc algo menores.
- La caja de 8 velocidades del ERLO no se modela: el giro es continuo.

## 5. Esquemas animados

Lo que está a escala y lo que no:

- **Fresado visto desde arriba.** Fresa, pieza, ae y arco de contacto a escala. El espesor de viruta se exagera
  (el hex ocupa el 16 % del radio) y la escala se escribe («espesor de viruta dibujado ×59»). Dentro del arco se ve
  el material que cada diente deja al siguiente: un festón que va de h(φ) justo delante de un diente a cero justo detrás
  del anterior, porque en el tiempo de un paso de diente la mesa avanza fz. En cada diente que corta, su viruta del
  color que da el core; al salir del arco, sale despedida. La fresa gira como en M03 (horario visto desde arriba) en
  cámara lenta (una vuelta cada 4 s) y el giro real se escribe con el factor («×1/61»).
- **Curva h(φ)** de 0 a 180° con el arco sombreado, hm (media, línea) y hex (máxima) y un punto por diente que corta.
  En oposición el diente entra con h = 0 (la página explica que roza y bruñe); en concordancia sale con h = 0.
- **Tira de la pasada**, a escala solo a lo largo del avance: dónde está la fresa en una pieza de 3 diámetros de largo
  (entre 48 y 200 mm), a su vf real (por la velocidad de la animación), y qué parte del arco está ya dentro.
- **Taladrado en sección.** Pieza cortada por el eje, agujero que va quedando, broca a escala bajando a su vf real
  (aproximación en rápido hasta 1 mm por encima, taladrado hasta que el diámetro entero llega a la profundidad pedida,
  retirada en rápido y otro agujero); las dos gargantas con la hélice de las tablas del afilado, girando en cámara
  lenta (una broca a derechas en M03 lleva la viruta hacia arriba); los filos se encienden mientras cortan; las virutas
  suben por las gargantas y caen a los lados, con la forma (`chips.gd`) y el color del core; empuje, par, σ y el hondo.
- **Un filo de cerca:** la capa que arranca cada filo en media vuelta, entre la pasada del otro filo (f/2 más arriba) y
  la suya, con b, h (perpendicular al filo) y f/2 (en vertical), exagerados con la escala escrita.

La animación del proceso (`MillDrillState.advance`) está en el core: la posición de la fresa, la fase del taladro, la
fracción del arco que corta al entrar y salir (∫h dφ de la parte del arco dentro de la pieza) y la fracción de filo que
corta mientras entra la punta (r/(D/2)). Solo avanza la máquina visible. No es física nueva: la pieza, las holguras y
los rápidos son elecciones del dibujo (`MILL_BLOCK_D`, `MILL_CLEAR_MM`, `DRILL_CLEAR_MM`, `RAPID_S`, `PAUSE_S`).

## 6. Las máquinas en 3D

La ficha «Máquina 3D» de cada página cambia el esquema por la máquina entera, construida por código como el torno
(con sus piezas de `app/taller/lathe3d/`: formas, virutas, taladrina, cámara orbital y cielo del taller, sin tocarlas).
Cuatro cámaras: **detalle** (la zona de corte), **frontal**, **superior** y **general** (la máquina entera); se arrastra
para girar y se acerca con la rueda, como en el torno.

- **Nada se calcula en la escena.** Cada fotograma pinta la vista del estado: `MillDrillState.mill_3d_view()` y
  `drill_3d_view()` (rpm, vc, posición de la fresa y fase de la broca, arco de contacto, potencia que corta ahora, forma y
  color de la viruta). Un test comprueba que esas vistas son las del modelo y que están completas también sin contacto,
  parada o sin datos.
- **Giro real con efecto estroboscópico controlado** (el criterio del torno): mientras la herramienta gira menos de 18°
  por fotograma se ve su giro de verdad (M03, horario visto desde arriba); por encima, el giro dibujado se frena hacia
  0,35 vueltas por segundo y aparece un anillo borroso, como en una grabación.
- **Avance real:** la mesa de la fresadora lleva la pieza a su vf y la pieza se va rebajando ap en una franja de ancho ae
  (centrada, o en el lado de la concordancia o de la oposición); la broca baja con el ciclo de §5.
- **Cotas de las fichas** (§4): mesa, ranuras y caña de la Lagun; columna, distancias del husillo, carrera de la caña, mesa
  y base del ERLO. Como haría el operario, la consola de la fresadora y la mesa del taladro suben o bajan para llevar la
  pieza a la herramienta con la caña casi recogida; un test comprueba que en los extremos de los deslizadores la
  consola no pasa de su carrera, la caña no baja más que la suya y el husillo queda a una distancia de la mesa de la
  ficha.
- **La pieza del taladro va cortada por el eje** (CSG): la mitad de atrás, maciza, enseña el agujero que va quedando
  (cilindro y punta cónica, del fondo que ha alcanzado la punta), y la de delante es translúcida.
- **Herramientas:** la fresa de planear lleva z plaquitas del color de su recubrimiento (`tool_materials.gd`), inclinadas
  κr; la de mango y la broca llevan sus gargantas con la hélice de las tablas del afilado (`sharpening.gd`; para la fresa
  de mango, sin dato del material, la del acero; se dibujan a 5° como poco, aunque la del latón es de 0°).
- **Solo dibujo** (estimación visual, sin fuente): las formas del cuerpo de las máquinas, el portaherramientas, el
  portabrocas, las manetas y los volantes, el tamaño de las piezas y el aspecto del bruto (más oscuro que el
  mecanizado). Las sombras suaves, el SSAO y el MSAA solo están en Forward+; en la nube se comprueba con OpenGL por
  software.

## 7. Sonido

`MachineSound.frame()` con `process: "mill"` o `"drill"` a través de `machine_sound_player.gd` (el mismo reproductor
del resto del taller, sin sonido posicional: `use_3d = false`).

- `teeth`: z de la fresa; en la broca, sus 2 labios. El paso de dientes suena a z·n/60 ([fuentes-u8](fuentes-u8.md)).
- `rpm`: el giro del modelo; 0 con la máquina parada o sin velocidad. `pmax_kw`: el de la máquina (o el ajustado).
- `pc_kw`: la potencia de corte neta por la fracción que corta ahora: la del arco dentro de la pieza en la fresa y, en
  la broca, (r/(D/2))² mientras entra la punta (con kc constante, P = kc·f·ω·r²/2). Fuera de la pieza, 0.
- `vc` y `diameter_mm` (campos que acepta `machine_sound.gd`), `coolant` y el `work_kind` del material.
- Comprobado en la captura: 74,0 Hz con la fresa de planear de 5 dientes a 909 rpm (75,8 Hz menos la caída del 2 % a
  plena carga del motor de inducción), 157,5 Hz con la de mango de 4 dientes a 2387 rpm (159,2 Hz) y 31 Hz con la
  broca a 955 rpm (31,8 Hz).

## 8. Barridos en varios núcleos y pantallas quietas

- `MillDrillState` barre 41 puntos de una entrada en bloques de 6, uno por tarea de `WorkerThreadPool.add_group_task`.
  Cada bloque escribe solo su casilla y los bloques se juntan en orden: el resultado no depende del número de hilos.
- El recorrido de cada barrido es el de `SWEEP_AXES`, alargado hasta el ensayo actual si queda fuera (ap = 20 mm con un
  barrido de 0,2–10 mm): la curva siempre pasa por el punto que se ve en la tarjeta de resultado.
- La interfaz no espera: `poll()` recoge el barrido cuando ha terminado (la sección lo llama en cada fotograma) y, si
  las entradas cambiaron mientras corría, lanza otro con las nuevas. `wait_sweeps()` espera (tests, demo, al cerrar).
- Con la máquina parada y sin virutas en el aire, los esquemas no se redibujan (CONTRATOS: las pantallas quietas no
  gastan CPU).
- Tests: 1 hilo = 4 hilos al bit en todos los barridos; el barrido asíncrono de la aplicación = el secuencial.

## 9. Casos límite

- **ae > Dc:** el estado no lo deja pasar del diámetro (al bajar el Ø, ae baja con él); el modelo, además, lo recorta
  y avisa.
- **ap = 0, rpm = 0, fz = 0:** el modelo avisa («Faltan datos», «Falta la velocidad») y devuelve null; la página
  enseña «—», el esquema dice que no hay contacto que dibujar, el barrido no se rompe y la máquina no suena cargada.
- **rpm fuera de la máquina:** por encima del tope, el modelo recorta el giro, recalcula vc y lo avisa («limitado por la
  máquina»); por debajo del mínimo de la ficha avisa la página.
- **Sin kc** (madera, plásticos, vidrio, piedra): sin fuerzas ni potencias, con el motivo; la geometría del contacto,
  el tiempo del agujero y la animación sí.
- **Dentro del árbol**, al cambiar el recorrido de un deslizador (el ae llega al Ø de la fresa) Godot recorta su valor y
  emite `value_changed`: las páginas ponen recorrido y valor con las señales bloqueadas, y la demo lo vigila con `assert`
  (los tests corren sin árbol y no pueden verlo).

## 10. Lo que no predice

- **Concordancia y oposición** cambian el dibujo (por dónde entra y sale la viruta), no los números: el modelo usa el
  mismo hm y el mismo kc. El roce y el endurecimiento del diente que entra con h = 0, la fuerza que levanta la pieza en
  oposición y la holgura del husillo en concordancia no se calculan; se explican con su fuente.
- **Arista transversal de la broca:** el empuje del modelo (Sandvik, Ff ≈ 0,5·kc·(D/2)·f·sen κr) es el de los filos.
  La bibliografía atribuye a la arista transversal la mayor parte del empuje y a los filos la del par (Watson, *Int.
  J. Mach. Tool Des. Res.* 25, 1985, parte IV; citado por Kishore Kumar, Kishore y Laxminarayana, *IJERT* 2(3), 2013):
  el empuje real es mayor. El par y la potencia son los de los filos, como en Sandvik.
- La **hélice** se dibuja pero no cambia las fuerzas (el modelo no la tiene); tampoco el adelgazado de la punta.
- **Vida:** solo la tendencia de Taylor con C estimada; el recubrimiento no la alarga en el modelo (no hay dato
  publicado accesible, `tool_materials.gd`).
- **Evacuación de la viruta y agujeros profundos** (L/D > 3–5), la **taladrina** (solo suena y se ve), la **flexión**
  de la fresa o la broca, el **salto radial** y el **chatter** (la entrada de sonido va sin chatter): fuera del modelo.
- **Entrada y salida de la fresa:** la fracción que corta es la de la geometría con h ∝ sen φ; sirve para el sonido y el
  dibujo, no cambia los números de la tarjeta, que son los del corte con el arco entero.
- La **curva de potencia del motor** con el giro (se toma constante) y la **caja de velocidades** (giro continuo).
- Por debajo de h = 0,06 mm kc se extrapola (el modelo lo avisa) y por debajo de 0,01 mm se calcula con 0,01.

## 11. Verificación

- `node godot/tools/godot.mjs test --filter=_mill` → 30 tests; el conjunto completo con `npm run godot:test`.
- Capturas (Movie Maker, OpenGL por software bajo Xvfb):
  `npm run godot:capture -- res://app/taller/mill3d/demo_fresado_taladro.tscn --frames=300 --out=<carpeta>` y, en
  teléfono, añadiendo `-- --ancho=390 --alto=844`; una parte con `-- --parte=fresadora` o `--parte=taladro`; las
  máquinas en 3D con `-- --vista=maquina`, y una cámara con `--camara=detalle`, `frontal`, `superior` o `general`.
- La demo corre dentro del árbol y comprueba con `assert`, tras cada cambio, que la página no ha tocado el estado y que
  enseña el resultado del modelo; en depuración un `assert` que falla hace fallar la captura.
