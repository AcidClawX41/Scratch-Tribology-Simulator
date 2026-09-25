import React from "react";
import { nailArt, nailSideArt, clawArt, surfaceArt, gemArt, clawTitle } from "@sts/core";
import { Art, memoArt } from "./Scene";

/* Ilustraciones realistas (geometría en @sts/core/art.js), las mismas que en escritorio. */
export function NailFront({ geom, base, inlay, wet = false, uid = "nf", width, height, label = true }) {
  const art = memoArt(`nf:${uid}:${geom.id}:${base.id}:${inlay.id}:${wet}`, () => nailArt({ geom, base, inlay, wet, uid }));
  return <Art art={art} viewBox="0 0 100 168" width={width} height={height} label={label ? `Uña ${geom.name.toLowerCase()} de ${base.name.toLowerCase()}` : undefined} />;
}

export function NailSide({ geom, base, inlay, wet = false, uid = "ns", width, height }) {
  const art = memoArt(`ns:${uid}:${geom.id}:${base.id}:${inlay.id}:${wet}`, () => nailSideArt({ geom, base, inlay, wet, uid }));
  return <Art art={art} viewBox="-122 -80 132 98" width={width} height={height} label="Vista lateral de la uña" />;
}

export function ClawIcon({ claw, inlay = null, tipColor = null, orient, uid = "ci", width, height, label = true }) {
  const art = memoArt(`ci:${uid}:${claw.id}:${inlay ? inlay.id : "-"}:${tipColor}:${orient}`, () => clawArt(claw, { inlay, tipColor, orient, uid }));
  return <Art art={art} viewBox="0 0 100 132" width={width} height={height} label={label ? clawTitle(claw) : undefined} />;
}

export function MaterialSwatch({ target, w = 120, h = 34, uid = "sw", detail = 0.7, rx = 7 }) {
  const art = memoArt(`sw:${uid}:${target.id}:${w}x${h}:${detail}`, () => surfaceArt(target.id, { w, h, uid, detail, rx }));
  return <Art art={art} viewBox={`0 0 ${w} ${h}`} width="100%" height="100%" />;
}

export function GemIcon({ inlay, size = 16 }) {
  const art = memoArt(`gem:${inlay.id}`, () => gemArt(inlay, 10, 10, 8, "gi"));
  return <Art art={art} viewBox="0 0 20 20" width={size} height={size} />;
}
