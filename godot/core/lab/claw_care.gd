## Tribología biológica · cetrería y cuidado de garras: el ensayo paso a paso (modelo 2.0, unidad 5a). Un objeto por
## garra (RefCounted, sin nodos ni variables estáticas mutables, determinista): la escena 3D de la unidad 5b lo mueve con
## el ratón y el teclado y pinta sus instantáneas. Datos con fuente: claw_care_data.gd. Guía: docs/fisica/cetreria.md.
##
## La garra es un estuche de queratina a lo largo de su curva (estaciones cada STATION_MM desde la base): su radio exterior
## (el de área equivalente) y, dentro, el de la carne viva (núcleo óseo con su dermis), que acaba donde acaba el hueso.
##   - Limar o tornear (Archard): ΔV = η·K·F·L/H. K = K_corte·fab·g: K_corte, el de un diente (1/tan θ) o de un grano
##     (2/(π·tan θ)) que cortase todo lo que hunde; fab, la parte que de verdad arranca, del grado de penetración de cada
##     diente o grano (Hokkirigawa-Kato, core/shared/abrasion.gd); g, el efecto del tamaño de grano hasta el tamaño crítico
##     (Kalácska 2021). η: la herramienta solo muerde lo que es más blando que ella (Contact.hardness_efficiency).
##   - La punta: limar de frente (≥ TRUNCATE_DEG) acorta y deja una cara plana (roma); limar en ángulo talla una faceta
##     cónica de ese semiángulo que afila la punta hasta el radio de la arista o del grano de la herramienta y, pasado el
##     vértice, acorta. La carga de lado que aguanta la punta es la del voladizo de claw_sharpness.gd (crece con R²).
##   - En contra de las capas (de la punta a la base) los dientes levantan el borde de las láminas: se deshojan si la
##     fuerza de pelado por unidad de ancho, μ·F/w, pasa de la tenacidad entre capas. A favor, no.
##   - Cortaúñas: la hoja es una cuña que abre una grieta a lo largo (viga doble en voladizo con desplazamiento impuesto:
##     G = 3·E·h³·Δ²/(16·a⁴)); raja hasta a = (3·E·h³·Δ²/(16·J))^¼. Si llega a la carne viva, la garra se rompe. Y aplasta
##     el tejido vivo que queda a menos de crush_k radios del corte.
##   - Calor del torno (P = ε·μ·F·v entra en la garra; a mano, la lima desliza 40-90 veces más despacio y el calor se
##     desprecia): conducción en una dimensión a lo largo de la garra (con su sección, que crece de la punta a la base) o
##     a través de la pared del flanco, hasta la carne viva y la sangre, a su temperatura, detrás; la superficie se enfría
##     al aire. Dolor desde ~43 °C; lesión con el tiempo a cada temperatura (Moritz & Henriques 1947). Una giratoria que
##     roza sin morder también calienta, con el rozamiento de la pareja (rub_mu; unidad 5l).
##   - La herramienta se gasta (unidad 5l): Archard con la razón de durezas al revés (tool_wear_k, de Pintaude 2009), en el
##     kit del ensayo (claw_care_kit.gd); con los filos más redondos, corta menos (element_cut con su radio).
##   - En un material frágil por encima de la hondura crítica de Bifano, el surco se arranca entero, sin arado (unidad 5l).
##   - Los cortaúñas cortan si la mano, por su palanca, da la fuerza que pide cizallar la sección (unidad 5l).
##   - La carne viva cortada sangra hasta la hemostasia (presión, con o sin hemostático). Dolor, movimiento del animal
##     según esté sujeto o anestesiado, y estrés (índices pedagógicos).
## El reloj es un contador entero de pasos de DT; sin tocar la garra (advance), avanzar a trozos da lo mismo que de una vez.
## Qué no predice: docs/fisica/cetreria.md §9. Unidades: mm · N · HV · MPa · °C · s.
## Uso:
##   const ClawCare = preload("res://core/lab/claw_care.gd")
##   var care := ClawCare.new({ "animal": "rapaz", "claw": "aguila", "overgrowth_days": 90 })
##   care.clip({ "tool": "guillotina", "remove_mm": 3.0 })
##   care.file({ "tool": "lima_fina", "zone": "punta", "angle_deg": 25, "force_n": 4, "travel_mm": 40, "direction": "a_favor" })
##   var snap := care.snapshot()       # perfil, punta, calor, sangre, grietas, animal, sucesos…
##   var rep := care.report()          # veredicto, nota y consejos con su fuente
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")
const Js = preload("res://core/shared/js.gd")
const Format = preload("res://core/shared/format.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Rng = preload("res://core/shared/rng.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const Physics = preload("res://core/lab/physics.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const Tutorial = preload("res://core/lab/claw_care_tutorial.gd")
const Patient = preload("res://core/lab/claw_care_patient.gd")
const Kit = preload("res://core/lab/claw_care_kit.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")

## Paso de tiempo interno (s). El modelo térmico es implícito (Euler hacia atrás): estable con cualquier paso.
const DT := 1.0 / 60.0
## Sin calor que meter, el modelo térmico avanza a bloques de COOL_BLOCK pasos alineados con el reloj (se enfría igual,
## con un paso implícito más largo, y cuesta 15 veces menos).
const COOL_BLOCK := 15
## Trozo más largo de un toque del torno (s): arranca y calienta a trozos, y el calor de lo arrancado se va con ello.
const ROTARY_CHUNK_S := 0.1
## Largo de la punta (mm) por el que entra el calor del torno cuando no hay faceta más larga: el calor nace en la
## superficie, pero una punta afilada no tiene volumen en el vértice (regularización del modelo).
const HEAT_ZONE_MM := 0.5
## Radio mínimo de la sección de la garra en el modelo térmico (mm): la punta nunca es más fina que un contacto.
const THERMAL_R_FLOOR_MM := 0.05
## Separación de las estaciones a lo largo de la curva (mm).
const STATION_MM := 0.05
## Lo que tiene que sobresalir la pieza pegada sobre el muñón para que una herramienta plana que pasa por la unión se apoye solo
## en ella (mm; unidad 5o): la lima o el tambor tocan lo alto, no la queratina de debajo del escalón. Tolerancia geométrica del
## modelo (una estación de radio), no un dato medido.
const JOINT_LEVEL_MM := 0.02
## Celda del modelo térmico (mm).
const THERMAL_DX_MM := 0.1
## Limar a más de este ángulo con el eje de la garra es limar de frente: acorta y deja la cara plana (grados).
const TRUNCATE_DEG := 80.0
## El núcleo vivo nunca es más grueso que esta fracción del radio de la garra (el estuche cubre siempre el hueso).
## Estimación geométrica: sin medición del espesor del estuche.
const CORE_MAX_FRACTION := 0.8
## Dureza (HV) del acero de las hojas de los cortaúñas: la de las limas (60-62 HRC, ~700 HV). Estimación.
const BLADE_HV := 700.0
## Tamaño de la mancha oscura del corte al acercarse a la carne viva en una garra oscura: a menos de un radio de la
## garra (dibujo; la señal que describe Dremel, sin distancia medida).
const SIGN_RADII := 1.0
## Tope de la dosis de lesión térmica (a partir de 1 el tejido ya está lesionado).
const DOSE_CAP := 100.0
## Probar la punta (unidad 5g): el material en el que se apoya (la «Uña ajena» del banco, Catalog.TARGETS), la fuerza de un
## toque ligero (elección del ensayo: como al probar un filo en la uña, sin apretar) y lo que dura el gesto (s).
const PROBE_TARGET := "una"
const PROBE_FORCE_N := 0.5
const PROBE_S := 0.5
const PROBE_SOURCE := "la uña del banco de ensayo (queratina de 25 HV y 2,9 GPa, μ = 0,3); el umbral de cesión bajo una esfera, p0 = 1,6·Y, de " + ClawSharpness.SRC_JOHNSON + "; la carga de rotura de la punta crece con R² (" + ClawSharpness.SRC_PATTRICK + "); la distancia crítica de " + ClawSharpness.SRC_TAYLOR + "; el toque de 0,5 N es una elección del ensayo"

# ── Identidad y ajustes ──
var _setup: Dictionary = {}
var _animal: Dictionary = {}
var _claw: Dictionary = {}
## La forma de la garra de este dedo (CareData.claw_shape): largo, alto de la base, arco y sección (petición 36).
var _shape: Dictionary = {}
## El bloque en bruto reforjado sobre el muñón de una garra rota (petición 35; ClawForge.care_setup): desde _block_from (mm
## desde la base) la garra es del material del bloque; antes, la queratina del muñón con su carne viva. INF: sin bloque.
## _block: el material (Catalog.INLAYS o el acrílico de la prótesis de verdad, ForgeData.PROSTHESIS; unidad 5j) con stumpMm,
## wallMm, fiction, note y source.
var _block_from := INF
## La punta con la que empieza (CareData.TIP_STARTS): «natural» no cambia nada.
var _tip_start := "natural"
## Cómo llega rota la garra (CareData.BROKEN_STARTS) o «»: sana.
var _broken_start := ""
var _block: Dictionary = {}
## Lo construido del bloque a capas (unidad 5o: el acrílico y la resina, capa a capa; mm desde el muñón). INF: el bloque
## entero, de una vez (la pieza rígida pegada).
var _block_built := INF
## El calor del bloque (unidad 5j; lo dejó la 5g): block_thermal() de su material, o {} si su ficha no trae la conducción, el
## calor específico o la densidad (entonces se cuenta como la queratina). _block_hot: ya ha llegado a su tope.
var _block_th: Dictionary = {}
var _block_hot := false
## El material de la última pasada (_mat_at): el sonido del rayado.
var _last_mat: Dictionary = {}
var _inlay: Dictionary = {}
var _reforged := false
var _humidity := "natural"
var _hv := 30.0
var _e_gpa := 2.0
var _alpha := 15.0
var _r0_um := 100.0
var _L_nat := 35.0
var _over := 0.0
var _core_ratio := 0.699
var _s_quick := 0.0
var _base_r := 5.0
var _tip0: Dictionary = {}

# ── Geometría ──
var _n := 0
var _r := PackedFloat64Array()
var _core := PackedFloat64Array()
var _s_apex := 0.0
var _flat_r := 0.0
var _point_um := 100.0
var _tip_alpha := 15.0
var _facet_deg := 0.0
var _facet_back := 0.0  # donde empieza la faceta (mm desde la base); la punta natural si no hay
var _removed_mm3 := 0.0

# ── Daños ──
var _splits: Array = []  # [{ from_s, to_s, reaches_quick }]
var _peels: Array = []  # [{ from_s, to_s }]
var _peel_depth := PackedFloat64Array()  # arranque a favor acumulado sobre cada estación deshojada (mm)
var _chips := 0
var _flattened := 0
var _broken := false
var _quick_cut := false
var _wall_through := false
## Las roturas con su sitio (petición 35): [{ kind, sMm, pieceMm, fromS, toS, reachesQuick, tS, tool, profile, source }].
var _breaks: Array = []
## La herramienta de la acción en curso (para apuntar quién rompió qué).
var _cur_tool := ""
## La cara llegó a la temperatura a la que la queratina se quema (CareData.THERMAL.char_c): el modelo no pasa de ahí.
var _charred := false

# ── Superficie ── (petición 37: por estación, como _r; CareData.SURFACE)
var _sra := PackedFloat64Array()  # Ra (µm) que dejó la última herramienta (la de partida, si no se ha tocado)
var _sburn := PackedFloat64Array()  # quemado (0-1)
var _schipd := PackedFloat64Array()  # hondura de los desconchones del régimen frágil y de las mellas (mm)
var _sscr := PackedFloat64Array()  # dirección del rayado de la última pasada (grados respecto al eje de la garra)
var _schip := PackedFloat64Array()  # 0 o 1: desconchón, escama o grieta (lo que se enseña)
var _ra0 := 0.5

# ── Calor ── (_th: exceso de temperatura θ = T − T_partida en cada nodo, del extremo vivo a la cara que se trabaja)
var _th := PackedFloat64Array()
var _th_c := PackedFloat64Array()  # capacidad térmica de cada nodo (J/K)
var _th_g := PackedFloat64Array()  # conductancia al nodo siguiente (W/K)
var _th_h := PackedFloat64Array()  # pérdida al aire (W/K)
var _th_w := PackedFloat64Array()  # parte del calor del torno que entra en cada nodo (suman 1)
var _th_cp := PackedFloat64Array()  # vectores de trabajo del algoritmo de Thomas
var _th_dp := PackedFloat64Array()
var _th_live := 0
var _th_reach := false
var _th_zone := "punta"
var _th_zone_s := 0.0
## En el flanco, el tramo de la garra que toca la herramienta (mm desde la base): por donde entra el calor.
var _th_flank_a := 0.0
var _th_flank_b := 0.0
var _th_heat_len := HEAT_ZONE_MM
var _th_frozen_to := 0
## Con el bloque (unidad 5j): el tope de cada nodo (θ máximo: el de la queratina o el del bloque) y si es del bloque. Vacíos
## sin bloque: entonces todos los nodos son de queratina, con su tope.
var _th_capv := PackedFloat64Array()
var _th_isblk := PackedByteArray()
var _flank_contact_mm2 := 0.0
var _quick_c := 32.0
var _peak_quick_c := 32.0
var _face_c := 32.0
var _dose := 0.0
var _heat_pain_s := 0.0

# ── Sangre, animal y protocolo ──
var _bleeding := false
var _bled := false
var _bleed_area := 0.0
var _bleed_t := 0.0
## Todo el tiempo que ha sangrado esta garra en el ensayo (s), de todas sus heridas: la sangre que pierde el animal (unidad 5o).
var _bleed_total := 0.0
var _press_t := 0.0
var _agent_t := 0.0
var _agent_used := ""
var _hemostasis_done := false
## El animal: su sujeción, su dolor, sus movimientos y su estrés (claw_care_patient.gd). Lo comparten todas las garras de
## un mismo animal (ClawCareState); una ClawCare sola tiene el suyo (_owns_patient).
var _patient: Patient
var _owns_patient := true
## Las herramientas y lo que se han gastado (claw_care_kit.gd; unidad 5l): las del ensayo, que comparten todas las garras del
## animal (ClawCareState); una ClawCare sola tiene las suyas (_owns_kit).
var _kit: Kit
var _owns_kit := true
## Veces que el animal se ha movido de dolor por lo que se le ha hecho a esta garra (el criterio de su informe).
var _moved_here := 0
var _disinfected := false
var _cream := false
var _repaired := false
var _wetted := false
var _tools_used: Dictionary = {}
## Las rpm más altas a las que se ha usado cada herramienta giratoria (para el consejo del calor).
var _rpm_max: Dictionary = {}
var _no_bite := false
var _no_bite_tools: Dictionary = {}
## Las herramientas giratorias que ya han rozado sin morder (el aviso del roce, una vez; unidad 5l).
var _rub_tools: Dictionary = {}
var _directions: Dictionary = {}
var _events: Array = []
var _k := 0
var _serial := 0


## setup: los ajustes del ensayo (configure). patient: el animal, si lo comparte con otras garras (ClawCareState); sin él,
## la garra tiene el suyo. kit: las herramientas del ensayo (claw_care_kit.gd), si las comparte; sin él, las suyas.
func _init(setup: Dictionary = {}, patient: Variant = null, kit: Variant = null) -> void:
	if patient != null:
		_patient = patient
		_owns_patient = false
	else:
		_patient = Patient.new()
	if kit != null:
		_kit = kit
		_owns_kit = false
	else:
		_kit = Kit.new()
	configure(setup)


# ════════════════════════════════ Ajustes ════════════════════════════════

## Empieza un ensayo nuevo: { animal, claw (rapaces: RAPTOR_IDS), digit (el dedo: CareData.CLAW_SHAPES; sin él, el de
## referencia, que es la garra de la ficha del banco), paw (la pata: una «trasera…» del tigre o del oso toma la forma de sus
## patas traseras), inlay (Catalog.INLAYS: los de la 1.x y los nuevos de la 2.0, el rubí y la alúmina; «none» la
## queratina), overgrowth_days (o overgrowth_mm), humidity (HUMIDITY_IDS), sedation (SEDATION), quick («valor» | «min» |
## «max» | «oculta»: en la banda, con la semilla), seed, block (la garra rota que vuelve de la reforja: { material (de
## Catalog.INLAYS o el acrílico de la prótesis de verdad, ForgeData.PROSTHESIS: supports_block), stump_mm (el muñón de
## queratina, mm desde la base), wall_mm (lo que sobra el bloque alrededor y delante del largo natural; por defecto, la
## pared de la funda, ForgeData.SHEATH), fiction, note, source }; petición 35) }.
func configure(setup: Dictionary) -> void:
	var s := setup.duplicate(true)
	var aid := String(s.get("animal", "rapaz"))
	if not CareData.ANIMALS.has(aid):
		aid = "rapaz"
	_animal = CareData.animal(aid)
	var cid := String(s.get("claw", _animal.claw))
	if not (_animal.claws as Array).has(cid):
		cid = String(_animal.claw)
	_claw = CareData.claw_entry(cid)
	# la garra de este dedo y de esta pata (petición 36): el largo y el alto de la base, relativos a la del banco
	_shape = CareData.claw_shape(cid, String(s.get("digit", "")), String(s.get("paw", "")).begins_with("trasera"))
	var iid := String(s.get("inlay", "none"))
	var inl: Variant = Catalog.find_by_id(Catalog.INLAYS, iid)
	_inlay = (inl as Dictionary).duplicate(true) if inl != null else (Catalog.INLAYS[0] as Dictionary).duplicate(true)
	_reforged = String(_inlay.id) != "none"
	_humidity = String(s.get("humidity", "natural"))
	if not CareData.KERATIN.has(_humidity):
		_humidity = "natural"
	# la sujeción es del animal: la suya se empieza de nuevo; la de un animal compartido, la lleva quien lo comparte
	if _owns_patient:
		var sed := String(s.get("sedation", _animal.restraint))
		_patient.reset(aid, sed if CareData.SEDATION.has(sed) else String(_animal.restraint), cid)
	# las herramientas también: las suyas, nuevas; las de un ensayo compartido, las lleva quien lo comparte
	if _owns_kit:
		_kit.reset()
	s["animal"] = aid
	s["claw"] = cid
	s["digit"] = String(_shape.digit)
	s["inlay"] = String(_inlay.id)
	s["humidity"] = _humidity
	s["sedation"] = _patient.sedation
	# la punta al empezar (petición de Eric en la 5s): natural, o roma, afilada o aguja (CareData.TIP_STARTS)
	_tip_start = String(s.get("tip_start", "natural"))
	if not CareData.TIP_STARTS.has(_tip_start):
		_tip_start = "natural"
	s["tip_start"] = _tip_start
	_setup = s
	# Material de la garra: la queratina de la ficha, o el de la garra reforjada (la forma no cambia: Physics.resolve_tool)
	_hv = float(_inlay.hv) if _reforged else float(_claw.hv)
	_e_gpa = float(_inlay.E) if _reforged else float(_claw.E)
	_alpha = float(_claw.alpha)
	_r0_um = ClawSharpness.radius_um_of_area(float(_claw.area))
	_L_nat = float(_claw.reach) * float(_shape.lengthRatio)
	_base_r = float(Physics.MODEL["clawBase"]) * float(_claw.reach) * float(_shape.baseRatio)
	_tip0 = Contact.tip_geometry(float(_claw.area), _alpha, _base_r)
	var growth := float(_animal.growth_mm_day.value)
	if _reforged:
		# una garra reforjada (metal, gema, cerámica, polímero) es materia inerte: no crece (Eric, 12-10-2026). Lo que
		# crece es la queratina del muñón, desde la base, y la pieza no se alarga: sin crecimiento de más
		_over = 0.0
	elif s.has("overgrowth_mm"):
		_over = maxf(float(s.overgrowth_mm), 0.0)
	else:
		_over = maxf(float(s.get("overgrowth_days", CareData.DEFAULT_OVERGROWTH_DAYS)), 0.0) * growth
	var band: Dictionary = _animal.core_ratio
	match String(s.get("quick", "valor")):
		"min":
			_core_ratio = float(band.min)
		"max":
			_core_ratio = float(band.max)
		"oculta":
			var rng := Rng.new(Rng.seed_of("carne-viva:%s:%s" % [cid, String(s.get("seed", "cetreria"))]))
			_core_ratio = float(band.min) + (float(band.max) - float(band.min)) * rng.next()
		_:
			_core_ratio = float(band.value)
	_s_quick = 0.0 if _reforged else _core_ratio * _L_nat
	# el bloque en bruto sobre el muñón (petición 35): la carne viva se queda en el muñón
	_block = {}
	_block_from = INF
	_block_built = INF
	_block_th = {}
	var blk: Variant = s.get("block", null)
	if blk is Dictionary and not _reforged:
		var bid := String((blk as Dictionary).get("material", ""))
		var bm: Variant = Catalog.find_by_id(Catalog.INLAYS, bid)
		if bm == null:
			bm = ForgeData.prosthesis_entry(bid)
		if bm == null and bid == String(CareData.RESIN.id):
			# la resina fotopolimerizable (unidad 5o), la otra reparación de verdad, capa a capa con la lámpara
			bm = CareData.RESIN.duplicate(true)
		if bm != null and String((bm as Dictionary).id) != "none":
			_block = (bm as Dictionary).duplicate(true)
			var stump := clampf(float((blk as Dictionary).get("stump_mm", 0.5 * _L_nat)), STATION_MM, _L_nat + _over)
			_block.merge({
				"stumpMm": stump, "wallMm": maxf(float((blk as Dictionary).get("wall_mm", ForgeData.SHEATH.wall_mm)), 0.0),
				"fiction": bool((blk as Dictionary).get("fiction", true)), "note": String((blk as Dictionary).get("note", "")),
				"source": String((blk as Dictionary).get("source", "")),
			}, true)
			_block_from = stump
			_block_built = maxf(float((blk as Dictionary).built_mm), STATION_MM) if (blk as Dictionary).has("built_mm") else INF
			_s_quick = minf(_s_quick, stump)
			_block_th = block_thermal(String(_block.id))
	_build_profile()
	_reset_damage()
	_reset_thermal()
	_reset_surface(s)
	_events = []
	_k = 0
	# la garra rota de serie (unidad 5v): partida ya al empezar, con la física de la rotura de siempre
	_broken_start = String(s.get("broken_start", ""))
	if not CareData.BROKEN_STARTS.has(_broken_start) or _reforged or _block_from < INF:
		_broken_start = ""
	if _broken_start != "":
		_setup["broken_start"] = _broken_start
		_apply_broken_start()
	else:
		_setup.erase("broken_start")
	if not _block.is_empty():
		_event("bloque", "Bloque en bruto de %s pegado al muñón (%s mm de queratina): hay que limarlo hasta la forma de la garra natural, con herramientas más duras que el material.%s" % [
			String(_block.name).to_lower(), Js.to_fixed(_block_from, 1), (" " + String(_block.note)) if String(_block.note) != "" else ""], String(_block.source) if String(_block.source) != "" else CareData.SRC_SAMOUR)
	_serial += 1


## La garra rota de serie (CareData.BROKEN_STARTS): se parte donde dice, con _break_off (el trozo se va y, por dentro de la carne
## viva, sangra). No cuenta como un error del ensayo: llega así.
func _apply_broken_start() -> void:
	var e: Dictionary = CareData.BROKEN_STARTS[_broken_start]
	var s_cut := _s_apex
	if _broken_start == "fresca":
		s_cut = maxf(_s_quick - float(e.into_quick_frac) * _L_nat, STATION_MM)
	else:
		s_cut = minf(_s_quick + float(e.beyond_quick_mm), _s_apex - STATION_MM)
	_break_off(s_cut, String(e.source))
	_broken = true
	_event("rota_de_serie", "Llega con la garra rota: %s (%s mm de garra)." % [String(e.name), Js.to_fixed(_s_apex, 1)], String(e.source))


## La forma de la garra de un dedo sin crear una ClawCare (unidad 5o: para dibujar cada garra del animal con la suya, lo
## pidió la 5k): { arcDeg, sectionRatio, naturalMm, baseRadiusMm, curve, ventralFlat }, con las mismas cuentas que configure().
static func shape_dims(claw_id: String, digit: String, hind: bool) -> Dictionary:
	var c := CareData.claw_entry(claw_id)
	var sh := CareData.claw_shape(claw_id, digit, hind)
	var reach := float(c.get("reach", 0.0))
	return {
		"arcDeg": float(sh.arcDeg), "sectionRatio": float(sh.sectionRatio), "naturalMm": reach * float(sh.lengthRatio),
		"baseRadiusMm": float(Physics.MODEL["clawBase"]) * reach * float(sh.baseRatio), "curve": (float(sh.arcDeg) - 35.0) / 115.0,
		"ventralFlat": bool(sh.ventralFlat),
	}


## El largo natural de esta garra (mm): el del banco por el de su dedo (CareData.claw_shape).
func natural_mm() -> float:
	return _L_nat


## Ajustes actuales (copia).
func setup() -> Dictionary:
	var s := _setup.duplicate(true)
	s["sedation"] = _patient.sedation
	return s


## El animal y el material de la garra («none»: la queratina), sin copiar los ajustes (el tutorial los pide a menudo).
func tutorial_key() -> String:
	return "%s|%s" % [String(_animal.id), String(_inlay.id)]


## El animal de esta garra (el que comparte con sus otras garras, si lo comparte).
func patient() -> Patient:
	return _patient


## Las herramientas del ensayo (las que comparte con las otras garras, si las comparte; unidad 5l).
func kit() -> Kit:
	return _kit


## Cómo van las herramientas de limar del ensayo (unidad 5l): { id: ClawCareKit.state() }, para la escena y la interfaz.
func tools() -> Dictionary:
	return _kit.view()


## Una nueva de la bandeja (unidad 5l): la herramienta id vuelve a cortar como el primer día. false si no se gasta.
func renew_tool(id: String) -> bool:
	var t := CareData.tool(id)
	if not Kit.wears(t):
		return false
	_kit.renew(id)
	_event("herramienta_nueva", "%s nueva de la bandeja: corta como el primer día." % String(t.name), String(CareData.TOOL_WEAR.k_mild.source))
	_serial += 1
	return true


## ¿Sabe la cetrería limar una garra de este material? Los de Catalog.INLAYS: la queratina («none»), los de la 1.x y los
## nuevos de la 2.0 (el rubí y la alúmina de la reforja). Lo usa ClawForge.care_setup().
static func supports_inlay(id: String) -> bool:
	return Catalog.find_by_id(Catalog.INLAYS, id) != null


## ¿Sabe la cetrería limar un bloque de este material pegado al muñón de una garra rota? Los del banco (supports_inlay) y el
## acrílico de la prótesis de verdad (ForgeData.PROSTHESIS; unidad 5j). Lo usa ClawForge.care_setup().
static func supports_block(id: String) -> bool:
	return id != "none" and (supports_inlay(id) or ForgeData.PROSTHESIS.has(id) or id == String(CareData.RESIN.id))


## La resistencia de un material de la garra (ClawSharpness.strength_of) y, si el banco no la tiene, la de la reforja (el
## acrílico de la prótesis de verdad: ForgeData.strength_of; unidad 5j) o la de la resina (CareData.RESIN; unidad 5o). null
## sin datos.
static func _strength_of(inlay: Variant) -> Variant:
	var st: Variant = ClawSharpness.strength_of(inlay)
	if st == null and inlay is Dictionary:
		st = ForgeData.strength_of(String((inlay as Dictionary).get("id", "")))
	if st == null and inlay is Dictionary and String((inlay as Dictionary).get("id", "")) == String(CareData.RESIN.id):
		var q := CareData.RESIN
		st = { "value": q.strength_mpa, "min": q.strength_min, "max": q.strength_max, "kind": "flexion", "kic": q.kic, "family": "polimero", "quality": q.quality, "source": q.source }
	return st


## El perfil de partida: la garra natural con lo que ha crecido de más; con un bloque (petición 35), el muñón de queratina
## hasta _block_from, con el perfil que tenía, y desde ahí un cilindro en bruto con wallMm de sobra alrededor (sobre el radio
## del muñón) y delante del largo natural, de cara plana: la pieza sin tallar, como el bloque del que la reforja talla la
## funda (ClawForge.sheath_geometry: rawDiameterMm, la funda más su pared).
func _build_profile() -> void:
	var L_old := _L_nat + _over
	var L0 := L_old
	var r_block := 0.0
	if _block_from < INF:
		r_block = Contact.hole_radius(_tip0, L_old - _block_from) + float(_block.wallMm)
		L0 = maxf(_L_nat, _block_from) + float(_block.wallMm)
		# a capas (unidad 5o): solo lo construido
		L0 = minf(L0, _block_from + _block_built)
	_n = int(ceil(L0 / STATION_MM)) + 1
	_r = PackedFloat64Array()
	_core = PackedFloat64Array()
	_r.resize(_n)
	_core.resize(_n)
	var ta := V8.js_tan(_alpha * Contact.DEG)
	for i in _n:
		var s := float(i) * STATION_MM
		var d := L_old - s
		var r := Contact.hole_radius(_tip0, d) if d > 0.0 else 0.0
		if _block_from < INF and s >= _block_from - 1e-9:
			r = r_block if s <= L0 + 1e-9 else 0.0
		_r[i] = r
		var c := 0.0
		if _s_quick > s:
			c = minf((_s_quick - s) * ta, CORE_MAX_FRACTION * r)
		_core[i] = c
	_s_apex = L0
	_flat_r = r_block
	_point_um = _r0_um
	_tip_alpha = _alpha
	_facet_deg = 0.0
	_facet_back = L0
	_removed_mm3 = 0.0
	if _tip_start != "natural" and _block_from == INF:
		_apply_tip_start(L0)


## La punta al empezar que no es la natural (CareData.TIP_STARTS): la roma, la natural gastada (una esfera de ratio·R0
## tangente al mismo cono, más atrás: la garra más corta y redondeada); la afilada y la aguja, una punta de ratio·R0 sobre un
## cono más estrecho (alpha_k), más larga, que se junta con la natural a needle_frac del largo. El perfil, el vértice, el radio
## de la punta y su semiángulo (los usa todo lo demás: el aguante de lado, la presión al pinchar, el medidor). Con bloque, no.
func _apply_tip_start(L0: float) -> void:
	var ts: Dictionary = CareData.TIP_STARTS[_tip_start]
	var ratio := float(ts.ratio)
	var r_um := _r0_um * ratio
	var al := _alpha * float(ts.alpha_k)
	var tip_s := Contact.tip_geometry(ClawSharpness.area_of_radius_um(r_um), al, float(_tip0.get("amax", INF)))
	var dr := (r_um - _r0_um) / 1000.0
	var inv_s := 1.0 / V8.js_sin(_alpha * Contact.DEG) - 1.0
	var blunt := ratio > 1.0
	var apex := L0 - dr * inv_s
	if not blunt:
		var dm := float(ts.needle_frac) * _L_nat
		apex = L0 - dr * inv_s + dm * (1.0 - V8.js_tan(al * Contact.DEG) / V8.js_tan(_alpha * Contact.DEG))
	var n_new := int(ceil(apex / STATION_MM)) + 1
	var r_old := _r
	var ta := V8.js_tan(_alpha * Contact.DEG)
	_r = PackedFloat64Array()
	_core = PackedFloat64Array()
	_r.resize(n_new)
	_core.resize(n_new)
	for i in n_new:
		var s := float(i) * STATION_MM
		var r_nat := r_old[i] if i < r_old.size() else 0.0
		var f := Contact.hole_radius(tip_s, apex - s) if apex - s > 0.0 else 0.0
		var r := minf(r_nat, f) if blunt else maxf(r_nat, f)
		if s > apex:
			r = 0.0
		_r[i] = r
		var c := 0.0
		if _s_quick > s:
			c = minf((_s_quick - s) * ta, CORE_MAX_FRACTION * r)
		_core[i] = c
	_n = n_new
	_s_apex = apex
	_point_um = r_um
	_tip_alpha = al
	_facet_back = apex


func _reset_damage() -> void:
	_splits = []
	_peels = []
	_peel_depth = PackedFloat64Array()
	_peel_depth.resize(_n)
	_chips = 0
	_flattened = 0
	_broken = false
	_quick_cut = false
	_wall_through = false
	_breaks = []
	_cur_tool = ""
	_bleeding = false
	_bled = false
	_bleed_area = 0.0
	_bleed_t = 0.0
	_bleed_total = 0.0
	_press_t = 0.0
	_agent_t = 0.0
	_agent_used = ""
	_hemostasis_done = false
	_moved_here = 0
	_disinfected = false
	_cream = false
	_repaired = false
	_wetted = false
	_tools_used = {}
	_rpm_max = {}
	_no_bite = false
	_no_bite_tools = {}
	_rub_tools = {}
	_directions = {}
	_last_mat = {}


## Cambia la humedad de la queratina (remojar o dejar secar): «seca», «natural», «humeda», «empapada».
func set_humidity(humidity: String) -> void:
	if not CareData.KERATIN.has(humidity):
		return
	if humidity in ["humeda", "empapada"] and _humidity not in ["humeda", "empapada"]:
		_wetted = true
		_event("remojar", "Garra remojada: la queratina se ablanda (y se deshoja con más facilidad).", CareData.SRC_AAD + "; " + CareData.SRC_FARRAN)
	_humidity = humidity
	_setup["humidity"] = humidity
	_serial += 1


## Cambia la sujeción o la anestesia.
## Cambia la sujeción o la anestesia: la del animal, la de todas sus garras.
func set_sedation(sedation: String) -> void:
	if not _patient.set_sedation(sedation):
		return
	_setup["sedation"] = sedation
	_serial += 1


## Tocar las garras de un tigre, un oso o un velocirraptor sin sedación ni anestesia es peligroso, y anestesiarlo después
## no lo borra (nota 0 en el informe). Lo apunta cada acción sobre la garra; preparar al animal antes de la primera, no.
func _note_handling() -> void:
	_patient.note_handling()


# ════════════════════════════════ Geometría ════════════════════════════════

## Radio exterior (mm) de la garra en la posición s (mm desde la base), interpolado entre estaciones; 0 más allá de la
## punta. En el último tramo va de la última estación a la cara de la punta (su radio si es plana; 0 si está afilada).
func radius_at(s: float) -> float:
	if s > _s_apex:
		return 0.0
	var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	var s_top := float(i_top) * STATION_MM
	if s > s_top and _s_apex > s_top:
		var u := (s - s_top) / (_s_apex - s_top)
		return _r[i_top] + (_flat_r - _r[i_top]) * u
	return _interp(_r, s)


## Radio de la carne viva (mm) en la posición s.
func core_at(s: float) -> float:
	return _interp(_core, s)


func _interp(a: PackedFloat64Array, s: float) -> float:
	if s <= 0.0:
		return a[0]
	var x := s / STATION_MM
	var i := int(floor(x))
	if i >= _n - 1:
		return a[_n - 1]
	var t := x - float(i)
	return a[i] * (1.0 - t) + a[i + 1] * t


## Posición de la punta (mm desde la base), largo que queda de más respecto al natural (mm) y distancia de la punta a la
## carne viva (mm; ≤ 0: expuesta).
func apex_mm() -> float:
	return _s_apex


func overgrowth_left_mm() -> float:
	return _s_apex - _L_nat


func quick_cover_mm() -> float:
	return INF if _reforged else _s_apex - _s_quick


## Radio de la punta (µm): la cara plana si queda, o la punta que dejó la última herramienta (la natural sin tocar).
func tip_radius_um() -> float:
	return maxf(_flat_r * 1000.0, _point_um)


## El material de la punta (unidad 5t-A: lo que toca la lente en un zarpazo): el id del material del vértice («none» la
## queratina; el de la garra reforjada, el del bloque o el de la funda pegada al muñón).
func tip_material_id() -> String:
	var m := _mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0))
	return String((m.inlay as Dictionary).get("id", "none")) if bool(m.reforged) else "none"


