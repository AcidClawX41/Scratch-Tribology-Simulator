## Emoji empaquetados: los textos del programa (datos del laboratorio y del taller, interfaz: core/ y app/) solo usan
## emoji que están en el subconjunto de Noto Color Emoji de assets/fonts, y el subconjunto no lleva ninguno de más. La
## fuente va de reserva de las tipografías del tema, y su licencia (OFL 1.1) está con ella y en los créditos.
## Si falla por un emoji nuevo o que ya no se usa: regenera la fuente con godot/tools/emoji.mjs --build.
extends "res://tests/case.gd"

const AppTheme = preload("res://app/theme/app_theme.gd")
const Main = preload("res://app/main.tscn")

const FONT := "res://assets/fonts/noto-color-emoji-subset.ttf"
const HOW := "regenera la fuente: node godot/tools/emoji.mjs --build /ruta/a/NotoColorEmoji.ttf"
## Emoji_Presentation=Yes del plano básico (Unicode 15.1), como en tools/emoji.mjs.
const BMP := [[0x231A, 0x231B], [0x23E9, 0x23EC], [0x23F0, 0x23F0], [0x23F3, 0x23F3], [0x25FD, 0x25FE], [0x2614, 0x2615],
	[0x2648, 0x2653], [0x267F, 0x267F], [0x2693, 0x2693], [0x26A1, 0x26A1], [0x26AA, 0x26AB], [0x26BD, 0x26BE], [0x26C4, 0x26C5],
	[0x26CE, 0x26CE], [0x26D4, 0x26D4], [0x26EA, 0x26EA], [0x26F2, 0x26F3], [0x26F5, 0x26F5], [0x26FA, 0x26FA], [0x26FD, 0x26FD],
	[0x2705, 0x2705], [0x270A, 0x270B], [0x2728, 0x2728], [0x274C, 0x274C], [0x274E, 0x274E], [0x2753, 0x2755], [0x2757, 0x2757],
	[0x2795, 0x2797], [0x27B0, 0x27B0], [0x27BF, 0x27BF], [0x2B1B, 0x2B1C], [0x2B50, 0x2B50], [0x2B55, 0x2B55]]


static func is_emoji(cp: int) -> bool:
	if cp >= 0x1F000 and cp <= 0x1FAFF:
		return true
	for r: Array in BMP:
		if cp >= r[0] and cp <= r[1]:
			return true
	return false


## Emoji de los scripts de core/ y app/: { código: [archivos] } (también lo que va seguido de U+FE0F, y U+FE0F).
static func used_emoji() -> Dictionary:
	var out := {}
	var files := gd_files("res://core")
	files.append_array(gd_files("res://app"))
	for f in files:
		var s := FileAccess.get_file_as_string(f)
		var n := s.length()
		for i in n:
			var cp := s.unicode_at(i)
			if cp < 0x2300:
				continue
			var vs16 := i + 1 < n and s.unicode_at(i + 1) == 0xFE0F
			if is_emoji(cp) or vs16 or cp == 0xFE0F:
				var where: Array = out.get(cp, [])
				if not where.has(f):
					where.append(f)
				out[cp] = where
	return out


func test_todo_emoji_usado_esta_en_la_fuente() -> void:
	var font: FontFile = load(FONT)
	assert_true(font != null, "la fuente de emoji está en assets/fonts")
	var used := used_emoji()
	assert_true(used.size() >= 10, "emoji de los textos: %d" % used.size())
	for cp: int in used:
		assert_true(font.has_char(cp), "U+%X %s (%s) no está en la fuente: %s" % [cp, String.chr(cp), ", ".join(used[cp]), HOW])


func test_la_fuente_solo_lleva_los_emoji_usados() -> void:
	var font: FontFile = load(FONT)
	var used := used_emoji()
	var extra: Array = []
	var chars := font.get_supported_chars()
	for i in chars.length():
		var cp := chars.unicode_at(i)
		if not used.has(cp):
			extra.append("U+%X" % cp)
	assert_eq(extra, [], "emoji de la fuente que ya no usa ningún texto (%s)" % HOW)
	var size := FileAccess.get_file_as_bytes(FONT).size()
	assert_true(size < 200_000, "un subconjunto pequeño (%d bytes; la fuente entera pesa ~10 MB)" % size)
	print("    (info) emoji: %d en %s, %d bytes" % [used.size(), FONT.get_file(), size])


func test_es_la_fuente_de_reserva_de_las_tipografias() -> void:
	# (por variables: GDScript pliega al compilar `AppTheme.MONO.fallbacks`, la propiedad de una constante de otro script)
	var fonts: Array = [AppTheme.MONO, AppTheme.MONO_BOLD, AppTheme.DISP_SEMI, AppTheme.DISP, AppTheme.DISP_BLACK]
	var emoji: Font = AppTheme.EMOJI
	for round_i in 2:  # el tema se construye más de una vez (el programa y cada sección suelta)
		AppTheme.build()
		for f: Font in fonts:
			assert_eq(f.fallbacks.count(emoji), 1, "%s tiene los emoji de reserva, una sola vez" % f.resource_path.get_file())
	var sp := AppTheme.spaced(2)
	assert_true(sp.base_font == fonts[0], "las variaciones con espaciado usan la tipografía base (con su reserva)")


func test_licencia_y_creditos() -> void:
	var ofl := FileAccess.get_file_as_string("res://assets/fonts/OFL-NotoColorEmoji.txt")
	assert_true(ofl.contains("SIL OPEN FONT LICENSE Version 1.1") and ofl.contains("Google"), "licencia OFL junto a la fuente")
	var m: Control = Main.instantiate()
	m.remember = false
	m.setup()
	m.show_credits()
	var texts := PackedStringArray()
	for l in m.credits_overlay.content.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_true("\n".join(texts).contains("Noto Color Emoji"), "créditos de la aplicación: la fuente de emoji")
	m.free()
