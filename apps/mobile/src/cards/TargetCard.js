import React from "react";
import { View } from "react-native";
import { TARGETS, targetSub } from "@sts/core";
import { Card, Tile, s as ui } from "../components/ui";
import { MaterialSwatch } from "../components/art";

export function TargetCard({ lab }) {
  const { target, set } = lab;
  return (
    <Card step="2" title="Material a rayar">
      <View style={ui.tiles}>
        {TARGETS.map((t) => (
          <Tile key={t.id} width="31.5%" on={target.id === t.id} onPress={() => set.target(t)} label={t.name} sub={targetSub(t)} artH={30}
            art={<MaterialSwatch target={t} w={120} h={34} uid={`tg${t.id}`} />} />
        ))}
      </View>
    </Card>
  );
}
