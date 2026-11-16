#!/bin/sh
# ==========================================================
# 搜狗 E1 B 槽：开机自动进入 E1 Linux（Ubuntu 22.04 arm64）
#
# 位置：/mnt/sdcard/e1_boot_linux.sh（userdata，可随时编辑）
# 调用：system_b 内 /etc/init.d/S98_e1linux 在开机时后台拉起
# 前提：原厂 adbd / WiFi / 8 麦 / DRM / bootcontrol 全部照常运行
#       —— 所以 adb 永远在线，随时可 updateEngine --misc=other 切回 A。
#
# 可调开关（改本文件即可，无需重刷分区）：
#   E1_TAKE_OVER_DISPLAY=1  停掉原厂 App 并尝试 Qt6 linuxfb 上屏（试验性）
#   E1_START_RECORDER=0     不自动启动 E1Recorder
# ==========================================================
ROOT=/mnt/sdcard/e1linux/ubuntu
MARK=/mnt/sdcard/e1_slot_b.status
BIN=/opt/E1Recorder/build/E1Recorder
E1_TAKE_OVER_DISPLAY=0
E1_START_RECORDER=1

echo "=== [E1 Linux] boot hook begin ==="
echo "kernel : $(uname -a)"
echo "cmdline: $(cat /proc/cmdline)"

[ -d "$ROOT" ] || { echo "[!] missing chroot rootfs: $ROOT"; exit 1; }

# ---- 幂等挂载 chroot 环境（重启后挂载会丢，每次开机重挂）----
mounted() { grep -q " $1 " /proc/mounts 2>/dev/null; }
domount() {
    src="$1"; dst="$2"; type="$3"
    mkdir -p "$dst" 2>/dev/null || true
    mounted "$dst" && return 0
    if [ -n "$type" ]; then
        mount -t "$type" "$src" "$dst" 2>/dev/null || echo "[warn] mount $dst failed"
    else
        mount --bind "$src" "$dst" 2>/dev/null || echo "[warn] bind $dst failed"
    fi
}
domount /dev   "$ROOT/dev"      ""
domount devpts "$ROOT/dev/pts"  devpts
domount proc   "$ROOT/proc"     proc
domount sysfs  "$ROOT/sys"      sysfs
domount tmpfs  "$ROOT/tmp"      tmpfs
domount tmpfs  "$ROOT/run"      tmpfs
domount tmpfs  "$ROOT/dev/shm"  tmpfs

# DNS（国内 + 备用）
printf 'nameserver 223.5.5.5\nnameserver 119.29.29.29\n' > "$ROOT/etc/resolv.conf"

# ---- 可选：让 Qt6 App 抢屏（默认关闭，避免影响原厂 UI）----
if [ "$E1_TAKE_OVER_DISPLAY" = "1" ]; then
    killall SogouE1 2>/dev/null || true
    QPA="linuxfb:fb=/dev/fb0:size=320x320:mmSize=320x320:offset=0x0"
    echo "[E1 Linux] display takeover requested (experimental)"
else
    QPA="offscreen"
fi

# ---- 在 Ubuntu chroot 内启动 Qt6 E1Recorder ----
if [ "$E1_START_RECORDER" = "1" ] && [ -x "$ROOT$BIN" ]; then
    mkdir -p "$ROOT/tmp/runtime-root"
    chmod 700 "$ROOT/tmp/runtime-root" 2>/dev/null || true
    START="cd /opt/E1Recorder/build && QT_QPA_PLATFORM=$QPA QT_QUICK_BACKEND=software XDG_RUNTIME_DIR=/tmp/runtime-root $BIN > /tmp/e1rec6.log 2>&1 & echo \$! > /tmp/e1rec6.pid"
    chroot "$ROOT" /usr/bin/env -i \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        HOME=/root LANG=C.UTF-8 TERM=vt100 QT_QUICK_BACKEND=software \
        /bin/sh -c "$START"
    echo "[E1 Linux] E1Recorder launched with QPA=$QPA"
else
    echo "[E1 Linux] E1Recorder not started"
fi

# ---- 状态标记（adb 侧可据此确认 B 槽 Linux 确实起来了）----
{
    echo "slot_b_linux=OK"
    echo "timestamp=$(date 2>/dev/null)"
    echo "kernel=$(uname -a)"
    echo "cmdline=$(cat /proc/cmdline)"
    echo "chroot_root=$ROOT"
    echo "qpa=$QPA"
} > "$MARK"

echo "=== [E1 Linux] done; status -> $MARK ==="
