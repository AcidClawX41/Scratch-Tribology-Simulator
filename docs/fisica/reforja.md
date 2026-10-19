# Reforja experimental de garras · materiales, métodos y proceso (laboratorio 2.0, unidad 5d)

> **Unidad 5d.** Física, datos y tutoriales, sin interfaz: el motor `godot/core/lab/claw_forge.gd` (`ClawForge`), sus
> datos `claw_forge_data.gd` (`ForgeData`) y sus tutoriales `claw_forge_tutorial.gd` (`ForgeTutorial`), con los tests
> `tests/lab/test_claw_forge*.gd` y los casos de referencia `tests/fixtures/spec/reforja.json`. La escena 3D del horno, la
> muela y la funda la hará otra unidad, sobre la cetrería que rehace la 5c (§14, lo que necesita).

**Petición 31 de Eric (03-10-2026):** «Cada animal tiene que tener su modelo propio en 3D, su tipo de garra y material, y
luego la opción de reforzado, que será más experimental y algo más fantasiosa, para reforjar una garra con distintos
materiales más duros; bueno, reforjarla o cubrirla de un material distinto y más duro, como pueden ser minerales, que
tendrán que tallarse, calentarse en un mini fundidor industrial, y recubrirse. Investiga materiales y métodos si no sabes
cómo.»

**Petición 32:** «Un horno de taller industrial bueno será una parte más experimental y no tan verídica, pero me gustaría
que fuera lo más realista posible, y que el usuario aprendiera también a mezclar polvos, sintetizarlos, inducción y
fundición; por ejemplo, un horno propio de calor y presión que, ajustándolo a los parámetros correctos y echando polvo de
óxido de aluminio, puedas crear zafiro, un poco a lo Minecraft, pero versión más real; y cuando lo creas, cubrir la parte de
la carne viva para que no se queme ni se fusione, recubrir las garras con ese material, y pulirlas con las herramientas y
durezas adecuadas.» Y después: «añadir también un tutorial bien hecho, que explique cómo funcionan los botones y
parámetros a aplicar de ese horno industrial, y qué polvo y material coger para lograr ese X material a hacer».

**Petición 33 (aviso para la 5e):** cada material tendrá su color, su brillo y su luz en 3D (`core/lab/claw_optics.gd`, de
la 5e). Esta unidad da ids estables (los de `Data.INLAYS` cuando existen; `rubi` y `alumina`, nuevos de la 2.0) y el
**acabado** de la pieza (§9); los datos ópticos son de la 5e.

## 1. Resumen

Una garra «reforjada» de verdad no se reforja: la garra viva no aguanta el calor. Lo que se puede hacer es una **funda**
aparte, del material que se quiera, y **pegarla en frío**, como una corona dental o la prótesis del pico de una rapaz. El
motor sigue ese proceso por etapas, cada una con sus parámetros y su resultado, y lo que en la realidad no se hace (recubrir
la garra en el animal, verter un material fundido encima, un horno que lo hace todo) va marcado como **ficción**
(`quality: "ficcion"`), con lo que pasaría de verdad.

1. **Material:** una receta del horno (zafiro, rubí, metal duro, alúmina, acero, oro, titanio, vidrio, diamante HPHT y
   CVD) o una piedra comprada (cuarzo, circonita, moissanita, hematites, cristal); para una garra rota, también el acrílico
   dental, la prótesis de verdad (§15.1).
2. **Horno:** modo, temperatura, tiempo, atmósfera, presión y molde frente a la receta y a los datos del material: con los
   parámetros correctos sale el material; fuera de su margen sale poroso, sin fundir, quemado o con defectos, y el motor
   dice por qué.
3. **Enfriar:** choque térmico (Kingery, con el factor de Manson); el vidrio se recuece; el cuarzo no cruza 573 °C deprisa.
4. **Tallar:** el abrasivo tiene que ser más duro; arranque de Archard grano a grano; régimen dúctil (Bifano); desconchado
   del borde (Chai y Lawn); con agua.
5. **Proteger la carne viva y recubrir:** la funda aparte (real) o la garra viva (ficción, con el calor por dos vías hasta la
   carne viva).
6. **Unir en frío:** el adhesivo o la queratina, el que aguante menos, por la superficie pegada; la holgura que llena cada
   adhesivo.
7. **Pulir** con un abrasivo más duro (y afilar si se pide, con `ClawSharpness`).
8. **Comprobar** con la fuerza del animal. La garra resultante pasa al banco, al coche en marcha y a la cetrería con su
   material, su dureza, su módulo, su resistencia, su masa, su afilado y su acabado.

## 2. La regla de oro: la garra viva no aguanta el calor

- La queratina se desnaturaliza y se quema hacia los 215-255 °C: la de la pezuña de vaca a ~215 °C (Kakkar et al. 2014) y
  las queratinas α entre 230 y 255 °C (Wortmann et al. 2012). La cetrería ya lo usa como tope (`CareData.THERMAL.char_c`,
  230 °C). La carne viva duele desde ~43 °C y se lesiona con el tiempo a cada temperatura (Moritz y Henriques 1947: 50 °C
  en 5 min, 60 °C en 5 s, 70 °C en 1 s).
- Por eso lo que se hace de verdad es en frío:
  - **coronas dentales**: la funda se hace aparte (colada a la cera perdida, fresada o sinterizada) y se cementa;
  - **prótesis y reparaciones del pico** de las rapaces, con metacrilato y bicarbonato, rehechas cada 8-12 semanas porque la
    queratina crece (Samour 2006);
  - **herraduras pegadas** al casco con adhesivos acrílicos: en las uniones acero-casco «la rotura ocurre siempre en el
    casco», no en el adhesivo (Ferreira et al. 2024).
- **Ficción:** recubrir la garra en el animal. El motor calcula lo que pasaría (§6) y lo marca.

## 3. Cómo se hace cada material

### 3.1 El horno-fundidor del taller (ficción en conjunto) y sus mandos

Ninguna máquina de taller hace todo esto: el horno es **ficción en conjunto** (`ForgeData.FURNACE`). Cada modo es una
máquina industrial real, con sus temperaturas, presiones y atmósferas de verdad: horno de mufla o de vacío, horno de
inducción, fundición, sinterizado y crecimiento de cristales (el soplete de Verneuil, la prensa HPHT y el reactor de CVD).

| Mando (`ForgeData.CONTROLS`) | Unidad y rango | Qué hace | Por qué importa |
|---|---|---|---|
| Modo | calentar · inducción · fundir y colar · sinterizar · sintetizar | elige la máquina | cada material se hace de una forma: el oro se cuela, el metal duro se sinteriza, el zafiro y el diamante se cultivan |
| Temperatura | °C, 20-3000 | la de la carga | por debajo de su punto no pasa nada; en el margen sale bien; por encima, defectos |
| Tiempo | s, hasta 1000 h | lo que se mantiene o crece | sinterizar es difusión (horas); un cristal crece a un ritmo (mm/h, mg/h, µm/h) |
| Atmósfera | aire · argón · vacío · hidrógeno con metano | el gas alrededor | el aire quema el diamante (~600 °C), oxida el metal duro (~540 °C) y contamina el titanio fundido |
| Presión | MPa, 0-6000 | la de la prensa | solo el diamante HPHT: estable por encima de la línea de Kennedy, P (kbar) = 19,4 + T/40 |
| Metano (CVD) | %, 0-20 | el metano en el hidrógeno | con 0,1-10 % crece diamante; con menos no llega carbono; con más, hollín |
| Molde | yeso · cáscara cerámica · grafito | dónde se cuela | el yeso no pasa de ~816 °C: vale para oro y vidrio, no para acero ni titanio |
| Enfriar | dentro del horno · aire · aceite · agua | cómo se saca | lo frágil se agrieta si el salto pasa del que aguanta; el vidrio se recuece |

### 3.2 Recetas por material objetivo

Cada receta (`ForgeData.RECIPES`; `ClawForge.recipes()` para pintarlas) lleva los polvos en fracción de peso, el modo, la
temperatura, el tiempo, la atmósfera, la presión y, si hace falta, el molde y el metano, cada uno con su margen bueno y lo
que sale si te pasas o te quedas corto (`low`/`high`: código, texto y acabado), y cómo enfriar.

| Receta | Polvos | Modo | Temperatura (margen) | Tiempo | Atmósfera · presión | Enfriar | Fuente |
|---|---|---|---|---|---|---|---|
| Zafiro (Verneuil) | Al₂O₃ ≥ 99,97 % | sintetizar | 2100 °C (2053-2200) | lo que crece la bola a ~10 mm/h | aire (llama de O₂ e H₂) · sin prensa | aire u horno | Saint-Gobain; Scheel 2000; The Gemology Project |
| Rubí (Verneuil) | Al₂O₃ + 1 % Cr₂O₃ (0,03-5 %) | sintetizar | 2100 °C (2053-2200) | ~10 mm/h | aire | aire u horno | Roditi (0,03-0,05 % en láser); How Products Are Made (~5 % en joyería) |
| Metal duro | 94,5 % WC + 5,5 % Co (±1) | sinterizar | 1420 °C (1350-1500) | ≥ 1 h | vacío o argón | horno | General Carbide; Fernandes y Senos 2011 |
| Alúmina sinterizada | Al₂O₃ + 0,25-0,5 % MgO | sinterizar | 1850 °C (1700-1950) | 24 h a 1700 °C … 6-8 h a 1900 °C | vacío | horno | Coble, US 3.026.210; CoorsTek AD-995 |
| Acero (inducción) | chatarra de 304 | inducción | 1525 °C (1500-1550) | ≥ 5 min | aire, argón o vacío · molde cerámico | agua | AK Steel 304; colada del CF8 |
| Oro (cera perdida) | oro fino | fundir y colar | 1150 °C (1094-1164) | ≥ 2 min | aire · yeso | agua | ITS-90; Ganoksin |
| Titanio | grado 2 | fundir y colar | 1720 °C (1698-1768) | ≥ 2 min | argón o vacío · grafito | aire | CRC; capa alfa (Chan et al. 2008) |
| Vidrio colado | vidrio de fundir | fundir y colar | 830 °C (800-843) | ≥ 3 h | aire · yeso y sílice | horno (recocido) | Bullseye Glass, Tip Sheet 8 |
| Diamante HPHT | 30 % grafito + 70 % Fe-Co(-Ti) | sintetizar | 1345 °C (1300 a la línea de Kennedy) | lo que crece a 6-8 mg/h (días) | cápsula cerrada · 5,5 GPa | horno | Sumiya et al. 2002; Kennedy y Kennedy 1976; Balmer et al. 2009 |
| Diamante CVD | CH₄ en H₂ (0,1-10 %) | sintetizar | 900 °C (700-1300), sobre un molde de Mo, W, Si o Ti | lo que crece la pared a 50-150 µm/h | H₂ + CH₄ · baja presión | horno | Balmer et al. 2009; Yan et al. 2002 |

Lo que sale fuera de margen, por ejemplo: alúmina que no funde a menos de 2053 °C (una costra blanca y porosa sobre la
semilla); metal duro sin fase líquida por debajo de ~1350 °C (poroso) o quemado al aire; oro que no llena el molde sin
30-100 °C por encima del líquido, o con rechupes y poros si se calienta de más; acero que quema el yeso; titanio fundido al
aire (capa alfa, quemado); diamante HPHT por encima de la línea de Kennedy (grafito) o con poca presión; CVD al aire (se
quema lo que crece) o con demasiado metano (hollín).

### 3.3 Lo que no se funde en un horno de taller

- **Oro** (1064,18 °C, ITS-90): un horno de joyero basta, y no se oxida.
- **Acero** (304: 1399-1454 °C): un horno de joyero no llega; se funde por inducción y se cuela en un molde cerámico.
- **Titanio** (1668 °C): al aire o en un molde de óxidos coge oxígeno y forma la capa alfa, dura y frágil; se funde con arco
  en argón o en vacío.
- **Carburo de tungsteno:** no se funde; se prensa polvo de WC con cobalto y se sinteriza en fase líquida a 1350-1500 °C en
  vacío (encoge ~20 %; Fernandes y Senos 2011). Al aire se oxida desde ~538 °C (General Carbide).
