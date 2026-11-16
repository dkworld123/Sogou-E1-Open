# E1 阶段 3/4：两套开源录音 App 已安装，并按 A/B 槽分槽启动

执行时间：2026-11-13 20:50–21:45
设备：搜狗 E1，序列号 `<SERIAL>`，当前 **B 槽 Linux 版（freE1）**、**A 槽 = chopin Qt 版**，root adb 在线。
性质：**纯应用层替换，零刷机** —— 只写 `/userdata` 下的文件，没有碰 `boot_a/b`、`system_a/b`、uboot、trust、GPT。
第 1–4 节是阶段 3（装 App），**第 5 节是阶段 4（A/B 分槽）**。

---

## 0. 装了什么

| | `rossihwang/freE1` | `chopinshown/sogouE1` |
|---|---|---|
| 界面 | C + LVGL 9.2.2，深色 UI | Qt Quick（QML），用原厂 `/usr/bin/qmlscene` |
| 主程序 | `/userdata/freE1/freE1` 8,139,584 B | `/userdata/e1-recorder/releases/1.0.0/recorderd` 4,307,256 B |
| 上屏路径 | **写 `/dev/fb0`**（LVGL fbdev） | **走 DRM/KMS**（patched `libqlinuxfb.so` + `QT_QPA_FB_DRM=1`），不写 fb0 |
| 音频 | PDM 8 麦 `hw:2,0` → 48 kHz/24-bit 立体声 | 同左，ch6/ch7 主麦、ch0–5 用于降噪 |
| 特色 | 文档最全、断电恢复、1h 分段、耳机监听、HTTP 导出、电源管理 | 波形/回放/标记、6 麦 Wiener 降噪 + 耳机 A/B、WiFi RTP 音频桥 |
| 成熟度 | 作者实测 10h 采集 0 xrun | 仓库 2026-11-13 当天新建 |

**两个 App 共用同一个原厂可写槽位 `/userdata/system/SogouE1`，同一时刻只能跑一套。**
现在通过「按槽位分发的 launcher」让 A 槽开机跑 chopin、B 槽开机跑 freE1（见第 5 节）；
文件都在共享的 `/userdata/system/` 里，切换不重刷任何分区：

```
/userdata/system/SogouE1            # 当前生效（= 分发器副本）
/userdata/system/SogouE1.dispatch   # 分发器原件：按槽位 exec 对应 launcher
/userdata/system/e1_slot_apps.conf  # SLOT_A=chopin / SLOT_B=freE1
/userdata/system/SogouE1.freE1      # freE1 launcher
/userdata/system/SogouE1.chopin     # chopin launcher
```

源码与构建产物仍在 chroot 里（`/mnt/sdcard/e1linux/ubuntu/e1_freE1/`、`/e1_chopin/`），
本地脚本在 `stage3/`。

---

## 1. 怎么编出来的（关键：全静态）

作者原方案要求 Bootlin `aarch64--glibc--stable-2018.02`（gcc 6.4 / glibc 2.26）交叉工具链，
但那份是 x86_64 host 二进制，**在这台 aarch64 设备上跑不了**；而 chroot 里的 Ubuntu 22.04 是
glibc 2.35，动态编译会 `symbol not found`。

解法：**在设备自带 Ubuntu chroot 里用原生 gcc 11.4 做全静态链接**，把 libc 一起打进二进制，
就不依赖设备 glibc 版本了。

- `Makefile.e1local`（本地改版）：`CC=gcc`、`LDFLAGS=-static`、`LDLIBS=-lpthread -lasound -ldl -lm`
- ALSA 静态库：chroot 内从 `alsa-lib-1.1.9.tar.bz2` 现场 `./configure --enable-static --disable-shared` 编出 `libasound.a`（9.2 MB），头 staging 到 `alsa-out/include/alsa/`
- LVGL 9.2.2：codeload 下载 tag tarball，只取 `lvgl.h` / `lv_version.h` / `src/`（311 个 .c）放进 `hwtest/third_party/lvgl/`
- chopin 后端：上游用 macOS 版 Zig cc，改成本机 `gcc -static` 编译 `recorderd.c wifi.c netaudio.c rtp_audio.c noise_reduce.c`

