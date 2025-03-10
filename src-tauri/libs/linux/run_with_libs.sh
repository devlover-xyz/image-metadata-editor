#!/bin/sh
# Script ini dijalankan sebelum aplikasi utama untuk menyetting LD_LIBRARY_PATH

# Tambahkan direktori dengan library ke LD_LIBRARY_PATH
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$SCRIPT_DIR/x86_64:$LD_LIBRARY_PATH"

# Jalankan aplikasi
exec "$@"
