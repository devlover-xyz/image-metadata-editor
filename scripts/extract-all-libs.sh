#!/bin/bash
# Script untuk mengekstrak semua library untuk semua platform
# Simpan sebagai extract-all-libs.sh
# Jalankan dengan: chmod +x extract-all-libs.sh && ./extract-all-libs.sh

# Deteksi OS
OS="$(uname)"

echo "======================="
echo "Ekstraksi Library Lokal"
echo "======================="
echo "OS Terdeteksi: $OS"
echo

# Jalankan script yang sesuai dengan OS saat ini
if [[ "$OS" == *"MINGW"* ]] || [[ "$OS" == *"MSYS"* ]] || [[ "$OS" == "Windows"* ]]; then
    echo "Menjalankan script Windows..."
    powershell.exe -ExecutionPolicy Bypass -File extract-windows-libs.ps1
elif [[ "$OS" == "Darwin" ]]; then
    echo "Menjalankan script macOS..."
    bash extract-macos-libs.sh
elif [[ "$OS" == "Linux" ]]; then
    echo "Menjalankan script Linux..."
    echo "Dibutuhkan hak admin untuk menginstal package..."
    sudo bash extract-linux-libs.sh
else
    echo "OS tidak dikenal: $OS"
    exit 1
fi

echo
echo "========================================"
echo "Ekstraksi library lokal telah selesai!"
echo "========================================"
echo "Library tersimpan di src-tauri/libs/"
echo
echo "Strukturnya:"
echo "- src-tauri/libs/windows/ (untuk Windows)"
echo "- src-tauri/libs/macos/   (untuk macOS)"
echo "- src-tauri/libs/linux/   (untuk Linux)"
echo

# Note: Library untuk platform lain tidak akan diekstrak
# secara lokal. Gunakan GitHub Actions untuk mengekstrak
# library untuk semua platform sekaligus.
