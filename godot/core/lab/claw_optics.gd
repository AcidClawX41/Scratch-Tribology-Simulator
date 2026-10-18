## Tribología biológica · óptica de los materiales de las garras (catálogo 2.0, unidad 5e). Sin estado.
##
## Qué hay aquí: los datos ópticos MEDIDOS de cada material con el que se puede ver una garra (la queratina natural, los
## materiales reforjados de Data.INLAYS y los que añade la reforja, `rubi` y `alumina`) y las cuentas que pasan de esos
## datos a lo que pinta la escena 3D (app/common/claw_material.gd). Guía, tabla valor → fuente → tipo y lo que no se
## predice: docs/fisica/materiales-garras.md.
##   - Metales (oro, acero inoxidable, titanio, carburo de tungsteno) y el mineral opaco (hematites): su reflectancia a
##     incidencia normal en cada longitud de onda, de su índice complejo medido (n + ik: R = ((n−1)² + k²)/((n+1)² + k²))
##     o de su reflectancia medida, pasada a sRGB lineal con las funciones de igualación CIE 1931 (ajuste de Wyman et al.
##     2013), el iluminante (cuerpo negro de 6504 K, el de D65) y la matriz de IEC 61966-2-1. Es el F0 de cada metal: el
##     oro, amarillo; el inoxidable y el titanio, grises con su matiz; el carburo, más oscuro.
##   - Gemas y vidrios: el índice de refracción con su fórmula de dispersión medida (Sellmeier, Cauchy…), por rayo
##     ordinario y extraordinario en los birrefringentes; de ahí salen el reflejo de Fresnel, el ángulo crítico, la
##     dispersión B–G (el «fuego»: diamante 0,044, moissanita 0,104) y el índice de cada canal de color.
##   - El color de lo transparente: la absorción por milímetro en cada canal (Beer–Lambert), derivada de lo medido: el
##     rubí, del color CIE L*a*b* de un rubí sintético a 1, 5 y 10 mm (Yuan et al. 2022); el zafiro azul, de la sección
##     eficaz del par Fe²⁺-Ti⁴⁺ (Dubinsky et al. 2020); el vidrio, de su índice de absorción k (Rubin 1985); la moissanita,
##     de su corte de absorción a 425 nm (Nassau et al. 1997). Lo incoloro no absorbe en el visible.
##   - La queratina (n de Leertouwer et al. 2011): su aspecto translúcido de siempre lo pinta la escena (dibujo); aquí
##     solo está su índice, que fija su reflejo.
##   - Los polímeros de la prótesis de verdad (unidad 5p): el acrílico dental (el índice del PMMA, Sultanova et al. 2009)
##     y la resina fotopolimerizable (con el mismo índice, como caso medido más parecido); transparentes de por sí, su color
##     y lo que difunden (scatter) son los de sus pigmentos y sus cargas, dibujo.
##   - Los acabados (pulido, tallado, limado, en bruto…): la rugosidad rms σ de cada uno y la fracción especular que deja,
##     exp(−(4πσ/λ)²) (Bennett & Porteus 1961); de la reforja (ClawForge, `finish`) y de la cetrería (la última herramienta
##     que ha mordido) se lee qué acabado tiene cada garra.
## Cada dato es { value, source, quality } (quality: «primary» medido en el caso, «secondary» medido en un caso cercano o
## leído de una figura, «estimate» sin medición: el caso medido más parecido con la suposición escrita, «dibujo» solo para
## pintar). Los números derivados (DERIVED) los recalcula un test desde los datos medidos.
## Unidades: longitud de onda en nm (las fórmulas de dispersión, en µm, como sus autores) · absorción en 1/mm · espesor en
## mm · rugosidad en µm · ángulos en grados. Funciones puras, deterministas y seguras para hilos; las cuentas usan las
## funciones de V8 (core/shared/v8_math.gd), no la libm. Uso: const ClawOptics = preload("res://core/lab/claw_optics.gd").
extends RefCounted

const V8 = preload("res://core/shared/v8_math.gd")

# ════════ Fuentes ════════
const SRC_RI_INFO := "datos tabulados de refractiveindex.info (Polyanskiy MN (2024), Refractiveindex.info database of optical constants, Sci. Data 11:94, doi:10.1038/s41597-023-02898-2; dominio público)"
const SRC_JC1972 := "Johnson PB, Christy RW (1972). Optical constants of the noble metals. Phys. Rev. B 6:4370-4379, doi:10.1103/PhysRevB.6.4370 (oro, a temperatura ambiente; " + SRC_RI_INFO + ")"
const SRC_JC1974 := "Johnson PB, Christy RW (1974). Optical constants of transition metals: Ti, V, Cr, Mn, Fe, Co, Ni, and Pd. Phys. Rev. B 9:5056-5070, doi:10.1103/PhysRevB.9.5056 (titanio y cromo, a temperatura ambiente; " + SRC_RI_INFO + ")"
const SRC_KARLSSON := "Karlsson B, Ribbing CG (1982). Optical constants and spectral selectivity of stainless steel and its oxides. J. Appl. Phys. 53:6340-6346, doi:10.1063/1.331503 (inoxidable austenítico Avesta 832 MV, parecido al 316: 18,5 % de Cr y 9,3 % de Ni; n y k leídos de su figura por " + SRC_RI_INFO + ")"
const SRC_CHONO := "Chono T, Tokutomi H, Nakamura K, Miyazaki K (2025). Reflectance spectral studies of spark plasma sintered tungsten carbide pellet. Jpn. J. Appl. Phys. 64:010905, doi:10.35848/1347-4065/ad9a43 (WC sinterizado y pulido a Ra ≤ 0,001 µm: reflectancia medida de ~0,47 a 1,8 eV y ~0,48 a 2,5 eV, leída de su figura 2c; por encima de 2,5 eV, su cálculo ab initio da ~0,46)"
const SRC_HOM := "Anthony JW, Bideaux RA, Bladh KW, Nichols MC (eds.), Handbook of Mineralogy, Mineralogical Society of America"
const SRC_HOM_HEMATITE := SRC_HOM + ", «Hematite»: reflectancia en el aire R1–R2 de 400 a 700 nm cada 20 nm (32,0–34,5 % a 400 nm … 22,8–25,6 % a 700 nm); gris acero, blanco grisáceo con tinte azulado en luz reflejada y reflejos internos rojo sangre; brillo metálico o submetálico"
const SRC_HOM_GEMS := SRC_HOM + ": brillo adamantino del diamante, adamantino a vítreo del corindón y vítreo del cuarzo; el corindón puro y el cuarzo, incoloros"
const SRC_PETER := "Peter F (1923). Über Brechungsindizes und Absorptionskonstanten des Diamanten zwischen 644 und 226 mμ. Z. Phys. 15:358-368, doi:10.1007/BF01330487 (fórmula de Sellmeier del diamante; " + SRC_RI_INFO + "). Coincide con el Handbook of Mineralogy: n = 2,4354 (486 nm), 2,4175 (589 nm) y 2,4076 (687 nm)"
const SRC_MALITSON := "Malitson IH, Dodge MJ (1972). Refractive index and birefringence of synthetic sapphire. J. Opt. Soc. Am. 62:1405, con la fórmula de Dodge MJ (1986), Handbook of Laser Science and Technology IV, CRC Press, p. 30 (zafiro sintético a 20 °C, rayos o y e; " + SRC_RI_INFO + ")"
const SRC_GHOSH := "Ghosh G (1999). Dispersion-equation coefficients for the refractive index and birefringence of calcite and quartz crystals. Opt. Commun. 163:95-102, doi:10.1016/S0030-4018(99)00091-7 (cuarzo α, rayos o y e; " + SRC_RI_INFO + ")"
const SRC_WOOD_NASSAU := "Wood DL, Nassau K (1982). Refractive index of cubic zirconia stabilized with yttria. Appl. Opt. 21:2978-2981, doi:10.1364/AO.21.002978 (12 % mol de Y₂O₃, 25 °C, medida de 0,36 a 5,1 µm: transparente en todo el visible; " + SRC_RI_INFO + ")"
const SRC_NASSAU_1997 := "Nassau K, McClure SF, Elen S, Shigley JE (1997). Synthetic moissanite: a new diamond substitute. Gems & Gemology 33:260-275 (n_o 2,648 y n_e 2,691, birrefringencia 0,043 y dispersión 0,104; de casi incolora a amarillo, verde o gris claros, la mejor como un color I del diamante; absorción por debajo de ~425 nm; brillo de pulido subadamantino)"
const SRC_RUBIN := "Rubin M (1985). Optical properties of soda lime silica glasses. Sol. Energy Mater. 12:275-288, doi:10.1016/0165-1633(85)90052-8 (vidrio de ventana claro: n = 1,5130 − 0,003169·λ² + 0,003962/λ², λ en µm, y su índice de absorción k de 0,31 a 4,6 µm; " + SRC_RI_INFO + ")"
const SRC_SCHOTT_LLF1 := "SCHOTT, catálogo de vidrio óptico (Zemax, 2017-01-20): LLF1, flint ligero con plomo, n_d 1,548 y ν_d 45,7, con su fórmula de Sellmeier y un índice de absorción k de ~10⁻⁸ en el visible (" + SRC_RI_INFO + ")"
const SRC_DIRECTIVE := "Directiva 69/493/CEE del Consejo, anexo I: el cristal al plomo (PbO ≥ 24 %) tiene un índice de refracción n_D ≥ 1,545"
const SRC_LEERTOUWER := "Leertouwer HL, Wilts BD, Stavenga DG (2011). Refractive index and dispersion of butterfly chitin and bird keratin measured by polarizing interference microscopy. Opt. Express 19:24061-24066, doi:10.1364/OE.19.024061 (queratina de las bárbulas de una pluma de ganso: n(λ) = 1,532 + 5890/λ², λ en nm)"
const SRC_YUAN := "Yuan B, Guo Y, Liu Z (2022). The influence of light path length on the color of synthetic ruby. Sci. Rep. 12:5943, doi:10.1038/s41598-022-08811-y (rubí de fusión a la llama, 0,998 % de Cr₂O₃ por ED-XRF semicuantitativo: CIE L*a*b* con D65 a 1, 5 y 10 mm de camino, rayos o y e)"
const SRC_DUBINSKY := "Dubinsky EV, Stone-Sundberg J, Emmett JL (2020). A quantitative description of the causes of color in corundum. Gems & Gemology 56:2-28 (sección eficaz del par Fe²⁺-Ti⁴⁺ del zafiro azul, E⊥c y E∥c, de su figura 10: pico de 1,94·10⁻¹⁸ cm² ± 25 % a 580 nm; 1 ppma = 1,178·10¹⁷ iones/cm³; sus círculos de color van de 1,5 a 15 ppma·cm)"
const SRC_WYMAN := "Wyman C, Sloan P-P, Shirley P (2013). Simple analytic approximations to the CIE XYZ color matching functions. J. Comput. Graph. Tech. 2(2):1-11 (observador CIE 1931 con el ajuste de varios lóbulos: ecuación 4 y tabla 1)"
const SRC_SRGB := "IEC 61966-2-1:1999 (sRGB): matriz de XYZ a RGB lineal y blanco D65; CIE 15:2004 para CIE L*a*b*"
const SRC_PLANCK := "ley de Planck con las constantes CODATA 2018 (c₁ = 3,741771852·10⁻¹⁶ W·m², c₂ = 1,438776877·10⁻² m·K); un cuerpo negro de 6504 K, la temperatura de color correlacionada del iluminante D65, hace de D65"
const SRC_BENNETT := "Bennett HE, Porteus JO (1961). Relation between surface roughness and specular reflectance at normal incidence. J. Opt. Soc. Am. 51:123-129, doi:10.1364/JOSA.51.000123 (R_especular = R₀·exp(−(4πσ/λ)²), σ la rugosidad rms)"
const SRC_LAMBROPOULOS := "Lambropoulos JC, Fang T, Funkenbusch PD, Jacobs SD, Cumbo MJ, Golini D (1996). Surface microroughness of optical glasses under deterministic microgrinding. Appl. Opt. 35:4448-4462, doi:10.1364/AO.35.004448 (el microrrectificado con diamante ligado deja superficies especulares de ~20 nm rms)"
const SRC_PROCESS_RA := "rugosidad típica de cada proceso (tablas de ASME B46.1 recogidas en el Machinery's Handbook): colado a la cera perdida y piezas sinterizadas, Ra de 1,6 a 3,2 µm; rectificado, de 0,1 a 1,6 µm; Rq ≈ 1,25·Ra en una superficie de alturas gaussianas"
const SRC_SCHNABEL := "Schnabel V, Spolenak R, Döbeli M, Galinski H (2018). Structural color sensors with thermal memory: measuring functional properties of Ti-based nitrides by eye. Adv. Opt. Mater. 6:1800656, doi:10.1002/adom.201800656 (TiN por pulverización reactiva con el sustrato a 400 °C; " + SRC_RI_INFO + ")"
const SRC_GILSHTEIN :="Gilshtein E, Pfeiffer S, Rossell MD, Sastre J, Gorjan L, Erni R, Tiwari AN, Graule T, Romanyuk YE (2021). Millisecond photonic sintering of iron oxide doped alumina ceramic coatings. Sci. Rep. 11:3536, doi:10.1038/s41598-021-82896-9 (la alúmina, con una banda prohibida de 7-8 eV, es blanca: refleja casi todo el visible)"
## Unidad 5p: el índice del PMMA, el polímero del acrílico dental (y, como caso medido más parecido, el de la resina).
const SRC_SULTANOVA := "Sultanova N, Kasarova S, Nikolov I (2009). Dispersion properties of optical polymers. Acta Phys. Pol. A 116:585-587 (PMMA, un polímero óptico transparente en el visible: n² − 1 = 1,1819·λ²/(λ² − 0,011313), λ en µm, medido de 437 a 1052 nm; " + SRC_RI_INFO + ")"
const SRC_PROSTHESIS_COLOR := "el color de la ficha de la prótesis de la reforja (ForgeData.PROSTHESIS.acrilico, #E6DCCF, dibujo): el acrílico dental de color diente lleva pigmentos y opacificantes que difunden la luz; el PMMA sin teñir es transparente"

