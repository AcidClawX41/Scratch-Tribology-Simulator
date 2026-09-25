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

## Deuda conocida

- La escala de fuerza es única (0,5–2000 N); los insectos necesitarán otra.
- La abrasión de la piel sin romperla (rasguño blanco, rasguños) usa umbrales de esfuerzo
  calibrados; romperla y rasgarla ya usan datos medidos (Davis 2004; Comley & Fleck 2010).
- Muchas fuerzas y energías de animales son estimaciones (tabla en `docs/FISICA.md`).
