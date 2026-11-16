#!/bin/sh
# ============================================================
# 进入搜狗 E1 上的 arm64 Linux（chroot）— 设备端执行
#
# 用法:
#   sh /mnt/sdcard/enter_linux.sh              # 交互式进 ubuntu
#   sh /mnt/sdcard/enter_linux.sh alpine       # 进 alpine
#   sh /mnt/sdcard/enter_linux.sh ubuntu 'uname -a; id'   # 执行一条命令
# ============================================================
set -e
NAME="${1:-ubuntu}"
CMD="$2"
ROOT=/mnt/sdcard/e1linux/$NAME

[ -d "$ROOT" ] || { echo "[!] 未找到 $ROOT，请先运行 setup_rootfs.sh $NAME"; exit 1; }

# ---- 幂等挂载（重复执行不会叠加）----
mounted() { grep -q " $ROOT\$2 " /proc/mounts 2>/dev/null; }

do_mount() {
  src="$1"; dst="$2"; type="$3"; opts="$4"
  mkdir -p "$dst" 2>/dev/null || true
  if ! grep -q " $dst " /proc/mounts 2>/dev/null; then
    if [ -n "$type" ]; then
      mount -t "$type" $opts "$src" "$dst" 2>/dev/null || echo "  [warn] mount $src -> $dst 失败"
    else
      mount --bind "$src" "$dst" 2>/dev/null || echo "  [warn] bind $src -> $dst 失败"
    fi
  fi
}

echo "== 准备 chroot 环境: $ROOT =="
do_mount /dev      "$ROOT/dev"      "" ""
do_mount devpts    "$ROOT/dev/pts"  devpts ""
do_mount /proc     "$ROOT/proc"     proc  ""
do_mount /sys      "$ROOT/sys"      sysfs ""
do_mount /tmp      "$ROOT/tmp"      "" ""
# 让 chroot 内能访问原厂系统资源（只读 bind）
mkdir -p "$ROOT/mnt/host" 2>/dev/null || true
do_mount /usr/lib  "$ROOT/mnt/host/usrlib" "" ""
do_mount /usr/qml  "$ROOT/mnt/host/usrqml" "" ""

# DNS（每次覆盖，保证可用）
cat > "$ROOT/etc/resolv.conf" <<'EOF'
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 8.8.8.8
EOF

# 环境变量：直接注入（不依赖 /etc/profile，Ubuntu base 不 source profile.d）
#
# ⚠️ 重要：LD_LIBRARY_PATH 绝不能包含原厂 /mnt/host/usrlib！
#    原厂是 glibc 2.26 + GCC 6.4 的 libstdc++(GLIBCXX 最高 3.4.22)，
#    而 Ubuntu 22.04 是 glibc 2.35 + GCC 12，cmake/g++/Qt6 需要
#    GLIBCXX_3.4.29/3.4.30。混入原厂库会导致 "version not found" 直接跑不起来。
#    原厂 Qt5 库只挂在 /mnt/host/ 下备用，需要时由单个命令显式指定，不进全局 env。
#
# 同理 QT_QPA_PLATFORM_PLUGIN_PATH / QML2_IMPORT_PATH 不能指向原厂 Qt5 目录，
# 否则 Qt6 会去加载 Qt5 的 platform 插件而崩溃。Qt6 用自带默认路径即可。
E1ENV="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
E1ENV="$E1ENV HOME=/root"
E1ENV="$E1ENV LANG=C.UTF-8"
E1ENV="$E1ENV TERM=vt100"
E1ENV="$E1ENV QT_QUICK_BACKEND=software"

if [ -n "$CMD" ]; then
  exec chroot "$ROOT" /usr/bin/env -i $E1ENV /bin/sh -c "$CMD"
else
  echo "== 进入 chroot（输入 exit 返回）=="
  exec chroot "$ROOT" /usr/bin/env -i $E1ENV /bin/sh -l
fi
