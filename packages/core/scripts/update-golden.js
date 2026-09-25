import { writeFileSync } from "node:fs";
import { SCENARIOS, runScenario, snapshot } from "./scenarios.js";
const out = Object.fromEntries(SCENARIOS.map(([name, p]) => [name, snapshot(runScenario(p))]));
writeFileSync(new URL("../test/golden.json", import.meta.url), JSON.stringify(out, null, 2) + "\n");
console.log(`golden.json actualizado con ${SCENARIOS.length} escenarios`);