- **Zafiro y rubí** (2053 °C): no se funden en un horno de taller; se cultiva el cristal desde el fundido (Verneuil,
  Kyropoulos, Czochralski).
- **Diamante:** se oxida al aire desde ~600 °C (KAPP) y hacia 700-800 °C se le forman hoyos de grafito que se queman (2024,
  Glass Phys. Chem.); a baja presión la superficie se grafitiza ya por debajo de ~1700 °C por el oxígeno que queda
  (Khmelnitsky y Gippius 2014): el motor toma 1500 °C en vacío (estimación). Se sintetiza a alta presión (HPHT) o en
  plasma (CVD).
- **Circonita** (ZrO₂ estabilizada, ~2750 °C): fusión en cráneo por radiofrecuencia (Nassau 1981). **Moissanita** (SiC):
  no funde, se disocia hacia los 2700 °C; se cultiva por sublimación a 2300-2500 °C en argón. Se compran.
- **Cuarzo:** la inversión α-β a 573 °C (0,45 % de dilatación) lo agrieta si se cruza deprisa (Johnson et al. 2021).
- **Vidrio:** se reblandece desde ~726 °C (Abrisa); se cuela en el horno a ~830 °C y se recuece despacio.
- **Esmaltes vítreos:** vidrio en polvo fundido sobre metal a 750-850 °C. **Recocido** del 304: 1038-1121 °C y
  enfriamiento rápido; el 304 no se templa (no endurece por temple). Cascarilla al aire por encima de ~899 °C (816 °C en
  servicio intermitente).

### 3.4 Piedras compradas

`choose(material)`: un bloque comprado del que se talla la funda (cuarzo, circonita, moissanita, hematites, cristal y
cualquiera del banco). No necesita horno, y el calor la estropea; el modo «Calentar» (`heat`) enseña qué le pasaría.

## 4. Enfriar: el choque térmico

- **Salto que aguanta una pieza frágil** con un enfriamiento brusco (Kingery 1955): ΔT = σ_f·(1 − ν)/(E·α), con la
  resistencia a flexión de `claw_fracture.gd`, el módulo del banco, ν = 0,3 (el del motor) y la dilatación de cada material.
- **Con un enfriamiento finito**, la tensión es ψ veces la del salto brusco (Manson 1966, recogido por Lu y Fleck 1998):
  1/ψ = 1,5 + 3,25/β − 0,5·e^(−16/β), β = h·a/k (h: convección; a: medio espesor; k: conductividad). El salto que aguanta es
  ΔT/ψ. Dentro del horno no hay choque; un metal no se agrieta por choque (cede).
- **Coeficientes de convección:** el aire, 15 W/(m²·K) (Incropera, el de la cetrería); el **agua, 8·10⁴, calibrado** con la
  alúmina: una probeta de 3 mm templada en agua aguanta un salto medido de 170-300 °C (Morgan Technical Ceramics, método de
  Hasselman) y con h = 8·10⁴ el modelo da 201 °C (dentro de la banda de la ebullición de Incropera, 2500-100 000); el
  **aceite, 2,3·10⁴**, el del agua por la relación de severidades de Grossmann (aceite 0,25-0,30; agua 0,9-1,0).
- El **vidrio** colado se recuece (Bullseye: 482 °C 6 h y luego 7-12 °C/h); enfriado fuera del horno desde más de su punto
  de recocido (546 °C) queda lleno de tensiones. El **cuarzo** no cruza 573 °C fuera del horno. La **bola de Verneuil** sale
  con tensión interna: se parte a lo largo antes de tallarla (aviso).

| Pieza | Brusco (K) | Aire | Aceite | Agua |
|---|---|---|---|---|
| Bola de zafiro de 13 mm a 2100 °C (salto 2080 °C) | 151 | ~2·10⁵: bien | 357: se agrieta | 242: se agrieta |
| Alúmina de 3 mm | 87 | — | — | 201 (medido 170-300) |
| Vidrio sodocálcico | 50 | — | — | — |

## 5. Tallar

- **El abrasivo tiene que ser más duro:** una lima solo marca lo que es más blando que ella (HolzWerken 2024). El motor usa
  la eficiencia de la dureza del banco (`Contact.hardness_efficiency`, Pintaude) y, además, cero si el abrasivo es más
  blando (`ClawForge.bite_efficiency`). Durezas de los granos del taller: corindón 2000 HV, carburo de silicio 2800, CBN 6322,
  diamante 10 000; la lima de acero, ~700 HV.
- **Arranque:** Archard grano a grano con la geometría de la cetrería (`ClawCare.element_cut`: grano de 60° con la punta de
  5 µm, toca el 10 %), ΔV/Δt = η·K·F·v/H, con la muela de serie (10 N, 20 m/s, contacto de 3 × 3 mm; estimación).
- **Régimen dúctil** (Bifano et al. 1991): por debajo de d_c = 0,15·(E/H)·(K_c/H)² el grano arranca sin grietas. Zafiro,
  0,046 µm; metal duro, 0,86 µm; el grano de diamante de 45 µm con 10 N hunde ~0,07 µm.
- **Desconchado del borde** (Chai y Lawn 2007): una punta a d del borde lo desconcha con F = 9·K_c·d^(3/2). Con 1 mm de pared:
  vidrio 213 N, moissanita 512 N, zafiro 683 N.
- **Con agua:** en seco, una pieza frágil que conduce mal el calor (vidrio, cuarzo, circonita: k < 10 W/(m·K), regla del
  modelo) se agrieta, y la muela de diamante se quema (se oxida por encima de 600 °C, KAPP).
- **La muela contra el acero:** el diamante y el carburo de silicio reaccionan con el hierro en el contacto caliente y se
  gastan deprisa (KAPP; Komanduri y Shaw 1975; patente US 4.505.720): para el acero, CBN o corindón. El desgaste en números
  (la relación G) no se modela: no hay una medición a mano para cada pareja.
- **Lo que se arranca:** de un bloque o una bola, el cilindro que contiene la funda menos la funda; de una pieza casi a su
  forma (colada, sinterizada o crecida sobre un molde), una piel de 0,1 mm (elección del ensayo).

| Funda del águila (14 mm de largo, 1 mm de pared) | Arranca | Tiempo con la muela de serie |
|---|---|---|
| Zafiro o rubí (de la bola) | 883 mm³ | 55 min (régimen frágil) |
| Diamante HPHT (del cristal) | 883 mm³ | ~140 h |
| Diamante CVD (piel) | 63 mm³ | ~10 h |
| Metal duro (piel) | 63 mm³ | 4 min |
| Alúmina (piel) | 63 mm³ | 2,3 min |
| Vidrio (piel) | 63 mm³ | 19 s |
| Acero (con CBN), titanio, oro (piel) | 63 mm³ | segundos |

## 6. Proteger la carne viva y recubrir

### 6.1 Barreras térmicas

| Barrera (`ForgeData.BARRIERS`) | k (W/(m·K)) | ρ·c | Aguanta | Fuente |
|---|---|---|---|---|
| Caucho de silicona | 0,2 | 1150 × 1175 | ~200 °C | Shin-Etsu; AZoM |
| Manta de aerogel | 0,024 (a 300 °C) | 200 × 1000 | 650 °C | Aspen Aerogels, Pyrogel XTE (calor específico estimado) |
| Gel de agua de joyero | 0,6 | 1000 × 4180 | no pasa de 100 °C mientras le queda agua (2257 kJ/kg) | Incropera; geles de joyero |

`ClawForge.barrier_heating(t, s, barrera, mm, pared)`: conducción en una dimensión, implícita (Euler hacia atrás y el
algoritmo de Thomas, como el modelo térmico de la cetrería), con la superficie a la temperatura del recubrimiento, la
barrera, la queratina (con la difusividad, la densidad y el calor específico de la cetrería: k = α·ρ·c = 0,200 W/(m·K)), 2 mm
de tejido vivo y la sangre a 32 °C detrás. Celdas de 0,05 mm (0,1 en el tejido vivo) y de 200 a 4000 pasos. Una barrera que no
aguanta la temperatura se descompone y deja la queratina al aire. En régimen permanente la temperatura cae en línea recta
con la resistencia en serie (caso de referencia).

### 6.2 Las dos vías del calor en la garra viva (ficción)

La barrera solo puede ir sobre la parte viva: para agarrar, la capa toca directamente la queratina. El calor llega a la carne
viva por dos vías (`live_paths`, `live_coat_heating`):

1. **Por la parte viva**, bajo la barrera: la pared más fina entre la capa y la carne viva.
2. **Por la punta muerta**, sin barrera: la capa calienta la queratina de la punta a su temperatura (si pasa de ~230 °C, se
   quema y la capa se funde con ella) y el calor viaja por dentro hasta la carne viva (la distancia en línea recta al final de
   la carne viva, como el flanco de la cetrería).

Así, una barrera nunca salva la garra de un recubrimiento caliente: la punta se quema igual. Cuanto más lejos de la carne viva
y menos tiempo, menos calor llega (en la queratina el calor avanza √(α·t): ~1,7 mm en 30 s, ~8 mm en 10 min). Con la alúmina
por plasma a ~150 °C sobre la garra del águila: 30 s sobre toda la funda llevan la carne viva a ~62 °C (al borde de la lesión);
10 min la lesionan; 30 s solo en la mitad de la punta muerta la dejan en ~35 °C (el tutorial de la ficción).

### 6.3 Recubrimientos

| Recubrimiento (`ForgeData.COATINGS`) | Temperatura de la pieza | Capa | Dureza | Dónde | Fuente |
|---|---|---|---|---|---|
| Alúmina por capas atómicas (ALD) | desde 33 °C | 1,107 Å por ciclo: 33 nm en 300 ciclos | sin dato | cámara de vacío; cualquier sustrato | Groner et al. 2004 |
| Alúmina por pulverización catódica | ≤ 250 °C (100 °C) | ~2 µm (estimación) | 12 GPa ≈ 1134 HV | vacío; cualquiera | Schneider et al. 1997 |
| Nitruro de titanio por PVD | 250-400 °C | 1-4 µm | 30 GPa ≈ 2835 HV | vacío; metales | Oerlikon Balzers, BALINIT A |
| Cromo duro galvánico | baño a 50-65 °C | 20-40 µm, ~25 µm/h | 750-1050 HV (900) | baño de ácido crómico con corriente; lo que no conduce, con pintura conductora antes | NEWMOA 2003; U.S. Chrome; ScienceDirect Topics; Gateros Plating |
| Alúmina por proyección de plasma | ~150 °C (estimación) | 200-500 µm, ~4 % de poros | ~950 HV | aire; metales | Mater. Charact. 2010; Mater. Des. 2004 |
| Diamante CVD | 700-1300 °C | ~20 µm | 10 000 HV | vacío; W, Ti, Mo, Si, diamante (no acero) | Balmer et al. 2009 |
| Esmalte vítreo | 750-850 °C | ~200 µm | ~550 HV (estimación) | aire; oro, acero, titanio | Andrews 1961 |
| Material fundido vertido encima | su fusión | — | la del material | **ficción** | — |

- **Una capa depositada no es zafiro:** sale amorfa (ALD, pulverización: 10-12 GPa) o policristalina y porosa (plasma); el
  zafiro es un monocristal que solo crece desde el fundido. Una capa gruesa de zafiro solo se puede hacer como funda aparte.
- **Regla de Bückle** (ISO 14577-4): la capa manda en el banco mientras la punta no se hunda más del 10 % de su espesor; más
  hondo, el sustrato (`benchDepthLimitUm`).
- En la funda (real): el recubrimiento tiene que agarrar en ese sustrato y la funda tiene que aguantar su temperatura (sin
  fundir, reblandecerse, oxidarse o grafitizarse). El **galvanizado** necesita una superficie que conduzca: sobre una piedra,
  una cerámica o la queratina, antes una pintura conductora de grafito, cobre o plata (Gateros Plating). En la garra viva
  sería, además, sumergirla con corriente en ácido crómico (cromo hexavalente, cancerígeno) durante horas. El calor del baño
  (55 °C, ~1 h para 30 µm) no la quema: la sangre a 32 °C se lleva el calor y la carne viva se queda en ~42 °C, por debajo del
  umbral del dolor; el peligro es químico, y el modelo no lo calcula.

