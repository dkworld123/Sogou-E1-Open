#!/bin/sh
# PC 端：把应用槽位交还原厂 App。freE1 的二进制与录音文件都保留，只是不再被启动。
set -e
ADB=${ADB:-adb}
S=${E1_SERIAL:-}
if [ -z "$S" ]; then S=$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'); fi
[ -n "$S" ] || { echo "E1: set E1_SERIAL=<your adb serial>" >&2; exit 1; }
"$ADB" start-server >/dev/null 2>&1
echo "=== 删除槽位文件 ==="
"$ADB" -s $S shell "rm -f /userdata/system/SogouE1; killall freE1 2>/dev/null || true; echo SLOT_REMOVED"
sleep 5
echo "=== 验证原厂 App 回归 ==="
"$ADB" -s $S shell "ps | grep -E 'freE1|SogouE1' | grep -v grep; echo '--- slot file ---'; ls -la /userdata/system/SogouE1 2>&1"
echo "ROLLBACK_DONE"
