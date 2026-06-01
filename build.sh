# ... (păstrează prima parte a scriptului neschimbată până la export PATH)

# TACTICA SALVATOARE PENTRU MAKEFILE-UL OEM:
# Exportăm variabilele critice direct în mediul Bash, ca Makefile-ul să le vadă instant
export CLANG_TRIPLE=aarch64-linux-android-
export CROSS_COMPILE=$NDK_BIN/aarch64-linux-android-
export CROSS_COMPILE_ARM32=$NDK_BIN/arm-linux-androideabi-

# Deficire argumente pentru Make (Păstrăm și aici pentru siguranță)
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

# Fix pentru erorile fatale de Git "ambiguous argument" din driverul Wi-Fi Qualcomm
echo "=== Configurare și păcălire Git pentru driverul Wi-Fi ==="
git config --local user.name "GitHub Action"
git config --local user.email "action@github.com"
git checkout -b temp-branch 2>/dev/null || git checkout temp-branch
git tag -a f35368d83 -m "Fix target revision for qcacld" 2>/dev/null || true

# Pasul 1: Generarea fișierului .config
echo "=== Pasul 1: Generare configurație ==="
# Adăugăm explicit CLANG_TRIPLE și direct în fața comenzii make
CLANG_TRIPLE=aarch64-linux-android- make "${MAKE_ARGS[@]}" sm8150_sec_r5q_eur_open_defconfig

# Pasul 2: Sincronizarea regulilor de Kconfig
echo "=== Pasul 2: Sincronizare și fixare Kconfig ==="
CLANG_TRIPLE=aarch64-linux-android- make "${MAKE_ARGS[@]}" olddefconfig

# Pasul 3: Compilarea imaginii finale
echo "=== Pasul 3: Compilare Kernel (Image.gz-dtb) ==="
CLANG_TRIPLE=aarch64-linux-android- make "${MAKE_ARGS[@]}" Image.gz-dtb

echo "=== 🎉 Compilare finalizată cu succes! ==="
