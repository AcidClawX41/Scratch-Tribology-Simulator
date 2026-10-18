# Materiales de las garras · color, brillo y luz de cada material (laboratorio 2.0, unidad 5e)

> **Unidad 5e.** Los datos ópticos con fuente en `godot/core/lab/claw_optics.gd` (`ClawOptics`, tests
> `tests/lab/test_claw_optics.gd`) y una sola biblioteca de materiales en `godot/app/common/` (`claw_material.gd`, el modelo
> de sombreado `claw_material.gdshaderinc`, los sombreadores `claw_solid.gdshader` y `claw_gem.gdshader` y la malla
> `claw_geo.gd`, tests `tests/app/test_claw_material.gd`), que usan la cetrería (`lab/cetreria/claw_look.gd` y
> `keratin.gdshader`), el coche en marcha (`lab/animals/animal3d.gd`) y la galería (`lab/demo_materiales.tscn`).

**Petición 33 de Eric (03-10-2026):** «Cada material en el que se quiera reflejar una garra con un material distinto deberá
mostrar su color real, tipo de iluminación y brillo que se le dé: el rubí será rojizo, el acero brillante como el titanio,
el diamante, la moissanita y demás igual, cada material milimétrico, preciso y detallado.» **Petición 36:** las texturas,
los materiales y los reflejos de cada garra, con la vista «La garra» de la Beta 2 como referencia (las garras oscuras y
brillantes de cerca y la carne viva al trasluz). **Petición 37:** que el material se degrade o se pula con cada pasada.

## 1. Qué se calcula y qué se dibuja

| Qué | Cómo | Tipo |
|---|---|---|
| El color del reflejo de cada metal (F0) | De su índice complejo medido n + ik (o de su reflectancia medida), R(λ) = ((n−1)² + k²)/((n+1)² + k²), integrado con las funciones CIE 1931 (ajuste de Wyman 2013), un cuerpo negro de 6504 K (D65) y la matriz de IEC 61966-2-1 | calculado |
| El índice de cada gema y vidrio, por canal y por rayo | Su fórmula de dispersión medida (Sellmeier o Cauchy) en la longitud de onda de cada canal (el centroide de su función de igualación) | calculado |
| El reflejo de Fresnel, el ángulo crítico y el «fuego» (dispersión B–G, n(486,1 nm) − n(656,3 nm)) | De esos índices | calculado |
| El color de lo transparente (rubí, zafiro, vidrio) | Absorción por mm de cada canal (Beer–Lambert), ajustada a lo medido | calculado |
| La rugosidad de cada acabado | σ (µm) de cada proceso, con su fuente; la fracción especular, exp(−(4πσ/λ)²) | calculado |
| La rugosidad de Godot de cada σ | De espejo (5 nm) a mate (micras), en escala logarítmica | dibujo |
| Las facetas de una talla, las rayas de la herramienta, las mellas, el polvo del limado, el hollín | Su forma y su tamaño | dibujo |
| El color de la queratina de cada especie | `KERATIN_COLORS`, con fuente o como estimación (§4) | dato o estimación |
| Las líneas de crecimiento, las capas del estuche y las estrías de la queratina | Ruido procedural, sin descargas | dibujo |
| El entorno dentro de las gemas | El mismo dibujo que los cielos de la nave del taller y de la carretera, evaluado en el sombreador | dibujo |

Lo que no se predice: la talla real de una gema (sus ángulos de corona y pabellón son los de una talla típica, ~30° y ~38°);
la luz que se esparce dentro de la queratina (la translucidez es la de la 5c, un alfa que deja ver la carne viva); el color
de un metal a más de ~600 °C (la reforja, «oxidado», usa un color de óxido dibujado); los colores de interferencia de una
capa fina.

## 2. Tabla de los datos ópticos (valor → fuente → tipo)

F0 en sRGB lineal (el reflejo a incidencia normal, el «color» de un metal); n_d a 589 nm; fuego = dispersión B–G; absorción
por mm en los canales rojo, verde y azul. Las fuentes completas, con su doi, están en `claw_optics.gd` (constantes `SRC_*`)
y cada valor lleva su `source` y su `quality`.

