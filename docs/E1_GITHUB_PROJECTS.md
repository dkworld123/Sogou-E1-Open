# 搜狗 E1 可玩项目清单（GitHub + 社区）

调研时间：2026-11-13 20:4x
方式：GitHub REST API 多关键词检索（中英文共 13 组）+ 逐个拉取 README / 文件树 / 安装文档 / 构建脚本 + 社区检索。
结论基于**实际读到的仓库内容**，不是只看标题。缓存快照在 `.probe/gh/`。

---

## 0. 一句话结论

E1 的开源生态在 2026-11 这半年集中爆发，玩法分四条互不相同的路线：

| 路线 | 代表项目 | 要不要刷机 | 对这台设备的价值 |
|---|---|---|---|
| **A. 替换原厂 App（最实用）** | `rossihwang/freE1`、`chopinshown/sogouE1` | **不用**，只放 2 个文件到可写槽位 | 直接把屏幕、8 麦、按键、导出全用起来，顺带解决我们遗留的「Qt6 上屏」 |
| **B. 补回停服的云转写** | `seabird000/E1Recorder`、公众号「10 元复活 E1」方案 | 不用 | 把 2024-05-30 停服后失效的转写/纪要复活 |
| **C. 研究资料** | `Hermes-Language/E1_Research` 等 | 只读 | 补 DRM/KMS 显示、8 麦、降噪、按键、私有协议 |
| **D. 换系统 / 真 Armbian** | `build_e1`、`u-boot`、RK3308 SDK 系 | 要 | 阶段 3 才碰，风险最高 |

> 关键新发现：`freE1` 与 `chopinshown/sogouE1` 用的是**同一个原厂可写应用槽位** `/userdata/system/SogouE1`，**二者互斥，只能装一个**。

---

## 1. 路线 A：替换原厂 App（优先推荐）

### 1.1 `rossihwang/freE1` ★ 最推荐
- 链接：https://github.com/rossihwang/freE1
- 状态：2026-11-10 更新，1 star，674 KB，C + LVGL 9.2.2，**无 Release**
- 原理：`inittab → SogouLunchProbe.sh → /oem/SogouLunch.sh → /usr/bin/SogouLunch.sh`，优先找 `/userdata/system/SogouE1`；存在就跑它，不存在就跑原厂 `/usr/bin/SogouE1`。
- 安装只要两个文件：`freE1` → `/userdata/freE1/freE1`，`e1ui-launch.sh` → `/userdata/system/SogouE1`，然后 `killall SogouE1` 让 init 重跑。
- **卸载只要删一个文件**：`rm -f /userdata/system/SogouE1`，原厂 App 立刻回来；`device-app.sh` 还有「30 秒内崩 3 次自动交还原厂」的守卫。
- 功能：48 kHz / 24-bit（可选 16-bit）立体声、1 小时分段、暂停/继续、断电恢复、录音标记、耳机监听、浏览器 HTTP 列表/下载/多选删除、WiFi 扫描配置、深色 LVGL 界面、电源策略（熄屏/深睡）。
- 作者实测：连续 10 h 采集 13,824,000,000 B 精确、0 xrun；AGC −66→−34 dBFS；监听 0 欠载；分段轮转精确 3600.0 s；`kill -9` 后 WAV 头自动修复。
- 文档齐全：`MANUAL` / `AUDIO_COMPARISON` / `NR_TESTING` / `INSTALL` / `TEST_PLAN` / `MIC_ARRAY_GEOMETRY`（麦位 64×25 mm，行距≈30 mm）/ `MARKS` / `BACKLOG`。
- **编译难点**：`Makefile.e1` / `Makefile.e1ui` 都是 `CC ?= aarch64-linux-gcc` + `-static`，静态链接正好绕开原厂 glibc 2.26 与 Ubuntu 22.04 glibc 2.35 的兼容坑；UI 版需 `scripts/fetch-lvgl.sh` 拉 LVGL 9.2.2、`scripts/fetch-alsa.sh` 从设备拉 libasound。我们手上已有 Bootlin `aarch64--glibc--stable-2018.02` 工具链（前缀 `aarch64-buildroot-linux-gnu-`，别名 `aarch64-linux-gnu-`），改一下 `CC` 就能编。
- 已知限制：44.1 kHz 下 PDM ch6/ch7 恒为 0；ch6/ch7 对方向不敏感，暂不做 DOA/波束成形；无 VAD；HTTP 无登录鉴权（`BACKLOG` 里明确列出）。

