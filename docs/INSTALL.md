# 安装说明

> **先读 [`NOTICE.md`](NOTICE.md)**：风险、免责、合规、隐私与操作禁忌都在那里。
> 本文只讲「怎么做」，按风险从低到高分成 L0–L3 四级，**建议逐级验证、逐级停止**。
> 只想要回录音的话，做完 **L0 就够了**。

---

## 0. 总览（风险分级）

| 级别 | 做什么 | 改动范围 | 需要重启 | 可逆性 | 适合谁 |
|---|---|---|---|---|---|
| **L0** | 导出录音 / 8 麦直录 | 无（纯只读） | 否 | 天然可逆 | 所有只想抢救录音的人 |
| **L1** | Ubuntu 22.04 arm64 chroot | `/mnt/sdcard` | 否 | 删目录即可 | 想在笔上编译 / 跑 Linux 的人 |
| **L2** | 开源录音 App + A/B 分槽 | `/userdata` | 否（进程重启） | 删一个文件 | 想让屏幕和按键重新有用的人 |
| **L3** | 改造 `system_b`，开机自启 Linux | **仅 `system_b` 分区** | 是（约 20 s） | 需 `dd` 回写备份 | 想研究 A/B 双系统的人 |

**依赖关系**：L2 的编译需要 L1（chroot 里的原生 gcc）；L3 的构建也需要 L1。
L0 完全独立。

---

## 1. 前置条件

### 1.1 设备侧

- 一支**你自己拥有的**搜狗 E1，能正常开机。
- 打开 adb：**通用设置 → 关于本机 → 连续点击「MAC 地址」→ 开发者模式 → 基本设置 → adb 打开**。
- 用 **USB 线**连接 PC（WiFi adb 会因省电掉线，切槽时尤其危险）。
- `adb shell id` 应返回 `uid=0(root)`。
- 先看一眼当前状态，记录在自己的笔记里：

```sh
adb devices -l
adb -s "$E1_SERIAL" shell "cat /proc/cmdline; cat /proc/version; df -h /userdata /mnt/sdcard"
```

### 1.2 PC 侧

| 工具 | 用途 | 备注 |
|---|---|---|
| Android Platform-Tools | `adb` / `adb pull` / `adb push` | 需在 PATH，或用 `ADB` 变量指向 `adb.exe` |
| Python 3 | 运行 `export_recordings.py` | 只用标准库 |
| `sh` / Git Bash | 执行 `*.sh` | Windows 建议 Git Bash |
| `curl` / `tar` / `sha256sum` | `tools/fetch_*.sh` 下载依赖 | 校验脚本内已固化 SHA256 |
| 可选 `squashfs-tools` | L3 重打包镜像 | 装在**设备的 chroot 内**，不是 PC |

### 1.3 环境约定

```sh
# Git Bash / sh
. scripts/e1_env.sh          # 设置 ADB、E1_SERIAL、MSYS_NO_PATHCONV=1
# 或手动：
export E1_SERIAL=<你的 adb 序列号>
export ADB=adb               # 可选：指向 adb.exe 完整路径
```

> `MSYS_NO_PATHCONV=1` 在 Git Bash 下**必须**设置，否则 `/mnt/sdcard/...` 会被改写成 Windows 路径。

### 1.4 备份（L3 必做，L1/L2 建议）

```sh
mkdir -p ./backups
# misc（1 MB）、原厂 system_b（400 MB）
adb -s "$E1_SERIAL" shell "dd if=/dev/block/by-name/misc of=/mnt/sdcard/misc.backup.img bs=1M count=1"
adb -s "$E1_SERIAL" shell "dd if=/dev/block/by-name/system_b of=/mnt/sdcard/system_b.orig.img bs=1M"
adb -s "$E1_SERIAL" pull /mnt/sdcard/misc.backup.img ./backups/
adb -s "$E1_SERIAL" pull /mnt/sdcard/system_b.orig.img ./backups/
md5sum ./backups/*            # 记下值，写进自己的笔记
```

`backups/` 已被 `.gitignore` 排除；**不要**把镜像提交到任何公开仓库。

---

## 2. L0 导出录音（只读，推荐先做）