# ════════ Longitudes de onda ════════
## Líneas de referencia (nm): la D del sodio (los índices de las gemas) y las B y G de Fraunhofer (la dispersión B–G, el
## «fuego» de la gemología); F, C y d (el número de Abbe de los vidrios).
const LAMBDA_D := 589.3
const LAMBDA_B := 686.7
const LAMBDA_G := 430.8
const LAMBDA_F := 486.1
const LAMBDA_C := 656.3
const LAMBDA_HE_D := 587.6
## Longitud de onda de cada canal de color para la refracción (nm): el centroide de la parte positiva de la función de
## igualación de cada canal sRGB (CIE 1931 de Wyman et al. con la matriz de IEC 61966-2-1, energía igual). Es una
## elección de dibujo (un canal de una pantalla no es una sola longitud de onda); channel_wavelengths() la recalcula.
const CHANNEL_NM := [601.2, 540.7, 451.8]
## Intervalo y paso de la integración espectral (nm).
const SPECTRUM_FROM := 380.0
const SPECTRUM_TO := 780.0
const SPECTRUM_STEP := 5.0
## Temperatura del iluminante (K): la de D65 (SRC_PLANCK).
const ILLUMINANT_K := 6504.0
## Constantes de Planck (CODATA 2018).
const PLANCK_C1 := 3.741771852e-16
const PLANCK_C2 := 1.438776877e-2
## XYZ → sRGB lineal (IEC 61966-2-1), por filas.
const XYZ_TO_RGB := [[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]]
## Blanco D65 de CIE L*a*b* (CIE 15:2004), Y = 100.
const D65_WHITE := [95.047, 100.0, 108.883]
## Ajuste de varios lóbulos del observador CIE 1931 (Wyman et al. 2013, tabla 1): [α, β (nm), γ (1/nm, antes del
## centro), δ (1/nm, después)].
const CIE_X_LOBES := [[0.362, 442.0, 0.0624, 0.0374], [1.056, 599.8, 0.0264, 0.0323], [-0.065, 501.1, 0.0490, 0.0382]]
const CIE_Y_LOBES := [[0.821, 568.8, 0.0213, 0.0247], [0.286, 530.9, 0.0613, 0.0322]]
const CIE_Z_LOBES := [[1.217, 437.0, 0.0845, 0.0278], [0.681, 459.0, 0.0385, 0.0725]]

# ════════ Datos medidos ════════
## Índice complejo de los metales: [λ (µm), n, k], en el intervalo visible de cada serie publicada.
const NK_GOLD := [
	[0.3679, 1.48, 1.895], [0.3815, 1.46, 1.933], [0.3974, 1.47, 1.952], [0.4133, 1.46, 1.958], [0.4305, 1.45, 1.948],
	[0.4509, 1.38, 1.914], [0.4714, 1.31, 1.849], [0.4959, 1.04, 1.833], [0.5209, 0.62, 2.081], [0.5486, 0.43, 2.455],
	[0.5821, 0.29, 2.863], [0.6168, 0.21, 3.272], [0.6595, 0.14, 3.697], [0.7045, 0.13, 4.103], [0.7560, 0.14, 4.542],
	[0.8211, 0.16, 5.083],
]
const NK_TITANIUM := [
	[0.368, 1.90, 2.90], [0.381, 1.99, 2.93], [0.397, 2.08, 2.95], [0.413, 2.14, 2.98], [0.431, 2.21, 3.01],
	[0.451, 2.27, 3.04], [0.471, 2.32, 3.10], [0.496, 2.36, 3.19], [0.521, 2.44, 3.30], [0.549, 2.54, 3.43],
	[0.582, 2.60, 3.58], [0.617, 2.67, 3.72], [0.659, 2.76, 3.84], [0.704, 2.86, 3.96], [0.756, 3.00, 4.01],
	[0.821, 3.21, 4.01],
]
const NK_STAINLESS := [
	[0.36, 1.4354, 2.5447], [0.38, 1.4786, 2.6681], [0.40, 1.5249, 2.7925], [0.42, 1.5762, 2.9240], [0.44, 1.6386, 3.0555],
	[0.46, 1.7169, 3.1785], [0.48, 1.7921, 3.2933], [0.50, 1.8636, 3.4010], [0.52, 1.9349, 3.5072], [0.54, 2.0072, 3.6166],
	[0.56, 2.0807, 3.7298], [0.58, 2.1557, 3.8451], [0.60, 2.2325, 3.9594], [0.62, 2.3122, 4.0504], [0.64, 2.3962, 4.1378],
	[0.66, 2.4839, 4.2261], [0.68, 2.5731, 4.3155], [0.70, 2.6617, 4.4066], [0.72, 2.7486, 4.5036], [0.74, 2.8331, 4.5851],
	[0.76, 2.9143, 4.6435], [0.78, 2.9915, 4.7009], [0.80, 3.0655, 4.7583],
]
## Recubrimientos de la reforja: nitruro de titanio por PVD (Schnabel et al. 2018, pulverizado a 400 °C, como el de la
## ficha de BALINIT A de la reforja) y cromo duro (Johnson & Christy 1974).
const NK_TIN := [
	[0.3600, 2.148, 1.026], [0.3791, 2.064, 0.969], [0.3981, 1.947, 0.912], [0.4172, 1.791, 0.898], [0.4363, 1.621, 0.926],
	[0.4553, 1.449, 0.999], [0.4744, 1.295, 1.122], [0.4934, 1.173, 1.270], [0.5124, 1.085, 1.434], [0.5315, 1.020, 1.578],
	[0.5505, 0.965, 1.728], [0.5695, 0.922, 1.876], [0.5886, 0.888, 2.025], [0.6076, 0.855, 2.170], [0.6267, 0.829, 2.309],
	[0.6457, 0.813, 2.455], [0.6648, 0.797, 2.589], [0.6839, 0.793, 2.727], [0.7029, 0.789, 2.868], [0.7220, 0.792, 3.001],
	[0.7410, 0.788, 3.119], [0.7601, 0.796, 3.246], [0.7791, 0.809, 3.365], [0.7980, 0.817, 3.497],
]
const NK_CHROMIUM := [
	[0.368, 1.87, 2.69], [0.381, 1.92, 2.74], [0.397, 2.00, 2.83], [0.413, 2.08, 2.93], [0.431, 2.19, 3.04],
	[0.451, 2.33, 3.14], [0.471, 2.51, 3.24], [0.496, 2.75, 3.30], [0.521, 2.94, 3.33], [0.549, 3.18, 3.33],
	[0.582, 3.22, 3.30], [0.617, 3.17, 3.30], [0.659, 3.09, 3.34], [0.704, 3.05, 3.39], [0.756, 3.08, 3.42],
	[0.821, 3.20, 3.48],
]
## Reflectancia medida a incidencia normal: [λ (nm), R]. Hematites: la media de R1 y R2 del Handbook of Mineralogy (los
## dos extremos de su anisotropía). Carburo de tungsteno: Chono et al. (2025), leída de la figura (por debajo de 496 nm,
## su cálculo ab initio).
const R_HEMATITE := [
	[400.0, 0.33250], [420.0, 0.32500], [440.0, 0.31750], [460.0, 0.30900], [480.0, 0.30300], [500.0, 0.29700],
	[520.0, 0.29100], [540.0, 0.28800], [560.0, 0.28600], [580.0, 0.28200], [600.0, 0.27350], [620.0, 0.26550],
	[640.0, 0.25800], [660.0, 0.25100], [680.0, 0.24600], [700.0, 0.24200],
]
const R_TUNGSTEN_CARBIDE := [[413.0, 0.46], [496.0, 0.48], [689.0, 0.47], [780.0, 0.47]]