产物校验：`ELF 64-bit LSB executable, ARM aarch64, statically linked`，`readelf -d` 无 `NEEDED`。
整轮编译在设备上耗时约 11 分钟（RK3308 4×A35 / 502 MB RAM，`-j2`）。

### 踩过的 5 个坑（都已修，脚本里已固化）
1. **chroot 缺 `bzip2`** → `apt install bzip2`，否则解不开 alsa-lib 的 `.tar.bz2`。
2. **静态链接顺序**：`-lm` 必须在 `-lasound` **之后**，否则 `libasound.a(pcm_ladspa/pcm_softvol)` 里的 `exp/pow/sqrtf` 报 undefined reference。
3. **静态 alsa-lib 把 prefix 写死成 chroot 路径**，运行时找 `/e1_freE1/alsa-out/share/alsa/alsa.conf` 失败 → `snd_pcm_open("hw:2,0")` 报 `Unknown PCM`。两个 launcher 都加了 `export ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf`（原厂确有此文件）。
4. **Qt 首次启动 `Failed to create dumb buffer`**：dmesg 是 `rockchip_gem_alloc_cma failed to allocate 204800 byte dma buffer` / `swiotlb buffer is full`。run.sh 里加 `sync; echo 3 > /proc/sys/vm/drop_caches` 后第二次启动成功，dmesg 出现 `vop_crtc_enable] Update mode to 320x320p2556`。
5. **chopin 的 `QT_QPA_FONTDIR`** 原写 `/usr/share/fonts`，对照原厂 `/usr/bin/SogouLunch.sh` 改成 `/data/fonts/`，并补 `QT_LINUXFB_DRM_LOGO`。

另外为避免和 freE1 抢 PDM 采集，B 槽开机钩子 `/mnt/sdcard/e1_boot_linux.sh` 的
`E1_START_RECORDER` 已从 `1` 改为 `0`（chroot 挂载照旧保留）。原版备份在
`stage2/e1_boot_linux.sh`。

---

## 2. 验证证据

### freE1
- 命令行冒烟：`wifi status` → `connected=1 ssid=<SSID> ip=192.168.x.x`；`shots` RC=0
- **真 8 麦录音**：`record --device --segment-sec 3` 跑 5 秒，日志 `arecord -D hw:2,0 -c 8 -r 48000 -f S32_LE`，共 253952 帧，生成 2 个 48 kHz/24-bit WAV（872 KB + 651 KB）
- 部署后 boot.log：`device UI up`、`fb0: 320x320 virt 320x320 bpp=32`、`fb0: unblanked`、`fb: flush ...`
- 进程 fd：打开 `/dev/fb0` + `/dev/input/event0,1,3`
- **抓 `/dev/fb0` 转 PNG 看到完整界面**：`22.7G 22h / STANDBY / 78%`、`00:00:00`、`DIRECTIONAL`、`MON`、绿色 `REC` 圆钮、`-- dBFS`（截图 `docs/images/freE1_screen.png`）

### chopin
- `E1_RECORDER_BACKEND_READY 1.0.0 storage=/mnt/sdcard/Recordings`
- `CAPTURE hw:2,0 rate=48000 channels=8 format=S32_LE ... selected_channels=6,7`
- `recorderd` fd 打开 `/dev/snd/pcmC2D0c`
- `qmlscene` fd 打开 **`/dev/dri/card0`** 与 event0/1/3，**没有** `/dev/fb0`
- dmesg：`rockchip-vop ff2e0000.vop: [drm:vop_crtc_enable] Update mode to 320x320p2556`
- `qml: E1_RECORDER_UI_READY 1.0.0`

> **重要认知**：两套上屏路径不同。chopin 走 DRM/KMS，所以「读 fb0 内容没变」**不能**说明它没上屏
> （fb0 里只是 freE1 留下的最后一帧；`/proc/fb` 为空、fb0 无驱动名，印证手记里「fb0 是假帧缓冲」）。
> 反过来看，freE1 写 fb0 是否送到物理屏，作者已在同款设备上实测过；如需百分百确认请肉眼看一下屏幕。