## 7. Unir en frío

| Adhesivo (`ForgeData.ADHESIVES`) | Cortante (ISO 4587) | Holgura ideal · máxima | Mojado | Fuente |
|---|---|---|---|---|
| Cianoacrilato | 20 MPa en acero (12,4 en aluminio) | 0,05 · 0,15 mm | 75 % tras 1000 h | Henkel, LOCTITE 401 |
| Epoxi | 14,9 MPa (aluminio rugoso) | 0,10-0,15 · 3,2 mm | sin dato (1) | Henkel, guía de metales (E-20HP) y de estructurales |
| Metacrilato | 19,4 MPa (aluminio rugoso) | 0,25-1,0 · 12,7 mm | sin dato (1) | Henkel (H8000); prótesis de pico (Samour 2006) |

- **La queratina bajo la unión** aguanta σ/2 (Tresca) × 0,25 (la relación entre capas de la uña, Farren et al. 2004):
  8,6 MPa a la humedad natural y 1,75 MPa empapada (estimación). Es menos que los adhesivos: manda la queratina, como en las
  herraduras pegadas (rompe el casco, Ferreira et al. 2024).
- **Capacidad** = mín(adhesivo, queratina) × superficie pegada (la interior de la funda). Con más holgura de la que llena, el
  adhesivo no cura. Más superficie nunca aguanta menos (invariante).
- **Comprobar** (`check_load`): toda la fuerza de la ficha del animal tirando de la funda, como cortante sobre la unión
  (suposición).
- **Soldadura fuerte** (`bond({ adhesive: "soldadura_fuerte" })`): la aleación de plata funde a 618-652 °C (SAE AMS 4763) y la
  queratina se quema a ~230 °C: no pega una funda a una garra. Sirve para unir piezas de metal de la funda (una punta de metal
  duro sobre acero, como las plaquitas de las herramientas) antes de pegarla en frío.

## 8. Pulir y afilar

- Pulir pide un abrasivo más duro: la lima de acero resbala sobre el zafiro y sobre la alúmina por plasma (~950 HV); la pasta
  de diamante (45 → 9 µm, DMT) los pule.
- **Pulir no afila:** la punta sigue con su radio natural. Con `sharpen` la punta queda del radio de la arista o del grano
  (10 o 5 µm) y el afilado sale de `ClawSharpness` (la carga de lado que la mella crece con R², Pattrick et al. 2018).
- La garra sigue en la cetrería con `ClawCare.new(forge.care_setup())`, con el material por su propio id (unidad 5g): los de
  `Catalog.INLAYS`, los de la 1.x y los nuevos de la 2.0, el rubí y la alúmina (`ClawCare.supports_inlay`). Uno que la
  cetrería no conociera iría como queratina con `careSupported = false` y el porqué.
- **La garra rota** (petición 35, unidad 5g; `docs/fisica/cetreria.md` §11.8): `care_setup(ajustes de la garra rota con
  stump_mm)` devuelve, en cuanto la pieza (del horno o comprada) sale bien y se enfría, sin tallar, el muñón de queratina con
  un bloque en bruto del material pegado encima (`block`: el cilindro de la funda con su pared de sobra), que se lima en la
  cetrería con herramientas más duras que el material. Va marcado como **ficción** (`block.fiction`, con la nota): en la
  realidad la pieza se talla aparte y se pega terminada; en el animal solo se pega y se lima una prótesis de acrílico. Esa
  vía real está en el laboratorio desde la unidad 5j: con el acrílico dental el bloque no es ficción (§15.1). La prótesis
  se hace para la garra de su dedo y con lo que queda de ella (§15.3), y el calor de limar el bloque va por la conducción
  de su material (§15.2).

## 9. La garra resultante, los ids y el acabado

`result_claw()`: `inlay` (id del material: los de `Data.INLAYS` —`zafiro`, `diamante`, `tungsteno`, `acero`, `titanio`,
`oro`, `vidrio`…— o los nuevos de la 2.0, `rubi` y `alumina`), `inBench`, `benchTwin`, `hv`, `E`, `densityKgM3`,
`strengthMPa`, `kic`, `sheathMassKg`, `clawMassKg` (queratina + funda), `finish`, `coating`, `bond`, `tipRadiusUm`,
`sharpness`, `quality` y `fiction`. Los materiales nuevos tienen la forma de las entradas de `Data.INLAYS` (con `area` y
`alpha` de la incrustación, la del zafiro) y lo que piden `ClawMass`, `ClawFracture` y `ClawSharpness`
(`ForgeData.NEW_MATERIALS`).

**Acabado** (`ForgeData.FINISH_IDS`, para la 5e): `bruto` (como sale del horno o de la tienda), `tallado`, `pulido`, `poroso`,
`agrietado`, `astillado`, `quemado`, `oxidado` (cascarilla) y `defectuoso`. La capa lleva el suyo (la de plasma, `poroso`, y
su porosidad aunque se pula).

## 10. Tabla valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Queratina: se quema a ~230 °C (215-255) | Kakkar et al. 2014; Wortmann et al. 2012 (`CareData`) | caso parecido medido |
| Oro funde a 1064,18 °C; dilatación 14,2·10⁻⁶, k 317 | ITS-90; CRC Handbook | norma; libro |
| Acero 304: funde a 1399-1454 °C; cascarilla > 899 °C (816); α 17,3·10⁻⁶; k 16,2 | AK Steel, 304/304L | ficha |
| Titanio funde a 1668 °C; capa alfa al aire | CRC Handbook; Chan et al. 2008 | libro; artículo |
| Titanio: α 8,6·10⁻⁶, k 16,4, c 523 J/(kg·K) (unidad 5j) | ASM, titanio de grado 2 recocido (datos de Allvac) | ficha |
| Metal duro: se oxida > 538 °C; encoge ~20 %; α 4,6-5,0·10⁻⁶; k 60-80 | General Carbide; Goodfellow | ficha |
| Sinterizado del WC-Co a 1350-1500 °C en vacío; 1 h | Fernandes y Senos 2011; estudios de contracción | artículo; estimación (la hora) |
| Vidrio: reblandece a 726 °C, recuece a 546 °C; α 9·10⁻⁶; k 1 | Abrisa; EN 572-1 | ficha; norma |
| Colada de vidrio: 830 °C 3 h, molde que falla > 843 °C, recocido a 482 °C | Bullseye, Tip Sheet 8 | ficha |
| Cuarzo: inversión a 573 °C (0,45 %); α 7,1-13,2·10⁻⁶; k 6,2-10,7 | Johnson et al. 2021; Tydex | artículo; ficha |
| Circonita: funde a ~2750 °C; α 9-11·10⁻⁶; k 2,5-3,0 | Nassau 1981; recopilaciones de la YSZ (Hayashi et al. 2005) | artículo; estimación (α y k) |
| Zafiro y rubí: funden a 2053 °C; α 7,9-8,8·10⁻⁶; k 40; 760-1035 MPa | Saint-Gobain Sapphire | ficha |
| Moissanita: se disocia a ~2700 °C; crece a 2300-2500 °C; α 4,02·10⁻⁶, k 125,6 (del SiC sinterizado) | GRAYSTAR; JXT Semi; Hexoloy SA | ficha; caso parecido medido |
| Diamante: se oxida > 600 °C (600-700); α 0,9·10⁻⁶; k 1000-2200 | KAPP 2006; Glass Phys. Chem. 2024; Balmer et al. 2009 | artículo |
| Diamante: grafitiza en vacío > 1500 °C (1500-1700) | Khmelnitsky y Gippius 2014 (a baja presión, < 1700 °C por el oxígeno) | estimación |
| Alúmina sinterizada: 3,90 g/cm³, Knoop 14,1 GPa (HV ≈ HK), 370 GPa, 379 MPa, 4-5 MPa·√m, α 8,2·10⁻⁶, k 30 | CoorsTek AD-995 | ficha (HV ≈ HK, estimación) |
| Rubí = zafiro en dureza, módulo, densidad y resistencia | Roditi; Saint-Gobain | ficha |
| Verneuil: llama ≥ 2000 °C (~2200), ~10 mm/h, bolas de 13-20 mm | Scheel 2000; The Gemology Project; Nassau 1980 | libro; artículo |
| Cr₂O₃ del rubí: 0,03-0,05 % (láser), ~5 % (joyería) | Roditi; How Products Are Made | ficha; divulgación |
| Alúmina de Coble: 0,25-0,5 % MgO, 1700-1950 °C, 24 h a 1700 y 6-8 h a 1900, vacío o H₂ | Coble, US 3.026.210 | patente |
| HPHT: 5,5 GPa, 1340-1350 °C, Fe-Co-Ti, 6-8 mg/h, cristales de hasta 12 mm | Sumiya et al. 2002 | artículo |
| Línea de Kennedy: P (kbar) = 19,4 + T/40 | Kennedy y Kennedy 1976 | artículo |
| CVD: 0,1-10 % de CH₄, sustrato a 700-1300 °C (Si, Mo, W, Ti, diamante); 50-150 µm/h | Balmer et al. 2009; Yan et al. 2002 | artículo |
| CVD: presión de una fracción de la del aire | — | estimación |
| Oro: colar a 30-100 °C sobre el líquido | Ganoksin | divulgación técnica |
| Acero: colar a 1500-1550 °C | CastingQuality (CF8) | divulgación técnica |
| Yeso: no pasa de ~816 °C | Ganoksin | divulgación técnica |
| Titanio: sobrecalentamiento de 30-100 °C | como el oro | estimación |
| Tiempos de fusión de la carga (2-10 min) | — | estimación |
| Convección: aire 15; agua 8·10⁴ (calibrado); aceite 2,3·10⁴ | Incropera; Morgan; Grossmann | libro; calibrado en un caso medido; estimación |
| ΔT de Kingery; factor de Manson | Kingery 1955; Manson 1966 (Lu y Fleck 1998) | libro; artículo |
| Desconchado: β = 9 | Chai y Lawn 2007 | artículo |
| Régimen dúctil: 0,15 | Bifano et al. 1991 | artículo |
| Durezas de los abrasivos | las del taller (GNPGraystar, GRAYSTAR, Solozhenko et al. 2019, KAPP; FWT) | ficha |
| El diamante y el SiC se gastan contra el acero | KAPP; Komanduri y Shaw 1975; US 4.505.720 | artículo; patente |
| Muela de serie: 10 N, 20 m/s, 3 × 3 mm; piel de 0,1 mm; agrietarse en seco con k < 10 | — | estimación (regla del modelo) |
| ALD: 1,107 Å por ciclo desde 33 °C | Groner et al. 2004 | artículo |
| Pulverización: ≤ 250 °C, 12 GPa; 2 µm a 100 °C | Schneider et al. 1997; amorfa 10-12 GPa (2001) | artículo; estimación (espesor y temperatura) |
| TiN: 30 GPa, 1-4 µm, 250/400 °C; HV = 0,0945·H_IT | Oerlikon Balzers; ISO 14577 | ficha; norma |
| Cromo duro: baño a 50-65 °C, 20-40 µm, ~25 µm/h, 750-1050 HV (900) | NEWMOA 2003 (vía Wikipedia); U.S. Chrome; ScienceDirect Topics | recopilación; ficha |
| Pintura conductora para galvanizar lo que no conduce | Gateros Plating | divulgación técnica |
| Soldadura fuerte de plata: 618-652 °C | SAE AMS 4763 | norma |
| Plasma: 200-500 µm, ~4 % de poros, ~950 HV; sustrato a 150 °C | Mater. Charact. 2010; Mater. Des. 2004 | artículo; estimación (la temperatura) |
| Esmalte: 750-850 °C; ~550 HV | Andrews 1961; el strass del banco | libro; estimación |
| Regla del 10 % de la capa | ISO 14577-4 | norma |
| Silicona 0,2 W/(m·K), 1050-1300 J/(kg·K), ~200 °C | Shin-Etsu; AZoM | ficha |
| Aerogel 14-62 mW/(m·K), 0,20 g/cm³, 650 °C; c ~1000 | Aspen Aerogels; c estimado | ficha; estimación |
| Agua 0,6 W/(m·K), 4180 J/(kg·K), 2257 kJ/kg | Incropera | libro |
| Cianoacrilato 20 MPa (12,4), 0,05-0,15 mm, 75 % mojado | Henkel, LOCTITE 401 | ficha |
| Epoxi 14,9 MPa; metacrilato 19,4 MPa; holguras | Henkel, guías de diseño | ficha |
| Cortante de la queratina bajo la unión: σ/2 × 0,25 | Tresca; Farren et al. 2004; Ferreira et al. 2024 | estimación |
| Funda de serie: 40 % de la garra, 1 mm de pared | como una corona dental | estimación (elección del ensayo) |
| Carga de la comprobación: la fuerza de la ficha, toda en cortante | la ficha del banco (2.0) | estimación (suposición) |
| Calor específico (J/(kg·K), unidad 5j): oro 129; acero 304, 500; metal duro 250 (150-480); vidrio 720; cuarzo 742; zafiro y rubí 757; diamante 509; alúmina 880 | CRC Handbook; AK Steel; Hyperion y Goodfellow; EN 572-1; NIST-JANAF (Chase 1998); Saint-Gobain; NIST WebBook (Victor 1962); CoorsTek | libro; ficha; norma; tabla |
| Calor específico del cristal al plomo 720, de la circonita 455 y de la moissanita 670 (unidad 5j) | el vidrio sodocálcico; el ZrO₂ monoclínico (NIST-JANAF); el SiC sinterizado (Hexoloy SA) | caso parecido medido (estimación) |
| Acrílico dental (PMMA, unidad 5j): ~20 HV; 2,6 GPa; 84,4 MPa a flexión (60-92,8); 1,63 MPa·√m; 1,18 g/cm³ | Zafar 2020 (termopolimerizado); Barbosa et al. en Alqutaibi et al. 2023 (autopolimerizable); ISO 20795-1 | artículo; norma (la dureza del autopolimerizable, estimación) |
| Acrílico dental: transición vítrea 125 °C; α 81·10⁻⁶; k 0,19; c 1306 J/(kg·K) | Zafar 2020; Assael et al. 2005; NIST WebBook (Melia 1962) | artículo; tabla |
| La prótesis de acrílico en una garra: la técnica del pico (rellenar, fraguar en frío, limar y rehacer cada 8-12 semanas) | Samour 2006; Matta et al. 2022 | estimación (caso parecido: el pico) |
| La superficie de la pieza: Ra = h/4 de la última muela o del último grano; el pulido a 10 N con 3 mm de contacto | la regla de la cetrería (5g); elección del ensayo | estimación |

