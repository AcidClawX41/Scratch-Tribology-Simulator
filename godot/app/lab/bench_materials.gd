## Guion visual de los materiales de la 2.0 en el banco (bench.gd lo pinta): la uña que se dobla o se parte al llegar a su
## carga de cesión, las grietas que salen cuando la carga pasa de su umbral y crecen con ella, la ventanilla templada que
## estalla en un instante y deja caer los trozos del hueco, el parabrisas que se agrieta en estrella sin caer, el hoyuelo
## de la abolladura que se hunde al golpear, la huella que sube al levantar la punta y la punta frágil que se mella.
## Los umbrales, los tamaños y el orden salen del resultado (res) y de los dibujos de core/lab/art_materials.gd; aquí solo
## se decide cuándo se ve cada cosa (el ritmo de la animación), que es dibujo y no dato:
##   · al rayar, la carga crece durante el primer cuarto del recorrido (RAMP) y cada fenómeno aparece cuando la carga llega
##     a su umbral del resultado: la cesión de la uña (nail.breakN; la carga pedida es breakN·stressMPa/strengthMPa), la
##     carga que abre la grieta de la ventanilla (pierceN) o la parte por flexión (bendN), la de las grietas de Hertz
##     (hertzN), la del colapso de la chapa (collapseN) y la fuerza de lado que mella la punta (chipN frente a lateralN);
##   · al apretar, todo empieza al tocar la superficie y la carga llega en LOAD_MS (en un golpe, el pico llega al
##     impacto): las grietas radiales y el cono crecen como la carga elevada a 2/3 (Anstis et al. 1981;
##     cone_radius_um), y la ventanilla estalla cuando la carga llega a la que abre la grieta;
##   · la uña doblada gira BEND_DEG en la raíz del borde libre (15-25° en la guía: estimación); la que se parte se suelta
##     y cae a la losa;
##   · una grieta cruza el vidrio a ~1500 m/s: en pantalla, instantáneo (un destello de FLASH_MS);
##   · la huella: al rayar, la lupa corta el surco por su mitad y enseña pasar la punta, que se hunde depthUm y al irse deja
##     residualDepthUm; al apretar, el fondo sube al levantar la punta (la retirada de bench.gd).
## Al rayar, todo acaba dentro del recorrido (SCRATCH_MS): el banco queda quieto cuando acaba el ensayo.
## Funciones puras (sin nodos): los tests piden el guion y la pose de cualquier resultado en cualquier momento; draw_*
## pintan sobre el CanvasItem que se les pasa (el banco, en su _draw).
## Uso: const BenchMaterials = preload("res://app/lab/bench_materials.gd"); var pl := BenchMaterials.plan(res, tool, x1, x2)
extends RefCounted

const Ui = preload("res://app/common/ui.gd")
const Js = preload("res://core/shared/js.gd")
const ArtMaterials = preload("res://core/lab/art_materials.gd")

## Duraciones del banco (bench.gd): el recorrido al rayar, la bajada al punzar y el fin del ensayo (LabState.RUN_MS).
const SCRATCH_MS := 1100.0
const PUNCTURE_MS := 900.0
## Al punzar, la punta baja de GY − 34 a GY + 1,5 unidades (bench.gd): toca la superficie en esta fracción del recorrido.
const TOUCH_E := 34.0 / 35.5
## La carga crece durante esta fracción del recorrido al rayar; al apretar, en LOAD_MS tras tocar; en un golpe, el pico
## llega al impacto (y las grietas salen en STRIKE_MS).
const RAMP := 0.25
const LOAD_MS := 150.0
const STRIKE_MS := 40.0
## La uña doblada (grados de dibujo) y lo que tarda en doblarse; la frágil, lo que flexa antes de partirse y lo que tarda
## el trozo en caer a la losa (y girar hasta quedar tumbado).
const BEND_DEG := 20.0
const BEND_MS := 180.0
const PRE_SNAP_DEG := 6.0
const SNAP_MS := 520.0
## La uña libre de la uña de perfil sale de la losa a este ángulo (Art.nail_side_art): tumbada, gira eso.
const NAIL_ATTACK_DEG := 35.0
## El destello del vidrio que estalla, la caída de los trozos del hueco (empieza FALL_DELAY después) y el hundimiento
## de la abolladura.
const FLASH_MS := 160.0
const FALL_DELAY := 60.0
const FALL_MS := 700.0
const DENT_MS := 200.0
## La lupa aparece en LUPA_MS; al punzar, LUPA_DELAY tras tocar; al rayar, cuando va por LUPA_E del recorrido.
const LUPA_MS := 250.0
const LUPA_DELAY := 200.0
const LUPA_E := 0.7
## La punta cruzando el corte de la lupa al rayar y la estela del surco bajo carga que se cierra detrás de ella (dibujo).
const PASS_MS := 360.0
const WAKE := 26.0
## La esquirla de una punta frágil que se mella: lo que tarda en caer.
const CHIP_MS := 450.0
## Dónde va la lupa (centro, unidades del banco): arriba a la derecha o, si la herramienta acaba ahí, a la izquierda.
const LUPA_RIGHT := Vector2(312.0, 44.0)
const LUPA_LEFT := Vector2(48.0, 44.0)


