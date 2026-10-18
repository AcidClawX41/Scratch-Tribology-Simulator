# Audio nativo: qué necesita cada plataforma

Cómo suena Scratch Tribology Simulator 1.x en cada sistema, qué pone el sistema operativo y qué lleva la
app dentro desde la 1.0.1. En resumen: solo Linux depende de algo que puede faltar (los plugins de
GStreamer), y desde la 1.0.1 el AppImage los lleva dentro y el `.deb` y el `.rpm` los piden al instalarse.
El AppImage 1.0.0, además, no podía sonar en ninguna distribución (ver «Qué pasaba en la 1.0.0»).

## Cómo suena la app

- **Escritorio (y web).** `apps/desktop/src/sound.js` renderiza una vez cada efecto de `@sts/core`
  (`sfx.js`) a PCM en un `AudioBuffer` y lo reproduce con el **Web Audio** del WebView. No decodifica
  ningún formato (ni MP3, ni AAC, ni Ogg): no depende de códecs, solo de que el WebView tenga una salida
  de audio que funcione.
- **Móvil.** Los mismos efectos, prerenderizados a 22 WAV (PCM) en `apps/mobile/assets/sfx`
  (`npm run sfx:mobile`) y reproducidos con `expo-audio`.
- Sin audio en el sistema, la app sigue funcionando en silencio.

| Plataforma | Por dónde sale el sonido | Qué puede faltar | Qué hace la app |
|---|---|---|---|
| Windows 10 (1803 o posterior) y 11 | WebView2 (Chromium) → WASAPI | nada: WebView2 viene con el sistema | si faltara, el instalador lo descarga |
| macOS 11 o posterior | WKWebView (WebKit) → Core Audio | nada | nada |
| Linux | WebKitGTK → GStreamer → PulseAudio, PipeWire o ALSA | los plugins de GStreamer | AppImage: los lleva dentro · `.deb` y `.rpm`: dependencias |
| Android | `expo-audio` → Media3 ExoPlayer | nada | ExoPlayer va compilado en el APK |
| iPhone y iPad | `expo-audio` → AVFoundation | nada | nada: AVFoundation es del sistema |

## Windows

WebView2 (el motor de Edge, basado en Chromium) saca el audio por WASAPI, la API de audio de Windows
(Core Audio). WebView2 viene con el sistema en Windows 10 desde la versión de abril de 2018 (1803) y en
Windows 11. Si faltara, el instalador (NSIS o MSI) usa `webviewInstallMode: downloadBootstrapper`: descarga
el instalador de WebView2 de Microsoft y lo ejecuta, así que en ese caso hace falta conexión.

- **Opción `offlineInstaller`.** Mete el instalador completo de WebView2 en el de la app: unos 127 MB más,
  y ya no hace falta red. No se usa por defecto porque casi nadie lo necesita y multiplica el tamaño de la
  descarga. Se cambia en `tauri.conf.json` (`bundle > windows > webviewInstallMode > type`).
- **Ediciones N y KN.** Les faltan Windows Media Player y las tecnologías relacionadas (Media Foundation,
  códecs MP3, AAC…), que devuelve el Media Feature Pack. La app no las usa, porque no decodifica nada, y
  la salida de audio del sistema no está entre lo que se quita. *No se ha probado en una edición N.*

No hay DLL que añadir: WebView2 es un componente del sistema con sus propias actualizaciones.

## macOS

WKWebView, el WebKit del sistema, saca el Web Audio por Core Audio, que forma parte de macOS. No hay nada
que instalar ni que empaquetar: basta la versión mínima de la app (macOS 11, `bundle > macOS >
minimumSystemVersion`).

## Linux

### La cadena del sonido

WebKitGTK no tiene salida de audio propia: el Web Audio sale por **GStreamer**. En WebKitGTK 2.50 (la de
Ubuntu 22.04, el contenedor donde se compila la release) la tubería es:

```text
webkitwebaudiosrc ! clocksync ! audioconvert ! audioresample ! autoaudiosink
```

`webkitwebaudiosrc` es de WebKit, pero por dentro usa `appsrc` (plugin `app`), y `clocksync` es del núcleo
de GStreamer (plugin `coreelements`, en `libgstreamer1.0-0`, que WebKitGTK siempre arrastra). El resto son
plugins que pueden no estar:

