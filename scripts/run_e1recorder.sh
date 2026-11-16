#!/bin/sh
# ============================================================
# 在 E1 的 Ubuntu chroot 里运行 Qt6 版 E1Recorder（设备端执行）
#
# 用法:
#   sh /mnt/sdcard/run_e1recorder.sh              # offscreen 冒烟测试（跑 6 秒后退出，不占屏）
#   sh /mnt/sdcard/run_e1recorder.sh offscreen   # 同上
#   sh /mnt/sdcard/run_e1recorder.sh linuxfb     # 尝试上 320x320 真屏（会抢显示，先停原厂 App）
#   sh /mnt/sdcard/run_e1recorder.sh forever     # offscreen 常驻（调试用）
# ============================================================
MODE="${1:-test}"
# BIN 是 chroot 内路径（供 chroot 里执行）；HOSTBIN 是设备宿主看到的真实路径（供存在性检查）
BIN=/opt/E1Recorder/build/E1Recorder
HOSTBIN=/mnt/sdcard/e1linux/ubuntu$BIN
LOG=/tmp/e1rec6.log
PIDF=/tmp/e1rec6.pid

[ -x "$HOSTBIN" ] || { echo "[!] 未找到 $HOSTBIN，请先编译 E1Recorder"; exit 1; }

mkdir -p /tmp/runtime-root
chmod 700 /tmp/runtime-root 2>/dev/null || true

case "$MODE" in
  linuxfb)
    # 设备 /dev/fb0 是假帧缓冲，真实显示走 DRM/KMS；此模式为试验性质
    QPA="linuxfb:fb=/dev/fb0:size=320x320:mmSize=320x320:offset=0x0"
    echo "== linuxfb 上屏模式（建议先 pkill -9 -f SogouE1）=="
    ;;
  *)
    QPA="offscreen"
    ;;
esac

START="cd /opt/E1Recorder/build && \
QT_QPA_PLATFORM=$QPA \
QT_QUICK_BACKEND=software \
XDG_RUNTIME_DIR=/tmp/runtime-root \
$BIN > $LOG 2>&1 & echo \$! > $PIDF"

sh /mnt/sdcard/enter_linux.sh ubuntu "$START"

if [ "$MODE" = "forever" ]; then
  echo "已在后台常驻，日志: $LOG  PID: $(cat $PIDF 2>/dev/null)"
  exit 0
fi

sleep 6
echo "== 进程 =="
ps | grep E1Recorder | grep -v grep | head -3 || echo "(进程已退出)"
echo "== 日志（空 = 无报错）=="
cat "$LOG" 2>/dev/null
echo "== 清理 =="
kill -9 "$(cat $PIDF 2>/dev/null)" 2>/dev/null || true
rm -f "$PIDF"
echo "done"
