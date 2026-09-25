import { C, DUEL_CARS, duel, duelVerdict, damageReport, fmtLen } from "@sts/core";
import { DISP, MONO } from "../theme.js";
import { Card, Pill, SubLabel } from "../components/ui.jsx";
import { Bench } from "../components/Bench.jsx";

/* ════════ MODO DUAL ════════
   El mismo ensayo en dos coches (un clásico de acero grueso frente a uno moderno, o de aluminio, o con
   aletas de plástico). Los dos bancos se animan con el ARAÑAR principal; debajo, qué raya, desgarra,
   punza o golpea en cada uno, cuánto y qué daño deja. Todo se calcula en core (duel, duelVerdict,
   damageReport): aquí solo se pinta. */

const BENCH_BOX = { background: `radial-gradient(120% 100% at 50% 0%, ${C.panel3}, ${C.panel2})`, border: `1px solid ${C.line}`, borderRadius: 14, padding: "4px 4px 0" };

function CarPicker({ value, onPick }) {
  return (
    <div className="chips" style={{ marginBottom: 8 }}>
      {DUEL_CARS.map((t) => <Pill key={t.id} on={t.id === value} onClick={() => onPick(t.id)} title={t.fact}>{t.name}</Pill>)}
    </div>
  );
}

function DamageList({ rows }) {
  return (
    <dl style={{ display: "grid", gridTemplateColumns: "auto 1fr", gap: "3px 10px", margin: "8px 2px 0", fontFamily: MONO, fontSize: 11.5 }}>
      {rows.map(([k, v]) => [<dt key={`k${k}`} style={{ color: C.dimmer }}>{k}</dt>, <dd key={`v${k}`} style={{ margin: 0, color: C.text }}>{v}</dd>])}
    </dl>
  );
}

/** Fila de la matriz: una manera de atacar en los dos coches y quién aguanta mejor. */
function DuelRow({ row, cars, current }) {
  const v = duelVerdict(row.res[0], row.res[1], cars);
  const cell = { padding: "7px 8px", borderTop: `1px solid ${C.line}`, verticalAlign: "top" };
  return (
    <tr style={{ background: current ? C.panel3 : "transparent" }}>
      <td style={{ ...cell, fontFamily: DISP, fontWeight: 700, color: C.text }}>{row.name}{current ? " ◂" : ""}</td>
      {row.res.map((r, i) => (
        <td key={i} style={{ ...cell, fontWeight: v.winner === i ? 700 : 400 }}>
          <div style={{ color: r.vcol }}>{r.verdict}</div>
          <div style={{ color: C.dimmer, fontSize: 11 }}>{r.depthUm > 0 ? fmtLen(r.depthUm) : "—"}{r.through ? ` · Ø ${fmtLen(r.grooveWidthUm)}` : ""}</div>
        </td>
      ))}
      <td style={{ ...cell, color: v.winner == null ? C.dim : C.mint }}>{v.text}</td>
    </tr>
  );
}

export function DualCard({ lab }) {
  const { dual, dualCars, params, claw, tearMode, method, phase, length, geom, base, inlay, wet, set } = lab;
  if (!dual) {
    return (
      <Card title="Modo dual · coche antiguo vs moderno" right={<Pill on={false} onClick={() => set.dual(true)}>Activar</Pill>}>
        <p style={{ fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 1.55, margin: 0 }}>
          El mismo ensayo en dos coches a la vez: un clásico de acero dulce más grueso frente a uno moderno de acero fino
          (o de aluminio, o con aletas de plástico). Qué raya, desgarra, punza o atraviesa cada uno, cuántos milímetros y qué daño deja.
        </p>
      </Card>
    );
  }
  const rows = duel(params, claw, dualCars);
  const isCurrent = (r) => r.p.method === method && r.p.strike === (method === "puncion" && !!params.strike) && r.p.tear === (method === "rayado" && !!(claw && tearMode));
  const current = rows.find(isCurrent) || rows[0];
  const tool = { claw, geom, base, inlay, wet };
  const done = phase === "done";
  const th = { textAlign: "left", fontFamily: MONO, fontWeight: 400, fontSize: 11, color: C.dimmer, padding: "0 8px 4px" };
  return (
    <Card title="Modo dual · coche antiguo vs moderno" right={<Pill on onClick={() => set.dual(false)}>Desactivar</Pill>}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))", gap: 14 }}>
        {dualCars.map((car, i) => (
          <div key={i}>
            <SubLabel>{i === 0 ? "Coche A" : "Coche B"}</SubLabel>
            <CarPicker value={car.id} onPick={(id) => set.dualCar(i, id)} />
            <div style={BENCH_BOX}>
              <Bench res={phase === "idle" ? null : current.res[i]} phase={phase} length={length} target={car} method={method} tool={tool} />
            </div>
            {done && (
              <div aria-live="polite" style={{ marginTop: 8 }}>
                <div style={{ fontFamily: DISP, fontWeight: 800, fontSize: 18, color: current.res[i].vcol }}>{current.res[i].verdict}</div>
                <div style={{ fontFamily: MONO, fontSize: 11.5, color: C.dim }}>{current.res[i].vsub}</div>
                <DamageList rows={damageReport(current.res[i], car, { length })} />
              </div>
            )}
          </div>
        ))}
      </div>
      {!done && <p style={{ fontFamily: MONO, fontSize: 12, color: C.dimmer, margin: "10px 2px 0" }}>{phase === "running" ? "Ensayando en los dos coches…" : "Pulsa ARAÑAR: el ensayo corre a la vez en los dos coches."}</p>}
      <SubLabel style={{ marginTop: 16 }}>Qué hace esta herramienta en cada coche</SubLabel>
      <div style={{ overflowX: "auto" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontFamily: MONO, fontSize: 12 }}>
          <thead><tr><th style={th} /><th style={th}>{dualCars[0].name}</th><th style={th}>{dualCars[1].name}</th><th style={th}>¿Quién aguanta?</th></tr></thead>
          <tbody>{rows.map((r) => <DuelRow key={r.id} row={r} cars={dualCars} current={r === current} />)}</tbody>
        </table>
      </div>
      <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 8 }}>misma herramienta, fuerza y largo · ◂ = el ensayo del banco · negrita = el que aguanta mejor</div>
    </Card>
  );
}
