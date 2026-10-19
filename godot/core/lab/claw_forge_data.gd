## Tribología biológica · reforja experimental de garras: datos con fuente (modelo 2.0, unidad 5d). Sin estado.
##
## Qué hay aquí (la física está en claw_forge.gd; la guía completa, en docs/fisica/reforja.md):
##   - MATERIALS: lo que hace el calor a cada material de la garra reforjada (los de Data.INLAYS y la alúmina sinterizada,
##     nueva de la 2.0): fusión, reblandecimiento, oxidación en el aire, grafitización, inversión del cuarzo, dilatación y
##     conductividad (para el choque térmico) y cómo se fabrica de verdad.
##   - NEW_MATERIALS: la alúmina sinterizada (no está en Data.INLAYS; va en el catálogo 2.0, no cambia el oráculo 1.x).
##   - PROSTHESIS: el acrílico de la prótesis de verdad de una garra rota (unidad 5j): se pega y se lima en la cetrería; no va
##     al banco.
##   - FURNACE y CONTROLS: el horno-fundidor del taller (FICCIÓN: junta en una máquina lo que en la industria hacen
##     varias) y sus mandos, cada uno con su unidad, su rango, qué hace y por qué importa.
##   - POWDERS y RECIPES: los polvos y las recetas por material objetivo (zafiro, rubí, metal duro, alúmina, acero, oro,
##     titanio, vidrio colado y diamante HPHT y CVD), con su margen bueno y lo que sale si te pasas o te quedas corto.
##   - COOLING: los medios de enfriamiento (coeficiente de convección) para el choque térmico.
##   - ABRASIVES: muelas y pastas para tallar y pulir (las durezas del taller).
##   - BARRIERS: barreras térmicas sobre la carne viva (silicona, manta de aerogel, gel de agua de joyero).
##   - COATINGS: recubrimientos (ALD, PVD, proyección por plasma, CVD de diamante, esmalte vítreo y el fundido encima, que
##     es ficción).
##   - ADHESIVES: cianoacrilato, epoxi y metacrilato, con su resistencia al cortante y su holgura.
##   - SHEATH: la funda por defecto (largo que cubre y espesor de pared).
## Cada dato es { value, source, quality } (y min/max si tiene banda); quality: "primary", "secondary", "estimate" (sin
## medición: el caso medido más parecido y la suposición escrita), "ficcion" (lo que no se hace de verdad; su source dice
## lo que pasaría) o "dibujo" (solo para pintar).
## Unidades: temperatura °C · tiempo s · presión MPa · longitud mm (espesores de capa en µm) · dureza HV · módulo GPa ·
## resistencia MPa · tenacidad MPa·√m · dilatación 1/K · conductividad W/(m·K) · densidad kg/m³ · calor específico
## J/(kg·K) · coeficiente de convección W/(m²·K).
## Uso: const ForgeData = preload("res://core/lab/claw_forge_data.gd").
extends RefCounted

