/* Doble de react-native-svg: mismos nombres de elementos que la librería real (15.8.0). */
import { host } from "./host.js";
const Svg = host("Svg");
export default Svg;
export const G = host("G"), Defs = host("Defs"), Path = host("Path"), Rect = host("Rect"), Circle = host("Circle"), Ellipse = host("Ellipse"),
  Line = host("Line"), Polygon = host("Polygon"), Polyline = host("Polyline"), Text = host("SvgText", true), LinearGradient = host("LinearGradient"),
  RadialGradient = host("RadialGradient"), Stop = host("Stop"), Mask = host("Mask"), ClipPath = host("ClipPath");
