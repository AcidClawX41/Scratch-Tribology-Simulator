## Tribología biológica · reforja: soldar piezas de metal de una funda de garra (unidad 5r; petición 44: lo que sí se suelda es
## metal con metal, en el laboratorio, antes de colocar la pieza). Funciones puras y datos con fuente, sin estado ni nodos.
##
## Los tres métodos reales para unir piezas pequeñas de metal (las de una funda o una prótesis, como las de joyería y las de
## los laboratorios dentales):
##   - «laser»: la soldadura láser pulsada (Nd:YAG de 1064 nm): la energía de cada pulso, su duración y el diámetro del punto dan
##     la potencia de pico y su densidad, que decide el modo (conducción, transición u ojo de cerradura: Amada), y el balance de
##     energía (lo que se absorbe y lo que funde: la entalpía de fusión del metal) da la hondura y la anchura de cada punto;
##   - «tig»: el micro-TIG o arco pulsado (Lampert PUK): la corriente, el tiempo y el argón; la energía del arco (I·V·t) con el
##     rendimiento del arco medido por calorimetría (DuPont y Marder 1995) y el mismo balance, siempre en modo de conducción;
##   - «braze»: la soldadura fuerte de plata (ForgeData.BRAZE, SAE AMS 4763): la temperatura (sólido-líquido 618-652 °C), el
##     fundente (activo hasta ~870 °C) y la holgura (capilaridad: 0,025-0,125 mm).
## Lo que se puede y lo que no (can_join): el titanio solo con titanio y con argón (sin gas coge oxígeno y sale frágil, y el
## color de la zona soldada lo delata: plateado o pajizo bien, azul o gris mal); el oro con oro; el acero con acero; metales
## distintos, intermetálicos frágiles; el metal duro no se funde: solo con soldadura fuerte; las gemas, las cerámicas y el
## vidrio no se sueldan (se engastan o se pegan); la queratina, nunca (no conduce y se quema a ~230 °C).
## Lo que sale (seam y joint): la hondura de la unión frente al espesor de la pared (falta de fusión o pared perforada), los
## poros, las grietas, el color y la resistencia de la unión frente a la del metal base, nunca mayor que esta.
## Guía y tabla valor → fuente → tipo: docs/fisica/reforja.md §18.
## Unidades: mm · J · ms · A · °C · MPa · kg/m³ · J/(kg·K) · W/(m·K).
## Uso: const ClawWeld = preload("res://core/lab/claw_weld.gd")
##      var spot := ClawWeld.laser_spot("acero", 20.0, 5.0, 0.6, "argon")
##      var seam := ClawWeld.seam(spot, 1.0, 12.0, 0.7)
##      var j := ClawWeld.joint("laser", "acero", "acero", spot, seam, "argon")
extends RefCounted

const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

