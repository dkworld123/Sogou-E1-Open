# 注明事项（使用前必读）

本文集中列出本仓库所有需要「注明」的事项：**风险、免责、合规、隐私、兼容性、
操作禁忌与未验证项**。README 与 `INSTALL.md` 里凡是出现「⚠️」的地方，都以此文为准。

> 一句话：这是一份**个人研究记录整理**，不是官方固件、不是刷机包、不是产品。
> 你可以照着做，但请自己判断、自己备份、自己承担后果。

---

## 0. 一页速览

| # | 事项 | 结论 |
|---|---|---|
| 1 | 与官方的关系 | **非官方**，与搜狗无任何关联或背书 |
| 2 | 官方云服务 | 2024-05-30 已停服，原厂转写 / 同步 / OTA 均不可用 |
| 3 | 变砖风险 | L0–L2 零风险；**L3 写 `system_b` 有变砖风险**，且会使保修失效 |
| 4 | 仓库内容 | 只有脚本与文档；**不含**固件、分区镜像、录音、数据库、密钥 |
| 5 | 上游许可 | 多个上游仓库**未声明 LICENSE**，本仓库只引用、不打包其源码 |
| 6 | 录音合规 | 录音须取得被录音者同意，不得用于非法窃听或侵犯隐私 |
| 7 | 隐私 | 序列号 / SSID / 本机路径 / 录音样本全部脱敏；示例值不可照抄 |
| 8 | 验证范围 | **一台设备**实测，其它批次 / 固件版本需自行核对 |
| 9 | 维护 | 无 SLA、无版本承诺、无官方支持；救砖通道未实跑 |
| 10 | 许可 | 原创内容 MIT；第三方组件各适用其原许可证 |

---

## 1. 风险与免责

### 1.1 硬件风险

- **`dd` 写 `system_b` 是本项目唯一会改只读分区的操作**。写错设备节点、写错槽位、
  断电或镜像损坏，都可能导致无法启动。
- 该设备**没有 SD 卡槽，没有可用的组合键进刷机模式**（`FN+VOLUMEUP` 是恢复出厂设置，
  不是切槽也不是 Loader）。严重变砖的最后手段是拆机短接 eMMC CLK↔GND 进 MaskROM。
- **`loader` / Rockusb / `rkdeveloptool` / MaskROM 救砖通道只在文档里推导，未真机实跑**。
  不要把「有回滚方案」理解成「一定救得回来」。
- 拆机、短接、改写分区可能**永久失去保修**，并可能造成硬件损坏。

### 1.2 数据风险

- 录音文件、`E1-DATA.db`、槽位配置都在设备上；任何写操作前请自行 `adb pull` / `dd` 备份。
- 本仓库的导出脚本是只读的，但**不会替你做备份**；导出物请自行另存。
- `/userdata/system/SogouE1` 是原厂 OTA 用的可写槽位，替换后原厂 App 不再启动
  （删掉该文件即恢复）。虽然官方已停服、被 OTA 覆盖的概率极低，但这不是保证。

### 1.3 免责条款

- 本项目按 MIT「**按原样提供，不作任何明示或默示担保**」。作者与贡献者不对设备损坏、
  数据丢失、业务中断、隐私泄露或任何间接损失负责。
- 文档中的命令、MD5、分区大小、偏移、PARTUUID 都是**在一台具体设备上得到的值**，
  仅作示例。执行前请自行核对，不要盲目复制粘贴。
- 任何涉及写分区的脚本，本仓库约定**默认只读预演、显式参数才执行**
  （`slot_tool.sh` 的 `--go`）。若外部脚本没有这个保护，请自行加上。

---

## 2. 合法合规

1. **只对你自己拥有的设备操作**。逆向、adb 调试、修改固件请在法律允许的范围内进行，
   并遵守设备购买地与使用地的法规。
2. **录音合规**：E1 是录音设备。录制会议、通话或他人讲话前，请取得所有被录音者的同意，
   遵守当地关于录音、个人信息与数据跨境的规定。本项目不提供任何规避同意机制的能力，
   也不鼓励隐蔽录音。
3. **不分发专有内容**：原厂固件（uboot / trust / boot / system / oem 镜像）、
   原厂 App、`libssb1.so` 等私有库属于权利人专有产物，本仓库不提供、不镜像、不打包。
   请只从自己的设备备份，且不要公开分发。
