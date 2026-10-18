## Tribología biológica · cetrería: el animal que comparten sus garras (unidad 5g; lo pidió la 5c). Sin nodos, determinista
## y sin variables estáticas.
##
## Cada garra es una ClawCare (claw_care.gd), con su forma, su carne viva, su calor y su sangre; el animal es uno: su
## sujeción o anestesia, su dolor, sus movimientos, su estrés y si se le tocaron las garras sin sedarlo (el peligro que
## pone la nota a 0). Las ClawCare de un mismo animal comparten este objeto, que guarda ClawCareState:
##   - trabajar otra garra no borra el estrés del animal ni lo que se ha movido;
##   - el reloj de la sujeción cuenta una sola vez: cada segundo sujeto suma su estrés (CareData.SEDATION[…].stress_rate,
##     un índice pedagógico) aunque cada garra lleve su propio reloj, porque el animal guarda hasta qué paso del reloj ha
##     contado (k) y solo suma los pasos nuevos.
## Una ClawCare sola crea el suyo: con un solo dueño da lo mismo, al bit, que antes de la 5g.
## Unidades: pasos del reloj de ClawCare (DT) · índices de 0 a 1.
## Uso: var patient := ClawCarePatient.new("tigre", "anestesia"); ClawCare.new(setup, patient)…
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const Rng = preload("res://core/shared/rng.gd")

## El animal (CareData.ANIMAL_IDS) y su sujeción (CareData.SEDATION).
var animal_id := "rapaz"
var sedation := "sujecion"
## Estrés (0-1, índice pedagógico): el del tiempo sujeto y el de cada dolor.
var stress := 0.0
## Dolor de la última acción y el más fuerte (0-1, índices pedagógicos).
var pain := 0.0
var max_pain := 0.0
## Solo pasa el tiempo (ClawCare.advance): nadie le toca las garras. Sin sujetar, entonces el tiempo no le estresa...
var idle := false
## ...salvo si se le está cogiendo la garra con una herramienta (un gesto en marcha de ClawCareState: la pasada, el torno
## apoyado, la presión o el cortaúñas cerrándose): entonces sí la manejan.
var gripped := false
## Veces que se ha movido de dolor, con cualquiera de sus garras.
var moved := 0
## Se le tocaron las garras a un tigre, un oso o un velocirraptor sin sedación ni anestesia (anestesiarlo después no lo borra).
var unsafe := false
## Ya se le han tocado las garras (unidad 5o, el medidor del animal): sin sujetar («libre»), el estrés del tiempo empieza a
## contar desde entonces; antes, el animal está tranquilo en su percha o en su jaula, sin que nadie lo maneje.
var handled := false
## Último paso del reloj (en pasos de ClawCare.DT) cuyo estrés ya está contado.
var k := 0
## Cambia con cada cambio del animal (la escena repinta solo si cambia).
var serial := 0
## La garra del banco del animal (aguila, buho, tigre…): decide cómo reacciona (ClawCareReaction.kind_of).
var claw_id := ""
## La reacción del animal estresado (unidad 5t-A, petición 61; el contrato con la escena de la 5t-B): reaction_seq sube 1
## en cada zarpazo; reaction_warning se enciende un poco antes (la postura de amenaza: REACTION.warn_s); reaction_intensity
## (0-1, índice de juego) y reaction_lens, lo que el zarpazo le hace a la lente puesta (ClawCareReaction.lens_hit: lo pone
## ClawCareState, que sabe qué garras tocan; {} hasta entonces). Es una probabilidad que crece con el estrés que dejan los
## errores (ClawCareReaction.chance, una tirada cada REACTION.roll_s, con el azar de semilla del animal y su garra: el mismo
## ensayo da siempre lo mismo); solo si la sujeción no basta para su especie (mobility() > 0) y como mucho una vez cada
## REACTION.gap_s.
var reaction_seq := 0
var reaction_warning := false
var reaction_intensity := 0.0
var reaction_lens: Dictionary = {}
## El paso del reloj en que empezó la amenaza (−1 sin amenaza) y el del último zarpazo.
var _arm_k := -1
var _last_react_k := -1
## La pausa para calmarlo (ClawCareReaction.CALM): se le deja tranquilo, no se revuelve y el estrés baja; cualquier acción
## sobre sus garras la acaba.
var resting := false
## El paso del reloj de la última tirada (−1 sin ninguna) y el azar de las tiradas (con semilla: determinista).
var _last_roll_k := -1
var _rng: Rng = null
## Un zarpazo nuevo cuya lente aún no se ha calculado (lo recoge ClawCareState).
var lens_pending := false
## El paso del reloj (s): el de ClawCare.DT, que llega en count_step.
var _dt := 1.0 / 60.0


func _init(animal: String = "rapaz", sedation_id: String = "", claw: String = "") -> void:
	reset(animal, sedation_id, claw)