# ════════ Fuentes ════════
const SRC_AMADA := "Amada Miyachi America (2016). Laser Welding Fundamentals (libro blanco), §2.2, §5, §6 y §8: modo de conducción a ~0,5 MW/cm², de transición a ~1 MW/cm² y de ojo de cerradura por encima de 1,5 MW/cm² (soldaduras estrechas y hondas, relación hondura/anchura > 1,5); la energía del pulso E = P·t; el pico de potencia manda en la hondura y la duración del pulso en la anchura; el solape entre puntos de una costura, del 80-90 % para que sea estanca y del 60-70 % para una unión solo de resistencia, con la hondura efectiva que crece con el solape; la holgura de una unión a tope, como mucho el 10 % del espesor; el titanio da buenas soldaduras y el wolframio soldaduras frágiles; el acero inoxidable con el titanio, intermetálicos frágiles (ensayar siempre); el titanio pide gas de protección (argón) y el acero inoxidable no lo necesita para la resistencia"
const SRC_BABA := "Baba N, Watanabe I (2005). Penetration depth into dental casting alloys by Nd:YAG laser. J. Biomed. Mater. Res. B 72(1):64-68, doi:10.1002/jbm.b.30117: con pulsos de 10 ms, de 160 a 340 V y puntos de 0,4 a 1,6 mm, la hondura va de 0,29 a 6,45 mm en el titanio puro, de 0,24 a 6,15 en el Co-Cr y de 0,12 a 5,22 en la aleación de oro de tipo IV; a más tensión (más energía) y menos diámetro, más hondura"
const SRC_WATANABE := "Watanabe I, Topham DS (2006). Laser welding of cast titanium and dental alloys using argon shielding. J. Prosthodont. 15:102-107: con pulsos de 10 ms, punto de 1 mm y 200 V, la carga de rotura del titanio puro soldado con argón es mayor que sin él, y el argón es necesario para el titanio pero no para el oro ni el Co-Cr; la aleación de oro soldada aguanta aproximadamente la mitad que sin soldar, con o sin argón"
const SRC_LI := "Li X, Xie J, Zhou Y (2005). Effects of oxygen contamination in the argon shielding gas in laser welding of commercially pure titanium thin sheet. J. Mater. Sci. 40:3437-3443, doi:10.1007/s10853-005-0447-8: al subir el oxígeno del gas, el color de la soldadura pasa de plateado a pajizo y a azul, la dureza sube y la ductilidad baja; la resistencia sube primero y luego cae (la microestructura pasa de alfa serrada a acicular)"
const SRC_W150G := "Han's Laser, soldadora láser de joyería W150G, ficha técnica: Nd:YAG de 1064 nm, 150 W de media, hasta 80 J por pulso, pulsos de 0,1 a 20 ms, 9 kW de pico, 0-20 Hz, baño de fusión de 0,2 mm, penetración de 0,1 a 3 mm; microscopio coaxial y protección completa de los ojos"
const SRC_PUK := "Lampert, PUK 6 (soldadora de joyería por micro-TIG), ficha técnica: corriente de 9 a 630 A, pulsos de 0,1 a 34 ms, hasta 3,3 puntos por segundo, argón de pureza ≥ 99,9 % a ~2 l/min, electrodo de hasta 1 mm; suelda oro, plata, platino, paladio, bronce, acero inoxidable, titanio, latón y cobre; el microscopio lleva el filtro de oscurecimiento automático"
const SRC_DUPONT := "DuPont JN, Marder AR (1995). Thermal efficiency of arc welding processes. Welding Journal 74(12):406s-416s: el rendimiento del arco medido con calorímetro, 0,67 ± 0,05 en el TIG (GTAW; 0,84 en el MIG y 0,47 en el plasma), con el arco a 15-16 V; el rendimiento de fusión (lo que de verdad funde de lo que llega a la pieza) crece con la potencia y la velocidad hasta saturar en ~0,48 (el máximo teórico de Wells para el flujo de calor en dos dimensiones)"
const SRC_CRC_FUSION := "Haynes WM (ed.), CRC Handbook of Chemistry and Physics, 95.ª ed. (2014), entalpía de fusión de los elementos: oro 12,55 kJ/mol (63,7 kJ/kg), hierro 13,81 kJ/mol (247 kJ/kg), titanio 14,15 kJ/mol (296 kJ/kg)"
const SRC_ABSORB := "absorción de la luz de 1064 nm por un metal frío y pulido: el oro refleja casi todo (como el cobre, que «pide mucha energía» en el Nd:YAG, Amada 2016 §5.1) y se toma 0,05; el acero inoxidable, 0,35, y el titanio, 0,40, los valores habituales de las tablas de absorción a 1 µm. Estimación: sin ficha a mano; una vez fundido, el metal absorbe mucho más (el efecto de bola de nieve de Amada 2016 §2.1)"
const SRC_COUPLING := "lo que de la energía del pulso acaba fundiendo metal: en conducción, la absorción del metal por un rendimiento de fusión de 0,3 (dentro de la banda medida de 0,1 a 0,48 de DuPont y Marder 1995); en ojo de cerradura, 0,037 para todos los metales (el vapor del ojo atrapa la luz, pero expulsa y evapora la mayor parte: calibrado para que 80 J en 2 ms sobre un punto de 0,5 mm den en el acero los ~3 mm de penetración máxima de la ficha de la W150G, y el titanio y el oro queden dentro de lo medido por Baba y Watanabe 2005). Estimación"
const SRC_HAZ := "la zona afectada por el calor: lo que avanza el calor durante el pulso, la longitud de difusión √(α·t) con la difusividad del metal (k/(ρ·c)) y el tiempo del pulso (Incropera et al. 2007): en un pulso de ms, décimas de mm en el acero y el titanio, y más en el oro, que conduce 20 veces más. Regla del modelo (estimación)"
const SRC_PERFORATION := "la pared se perfora cuando el ojo de cerradura la atraviesa y sigue: la hondura pasa del espesor más la anchura del punto (el baño ya no tiene dónde apoyarse). Regla del modelo (estimación)"
const SRC_POROSITY := "en ojo de cerradura, el ojo se cierra sobre sí mismo y deja poros, más cuanto más denso es el pico (Amada 2016 §6.4 y §8.1: la forma del pulso y el gas reducen los poros); se toma el riesgo por encima de 3 MW/cm² (estimación)"
const SRC_GAS_FACTORS := "lo que aguanta la unión frente al metal base: el oro soldado, la mitad (Watanabe y Topham 2006, medido); el titanio con argón y el acero inoxidable, 0,9 (estimación: Watanabe y Topham no dan la cifra del titanio con argón y Amada 2016 dice «excelentes» de las del 304); el titanio sin argón, 0,4 (estimación: contaminado por el oxígeno pierde ductilidad, Li et al. 2005), y con el argón escaso, 0,7 (pajizo: aún aceptable, estimación); un metal distinto soldado a otro, 0,3 (estimación: «los intermetálicos frágiles son más débiles que cualquiera de los dos metales», Amada 2016 §5.1.1)"
const SRC_TIG_SPOT := "el punto del micro-TIG: el arco de un electrodo de hasta 1 mm (Lampert) funde un baño de ~1 mm de ancho en conducción; se toma 1 mm de diámetro de la fuente de calor (estimación) y el arco a 15 V (DuPont y Marder 1995, el TIG a 15-16 V)"
const SRC_BRAZE_GAP := "la holgura de una unión con soldadura fuerte de plata: el fundido sube por capilaridad con holguras de 0,025 a 0,125 mm (0,001-0,005 in), y la unión más fuerte sale hacia 0,04 mm (la regla de las guías de soldadura fuerte, AWS Brazing Handbook y Lucas-Milhaupt: sin la ficha a mano, estimación); el fundente de los aceros y los metales duros (AWS FB3-A) trabaja de ~565 a ~870 °C y por encima se agota y deja que se oxide la unión (estimación)"
const SRC_BRAZE_TAU := "lo que aguanta al cortante una unión de plata bien hecha: ~170 MPa (las guías de soldadura fuerte dan 140-240 MPa para las aleaciones de plata en acero; estimación, sin ficha a mano); nunca más que el metal base más blando"
const SRC_BRAZE_WC := "las plaquitas de metal duro se sueldan a los mangos de acero con soldadura fuerte de plata (" + ForgeData.SRC_BRAZING + "); el carburo de tungsteno no se funde (" + ForgeData.SRC_GC_GUIDE + ") y el wolframio soldado por fusión sale frágil (Amada 2016, tabla 1)"
const SRC_NO_WELD := "las gemas, las cerámicas y el vidrio no se sueldan: no conducen (no salta el arco) y no se funden con el metal (el zafiro a 2053 °C y el vidrio se comba a 726 °C: se engastan o se pegan en frío); la queratina, nunca: no conduce, se quema a ~230 °C (" + CareData.SRC_KAKKAR + ") y no se funde con nada"
const SRC_PACE := "lo que tarda cada punto: el micro-TIG da hasta 3,3 puntos por segundo (Lampert); el láser de joyería va a mano, a 2-5 puntos por segundo (elección del juego: el pedal manda y la pieza se mueve a mano); el soplete de la soldadura fuerte calienta cada tramo de la costura en ~10 s (estimación)"

