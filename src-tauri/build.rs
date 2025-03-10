// build.rs untuk library yang dibundel di src-tauri/libs
use std::env;
use std::path::Path;

fn main() {
    // Konfigurasi tauri-build untuk Tauri v2
    tauri_build::build();
    
    // Konfigurasi untuk platform yang berbeda
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    
    println!("cargo:warning=Building for OS: {}, ARCH: {}", target_os, target_arch);
    
    // Path untuk menyimpan library yang dibundel
    let out_dir = env::var("OUT_DIR").unwrap_or_default();
    let deps_dir = Path::new(&out_dir).join("deps");
    
    // Buat direktori jika belum ada
    let _ = std::fs::create_dir_all(&deps_dir);
    
    // Path ke library yang dibundel
    let libs_base = "src-tauri/libs";
    
    // Sesuaikan dengan platform dan arsitektur
    match (target_os.as_str(), target_arch.as_str()) {
        ("macos", "x86_64") => {
            // macOS Intel
            if Path::new(&format!("{}/macos/x86_64/libgexiv2.dylib", libs_base)).exists() {
                let lib_path = format!("{}/macos/x86_64", libs_base);
                println!("cargo:warning=Using bundled x86_64 libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "dylib");
            } else if Path::new(&format!("{}/macos/universal/libgexiv2.dylib", libs_base)).exists() {
                // Fallback ke universal jika tersedia
                let lib_path = format!("{}/macos/universal", libs_base);
                println!("cargo:warning=Using bundled universal libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "dylib");
            } else {
                println!("cargo:warning=No bundled macOS x86_64 libraries found, will use pkg-config");
            }
        },
        ("macos", "aarch64") => {
            // macOS ARM
            if Path::new(&format!("{}/macos/arm64/libgexiv2.dylib", libs_base)).exists() {
                let lib_path = format!("{}/macos/arm64", libs_base);
                println!("cargo:warning=Using bundled arm64 libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "dylib");
            } else if Path::new(&format!("{}/macos/universal/libgexiv2.dylib", libs_base)).exists() {
                // Fallback ke universal jika tersedia
                let lib_path = format!("{}/macos/universal", libs_base);
                println!("cargo:warning=Using bundled universal libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "dylib");
            } else {
                println!("cargo:warning=No bundled macOS arm64 libraries found, will use pkg-config");
            }
        },
        ("windows", _) => {
            // Windows (biasanya x86_64)
            if Path::new(&format!("{}/windows/x86_64/gexiv2.dll", libs_base)).exists() {
                let lib_path = format!("{}/windows/x86_64", libs_base);
                println!("cargo:warning=Using bundled Windows libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "dll");
                
                // Set environment variable for runtime
                println!("cargo:rustc-env=PATH={}", lib_path);
            } else {
                println!("cargo:warning=No bundled Windows libraries found, will use pkg-config");
            }
        },
        ("linux", _) => {
            // Linux (biasanya x86_64)
            if Path::new(&format!("{}/linux/x86_64/libgexiv2.so", libs_base)).exists() {
                let lib_path = format!("{}/linux/x86_64", libs_base);
                println!("cargo:warning=Using bundled Linux libraries from {}", lib_path);
                println!("cargo:rustc-link-search=native={}", lib_path);
                println!("cargo:rustc-link-lib=dylib=gexiv2");
                
                // Copy libs to output
                copy_libs_from_dir(&lib_path, &deps_dir, "so");
            } else {
                println!("cargo:warning=No bundled Linux libraries found, will use pkg-config");
            }
        },
        _ => {
            println!("cargo:warning=Unsupported platform, will try to use pkg-config");
        }
    }
    
    // Rerun build script jika library berubah
    println!("cargo:rerun-if-changed={}", libs_base);
    
    // Environment variables fallback untuk pkg-config jika dibutuhkan
    println!("cargo:rerun-if-env-changed=GEXIV2_NO_PKG_CONFIG");
    println!("cargo:rerun-if-env-changed=GEXIV2_LIB_DIR");
    println!("cargo:rerun-if-env-changed=GEXIV2_INCLUDE_DIR");
}

fn copy_libs_from_dir(src_dir: &str, dst_dir: &impl AsRef<Path>, extension: &str) {
    if let Ok(entries) = std::fs::read_dir(src_dir) {
        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_file() && 
               path.extension().map_or(false, |ext| ext == extension) {
                if let Some(file_name) = path.file_name() {
                    let dst = dst_dir.as_ref().join(file_name);
                    if let Err(e) = std::fs::copy(&path, &dst) {
                        println!("cargo:warning=Failed to copy {}: {}", path.display(), e);
                    } else {
                        println!("cargo:warning=Copied {} to deps directory", file_name.to_string_lossy());
                    }
                }
            }
        }
    } else {
        println!("cargo:warning=Could not read directory: {}", src_dir);
    }
}
