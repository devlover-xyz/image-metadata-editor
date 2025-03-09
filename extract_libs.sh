#!/bin/bash
# extract_libs.sh - Script untuk mengekstrak library dependencies untuk bundling

# Buat direktori untuk libraries
mkdir -p src-tauri/libs/windows
mkdir -p src-tauri/libs/macos
mkdir -p src-tauri/libs/linux

# Deteksi OS
OS="$(uname)"

# Windows (menggunakan PowerShell)
if [[ "$OS" == *"MINGW"* ]] || [[ "$OS" == *"MSYS"* ]] || [[ "$OS" == "Windows"* ]]; then
    echo "Mendeteksi Windows, mengekstrak libraries..."
    
    # Script PowerShell untuk ekstraksi library dari MSYS2
    cat > extract_deps.ps1 << 'EOF'
# Direktori tujuan
$dest = "src-tauri\libs\windows"
mkdir -p $dest -Force

# Library utama
Copy-Item "C:\msys64\mingw64\bin\libgexiv2-2.dll" "$dest\gexiv2.dll"

# Temukan dependencies dengan ldd
$deps = & "C:\msys64\mingw64\bin\ldd.exe" "C:\msys64\mingw64\bin\libgexiv2-2.dll" | 
        Select-String -Pattern "=> C:/msys64/mingw64/bin/(.*\.dll)" | 
        ForEach-Object { $_.Matches.Groups[1].Value }

# Salin semua dependencies
foreach ($dep in $deps) {
    Copy-Item "C:\msys64\mingw64\bin\$dep" "$dest\"
    Write-Host "Copied $dep"
}

# Tambahkan library GTK/GLib yang mungkin diperlukan
$glib_deps = @(
    "libglib-2.0-0.dll",
    "libgobject-2.0-0.dll",
    "libgio-2.0-0.dll",
    "libintl-8.dll",
    "libiconv-2.dll",
    "libpcre-1.dll"
)

foreach ($dep in $glib_deps) {
    if (!(Test-Path "$dest\$dep") -and (Test-Path "C:\msys64\mingw64\bin\$dep")) {
        Copy-Item "C:\msys64\mingw64\bin\$dep" "$dest\"
        Write-Host "Copied additional dependency: $dep"
    }
}
EOF

    # Jalankan script PowerShell
    powershell.exe -ExecutionPolicy Bypass -File extract_deps.ps1
    
# macOS
elif [[ "$OS" == "Darwin" ]]; then
    echo "Mendeteksi macOS, mengekstrak libraries..."
    
    # Salin library utama
    cp "$(brew --prefix)/lib/libgexiv2.dylib" src-tauri/libs/macos/

    # Temukan dependencies dengan otool
    DEPS=$(otool -L "$(brew --prefix)/lib/libgexiv2.dylib" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
    
    # Salin semua dependencies
    for dep in $DEPS; do
        base_name=$(basename "$dep")

        # Get current user and group
        CURRENT_USER=$(whoami)
        CURRENT_GROUP=$(id -gn)
        
        # Copy file and set permissions
        cp "$dep" "src-tauri/libs/macos/"
        chown $CURRENT_USER:$CURRENT_GROUP "src-tauri/libs/macos/$(basename "$dep")"
        chmod 755 "src-tauri/libs/macos/$(basename "$dep")"
        echo "Copied $base_name"
        
        # Perbaiki path di dalam library
        install_name_tool -id "@executable_path/$base_name" "src-tauri/libs/macos/$base_name"
        
        # Untuk library utama, ubah referensi ke dependensi
        install_name_tool -change "$dep" "@executable_path/$base_name" "src-tauri/libs/macos/libgexiv2.dylib"
    done
    
    # Perbaiki path di dalam library utama
    install_name_tool -id "@executable_path/libgexiv2.dylib" "src-tauri/libs/macos/libgexiv2.dylib"
    
    # Perbaiki referensi antar library
    for lib in src-tauri/libs/macos/*.dylib; do
        if [ "$lib" != "src-tauri/libs/macos/libgexiv2.dylib" ]; then
            base_name=$(basename "$lib")
            dep_libs=$(otool -L "$lib" | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
            
            for dep in $dep_libs; do
                dep_base=$(basename "$dep")
                if [ -f "src-tauri/libs/macos/$dep_base" ]; then
                    install_name_tool -change "$dep" "@executable_path/$dep_base" "$lib"
                    echo "Fixed reference in $base_name to $dep_base"
                fi
            done
        fi
    done
    
# Linux
elif [[ "$OS" == "Linux" ]]; then
    echo "Mendeteksi Linux, mengekstrak libraries..."
    
    # Lokasi library berdasarkan distro
    if [ -f "/usr/lib/x86_64-linux-gnu/libgexiv2.so.2" ]; then
        # Debian/Ubuntu
        GEXIV2_PATH="/usr/lib/x86_64-linux-gnu/libgexiv2.so.2"
    elif [ -f "/usr/lib64/libgexiv2.so.2" ]; then
        # Fedora/RHEL
        GEXIV2_PATH="/usr/lib64/libgexiv2.so.2"
    else
        echo "Tidak dapat menemukan libgexiv2.so.2, harap instal terlebih dahulu"
        exit 1
    fi
    
    # Salin library utama
    cp "$GEXIV2_PATH" src-tauri/libs/linux/libgexiv2.so
    
    # Temukan dependencies dengan ldd
    DEPS=$(ldd "$GEXIV2_PATH" | grep "=> /" | awk '{print $3}')
    
    # Salin semua dependencies
    for dep in $DEPS; do
        base_name=$(basename "$dep")
        # Abaikan library sistem standar
        if [[ ! "$base_name" =~ ^(libc\.so|libm\.so|libdl\.so|libpthread\.so|librt\.so|ld-linux-x86-64\.so) ]]; then
            cp "$dep" "src-tauri/libs/linux/"
            echo "Copied $base_name"
        fi
    done
    
    # Buat script untuk menyetting LD_LIBRARY_PATH
    cat > src-tauri/assets/set_libs.sh << EOF
#!/bin/sh
# Script ini dijalankan sebelum aplikasi utama untuk menyetting LD_LIBRARY_PATH

# Tambahkan direktori dengan library ke LD_LIBRARY_PATH
SCRIPT_DIR=\$(dirname "\$0")
export LD_LIBRARY_PATH="\$SCRIPT_DIR/../resources/libs/linux:\$LD_LIBRARY_PATH"

# Jalankan aplikasi utama
exec "\$SCRIPT_DIR/\$1" "\${@:2}"
EOF
    
    chmod +x src-tauri/assets/set_libs.sh
else
    echo "OS tidak dikenal: $OS"
    exit 1
fi

echo "Ekstraksi library selesai!"