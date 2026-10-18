# Unidad 9 · Torno 3D: malla dinámica, acabado y virutas

Escena 3D del torno del **Taller industrial**: la pieza va perdiendo material anillo a anillo, su superficie pasa
de bruto a desbaste mate, acabado brillante y pulido espejo según el Ra que publica el torno, y salen virutas con
la forma y el color que tocan. La escena **no calcula mecanizado**: pinta lo que le da una fuente de perfil (el
núcleo del torno de la unidad 3; en la demo, una fuente simulada) y lo que le pasa la interfaz.

## Archivos

| Archivo | Qué hace |
|---|---|
| `godot/core/taller/lathe_mesh.gd` | Malla de revolución a partir del perfil del contrato: arrays, bytes de GPU y actualización por rango `dirty` |
| `godot/core/taller/chips.gd` | Virutas deterministas: forma según el material, color de revenido según vc, balística y superficies de reposo |
| `godot/app/taller/lathe_3d.tscn` + `.gd` | La escena del torno y su API pública |
| `godot/app/taller/acabado.gdshader` | Metal según material, rugosidad según Ra, marcas de avance, caras y capa de desviación |
| `godot/app/taller/lathe3d/` | Ayudantes: máquina procedural, plato, pieza, virutas, refrigerante, cámara, cielo de la nave, fuente de la demo |
| `godot/app/taller/demo_torno3d.tscn` + `.gd` | Demostración de unos 10 s |
| `godot/tests/taller/test_lathe_mesh.gd` | Tests de la malla y de las virutas |

## API pública de la escena (`lathe_3d.gd`)

Coordenadas del torno en mm, r en radio, Z0 en la cara acabada (CONTRATOS.md).

| Llamada | Efecto |
|---|---|
| `set_profile_source(obj)` | Cualquier objeto con `profile()` (perfil del contrato). Si además tiene `tool_pose()` → `Vector2(r, z)` o `{r, z}`, la escena la lee en cada fotograma |
| `set_rpm(rpm)` | Giro del cabezal; negativo, al revés |
| `set_tool_pose(r, z)` | Punta teórica de la herramienta |
| `set_cutting(on, pc_kw)` | Si corta y con qué potencia: caudal de virutas |
| `set_overlay("acabado" \| "desviacion")` | Capa de la pieza |
| `set_view("frontal" \| "superior" \| "detalle" \| "general")` | Vista de cámara con transición suave; la de detalle sigue a la punta |
| `set_work_material(kind)` | `kind` de CONTRATOS.md: aspecto del metal y del bruto, forma y color de las virutas |
| `set_plan(banda)` | Banda de tolerancia `{z0, dz, r_min, r_max}` para la capa de desviación (ver `LatheMesh.band_from_segments`) |
| `set_coolant(on)`, `set_chuck_grip(mm)`, `set_feed(f)`, `set_nose_radius(rε)`, `configure_lod(lados, anillos)` | Refrigerante, longitud dentro del plato, paso real de las marcas, radio de punta y nivel de detalle |
| `tool_tip_global()`, `cutting_speed()` | Punta en coordenadas de escena (para `tool_pos` del sonido) y vc en m/min |

## Malla dinámica (`lathe_mesh.gd`)

- **Nivel de detalle.** Toma uno de cada `ring_step` anillos del núcleo (muestreo puntual, siempre con el último)
  para no pasar de `max_rings` (2000 en escritorio), y `sides` lados (64; 32 en móvil) más la columna de la
  costura. Dos tapas cierran la pieza. Cualquier rango de anillos es un bloque contiguo de vértices.
- **Actualización por rango.** Del `dirty` del contrato salen los anillos de la malla que lo muestrean y un vecino a
  cada lado (sus normales dependen de ellos). Se devuelven los bytes de posiciones, normal + tangente y
  atributos, con su desplazamiento, para `surface_update_vertex_region` / `surface_update_attribute_region`.
- **Formato de Godot 4.7** (sin comprimir, comprobado en los tests contra `RenderingServer`): posiciones 12 B por
  vértice al principio del búfer de vértices; detrás, normal y tangente octaédricas (2 × 2 uint16, 8 B); atributos
  UV (2 float) + CUSTOM0 (4 float) = 24 B. La codificación octaédrica se hace con las mismas operaciones en float32
  que el motor: los bytes coinciden bit a bit con los de `add_surface_from_arrays`.
