#!/bin/sh
# ============================================================
# 拉取上游开源项目到 vendor/（被 .gitignore 排除，不会被提交）
#
# 用法：
#   sh tools/fetch_upstream.sh            常用 4 个项目
#   sh tools/fetch_upstream.sh --all      含体积大的 Armbian build fork
#
# 说明：上游多数仓库**未声明 LICENSE**，本脚本只帮你取源码，
#       使用范围请自行判断，见 THIRD_PARTY.md。
#       优先走 codeload tarball（比 git clone 更能穿过部分代理）。
# ============================================================
set -e
D=${VENDOR_DIR:-vendor}
CURL_OPTS=${CURL_OPTS:--fL}
ALL=0
[ "${1:-}" = "--all" ] && ALL=1
mkdir -p "$D"

get_repo() {
    _owner=$1; _repo=$2; _branch=$3; _dir=$4
    _out="$D/$_dir"
    if [ -d "$_out" ] && [ -n "$(ls -A "$_out" 2>/dev/null)" ]; then
        echo "  [ok]    $_dir 已存在，跳过"; return 0
    fi
    echo "  [get]   $_owner/$_repo ($_branch)"
    _tmp="$D/.$_dir.tar.gz"
    _url="https://codeload.github.com/$_owner/$_repo/tar.gz/refs/heads/$_branch"
    if ! curl $CURL_OPTS --retry 2 --max-time 180 -o "$_tmp" "$_url"; then
        echo "  [warn]  $_branch 失败，试 master"
        _url="https://codeload.github.com/$_owner/$_repo/tar.gz/refs/heads/master"
        curl $CURL_OPTS --retry 2 --max-time 180 -o "$_tmp" "$_url" || {
            echo "  [FAIL]  $_owner/$_repo 下载失败"; rm -f "$_tmp"; return 1;
        }
    fi
    mkdir -p "$_out"
    tar -xzf "$_tmp" -C "$_out" --strip-components=1
    rm -f "$_tmp"
    echo "  [ok]    -> $_out"
}

echo "=== 上游源码目录: $D ==="
get_repo rossihwang       freE1        master  freE1
get_repo chopinshown      sogouE1      main    sogouE1
get_repo Hermes-Language  E1_Research  main    E1_Research
get_repo Hermes-Language  Armbian_E1   main    Armbian_E1

if [ "$ALL" = 1 ]; then
    echo "  [note]  build_e1 / u-boot 各 300–600 MB，请耐心"
    get_repo Hermes-Language build_e1 main build_e1
    get_repo seabird000      E1Recorder main E1Recorder
fi

echo "=== 完成 ==="
echo "    下一步：按 docs/UPSTREAM_PATCHES.md 应用适配 diff，再用 stage3/ 下的脚本编译。"
