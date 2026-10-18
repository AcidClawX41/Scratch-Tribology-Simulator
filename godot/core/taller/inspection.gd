## Taller · inspección de la pieza torneada contra su plano (unidad 5).
##
## inspect_part(perfil, plano) lee el perfil del torno (CONTRATOS.md: z0, dz, r, ring_ra, ring_pass…) y mide como
## un inspector con micrómetro, calibre y rugosímetro:
##   - Diámetro: tamaño local de cada anillo = 2·(cresta más alta) en una ventana de ANVIL_MM centrada en él, como
##     un palpador de ese ancho (se apoya en las crestas; los valles son rugosidad, no tamaño). Junto a un hombro
##     (esquina interior, hacia un diámetro mayor) se deja CORNER_MM sin medir: ahí está el acuerdo del radio de la
##     punta (rε ≤ 1,2 mm en el catálogo), que es una esquina, no un error de diámetro. Una ranura más ancha
##     que el palpador se detecta esté donde esté; una más estrecha no cambia la medida. Se exige que TODOS los
##     tamaños locales caigan en la tolerancia; «measured» es el más alejado del centro de la tolerancia.
##   - Longitud (desde la cara): la cara es el plano refrentado, el último anillo cuyo radio pasa de la mitad del
##     radio nominal de la cara. Así el pezón que deja refrentar sin pasar el eje (radio ≤ rε) no se toma por la
##     cara; se informa aparte en center_nipple. Un escalón se localiza donde el radio
##     cruza la media de los radios MEDIDOS a SEARCH_MM a cada lado; un quiebro sin escalón (el inicio del cono),
##     cortando las rectas ajustadas a cada lado.
##   - Chaflán a 45°: c = √(2·A), con A el área que falta respecto al cilindro medido junto a la cara.
##   - Radio cóncavo del hombro: R = √(A/(1 − π/4)), con A el área que añade el redondeo sobre el cilindro
##     medido.
##   - Cono: recta ajustada a los radios de la zona; diámetros en sus dos extremos.
##   - Rosca exterior (fase 2): el perfil es su sección axial, con un surco en V cada paso. Se buscan los surcos y se
##     mide como con un micrómetro de roscas y un proyector de perfiles: Ø exterior (crestas), Ø de fondo (surcos de
##     profundidad completa), paso (recta ajustada a los centros de los surcos), Ø medio (radio al que el surco mide
##     medio paso de ancho, la definición del Ø medio simple de ISO 5408) y rosca completa (de la cara al último surco
##     de profundidad completa).
##   - Ra: regla del 16 % de ISO 4288 (la superficie es buena si no más del 16 % de las medidas supera el límite),
##     solo con los anillos mecanizados (ring_pass ≥ 1) y con material. «measured» es el percentil 84 de sus Ra:
##     measured ≤ required ⇔ regla cumplida (con la holgura de redondeo del float32 de ring_ra).
##   - deviation_map: desviación radial de cada anillo respecto al nominal (µm; + sobra material, − pasado). Donde
##     el nominal cambia dentro del anillo (escalones, chaflanes) se compara con el intervalo nominal del anillo,
##     para que un medio anillo de diferencia de rejilla no pinte un falso error.
##   - ring_state: 0 bien o sin tolerancia propia, 1 sobra material fuera de tolerancia, 2 pasado (en las zonas de
##     diámetros, con el tamaño local de cada anillo, y del cono).
##   - score (0-10): media ponderada (diámetros ×2; resto de cotas y cada zona de Ra ×1). Una cota correcta vale 1;
##     una fuera de tolerancia, como mucho 0,5, y nada si se sale más que el ancho de su tolerancia.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Drawing = preload("res://core/taller/drawing.gd")