- **Rápida en GDScript:** por anillo, tres productos nativos (`Transform3D * PackedVector3Array`) en lugar de un bucle
  por vértice. La inclinación del perfil se cuantiza (16384 pasos por vuelta) antes de calcular normales, así que
  la caché de columnas de normales no cambia el resultado: reescribir un rango da los mismos bytes que reconstruir.
- **CUSTOM0 por vértice:** x = Ra (µm) · y = tipo de pasada (0 bruto, 1 desbaste, 2 acabado, 3 pulido) · z =
  desviación del diámetro respecto al centro de la zona de tolerancia (µm) · w = semiancho de esa zona (µm), o −1
  si el plano no acota el anillo. La componente w era «reservada» en el encargo: la uso para la tolerancia porque
  la capa de desviación la necesita por anillo (Ø30 h9 y Ø46 ±0,1 conviven en la misma pieza).

### Rendimiento medido (CPU, sin ventana)

| Caso | Tiempo |
|---|---|
| Actualización por fotograma, 2000 anillos × 64 lados, pasada que avanza 0,5 mm por fotograma (mediana / p95; 4 núcleos compartidos con otros 10 agentes) | 0,13–0,19 ms / 0,16–0,30 ms |
| Reescribir la malla entera (2000 × 64) | 7–14 ms |
| Construcción completa (2000 × 64) | 46–78 ms (solo al cambiar de pieza, de rejilla o de plano) |
| Demo (1418 anillos × 64, pasadas aceleradas unas 8 veces), actualización por rangos incluida la subida a la GPU | media 0,61 ms, máxima 1,66 ms |

El criterio del encargo (≤ 2 ms por fotograma con 2000 × 64) se cumple con margen; el test lo comprueba.

## Acabado (`acabado.gdshader`)

- **Metal:** F0 en sRGB lineal de Hoffman (2015) para hierro/acero (0,562 0,565 0,578), aluminio (0,913 0,922 0,924),
  titanio (0,542 0,497 0,449) y níquel (0,660 0,609 0,526). Latón (0,887 0,789 0,434), inoxidable y fundición:
  **estimación**. El aspecto del bruto (calamina del laminado en caliente, estirado, extruido) es una
  **estimación visual**.
- **Rugosidad a partir de Ra:** curva continua 0,1 µm → 0,06 (espejo) · 0,8 → 0,18 · 3,2 → 0,33 · 12,5 → 0,53
  (GGX perceptual). **Estimación visual** apoyada en que el lóbulo especular crece con la pendiente de las crestas, y
  esta con f/rε (pendiente máxima = f/(2·rε)).
- **Marcas de avance:** crestas de perfil circular de radio rε con el paso f. Si la fuente no da f, sale de la
  fórmula clásica del acabado teórico en torneado, **Ra ≈ f²/(32·rε)** (Boothroyd y Knight, *Fundamentals of Machining
  and Machine Tools*, 3.ª ed., 2006: Ra = 0,0321·f²/rε, que sale de la altura pico-valle teórica Rt = f²/(8·rε)),
  despejada: f = √(32·rε·Ra). Con desbaste f = 0,4 mm y rε = 0,8 mm da Ra ≈ 6,3 µm, y con acabado
  f = 0,15 mm, 0,9 µm. La pendiente dibujada se reduce al 70 % (las crestas reales se redondean por el flujo lateral
  del material: **estimación**). Cuando el paso ya no cabe en un píxel, las crestas se funden en la rugosidad y en
  anisotropía (lisa a lo largo de la vuelta, rugosa a lo largo del eje; Forward+ y Mobile), sin muaré.
- **Caras** (hombros, refrentado): se reconocen porque la normal geométrica del triángulo (derivadas de pantalla) no
  coincide con la suavizada del anillo; se sombrean planas y con marcas concéntricas.
- **Capa de desviación:** ámbar si sobra material (más oscuro cuanto más sobra), verde en tolerancia, rojo si está
  pasado de medida, gris donde no hay cota. En los hombros, los anillos a menos de 0,1 mm del cambio aceptan la
  unión de las dos bandas: la cota axial no es un diámetro y un anillo de más no debe salir en rojo.
- **Tolerancias de la demo:** ISO 286 (h9: 0/−52 µm de 18 a 30 mm y 0/−62 µm de 30 a 50 mm, las de CONTRATOS.md);
  chaflán ±0,2 mm según ISO 2768-1 clase m (aristas y chaflanes de 0,5 a 3 mm).

## Virutas (`chips.gd`)