### 1.2 `chopinshown/sogouE1` ★ 今天（2026-11-13）新建
- 链接：https://github.com/chopinshown/sogouE1
- 状态：0 star，321 KB，Qt Quick 界面 + 原生 ALSA，**Mac 上构建、adb 安装到同一个可写槽位**。
- 功能：48 kHz / 24-bit 立体声 WAV、左右电平表、物理 REC/MARK/STOP 键、cue 点 + JSON sidecar、波形预览/回放/跳转、WiFi 扫描与保存、**WiFi RTP/UDP 实时音频桥**（Mac/Windows Python 桥）、6 辅助麦 Wiener 谱降噪 + 耳机 A/B 对比。
- 音频认识比 freE1 更深：`hw:2,0` 开全 8 槽 @48 kHz，取 ch6/ch7 作主立体声（外部 ADC 主麦对），ch0–5 辅助麦做降噪；24-bit 样本左对齐在 32-bit 字里，打包成 3 字节 WAV；回放直接走物理 `hw:0,0`，绕开原厂 `default` → 软件 loopback → `eq_drc_process`。
- 作者实测：8 秒 8 通道同步采集无 overrun；合成测试 8.5 dB 稳态噪声抑制；房间实测约 6.3 dB 降低；2026-11-13 本人 A/B 试听结论「Noise is lower and voice is clear」。
- 与 freE1 的差异：Qt Quick（我们设备自带 Qt 5.9.4 + QML，方向接近）、有降噪和 RTP 音频桥，但需要 Mac 工具链构建，且仓库刚建、没有 Release。

> **选择建议**：想要「稳、文档全、能自己静态编译」选 freE1；想要「Qt/QML 路线 + 降噪 + WiFi 实时音频」选 chopinshown/sogouE1。两者都**不刷机、秒回滚**，可以先各编译一份轮流试，反正删一个文件就换回来。

---

## 2. 路线 B：把停服的云转写补回来

### 2.1 `seabird000/E1Recorder`
- 链接：https://github.com/seabird000/E1Recorder ，MIT，5 stars，2026-11-13 更新
- macOS 菜单栏 App（SwiftUI）：USB / WiFi 同步录音 → 自己的阿里云通义听悟或百炼（Fun-ASR）→ 会议纪要 Markdown / Word / PDF → 存笔记库；含 5 套纪要模板、笔端校时、用量预算、WiFi 地点/发言人/热词。
- **Windows 用不了这个 App**。但 `pen/` 目录里三个纯 shell 脚本可独立用在笔上：
  - `e1sync.sh`：断电后 RTC 复位 → 用 last-known-good 时间兜底并标记 estimated，联网跑 ntpd 后 `hwclock -w`，只写 `/userdata/e1sync`，**不碰系统分区、不重启**。
  - `e1wifi`、`auto_reboot.sh`：WiFi 同步到自建 OSS / 重启策略。
- 我们设备时钟确实停在 2019-10-02（本次开机状态文件里 `timestamp=Wed Oct 2 00:39:25 CST 2019`），这个校时脚本**立刻有用**。

