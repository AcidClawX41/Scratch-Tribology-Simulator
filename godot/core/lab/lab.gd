## Tribología biológica · lógica del laboratorio (port de packages/core/src/lab.js, motor 1.x).
##
## Logros, fichas, etiquetas del cuaderno, fundamentos y el modo dual (el mismo ensayo en dos coches). No es física,
## pero vive en core para que la interfaz solo pinte: los textos salen idénticos a los del motor 1.x (el oráculo),
## con los formatos de core/shared/format.gd.
## Uso: const Lab = preload("res://core/lab/lab.gd"), y después Lab.earn_badges(prev, ctx), Lab.duel(…)…
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
## Aguijones de insectos (modelo 2.0): sus textos (mN y mg) y su modo dual, que solo pica.
const Insects = preload("res://core/lab/insects.gd")
const StingLab = preload("res://core/lab/sting_lab.gd")
## El velocirraptor reconstruido (modelo 2.0; unidad 4i): su fuerza máxima.
const DinoLab = preload("res://core/lab/dino_lab.gd")

const BADGES := [
	{ "id": "vidrio", "t": "Barrera del vidrio" }, { "id": "movil", "t": "Pantalla a salvo" },
	{ "id": "zafiro", "t": "Cazadora de zafiros" }, { "id": "diamante", "t": "Diamante vs diamante" },
	{ "id": "piel", "t": "Marca en la piel" }, { "id": "fisico", "t": "Físico de bata" },
	{ "id": "coche", "t": "Pintura al descubierto" }, { "id": "depredador", "t": "Depredador" },
	{ "id": "resplandor", "t": "🪓 ¡Aquí está Johnny!" }, { "id": "metal", "t": "Marca en el metal" },
	{ "id": "casuario", "t": "🦖 Dinosaurio vivo" }, { "id": "colmillo", "t": "🦷 Colmillo roto" },
	{ "id": "banera", "t": "🛁 Uña de bañera" }, { "id": "abrelatas", "t": "🥫 Abrelatas" },
	{ "id": "cristal", "t": "💥 Cristal roto" },
]
## Número de ensayos que da el logro «Físico de bata».
const BADGE_RUNS := 8
## Logros de lo nuevo de la 2.0 (unidad 4p), aparte de los de la 1.x (BADGES, que compara el oráculo y no cambian): los
## aguijones, el velocirraptor (el de verdad y el de cine), las zonas del cuerpo, el hueso, el ángulo de ataque, la uña que
## se parte, la ventanilla templada y el coche en marcha. Solo se ganan con la física 2.0; los de `car`, en la página del coche
## en marcha (earn_car_badges), y los demás, en el banco (earn_badges_model), en este orden.
const BADGES_V2 := [
	{ "id": "kamikaze", "t": "🐝 Kamikaze" }, { "id": "raptor", "t": "Raptor de verdad" },
	{ "id": "cine", "t": "Solo en el cine" }, { "id": "callo", "t": "Callo de serie" },
	{ "id": "penetrante", "t": "Herida penetrante" }, { "id": "hueso", "t": "Hasta el hueso" },
	{ "id": "gancho", "t": "🪝 De gancho" }, { "id": "unarota", "t": "💅 Uña rota" },
	{ "id": "martillo", "t": "Martillo de emergencia" }, { "id": "polizon", "t": "🐾 Polizón", "car": true },
	{ "id": "abollado", "t": "Abollado en marcha", "car": true },
]
## Velocidad (km/h) desde la que un animal que aguanta encima del coche en marcha gana «Polizón».
const POLIZON_KMH := 100.0

## Orden en que earnBadges (lab.js) comprueba los logros: el conjunto de logros conserva el orden de inserción, así
## que un ensayo que gana dos logros los añade en este orden, igual que el Set del JS.
const BADGE_ORDER := [
	"vidrio", "zafiro", "movil", "diamante", "piel", "coche", "abrelatas", "cristal", "resplandor", "metal", "depredador",
	"casuario", "colmillo", "banera", "fisico",
]