| Elemento | Qué hace | Debian y Ubuntu | Fedora |
|---|---|---|---|
| `appsrc`, `audioconvert`, `audioresample` | entregan el audio de WebKit y pasan su formato y su frecuencia de muestreo a lo que acepta la salida | `gstreamer1.0-plugins-base` | `gstreamer1-plugins-base` |
| `autoaudiosink` | elige la salida: la de más rango que arranque (ignora las de rango menor que MARGINAL) | `gstreamer1.0-plugins-good` | `gstreamer1-plugins-good` |
| `pulsesink` (rango PRIMARY+10) | envía el sonido a PulseAudio, o a PipeWire a través de `pipewire-pulse` | `gstreamer1.0-plugins-good` | `gstreamer1-plugins-good` |
| `alsasink` (rango PRIMARY) | salida directa a ALSA cuando no hay servidor de sonido | `gstreamer1.0-alsa` | `gstreamer1-plugins-base` |

Si falta alguno, la app funciona pero no suena. WebKitGTK solo lo avisa en la terminal («GStreamer element
… not found. Please install it») o, si están los plugins pero no arranca ninguna salida, en el registro de
GStreamer (`GST_DEBUG=2`).

### Por qué esos paquetes y no otros

- **`gstreamer1.0-plugins-base` y `gstreamer1.0-plugins-good`, aunque WebKitGTK ya dependa de ellos.** En
  Ubuntu 22.04, Ubuntu 24.04 y Debian 12, `libwebkit2gtk-4.1-0` depende de los dos, así que ahí no añaden
  nada. Se declaran igualmente porque la app los necesita para sonar y otras distribuciones o derivadas
  pueden empaquetar WebKitGTK de otra manera. En Fedora, `webkit2gtk4.1` solo *recomienda*
  `gstreamer1-plugins-good` (dependencia débil).
- **`gstreamer1.0-alsa`.** WebKitGTK solo lo *sugiere*, y apt no instala sugerencias. Sin él, en un sistema
  sin PulseAudio ni PipeWire no hay ninguna salida. En Fedora, `alsasink` ya va en
  `gstreamer1-plugins-base`.
- **No `gstreamer1.0-pulseaudio`.** En Ubuntu 22.04, Ubuntu 24.04 y Debian 12 es un paquete de transición
  vacío que solo depende de `gstreamer1.0-plugins-good`, donde está `pulsesink` (en Ubuntu 24.04, además,
  está en *universe*).
- **No `gstreamer1.0-pipewire` (en Fedora, `pipewire-gstreamer`).** `pipewiresink` se registra con rango
  NONE, así que `autoaudiosink` nunca lo elige: con PipeWire, el sonido sale por `pulsesink` a través de
  `pipewire-pulse`. Además, `libpipewire` tiene que coincidir con el servidor del sistema (por eso la lista
  de exclusión de AppImage la deja fuera), y el linuxdeploy de Tauri 2.11 no la excluye (el 07333c6 que usa
  la release, sí): dentro del AppImage podría romper.

### AppImage: GStreamer dentro (`bundleMediaFramework`)

Con `bundle > linux > appimage > bundleMediaFramework: true`, Tauri ejecuta linuxdeploy con el plugin
`gstreamer` (`tauri-apps/linuxdeploy-plugin-gstreamer`), que:

1. copia los plugins de la carpeta `GSTREAMER_PLUGINS_DIR` (si no se indica, **todos** los de
   `/usr/lib/x86_64-linux-gnu/gstreamer-1.0`) a `usr/lib/gstreamer-1.0` del AppImage, con las bibliotecas de
   las que dependen y los ayudantes `gst-plugin-scanner` y `gst-ptp-helper`;
2. añade un gancho de arranque (`apprun-hooks/linuxdeploy-plugin-gstreamer.sh`) que apunta
   `GST_PLUGIN_SYSTEM_PATH_1_0` a esa carpeta: el GStreamer del AppImage usa sus propios plugins y no los
   del sistema, que pueden faltar, estar en otra ruta (`/usr/lib64` en Fedora) o ser de otra versión.

**La release no copia todos los plugins.** La carpeta entera son unos 110 plugins, y algunos arrastran
bibliotecas solo GPL: con todos dentro, el AppImage de prueba llevaba `libslang.so.2` y `libgpm.so.2`
(GPL-2+), por `aasink` y `cacasink`. Además, GStreamer examina cada plugin al arrancar, en una ruta nueva
cada vez que se monta el AppImage. Por eso `release.yml` prepara una carpeta solo con los plugins que hacen
falta y la pasa en `GSTREAMER_PLUGINS_DIR`: `coreelements`, `app`, `audioconvert`, `audioresample` y
`autodetect` (la cadena), `pulseaudio` y `alsa` (las salidas), y `playback`, `typefindfunctions` y `volume`,
que WebKit busca para el multimedia. La documentación de Tauri habla de 15 a 35 MB más con la carpeta
entera; con esta selección es bastante menos (el resumen de cada release da el tamaño).

