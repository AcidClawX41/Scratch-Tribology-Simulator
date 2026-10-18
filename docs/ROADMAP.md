# Hoja de ruta

Tareas priorizadas, pensadas para abordarse **una por PR**. Cada una indica qué hay que
verificar para darla por terminada. Marca con `[x]` al completar.

## P1 · Arquitectura y calidad

- [x] **Dividir `apps/desktop/src/App.jsx` en tarjetas.** `src/cards/*` (el cuaderno va dentro de
  `BadgesCard`) y el estado en el hook `useLab()` (`src/hooks/useLab.js`), que además centraliza los
  temporizadores del ensayo (antes un ensayo viejo podía vaciar o terminar antes de tiempo el nuevo).
- [x] **Compartir la lógica de estado con móvil.** `createLabHook(React)` en `@sts/core`
  (sin dependencias: cada app le pasa sus hooks). Estado, logros, cuaderno y sonidos idénticos.
- [ ] **Mover el corte de la puerta a `@sts/core`** como grafo de escena. El del coche ya está
  (`carSectionArt`, con la carrocería de cada coche) y el de la piel también.
- [ ] **Tests de UI en CI.** Playwright contra `vite preview`: recorrer manicura, garras,
  punción e impacto; fallar si hay errores de consola. Añadir un job a `.github/workflows/ci.yml`.
- [ ] **Generar el artefacto autocontenido** desde el código real
  (script que empaquete core + desktop en un único `.jsx`), para retirar `legacy/`.

## P1 · Física

- [ ] **Aguijones de insectos** (abeja melífera, avispa común, avispón europeo, abejorro,
  hormiga bala). Datos en `docs/FISICA.md` → "pendientes de integrar".
  Retos: fuerzas en **mN**, así que hace falta bajar `FMIN` (p. ej. 0,001 N) o un deslizador
  por escala. Modelar el **gradiente de dureza** de la punta y las púas de la abeja
  (se queda clavada: el aguijón es de un solo uso).
  *Verificación:* tests de que la abeja perfora piel con ~2–3 mN y de que ningún aguijón raya
  sólidos duros.
- [x] **Impacto más físico.** El ×4 fijo pasa a energía cinética ½·m·v² por garra y trabajo de
  penetración ∫F·dh (modelo v2; víboras con datos de Estrada 2026 y Penning 2016).
- [x] **Humedad de la queratina.** Interruptor "húmeda": ×0,2 en dureza y módulo de uña natural y
  garras (Farran 2009; Bonser en McKittrick 2012).
- [ ] **Ángulo de ataque explícito** como parámetro. v2 ya usa el semiángulo de la punta (`alpha`)
  para la geometría y el modo de abrasión; falta el ángulo con que se presenta la garra al rayar.
- [ ] **Rotura de uñas por flexión.** Una stiletto se parte mucho antes de 30 N. Hace falta el
  espesor, la longitud libre y la resistencia a flexión de uña, gel y acrílico (buscar fuentes).
- [ ] **Recuperación elástica** de los polímeros (barniz, ABS): la profundidad mostrada es bajo carga.
- [x] **Perforación de chapa fina.** Coches (clásico, moderno, aluminio, plástico) y puerta de
  aluminio: indentación hasta romper la chapa y pétalos de Wierzbicki (1999) después; perforar y
  atravesar son etapas distintas (FISICA.md, apartado 14).
- [x] **Vidrio de ventana que se parte por flexión** (Roark + EN 572-1), con la fuerza de pico del
  golpe amortiguada por el tejido blando (apartado 15).
- [ ] **Abolladura de chapa.** La energía que sobra de un golpe que no perfora (un zarpazo de oso
  contra el acero) abollaría la puerta. Nippon Steel (2013) trata la resistencia a la abolladura;
  falta un modelo con carga y energía de abolladura medidas.
- [ ] **Ventanillas templadas y parabrisas laminado.** El templado (120 MPa, EN 12150-1) estalla
  en trozos pequeños cuando una punta dura atraviesa su capa comprimida; el laminado se agrieta
  pero no cae.
- [ ] **Rotura de garras reforjadas frágiles** (cuarzo, zafiro) al golpear metal: hoy solo se
  rompen los colmillos (30 N).
- [ ] **Fractura de frágiles:** umbral de Lawn-Evans y grietas de Hertz (anillo/cono, ley de
  Auerbach) en vidrio, cuarzo y gemas. Hoy una punta roma y dura (uña maciza de zafiro o diamante
  con forma cuadrada) se queda en "roza sin marcar" por contacto elástico, cuando al deslizar
  podría abrir grietas. Hace falta la constante de Auerbach medida de cada material.
