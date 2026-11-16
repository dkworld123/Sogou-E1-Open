#!/bin/sh
# 在 E1 的 Ubuntu 22.04 arm64 chroot 内执行（路径 /e1_freE1）。
# 产出：/e1_freE1/freE1-master/build_e1ui/freE1 —— aarch64 全静态 ELF。
ROOT=/e1_freE1
exec > "$ROOT/build.log" 2>&1
set -e
echo "=== $(date) freE1 static build start ==="
echo "gcc: $(gcc --version | head -1)"

echo "=== [1/3] 编译 alsa-lib 1.1.9 静态库 ==="
if [ ! -f "$ROOT/alsa-out/lib/libasound.a" ]; then
    cd "$ROOT"
    rm -rf alsa-lib-1.1.9
    tar -xjf alsa-lib-1.1.9.tar.bz2
    cd alsa-lib-1.1.9
    ./configure --prefix="$ROOT/alsa-out" --enable-static --disable-shared --disable-python 2>&1 | tail -15
    make -j2 2>&1 | tail -20
    mkdir -p "$ROOT/alsa-out/lib" "$ROOT/alsa-out/include/alsa/sound"
    cp src/.libs/libasound.a "$ROOT/alsa-out/lib/"
    cp include/*.h "$ROOT/alsa-out/include/alsa/"
    cp -r include/sound/. "$ROOT/alsa-out/include/alsa/sound/" 2>/dev/null || true
fi
ls -la "$ROOT/alsa-out/lib/libasound.a" "$ROOT/alsa-out/include/alsa/asoundlib.h"

echo "=== [2/3] 编译 freE1（LVGL 9.2.2 + 全静态）==="
cd "$ROOT/freE1-master"
make -f Makefile.e1local clean >/dev/null 2>&1 || true
make -f Makefile.e1local -j2 2>&1 | tail -30

echo "=== [3/3] 产物校验 ==="
file build_e1ui/freE1
ls -la build_e1ui/freE1
readelf -h build_e1ui/freE1 | grep -E 'Class|Machine|Type:'
echo "--- dynamic section（全静态应为无）---"
readelf -d build_e1ui/freE1 2>&1 | head -5
echo "--- NEEDED ---"
readelf -d build_e1ui/freE1 2>/dev/null | grep NEEDED || echo "none (fully static)"
echo "BUILD_OK"