- **Forma por material** (clases de ISO 3685:1993, anexo G): rizada = en arco (6, la del rompevirutas), espiral =
  tubular o helicoidal (2, 4 y 5), astillada = elemental o de aguja (7 y 8). Asignación por grupo ISO según el
  *Training Handbook* de Sandvik Coromant: acero (P) viruta larga controlable con rompevirutas → rizada; inoxidable
  (M) larga y tenaz → espiral; fundición (K) corta → astillada; aluminio (N) larga → espiral; superaleaciones (S)
  tenaz → espiral; titanio, segmentada en diente de sierra (Komanduri y von Turkovich, *Wear* 69, 1981) → rizada;
  latón de corte libre (CuZn39Pb3), corta y quebradiza por el plomo (guías de mecanizado de la Copper Development
  Association) → astillada. Madera, plástico, piedra y vidrio: **estimación**.
- **Color de revenido:** temperaturas de la tabla clásica de colores de revenido del acero al carbono (220 °C
  pajizo, 255 °C marrón, 275 °C púrpura, 295 °C azul oscuro, 310 °C azul claro, 330 °C gris azulado; Machinery's
  Handbook, y Wikipedia «Tempering (metallurgy)»). Los RGB son una aproximación visual: **estimación**. Inoxidable,
  titanio y níquel toman los mismos colores 100, 150 y 120 °C más arriba: **estimación**. Aluminio, latón,
  fundición y no metales no toman color.
- **Temperatura de la viruta según vc:** T = 20 + 280·√(vc/200) °C, calibrada con la regla de taller «con metal duro
  a la vc recomendada para acero (≈ 200 m/min) la viruta sale azul; con acero rápido (≈ 30 m/min), sin color».
  **Estimación**: la temperatura real depende también del avance, del material y de la herramienta.
- **Balística:** sale de la punta a vc/ζ (ζ = razón de compresión de la viruta, de 1 a 2,6 según el material:
  **estimación** de orden de magnitud), con dispersión, gravedad, frenado del aire 1,8 s⁻¹ (**estimación visual**) y
  giro. Se queda en la superficie más alta que tenga debajo (torreta, charriot, carro transversal, carro,
  delantal, bancada) o en la bandeja; las que caen sobre el carro viajan con él.
- **Caudal dibujado:** una viruta dibujada representa un trozo; el caudal crece con las rpm y con la potencia de
  corte (**estimación visual**).
- **Determinismo:** todo el azar sale de `core/shared/rng.gd` con semilla de texto; mismas llamadas, mismas virutas.

## Escena (`lathe_3d.tscn`)

- **Máquina procedural** (sin nada descargado): torno paralelo de 360 mm de volteo (180 mm de altura de puntos),
  plato de 3 garras de Ø200 con garras duras escalonadas, contrapunto con punto giratorio, carro con delantal y
  volantes, carro transversal, charriot, torreta cuadrangular de 85 mm, portaherramientas PCLNR 2020 y plaquita
  CNMG 120408 (designación ISO 1832: 80°, 12,7 mm de círculo inscrito, 4,76 mm de espesor, rε = 0,8 mm) con la punta
  teórica donde dice CONTRATOS.md (centro del radio en (rε, rε)). Husillo de roscar, barra de cilindrar, bandeja de
  virutas, protección trasera, lámpara de máquina, manguera articulada de taladrina. Proporciones: **estimación** de
  un torno de taller de FP.
- **Efecto estroboscópico controlado:** a 1200 rpm y 30 fotogramas/s el plato gira 240° por fotograma y, con tres
  garras, parecería quieto o marcha atrás (efecto carro de diligencia, el mismo que en un taller con fluorescentes
  hace que un plato en marcha parezca parado: INSST, NTP 211 «Iluminación de los centros de trabajo»). Por encima de
  18° por fotograma la velocidad aparente se frena a 0,35 vueltas/s en el sentido real y se dibuja un rastro
  translúcido de las garras en el arco que barrerían: a rpm altas se ven como un anillo borroso.
- **Refrigerante** (solo visual): taladrina (emulsión de aceite soluble, blanca lechosa; INSST, NTP 317 «Fluidos de
  corte») con un chorro desde la tobera y salpicaduras en la punta (GPUParticles3D).
- **Luz y entorno:** cielo procedural de nave de taller (techo con luminarias lineales, paredes con ventanal, suelo
  de hormigón) que da el fondo y los reflejos del metal; sol direccional con sombras; lámpara de máquina con
  sombras; ReflectionProbe en Forward+ y Mobile. En Compatibility la sonda sale negra (Godot 4.7.2 con OpenGL por
  software), así que allí se apaga.
