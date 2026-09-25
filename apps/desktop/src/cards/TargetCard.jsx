import { TARGETS, targetSub } from "@sts/core";
import { Card, Tile } from "../components/ui.jsx";
import { MaterialSwatch } from "../components/art.jsx";

export function TargetCard({ lab }) {
  const { target, set } = lab;
  return (
    <Card step="2" title="Material a rayar">
      <div className="tiles wide">
        {TARGETS.map((t) => (
          <Tile key={t.id} wide on={target.id === t.id} onClick={() => set.target(t)} label={t.name} sub={targetSub(t)} artH={34}
            art={<MaterialSwatch target={t} w={120} h={34} uid={`tg${t.id}`} />} />
        ))}
      </div>
    </Card>
  );
}
