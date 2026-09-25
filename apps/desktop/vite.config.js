import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Puerto fijo que Tauri espera en desarrollo (devUrl en tauri.conf.json)
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: { port: 1420, strictPort: true },
  build: { outDir: "dist", target: ["es2021", "chrome105", "safari15"] },
});