## Los métodos, con su máquina de ficha y sus mandos (min, max, paso, valor de serie).
const METHOD_IDS := ["laser", "tig", "braze"]
const METHODS := {
	"laser": {
		"id": "laser", "name": "Soldadura láser (Nd:YAG pulsado)", "short": "Láser", "machine": "soldadora láser de joyería o de laboratorio dental (W150G: 1064 nm, hasta 80 J y 20 ms por pulso, 9 kW de pico)",
		"controls": { "energy_j": { "min": 1.0, "max": 80.0, "step": 1.0, "value": 12.0 }, "pulse_ms": { "min": 0.1, "max": 20.0, "step": 0.1, "value": 4.0 }, "spot_mm": { "min": 0.2, "max": 2.0, "step": 0.1, "value": 0.6 } },
		"gas": true, "pulses_per_s": 4.0, "quality": "secondary", "source": SRC_W150G + "; " + SRC_AMADA,
		"safety": "El láser de 1064 nm no se ve y enfoca en la retina: se mira siempre por el microscopio con su filtro, nunca al punto. La máquina lleva la protección de los ojos.",
	},
	"tig": {
		"id": "tig", "name": "Micro-TIG (arco pulsado con argón)", "short": "Micro-TIG", "machine": "soldadora de arco pulsado de joyería (Lampert PUK 6: de 9 a 630 A, pulsos de 0,1 a 34 ms, argón a 2 l/min)",
		"controls": { "current_a": { "min": 9.0, "max": 630.0, "step": 1.0, "value": 150.0 }, "pulse_ms": { "min": 0.1, "max": 34.0, "step": 0.1, "value": 8.0 } },
		"gas": true, "pulses_per_s": 3.3, "quality": "secondary", "source": SRC_PUK + "; " + SRC_DUPONT,
		"safety": "El arco deslumbra y quema la córnea y la piel (luz ultravioleta): el microscopio lleva un filtro que se oscurece solo con cada pulso; sin él, pantalla de soldar.",
	},
	"braze": {
		"id": "braze", "name": "Soldadura fuerte de plata (soplete)", "short": "Soldadura fuerte", "machine": "soplete de joyero con la aleación de plata (56Ag-22Cu-17Zn-5Sn, sólido-líquido 618-652 °C) y su fundente",
		"controls": { "temp_c": { "min": 400.0, "max": 1100.0, "step": 10.0, "value": 700.0 }, "gap_mm": { "min": 0.0, "max": 0.3, "step": 0.005, "value": 0.04 } },
		"gas": false, "pulses_per_s": 0.1, "quality": "secondary", "source": ForgeData.SRC_BRAZING + "; " + SRC_BRAZE_GAP,
		"safety": "Gafas de soplete (la llama y el metal al rojo deslumbran) y el fundente, que lleva fluoruros, con ventilación.",
	},
}
## El gas de protección: con argón bueno, con el argón escaso (poco caudal: entra algo de aire) o sin gas (al aire).
const GAS_IDS := ["argon", "argon_escaso", "aire"]
const GAS_NAMES := { "argon": "Argón (2 l/min)", "argon_escaso": "Argón escaso", "aire": "Sin gas (al aire)" }
## El solape entre puntos de la costura (Amada 2016 §6.3): solo resistencia (60-70 %) o estanca (80-90 %).
const OVERLAPS := [
	{ "id": "resistencia", "name": "Solo resistencia (65 %)", "value": 0.65 },
	{ "id": "estanca", "name": "Estanca (85 %)", "value": 0.85 },
]
## Lo que hace falta de cada metal para fundirlo (la entalpía de fusión, J/kg) y lo que absorbe de la luz de 1064 nm en frío.
const FUSION_J_KG := {
	"oro": { "value": 63700.0, "quality": "secondary", "source": SRC_CRC_FUSION },
	"acero": { "value": 247000.0, "quality": "estimate", "source": "la del hierro (" + SRC_CRC_FUSION + "): estimación para el 304" },
	"titanio": { "value": 296000.0, "quality": "secondary", "source": SRC_CRC_FUSION },
}
const ABSORPTIVITY := {
	"oro": { "value": 0.05, "quality": "estimate", "source": SRC_ABSORB },
	"acero": { "value": 0.35, "quality": "estimate", "source": SRC_ABSORB },
	"titanio": { "value": 0.40, "quality": "estimate", "source": SRC_ABSORB },
}
## Los umbrales de la densidad de potencia (MW/cm²): conducción, transición y ojo de cerradura; y desde dónde hay poros.
const DENSITY := { "conduction": 0.5, "transition": 1.0, "keyhole": 1.5, "porosity": 3.0, "quality": "secondary", "source": SRC_AMADA + "; los poros, " + SRC_POROSITY }
## Lo que funde de la energía del pulso: en conducción, la absorción por el rendimiento de fusión; en ojo de cerradura, el
## acoplamiento calibrado (estimación, SRC_COUPLING).
const MELT_EFF_CONDUCTION := { "value": 0.3, "quality": "estimate", "source": SRC_COUPLING }
const KEYHOLE_COUPLING := { "value": 0.037, "quality": "estimate", "source": SRC_COUPLING }
## La anchura del punto en ojo de cerradura frente al punto óptico (Amada: la soldadura es algo más ancha que el punto).
const KEYHOLE_WIDTH_FACTOR := { "value": 1.2, "quality": "estimate", "source": SRC_AMADA + " (§6, el ancho de la soldadura es mayor que el punto óptico: se toma 1,2 veces, estimación)" }
## El arco del micro-TIG: su tensión, su rendimiento (DuPont y Marder) y el diámetro de su fuente de calor.
const ARC := { "volts": 15.0, "efficiency": 0.67, "spot_mm": 1.0, "quality": "secondary", "source": SRC_DUPONT + "; " + SRC_TIG_SPOT }
## Lo que aguanta la unión frente al metal base (0-1), por lo que la debilita (SRC_GAS_FACTORS).
const JOINT_FACTOR := {
	"oro": { "value": 0.5, "quality": "secondary", "source": SRC_WATANABE },
	"acero": { "value": 0.9, "quality": "estimate", "source": SRC_GAS_FACTORS },
	"titanio": { "value": 0.9, "quality": "estimate", "source": SRC_GAS_FACTORS },
	"titanio_argon_escaso": { "value": 0.7, "quality": "estimate", "source": SRC_GAS_FACTORS },
	"titanio_aire": { "value": 0.4, "quality": "estimate", "source": SRC_GAS_FACTORS },
	"distintos": { "value": 0.3, "quality": "estimate", "source": SRC_GAS_FACTORS },
}
## El color de la zona soldada del titanio según el oxígeno del gas (Li et al. 2005) y el del acero al aire (la capa de óxido
## azul del inoxidable: la tabla de colores de revenido del taller); el oro no se oxida.
const TI_COLORS := {
	"argon": { "hex": "#D9DDE2", "name": "plateado", "ok": true },
	"argon_escaso": { "hex": "#E3C978", "name": "pajizo", "ok": true },
	"aire": { "hex": "#4D6AA6", "name": "azul (y gris en el centro)", "ok": false },
}
const STEEL_AIR_COLOR := { "hex": "#3F5FA8", "name": "azul (óxido)", "quality": "secondary", "source": "la capa de óxido del inoxidable calentado al aire (BSSA, los colores de revenido del taller)" }
const COLOR_SOURCE := SRC_LI
## La soldadura fuerte: el fundente (hasta dónde trabaja), la holgura y lo que aguanta.
const BRAZE := {
	"flux_min_c": 565.0, "flux_max_c": 870.0, "gap_min_mm": 0.025, "gap_best_mm": 0.04, "gap_max_mm": 0.125, "tau_mpa": 170.0,
	"quality": "estimate", "source": SRC_BRAZE_GAP + "; " + SRC_BRAZE_TAU,
}
## El pulso de más sobre un tramo ya soldado: refunde (más calor, más zona afectada); a partir del tercero, en la soldadura
## fuerte el fundente se agota (elección del juego).
const REMELT_MAX := 2
## La altura del cordón sobre la superficie (la sobremonta que hay que limar): una fracción de la anchura del punto (dibujo y
## elección del juego: lo que queda por limar con la muela fina).
const BEAD_FRAC := { "value": 0.2, "quality": "estimate", "source": "la sobremonta del cordón, un quinto de su anchura: elección del juego (se lima con la muela fina)" }