Probado con el linuxdeploy y el plugin que descarga Tauri 2.11.5 sobre una app de prueba: dentro del
AppImage, GStreamer encuentra `autoaudiosink`, `pulsesink`, `audioconvert`, `audioresample` y `clocksync`;
con la carpeta de plugins vacía, ninguno.

**Qué pasaba en la 1.0.0.** El AppImage publicado no lleva `usr/lib/gstreamer-1.0`, pero su lanzador
(`AppRun.wrapped`, el `apprun-old` que pone Tauri) exporta igualmente
`GST_PLUGIN_SYSTEM_PATH_1_0=$APPDIR/usr/lib/gstreamer-1.0:`. Con esa variable, GStreamer ya no busca en la
carpeta de plugins del sistema ni en la del usuario (`gstregistry.c`), así que no encuentra ninguno: con ese
valor, `gst-inspect-1.0` no ve `autoaudiosink` ni `audioconvert` aunque estén instalados. El AppImage 1.0.0
se quedaba sin sonido en cualquier distribución, no solo en las que no traen los plugins (comprobado el
mecanismo sobre el archivo publicado; no se ha oído en un escritorio). Es uno de los fallos que describe
tauri-apps/tauri#15665 con Tauri 2.11, la versión de la app. Los `.deb` y `.rpm` 1.0.0 no tienen ese
lanzador y usan el GStreamer del sistema.

Más detalles del AppImage:

- **Los plugins se instalan en el runner antes de compilar**, porque linuxdeploy solo empaqueta lo que
  encuentra; la documentación de Tauri pide que la máquina de compilación tenga todos los plugins que la
  app vaya a necesitar. Son los mismos paquetes que declara el `.deb`.
- **Nada de `bad`, `ugly`, `libav` ni `pipewire`.** La documentación de Tauri avisa de que la licencia de
  los `ugly` puede impedir distribuirlos, y `THIRD-PARTY-NOTICES.md` solo cita los paquetes fuente
  `gstreamer1.0`, `gst-plugins-base1.0` y `gst-plugins-good1.0`.
- **`libasound.so.2` se queda fuera a propósito:** está en la lista de exclusión del linuxdeploy que usa
  Tauri, porque tiene que ser la del sistema; `alsasink` usa la `libasound` del equipo. `libpulse` no está
  en esa lista, así que `pulsesink` se lleva la suya.
- **Registro de GStreamer propio.** Por defecto, el GStreamer del AppImage guardaría su registro de plugins en
  el mismo archivo que el del sistema (`~/.cache/gstreamer-1.0/registry.x86_64.bin`), lo dejaría con sus diez
  plugins y el siguiente programa del sistema que use GStreamer tendría que volver a examinar todos los suyos.
  Desde la 1.0.1, `main.rs` pone `GST_REGISTRY_1_0` en
  `~/.cache/com.acidclawx41.scratchtribology/gstreamer-1.0/registry.x86_64.bin` (GStreamer crea la carpeta),
  solo si el ejecutable está dentro del `APPDIR` del AppImage y nadie ha elegido otro registro; el `.deb` y el
  `.rpm` siguen con el registro del sistema. El AppImage vuelve a examinar sus diez plugins en cada arranque,
  porque se monta en una ruta nueva, pero son pocos. Probado en Docker: con el AppImage en Ubuntu 26.04, el
  registro va a esa carpeta y el del sistema no se toca; con el `.deb` en Ubuntu 22.04, aunque herede un
  `APPDIR` de otro AppImage, se usa el del sistema. En los dos casos suena.

### `.deb` y `.rpm`

No llevan bibliotecas: usan el WebKitGTK y el GStreamer de la distribución. Tauri ya añade WebKitGTK y GTK
(`libwebkit2gtk-4.1-0` y `libgtk-3-0` en el `.deb`; `libwebkit2gtk-4.1.so.0()(64bit)` y
`libgtk-3.so.0()(64bit)` en el `.rpm`, que valen en cualquier distribución).