## 11. Lo marcado como ficción, y por qué

- **El horno-fundidor que lo junta todo** (`FURNACE.quality = "ficcion"`): cada modo es real, pero ninguna máquina de taller
  hace a la vez Verneuil, HPHT, CVD, inducción y sinterizado en vacío.
- **Recubrir la garra en el animal** (cualquier método con `target: "garra_viva"`): nadie lo hace; se hace una funda aparte.
  Los recubrimientos en vacío (ALD, pulverización, PVD, CVD) piden una cámara en la que un animal no puede entrar. El motor
  calcula el calor por las dos vías (§6.2) y dice qué pasaría.
- **Verter un material fundido sobre la garra** (`COATINGS.fundido`): la capa sale a su temperatura de fusión (1064 °C el oro,
  2053 °C el zafiro), muy por encima de los ~230 °C a los que se quema la queratina: siempre la quema.
- **La garra resultante** de una ficción lleva `quality: "ficcion"`; sigue siendo de queratina para el banco, con la capa
  aparte (`coating`).
- **Tallar el bloque en el animal** (la garra rota que vuelve a la cetrería, unidad 5g: `care_setup` con `stump_mm`): en la
  realidad la funda o la prótesis se talla aparte, con muelas y discos de diamante y agua (horas en las gemas), y se pega en
  frío ya terminada; en el animal solo se lima el acrílico. El motor lo deja hacer, con la nota. El acrílico dental, la vía
  real, no es ficción (§15.1).

## 12. Qué no predice

- Cinéticas: el horno da un estado según la temperatura (funde, se oxida, se grafitiza…), no la velocidad de la oxidación ni
  del crecimiento de grano; los tiempos de sinterizado son los de las recetas.
- La forma real del cristal (la bola de Verneuil es un cilindro de diámetro fijo), las inclusiones, el color (dibujo) y la
  tensión residual en números.
- El choque térmico con radiación (a más de ~1000 °C suma decenas a cientos de W/(m²·K) al aire; no cambia ningún resultado
  del modelo), con geometrías que no sean una placa y con cambios de las propiedades con la temperatura.
- El desgaste de la muela en números (relación G). La rugosidad que deja la última muela o el último grano sí (§15.4), pero
  como un valor para toda la pieza, sin la textura de cada grano.
- El reparto del calor del roce entre la herramienta y el bloque (ε = 0,5) y la fricción de la lija son los de la queratina
  en todos los bloques; con una muela convencional, el acero se queda con el 60-85 % (Malkin y Guo 2007): en un bloque de
  metal llegaría algo más de calor (§15.2).
- El calor de la garra viva en tres dimensiones: las dos vías son losas de una dimensión; la exotermia del metacrilato al
  curar (en masa puede pasar de 70 °C; en capas finas, no).
- La resistencia de la unión al pelado y a la flexión (solo cortante medio), la fatiga, el envejecimiento en agua del epoxi y
  del metacrilato, y el crecimiento de la garra debajo de la funda (la prótesis del pico se rehace cada 8-12 semanas).
- La capa en el banco: el motor de punción y rayado no tiene una capa sobre otro material; se da la hondura hasta la que manda
  (§6.3).
- Kyropoulos y Czochralski (cristales grandes para garras gruesas): sin un ritmo de crecimiento a mano, no se modelan.

## 13. Casos de referencia

`tests/fixtures/spec/reforja.json` (23 casos, cada uno con su cálculo a mano en la nota) contra `test_claw_forge_spec.gd`:
la línea de Kennedy, el salto de Kingery del vidrio, el factor de Manson, el temple calibrado de la alúmina, la bola de zafiro
en agua, aceite y aire, el desconchado del borde, el régimen dúctil del zafiro y del metal duro, la unión con epoxi seca y
empapada y el cianoacrilato que no cura, la geometría de la funda del águila, lo que crece cada método, el sinterizado de
Coble, la capa de ALD, quién muerde a quién, la barrera en régimen permanente, el gel de agua, la queratina sin barrera, la masa
de la funda, el proceso completo del zafiro, el rubí sin cromo, el diamante HPHT junto a la línea de Kennedy, el calor al aire
y en vacío y el cuarzo por 573 °C.

Invariantes (`test_claw_forge.gd`): un abrasivo más blando nunca talla ni pule; más temperatura nunca funde ni degrada menos;
el diamante al aire por encima de su oxidación siempre se degrada; más superficie pegada nunca se despega antes; nada caliente
toca la garra viva sin quemarla; una barrera más gruesa, cubrir menos o menos tiempo nunca la dejan más caliente; ψ crece con
β; un medio que enfría más nunca aguanta más salto. Recetas (`test_claw_forge_recipes.gd`): cada una, siguiendo su tutorial al
pie de la letra, sale bien en el águila (y en el tigre, el oso, el velocirraptor y el halcón, salvo cuando la funda no cabe en
el cristal del método, y lo dice); desviar cada parámetro fuera de su margen da el defecto de la receta.

## 14. Guía de integración (para la parte de interfaz)

**Crear y mover:** `ClawForge.new({ animal, claw, recipe, cover_mm, wall_mm, humidity, digit, paw, stump_mm, cover_frac })`
(los cuatro últimos, de la unidad 5j: la garra de su dedo y de su pata, lo que queda de una garra rota y la parte de la garra
que cubre la funda); acciones `mix(gramos)`,
`fire({ mode, temp_c, time_s, atmosphere, pressure_mpa, mold, methane })`, `choose(material)`, `heat({ temp_c, atmosphere })`,
`cool(medio)`, `carve({ abrasive, grain_um, force_n, speed_ms, coolant })`, `protect({ barrier, thickness_mm })`,
`coat({ method, target, time_s, cycles, material, cover_mm })`, `bond({ adhesive, gap_mm })`,
`polish({ abrasive, grain_um, sharpen })` y `check_load({ load_n })`. Lecturas: `snapshot()`, `report()`, `result_claw()`,
`care_setup()` (y `care_setup(ajustes con stump_mm)`, la garra rota: §8), `stage()`, `events()`, `serial()`, `natural_mm()`
y `surface()` (§15.4).

**Recetas, mandos y tutoriales:** `ClawForge.recipes()` (tarjetas con los polvos y sus nombres), `ClawForge.controls()` (los
mandos, para diales y botones), `tutorial(id)` (`horno`, una receta, `piedra`, `acrilico` o `garra_viva`: pasos con `title`, `text`,
`source`, `check`, `done`, `action`, `args` y `mistake`), `recommended(id)` y `do_step(paso)`.

**Lo que necesita la escena 3D del horno** (la hará otra unidad):

- **Mezcla de polvos:** la balanza y los tarros de `ForgeData.POWDERS` (alúmina, óxido de cromo, magnesia, WC, cobalto,
  grafito, disolvente de Fe-Co, metano, granallas); el crisol o el alimentador se llena con lo pesado (`mix` da las
  fracciones y el primer problema).
- **Mandos:** los de `controls()`: dial del modo, de la temperatura (con la escala del margen de la receta pintada), del tiempo,
  de la presión, selector de la atmósfera, del molde, del metano y del enfriamiento. Botón de arrancar.
- **Lo que se ve:** la llama de oxígeno e hidrógeno y la bola que crece hacia abajo (Verneuil, `growth.mm_h` y el tamaño
  crecido en `fire().grown`); la bobina de inducción y el crisol al rojo; la prensa cerrada (HPHT); el plasma violeta sobre el
  molde (CVD); la pieza que encoge al sinterizar; la colada en el molde; el temple que hierve; la pieza con su acabado
  (`finish`) y su color (de la 5e).
- **Taller:** la muela con su agua, la barrera sobre la carne viva (con la mitad de la garra que tiene carne viva, de
  `live_paths()`), la pistola de proyección y la funda que se pega; el termómetro de la carne viva en la ficción
  (`coat().thermal`).
- **Sonidos propuestos** (ids nuevos, `ClawForge.SFX_FORGE`; la parte de interfaz los sintetiza y hornea): `forja-muela`,
  `forja-horno` (zumbido del horno eléctrico), `forja-llama` (soplete), `forja-induccion` (zumbido de la bobina),
  `forja-prensa`, `forja-colada` y `forja-temple` (siseo del temple, también la garra que se quema). Los demás son los del
  laboratorio (`shatter`, `snap`, `slide`, `scratch-metal`, `scratch-glass`, `tap`). `sfx_for(acción, resultado)` dice cuál;
  la marcha del horno suena a la máquina del modo, no a la receta (`machine_for(modo, receta)` y `machine_sfx(máquina)`,
  unidad 5j).
- **Textos:** las fuentes se enseñan con `ClawCareState.readable_source()`, como en la cetrería.
- **Rendimiento:** `coat()` sobre la garra viva y `barrier_heating` integran hasta 4000 pasos por vía (décimas de segundo en
  GDScript): una vez por acción, no por fotograma.

## 15. La pasada de pulido (unidad 5j)

Lo que pidieron la 5f al unirse y la 5g al terminar. Tests: `test_claw_forge.gd`, `test_claw_forge_state.gd`,
`test_claw_care_bloque.gd`, `test_forge3d.gd` y `test_forge_page.gd`.

### 15.1 La prótesis de verdad: el acrílico dental

Una garra rota de una rapaz no se arregla con una funda de zafiro. Lo que se hace de verdad es lo del pico:

