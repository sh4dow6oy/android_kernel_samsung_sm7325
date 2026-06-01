#!/bin/bash

# 1. Import Proton Clang (Toolchain LLVM modern și complet)
git clone --depth=1 https://github.com/kdrag0n/proton-clang.git toolchain/proton-clang
# Setting 
export ANDROID_BUILD_TOP=$(pwd)

# OEM & Architecture Setting
export ARCH=arm64
export SUBARCH=arm64

# Definirea căilor către Proton Clang
PROTON_BIN=$(pwd)/toolchain/proton-clang/bin
# Setăm compilatorul principal (Clang) din Proton
KERNEL_LLVM_BIN=$PROTON_BIN/clang
BUILD_CROSS_COMPILE=$PROTON_BIN/aarch64-linux-gnu-
BUILD_CROSS_COMPILE_ARM32=$PROTON_BIN/arm-linux-gnueabi-
CLANG_TRIPLE=aarch64-linux-gnu-

# Setări mediu pentru Device Tree / Overlays
export DTC_EXT=$(pwd)/tools/dtc
export CONFIG_BUILD_ARM64_DT_OVERLAY=y
# Cooking Kernel Source
mkdir -p out
# Setări globale de mediu pentru ca LLVM să fie recunoscut nativ în sursele Qualcomm/Samsung
export LLVM=1
export LLVM_IAS=1

# TACTICA SALVATOARE: Creăm un folder local de legături (symlinks) și îl punem în PATH.
mkdir -p $(pwd)/tools/bin-links

ln -sf $PROTON_BIN/llvm-ar $(pwd)/tools/bin-links/llvm-ar
ln -sf $PROTON_BIN/llvm-nm $(pwd)/tools/bin-links/llvm-nm
ln -sf $PROTON_BIN/llvm-objcopy $(pwd)/tools/bin-links/llvm-objcopy
ln -sf $PROTON_BIN/llvm-objdump $(pwd)/tools/bin-links/llvm-objdump
ln -sf $PROTON_BIN/llvm-strip $(pwd)/tools/bin-links/llvm-strip

export PATH="$(pwd)/tools/bin-links:$PATH"



MAKE_ARGS=(

    -j$(nproc --all) \

    ARCH=arm64 \

    CROSS_COMPILE="$BUILD_CROSS_COMPILE" \

    CROSS_COMPILE_ARM32="$BUILD_CROSS_COMPILE_ARM32" \

    CC="$KERNEL_LLVM_BIN" \

    CLANG_TRIPLE="$CLANG_TRIPLE" \

    LD="$PROTON_BIN/ld.lld" \

    AR="$PROTON_BIN/llvm-ar" \

    NM="$PROTON_BIN/llvm-nm" \

    OBJCOPY="$PROTON_BIN/llvm-objcopy" \

    OBJDUMP="$PROTON_BIN/llvm-objdump" \

    STRIP="$PROTON_BIN/llvm-strip" \

    HOSTCC=gcc \

    HOSTCXX=g++ \

    O=out

)



# Fix pentru erorile fatale de Git "ambiguous argument" din driverul Wi-Fi Qualcomm (qcacld-3.0)

echo "=== Configurare și păcălire Git pentru driverul Wi-Fi ==="

git config --global user.name "GitHub Action"

git config --global user.email "action@github.com"

git checkout -b temp-branch 2>/dev/null || true

git tag -a f35368d83 -m "Fix target revision for qcacld" 2>/dev/null || true



# Pasul 1: Generarea fișierului .config folosind configurația ta curată pentru R5Q

echo "=== Pasul 1: Generare configurație exclusivă sm8150_sec_r5q_eur_open_defconfig ==="

make "${MAKE_ARGS[@]}" sm8150_sec_r5q_eur_open_defconfig || exit 1



# Pasul 2: Sincronizarea regulilor de Kconfig în siguranță (fără merge_config)

echo "=== Pasul 2: Sincronizare și fixare Kconfig ==="

make "${MAKE_ARGS[@]}" olddefconfig || exit 1



# Pasul 3: Compilarea imaginii finale

echo "=== Pasul 3: Compilare Kernel (Image.gz-dtb) ==="

make "${MAKE_ARGS[@]}" Image.gz-dtb || exit 1