| Paquete | Dependencias de audio (`tauri.conf.json`) | Nombres comprobados en |
|---|---|---|
| `.deb` | exige `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good` y `gstreamer1.0-alsa` | Ubuntu 22.04, 24.04 y 26.04; Debian 12 y 13 |
| `.rpm` | recomienda `gstreamer1-plugins-base` y `gstreamer1-plugins-good` (Fedora) y `gstreamer-plugins-base` y `gstreamer-plugins-good` (openSUSE) | Fedora 43, 44, 45 y Rawhide; openSUSE |

El `.rpm` los **recomienda** en vez de exigirlos porque cada familia los llama de una manera: una
dependencia fuerte con los nombres de Fedora lo dejaría sin instalar en openSUSE, y al revés. Una
recomendación que no existe se ignora, y dnf y zypper instalan las que sí existen salvo que se les diga lo
contrario (en Fedora, `install_weak_deps=False`, habitual en instalaciones mínimas; ahí hay que instalar
los plugins a mano o usar el AppImage).

### Qué comprueba la release y qué no

El job de Linux de `.github/workflows/release.yml` (en un contenedor `ubuntu:22.04`, ver «Dónde se compila»):

- instala `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good` y `gstreamer1.0-alsa` y prepara la
  carpeta de plugins elegidos antes de `tauri-action`;
- pone el linuxdeploy de Tauri 2.12 (ver «AppImage y Mesa 25 o posterior»);
- extrae el AppImage (`--appimage-extract`) y exige exactamente esos plugins, entre ellos
  `libgstcoreelements.so`, `libgstapp.so`, `libgstaudioconvert.so`, `libgstaudioresample.so`,
  `libgstautodetect.so`, `libgstpulseaudio.so` y `libgstalsa.so`, el gancho con
  `GST_PLUGIN_SYSTEM_PATH_1_0` y que no lleve `libwayland-client`;
- busca con `dpkg -S` el paquete de Ubuntu de cada binario de `usr/lib` y falla si alguno no sale de un
  paquete, si entra una biblioteca solo GPL (`libslang2`, `libgpm2`, `libreadline`, códecs GPL…) o si algún
  plugin sale de un paquete fuente distinto de los tres citados;
- publica en la Release `Scratch-Tribology-Simulator_<versión>_linux-appimage-licenses.txt`: cada paquete de
  Ubuntu con archivos en el AppImage, con su versión exacta y su paquete fuente, y su archivo de copyright
  completo (a eso remite `THIRD-PARTY-NOTICES.md`);
- comprueba con `dpkg-deb -I` que el `.deb` exige, y con `rpm -qp --recommends` que el `.rpm` recomienda,
  lo que dice `tauri.conf.json` (e imprime `rpm -qpR`);
- imprime el tamaño del AppImage (también en el resumen del job).

Si algo falla, el borrador de la Release no se publica. En cada `npm test`,
`packages/core/test/packaging.test.js` vigila que la configuración, el workflow, este documento y
`THIRD-PARTY-NOTICES.md` sigan cuadrando.

Lo que la CI no puede comprobar es que **suene**: eso pide probar el AppImage en un escritorio real, mejor
en una distribución distinta de Ubuntu (Fedora, Arch…) y en una sin PulseAudio ni PipeWire. Tampoco que
arranque con una GPU de verdad (ver «AppImage y Mesa 25 o posterior»).

```bash
./Scratch*.AppImage --appimage-extract > /dev/null
ls squashfs-root/usr/lib/gstreamer-1.0
GST_DEBUG=2 ./Scratch*.AppImage       # busca «not found. Please install it» y los errores de GStreamer
dpkg-deb -f Scratch*.deb Depends      # dependencias del .deb
rpm -qp --recommends Scratch*.rpm     # recomendaciones del .rpm
```

### AppImage y Mesa 25 o posterior (tauri#15976)

No tiene que ver con el sonido, pero es del mismo AppImage.

**Qué pasa.** El linuxdeploy que descarga Tauri hasta la 2.11.5 (compilado el 26-07-2024) mete en el AppImage
el `libwayland-client` de la máquina de compilación (Wayland 1.20 en Ubuntu 22.04). El WebKit del AppImage lo
carga, y el lanzador pone `usr/lib` del AppImage en `LD_LIBRARY_PATH`, así que el `libEGL` de Mesa del sistema,
que nunca va dentro (`libEGL`, `libGL`, `libgbm` y `libdrm` están en la lista de exclusión), usa esa copia. Al
de Mesa 26 le faltan ahí `wl_display_create_queue_with_name` y `wl_display_dispatch_queue_timeout` (de Wayland
1.23) y `wl_fixes_interface`: no carga, WebKit no puede crear su pantalla EGL y el proceso web aborta con
`Could not create default EGL display: EGL_BAD_PARAMETER. Aborting...`. La ventana se abre, pero vacía. Pasa en
sesiones Wayland y X11, aunque el gancho del plugin de GTK fuerce X11 (`GDK_BACKEND=x11`).

