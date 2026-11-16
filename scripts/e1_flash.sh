#!/usr/bin/env bash
# e1_flash.sh —— 把 Armbian 镜像写入搜狗 E1 的 boot_a + system_a（保留原厂启动器，较低风险）
#
# 策略：不动 uboot/trust/misc（启动器），只替换 boot_a（内核+DTB）与 system_a（Debian 根文件系统）。
#       保留 boot_b/system_b 作为原厂后备槽。
#
# 用法：
#   bash e1_flash.sh                      # 只打印将做什么，不执行（默认）
#   bash e1_flash.sh --yes                # 真正写入并重启
#   bash e1_flash.sh --boot boot_a.img --system system_a.ext4.img --yes
#   bash e1_flash.sh --adb /path/adb.exe --serial <YOUR_SERIAL>
#
# 前置：E1 开机、USB 连好、adb 已开（开发者模式）。镜像先用 e1_build_armbian.sh 生成。
set -u

ADB="${ADB:-adb}"
SERIAL="${E1_SERIAL:-$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1;exit}')}"
BOOT_IMG="./boot_a.img"
SYS_IMG="./system_a.ext4.img"
DO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --yes)    DO=1 ;;
    --boot)   shift; BOOT_IMG="$1" ;;
    --system) shift; SYS_IMG="$1" ;;
    --adb)    shift; ADB="$1" ;;
    --serial) shift; SERIAL="$1" ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
  shift
done

echo "===== 搜狗 E1 刷 Armbian（boot_a + system_a）====="
echo "[*] adb: $ADB   serial: $SERIAL"
echo "[*] boot 镜像: $BOOT_IMG"
echo "[*] system 镜像: $SYS_IMG"

# 检查设备
if ! "$ADB" devices | grep -q "$SERIAL"; then
  echo "[!] 未检测到设备 $SERIAL，请确认 USB 连接 + adb 已开。"; exit 1
fi

# 检查镜像存在
for f in "$BOOT_IMG" "$SYS_IMG"; do
  if [ ! -f "$f" ]; then
    echo "[!] 找不到镜像: $f（请先用 e1_build_armbian.sh 生成，或用 --boot/--system 指定）"; exit 1
  fi
done

# 大小合理性检查（boot_a 分区 20MB；system_a 分区 400MB）
boot_bytes=$(stat -c%s "$BOOT_IMG" 2>/dev/null || echo 0)
sys_bytes=$(stat -c%s "$SYS_IMG" 2>/dev/null || echo 0)
if [ "$boot_bytes" -gt 20971520 ]; then
  echo "[!] boot 镜像 ${boot_bytes} 字节 > boot_a 分区 20MB，会写溢出！中止。"; exit 1
fi
if [ "$sys_bytes" -gt 419430400 ]; then
  echo "[!] system 镜像 ${sys_bytes} 字节 > system_a 分区 400MB，会写溢出！中止。"; exit 1
fi
echo "[*] boot 镜像: $((boot_bytes/1024)) KB；system 镜像: $((sys_bytes/1024/1024)) MB"

echo
echo "---- 将执行（设备端 dd，保留 uboot/trust/misc 不动）----"
echo "  adb push $BOOT_IMG -> /mnt/sdcard/e1_flash/boot_a.img"
echo "  adb push $SYS_IMG  -> /mnt/sdcard/e1_flash/system_a.ext4.img"
echo "  dd if=/mnt/sdcard/e1_flash/boot_a.img        of=/dev/block/by-name/boot_a"
echo "  dd if=/mnt/sdcard/e1_flash/system_a.ext4.img of=/dev/block/by-name/system_a"
echo "  sync && reboot"
echo "---------------------------------------------"

if [ "$DO" -ne 1 ]; then
  echo
  echo "[*] 这是预演（dry run）。确认无误后加 --yes 真正写入。刷机有风险，务必已做好 e1_stock_backup 备份。"
  exit 0
fi

echo
echo "[!] 开始写入（请确保供电稳定，过程中不要拔线/断电）..."
set -e
"$ADB" -s "$SERIAL" shell "mkdir -p /mnt/sdcard/e1_flash"
"$ADB" -s "$SERIAL" push "$BOOT_IMG" /mnt/sdcard/e1_flash/boot_a.img
"$ADB" -s "$SERIAL" push "$SYS_IMG" /mnt/sdcard/e1_flash/system_a.ext4.img
"$ADB" -s "$SERIAL" shell "dd if=/mnt/sdcard/e1_flash/boot_a.img of=/dev/block/by-name/boot_a bs=1M; dd if=/mnt/sdcard/e1_flash/system_a.ext4.img of=/dev/block/by-name/system_a bs=1M; sync; echo FLASH_DONE"
echo "[+] 写入完成，设备即将重启。若起不来，立即用 e1_recover.sh --yes 还原，或进入 MaskROM 救砖。"
"$ADB" -s "$SERIAL" reboot || true
