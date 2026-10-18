## Taller · programas de ejemplo para el control Fagor 8055 T.
##
## Las piezas A y B de CONTRATOS.md, programadas y comentadas como en un ejercicio de FP de Diseño en Fabricación
## Mecánica, y un programa con tres errores didácticos para que el alumno los busque. Fase 2: las mismas piezas con el
## acabado compensado con G42 (pieza_a_g42 y pieza_b_g42, esta con (RPT)) y la pieza C, un tornillo M20×2,5 con una
## subrutina de acabado y el ciclo de roscado G86 (docs/taller/fagor-fase2.md).
## - Cero pieza en la cara acabada (Z0), la pieza en Z negativas y X en diámetro (G151).
## - En el acabado se programa el centro de cada tolerancia ISO 286 (tabla IT de CONTRATOS.md).
## - Las condiciones de corte (Vc, f, pasada) son valores didácticos de ejemplo, no datos de catálogo: el modelo de
##   corte del taller decide si son razonables (docs/taller/fuentes-u4.md).
## Uso: interpret_program(EXAMPLE_PROGRAMS[id]["text"], options(id)) con gcode.gd: options() da las tablas de
## herramientas y correctores de la torreta del programa (radio de la punta y código de forma de cada plaquita), sin
## las que G41/G42 no desplazan nada (el control toma R0).
extends RefCounted

const Gcode = preload("res://core/taller/gcode.gd")