## Fundamentos físicos (resumen de docs/FISICA.md) que muestra la interfaz: [título, texto].
const FUNDAMENTOS := [
	["Presión", "nominal P = F/A (lo que la punta «pide»); la REAL nunca supera la dureza de quien cede (Tabor)."],
	["Punta esfero-cónica", "radio R = √(A/π) y semiángulo α. Una punta roma trabaja como esfera (h ∝ F); una afilada, como cono (h ∝ √F)."],
	["Hertz", "por debajo de p0 = 1,6·Y el contacto es elástico y no deja huella. La fricción adelanta la plastificación (von Mises √(1+3μ²))."],
	["Quién cede", "con r = HV_punta/HV_obj < 0,8 cede la punta (Pintaude); por encima se deforma cada vez menos hasta r ≈ 2."],
	["Profundidad", "la carga la soporta H·π·a² (punción) o H·π·a²/2 al rayar (solo trabaja el frente del surco)."],
	["Multicapa", "pintura sobre la carrocería (acero de 0,7 mm en un coche moderno, acero dulce de ~0,9 mm en uno clásico, aluminio de 1 mm o plástico de ~2,5 mm): la queratina no corta el metal. Laca dura sobre roble (efecto cáscara de huevo)."],
	["Chapa fina", "una punta dura primero rompe la chapa (dureza) y luego abre el agujero en pétalos: E = σ0·t²·l·[1,23 + 8,9·(l/t)^0,4] (Wierzbicki 1999). Perforar es que la punta asome por detrás; atravesar, que pase la garra entera."],
	["Vidrio de ventana", "la hoja de 4 mm se parte al flexar hasta 45 MPa (EN 572-1): ~200 N en el centro (Roark), aunque la punta sea blanda. En un golpe cuenta la fuerza de pico, que el tejido blando de la pata amortigua: un gato no la rompe; un oso, sí."],
	["Frágil", "vidrio y gemas se rayan por microfractura cuando la punta es más dura; el acero blando no raya el vidrio."],
	["Piel", "capas: córnea, epidermis (sin vasos), dermis (aguanta y sangra), grasa, fascia y músculo. Romperla exige la fuerza medida in vivo (Davis 2004); dentro, la punta acuña una grieta (F = 2·J·a) y al arrastrar la garra rasga: F = ∫J dz (tenacidad al desgarro de cada capa)."],
	["Impacto", "½·m·v² de cada garra más el trabajo del empuje = trabajo de penetración ∫F·dh. El casuario es el único que atraviesa la puerta de roble."],
	["Límites", "nada se hunde más que su propia garra, y los colmillos se rompen a ~30 N (Estrada 2026)."],
	["Queratina húmeda", "empapada pierde ~80 % de rigidez y resistencia (Farran 2009): una uña mojada apenas raya."],
	["Modo de abrasión (Hokkirigawa-Kato)", "Dp = h/a decide arado (< 0,1: desplaza) → cuña → corte (> 0,2: arranca viruta). Fricción de rayado μ = μ_adh + μ_arado."],
	["Desgaste (Archard)", "V ∝ F·L/H, por la fracción realmente arrancada."],
	["Adhesión (Van der Waals, JKR)", "F_adh = 1,5·π·R·W: despreciable a escala macro."],
]
const FUNDAMENTOS_NOTE := "Mohs es ordinal y no lineal; el motor calcula en Vickers. Detalle y fuentes en docs/FISICA.md."
## Fundamentos de los materiales de la 2.0 (resumen de docs/fisica/pulido-materiales.md): frágiles, uñas que ceden,
## recuperación, abolladura y vidrios de coche.
const FUNDAMENTOS_V2 := [
	["Frágiles (2.0)", "una punta roma y dura no raya el vidrio, pero lo agrieta: la grieta de anillo salta a un cono con P = A·K_c²·R/E* (ley de Auerbach) y, al deslizar, la fricción divide esa carga por (1 + k·μ)³ (Ren & Zhang 2014): herraduras desde ~1 N. Una punta afilada hace surco y, pasado un tamaño crítico de huella, grietas laterales que astillan el borde (Lawn & Evans 1977)."],
	["Uñas que ceden (2.0)", "el borde libre es un voladizo: se dobla (queratina, metal) o se parte (gel, acrílico, zafiro) cuando F·L llega a σ·Z, con la «C» de la uña (radio de 7,4 mm, Jung 2015). Una stiletto natural cede a ~14 N: el resto de la fuerza se queda en el dedo. Ataque de 45° (estimación)."],
	["Recuperación (2.0)", "la profundidad del ensayo es bajo carga; al levantar la punta el material devuelve h = m·π·a·H/(2E') (Oliver & Pharr 1992). El barniz y el ABS recuperan mucho; los metales, casi nada. Lo que se ve es la huella residual."],
	["Abolladura y vidrios de coche (2.0)", "la chapa se abolla por encima de su carga de colapso, π·C·σ·t²/2 (Jones 1989; calibrado con Nippon Steel 2013): un zarpazo de oso la abolla ~3 mm. La ventanilla templada estalla en trocitos romos si la flexión o una grieta atraviesan su capa comprimida; el parabrisas laminado se agrieta, pero la lámina de PVB sujeta los trozos."],
	["Afilado de las garras (2.0)", "una garra reforjada se puede afilar de su punta natural al filo de una hoja de afeitar (40 nm; Roscioli 2020). Con la misma fuerza la presión sube con R^(−2/3) (Hertz) y la punta entra más, pero la carga que aguanta de lado baja con R² (una viga en voladizo; Pattrick 2018): la fricción al rayar mella una punta frágil muy afilada o dobla una de metal. El velocirraptor es una reconstrucción: su punta no fosiliza y es una pregunta abierta."],
	["Patada del casuario (2.0)", "sale del salto del coche en marcha: con los pies por delante a ~4,8 m/s (el trabajo por kilo de músculo de un ave, Henry 2005, con la masa muscular de una pata de avestruz, Hutchinson 2015). En el banco la daga lleva la masa de los músculos de la pata que patea de la hembra de 58 kg, la del coche en marcha: ~88 J (hasta ~340 J con todo su trabajo), no los 160 J de la 1.x. Con su fuerza de ficha, la daga ya no atraviesa la puerta de roble de 35 mm: se queda a ~31 mm."],
]
## Fundamentos de la biología de la 2.0 (unidad 4n; resumen de docs/fisica/pulido-biologia.md y velociraptor.md): zonas
## y hueso, la punción por capas, el ángulo de ataque, el esmalte de los colmillos y el velocirraptor.
const FUNDAMENTOS_BIO_V2 := [
	["Zonas del cuerpo y hueso (2.0)", "cada zona (brazo, palma, dorso de la mano, pómulo, abdomen) tiene sus espesores de capa y, debajo, hueso o la cavidad abdominal. La punta que llega a la cortical tiene que indentarla: con menos de 1,25 veces la dureza del hueso (toda la queratina y, contra el húmero o los metacarpianos, la dentina de los colmillos en cuanto el contacto sale del esmalte), el hueso la para (Richardson 1968)."],
	["Punción por capas (2.0)", "la grieta se abre en todas las capas que cruza la parte ancha de la punta, F = 2·Σ J·Δρ, nunca más ancha que la herramienta (Shergold & Fleck 2005), y los flancos rozan: τ = ξ·⟨p⟩ con la presión de la grieta acuñada de Fregonese & Bacca (2022) y ξ = 0,05 (estimación). La resistencia ya no cae de golpe al salir de la dermis."],
	["Ángulo de ataque (2.0)", "el que forma el eje de la punta con la superficie (90° = de punta). Inclinarla gira la cara que avanza, θ = ataque − α, y con ella el grado de penetración que decide arado, cuña o corte (Challen & Oxley 1979; Sedriks & Mulhearn 1963); en una uña, el mismo ángulo decide cuánto se dobla. Nadie lo ha medido al rayar: 45° en las uñas y 90° en las garras son estimaciones."],
	["Esmalte de los colmillos (2.0)", "la punta del colmillo de víbora es un casquete de esmalte sobre dentina (Estrada 2026). Su dureza va de la del esmalte (3,15 GPa, el de cocodrilo: Enax 2013) en un contacto pequeño a la de la dentina (0,6 GPa) en uno grande: H(a) = H_d + (H_e − H_d)·e^(−a/t), con t = 10 µm (estimación)."],
	["Velocirraptor (2.0)", "una reconstrucción de Deinonychus: masa, garra, agarre de un pie y salto en bandas, cada una con su fuente. La punta no fosiliza: se ensaya con la de la arpía (pregunta abierta). El de película es ficción: su garra es dura como el acero; la de verdad, de queratina, no raja la chapa de un coche."],
]
## «Impacto» de la 1.x con la patada de la 2.0: en la 1.x el casuario atraviesa la puerta de roble; en la 2.0, no.
const FUNDAMENTO_IMPACTO_V2 := ["Impacto", "½·m·v² de cada garra más el trabajo del empuje = trabajo de penetración ∫F·dh. Con la física de la 1.x el casuario es el único que atraviesa la puerta de roble; con la de la 2.0 su patada sale del salto y se queda a ~31 mm (ver «Patada del casuario»)."]
## Nota de los fundamentos sin rutas del proyecto: las fuentes de cada ensayo, debajo del resultado.
const FUNDAMENTOS_NOTE_V2 := "Mohs es ordinal y no lineal; el motor calcula en Vickers. Cada ensayo de la 2.0 enseña debajo del resultado las fuentes y estimaciones que ha usado; el detalle, en «Modelo físico y fuentes», la documentación del proyecto."
## Pie del banco con cada física (el de la 1.x es el de App.jsx, con la documentación por su nombre y no por su ruta).
const MODEL_NOTE_V1 := "Modelo educativo v2 con datos publicados: nanoindentación de uña (E ≈ 2,9 GPa), barniz de coche (0,2–0,4 GPa), punción de piel in vivo (Davis 2004), colmillos de víbora (Estrada 2026) y agarre de rapaces (Sustaita & Hertel 2010). Fuerzas y golpes de animales: estimaciones. Mohs↔Vickers no es lineal. Detalle y fuentes en «Modelo físico y fuentes», la documentación del proyecto."
const MODEL_NOTE_V2 := "Física 2.0 con datos publicados: lo de la 1.x y, además, zonas del cuerpo con su hueso, esmalte de los colmillos, frágiles que se agrietan, vidrios de coche, abolladura, recuperación elástica, aguijones y el velocirraptor. Fuerzas y golpes de animales, el ángulo de ataque y la punta del velocirraptor: estimaciones. Mohs↔Vickers no es lineal. Cada ensayo cita sus fuentes y estimaciones debajo del resultado."