const Data = preload("res://core/lab/data.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const ClawFracture = preload("res://core/lab/claw_fracture.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")

# ════════ Fuentes ════════
const SRC_ITS90 := "Escala Internacional de Temperatura de 1990 (ITS-90): punto de congelación del oro, 1337,33 K = 1064,18 °C (punto fijo de definición)"
const SRC_CRC := "Haynes WM (ed.), CRC Handbook of Chemistry and Physics, 95.ª ed. (2014): punto de fusión del titanio, 1668 °C; dilatación del oro, 14,2·10⁻⁶ 1/K, y conductividad, 317 W/(m·K), a 25 °C"
const SRC_AK304 := "AK Steel, 304/304L Stainless Steel, Product Data Bulletin: intervalo de fusión 1399-1454 °C; sin cascarilla apreciable hasta ~899 °C en servicio continuo (816 °C intermitente); recocido de 1038-1121 °C con enfriamiento rápido; dilatación 17,3·10⁻⁶ 1/K (0-100 °C), conductividad 16,2 W/(m·K) y calor específico 0,12 BTU/(lb·°F) = 500 J/(kg·K) (0-100 °C)"
const SRC_ALPHA_CASE := "La capa alfa: el titanio caliente al aire o en un molde de óxidos coge oxígeno y forma una capa superficial dura y frágil con microgrietas; se evita fundiendo y colando en vacío profundo o en argón (Chan KS, Koike M, Johnson BW, Okabe T (2008). Modeling of alpha-case formation and its effects on the mechanical properties of titanium alloy castings. Metall. Mater. Trans. A 39:171-180, doi:10.1007/s11661-007-9406-0, en el colado dental del titanio)"
const SRC_GC_GUIDE := "General Carbide, The Designer's Guide to Tungsten Carbide: el metal duro se sinteriza en un horno y encoge hasta un 20 %; «as temperatures approach 1000 °F (538 °C), oxidation will occur»"
const SRC_GOODFELLOW_WC := "Goodfellow, carburo de tungsteno con cobalto WC 94/Co 6 (recogido por AZoM): dilatación 4,6-5,0·10⁻⁶ 1/K (20-1000 °C), conductividad 60-80 W/(m·K) a 20 °C, densidad 14,95 g/cm³"
const SRC_WC_SINTER := "Sinterizado en fase líquida del metal duro WC-Co entre 1350 y 1500 °C, en vacío (p. ej., Fernandes CM, Senos AMR (2011), Cemented carbide phase diagrams: a review, Int. J. Refract. Met. Hard Mater. 29:405-418; y los estudios de contracción de WC-Co sinterizados a 1350-1450 °C)"
const SRC_ABRISA := "Abrisa Technologies, Soda-Lime Float Glass, ficha técnica: punto de reblandecimiento 726 °C, de recocido 546 °C y de deformación 514 °C"
const SRC_EN572 := "EN 572-1 (vidrio sodocálcico): dilatación 9·10⁻⁶ 1/K, conductividad 1 W/(m·K) y calor específico 720 J/(kg·K)"
const SRC_BULLSEYE := "Bullseye Glass Co., Tip Sheet 8 «Basic lost wax kilncasting»: molde de yeso y harina de sílice al 50 %; mantener a 830 °C (1525 °F) 3 h; por encima de 843 °C el molde puede fallar; recocer a 482 °C 6 h y bajar a 6,7-12 °C/h"
const SRC_QUARTZ_INV := "La inversión α-β del cuarzo a 573 °C, con una dilatación lineal del 0,45 %, microfisura rocas y cerámicas que la atraviesan (Johnson SE et al. (2021), The quartz α↔β phase transition: does it drive damage and reaction in continental crust?, Earth Planet. Sci. Lett. 553:116622); en cerámica, enfriar deprisa por esa temperatura agrieta la pieza («dunting»)"
const SRC_TYDEX_QUARTZ := "Tydex, Synthetic Crystal Quartz, ficha técnica: dilatación 7,1·10⁻⁶ 1/K paralela al eje Z y 13,2·10⁻⁶ perpendicular (0-25 °C); conductividad 10,7 W/(m·K) paralela y 6,2 perpendicular"
const SRC_CORNING_7980 := "Corning HPFS 7980 (sílice fundida), ficha técnica: punto de reblandecimiento 1585 °C, de recocido 1042 °C"
const SRC_NASSAU_CZ := "Nassau K (1981). Cubic zirconia: an update. Gems & Gemology 17:9-19, doi:10.5741/GEMS.17.1.9: el ZrO₂ puro funde a unos 2750 °C; se estabiliza con CaO, MgO o Y₂O₃ y se cultiva por fusión en cráneo con radiofrecuencia"
const SRC_YSZ := "Circonia estabilizada con itria: dilatación del orden de 9-11·10⁻⁶ 1/K y conductividad de la cerámica densa de 2,5-3,0 W/(m·K) (recopilaciones de propiedades de la YSZ; la dilatación baja al subir la itria: Hayashi H, Saitou T, Maruyama N, Inaba H, Kawamura K, Mori M (2005), Solid State Ionics 176:613-619, doi:10.1016/j.ssi.2004.08.021)"
const SRC_SG_SAPPHIRE := "Saint-Gobain Crystals, Sapphire Products (ficha técnica, 2016-2018): funde a 2053 °C; dilatación 8,8·10⁻⁶ 1/K paralela al eje c y 7,9·10⁻⁶ perpendicular (25-1000 °C); conductividad 0,4 W/(cm·K) = 40 W/(m·K) a 25 °C; calor específico 0,181 cal/(g·K) = 757 J/(kg·K)"
const SRC_HEXOLOY := "Saint-Gobain, Hexoloy SA (carburo de silicio sinterizado), ficha técnica: dilatación 4,02·10⁻⁶ 1/K (de 20 a 700 °C), conductividad 125,6 W/(m·K), calor específico medio 0,67 J/(g·K) a temperatura ambiente, densidad 3,10 g/cm³"
const SRC_SIC_PVT := "Crecimiento de monocristales de SiC por transporte físico de vapor (sublimación) a 2300-2500 °C en argón (JXT Semi Technology, «Physical vapor transport (PVT) growth process of silicon carbide single crystals»); la moissanita de joyería sale de ese proceso (Nassau K et al. 1997, Gems & Gemology 33:260-275)"
const SRC_SIC_DISSOC := "GRAYSTAR, TDS Black Silicon Carbide (2009): el SiC no funde, se disocia hacia los 2700 °C"
const SRC_KAPP := "Brazda P. (KAPP Technologies), «Hard choices: diamond or CBN?», Gear Solutions, 1-2-2006: el diamante «se oxida por encima de 600 °C» (el mismo dato de la tabla de abrasivos del taller)"
const SRC_DIAMOND_OX := "El diamante se oxida al aire desde ~600 °C (KAPP 2006) y hacia 700-800 °C se le forman hoyos de grafito que se queman a CO y CO₂ («High temperature graphitization of diamond during heat treatment in air and in a vacuum» (2024), Glass Phys. Chem., doi:10.1134/S1087659624600315)"
const SRC_DIAMOND_VACUUM := "A baja presión la superficie del diamante se grafitiza ya por debajo de ~1700 °C, por el oxígeno que queda (Khmelnitsky RA, Gippius AA (2014). Transformation of diamond to graphite under heat treatment at low pressure. Phase Transitions 87(2), doi:10.1080/01411594.2013.807429)"
const SRC_BALMER := "Balmer RS et al. (2009). Chemical vapour deposition synthetic diamond: materials, technology and applications. J. Phys.: Condens. Matter 21:364221, doi:10.1088/0953-8984/21/36/364221: el diamante natural se forma a 70-80 kbar y 1400-1600 °C; la síntesis HPHT necesita un metal disolvente (Fe, Co o Ni) para ser práctica (Bundy 1963); la CVD crece con 0,1-10 % de CH₄ en H₂ y el sustrato a 700-1300 °C (Si, Mo, W, Ti o diamante: poca solubilidad del carbono) y recubre piezas con forma; tabla 7: diamante policristalino, 1000-2200 W/(m·K), 0,9·10⁻⁶ 1/K y 1100 GPa"
const SRC_KENNEDY := "Kennedy CS, Kennedy GC (1976). The equilibrium boundary between graphite and diamond. J. Geophys. Res. 81:2467-2470, doi:10.1029/JB081i014p02467: P (kbar) = 19,4 + T(°C)/40, medida de 1100 a 1625 °C"
const SRC_SUMIYA := "Sumiya H, Toda N, Satoh S (2002). Growth rate of high-quality large diamond crystals. J. Cryst. Growth 237-239:1281-1285: método del gradiente de temperatura a 5,5 GPa y 1340-1350 °C con disolvente de Fe-Co con Ti; cristales IIa de hasta 12 mm a 6-8 mg/h"
const SRC_YAN := "Yan C-S, Vohra YK, Mao H-K, Hemley RJ (2002). Very high growth rate chemical vapor deposition of single-crystal diamond. PNAS 99:12523-12525, doi:10.1073/pnas.152464799: 50-150 µm/h con plasma de microondas"
const SRC_COBLE := "Coble RL (1962), patente US 3.026.210, Transparent alumina and method of preparation: alúmina con 1/4-1/2 % en peso de MgO, precocida al aire a 1000-1200 °C al menos 1 h, sinterizada a no menos de ~1700 °C (mejor 1800-1950 °C) en vacío o en hidrógeno; a 1700 °C pide 24 h y a 1900 °C, 6-8 h"
const SRC_COORSTEK := "CoorsTek AD-995 (alúmina del 99,5 %), ficha técnica: densidad 3,90 g/cm³, Knoop (1 kg) 14,1 GPa, módulo 370 GPa, flexión 379 MPa, tenacidad 4-5 MPa·√m, dilatación 8,2·10⁻⁶ 1/K (25-1000 °C), conductividad 30 W/(m·K), calor específico 880 J/(kg·K), Poisson 0,22"
const SRC_VERNEUIL := "Método de Verneuil (fusión a la llama): polvo de Al₂O₃ que cae por una llama de oxígeno e hidrógeno de al menos 2000 °C (~2200 °C) y crece una bola sobre una semilla que baja a ~10 mm/h; bolas de 13-20 mm de diámetro y hasta 100 mm de largo; al enfriar se parte a lo largo para aliviar la tensión interna (Scheel HJ (2000), Historical aspects of crystal growth technology, J. Cryst. Growth 211:1-12; The Gemology Project, «Flame fusion»; Nassau K (1980), Gems Made by Man)"
const SRC_RUBY_CR := "Rubí = corindón con cromo: el de los láseres lleva 0,03 o 0,05 % en peso de Cr₂O₃ (Roditi, Ruby laser rods); la mezcla de Verneuil para joyería, en torno al 5 % (How Products Are Made, «Synthetic ruby»). La dureza no cambia: es corindón"
const SRC_GANOKSIN := "Ganoksin, «Cracks in jewelry manufacturing» y «Colored karat golds for investment casting»: colar a 30-100 °C por encima del líquido según el tamaño (+100 °C en piezas pequeñas y finas); demasiado caliente da rechupes, poros de gas y grano grueso"
const SRC_GYPSUM := "El revestimiento de yeso (sulfato cálcico) no se calienta por encima de ~816 °C (1500 °F): se descompone en óxidos de azufre que manchan el metal y dan poros (Ganoksin, «Wax casting burnout cycles»); para colar acero o titanio hace falta un revestimiento de fosfato o una cáscara cerámica"
const SRC_STEEL_POUR := "Colada del inoxidable 304 (CF8): 1500-1550 °C, con 100-150 °C de sobrecalentamiento; demasiado caliente absorbe gas, reacciona con el molde y da grano grueso (CastingQuality, «Stainless steel CF8 (SS304)»; guías de fundición a la cera perdida de acero)"
const SRC_TI_CAST := "El titanio se funde con arco en argón o en vacío y se cuela en moldes de grafito o de óxidos especiales: el aire y los moldes de sílice lo contaminan (capa alfa). Así se cuelan las prótesis dentales de titanio (" + SRC_ALPHA_CASE + ")"
const SRC_ENAMEL := "Esmalte vítreo: vidrio en polvo fundido sobre metal a 750-850 °C (Andrews AI (1961), Porcelain Enamels, Garrard Press; Thomaz, «Enamel on metal: general information»)"
const SRC_GRONER := "Groner MD, Fabreguette FH, Elam JW, George SM (2004). Low-temperature Al₂O₃ atomic layer deposition. Chem. Mater. 16:639-645: alúmina por capas atómicas (trimetilaluminio y agua) desde 33 °C, 332 Å en 300 ciclos a 33 °C (1,107 Å por ciclo), en un reactor a baja presión"
const SRC_BALINIT_A := "Oerlikon Balzers, BALINIT A (TiN por PVD): dureza 30 ± 3 GPa (H_IT), 1-4 µm, temperatura de recubrimiento 250/400 °C, en cámara de vacío"
const SRC_ISO14577 := "ISO 14577-1, anexo: HV ≈ 0,0945·H_IT (MPa); ISO 14577-4 (regla de Bückle): para medir la dureza de una capa, la huella no debe pasar del 10 % de su espesor; más hondo manda el sustrato"
const SRC_APS := "Alúmina por proyección de plasma atmosférico: capas de 200-500 µm, porosidad del 2-20 % (~4 % en alúmina pura), microdureza ~900-1000 HV; con el sustrato más caliente (hasta 500 °C) sale más dura y menos porosa («Effect of the thickness on properties of Al₂O₃ coatings deposited by plasma spraying», Materials Characterization, 2010; «Effect of the substrate temperature on properties of plasma sprayed Al₂O₃ coatings», Materials & Design, 2004)"
const SRC_SCHNEIDER := "Schneider JM, Sproul WD, Chia RWJ, Wong MS, Matthews A (1997). Very-high-rate reactive sputtering of alumina hard coatings. Surf. Coat. Technol. 96:262-266: alúmina por pulverización catódica reactiva con el sustrato a 250 °C o menos; capas densas y transparentes de 12 GPa de dureza y 140 GPa de módulo"
const SRC_AMORPHOUS_AL2O3 := "«Tribological and optical properties of crystalline and amorphous alumina thin films grown by low-temperature reactive magnetron sputter-deposition», Surface and Coatings Technology (2001): la alúmina amorfa de las capas frías, 10-12 GPa; la cristalina, ~25 GPa"
const SRC_MORGAN := "Morgan Technical Ceramics, «Thermal shock resistance» (método de Hasselman: probetas de flexión templadas en un fluido): salto que aguanta la alúmina, 170-300 °C; carburo de silicio, 400 °C; circonia, 400-500 °C"
const SRC_GROSSMANN := "Severidad del temple de Grossmann sin agitar (H, en pulgadas⁻¹): aire 0,02; aceite 0,25-0,30; agua 0,9-1,0; salmuera 2 (tabla recogida en ScienceDirect Topics, «Quench severity», y en las guías de temple del acero)"
const SRC_HARD_CHROME := "Cromo duro galvánico: baño de ácido crómico a 50-65 °C (Northeast Waste Management Officials' Association, 2003, recogido en Wikipedia, «Chrome plating»), capas normales de 20-40 µm (U.S. Chrome Corporation), ~25 µm por hora, 65-69 HRC; 750-1050 HV (ScienceDirect Topics, «Hard chromium»). El cromo hexavalente del baño es cancerígeno"
const SRC_ELECTROFORMING := "Gateros Plating, «Electroforming tutorial»: un objeto que no conduce se pinta antes con pintura conductora de grafito, cobre o plata (sobre la de plata el cobre empieza a depositarse en 2-5 min; sobre las otras, en 15-60)"
const SRC_BRAZING := "SAE AMS 4763: aleación de soldadura fuerte de plata 56Ag-22Cu-17Zn-5Sn, sólido-líquido 618-652 °C; así se sueldan las plaquitas de metal duro a los mangos de acero"
const SRC_INCROPERA := "Incropera FP, DeWitt DP, Bergman TL, Lavine AS (2007). Fundamentals of Heat and Mass Transfer, 6.ª ed., tabla 1.1: convección natural en gases 2-25 W/(m²·K), forzada en líquidos 100-20 000, con ebullición 2500-100 000"
const SRC_KINGERY := "Kingery WD (1955). Factors affecting thermal stress resistance of ceramic materials. J. Am. Ceram. Soc. 38:3-15: salto de temperatura que aguanta una pieza frágil, ΔT_c = σ_f·(1 − ν)/(E·α)"
const SRC_MANSON := "Manson SS (1966). Thermal Stress and Low-Cycle Fatigue. McGraw-Hill; recogido en Lu TJ, Fleck NA (1998), The thermal shock resistance of solids, Acta Mater. 46:4755-4768: con un enfriamiento finito, la tensión es ψ veces la del salto brusco, 1/ψ = 1,5 + 3,25/β − 0,5·e^(−16/β), β = h·a/k"
const SRC_CHAI_LAWN := "Chai H, Lawn BR (2007). A universal relation for edge chipping from sharp contacts in brittle materials. Acta Mater. 55:2555-2561: una punta a la distancia d del borde lo desconcha con F = β·K_c·d^(3/2), β ≈ 9"
const SRC_BIFANO := "Bifano TG, Dow TA, Scattergood RO (1991). Ductile-regime grinding: a new technology for machining brittle materials. J. Eng. Ind. 113:184-189: por debajo de la hondura crítica d_c = 0,15·(E/H)·(K_c/H)² el grano arranca sin grietas"
const SRC_LOCTITE_401 := "Henkel, LOCTITE 401 (cianoacrilato): cortante 20 N/mm² en acero chorreado y 12,4 en aluminio decapado (ISO 4587); tras 1000 h en agua conserva el 75 % (TDS de 2012); trabaja mejor con holguras de 0,05 mm (TDS de 1996) y llena hasta 0,15 mm (página del producto)"
const SRC_LOCTITE_GUIDE := "Henkel, The LOCTITE Design Guide for Bonding Metals, vol. 6, tabla 7 (aluminio rugoso, 68 rms): epoxi E-20HP, 2160 psi = 14,9 MPa; acrílico de dos componentes H8000, 2820 psi = 19,4 MPa. Henkel, Structural Adhesives and NVH Selector Guide: holgura ideal y máxima, epoxi 0,004-0,006 in y 0,125 in (0,10-0,15 mm y 3,2 mm); acrílico de dos componentes 0,010-0,040 in y 0,5 in (0,25-1,0 mm y 12,7 mm)"
const SRC_FERREIRA := "Ferreira CMC, Simões BD, Marques EAS, Carbas RJC, da Silva LFM (2024). Exploring adhesive performance in horseshoe bonding through advanced mechanical and numerical analysis. Biomimetics 10:2, doi:10.3390/biomimetics10010002: dos adhesivos acrílicos de herraduras pegadas; en las uniones acero-casco «la rotura ocurre siempre en el casco», no en el adhesivo"
const SRC_SHINETSU := "Shin-Etsu, Characteristic properties of silicone rubber compounds (catálogo): densidad 1,1-1,2, aguanta en servicio hasta ~200 °C; caucho de silicona sin carga, ~0,2 W/(m·K) y 1050-1300 J/(kg·K) (AZoM, «Silicone rubber»)"
const SRC_PYROGEL := "Aspen Aerogels, Pyrogel XTE, ficha técnica: densidad 0,20 g/cm³, conductividad 14 mW/(m·K) a 0 °C, 24 a 300 °C y 62 a 600 °C, hasta 650 °C"
const SRC_WATER := "Agua: conductividad 0,6 W/(m·K), calor específico 4180 J/(kg·K), calor de vaporización 2257 kJ/kg a 100 °C (Incropera et al. 2007, tablas A.6); los geles de joyero (Kool Jool, Thermo-Gel) son agua gelificada que se pone sobre las piedras al soldar y se lleva el calor al evaporarse"
const SRC_IRON_REACTIVE := "el diamante «reacciona con los metales del grupo del hierro ya por encima de 700 °C» (KAPP 2006; Komanduri M, Shaw MC (1975), Nature 255:211, el carbono se difunde en el hierro) y el carburo de silicio no sirve para el acero «por su reactividad química con él a la temperatura del contacto» (patente US 4.505.720): contra el acero se gastan deprisa; el corindón y el CBN, no"
const SRC_ABRASIVES := "durezas de los granos del taller (corindón 2000 HV, carburo de silicio 2800, CBN 6322 y diamante 10 000; fichas de GNPGraystar, GRAYSTAR, Solozhenko et al. 2019 y KAPP) y la lima de acero de 60-62 HRC (~700 HV, FWT GmbH y DIN EN ISO 18265)"
const SRC_DMT := "DMT Diamond Sharpeners, FAQ: diamante de 60, 45, 25 y 9 µm (mallas 220, 325, 600 y 1200)"
const SRC_FILE_TEST := "HolzWerken (18-9-2024), «Stahlhärte bestimmen»: una lima solo deja marca en lo que es más blando que ella (juego de limas de prueba de 40 a 65 HRC)"
const SRC_LAPIDARY := "Práctica de lapidario y de rectificado de cerámicas: se talla siempre con agua (las muelas de diamante se queman por encima de 600 °C al aire, KAPP; el vidrio y el cuarzo, malos conductores, se agrietan con el calor del roce en seco). Sin cifra medida para la pieza: regla del modelo"
# 5j · el calor específico de cada material (para el calor de limar el bloque en la cetrería) y la prótesis de acrílico
const SRC_CRC_CP := "Haynes WM (ed.), CRC Handbook of Chemistry and Physics, 95.ª ed. (2014), calor específico de los elementos a 25 °C: oro, 0,129 J/(g·K)"
const SRC_ASM_TI2 := "ASM Aerospace Specification Metals, ficha del titanio de grado 2 recocido (UNS R50400; datos de Allvac): dilatación 8,6 µm/(m·°C) de 20 a 93 °C, calor específico 0,523 J/(g·°C), conductividad 16,4 W/(m·K), densidad 4,51 g/cm³"
const SRC_HYPERION_WC := "Hyperion Materials & Technologies, «Thermal properties» del metal duro: el calor específico de los WC-Co sin otros carburos, 150-350 J/(kg·°C) a temperatura ambiente (la mitad que el del acero); 200-480 J/(kg·K) a 25 °C en la ficha de Goodfellow del WC 94/Co 6 (AZoM)"
const SRC_NIST_DIAMOND := "NIST Chemistry WebBook (SRD 69), diamante: capacidad calorífica 6,117 J/(mol·K) a 298,15 K (Victor 1962): 509 J/(kg·K)"
const SRC_JANAF := "Chase MW (1998). NIST-JANAF Thermochemical Tables, 4.ª ed. J. Phys. Chem. Ref. Data, monografía 9 (en el NIST Chemistry WebBook, con su ecuación de Shomate): el cuarzo α, 44,6 J/(mol·K) a 298,15 K (742 J/(kg·K)); el ZrO₂ monoclínico, 56,1 J/(mol·K) (455 J/(kg·K))"
const SRC_ZAFAR_PMMA := "Zafar MS (2020). Prosthodontic applications of polymethyl methacrylate (PMMA): an update. Polymers 12:2299. doi:10.3390/polym12102299, tabla 4 (el PMMA termopolimerizado de las prótesis dentales: Knoop 18-20 KHN y Vickers ~20, módulo 2,6 GPa, densidad 1,18 g/cm³, dilatación 81·10⁻⁶ 1/°C, transición vítrea 125 °C; la polimerización del PMMA desprende mucho calor)"
const SRC_ALQUTAIBI := "Alqutaibi AY et al. (2023). Polymeric denture base materials: a review. Polymers 15:3258. doi:10.3390/polym15153258 (recoge a Barbosa DB, Compagnoni MA, Souza RF, Pero AC, J. Prosthodont.: el PMMA autopolimerizable, 84,40 ± 1,68 MPa a flexión y 1,63 ± 0,1 MPa·√m de tenacidad; el termopolimerizado, 92,84 MPa y 2,06 MPa·√m; el monómero residual, 3-5 % en los autopolimerizables y 0,2-0,5 % en los termopolimerizados)"
const SRC_ISO20795 := "ISO 20795-1:2013, Odontología, polímeros de base, parte 1 (bases de prótesis dentales): los autopolimerizables (tipo 2), al menos 60 MPa de resistencia a flexión y 1500 MPa de módulo"
const SRC_ASSAEL_PMMA := "Assael MJ, Botsios S, Gialou K, Metaxa IN (2005). Thermal conductivity of polymethyl methacrylate (PMMA) and borosilicate crown glass BK7. Int. J. Thermophys. 26:1595-1605. doi:10.1007/s10765-005-8106-5 (el PMMA como material de referencia: 0,190 W/(m·K) a 298 K)"
const SRC_NIST_PMMA := "NIST Chemistry WebBook (SRD 69), poli(metacrilato de metilo): capacidad calorífica del sólido, 130,8 J/(mol·K) a 298,15 K (Melia 1962), por mol de la unidad que se repite (100,12 g/mol): 1306 J/(kg·K)"
const SRC_SAMOUR_REPAIR := CareData.SRC_SAMOUR + ", pp. 927-928: el pico se rellena con «methacrylate glue and baking soda or commercially available beak repair kits» y, como crece, «continuous repairs will be required every 8 to 12 weeks»; las garras se recortan y se les da forma con una cuchilla y limas, y la sangre se para con un cauterio o un lápiz de nitrato de plata"
const SRC_MATTA := "Matta T, Eshar D, Nau MR (2022). Surgical repair of a rostral maxillary beak fracture using an improvised metal implant scaffolding and dental acrylic prosthesis in a pet double yellow-headed Amazon parrot (Amazona ochrocephala oratrix). Israel J. Vet. Med. 77(4):213-221: el acrílico dental se usa en el pico porque fragua en frío, sin el calor que dañaría el tejido; ya fraguado, se le dio forma con una amoladora (Dremel); una prótesis de acrílico sin anclar se cae al renovarse la queratina, y esta se cayó sola a los seis meses, con el pico ya crecido"

## Coeficiente de Poisson común del motor (Contact.CONTACT.nu): el del choque térmico.
const NU := 0.3

# ════════ Materiales: el calor y cómo se hacen ════════
## Por id de Data.INLAYS (más «alumina»). Campos (null si no aplica o no hay dato):
##   family: «metal», «metal_duro», «vidrio», «cristal» (monocristal), «ceramica» o «polimero» (el acrílico de la prótesis);
##   melt_c: funde (o se disocia) · soften_c: se reblandece (vidrios) · air_c: se degrada al aire por encima (oxidación,
##   cascarilla) y air_what, qué pasa · inert_c: se degrada aun sin aire (el diamante se grafitiza) · inversion_c: cambio de
##   fase que agrieta al cruzarlo deprisa (cuarzo) · alpha (1/K) y k (W/(m·K)): para el choque térmico · cp (J/(kg·K)): con
##   k y la densidad, el calor de limar un bloque de ese material en la cetrería (unidad 5j);
##   route: cómo se hace de verdad («colar», «sinterizar», «cristal», «natural», «frio») y route_text.
const MATERIALS := {
	"oro": {
		"family": "metal",
		"melt_c": { "value": 1064.18, "quality": "primary", "source": SRC_ITS90 },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 14.2e-6, "quality": "secondary", "source": SRC_CRC },
		"k": { "value": 317.0, "quality": "secondary", "source": SRC_CRC },
		"cp": { "value": 129.0, "quality": "secondary", "source": SRC_CRC_CP },
		"route": "colar", "route_text": "Se funde en un crisol a ~1100 °C y se cuela a la cera perdida: un horno de joyero basta. No se oxida.",
	},
	"acero": {
		"family": "metal", "ferrous": true,
		"melt_c": { "value": 1454.0, "min": 1399.0, "max": 1454.0, "quality": "secondary", "source": SRC_AK304 },
		"soften_c": null,
		"air_c": { "value": 899.0, "min": 816.0, "max": 899.0, "quality": "secondary", "source": SRC_AK304 },
		"air_what": "cascarilla: se oxida la superficie", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 17.3e-6, "quality": "secondary", "source": SRC_AK304 },
		"k": { "value": 16.2, "quality": "secondary", "source": SRC_AK304 },
		"cp": { "value": 500.0, "quality": "secondary", "source": SRC_AK304 },
		"route": "colar", "route_text": "Funde a 1400-1454 °C: un horno de joyero no llega; hace falta un horno de inducción y un molde cerámico.",
	},
	"titanio": {
		"family": "metal",
		"melt_c": { "value": 1668.0, "quality": "secondary", "source": SRC_CRC },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"air_melt": "capa alfa: fundido al aire coge oxígeno y la superficie queda dura, frágil y con microgrietas",
		"air_melt_source": SRC_ALPHA_CASE,
		"alpha": { "value": 8.6e-6, "quality": "secondary", "source": SRC_ASM_TI2 + " (un metal dúctil no se agrieta por choque térmico)" },
		"k": { "value": 16.4, "quality": "secondary", "source": SRC_ASM_TI2 },
		"cp": { "value": 523.0, "quality": "secondary", "source": SRC_ASM_TI2 },
		"route": "colar", "route_text": "Funde a 1668 °C y al aire se contamina: se funde con arco en argón o en vacío y se cuela en moldes especiales.",
	},
	"tungsteno": {
		"family": "metal_duro",
		"melt_c": null, "soften_c": null,
		"air_c": { "value": 538.0, "quality": "secondary", "source": SRC_GC_GUIDE },
		"air_what": "se oxida: polvo y escamas de óxido en la superficie", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 4.8e-6, "min": 4.6e-6, "max": 5.0e-6, "quality": "secondary", "source": SRC_GOODFELLOW_WC },
		"k": { "value": 70.0, "min": 60.0, "max": 80.0, "quality": "secondary", "source": SRC_GOODFELLOW_WC },
		"cp": { "value": 250.0, "min": 150.0, "max": 480.0, "quality": "secondary", "source": SRC_HYPERION_WC + ". Se toma 250, dentro de las dos bandas" },
		"route": "sinterizar", "route_text": "No se funde: se prensa polvo de WC con un 5,5 % de cobalto y se sinteriza a 1350-1500 °C en vacío (encoge ~20 %).",
	},
	"vidrio": {
		"family": "vidrio",
		"melt_c": null,
		"soften_c": { "value": 726.0, "quality": "secondary", "source": SRC_ABRISA },
		"anneal_c": { "value": 546.0, "quality": "secondary", "source": SRC_ABRISA },
		"air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 9.0e-6, "quality": "secondary", "source": SRC_EN572 },
		"k": { "value": 1.0, "quality": "secondary", "source": SRC_EN572 },
		"cp": { "value": 720.0, "quality": "secondary", "source": SRC_EN572 },
		"route": "colar", "route_text": "Se reblandece desde ~726 °C: se cuela en un molde en el horno (a ~830 °C) y se recuece despacio.",
	},
	"swarovski": {
		"family": "vidrio",
		"melt_c": null,
		"soften_c": { "value": 726.0, "quality": "estimate", "source": "caso medido más parecido: el vidrio sodocálcico (" + SRC_ABRISA + "); el cristal al plomo se reblandece algo antes" },
		"anneal_c": { "value": 546.0, "quality": "estimate", "source": "caso medido más parecido: el vidrio sodocálcico (" + SRC_ABRISA + ")" },
		"air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 9.0e-6, "quality": "estimate", "source": "caso medido más parecido: el vidrio sodocálcico (" + SRC_EN572 + ")" },
		"k": { "value": 1.0, "quality": "estimate", "source": "caso medido más parecido: el vidrio sodocálcico (" + SRC_EN572 + ")" },
		"cp": { "value": 720.0, "quality": "estimate", "source": "caso medido más parecido: el vidrio sodocálcico (" + SRC_EN572 + "); el cristal al plomo, más pesado, tiene algo menos" },
		"route": "natural", "route_text": "Se compra tallado: es cristal al plomo de fábrica. En el horno se comporta como un vidrio.",
	},
	"hematites": {
		"family": "cristal",
		"melt_c": null, "soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": null, "k": null,
		"route": "natural", "route_text": "Mineral natural: se compra y se talla. Sin datos de cómo le afecta el horno ni de su resistencia: no se predice.",
	},
	"cuarzo": {
		"family": "cristal",
		"melt_c": null,
		"soften_c": { "value": 1585.0, "quality": "estimate", "source": "caso medido más parecido: la sílice fundida (" + SRC_CORNING_7980 + ")" },
		"air_c": null, "air_what": "",
		"inert_c": null,
		"inversion_c": { "value": 573.0, "quality": "secondary", "source": SRC_QUARTZ_INV },
		"alpha": { "value": 13.2e-6, "min": 7.1e-6, "max": 13.2e-6, "quality": "secondary", "source": SRC_TYDEX_QUARTZ + " (se toma la perpendicular, la peor)" },
		"k": { "value": 6.2, "min": 6.2, "max": 10.7, "quality": "secondary", "source": SRC_TYDEX_QUARTZ + " (se toma la perpendicular, la peor)" },
		"cp": { "value": 742.0, "quality": "secondary", "source": SRC_JANAF },
		"route": "natural", "route_text": "Se compra natural o cultivado y se talla. Al pasar por 573 °C cambia de fase y se agrieta si se enfría deprisa.",
	},
	"circonita": {
		"family": "cristal",
		"melt_c": { "value": 2750.0, "quality": "secondary", "source": SRC_NASSAU_CZ },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 10.0e-6, "min": 9.0e-6, "max": 11.0e-6, "quality": "estimate", "source": SRC_YSZ },
		"k": { "value": 2.5, "min": 2.5, "max": 3.0, "quality": "estimate", "source": SRC_YSZ },
		"cp": { "value": 455.0, "quality": "estimate", "source": "caso medido más parecido: el ZrO₂ monoclínico (" + SRC_JANAF + "); la circonita es ZrO₂ estabilizada en cúbica" },
		"route": "natural", "route_text": "Funde a ~2750 °C: se cultiva por fusión en cráneo en la industria y se compra para tallarla.",
	},
	"zafiro": {
		"family": "cristal",
		"melt_c": { "value": 2053.0, "quality": "primary", "source": SRC_SG_SAPPHIRE },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 8.8e-6, "min": 7.9e-6, "max": 8.8e-6, "quality": "primary", "source": SRC_SG_SAPPHIRE + " (se toma la paralela, la peor)" },
		"k": { "value": 40.0, "quality": "primary", "source": SRC_SG_SAPPHIRE },
		"cp": { "value": 757.0, "quality": "primary", "source": SRC_SG_SAPPHIRE },
		"route": "cristal", "route_text": "No se funde en un horno de taller (2053 °C): se cultiva el cristal desde la alúmina fundida (Verneuil) y se talla.",
	},
	"rubi": {
		"family": "cristal",
		"melt_c": { "value": 2053.0, "quality": "primary", "source": SRC_SG_SAPPHIRE + " (el rubí es corindón)" },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 8.8e-6, "min": 7.9e-6, "max": 8.8e-6, "quality": "primary", "source": SRC_SG_SAPPHIRE + " (corindón; se toma la paralela, la peor)" },
		"k": { "value": 40.0, "quality": "primary", "source": SRC_SG_SAPPHIRE + " (corindón)" },
		"cp": { "value": 757.0, "quality": "primary", "source": SRC_SG_SAPPHIRE + " (corindón)" },
		"route": "cristal", "route_text": "Como el zafiro: alúmina con una pizca de óxido de cromo fundida a la llama (Verneuil) que crece una bola roja.",
	},
	"moissanita": {
		"family": "cristal",
		"melt_c": { "value": 2700.0, "quality": "secondary", "source": SRC_SIC_DISSOC },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 4.02e-6, "quality": "estimate", "source": "caso medido más parecido: el SiC sinterizado (" + SRC_HEXOLOY + ")" },
		"k": { "value": 125.6, "quality": "estimate", "source": "caso medido más parecido: el SiC sinterizado (" + SRC_HEXOLOY + ")" },
		"cp": { "value": 670.0, "quality": "estimate", "source": "caso medido más parecido: el SiC sinterizado (" + SRC_HEXOLOY + ")" },
		"route": "natural", "route_text": "No funde: se disocia a ~2700 °C. Se cultiva por sublimación a 2300-2500 °C en argón en la industria y se compra.",
	},
	"diamante": {
		"family": "cristal",
		"melt_c": null, "soften_c": null,
		"air_c": { "value": 600.0, "min": 600.0, "max": 700.0, "quality": "secondary", "source": SRC_KAPP + "; " + SRC_DIAMOND_OX },
		"air_what": "se oxida: se graba y se quema a CO₂",
		"inert_c": { "value": 1500.0, "min": 1500.0, "max": 1700.0, "quality": "estimate", "source": "caso medido más parecido: " + SRC_DIAMOND_VACUUM + ". Se toma 1500 °C, lo que dan para el vacío o el gas inerte los fabricantes de recubrimientos de diamante (estimación)" },
		"inversion_c": null,
		"alpha": { "value": 0.9e-6, "quality": "secondary", "source": SRC_BALMER },
		"k": { "value": 2000.0, "min": 1000.0, "max": 2200.0, "quality": "secondary", "source": SRC_BALMER },
		"cp": { "value": 509.0, "quality": "secondary", "source": SRC_NIST_DIAMOND },
		"route": "cristal", "route_text": "No se funde: se sintetiza a alta presión (HPHT) o en plasma (CVD). Al aire se quema por encima de ~600-700 °C.",
	},
	"alumina": {
		"family": "ceramica",
		"melt_c": { "value": 2053.0, "quality": "secondary", "source": "la del corindón: " + SRC_SG_SAPPHIRE },
		"soften_c": null, "air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 8.2e-6, "quality": "secondary", "source": SRC_COORSTEK },
		"k": { "value": 30.0, "quality": "secondary", "source": SRC_COORSTEK },
		"cp": { "value": 880.0, "quality": "secondary", "source": SRC_COORSTEK },
		"route": "sinterizar", "route_text": "Polvo de alúmina con un poco de MgO, prensado y sinterizado a 1700-1950 °C en vacío.",
	},
	# 5j · el acrílico de la prótesis de verdad (PROSTHESIS): no va al horno, fragua en frío
	"acrilico": {
		"family": "polimero",
		"melt_c": null,
		"soften_c": { "value": 125.0, "quality": "secondary", "source": SRC_ZAFAR_PMMA + " (la transición vítrea del PMMA de las prótesis; el autopolimerizable, con más monómero residual, se ablanda algo antes: sin cifra a mano)" },
		"air_c": null, "air_what": "", "inert_c": null, "inversion_c": null,
		"alpha": { "value": 81.0e-6, "quality": "secondary", "source": SRC_ZAFAR_PMMA },
		"k": { "value": 0.19, "quality": "secondary", "source": SRC_ASSAEL_PMMA },
		"cp": { "value": 1306.0, "quality": "secondary", "source": SRC_NIST_PMMA },
		"route": "frio", "route_text": "No va al horno: el polvo de PMMA y el líquido de metacrilato se mezclan y fraguan en frío en unos minutos. Se aplica sobre la garra rota y se lima en el animal, como se reparan de verdad los picos de las aves (en una garra, la misma técnica).",
	},
}