- **Cámara orbital:** arrastrar para girar, rueda o pellizco para acercar, botón central o Mayús para desplazar.

## Demo (`demo_torno3d.tscn`)

Fuente simulada (`lathe3d/demo_source.gd`) sobre la pieza A de CONTRATOS.md (C45E, bruto Ø50 × 85, 25 mm en el
plato): refrentado, cuatro pasadas de desbaste (f = 0,4 mm, Ra 6,3 µm), medición intermedia (todo en ámbar),
acabado del contorno (f = 0,15 mm, Ra 0,9 µm, con taladrina), pulido con tela abrasiva del Ø40 (Ra ≈ 0,2 µm:
**estimación**) e inspección. Para enseñar el rojo, el Ø30 h9 se acaba a Ø29,92 (corrector de desgaste mal
introducido). El tiempo va acelerado unas 8 veces; la potencia que se muestra es Pc = kc·Q con kc = 2000 N/mm²
(**estimación** de orden de magnitud para el C45) y el volumen realmente arrancado. Argumentos para capturas:
`--at=<s>`, `--view=<nombre>`, `--overlay=<capa>`, `--orbit=<elevación>,<distancia>`.

## Tabla de estimaciones

| Dato | Valor | Por qué es estimación |
|---|---|---|
| Ra → rugosidad GGX | curva 0,1 µm → 0,06 … 12,5 µm → 0,53 | correspondencia visual, sin medición BRDF de superficies torneadas |
| Suavizado de las crestas dibujadas | 70 % de la pendiente teórica | el redondeo real depende del material y del filo |
| F0 de latón, inoxidable y fundición; aspecto del bruto | ver `WORK_LOOKS` | no están en la tabla de Hoffman |
| Colores RGB de revenido y su desplazamiento en inox, Ti y Ni | ver `Chips.TEMPER` | los colores son de interferencia; las temperaturas del inox, Ti y Ni varían con la aleación |
| Temperatura de la viruta según vc | 20 + 280·√(vc/200) °C | regla de taller, no un modelo térmico |
| Razón de compresión ζ, frenado del aire, caudal dibujado | ver `Chips.KINDS` | órdenes de magnitud para la animación |
| Formas de viruta de madera, plástico, piedra y vidrio | ver `Chips.KINDS` | sin fuente de clasificación |
| Dimensiones de la máquina (salvo la plaquita) | ver `machine.gd` | proporciones de un torno de FP típico |
| Ra del bruto (25 µm), del pulido (0,2 µm) y kc del C45 en la demo | ver `demo_source.gd` | valores de orden de magnitud para la demostración |

## Para el coordinador

1. **Avance por anillo.** Las marcas de avance deducen f de Ra. Si el núcleo del torno (unidad 3) publicara
   `ring_feed: PackedFloat32Array` (mm/vuelta de la última pasada de cada anillo), la escena usaría el f real de cada
   zona; hoy solo hay `set_feed(f)` global.
2. **Plano → banda de tolerancia.** La capa de desviación espera `{z0, dz, r_min, r_max}` por anillo. La unidad del
   plano (5) puede generarla o usar `LatheMesh.band_from_segments` (tramos rectos: cilindros, conos, chaflanes).
   Los radios de acuerdo (el R2 cóncavo de la pieza B) aún no están soportados en esa función.
3. **`tool_pose()` en el contrato.** La escena lee la punta de la fuente si la ofrece; convendría fijarlo en
   CONTRATOS.md (o derivarla del IR del intérprete Fagor).
4. **CUSTOM0.w** deja de estar reservada: lleva el semiancho de la tolerancia (ver arriba).
5. **Tests de virutas.** Están en `tests/taller/test_lathe_mesh.gd` porque el encargo solo permitía ese archivo de
   tests; se pueden mover a `test_chips.gd`.
6. **Sonido (unidad 8).** `tool_tip_global()` da `tool_pos` y `cutting_speed()` la vc de la entrada de sonido.
7. **Integración en la interfaz.** La escena pone MSAA 4× en su viewport (`msaa`); dentro de la app conviene
   montarla en un `SubViewport`. En móvil: `configure_lod(32, 800)`.
8. **Compatibility.** Sin ReflectionProbe (sale negra) ni anisotropía; el resto del acabado se ve igual. Forward+ no
   se ha podido comprobar a ojo en la nube (solo hay OpenGL por software).