## Semiángulo de la punta (grados): el natural, o el de la última faceta tallada.
func tip_alpha_deg() -> float:
	return _tip_alpha


## Geometría de la punta para claw_sharpness.gd, con la base de la garra.
func tip_geometry() -> Dictionary:
	var t := ClawSharpness.tip_of(tip_radius_um(), _tip_alpha)
	t["amax"] = _base_r
	return t


# ════════════════════════════════ Física pura ════════════════════════════════

## Dureza de la queratina (MPa) en un estado de humedad: la del banco escalada con la resistencia (Tabor); una garra
## reforjada, la de su material (el agua no la ablanda).
static func hardness_mpa(claw_hv: float, humidity: String, reforged: bool = false) -> float:
	if reforged:
		return claw_hv * Contact.HV_MPA
	var k: Dictionary = CareData.keratin(humidity)
	return claw_hv * Contact.HV_MPA * float(k.sigma_mpa) / CareData.SIGMA_REF_MPA


## Corte de cada diente o grano: { elements, forceN (por elemento), depthUm, Dp, absMode, fab, g, kCut, k }.
## tool: una entrada de TOOLS (con tip_um, el radio de sus filos gastados, si se ha gastado: ClawCareKit.worn_tool; unidad
## 5l); force_n: la fuerza de la mano; w_mm, l_mm: ancho y largo del contacto; h_mpa: dureza.
static func element_cut(tool_d: Dictionary, force_n: float, w_mm: float, l_mm: float, h_mpa: float) -> Dictionary:
	var out := { "elements": 0.0, "forceN": 0.0, "depthUm": 0.0, "Dp": 0.0, "absMode": "arado", "fab": 0.0, "g": 0.0, "kCut": 0.0, "k": 0.0 }
	if force_n <= 0.0 or h_mpa <= 0.0 or w_mm <= 0.0 or l_mm <= 0.0:
		return out
	var tooth := String(tool_d.get("element", "grano")) == "diente"
	var geom: Dictionary = CareData.TOOTH_GEOMETRY if tooth else CareData.GRAIN_GEOMETRY
	var th: float = geom.half_angle_deg
	var tan_t := V8.js_tan(th * Contact.DEG)
	var tip_mm := _tip_um(tool_d) / 1000.0
	var n := 1.0
	var f := force_n
	var h := 0.0
	var dp := 0.0
	var k_cut := 0.0
	var g := 1.0
	if tooth:
		# filas de dientes bajo el contacto; cada arista (del ancho del contacto) cepilla una capa de hondura h
		n = maxf(float(tool_d.teeth_cm) * l_mm / 10.0, 1.0)
		f = force_n / n
		h = f / (h_mpa * tan_t * w_mm)
		# arista redondeada: media anchura del contacto b = √(2·r·h) mientras toca solo lo redondo
		var ht := tip_mm * (1.0 - V8.js_sin(th * Contact.DEG))
		var b := sqrt(2.0 * tip_mm * h) if h <= ht else tip_mm * V8.js_cos(th * Contact.DEG) + (h - ht) * tan_t
		dp = h / b if b > 0.0 else 0.0
		k_cut = 1.0 / tan_t
	var fab_brittle := 1.0
	if not tooth:
		var d_mm := float(tool_d.grain_um) / 1000.0
		n = maxf(float(geom.engaged) * w_mm * l_mm / (d_mm * d_mm), 1.0)
		f = force_n / n
		# grano esfero-cónico; al deslizar carga solo la mitad delantera del contacto
		var a := sqrt(2.0 * f / (PI * h_mpa))
		var grain := Contact.tip_geometry(PI * tip_mm * tip_mm, th)
		h = Contact.depth_for_radius(grain, a)
		dp = h / a if a > 0.0 else 0.0
		k_cut = 2.0 / (PI * tan_t)
		g = minf(1.0, float(tool_d.grain_um) / float(CareData.CRITICAL_GRAIN_UM.value))
		fab_brittle = groove_area_ratio(grain, a, h)
	var ab := Abrasion.abrasion_mode(dp)
	out.merge({
		"elements": n, "forceN": f, "depthUm": h * 1000.0, "Dp": dp, "absMode": ab.absMode, "fab": ab.fab, "g": g,
		"kCut": k_cut, "k": k_cut * float(ab.fab) * g, "fabBrittle": fab_brittle,
	}, true)
	return out


## La sección del surco de un grano esfero-cónico (grain: Contact.tip_geometry) hundido h con el contacto de radio a, frente a
## la del cono afilado con el mismo contacto (a²/tan α, la que da K_corte): lo que arranca en régimen frágil, donde el surco
## se va entero (unidad 5l). 1 si el grano está afilado; menos con la punta más redonda (gastado): la cápsula esférica y el
## tronco de cono por encima, R²·acos((R − h)/R) − (R − h)·√(2Rh − h²) hasta la tangencia y 2·a_t·(h − h_t) + tan α·(h − h_t)²
## desde ahí (geometría).
static func groove_area_ratio(grain: Dictionary, a: float, h: float) -> float:
	var t := float(grain.tanA)
	if not (a > 0.0) or not (h > 0.0) or t <= 0.0:
		return 0.0
	var r := float(grain.R)
	var ht := float(grain.ht)
	var at := float(grain.at)
	var area := 0.0
	if h <= ht:
		area = r * r * _acos((r - h) / r) - (r - h) * sqrt(maxf(2.0 * r * h - h * h, 0.0))
	else:
		area = r * r * _acos((r - ht) / r) - (r - ht) * at + 2.0 * at * (h - ht) + t * (h - ht) * (h - ht)
	return clampf(area / (a * a / t), 0.0, 1.0)


## acos con la atan2 de V8 (la de la libm cambia de una plataforma a otra): acos(x) = atan2(√((1 − x)·(1 + x)), x).
static func _acos(x: float) -> float:
	var c := clampf(x, -1.0, 1.0)
	return V8.js_atan2(sqrt(maxf((1.0 - c) * (1.0 + c), 0.0)), c)


## Hondura (µm) de los surcos que deja la herramienta, la que da la rugosidad (pass_ra_um): la del rayado de cada grano
## (element_cut) o, en una lima de dientes, la de cada diente suelto. Para el arranque, cada fila de dientes cepilla una capa
## del ancho del contacto (element_cut); para la rugosidad cuenta el surco de cada diente: en una lima de picado doble, como
## las de taller, el segundo picado parte las aristas en dientes sueltos, ~(teeth_cm)² por cm², y cada uno raya como un grano
## de la geometría del diente (CareData.TOOTH_GEOMETRY), con la fuerza repartida entre todos los del contacto.
static func groove_um(tool_d: Dictionary, force_n: float, w_mm: float, l_mm: float, h_mpa: float) -> float:
	if String(tool_d.get("element", "grano")) != "diente":
		return float(element_cut(tool_d, force_n, w_mm, l_mm, h_mpa).depthUm)
	if force_n <= 0.0 or h_mpa <= 0.0 or w_mm <= 0.0 or l_mm <= 0.0 or float(tool_d.get("teeth_cm", 0.0)) <= 0.0:
		return 0.0
	var pitch := 10.0 / float(tool_d.teeth_cm)
	var f := force_n / maxf(w_mm * l_mm / (pitch * pitch), 1.0)
	var tip_mm := _tip_um(tool_d) / 1000.0
	var tooth := Contact.tip_geometry(PI * tip_mm * tip_mm, float(CareData.TOOTH_GEOMETRY.half_angle_deg))
	return Contact.depth_for_radius(tooth, sqrt(2.0 * f / (PI * h_mpa))) * 1000.0


## Radio (µm) de la arista del diente o de la punta del grano de esta herramienta: el de su geometría (nueva) o, si se ha
## gastado, el de sus filos redondeados (tip_um, de ClawCareKit.worn_tool; unidad 5l).
static func _tip_um(tool_d: Dictionary) -> float:
	if tool_d.has("tip_um"):
		return float(tool_d.tip_um)
	return float((CareData.TOOTH_GEOMETRY if String(tool_d.get("element", "grano")) == "diente" else CareData.GRAIN_GEOMETRY).tip_um)


## Volumen arrancado (mm³) con la fuerza force_n a lo largo de travel_mm: η·K·F·L/H (Archard). claw_hv: dureza de la garra
## (la de la queratina de la ficha o la del material reforjado), para ver si la herramienta muerde (η). brittle: la pasada va
## en régimen frágil (un material frágil, con el surco más hondo que la hondura crítica de Bifano; unidad 5l): el surco se
## arranca entero, sin el arado de Hokkirigawa y Kato: lo que se desplaza se rompe y se va en vez de quedarse a los lados
## (Bifano et al. 1991); el del grano, con la sección de su punta (groove_area_ratio: uno gastado arranca menos); el de un
## diente, la capa entera. Es una cota baja: las grietas laterales (Evans y Marshall 1981) arrancarían algo más.
static func removal_mm3(tool_d: Dictionary, force_n: float, travel_mm: float, w_mm: float, l_mm: float, claw_hv: float, h_mpa: float, brittle: bool = false) -> float:
	if travel_mm <= 0.0:
		return 0.0
	var eta := Contact.hardness_efficiency(float(tool_d.get("tool_hv", 0.0)) / claw_hv) if claw_hv > 0.0 else 1.0
	if eta <= 0.0:
		return 0.0
	var ec := element_cut(tool_d, force_n, w_mm, l_mm, h_mpa)
	# en régimen frágil, nunca menos que lo que arrancaría cortando (el arado de Hokkirigawa y Kato): lo que se rompe se suma
	var k := float(ec.kCut) * maxf(float(ec.fab), float(ec.fabBrittle)) * float(ec.g) if brittle else float(ec.k)
	return eta * k * force_n * travel_mm / h_mpa


# ──────── Cómo trabaja cada herramienta según la dureza (unidad 5l; CareData.TOOL_WEAR, RUB_FRICTION, CLIP_FORCE) ────────

## Desde qué razón de durezas ρ = H_garra/H_herramienta empieza a gastarse la herramienta (CareData.TOOL_WEAR.onset): por
## debajo, la garra cede antes de deformar sus filos.
static func wear_onset_ratio() -> float:
	return float(CareData.TOOL_WEAR.onset.value)


