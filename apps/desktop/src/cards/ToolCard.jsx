import { useRef } from "react";
import { materialName, C, CLAWS, CLAW_GROUPS, GEOMS, BASES, BASE_GROUPS, INLAYS, clawSpec, fmtP, nailSwatch, fmtJ } from "@sts/core";
import { DISP, MONO } from "../theme.js";
import { Card, Segmented, Tile, SubLabel, Note, Pill } from "../components/ui.jsx";
import { NailFront, NailSide, ClawIcon, GemIcon } from "../components/art.jsx";

const Stat = ({ k, v }) => <span><span style={{ color: C.dimmer }}>{k}</span> {v}</span>;

export function ToolCard({ lab }) {
  const { claw, geom, base, inlay, wet, tool, set } = lab;
  const lastClaw = useRef(CLAWS[0]);
  if (claw) lastClaw.current = claw;
  const spec = claw ? clawSpec(claw, inlay, tool) : null;
  return (
    <Card step="1" title="Herramienta" right={
      <Segmented label="Tipo de herramienta" value={claw ? "garras" : "unas"}
        onChange={(m) => set.claw(m === "garras" ? lastClaw.current : null)}
        options={[{ id: "unas", label: "💅 Uñas" }, { id: "garras", label: "🐾 Garras y colmillos" }]} />
    }>
      {claw ? (
        <>
          <div className="preview">
            <div className="preview-art" style={{ width: 118, height: 150 }}><ClawIcon claw={claw} inlay={inlay} uid="main" width={100} height={132} /></div>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontFamily: DISP, fontWeight: 800, fontSize: 18, marginBottom: 5 }}>{spec.title}</div>
              <div style={{ fontFamily: MONO, fontSize: 11.5, color: C.dim, lineHeight: 1.55, marginBottom: 8 }}>{claw.desc}</div>
              <div style={{ fontFamily: MONO, fontSize: 11.5, color: C.mint, lineHeight: 1.7, display: "flex", flexWrap: "wrap", columnGap: 12 }}>
                <Stat k={spec.material} v={spec.hardness} />
                <Stat k="punta" v={`R ${tool.tipRadiusUm.toFixed(0)} µm · α ${tool.alpha}°`} />
                <Stat k="curvatura" v={`${(claw.curve * 100).toFixed(0)} %`} />
                <Stat k="longitud útil" v={`${claw.reach} mm`} />
                <Stat k="peso" v={`${claw.mass} kg`} />
                <Stat k="fuerza" v={`~${claw.force} N`} />
                <Stat k="golpe" v={`~${fmtJ(tool.strikeJ)} J`} />
              </div>
            </div>
          </div>
          {CLAW_GROUPS.map((g) => (
            <div key={g}>
              <SubLabel>{g}</SubLabel>
              <div className="tiles">
                {CLAWS.filter((c) => c.group === g).map((c) => (
                  <Tile key={c.id} on={claw.id === c.id} onClick={() => set.claw(c)} label={c.name} artH={58}
                    art={<ClawIcon claw={c} uid={`t${c.id}`} width={44} height={58} label={false} />} />
                ))}
              </div>
            </div>
          ))}
        </>
      ) : (
        <>
          <div className="preview">
            <div className="preview-art" style={{ width: 92, height: 150 }}><NailFront geom={geom} base={base} inlay={inlay} wet={wet} uid="main" width={80} height={134} /></div>
            <div className="preview-art" style={{ width: 150, height: 150, padding: 4 }}><NailSide geom={geom} base={base} inlay={inlay} wet={wet} uid="main" width={140} height={104} /></div>
            <div style={{ minWidth: 0, fontFamily: MONO, fontSize: 11.5, color: C.mint, lineHeight: 1.7 }}>
              <div style={{ fontFamily: DISP, fontWeight: 800, fontSize: 17, color: C.text, marginBottom: 4 }}>{geom.name} · {base.short}</div>
              <div><Stat k="dureza" v={`${fmtP(tool.hv)} HV · Mohs ${tool.mohs}`} /></div>
              <div><Stat k="punta" v={`${tool.area.toFixed(2)} mm² · R ${tool.tipRadiusUm.toFixed(0)} µm · α ${tool.alpha}°`} /></div>
              <div><Stat k="uña libre" v={`${geom.reach} mm`} /></div>
            </div>
          </div>
          <SubLabel>Forma</SubLabel>
          <div className="tiles">
            {GEOMS.map((g) => (
              <Tile key={g.id} on={geom.id === g.id} onClick={() => set.geom(g)} label={g.name} sub={`${g.area} mm²`} artH={62}
                art={<NailFront geom={g} base={base} inlay={INLAYS[0]} uid={`t${g.id}`} width={37} height={62} label={false} />} />
            ))}
          </div>
          {BASE_GROUPS.map((grp) => (
            <div key={grp}>
              <SubLabel>{grp === "Salón" ? "Material · salón" : "Material · experimentos (uña maciza)"}</SubLabel>
              <div className="chips">
                {BASES.filter((b) => b.group === grp).map((b) => {
                  const [c1, c2] = nailSwatch(b.id);
                  return (
                    <Pill key={b.id} on={base.id === b.id} onClick={() => set.base(b)}>
                      <span aria-hidden="true" style={{ width: 13, height: 13, borderRadius: 7, background: `linear-gradient(135deg, ${c1}, ${c2})`, border: "1px solid rgba(255,255,255,.35)" }} />
                      {b.name}
                    </Pill>
                  );
                })}
              </div>
            </div>
          ))}
          {base.desc && <Note style={{ color: C.dim }}>🧪 {base.desc}</Note>}
        </>
      )}

      <SubLabel>{claw ? "Material de la garra · experimento: la misma garra, reforjada en otro material" : "Incrustación · piedras en la uña (la de la punta es la que araña)"}</SubLabel>
      <div className="chips">
        {INLAYS.map((i) => (
          <Pill key={i.id} on={inlay.id === i.id} onClick={() => set.inlay(i)} title={i.hv ? `${i.hv} HV` : undefined}>
            {i.id !== "none" && <GemIcon inlay={i} size={16} />}{i.name}{i.mohs ? <span style={{ fontFamily: MONO, fontWeight: 400, fontSize: 11, opacity: 0.8 }}>M{i.mohs}</span> : null}
          </Pill>
        ))}
      </div>
      {claw && claw.fang && inlay.id !== "none" && <Note>colmillo reforjado en {inlay.name.toLowerCase()}: aguja con dureza de {inlay.hv} HV (ya no se rompe a {claw.fBreak} N)</Note>}
      {claw && !claw.fang && inlay.id !== "none" && <Note>garra reforjada en {materialName(inlay)}: la misma forma, con dureza de {inlay.hv} HV</Note>}

      {(tool.keratin || wet) && (
        <>
          <SubLabel>Estado de la queratina</SubLabel>
          <Segmented label="Estado de la queratina" value={wet ? "humeda" : "seca"} onChange={(v) => set.wet(v === "humeda")}
            options={[{ id: "seca", label: "Seca" }, { id: "humeda", label: "💧 Húmeda (remojada)" }]} />
          <Note>{!tool.keratin
            ? "Esta punta no es queratina (gel, acrílico, metal, gema o dentina): el agua no la cambia."
            : wet ? "Empapada, la queratina pierde ~80 % de rigidez y resistencia (Farran 2009): se dobla y apenas raya."
              : "Humedad normal de la uña (14-30 % de agua). Prueba a remojarla."}</Note>
        </>
      )}
    </Card>
  );
}
