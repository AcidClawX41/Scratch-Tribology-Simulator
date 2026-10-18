# Taller industrial · fuentes y modelos

Documentación física del **Taller industrial** de la V2. Es el equivalente de `docs/FISICA.md` para el
mecanizado, el torno, la radial y la afiladora. Cada unidad de trabajo del prototipo deja aquí sus fuentes en
`fuentes-u<n>.md`, y en la integración se reúnen en `docs/TALLER.md`.

**Reglas, las mismas que en FISICA.md:**
- Todo valor nuevo lleva su fuente.
- Lo que no tiene medición publicada se marca como **estimación**, en el dato (`quality: "estimate"`) y en esta
  documentación.
- Cada material saca sus coeficientes de corte (kc1.1, mc) de **una sola familia de fuentes**, y la dispersión entre
  fuentes se muestra como banda de incertidumbre.

**Unidades del taller.** Velocidad de corte en m/min, velocidad periférica en m/s, giro en rpm, avance en mm/rev o
mm/min, potencia en kW, par en N·m, temperatura en °C y vida de herramienta en min. Todas se suman a las del
laboratorio (N, MPa, HV, mm, µm, kg).

**Contratos entre módulos:** `godot/CONTRATOS.md`.