static func _smooth(u: float) -> float:
	var v := clampf(u, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Progreso suavizado del recorrido de bench.gd a los ms del ensayo.
static func eased_at(ms: float, puncture: bool) -> float:
	if puncture:
		return Ui.cubic_bezier(0.6, 0.0, 0.9, 0.4, clampf(ms / PUNCTURE_MS, 0.0, 1.0))
	return Ui.cubic_bezier(0.45, 0.05, 0.25, 1.0, clampf(ms / SCRATCH_MS, 0.0, 1.0))


## ms del ensayo en que el recorrido suavizado llega a e (la curva es monótona: búsqueda binaria).
static func ms_at_eased(e: float, puncture: bool) -> float:
	var total := PUNCTURE_MS if puncture else SCRATCH_MS
	if e <= 0.0:
		return 0.0
	if e >= 1.0:
		return total
	var lo := 0.0
	var hi := 1.0
	for i in 40:
		var mid := (lo + hi) / 2.0
		if eased_at(mid * total, puncture) < e:
			lo = mid
		else:
			hi = mid
	return hi * total


## La carga en la punta que da el resultado (N): el pico en una hoja; si no, la presión nominal por el área.
static func tip_load(res: Dictionary) -> float:
	if res.get("peakN") != null:
		return float(res.peakN)
	return float(res.get("pNominal", 0.0)) * float(res.get("area", 0.0))


## Dónde va la lupa (centro, unidades del banco): a la derecha, salvo que la herramienta acabe ahí al rayar o se incline
## hacia ella (tool.lean > 0: la base por delante de la punta, como la uña que arrastra; bench_biology.gd).
static func lupa_pos(puncture: bool, x2: float, tool: Dictionary) -> Vector2:
	var lean := int(tool.get("lean", 0))
	return LUPA_RIGHT if (puncture or x2 < 236.0) and lean <= 0 else LUPA_LEFT


## Un guion sin nada que animar (el esqueleto de plan): lo completan plan y, con la biología, BenchBiology.with_biology.
static func blank(res: Dictionary, x2: float) -> Dictionary:
	var puncture := Js.truthy(res.get("puncture"))
	return {
		"puncture": puncture, "touch": ms_at_eased(TOUCH_E, true) if puncture else 0.0, "load": tip_load(res), "nail": null,
		"crack": null, "glazing": null, "hertz": null, "dent": null, "chip": null, "lupa": null, "rec": null, "wake": false, "x_stop": x2,
		"end": 0.0,
	}


## Guion del ensayo: {} si el resultado no trae nada de la 2.0 que animar. tool: { claw, geom, base, inlay, wet } (la
## herramienta del banco); x1, x2: el recorrido al rayar. Devuelve { puncture, touch (ms en que toca), end (ms), load (la
## carga pedida, N), nail: { mode, at, x } | null, crack: { at, dur } | null, glazing: { kind, at, x } | null, hertz: { at, x } |
## null, dent: { at, x } | null, chip: { at, x } | null, lupa: { kind, at, pos } | null, rec: { pass } | null, wake, x_stop
## (donde deja de rayar una uña que se parte, o x2) }. Los ms (at, pass), desde que empieza el ensayo; x, dónde pasa al
## rayar (−1 al punzar, que pasa en el punto de punción).
static func plan(res: Variant, tool: Dictionary, x1: float, x2: float) -> Dictionary:
	if not ArtMaterials.is_v2(res):
		return {}
	var r: Dictionary = res
	var puncture := Js.truthy(r.get("puncture"))
	var x_at := func(e: float) -> float: return x1 + (x2 - x1) * e
	var touch := ms_at_eased(TOUCH_E, true) if puncture else 0.0
	var f_tip := tip_load(r)
	var f_req := f_tip
	var nail_d: Variant = r.get("nail")
	var nail_broken: bool = nail_d is Dictionary and nail_d.broken == true
	if nail_broken and float(nail_d.strengthMPa) > 0.0:
		f_req = float(nail_d.breakN) * float(nail_d.stressMPa) / float(nail_d.strengthMPa)
	# cuándo llega la carga a x (N): al rayar, en la rampa; al apretar, en LOAD_MS tras tocar; en un golpe (el resultado
	# trae su energía), el pico llega al impacto
	var strike := puncture and float(r.get("energyJ", 0.0)) > 0.0
	var when := func(x: float) -> float:
		var frac := clampf(x / f_req, 0.0, 1.0) if f_req > 0.0 else 0.0
		if strike:
			return touch
		if puncture:
			return touch + LOAD_MS * frac
		return ms_at_eased(RAMP * frac, false)
	var pl := blank(r, x2)
	pl.load = f_req
	var end := 0.0
	# la uña: se dobla o se parte al llegar a su carga de cesión
	if nail_broken and tool.get("claw") == null:
		var at: float = when.call(float(nail_d.breakN))
		var mode: String = nail_d.mode
		var x_n: float = x_at.call(eased_at(at, false)) if not puncture else -1.0
		pl.nail = { "mode": mode, "at": at, "x": x_n }
		end = maxf(end, at + (SNAP_MS if mode == "parte" else BEND_MS))
		if mode == "parte" and not puncture:
			pl.x_stop = x_n
	var fr: Variant = r.get("fracture")
	var cracks: bool = fr is Dictionary and fr.cracks == true
	# grietas en el punto al apretar: crecen con la carga (el cono o las radiales)
	if puncture and cracks and (fr.pattern == "cono" or fr.pattern == "radiales"):
		var dur := STRIKE_MS if strike else LOAD_MS
		pl.crack = { "at": touch, "dur": dur }
		end = maxf(end, touch + dur)
	# grietas de Hertz o astillado al rayar: empiezan donde la carga pasa del umbral de Hertz
	if not puncture and cracks:
		var at_h: float = when.call(float(fr.hertzN)) if fr.mode == "hertz" else 0.0
		pl.hertz = { "at": at_h, "x": x_at.call(eased_at(at_h, false)) }
	# los vidrios de coche: estalla o se agrieta cuando la carga llega a la que lo hace
	var burst := ArtMaterials.glazing_burst(r)
	if burst != "":
		var gl: Dictionary = r.glazing
		var thr: float = float(gl.pierceN) if gl.get("cause") == "grieta" and gl.has("pierceN") else float(gl.bendN)
		var at_g: float = when.call(thr)
		pl.glazing = { "kind": burst, "at": at_g, "x": x_at.call(eased_at(at_g, false)) if not puncture else -1.0 }
		end = maxf(end, at_g + (FALL_DELAY + FALL_MS if burst == "templado" else FLASH_MS))
	# la abolladura: al punzar, se hunde al tocar; al rayar, desde donde la carga pasa del colapso de la chapa
	if ArtMaterials.dent_visible(r):
		var at_d: float = touch if puncture else when.call(float(r.dent.collapseN))
		pl.dent = { "at": at_d, "x": x_at.call(eased_at(at_d, false)) if not puncture else -1.0 }
		end = maxf(end, at_d + (DENT_MS if puncture else 0.0))
	# la punta frágil que se mella (la fuerza de lado crece con la carga)
	var chip: Variant = r.get("tipChip")
	if chip is Dictionary and chip.chipped == true and not puncture:
		var at_c := ms_at_eased(RAMP * clampf(float(chip.chipN) / maxf(float(chip.lateralN), 1e-9), 0.0, 1.0), false)
		pl.chip = { "at": at_c, "x": x_at.call(eased_at(at_c, false)) }
		end = maxf(end, at_c + CHIP_MS)
	# la huella que sube: al rayar, la punta cruza el corte de la lupa (la mitad del surco) con una estela detrás
	var kind := ArtMaterials.lupa_kind(r)
	if kind == "recuperacion":
		if not puncture:
			var mid := ms_at_eased(0.5, false)
			pl.rec = { "pass": mid }
			pl.wake = true
			end = maxf(end, mid + PASS_MS / 2.0)
		else:
			pl.rec = { "pass": -1.0 }
	if kind != "":
		var at_l: float
		if puncture:
			at_l = touch + LUPA_DELAY
		elif kind == "recuperacion":
			at_l = maxf(0.0, float(pl.rec.pass) - PASS_MS / 2.0 - LUPA_MS)
		else:
			at_l = ms_at_eased(LUPA_E, false)
		pl.lupa = { "kind": kind, "at": at_l, "pos": lupa_pos(puncture, x2, tool) }
		end = maxf(end, at_l + LUPA_MS)
	if not puncture:
		end = minf(end, SCRATCH_MS)
	var any: bool = pl.nail != null or pl.crack != null or pl.hertz != null or pl.glazing != null or pl.dent != null or pl.chip != null \
		or pl.lupa != null
	if not any:
		return {}
	pl["end"] = end
	return pl


## Pose de los materiales a los ms del ensayo (lift: la retirada de la punta tras punzar, 0-1, la de bench.gd). Devuelve
## { nail: { angle (rad; negativo: el borde libre sube hacia el dorso), snap (0-1 la caída del trozo, −1 si no se ha
## partido) }, crack (0-1 la longitud de las grietas del punto: la carga a la 2/3), glazing (0-1 cuánto se ve el panal o la
## estrella), flash (0-1), fall (0-1 la caída de los trozos del hueco, −1 antes), dent (0-1), chip (0-1, −1 antes),
## lupa (0-1), rec: { tip (0-1: 1, la punta en el fondo), leaving } }.
static func pose(pl: Dictionary, ms: float, lift := 0.0) -> Dictionary:
	var out := {
		"nail": { "angle": 0.0, "snap": -1.0 }, "crack": 0.0, "glazing": 0.0, "flash": 0.0, "fall": -1.0, "dent": 0.0, "chip": -1.0,
		"lupa": 0.0, "rec": { "tip": 0.0, "leaving": false },
	}
	if pl.is_empty():
		return out
	var n: Variant = pl.nail
	if n != null:
		var at: float = n.at
		if n.mode == "parte":
			var pre := _smooth((ms - (at - 80.0)) / 80.0) if ms < at else 0.0
			out.nail = { "angle": -PRE_SNAP_DEG * PI / 180.0 * pre, "snap": clampf((ms - at) / SNAP_MS, 0.0, 1.0) if ms >= at else -1.0 }
		else:
			out.nail = { "angle": -BEND_DEG * PI / 180.0 * _smooth((ms - at) / BEND_MS), "snap": -1.0 }
	if pl.crack != null and ms >= float(pl.crack.at):
		# la longitud de una grieta de indentación crece como la carga elevada a 2/3 (Anstis et al. 1981)
		var f := clampf((ms - float(pl.crack.at)) / float(pl.crack.dur), 0.0, 1.0)
		out.crack = pow(f, 2.0 / 3.0)
	var g: Variant = pl.glazing
	if g != null and ms >= float(g.at):
		out.glazing = 1.0
		out.flash = 1.0 - clampf((ms - float(g.at)) / FLASH_MS, 0.0, 1.0)
		if g.kind == "templado":
			out.fall = clampf((ms - float(g.at) - FALL_DELAY) / FALL_MS, 0.0, 1.0)
	var d: Variant = pl.dent
	if d != null and ms >= float(d.at):
		out.dent = _smooth((ms - float(d.at)) / DENT_MS) if pl.puncture else 1.0
	var c: Variant = pl.chip
	if c != null and ms >= float(c.at):
		out.chip = clampf((ms - float(c.at)) / CHIP_MS, 0.0, 1.0)
	var l: Variant = pl.lupa
	if l != null and ms >= float(l.at):
		out.lupa = _smooth((ms - float(l.at)) / LUPA_MS)
	var rc: Variant = pl.rec
	if rc != null:
		if pl.puncture:
			# la punta está en el fondo desde que toca; al levantarla, se va y el fondo la sigue hasta la huella que queda
			out.rec = { "tip": 1.0 - _smooth(lift), "leaving": lift > 0.0 }
		else:
			var u := (ms - (float(rc.pass) - PASS_MS / 2.0)) / PASS_MS
			if u <= 0.0:
				out.rec = { "tip": 0.0, "leaving": false }
			elif u < 0.5:
				out.rec = { "tip": _smooth(u * 2.0), "leaving": false }
			else:
				out.rec = { "tip": 1.0 - _smooth((u - 0.5) * 2.0), "leaving": true }
	return out


## Profundidad de la huella en la lupa (unidades) con la punta a tip (0-1) del fondo: entrando, la hunde la punta;
## saliendo, el fondo la sigue hasta la huella que queda (dRes). dyn: el de ArtMaterials.lupa_art.
static func rec_depth(dyn: Dictionary, rec: Dictionary) -> float:
	var dl: float = dyn.dLoad
	var dr: float = dyn.dRes
	var tip_depth := dl - (1.0 - float(rec.tip)) * (dl + 0.8 * float(dyn.r))
	if bool(rec.leaving):
		return clampf(tip_depth, dr, dl)
	return clampf(tip_depth, 0.0, dl)


# ── Pintar (en el _draw del banco; s: píxeles por unidad del banco) ──

## Los trozos del hueco de la ventanilla (los pieces del panal de ArtMaterials.burst_art): en su sitio al estallar y luego
## cayendo, girando y apagándose. u: pose.fall (0-1); tint: el color del vidrio.
static func draw_pieces(ci: CanvasItem, pieces: Array, u: float, s: float, tint: Color) -> void:
	var alpha := 1.0 - _smooth((u - 0.55) / 0.45)
	if alpha <= 0.0:
		return
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		var c: Vector2 = pc.c
		var at := c + Vector2(side * (4.0 + 3.0 * i) * u, 70.0 * u * u)
		ci.draw_set_transform(at * s, side * 1.3 * u, Vector2(s, s))
		ci.draw_colored_polygon(pc.poly, Color(tint, 0.85 * alpha))
		ci.draw_polyline(pc.loop, Color(1, 1, 1, 0.8 * alpha), 0.5, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## El destello del vidrio que estalla, sobre la cara de la losa. a: pose.flash (0-1).
static func draw_flash(ci: CanvasItem, face: Rect2, a: float, s: float) -> void:
	if a > 0.0:
		ci.draw_rect(Rect2(face.position * s, face.size * s), Color(1, 1, 1, 0.55 * a))


## La estela del surco bajo carga que se cierra detrás de la punta al rayar: de la punta hacia atrás, cada vez más tenue
## (el material recupera en cuanto la punta pasa). w: ancho del surco (unidades); col: su fondo.
static func draw_wake(ci: CanvasItem, x_tip: float, x_from: float, y: float, w: float, s: float, col: Color) -> void:
	var len := minf(WAKE, x_tip - x_from)
	if len <= 0.5:
		return
	var n := 6
	for i in n:
		var a := Vector2(x_tip - len * i / n, y) * s
		var b := Vector2(x_tip - len * (i + 1) / n, y) * s
		var k := 1.0 - float(i) / n
		ci.draw_line(b, a, Color(0, 0, 0, 0.4 * k), (w + 1.2) * s)
		ci.draw_line(b, a, Color(col, 0.85 * k), maxf(0.6, 0.5 * w) * s)


## La esquirla de una punta frágil que se mella: tres trocitos del color del material que saltan de la punta (at) y caen a
## la losa (floor_y) junto al surco, y un chispazo al mellarse (dibujo). u: pose.chip (0-1).
static func draw_chips(ci: CanvasItem, at: Vector2, floor_y: float, u: float, s: float, col: Color) -> void:
	if u < 0.0:
		return
	if u < 0.3:
		var k := 1.0 - u / 0.3
		ci.draw_circle(at * s, (1.2 + 2.5 * u) * s, Color(1, 1, 1, 0.8 * k), true, -1.0, true)
	var dxs := [-9.0, 5.0, 12.0]
	for i in 3:
		var land := Vector2(at.x + float(dxs[i]), floor_y + (i - 1) * 1.4)
		var p := at.lerp(land, u) - Vector2(0.0, 7.0 * 4.0 * u * (1.0 - u))
		ci.draw_set_transform(p * s, (i + 1) * 3.0 * u, Vector2(s, s))
		var r := 0.9 + 0.35 * i
		ci.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -r), Vector2(r, r * 0.7), Vector2(-r, r * 0.5)]), col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## La huella de la lupa, encima de su textura (ArtMaterials.lupa_art, tipo "recuperacion"): el surco recortado en el