### 完整性
`system_a=38b7f94f…`、`system_b=41adf6a7…`、`boot_a=boot_b=34e91d77…` 与装 App 前完全一致；
`/proc/cmdline` 仍 `androidboot.slot_suffix=_b`；adb 全程在线。

---

## 3. 日常使用

在 PC 的 Git Bash 里（工作区根目录）：

```sh
# 分槽模式（当前默认，详见第 5 节）
sh stage3/e1_app_switch.sh slots                  # A=chopin B=freE1
sh stage3/e1_app_switch.sh slots factory freE1    # A 槽回纯原厂
sh stage3/e1_app_switch.sh status                 # 只读看状态

# 单槽模式（会覆盖分发器，两槽都跑同一个 App）
sh stage3/e1_app_switch.sh freE1
sh stage3/e1_app_switch.sh chopin
sh stage3/e1_app_switch.sh factory

# 看日志
adb -s "$E1_SERIAL" shell "tail -30 /mnt/sdcard/freE1/boot.log"
adb -s "$E1_SERIAL" shell "tail -30 /userdata/e1-recorder/audio.log"

# 完全回原厂（连文件都不留）
adb -s "$E1_SERIAL" shell "rm -f /userdata/system/SogouE1; killall freE1"
```

设备端等效操作就是 `cp` 一个 launcher 到 `/userdata/system/SogouE1` 再 `kill -TERM` 旧 launcher。

### 注意事项
- **chopin 的 launcher 在 App 正常退出后会 `touch /userdata/e1-recorder/disabled` 并 exec 原厂 App**（防崩溃设计）。之后再想用它需 `rm -f /userdata/e1-recorder/disabled`；`e1_app_switch.sh chopin` 已自动处理。
- **freE1 有 3 次崩溃回退**（`/userdata/freE1/cnt`），切换脚本会清零。
- 这个槽位本是原厂 OTA 用的；官方 2024-05-30 已停服，被覆盖概率极低。安装前槽位为空（原厂走 `/usr/bin/SogouE1`）。
- freE1 的 HTTP 导出默认关闭（设置页开启）；作者 `BACKLOG` 明确写了 **HTTP 无登录鉴权**，别在不受信任的 LAN 里开。
- 44.1 kHz 在 PDM 上 ch6/ch7 恒为 0；两项目都用 48 kHz。
- 设备 RTC 停在 2019，freE1 launcher 会 `ntpd` 校时（日志 `rtc: synced`）。
- B 槽开机钩子仍会挂载 Ubuntu chroot、写状态文件，但**不再自启 Qt6 E1Recorder**；想恢复把 `E1_START_RECORDER` 改回 `1`（改 userdata 即可，不用重刷分区）。
- **A 槽镜像仍是逐字节完整的原厂系统**（`system_a` MD5 未变），但分槽模式下开机 App 是 chopin；要「纯原厂体验」把 `SLOT_A=factory`。`updateEngine --misc=other --reboot` 随时切槽，与本次应用层改动互不影响。

---

## 4. 相关文件

| 文件 | 用途 |
|---|---|
| `stage3/e1_app_switch.sh` | 分槽 / 单槽 / 原厂 / status 四种模式（最常用） |
| `stage3/SogouE1.dispatch` | 按 A/B 槽位分发的 launcher 原件 |
| `stage3/e1_slot_apps.conf` | 分槽配置 `SLOT_A` / `SLOT_B` |
| `stage3/deploy_freE1.sh` | 从 chroot 重新部署 freE1 二进制 |
| `stage3/rollback_freE1.sh` | 回原厂 App |
| `stage3/build_freE1_static.sh` | chroot 内一键编 alsa-lib + LVGL + freE1 |
| `stage3/Makefile.e1local` | 全静态编译配置 |
| `stage3/build_recorderd_static.sh` | 全静态编译 chopin 后端 |
| `stage2/e1_boot_linux.no-recorder.sh` | 当前设备上的 B 槽开机钩子 |
| `docs/images/freE1_screen.png` | freE1 真实帧缓冲截图 |
| `docs/E1_GITHUB_PROJECTS.md` | 开源项目调研清单 |

---

## 5. 阶段 4：A/B 槽各跑一套（2026-11-13 21:35–21:45）

