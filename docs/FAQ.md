# 常见问题与排错

> 更完整的注明事项见 [`NOTICE.md`](NOTICE.md)，安装步骤见 [`INSTALL.md`](INSTALL.md)。
> 提问前建议先准备好 `adb devices -l`、`cat /proc/cmdline` 和相关日志尾部。

---

### Q1. 现在这台设备已经是 Armbian 了吗？

**不是。** 当前是「原厂 Buildroot 系统 + Ubuntu 22.04 arm64 chroot」的混合体：

- 内核仍是原厂 Linux 4.4.143，PID 1 仍是原厂 busybox init；
- 没有 systemd、没有 Armbian 内核包 / U-Boot 包 / `armbian-config`；
- Ubuntu 只是 `/mnt/sdcard/e1linux/ubuntu` 里的一个用户态根目录，靠 `mount --bind` + `chroot` 进入；
- B 槽改造也只是给原厂 squashfs 加了一个 `S98_e1linux` 开机钩子，让它开机自动挂 chroot。

所以「能跑 apt / gcc / Qt6」不等于「刷了 Armbian」。真 Armbian 需要解决 400 MB 分区容量、
adbd 回连通道、DRM 显示适配三个硬约束，见 [`E1_ARMBIAN_INSTALL.md`](E1_ARMBIAN_INSTALL.md)
与 [`BACKLOG.md`](BACKLOG.md)。

---

### Q2. 为什么不直接刷 Armbian / 换系统？

三个实测约束：① `system` 分区只有 400 MB，Ubuntu base 解包后约 1.45 GB；
② 换成独立原生根会丢掉原厂 adbd / WiFi 回连通道，出问题就失联；
③ 显示走 Rockchip DRM/KMS + VOP，Qt 需要原厂 patched `libqlinuxfb.so`，新系统要重新适配。
chroot 保留原厂内核与驱动，零刷机、完全可逆，代价是**不是开机原生的 Linux**。

---

### Q3. adb 怎么打开？连不上怎么办？

设备上：**通用设置 → 关于本机 → 连续点击「MAC 地址」→ 开发者模式 → 基本设置 → adb 打开**，
然后插 USB 线。PC 上 `adb devices -l` 应看到一台 `device`。

- 优先 USB；WiFi adb 会因省电掉线，切槽时尤其危险。
- Git Bash 里设备路径必须 `MSYS_NO_PATHCONV=1`（`. scripts/e1_env.sh` 已设置）。
- 若 `adb devices` 为空，先 `adb start-server` 再等几秒；无线调试是 mDNS 发现，需要时间。
- `adb shell id` 应为 `uid=0(root)`。

---

### Q4. 切换 A/B 分区需要按组合键吗？

**不需要，也不需要拆机。** 设备自带 Rockchip 官方 `/usr/bin/updateEngine`（V1.0.1）：
`updateEngine --misc=other --reboot` 交换两槽 priority 并重启，约 20 秒上线。
`/etc/init.d/S99_bootcontrol` 开机自动 `--misc=now` 报平安；启动失败 uboot 靠 `tries_remaining` 自动回滚。

`FN+VOLUMEUP` 是 `/etc/input-event-daemon.conf` 里的**恢复出厂设置**，不是切槽，别乱按。
机制推导与逐字节证据见 [`E1_SLOT_SWITCH.md`](E1_SLOT_SWITCH.md)。

---

### Q5. 切槽命令发了，重启后却没变？

最常见原因是 **WiFi adb 掉线，命令根本没发出去**。处理顺序：

```sh
adb devices -l                                   # 必须在线，最好 USB
adb -s "$E1_SERIAL" shell "/usr/bin/updateEngine --misc=other --reboot"
# 重启上线后复核，不要只看命令返回码
adb -s "$E1_SERIAL" shell "cat /proc/cmdline | tr ' ' '\n' | grep slot_suffix"
```

