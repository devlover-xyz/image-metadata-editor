# Script PowerShell untuk mengekstrak library Windows
# Simpan sebagai scripts/extract-windows-libs.ps1

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

# Temukan semua dependensi dengan ldd - FIX: Gunakan path relatif dalam MSYS2
Write-Host "Mencari dan menyalin dependencies..." -ForegroundColor Cyan
$deps = & C:\msys64\usr\bin\bash.exe -lc "ldd /mingw64/bin/libgexiv2-2.dll | grep -v libgexiv2 | grep '=>' | awk '{print \$3}'" 

foreach ($dep in $deps) {
    # Jika path mulai dengan /mingw64/bin/, konversikan ke path Windows
    if ($dep -match "^/mingw64/bin/(.+)$") {
        $base_name = $matches[1]
        Write-Host "Menyalin dependency: $base_name" -ForegroundColor Gray
        Copy-Item "C:\msys64\mingw64\bin\$base_name" "$libDir\"
    }
    elseif ($dep -match "^/") {
        # Jika path absolut di MSYS2, konversikan ke path Windows
        $base_name = Split-Path $dep -Leaf
        if (Test-Path "C:\msys64$dep") {
            Write-Host "Menyalin dependency dari path absolut: $base_name" -ForegroundColor Gray
            Copy-Item "C:\msys64$dep" "$libDir\"
        }
    }
    else {
        # Jika dependency langsung, salin dari bin
        $base_name = $dep
        Write-Host "Menyalin dependency langsung: $base_name" -ForegroundColor Gray
        if (Test-Path "C:\msys64\mingw64\bin\$base_name") {
            Copy-Item "C:\msys64\mingw64\bin\$base_name" "$libDir\"
        }
    }
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
    # FIX: Perbaiki sintaks kondisi PowerShell
    if ((Test-Path "C:\msys64\mingw64\bin\$lib") -and (-not (Test-Path "$libDir\$lib"))) {
        Write-Host "Menyalin library tambahan: $lib" -ForegroundColor Gray
        Copy-Item "C:\msys64\mingw64\bin\$lib" "$libDir\"
    }
}

# Tampilkan hasil
Write-Host "`nPengekstrakan library Windows selesai!" -ForegroundColor Green
Write-Host "Library tersimpan di: $libDir" -ForegroundColor Green
Write-Host "Daftar file:" -ForegroundColor Green
Get-ChildItem -Path $libDir