## Fórmulas de dispersión (λ en µm), con los coeficientes de cada autor:
##   «sellmeier1»: n² − 1 = c0 + Σ c_i·λ²/(λ² − c_{i+1}²);  «sellmeier2»: n² − 1 = c0 + Σ c_i·λ²/(λ² − c_{i+1});
##   «cauchy»: n = c0 + c1/λ² (+ c2/λ⁴);  «rubin»: n = c0 + c1·λ² + c2/λ² (Rubin 1985).
const DISP_DIAMOND := { "type": "sellmeier1", "c": [0.0, 0.3306, 0.1750, 4.3356, 0.1060] }
const DISP_CORUNDUM_O := { "type": "sellmeier1", "c": [0.0, 1.4313493, 0.0726631, 0.65054713, 0.1193242, 5.3414021, 18.028251] }
const DISP_CORUNDUM_E := { "type": "sellmeier1", "c": [0.0, 1.5039759, 0.0740288, 0.55069141, 0.1216529, 6.5927379, 20.072248] }
const DISP_QUARTZ_O := { "type": "sellmeier2", "c": [0.28604141, 1.07044083, 1.00585997e-2, 1.10202242, 100.0] }
const DISP_QUARTZ_E := { "type": "sellmeier2", "c": [0.28851804, 1.09509924, 1.02101864e-2, 1.15662475, 100.0] }
const DISP_CZ := { "type": "sellmeier1", "c": [0.0, 1.347091, 0.062543, 2.117788, 0.166739, 9.452943, 24.320570] }
const DISP_SODA_LIME := { "type": "rubin", "c": [1.5130, -0.003169, 0.003962] }
const DISP_LLF1 := { "type": "sellmeier2", "c": [0.0, 1.21640125, 0.00857807248, 0.13366454, 0.0420143003, 0.883399468, 107.59306] }
## Queratina de ave (Leertouwer et al. 2011): n = 1,532 + 5890 nm²/λ² = 1,532 + 0,00589 µm²/λ².
const DISP_KERATIN := { "type": "cauchy", "c": [1.532, 0.00589] }
## PMMA (Sultanova et al. 2009): n² − 1 = 1,1819·λ²/(λ² − 0,011313), λ en µm. La línea G (430,8 nm) queda 6 nm por debajo
## de lo medido (437 nm): la dispersión B–G se extrapola esos 6 nm.
const DISP_PMMA := { "type": "sellmeier2", "c": [0.0, 1.1819, 0.011313] }
## Moissanita: los índices y la dispersión B–G de Nassau et al. (1997) en una ley de Cauchy de dos términos (la forma de
## la curva es una suposición; los tres números son los medidos en la gema).
const MOISSANITE := { "n_o": 2.648, "n_e": 2.691, "dispersion_bg": 0.104 }

## Rubí sintético (Yuan et al. 2022): CIE L*a*b* (D65) a 1, 5 y 10 mm de camino, rayos o y e.
const RUBY_LAB := {
	"o": [[1.0, 81.72, 25.72, -5.4], [5.0, 49.87, 62.93, -2.44], [10.0, 36.32, 59.90, 14.46]],
	"e": [[1.0, 83.79, 12.85, -3.62], [5.0, 48.49, 48.52, -4.78], [10.0, 33.95, 57.04, 9.98]],
}
## Zafiro azul: sección eficaz del par Fe²⁺-Ti⁴⁺ (×10⁻¹⁸ cm²), E⊥c y E∥c, cada 10 nm de 340 a 780 nm: digitalizada de los
## trazos vectoriales de la figura 10 de Dubinsky et al. (2020) (su pico E⊥c, 1,98 a 580 nm, frente a los 1,94 ± 25 % que
## da el texto).
const FETI_FROM_NM := 340.0
const FETI_STEP_NM := 10.0
const FETI_PERP := [
	0.160, 0.178, 0.201, 0.230, 0.260, 0.284, 0.305, 0.325, 0.346, 0.373, 0.408, 0.455, 0.517, 0.600, 0.701, 0.827,
	0.972, 1.139, 1.315, 1.497, 1.663, 1.803, 1.903, 1.963, 1.980, 1.964, 1.922, 1.867, 1.807, 1.744, 1.685, 1.631,
	1.583, 1.542, 1.503, 1.464, 1.423, 1.379, 1.330, 1.276, 1.219, 1.157, 1.096, 1.030, 0.967,
]
const FETI_PAR := [
	0.086, 0.118, 0.162, 0.212, 0.261, 0.306, 0.348, 0.383, 0.412, 0.438, 0.463, 0.491, 0.522, 0.552, 0.574, 0.589,
	0.596, 0.604, 0.619, 0.645, 0.680, 0.718, 0.756, 0.795, 0.833, 0.872, 0.913, 0.957, 1.002, 1.048, 1.091, 1.132,
	1.169, 1.203, 1.228, 1.245, 1.255, 1.256, 1.247, 1.229, 1.203, 1.170, 1.132, 1.088, 1.041,
]
## Iones por cm³ en 1 ppma de corindón (Dubinsky et al. 2020).
const PPMA_IONS_CM3 := 1.178e17
## Pares Fe²⁺-Ti⁴⁺ del zafiro azul del simulador (ppma): ESTIMACIÓN, un azul medio dentro de los círculos de color de
## Dubinsky et al. (de 1,5 a 15 ppma·cm en una piedra de 1 cm).
const SAPPHIRE_FETI_PPMA := { "value": 6.0, "min": 1.5, "max": 15.0, "quality": "estimate", "source": "un zafiro azul medio: los círculos de color de " + SRC_DUBINSKY + " van de 1,5 a 15 ppma·cm; con 6 ppma, 10 mm de piedra dejan pasar el 74 % del azul y el 29 % del rojo. La concentración de un zafiro concreto varía de una piedra a otra" }
## Vidrio sodocálcico (Rubin 1985): índice de absorción k, [λ (nm), k].
const K_SODA_LIME := [
	[360.0, 5.419e-7], [370.0, 4.061e-7], [380.0, 5.936e-7], [390.0, 2.828e-7], [400.0, 2.047e-7], [410.0, 2.182e-7],
	[420.0, 2.279e-7], [430.0, 2.397e-7], [440.0, 2.342e-7], [450.0, 1.925e-7], [460.0, 1.669e-7], [470.0, 1.700e-7],
	[480.0, 1.683e-7], [490.0, 1.554e-7], [500.0, 1.492e-7], [510.0, 1.499e-7], [520.0, 1.582e-7], [530.0, 1.769e-7],
	[540.0, 1.988e-7], [550.0, 2.200e-7], [560.0, 2.529e-7], [570.0, 3.051e-7], [580.0, 3.563e-7], [590.0, 4.003e-7],
	[600.0, 4.548e-7], [610.0, 5.217e-7], [620.0, 5.972e-7], [630.0, 6.913e-7], [640.0, 7.754e-7], [650.0, 8.371e-7],
	[660.0, 9.108e-7], [670.0, 1.009e-6], [680.0, 1.097e-6], [690.0, 1.159e-6], [700.0, 1.234e-6], [710.0, 1.349e-6],
	[720.0, 1.466e-6], [730.0, 1.585e-6], [740.0, 1.706e-6], [750.0, 1.830e-6], [760.0, 1.956e-6], [770.0, 2.085e-6],
	[780.0, 2.214e-6],
]
## Corte de absorción de la moissanita (nm): por debajo no pasa la luz en una piedra de milímetros (Nassau et al. 1997).
const MOISSANITE_CUTOFF_NM := 425.0

