import { C } from "@sts/core";
import { DISP, MONO } from "../theme.js";

/* Primitivas de interfaz. Sin estado propio: todo llega por props. */

export function Card({ step, title, right, children, style }) {
  return (
    <section className="card" style={style}>
      {(title || right) && (
        <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10, marginBottom: 12 }}>
          <h2 style={{ display: "flex", alignItems: "center", gap: 9, margin: 0, fontFamily: DISP, fontWeight: 700, fontSize: 15, letterSpacing: 0.2 }}>
            {step && <span className="step">{step}</span>}{title}
          </h2>
          {right}
        </header>
      )}
      {children}
    </section>
  );
}

export const SubLabel = ({ children, style }) => (
  <div style={{ fontFamily: MONO, fontSize: 11, letterSpacing: 1.2, color: C.dimmer, textTransform: "uppercase", margin: "14px 0 8px", ...style }}>{children}</div>
);
export const Note = ({ children, style }) => (
  <div style={{ fontFamily: MONO, fontSize: 11, color: C.dimmer, lineHeight: 1.55, marginTop: 7, ...style }}>{children}</div>
);

export const Pill = ({ on, onClick, children, title }) => (
  <button className={`pill${on ? " on" : ""}`} onClick={onClick} aria-pressed={on} title={title}>{children}</button>
);

/** Control segmentado (una sola opción activa). */
export function Segmented({ options, value, onChange, label }) {
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o.id} className={value === o.id ? "on" : ""} aria-pressed={value === o.id} onClick={() => onChange(o.id)} title={o.title}>
          {o.icon}{o.label}
        </button>
      ))}
    </div>
  );
}

/** Ficha con ilustración (herramientas y materiales). */
export function Tile({ on, onClick, art, label, sub, artH = 52, wide = false }) {
  return (
    <button className={`tile${on ? " on" : ""}${wide ? " wide" : ""}`} onClick={onClick} aria-pressed={on}>
      <span className="tile-art" style={{ height: artH }}>{art}</span>
      <span className="tile-label">{label}</span>
      {sub && <span className="tile-sub">{sub}</span>}
    </button>
  );
}

/** Métrica con etiqueta en versalitas; sym (χ, φ…) se muestra tal cual para que no se confunda con una X. */
export function Metric({ label, sym, val, col, wide }) {
  return (
    <div className="metric" style={wide ? { gridColumn: "1 / -1" } : undefined}>
      <div style={{ fontFamily: MONO, fontSize: 10, color: C.dimmer, letterSpacing: 1, textTransform: "uppercase" }}>
        {label}{sym && <span style={{ textTransform: "none", fontSize: 12, letterSpacing: 0, color: C.dim }}> {sym}</span>}
      </div>
      <div style={{ fontFamily: MONO, fontSize: 14, color: col || C.text, marginTop: 4, wordBreak: "break-word" }}>{val}</div>
    </div>
  );
}

/** Deslizador con cabecera y pista rellena hasta el valor. */
export function Slider({ label, hint, display, value, min, max, step, onChange, valueText }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ marginTop: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 8 }}>
        <span style={{ fontFamily: MONO, fontSize: 12.5, color: C.dim }}>{label}{hint && <span style={{ color: C.dimmer }}> {hint}</span>}</span>
        <span style={{ fontFamily: MONO, fontSize: 15, color: C.rose, fontWeight: 700 }}>{display}</span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} aria-label={label} aria-valuetext={valueText}
        style={{ background: `linear-gradient(90deg, ${C.rose} ${pct}%, ${C.line} ${pct}%)` }}
        onChange={(e) => onChange(parseFloat(e.target.value))} />
    </div>
  );
}

export function IconButton({ on, onClick, label, children }) {
  return (
    <button className={`iconbtn${on ? " on" : ""}`} onClick={onClick} aria-pressed={on} title={label} aria-label={label}>{children}</button>
  );
}

/** Altavoz (activado / silenciado). */
export const SpeakerIcon = ({ on }) => (
  <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 9v6h4l5 4V5L8 9H4z" fill="currentColor" stroke="none" />
    {on ? <><path d="M16 9.5a4 4 0 0 1 0 5" /><path d="M18.5 7a7.5 7.5 0 0 1 0 10" /></> : <><path d="M17 9l5 6" /><path d="M22 9l-5 6" /></>}
  </svg>
);