## Coeficiente de desgaste (Archard, adimensional) de la herramienta contra un material ρ = H_garra/H_herramienta veces más
## duro que ella (Pintaude 2009; CareData.TOOL_WEAR): 0 por debajo de wear_onset_ratio(); sube hasta el suave (k_mild) en la
## r = 0,8 del banco (Richardson 1968) y de ahí al severo (k_severe) con la curva del banco (Contact.hardness_efficiency). No
## baja nunca al subir ρ.
static func tool_wear_k(rho: float) -> float:
	var on := wear_onset_ratio()
	if not (rho > on):
		return 0.0
	var k_mild := float(CareData.TOOL_WEAR.k_mild.value)
	var k_sev := float(CareData.TOOL_WEAR.k_severe.value)
	var r_off := float(Contact.CONTACT.rOff)
	if rho < r_off:
		return k_mild * Contact.smoothstep(on, r_off, rho)
	return k_mild + (k_sev - k_mild) * Contact.hardness_efficiency(rho)


## Volumen (mm³) que pierde la herramienta al deslizar slid_mm apretada con force_n contra un material de claw_hv (HV):
## K(ρ)·F·L/H_herramienta (Archard con la razón de durezas al revés).
static func tool_wear_mm3(tool_d: Dictionary, force_n: float, slid_mm: float, claw_hv: float) -> float:
	var t_hv := float(tool_d.get("tool_hv", 0.0))
	if t_hv <= 0.0 or claw_hv <= 0.0 or not (slid_mm > 0.0) or not (force_n > 0.0):
		return 0.0
	return tool_wear_k(claw_hv / t_hv) * force_n * slid_mm / (t_hv * Contact.HV_MPA)


## El rozamiento de la herramienta cuando roza sin morder contra un material de mat_hv (HV): con el diamante, el suyo; la
## lima de acero, la del acero sobre una cerámica; el corindón, la de una cerámica dura sobre otra (CareData.RUB_FRICTION).
static func rub_mu(tool_d: Dictionary, mat_hv: float) -> float:
	return float(CareData.RUB_FRICTION[_rub_key(tool_d, mat_hv)].value)


## El rozamiento que hace el calor de una pasada (μ de P = ε·μ·F·v): el del amolado mientras la herramienta muerde
## (CareData.THERMAL.friction), el de la pareja si roza sin morder (rub_mu) y, entre los dos, según lo que muerde: la carga
## que llevan los filos que cortan, η, y la que roza, 1 − η (suposición del modelo). En la queratina, que todo lo muerde, el
## del amolado de siempre.
static func friction_mu(tool_d: Dictionary, mat_hv: float) -> float:
	var t_hv := float(tool_d.get("tool_hv", 0.0))
	var eta := Contact.hardness_efficiency(t_hv / mat_hv) if mat_hv > 0.0 else 1.0
	var mu_cut := float(CareData.THERMAL.friction.value)
	if eta >= 1.0:
		return mu_cut
	return eta * mu_cut + (1.0 - eta) * rub_mu(tool_d, mat_hv)


## Lo que da un cortaúñas en el filo (N): la fuerza de la mano por su palanca (CareData.CLIP_FORCE).
static func clip_capacity_n(tool_d: Dictionary) -> float:
	return float(CareData.CLIP_FORCE.hand_n.value) * float(tool_d.get("lever", 1.0))


## La resistencia a cortadura (MPa) del material del sitio m ({ reforged, hv, e, inlay }) para un cortaúñas: τ = σ/√3 en un
## dúctil (la tensión de flujo de un metal, H/2,8, o la resistencia de la queratina a su humedad: von Mises) y τ = σ en un
## frágil (su resistencia a flexión). 0 sin datos (no se sabe: no se le pone tope de fuerza).
static func shear_strength_mpa(m: Dictionary, humidity: String) -> float:
	if not bool(m.get("reforged", false)):
		return float(CareData.keratin(humidity).sigma_mpa) / sqrt(3.0)
	var inl: Variant = m.get("inlay", null)
	if ClawFracture.behavior(inl) == "fragil":
		var b: Variant = ClawFracture.strength(inl)
		return float(b.value) if b != null else 0.0
	var st: Variant = _strength_of(inl)
	return float(st.value) / sqrt(3.0) if st != null else 0.0


## Una fuerza legible: «540 N» o, desde 1000 N, «2.2 kN».
static func force_text(f: float) -> String:
	return ("%s kN" % Js.to_fixed(f / 1000.0, 1)) if f >= 1000.0 else ("%s N" % Format.fmt_f(f))


## La fuerza (N) que pide cortar entera la sección de radio r_mm del material del sitio m: τ·π·r².
static func clip_force_n(m: Dictionary, humidity: String, r_mm: float) -> float:
	return shear_strength_mpa(m, humidity) * PI * r_mm * r_mm


## Lo que sale de una pasada que arranca mm3 (para la escena; CareData.DEBRIS_COLOR): { kind («polvo» | «limaduras» |
## «virutas»), name, material, color, colorSource, colorQuality («dibujo»), sizeUm (el grueso de la viruta: la hondura del
## surco de cada filo), mm3, sparks (la firma de core/taller/sparks.gd de lo que chispea si la herramienta gira; «» si no),
## settleMs y dragPerS (cómo cae en el aire una partícula del grueso de la viruta: la ley de Stokes, CareData.SRC_STOKES; para
## el polvo de los frágiles, de micras: las limaduras y las virutas son láminas y caen antes), density (kg/m³) }.
## La queratina da polvo del color de su garra; los metales, limaduras; los frágiles, polvo; el acrílico, virutas.
static func debris_for(m: Dictionary, depth_um: float, mm3: float, keratin_color: String) -> Dictionary:
	var id := String((m.get("inlay", {}) as Dictionary).get("id", "none")) if bool(m.get("reforged", false)) else "none"
	var kind := "polvo"
	var nm := "polvo de queratina"
	var col := keratin_color
	var src := "dibujo: el color de la queratina de la garra (ClawOptics.KERATIN_COLORS)"
	if id != "none":
		var beh := ClawFracture.behavior(m.inlay)
		if beh == "ductil":
			kind = "limaduras"
			nm = "limaduras de " + String(ClawFracture.NOUNS.get(id, id))
		elif id == "acrilico":
			kind = "virutas"
			nm = "virutas de acrílico"
		else:
			nm = "polvo de " + String(ClawFracture.NOUNS.get(id, id))
		var dc: Array = CareData.DEBRIS_COLOR.get(id, [String((m.inlay as Dictionary).get("col", "#C7CDD6")), "dibujo: el color del material"])
		col = String(dc[0])
		src = String(dc[1])
	# cómo cae (Stokes): k = 18·μ/(ρ·d²), con d el grueso de la viruta (al menos una décima de micra) y la densidad del material
	var rho := float(CareData.ClawMass.DENSITY.get(id, {}).get("value", (m.get("inlay", {}) as Dictionary).get("density", CareData.KERATIN_DENSITY)))
	var d := maxf(depth_um, 0.1) * 1.0e-6
	var k := 18.0 * float(CareData.AIR_VISCOSITY.value) / (rho * d * d)
	return {
		"kind": kind, "name": nm, "material": id, "color": col, "colorSource": src, "colorQuality": "dibujo",
		"sizeUm": maxf(depth_um, 0.0), "mm3": maxf(mm3, 0.0), "sparks": String(CareData.SPARK_MATERIAL.get(id, "")),
		"density": rho, "dragPerS": k, "settleMs": 9.81 / k, "settleSource": CareData.SRC_STOKES + "; " + String(CareData.AIR_VISCOSITY.source),
	}


## Longitud (mm) que raja por delante la cuña de un cortaúñas: la de una viga doble en voladizo con la apertura impuesta
## Δ, a = (3·E·h³·Δ²/(16·J))^¼ (h: medio espesor de la garra, el radio; J: tenacidad a lo largo).
static func split_length_mm(e_gpa: float, half_mm: float, wedge_mm: float, j_kj_m2: float) -> float:
	if j_kj_m2 <= 0.0 or wedge_mm <= 0.0 or half_mm <= 0.0:
		return 0.0
	var e := e_gpa * 1.0e9
	var h := half_mm / 1000.0
	var w := wedge_mm / 1000.0
	var j := j_kj_m2 * 1000.0
	var x := 3.0 * e * h * h * h * w * w / (16.0 * j)
	return sqrt(sqrt(x)) * 1000.0


## Energía de pelado (kJ/m² = N/mm) de una pasada en contra de las capas: la fuerza de roce por unidad de ancho que tira
## del borde de las láminas, μ·F/w.
static func peel_energy_kj_m2(mu: float, force_n: float, w_mm: float) -> float:
	return mu * force_n / w_mm if w_mm > 0.0 else 0.0


## Tenacidad entre capas (kJ/m²) de la queratina en ese estado de humedad.
static func interlaminar_kj_m2(humidity: String) -> float:
	return float(CareData.keratin(humidity).j_lat) * float(CareData.INTERLAMINAR.value)


## Velocidad (m/s) de la superficie de un tambor de diámetro drum_mm a rpm: π·D·n/60.
static func surface_speed_ms(drum_mm: float, rpm: float) -> float:
	return PI * drum_mm / 1000.0 * rpm / 60.0


## Segundos a una temperatura (°C) hasta la lesión del tejido (Moritz & Henriques 1947), interpolando el logaritmo del
## tiempo entre las filas de la tabla; INF por debajo de 44 °C.
static func injury_time_s(t_c: float) -> float:
	var tab: Array = CareData.INJURY_TABLE
	if t_c < float(tab[0][0]):
		return INF
	for i in range(tab.size() - 1):
		var t0: float = tab[i][0]
		var t1: float = tab[i + 1][0]
		if t_c <= t1:
			var u := (t_c - t0) / (t1 - t0)
			return V8.js_exp(V8.js_log(float(tab[i][1])) * (1.0 - u) + V8.js_log(float(tab[i + 1][1])) * u)
	# más allá de 70 °C: la misma pendiente del último tramo
	var n := tab.size()
	var slope := (V8.js_log(float(tab[n - 1][1])) - V8.js_log(float(tab[n - 2][1]))) / (float(tab[n - 1][0]) - float(tab[n - 2][0]))
	return V8.js_exp(V8.js_log(float(tab[n - 1][1])) + slope * (t_c - float(tab[n - 1][0])))


## Dolor (0-1) de la carne viva a esa temperatura: 0 hasta el umbral y 1 a 50 °C (índice pedagógico).
static func heat_pain(t_c: float) -> float:
	var p0: float = CareData.THERMAL.pain_c.value
	var p1: float = CareData.PAIN.heat_full_c
	return Contact.clamp_js((t_c - p0) / (p1 - p0), 0.0, 1.0)


## Resistencia de la punta de queratina para claw_sharpness.gd: { value, min, max, kind («flexion» frágil | «fluencia»
## dúctil), kic: null, quality, source }; una garra reforjada, la de su material (claw_fracture.gd).
static func keratin_strength(humidity: String) -> Dictionary:
	var k: Dictionary = CareData.keratin(humidity)
	var s: float = k.sigma_mpa
	return {
		"value": s, "min": s, "max": s, "kind": "fluencia" if bool(k.ductile) else "flexion", "kic": null,
		"family": "queratina", "quality": k.quality, "source": String(k.source),
	}


## Tenacidad de la queratina (MPa·√m) en un estado de humedad, para la distancia crítica de Taylor de la prueba de la punta:
## K_c = √(E·J), con el módulo de la garra de avestruz (Taylor et al. 2004) y el trabajo de rotura de lado de la uña (Farran
## et al. 2008), el de una grieta que cruza la punta. { value, quality: «estimate», source }.
static func keratin_toughness(humidity: String) -> Dictionary:
	var k: Dictionary = CareData.keratin(humidity)
	var kic := sqrt(float(k.e_gpa) * 1.0e9 * float(k.j_lat) * 1000.0) / 1.0e6
	return {
		"value": kic, "quality": "estimate",
		"source": "estimación: K_c = √(E·J) (la relación de la mecánica de la fractura elástica, G = K²/E) con el módulo de " + CareData.SRC_TAYLOR + " y el trabajo de rotura de lado de " + CareData.SRC_FARRAN + "; el trabajo de rotura incluye lo que la queratina se deforma, así que es una cota alta",
	}


## La resistencia de la punta de queratina (keratin_strength) con su tenacidad (keratin_toughness): la que usa la prueba de
## la punta para la distancia crítica de Taylor.
static func keratin_strength_k(humidity: String) -> Dictionary:
	var st := keratin_strength(humidity)
	st["kic"] = float(keratin_toughness(humidity).value)
	return st


## Carga de lado (N) que aguanta la punta de radio r_um y semiángulo alpha_deg con esa resistencia, empujada a x0_mm del
## vértice. Crece con R²: una punta más fina nunca aguanta más.
static func lateral_capacity_n(r_um: float, alpha_deg: float, strength: Dictionary, x0_mm: float = 0.0) -> float:
	return ClawSharpness.chip_load_n(ClawSharpness.tip_of(r_um, alpha_deg), float(strength.value), x0_mm)


# ════════════════════════════════ Acciones ════════════════════════════════

## Una pasada (o un tramo de pasada) con una lima o el torno. p:
##   tool (TOOLS: lima_* , lija_* o «torno»), zone («punta» | «flanco»), angle_deg (semiángulo de la faceta con el eje de
##   la garra en la punta; ≥ 80°: de frente), at_mm (flanco: distancia desde la punta al centro del contacto), length_mm
##   (flanco: largo del contacto, 3 mm por defecto), force_n, travel_mm y speed_mm_s (lo que desliza la lima y a qué
##   velocidad, 100 mm/s por defecto; el torno: dwell_s y rpm), direction («a_favor»: de la base a la punta ·
##   «en_contra» · «vaiven»). El torno trabaja a trozos de ROTARY_CHUNK_S: arranca, calienta y vuelve a arrancar.
## Devuelve { tool, removedMm3, k, Dp, absMode, peeled, chipped, flattened, bled, noBite, heatW (potencia que entra en
## la garra), raUm (la rugosidad que queda donde ha pasado: la que deja donde quita, pass_ra_um de la hondura de los surcos,
## groove_um; si no ha quitado nada, la de antes, porque la superficie no cambia) }; y desde la unidad 5l: rubbing (roza sin
## morder: una giratoria calienta igual), mu (el rozamiento del calor: friction_mu), regime («frágil» si el surco pasa de la
## hondura crítica de Bifano en un material frágil; si no, «dúctil»), toolEdgeUm (el radio de los filos con el que ha
## trabajado), toolWearMm3 (lo que ha perdido la herramienta), toolState (cómo queda: ClawCareKit.state) y debris (lo que
## sale: debris_for).
func file(p: Dictionary) -> Dictionary:
	var tool_d := CareData.tool(String(p.get("tool", "lima_fina")))
	if not tool_d.is_empty():
		_note_handling()
	if not tool_d.is_empty() and String(tool_d.kind) == "torno":
		var total := int(floor(maxf(float(p.get("dwell_s", 1.0)), 0.0) / DT + 1e-9))
		var chunk := maxi(int(round(ROTARY_CHUNK_S / DT)), 1)
		if total > chunk:
			var acc := {}
			var done := 0
			while done < total:
				var q := p.duplicate()
				var steps := mini(chunk, total - done)
				q["dwell_s"] = float(steps) * DT
				var r := _file_once(q, tool_d)
				if acc.is_empty():
					acc = r
				else:
					acc["removedMm3"] = float(acc.removedMm3) + float(r.removedMm3)
					acc["toolWearMm3"] = float(acc.get("toolWearMm3", 0.0)) + float(r.get("toolWearMm3", 0.0))
					for key: String in ["peeled", "chipped", "flattened", "bled", "noBite", "rubbing"]:
						acc[key] = bool(acc.get(key, false)) or bool(r.get(key, false))
					for key: String in ["k", "Dp", "absMode", "heatW", "raUm", "mu", "regime", "toolEdgeUm", "toolState"]:
						if r.has(key):
							acc[key] = r[key]
					if r.has("debris"):
						var db: Dictionary = (r.debris as Dictionary).duplicate()
						db["mm3"] = float(acc.removedMm3)
						acc["debris"] = db
				done += steps
			return acc
	return _file_once(p, tool_d)


func _file_once(p: Dictionary, tool_d: Dictionary) -> Dictionary:
	var out := { "tool": String(tool_d.get("id", "")), "removedMm3": 0.0, "k": 0.0, "Dp": 0.0, "absMode": "arado", "peeled": false, "chipped": false, "flattened": false, "bled": false, "noBite": false, "heatW": 0.0, "raUm": 0.0,
		"rubbing": false, "mu": 0.0, "regime": "dúctil", "toolEdgeUm": 0.0, "toolWearMm3": 0.0 }
	if tool_d.is_empty() or not (String(tool_d.kind) in ["lima", "torno"]):
		return out
	_tools_used[String(tool_d.id)] = true
	_cur_tool = String(tool_d.id)
	# la herramienta como está (unidad 5l): con los filos que haya redondeado lo que ya ha limado (el kit del ensayo)
	var tool_w := _kit.worn_tool(tool_d)
	out["toolEdgeUm"] = _tip_um(tool_w)
	var rotary := String(tool_d.kind) == "torno"
	var force := maxf(float(p.get("force_n", 3.0)), 0.0)
	var dt := 0.0
	var travel := 0.0
	var speed := 0.0
	if rotary:
		dt = maxf(float(p.get("dwell_s", 1.0)), 0.0)
		var rpm := maxf(float(p.get("rpm", tool_d.rpm)), 0.0)
		speed = surface_speed_ms(float(tool_d.drum_mm), rpm)
		travel = speed * 1000.0 * dt
		_rpm_max[String(tool_d.id)] = maxf(float(_rpm_max.get(String(tool_d.id), 0.0)), rpm)
	else:
		travel = maxf(float(p.get("travel_mm", 30.0)), 0.0)
		speed = maxf(float(p.get("speed_mm_s", 100.0)), 1.0) / 1000.0
		dt = travel / (speed * 1000.0)
	var direction := String(p.get("direction", "a_favor"))
	if not (direction in ["a_favor", "en_contra", "vaiven"]):
		direction = "a_favor"
	_directions[direction] = true
	var zone := "flanco" if String(p.get("zone", "punta")) == "flanco" else "punta"
	var angle := Contact.clamp_js(float(p.get("angle_deg", 90.0)), 1.0, 90.0)
	# el material que se lima: el del sitio del contacto (la queratina, la garra reforjada o el bloque en bruto, _mat_at)
	var m: Dictionary = {}
	var h := 0.0
	var mu: float = CareData.THERMAL.friction.value
	var edge := _edge_um(tool_w)
	# una lima de dientes solo corta al empujar: en vaivén, la mitad del recorrido no arranca (Nicholson)
	var cut_travel := travel * (0.5 if direction == "vaiven" and String(tool_d.element) == "diente" else 1.0)
	var pain := 0.0
	var heat_len := HEAT_ZONE_MM
	var s_heat := _s_apex
	var touching := true
	# el ancho del contacto (la tira de la cara de la herramienta que lo recorre: por donde se reparte su desgaste), la hondura
	# del surco de cada filo y la estación donde trabaja (la rugosidad que queda si no quita nada)
	var strip := 0.0
	var groove_d := 0.0
	var s_ra := _s_apex
	if zone == "flanco":
		var at := maxf(float(p.get("at_mm", 3.0)), 0.0)
		var len_mm := maxf(float(p.get("length_mm", 3.0)), STATION_MM)
		if at > _s_apex + 0.5 * len_mm:
			return out
		var s_mid := clampf(_s_apex - at, 0.0, _s_apex)
		var s_a := maxf(s_mid - 0.5 * len_mm, 0.0)
		var s_b := minf(s_mid + 0.5 * len_mm, _s_apex)
		# la unión de una pieza sobre el muñón (unidad 5o): mientras la pieza sobresale, la herramienta se apoya en ella y no llega
		# a la queratina de debajo del escalón (repartir lo arrancado por igual a los dos lados agrandaba el escalón con una pieza
		# más dura que la queratina)
		if _block_from > s_a and _block_from < s_b and radius_at(_block_from + STATION_MM) - radius_at(_block_from - STATION_MM) > JOINT_LEVEL_MM:
			# desde la primera estación de la pieza (la de debajo de la unión es de la queratina)
			s_a = (floor(_block_from / STATION_MM) + 1.0) * STATION_MM + 1e-6
		if s_b <= s_a:
			return out
		var w := 2.0 * maxf(radius_at(s_mid), 0.05)
		m = _mat_at(s_mid)
		h = hardness_mpa(float(m.hv), _humidity, bool(m.reforged))
		_flank_contact_mm2 = w * maxf(s_b - s_a, STATION_MM)
		_th_flank_a = s_a
		_th_flank_b = s_b
		# donde ya no queda garra, la herramienta no toca nada: ni arranca ni calienta
		touching = _has_material(s_a, s_b)
		var ec := element_cut(tool_w, force, w, maxf(s_b - s_a, STATION_MM), h)
		var groove := groove_um(tool_w, force, w, maxf(s_b - s_a, STATION_MM), h)
		var brittle := _brittle_regime(groove, m)
		var dv := removal_mm3(tool_w, force, cut_travel, w, maxf(s_b - s_a, STATION_MM), float(m.hv), h, brittle)
		out.merge({ "k": ec.k, "Dp": ec.Dp, "absMode": ec.absMode, "noBite": _bites(tool_d, float(m.hv)) <= 0.0 and cut_travel > 0.0 and force > 0.0, "raUm": pass_ra_um(groove),
			"regime": "frágil" if brittle else "dúctil" }, true)
		strip = w
		groove_d = groove
		s_ra = s_mid
		var r_before := _r.duplicate()
		var r := _thin_flank(s_a, s_b, dv, direction, edge)
		out["removedMm3"] = r.removed
		if float(r.removed) > 0.0:
			_surface_pass(r_before, groove, angle if rotary else 0.0, false, m)
		if bool(r.bled):
			out["bled"] = true
			pain = maxf(pain, float(CareData.PAIN.quick_cut))
		out["peeled"] = _peel_check(direction, mu, force, w, s_a, s_b, bool(m.reforged))
		s_heat = minf(s_mid, _s_apex)
	else:
		var w_tip := 2.0 * maxf(radius_at(_s_apex - 1.0), 0.1)
		m = _mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0))
		h = hardness_mpa(float(m.hv), _humidity, bool(m.reforged))
		var ec := element_cut(tool_w, force, w_tip, w_tip, h)
		var groove2 := groove_um(tool_w, force, w_tip, w_tip, h)
		var brittle2 := _brittle_regime(groove2, m)
		var dv := removal_mm3(tool_w, force, cut_travel, w_tip, w_tip, float(m.hv), h, brittle2)
		out.merge({ "k": ec.k, "Dp": ec.Dp, "absMode": ec.absMode, "noBite": _bites(tool_d, float(m.hv)) <= 0.0 and cut_travel > 0.0 and force > 0.0, "raUm": pass_ra_um(groove2),
			"regime": "frágil" if brittle2 else "dúctil" }, true)
		strip = w_tip
		groove_d = groove2
		var r_before2 := _r.duplicate()
		var r2: Dictionary
		if angle >= TRUNCATE_DEG:
			r2 = _truncate_volume(dv, edge)
			r2["facet_len"] = 0.0
		elif angle <= _tip_alpha + 1.0:
			# la lima va más tumbada que el flanco de la punta: adelgaza los flancos de los últimos milímetros
			r2 = _thin_flank(maxf(_s_apex - 3.0, 0.0), _s_apex, dv, direction, edge)
			r2["facet_len"] = minf(3.0, _s_apex)
		else:
			r2 = _facet(angle, dv, edge)
		out["removedMm3"] = r2.removed
		if float(r2.removed) > 0.0:
			# la superficie: lo limado a lo largo (la lima, a lo largo de la garra; el tambor, al ángulo de la mano) y, de frente,
			# la cara nueva, rayada de través
			_surface_pass(r_before2, groove2, angle if rotary else 0.0, angle >= TRUNCATE_DEG, m)
		heat_len = maxf(float(r2.facet_len), HEAT_ZONE_MM)
		if bool(r2.bled):
			out["bled"] = true
			pain = maxf(pain, float(CareData.PAIN.quick_cut))
		out["peeled"] = _peel_check(direction, mu, force, w_tip, maxf(_s_apex - 2.0, 0.0), _s_apex, bool(m.reforged))
		if angle < TRUNCATE_DEG and dv > 0.0:
			var ch := _chip_check(mu * force, float(r2.facet_len))
			out["chipped"] = ch.chipped
			out["flattened"] = ch.flattened
			if bool(ch.bled):
				out["bled"] = true
				pain = maxf(pain, float(CareData.PAIN.quick_split))
		s_heat = _s_apex
	_last_mat = m
	var mat_name := String(m.inlay.name).to_lower() if bool(m.reforged) else "queratina"
	if bool(out.noBite):
		_no_bite = true
		if not _no_bite_tools.has(String(tool_d.id)):
			_no_bite_tools[String(tool_d.id)] = true
			_event("no_muerde", "%s no muerde la garra de %s: la herramienta tiene que ser más dura que lo que lima." % [String(tool_d.name), mat_name], CareData.SRC_FILE_TEST)
	# si no ha quitado nada, la superficie no cambia: la rugosidad que queda es la de antes (unidad 5l)
	if not (float(out.removedMm3) > 0.0):
		out["raUm"] = _ra_at(s_ra)
	# la herramienta se gasta con todo lo que desliza apretada contra lo que hay (unidad 5l): Archard con la razón de durezas al
	# revés; donde ya no queda garra no toca nada
	out["rubbing"] = bool(out.noBite) and touching
	var dv_t := tool_wear_mm3(tool_d, force, travel, float(m.hv)) if touching else 0.0
	out["toolWearMm3"] = dv_t
	_kit.add(tool_d, dv_t, strip, travel if touching else 0.0, travel if bool(out.rubbing) else 0.0)
	var ts := _kit.state(tool_d)
	out["toolState"] = ts
	if String(ts.state) == "gastada" and _kit.flag_dull(String(tool_d.id)):
		_event("herramienta_gastada", "%s se ha %s contra la garra de %s: sus filos han pasado de %s a %s µm de radio y corta mucho menos. Coge una nueva de la bandeja." % [
			String(tool_d.name), "embotado" if String(ts.look) == "dientes" else "vidriado", mat_name, Js.to_fixed(float(ts.edgeNewUm), 0),
			Js.to_fixed(float(ts.edgeUm), 1)], String(CareData.TOOL_WEAR.k_mild.source))
	# calor de la herramienta giratoria (P = ε·μ·F·v) durante el tiempo de contacto, también si roza sin morder (con el
	# rozamiento de la pareja: friction_mu); a mano, despreciable (CareData.THERMAL.hand)
	var mu_heat := friction_mu(tool_d, float(m.hv))
	out["mu"] = mu_heat
	var p_in := heat_power_w(force, speed, -1.0, mu_heat) if rotary and touching else 0.0
	out["heatW"] = p_in
	if rotary and bool(out.rubbing) and p_in > 0.0 and not _rub_tools.has(String(tool_d.id)):
		_rub_tools[String(tool_d.id)] = true
		_event("roce", "%s roza la garra de %s sin morderla: no arranca nada, pero calienta (%s W) y se gasta." % [
			String(tool_d.name), mat_name, Js.to_fixed(p_in, 2)], String(CareData.RUB_FRICTION[_rub_key(tool_d, float(m.hv))].source) + "; " + CareData.SRC_DREMEL_GUIDE)
	# lo que sale de la pasada (para la escena): polvo, limaduras o virutas, del color del material
	out["debris"] = debris_for(m, groove_d, float(out.removedMm3), String(_claw.get("col", "#6B5A45")))
	var th_pain := _run(dt, p_in, zone, s_heat, heat_len)
	pain = maxf(pain, th_pain)
	_refresh_chip()
	_react(pain)
	_serial += 1
	return out


