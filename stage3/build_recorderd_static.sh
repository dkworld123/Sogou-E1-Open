#!/bin/sh
# 在 E1 的 Ubuntu 22.04 arm64 chroot 内编译 chopinshown/sogouE1 的后端 recorderd。
# 上游用 macOS 版 Zig cc -target aarch64-linux-gnu.2.26；这里改用 chroot 原生 gcc
# + 全静态，复用 freE1 那一步编出的 /e1_freE1/alsa-out/lib/libasound.a，
# 同样绕开原厂 glibc 2.26 的版本限制。QML 界面直接用设备自带 /usr/bin/qmlscene。
ROOT=/e1_chopin/recorder-app
exec > /e1_chopin/build.log 2>&1
set -e
echo "=== $(date) chopin recorderd static build ==="
echo "gcc: $(gcc --version | head -1)"
ls -la /e1_freE1/alsa-out/lib/libasound.a
cd "$ROOT"
mkdir -p build
gcc -O2 -g -Wall -Wextra \
    -I/e1_freE1/alsa-out/include -Ivendor \
    recorderd.c wifi.c netaudio.c rtp_audio.c noise_reduce.c \
    -static -L/e1_freE1/alsa-out/lib \
    -lasound -lpthread -ldl -lm \
    -o build/recorderd
echo "=== 产物 ==="
file build/recorderd
ls -la build/recorderd
readelf -h build/recorderd | grep -E 'Class|Machine|Type:'
echo "CHOPIN_BUILD_OK"
