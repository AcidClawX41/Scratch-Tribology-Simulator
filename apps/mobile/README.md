# apps/mobile · iPhone y Android (Expo)

App **Expo / React Native**. El motor físico y los datos vienen de `packages/core`
(dependencia `file:../../packages/core`), el mismo que usa la versión de escritorio.
`metro.config.js` ya está preparado para resolver ese paquete fuera de la carpeta.

Desarrollado por/para Eric Valls Gramunt. Licencia MIT (ver [`LICENSE`](../../LICENSE) y
[`THIRD-PARTY-NOTICES.md`](../../THIRD-PARTY-NOTICES.md)).

> Esta app **no** forma parte de los workspaces de la raíz (Expo pesa cientos de MB).
> Se instala por separado dentro de `apps/mobile`.

---

## Arranque rápido (5 min)

```bash
cd apps/mobile
npm install
npx expo install --check   # las versiones deben cuadrar con la SDK 52 (si no: --fix)
npx expo start
```

La app usa la **SDK 52** de Expo, y eso decide dónde funciona **Expo Go**
([fuente](https://docs.expo.dev/troubleshooting/expo-go-version-mismatch/)):

| Dónde | ¿Expo Go con la SDK 52? |
|---|---|
| iPhone o iPad físico | **No.** La App Store solo ofrece Expo Go hasta la SDK 54 y iOS no deja instalar versiones anteriores. Usa la build nativa de abajo |
| Simulador de iOS (Mac con Xcode) | Sí: pulsa `i` en `npx expo start` y la CLI instala la versión de Expo Go que corresponde |
| Android (móvil o emulador) | Sí: descarga Expo Go para la SDK 52 en [expo.dev/go](https://expo.dev/go) |

> Saltar a la última SDK (`npx expo install expo@latest --fix`) cambia React Native y React de
> versión mayor: hazlo en una rama aparte, siguiendo la guía de actualización de Expo.

---

## Build nativa en tu MacBook Pro M1

### iOS (iPhone y iPad)

Requisitos:

- **Xcode** (App Store). Con Xcode 16.3 o posterior hace falta **React Native ≥ 0.76.9**, la
  versión fijada en `package.json`: la 0.76.9 actualizó folly y fmt precisamente para
  compilar con Xcode 16.3 (changelog de React Native); la 0.76.5 no compila.
- **CocoaPods**: `brew install cocoapods`. En Apple Silicon funciona de forma nativa; el viejo
  truco de `arch -x86_64` ya no hace falta.

```bash
npx expo run:ios                      # simulador
npx expo run:ios --device             # tu iPhone conectado por cable
```

`expo run:ios` genera la carpeta `ios/` (prebuild) si no existe y ejecuta `pod install` cuando
cambian las dependencias. A mano sería `npx expo prebuild --platform ios` y
`cd ios && pod install`.

La app es **universal iPhone + iPad** (`"supportsTablet": true` en `app.json`): un solo binario,
con una columna en iPhone y dos en el iPad apaisado.

Firma: para instalarla en tu propio iPhone basta tu Apple Account en Xcode (equipo «Personal
Team»), pero ese perfil caduca a los 7 días y hay que reinstalar
([Apple](https://developer.apple.com/support/compare-memberships/)). TestFlight y App Store
necesitan el Apple Developer Program: abre `ios/ScratchTribologySimulator.xcworkspace` (el
nombre sale de `expo.name` en `app.json`), elige tu equipo en *Signing & Capabilities* y
`Product → Archive`.

### Android

Requisitos: Android Studio + JDK 17.

```bash
npx expo prebuild --platform android
npx expo run:android
```

Para el `.aab` de Play Store:

```bash
cd android && ./gradlew bundleRelease
# → android/app/build/outputs/bundle/release/app-release.aab
```

### Sin compilar nada: la Release de GitHub

Cada versión publicada en *Releases* (workflow `.github/workflows/release.yml`) trae:

- **`…_android.apk`**: se instala directamente (permite «instalar apps desconocidas» en el
  navegador o el gestor de archivos). Va firmado con la clave de depuración de la plantilla de
  Expo; para publicarlo en Google Play, da tu clave como secretos del repositorio
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`) y el workflow lo firma con `apksigner`.
- **`…_ios-unsigned.ipa`**: iOS no instala nada sin firmar. Ábrelo con **AltStore** o
  **Sideloadly** en tu Mac: lo firman con tu Apple ID y lo instalan en tu iPhone (con cuenta
  gratuita la firma dura 7 días). Para TestFlight o la App Store hace falta el Apple Developer
  Program y la build de Xcode de arriba.

### Alternativa sin Xcode local: EAS Build (nube)

```bash
npm install -g eas-cli
eas login
eas build --platform ios
eas build --platform android
```

---

## Estructura

```
apps/mobile/
├── App.js                 ← fuentes, arranque y composición (1 columna en iPhone, 2 en iPad apaisado)
├── index.js · app.json · babel.config.js
├── metro.config.js        ← watchFolders → packages/core
├── assets/sfx/*.wav       ← efectos de sonido prerenderizados desde @sts/core (no editar a mano)
├── scripts/render-sfx.mjs ← regenera los WAV y src/sfxAssets.js (npm run sfx:mobile, desde la raíz)
└── src/
    ├── theme.js           ← tipografías; la paleta C viene de @sts/core
    ├── sound.js           ← expo-audio + vibración (expo-haptics), interruptor de efectos
    ├── sfxAssets.js       ← require() de cada WAV (generado)
    ├── hooks/useLab.js    ← createLabHook(React) de @sts/core: el mismo estado que escritorio
    ├── cards/             ← Tool, Target, Params, Result, Compare y Badges
    └── components/
        ├── Scene.js       ← traduce el grafo de escena de @sts/core/art.js a react-native-svg
        ├── art.js         ← uñas, garras, colmillos, materiales y gemas (mismos dibujos que escritorio)
        ├── Bench.js       ← banco de ensayo animado (Animated)
        ├── sections.js    ← cortes por capas: pintura, puerta, piel y perfil de la huella
        └── ui.js          ← Card, Pill, Segmented, Tile, SliderRow, Metric, IconButton…
```

Las ilustraciones y los sonidos **no** se dibujan ni se sintetizan aquí: vienen de `packages/core`
(`art.js`, `sfx.js`), así móvil y escritorio muestran y suenan igual.

## Sonido y vibración

- Los 22 efectos de `@sts/core/sfx.js` se prerenderizan a WAV (`npm run sfx:mobile` en la raíz) y
  se reproducen con **expo-audio**. `npm run check:mobile` falla si los WAV no coinciden con el motor.
- En iPhone respetan el interruptor de silencio y se **mezclan** con tu música (no la cortan).
- Cada efecto lleva su vibración (expo-haptics): selección al tocar, impactos suaves o fuertes
  según el ensayo y una notificación al ganar un logro o romperse la punta.
- Un solo botón "Sonido/Silencio" activa o apaga sonido y vibración. De momento la preferencia no
  se guarda entre sesiones (ROADMAP).

## Qué cambió respecto al web (y por qué)

| Web | Nativo | Motivo |
|-----|--------|--------|
| `<div>` / `<span>` | `<View>` / `<Text>` | en RN todo texto va dentro de `<Text>` |
| estilos inline CSS | `StyleSheet.create` | misma sintaxis camelCase, pero cacheado |
| `<svg>` | `react-native-svg` | API casi idéntica; `<text>` → `<Text>` de svg |
| `clipPath: inset(...)` | `<ClipPath><Rect/>` | el CSS clip-path no existe en RN |
| `<input type="range">` | `@react-native-community/slider` | slider nativo |
| `linear-gradient` CSS | `expo-linear-gradient` | botón ARAÑAR |
| transiciones CSS | `Animated` | animación del banco de ensayo |
| Web Audio | `expo-audio` + WAV prerenderizados | efectos de sonido |
| (no existe) | `expo-haptics` | vibración con cada efecto |
| `overflow-x: auto` | `<ScrollView horizontal>` | filas de píldoras |
| `@import` Google Fonts | `@expo-google-fonts/*` | fuentes empaquetadas, funciona offline |

**Detalle tipográfico:** en RN cada peso es una familia distinta.
Por eso `theme.js` exporta `DISP` (Syne 700), `DISP8` (Syne 800),
`MONO` (Space Mono 400) y `MONOB` (Space Mono 700) en vez de usar `fontWeight`.

---
