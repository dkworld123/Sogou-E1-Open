# 未完成事项 / 待办清单

> 状态：2026-11-16 整理。本项目是个人研究记录整理，**没有版本路线图或交付承诺**。
> 这里只是把「还没做 / 还没验证」的事如实列出来，避免 README 里的「已跑通」被误读为「全都做完了」。
> 风险与边界见 [`NOTICE.md`](NOTICE.md)。

---

## P0 · 需要人工确认或低成本验证

| # | 事项 | 现状 | 建议做法 |
|---|---|---|---|
| 1 | **物理屏幕观感** | 只抓到 `/dev/fb0` 帧缓冲 PNG、读到 DRM `320x320p2556`，**没有肉眼确认** | 开机看一眼亮度 / 触摸 / 刷新；LVGL 与 Qt Quick 两条路径各看一次 |
| 2 | **救砖通道实跑** | `adb reboot loader` + `rkdeveloptool`、拆机 MaskROM 均**只在文档推导** | 在**有完整备份的第二台设备**上验证；或先只验证 `loader` 能否进入 |
| 3 | 全仓脱敏与链接复检 | 已做一轮 | 每次提交前 `git status` + 敏感串扫描，见 `NOTICE.md` 第 3 节 |
| 4 | 脚本在纯净环境复测 | 仅一台 Windows 主机跑通 | 干净 Git Bash + 只有 adb 的环境里跑 L0 / L1 |

---

## P1 · 功能补齐

| # | 事项 | 难点 / 约束 | 参考方案 |
|---|---|---|---|
| 5 | **设备校时** | RTC 断电后回到 2019，录音时间戳不可信 | [`seabird000/E1Recorder`](https://github.com/seabird000/E1Recorder) 的 `pen/e1sync.sh`（MIT，只写 `/userdata`） |
| 6 | **云转写 / 会议纪要** | 官方 2024-05-30 停服 | 同上（自建阿里云 STT），或社区「自建服务器接管私有协议」方案；注意密钥与录音合规 |
| 7 | **SSH / 远程登录** | chroot 内起 sshd 需处理端口、防火墙与开机自启 | 在 B 槽钩子 `e1_boot_linux.sh` 里挂，不动分区 |
| 8 | **自研 Qt6 `E1Recorder` 原生上屏** | 目前只做 `offscreen` 冒烟；Qt6 缺原厂 patched `libqlinuxfb.so` 的 DRM 逻辑 | 参照 chopin 的 `qmlscene` 路径（`/dev/dri/card0`）或移植 patched 插件逻辑 |
| 9 | 上游适配脚本化 | 现在 `UPSTREAM_PATCHES.md` 的 3 段 diff 要手工应用 | 做成 `patch -p1` 可用的 `.patch` 文件 + 一键构建脚本 |
| 10 | 一键验证脚本 | 验证清单散落在 `INSTALL.md` | 写 `tools/verify_device.sh`，只读输出槽位 / MD5 / 进程 / 日志 |

---

## P2 · 大工程 / 高优先级低

| # | 事项 | 硬约束 | 备注 |
|---|---|---|---|
| 11 | **「真 Armbian」原生启动** | 400 MB 分区 vs 1.45 GB rootfs；adbd 回连通道；DRM 显示适配 | 需 [`Hermes-Language/build_e1`](https://github.com/Hermes-Language/build_e1) + `u-boot` + RK3308 BSP；当前方案刻意绕开 |
| 12 | 换内核 / 主线 Linux | 原厂 4.4.143 的 PDM、VOP、触摸驱动需移植 | 同 SoC 参考：`jayanta525/rk3308-rock-pi-s`、`MitchRatquest/rk3308_synth`（板级不同，不可直接刷） |
| 13 | 多批次设备适配 | 只测过一台；分区 GUID / MD5 / 屏幕批次可能不同 | 欢迎提 Issue 附 `sgdisk -i` 与 `cmdline` |
| 14 | 上游 LICENSE 澄清 | `freE1`、`chopin sogouE1`、`Armbian_E1` 等未声明 LICENSE | 若上游补上许可证，可考虑把适配脚本 / 补丁合并进本仓库 |

---

## 已明确不做（保留作反面参考）

| 方案 | 放弃原因 | 文档 |
|---|---|---|
| WSL2 + Docker 交叉编译 | 本机 WSL 子系统未安装、无管理员权限；且设备本机 gcc 更快 | `E1_LINUX_INSTALLED.md` 第一节 |
| Bootlin x86 host 交叉工具链 | 是 x86_64 二进制，在 aarch64 设备上跑不了 | `UPSTREAM_PATCHES.md` 第 4 节 |
| 把 Ubuntu rootfs 刷进 `system` 分区 | 400 MB 装不下，且会丢 adbd 回连 | `E1_ARMBIAN_INSTALL.md` |
| 改 GPT / parameter 自定义分区表 | 社区已有「卡 logo」案例 | `E1_GITHUB_PROJECTS.md` 第 4 节 |
| 动态链接新 glibc 程序 | 原厂 glibc 2.26 不兼容 | `E1_APPS_INSTALLED.md` 第 1 节 |

---

## 想接坑？

先读 [`../CONTRIBUTING.md`](../CONTRIBUTING.md) 与 [`NOTICE.md`](NOTICE.md)：
任何新方案请**先写清楚回滚路径**，并保持「原厂 A 槽不动」这条底线。
