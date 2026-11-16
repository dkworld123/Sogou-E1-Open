#!/usr/bin/env bash
# ============================================================
#  E1 Qt5 录音器 —— 交叉编译（在 WSL2 Ubuntu 22.04 内运行，离线）
#
#  工具链：Bootlin aarch64 glibc stable-2018.02（GCC 6.x / glibc 2.26）
#          —— 与设备 Buildroot 2018.02-rc3 / glibc 2.26 完全匹配。
#  Qt 源码：Qt 5.9.4（qtbase + qtdeclarative），已预先下载到工程目录。
#  产物：交叉编译出的 Qt 5.9.4 host 工具(moc/qmake/rcc) + 目标库 + 头文件，
#        再用它编出 e1recorder（aarch64）。部署时只推 e1recorder + main.qml，
#        运行时复用设备自带的 Qt 5.9.4（同版本/同 glibc，ABI 一致）。
#
#  前提（在本 Ubuntu 里执行一次）：
#    sudo apt-get update
#    sudo apt-get install -y build-essential git python3 perl flex bison gperf \
#        pkg-config wget xz-utils patchelf
#    （注意：不要装 libxkbcommon-dev / libfontconfig-dev 等 *-dev，
#      否则会被错误链进 aarch64 产物，导致架构/符号错乱）
#
#  用法：  cd <REPO>/e1_qt5_recorder
#          bash build_e1_qt5.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TC_TARBALL="$PROJ_ROOT/toolchain/bootlin-stable-2018.02.tar.bz2"
QT_TARBALL_BASE="$PROJ_ROOT/qt_src/qtbase-opensource-src-5.9.4.tar.xz"
QT_TARBALL_DECL="$PROJ_ROOT/qt_src/qtdeclarative-opensource-src-5.9.4.tar.xz"
LIBASOUND_DIR="$SCRIPT_DIR/libs"

# 工作目录放 WSL2 本地 ext4，避免 /mnt/c 跨文件系统慢
WORK="$HOME/e1_build"
TC_DIR="$WORK/toolchain"
SRC_DIR="$WORK/src"
QT_PREFIX="$WORK/qt5.9.4-install"
APP_DIR="$SCRIPT_DIR"

echo "== 工程根: $PROJ_ROOT =="
echo "== 工作目录: $WORK =="

# ---------- 0) 检查预下载文件 ----------
for f in "$TC_TARBALL" "$QT_TARBALL_BASE" "$QT_TARBALL_DECL"; do
  if [ ! -f "$f" ]; then
    echo "[!] 缺少预下载文件: $f"
    echo "    请先在 Windows 侧确认沙箱已把它下载到工程目录（见 download 状态），"
    echo "    或自行把对应文件放到 $PROJ_ROOT/toolchain 与 $PROJ_ROOT/qt_src。"
    exit 1
  fi
done