const MARGIN_MM := 0.1  # se excluye junto a los extremos de cada zona (transiciones)
const CORNER_MM := 1.2  # se excluye junto a una esquina interior: el acuerdo de la punta (rε máximo del catálogo)
const CORNER_PROBE_MM := 0.5  # distancia a la que se mira el plano para saber si el vecino es más grande
const FACE_SHARE := 0.5  # la cara es el último anillo con más de esta fracción del radio nominal de la cara
const ANVIL_MM := 1.0  # ancho del palpador con el que se mide el tamaño local de los diámetros
const SEARCH_MM := 1.5  # búsqueda de un escalón alrededor de su posición nominal
const STEP_MIN_MM := 0.01  # diferencia de radio mínima para que haya escalón
const FIT_SPAN_MM := 5.0  # tramo de ajuste a cada lado de un quiebro
const RA_SHARE := 16  # regla del 16 % (ISO 4288:1996, 5.2)
const RA_REL_EPS := 1e-6  # ring_ra es float32: 3,2 se guarda como 3,2000000477
const R_EPS := 1e-6
const TOL_EPS := 1e-9
const SRC_RA := "ISO 4288:1996, 5.2: regla del 16 %"
const THREAD_GROOVE_MM := 0.02  # un anillo por debajo de la cresta más que esto es surco de la rosca
const THREAD_FULL_MM := 0.02  # un surco es de profundidad completa si su fondo está a esto del más hondo
const THREAD_KINDS := {
	"thread_major": "major", "thread_pitch_diameter": "d2", "thread_minor": "minor", "thread_pitch": "pitch",
	"thread_length": "length",
}


static func inspect_part(profile: Dictionary, drawing: Dictionary) -> Dictionary:
	var r: PackedFloat64Array = profile.get("r", PackedFloat64Array())
	var ctx := {
		"z0": float(profile.get("z0", 0.0)), "dz": float(profile.get("dz", Drawing.DZ_DEFAULT)), "r": r,
		"n": r.size(),
	}
	var face := _face_z(ctx, drawing)
	var results := {}
	var cyl_r := {}
	var thread := {}
	for f in drawing["features"]:
		if f["kind"] == "diameter":
			var res := _diameter(ctx, drawing, f)
			results[f["id"]] = res
			cyl_r[f["id"]] = res["cyl_r"]
	for f in drawing["features"]:
		match str(f["kind"]):
			"length":
				results[f["id"]] = _length(ctx, drawing, f, face)
			"chamfer":
				results[f["id"]] = _chamfer(ctx, f, face, _adjacent_r(drawing, cyl_r, f["z_to"] - 0.01))
			"radius":
				results[f["id"]] = _radius(ctx, drawing, f, _adjacent_r(drawing, cyl_r, f["z_from"] + 0.01))
			"cone":
				results[f["id"]] = _cone(ctx, f)
			"thread_major", "thread_pitch_diameter", "thread_minor", "thread_pitch", "thread_length":
				if thread.is_empty():
					thread = _thread(ctx, drawing, face)
				results[f["id"]] = _result(f, float(thread.get(THREAD_KINDS[f["kind"]], NAN)))
	var maps := _maps(ctx, drawing, results)
	var features: Array[Dictionary] = []
	for f in drawing["features"]:
		var res: Dictionary = results[f["id"]]
		res.erase("local")
		res.erase("map_local")
		res.erase("cyl_r")
		res.erase("zone")
		features.append(res)
	var ra := _ra(ctx, profile.get("ring_ra"), profile.get("ring_pass"), drawing)
	var passed := true
	var got := 0.0
	var total := 0.0
	for f in features:
		passed = passed and f["ok"]
		var w := 2.0 if f["kind"] == "diameter" else 1.0
		total += w
		got += w * _credit(f["ok"], f["measured"], f["lower"], f["upper"])
	for z in ra:
		passed = passed and z["ok"]
		total += 1.0
		got += _credit(z["ok"], z["measured"], 0.0, z["required"])
	var score := Js.js_round(100.0 * got / total) / 10.0 if total > 0.0 else 0.0
	return {
		"features": features,
		"ra": ra,
		"deviation_map": maps["map"],
		"ring_state": maps["state"],
		"face_z": face,
		"center_nipple": _center_nipple(ctx, face),
		"thread": thread if not thread.is_empty() else null,
		"passed": passed,
		"score": score,
	}


# --- rejilla ----------------------------------------------------------------------------------------------------


static func _z(ctx: Dictionary, i: int) -> float:
	return float(ctx["z0"]) + i * float(ctx["dz"])


## Índices [desde, hasta] de los anillos con z ∈ [za, zb] (hasta < desde si no hay ninguno).
static func _span(ctx: Dictionary, za: float, zb: float) -> Vector2i:
	var z0: float = ctx["z0"]
	var dz: float = ctx["dz"]
	var n: int = ctx["n"]
	var i0 := maxi(0, int(ceil((za - z0) / dz - 1e-9)))
	var i1 := mini(n - 1, int(floor((zb - z0) / dz + 1e-9)))
	return Vector2i(i0, i1)


