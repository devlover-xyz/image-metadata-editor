# Script PowerShell untuk mengekstrak library Windows
# Simpan sebagai extract-windows-libs.ps1

# Pastikan MSYS2 sudah terinstal
if (!(Test-Path "C:\msys64\usr\bin\bash.exe")) {
    Write-Host "MSYS2 tidak ditemukan. Silakan instal dari https://www.msys2.org/" -ForegroundColor Red
    exit 1
}

# Instal dependencies jika belum ada
Write-Host "Memastikan gexiv2 dan pkg-config terinstal..." -ForegroundColor Cyan
C:\msys64\usr\bin\bash.exe -lc "pacman -Sy --noconfirm mingw-w64-x86_64-pkg-config mingw-w64-x86_64-gexiv2"

# Buat direktori untuk menyimpan library
$libDir = "src-tauri\libs\windows\x86_64"
New-Item -Path $libDir -ItemType Directory -Force | Out-Null

# Salin file DLL utama
Write-Host "Menyalin library utama gexiv2..." -ForegroundColor Cyan
Copy-Item C:\msys64\mingw64\bin\libgexiv2-2.dll "$libDir\gexiv2.dll"

# Temukan semua dependensi dengan ldd
Write-Host "Mencari dan menyalin dependencies..." -ForegroundColor Cyan
$deps = & C:\msys64\usr\bin\bash.exe -c "ldd /mingw64/bin/libgexiv2-2.dll | grep -v libgexiv2 | grep '=> /mingw64/' | awk '{print \$3}'"

foreach ($dep in $deps) {
  $dep = $dep -replace '/mingw64/bin/', ''
  Write-Host "Menyalin dependency: $dep" -ForegroundColor Gray
  Copy-Item "C:\msys64\mingw64\bin\$dep" "$libDir\"
}

# Tambahan library yang mungkin diperlukan
$additionalLibs = @(
  "libglib-2.0-0.dll",
  "libgobject-2.0-0.dll",
  "libintl-8.dll",
  "libiconv-2.dll",
  "libpcre-1.dll",
  "libwinpthread-1.dll"
)

foreach ($lib in $additionalLibs) {
  if (Test-Path "C:\msys64\mingw64\bin\$lib" -not (Test-Path "$libDir\$lib")) {
    Write-Host "Menyalin library tambahan: $lib" -ForegroundColor Gray
    Copy-Item "C:\msys64\mingw64\bin\$lib" "$libDir\"
  }
}

# Tampilkan hasil
Write-Host "`nPengekstrakan library Windows selesai!" -ForegroundColor Green
Write-Host "Library tersimpan di: $libDir" -ForegroundColor Green
Write-Host "Daftar file:" -ForegroundColor Green
Get-ChildItem -Path $libDir