- los veterinarios rellenan el pico con «methacrylate glue and baking soda or commercially available beak repair kits» y,
  como crece, «continuous repairs will be required every 8 to 12 weeks» (Samour 2006, pp. 927-928);
- el acrílico dental se usa en el pico porque fragua en frío, sin el calor que dañaría el tejido; ya fraguado, se le da forma
  con una amoladora, y una prótesis de acrílico sin anclar se cae cuando se renueva la queratina (Matta et al. 2022: la del
  pico de un loro se cayó sola a los seis meses, con el pico ya crecido);
- en una garra, la misma técnica: **estimación**, con el caso documentado más parecido, el pico.

Con la garra rota, «Reforjar con material» ofrece «Acrílico dental (la prótesis de verdad)» junto a las recetas de fantasía.
Con la garra sana no sale.

- **Se mezcla sin horno:** `choose("acrilico")`, la tecla L o el estuche del acrílico de la mesa de la balanza.
- **Vuelve a la cetrería** como un bloque con la pared de sobra sobre lo que queda de la garra (`care_setup`), sin ficción:
  `block.fiction = false` y `block.quality = "estimate"`, con su nota y sus fuentes. Allí se lima con la lima o con la
  amoladora. Los demás materiales siguen marcados como ficción (`block.quality = "ficcion"`).
- **La cetrería lo conoce como bloque** (`ClawCare.supports_block`; no está en el banco). Su punta aguanta con su resistencia
  (`ForgeData.strength_of`) y se lima en régimen dúctil (d_c ≈ 0,14 mm: no desconcha).
- **No va al horno:** pasado su reblandecimiento (125 °C, la transición vítrea del PMMA) se ablanda (`heat`, defecto
  «reblandece»).
- **El tutorial** `acrilico`: la prótesis de verdad, parar la sangre y secar, mezclar, aplicarla y limarla en la cetrería y
  rehacerla cuando crezca.
- **Su aspecto:** la biblioteca de materiales aún no tiene los datos ópticos del acrílico (`ClawOptics`, de la 5e): la pieza
  se pinta como la queratina con el color de dibujo del acrílico (`look_view().tint`). En la cetrería, el bloque aún se pinta
  con la queratina de la garra (como el de cualquier material).

Los datos (`ForgeData.PROSTHESIS.acrilico` y su ficha de horno en `ForgeData.MATERIALS.acrilico`) son los del PMMA de las
prótesis dentales:

| Dato | Valor | Fuente | Tipo |
|---|---|---|---|
| Dureza | ~20 HV | Zafar 2020 (termopolimerizado: 18-20 KHN, ~20 VHN); el autopolimerizable, igual o algo más blando | estimación |
| Módulo | 2,6 GPa (la norma pide ≥ 1,5) | Zafar 2020; ISO 20795-1 | artículo; norma |
| Resistencia a flexión | 84,4 MPa (banda 60-92,8) | Barbosa et al. en Alqutaibi et al. 2023 (autopolimerizable); el mínimo de la ISO 20795-1 y el termopolimerizado | artículo; norma |
| Tenacidad | 1,63 MPa·√m | Barbosa et al. en Alqutaibi et al. 2023 | artículo |
| Densidad | 1,18 g/cm³ | Zafar 2020 | artículo |
| Se ablanda | 125 °C (la transición vítrea) | Zafar 2020 | artículo |
| Dilatación · conducción · calor específico | 81·10⁻⁶ 1/K · 0,19 W/(m·K) · 1306 J/(kg·K) | Zafar 2020; Assael et al. 2005; NIST WebBook (Melia 1962) | artículo; tabla |
| El color | #E6DCCF | — | dibujo |

### 15.2 El calor de limar el bloque

Hasta la 5j, el calor de limar el bloque de una garra rota se contaba con la conducción de la queratina, que solo vale para
el acrílico. Ahora cada nodo del modelo térmico de la cetrería lleva el material de su sitio (`ClawCare.block_thermal`, con
la ficha de esta unidad):

- **Las propiedades:** la queratina del muñón y de la carne viva, o el bloque con su conducción k, su densidad ρ y su calor
  específico c (`ForgeData.MATERIALS`, con la fila nueva `cp`, y `ForgeData.density_of`).
- **Entre dos materiales,** las dos mitades de los nodos en serie: a/(dx/2/k₁ + dx/2/k₂).
- **Hasta dónde llega el calor:** el bloque va del lado de la cara, y se cuenta con el largo equivalente de queratina,
  L·√(α_queratina/α_bloque) (la difusión tarda L²/α), contra los 12 mm de `max_depth_mm`.
- **El tope de cada nodo:** el de su material. La queratina se quema a ~230 °C; el bloque, a la temperatura más baja a la
  que se estropea en el aire: se funde, se ablanda (el acrílico, a 125 °C) o se oxida (el diamante, a 600 °C). Lo dice el
  suceso «bloque_calor». La superficie del bloque se marca como quemada en los 15 °C antes de su tope.
- **Sin datos de conducción** (la hematites), como la queratina, y la nota lo dice; sin bloque, el modelo no cambia.

Con 0,5 W en la punta de un bloque sobre lo que queda de la garra del águila (el muñón de 20 mm), durante 20 s:

| Bloque | k (W/(m·K)) | α (m²/s) | Cara | Carne viva |
|---|---|---|---|---|
| Acrílico | 0,19 | 1,2·10⁻⁷ | 74,8 °C | 32,00 °C |
| Vidrio | 1 | 5,5·10⁻⁷ | 51,9 °C | 32,01 °C |
| Circonita | 2,5 | 9,5·10⁻⁷ | 42,9 °C | 32,07 °C |
| Cuarzo | 6,2 | 3,2·10⁻⁶ | 40,3 °C | 33,29 °C |
| Titanio | 16,4 | 7,0·10⁻⁶ | 36,9 °C | 34,01 °C |
| Oro | 317 | 1,3·10⁻⁴ | 35,0 °C | 34,81 °C |

El calor se reparte por el metal y la cara queda más fría, pero llega antes a la carne viva: es lo que decía la nota de la
5g. Invariantes con test: con el mismo calor, un bloque que conduce y difunde más nunca deja la carne viva más fría ni la
cara más caliente; en régimen, el calor cruza el bloque y la queratina en serie (θ_cara = P/(1/R + h·A)); el acrílico
calienta como la queratina (±25 %). El reparto del calor del roce y la fricción siguen siendo los de la queratina (§12).

### 15.3 La forma de la prótesis de una garra rota

`ClawForge.new({ …, digit, paw, stump_mm, cover_frac })`: la funda o la prótesis se hace para la garra de su dedo y de su
pata (la de la cetrería, `CareData.claw_shape`), y la de una garra rota, con lo que queda de ella (`stump_mm`, lo que da
`ClawCareState.reforge_request()`). Antes se calculaba sobre la garra sana del banco.

- `sheath_geometry(claw, cover_mm, wall_mm, gone_mm, shape)`: lo que falta (`gone_mm`, desde la punta natural) se rehace
  macizo y no se pega; el resto es la funda hueca, pegada sobre lo que queda.
- La instantánea de la funda lleva `naturalMm`, `goneMm`, `stumpCoverMm` y `solidVolumeMm3`; `natural_mm()`, el largo
  natural de esa garra.
- Si no queda nada que cubrir, `bond()` da el defecto «sin_superficie».

Por ejemplo, la garra del dedo II del águila (48,8 mm) rota a 18 mm: rehace 30,8 mm macizos y se pega sobre los 18 mm que
quedan (820 mm² para pegar).

### 15.4 La superficie de la pieza

La pieza tallada o pulida lleva la rugosidad que deja la última muela o el último grano, con la regla de la cetrería
(Ra = h/4, con la hondura del surco de cada grano: `ClawCare.groove_um` y `pass_ra_um`):

- `evaluate_carve` devuelve `raUm` y `chip` (1 si talla en régimen frágil: desconcha).
- `polish_surface(abrasivo, grano, material, dureza)` usa la fuerza y el contacto de `ForgeData.PIECE_SURFACE` (10 N y 3 mm,
  estimación).
- `surface()`: `{ ok, by («talla» | «pulido»), material, raUm, chip, scratchDeg, stations, lengthMm, quality, source }`.
  Las `stations` llevan la forma de `ClawMaterial.surface_image` (la de la cetrería). Una capa de 1 µm o más la tapa
  (`ok = false`).
- La escena la codifica con la biblioteca común (`ClawMaterial.surface_image` y `set_surface`), como la cetrería.

| Pieza | Tallada | Pulida con diamante de 45 µm | De 9 µm |
|---|---|---|---|
| Zafiro (muela de diamante) | 0,018 µm, desconcha | 0,018 µm | 0,0007 µm, sin desconchar |
| Vidrio (diamante) | 0,068 µm, desconcha | 0,068 µm | 0,0027 µm |
| Acero (CBN) | 0,60 µm | 0,20 µm | 0,007 µm |
| Oro (diamante) | 0,81 µm | 0,81 µm | 0,05 µm |

En las piezas duras sale casi un espejo, como en la cetrería (estimación).

### 15.5 La vista de la cetrería, el sonido y el teléfono

- `ClawCareState.view().reforge_request`: lo que pide la reforja con la garra rota y sin reconstruir (`{}` si no). La página
  de la cetrería debe leerlo de ahí (pendiente de la 5h, dueña de `care_page.gd`).
- `sfx_for("fire")` sigue a la máquina del modo del horno (`machine_for(modo, receta)`: el soplete de Verneuil, la prensa
  HPHT, la CVD, el sinterizado, la bobina o la colada) y `sfx_for("heat")`, al horno.
- En el teléfono, las vistas encuadran lo suyo a la izquierda del deslizador grande (`Forge3D.set_inset_right` y
  `ForgePage.inset_right()`): la columna derecha del panel del horno ya no queda debajo. Es presentación, no física.

## 17. La reforja realista (unidad 5m, peticiones 42 a 45)

**Petición 42 de Eric (04-10-2026):** «hay que echar los materiales dentro de la máquina, usar los botones y parámetros
para cada material, programar un tiempo —que en el juego será más rápido y podrá ajustarse la velocidad, pero que en la
vida real tardaría más— y, una vez obtenido el material en bruto, colarlo en un coladero con la forma de cada garra […]; o,
si se obtiene un mineral duro en bruto, darle la forma correcta de garra de cada animal con las herramientas
correspondientes. Todo ello con un tutorial, o sin él». **Petición 43:** el laboratorio acaba en la pieza terminada y sin
pegar; colocarla y acabarla a mano es de la cetrería. **Petición 45:** la sala con ventanas al campo y materiales con
textura.

### 17.1 La carga dentro de su máquina

Cada modo del horno es una máquina real (§3.1) y cada una se carga a su manera (`ForgeData.MACHINES`):

| Máquina | Lo que entra | Dónde | Cómo se cierra | Fuente |
|---|---|---|---|---|
| Verneuil | la alúmina en polvo | la tolva del soplete, que un martillo golpea para que el polvo caiga por la llama | la tapa de la tolva; la semilla sube hasta la llama | Scheel 2000; The Gemology Project |
| HPHT | la cápsula (grafito, disolvente de Fe-Co y la semilla) | entre los yunques de la prensa | los yunques aprietan la cápsula | Sumiya et al. 2002 |
| CVD | el sustrato con la forma de la funda (Mo, W o Si) | sobre el calentador, bajo la campana | la campana baja y se hace el vacío | Balmer et al. 2009 |
| Sinterizado | la pastilla prensada (más grande: encoge ~20 %) | en su bandeja, dentro del horno | la puerta del horno | General Carbide; Coble |
| Inducción | el crisol con la chatarra | dentro de la bobina | la tapa del horno | CastingQuality (CF8) |
| Fundir y colar | el crisol con el metal o el vidrio, y el molde caliente | el crisol en el horno; el molde, al lado | la puerta | Kerr; Bullseye |
| Calentar | la pieza o el molde que se quema | en la bandeja | la puerta | §3.3 |

«Arrancar» no deja sin la carga en la máquina del modo del dial, y dice por qué. Es procedimiento, no física: el motor lo
apunta (`load_machine`) y la marcha lo exige en la interfaz.

