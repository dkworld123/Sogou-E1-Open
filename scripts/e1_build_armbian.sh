#!/usr/bin/env bash
# e1_build_armbian.sh —— 搜狗 E1 的 Armbian 构建脚手架（在 Linux x86_64 主机上运行）
#
# 目标：产出 boot_a.img（LZ4 内核 + E1 DTB）与 system_a.ext4.img（Debian 根文件系统），
#       供 e1_flash.sh 刷入。策略是「保留原厂启动器，只换 boot_a + system_a」。
#
# ⚠️ 这是脚手架，不是一键脚本：RK3308 内核 + E1 专属硬件（8麦PDM/屏/触控/WiFi）需要你按实机调试 DTB 与驱动。
# ⚠️ 本机（Windows 沙箱）无法运行本脚本 —— 请在 WSL2 Ubuntu 22.04 + Docker，或独立 Linux x86_64 上跑。
#
# 用法：bash e1_build_armbian.sh all     # 依次执行 kernel / rootfs / pack
#       bash e1_build_armbian.sh kernel  # 只构建内核
#       bash e1_build_armbian.sh rootfs  # 只构建根文件系统
#       bash e1_build_armbian.sh pack    # 只打包镜像（需先有内核与根文件系统）
set -eu

WORKDIR="${E1_WORKDIR:-$PWD/e1_build}"
DTS_SRC="${E1_DTS_SRC:-$WORKDIR/extracted.dts}"   # 用仓库的 extracted.dts 作为 DTB 起点
CROSS="aarch64-linux-gnu-"
JOBS="$(nproc)"

KERNEL_REPO="${KERNEL_REPO:-https://github.com/armbian/linux-rockchip.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-rk-6.1-rk3308}"   # 按需调整；也可改用主线 torvalds/linux
ROOTFS_DIR="$WORKDIR/rootfs"
DEBIAN_SUITE="${DEBIAN_SUITE:-bookworm}"
BOOT_IMG="$WORKDIR/boot_a.img"
SYS_IMG="$WORKDIR/system_a.ext4.img"
SYS_SIZE_MB="${SYS_SIZE_MB:-380}"                  # 必须 < 400MB（system_a 分区上限）
PAGE_SIZE=2048
NEW_CMDLINE="root=/dev/mmcblk0p6 rootfstype=ext4 rootwait console=ttyFIQ0,1500000"

mkdir -p "$WORKDIR"

step_kernel() {
  echo "===== [1/3] 构建 RK3308 + E1 内核 ====="
  cd "$WORKDIR"
  if [ ! -d linux-rockchip ]; then
    git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" linux-rockchip
  fi
  cd linux-rockchip
  # 起点配置：RK3308 开发板 defconfig（最接近 E1）
  make ARCH=arm64 CROSS_COMPILE="$CROSS" defconfig 2>/dev/null || \
    make ARCH=arm64 CROSS_COMPILE="$CROSS" rockchip_defconfig
  echo ">>> TODO: 用 extracted.dts 生成 rk3308-e1.dtb，并开启以下驱动（按需 menuconfig）："
  echo "    - RK3308 PDM 麦克风阵列 + 音频 Codec"
  echo "    - 320x320 RGB LCD 面板 + 触摸 st1633i"
  echo "    - SDIO/USB WiFi + BT（按实机芯片选固件）"
  echo "    - CONFIG_KERNEL_LZ4=y（原厂 boot 镜像内核是 LZ4 压缩）"
  read -rp "按回车继续编译（请先确认已手工调整好 defconfig / DTB）..."
  make ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$JOBS" Image dtbs
  # 把 E1 DTB 放到 arch/arm64/boot/dts/rockchip/rk3308-e1.dtb（由 extracted.dts 编译）
  [ -f "$DTS_SRC" ] && dtc -I dts -O dtb "$DTS_SRC" -o arch/arm64/boot/dts/rockchip/rk3308-e1.dtb || \
    echo ">>> 未找到 $DTS_SRC，请手工放置 rk3308-e1.dtb"
  echo "[+] 内核产物: arch/arm64/boot/Image (+ rk3308-e1.dtb)"
}

step_rootfs() {
  echo "===== [2/3] 构建 Debian 根文件系统（debootstrap）====="
  sudo apt-get update && sudo apt-get install -y debootstrap qemu-user-static
  rm -rf "$ROOTFS_DIR"; mkdir -p "$ROOTFS_DIR"
  sudo debootstrap --arch=arm64 --foreign "$DEBIAN_SUITE" "$ROOTFS_DIR" http://deb.debian.org/debian
  sudo cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"
  sudo chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage
  sudo chroot "$ROOTFS_DIR" apt-get install -y openssh-server alsa-utils vim network-manager
  echo "[+] 根文件系统: $ROOTFS_DIR（可继续 chroot 定制，如设 root 密码、加用户）"
}

step_pack() {
  echo "===== [3/3] 打包 boot_a.img + system_a.ext4.img ====="
  cd "$WORKDIR"
  KIMG=linux-rockchip/arch/arm64/boot/Image
  DTB=linux-rockchip/arch/arm64/boot/dts/rockchip/rk3308-e1.dtb
  [ -f "$KIMG" ] || { echo "[!] 缺少内核 $KIMG"; exit 1; }
  [ -f "$DTB" ] || { echo "[!] 缺少 DTB $DTB（请先编译 rk3308-e1.dtb）"; exit 1; }
  # LZ4 压缩内核（与原厂一致）
  lz4 -f -9 "$KIMG" "$WORKDIR/Image.lz4" || sh -c "lz4c -c -9 $KIMG > $WORKDIR/Image.lz4"
  # 打包 Android boot 镜像（page_size=2048，DTB 放 --second）
  mkbootimg --kernel "$WORKDIR/Image.lz4" --second "$DTB" --pagesize "$PAGE_SIZE" \
            --cmdline "$NEW_CMDLINE" --os_version 11.0.0 --os_patch_level 2020-01-01 \
            -o "$BOOT_IMG"
  echo "[+] 生成 boot_a.img: $BOOT_IMG"
  # 打包 ext4 根文件系统
  rm -f "$SYS_IMG"; dd if=/dev/zero of="$SYS_IMG" bs=1M count="$SYS_SIZE_MB" status=none
  mkfs.ext4 -F -L e1root "$SYS_IMG"
  mkdir -p "$WORKDIR/mnt"
  sudo mount -o loop "$SYS_IMG" "$WORKDIR/mnt"
  sudo cp -a "$ROOTFS_DIR/." "$WORKDIR/mnt/"
  sudo umount "$WORKDIR/mnt"
  echo "[+] 生成 system_a.ext4.img: $SYS_IMG"
  echo "[*] 把这两个 .img 拷回 Windows，连上 E1 后运行：bash e1_flash.sh --boot boot_a.img --system system_a.ext4.img --yes"
}

case "${1:-all}" in
  kernel) step_kernel ;;
  rootfs) step_rootfs ;;
  pack)   step_pack ;;
  all)    step_kernel; step_rootfs; step_pack ;;
  *) echo "用法: $0 {all|kernel|rootfs|pack}"; exit 2 ;;
esac
echo "[done]"