## Los fundamentos de la hoja «Fundamentos» (no dependen de la física elegida: la hoja se escribe una vez): los de la
## 1.x (con «Impacto» para las dos físicas), los de los materiales y la biología de la 2.0 y el de los aguijones.
static func fundamentos() -> Array:
	var out: Array = []
	for f: Array in FUNDAMENTOS:
		out.append(FUNDAMENTO_IMPACTO_V2 if f[0] == FUNDAMENTO_IMPACTO_V2[0] else f)
	return out + FUNDAMENTOS_V2 + FUNDAMENTOS_BIO_V2 + StingLab.FUNDAMENTOS


## El pie del banco con la física elegida.
static func model_note(model: String) -> String:
	return MODEL_NOTE_V1 if model == Physics.MODEL_V1 else MODEL_NOTE_V2


## Modo dual: la pareja por defecto (antiguo frente a moderno) y las maneras de atacar: rayar, desgarrar (solo
## garras), punzar empujando y golpear.
const DUEL_DEFAULT := ["cocheclasico", "coche"]
const DUEL_MODES := [
	{ "id": "rayado", "name": "Raya", "p": { "method": "rayado", "strike": false, "tear": false } },
	{ "id": "desgarro", "name": "Desgarra", "p": { "method": "rayado", "strike": false, "tear": true }, "clawOnly": true },
	{ "id": "puncion", "name": "Punza", "p": { "method": "puncion", "strike": false, "tear": false } },
	{ "id": "golpe", "name": "Golpea", "p": { "method": "puncion", "strike": true, "tear": false } },
]
## Coches del modo dual: los materiales que tienen carrocería (TARGETS.filter((t) => t.body) del JS). Van por
## índice porque una constante no admite filtros. No pueden desplazarse sin avisar: test_data.gd fija el orden y los
## ids de TARGETS a los del oráculo y comprueba que estos son los cuatro coches.
const DUEL_CARS := [Data.TARGETS[6], Data.TARGETS[7], Data.TARGETS[8], Data.TARGETS[9]]