**El arreglo de Tauri** (tauri-apps/tauri#16062, fusionado el 25-09-2026 en la rama de la 2.12) es un
linuxdeploy nuevo, el 07333c6 (compilado el 01-09-2026), cuya lista de exclusión ya trae `libwayland-client.so.0`
(y `libpipewire-0.3.so.0`, que el AppImage no lleva); su plugin de GTK, además, deja de forzar X11. El 26-09-2026
no está publicado: la última versión es la 2.11.5 del CLI (20-09-2026, con el bundler 2.9.4), la que usa la app.
Mientras tanto, el paso «linuxdeploy de Tauri 2.12 para el AppImage» de `release.yml` deja ese linuxdeploy,
verificado con su SHA-256, en la caché de herramientas de Tauri (`~/.cache/tauri/linuxdeploy-x86_64.AppImage`):
Tauri 2.11.5 solo descarga el suyo si falta ese archivo. Después de compilar, la comprobación falla si el
AppImage lleva `libwayland-client`.

**Por qué solo `libwayland-client`.** Es la única biblioteca del AppImage a la que el Mesa del sistema le pide
algo que no tiene (comprobado con `readelf` y `nm` en Ubuntu 26.04 y Fedora 44). Mesa también usa las copias de
`libxcb-randr`, `libxcb-shm`, `libXext`, `libzstd` y `libelf` del AppImage, pero en ellas encuentra todo lo que
pide; la plataforma Wayland del driver de NVIDIA (egl-wayland 1.1.21) también lo encuentra todo en las de
Wayland, y la de X11 (egl-x11) no usa ninguna del AppImage. El autor de tauri#15976 quitó diez (`libwayland-client`,
`-cursor`, `-egl` y `-server`, `libxkbcommon`, `libxcb-randr`, `-render` y `-shm`, `libXau` y `libXdmcp`) y
también arranca, pero el WebKit del AppImage necesita `libwayland-server`, que ni Mesa ni GTK piden: en Ubuntu
26.04 la traen los compositores (mutter, KWin, muffin, wlroots…), Qt 6 Wayland, WebKitGTK o egl-wayland, y en
un escritorio X11 sin ellos (Xfce, MATE…) el AppImage ni arrancaría. `libwayland-client`, en cambio, la piden el
`libEGL` de Mesa, GTK 3 y Xwayland: está en cualquier escritorio. Si en el futuro chocara otra biblioteca, el
linuxdeploy nuevo acepta `LINUXDEPLOY_EXCLUDED_LIBRARIES` (patrones separados por `;`), que llega también a las
llamadas de sus plugins de GTK y GStreamer.

**Qué más cambia.** Comparado en local con el AppImage sin el arreglo, en `usr/lib` solo falta `libwayland-client`
(123 → 122 paquetes de Ubuntu en la lista de licencias). Cambian también los archivos `copyright` de
`usr/share/doc`, el tamaño de los binarios que retoca linuxdeploy (el nuevo trae patchelf 0.19.1 y el `strip`
de binutils 2.47) y el orden en que el lanzador carga los ganchos de GStreamer y GTK, que tocan variables
distintas. Los plugins, los ganchos, los RPATH, el `.deb` y el `.rpm` son los mismos.

**Probado en local** con Docker: compilado en `ubuntu:22.04` con los pasos de `release.yml` y abierto en sway
sin pantalla, con Xwayland y Mesa por software (llvmpipe), como una sesión Wayland sin GPU; el sonido, en Xvfb
con PulseAudio: al pulsar ARAÑAR, WebKit abre un flujo en PulseAudio con los plugins de GStreamer del AppImage.

| AppImage | Ubuntu 22.04 (Mesa 23.2) | Ubuntu 26.04 (Mesa 26.0.8) | Fedora 44 (Mesa 26.2.3) |
|---|---|---|---|
| Sin el arreglo (linuxdeploy de Tauri 2.11.5) | abre y suena | `EGL_BAD_PARAMETER`, ventana vacía (también en X11) | `EGL_BAD_PARAMETER`, ventana vacía |
| Con el linuxdeploy de Tauri 2.12 (la release) | abre y suena | abre y suena | abre |
| Sin las diez de tauri#15976 | abre | abre | abre |

