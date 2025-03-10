@echo off
REM fix-pkg-config.bat - Script untuk memperbaiki masalah pkg-config di Windows

echo === Mengatasi error pkg-config di Windows ===

REM Periksa apakah MSYS2 sudah terinstal
if exist C:\msys64\usr\bin\pacman.exe (
    echo MSYS2 ditemukan di C:\msys64
) else (
    echo MSYS2 tidak ditemukan. Silakan instal MSYS2 dari https://www.msys2.org/
    echo Setelah instalasi, jalankan script ini kembali.
    pause
    exit /b 1
)

REM Instal pkg-config dan gexiv2 melalui MSYS2
echo Menginstal pkg-config dan gexiv2...
C:\msys64\usr\bin\bash.exe -lc "pacman -Sy --noconfirm mingw-w64-x86_64-pkg-config mingw-w64-x86_64-gexiv2"

REM Tambahkan path MSYS2 ke PATH sistem untuk sesi saat ini
set PATH=C:\msys64\mingw64\bin;%PATH%

REM Periksa apakah pkg-config sudah berfungsi sekarang
echo Memeriksa instalasi pkg-config...
where pkg-config
if %ERRORLEVEL% NEQ 0 (
    echo pkg-config masih tidak ditemukan. Pastikan C:\msys64\mingw64\bin ada di PATH sistem Anda.
) else (
    echo pkg-config berhasil diinstal.
    pkg-config --version
)

REM Periksa apakah gexiv2 terdeteksi
echo Memeriksa deteksi gexiv2...
pkg-config --exists --print-errors gexiv2
if %ERRORLEVEL% NEQ 0 (
    echo gexiv2 tidak terdeteksi oleh pkg-config.
) else (
    echo gexiv2 berhasil terdeteksi oleh pkg-config.
    pkg-config --modversion gexiv2
)

echo.
echo === Menambahkan konfigurasi cargo khusus ===

REM Buat folder .cargo jika belum ada
if not exist .cargo mkdir .cargo

REM Buat file config.toml untuk memberi tahu Cargo tentang lokasi library
echo Membuat file konfigurasi Cargo...
(
echo [build]
echo rustflags = ["-C", "link-arg=-LC:\\msys64\\mingw64\\lib"]
echo.
echo [env]
echo PKG_CONFIG_PATH = "C:\\msys64\\mingw64\\lib\\pkgconfig"
) > .cargo\config.toml

echo File .cargo\config.toml berhasil dibuat.

echo.
echo === Membuat environment file untuk proses build ===

REM Buat file .env untuk variabel lingkungan build
(
echo PKG_CONFIG_PATH=C:\msys64\mingw64\lib\pkgconfig
echo PKG_CONFIG_ALLOW_CROSS=1
) > .env

echo File .env berhasil dibuat.

echo.
echo === PENTING: Langkah selanjutnya ===
echo 1. Pastikan untuk MENUTUP dan MEMBUKA KEMBALI terminal/cmd/powershell Anda
echo 2. Tambahkan C:\msys64\mingw64\bin ke PATH sistem permanen Anda:
echo    - Buka Control Panel -^> System -^> Advanced System Settings
echo    - Klik "Environment Variables"
echo    - Di bagian "System Variables", edit variabel "Path"
echo    - Tambahkan "C:\msys64\mingw64\bin"
echo    - Klik OK dan tutup semua dialog
echo 3. Coba build kembali proyek Anda

pause