## Logros tras un ensayo. prev es un conjunto de ids (diccionario id → true, en orden de inserción); devuelve un
## conjunto nuevo (no modifica prev). ctx: { res, target, inlay, claw, method, strike, runs }.
static func earn_badges(prev: Dictionary, ctx: Dictionary) -> Dictionary:
	var nb := prev.duplicate()
	for id: String in BADGE_ORDER:
		if badge_earned(id, ctx):
			nb[id] = true
	return nb


## Condición de cada logro (las de earnBadges en lab.js). ctx: { res, target, inlay, claw, method, strike, runs }, con
## claw null si el ensayo es con una uña.
static func badge_earned(id: String, ctx: Dictionary) -> bool:
	var res: Dictionary = ctx.res
	var target: Dictionary = ctx.target
	var claw: Variant = ctx.get("claw")
	var scratched: Variant = res.get("scratched")
	match id:
		"vidrio":
			return Physics.is_true(scratched) and target.id == "vidrio"
		"zafiro":
			return Physics.is_true(scratched) and target.id == "zafiro"
		"movil":
			return Physics.truthy(res.get("toolWorn")) and target.id == "movil"
		"diamante":
			return target.id == "diamante" and ctx.inlay.id == "diamante"
		"piel":
			return target.id == "piel" and Physics.truthy(scratched)
		"coche":
			return Physics.truthy(target.get("paint")) and res.depthUm >= 45.0
		"abrelatas":
			return Physics.truthy(target.get("body")) and Physics.truthy(res.get("through"))
		"cristal":
			return Physics.truthy(res.get("shattered"))
		"resplandor":
			return target.id == "puertamadera" and res.verdict == "ATRAVIESA LA PUERTA"
		"metal":
			return target.id == "puertametal" and Physics.truthy(scratched)
		"depredador":
			return Physics.truthy(claw)
		"casuario":
			return (Physics.truthy(claw) and claw.id == "casuario" and ctx.get("method") == "puncion"
				and Physics.truthy(ctx.get("strike")) and target.id == "piel" and Physics.truthy(scratched))
		"colmillo":
			return Physics.truthy(res.get("toolBroken")) and Physics.truthy(claw) and Physics.truthy(claw.get("fang"))
		"banera":
			return Physics.truthy(res.get("wet")) and not Physics.truthy(scratched) and not Physics.truthy(target.get("skin"))
		"fisico":
			return ctx.runs >= BADGE_RUNS
	return false


## Logros tras un ensayo del banco con la física elegida (unidad 4p): los de la 1.x (earn_badges, idénticos al oráculo) y,
## con la 2.0, los de BADGES_V2 que salen del banco (badge_v2_earned), detrás y en su orden. ctx, el de earn_badges.
static func earn_badges_model(prev: Dictionary, ctx: Dictionary, model: String) -> Dictionary:
	var nb := earn_badges(prev, ctx)
	if model != Physics.MODEL_V2:
		return nb
	for b: Dictionary in BADGES_V2:
		if not b.get("car", false) and badge_v2_earned(String(b.id), ctx):
			nb[b.id] = true
	return nb