## Radio del anillo más cercano a z; NAN fuera de la rejilla.
static func _r_at(ctx: Dictionary, z: float) -> float:
	var i := int(roundf((z - float(ctx["z0"])) / float(ctx["dz"])))
	if i < 0 or i >= int(ctx["n"]):
		return NAN
	var r: PackedFloat64Array = ctx["r"]
	return r[i]


## z de la cara: el plano refrentado, el último anillo cuyo radio pasa de FACE_SHARE del radio nominal de la cara
## (el del plano justo por dentro de Z0). Un pezón en el centro no la desplaza. NAN si el perfil está vacío.
static func _face_z(ctx: Dictionary, drawing: Dictionary) -> float:
	var r: PackedFloat64Array = ctx["r"]
	var r_face_nom := Drawing.nominal_radius(drawing, -1e-3)
	var threshold := maxf(R_EPS, FACE_SHARE * r_face_nom)
	for i in range(int(ctx["n"]) - 1, -1, -1):
		if r[i] > threshold:
			return _z(ctx, i)
	return NAN


## Pezón del centro por delante de la cara (refrentar hasta X0 lo deja: la punta redonda no llega al eje).
## { diameter_mm, height_mm } o null si no hay.
static func _center_nipple(ctx: Dictionary, face: float) -> Variant:
	if is_nan(face):
		return null
	var r: PackedFloat64Array = ctx["r"]
	# hasta el último anillo de la rejilla (con INF, int(floor(INF)) es el entero más negativo y el tramo sale vacío)
	var sp := _span(ctx, face + 0.5 * float(ctx["dz"]), _z(ctx, int(ctx["n"]) - 1))
	var r_max := 0.0
	var z_top := NAN
	for i in range(sp.x, sp.y + 1):
		if r[i] > R_EPS:
			r_max = maxf(r_max, r[i])
			z_top = _z(ctx, i)
	if is_nan(z_top):
		return null
	return { "diameter_mm": 2.0 * r_max, "height_mm": z_top - face }


## Tamaño local (en radio) de cada anillo de [za, zb]: la cresta más alta en una ventana de ANVIL_MM centrada en
## el anillo y recortada a la zona. { i0, i1, crest } con crest[k] el del anillo i0 + k (vacío si no hay anillos).
static func _local_crests(ctx: Dictionary, za: float, zb: float) -> Dictionary:
	var sp := _span(ctx, za, zb)
	var crest := PackedFloat64Array()
	if sp.y < sp.x:
		return { "i0": sp.x, "i1": sp.y, "crest": crest }
	var r: PackedFloat64Array = ctx["r"]
	var half := maxi(0, int(roundf(ANVIL_MM / float(ctx["dz"]) / 2.0)))
	crest.resize(sp.y - sp.x + 1)
	for i in range(sp.x, sp.y + 1):
		var best := r[i]
		for k in range(maxi(sp.x, i - half), mini(sp.y, i + half) + 1):
			best = maxf(best, r[k])
		crest[i - sp.x] = best
	return { "i0": sp.x, "i1": sp.y, "crest": crest }


## Resultado de una cota: los campos del contrato y los límites en mm.
static func _result(f: Dictionary, measured: float) -> Dictionary:
	var nominal: float = f["nominal"]
	var upper: float = nominal + float(f["tol"]["upper_um"]) / 1000.0
	var lower: float = nominal + float(f["tol"]["lower_um"]) / 1000.0
	var ok := not is_nan(measured) and measured <= upper + TOL_EPS and measured >= lower - TOL_EPS
	return {
		"id": f["id"], "kind": f["kind"], "label": f["label"], "iso": f["iso"],
		"measured": measured, "nominal": nominal, "upper": upper, "lower": lower, "ok": ok,
		"deviation_um": (measured - nominal) * 1000.0,
	}


# --- cotas ------------------------------------------------------------------------------------------------------


