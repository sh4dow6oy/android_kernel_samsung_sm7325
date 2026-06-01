#!/bin/bash

# Oprim scriptul la prima eroare întâmpinată pentru a nu rula pașii următori degeaba
set -e

# 1. Pregătire directoare
BASE_DIR=$(pwd)
TOOLCHAIN_DIR="$BASE_DIR/toolchain/ndk-clang"
mkdir -p "$TOOLCHAIN_DIR"

# 2. Descărcare și extragere Toolchain LLVM NDK r29
if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ]; then
    echo "=== Descărcare NDK Clang r29 ==="
    wget -q --show-progress -O llvm.tar.zst https://github.com/Ylarod/setup-ndk-clang/releases/download/prebuilt/clang-linux-x86-ndk-r29-r563880c.tar.zst
    
    echo "=== Extragere Toolchain ==="
    # Extragem temporar pentru a vedea exact structura folderului
    mkdir -p tmp_extract
    tar -I zstd -xf llvm.tar.zst -C tmp_extract/
    
    # Mutăm conținutul corect în folderul final (rezolvă problema structurii de directoare imbricate)
    if [ -d tmp_extract/bin ]; then
        mv tmp_extract/* "$TOOLCHAIN_DIR/"
    else
        mv tmp_extract/*/* "$TOOLCHAIN_DIR/" 2>/dev/null || mv tmp_extract/* "$TOOLCHAIN_DIR/"
    fi
    
    rm -rf tmp_extract llvm.tar.zst
fi

# Dublă verificare: s-a extras corect compilatorul?
if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ]; then
    echo "❌ EROARE CRITICĂ: Clang nu a fost găsit în $TOOLCHAIN_DIR/bin/clang după extragere!"
    exit 1
fi

# 3. Setări mediu globale explicite (Căi Absolute)
export ANDROID_BUILD_TOP="$BASE_DIR"
export ARCH=arm64
export SUBARCH=arm64
export DTC_EXT="$BASE_DIR/tools/dtc"
export CONFIG_BUILD_ARM64_DT_OVERLAY=y

# Calea către binarele compilatorului
NDK_BIN="$TOOLCHAIN_DIR/bin"
export CLANG_TRIPLE=aarch64-linux-android-
export CROSS_COMPILE="$NDK_BIN/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$NDK_BIN/arm-linux-androideabi-"

# 4. TACTICA SALVATOARE: Creăm folderul local de legături (symlinks)
mkdir -p "$BASE_DIR/tools/bin-links"
for tool in ar nm objcopy objdump strip ld.lld; do
    ln -sf "$NDK_BIN/llvm-$tool" "$BASE_DIR/tools/bin-links/llvm-$tool"
    ln -sf "$NDK_BIN/llvm-$tool" "$BASE_DIR/tools/bin-links/$tool"
done
ln -sf "$NDK_BIN/ld.lld" "$BASE_DIR/tools/bin-links/ld"

# Adăugăm în PATH
export PATH="$BASE_DIR/tools/bin-links:$NDK_BIN:$PATH"

# 5. Definire argumente pentru Make (Folosind căile absolute verificate)
MAKE_ARGS=(
    -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    SUBARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CC="$NDK_BIN/clang" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    LD="$NDK_BIN/ld.lld" \
    AR="$NDK_BIN/llvm-ar" \
    NM="$NDK_BIN/llvm-nm" \
    OBJCOPY="$NDK_BIN/llvm-objcopy" \
    OBJDUMP="$NDK_BIN/llvm-objdump" \
    STRIP="$NDK_BIN/llvm-strip" \
    HOSTCC=gcc \
    HOSTCXX=g++
)

# 6. Fix pentru driverul Wi-Fi Qualcomm (qcacld-3.0)
echo "=== Configurare și păcălire Git pentru driverul Wi-Fi ==="
git config --local user.name "GitHub Action"
git config --local user.email "action@github.com"
git checkout -b temp-branch 2>/dev/null || git checkout temp-branch
git tag -a f35368d83 -m "Fix target revision for qcacld" 2>/dev/null || true

# Curățăm folderul out dacă existau reziduuri de la build-uri eșuate
mkdir -p out

# Pasul 1: Generarea fișierului .config
echo "=== Pasul 1: Generare configurație ==="
make "${MAKE_ARGS[@]}" sm8150_sec_r5q_eur_open_defconfig

# Pasul 2: Sincronizarea regulilor de Kconfig
echo "=== Pasul 2: Sincronizare și fixare Kconfig ==="
make "${MAKE_ARGS[@]}" olddefconfig

# Pasul 3: Compilarea imaginii finale
echo "=== Pasul 3: Compilare Kernel (Image.gz-dtb) ==="
make "${MAKE_ARGS[@]}" Image.gz-dtb

echo "=== 🎉 Compilare finalizată cu succes! ==="