## La rugosidad (Ra, µm) de la superficie en s (mm desde la base): la de su estación.
func _ra_at(s: float) -> float:
	if _n <= 0:
		return _ra0
	return _sra[clampi(int(floor(s / STATION_MM)), 0, mini(int(floor(_s_apex / STATION_MM)), _n - 1))]


## La fila de CareData.RUB_FRICTION de una herramienta que roza un material de mat_hv (la que usa rub_mu).
static func _rub_key(tool_d: Dictionary, mat_hv: float) -> String:
	if float(tool_d.get("tool_hv", 0.0)) >= 10000.0 or mat_hv >= 10000.0:
		return "diamante"
	return "acero" if String(tool_d.get("element", "grano")) == "diente" else "ceramica"


## ¿Queda garra entre s_a y s_b (mm desde la base)? Si no, la herramienta pasa por donde ya no hay nada que tocar.
func _has_material(s_a: float, s_b: float) -> bool:
	for i in range(maxi(int(floor(s_a / STATION_MM)), 0), mini(int(ceil(s_b / STATION_MM)), _n - 1) + 1):
		if _r[i] > 0.0:
			return true
	return false


## Radio (µm) de la arista del diente o de la punta del grano: el de la punta que deja la herramienta (gastada, más roma;
## unidad 5l).
static func _edge_um(tool_d: Dictionary) -> float:
	return _tip_um(tool_d)


## Corta con un cortaúñas: { tool: «guillotina» | «tijera» | «tenaza», remove_mm (lo que se corta desde la punta) }.
## Devuelve { tool, cut, reason, splitMm, reachesQuick, crushed, bled } y, desde la unidad 5l, forceN (la que pide cortar la
## sección entera: clip_force_n) y capacityN (la que da el cortaúñas: la mano por su palanca, clip_capacity_n). Si no
## llega, no corta, y lo dice.
func clip(p: Dictionary) -> Dictionary:
	var tool_d := CareData.tool(String(p.get("tool", "guillotina")))
	var out := { "tool": String(tool_d.get("id", "")), "cut": false, "reason": "", "splitMm": 0.0, "reachesQuick": false, "crushed": false, "bled": false,
		"forceN": 0.0, "capacityN": 0.0 }
	if tool_d.is_empty() or String(tool_d.kind) != "cortaunas":
		out["reason"] = "no es un cortaúñas"
		return out
	_note_handling()
	_tools_used[String(tool_d.id)] = true
	_cur_tool = String(tool_d.id)
	var s_cut := _s_apex - maxf(float(p.get("remove_mm", 1.0)), 0.0)
	if s_cut >= _s_apex:
		return out
	s_cut = maxf(s_cut, 0.0)
	var r := radius_at(s_cut)
	if 2.0 * r > float(tool_d.jaw_mm):
		out["reason"] = "la garra (%s mm) no cabe en %s (%s mm)" % [Js.to_fixed(2.0 * r, 1), String(tool_d.name).to_lower(), Js.to_fixed(float(tool_d.jaw_mm), 0)]
		_event("no_cabe", "La garra no cabe en " + String(tool_d.name).to_lower() + ": hacen falta unas tenazas más grandes (las de herrador, en un tigre).", CareData.SRC_CATTALES)
		return out
	# el material del corte: la queratina, la garra reforjada o el bloque en bruto (_mat_at)
	var mc := _mat_at(s_cut)
	if bool(mc.reforged) and Contact.hardness_efficiency(BLADE_HV / float(mc.hv)) <= 0.0:
		out["reason"] = "la hoja de acero no corta la garra de " + String(mc.inlay.name).to_lower()
		_no_bite = true
		_event("no_corta", "La hoja del cortaúñas no corta la garra de %s: es más dura que el acero." % String(mc.inlay.name).to_lower(), CareData.SRC_FILE_TEST)
		return out
	# la fuerza (unidad 5l): cortar la sección entera pide τ·A; el cortaúñas da la mano por su palanca
	var need := clip_force_n(mc, _humidity, r)
	var have := clip_capacity_n(tool_d)
	out["forceN"] = need
	out["capacityN"] = have
	if need > have:
		var what := String(mc.inlay.name).to_lower() if bool(mc.reforged) else "queratina"
		out["reason"] = "cortar %s mm de %s pide ~%s y %s da ~%s" % [Js.to_fixed(2.0 * r, 1), what, force_text(need), String(tool_d.name).to_lower(), force_text(have)]
		_event("no_corta_fuerza", "%s no puede con la garra de %s de %s mm: cortarla pide ~%s (su resistencia a cortadura por la sección) y la mano, por su palanca de ×%s, da ~%s. Hace falta una cizalla, o limarla." % [
			String(tool_d.name), what, Js.to_fixed(2.0 * r, 1), force_text(need), Js.to_fixed(float(tool_d.get("lever", 1.0)), 1), force_text(have)],
			String(CareData.CLIP_FORCE.shear.source) + "; " + String(CareData.CLIP_FORCE.hand_n.source) + "; " + String(CareData.CLIP_FORCE.lever.source))
		_idle_run(0.5)
		_serial += 1
		return out
	out["cut"] = true
	var pain := 0.0
	var old_apex := _s_apex
	var piece := _piece_profile(s_cut, old_apex)
	var bled := _cut_to(s_cut)
	_note_break("corte", s_cut, s_cut, old_apex, bled, piece, String(tool_d.source))
	if bled:
		out["bled"] = true
		pain = float(CareData.PAIN.quick_cut)
	# la cuña raja a lo largo por delante de la hoja
	var k: Dictionary = CareData.keratin(_humidity)
	var e := float(mc.e) if bool(mc.reforged) else float(k.e_gpa)
	var j := float(k.j_long)
	if bool(mc.reforged):
		var st: Variant = _strength_of(mc.inlay)
		j = 0.0 if st == null or st.get("kic") == null else float(st.kic) * float(st.kic) / (float(mc.e) * 1000.0) * 1000.0
	var a := split_length_mm(e, r, float(tool_d.wedge_mm), j) if j > 0.0 else 0.0
	out["splitMm"] = a
	if a > 0.0:
		var to_s := maxf(s_cut - a, 0.0)
		var reaches := not _reforged and to_s <= _s_quick and s_cut > _s_quick
		_splits.append({ "from_s": to_s, "to_s": s_cut, "reaches_quick": reaches, "tool": String(tool_d.id) })
		_note_break("raja_carne" if reaches else "raja", to_s, to_s, s_cut, reaches, {}, CareData.SRC_FARRAN)
		if reaches:
			out["reachesQuick"] = true
			_broken = true
			var c_split := core_at(_s_quick - 0.5 * minf(a, _s_quick))
			_open_bleed(PI * c_split * c_split)
			pain = maxf(pain, float(CareData.PAIN.quick_split))
			_event("raja", "El corte raja la garra a lo largo %s mm y llega a la carne viva: garra rota." % Js.to_fixed(a, 1), CareData.SRC_FARRAN)
		else:
			_event("grieta", "El corte deja una grieta a lo largo de %s mm." % Js.to_fixed(a, 1), CareData.SRC_FARRAN)
	# aplastamiento del tejido vivo cercano
	var gap := s_cut - _s_quick
	if not bool(mc.reforged) and gap > 0.0 and gap < float(tool_d.crush_k) * r:
		out["crushed"] = true
		pain = maxf(pain, float(CareData.PAIN.quick_crush))
		# en una garra oscura la carne viva no se ve: el aviso no dice a qué distancia está
		var where := ("a %s mm de la carne viva" % Js.to_fixed(gap, 1)) if bool(_animal.quick_visible) else "muy cerca de la carne viva"
		_event("aplasta", "Corte %s: la hoja la aprieta y duele." % where, String(tool_d.source))
	_idle_run(0.5)
	_refresh_chip()
	_react(pain)
	_serial += 1
	return out


## Hemostasia: { tool: «hemostatico» | «nitrato_plata» | «» (solo presión), pressure_s }. Pasa el tiempo de la presión.
## Devuelve { stopped, needS, heldS }.
func hemostasis(p: Dictionary) -> Dictionary:
	var tid := String(p.get("tool", ""))
	var tool_d := CareData.tool(tid)
	var agent := not tool_d.is_empty() and String(tool_d.kind) == "hemostatico"
	var secs := maxf(float(p.get("pressure_s", 30.0)), 0.0)
	_note_handling()
	if agent:
		_tools_used[tid] = true
		_agent_used = tid
	var pain := float(tool_d.get("pain", 0.0)) if agent and _bleeding else 0.0
	if _bleeding:
		_press_t += secs
		if agent:
			_agent_t += secs
	var need := _hemostasis_need()
	_idle_run(secs)
	if _bleeding and (_agent_t >= float(CareData.HEMOSTASIS.agent_s.value) or _press_t >= float(CareData.HEMOSTASIS.pressure_s.value)):
		_stop_bleed(true)
	_react(pain)
	_serial += 1
	# lo que lleva y lo que hace falta con lo que se está usando (el hemostático cuenta su tiempo; la gasa, toda la presión)
	var with_agent := _agent_used != ""
	var goal_s := float(CareData.HEMOSTASIS.agent_s.value if with_agent else CareData.HEMOSTASIS.pressure_s.value)
	return { "stopped": not _bleeding, "needS": need, "heldS": _press_t, "agent": with_agent,
		"doneS": minf(_agent_t if with_agent else _press_t, goal_s), "goalS": goal_s }


## Antiséptico, crema o reconstrucción: { tool: «clorhexidina» | «crema» | «metacrilato» }.
func apply(p: Dictionary) -> Dictionary:
	var tid := String(p.get("tool", ""))
	var tool_d := CareData.tool(tid)
	if tool_d.is_empty():
		return { "ok": false }
	_note_handling()
	_tools_used[tid] = true
	match String(tool_d.kind):
		"antiseptico":
			_disinfected = true
		"crema":
			_cream = true
		"reparacion":
			if _bleeding:
				return { "ok": false, "reason": "primero hay que parar la sangre" }
			if _broken or _quick_cut or _wall_through:
				_repaired = true
				_event("reconstruida", "Garra reconstruida con metacrilato y bicarbonato: provisional, hasta que crezca.", String(tool_d.source))
	_serial += 1
	return { "ok": true }


## Probar la punta (unidad 5g; lo pidió la 5b): apoyar el vértice en una uña (la «Uña ajena» del banco: 25 HV, 2,9 GPa y
## μ = 0,3) y pasarlo de lado con un toque ligero, como se prueba un filo en la uña. Carga el VÉRTICE (x0 = 0) y no la mitad
## de la faceta, como una pasada de lima: así una punta de aguja se mella.
##   - ¿Prende? La uña empieza a ceder bajo la punta cuando la presión de Hertz pasa de 1,6·H/2,8 (Johnson 1985,
##     ClawSharpness.yield_onset_n): esa fuerza crece con R², y con el toque una punta afilada la marca y una roma resbala.
##   - ¿Aguanta? La carga de lado μ·F en el vértice contra la que aguanta la punta (ClawSharpness.evaluate, la viga en
##     voladizo de claw_fracture.gd), que crece con R² (Pattrick et al. 2018). Frágil, se mella (ClawFracture
##     .broken_length_mm); mojada y dúctil, se aplasta.
##   - La distancia crítica de Taylor (2007), L = (K_c/σ)²/π, dice si la resistencia medida vale a esa escala. En la
##     queratina (K_c = √(E·J), keratin_toughness) L es de ~1-1,5 mm, más que la sección más cargada de una punta (décimas
##     de milímetro): el modelo se queda del lado seguro y la punta real aguantaría algo más (sizeEffect).
## p: { force_n (por defecto PROBE_FORCE_N) }. Devuelve { tool («una»), forceN, lateralN, tipRadiusUm, alphaDeg, yieldN
##   (la fuerza desde la que marca la uña), catches, depthUm, chipN, chipMinN, chipMaxN, chipped, flattened, lostMm,
##   criticalUm, sizeEffect, bled, verdict («prende» | «resbala» | «mella» | «aplasta» | «sin_datos»), text, source }.
func probe_tip(p: Dictionary = {}) -> Dictionary:
	var target: Dictionary = Catalog.find_by_id(Catalog.TARGETS, PROBE_TARGET)
	var force := maxf(float(p.get("force_n", PROBE_FORCE_N)), 0.0)
	var mu := float(target.mu)
	var lateral := mu * force
	var out := {
		"tool": PROBE_TARGET, "forceN": force, "lateralN": lateral, "tipRadiusUm": tip_radius_um(), "alphaDeg": _tip_alpha,
		"yieldN": null, "catches": false, "depthUm": 0.0, "chipN": null, "chipMinN": null, "chipMaxN": null, "chipped": false,
		"flattened": false, "lostMm": 0.0, "criticalUm": null, "sizeEffect": false, "bled": false, "verdict": "sin_datos",
		"text": "", "source": PROBE_SOURCE,
	}
	if _s_apex <= 0.0:
		out["text"] = "No queda garra que probar."
		return out
	_note_handling()
	_cur_tool = PROBE_TARGET
	var r_um := tip_radius_um()
	var tip := tip_geometry()
	# ¿marca la uña? (el contacto elástico de Hertz del banco, con el módulo de la garra o de su material)
	var m_tip := _mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0))
	var e_claw := float(m_tip.e) if bool(m_tip.reforged) else float(CareData.keratin(_humidity).e_gpa)
	var y_n := ClawSharpness.yield_onset_n(r_um, e_claw, float(target.E), float(target.hv) * Contact.HV_MPA)
	out["yieldN"] = y_n
	out["catches"] = force >= y_n
	if bool(out.catches):
		out["depthUm"] = ClawSharpness.plastic_depth_um(r_um, _tip_alpha, force, float(target.hv) * Contact.HV_MPA)
	# ¿aguanta la carga de lado en el vértice?
	var st: Variant = _tip_strength(_humidity, true)
	var pain := 0.0
	if st != null:
		var ev := ClawSharpness.evaluate(tip, st, lateral, 0.0)
		out.merge({ "chipN": ev.chipN, "chipMinN": ev.chipMinN, "chipMaxN": ev.chipMaxN, "criticalUm": ev.criticalUm,
			"sizeEffect": ev.sizeEffect }, true)
		if bool(ev.breaks):
			var lost := maxf(ClawFracture.broken_length_mm(tip, _s_apex, float(st.value), lateral, 0.0), float(ev.peakXUm) / 1000.0)
			_chips += 1
			out["chipped"] = true
			out["lostMm"] = minf(lost, _s_apex)
			out["verdict"] = "mella"
			out["text"] = "La punta se mella al probarla: aguanta de lado ~%s y el toque le da ~%s; se desprenden %s mm." % [
				Format.fmt_small_force(float(ev.chipN)), Format.fmt_small_force(lateral), Js.to_fixed(float(out.lostMm), 2)]
			_event("mella", out.text, ClawSharpness.SRC_PATTRICK)
			out["bled"] = _break_off(_s_apex - lost, ClawSharpness.SRC_PATTRICK)
			if bool(out.bled):
				_broken = true
				pain = float(CareData.PAIN.quick_split)
		elif bool(ev.bends):
			_flattened += 1
			out["flattened"] = true
			out["verdict"] = "aplasta"
			_flat_r = maxf(_flat_r, float(ev.peakRUm) / 1000.0)
			# la queratina mojada o un metal dúctil: se dobla en vez de mellarse (el texto, del material de la punta)
			var why := "tan fina, el metal cede" if bool(_mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0)).reforged) else "blanda y mojada"
			out["text"] = "La punta, %s, se dobla al probarla: aguanta de lado ~%s y el toque le da ~%s." % [
				why, Format.fmt_small_force(float(ev.chipN)), Format.fmt_small_force(lateral)]
			_event("aplasta_punta", out.text, String(st.source))
	if String(out.verdict) == "sin_datos" or String(out.verdict) == "":
		if st == null:
			out["text"] = "Sin datos de la resistencia de este material: no se sabe si la punta aguanta."
		elif bool(out.catches):
			out["verdict"] = "prende"
			out["text"] = "La punta prende en la uña (la marca desde ~%s y el toque es de %s) y aguanta de lado ~%s: afilada y entera." % [
				Format.fmt_small_force(y_n), Format.fmt_small_force(force), Format.fmt_small_force(float(out.chipN))]
		else:
			out["verdict"] = "resbala"
			out["text"] = "La punta resbala por la uña: con un toque de %s no la marca (haría falta ~%s). Está roma." % [
				Format.fmt_small_force(force), Format.fmt_small_force(y_n)]
	if bool(out.sizeEffect) and String(out.verdict) in ["mella", "prende"]:
		out["text"] = String(out.text) + " (La punta es más fina que la distancia crítica del material, ~%s mm: aguantaría algo más.)" % Js.to_fixed(float(out.criticalUm) / 1000.0, 1)
	_event("prueba", String(out.text), PROBE_SOURCE)
	_idle_run(PROBE_S)
	_react(pain)
	_serial += 1
	return out


## Deja pasar el tiempo sin tocar la garra (enfría, sangra si no se ha parado, el animal se cansa o descansa).
func advance(seconds: float) -> void:
	_patient.idle = true
	_idle_run(maxf(seconds, 0.0))
	_patient.idle = false
	_serial += 1


## Lo mismo mientras se le coge la garra con una herramienta (un gesto en marcha de ClawCareState): el animal se está
## manejando y ese tiempo le suma estrés (claw_care_patient.gd, gripped). Es su propia llamada para que repetir las llamadas
## de un ensayo dé el mismo animal.
func advance_held(seconds: float) -> void:
	var was := _patient.gripped
	_patient.gripped = true
	advance(seconds)
	_patient.gripped = was