const EXAMPLE_PROGRAMS := {
	"pieza_a": {
		"title": "Pieza A · Eje escalonado",
		"description": "Refrentado con G82, desbaste de los tres diámetros con G81 y acabado del perfil con G01.",
		"material": "C45E",
		"stock": { "diameter": 50.0, "length": 85.0, "in_chuck": 25.0 },
		"tools": ["T1", "T3"],
		# torreta con la que se ha probado en el torno simulado (ids de core/taller/lathe_tools.gd)
		"turret": { "1": "PCLNR2525M12/CNMG120408-PM", "3": "PVJNR2525M16HP/VNMG160404-PF" },
		"text": """; ==============================================================
; PIEZA A · EJE ESCALONADO · control Fagor 8055 T
; Material C45E · bruto Ø50 x 85 · 25 mm dentro del plato
; Cero pieza en la cara acabada (Z0): la pieza queda en Z negativas.
; X en diámetro (G151). En el acabado se programa el centro de
; cada tolerancia (ISO 286):
;   Ø30 h9 (0/-0,052)  -> X29.974
;   Ø40 h9 (0/-0,062)  -> X39.969
;   Ø46 ±0,1           -> X46
; T1: desbaste exterior · T3: acabado exterior
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G92 S2500                 ; tope de giro para la velocidad de corte constante
N30 T1 D1                     ; herramienta de desbaste
N40 G96 S180 M3 M8            ; Vc 180 m/min, giro a derechas y refrigerante
N50 G00 X52 Z2 F0.25          ; punto de llamada; F0.25 mm/rev para desbastar
; --- Refrentado de la cara hasta Z0, en pasadas de 1 mm ---
N60 G82 X52 Z0 Q0 R0 C1 D1
; --- Desbaste de los tres diámetros: creces de 0,3 en X y 0,1 en Z ---
N70 G81 X46 Z0 Q46 R-55 C2 D1 L0.3 M0.1       ; Ø46 hasta Z-55
N80 G00 X47                                    ; nuevo punto de llamada
N90 G81 X40 Z0 Q40 R-40 C2 D1 L0.3 M0.1       ; Ø40 hasta Z-40
N100 G00 X41
N110 G81 X30 Z0 Q30 R-20 C2 D1 L0.3 M0.1      ; Ø30 hasta Z-20
N120 G00 X100 Z100            ; punto de cambio de herramienta
; --- Acabado del perfil ---
N130 T3 D3                    ; herramienta de acabado
N140 G96 S220                 ; Vc 220 m/min
N150 G00 X27.974 Z2           ; frente al inicio del chaflán
N160 G01 Z0 F0.1              ; hasta la cara, a 0,1 mm/rev
N170 X29.974 Z-1              ; chaflán 1x45°
N180 Z-20                     ; Ø30 h9
N190 X39.969                  ; hombro
N200 Z-40                     ; Ø40 h9 (Ra 1,6)
N210 X46                      ; hombro
N220 Z-55                     ; Ø46 ±0,1
N230 X52                      ; salida por encima del bruto
N240 G00 X100 Z100 M9         ; retirada y refrigerante cerrado
N250 M30                      ; fin de programa
""",
	},
	"pieza_b": {
		"title": "Pieza B · Bulón",
		"description": "Refrentado con G01 y perfil completo con G68: desbaste, pasada final de desbaste y acabado.",
		"material": "EN AW-6082 T6",
		"stock": { "diameter": 40.0, "length": 70.0, "in_chuck": 20.0 },
		"tools": ["T2"],
		# DNMG 15 04 08-PM: admite pasadas de hasta 6 mm para el desbaste de G68 (C2) y con rε 0,8 y H0.1 deja Ra ≈ 0,4 µm
		"turret": { "2": "PDJNR2525M15/DNMG150408-PM" },
		"text": """; ==============================================================
; PIEZA B · BULÓN · control Fagor 8055 T
; Material EN AW-6082 T6 · bruto Ø40 x 70 · 20 mm dentro del plato
; Cero pieza en la cara acabada (Z0). X en diámetro (G151).
; Centro de cada tolerancia (ISO 286):
;   Ø24 h8 (0/-0,033)  -> X23.9835
;   Ø36 js9 (±0,031)   -> X36
; Una sola herramienta para aluminio (T2): el ciclo G68 desbasta,
; da la pasada final de desbaste (F) y la de acabado (H).
; Sin D, cada pasada se retira siguiendo el perfil: el acabado
; encuentra unas creces más uniformes.
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G92 S3000                 ; tope de giro para G96
N30 T2 D2                     ; herramienta de desbaste y acabado para aluminio
N40 G96 S300 M3 M8            ; Vc 300 m/min, giro a derechas y refrigerante
N50 G00 X44 Z0                ; a la altura de la cara
N60 G01 X-0.8 F0.15           ; refrentado pasando el eje hasta X-2·rε (rε 0,4): sin pezón en el centro
N70 G00 Z2                    ; separarse de la cara
N80 X44 F0.25                 ; punto de llamada; F0.25 mm/rev para desbastar
; --- Desbaste, pasada final y acabado del perfil N200-N260 ---
; X Z: inicio del perfil · C: paso · L M: creces en X y en Z
; F: avance de la pasada final · H: avance de acabado · S E: etiquetas
N90 G68 X22.9835 Z0 C2 L0.3 M0.1 F0.2 H0.1 S200 E260
N100 G00 X100 Z100 M9         ; retirada y refrigerante cerrado
N110 M30                      ; fin de programa
; ---------- Perfil de acabado (etiquetas S200 y E260) ----------
N200 G01 X23.9835 Z-0.5       ; chaflán 0,5x45°
N210 Z-13                     ; Ø24 h8 (Ra 1,6)
N220 G02 X27.9835 Z-15 R2     ; radio cóncavo R2 en el hombro
N230 G01 X36                  ; cara del hombro
N240 Z-35                     ; Ø36 js9
N250 X38 Z-45                 ; cono de Ø36 a Ø38
N260 X42                      ; salida por encima del bruto
""",
	},
	"pieza_a_g42": {
		"title": "Pieza A · con G42",
		"description": "La pieza A con el acabado compensado (G42): chaflán, hombros y diámetros a cota con la punta redonda.",
		"material": "C45E",
		"stock": { "diameter": 50.0, "length": 85.0, "in_chuck": 25.0 },
		"tools": ["T1", "T3"],
		"turret": { "1": "PCLNR2525M12/CNMG120408-PM", "3": "PVJNR2525M16HP/VNMG160404-PF" },
		"text": """; ==============================================================
; PIEZA A CON G42 · EJE ESCALONADO · control Fagor 8055 T
; Material C45E · bruto Ø50 x 85 · 25 mm dentro del plato
; Igual que la pieza A, pero el acabado lleva la compensación
; del radio de la punta (G42, manual p. 133-140): el CNC toma
; el radio R0,4 y el código de forma F3 del corrector D3 y
; desplaza la trayectoria para que la punta redonda deje el
; chaflán y los hombros a cota. Sin G42, el chaflán 1x45° sale
; de 0,77 mm. La cara se refrenta pasando el eje hasta X-2·rε
; (Q-1.6 con rε 0,8): la punta redonda no deja pezón.
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G92 S2500                 ; tope de giro para la velocidad de corte constante
N30 T1 D1                     ; herramienta de desbaste
N40 G96 S180 M3 M8            ; Vc 180 m/min, giro a derechas y refrigerante
N50 G00 X52 Z2 F0.25          ; punto de llamada; F0.25 mm/rev para desbastar
; --- Refrentado de la cara hasta Z0, en pasadas de 1 mm ---
N60 G82 X52 Z0 Q-1.6 R0 C1 D1  ; pasando el eje hasta X-2·rε: sin pezón
; --- Desbaste de los tres diámetros: creces de 0,3 en X y 0,1 en Z ---
N70 G81 X46 Z0 Q46 R-55 C2 D1 L0.3 M0.1       ; Ø46 hasta Z-55
N80 G00 X47                                    ; nuevo punto de llamada
N90 G81 X40 Z0 Q40 R-40 C2 D1 L0.3 M0.1       ; Ø40 hasta Z-40
N100 G00 X41
N110 G81 X30 Z0 Q30 R-20 C2 D1 L0.3 M0.1      ; Ø30 hasta Z-20
N120 G00 X100 Z100            ; punto de cambio de herramienta
; --- Acabado del perfil con G42 ---
N130 T3 D3                    ; herramienta de acabado; D3: R0,4 F3
N140 G96 S220                 ; Vc 220 m/min
N150 G00 X20 Z2               ; frente a la cara, por debajo del chaflán
N160 G42 G01 Z0 F0.1          ; activa G42 en la entrada hasta la cara
N170 X27.974                  ; por la cara hasta el chaflán
N180 X29.974 Z-1              ; chaflán 1x45°
N190 Z-20                     ; Ø30 h9
N200 X39.969                  ; hombro
N210 Z-40                     ; Ø40 h9 (Ra 1,6)
N220 X46                      ; hombro
N230 Z-55                     ; Ø46 ±0,1
N240 X52                      ; salida por encima del bruto
N250 G40 G00 X100 Z100 M9     ; anula G42 al retirarse y cierra el refrigerante
N260 M30                      ; fin de programa
""",
	},
	"pieza_b_g42": {
		"title": "Pieza B · con G42 y RPT",
		"description": "G68 desbasta sin H y el acabado repite el perfil con (RPT) y G42: chaflán, R2 y cono a cota.",
		"material": "EN AW-6082 T6",
		"stock": { "diameter": 40.0, "length": 70.0, "in_chuck": 20.0 },
		"tools": ["T2"],
		"turret": { "2": "PDJNR2525M15/DNMG150408-PM" },
		"text": """; ==============================================================
; PIEZA B CON G42 · BULÓN · control Fagor 8055 T
; Material EN AW-6082 T6 · bruto Ø40 x 70 · 20 mm dentro del plato
; El ciclo G68 desbasta y da la pasada final de desbaste (F),
; pero sin H. El acabado va aparte, con G42 (R0,8 y F3 del
; corrector D2), repitiendo los bloques del perfil con
; (RPT N200, N260) (manual, p. 289): RPT no anula la
; compensación. Así el chaflán, el R2 y el cono salen a cota.
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G92 S3000                 ; tope de giro para G96
N30 T2 D2                     ; herramienta de desbaste y acabado para aluminio
N40 G96 S300 M3 M8            ; Vc 300 m/min, giro a derechas y refrigerante
N50 G00 X44 Z0                ; a la altura de la cara
N60 G01 X-1.6 F0.15           ; refrentado pasando el eje hasta X-2·rε (rε 0,8): sin pezón
N70 G00 Z2                    ; separarse de la cara
N80 X44 F0.25                 ; punto de llamada; F0.25 mm/rev para desbastar
; --- Desbaste y pasada final de desbaste del perfil N200-N260 ---
N90 G68 X22.9835 Z0 C2 L0.3 M0.1 F0.2 S200 E260
; --- Acabado: el mismo perfil, repetido con G42 ---
N100 G00 X18 Z2               ; frente a la cara, por debajo del chaflán
N110 G42 G01 Z0 F0.1          ; activa G42 en la entrada hasta la cara
N120 X22.9835                 ; por la cara hasta el inicio del chaflán
N130 (RPT N200, N260)         ; perfil de acabado, compensado
N140 G40 G00 X100 Z100 M9     ; anula G42 al retirarse y cierra el refrigerante
N150 M30                      ; fin de programa
; ---------- Perfil (etiquetas S200 y E260) ----------
N200 G01 X23.9835 Z-0.5       ; chaflán 0,5x45°
N210 Z-13                     ; Ø24 h8 (Ra 1,6)
N220 G02 X27.9835 Z-15 R2     ; radio cóncavo R2 en el hombro
N230 G01 X36                  ; cara del hombro
N240 Z-35                     ; Ø36 js9
N250 X38 Z-45                 ; cono de Ø36 a Ø38
N260 X42                      ; salida por encima del bruto
""",
	},
	"pieza_c": {
		"title": "Pieza C · Tornillo M20×2,5",
		"description": "Desbaste con G81, acabado con G42 en una subrutina (CALL) y rosca M20×2,5 con el ciclo G86.",
		"material": "C45E",
		"stock": { "diameter": 30.0, "length": 75.0, "in_chuck": 25.0 },
		"tools": ["T1", "T3", "T5"],
		"turret": { "1": "PCLNR2525M12/CNMG120408-PM", "3": "PVJNR2525M16HP/VNMG160404-PF",
			"5": "266RFG-2525-16/266RG-16MM01A250M" },
		"text": """; ==============================================================
; PIEZA C · TORNILLO M20x2,5 · control Fagor 8055 T
; Material C45E · bruto Ø30 x 75 · 25 mm dentro del plato
; Cero pieza en la cara acabada (Z0). X en diámetro (G151).
; Rosca métrica ISO M20x2,5-6g (ISO 68-1 e ISO 965-1):
;   Ø exterior 19,623-19,958  -> se tornea a X19.79
;   Ø medio 18,164-18,334 · paso 2,5
;   H = 0,866·P = 2,165 · h3 = 0,6134·P = 1,534 (del Ø20)
;   desde X19.79, I1.49 deja el Ø medio en el centro de 6g
; T1: desbaste · T3: acabado con G42 · T5: roscar 60° (F62)
; El acabado es la subrutina 10 (CALL, manual p. 291-292) y la
; rosca, el ciclo G86 (p. 187): 14 pasadas de B·raíz(n) con
; penetración por el flanco (A30) y salida de rosca J de 1 paso.
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G92 S2500                 ; tope de giro para G96
N30 T1 D1                     ; herramienta de desbaste
N40 G96 S180 M3 M8            ; Vc 180 m/min, giro a derechas y refrigerante
N50 G00 X32 Z2 F0.25          ; punto de llamada; F0.25 mm/rev para desbastar
; --- Refrentado de la cara hasta Z0, pasando el eje hasta X-2·rε ---
N60 G82 X32 Z0 Q-1.6 R0 C1 D1
; --- Desbaste: creces de 0,3 en X y 0,1 en Z ---
N70 G81 X26 Z0 Q26 R-45 C2 D1 L0.3 M0.1       ; Ø26 hasta Z-45
N80 G00 X27                                    ; nuevo punto de llamada
N90 G81 X20 Z0 Q20 R-32 C2 D1 L0.3 M0.1       ; Ø20 hasta Z-32
N100 G00 X100 Z100            ; punto de cambio de herramienta
; --- Acabado del perfil: subrutina 10, con G42 ---
N110 T3 D3                    ; herramienta de acabado; D3: R0,4 F3
N120 G96 S220                 ; Vc 220 m/min
N130 (CALL 10)
N140 G00 X100 Z100
; --- Rosca M20x2,5 con G86 ---
N150 T5 D5                    ; herramienta de roscar; D5: R0,361 F62
N160 G97 S1000                ; rpm fijas: 2,5 x 1000 = 2500 mm/min
N170 G00 X24 Z10              ; cerca del punto de aproximación
; X Z: inicio (2 pasos por delante de la cara) · Q R: final · I: profundidad
; B E: pasadas B·raíz(n), incremento mínimo E · D: distancia de seguridad
; L: acabado · C: paso · J: salida de rosca · A: penetración por el flanco
N180 G86 X19.79 Z5 Q19.79 R-24 I1.49 B0.4 E0.05 D1 L0.05 C2.5 J2.5 A30
N190 G00 X100 Z100 M9         ; retirada y refrigerante cerrado
N200 M30                      ; fin de programa
; ---------- Subrutina 10: perfil de acabado con G42 ----------
N300 (SUB 10)
N310 G00 X14 Z2               ; frente a la cara, por debajo del chaflán
N320 G42 G01 Z0 F0.1          ; activa G42 en la entrada hasta la cara
N330 X16.79                   ; por la cara hasta el chaflán
N340 X19.79 Z-1.5             ; chaflán de entrada de la rosca (por debajo del Ø de fondo)
N350 Z-32                     ; Ø exterior de la rosca
N360 X26                      ; hombro
N370 Z-45                     ; Ø26
N380 X32                      ; salida por encima del bruto
N390 G40 G00 X40 Z2           ; anula G42 al retirarse
N400 (RET)
""",
	},
	"errores": {
		"title": "Pieza A con 3 errores",
		"description": "El acabado de la pieza A con tres errores típicos. ¿Los encuentras antes de ejecutarlo?",
		"material": "C45E",
		"stock": { "diameter": 50.0, "length": 85.0, "in_chuck": 25.0 },
		"tools": ["T3"],
		"turret": { "3": "PVJNR2525M16HP/VNMG160404-PF" },
		# lo que el alumno debe descubrir (el simulador da el error con la línea y el bloque)
		"errors": [
			{ "n": 20, "code": "unsupported",
				"why": "G50 no es el tope de giro del 8055 (allí es arista matada controlada): es G92 S2500. " +
					"Costumbre de Fanuc, donde G50 S limita las rpm." },
			{ "n": 90, "code": "arc_impossible",
				"why": "Los extremos del arco distan 1,41 mm y un radio de 0,5 mm no llega: " +
					"el redondeo de 1 mm se programa con R1." },
			{ "n": 120, "code": "g04_alone",
				"why": "La espera del 8055 es G04 K en centésimas de segundo (G04 K150 = 1,5 s); " +
					"con X, la X sería una cota." },
		],
		"text": """; ==============================================================
; PIEZA A · ACABADO · control Fagor 8055 T
; Hay tres errores en este programa. ¿Dónde?
; ==============================================================
N10 G90 G71 G95 G151          ; absolutas, mm, avance por vuelta, X en diámetro
N20 G50 S2500                 ; tope de giro
N30 T3 D3                     ; herramienta de acabado
N40 G96 S220 M3 M8            ; Vc 220 m/min
N50 G00 X27.974 Z2
N60 G01 Z0 F0.1
N70 X29.974 Z-1               ; chaflán 1x45°
N80 Z-19
N90 G02 X31.974 Z-20 R0.5     ; redondeo al pie del hombro
N100 G01 X39.969
N110 Z-40
N120 G04 X1.5                 ; espera de 1,5 s para limpiar el hombro
N130 X46
N140 Z-55
N150 X52
N160 G00 X100 Z100 M9
N170 M30
""",
	},
}


## Opciones del intérprete para un programa de ejemplo: las tablas de herramientas y de correctores de su torreta
## (gcode.gd, turret_options). {} si el programa no existe.
static func options(id: String) -> Dictionary:
	if not EXAMPLE_PROGRAMS.has(id):
		return {}
	return Gcode.turret_options(EXAMPLE_PROGRAMS[id]["turret"])
