## Colores de la paleta glam-lab para la interfaz. La paleta es una sola, core/shared/theme.gd (port de theme.js),
## compartida por las dos secciones; aquí solo se convierte a Color.
## El motor devuelve colores de veredicto como texto hexadecimal (vcol): Palette.color(res.vcol).
extends RefCounted

const SharedTheme = preload("res://core/shared/theme.gd")
const HEX := SharedTheme.C


## Color por nombre de la paleta («mint») o por texto hexadecimal («#5BE0C8»).
static func color(name_or_hex: String) -> Color:
	return Color(HEX.get(name_or_hex, name_or_hex))