## Zona cilíndrica de un diámetro: los tramos rectos del contorno con r = nominal/2 dentro de [z_to, z_from].
static func _cyl_zone(drawing: Dictionary, f: Dictionary) -> Vector2:
	var r_nom: float = float(f["nominal"]) / 2.0
	var zl := minf(f["z_from"], f["z_to"])
	var zh := maxf(f["z_from"], f["z_to"])
	var a := INF
	var b := -INF
	for seg in drawing["contour"]:
		if seg["kind"] != "line" or absf(float(seg["r_hi"]) - r_nom) > 1e-9 or absf(float(seg["r_lo"]) - r_nom) > 1e-9:
			continue
		var sa := maxf(zl, seg["z_lo"])
		var sb := minf(zh, seg["z_hi"])
		if sa < sb:
			a = minf(a, sa)
			b = maxf(b, sb)
	return Vector2(a, b)


static func _diameter(ctx: Dictionary, drawing: Dictionary, f: Dictionary) -> Dictionary:
	var zone := _cyl_zone(drawing, f)
	var local := { "i0": 0, "i1": -1, "crest": PackedFloat64Array() }
	# el mapa de estados pinta toda la zona (también el acuerdo de la esquina, que sobra respecto al canto vivo)
	var map_local := local
	if zone.x < zone.y:
		# junto a una esquina interior (el vecino del plano es más grande) queda el acuerdo de la punta: no se mide
		var r_nom: float = float(f["nominal"]) / 2.0
		# (se mira el plano a CORNER_PROBE_MM del borde: un redondeo tangente apenas sube junto a la tangencia)
		var m_lo := CORNER_MM if Drawing.nominal_radius(drawing, zone.x - CORNER_PROBE_MM) > r_nom + 1e-6 else MARGIN_MM
		var m_hi := CORNER_MM if Drawing.nominal_radius(drawing, zone.y + CORNER_PROBE_MM) > r_nom + 1e-6 else MARGIN_MM
		map_local = _local_crests(ctx, zone.x + MARGIN_MM, zone.y - MARGIN_MM)
		local = _local_crests(ctx, zone.x + m_lo, zone.y - m_hi) if zone.y - zone.x > m_lo + m_hi else map_local
	var crest: PackedFloat64Array = local["crest"]
	if crest.is_empty():
		var empty := _result(f, NAN)
		empty["local"] = local
		empty["map_local"] = map_local
		empty["cyl_r"] = NAN
		return empty
	var upper: float = float(f["nominal"]) + float(f["tol"]["upper_um"]) / 1000.0
	var lower: float = float(f["nominal"]) + float(f["tol"]["lower_um"]) / 1000.0
	var mid := (upper + lower) / 2.0
	var worst := 2.0 * crest[0]
	var smin := INF
	var smax := -INF
	for c in crest:
		var s := 2.0 * c
		smin = minf(smin, s)
		smax = maxf(smax, s)
		if absf(s - mid) > absf(worst - mid):
			worst = s
	var res := _result(f, worst)
	res["ok"] = smin >= lower - TOL_EPS and smax <= upper + TOL_EPS
	res["measured_min"] = smin
	res["measured_max"] = smax
	res["local"] = local
	res["map_local"] = map_local
	# radio del cilindro para el chaflán y el redondeo contiguos: la mediana de los tamaños locales, que no se deja
	# arrastrar por el trozo de zona que pise un chaflán más largo de lo debido
	var sorted := crest.duplicate()
	sorted.sort()
	res["cyl_r"] = sorted[int(sorted.size() / 2.0)]
	return res


## Radio medido del cilindro contiguo (el diámetro cuya zona contiene z_probe); si no se midió, el nominal.
static func _adjacent_r(drawing: Dictionary, cyl_r: Dictionary, z_probe: float) -> float:
	for d in drawing["features"]:
		if d["kind"] != "diameter":
			continue
		if z_probe <= maxf(d["z_from"], d["z_to"]) and z_probe >= minf(d["z_from"], d["z_to"]):
			var v: float = cyl_r.get(d["id"], NAN)
			return v if not is_nan(v) else float(d["nominal"]) / 2.0
	return Drawing.nominal_radius(drawing, z_probe)


## Posición medida de un rasgo del contorno en z_nom: la cara (si a su derecha no hay pieza en el plano), un
## escalón o un quiebro (según el plano), medidos en el perfil.
static func _landmark(ctx: Dictionary, drawing: Dictionary, z_nom: float, face: float) -> float:
	var r_left := Drawing.nominal_radius(drawing, z_nom - 1e-4)
	var r_right := Drawing.nominal_radius(drawing, z_nom + 1e-4)
	if r_right <= R_EPS:
		return face
	if absf(r_left - r_right) > 1e-3:
		return _step(ctx, z_nom)
	return _kink(ctx, z_nom)