## Material nuevo de la 2.0 (no está en Data.INLAYS; el oráculo 1.x no cambia). Con todo lo que piden los motores de la
## garra: dureza, módulo, densidad, resistencia a flexión y tenacidad. La dureza Vickers se toma igual a la Knoop medida
## (14,1 GPa = 1438 kgf/mm²; estimación: a 1 kg, en la alúmina, las dos escalas están cerca).
## Cada entrada tiene la forma de las de Data.INLAYS (id, name, short, hv, mohs, E, area, alpha, col) para que el catálogo
## 2.0 la pueda añadir tal cual, y además lo que piden los motores de la garra: density (kg/m³; ClawMass), strength_mpa,
## strength_min, strength_max y kic (ClawFracture y ClawSharpness). area y alpha: la talla de la incrustación en una uña,
## la del zafiro del banco (estimación: el mismo compuesto, Al₂O₃). bench_twin: el material del banco con la misma
## mecánica en todos los datos del motor («» si no hay ninguno): el rubí es corindón como el zafiro.
const NEW_MATERIALS := {
	"alumina": {
		"id": "alumina", "name": "Alúmina sinterizada", "short": "Alúmina", "hv": 1438.0, "mohs": 9.0, "E": 370.0,
		"area": 0.07, "alpha": Data.GEM_ALPHA, "col": "#F4F1EA",
		# la densidad, la resistencia y la tenacidad, de sus filas de ClawMass y ClawFracture (unidad 5g; las mismas cifras)
		"density": ClawMass.DENSITY["alumina"]["value"],
		"strength_mpa": ClawFracture.BRITTLE["alumina"]["value"], "strength_min": ClawFracture.BRITTLE["alumina"]["min"],
		"strength_max": ClawFracture.BRITTLE["alumina"]["max"], "kic": ClawFracture.BRITTLE["alumina"]["kic"],
		"bench_twin": "",
		"quality": "secondary",
		"source": SRC_COORSTEK + ". HV ≈ HK (estimación). La alúmina translúcida de Coble (" + SRC_COBLE + ") es el mismo material, sin poros",
	},
	"rubi": {
		"id": "rubi", "name": "Rubí sintético", "short": "Rubí", "hv": 2000.0, "mohs": 9.0, "E": 400.0,
		"area": 0.07, "alpha": Data.GEM_ALPHA, "col": "#C8102E",
		"density": ClawMass.DENSITY["zafiro"]["value"],
		"strength_mpa": ClawFracture.BRITTLE["zafiro"]["value"], "strength_min": ClawFracture.BRITTLE["zafiro"]["min"],
		"strength_max": ClawFracture.BRITTLE["zafiro"]["max"], "kic": ClawFracture.BRITTLE["zafiro"]["kic"],
		"bench_twin": "zafiro",
		"quality": "secondary",
		"source": "El rubí es corindón con un poco de cromo: la dureza, el módulo, la densidad y la resistencia son las del zafiro del banco (" + SRC_RUBY_CR + "; " + SRC_SG_SAPPHIRE + "). El color es solo dibujo",
	},
}

## La prótesis de verdad de una garra rota (unidad 5j): el acrílico dental autopolimerizable (polvo de PMMA y líquido de
## metacrilato) con que los veterinarios reparan el pico de las aves (Samour 2006; Matta et al. 2022). Se aplica sobre el muñón
## con algo de sobra, fragua en frío y se lima en el animal hasta la forma de la garra; se cae o se rehace cuando crece la
## queratina. En una garra, la misma técnica (use: suposición con el caso documentado más parecido, el pico). No es ficción.
## No está en el banco (Catalog.INLAYS): la cetrería lo lima como bloque sobre el muñón (ClawCare.supports_block). Con la
## forma de las entradas de Data.INLAYS que usan la reforja y la cetrería (id, name, short, hv, E, col) y lo que piden los
## motores de la garra: density (kg/m³), strength_mpa, strength_min, strength_max y kic. Las cifras, del PMMA de las prótesis
## dentales:
##   - hv: ~20 VHN y 18-20 KHN del termopolimerizado (Zafar 2020); el autopolimerizable, con más monómero residual, igual o algo
##     más blando: estimación con el caso medido más parecido;
##   - E: 2,6 GPa del termopolimerizado (Zafar 2020), con la banda de la norma (≥ 1,5 GPa en los autopolimerizables);
##   - resistencia y tenacidad: las medidas en el autopolimerizable (84,4 MPa y 1,63 MPa·√m; Barbosa et al. en Alqutaibi et
##     al. 2023), con el mínimo de la norma ISO 20795-1 (60 MPa) y el del termopolimerizado (92,8 MPa) como banda;
##   - densidad 1,18 g/cm³ (Zafar 2020). El color es dibujo.
const PROSTHESIS := {
	"acrilico": {
		"id": "acrilico", "name": "Acrílico dental", "short": "Acrílico", "hv": 20.0, "E": 2.6, "col": "#E6DCCF",
		"density": 1180.0, "strength_mpa": 84.4, "strength_min": 60.0, "strength_max": 92.84, "kic": 1.63,
		"quality": "secondary", "hv_quality": "estimate", "real": true,
		"use": "Así se repara de verdad el pico de las aves: el acrílico dental se aplica sobre lo que queda con algo de sobra, fragua en frío y se lima en el animal; se cae o se rehace cuando crece la queratina (cada 8-12 semanas en el pico). En una garra, la misma técnica.",
		"use_quality": "estimate",
		"use_source": SRC_SAMOUR_REPAIR + "; " + SRC_MATTA + ". En una garra: la misma técnica (suposición con el caso documentado más parecido, el pico)",
		"source": "El acrílico dental autopolimerizable de las reparaciones del pico de las aves (" + SRC_SAMOUR_REPAIR + "; " + SRC_MATTA + "), el PMMA de las prótesis dentales: dureza ~20 HV, la del termopolimerizado (" + SRC_ZAFAR_PMMA + "; estimación: el autopolimerizable, igual o algo más blando); módulo 2,6 GPa (" + SRC_ZAFAR_PMMA + "; la norma pide al menos 1,5 GPa: " + SRC_ISO20795 + "); resistencia a flexión 84,4 MPa y tenacidad 1,63 MPa·√m, medidas en el autopolimerizable (" + SRC_ALQUTAIBI + "); densidad 1,18 g/cm³. El color es dibujo",
	},
}


