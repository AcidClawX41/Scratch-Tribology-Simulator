<!-- Plantilla de las notas de cada Release. release.yml sustituye {{VERSION}} (la etiqueta) y {{REPO}}
     (propietario/repositorio). Actualiza «Highlights» con cada versión nueva. -->
<p align="center">
  <img src="https://github.com/{{REPO}}/raw/{{VERSION}}/docs/img/banner.png" alt="Scratch Tribology Simulator: what scratches what, and why" width="100%">
</p>

## Scratch Tribology Simulator {{VERSION}}

An educational contact-mechanics and tribology lab. Human nails, animal claws and viper fangs are tested
against materials from human skin to diamond, using published physical models and measured data. Every
equation and its source is in the [README](https://github.com/{{REPO}}#the-physics-models-and-equations)
and in [`docs/FISICA.md`](https://github.com/{{REPO}}/blob/{{VERSION}}/docs/FISICA.md).

### What's new in 1.0.1

- **Sound on Linux.** The 1.0.0 AppImage was silent on every distribution: its launcher pointed GStreamer at a
  plugin folder that wasn't there (tauri-apps/tauri#15665). The AppImage now carries only the GStreamer plugins that
  Web Audio needs (8.6 MB instead of ~35 MB with all of them). The `.deb` requires the system plugins and the `.rpm`
  recommends them, so it still installs on openSUSE.
- **Licences:** the libraries inside the AppImage, with their exact versions, are listed in
  `…_linux-appimage-licenses.txt`, attached to this release.
- **Recent Mesa (Ubuntu 26.04, Fedora 44):** the AppImage is built with the linuxdeploy that Tauri 2.12 will ship,
  which leaves out the bundled `libwayland-client` that made it abort with `EGL_BAD_PARAMETER`
  (tauri-apps/tauri#15976). Tested in containers without a GPU; if it still fails on your machine, use the `.deb` or
  the `.rpm`.

### Highlights

- **Cars, perforated for real:** classic mild steel (~0.9 mm), modern bake-hardening steel (0.7 mm),
  aluminium (1.0 mm) and a plastic wing (~2.5 mm), all under the same OEM paint. A tip first scratches
  the paint, then perforates the panel. With enough energy the whole claw goes through as the hole opens
  in petals (Wierzbicki 1999).
- **Window glass that breaks in bending** (Roark; EN 572-1). A cat's swipe doesn't break a window; a
  bear's does.
- **Layered human skin:** stratum corneum, epidermis, dermis, fat, fascia and muscle, with in-vivo and
  cadaver data. Results range from white scratches to deep lacerations, and each one reports the layer
  reached and whether it bleeds.
- **Dual mode:** the same test on an old and a modern car, with a damage report in millimetres and
  centimetres.
- **Experiments:** solid steel, titanium, sapphire and diamond nails, the Stiletto XL, and claws reforged
  in steel, tungsten carbide, sapphire or diamond.
- **Physics model v2.4:** sphero-conical tips, Hertz contact, real pressure capped by hardness, strikes
  as an energy balance, and no tool sinking deeper than its own length.
- An interface with illustrations, cross-sections and 22 toggleable sound effects, plus an iPhone and
  Android app.

### Downloads

| Platform | File | First launch |
|---|---|---|
| Windows 10/11 | `…_x64-setup.exe` (or `…_x64_en-US.msi`) | Not code-signed: SmartScreen → *More info* → *Run anyway* |
| macOS · Apple Silicon (M1 and later) | `…_aarch64.dmg` | Not notarized: open it once, then *System Settings → Privacy & Security → Open Anyway* |
| macOS · Intel | `…_x64.dmg` | Same as above |
| Linux | `…_amd64.AppImage` (portable executable) · `.deb` · `.rpm` | AppImage: `chmod +x` and run it. NVIDIA users: see `apps/desktop/README.md` |
| Android 7.0+ | `…_android.apk` | Allow *Install unknown apps* for your browser or file manager |
| iPhone / iPad (iOS 15.1+) | `…_ios-unsigned.ipa` | Unsigned: install it with **AltStore** or **Sideloadly**, which sign it with your Apple ID (free accounts must reinstall every 7 days) |

The interface is in Spanish. The apps need no network connection: fonts are bundled, and there is no
analytics or any other external call.

### Verified before release

- 121 automated tests, including 40 golden reference scenarios, physical invariants and packaging checks.
- A sweep of the whole catalogue: 603,228 runs with no broken result.
- CI on every change: the desktop frontend, the native shell (`rustfmt`, `clippy`), and the mobile app's
  smoke test and Metro bundle for Android and iOS.

Built automatically by GitHub Actions (`.github/workflows/release.yml`) from tag `{{VERSION}}`.

Scratch Tribology Simulator is © 2026 Eric Valls Gramunt and released under the
[MIT License](https://github.com/{{REPO}}/blob/{{VERSION}}/LICENSE). Bundled fonts and libraries keep their own
licenses: see [THIRD-PARTY-NOTICES.md](https://github.com/{{REPO}}/blob/{{VERSION}}/THIRD-PARTY-NOTICES.md).
