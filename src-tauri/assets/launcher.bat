@echo off
REM launcher.bat - Script untuk meluncurkan aplikasi dengan path library yang benar
REM Tambahkan ini ke src-tauri/assets/ dan sertakan dalam bundling

REM Simpan direktori saat ini
set ORIGINAL_DIR=%CD%

REM Pindah ke direktori script
cd /d "%~dp0"

REM Tambahkan direktori library ke PATH
set PATH=%~dp0..\resources\libs\windows;%PATH%

REM Jalankan aplikasi
start "" "%~dp0..\Image Metadata Editor.exe" %*

REM Kembalikan direktori asli
cd /d "%ORIGINAL_DIR%"