# ════════════════════════════════ Lo que se puede unir y lo que no ════════════════════════════════

## La familia de un material para la soldadura: «metal» (oro, acero, titanio), «metal_duro», «gema» (cristales, vidrios y
## cerámicas), «queratina» («none») o «polimero».
static func family_of(mid: String) -> String:
	if mid == "none" or mid == "":
		return "queratina"
	var m := ForgeData.material(mid)
	var fam := String(m.get("family", ""))
	match fam:
		"metal":
			return "metal"
		"metal_duro":
			return "metal_duro"
		"polimero":
			return "polimero"
	return "gema"


## ¿Se pueden unir a y b con ese método y ese gas? { ok, code, text, source, quality }. Nunca la queratina; las gemas, las
## cerámicas y el vidrio, nunca; el metal duro, solo con soldadura fuerte; por fusión, solo el mismo metal; el titanio por
## fusión, con argón (sin gas sale, pero contaminado: lo dice el resultado, no esta función).
static func can_join(a: String, b: String, method: String) -> Dictionary:
	var out := { "ok": false, "code": "", "text": "", "source": SRC_NO_WELD, "quality": "secondary" }
	if not METHODS.has(method):
		out["code"] = "metodo"
		out["text"] = "Ese método no existe."
		return out
	var fa := family_of(a)
	var fb := family_of(b)
	for pair: Array in [[a, fa], [b, fb]]:
		var nm := _name(String(pair[0]))
		match String(pair[1]):
			"queratina":
				out["code"] = "queratina"
				out["text"] = "La queratina no se suelda nunca: no conduce (el arco no salta), se quema a ~%s °C y no se funde con ningún metal. La pieza se pega en frío en la cetrería." % Js.to_fixed(float(CareData.THERMAL.char_c.value), 0)
				return out
			"gema":
				out["code"] = "gema"
				out["text"] = "%s no se suelda: no conduce y no se funde con el metal. Las gemas, las cerámicas y el vidrio se engastan o se pegan." % nm.substr(0, 1).to_upper() + nm.substr(1)
				return out
			"polimero":
				out["code"] = "polimero"
				out["text"] = "El acrílico se ablanda a 125 °C y se quema con el arco o el láser: se pega, no se suelda."
				return out
	if fa == "metal_duro" or fb == "metal_duro":
		if method == "braze":
			out["ok"] = true
			out["source"] = SRC_BRAZE_WC
			out["text"] = "El metal duro se suelda con plata, como las plaquitas a los mangos de acero."
			return out
		out["code"] = "metal_duro"
		out["source"] = SRC_BRAZE_WC
		out["text"] = "El carburo de tungsteno no se funde (el cobalto sí, y el carburo queda suelto): por fusión sale frágil. El metal duro se une con soldadura fuerte de plata, como las plaquitas de las herramientas."
		return out
	if method == "braze":
		out["ok"] = true
		out["source"] = ForgeData.SRC_BRAZING
		out["text"] = "La plata moja los dos metales: se pueden unir aunque sean distintos."
		return out
	if a != b:
		out["code"] = "distintos"
		out["source"] = SRC_AMADA
		out["text"] = "%s con %s por fusión: se mezclan en el baño y forman intermetálicos frágiles (la unión aguanta menos que cualquiera de los dos). Metales distintos, con soldadura fuerte." % [_name(a).substr(0, 1).to_upper() + _name(a).substr(1), _name(b)]
		return out
	out["ok"] = true
	out["source"] = SRC_AMADA + "; " + SRC_WATANABE
	out["text"] = "%s con %s: el mismo metal, se funde en un solo baño." % [_name(a).substr(0, 1).to_upper() + _name(a).substr(1), _name(b)]
	if a == "titanio":
		out["text"] = String(out.text) + " El titanio fundido coge oxígeno: siempre con argón."
	return out