## El calor que desprende el acrílico al fraguar (unidad 5o; ClawCareBond.heat_between): p { w (W, la potencia media),
## secs (s), len_mm (el alto de las capas que aún fraguan, por donde entra el calor) }. Entra en el modelo térmico de la garra
## por la cara de arriba del bloque (la punta), como el calor del torno: la carne viva se calienta, duele y se lesiona con el
## mismo modelo. { quickC, peakQuickC, faceC, pain }.
func exotherm(p: Dictionary) -> Dictionary:
	var secs := maxf(float(p.get("secs", 0.0)), 0.0)
	var w := maxf(float(p.get("w", 0.0)), 0.0)
	var heat_len := clampf(float(p.get("len_mm", HEAT_ZONE_MM)), STATION_MM, maxf(_s_apex, STATION_MM))
	var pain := _run(secs, w, "punta", _s_apex, heat_len)
	_react(pain)
	_serial += 1
	return { "quickC": _quick_c, "peakQuickC": _peak_quick_c, "faceC": _face_c, "pain": pain }


## Una capa más del bloque (unidad 5o: el acrílico o la resina, capa a capa): p { h_mm }. El bloque crece h_mm hacia la
## punta, con su radio en bruto; lo que ya había (el muñón y las capas de antes) no cambia. Solo con un bloque que se
## construye a capas (block.built_mm). { ok, builtMm, apexMm }.
func grow_block(p: Dictionary) -> Dictionary:
	var h := maxf(float(p.get("h_mm", 0.0)), 0.0)
	if _block_from == INF or not is_finite(_block_built) or h <= 0.0:
		return { "ok": false, "builtMm": _block_built, "apexMm": _s_apex }
	var keep_r := _r.duplicate()
	var keep_core := _core.duplicate()
	var keep_n := _n
	var removed := _removed_mm3
	var keep_ra := _sra.duplicate()
	_block_built += h
	_build_profile()
	var below := int(floor(_block_from / STATION_MM - 1e-9))
	for i in mini(mini(below + 1, keep_n), _n):
		_r[i] = keep_r[i]
		_core[i] = keep_core[i]
	_removed_mm3 = removed
	_sra.resize(_n)
	_sburn.resize(_n)
	_schipd.resize(_n)
	_sscr.resize(_n)
	_schip.resize(_n)
	for i in _n:
		_sra[i] = keep_ra[i] if i < keep_ra.size() and float(i) * STATION_MM < _block_from - 1e-9 else float(CareData.SURFACE.raw_ra_um.value)
	_serial += 1
	return { "ok": true, "builtMm": _block_built, "apexMm": _s_apex }


## ¿Muerde la herramienta esta garra (o el material del sitio, hv)? η de la dureza (0: no muerde; 1: del todo).
func _bites(tool_d: Dictionary, hv: float = -1.0) -> float:
	var h := hv if hv > 0.0 else _hv
	return Contact.hardness_efficiency(float(tool_d.get("tool_hv", 0.0)) / h) if h > 0.0 else 1.0


## Todo el tiempo que ha sangrado esta garra en el ensayo (s): la sangre que pierde el animal (unidad 5o).
func bleed_total_s() -> float:
	return _bleed_total


## El material en s (mm desde la base), para explicar en la interfaz lo que muerde y lo que no (unidad 5o, la claridad de las
## limas): { reforged, hv, name } (la queratina, la garra reforjada o el bloque) y bites(tool_id): la eficacia de esa
## herramienta ahí (Contact.hardness_efficiency de la razón de durezas, la misma que usa file(); 0 = no muerde).
func material_at(s: float) -> Dictionary:
	var m := _mat_at(s)
	var nm := "queratina"
	if bool(m.reforged) and m.inlay is Dictionary:
		nm = String((m.inlay as Dictionary).get("name", "")).to_lower()
	return { "reforged": bool(m.reforged), "hv": float(m.hv), "name": nm }


func bites_at(tool_id: String, s: float) -> float:
	var td := CareData.tool(tool_id)
	if td.is_empty() or not td.has("tool_hv"):
		return 0.0
	return _bites(td, float(_mat_at(s).hv))


## El material en s (mm desde la base): { reforged, hv, e, inlay }. La queratina de la garra o el de la garra reforjada
## entera; desde _block_from, el del bloque en bruto pegado al muñón (petición 35).
func _mat_at(s: float) -> Dictionary:
	if _block_from < INF and s >= _block_from - 1e-9:
		return { "reforged": true, "hv": float(_block.hv), "e": float(_block.E), "inlay": _block }
	return { "reforged": _reforged, "hv": _hv, "e": _e_gpa, "inlay": _inlay }


## (5v) ¿Está rota la garra (o atravesada su pared) y está reconstruida? { broken, repaired }, sin hacer la instantánea.
func broken_state() -> Dictionary:
	return { "broken": _broken or _wall_through, "repaired": _repaired }


## (cierre de la 5s) El material de la punta: { reforged, id, name, behavior («queratina», «ductil», «fragil» o «sin_datos»:
## ClawFracture.behavior, o el tipo de su resistencia en los de la reforja), strength (la de _tip_strength, o null), hv }.
func tip_material() -> Dictionary:
	var m := _mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0))
	var st: Variant = _tip_strength("natural")
	var inl: Dictionary = m.inlay
	var beh := "queratina"
	if bool(m.reforged):
		beh = ClawFracture.behavior(inl)
		if beh == "":
			beh = "sin_datos" if st == null else ("fragil" if String((st as Dictionary).get("kind", "")) == "flexion" else "ductil")
	return { "reforged": bool(m.reforged), "id": String(inl.get("id", "none")), "name": String(inl.get("name", "queratina")),
		"behavior": beh, "strength": st, "hv": float(m.hv) }


## La resistencia de la punta (la del material de la punta: la queratina en un estado de humedad, o el material reforjado o
## el del bloque; _strength_of). keratin_k: la de la queratina con su tenacidad (keratin_strength_k).
func _tip_strength(humidity: String, keratin_k: bool = false) -> Variant:
	var m := _mat_at(maxf(_s_apex - 0.5 * STATION_MM, 0.0))
	if bool(m.reforged):
		return _strength_of(m.inlay)
	return keratin_strength_k(humidity) if keratin_k else keratin_strength(humidity)


# ════════════════════════════════ Geometría de las acciones ════════════════════════════════

# ════════════════════════════════ Superficie (petición 37) ════════════════════════════════

## La superficie de partida: la rugosidad de la garra natural, la de una reforjada pulida o la que digan los ajustes
## (surface_ra_um: la de la reforja, un bloque en bruto…); sin quemar, sin desconchones y con el rayado a lo largo.
func _reset_surface(s: Dictionary) -> void:
	_ra0 = float(CareData.SURFACE.polished_ra_um.value if _reforged else CareData.SURFACE.natural_ra_um.value)
	if s.has("surface_ra_um") and float(s.surface_ra_um) > 0.0:
		_ra0 = float(s.surface_ra_um)
	# (los Packed*Array son valores: se redimensiona cada uno, no una copia)
	_sra.resize(_n)
	_sburn.resize(_n)
	_schipd.resize(_n)
	_sscr.resize(_n)
	_schip.resize(_n)
	_sra.fill(_ra0)
	_sburn.fill(0.0)
	_schipd.fill(0.0)
	_sscr.fill(0.0)
	_schip.fill(0.0)
	# el bloque en bruto (petición 35), con la rugosidad de una pieza sin tallar (CareData.SURFACE.raw_ra_um)
	if _block_from < INF:
		for i in _n:
			if float(i) * STATION_MM >= _block_from - 1e-9:
				_sra[i] = float(CareData.SURFACE.raw_ra_um.value)


## Rugosidad (Ra, µm) que deja una pasada cuyos dientes o granos rayan depth_um de hondura: Ra = h/4 (CareData.SURFACE).
static func pass_ra_um(depth_um: float) -> float:
	return float(CareData.SURFACE.ra_per_depth.value) * maxf(depth_um, 0.0)


## La rugosidad (Ra, µm) que queda en una estación que tenía ra después de una pasada que deja ra_t y quita dz_um de hondura
## (CareData.SURFACE): una herramienta más gruesa (ra_t ≥ ra) la deja con la suya enseguida; una más fina la pule hacia la
## suya a medida que quita, y los surcos de antes se van del todo cuando ha quitado su hondura (clear_per_ra·Ra = 4·Ra). Sin
## quitar nada (dz_um = 0), no cambia. Nunca queda por debajo de la de la herramienta ni por encima de la mayor de las dos.
static func next_ra(ra: float, ra_t: float, dz_um: float) -> float:
	if not (dz_um > 0.0):
		return ra
	if ra_t >= ra:
		return ra_t
	return ra_t + (ra - ra_t) * maxf(1.0 - dz_um / (float(CareData.SURFACE.clear_per_ra.value) * ra), 0.0)


## Hondura crítica del régimen dúctil (µm) de un material frágil, d_c = 0,15·(E/H)·(K_c/H)² (Bifano et al. 1991; la misma
## fórmula y la misma constante que ClawForge.ductile_depth_um): por debajo, el grano arranca sin desconchar; por encima,
## desconcha.
static func ductile_depth_um(e_gpa: float, hv: float, kic: float) -> float:
	var h := hv * Contact.HV_MPA * 1.0e6
	var e := e_gpa * 1.0e9
	var q := kic * 1.0e6 / h
	return float(ForgeData.DUCTILE_REGIME_K.value) * (e / h) * q * q * 1.0e6


## Hondura (mm) de los desconchones que deja una pasada que raya depth_um: la de los surcos si la garra es de un material
## frágil reforjado y la pasada va en régimen frágil (más hondo que d_c de Bifano); 0 si no (la queratina y los metales se
## liman en régimen dúctil: d_c de la queratina pasa de 100 µm).
func _brittle_chip_mm(depth_um: float, m: Dictionary = {}) -> float:
	return depth_um / 1000.0 if _brittle_regime(depth_um, m) else 0.0


## ¿Va en régimen frágil una pasada cuyos filos rayan depth_um en el material m? Si es frágil (ClawFracture) y el surco pasa
## de la hondura crítica de Bifano, d_c = 0,15·(E/H)·(K_c/H)² (ductile_depth_um): entonces desconcha y el surco se arranca
## entero (removal_mm3 con brittle). La queratina y los metales, nunca.
func _brittle_regime(depth_um: float, m: Dictionary = {}) -> bool:
	var mat := m if not m.is_empty() else _mat_at(0.0)
	if not bool(mat.reforged) or ClawFracture.behavior(mat.inlay) != "fragil":
		return false
	var st: Variant = ClawFracture.strength(mat.inlay)
	if st == null or st.get("kic") == null:
		return false
	return depth_um > ductile_depth_um(float(mat.e), float(mat.hv), float(st.kic))


## Después de una pasada: en cada estación donde se ha quitado material (dz = lo que ha perdido de radio), la rugosidad va
## hacia la de la herramienta. Una más gruesa la raya enseguida; una más fina la pule a medida que quita, y los surcos de
## antes desaparecen cuando ha quitado su hondura (4·Ra). Donde no se ha quitado nada, no cambia. Lo quemado se va al quitar
## su capa; una pasada en régimen frágil desconcha. face: la pasada ha cortado de frente la cara de la punta (una superficie
## nueva, rayada de través).
func _surface_pass(r_before: PackedFloat64Array, depth_um: float, scratch_deg: float, face: bool, m: Dictionary = {}) -> void:
	var ra_t := pass_ra_um(depth_um)
	var burn_d := float(CareData.SURFACE.burn_depth_mm.value)
	var chip_d := _brittle_chip_mm(depth_um, m)
	var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	for i in range(0, i_top + 1):
		var dz := r_before[i] - _r[i]
		if not (dz > 0.0):
			continue
		_sra[i] = next_ra(_sra[i], ra_t, dz * 1000.0)
		_sscr[i] = scratch_deg
		_sburn[i] = _sburn[i] * maxf(1.0 - dz / burn_d, 0.0)
		_schipd[i] = maxf(maxf(_schipd[i] - dz, 0.0), chip_d)
	if face and i_top >= 0:
		_sra[i_top] = ra_t
		_sscr[i_top] = 90.0
		_sburn[i_top] = 0.0
		_schipd[i_top] = chip_d
	_refresh_chip()


## El quemado de la superficie, de la temperatura de cada nodo del modelo térmico: 0 por debajo de la desnaturalización de la
## queratina (CareData.THERMAL.char_c.min, ~215 °C) y 1 donde llega al tope del modelo (char_c, ~230 °C), donde se quema. En
## la punta, cada nodo a su sitio a lo largo de la garra; en el flanco, la cara del contacto. Solo sube.
func _surface_burn() -> void:
	var n := _th.size()
	if n == 0:
		return
	var onset := float(CareData.THERMAL.char_c.min)
	var full := float(CareData.THERMAL.char_c.value)
	var bed := float(CareData.THERMAL.bed_c.value)
	var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	var per := _th_capv.size() == n
	if _th_zone == "flanco":
		var f_on := onset
		var f_full := full
		if per and _th_isblk[n - 1] == 1:
			f_full = bed + _th_capv[n - 1]
			f_on = f_full - (full - onset)
		if not is_finite(f_full):
			return
		var bf := clampf((bed + _th[n - 1] - f_on) / (f_full - f_on), 0.0, 1.0)
		if bf > 0.0:
			for j in range(maxi(int(floor(_th_flank_a / STATION_MM)), 0), mini(int(ceil(_th_flank_b / STATION_MM)), i_top) + 1):
				_sburn[j] = maxf(_sburn[j], bf)
		return
	var last := n - 1
	for i in range(1, n):
		var t := bed + _th[i]
		var on_i := onset
		var full_i := full
		if per and _th_isblk[i] == 1:
			# en el bloque (unidad 5j), donde llega a su tope: se funde, se ablanda o se oxida
			full_i = bed + _th_capv[i]
			on_i = full_i - (full - onset)
		if t < on_i or not is_finite(full_i):
			continue
		var b := clampf((t - on_i) / (full_i - on_i), 0.0, 1.0)
		var s := _th_zone_s - float(last - i) * THERMAL_DX_MM
		for j in range(maxi(int(floor((s - 0.5 * THERMAL_DX_MM) / STATION_MM)), 0), mini(int(floor((s + 0.5 * THERMAL_DX_MM) / STATION_MM)), i_top) + 1):
			_sburn[j] = maxf(_sburn[j], b)


## Lo que se enseña como desconchón (0 o 1): los desconchones del régimen frágil y de las mellas, las escamas (deshojada) y
## las grietas abiertas.
func _refresh_chip() -> void:
	for i in _n:
		_schip[i] = 1.0 if _schipd[i] > 0.0 else 0.0
	for group: Array in [_peels, _splits]:
		for d: Dictionary in group:
			for i in range(maxi(int(floor(float(d.from_s) / STATION_MM)), 0), mini(int(ceil(float(d.to_s) / STATION_MM)), _n - 1) + 1):
				_schip[i] = 1.0


## La superficie para la escena y el material (petición 37; CONTRATOS.md): por estación de STATION_MM desde la base hasta
## la punta: ra_um, burn (0-1), chip (0 o 1) y scratch_deg (0-180°, respecto al eje de la garra).
func surface() -> Dictionary:
	var m := mini(int(floor(_s_apex / STATION_MM)), _n - 1) + 1
	return {
		"stationMm": STATION_MM, "lengthMm": _s_apex, "n": m, "ra_um": _sra.slice(0, m), "burn": _sburn.slice(0, m),
		"chip": _schip.slice(0, m), "scratch_deg": _sscr.slice(0, m), "raStartUm": _ra0, "quality": "estimate",
		"source": String(CareData.SURFACE.ra_per_depth.source),
	}


## La superficie como una lista de estaciones, de la base a la punta: [{ ra_um, burn, chip, scratch_deg }], la forma que lee
## la biblioteca de materiales de la 5e (ClawMaterial.surface_image). Lo mismo que surface(), sin física nueva; se pide
## cuando cambia la instantánea, no en cada fotograma.
func surface_stations() -> Array:
	var m := mini(int(floor(_s_apex / STATION_MM)), _n - 1) + 1
	var out: Array = []
	out.resize(m)
	for i in m:
		out[i] = { "ra_um": _sra[i], "burn": _sburn[i], "chip": _schip[i], "scratch_deg": _sscr[i] }
	return out


## La forma del trozo de garra entre from_s y to_s (mm desde la base), del perfil de ahora: { s, r } cada 0,5 mm y los dos
## extremos. Es la del trozo que se va al romperse o al cortarse (la escena lo separa y lo deja caer).
func _piece_profile(from_s: float, to_s: float) -> Dictionary:
	var ps := PackedFloat64Array()
	var pr := PackedFloat64Array()
	if to_s <= from_s:
		return { "s": ps, "r": pr }
	var s := from_s
	while s < to_s:
		ps.append(s)
		pr.append(radius_at(s))
		s += 0.5
	ps.append(to_s)
	pr.append(radius_at(to_s))
	return { "s": ps, "r": pr }


## Apunta una rotura con su sitio (petición 35, para la escena de la 5h): kind («mella»: se desprende la punta; «parte»: se
## parte la garra entera por la base; «corte»: el trozo que corta el cortaúñas; «raja» y «raja_carne»: una grieta a lo
## largo, que llega o no a la carne viva; «pared»: la herramienta atraviesa el estuche hasta la carne viva), s_mm (dónde se
## rompe, mm desde la base), el trozo que se va (de from_s a to_s, su largo y su forma, si se va) y si llega a la carne viva.
func _note_break(kind: String, s_mm: float, from_s: float, to_s: float, reaches_quick: bool, piece: Dictionary, source: String) -> void:
	var falls := kind in ["mella", "parte", "corte"]
	_breaks.append({
		"kind": kind, "sMm": s_mm, "pieceMm": maxf(to_s - from_s, 0.0) if falls else 0.0, "fromS": from_s, "toS": to_s,
		"reachesQuick": reaches_quick, "tS": time_s(), "tool": _cur_tool, "falls": falls,
		"profile": piece if falls else { "s": PackedFloat64Array(), "r": PackedFloat64Array() }, "source": source,
	})


## Se rompe la punta hasta s_new (mm desde la base): el trozo se va entero (una mella, o la garra entera si s_new llega a la
## base) y queda apuntado con su sitio y su forma. true si corta la carne viva.
func _break_off(s_new: float, source: String) -> bool:
	var s_cut := maxf(s_new, 0.0)
	var old_apex := _s_apex
	var piece := _piece_profile(s_cut, old_apex)
	var bled := _cut_to(s_cut)
	_note_break("parte" if s_cut <= 0.0 else "mella", s_cut, s_cut, old_apex, bled, piece, source)
	# la cara de la rotura es un desconchón (hasta que se lime una capa como la de una escama)
	var it := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	if it >= 0:
		_schipd[it] = maxf(_schipd[it], float(CareData.PEEL_DEPTH.value))
	_refresh_chip()
	return bled


## Corta la garra en s (una cara plana). edge_um: el radio de las esquinas que deja la herramienta (si limó ella; el
## cortaúñas y una mella no lo cambian). true si corta la carne viva.
func _cut_to(s_cut: float, edge_um: float = -1.0) -> bool:
	if s_cut >= _s_apex:
		return false
	# la cara del corte: el radio de la sección donde se corta (antes de borrar lo de más allá)
	var face := radius_at(s_cut) if s_cut > 0.0 else 0.0
	var i0 := int(floor(s_cut / STATION_MM)) + 1
	for i in range(maxi(i0, 0), _n):
		_removed_mm3 += PI * _r[i] * _r[i] * STATION_MM
		_r[i] = 0.0
	_s_apex = s_cut
	_flat_r = face
	if edge_um > 0.0:
		_point_um = edge_um
	# si el corte pasa de la faceta, la punta vuelve a tener el ángulo natural de la garra
	if s_cut <= _facet_back:
		_tip_alpha = _alpha
		_facet_deg = 0.0
		_facet_back = s_cut
	# las grietas que quedaban en lo cortado se van con ello
	_trim_damage(s_cut)
	if not _reforged and s_cut < _s_quick:
		if not _quick_cut:
			_event("carne_viva", "Corte en la carne viva a %s mm de su final: sangra." % Js.to_fixed(_s_quick - s_cut, 1), CareData.SRC_SAMOUR)
		_quick_cut = true
		_open_bleed(PI * core_at(s_cut) * core_at(s_cut))
		return true
	return false


## Lima de frente: acorta arrancando el volumen dv desde la punta. { removed, bled }.
func _truncate_volume(dv: float, edge_um: float) -> Dictionary:
	if dv <= 0.0:
		return { "removed": 0.0, "bled": false }
	var left := dv
	var s := _s_apex
	while left > 0.0 and s > 0.0:
		var a := PI * radius_at(s) * radius_at(s)
		var ds := minf(STATION_MM, s)
		var chunk := maxf(a, 1e-9) * ds
		if chunk >= left:
			s -= left / maxf(a, 1e-9)
			left = 0.0
		else:
			left -= chunk
			s -= ds
	var removed := dv - left
	var bled := _cut_to(maxf(s, 0.0), edge_um)
	return { "removed": removed, "bled": bled }


## Talla una faceta cónica de semiángulo theta (grados) arrancando el volumen dv. El cono tiene el vértice en sc (mm desde
## la base) y radio (sc − s)·tan θ hacia la base: con sc más allá de la punta deja una cara plana más pequeña; con sc
## dentro de la garra, la punta queda afilada y la garra más corta. Las esquinas y la punta quedan con el radio de la
## arista o del grano de la herramienta (edge_um). Los conos de un mismo ángulo están unos dentro de otros: limar dv de
## una vez o a trozos deja la misma forma. { removed, bled, facet_len }.
func _facet(theta: float, dv: float, edge_um: float) -> Dictionary:
	var t := V8.js_tan(theta * Contact.DEG)
	if dv <= 0.0 or t <= 0.0:
		return { "removed": 0.0, "bled": false, "facet_len": 0.0 }
	# sin arrancar nada: el cono solo roza el borde (el máximo de s + r/tan θ, con el borde de la cara plana)
	var hi := _s_apex + _flat_r / t
	var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	for i in range(maxi(i_top - int(ceil(_base_r / t / STATION_MM)) - 1, 0), i_top + 1):
		hi = maxf(hi, float(i) * STATION_MM + _r[i] / t)
	var lo := 0.0
	# V(sc) decrece con sc: se busca V(sc) = dv (acotando el volumen a lo que queda de garra)
	var v_lo := _facet_volume(lo, t)
	var target := minf(dv, v_lo)
	for it in 60:
		var mid := 0.5 * (lo + hi)
		if _facet_volume(mid, t) > target:
			lo = mid
		else:
			hi = mid
	var sc := hi
	var removed := _facet_volume(sc, t)
	var old_apex := _s_apex
	var old_flat := _flat_r
	# talla el perfil
	var back := _s_apex
	for i in range(maxi(int(floor((sc - _base_r / t) / STATION_MM)), 0), i_top + 1):
		var s := float(i) * STATION_MM
		var rc := (sc - s) * t
		if rc < _r[i]:
			back = minf(back, s)
			_r[i] = maxf(rc, 0.0)
	_removed_mm3 += removed
	var bled := false
	if removed > 0.0:
		_point_um = edge_um
	if sc <= old_apex:
		_flat_r = 0.0
		_s_apex = maxf(sc, 0.0)
		_trim_damage(_s_apex)
	else:
		_flat_r = minf(old_flat, (sc - old_apex) * t)
	if removed > 0.0:
		_tip_alpha = theta
		_facet_deg = theta
		_facet_back = minf(back, _s_apex)
	# la faceta no puede comerse la carne viva: si el vértice pasa de ella o el cono la corta de lado, sangra
	if not _reforged:
		if _s_apex < _s_quick:
			if not _quick_cut:
				_event("carne_viva", "La faceta llega a la carne viva: sangra.", CareData.SRC_SAMOUR)
			_quick_cut = true
			_open_bleed(PI * core_at(_s_apex) * core_at(_s_apex))
			bled = true
		else:
			for i in range(maxi(int(floor(back / STATION_MM)), 0), mini(int(floor(_s_quick / STATION_MM)), _n - 1) + 1):
				if _core[i] > 0.0 and _r[i] < _core[i]:
					bled = true
					if not _wall_through:
						_wall_through = true
						_open_bleed(PI * (_core[i] * _core[i] - _r[i] * _r[i]))
						_event("pared", "La faceta atraviesa el estuche y deja la carne viva al aire.", CareData.SRC_MSD)
						_note_break("pared", float(i) * STATION_MM, back, minf(_s_quick, _s_apex), true, {}, CareData.SRC_MSD)
					break
	return { "removed": removed, "bled": bled, "facet_len": maxf(minf(_s_apex, old_apex) - back, 0.0) }


