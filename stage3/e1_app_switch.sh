#!/bin/sh
# PC 端（Git Bash）：管理搜狗 E1 开机启动的录音 App
#
#   sh e1_app_switch.sh slots [A方案] [B方案]   按槽位分发（推荐，默认 chopin/freE1）
#   sh e1_app_switch.sh freE1                  两槽都跑 freE1（会关掉分槽）
#   sh e1_app_switch.sh chopin                 两槽都跑 chopin（会关掉分槽）
#   sh e1_app_switch.sh factory                两槽都回原厂 App
#   sh e1_app_switch.sh status                 只读查看当前状态
#
# 方案可选值：freE1 | chopin | factory
# 说明：/userdata 是 A/B 共享分区，"各槽装各的"只能靠 SogouE1.dispatch 分发器实现。
set -e
ADB=${ADB:-adb}
S=${E1_SERIAL:-}
if [ -z "$S" ]; then S=$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'); fi
[ -n "$S" ] || { echo "E1: set E1_SERIAL=<your adb serial>" >&2; exit 1; }
D=/userdata/system
MODE=${1:-}
[ -n "$MODE" ] || { echo "usage: sh $0 slots [A] [B]|freE1|chopin|factory|status"; exit 1; }
"$ADB" start-server >/dev/null 2>&1

valid() { case "$1" in freE1|chopin|factory) return 0;; *) return 1;; esac; }

case "$MODE" in
  status)
    "$ADB" -s $S shell "echo '--- 槽位 ---'; cat /proc/cmdline | tr ' ' '\n' | grep -E 'slot_suffix|^root='; \
      echo '--- 生效 launcher ---'; head -2 $D/SogouE1 2>/dev/null; \
      echo '--- 分槽配置 ---'; cat $D/e1_slot_apps.conf 2>/dev/null | grep -v '^#' | grep .; \
      echo '--- 分发日志尾部 ---'; tail -6 /mnt/sdcard/e1_slot_dispatch.log 2>/dev/null; \
      echo '--- 进程 ---'; ps | grep -E 'freE1|qmlscene|recorderd|SogouE1' | grep -v grep || true"
    echo "STATUS_DONE"; exit 0;;
  slots)
    A=${2:-chopin}; B=${3:-freE1}
    valid "$A" || { echo "bad slot A: $A (expected freE1|chopin|factory)"; exit 1; }
    valid "$B" || { echo "bad slot B: $B (expected freE1|chopin|factory)"; exit 1; }
    SWITCH="printf 'SLOT_A=%s\\nSLOT_B=%s\\n' '$A' '$B' > $D/e1_slot_apps.conf; \
      cp $D/SogouE1.dispatch $D/SogouE1; chmod 755 $D/SogouE1"
    echo "=== 启用分槽：A=$A  B=$B ==="
    ;;
  freE1)
    echo "[提示] 单槽模式会覆盖分发器；恢复分槽请运行：sh $0 slots"
    SWITCH="cp $D/SogouE1.freE1 $D/SogouE1"
    ;;
  chopin)
    echo "[提示] 单槽模式会覆盖分发器；恢复分槽请运行：sh $0 slots"
    SWITCH="cp $D/SogouE1.chopin $D/SogouE1; rm -f /userdata/e1-recorder/disabled; \
      test -f /userdata/e1-recorder/current.version || echo 1.0.0 > /userdata/e1-recorder/current.version"
    ;;
  factory)
    echo "[提示] 这会删掉生效 launcher，A/B 两槽都回原厂；恢复分槽请运行：sh $0 slots"
    SWITCH="rm -f $D/SogouE1"
    ;;
  *)
    echo "unknown mode: $MODE (expected slots|freE1|chopin|factory|status)"; exit 1;;
esac

echo "=== 应用 $MODE ==="
"$ADB" -s $S shell "$SWITCH; chmod 755 $D/SogouE1 2>/dev/null || true; \
  sh -n $D/SogouE1 && echo LAUNCHER_SYNTAX_OK; \
  echo 0 > /userdata/freE1/cnt 2>/dev/null || true; \
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true; \
  P=\$(ps | grep '/userdata/system/SogouE1' | grep -v grep | head -1 | awk '{print \$1}'); \
  echo OLD_LAUNCHER=\$P; \
  if [ -n \"\$P\" ]; then kill -TERM \$P; \
  else killall freE1 qmlscene recorderd SogouE1 2>/dev/null || true; fi; \
  echo SWITCH_ISSUED"

echo "=== 等待 init 重新拉起 ==="
sleep 9
"$ADB" -s $S shell "echo '--- 当前 launcher ---'; head -2 $D/SogouE1 2>/dev/null; \
  echo '--- 进程 ---'; ps | grep -E 'freE1|qmlscene|recorderd|SogouE1' | grep -v grep; \
  echo '--- 分发日志 ---'; tail -4 /mnt/sdcard/e1_slot_dispatch.log 2>/dev/null; \
  echo '--- adb ---'; echo ONLINE"

echo "SWITCH_DONE ($MODE)"
