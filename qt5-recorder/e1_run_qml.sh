#!/bin/sh
# e1_run_qml.sh — 在搜狗 E1 上用设备自带的 qmlscene 跑任意 QML 界面（零编译）。
# 用法（在 PC 上通过 adb 调用，或 adb shell 内运行）：
#   e1_run_qml.sh /tmp/xxx.qml [秒数]
# 要点：照搬原厂 /usr/bin/SogouLunch.sh 的 QT 环境变量（linuxfb + softwarecontext + evdev）。
# 注意：本机会先杀掉原厂 SogouE1 释放 fb0，运行结束后尝试恢复。
set -e

QML="$1"
SECONDS="${2:-10}"

if [ -z "$QML" ]; then
  echo "用法: e1_run_qml.sh <qml路径> [秒数]"
  exit 1
fi

# 杀原厂 App，释放帧缓冲
pkill -9 -f SogouE1 2>/dev/null || true
sleep 1

# —— 原厂官方环境变量（来自 /usr/bin/SogouLunch.sh）——
export QT_QPA_FB_DRM=1
export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=320x320:mmSize=320x320:offset=0x0:tty=/dev/ttyS4
export QMLSCENE_DEVICE=softwarecontext
export QT_QPA_EVDEV_KEYBOARD_PARAMETERS=/dev/input/event3:/dev/input/event1
export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS=/dev/input/event0:rotate=0
export QT_QPA_FONTDIR=/usr/share/fonts/
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins/
export LD_LIBRARY_PATH=/data/system/lib:/data:$LD_LIBRARY_PATH

echo "[*] 用 qmlscene 运行 $QML （$SECONDS 秒后自动退出）"
qmlscene "$QML" >/tmp/qml_last.log 2>&1 &
QPID=$!
sleep "$SECONDS"
kill -9 "$QPID" 2>/dev/null || true
echo "[*] 已结束 qmlscene"

# 恢复原厂界面
nohup /usr/bin/SogouE1 >/dev/null 2>&1 &
sleep 1
echo "[*] 已尝试恢复原厂 App（SogouE1）"
echo "--- qmlscene 日志（空=无报错）---"
cat /tmp/qml_last.log 2>/dev/null || true