**结论：可以，但做法不是「各槽各装一份」**。`userdata` 是 A/B **共享分区**，
`/userdata/system/SogouE1` 这个原厂 OTA 槽位对两个槽是同一个文件；而 A/B 两个
`system` squashfs 的启动链完全相同：

```
/etc/inittab  ::respawn:/usr/bin/SogouLunchProbe.sh
  -> /usr/bin/SogouLunch.sh
  -> [ -f /userdata/system/SogouE1 ] && exec /userdata/system/SogouE1
     (否则 exec /usr/bin/SogouE1，即原厂 App)
```

所以只需把 `SogouE1` 换成**按槽位分发的 launcher**，A 槽和 B 槽开机就能各跑一套，
**一个分区都不用改**。

### 分发器怎么判槽
优先读 `/proc/cmdline` 的 `androidboot.slot_suffix=_a|_b`；老固件没有该字段时退回
`root=PARTUUID=2f2f0000…(A)` / `a96b0000…(B)`。**认不出槽位、配置缺失、目标 launcher
不存在 → 一律 `exec /usr/bin/SogouE1`**（最保守兜底）。

分发器还会顺手处理两个已知坑：切到 chopin 前删 `/userdata/e1-recorder/disabled` 并
`echo 3 > /proc/sys/vm/drop_caches`（保 DRM CMA 连续内存）；切到 freE1 前清零
`/userdata/freE1/cnt` 崩溃计数。判定日志写到 `/mnt/sdcard/e1_slot_dispatch.log`。

配置 `/userdata/system/e1_slot_apps.conf`：
```sh
SLOT_A=chopin   # 可选 freE1 | chopin | factory
SLOT_B=freE1
```

### 实测（两次重启，各约 20 秒上线）

| 槽 | cmdline | 分发结果 | 证据 |
|---|---|---|---|
| **A** | `slot_suffix=_a`、`root=PARTUUID=2f2f0000-…5d21` | `slot=A app=chopin` | 纯原厂 Buildroot（无 `/etc/e1_slot_b_marker`、无 `S98_e1linux`）；进程 `SogouE1.chopin` / `recorderd` / `qmlscene Main.qml`；`qmlscene` fd 打开 `/dev/dri/card0` + event0/1/3，`recorderd` 打开 `/dev/snd/pcmC2D0c`；日志 `E1_RECORDER_UI_READY` + `CAPTURE … selected_channels=6,7` |
| **B** | `slot_suffix=_b`、`root=PARTUUID=a96b0000-…272d` | `slot=B app=freE1` | 有 B 槽标记；`freE1 ui-dev` 在跑；`device UI up` 与 `fb: flush …` |

四个分区 MD5 全程未变：`system_a=38b7f94f…`、`system_b=41adf6a7…`、
`boot_a=boot_b=34e91d77…`。

### 用法
```sh
# 启用 / 改分槽（参数可换，默认 A=chopin B=freE1）
sh stage3/e1_app_switch.sh slots
sh stage3/e1_app_switch.sh slots freE1 chopin    # 对调
sh stage3/e1_app_switch.sh slots factory freE1   # A 槽回纯原厂

# 只读看当前槽位、配置、分发日志、进程
sh stage3/e1_app_switch.sh status

# 切槽（每次约 20 秒）
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"
```

### 取舍与回退
- **A 槽镜像仍逐字节原厂**（`system_a` MD5 未变），变的只是开机 App。若想让 A 槽恢复
  「纯原厂体验」，把配置改成 `SLOT_A=factory`；`rm -f /userdata/system/SogouE1` 则两槽一起回原厂。
- 单槽模式 `freE1` / `chopin` / `factory` 会**覆盖分发器**，恢复分槽再跑一次 `slots`。
- 分发器只是普通 userdata 文件，删掉即全回原厂；不影响 `updateEngine` 切槽，
  也不影响阶段 2 的 A/B 双向回退通道。
- 任一时刻只有一个槽在启动、只跑一套 App，两套不会同时抢 PDM 采集或显示。
- 操作过程中设备 WiFi 有过一次省电掉线（`adb: device not found`），切槽命令因此**没有发出**；
  改为「先探测在线 → 立刻下发 `switch --go`」后成功。以后切槽请先确认 `adb devices` 在线。
