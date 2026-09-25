import React from "react";
import ReactDOM from "react-dom/client";
// Fuentes empaquetadas en el binario: sin dependencia de red.
import "@fontsource/syne/600.css";
import "@fontsource/syne/700.css";
import "@fontsource/syne/800.css";
import "@fontsource/space-mono/400.css";
import "@fontsource/space-mono/700.css";
import "./styles.css";
import App from "./App.jsx";
import { installNativeBehaviour } from "./native.js";
import { applyThemeVars } from "./theme.js";

applyThemeVars();
installNativeBehaviour();

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
