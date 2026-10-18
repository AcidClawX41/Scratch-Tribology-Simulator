# Borradores de la unidad 4t para el coordinador (coche en curva)

Texto para revisar y pegar. `godot/CONTRATOS.md` y `docs/FISICA.md` los edita solo el coordinador: aquí van tal como
quedarían, con su sitio.

## 1. `godot/CONTRATOS.md` · después de «Tarjeta del coche en marcha (4c, unida)»

```markdown
## Coche en curva (4t, unida)

Petición 63 de Eric: «añadir un coche que gira en curvas, y cambia radicalmente el lado de la fuerza G». Guía en
`docs/fisica/coche-en-marcha.md` §20.

- **Motor:** `core/lab/car_curve.gd` (`CarCurve`), funciones puras, estáticas y deterministas, sin nodos. No toca
  `moving_car.gd`: usa su equilibrio de siempre (`MovingCar._eval`, `_margin`, `_mode_of`, `_window`, `_no_window`,
  `_band_txt`, `_ending`) con la aceleración lateral de la curva.
  - Cinemática: `lateral_ms2(v, R)` (a = v²/R, exacta), `demand_g`, `skid_kmh(R, μ)`, `felt_ms2` (sin pasar del tope del
    coche), `yaw_rate` (ω = a/v) y `at_lateral_kin`.
  - La carretera: `road(R, target)` (velocidad de proyecto, J de la norma, clotoides, tramos de la S y tope del coche),
    `design_kmh`, `jerk_norm`, `grip_of`, `radius_at(u)` y `slider_u(R)` (el deslizador logarítmico, con radios redondos y
    los valores marcados), `path` (el plano visto desde arriba).
  - La S: `s_kappa`, `s_dkappa`, `s_at(rd, v, t)`, `s_profile`, `s_duration` y `s_jerk_ms3`.
  - El animal: `at_speed(scen, v, R, grip, side)` y `at_lateral` (las de `MovingCar.at_speed` más el campo `curve`: `rM`,
    `side`, `demandMs2`, `demandG`, `latMs2`, `latG`, `skids`, `gripG`, `skidKmh`, `tyN`, `ttN`, `shares`, `markDeg` y
    `meter`), `side_shares` y `mark_deg`.
  - El despegue: `detach(scen, R, grip, side)` y `detach_s` (lo de `MovingCar.detach` más `rM`, `side`, `gripG`, `skidKmh`,
    `skidMinKmh`, `skidMaxKmh` y `skidsFirst`), `chart` y `verdict` («EL COCHE DERRAPA ANTES», «RESBALA HACIA FUERA» o el de
    siempre).
  - El golpe en curva: `approach_offsets` (el camino del animal visto desde el coche que gira; la fuerza del golpe no
    cambia).
  - Textos: `now_txt`, `why_txt`, `side_txt`, `side_name`, `g_ms2_txt` y `r_txt`.
  - Datos con `source` y `quality`: `NORM_RADII` (3.1-IC, tabla 4.4), `PRESETS`, `RING_R` (glorieta, estimación),
    `CAR_GRIP` (turismo y deportivo, estimación), `LOAD_TRANSFER` (h/b, estimación) y `DRAW_ONLY`.
- **Estado** (`MovingCarState`, bloque «Curvas (unidad 4t)» al final y unos pocos enganches):
  - `road` (`CarCurve.ROADS`: «recta», «curva», «s») y `radius_m`; `set_road` y `set_radius` (sin setup: `_recurve`);
  - `curve_on`, `curve_road`, `curve_grip`, `curve_side`, `curve_now`, `curve_sides` (la S, los dos lados);
  - textos: `curve_text`, `s_text`, `meter_note(c, loop_s, short)`, `road_note(short)`, `radius_text`, el porqué cuando el
    coche derrapa antes (`_curve_skid_why`), lecturas, fuentes y «¿sabías que…?» de la curva;
  - la S en la vista: `s_frame(t)` y `s_duration`; el medidor: `meter`;
  - el golpe en curva: `impact_curve_on`, `impact_lat_g`, `impact_approach(dist, n)` e `impact_curve_text`;
  - **en recta no se llama a nada de la curva** (`_at_speed` y `_derive` van por el camino de siempre): todo sale al bit
    como antes (lo vigila `test_car_curve.gd`). Maniobra con curva y carretera en curva no se suman; los experimentos van
    en recta.
- **Vista 3D** (`app/lab/car3d/`, archivos nuevos):
  - `road_curve.gd` y `road_curve.gdshader`: la tira de la carretera llevada a lo largo del eje de la curva con su rumbo
    (`path_p`, `path_h`: 64 puntos), con líneas, bordillos rojos y blancos y el arcén de tierra y hierba seca; la corta de la
    vista de lado (la curva 6 veces más cerrada, dibujo) y la larga de la persecución (de −40 a +260 m, al radio de verdad).
    También el balanceo (5°/g), la inclinación del animal (14°/g), el giro de las ruedas (Ackermann × 3) y la cámara de
    persecución (`chase_pose`, más cerca en el teléfono). Todo dibujo;
  - `g_meter.gd`: el medidor de fuerza G (la flecha por unidad de peso, el círculo de las garras, el tope del coche, la
    estela de la S y el anillo del cambio de lado);
  - `road_map.gd`: el plano de la carretera vista desde arriba con el coche.
- **Vista de persecución** (por defecto en curva; «De lado» en la tarjeta, para las garras): cámara detrás del coche sobre la
  propia carretera; la lupa no sale y el horizonte del paisaje sigue a la cámara. En la S, al cruzar la fuerza el cero en la
  clotoide de cambio, el rótulo «¡Cambia de lado!» y el anillo del medidor (~1 s).
- **Bloques al final de los archivos del coche** (cada calle cambia solo su bloque):
  - `car_model.gd`: «Curvas (unidad 4t)», las ruedas del otro lado (`ensure_far_wheels`) y la dirección (`set_steer`,
    `_wheel_rot`); `set_wheels` llama a `_wheel_rot` (con la dirección a 0 es la misma transformación de antes);
  - `car_scene.gd`: «Curvas (unidad 4t)», `set_curved`, `set_roll`, `set_chase`, `update_chase`, la carretera larga y la
    cámara; `_road()` guarda los nodos de la recta en `_flat` y `set_road` mueve también la curva;
  - `moving_car_view.gd`: «Curvas (unidad 4t)», `_sync_curve`, `_s_show`, `_s_tick`, `_apply_curve`, `chasing`,
    `set_chase_pref`, `_chase_horizon`, `_layout_meter`, `_twist_hold_marks` (los desgarros torcidos hacia fuera),
    `_draw_flash` y `_approach_at` (el golpe en curva); enganches de una línea en `sync`, `step`, `_draw`, `_draw_overlay`,
    `_place_animal`, `_draw_hold_animal` y `_draw_impact`;
  - `moving_car_card.gd`: «Curvas (unidad 4t)», `_build_road`, `_connect_road` y `_paint_road` (el selector, la vista, el
    radio con los valores de la norma y la frase).
- **Demo:** `app/lab/demo_curvas.tscn` (7 casos: recta, curva hasta derrapar, la S, la lechuza que resbala, el oso en el
  deportivo, la S de lado y el golpe en curva).
- **Tests:** `tests/lab/test_car_curve.gd` y `tests/app/test_car_curve_ui.gd`.
- **Pendiente:** el peralte (la curva va plana); la dinámica del animal en la S (cuasiestático); la referencia del aire en
  curva; la luneta gris al balancear en la vista de lado (`car_glass.gdshader`, de la calle A).
```

