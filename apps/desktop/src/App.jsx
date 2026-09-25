import { useState } from "react";
import { C, CLAWS, FUNDAMENTOS, FUNDAMENTOS_NOTE, LICENSE_NOTE } from "@sts/core";
import { DISP, MONO } from "./theme.js";
import { IconButton, SpeakerIcon } from "./components/ui.jsx";
import { ClawIcon } from "./components/art.jsx";
import { ToolCard } from "./cards/ToolCard.jsx";
import { TargetCard } from "./cards/TargetCard.jsx";
import { ParamsCard } from "./cards/ParamsCard.jsx";
import { ResultCard } from "./cards/ResultCard.jsx";
import { CompareCard } from "./cards/CompareCard.jsx";
import { DualCard } from "./cards/DualCard.jsx";
import { BadgesCard } from "./cards/BadgesCard.jsx";
import { useLab } from "./hooks/useLab.js";
import { useSound } from "./sound.js";
import { useRunShortcut, runShortcutLabel } from "./native.js";

/* ════════ APP ════════
   Dos columnas en ventanas anchas (configuración | banco y resultados) y una en estrechas. */
export default function App() {
  const [soundOn, toggleSound, play] = useSound();
  const lab = useLab(play);
  const [showModel, setShowModel] = useState(false);
  const running = lab.phase === "running";
  useRunShortcut(lab.run, !running);

  return (
    <div className="app">
      <header className="topbar">
        <div style={{ display: "flex", alignItems: "center", gap: 12, minWidth: 0 }}>
          <div className="preview-art" style={{ width: 46, height: 46, padding: 4, borderRadius: 14 }} aria-hidden="true">
            <ClawIcon claw={CLAWS[0]} uid="logo" width={34} height={40} label={false} />
          </div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontFamily: MONO, fontSize: 11, letterSpacing: 2, color: C.mint, textTransform: "uppercase" }}>Scratch Tribology Simulator</div>
            <h1 style={{ fontFamily: DISP, fontWeight: 800, fontSize: 28, lineHeight: 1.05, margin: "2px 0 0" }}>¿Qué raya a qué?</h1>
          </div>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <IconButton on={showModel} onClick={() => setShowModel((s) => !s)} label={showModel ? "Ocultar fundamentos físicos" : "Ver fundamentos físicos"}>
            <span aria-hidden="true">∑</span> Fundamentos
          </IconButton>
          <IconButton on={soundOn} onClick={toggleSound} label={soundOn ? "Sonido activado: pulsa para silenciar" : "Sonido desactivado: pulsa para activar"}>
            <SpeakerIcon on={soundOn} /> {soundOn ? "Sonido" : "Silencio"}
          </IconButton>
        </div>
      </header>

      {showModel && (
        <div className="card topbar" style={{ display: "block", marginBottom: 16, fontFamily: MONO, fontSize: 12, color: C.dim, lineHeight: 1.75 }}>
          <div style={{ fontFamily: DISP, fontWeight: 700, fontSize: 15, color: C.text, marginBottom: 8 }}>Fundamentos físicos</div>
          <div style={{ columns: "320px 2", columnGap: 28 }}>
            {FUNDAMENTOS.map(([k, v]) => <div key={k} style={{ breakInside: "avoid", marginBottom: 4 }}>· <b style={{ color: C.text }}>{k}</b>: {v}</div>)}
          </div>
          <div style={{ color: C.dimmer, marginTop: 8 }}>{FUNDAMENTOS_NOTE}</div>
        </div>
      )}

      <main className="layout">
        <div className="col">
          <ToolCard lab={lab} />
          <TargetCard lab={lab} />
          <ParamsCard lab={lab} />
        </div>
        <div className="col">
          <button className="run" onClick={lab.run} disabled={running} title={`Arañar (${runShortcutLabel})`} aria-keyshortcuts={runShortcutLabel.replace(/\s/g, "")}>
            {running ? "Ensayando…" : "▸ ARAÑAR"}
            {!running && <span style={{ fontFamily: MONO, fontWeight: 400, fontSize: 11, opacity: 0.7, marginLeft: 10 }}>{runShortcutLabel}</span>}
          </button>
          <ResultCard lab={lab} />
          <DualCard lab={lab} />
          <CompareCard lab={lab} />
          <BadgesCard lab={lab} />
        </div>
      </main>

      <p className="footer" style={{ fontFamily: MONO, fontSize: 11, color: C.dimmer, lineHeight: 1.6, marginTop: 18 }}>
        Modelo educativo v2 con datos publicados: nanoindentación de uña (E ≈ 2,9 GPa), barniz de coche (0,2–0,4 GPa), punción de piel in vivo (Davis 2004), colmillos de víbora (Estrada 2026) y agarre de rapaces (Sustaita &amp; Hertel 2010). Fuerzas y golpes de animales: estimaciones. Mohs↔Vickers no es lineal. Detalle y fuentes en docs/FISICA.md.
        <br />{LICENSE_NOTE}
      </p>
    </div>
  );
}