| Material | F0 (R, G, B) | n_d | Fuego | Birref. | Ángulo crítico | Absorción (1/mm) | Fuente | Tipo |
|---|---|---|---|---|---|---|---|---|
| Queratina | (0,046, 0,047, 0,048) | 1,549 | 0,019 | — | 40,2° | — | Leertouwer et al. 2011 (queratina β de pluma) | secundario |
| Oro | (1,000, 0,733, 0,366) | — | — | — | — | — | Johnson & Christy 1972, n y k | primario |
| Acero inoxidable | (0,668, 0,639, 0,598) | — | — | — | — | — | Karlsson & Ribbing 1982 (inoxidable austenítico, n y k de su figura) | secundario |
| Titanio | (0,617, 0,580, 0,542) | — | — | — | — | — | Johnson & Christy 1974, n y k | primario |
| Carburo de tungsteno | (0,472, 0,479, 0,469) | — | — | — | — | — | Chono et al. 2025 (WC pulido: R ≈ 0,47-0,48) | estimación (reflectancia de figura) |
| Hematites | (0,264, 0,287, 0,316) | — | — | — | — | — | Handbook of Mineralogy, R1-R2 de 400 a 700 nm | primario |
| Vidrio (strass) | (0,043, 0,043, 0,044) | 1,523 | 0,014 | — | 41,0° | (0,014, 0,005, 0,005) | Rubin 1985 (vidrio sodocálcico, n y k): el verde del canto | estimación (el strass como vidrio de ventana) |
| Cristal Swarovski | (0,046, 0,047, 0,048) | 1,548 | 0,021 | — | 40,2° | — | Schott LLF1 y la Directiva 69/493/CEE (cristal al plomo, n_D ≥ 1,545) | estimación |
| Cuarzo | (0,046, 0,046, 0,047) | 1,544 | 0,013 | 0,0091 | 40,4° | — | Ghosh 1999 (rayos o y e) | primario |
| Circonita | (0,134, 0,136, 0,140) | 2,159 | 0,060 | — | 27,6° | — | Wood & Nassau 1982 | primario |
| Zafiro azul | (0,077, 0,077, 0,079) | 1,768 | 0,018 | −0,0081 | 34,4° | (0,123, 0,095, 0,030) | Malitson & Dodge 1972 (n); Dubinsky et al. 2020 (sección eficaz Fe²⁺-Ti⁴⁺) | primario (n), estimación (concentración) |
| Rubí | (0,077, 0,077, 0,079) | 1,768 | 0,018 | −0,0081 | 34,4° | (0,093, 0,564, 0,280) | Malitson & Dodge 1972 (n); Yuan et al. 2022 (color CIE L*a*b* a 1, 5 y 10 mm) | secundario |
| Alúmina | (0,077, 0,077, 0,079) | 1,768 | — | — | — | — (blanca difusa) | el índice del corindón; blanca por dispersión (Gilshtein et al. 2021) | estimación |
| Moissanita | (0,204, 0,206, 0,213) | 2,648 | 0,104 | 0,043 | 22,2° | — (corte a 425 nm) | Nassau et al. 1997 | primario |
| Diamante | (0,172, 0,173, 0,176) | 2,417 | 0,044 | — | 24,4° | — | Peter 1923 (Sellmeier), como el Handbook of Mineralogy | primario |
| Nitruro de titanio (capa) | (0,660, 0,412, 0,150) | — | — | — | — | — | Schnabel et al. 2018, n y k | secundario |
| Cromo duro (capa) | (0,550, 0,556, 0,554) | — | — | — | — | — | Johnson & Christy 1974, n y k | secundario |
| Zafiro incoloro (Verneuil) | (0,077, 0,077, 0,079) | 1,768 | 0,018 | −0,0081 | 34,4° | — | Malitson & Dodge 1972 | primario |
| Acrílico dental (PMMA, 5p) | (0,039, 0,039, 0,040) | 1,4905 | 0,016 | — | 42,1° | — (cuerpo de color diente, `scatter` 0,85) | Sultanova et al. 2009 (n del PMMA); color y `scatter`, dibujo | primario (n), dibujo (color) |
| Resina fotopolimerizable (5p) | (0,039, 0,039, 0,040) | 1,4905 | 0,016 | — | 42,1° | — (marfil translúcido, `scatter` 0,5) | el PMMA como caso medido más parecido; color y `scatter`, dibujo | estimación (n), dibujo (color) |

El F0 del diamante (0,172) pasa del máximo del `SPECULAR` de Godot (F0 = 0,16·s², recortado a 0,16): su reflejo exterior
se queda un 7 % corto; su brillo de verdad sale de la reflexión total de dentro, que se calcula.