# ════════ El horno-fundidor del taller (ficción en conjunto) ════════
const FURNACE := {
	"name": "Horno-fundidor del taller",
	"quality": "ficcion",
	"source": "FICCIÓN: ninguna máquina de taller hace todo esto. Cada modo es el de una máquina industrial real (horno de mufla o de vacío, horno de inducción, soplete de Verneuil, prensa HPHT, reactor de CVD) con sus temperaturas, presiones y atmósferas de verdad; lo inventado es tenerlas juntas en una sola caja",
	"modes": ["calentar", "induccion", "fundir_colar", "sinterizar", "sintetizar"],
}
## Los mandos del horno: id, nombre, unidad, rango, qué hace físicamente y por qué importa. La interfaz los pinta como
## diales y botones; el tutorial general los explica uno a uno.
const CONTROLS := [
	{
		"id": "modo", "name": "Modo", "unit": "", "options": ["calentar", "induccion", "fundir_colar", "sinterizar", "sintetizar"],
		"option_names": { "calentar": "Calentar (tratamiento)", "induccion": "Inducción (fundir metal)", "fundir_colar": "Fundir y colar", "sinterizar": "Sinterizar polvo", "sintetizar": "Sintetizar cristal" },
		"what": "Elige la máquina: calentar una pieza (recocer, probar qué le hace el calor), fundir metal con una bobina de inducción, fundir y colar en un molde, sinterizar polvo prensado o cultivar un cristal (Verneuil, HPHT, CVD).",
		"why": "Cada material se hace de una forma: el oro se cuela, el metal duro se sinteriza, el zafiro y el diamante se cultivan. Con el modo equivocado no sale.",
		"source": FURNACE.source, "quality": "ficcion",
	},
	{
		"id": "temp_c", "name": "Temperatura", "unit": "°C", "min": 20.0, "max": 3000.0, "step": 5.0,
		"what": "La temperatura de la carga (del crisol, de la llama o de la prensa).",
		"why": "Por debajo del punto de fusión o de sinterizado no pasa nada; dentro del margen sale bien; por encima aparecen defectos (burbujas, grano grueso, oxidación o se vuelve grafito).",
		"source": "puntos de fusión y márgenes de cada receta (ver sus fuentes)", "quality": "secondary",
	},
	{
		"id": "time_s", "name": "Tiempo", "unit": "s", "min": 0.0, "max": 3.6e6, "step": 60.0,
		"what": "Cuánto se mantiene a esa temperatura (en un crecimiento, cuánto crece el cristal).",
		"why": "Sinterizar es difusión: pide horas. Un cristal crece a un ritmo (mm/h, mg/h, µm/h): poco tiempo da una pieza pequeña o porosa.",
		"source": "ritmos de cada receta (Verneuil, Sumiya 2002, Yan 2002, Coble)", "quality": "secondary",
	},
	{
		"id": "atmosphere", "name": "Atmósfera", "unit": "", "options": ["aire", "argon", "vacio", "h2_ch4"],
		"option_names": { "aire": "Aire", "argon": "Argón (gas inerte)", "vacio": "Vacío", "h2_ch4": "Hidrógeno con metano (CVD)" },
		"what": "El gas que rodea la carga.",
		"why": "El oxígeno del aire quema el diamante (~600 °C), oxida el metal duro (~540 °C) y contamina el titanio fundido; el vacío o el argón lo evitan. La CVD necesita hidrógeno con un poco de metano.",
		"source": SRC_KAPP + "; " + SRC_GC_GUIDE + "; " + SRC_ALPHA_CASE + "; " + SRC_BALMER, "quality": "secondary",
	},
	{
		"id": "pressure_mpa", "name": "Presión", "unit": "MPa", "min": 0.0, "max": 6000.0, "step": 100.0,
		"what": "La presión que la prensa aplica a la carga (0,1 MPa es la del aire).",
		"why": "Solo la síntesis de diamante HPHT la necesita: el diamante es estable por encima de la línea de Kennedy, P (kbar) = 19,4 + T/40 (5,5 GPa a ~1400 °C). Por debajo, el carbono sigue siendo grafito.",
		"source": SRC_KENNEDY + "; " + SRC_SUMIYA, "quality": "secondary",
	},
	{
		"id": "methane", "name": "Metano en el gas (CVD)", "unit": "%", "min": 0.0, "max": 20.0, "step": 0.1,
		"what": "La proporción de metano en el hidrógeno que el plasma rompe sobre la pieza (el motor la recibe como fracción: 5 % = 0,05).",
		"why": "Con un 0,1-10 % de metano crece diamante; con menos no llega carbono y con más se deposita hollín y grafito.",
		"source": SRC_BALMER, "quality": "secondary",
	},
	{
		"id": "mold", "name": "Molde", "unit": "", "options": ["yeso", "ceramico", "grafito"],
		"option_names": { "yeso": "Revestimiento de yeso", "ceramico": "Cáscara cerámica (fosfato)", "grafito": "Grafito (en vacío)" },
		"what": "Dónde se cuela el metal o el vidrio (al fundir y colar).",
		"why": "El yeso no aguanta más de ~816 °C sin descomponerse: vale para oro y vidrio, no para acero ni titanio.",
		"source": SRC_GYPSUM, "quality": "secondary",
	},
	{
		"id": "cool", "name": "Enfriar", "unit": "", "options": ["horno", "aire", "aceite", "agua"],
		"option_names": { "horno": "Dentro del horno (lento, recociendo)", "aire": "Al aire", "aceite": "En aceite", "agua": "En agua" },
		"what": "Cómo se enfría la pieza al sacarla.",
		"why": "Una pieza frágil se agrieta si el salto de temperatura pasa del que aguanta (Kingery, con el factor de Manson); el vidrio hay que recocerlo y el cuarzo no puede cruzar 573 °C deprisa.",
		"source": SRC_KINGERY + "; " + SRC_MANSON + "; " + SRC_BULLSEYE + "; " + SRC_QUARTZ_INV, "quality": "secondary",
	},
]

# ════════ Polvos y materias primas ════════
const POWDERS := {
	"al2o3": { "id": "al2o3", "name": "Óxido de aluminio (alúmina)", "formula": "Al₂O₃", "what": "La materia del zafiro, del rubí y de la cerámica de alúmina.", "source": SRC_VERNEUIL },
	"cr2o3": { "id": "cr2o3", "name": "Óxido de cromo", "formula": "Cr₂O₃", "what": "Una pizca en la alúmina da el rojo del rubí.", "source": SRC_RUBY_CR },
	"mgo": { "id": "mgo", "name": "Óxido de magnesio", "formula": "MgO", "what": "Un cuarto de punto en la alúmina frena el crecimiento del grano y deja sinterizar sin poros.", "source": SRC_COBLE },
	"wc": { "id": "wc", "name": "Carburo de tungsteno", "formula": "WC", "what": "Los granos duros del metal duro.", "source": SRC_GC_GUIDE },
	"co": { "id": "co", "name": "Cobalto", "formula": "Co", "what": "El aglutinante: funde con algo de carbono y pega los granos de WC.", "source": SRC_WC_SINTER },
	"grafito": { "id": "grafito", "name": "Grafito", "formula": "C", "what": "La fuente de carbono del diamante HPHT.", "source": SRC_SUMIYA },
	"fe_co": { "id": "fe_co", "name": "Disolvente de hierro y cobalto (con algo de Ti)", "formula": "Fe-Co-Ti", "what": "Disuelve el carbono y lo deja crecer como diamante; sin él, la conversión directa pide mucha más presión.", "source": SRC_BALMER + "; " + SRC_SUMIYA },
	"ch4_h2": { "id": "ch4_h2", "name": "Metano en hidrógeno", "formula": "CH₄ + H₂", "what": "El gas de la CVD: el plasma lo rompe y el carbono se deposita como diamante.", "source": SRC_BALMER },
	"oro": { "id": "oro", "name": "Granalla de oro fino", "formula": "Au", "what": "Oro de 24 quilates en granos para fundir.", "source": SRC_ITS90 },
	"acero": { "id": "acero", "name": "Chatarra de acero inoxidable 304", "formula": "Fe-18Cr-8Ni", "what": "Recortes del mismo acero de la tachuela del banco.", "source": SRC_AK304 },
	"titanio": { "id": "titanio", "name": "Lingote de titanio de grado 2", "formula": "Ti", "what": "Titanio comercialmente puro.", "source": SRC_CRC },
	"vidrio": { "id": "vidrio", "name": "Granalla de vidrio de fundir", "formula": "vidrio", "what": "Trozos de vidrio limpio para colar en el molde.", "source": SRC_BULLSEYE },
}

# ════════ 5w · pesar para la pieza de esta garra ════════
## Cuánto se pesa (ClawForge.mix_plan): lo que pide la pieza es su volumen por la densidad del material (ClawMass, con su
## fuente) y cada polvo, ese total por su fracción en peso de la receta. Lo que se pesa de más y lo que se admite por encima
## son elecciones del juego; la balanza, la de un laboratorio de análisis.
##   - extra: lo que se pesa de más sobre lo que pide la pieza (lo que se queda en el plato, en el crisol o en la tolva);
##   - over: hasta cuánto por encima de lo que pide la pieza se admite en el crisol (más es desperdiciar);
##   - inner (5w): lo que se apunta por dentro del margen de cada polvo, en fracción del margen;
##   - readability_g: lo que distingue la balanza (g), la de una balanza analítica de 220 g.
const MIX_PLAN := {
	"extra": { "value": 0.1, "quality": "juego", "source": "un 10 % de más sobre lo que pide la pieza, para lo que se queda pegado en el plato, el crisol o la tolva: elección del juego (la merma real depende de la máquina)" },
	"over": { "value": 0.2, "quality": "juego", "source": "hasta un 20 % por encima de lo que pide la pieza: elección del juego (más se desperdicia: no cabe en el crisol de una pieza tan pequeña)" },
	"inner": { "value": 0.1, "quality": "juego", "source": "se pesa para una proporción al menos a un 10 % del margen de la receta por dentro de cada borde (si la de la receta está en el borde, como el 0,25 % de MgO de la alúmina, que es su mínimo): elección del juego, para que lo que no distingue la balanza no deje la mezcla fuera" },
	"readability_g": { "value": 0.0001, "quality": "secondary", "source": "balanza analítica de laboratorio de 220 g que distingue 0,1 mg (p. ej., Mettler Toledo ME204, ficha técnica): lo bastante para pesar los miligramos de MgO o de Cr₂O₃ de una funda" },
}
## La CVD no pesa polvo: el gas entra de la botella mientras crece la capa. En la balanza se pone, por juego, el carbono que
## pide la capa (el del diamante de la funda).
const CVD_GAS_NOTE := "La CVD no pesa polvo: el metano y el hidrógeno entran de la botella mientras crece la capa, y solo una parte del carbono acaba en ella. Aquí se pesa, por juego, el carbono que pide la capa: el del diamante de la funda."