另外 `misc` 里有 **3 份** A/B 元数据，`updateEngine` 只更新影子份；
**不要手工改 misc 字节**。回滚用 `slot_tool.sh restore --go`。

---

### Q6. 读 `/dev/fb0` 内容没变，是不是 App 没上屏？

不一定。`/dev/fb0` 是「假帧缓冲」（`/proc/fb` 为空、fb0 无驱动名）：

- **LVGL（freE1）** 直接写 fb0 → 抓帧能看到界面（仓库截图即由此而来）；
- **Qt Quick（chopin）** 走 DRM/KMS `/dev/dri/card0`（进程 fd 可证实），**不写 fb0**，
  所以 fb0 里只是上一次 LVGL 留下的最后一帧。

看 Qt 是否上屏，应查 `qmlscene` 的 fd、dmesg 里的
`vop_crtc_enable] Update mode to 320x320p2556`，或直接肉眼看屏幕。

---

### Q7. 两套录音 App 能同时装吗？

**不能装两份，但能「分槽各跑一套」**。两者共用原厂可写槽位 `/userdata/system/SogouE1`
（`userdata` 是 A/B 共享分区）。本项目的做法是放一个 `SogouE1.dispatch` 分发器，
读 `cmdline` 判槽后 `exec` 对应 launcher：`SLOT_A=chopin` / `SLOT_B=freE1`。

```sh
sh stage3/e1_app_switch.sh status
sh stage3/e1_app_switch.sh slots
```

---

### Q8. 编译动态程序报 `symbol not found` / `GLIBCXX_3.4.30 not found`？

原厂是 glibc 2.26 + GCC 6.3，Ubuntu chroot 是 glibc 2.35 + GCC 11/12。两条常见原因：

1. 动态链接到原厂库版本太老 → **用设备原生 gcc 全静态链接**（`-static`，产物无 `NEEDED`）；
2. `enter_linux.sh` 里混进了原厂 `/usr/lib/qt/plugins` 或 `LD_LIBRARY_PATH` → 全部清掉，
   原厂 Qt5 资源只 bind 到 `/mnt/host/` 备用，需要时单条命令显式指定。

> Bootlin `aarch64--glibc--stable-2018.02` 是 **x86_64 host** 工具链，在这台 aarch64 设备上跑不了。

---

### Q9. 静态链接报 `undefined reference to exp/pow/sqrtf`？

库顺序问题：`-lm` 必须放在 `-lasound` **之后**。
本项目固定在 `LDLIBS := -lpthread -lasound -ldl -lm`。

---

### Q10. 运行时 `snd_pcm_open("hw:2,0")` 报 `Unknown PCM`？

静态编译的 alsa-lib 1.1.9 把配置 prefix 写死成了 chroot 内构建目录。launcher 里必须：

```sh
export ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf
```

并确认原厂 `/etc/asound.conf` 已复制进 rootfs（命名 PCM `8c48kmic` 才能列出）。

---

### Q11. Qt 启动报 `Failed to create dumb buffer`？

dmesg 通常是 `rockchip_gem_alloc_cma failed to allocate 204800 byte dma buffer`，
即 CMA 连续物理内存不足。启动前：

```sh
sync
echo 3 > /proc/sys/vm/drop_caches
```

另外 chopin 的 `QT_QPA_FONTDIR` 要照原厂 `/usr/bin/SogouLunch.sh` 设为 `/data/fonts/`，
并补 `QT_LINUXFB_DRM_LOGO`，见 [`UPSTREAM_PATCHES.md`](UPSTREAM_PATCHES.md)。

---

### Q12. 为什么不能把 Ubuntu rootfs 直接刷进 `system`？

`system_a/b` 各 400 MB squashfs，原厂 system 实际只占 101.1 MB；Ubuntu base 解包约 1.45 GB。
而且换成独立原生根后，原厂 adbd / WiFi 服务不再启动，设备可能直接失联。
所以本项目选择「原厂底座 + chroot」。