## Condición de cada logro de la 2.0 que sale del banco, con el resultado de compute() (modelo 2.0) y la selección del
## ensayo (ctx de earn_badges):
##   - kamikaze: un aguijón se queda clavado y el insecto se desgarra al irse (la autotomía de la abeja: res.sting);
##   - raptor: el velocirraptor reconstruido (el de verdad, no el de cine) deja su marca;
##   - cine: la garra de película del velocirraptor de cine (sin reforjar) raja o atraviesa la chapa de un coche, lo que la de
##     verdad, de queratina, no puede;
##   - callo: el callo de la palma se pule sin sangrar («CALLO PULIDO»);
##   - penetrante: la punta pasa la pared del abdomen y entra en la cavidad («HERIDA PENETRANTE»);
##   - hueso: la punta llega al hueso (res.pen.boneHit), lo marque o no;
##   - gancho: de gancho (un ataque de más de 90°), la herramienta corta (modo de abrasión «corte»);
##   - unarota: la uña se parte («SE PARTE LA UÑA»: el gel, el acrílico o el zafiro, frágiles);
##   - martillo: la ventanilla templada estalla por una grieta que atraviesa su capa comprimida (el truco del martillo de
##     emergencia), no por flexión.
static func badge_v2_earned(id: String, ctx: Dictionary) -> bool:
	var res: Dictionary = ctx.res
	var claw: Variant = ctx.get("claw")
	match id:
		"kamikaze":
			var s: Variant = res.get("sting")
			return s is Dictionary and s.get("autotomy") == true
		"raptor":
			return DinoLab.is_dino(claw) and not DinoLab.is_film(claw) and Physics.truthy(res.get("scratched"))
		"cine":
			var inlay: Variant = ctx.get("inlay")
			var forged: bool = inlay is Dictionary and String(inlay.get("id", "none")) != "none"
			return (DinoLab.is_film(claw) and not forged and Physics.truthy(ctx.target.get("body"))
				and Physics.truthy(res.get("through")))
		"callo":
			return res.get("verdict") == "CALLO PULIDO"
		"penetrante":
			return res.get("verdict") == "HERIDA PENETRANTE"
		"hueso":
			var pen: Variant = res.get("pen")
			return pen is Dictionary and pen.get("boneHit") == true
		"gancho":
			var att: Variant = res.get("attackDeg")
			return att != null and float(att) > 90.0 and res.get("absMode") == "corte"
		"unarota":
			return res.get("verdict") == "SE PARTE LA UÑA"
		"martillo":
			var g: Variant = res.get("glazing")
			return (g is Dictionary and g.get("kind") == "templado" and g.get("cause") == "grieta"
				and Physics.truthy(res.get("shattered")))
	return false


## Logros del coche en marcha (unidad 4p; la página del coche, a través de LabState.earn_car_badges). ctx: { mode («hold» o
## «impact»), holds (aguanta a la velocidad del deslizador), vKmh (esa velocidad), hit (el resultado de impact(), o {}) }:
##   - polizon: quieto encima, aguanta a POLIZON_KMH o más;
##   - abollado: el golpe deja una abolladura que se ve en la chapa.
## Devuelve un conjunto nuevo (no modifica prev).
static func earn_car_badges(prev: Dictionary, ctx: Dictionary) -> Dictionary:
	var nb := prev.duplicate()
	if ctx.get("mode") == "hold" and ctx.get("holds") == true and float(ctx.get("vKmh", 0.0)) >= POLIZON_KMH:
		nb["polizon"] = true
	var hit: Variant = ctx.get("hit")
	if ctx.get("mode") == "impact" and hit is Dictionary and hit.get("ok") == true:
		var d: Variant = hit.get("dent")
		if d is Dictionary and d.get("visible") == true:
			nb["abollado"] = true
	return nb


## Nombre del material de una garra reforjada, en minúscula salvo siglas: "acero", "zafiro", "CZ".
static func material_name(inlay: Dictionary) -> String:
	var s: String = inlay.short
	var acronym := s.length() >= 2  # /^[A-Z]{2,}$/
	for i in s.length():
		var ch := s.unicode_at(i)
		if ch < 65 or ch > 90:
			acronym = false
	return s if acronym else s.to_lower()


## Ficha de una garra o colmillo con la herramienta resuelta (Physics.resolve_tool): una garra reforjada muestra su
## material y su dureza, no la de la queratina; una garra empapada, la dureza que le queda. Un aguijón es de quitina.
static func claw_spec(claw: Dictionary, inlay: Dictionary, tool: Dictionary) -> Dictionary:
	var has_gem := Physics.truthy(tool.get("hasGem"))
	var material: String
	if has_gem:
		material = material_name(inlay)
	elif Insects.is_stinger(claw):
		material = "quitina"
	else:
		material = "dentina" if Physics.truthy(claw.get("fang")) else "queratina"
		if Physics.truthy(tool.get("wet")):
			material += " húmeda"
	return {
		"title": Data.claw_title(claw) + (" de " + material_name(inlay) if has_gem else ""),
		"material": material,
		"hardness": "%s HV · Mohs %s" % [Format.fmt_p(tool.hv), Physics.template_str(tool.get("mohs"))],
	}


