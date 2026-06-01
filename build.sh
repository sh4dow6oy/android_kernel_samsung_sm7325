#!/bin/bash

# Oprim scriptul la prima eroare întâmpinată
set -e

# 1. Descărcare și extragere Toolchain LLVM NDK r29
mkdir -p toolchain/ndk-clang
if [ ! -f "toolchain/ndk-clang/bin/clang" ]; then
    echo "=== Descărcare NDK Clang r29 ==="
    wget -O llvm.tar.zst https://github.com/Ylarod/setup-ndk-clang/releases/download/prebuilt/clang-linux-x86-ndk-r29-r563880c.tar.zst
    
    echo "=== Extragere Toolchain (necesită pachetul zstd) ==="
    # Extrage direct în folderul țintă
    tar -I zstd -xf llvm.tar.zst -C toolchain/ndk-clang --strip-components=1
    rm llvm.tar.zst
fi

# Setări mediu globale
export ANDROID_BUILD_TOP=$(pwd)
export ARCH=arm64
export SUBARCH=arm64

# Definirea căilor către NDK Clang
NDK_BIN=$(pwd)/toolchain/ndk-clang/bin
CLANG_TRIPLE=aarch64-linux-android-

# Setări mediu pentru Device Tree / Overlays
export DTC_EXT=$(pwd)/tools/dtc
export CONFIG_BUILD_ARM64_DT_OVERLAY=y

# Folderul de ieșire
mkdir -p out

# TACTICA SALVATOARE: Creăm folderul local de legături (symlinks)
# NDK Clang folosește prefixul 'llvm-' pentru utilitare
mkdir -p $(pwd)/tools/bin-links
for tool in ar nm objcopy objdump strip ld.lld; do
    ln -sf "$NDK_BIN/llvm-$tool" "$(pwd)/tools/bin-links/llvm-$tool"
    # Adăugăm link-uri și fără prefixul 'llvm-' pentru scripturile OEM încăpățânate
    ln -sf "$NDK_BIN/llvm-$tool" "$(pwd)/tools/bin-links/$tool"
done

# Mapare fallback pentru ld (linker)
ln -sf "$NDK_BIN/ld.lld" "$(pwd)/tools/bin-links/ld"

# Adăugăm folderul de link-uri și folderul NDK în PATH
export PATH="$(pwd)/tools/bin-links:$NDK_BIN:$PATH"

# Deficire argumente pentru Make (Full LLVM Setup)
MAKE_ARGS=(
    -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    SUBARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CC="$NDK_BIN/clang" \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    CROSS_COMPILE="$NDK_BIN/aarch64-linux-android-" \
    CROSS_COMPILE_ARM32="$NDK_BIN/arm-linux-androideabi-" \
    LD="$NDK_BIN/ld.lld" \
    AR="$NDK_BIN/llvm-ar" \
    NM="$NDK_BIN/llvm-nm" \
    OBJCOPY="$NDK_BIN/llvm-objcopy" \
    OBJDUMP="$NDK_BIN/llvm-objdump" \
    STRIP="$NDK_BIN/llvm-strip" \
    HOSTCC=gcc \
    HOSTCXX=g++
)

# Fix pentru erorile fatale de Git "ambiguous argument" din driverul Wi-Fi Qualcomm (qcacld-3.0)
echo "=== Configurare și păcălire Git pentru driverul Wi-Fi ==="
git config --local user.name "GitHub Action"
git config --local user.email "action@github.com"

git checkout -b temp-branch 2>/dev/null || git checkout temp-branch
git tag -a f35368d83 -m "Fix target revision for qcacld" 2>/dev/null || true

# Pasul 1: Generarea fișierului .config folosind configurația pentru R5Q
echo "=== Pasul 1: Generare configurație exclusivă sm8150_sec_r5q_eur_open_defconfig ==="
make "${MAKE_ARGS[@]}" sm8150_sec_r5q_eur_open_defconfig

# Pasul 2: Sincronizarea regulilor de Kconfig în siguranță
echo "=== Pasul 2: Sincronizare și fixare Kconfig ==="
make "${MAKE_ARGS[@]}" olddefconfig

# Pasul 3: Compilarea imaginii finale
echo "=== Pasul 3: Compilare Kernel (Image.gz-dtb) ==="
make "${MAKE_ARGS[@]}" Image.gz-dtb

echo "=== 🎉 Compilare finalizată cu succes! Verifică folderul out/arch/arm64/boot/ ==="