## Empieza de nuevo: el animal (uno de CareData.ANIMALS; si no, la rapaz) con esa sujeción (si no existe, la suya) y su
## garra del banco (sin ella, la de su ficha).
func reset(animal: String, sedation_id: String = "", claw: String = "") -> void:
	animal_id = animal if CareData.ANIMALS.has(animal) else "rapaz"
	sedation = sedation_id if CareData.SEDATION.has(sedation_id) else String(CareData.ANIMALS[animal_id].restraint)
	claw_id = claw if claw != "" and (CareData.ANIMALS[animal_id].claws as Array).has(claw) else String(CareData.ANIMALS[animal_id].claw)
	stress = 0.0
	pain = 0.0
	max_pain = 0.0
	moved = 0
	unsafe = false
	handled = false
	k = 0
	reaction_seq = 0
	reaction_warning = false
	reaction_intensity = 0.0
	reaction_lens = {}
	lens_pending = false
	_arm_k = -1
	_last_react_k = -1
	_last_roll_k = -1
	resting = false
	_rng = Rng.new(Rng.seed_of("reaccion:%s:%s" % [animal_id, claw_id]))
	serial += 1


## La garra del banco del animal (la rapaz cambia de especie sin cambiar de paciente).
func set_claw(id: String) -> void:
	if id != claw_id and (CareData.ANIMALS[animal_id].claws as Array).has(id):
		claw_id = id
		serial += 1


## Cambia la sujeción o la anestesia (la de todas sus garras). false si no existe.
func set_sedation(id: String) -> bool:
	if not CareData.SEDATION.has(id):
		return false
	var order := ["libre", "sujecion", "sedacion", "anestesia"]
	var up := order.find(id) > order.find(sedation)
	sedation = id
	serial += 1
	# más sujeción o más sedación a tiempo: la amenaza se apaga en el acto (unidad 5t-A) y la próxima tirada espera
	if up and (reaction_warning or _arm_k >= 0):
		reaction_warning = false
		_arm_k = -1
		_last_roll_k = k
	_update_reaction()
	return true


## ¿Está sedado o anestesiado como pide su especie? La rapaz, sujeta (capucha y toalla) basta; el tigre, el oso y el
## velocirraptor, sedación o anestesia.
func restrained() -> bool:
	if animal_id == "rapaz":
		return sedation != "libre"
	return sedation in ["sedacion", "anestesia"]


## Empieza o acaba la pausa para calmarlo. Al empezarla se apaga la amenaza (se apartan las manos de sus garras).
func rest(on: bool) -> void:
	if on == resting:
		return
	resting = on
	serial += 1
	_update_reaction()


## Lo que baja el estrés cada segundo en la pausa con su sujeción de ahora (ClawCareReaction.CALM, índice por segundo).
func calm_rate() -> float:
	return float(Reaction.CALM.get(sedation, 0.0))


## Una acción sobre una de sus garras: tocarlas a un animal grande sin sedarlo lo apunta como peligro (y acaba la pausa).
func note_handling() -> void:
	if resting:
		resting = false
		serial += 1
	if not handled:
		handled = true
		serial += 1
	if animal_id != "rapaz" and sedation not in ["sedacion", "anestesia"] and not unsafe:
		unsafe = true
		serial += 1


## El estrés del tiempo que pasa sujeto: rate·dt por cada paso nuevo del reloj (el que ya contó otra garra, no). step: el
## paso que acaba (el de la garra que avanza).
func count_step(step: int, rate: float, dt: float) -> void:
	if step <= k:
		return
	_dt = dt
	if resting:
		# en la pausa, cada paso del reloj (también los que se cuentan de una vez) le calma
		stress = maxf(stress - calm_rate() * float(step - k) * dt, 0.0)
	elif accumulates():
		stress = minf(stress + rate * dt, 1.0)
	k = step
	_update_reaction()


## ¿Suma estrés el tiempo que pasa? Solo mientras se le manejan las garras (una acción o un gesto en marcha: gripped), a
## la velocidad de su sujeción (stress_rate). Si solo pasa el tiempo (idle, ClawCare.advance), nadie lo toca: no suma, con
## cualquier sujeción; y en la pausa baja (CALM). Eric, petición 51 y 18-10-2026: «no quiero algo hardcore»; antes, tocarlo
## una vez lo hacía sumar para siempre (un 2 % por segundo sin sujetar con la herramienta ya parada).
func accumulates() -> bool:
	return not resting and handled and (gripped or not idle)