## material con la profundidad de ahora (rec_depth), su perfil y la punta, que se apaga hacia arriba y nunca se sale del
## círculo. o: centro de la lupa (unidades del banco); a: opacidad de la lupa; line: color del perfil; tip_col: de la punta;
## z: el aumento con que se pinta la lupa (bench.gd, lupa_zoom).
static func draw_recovery(ci: CanvasItem, o: Vector2, dyn: Dictionary, rec: Dictionary, a: float, s: float, line: Color, tip_col: Color,
		z := 1.0) -> void:
	s *= z
	o /= z
	var ys: float = dyn.ys
	var aa: float = dyn.a
	var p: float = dyn.p
	var r: float = dyn.r
	var d := rec_depth(dyn, rec)
	if d > 0.4:  # (menos es una línea: nada que recortar)
		var prof := PackedVector2Array()
		for i in 17:
			var x := -aa + 2.0 * aa * i / 16.0
			prof.append((o + Vector2(x, ys + ArtMaterials.groove_profile(x, aa, d, p))) * s)
		ci.draw_colored_polygon(prof, Color(Color(String(dyn.air)), a))
		ci.draw_polyline(prof, Color(line, a), 1.5 * s, true)
	# la punta: el perfil bajo carga prolongado hacia arriba, desplazado lo que se ha ido; se corta en `top`, o antes si
	# se saldría del círculo, y la cierra la cuerda entre sus dos extremos (siempre dentro)
	var dl: float = dyn.dLoad
	var off := (1.0 - float(rec.tip)) * (dl + 0.8 * r)
	var top := ys - 0.85 * r
	var reach := 1.0 + (ys - top - off) / maxf(dl, 1e-6)
	if float(rec.tip) <= 0.0 or reach <= 0.0:
		return
	var X := aa * pow(reach, 1.0 / p)
	for i in 30:  # el extremo, dentro del círculo (el perfil es una U: si sus extremos están dentro, ella también)
		var yx := ys + ArtMaterials.groove_profile(X, aa, dl, p) - off
		if X * X + yx * yx <= 0.93 * r * r:
			break
		X *= 0.93
	if X < 0.5:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var bottom := ys + dl - off
	var y_end := ys + ArtMaterials.groove_profile(X, aa, dl, p) - off
	for i in 21:
		var x := -X + 2.0 * X * i / 20.0
		var q := Vector2(x, ys + ArtMaterials.groove_profile(x, aa, dl, p) - off)
		pts.append((o + q) * s)
		cols.append(Color(tip_col, a * 0.8 * clampf((q.y - y_end) / maxf(bottom - y_end, 1e-6), 0.0, 1.0)))
	if bottom - y_end > 0.5:
		ci.draw_polygon(pts, cols)