# ════════ Recetas por material objetivo ════════
## Cada receta: id, name, product (Data.INLAYS o «alumina»), variety, mode, method, form («bola», «cristal», «capa»,
## «sinterizada», «colada»); powders [{ id, value, min, max, low, high }] (fracción en peso; low/high: lo que pasa fuera);
## temp_c, time_s, pressure_mpa { value, min, max, low, high }; atmosphere { ok, value, bad: {atm: {code, text}} };
## mold { ok, value, bad }; cool { ok, value, bad }; growth (ritmo del crecimiento: mm_h, mg_h o um_h, y tamaño máximo);
## quality y source. low y high son { code, text }.
## Códigos de defecto: «modo», «mezcla», «atmosfera», «presion», «frio» (te quedas corto de temperatura), «caliente» (te
## pasas), «corto» (poco tiempo), «molde», «choque» (se agrieta al enfriar), «sin_recocer», «inversion».
const RECIPE_IDS := ["zafiro", "rubi", "metal_duro", "alumina", "acero", "oro", "titanio", "vidrio", "diamante_hpht", "diamante_cvd"]
const RECIPES := {
	"zafiro": {
		"id": "zafiro", "name": "Zafiro (Verneuil)", "product": "zafiro", "variety": "zafiro sintético incoloro", "mode": "sintetizar", "method": "verneuil", "form": "bola",
		"powders": [
			{ "id": "al2o3", "value": 1.0, "min": 0.9997, "max": 1.0, "low": { "code": "mezcla", "text": "La alúmina no es pura: otro óxido en la mezcla colorea el cristal o lo llena de inclusiones." } },
		],
		"temp_c": {
			"value": 2100.0, "min": 2053.0, "max": 2200.0, "quality": "secondary", "source": SRC_SG_SAPPHIRE + "; " + SRC_VERNEUIL,
			"low": { "code": "frio", "text": "Por debajo de 2053 °C la alúmina no funde: el polvo se queda en la semilla como una costra blanca y porosa, sin cristal.", "finish": "poroso" },
			"high": { "code": "caliente", "text": "Más caliente que la llama de oxígeno e hidrógeno (~2200 °C): el casquete fundido crece demasiado, gotea y deja burbujas y tensiones (estimación: la llama del método no pasa de ahí)." },
		},
		"time_s": {
			"value": 7200.0, "min": 0.0, "quality": "secondary", "source": SRC_VERNEUIL,
			"low": { "code": "corto", "text": "La bola es más corta que la funda: a ~10 mm/h no ha dado tiempo a crecer lo que hace falta." },
		},
		"growth": { "kind": "mm_h", "value": 10.0, "max_diameter_mm": 20.0, "diameter_mm": 13.0, "quality": "secondary", "source": SRC_VERNEUIL },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": 1.0, "quality": "secondary", "source": SRC_VERNEUIL, "high": { "code": "presion", "text": "Verneuil es una llama al aire libre: no hay prensa que valga; con presión no hay llama." } },
		"atmosphere": { "ok": ["aire"], "value": "aire", "source": SRC_VERNEUIL, "bad": { "vacio": { "code": "atmosfera", "text": "En vacío no hay llama: el soplete de oxígeno e hidrógeno necesita arder." }, "argon": { "code": "atmosfera", "text": "En argón la llama se apaga: el método es un soplete al aire." }, "h2_ch4": { "code": "atmosfera", "text": "Con metano la llama deposita hollín sobre la bola: sale negra y con inclusiones." } } },
		"cool": { "ok": ["horno", "aire"], "value": "aire", "source": SRC_VERNEUIL + "; " + SRC_KINGERY },
		"quality": "secondary", "source": SRC_VERNEUIL,
	},
	"rubi": {
		"id": "rubi", "name": "Rubí (Verneuil)", "product": "rubi", "variety": "rubí", "mode": "sintetizar", "method": "verneuil", "form": "bola",
		"powders": [
			{ "id": "al2o3", "value": 0.99, "min": 0.95, "max": 0.9997 },
			{ "id": "cr2o3", "value": 0.01, "min": 0.0003, "max": 0.05,
				"low": { "code": "mezcla", "text": "Sin cromo bastante (menos de un 0,03 %) sale zafiro rosado o incoloro, no rubí." },
				"high": { "code": "mezcla", "text": "Con más de un 5 % de Cr₂O₃ te sales de lo descrito: el color se oscurece y no hay receta medida (estimación)." } },
		],
		"temp_c": {
			"value": 2100.0, "min": 2053.0, "max": 2200.0, "quality": "secondary", "source": SRC_SG_SAPPHIRE + "; " + SRC_VERNEUIL,
			"low": { "code": "frio", "text": "Por debajo de 2053 °C la alúmina no funde: queda una costra rosada y porosa, sin cristal.", "finish": "poroso" },
			"high": { "code": "caliente", "text": "Más caliente que la llama de oxígeno e hidrógeno (~2200 °C): el casquete gotea y deja burbujas y tensiones (estimación)." },
		},
		"time_s": { "value": 7200.0, "min": 0.0, "quality": "secondary", "source": SRC_VERNEUIL, "low": { "code": "corto", "text": "La bola es más corta que la funda: a ~10 mm/h no ha crecido bastante." } },
		"growth": { "kind": "mm_h", "value": 10.0, "max_diameter_mm": 20.0, "diameter_mm": 13.0, "quality": "secondary", "source": SRC_VERNEUIL },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": 1.0, "quality": "secondary", "source": SRC_VERNEUIL, "high": { "code": "presion", "text": "Verneuil es una llama al aire libre: con presión no hay llama." } },
		"atmosphere": { "ok": ["aire"], "value": "aire", "source": SRC_VERNEUIL, "bad": { "vacio": { "code": "atmosfera", "text": "En vacío no hay llama." }, "argon": { "code": "atmosfera", "text": "En argón la llama se apaga." }, "h2_ch4": { "code": "atmosfera", "text": "Con metano la llama deposita hollín sobre la bola." } } },
		"cool": { "ok": ["horno", "aire"], "value": "aire", "source": SRC_VERNEUIL + "; " + SRC_KINGERY },
		"quality": "secondary", "source": SRC_VERNEUIL + "; " + SRC_RUBY_CR,
	},
	"metal_duro": {
		"id": "metal_duro", "name": "Metal duro (WC-Co sinterizado)", "product": "tungsteno", "variety": "", "mode": "sinterizar", "method": "sinterizado", "form": "sinterizada",
		"powders": [
			{ "id": "wc", "value": 0.945, "min": 0.935, "max": 0.955 },
			{ "id": "co", "value": 0.055, "min": 0.045, "max": 0.065,
				"low": { "code": "mezcla", "text": "Con poco cobalto no hay líquido bastante para cerrar los huecos: queda porosa y se desmorona.", "finish": "poroso" },
				"high": { "code": "mezcla", "text": "Con más cobalto sale otro grado: más tenaz pero más blando que el del banco (2000 HV con un 5,5 % de Co)." } },
		],
		"temp_c": {
			"value": 1420.0, "min": 1350.0, "max": 1500.0, "quality": "secondary", "source": SRC_WC_SINTER,
			"low": { "code": "frio", "text": "Por debajo de ~1350 °C el cobalto no llega a fundir con el carbono: sin fase líquida, la pieza queda porosa y blanda.", "finish": "poroso" },
			"high": { "code": "caliente", "text": "Por encima de ~1500 °C hay demasiado líquido: el grano crece, la pieza se deforma y pierde dureza (estimación)." },
		},
		"time_s": { "value": 3600.0, "min": 3600.0, "quality": "estimate", "source": "sinterizado de una hora a la temperatura (los ensayos de " + SRC_WC_SINTER + "); estimación", "low": { "code": "corto", "text": "Menos de una hora: los huecos no se cierran del todo y queda porosa.", "finish": "poroso" } },
		"pressure_mpa": { "value": 0.0, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_WC_SINTER },
		"atmosphere": { "ok": ["vacio", "argon"], "value": "vacio", "source": SRC_WC_SINTER + "; " + SRC_GC_GUIDE, "bad": { "aire": { "code": "atmosfera", "text": "Al aire el carburo se oxida desde ~540 °C: sale una pieza cubierta de polvo de óxido, quemada.", "finish": "quemado" }, "h2_ch4": { "code": "atmosfera", "text": "El metano carbura el cobalto de más: sale grafito libre y la pieza queda frágil (estimación)." } } },
		"cool": { "ok": ["horno", "aire", "aceite", "agua"], "value": "horno", "source": SRC_KINGERY + "; " + SRC_MANSON },
		"shrink": { "value": 0.2, "quality": "secondary", "source": SRC_GC_GUIDE },
		"quality": "secondary", "source": SRC_WC_SINTER + "; " + SRC_GC_GUIDE,
	},
	"alumina": {
		"id": "alumina", "name": "Alúmina sinterizada (Coble)", "product": "alumina", "variety": "", "mode": "sinterizar", "method": "sinterizado", "form": "sinterizada",
		"powders": [
			{ "id": "al2o3", "value": 0.9975, "min": 0.995, "max": 0.9975 },
			{ "id": "mgo", "value": 0.0025, "min": 0.0025, "max": 0.005,
				"low": { "code": "mezcla", "text": "Sin un cuarto de punto de MgO el grano crece a saltos y deja poros atrapados: opaca y más débil.", "finish": "poroso" },
				"high": { "code": "mezcla", "text": "Con más de medio punto de MgO aparece espinela en los bordes de grano: fuera de la receta." } },
		],
		"temp_c": {
			"value": 1850.0, "min": 1700.0, "max": 1950.0, "quality": "secondary", "source": SRC_COBLE,
			"low": { "code": "frio", "text": "Por debajo de ~1700 °C no se cierran los poros: queda una pieza blanca, porosa y débil.", "finish": "poroso" },
			"high": { "code": "caliente", "text": "Por encima de ~1950 °C te sales de la receta de Coble: el grano engorda y la pieza pierde resistencia (estimación)." },
		},
		"time_s": { "value": 36000.0, "min": 0.0, "quality": "secondary", "source": SRC_COBLE, "low": { "code": "corto", "text": "Poco tiempo para esa temperatura (24 h a 1700 °C, 6-8 h a 1900 °C): quedan poros.", "finish": "poroso" } },
		"pressure_mpa": { "value": 0.0, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_COBLE },
		"atmosphere": { "ok": ["vacio"], "value": "vacio", "source": SRC_COBLE, "bad": { "aire": { "code": "atmosfera", "text": "Al aire el gas queda atrapado en los poros y no se cierran: sale opaca y porosa (Coble pide vacío o hidrógeno).", "finish": "poroso" }, "argon": { "code": "atmosfera", "text": "El argón no se disuelve en la alúmina y se queda en los poros: no se cierran del todo.", "finish": "poroso" }, "h2_ch4": { "code": "atmosfera", "text": "El metano deja carbono: sale gris y con inclusiones (estimación)." } } },
		"cool": { "ok": ["horno", "aire"], "value": "horno", "source": SRC_KINGERY + "; " + SRC_MANSON },
		"quality": "secondary", "source": SRC_COBLE + "; " + SRC_COORSTEK,
	},
	"acero": {
		"id": "acero", "name": "Acero inoxidable fundido por inducción", "product": "acero", "variety": "", "mode": "induccion", "method": "colada", "form": "colada",
		"powders": [ { "id": "acero", "value": 1.0, "min": 1.0, "max": 1.0, "low": { "code": "mezcla", "text": "Otro metal en el crisol cambia la aleación: ya no es el 304." } } ],
		"temp_c": {
			"value": 1525.0, "min": 1500.0, "max": 1550.0, "quality": "secondary", "source": SRC_AK304 + "; " + SRC_STEEL_POUR,
			"low": { "code": "frio", "text": "Sin 100-150 °C por encima del líquido (1454 °C) el acero empieza a solidificar en el bebedero: la colada no llena el molde." },
			"high": { "code": "caliente", "text": "Demasiado caliente: el acero absorbe gas, reacciona con el molde y sale poroso y de grano grueso.", "finish": "poroso" },
		},
		"time_s": { "value": 600.0, "min": 300.0, "quality": "estimate", "source": "hasta que se funde toda la carga en un horno de inducción pequeño (estimación)", "low": { "code": "corto", "text": "La carga no se ha fundido entera: quedan trozos sólidos en el crisol." } },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_STEEL_POUR },
		"atmosphere": { "ok": ["aire", "argon", "vacio"], "value": "aire", "source": SRC_STEEL_POUR, "bad": { "h2_ch4": { "code": "atmosfera", "text": "El metano carbura el acero: deja de ser inoxidable (estimación)." } } },
		"mold": { "ok": ["ceramico"], "value": "ceramico", "source": SRC_GYPSUM, "bad": { "yeso": { "code": "molde", "text": "El yeso se descompone a más de ~816 °C: el acero a 1500 °C lo quema, salen gases de azufre y la funda queda porosa y manchada.", "finish": "poroso" }, "grafito": { "code": "molde", "text": "El grafito carbura el acero fundido: la superficie deja de ser inoxidable (estimación)." } } },
		"cool": { "ok": ["agua", "aire", "aceite", "horno"], "value": "agua", "source": SRC_AK304 },
		"quality": "secondary", "source": SRC_AK304 + "; " + SRC_STEEL_POUR,
	},
	"oro": {
		"id": "oro", "name": "Oro colado a la cera perdida", "product": "oro", "variety": "", "mode": "fundir_colar", "method": "colada", "form": "colada",
		"powders": [ { "id": "oro", "value": 1.0, "min": 1.0, "max": 1.0, "low": { "code": "mezcla", "text": "Otro metal en el crisol cambia la aleación: ya no es oro fino." } } ],
		"temp_c": {
			"value": 1150.0, "min": 1094.0, "max": 1164.0, "quality": "secondary", "source": SRC_ITS90 + "; " + SRC_GANOKSIN,
			"low": { "code": "frio", "text": "Sin 30-100 °C por encima de 1064 °C el oro solidifica antes de llenar el molde: la funda sale incompleta." },
			"high": { "code": "caliente", "text": "Más de ~100 °C por encima del líquido: rechupes, poros de gas y grano grueso.", "finish": "poroso" },
		},
		"time_s": { "value": 300.0, "min": 120.0, "quality": "estimate", "source": "hasta que se funde toda la granalla en el crisol (estimación)", "low": { "code": "corto", "text": "Quedan granos sin fundir en el crisol." } },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_GANOKSIN },
		"atmosphere": { "ok": ["aire", "argon", "vacio"], "value": "aire", "source": SRC_ITS90, "bad": { "h2_ch4": { "code": "atmosfera", "text": "Con metano se ensucia el oro de hollín (estimación)." } } },
		"mold": { "ok": ["yeso", "ceramico"], "value": "yeso", "source": SRC_GYPSUM, "bad": { "grafito": { "code": "molde", "text": "Un molde de grafito no copia los detalles de una cera: la funda sale basta (estimación)." } } },
		"cool": { "ok": ["agua", "aire", "aceite", "horno"], "value": "agua", "source": SRC_GANOKSIN },
		"quality": "secondary", "source": SRC_ITS90 + "; " + SRC_GANOKSIN,
	},
	"titanio": {
		"id": "titanio", "name": "Titanio fundido en vacío", "product": "titanio", "variety": "", "mode": "fundir_colar", "method": "colada", "form": "colada",
		"powders": [ { "id": "titanio", "value": 1.0, "min": 1.0, "max": 1.0, "low": { "code": "mezcla", "text": "Otro metal cambia la aleación: ya no es titanio de grado 2." } } ],
		"temp_c": {
			"value": 1720.0, "min": 1698.0, "max": 1768.0, "quality": "estimate", "source": SRC_CRC + "; sobrecalentamiento de 30-100 °C como en el oro (" + SRC_GANOKSIN + "): estimación",
			"low": { "code": "frio", "text": "Sin sobrecalentamiento por encima de 1668 °C el titanio no llena el molde." },
			"high": { "code": "caliente", "text": "Demasiado caliente: reacciona con el molde y aumenta la capa alfa (estimación)." },
		},
		"time_s": { "value": 300.0, "min": 120.0, "quality": "estimate", "source": "hasta que se funde el lingote con el arco (estimación)", "low": { "code": "corto", "text": "Queda titanio sin fundir." } },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_TI_CAST + " (en argón, a la presión del aire)" },
		"atmosphere": { "ok": ["vacio", "argon"], "value": "argon", "source": SRC_TI_CAST + "; " + SRC_ALPHA_CASE, "bad": { "aire": { "code": "atmosfera", "text": "Fundido al aire, el titanio coge oxígeno: capa alfa dura y frágil, con microgrietas. Quemado.", "finish": "quemado" }, "h2_ch4": { "code": "atmosfera", "text": "El hidrógeno fragiliza el titanio: quemado.", "finish": "quemado" } } },
		"mold": { "ok": ["grafito", "ceramico"], "value": "ceramico", "source": SRC_TI_CAST + "; las prótesis dentales de titanio se cuelan a la cera perdida en revestimientos de fosfato específicos del titanio (" + SRC_FERREIRA_TI + "; " + SRC_HSU + ")", "bad": { "yeso": { "code": "molde", "text": "El yeso (sulfato y sílice) reacciona con el titanio fundido: capa alfa y poros.", "finish": "poroso" } } },
		"cool": { "ok": ["agua", "aire", "aceite", "horno"], "value": "aire", "source": SRC_TI_CAST },
		"quality": "estimate", "source": SRC_TI_CAST + "; " + SRC_ALPHA_CASE,
	},
	"vidrio": {
		"id": "vidrio", "name": "Vidrio colado en el horno (cera perdida)", "product": "vidrio", "variety": "", "mode": "fundir_colar", "method": "colada", "form": "colada",
		"powders": [ { "id": "vidrio", "value": 1.0, "min": 1.0, "max": 1.0, "low": { "code": "mezcla", "text": "Vidrios distintos en el mismo molde dilatan distinto y se rajan al enfriar." } } ],
		"temp_c": {
			"value": 830.0, "min": 800.0, "max": 843.0, "quality": "secondary", "source": SRC_BULLSEYE,
			"low": { "code": "frio", "text": "Sin pasar bien del reblandecimiento el vidrio no fluye: no llena el molde y quedan granos sueltos." },
			"high": { "code": "caliente", "text": "Por encima de ~843 °C el molde de yeso falla y el vidrio se escapa por las grietas." },
		},
		"time_s": { "value": 10800.0, "min": 10800.0, "quality": "secondary", "source": SRC_BULLSEYE, "low": { "code": "corto", "text": "Menos de 3 h a esa temperatura: el vidrio no ha bajado del todo al molde." } },
		"pressure_mpa": { "value": 0.101, "min": 0.0, "max": INF, "quality": "secondary", "source": SRC_BULLSEYE },
		"atmosphere": { "ok": ["aire"], "value": "aire", "source": SRC_BULLSEYE, "bad": { "vacio": { "code": "atmosfera", "text": "El molde de yeso húmedo hierve en vacío y se rompe (estimación)." }, "argon": { "code": "atmosfera", "text": "Sin aire no se quema la cera que quedó en el molde: el vidrio sale gris (estimación)." }, "h2_ch4": { "code": "atmosfera", "text": "El metano reduce el vidrio: sale gris y con burbujas (estimación)." } } },
		"mold": { "ok": ["yeso"], "value": "yeso", "source": SRC_BULLSEYE, "bad": { "grafito": { "code": "molde", "text": "Un molde de grafito no copia los detalles de una cera (estimación)." }, "ceramico": { "code": "molde", "text": "La cáscara cerámica no se desmolda del vidrio sin romperlo (estimación)." } } },
		"cool": { "ok": ["horno"], "value": "horno", "source": SRC_BULLSEYE },
		"quality": "secondary", "source": SRC_BULLSEYE,
	},
	"diamante_hpht": {
		"id": "diamante_hpht", "name": "Diamante HPHT (prensa)", "product": "diamante", "variety": "diamante sintético HPHT", "mode": "sintetizar", "method": "hpht", "form": "cristal",
		"powders": [
			{ "id": "grafito", "value": 0.3, "min": 0.2, "max": 0.4 },
			{ "id": "fe_co", "value": 0.7, "min": 0.6, "max": 0.8,
				"low": { "code": "mezcla", "text": "Sin disolvente metálico el grafito no pasa a diamante en una prensa: la conversión directa pide mucha más presión y temperatura." },
				"high": { "code": "mezcla", "text": "Con poco grafito se acaba el carbono antes de que crezca el cristal (estimación)." } },
		],
		"temp_c": {
			"value": 1345.0, "min": 1300.0, "max": 1425.0, "quality": "secondary", "source": SRC_SUMIYA + "; " + SRC_KENNEDY,
			"low": { "code": "frio", "text": "Por debajo de ~1300 °C el disolvente de Fe-Co no funde con el carbono: no crece nada (estimación por debajo de los 1340 °C de Sumiya)." },
			"high": { "code": "caliente", "text": "Por encima de la línea de Kennedy a esa presión (1424 °C a 5,5 GPa) el grafito es lo estable: sale grafito, no diamante." },
		},
		"time_s": { "value": 72000.0, "min": 0.0, "quality": "secondary", "source": SRC_SUMIYA, "low": { "code": "corto", "text": "A 6-8 mg/h no ha dado tiempo a crecer un cristal con el que tallar la funda." } },
		"growth": { "kind": "mg_h", "value": 7.0, "min": 6.0, "max": 8.0, "max_diameter_mm": 12.0, "quality": "secondary", "source": SRC_SUMIYA },
		"pressure_mpa": {
			"value": 5500.0, "min": 0.0, "max": 6000.0, "quality": "secondary", "source": SRC_KENNEDY + "; " + SRC_SUMIYA,
			"low": { "code": "presion", "text": "Por debajo de la línea de Kennedy (P = 19,4 + T/40 kbar) el diamante no es estable: el carbono se queda en grafito." },
		},
		"atmosphere": { "ok": ["vacio", "argon", "aire", "h2_ch4"], "value": "vacio", "source": "la carga va cerrada en una cápsula dentro de la prensa: el gas de fuera no la toca (" + SRC_BALMER + ")", "bad": {} },
		"cool": { "ok": ["horno", "aire"], "value": "horno", "source": SRC_KINGERY + "; " + SRC_MANSON },
		"quality": "secondary", "source": SRC_SUMIYA + "; " + SRC_KENNEDY + "; " + SRC_BALMER,
	},
	"diamante_cvd": {
		"id": "diamante_cvd", "name": "Diamante CVD (funda crecida sobre un molde)", "product": "diamante", "variety": "diamante CVD policristalino", "mode": "sintetizar", "method": "cvd", "form": "capa",
		"powders": [ { "id": "ch4_h2", "value": 1.0, "min": 1.0, "max": 1.0 } ],
		"methane": {
			"value": 0.05, "min": 0.001, "max": 0.1, "quality": "secondary", "source": SRC_BALMER,
			"low": { "code": "mezcla", "text": "Con menos de un 0,1 % de metano casi no llega carbono: no crece." },
			"high": { "code": "mezcla", "text": "Con más de un 10 % de metano el carbono se deposita como hollín y grafito, no como diamante." },
		},
		"temp_c": {
			"value": 900.0, "min": 700.0, "max": 1300.0, "quality": "secondary", "source": SRC_BALMER,
			"low": { "code": "frio", "text": "Con el sustrato por debajo de ~700 °C no crece diamante (sale carbono amorfo)." },
			"high": { "code": "caliente", "text": "Con el sustrato por encima de ~1300 °C se deposita grafito y el diamante se graba." },
		},
		"time_s": { "value": 36000.0, "min": 0.0, "quality": "secondary", "source": SRC_YAN, "low": { "code": "corto", "text": "La capa es más fina que la pared que querías: a ~100 µm/h no ha crecido bastante." } },
		"growth": { "kind": "um_h", "value": 100.0, "min": 50.0, "max": 150.0, "quality": "secondary", "source": SRC_YAN },
		"pressure_mpa": { "value": 0.02, "min": 0.0, "max": 0.101, "quality": "estimate", "source": "el plasma de microondas trabaja a una fracción de la presión del aire (Balmer 2009; cifra de presión no tomada de la fuente: estimación)", "high": { "code": "presion", "text": "A presión de aire o más el plasma de microondas no se mantiene sobre la pieza (estimación)." } },
		"atmosphere": { "ok": ["h2_ch4"], "value": "h2_ch4", "source": SRC_BALMER, "bad": { "aire": { "code": "atmosfera", "text": "El oxígeno quema el diamante que crece (se oxida desde ~600 °C): no queda nada.", "finish": "quemado" }, "argon": { "code": "atmosfera", "text": "Sin hidrógeno ni metano no hay carbono que depositar." }, "vacio": { "code": "atmosfera", "text": "En vacío no hay gas que el plasma pueda romper: no crece nada." } } },
		"substrates": ["tungsteno", "titanio", "molibdeno", "silicio", "diamante"],
		"cool": { "ok": ["horno", "aire"], "value": "horno", "source": SRC_KINGERY + "; " + SRC_MANSON },
		"quality": "secondary", "source": SRC_BALMER + "; " + SRC_YAN,
	},
}

