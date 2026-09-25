import React, { useRef } from "react";
import { View, Text, StyleSheet } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { materialName, C, CLAWS, CLAW_GROUPS, GEOMS, BASES, BASE_GROUPS, INLAYS, clawSpec, fmtP, fmtJ, nailSwatch } from "@sts/core";
import { DISP8, MONO } from "../theme";
import { Card, Segmented, Tile, SubLabel, Note, Pill, s as ui } from "../components/ui";
import { NailFront, NailSide, ClawIcon, GemIcon } from "../components/art";

const Stat = ({ k, v }) => <Text style={st.stat}><Text style={{ color: C.dimmer }}>{k}</Text> {v}{"  "}</Text>;

export function ToolCard({ lab }) {
  const { claw, geom, base, inlay, wet, tool, set } = lab;
  const lastClaw = useRef(CLAWS[0]);
  if (claw) lastClaw.current = claw;
  const spec = claw ? clawSpec(claw, inlay, tool) : null;
  return (
    <Card step="1" title="Herramienta">
      <Segmented label="Tipo de herramienta" value={claw ? "garras" : "unas"} style={{ marginBottom: 12 }}
        onChange={(m) => set.claw(m === "garras" ? lastClaw.current : null)}
        options={[{ id: "unas", label: "💅 Uñas" }, { id: "garras", label: "🐾 Garras y colmillos" }]} />
      {claw ? (
        <>
          <View style={st.preview}>
            <View style={[ui.previewArt, { width: 104, height: 136 }]}><ClawIcon claw={claw} inlay={inlay} uid="main" width={92} height={121} /></View>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={st.title}>{spec.title}</Text>
              <Text style={st.desc}>{claw.desc}</Text>
              <Text style={st.stats}>
                <Stat k={spec.material} v={spec.hardness} />
                <Stat k="punta" v={`R ${tool.tipRadiusUm.toFixed(0)} µm · α ${tool.alpha}°`} />
                <Stat k="curvatura" v={`${(claw.curve * 100).toFixed(0)} %`} />
                <Stat k="longitud útil" v={`${claw.reach} mm`} />
                <Stat k="peso" v={`${claw.mass} kg`} />
                <Stat k="fuerza" v={`~${claw.force} N`} />
                <Stat k="golpe" v={`~${fmtJ(tool.strikeJ)} J`} />
              </Text>
            </View>
          </View>
          {CLAW_GROUPS.map((g) => (
            <View key={g}>
              <SubLabel>{g}</SubLabel>
              <View style={ui.tiles}>
                {CLAWS.filter((c) => c.group === g).map((c) => (
                  <Tile key={c.id} on={claw.id === c.id} onPress={() => set.claw(c)} label={c.name} artH={52}
                    art={<ClawIcon claw={c} uid={`t${c.id}`} width={40} height={52} label={false} />} />
                ))}
              </View>
            </View>
          ))}
        </>
      ) : (
        <>
          <View style={st.preview}>
            <View style={[ui.previewArt, { width: 78, height: 128 }]}><NailFront geom={geom} base={base} inlay={inlay} wet={wet} uid="main" width={68} height={114} /></View>
            <View style={[ui.previewArt, { width: 116, height: 128, padding: 2 }]}><NailSide geom={geom} base={base} inlay={inlay} wet={wet} uid="main" width={110} height={82} /></View>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={[st.title, { fontSize: 15 }]}>{geom.name} · {base.short}</Text>
              <Text style={st.stats}>
                <Stat k="dureza" v={`${fmtP(tool.hv)} HV · Mohs ${tool.mohs}`} />{"\n"}
                <Stat k="punta" v={`${tool.area.toFixed(2)} mm² · R ${tool.tipRadiusUm.toFixed(0)} µm · α ${tool.alpha}°`} />{"\n"}
                <Stat k="uña libre" v={`${geom.reach} mm`} />
              </Text>
            </View>
          </View>
          <SubLabel>Forma</SubLabel>
          <View style={ui.tiles}>
            {GEOMS.map((g) => (
              <Tile key={g.id} width="31.5%" on={geom.id === g.id} onPress={() => set.geom(g)} label={g.name} sub={`${g.area} mm²`} artH={58}
                art={<NailFront geom={g} base={base} inlay={INLAYS[0]} uid={`t${g.id}`} width={35} height={58} label={false} />} />
            ))}
          </View>
          {BASE_GROUPS.map((grp) => (
            <View key={grp}>
              <SubLabel>{grp === "Salón" ? "Material · salón" : "Material · experimentos (uña maciza)"}</SubLabel>
              <View style={ui.wrapRow}>
                {BASES.filter((b) => b.group === grp).map((b) => (
                  <Pill key={b.id} on={base.id === b.id} onPress={() => set.base(b)}
                    icon={<LinearGradient colors={nailSwatch(b.id)} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={st.swatch} />}>{b.name}</Pill>
                ))}
              </View>
            </View>
          ))}
          {base.desc ? <Note style={{ color: C.dim }}>🧪 {base.desc}</Note> : null}
        </>
      )}

      <SubLabel>{claw ? "Material de la garra · la misma garra, reforjada" : "Incrustación · la piedra de la punta es la que araña"}</SubLabel>
      <View style={ui.wrapRow}>
        {INLAYS.map((i) => (
          <Pill key={i.id} on={inlay.id === i.id} onPress={() => set.inlay(i)} icon={i.id !== "none" ? <GemIcon inlay={i} size={15} /> : null}>
            {i.name}{i.mohs ? ` · M${i.mohs}` : ""}
          </Pill>
        ))}
      </View>
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

const st = StyleSheet.create({
  preview: { flexDirection: "row", gap: 10, alignItems: "stretch" },
  title: { fontFamily: DISP8, fontSize: 16, color: C.text, marginBottom: 4 },
  desc: { fontFamily: MONO, fontSize: 10.5, color: C.dim, lineHeight: 15.5, marginBottom: 6 },
  stats: { fontFamily: MONO, fontSize: 10.5, color: C.mint, lineHeight: 17 },
  stat: { fontFamily: MONO, fontSize: 10.5, color: C.mint },
  swatch: { width: 13, height: 13, borderRadius: 7, borderWidth: 1, borderColor: "rgba(255,255,255,0.35)" },
});
