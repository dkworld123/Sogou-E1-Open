#!/bin/sh
# ============================================================
# 在搜狗 E1 上解包 arm64 rootfs（设备端执行，busybox ash）
# 用法: sh setup_rootfs.sh alpine | ubuntu
# ============================================================
set -e
WHICH="$1"
[ -n "$WHICH" ] || WHICH=alpine

case "$WHICH" in
  alpine)
    TAR=/mnt/sdcard/alpine-minirootfs.tar.gz
    DST=/mnt/sdcard/e1linux/alpine
    ;;
  ubuntu)
    TAR=/mnt/sdcard/ubuntu-base.tar.gz
    DST=/mnt/sdcard/e1linux/ubuntu
    ;;
  *)
    echo "usage: sh setup_rootfs.sh alpine|ubuntu"; exit 1 ;;
esac

[ -f "$TAR" ] || { echo "[!] 缺少 $TAR"; exit 1; }
mkdir -p "$DST"

echo "== 解包 $TAR -> $DST =="
# 设备 BusyBox tar 1.27.2 不支持 -z，且可能无独立 gzip；
# 优先用管道 gzip -dc，失败则回退到设备上的 xz/内建自动探测。
if command -v gzip >/dev/null 2>&1; then
  gzip -dc "$TAR" | tar -xf - -C "$DST"
elif command -v busybox >/dev/null 2>&1 && busybox gzip --help >/dev/null 2>&1; then
  busybox gzip -dc "$TAR" | tar -xf - -C "$DST"
else
  tar -xf "$TAR" -C "$DST"   # 部分 tar 会自动探测 gzip
fi
echo "== 解包完成，顶层内容 =="
ls -la "$DST" | head -25

echo "== 写入 resolv.conf（DNS）=="
cat > "$DST/etc/resolv.conf" <<'EOF'
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 8.8.8.8
EOF

echo "== 建立 chroot 挂载点 =="
for d in dev proc sys dev/pts tmp run; do mkdir -p "$DST/$d"; done

echo "OK: $DST 就绪"