# ════════ Acabado de la pieza ════════
## Lo que la parte de dibujo y de materiales necesita para pintar la pieza (su color y su brillo son de otra unidad).
## Un defecto del horno da el acabado de su receta («finish» en el defecto) o, si no lo dice, «defectuoso».
const FINISH_IDS := ["bruto", "tallado", "pulido", "poroso", "agrietado", "astillado", "quemado", "oxidado", "defectuoso"]
const FINISH_NAMES := {
	"bruto": "En bruto", "tallado": "Tallado", "pulido": "Pulido", "poroso": "Poroso", "agrietado": "Agrietado",
	"astillado": "Astillado", "quemado": "Quemado u oxidado del todo", "oxidado": "Con cascarilla", "defectuoso": "Con defectos",
}

# ════════ Enfriamiento ════════
## Coeficiente de convección de cada medio (W/(m²·K)) para el choque térmico (Manson). «horno»: se enfría con el horno,
## despacio y recociendo; sin salto brusco.
const COOLING := {
	"horno": { "name": "Dentro del horno", "h": 0.0, "quality": "estimate", "source": "enfriamiento controlado con el horno (rampas de " + SRC_BULLSEYE + "): sin choque térmico" },
	"aire": { "name": "Al aire", "h": 15.0, "min": 2.0, "max": 25.0, "quality": "secondary", "source": SRC_INCROPERA + " (convección natural en gases; el mismo de la cetrería)" },
	"aceite": { "name": "En aceite", "h": 23000.0, "quality": "estimate", "source": "el del agua por la relación de severidades de Grossmann, aceite/agua = 0,275/0,95 ≈ 0,29 (" + SRC_GROSSMANN + ")" },
	"agua": { "name": "En agua", "h": 80000.0, "min": 2500.0, "max": 100000.0, "quality": "estimate", "source": "calibrado en el caso medido: con el factor de Manson, una probeta de alúmina de 3 mm (" + SRC_COORSTEK + ") templada en agua aguanta un salto de 201 °C con h = 8·10⁴ W/(m²·K), dentro de lo medido (" + SRC_MORGAN + ") y de la banda de la ebullición (" + SRC_INCROPERA + ")" },
}

# ════════ Abrasivos para tallar y pulir ════════
## grain_um: tamaño de grano por defecto de la muela (o de la pasta al pulir). La geometría de cada grano es la de la
## cetrería (CareData.GRAIN_GEOMETRY: semiángulo de 60°, punta de 5 µm, toca el 10 %). iron_reactive: se gasta
## químicamente contra el acero (SRC_IRON_REACTIVE); el desgaste en números (la relación G) no se modela.
const ABRASIVES := {
	"lima_acero": { "id": "lima_acero", "iron_reactive": false, "name": "Lima de acero", "hv": 700.0, "grain_um": 77.2, "element": "diente", "teeth_cm": 22.0, "quality": "secondary", "source": SRC_ABRASIVES },
	"corindon": { "id": "corindon", "iron_reactive": false, "name": "Muela de corindón", "hv": 2000.0, "grain_um": 91.0, "element": "grano", "quality": "primary", "source": SRC_ABRASIVES },
	"sic": { "id": "sic", "iron_reactive": true, "name": "Muela de carburo de silicio verde", "hv": 2800.0, "grain_um": 91.0, "element": "grano", "quality": "primary", "source": SRC_ABRASIVES },
	"cbn": { "id": "cbn", "iron_reactive": false, "name": "Muela de CBN", "hv": 6322.0, "grain_um": 91.0, "element": "grano", "quality": "primary", "source": SRC_ABRASIVES },
	"diamante": { "id": "diamante", "iron_reactive": true, "name": "Muela o pasta de diamante", "hv": 10000.0, "grain_um": 45.0, "element": "grano", "quality": "primary", "source": SRC_ABRASIVES + "; " + SRC_DMT },
}
## Tamaños de grano para pulir (µm), de grueso a fino (DMT y pastas de diamante).
const POLISH_GRITS := [60.0, 45.0, 25.0, 9.0]
## Velocidad de la muela de tallar por defecto (m/s) y contacto (mm): elección del ensayo (estimación).
const CARVE_DEFAULTS := { "speed_ms": 20.0, "force_n": 10.0, "contact_mm": 3.0, "quality": "estimate", "source": "muela de lapidario de ~20 m/s y contacto de 3 × 3 mm: elección del ensayo" }
## Desconchado del borde (Chai y Lawn 2007): F = β·K_c·d^(3/2).
const EDGE_CHIP_BETA := { "value": 9.0, "quality": "secondary", "source": SRC_CHAI_LAWN }
## Hondura crítica del régimen dúctil (Bifano et al. 1991): d_c = 0,15·(E/H)·(K_c/H)².
const DUCTILE_REGIME_K := { "value": 0.15, "quality": "secondary", "source": SRC_BIFANO }
## Piel que se repasa en una pieza casi terminada (colada, sinterizada o crecida sobre un molde), en mm. Elección.
const FINISH_SKIN_MM := { "value": 0.1, "quality": "estimate", "source": "repaso de 0,1 mm sobre una pieza casi a su forma (elección del ensayo)" }
## La superficie de la pieza al tallarla y al pulirla (unidad 5j; la misma regla que la cetrería, CareData.SURFACE): la Ra
## que deja la última muela o el último grano, Ra = h/4 con la hondura del surco de cada grano (ClawCare.groove_um, con la
## fuerza y el contacto de la máquina), y los desconchones del régimen frágil (más hondo que d_c de Bifano). La pulidora
## aprieta como la muela de serie (elección del ensayo); el rayado va alrededor de la pieza, que se gira contra la muela
## (dibujo); la superficie va en stations estaciones iguales a lo largo de la pieza (dibujo).
const PIECE_SURFACE := {
	"polish_force_n": 10.0, "polish_contact_mm": 3.0, "scratch_deg": 90.0, "stations": 8, "quality": "estimate",
	"source": "Ra = h/4 con la hondura del surco de cada grano, la misma regla que la superficie de la cetrería (estimación, sin medición de piezas talladas así); la pulidora, con la fuerza y el contacto de la muela de serie (10 N, 3 × 3 mm: elección del ensayo); el rayado alrededor de la pieza, dibujo",
}

# ════════ Barreras térmicas sobre la carne viva ════════
## k, rho, cp: conducción y capacidad; max_c: hasta dónde aguanta; water: agua que se evapora (fracción en peso).
const BARRIER_IDS := ["silicona", "aerogel", "gel"]
const BARRIERS := {
	"silicona": { "id": "silicona", "name": "Caucho de silicona", "k": 0.2, "rho": 1150.0, "cp": 1175.0, "max_c": 200.0, "water": 0.0, "quality": "secondary", "source": SRC_SHINETSU + ". Densidad y calor específico: el centro de las bandas" },
	"aerogel": { "id": "aerogel", "name": "Manta de aerogel", "k": 0.024, "rho": 200.0, "cp": 1000.0, "max_c": 650.0, "water": 0.0, "quality": "estimate", "source": SRC_PYROGEL + " (se toma la de 300 °C). Calor específico de una sílice porosa, ~1000 J/(kg·K): estimación" },
	"gel": { "id": "gel", "name": "Gel de agua de joyero", "k": 0.6, "rho": 1000.0, "cp": 4180.0, "max_c": INF, "water": 1.0, "latent_j_kg": 2.257e6, "boil_c": 100.0, "quality": "secondary", "source": SRC_WATER },
}

# ════════ Recubrimientos ════════
## t_c: temperatura de la superficie mientras se recubre; thick_um: espesor que deja; hv: dureza de la capa (null sin
## dato); vacuum: necesita una cámara de vacío (un animal no puede entrar); substrates: materiales de funda que lo
## admiten (vacío: cualquiera); product: material de la capa.
const COATING_IDS := ["ald_alumina", "sputter_alumina", "pvd_tin", "cromo_duro", "plasma_alumina", "cvd_diamante", "esmalte", "fundido"]
const COATINGS := {
	"ald_alumina": {
		"id": "ald_alumina", "name": "Alúmina por capas atómicas (ALD)", "product": "alumina", "t_c": 33.0, "t_min": 33.0, "t_max": 177.0,
		"thick_um": 0.0332, "per_cycle_um": 0.0001107, "hv": null, "vacuum": true, "substrates": [],
		"quality": "secondary", "source": SRC_GRONER,
	},
	"sputter_alumina": {
		"id": "sputter_alumina", "name": "Alúmina por pulverización catódica", "product": "alumina", "t_c": 100.0, "t_min": 20.0, "t_max": 250.0,
		"thick_um": 2.0, "hv": 1134.0, "vacuum": true, "substrates": [],
		"quality": "estimate",
		"source": SRC_SCHNEIDER + "; " + SRC_AMORPHOUS_AL2O3 + "; 12 GPa → 1134 HV (" + SRC_ISO14577 + "). Espesor de 2 µm y sustrato a 100 °C: elección dentro de lo publicado (las capas duras de PVD miden 1-4 µm, " + SRC_BALINIT_A + ")",
	},
	"pvd_tin": {
		"id": "pvd_tin", "name": "Nitruro de titanio por PVD", "product": "tin", "t_c": 400.0, "t_min": 250.0, "t_max": 400.0,
		"thick_um": 3.0, "thick_min": 1.0, "thick_max": 4.0, "hv": 2835.0, "vacuum": true, "substrates": ["acero", "titanio", "tungsteno", "oro"],
		"quality": "secondary", "source": SRC_BALINIT_A + "; " + SRC_ISO14577 + " (30 GPa → 2835 HV)",
	},
	"cromo_duro": {
		"id": "cromo_duro", "name": "Cromo duro galvánico", "product": "cromo", "t_c": 55.0, "t_min": 50.0, "t_max": 65.0,
		"thick_um": 30.0, "thick_min": 20.0, "thick_max": 40.0, "rate_um_h": 25.0, "hv": 900.0, "vacuum": false, "substrates": [],
		"conductive_layer": true, "bath": true,
		"quality": "secondary",
		"source": SRC_HARD_CHROME + ". Sobre lo que no conduce (la queratina, una piedra, una cerámica), antes una capa de pintura conductora (" + SRC_ELECTROFORMING + "). 900 HV: el centro de la banda",
	},
	"plasma_alumina": {
		"id": "plasma_alumina", "name": "Alúmina por proyección de plasma", "product": "alumina", "t_c": 150.0, "t_min": 100.0, "t_max": 500.0,
		"thick_um": 300.0, "thick_min": 200.0, "thick_max": 500.0, "hv": 950.0, "porosity": 0.04, "vacuum": false, "substrates": ["acero", "titanio", "tungsteno"],
		"quality": "estimate", "source": SRC_APS + ". La temperatura del sustrato, 150 °C, es una elección dentro de lo publicado (estimación)",
	},
	"cvd_diamante": {
		"id": "cvd_diamante", "name": "Diamante por CVD", "product": "diamante", "t_c": 900.0, "t_min": 700.0, "t_max": 1300.0,
		"thick_um": 20.0, "hv": 10000.0, "vacuum": true, "substrates": ["tungsteno", "titanio", "diamante"],
		"quality": "secondary", "source": SRC_BALMER,
	},
	"esmalte": {
		"id": "esmalte", "name": "Esmalte vítreo", "product": "vidrio", "t_c": 800.0, "t_min": 750.0, "t_max": 850.0,
		"thick_um": 200.0, "hv": 550.0, "vacuum": false, "substrates": ["oro", "acero", "titanio"],
		"quality": "estimate", "source": SRC_ENAMEL + ". Dureza: la del strass de vidrio del banco (estimación)",
	},
	"fundido": {
		"id": "fundido", "name": "Material fundido vertido encima", "product": "", "t_c": 0.0, "thick_um": 1000.0, "hv": null, "vacuum": false, "substrates": [],
		"quality": "ficcion",
		"source": "FICCIÓN: verter un material fundido sobre una garra. Lo que pasaría: la capa sale a su temperatura de fusión (1064 °C el oro, 2053 °C el zafiro), muy por encima de los ~230 °C a los que se quema la queratina",
	},
}