static func _name(mid: String) -> String:
	if mid == "none" or mid == "":
		return "la queratina"
	var e: Variant = ForgeData.inlay_entry(mid)
	return String(e.name).to_lower() if e != null else mid


# ════════════════════════════════ Un punto de soldadura ════════════════════════════════

## Lo que cuesta fundir un mm³ del metal (J/mm³): ρ·(c·(T_fusión − 20) + L). 0 si no hay datos (no se funde).
static func melt_enthalpy_j_mm3(mid: String) -> float:
	var m := ForgeData.material(mid)
	var rho: Variant = ForgeData.density_of(mid)
	if m.is_empty() or m.get("melt_c") == null or m.get("cp") == null or rho == null or not FUSION_J_KG.has(mid):
		return 0.0
	var dt := float(m.melt_c.value) - 20.0
	return float(rho) * 1.0e-9 * (float(m.cp.value) * dt + float(FUSION_J_KG[mid].value))


## La difusividad del metal (m²/s): k/(ρ·c). 0 sin datos.
static func diffusivity_m2_s(mid: String) -> float:
	var m := ForgeData.material(mid)
	var rho: Variant = ForgeData.density_of(mid)
	if m.is_empty() or m.get("k") == null or m.get("cp") == null or rho == null:
		return 0.0
	return float(m.k.value) / (float(rho) * float(m.cp.value))


## El modo de un pulso láser por su densidad de pico (MW/cm²): «conduccion», «transicion» u «ojo» (de cerradura), y cuánto
## de ojo de cerradura tiene (0-1, suave entre los umbrales).
static func mode_of(density_mw_cm2: float) -> Dictionary:
	var k := Contact.smoothstep(float(DENSITY.transition), float(DENSITY.keyhole), density_mw_cm2)
	var mode := "conduccion"
	if density_mw_cm2 >= float(DENSITY.keyhole):
		mode = "ojo"
	elif density_mw_cm2 >= float(DENSITY.transition):
		mode = "transicion"
	return { "mode": mode, "keyhole": k }


## Un punto de soldadura láser sobre el metal mid: energy_j por pulso, pulse_ms y el diámetro del punto spot_mm. { ok, method,
## material, energyJ, pulseMs, spotMm, peakKw, densityMWcm2, mode, keyhole (0-1), absorbed (la fracción que funde), meltedMm3,
## depthMm, widthMm, hazMm, porosity, color { hex, name, ok }, contaminated, gas, text, source }. Más energía por pulso
## nunca da menos hondura (con lo demás igual).
static func laser_spot(mid: String, energy_j: float, pulse_ms: float, spot_mm: float, gas := "argon") -> Dictionary:
	var out := _spot_base("laser", mid, gas)
	var e := maxf(energy_j, 0.0)
	var t := maxf(pulse_ms, 0.01)
	var d := maxf(spot_mm, 0.05)
	out.merge({ "energyJ": e, "pulseMs": t, "spotMm": d }, true)
	var hm := melt_enthalpy_j_mm3(mid)
	if hm <= 0.0 or not ABSORPTIVITY.has(mid):
		out["defect"] = "no_funde"
		out["text"] = "%s no se funde con el láser." % (_name(mid).substr(0, 1).to_upper() + _name(mid).substr(1))
		return out
	var peak_w := e / (t * 1.0e-3)
	var area_cm2 := PI * (d * 0.05) * (d * 0.05)
	var dens := peak_w / area_cm2 * 1.0e-6
	var md := mode_of(dens)
	var kh := float(md.keyhole)
	var c_cond := float(ABSORPTIVITY[mid].value) * float(MELT_EFF_CONDUCTION.value)
	var c_key := float(KEYHOLE_COUPLING.value)
	# conducción: un baño semiesférico con lo que absorbe el metal frío; ojo de cerradura: un paraboloide del ancho del punto con
	# el acoplamiento calibrado (el ojo atrapa la luz, pero evapora y expulsa casi todo). Manda el más hondo de los dos, con el ojo
	# pesado por cuánto de ojo tiene el pulso: así más energía nunca da menos hondura
	var v_cond := c_cond * e / hm
	var v_key := c_key * e / hm
	var r_cond := V8.js_cbrt(3.0 * v_cond / (2.0 * PI))
	var w_key := d * float(KEYHOLE_WIDTH_FACTOR.value)
	var h_key := 8.0 * v_key / (PI * w_key * w_key) * kh
	var keyed := h_key > r_cond
	var depth := maxf(r_cond, h_key)
	var width := 2.0 * r_cond + (w_key - 2.0 * r_cond) * kh if keyed else 2.0 * r_cond
	var coupling := c_key if keyed else c_cond
	var v_melt := v_key if keyed else v_cond
	out.merge({
		"ok": true, "peakKw": peak_w / 1000.0, "densityMWcm2": dens, "mode": String(md.mode), "keyhole": kh, "absorbed": coupling,
		"meltedMm3": v_melt, "depthMm": depth, "widthMm": width, "hazMm": haz_mm(mid, t),
		"porosity": dens > float(DENSITY.porosity), "aspect": depth / maxf(width, 1e-9),
	}, true)
	_finish_spot(out)
	return out