## Volumen (mm³) que arrancaría un cono de faceta con el vértice en sc y tan θ = t. Solo miran las estaciones donde el cono
## es más estrecho que la base de la garra.
func _facet_volume(sc: float, t: float) -> float:
	var v := 0.0
	var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
	for i in range(maxi(int(floor((sc - _base_r / t) / STATION_MM)), 0), i_top + 1):
		var s := float(i) * STATION_MM
		var rc := maxf((sc - s) * t, 0.0)
		var ri := _r[i]
		if ri > rc:
			v += PI * (ri * ri - rc * rc) * STATION_MM
	return v


## Lo que había más allá de s ya no está: grietas y escamas se recortan.
func _trim_damage(s_cut: float) -> void:
	var keep: Array = []
	for sp: Dictionary in _splits:
		if float(sp.from_s) < s_cut:
			sp["to_s"] = minf(float(sp.to_s), s_cut)
			keep.append(sp)
	_splits = keep
	var kp: Array = []
	for pe: Dictionary in _peels:
		if float(pe.from_s) < s_cut:
			pe["to_s"] = minf(float(pe.to_s), s_cut)
			kp.append(pe)
	_peels = kp


## Adelgaza el flanco entre s_a y s_b arrancando dv: cada estación pierde la misma sección (la lima se reparte alrededor;
## simplificación: docs/fisica/cetreria.md §9). Si llega a la punta, la punta queda con el radio de la herramienta
## (edge_um) y retrocede donde ya no queda garra. { removed, bled }.
func _thin_flank(s_a: float, s_b: float, dv: float, direction: String, edge_um: float = -1.0) -> Dictionary:
	var i0 := int(floor(s_a / STATION_MM))
	var i1 := mini(int(ceil(s_b / STATION_MM)), _n - 1)
	var cnt := maxi(i1 - i0 + 1, 1)
	var da := dv / (float(cnt) * STATION_MM)
	var removed := 0.0
	var bled := false
	for i in range(maxi(i0, 0), i1 + 1):
		var r := _r[i]
		if r <= 0.0:
			continue
		var r_new := sqrt(maxf(r * r - da / PI, 0.0))
		removed += PI * (r * r - r_new * r_new) * STATION_MM
		if direction == "a_favor" and _peel_depth.size() == _n:
			_peel_depth[i] += r - r_new
		_r[i] = r_new
		if not _reforged and _core[i] > 0.0 and r_new < _core[i]:
			bled = true
	# la cara plana de la punta pierde la misma sección si el contacto llega a ella
	var at_tip := _s_apex <= s_b + STATION_MM
	if at_tip and _flat_r > 0.0:
		_flat_r = sqrt(maxf(_flat_r * _flat_r - da / PI, 0.0))
	if at_tip and removed > 0.0:
		if edge_um > 0.0:
			_point_um = edge_um
		# donde ya no queda garra, la punta retrocede
		var i_top := mini(int(floor(_s_apex / STATION_MM)), _n - 1)
		var j := i_top
		while j > 0 and _r[j] <= 0.0:
			j -= 1
		if j < i_top:
			_s_apex = float(j + 1) * STATION_MM if _r[j] > 0.0 else 0.0
			_flat_r = 0.0
			_trim_damage(_s_apex)
	_removed_mm3 += removed
	if bled and not _wall_through:
		_wall_through = true
		_open_bleed(PI * core_at(0.5 * (s_a + s_b)) * core_at(0.5 * (s_a + s_b)))
		_event("pared", "El flanco se ha limado hasta la carne viva: sangra.", CareData.SRC_MSD)
		_note_break("pared", 0.5 * (s_a + s_b), s_a, s_b, true, {}, CareData.SRC_MSD)
	_clear_peels()
	return { "removed": removed, "bled": bled }


## ¿Se deshojan las capas? En contra de las capas (o en vaivén) con μ·F/w por encima de la tenacidad entre capas.
func _peel_check(direction: String, mu: float, force: float, w: float, s_a: float, s_b: float, reforged: bool = false) -> bool:
	if direction == "a_favor" or _reforged or reforged:
		return false
	var g := peel_energy_kj_m2(mu, force, w)
	if g < interlaminar_kj_m2(_humidity):
		return false
	_peels.append({ "from_s": s_a, "to_s": s_b })
	# lo arrancado a favor desde aquí cuenta para quitar la escama
	for i in range(maxi(int(floor(s_a / STATION_MM)), 0), mini(int(ceil(s_b / STATION_MM)), _n - 1) + 1):
		_peel_depth[i] = 0.0
	_event("deshoja", "Limando en contra de las capas se levantan y se deshojan (μ·F/w = %s kJ/m², más que las %s kJ/m² entre capas)." % [Js.to_fixed(g, 2), Js.to_fixed(interlaminar_kj_m2(_humidity), 2)], CareData.SRC_FARRAN + "; " + CareData.SRC_AAD)
	return true


## Quita las escamas que ya se han limado a favor hasta su espesor.
func _clear_peels() -> void:
	if _peels.is_empty():
		return
	var need: float = CareData.PEEL_DEPTH.value
	var keep: Array = []
	for pe: Dictionary in _peels:
		var ok := true
		for i in range(maxi(int(floor(float(pe.from_s) / STATION_MM)), 0), mini(int(ceil(float(pe.to_s) / STATION_MM)), _n - 1) + 1):
			if _r[i] > 0.0 and _peel_depth[i] < need:
				ok = false
				break
		if not ok:
			keep.append(pe)
	_peels = keep


## ¿Se mella (frágil) o se aplasta (dúctil) la punta con la carga de lado de la pasada? La carga va al centro de la
## faceta. { chipped, flattened, bled }.
func _chip_check(lateral: float, facet_len: float) -> Dictionary:
	var out := { "chipped": false, "flattened": false, "bled": false }
	if lateral <= 0.0 or _s_apex <= 0.0:
		return out
	var st: Variant = _tip_strength(_humidity)
	if st == null:
		return out
	var tip := tip_geometry()
	var x0 := 0.5 * maxf(facet_len, 0.0)
	var ev := ClawSharpness.evaluate(tip, st, lateral, x0)
	if not bool(ev.fails):
		return out
	if bool(ev.breaks):
		var lost := ClawFracture.broken_length_mm(tip, _s_apex, float(st.value), lateral, x0)
		lost = maxf(lost, float(ev.peakXUm) / 1000.0)
		_chips += 1
		out["chipped"] = true
		_event("mella", "La punta se mella: se desprenden %s mm (la carga de lado pasa de lo que aguanta)." % Js.to_fixed(lost, 2), ClawSharpness.SRC_PATTRICK)
		out["bled"] = _break_off(maxf(_s_apex - lost, 0.0), ClawSharpness.SRC_PATTRICK)
		if bool(out.bled):
			_broken = true
	else:
		_flattened += 1
		out["flattened"] = true
		_flat_r = maxf(_flat_r, float(ev.peakRUm) / 1000.0)
		_event("aplasta_punta", "La punta, blanda y mojada, se dobla y se aplasta en vez de afilarse.", String(st.source))
	return out


# ════════════════════════════════ Sangre, calor y animal ════════════════════════════════

func _open_bleed(area_mm2: float) -> void:
	# cada herida nueva empieza su propia hemostasia: la presión y el hemostático de otra herida no cuentan
	_bleed_t = 0.0
	_press_t = 0.0
	_agent_t = 0.0
	_agent_used = ""
	_bleeding = true
	_bled = true
	_hemostasis_done = false
	_bleed_area = maxf(_bleed_area, area_mm2)


func _stop_bleed(by_hand: bool) -> void:
	_bleeding = false
	_hemostasis_done = by_hand or _hemostasis_done
	_event("para_sangre", "Ha parado de sangrar.", CareData.SRC_VCA)


## Segundos de presión que faltan para parar la sangre con lo que se está usando.
func _hemostasis_need() -> float:
	if not _bleeding:
		return 0.0
	if _agent_used != "":
		return maxf(float(CareData.HEMOSTASIS.agent_s.value) - _agent_t, 0.0)
	return maxf(float(CareData.HEMOSTASIS.pressure_s.value) - _press_t, 0.0)


## Avanza el tiempo secs con la potencia p_w (W) del torno entrando en la cara que se trabaja (zone, posición s;
## heat_len: largo de la punta por el que entra). Devuelve el dolor máximo por calor.
func _run(secs: float, p_w: float, zone: String, s_zone: float, heat_len: float = HEAT_ZONE_MM) -> float:
	var steps := int(floor(secs / DT + 1e-9))
	if secs > 0.0 and steps == 0:
		steps = 1
	_th_zone = zone
	_th_zone_s = s_zone
	_th_heat_len = heat_len
	var thermal := not _reforged
	if thermal:
		_thermal_setup(zone, s_zone, heat_len)
	var pain := 0.0
	var rate := _patient.stress_rate()
	for i in steps:
		# sin calor, sin sangre y con la garra fría, solo pasa el reloj del animal: de una vez (unidad 5o; el reloj a ×600 o
		# ×3600 para esperar a que cure un adhesivo). Da exactamente lo mismo que paso a paso.
		if p_w <= 0.0 and not _bleeding and (not thermal or (_k >= _th_frozen_to and _thermal_idle())):
			_fast_count(steps - i, rate)
			_k += steps - i
			break
		if thermal:
			if p_w > 0.0:
				_thermal_step(p_w, DT)
				_th_frozen_to = _k + 1
			elif _k >= _th_frozen_to and not _thermal_idle():
				# sin calor: a bloques alineados con el reloj (el resultado no depende de cómo se reparta el tiempo)
				if _k % COOL_BLOCK == 0:
					# el bloque entero, aunque acabe después de este avance: así no depende de cómo se reparta el tiempo
					_thermal_step(0.0, float(COOL_BLOCK) * DT)
					_th_frozen_to = _k + COOL_BLOCK
				else:
					_thermal_step(0.0, DT)
		pain = maxf(pain, heat_pain(_quick_c))
		if _quick_c >= float(CareData.THERMAL.pain_c.value):
			_heat_pain_s += DT
		var ti := injury_time_s(_quick_c)
		if is_finite(ti):
			# fracción del tiempo hasta la lesión; pasado 1 ya está lesionada (tope para que el número no crezca sin fin)
			_dose = minf(_dose + DT / ti, DOSE_CAP)
		if _bleeding:
			_bleed_t += DT
			_bleed_total += DT
			if _bleed_t >= float(CareData.HEMOSTASIS.none_s.value):
				_stop_bleed(false)
		# el estrés del tiempo sujeto, una sola vez por paso del reloj aunque el animal tenga varias garras
		_patient.count_step(_k + 1, rate, DT)
		_k += 1
	if _dose >= 1.0 and not _events.any(func(e: Dictionary) -> bool: return e.code == "quemadura"):
		_event("quemadura", "El calor ha llegado a la carne viva el tiempo suficiente para lesionarla.", CareData.SRC_MORITZ)
	if pain > 0.0 and not _events.any(func(e: Dictionary) -> bool: return e.code == "calor"):
		_event("calor", "El calor llega a la carne viva: pasa de ~43 °C y duele. Toques cortos con pausas.", CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_DUBIN)
	return pain


## n pasos del reloj sin nada más que el estrés del tiempo sujeto: paso a paso mientras sube (con el mismo redondeo que
## count_step) y, cuando ya no cambia (tope o sin sujeción que estrese), de una vez.
func _fast_count(n: int, rate: float) -> void:
	var step := maxi(_k + 1, _patient.k + 1)
	var last := _k + n
	if rate > 0.0 and _patient.accumulates():
		while step <= last and _patient.stress < 1.0:
			_patient.count_step(step, rate, DT)
			step += 1
	if last > _patient.k:
		_patient.count_step(last, 0.0, DT)


func _reset_thermal() -> void:
	var bed: float = CareData.THERMAL.bed_c.value
	_th = PackedFloat64Array()
	_th_c = PackedFloat64Array()
	_th_g = PackedFloat64Array()
	_th_h = PackedFloat64Array()
	_th_w = PackedFloat64Array()
	_th_live = 0
	_th_reach = false
	_th_frozen_to = 0
	_quick_c = bed
	_peak_quick_c = bed
	_face_c = bed
	_dose = 0.0
	_charred = false
	_block_hot = false
	_heat_pain_s = 0.0
	_th_zone = "punta"
	_th_zone_s = _s_apex
	_th_heat_len = HEAT_ZONE_MM


## Conductividad de la queratina (W/(m·K)): k = α·ρ·c (difusividad de la uña, densidad y calor específico de los datos).
static func keratin_conductivity() -> float:
	return float(CareData.THERMAL.diffusivity_m2_s.value) * CareData.KERATIN_DENSITY * float(CareData.THERMAL.specific_heat_j_kg_k.value)


## El calor de un material de bloque (unidad 5j; lo dejó la 5g), de su ficha de la reforja (ForgeData.MATERIALS y
## ForgeData.density_of): { k (W/(m·K)), rhoC (ρ·c, J/(m³·K)), alpha (k/ρc, m²/s), capC (°C: la temperatura más baja a la
## que se estropea en el aire, la de fundirse, ablandarse o degradarse; null si no tiene), capWhat (qué le pasa), capSource,
## quality (la peor de k y de c), source } o {} si la ficha no trae la conducción, el calor específico o la densidad (la
## hematites): entonces el bloque se cuenta como la queratina.
static func block_thermal(mat_id: String) -> Dictionary:
	var m := ForgeData.material(mat_id)
	var rho: Variant = ForgeData.density_of(mat_id)
	if m.is_empty() or m.get("k") == null or m.get("cp") == null or rho == null:
		return {}
	var k := float(m.k.value)
	var rho_c := float(rho) * float(m.cp.value)
	var rank := { "primary": 0, "secondary": 1, "estimate": 2 }
	var q := String(m.k.quality) if int(rank.get(String(m.k.quality), 2)) >= int(rank.get(String(m.cp.quality), 2)) else String(m.cp.quality)
	var out := { "k": k, "rhoC": rho_c, "alpha": k / rho_c, "capC": null, "capWhat": "", "capSource": "", "quality": q,
		"source": "conducción: %s; calor específico: %s" % [String(m.k.source), String(m.cp.source)] }
	var words := { "melt_c": "se funde", "soften_c": "se ablanda", "air_c": "se oxida al aire", "inert_c": "se degrada" }
	for key: String in ["melt_c", "soften_c", "air_c", "inert_c"]:
		if m.get(key) != null and (out.capC == null or float(m[key].value) < float(out.capC)):
			out["capC"] = float(m[key].value)
			out["capWhat"] = String(words[key])
			out["capSource"] = String(m[key].source)
	return out


## Potencia (W) del roce que entra en la garra: ε·μ·F·v.
static func heat_power_w(force_n: float, speed_ms: float, partition: float = -1.0, mu: float = -1.0) -> float:
	var eps := partition if partition >= 0.0 else float(CareData.THERMAL.partition.value)
	var m := mu if mu >= 0.0 else float(CareData.THERMAL.friction.value)
	return eps * m * maxf(force_n, 0.0) * maxf(speed_ms, 0.0)


## Distancia (mm) de la cara que se trabaja a la carne viva: a lo largo desde la punta; en el flanco, el espesor de la
## pared donde hay carne viva debajo, o la distancia en línea recta al final de la carne viva si se lima más allá.
func _thermal_depth(zone: String, s_zone: float) -> float:
	if zone == "flanco":
		if s_zone < _s_quick:
			return maxf(radius_at(s_zone) - core_at(s_zone), 0.0)
		var dx := s_zone - _s_quick
		var ry := radius_at(s_zone)
		return sqrt(dx * dx + ry * ry)
	return maxf(_s_apex - _s_quick, 0.0)


## Prepara el modelo térmico para la geometría de ahora. Nodos cada THERMAL_DX_MM desde el extremo vivo (la sangre, a la
## temperatura de partida: θ = 0) hasta la cara. En la punta, la sección de cada nodo es la de la garra en su sitio y
## pierde calor al aire por su contorno; el calor del torno entra en los nodos de los últimos heat_len mm, por volumen.
## En el flanco, una losa con el área del contacto a través de la pared; el calor entra por la cara. Si la carne viva
## queda más lejos que max_depth_mm, el extremo lejano es la garra a la temperatura de partida.
func _thermal_setup(zone: String, s_zone: float, heat_len: float) -> void:
	if not _block_th.is_empty():
		_thermal_setup_block(zone, s_zone, heat_len)
		return
	_th_capv.resize(0)
	_th_isblk.resize(0)
	var depth := _thermal_depth(zone, s_zone)
	var max_d: float = CareData.THERMAL.max_depth_mm.value
	var reach := depth <= max_d
	var n_live := int(round(float(CareData.THERMAL.live_mm.value) / THERMAL_DX_MM)) if reach else 0
	var n_ker := maxi(int(ceil(minf(depth, max_d) / THERMAL_DX_MM - 1e-9)), 1)
	var n := n_live + n_ker + 1
	if _th.size() != n or _th_reach != reach or _th_live != n_live:
		_resize_slab(n, n_live, reach)
	var k := keratin_conductivity()
	var rho_c: float = CareData.KERATIN_DENSITY * float(CareData.THERMAL.specific_heat_j_kg_k.value)
	var h_air: float = CareData.THERMAL.h_air.value
	var dx := THERMAL_DX_MM / 1000.0
	_th_c.resize(n)
	_th_g.resize(n)
	_th_h.resize(n)
	_th_w.resize(n)
	_th_cp.resize(n)
	_th_dp.resize(n)
	var last := n - 1
	if zone == "flanco":
		var a_c := maxf(_flank_contact_mm2, THERMAL_R_FLOOR_MM * THERMAL_R_FLOOR_MM * PI) * 1.0e-6
		for i in n:
			_th_c[i] = rho_c * a_c * dx * (0.5 if i == last else 1.0)
			_th_g[i] = k * a_c / dx if i < last else 0.0
			_th_h[i] = h_air * a_c if i == last else 0.0
			_th_w[i] = 1.0 if i == last else 0.0
		return
	var total := 0.0
	for i in n:
		var s := s_zone - float(last - i) * THERMAL_DX_MM
		var r := maxf(radius_at(s), THERMAL_R_FLOOR_MM) / 1000.0
		var half := 0.5 if i == last else 1.0
		var vol := PI * r * r * dx * half
		_th_c[i] = rho_c * vol
		if i < last:
			var rm := maxf(radius_at(s + 0.5 * THERMAL_DX_MM), THERMAL_R_FLOOR_MM) / 1000.0
			_th_g[i] = k * PI * rm * rm / dx
		else:
			_th_g[i] = 0.0
		_th_h[i] = h_air * (2.0 * PI * r * dx * half + (PI * r * r if i == last else 0.0))
		var w := vol if s >= s_zone - heat_len - 1e-9 and i > 0 else 0.0
		_th_w[i] = w
		total += w
	for i in n:
		_th_w[i] = _th_w[i] / total if total > 0.0 else (1.0 if i == last else 0.0)


## El modelo térmico con el bloque sobre el muñón (unidad 5j; lo dejó la 5g): como _thermal_setup, pero cada nodo con el
## material de su sitio (la queratina del muñón y de la carne viva, o el bloque, con su conducción, su densidad y su calor
## específico: block_thermal), entre dos nodos de distinto material sus dos mitades en serie, y el tope de cada nodo, el de
## su material (la queratina se quema; el bloque se funde, se ablanda o se oxida). El bloque va del lado de la cara: hasta
## dónde llega el calor se cuenta con el largo equivalente de queratina, L·√(α_queratina/α_bloque) en el bloque (la difusión
## tarda L²/α), contra max_depth_mm. Sin bloque en el camino (el flanco sobre el muñón), lo mismo que _thermal_setup.
func _thermal_setup_block(zone: String, s_zone: float, heat_len: float) -> void:
	var depth := _thermal_depth(zone, s_zone)
	var max_d: float = CareData.THERMAL.max_depth_mm.value
	var f_blk := sqrt(float(CareData.THERMAL.diffusivity_m2_s.value) / float(_block_th.alpha))
	# mm del eje de la garra por mm del camino del calor: a lo largo en la punta; en el flanco, en línea recta hasta el final
	# de la carne viva (0 a través de la pared, donde hay carne viva debajo: ahí no hay bloque)
	var along := 1.0
	if zone == "flanco":
		along = 0.0 if s_zone < _s_quick else (s_zone - _s_quick) / maxf(depth, 1e-9)
	var lb := minf((s_zone - _block_from) / along, depth) if along > 0.0 and s_zone > _block_from else 0.0
	var reach := depth + lb * (f_blk - 1.0) <= max_d
	var x := depth
	if not reach:
		x = max_d / f_blk if f_blk * lb >= max_d else lb + (max_d - f_blk * lb)
	var n_live := int(round(float(CareData.THERMAL.live_mm.value) / THERMAL_DX_MM)) if reach else 0
	var n_ker := maxi(int(ceil(x / THERMAL_DX_MM - 1e-9)), 1)
	var n := n_live + n_ker + 1
	if _th.size() != n or _th_reach != reach or _th_live != n_live:
		_resize_slab(n, n_live, reach)
	var k_ker := keratin_conductivity()
	var rc_ker: float = CareData.KERATIN_DENSITY * float(CareData.THERMAL.specific_heat_j_kg_k.value)
	var k_blk := float(_block_th.k)
	var rc_blk := float(_block_th.rhoC)
	var bed: float = CareData.THERMAL.bed_c.value
	var cap_ker: float = float(CareData.THERMAL.char_c.value) - bed
	var cap_blk := float(_block_th.capC) - bed if _block_th.capC != null else INF
	var h_air: float = CareData.THERMAL.h_air.value
	var dx := THERMAL_DX_MM / 1000.0
	_th_c.resize(n)
	_th_g.resize(n)
	_th_h.resize(n)
	_th_w.resize(n)
	_th_cp.resize(n)
	_th_dp.resize(n)
	_th_capv.resize(n)
	_th_isblk.resize(n)
	var last := n - 1
	# el material de cada nodo, por su sitio en el eje (como _mat_at)
	for i in n:
		var d := float(last - i) * THERMAL_DX_MM
		var blk := along > 0.0 and d <= depth + 1e-9 and s_zone - d * along >= _block_from - 1e-9
		_th_isblk[i] = 1 if blk else 0
		_th_capv[i] = cap_blk if blk else cap_ker
	if zone == "flanco":
		var a_c := maxf(_flank_contact_mm2, THERMAL_R_FLOOR_MM * THERMAL_R_FLOOR_MM * PI) * 1.0e-6
		for i in n:
			var rc := rc_blk if _th_isblk[i] == 1 else rc_ker
			_th_c[i] = rc * a_c * dx * (0.5 if i == last else 1.0)
			_th_g[i] = _series_g(i, last, a_c, dx, k_ker, k_blk)
			_th_h[i] = h_air * a_c if i == last else 0.0
			_th_w[i] = 1.0 if i == last else 0.0
		return
	var total := 0.0
	for i in n:
		var s := s_zone - float(last - i) * THERMAL_DX_MM
		var r := maxf(radius_at(s), THERMAL_R_FLOOR_MM) / 1000.0
		var half := 0.5 if i == last else 1.0
		var vol := PI * r * r * dx * half
		_th_c[i] = (rc_blk if _th_isblk[i] == 1 else rc_ker) * vol
		if i < last:
			var rm := maxf(radius_at(s + 0.5 * THERMAL_DX_MM), THERMAL_R_FLOOR_MM) / 1000.0
			_th_g[i] = _series_g(i, last, PI * rm * rm, dx, k_ker, k_blk)
		else:
			_th_g[i] = 0.0
		_th_h[i] = h_air * (2.0 * PI * r * dx * half + (PI * r * r if i == last else 0.0))
		var w := vol if s >= s_zone - heat_len - 1e-9 and i > 0 else 0.0
		_th_w[i] = w
		total += w
	for i in n:
		_th_w[i] = _th_w[i] / total if total > 0.0 else (1.0 if i == last else 0.0)


