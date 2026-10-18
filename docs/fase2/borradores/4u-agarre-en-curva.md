# Borrador 4u · para CONTRATOS.md y FISICA.md (lo pasa el coordinador)

## 1. Sección para `godot/CONTRATOS.md`, detrás de «Coche en curva (4t, unida)»

## Agarre en curva (4u)

Petición de Eric del 18-10: en curva el animal se agarra con su animación, deja más marcas al recolocarse y se cae en la
curva demasiado rápida. Guía en `docs/fisica/coche-en-marcha.md` §26.

- **Motor:** `core/lab/car_curve_grip.gd` (`CarCurveGrip`), funciones puras, estáticas y deterministas, sin nodos. No tiene
  equilibrio propio: usa el de la 4t (`CarCurve.at_speed`, `at_lateral` y `detach`) y las marcas de la 4s
  (`MovingCar._marks`, `CarTear`).
  - `usage(a)` (u = necesaria / disponible) y `effort(u)` (0-1, dibujo, desde `REACT_FROM`);
  - `slip_count(u, n)`, `flip_count(u, n)` y `slip_len_mm(u)`: nunca bajan si sube u;
  - `claw_force(scen, a)` (la garra del lado de fuera: 2·share de la normal y su parte de la necesaria) y
    `slip_marks(scen, f, len_mm)` (el surco del motor de siempre);
  - `at(scen, a)`: en una curva quieta, { u, effort, holds, side, deg, claws, slips, lenMm, tipN, marks, falls, sideways,
    mode, fallMm, fallMarks, quality, source }; {} en recta;
  - `s_events(scen, rd, v, grip_g)`: en la S, los momentos { tS, kind («resbala», «cambio», «cae»), side, claws, lenMm, tipN,
    deg, u, marks }, el pico de cada lado, falls y fallT;
  - `groove_count`, `marks_txt`, `claws_txt`, `now_txt` y `s_txt`;
  - datos con `source` y `quality`: `SLIP_FROM`, `FLIP_FROM`, `SLIP_MM` y `FALL_SLIDE_MM` (estimaciones de juego, con
    banda) y `REACT_FROM` (dibujo).
  - Se cae si y solo si no aguanta (`at_speed.holds`), lo mismo que dice el despegue en curva.
- **Estado** (`MovingCarState`, bloque «Agarre en curva (unidad 4u)» al final): `grip_now()` (una vez por ensayo, velocidad y
  radio: dos o tres compute() del motor de las marcas), `grip_text`, `grip_rows`, `_grip_readings` y `_grip_sources`, con
  enganches de una línea en `curve_text`, `_curve_readings`, `_curve_sources` y `hold_rows`. **En recta no se llama a nada:**
  el informe y las fuentes salen al bit (test).
- **Vista** (bloques «Agarre en curva (unidad 4u)» al final de `moving_car_view.gd` y de `animals/hd3d.gd`):
  - los surcos (`_dmg_grip`, que `_apply_damage` junta con los demás) desde las puntas de las garras del lado de fuera, en la
    dirección de la fuerza; en la S, al pasar cada momento, y se acumulan hasta que cambia el ensayo;
  - el esfuerzo en la pose (`curve_effort`, `curve_side`, `curve_regrip`): la rapaz baja el cuerpo, el oso abre las patas, el
    tigre y el velocirraptor se agazapan con la pose de la 4s, la cola de contrapeso del velocirraptor y el tirón al
    recolocarse;
  - la caída (`_grip_fall_draw`): resbala hasta el borde, cuelga un instante y cae rodando por la carretera, quedándose atrás;
    en la S queda caído hasta que la S vuelve a empezar (`_grip_latched`);
  - enganches de una línea en `sync`, `step`, `_apply_damage`, `_draw_hold_animal`, `_place_animal` y `_s_show`; en
    `hd3d.pose`, `_pose_curve`.
- **El miedo (petición de Eric del 18-10, lo primero de la 4u):** `CarCurveGrip.fear(u, jerk)` (dibujo, `FEAR`): del margen del
  agarre y del tirón de la S; la vista lo suaviza (`FEAR_TAU`, 0,3 s) con su lado y se lo pasa a la pose (`curve_on`,
  `curve_fear` de -1 a 1, `curve_regrip`). En `hd3d.gd` (bloque «Agarre en curva (unidad 4u)», `_pose_curve` y `CURVE_POSE` por
  especie): el cuerpo (`_holder`) agachado y girado hacia dentro con las patas en el techo (la raíz no se inclina: la vista
  le quita su `lean_rad` en `_grip_root`), la cabeza, las patas que escarban, la cola de contrapeso y las dos alas de la
  rapaz (`_curve_rig`: la izquierda, espejo de la derecha, una vez al construirla). Vida en curva (respiración, equilibrio,
  mirar) y temblor con mucho miedo; en recta, `_curve_rest`.
- **Los cuerpos de la cetrería en el coche:** con `pose.rig` (lo pone `hd3d.gd` salvo en el velocirraptor), `body_mammal.gd`
  lleva la cola en su pivote y `body_bird.gd` el ala de arriba, sus primarias y la cola (`car_rig`); en la cetrería no
  cambia nada.
- **Cámara de persecución:** más cerca (`CHASE_BACK` 4,9 m, `CHASE_UP` 2,45, `CHASE_LOOK_Y` 1,4, 46°; en el teléfono, 3,9 m),
  para ver al animal.
- **La caída de cada especie** (dibujo, `FALL_STYLE` en la vista): el tigre gira y cae de pie, el oso boca arriba, el
  velocirraptor salta fuera de pie, el de cine se abalanza hacia delante (ficción) y el ave abre las alas e intenta despegar
  (el texto lo dice: `now_txt`/`s_txt` con `bird`).
- **Hoja del miedo:** `app/lab/demo_miedo.tscn` (`-- --solo=<id> [--lado] [--uno=K]`).
- **Demo:** `app/lab/demo_curvas.tscn`, casos 13 (la S del tigre que se recoloca), 14 (las marcas de cerca) y 15 (el oso que se
  cae en la curva de 50 m; con `--animal=<id> --postura=<p> --hasta=<km/h>`, otro animal).
- **Tests:** `tests/lab/test_car_curve_grip.gd` y `tests/app/test_car_curve_grip_ui.gd`.
- **Pendiente:** la dinámica de verdad (sigue cuasiestático).

## 2. Fila de «Cambios de la 2.0» en `docs/FISICA.md`

| 4u · agarre en curva | El animal se recoloca cerca de su tope en curva (resbalones con el surco del motor de siempre) y se cae si no aguanta; en recta no cambia nada | `docs/fisica/coche-en-marcha.md` §26 |

## 3. Filas de la tabla de estimaciones de `docs/FISICA.md`

| Valor | Estimación | Por qué |
|---|---|---|
| Desde cuándo resbalan las garras en curva | 80 % del agarre (70-90 %) | suposición de juego; caso parecido: Dai, Gorb y Schwarz (2002) |
| Al cambiar de lado en la S, desde cuándo se recolocan | 55 % del agarre (40-70 %) | suposición de juego |
| Lo que resbala cada garra antes de volver a clavarse | 15 mm (6-30) | suposición de juego: el paso de una pata al recolocarla |
| Lo que resbala hacia fuera al caerse | 300 mm (150-600) | medio ancho de un techo de turismo |