---

### Q13. 导出脚本找不到录音 / WAV 路径不对？

- 用 `--list` 先看 `E1-DATA.db` 里解析出多少条；
- 真实录音字段是 `waveFormPath`（原始 wav），降噪版是同目录 `_denoise.mp3`；
- 数据库路径 `/userdata/databases/E1-DATA.db`，只读拉取；
- 中文文件名在 Git Bash 下易被改写，必要时导出到纯 ASCII 目录名；
- 去重状态在 `.e1_exported.json`，想重导就删掉它。

---

### Q14. 设备时间是 2019 年，录音时间戳全错？

断电后 RTC 复位，实测时钟停在 2019-10-02。freE1 的 launcher 会尝试 `ntpd` 校时；
更完整的方案是 [`seabird000/E1Recorder`](https://github.com/seabird000/E1Recorder)
的 `pen/e1sync.sh`（联网校时 + last-known-good 兜底），**本项目尚未集成**，见 `BACKLOG.md`。

---

### Q15. 变砖了怎么救？

按从轻到重：

1. `updateEngine --misc=other --reboot` 切回另一槽（uboot 失败自动回滚）；
2. `slot_tool.sh restore --go` 恢复 misc；用备份 `dd` 回写 `system_b`；
3. `adb reboot loader` + `rkdeveloptool`；
4. 拆机短接 eMMC CLK↔GND 进 MaskROM。

⚠️ **第 3、4 条只在文档里推导，未真机实跑**。请务必提前 `dd` 备份。
另外：改 GPT / parameter 导致卡 logo 的案例在社区已有，本项目全程不动 GPT。

---

### Q16. 云转写 / 会议纪要还能用吗？

官方 2024-05-30 停服后不能。可选第三方方案（本项目**未集成**）：
`seabird000/E1Recorder`（MIT，macOS + 自建阿里云 STT），
或社区「用自建服务器接管 `*.sogou.com` 私有协议」的方案。见
[`E1_GITHUB_PROJECTS.md`](E1_GITHUB_PROJECTS.md) 与 `BACKLOG.md`。

---

### Q17. Windows 能用吗？

能。导出脚本是 Python 3 跨平台；`windows/` 下有安装 / 卸载 / 构建部署的 bat。
shell 脚本建议用 Git Bash 跑（注意 `MSYS_NO_PATHCONV=1`）。
WSL2 辅助脚本 `install_wsl2_ubuntu.ps1` 属于早期方案，本机 WSL 未安装，最终未采用。

---

### Q18. 仓库里为什么没有 App 二进制、固件和 Qt 工程产物？

- **版权**：原厂固件是专有产物；`freE1`、`chopin sogouE1`、`Armbian_E1` 等上游仓库
  **未声明 LICENSE**，第三方再分发其源码有法律风险。
- **体积**：完整工作区约 1.8 GB，GitHub 单文件上限 100 MB。
- **隐私**：录音、数据库、序列号、SSID、本机路径都不属于可公开内容。

所以仓库只保留原创脚本、文档、diff 文本与一张界面截图，依赖用 `tools/fetch_*.sh` 自行获取。
详见 [`../THIRD_PARTY.md`](../THIRD_PARTY.md)。

---

### Q19. 怎么确认我的原厂系统没被改坏？

```sh
adb -s "$E1_SERIAL" shell "cat /proc/cmdline | tr ' ' '\n' | grep -E 'slot_suffix|^root='"
adb -s "$E1_SERIAL" shell "md5sum /dev/block/by-name/system_a /dev/block/by-name/system_b"
```

把结果与安装前记录对照；本项目实测中 `boot_a/boot_b` 相同、`system_a` 的 MD5 全程未变。
最保险的一键回原厂：`sh stage3/e1_app_switch.sh factory` + 切回 A 槽。