## Escalón: con los radios medidos a SEARCH_MM a cada lado de z_nom, primer anillo (desde la cara hacia el plato)
## que cruza su media. NAN si no hay diferencia de radio (no hay escalón que medir).
static func _step(ctx: Dictionary, z_nom: float) -> float:
	var r_right := _r_at(ctx, z_nom + SEARCH_MM)
	var r_left := _r_at(ctx, z_nom - SEARCH_MM)
	if is_nan(r_right) or is_nan(r_left) or absf(r_left - r_right) < STEP_MIN_MM:
		return NAN
	var mid := (r_left + r_right) / 2.0
	var grows_left := r_left > r_right
	var sp := _span(ctx, z_nom - SEARCH_MM, z_nom + SEARCH_MM)
	var r: PackedFloat64Array = ctx["r"]
	for i in range(sp.y, sp.x - 1, -1):
		if (grows_left and r[i] >= mid) or (not grows_left and r[i] <= mid):
			return _z(ctx, i)
	return NAN


## Quiebro: intersección de las rectas ajustadas a los radios a cada lado de z_nom.
static func _kink(ctx: Dictionary, z_nom: float) -> float:
	var right := _fit(ctx, z_nom + MARGIN_MM, z_nom + FIT_SPAN_MM)
	var left := _fit(ctx, z_nom - FIT_SPAN_MM, z_nom - MARGIN_MM)
	if right.is_empty() or left.is_empty():
		return NAN
	var db: float = float(right["b"]) - float(left["b"])
	if absf(db) < 1e-9:
		return NAN
	return (float(left["a"]) - float(right["a"])) / db


## Recta r = a + b·z por mínimos cuadrados sobre los anillos de [za, zb]. {} si hay menos de dos.
static func _fit(ctx: Dictionary, za: float, zb: float) -> Dictionary:
	var sp := _span(ctx, za, zb)
	var n := sp.y - sp.x + 1
	if n < 2:
		return {}
	var r: PackedFloat64Array = ctx["r"]
	var mz := 0.0
	var mr := 0.0
	for i in range(sp.x, sp.y + 1):
		mz += _z(ctx, i) / n
		mr += r[i] / n
	var szz := 0.0
	var szr := 0.0
	for i in range(sp.x, sp.y + 1):
		var dzv := _z(ctx, i) - mz
		szz += dzv * dzv
		szr += dzv * (r[i] - mr)
	if szz <= 0.0:
		return {}
	var b := szr / szz
	return { "a": mr - b * mz, "b": b }


static func _length(ctx: Dictionary, drawing: Dictionary, f: Dictionary, face: float) -> Dictionary:
	var z_a := _landmark(ctx, drawing, f["z_from"], face)
	var z_b := _landmark(ctx, drawing, f["z_to"], face)
	return _result(f, z_a - z_b)


## Chaflán a 45°: c = √(2A); A por trapecios desde la cara (el anillo de la cara con medio peso).
static func _chamfer(ctx: Dictionary, f: Dictionary, face: float, r_cyl: float) -> Dictionary:
	if is_nan(face):
		return _result(f, NAN)
	var r: PackedFloat64Array = ctx["r"]
	var dz: float = ctx["dz"]
	var sp := _span(ctx, face - 2.0 * float(f["nominal"]) - 0.5, face + TOL_EPS)
	var area := 0.0
	for i in range(sp.x, sp.y + 1):
		var gap := maxf(0.0, r_cyl - r[i])
		area += gap * dz * (0.5 if i == sp.y else 1.0)
	return _result(f, sqrt(2.0 * area))


## Radio cóncavo del hombro: R = √(A/(1 − π/4)), con A el exceso sobre el cilindro medido entre el hombro y
## 2·R nominal hacia la cara (el primer medio intervalo, con el valor del primer anillo).
static func _radius(ctx: Dictionary, drawing: Dictionary, f: Dictionary, r_cyl: float) -> Dictionary:
	var z_sh := _landmark(ctx, drawing, f["z_to"], NAN)
	if is_nan(z_sh):
		return _result(f, NAN)
	var r: PackedFloat64Array = ctx["r"]
	var dz: float = ctx["dz"]
	var r_nom: float = f["nominal"]
	var sp := _span(ctx, z_sh + dz * 0.5, z_sh + 2.0 * r_nom)
	if sp.y < sp.x:
		return _result(f, NAN)
	var area := 0.0
	for i in range(sp.x, sp.y + 1):
		area += clampf(r[i] - r_cyl, 0.0, 2.0 * r_nom) * dz
	area += clampf(r[sp.x] - r_cyl, 0.0, 2.0 * r_nom) * dz / 2.0
	area -= clampf(r[sp.y] - r_cyl, 0.0, 2.0 * r_nom) * dz / 2.0
	return _result(f, sqrt(maxf(area, 0.0) / (1.0 - PI / 4.0)))


