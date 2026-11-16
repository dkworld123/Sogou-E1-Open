#!/usr/bin/env bash
# ============================================================
#  E1 Qt5 录音器 —— 部署并运行（在 PC 侧运行，需 adb + 已编译的 e1recorder）
#  只推 e1recorder（aarch64）到设备，运行时复用设备自带 Qt 5.9.4
#  （同为 5.9.4 / glibc 2.26，ABI 一致）。QML 已内嵌进二进制(qrc)，
#  因此设备侧只需 Qt 运行库 + QML 导入目录（/usr/qml）。
#  环境变量严格照抄原厂 /usr/bin/SogouLunch.sh（已实测渲染正常）。
#
#  用法：  bash deploy_e1_qt5.sh
#          SERIAL=xxxx bash deploy_e1_qt5.sh
#          bash deploy_e1_qt5.sh --replace-factory   # 覆盖原厂 App（开机自启）
# ============================================================
set -e

ADB=${ADB:-adb}
SERIAL=${E1_SERIAL:-${SERIAL:-$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1;exit}')}}
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SRC_DIR/e1recorder"
DEST=/userdata/e1_qt_rec
REPLACE_FACTORY=0
[ "$1" = "--replace-factory" ] && REPLACE_FACTORY=1

if [ ! -f "$BIN" ]; then
  echo "[!] 找不到 $BIN —— 请先在 WSL2 里跑 build_e1_qt5.sh 编译。" >&2
  exit 1
fi

echo "== 推送 e1recorder 到 $SERIAL:$DEST =="
"$ADB" -s "$SERIAL" shell "mkdir -p $DEST"
"$ADB" -s "$SERIAL" push "$BIN" "$DEST/e1recorder"
"$ADB" -s "$SERIAL" shell "chmod 755 $DEST/e1recorder"

# —— 上线前依赖自检：核对二进制 DT_NEEDED 的每一个库在设备上都能找到 ——
# 清单由 build_e1_qt5.sh 用交叉 readelf 生成（e1recorder.needed）。
NEEDED="$SRC_DIR/e1recorder.needed"
if [ -f "$NEEDED" ]; then
  echo "== 依赖自检（DT_NEEDED 是否都在设备上）=="
  MISS=0
  while read -r lib; do
    [ -z "$lib" ] && continue
    if "$ADB" -s "$SERIAL" shell "ls /data/system/lib/$lib /data/$lib /usr/lib/$lib /lib/$lib" 2>/dev/null | grep -q .; then
      echo "  [ok] $lib"
    else
      echo "  [缺] $lib  <- 设备上找不到，运行时将报 load/symbol error"
      MISS=1
    fi
  done < "$NEEDED"
  if [ "$MISS" = "1" ]; then
    echo "  ⚠️ 存在缺失依赖，仍会继续启动，但很可能黑屏/崩溃。请检查上面标 [缺] 的库。"
  else
    echo "  ✔ 所有动态依赖在设备上存在"
  fi
else
  echo "== 跳过依赖自检（未找到 $NEEDED，可能用旧版 build 脚本编译）。手动确认设备有 Qt5 运行库即可。"
fi


if [ "$REPLACE_FACTORY" = "1" ]; then
  echo "== 覆盖原厂 App（开机自启本程序）=="
  "$ADB" -s "$SERIAL" shell "mkdir -p /userdata/system && cp $DEST/e1recorder /userdata/system/SogouE1 && chmod 755 /userdata/system/SogouE1"
  "$ADB" -s "$SERIAL" reboot
  echo "    已设置。重启后直接启动本程序（恢复：删 /userdata/system/SogouE1）。"
  exit 0
fi

# —— 原厂官方 QT 环境变量（来自 /usr/bin/SogouLunch.sh，实测渲染正常）——
# QML2_IMPORT_PATH 指向设备自带 QML 导入（/usr/qml 含 QtQuick.2 等）。
ENV="\
QT_QPA_FB_DRM=1 \
QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=320x320:mmSize=320x320:offset=0x0:tty=/dev/ttyS4 \
QMLSCENE_DEVICE=softwarecontext \
QT_QUICK_BACKEND=software \
QT_QPA_EVDEV_KEYBOARD_PARAMETERS=/dev/input/event3:/dev/input/event1 \
QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS=/dev/input/event0:rotate=0 \
QT_QPA_FONTDIR=/usr/share/fonts/ \
QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins/ \
QML2_IMPORT_PATH=/usr/qml \
LD_LIBRARY_PATH=/data/system/lib:/data:/usr/lib"

echo "== 后台启动（日志 /tmp/e1rec.log；停止: adb shell pkill -9 -f e1recorder）=="
"$ADB" -s "$SERIAL" shell "pkill -9 -f SogouE1 2>/dev/null; pkill -9 -f e1recorder 2>/dev/null; sleep 1; cd $DEST && export $ENV && (./e1recorder >/tmp/e1rec.log 2>&1 &) ; sleep 2; echo started"
echo
echo "已启动。查看日志:  adb -s $SERIAL shell cat /tmp/e1rec.log"
echo "若黑屏：检查 /tmp/e1rec.log，确认 QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins 与 QML2_IMPORT_PATH=/usr/qml。"
