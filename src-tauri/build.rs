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

    println!("cargo:warning=Building for OS: {}, ARCH: {}", target_os, target_arch);

    // Sesuaikan dengan platform
    match target_os.as_str() {
        "macos" => {
            // Check jika kita menggunakan konfigurasi tanpa pkg-config
            if env::var("GEXIV2_NO_PKG_CONFIG").is_ok() {
                let lib_dir = env::var("GEXIV2_LIB_DIR")
                    .expect("GEXIV2_LIB_DIR must be set when GEXIV2_NO_PKG_CONFIG is enabled");
                let include_dir = env::var("GEXIV2_INCLUDE_DIR")
                    .expect("GEXIV2_INCLUDE_DIR must be set when GEXIV2_NO_PKG_CONFIG is enabled");
                
                println!("cargo:warning=Using manual library paths: lib={}, include={}", lib_dir, include_dir);
                println!("cargo:rustc-link-search=native={}", lib_dir);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                println!("cargo:include={}", include_dir);
                
                // Deteksi library yang sesuai dengan arsitektur target
                let lib_path = match target_arch.as_str() {
                    "x86_64" => {
                        if Path::new(&format!("{}/x86_64/libgexiv2.dylib", lib_dir)).exists() {
                            format!("{}/x86_64", lib_dir)
                        } else {
                            lib_dir.clone()
                        }
                    },
                    "aarch64" => {
                        if Path::new(&format!("{}/arm64/libgexiv2.dylib", lib_dir)).exists() {
                            format!("{}/arm64", lib_dir)
                        } else {
                            lib_dir.clone()
                        }
                    },
                    _ => lib_dir.clone()
                };
                
                // Check apakah ada binary universal
                let universal_lib_path = format!("{}/universal", lib_dir);
                let use_universal = Path::new(&universal_lib_path).exists() && 
                                   Path::new(&format!("{}/libgexiv2.dylib", universal_lib_path)).exists();
                
                // Preferensi universal binary jika tersedia
                let final_lib_path = if use_universal {
                    println!("cargo:warning=Using universal binary libraries");
                    universal_lib_path
                } else {
                    println!("cargo:warning=Using architecture-specific libraries: {}", lib_path);
                    lib_path
                };
                
                // Copy semua library ke output directory
                if let Ok(entries) = std::fs::read_dir(&final_lib_path) {
                    for entry in entries.filter_map(Result::ok) {
                        let path = entry.path();
                        if path.is_file() && 
                           path.extension().map_or(false, |ext| ext == "dylib") {
                            let file_name = path.file_name().unwrap();
                            let dst = deps_dir.join(file_name);
                            if let Err(e) = std::fs::copy(&path, &dst) {
                                println!("cargo:warning=Failed to copy {}: {}", path.display(), e);
                            } else {
                                println!("cargo:warning=Copied {} to deps directory", file_name.to_string_lossy());
                            }
                        }
                    }
                }
            } else {
                // Fallback ke pendekatan standar dengan pkg-config
                println!("cargo:warning=Using pkg-config for library detection");

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
        }
        // "macos" => {
        //     // Untuk macOS
        //     println!("cargo:rustc-link-search=native=src-tauri/libs/macos");
        //     println!("cargo:rustc-link-lib=dylib=gexiv2");

        //     // Copy library ke direktori output
        //     if Path::new("src-tauri/libs/macos/libgexiv2.dylib").exists() {
        //         std::fs::copy(
        //             "src-tauri/libs/macos/libgexiv2.dylib",
        //             deps_dir.join("libgexiv2.dylib"),
        //         )
        //         .unwrap_or_else(|e| {
        //             println!("cargo:warning=Failed to copy libgexiv2.dylib: {}", e);
        //             0
        //         });

        //         // Untuk macOS, kita perlu mengubah rpath
        //         if Command::new("install_name_tool")
        //             .args(&[
        //                 "-change",
        //                 "/usr/local/lib/libgexiv2.dylib",
        //                 "@executable_path/libgexiv2.dylib",
        //             ])
        //             .arg(deps_dir.join("libgexiv2.dylib"))
        //             .status()
        //             .is_err()
        //         {
        //             println!("cargo:warning=Failed to run install_name_tool");
        //         }
        //     } else {
        //         println!("cargo:warning=libgexiv2.dylib tidak ditemukan, pastikan untuk mengekstrak library terlebih dahulu");
        //     }
        // }
        "windows" => {
            // Untuk Windows
            println!("cargo:rustc-link-search=native=src-tauri/libs/windows");
            println!("cargo:rustc-link-lib=dylib=gexiv2");

            // Copy library ke direktori output
            if Path::new("src-tauri/libs/windows/gexiv2.dll").exists() {
                println!("cargo:warning=Found bundled gexiv2.dll, copying to deps directory");
                
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
        "linux" => {
            // Untuk Linux
            println!("cargo:rustc-link-search=native=src-tauri/libs/linux");
            println!("cargo:rustc-link-lib=dylib=gexiv2");

            // Copy library ke direktori output
            if Path::new("src-tauri/libs/linux/libgexiv2.so").exists() {
                println!("cargo:warning=Found bundled libgexiv2.so, copying to deps directory");
                
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
