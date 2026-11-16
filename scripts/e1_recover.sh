#!/usr/bin/env bash
# e1_recover.sh —— 用 e1_stock_backup 把 E1 还原回原厂（写回 boot_a + system_a）
#
# 适用场景：
#   A) 设备还能 adb 启动到原厂/任意系统：直接 dd 写回备份即可。
#   B) 设备已无法启动（变砖）：需先进入 MaskROM（RK3308 短接 eMMC CLK↔GND 上电），
#      用 rkdeveloptool 写回 uboot/trust/boot_a/system_a 备份（本脚本只覆盖 A 场景的 dd 部分；
#      MaskROM 写回请参考 E1_ARMBIAN_PLAN.md 第 2 节）。
#
# 用法：
#   bash e1_recover.sh                 # 预演（默认）
#   bash e1_recover.sh --yes           # 真正写回并重启
#   bash e1_recover.sh --backup /path/to/e1_stock_backup/e1_backup --yes
set -u

ADB="${ADB:-adb}"
SERIAL="${E1_SERIAL:-$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1;exit}')}"
BACKUP_DIR="./e1_stock_backup/e1_backup"
DO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --yes)     DO=1 ;;
    --backup)  shift; BACKUP_DIR="$1" ;;
    --adb)     shift; ADB="$1" ;;
    --serial)  shift; SERIAL="$1" ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
  shift
done

echo "===== 搜狗 E1 还原原厂（写回 boot_a + system_a）====="
echo "[*] adb: $ADB   serial: $SERIAL"
echo "[*] 备份目录: $BACKUP_DIR"

if ! "$ADB" devices | grep -q "$SERIAL"; then
  echo "[!] 未检测到设备 $SERIAL（若已变砖无法 adb，请改用 MaskROM + rkdeveloptool，见方案文档）。"; exit 1
fi

for f in boot_a.img system_a.img uboot.img trust.img; do
  if [ ! -f "$BACKUP_DIR/$f" ]; then
    echo "[!] 备份缺失: $BACKUP_DIR/$f"; exit 1
  fi
done

echo
echo "---- 将执行（把原厂备份写回设备对应分区）----"
echo "  dd if=$BACKUP_DIR/boot_a.img  of=/dev/block/by-name/boot_a"
echo "  dd if=$BACKUP_DIR/system_a.img of=/dev/block/by-name/system_a"
echo "  (uboot/trust 启动器未动，无需还原；若启动器也坏了再用 MaskROM 写 uboot.img/trust.img)"
echo "---------------------------------------------"

if [ "$DO" -ne 1 ]; then
  echo
  echo "[*] 预演（dry run）。确认后加 --yes 真正写回。"
  exit 0
fi

echo
echo "[!] 开始写回原厂..."
set -e
"$ADB" -s "$SERIAL" shell "dd if=/mnt/sdcard/e1_flash/boot_a.img of=/dev/block/by-name/boot_a bs=1M" 2>/dev/null || true
# 若设备还能 adb，把备份先推过去再 dd（避免本地路径问题）
"$ADB" -s "$SERIAL" shell "mkdir -p /mnt/sdcard/e1_recover"
"$ADB" -s "$SERIAL" push "$BACKUP_DIR/boot_a.img" /mnt/sdcard/e1_recover/boot_a.img
"$ADB" -s "$SERIAL" push "$BACKUP_DIR/system_a.img" /mnt/sdcard/e1_recover/system_a.img
"$ADB" -s "$SERIAL" shell "dd if=/mnt/sdcard/e1_recover/boot_a.img of=/dev/block/by-name/boot_a bs=1M; dd if=/mnt/sdcard/e1_recover/system_a.img of=/dev/block/by-name/system_a bs=1M; sync; echo RECOVER_DONE"
echo "[+] 写回完成，设备即将重启回原厂固件。"
"$ADB" -s "$SERIAL" reboot || true
