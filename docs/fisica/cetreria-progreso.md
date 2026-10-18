# Cetrería · el progreso del veterinario, los encargos y la tienda de lentes (unidad 5u)

Petición 62 de Eric (13-10-2026): un nivel de experiencia del veterinario, encargos de cuidado de garras y de reforja para
subirlo, y una tienda con cuatro lentes de cámara cada vez mejores y más resistentes. Va con la 5t (la lente y la reacción
del animal, calles B y C).

**Educativo, no de juego duro:** nunca se pierde lo hecho, el nivel no baja, un encargo hecho no se cobra dos veces, los
errores cuestan (restan de la recompensa) pero se explican, y la práctica libre impide los caminos cerrados.

## Dónde está

| Pieza | Archivo |
|---|---|
| El progreso (sin nodos, determinista) | `godot/core/lab/vet_progress.gd` (`VetProgress`) |
| La tarjeta «Tu consulta de veterinario» | `godot/app/lab/cetreria/care_progress_card.gd` |
| Su enganche en la página | bloque «5u» al final de `godot/app/lab/cetreria/care_page.gd` (y `_build_progress()`, `_progress_check(v)`) |
| La ruta del guardado | `lab_section.gd`: `user://cetreria.cfg`, junto a `user://ajustes.cfg`; sin ajustes (tests, demo), no se guarda |
| Tests | `godot/tests/lab/test_vet_progress.gd`, `godot/tests/app/test_care_progress.gd` |
| Demo | `godot/app/lab/cetreria/demo_progreso.tscn` (`-- --caso=1..4`) |

## Lo que es juego y lo que es física

Todo número de `vet_progress.gd` lleva `quality: "juego"` y nunca se presenta como física; los créditos son honorarios
ficticios, nunca dinero real (lo dice la tarjeta). Lo que **piden** los encargos es la práctica veterinaria de verdad y lleva
su fuente (Samour 2006 para la sujeción de las rapaces; Cat Tales 2024 y Animals Asia para la anestesia; Dubin y Patapoutian
2010 y Dremel para el calor; la rúbrica pedagógica para la nota). Los datos de las lentes (material, dureza, qué garras las
rayan, el daño acumulado) son de la cetrería: `claw_care_reaction.gd` (`LENSES`, `scratched_by`) y `claw_care_lens.gd`.

| Valor | Cifra | Tipo |
|---|---|---|
| Experiencia para los niveles 2, 3 y 4 (y un encargo hecho del nivel de antes) | 80, 240, 540 | juego |
| Lentes: nivel · precio · reponer | plástico 1 · de serie · 10; vidrio 2 · 80 · 30; templado 3 · 180 · 90; zafiro 4 · 380 · 190 | juego |
| Recompensa: base × (0,5 + 0,05 · nota) × (1 − lo que restan los errores) | — | juego |
| Lo que resta cada error que el encargo no pide evitar | sangre 25 %, calor 20 %, sin sujeción 30 %, se mueve 15 %, sin desinfectar 10 % | juego |
| Práctica libre (consulta terminada sin peligro, nota ≥ 5) | +15 de experiencia y +5 créditos | juego |

Los umbrales caben en lo que dan los encargos de cada nivel con la nota mínima que piden (sin la mesa de soldar): lo vigila un
test. Reponer el plástico y el vidrio es barato porque con los animales grandes se rajan pronto (5t-A).

## Los encargos

| Nivel | Encargo | Se comprueba con |
|---|---|---|
| 1 | El coping del águila: sujeción, sin sangre, nota ≥ 6 | el informe de la cetrería al terminar |
| 1 | La punta del halcón: sujeción, punta natural, sin sangre, nota ≥ 7 | ídem |
| 2 | El búho, sin sobresaltos: sujeción, que no se mueva, sin calor, nota ≥ 7 | ídem |
| 2 | Una funda de oro a la cera perdida | el informe de la reforja (veredicto «bien», oro) |
| 3 | El tigre de la clínica: anestesia, sin sangre, nota ≥ 6 | la cetrería |
| 3 | El oso pardo del santuario: anestesia, quieto, sin calor, nota ≥ 7 | ídem |
| 3 | Afilada como una daga (lechuza): veredicto «perfecta_daga», nota ≥ 8 | ídem |
| 3 | Soldar la punta de una funda (solo con la mesa de soldar de la 5r) | la unión de la pieza (`piece.weld`) |
| 4 | La hoz del velocirraptor: dedo II, anestesia, punta natural, nota ≥ 8 | la cetrería |
| 4 | Una funda de zafiro, colocada: pegada, sin escalón y probada | la colocación (5o) en el informe de la cetrería |