4. **上游授权**：`freE1`、`chopinshown/sogouE1`、`Armbian_E1`、`E1_Research` 等在 GitHub 上
   **未声明 LICENSE**（查询时间 2026-11-13）。「没有 LICENSE」**不等于公有领域**，
   默认是「保留所有权利」。本仓库只提供下载脚本、适配 diff 与用法说明，不分发其源码；
   若要公开分发、二次发布或商业使用，请先联系上游作者取得授权。详见 [`../THIRD_PARTY.md`](../THIRD_PARTY.md)。
5. **商标**：「搜狗」「Sogou」「录音笔 E1」等名称归其权利人所有，本项目仅作兼容性描述，
   不表示任何官方关联或背书。
6. **云服务与账号**：若自行接入第三方 STT / OSS / AI 服务（见 `BACKLOG.md`），
   费用、密钥安全、数据出境与合规由使用者自行负责。

---

## 3. 隐私与脱敏

### 3.1 仓库里没有什么

- 无录音 WAV/MP3、无 `E1-DATA.db`、无导出物、无原厂镜像、无编译产物二进制。
- `.gitignore` 已排除 `*.img`、`*.wav`、`*.db`、`deps/`、`vendor/`、`rootfs/`、
  `.probe/`、`__pycache__/` 等。整理后仓库只有文本与一张界面截图。
- 设备序列号统一写作 `<SERIAL>` / `$E1_SERIAL`，WiFi 名称写作 `<SSID>`，
  Windows 本机路径与 IM 文件目录已替换为相对路径或占位符。

### 3.2 提交前请自己再查一遍

```sh
git status                       # 确认没有大文件与个人数据
git grep -n -E '[A-Za-z]:[\\/]|192\.168\.|xwechat|SSID|password|token|PRIVATE KEY'
```

上面这条只是示意（会匹配 Windows 盘符路径、内网 IP、IM 文件目录、常见敏感字段名），
请按自己的环境补充关键词；命中后先判断是不是占位符再提交。

提交内容里出现本机绝对路径、序列号、SSID、密钥、他人姓名或录音内容，都属于事故。
贡献约定见 [`../CONTRIBUTING.md`](../CONTRIBUTING.md)。

### 3.3 运行期隐私风险（第三方 App）

| 组件 | 风险 | 建议 |
|---|---|---|
| freE1 的 HTTP 录音列表 / 下载 | 上游 `BACKLOG` 明确写了**无登录鉴权**，默认关闭 | 只在可信局域网开启，别暴露到公网 |
| chopin 的 WiFi RTP 音频桥 | 音频流明文走局域网 | 同上；注意同网段其它设备可监听 |
| 自建云转写 / OSS | 录音上传到第三方账号 | 自行评估敏感内容，配置最小权限密钥 |
| 设备时钟 | RTC 断电后回到 2019，录音时间戳可能不准 | 用 `seabird000/E1Recorder` 的 `pen/e1sync.sh` 校时（本项目未集成） |

---

## 4. 设备兼容性与示例值

- 全部实测数据来自**一台**搜狗 E1：RK3308、Linux 4.4.143、Buildroot 2018.02-rc3、
  glibc 2.26、Qt 5.9.4、`system_a/b` 各 400 MB squashfs。
  不同批次、不同固件、已被他人改装过的设备，分区布局与文件可能不同。
- 文档里的 **MD5、PARTUUID、GUID、misc 偏移、序列号、SSID、时间戳均为示例**，
  请以你自己设备的 `sgdisk -i`、`cat /proc/cmdline`、`md5sum` 结果为准。
- **adb 需要手动开启**：通用设置 → 关于本机 → 连续点击「MAC 地址」→ 开发者模式 →
  基本设置 → adb 打开。本项目不会、也不能替你绕过设备上的授权开关。
- **优先 USB 连接**：WiFi adb 会因省电掉线，曾出现「切槽命令以为发出去了、其实没发」的情况。
  切槽前先 `adb devices -l` 确认在线，重启后以 `cmdline` 的 `slot_suffix` 复核结果。
- `docs/` 下的 `E1_*.md`、`SESSION_NOTES.md` 是**开发期报告**，路径与结论保留原貌；
  整理后目录对应关系见 README 第 4 节。
- `windows/*.bat` 在未检测到 adb 设备时会把 `E1_SERIAL` 置为占位值 `CHANGEME` 并继续，
  命令随后会失败。**请显式 `set E1_SERIAL=<你的序列号>` 或确认 `adb devices` 里只有一台设备**，
  不要把这个占位值当成真实序列号。脚本注释里的 `C:/path/to/adb.exe`、`D:/E1录音` 是通用示例路径。

---

## 5. 操作禁忌（技术层面）

