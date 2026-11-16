#!/bin/sh
# ============================================================
# 下载第三方依赖到 deps/（该目录被 .gitignore 排除，不入库）
#
# 用法：
#   sh tools/fetch_deps.sh                 下载并校验全部
#   sh tools/fetch_deps.sh --skip-verify  跳过 sha256（不推荐）
#   CURL_OPTS=-kL sh tools/fetch_deps.sh 企业代理 MITM 时可加 -k（仍会做 sha256 校验）
#
# SHA256 来自本项目实测下载的文件。若上游重新打包导致校验失败，
# 请人工核对来源后更新下面的值，不要直接关掉校验。
# ============================================================
set -e
D=${DEPS_DIR:-deps}
CURL_OPTS=${CURL_OPTS:--fL}
VERIFY=1
[ "${1:-}" = "--skip-verify" ] && VERIFY=0
mkdir -p "$D"

fetch() {
    _name=$1; _url=$2; _sha=$3
    _out="$D/$_name"
    if [ -f "$_out" ] && [ "$VERIFY" = 1 ]; then
        _cur=$(sha256sum "$_out" | awk '{print $1}')
        if [ "$_cur" = "$_sha" ]; then echo "  [ok]    $_name (已存在且校验通过)"; return 0; fi
        echo "  [warn]  $_name 校验不符，重新下载"
    elif [ -f "$_out" ]; then
        echo "  [ok]    $_name (已存在，跳过校验)"; return 0
    fi
    echo "  [get]   $_name"
    curl $CURL_OPTS --retry 3 --max-time 300 -o "$_out.tmp" "$_url" || {
        echo "  [FAIL]  下载失败: $_url"; rm -f "$_out.tmp"; return 1;
    }
    mv "$_out.tmp" "$_out"
    if [ "$VERIFY" = 1 ]; then
        _cur=$(sha256sum "$_out" | awk '{print $1}')
        if [ "$_cur" != "$_sha" ]; then
            echo "  [FAIL]  SHA256 不符: $_name"
            echo "          expected $_sha"
            echo "          actual   $_cur"
            return 1
        fi
        echo "  [ok]    $_name SHA256 校验通过"
    fi
}

echo "=== 依赖下载目录: $D ==="
fetch lvgl-v9.2.2.tar.gz \
  "https://codeload.github.com/lvgl/lvgl/tar.gz/refs/tags/v9.2.2" \
  "129b4e00e06639fa79d7e8a6cab3c1ecce2445b1a246652ccd34f22e7b17ad6f"

fetch alsa-lib-1.1.9.tar.bz2 \
  "https://www.alsa-project.org/files/pub/lib/alsa-lib-1.1.9.tar.bz2" \
  "488373aef5396682f3a411a6d064ae0ad196b9c96269d0bb912fbdeec94b994b"

fetch bootlin-stable-2018.02.tar.bz2 \
  "https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/aarch64--glibc--stable-2018.02.tar.bz2" \
  "820b49314438639dbe0904ea95d88f615b8218a06f529749751911a2a39454d5"

fetch qtbase-opensource-src-5.9.4.tar.xz \
  "https://download.qt.io/archive/qt/5.9/5.9.4/submodules/qtbase-opensource-src-5.9.4.tar.xz" \
  "69e6bde3ab00673a77e1506173551fec7d0cd899fcbf9b1260517db1b61004cf"

fetch qtdeclarative-opensource-src-5.9.4.tar.xz \
  "https://download.qt.io/archive/qt/5.9/5.9.4/submodules/qtdeclarative-opensource-src-5.9.4.tar.xz" \
  "dc638a3b207dd2c6607a21415f6dd8d760568535dfe4b485fdb4576c98832d65"

fetch ubuntu-base-22.04-arm64.tar.gz \
  "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-arm64.tar.gz" \
  "075d4abd2817a5023ab0a82f5cb314c5ec0aa64a9c0b40fd3154ca3bfdae979f"

fetch alpine-minirootfs-aarch64.tar.gz \
  "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-minirootfs-3.18.4-aarch64.tar.gz" \
  "25500fd99b68a063bdd0951797d3cf37174541ce9e8da334bf1566583c87f0cc"

echo "=== 完成。文件在 $D/ ，不会被 git 跟踪 ==="
echo "    Ubuntu base 复制到 /mnt/sdcard/ubuntu-base.tar.gz 后可用 scripts/setup_rootfs.sh 解包"
