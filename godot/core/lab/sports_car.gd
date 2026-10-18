## Tribología biológica · el deportivo del coche en marcha (modelo 2.0, unidad 4r, petición 51: «un modelo de coche
## deportivo que vaya más allá de 230 km/h»).
##
## Un segundo coche para el coche en marcha, con su velocidad máxima como tope del deslizador (el turismo sigue en
## MovingCar.SLIDER_MAX_KMH, 230 km/h). Los datos son los de la ficha técnica del fabricante del Porsche 911 Carrera de
## la generación 992 (2019), el deportivo de serie mejor documentado: velocidad máxima, masa, Cd y medidas exteriores.
## Lo que no publica (el área frontal) es una estimación a partir de sus medidas, marcada. La chapa y la pintura son las
## de Data.CAR_BODIES «aluminio» (AA6016 de 1,0 mm): la piel exterior del 992 es de aluminio salvo los paragolpes
## (Porsche, 2018), y es el caso medido más parecido que tiene el catálogo (no se mide la chapa de un 911). El Cp por
## zona es el del turismo (MovingCar.ZONES: el DrivAer, media de las tres carrocerías): el valor del fastback del mismo
## ensayo (techo −0,47) queda dentro de su banda, así que no se añade otro juego de Cp (estimación, dicho en la ficha).
## Guía y fuentes: docs/fisica/coche-en-marcha.md §19 y docs/FISICA.md, «Cambios de la 2.0».
## Uso: const SportsCar = preload("res://core/lab/sports_car.gd"); SportsCar.ENTRY va en Catalog.V2_TARGETS y
## MovingCarState.CARS.
extends RefCounted

const Data = preload("res://core/lab/data.gd")

const ID := "deportivo"
const SRC_PORSCHE_992 := "Porsche AG (2019). 911 Carrera (992): ficha técnica y nota de prensa «El nuevo Porsche 911» (newsroom.porsche.com): velocidad máxima 293 km/h, peso en vacío DIN 1505 kg, Cd 0,29, largo 4519 mm, ancho 1852 mm, alto 1300 mm"
const SRC_PORSCHE_BODY := "Porsche AG (2018). Nota de prensa «El nuevo Porsche 911»: la piel exterior de la carrocería del 992 es entera de aluminio salvo los paragolpes delantero y trasero"

## Velocidad máxima (km/h): el tope del deslizador con este coche (MovingCar.slider_max_kmh).
const VMAX_KMH := { "value": 293.0, "quality": "primary", "source": SRC_PORSCHE_992 }
## Masa en vacío (kg): solo informativa (el golpe usa car_mass_kg de la tarjeta, como con los demás coches).
const MASS_KG := { "value": 1505.0, "quality": "primary", "source": SRC_PORSCHE_992 }
## Cd de serie (ficha técnica).
const CD := { "value": 0.29, "quality": "primary", "source": SRC_PORSCHE_992 }
## Área frontal (m²): el fabricante no la publica; estimación con sus medidas (1,852 × 1,300 m) y el factor de relleno
## del DrivAer (2,176 m² frente a 1,82 × 1,42 m: 0,84).
const AREA_M2 := { "value": 2.02, "quality": "estimate", "source": "estimación: 1,852 m × 1,300 m (" + SRC_PORSCHE_992 + ") por el factor de relleno del DrivAer de referencia (0,84: 2,176 m² sobre 1,82 × 1,42 m)" }
## Medidas exteriores (m) y lo que cambia frente al turismo del dibujo (car3d/car_shape.gd: 4,5 × 1,8 × 1,45 m): el mismo
## largo, un 3 % más ancho y un 10 % más bajo. Solo dibujo (la física no usa la silueta).
const SIZE_M := { "length": 4.519, "width": 1.852, "height": 1.300, "quality": "primary", "source": SRC_PORSCHE_992 }
const DRAW_SCALE := { "length": 1.0, "width": 1.03, "height": 0.90 }
## Solo dibujo: un cupé de dos puertas (el 911 lo es), pintado de un azul liso (con el amarillo de antes y cuatro puertas
## parecía un taxi).
const DRAW_DOORS := 2
const DRAW_COL := "#1E8FCB"

## La entrada del catálogo (como las de los coches de Data.TARGETS: la física del banco y del coche la leen igual).
const ENTRY := {
	"id": ID, "name": "Deportivo", "hv": 20.0, "E": 3.2, "mohs": null, "col": DRAW_COL, "paint": true, "body": Data.CAR_BODIES["aluminio"],
	"mu": 0.5, "W": 0.04,
	"thickness": (Data.PAINT_LAYERS[-1]["to"] + Data.CAR_BODIES["aluminio"]["t"]) / 1000.0,
	"layers": { "kind": "paint-on-body", "film": Data.PAINT_FILM, "sub": Data.CAR_BODIES["aluminio"] },
	"fact": Data.PAINT_FACT + " Un deportivo de serie (Porsche 911 Carrera 992): 293 km/h de velocidad máxima, 1505 kg y Cd 0,29 (ficha del fabricante). Debajo, la misma chapa de aluminio AA6016 de 1,0 mm del coche de aluminio (su piel exterior es de aluminio): el caso medido más parecido, no una medición del 911. El aire sobre cada zona es el del turismo (estimación: en el túnel, el fastback da en el techo −0,47, dentro de la banda).",
	"vmax_kmh": 293.0, "mass_kg": 1505.0, "aero": { "cd": 0.29, "area_m2": 2.02 }, "draw_scale": DRAW_SCALE, "draw_doors": DRAW_DOORS,
	"sources": { "vmax_kmh": VMAX_KMH, "mass_kg": MASS_KG, "cd": CD, "area_m2": AREA_M2, "size_m": SIZE_M, "body": { "quality": "secondary", "source": SRC_PORSCHE_BODY + "; chapa y espesor: los de Data.CAR_BODIES «aluminio» (AA6016, 1,0 mm), el caso medido más parecido" },
		"cp": { "quality": "estimate", "source": "el Cp por zona del turismo (MovingCar.ZONES, DrivAer: media de las tres carrocerías); el fastback del mismo ensayo da −0,47 en el techo, dentro de la banda" } },
	"quality": "primary", "source": SRC_PORSCHE_992,
}