## Conductancia (W/K) del nodo i al siguiente por una sección a (m²) con nodos cada dx (m): k·a/dx si los dos son del mismo
## material; si no, sus dos mitades en serie, a/(dx/2/k_i + dx/2/k_i+1). 0 en la cara.
func _series_g(i: int, last: int, a: float, dx: float, k_ker: float, k_blk: float) -> float:
	if i >= last:
		return 0.0
	var k_i := k_blk if _th_isblk[i] == 1 else k_ker
	var k_j := k_blk if _th_isblk[i + 1] == 1 else k_ker
	if _th_isblk[i] == _th_isblk[i + 1]:
		return k_i * a / dx
	return a / (0.5 * dx / k_i + 0.5 * dx / k_j)


## Un paso implícito (Euler hacia atrás, algoritmo de Thomas) de dt_s segundos con la potencia p_w entrando en la garra.
func _thermal_step(p_w: float, dt_s: float) -> void:
	var n := _th.size()
	if n < 2:
		return
	var last := n - 1
	for i in range(1, n):
		var g_lo := _th_g[i - 1]
		var g_hi := _th_g[i] if i < last else 0.0
		var cdt := _th_c[i] / dt_s
		var b := cdt + g_lo + g_hi + _th_h[i]
		var d := cdt * _th[i] + p_w * _th_w[i]
		if i == 1:
			_th_cp[i] = -g_hi / b
			_th_dp[i] = d / b
		else:
			var den := b + g_lo * _th_cp[i - 1]
			_th_cp[i] = -g_hi / den
			_th_dp[i] = (d + g_lo * _th_dp[i - 1]) / den
	_th[last] = _th_dp[last]
	for i in range(last - 1, 0, -1):
		_th[i] = _th_dp[i] - _th_cp[i] * _th[i + 1]
	_th[0] = 0.0
	# la queratina no pasa de la temperatura a la que se quema (CareData.THERMAL.char_c): lo que sobra la quema, no la
	# calienta más (sin este tope, un torno quieto sobre un contacto diminuto subía a miles de grados)
	var cap: float = float(CareData.THERMAL.char_c.value) - float(CareData.THERMAL.bed_c.value)
	var hit := false
	# con el bloque (unidad 5j), cada nodo con el tope de su material: el bloque se funde, se ablanda o se oxida
	var per := _th_capv.size() == n
	var hit_blk := false
	for i in range(1, n):
		var c := _th_capv[i] if per else cap
		if _th[i] > c:
			_th[i] = c
			if per and _th_isblk[i] == 1:
				hit_blk = true
			else:
				hit = true
	if hit_blk and not _block_hot:
		_block_hot = true
		_event("bloque_calor", "El bloque de %s llega a ~%s °C, donde %s: lo que sobra lo estropea en vez de calentarlo más. Para y deja que se enfríe." % [
			String(_block.name).to_lower(), Js.to_fixed(float(_block_th.capC), 0), String(_block_th.capWhat)], String(_block_th.capSource))
	if hit and not _charred:
		_charred = true
		_event("quema", "La queratina llega a ~%s °C y se quema: huele a quemado. Para y deja que se enfríe." % Js.to_fixed(float(CareData.THERMAL.char_c.value), 0), String(CareData.THERMAL.char_c.source) + "; " + CareData.SRC_DREMEL_GUIDE)
	_read_thermal()
	# la superficie se quema donde pasa de la desnaturalización de la queratina (petición 37), mientras entra calor: es entonces
	# cuando la cara llega a lo más alto, y donde está la herramienta (el modelo térmico es uno y va con ella; al enfriarse,
	# sin herramienta, no quema nada nuevo)
	var gate := float(CareData.THERMAL.char_c.min)
	if per and _block_th.capC != null:
		gate = minf(gate, float(_block_th.capC) - (float(CareData.THERMAL.char_c.value) - gate))
	if p_w > 0.0 and _face_c >= gate:
		_surface_burn()


## Sin calor que meter: el tiempo pasa en la zona del modelo térmico (la punta, donde esté ahora, si la zona del flanco
## ya no existe).
func _idle_run(secs: float) -> float:
	var zone := _th_zone
	var s := _th_zone_s
	if zone != "flanco" or s > _s_apex:
		zone = "punta"
		s = _s_apex
	return _run(secs, 0.0, zone, s, _th_heat_len)


## Dónde está el calor (lo pidió la 5b, unidad 5g): el tramo de la garra (mm desde la base) que cubren los nodos del modelo
## térmico. En la punta («largo»), los nodos van a lo largo de la garra, cada THERMAL_DX_MM, del extremo vivo (el primero) a
## la cara (el último, en sZone): [sZone − (n − 1)·dx, sZone]. En el flanco («pared»), los nodos atraviesan la pared, de la
## carne viva a la cara, y el tramo es el del contacto de la herramienta, por donde entra el calor.
func _thermal_span() -> PackedFloat64Array:
	if _th_zone == "flanco":
		return PackedFloat64Array([_th_flank_a, _th_flank_b])
	var n := _th.size()
	return PackedFloat64Array([_th_zone_s - float(maxi(n - 1, 0)) * THERMAL_DX_MM, _th_zone_s])


## Temperatura de cada nodo del modelo térmico (°C), del extremo vivo a la cara.
func _cells_c() -> PackedFloat64Array:
	var bed: float = CareData.THERMAL.bed_c.value
	var out := PackedFloat64Array()
	out.resize(_th.size())
	for i in _th.size():
		out[i] = bed + _th[i]
	return out


## Temperaturas de la cara y de la carne viva a partir del exceso de cada nodo.
func _read_thermal() -> void:
	var bed: float = CareData.THERMAL.bed_c.value
	var n := _th.size()
	_face_c = bed + (_th[n - 1] if n > 0 else 0.0)
	_quick_c = bed + (_th[_th_live] if _th_reach and _th_live < n else 0.0)
	_peak_quick_c = maxf(_peak_quick_c, _quick_c)


## ¿Está toda la garra del modelo térmico a la temperatura de partida (±1 mK)? Si lo está, la deja exactamente.
func _thermal_idle() -> bool:
	for x in _th:
		if absf(x) > 1e-3:
			return false
	if not _th.is_empty():
		_th.fill(0.0)
		_read_thermal()
	return true


## Cambia el número de nodos, anclado en el extremo vivo: lo que se arranca en la cara se lleva su calor; si la cara se
## aleja (otra zona), los nodos nuevos toman el exceso de la cara. Si cambia el tramo vivo, se empieza de nuevo.
func _resize_slab(n: int, n_live: int, reach: bool) -> void:
	var old := _th
	var old_n := old.size()
	var same := old_n > 0 and _th_reach == reach and _th_live == n_live
	_th = PackedFloat64Array()
	_th.resize(n)
	for i in n:
		if not same:
			_th[i] = 0.0
		elif i < old_n:
			_th[i] = old[i]
		else:
			_th[i] = old[old_n - 1]
	_th_live = n_live
	_th_reach = reach
	_read_thermal()


## Reacción del animal al dolor p (0-1): se mueve si pasa de lo que aguanta con su sujeción; el estrés sube.
func _react(p: float) -> void:
	if _patient.react(p):
		_moved_here += 1
		var sed: Dictionary = CareData.SEDATION[_patient.sedation]
		_event("se_mueve", "El animal se mueve de dolor: %s no basta." % String(sed.name).to_lower(), String(sed.source))


func _event(code: String, message: String, source: String) -> void:
	_events.append({ "code": code, "message": message, "source": source, "t_s": float(_k) * DT })


# ════════════════════════════════ Lecturas ════════════════════════════════

## Número que cambia con cada cambio de estado (la escena repinta solo si cambia).
func serial() -> int:
	return _serial


## Tiempo del ensayo (s), del contador entero de pasos.
func time_s() -> float:
	return float(_k) * DT


## Sucesos del ensayo (copia): [{ code, message, source, t_s }].
func events() -> Array:
	return _events.duplicate(true)


## La punta frente a la natural: { tipRadiusUm, naturalUm, ratio, alphaDeg, naturalAlphaDeg, lateralN (lo que aguanta de
## lado en el vértice), naturalLateralN, strengthRatio, facetDeg, flatMm }. Con la queratina a la humedad natural, para
## comparar formas; una garra reforjada o con el bloque en la punta, con su material.
func tip_state() -> Dictionary:
	var st: Variant = _tip_strength("natural")
	var r := tip_radius_um()
	var cap: Variant = null
	var cap0: Variant = null
	var ratio_s: Variant = null
	if st != null:
		cap = lateral_capacity_n(r, _tip_alpha, st)
		cap0 = lateral_capacity_n(_r0_um, _alpha, st)
		ratio_s = float(cap) / float(cap0) if float(cap0) > 0.0 else null
	return {
		"tipRadiusUm": r, "naturalUm": _r0_um, "ratio": r / _r0_um, "alphaDeg": _tip_alpha, "naturalAlphaDeg": _alpha,
		"lateralN": cap, "naturalLateralN": cap0, "strengthRatio": ratio_s, "facetDeg": _facet_deg, "flatMm": _flat_r,
	}


## Los veredictos de la forma en directo: [título, tono («bien» | «aviso» | «mal»)]. El texto con números lo arma shape().
const SHAPE_VERDICTS := {
	"correcta": ["Correcta", "bien"], "afilada": ["Afilada y sana", "bien"], "larga": ["Aún larga", "aviso"],
	"facetada": ["Facetada", "aviso"], "roma": ["Roma", "aviso"], "cerca": ["Al borde de la carne viva", "aviso"],
	"fina": ["Demasiado fina", "mal"], "carne_viva": ["Pasada de la carne viva", "mal"], "rota": ["Rota", "mal"],
	"reconstruida": ["Reconstruida", "aviso"],
}


## La forma en directo (petición 35): después de cada pasada, cómo va la garra, solo con lo que ya calcula el motor (la
## punta y lo que aguanta de lado, de claw_sharpness.gd; el largo que queda; la carne viva y las roturas) y los márgenes
## del informe (CareData.MARGINS). Por orden: rota, pasada de la carne viva, demasiado fina (aguanta de lado menos de la
## cuarta parte que la natural: se va a mellar), al borde de la carne viva (la señal del corte que se ve; en una garra
## oscura no se dice dónde está), roma (punta de más del doble de radio), facetada (la faceta se aparta más de 10° del
## ángulo de la garra), aún larga y, si no, correcta o afilada (más fina que la natural y aún aguanta).
## { verdict, title, tone, text, source, tipRadiusUm, naturalUm, ratio, strengthRatio, lateralN, overgrowthLeftMm,
##   facetDeg, naturalAlphaDeg, quickCoverMm (solo si la carne viva se ve), sign }.
func shape() -> Dictionary:
	var M: Dictionary = CareData.MARGINS
	var ts := tip_state()
	var sr: Variant = ts.strengthRatio
	var left := overgrowth_left_mm()
	# con el bloque en bruto (petición 35), lo que sobra se cuenta frente a la sobra del bloque o al crecimiento de más
	var over_ref := maxf(_over, float(_block.wallMm)) if not _block.is_empty() else _over
	var left_frac := left / over_ref if over_ref > 0.0 else 0.0
	var cover := quick_cover_mm()
	var visible := bool(_animal.quick_visible) and not _reforged
	var sign := not _reforged and cover > 0.0 and cover < SIGN_RADII * radius_at(_s_quick)
	var v := "correcta"
	var text := "La forma natural: su punta, su largo y su margen a la carne viva."
	var src := ClawSharpness.SRC_PATTRICK + "; " + CareData.SRC_RUBRIC
	if (_broken or _wall_through) and _repaired:
		# (5v) la garra rota ya reconstruida con metacrilato: provisional (el motor no lo dibuja ni lo lima: la forma y la punta
		# que se leen son las del muñón)
		v = "reconstruida"
		text = "Con metacrilato y bicarbonato: una capa dura y provisional sobre el muñón, que se rehace cada 8-12 semanas mientras la garra crece. La forma y la punta que se leen son las del muñón."
		src = CareData.SRC_SAMOUR + ", pp. 925-928"
	elif _broken or _wall_through:
		v = "rota"
		text = "Rota hasta la carne viva: hemostasia, limpieza y reconstrucción, o reforjarla con material."
		src = CareData.SRC_SAMOUR
	elif _quick_cut:
		v = "carne_viva"
		text = "El corte ha llegado a la carne viva: sangra."
		src = CareData.SRC_SAMOUR
	elif sr != null and float(sr) < 0.25:
		v = "fina"
		text = "Aguanta de lado el %s %% de la natural (~%s en el vértice): se va a mellar." % [Js.to_fixed(float(sr) * 100.0, 0), Format.fmt_small_force(float(ts.lateralN))]
		src = ClawSharpness.SRC_PATTRICK
	elif sign:
		v = "cerca"
		text = ("A %s mm de la carne viva: menos que el grosor de la garra ahí." % Js.to_fixed(cover, 1)) if visible else "El centro del corte se oscurece: la carne viva está muy cerca. Para."
		src = (CareData.SRC_SAKAS if visible else CareData.SRC_DREMEL_GUIDE) + "; " + CareData.SRC_RUBRIC
	elif float(ts.ratio) > float(M.tip_ratio_hi):
		v = "roma"
		text = "Punta de %s µm, %s veces la natural: pinchar pide mucha más fuerza." % [Js.to_fixed(float(ts.tipRadiusUm), 0), Js.to_fixed(float(ts.ratio), 1)]
		src = ClawSharpness.SRC_DAVIS
	elif _facet_deg > 0.0 and absf(_facet_deg - _alpha) > float(M.facet_deg):
		v = "facetada"
		text = "La faceta va a %s° y la garra, a %s°: no sigue la curva." % [Js.to_fixed(_facet_deg, 0), Js.to_fixed(_alpha, 0)]
		src = CareData.SRC_DREMEL_GUIDE + "; " + CareData.SRC_SAMOUR
	elif left_frac > float(M.overgrowth_left):
		v = "larga"
		text = "Quedan %s mm del crecimiento de más." % Js.to_fixed(left, 1)
		src = CareData.SRC_SAMOUR + "; " + CareData.SRC_ARENT
	elif float(ts.ratio) < 1.0 and sr != null:
		v = "afilada"
		text = "Más fina que la natural (%s µm) y aún aguanta de lado el %s %%." % [Js.to_fixed(float(ts.tipRadiusUm), 0), Js.to_fixed(float(sr) * 100.0, 0)]
	var vv: Array = SHAPE_VERDICTS[v]
	return {
		"verdict": v, "title": String(vv[0]), "tone": String(vv[1]), "text": text, "source": src,
		"tipRadiusUm": ts.tipRadiusUm, "naturalUm": ts.naturalUm, "ratio": ts.ratio, "strengthRatio": sr, "lateralN": ts.lateralN,
		"overgrowthLeftMm": left, "facetDeg": _facet_deg, "naturalAlphaDeg": _alpha, "quickCoverMm": cover if visible else null,
		"sign": sign,
	}


## Instantánea para la escena 3D, la interfaz y el tutorial (un diccionario nuevo en cada llamada).
##   profile: { s (mm desde la base), r (radio exterior), core (radio de la carne viva) } hasta la punta, cada 0,5 mm;
##   claw: largos, carne viva, crecimiento de más, color (dibujo), si la carne viva se ve y la señal del corte;
##   tip, thermal, bleeding, damage, animal, events, serial, t_s.
func snapshot() -> Dictionary:
	var ps := PackedFloat64Array()
	var pr := PackedFloat64Array()
	var pc := PackedFloat64Array()
	var step := maxi(int(round(0.5 / STATION_MM)), 1)
	var i := 0
	while float(i) * STATION_MM < _s_apex:
		ps.append(float(i) * STATION_MM)
		pr.append(_r[i])
		pc.append(_core[i])
		i += step
	ps.append(_s_apex)
	pr.append(radius_at(_s_apex))
	pc.append(core_at(_s_apex))
	var cover := quick_cover_mm()
	var hm: Dictionary = CareData.keratin(_humidity)
	return {
		"serial": _serial, "t_s": time_s(),
		"animal_id": String(_animal.id), "claw_id": String(_claw.id), "inlay": String(_inlay.id), "reforged": _reforged,
		"profile": { "s": ps, "r": pr, "core": pc },
		"claw": {
			"lengthMm": _s_apex, "naturalMm": _L_nat, "startMm": _L_nat + _over, "overgrowthLeftMm": overgrowth_left_mm(),
			"tipStart": _tip_start,
			"quickMm": null if _reforged else _s_quick, "quickCoverMm": null if _reforged else cover, "baseRadiusMm": _base_r,
			# la forma de la garra de este dedo (petición 36; CareData.CLAW_SHAPES): el arco de fuera (y el de dentro), lo
			# comprimida de lado que es (la física, redonda con el radio del perfil; el dibujo, alto 2·r·√k y ancho 2·r/√k) y la
			# cara de abajo plana. curve: la del dibujo (art.gd: la línea media gira 35° + 115°·curve), la que da arcDeg
			"digit": String(_shape.digit), "hind": bool(_shape.hind), "arcDeg": float(_shape.arcDeg), "arcInnerDeg": _shape.arcInnerDeg,
			"arcMethod": String(_shape.arcMethod),
			"sectionRatio": float(_shape.sectionRatio), "ventralFlat": bool(_shape.ventralFlat), "shapeQuality": String(_shape.quality),
			"shapeSource": String(_shape.source), "sectionQuality": String(_shape.sectionQuality), "sectionSource": String(_shape.sectionSource),
			"curve": (float(_shape.arcDeg) - 35.0) / 115.0,
			"color": String(_claw.get("col", "#6B5A45")) if not _reforged else String(_inlay.get("col", "#C7CDD6")),
			# el color de la queratina de esta especie (dibujo), también con la garra reforjada: el de las demás garras sin pieza
			"keratinColor": String(_claw.get("col", "#6B5A45")),
			# el bloque en bruto reforjado sobre el muñón (petición 35): desde fromMm (mm desde la base) la garra es del material
			# del bloque, con su color; fiction y note dicen lo que en la realidad no se hace. null sin bloque
			"block": null if _block.is_empty() else {
				"material": String(_block.id), "name": String(_block.name), "color": String(_block.get("col", "#C7CDD6")),
				"colorQuality": "dibujo", "fromMm": _block_from, "stumpMm": float(_block.stumpMm), "wallMm": float(_block.wallMm),
				"hv": float(_block.hv), "fiction": bool(_block.fiction), "note": String(_block.note), "source": String(_block.source),
				# a capas (unidad 5o): lo construido (mm desde el muñón); null, el bloque entero
				"builtMm": _block_built if is_finite(_block_built) else null,
				# cómo conduce el calor de limarlo (unidad 5j: block_thermal); null si se cuenta como la queratina
				"thermal": null if _block_th.is_empty() else _block_th.duplicate(),
			},
			"colorQuality": "dibujo", "quickVisible": bool(_animal.quick_visible) and not _reforged,
			"sign": not _reforged and cover > 0.0 and cover < SIGN_RADII * radius_at(_s_quick),
			"humidity": _humidity, "humidityName": String(hm.name), "removedMm3": _removed_mm3,
		},
		"tip": tip_state(),
		# la forma en directo (petición 35) y la superficie, por estación (petición 37)
		"shape": shape(),
		"surface": surface(),
		"thermal": {
			"quickC": _quick_c, "faceC": _face_c, "peakQuickC": _peak_quick_c, "painC": float(CareData.THERMAL.pain_c.value),
			"painS": _heat_pain_s, "injuryDose": _dose, "injured": _dose >= 1.0, "cells": _cells_c(),
			"quickCell": _th_live if _th_reach else -1,
			"charred": _charred, "charC": float(CareData.THERMAL.char_c.value),
			# el bloque (unidad 5j) ha llegado a su tope (se funde, se ablanda o se oxida)
			"blockHot": _block_hot,
			# dónde está el calor (unidad 5g): la zona, dónde entra (mm desde la base), el paso de los nodos y su tramo
			"zone": _th_zone, "sZone": _th_zone_s, "dxMm": THERMAL_DX_MM, "axis": "pared" if _th_zone == "flanco" else "largo",
			"spanMm": _thermal_span(),
		},
		"bleeding": {
			"active": _bleeding, "bled": _bled, "areaMm2": _bleed_area, "elapsedS": _bleed_t, "totalS": _bleed_total, "needS": _hemostasis_need(),
			"agent": _agent_used, "disinfected": _disinfected,
		},
		"damage": {
			"splits": _splits.duplicate(true), "peels": _peels.duplicate(true), "chips": _chips, "flattened": _flattened,
			"broken": _broken or _wall_through, "quickCut": _quick_cut, "wallThrough": _wall_through, "repaired": _repaired,
			"brokenStart": _broken_start,
			# las roturas con su sitio (petición 35): dónde, el trozo que se va y de qué tipo; la última, aparte
			"breaks": _breaks.duplicate(true), "lastBreak": (_breaks.back() as Dictionary).duplicate(true) if not _breaks.is_empty() else null,
		},
		"animal": {
			# el animal (compartido con sus otras garras) y lo que se ha movido por lo que se le ha hecho a esta
			"sedation": _patient.sedation, "sedationName": String(CareData.SEDATION[_patient.sedation].name), "pain": _patient.pain,
			"maxPain": _patient.max_pain, "stress": _patient.stress, "moved": _patient.moved, "movedHere": _moved_here,
			"unsafe": _patient.unsafe, "stressQuality": "índice pedagógico",
		},
		"events": _events.duplicate(true),
	}


