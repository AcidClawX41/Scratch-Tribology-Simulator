# 6a · Música de fondo: tres canciones con su botón al lado del sonido

- **Petición 59 de Eric (12-10-2026)**, para cuando se reinicie el límite semanal (sábado 17-10-2026): «otra cosa que me
  gustaría añadir a la aplicación son 3 canciones de música, que podrán activarse y desactivarse con un botón al lado del
  del sonido; por defecto vendrá desactivado».
- **Estado:** en cola. Las tres canciones ya están en `godot/assets/music/` (con `.gdignore`, sin importar) y su origen en
  `godot/assets/music/LEEME.md`.
- **Quién:** pequeño y toca la barra de arriba (`app/main.gd`) y los buses de audio (`default_bus_layout.tres`), que son
  del coordinador: lo hace el coordinador o un agente con permiso expreso para esos dos archivos.

## Lo que hay

- Tres versiones de «After Hours at the Test Bench» (Eric Valls Gramunt, creadas con Suno), MP3 de 64 kbps, 48 kHz,
  estéreo, de unos 9 minutos cada una: 12,8 MB en total (cada exportación crece eso; el APK también).
- La barra de arriba tiene el botón de sonido (`sound_button`, un `Pill` «IconButton» con el altavoz); `toggle_sound` y
  `_apply_sound` silencian **el bus «Master»**, y el sonido de la interfaz (`ui_sound`) va directo a «Master». Los buses son
  Master (con limitador), Lab y Maquina. Ajustes en `user://ajustes.cfg`, sección `[app]`.

## Lo que hay que hacer

1. **Importar la música:** borrar `godot/assets/music/.gdignore`, importar los tres MP3 como `AudioStreamMP3` sin bucle
   (versionar sus `.import`), y comprobar que la exportación de Linux y Windows los lleva.
2. **Un bus «Musica»** en `default_bus_layout.tres`, que envía a Master, con el volumen por debajo de los efectos (de
   partida −10 dB, a ajustar escuchando: la música acompaña, no tapa el clic de la lima ni el torno).
3. **Que los dos botones sean independientes.** Hoy el de sonido silencia Master, que silenciaría también la música. El de
   sonido pasa a silenciar solo los efectos: Lab, Maquina y un bus nuevo «Interfaz» para `ui_sound` (en vez de Master). El
   de música silencia o reproduce el bus «Musica». Así se puede tener música sin efectos o efectos sin música. **Los
   efectos de sonido no cambian (Eric, 12-10-2026):** siguen todos, encendidos por defecto y con su botón de siempre.
4. **El botón de música** al lado del de sonido, en las dos secciones, con un icono de nota musical (dibujado como el
   altavoz, sin fuentes de iconos nuevas), su `tooltip_text` y su nombre accesible («Música: apagada» / «Música:
   encendida»), y en las cinco formas de la barra (`BAR_LEVELS`) y en el teléfono (con el tamaño táctil de los demás
   botones).
5. **Por defecto, apagada.** Se guarda en `ajustes.cfg` (`[app] music = false`) y se recuerda al volver a abrir. Con la
   música apagada no se carga ni se reproduce nada (que no gaste memoria ni CPU).
6. **Cómo suena:** al encender, empieza por una de las tres al azar (con el `rng` de semilla de la app, no `randf()`) y
   sigue con las demás en orden, en bucle; un fundido corto al encender y al apagar (sin cortes secos). En el teléfono se
   pausa al pasar la app a segundo plano y sigue al volver.
7. **Créditos y licencias:** en la hoja «Créditos y licencias» y en `THIRD-PARTY-NOTICES.md`: «Música: “After Hours at the
   Test Bench” (tres versiones), de Eric Valls Gramunt, creada con Suno», con la licencia que decida Eric (abajo). En el
   README, que la música no va bajo MIT.
8. **Tests:** apagada por defecto; el interruptor se guarda y se lee; el bus «Musica» existe y envía a Master; el botón de
   sonido ya no silencia la música ni el de música los efectos; con la música apagada no hay ningún `AudioStreamPlayer`
   reproduciendo; los tres archivos cargan; el botón tiene nombre accesible. Sin tests que dependan del tiempo con
   márgenes justos.
9. **Verificación:** batería completa, `npm test`, gdlint, una captura de la barra en escritorio y teléfono, y un WAV de
   Movie Maker con la música encendida (que suena, con fundido, y por debajo de un efecto).

## Licencia

Las etiquetas de los MP3 dicen «made with Suno». **Eric confirmó el 12-10-2026 que las creó con el plan Pro de Suno.**
Según los términos de Suno, lo que se crea con un plan de pago es del usuario y se puede usar y distribuir, también de
forma comercial; así que se pueden publicar con el programa en el repositorio público y en las tiendas.

La música va aparte de la licencia MIT del código. Mientras Eric no elija otra, se marca como «© 2026 Eric Valls Gramunt.
Todos los derechos reservados. Se distribuye solo con Tribology Simulator & Industrial Workshop»; si prefiere que otros
puedan reutilizarla, una Creative Commons (por ejemplo CC BY 4.0). Eso se pone en «Créditos y licencias», en
`THIRD-PARTY-NOTICES.md` (o un `godot/assets/music/LICENCIA.txt`) y en el README.
