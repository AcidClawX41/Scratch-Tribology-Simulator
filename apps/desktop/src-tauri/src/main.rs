// Oculta la consola en Windows en builds de release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    let context = tauri::generate_context!();

    #[cfg(target_os = "linux")]
    linux::nvidia_dmabuf_workaround();
    #[cfg(target_os = "linux")]
    linux::appimage_gstreamer_registry(&context.config().identifier);

    tauri::Builder::default()
        // Recuerda tamaño, posición y maximizado de la ventana entre sesiones (como una app nativa).
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .run(context)
        .expect("error al arrancar Scratch Tribology Simulator");
}

#[cfg(target_os = "linux")]
mod linux {
    use std::{
        env,
        path::{Path, PathBuf},
    };

    /// WebKitGTK con el driver propietario de NVIDIA puede dejar la ventana en blanco o parpadeando
    /// con su renderizador DMA-BUF. Solo si hay una GPU NVIDIA con su driver cargado y el usuario no
    /// ha elegido ya: respeta `WEBKIT_DISABLE_DMABUF_RENDERER` si existe y se puede desactivar con
    /// `STS_KEEP_DMABUF=1`. Con Mesa (AMD, Intel, Nouveau) no se toca nada.
    pub fn nvidia_dmabuf_workaround() {
        let nvidia = Path::new("/proc/driver/nvidia/version").exists();
        if nvidia
            && env::var_os("WEBKIT_DISABLE_DMABUF_RENDERER").is_none()
            && env::var_os("STS_KEEP_DMABUF").is_none()
        {
            // Al principio de main, antes de crear ningún hilo: modificar el entorno es seguro aquí.
            env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
    }

    /// El AppImage lleva su propio GStreamer, con solo los plugins del Web Audio (docs/AUDIO-NATIVO.md).
    /// Sin esto guardaría su registro de plugins en el mismo archivo que el GStreamer del sistema
    /// (`~/.cache/gstreamer-1.0/registry.<arch>.bin`), que se quedaría con esos pocos plugins, y el
    /// siguiente programa que use GStreamer tendría que volver a examinar todos los suyos. Solo dentro
    /// del AppImage y si nadie ha elegido otro registro (`GST_REGISTRY_1_0`): el `.deb` y el `.rpm`
    /// usan el GStreamer del sistema y su registro de siempre.
    pub fn appimage_gstreamer_registry(identifier: &str) {
        if !inside_appimage() || env::var_os("GST_REGISTRY_1_0").is_some() {
            return;
        }
        if let Some(cache) = cache_dir() {
            let registry = cache
                .join(identifier)
                .join("gstreamer-1.0")
                .join(format!("registry.{}.bin", env::consts::ARCH));
            // Al principio de main, antes de crear ningún hilo. GStreamer crea la carpeta al guardarlo.
            env::set_var("GST_REGISTRY_1_0", registry);
        }
    }

    /// El lanzador del AppImage pone en `APPDIR` la carpeta donde lo ha montado, y el ejecutable está
    /// dentro: así no cuenta un `APPDIR` heredado de otro AppImage.
    fn inside_appimage() -> bool {
        match (env::var_os("APPDIR"), env::current_exe()) {
            (Some(dir), Ok(exe)) => exe.starts_with(dir),
            _ => false,
        }
    }

    /// Caché del usuario según XDG: `$XDG_CACHE_HOME` si es una ruta absoluta; si no, `~/.cache`.
    fn cache_dir() -> Option<PathBuf> {
        env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .filter(|dir| dir.is_absolute())
            .or_else(|| env::var_os("HOME").map(|home| Path::new(&home).join(".cache")))
    }
}
