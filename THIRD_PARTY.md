# 第三方项目与依赖

本仓库**只开源本项目原创的脚本与文档**。下面这些组件的源码、二进制与固件
**都没有被打包进仓库**，请通过 `tools/fetch_deps.sh` / `tools/fetch_upstream.sh` 自行获取。

## 1. 为什么不打包

| 原因 | 说明 |
|---|---|
| **许可证** | `freE1`、`chopinshown/sogouE1`、`Armbian_E1` 等上游仓库在 GitHub 上**没有声明 LICENSE**。按默认规则是「保留所有权利」，由第三方再分发其源码存在法律风险。 |
| **版权** | 原厂固件（uboot / trust / boot / system / oem 镜像）是搜狗的专有产物，本项目无权再分发；请只从自己的设备备份。 |
| **体积** | 完整工作区 1.8 GB：`system_a/b` 各 400 MB、LVGL 源码 136 MB、LVGL tarball 68 MB、Qt 源码 64 MB、工具链 57 MB……GitHub 单文件硬上限 100 MB，且大仓库不友好。 |
| **隐私** | 录音 WAV/MP3、`E1-DATA.db`、设备序列号、WiFi SSID、本机绝对路径都不属于可公开内容。 |

整理后的仓库约 **400 KB**，只含文本与一张 5 KB 截图。

## 2. 上游 GitHub 项目

许可证状态为 2026-11-13 查询 GitHub API 的 `license.spdx_id`；`NONE` 表示**该仓库未声明许可证**。

| 项目 | 许可证 | 用途 | 获取 |
|---|---|---|---|
| [`rossihwang/freE1`](https://github.com/rossihwang/freE1) | **NONE** | LVGL 9.2.2 录音 App，本项目的 B 槽默认应用 | `tools/fetch_upstream.sh` |
| [`chopinshown/sogouE1`](https://github.com/chopinshown/sogouE1) | **NONE** | Qt Quick 录音 App + C 后端 `recorderd`，本项目 A 槽应用 | 同上 |
| [`Hermes-Language/Armbian_E1`](https://github.com/Hermes-Language/Armbian_E1) | **NONE** | 早期 Armbian 尝试（WIP，但 `extracted.dts` 与 ALSA/UCM 配置可用） | 同上 |
| [`Hermes-Language/E1_Research`](https://github.com/Hermes-Language/E1_Research) | **NONE** | 显示 / 音频 / 按键的硬件研究报告 | 同上（文档参考） |
| [`Hermes-Language/build_e1`](https://github.com/Hermes-Language/build_e1) | GPL-2.0 | Armbian build framework 的 E1 fork | 同上（体积大，按需） |
| [`Hermes-Language/u-boot`](https://github.com/Hermes-Language/u-boot) | NONE（U-Boot 本体 GPL-2.0+） | E1 适配 U-Boot | 同上 |
| [`Hermes-Language/NarrativeDesignEmbedded`](https://github.com/Hermes-Language/NarrativeDesignEmbedded) | MIT | Slint UI 参考 | 仅链接 |
| [`seabird000/E1Recorder`](https://github.com/seabird000/E1Recorder) | MIT | macOS 同步 + 云转写；`pen/e1sync.sh` 校时脚本可用 | 仅链接 |
| [`MitchRatquest/rk3308_synth`](https://github.com/MitchRatquest/rk3308_synth) | NONE | 同 SoC 的现代 Buildroot patch 参考 | 仅链接 |
| [`jayanta525/rk3308-rock-pi-s`](https://github.com/jayanta525/rk3308-rock-pi-s) | NOASSERTION | 同 SoC 的 OpenWrt / U-Boot 参考 | 仅链接 |
| [`JeffyCN/meta-rockchip`](https://github.com/JeffyCN/meta-rockchip) | 依仓库 | RK3308 BSP 参考 | 仅链接 |

> **请自行判断使用范围**：`NONE` 不等于「公有领域」。若要把这些项目用于公开分发或商业用途，
> 建议先向上游作者确认授权。

## 3. 第三方库与工具链

| 组件 | 版本 | 许可证 | 在本项目中的作用 | 获取 |
|---|---|---|---|---|
| [LVGL](https://github.com/lvgl/lvgl) | 9.2.2 | MIT | freE1 的 UI 框架 | `tools/fetch_deps.sh` |
| [alsa-lib](https://www.alsa-project.org/) | 1.1.9 | LGPL-2.1-or-later | 现场编静态 `libasound.a`，绕开原厂 glibc 2.26 | 同上 |
| [Qt](https://www.qt.io/) | 5.9.4（qtbase / qtdeclarative） | LGPL-2.1 / GPL / 商业 | 早期 Qt5 交叉编译路线 | 同上 |
| [Bootlin toolchains](https://toolchains.bootlin.com/) | `aarch64--glibc--stable-2018.02` | 内含 GCC / binutils / glibc，各自 GPL / LGPL | x86 host 交叉工具链参考（本项目最终改用设备原生 gcc） | 同上 |
| [Ubuntu base](https://cdimage.ubuntu.com/ubuntu-base/) | 22.04.5 arm64 | 各包独立许可证 | chroot 的 arm64 用户空间 | 同上 |
| [Alpine minirootfs](https://alpinelinux.org/downloads/) | aarch64 | 各包独立许可证 | 轻量备用 rootfs | 同上 |
| 原厂固件 | — | **搜狗专有，未授权** | 备份 / 回滚 / 重打包 B 槽时用 | **只能从你自己的设备 `dd` 备份** |

## 4. 我们对上游做的改动

见 [`docs/UPSTREAM_PATCHES.md`](docs/UPSTREAM_PATCHES.md)。
那里只给出**修改说明与 diff 文本**，不包含上游文件本体；
`stage3/` 下的 `Makefile.e1local`、`build_freE1_static.sh`、`build_recorderd_static.sh`
是本项目独立新写的驱动脚本，不是上游代码的复制品。

## 5. 商标

「搜狗」「Sogou」「录音笔 E1」等名称归其权利人所有。本项目仅作兼容性描述，
不表示任何官方背书或关联。

---

> 完整的使用风险、免责、录音合规、隐私与操作禁忌等注明事项，见
> [`docs/NOTICE.md`](docs/NOTICE.md)；改动上游源码的具体位置见
> [`docs/UPSTREAM_PATCHES.md`](docs/UPSTREAM_PATCHES.md)。
