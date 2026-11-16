# 日常使用速查

> 第一次使用请先按 [`INSTALL.md`](INSTALL.md) 装好；所有命令默认在**仓库根目录**执行。
> 风险与禁忌见 [`NOTICE.md`](NOTICE.md)，排错见 [`FAQ.md`](FAQ.md)。

---

## 0. 每次开工先做

```sh
. scripts/e1_env.sh                    # 设置 ADB / E1_SERIAL / MSYS_NO_PATHCONV
adb devices -l                         # 确认在线（优先 USB）
adb -s "$E1_SERIAL" shell "cat /proc/cmdline | tr ' ' '\n' | grep slot_suffix"
```

`e1_env.sh` 还提供 `e1_adb shell ...` / `e1_adb push ...` 简写，等价于 `adb -s "$E1_SERIAL" ...`。

---

## 1. 录音相关

| 目的 | 命令 |
|---|---|
| 只列出笔上录音 | `python3 scripts/export_recordings.py --list` |
| 导出新录音 | `python3 scripts/export_recordings.py --out ./my_recordings` |
| 8 麦直录 10 秒并拉回 | `python3 scripts/export_recordings.py record --seconds 10` |
| 指定 adb 路径 | `python3 scripts/export_recordings.py --adb /path/to/adb.exe --list` |
| chroot 内录 8 麦 | `adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'arecord -D 8c48kmic -f S32_LE -r 48000 -c 8 -d 3 /root/rec.wav'"` |
| 拉回该 WAV | `adb -s "$E1_SERIAL" pull /mnt/sdcard/e1linux/ubuntu/root/rec.wav .` |

导出器用 `.e1_exported.json` 去重，纯只读、不写笔上内容。

---

## 2. chroot Linux

```sh
# 交互式进入（exit 退出）
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu"

# 单条命令
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'uname -a'"
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'apt-get install -y htop'"

# Qt6 E1Recorder 冒烟（offscreen，不占屏）
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/run_e1recorder.sh offscreen"
```

`enter_linux.sh` 用 `env -i` 启动，命令里写 `VAR=x cmd` 形式可正常传递。
**不要**把原厂 Qt5 / libstdc++ 路径混进环境变量（见 `NOTICE.md` 第 5 节）。

---

## 3. A/B 槽位

```sh
# 设备上执行（脚本需先 push 到 /mnt/sdcard/）
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh status"      # 只读
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh backup"      # 备份 misc
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh switch --go" # 切槽并重启

# 或直接调用原厂工具（推荐，等价且更透明）
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=now"       # 标记当前槽启动成功

# 回滚 misc
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh restore --go"
```

- 默认只读预演，**写操作必须显式加 `--go`**。
- 切槽约 20 秒上线；重启后以 `cmdline` 的 `slot_suffix` 为准复核，别只看命令返回码。
- 不要手改 `misc` 字节，也不要改 GPT / parameter。

---

## 4. 录音 App 与分槽

```sh
sh stage3/e1_app_switch.sh status                   # 只读：槽位 / launcher / 配置 / 进程
sh stage3/e1_app_switch.sh slots                   # A=chopin  B=freE1（默认）
sh stage3/e1_app_switch.sh slots factory freE1     # A 槽回纯原厂，B 槽 freE1
sh stage3/e1_app_switch.sh slots freE1 chopin      # 对调

sh stage3/e1_app_switch.sh freE1                   # 单槽模式：两槽都跑 freE1
sh stage3/e1_app_switch.sh chopin                  # 两槽都跑 chopin
sh stage3/e1_app_switch.sh factory                 # 两槽都回原厂 App

sh stage3/deploy_freE1.sh                          # 从 chroot 重新部署 freE1
sh stage3/rollback_freE1.sh                        # 回原厂 App
```

```sh
# 日志
adb -s "$E1_SERIAL" shell "tail -30 /mnt/sdcard/freE1/boot.log"
adb -s "$E1_SERIAL" shell "tail -30 /userdata/e1-recorder/audio.log"
adb -s "$E1_SERIAL" shell "tail -30 /mnt/sdcard/e1_boot_linux.log"
adb -s "$E1_SERIAL" shell "tail -10 /mnt/sdcard/e1_slot_dispatch.log"
```

注意：

- chopin 正常退出后会 `touch /userdata/e1-recorder/disabled` 并交还原厂 App；
  再想用它需 `rm -f` 该文件（`e1_app_switch.sh chopin` 已自动处理）。
- freE1 有「3 次崩溃自动回退」计数 `/userdata/freE1/cnt`，切换脚本会清零。
- freE1 的 HTTP 导出**无登录鉴权**，默认关闭，别在不可信 LAN 里开。
- 上屏要先 `pkill -9 -f SogouE1`；Qt 启动前 `echo 3 > /proc/sys/vm/drop_caches`。

---

## 5. 依赖与上游源码

```sh
sh tools/fetch_deps.sh                  # deps/：Ubuntu base / Alpine / alsa-lib / LVGL / Qt / 工具链
sh tools/fetch_upstream.sh              # vendor/：freE1 / sogouE1 / E1_Research / Armbian_E1
sh tools/fetch_upstream.sh --all        # 另加体积大的 build_e1 / E1Recorder
```

- `deps/`、`vendor/` 均被 `.gitignore` 排除，**不进仓库**。
- `fetch_deps.sh` 会做 SHA256 校验；企业代理 MITM 场景可用 `CURL_OPTS=-kL sh tools/fetch_deps.sh`，
  但校验不能关（`--skip-verify` 不推荐）。
- 上游多数仓库**未声明 LICENSE**，取到源码后请自行判断使用范围，见 [`../THIRD_PARTY.md`](../THIRD_PARTY.md)。

---

## 6. Windows 一键脚本

| 文件 | 作用 |
|---|---|
| `windows/install_e1_linux.bat` | 安装 chroot Ubuntu（检查设备 → 下载/推送 rootfs → 解包 → 配置 → 验证） |
| `windows/uninstall_e1_linux.bat` | 卸载挂载 + 删目录，恢复原厂 |
| `windows/build_and_deploy_e1.bat` | 构建并部署 Qt5 录音器 |
| `windows/install_wsl2_ubuntu.ps1` | 早期 WSL2 路线辅助脚本（本机 WSL 未安装，最终未采用） |

bat 里 `ROOT=%~dp0..`，即按**仓库根目录**定位 `scripts/` 与 `rootfs/`，不要单独把 bat 拷出去运行。

---

## 7. 一条命令回原厂

```sh
adb -s "$E1_SERIAL" shell "rm -f /userdata/system/SogouE1; killall freE1 2>/dev/null || true"
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"   # 如当前在 B 槽
```

完整回滚阶梯见 [`INSTALL.md`](INSTALL.md) 第 7 节。