### 17.2 El tiempo de verdad

El dial programa el tiempo real del proceso (el de cada receta, §3.2). La marcha dura ese tiempo dividido por la velocidad
elegida (×60, ×600, ×3600, ×36 000 o «lo más rápido»), con topes de unos segundos y unos minutos (elección de la
interfaz), y el reloj enseña lo que lleva y lo que falta de verdad. La velocidad no cambia el resultado: el motor lo decide
al arrancar. Duraciones nuevas, con su fuente:

| Paso | Duración real | Fuente | Tipo |
|---|---|---|---|
| Fraguado del revestimiento de yeso antes de quemarlo | 2 h | Kerr, Satin Cast 20 / KerrCast 2000, Directions For Use (2011): «Let flasks sit still for 2 hours» | ficha |
| Fraguado del revestimiento de fosfato | ≥ 1 h | Shor International, «Platinum investment instructions» | ficha |
| Curado del molde de yeso y sílice del vidrio | 24-48 h envuelto | Bullseye Glass, TipSheet 8 | ficha |
| Quemado de la cera en yeso (molde pequeño, 63 × 63 mm) | ciclo de 5 h de mantenimiento: 1 h a 149 °C, 1 h a 371 °C, 2 h a 732 °C y 1 h a la temperatura de colada; rampas de ~5 °C/min aparte | Kerr (2011), «Recommended Burnout Cycles» | ficha |
| Temperatura del molde de yeso al colar oro | 482-538 °C (piezas finas) | Kerr (2011) | ficha |
| El yeso no pasa de ~816 °C | se descompone y da poros | Ganoksin (§3.3) | divulgación técnica |
| Quemado del revestimiento de fosfato (acero inoxidable, titanio) | 93 °C la primera hora, 177 °C la media hora siguiente, 2 h hasta 871 °C y 1 h a 871 °C; el molde, 1 h a la de colada | Shor International; SRS-Goodwin, «Burnout guidelines & casting temperatures» | ficha |
| Temperatura del molde para el inoxidable | 750-900 °C (colada a 1625-1675 °C) | SRS-Goodwin | ficha |
| Molde del vidrio (yeso y sílice) | 55 °C/h hasta 93 °C y 6 h; 55 °C/h hasta 677 °C y 2 h; 333 °C/h hasta 830 °C y 3 h | Bullseye Glass, TipSheet 8 («Typical cycle») | ficha |
| Recocido del vidrio colado | lo más rápido que enfríe el horno hasta 596-677 °C y 4 h; 27,7 °C/h hasta 482 °C y 6 h; 6,7 °C/h hasta 427 °C; 12 °C/h hasta 371 °C; 40 °C/h hasta 21 °C; un día antes de desmoldar | Bullseye Glass, TipSheet 8 | ficha |
| Enfriar al aire, en aceite o en agua | estimación de capacidad concentrada, τ = ρ·c·V/(h·A), con los coeficientes de §4 | Incropera et al. 2007 | estimación |
| Cada pasada de la muela | el volumen que quita entre la tasa de arranque del motor (§5) | §5 | modelo |

### 17.3 La cera perdida: la colada con la forma de la garra

Los metales (oro, acero y titanio) y el vidrio se cuelan en un molde con la forma de la funda de la garra de su dedo
(`CareData.claw_shape`), como se hacen las coronas dentales y las joyas: el modelo de cera, el revestimiento, el quemado de
la cera, la colada, el enfriado, romper el molde y cortar y limar el bebedero. **Los minerales duros no se cuelan en un
taller:** el zafiro y el rubí funden a 2053 °C y se cultivan como cristal (§3.3), el diamante no funde, y la alúmina colada
de la industria (la electrofundida) sale de un horno de arco con rechupes de 1-10 mm y un 16-20 % de huecos (patentes de
los refractarios electrofundidos, p. ej. US 6.812.177): para una garra, se tallan.

- **La contracción.** El metal encoge al solidificar y al enfriarse: el oro puro, un 1,67 % lineal (Hollenback y Skinner
  1946); el titanio, un 1,55 % (Ferreira et al. 2007, del sólido a la temperatura ambiente con su dilatación); el acero 304,
  con el mismo método y la dilatación de su ficha, 17,3·10⁻⁶ × (1399 − 20) ≈ 2,4 % (estimación: la dilatación de 0-100 °C,
  que crece con la temperatura); el vidrio, desde su recocido, 9·10⁻⁶ × (546 − 20) ≈ 0,47 % (estimación).
- **El revestimiento la compensa.** El de yeso con cristobalita se dilata ~1,6-1,7 % al fraguar y al calentarse (Earnshaw
  1988; Finger y Jørgensen 1980); el de fosfato, un 2,10 % al fraguar con su líquido (Hsu et al. 2007), y llega al 1,55 %
  del titanio según la concentración del líquido (Ferreira et al. 2007); en el yeso y sílice del vidrio, «la sílice se dilata
  al cocerse y compensa el yeso, que encoge» (Bullseye: dilatación neta ≈ 0, estimación). Lo que falte se compensa haciendo
  la cera más grande (la «regla de contracción» del modelista; ORNL, Sabau 2005).
- **El bebedero.** Tiene que solidificar después de la pieza para alimentarla mientras encoge: su módulo (volumen entre
  superficie) ≥ 1,2 veces el de la pieza (regla de Chvorinov; Campbell y Harding, TALAT 3206). Un cilindro de diámetro d
  tiene un módulo d/4 y una pared de espesor t, t/2: d ≥ 2,4·t.
- **Los defectos**, los de la receta (§3.2) y los de Kerr: frío o con el molde frío, no llena; caliente, poros; la cera mal
  quemada, poros y no llena; el yeso por encima de ~816 °C, poros; el molde que no aguanta el metal (§3.1).

### 17.4 El tallado por pasadas de un mineral duro

Con las máquinas de un lapidario y la pieza pegada en un palo con cera (el «dop»: la cera verde funde a ~65 °C):

