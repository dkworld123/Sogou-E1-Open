#!/bin/sh
# PC 端（Git Bash）：把设备 chroot 里编好的 freE1 部署到原厂可写应用槽位。
# 只写 /userdata/freE1/ 与 /userdata/system/SogouE1，不动任何只读分区。
# 回滚：sh rollback_freE1.sh
set -e
ADB=${ADB:-adb}
S=${E1_SERIAL:-}
if [ -z "$S" ]; then S=$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'); fi
[ -n "$S" ] || { echo "E1: set E1_SERIAL=<your adb serial>" >&2; exit 1; }
CH=/mnt/sdcard/e1linux/ubuntu/e1_freE1
BIN=$CH/freE1-master/build_e1ui/freE1
LAUNCH=$CH/e1ui-launch.sh

"$ADB" start-server >/dev/null 2>&1
echo "=== 1) 校验产物 ==="
"$ADB" -s $S shell "ls -la $BIN $LAUNCH; echo -n 'ELF magic: '; head -c 4 $BIN | od -An -tx1"

echo "=== 2) 备份槽位现状（若已有自定义 App）==="
"$ADB" -s $S shell "if [ -e /userdata/system/SogouE1 ]; then cp /userdata/system/SogouE1 /userdata/system/SogouE1.bak.\$(date +%s); echo BACKUP_MADE; else echo SLOT_EMPTY_FACTORY_DEFAULT; fi"

echo "=== 3) 安装两个文件 ==="
"$ADB" -s $S shell "mkdir -p /userdata/freE1 /userdata/system; cp $BIN /userdata/freE1/freE1; cp $LAUNCH /userdata/system/SogouE1; chmod 755 /userdata/freE1/freE1 /userdata/system/SogouE1; sh -n /userdata/system/SogouE1 && echo LAUNCHER_SYNTAX_OK; ls -la /userdata/freE1/freE1 /userdata/system/SogouE1"

echo "=== 4) 杀掉原厂 App，让 init 重跑 launcher ==="
"$ADB" -s $S shell "killall SogouE1 2>/dev/null || true; echo KILLED"

echo "=== 5) 等待并验证 ==="
sleep 6
"$ADB" -s $S shell "echo '--- 进程 ---'; ps | grep -E 'freE1|SogouE1' | grep -v grep; echo '--- boot.log ---'; tail -25 /mnt/sdcard/freE1/boot.log 2>/dev/null; echo '--- adb 仍在线 ---'; echo ONLINE"
echo "DEPLOY_DONE"