**Sin probar:** GPU de verdad (NVIDIA con su driver, AMD con radeonsi) y sesiones de GNOME o KDE. Mientras no
se pruebe, en Ubuntu 26.04 lo recomendado es el `.deb` (`apps/desktop/README.md`), que usa el WebKitGTK y el
Mesa del sistema. **Con Tauri 2.12:** al subir `@tauri-apps/cli`, `tauri` y `tauri-build`, el bundler descarga
él mismo ese linuxdeploy (como `linuxdeploy-07333c6-x86_64.AppImage`), así que el paso sobra y se quita; la
comprobación sigue valiendo.

### Dónde se compila: contenedor `ubuntu:22.04`

GitHub retira el ejecutor `ubuntu-22.04`: empezó el 17-09-2026, habrá cortes de aviso (23 y 30 de marzo, 6 y
13 de abril de 2027, de 14:00 a 00:00 UTC) y deja de funcionar el 17-04-2027 (actions/runner-images#14254).
Desde la 1.0.1, el job de Linux corre en `ubuntu-latest` dentro de un contenedor `ubuntu:22.04`. Tauri pide
compilar en la base más antigua que se quiera soportar con WebKitGTK 4.1 (Ubuntu 22.04 o Debian 12) y propone
Docker para ello.

| | Contenedor `ubuntu:22.04` (elegido) | Ejecutor `ubuntu-24.04` sin contenedor |
|---|---|---|
| glibc mínima del `.deb`, el `.rpm` y el AppImage | 2.35, como hasta ahora: Ubuntu 22.04, Debian 12, Fedora 36… | 2.39: se quedan fuera Ubuntu 22.04 y Debian 12 (2.36) |
| Lo que va dentro del AppImage | lo mismo que hasta ahora (jammy); `THIRD-PARTY-NOTICES.md` sigue valiendo | lo de noble: hay que rehacer los avisos |
| Trabajo en el workflow | instalar lo que el ejecutor ya traía (git, curl, compilador, jq, rpm…); sin `sudo` ni `gh` | ninguno |
| Tiempo | 1-2 minutos más de apt | igual |

El ejecutor da igual porque solo pone Docker, así que es `ubuntu-latest` y no hay que volver a moverlo. Lo que
sí caduca es la base: sin Ubuntu Pro, Ubuntu 22.04 deja de recibir actualizaciones de seguridad (también del
WebKitGTK del AppImage) en abril de 2027. Entonces conviene pasar el contenedor a `ubuntu:24.04` y aceptar
glibc 2.39, con los avisos de licencias de noble.

### Compilar el AppImage en local

`npm run tauri build` en Linux genera también el AppImage, y el plugin de linuxdeploy necesita los plugins
de GStreamer instalados. En Ubuntu y Debian, los tres paquetes del `.deb`. En distribuciones con `lib64`
el plugin no encuentra las rutas por sí solo y hay que dárselas; en Fedora (y sus derivadas):

```bash
GSTREAMER_PLUGINS_DIR=/usr/lib64/gstreamer-1.0 GSTREAMER_HELPERS_DIR=/usr/libexec/gstreamer-1.0 npm run tauri build
npm run tauri build -- --bundles deb,rpm      # o sin AppImage
```

Sin `GSTREAMER_PLUGINS_DIR` apuntando a una carpeta con los plugins elegidos (como hace `release.yml`), el
AppImage local lleva todos los plugins instalados, con las licencias de sus bibliotecas: vale para probar,
no para distribuir.

## Android e iPhone

Todo va dentro del paquete: los 22 WAV y `expo-audio` (Expo SDK 52), que en Android reproduce con AndroidX
Media3 ExoPlayer, compilado dentro del APK, y en iOS con AVFoundation, del sistema. No hay WebView ni
GStreamer de por medio y no hay nada que añadir.

## V2 en Godot

La 2.0 (Godot 4.7) no usa WebView: el motor saca el audio directamente por la API de cada sistema, así que
el problema que resuelve la 1.0.1 no existe allí.

| Sistema | Driver de Godot | Qué necesita |
|---|---|---|
| Windows | WASAPI | nada: es parte de Windows |
| macOS e iOS | Core Audio | nada |
| Linux | PulseAudio (también con PipeWire, vía `pipewire-pulse`) o ALSA, cargadas con `dlopen` al arrancar (`use_sowrap`, activo por defecto) | la `libpulse.so.0` o la `libasound.so.2` del sistema; sin ninguna, arranca en silencio (driver Dummy) |
| Android | OpenSL ES | nada: es parte de Android |

Sin GStreamer ni WebView: cada plataforma usa su audio nativo y el ejecutable no depende al enlazar de
ninguna biblioteca de sonido.

## Fuentes

- Tauri 2. AppImage, «Multimedia support via GStreamer» (`bundleMediaFramework`, plugins en la máquina de
  compilación, aviso sobre `ugly`). https://v2.tauri.app/distribute/appimage/
- Tauri 2. Referencia de configuración, `AppImageConfig.bundleMediaFramework` («~15-35MB»).
  https://v2.tauri.app/reference/config/#appimageconfig
- Tauri 2. Paquete Debian (dependencias que añade el bundler). https://v2.tauri.app/distribute/debian/
- Tauri 2. Instalador de Windows, opciones de WebView2 (Windows 10 de abril de 2018 o posterior y
  Windows 11; `offlineInstaller` ~127 MB). https://v2.tauri.app/distribute/windows-installer/
- Bundler de Tauri, `linuxdeploy.rs` (`--plugin gstreamer`) y `tauri-cli/src/interface/rust.rs`
  (dependencias automáticas del `.deb` y el `.rpm`). https://github.com/tauri-apps/tauri/tree/dev/crates
- `tauri-apps/linuxdeploy-plugin-gstreamer` (copia de plugins y gancho `GST_PLUGIN_SYSTEM_PATH_1_0`).
  https://github.com/tauri-apps/linuxdeploy-plugin-gstreamer
- Lanzador `apprun-old` de Tauri (`GST_PLUGIN_SYSTEM_PATH_1_0=%s/usr/lib/gstreamer-1.0:%s`), idéntico al
  `AppRun.wrapped` del AppImage 1.0.0 publicado.
  https://github.com/tauri-apps/binary-releases/releases/tag/apprun-old
- tauri-apps/tauri#15665 (variable de GStreamer apuntando a una carpeta que no existe; bibliotecas
  gráficas con Mesa 25) y #15976 (Fedora 44, Mesa 26.1.8, AMD 680M; arreglo probado: quitar diez bibliotecas).
  https://github.com/tauri-apps/tauri/issues/15665 · https://github.com/tauri-apps/tauri/issues/15976