## Materiales reforjados que suenan a metal al limarlos (los demás, a vidrio o piedra).
const METAL_INLAYS := ["oro", "acero", "titanio", "tungsteno"]


## Efecto de sonido del laboratorio para el resultado de una acción («file», «clip», «hemostasis», «apply»): un id de
## core/lab/sfx.gd (SFX_IDS; los WAV, en res://assets/sfx/lab/). Carne viva cortada o rajada: «skin-cut»; punta mellada:
## «snap»; aplastada: «press»; la lima que resbala sin morder: «slide»; limar queratina: «scratch-deep» (bastarda o
## deshojando), «scratch-wood» (limas de acero finas) o «scratch-soft» (lijas, diamante y torno); una garra reforjada,
## «scratch-metal» o «scratch-glass»; el cortaúñas, «snap»; la sangre que no para, «drip». El zumbido del motor del
## torno lo pone la escena.
func sfx_for(action: String, result: Dictionary) -> String:
	if bool(result.get("bled", false)) or bool(result.get("reachesQuick", false)):
		return "skin-cut"
	match action:
		"file":
			if bool(result.get("chipped", false)):
				return "snap"
			if bool(result.get("flattened", false)):
				return "press"
			if bool(result.get("noBite", false)):
				return "slide"
			var lm: Dictionary = _last_mat if not _last_mat.is_empty() else _mat_at(_s_apex)
			if bool(lm.reforged):
				return "scratch-metal" if METAL_INLAYS.has(String(lm.inlay.id)) else "scratch-glass"
			var tid := String(result.get("tool", ""))
			if tid == "lima_bastarda" or bool(result.get("peeled", false)):
				return "scratch-deep"
			if tid in ["lima_entrefina", "lima_fina"]:
				return "scratch-wood"
			return "scratch-soft"
		"clip":
			return "snap" if bool(result.get("cut", false)) else "tap"
		"probe":
			if bool(result.get("chipped", false)):
				return "snap"
			if bool(result.get("flattened", false)):
				return "press"
			return "tap" if bool(result.get("catches", false)) else "slide"
		"hemostasis":
			return "tap" if bool(result.get("stopped", false)) else "drip"
	return "tap"


## Condiciones que sabe comprobar check() (las que usan los pasos de claw_care_tutorial.gd).
const CHECK_KEYS := [
	"sujecion", "remojada", "sin_sangre", "sin_grieta", "a_favor", "curva", "largo", "punta", "sin_calor", "hemostasia",
	"desinfectada", "crema", "reconstruida", "lima_adecuada",
]


## ¿Se cumple una condición del tutorial? (claves de claw_care_tutorial.gd).
func check(key: String) -> bool:
	match key:
		"sujecion":
			if String(_animal.id) == "rapaz":
				return _patient.sedation != "libre"
			return _patient.restrained()
		"remojada":
			return _wetted or _humidity in ["humeda", "empapada"]
		"sin_sangre":
			return not _bled
		"sin_grieta":
			return _splits.is_empty()
		"a_favor":
			return _directions.has("a_favor") and not _directions.has("en_contra") and not _directions.has("vaiven")
		"curva":
			return _facet_deg <= 0.0 or absf(_facet_deg - _alpha) <= float(CareData.MARGINS.facet_deg) + 1e-9
		"largo":
			return _over <= 0.0 or overgrowth_left_mm() <= float(CareData.MARGINS.overgrowth_left) * _over + 1e-9
		"punta":
			var ts := tip_state()
			if ts.strengthRatio == null:
				return float(ts.ratio) >= float(CareData.MARGINS.tip_ratio_lo) and float(ts.ratio) <= float(CareData.MARGINS.tip_ratio_hi)
			return float(ts.strengthRatio) >= 0.25 - 1e-12 and float(ts.ratio) <= float(CareData.MARGINS.tip_ratio_hi)
		"sin_calor":
			return _peak_quick_c < float(CareData.THERMAL.pain_c.value)
		"hemostasia":
			return not _bleeding
		"desinfectada":
			return not _bled or _disinfected
		"crema":
			return _cream
		"reconstruida":
			return not (_broken or _wall_through) or _repaired
		"pausa":
			return _patient.resting
		"calmado":
			return _patient.stress < float(CareData.ANIMAL_RISK["restless"])
		"lima_adecuada":
			for tid: String in _tools_used:
				var t := CareData.tool(tid)
				if String(t.get("kind", "")) in ["lima", "torno"] and _bites(t) > 0.0:
					return true
			return false
	return true


## El tutorial de un proceso para este ensayo: los pasos de claw_care_tutorial.gd con done (si tienen condición).
func tutorial(process: String) -> Array:
	var out: Array = []
	for st: Dictionary in Tutorial.steps(String(_animal.id), process, String(_inlay.id)):
		var s2 := st.duplicate()
		s2["done"] = check(String(st.check)) if String(st.check) != "" else null
		out.append(s2)
	return out


# ════════════════════════════════ Informe ════════════════════════════════

## Veredicto, nota (rúbrica pedagógica) y consejos con su fuente:
## { verdict, verdictText, grade, gradeText, criteria: [{ id, title, ok, lost, text, source }], advice: [{ id, title, text,
##   source }], regrow: { days, text, source } | null, facts, rubricSource }.
## Veredictos: «rota», «reconstruida» (rota y reconstruida con metacrilato), «corta_sangra», «agrietada», «daga_fragil»,
## «roma», «larga», «corta», «perfecta_daga» (más afilada que la natural y aún aguanta) y «perfecta».
func report() -> Dictionary:
	var R: Dictionary = CareData.RUBRIC
	var M: Dictionary = CareData.MARGINS
	var crit: Array = []
	var advice: Array = []
	var cap := 10.0
	var ts := tip_state()
	var bird := String(_animal.id) == "rapaz"
	var margin := quick_cover_mm()
	var safe := radius_at(_s_quick) if not _reforged else 0.0
	var left := overgrowth_left_mm()
	var left_frac := left / _over if _over > 0.0 else 0.0
	var s_ratio: Variant = ts.strengthRatio
	# ── Sujeción y anestesia ──
	if _patient.unsafe:
		cap = 0.0
		_crit(crit, "anestesia", "¡Peligro!", R.sin_anestesia, "El procedimiento empezó sin sedación o anestesia suficiente; anestesiar después no lo borra. Nota 0.", CareData.SRC_CATTALES + "; " + CareData.SRC_ANIMALS_ASIA)
	elif not check("sujecion"):
		if bird:
			_crit(crit, "sujecion", "Sujeción", R.sin_sujecion, "Una rapaz se sujeta encapuchada y envuelta en una toalla, entre dos personas si es grande.", CareData.SRC_SAMOUR)
		else:
			cap = 0.0
			_crit(crit, "anestesia", "¡Peligro!", R.sin_anestesia, "A un %s solo se le tocan las garras sedado a fondo o con anestesia general. Nota 0." % String(_animal.name).to_lower(), CareData.SRC_CATTALES + "; " + CareData.SRC_ANIMALS_ASIA)
	if _moved_here > 0:
		_crit(crit, "se_mueve", "El animal se movió", R.se_mueve, "Se movió %d vez/veces por el dolor." % _moved_here, String(CareData.SEDATION[_patient.sedation].source))
	# ── Daños ──
	if _broken or _wall_through:
		_crit(crit, "rota", "Garra rota", R.rota, "La garra se ha roto hasta la carne viva: hemostasia, limpieza y reconstrucción provisional hasta que crezca.", CareData.SRC_SAMOUR)
		if not _repaired:
			_crit(crit, "sin_reconstruir", "Sin reconstruir", R.sin_reconstruir, "Una garra rota se protege y se reconstruye con metacrilato hasta que crezca.", String(CareData.TOOLS.metacrilato.source))
	elif _quick_cut:
		_crit(crit, "sangra", "Demasiado corta", R.sangra, "Se ha cortado la carne viva: recortar de más hace sangrar.", CareData.SRC_SAMOUR)
	# una grieta que llega a la carne viva ya cuenta como garra rota
	var open_splits := _splits.filter(func(sp: Dictionary) -> bool: return not bool(sp.reaches_quick))
	if not open_splits.is_empty():
		_crit(crit, "grieta", "Grieta", R.grieta, "El cortaúñas dejó una grieta a lo largo de %s mm." % Js.to_fixed(_split_total(open_splits), 1), CareData.SRC_FARRAN)
	if not _peels.is_empty():
		_crit(crit, "deshojada", "Deshojada", R.deshojada, "Limando en contra de las capas se han levantado escamas.", CareData.SRC_FARRAN + "; " + CareData.SRC_AAD)
	if _chips > 0:
		_crit(crit, "mellada", "Punta mellada", R.mellada, "La punta se melló %d vez/veces: demasiada carga de lado para lo fina que estaba." % _chips, ClawSharpness.SRC_PATTRICK)
	if _dose >= 1.0:
		_crit(crit, "calor_lesion", "Quemadura", R.calor_lesion, "El calor del torno ha lesionado la carne viva (%s °C de pico)." % Js.to_fixed(_peak_quick_c, 0), CareData.SRC_MORITZ)
	elif _peak_quick_c >= float(CareData.THERMAL.pain_c.value):
		_crit(crit, "calor_dolor", "Calor", R.calor_dolor, "El calor llegó a la carne viva: %s °C de pico, por encima del umbral del dolor (~43 °C)." % Js.to_fixed(_peak_quick_c, 1), CareData.SRC_DUBIN + "; " + CareData.SRC_DREMEL_GUIDE)
	if _bled and _bleeding:
		_crit(crit, "sin_hemostasia", "Sigue sangrando", R.sin_hemostasia, "Hay que parar la sangre: polvo hemostático y presión.", CareData.SRC_DREMEL_GUIDE)
	if _bled and not _disinfected:
		_crit(crit, "sin_desinfectar", "Sin desinfectar: riesgo de infección", R.sin_desinfectar, "Ha sangrado y la herida se ha quedado sin limpiar: se puede infectar. Se limpia con clorhexidina diluida al 0,05 %, que mata las bacterias sin retrasar la cicatrización.", CareData.SRC_LOZIER + "; " + CareData.SRC_MSD)
	if bird and not _cream and not _reforged:
		_crit(crit, "sin_crema", "Sin crema", R.sin_crema, "Después del arreglo de las garras (el «coping» de los cetreros), crema de lanolina o parafina en las garras.", CareData.SRC_SAMOUR)
	if _no_bite:
		_crit(crit, "lima_no_muerde", "Herramienta", R.lima_no_muerde, "Se usó una herramienta que no muerde este material: tiene que ser más dura que la garra.", CareData.SRC_FILE_TEST)
	# ── Forma ──
	if left_frac > float(M.overgrowth_left):
		_crit(crit, "largo", "Aún larga", float(R.largo) * minf(left_frac, 1.0), "Quedan %s mm del crecimiento de más." % Js.to_fixed(left, 1), CareData.SRC_SAMOUR + "; " + CareData.SRC_ARENT)
	var near := not _reforged and not (_broken or _wall_through or _quick_cut) and margin > 0.0 and margin < safe
	if near:
		_crit(crit, "corta", "Muy cerca de la carne viva", R.corta, "Quedan %s mm de queratina delante de la carne viva: menos que el grosor de la garra ahí (%s mm)." % [Js.to_fixed(margin, 1), Js.to_fixed(safe, 1)], CareData.SRC_RUBRIC)
	var fragile := s_ratio != null and float(s_ratio) < 0.25
	var blunt := float(ts.ratio) > float(M.tip_ratio_hi)
	if fragile:
		_crit(crit, "daga", "Demasiado fina", R.daga, "La punta aguanta de lado el %s %% de la natural: se mellará." % Js.to_fixed(float(s_ratio) * 100.0, 0), ClawSharpness.SRC_PATTRICK)
	elif blunt:
		_crit(crit, "roma", "Roma", R.roma, "Punta de %s µm, %s veces la natural: pinchar pide mucha más fuerza." % [Js.to_fixed(float(ts.tipRadiusUm), 0), Js.to_fixed(float(ts.ratio), 1)], ClawSharpness.SRC_DAVIS)
	if _facet_deg > 0.0 and absf(_facet_deg - _alpha) > float(M.facet_deg):
		_crit(crit, "curva", "No sigue la curva", R.curva, "La faceta va a %s° y la garra, a %s°." % [Js.to_fixed(_facet_deg, 0), Js.to_fixed(_alpha, 0)], CareData.SRC_DREMEL_GUIDE)
	# ── Veredicto ──
	var verdict := "perfecta"
	if _patient.unsafe:
		verdict = "peligro"
	elif _broken or _wall_through:
		verdict = "reconstruida" if _repaired else "rota"
	elif _quick_cut or _bleeding:
		verdict = "corta_sangra"
	elif not _splits.is_empty() or not _peels.is_empty() or _chips > 0:
		verdict = "agrietada"
	elif near:
		verdict = "corta"
	elif fragile:
		verdict = "daga_fragil"
	elif blunt:
		verdict = "roma"
	elif left_frac > float(M.overgrowth_left):
		verdict = "larga"
	elif float(ts.ratio) < 1.0:
		verdict = "perfecta_daga"
	var lost := 0.0
	for c: Dictionary in crit:
		lost += float(c.lost)
	var grade := clampf(10.0 - lost, 0.0, cap)
	return {
		"verdict": verdict, "verdictText": String(VERDICTS[verdict]), "grade": grade, "gradeText": "%s / 10" % Js.to_fixed(grade, 1),
		"criteria": crit, "advice": _advice(verdict, ts), "regrow": _regrow(verdict), "rubricSource": CareData.SRC_RUBRIC,
		"facts": {
			"lengthMm": _s_apex, "naturalMm": _L_nat, "overgrowthLeftMm": left, "quickCoverMm": null if _reforged else margin, "safeMarginMm": null if _reforged else safe,
			"tip": ts, "peakQuickC": _peak_quick_c, "injuryDose": _dose, "moved": _moved_here, "movedAnimal": _patient.moved, "stress": _patient.stress,
		},
	}


const VERDICTS := {
	"perfecta": "Perfecta: la forma natural, con su punta y margen a la carne viva.",
	"perfecta_daga": "Perfecta y afilada como una daga: más fina que la natural y aún aguanta de lado.",
	"daga_fragil": "Afilada como una daga, pero frágil: se mellará con poca carga de lado.",
	"roma": "Roma: sin punta, pinchar pide mucha más fuerza.",
	"larga": "Aún larga: queda crecimiento de más.",
	"corta": "Demasiado corta: al borde de la carne viva.",
	"corta_sangra": "Demasiado corta: se ha cortado la carne viva y sangra.",
	"agrietada": "Agrietada: grietas, escamas o la punta mellada.",
	"rota": "Rota hasta la carne viva: se reconstruye con metacrilato o se espera a que crezca.",
	"peligro": "Peligro: se le han tocado las garras a un animal grande sin sedar ni anestesiar. Nota 0.",
	"reconstruida": "Rota y reconstruida: metacrilato provisional, rehecho cada 8-12 semanas hasta que la garra vuelva a crecer.",
}


func _crit(list: Array, id: String, title: String, lost: float, text: String, source: String) -> void:
	list.append({ "id": id, "title": title, "ok": false, "lost": lost, "text": text, "source": source })


func _split_total(splits: Array) -> float:
	var t := 0.0
	for sp: Dictionary in splits:
		t += float(sp.to_s) - float(sp.from_s)
	return t


## Consejos según lo que ha pasado, cada uno con su fuente.
func _advice(verdict: String, ts: Dictionary) -> Array:
	var out: Array = []
	if not _peels.is_empty() or _directions.has("en_contra") or _directions.has("vaiven"):
		out.append({ "id": "direccion", "title": "Dirección", "text": "Lima siempre de la base a la punta y levanta la lima al volver: en contra se deshoja.", "source": CareData.SRC_AAD + "; " + CareData.SRC_NICHOLSON })
	if not _splits.is_empty():
		out.append({ "id": "remojar", "title": "Antes de cortar", "text": "Remoja la garra unos minutos antes de cortarla y usa un cortaúñas de guillotina afilado: seca y con el de tijera se raja más.", "source": CareData.SRC_AAD + "; " + CareData.SRC_FARRAN + "; " + CareData.SRC_SAMOUR })
	if _peak_quick_c >= float(CareData.THERMAL.pain_c.value):
		out.append(_heat_advice())
	if verdict == "daga_fragil" or _chips > 0:
		out.append({ "id": "punta", "title": "La punta", "text": "No la dejes más fina que la natural o ábrele el ángulo de la faceta: la carga que aguanta de lado crece con el cuadrado del radio.", "source": ClawSharpness.SRC_PATTRICK })
	if verdict == "roma":
		out.append({ "id": "afilar", "title": "Dar la punta", "text": "Talla una faceta alrededor del vértice con la lima fina, algo más abierta que la garra.", "source": ClawSharpness.SRC_PATTRICK })
	if _bled:
		out.append({ "id": "sangre", "title": "Si sangra", "text": "Polvo hemostático y presión; luego clorhexidina al 0,05 %.", "source": CareData.SRC_MSD + "; " + CareData.SRC_LOZIER })
	if _no_bite:
		out.append({ "id": "dureza", "title": "La herramienta", "text": "Para las garras de hematites, cuarzo, circonita, alúmina, zafiro, rubí, moissanita o carburo de tungsteno, lima de diamante: la de acero no muerde.", "source": CareData.SRC_FILE_TEST })
	if String(_animal.id) == "rapaz" and not _cream:
		out.append({ "id": "crema", "title": "Al terminar", "text": "Crema de lanolina o parafina en las garras, y perchas duras que las desgasten.", "source": CareData.SRC_SAMOUR })
	if ts.strengthRatio != null and verdict in ["perfecta", "perfecta_daga"]:
		out.append({ "id": "bien", "title": "Bien hecho", "text": "La punta aguanta de lado el %s %% de la natural con un radio de %s µm." % [Js.to_fixed(float(ts.strengthRatio) * 100.0, 0), Js.to_fixed(float(ts.tipRadiusUm), 0)], "source": ClawSharpness.SRC_PATTRICK })
	return out


## Cómo se nombra cada herramienta giratoria en los consejos: [con artículo, al empezar la frase].
const ROTARY_NOUNS := { "torno": ["el torno", "El torno"], "amoladora": ["la amoladora", "La amoladora"] }
## La ficha de la que sale la velocidad de cada herramienta giratoria.
const ROTARY_SOURCES := { "torno": CareData.SRC_DREMEL_7300, "amoladora": CareData.SRC_DREMEL_LITE }


## El consejo del calor (unidad 5g; lo pidió la 5c): habla de la herramienta giratoria que se ha usado (el torno, la
## amoladora o las dos) y de su velocidad más baja, la de su ficha (6500 rpm el torno, 8000 la amoladora). Si se ha usado más
## deprisa, dice cuánto más calienta con la misma fuerza: P = ε·μ·F·v y v = π·D·n, así que el calor crece con las rpm.
func _heat_advice() -> Dictionary:
	var used: Array = []
	for tid: String in CareData.TOOL_IDS:
		if String(CareData.TOOLS[tid].kind) == "torno" and _tools_used.has(tid):
			used.append(tid)
	if used.is_empty():
		used = ["torno"]
	var lows: Array = []
	var notes: Array = []
	var srcs: Array = [CareData.SRC_DREMEL_GUIDE]
	var titles: Array = []
	for tid: String in used:
		var t: Dictionary = CareData.TOOLS[tid]
		var nouns: Array = ROTARY_NOUNS.get(tid, [String(t.name).to_lower(), String(t.name)])
		var low := float((t.rpm_steps as Array)[0])
		var top := float(_rpm_max.get(tid, low))
		titles.append(String(nouns[1]) if titles.is_empty() else String(nouns[0]))
		lows.append([String(nouns[0]), low])
		if top > low:
			notes.append("A %s rpm, %s corre %s veces más deprisa que a %s y, con la misma fuerza, calienta otro tanto." % [
				grouped(top), String(nouns[0]), Js.to_fixed(top / low, 1), grouped(low)])
		srcs.append(String(ROTARY_SOURCES.get(tid, t.source)))
	var speed := ""
	if lows.size() == 1:
		speed = "a %s rpm, la velocidad más baja de %s" % [grouped(float(lows[0][1])), String(lows[0][0])]
	else:
		var parts: Array = lows.map(func(l: Array) -> String: return "%s rpm %s" % [grouped(float(l[1])), String(l[0])])
		speed = "en la velocidad más baja (%s)" % ", ".join(parts)
	var text := "Toques de pocos segundos con pausas, sin apretar y %s: el calor es μ·F·v." % speed
	if not notes.is_empty():
		text += " " + " ".join(notes)
	return { "id": "torno", "title": " y ".join(titles), "text": text, "source": "; ".join(srcs) }


## Un entero con los miles separados por un espacio duro a partir de cinco cifras («13 000»; «6500» sin separar), como
## escribe los números la página (ClawCareState.grouped lo llama).
static func grouped(x: float) -> String:
	var t := Js.to_fixed(absf(x), 0)
	if t.length() > 4:
		var out := ""
		while t.length() > 3:
			out = " " + t.substr(t.length() - 3) + out
			t = t.substr(0, t.length() - 3)
		t += out
	return ("-" if x < 0.0 else "") + t


## Cuánto tarda en volver a crecer lo que falta: la garra rota de una rapaz, 2-3 meses (Samour 2006); lo que se ha
## cortado de más, al ritmo de crecimiento de la especie. null si no falta nada.
func _regrow(verdict: String) -> Variant:
	if _reforged:
		return null
	var g: Dictionary = _animal.growth_mm_day
	var missing := maxf(_L_nat - _s_apex, 0.0)
	if verdict in ["rota", "reconstruida"] and _animal.has("regrow_days"):
		var rd: Dictionary = _animal.regrow_days
		return { "days": float(rd.value), "min": float(rd.min), "max": float(rd.max), "text": "Una garra rota tarda de 2 a 3 meses en rehacerse.", "source": String(rd.source), "quality": String(rd.quality) }
	if missing <= 0.0 and not (verdict in ["rota", "reconstruida", "corta_sangra"]):
		return null
	var days := missing / float(g.value) if float(g.value) > 0.0 else INF
	return { "days": days, "text": "Faltan %s mm: a %s mm al día, unos %s días." % [Js.to_fixed(missing, 1), Js.to_fixed(float(g.value), 2), Js.to_fixed(days, 0)], "source": String(g.source), "quality": String(g.quality) }
