## Nombre y avisos del programa de la 2.0. Desde la 2.0 el programa se llama «Tribology Simulator & Industrial
## Workshop» porque ya no es solo un simulador de rayado: tiene también el taller industrial. La 1.x (Tauri y Expo) sigue
## llamándose Scratch Tribology Simulator, y `core/lab/lab.gd` → `license_note()` conserva su texto al pie de la letra,
## porque lo compara el oráculo. Los identificadores de instalación (com.acidclawx41.scratchtribology) no cambian: así la
## 2.0 se instala encima de la 1.x.
extends RefCounted

const NAME := "Tribology Simulator & Industrial Workshop"
## Subtítulo en español para la interfaz y la documentación.
const NAME_ES := "Simulador de tribología y taller industrial"
## Nombre sin espacios ni símbolos para archivos (ejecutables, paquetes, carpeta de datos).
const FILE_NAME := "TribologySimulatorWorkshop"
## Nombre de la 1.x, para los créditos.
const PREVIOUS_NAME := "Scratch Tribology Simulator"
const AUTHOR := "Eric Valls Gramunt"

# ── Donaciones (petición 39): el botón «Dona o invítame» de la barra superior, en las dos secciones ──
## Los enlaces los edita Eric. Uno con la url vacía no sale; sin ninguno, el panel enseña solo el texto. Cada uno se abre
## en el navegador del sistema al pulsarlo (OS.shell_open): el programa no hace ninguna llamada a la red por su cuenta.
const DONATE_LINKS := [
	{ "id": "github", "label": "GitHub Sponsors", "detail": "Único o mensual", "url": "https://github.com/sponsors/AcidClawX41" },
	{ "id": "paypal", "label": "PayPal", "detail": "Donación directa", "url": "https://paypal.me/EricValls" },
	{ "id": "kofi", "label": "Ko-fi", "detail": "Un café o más", "url": "https://ko-fi.com/ericdev" },
]
## El botón (en el teléfono, el corto) y el título del panel.
const DONATE_BUTTON := "Dona o invítame"
const DONATE_BUTTON_SHORT := "Invítame"
const DONATE_TITLE := "Dona o invítame a un café"
## La fecha de nacimiento de Eric (petición 41): su edad del texto de las donaciones sale de ella y de la fecha del sistema
## (donate_text), así que cada 13 de mayo sube un año sola.
const AUTHOR_BIRTH := { "year": 1994, "month": 5, "day": 13 }
## El texto del panel, de Eric, en primera persona (revisado por él el 04-10-2026). Un párrafo por elemento; «{edad}» es su
## edad del día (donate_text). Los dos primeros son la entradilla (el saludo y la frase que lo sigue); el resto va por
## secciones (DONATE_SECTIONS).
const DONATE_TEXT := [
	"Hola, soy Eric Valls Gramunt y tengo {edad} años.",
	"Este programa lo he hecho poco a poco y en mi tiempo libre.",
	"Nació de una pregunta sencilla: ¿qué raya, qué corta y qué perfora a qué? Empezó con uñas, garras y colmillos, y ha crecido hasta un laboratorio de tribología biológica (con el coche en marcha, la cetrería veterinaria y la reforja de garras) y un taller industrial, todavía en desarrollo, con torno manual y CNC, fresadora, taladro, radial y afiladora. Todo con física de verdad: cada número lleva su fuente, y lo que no está medido se marca como estimación.",
	"Lo he codiseñado junto con Claude Code, revisando yo mismo buena parte de los diseños en 3D en Godot y del código.",
	"He pasado por dos ciclos de FP Superior: Diseño en Fabricación Mecánica, donde trabajé con simuladores de torno como el que inspiró el taller de este programa, e Informática, donde estudié sobre todo sistemas. Este proyecto junta lo que más me gusta: la mecánica, la ciencia de los materiales y el software. Fuera de aquí, me apasionan la inteligencia artificial, el hardware y los videojuegos.",
	"También soy un apasionado de los animales, sobre todo de las aves y de los felinos: en mi tiempo libre disfruto yendo de vez en cuando a cursos de cetrería (jeje, de ahí la cetrería de este programa) y haciendo excursiones por la montaña con mis amigos, cuando las condiciones lo permiten.",
	"Espero que ayude a algunos futuros estudiantes de FP y de carrera a animarse a hacer cálculos y a experimentar con la física.",
	"El programa es gratuito, sin anuncios y no recoge ningún dato. Si te ha gustado o te ha resultado útil, puedes invitarme a un café o apoyar el proyecto. Cualquier ayuda me anima a seguir mejorándolo. ¡Gracias!",
]
## Secciones en desarrollo (petición 40): el selector las marca con «· WIP» y la sección lleva este aviso.
const WIP_SECTIONS := ["taller"]
const WIP_NOTE := "WIP · En desarrollo: el taller ya funciona en muchas cosas, pero aún faltan partes por terminar e implementar."
## Las secciones del panel, en su orden: [título, párrafos de DONATE_TEXT, si llevan las tarjetas de donación]. La de
## apoyar va primero, justo después de la entradilla (los dos primeros párrafos), para que las tarjetas se vean sin bajar.
const DONATE_SECTIONS := [["Apóyalo", [7], true], ["El proyecto", [2, 3, 6], false], ["Sobre mí", [4, 5], false]]
## La nota bajo los enlaces.
const DONATE_NOTE := "Cada enlace se abre en tu navegador. El programa no se conecta a nada por su cuenta."


## La edad (años cumplidos) el día today ({ year, month, day }, como Time.get_date_dict_from_system) de quien nació el día
## birth: los años de diferencia, uno menos si today cae antes del cumpleaños de ese año.
static func age_on(today: Dictionary, birth: Dictionary = AUTHOR_BIRTH) -> int:
	var age := int(today.get("year", 0)) - int(birth.year)
	var m := int(today.get("month", 1))
	var d := int(today.get("day", 1))
	if m < int(birth.month) or (m == int(birth.month) and d < int(birth.day)):
		age -= 1
	return maxi(age, 0)


## El texto del panel con la edad de Eric el día today (la fecha la pone la interfaz: aquí no se lee el reloj).
static func donate_text(today: Dictionary) -> Array:
	var age := "%d" % age_on(today)
	return DONATE_TEXT.map(func(p: String) -> String: return p.replace("{edad}", age))


## Los enlaces de donación que tienen url (los vacíos no salen).
static func donate_links(links: Array = DONATE_LINKS) -> Array:
	return links.filter(func(l: Dictionary) -> bool: return String(l.get("url", "")).strip_edges() != "")


## Pie y créditos: nombre, versión, autor y licencias (programa MIT; fuentes OFL).
static func license_note(version: String) -> String:
	return "%s %s © 2026 %s · Licencia MIT. Tipografías Syne y Space Mono: SIL Open Font License 1.1." % [NAME, version, AUTHOR]