- tauri-apps/tauri#16062, «fix(bundler): update linuxdeploy and linuxdeploy-plugin-gtk» (cierra las dos; hito
  2.12) y el `linuxdeploy.rs` resultante en `dev` (`LINUXDEPLOY_COMMIT_HASH = "07333c6"`, CLI 2.12.0).
  https://github.com/tauri-apps/tauri/pull/16062 ·
  https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-bundler/src/bundle/linux/appimage/linuxdeploy.rs
- Versiones publicadas: `@tauri-apps/cli` en npm (la última 2.x, 2.11.5, del 20-09-2026) y `tauri-bundler` en
  crates.io (la última 2.x, 2.9.4, del 28-06-2026). https://www.npmjs.com/package/@tauri-apps/cli ·
  https://crates.io/crates/tauri-bundler/versions
- linuxdeploy 07333c6 (01-09-2026) en https://github.com/tauri-apps/binary-releases/releases/tag/linuxdeploy-07333c6;
  `LINUXDEPLOY_EXCLUDED_LIBRARIES`: commit 98f393c de linuxdeploy/linuxdeploy.
  https://github.com/linuxdeploy/linuxdeploy/commit/98f393c4d9acbb586c27885eeec7c01eefb26259
- pkg2appimage#559 (`libwayland-client.so.0` en la lista de exclusión: el `libEGL` de Mesa usa funciones de
  Wayland 1.23). https://github.com/AppImageCommunity/pkg2appimage/pull/559
- Símbolos y dependencias de Mesa 26.0.8 (Ubuntu 26.04) y 26.2.3 (Fedora 44), de egl-wayland 1.1.21 y
  egl-x11 1.0.3 (Ubuntu 26.04), comprobados con `readelf -d` y `nm -D` en contenedores; dependencias inversas
  de `libwayland-server0` y `libwayland-client0` con `apt-cache rdepends` (Ubuntu 26.04).
