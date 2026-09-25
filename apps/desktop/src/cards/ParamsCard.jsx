import { C, TYPES, fToT, tToF, fmtF, fmtJ, passDepthFactor, tearLeverage } from "@sts/core";
import { MONO } from "../theme.js";
import { Card, Segmented, SubLabel, Note, Slider } from "../components/ui.jsx";


export function ParamsCard({ lab }) {
  const { claw, method, strike, force, length, passes, type, tearMode, tool, strikeJ, maxF, set } = lab;
  const setForce = (t) => { const f = tToF(t); set.force(f < 10 ? Math.round(f * 10) / 10 : Math.round(f)); };
  return (
    <Card step="3" title="Parámetros del ensayo">
      <Slider label="Fuerza" hint="(escala log)" display={`${fmtF(force)} N`} value={fToT(force)} min={0} max={1} step={0.004}
        onChange={setForce} valueText={`${fmtF(force)} newtons`} />
      <div style={{ display: "flex", justifyContent: "space-between", fontFamily: MONO, fontSize: 10.5, color: C.dimmer, marginTop: 6 }}>
        <span>0,5 N</span><span>roce humano</span><span>zarpazo</span><span>2000 N</span>
      </div>
      <button className="pill" onClick={() => set.force(maxF.force)}
        style={{ marginTop: 12, width: "100%", display: "block", textAlign: "center", padding: "10px 12px", color: C.gold, borderColor: C.gold, whiteSpace: "normal" }}>
        ⤓ Usar fuerza MÁX. {maxF.label} · ~{maxF.force} N
        <span style={{ display: "block", fontFamily: MONO, fontWeight: 400, fontSize: 10.5, color: C.dimmer, marginTop: 3 }}>{maxF.note}</span>
      </button>

      <SubLabel>Método</SubLabel>
      <Segmented label="Método" value={method} onChange={set.method}
        options={[{ id: "rayado", label: "Rayado (arrastre)" }, { id: "puncion", label: "Punción / inyección" }]} />
      {method === "puncion" ? (
        <>
          <Note>
            Penetración vertical, sin arrastre: la punta entra recta. {claw && claw.fang ? "El colmillo, además, es hueco → inyecta veneno en el tejido." : "Solo los colmillos inyectan; el resto hace punción seca."} Nada se hunde más que su propia {claw ? (claw.fang ? "aguja" : "garra") : "uña libre"}: aquí, ≤ {tool.reach} mm.
          </Note>
          <SubLabel>Golpe</SubLabel>
          <Segmented label="Golpe" value={strike ? "impacto" : "estatico"} onChange={(v) => set.strike(v === "impacto")}
            options={[{ id: "estatico", label: "Estático" }, { id: "impacto", label: "💥 Impacto (golpe)" }]} />
          <Note>{strike
            ? `Golpe dinámico: ½·m·v² ≈ ${fmtJ(strikeJ)} J (${tool.strike.v} m/s, ${tool.strike.m} kg efectivos ${claw ? "por garra" : "del dedo"}) + el trabajo del empuje = trabajo de penetración.`
            : "Empuje cuasi-estático (equilibrio de fuerzas): conservador. Cambia a Impacto para una mordedura, patada o zarpazo real."}</Note>
        </>
      ) : (
        <>
          <Slider label="Longitud" display={`${length} mm`} value={length} min={5} max={60} step={1} onChange={(v) => set.length(Math.round(v))} valueText={`${length} milímetros`} />
          <Slider label="Pasadas" hint="(mismo surco)" display={`${passes}×`} value={passes} min={1} max={100} step={1} onChange={(v) => set.passesSlider(Math.round(v))} valueText={`${passes} pasadas`} />
          <div className="chips" style={{ marginTop: 10 }}>
            {[1, 5, 20, 50, 100].map((n) => (
              <button key={n} className={`pill${passes === n ? " on" : ""}`} aria-pressed={passes === n} onClick={() => set.passes(n)} style={{ flex: 1, justifyContent: "center", fontFamily: MONO }}>{n}×</button>
            ))}
          </div>
          {passes > 1 && <Note>Arañar {passes} veces en la misma línea profundiza ×{passDepthFactor(passes).toFixed(1)} (sublineal: cada pasada arranca menos). Si la herramienta no marca ni una vez, mil pasadas tampoco: solo se desgasta la punta.</Note>}
          <SubLabel>Tipo de arañazo</SubLabel>
          <Segmented label="Tipo de arañazo" value={type.id} onChange={(id) => set.type(TYPES.find((t) => t.id === id))} options={TYPES.map((t) => ({ id: t.id, label: t.name }))} />
          {claw && (
            <>
              <SubLabel>Modo de garra</SubLabel>
              <Segmented label="Modo de garra" value={tearMode ? "desgarro" : "arrastre"} onChange={(v) => set.tearMode(v === "desgarro")}
                options={[{ id: "arrastre", label: "Arrastre" }, { id: "desgarro", label: "🪝 Desgarro (palanca)" }]} />
              <Note>{tearMode
                ? `Gancho + palanca: la garra curva rasga en vez de arrastrar. Ventaja mecánica ×${tearLeverage(claw).toFixed(1)} en la punta.`
                : "Arrastre liso (como una uña). Cambia a Desgarro para que la curvatura haga palanca."}</Note>
            </>
          )}
        </>
      )}
    </Card>
  );
}