## Subtítulo de cada material en las fichas: su dureza o, en un coche, qué hay bajo la pintura.
static func target_sub(t: Dictionary) -> String:
	if Physics.truthy(t.get("skin")):
		return "tejido vivo"
	if Physics.truthy(t.get("body")):
		return "pintura + %s %s mm" % [String(t.body.name).to_lower(), Js.to_fixed(t.body.t / 1000.0, 1).replace(".", ",")]
	var hv: float = t.layers.film.hv if Physics.truthy(t.get("layers")) else t.hv
	# 2.0: los vidrios de coche dicen cómo están hechos (docs/fisica/pulido-materiales.md §7.5)
	var kind := " · templado" if Physics.truthy(t.get("tempered")) else (" · laminado" if Physics.truthy(t.get("laminated")) else "")
	return "%s HV%s%s" % [Js.js_num_str(hv), kind, " · frágil" if Physics.truthy(t.get("brittle")) else ""]


## Nombre corto de la herramienta para el cuaderno de ensayos. p: { claw, geom, inlay, res }.
static func tool_label(p: Dictionary) -> String:
	var claw: Variant = p.get("claw")
	var res: Dictionary = p.res
	# una garra «reforjada» es de ese material; en una uña, la piedra va incrustada
	var gem := ""
	if Physics.truthy(res.get("hasGem")):
		gem = (" de " + material_name(p.inlay)) if Physics.truthy(claw) else (" + " + String(p.inlay.short))
	var wet := " (húmeda)" if Physics.truthy(res.get("wet")) else ""
	return (Data.claw_title(claw) if Physics.truthy(claw) else String(p.geom.name)) + gem + wet


## Aviso de licencia del pie (textos completos en LICENSE y THIRD-PARTY-NOTICES.md), con la versión del programa.
## El motor 1.x lo escribía con su APP_VERSION ("1.0.0").
static func license_note(version: String) -> String:
	return "Scratch Tribology Simulator %s © 2026 Eric Valls Gramunt · Licencia MIT. Tipografías Syne y Space Mono: SIL Open Font License 1.1." % version


## Fuerza inicial del banco (N), la de la 1.x (LabState.LAB_DEFAULTS.force): la que se pone al volver de una
## herramienta con otra escala (un aguijón) a una de la 1.x.
const FORCE_DEFAULT := 4.0
## Escala de los aguijones (N): de 0,01 a 1000 mN. Una abeja empuja con unos 2-3 mN.
const STING_FMIN := 1.0 / 100000.0  # 1e-5 N (0,01 mN), con una división exacta en lugar de leer el decimal
const STING_FMAX := 1.0
## Un aguijón reforjado en otro material llega hasta 5000 mN: la abeja de diamante pandea hacia 3,8 N (ingeniero físico
## de los aguijones, docs/fisica/aguijones.md) y hay que poder llegar ahí.
const STING_FORGED_FMAX := 5.0


## Escala de fuerza de una herramienta (la garra, el colmillo o el aguijón elegidos; null con una uña), siempre en N:
## { min, max, default, unit: "N" | "mN", log: true }. `unit` solo decide cómo se muestra. inlay: la incrustación o el
## material con que está reforjada (entrada de Catalog.INLAYS o su id; null o "none", sin reforjar).
##   - Herramientas de la 1.x: de 0,5 a 2000 N (Format.FMIN y FMAX, como siempre); default, la fuerza inicial del banco.
##   - Aguijones (con la clave `stinger`, core/lab/insects.gd): de 0,01 a 1000 mN; reforjados en otro material, hasta
##     5000 mN. default, su `force`.
static func force_range(tool: Variant, inlay: Variant = null) -> Dictionary:
	if tool is Dictionary and Physics.truthy(tool.get("stinger")):
		var inlay_id: String = String(inlay.get("id", "none")) if inlay is Dictionary else (String(inlay) if inlay != null else "none")
		var fmax := STING_FORGED_FMAX if inlay_id != "none" else STING_FMAX
		var f: Variant = tool.get("force")
		var want: float = float(f) if typeof(f) in [TYPE_INT, TYPE_FLOAT] else STING_FMIN
		return { "min": STING_FMIN, "max": fmax, "default": clampf(want, STING_FMIN, fmax), "unit": "mN", "log": true }
	return { "min": Format.FMIN, "max": Format.FMAX, "default": FORCE_DEFAULT, "unit": "N", "log": true }


