mod metadata;

use metadata::{read_image_metadata, write_image_metadata, ImageMetadata};
use std::path::PathBuf;

// Fungsi untuk membaca metadata
#[tauri::command]
async fn read_metadata(path: String) -> Result<ImageMetadata, String> {
    let path = PathBuf::from(path);
    read_image_metadata(&path).map_err(|e| e.to_string())
}

// Fungsi untuk menulis metadata
#[tauri::command]
async fn write_metadata(path: String, metadata: ImageMetadata) -> Result<(), String> {
    let path = PathBuf::from(path);
    write_image_metadata(&path, &metadata).map_err(|e| e.to_string())
}

// Fungsi untuk mendapatkan info platform
#[tauri::command]
async fn get_platform_info() -> Result<serde_json::Value, String> {
    let info = serde_json::json!({
        "os": std::env::consts::OS,
        "arch": std::env::consts::ARCH,
        "family": std::env::consts::FAMILY,
    });
    Ok(info)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Inisialisasi rexiv2 sebelum memulai aplikasi
    if let Err(e) = rexiv2::initialize() {
        eprintln!("Gagal menginisialisasi rexiv2: {}", e);
        std::process::exit(1);
    }

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            read_metadata,
            write_metadata,
            get_platform_info
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