## La reacción al dolor p (0-1) de una acción en cualquiera de sus garras: el estrés sube y, si pasa de lo que aguanta con su
## sujeción, se mueve. true si se ha movido.
func react(p: float) -> bool:
	if resting:
		resting = false
	pain = p
	max_pain = maxf(max_pain, p)
	serial += 1
	if p <= 0.0:
		return false
	# con anestesia general no siente el dolor: no le estresa (el dolor se apunta igual, para el informe)
	if sedation != "anestesia":
		stress = minf(stress + 0.2 * p, 1.0)
	_update_reaction()
	if p >= float(CareData.SEDATION[sedation].move_pain):
		moved += 1
		return true
	return false


# ════════ La reacción (unidad 5t-A) ════════

## Lo que puede moverse ahora (0-1, ClawCareReaction.mobility_of): 0 con la sujeción que basta para su especie.
func mobility() -> float:
	return Reaction.mobility_of(animal_id, sedation)


## ¿Puede revolverse ahora? Ya se le ha tocado, no está en la pausa, puede moverse algo (mobility() > 0: con la sujeción que
## basta, solo el resto de RESIDUAL) y el estrés pasa de «inquieto» (REACTION.low).
func can_react() -> bool:
	return handled and not resting and mobility() > 0.0 and stress >= float(Reaction.REACTION.low)


## La probabilidad de que se revuelva en la próxima tirada (0-1, ClawCareReaction.chance): con la sujeción que basta, solo
## si le duele mucho (ClawCareReaction.pain_gate con el dolor de la última acción).
func attack_chance() -> float:
	if not handled or resting:
		return 0.0
	return Reaction.chance(stress, mobility()) * Reaction.pain_gate(animal_id, sedation, pain)


## La máquina de la reacción, en el paso del reloj de ahora (k): cada REACTION.roll_s tira el dado (si ya ha pasado
## REACTION.gap_s desde el último zarpazo) y, si sale, se enciende la amenaza; si sigue así REACTION.warn_s, lanza el zarpazo;
## si se calma o se le seda bien antes, se apaga sin zarpazo.
func _update_reaction() -> void:
	if not can_react():
		if reaction_warning or _arm_k >= 0:
			reaction_warning = false
			_arm_k = -1
			serial += 1
		return
	if _last_react_k >= 0 and float(k - _last_react_k) * _dt < float(Reaction.REACTION.gap_s):
		return
	if _arm_k < 0:
		if _last_roll_k >= 0 and float(k - _last_roll_k) * _dt + 1e-9 < float(Reaction.REACTION.roll_s):
			return
		_last_roll_k = k
		if _rng.next() >= attack_chance():
			return
		_arm_k = k
		reaction_warning = true
		serial += 1
		return
	if float(k - _arm_k) * _dt + 1e-9 >= float(Reaction.REACTION.warn_s):
		reaction_seq += 1
		reaction_warning = false
		reaction_intensity = Reaction.intensity_of(mobility(), stress)
		reaction_lens = {}
		lens_pending = true
		_last_react_k = k
		_arm_k = -1
		serial += 1


## Al recogerlo después de soltarse (ClawCareState.recapture): una tirada con su azar (determinista) y, si sale
## (ClawCareReaction.RECAPTURE.chance), un zarpazo como el de la reacción, con su intensidad y su lente por calcular.
## true si ha habido zarpazo.
func recapture_roll() -> bool:
	if _rng.next() >= float(Reaction.RECAPTURE.chance):
		return false
	reaction_seq += 1
	reaction_warning = false
	# aún suelta: se mueve del todo (la sujeción llega después)
	reaction_intensity = Reaction.intensity_of(1.0, stress)
	reaction_lens = {}
	lens_pending = true
	_last_react_k = k
	_arm_k = -1
	serial += 1
	return true


## La reacción para la escena (copia): { seq, warning, kind, intensity, lens } (el contrato con la 5t-B).
func reaction_view() -> Dictionary:
	return {
		"seq": reaction_seq, "warning": reaction_warning, "kind": Reaction.kind_of(animal_id, claw_id),
		"intensity": reaction_intensity, "lens": reaction_lens.duplicate(true),
	}


## El estrés que suma cada segundo con su sujeción de ahora (índice por segundo).
func stress_rate() -> float:
	return float(CareData.SEDATION[sedation].stress_rate)


## Lo que pinta la escena del animal (copia): { animal, claw, sedation, sedationName, pain, maxPain, stress, moved, unsafe,
## restrained, handled, stressQuality, reaction, resting, attackChance, attackChanceQuality }; reaction: { seq, warning, kind,
## intensity, lens } (reaction_view).
func view() -> Dictionary:
	return {
		"animal": animal_id, "claw": claw_id, "sedation": sedation, "sedationName": String(CareData.SEDATION[sedation].name),
		"pain": pain, "maxPain": max_pain, "stress": stress, "moved": moved, "unsafe": unsafe, "restrained": restrained(),
		"handled": handled, "stressQuality": "índice pedagógico", "reaction": reaction_view(), "resting": resting,
		"attackChance": attack_chance(), "attackChanceQuality": "juego",
	}