## Texto del botón de fuerza máxima (humana o del animal): { force, label, note }. El velocirraptor (2.0): el agarre de un
## pie y, en la nota, «la garra sola, ~10 N; la réplica, 483 N» (DinoLab.max_force_hint).
static func max_force_hint(claw: Variant) -> Dictionary:
	if not Physics.truthy(claw):
		return {
			"force": Data.HUMAN.force, "label": "humana",
			"note": "arañazo decidido, 1 uña. Una stiletto real se partiría antes. Un roce normal es ~1–5 N",
		}
	if Insects.is_stinger(claw):
		return StingLab.max_force_hint(claw)  # el empuje al picar, en mN, y el peso en mg
	if DinoLab.is_dino(claw):
		return DinoLab.max_force_hint(claw)  # el agarre de un pie; en la nota, la garra sola y la réplica
	if Physics.truthy(claw.get("fang")):
		return {
			"force": claw.force, "label": "del colmillo",
			"note": ("los colmillos hidratados aguantan ~%s N antes de romperse (Estrada 2026). Refórjalo en metal "
				+ "(incrustación) para empujar más.") % Physics.template_str(claw.get("fBreak")),
		}
	return {
		"force": claw.force, "label": "del " + String(claw.name).to_lower(),
		"note": "máximo esfuerzo (zarpazo o agarre) · peso ~%s kg. Un mimo/juego es mucho menos (~1–4 N)"
			% Physics.template_str(claw.get("mass")),
	}


# ════════ MODO DUAL: EL MISMO ENSAYO EN DOS COCHES ════════
# Qué raya, punza, desgarra o atraviesa la herramienta en cada coche, cuántos milímetros (o centímetros) y qué daño
# deja. Aquí se calcula; la interfaz solo lo pinta.

## Longitud legible con centímetros a partir de 1 cm (Format.fmt_len): 350 µm · 6.1 mm · 35 mm (3.5 cm).
static func fmt_len(um: float) -> String:
	return Format.fmt_len(um)


## Etapa de daño de un resultado sobre un coche: 0 nada · 1 pintura · 2 carrocería · 3 perforada · 4 atravesada. En la
## 2.0 una abolladura visible es daño de carrocería aunque no pase de la pintura (docs/fisica/pulido-materiales.md §7.7).
static func damage_stage(res: Dictionary) -> int:
	var verdict: String = res.verdict
	if verdict.begins_with("ATRAVIESA") or verdict.begins_with("RAJA"):
		return 4
	if verdict.begins_with("PERFORA LA") or verdict.begins_with("PERFORA EL"):
		return 3
	if res.depthUm > Data.PAINT_LAYERS[-1].to + 1.0 or _dent_visible(res):
		return 2
	return 1 if Physics.truthy(res.get("scratched")) else 0


## ¿Deja el ensayo una abolladura visible? (2.0: res.dent; en la 1.x es null).
static func _dent_visible(res: Dictionary) -> bool:
	var d: Variant = res.get("dent")
	return d is Dictionary and d.get("visible") == true


## Informe de daños: pares [etiqueta, valor] listos para pintar. length: largo del ensayo en mm (25 por defecto).
## En la 2.0 añade los trozos de la ventanilla templada, la telaraña del parabrisas, la abolladura y la uña que cede
## (docs/fisica/pulido-materiales.md §7.5 y §7.7); con un resultado de la 1.x (esos campos a null) es el de siempre.
static func damage_report(res: Dictionary, target: Dictionary, length: float = 25.0) -> Array:
	var out: Array = []
	var glazing: Variant = res.get("glazing")
	if Physics.truthy(res.get("shattered")):
		var glass := [["Vidrio", "se parte (pico ~%s N; aguanta ~%s N)" % [Format.fmt_f(res.peakN), Format.fmt_f(res.paneN)]]]
		if glazing is Dictionary and glazing.get("kind") == "templado":
			glass.append(["Trozos", "~%s por cada 5 × 5 cm, de ~%s mm: romos y sin filo" % [
				Js.js_num_str(Js.js_round(glazing.fragments25)), Js.to_fixed(glazing.fragmentMm, 1)]])
		return glass
	if glazing is Dictionary and glazing.get("kind") == "laminado" and glazing.get("cracked") == true:
		out.append(["Vidrio", "se agrieta en estrella y telaraña (aguanta ~%s N)" % Format.fmt_f(glazing.bendN)])
		out.append(["Lámina de PVB", "sujeta los trozos: no cae"])
		if glazing.get("penetrationRisk") == true:
			out.append(["Atravesarlo", "podría: %s J frente a los %s J de la homologación" % [
				Format.fmt_j(res.energyJ), Js.to_fixed(glazing.penetrationJ, 1)]])
	var dented := _dent_visible(res)
	if not Physics.truthy(res.get("scratched")) and not dented:
		if Physics.truthy(res.get("toolBroken")):
			return [["Daño", "ninguno: se dobla el aguijón" if res.get("sting") != null else "ninguno: se rompe la punta"]]
		var nail: Variant = res.get("nail")
		if nail is Dictionary and nail.get("broken") == true:
			return [["Daño", "ninguno visible (a ~%s N la uña se %s)" % [Format.fmt_f(nail.breakN), "parte" if nail.mode == "parte" else "dobla"]]]
		return [["Daño", "ninguno visible"]]
	var puncture := Physics.truthy(res.get("puncture"))
	var through := Physics.truthy(res.get("through"))
	if Physics.truthy(res.get("scratched")):
		out.append(["Profundidad", Format.fmt_len(res.depthUm)])
		var residual: Variant = res.get("residualDepthUm")
		if residual != null and float(residual) < res.depthUm - 0.05:
			out.append(["Queda al levantar la punta", Format.fmt_len(residual)])
		if through:
			out.append(["Agujero" if puncture else "Raja", "Ø " + Format.fmt_len(res.grooveWidthUm)])
		elif not puncture and res.grooveWidthUm > 0.0:
			out.append(["Surco", "%s cm de largo × %s" % [Js.to_fixed(length / 10.0, 1), Format.fmt_depth(res.grooveWidthUm)]])
		var L: Variant = Data.car_layers(target)
		if L != null:
			var broken: PackedStringArray = []
			for l: Dictionary in L:
				if res.depthUm > l.from + 1e-6:
					var n: String = l.name
					broken.append(n.substr(0, 1).to_lower() + n.substr(1))  # "Acero BH" → "acero BH"
			if broken.size() > 0:
				out.append(["Capas", ("todas, y %s de lado a lado" % target.body.noun) if through else " · ".join(broken)])
	if dented:
		out.append(["Abolladura", "~%s mm (la chapa se queda %s J)" % [Physics.fmt_mm(res.dent.depthMm), Format.fmt_j(res.dent.panelJ)]])
	# Energía: solo tiene sentido en un golpe. En la 1.x, lo que no entra rebota o abolla (la abolladura no se modela); en
	# la 2.0 la abolladura sí se calcula (res.dent) y el resto lo amortigua quien golpea.
	var energy: float = res.energyJ if res.get("energyJ") != null else 0.0
	if puncture and energy > 0.0 and res.get("workJ") != null:
		var kept := minf(res.workJ, energy)
		out.append(["Energía absorbida", "%s J de %s J" % [Format.fmt_j(kept), Format.fmt_j(energy)]])
		if not through and kept < 0.5 * energy:
			var rest := "rebota o abolla (la abolladura no se modela)"
			if res.get("residualDepthUm") != null:  # un resultado de la 2.0
				# el animal (una pata o, con un colmillo, la cabeza de la serpiente) o tu dedo
				var who := "el animal" if Physics.truthy(res.get("claw")) else "tu dedo"
				if dented:
					rest = "abolla la chapa y el resto lo amortigua %s" % who
				elif res.get("dent") != null:
					rest = "lo amortigua %s (no llega a abollar)" % who
				else:
					rest = "rebota: no es una chapa metálica"
			out.append(["El resto", rest])
	return out


