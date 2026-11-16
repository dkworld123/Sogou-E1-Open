#!/bin/sh
# ============================================================
# 搜狗 E1 A/B 槽位工具（设备端执行）
#
#   默认只读；所有会修改设备的操作必须显式加 --go，否则只打印 DRY-RUN。
#
#   用法：
#     sh slot_tool.sh status                 只读：槽位/cmdline/GUID/misc 元数据
#     sh slot_tool.sh backup                备份整个 misc 分区到 sdcard
#     sh slot_tool.sh arm      --go         预约切到另一槽（不重启）
#     sh slot_tool.sh switch   --go         切到另一槽并立即重启
#     sh slot_tool.sh markok                标记当前槽启动成功
#     sh slot_tool.sh restore  --go         从备份恢复 misc（回滚用）
#     sh slot_tool.sh loader   --go         重启进 Rockusb Loader（需 PC 侧工具）
#
#   依据（2026-11-13 真机核实）：
#     /usr/bin/updateEngine  V1.0.1  --misc=now / --misc=other / --reboot
#     /etc/init.d/S99_bootcontrol 开机自动 --misc=now
#     uboot.img 含 libavb_ab 状态机，misc+0x800 为 AvbABData(CRC32 BE)
# ============================================================

MISC=/dev/block/by-name/misc
BACKUP=/mnt/sdcard/misc.backup.img
MODE="${1:-status}"
GO="${2:-}"

status_slot() {
    echo "==== 当前启动槽 / cmdline ===="
    cat /proc/cmdline | tr ' ' '\n' | grep -E 'slot_suffix|^root=|rootfstype' 2>/dev/null
    echo
    echo "==== system_a / system_b 分区 GUID ===="
    for p in 6 7; do
        sgdisk -i "$p" /dev/mmcblk0 2>/dev/null | grep -iE 'Partition unique GUID|Partition name'
    done
    echo
    echo "==== misc+0x800 AvbABData (32B, busybox od -x) ===="
    dd if="$MISC" bs=1 skip=2048 count=32 2>/dev/null | od -x | head -3
    echo "  [布局] magic(4) | ver(2) | res(2) | A:pri,tries,succ,res(4) | B:(4) | last_boot(1) | res(11) | crc32_be(4)"
    echo
    echo "==== misc+0x1000 BCB 命令区 ===="
    dd if="$MISC" bs=1 skip=4096 count=64 2>/dev/null | od -c | head -4
    echo
    echo "==== 切槽工具 ===="
    ls -la /usr/bin/updateEngine /etc/init.d/S99_bootcontrol 2>/dev/null
}

need_go() {
    if [ "$GO" != "--go" ]; then
        echo "[DRY-RUN] 该操作会修改设备。确认后请显式加 --go："
        echo "          sh slot_tool.sh $MODE --go"
        echo
        status_slot
        exit 0
    fi
}

case "$MODE" in

  status)
    status_slot
    ;;

  backup)
    echo "== 备份 misc 分区 -> $BACKUP =="
    dd if="$MISC" of="$BACKUP" bs=1M count=1 2>/dev/null
    ls -la "$BACKUP"
    ;;

  arm)
    need_go
    echo "== 预约切换到另一槽（不重启，下次开机生效）=="
    /usr/bin/updateEngine --misc=other
    echo "-- 变更后 misc+0x800 / +0x1000 --"
    dd if="$MISC" bs=1 skip=2048 count=32 2>/dev/null | od -x | head -3
    dd if="$MISC" bs=1 skip=4096 count=64 2>/dev/null | od -c | head -3
    ;;

  switch)
    need_go
    [ -f "$BACKUP" ] || { echo "[!] 先执行 sh slot_tool.sh backup"; exit 1; }
    echo "== 切换到另一槽并立即重启 =="
    echo "   注意：B 槽当前与 A 槽逐字节相同，A 槽不会被改动。"
    /usr/bin/updateEngine --misc=other --reboot
    ;;

  markok)
    echo "== 标记当前槽启动成功（正常由 S99_bootcontrol 自动执行）=="
    /usr/bin/updateEngine --misc=now
    ;;

  restore)
    need_go
    [ -f "$BACKUP" ] || { echo "[!] 缺备份 $BACKUP"; exit 1; }
    echo "== 从备份恢复整个 misc 分区 =="
    dd if="$BACKUP" of="$MISC" bs=1M count=1 2>/dev/null
    echo "恢复完成"
    ;;

  loader)
    need_go
    echo "== 重启进 Rockusb Loader 模式 =="
    echo "   警告：adb 会断开，PC 侧需已备好 rkdeveloptool / RKDevTool 与驱动。"
    echo "   这是无需拆机的救砖通道；若工具未就绪请勿执行。"
    reboot loader
    ;;

  *)
    echo "用法: sh slot_tool.sh {status|backup|arm|switch|markok|restore|loader} [--go]"
    exit 1
    ;;
esac