| Herramienta | Qué hace | Ficha |
|---|---|---|
| Sierra de disco de diamante (Hi-Tech Diamond, 6", 800-3400 rpm, depósito de agua de 16 oz) | saca el tocho de la bola, del cristal o del bloque, y corta el bebedero | disco de 6" × 0,012-0,015" (0,30-0,38 mm) de canto, para corindón, rubí, cuarzo y vidrio |
| Muelas de diamante en fila (Diamond Pacific Genie: 6", 1800 rpm, bomba de agua) | la gruesa (grano 80) desbasta; la fina (grano 220) da la forma | ruedas metálicas de níquel de 80 y 220; luego 280, 600, 1200 y 3000 de resina y un disco de 14 000 |
| Fresa de diamante en el eje flexible | vacía la funda por dentro | — |
| Pulidora (disco de fieltro o cuero con pasta de diamante) | pule | DMT: 60, 45, 25 y 9 µm |

- El grano: 80 mesh ≈ D181 (150-180 µm) y 220 mesh ≈ D76 (63-75 µm), FEPA/ISO 6106 (Haefeli, «Grit sizes»).
- Cada pasada quita una capa de lo que sobra sobre la silueta de la garra; su tiempo es el volumen entre la tasa de arranque
  de Archard del motor (§5) con el grano, la fuerza y la velocidad de esa herramienta. Lo que quita cada pasada es una
  elección del juego (sin medición publicada: el lapidario la ajusta a ojo).
- Los errores, los de §5: una herramienta más blanda no muerde; en seco se agrieta lo frágil que conduce mal y se quema la
  muela de diamante; apretando de más se desconcha el borde (Chai y Lawn, con la pared que queda); pasarse de la silueta
  deja la pared más fina, y si llega a cero, agujerea la funda.

### 17.5 El laboratorio acaba en la pieza sin pegar (petición 43)

El laboratorio termina en la pieza tallada (o colada y limada), protegida o recubierta, y pulida, y en «Probar el ajuste»
(la holgura entre la funda y la garra, sin pegar). Pegarla (`bond()` y `bond_capacity()`, que siguen en el motor) y probarla
con la carga son de la cetrería, sobre el animal. `care_setup()` lleva además la pieza sin pegar (`piece`).

### 17.6 Lo que elige la interfaz (no son datos)

- **El orden.** Primero el modo (que elige la máquina), luego meter la carga (M o la puerta del horno) y luego arrancar. Con
  la carga en otra máquina, o sin ella, «Arrancar» no arranca y dice dónde está; el error se explica con el paso «Meter la
  carga en su máquina» (o con el de pesar, si el crisol está vacío).
- **Lo que dura en la pantalla.** La marcha, el tiempo de verdad entre la velocidad, entre 3 s y 150 s; las animaciones del
  taller con tiempo de verdad (enfriar, el fraguado del revestimiento, la espera del vidrio para desmoldar, cada pasada),
  entre 0,8 s y 20 s. «Lo más rápido», siempre lo menos. El reloj dice cuándo manda el tope. La subida de temperatura del
  horno al empezar la marcha es dibujo (el motor no modela la cinética), salvo en el quemado de la cera, donde el horno sigue
  el ciclo de la fuente con sus subidas y sus mantenimientos.
- **Las pasadas.** La muela gruesa quita 1 mm de lo que sobra por pasada (no sigue la línea: si sobra menos, se pasa), la
  fina 0,25 mm (sigue la línea), la fresa vacía 5 mm de hondo; una pasada suave quita la cuarta parte; la forma es la de la
  garra cuando lo que sobra o falta no pasa de 0,05 mm (a ojo con la plantilla). Pasarse de la silueta se dice en cuanto
  pasa, esté o no vaciada la funda. Todo ello, estimación (tabla de estimaciones de §10).
- **Enfriar hasta cogerla:** hasta 50 °C (elección).
- **La sala (petición 45)** es dibujo: el cielo, el campo y los materiales con relieve (forge_looks.gd) no entran en la física.

### 17.7 Pendiente

- La soldadura TIG y por láser de las piezas de metal de la funda (petición 44): hecha en la 5r (§18).
- Las máquinas por dentro con más detalle (la semilla que sube en Verneuil, la campana que baja en la CVD, el martillo que
  golpea la tolva) y el palo de lapidario con su cera calentándose: lo que se ve es el mínimo reconocible.
- El tallado no rehace la superficie interior de la funda (el hueco de la fresa se cuenta, pero no se dibuja).

## 18. Soldar piezas de metal de la funda (5r; petición 44)

Lo que sí se suelda es metal con metal, en el laboratorio y antes de colocar la pieza (la punta a la funda, o una funda
rota por su costura). Sobre la queratina, nunca: no conduce, se quema a ~230 °C y no se funde con el metal (eso lo explica la
cetrería, 5o). Código: `core/lab/claw_weld.gd` (la física), `claw_forge.gd` (`weld_setup`, `weld_align`, `weld_pulse`,
`weld_finish`, `weld_recommended`) y `claw_forge_state.gd` (la mesa: el método, sus mandos con topes, colocar y alinear, el
pedal que da un pulso por periodo con el haz sobre la costura).

### 18.1 Los tres métodos

- **Láser pulsado (Nd:YAG de joyería, W150G):** la energía del pulso E, su duración t y el diámetro del punto d dan el pico
  P = E/t y la densidad P/(π·d²/4). Por debajo de ~0,5 MW/cm² funde en **conducción** (baño ancho y poco hondo: la absorción
  del metal frío por un rendimiento de fusión de 0,3); por encima de ~1,5 MW/cm², en **ojo de cerradura** (estrecho y hondo:
  un acoplamiento de 0,037 calibrado con la penetración máxima de la ficha); entre medias, la transición. El volumen fundido
  es la energía que funde entre la entalpía de fusión por mm³; la hondura y la anchura salen de ese volumen y del modo. Por
  encima de ~3 MW/cm², poros (el ojo se cierra sobre sí mismo).
- **Micro-TIG (arco pulsado con argón, PUK):** la energía del pulso es V·I·t con el arco a 15 V y un rendimiento de 0,67
  (DuPont y Marder 1995); la fuente de calor, de ~1 mm; funde en conducción.
- **Soldadura fuerte de plata (soplete, AMS 4763):** la plata funde a 618-652 °C y sube por capilaridad con holguras de
  0,025 a 0,125 mm (la más fuerte hacia 0,04 mm); el fundente trabaja de ~565 a ~870 °C (por encima se agota). Es lo que une
  el metal duro (que no se funde) y metales distintos. Lo que aguanta al cortante, ~170 MPa, nunca más que el metal base más
  blando.

### 18.2 La costura y la unión

- **La costura** va alrededor de la funda, al 30 % de su largo desde la punta; los puntos que hacen falta salen de la
  circunferencia, la anchura del punto y el solape (del 60-70 % para resistencia, del 80-90 % para que sea estanca; la hondura
  efectiva crece con el solape). La plata recorre la costura por tramos de ~2 mm.
- **Alinear:** la junta admite como mucho el 10 % de la pared de desalineación (Amada 2016).
- **Lo que sale:** la hondura efectiva frente a la pared (falta de fusión si no la atraviesa; perforada si el ojo la atraviesa
  y sigue), los poros, el color de la zona soldada (el titanio con argón, plateado; con poco argón, pajizo; al aire, azul y gris:
  contaminado y frágil, Li et al. 2005; el inoxidable al aire, azul) y lo que aguanta la unión frente al metal base: el oro,
  la mitad (Watanabe y Topham 2006, medido); el acero y el titanio con argón, 0,9; el titanio con poco argón, 0,7; al aire,
  0,4; dos metales distintos por fusión, 0,3 (intermetálicos frágiles). **Nunca más que el metal base** (hay un test).
- **Lo que no se suelda:** las gemas, las cerámicas y el vidrio (no conducen y no se funden con el metal: se engastan o se
  pegan); el oro con el titanio por fusión (intermetálicos); el metal duro por fusión (solo con plata); la queratina, nunca.
- **Lo recomendado** (`weld_recommended`, el paso «P» del tutorial): el oro con el micro-TIG (refleja el láser frío); el acero
  y el titanio con el láser (el titanio, con argón); el metal duro con plata. La energía (o la corriente) es la más baja del
  mando que atraviesa la pared de esa funda sin perforarla, con el solape de resistencia y, si no basta, con el de estanca
  (la física de §18.1 con los pasos de los mandos).
- **Después:** el cordón sobresale una quinta parte de su anchura (elección del juego) y se lima con la muela fina; la funda
  se pule y pasa a la cetrería con lo que aguanta su unión (`care_setup().piece.weld`).

### 18.3 Valor → fuente → tipo

| Valor | Fuente | Tipo |
|---|---|---|
| Umbrales de densidad: conducción 0,5, transición 1, ojo de cerradura 1,5 MW/cm²; solape 60-70 % / 80-90 %; holgura ≤ 10 % de la pared | Amada Miyachi (2016), *Laser Welding Fundamentals* | secundaria |
| Poros por encima de 3 MW/cm² | Amada (2016) §6.4 y §8.1, con el umbral elegido | estimación |
| Entalpía de fusión: oro 63,7 kJ/kg, titanio 296 kJ/kg; acero, la del hierro (247 kJ/kg) | CRC Handbook (2014) | secundaria (el acero, estimación) |
| Absorción a 1064 nm en frío: oro 0,05, acero 0,35, titanio 0,40 | tablas de absorción a 1 µm; Amada (2016) §5.1 | estimación |
| Rendimiento de fusión en conducción 0,3; acoplamiento en ojo de cerradura 0,037 (calibrado con la W150G) | DuPont y Marder (1995); ficha W150G; Baba y Watanabe (2005) | estimación |
| Anchura en ojo de cerradura, 1,2 veces el punto | Amada (2016) §6 | estimación |
| Arco del micro-TIG: 15 V, rendimiento 0,67, fuente de ~1 mm | DuPont y Marder (1995); ficha PUK | secundaria (el diámetro, estimación) |
| La unión frente al metal base: oro 0,5 | Watanabe y Topham (2006) | secundaria |
| Acero y titanio con argón 0,9; titanio con poco argón 0,7, al aire 0,4; distintos 0,3 | Amada (2016); Li et al. (2005) | estimación |
| Color de la zona del titanio según el gas | Li et al. (2005) | secundaria |
| Plata: 618-652 °C; holgura 0,025-0,125 mm (mejor 0,04); fundente 565-870 °C; 170 MPa al cortante | AMS 4763; guías de soldadura fuerte (AWS, Lucas-Milhaupt) | norma / estimación |
| Ritmo: el micro-TIG hasta 3,3 puntos/s; el láser a mano 4/s; el soplete ~10 s por tramo | ficha PUK; elección del juego | secundaria / juego |
| Sobremonta del cordón, 1/5 de su anchura; refundir más de 2 veces por cuarto agota el fundente | elección del juego | juego |

La mesa en 3D (forge_3d.gd: la mesa, el soporte, los aparatos, las cuentas de la costura, el punto incandescente que se enfría
con la rampa del cuerpo negro de core y el destello suave) es dibujo.

### 18.4 El sonido, el teléfono y la demo

- **El sonido.** Cada pulso suena con su aparato: `forja-pulso` (el láser) y `forja-arco` (el micro-TIG). Los dos entran en la
  tabla de clases de `core/lab/sfx.gd` como **herramienta** (banda de −26 a −22 LUFS, pico ≤ 0,70) con su ganancia: +4,5 dB el
  láser (−31,3 → −26,8 LUFS, pico 0,68) y +4,0 dB el arco (−31,2 → −27,2 LUFS, pico 0,69). Los limita el pico: el arco se
  queda 0,2 dB por debajo de la banda, que es lo que la regla admite con el pico por encima de 0,6 (`test_sfx_mezcla`, y la
  tabla de `docs/fase2/qa-sonido.md`). Son ganancias de mezcla (juego), no física.
- **El teléfono.** El mando táctil grande del horno (la barra de la temperatura que sale en pantallas estrechas) tapaba la
  mesa de soldar: en la vista «Soldar» se esconde (`forge_page._touch_wanted()`), y vuelve en las demás vistas.
- **La lectura de la unión.** La tarjeta escribe «aguanta ~N MPa»: la tilde es «más o menos», no un signo menos. La resistencia
  de la unión está acotada entre 0 y la del metal base (`efficiency` entre 0 y 1), y el test de las uniones lo comprueba en
  las dos direcciones con más de mil combinaciones.
- **La demo** (`demo_reforja.gd`, escenas 15 a 17): el acero con láser (unión buena), el titanio al aire (la unión azul y
  gris, contaminada, que aguanta ~210 MPa de los 525 MPa) y el metal duro con plata. El puntero recorre la costura apretado,
  como una persona; en el teléfono la vuelta se ve de canto y la mitad de atrás queda tapada por la garra, así que el ratón no
  llega a unos tramos (en la escena 15, a 6 de 56): la demo los acaba con «Un punto (J)», que suelta el pulso en el primer
  tramo que falta, igual que haría quien juega. Al final, en el teléfono, baja la página hasta el veredicto de la tarjeta.
- **El coste.** La forja con la mesa de soldar, medida contra main (4534c56) con el mismo caso sin soldar (el 13, a 30 fps
  fijos, OpenGL por software, ventanas intercaladas y sin otra carga): la escena 3D, 0,35-0,39 ms por fotograma con la rama (mediana 0,352) frente a 0,36-0,39 ms en main
  (mediana 0,369), y la página, 1,53-1,72 ms por repintado (mediana 1,585) frente a 1,50-1,61 ms (mediana 1,560); la
  diferencia queda dentro del ruido entre ventanas. Soldando (el caso 15), la escena 3D cuesta 0,34-0,35 ms y la página
  1,94-2,01 ms de media (repinta más: cada pulso cambia la tarjeta), con algún repintado suelto de 42-46 ms (en main, el
  pico del caso 13 llega a 22-29 ms).

## 19. Pesar los polvos para la pieza de esta garra (5w)

Eric, con el metal duro en el paso 1: «no sé cuántos gramos de cada polvo echar». Hasta la 5w la balanza solo miraba la
proporción, lo recomendado era un lote de 100 g y la tarjeta escribía el WC con cero decimales (95 % + 5,5 % = 100,5 %; la
receta es WC-5,5Co, el 94,5 %).

- **Lo que pide la pieza** (`ClawForge.mix_plan`): el volumen de lo que se hace por la densidad del material (la de
  `ClawMass`, con su fuente) y, de cada polvo, ese total por su fracción en peso de la receta.
  - Lo que se talla de un cristal (la bola de Verneuil, el cristal HPHT): el cilindro que contiene la funda (`rawVolumeMm3`).
  - Lo que sale casi con su forma (el sinterizado y la capa de la CVD): la funda (`volumeMm3`; el sinterizado conserva la masa
    aunque encoja).
  - Lo colado: el modelo de cera con su bebedero (`wax_volume_mm3`, el mismo de `wax()`; antes de la cera, con la cera a la
    medida y el molde de la receta). La colada sigue comprobando `metalG` («poco metal»).
  - El diamante HPHT: el grafito es el carbono del cristal; la carga es ese carbono entre su fracción (30 %), y el grafito nunca
    puede pesar menos que el cristal (`poco_carbono`).
  - La CVD no pesa polvo: el gas entra de la botella. En la balanza se pesa, **por juego**, el carbono de la capa.
- **La tolerancia**: se pesa un 10 % de más (lo que se queda en el plato, el crisol o la tolva) y se admite hasta un 20 % por
  encima de lo que pide la pieza; por debajo no llega. Los dos números son de **juego**. Con la proporción fuera de la receta o
  la masa fuera de ese margen, `mix()` no da la mezcla por buena y la balanza no carga el crisol (lo dice y dice cómo se arregla).
- **Por dentro del margen** (`ClawForge.mix_aims`): cada polvo se pesa para la proporción de la receta, salvo que esté en el
  borde de su margen. El 0,25 % de MgO de la alúmina es su mínimo: apuntando a él, lo que no distingue la balanza (0,1 mg) dejaba
  la mezcla fuera aunque se siguieran los botones. Entonces se apunta un 10 % del margen por dentro (0,275 %; **juego**), las
  proporciones siguen sumando el 100 % y la frase de la balanza y del tutorial lo dice.
- **El arreglo** (`mix_status().fix`): echar lo que falta, en múltiplos de lo que distingue la balanza (nunca «echa 0.0000 g»); con un solo polvo en el plato, quitar lo que sobra (vuelve al tarro con
  la espátula); con varios, ya mezclados, no se separan: compensar echando de los otros si cabe en lo que se admite, o vaciar el
  plato. Un test comprueba que lo que propone deja la mezcla en tolerancia.
- **La balanza**: una analítica de 220 g que distingue 0,1 mg (como la Mettler Toledo ME204): los miligramos de MgO de la alúmina
  (0,25-0,5 %) o de Cr₂O₃ del rubí se pueden pesar. La pantalla, con 4 decimales y la tara (Z). Las dosis de cada polvo y el chorro
  del tarro van con su objetivo (elección de la interfaz).

| Valor | Fuente | Tipo |
|---|---|---|
| Densidades del zafiro, el rubí, el metal duro, la alúmina, el acero, el oro, el titanio, el vidrio y el diamante | `ClawMass.DENSITY` (las suyas) | las de cada dato |
| Fracciones en peso y márgenes de cada receta | las recetas de este documento (§3) | las de cada receta |
| Se pesa un 10 % de más; se admite hasta un 20 % por encima | elección del juego | juego |
| Balanza de 220 g que distingue 0,1 mg | ficha de una balanza analítica (Mettler Toledo ME204) | ficha |
| El carbono de la capa de la CVD en la balanza | elección del juego | juego |
| Se apunta un 10 % del margen por dentro si la receta está en su borde | elección del juego | juego |

**El tutorial, jugable con los mandos (5w).** Los valores que pide cada paso son los que marcan los mandos de la página: el dial del
tiempo va por marcas (el paso dice la primera que llega a lo que tarda la funda: «1 h 30 min», no «1 h 6 min o más») y el de la
temperatura, de 5 en 5 °C (el quemado del revestimiento de fosfato pide 871 °C: el paso dice «875 °C»). Un test juega cada receta
solo con los botones de dosis y los pasos de los diales y llega al final. «Otra pieza» (y otra forma, otra pared u otra garra)
vuelve al primer paso del tutorial; una pieza que ya no se arregla (agrietada al enfriar, agujereada al tallar) lo dice y manda a
«Otra pieza». No cambia ninguna física.

## 16. Fuentes

- Abrisa Technologies. Soda-Lime Float Glass, ficha técnica.
- Bullseye Glass Co. TipSheet 8: Basic lost wax kilncasting (el ciclo típico, el curado del molde y el desmoldeo).
- Campbell J, Harding RA (1994). TALAT Lecture 3206: The feeding of castings. EAA (las reglas del bebedero y la de Chvorinov).
- Diamond Pacific. Genie, ficha (muelas de 6", 80 y 220 metálicas, 280-3000 de resina, 1800 rpm).
- Earnshaw R (1988). The effect of casting ring liners on the potential expansion of a gypsum-bonded investment. *J. Dent.
  Res.* 67(11):1366-1370. doi:10.1177/00220345880670110101
- Ferreira AR, Adabo GL, Peitl Filho O, Soares da Rocha S, Fonseca RG (2007). Evaluation of the thermal shrinkage of
  titanium and the setting and thermal expansion of phosphate-bonded investments. *J. Prosthet. Dent.* 98(1):24-29.
  doi:10.1016/S0022-3913(07)60034-1
- Finger W, Jørgensen KD (1980). An improved dental casting investment. *Scand. J. Dent. Res.* 88(3):278-284.
  doi:10.1111/j.1600-0722.1980.tb01226.x
- Haefeli Diamantwerkzeugfabrik. Grit sizes (FEPA/ISO 6106).
- Hi-Tech Diamond. 6" trim saw, ficha.
- Hollenback GM, Skinner EW (1946). Shrinkage during casting of gold and gold alloys. *J. Am. Dent. Assoc.* 33:1391-1399.
  doi:10.14219/jada.archive.1946.0210
- Hsu HC, Kikuchi H, Yen SK, Nishiyama M (2007). Evaluation of different bonded investments for dental titanium casting.
  *J. Mater. Sci. Mater. Med.* 18(4):605-609. doi:10.1007/s10856-007-2308-2
- Kerr Corporation (2011). Satin Cast 20 / KerrCast 2000, Directions For Use (lit. 34332A).
- Sabau AS, Cannell N (2005). Predicting pattern tooling and casting dimensions for investment casting, phase II. ORNL.
- Shor International. Platinum investment instructions.
- SRS-Goodwin Refractory Services. Burnout guidelines & casting temperatures.
- Alqutaibi AY et al. (2023). Polymeric denture base materials: a review. *Polymers* 15:3258. doi:10.3390/polym15153258
  (recoge a Barbosa DB, Compagnoni MA, Souza RF, Pero AC, *J. Prosthodont.*: el PMMA autopolimerizable).
- ASM Aerospace Specification Metals. Titanio de grado 2 recocido (UNS R50400), ficha (datos de Allvac).
- Assael MJ, Botsios S, Gialou K, Metaxa IN (2005). Thermal conductivity of polymethyl methacrylate (PMMA) and borosilicate
  crown glass BK7. *Int. J. Thermophys.* 26:1595-1605. doi:10.1007/s10765-005-8106-5
- AK Steel. 304/304L Stainless Steel, Product Data Bulletin.
- Andrews AI (1961). Porcelain Enamels. Garrard Press.
- Aspen Aerogels. Pyrogel XTE, ficha técnica.
- Balmer RS et al. (2009). Chemical vapour deposition synthetic diamond: materials, technology and applications. *J. Phys.:
  Condens. Matter* 21:364221. doi:10.1088/0953-8984/21/36/364221
- Bifano TG, Dow TA, Scattergood RO (1991). Ductile-regime grinding: a new technology for machining brittle materials.
  *J. Eng. Ind.* 113:184-189.
- Brazda P (KAPP Technologies) (2006). Hard choices: diamond or CBN? *Gear Solutions*, 1-2-2006.
- Bullseye Glass Co. Tip Sheet 8: Basic lost wax kilncasting.
- CastingQuality. Stainless steel CF8 (SS304).
- Chai H, Lawn BR (2007). A universal relation for edge chipping from sharp contacts in brittle materials. *Acta Mater.*
  55:2555-2561.
- Chase MW (1998). NIST-JANAF Thermochemical Tables, 4.ª ed. *J. Phys. Chem. Ref. Data*, monografía 9 (en el NIST Chemistry
  WebBook).
- Coble RL (1962). Transparent alumina and method of preparation. Patente US 3.026.210.
- CoorsTek. AD-995 alumina, ficha técnica.
- Fernandes CM, Senos AMR (2011). Cemented carbide phase diagrams: a review. *Int. J. Refract. Met. Hard Mater.* 29:405-418.
- Ferreira CMC, Simões BD, Marques EAS, Carbas RJC, da Silva LFM (2024). Exploring adhesive performance in horseshoe bonding
  through advanced mechanical and numerical analysis. *Biomimetics* 10:2. doi:10.3390/biomimetics10010002
- Gateros Plating. Electroforming tutorial.
- Ganoksin. Cracks in jewelry manufacturing; Colored karat golds for investment casting; Wax casting burnout cycles.
- General Carbide. The Designer's Guide to Tungsten Carbide; Grade Specifications.
- Goodfellow. Tungsten Carbide/Cobalt WC 94/Co 6 (AZoM).
- GRAYSTAR. TDS Black Silicon Carbide (2009).
- Groner MD, Fabreguette FH, Elam JW, George SM (2004). Low-temperature Al₂O₃ atomic layer deposition. *Chem. Mater.*
  16:639-645.
- Grossmann, severidad del temple (tabla recogida en ScienceDirect Topics, «Quench severity»).
- Hayashi H, Saitou T, Maruyama N, Inaba H, Kawamura K, Mori M (2005). Thermal expansion coefficient of yttria stabilized
  zirconia for various yttria contents. *Solid State Ionics* 176:613-619. doi:10.1016/j.ssi.2004.08.021
- Haynes WM (ed.) (2014). CRC Handbook of Chemistry and Physics, 95.ª ed.
- Henkel. LOCTITE 401, fichas técnicas (1996 y 2012); The LOCTITE Design Guide for Bonding Metals, vol. 6; Structural
  Adhesives and NVH Selector Guide.
- Hyperion Materials & Technologies. Thermal properties (del metal duro).
- Incropera FP, DeWitt DP, Bergman TL, Lavine AS (2007). Fundamentals of Heat and Mass Transfer, 6.ª ed.
- ISO 14577-1 y 14577-4 (indentación instrumentada; capas).
- ISO 20795-1:2013. Odontología, polímeros de base, parte 1: bases de prótesis dentales.
- ITS-90 (Escala Internacional de Temperatura de 1990).
- Johnson SE et al. (2021). The quartz α↔β phase transition: does it drive damage and reaction in continental crust? *Earth
  Planet. Sci. Lett.* 553:116622.
- Kakkar P, Madhan B, Shanmugam G (2014). Extraction and characterization of keratin from bovine hoof. *SpringerPlus* 3:596.
- Kennedy CS, Kennedy GC (1976). The equilibrium boundary between graphite and diamond. *J. Geophys. Res.* 81:2467-2470.
  doi:10.1029/JB081i014p02467
- Khmelnitsky RA, Gippius AA (2014). Transformation of diamond to graphite under heat treatment at low pressure. *Phase
  Transitions* 87(2). doi:10.1080/01411594.2013.807429
- High temperature graphitization of diamond during heat treatment in air and in a vacuum (2024). *Glass Phys. Chem.*
  doi:10.1134/S1087659624600315
- JXT Semi Technology. Physical vapor transport (PVT) growth process of silicon carbide (SiC) single crystals.
- Kingery WD (1955). Factors affecting thermal stress resistance of ceramic materials. *J. Am. Ceram. Soc.* 38:3-15.
- Komanduri R, Shaw MC (1975). Wear of synthetic diamond when grinding ferrous metals. *Nature* 255:211-213.
- Lu TJ, Fleck NA (1998). The thermal shock resistance of solids. *Acta Mater.* 46:4755-4768 (recoge a Manson SS (1966),
  Thermal Stress and Low-Cycle Fatigue, McGraw-Hill).
- Malkin S, Guo C (2007). Thermal analysis of grinding. *CIRP Annals* 56:760-782 (el reparto del calor, en la cetrería).
- Matta T, Eshar D, Nau MR (2022). Surgical repair of a rostral maxillary beak fracture using an improvised metal implant
  scaffolding and dental acrylic prosthesis in a pet double yellow-headed Amazon parrot (*Amazona ochrocephala oratrix*).
  *Israel J. Vet. Med.* 77(4):213-221.
- Morgan Technical Ceramics. Thermal shock resistance.
- Nassau K (1980). Gems Made by Man. Chilton.
- Nassau K (1981). Cubic zirconia: an update. *Gems & Gemology* 17:9-19. doi:10.5741/GEMS.17.1.9
- NIST Chemistry WebBook (SRD 69): diamante (Victor 1962) y poli(metacrilato de metilo) (Melia 1962), capacidad calorífica
  del sólido a 298,15 K.
- Oerlikon Balzers. BALINIT A (TiN).
- Northeast Waste Management Officials' Association (2003), recogido en Wikipedia, «Chrome plating» (baño del cromo duro);
  U.S. Chrome Corporation (espesores); ScienceDirect Topics, «Hard chromium» (dureza).
- Patente US 4.505.720 (el carburo de silicio contra el acero).
- SAE AMS 4763. Silver alloy, brazing filler metal 56Ag-22Cu-17Zn-5Sn, 618-652 °C.
- Roditi. Ruby laser rods.
- Saint-Gobain Crystals. Sapphire Products (2016-2018); Saint-Gobain, Hexoloy SA.
- Samour J (2006). Management of raptors. En Harrison GJ, Lightfoot TL (eds.), Clinical Avian Medicine, vol. II, cap. 40,
  pp. 915-956. Spix Publishing (las reparaciones del pico, pp. 927-928).
- Scheel HJ (2000). Historical aspects of crystal growth technology. *J. Cryst. Growth* 211:1-12.
- Schneider JM, Sproul WD, Chia RWJ, Wong MS, Matthews A (1997). Very-high-rate reactive sputtering of alumina hard coatings.
  *Surf. Coat. Technol.* 96:262-266.
- Shin-Etsu. Characteristic properties of silicone rubber compounds; AZoM, Silicone rubber.
- Sumiya H, Toda N, Satoh S (2002). Growth rate of high-quality large diamond crystals. *J. Cryst. Growth* 237-239:1281-1285.
- Chan KS, Koike M, Johnson BW, Okabe T (2008). Modeling of alpha-case formation and its effects on the mechanical properties
  of titanium alloy castings. *Metall. Mater. Trans. A* 39:171-180. doi:10.1007/s11661-007-9406-0
- The Gemology Project. Flame fusion.
- Tribological and optical properties of crystalline and amorphous alumina thin films grown by low-temperature reactive magnetron
  sputter-deposition (2001). *Surf. Coat. Technol.*
- Tydex. Synthetic crystal quartz.
- Wortmann FJ, Wortmann G, Marsh J, Meinert K (2012). Thermal denaturation and structural changes of α-helical proteins in
  keratins. *J. Struct. Biol.* 177:553-560.
- Yan C-S, Vohra YK, Mao H-K, Hemley RJ (2002). Very high growth rate chemical vapor deposition of single-crystal diamond.
  *PNAS* 99:12523-12525. doi:10.1073/pnas.152464799
- Zafar MS (2020). Prosthodontic applications of polymethyl methacrylate (PMMA): an update. *Polymers* 12:2299.
  doi:10.3390/polym12102299
- Effect of the substrate temperature on properties of plasma sprayed Al₂O₃ coatings (2004). *Materials & Design*.
- Effect of the thickness on properties of Al₂O₃ coatings deposited by plasma spraying (2010). *Materials Characterization*.