```sh
python3 scripts/export_recordings.py --list
python3 scripts/export_recordings.py --out ./my_recordings
python3 scripts/export_recordings.py record --seconds 10     # 8 麦直录并拉回
```

脚本读 `/userdata/databases/E1-DATA.db` 与录音文件，用本地 `.e1_exported.json` 去重，
**不改笔上任何内容**。`my_recordings/`、`.e1_exported.json` 均被 `.gitignore` 排除。

验证：导出目录里出现按「日期_时间_标题」命名的 WAV / MP3；`--list` 的条数与笔上一致。

---

## 3. L1 设备本机 Linux（零刷机）

原理：不换内核、不换分区，把 arm64 rootfs 解包到 `/mnt/sdcard/e1linux/ubuntu`，
`mount --bind` 挂入 `/dev /proc /sys /dev/pts` 后 `chroot` 进去。原厂系统照常运行，
DRM 显示、触摸、8 麦 PDM 驱动全部由原厂内核提供。

```sh
# 1) 取依赖（Ubuntu base 22.04 arm64 / Alpine minirootfs / alsa-lib / LVGL / Qt）
sh tools/fetch_deps.sh

# 2) 安装（二选一）
#    Windows：双击 windows/install_e1_linux.bat
#    手动：按 windows/install_e1_linux.bat 里的顺序 push scripts/ 下 4 个脚本并依次执行

# 3) 验证
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'cat /etc/os-release; uname -a'"
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'arecord -L' "   # 应能看到 8c48kmic
```

常用命令见 [`USAGE.md`](USAGE.md)。详细实测记录见 [`E1_LINUX_INSTALLED.md`](E1_LINUX_INSTALLED.md)。

**卸载**：`windows/uninstall_e1_linux.bat`，或卸载挂载点后删掉 `/mnt/sdcard/e1linux` 目录，
无需重启即可完全恢复。

> ⚠️ `enter_linux.sh` 用 `env -i` 启动，**不要**把原厂 Qt5 / libstdc++ 路径混进
> `LD_LIBRARY_PATH` 或 `QT_QPA_PLATFORM_PLUGIN_PATH`，否则 `GLIBCXX_3.4.30 not found`。

---

## 4. L2 录音 App 与分槽分发（纯 userdata）

前提：已完成 L1，chroot 里有 gcc / `alsa-lib` 静态库 / LVGL 9.2.2。

```sh
# 1) 取上游源码（只下载到 vendor/，不入库）
sh tools/fetch_upstream.sh

# 2) 按 docs/UPSTREAM_PATCHES.md 的 diff 应用 3 处适配
#    （ALSA_CONFIG_PATH、QT_QPA_FONTDIR / drop_caches、去掉写死的 adb 序列号）

# 3) 把 stage3/ 下 3 个构建脚本 push 到设备，在 chroot 内执行（约 11 分钟，-j2）
#    下列路径是示例，按你实际 push 到的 chroot 目录调整
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'sh /e1_freE1/build_freE1_static.sh'"
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'sh /e1_chopin/build_recorderd_static.sh'"

# 4) 部署到原厂可写槽位（PC 端执行）
sh stage3/deploy_freE1.sh

# 5) 启用按槽分发：A=chopin(Qt Quick/DRM)，B=freE1(LVGL/fb0)
sh stage3/e1_app_switch.sh slots
sh stage3/e1_app_switch.sh status
```

验证清单：

| 检查 | 期望 |
|---|---|
| `file` 产物 | `ELF 64-bit ARM aarch64, statically linked`，`readelf -d` 无 `NEEDED` |
| launcher 语法 | `sh -n /userdata/system/SogouE1` 通过 |
| 进程 | `ps` 里出现 `freE1` 或 `qmlscene` + `recorderd` |
| 分区完整性 | `system_a/b`、`boot_a/b` 的 MD5 与安装前一致 |
| 槽位 | `cat /proc/cmdline` 里的 `androidboot.slot_suffix` 与分发日志一致 |

> 两套 App **共用同一个** `/userdata/system/SogouE1`，不能同时装两份；
> 分槽靠 `SogouE1.dispatch` 读 `/proc/cmdline` 后 `exec` 对应 launcher 实现
> （`userdata` 是 A/B 共享分区）。详见 [`E1_APPS_INSTALLED.md`](E1_APPS_INSTALLED.md)。

