# Exportar la V2 (Godot 4.7.2)

> Desde la 2.0 el programa se llama **Tribology Simulator & Industrial Workshop** (la 1.x era Scratch Tribology
> Simulator). Los identificadores de paquete (`com.acidclawx41.scratchtribology`) no cambian: la 2.0 se instala encima
> de la 1.x.

Cómo se convierte el proyecto de `godot/` en programas para **Windows, macOS, Linux, Android e iOS**, a mano o
con GitHub Actions. Tres archivos lo sostienen:

- `godot/export_presets.cfg`: los cinco presets de exportación (sin secretos).
- `.github/workflows/godot-ci.yml`: tests, gdlint y motor 1.x en cada push a `main` y en cada pull request.
- `.github/workflows/godot-release.yml`: exporta, empaqueta, comprueba y sube todo a una Release en borrador al
  empujar una etiqueta `v2*`.

## Qué se publica

| Plataforma | Archivo | Cómo se hace | Firma |
|---|---|---|---|
| Windows x86_64 | `Tribology-Simulator-Industrial-Workshop_<versión>_windows-x86_64.zip` | un solo `.exe` con el pck dentro, icono y metadatos escritos por Godot | sin firmar (SmartScreen avisa) |
| macOS universal | `…_macos-universal.dmg` | `.app` universal (Intel y Apple Silicon) en un DMG hecho con `hdiutil` | ad hoc, sin notarizar |
| Linux x86_64 | `…_linux-x86_64.tar.gz`, `…_linux-x86_64.AppImage`, `…_amd64.deb` | ejecutable con el pck dentro; AppImage con appimagetool; `.deb` con `dpkg-deb` | — |
| Android | `…_android.apk` | APK con la plantilla precompilada, arm64-v8a y armeabi-v7a | clave del autor (secretos) o la de depuración de la 1.x |
| iPhone / iPad | `…_ios-unsigned.ipa` | proyecto Xcode exportado por Godot y compilado con `xcodebuild` | sin firmar (AltStore o Sideloadly la firman al instalar) |

Tamaños de referencia del prototipo actual: ejecutable de Linux 74 MB (29 MB en `.tar.gz`, 27 MB la AppImage,
20 MB el `.deb`), `.exe` 109 MB (38 MB en `.zip`), `.app` universal 171 MB (61 MB en `.zip`). Casi todo es el
motor: el pck del proyecto ocupa unos 0,3 MB.

## Requisitos

### Para exportar

