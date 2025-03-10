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

    # Deteksi arsitektur saat ini
    ARCH=$(uname -m)
    echo "Current architecture: $ARCH"

    # Buat direktori untuk menyimpan library
    mkdir -p src-tauri/libs/macos/x86_64
    mkdir -p src-tauri/libs/macos/arm64
    mkdir -p src-tauri/libs/macos/universal
    
    # Cek apakah gexiv2 terdeteksi oleh pkg-config
    echo "Checking if gexiv2 is properly detected by pkg-config..."
    pkg-config --modversion gexiv2 || true

    # Cari lokasi library gexiv2
    GEXIV2_PATH=$(pkg-config --variable=libdir gexiv2)/libgexiv2.dylib
    echo "GExiv2 library found at: $GEXIV2_PATH"


     # Salin library ke direktori arsitektur saat ini
    if [ "$ARCH" = "x86_64" ]; then
      # Kita berada di Intel Mac
      echo "Copying libraries for Intel architecture (x86_64)"
      cp "$GEXIV2_PATH" src-tauri/libs/macos/x86_64/libgexiv2.dylib
      
      # Cari dependencies menggunakan otool
      DEPS=$(otool -L "$GEXIV2_PATH" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
      for dep in $DEPS; do
        base_name=$(basename "$dep")
        echo "Copying x86_64 dependency: $base_name"
        cp "$dep" "src-tauri/libs/macos/x86_64/$base_name"
      done
      
      # Coba untuk mendapatkan versi ARM jika mungkin menggunakan Rosetta
      echo "Attempting to get ARM libraries using Rosetta..."
      arch -arm64 brew install gexiv2 || true
      ARM_GEXIV2_PATH=$(arch -arm64 pkg-config --variable=libdir gexiv2 2>/dev/null)/libgexiv2.dylib || true
      
      if [ -f "$ARM_GEXIV2_PATH" ]; then
        echo "ARM version found, copying..."
        cp "$ARM_GEXIV2_PATH" src-tauri/libs/macos/arm64/libgexiv2.dylib
        
        # Cari dependencies untuk ARM
        ARM_DEPS=$(arch -arm64 otool -L "$ARM_GEXIV2_PATH" 2>/dev/null | grep -v libgexiv2 | grep "$(arch -arm64 brew --prefix 2>/dev/null)" | awk -F' ' '{print $1}')
        for dep in $ARM_DEPS; do
          base_name=$(basename "$dep")
          echo "Copying arm64 dependency: $base_name"
          cp "$dep" "src-tauri/libs/macos/arm64/$base_name"
        done
      else
        echo "Could not obtain ARM libraries, will use x86_64 version only"
        # Copy x86_64 libraries ke universal directory
        cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/universal/
      fi
    else
      # Kita berada di ARM Mac (M1/M2)
      echo "Copying libraries for ARM architecture (arm64)"
      cp "$GEXIV2_PATH" src-tauri/libs/macos/arm64/libgexiv2.dylib
      
      # Cari dependencies menggunakan otool
      DEPS=$(otool -L "$GEXIV2_PATH" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
      for dep in $DEPS; do
        base_name=$(basename "$dep")
        echo "Copying arm64 dependency: $base_name"
        cp "$dep" "src-tauri/libs/macos/arm64/$base_name"
      done
      
      # Coba untuk mendapatkan versi Intel jika mungkin menggunakan Rosetta
      echo "Attempting to get Intel libraries if possible..."
      arch -x86_64 brew install gexiv2 || true
      INTEL_GEXIV2_PATH=$(arch -x86_64 pkg-config --variable=libdir gexiv2 2>/dev/null)/libgexiv2.dylib || true
      
      if [ -f "$INTEL_GEXIV2_PATH" ]; then
        echo "Intel version found, copying..."
        cp "$INTEL_GEXIV2_PATH" src-tauri/libs/macos/x86_64/libgexiv2.dylib
        
        # Cari dependencies untuk Intel
        INTEL_DEPS=$(arch -x86_64 otool -L "$INTEL_GEXIV2_PATH" 2>/dev/null | grep -v libgexiv2 | grep "$(arch -x86_64 brew --prefix 2>/dev/null)" | awk -F' ' '{print $1}')
        for dep in $INTEL_DEPS; do
          base_name=$(basename "$dep")
          echo "Copying x86_64 dependency: $base_name"
          cp "$dep" "src-tauri/libs/macos/x86_64/$base_name"
        done
      else
        echo "Could not obtain Intel libraries, will use arm64 version only"
        # Copy arm64 libraries ke universal directory
        cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/universal/
      fi
    fi
    
    # Coba buat universal binaries jika kedua arsitektur tersedia
    if [ -f "src-tauri/libs/macos/x86_64/libgexiv2.dylib" ] && [ -f "src-tauri/libs/macos/arm64/libgexiv2.dylib" ]; then
      echo "Creating universal binaries..."
      
      # Buat daftar semua library yang ada di kedua arsitektur
      x86_files=$(ls src-tauri/libs/macos/x86_64/)
      arm64_files=$(ls src-tauri/libs/macos/arm64/)
      
      # Temukan file yang ada di kedua arsitektur
      common_files=$(comm -12 <(echo "$x86_files" | sort) <(echo "$arm64_files" | sort))
      
      # Buat universal binary untuk setiap file yang umum
      for file in $common_files; do
        echo "Creating universal binary for $file"
        lipo -create "src-tauri/libs/macos/x86_64/$file" "src-tauri/libs/macos/arm64/$file" -output "src-tauri/libs/macos/universal/$file"
      done
    fi
    
    # Perbaiki path referensi di library universal
    echo "Fixing library references in universal libraries..."
    for lib in src-tauri/libs/macos/universal/*.dylib; do
      if [ -f "$lib" ]; then
        base_name=$(basename "$lib")
        # Fix ID
        install_name_tool -id "@executable_path/$base_name" "$lib"
        
        # Fix dependencies
        deps=$(otool -L "$lib" | grep -v "@executable_path" | grep -v "/usr/lib" | awk -F' ' '{print $1}')
        for dep in $deps; do
          dep_base=$(basename "$dep")
          if [ -f "src-tauri/libs/macos/universal/$dep_base" ]; then
            echo "Fixing reference in $base_name to $dep_base"
            install_name_tool -change "$dep" "@executable_path/$dep_base" "$lib"
          fi
        done
      fi
    done
    
    # Pilih direktori yang akan digunakan sebagai library directory
    if [ -d "src-tauri/libs/macos/universal" ] && [ "$(ls -A src-tauri/libs/macos/universal/)" ]; then
      echo "Using universal binaries"
      cp src-tauri/libs/macos/universal/* src-tauri/libs/macos/
    elif [ "$ARCH" = "x86_64" ]; then
      echo "Using x86_64 binaries only"
      cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/
    else
      echo "Using arm64 binaries only"
      cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/
    fi
    
    # Tampilkan isi direktori final
    echo "Contents of final libs/macos directory:"
    ls -la src-tauri/libs/macos/
    
    # Set environment variables untuk build process
    echo "PKG_CONFIG_ALLOW_CROSS=1" >> $GITHUB_ENV
    echo "GEXIV2_NO_PKG_CONFIG=1" >> $GITHUB_ENV
    echo "GEXIV2_LIB_DIR=$(pwd)/src-tauri/libs/macos" >> $GITHUB_ENV
    echo "GEXIV2_INCLUDE_DIR=$(pkg-config --variable=includedir gexiv2)/gexiv2" >> $GITHUB_ENV


    
    # # Salin library utama
    # cp "$(brew --prefix)/lib/libgexiv2.dylib" src-tauri/libs/macos/

    # # Temukan dependencies dengan otool
    # DEPS=$(otool -L "$(brew --prefix)/lib/libgexiv2.dylib" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
    
    # # Salin semua dependencies
    # for dep in $DEPS; do
    #     base_name=$(basename "$dep")

    #     # Get current user and group
    #     CURRENT_USER=$(whoami)
    #     CURRENT_GROUP=$(id -gn)
        
    #     # Copy file and set permissions
    #     cp "$dep" "src-tauri/libs/macos/"
    #     chown $CURRENT_USER:$CURRENT_GROUP "src-tauri/libs/macos/$(basename "$dep")"
    #     chmod 755 "src-tauri/libs/macos/$(basename "$dep")"
    #     echo "Copied $base_name"
        
    #     # Perbaiki path di dalam library
    #     install_name_tool -id "@executable_path/$base_name" "src-tauri/libs/macos/$base_name"
        
    #     # Untuk library utama, ubah referensi ke dependensi
    #     install_name_tool -change "$dep" "@executable_path/$base_name" "src-tauri/libs/macos/libgexiv2.dylib"
    # done
    
    # # Perbaiki path di dalam library utama
    # install_name_tool -id "@executable_path/libgexiv2.dylib" "src-tauri/libs/macos/libgexiv2.dylib"
    
    # # Perbaiki referensi antar library
    # for lib in src-tauri/libs/macos/*.dylib; do
    #     if [ "$lib" != "src-tauri/libs/macos/libgexiv2.dylib" ]; then
    #         base_name=$(basename "$lib")
    #         dep_libs=$(otool -L "$lib" | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
            
    #         for dep in $dep_libs; do
    #             dep_base=$(basename "$dep")
    #             if [ -f "src-tauri/libs/macos/$dep_base" ]; then
    #                 install_name_tool -change "$dep" "@executable_path/$dep_base" "$lib"
    #                 echo "Fixed reference in $base_name to $dep_base"
    #             fi
    #         done
    #     fi
    # done
    
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
