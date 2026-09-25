import React from "react";
import { problems } from "./errors.js";
// En React Native un texto fuera de <Text> lanza "Text strings must be rendered within a <Text> component".
export const checkText = (name, children) => React.Children.forEach(children, (c) => {
  if ((typeof c === "string" && c.trim() !== "") || typeof c === "number") problems.push(`${name}: texto fuera de <Text>: "${c}"`);
});
export const host = (name, textOk = false) => {
  const C = React.forwardRef((props, ref) => { if (!textOk) checkText(name, props.children); return React.createElement(name, { ...props, ref }, props.children); });
  C.displayName = name;
  return C;
};