## Cono: recta ajustada a los radios de la zona; «measured» es el diámetro en z_to y measured_from en z_from.
static func _cone(ctx: Dictionary, f: Dictionary) -> Dictionary:
	var zl := minf(f["z_from"], f["z_to"])
	var zh := maxf(f["z_from"], f["z_to"])
	var line := _fit(ctx, zl + MARGIN_MM, zh - MARGIN_MM)
	var sp := _span(ctx, zl + MARGIN_MM, zh - MARGIN_MM)
	if line.is_empty():
		var empty := _result(f, NAN)
		empty["zone"] = sp
		return empty
	var d_to := 2.0 * (float(line["a"]) + float(line["b"]) * float(f["z_to"]))
	var d_from := 2.0 * (float(line["a"]) + float(line["b"]) * float(f["z_from"]))
	var res := _result(f, d_to)
	var nom_from: float = f["nominal_from"]
	var up_from: float = nom_from + float(f["tol"]["upper_um"]) / 1000.0
	var lo_from: float = nom_from + float(f["tol"]["lower_um"]) / 1000.0
	var ok_from := d_from <= up_from + TOL_EPS and d_from >= lo_from - TOL_EPS
	res["ok"] = res["ok"] and ok_from
	res["measured_from"] = d_from
	res["nominal_from"] = nom_from
	var dev_from := (d_from - nom_from) * 1000.0
	if absf(dev_from) > absf(float(res["deviation_um"])):
		res["deviation_um"] = dev_from
	res["zone"] = sp
	return res


# --- rosca ------------------------------------------------------------------------------------------------------


## Zona roscada del plano: [z_lo, z_hi] de los tramos con thread = true, y z_cyl, donde empieza la parte cilíndrica
## (detrás del chaflán de entrada). Vector3(NAN…) si el plano no tiene rosca.
static func _thread_zone(drawing: Dictionary) -> Vector3:
	var lo := INF
	var hi := -INF
	var cyl := -INF
	for seg in drawing["contour"]:
		if not seg.get("thread", false):
			continue
		lo = minf(lo, float(seg["z_lo"]))
		hi = maxf(hi, float(seg["z_hi"]))
		if seg["kind"] == "line" and absf(float(seg["r_hi"]) - float(seg["r_lo"])) < 1e-9:
			cyl = maxf(cyl, float(seg["z_hi"]))
	if lo > hi:
		return Vector3(NAN, NAN, NAN)
	return Vector3(lo, hi, cyl if is_finite(cyl) else hi)