- GitHub, retirada de las imágenes de Ubuntu 22.04 (17-09-2026 a 17-04-2027, cortes de aviso).
  https://github.com/actions/runner-images/issues/14254
- Tauri 2, AppImage: compilar en la base más antigua que se quiera soportar (Ubuntu 22.04 o Debian 12), con
  Docker o GitHub Actions. https://v2.tauri.app/distribute/appimage/
- actions/runner, `ContainerStepHost` (`StepHost.cs`): en un job con contenedor, las entradas de las acciones
  se traducen a rutas del contenedor. https://github.com/actions/runner/blob/main/src/Runner.Worker/Handlers/StepHost.cs
- GStreamer 1.20.3, `gst/gstregistry.c`: con `GST_PLUGIN_SYSTEM_PATH_1_0` definida no se examinan la
  carpeta del sistema ni la del usuario.
  https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.3/subprojects/gstreamer/gst/gstregistry.c
- WebKitGTK 2.50.4, `AudioDestinationGStreamer.cpp` (la tubería) y `GStreamerCommon.cpp`
  (`createAutoAudioSink`). https://github.com/WebKit/WebKit/tree/webkitgtk-2.50.4/Source/WebCore/platform
- GStreamer 1.20.3: `gstautodetect.c` (solo rangos ≥ MARGINAL), `pulsesink.c` (PRIMARY+10) y
  `gstalsasink.c` (PRIMARY). https://gitlab.freedesktop.org/gstreamer/gstreamer/-/tree/1.20.3/subprojects
- PipeWire 1.0.5, `src/gst/gstpipewire.c` (`pipewiresink` con rango NONE).
  https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/src/gst/gstpipewire.c
- AppImage, lista de exclusión (`libasound.so.2`, `libpipewire-0.3.so.0`, `libwayland-client.so.0`).
  https://github.com/AppImageCommunity/pkg2appimage/blob/master/excludelist. La del linuxdeploy que
  descarga Tauri 2.11 (`strings` sobre el binario) trae `libasound.so.2` y `libjack.so.0`, pero no
  `libpipewire-0.3.so.0` ni `libwayland-client.so.0`; la del 07333c6 trae las cuatro.
  https://github.com/tauri-apps/binary-releases/releases/tag/linuxdeploy
- Paquetes y listas de archivos: https://packages.ubuntu.com (jammy, noble, resolute),
  https://packages.debian.org (bookworm, trixie) y https://packages.fedoraproject.org
  (`gstreamer1-plugins-base`, `gstreamer1-plugins-good`); Ubuntu 24.04 además con `apt-cache` y `dpkg -L`.
  Recomendación débil de Fedora: https://src.fedoraproject.org/rpms/webkitgtk/blob/f44/f/webkitgtk.spec.
  Ayudantes de GStreamer en Fedora (`/usr/libexec/gstreamer-1.0`): paquete `gstreamer1` de Fedora 44.
  Nombres de openSUSE: https://software.opensuse.org/package/gstreamer-plugins-good
- Tauri 2, esquema de configuración de la CLI 2.11.5 (`RpmConfig.recommends`) y bundler (`rpm.rs`:
  `builder.recommends`). https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-bundler/src/bundle/linux/rpm.rs
- Bibliotecas GPL con todos los plugins: `libslang.so.2` y `libgpm.so.2` (GPL-2+, según su `copyright`) en
  un AppImage de prueba hecho con el linuxdeploy de Tauri y la carpeta entera de plugins de Ubuntu 24.04.
- Chromium, `media/audio/win/audio_low_latency_output_win.h` (salida por WASAPI).
  https://github.com/chromium/chromium/blob/main/media/audio/win/audio_low_latency_output_win.h
- Microsoft, Media Feature Pack para las ediciones N.
  https://support.microsoft.com/en-us/windows/experience/platform-variants/media-feature-pack-for-windows-n
- `expo-audio` 0.3.5: `android/build.gradle` (Media3 ExoPlayer 1.4.0) e `ios/AudioModule.swift`
  (AVFoundation). https://unpkg.com/browse/expo-audio@0.3.5/
- Godot 4.7: `platform/linuxbsd/detect.py` (`use_sowrap`), `drivers/pulseaudio/pulse-so_wrap.c` y
  `drivers/alsa/asound-so_wrap.c` (`dlopen`), `platform/android/os_android.h` (OpenSL ES) y
  `servers/audio/audio_server.cpp` (driver Dummy). https://github.com/godotengine/godot/tree/4.7-stable
