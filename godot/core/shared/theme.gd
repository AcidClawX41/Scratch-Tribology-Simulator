## Paleta glam-lab (port de packages/core/src/theme.js), la única del programa: la usan las dos secciones.
## El motor del laboratorio devuelve colores de veredicto como texto hexadecimal (vcol); la interfaz los convierte
## en Color con app/theme/palette.gd. Contraste revisado (WCAG AA ≥ 4,5:1 para texto pequeño sobre bg, panel y
## panel2).
## Uso: const SharedTheme = preload("res://core/shared/theme.gd"), y después SharedTheme.C.mint («Theme» ya es una
## clase de Godot).
extends RefCounted

const C := {
	"bg": "#170E1C", "bg2": "#1D1224", "panel": "#221530", "panel2": "#2C1D3D", "panel3": "#36254A",
	"line": "#3F2D52", "line2": "#56406D",
	"text": "#F4E9F0", "dim": "#BCA9C7", "dimmer": "#9C89AD",
	"rose": "#F2A6C0", "gold": "#E6B450", "mint": "#5BE0C8", "coral": "#FF6B7A", "ice": "#BFE9FF",
}