## Un punto de micro-TIG sobre el metal mid: la corriente (A), el tiempo (ms) y el gas. La energía, I·V·t con el arco a 15 V; lo
## que llega a la pieza, el rendimiento del arco (0,67); lo que funde, el de fusión de conducción. Siempre en conducción: un baño
## semiesférico. El mismo diccionario que laser_spot (con currentA en vez de energyJ y spotMm = el de la fuente del arco).
static func tig_spot(mid: String, current_a: float, pulse_ms: float, gas := "argon") -> Dictionary:
	var out := _spot_base("tig", mid, gas)
	var i := maxf(current_a, 0.0)
	var t := maxf(pulse_ms, 0.01)
	var e := i * float(ARC.volts) * t * 1.0e-3
	out.merge({ "currentA": i, "pulseMs": t, "energyJ": e, "spotMm": float(ARC.spot_mm) }, true)
	var hm := melt_enthalpy_j_mm3(mid)
	if hm <= 0.0:
		out["defect"] = "no_funde"
		out["text"] = "%s no se funde con el arco." % (_name(mid).substr(0, 1).to_upper() + _name(mid).substr(1))
		return out
	var coupling := float(ARC.efficiency) * float(MELT_EFF_CONDUCTION.value)
	var v_melt := coupling * e / hm
	var r := V8.js_cbrt(3.0 * v_melt / (2.0 * PI))
	var peak_w := i * float(ARC.volts)
	var area_cm2 := PI * (float(ARC.spot_mm) * 0.05) * (float(ARC.spot_mm) * 0.05)
	out.merge({
		"ok": true, "peakKw": peak_w / 1000.0, "densityMWcm2": peak_w / area_cm2 * 1.0e-6, "mode": "conduccion", "keyhole": 0.0,
		"absorbed": coupling, "meltedMm3": v_melt, "depthMm": r, "widthMm": 2.0 * r, "hazMm": haz_mm(mid, t), "porosity": false,
		"aspect": 0.5,
	}, true)
	_finish_spot(out)
	return out


static func _spot_base(method: String, mid: String, gas: String) -> Dictionary:
	return {
		"ok": false, "method": method, "material": mid, "gas": gas if GAS_IDS.has(gas) else "argon", "energyJ": 0.0, "pulseMs": 0.0,
		"spotMm": 0.0, "peakKw": 0.0, "densityMWcm2": 0.0, "mode": "", "keyhole": 0.0, "absorbed": 0.0, "meltedMm3": 0.0,
		"depthMm": 0.0, "widthMm": 0.0, "hazMm": 0.0, "porosity": false, "aspect": 0.0, "color": {}, "contaminated": false,
		"defect": "", "text": "", "source": String(METHODS[method].source) + "; " + SRC_COUPLING + "; " + SRC_HAZ,
	}


## La zona afectada por el calor (mm): √(α·t) con el tiempo del pulso.
static func haz_mm(mid: String, pulse_ms: float) -> float:
	var a := diffusivity_m2_s(mid)
	return sqrt(a * pulse_ms * 1.0e-3) * 1000.0 if a > 0.0 else 0.0


## El color de la zona soldada y la contaminación por el gas, y el texto del punto.
static func _finish_spot(out: Dictionary) -> void:
	var mid := String(out.material)
	var gas := String(out.gas)
	out["color"] = weld_color(mid, gas)
	out["contaminated"] = mid == "titanio" and gas == "aire"
	var words := { "conduccion": "en conducción (un baño ancho y poco hondo)", "transicion": "en transición (empieza el ojo de cerradura)", "ojo": "en ojo de cerradura (estrecho y hondo)" }
	out["text"] = "Punto de %s mm de hondura y %s mm de ancho, %s, con %s mm de zona afectada por el calor; el color de la zona soldada: %s." % [
		Js.to_fixed(float(out.depthMm), 2), Js.to_fixed(float(out.widthMm), 2), String(words.get(String(out.mode), "")), Js.to_fixed(float(out.hazMm), 2), String(out.color.name)]
	if bool(out.contaminated):
		out["text"] = String(out.text) + " El titanio fundido al aire coge oxígeno: duro y frágil."
	if bool(out.porosity):
		out["text"] = String(out.text) + " Con ese pico el ojo de cerradura se cierra mal y deja poros."


## El color de la zona soldada: el titanio, por el oxígeno del gas (Li et al. 2005); el acero al aire, el azul del óxido; el oro,
## su color. { hex, name, ok, source }.
static func weld_color(mid: String, gas: String) -> Dictionary:
	if mid == "titanio":
		var c: Dictionary = TI_COLORS.get(gas, TI_COLORS.argon)
		return { "hex": c.hex, "name": c.name, "ok": c.ok, "source": COLOR_SOURCE }
	if mid == "acero" and gas == "aire":
		return { "hex": STEEL_AIR_COLOR.hex, "name": STEEL_AIR_COLOR.name, "ok": true, "source": String(STEEL_AIR_COLOR.source) }
	var e: Variant = ForgeData.inlay_entry(mid)
	return { "hex": String(e.get("col", "#C7CDD6")) if e != null else "#C7CDD6", "name": "el del metal, brillante", "ok": true, "source": SRC_WATANABE + " (el oro y el acero no necesitan el argón)" }


# ════════════════════════════════ La costura y la unión ════════════════════════════════