## 2. `docs/FISICA.md` · fila de «Cambios de la 2.0» (después de la del deportivo)

```markdown
| **Coche en marcha · el coche en curva** (unidad 4t; `car_curve.gd`, `moving_car_state.gd`; `docs/fisica/coche-en-marcha.md` §20): la aceleración lateral de una curva, a = v²/R (exacta), sustituye a la de la maniobra en la componente lateral del equilibrio de siempre (se suma como vector al viento y al peso), sin pasar del tope de agarre lateral del coche (0,85 g el turismo, 1,0 g el deportivo: si la curva pide más, el coche derrapa y el animal no siente más). Radios mínimos de la norma 3.1-IC (tabla 4.4) y una glorieta urbana de 15 m; la curva en S con las clotoides de la norma para su J a la velocidad de proyecto (4.4.3.1 y tabla 4.6, sin peralte), con el tirón J·(v/v_p)³. Las garras del lado de fuera cargan más (ΔN = F_lat·h/2b, con h/b ≈ 1, estimación); el veredicto no depende de ese reparto. En el golpe en curva solo cambia el camino del animal visto desde el coche que gira | Solo ensayos nuevos del coche en marcha con la carretera en curva: en recta todo sale al bit como antes (`compute()`, el golden 2.0 y los casos de referencia del coche no cambian), y el golpe en curva da el mismo `impact()`. Ejemplos: el tigre tumbado en el techo en la curva de 130 m aguanta hasta que el coche derrapa (~119 km/h); la lechuza en el techo en la de 50 m resbala hacia fuera a ~67 km/h (el coche derraparía a ~74); en la S de 130 m a 95 km/h tira 0,55 g de cada lado y cambia de lado con un tirón de ~2 m/s³ (4 veces la J de la norma a 60 km/h) | Ministerio de Fomento (2016), Norma 3.1-IC Trazado (Orden FOM/273/2016), tablas 4.3, 4.4 y 4.6, apartados 4.4.3.1 y 10.6; Wong (2008); Car and Driver (2021) vía Stuttcars (2022), el 911 GT3 (992), como caso parecido | `test_car_curve.gd`, `test_car_curve_ui.gd` |
```

## 3. `docs/FISICA.md` · filas de «Estimaciones (no son mediciones)» (después de las del coche en marcha)

```markdown
| Coche en marcha: tope de agarre lateral del turismo (2.0, unidad 4t) | 0,85 g (0,8-0,9) | la adherencia de pico del neumático en asfalto seco de Wong (2008), 0,8-0,9, tomada también de lado para un turismo de serie; pasado el tope, el coche derrapa y el animal no siente más (`docs/fisica/coche-en-marcha.md` §20.3) |
| Coche en marcha: tope de agarre lateral del deportivo (2.0, unidad 4t) | 1,0 g (0,9-1,1) | sin prueba de patinaje publicada del 911 Carrera (992): el caso medido más parecido es su versión de circuito, el GT3, 1,16 g en la pista circular de 300 pies de Car and Driver (2021) con neumáticos semislick; el de calle, por debajo (§20.3) |
| Coche en marcha: reparto de la carga entre las garras de cada lado (2.0, unidad 4t) | h/b ≈ 1 (0,5-1,5) | estática de un sólido sobre dos apoyos, ΔN = F_lat·h/2b, con el centro de masas a la altura de media base de apoyo (agazapado): una suposición sin medición publicada de un animal agarrado a un coche en curva; el veredicto de agarre no depende de él mientras las garras de dentro apoyen (§20.5) |
| Coche en marcha: radio de una glorieta urbana (2.0, unidad 4t) | 15 m (12-18) | 3.1-IC, 10.6: diámetro exterior de 30 a 40 m en una glorieta urbana de un carril; el coche va por el centro del carril, 2-3 m por dentro del borde (§20.2) |
```
