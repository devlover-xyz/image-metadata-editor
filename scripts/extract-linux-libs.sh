#!/bin/bash
# Script untuk mengekstrak library Linux
# Simpan sebagai scripts/extract-linux-libs.sh
# Jalankan dengan: chmod +x scripts/extract-linux-libs.sh && sudo ./scripts/extract-linux-libs.sh

# Set umask untuk konsistensi file permission
umask 022

# Function untuk mengembalikan permission script jika perlu
revert_permissions() {
  # Pastikan script memiliki permission yang konsisten
  chmod 755 "$(readlink -f "$0")"
}

# Trap untuk membersihkan saat exit
trap revert_permissions EXIT

# Periksa apakah script dijalankan dengan sudo
if [ "$EUID" -ne 0 ]; then
  echo "Script ini memerlukan hak admin. Jalankan dengan sudo."
  exit 1
fi

# Deteksi distro
DISTRO=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

echo "Distro terdeteksi: $DISTRO"

# Instal dependencies berdasarkan distro
echo "Menginstal libgexiv2-dev..."
case $DISTRO in
    ubuntu|debian|pop|mint|elementary)
        apt-get update
        apt-get install -y libgexiv2-dev pkg-config
        ;;
    fedora|centos|rhel)
        dnf install -y gexiv2-devel pkgconfig
        ;;
    arch|manjaro|endeavouros)
        pacman -Sy --noconfirm gexiv2 pkgconf
        ;;
    *)
        echo "Distro tidak dikenali. Mencoba dengan apt..."
        apt-get update || true
        apt-get install -y libgexiv2-dev pkg-config || true
        
        if ! command -v pkg-config > /dev/null; then
            echo "Gagal menginstal pkg-config. Silakan instal libgexiv2-dev dan pkg-config secara manual."
            exit 1
        fi
        ;;
esac

# Buat direktori untuk menyimpan library
mkdir -p src-tauri/libs/linux/x86_64

# Cari lokasi library gexiv2
GEXIV2_PATH=$(pkg-config --variable=libdir gexiv2)/libgexiv2.so
if [ ! -f "$GEXIV2_PATH" ]; then
    echo "Mencari library gexiv2 di lokasi lain..."
    GEXIV2_PATH=$(find /usr/lib* -name "libgexiv2.so*" | head -n 1)
fi

if [ -z "$GEXIV2_PATH" ] || [ ! -f "$GEXIV2_PATH" ]; then
    echo "Tidak dapat menemukan libgexiv2.so"
    exit 1
fi

echo "GExiv2 library ditemukan di: $GEXIV2_PATH"

# Salin library utama
cp "$GEXIV2_PATH" src-tauri/libs/linux/x86_64/libgexiv2.so
if [ $? -ne 0 ]; then
    echo "Gagal menyalin library utama"
    exit 1
fi

# Cari dependencies
echo "Menyalin dependencies..."
DEPS=$(ldd "$GEXIV2_PATH" | grep "=> /" | awk '{print $3}')
for dep in $DEPS; do
    base_name=$(basename "$dep")
    # Skip lib standar sistem
    if [[ "$base_name" != libc.so* && "$base_name" != libm.so* && 
          "$base_name" != libdl.so* && "$base_name" != libpthread.so* && 
          "$base_name" != librt.so* && "$base_name" != "ld-linux"* ]]; then
        echo "Menyalin dependency: $base_name"
        cp "$dep" "src-tauri/libs/linux/x86_64/$base_name"
    fi
done

# Buat script untuk menyetting LD_LIBRARY_PATH jika diperlukan
cat > src-tauri/libs/linux/run_with_libs.sh << 'EOF'
#!/bin/sh
# Script ini dijalankan sebelum aplikasi utama untuk menyetting LD_LIBRARY_PATH

# Tambahkan direktori dengan library ke LD_LIBRARY_PATH
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$SCRIPT_DIR/x86_64:$LD_LIBRARY_PATH"

# Jalankan aplikasi
exec "$@"
EOF

chmod +x src-tauri/libs/linux/run_with_libs.sh

# Fix permission untuk semua file yang dibuat
find src-tauri/libs/linux -type f -exec chmod 644 {} \;
find src-tauri/libs/linux -type d -exec chmod 755 {} \;
chmod +x src-tauri/libs/linux/run_with_libs.sh

# Tampilkan hasil
echo -e "\nPengekstrakan library Linux selesai!"
echo "Library tersimpan di: src-tauri/libs/linux/x86_64/"
echo "Daftar file:"
ls -la src-tauri/libs/linux/x86_64/