## El mismo ensayo (herramienta, fuerza, largo…) en dos coches y en cada manera de atacar: una fila por manera,
## { id, name, p, clawOnly?, res: [resultado en cars[0], resultado en cars[1]] }. Un aguijón solo pica: sin rayado,
## desgarro ni golpe (docs/fisica/aguijones.md §7.2), así que tiene una sola fila, «Punza».
static func duel(params: Dictionary, claw: Variant, cars: Array) -> Array:
	var rows: Array = []
	var stinger := Insects.is_stinger(claw)
	for m: Dictionary in DUEL_MODES:
		if Physics.truthy(m.get("clawOnly")) and not Physics.truthy(claw):
			continue
		if stinger and m.id != "puncion":
			continue
		var row := m.duplicate()
		var res: Array = []
		for target: Dictionary in cars:
			var p := params.duplicate()
			p.claw = claw
			p.merge(m.p, true)
			p.target = target
			res.append(Physics.compute(p))
		row.res = res
		rows.append(row)
	return rows


## Quién aguanta mejor: menos etapa de daño; a igual etapa, menos profundidad o, si las dos quedan atravesadas de
## lado a lado, la que se queda más energía del golpe. { winner: 0 | 1 | null, text }.
static func duel_verdict(res_a: Dictionary, res_b: Dictionary, cars: Array) -> Dictionary:
	var a := damage_stage(res_a)
	var b := damage_stage(res_b)
	if a != b:
		var w := 0 if a < b else 1
		return { "winner": w, "text": "aguanta mejor " + _lower_name(cars[w]) }
	if a == 4:
		var wa: float = res_a.workJ if res_a.get("workJ") != null else 0.0
		var wb: float = res_b.workJ if res_b.get("workJ") != null else 0.0
		if absf(wa - wb) > 0.05:
			var w := 0 if wa > wb else 1
			return { "winner": w, "text": "las dos ceden; %s absorbe más energía" % _lower_name(cars[w]) }
		return { "winner": null, "text": "las dos ceden por igual" }
	var da: float = res_a.depthUm
	var db: float = res_b.depthUm
	if a >= 1 and absf(da - db) > 0.05 * maxf(da, db):
		var w := 0 if da < db else 1
		if a == 3:
			return { "winner": w, "text": "las dos se perforan; %s deja pasar menos punta" % _lower_name(cars[w]) }
		return { "winner": w, "text": "%s se marca menos" % _lower_name(cars[w]) }
	return { "winner": null, "text": "ninguno sufre daño" if a == 0 else "empate" }


static func _lower_name(t: Dictionary) -> String:
	return String(t.name).to_lower()
