#!/bin/sh
# ==========================================================
# 在 E1 的 Ubuntu chroot 内构建 system_b 新镜像
# 运行位置：chroot 内 /e1_stage2/build_system_b.sh
# 输入：/e1_stage2/system_a.img（从 system_a 分区 dd 出的原厂镜像）
#       /e1_stage2/S98_e1linux、e1_slot_b_marker
# 输出：/e1_stage2/system_b.new.img（已 pad 到 400MB，整分区 md5 可校验）
# ==========================================================
set -e
cd /e1_stage2

echo "=== 1) 解包原厂 squashfs ==="
rm -rf root
unsquashfs -d root system_a.img > /dev/null
echo "    解包完成，文件数: $(find root | wc -l)"
echo "    非 root 属主条目数: $(find root ! -uid 0 | wc -l)"

echo "=== 2) 注入 B 槽专属文件 ==="
mkdir -p root/etc/init.d
cp S98_e1linux root/etc/init.d/S98_e1linux
chmod 755 root/etc/init.d/S98_e1linux
cp e1_slot_b_marker root/etc/e1_slot_b_marker
chmod 644 root/etc/e1_slot_b_marker

echo "=== 3) 重新打包（gzip / 128KB，与原厂参数一致）==="
rm -f system_b.new.img
mksquashfs root system_b.new.img -comp gzip -b 131072 -noappend -no-progress 2>&1 | tail -8
RAW=$(stat -c%s system_b.new.img)
echo "    打包后大小: $RAW bytes ($((RAW/1048576)) MB)"
[ "$RAW" -lt 419430400 ] || { echo "[!] 超过 400MB 分区，中止"; exit 1; }

echo "=== 4) 补零到分区大小（便于整分区 md5 校验）==="
truncate -s 419430400 system_b.new.img
ls -la system_b.new.img
md5sum system_b.new.img

echo "=== 5) 校验镜像内确实含钩子与标记 ==="
unsquashfs -l system_b.new.img | grep -E 'S98_e1linux|e1_slot_b_marker' || { echo "[!] 注入失败"; exit 1; }
echo "=== BUILD_OK ==="