| 不要做 | 原因 / 正确做法 |
|---|---|
| 手改 `misc` 分区字节 | 里面有 **3 份** AvbABData（含 CRC32），`updateEngine` 只更新影子份；一律用 `/usr/bin/updateEngine --misc=other` |
| 改 GPT / parameter | 社区已有「自己写分区表后卡 logo」的案例；本项目全程不动 GPT |
| 为了换系统去改 `boot_b` | DTB 里的 `root=PARTUUID=614e0000-0000` 是占位符，uboot 会按槽替换；改了反而容易错 |
| 把 1.45 GB rootfs 刷进 400 MB 分区 | 装不下；且独立原生根会丢掉 adbd 回连通道 → 用 chroot 方案 |
| 动态链接新工具链编出的程序 | 原厂 glibc 2.26 会 `symbol not found` → 用设备原生 gcc **全静态**链接 |
| 把 `-lm` 放在 `-lasound` 前面 | 静态库解析顺序导致 `exp/pow/sqrtf` undefined |
| 忘记 `ALSA_CONFIG_PATH` | 静态 alsa-lib 把 prefix 写死成构建目录，运行时会 `Unknown PCM` |
| Qt 启动前不回收页缓存 | `rockchip_gem_alloc_cma failed` → 先 `echo 3 > /proc/sys/vm/drop_caches` |
| 认为「读 fb0 没变 = 没上屏」 | fb0 是假帧缓冲；Qt 走 DRM/KMS `/dev/dri/card0`，LVGL 才写 fb0 |
| 同时装两套 App 到 `/userdata/system/SogouE1` | 二者**互斥**；用 `SogouE1.dispatch` 按槽分发 |
| 在 44.1 kHz 下取 PDM ch6/ch7 | 该采样率下两通道恒为 0，两个上游项目都用 48 kHz |
| 在 `enter_linux.sh` 里混入原厂 Qt5 / libstdc++ 路径 | 会报 `GLIBCXX_3.4.30 not found`，且 Qt6 加载 Qt5 插件会崩 |
| 把设备端 `.sh` 存成 CRLF 再 `adb push` | Windows Git 默认会转 CRLF，Linux 执行时报 `^M: not found`；`.gitattributes` 已对脚本强制 `eol=lf`，push 前用 `file` 确认 |

**始终保持不变的底线**：`boot_a/boot_b`、`system_a`、uboot、trust、GPT 不改；
`system_b` 的改造只用原厂 squashfs 重打包，加一个 `S98_e1linux` 开机钩子与标记文件。

---

## 6. 未验证 / 已知局限

| 项 | 状态 |
|---|---|
| `adb reboot loader` + `rkdeveloptool`、拆机 MaskROM 救砖 | **仅文档推导，未实跑** |
| 「真 Armbian」原生启动（systemd 作 PID 1） | **未做**；当前是原厂 Buildroot + Ubuntu chroot 混合体，PID 1 仍是 busybox init |
| 自研 Qt6 `E1Recorder` 原生上屏 | 只做过 `offscreen` 冒烟；DRM 上屏由上游 chopin 的 Qt Quick 路径间接证实思路 |
| 物理屏幕观感 | 只能读帧缓冲与 DRM 状态，**需人工肉眼确认** |
| 校时、云转写、SSH | 未集成，见 `BACKLOG.md` |
| Windows 一键 bat | 只在一台 Windows 主机上跑通，未在纯净环境复测 |
| 其它批次设备 | 未测试 |

---

## 7. 维护、支持与反馈

- 本项目是**按现状提供的研究记录**，没有版本路线图保证、没有响应时间承诺，
  也不提供一对一刷机指导。
- 遇到问题请先看 [`FAQ.md`](FAQ.md) 与 `INSTALL.md` 的「验证清单」，
  再带着 `adb devices -l`、`cat /proc/cmdline`、相关日志开 Issue。
- 提 Issue / PR 时**不要贴**序列号、SSID、密钥、录音内容或本机绝对路径。
- 若你发现上游项目补上了 LICENSE、或某条结论在你的设备上不成立，欢迎提 PR 更正文档。

---

## 8. 相关文档

- 风险分级与操作步骤：[`INSTALL.md`](INSTALL.md)
- 命令速查：[`USAGE.md`](USAGE.md)
- 常见问题：[`FAQ.md`](FAQ.md)
- 未完成事项：[`BACKLOG.md`](BACKLOG.md)
- 第三方许可与不打包说明：[`../THIRD_PARTY.md`](../THIRD_PARTY.md)
- 贡献约定：[`../CONTRIBUTING.md`](../CONTRIBUTING.md)
