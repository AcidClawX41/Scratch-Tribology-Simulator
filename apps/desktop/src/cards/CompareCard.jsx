import { C, GEOMS, CLAWS, INLAYS, compute, fmtF, fmtP, fmtDepth } from "@sts/core";
import { DISP, MONO } from "../theme.js";
import { Card } from "../components/ui.jsx";
import { ClawIcon, NailFront } from "../components/art.jsx";

function Row({ icon, name, verdict, vcol, meta, sev, on, onClick }) {
  return (
    <button onClick={onClick} aria-pressed={on} title="Usar esta herramienta"
      style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "9px 8px", borderRadius: 12, cursor: "pointer", textAlign: "left", color: C.text,
        background: on ? C.panel3 : "transparent", border: `1px solid ${on ? C.line2 : "transparent"}`, borderTop: on ? undefined : `1px solid ${C.line}` }}>
      <div style={{ width: 30, height: 42, flexShrink: 0 }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 8 }}>
          <span style={{ fontFamily: DISP, fontWeight: 700, fontSize: 13.5 }}>{name}</span>
          <span style={{ fontFamily: MONO, fontSize: 11, color: vcol, textAlign: "right" }}>{verdict}</span>
        </div>
        <div style={{ fontFamily: MONO, fontSize: 11, color: C.dimmer, margin: "3px 0 6px" }}>{meta}</div>
        <div style={{ height: 6, background: C.panel2, borderRadius: 5, overflow: "hidden" }}>
          <div style={{ width: `${Math.max(4, sev * 100)}%`, height: "100%", background: vcol, borderRadius: 5, transition: "width .4s" }} />
        </div>
      </div>
    </button>
  );
}

export function CompareCard({ lab }) {
  const { claw, base, inlay, target, force, params, tearMode, set } = lab;
  if (claw) {
    const rows = CLAWS.map((c) => ({ c, ...compute({ ...params, claw: c, tear: tearMode }) })).sort((a, b) => b.pNominal - a.pNominal);
    return (
      <Card title="Comparar garras y colmillos">
        <p style={{ fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 1.55, margin: "0 0 6px" }}>
          Misma fuerza ({fmtF(force)} N) sobre {target.name}{inlay.id !== "none" ? ` con ${inlay.short}` : ""}. Queratina (Mohs ~2,5-3) y dentina: lo que cambia es el afilado (R, α), la curvatura y la gema de la punta.
        </p>
        {rows.map((r) => (
          <Row key={r.c.id} on={r.c.id === claw.id} onClick={() => set.claw(r.c)} name={r.c.name} verdict={r.verdict} vcol={r.vcol} sev={r.sev}
            icon={<ClawIcon claw={r.c} inlay={inlay} tipColor={r.vcol} uid="cmp" width={30} height={42} label={false} />}
            meta={`${r.area.toFixed(3)} mm² · α ${r.alphaDeg}° · ${fmtP(r.pNominal)} MPa nom.${r.depthUm > 0.1 ? ` · ${fmtDepth(r.depthUm)}` : ""}`} />
        ))}
        <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 8 }}>barra = severidad · pulsa una fila para usar esa herramienta</div>
      </Card>
    );
  }
  const rows = GEOMS.map((g) => ({ g, ...compute({ ...params, geom: g, inlay: INLAYS[0], claw: null }) })).sort((a, b) => b.pNominal - a.pNominal);
  return (
    <Card title="Comparativa por forma">
      <p style={{ fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 1.55, margin: "0 0 6px" }}>
        Misma fuerza ({fmtF(force)} N) y material ({base.name}) sobre {target.name}. Solo cambia la forma → el área de la punta → la presión, el desgaste y el rayado. (Sin incrustación, para aislar la forma.)
      </p>
      {rows.map((r) => (
        <Row key={r.g.id} on={r.g.id === lab.geom.id} onClick={() => set.geom(r.g)} name={r.g.name} verdict={r.verdict} vcol={r.vcol} sev={r.sev}
          icon={<NailFront geom={r.g} base={base} inlay={INLAYS[0]} uid="cmp" width={26} height={42} label={false} />}
          meta={`${r.area.toFixed(2)} mm² · ${fmtP(r.pNominal)} MPa nom. · desgaste ${r.wearIdx}${r.depthUm > 0.1 ? ` · ${fmtDepth(r.depthUm)}` : ""}`} />
      ))}
      <div style={{ fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 8 }}>barra = severidad del surco · pulsa una fila para usar esa forma</div>
    </Card>
  );
}