## La costura: una fila de puntos solapados a lo largo de length_mm sobre una pared de wall_mm. { pulsesNeed, pitchMm, overlap,
## effDepthMm (la hondura efectiva con el solape), fusion (lo que la unión atraviesa de la pared, 0-1), through (la atraviesa),
## perforated (el ojo se pasa y agujerea la pared), beadMm (la sobremonta que hay que limar), text, source }.
static func seam(spot: Dictionary, wall_mm: float, length_mm: float, overlap: float) -> Dictionary:
	var ov := clampf(overlap, 0.0, 0.95)
	var w := maxf(float(spot.get("widthMm", 0.0)), 1e-6)
	var pitch := w * (1.0 - ov)
	var n := int(ceil(length_mm / maxf(pitch, 1e-6))) if bool(spot.get("ok", false)) else 0
	# la hondura efectiva crece con el solape (Amada, figura 36): a solape 0, la mitad; a solape 1, toda
	var eff := float(spot.get("depthMm", 0.0)) * (0.5 + 0.5 * ov)
	var fusion := clampf(eff / maxf(wall_mm, 1e-6), 0.0, 1.0)
	var perforated := float(spot.get("keyhole", 0.0)) > 0.5 and float(spot.get("depthMm", 0.0)) > wall_mm + w
	var out := {
		"pulsesNeed": maxi(n, 1) if n > 0 else 0, "pitchMm": pitch, "overlap": ov, "effDepthMm": eff, "fusion": fusion, "through": fusion >= 1.0 - 1e-9,
		"perforated": perforated, "beadMm": w * float(BEAD_FRAC.value), "wallMm": wall_mm, "lengthMm": length_mm, "text": "",
		"source": SRC_AMADA + "; " + SRC_PERFORATION,
	}
	if n > 0:
		out["text"] = "%d puntos de %s mm de ancho a lo largo de %s mm de costura (solape del %s %%): la unión llega a %s mm de los %s mm de pared." % [
			int(out.pulsesNeed), Js.to_fixed(w, 2), Js.to_fixed(length_mm, 1), Js.to_fixed(ov * 100.0, 0), Js.to_fixed(eff, 2), Js.to_fixed(wall_mm, 2)]
	return out


## La soldadura fuerte de plata de a con b: la temperatura del soplete y la holgura. { ok, defect, text, flows, factor (lo que
## aguanta frente a una unión perfecta, 0-1), tauMPa, source }.
static func braze(a: String, b: String, temp_c: float, gap_mm: float) -> Dictionary:
	var bz: Dictionary = ForgeData.BRAZE
	var out := { "ok": false, "defect": "", "text": "", "flows": false, "factor": 0.0, "tauMPa": float(BRAZE.tau_mpa), "tempC": temp_c, "gapMm": gap_mm,
		"source": String(bz.source) + "; " + String(BRAZE.source) }
	var cj := can_join(a, b, "braze")
	if not bool(cj.ok):
		out["defect"] = String(cj.code)
		out["text"] = String(cj.text)
		return out
	var low := minf(_melt_or_inf(a), _melt_or_inf(b))
	if temp_c < float(bz.t_min):
		out["defect"] = "fria"
		out["text"] = "A %s °C la aleación de plata no funde (sólido a %s °C): no moja nada." % [Js.to_fixed(temp_c, 0), Js.to_fixed(float(bz.t_min), 0)]
	elif temp_c < float(bz.t_max):
		out["defect"] = "pastosa"
		out["text"] = "Entre %s y %s °C la aleación está pastosa (sólido-líquido): no corre por la holgura y la unión queda a medias." % [Js.to_fixed(float(bz.t_min), 0), Js.to_fixed(float(bz.t_max), 0)]
	elif temp_c >= low:
		out["defect"] = "funde_base"
		out["text"] = "A %s °C se funde el propio metal base (%s °C): la pieza pierde la forma." % [Js.to_fixed(temp_c, 0), Js.to_fixed(low, 0)]
	elif temp_c > float(BRAZE.flux_max_c):
		out["defect"] = "fundente_agotado"
		out["text"] = "Por encima de ~%s °C el fundente se agota: la unión se oxida, la plata no moja y quedan huecos." % Js.to_fixed(float(BRAZE.flux_max_c), 0)
	elif gap_mm < float(BRAZE.gap_min_mm):
		out["defect"] = "sin_holgura"
		out["text"] = "Con %s mm de holgura la plata no entra por capilaridad (hace falta al menos %s mm): la unión queda vacía." % [Js.to_fixed(gap_mm, 3), Js.to_fixed(float(BRAZE.gap_min_mm), 3)]
	elif gap_mm > float(BRAZE.gap_max_mm) * 2.0:
		out["defect"] = "holgura"
		out["text"] = "Con %s mm de holgura la plata no se sostiene en la junta (como mucho ~%s mm): se cae y deja huecos." % [Js.to_fixed(gap_mm, 3), Js.to_fixed(float(BRAZE.gap_max_mm), 3)]
	else:
		out["ok"] = true
		out["flows"] = true
		var f := 1.0
		if gap_mm > float(BRAZE.gap_max_mm):
			f = 0.5 * (1.0 - (gap_mm - float(BRAZE.gap_max_mm)) / float(BRAZE.gap_max_mm))
		elif gap_mm > float(BRAZE.gap_best_mm) * 2.0:
			f = 1.0 - 0.5 * (gap_mm - float(BRAZE.gap_best_mm) * 2.0) / (float(BRAZE.gap_max_mm) - float(BRAZE.gap_best_mm) * 2.0)
		out["factor"] = clampf(f, 0.0, 1.0)
		out["text"] = "A %s °C la plata funde y sube por la holgura de %s mm: moja los dos metales%s." % [Js.to_fixed(temp_c, 0), Js.to_fixed(gap_mm, 3), "" if f >= 0.999 else " (la holgura es grande: la unión aguanta un %s %% de lo que podría)" % Js.to_fixed(f * 100.0, 0)]
	return out


static func _melt_or_inf(mid: String) -> float:
	var m := ForgeData.material(mid)
	return float(m.melt_c.value) if not m.is_empty() and m.get("melt_c") != null else INF


## La resistencia del metal base (MPa) para comparar la unión: la de fluencia (Tabor) de los metales o la de flexión del metal duro.
static func base_strength_mpa(mid: String) -> float:
	var st: Variant = ForgeData.strength_of(mid)
	return float(st.value) if st != null else 0.0