# ════════ Números derivados (los recalcula un test con las funciones de abajo) ════════
## F0: reflectancia a incidencia normal en sRGB lineal (sin recortar: el oro pasa de 1 en el rojo); ior: índice de cada
## canal (CHANNEL_NM), rayo ordinario y extraordinario; absorption: 1/mm en cada canal; tint: transmitancia que no depende
## del espesor (un corte de absorción); n_d, dispersion_bg, birefringence (n_e − n_o) y abbe.
const DERIVED := {
	"none": { "f0": [0.0463, 0.0468, 0.0480], "ior": [1.5483, 1.5521, 1.5609], "ior_e": [], "n_d": 1.5490, "dispersion_bg": 0.0192, "birefringence": 0.0, "abbe": 48.8, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"oro": { "f0": [1.0249, 0.7325, 0.3658] },
	"acero": { "f0": [0.6679, 0.6395, 0.5976] },
	"titanio": { "f0": [0.6170, 0.5799, 0.5424] },
	"tungsteno": { "f0": [0.4716, 0.4788, 0.4686] },
	"hematites": { "f0": [0.2635, 0.2872, 0.3162] },
	"vidrio": { "f0": [0.0429, 0.0433, 0.0441], "ior": [1.5228, 1.5256, 1.5318], "ior_e": [], "n_d": 1.5233, "dispersion_bg": 0.0139, "birefringence": 0.0, "abbe": 63.9, "absorption": [0.0137, 0.0046, 0.0054], "tint": [1.0, 1.0, 1.0] },
	"swarovski": { "f0": [0.0462, 0.0467, 0.0480], "ior": [1.5473, 1.5514, 1.5609], "ior_e": [], "n_d": 1.5480, "dispersion_bg": 0.0209, "birefringence": 0.0, "abbe": 45.7, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"cuarzo": { "f0": [0.0457, 0.0460, 0.0468], "ior": [1.5437, 1.5464, 1.5523], "ior_e": [1.5528, 1.5556, 1.5617], "n_d": 1.5442, "dispersion_bg": 0.0133, "birefringence": 0.0091, "abbe": 69.7, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"circonita": { "f0": [0.1342, 0.1360, 0.1400], "ior": [2.1565, 2.1682, 2.1959], "ior_e": [], "n_d": 2.1585, "dispersion_bg": 0.0604, "birefringence": 0.0, "abbe": 33.5, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"zafiro": { "f0": [0.0769, 0.0774, 0.0786], "ior": [1.7674, 1.7711, 1.7791], "ior_e": [1.7594, 1.7629, 1.7708], "n_d": 1.7681, "dispersion_bg": 0.0181, "birefringence": -0.0081, "abbe": 72.3, "absorption": [0.1230, 0.0952, 0.0299], "tint": [1.0, 1.0, 1.0] },
	"rubi": { "f0": [0.0769, 0.0774, 0.0786], "ior": [1.7674, 1.7711, 1.7791], "ior_e": [1.7594, 1.7629, 1.7708], "n_d": 1.7681, "dispersion_bg": 0.0181, "birefringence": -0.0081, "abbe": 72.3, "absorption": [0.0926, 0.5639, 0.2799], "tint": [1.0, 1.0, 1.0] },
	"alumina": { "f0": [0.0769, 0.0774, 0.0786], "ior": [1.7674, 1.7711, 1.7791], "ior_e": [], "n_d": 1.7681, "dispersion_bg": 0.0181, "birefringence": 0.0, "abbe": 72.3, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"moissanita": { "f0": [0.2036, 0.2064, 0.2127], "ior": [2.6444, 2.6652, 2.7123], "ior_e": [2.6874, 2.7082, 2.7553], "n_d": 2.6480, "dispersion_bg": 0.1040, "birefringence": 0.0430, "abbe": 0.0, "absorption": [0.0, 0.0, 0.0], "tint": [0.9860, 1.0116, 0.9204] },
	"diamante": { "f0": [0.1718, 0.1730, 0.1759], "ior": [2.4158, 2.4245, 2.4448], "ior_e": [], "n_d": 2.4173, "dispersion_bg": 0.0444, "birefringence": 0.0, "abbe": 55.3, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"zafiro_incoloro": { "f0": [0.0769, 0.0774, 0.0786], "ior": [1.7674, 1.7711, 1.7791], "ior_e": [1.7594, 1.7629, 1.7708], "n_d": 1.7681, "dispersion_bg": 0.0181, "birefringence": -0.0081, "abbe": 72.3, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"tin": { "f0": [0.6599, 0.4122, 0.1499] },
	"cromo": { "f0": [0.5496, 0.5561, 0.5537] },
	"acrilico": { "f0": [0.0387, 0.0391, 0.0401], "ior": [1.4900, 1.4931, 1.5004], "ior_e": [], "n_d": 1.4905, "dispersion_bg": 0.0159, "birefringence": 0.0, "abbe": 53.2, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
	"resina": { "f0": [0.0387, 0.0391, 0.0401], "ior": [1.4900, 1.4931, 1.5004], "ior_e": [], "n_d": 1.4905, "dispersion_bg": 0.0159, "birefringence": 0.0, "abbe": 53.2, "absorption": [0.0, 0.0, 0.0], "tint": [1.0, 1.0, 1.0] },
}

# ════════ Catálogo de materiales ════════
## Por id (los de Data.INLAYS, «none» la queratina, los de la reforja: «rubi» y «alumina», y los de la prótesis de verdad
## de una garra rota, unidad 5p: «acrilico», el acrílico dental de ForgeData.PROSTHESIS, y «resina», la resina
## fotopolimerizable que se cura con la lámpara en la cetrería). family: «queratina», «metal», «mineral» (opaco con reflejo
## de metal), «gema», «vidrio», «ceramica» o «polimero» (un dieléctrico de cuerpo translúcido: lo que difunden sus
## pigmentos y cargas, scatter). Cada dato óptico, con su fuente.
const MATERIAL_IDS := ["none", "oro", "acero", "titanio", "tungsteno", "vidrio", "swarovski", "hematites", "cuarzo", "circonita", "zafiro", "rubi", "alumina", "moissanita", "diamante", "acrilico", "resina"]
## Lo que también puede verse en una garra de la reforja: el zafiro sintético incoloro de Verneuil (la receta «zafiro»)
## y los recubrimientos de metal (nitruro de titanio y cromo duro).
const EXTRA_IDS := ["zafiro_incoloro", "tin", "cromo"]
const MATERIALS := {
	"none": {
		"name": "Queratina", "family": "queratina", "optic": "isótropo", "luster": "céreo a vítreo",
		"index": { "value": DISP_KERATIN, "quality": "secondary", "source": SRC_LEERTOUWER + ". Caso medido más parecido: la queratina β de una pluma (la de las garras de aves y reptiles); la queratina α de los mamíferos tiene un índice del mismo orden" },
		"color": { "value": "el de cada especie (Data.CLAWS)", "quality": "dibujo", "source": "color de la ficha de cada garra (dibujo de la 1.x)" },
	},
	"oro": {
		"name": "Oro", "family": "metal", "luster": "metálico",
		"nk": { "value": NK_GOLD, "quality": "primary", "source": SRC_JC1972 + ". El pan de oro del banco es oro casi puro" },
	},
	"acero": {
		"name": "Acero inoxidable", "family": "metal", "luster": "metálico",
		"nk": { "value": NK_STAINLESS, "quality": "secondary", "source": SRC_KARLSSON + ". Caso medido más parecido al 304 de la tachuela del banco (18 % de Cr y 8 % de Ni): un austenítico del mismo grupo" },
	},
	"titanio": {
		"name": "Titanio", "family": "metal", "luster": "metálico",
		"nk": { "value": NK_TITANIUM, "quality": "primary", "source": SRC_JC1974 + ". El titanio de grado 2 del banco es titanio comercialmente puro" },
	},
	"tungsteno": {
		"name": "Carburo de tungsteno", "family": "metal", "luster": "metálico",
		"reflectance": { "value": R_TUNGSTEN_CARBIDE, "quality": "estimate", "source": SRC_CHONO + ". Caso medido más parecido al metal duro del banco (94,5 % de WC y 5,5 % de cobalto): el WC sin aglutinante; el cobalto, poco, lo aclara algo" },
	},
	"hematites": {
		"name": "Hematites", "family": "mineral", "luster": "metálico a submetálico",
		"reflectance": { "value": R_HEMATITE, "quality": "primary", "source": SRC_HOM_HEMATITE },
	},
	"vidrio": {
		"name": "Vidrio (strass)", "family": "vidrio", "optic": "isótropo", "luster": "vítreo",
		"index": { "value": DISP_SODA_LIME, "quality": "estimate", "source": SRC_RUBIN + ". Caso medido más parecido: el vidrio sodocálcico, el mismo de su densidad y su resistencia en el banco; un strass de vidrio al plomo tendría algo más de índice" },
		"absorption": { "value": "k", "quality": "estimate", "source": SRC_RUBIN + ": el hierro del vidrio claro absorbe algo más el rojo (el canto verdoso de una luna)" },
	},
	"swarovski": {
		"name": "Cristal Swarovski", "family": "vidrio", "optic": "isótropo", "luster": "vítreo",
		"index": { "value": DISP_LLF1, "quality": "estimate", "source": SRC_SCHOTT_LLF1 + ". Caso medido más parecido: el cristal clásico es cristal al plomo con n_D ≥ 1,545 (" + SRC_DIRECTIVE + "); Swarovski no publica su fórmula" },
		"absorption": { "value": 0.0, "quality": "estimate", "source": SRC_SCHOTT_LLF1 + ": con k ~10⁻⁸, 10 mm absorben menos de un 0,2 %: incoloro" },
	},
	"cuarzo": {
		"name": "Cuarzo (cristal de roca)", "family": "gema", "optic": "uniáxico (+)", "luster": "vítreo",
		"index": { "value": DISP_QUARTZ_O, "e": DISP_QUARTZ_E, "quality": "primary", "source": SRC_GHOSH + ". Handbook of Mineralogy: ω = 1,544, ε = 1,553" },
		"absorption": { "value": 0.0, "quality": "secondary", "source": SRC_HOM_GEMS },
	},
	"circonita": {
		"name": "Circonita", "family": "gema", "optic": "isótropo", "luster": "adamantino",
		"index": { "value": DISP_CZ, "quality": "primary", "source": SRC_WOOD_NASSAU },
		"absorption": { "value": 0.0, "quality": "primary", "source": SRC_WOOD_NASSAU },
	},
	"zafiro": {
		"name": "Zafiro azul", "family": "gema", "optic": "uniáxico (−)", "luster": "adamantino a vítreo",
		"index": { "value": DISP_CORUNDUM_O, "e": DISP_CORUNDUM_E, "quality": "primary", "source": SRC_MALITSON + ". Handbook of Mineralogy: ω = 1,767–1,772, ε = 1,759–1,763" },
		"absorption": { "value": "feti", "quality": "estimate", "source": SRC_DUBINSKY + ". El azul es del hierro y el titanio: la carga que salta del Fe²⁺ al Ti⁴⁺ absorbe el amarillo y el rojo. Concentración de pares: 6 ppma, un azul medio (estimación)" },
	},
	"rubi": {
		"name": "Rubí", "family": "gema", "optic": "uniáxico (−)", "luster": "adamantino a vítreo",
		"index": { "value": DISP_CORUNDUM_O, "e": DISP_CORUNDUM_E, "quality": "secondary", "source": SRC_MALITSON + ". El rubí es corindón con algo de cromo: su índice es el del zafiro sintético (el Handbook of Mineralogy da la misma banda para todo el corindón)" },
		"absorption": { "value": "lab", "quality": "secondary", "source": SRC_YUAN + ". El rojo es del cromo: el Cr³⁺ absorbe el verde-amarillo (~550 nm) y el violeta (~410 nm) y deja pasar el rojo y algo de azul. Absorción por canal ajustada a Beer–Lambert entre 1 y 10 mm, media de los rayos o y e" },
	},
	"alumina": {
		"name": "Alúmina", "family": "ceramica", "optic": "policristal", "luster": "vítreo a mate",
		"index": { "value": DISP_CORUNDUM_O, "quality": "estimate", "source": SRC_MALITSON + ". La alúmina sinterizada es corindón policristalino: su reflejo es el del corindón" },
		"albedo": { "value": [0.88, 0.87, 0.85], "quality": "estimate", "source": SRC_GILSHTEIN + ". Sin espectro medido de la pieza: blanco marfil que difunde casi toda la luz (el color de la ficha de la reforja, #F4F1EA, en sRGB lineal ≈ 0,90; 0,88 tras el reflejo)" },
	},
	"moissanita": {
		"name": "Moissanita", "family": "gema", "optic": "uniáxico (+)", "luster": "subadamantino",
		"index": { "value": MOISSANITE, "quality": "primary", "source": SRC_NASSAU_1997 + ". La curva entre las líneas B y G, una ley de Cauchy (suposición)" },
		"absorption": { "value": "cutoff", "quality": "primary", "source": SRC_NASSAU_1997 + ": por debajo de 425 nm no pasa la luz, y eso le da un matiz amarillento leve" },
	},
	"diamante": {
		"name": "Diamante", "family": "gema", "optic": "isótropo", "luster": "adamantino",
		"index": { "value": DISP_DIAMOND, "quality": "primary", "source": SRC_PETER },
		"absorption": { "value": 0.0, "quality": "secondary", "source": SRC_HOM_GEMS + ". Se modela el diamante incoloro (tipo IIa, sin nitrógeno): no absorbe en el visible" },
	},
	"zafiro_incoloro": {
		"name": "Zafiro incoloro", "family": "gema", "optic": "uniáxico (−)", "luster": "adamantino a vítreo",
		"index": { "value": DISP_CORUNDUM_O, "e": DISP_CORUNDUM_E, "quality": "primary", "source": SRC_MALITSON },
		"absorption": { "value": 0.0, "quality": "secondary", "source": SRC_HOM_GEMS + ": el corindón sin hierro, titanio ni cromo (la alúmina pura de Verneuil de la reforja) es incoloro" },
	},
	"tin": {
		"name": "Nitruro de titanio", "family": "metal", "luster": "metálico",
		"nk": { "value": NK_TIN, "quality": "secondary", "source": SRC_SCHNABEL + ". La capa de la reforja (PVD a 250-400 °C, 1-4 µm) es opaca: la luz no pasa de unas decenas de nanómetros" },
	},
	"cromo": {
		"name": "Cromo duro", "family": "metal", "luster": "metálico",
		"nk": { "value": NK_CHROMIUM, "quality": "secondary", "source": "cromo puro: " + SRC_JC1974 + ". El cromo duro galvánico es cromo casi puro" },
	},
	# unidad 5p: la prótesis de verdad de una garra rota (no es ficción)
	"acrilico": {
		"name": "Acrílico dental", "family": "polimero", "optic": "isótropo (amorfo)", "luster": "vítreo",
		"index": { "value": DISP_PMMA, "quality": "primary", "source": SRC_SULTANOVA + ". El acrílico dental autopolimerizable es polvo de PMMA y líquido de metacrilato de metilo, que fragua en PMMA: su índice es el del PMMA" },
		"absorption": { "value": 0.0, "quality": "secondary", "source": SRC_SULTANOVA + ": el PMMA no absorbe en el visible (lo que se pierde al atravesar una placa clara es el reflejo de sus dos caras, un 4 % en cada una)" },
		"albedo": { "value": [0.791, 0.716, 0.624], "quality": "dibujo", "source": SRC_PROSTHESIS_COLOR + " (en sRGB lineal)" },
		"scatter": { "value": 0.85, "quality": "dibujo", "source": "lo que difunde el cuerpo del acrílico de color diente (0 transparente, 1 opaco): casi opaco, translúcido en lo fino. Sin medición a mano: dibujo" },
	},
	"resina": {
		"name": "Resina fotopolimerizable", "family": "polimero", "optic": "isótropo (amorfo)", "luster": "vítreo",
		"index": { "value": DISP_PMMA, "quality": "estimate", "source": "sin el índice medido de la resina curada a mano: caso medido más parecido, el PMMA, otro polimetacrilato (" + SRC_SULTANOVA + "); una resina de Bis-GMA con cargas de vidrio tendrá algo más de índice" },
		"absorption": { "value": 0.0, "quality": "estimate", "source": "como el PMMA, sin absorción en el visible (" + SRC_SULTANOVA + "); el color lo dan sus pigmentos y sus cargas (scatter y albedo)" },
		"albedo": { "value": [0.776, 0.680, 0.503], "quality": "dibujo", "source": "una resina de color natural, de un marfil algo amarillento como el de las resinas compuestas de los dentistas (#E4D7BC, en sRGB lineal): dibujo" },
		"scatter": { "value": 0.5, "quality": "dibujo", "source": "lo que difunde su cuerpo (0 transparente, 1 opaco): más translúcida que el acrílico de color diente, deja ver algo de lo de detrás. Sin medición a mano: dibujo" },
	},
}

# ════════ El color de la queratina de cada especie (petición 36) ════════
## Color de la garra natural de cada animal (id de Data.CLAWS): el de su ficha del banco, con lo que se sabe de él. Es
## dibujo con fuente: la queratina no tiene un color medido en estas garras; el de la ficha es el que pinta todo el
## programa (el banco, el coche en marcha, la cetrería y la galería) y aquí se dice de dónde sale.
const SRC_ADW_EAGLE := "Kirschbaum K, Ivory A (2002). Aquila chrysaetos. Animal Diversity Web, Universidad de Míchigan: «The bills and claws are black, while the cere and feet are yellow»"
const SRC_WSU_CAT := "Washington State University Veterinary Teaching Hospital (17-3-2022), «How to clip a cat's nails»: «Most cats have light colored claws, making it easy to see the pink blood vessels and nerves at the base of the nail, which is called the quick»"
const SRC_MTFWP := "Montana Fish, Wildlife & Parks, Bear Identification Course: el oso pardo (grizzly) tiene garras delanteras «gently curved, often light-colored, two- to four-inch long»; las del oso negro, «dark-colored»"
const KERATIN_COLORS := {
	"aguila": { "value": "#2E2A26", "quality": "secondary", "source": "garra negra: " + SRC_ADW_EAGLE + "; el color de la ficha del banco" },
	"arpia": { "value": "#3A3530", "quality": "estimate", "source": "caso documentado más parecido, el águila real, de garras negras (" + SRC_ADW_EAGLE + "); el color de la ficha del banco" },
	"halcon": { "value": "#5A5048", "quality": "estimate", "source": "caso documentado más parecido, el águila real (" + SRC_ADW_EAGLE + "); el color de la ficha del banco" },
	"buho": { "value": "#4A4034", "quality": "estimate", "source": "caso documentado más parecido, el águila real (" + SRC_ADW_EAGLE + "); el color de la ficha del banco" },
	"lechuza": { "value": "#C8B090", "quality": "dibujo", "source": "el color de la ficha del banco (dibujo de la 1.x)" },
	"buitre": { "value": "#6B5A45", "quality": "dibujo", "source": "el color de la ficha del banco (dibujo de la 1.x)" },
	"tigre": { "value": "#D9C49E", "quality": "estimate", "source": "garra clara de color cuerno, con la carne viva rosada a trasluz: caso documentado más parecido, el gato doméstico (" + SRC_WSU_CAT + "); el color de la ficha del banco" },
	"oso": { "value": "#46392E", "quality": "estimate", "source": "parda oscura, el color de la ficha del banco y el que pide la petición 36; el color varía de un oso a otro: " + SRC_MTFWP },
	"casuario": { "value": "#3A3431", "quality": "dibujo", "source": "sin color publicado de la daga: el gris pardo oscuro del modelo 3D del coche en marcha (4l); la ficha del banco pinta el ave entera de azul (#1F2A44), no la uña" },
	"velociraptor": { "value": "#4A3F35", "quality": "estimate", "source": "la queratina no fosiliza: caso documentado más parecido, sus parientes vivos, las rapaces, de garras negras (" + SRC_ADW_EAGLE + "); el color de la ficha del banco" },
	"velociraptor_pelicula": { "value": "#6B5B3E", "quality": "dibujo", "source": "el color de la ficha del velocirraptor de cine (dibujo de un diseño original)" },
}


## El color de la queratina natural de una garra (Color, sRGB): el de KERATIN_COLORS o, si no está, fallback.
static func keratin_color(claw_id: String, fallback := "#2E2A26") -> Color:
	var e: Variant = KERATIN_COLORS.get(claw_id)
	return Color(String((e as Dictionary).value) if e != null else fallback)


# ════════ Acabados ════════
## Acabado de la superficie: σ, la rugosidad rms (µm), con su fuente, y lo que se ve (facets: facetas talladas; scratch:
## rayas; chips: mellas; cracks: grietas; oxide: cascarilla u óxido; burn: grabado del fuego; pores: poros). Los ids de la
## reforja (ClawForge, ForgeData.FINISH_IDS) y los que da la cetrería: «limado» (la última lima o lija que mordió) y
## «mellado» (la punta mellada).
const FINISH_IDS := ["pulido", "tallado", "limado", "bruto", "poroso", "agrietado", "astillado", "mellado", "quemado", "oxidado", "defectuoso"]
const FINISH_NAMES := {
	"pulido": "Pulido", "tallado": "Tallado", "limado": "Limado", "bruto": "En bruto", "poroso": "Poroso", "agrietado": "Agrietado",
	"astillado": "Astillado", "mellado": "Mellado", "quemado": "Quemado", "oxidado": "Con cascarilla u óxido", "defectuoso": "Con defectos",
}
## σ de un pulido de espejo (µm): ESTIMACIÓN, por debajo de los ~20 nm rms del microrrectificado, que ya es especular.
const POLISH_SIGMA_UM := { "value": 0.005, "min": 0.001, "max": 0.02, "quality": "estimate", "source": "un pulido con pasta de diamante deja menos rugosidad que el microrrectificado con diamante ligado, que ya da superficies especulares de ~20 nm rms (" + SRC_LAMBROPOULOS + "); 5 nm, elección dentro de esa banda" }
## σ frente al tamaño del grano que la deja (σ ≈ k·grano): ESTIMACIÓN con el caso medido más parecido.
const GRAIN_SIGMA_RATIO := { "value": 0.008, "min": 0.005, "max": 0.013, "quality": "estimate", "source": "caso medido más parecido: el microrrectificado de vidrio óptico con diamante de 2-4 µm deja ~20 nm rms (" + SRC_LAMBROPOULOS + "), σ ≈ 0,8 % del grano; la misma proporción se toma para los granos más gruesos de las limas de diamante y las lijas (suposición)" }
## σ de una pieza en bruto, colada o sinterizada (µm): ESTIMACIÓN con la tabla de procesos.
const RAW_SIGMA_UM := { "value": 3.0, "min": 2.0, "max": 4.0, "quality": "estimate", "source": SRC_PROCESS_RA + " (Ra 1,6-3,2 µm → σ ≈ 2-4 µm)" }
## Grano de la muela de tallar por defecto (µm): el de la reforja (ForgeData.ABRASIVES, 91 µm en las muelas de lapidario).
const CARVE_GRAIN_UM := { "value": 91.0, "quality": "secondary", "source": "grano medio de las muelas de tallar de la reforja (claw_forge_data.gd, ABRASIVES)" }
const FINISHES := {
	"pulido": { "sigma": POLISH_SIGMA_UM, "facets": true, "scratch": 0.0 },
	"tallado": { "grain": CARVE_GRAIN_UM, "facets": true, "scratch": 0.6 },
	"limado": { "grain": null, "facets": false, "scratch": 1.0 },
	"bruto": { "sigma": RAW_SIGMA_UM, "facets": false, "scratch": 0.0 },
	"poroso": { "sigma": RAW_SIGMA_UM, "facets": false, "scratch": 0.0, "pores": 1.0 },
	"agrietado": { "sigma": POLISH_SIGMA_UM, "facets": true, "scratch": 0.0, "cracks": 3 },
	"astillado": { "grain": CARVE_GRAIN_UM, "facets": true, "scratch": 0.3, "chips": 3 },
	"mellado": { "sigma": POLISH_SIGMA_UM, "facets": true, "scratch": 0.0, "chips": 2 },
	"quemado": { "sigma": RAW_SIGMA_UM, "facets": false, "scratch": 0.0, "burn": 1.0 },
	"oxidado": { "sigma": RAW_SIGMA_UM, "facets": false, "scratch": 0.0, "oxide": 1.0 },
	"defectuoso": { "sigma": RAW_SIGMA_UM, "facets": false, "scratch": 0.2, "cracks": 1, "pores": 0.5 },
}


# ════════ Color: CIE 1931 → sRGB lineal ════════

static func _lobe(nm: float, l: Array) -> float:
	var t := (nm - float(l[1])) * (float(l[2]) if nm < float(l[1]) else float(l[3]))
	return float(l[0]) * V8.js_exp(-0.5 * t * t)


## Funciones de igualación CIE 1931 en nm (Wyman et al. 2013): [x̄, ȳ, z̄].
static func cie_xyz(nm: float) -> PackedFloat64Array:
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	for l: Array in CIE_X_LOBES:
		out[0] += _lobe(nm, l)
	for l: Array in CIE_Y_LOBES:
		out[1] += _lobe(nm, l)
	for l: Array in CIE_Z_LOBES:
		out[2] += _lobe(nm, l)
	return out


## Emitancia espectral de un cuerpo negro (W/(m²·m)) a nm y t_k.
static func planck(nm: float, t_k: float) -> float:
	var l := nm * 1.0e-9
	return PLANCK_C1 / (l * l * l * l * l * (V8.js_exp(PLANCK_C2 / (l * t_k)) - 1.0))


static func _to_rgb(x: float, y: float, z: float) -> PackedFloat64Array:
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	for i in 3:
		var row: Array = XYZ_TO_RGB[i]
		out[i] = float(row[0]) * x + float(row[1]) * y + float(row[2]) * z
	return out


## Pesos de la integración espectral: { nm (las muestras), w (x̄·S, ȳ·S, z̄·S por muestra, de tres en tres), white (sRGB
## lineal del reflector perfecto) }. Se calculan una vez para varias integrales.
static func spectral_weights() -> Dictionary:
	var nm := PackedFloat64Array()
	var w := PackedFloat64Array()
	var l := SPECTRUM_FROM
	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	while l <= SPECTRUM_TO + 1e-9:
		var s := planck(l, ILLUMINANT_K)
		var c := cie_xyz(l)
		nm.append(l)
		w.append(s * c[0])
		w.append(s * c[1])
		w.append(s * c[2])
		sx += s * c[0]
		sy += s * c[1]
		sz += s * c[2]
		l += SPECTRUM_STEP
	return { "nm": nm, "w": w, "white": _to_rgb(sx, sy, sz) }


## sRGB lineal de un espectro (reflectancia o transmitancia, 0-1, una muestra por longitud de onda de weights.nm),
## relativo al reflector perfecto: el blanco da (1, 1, 1).
static func spectrum_rgb(values: PackedFloat64Array, weights: Dictionary) -> PackedFloat64Array:
	var w: PackedFloat64Array = weights.w
	var x := 0.0
	var y := 0.0
	var z := 0.0
	for i in values.size():
		x += w[3 * i] * values[i]
		y += w[3 * i + 1] * values[i]
		z += w[3 * i + 2] * values[i]
	var rgb := _to_rgb(x, y, z)
	var white: PackedFloat64Array = weights.white
	for i in 3:
		rgb[i] /= white[i]
	return rgb


## CIE L*a*b* (D65) → sRGB lineal (sin recortar).
static func lab_to_linear_rgb(lab_l: float, lab_a: float, lab_b: float) -> PackedFloat64Array:
	var fy := (lab_l + 16.0) / 116.0
	var fx := fy + lab_a / 500.0
	var fz := fy - lab_b / 200.0
	var xyz := PackedFloat64Array()
	var i := 0
	for f: float in [fx, fy, fz]:
		var d := 6.0 / 29.0
		var v := f * f * f if f > d else 3.0 * d * d * (f - 4.0 / 29.0)
		xyz.append(float(D65_WHITE[i]) * v / 100.0)
		i += 1
	return _to_rgb(xyz[0], xyz[1], xyz[2])


## La longitud de onda de cada canal (nm): el centroide de la parte positiva de su función de igualación (energía igual).
static func channel_wavelengths() -> PackedFloat64Array:
	var num := PackedFloat64Array([0.0, 0.0, 0.0])
	var den := PackedFloat64Array([0.0, 0.0, 0.0])
	var l := SPECTRUM_FROM
	while l <= SPECTRUM_TO + 1e-9:
		var c := cie_xyz(l)
		var rgb := _to_rgb(c[0], c[1], c[2])
		for i in 3:
			var w := maxf(rgb[i], 0.0)
			num[i] += l * w
			den[i] += w
		l += 1.0
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	for i in 3:
		out[i] = num[i] / den[i]
	return out


# ════════ Interpolación de tablas ════════

## Valor de la columna col en x (interpolación lineal; fuera de la tabla, el extremo).
static func table_at(rows: Array, x: float, col := 1) -> float:
	var n := rows.size()
	if n == 0:
		return 0.0
	if x <= float(rows[0][0]):
		return float(rows[0][col])
	for i in range(1, n):
		var x1 := float(rows[i][0])
		if x <= x1:
			var x0 := float(rows[i - 1][0])
			var u := (x - x0) / (x1 - x0) if x1 > x0 else 0.0
			return float(rows[i - 1][col]) + (float(rows[i][col]) - float(rows[i - 1][col])) * u
	return float(rows[n - 1][col])


# ════════ Reflexión ════════

## Reflectancia a incidencia normal de un medio de índice complejo n + ik desde el aire.
static func normal_reflectance(n: float, k: float = 0.0) -> float:
	return ((n - 1.0) * (n - 1.0) + k * k) / ((n + 1.0) * (n + 1.0) + k * k)


## Reflectancia de Fresnel de un dieléctrico (luz sin polarizar) para el coseno del ángulo de incidencia cos_i, desde
## el aire hacia el índice n (1 con reflexión total).
static func fresnel(cos_i: float, n: float) -> float:
	var ci := clampf(absf(cos_i), 0.0, 1.0)
	var si2 := 1.0 - ci * ci
	var st2 := si2 / (n * n)
	if st2 >= 1.0:
		return 1.0
	var ct := sqrt(1.0 - st2)
	var rs := (ci - n * ct) / (ci + n * ct)
	var rp := (n * ci - ct) / (n * ci + ct)
	return 0.5 * (rs * rs + rp * rp)


## Ángulo crítico (grados) de la reflexión total interna de un índice n hacia el aire.
static func critical_angle_deg(n: float) -> float:
	var s := 1.0 / n
	return rad_to_deg(V8.js_atan2(s, sqrt(1.0 - s * s)))


## Reflectancia espectral (una muestra por longitud de onda de weights.nm) de un metal o mineral opaco; vacío si no lo es.
static func reflectance_spectrum(id: String, weights: Dictionary) -> PackedFloat64Array:
	var m: Dictionary = MATERIALS.get(id, {})
	var nm: PackedFloat64Array = weights.nm
	var out := PackedFloat64Array()
	if m.has("nk"):
		var rows: Array = m.nk.value
		for l: float in nm:
			out.append(normal_reflectance(table_at(rows, l / 1000.0, 1), table_at(rows, l / 1000.0, 2)))
	elif m.has("reflectance"):
		var rows: Array = m.reflectance.value
		for l: float in nm:
			out.append(table_at(rows, l))
	return out


## F0 de un metal o mineral (sRGB lineal, sin recortar), de su espectro medido.
static func metal_f0(id: String, weights: Dictionary = {}) -> PackedFloat64Array:
	var w := weights if not weights.is_empty() else spectral_weights()
	return spectrum_rgb(reflectance_spectrum(id, w), w)


# ════════ Refracción y dispersión ════════

## Índice de refracción a nm de una fórmula de dispersión (DISP_*).
static func index_from(disp: Dictionary, nm: float) -> float:
	var l := nm / 1000.0
	var l2 := l * l
	var c: Array = disp.c
	match String(disp.type):
		"sellmeier1", "sellmeier2":
			var sq := String(disp.type) == "sellmeier1"
			var n2 := 1.0 + float(c[0])
			var i := 1
			while i + 1 < c.size():
				var ci := float(c[i + 1])
				n2 += float(c[i]) * l2 / (l2 - (ci * ci if sq else ci))
				i += 2
			return sqrt(n2)
		"cauchy":
			return float(c[0]) + float(c[1]) / l2 + (float(c[2]) / (l2 * l2) if c.size() > 2 else 0.0)
		"rubin":
			return float(c[0]) + float(c[1]) * l2 + float(c[2]) / l2
	return 1.0


## Ley de Cauchy de dos términos que pasa por n_d (en LAMBDA_D) con la dispersión B–G dada.
static func cauchy_from(n_d: float, dispersion_bg: float) -> Dictionary:
	var lb := LAMBDA_B / 1000.0
	var lg := LAMBDA_G / 1000.0
	var ld := LAMBDA_D / 1000.0
	var b := dispersion_bg / (1.0 / (lg * lg) - 1.0 / (lb * lb))
	return { "type": "cauchy", "c": [n_d - b / (ld * ld), b] }


## Fórmula de dispersión de un material: ray «o» (ordinario, o la única) o «e» (extraordinario); {} si no es transparente.
static func dispersion_of(id: String, ray := "o") -> Dictionary:
	var m: Dictionary = MATERIALS.get(id, {})
	if not m.has("index"):
		return {}
	var idx: Dictionary = m.index
	var v: Dictionary = idx.value
	if v.has("n_o"):
		return cauchy_from(float(v.n_e if ray == "e" else v.n_o), float(v.dispersion_bg))
	if ray == "e":
		return idx.get("e", {})
	return v


## Índice de refracción de un material a nm (rayo o o e).
static func refractive_index(id: String, nm: float, ray := "o") -> float:
	var d := dispersion_of(id, ray)
	return index_from(d, nm) if not d.is_empty() else 1.0


## Dispersión B–G (n_G − n_B, el «fuego»).
static func dispersion_bg(id: String) -> float:
	return refractive_index(id, LAMBDA_G) - refractive_index(id, LAMBDA_B)


## Birrefringencia n_e − n_o a LAMBDA_D (0 si es isótropo).
static func birefringence(id: String) -> float:
	var e := dispersion_of(id, "e")
	if e.is_empty():
		return 0.0
	return index_from(e, LAMBDA_D) - refractive_index(id, LAMBDA_D)


## Número de Abbe ν_d = (n_d − 1)/(n_F − n_C) (0 si la fórmula no es la medida del material: la moissanita lleva una
## ley de Cauchy supuesta entre B y G).
static func abbe(id: String) -> float:
	var m: Dictionary = MATERIALS.get(id, {})
	if not m.has("index") or (m.index.value as Dictionary).has("n_o"):
		return 0.0
	var nf := refractive_index(id, LAMBDA_F)
	var nc := refractive_index(id, LAMBDA_C)
	return (refractive_index(id, LAMBDA_HE_D) - 1.0) / (nf - nc) if nf > nc else 0.0


## Índices de cada canal (CHANNEL_NM) de un rayo.
static func channel_indices(id: String, ray := "o") -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if dispersion_of(id, ray).is_empty():
		return out
	for nm: float in CHANNEL_NM:
		out.append(refractive_index(id, nm, ray))
	return out


# ════════ Absorción (color de lo transparente) ════════

## Absorción por milímetro en cada canal (sRGB lineal) ajustada a Beer–Lambert con las transmitancias t1 (espesor d1) y
## t2 (d2): α = ln(t1/t2)/(d2 − d1).
static func fit_absorption(t1: PackedFloat64Array, d1: float, t2: PackedFloat64Array, d2: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in 3:
		out.append(V8.js_log(maxf(t1[i], 1e-9) / maxf(t2[i], 1e-9)) / (d2 - d1))
	return out


## Rubí: la absorción de cada canal con los colores medidos a 1 y 10 mm (Yuan et al. 2022), media de los rayos o y e.
static func ruby_absorption() -> PackedFloat64Array:
	var acc := PackedFloat64Array([0.0, 0.0, 0.0])
	for ray: String in ["o", "e"]:
		var rows: Array = RUBY_LAB[ray]
		var a: Array = rows[0]
		var b: Array = rows[rows.size() - 1]
		var fit := fit_absorption(lab_to_linear_rgb(a[1], a[2], a[3]), float(a[0]), lab_to_linear_rgb(b[1], b[2], b[3]), float(b[0]))
		for i in 3:
			acc[i] += 0.5 * fit[i]
	return acc


## Sección eficaz del par Fe²⁺-Ti⁴⁺ sin polarizar (cm²) a nm: (2·E⊥c + E∥c)/3.
static func feti_cross_section(nm: float) -> float:
	var x := clampf((nm - FETI_FROM_NM) / FETI_STEP_NM, 0.0, float(FETI_PERP.size() - 1))
	var i := mini(int(floor(x)), FETI_PERP.size() - 2)
	var u := x - float(i)
	var p := float(FETI_PERP[i]) + (float(FETI_PERP[i + 1]) - float(FETI_PERP[i])) * u
	var q := float(FETI_PAR[i]) + (float(FETI_PAR[i + 1]) - float(FETI_PAR[i])) * u
	return (2.0 * p + q) / 3.0 * 1.0e-18


## Zafiro azul: absorción espectral (1/mm) a nm con ppma pares Fe²⁺-Ti⁴⁺.
static func sapphire_alpha_mm(nm: float, ppma: float) -> float:
	return feti_cross_section(nm) * ppma * PPMA_IONS_CM3 / 10.0


## Transmitancia en sRGB lineal de un espesor d_mm con una absorción espectral alpha_of(nm) (1/mm).
static func transmittance_rgb(alpha_of: Callable, d_mm: float, weights: Dictionary) -> PackedFloat64Array:
	var nm: PackedFloat64Array = weights.nm
	var t := PackedFloat64Array()
	for l: float in nm:
		t.append(V8.js_exp(-float(alpha_of.call(l)) * d_mm))
	return spectrum_rgb(t, weights)


## Absorción por canal de un material transparente: ajuste de Beer–Lambert entre 1 y 10 mm de su absorción espectral
## (zafiro y vidrio) o de los colores medidos (rubí); cero en lo incoloro.
static func channel_absorption(id: String, weights: Dictionary = {}) -> PackedFloat64Array:
	var w := weights if not weights.is_empty() else spectral_weights()
	match id:
		"rubi":
			return ruby_absorption()
		"zafiro":
			var ppma := float(SAPPHIRE_FETI_PPMA.value)
			var f := func(nm: float) -> float: return sapphire_alpha_mm(nm, ppma)
			return fit_absorption(transmittance_rgb(f, 1.0, w), 1.0, transmittance_rgb(f, 10.0, w), 10.0)
		"vidrio":
			var g := func(nm: float) -> float: return 4.0 * PI * table_at(K_SODA_LIME, nm) / (nm * 1.0e-6)
			return fit_absorption(transmittance_rgb(g, 1.0, w), 1.0, transmittance_rgb(g, 10.0, w), 10.0)
	return PackedFloat64Array([0.0, 0.0, 0.0])


## Filtro que no depende del espesor (un corte de absorción): la moissanita, sin la luz por debajo de 425 nm.
static func channel_tint(id: String, weights: Dictionary = {}) -> PackedFloat64Array:
	if id != "moissanita":
		return PackedFloat64Array([1.0, 1.0, 1.0])
	var w := weights if not weights.is_empty() else spectral_weights()
	var nm: PackedFloat64Array = w.nm
	var t := PackedFloat64Array()
	for l: float in nm:
		t.append(0.0 if l < MOISSANITE_CUTOFF_NM else 1.0)
	return spectrum_rgb(t, w)


# ════════ El aspecto de cada material ════════

static func _arr(v: Variant) -> Array:
	var out: Array = []
	if v is Array or v is PackedFloat64Array:
		for x: Variant in v:
			out.append(float(x))
	return out


## Lo que la escena necesita de un material (los números de DERIVED, que el test recalcula): { id, name, family, metallic,
## transparent, f0 [r, g, b] (sRGB lineal, recortado a 1), ior y ior_e (por canal), n_d, dispersion_bg, birefringence,
## abbe, critical_deg, absorption (1/mm), tint, albedo ([] si no tiene color difuso propio), scatter (lo que difunde el
## cuerpo de un polímero, 0-1; 0 en los demás), luster, optic, quality (la peor de sus datos) y sources ({ campo: fuente
## }) }. {} si el id no existe.
static func look(id: String) -> Dictionary:
	if not MATERIALS.has(id):
		return {}
	var m: Dictionary = MATERIALS[id]
	var d: Dictionary = DERIVED[id]
	var fam := String(m.family)
	var f0: Array = []
	for x: float in _arr(d.f0):
		f0.append(minf(x, 1.0))
	var tint: Array = []
	for x: float in _arr(d.get("tint", [1.0, 1.0, 1.0])):
		tint.append(minf(x, 1.0))
	var out := {
		"id": id, "name": String(m.name), "family": fam, "metallic": fam in ["metal", "mineral"],
		"transparent": fam in ["gema", "vidrio"], "f0": f0, "ior": _arr(d.get("ior", [])), "ior_e": _arr(d.get("ior_e", [])),
		"n_d": float(d.get("n_d", 0.0)), "dispersion_bg": float(d.get("dispersion_bg", 0.0)), "birefringence": float(d.get("birefringence", 0.0)),
		"abbe": float(d.get("abbe", 0.0)), "critical_deg": critical_angle_deg(float(d.n_d)) if d.has("n_d") else 0.0,
		"absorption": _arr(d.get("absorption", [0.0, 0.0, 0.0])), "tint": tint,
		"albedo": _arr(m.albedo.value) if m.has("albedo") else [], "luster": String(m.get("luster", "")), "optic": String(m.get("optic", "")),
		"scatter": float(m.scatter.value) if m.has("scatter") else 0.0,
	}
	var rank := { "primary": 0, "secondary": 1, "estimate": 2, "dibujo": 3 }
	var worst := "primary"
	var src := {}
	for key: String in ["nk", "reflectance", "index", "absorption", "albedo", "scatter"]:
		if m.has(key):
			var e: Dictionary = m[key]
			src[key] = String(e.source)
			if int(rank.get(String(e.quality), 0)) > int(rank[worst]):
				worst = String(e.quality)
	if id == "zafiro":
		src["concentration"] = String(SAPPHIRE_FETI_PPMA.source)
	out["quality"] = worst
	out["sources"] = src
	return out


## Todos los materiales con su aspecto, en el orden de MATERIAL_IDS.
static func looks() -> Array:
	var out: Array = []
	for id: String in MATERIAL_IDS:
		out.append(look(id))
	return out


## Los números de DERIVED recalculados desde los datos medidos (lo usa el test; tarda unos milisegundos).
static func derive(id: String, weights: Dictionary = {}) -> Dictionary:
	var w := weights if not weights.is_empty() else spectral_weights()
	var m: Dictionary = MATERIALS.get(id, {})
	if m.is_empty():
		return {}
	if m.has("nk") or m.has("reflectance"):
		return { "f0": metal_f0(id, w) }
	var ior := channel_indices(id, "o")
	var f0 := PackedFloat64Array()
	for n: float in ior:
		f0.append(normal_reflectance(n))
	return {
		"f0": f0, "ior": ior, "ior_e": channel_indices(id, "e"), "n_d": refractive_index(id, LAMBDA_D), "dispersion_bg": dispersion_bg(id),
		"birefringence": birefringence(id), "abbe": abbe(id), "absorption": channel_absorption(id, w), "tint": channel_tint(id, w),
	}


# ════════ Acabados ════════

## Fracción de la reflexión que sigue siendo especular con una rugosidad rms sigma_um a nm (Bennett & Porteus 1961).
static func specular_fraction(sigma_um: float, nm := 550.0) -> float:
	var x := 4.0 * PI * sigma_um * 1000.0 / nm
	return V8.js_exp(-x * x)


## Rugosidad rms (µm) que deja un abrasivo de grano grain_um (σ ≈ k·grano, GRAIN_SIGMA_RATIO).
static func sigma_of_grain(grain_um: float) -> float:
	return maxf(grain_um, 0.0) * float(GRAIN_SIGMA_RATIO.value)


## El «grano» de una herramienta de la cetrería (CareData.TOOLS): el tamaño de su abrasivo, o, en una lima de dientes, la
## separación entre dientes (10 000/dientes por cm, en µm). Lo segundo es una ESTIMACIÓN: cada diente deja un surco y la
## rugosidad se toma con la misma proporción que la de un grano (GRAIN_SIGMA_RATIO).
static func tool_grain_um(tool: Dictionary) -> float:
	if float(tool.get("grain_um", 0.0)) > 0.0:
		return float(tool.grain_um)
	if float(tool.get("teeth_cm", 0.0)) > 0.0:
		return 10000.0 / float(tool.teeth_cm)
	return 0.0


## Un acabado: { id, name, sigma_um, gloss (fracción especular a 550 nm), facets, scratch (0-1), chips, cracks, oxide,
## burn, pores, grain_um, quality, source }. grain_um: el grano de lo último que mordió (pulido, tallado o limado); si no
## se da, el de la tabla. Un id que no existe da «pulido».
static func finish(id: String, grain_um: Variant = null) -> Dictionary:
	var fid := id if FINISHES.has(id) else "pulido"
	var f: Dictionary = FINISHES[fid]
	var sigma := 0.0
	var quality := "estimate"
	var source := ""
	var grain: Variant = null
	if grain_um != null and float(grain_um) > 0.0 and fid in ["pulido", "tallado", "limado", "astillado"]:
		grain = float(grain_um)
	elif f.get("grain") != null:
		grain = float(f.grain.value)
	if grain != null:
		sigma = sigma_of_grain(float(grain))
		source = String(GRAIN_SIGMA_RATIO.source)
	elif f.has("sigma"):
		sigma = float(f.sigma.value)
		quality = String(f.sigma.quality)
		source = String(f.sigma.source)
	else:
		sigma = float(POLISH_SIGMA_UM.value)
		source = String(POLISH_SIGMA_UM.source)
	return {
		"id": fid, "name": String(FINISH_NAMES[fid]), "sigma_um": sigma, "gloss": specular_fraction(sigma), "grain_um": grain,
		"facets": bool(f.get("facets", false)), "scratch": float(f.get("scratch", 0.0)), "chips": int(f.get("chips", 0)),
		"cracks": int(f.get("cracks", 0)), "oxide": float(f.get("oxide", 0.0)), "burn": float(f.get("burn", 0.0)),
		"pores": float(f.get("pores", 0.0)), "quality": quality, "source": source + "; fracción especular: " + SRC_BENNETT,
	}


## Acabado por defecto de una garra reforjada sin historia (el banco, el coche en marcha): una pieza tallada y pulida;
## los metales, pulidos sin facetas (se cuelan o se mecanizan y se pulen). La queratina natural, su superficie de siempre.
static func default_finish(id: String) -> Dictionary:
	var f := finish("pulido")
	var fam := String((MATERIALS.get(id, {}) as Dictionary).get("family", "queratina"))
	if fam in ["metal", "mineral", "queratina", "ceramica", "polimero"]:
		f["facets"] = false
	return f


## Acabado de una garra que sale de la reforja: el de ClawForge.result_claw().finish (ForgeData.FINISH_IDS) con el grano
## de pulir si se ha pulido (polish_grain_um). Un polímero (el acrílico dental) se moldea y se lima: nunca lleva facetas.
static func finish_from_forge(forge_finish: String, polish_grain_um: Variant = null, material := "") -> Dictionary:
	var id := forge_finish if FINISHES.has(forge_finish) else "pulido"
	var f := finish(id, polish_grain_um if id == "pulido" else null)
	var fam := String((MATERIALS.get(material, {}) as Dictionary).get("family", "")) if material != "" else ""
	if (fam in ["metal", "mineral"] and id in ["pulido", "bruto"]) or fam == "polimero":
		f["facets"] = false
	return f


## Acabado de una garra reforjada en la cetrería: sin trabajar, el de la reforja (o el de por defecto); limada, el de la
## última herramienta que mordió (su grano, grain_um) con sus rayas, y mellada si la punta lo está. snapshot: el de
## ClawCare.
static func finish_from_care(snapshot: Dictionary, grain_um: Variant = null, base: Dictionary = {}) -> Dictionary:
	var material := String(snapshot.get("inlay", "none"))
	var f := base.duplicate(true) if not base.is_empty() else default_finish(material)
	var cl: Dictionary = snapshot.get("claw", {})
	var dmg: Dictionary = snapshot.get("damage", {})
	if float(cl.get("removedMm3", 0.0)) > 0.0 and grain_um != null and float(grain_um) > 0.0:
		var worked := finish("limado", grain_um)
		worked["facets"] = bool(f.get("facets", false))
		f = worked
	var chips := int(dmg.get("chips", 0))
	if chips > 0:
		f["chips"] = maxi(int(f.get("chips", 0)), mini(chips, 4))
		f["id"] = "mellado" if String(f.id) == "pulido" else String(f.id)
		f["name"] = String(FINISH_NAMES[String(f.id)])
	return f


# ════════ La reforja: qué superficie se ve ════════

## Profundidad de penetración de la luz (µm) en un medio absorbente de índice de absorción k a nm: δ = λ/(4πk) (la
## intensidad cae como e^(−z/δ)). Una capa de metal de 3δ ya es opaca.
static func skin_depth_um(k: float, nm := 550.0) -> float:
	return nm / 1000.0 / (4.0 * PI * k) if k > 0.0 else INF


## El id óptico de un material de la reforja con su variedad: el zafiro de Verneuil (alúmina pura) es incoloro.
static func optical_id(material: String, variety := "") -> String:
	if material == "zafiro" and variety.find("incoloro") >= 0:
		return "zafiro_incoloro"
	return material if MATERIALS.has(material) else "none"


## Qué se ve de una garra de la reforja (ClawForge.result_claw()): { material (id óptico de la superficie), finish (el
## de finish_from_forge), coat ({ material, thicknessUm, visible, clear, opaqueUm } o null) }. Una capa de metal
## (nitruro de titanio, cromo) más gruesa que 3δ (opaqueUm) tapa lo de debajo; una capa porosa (la alúmina proyectada con
## plasma), también; el diamante CVD y el esmalte forman su propia superficie; una capa densa de alúmina deja ver la funda
## (la de 2 µm añade su brillo: clear) y la de capas atómicas, de 33 nm, no se ve.
static func forge_surface(result_claw: Dictionary, variety := "", polish_grain_um: Variant = null) -> Dictionary:
	var mid := optical_id(String(result_claw.get("inlay", "none")), variety)
	var fin := String(result_claw.get("finish", ""))
	var out := { "material": mid, "finish": finish_from_forge(fin, polish_grain_um, mid), "coat": null }
	var coat: Variant = result_claw.get("coating")
	if not (coat is Dictionary):
		return out
	var c: Dictionary = coat
	var cm := String(c.get("material", ""))
	var th := float(c.get("thicknessUm", 0.0))
	var view := { "material": cm, "thicknessUm": th, "visible": false, "clear": false, "opaqueUm": 0.0 }
	if cm in ["tin", "cromo"]:
		var rows: Array = MATERIALS[cm].nk.value
		view["opaqueUm"] = 3.0 * skin_depth_um(table_at(rows, 0.55, 2))
		view["visible"] = th >= float(view.opaqueUm)
	elif cm == "alumina":
		view["visible"] = float(c.get("porosity", 0.0)) > 0.0
		view["clear"] = not bool(view.visible) and th >= 1.0
	elif cm in ["diamante", "vidrio"]:
		view["visible"] = th > 0.0
	elif MATERIALS.has(cm):
		view["visible"] = true
	if bool(view.visible):
		out["material"] = cm
	out["coat"] = view
	return out
