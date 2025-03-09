use std::env;
use std::path::Path;
use std::process::Command;

// fn main() {
//     // Konfigurasi tauri-build untuk Tauri v2
//     tauri_build::build();
// }

fn main() {
    // Konfigurasi tauri-build untuk Tauri v2
    tauri_build::build();

    // Konfigurasi untuk platform yang berbeda
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();

    // Path untuk menyimpan library yang dibundel
    let out_dir = env::var("OUT_DIR").unwrap();
    let deps_dir = Path::new(&out_dir).join("deps");

    // Buat direktori jika belum ada
    std::fs::create_dir_all(&deps_dir).unwrap();

    // Sesuaikan dengan platform
    match target_os.as_str() {
        "windows" => {
            // Untuk Windows
            println!("cargo:rustc-link-search=native=src-tauri/libs/windows");
            println!("cargo:rustc-link-lib=dylib=gexiv2");

            // Copy library ke direktori output
            if Path::new("src-tauri/libs/windows/gexiv2.dll").exists() {
                std::fs::copy(
                    "src-tauri/libs/windows/gexiv2.dll",
                    deps_dir.join("gexiv2.dll"),
                )
                .unwrap_or_else(|e| {
                    println!("cargo:warning=Failed to copy gexiv2.dll: {}", e);
                    0
                });

                // Atur flag lingkungan Rust untuk mencari di path kustom
                println!("cargo:rustc-env=PATH=src-tauri/libs/windows");
            } else {
                println!("cargo:warning=gexiv2.dll tidak ditemukan, pastikan untuk mengekstrak library terlebih dahulu");
            }
        }
        "macos" => {
            // Untuk macOS
            println!("cargo:rustc-link-search=native=src-tauri/libs/macos");
            println!("cargo:rustc-link-lib=dylib=gexiv2");

            // Copy library ke direktori output
            if Path::new("src-tauri/libs/macos/libgexiv2.dylib").exists() {
                std::fs::copy(
                    "src-tauri/libs/macos/libgexiv2.dylib",
                    deps_dir.join("libgexiv2.dylib"),
                )
                .unwrap_or_else(|e| {
                    println!("cargo:warning=Failed to copy libgexiv2.dylib: {}", e);
                    0
                });

                // Untuk macOS, kita perlu mengubah rpath
                if Command::new("install_name_tool")
                    .args(&[
                        "-change",
                        "/usr/local/lib/libgexiv2.dylib",
                        "@executable_path/libgexiv2.dylib",
                    ])
                    .arg(deps_dir.join("libgexiv2.dylib"))
                    .status()
                    .is_err()
                {
                    println!("cargo:warning=Failed to run install_name_tool");
                }
            } else {
                println!("cargo:warning=libgexiv2.dylib tidak ditemukan, pastikan untuk mengekstrak library terlebih dahulu");
            }
        }
        "linux" => {
            // Untuk Linux
            println!("cargo:rustc-link-search=native=src-tauri/libs/linux");
            println!("cargo:rustc-link-lib=dylib=gexiv2");

            // Copy library ke direktori output
            if Path::new("src-tauri/libs/linux/libgexiv2.so").exists() {
                std::fs::copy(
                    "src-tauri/libs/linux/libgexiv2.so",
                    deps_dir.join("libgexiv2.so"),
                )
                .unwrap_or_else(|e| {
                    println!("cargo:warning=Failed to copy libgexiv2.so: {}", e);
                    0
                });
            } else {
                println!("cargo:warning=libgexiv2.so tidak ditemukan, pastikan untuk mengekstrak library terlebih dahulu");
            }
        }
        _ => {
            println!("cargo:warning=Unsupported platform for bundled dependencies");
        }
    }

    // Rerun build script jika libraries berubah
    println!("cargo:rerun-if-changed=src-tauri/libs");
}
