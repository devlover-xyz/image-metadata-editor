#!/bin/bash
# Skrip ini dijalankan setelah build Tauri untuk memperbaiki referensi library di macOS

set -e  # Exit pada error

APP_NAME="image-metadata-editor"

# Deteksi platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Menjalankan post-processing untuk macOS..."
    
    # Temukan path aplikasi yang dihasilkan
    APP_PATH=$(find target -name "${APP_NAME}.app" -type d | grep -v "debug" | head -n 1)
    
    if [ -z "$APP_PATH" ]; then
        echo "Error: Tidak dapat menemukan aplikasi yang dihasilkan"
        exit 1
    fi
    
    echo "Aplikasi ditemukan di: $APP_PATH"
    
    # Pastikan folder Frameworks ada
    FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"
    EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
    RESOURCES_PATH="$APP_PATH/Contents/Resources/libs"
    
    mkdir -p "$FRAMEWORKS_PATH"
    
    # Salin library dari folder resources ke Frameworks jika belum ada
    if [ -d "$RESOURCES_PATH" ]; then
        echo "Menyalin library dari Resources ke Frameworks..."
        cp -R "$RESOURCES_PATH"/* "$FRAMEWORKS_PATH/" 2>/dev/null || true
    fi
    
    # Perbaiki referensi di executable utama
    echo "Memperbaiki referensi library di executable utama..."
    
    if [ -f "$FRAMEWORKS_PATH/libgexiv2.dylib" ]; then
        # Ubah ID library
        install_name_tool -id "@executable_path/../Frameworks/libgexiv2.dylib" "$FRAMEWORKS_PATH/libgexiv2.dylib"
        
        # Ubah referensi di executable
        install_name_tool -change "@executable_path/libgexiv2.dylib" "@executable_path/../Frameworks/libgexiv2.dylib" "$EXECUTABLE_PATH"
        
        echo "Referensi libgexiv2.dylib diperbaiki"
    else
        echo "Warning: libgexiv2.dylib tidak ditemukan di Frameworks"
    fi
    
    # Periksa dependensi libgexiv2.dylib
    if [ -f "$FRAMEWORKS_PATH/libgexiv2.dylib" ]; then
        echo "Memeriksa dependensi libgexiv2.dylib..."
        DEPS=$(otool -L "$FRAMEWORKS_PATH/libgexiv2.dylib" | grep -v "@executable_path" | grep -v "/System" | grep -v "/usr/lib" | awk '{print $1}')
        
        for DEP in $DEPS; do
            DEP_NAME=$(basename "$DEP")
            echo "Memperbaiki referensi untuk dependensi: $DEP_NAME"
            
            # Jika dependensi ada di Frameworks, perbaiki referensinya
            if [ -f "$FRAMEWORKS_PATH/$DEP_NAME" ]; then
                install_name_tool -change "$DEP" "@executable_path/../Frameworks/$DEP_NAME" "$FRAMEWORKS_PATH/libgexiv2.dylib"
                echo "  Referensi $DEP_NAME diperbaiki"
            else
                echo "  Warning: Dependensi $DEP_NAME tidak ditemukan di Frameworks"
            fi
        done
    fi

    # Tambahkan di skrip fix-libraries.sh
    echo "Menandatangani libraries..."
    find "$FRAMEWORKS_PATH" -name "*.dylib" -exec codesign --force --sign - {} \;

    echo "Menandatangani ulang aplikasi..."
    codesign --force --deep --sign - "$APP_PATH"
    
    echo "Post-processing macOS selesai"
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Menjalankan post-processing untuk Linux..."
    # Implementasi untuk Linux jika diperlukan
    
elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32" ]]; then
    echo "Menjalankan post-processing untuk Windows..."
    # Implementasi untuk Windows jika diperlukan
    
else
    echo "Platform tidak dikenal: $OSTYPE"
    exit 1
fi

echo "Post-processing selesai"
exit 0