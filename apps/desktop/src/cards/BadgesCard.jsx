import { C, BADGES } from "@sts/core";
import { MONO } from "../theme.js";
import { Card } from "../components/ui.jsx";

export function BadgesCard({ lab }) {
  const { badges, log } = lab;
  return (
    <Card title="Logros de laboratorio" right={<span style={{ fontFamily: MONO, fontSize: 11.5, color: C.gold }}>{badges.size}/{BADGES.length}</span>}>
      <div className="chips">
        {BADGES.map((b) => {
          const got = badges.has(b.id);
          return (
            <span key={b.id} style={{ fontFamily: MONO, fontSize: 11.5, padding: "6px 10px", borderRadius: 9, background: got ? C.gold : C.panel2, color: got ? C.bg : C.dimmer,
              border: `1px solid ${got ? C.gold : C.line}`, boxShadow: got ? "0 4px 14px rgba(230,180,80,.25)" : "none" }}>
              {got ? "★ " : "○ "}{b.t}
            </span>
          );
        })}
      </div>
      {log.length > 0 && (
        <>
          <div style={{ fontFamily: MONO, fontSize: 11, letterSpacing: 1.2, color: C.dimmer, textTransform: "uppercase", margin: "16px 0 6px" }}>Cuaderno · últimos ensayos</div>
          {log.map((e, i) => (
            <div key={e.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, padding: "7px 0", borderTop: i ? `1px solid ${C.line}` : "none" }}>
              <span style={{ fontFamily: MONO, fontSize: 12, color: C.dim, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{e.tool} → {e.tgt}</span>
              <span style={{ fontFamily: MONO, fontSize: 12, color: e.col, flexShrink: 0 }}>{e.verdict}</span>
            </div>
          ))}
        </>
      )}
    </Card>
  );
}
