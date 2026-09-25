# apps/desktop · escritorio (macOS · Windows · Linux)

App nativa de escritorio con **Tauri 2**. La UI es React (`src/`) y el motor físico viene
de `packages/core`, compartido con la app móvil. Se empaqueta en un binario
pequeño (~5-10 MB) que usa el WebView del propio sistema: WebKit en macOS, WebView2 en Windows y
WebKitGTK en Linux.

Desarrollado por/para Eric Valls Gramunt. Licencia MIT (ver [`LICENSE`](../../LICENSE) y
[`THIRD-PARTY-NOTICES.md`](../../THIRD-PARTY-NOTICES.md)).

---

## Requisitos (una sola vez)

**macOS (tu MacBook Pro M1)**

```bash
xcode-select --install                                   # herramientas de compilación
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
brew install node
```

**Windows 10/11**

1. [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) → marca *Desarrollo para el escritorio con C++*
2. Rust: `winget install Rustlang.Rustup`
3. Node: `winget install OpenJS.NodeJS.LTS`
4. WebView2 ya viene en Windows 10/11 actualizados.

**Linux (Ubuntu 22.04 o posterior, incluida tu 26.04)**

```bash
sudo apt update
sudo apt install -y libwebkit2gtk-4.1-dev build-essential curl wget file libxdo-dev libssl-dev \
  libayatana-appindicator3-dev librsvg2-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh     # Rust en tu usuario, sin tocar el sistema
```

Es la lista oficial de requisitos de Tauri 2 para Debian/Ubuntu. Node 24 (el de `.nvmrc`), mejor
con `nvm` o `fnm` que con el paquete de la distribución. Para empaquetar el `.AppImage` hacen falta
además `patchelf` y `xdg-utils` (la CI de GitHub ya los instala).

**GPU NVIDIA en Linux.** Con el driver propietario, WebKitGTK puede dejar la ventana en blanco o
parpadeando por su renderizador DMA-BUF. La app lo detecta (`/proc/driver/nvidia/version`) y solo
entonces pone `WEBKIT_DISABLE_DMABUF_RENDERER=1`. Si ya has fijado esa variable, se respeta. En un
equipo con NVIDIA y AMD a la vez, si la pantalla la mueve la AMD (Mesa) y quieres el renderizador
DMA-BUF, arranca con `STS_KEEP_DMABUF=1`.

---

## Desarrollo

Todos los comandos se lanzan **desde la raíz del repositorio**:

```bash
npm install
npm run tauri dev        # ventana nativa con recarga en caliente
```

La primera vez Cargo descarga y compila dependencias: 2-4 min. Luego, segundos.

## Build de instaladores

```bash
npm run tauri build
```

| Sistema | Salida en `src-tauri/target/release/bundle/` |
|---|---|
| macOS | `dmg/Scratch Tribology Simulator_1.0.0_aarch64.dmg` y `macos/Scratch Tribology Simulator.app` |
| Windows | `msi/…_x64_en-US.msi` (WiX en inglés, el idioma por defecto) y `nsis/…_x64-setup.exe` |
| Linux | `deb/…_amd64.deb`, `rpm/…x86_64.rpm` y `appimage/…_amd64.AppImage` |

**Binario universal macOS** (Apple Silicon + Intel en uno):

```bash
rustup target add x86_64-apple-darwin      # en un M1, aarch64-apple-darwin ya viene de serie
npm run tauri build -- --target universal-apple-darwin
lipo -archs "apps/desktop/src-tauri/target/universal-apple-darwin/release/scratch-tribology-simulator"
# → x86_64 arm64
```

Tauri compila las dos arquitecturas por separado y las une con `lipo`, así que Rust tiene que venir
de `rustup` (el de Homebrew no trae la biblioteca estándar de Intel). La salida queda en
`src-tauri/target/universal-apple-darwin/release/bundle/`:
`dmg/Scratch Tribology Simulator_1.0.0_universal.dmg` y `macos/Scratch Tribology Simulator.app`.