## Mide la rosca en la sección axial del perfil. Devuelve { major, minor, pitch, d2, length, grooves, full } (mm;
## NAN lo que no se pueda medir) o {} si el plano no tiene rosca.
static func _thread(ctx: Dictionary, drawing: Dictionary, face: float) -> Dictionary:
	var zone := _thread_zone(drawing)
	if is_nan(zone.x):
		return {}
	var out := { "major": NAN, "minor": NAN, "pitch": NAN, "d2": NAN, "length": NAN, "grooves": 0, "full": 0 }
	if is_nan(face):
		return out  # perfil vacío: no hay cara desde la que medir
	var pitch_nom: float = drawing.get("thread", {}).get("pitch_mm", 1.0)
	var r: PackedFloat64Array = ctx["r"]
	var sp := _span(ctx, zone.x, minf(zone.z, face))
	if sp.y - sp.x < 4:
		return out
	var top := -INF
	for i in range(sp.x, sp.y + 1):
		top = maxf(top, r[i])
	# surcos: tramos de anillos por debajo de la cresta; los que tocan los bordes de la zona están cortados
	var grooves: Array = []
	var i := sp.x
	while i <= sp.y:
		if r[i] >= top - THREAD_GROOVE_MM:
			i += 1
			continue
		var a := i
		while i <= sp.y and r[i] < top - THREAD_GROOVE_MM:
			i += 1
		var b := i - 1
		if a > sp.x and b < sp.y:
			var root := INF
			for k in range(a, b + 1):
				root = minf(root, r[k])
			grooves.append({ "a": a, "b": b, "root": root })
	out["grooves"] = grooves.size()
	if grooves.size() < 2:
		return out
	var deepest := INF
	for g in grooves:
		deepest = minf(deepest, float(g["root"]))
	var full: Array = []
	for g in grooves:
		if float(g["root"]) <= deepest + THREAD_FULL_MM:
			full.append(g)
	out["full"] = full.size()
	# crestas: lo más alto entre dos surcos seguidos
	var crests := PackedFloat64Array()
	for k in range(1, grooves.size()):
		var c := -INF
		for j in range(int(grooves[k - 1]["b"]) + 1, int(grooves[k]["a"])):
			c = maxf(c, r[j])
		if is_finite(c):
			crests.append(c)
	if crests.size() > 0:
		out["major"] = 2.0 * _median(crests)
	if full.size() < 2:
		return out
	var roots := PackedFloat64Array()
	var centers := PackedFloat64Array()
	for g in full:
		roots.append(g["root"])
		var mid := 0.5 * (float(g["root"]) + top)
		centers.append(0.5 * (_flank_z(ctx, g, mid, true) + _flank_z(ctx, g, mid, false)))
	out["minor"] = 2.0 * _median(roots)
	# paso: recta ajustada a los centros de los surcos completos, numerados por su distancia en pasos nominales
	var n := centers.size()
	var mk := 0.0
	var mz := 0.0
	var ks := PackedFloat64Array()
	for k in n:
		ks.append(roundf((centers[k] - centers[0]) / pitch_nom))
		mk += ks[k] / n
		mz += centers[k] / n
	var skk := 0.0
	var skz := 0.0
	for k in n:
		skk += (ks[k] - mk) * (ks[k] - mk)
		skz += (ks[k] - mk) * (centers[k] - mz)
	if skk <= 0.0:
		return out
	var pitch := absf(skz / skk)
	out["pitch"] = pitch
	# Ø medio: en cada surco completo, el radio al que mide medio paso de ancho (bisección: el ancho crece con el radio)
	var ys := 0.0
	for g in full:
		var lo: float = g["root"]
		var hi := top
		for it in 60:
			var y := 0.5 * (lo + hi)
			var w := _flank_z(ctx, g, y, false) - _flank_z(ctx, g, y, true)
			if w < 0.5 * pitch:
				lo = y
			else:
				hi = y
		ys += 0.5 * (lo + hi) / full.size()
	out["d2"] = 2.0 * ys
	# rosca completa: de la cara al centro del último surco de profundidad completa (el más cercano al plato)
	var last := INF
	for c in centers:
		last = minf(last, c)
	out["length"] = face - last
	return out


## z del flanco de un surco a la altura y (interpolación lineal entre anillos): left = true, el flanco del lado del
## plato (índices menores); false, el del lado de la cara.
static func _flank_z(ctx: Dictionary, g: Dictionary, y: float, left: bool) -> float:
	var r: PackedFloat64Array = ctx["r"]
	var j := int(g["a"])  # desde el fondo del surco hacia fuera
	for k in range(int(g["a"]), int(g["b"]) + 1):
		if r[k] < r[j]:
			j = k
	var step := -1 if left else 1
	while j + step >= 0 and j + step < int(ctx["n"]) and r[j + step] < y:
		j += step
	var k2 := j + step
	if k2 < 0 or k2 >= int(ctx["n"]) or r[k2] == r[j]:
		return _z(ctx, j)
	var t := (y - r[j]) / (r[k2] - r[j])
	return _z(ctx, j) + t * float(step) * float(ctx["dz"])


static func _median(v: PackedFloat64Array) -> float:
	var s := v.duplicate()
	s.sort()
	var n := s.size()
	return s[n / 2] if n % 2 == 1 else 0.5 * (s[n / 2 - 1] + s[n / 2])


# --- rugosidad --------------------------------------------------------------------------------------------------


