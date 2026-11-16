#!/bin/sh
# ============================================================
# Ubuntu chroot 安装后的额外配置（设备端执行）
#   - apt 国内源
#   - DNS
#   - 接入原厂 /etc/asound.conf（8c48kmic 等命名 PCM）
#   - 默认 profile（提示符、PATH、Qt 环境）
# ============================================================
set -e
ROOT=/mnt/sdcard/e1linux/ubuntu
[ -d "$ROOT" ] || { echo "[!] 未找到 $ROOT，请先运行 setup_rootfs.sh ubuntu"; exit 1; }

echo "== [1/4] 配置 apt 国内源（ubuntu-ports / HTTP）=="
cat > "$ROOT/etc/apt/sources.list" <<'EOF'
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ jammy-security main restricted universe multiverse
EOF

echo "== [2/4] DNS =="
cat > "$ROOT/etc/resolv.conf" <<'EOF'
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 8.8.8.8
EOF

echo "== [3/4] 接入原厂 ALSA 配置 =="
if [ -f /etc/asound.conf ]; then
  cp /etc/asound.conf "$ROOT/etc/asound.conf"
  echo "    已复制 /etc/asound.conf（含 8c48kmic / 8c96kmic）"
else
  echo "    [warn] 设备无 /etc/asound.conf，跳过（仍可用 hw:2,0 直接采集）"
fi

echo "== [4/4] 默认 profile =="
# ⚠️ 不要把原厂 /mnt/host/usrlib 写进 LD_LIBRARY_PATH（老 libstdc++ 会污染 Ubuntu 工具链）
#    不要把 QT_*_PLUGIN_PATH / QML2_IMPORT_PATH 指向原厂 Qt5 目录（会污染 Qt6）
cat > "$ROOT/etc/profile.d/e1linux.sh" <<'EOF'
# 搜狗 E1 上的 Ubuntu 22.04 arm64 (chroot)
# 原厂 Qt5 资源挂在 /mnt/host/usrlib、/mnt/host/usrqml，需要时显式指定，
# 绝不写入全局 LD_LIBRARY_PATH / QT_QPA_PLATFORM_PLUGIN_PATH。
export QT_QUICK_BACKEND=software
PS1='[E1-Ubuntu] \w # '
EOF
chmod 644 "$ROOT/etc/profile.d/e1linux.sh" 2>/dev/null || true

echo "OK: Ubuntu 额外配置完成"
