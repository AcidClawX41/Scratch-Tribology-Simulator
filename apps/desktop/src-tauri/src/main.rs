// Oculta la consola en Windows en builds de release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    #[cfg(target_os = "linux")]
    linux::nvidia_dmabuf_workaround();

    tauri::Builder::default()
        // Recuerda tamaño, posición y maximizado de la ventana entre sesiones (como una app nativa).
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .run(tauri::generate_context!())
        .expect("error al arrancar Scratch Tribology Simulator");
}

#[cfg(target_os = "linux")]
mod linux {
    use std::{env, path::Path};

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
            // Primera línea de main, antes de crear ningún hilo: modificar el entorno es seguro aquí.
            env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
    }
}