**回原厂**：`sh stage3/e1_app_switch.sh factory`，或
`adb -s "$E1_SERIAL" shell "rm -f /userdata/system/SogouE1"`。

---

## 5. L3 B 槽系统（写分区，请先备份）

> ⚠️ **这是唯一会改只读分区的步骤**。请确认已完成 §1.4 备份，并读过 `NOTICE.md` 第 1、5 节。
> 原理与逐字节证据见 [`E1_SLOT_SWITCH.md`](E1_SLOT_SWITCH.md)。

```sh
# 1) 只查看，别急着写
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh status"
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh backup"

# 2) 在设备 chroot 内准备 /e1_stage2/：
#    system_a.img（从 system_a dd 出的原厂镜像）、S98_e1linux、
#    e1_slot_b_marker、build_system_b.sh、e1_boot_linux.sh
#    然后在设备 chroot 内执行（脚本注释指定的运行位置是 /e1_stage2/）：
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/enter_linux.sh ubuntu 'sh /e1_stage2/build_system_b.sh'"
#    产出 /e1_stage2/system_b.new.img（对应设备路径 /mnt/sdcard/e1linux/ubuntu/e1_stage2/），pad 到 400 MB

# 3) 校验产物：superblock 参数与原厂一致（gzip / 128 KB block），且含钩子与标记
#    见 build_system_b.sh 末尾的自检输出 BUILD_OK

# 4) 写入（唯一不可逆步骤，务必确认路径）
adb -s "$E1_SERIAL" shell "dd if=/mnt/sdcard/e1linux/ubuntu/e1_stage2/system_b.new.img \
  of=/dev/block/by-name/system_b bs=1M; sync"

# 5) 切槽并重启（约 20 秒上线）
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"
```

**`boot_b` 不用改**：uboot 会自动把 DTB 里占位的 `root=PARTUUID=` 换成 `system_b` 的 GUID。
A 槽 / boot / uboot / trust / GPT 全程不动。

验证：重启后 adb 上线，`cat /proc/cmdline` 显示 `slot_suffix=_b`；
`/mnt/sdcard/e1_boot_linux.log` 有钩子输出；再 `--misc=other --reboot` 能切回 A 槽。

---

## 6. 安装后验证清单

- [ ] `adb devices -l` 在线，且是 USB 连接
- [ ] `cat /proc/cmdline` 的 `slot_suffix` 与预期槽位一致
- [ ] `system_a` / `boot_a` / `boot_b` 的 MD5 与安装前记录一致
- [ ] `/userdata/system/SogouE1` 存在且 `sh -n` 通过
- [ ] 目标 App 进程在跑，日志无 `Unknown PCM` / `dumb buffer` / `symbol not found`
- [ ] 录音能生成非零数据的 WAV（不是空文件）
- [ ] 至少完整走过一次「切到 B → 切回 A」回环
- [ ] 备份文件在 PC 上，且 MD5 已记录

---

## 7. 卸载与回滚速查

| 想回到 | 操作 |
|---|---|
| 原厂 App | `sh stage3/e1_app_switch.sh factory`（或删 `/userdata/system/SogouE1`） |
| 原厂 A 槽 | `adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"` |
| 原厂 misc | `adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh restore --go"` |
| 原厂 `system_b` | `adb -s "$E1_SERIAL" shell "dd if=/mnt/sdcard/system_b.orig.img of=/dev/block/by-name/system_b bs=1M; sync"` |
| 删掉 chroot | `windows/uninstall_e1_linux.bat` |
| 彻底变砖后的最后手段 | `adb reboot loader` + `rkdeveloptool`；再不行拆机短接 eMMC CLK↔GND 进 MaskROM（**未实跑验证**） |

---

## 8. 下一步

- 日常命令：[`USAGE.md`](USAGE.md)
- 排错：[`FAQ.md`](FAQ.md)
- 没做完的事：[`BACKLOG.md`](BACKLOG.md)
- 上游改动清单：[`UPSTREAM_PATCHES.md`](UPSTREAM_PATCHES.md)
