# Unidad 8 · Sonido de máquina

Sonido del **Taller industrial**: torno, fresadora, taladro, radial (también cortando chapa de carrocería, como en
los rescates) y afiladora. Qué frecuencias suenan, con qué nivel y por qué, con sus fuentes. Lo que no tiene
medición publicada va marcado como **estimación**.

## Cómo funciona

| Pieza | Archivo | Qué hace |
|---|---|---|
| DSP compartida | `godot/core/shared/dsp.gd` | Port 1:1 de los bloques de `packages/core/src/sfx.js`: biquad RBJ, banda de ruido con modulación, tono con barrido, resonancia modal, chasquidos, envolventes, `finish` y WAV PCM de 16 bits. Añade bloques para bucles: senos exactamente periódicos, ruido rosa y costura con fundido. |
| Función de marco | `godot/core/taller/machine_sound.gd` | Función **pura** de la entrada de sonido de `CONTRATOS.md` a un marco `{ tones, noise, crackle_rate, chatter, coolant_gain, master_gain, pan, … }`. `voices()` lo traduce a cada bucle: `pitch_scale`, volumen y filtros del bus. Cada ficha de catálogo (`MACHINES`, `KIND`, `GRINDER_KIND`, `DISCS`, `SHEET`) lleva `source` y `quality`. |
| Horneado | `godot/tools/bake_sounds.gd` | Genera los 14 bucles y los 4 granos de `godot/assets/sfx/taller/`. Toma las frecuencias del marco de referencia de cada bucle. Es determinista y la costura no hace clic. |
| Reproductor | `godot/app/taller/machine_sound_player.gd` | Aplica el marco 60 veces por segundo, con suavizado exponencial (volumen 50 ms, tono 80 ms, filtros 80 ms). |
| Demostración | `godot/app/taller/demo_sonido.tscn` | Guion determinista de 12,5 s con el torno y la radial. |
| Buses | `godot/default_bus_layout.tres` | Ver [«Buses»](#buses). |

- **En tiempo real no se calcula nada muestra a muestra en GDScript**, porque en móvil sería lento. Solo suenan
  bucles horneados, y el reproductor mueve el mezclador de Godot: volumen, `pitch_scale` y filtros de bus.
- **Todo el audio es el de Godot:** WASAPI en Windows, CoreAudio en macOS e iOS, PulseAudio o ALSA en Linux, y
  el driver propio en Android. No hace falta ningún componente del sistema. Los bucles son WAV PCM sin comprimir,
  que se importan igual en todas las plataformas.

### Por qué los bucles cambian de tono sin romper la física

- **Lo que gira con el husillo va en un solo bucle por máquina:** 1×, 2×, engranes, rotor y ventilador. Todas
  esas frecuencias son múltiplos de n/60, así que un mismo `pitch_scale = n/n_ref` las mueve juntas y sin error.
- **El paso de garras, dientes o segmentos va en un bucle aparte**, horneado sin resonancias fijas. Así su
  `pitch_scale` vale para cualquier número de garras o de dientes:
  - las garras son aire, y su espectro escala con la velocidad igual que el bucle;
  - dientes y segmentos son un tren de impulsos armónico con ruido de banda ancha;
  - el timbre del material lo pone la banda del corte, que no se transpone.
- **El zumbido del motor tiene tono fijo** (2·f de red). No depende del giro del husillo.
- **Los modos de la chapa escalan todos con h·c_p.** Un solo `pitch_scale` pasa del acero de 0,8 mm al aluminio de
  1 mm.
- **El corte es ruido rosa filtrado en tiempo real** por un paso banda de bus con el `fc` y el `Q` del marco. Con
  ruido rosa, la potencia que deja pasar un paso banda de Q fijo no depende de `fc`: el volumen se compensa de
  forma analítica. Para que la compensación valga, `fc` se acota a 300–6500 Hz, dentro del ruido horneado.
- **El tono de referencia de cada bucle no se copia a mano.** `loop_ref_hz()` lo saca del marco de la misma
  entrada de referencia con la que se hornea el bucle, y un test comprueba con la DFT que cada bucle tonal tiene
  su pico ahí.
- **Las voces nunca pasan de 0 dB.** `voices()` entrega los volúmenes 12 dB por debajo y el bus «Maquina» los
  recupera con un `AudioEffectAmplify` de +12 dB. Así el tope `max_db = +6 dB` de `AudioStreamPlayer3D` no
  aplasta el corte más fuerte, y 2D y 3D suenan igual.
- **El tono no se desliza mientras la voz está callada.** Una voz que entra desde el silencio va directa a su tono,
  y una que se apaga lo conserva. Por eso el chatter entra sin barrido.

## Modelo físico del marco

| Componente | Frecuencia / ley | Nivel | Fuente | Calidad |
|---|---|---|---|---|
| Giro del husillo | n/60 (1×) y 2× | ∝ (n/n_ref)¹, en la radial (n/n_ref)² | 1× desequilibrio y 2× desalineación: ISO 13373-3; Randall (2011) | secundaria (frecuencias); estimación (niveles) |
| Paso de garras | garras·n/60 | ∝ (n/n_ref)³ | Fuente aerodinámica dipolar, potencia ∝ U⁶ (Curle 1955). Ruido de rotores: Gutin (1936) | secundaria; estimación (nivel absoluto) |
| Paso de dientes (fresa) y labios (broca) | z·n/60 | ∝ √(Pc/Pmáx) | Frecuencia de paso de dientes (Altintas 2012, cap. 2 y 3) | primaria (frecuencia); estimación (nivel) |
| Engrane | z_engranaje·n/60 y 2× | con el giro | Frecuencia de engrane (Smith 2003; Randall 2011) | primaria (frecuencia). Los dientes (47 en el torno, 31 en la fresadora, 33 en la corona de la radial) son **estimación** |
| Motor de inducción | 2·f de red y múltiplos pares: 100, 200, 300, 400 y 600 Hz a 50 Hz | +30 % a plena carga | Fuerzas de Maxwell ∝ B², a 2f y armónicos pares (Gieras, Wang y Lai 2006); f = 50 Hz (EN 50160) | secundaria (frecuencias); estimación (amplitudes y efecto de la carga) |
| Motor universal (radial) | rotor a 3× el disco (corona 33/11), ventilador de 9 álabes (27×) y 2f débil | con el giro | Par pulsante a 2f en motores monofásicos (Chapman 2012) | estimación (relación y álabes) |
| Caída del giro con la carga | n = n₀·(1 − droop·carga) | — | Inducción: deslizamiento nominal del 3 al 5 % (catálogos de motores IEC 60034; aquí 4 %). Universal: característica serie, el giro cae mucho con el par (Chapman 2012) | secundaria (inducción); **estimación** (universal, 30 % a plena carga) |
| Banda del corte | fc según el material · √(vc/vc_ref), acotado entre 0,6 y 1,6 | eficaz ∝ √(Pc/Pmáx): la potencia acústica, proporcional a la de corte | La potencia sonora es proporcional a la mecánica con un rendimiento acústico constante: hipótesis del modelo | **estimación** (fc, Q y exponente) |
| Crujido de viruta | viruta que sale a vc/λ y se rompe cada chip_mm | ∝ √(Pc/Pmáx) | Formas de viruta: ISO 3685:1993, anexo G. Relación de compresión λ de 1,5 a 4 en aceros (Trent y Wright 2000) | orden cualitativo: secundaria; longitudes: **estimación** |
| Chatter | f_c = f_n·√(1+2ζ), en el mínimo del lóbulo. Bandas a f_c ± f_tp | smoothstep(1; 1,5; b/b_lim) | Tlusty y Polacek (1963); Altintas (2012, cap. 3); frecuencias múltiples en fresado (Insperger et al. 2003); el chatter se oye como un pico no síncrono (Delio, Tlusty y Smith 1992) | primaria (modelo); ζ = 3 %: **estimación** (rango típico del 1 al 5 %) |
| Refrigerante | bomba de 2800 rpm (46,7 Hz) y 6 álabes (280 Hz), más un chorro de ruido y gotas | constante | Frecuencia de paso de álabes z·n/60 (Brennen 1994) | estimación (bomba concreta) |
| Chapa que vibra (radial) | modos impar-impar de una placa apoyada de 300 × 200 × 0,8 mm (acero), con f_mn de Kirchhoff | ∝ √(Pc/Pmáx)·ring·√(h_ref/h) | Kirchhoff y Leissa (1969, NASA SP-160); los modos impar-impar son los que mejor radian (Wallace 1972) | primaria (fórmula); panel y espesores: **estimación** |
| Paneo | tool_pos.x / 0,75 m | — | decisión de diseño | — |
| Nivel de cada máquina | 10^(0,5·(L − 97)/20) | — | L en dB(A) a 1 m: radial ≈ 91, en el orden de lo que declaran los fabricantes según EN 62841-2-3; resto, **estimación** | secundaria o estimación |

Comprobación del modelo de la chapa: el modo (1,1) del panel de referencia sale a **71 Hz**, y el modo clave
(5,3) a **988,9 Hz**. El aluminio de 1 mm sube los modos ×1,244 (clave a 1229,8 Hz). El plástico PP de 3 mm los
deja en ×0,924, pero su amortiguamiento (η ≈ 0,08 frente a 0,01) casi apaga el «ring».

### Radial cortando chapa: qué cambia con el material y el disco

La radial es la de 125 mm a 11.000 rpm. En vacío, el disco suena a **183,3 Hz**. Su velocidad periférica es de
72 m/s; EN 12413 marca 80 m/s como máximo para estos discos.

- **Acero:** chirría. Banda de corte a 5,2 kHz con Q = 3,5, «ring» completo y unas 120 chispas por segundo a
  plena carga (proporcionales a la carga).
- **Aluminio:** más apagado, porque embota el disco. Banda a 2,4 kHz con Q = 1,2, paso bajo a 6 kHz, 60 % de
  «ring» y pocas chispas.
- **Plástico:** se funde. Banda a 850 Hz con Q = 0,8, paso bajo a 2,5 kHz, sin chispas y casi sin «ring».
- **Disco:**
  - `fino_1mm` es la referencia.
  - `grueso_3mm` suena más grave y áspero y más fuerte, y roza más: suma 0,15 de carga, así que frena más el
    motor.
  - `diamante` suena más agudo y con menos chispas, y silba a segmentos·n/60 (10 segmentos: 1833 Hz).
  - `laminas` desbasta en vez de cortar: banda baja y ancha, con la mitad de «ring».
  - El disco se aplica igual sobre los materiales sin ficha de radial (piedra, vidrio, madera…), que usan la
    banda general subida un 50 %.
- **Bajada de rpm bajo carga:** 30 % a plena carga, que es una estimación. Con disco fino a media carga cae a
  9350 rpm (155,8 Hz); forzado, hacia 7700 rpm.

Todos los valores de esta sección son **estimación**, salvo la fórmula de los modos y las propiedades de los
materiales.

## Tabla de estimaciones

| Dato | Valor | Motivo |
|---|---|---|
| Dientes de engranajes y álabes | torno 47, fresadora 31, corona de la radial 33 (piñón 11), ventilador de 9 álabes | Ejemplos plausibles, no de una máquina concreta |
| Amplitudes relativas del husillo y del motor | ver `MACHINES` y `MOTOR_HUM` | Sin medición publicada por máquina |
| Nivel en vacío | torno y fresadora 78, taladro 75, afiladora 80 y radial 91 dB(A) a 1 m | ISO 230-5 define el ensayo, pero cada máquina da su valor |
| Compresión de niveles | la mitad de la escala en dB | Para que el torno no quede inaudible junto a la radial |
| Caída de giro | 30 % del motor universal a plena carga | Sin datos de fabricante del giro en carga |
| Banda del corte | fc, Q, paso bajo y ganancia por material | Sin medición publicada que lo cuantifique para este banco |
| Largo de viruta rota y λ | ver `KIND` | Orden cualitativo de ISO 3685; los valores son ilustrativos |
| Chispas de la radial | acero 120/s, inox 90/s, aluminio 12/s, plástico 0 | — |
| Discos | factores de `DISCS`; 10 segmentos en el de diamante | — |
| Panel de chapa y espesores | 300 × 200 mm; acero 0,8 mm, aluminio 1,0 mm, PP 3,0 mm | Valores típicos de carrocería, sin una pieza concreta |
| Amortiguamiento de la chapa | acero 0,01, aluminio 0,012, PP 0,08 | Del orden de los factores de pérdidas de Cremer, Heckl y Petersson (2005) |
| ζ del chatter | 3 % | Rango típico del 1 al 5 % |
| Bomba de refrigerante | 2800 rpm, 6 álabes | — |

## Bucles horneados

WAV PCM de 16 bits, mono, 22.050 Hz, en `godot/assets/sfx/taller/`, unos 0,9 MB en total. Las duraciones dan
ciclos enteros de todos los tonos, así que la costura es exacta.

| Bucle | Tono clave | Contenido |
|---|---|---|
| `motor` | 100 Hz | 2f, 4f, 6f, 8f y 12f, más el soplo del ventilador |
| `spindle_lathe` | 20 Hz (1200 rpm) | 1×, 2×, engrane 47× (940 Hz) y 94× |
| `spindle_mill` | 50 Hz (3000 rpm) | 1×, 2×, engrane 31× y 62× |
| `spindle_drill` | 16,7 Hz (1000 rpm) | 1×, 2× y 3× |
| `spindle_grinder` | **183,3 Hz** (11.000 rpm) | 1× y 2× del disco, rotor 3× (550 Hz) y 6×, ventilador 27× (4950 Hz), engrane 33× (6050 Hz) y escobillas |
| `spindle_sharpener` | 47,5 Hz (2850 rpm) | 1×, 2× y 3× |
| `jaws` | 60 Hz (3 garras a 1200 rpm) | soplo de las garras: armónicos suaves y ruido pulsado |
| `teeth` | **200 Hz** (4 dientes a 3000 rpm) | tren de impactos en coseno |
| `segments` | 1833,3 Hz (10 segmentos a 11.000 rpm) | silbido de los segmentos |
| `cut` | — | ruido rosa de 100 Hz a 10 kHz con modulación «stick-slip» (valor eficaz 0,18) |
| `sheet` | modo (5,3) a 988,9 Hz | 16 modos impar-impar (Q = 1/η = 100) excitados por unos 1500 impactos/s |
| `chatter` | 1000 Hz | tono con 2.º y 3.º armónico y un vaivén de 5 Hz |
| `coolant` | 46,7 Hz | bomba, álabes a 280 Hz, chorro y gotas |
| `crackle` | — | chasquidos densos (200/s) |
| `chip_0` … `chip_3` | — | granos de viruta, sin bucle |

Cómo regenerarlos, desde la raíz:

```bash
node godot/tools/godot.mjs run --headless --script res://tools/bake_sounds.gd
npm run godot:import
```

El horneado deja cada `.import` con bucle hacia delante, PCM sin comprimir y `edit/loop_end` igual al número de
muestras. El test `test_wav_del_repo_al_dia` falla si el WAV del repositorio no coincide con el que sale de
hornearlo en memoria.

## Buses

| Bus | Envía a | Efectos |
|---|---|---|
| `Master` | — | limitador (ya estaba) |
| `Maquina` | `Master` | ganancia de +12 dB (recupera el margen de las voces), paso alto a 25 Hz (quita los infrasonidos de los bucles bajados de tono) y panoramizador (paneo del marco en vistas 2D; en 3D queda en 0) |
| `MaquinaCorte` | `Maquina` | paso banda de una etapa (fc, `resonance` = Q/2) y paso bajo que apaga los materiales blandos |

Los filtros del bus son compartidos: suena **una máquina a la vez**.

## Hallazgos de Godot 4.7.2 (medidos con Movie Maker)

- **Paso banda de bus.** En `AudioEffectBandPassFilter`, Q vale 2·`resonance` y la ganancia de pico √(Q+1). Con
  un seno en fc salen √2 con `resonance` 0,5 y √5 con 2,0, exactos. La potencia de ruido que deja pasar sigue el
  ancho de banda equivalente π·fc/(2Q). `voices()` compensa con eso el volumen del corte.
- **`loop_end` de los WAV importados.** `edit/loop_end = -1` se importa como N − 1, y la reproducción trata
  `loop_end` como exclusivo: en cada vuelta se pierde la última muestra. Con un seno de 1 kHz aparece un salto de
  fase de 16° cada 1,2 s. Con `edit/loop_end = N` explícito no hay salto. El horneado escribe ese valor y un test
  lo vigila.
- **WAV de Movie Maker.** Sale a 48 kHz, estéreo y PCM de 32 bits, sea cual sea la frecuencia de mezcla del
  proyecto.
- **`max_db` de `AudioStreamPlayer3D`.** Topa la suma de `volume_db` y la atenuación por distancia (+6 dB por
  defecto). Si una voz pide más, deja de crecer. De ahí el margen de 12 dB de las voces.
- **Reproducciones vivas al salir.** Si el programa se cierra con bucles sonando (por ejemplo, con
  `--quit-after`), Godot avisa de objetos y recursos «filtrados»: el servidor de audio ya no mezcla y no suelta
  las reproducciones. Para evitarlo:
  - la demo acaba en silencio y llama a `stop_now()`;
  - el reproductor de granos se para cuando queda libre.
- **Granos reproducibles.** `AudioStreamRandomizer` usa el aleatorio global de Godot, que se siembra solo al
  arrancar, así que las capturas no serían reproducibles. Los granos se disparan con `core/shared/rng.gd` sobre un
  `AudioStreamPolyphonic`.

## Verificación

### Tests

`npm run godot:test` da 36 tests y 0 fallidos (20 de esta unidad):

- **Port de la DSP:** los 22 efectos de la 1.x, rehechos con `dsp.gd`, dan **el mismo sha256** que
  `tests/fixtures/sfx.json`, byte a byte.
- **DFT de los bucles horneados, con un margen de ±2 %.** Los cinco picos salen en el bin exacto, con prominencia
  de más de 20 dB:

  | Bucle | Frecuencia |
  |---|---|
  | Radial a 11.000 rpm | 183,3 Hz |
  | Fresa de 4 dientes a 3000 rpm | 200 Hz |
  | Paso de garras (3 garras a 1200 rpm) | 60 Hz |
  | Engrane del torno | 940 Hz |
  | Segmentos del disco de diamante | 1833 Hz |

  Además, el rotor de la radial sale a 550 Hz y el motor a 100 Hz, y cada bucle tonal tiene su pico donde dice
  `loop_ref_hz()`.
- **Marco monótono:** más Pc da más ganancia de corte en los 5 procesos y los 11 materiales. Sin corte, la
  ganancia de corte, la viruta, el chatter y la chapa valen 0.
- **Marco puro:** con la misma entrada sale el mismo marco, y la entrada no se modifica.
- **Radial:** cambia según el material y el disco, también en materiales sin ficha propia. El giro baja con la
  carga y nunca pasa a negativo, y las chispas son proporcionales a la carga.
- **Fichas:** todas llevan `source` y `quality`.
- **Banda del corte:** siempre dentro del ruido horneado.
- **Chatter:** cerca del modo y no síncrono.
- **Voces:** `pitch · ref_hz` coincide con el tono clave y el volumen con master · margen · ganancia / nivel.
- **Costura y saturación:** el salto en la costura no supera el percentil 99,9 de los saltos entre muestras, y
  ningún bucle satura.
- **Determinismo:** hornear dos veces da el mismo sha256.
- **WAV del repositorio:** están al día.
- **Importación:** bucle hacia delante, `loop_end = N`, 16 bits y 22.050 Hz. Los granos llegan exactamente al pico
  de 0,9.
- **Buses:** `Maquina` (con su ganancia de recuperación) y `MaquinaCorte`, con sus filtros.

### e2e

Comando de captura:

```bash
npm run godot:capture -- res://app/taller/demo_sonido.tscn --frames=375 --out=<carpeta>
```

Son 375 fotogramas porque el guion dura 12,5 s: el encargo pedía de 8 a 10 s, y el coordinador añadió el tramo
de la radial. Un script de Node, fuera del repositorio, analiza `f.wav` frente a `demo_previsto.json`, que la demo
escribe junto al vídeo con el marco previsto de cada ventana. Mide la DFT (Hann, relleno hasta 2¹⁹) y el valor
eficaz por ventanas.

| Tramo | Componente | Previsto (Hz) | Medido (Hz) | Error |
|---|---|---|---|---|
| Torno en vacío, 1200 rpm | paso de garras 3·n/60 | 60,00 | 59,99 | −0,02 % |
| | motor 2·f de red | 100,00 | 100,00 | 0,00 % |
| | motor 4·f de red | 200,00 | 200,00 | 0,00 % |
| | engrane 47·n/60 | 940,00 | 939,67 | −0,04 % |
| Acero, Pc de 1,3 kW | paso de garras (con la caída de giro) | 59,42 | 59,48 | +0,10 % |
| | engrane | 930,94 | 931,98 | +0,11 % |
| Acero, Pc de 2,8 kW | paso de garras | 58,77 | 58,84 | +0,12 % |
| | engrane | 920,69 | 921,48 | +0,09 % |
| Aluminio, 2400 rpm | paso de garras | 118,43 | 118,29 | −0,12 % |
| | engrane | 1855,39 | 1853,47 | −0,10 % |
| | motor 2·f de red | 100,00 | 99,99 | −0,01 % |
| Chatter (modo de 820 Hz) | f_c = f_n·√(1+2ζ) | 844,24 | 844,22 | 0,00 % |
| | banda f_c − n/60 | 824,53 | 824,56 | 0,00 % |
| | banda f_c + n/60 | 863,95 | 863,96 | 0,00 % |
| Refrigerante | álabes de la bomba | 280,00 | 279,99 | 0,00 % |
| | giro de la bomba | 46,67 | 46,66 | −0,01 % |
| Radial en vacío | disco 1× | 183,33 | 183,11 | −0,12 % |
| | rotor 3× | 550,00 | 549,33 | −0,12 % |
| Radial, corte limpio | disco 1× (caído a 9350 rpm) | 155,83 | 155,85 | +0,01 % |
| | rotor 3× | 467,50 | 467,58 | +0,02 % |
| | chapa: modo clave (5,3) | 988,89 | 988,75 | −0,01 % |
| Radial, corte sucio | rotor 3× (centroide, porque el giro oscila) | 382,68 | 380,91 | −0,46 % |

Todos los picos superan su entorno en 17 dB o más. El chatter no es síncrono: 844,2 Hz son 42,2 vueltas de
20 Hz.

Niveles medidos:

| Tramo | Pc/Pmáx | Valor eficaz (dBFS) | Pico (dBFS) |
|---|---|---|---|
| Torno parado | 0 | −240 | −240 |
| Torno en vacío | 0 | −32,6 | −24,0 |
| Acero 1 | 0,24 | −25,2 | −13,2 |
| Acero 2 | 0,38 | −23,2 | −11,5 |
| Acero 3 | 0,51 | −22,2 | −10,8 |
| Aluminio | 0,33 | −23,5 | −10,7 |
| Chatter | 0,36 | −21,0 | −8,4 |
| Refrigerante | 0,44 | −22,4 | −10,8 |
| Radial en vacío | 0 | −26,6 | −15,7 |
| Radial, corte limpio | 0,50 | −17,9 | −5,5 |
| Radial, corte sucio | 1,01 | −14,9 | −2,3 |

Comprobaciones:

- El valor eficaz sube con Pc en el acero.
- El torno en vacío queda 7,4 dB por debajo del primer tramo de corte.
- La radial corta con 8,7 dB más que en vacío, y el corte sucio suena 3 dB más que el limpio.
- El giro de la radial baja: 183,3 Hz en vacío, 155,8 Hz en el corte limpio y unos 128 Hz de media en el sucio.
- El pico máximo es de 0,77, sin muestras a fondo de escala: el limitador del Master no actúa.
- Centroide espectral: el acero da 3,2 kHz y el aluminio 2,1 kHz, que suena más apagado. El corte limpio de la
  radial da 4,0 kHz y el sucio 3,3 kHz, más grave y áspero.
- Resultado: 28 de 28 comprobaciones correctas.

## Para el coordinador

1. **Contrato de la entrada de sonido.** Esta unidad acepta campos opcionales que conviene añadir a
   `CONTRATOS.md`:
   - `disc_id`: `fino_1mm`, `grueso_3mm`, `diamante` o `laminas`; la radial, de la unidad 6;
   - `sheet_mm`: espesor de la chapa;
   - `vc` en m/min, o `diameter_mm` para calcularla;
   - `mains_hz`, 50 por defecto;
   - `speed_droop`: 0 si un variador regula el giro, como en el torno CNC Fagor, y el motor no cae con la carga.
2. **Semántica que he supuesto; confirmadla en el contrato:**
   - `rpm` es el giro sin carga. El marco aplica la caída del motor; si el torno ya calcula el giro real, que pase
     `speed_droop: 0`.
   - `chatter.risk = b/b_lim`, la profundidad frente a la de estabilidad de los lóbulos: es estable por debajo de
     1 y el chatter está desarrollado a 1,5.
   - `tool_pos` va en metros, en el sistema local del nodo de sonido, con x a la derecha del operario (Z del
     torno).
3. **`npm run godot:bake`.** Propongo añadir a `package.json` (no lo toco) este script:
   `node godot/tools/godot.mjs run --headless --script res://tools/bake_sounds.gd`. Ojo: `godot.mjs run` no
   reenvía el separador `--`. El horneado acepta `--check` en cualquiera de las dos listas de argumentos.
4. **Una máquina a la vez.** Los filtros de `MaquinaCorte` son compartidos. Si el taller necesitara dos máquinas
   sonando juntas, cada reproductor tendría que crear su propio bus.
5. **Integración 3D (unidad 9) y taller (unidad 13).** Crear `MachineSoundPlayer`, fijar `chuck_position` y
   llamar a `set_input()` cuando cambie el estado de la máquina. En vistas sin `Camera3D`, poner `use_3d = false`.
6. **Pmáx.** Los valores por defecto son 5,5 kW en el torno, 3 kW en la fresadora, 1,1 kW en el taladro, 0,72 kW
   en la radial y 0,37 kW en la afiladora. Conviene que cada máquina pase el suyo.

## Referencias

- Altintas, Y. (2012). *Manufacturing Automation: Metal Cutting Mechanics, Machine Tool Vibrations, and CNC
  Design*, 2.ª ed. Cambridge University Press.
- Brennen, C. E. (1994). *Hydrodynamics of Pumps*. Oxford University Press.
- Bristow-Johnson, R. *Audio EQ Cookbook* (fórmulas de los biquad; W3C Working Group Note).
- Chapman, S. J. (2012). *Electric Machinery Fundamentals*, 5.ª ed. McGraw-Hill.
- Cremer, L., Heckl, M., Petersson, B. A. T. (2005). *Structure-Borne Sound*, 3.ª ed. Springer.
- Curle, N. (1955). The influence of solid boundaries upon aerodynamic sound. *Proc. R. Soc. A* 231, 505–514.
- Delio, T., Tlusty, J., Smith, S. (1992). Use of audio signals for chatter detection and control. *ASME J. Eng.
  Ind.* 114(2), 146–157.
- EN 50160. Características de la tensión suministrada por las redes generales de distribución (50 Hz).
- EN 12413. Requisitos de seguridad para productos abrasivos aglomerados (velocidad máxima de los discos).
- EN 62841-2-3. Herramientas eléctricas portátiles: amoladoras (código de ensayo de ruido).
- Gieras, J. F., Wang, C., Lai, J. C. (2006). *Noise of Polyphase Electric Motors*. CRC Press.
- Gutin, L. (1936). On the sound field of a rotating propeller (traducción: NACA TM 1195, 1948).
- IEC 60034-1. Máquinas eléctricas rotativas: características asignadas y de funcionamiento.
- Insperger, T., Stépán, G., Bayly, P. V., Mann, B. P. (2003). Multiple chatter frequencies in milling
  processes. *J. Sound Vib.* 262(2), 333–345.
- ISO 230-5. Código de ensayo de máquinas herramienta: emisión de ruido.
- ISO 3685:1993. Ensayo de vida de herramientas de torneado (anexo de formas de viruta).
- ISO 13373-3. Vigilancia del estado de máquinas: guía para el diagnóstico de vibraciones.
- Kellet, P. Filtro de ruido rosa (musicdsp.org, «pink noise filter», versión refinada).
- Leissa, A. W. (1969). *Vibration of Plates*. NASA SP-160.
- Randall, R. B. (2011). *Vibration-based Condition Monitoring*. Wiley.
- Smith, J. D. (2003). *Gear Noise and Vibration*, 2.ª ed. Marcel Dekker.
- Tlusty, J., Polacek, M. (1963). The stability of machine tools against self-excited vibrations in machining.
  *ASME International Research in Production Engineering*, 465–474.
- Trent, E. M., Wright, P. K. (2000). *Metal Cutting*, 4.ª ed. Butterworth-Heinemann.
- Wallace, C. E. (1972). Radiation resistance of a rectangular panel. *J. Acoust. Soc. Am.* 51(3B), 946–952.