- [ ] **Esmalte de la punta del colmillo** (más duro que la dentina): falta su dureza medida.
- [x] **Piel por capas.** Capa córnea, epidermis, dermis, grasa, fascia y músculo con espesores,
  rigidez y tenacidad medidos; rasguños, arañazos que sangran, desgarros, laceraciones y punciones
  que dicen en qué capa queda la punta (FISICA.md, apartado 7).
- [ ] **Otras zonas del cuerpo** (palma, cara, abdomen, dorso de la mano): la capa córnea de la
  palma mide ~170 µm (Egawa 2007) y la grasa del abdomen ~14 mm (Gibney 2010). Selector de zona.
- [ ] **Hueso bajo el músculo** y fricción en los flancos de la punta al entrar (Shergold & Fleck):
  hoy la punta solo se detiene por su propio alcance.

## P2 · Producto

- [ ] **Persistencia local** de logros y cuaderno: `localStorage` en escritorio,
  AsyncStorage en móvil. Botón para reiniciar. En móvil, guardar también la preferencia de
  sonido y vibración (escritorio ya la recuerda).
- [x] **Modo dual de coches:** el mismo ensayo en dos coches (clásico frente a moderno, aluminio o
  plástico), con los dos bancos animados y la tabla de qué raya, desgarra, punza o golpea en cada
  uno, cuántos milímetros y qué daño deja (`duel`, `duelVerdict` y `damageReport` en core).
- [ ] **Comparador libre:** elegir 2–3 herramientas y un material y ver una tabla lado a lado.
- [ ] **Exportar** un resultado como PNG (tarjeta compartible) o el cuaderno a CSV.
- [ ] **Idiomas:** español (por defecto), catalán e inglés. Extraer textos a un diccionario.
- [ ] **Accesibilidad:** hecho en escritorio: contraste AA de la paleta, `aria-pressed` en
  selectores, `aria-valuetext` en deslizadores, foco visible, atajo ⌘/Ctrl+↩ y movimiento reducido.
  Falta: revisión con lector de pantalla (VoiceOver, NVDA, Orca) y lo equivalente en móvil.

## P3 · Mantenimiento

- [ ] Migrar `packages/core` a TypeScript con tipos para `Claw`, `Target` y `Result`.
- [ ] Actualizar Expo a la SDK más reciente (`npx expo install expo@latest --fix`) y probar en dispositivo.
- [ ] Firma y notarización de macOS y firma de código en Windows en el workflow de release.

## V2.0 en Godot (prototipo en `godot/`)

El estudio completo, con las mediciones del prototipo, está en `docs/V2-VIABILIDAD.md`. Fases que quedan, con
agentes (como mucho 2 a la vez):

- [ ] **Laboratorio con paridad total con la 1.x**, comprobada pantalla a pantalla: modo dual, comparativa, logros,
  cuaderno y fundamentos. Además, hápticos en móvil y precarga de las losas del banco (hoy, al cambiar de material se
  ve la anterior unos 170 ms).
- [ ] **Taller, fase 2 del control Fagor:** compensación del radio de la punta G41/G42 (hoy los chaflanes, conos y
  radios salen con el error de la punta, y así se enseña), roscado, más ciclos y subrutinas. Después, el dialecto
  Fanuc. Probarlo con los programas reales de la FP.
- [ ] **Fresadora y taladro** en la interfaz: el modelo de corte ya calcula fresado y taladrado.
- [ ] **Radial:**
  - ancho de corte del disco de láminas (falta un dato verificado);
  - discos de metal duro y de CBN;
  - Awan 2021 para la energía de corte del acero al carbono;
  - una sola fuente para la longitud y el color de las chispas (hoy en `radial.gd` y en `sparks.gd`).
- [ ] **Release en 5 plataformas** (`godot-release.yml`): instaladores, APK e IPA, presets de calidad para móvil,
  y pruebas en tu iPhone, Android, Windows y macOS.
- [ ] **Accesibilidad:** AccessKit y prueba con lector de pantalla.
- [ ] **Emoji:** empaquetar Noto Color Emoji (OFL, ~10 MB) o quitarlos, porque hoy dependen de la fuente del sistema.
- [ ] **Determinismo entre plataformas:** la física del laboratorio aún usa `pow`, `exp`, `log` y `tan` de la libm de
  cada plataforma en unos pocos sitios; pasarlos a `core/shared/v8_math.gd` (ya están pow, tan y log) para que dé
  lo mismo, bit a bit, en todas.
