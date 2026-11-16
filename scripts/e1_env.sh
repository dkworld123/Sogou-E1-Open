#!/bin/sh
# ============================================================
# 通用环境片段：给二次开发 / 临时命令用（source 它，不要直接执行）
#
#   . scripts/e1_env.sh
#   e1_adb shell "cat /proc/cmdline"
#   e1_adb push foo.sh /mnt/sdcard/
#
# 约定：
#   ADB          adb 可执行文件，默认 PATH 里的 adb
#   E1_SERIAL    设备序列号，默认自动取 `adb devices` 的第一台
#   MSYS_NO_PATHCONV=1 在 Git Bash 下必须设置，否则 /mnt/sdcard/... 会被改写成 Windows 路径
# ============================================================
ADB=${ADB:-adb}
E1_SERIAL=${E1_SERIAL:-}

if [ -z "$E1_SERIAL" ]; then
    E1_SERIAL=$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}')
fi

if [ -z "$E1_SERIAL" ]; then
    echo "E1: 未发现设备。请先连接，或 export E1_SERIAL=<adb 序列号>" >&2
    return 1 2>/dev/null || exit 1
fi

export ADB E1_SERIAL
export MSYS_NO_PATHCONV=1

e1_adb() { "$ADB" -s "$E1_SERIAL" "$@"; }

# 仅在执行（而非 source）时打印状态
if [ "${0##*/}" = "e1_env.sh" ]; then
    echo "ADB=$ADB"
    echo "E1_SERIAL=$E1_SERIAL"
    "$ADB" -s "$E1_SERIAL" shell "cat /proc/cmdline" 2>/dev/null || true
fi