# ---------- 1) 解包 Bootlin 工具链 ----------
mkdir -p "$TC_DIR"
if ! ls "$TC_DIR"/*/bin/*gcc >/dev/null 2>&1; then
  echo "== 解包 Bootlin 工具链 =="
  tar xf "$TC_TARBALL" -C "$TC_DIR"
fi
# 自动定位工具链 gcc（兼容任意前缀：aarch64-linux-gnu-* 或 aarch64-buildroot-linux-gnu-* 等）
REAL_GCC=$(ls "$TC_DIR"/*/bin/*gcc 2>/dev/null | head -1)
[ -n "$REAL_GCC" ] || { echo "[!] 找不到工具链 gcc"; exit 1; }
TC_BIN=$(dirname "$REAL_GCC")
# 推断真实前缀，如 aarch64-linux-gnu-gcc -> aarch64-linux-gnu-
PREFIX=$(basename "$REAL_GCC"); PREFIX=${PREFIX%-gcc}-
echo "    工具链前缀: $PREFIX"
"$REAL_GCC" --version | head -1

# 建 aarch64-linux-gnu-* 软链（Qt mkspec 期望此前缀），加入 PATH
mkdir -p "$WORK/hostbin"
for t in gcc g++ ld ar nm objcopy objdump strip ranlib; do
  if [ -e "$TC_BIN/${PREFIX}$t" ]; then
    ln -sf "$TC_BIN/${PREFIX}$t" "$WORK/hostbin/aarch64-linux-gnu-$t"
  fi
done
export PATH="$WORK/hostbin:$PATH"
export CROSS=aarch64-linux-gnu-

# 宿主编译器降级为 gcc-9：Ubuntu 22.04 默认 gcc-11 编不动 Qt 5.9.4 的
# host 工具（moc/rcc/qmake 的编译会撞 C++ 标准变更）。仅 host 部分使用
# gcc-9；aarch64 目标库由上面 Bootlin 工具链（GCC 6.4）编译，不受影响。
if command -v gcc-9 >/dev/null 2>&1; then
  export CC=gcc-9 CXX=g++-9
  echo "    宿主编译器: $(gcc-9 --version | head -1)"
else
  echo "[!] 未找到 gcc-9；请先运行 e1_build_env.sh 安装。继续用默认 $(gcc --version|head -1) 可能失败。"
fi

# ---------- 2) 解包 Qt 源码 ----------
mkdir -p "$SRC_DIR"
[ -d "$SRC_DIR/qtbase-opensource-src-5.9.4" ] || tar xf "$QT_TARBALL_BASE" -C "$SRC_DIR"
[ -d "$SRC_DIR/qtdeclarative-opensource-src-5.9.4" ] || tar xf "$QT_TARBALL_DECL" -C "$SRC_DIR"

# ---------- 3) 交叉编译 Qt 5.9.4 qtbase ----------
cd "$SRC_DIR/qtbase-opensource-src-5.9.4"
if [ ! -x "$QT_PREFIX/bin/qmake" ]; then
  echo "== 配置并编译 qtbase（这步较久，约 20~40 分钟）=="
  ./configure -release -opensource -confirm-license \
    -xplatform linux-aarch64-gnu-g++ \
    -prefix "$QT_PREFIX" \
    -no-opengl -linuxfb -no-xcb -no-glib -no-dbus \
    -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype \
    -no-icu -qt-double-conversion \
    -nomake examples -nomake tests
  make -j"$(nproc)"
  make install
else
  echo "== qtbase 已编译，跳过 =="
fi

# ---------- 4) 交叉编译 qtdeclarative ----------
cd "$SRC_DIR/qtdeclarative-opensource-src-5.9.4"
if [ ! -f "$QT_PREFIX/lib/libQt5Quick.so" ]; then
  echo "== 编译 qtdeclarative =="
  "$QT_PREFIX/bin/qmake"
  make -j"$(nproc)"
  make install
else
  echo "== qtdeclarative 已编译，跳过 =="
fi

echo "== Qt 5.9.4 交叉编译完成: $QT_PREFIX =="

# ---------- 4b) ALSA 开发头（仅编译期需要；asoundlib.h 内部用 <alsa/...> 引用子头）----------
# 注意：alsa-lib 源码把头文件扁平放在 include/ 下，但 asoundlib.h 用 <alsa/pcm.h> 等
#       引用子头，因此需要 staging 出一个 include/alsa/ 目录（把扁平头放进去），
#       才能用 -I 同时解析 <alsa/asoundlib.h> 与其内部的 <alsa/pcm.h>。
ALSA_TARBALL="$PROJ_ROOT/alsa_src/alsa-lib-1.1.9.tar.bz2"
if [ -f "$ALSA_TARBALL" ]; then
  ALSA_TOP=$(tar tf "$ALSA_TARBALL" | head -1 | cut -d/ -f1)
  [ -d "$WORK/$ALSA_TOP" ] || tar xf "$ALSA_TARBALL" -C "$WORK"
  ALSA_STAGE="$WORK/alsa_inc"
  rm -rf "$ALSA_STAGE"; mkdir -p "$ALSA_STAGE/alsa"
  cp -a "$WORK/$ALSA_TOP/include/"*.h "$ALSA_STAGE/alsa/" 2>/dev/null
  [ -d "$WORK/$ALSA_TOP/include/sound" ] && cp -a "$WORK/$ALSA_TOP/include/sound" "$ALSA_STAGE/alsa/" 2>/dev/null
  [ -e "$ALSA_STAGE/alsa/asoundlib.h" ] || cp -a "$WORK/$ALSA_TOP/include/asoundlib.h" "$ALSA_STAGE/alsa/" 2>/dev/null
  if [ -e "$ALSA_STAGE/alsa/asoundlib.h" ]; then
    export ALSA_INCLUDE="$ALSA_STAGE"
    echo "    ALSA 头文件(暂存): $ALSA_INCLUDE/alsa/asoundlib.h"
  else
    echo "[!] 未找到 asoundlib.h（ALSA 头布局异常）"
  fi
else
  echo "[!] 缺少 ALSA 源码: $ALSA_TARBALL"
  echo "    录音器编译将因找不到 asoundlib.h 而失败；请先把它下载到工程目录。"
fi

# ---------- 5) 编译录音器 App ----------
cd "$APP_DIR"
# 把设备 libasound 复制进链接 sysroot 并建软链（Linux 下 ln 可用）
SYSROOT_LIB="$WORK/sysroot_lib"
mkdir -p "$SYSROOT_LIB"
cp -f "$LIBASOUND_DIR"/libasound.so* "$SYSROOT_LIB/" 2>/dev/null || true
( cd "$SYSROOT_LIB" && ln -sf libasound.so.2.0.0 libasound.so.2 2>/dev/null; ln -sf libasound.so.2.0.0 libasound.so 2>/dev/null ) || true
export LIBASOUND_LIBDIR="$SYSROOT_LIB"

"$QT_PREFIX/bin/qmake" e1recorder.pro
make clean
make -j"$(nproc)"
ls -l e1recorder

# 去掉可能的 RPATH（指向构建机路径在设备上不存在），运行时靠 LD_LIBRARY_PATH 找设备 Qt
if command -v patchelf >/dev/null 2>&1; then
  patchelf --remove-rpath e1recorder 2>/dev/null || true
fi
file e1recorder 2>/dev/null || true

# 提取 DT_NEEDED 依赖清单（供 deploy_e1_qt5.sh 在设备侧做上线前自检，
# 避免“黑屏才发现缺库”）。aarch64-linux-gnu-readelf 由上面建的软链提供。
if command -v aarch64-linux-gnu-readelf >/dev/null 2>&1; then
  aarch64-linux-gnu-readelf -d e1recorder 2>/dev/null \
    | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p' | sort -u > e1recorder.needed
  echo "    DT_NEEDED 清单 -> $APP_DIR/e1recorder.needed"
  cat e1recorder.needed
else
  echo "[!] 未找到 aarch64-linux-gnu-readelf，跳过依赖清单生成（不影响编译）"
fi

echo
echo "编译完成 -> $APP_DIR/e1recorder (aarch64)。"
echo "下一步：回到 Windows，在工程目录执行  bash e1_qt5_recorder/deploy_e1_qt5.sh"