- [ ] **ThorVG:** los grupos con `clipPath` se componen en 8 bits (el cepillado de la uña de metal sale más tenue).
- [ ] **Herramientas:** que el ejecutor de tests espere fotogramas (para probar la disposición real de la
  interfaz) y capturas de teléfono sin el marco (un `override.cfg` temporal con el tamaño).

- [ ] **Coche en marcha, lo que queda tras la 4d:**
  - integrar `ClawFracture` (rotura de garras reforjadas frágiles) en el banco del laboratorio;
  - resistencia medida de juntas de goma, barras, retrovisor, antena y limpiaparabrisas;
  - medir el arado de una garra en la pintura (hoy, Bowden & Tabor como estimación);
  - que los anclajes frenen el deslizamiento del golpe.
- [x] **Aguantar puede ser una ventana de velocidades** (señalado en la 4c). Ejemplo: el oso de pie en el techo con una
  frenada de 0,9 g. El veredicto decía «ni a paso de hombre aguanta», pero de ~62 km/h en adelante el viento de cara
  compensa la inercia. Ahora `detach` da `holdFromKmh`, `holdToKmh` y `holdToMode`, y los textos, la banda y la gráfica
  los enseñan. Afecta a ~10 % de los ensayos del barrido. Además:
  - ningún texto dice «~0 km/h» (`REST_KMH`);
  - los textos concuerdan con el género del animal (`GRAMMAR`: «sale despedida», «se queda clavada»);
  - «no corta el acero de horno», con artículo;
  - el botón de fuerza máxima dice «unos 300 N», porque en Syne la virgulilla parecía un punto;
  - `defense_block` da `pcsaCm2`, y el estado ya no recalcula la fuerza de defensa para citarlo.
- [ ] **Coche en marcha, más fallos señalados en la 4c:**
  - física (para un ingeniero físico): unas garras clavadas que atraviesan la aleta de plástico dan `crush_m` = 0, y
    entonces `t_crush` = 0 y no hay marcas de arrastre. Falta cuánto rasga una garra clavada al ser arrastrada por el
    plástico;
  - datos sin `source` ni `quality`: `IMPACT_ZONES`, `BODIES`, `limbStiffness`, `BIRD_AERO.wing.sustenta` y
    `MANEUVERS.crucero`;
  - `impact` no da las componentes de la velocidad ni el tiempo de vuelo del salto, ni bandas;
  - funciones de formato privadas duplicadas entre `MovingCar` y `MovingCarState`;
  - la sustentación del ave con viento de cola usa v² sin signo: un ala con el aire por detrás sustenta mucho menos
    (estimación pendiente de fuente).

## 1.x (Tauri y Expo)

- [x] **AppImage con Mesa reciente** (tauri-apps/tauri#15976): el arreglo de Tauri (#16062, 2.12) no está publicado;
  la release usa ya su linuxdeploy 07333c6, que deja fuera `libwayland-client`, y lo comprueba. Probado en Docker
  (Ubuntu 22.04, 26.04 y Fedora 44, sin GPU). Detalle en `docs/AUDIO-NATIVO.md`.
- [ ] **Probar el AppImage 1.0.1 con GPU de verdad** en Ubuntu 26.04 (NVIDIA y AMD, Wayland y X11). Mientras tanto, el `.deb`.
- [ ] **Tauri 2.12:** al publicarse, subir `@tauri-apps/cli`, `tauri` y `tauri-build` y quitar el paso «linuxdeploy de
  Tauri 2.12 para el AppImage» de `release.yml` (la comprobación se queda).
- [x] **Ejecutor `ubuntu-22.04`:** `release.yml` compila Linux en un contenedor `ubuntu:22.04` sobre `ubuntu-latest`.
- [ ] **`ci.yml` (job desktop-shell) sigue en `ubuntu-22.04`:** moverlo igual antes de los cortes de aviso (23-03-2027).
- [ ] **Abril de 2027:** Ubuntu 22.04 sale del soporte estándar; valorar el contenedor `ubuntu:24.04` (glibc 2.39,
  sin Ubuntu 22.04 ni Debian 12) y rehacer `THIRD-PARTY-NOTICES.md` con noble.
- [x] **Registro de GStreamer propio del AppImage** (`GST_REGISTRY_1_0`, en `main.rs`).

## Deuda conocida

- La escala de fuerza es única (0,5–2000 N); los insectos necesitarán otra.
- La abrasión de la piel sin romperla (rasguño blanco, rasguños) usa umbrales de esfuerzo
  calibrados; romperla y rasgarla ya usan datos medidos (Davis 2004; Comley & Fleck 2010).
- Muchas fuerzas y energías de animales son estimaciones (tabla en `docs/FISICA.md`).
