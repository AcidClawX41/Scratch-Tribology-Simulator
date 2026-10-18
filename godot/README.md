# Tribology Simulator & Industrial Workshop 2.0 · proyecto Godot (prototipo)

Antes se llamaba **Scratch Tribology Simulator** (la 1.x conserva ese nombre). Con el taller industrial ya no es solo
un simulador de rayado.

Un solo programa con dos secciones, hecho con **Godot 4.7.2** (editor estándar, no .NET) y GDScript:
- **Tribología biológica:** uñas, garras y colmillos.
- **Taller industrial:** mecanizado, torno manual y CNC compatible con el Fagor 8055 T, radial contra chapa de coche
  y afiladora.

## Abrirlo y ejecutarlo

1. Instala **Godot 4.7.2** (editor estándar, sin .NET) con `npm run godot:setup`. Lo descarga de la release oficial,
   comprueba la suma SHA-512 (`tools/godot-4.7.2.sha512`) y lo deja en `.godot-home/bin/godot`, donde lo encuentran
   los scripts. Con `npm run godot:setup -- --templates` instala también las plantillas de exportación. También
   puedes descargarlo a mano de godotengine.org.
2. En el gestor de proyectos: *Importar* → `godot/project.godot`.
3. **F5** ejecuta el programa y **F6** la escena abierta.

**Demos** (ábrelas en el editor y pulsa F6):

| Escena | Qué enseña |
|---|---|
| `app/taller/demo_torno3d.tscn` | Torno 3D: pieza A desde el bruto, desbaste, acabado con taladrina, pulido e inspección en colores |
| `app/taller/demo_radial.tscn` | Radial contra chapa: cinco discos y chapas, del corte limpio al sucio |
| `app/taller/demo_sonido.tscn` | Sonido de máquina: arranque, subida de rpm, corte y chatter |

## Tests

Desde la raíz del repositorio, con Node 20 o posterior y la variable `GODOT` apuntando al ejecutable. El oráculo de los tests está versionado (`godot/tests/fixtures/`), así que da igual qué Node tengas; solo hace falta Node 22 si cambia el motor 1.x y hay que regenerarlo (con otro V8, algún `pow()` difiere en el último bit):

```bash
GODOT=/ruta/a/godot npm run godot:test                          # todos
GODOT=/ruta/a/godot npm run godot:test -- --filter=taller/      # solo una carpeta o un archivo
```

- Primero exporta el oráculo del motor 1.x, luego importa el proyecto y ejecuta `tests/**/test_*.gd`.
- Falla si algún test falla o si la salida contiene «SCRIPT ERROR» o «Parse Error».
- Carpetas:
  - `tests/lab`: laboratorio contra el oráculo, golden 2.0 y seguridad para hilos;
  - `tests/taller`;
  - `tests/shared`: capa compartida;
  - `tests/app`: interfaz, sin ventana;
  - `tests/integration`: cadenas completas.

## Física del laboratorio: 1.x y 2.0

- `Physics.compute(p)` acepta `p.model`: `"2.0"` (por defecto, la de la aplicación) o `"1.x"` (el motor 1.x al bit, el
  que usan los tests del oráculo). Hoy dan lo mismo. Cada cambio de la 2.0 va en una rama `if c.v2:` y se documenta en
  [`../docs/FISICA.md`](../docs/FISICA.md) → «Cambios de la 2.0».
- La interfaz calcula siempre con el modelo del banco (`LabState.model`) a través de `lab.compute()`, `lab.duel()` y
  `lab.tool()`; un test vigila que nada en `app/` llame a `Physics.compute`, `Physics.resolve_tool` ni `Lab.duel`.
- **Golden 2.0** (`tests/fixtures/lab-golden-v2.json`): las salidas del modelo 2.0 en los 40 escenarios del golden 1.x y
  en los escenarios nuevos de la 2.0 (`EXTRA_SCENARIOS` en `tools/golden_v2.gd`), con el mismo formato y la misma
  política de comparación que el oráculo. Lo comprueba `tests/lab/test_golden_v2.gd`.
  - Se regenera **solo a propósito**, después de un cambio de la física 2.0 hecho adrede o al añadir escenarios:
    ```bash
    GODOT=/ruta/a/godot npm run godot:golden
    ```
  - La orden lista los escenarios de la 1.x que cambian: cada uno se explica en `docs/FISICA.md` («Cambios de la 2.0»),
    con su fuente. Nunca se regenera para que pase un test sin entender por qué ha cambiado.

## Rendimiento y multinúcleo

```bash
GODOT=/ruta/a/godot npm run godot:bench                               # 1, 2, 4… hilos hasta los de tu CPU
GODOT=/ruta/a/godot npm run godot:bench -- --quick                    # versión corta
GODOT=/ruta/a/godot npm run godot:bench -- --threads=1,6,12,24 --out=bench.json
```

`tools/bench.gd` mide sin ventana las tareas pesadas con varios números de hilos:
- los ensayos del laboratorio;
- el rasterizado de los dibujos con ThorVG;
- la radial y la afiladora;
- el programa Fagor completo del torno, su malla 3D y el sonido.

Comprueba que el resultado en paralelo sea idéntico al secuencial. Guarda un JSON con la CPU, los hilos, la versión de
Godot, la mediana de los tiempos y la aceleración, para comparar equipos, por ejemplo la nube con un Ryzen 9 7900. Las
reglas de paralelismo están en [`CONTRATOS.md`](CONTRATOS.md) → «Rendimiento y multinúcleo».

## Capturas con Movie Maker

```bash
npm run godot:capture -- res://app/taller/demo_torno3d.tscn --frames=300 --out=/tmp/torno
npm run godot:capture -- res://app/main.tscn --frames=90 --phone --out=/tmp/telefono   # 390 × 844, sin marco
```

Graba PNG + WAV (bajo Xvfb si no hay pantalla, con OpenGL). Con `--phone` (o `--phone=ANCHOxALTO`), la escena se ve
al tamaño de un teléfono: Movie Maker graba siempre al tamaño del proyecto, así que la orden escribe un `override.cfg`
temporal junto a `project.godot` con ese tamaño y lo borra al acabar.

## Dónde está cada cosa

- `core/`: física, datos y dibujo, sin nodos. Tres partes:
  - `shared/`: capa común;
  - `lab/`: tribología biológica;
  - `taller/`: taller industrial.
- `app/`: escenas e interfaz.
- `assets/`: fuentes y sonidos.
- `tests/`: ejecutor propio y tests.
- `tools/`: `godot.mjs` y el horneado de sonidos. Los zumbidos y los efectos de los aguijones (2.0) se hornean con
  `node godot/tools/godot.mjs run --headless --script res://tools/bake_lab_extra.gd` en `assets/sfx/lab/`; un test
  comprueba que los WAV están al día.

**Documentación:**
- Las reglas del proyecto y los contratos entre módulos están en [`CONTRATOS.md`](CONTRATOS.md).
- La física del taller está en [`../docs/TALLER.md`](../docs/TALLER.md).
- La exportación a cada plataforma está en [`../docs/GODOT-EXPORT.md`](../docs/GODOT-EXPORT.md).