### 2.2 非 GitHub 但最完整的云替代方案（社区）
公众号《用 DeepSeek 花了 10 元复活搜狗 E1 录音笔》：
- 通过 `dnsmasq` 把 `*.sogou.com` 劫持到自建服务器，逆向原厂私有「墙」协议（RSA-1024 + AES-256-CBC + deflateRaw），**不刷机不改固件**，笔连 WiFi 就能继续工作。
- 笔端：静态编译 aarch64 `uploader` → `/userdata/bin/`，`crond` 每 2 分钟扫新录音，HTTP multipart 上传；改 `/oem/SogouLunch.sh` 保证重启自恢复。
- 服务端：Nginx + Node.js → WAV 按 20 分钟分片 → SiliconFlow STT → DeepSeek 标题/总结 → Markdown → GitHub REST API → Obsidian Git 自动 pull。
- 这套正好解决我们「B 槽能跑程序但转写还是死的」的问题；`/oem` 在原厂 squashfs 里只读，但**我们 B 槽是可重打包的 squashfs**，可以直接把启动钩子做进镜像，比改 `/oem` 更干净。

### 2.3 `zxjay/Sogou-AI-Recorder-mp-plugin`
2020 年官方小程序 SDK 插件（`provider: wxcaba63e60ef46eab`），依赖已停服的 `token`，**功能上已失效**，只剩 BLE 协议文档价值。

---

## 3. 路线 C：研究资料（补我们遗留的上屏 / 8 麦）

| 仓库 | 内容 | 对我们的用处 |
|---|---|---|
| `Hermes-Language/E1_Research` ★ | 26 MB；`Display.md`(25 KB，VOP/DRM/KMS 对象模型、320×320 DPI 并行 RGB、25.56 Hz、st16xx 触摸 I2C 0x36)、`Audio.md`(15 KB，PDM 寄存器 `ff380000`、98.304 MHz 时钟、8 通道拓扑)、`Key.md`、`Connect.md`(17 KB)、`Denoise.md`、`NNSE.md`、`File_Info.md`、`extracted.dts`、`Original/`；还提到有 IDA Pro 分析库（太大未上传，需联系作者） | **正好补「Qt6 上屏 DRM/KMS」和 8 麦/降噪的空白** |
| `Hermes-Language/Armbian_E1` | 我们已 clone；WIP，只有 `extracted.dts`、ALSA/UCM 配置、`E1Recorder`(Qt6)、`userpatches`；README 自述「目前貌似完成了 ALSA 相关设置的导出以及设备树的提取」 | 已用尽，无新东西 |
| `Hermes-Language/build_e1` | 600 MB 完整 Armbian build framework fork（`compile.sh`/`config`/`patch`/`packages`），2025-07-27 | 「真 Armbian」的上游框架，我们阶段 2 走 chroot 绕开了它 |
| `Hermes-Language/u-boot` | 305 MB 完整 U-Boot fork，2025-07-27 | 真 Armbian 需要替换 uboot 时的来源 |
| `Hermes-Language/NarrativeDesignEmbedded` | 69 KB，Rust + Slint 嵌入式 UI 试验，2025-09-10 | 另一套 UI 技术栈参考（不是 Qt、不是 LVGL） |

---

## 4. 路线 D：同 SoC 底层参考（做真 Linux / 换内核才用）

| 仓库 | stars | 说明 |
|---|---|---|
| `JeffyCN/meta-rockchip` | 239 | Rockchip 官方维护者之一的 Yocto BSP layer |
| `ariaboard-com/rockchip_rk3308_{linux_sdk,kernel,uboot,buildroot}` | 1–12 | RK3308 完整 SDK 四件套（kernel/uboot/buildroot/SDK） |
| `jayanta525/rk3308-rock-pi-s` | 27 | OpenWrt for ROCK Pi S（同 RK3308），含 SD/NAND 启动与 uboot 构建文档 |
| `MitchRatquest/rk3308_synth` | 0 | modern buildroot external tree，带 `0001-Get-it-working-on-modern-buildroot.patch`，把老 RK3308 BSP 搬进新 Buildroot |
| `radxa-build/radxa-rcore-rk3308-io` / `kvn61/rk3308` / `seven12767/rk3308` | 0–3 | 零散板级资料 |

> 这些都是**别的板子**（ROCK Pi S / Firefly / ariaboard），设备树、引脚、WiFi 模组都不同，只能当代码参考，不能直接刷。