## 3. Los acabados

| Acabado | σ (µm) | Fuente | Tipo |
|---|---|---|---|
| Pulido | 0,005 | por debajo de los ~20 nm rms del microrrectificado con diamante, que ya es especular (Lambropoulos et al. 1996) | estimación |
| Tallado, astillado | 0,008 × grano (91 µm de las muelas de la reforja → 0,73) | σ ≈ 0,8 % del grano: el caso medido más parecido, el microrrectificado de vidrio (Lambropoulos et al. 1996) | estimación |
| Limado | 0,008 × grano de la herramienta (`ClawOptics.tool_grain_um`: el grano, o 10 000/dientes por cm en las limas) | ídem | estimación |
| En bruto, poroso, quemado, oxidado, defectuoso | 3,0 | colado o sinterizado: Ra 1,6-3,2 µm (ASME B46.1 en el Machinery's Handbook; σ ≈ 1,25·Ra) | estimación |
| Mellado, agrietado | 0,005 (pulido, con mellas o grietas) | ídem que pulido | estimación |

La fracción especular que deja cada σ es la de Bennett & Porteus 1961. La reforja dice el acabado (`ClawForge.result_claw().finish`:
`ClawOptics.finish_from_forge`); la cetrería, la última herramienta que mordió (`finish_from_care`) y, por estación, la
superficie de cada pasada (§6).

## 4. El color de la queratina de cada especie

| Especie | Color | Fuente | Tipo |
|---|---|---|---|
| Águila real | #2E2A26 | Kirschbaum & Ivory 2002, Animal Diversity Web: «The bills and claws are black» | secundario |
| Arpía, halcón, búho | #3A3530, #5A5048, #4A4034 | caso documentado más parecido: el águila real, de garras negras | estimación |
| Lechuza, buitre | #C8B090, #6B5A45 | el color de la ficha del banco | dibujo |
| Tigre | #D9C49E (cuerno claro, con la carne viva rosada a trasluz) | caso documentado más parecido: el gato doméstico (WSU Veterinary Teaching Hospital) | estimación |
| Oso pardo | #46392E (pardo oscuro, lo que pide la petición 36) | varía de un oso a otro (Montana FWP, identificación de osos) | estimación |
| Casuario | #3A3431 | sin color publicado de la daga: el del modelo del coche (la ficha del banco pinta el ave entera de azul) | dibujo |
| Velocirraptor | #4A3F35 | la queratina no fosiliza: sus parientes vivos, las rapaces, de garras negras | estimación |
| Velocirraptor de cine | #6B5B3E | diseño original | dibujo |

Es la única fuente del color: la cetrería (el color de `ClawCare`, el del catálogo, coincide), el coche en marcha
(`Animal3D.claw_natural`) y la galería leen `ClawOptics.keratin_color(id)`.

## 5. Cómo se pinta cada familia (claw_material.gdshaderinc)

- **Metal y mineral opaco:** metálico, con `ALBEDO` = su F0 y la rugosidad de su acabado; el reflejo es el del sitio (el
  cielo o la sonda de reflexión de la escena). Lo quemado en la cetrería deja hollín; el óxido solo lo pone la reforja.
  **Desde la unidad 5q (petición 56):** el reflejo de Godot solo trae el cielo de la escena (en Compatibility y Mobile no
  hay sonda, y en Forward+ la sonda no lleva las lámparas), así que el acero salía gris plano y el oro apagado. Un metal
  pulido suma el reflejo del entorno dibujado de la biblioteca (`claw_env_at`, el mismo que ven las gemas: la nave o la
  carretera, con sus lámparas, ventanas y paredes) en la dirección reflejada, teñido por su F0 con el Fresnel de Schlick
  (hacia el blanco en el borde), difuminado por su rugosidad y con un tope (1,8 veces el blanco) para que el tonemap no lave
  el color del oro en el reflejo de una lámpara. Las rayas, los poros, el óxido y el hollín lo apagan; por encima de la
  rugosidad 0,7 desaparece. Donde la sala ya tiene sonda (Forward+ en la cetrería), `claw_env_energy` baja a 0,35 en los
  metales (`ClawLook.METAL_ENV_WITH_PROBE`), para no sumar dos veces la sala. Es dibujo: el F0 y la rugosidad siguen
  siendo los medidos.
- **Gema y vidrio:** el reflejo exterior lo pone la luz de Godot con el F0 de su índice; lo que entra se refracta por canal
  (cada canal sale por otro sitio: el fuego), choca con la cara de atrás inclinada como el pabellón de una talla (~38°;
  ~12° en una garra lisa), rebota si pasa del ángulo crítico (el diamante y la moissanita brillan; el cuarzo y el vidrio
  dejan ver a través), se tiñe con Beer-Lambert por el camino dentro y sale al entorno. En el escritorio (`claw_gem`), lo
  que sale por detrás es lo que hay detrás en la pantalla, refractado; en el teléfono (`claw_solid`), el entorno dibujado
  y un solo rayo por canal. Los birrefringentes promedian sus dos rayos.
- **Cerámica (alúmina):** blanca difusa, algo translúcida en lo fino.
- **Polímero (acrílico dental y resina, unidad 5p):** un dieléctrico con el reflejo de Fresnel de su índice y un cuerpo
  translúcido de su color: los pigmentos y las cargas difunden una parte de la luz (`scatter`) y el resto pasa y sale con lo de
  detrás, refractado y borroso; más translúcido en lo fino; limado, blanquecino como el metacrilato esmerilado; quemado,
  pardo. Nunca lleva facetas (se moldea y se lima). La reforja (`look_view` da `acrilico` sin tinte) y la cetrería (el bloque
  de la prótesis) lo pintan desde la biblioteca.
- **El fuego (unidad 5p):** las facetas de una talla son planas de verdad (las tangentes salen del jacobiano de (s, a) en la
  pantalla, con el mismo sentido en OpenGL y en Vulkan: con el marco de Schüler cambiaban de signo y las facetas se curvaban),
  también a lo largo (con lo que gira la superficie por milímetro); cada faceta de delante deja ver un mosaico de las de atrás
  (triángulos, que se funden con la faceta de lejos); y dentro de la gema el entorno lleva los puntos de luz pequeños de la sala
  (bombillas y focos de 0,25-0,5°, de 18 a 45 veces el blanco; dibujo), que un canal alcanza y los otros no: un destello de
  color. La dispersión, el índice y la absorción medidos no cambian.
- **Queratina:** su color con las líneas de crecimiento, las capas del estuche y las estrías finas; la punta algo más
  clara; una capa de barniz (clearcoat) de la queratina pulida por el uso, que la herramienta raya y el calor quema; en la
  cetrería, translúcida en las garras claras, con la carne viva dentro (opacidad de la 5c).
- **Cada detalle más fino que un píxel se apaga** y pasa a rugosidad (sin muaré de lejos).

## 6. La superficie de cada pasada (petición 37)

El material lee la textura `surface_tex` que le pasa la escena con `ClawCare.snapshot().surface` (contrato «La cetrería en
alta definición y la superficie de la garra»): una columna por estación a lo largo de s, RGBA8, R = log₁₀(Ra/0,01 µm)/log₁₀(5000) (recortado a [0, 1]),
G = quemado, B = desconchón, A = dirección del rayado/180°, con `surface_range` = (0, largo en mm); (0, 0) = sin superficie,
la del acabado. Con σ ≈ 1,25·Ra: R da la rugosidad (de pulido espejo a mate) y la fuerza de las rayas en la dirección de
A; G oscurece hacia el carbón y apaga el brillo y el barniz; B rompe la normal en escamas concoideas. Una gema rayada se
vuelve lechosa. `ClawMaterial.surface_image(estaciones)` codifica, `set_surface(mat, textura, largo)` y
`clear_surface(mat)` la ponen y la quitan. Con 8 bits, R va de 0,196 en 0,196 µm de Ra: bien para la lima y la lija; un
pulido fino (Ra ≲ 0,1 µm) se lee como 0 o 0,196 (§9).

## 7. Integración

- `ClawMaterial.material(id, acabado, opts)` → `ShaderMaterial` de la caché: **una vez por clave** (material, acabado,
  calidad, entorno, color, superficie…), después se reutiliza; en cada fotograma no se crea nada (test). `opts`: `quality`
  («movil»: el sombreador opaco, sin leer la pantalla), `env` («taller» | «carretera»), `color` (la queratina), `apex_mm`,
  `facet_mm` (por defecto, un 20 % del largo), `seed`, `uv_mode` (1 para otra malla), `thick_mm`, `clear`, `surface`.
- `ClawMaterial.params(id, acabado, opts)` y `apply(mat, …)`: para un material propio (el de la cetrería).
- `ClawMaterial.for_forge(ClawForge.result_claw(), opts, variedad, grano)`: material y acabado de la reforja en una
  llamada, con la capa que se ve (TiN, cromo, alúmina porosa, diamante, esmalte) o, si es transparente, un barniz.
- La malla: UV.x = s (mm desde la base), UV.y = vuelta (0 arriba), UV2.x = radio (mm), UV2.y = largo de la garra (mm),
  como `claw_mesh.gd` de la cetrería y `ClawGeo`. Otra malla: `uv_mode` = 1.
- **Cetrería:** `ClawLook.params(material, color, { light, finished, other, surface, quality })`, `apply(mat, p)` y
  `apply_model(a3d, p)`, la API de la 5c; `keratin.gdshader` incluye el modelo y pone encima el calor, las grietas, las
  escamas, la sangre, el polvo, la crema y el resaltado.
- **Coche en marcha:** `Animal3D.set_claws(natural, material, color, entorno)` pone el material de la biblioteca (una copia
  por animal y material: el desvanecido `claw_fade` es suyo). Las garras de los modelos (`Rig3D.Model.claw`) salen de
  `ClawGeo.model_claw`: el largo y la curva de cada especie (los del catálogo), la sección de su dibujo y su ahusado, con
  las coordenadas en mm y la base cerrada dentro del dedo.
- Funciona igual en Forward+, Mobile y Compatibility (comprobado en Compatibility con las capturas). No usa `instance
  uniform`: reservan 16 huecos por malla en un búfer de 4096 en Compatibility y un animal lleva decenas de trozos de garra.

## 8. Coste

CPU por fotograma: **0** en la biblioteca (nada por fotograma; el aspecto se pone al cambiar de garra o de material). Pedir
un material ya hecho, ~18 µs (la clave); el aspecto de la cetrería (params + apply), ~80 µs; la malla de una garra del
coche, ~0,35 ms al construir el modelo, que se guarda en la caché. La pose de los animales del coche y la escena de la
cetrería cuestan lo mismo que antes (sus tests: 40-60 µs por animal; 1,8 ms de media la cetrería). GPU: solo los píxeles de
la garra; la gema del escritorio lee una copia de la pantalla (una por fotograma).

## 9. Pendiente y peticiones

- Unidad 5p: el arco de las garras del coche en marcha ya sale de `CareData.claw_arc` (`Mammals3D.claw_of`, que usan también
  las rapaces, y `Theropod3D.sickle_of`); el casuario sigue con su daga de 14° (`cassowary3d.gd`, que no era de la 5p).
- Hecho en la 5q (antes, pendiente de la 5p): el acero pulido se veía pardo y apagado en la cetrería porque la ventana del
  cielo de la sala quedaba por encima del techo (2,9-4,6 m con el techo a 2,6 m): el cielo de la sala (`workshop_sky`) tiene
  ahora la ventana donde la escena la pone (`window_bottom` y `window_top`; la cetrería, de 0,9 a 2,3 m), la sonda de
  reflexión vuelve a verse en la garra (`probe_on_focus`) y la reforja tiene un cielo más claro (techo 0,36-0,56-0,84 en
  vez de 0,13). Los metales suman además el reflejo del entorno dibujado (§5).

- La luz del sitio (5h): con el techo oscuro del cielo de la nave (0,13), el dorso pulido de un metal refleja casi negro;
  con un techo claro (~0,5, como en la galería) o una sonda de reflexión de la sala, el titanio y el acero brillan grises
  y el oro dorado (capturas de la prueba en el informe de la 5e).
- Hecho al unir la 5e: R va en escala logarítmica (de 0,01 a 50 µm, pasos de un 3,4 %), porque con R = Ra/50 en 8 bits
  todo lo que bajaba de 0,2 µm se leía como un espejo.
- Las curvas de cada garra: la cetrería y la galería usan 35° + 115°·curva y el coche 180°·curva^1,6; cuando la 5g ponga
  el arco medido de cada dedo en `claw_care_data.gd`, los dos (y `ClawGeo.spec_of`) deberían leerlo. Medidas que pueden
  servir: Fowler DW, Freedman EA, Scannella JB (2009), PLoS ONE 4:e7999, tabla S1 (el arco de los talones de cada dedo:
  águila real ~130°, halcón peregrino ~138°, el aura gallipavo ~82°).