## La unión entera: method («laser», «tig» o «braze»), los dos metales, el punto (de laser_spot o tig_spot; {} en la soldadura
## fuerte), la costura (seam; {} en la fuerte), el gas y, en la fuerte, su resultado (braze). Lo que aguanta la unión
## (jointMPa) nunca pasa de la resistencia del metal base más blando (baseMPa). { ok, defect, text, jointMPa, baseMPa, efficiency,
## factors [{ what, value, source }], color, contaminated, porosity, cracks, limitedBy, source }.
static func joint(method: String, a: String, b: String, spot: Dictionary, sm: Dictionary, gas := "argon", bz: Dictionary = {}) -> Dictionary:
	var base := minf(base_strength_mpa(a), base_strength_mpa(b)) if base_strength_mpa(a) > 0.0 and base_strength_mpa(b) > 0.0 else maxf(base_strength_mpa(a), base_strength_mpa(b))
	var out := { "ok": false, "method": method, "a": a, "b": b, "defect": "", "text": "", "jointMPa": 0.0, "baseMPa": base, "efficiency": 0.0,
		"factors": [], "color": {}, "contaminated": false, "porosity": false, "cracks": false, "limitedBy": "", "source": "" }
	var cj := can_join(a, b, method)
	if not bool(cj.ok):
		out["defect"] = String(cj.code)
		out["text"] = String(cj.text)
		out["source"] = String(cj.source)
		# el titanio con otro metal: intermetálicos, se agrieta; es lo que sale si se insiste
		out["cracks"] = String(cj.code) == "distintos"
		return out
	var factors: Array = out.factors
	if method == "braze":
		var fac := float(bz.get("factor", 0.0))
		out["source"] = String(bz.get("source", ""))
		if not bool(bz.get("ok", false)):
			out["defect"] = String(bz.get("defect", "fria"))
			out["text"] = String(bz.get("text", ""))
			return out
		factors.append({ "what": "la holgura de la plata", "value": fac, "source": SRC_BRAZE_GAP })
		var tau := float(bz.get("tauMPa", BRAZE.tau_mpa)) * fac
		out["jointMPa"] = minf(tau, base)
		out["limitedBy"] = "la plata" if tau < base else "el metal base"
		out["efficiency"] = float(out.jointMPa) / maxf(base, 1e-9)
		out["ok"] = true
		out["color"] = { "hex": "#D8D8D0", "name": "la línea de plata entre los dos metales", "ok": true, "source": ForgeData.SRC_BRAZING }
		out["text"] = "Unión de plata: aguanta ~%s MPa al cortante (manda %s; el metal base, %s MPa)." % [Js.to_fixed(float(out.jointMPa), 0), String(out.limitedBy), Js.to_fixed(base, 0)]
		return out
	out["source"] = String(spot.get("source", "")) + "; " + SRC_GAS_FACTORS
	out["color"] = spot.get("color", {})
	out["contaminated"] = bool(spot.get("contaminated", false))
	out["porosity"] = bool(spot.get("porosity", false))
	if not bool(spot.get("ok", false)):
		out["defect"] = String(spot.get("defect", "no_funde"))
		out["text"] = String(spot.get("text", ""))
		return out
	if bool(sm.get("perforated", false)):
		out["defect"] = "perforada"
		out["text"] = "Demasiado hondo: el ojo de cerradura (%s mm) atraviesa la pared de %s mm y la perfora. Menos energía, un pulso más largo o un punto más ancho." % [Js.to_fixed(float(spot.depthMm), 2), Js.to_fixed(float(sm.wallMm), 2)]
		return out
	var fusion := float(sm.get("fusion", 0.0))
	var key := a
	if a == "titanio" and gas != "argon":
		key = "titanio_" + gas
	var jf: Dictionary = JOINT_FACTOR.get(key, JOINT_FACTOR.get(a, { "value": 0.5, "source": SRC_GAS_FACTORS }))
	factors.append({ "what": "el metal soldado (%s%s)" % [_name(a), ", " + String(GAS_NAMES.get(gas, gas)).to_lower() if a == "titanio" else ""], "value": float(jf.value), "source": String(jf.source) })
	factors.append({ "what": "lo que la unión atraviesa de la pared", "value": fusion, "source": SRC_AMADA })
	var eff := float(jf.value) * fusion
	if bool(out.porosity):
		factors.append({ "what": "los poros del ojo de cerradura", "value": 0.8, "source": SRC_POROSITY })
		eff *= 0.8
	out["efficiency"] = clampf(eff, 0.0, 1.0)
	out["jointMPa"] = base * float(out.efficiency)
	out["limitedBy"] = "la fusión incompleta" if fusion < 0.999 else ("el oxígeno" if bool(out.contaminated) else "el metal soldado")
	if bool(out.contaminated):
		out["defect"] = "contaminada"
		out["text"] = "Titanio soldado al aire: la zona soldada sale %s, dura y frágil (coge oxígeno). Aguanta ~%s MPa de los %s MPa del titanio. Con argón." % [String(out.color.name), Js.to_fixed(float(out.jointMPa), 0), Js.to_fixed(base, 0)]
		return out
	if fusion < 0.999:
		out["defect"] = "falta_fusion"
		out["text"] = "Falta de fusión: la unión llega a %s mm de los %s mm de pared (el %s %%); aguanta ~%s MPa de los %s MPa del metal. Más energía, o un punto más estrecho." % [
			Js.to_fixed(float(sm.effDepthMm), 2), Js.to_fixed(float(sm.wallMm), 2), Js.to_fixed(fusion * 100.0, 0), Js.to_fixed(float(out.jointMPa), 0), Js.to_fixed(base, 0)]
		out["ok"] = fusion >= 0.5
		return out
	out["ok"] = true
	out["text"] = "Unión soldada: atraviesa la pared y aguanta ~%s MPa (el %s %% del metal base, %s MPa); el color de la zona soldada: %s." % [
		Js.to_fixed(float(out.jointMPa), 0), Js.to_fixed(float(out.efficiency) * 100.0, 0), Js.to_fixed(base, 0), String(out.color.name)]
	if bool(out.porosity):
		out["text"] = String(out.text) + " Con poros del ojo de cerradura."
	return out


## Lo que tarda cada pulso o cada tramo (s de verdad), por método.
static func pulse_period_s(method: String) -> float:
	var m: Dictionary = METHODS.get(method, {})
	return 1.0 / float(m.get("pulses_per_s", 1.0)) if not m.is_empty() else 1.0