# ════════ Adhesivos (unión en frío de la funda) ════════
## tau: resistencia al cortante del adhesivo (MPa) en el ensayo de referencia; gap_ideal y gap_max: holguras (mm); wet:
## lo que conserva mojado (fracción).
const ADHESIVE_IDS := ["cianoacrilato", "epoxi", "metacrilato"]
const ADHESIVES := {
	"cianoacrilato": { "id": "cianoacrilato", "name": "Cianoacrilato (pegamento instantáneo)", "tau": 20.0, "tau_min": 12.4, "gap_ideal_min": 0.0, "gap_ideal": 0.05, "gap_max": 0.15, "wet": 0.75, "quality": "secondary", "source": SRC_LOCTITE_401 },
	"epoxi": { "id": "epoxi", "name": "Epoxi de dos componentes", "tau": 14.9, "gap_ideal_min": 0.10, "gap_ideal": 0.15, "gap_max": 3.2, "wet": 1.0, "quality": "secondary", "source": SRC_LOCTITE_GUIDE + ". Mojado: sin dato; se toma 1 (estimación)" },
	"metacrilato": { "id": "metacrilato", "name": "Metacrilato de dos componentes", "tau": 19.4, "gap_ideal_min": 0.25, "gap_ideal": 1.0, "gap_max": 12.7, "wet": 1.0, "quality": "secondary", "source": SRC_LOCTITE_GUIDE + "; el de las prótesis de pico y de las herraduras pegadas (" + CareData.SRC_SAMOUR + "; " + SRC_FERREIRA + "). Mojado: sin dato; se toma 1 (estimación)" },
}
## Soldadura fuerte: no pega la funda a la garra (funde a 618-652 °C y la queratina se quema a ~230 °C); une piezas de metal
## de la funda, como una punta de metal duro sobre una funda de acero. No está en ADHESIVE_IDS (no es un adhesivo).
const BRAZE := {
	"id": "soldadura_fuerte", "name": "Soldadura fuerte de plata", "t_c": 652.0, "t_min": 618.0, "t_max": 652.0,
	"quality": "secondary", "source": SRC_BRAZING,
}
## Cortante que aguanta la queratina bajo la unión: σ/2 (Tresca) por la relación entre capas de la cetrería
## (CareData.INTERLAMINAR, 0,25). Estimación: en las uniones medidas rompe el casco, no el adhesivo (Ferreira 2024).
const KERATIN_SHEAR := {
	"tresca": 0.5, "quality": "estimate",
	"source": "sin medición del cortante entre las láminas de una garra; se toma σ/2 (Tresca) por la relación entre capas de la uña (" + CareData.SRC_FARREN + "), y así la queratina rompe antes que el adhesivo, como en " + SRC_FERREIRA,
}

# ════════ La funda por defecto ════════
## cover_frac: parte del largo de la garra que cubre desde la punta; wall_mm: espesor de pared. Elecciones del ensayo.
const SHEATH := { "cover_frac": 0.4, "wall_mm": 1.0, "quality": "estimate", "source": "funda que cubre el 40 % de la garra desde la punta con 1 mm de pared: elección del ensayo (como una corona dental o un capuchón)" }


# ════════ 5m · la reforja realista: fuentes ════════
const SRC_KERR := "Kerr Corporation (2011), Satin Cast 20 / KerrCast 2000, Directions For Use (lit. 34332A): dejar fraguar los cilindros 2 h antes de quemarlos; ciclos de quemado (solo los mantenimientos, sin las subidas, de ~5 °C/min): el de 5 h para cilindros de 63 × 63 mm, 1 h a 149 °C, 1 h a 371 °C, 2 h a 732 °C («eliminación completa») y 1 h a la temperatura de colada; anillos y piezas finas con el molde a 482-538 °C; «non-fills»: cera mal quemada, molde o metal fríos, poco metal; «porous castings»: cera mal quemada, metal recalentado, molde demasiado caliente"
const SRC_SHOR := "Shor International, «Platinum investment instructions» (revestimiento de fosfato para platino, paladio y los metales de alta temperatura): fraguar al menos 1 h; quemado: hasta 93 °C (200 °F) la primera hora, hasta 177 °C (350 °F) la media hora siguiente, 2 h hasta 871 °C (1600 °F) y 1 h a 871 °C"
const SRC_SRS := "SRS-Goodwin Refractory Services, «Burnout guidelines & casting temperatures»: el acero inoxidable se cuela a 1625-1675 °C con el molde a 750-900 °C; el molde se mantiene al menos 1 h a la temperatura de colada para que su centro llegue a ella"
const SRC_BULLSEYE_TS8 := "Bullseye Glass Co., TipSheet 8 «Basic lost wax kilncasting»: molde de dos capas de yeso n.º 1 y harina de sílice (la sílice se dilata al cocerse y compensa el yeso, que encoge); la cera se saca con vapor; el molde se cura envuelto 24-48 h; ciclo típico: 55 °C/h hasta 93 °C y 6 h; 55 °C/h hasta 677 °C y 2 h; 333 °C/h hasta 830 °C y 3 h; lo que enfríe solo el horno cerrado hasta 596-677 °C y 4 h; 27,7 °C/h hasta 482 °C y 6 h; 6,7 °C/h hasta 427 °C; 12 °C/h hasta 371 °C; 40 °C/h hasta 21 °C; un día a la temperatura ambiente antes de desmoldar; el depósito se corta con una sierra de agua con disco de diamante"
const SRC_HOLLENBACK := "Hollenback GM, Skinner EW (1946). Shrinkage during casting of gold and gold alloys. J. Am. Dent. Assoc. 33:1391-1399, doi:10.14219/jada.archive.1946.0210: el oro puro encoge un 1,67 ± 0,02 % lineal al colarse (como lo recoge la literatura de la colada dental)"
const SRC_FERREIRA_TI := "Ferreira AR, Adabo GL, Peitl Filho O, Soares da Rocha S, Fonseca RG (2007). Evaluation of the thermal shrinkage of titanium and the setting and thermal expansion of phosphate-bonded investments. J. Prosthet. Dent. 98(1):24-29, doi:10.1016/S0022-3913(07)60034-1: la contracción del titanio de la fusión a la temperatura ambiente, calculada con su dilatación, 1,55 %; un revestimiento de fosfato llega a esa dilatación con su líquido al 100 % a 594 °C; el de control, específico del titanio, con el molde a 430 °C"
const SRC_HSU := "Hsu HC, Kikuchi H, Yen SK, Nishiyama M (2007). Evaluation of different bonded investments for dental titanium casting. J. Mater. Sci. Mater. Med. 18(4):605-609, doi:10.1007/s10856-007-2308-2: el revestimiento de fosfato se dilata un 2,10 % al fraguar con su líquido, bastante para compensar la contracción del titanio"
const SRC_EARNSHAW := "Earnshaw R (1988). The effect of casting ring liners on the potential expansion of a gypsum-bonded investment. J. Dent. Res. 67(11):1366-1370, doi:10.1177/00220345880670110101: dilatación total (al fraguar y al calentarse) de un revestimiento de yeso, 1,7 %; con forros de cerámica secos, 1,6-1,7 %; y Finger W, Jørgensen KD (1980), Scand. J. Dent. Res. 88:278-284: un revestimiento de yeso con un 1,7 % de dilatación térmica"
const SRC_CAMPBELL := "Campbell J, Harding RA (1994). TALAT Lecture 3206, The feeding of castings (European Aluminium Association): la regla de Chvorinov (lo que tarda en solidificar crece con el módulo, el volumen entre la superficie que enfría); el módulo del bebedero tiene que ser mayor que el de la pieza, normalmente Mf = 1,2·Mc; un cilindro largo de diámetro d tiene un módulo d/4 y una placa de espesor t, t/2"
const SRC_SABAU := "Sabau AS, Cannell N (2005). Predicting pattern tooling and casting dimensions for investment casting, phase II. Oak Ridge National Laboratory: la industria hace el molde de la cera más grande que la pieza para compensar lo que cambian de tamaño la cera y la aleación"
const SRC_GENIE := "Diamond Pacific, Genie (máquina de lapidario de seis muelas en fila): muelas de diamante de 6\" de 80 y 220 de liga metálica y de 280, 600, 1200 y 3000 de resina, y un disco de 14 000; motor de 1/2 CV a 1800 rpm y bomba de agua (fichas de los distribuidores, p. ej., Kingsley North)"
const SRC_HITECH_SAW := "Hi-Tech Diamond, sierra de recortar de 6\" (ficha de los distribuidores): disco de diamante de 6\" × 0,012-0,015\" (0,30-0,38 mm) de canto, motor de 1/4 CV de 800 a 3400 rpm y depósito de agua de 16 oz; corta corindón, rubí, cuarzo y vidrio"
const SRC_FOREDOM := "Foredom, motor SR de eje flexible, el del joyero: 1/6 CV, de 500 a 18 000 rpm"
const SRC_HAEFELI := "Haefeli Diamantwerkzeugfabrik, «Grit sizes» (FEPA e ISO 6106): D181, 150-180 µm; D126, 106-125 µm; D91, 75-90 µm; D76, 63-75 µm; D46, 38-45 µm; una muela de grano 80 es del orden de D181 y una de 220, de D76"
const SRC_DOP := "La pieza se talla pegada en un palo (el «dop») con cera de lapidario, que se calienta con la pieza a ~65 °C (la cera verde de baja temperatura) y se aprieta contra su base (guías de lapidario: Rockhound Resource, «Dopping a stone with wax»; United States Faceters Guild, «Dopping»)"
const SRC_FUSED_CAST := "Los refractarios de alúmina electrofundida se funden en un horno de arco, se cuelan en moldes de arena y se recuecen (patente US 4.943.398, Toshiba Monofrax, 1990): son ladrillos de horno con poros, no piezas finas"

# ════════ 5m · cada máquina y cómo se carga ════════
## Petición 42: «echar los materiales dentro de la máquina». Cada modo del horno es una máquina real y cada una se carga a su
## manera: charge, lo que entra («alimentador», «capsula», «sustrato», «pastilla», «crisol» o «pieza»; en el horno de
## calentar entra también el molde de la cera perdida, para quemarla); where, dónde va; close, cómo se cierra. Es
## procedimiento: la interfaz no arranca sin la carga dentro (ClawForge.load_machine), con la fuente de la máquina de verdad.
const MACHINES := {
	"verneuil": { "id": "verneuil", "name": "Soplete de Verneuil", "charge": "alimentador", "charge_name": "La alúmina, en la tolva", "where": "arriba del soplete: un martillo golpea la tolva y el polvo cae poco a poco por la llama de oxígeno e hidrógeno sobre la semilla", "close": "se tapa la tolva y la semilla sube hasta la llama", "quality": "secondary", "source": SRC_VERNEUIL },
	"hpht": { "id": "hpht", "name": "Prensa de alta presión (HPHT)", "charge": "capsula", "charge_name": "La cápsula", "where": "entre los yunques de la prensa: el grafito, el disolvente de hierro y cobalto y una semilla de diamante, cerrados en su cápsula", "close": "los yunques bajan y aprietan la cápsula", "quality": "secondary", "source": SRC_SUMIYA },
	"cvd": { "id": "cvd", "name": "Reactor de plasma (CVD)", "charge": "sustrato", "charge_name": "El sustrato", "where": "sobre el calentador, bajo la campana: un molde de molibdeno, wolframio o silicio con la forma de la funda", "close": "baja la campana y se hace el vacío antes de dejar entrar el hidrógeno con el metano", "quality": "secondary", "source": SRC_BALMER },
	"sinterizado": { "id": "sinterizado", "name": "Horno de sinterizar", "charge": "pastilla", "charge_name": "La pastilla prensada", "where": "en su bandeja, dentro del horno: el polvo prensado con la forma de la funda, más grande, porque encoge al sinterizar", "close": "se cierra la puerta del horno", "quality": "secondary", "source": SRC_GC_GUIDE + "; " + SRC_COBLE },
	"induccion": { "id": "induccion", "name": "Horno de inducción", "charge": "crisol", "charge_name": "El crisol", "where": "dentro de la bobina de inducción, que calienta el metal sin tocarlo", "close": "se cierra la tapa", "quality": "secondary", "source": SRC_STEEL_POUR },
	"colada": { "id": "colada", "name": "Horno de fundir y colar", "charge": "crisol", "charge_name": "El crisol", "where": "en el horno, junto al molde", "close": "se cierra la puerta", "quality": "secondary", "source": SRC_KERR + "; " + SRC_BULLSEYE_TS8 },
	"calentar": { "id": "calentar", "name": "Horno de calentar", "charge": "pieza", "charge_name": "La pieza", "where": "en la bandeja del horno", "close": "se cierra la puerta", "quality": "ficcion", "source": FURNACE.source },
}
## Lo que entra en cada máquina, en palabras (los del molde y de la pieza, en el horno de calentar).
const CHARGE_NAMES := { "alimentador": "la alúmina, en la tolva", "capsula": "la cápsula", "sustrato": "el sustrato", "pastilla": "la pastilla prensada", "crisol": "el crisol", "molde": "el molde revestido", "pieza": "la pieza" }