static func _ra(ctx: Dictionary, ring_ra: Variant, ring_pass: Variant, drawing: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r: PackedFloat64Array = ctx["r"]
	for zone in drawing["ra"]:
		var required: float = zone["required_um"]
		var item := {
			"zone": zone["zone"], "measured": NAN, "mean": NAN, "required": required, "share_over": NAN,
			"ok": false, "general": zone["general"], "rule": SRC_RA, "machined_rings": 0,
		}
		out.append(item)
		if ring_ra == null:
			continue
		var zl := minf(zone["z_from"], zone["z_to"])
		var zh := maxf(zone["z_from"], zone["z_to"])
		var sp := _span(ctx, zl + MARGIN_MM, zh - MARGIN_MM)
		var vals: Array[float] = []
		for i in range(sp.x, sp.y + 1):
			if i >= ring_ra.size() or r[i] <= R_EPS:
				continue  # sin material no hay superficie que medir
			if ring_pass != null and (i >= ring_pass.size() or int(ring_pass[i]) < 1):
				continue  # superficie de bruto: no se ha mecanizado
			vals.append(float(ring_ra[i]))
		item["machined_rings"] = vals.size()
		if vals.is_empty():
			continue
		vals.sort()
		var n := vals.size()
		var p84: float = vals[int((84 * n + 99) / 100) - 1]  # percentil 84 con enteros: ceil(0,84·n) − 1
		var limit := required * (1.0 + RA_REL_EPS)
		var mean := 0.0
		var over := 0
		for v in vals:
			mean += v / n
			if v > limit:
				over += 1
		item["measured"] = p84
		item["mean"] = mean
		item["share_over"] = float(over) / n
		item["ok"] = over * 100 <= RA_SHARE * n
	return out


# --- mapas y nota -----------------------------------------------------------------------------------------------


static func _maps(ctx: Dictionary, drawing: Dictionary, results: Dictionary) -> Dictionary:
	var n: int = ctx["n"]
	var dz: float = ctx["dz"]
	var r: PackedFloat64Array = ctx["r"]
	var dev := PackedFloat32Array()
	var state := PackedByteArray()
	dev.resize(n)
	state.resize(n)
	var tz := _thread_zone(drawing)
	var th: Dictionary = drawing.get("thread", {})
	for i in n:
		var z := _z(ctx, i)
		var band := Drawing.nominal_range(drawing, z - dz / 2.0, z + dz / 2.0)
		if not is_nan(tz.x) and z >= tz.x - 1e-9 and z <= tz.y + 1e-9 and not th.is_empty():
			# zona roscada: bien entre el fondo mínimo y el exterior máximo
			band = Vector2(float(th["d3_min_mm"]) / 2.0, float(th["d_max_mm"]) / 2.0)
		var d := 0.0
		if r[i] > band.y:
			d = r[i] - band.y
		elif r[i] < band.x:
			d = r[i] - band.x
		dev[i] = d * 1000.0
		state[i] = 0
	for f in drawing["features"]:
		var res: Dictionary = results[f["id"]]
		var up_um: float = f["tol"]["upper_um"]
		var lo_um: float = f["tol"]["lower_um"]
		if f["kind"] == "diameter":
			var local: Dictionary = res.get("map_local", res["local"])
			var crest: PackedFloat64Array = local["crest"]
			var nom_r: float = float(f["nominal"]) / 2.0
			for k in crest.size():
				state[int(local["i0"]) + k] = _state(crest[k], nom_r + up_um / 2000.0, nom_r + lo_um / 2000.0)
		elif f["kind"] == "cone" and res.has("zone"):
			var sp: Vector2i = res["zone"]
			for i in range(sp.x, sp.y + 1):
				var nom_r := Drawing.nominal_radius(drawing, _z(ctx, i))
				state[i] = _state(r[i], nom_r + up_um / 2000.0, nom_r + lo_um / 2000.0)
	return { "map": dev, "state": state }


static func _state(value: float, upper: float, lower: float) -> int:
	if value > upper + TOL_EPS:
		return 1
	if value < lower - TOL_EPS:
		return 2
	return 0


## Crédito de una cota o de una zona de Ra: 1 si está bien; si no, hasta 0,5 según cuánto se sale respecto al
## ancho de su tolerancia (0 si no se pudo medir).
static func _credit(ok: bool, measured: float, lower: float, upper: float) -> float:
	if ok:
		return 1.0
	if is_nan(measured):
		return 0.0
	var width := maxf(upper - lower, 1e-12)
	var excess := maxf(lower - measured, measured - upper)
	return 0.5 * clampf(1.0 - excess / width, 0.0, 1.0)