- **Godot 4.7.2 estándar** (no la edición .NET): el editor de <https://godotengine.org/download/archive/4.7.2-stable/>.
- **Plantillas de exportación 4.7.2** (`Godot_v4.7.2-stable_export_templates.tpz`, 1,3 GB; unos 2 GB instaladas).
  Desde el editor: *Editor → Gestionar plantillas de exportación → Descargar e instalar*. A mano, se descomprime
  la carpeta `templates/` del `.tpz` en:
  - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
  - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
  - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`

  Comprueba el SHA-512 con el `SHA512-SUMS.txt` de la Release de Godot en GitHub
  (`https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt`).
- **Android:** JDK 17 y el SDK de Android con `platform-tools` (adb) y `build-tools` (apksigner). Godot 4.7 los
  busca en *Configuración del editor → Exportar → Android* (`java_sdk_path` y `android_sdk_path`), que la primera
  vez toman `JAVA_HOME` y `ANDROID_HOME`. No hace falta Gradle ni la plantilla de compilación de Android: el preset
  usa el APK precompilado.
- **iOS:** exportar el proyecto Xcode funciona desde cualquier sistema; compilarlo exige un Mac con **Xcode 26.1 o
  posterior**, porque las bibliotecas de las plantillas de iOS de Godot 4.7.2 están compiladas con el SDK de
  iOS 26.1 (se ve en sus `LC_BUILD_VERSION`).
- **macOS:** el `.app` (en `.zip`, firmado ad hoc por el firmador integrado de Godot) se exporta desde cualquier
  sistema; el `.dmg` necesita `hdiutil`, es decir, un Mac.
- **Linux:** `dpkg-deb` para el `.deb` y appimagetool 1.9.1 para la AppImage.
- **Windows:** nada más; Godot escribe el icono y los metadatos del `.exe` sin rcedit, también desde Linux.

### Requisitos de sistema de lo exportado

Los de Godot 4.7 para proyectos exportados
([docs.godotengine.org/en/4.7/about/system_requirements.html](https://docs.godotengine.org/en/4.7/about/system_requirements.html)):

| Sistema | Mínimo | Gráficos |
|---|---|---|
| Windows | Windows 10, x86_64 con SSE4.2 | Forward+: Vulkan 1.0 o Direct3D 12; Compatibility: OpenGL 3.3 o Direct3D 11 |
| macOS | macOS 11 en Intel, macOS 13 en Apple Silicon | Forward+: Metal 3 (o Vulkan con MoltenVK); Compatibility: OpenGL 3.3 |
| Linux | una distribución posterior a 2018 (el ejecutable pide glibc ≥ 2.28) | Forward+: Vulkan 1.0; Compatibility: OpenGL 3.3 |
| Android | **Android 7.0 con Compatibility**, Android 9.0 con Mobile | Mobile: Vulkan; Compatibility: OpenGL ES 3.0 |
| iOS | **iOS 15 con Vulkan (MoltenVK)**, iOS 16 con Metal | Metal 3 o Vulkan; Compatibility: OpenGL ES 3.0 |

Cómo encaja el proyecto: `project.godot` usa Forward+ en escritorio y Mobile en móviles, con
`rendering/rendering_device/fallback_to_opengl3=true`. Por eso:

- En **Android** el APK se instala desde Android 7.0 (la plantilla precompilada de Godot 4.7 lleva `minSdk 24` y
  `targetSdk 36`). Godot 4.7 solo usa Vulkan si el dispositivo declara Vulkan 1.1; si no (en la práctica, casi todos
  los de Android 7.0–8.x), arranca con el renderizador **Compatibility** (OpenGL ES 3.0). Con una compilación Gradle
  el `minSdk` por defecto subiría a 29 para Vulkan: por eso el preset no usa Gradle.
- En **iOS** el mínimo es iOS 15: Godot 4.7 usa Metal y, donde no puede (iOS 15), Vulkan con MoltenVK, que va
  incluido en el proyecto Xcode.
- En **escritorio**, si no hay Vulkan (ni Direct3D 12 en Windows, ni Metal en macOS), cae a OpenGL 3.3.

### Audio en cada plataforma

Godot mezcla el audio él mismo (buses de `default_bus_layout.tres`, con un limitador en el maestro) y lo entrega al
controlador nativo de cada sistema. Los sonidos del laboratorio son WAV que Godot importa dentro del pck: no hace
falta ningún códec ni componente aparte.

| Plataforma | Controlador | Qué necesita |
|---|---|---|
| Windows | WASAPI | forma parte de Windows |
| macOS | CoreAudio | forma parte de macOS |
| Linux | PulseAudio y, si falla, ALSA | `libpulse.so.0` (también sirve con PipeWire, vía pipewire-pulse) o `libasound.so.2` |
| Android | «Android» (OpenSL ES) | forma parte de Android; reproducir no pide permisos |
| iOS | CoreAudio | forma parte de iOS |

Las compilaciones oficiales de Godot para Linux **cargan PulseAudio y ALSA en tiempo de ejecución** (`dlopen`), no
al enlazar: si falta una biblioteca, prueba la siguiente. Si no queda ninguna, en cualquier plataforma, Godot avisa
(«All audio drivers failed, falling back to the dummy driver») y sigue funcionando en silencio en vez de no
arrancar. Para diagnosticar se puede forzar uno: `--audio-driver ALSA`. Sin ventana (`--headless`) se usa el
controlador mudo, y Movie Maker (`--write-movie`) escribe el audio en un WAV.

### Dependencias del .deb

El ejecutable de Linux solo enlaza con la glibc (`libc`, `libm`, `libdl`, `libpthread`, `librt`; el símbolo más
nuevo que pide es `GLIBC_2.28`). Todo lo demás lo carga con `dlopen` al arrancar, así que `dpkg-shlibdeps` no lo
vería y el `.deb` lo declara a mano:

- **Depends** (sin esto no abre ventana o no suena): `libc6 (>= 2.28)`, `libx11-6 | libwayland-client0`,
  `libgl1 | libvulkan1`, `libasound2 | libpulse0`. En Ubuntu 24.04 y Debian 13, `libasound2t64` provee
  `libasound2`.
- **Recommends** (Godot los usa si están): `libpulse0`, `libvulkan1`, `mesa-vulkan-drivers | vulkan-icd`, `libegl1`,
  las extensiones de X11 (`libxcursor1`, `libxext6`, `libxi6`, `libxinerama1`, `libxrandr2`, `libxrender1`),
  Wayland (`libwayland-cursor0`, `libwayland-egl1`, `libxkbcommon0`, `libdecor-0-0`), `libfontconfig1`,
  `libdbus-1-3` y `libudev1`.
- **Suggests:** `libspeechd2` (texto a voz).

La lista sale de las bibliotecas que nombra la plantilla `linux_release.x86_64` (con `readelf -d` y `strings`). El
`.deb` instala el ejecutable en `/usr/bin/tribology-simulator-workshop`, el lanzador en
`/usr/share/applications/`, el icono en `/usr/share/pixmaps/` y las licencias en
`/usr/share/doc/tribology-simulator-workshop/`. La versión `2.0.0-prototipo` pasa a `2.0.0~prototipo`, que en Debian
va antes que la `2.0.0`.

## Los presets

`godot/export_presets.cfg` solo escribe lo que difiere de los valores por defecto de Godot 4.7.2 o conviene tener a
la vista, con un comentario por opción. Los nombres de las opciones están comprobados contra la referencia de
clases de la etiqueta `4.7.2-stable` (`EditorExportPlatformWindows`, `…MacOS`, `…LinuxBSD`, `…Android`, `…IOS`).
Si lo guardas desde el editor, Godot lo reescribe entero y sin comentarios: no pasa nada.

Comunes a los cinco: todos los recursos, salvo `tests/*` y `tools/*` (el ejecutor de tests y las herramientas no van
en el pck). Ruta por defecto en el editor: `dist/godot/<plataforma>/` en la raíz del repositorio (ignorada por git).

| Preset | Opciones que importan |
|---|---|
| Windows | x86_64, pck embebido, icono `res://assets/icon.png`, empresa, producto, descripción y copyright; sin firma de código |
| macOS | universal, identificador `com.acidclawx41.scratchtribology`, categoría Education, mínimos 11.00 (Intel) y 13.00 (Apple Silicon), firma ad hoc con el firmador integrado (`codesign/codesign=1`), sin notarizar |
| Linux | x86_64, pck embebido |
| Android | APK precompilado (sin Gradle), arm64-v8a y armeabi-v7a, paquete `com.acidclawx41.scratchtribology`, categoría «Undefined» (no es un juego), **sin Internet**; un solo permiso, `VIBRATE` (de los «normales»: se concede al instalar, sin preguntar), para los hápticos del laboratorio |
| iOS | solo el proyecto Xcode, iPhone y iPad, iOS 15, fondo de la pantalla de arranque #170E1C, Team ID de marcador |

**Versión.** Godot toma la de `config/version` (`2.0.0-prototipo`) solo si es numérica; Windows y Apple no admiten
el sufijo, así que cada preset la lleva en su formato:

| Dónde | Valor | Regla |
|---|---|---|
| `godot/project.godot` → `config/version` | `2.0.0-prototipo` | la versión que manda |
| Android `version/name` · `version/code` | `2.0.0-prototipo` · `1` | el código sube en cada versión |
| Windows `application/file_version` y `product_version` | `2.0.0.1` | números de la versión + código |
| macOS e iOS `application/short_version` · `application/version` | `2.0.0` · `1` | números de la versión · código |

`godot-release.yml` comprueba que todo coincide (y que la etiqueta es `v` + `config/version`) antes de compilar.

**Secretos.** El preset no lleva claves. Godot guarda las opciones secretas (almacenes de claves, certificados) en
`godot/.godot/export_credentials.cfg`, que no se sube; en la línea de órdenes y en CI se pasan por variables de
entorno.

**Team ID de iOS.** Godot 4.7 no exporta el proyecto sin un Team ID. `0000000000` es un marcador: la `.ipa` se
compila sin firma y Xcode no lo usa. Si algún día firmas, pon el tuyo en el preset o elige tu equipo en Xcode
(*Signing & Capabilities*).

## Exportar a mano

### Desde el editor

1. Abre `godot/project.godot` con Godot 4.7.2 e instala las plantillas (ver arriba).
2. *Proyecto → Exportar…*, elige el preset y pulsa *Exportar proyecto…*.
3. Desmarca *Exportar con depuración* (la versión para repartir es la de publicación) y guarda en la ruta propuesta.

Notas por plataforma:

- **Android:** para firmar con tu clave, rellena en el preset *Keystore → Release*, *Release User* y
  *Release Password*. Godot pasa a apksigner una sola contraseña: si la de la clave es distinta de la del almacén,
  exporta firmando con la de depuración y vuelve a firmar con `apksigner` como hace el workflow.
- **iOS:** en la carpeta elegida quedan `TribologySimulatorWorkshop.xcodeproj` y sus archivos. Ábrelo con Xcode 26.1 o
  posterior, elige tu equipo en *Signing & Capabilities* y compila en tu dispositivo, o compílalo sin firma como en
  el workflow.
- **macOS:** el preset produce un `.zip` con el `.app`. En un Mac también puedes exportar directamente a `.dmg`
  (Godot usa `hdiutil`).

### Desde la línea de órdenes

Desde la raíz del repositorio. La ruta de salida es absoluta o relativa a `godot/`, y su carpeta tiene que existir:
si no, Godot 4.7.2 falla con «The given export path doesn't exist». Una exportación fallida termina con código 1.

```bash
mkdir -p dist/godot/linux dist/godot/windows dist/godot/macos dist/godot/android dist/godot/ios
godot --headless --path godot --import
godot --headless --path godot --export-release "Linux" "$PWD/dist/godot/linux/TribologySimulatorWorkshop.x86_64"
godot --headless --path godot --export-release "Windows" "$PWD/dist/godot/windows/TribologySimulatorWorkshop.exe"
godot --headless --path godot --export-release "macOS" "$PWD/dist/godot/macos/TribologySimulatorWorkshop.zip"
godot --headless --path godot --export-release "iOS" "$PWD/dist/godot/ios/TribologySimulatorWorkshop.ipa"
```

En iOS el preset exporta solo el proyecto Xcode: el nombre `.ipa` da nombre al proyecto
(`TribologySimulatorWorkshop.xcodeproj`), y fuera de macOS Godot avisa además de que allí no podría compilar la `.ipa`.

Android, con tu clave (o la de depuración) por variables de entorno:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/a/release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=mi_alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
godot --headless --path godot --export-release "Android" "$PWD/dist/godot/android/TribologySimulatorWorkshop.apk"
```

Con el envoltorio del repositorio, los ajustes del editor quedan aislados en `.godot-home/`, y las plantillas se
buscan en `.godot-home/data/godot/export_templates/4.7.2.stable/` (con `STS_GODOT_KEEP_HOME=1`, en las tuyas):

```bash
GODOT=/ruta/a/godot node godot/tools/godot.mjs run --headless --export-release Linux "$PWD/dist/godot/linux/TribologySimulatorWorkshop.x86_64"
```

Probar lo exportado en Linux, sin ventana y con captura de Movie Maker (bajo Xvfb si no hay pantalla):

```bash
dist/godot/linux/TribologySimulatorWorkshop.x86_64 --headless --quit
mkdir -p /tmp/cap && xvfb-run -a -s "-screen 0 1240x880x24" dist/godot/linux/TribologySimulatorWorkshop.x86_64 \
  --rendering-driver opengl3 --write-movie /tmp/cap/f.png --fixed-fps 30 --quit-after 30
```

### Empaquetar a mano

Los pasos exactos (AppImage, `.deb`, DMG, firma del APK y `.ipa` sin firmar) están en `godot-release.yml`,
comentados; se pueden copiar tal cual. En resumen:

- **AppImage:** `AppDir/usr/bin/tribology-simulator-workshop` (el ejecutable), `AppDir/AppRun` como enlace a él, el
  lanzador `.desktop` y el icono en la raíz, y `appimagetool AppDir`. appimagetool incluye el runtime type2, que va
  enlazado estáticamente: la AppImage no necesita `libfuse2` en el sistema del usuario.
- **DMG:** una carpeta con el `.app` (copiado con `ditto`), un enlace a `/Applications` y las licencias, y
  `hdiutil create -fs HFS+ -format UDZO`.
- **IPA sin firmar:** `xcodebuild archive` con `CODE_SIGNING_ALLOWED=NO` y la app del `.xcarchive` dentro de
  `Payload/`, comprimida en zip.

## GitHub Actions

### godot-ci.yml

En cada push a `main` y en cada pull request (y a mano): instala Godot 4.7.2 desde downloads.godotengine.org y
comprueba su SHA-512 con el `SHA512-SUMS.txt` oficial (otro origen, la Release de Godot en GitHub), ejecuta
`npm run godot:test`, `gdlint` desde `godot/` (toma las reglas de `godot/gdlintrc`) y `npm test` del motor 1.x, que
es el oráculo. Las tres últimas comprobaciones se ejecutan aunque falle una anterior, para ver todos los fallos de
una vez.

### godot-release.yml

Se lanza al empujar una etiqueta `v2*` (o a mano, sin tocar las Releases):

1. **Versión y borrador:** comprueba versiones y etiqueta, y crea la Release en borrador (prerrelease si la versión
   lleva guion). Si se relanza la misma etiqueta, borra lo subido antes.
2. **Exportar con Godot** (Ubuntu): editor y plantillas desde la descarga oficial con el SHA-512 comprobado,
   guardados en caché; solo se instalan las cinco plantillas que se usan. Importa el proyecto y exporta las cinco
   plataformas desde Linux, y añade las licencias.
3. **Una tarea por plataforma**, en paralelo:
   - *Linux:* el ejecutable arranca con `--headless --quit`; hace el `.tar.gz`, la AppImage y el `.deb`; la AppImage
     arranca, y el `.deb` se instala con apt, arranca desde `/usr/bin` y se desinstala.
   - *Windows:* comprueba el tipo del `.exe` y sus metadatos, y hace el `.zip`.
   - *macOS* (runner de macOS 26): verifica la firma ad hoc con `codesign`, que el binario es universal y que
     arranca; hace el DMG con `hdiutil` y lo verifica.
   - *Android:* si hay secretos, vuelve a firmar con tu clave, igual que `release.yml`; comprueba la firma, el
     paquete, la versión, `minSdk 24`, las dos arquitecturas y que no pide Internet.
   - *iPhone:* compila con Xcode 26.6 sin firmar y empaqueta la `.ipa`.

   Cada una comprueba el tamaño de lo que produce y lo deja como artefacto de la ejecución.
4. **Subir al borrador:** sube lo que haya salido bien y termina en rojo si falta alguno de los siete archivos. El
   borrador **no se publica solo**: revísalo y publícalo a mano.

**Firma de Android.** Los mismos secretos opcionales que la 1.x: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`. Sin ellos, el APK va firmado con la
clave de depuración de la plantilla de Expo SDK 52 que usa la 1.x (la de siempre de React Native: alias
`androiddebugkey`, SHA-1 `5E:8F:16:06:2E:A3:CD:2C:4A:0D:54:78:76:BA:A6:F3:8C:AB:F6:25`), descargada con
`npm pack expo-template-bare-minimum@52.0.79` y comprobada por su SHA-256. Como el paquete es el mismo que el de la
1.x, así la V2 se instala encima. Esa clave es pública: vale para instalar a mano, no para Google Play.

**Descargas fijadas.** Godot se comprueba con las sumas oficiales; appimagetool 1.9.1 y la clave de depuración, con
un SHA-256 escrito en el workflow. appimagetool descarga además el runtime type2 actual de AppImage.

### Qué se ha verificado y dónde

- **En local** (Ubuntu 24.04, Godot 4.7.2 oficial): los nombres de todas las opciones de los presets contra la
  referencia de clases 4.7.2; exportaciones reales de Linux, Windows, macOS y el proyecto Xcode de iOS; el ejecutable
  de Linux arrancado sin ventana y bajo Xvfb con Movie Maker (fotogramas PNG y WAV); los pasos de los dos workflows
  que corren en Linux, ejecutados tal cual (versiones, descarga y SHA-512, clave de depuración, importación,
  exportación, licencias, `.tar.gz`, AppImage, `.deb` instalado con apt, `.zip` de Windows, tests de Godot y del
  motor); `actionlint` y `shellcheck` sin avisos.
- **Solo en GitHub Actions:** la exportación y firma de Android (hace falta el SDK), todo lo de macOS (`codesign`,
  arranque, `hdiutil`) e iOS (`xcodebuild`), los artefactos entre trabajos, la caché y la subida a la Release.

## Subir de versión

- **De la app:** cambia `config/version` en `godot/project.godot` y, en `godot/export_presets.cfg`,
  `version/name`, `version/code` (+1), `application/file_version` y `application/product_version`
  (`x.y.z.código`) y `application/short_version` y `application/version` de macOS e iOS. Luego etiqueta
  `v<versión>`. Si algo no cuadra, el primer paso de la Release lo dice.
- **De Godot:** cambia `GODOT_VERSION` en los dos workflows, revisa las opciones de los presets contra la nueva
  referencia de clases, el Xcode que piden las plantillas de iOS (el SDK de sus bibliotecas) y el runner de macOS.

## Para el coordinador

1. **`godot/gdlintrc` (hecho en la fase 2, commit 4d4e05d).** El proyecto creció con líneas de datos muy largas: con
   esta propuesta aún salían 1441 avisos, así que el `gdlintrc` final quita también el límite de línea, de líneas por
   archivo y de métodos públicos, y el orden de las definiciones. Los 10 avisos reales se arreglaron: gdlint da 0.
   Propuesta original: con la configuración por defecto de gdtoolkit 4, gdlint da 83 avisos en el código actual (líneas de más de 100 caracteres, notación física como `F`, `R`, `Dp` o
   `Estar`, `const _Js`, y más de 6 `return` en `tests/case.gd`). Propuesta, probada con gdtoolkit 4.5.0 (0 avisos):

   ```yaml
   # Convenciones de GDScript del proyecto para gdlint (gdtoolkit 4). Solo cambia lo que difiere de los valores
   # por defecto (gdlint --dump-default-config):
   # · líneas de hasta 150 caracteres, el estilo del proyecto (tablas y mensajes largos en los tests);
   # · argumentos y variables con mayúsculas para la notación física (F, R, H, Dp, Estar…), como en physics.js;
   # · constantes de preload privadas en PascalCase (const _Js = preload(…));
   # · sin límite de return por función: los comparadores del oráculo (tests/case.gd) salen pronto por tipo.
   max-line-length: 150
   function-argument-name: _?[a-zA-Z][a-zA-Z0-9]*(_[a-zA-Z0-9]+)*
   function-variable-name: '[a-zA-Z][a-zA-Z0-9]*(_[a-zA-Z0-9]+)*'
   loop-variable-name: _?[a-zA-Z][a-zA-Z0-9]*(_[a-zA-Z0-9]+)*
   load-constant-name: (_?([A-Z][a-z0-9]*)+|_?[A-Z][A-Z0-9]*(_[A-Z0-9]+)*)
   disable:
     - max-returns
   ```

2. **`release.yml` de la 1.x también se dispara con las etiquetas `v2*`** (escucha `v*`). Hoy fallaría en su primer
   paso (la etiqueta no coincide con `package.json`, 1.0.0) y dejaría una ejecución en rojo; si alguien subiera
   `package.json` a 2.x, compilaría la 1.x y la subiría a la misma Release. Propuesta: `tags: ["v1*"]` en
   `release.yml`, o retirarlo cuando la V2 sustituya a la 1.x.
3. **`THIRD-PARTY-NOTICES.md`:** la V2 incluye Godot Engine (MIT) y sus componentes de terceros. Los paquetes ya
   llevan `GODOT-LICENSE.txt` y `GODOT-COPYRIGHT.txt` de la etiqueta 4.7.2-stable, pero el APK y la `.ipa` no pueden
   llevar archivos sueltos: la app debería mostrarlos (por ejemplo en un «Acerca de» con
   `Engine.get_license_text()` y `Engine.get_copyright_info()`), y el archivo de avisos debería citar Godot.
4. **Icono adaptable de Android:** sin `launcher_icons/adaptive_foreground_432x432` Godot usa el icono entero como
   primer plano y la máscara del lanzador lo recorta. Hace falta un primer plano de 432×432 con el logotipo dentro
   del círculo central de 264 px (la 1.x tiene `apps/mobile/assets/adaptive-icon.png`) y el fondo #170E1C, en
   `godot/assets/`, y apuntar a ellos desde el preset.
5. **Código de versión de Android:** la V2 usa `version/code=1`, el mismo que el APK de la 1.x con el mismo paquete.
   Android deja instalarla encima (igual o mayor, con la misma clave), pero cada versión siguiente tiene que subirlo.
6. **Vibración (hecho en la fase 2):** el laboratorio vibra con cada efecto de sonido en el teléfono
   (`app/common/haptics.gd`, con `Input.vibrate_handheld()`, como los hápticos de la 1.x), y el preset de Android
   activa `permissions/vibrate`; sin ese permiso la vibración no funciona. iOS no pide permiso.
7. **Aviso inofensivo al exportar iOS:** «Property not found: application/boot_splash/fullsize» lo emite el propio
   exportador de Godot 4.7.2 al leer un ajuste que ya no existe; no hay que tocar nada.
