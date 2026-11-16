#!/usr/bin/env bash
# ============================================================
#  E1 Qt5 录音器 —— WSL2 构建环境初始化（在 WSL2 Ubuntu 22.04 内运行）
#
#  只需安装【宿主】构建依赖（x86_64 上的工具）。
#  交叉工具链（Bootlin aarch64 glibc 2.26）与 Qt 5.9.4 源码已预下载到
#  工程目录，由 build_e1_qt5.sh 离线使用 —— 不需要 Docker，也不需要
#  通过 apt 安装任何 *-arm64 / crossbuild 交叉工具链（它们的 GCC/glibc
#  版本与设备不匹配，且会与 Bootlin 工具链冲突）。
#
#  ⚠️ 不要装 libxkbcommon-dev / libfontconfig-dev 等 *-dev 宿主开发包，
#     否则可能被错误地链进 aarch64 产物，导致架构/符号错乱。
#
#  说明：宿主默认 gcc 是 11（Ubuntu 22.04），但 Qt 5.9.4 的 host 工具
#  （moc/rcc/qmake 的编译）在 GCC 11 下会因 C++ 标准变更而失败。因此
#  额外安装 gcc-9/g++-9，由 build_e1_qt5.sh 用 CC/CXX 指定只给 host 部分
#  使用；aarch64 目标库仍由 Bootlin 工具链（GCC 6.4）编译，不受此影响。
#
#  用法：  bash e1_build_env.sh
# ============================================================
set -e

echo "== [1/3] 更新 apt =="
sudo apt-get update

echo "== [2/3] 安装宿主构建依赖（仅 x86_64 宿主工具）=="
sudo apt-get install -y --no-install-recommends \
  build-essential git python3 perl flex bison gperf pkg-config \
  wget xz-utils patchelf file \
  gcc-9 g++-9

echo "== [3/3] 确认 gcc-9 可用 =="
gcc-9 --version | head -1 || { echo "[!] gcc-9 未安装成功"; exit 1; }

echo
echo "==================================================="
echo " 环境就绪。下一步（仍在 WSL2 Ubuntu 内）："
echo "   cd <REPO>/e1_qt5_recorder"
echo "   bash build_e1_qt5.sh"
echo "（编译完成后回到 Windows，运行  bash e1_qt5_recorder/deploy_e1_qt5.sh 部署）"
echo "==================================================="