# ════════ 5m · la colada con la forma de la garra (la cera perdida) ════════
## Lo que encoge cada material al colarse (fracción lineal, de la colada a la temperatura ambiente). El oro, medido; el titanio,
## calculado con su dilatación del sólido a la temperatura ambiente (Ferreira 2007); el acero 304 y el vidrio, con el mismo
## método y la dilatación de su ficha (estimación: la dilatación de 0-100 °C crece con la temperatura, así que se quedan cortos).
const CAST := {
	"oro": { "shrink": { "value": 0.0167, "min": 0.0165, "max": 0.0169, "quality": "secondary", "source": SRC_HOLLENBACK } },
	"titanio": { "shrink": { "value": 0.0155, "quality": "secondary", "source": SRC_FERREIRA_TI } },
	"acero": { "shrink": { "value": 17.3e-6 * (1399.0 - 20.0), "quality": "estimate", "source": "el método de Ferreira et al. (2007) para el titanio (la contracción del sólido, de la temperatura de solidificación a la ambiente, con su dilatación) con la ficha del 304: 17,3·10⁻⁶ 1/K × (1399 − 20) °C = 2,39 % (" + SRC_AK304 + "). Estimación: la dilatación crece con la temperatura" } },
	"vidrio": { "shrink": { "value": 9.0e-6 * (546.0 - 20.0), "quality": "estimate", "source": "lo que encoge el vidrio desde su punto de recocido, donde deja de fluir, hasta la temperatura ambiente: 9·10⁻⁶ 1/K × (546 − 20) °C = 0,47 % (" + SRC_EN572 + "; " + SRC_ABRISA + "). Estimación" } },
}
## Lo que no se cuela en un taller, y por qué (por material de la receta o de la piedra comprada).
const NO_CAST := {
	"zafiro": "El zafiro no se cuela en un taller: funde a 2053 °C, más que cualquier molde de taller, y colado sale policristalino y lleno de poros. El de una garra es un cristal que crece desde el fundido (Verneuil): se talla con muelas de diamante.",
	"rubi": "El rubí no se cuela en un taller: es corindón, que funde a 2053 °C y colado sale policristalino y lleno de poros. Crece como cristal a la llama (Verneuil) y se talla con muelas de diamante.",
	"alumina": "La alúmina no se cuela en un taller: funde a 2053 °C. La industria la funde con arco y la cuela en arena, pero sale como un ladrillo de horno, con poros. Las piezas de alúmina se prensan y se sinterizan, y se repasan con diamante.",
	"tungsteno": "El metal duro no se funde ni se cuela: es carburo de tungsteno pegado con cobalto, prensado y sinterizado en fase líquida.",
	"diamante": "El diamante no funde: al aire se quema desde ~600 °C y a baja presión se vuelve grafito. Se sintetiza (HPHT o CVD) y se talla con diamante.",
	"cuarzo": "El cuarzo no se cuela en un taller: fundido y enfriado sale vidrio de sílice, no cuarzo. Se compra y se talla.",
	"circonita": "La circonita funde a ~2750 °C: se cultiva por fusión en cráneo en la industria y se compra para tallarla.",
	"moissanita": "La moissanita no funde: se disocia hacia los 2700 °C. Se cultiva por sublimación y se compra para tallarla.",
	"hematites": "La hematites es un mineral natural: se compra y se talla.",
	"swarovski": "El cristal comprado ya viene tallado de fábrica: se repasa con diamante.",
	"acrilico": "El acrílico dental no se cuela en el laboratorio: se mezcla y se aplica sobre lo que queda de la garra, en la cetrería.",
}
const NO_CAST_SOURCE := SRC_SG_SAPPHIRE + "; " + SRC_VERNEUIL + "; " + SRC_FUSED_CAST + "; " + SRC_WC_SINTER + "; " + SRC_BALMER + "; " + SRC_NASSAU_CZ + "; " + SRC_SIC_DISSOC
## Los revestimientos: lo que se dilatan (al fraguar y al calentarse: compensa lo que encoge el metal), lo que fraguan antes de
## quemarlos y lo que aguantan. El grafito no se reviste: es un molde mecanizado.
const INVESTMENTS := {
	"yeso": { "id": "yeso", "name": "Revestimiento de yeso con cristobalita", "expansion": { "value": 0.016, "min": 0.016, "max": 0.017, "quality": "secondary", "source": SRC_EARNSHAW }, "set_s": { "value": 7200.0, "quality": "secondary", "source": SRC_KERR }, "machined": false },
	"ceramico": { "id": "ceramico", "name": "Revestimiento de fosfato", "expansion": { "value": 0.021, "quality": "secondary", "source": SRC_HSU + "; se ajusta con la concentración de su líquido (" + SRC_FERREIRA_TI + ")" }, "set_s": { "value": 3600.0, "quality": "secondary", "source": SRC_SHOR }, "machined": false },
	"grafito": { "id": "grafito", "name": "Molde de grafito mecanizado", "expansion": { "value": 0.0, "quality": "estimate", "source": "un molde mecanizado no se dilata al fraguar: se hace más grande lo que encoge el metal (" + SRC_SABAU + ")" }, "set_s": { "value": 0.0, "quality": "estimate", "source": "no fragua: se mecaniza" }, "machined": true },
}
## El molde del vidrio: yeso y harina de sílice (Bullseye), sin dilatación neta, y su curado.
const GLASS_INVESTMENT := { "id": "yeso", "name": "Molde de yeso y harina de sílice", "expansion": { "value": 0.0, "quality": "estimate", "source": SRC_BULLSEYE_TS8 + ". Sin cifra de la dilatación neta: se toma 0, porque la sílice compensa el yeso (estimación)" }, "set_s": { "value": 86400.0, "min": 86400.0, "max": 172800.0, "quality": "secondary", "source": SRC_BULLSEYE_TS8 }, "machined": false }
## El quemado de la cera: los tramos del ciclo, cada uno { to (°C; «top»: el de arriba, el que se programa con los diales),
## ramp_s (lo que dura la subida; si no, con rate_c_s), hold_s (el mantenimiento; en el de arriba, el que se programa) }, la
## temperatura mínima de arriba (la que quema la cera del todo), la máxima que aguanta el molde, el mantenimiento mínimo de
## arriba y la subida por defecto (~5 °C/min, la de Kerr). El molde queda después a su temperatura de colada (MOLD_C).
const BURNOUT := {
	"yeso": {
		"name": "ciclo de quemado de 5 h del revestimiento de yeso (cilindro de 63 × 63 mm)",
		"segments": [{ "to": 149.0, "hold_s": 3600.0 }, { "to": 371.0, "hold_s": 3600.0 }, { "to": "top", "hold_s": "top" }],
		"top_c": 732.0, "top_min_c": 732.0, "top_max_c": 816.0, "top_hold_s": 7200.0, "rate_c_s": 5.0 / 60.0,
		"quality": "secondary", "source": SRC_KERR + "; " + SRC_GYPSUM,
	},
	"ceramico": {
		"name": "quemado del revestimiento de fosfato",
		"segments": [{ "to": 93.0, "ramp_s": 3600.0, "hold_s": 0.0 }, { "to": 177.0, "ramp_s": 1800.0, "hold_s": 0.0 }, { "to": "top", "ramp_s": 7200.0, "hold_s": "top" }],
		"top_c": 871.0, "top_min_c": 871.0, "top_max_c": INF, "top_hold_s": 3600.0, "rate_c_s": 5.0 / 60.0,
		"quality": "secondary", "source": SRC_SHOR,
	},
	"vidrio": {
		"name": "secado y curado del molde de yeso y sílice en el horno",
		"segments": [{ "to": 93.0, "rate_c_s": 55.0 / 3600.0, "hold_s": 21600.0 }, { "to": "top", "rate_c_s": 55.0 / 3600.0, "hold_s": "top" }],
		"top_c": 677.0, "top_min_c": 677.0, "top_max_c": 843.0, "top_hold_s": 7200.0, "rate_c_s": 55.0 / 3600.0,
		"quality": "secondary", "source": SRC_BULLSEYE_TS8,
	},
}
## La temperatura del molde al colar cada material (°C), y su margen si la fuente lo da (frío: no llena; caliente: poros).
const MOLD_C := {
	"oro": { "value": 510.0, "min": 482.0, "max": 538.0, "quality": "secondary", "source": SRC_KERR },
	"acero": { "value": 871.0, "min": 750.0, "max": 900.0, "quality": "secondary", "source": SRC_SRS + "; " + SRC_SHOR },
	"titanio": { "value": 430.0, "quality": "secondary", "source": SRC_FERREIRA_TI },
	"vidrio": { "value": 677.0, "quality": "secondary", "source": SRC_BULLSEYE_TS8 + " (el molde se calienta con el vidrio)" },
}
## El recocido del vidrio colado, desde la temperatura del proceso (Bullseye): cada tramo { to (°C), rate_c_s (la bajada; 0: la
## que haga el horno cerrado solo, sin cifra), hold_s }.
const ANNEAL_GLASS := {
	"segments": [{ "to": 636.5, "rate_c_s": 0.0, "hold_s": 14400.0 }, { "to": 482.0, "rate_c_s": 27.7 / 3600.0, "hold_s": 21600.0 },
		{ "to": 427.0, "rate_c_s": 6.7 / 3600.0, "hold_s": 60.0 }, { "to": 371.0, "rate_c_s": 12.0 / 3600.0, "hold_s": 60.0 },
		{ "to": 21.0, "rate_c_s": 40.0 / 3600.0, "hold_s": 60.0 }],
	"quality": "secondary", "source": SRC_BULLSEYE_TS8 + ". La primera bajada, la que haga el horno cerrado solo, no se cuenta (sin cifra); el mantenimiento contra los rechupes, en el centro de 596-677 °C",
}
## El bebedero: su módulo, 1,2 veces el de la pieza (Chvorinov y Campbell); su largo (dibujo) y lo que deja la sierra al
## cortarlo, para limarlo (elección del juego).
const SPRUE := {
	"modulus_factor": { "value": 1.2, "quality": "secondary", "source": SRC_CAMPBELL },
	"length_mm": { "value": 8.0, "quality": "dibujo", "source": "el largo del bebedero: dibujo" },
	"stub_mm": { "value": 0.5, "quality": "estimate", "source": "lo que deja la sierra al cortar el bebedero, para limarlo: elección del juego (sin medición publicada)" },
	"misrun_fill": { "value": 0.55, "quality": "dibujo", "source": "lo que se ve llenarse el molde en una colada fría: dibujo (el motor solo dice que no llena)" },
}

# ════════ 5m · el tallado por pasadas: las herramientas del lapidario ════════
## role: «cortar» (la sierra saca el tocho o corta el bebedero), «desbastar», «vaciar» (la fresa vacía la funda por dentro),
## «formar» o «pulir» (la pulidora es ClawForge.polish). grain_um, el grano (D de FEPA/ISO 6106); speed_ms, la del borde con
## las rpm de su máquina de ficha; layer_mm, lo que quita una pasada de lo que sobra sobre la silueta (la fresa, depth_mm de
## hueco): elecciones del juego, sin medición publicada (el lapidario la ajusta a ojo). La pieza va pegada en un palo (SRC_DOP).
const CARVE_TOOL_IDS := ["sierra", "muela_gruesa", "fresa", "muela_fina", "pulidora"]
const CARVE_TOOLS := {
	"sierra": { "id": "sierra", "name": "Sierra de disco de diamante", "short": "Sierra", "role": "cortar", "grain_um": 181.0, "speed_ms": PI * 0.1524 * 3400.0 / 60.0, "kerf_mm": 0.38, "machine": "sierra de recortar de 6\" con su bandeja de agua", "quality": "estimate", "source": SRC_HITECH_SAW + ". Sin ficha del grano del borde: se toma el de la muela gruesa (D181), estimación" },
	"muela_gruesa": { "id": "muela_gruesa", "name": "Muela de diamante gruesa (grano 80)", "short": "Muela gruesa", "role": "desbastar", "grain_um": 181.0, "speed_ms": PI * 0.1524 * 1800.0 / 60.0, "layer_mm": 1.0, "machine": "máquina de muelas de 6\" en fila con su goteo de agua", "quality": "secondary", "source": SRC_GENIE + "; " + SRC_HAEFELI + ". La capa de cada pasada, elección del juego" },
	"fresa": { "id": "fresa", "name": "Fresa de diamante del eje flexible", "short": "Fresa", "role": "vaciar", "grain_um": 91.0, "speed_ms": PI * 0.003 * 18000.0 / 60.0, "depth_mm": 5.0, "machine": "eje flexible de joyero con una fresa de diamante de 3 mm", "quality": "estimate", "source": SRC_FOREDOM + ". Una fresa de 3 mm de grano medio (~D91): estimación, sin ficha; la hondura de cada pasada, elección del juego" },
	"muela_fina": { "id": "muela_fina", "name": "Muela de diamante fina (grano 220)", "short": "Muela fina", "role": "formar", "grain_um": 76.0, "speed_ms": PI * 0.1524 * 1800.0 / 60.0, "layer_mm": 0.25, "machine": "máquina de muelas de 6\" en fila con su goteo de agua", "quality": "secondary", "source": SRC_GENIE + "; " + SRC_HAEFELI + ". La capa de cada pasada, elección del juego" },
	"pulidora": { "id": "pulidora", "name": "Pulidora: disco de fieltro o de cuero con pasta de diamante", "short": "Pulidora", "role": "pulir", "machine": "pulidora con su disco de fieltro y la pasta", "quality": "secondary", "source": SRC_GENIE + "; " + SRC_DMT },
}
## Una pasada suave quita esta parte de la capa (o del hueco) de una normal; la forma es la de la garra cuando lo que sobra
## o lo que falta no pasa de SHAPE_TOL (a ojo con la plantilla). Elecciones del juego.
const CARVE_LIGHT := { "value": 0.25, "quality": "estimate", "source": "una pasada suave quita la cuarta parte de una normal: elección del juego" }
const SHAPE_TOL := { "value": 0.05, "quality": "estimate", "source": "lo que se ve a ojo contra la plantilla de la silueta: elección del juego" }
## Al enfriar al aire, en aceite o en agua, cuánto tarda de verdad (estimación de capacidad concentrada, τ = ρ·c·V/(h·A), con los
## coeficientes de COOLING) hasta que se puede coger con la mano (elección: 50 °C).
const COOL_HANDLE_C := { "value": 50.0, "quality": "estimate", "source": "la temperatura a la que la pieza ya se puede coger: elección del juego" }


# ════════ Funciones de acceso ════════

## La receta (copia) o {} si no existe.
static func recipe(id: String) -> Dictionary:
	return (RECIPES.get(id, {}) as Dictionary).duplicate(true)


## Los datos térmicos del material (copia) o {} si no hay.
static func material(id: String) -> Dictionary:
	return (MATERIALS.get(id, {}) as Dictionary).duplicate(true)


## La entrada del material de la garra: la de Data.INLAYS, la nueva de la 2.0 o la de la prótesis de verdad (PROSTHESIS)
## (copia); null si no existe.
static func inlay_entry(id: String) -> Variant:
	var e: Variant = Data.find_by_id(Data.INLAYS, id)
	if e != null:
		return (e as Dictionary).duplicate(true)
	if NEW_MATERIALS.has(id):
		return (NEW_MATERIALS[id] as Dictionary).duplicate(true)
	if PROSTHESIS.has(id):
		return (PROSTHESIS[id] as Dictionary).duplicate(true)
	return null


## La entrada de un material de la prótesis de verdad (PROSTHESIS; copia) o null.
static func prosthesis_entry(id: String) -> Variant:
	return (PROSTHESIS[id] as Dictionary).duplicate(true) if PROSTHESIS.has(id) else null


## Densidad (kg/m³) del material: la de claw_mass.gd o la de NEW_MATERIALS; null sin dato.
static func density_of(id: String) -> Variant:
	var d: Variant = ClawMass.density_of(id)
	if d != null:
		return float(d.value)
	if NEW_MATERIALS.has(id):
		return float(NEW_MATERIALS[id].density)
	if PROSTHESIS.has(id):
		return float(PROSTHESIS[id].density)
	return null


## Resistencia del material como la de ClawFracture.strength() (para ClawSharpness), con la alúmina nueva; null sin dato.
static func strength_of(id: String) -> Variant:
	var s: Variant = ClawFracture.strength(id)
	if s != null:
		return s
	if NEW_MATERIALS.has(id):
		var m: Dictionary = NEW_MATERIALS[id]
		return { "value": m.strength_mpa, "min": m.strength_min, "max": m.strength_max, "kind": "flexion", "kic": m.kic, "family": "ceramica" if id == "alumina" else "cristal", "quality": m.quality, "source": m.source }
	if PROSTHESIS.has(id):
		var q: Dictionary = PROSTHESIS[id]
		return { "value": q.strength_mpa, "min": q.strength_min, "max": q.strength_max, "kind": "flexion", "kic": q.kic, "family": "polimero", "quality": q.quality, "source": q.source }
	return null


## ¿Está el material en el catálogo del banco? El de la 2.0, Catalog.INLAYS: los de la 1.x (Data.INLAYS) y los nuevos de la
## reforja (NEW_MATERIALS, que Catalog.V2_INLAYS toma tal cual; sin cargar catalog.gd, que ya carga este archivo: un test
## comprueba que dicen lo mismo).
static func in_bench(id: String) -> bool:
	return id != "none" and (Data.find_by_id(Data.INLAYS, id) != null or NEW_MATERIALS.has(id))


## El material del banco con la misma mecánica (el propio si ya está; el gemelo de NEW_MATERIALS, o «» si no hay).
static func bench_twin(id: String) -> String:
	if in_bench(id):
		return id
	if NEW_MATERIALS.has(id):
		return String(NEW_MATERIALS[id].bench_twin)
	return ""