**Importante:** cada sistema compila su propio instalador. El `.dmg` se hace en el Mac,
el `.msi`/`.exe` en Windows y el `.deb`/`.rpm`/`.AppImage` en Linux. Si no quieres tocar cada
máquina, usa GitHub Actions (abajo).

---

## Compilación automática en GitHub

`.github/workflows/release.yml`: al subir un tag `v*` (el mismo número que `package.json`), GitHub
Actions compila macOS (Apple Silicon e Intel), Windows y Linux, además del APK de Android y el IPA
de iPhone, los sube a un borrador de Release y lo publica cuando todo ha compilado:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

«Run workflow» (a mano, en la pestaña Actions) compila lo mismo sin publicar nada: los archivos
quedan como artefactos del workflow. En cada push a `main` y en cada pull request, la CI pasa los
tests, compila el frontend, revisa la app móvil y compila el shell nativo con `rustfmt` y `clippy`.

---

## Primer arranque sin firmar

La app que compilas tú en tu propio Mac se abre sin más: Gatekeeper revisa lo descargado (lo que
lleva el atributo de cuarentena) y un build local no lo lleva. Los avisos aparecen cuando otra
persona descarga el instalador sin firmar:

- **macOS 15 Sequoia o posterior:** ábrela una vez, luego *Ajustes del Sistema → Privacidad y
  seguridad → Abrir igualmente* ([Apple](https://support.apple.com/guide/mac-help/mh40616/mac)).
  El truco de clic derecho → *Abrir* ya no sirve desde Sequoia; solo funciona en macOS 14 o anterior.
  Alternativa en Terminal: `xattr -dr com.apple.quarantine "/Applications/Scratch Tribology Simulator.app"`
- **Windows (SmartScreen):** *Más información* → *Ejecutar de todas formas*.

Para distribuir sin avisos: firma con Developer ID + notarización en macOS
(Apple Developer Program, 99 $/año) y certificado de firma de código en Windows. Sin cuenta de pago,
Tauri admite firma *ad hoc* (`"signingIdentity": "-"` en `bundle > macOS`): la documentación la
recomienda en Apple Silicon, donde se exige firma a todo lo que llega de internet, pero el usuario
tiene que seguir aprobándola en *Privacidad y seguridad*
([Tauri](https://v2.tauri.app/distribute/sign/macos/#ad-hoc-signing)).

---

## Estructura

```
apps/desktop/
├── index.html
├── public/favicon.png        ← icono de la pestaña (versión web)
├── src/
│   ├── main.jsx              ← monta React, fuentes empaquetadas (offline), estilos e integración nativa
│   ├── styles.css            ← estilos globales ESTÁTICOS con la paleta como variables CSS (ver CSP abajo)
│   ├── App.jsx               ← composición: barra superior y dos columnas (configuración | banco)
│   ├── theme.js              ← DISP / MONO (tipografías); la paleta C viene de @sts/core
│   ├── native.js             ← plataforma, atajo ⌘/Ctrl+↩, menú contextual y teclas de navegador
│   ├── sound.js              ← efectos de @sts/core en Web Audio + preferencia on/off (localStorage)
│   ├── hooks/useLab.js       ← estado del laboratorio, temporizadores y sonidos del ensayo
│   ├── cards/                ← Tool, Target, Params, Result, Compare y Badges (una tarjeta por archivo)
│   └── components/
│       ├── Scene.jsx         ← traduce el grafo de escena de @sts/core/art.js a SVG de React
│       ├── art.jsx           ← NailFront, NailSide, ClawIcon, MaterialSwatch, GemIcon
│       ├── Bench.jsx         ← banco de ensayo animado (losa texturizada, herramienta y marca)
│       ├── sections.jsx      ← cortes multicapa (pintura, puerta) y perfil de la huella
│       └── ui.jsx            ← Card, Pill, Segmented, Tile, Slider, Metric, IconButton
├── src-tauri/                ← shell Rust mínimo, CSP estricta, iconos
└── app-icon.png              ← icono fuente (regenera con `npx tauri icon app-icon.png`)
```

Las ilustraciones y los sonidos **no** se dibujan ni se sintetizan aquí: vienen de
`packages/core` (`art.js`, `sfx.js`), así escritorio y móvil muestran y suenan igual.

**CSP y estilos.** En la app empaquetada, Tauri añade un *nonce* a `style-src` por cada `<style>`
del HTML, y con un nonce presente el WebView ignora `'unsafe-inline'`: un `<style>` creado en tiempo
de ejecución se bloquea (en el navegador sí funciona, por eso no se ve con `npm run dev`). Los estilos
globales van en `src/styles.css` y los de componente en línea (CSSOM, permitido). `npm run build`
falla si alguien vuelve a generar un `<style>` (`scripts/check-csp.mjs`).

## Integración nativa

- **Ventana:** tema oscuro nativo (barra de título en macOS y Windows), fondo del color de la app
  mientras carga (sin destello blanco), tamaño inicial para dos columnas y nunca más grande que la
  pantalla. Recuerda tamaño, posición y maximizado entre sesiones (`tauri-plugin-window-state`).
- **Teclado:** ⌘↩ en macOS y Ctrl↩ en Windows/Linux lanzan el ensayo; ⌘/Ctrl + y − hacen zoom.
  Se bloquean las teclas de navegador que no pintan nada en una app (recargar, imprimir) y el menú
  contextual fuera de los campos de texto.
- **Windows 11:** barras de desplazamiento superpuestas (Fluent) con WebView2 ≥ 125.
- **Linux:** paquetes .deb (sección *education*), .rpm y .AppImage, y el arreglo para NVIDIA.
- **Sonido:** Web Audio del propio WebView (WebKit, WebView2, WebKitGTK); el botón de silencio se
  recuerda en cada equipo.

## Qué incluye la 1.0.0

- **Uñas, garras y colmillos:** uñas de salón curvas, Stiletto XL y piedras incrustadas; uñas
  experimentales de acero, titanio, zafiro y diamante; garras de mamíferos y de 9 aves (águila
  arpía, halcón peregrino, lechuza, buitre leonado, **casuario**, emú, avestruz, espolón de gallo y
  guacamayo), y garras reforjadas en acero, zafiro, tungsteno o diamante.
- **Modelo físico v2.4** (Hertz, punta esfero-cónica, impacto por energía) y **piel humana por
  capas**: rasguños, arañazos que sangran, desgarros, laceraciones y punciones que dicen la capa
  alcanzada.
- **Coches realistas:** clásico (acero dulce ~0,9 mm), moderno (acero de horno 0,7 mm), de
  aluminio (1,0 mm) y aleta de plástico (PPE/PA ~2,5 mm). La chapa se perfora y, con energía de
  sobra, la herramienta entera la atraviesa (pétalos de Wierzbicki); rayando fuerte, la raja.
- **Vidrio de ventana** que se parte al flexar (Roark + EN 572-1): un zarpazo de gato no la rompe,
  el de un oso sí. Puerta de aluminio de casa con la misma física de chapa fina.
- **Modo dual:** el mismo ensayo en dos coches (antiguo frente a moderno) con informe de daños en
  milímetros y centímetros, y un corte del coche con la carrocería real.
- Fuerza de hasta **2000 N** (la patada de avestruz no cabía en 500 N). Las fuerzas de casuario,
  emú, avestruz y arpía son **estimaciones** y así se indica en su ficha.
- Interfaz en dos columnas con ilustraciones, banco animado con texturas, sonido por situación
  (activable) y logros como 🦖 *Dinosaurio vivo* (casuario + punción + impacto sobre piel).
- Release automática en GitHub: instaladores de escritorio, APK de Android e IPA de iPhone.