Un encargo se acepta en la tarjeta («Traer al animal a la mesa» empieza la consulta con su animal y su garra; la sujeción la
elige el usuario). Al terminar la consulta se comprueba; si no se cumple, la tarjeta dice qué falta y por qué, y sigue en
curso. La misma consulta terminada otra vez («Seguir con esta garra») vuelve a mirar el encargo, pero la práctica no se
cobra dos veces.

## Los encargos de la 5v: iniciación, minijuegos y garras rotas

Petición de Eric del 17-10. Todo en `core/lab/vet_progress.gd` (los encargos y lo que piden) y `core/lab/vet_minigames.gd`
(cómo va cada minijuego, con la vista de la cetrería, sin física nueva).

- **Iniciación** (`INITIATION`): cinco encargos en cadena, uno por tutorial («Preparar al animal», «Buscar la carne viva»,
  «Recortar el sobrante», «Limar» y «Dar la punta»). Aceptarlo trae al águila con el tutorial abierto en su proceso; se cumple
  al llegar al final de ese tutorial y terminar la consulta. Cada uno se abre al hacer el anterior.
- **Minijuegos** (`JOBS_5V`), con su objetivo, su barra y lo que falta en la tarjeta:
  - *pulir*: a su largo y con el Ra medio de los últimos 5 mm de la punta (la superficie del motor) por debajo de 1,5 µm, sin
    quemarla. La lima gruesa raya (~6 µm); la lija fina en la punta, quitando el resto del sobrante, la deja en ~1 µm;
  - *transformar*: la punta en una banda del medidor: roma para un búho que se clava las garras (juego) o la natural para un
    águila que llega con las garras gastadas. **La banda «afilada» (×0,5-×1) no se pide**: con la resolución del motor no se
    alcanza (en ángulo, la punta queda con el radio de los dientes de la lima, una aguja; de frente, el corte mínimo deja
    ×1,15 como poco). Para volver a la natural desde la roma: la lima fina en ángulo y, al pasarse a aguja, un toque de frente;
  - *reparar*: la garra rota (de serie o rota en la operación) con la sangre parada, desinfectada y reconstruida con
    metacrilato o con la pieza de la reforja colocada;
  - *reforjar*: una funda del material pedido hecha en la reforja (`ClawCareState.reforge_with` y la colocación de la 5o) y
    colocada a mano: limpia, pegada, sin escalón y probada.
- **Garras rotas de serie** (`setup.broken_start = { paw, digit, kind }`; `CareData.BROKEN_STARTS`): «fresca», partida por
  dentro de la carne viva y sangrando, o «muñon», partida hace días por delante de ella. La rotura es la del motor
  (`_break_off`); el ensayo empieza en esa garra y el tutorial pasa por «Si sangra» y «Garra rota». La sangre con la que llega
  no resta de la recompensa. Dónde se parte es una estimación (Samour 2006, p. 925).
- **La que se rompe durante el encargo**: el encargo no se pierde; pasa a «repararla» (lo que pide se cambia por la garra
  reparada, manteniendo la sujeción o la anestesia) y se cobra la mitad (`REPAIR_PAY`, juego), con el porqué en la tarjeta.
- Reconstruida con metacrilato, la forma en directo dice «Reconstruida» (provisional, se rehace cada 8-12 semanas) y el medidor
  lee el muñón: el metacrilato no se dibuja ni se lima en el motor.

## El guardado

`user://cetreria.cfg` (ConfigFile): `[formato] version = 1` y `[progreso]` con `xp`, `credits`, `best_level`, `lens_on`,
`active_job`, `lenses` (`{ id: { owned, damage } }`, con `damage` el `to_dict()` de `ClawCareLens` y su `obscuration`) y
`jobs`. Un archivo que no se puede leer se deja aparte (`.roto`) y se empieza de cero avisando; un dato raro empieza de cero y
se dice cuál; un archivo de una versión más nueva no se toca y la sesión no se guarda.

La lente comprada se monta en la cetrería (`lens_mount`; la que ya se tenía, con sus rayones, `lens_load`) y sus rayones se
guardan cuando cambian (`view().lens`).

## Pendiente

- Que la escena de la cetrería dibuje la lente puesta y sus rayones (5t-B, calle B).
- El encargo de soldar aparece cuando se una la 5r (la mesa de soldar).
- Un aviso en la reforja cuando su encargo se cumple (hoy se ve al volver a la cetrería).
