#!/bin/bash
# Script untuk mengekstrak library macOS
# Simpan sebagai extract-macos-libs.sh
# Jalankan dengan: chmod +x extract-macos-libs.sh && ./extract-macos-libs.sh

# Periksa apakah Homebrew terinstal
if ! command -v brew &> /dev/null; then
    echo "Homebrew tidak ditemukan. Silakan instal dengan menjalankan:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Instal dependensi
echo "Menginstal dependency dengan Homebrew..."
brew update
brew install pkg-config gexiv2

# Deteksi arsitektur saat ini
ARCH=$(uname -m)
echo "Arsitektur saat ini: $ARCH"

# Buat direktori untuk menyimpan library
mkdir -p src-tauri/libs/macos/x86_64
mkdir -p src-tauri/libs/macos/arm64
mkdir -p src-tauri/libs/macos/universal

# Cari lokasi library gexiv2
GEXIV2_PATH=$(pkg-config --variable=libdir gexiv2)/libgexiv2.dylib
echo "GExiv2 library ditemukan di: $GEXIV2_PATH"

if [ "$ARCH" = "x86_64" ]; then
    # Kita berada di Intel Mac
    echo "Menyalin library untuk arsitektur Intel (x86_64)..."
    cp "$GEXIV2_PATH" src-tauri/libs/macos/x86_64/libgexiv2.dylib
    
    # Cari dependencies menggunakan otool
    DEPS=$(otool -L "$GEXIV2_PATH" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
    for dep in $DEPS; do
        base_name=$(basename "$dep")
        echo "Menyalin x86_64 dependency: $base_name"
        cp "$dep" "src-tauri/libs/macos/x86_64/$base_name"
    done
    
    # Coba untuk mendapatkan versi ARM jika mungkin menggunakan Rosetta
    echo "Mencoba mendapatkan library ARM menggunakan Rosetta..."
    if command -v arch &> /dev/null; then
        if arch -arm64 true 2>/dev/null; then
            echo "Rosetta tersedia, mengekstrak library ARM64..."
            arch -arm64 brew install gexiv2 || true
            ARM_GEXIV2_PATH=$(arch -arm64 pkg-config --variable=libdir gexiv2 2>/dev/null)/libgexiv2.dylib || true
            
            if [ -f "$ARM_GEXIV2_PATH" ]; then
                echo "Versi ARM ditemukan, menyalin..."
                cp "$ARM_GEXIV2_PATH" src-tauri/libs/macos/arm64/libgexiv2.dylib
                
                # Cari dependencies untuk ARM
                ARM_DEPS=$(arch -arm64 otool -L "$ARM_GEXIV2_PATH" 2>/dev/null | grep -v libgexiv2 | grep "$(arch -arm64 brew --prefix 2>/dev/null)" | awk -F' ' '{print $1}')
                for dep in $ARM_DEPS; do
                    base_name=$(basename "$dep")
                    echo "Menyalin arm64 dependency: $base_name"
                    cp "$dep" "src-tauri/libs/macos/arm64/$base_name"
                done
            else
                echo "Tidak dapat memperoleh library ARM, hanya akan menggunakan versi x86_64"
                # Salin library x86_64 ke universal
                cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/universal/
            fi
        else
            echo "Rosetta tidak tersedia, hanya akan menggunakan versi x86_64"
            # Salin library x86_64 ke universal
            cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/universal/
        fi
    else
        echo "Perintah 'arch' tidak tersedia, hanya akan menggunakan versi x86_64"
        # Salin library x86_64 ke universal
        cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/universal/
    fi
else
    # Kita berada di ARM Mac (M1/M2)
    echo "Menyalin library untuk arsitektur ARM (arm64)..."
    cp "$GEXIV2_PATH" src-tauri/libs/macos/arm64/libgexiv2.dylib
    
    # Cari dependencies menggunakan otool
    DEPS=$(otool -L "$GEXIV2_PATH" | grep -v libgexiv2 | grep "$(brew --prefix)" | awk -F' ' '{print $1}')
    for dep in $DEPS; do
        base_name=$(basename "$dep")
        echo "Menyalin arm64 dependency: $base_name"
        cp "$dep" "src-tauri/libs/macos/arm64/$base_name"
    done
    
    # Coba untuk mendapatkan versi Intel jika mungkin menggunakan Rosetta
    echo "Mencoba mendapatkan library Intel jika memungkinkan..."
    if command -v arch &> /dev/null; then
        if arch -x86_64 true 2>/dev/null; then
            echo "Rosetta tersedia, mengekstrak library x86_64..."
            arch -x86_64 brew install gexiv2 || true
            INTEL_GEXIV2_PATH=$(arch -x86_64 pkg-config --variable=libdir gexiv2 2>/dev/null)/libgexiv2.dylib || true
            
            if [ -f "$INTEL_GEXIV2_PATH" ]; then
                echo "Versi Intel ditemukan, menyalin..."
                cp "$INTEL_GEXIV2_PATH" src-tauri/libs/macos/x86_64/libgexiv2.dylib
                
                # Cari dependencies untuk Intel
                INTEL_DEPS=$(arch -x86_64 otool -L "$INTEL_GEXIV2_PATH" 2>/dev/null | grep -v libgexiv2 | grep "$(arch -x86_64 brew --prefix 2>/dev/null)" | awk -F' ' '{print $1}')
                for dep in $INTEL_DEPS; do
                    base_name=$(basename "$dep")
                    echo "Menyalin x86_64 dependency: $base_name"
                    cp "$dep" "src-tauri/libs/macos/x86_64/$base_name"
                done
            else
                echo "Tidak dapat memperoleh library Intel, hanya akan menggunakan versi arm64"
                # Salin library arm64 ke universal
                cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/universal/
            fi
        else
            echo "Rosetta tidak tersedia, hanya akan menggunakan versi arm64"
            # Salin library arm64 ke universal
            cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/universal/
        fi
    else
        echo "Perintah 'arch' tidak tersedia, hanya akan menggunakan versi arm64"
        # Salin library arm64 ke universal
        cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/universal/
    fi
fi

# Buat universal binary jika kedua arsitektur tersedia
if [ -f "src-tauri/libs/macos/x86_64/libgexiv2.dylib" ] && [ -f "src-tauri/libs/macos/arm64/libgexiv2.dylib" ]; then
    echo "Membuat universal binaries..."
    
    # Buat daftar semua library yang ada di kedua arsitektur
    x86_files=$(ls src-tauri/libs/macos/x86_64/)
    arm64_files=$(ls src-tauri/libs/macos/arm64/)
    
    # Temukan file yang ada di kedua arsitektur
    common_files=$(comm -12 <(echo "$x86_files" | sort) <(echo "$arm64_files" | sort))
    
    # Buat universal binary untuk setiap file yang umum
    for file in $common_files; do
        echo "Membuat universal binary untuk $file"
        lipo -create "src-tauri/libs/macos/x86_64/$file" "src-tauri/libs/macos/arm64/$file" -output "src-tauri/libs/macos/universal/$file"
    done
fi

# Perbaiki path referensi di library universal
echo "Memperbaiki referensi library di universal libraries..."
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
                echo "Memperbaiki referensi di $base_name ke $dep_base"
                install_name_tool -change "$dep" "@executable_path/$dep_base" "$lib"
            fi
        done
    fi
done

# Pilih direktori yang akan digunakan sebagai library directory
if [ -d "src-tauri/libs/macos/universal" ] && [ "$(ls -A src-tauri/libs/macos/universal/)" ]; then
    echo "Menggunakan universal binaries"
    cp src-tauri/libs/macos/universal/* src-tauri/libs/macos/
elif [ "$ARCH" = "x86_64" ]; then
    echo "Menggunakan x86_64 binaries saja"
    cp src-tauri/libs/macos/x86_64/* src-tauri/libs/macos/
else
    echo "Menggunakan arm64 binaries saja"
    cp src-tauri/libs/macos/arm64/* src-tauri/libs/macos/
fi

# Tampilkan hasil
echo -e "\nPengekstrakan library macOS selesai!"
echo "Library tersimpan di: src-tauri/libs/macos/"
echo "Daftar file:"
ls -la src-tauri/libs/macos/