### 不适用但相关
- `zhangxuyang0714-create/sogou-c1-ble-research`：C1 / C18D 的 BLE 协议逆向（GATT `2BB1` opcode、Android Kotlin 客户端）。E1 走 USB/WiFi，不是 BLE，协议不通用。

### 社区讨论（非 GitHub）
- whycan.cn `/t_12087.html`《[废物利用] 搜狗 E1 录音笔重新开发》：整个生态的源头帖。确认了 adb 开启方式（通用设置 → 关于本机 → 连点「MAC 地址」）、Buildroot 2018.02-rc3、RK3308 `evb digital-pdm mic v13` 设备树 model、核心可执行文件 `SogouE1` 是 Qt5 + `libssb1.so`/`libsttsdk.so`/`libnnse.so`。
- 帖里有人「自己写分区表刷入后卡 logo」——**正好印证我们坚持不动 GPT/parameter 的决策是对的**。

---

## 5. 落地结果（2026-11-13 晚已执行）

**第一梯队两套 App 已全部装好并实测通过**，完整报告见 `docs/E1_APPS_INSTALLED.md`。要点：

- 没用 Bootlin 交叉工具链（它是 x86_64 host，在 aarch64 设备上跑不了），改在设备 Ubuntu chroot 里用 gcc 11.4 **全静态**编译，把 libc 打进二进制，绕开原厂 glibc 2.26。
- `freE1`（LVGL，写 `/dev/fb0`）与 `chopinshown/sogouE1`（Qt Quick，走 DRM/KMS `/dev/dri/card0`）都跑通；两者共用 `/userdata/system/SogouE1`，用 `e1_app_switch.sh` 三态切换，当前默认 freE1。
- 修掉 5 个坑：chroot 缺 bzip2、静态链接 `-lm` 顺序、`ALSA_CONFIG_PATH` 指向原厂 alsa.conf、DRM dumb buffer 的 CMA 不足（drop_caches）、chopin 的 `QT_QPA_FONTDIR`。
- B 槽开机钩子 `E1_START_RECORDER` 改为 0，避免抢 PDM 采集。
- **遗留的「Qt6 上屏」疑问有了答案**：fb0 是假帧缓冲，Qt 必须靠 patched `libqlinuxfb.so` + `QT_QPA_FB_DRM=1` 走 DRM；而 LVGL 直接写 fb0 也能出画。读 fb0 只能验证前者。
- 全程零刷机：`system_a/b`、`boot_a/b`、uboot、trust、GPT、misc MD5 未变；A 槽仍是完整原厂。

**下一步（未做）**
1. 校时 + 云链路：`seabird000/E1Recorder` 的 `pen/e1sync.sh`，或公众号「10 元复活 E1」的自建 STT/AI 纪要方案，把停服的转写补回来。
2. 真 Armbian：上游 `Hermes-Language/build_e1` + `u-boot` + `ariaboard-com` RK3308 SDK；仍需解决 400 MB 分区 vs 1.45 GB rootfs、adbd 回连通道、显示适配。

---

## 6. 注意事项

- `freE1` 与 `chopinshown/sogouE1` **同槽互斥**，同时只能装一个。
- 两者都**没有 Release**，必须自行编译（本工作区已编好全静态二进制，见 `docs/E1_APPS_INSTALLED.md`）；`freE1` 的 INSTALL.md 警告「链到更新版 glibc 会黑屏」，我们用全静态链接规避。
- 这个槽位本来是原厂 OTA 用的；官方 2024-05-30 已停服，被 OTA 覆盖的概率极低。安装前槽位为空（原厂走 `/usr/bin/SogouE1`），现在三个 launcher 都保存在 `/userdata/system/SogouE1{,.freE1,.chopin}`。
- 原厂 `SogouE1` 被替换后不再启动；我们 B 槽的 `S98_e1linux` 钩子不依赖它，所以 A/B 切换和 `updateEngine` 回退能力**不受影响**。
- 搜索结果中混入了大量与 E1 无关的政治/噪音仓库，已全部剔除，本清单只保留与设备、RK3308、搜狗录音笔相关的项目。
